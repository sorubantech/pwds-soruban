# ODP-B3 — Durable Cross-Instance Idempotency Guard

**Status**: ✅ CROSS-INSTANCE GUARD SHIPPED (session 65, migration-free). A
Postgres **session-level advisory lock** (`pg_advisory_lock` / `pg_advisory_unlock`)
now serializes Confirm calls for a given `PaymentSessionId` **across all API
instances** — see `ConfirmOnlineDonation.cs` (ODP-B3 block, `DeriveAdvisoryLockKey`).
This required **no schema change**, so it did not need a user-authored migration.

The `xmin` / atomic-claim options below (Option A / Option B) are now **OPTIONAL
future hardening**, retained for reference. They are NOT required for the P0 gate —
the advisory lock already closes the cross-instance double-charge window. Only
revisit them if you want optimistic-concurrency protection independent of the lock
(e.g. defense-in-depth against a lock acquired on a stale/misrouted connection).
Both remain **user-owned** (they touch the EF model snapshot or seed MasterData).

## Problem

`ConfirmOnlineDonationHandler.Handle` (`ConfirmOnlineDonation.cs`) now serializes
concurrent Confirm calls for the same `PaymentSessionId` using an in-process
`ConcurrentDictionary<string, SemaphoreSlim>` lock (implemented this session — see
`_sessionLocks` / `HandleInner`). That closes the double-charge window **within one
API instance**.

It does **not** close the window across multiple API instances behind a load
balancer / in a scaled-out deployment: two instances can each acquire their own
in-process semaphore for the same `PaymentSessionId` and both read the staging row
as PENDING before either commits COMPLETED, resulting in two gateway charges for
one donation.

## Recommended fix (requires a user-authored migration)

**Option A — Postgres `xmin` optimistic concurrency (preferred, smallest footprint)**

1. Configure `OnlineDonationStaging` as a concurrency-tracked entity via the
   Postgres system column `xmin`:
   ```csharp
   builder.Property<uint>("xmin").HasColumnName("xmin").HasColumnType("xid")
       .ValueGeneratedOnAddOrUpdate().IsConcurrencyToken();
   ```
   This requires **no new column** — `xmin` is a Postgres system column already
   present on every row.
2. In `ConfirmOnlineDonationHandler`, after the in-process lock is acquired and the
   staging row is re-read, catch `DbUpdateConcurrencyException` around the
   `SaveChangesAsync` calls that flip `PaymentStatusId`. On conflict, re-fetch the
   row: if it is now COMPLETED, return the idempotent cached-success response
   (mirrors the existing idempotency branch at the top of `HandleInner`); otherwise
   rethrow.
3. This is a config-only EF change plus a handler catch block — no new column, no
   new MasterData row. The migration only needs to confirm EF's model snapshot
   picks up the shadow concurrency token (Npgsql handles `xmin` natively).

**Option B — Atomic conditional claim via `ExecuteUpdateAsync` (alternative)**

1. Requires a new terminal-ish MasterData `PAYMENTSTATUS` value, e.g.
   `PROCESSING` (seed data only — no schema/table/column change), OR reuse of the
   existing PENDING→COMPLETED/FAILED values with a rows-affected-guarded claim:
   ```csharp
   var claimed = await dbContext.OnlineDonationStagings
       .Where(s => s.OnlineDonationStagingId == staging.OnlineDonationStagingId
                && s.PaymentStatusId == statusPendingId)
       .ExecuteUpdateAsync(s => s.SetProperty(x => x.PaymentStatusId, statusProcessingId), ct);
   if (claimed == 0)
   {
       // Someone else already claimed it — re-read and return idempotent response
       // if COMPLETED, or a "still processing, retry" response otherwise.
   }
   ```
   Precedent for this exact atomic-claim shape already exists in
   `OnlineDonationMapJobRunner.cs` ("Atomic claim Queued → Running").
2. Downside vs Option A: needs a new seeded `PAYMENTSTATUS=PROCESSING` MasterData
   row (data seed, not schema, but still an operational step) and a bit more
   handler branching to interpret the transient PROCESSING state on retries/errors
   (e.g. a crash between claim and charge leaves the row stuck in PROCESSING until
   the ISSUE-25 sweep job — see `onlinedonationpage.md` registry — reclaims it).

**Why Option A is recommended**: zero new rows, zero new columns, smallest
surface area, and Npgsql/EF's built-in `xmin` support is a well-trodden path for
exactly this "avoid last-writer-wins on a captured payment" problem.

## Why Option A / B were NOT used for the P0 gate

Both options touch either the EF model (new shadow property / concurrency token —
arguably schema-adjacent since it changes what EF tracks, even though `xmin`
itself is not a new column) or require a new seeded MasterData value whose
presence cannot be safely assumed without checking the live MasterData table for
this tenant/environment. Per the task's hard constraint ("if a fix seems to need
a schema change, STOP and write a SPEC instead"), a schema-touching approach was
avoided. The advisory lock achieves the same cross-instance guarantee with **zero
schema/model/seed footprint**, so it shipped instead.

## What shipped (session 65 — no schema change)

Two layers in `ConfirmOnlineDonation.cs`, keyed by `PaymentSessionId`:

1. **Fast path — in-process `SemaphoreSlim`** (`_sessionLocks` `ConcurrentDictionary`).
   Cheap serialization for the common single-instance / sticky-session / donor
   browser-retry case; avoids a DB round-trip when the contention is local.
2. **Durable path — Postgres session-level advisory lock** (inside the semaphore).
   On a **dedicated `NpgsqlConnection`** (`configuration.GetConnectionString("Database")`),
   `SELECT pg_advisory_lock(@k)` where `k = DeriveAdvisoryLockKey(sessionKey)` — a
   `SHA256("ODP-CONFIRM|" + sessionKey)` → `Int64` (NOT `string.GetHashCode`, which
   is non-deterministic across processes). `HandleInner` runs while held;
   `pg_advisory_unlock(@k)` in `finally` (a warning on unlock failure is benign —
   closing the connection auto-releases the lock). This serializes Confirm for one
   `PaymentSessionId` across **every** instance sharing the database.

No migration, no new column, no new MasterData row — deployable as-is.

## Optional future hardening (user-owned, NOT required)

Option A (`xmin`) or Option B (atomic claim) above can be layered on later for
defense-in-depth, but are unnecessary for the live-money gate now that the advisory
lock is in place. Pick up only if a topology change (e.g. multiple databases, or a
desire for lock-independent optimistic concurrency) makes them worthwhile.
