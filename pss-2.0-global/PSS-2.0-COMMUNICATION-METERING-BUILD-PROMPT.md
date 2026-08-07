# PSS 2.0 — Communication Metering Build Prompt (Email)

> **Status:** BUILT (written 2026-08-05 · built 2026-08-05) · BE + FE · **1 migration + 1 seed user-owned, both PENDING** — see §⑩
> **Implements:** `PSS-2.0-COMMUNICATION-METERING-AND-BILLING-STRATEGY.md` §⑦ **Must-have items 1–14 only**
> **Depends on:** PROMPT-08 migration `20260729062510_Add_PlatformCommunicationProvider` **applied** · a live `billing.Subscription` per tenant
> **Does not supersede anything.** Nothing already built is deleted. Two existing service files are edited.

---

## ⚠️ Rules for whoever builds this

1. **Do not run `dotnet build`.** The user builds the backend. You prove correctness by reading, not compiling.
2. **Migrations are strictly user-owned.** Never run `dotnet ef migrations add` / `remove` / `database update`. Never hand-author a migration file or a snapshot. You write the **migration spec** (§③) and the **seed SQL**; the user authors, applies and commits.
3. **Frontend typecheck is mandatory and must actually run:** `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` with **no pipe**. Only **exit 0** counts as clean. A run that reports only a pre-existing `TS2688` config error checked *zero files* — that is not a pass.
4. **`PSS_2.0_Backend/` and `PSS_2.0_Frontend/` are gitignored.** The Grep/Glob tools return **zero** `.cs` matches. Use `find -iname` to locate files, or scope `grep -rn --include=*.cs` to **one** project subdirectory — a repo-wide backend grep times out at 120 s. Absolute-path `Read` works fine.
5. **The DB is UTC-only.** Every Postgres date column is `timestamp with time zone`; Npgsql throws on `DateTimeKind.Unspecified`. Use `DateTime.UtcNow`; build boundaries with `DateTimeKind.Utc`; never `DateTime.Today` inside an EF predicate.
6. **HotChocolate strips `Get` from every resolver name** (`GetMyUsage` → `myUsage`) and **appends `Input` to input types** (`UsageDto` → `UsageDtoInput`). `tsc` cannot see GraphQL field names — a wrong name builds clean and fails only at runtime. Read the resolver, then write the query.
7. **Never assume a property, column or GraphQL field name.** Read the source file first. Audit fields are `createdDate` / `modifiedDate`, not `createdAt` / `modifiedAt`.
8. **`ops` and `billing` are platform-global schemas.** Every read needs `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true` guard.
9. **New meter codes are one-way doors.** A missing `billing.PlanQuota` row resolves to `0L` = hard block. Every new meter code ships with a `PlanQuota` row for **every** plan **in the same release** (§③.4). No exceptions.
10. **Fail-closed is the design, not a bug.** Do not add an appsettings fallback anywhere in this build. If a tenant has no configured provider, the send does not happen and the UI says so.

---

## ⓪ What is actually on disk (verified 2026-08-05)

### Already built and working — do not rebuild

| Path | State |
|---|---|
| `Base.Application/Behaviors/QuotaBehavior.cs` | ✅ Complete. MediatR `IPipelineBehavior`, registered at `Base.Application/DependencyInjection.cs:38` as `config.AddOpenBehavior(typeof(QuotaBehavior<,>)); // 5. Plan quota ([MeteredResource])` |
| `Base.Application/Behaviors/PlanGateAttributes.cs:44` | ✅ `MeteredResourceAttribute` |
| `Base.Application/Behaviors/PlanGateAttributes.cs:66` | ✅ `IBulkMeteredRequest` (`UnitCount`) |
| `Base.Infrastructure/Services/Billing/EntitlementService.cs:65-110` | ✅ `GetLimitAsync` — *"Present → the limit (null = unlimited). Absent → 0 (not provisioned / fail-closed)."* ~60 s cache, `Invalidate(companyId)` |
| `Base.Application/Services/Billing/UsageMeterService.cs` | ✅ `GetUsedAsync`, `IncrementFlowAsync` (atomic raw-SQL `UPDATE … SET "CurrentValue" = "CurrentValue" + {0}`, insert-on-miss, retry), `EnsureStockCapacityAsync` (under `pg_advisory_xact_lock`), `GetCurrentPeriodStartAsync` (live `Subscription.CurrentPeriodStart`, calendar-month fallback) |
| `Base.Application/Exceptions/PlanEnforcementExceptions.cs:35` | ✅ `PlanQuotaExceededException(string meterCode, long limit, long used)` |
| `Base.Application/Interfaces/BillingCodes.cs` | ✅ `MeterCodes.Contacts/Donations/Emails/Users`, `FeatureCodes.ChannelEmail/ChannelSms/ChannelWhatsApp` |
| `billing.SubscriptionOverride` + `SetSubscriptionOverrideCommand` | ✅ The "contact us / raise this tenant's limit" path already exists. **Reuse it. Do not build a second one.** |
| `Base.Support/Email/Services/EmailExecutorService.cs` | ✅ Phase 1 — resolves recipients, renders, bulk-inserts `EmailSendQueue`, enqueues Phase 2 |
| `Base.Support/Email/Services/EmailSenderService.cs` | ✅ Phase 2 — resolves the PRIMARY provider, calls `IParallelEmailOrchestrator.ProcessJobAsync`, writes job status + `CalculateNextExecutionAt` for `RECURRING` |
| `Base.Domain/Models/NotifyModels/EmailSendJob.cs:22` | ✅ `public bool IsSystem { get; set; }` — the transactional-mail exemption flag already exists |

### The `[MeteredResource]` census — this is the whole product

```
Business/ContactBusiness/Contacts/Commands/CreateContact.cs:13                  [MeteredResource(MeterCodes.Contacts,  MeterTypes.Stock)]
Business/DonationBusiness/GlobalDonations/Commands/CreateGlobalDonation.cs:10   [MeteredResource(MeterCodes.Donations, MeterTypes.Stock)]
…/CreateGlobalDonationWithChildren.cs:21                                        [MeteredResource(MeterCodes.Donations, MeterTypes.Stock)]
Business/NotifyBusiness/EmailSendJobs/Commands/SendTestEmail.cs:11              [MeteredResource(MeterCodes.Emails,    MeterTypes.Flow)]
```

**Read that again.** Four annotated commands in the entire codebase, and the only email one is **the test-send button**. The 10,000-email allowance we sell is decorative.

### Defects this build must fix

**D1 — ★ The bulk email path never passes through MediatR, so `QuotaBehavior` can never see it.**

`CreateEmailSendJobCommand` *is* a MediatR command, but it does not send email — it enqueues Hangfire:

```
Business/NotifyBusiness/EmailSendJobs/Commands/CreateEmailSendJob.cs:139
    hangfireJobId = _hangfireJobClient.Enqueue<IEmailExecutorService>(
        x => x.ProcessBulkEmailJobAsync(emailSendJobId, CancellationToken.None));
CreateEmailSendJob.cs:147, :158   (schedule / recurring variants)
UpdateEmailSendJob.cs:141, :160, :180
```

`EmailExecutorService` and `EmailSenderService` are **plain injected services invoked by Hangfire**, not MediatR handlers. `QuotaBehavior<TRequest,TResponse>` is an `IPipelineBehavior`.

> ⚠️ **Therefore: putting `[MeteredResource(MeterCodes.Emails, MeterTypes.Flow)]` on `CreateEmailSendJobCommand` would meter nothing.** It would compile, deploy, look correct in review, and count one unit per *job* instead of per *email* — or zero, because a recurring job re-fires with no command at all. **Do not do it.** Metering goes *inside* the two services. This is the single most important instruction in this document.

**D2 — `CreateEmailSendJob.cs` has the feature gate but no meter.**

```csharp
// P-12 (T-A18) §3.3 — user-triggered outbound email. System/transactional mail (tenant activation,
// password reset, support query) is NOT gated: it must deliver regardless of plan state.
[RequiresFeature(FeatureCodes.ChannelEmail)]
[CustomAuthorize(DecoratorNotifyModules.EmailSendJob, Permissions.Create)]
public record CreateEmailSendJobCommand(EmailSendJobRequestDto emailSendJob) : ICommand<CreateEmailSendJobResult>;
```

Keep that comment and that policy — **system mail is never metered and never blocked** (§⑥ INV-4).

**D3 — There is no way to tell a platform-sent email from a BYO-sent one.** `Base.Domain/Models/NotifyModels/CompanyEmailProvider.cs` has `ProviderConfiguration`, `CostPerEmail`, `SendingDomainName`, `DomainStatus`, `IsDefault`, `HourlyEmailLimit` / `DailyEmailLimit` / `MonthlyEmailLimit` / `RatePerSecond` — **and no ownership discriminator.** Without one, `EMAILS_PLATFORM` (the COGS meter) cannot be computed. → new column, §③.1.

**D4 — The provider rate caps are dead columns.** `HourlyEmailLimit`, `DailyEmailLimit`, `MonthlyEmailLimit`, `RatePerSecond` exist and are read by nothing. **Out of scope here** (§⑦) — they are throttle layer L2; this build is layer L1 only. Do not conflate them.

**D5 — The fallback provider is fetched and discarded.** `EmailExecutorService.cs:176-185` assigns `companyFallbackEmailProvider` and then re-tests `companyEmailProvider`. Real bug, **out of scope**, listed so nobody "fixes" it mid-build and blows the diff. Log it, move on.

**D6 — The job-COMPLETED status update is commented out** at `EmailExecutorService.cs:335-340`. Out of scope. Noted because §④.3 writes near it.

---

## ① The one idea

**Count every email the platform processes, against the tenant's plan, on the tenant's billing anniversary — and stop the send *before* it starts when it will not fit.**

Two meters, and they are not the same thing:

| Meter | Counts | Why it exists |
|---|---|---|
| `EMAILS` | Every email the platform processes — **BYO provider or ours** | The **value** meter. This is what we sell. A tenant using their own SendGrid still uses our templates, segments, scheduler, tracking and analytics. They pay for that. |
| `EMAILS_PLATFORM` | Only the subset **delivered on our infrastructure** | The **COGS** meter. This is what we actually pay for. Platform-side visibility; not a tenant-facing block in v1. |

Every email increments `EMAILS`. Platform-sent emails increment **both**.

---

## ② Design

### ②.1 Where the two hooks go

```
CreateEmailSendJobCommand  ──MediatR──▶  [RequiresFeature(ChannelEmail)]   ← already there
        │                                (no [MeteredResource] — see D1)
        │ Hangfire.Enqueue
        ▼
EmailExecutorService.ProcessBulkEmailJobAsync
        │  … resolves recipients …
        │  bulkData.TotalRecipients now known   ← ★ HOOK A: PRE-FLIGHT (block here)
        │  renders + bulk-inserts EmailSendQueue
        │ Hangfire.Enqueue
        ▼
EmailSenderService.SendQueuedEmailAsync
        │  result = _parallelOrchestrator.ProcessJobAsync(...)
        │  result.TotalSuccess known            ← ★ HOOK B: INCREMENT (count here)
        ▼
     done
```

**Hook A blocks. Hook B counts.** Never the other way round.

- **Block at A**, because that is the last moment before we do expensive work and the first moment we know the true recipient count. `EmailExecutorService.cs:224` currently reads `if (bulkData.TotalRecipients == 0) throw new Exception("Job executed with 0 valid recipients.");` — the quota check goes immediately beside it.
- **Count at B**, because a queued email is not a sent email. Counting at A would bill a tenant for a provider outage.

### ②.2 All-or-nothing, deliberately

A job that does not fit is **rejected whole**. We do not send the first 400 of 500 and drop 100 — a half-sent newsletter is worse than an unsent one, and a partial send is not re-runnable without duplicating.

The tenant sees the wall **before** they press Send (§⑤.2), not after.

### ②.3 The period is the billing anniversary, not the calendar month

`UsageMeterService.GetCurrentPeriodStartAsync` reads the live `Subscription.CurrentPeriodStart`. **Never write "this month" in any string, label, tooltip or email in this build.** Write *"resets on {CurrentPeriodEnd:d MMM yyyy}"*.

### ②.4 A plan change resets the counter — this is correct

`AssignSubscription.cs:140-230` cancels the incumbent and inserts a successor with `CurrentPeriodStart = now`; `UsageCounter` is keyed on `(CompanyId, MeterCode, PeriodStart)`. So a blocked tenant who upgrades is unblocked **instantly, with zero new code**. Upgrade is the default remedy and the only self-serve one. **Do not "fix" this reset.**

### ②.5 Recurring jobs meter on every run

`EmailSenderService.CalculateNextExecutionAt` re-fires `RECURRING` jobs via Cronos. Each run passes Hook A and Hook B again. That is intended: a weekly newsletter to 5,000 people costs 5,000 units a week, not 5,000 once. **A recurring job that fails its pre-flight is paused, not cancelled** — §④.3.

---

## ③ Data

### ③.1 Migration — `Add_EmailProviderOwnership` (user-owned)

Write this into a sibling file `PSS-2.0-COMMUNICATION-METERING-MIGRATION-SPEC.md`. Do not create the migration.

**1. `notify.CompanyEmailProviders` — add one column**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `IsPlatformProvider` | `boolean` | NOT NULL | `false` | `true` = this row sends on our infrastructure (the platform sender), `false` = tenant's own account (BYO) |

Add the matching property to `CompanyEmailProvider.cs` **immediately after `IsDefault`**, and the `HasDefaultValue(false)` line to its EF configuration.

**2. Backfill**

Existing rows are all BYO by definition (the platform sender did not exist before PROMPT-08). `false` is correct for every existing row; the NOT NULL default handles it. **No data backfill script needed.**

**3. What is *not* in this migration**

- No new tables. `billing.PlanQuota` and `billing.UsageCounter` already exist and are sufficient.
- No add-on-pack tables (`AddOnPackCatalog` / `AddOnPackPrices` / `CompanyAddOnPacks`) — packs are §⑦ out of scope.
- No index changes. `UsageCounter` already has `UNIQUE (CompanyId, MeterCode, PeriodStart)`.
- No column on `EmailSendJob` — `IsSystem` already exists.

**4. Ordering and safety**

Additive, defaulted, non-breaking. Safe to apply before deploying the code. Must be applied **after** `20260729062510_Add_PlatformCommunicationProvider`.

### ③.2 New meter codes — `BillingCodes.cs`

```csharp
public const string EmailsPlatform      = "EMAILS_PLATFORM";
public const string SmsSegments         = "SMS_SEGMENTS";
public const string WhatsAppConversations = "WHATSAPP_CONVERSATIONS";
```

`SMS_SEGMENTS` and `WHATSAPP_CONVERSATIONS` are **declared and seeded now, enforced later** (D2 of the strategy doc is unanswered). Declaring them now costs nothing; adding them later means a second seed release against live tenants. They ship at `0` on every plan — SMS and WhatsApp stay BYO-only.

> An SMS "segment" is 160 GSM-7 characters (70 UCS-2). A WhatsApp "conversation" is a Meta 24-hour window. Neither is one message. Never meter SMS or WhatsApp per-message — SMS cost varies ~30× by destination country.

### ③.3 Do not touch `PlanEntitlement`

`billing.PlanEntitlement` (boolean feature on/off) and `billing.PlanQuota` (numeric limit) are **separate tables**. This build writes only `PlanQuota`. `FeatureCodes.ChannelEmail` already exists and is already gating.

### ③.4 Seed — `billing-communication-quota-seed.sql` (user-owned)

Into repo-root `sql-scripts-dyanmic/`. Idempotent (`ON CONFLICT (PlanId, MeterCode) DO NOTHING`). **Every plan × every meter — a missing row is a hard block, not a default.**

| Meter | FREE | PLAN_50K | PLAN_100K | CUSTOM |
|---|---|---|---|---|
| `EMAILS` | 1,000 | 50,000 | 100,000 | `NULL` (unlimited) |
| `EMAILS_PLATFORM` | 1,000 | 50,000 | 100,000 | `NULL` (unlimited) |
| `SMS_SEGMENTS` | 0 | 0 | 0 | 0 |
| `WHATSAPP_CONVERSATIONS` | 0 | 0 | 0 | 0 |

`MeterType = 'FLOW'` on all four. `Period = 'BILLING_PERIOD'`.

> ⚠️ **These numbers are an assumption, not a decision.** They are strategy-doc **D1**, still open — see §⑨. Size them for a **peak** month (Diwali, Christmas, a disaster appeal), not an average one: packs are out of scope, so a tenant who runs out has exactly one route — upgrade, and pay more *every* month thereafter. If the user ratifies different numbers, only this table changes; no code changes.

`NULL` = unlimited is **supported and load-bearing**: `QuotaBehavior` returns early on null and skips the count entirely.

---

## ④ Build steps

### ④.1 `BillingCodes.cs` — add the three meter codes (§③.2)

Add to `MeterCodes` only. Do not touch `FeatureCodes`, `PlanCodes` or `SubscriptionStatuses`.

### ④.2 `CompanyEmailProvider.cs` + EF config — add `IsPlatformProvider` (§③.1)

Entity property + `HasDefaultValue(false)`. **Then stop.** Do not run `dotnet ef`.

### ④.3 ★ Hook A — pre-flight, `EmailExecutorService.ProcessBulkEmailJobAsync`

Inject `IEntitlementService` and `IUsageMeterService`. At **`EmailExecutorService.cs:224`**, beside the existing zero-recipient guard:

```csharp
if (bulkData.TotalRecipients == 0)
    throw new Exception("Job executed with 0 valid recipients.");

// P-25 §④.3 — L1 plan-quota pre-flight. The bulk path is Hangfire, not MediatR,
// so QuotaBehavior cannot reach it. This IS the gate for bulk email.
if (!emailSendJob.IsSystem)
{
    var limit = await _entitlements.GetLimitAsync(companyId, MeterCodes.Emails, cancellationToken);
    if (limit is not null)                              // null = unlimited
    {
        var used = await _usageMeters.GetUsedAsync(companyId, MeterCodes.Emails, MeterTypes.Flow, cancellationToken);
        if (used + bulkData.TotalRecipients > limit.Value)
            throw new PlanQuotaExceededException(MeterCodes.Emails, limit.Value, used);
    }
}
```

Rules for this block:

- **`IsSystem` short-circuits everything.** Tenant activation, password reset and support-query mail deliver regardless of plan state. This preserves the existing `CreateEmailSendJob.cs` policy comment verbatim.
- **`limit is null` → unlimited → skip the count entirely.** Do not `?? 0`. Do not `.Value` before the null check. `QuotaBehavior.cs` does exactly this; match it.
- **`limit == 0` still throws** via the same arithmetic (`used + n > 0`). No special case needed — but note that 0 means *not provisioned*, which is why §③.4 seeds every plan.
- On `PlanQuotaExceededException`, the surrounding job-failure handler must set the job status to **FAILED** with `ErrorMessage = "Plan email limit reached ({used}/{limit}). Upgrade your plan to send this campaign."` — and **for `RECURRING` jobs, PAUSE rather than cancel** the Hangfire recurring job, so an upgrade resumes the schedule instead of silently ending it.
- **Do not increment here.** Queued ≠ sent.

### ④.4 ★ Hook B — increment, `EmailSenderService.SendQueuedEmailAsync`

Inject `IUsageMeterService`. After `result` returns from `_parallelOrchestrator.ProcessJobAsync(...)` and before the job-status write:

```csharp
// P-25 §④.4 — count what was actually delivered, never what was queued.
if (!emailSendJob.IsSystem && result.TotalSuccess > 0)
{
    await _usageMeters.IncrementFlowAsync(companyId, MeterCodes.Emails, result.TotalSuccess, cancellationToken);

    if (primaryProvider.IsPlatformProvider)
        await _usageMeters.IncrementFlowAsync(companyId, MeterCodes.EmailsPlatform, result.TotalSuccess, cancellationToken);
}
```

- **`result.TotalSuccess`, never `result.TotalProcessed` and never `TotalEmailsQueued`.** A failed send is not a billable send.
- `IncrementFlowAsync` is atomic raw SQL with insert-on-miss and retry — safe under the parallel workers. Do not wrap it in your own transaction.
- **Swallow exceptions from the increment.** `UsageMeterService` already documents *"a metering write must never break the operation it is metering."* Log and continue; never fail a delivered send because a counter write lost a race.
- `IsPlatformProvider` comes from the `CompanyEmailProviderResponseDto` — add the field to that DTO and its mapping (§④.5).
- Batched jobs call `SendQueuedEmailAsync` once **per batch**; each call increments only its own batch's successes. That is correct — do not try to dedupe across batches.

### ④.5 DTO plumbing

Add `IsPlatformProvider` to `CompanyEmailProviderResponseDto` and to every mapping/projection that builds it (`GetCompanyEmailProvidersAsync` in the provider-config repository). Read the file before editing; do not assume the projection is AutoMapper.

### ④.6 Annotate the remaining single-send email commands

`SendTestEmail.cs:11` already carries `[MeteredResource(MeterCodes.Emails, MeterTypes.Flow)]`. Leave it. Do **not** add the attribute to `CreateEmailSendJob` / `UpdateEmailSendJob` (D1). `SendSupportQueryEmail` is system mail — leave unmetered.

### ④.7 Threshold warnings — 80 % and 95 %

A small service invoked **from Hook B, after the increment, outside any transaction, in a try/catch that swallows everything.**

- Fires once per **`(CompanyId, MeterCode, PeriodStart, Threshold)`** — the period start is part of the key, so a new billing period re-arms both thresholds automatically.
- Recipients resolve from `NOTIFY_ADMIN_ROLE_CODES` (the PROMPT-22 setting). **If unset it fails quiet** — that is the existing behaviour; log a warning, do not throw.
- Skip entirely when the limit is `null` (unlimited).
- Delivered through the PROMPT-22 in-app notification service. **The warning email, if any, must be `IsSystem = true`** — otherwise the "you are nearly out of email" message consumes email quota. Think about that one for a second.
- Copy: *"You've used 41,200 of 50,000 emails (82%). Your allowance resets on 14 Sep 2026."* Never "this month".

### ④.8 GraphQL — tenant usage query

Extend the existing entitlements/usage resolver rather than adding a new root field, if one exists; otherwise add `GetMyCommunicationUsage`.

Returns, per meter (`EMAILS` at minimum): `meterCode`, `limitValue` (null = unlimited), `usedValue`, `periodStart`, `periodEnd`, `hasLiveSubscription`.

> **HotChocolate:** `GetMyCommunicationUsage` is exposed as **`myCommunicationUsage`**. Verify against the generated schema before writing the FE query — `tsc` will not catch a wrong name.

### ④.9 GraphQL — campaign pre-flight

`GetEmailCampaignPreflight(recipientCount: Int!)` → **`emailCampaignPreflight`**. Returns `{ willFit, limitValue, usedValue, remaining, periodEnd, hasLiveSubscription }`.

Uses the same `GetLimitAsync` + `GetUsedAsync` pair as Hook A so the answer cannot disagree with the enforcement. **It is advisory only** — Hook A remains the gate. A tenant who sits on the screen for an hour can still fail at A; that is fine and expected.

---

## ⑤ UI notes

### ⑤.1 Usage panel

Where the plan/usage panel already lives. One row per meter: label, `used / limit`, a progress bar, and the reset date.

- `limitValue == null` → render **"Unlimited"**, no bar, no percentage.
- `hasLiveSubscription == false` → **"No active subscription"** + a link to billing. **Never** render that as "0 of 0 used" — a tenant whose card expired must not be told they sent too many emails (§⑥ INV-6).
- ≥ 80 % amber, ≥ 95 % / at limit red.
- Icon container and status chip: solid `bg-amber-600` / `bg-red-600` with `text-white`. **Never** `bg-red-50`, `bg-red-100`, `text-red-700`, `bg-muted` or `text-muted-foreground`.
- Numbers right-aligned (data context). Reset date flows normally next to its label (info context).
- Shaped `Skeleton` while loading; explicit empty and error states.

### ⑤.2 Campaign pre-flight on the send screen

Once the recipient count is known and **before** Send is pressed, call `emailCampaignPreflight`.

- `willFit: true` → a quiet line: *"Will use 4,200 of your remaining 8,800 emails."*
- `willFit: false` → **disable Send** and show: *"This campaign needs 12,000 emails but only 8,800 remain in your allowance (resets 14 Sep 2026). Upgrade your plan to send it."* with an upgrade link. All-or-nothing (§②.2) — do not offer to send a partial campaign.
- Never show a "buy a pack" button. Packs do not exist in this build (§⑦). Not greyed out, not "contact us to unlock" — **absent**.

### ⑤.3 Error surfacing

`PlanQuotaExceededException` from Hook A lands on the job row, not in an HTTP response — the user has already navigated away. It must surface in the campaign list / job detail as a clear FAILED reason, and through the in-app notification service.

### ⑤.4 Everywhere, one wording rule

**Never "this month".** Always *"resets on {date}"*. The period is the billing anniversary and for most tenants it is not the 1st.

---

## ⑥ Invariants

| # | Invariant |
|---|---|
| INV-1 | Metering for bulk email lives **inside** `EmailExecutorService` / `EmailSenderService`. `[MeteredResource]` on a job-creation command is forbidden (D1). |
| INV-2 | **Block on intent (Hook A), count on delivery (Hook B).** Never count queued email. |
| INV-3 | A metering write never breaks the operation it meters. Increment failures are logged and swallowed. |
| INV-4 | `IsSystem == true` is never metered and never blocked. Activation, password reset and support mail always deliver. |
| INV-5 | `limitValue == null` means unlimited: skip the count entirely, never coerce to 0. |
| INV-6 | "No live subscription" and "limit reached" are different states with different copy. Never collapse them. |
| INV-7 | Every meter code has a `PlanQuota` row on **every** plan, shipped in the **same** release. |
| INV-8 | Every email increments `EMAILS`. Platform-sent email increments `EMAILS_PLATFORM` **as well**, never instead. |
| INV-9 | Warning emails are `IsSystem = true` and are sent outside the metered path. |
| INV-10 | No appsettings fallback. Fail closed, with a message telling the tenant to configure a provider. |
| INV-11 | The plan-change counter reset is intended behaviour and must not be "fixed". |

---

## ⑦ Out of scope

Do not build, do not stub, do not leave a TODO for:

- **Add-on email packs** — strategy §⑦ S1–S5. No `ADDON:EMAIL_PACKS` feature code, no `AddOnPackCatalog` / `AddOnPackPrices` / `CompanyAddOnPacks` tables, no Buy-pack button anywhere.
- **SMS / WhatsApp enforcement.** Codes are declared and seeded at `0`; nothing reads them. Blocked on strategy D2.
- **Provider rate caps (throttle layer L2)** — `HourlyEmailLimit` / `DailyEmailLimit` / `MonthlyEmailLimit` / `RatePerSecond` stay dead columns (D4).
- **Spend/abuse suspension (layer L3)**, bounce/complaint auto-suspend, warm-up ramps, transactional/marketing stream separation.
- **Metered overage, wallets, usage-based invoicing.** Nothing is ever auto-charged.
- **A cross-tenant `/ops/usage` platform table.** Explicitly not chosen.
- **The fallback-provider bug** (D5) and **the commented-out COMPLETED status** (D6).
- A second override mechanism. `SetSubscriptionOverrideCommand` already exists; raising one tenant's limit is a row in `billing.SubscriptionOverride`.

---

## ⑧ Acceptance

| # | Check |
|---|---|
| 1 | `grep -rn "MeteredResource" Base.Application/Business/NotifyBusiness/` returns **only** `SendTestEmail.cs:11`. |
| 2 | `EmailExecutorService.ProcessBulkEmailJobAsync` throws `PlanQuotaExceededException` when `used + TotalRecipients > limit`, and the job row reads FAILED with the upgrade message. |
| 3 | A tenant on `CUSTOM` (`LimitValue NULL`) sends a 200,000-recipient campaign with no block and no `GetUsedAsync` call. |
| 4 | After a successful 500-recipient send, `billing.UsageCounter` for `(CompanyId, 'EMAILS', PeriodStart)` rose by exactly the delivered count — **not** 500 if some failed. |
| 5 | The same send on a platform provider also raised `EMAILS_PLATFORM` by the same amount. On a BYO provider, `EMAILS_PLATFORM` is unchanged and `EMAILS` still rose. |
| 6 | A job with `IsSystem = true` on a tenant at 100 % of quota still delivers, and increments nothing. |
| 7 | A recurring job that fails pre-flight is **paused**, not cancelled; after an upgrade it resumes on schedule. |
| 8 | The 80 % warning fires exactly once per period per meter; forcing a second increment past 80 % does not re-fire it; a new `PeriodStart` re-arms it. |
| 9 | The warning notification itself does not increment `EMAILS`. |
| 10 | Every plan in `billing.Plans` has a `PlanQuota` row for all four meter codes. A `LEFT JOIN` looking for nulls returns zero rows. |
| 11 | A tenant with no live subscription sees "No active subscription", not "0 of 0". |
| 12 | No string anywhere in the diff contains "this month" in a quota context. |
| 13 | The send screen disables Send when `willFit: false` and shows the remaining count and reset date. |
| 14 | No Buy-pack UI exists anywhere in the diff. |
| 15 | `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` → **exit 0**, no pipe. |
| 16 | Every new GraphQL field name was verified against the generated schema, not guessed (rule 6). |
| 17 | Icon containers and status chips are solid `bg-X-600` + `text-white`; no `bg-X-50/100`, no `text-X-700/800`, no `bg-muted`. |
| 18 | No migration file, snapshot or `dotnet ef` invocation appears in the diff. |

---

## ⑨ Open questions

| # | Question | Status |
|---|---|---|
| **Q1** | **The per-plan numbers (strategy D1).** §③.4 assumes FREE 1,000 / PLAN_50K 50,000 / PLAN_100K 100,000 / CUSTOM unlimited, same for `EMAILS_PLATFORM`. ⚠️ **Assumed, not ratified.** Size for a peak month — packs are out of scope, so running out means upgrading permanently. | **Blocks the seed only.** All code is written against `PlanQuota`, so changing these numbers changes one SQL file and nothing else. Build may start. |
| **Q2** | Are `SMS_SEGMENTS` / `WHATSAPP_CONVERSATIONS` really 0 on every plan at launch (BYO-only), or does one plan bundle a wallet? (strategy D2) | Assumed **0 / BYO-only**. Blocks nothing here. |
| **Q3** | Does the tenant welcome/activation email under fail-closed reach `IsSystem = true` on every path? (companion plan Q12) | ⚠️ **Hard blocker for fail-closed generally**, not for this build — INV-4 handles it whichever way it lands. |
| **Q4** | Tenants currently sending through the old global appsettings key — cut over before or after this ships? (companion plan Q13) | If after, they will meter as BYO (`IsPlatformProvider = false`) and `EMAILS_PLATFORM` will under-report until cutover. Acceptable; flag it. |
| **Q5** | Which existing resolver owns tenant entitlement/usage reads — extend it, or add `GetMyCommunicationUsage` as a new root field? | Builder decides after reading the resolver. Prefer extending. |

---

## ⑩ Build log

**Session 1 — 2026-08-05 — §④ + §⑤.1–⑤.4 built. FE typecheck `npx tsc --noEmit --incremental false` → exit 0 (no pipe). No `dotnet build`, no `dotnet ef`, no migration file or snapshot in the diff.**

### User-owned artefacts — BOTH PENDING, nothing below works until they are applied

| Artefact | What | Where |
|---|---|---|
| Migration `Add_EmailProviderOwnership` | ONE column: `notify."CompanyEmailProviders"."IsPlatformProvider" boolean NOT NULL DEFAULT false`. The EF model/config change is written; the migration is yours to author, apply and commit. | Spec: `PSS-2.0-COMMUNICATION-METERING-MIGRATION-SPEC.md` |
| Seed — 16 `billing.PlanQuota` rows | 4 meter codes × 4 plans. **INV-7/rule 9: without this every new meter code resolves to `0L` = hard block on every tenant.** Apply in the same release as the code. | `sql-scripts-dyanmic/billing-communication-quota-seed.sql` |

The second seed the header originally promised turned out to be unnecessary. The warning service goes through `INotificationSender.SendAsync`, whose direct-send path composes title/body/icon/action inline and carries `TriggerCode` through to the staged row as a free-form audit string — it looks nothing up. `billing.quota.threshold` and `billing.quota.campaignblocked` therefore need no trigger or template row. **One seed, not two.**

### Decisions and deviations from the prompt as written

| # | Prompt said | Built | Why |
|---|---|---|---|
| D-1 | `PlanQuota.Period = 'BILLING_PERIOD'` | `Period = 'MONTH'` | The existing catalogue rows and the resolver both use `'MONTH'`; a new value would have been read by nothing. The period *boundary* is still the billing anniversary — it is computed from the subscription, never from the string. |
| D-2 | Re-seed `EMAILS` to 1,000 / 50,000 / 100,000 / unlimited (Q1) | Pre-existing catalogue numbers left untouched; the re-alignment `UPDATE` block sits **commented out** at the foot of the seed | Q1 is explicitly unratified. Silently rewriting live plan limits is not a build decision. Uncomment when the numbers are signed off. |
| D-3 | — | New `MeterCodes.Communication` array | The usage panel and the ops usage grid both need "which meters are communication meters"; two hand-kept lists would drift. |
| D-4 | — | Response DTOs live with the query, not in a shared DTO folder | Matches the surrounding billing handlers. |
| D-5 | — | Fixed `GetMyEntitlements`' period-start computation | It disagreed with the meter service about where the period began, so the panel and the gate could report different `used` values for the same tenant. |
| D-6 | Q5: "prefer extending `myEntitlements`" | **Two new root fields** — `myCommunicationUsage`, `emailCampaignPreflight` | `myEntitlements` is read by the app shell on every page load and its `MeterStateDto` has no room for the period boundary. Rationale is written into `GetMyCommunicationUsage.cs` next to the code. |
| D-7 | — | Warning/block dedup uses **synthetic `billing.UsageCounters` rows** as markers (`EMAILS#W{threshold}`, `EMAILS#B{jobId}`) | The UNIQUE `(CompanyId, MeterCode, PeriodStart)` index makes "once per period" durable and race-free with no new table. `MeterCode` is `HasMaxLength(30)` — the marker strings fit. |
| D-8 | — | PAUSED-status lookup uses `TryGetValue` + `failedStatusId` fallback | `GetMultipleMasterDataIdsByCodesAsync` can return a partial dictionary; an unconfigured PAUSED code must not turn a quota block into a `KeyNotFoundException`. |
| D-9 | — | Hook A's log row is `EmailLogType.JobBlockedByQuota`, a **new value in the existing 50-char `LogType` column** | The §⑤.3 read needed a non-fragile discriminator, and pattern-matching English log text is not one. Existing column, existing `(EmailSendJobId, LogType)` index → **no migration** (acceptance #18). |
| D-10 | §⑤.3 "surface the reason" | Built on the **job-detail screen only** (`CampaignBlockedNotice`), not on the campaign list | The list has no room for used/limit/remaining/reset-date, and a red chip that opens the job is the existing pattern. |
| D-11 | — | Pre-flight **fails open on the client** | Advisory only (§④.9); the executor re-checks at send time. A failed advisory query must not block a send the server would have allowed. |
| D-12 | — | Two pre-existing "this month" strings rewritten to the reset date | Acceptance #12. The allowance resets on the billing anniversary; "this month" was wrong copy, not just imprecise. |
| D-13 | — | Communication meters split out of the generic usage grid into their own panel | They carry a period boundary and a reset date the generic `MeterStateDto` grid cannot render. |

### Verified acceptance

- #12 — grep for `this month`: only the prohibition comments remain; no user-facing copy.
- #14 — no Buy-pack UI: absent, not disabled, not "contact us".
- #15 — `npx tsc --noEmit --incremental false` → **EXIT=0**, no pipe, files actually checked (no TS2688-only run).
- #17 — grep for `bg-{warning,destructive,primary,success}-{50,100}` and `text-…-{700,800}` across every new/changed comms component: **no matches**. Icon containers and chips are solid `bg-X-600 text-white`.
- #18 — no migration file, no snapshot, no `dotnet ef` invocation in the diff.
- Out-of-scope list honoured: no add-on packs, no SMS/WhatsApp enforcement (codes seeded at 0, nothing reads them), no rate caps, no suspension, no overage/wallets, no cross-tenant `/ops/usage`, D5/D6 untouched, no second override mechanism, no `[MeteredResource]` on job creation, `SendTestEmail.cs:11` and `SendSupportQueryEmail` left as-is.

### Still open after this session

- **Q1** — the per-plan `EMAILS` / `EMAILS_PLATFORM` numbers remain unratified (see D-2). Nothing but the seed depends on them.
- **Q4** — until the platform-provider row is flipped (`IsPlatformProvider = true`), tenants still on the old global appsettings key meter as BYO and **`EMAILS_PLATFORM` under-reports**. Known and accepted; flagged here so the first COGS report is not read as truth.
