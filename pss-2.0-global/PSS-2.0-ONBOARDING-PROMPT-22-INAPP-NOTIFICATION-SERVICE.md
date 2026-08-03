# PSS 2.0 — PROMPT 22 · In-App Notification Service (Platform + Tenant)

> **Status:** PROMPT_READY · not built
> **Depends on:** PROMPT-21 (`AssignLead`) for the first real trigger — but §④ steps 1–11 are independent and can land first.
> **Supersedes:** the unwritten `.claude/feature-specs/in-app-notification-runtime.md` referenced throughout the existing code. **That file does not exist on disk.** Its "Phase 0 / Phase 2 / Phase 3" numbering is unrecoverable; this document replaces it as the spec of record.

---

## ⚠️ Rules for whoever builds this

1. **Do NOT run `dotnet build`.** The user builds the backend.
2. **Migrations are strictly user-owned.** Never run `dotnet ef migrations add|remove` or `database update`. Never hand-author a migration or a snapshot. §3.9 is a *spec* the user implements.
3. **Seed SQL: you write it, the user applies it.** Put it in the repo-root `sql-scripts-dyanmic/`.
4. **`PSS_2.0_Backend/` is gitignored** — the Grep/Glob tools return zero `.cs` matches. Use `find -iname`, or scope `grep -rn --include=*.cs` to **one** project subdirectory (a repo-wide backend grep times out at 120s). Absolute-path `Read` works fine.
5. **Frontend typecheck:** `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, no pipe. Only exit 0 counts as clean.
6. **DB is UTC-only.** Every Postgres date column is `timestamp with time zone`; Npgsql throws on `Kind=Unspecified`. Use `DateTime.UtcNow`.
7. **HotChocolate strips `Get`** from every resolver (`GetNotificationBadge` → `notificationBadge`) and appends `Input` to input types. tsc cannot see gql field names — a wrong name compiles clean and fails only at runtime. Verify every new field name against the emitted schema.
8. **This is a wiring-and-scoping job, not a greenfield build.** Roughly 70% of what this document describes already exists on disk and has never executed once. Read §⓪ before writing a line of code. If you find yourself creating a second dispatcher, stop — you have misread the codebase.

---

## ⓪ What is actually on disk (verified, 2026-08-03)

Everything in this section was read directly. File and line references are literal.

### Already built — the template-driven engine

| Piece | Path | State |
|---|---|---|
| `Notification` entity | `Base.Domain/Models/NotifyModels/Notification.cs` (namespace is `SharedModels`) | Full. Per-recipient row + delivery tracking (`SentAt`/`DeliveredAt`/`ReadAt`/`PushedAt`/`FailedAt`/`DeliveryError`). **`CompanyId` is `int?`.** |
| `NotificationJob` | `Base.Domain/Models/NotifyModels/NotificationJob.cs` | Full. Fan-out header, counters, `TokenSnapshot`, `IsBulk`, `HangfireJobId`. **`CompanyId` is non-nullable `int` with a required FK.** |
| `NotificationTemplate` | `…/NotificationTemplate.cs` | Full. `TriggerEvent`, `TriggerConditionJson`, `EnableInApp/Email/WhatsApp/Push`, MasterData FKs for Category/Priority/RecipientType/Audience, `IncludeAdmins`, `ActionUrl`. |
| `NotificationTemplateRole` | `…/NotificationTemplateRole.cs` | Full. Role-code child rows. |
| `INotificationDispatcher` / `NotificationDispatcher` | `Base.Application/Services/Notifications/` | 308 lines. Template match → condition eval → resolve → render → persist job + rows. |
| `INotificationRecipientResolver` / impl | same folder | 139 lines. Two-stage funnel: Stage A audience pool (Staff/Member/Volunteer/All), Stage B narrowing (AllStaff/Roles/AssignedStaff/Initiated/Custom). |
| `NotificationTokenRenderer` | same folder | `{{Token}}` substitution. |
| `NotificationTriggerEvent` | `Base.Domain/Events/NotifyEvents/` | Generic domain event, published by the SaveChanges interceptor. |
| `NotificationTriggerHandler` | `Base.Application/Business/NotifyBusiness/NotificationTriggers/` | Bridges the event to the dispatcher. |
| Inbox reads | `…/Notifications/Queries/GetInboxNotifications.cs`, `GetInboxSummary.cs`, `GetUserNotifications.cs` | Paged feed, summary counts, unread badge count. |
| Inbox writes | `…/Notifications/Commands/` | Read/ReadAll/Star/Delete/DeleteAll/Toggle/Mute. |
| FE Notification Center | `(core)/crm/notification/notificationcenter/page.tsx` + 8 components | Full page: filter bar, cards, category theming, relative time, `use-notification-center.ts`. |
| FE bell panel | `custom-components/notifications-panel/index.tsx` + `notification-item.tsx` | Working popover, unread/all toggle, paging, `useNotificationCount` + `useFetchNotifications` hooks. |
| MasterData seeds | `PSS_2.0_Backend/…/Base/sql-scripts-dyanmic/seed_notification_runtime_masterdata.sql`, `seed_notificationtemplate_masterdata.sql` | Written. **Note the path** — these live under the backend tree, not the repo-root `sql-scripts-dyanmic/`. Application state unverified. |

**Read that table again.** A complete, thoughtfully-built, tenant-scoped in-app notification runtime already exists. It has never delivered a single notification.

### The defects

**D1 — The engine is dead code. Nothing raises the trigger event.**

```
grep -rn "NotificationTriggerEvent" --include=*.cs PeopleServe/
  → NotifyEvents/NotificationTriggerEvent.cs   (the definition)
  → NotificationTriggers/NotificationTriggerHandler.cs  (the handler)
  → (nothing else)
```

Zero business commands raise it. Not donations, not contacts, not cases, not grants, not events. `DispatchAsync` is unreachable from any user action; the only path that reaches the persist method is `SendTestAsync`, invoked from the template screen's "send test" button. Every template a tenant configures is inert. **This is the single most important fact in this document** — the work here is overwhelmingly *connecting* what exists, not building it.

**D2 — There is no bell in the application.**

`layout-components/header/header.tsx:37`:
```tsx
{/* <NotificationsPanel /> */}
```

Commented out. The working panel, its two hooks, and its GraphQL queries are all live code that nothing mounts. The second bell component, `header/notification-message.tsx`, *is* rendered in some layouts but is a static shell — its entire list body is commented out (lines 45–81), the unread badge is commented out (lines 28–30), "Mark all as read" is a `<span>` with no handler, and "View All" links to `/dashboard`, not to the Notification Center. So the finished `(core)/crm/notification/notificationcenter` page has **no entry point anywhere in the UI**.

Consequence: even after D1 is fixed, notifications would land in a table no user can see.

**D3 — The platform surface cannot use the engine at all.** Four separate hard blocks:

- `INotificationDispatcher.DispatchAsync(string triggerCode, int companyId, …)` — `companyId` is non-nullable.
- `NotificationTriggerEvent.CompanyId` — non-nullable `int`.
- `NotificationJob.CompanyId` — non-nullable `int`, **required FK to `app.Companies`**. A platform notification has no company; this FK makes the row unwritable.
- Every recipient pool is tenant-shaped: `StaffPoolAsync` → `Staffs.Where(s => s.CompanyId == companyId)`, ditto members and volunteers. There is no platform-staff pool. And the `Roles` branch queries `UserRoles.Where(ur => ur.CompanyId == companyId)` — platform roles have `CompanyId IS NULL`, so that branch returns empty for every platform caller.

The one thing that is *not* blocked: `Notification.CompanyId` is already `int?`. The per-recipient row can represent a platform notification today. Only the header and the signatures need widening.

**D4 — The inbox queries have no scope filter at all.**

`GetInboxNotifications.cs:48-50` and `GetInboxSummary.cs:41-44` filter on `ToUserId` and `IsDeleted` **only**. No `CompanyId`, no scope. Two consequences, one present and one incoming:

- *Today:* a user who belongs to two tenants sees both tenants' notifications interleaved in one inbox, with no indication of which is which.
- *The moment §② ships:* platform notifications would appear inside the tenant Notification Center, because nothing excludes them. A support engineer working inside a customer's tenant would see "Lead #412 assigned to you" in that customer's notification bell.

This must be fixed **in the same change** that introduces platform notifications, not after. See §2.6.

`GetUserNotifications.cs:33-35` (the unread badge) is worse — it filters `ToUserId` and `!IsRead` and **omits `IsDeleted` entirely**, so soft-deleted unread notifications still inflate the badge. A user can clear their inbox and watch the count stay at 7.

**D5 — `CreateNotificationCommand` is an unguarded spoofing surface.**

`Notifications/Commands/CreateNotification.cs:18` is `command.Notification.Adapt<Notification>()` straight into `Add()`. It is exposed as a GraphQL mutation (`NotificationMutations.cs:27`). The client supplies `ToUserId`, `FromUserId`, `CompanyId`, `NotificationTitle`, `NotificationText`, `ActionUrl` — all of it, unvalidated. Any user holding `Notification.Create` can fabricate a notification that appears to come from anyone, addressed to anyone, in any company, with an arbitrary action link.

This is the only "send" path that currently exists, and it cannot be the one the new service uses.

**D6 — `IncludeAdmins` resolves admins by substring match.**

`NotificationRecipientResolver.cs:79-82`, carrying its own `// TODO confirm admin role code`:
```csharp
.Where(ur => ur.CompanyId == companyId && ur.Role.RoleCode.Contains("ADMIN"))
```
Any role whose code contains the letters `ADMIN` is treated as an org admin. Given the platform role set includes `PLATFORM_ADMIN`, and tenants can create their own roles, this will attract false positives. It is also the kind of rule that quietly starts matching more people as the role catalog grows.

**D7 — `ModuleId` is a required FK stamped from a hardcoded module code that may not exist.**

`NotificationDispatcher.cs:33` hardcodes `DefaultModuleCode = "GENERAL"`, with a `// TODO confirm ModuleCode`. `ResolveDefaultModuleIdAsync` logs a warning and returns `Guid.Empty` when the row is missing — and then the insert FK-violates and the whole `SaveChangesAsync` throws, taking the business transaction with it if the dispatch is not isolated. Every notification in the system is stamped against one meaningless module.

**D8 — `NotificationTypeId` is hardcoded to `1`** (`NotificationDispatcher.cs:27`) against a catalog that does not exist — the column is a plain `int` with no FK and no lookup table. It is a required column carrying no information.

**D9 — `MuteNotificationType` is a no-op that reports success.**

`Commands/MuteNotificationType.cs` — the handler logs and returns `(true, "Muted. You can unmute from Notification Settings.")`. Nothing is persisted; the `UserNotificationMute` table does not exist. The user is told their preference was saved. It was not, and there is no Notification Settings screen to unmute from either.

**D10 — No realtime, and no polling either.**

SignalR is registered (`Base.API/DependencyInjection.cs:209`) but the only hub mapped is `app.MapHub<ImportProgressHub>("/hubs/import-progress")` (line 428). There is no notification hub. Separately, the FE panel fetches on popover-open only (`notifications-panel/index.tsx:52-57`) and `useNotificationCount` runs a plain `useQuery` with **no `pollInterval`** — so the unread badge is fetched once per page load and never refreshes. A notification that arrives while the user sits on a page is invisible until they navigate.

**D11 — The bulk path is a comment.** `NotificationDispatcher.cs:99-107` computes `isBulk`, writes it to the job header, logs "Phase 3 will route this to Hangfire" — and then persists inline anyway. A 5,000-staff broadcast is 5,000 inserts inside the caller's request. `HangfireJobId` is never written.

---

## ① The one idea

**Two things are missing, and neither is a notification engine.**

The engine is finished. What is missing is (a) an *address space* that includes the platform, and (b) *anyone calling it*.

So this prompt does exactly three things, in this order of importance:

1. **Make the engine addressable.** One `Scope` dimension (TENANT | PLATFORM) threaded through the entity, the job header, the dispatch signature, the recipient resolver, and — critically — the inbox reads. This is the difference between "a tenant feature" and "a notification service."
2. **Add a direct-send path** that does not require a template. The template path is tenant-configurable and therefore *best-effort by design*: if the row is missing, inactive, or has `EnableInApp = false`, nothing is sent and nothing complains. That is correct for "notify staff when a donation over $500 arrives." It is wrong for "tell Rahim he now owns this lead" — a system event whose delivery must not depend on a config row someone can toggle off. Both paths write the same rows and land in the same inbox; they differ only in who decides whether the send happens.
3. **Mount the UI.** Uncomment one line, delete one dead component, and give the platform surface its own inbox route.

**The corollary that governs every decision below:** the inbox is a *per-user, per-scope* view. `ToUserId` alone is not a sufficient filter and never was (D4). Every read path in this document carries scope, and adding scope to the reads is not optional cleanup — it is the security boundary that lets platform and tenant notifications share one table.

**What this deliberately is not:** a message centre, a chat system, or an activity feed. There are no threads, no replies, no read receipts visible to the sender, and no per-notification permissions. A notification is a one-way, per-recipient, disposable pointer at something that happened. Keeping it that thin is what makes the fan-out cheap.

---

## ② Design

### 2.1 Two dispatch modes, one persist path

```csharp
namespace Base.Application.Services.Notifications;

/// <summary>
/// Imperative, template-free notification send. System-owned: the caller decides the
/// recipients and the content, and delivery does NOT depend on a tenant-editable
/// NotificationTemplate row. Use for system events that must always notify
/// (assignment, provisioning outcome, security). For business events a tenant should
/// be able to configure or silence, raise NotificationTriggerEvent instead.
/// </summary>
public interface INotificationSender
{
    Task<int> SendAsync(NotificationRequest request, CancellationToken ct);
}

public sealed record NotificationRequest
{
    public required NotificationTarget Target      { get; init; }
    public required string             Title       { get; init; }   // already rendered — no tokens
    public required string             Body        { get; init; }
    public string   Category            { get; init; } = "System";
    public string   Priority            { get; init; } = "Normal";
    public string   IconCode            { get; init; } = "fa-bell";
    public string?  IconColor           { get; init; }
    public string?  ActionUrl           { get; init; }
    public string?  ActionLabel         { get; init; }
    public int?     FromUserId          { get; init; }              // acting user; null = system
    public string   TriggerCode         { get; init; } = "direct";  // audit label on the job header
    public string?  SourceEntityType    { get; init; }              // e.g. "Lead"  — see §3.4
    public int?     SourceEntityId      { get; init; }
}
```

`SendAsync` returns the number of `Notification` rows written, so a caller can log "notified 0 recipients" — which is the failure that otherwise goes unnoticed.

The two modes converge immediately: `INotificationSender` resolves its target to a user-id list and then calls the **same** private persist routine the dispatcher uses. Extract that routine (currently `NotificationDispatcher.PersistNotifications`) into an internal shared service so the job header, the delivery-status stamping, and the column mapping exist once. Two copies of that method will drift within a quarter.

### 2.2 The address space — `NotificationTarget`

This is the type that answers the user's requirement directly. The four asked-for categories map one-to-one onto factory methods:

```csharp
public sealed record NotificationTarget
{
    public NotificationScope Scope     { get; private init; }   // Tenant | Platform
    public int?              CompanyId { get; private init; }   // required iff Scope == Tenant
    public TargetKind        Kind      { get; private init; }
    public IReadOnlyList<int>    UserIds   { get; private init; } = [];
    public IReadOnlyList<string> RoleCodes { get; private init; } = [];

    // ── One-to-one / explicit set ──────────────────────────────────────────
    public static NotificationTarget TenantUser (int companyId, int userId);
    public static NotificationTarget TenantUsers(int companyId, IEnumerable<int> userIds);
    public static NotificationTarget PlatformUser (int userId);
    public static NotificationTarget PlatformUsers(IEnumerable<int> userIds);

    // ── Everyone in a scope ────────────────────────────────────────────────
    public static NotificationTarget TenantAllStaff(int companyId);
    public static NotificationTarget AllPlatformStaff();

    // ── By role ────────────────────────────────────────────────────────────
    public static NotificationTarget TenantRoles (int companyId, params string[] roleCodes);
    public static NotificationTarget PlatformRoles(params string[] roleCodes);

    // ── Cross-tenant broadcast (see §2.7 — gated, deliberately awkward) ────
    public static NotificationTarget AllTenantsAllStaff();
}

public enum NotificationScope { Tenant = 1, Platform = 2 }
public enum TargetKind        { ExplicitUsers = 1, AllStaff = 2, Roles = 3, AllTenants = 4 }
```

**Why a target object rather than overloads.** Six `SendAsync` overloads would encode the same information in the signature and then need re-encoding at every layer that carries it — the request DTO, the resolver, the job header. One value object travels intact, is trivially unit-testable, and makes the scope/company invariant (§⑥ I-2) enforceable in a constructor instead of at six call sites.

**Why `PlatformUser(userId)` takes no company.** Deliberate friction in the right place. A platform target with a company id is a bug, and a tenant target without one is a bug; making them structurally impossible beats validating them.

### 2.3 Platform-staff resolution — one helper, shared

The platform pool is the discriminator established in PROMPT-19 §11.4 and reused by PROMPT-21 §2.3: *an `auth.Users` row holding ≥1 active `UserRole` on a `Role` with `CompanyId IS NULL`.*

```csharp
// Base.Application/Helpers/PlatformStaffHelper.cs — NEW, shared.
// PROMPT-19 §11.4 / PROMPT-21 §2.3 / PROMPT-22 §2.3 all need this exact predicate.
// It is a helper and not three inline copies precisely because "who counts as platform
// staff" is a rule that will change once, and must change in one place when it does.
public static IQueryable<int> PlatformStaffUserIds(IApplicationDbContext db) =>
    db.Users
      .IgnoreQueryFilters()
      .Where(u => u.IsActive == true && u.IsDeleted != true
               && u.UserRoles.Any(ur => ur.IsActive == true && ur.IsDeleted != true
                                     && ur.Role!.CompanyId == null))
      .Select(u => u.UserId);

public static IQueryable<int> PlatformStaffUserIdsInRoles(IApplicationDbContext db, IEnumerable<string> roleCodes);
public static Task<bool> IsPlatformStaffAsync(IApplicationDbContext db, int userId, CancellationToken ct);
```

**`IgnoreQueryFilters()` is mandatory on every one of these.** Platform callers have `CurrentTenantId == null`; without it the tenant filter silently returns an empty pool and the notification is dropped with no error. Pair it with the explicit `IsDeleted != true` guard, since ignoring the filter also discards soft-delete filtering.

If PROMPT-21 has already shipped its own inline copy of this predicate, **replace it with a call to this helper** as part of this work. Two divergent definitions of "platform staff" is a security bug waiting for a role rename.

### 2.4 Resolver extension

Extend `NotificationRecipientResolver` with a scope-aware overload rather than replacing the template one. The existing `ResolveAsync(template, companyId, ctx, ct)` keeps working unchanged — legacy behaviour is exactly preserved — and a new method resolves a `NotificationTarget`:

```csharp
Task<List<int>> ResolveTargetAsync(NotificationTarget target, CancellationToken ct);
```

| `Kind` × `Scope` | Resolution |
|---|---|
| `ExplicitUsers` / Tenant | Filter the supplied ids to users actually in `companyId` (§⑥ I-4). Do not trust the caller. |
| `ExplicitUsers` / Platform | Filter to `PlatformStaffUserIds`. |
| `AllStaff` / Tenant | Existing `StaffPoolAsync(companyId)`. |
| `AllStaff` / Platform | `PlatformStaffUserIds`. |
| `Roles` / Tenant | `UserRoles.Where(ur => ur.CompanyId == companyId && roleCodes.Contains(ur.Role.RoleCode))`. |
| `Roles` / Platform | `PlatformStaffUserIdsInRoles(roleCodes)` — note `ur.Role.CompanyId == null`, **not** `ur.CompanyId == companyId`, which is the D3 trap. |
| `AllTenants` | `Staffs.Where(s => s.IsDeleted == false)` across all companies, `IgnoreQueryFilters()`. Gated — §2.7. |

Always de-dupe, always drop `userId <= 0`, and **always drop the acting user from the recipient list on direct sends** unless the request explicitly opts in. Notifying someone about the thing they just did is the fastest way to teach users that the bell is noise. (Self-claim in PROMPT-21 is exactly this case: you assigned yourself; you know.)

While you are in this file, fix **D6** — replace the `RoleCode.Contains("ADMIN")` substring match with an explicit code list read from a platform setting (`NOTIFY_ADMIN_ROLE_CODES`, default `ORGADMIN,BUSINESSADMIN`), or drop `IncludeAdmins` support for platform-scope targets entirely. Do not leave a substring match deciding who receives administrative notifications.

### 2.5 Scope on the row, not inferred from `CompanyId IS NULL`

Add `Notification.Scope` (`varchar(10)`, `TENANT` | `PLATFORM`, default `TENANT`, **not null**) and the same on `NotificationJob`.

**Why not just use `CompanyId IS NULL`?** Because it is already ambiguous. `Notification.CompanyId` is nullable today and legacy rows may carry null for reasons unrelated to the platform — `SendTestAsync` writes `template.CompanyId ?? 0`, and `CreateNotificationCommand` (D5) accepts whatever the client sends. An explicit, backfilled, non-null discriminator means the inbox filter is a positive assertion (`Scope = 'PLATFORM'`) rather than an absence-of-evidence test. When the filter in question is the boundary between a customer's data and the vendor's, positive assertion is worth one `varchar(10)`.

The two are still constrained to agree — see §⑥ I-2.

### 2.6 Fix the inbox reads (D4) — required, same change

Every read path gains scope. The scope is **derived server-side** from the request context, never accepted as a client parameter:

- The caller is on the platform surface (has ≥1 `CompanyId IS NULL` role **and** the request carries no tenant context) → `Scope = 'PLATFORM'`.
- Otherwise → `Scope = 'TENANT' AND CompanyId = <current tenant>`.

The cleanest expression is an explicit enum argument on the query resolved by the *mutation/query layer* from route + claims, exactly as `TryGetActingUserId` resolves the acting user — not a boolean the client toggles. **A client-supplied scope is a client-supplied answer to "may I see the vendor's notifications."**

Apply to all four:
- `GetInboxNotificationsQuery` — add scope + company filter.
- `GetInboxSummaryQuery` — same.
- `GetUserNotificationsQuery` (badge count) — same, **and add the missing `IsDeleted == false`** (D4).
- The new `GetNotificationBadgeQuery` (§2.8) — same.

A user who is both platform staff and a tenant user gets two distinct inboxes, one per surface. That is the correct model and it falls out of the scope filter for free.

### 2.7 Broadcast is a privileged act

"Send to all staff in the tenant," "send to all platform staff," and especially "send to every user in every tenant" are megaphones, not notifications. They are the mechanism by which one mistaken click reaches every user of the product.

Gate them separately from `Notification.Create`:

| Target | Required capability |
|---|---|
| `TenantUser` / `TenantUsers` (≤ 5 recipients) | `NOTIFICATION` / `Create` (existing) |
| `TenantAllStaff`, `TenantRoles` | **new** `NOTIFICATION_BROADCAST` |
| `PlatformUser(s)` | `PLATFORM_NOTIFY` (implicit for platform staff) |
| `AllPlatformStaff`, `PlatformRoles` | **new** `PLATFORM_NOTIFY_BROADCAST` |
| `AllTenantsAllStaff` | **new** `PLATFORM_NOTIFY_ANNOUNCE` — `SUPERADMIN` only |

**System sends bypass this entirely.** `INotificationSender` called from a handler (lead assignment, provisioning) is not a user action and must not be capability-checked — the capability governs the *composer UI*, which is the surface a human drives. Enforce it in the compose command (§④ step 12), not inside `SendAsync`. Putting the check in `SendAsync` means a support engineer without the broadcast capability silently breaks provisioning notifications, and the failure appears nowhere near its cause.

`AllTenantsAllStaff` additionally must require a typed confirmation in the UI and must always route through the async fan-out (§2.9), never inline.

### 2.8 Delivery: fix polling now, SignalR later — and be honest about why

**Now (this prompt):** a dedicated lightweight badge query, polled.

```
query notificationBadge {   # HotChocolate strips Get — verify the emitted name
  result { data { unreadCount latestNotificationId latestCreatedDate } }
}
```

Three scalars. No list, no joins, no template includes. The FE polls it with Apollo `pollInterval: 60000` and refetches the *list* only when `latestNotificationId` changes or the popover opens. Sixty seconds is the right default: it is well inside the human tolerance for "did my colleague see it yet," and one indexed `COUNT(*)` per user per minute is nothing. Do not poll the full inbox list — that is the mistake that makes people rip polling out and blame polling.

Set `pollInterval` from a config value so it is tunable without a deploy, and **stop polling when the tab is hidden** (`document.visibilityState`) — otherwise every abandoned background tab bills you a query a minute forever.

**Later (deferred, §⑦):** a SignalR `NotificationHub`. When it is built it will need, and this is the part that gets skipped:
- Authenticated hub connections with the user id from the JWT, and per-user groups (`user:{userId}:{scope}`) — never broadcast-to-all-connections with client-side filtering.
- **A backplane (Redis) if the API ever runs more than one instance.** Without it, a push reaches only users connected to the node that handled the write. This half-works perfectly in dev and single-node staging, and then fails for ~50% of users the day a second instance is added — which is exactly the sort of failure nobody attributes to the notification system.
- The push is an *optimisation over* the poll, never a replacement. Keep the poll as the floor; a dropped WebSocket must degrade to a 60-second delay, not to silence.

Stamp `PushedAt` when SignalR ships. The column already exists and stays null until then.

### 2.9 Fan-out threshold (D11)

Keep `InlineThreshold` but make it a config value rather than `private const int InlineThreshold = 20`, and make the `isBulk` branch actually mean something:

- `recipients.Count <= threshold` → inline, as today.
- `> threshold` → enqueue a Hangfire job, write `HangfireJobId` to the header, set `JobStatusId = Pending`, and **return from the request immediately**. The job inserts in batches (500/`SaveChanges`), updating `SuccessCount`/`FailCount` and finally `CompletedAt` + `Completed`.

The synthetic-`ClaimsPrincipal` pattern the existing comment points at (`OnlineDonationMapJobRunner`) is the right model — read it before writing this. Note the job runs with no HTTP context, so the acting user and scope must be carried on the job header, not resolved from claims.

If Hangfire fan-out is descoped, **remove the `isBulk` branch and its log line** rather than leaving a comment that says Phase 3 will handle it. That comment has already survived one full re-planning cycle and it makes the code look more finished than it is.

### 2.10 Retention — decide it now, not when the table is 40M rows

Notifications are the highest-insert, lowest-value-per-row table the product will have: one row per recipient per event, read once, never updated after `ReadAt`. Nothing in the current design ever deletes one.

Ship a nightly Hangfire purge from day one, driven by platform settings:
- `NOTIFY_RETENTION_READ_DAYS` (default **90**) — soft-delete read notifications older than this.
- `NOTIFY_RETENTION_HARD_DAYS` (default **365**) — hard-delete anything older, read or not.
- Never purge rows with `IsStarred = true` under the read rule — starring is the user saying "keep this."

Hard-delete in batches with a `LIMIT`, not one `DELETE … WHERE CreatedDate <` statement; the unbounded form takes a lock long enough to stall the inbox for everyone.

Do this at the start because retrofitting a purge onto a table that has already grown past comfortable means a maintenance window. Doing it now costs one job and two settings rows.

### 2.11 Preferences — close the lie, or remove it (D9)

`MuteNotificationType` tells the user their preference was saved and saves nothing. Two acceptable outcomes, no third:

- **Preferred:** build `notify.UserNotificationPreferences` — `(UserId, TriggerCode|NotificationTemplateId, Channel, IsMuted)` — and have `SendAsync`/`DispatchAsync` filter muted recipients *after* resolution, *before* persist. Direct sends of `Priority = 'Urgent'` ignore mutes (§⑥ I-8): security and assignment notifications are not opt-out.
- **Otherwise:** remove the mute action from the FE menu and have the command throw `NotImplementedException`. A control that reports success and does nothing is worse than no control — the user stops trusting the surface and there is no signal that anything is wrong.

Recommendation: build it. It is one small table and the alternative is a support ticket per noisy tenant.

### 2.12 The first real trigger — lead assignment (the reason this prompt exists)

In PROMPT-21's `AssignLeadHandler`, **after** the single `SaveChangesAsync`:

```csharp
// In-app first: it cannot bounce, needs no provider configuration, and lands where the
// assignee already works. Email (P-21 §2.6) is the secondary, best-effort channel.
await notificationSender.SendAsync(new NotificationRequest
{
    Target      = NotificationTarget.PlatformUser(assigneeUserId),
    Title       = "Lead assigned to you",
    Body        = $"{lead.CompanyName} ({lead.ContactName}) was assigned to you by {actingUserName}.",
    Category    = "Lead",
    Priority    = "Normal",
    IconCode    = "ph:user-switch",
    ActionUrl   = $"/ops/leads?leadId={lead.LeadId}",
    ActionLabel = "Open lead",
    FromUserId  = actingUserId,
    TriggerCode = "lead.assigned",
    SourceEntityType = "Lead",
    SourceEntityId   = lead.LeadId,
}, ct);
```

Rules for this call, all of which generalise to every future trigger:
- **After `SaveChanges`, never inside the transaction.** A notification failure must not roll back an assignment.
- **Wrapped so it cannot throw into the handler** — log and continue. Same posture as P-21 §2.6's email.
- **Skipped on self-claim.** You do not need telling that you claimed a lead.
- **On reassignment, also notify the previous owner** — this answers PROMPT-21 §⑨ Q6. In-app yes, email no: in-app is a line in a list they can ignore, whereas an email saying "a lead was taken from you" is a conversation nobody asked for. This is precisely the class of notification that justifies having an in-app channel at all.
- **`ActionUrl` is scope-relative** — no `/{lang}` prefix and no host. The FE prepends the locale. See §⑥ I-7.

Also wire, in the same pass, the platform events that already have no channel and obviously want one: `provisioning.failed` → `PlatformRoles("PLATFORM_IMPLEMENTATION","PLATFORM_ADMIN")`; `lead.created` (from the P-20 public enquiry form) → `PlatformRoles("PLATFORM_SALES")`, which is what turns the unassigned-lead queue into something someone actually looks at. Both are two-line calls once §④ steps 1–11 exist.

---

## ③ Data

### 3.1 `notify.Notifications` — added columns

| Column | Type | Notes |
|---|---|---|
| `Scope` | `varchar(10)` NOT NULL DEFAULT `'TENANT'` | `TENANT` \| `PLATFORM`. Backfill all existing rows to `TENANT`. |
| `SourceEntityType` | `varchar(60)` NULL | e.g. `Lead`, `Case`, `Donation`. |
| `SourceEntityId` | `int` NULL | With the above: deep-link target, "all notifications about this record", and the dedupe key (§⑨ Q4). |

`CompanyId` stays `int?` — already correct.

### 3.2 `notify.NotificationJobs` — changed + added

| Column | Change |
|---|---|
| `CompanyId` | `int` → **`int?`**, and the FK to `app.Companies` becomes optional. This is the D3 blocker; without it no platform notification can be written. |
| `Scope` | **new** `varchar(10)` NOT NULL DEFAULT `'TENANT'`. |
| `TargetKind` | **new** `varchar(20)` NULL — `ExplicitUsers`/`AllStaff`/`Roles`/`AllTenants`. Audit: "who was this actually aimed at." |
| `TargetSnapshot` | **new** `text` NULL — JSON of the resolved `NotificationTarget`. Sibling to the existing `TokenSnapshot`; makes a bad broadcast explicable after the fact. |

### 3.3 `notify.UserNotificationPreferences` — new (§2.11)

```csharp
[Table("UserNotificationPreferences", Schema = "notify")]
public class UserNotificationPreference : Entity
{
    public int  UserNotificationPreferenceId { get; set; }
    public int  UserId { get; set; }                    // no FK — platform users are not tenant-scoped
    public string Scope { get; set; } = "TENANT";
    public int? CompanyId { get; set; }                 // null for platform preferences
    public string? TriggerCode { get; set; }            // null ⇒ applies to the whole Category
    public string? Category { get; set; }
    public bool IsInAppMuted { get; set; }
    public bool IsEmailMuted { get; set; }
}
```
Unique index on `(UserId, Scope, CompanyId, TriggerCode, Category)`.

**`UserId` carries no FK**, for the same reason `Lead.OwnerUserId` and `LeadAssignment.AssignedToUserId` carry none: `auth.Users` is tenant-scoped and platform users are not. Index it; do not constrain it.

### 3.4 Indexes

```
IX_Notifications_ToUserId_Scope_IsDeleted_CreatedDate   (ToUserId, Scope, IsDeleted, CreatedDate DESC)
IX_Notifications_ToUserId_Scope_IsRead_IsDeleted        (ToUserId, Scope, IsRead, IsDeleted)
IX_Notifications_SourceEntity                           (SourceEntityType, SourceEntityId)
IX_NotificationJobs_Scope_CreatedDate                   (Scope, CreatedDate DESC)
```

The first two **supersede** the existing `IX_Notifications_ToUserId_IsDeleted_CreatedDate` and `IX_Notifications_ToUserId_IsRead_IsDeleted` (`NotificationConfiguration.cs:88-95`). Drop the old two in the same migration — leaving both pairs doubles the write cost of the highest-insert table in the product to no benefit.

### 3.5 Fix `ModuleId` (D7)

`Notification.ModuleId` is a required FK to `auth.Modules` populated from a hardcoded `"GENERAL"` code that may not exist in every environment. Two options; pick one and be explicit:

- **Preferred: make it nullable.** It carries no information today — every row gets the same value — and a required FK on a runtime-resolved code is a latent production `SaveChanges` failure. Nullable, plus a real per-trigger module map later if the grouping ever earns its keep.
- **Otherwise:** guarantee the `GENERAL` module row exists via seed, and make `ResolveDefaultModuleIdAsync` **throw** rather than log-and-return `Guid.Empty`. Failing loudly at dispatch beats an FK violation that surfaces as a rolled-back business transaction three layers up.

Do not leave it as-is. And note that a *platform* notification pointing at a tenant-oriented module catalog is meaningless regardless — which is the argument for nullable.

Same for `NotificationTypeId` (D8): it is a required `int` with no catalog, hardcoded to `1`. Either give it a lookup table or drop the column. Keeping a required column that always holds `1` is a migration everyone will be afraid to touch in a year.

### 3.6 Migration spec — user-owned

Name: `Add_Notification_Scope_And_Preferences`

1. `ALTER TABLE notify."Notifications"` — add `Scope varchar(10) NOT NULL DEFAULT 'TENANT'`, `SourceEntityType varchar(60) NULL`, `SourceEntityId int NULL`.
2. `ALTER TABLE notify."NotificationJobs"` — `CompanyId` → nullable (drop and recreate the FK as optional); add `Scope varchar(10) NOT NULL DEFAULT 'TENANT'`, `TargetKind varchar(20) NULL`, `TargetSnapshot text NULL`.
3. `CREATE TABLE notify."UserNotificationPreferences"` per §3.3, standard `Entity` audit columns, unique index as specified.
4. Drop `IX_Notifications_ToUserId_IsDeleted_CreatedDate` and `IX_Notifications_ToUserId_IsRead_IsDeleted`; create the four indexes in §3.4.
5. If §3.5 preferred option: `Notification.ModuleId` → nullable.

Every step is additive or index-level except the `ModuleId` and `NotificationJobs.CompanyId` nullability widenings, which are also safe (narrowing would not be). The `DEFAULT 'TENANT'` backfills existing rows correctly with no data script — every notification written to date is a tenant notification.

**Verify before generating:** whether `notify.NotificationJobs` currently has rows. If it does, the FK drop/recreate needs the existing values to remain valid — they will, since they are all non-null company ids.

### 3.7 Seeds — `sql-scripts-dyanmic/` (repo root)

**`notification-broadcast-capability-seed.sql`** — three capabilities:
- `NOTIFICATION_BROADCAST` → tenant admin roles.
- `PLATFORM_NOTIFY_BROADCAST` → `PLATFORM_ADMIN`, `SUPERADMIN`.
- `PLATFORM_NOTIFY_ANNOUNCE` → `SUPERADMIN` only.

Pick display orders from a verified-free gap in the platform block — **do not assume**; PROMPT-21 §3.8 already claims 89. Query the table first.

**`notification-platform-settings-seed.sql`** — `sett.OrganizationSettings` rows with `CompanyId IS NULL`:
`NOTIFY_POLL_INTERVAL_SECONDS=60`, `NOTIFY_INLINE_THRESHOLD=20`, `NOTIFY_RETENTION_READ_DAYS=90`, `NOTIFY_RETENTION_HARD_DAYS=365`, `NOTIFY_ADMIN_ROLE_CODES=ORGADMIN,BUSINESSADMIN`.

**Verify and relocate the existing MasterData seeds.** `seed_notification_runtime_masterdata.sql` and `seed_notificationtemplate_masterdata.sql` live under `PSS_2.0_Backend/…/Base/sql-scripts-dyanmic/`, not the repo-root folder the user applies from. Confirm whether `NOTIFICATIONDELIVERYSTATUS` and `NOTIFICATIONJOBSTATUS` rows actually exist in the database before assuming the delivery-status lookups resolve — `MasterDataLookupHelper.GetIdByCodeAsync` returns null on a miss and the dispatcher tolerates it, so an unseeded environment writes every notification with `DeliveryStatusId = NULL` and nothing complains.

Also add a `NOTIFICATIONSCOPE` MasterData TypeCode only if the codebase wants Scope as a lookup. **Recommendation: no** — it is a two-value discriminator that branches code paths, and a MasterData FK would make the security-critical inbox filter a join. Keep it a string column.

---

## ④ Build steps

Backend, in order. Steps 1–11 are independent of PROMPT-21 and can land first.

1. `PlatformStaffHelper` (§2.3). If PROMPT-21 shipped an inline copy, replace it.
2. `NotificationScope`, `TargetKind`, `NotificationTarget`, `NotificationRequest` (§2.1–2.2) in `Base.Application/Services/Notifications/`.
3. Entity + EF config changes: `Notification.Scope`/`SourceEntityType`/`SourceEntityId`; `NotificationJob.CompanyId` nullable + `Scope`/`TargetKind`/`TargetSnapshot`; `UserNotificationPreference` + config. Index changes per §3.4.
4. Extract `PersistNotifications` out of `NotificationDispatcher` into a shared internal `NotificationWriter`, taking scope. Dispatcher calls it; sender will too. **One copy.**
5. `ResolveTargetAsync` on the resolver (§2.4), plus the D6 `IncludeAdmins` fix.
6. `INotificationSender` / `NotificationSender` (§2.1). Register in `Base.Application/DependencyInjection.cs:103` beside the existing Phase-0 registration.
7. Widen the dispatch path for platform: `DispatchAsync(string triggerCode, NotificationScope scope, int? companyId, …)` and `NotificationTriggerEvent.CompanyId` → `int?` + a `Scope`. Update `NotificationTriggerHandler`.
8. Mute filtering in `NotificationWriter` (§2.11), with the `Urgent` bypass.
9. **Fix the inbox reads (D4)** — scope + company on `GetInboxNotifications`, `GetInboxSummary`, `GetUserNotifications`, and add the missing `IsDeleted == false` on the badge count. Resolve scope in the API layer from route + claims, never from a client argument.
10. New `GetNotificationBadgeQuery` (§2.8) + GraphQL query. Verify the emitted field name.
11. **Fix `CreateNotificationCommand` (D5)** — `FromUserId` from the claim only; `ToUserId` validated to be a real, active user in the caller's scope; `CompanyId` from context, never the DTO. Or delete the mutation outright if the composer (step 12) replaces it — that is the cleaner outcome.
12. `SendNotificationCommand` — the human composer behind the UI in §⑤. Capability-gated per §2.7. Builds a `NotificationTarget` from the form and calls `INotificationSender`.
13. `GetNotificationRecipientOptionsQuery` — the composer's picker: platform staff list, tenant staff list, role list, scoped to what the caller may broadcast to.
14. Retention purge job (§2.10) + registration.
15. Hangfire fan-out (§2.9) — or explicitly descope and delete the dead `isBulk` branch.
16. **Wire lead assignment** (§2.12) into `AssignLeadHandler`, plus `provisioning.failed` and `lead.created`.

Frontend:

17. **Uncomment `<NotificationsPanel />` at `header.tsx:37`.** This is the single highest-value line in the whole prompt.
18. **Delete `header/notification-message.tsx`** and every reference to it. A second, non-functional bell will otherwise be "fixed" by someone in six months who does not know the real one exists.
19. Add `pollInterval` (from config) + `visibilitychange` pause to `useNotificationCount`; repoint it at `notificationBadge`.
20. Platform inbox route `(master)/ops/notifications/page.tsx`, **reusing** the existing `notification-center-page.tsx` component with a scope prop. One component, two routes — see §⑤.
21. Composer dialog (§⑤) behind the broadcast capabilities.
22. `ActionUrl` navigation: prepend the current locale, and route within the current surface (§⑥ I-7).
23. Notification preferences panel in user settings, if §2.11 is built.

---

## ⑤ UI notes

**The bell.** One component, both surfaces. It already renders unread/all, pages, and marks read; it just needs mounting and the badge count. Cap the badge display at `99+`.

**The inbox.** `notification-center-page.tsx` is finished and good. Give it a `scope` prop and mount it at both `(core)/crm/notification/notificationcenter` (tenant) and `(master)/ops/notifications` (platform). **Do not fork it.** Two copies will diverge on the first styling change, and the platform copy will be the one that rots, because fewer people look at it.

Note that `(master)/ops/layout.tsx` already wraps children in `DashBoardLayoutProvider`, which renders the shared `Header` — so mounting the bell in `header.tsx` lights it up on the ops surface with no extra work. `(master)/layout.tsx` itself is deliberately bare (masterdashboard keeps its own chrome), so the master dashboard will *not* get a bell; if it should, that is a separate decision, not an oversight to fix silently.

**The composer.** A dialog, not a page. Fields: audience mode (radio: *Specific people* / *By role* / *Everyone*), the dependent picker, title, body, priority, optional action URL + label. Show a live **"This will notify N people"** count before send, resolved server-side from the same resolver that will do the send — a count computed differently from the send is worse than no count. For any audience over 50, require a typed confirmation.

**Empty and error states.** The inbox has an empty state already (`empty-state.tsx`). The platform inbox will be empty for a long time — make sure that state reads as "nothing yet," not as "something is broken."

Per the standing UI rules: design tokens only (no hex, no px), `@iconify` Phosphor icons, shaped skeletons, xs→xl responsive, and icon containers / badges use solid `bg-X-600` + `text-white`.

---

## ⑥ Invariants

- **I-1** — A notification is written by exactly one code path: `NotificationWriter`. No handler ever constructs a `Notification` and calls `dbContext.Notifications.Add` directly. (D5 is what that looks like when violated.)
- **I-2** — `Scope = 'TENANT'` ⟺ `CompanyId IS NOT NULL`; `Scope = 'PLATFORM'` ⟺ `CompanyId IS NULL`. Enforce in the `NotificationTarget` constructor and assert in the writer. Applies to `Notifications` and `NotificationJobs` alike.
- **I-3** — Every inbox read filters on `(ToUserId, Scope)` and, for tenant scope, `CompanyId`. No exceptions. A read without a scope filter is a cross-boundary leak, not a missing nicety.
- **I-4** — Explicit recipient ids supplied by a caller are always re-validated against the resolved scope. A `ToUserId` that arrives over the wire is a request, not a fact.
- **I-5** — Notification delivery never fails, rolls back, or delays the business action that caused it. Always after `SaveChanges`; always exception-wrapped.
- **I-6** — The acting user is excluded from their own notification unless explicitly opted in.
- **I-7** — `ActionUrl` is a locale-less, host-less, surface-relative path (`/ops/leads?leadId=1`). The FE prepends locale. Never store an absolute URL — it will be wrong the first time the host changes, and those rows are permanent.
- **I-8** — `Priority = 'Urgent'` and all direct system sends bypass user mutes. Assignment and security notifications are not opt-out.
- **I-9** — Broadcast capability is checked in the **compose command**, never inside `SendAsync`. System sends must not be capability-gated.
- **I-10** — Platform-staff membership is resolved *only* through `PlatformStaffHelper`. Never `User.CompanyId IS NULL` alone; never an inline copy of the predicate.
- **I-11** — Every platform-scope query uses `IgnoreQueryFilters()` **plus** an explicit `IsDeleted != true`. Ignoring the tenant filter also discards soft-delete filtering.
- **I-12** — Notification rows are disposable. Nothing in the product may treat a notification as the system of record for anything; the source entity is. This is what makes §2.10's purge safe, and it is why there are no threads or replies.

---

## ⑦ Out of scope

- SignalR realtime push (§2.8 defers it explicitly, with the backplane warning that must survive the deferral).
- Browser/OS push notifications, and the `EnablePush` template flag.
- Email/SMS/WhatsApp channel fan-out from the notification service — those subsystems exist independently and this prompt does not merge them.
- Notification digests ("your 12 notifications from today").
- Read receipts visible to a sender, threading, replies, attachments.
- Localisation of notification bodies. Rendered content is stored as written, in the sender's language. Templating a translated body is a real feature and a much larger one.
- Rewriting the template-driven engine. It works; it just needs raising.

---

## ⑧ Acceptance

1. Assigning a lead to another platform staffer produces exactly one notification, visible in that user's bell within one poll interval, and none for the assigner.
2. Self-claiming a lead produces zero notifications.
3. Reassigning notifies the new owner and the previous owner, and nobody else.
4. A tenant user's bell shows zero platform notifications. Verify with a user who holds **both** a platform role and a tenant role — this is the D4 regression test and the only one that matters.
5. A user in two tenants sees only the current tenant's notifications in each.
6. Badge count matches the inbox unread count exactly, including after soft-deleting an unread notification (the D4 badge bug).
7. `AllPlatformStaff` reaches every active platform staffer and no tenant user.
8. `TenantRoles("FINANCE")` reaches exactly the finance-role users of that tenant.
9. A user without `NOTIFICATION_BROADCAST` cannot see or invoke the "Everyone" audience option, and the mutation rejects it if called directly.
10. Lead assignment still succeeds when the notification write fails (temporarily break the sender and confirm the assignment commits).
11. A dispatch resolving to zero recipients logs it and does not write an empty job header.
12. `tsc --noEmit --incremental false` exits 0.
13. The badge stops polling when the tab is hidden and resumes on focus.
14. Deleting a `NotificationTemplate` leaves historical notifications intact and readable (existing `SetNull` behaviour — confirm it survives the changes).
15. The retention purge soft-deletes read notifications past the threshold and never touches starred ones.

---

## ⑨ Open questions

**Q1 — `ModuleId`: nullable, or guarantee the `GENERAL` module row? (blocks §④ step 3, and therefore the migration.)** §3.5 recommends nullable. This is the one question that must be answered before the user generates the migration, because reversing it later is a data-bearing change rather than an additive one.

**Q2 — Build `UserNotificationPreferences`, or remove the mute action?** §2.11 recommends building it. Leaving a control that reports a success it did not perform is the worst of the three outcomes.

**Q3 — Does `NotificationTypeId` get a catalog or get dropped?** It is a required column that has only ever held `1`. Dropping it is cleaner; keeping it means someone must define what a notification *type* is, given that Category and Priority already exist.

**Q4 — Dedupe policy.** If `AssignLead` is invoked twice with the same assignee, the second is a no-op on the lead (P-21 idempotency) so no notification is sent — that case is covered. But should the service *generally* suppress an identical `(TriggerCode, SourceEntityType, SourceEntityId, ToUserId)` inside a short window? Recommendation: not yet. Add `SourceEntityType`/`SourceEntityId` now (they earn their place as deep-link and cleanup keys regardless), and let real duplicate patterns tell us the window rather than guessing it.

**Q5 — Should the master dashboard get a bell?** `(master)/layout.tsx` is deliberately bare, so `masterdashboard` will not receive one from step 17. If platform staff live on that screen, this is a gap; if it is a landing page they pass through, it is not.

**Q6 — Poll interval default.** §2.8 proposes 60s, configurable. Anything under 30s starts to cost real query volume at scale; anything over 120s feels broken to a user watching for a colleague's action.

**Q7 — Is Hangfire fan-out in scope now (§2.9), or is the honest move to delete the dead `isBulk` branch and revisit when a tenant actually has >20 staff receiving one event?** Recommendation: delete the branch now, build the job when the first real broadcast feature ships. A seam that has never been exercised is not a seam.

**Q8 — `AllTenantsAllStaff`:** is a cross-tenant product announcement genuinely wanted? It is the single most dangerous capability in this document and it may be better served by a banner on the dashboard than by writing a row per user across every tenant.

---

## ⑩ Build log

_(empty — nothing built)_
