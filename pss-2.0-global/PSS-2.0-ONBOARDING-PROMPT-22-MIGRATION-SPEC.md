# PROMPT-22 (§3.6) — Migration spec, user-owned

Backend and frontend code for the in-app notification service is complete and compiles against the
entity model below. **The migration has not been created.** Per standing policy the EF migration is
authored, run and committed by you, not by me. This file is the spec to author it from.

```
cd PSS_2.0_Backend/PeopleServe/Services/Base
dotnet build                                    # prove it compiles first
dotnet ef migrations add Add_Notification_Scope_And_Preferences -p Base.Infrastructure -s Base.API
dotnet ef database update -p Base.Infrastructure -s Base.API
```

The EF configurations already encode every column type and index below, so a scaffolded migration
should match this spec without hand-editing. **Diff it against this list before applying.**

**Unlike P-21, this one is NOT purely additive.** It drops one column, relaxes two columns to
nullable, and drops two existing indexes. Read §5 (Ordering and safety) before running it against
anything with data in it.

---

## 1. `notify.Notifications` — 1 column dropped, 1 relaxed, 3 added

### Dropped

| Column | Why |
|---|---|
| `NotificationTypeId` | `int` NOT NULL whose only ever written value, at every call site in the codebase, was the literal `1`. It pointed at no lookup table and no code ever read it back. Dropping it is the whole change — there is nothing to migrate. |

### Relaxed to nullable

| Column | Was | Now | Why |
|---|---|---|---|
| `ModuleId` | `uuid` NOT NULL, FK → `auth.Modules` | `uuid` **NULL**, same FK | The only writer stamped it from a hardcoded `"GENERAL"` module lookup that returns `Guid.Empty` when the row is absent — i.e. a latent FK violation carrying no information. A PLATFORM-scope notification has no tenant module to point at at all, so "required" could not survive the platform surface. The FK and `OnDelete(Restrict)` are unchanged; only the nullability moves. |

Existing rows keep whatever `ModuleId` they have. Nothing is nulled out.

### Added

| Column | Type | Null | Default | Why |
|---|---|---|---|---|
| `Scope` | `varchar(10)` | no | `'TENANT'` | **The point of the whole prompt.** `TENANT` \| `PLATFORM`. Together with `CompanyId` this *is* the inbox security predicate, which is why it is a plain string and not a MasterData FK — the filter separating a tenant's inbox from the vendor's must not depend on a join to a lookup row an environment can be missing. Server-derived on every write; **never accepted from a client** on any read or write. |
| `SourceEntityType` | `varchar(60)` | yes | — | What the notification is about (`"Lead"`). |
| `SourceEntityId` | `int` | yes | — | …and which one (`42`). Lets a later feature find or revoke the notifications for a record without parsing `ActionUrl`. |

The `'TENANT'` default is what backfills every existing row correctly: every notification that
exists today was written by tenant code for a tenant user. No `UPDATE` statement is needed.

### Indexes — 2 dropped, 3 created

```sql
DROP INDEX notify."IX_Notifications_ToUserId_IsDeleted_CreatedDate";
DROP INDEX notify."IX_Notifications_ToUserId_IsRead_IsDeleted";

CREATE INDEX "IX_Notifications_ToUserId_Scope_IsDeleted_CreatedDate"
  ON notify."Notifications" ("ToUserId", "Scope", "IsDeleted", "CreatedDate");

CREATE INDEX "IX_Notifications_ToUserId_Scope_IsRead_IsDeleted"
  ON notify."Notifications" ("ToUserId", "Scope", "IsRead", "IsDeleted");

CREATE INDEX "IX_Notifications_SourceEntity"
  ON notify."Notifications" ("SourceEntityType", "SourceEntityId");
```

The two old indexes are **dropped, not kept alongside** the new ones. Every inbox read now filters on
`Scope`, so the new indexes are strict supersets with an identical leading column — keeping both
would be write cost on the hottest-inserted table in the module for zero read benefit.

`IX_Notifications_ToUserId_IsStarred_IsDeleted`, `IX_Notifications_Category` and
`IX_Notifications_Priority` are unchanged. If the scaffolded migration tries to recreate them, your
database is behind — check before applying.

## 2. `notify.NotificationJobs` — 1 relaxed, 3 added

| Column | Change | Null | Default | Why |
|---|---|---|---|---|
| `CompanyId` | `int` NOT NULL → **NULL** | yes | — | A platform dispatch belongs to no company. Null ⇒ `Scope = 'PLATFORM'`. FK to `app.Companies` and `OnDelete(Restrict)` unchanged. |
| `Scope` | new `varchar(10)` | no | `'TENANT'` | Same address space as `Notifications.Scope`. Defaults backfill existing rows correctly. |
| `TargetKind` | new `varchar(20)` | yes | — | Audience shape of the run (`Users` / `Roles` / `AllStaff`) — the header's record of *what was asked for*, next to `TargetSnapshot`'s record of *who it resolved to*. |
| `TargetSnapshot` | new `text` | yes | — | JSON of the resolved recipient set at dispatch time. A notification row is disposable (see §4); this is where the audit answer lives. |

### Index

```sql
CREATE INDEX "IX_NotificationJobs_Scope_CreatedDate"
  ON notify."NotificationJobs" ("Scope", "CreatedDate");
```

Existing `IX_NotificationJobs_CompanyId`, `_TriggerCode`, `_JobStatusId` are unchanged.

**`IsBulk` stays and is still computed and written** even though the Hangfire fan-out branch it used
to gate was descoped (§⑨ Q7). It is the flag a future async path will read; deleting the column and
re-adding it later would be the more disruptive choice.

## 3. `notify.UserNotificationPreferences` — new table

Replaces `MuteNotificationType`, which logged a message, returned *"Muted. You can unmute from
Notification Settings."*, and stored nothing.

| Column | Type | Null | Why |
|---|---|---|---|
| `UserNotificationPreferenceId` | `int` PK, identity always | no | — |
| `UserId` | `int` | no | **No FK, deliberately** — see below. |
| `Scope` | `varchar(10)`, default `'TENANT'` | no | A user who is both platform staff and a tenant member keeps two independent sets of preferences. That is the point, not an accident. |
| `CompanyId` | `int` FK → `app."Companies"`, `ON DELETE RESTRICT` | **yes** | Null ⇒ a PLATFORM-scope preference. |
| `TriggerCode` | `varchar(100)` | yes | Exact trigger to mute (`"lead.assigned"`). Null ⇒ the rule applies to the whole `Category`. |
| `Category` | `varchar(30)` | yes | Category to mute (`"Lead"`). Used when `TriggerCode` is null. |
| `IsInAppMuted` | `bool`, default `false` | no | |
| `IsEmailMuted` | `bool`, default `false` | no | |
| + `Entity` audit columns | | | `CreatedBy/CreatedDate/ModifiedBy/ModifiedDate/IsActive/IsDeleted` |

```sql
CREATE INDEX "IX_UserNotificationPreferences_UserId"
  ON notify."UserNotificationPreferences" ("UserId");

CREATE UNIQUE INDEX "UX_UserNotificationPreferences_User_Scope_Company_Trigger_Category"
  ON notify."UserNotificationPreferences"
     ("UserId", "Scope", "CompanyId", "TriggerCode", "Category");
```

**The unique index is load-bearing, not hygiene.** The update handler is an upsert keyed on exactly
that tuple; without the constraint a double-click on a toggle writes two rows and the subsequent
unmute silently leaves one of them behind — the user un-mutes something and still hears nothing,
which is the single worst failure mode this table has.

**A row is a MUTE, never a subscription: absence means "deliver".** That is why there is no backfill
and no per-user seeding — a new trigger code works for everybody the moment it ships, and the
delivery-side check stays a single anti-join.

**`UserId` carries no foreign key, deliberately.** `auth.Users` is tenant-scoped and this table is
read on the delivery hot path from a context that bypasses the tenant query filter; a constraint
would fight that filter for a guarantee the application already makes. Same reasoning as
`Lead.OwnerUserId` and `LeadAssignments.AssignedToUserId` in P-21 — do not "fix" one without the
others.

## 4. What is *not* in this migration

- **No notification-archive or outbox table.** Notification rows are disposable by design (§I-12):
  nothing in the system treats a notification as the record of what happened. The record lives in the
  source entity and in `NotificationJobs.TargetSnapshot`.
- **No `TargetKind = 'AllTenants'` support.** Cross-tenant announce was descoped with the Hangfire
  fan-out (§⑨ Q7/Q8); the column is a free-text `varchar(20)` so adding it later needs no migration.
- **No new MasterData rows.** `NOTIFICATIONDELIVERYSTATUS` and `NOTIFICATIONJOBSTATUS` are referenced
  by existing FKs — **verify those lookup rows actually exist in your environment before dispatching
  anything.** The dispatcher has never executed in this codebase, so an absent lookup row has never
  had the chance to fail loudly.

## 5. Ordering and safety

1. **Take a backup.** This is the first P-2x migration that drops a column and drops indexes.
2. Apply the migration. The two nullability relaxations and the three defaulted `Scope` columns are
   safe on populated tables; the `NotificationTypeId` drop is irreversible without that backup.
3. Apply `sql-scripts-dyanmic/notification-broadcast-capability-seed.sql` — the two new capabilities
   and their grants. **Until it runs nobody can compose a notification**, on either surface: the
   Compose button is drawn from the capability and the send re-checks it server-side.
4. Apply `sql-scripts-dyanmic/notification-platform-settings-seed.sql` — the platform-level
   (`CompanyId IS NULL`) notification settings rows.
5. Apply `sql-scripts-dyanmic/notification-trigger-templates-seed.sql` — the two missing
   `NOTIFICATIONCATEGORY` rows (`Lead`, `Provisioning`) and one catalogue template per emitted
   trigger code. **Until it runs, every user's Settings → Notifications panel is permanently
   empty** — the panel is built from templates overlaid with mute rows, so with no templates there
   is nothing to render and nothing errors. Requires the pre-existing
   `PSS_2.0_Backend/.../sql-scripts-dyanmic/seed_notificationtemplate_masterdata.sql` to have run;
   if it has not, this file inserts nothing (guarded, silent) — see its VERIFY block.
6. Confirm the `NOTIFICATIONDELIVERYSTATUS` and `NOTIFICATIONJOBSTATUS` MasterData rows exist. See
   §4 — this is the most likely first-run failure and it will not show up at compile time.
