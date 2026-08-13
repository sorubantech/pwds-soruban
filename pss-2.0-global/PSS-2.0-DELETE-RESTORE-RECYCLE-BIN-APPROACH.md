# PSS 2.0 — Global Delete, Recently Deleted & Restore

**Type:** architecture approach document (not a build prompt)
**Status:** FOR REVIEW — decisions marked ⚑ need your sign-off before a build prompt is written
**Scope:** MVP production readiness. Deliberately smaller than the ambition in the brief.

---

## ① The headline

**We are closer than the brief assumes, and the gap is not where you'd expect.**

Soft delete already exists everywhere. What is missing is not the *delete* — it is the **evidence
that a delete happened**. Today a deleted row is indistinguishable from a row that was deleted two
years ago. There is no timestamp, no actor, no record of the episode.

So "Deleted today / last 7 days / last 30 days" is **not a query we can write against the current
schema.** That single fact drives the entire design.

---

## ② What is on disk today — verified, not assumed

| Fact | Evidence | Consequence |
|---|---|---|
| Every entity inherits `IsDeleted` from a base class. | `Base.Domain/Abstractions/Entity.cs` — `CreatedBy/CreatedDate/ModifiedBy/ModifiedDate/IsActive/IsDeleted`. | Soft delete is universal. Good starting point. |
| **There is no `DeletedOn` and no `DeletedBy` on any business entity.** | Same file. The only `Deleted*` columns anywhere are `HardDeletedOn/By` on `ops.DataPurgeRequest`. | **The retention buckets in your brief are unanswerable today.** This is the load-bearing gap. |
| The global query filter is **tenant-only**, not delete-aware. | `ApplicationDbContext.ApplyTenantFilters` (lines 61–131) builds `CurrentTenantId == null ‖ CompanyId == CurrentTenantId ‖ IsSystem`. Nothing about `IsDeleted`. | Soft-deleted rows are **still returned by EF** unless each query hand-writes `IsDeleted != true`. A recycle bin does not have to fight a filter — but it also means deleted rows leak wherever a guard was forgotten. |
| **188 hand-written Delete commands.** | `find Base.Application/Business -ipath "*delete*" -name "*.cs"` → 188. | Any design that requires editing every delete site is dead on arrival. |
| Each one is the same 5 lines. | `DeleteContact.cs`: find → `contact.IsDeleted = true` → `Update` → `SaveChanges`. | The pattern is uniform, which makes a central service viable. |
| **Delete does not cascade.** `DeleteContact` flips the contact and nothing else — addresses, phones, emails, relationships all stay `IsDeleted = false`. | `DeleteContact.cs` handler, steps 1–3. | Restore is *easy* today. It also means our current delete is shallower than users think. **Do not fix this in the same build** (§⑧). |
| **A near-identical system already exists at platform level.** | `ops.DataPurgeRequest` + `SoftDeletePurgeTarget` / `RestorePurgeTarget` / `HardDeletePurgeTarget` / `PurgeScopeResolver` / `GetPurgeCandidates` / `GetPurgePreview`. | **This is the blueprint. We generalise it downward, we do not invent an architecture.** |
| Audit infrastructure exists. | `audit.audit_no_seq` sequence + `AuditLogWriter`; `ops.PlatformAuditLog`. | Recycle bin writes audit rows through the existing writer. No new audit plumbing. |
| No blob storage is provisioned. | Standing project fact. | Deleting a Document deletes **metadata only**. Say so in the UI. |

### The seventh instance of the same pattern

`ops.DataPurgeRequest` already solved this problem properly for LEAD and TENANT targets. Its design
notes are worth quoting because they are the four rules we inherit:

1. `TargetId` carries **no foreign key** — the row must outlive its target.
2. `TargetName` is a **snapshot** — after a hard delete there is nothing left to join to.
3. **No `CompanyId`** on that particular table (it is platform-global) — but ours is tenant-scoped,
   so ours *does* have one. This is the one place we deliberately diverge.
4. The episode row **is never deleted** — not on restore, not on hard delete.

Plus the mechanism that makes restore possible at all: **`ManifestJson`** — the exact row ids that
were flipped, per table, captured *before* the flip, with a `ManifestTruncated` flag when the list
hits a cap.

---

## ③ The mental model

> **A delete is an episode, not a flag. The flag says a row is gone; the episode says who removed
> what, when, and exactly which rows to put back.**

Everything below follows from that one sentence.

---

## ④ The architecture

```
  188 Delete commands
          │  (each keeps its own validation, authorization, business rules)
          ▼
  IRecycleBinService.SoftDeleteAsync(entityTypeCode, id, ct)
          │
          ├─► resolve entity via RecycleBinRegistry  (curated, not reflected)
          ├─► capture label snapshot + manifest of row ids
          ├─► flip IsDeleted = true
          ├─► INSERT app.RecycleBinEntries  (the episode)
          └─► AuditLogWriter.Write(DELETE)
                     │  all inside ONE transaction
                     ▼
        Recently Deleted  ── query app.RecycleBinEntries WHERE Status = DELETED
                     │                AND CompanyId = tenant
                     │                AND DeletedOn >= now - 30d
                     ▼
        RestoreAsync ──► replay manifest ──► IsDeleted = false ──► Status = RESTORED
                     │
                     ▼
        Retention expiry ──► Status = EXPIRED  (hidden, NOT destroyed — see ⚑D5)
```

### ⚑ D1 — The episode table carries the metadata. Entity tables are not touched.

**Decision: add NO columns to business tables. Not `DeletedOn`, not `DeletedBy`.**

The obvious move is to add `DeletedOn` / `DeletedBy` to the `Entity` base class. Resist it. That
base class is inherited by *every* table in the product, so it is a migration touching hundreds of
tables, on a live database, to store data that the episode row already holds. The cost/benefit is
terrible and it is exactly the kind of change that turns a two-week feature into a two-month one.

**Trade-off, stated honestly:**

- Rows soft-deleted **before this ships** have no episode and will never appear in Recently Deleted.
  Recently Deleted starts from the day we deploy. That is acceptable and we say so in the empty state.
- Rows deleted by a path that **bypasses the service** are invisible too. Mitigation in ⚑D3.

**When we would revisit:** if we ever need "show me everything deleted, including pre-launch", or
per-row delete attribution for compliance export. Neither is an MVP need.

### The table

```
app.RecycleBinEntries
  RecycleBinEntryId    int PK
  CompanyId            int NOT NULL          -- tenant scope; picks up ApplyTenantFilters by convention
  EntityTypeCode       varchar(50) NOT NULL  -- CONTACT | DONATION | CAMPAIGN | ...
  EntityId             int NOT NULL          -- deliberately NOT a foreign key (rule 1)
  EntityLabel          varchar(300) NOT NULL -- snapshot: "Ramesh Kumar" (rule 2)
  EntitySubLabel       varchar(300) NULL     -- snapshot: "ramesh@x.org · Donor"
  ManifestJson         text NULL             -- per-table row ids flipped, captured pre-flip
  ManifestTruncated    bool NOT NULL default false
  Status               varchar(20) NOT NULL  -- DELETED | RESTORED | EXPIRED | PURGED
  DeletedByUserId      int NULL
  DeletedByUserName    varchar(200) NULL     -- snapshot; the user may leave the org
  DeletedOn            timestamptz NOT NULL
  RestoreEligibleUntil timestamptz NOT NULL  -- stamped AT DELETE TIME (rule below)
  RestoredByUserId     int NULL
  RestoredByUserName   varchar(200) NULL
  RestoredOn           timestamptz NULL
  IpAddress            varchar(64) NULL
  + Entity base (CreatedBy/Date, ModifiedBy/Date, IsActive, IsDeleted)

  INDEX IX_RecycleBin_Tenant_Window  (CompanyId, Status, DeletedOn DESC)
  INDEX IX_RecycleBin_Target         (CompanyId, EntityTypeCode, EntityId)
```

**`RestoreEligibleUntil` is stamped once, at delete time.** Copied straight from
`DataPurgeRequest.HardDeleteEligibleOn` and for the same reason: if an admin later changes the
retention setting from 30 to 7 days, that must not retroactively destroy someone's recovery window.
Policy changes apply to future deletions only. This is a compliance property, not a nicety.

**The row is never deleted.** Restored, expired, purged — the episode survives all three. It is the
audit trail.

### ⚑ D2 — A curated registry, not reflection

```csharp
public sealed record RecycleBinEntityDescriptor(
    string  EntityTypeCode,          // "CONTACT"
    string  DisplayName,             // "Contact"
    string  Icon,                    // "ph:user"
    string  MenuCode,                // for the capability check — reuses existing RBAC
    Func<IApplicationDbContext, IQueryable<Entity>> Query,
    Func<Entity, (string Label, string? SubLabel)> Snapshot,
    Func<IApplicationDbContext, int, CancellationToken, Task<IReadOnlyList<string>>> RestoreConflicts
);
```

Hand-curated, exactly like `billing.Features`. **Do not generate it from `auth.Modules`, the menu
tree, or by scanning for `IsDeleted`.** A generic scanner would happily offer to restore a junction
row, a settings KV pair or an audit entry — all of which would be either meaningless or dangerous.

**MVP coverage: 8–12 top-level entities**, the ones a user genuinely mourns:

Contact · Donation · Campaign · Event · Grant · Case · Volunteer · Family · Pledge · Document

Explicitly out: child rows (addresses, phone numbers, line items), configuration, RBAC, audit,
anything in `ops`/`billing`/`sett`. Unregistered types simply never reach the bin — their delete
behaves exactly as it does today.

### ⚑ D3 — 188 commands: three call-sites, not 188 rewrites

Do **not** touch all 188. Touch only the delete commands for the registered entities (≈10 files).
Each becomes:

```csharp
// was: contact.IsDeleted = true; dbContext.Contacts.Update(contact); await SaveChangesAsync(ct);
await recycleBin.SoftDeleteAsync(RecycleBinEntityTypes.Contact, contactId, ct);
```

Validation, `[CustomAuthorize]` and business rules stay in the command where they belong. The
service owns only the mechanics of the episode.

**Drift detection instead of enforcement.** We cannot stop a future developer writing
`x.IsDeleted = true` by hand. Instead ship one health query that finds registered-entity rows with
`IsDeleted = true` and no matching bin entry, and surface the count on the platform ops console.
Cheap, honest, catches the mistake in review rather than in production.

### ⚑ D4 — Restore must be pre-checked, and is allowed to fail

This is the part most implementations get wrong. **Restoring is not the inverse of deleting**,
because the world moved on:

| Conflict | Example | Handling |
|---|---|---|
| **Unique index collision** | Contact's email was reassigned to a new contact after the delete. | Block, name the conflict, offer nothing else. Never silently rename. |
| **Dangling parent** | Restoring a Donation whose Campaign was itself deleted. | Block with "Restore *Campaign X* first." Chained restore is not MVP. |
| **Quota / entitlement** | Tenant is at 5,000 contacts on their plan; restoring makes 5,001. | Block with the upgrade path. Quota is a hard gate (existing rule). |
| **Number sequence reuse** | The record's business code was re-issued to a new record. | Restore, keep the original code, flag the duplicate. Do not renumber a restored record — it may be printed on a receipt. |
| **Truncated manifest** | Blast radius exceeded the id cap. | Restore best-effort **and say so in the UI**, exactly as `DataPurgeRequest.ManifestTruncated` requires. |

`RestoreConflicts` on the descriptor returns the list. The UI calls it on hover/select and disables
Restore with the reason visible **before** the user clicks. A restore that fails after the click is
a support ticket; a restore that is greyed out with an explanation is a good product.

### ⚑ D5 — Retention expiry HIDES. It does not destroy.

**MVP does not hard-delete anything.** At day 31 the entry flips to `EXPIRED`, Restore disappears,
and the underlying row stays exactly where it is with `IsDeleted = true`.

Why I am recommending against auto-purge in MVP:

1. **Delete does not cascade today** (§②). A hard delete would leave live children pointing at a
   destroyed parent, or trip FK constraints at 2am in a background job. Both are worse than keeping
   a dead row.
2. **We already have the erasure story.** GDPR right-to-erasure is served by the existing
   `ops.DataPurge` flow — requested, reasoned, cooling-off, manifest-backed, operator-approved.
   That is the correct place for irreversible destruction, and it is already built.
3. Storage pressure from soft-deleted CRM rows is a rounding error at our scale.

**When we would build it:** when the first tenant asks, or when a table's dead-row ratio is
measurably hurting queries. At that point it is a scheduled job that walks `EXPIRED` entries and
replays the manifest through the existing hard-delete machinery — a small addition, precisely
because the manifest is already there.

### ⚑ D6 — Placement: Settings, not Profile. And who sees what.

Your brief says Profile/Settings. I'd push back gently on Profile.

**A deleted donor is tenant data, not personal data.** If it lives in the deleting user's profile,
then when that user leaves the organisation their deletions become unreachable. Recently Deleted
belongs in **Settings → Data → Recently Deleted**, tenant-scoped, with a **"Deleted by me"** filter
chip on by default so it still *feels* personal.

**Visibility model (MVP):** an entry is visible if the user holds **Read** on that entity's
`MenuCode`. **Restore requires Delete** on the same MenuCode. No new capability, no new seed rows,
no new RBAC concepts — it reuses the two-check model we already have.

Rationale: if you were never allowed to see contacts, a deleted contact's name should not leak to
you through the bin. And if you were trusted to delete it, you are trusted to put it back.

### D7 — Multi-tenancy, security, performance

- **Tenant isolation is automatic.** `CompanyId` on the table means `ApplyTenantFilters` attaches by
  convention (verified mechanism, lines 61–131). Do not add `IgnoreQueryFilters()` here — that is
  for `ops`/`billing` platform-global tables only, and using it here would be a cross-tenant leak.
- **`EntityId` is not an FK, so it is not validated by the database.** Every read path must
  re-resolve through the registry and re-check the tenant, never trust the stored id alone.
- **The label is a snapshot and may be stale.** That is correct behaviour — it shows what was
  deleted, not what exists now.
- **The window query is the only hot path**, and `(CompanyId, Status, DeletedOn DESC)` covers it.
  Keep the default page at 25 with cursor paging. Never `COUNT(*)` the whole bin for a badge.
- **UTC everywhere.** `timestamptz`, `DateTime.UtcNow`, bucket boundaries built with
  `DateTimeKind.Utc`. Never `DateTime.Today` in an EF predicate. The "Deleted today" bucket is
  computed in the **tenant's** timezone at the presentation layer, not in SQL.
- **Rate-limit restore.** A scripted restore-loop is a plausible abuse vector against quota gates.
- **DR:** the bin adds no new backup requirement. It is one ordinary tenant table, and because
  nothing is destroyed, point-in-time recovery semantics are unchanged.

---

## ⑤ The UX

**Settings → Data → Recently Deleted.**

- **Bucket rail:** Today · Last 7 days · Last 30 days · Expired. Counts on each. Buckets are
  filters over one list, not four queries.
- **Row:** entity icon (solid `bg-X-600` + white) · label · sub-label · type chip · "Deleted by
  Priya · 2 days ago" · time-remaining pill · **Restore**.
- **The time-remaining pill is the emotional core.** "27 days left" → amber under 7 → grey and
  disabled at expiry. It is what makes the retention policy feel like a promise rather than a rule.
- **Restore is a confirm, not a one-click.** State exactly what returns: *"Restore Ramesh Kumar?
  This contact will reappear in Contacts. 3 related records were not deleted and are unaffected."*
  That last sentence is the shallow-delete truth from §②, said out loud.
- **Blocked restore** shows the reason inline from `RestoreConflicts` — greyed button, tooltip with
  the actual conflict.
- **Empty state must be honest:** *"Nothing deleted in the last 30 days. Records deleted before
  [ship date] aren't listed here."*
- **Filters:** type, deleted-by, date range, search over the snapshot label.
- **No bulk restore in MVP.** Bulk restore multiplies every conflict in ⚑D4 by N and turns a clean
  UX into a partial-failure report. Ship single-restore, watch whether anyone asks.

---

## ⑥ What this is NOT

- Not a version history / undo stack. It recovers deletions, not edits.
- Not a backup. Say this in the UI subtitle; someone will otherwise assume it is one.
- Not the GDPR erasure path — that is the existing `ops.DataPurge` flow, and the two must not be
  conflated. One is *"I didn't mean that"*; the other is *"destroy this permanently, on the record."*
- Not cascade delete. §⑧.
- Not a platform-side feature. Tenant surface only; platform already has DataPurge.

---

## ⑦ MVP phasing

| Phase | Contents | Size |
|---|---|---|
| **1 — the spine** | `app.RecycleBinEntries` + migration · `IRecycleBinService` (SoftDelete / Restore / conflicts) · registry with **3** entities (Contact, Donation, Campaign) · GraphQL query + restore mutation · the Settings screen. | **M** |
| **2 — coverage** | Registry grows to the full 8–12. Pure config plus ~7 one-line command edits. | **S** |
| **3 — hygiene** | Expiry sweep to `EXPIRED` · drift-detection health query on the ops console · restore analytics. | **S** |
| **Later, on demand** | Hard purge job · cascade delete · bulk restore · chained parent restore. | — |

Phase 1 is the honest MVP. Phase 2 is cheap *because* Phase 1 is a registry.

---

## ⑧ The one thing I'd argue with you about

**Do not fix cascade delete in this build.**

You will notice, the first time you test it, that deleting a contact leaves its addresses, phone
numbers and relationships alive. The instinct is to fix that here, since we're in the delete code
anyway.

Don't. Making delete cascade changes the blast radius of **188 existing commands** and every screen
that depends on their current behaviour. It is a genuinely risky change that deserves its own
prompt, its own test pass, and its own rollback plan. Shipping it inside a recycle-bin build means
that when something breaks, you won't know which half broke it.

The manifest design already accommodates cascade later — that is exactly what `ManifestJson` is
for. Build the bin now; widen what it captures when you deliberately choose to.

---

## ⑨ Decisions I need from you

| ⚑ | Decision | My recommendation |
|---|---|---|
| **D1** | Columns on entity tables, or metadata on the episode row only? | **Episode row only.** Legacy deletions stay invisible; we say so. |
| **D2** | Which entities in the registry for Phase 1? | Contact · Donation · Campaign. |
| **D5** | Does expiry destroy data, or just hide it? | **Hide only.** No hard delete in MVP. |
| **D6** | Settings (tenant) or Profile (personal)? | **Settings → Data**, with a "Deleted by me" chip on by default. |
| **D6b** | Visibility rule? | Read-on-entity to see, Delete-on-entity to restore. No new capability. |
| — | Retention: 30 days fixed, or tenant-configurable? | **Fixed 30 in MVP.** Configurable invites the "shorten it retroactively" bug that `RestoreEligibleUntil` exists to prevent. |

Answer these and I'll write `PSS-2.0-RECYCLE-BIN-BUILD-PROMPT.md` in the usual §①–⑫ shape.
