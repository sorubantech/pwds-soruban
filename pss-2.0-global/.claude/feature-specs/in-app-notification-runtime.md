# In-App Notification Runtime — Implementation Plan

> **Status**: DESIGN / PROPOSED — not yet built
> **Author**: rehydrated from `/continue-screen #36` design pass, 2026-07-08
> **Scope**: Net-new subsystem. NOT a `/continue-screen` fix on screen #36. Plan this as its own feature (feeds `/plan-screens`).
> **Context docs**: template admin screen = `#36` (`.claude/screen-tracker/prompts/notificationtemplate.md`); display screen = `#35` (`notificationcenter.md`).

---

## 1. Goal

Turn the existing notification **shell** (templates + instance table + display UI) into a working **real-time, multi-tenant in-app notification runtime** for **admin and staff** users. A business action (donation created, approval requested, …) must automatically produce per-user notification rows and surface them **without a page refresh** — bell badge + toast + live inbox.

**Chosen delivery transport**: **SignalR push** (per-user groups), mirroring the in-stack `ImportProgressHub`, with **poll/refetch as a graceful fallback** if the socket drops. This is the correct approach for an internal admin/staff app.

**Chosen trigger scope**: Build **one generic trigger-agnostic engine**, then integrate **all required areas** (Donation, Contact, Campaign, Event, Approval, System) via a per-area checklist (§9). Adding a new trigger later = raise an event + register a mapping; no engine changes.

---

## 2. What already exists vs. what's missing

| Layer | Component | State |
|---|---|---|
| Config | `NotificationTemplate` + `NotificationTemplateRole` (#36) | ✅ Built — `TriggerEvent`, `TriggerConditionJson`, channel flags, `RecipientType`, role targeting |
| Instance | `notify.Notifications` (`ToUserId`, `IsRead`, `CompanyId`, `Category`, `Priority`, `ActionUrl`, `IsStarred`, `NotificationTemplateId` FK) | ✅ Table + read/mark-read CRUD + `GetInboxNotifications` |
| Display | Notification Center (#35) — list, filters, mark-read, star, optimistic | ✅ Built + routed |
| Bell | `NotificationsPanel` (bell + live unread badge) | ⚠️ Built, **commented out** at `header.tsx:31` |
| Event bus | MediatR + `DispatchDomainEventsInterceptor` (SaveChanges → publish) | ✅ Exists (only auth/settings entities raise events today) |
| Async | Hangfire (runs the email send pipeline) | ✅ Available |
| Tenant-in-jobs | Synthetic `ClaimsPrincipal` (`OnlineDonationMapJobRunner`) | ✅ Proven pattern |
| Real-time | SignalR — only `ImportProgressHub` | ⚠️ No notification hub |
| **Dispatcher** | `INotificationDispatcher` / trigger consumer | ❌ **Absent — the core gap** |
| **Business events** | `DonationCreatedEvent` etc. | ❌ **Absent — no source entity raises them** |
| **Runtime population** | anything inserting `Notifications` automatically | ❌ **Absent** |

**Bottom line**: config in, display out, **no engine in between**. `TriggerEvent` is data-only today; nothing reads it.

---

## 3. Target architecture — the pipeline

```
Business action        Trigger source           Dispatch (NEW core)            Persist              Deliver
──────────────────────────────────────────────────────────────────────────────────────────────────────────
Aggregate raises   →  domain event (MediatR)  →  INotificationDispatcher    →  N× Notification   →  SignalR push
 domain event         OR Hangfire sweep          · match templates by          rows, each           → user-{id} group
 (sync CRUD)          OR workflow/pipeline hook   TriggerEvent + tenant        stamped CompanyId    → bell badge + toast
                                                 · eval TriggerCondition       + ToUserId           fallback: poll refetch
                                                 · resolve recipients
                                                 · render {{tokens}}
                                                 · (Hangfire for large fan-out)
```

Four firing mechanisms feed the **same** dispatcher (see §9 for which trigger uses which):

1. **Domain-event-driven** — synchronous CRUD (donation.created, contact.created, …). Entity becomes an `Aggregate`, raises an event, the existing SaveChanges interceptor publishes it.
2. **Scheduled/swept** — time-based (pledge.overdue, event.reminder, password.expiring, recurring.payment.failed). A Hangfire **recurring** job scans and calls the dispatcher.
3. **Workflow-driven** — approval engine hooks (approval.requested/granted/rejected).
4. **Pipeline-driven** — existing subsystems (import.completed from the import pipeline; contact.duplicate.found from the dedup service; system.error from the global exception handler).

The dispatcher does not care which mechanism fired it — it takes `(triggerCode, payload)` and produces notifications.

---

## 4. Component design

### 4.1 Domain events (Stage 1)

- Convert source entities that must notify from `Entity` → `Aggregate` (adds `AddDomainEvent`).
- Define lightweight event records under `Base.Domain/Events/NotifyEvents/` (or per-module event folders) carrying **only** what the dispatcher needs: the trigger code, `CompanyId`, the acting/initiating user, and a token payload dictionary.

```csharp
public sealed record NotificationTriggerEvent(
    string   TriggerCode,          // "donation.created"
    int      CompanyId,            // tenant — from the entity, NOT the acting user's default
    int?     InitiatedByUserId,    // for RecipientType.Initiated
    int?     AssignedUserId,       // for RecipientType.AssignedStaff
    IReadOnlyDictionary<string,string> Tokens   // {{DonationAmount}} => "$500", ...
) : IDomainEvent;
```

> **Design choice**: use a **single generic `NotificationTriggerEvent`** rather than one event type per business action. Business handlers construct it from their own domain event. This keeps the notification engine decoupled from every module's event vocabulary and avoids 20+ `INotificationHandler<T>` classes. (Alternative — one strongly-typed event per trigger — is more discoverable but far more boilerplate; recommend the generic record.)

### 4.2 Trigger → notification bridge (Stage 2)

A single `INotificationHandler<NotificationTriggerEvent>` in the Application layer forwards to the dispatcher. Business code raises `NotificationTriggerEvent`; it never touches notification internals.

### 4.3 `INotificationDispatcher` — the core (Stage 3)

```csharp
public interface INotificationDispatcher
{
    Task DispatchAsync(string triggerCode, int companyId,
                       NotificationContext ctx, CancellationToken ct);
    Task SendTestAsync(int templateId, int currentUserId, CancellationToken ct);  // closes ISSUE-4 on #36
}
```

Algorithm:
1. **Load matching templates** — `IsActive == true` AND `TriggerEvent == triggerCode` AND **(`CompanyId == companyId` OR `IsSystem == true`)`**. ⟵ *tenant scoping lives here.*
2. **Evaluate `TriggerConditionJson`** — parse `{field, operator, value}`, test against `ctx.Tokens`/payload. Skip template if it fails. Reuse the operator set already defined on #36 (`equals`, `greaterThan`, `lessThan`, `contains`).
3. **Resolve recipients** (§4.4).
4. **Render tokens** — replace `{{Token}}` in `NotificationTitle` / `NotificationTemplateText` / `ActionUrl` / `ActionLabel` from `ctx.Tokens` (backend equivalent of #36's FE preview `SAMPLE_TOKENS`). Unknown tokens → leave literal (do not fail dispatch).
5. **Persist + deliver** (§4.5, §4.6).
6. **Side-effect** — stamp `NotificationTemplate.LastTriggeredDate` (column already exists, currently unused).

Register as scoped DI; resolvable from both MediatR handlers and Hangfire jobs.

### 4.4 Recipient resolution — multi-tenant (Stage 3 cont.)

**Single-identity target — the resolver always produces `auth.Users.UserId`s, nothing else.** The app has one credentialed login table, `auth.Users` (PK `UserId int`); staff, members, and volunteers are *satellite profile tables that link back to a User*, not parallel identities:

- Staff → `app.Staffs.UserId` → `auth.Users`
- Member → `corg.Contacts.UserId` → `auth.Users`
- Volunteer → `app.Volunteers.ContactId` → `corg.Contacts.UserId` → `auth.Users`

The JWT carries only a `"UserId"` claim (= `Users.UserId`); `GetCurrentUserId()` returns it; and `Notification.ToUserId` / `FromUserId` are **already FKs to `auth.Users.UserId`** (see `NotificationConfiguration.cs`). So the resolver, the persisted `ToUserId`, and the SignalR group key `user-{UserId}` are the **same single id** for every audience — admin, staff, member, and volunteer alike. RecipientType is only *how you find which UserIds*; the output type never varies.

Members and volunteers are **in scope for in-app** delivery: once a Contact is onboarded as a member or volunteer they are provisioned a `User` + role, and the portal ("buddy") is chosen dynamically by request domain — a *render* concern layered over the same `UserId`. There is therefore no login-less-recipient problem in practice; the resolver may still defensively skip any target with a null `UserId` (a Contact/Volunteer not yet provisioned) and leave those to the email/WhatsApp channel.

**Two dimensions — Audience (the WHO-pool) × RecipientType (the HOW-narrowing).** Resolution is a two-stage funnel, **always scoped to `companyId`**:

**Stage A — `Audience`** picks the base pool of people (NEW `string` column on `NotificationTemplate`; default `Staff` so legacy templates are unchanged). Each pool → `auth.Users.UserId`s in the tenant:

| `Audience` | Base pool (scoped to `companyId`) |
|---|---|
| `Staff` | `app.Staffs.Where(s => s.CompanyId == c && !s.IsDeleted).Select(s => s.UserId)` |
| `Member` | `corg.Contacts.Where(c2 => c2.CompanyId == c && c2.UserId != null).Select(c2 => c2.UserId!)` |
| `Volunteer` | `app.Volunteers.Where(v => v.CompanyId == c).Select(v => v.Contact!.UserId)` where `ContactId != null && Contact.UserId != null` |
| `All` | union of the three pools above |

**Stage B — `RecipientType`** narrows *within* that pool (existing 5 values kept — #36 dropdown/validation unchanged; only their meaning is now "within the selected audience"):

| `RecipientType` | Resolves to (all → `auth.Users.UserId`), pool = Stage-A result |
|---|---|
| `AllStaff` | the **entire** Stage-A pool (name kept for back-compat; now reads "all in audience") |
| `Roles` | pool **∩** users holding any `NotificationTemplateRole.RoleCode[]` **within `companyId`** (join `auth.UserRoles`) — role narrowing works uniformly for staff, `MEMBERSHIP`, `VOLUNTEER` roles |
| `AssignedStaff` | `ctx.AssignedUserId` (the record owner/assignee — contextual, single user; audience-independent) |
| `Initiated` | `ctx.InitiatedByUserId` (contextual, single user; audience-independent) |
| `Custom` | deferred (needs `NotificationTemplateUser` child — out of scope, ISSUE-7 on #36) |
| `IncludeAdmins` (additive flag) | union in all Org Admins of `companyId` on top of whatever Stage B produced |

> **Back-compat**: existing templates have no `Audience` → resolver defaults it to `Staff`, so a legacy `RecipientType=AllStaff` template still means "all staff of the company," identical to today. New capability = choosing `Member`/`Volunteer`/`All` as the pool, optionally role-narrowed.

De-dup the final user set (a user matched by both role and the admin flag gets **one** notification). Skip any resolved person whose `UserId` is null (unprovisioned Contact/Volunteer) — those fall through to the email/WhatsApp channel. Respect future `UserNotificationMute` preferences when that table lands (currently a placeholder — see #35 `MuteNotificationType`).

### 4.5 Persistence + async fan-out (Stage 4)

**Two delivery paths (both required — the dispatcher chooses by resolved-count):**

- Insert **one `notify.Notifications` row per resolved user**, each stamped `CompanyId = companyId` (from payload/tenant, **never** the acting user's default company) and `ToUserId = userId`, plus rendered title/body/icon/priority/action + `NotificationTemplateId`.
- **① Direct / one-on-one (small set, ≤ threshold, e.g. ≤ 20)** → insert **inline in the request** and push immediately. This is the common contextual case (`AssignedStaff`, `Initiated`, small `Roles`) — a single addressed notification, synchronous, no job overhead.
- **② Hangfire fan-out (large set — `Audience=All`/`Staff`/`Member` broadcast, big role groups)** → enqueue a **Hangfire job** (`BackgroundJob.Enqueue`) that fans out, mirroring the email pipeline (`EmailExecutorService` → `SendQueuedEmailAsync`). The job **must** rebuild tenant/user context via the **synthetic `ClaimsPrincipal`** pattern (`OnlineDonationMapJobRunner`) — no `HttpContext` in a job.
- The threshold is a single tunable constant on the dispatcher; both paths call the **same** persist+push code, differing only in where they run.
- The table and its read/mark-read CRUD already exist — **no new instance entity needed.**

### 4.6 Real-time delivery — SignalR (Stage 5)

New `NotificationHub` (mirror `ImportProgressHub` + `ImportProgressNotifier`):

- **Auth**: JWT bearer (same token the FE already sends). On connect, read `userId` + `companyId` from claims; add the connection to group **`user-{userId}`** (and optionally `company-{companyId}` for broadcast-style alerts).
- **Push**: after a notification row is committed, call `IHubContext<NotificationHub>.Clients.Group($"user-{toUserId}").SendAsync("notification", payload)`. From a Hangfire job, inject `IHubContext` (works outside request scope).
- **Payload**: the notification DTO (id, title, body, icon, priority, actionUrl/label, createdDate) + the recipient's new unread count.
- **Register**: `AddSignalR()` + `MapHub<NotificationHub>("/hubs/notifications")` in `Program.cs` (next to import-progress).

**Fallback**: if the socket is down, the existing refetch-on-navigation still works; add a low-frequency backstop poll (`pollInterval` on the unread-count query) so counts self-heal.

### 4.7 Frontend wiring

1. **Re-enable the bell** — uncomment `<NotificationsPanel/>` at `header.tsx:31`. It already renders the unread badge + list.
2. **Centralize unread count** — move the count into a shared store (extend `notification-center-store.ts` or a small `notification-live-store.ts`) so the bell and the Center page (#35) read one source. Kill the `refetchUnreadBell` no-op stub.
3. **SignalR client** — add a `@microsoft/signalr` `HubConnection` to `/hubs/notifications` (mirror `use-import-signalr.ts` + `BaseUrlConfig.ts` `SIGNALR_HUB_URL`). On `"notification"` event: increment unread count, prepend to the inbox list if mounted, and fire a `sonner` toast (app-wide toast lib) with the title + an action linking to `ActionUrl`.
4. **Toast**: use `sonner` (`toast(...)` with an action button) — consistent with the rest of the app.

---

## 5. Multi-tenant invariants (must hold everywhere)

1. Template matching filters on **`CompanyId == tenant OR IsSystem == true`** — a company sees its own + global system templates, never another tenant's.
2. Recipient resolution (roles, all-staff, admins) is **always** scoped to the triggering `CompanyId`.
3. Every `Notification` row carries `CompanyId`; the tenant interceptor + `GetInboxNotifications` (`ToUserId == currentUser`) enforce isolation on read.
4. **Background jobs rebuild tenant context** via the synthetic `ClaimsPrincipal` — omission = cross-tenant leak/misfire.
5. **SignalR groups are keyed per user** (`user-{userId}`) so a user only ever receives their own company's pushes. If `company-{companyId}` broadcast groups are used, verify the connecting user actually belongs to that company from claims — never trust a client-supplied company id.
6. System templates (`CompanyId = null`, `IsSystem = true`) fire for **all** tenants; the `companyId` on the produced rows comes from the **triggering action's** tenant, not the template.

---

## 6. New / changed DB objects

- **No new columns** on `Notifications` — it already has everything (`ToUserId`, `IsRead`, `CompanyId`, `Category`, `Priority`, `IconCode/Color`, `ActionUrl/Label`, `IsStarred`, `NotificationTemplateId`).
- **Optional** `notify.UserNotificationMute` (userId, companyId, notificationType/category, mutedUntil) — unblocks the existing mute placeholder (#35). Defer to a later phase.
- **No migration for the core engine** — it's pure code (events, dispatcher, hub, jobs). *(Migrations are user-authored per project convention — flag any that arise; none expected for Phase 1.)*

---

## 7. File manifest

### Backend — new

| File | Purpose |
|---|---|
| `Base.Domain/Events/NotifyEvents/NotificationTriggerEvent.cs` | generic trigger event record |
| `Base.Application/Services/Notifications/INotificationDispatcher.cs` + `NotificationDispatcher.cs` | core engine (match → condition → recipients → render → persist → push) |
| `Base.Application/Services/Notifications/INotificationRecipientResolver.cs` + impl | RecipientType → tenant-scoped user list |
| `Base.Application/Services/Notifications/NotificationTokenRenderer.cs` | `{{token}}` substitution |
| `Base.Application/Business/NotifyBusiness/.../NotificationTriggerHandler.cs` | `INotificationHandler<NotificationTriggerEvent>` bridge |
| `Base.Application/Hubs/NotificationHub.cs` | SignalR hub (per-user groups) |
| `Base.Infrastructure/Services/Notifications/NotificationPushNotifier.cs` | `IHubContext` push wrapper (mirror `ImportProgressNotifier`) |
| `Base.Infrastructure/Services/Notifications/NotificationFanoutJob.cs` | Hangfire job for large recipient sets |
| Scheduled sweeps (per swept trigger) | e.g. `PledgeOverdueNotificationSweep`, `EventReminderSweep` |

### Backend — modified

| File | Change |
|---|---|
| `NotificationTemplateMutations.cs` (#36) | add real `SendTest` calling `INotificationDispatcher.SendTestAsync` (closes ISSUE-4) |
| source entities (Donation, Contact, Campaign, Event, …) | `Entity` → `Aggregate`; raise `NotificationTriggerEvent` in create/update paths |
| `Base.API/Program.cs` | `AddSignalR()` (if not global) + `MapHub<NotificationHub>("/hubs/notifications")`; register dispatcher/resolver/notifier in DI; register recurring sweep jobs |
| DI registration module | scoped `INotificationDispatcher`, `INotificationRecipientResolver`, singletons for notifier |

### Frontend — modified/new

| File | Change |
|---|---|
| `header.tsx:31` | uncomment `<NotificationsPanel/>` |
| `notification-center-store.ts` (or new `notification-live-store.ts`) | centralized unread count; replace `refetchUnreadBell` no-op |
| `use-notification-signalr.ts` (new, mirror `use-import-signalr.ts`) | `@microsoft/signalr` client → `/hubs/notifications`; on event: bump count, prepend item, `sonner` toast |
| `BaseUrlConfig.ts` | add `NOTIFICATION_HUB_URL` |
| `NotificationsPanel` / center hook | consume the shared live store |

---

## 8. Phased delivery plan

| Phase | Deliverable | Proves | Est. |
|---|---|---|---|
| **0 — Engine** | `INotificationDispatcher` + recipient resolver + token renderer + generic `NotificationTriggerEvent` + bridge handler. Persists rows (inline, no push yet). | The pipeline produces correct per-user rows for one wired trigger; verify in the existing Notification Center by refresh. | core |
| **1 — First vertical trigger** | Wire **one** high-value trigger end-to-end (recommend `approval.requested` or `donation.created`) — entity→Aggregate, raise event, dispatch, rows appear in #35. Real `SendTest` on #36. | Multi-tenant correctness (system + company templates, role/admin recipients, condition eval) on a real flow. | small |
| **2 — Real-time** | `NotificationHub` + push notifier + FE SignalR client + re-enabled bell + centralized unread count + toast. | Notifications appear live for admin + staff without refresh. | medium |
| **3 — Async fan-out** | Hangfire fan-out job for `AllStaff`/large role sets, with synthetic-principal tenant context. | Scale + tenant safety in jobs. | small |
| **4 — Remaining trigger areas** | Integrate the rest of §9 by mechanism (domain-event, swept, workflow, pipeline). Each = raise event + map tokens; no engine change. | Full required coverage. | per-area |
| **5 (opt) — Mute prefs** | `UserNotificationMute` table + honor it in recipient resolution; close #35 mute placeholder. | User control. | small |

Recommend a **Phase 0 → 1 → 2** first cut for a demoable real-time slice, then fan the rest of §9 in.

---

## 9. Trigger integration checklist (required areas)

Each trigger needs a **firing source**. Grouped by mechanism:

**Domain-event-driven (sync CRUD → entity becomes `Aggregate`):**
- `donation.created`, `donation.updated`
- `cheque.status.changed`, `cheque.status.bounced`
- `contact.created`, `contact.updated`
- `campaign.created`, `campaign.ended`
- `event.registration.new`

**Scheduled / swept (Hangfire recurring job scans + dispatches):**
- `pledge.payment.overdue`
- `recurring.payment.failed`
- `event.reminder`
- `user.password.expiring`

**Workflow-driven (approval engine hooks):**
- `approval.requested`, `approval.granted`, `approval.rejected`

**Pipeline-driven (existing subsystems fire the trigger):**
- `import.completed` — from the import pipeline (already has SignalR infra)
- `campaign.goal.reached` — from donation aggregation crossing goal
- `contact.duplicate.found` — from the dedup service
- `system.error` — from the global exception handler

> These are the trigger codes referenced by the 12 seeded system templates on #36 + the §③ catalog. Confirm the exact required set with product before Phase 4 — some (e.g. `system.error`) may be admin-only or deferred.

---

## 10. Open decisions & risks

1. **Event granularity** — single generic `NotificationTriggerEvent` (recommended, low boilerplate) vs. one typed event per trigger (more discoverable). *Recommend generic.*
2. **Which entities become `Aggregate`s** — audit each source entity; converting `Entity`→`Aggregate` is low-risk but touches core domain classes. Sequence carefully behind the interceptor.
3. **SignalR scaling** — single-server is fine now; multi-instance later needs a Redis backplane (`AddSignalR().AddStackExchangeRedis(...)`). Note but don't build yet.
4. **Token payload contract** — each business handler must supply the right `{{Tokens}}`; mismatches show literal tokens. Define a per-trigger token map alongside §9.
5. **Fan-out volume** — `AllStaff` on a large tenant = many rows; the Hangfire threshold (§4.5) and batching size need tuning.
6. **Mute/preferences** — currently a placeholder; decide whether Phase 1 must respect any opt-out or defer entirely to Phase 5.

---

## 11. Explicitly out of scope

- Email / WhatsApp / Push channel dispatch at trigger time (`EnableEmail/WhatsApp/Push`) — those persist on the template but route through the **existing** email/WhatsApp pipelines, separate work (#36 ISSUE-5/6).
- `RecipientType = Custom` user-picker (#36 ISSUE-7).
- Mobile push (`EnablePush` reserved, server-forced false).
- Multi-server SignalR backplane (Redis) until horizontal scaling is needed.
