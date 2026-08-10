# PSS 2.0 — Phase 6 · Generic Tenant Intimation System

**Status:** NOT STARTED
**Source brief:** `prompts/intimation_prompt.md`
**Scope:** Backend (Base.Domain / Base.Application / Base.API) + Frontend (tenant shell banner, platform console) + seed SQL. **No EF migration authored here — the user writes it.**

---

## ⓪ Why this phase exists (read this before anything else)

The source brief asks for a "generic Tenant Intimation System". Taken at face value it reads as a
greenfield subsystem. **It is not.** A grounding pass over the codebase found that roughly 70% of the
brief is already built and shipped under P-22 and the in-app notification runtime work:

- `INotificationDispatcher` / `INotificationSender` / `INotificationWriter` / `INotificationRecipientResolver` — the generic "business modules never touch the UI" seam the brief's §"Important Design Principle" asks for **already exists**.
- Trigger-driven auto-generation exists (`NotificationTriggerEvent` → MediatR → `NotificationTriggerHandler`).
- The Notification Center exists, with read/unread, badge count, detail, action, mark-all, delete, star, filter, search and mute — already **past** the brief's MVP list.
- Recipient shapes exist (`NotificationTarget`: users / roles / all-staff, tenant and platform).
- Delivery tracking and analytics exist (`notify.NotificationJobs` header + 8 per-recipient columns on `notify.Notifications`).
- Tenant isolation exists and is enforced *structurally*, not by convention.
- A manual composer exists (`SendNotificationCommand` + `notification-composer-dialog.tsx`).

**Do not rebuild any of that.** The word "intimation" currently appears in exactly one file in the
entire repository — the brief itself. There is no half-built surface to reconcile with, and no
existing name to collide with.

What is genuinely missing is five things, and this phase builds those five and nothing else.

---

## ① Grounding — what exists, what is missing

### Exists (do not modify unless a fix below names the file)

| Concern | Where |
|---|---|
| Dispatch engine | `Base.Application/Services/Notifications/NotificationDispatcher.cs` |
| Direct send seam (no template) | `Services/Notifications/INotificationSender.cs`, `NotificationSender.cs` |
| Recipient resolution | `Services/Notifications/NotificationRecipientResolver.cs` |
| Address space (TENANT \| PLATFORM) | `Services/Notifications/NotificationScope.cs` |
| Audience shapes + broadcast gate | `Services/Notifications/NotificationTarget.cs`, `NotificationAudience.cs` |
| Instance row | `Base.Domain/Models/NotifyModels/Notification.cs` (namespace is `SharedModels`) |
| Fan-out header | `Base.Domain/Models/NotifyModels/NotificationJob.cs` |
| Tenant inbox UI | `presentation/components/page-components/crm/notification/notificationcenter/` |
| Platform inbox UI | `app/[lang]/(master)/ops/notifications/page.tsx` |
| Bell | `components/layout-components/app-topbar/index.tsx:233` |
| Nightly Hangfire registration pattern | `Base.API/Extensions/NotificationRetentionRegistrationExtension.cs` |
| The one shell banner slot | `presentation/provider/app-shell-provider.tsx:307` |

### Missing — the five gaps this phase closes

1. **The platform cannot address a tenant's users.** P-22 deliberately made this
   *unrepresentable*: `NotificationTarget` has a private constructor and named factories only, a
   Platform target is hard-coded to `CompanyId = null`, and the file's own comment calls a CompanyId on a
   platform notification "a cross-tenant leak". `/ops/notifications` is the platform team's **own**
   inbox, not a tenant-addressing console. `AllTenantsAllStaff` was explicitly declined.
2. **No banner channel.** `Notification` *is* the in-app row; there is no presentation-channel
   abstraction beneath it. Meanwhile **13 bespoke one-off banners** exist across the codebase
   (pledge-overdue, failed-payments, connection-status, base-currency, revision, reply-window, …) —
   precisely the anti-pattern the brief warns against, already replicated 13 times.
3. **No condition / resolution model.** `Notification` has no dedup key, no `ExpiresAt`, no
   dismissal, no resolved state. "Email provider missing" would fire a fresh row on every trigger
   forever, and nothing would remove it when the provider is configured. The brief's §"Resolution"
   and §"Duplicate Prevention" are unimplementable against the current schema.
4. **No condition detectors.** Nothing evaluates "provider missing", "gateway missing",
   "subscription expiring".
5. **Severity drives nothing.** `NOTIFICATIONPRIORITY` is Normal/High/Urgent and has no visual contract.

### INV-10 — the invariant this phase establishes

> **An Intimation is addressed to a TENANT, never to a user in another address space.**
>
> The platform writes a row bearing a `CompanyId`. It never names a user outside its own scope.
> Recipient resolution happens **tenant-side**, through the existing resolver, inside the tenant's own
> scope. This is why a new record is introduced rather than a cross-scope `NotificationTarget`
> factory: it delivers the brief's Platform → Tenant A → Tenant Manager flow **without weakening the
> P-22 leak guard by one line**.

Corollary: `notify.Intimations` is the **condition** (one row per tenant per condition).
`notify.Notifications` remains the **per-user delivery row** (N per tenant). Conflating the two is
what makes dedup and auto-resolve impossible today; keeping them separate is the entire point.

```
        Platform / System condition
                    ↓
        notify.Intimations   ← ONE row, addressed to a tenant
                    ↓
        ┌───────────────────┴───────────────────┐
        ↓                                       ↓
  Banner channel                        Notification channel
  (tenant reads its own rows)           (existing sender, tenant-scoped fan-out)
```

---

## ② Hard constraints

1. **Do not modify `NotificationTarget.cs`, `NotificationAudience.cs` or `NotificationScope.cs`.** No new
   cross-scope factory. No `PlatformToTenant` shape. INV-10 exists so these files stay untouched.
2. **Do not modify `Notification.cs`, `NotificationJob.cs`, the dispatcher, the resolver or the
   writer.** The notification channel is consumed through the *existing public seam*
   (`INotificationSender.SendAsync`) and through nothing else.
3. **Do not modify `PlanStatusBanner`** or `useEntitlements`. See §⑦.1 — quota/usage intentionally
   stays out of this system.
4. **Do not touch `middleware.ts`, `PUBLIC_ROUTES`, `authorized()`, or `PlatformGate`** (Phase 5 / Phase 2.1 surfaces).
5. **Do not author an EF migration.** Do not run `dotnet ef migrations add`. Do not edit
   `ApplicationDbContextModelSnapshot`. Write entity + configuration + `DbSet` registration only; the
   user creates the migration.
6. **Do not run `dotnet build`.** Make compiling changes and hand off.
7. **Do not commit.** `git add` only, from **inside** the nested repos (`PSS_2.0_Backend`,
   `PSS_2.0_Frontend` each own a `.git/`). Never `git push`, amend or tag. Never add a
   `Co-Authored-By` trailer or a "Generated with Claude Code" line.
8. **Do not edit `BaseUrlConfig.ts`** — it is user-managed.
9. **Do not probe ports, processes or API liveness.** Do not gate any deliverable on the API running.
10. **PostgreSQL, not SQL Server.** Seeds use `now()`, double-quoted identifiers, `TRUE`/`FALSE`,
    `WHERE NOT EXISTS`, `LIMIT 1`, and must be idempotent and re-runnable.
11. **No new delivery channel.** Email / SMS / WhatsApp / Push are explicitly out. The architecture
    must not *prevent* them; it must not *contain* them.
12. **No scheduling / publishing workflow** for manual intimations. See §⑦.2.

---

## ③ Fixes

### Backend

#### F-7.1 — `notify.Intimations` entity + configuration

New file `Base.Domain/Models/NotifyModels/Intimation.cs`, mirroring the style of
`NotificationJob.cs` (inherit `Entity`, `[Table("Intimations", Schema = "notify")]`).

| Column | Type | Notes |
|---|---|---|
| `IntimationId` | `int` PK | |
| `CompanyId` | `int` **NOT NULL** | The addressed tenant. INV-10: this is the security predicate. FK → `app.Companies`. |
| `IntimationTypeCode` | `string(100)` NOT NULL | `EMAIL_PROVIDER_MISSING`, `PAYMENT_GATEWAY_MISSING`, `SUBSCRIPTION_EXPIRING`, `MANUAL` |
| `SourceKey` | `string(200)` NULL | Discriminator *within* a type. Part of the dedup key. |
| `Kind` | `string(20)` NOT NULL | `CONDITION` \| `INFORMATIONAL` |
| `Status` | `string(20)` NOT NULL | `ACTIVE` \| `RESOLVED` \| `EXPIRED` |
| `SourceType` | `string(20)` NOT NULL | `SYSTEM` \| `PLATFORM` |
| `CategoryId` | `int?` FK → `sett.MasterDatas` | TypeCode `INTIMATIONCATEGORY` |
| `SeverityId` | `int?` FK → `sett.MasterDatas` | TypeCode `INTIMATIONSEVERITY` |
| `Title` | `string(200)` NOT NULL | |
| `Message` | `string(2000)` NOT NULL | |
| `ActionLabel` | `string(100)` NULL | |
| `ActionUrl` | `string(500)` NULL | |
| `RequiredMenuCode` | `string(100)` NULL | Permission-awareness — see F-7.5 |
| `RequiredCapability` | `string(100)` NULL | |
| `IsDismissible` | `bool` NOT NULL | |
| `PublishedAt` | `DateTime?` | |
| `ExpiresAt` | `DateTime?` | |
| `ResolvedAt` | `DateTime?` | |
| `CreatedByUserId` | `int?` | NULL = system-generated |
| `MetadataJson` | `string?` (`jsonb`) | |

**Why `Kind`, `Status` and `SourceType` are plain strings and not MasterData FKs** — this is the
`NotificationScope.cs` precedent, and the reasoning transfers verbatim: these three drive the banner
read predicate and the resolution sweep. A predicate that decides whether a tenant sees a CRITICAL
notice must not depend on a join to a seedable lookup row that an environment can be missing.
`CategoryId` / `SeverityId` **are** MasterData FKs, because they drive display and configuration only —
the `NotificationTemplate` precedent.

**Dedup index (the single most important line in this phase):**

```
UNIQUE (CompanyId, IntimationTypeCode, SourceKey) WHERE Status = 'ACTIVE'
```

A PostgreSQL *partial* unique index. EF cannot express the predicate in a fluent index, so record it
in the configuration with `.HasFilter("\"Status\" = 'ACTIVE'")` and **call it out explicitly in the
build log** so the user's migration carries it. This one index is what makes "detected on every
login" harmless without any application-level lock.

Register `DbSet<Intimation>` on `INotifyDbContext` and the `ApplicationDbContext` partial, exactly as
`NotificationJob` is registered.

#### F-7.2 — `notify.IntimationDismissals`

`IntimationDismissalId` PK, `IntimationId` FK (cascade), `UserId` FK → `auth.Users`, `DismissedAt`.
Unique `(IntimationId, UserId)`.

Dismissal is a **per-user** fact about a **tenant-wide** record, which is exactly why it cannot be a
column on `Intimations` and cannot reuse `Notification.IsRead`.

#### F-7.3 — MasterData seed

`sql-scripts-dyanmic/seed_intimation_masterdata.sql`, idempotent, following
`seed_notification_runtime_masterdata.sql`:

- `INTIMATIONCATEGORY` — `Communication`, `Payment`, `Subscription`, `Configuration`, `System`, `Security`
- `INTIMATIONSEVERITY` — `INFO`, `WARNING`, `CRITICAL`

**Severity is three values, not the brief's five.** Severity must *mean* something mechanical, and
five levels where two are visually indistinguishable is decoration. The contract:

| Severity | Notification | Banner | Dismissible |
|---|---|---|---|
| `INFO` | yes | **no** | n/a |
| `WARNING` | yes | yes | yes (per user, persists) |
| `CRITICAL` | yes | yes | **no** — clears only on resolve/expire |

`IsDismissible` is stored rather than derived so a platform admin can override downward, but the
default must follow this table.

#### F-7.4 — `IIntimationService` — the raise / resolve seam

`Base.Application/Services/Intimations/IIntimationService.cs` + implementation:

```csharp
Task<bool> RaiseAsync(IntimationRequest request, CancellationToken ct);   // true = newly raised
Task<bool> ResolveAsync(int companyId, string typeCode, string? sourceKey, CancellationToken ct);
```

- `RaiseAsync` is an **upsert against the dedup key**. If an ACTIVE row already matches, it
  refreshes `Message`/`MetadataJson` and returns `false`. It does **not** create a second row and it
  does **not** re-notify.
- **The notification channel fires only on a `true` return** (first raise). This is the brief's
  §"Duplicate Prevention" answered in one line rather than with a re-notification cadence engine.
- `ResolveAsync` sets `Status = 'RESOLVED'`, stamps `ResolvedAt`, and is idempotent when nothing matches.
- Follow `INotificationSender`'s contract discipline: **never throw into a business handler.** A
  configuration save that committed must not report failure because an intimation row did not write.

#### F-7.5 — Tenant read + dismiss

`GetActiveIntimations` query (tenant scope, `CompanyId` from claims — **never** a parameter):

- `Status = 'ACTIVE'`
- `ExpiresAt IS NULL OR ExpiresAt > now()`
- not dismissed by the calling user (anti-join on `IntimationDismissals`)
- **capability filter**: when `RequiredMenuCode` / `RequiredCapability` are set, drop the row unless
  `ICustomAuthorizeService.HasAccessAsync(userId, menu, capability)` passes.

That last rule is the brief's "Tenant Manager → notification + banner; Normal Staff → nothing", and it
costs one existing service call. A caseworker cannot configure a payment gateway, so for them the
notice is a standing alarm about someone else's problem.

`DismissIntimation(intimationId)` mutation — rejects when the row is not `IsDismissible`, and
re-derives the tenant from claims before writing.

#### F-7.6 — Platform console commands

Under `Base.Application/Business/OpsBusiness/Intimations/`, capability-gated on a new
`PLATFORM_INTIMATIONS` menu:

- `CreateIntimation` — platform admin picks tenant + category + severity + title + message + optional
  action; writes `SourceType = 'PLATFORM'`, `Kind = 'INFORMATIONAL'`, `IntimationTypeCode = 'MANUAL'`,
  `SourceKey = null`. Because MANUAL rows would collide on the dedup index, generate `SourceKey` as
  the new row's identity substitute (e.g. a GUID string) so two manual notices to the same tenant can
  coexist. **Call this out in the build log** — it is the one place the dedup key needs a deliberate escape.
- `ResolveIntimation` / `ExpireIntimation` — platform-side manual close.
- `GetIntimations` — platform list with tenant filter and status filter.

#### F-7.7 — Condition detectors + sweep

`Base.Application/Services/Intimations/Conditions/` — one class per condition behind a common
`IIntimationCondition` with `Task EvaluateAsync(int companyId, CancellationToken ct)` that calls either
`RaiseAsync` or `ResolveAsync`. **Three detectors for MVP:**

1. `EMAIL_PROVIDER_MISSING` — no active provider resolvable for the company. Ground this against the
   existing per-company provider resolution (`CompanyEmailProviders` / the recent platform-vs-BYO
   ownership work) rather than inventing a new check.
2. `PAYMENT_GATEWAY_MISSING` — online donations enabled but no active `CompanyPaymentGateways` row.
3. `SUBSCRIPTION_EXPIRING` — expiry within 30 days. Resolve on renewal.

Register a nightly Hangfire recurring job that iterates active companies and runs every detector,
copying `NotificationRetentionRegistrationExtension.cs` **exactly** (including the try/catch and the
warning log). Cron `45 3 * * *` UTC — after the 03:15 retention purge. Rebuild tenant context per
company using the synthetic-principal pattern; do not assume an ambient tenant inside a job.

Detectors must be *idempotent by construction*: running the sweep twice in a row must produce zero
new rows.

#### F-7.8 — Notification channel bridge

Inside `RaiseAsync`, on a `true` return only, call the **existing**
`INotificationSender.SendAsync` with a tenant target — `NotificationTarget.TenantRoles(companyId, …)`
when the intimation carries a `RequiredCapability`-bearing role set, otherwise
`TenantAllStaff(companyId)` — using `TriggerCode = "intimation.raised"` and carrying the
title / message / action through. Wrap in try/catch and log; a failed notification must not roll back
the intimation.

### Frontend

#### F-7.9 — Generic `IntimationBanner`

`presentation/components/intimation/intimation-banner.tsx`, mounted in the **existing** shell slot at
`app-shell-provider.tsx:307`, alongside `PlanStatusBanner` (which stays exactly as it is).

Behaviour:

- Renders only `WARNING` and `CRITICAL` rows; `INFO` is notification-only.
- **Stacks at most 2**, ordered severity-then-recency. Everything beyond collapses into a
  `+N more` link to the notification center. **Do not rotate or carousel** — a message that moves
  while you read it is a message you do not read.
- `CRITICAL` renders with no dismiss control at all (not a disabled one).
- Dismiss calls the mutation and removes the row optimistically.
- Solid accent background with white foreground, per the house convention (`bg-destructive-600` /
  `bg-warning-600`, matching `plan-status-banner.tsx`).
- Renders nothing — no skeleton, no reserved height — while loading or when empty.

#### F-7.10 — Platform console screen

`app/[lang]/(master)/ops/intimations/page.tsx` + page components, mirroring the structure of the
sibling `ops/` screens. Reuse the shared grid (`FlowDataTable` / `AdvancedDataTable`) — **do not fork
a bespoke table** — and the canonical `FormInput` / `FormSelect` / `FormDatePicker` components. No
`window.confirm` / `alert` / `prompt` anywhere.

#### F-7.11 — Menu + capability seed

`sql-scripts-dyanmic/platform-intimations-menu-capability-seed.sql`, following
`platform-tenant-access-menu-seed.sql`: Menus + MenuCapabilities + RoleCapabilities, idempotent,
granting the platform admin role. Menu code `PLATFORM_INTIMATIONS`.

---

## ④ Static verification

Backend — **do not run `dotnet build`.** Confirm by inspection that every new file compiles against
the seams it uses, and that `DbSet` registration exists in both `INotifyDbContext` and the
`ApplicationDbContext` partial.

Frontend:

```
rm -rf .next/types && npx tsc --noEmit --incremental false
```

Must exit 0. Do not use `Glob` with `[lang]` in the pattern — `[…]` is a glob character class and
silently matches nothing; use `Get-ChildItem -LiteralPath … -Recurse`. Do not `Select-String` across
`tsconfig.tsbuildinfo` (multi-MB single line).

---

## ⑤ Deferred manual acceptance (user runs when convenient)

| # | Check |
|---|---|
| A1 | Platform console creates an intimation for Tenant A; it appears in Tenant A's banner. |
| A2 | **Tenant B sees nothing.** The isolation check — this is the one that matters most. |
| A3 | A `WARNING` banner dismisses, stays dismissed across reload, and stays dismissed for that user only. |
| A4 | A `CRITICAL` banner has no dismiss control and survives reload. |
| A5 | Run the sweep twice — the second run creates zero new rows. |
| A6 | Configure the missing email provider; the banner disappears on the next sweep without manual action. |
| A7 | A user lacking `RequiredCapability` sees neither banner nor notification. |
| A8 | Three or more active intimations → 2 banners + `+N more`. |
| A9 | The in-app notification fires on first raise **only** — not on the second sweep. |
| A10 | `PlanStatusBanner` still renders independently and is unchanged. |

---

## ⑥ Deliverable

Staged, not committed, in the nested repos. A Build Log appended at §⑧ recording: every file added
and changed, the two migration tasks handed to the user (create `notify.Intimations` +
`notify.IntimationDismissals`, **including the partial unique index**), any deviation from this
prompt with its reason, and anything discovered that this prompt got wrong.

---

## ⑦ Out of scope — deliberate decisions, not omissions

1. **Usage / quota intimations are NOT built.** The brief's Scenario 2 ("email usage 90%") is already
   covered by `PlanStatusBanner`, which reads live entitlement meters. Routing it through intimations
   too would put two banners on screen saying the same thing, and would move a live meter reading
   behind a nightly sweep — strictly worse. Quota stays with the plan system.
2. **No Draft / Scheduled / Publish / Cancel workflow.** Lifecycle is four states —
   `ACTIVE` → `RESOLVED` | `EXPIRED` (plus manual create). Draft-and-schedule is a
   content-management surface; "create it when you want it live" covers every scenario in the brief.
3. **No re-notification cadence.** First-raise-only, plus resolve-and-reappear, is the complete
   dedup story. A cadence engine can be added later against `MetadataJson` without schema change.
4. **No banner-impression analytics.** `NotificationJobs` and the eight delivery columns already
   cover the notification half. Impression telemetry is the classic thing that gets built and never read.
5. **Email / SMS / WhatsApp / Push.** Architecturally unblocked — `IIntimationService` is the fan-out
   point and a new channel is a new call inside `RaiseAsync` — but not built.
6. **The 13 existing bespoke banners are NOT migrated.** They are screen-local and contextual;
   this system is for tenant-wide platform intimations. Migrating them is a separate, later decision.

---

## ⑧ Build Log

Built 2026-08-08. All 11 fixes (F-7.1 … F-7.11) delivered. Staged, **not committed**, in each nested
repo. No EF migration authored, no `dotnet build` run, no `ApplicationDbContextModelSnapshot` edit.

### 8.1 Backend — files added

`PSS_2.0_Backend/PeopleServe/Services/Base/`

| Fix | File |
| --- | --- |
| F-7.1 | `Base.Domain/Models/NotifyModels/Intimation.cs` |
| F-7.2 | `Base.Domain/Models/NotifyModels/IntimationDismissal.cs` |
| F-7.1 | `Base.Infrastructure/Data/Configurations/NotifyConfigurations/IntimationConfiguration.cs` |
| F-7.2 | `Base.Infrastructure/Data/Configurations/NotifyConfigurations/IntimationDismissalConfiguration.cs` |
| F-7.3 | `sql-scripts-dyanmic/seed_intimation_masterdata.sql` |
| F-7.4 | `Base.Application/Services/Intimations/IIntimationService.cs` |
| F-7.4 | `Base.Application/Services/Intimations/IntimationService.cs` |
| F-7.4 | `Base.Application/Services/Intimations/IntimationRequest.cs` |
| F-7.7 | `Base.Application/Services/Intimations/IIntimationSweepService.cs` |
| F-7.7 | `Base.Application/Services/Intimations/IntimationSweepService.cs` |
| F-7.7 | `Base.Application/Services/Intimations/Conditions/IIntimationCondition.cs` |
| F-7.7 | `Base.Application/Services/Intimations/Conditions/EmailProviderMissingCondition.cs` |
| F-7.7 | `Base.Application/Services/Intimations/Conditions/PaymentGatewayMissingCondition.cs` |
| F-7.7 | `Base.Application/Services/Intimations/Conditions/SubscriptionExpiringCondition.cs` |
| F-7.7 | `Base.API/Extensions/IntimationSweepRegistrationExtension.cs` |
| F-7.5 | `Base.Application/Business/NotifyBusiness/Intimations/Queries/GetActiveIntimations.cs` |
| F-7.5 | `Base.Application/Business/NotifyBusiness/Intimations/Commands/DismissIntimation.cs` |
| F-7.5 | `Base.Application/Schemas/NotifySchemas/IntimationSchemas.cs` |
| F-7.5 | `Base.API/EndPoints/Notify/Queries/IntimationQueries.cs` |
| F-7.5 | `Base.API/EndPoints/Notify/Mutations/IntimationMutations.cs` |
| F-7.6 | `Base.Application/Business/OpsBusiness/Intimations/Queries/GetIntimations.cs` |
| F-7.6 | `Base.Application/Business/OpsBusiness/Intimations/Commands/CreateIntimation.cs` |
| F-7.6 | `Base.Application/Business/OpsBusiness/Intimations/Commands/ResolveIntimation.cs` |
| F-7.6 | `Base.Application/Business/OpsBusiness/Intimations/Commands/ExpireIntimation.cs` |
| F-7.6 | `Base.API/EndPoints/Ops/Queries/IntimationOpsQueries.cs` |
| F-7.6 | `Base.API/EndPoints/Ops/Mutations/IntimationOpsMutations.cs` |

### 8.2 Backend — files changed

| File | Change |
| --- | --- |
| `Base.Application/Data/Persistence/INotifyDbContext.cs` | `DbSet<Intimation>` + `DbSet<IntimationDismissal>` declared on the interface |
| `Base.Infrastructure/Data/Persistence/NotifyDbContext.cs` | Same two `DbSet`s on the concrete partial — **both halves registered**, per §④ |
| `Base.Application/DependencyInjection.cs` | `IIntimationService`, `IIntimationSweepService` and the three `IIntimationCondition` implementations registered scoped |
| `Base.API/Program.cs` | Nightly sweep recurring job wired via `AddIntimationSweepRecurringJob()` |

Nothing in `NotificationTarget.cs`, `NotificationAudience.cs`, `NotificationScope.cs`,
`Notification.cs`, `NotificationJob.cs`, the dispatcher, the resolver or the writer was touched
(§② 1–2). The notification bridge (F-7.8) consumes only the public
`INotificationSender.SendAsync` seam, fires **only when `RaiseAsync` returns `true`** (a first
raise, never a re-raise of an already-ACTIVE condition), and carries
`TriggerCode = "intimation.raised"`.

### 8.3 Frontend — files added

`PSS_2.0_Frontend/src/`

| Fix | File |
| --- | --- |
| F-7.9 | `presentation/components/intimation/intimation-banner.tsx` |
| F-7.9 | `presentation/components/intimation/index.ts` |
| F-7.5 | `infrastructure/gql-queries/notify-queries/IntimationQuery.ts` (tenant read + dismiss) |
| F-7.6 | `infrastructure/gql-queries/ops-queries/IntimationQuery.ts` (platform list) |
| F-7.6 | `infrastructure/gql-mutations/ops-mutations/IntimationMutation.ts` |
| F-7.6 | `domain/entities/ops-service/IntimationDto.ts` |
| F-7.10 | `presentation/components/page-components/ops/intimations/platform-intimations-list-page.tsx` |
| F-7.10 | `presentation/components/page-components/ops/intimations/intimation-form-dialog.tsx` |
| F-7.10 | `presentation/components/page-components/ops/intimations/intimation-form-schemas.ts` |
| F-7.10 | `presentation/components/page-components/ops/intimations/index.ts` |
| F-7.10 | `app/[lang]/(master)/ops/intimations/page.tsx` |

### 8.4 Frontend — files changed

Barrel re-exports only, plus one real wiring change:

- `domain/entities/ops-service/index.ts`, `infrastructure/gql-mutations/ops-mutations/index.ts`,
  `infrastructure/gql-queries/notify-queries/index.ts`,
  `infrastructure/gql-queries/ops-queries/index.ts`,
  `presentation/components/page-components/ops/index.ts` — barrel exports.
- `presentation/provider/app-shell-provider.tsx` — `<IntimationBanner />` mounted at the shell
  slot (F-7.9).

`PlanStatusBanner`, `useEntitlements`, `middleware.ts`, `PUBLIC_ROUTES`, `authorized()` and
`PlatformGate` were not touched (§② 3–4). `BaseUrlConfig.ts` shows as modified in
`git status` — that is a **pre-existing, user-managed local edit**; it was not made by this build
and is deliberately **not staged**.

### 8.5 Seed SQL

- `PSS_2.0_Backend/.../sql-scripts-dyanmic/seed_intimation_masterdata.sql` (F-7.3) — severity and
  category MasterData.
- `pss-2.0-global/sql-scripts-dyanmic/platform-intimations-menu-capability-seed.sql` (F-7.11) —
  `PLATFORM_INTIMATIONS` menu on `/ops/intimations` (OrderBy 965, under `PLATFORMCONTROLPLANE`),
  capabilities `PLATFORM_INTIMATIONS` / `PLATFORM_INTIMATIONS_MANAGE` (OrderBy 107/108,
  `IsSpecial = true`), `MenuCapabilities` incl. `ISMENURENDER`, `RoleCapabilities` for
  `PLATFORM_ADMIN` + `SUPERADMIN`, and the `sett."Grids"` header row `PLATFORMINTIMATION`.

Both are PostgreSQL, idempotent and re-runnable (`now()`, double-quoted identifiers,
`TRUE`/`FALSE`, `WHERE NOT EXISTS`). Neither contains DDL.

### 8.6 Static verification (§④)

- Backend: inspection only, no build. `DbSet` registration confirmed in **both**
  `INotifyDbContext` and the `NotifyDbContext` partial.
- Frontend: `rm -rf .next/types && npx tsc --noEmit --incremental false` → **exit 0**.

### 8.7 Two migration tasks handed to the user

Entities, configurations and `DbSet` registrations are in place; the migration itself is yours.

**1. `notify.Intimations`**
Columns per `Intimation.cs`; indexes per `IntimationConfiguration.cs`:
- `IX_Intimations_Company_Status` on `(CompanyId, Status)`
- an index on `CompanyId`
- **`UX_Intimations_Company_Type_SourceKey_Active`** — UNIQUE on
  `(CompanyId, IntimationTypeCode, SourceKey)` **with filter `"Status" = 'ACTIVE'`**.
  This partial unique index is the dedup guarantee: it is what makes "one ACTIVE row per tenant
  per condition" a database fact rather than a hope, while still allowing an unlimited history of
  RESOLVED/EXPIRED rows for the same condition. `HasFilter` emits a raw predicate — verify the
  generated migration keeps the quoted `"Status"` intact.

**2. `notify.IntimationDismissals`**
- **`UX_IntimationDismissals_Intimation_User`** — UNIQUE on `(IntimationId, UserId)`, so a repeat
  dismiss is idempotent instead of double-counting.

### 8.8 Deviations from the prompt, with reasons

1. **F-7.10 grid — bespoke `<table>`, not `FlowDataTable`/`AdvancedDataTable`.** The prompt asks
   for the shared grid. The shared grids are menu- and `gridCode`-driven **tenant** machinery
   whose `sett."Fields"`/`"GridFields"` rows the control plane does not populate; every existing
   `(master)/ops` screen is a bespoke table for exactly that reason. Followed the sibling ops
   convention (`platform-comms-list-page.tsx` line-for-line). The reason is also recorded in the
   component's header doc block so the next reader does not "fix" it.
2. **F-7.6 `CreateIntimation` takes flat scalar arguments, not a DTO input object.** The sibling
   ops mutations take a DTO input, but only because they carry a vendor-varying credential bag.
   The other three intimation resolvers take scalars; matching them keeps the family consistent.
3. **Manual (PLATFORM-source) intimations get a GUID `SourceKey`.** The partial unique index would
   otherwise collapse two deliberate announcements to the same tenant into one. A GUID key means
   manual notices are never deduplicated against each other — which is correct, and is stated to
   the operator in the create dialog. Detector-raised rows keep their deterministic `SourceKey` and
   so remain deduplicated.
4. **No edit path for a posted notice.** Deliberate, not an omission: a notice a tenant has already
   seen is not something the platform should be able to rewrite in place. Wrong notice ⇒ expire it
   and post a replacement, so the tenant's history stays honest.
5. **Expiry date is stored as end-of-day UTC.** The form takes a `date`; "expires on the 14th" is
   converted to `…T23:59:59Z` rather than midnight, so a notice does not vanish at the start of the
   day the operator typed.
6. **`PLATFORM_SUPPORT` gets no grant**, not even VIEW. Posting to a tenant carries the platform's
   name; the seed comments how to widen it through the Access Control screen if operations asks.

### 8.9 Things the prompt got wrong or under-specified

1. **§③ F-7.10 "reuse the shared grid"** — not achievable on the control plane; see deviation 1.
2. **MenuUrl** — the prompt does not state the stored convention. It is a **leading-slash path
   mirroring the Next.js route** (`/ops/intimations`), matching `/ops/notifications`,
   `/ops/data-cleanup`, `/ops/tenant-access`. Two menus must never share a MenuUrl — the nav
   builder and the sidebar active-state matcher identify a menu by it.
3. **Apollo Client v4** — `useQuery`/`useMutation` must be imported from `@apollo/client/react`,
   not `@apollo/client` (only `gql` still lives at the root entry). The prompt's snippets use the
   v3 spelling; a first draft of `intimation-banner.tsx` inherited it and was corrected. Anything
   written against this prompt later needs the same care.
4. **Capability `OrderBy` collisions already exist** in the platform run (103/104 are used twice by
   earlier seeds). This build continued at 107/108 rather than renumbering anyone else's rows.
5. **§③ F-7.7 cron `45 3 * * *`** — the prompt does not say which timezone. Registered explicitly
   as `TimeZoneInfo.Utc`; without that, Hangfire follows the server's local zone and the sweep
   silently drifts between environments.

### 8.10 Not done, by design (§⑦)

Usage/quota intimations; Draft/Scheduled/Publish/Cancel workflow; re-notification cadence;
banner-impression analytics; Email/SMS/WhatsApp/Push channels; migration of the 13 existing
bespoke banners.

---

## ⑨ Guide review — Phase 6 verification

**Verdict: ACCEPTED.** One functional defect and one migration-time decision, both listed below.
Nothing found weakens P-22 or INV-10.

### 9.1 Constraints (§②) — verified structurally

`NotificationTarget.cs`, `NotificationAudience.cs`, `NotificationScope.cs`, `Notification.cs`,
`NotificationJob.cs`, the dispatcher, the resolver, the writer, `PlanStatusBanner`, `middleware.ts`
and `PlatformGate` are **all absent from the staged change list** across both nested repos. The
P-22 leak guard is untouched by construction, not by inspection. `AllTenantsAllStaff` was not
introduced. `BaseUrlConfig.ts` shows ` M` and is correctly left unstaged. No commit occurred.

### 9.2 Read and confirmed correct

| Check | Where | Result |
|---|---|---|
| Notify on **first raise only** | `IntimationService.RaiseAsync` | Refresh branch returns `false` before `NotifyAsync`; the bridge is inside the insert path only. |
| No `companyId` on the tenant read | `GetActiveIntimations` / `IntimationQueries` | Derived from claims; platform staff get `[]`, not an error. |
| Partial unique index | `IntimationConfiguration` | `.HasFilter("\"Status\" = 'ACTIVE'")`, quoted identifier intact. |
| CRITICAL non-dismissible | service (server-forced) + `DismissIntimation` (rejects) + banner (renders no control) | All three layers agree. |
| Cross-tenant dismiss | `DismissIntimation` | Matched on `(id AND CompanyId)`, never id alone. |
| Bridge surface | `IntimationService.NotifyAsync` | `INotificationSender.SendAsync` only; target is `TenantAllStaff`/`TenantRoles`, never a user, never platform. |
| Sweep isolation | `IntimationSweepService` | try/catch per tenant × per condition; expiry failure does not cost the condition pass. |
| Cron | `IntimationSweepRegistrationExtension` | Mirrors retention; explicit `TimeZoneInfo.Utc`. |
| Apollo v4 | `intimation-banner.tsx` | `@apollo/client/react`. |
| MasterData codes | `seed_intimation_masterdata.sql` | `DataValue`s match `IntimationSeverities` (UPPERCASE) and `IntimationCategories` (Pascal) exactly. |
| Ops gate | `GetIntimations` | `[CustomAuthorize(menu, view, manage)]` resolves to the `params` overload; `HasAccessAsync(..., List<string>)` is **ANY-of**, so view-only roles read and only MANAGE writes. Correct, not a typo. |

### 9.3 Defect — severity escalation is invisible to a user who dismissed the warning

`SubscriptionExpiringCondition` deliberately escalates `WARNING → CRITICAL` at `daysLeft <= 7` on
**the same row** (same `SourceKey`), so `RaiseAsync` takes the refresh branch. That branch updates
`SeverityId` but **not** `IsDismissible`, and the user's `IntimationDismissal` row survives. The
result: a user who dismissed the day-30 warning gets no banner when it becomes CRITICAL, and no
notification either (notify-on-first-raise-only, correctly). The condition escalated; nobody was
told.

Fix, service-level, no migration: in the refresh branch, when the resolved severity is CRITICAL and
the stored row is not already CRITICAL, set `IsDismissible = false` and soft-delete that
intimation's `IntimationDismissals`. Re-notifying on escalation is a separate call and arguably
warranted; the dismissal clear is the minimum.

### 9.4 Decide before the migration is authored

The dedup index filter is `"Status" = 'ACTIVE'`, but every read/write predicate in the service also
carries `IsDeleted != true`. Should a row ever be soft-deleted while still ACTIVE, `RaiseAsync`
would miss it, attempt an INSERT, hit the unique violation, swallow it as a `LogWarning` and return
`false` — that condition then never raises again for that tenant. **Latent today**: nothing in the
staged code sets `IsDeleted = true` on an intimation (`ExpireIntimation` sets `Status`). But the
index ships in the migration, so widen it now:

```
"Status" = 'ACTIVE' AND "IsDeleted" = false
```

### 9.5 Accepted deviations

All six in §8.8 are sound. The bespoke `<table>` (deviation 1) is the right call — the control plane
does not populate `sett."Fields"`/`"GridFields"`, so `FlowDataTable` has nothing to bind. The GUID
`SourceKey` for manual notices (deviation 2) is the correct escape from an index built for
detectors; its stated consequence — the platform can post two identical manual notices — is
acceptable.

### 9.6 Still owed by the user

Two EF migrations (`Intimation`, `IntimationDismissal`) carrying the partial unique index with the
quoted `"Status"` predicate intact, plus the two seeds. §⑤ A1–A10 remain unexercised.
