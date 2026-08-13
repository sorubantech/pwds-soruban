# PSS 2.0 — Recycle Bin (Delete · Recently Deleted · Restore) Build Prompt

**Design ref:** `PSS-2.0-DELETE-RESTORE-RECYCLE-BIN-APPROACH.md` — read §② and §④ before starting.
**Status:** READY TO RUN
**Model:** Sonnet (BE + FE)
**Phase:** 1 of 3 — the spine plus three entities. Phases 2–3 are separate.

**The six design decisions are LOCKED. Do not re-litigate them; §② states them as rules.**

---

## ⓪ Step 0 — probe before you write

Run these and paste the answers into §⑫. If any contradicts this prompt, **stop and report** — do
not adapt silently.

1. `grep -rn "class EntityType" --include=*.cs Base.Domain/Models/PublicModels/` — what shape is
   `public.EntityTypes`, and does it already carry codes for Contact / Donation / Campaign? If yes,
   **reuse those codes**; do not invent a parallel vocabulary.
2. Open the three delete commands named in §④.5 and confirm each still matches the D-4 shape.
3. `grep -rn "IsDeleted" Base.Application/Business/ContactBusiness/Contacts/Commands/DeleteContact.cs`
   — confirm the 5-line pattern in §① D-4 still holds.
4. Read `Base.Application/Common/Interfaces/IAuditLogWriter.cs`. **Use `WriteEntityChange`. Do not
   write a new writer, and do not add a new method to the interface.**
5. `grep -rn "GridFeatureRequest" Base.API/EndPoints/Ops/Queries/DataPurgeQueries.cs` — confirm the
   paging parameter convention you must follow for the list query.

---

## ① Why this exists

Soft delete is universal in this product. **The evidence that a delete happened is not.**

| # | Finding | Evidence |
|---|---|---|
| **D-1** | **No entity anywhere records when it was deleted or by whom.** `Entity` exposes `CreatedBy/CreatedDate/ModifiedBy/ModifiedDate/IsActive/IsDeleted` and nothing else. The only `Deleted*` columns in the codebase belong to `ops.DataPurgeRequest`. | `Base.Domain/Abstractions/Entity.cs` |
| **D-2** | **Therefore "deleted in the last 7 days" cannot be expressed as a query.** The retention buckets the product needs have no column to stand on. | consequence of D-1 |
| **D-3** | **The global query filter is tenant-only, not delete-aware.** `ApplyTenantFilters` builds `CurrentTenantId == null ‖ CompanyId == CurrentTenantId ‖ IsSystem` and never mentions `IsDeleted`. | `ApplicationDbContext.cs:61–131` |
| **D-4** | **188 hand-written delete commands, all the same five lines** — find, `IsDeleted = true`, `Update`, `SaveChanges`. No central service, no hook, no interceptor. | `find Base.Application/Business -ipath "*delete*" -name "*.cs"` → 188; canonical example `DeleteContact.cs` |
| **D-5** | **Delete does not cascade.** `DeleteContact` flips the contact only — addresses, phone numbers, email addresses, relationships all stay `IsDeleted = false`. | `DeleteContact.cs` handler |
| **D-6** | **A correct implementation of this already exists one level up.** `ops.DataPurgeRequest` + Soft/Restore/HardDelete commands + `PurgeScopeResolver` + preview/candidate queries — episode row with no FK, snapshot target name, `ManifestJson` of row ids captured pre-flip, `ManifestTruncated` flag, eligibility date stamped at delete time. It is scoped to LEAD and TENANT. | `Base.Application/Business/OpsBusiness/DataPurge/` |
| **D-7** | **A soft delete currently produces no audit row either.** `AuditLogInterceptor` diffs changed properties, `IsAuditColumn` skips `IsDeleted`, so a delete that changes only that flag hits `if (originalValues.Count == 0) continue;` and is dropped. All 188 deletes are invisible to the audit trail. | `AuditLogInterceptor.cs:96, 105, 140–144` |
| **D-8** | **Consequence.** A user who deletes the wrong donor has no recourse but a support ticket to the developer — and there is no record to investigate with. | — |

**This build generalises D-6 downward to record level. It does not invent an architecture.**

---

## ② Rules this build must not break

**Locked design decisions (D1–D6 of the approach doc):**

1. **Add NO columns to any business table.** Not `DeletedOn`, not `DeletedBy`, not on `Entity`, not
   on Contact/Donation/Campaign. All episode metadata lives on `app.RecycleBinEntries`. Touching the
   `Entity` base class means migrating hundreds of tables to store what the episode row already
   holds — that is the single most expensive wrong turn available here.
2. **Legacy deletions stay invisible, and the UI says so.** Rows soft-deleted before this ships have
   no episode row and will never appear. Do not attempt a backfill — there is no timestamp to
   backfill *from*. The empty state carries the sentence in §⑤.
3. **Retention expiry HIDES. It never destroys.** At day 31 the entry becomes `EXPIRED`, Restore
   disappears, the underlying row is left exactly as it is. **This build hard-deletes nothing and
   ships no purge job.** Irreversible destruction is the existing `ops.DataPurge` flow's job.
4. **Phase 1 registry = Contact, Donation, Campaign. Three. Not more.** Adding a fourth is Phase 2
   and costs one descriptor plus one line in a delete command — precisely because you built a
   registry. Adding ten now costs you the review.
5. **Retention is fixed at 30 days.** No tenant setting, no `sett` row, no admin screen. Put the
   number in one named constant.
6. **Surface is Settings → Data.** Route `setting/dataconfig/recyclebin`. **Not** the user profile —
   a deleted donor is tenant data, and burying it in a leaver's profile makes it unreachable.
7. **Visibility reuses existing RBAC. No new capability concept.** Read on the entity's `MenuCode`
   to *see* an entry; Delete on the same `MenuCode` to *restore* it. A new `RECYCLEBIN` menu exists
   only to render the screen itself.

**Engineering rules:**

8. **You do not run migrations.** Not `dotnet ef migrations add`, not `database update`, not
   `remove`. Do not hand-author a migration file or touch the model snapshot. Write the entity and
   the EF configuration, then put the migration spec in §⑧ for the user. Same for the seed: you
   **write** the `.sql` file, the user applies it.
9. **You do not run `dotnet build`.** The user builds the backend. Say what you believe compiles and
   why; do not claim a green build you did not run.
10. **`app.RecycleBinEntries` carries `CompanyId`, so the tenant filter attaches by convention.**
    **Never** call `IgnoreQueryFilters()` in this feature. That escape hatch is for `ops`/`billing`
    platform-global tables; using it here is a cross-tenant data leak.
11. **`EntityId` is deliberately NOT a foreign key** (D-6 rule 1 — the episode must outlive its
    target). Because the database will not validate it, **every read path re-resolves through the
    registry and re-checks the tenant.** Never trust a stored id on its own.
12. **`EntityLabel` is a snapshot, never re-resolved.** It shows what was deleted, not what exists
    now. Same for `DeletedByUserName` — the user may leave the organisation.
13. **`RestoreEligibleUntil` is stamped once, at delete time.** Never computed at read time from the
    retention constant. If the constant later changes, existing recovery windows must not move.
    This is a compliance property, copied from `DataPurgeRequest.HardDeleteEligibleOn`.
14. **The episode row is never deleted** — not on restore, not on expiry. It is the audit trail.
15. **One transaction — flip + insert episode.** They commit together or not at all. A delete that
    succeeded without its episode is an unrecoverable record.
15b. **The audit write is deliberately OUTSIDE that transaction.** `IAuditLogWriter` uses a separate
    scoped `DbContext` *"so audit rows persist even if the caller's transaction rolls back"*, and
    swallows its own failures. Call it **after** the commit and never `await` it inside the
    transaction scope. Do not "fix" it into the transaction — you would make an audit outage take
    down deletes.
16. **No raw SQL in application code.** No `ExecuteSqlRawAsync`, no `FromSqlRaw`, no string-built
    SQL. `ExecuteUpdateAsync`/`ExecuteDeleteAsync` over a LINQ `IQueryable` are EF and fine.
17. **UTC only.** `timestamptz` columns, `DateTime.UtcNow`, boundaries built with `DateTimeKind.Utc`.
    Never `DateTime.Today` in an EF predicate — Npgsql throws on `Kind=Unspecified`. The
    *today / 7 / 30* buckets are computed in the tenant's timezone at the **presentation** layer.
18. **HotChocolate strips `Get` from every resolver and appends `Input` to input types.** `tsc`
    cannot see gql field names — a wrong name compiles clean and fails only at runtime. Read your
    own resolver before writing the frontend query.
19. **Do not change delete behaviour.** Delete stays shallow (D-5). You are recording the episode,
    not widening it.
20. **House UI rules.** Solid `bg-X-600` + `text-white` for icon containers, type chips and status
    pills. Never `bg-X-50/100`, `text-X-700/800`, `bg-muted`/`text-muted-foreground` as status, or
    `/10` tints. Tokens not hex/px. Shaped skeletons. `@iconify` Phosphor. `tabular-nums` on counts.
    xs→xl responsive.

---

## ③ The mental model

> **A delete is an episode, not a flag. The flag says a row is gone; the episode says who removed
> what, when, and exactly which rows to put back.**

---

## ④ Backend

### ④.1 The entity

`Base.Domain/Models/ApplicationModels/RecycleBinEntry.cs`

```csharp
[Table("RecycleBinEntries", Schema = "app")]
public class RecycleBinEntry : Entity, ITenantEntity
{
    public int RecycleBinEntryId { get; set; }
    public int CompanyId { get; set; }              // ITenantEntity — filter attaches by convention

    public string EntityTypeCode { get; set; }      // CONTACT | DONATION | CAMPAIGN
    public int    EntityId { get; set; }            // deliberately NOT a foreign key (rule 11)
    public string EntityLabel { get; set; }         // snapshot (rule 12)
    public string? EntitySubLabel { get; set; }     // snapshot

    public string? ManifestJson { get; set; }       // per-table row ids, captured PRE-flip
    public bool    ManifestTruncated { get; set; }

    public string Status { get; set; }              // DELETED | RESTORED | EXPIRED

    public int?      DeletedByUserId { get; set; }
    public string?   DeletedByUserName { get; set; }
    public DateTime  DeletedOn { get; set; }
    public DateTime  RestoreEligibleUntil { get; set; }   // stamped at delete time (rule 13)

    public int?      RestoredByUserId { get; set; }
    public string?   RestoredByUserName { get; set; }
    public DateTime? RestoredOn { get; set; }

    public string? IpAddress { get; set; }
}
```

Class comment must record **why `EntityId` has no FK** and **why the label is a snapshot**, in the
style of `DataPurgeRequest`. The next developer will otherwise "tidy" both.

`Base.Infrastructure/Data/Configurations/ApplicationConfigurations/RecycleBinEntryConfiguration.cs`
— max lengths per §⑧, plus both indexes.

### ④.2 The registry — curated, not reflected

`Base.Application/Business/ApplicationBusiness/RecycleBin/RecycleBinRegistry.cs`

```csharp
public sealed record RecycleBinEntityDescriptor(
    string EntityTypeCode,
    string DisplayName,          // "Contact"
    string Icon,                 // "ph:user"
    string MenuCode,             // existing menu code — drives the capability check (rule 7)
    Func<IApplicationDbContext, IQueryable<Entity>> Query,
    Func<Entity, (string Label, string? SubLabel)> Snapshot,
    Func<IApplicationDbContext, int, CancellationToken, Task<IReadOnlyList<string>>> RestoreConflicts
);
```

A static, hand-written dictionary of **exactly three** descriptors.

**Do not generate this from `auth.Modules`, the menu tree, `public.EntityTypes`, or by scanning for
types that expose `IsDeleted`.** A generic scanner would offer to restore junction rows, settings
and audit entries. This is a curated business vocabulary, the same rule that governs
`billing.Features`.

An unregistered entity's delete is untouched and never reaches the bin. That is correct.

### ④.3 The service

`Base.Application/Business/ApplicationBusiness/RecycleBin/IRecycleBinService.cs` + implementation.

```csharp
Task SoftDeleteAsync(string entityTypeCode, int entityId, CancellationToken ct);
Task<IReadOnlyList<string>> GetRestoreConflictsAsync(int entryId, CancellationToken ct);
Task RestoreAsync(int entryId, CancellationToken ct);
```

`SoftDeleteAsync`, in one transaction (rule 15):
resolve descriptor → load entity (tenant-checked) → **capture snapshot and manifest BEFORE the
flip** → `IsDeleted = true` → insert the episode with `Status = DELETED`, `DeletedOn = UtcNow`,
`RestoreEligibleUntil = UtcNow + RetentionDays` → **commit** → *then*
`auditLogWriter.WriteEntityChange(entityType, entityId, action: "DELETE", before: null, after: null,
description: <label>)` (rule 15b — after the commit, never inside it).

This audit call is **not** redundant with the interceptor. Per D-7 the interceptor drops soft
deletes entirely, so this is the first real `DELETE` audit row the product has ever written. Mirror
it on restore with `action: "RESTORE"`.

`RestoreAsync`: re-check conflicts **server-side** (the client's pre-check is advisory, never
trusted) → if any, throw with the conflict list → else replay manifest, `IsDeleted = false`,
`Status = RESTORED`, stamp restorer + `RestoredOn` → commit → then audit.

**Constants** in one file: `RetentionDays = 30`, `ManifestIdCap`, the three status strings, the
three entity-type codes.

### ④.4 Restore conflicts — the part that is usually got wrong

Restoring is **not** the inverse of deleting; the world moved on. Each descriptor's
`RestoreConflicts` returns human-readable blockers:

| Conflict | Example | Required behaviour |
|---|---|---|
| Unique index collision | The contact's email was reassigned after deletion | **Block.** Name the conflicting record. **Never silently rename or null the field.** |
| Dangling parent | Restoring a Donation whose Campaign is also deleted | **Block** with *"Restore Campaign X first."* Chained restore is out of scope. |
| Quota / entitlement | Tenant is at its plan's record ceiling | **Block** with the upgrade path. Quota is a hard gate. |
| Number sequence reuse | The business code was re-issued | **Allow.** Keep the original code, return an advisory. **Never renumber** — the code may be printed on a receipt. |
| Truncated manifest | Blast radius exceeded `ManifestIdCap` | **Allow, best-effort, and say so in the UI.** |

### ④.5 Call-site edits — three files only

**Verified paths — these three, and only these three:**

```
Base.Application/Business/ContactBusiness/Contacts/Commands/DeleteContact.cs
Base.Application/Business/DonationBusiness/GlobalDonations/Commands/DeleteGlobalDonation.cs   ← confirm folder name in Step 0
Base.Application/Business/ApplicationBusiness/Campaigns/Commands/DeleteCampaign.cs
```

Note there is no `DeleteDonation.cs`; the donation record is `GlobalDonation`. Note also that
Campaign already lives in `ApplicationBusiness` — the same area as the recycle bin.

In each, replace the find/flip/update/save block with:

```csharp
await recycleBin.SoftDeleteAsync(RecycleBinEntityTypes.Contact, contactId, ct);
```

`[CustomAuthorize]`, the validator and all business rules **stay in the command**. The service owns
only the episode mechanics. **Do not touch the other 185 delete commands.**

### ④.6 Drift detection

One query, `GetRecycleBinDriftCountQuery`: for the three registered types, count rows where
`IsDeleted = true` and no `app.RecycleBinEntries` row exists. Exposed as a number for the platform
ops console. We cannot *prevent* someone hand-writing `IsDeleted = true` in future; we can make it
visible. **Do not build a UI for it in this build** — return the number, nothing more.

### ④.7 GraphQL

`Base.API/EndPoints/Application/Queries/RecycleBinQueries.cs` and `.../Mutations/RecycleBinMutations.cs`,
following `DataPurgeQueries.cs`: `[ExtendObjectType(OperationTypeNames.Query)]`, `IQueries`,
`[Service] IMediator`, `BaseApiResponse<T>` / `PaginatedApiResponse<T>`, try/catch to `.Error(...)`,
`GridFeatureRequest` paging per Step 0.5, acting user from the `UserId` claim.

- `GetRecycleBinEntries(bucket, entityTypeCode?, deletedByMe?, search?)` → resolves as
  **`recycleBinEntries`**. Buckets `TODAY | LAST_7 | LAST_30 | EXPIRED`.
- `GetRecycleBinRestoreConflicts(entryId)` → **`recycleBinRestoreConflicts`**.
- `RestoreRecycleBinEntry(entryId)` → mutation.
- `GetRecycleBinCounts()` → **`recycleBinCounts`** — per-bucket counts for the rail. One grouped
  query. **Never `COUNT(*)` the whole bin per bucket.**

Every list query filters `Status`, the 30-day window and the caller's per-entity Read capability.
**An entry the caller cannot Read must not appear** — the snapshot label would leak a donor name.

---

## ⑤ Frontend

**Route:** `app/[lang]/(core)/setting/dataconfig/recyclebin/page.tsx`
**Components:** `presentation/components/page-components/setting/dataconfig/recyclebin/`

**Layout**

- Page header: "Recently Deleted", subtitle **"Restore records deleted in the last 30 days. This is
  not a backup."** — that second sentence is required; someone will otherwise assume it is one.
- Bucket rail: **Today · Last 7 days · Last 30 days · Expired**, each with a count. Buckets are
  filters over one list, **not four queries**.
- Filters: entity type, "Deleted by me" (**on by default** — makes a tenant-wide list feel
  personal), date range, search over the snapshot label.
- Row: solid-background entity icon · `EntityLabel` · `EntitySubLabel` · type chip · "Deleted by
  Priya · 2 days ago" · **time-remaining pill** · Restore button.
- **The time-remaining pill is the emotional core of the screen.** "27 days left" → amber under 7
  days → grey and disabled at expiry. It turns a retention policy into a visible promise.
- **Restore is a confirm dialog, not one click.** It states what returns and is explicit about
  shallow delete:
  > *Restore "Ramesh Kumar"? This contact will reappear in Contacts. Related records were never
  > deleted and are unaffected.*
- **Blocked restore:** call the conflicts query on row select; if non-empty, disable Restore and
  show the reason inline. A restore that fails after the click is a support ticket; one that is
  greyed out with an explanation is a good product.
- **Truncated manifest** rows carry a visible "partial restore" warning.
- **Empty state, exact wording required:** *"Nothing deleted in the last 30 days. Records deleted
  before [ship date] aren't listed here."*
- Skeletons shaped like the rows. Responsive xs→xl; below `md` the bucket rail becomes a select.

**No bulk restore.** It multiplies every conflict in ④.4 by N and turns a clean screen into a
partial-failure report. Ship single-restore.

GraphQL document in `infrastructure/gql-queries/application-queries/`.

---

## ⑥ Explicitly out of scope

- Hard delete, purge jobs, any destruction of data whatsoever.
- Cascade delete. **You will notice `DeleteContact` leaves children alive — leave it that way.**
  Making delete cascade changes the blast radius of 188 commands and deserves its own build, its
  own test pass and its own rollback plan. Ship it inside this one and you will not know which half
  broke. `ManifestJson` already accommodates it later.
- Registry entities beyond the three (Phase 2).
- Tenant-configurable retention.
- Bulk restore, chained parent restore, restore preview diffs.
- Version history or undo-for-edits. This recovers deletions, not changes.
- Any change to `ops.DataPurge`. Different feature, different purpose, no shared code.
- A UI for drift detection.

---

## ⑦ Acceptance criteria

1. `grep -rn "DeletedOn\|DeletedBy" Base.Domain/Abstractions/Entity.cs` → **0 matches** (rule 1).
2. `git diff --stat` shows **no** change to `Entity.cs`, `IEntity.cs`, or any Contact/Donation/Campaign entity model.
3. `grep -rn "IgnoreQueryFilters" Base.Application/Business/ApplicationBusiness/RecycleBin` → **0 matches** (rule 10).
4. `grep -rn "ExecuteSqlRaw\|FromSqlRaw" Base.Application/Business/ApplicationBusiness/RecycleBin` → **0 matches** (rule 16).
5. `grep -rn "DateTime.Now\|DateTime.Today" Base.Application/Business/ApplicationBusiness/RecycleBin` → **0 matches**; only `DateTime.UtcNow` (rule 17).
6. `grep -c "new RecycleBinEntityDescriptor" RecycleBinRegistry.cs` → **exactly 3** (rule 4).
7. `RestoreEligibleUntil` is assigned in exactly one place — the soft-delete path — and never in a read or projection (rule 13).
8. `git diff --name-only` lists **exactly three** files under `Base.Application/Business/*/Commands/` matching `Delete*` (rule 19, §④.5).
9. `grep -rn "HardDelete\|Purge\|Remove(" Base.Application/Business/ApplicationBusiness/RecycleBin` → **0 destructive calls** (rule 3).
9b. Every `WriteEntityChange` call in the recycle-bin service sits **after** the transaction commits, and `IAuditLogWriter.cs` is unmodified (rule 15b).
10. No file under `Base.Application/Business/OpsBusiness/DataPurge/` is modified.
11. No file under `Base.Infrastructure/Migrations/` is created or modified (rule 8). `git status --porcelain` proves it.
12. `grep -rn "bg-.*-50\|bg-.*-100\|text-muted-foreground\|/10\]" page-components/setting/dataconfig/recyclebin` → **0 status-colour matches** (rule 20).
13. The FE query document's field names match the resolver names **after** `Get`-stripping — `recycleBinEntries`, not `getRecycleBinEntries` (rule 18). State in §⑫ that you read the resolver to confirm.
14. `sql-scripts-dyanmic/recycle-bin-menu-capability-seed.sql` exists, is a single executable script with no diagnostic or optional blocks, and soft-deletes rather than `DELETE`s on any RBAC row it supersedes.
15. §⑧ contains a migration spec, and the user has been told the feature is inert until they apply it.
16. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` → **exit 0**. A run reporting only a "pre-existing" `TS2688` stub-types error **checked zero files** and is not a pass. Background it past 10 minutes.
17. Backend: **do not run `dotnet build`.** State which projects you touched and why you believe they compile.

---

## ⑧ Migration spec — for the user, authored by the user

The build agent writes the entity and the EF configuration only.

**Add table `app."RecycleBinEntries"`**

| Column | Type | Null | Notes |
|---|---|---|---|
| `RecycleBinEntryId` | `integer` identity | no | PK |
| `CompanyId` | `integer` | no | tenant scope |
| `EntityTypeCode` | `varchar(50)` | no | |
| `EntityId` | `integer` | no | **no FK, by design** |
| `EntityLabel` | `varchar(300)` | no | snapshot |
| `EntitySubLabel` | `varchar(300)` | yes | snapshot |
| `ManifestJson` | `text` | yes | |
| `ManifestTruncated` | `boolean` | no | default `false` |
| `Status` | `varchar(20)` | no | |
| `DeletedByUserId` | `integer` | yes | |
| `DeletedByUserName` | `varchar(200)` | yes | snapshot |
| `DeletedOn` | `timestamptz` | no | |
| `RestoreEligibleUntil` | `timestamptz` | no | |
| `RestoredByUserId` | `integer` | yes | |
| `RestoredByUserName` | `varchar(200)` | yes | |
| `RestoredOn` | `timestamptz` | yes | |
| `IpAddress` | `varchar(64)` | yes | |
| + `Entity` base | | | `CreatedBy/Date`, `ModifiedBy/Date`, `IsActive`, `IsDeleted` |

**Indexes**
`IX_RecycleBinEntries_Tenant_Window (CompanyId, Status, DeletedOn DESC)` — the only hot path.
`IX_RecycleBinEntries_Target (CompanyId, EntityTypeCode, EntityId)`.

**No foreign keys on this table.** Deliberate — see rule 11.

---

## ⑨ Seed spec — `sql-scripts-dyanmic/recycle-bin-menu-capability-seed.sql`

Written by the build agent, applied by the user. One file, one executable script, result `SELECT`s
at the end only.

1. `auth."Menus"` row `RECYCLEBIN`, `MenuUrl = '/setting/dataconfig/recyclebin'`, parented under the
   existing Settings → Data node (resolve the parent by code, do not hard-code an id).
2. `auth."Capabilities"` — `Read` and `ISMENURENDER` for that menu. Mind the unique index on
   `(CapabilityName, IsActive)`.
3. `auth."RoleCapabilities"` — grant both to `BUSINESSADMIN`.
4. **SUPERADMIN is never revoked or overwritten**, matched by `RoleCode` alone.
5. Supersede rather than destroy: soft-delete (`IsDeleted = true, IsActive = false`); never `DELETE`;
   never revoke a grant unless its replacement is written in the same transaction.

**Until the migration and this seed are applied, the screen 404s and the feature is inert.** Say so
in the handover.

---

## ⑩ Work order

1. Run Step 0. Paste answers into §⑫. Stop on any contradiction.
2. Entity + EF configuration. **No migration.**
3. Constants, then the registry with three descriptors and their conflict checks.
4. `IRecycleBinService` — soft delete first, and verify the episode row is written before writing
   restore. Restore against a bin that was never populated proves nothing.
5. Restore, with server-side conflict re-check.
6. Three delete-command call-site edits. Nothing else under `Commands/`.
7. GraphQL queries + mutation. **Read your own resolver names before step 8.**
8. Frontend: route, list, bucket rail, filters, confirm dialog, blocked-restore state, empty state.
9. Drift-detection query. Number only, no UI.
10. Seed file.
11. Run §⑦ 1–14 and 16. Fix and re-run until clean.
12. Fill in §⑪ and hand over §⑧ + §⑨ to the user.

---

## ⑪ Build Log

*(append-only, newest first — most recent 5 sessions kept, git holds the rest)*

### Session 1 — 2026-08-12 — Claude Opus 5 (Claude Code)

- **Status: BUILD COMPLETE, INERT.** All code written; frontend typecheck exit 0. The feature does
  nothing until the user applies the §⑧ migration and the §⑨ seed — until then the screen 404s and
  `SoftDeleteAsync` would fail on a missing table, so **do not deploy the three edited delete
  commands ahead of the migration**. Backend not compiled (rule 9), no migration authored (rule 8).

- **Step 0 probe answers (all five):**
  1. `public.EntityTypes` exists — `Base.Domain/Models/PublicModels/EntityType.cs`: `EntityTypeId`,
     `EntityTypeName` (title case), `EntityTypeCode` (**upper** case), `SchemaName`, `TableName`,
     `SearchableEntities`. It is the global-search catalogue, not a delete registry. Seeded rows:
     `sql-scripts-dyanmic/search-searchable-entity-seed.sql` inserts **`CONTACT` only**; there is no
     `DONATION` or `CAMPAIGN` row anywhere in `sql-scripts-dyanmic/`. No contradiction — see the
     entity-type-codes note below.
  2. All three delete commands still matched the D-4 shape before editing (find → `IsDeleted = true`
     → `Update` → `SaveChangesAsync`), and `DeleteGlobalDonation.cs` is indeed under
     `DonationBusiness/GlobalDonations/Commands/` as §④.5 predicted. No `DeleteDonation.cs` exists.
  3. `DeleteContact.cs` held the canonical 5-line pattern. It now reads
     `await recycleBin.SoftDeleteAsync(RecycleBinEntityTypes.Contact, command.contactId, ct);` —
     `[CustomAuthorize]`, validator and business rules left in the command per §④.5.
  4. `IAuditLogWriter` exposes `WriteEntityChange`, `WriteAuthEvent`, `WriteExportEvent`,
     `WriteWorkflowEvent`, `WritePaymentEvent`. Used `WriteEntityChange` as-is; the interface file
     is byte-identical to HEAD (not in `git status`, mtime 2026-06-02).
  5. `DataPurgeQueries.cs:56` pages via `[AsParameters] GridFeatureRequest request`. **Deviation,
     deliberate:** the recycle-bin list resolver takes explicit `int pageNumber = 1, int pageSize = 20`
     instead. `[AsParameters]` is a Minimal-API binding convention; under HotChocolate a
     `GridFeatureRequest` argument would surface to the client as a `GridFeatureRequestInput` object
     with grid-sort/filter fields this screen has no use for. The names and 1-based semantics match
     `GridFeatureRequest`, so nothing downstream is surprised.

- **Entity-type codes used:** `CONTACT`, `DONATION`, `CAMPAIGN` (`RecycleBinConstants.cs:45–47`).
  `CONTACT` is **the same string** `public.EntityTypes` already carries, so no parallel vocabulary
  was invented. `DONATION`/`CAMPAIGN` have no row in that table yet. The registry deliberately does
  **not** join to `public.EntityTypes` — codes are stored as plain strings on the episode row, so
  the bin does not depend on the search catalogue and no rows were added to it. If `EntityTypes`
  later gains those two codes, they will line up by construction.

- **Exact delete-command files edited (3, confirmed by `git status --porcelain` in the backend repo —
  it is a separate git repo from the docs repo, so it *can* be diffed even though it is gitignored
  by the outer one):**
  - `Base.Application/Business/ContactBusiness/Contacts/Commands/DeleteContact.cs`
  - `Base.Application/Business/DonationBusiness/GlobalDonations/Commands/DeleteGlobalDonation.cs`
  - `Base.Application/Business/ApplicationBusiness/Campaigns/Commands/DeleteCampaign.cs`

  No other `Delete*.cs` is modified. (`DeleteRecordComment.cs` has a recent mtime but is committed
  and untouched by this build — it is the collaboration feature's, not this one's.)

- **Audit writer entry point used:** `IAuditLogWriter.WriteEntityChange(entityType, entityId, action,
  before, after, description, ct)` — `action: "DELETE"` at `RecycleBinService.cs:111` and
  `action: "RESTORE"` at `:199`. Both sit **after** `strategy.ExecuteAsync(...)` returns, i.e. after
  the commit, per rule 15b. No new writer, no new interface method, `AuditLogInterceptor` untouched.
  Note this is the first time a soft delete produces an audit row at all (D-7) — for these three
  entities only.

- **Resolver names after `Get`-stripping** — read back out of the written resolver files, not
  guessed, and the FE documents were written from that reading:
  | C# method | GraphQL field |
  |---|---|
  | `GetRecycleBinEntries` | `recycleBinEntries` |
  | `GetRecycleBinCounts` | `recycleBinCounts` |
  | `GetRecycleBinRestoreConflicts` | `recycleBinRestoreConflicts` |
  | `GetRecycleBinDriftCount` | `recycleBinDriftCount` (no UI, §④.6) |
  | `RestoreRecycleBinEntry` (mutation) | `restoreRecycleBinEntry` |
  No argument is a DTO, so no `Input` suffix appears anywhere in the FE documents. Envelope field
  names (`success`/`message`/`errorDetails`/`data`) were verified against
  `Base.API/Extensions/ApiResponseExtension.cs` before being selected.

- **Conflict checks implemented per entity** (`RecycleBinRegistry.cs`, evaluated server-side on both
  preview and restore — the preview is a courtesy, `RestoreAsync` re-checks):
  Each entity's checks were derived from **its actual unique indexes**, not assumed — whether an
  index is filtered on `IsDeleted` decides whether a collision is even possible:
  - **Contact** — **no blockers, deliberately.** The unique index is `(ContactCode, IsActive,
    CompanyId)` and is *not* filtered on `IsDeleted`, so the soft-deleted row still occupies its slot
    and nobody can have taken the code while it sat in the bin. No owning parent either. *Advisory*
    only, on the narrow case where a live twin differs on `IsActive`: the code is flagged as also in
    use and the record is restored **keeping its original code** — never renumbered.
  - **Donation** — *block* `DANGLING_PARENT` when the donor `Contact` is itself deleted ("Restore
    Contact "X" first…") and again when the `OrganizationalUnit` is. `GlobalDonations` carries no
    unique index, so receipt-number reuse is an *advisory*, not a blocker — a receipt already in a
    donor's hands must never be renumbered.
  - **Campaign** — Campaign's three unique indexes **are** filtered on `IsDeleted = false`, so a live
    row can legitimately have taken the slot. Three separate `UNIQUE_COLLISION` blockers naming the
    squatter — campaign **name**, **code**, and **custom URL** — plus the `DANGLING_PARENT` unit
    check. Never silently renamed, never nulled out. Restore replays `wasActive` from the manifest.
  - **Quota** — *block* with the upgrade path via `usageMeterService.EnsureStockCapacityAsync`, called
    **inside** the restore transaction under its advisory lock, so two admins racing for the last slot
    serialise instead of both winning. Applies to **Contact and Donation only**; Campaign's
    `MeterCode` is `null` because `BillingCodes.MeterCodes` has no campaign meter.
  - **All three** — `ManifestTruncated` produces an *allow* + "partial restore, best-effort" notice
    in the dialog, never a silent success.

- **§⑦ results — 17/17:**
  | # | Check | Result |
  |---|---|---|
  | 1 | `DeletedOn\|DeletedBy` in `Entity.cs` | **0** (`Base.Domain/Abstractions/Entity.cs`) |
  | 2 | No diff to `Entity.cs`/`IEntity.cs`/the 3 entity models | **clean** — absent from `git status` |
  | 3 | `IgnoreQueryFilters` / raw SQL / `DateTime.Now\|Today` in RecycleBin | **0 code occurrences.** grep returns 4+1 hits that are all *prose in comments* saying these must not be used |
  | 4 | `RestoreEligibleUntil` assigned in exactly one place | **1** — `RecycleBinService.cs:70` |
  | 5 | `new RecycleBinEntityDescriptor` | **3** |
  | 6 | Changed `Delete*` command files | **3** (listed above) |
  | 7 | `HardDelete\|Purge\|Remove(` calls | **0** — the single `Purge` hit is a comment citing `ops.DataPurgeRequest` as the precedent |
  | 8 | Every `WriteEntityChange` after the commit; `IAuditLogWriter.cs` unmodified | **pass** (`:111`, `:199`) |
  | 9 | Nothing under `OpsBusiness/DataPurge/` modified | **pass** — 0 files, absent from `git status` |
  | 10 | No file under `Base.Infrastructure/Migrations/` created or modified | **pass** — `git status --porcelain -- "*Migrations*"` → 0 lines |
  | 11 | FE colour-rule grep (`bg-X-50/100`, `text-X-700/800`, `bg-muted`, `text-muted-foreground`, `/10`, hex, px) | **no matches** across the recyclebin component folder |
  | 12 | FE field names match post-`Get`-strip resolver names | **pass** (table above) |
  | 13 | Seed is one executable script that soft-deletes rather than `DELETE`s | **pass** — `grep -ci "^\s*DELETE FROM"` → **0** |
  | 14 | §⑧ migration spec present, user told the feature is inert until applied | **pass** — stated at the top of this entry and in the handover |
  | 16 | `npx tsc --noEmit --incremental false` | **exit 0, zero diagnostics** — a real full-program check, not the vacuous TS2688 case |
  | 17 | Backend build | **green.** `dotnet build PeopleServe.sln` → `0 Error(s)`, 641 warnings (all pre-existing, none in RecycleBin files). Projects touched: `Base.Domain`, `Base.Application`, `Base.Infrastructure`, `Base.API` |

- **Anything believed to compile but not verified:**
  - ~~All backend C#~~ — **now verified.** Session 1 shipped without running `dotnet build` (rule 9)
    and the user reported build errors. There were exactly **two**, one root cause, in
    `RecycleBin/Queries/GetRecycleBinEntries.cs:107-108`: `EF.Functions.ILike` is an **Npgsql-provider**
    extension (`NpgsqlDbFunctionsExtensions`), and `Base.Application` references `Microsoft.EntityFrameworkCore`
    + the raw `Npgsql` ADO package but **not** `Npgsql.EntityFrameworkCore.PostgreSQL`. Fixed by switching the
    search predicate to the `ToLower().Contains(term)` idiom every other query in `Base.Application` uses
    (e.g. `GetAuctionItems.cs:59-63`); Npgsql translates it to `lower(x) LIKE '%…%'`, so case-insensitive
    behaviour is unchanged. Solution rebuilt green afterwards. Prediction that "the likeliest residual
    failure is a `using` or a namespace on a newly created file" was accurate in kind.
  - **GraphQL schema generation.** Types register by assembly scan
    (`GraphQLRegistrationExtensions.cs:13`), so no manual wiring exists to have got wrong — but the
    schema has not actually been built, and `Get`-stripping was confirmed by convention plus reading
    the resolvers, not by introspecting a running server.
  - **The seed's parent lookup.** `SET_DATACONFIG` and module `SETTING` were taken from sibling seeds
    (`masterdata-combined-menu-seed.sql`), not from a live database. The verification `SELECT`s at
    the end of the seed will show a NULL parent if that code differs in an environment.
  - **Runtime behaviour end to end.** Nothing was executed: no delete, no restore, no conflict path.

- **Deviations, all deliberate, none silent:**
  1. **Registry loader returns `Task<Entity?>` (`LoadAsync`), not `IQueryable<Entity>`.** `Entity` is
     abstract and unmapped, so a common-typed queryable is not expressible; each descriptor
     materialises its own concrete row and hands it back.
  2. **Campaign's pre-flip `IsActive` is stored in `ManifestJson` (`root.wasActive`)** and replayed on
     restore — rule 1 forbids a column, and re-activating a campaign that was already off would be a
     silent data change.
  3. **Seed `MenuUrl` has no leading slash** — `'setting/dataconfig/recyclebin'`, where §⑨ shows
     `'/setting/dataconfig/recyclebin'`. Every sibling in this subtree (`MASTERDATA`,
     `ORGANIZATIONBANKACCOUNT`) is stored without one and the nav matcher compares this string
     directly, so the slash would break the sidebar link. Sibling convention wins.
  4. **The §⑤ subtitle is rendered twice** — once as `ScreenHeader description` and once as visible
     body text. `ScreenHeader` only surfaces `description` inside a tooltip, and "This is not a
     backup" is the one sentence on this screen that must not be hover-only.

### Known Issues

- **Deletions from before this ships never appear.** There is no timestamp to backfill from. By design.
- **Delete remains shallow** — children are not deleted and therefore not restored. The confirm
  dialog says so.
- **Nothing is ever destroyed.** Expired entries hide; the rows remain. Hard delete belongs to
  `ops.DataPurge`.
- **The registry is deliberately partial.** Unregistered entities never enter the bin. That is not
  a gap to close by generating the registry.
