# PSS 2.0 — Communication Providers Configuration (Platform + Tenant) — Review & Plan

**Type:** Analysis + plan document. **Nothing is built by this file.**
**Date:** 2026-08-04
**Covers:** (a) review of the three tenant channel configuration screens, (b) the missing platform-side UI, (c) the plan-quota-vs-tenant-provider question.
**Migrations:** any schema change named here is **user-owned** — specified, never authored or run by the agent.

---

## ⓪ Verified on disk

Every claim below was read from source this session. Backend paths are relative to
`PSS_2.0_Backend/PeopleServe/Services/Base/`.

| Thing | Path | State |
|---|---|---|
| Platform provider entity | `Base.Domain/Models/OpsModels/PlatformCommunicationProvider.cs` | **exists** |
| Platform migration | `Base.Infrastructure/Migrations/20260729062510_Add_PlatformCommunicationProvider` | exists, **UNAPPLIED** |
| Platform resolver + service | `PlatformCommunicationProviderResolver`, `PlatformCommunicationService` | **exist** |
| Platform CQRS / GraphQL / **any FE file** | — | **none** (`grep PlatformCommunicationProvider PSS_2.0_Frontend/src` → 0 hits) |
| Tenant email provider entity | `Base.Domain/Models/NotifyModels/CompanyEmailProvider.cs` | exists, full CQRS |
| Tenant SMS entity | `Base.Domain/Models/NotifyModels/SmsSetting.cs` | exists, 14 command/query folders |
| Tenant WhatsApp entity | `Base.Domain/Models/NotifyModels/WhatsAppSetting.cs` | exists, full campaign/conversation surface |
| Tenant FE screens | `src/app/[lang]/(core)/setting/communicationconfig/{emailproviderconfig,smssetup,whatsappsetup}` | all three **exist and render** |
| Quota pipeline | `Base.Application/Behaviors/QuotaBehavior.cs`, `PlanGateAttributes.cs` | exists, wired |
| Meter vocabulary | `Base.Application/Interfaces/BillingCodes.cs` | `MeterCodes = CONTACTS, DONATIONS, EMAILS, USERS` |
| Real email send loop | `Base.Support/Email/Workers/ParallelEmailOrchestrator.cs` (370 ln) | **no `IMediator`, no `IUsageMeterService`** |

Existing prompts that already own part of this scope:
- **`PSS-2.0-ONBOARDING-PROMPT-08-PLATFORM-COMMS-PROVIDERS.md`** (T-A14) — **BUILT.** Entity, EF config, resolver, service, migration spec, seed. Migration + seed still user-owned/unapplied.
- **`PSS-2.0-ONBOARDING-PROMPT-09-PLATFORM-COMMS-CRUD.md`** (T-A15, 285 lines) — **WRITTEN, NOT EXECUTED.** Specifies exactly the platform CRUD + `(master)` CONFIG screen the user says is missing. Its own §0.2 sequences it after PROMPT-14 — **PROMPT-14 is now built, so that gate is clear.**

---

## ① Executive answer to the three questions

**Q — "platform side has the table but no UI screen."**
Correct, and it is already specified. **PROMPT-09 is the plan.** Do not write a third document for it; execute PROMPT-09. The only prerequisite that is genuinely outstanding is that PROMPT-08's migration and seed are unapplied — until they are, `GetDefaultAsync("EMAIL")` returns `null` and platform mail silently falls back to the legacy `appsettings` SendGrid key. **Applying P-08's migration + seed is worth more today than any screen.**

**Q — "tenant screens need review."**
All three render. They are **not** three variations of one design — they are three unrelated designs (§③). Email is a multi-row provider list with failover and per-provider caps; SMS is a singleton with one typed column per provider vendor and plaintext secrets; WhatsApp is a singleton for one vendor. That divergence is the review finding, and §⑤ proposes what to do about it.

**Q — "the plan says 50,000 emails; can we actually hold the tenant to it when they bring their own provider?"**
**Yes architecturally, no in practice.** Yes because the tenant's own SendGrid key is only ever used *by our sender* — every send originates inside our job pipeline, so we can count and refuse regardless of whose credentials execute it. The tenant has no way to send "through PSS" without passing our code. No in practice because **today nothing counts**:

```
[MeteredResource(MeterCodes.Emails, MeterTypes.Flow)]
  → EmailSendJobs/Commands/SendTestEmail.cs:11        ← the ONLY one
[RequiresFeature(...)] but NO meter:
  → EmailSendJobs/Commands/CreateEmailSendJob.cs:13
  → SMSCampaigns/SendNowCommand/SendSMSCampaignNow.cs:10
  → WhatsAppCampaigns/SendNowCommand/SendWhatsAppCampaignNow.cs:12
  → WhatsAppConversations/Commands/SendOutboundWhatsAppMessage.cs:13
```

A 50,000-email plan is currently a **boolean** (channel on / channel off), not a number. A tenant can send five million and the counter reads whatever the test button left behind. There are also **no `SMS` or `WHATSAPP` meter codes at all** — `MeterCodes.All = [Contacts, Donations, Users, Emails]`. §④ is the fix.

---

## ② Three throttle layers — never conflate them

This is the single most important thing for the UI to get right. Three different caps already exist in the schema and they answer three different questions.

| Layer | Stored in | Owned by | Question it answers | Breach behaviour |
|---|---|---|---|---|
| **L1 — Plan quota** | `billing.UsageCounter` + `billing.PlanEntitlement` limit | **Platform / commercial** | "Has this tenant bought the right to send this many?" | 402 `PLAN_QUOTA_EXCEEDED`, soft-block (T-A18: warn 80%, block new sends at 100%) |
| **L2 — Provider rate cap** | `CompanyEmailProvider.HourlyEmailLimit` / `DailyEmailLimit` / `MonthlyEmailLimit` / `RatePerSecond` | **Tenant / deliverability** | "How fast may we push this vendor before they throttle or blacklist us?" | queue/defer, spread over time — **not** an error to the user |
| **L3 — Spend budget** | `SmsSetting.MonthlyBudgetCap` + `BudgetAlertThresholdPct` + `AutoPauseWhenBudgetExceeded` | **Tenant / finance** | "How much money is this tenant willing to burn?" | auto-pause promotional traffic (`PausePromotionalOnly`) |

**Rules:**
- **I-1.** L1 is the only layer the platform sets. A tenant must never be able to raise it, and the tenant-side screens must render it **read-only**, sourced from `getMyEntitlements`.
- **I-2.** L2 and L3 are tenant-editable and must never be presented as, or validated against, plan limits. A tenant lowering `DailyEmailLimit` does not change what they have paid for.
- **I-3.** The three must be labelled distinctly on screen — "Plan allowance", "Provider send rate", "Monthly spend cap". Today they would all read as "limit" and the support tickets write themselves.
- **I-4.** L1 has no equivalent on the platform side. `ops.PlatformCommunicationProviders` is the platform's own sender; the platform does not meter itself.

---

## ③ Tenant screen review — current state, per channel

### 3.1 Email — `setting/communicationconfig/emailproviderconfig` (menu `COMPANYEMAILPROVIDER`)

- **Storage:** `notify.CompanyEmailProviders` — **multi-row per company**, `ProviderConfiguration` as JSON deserialized by `EmailProviderFactory`, `Priority` (lower first), `IsDefault`.
- **Depth:** full CQRS — Create / Update / Save / Delete / Toggle / Workflow commands; Get / GetById / GetStats queries; schema + mutations + queries + EF config + seed SQL.
- **ALIGN #28 extras present:** `ApiRegion`, `SendingDomainName` + `DomainStatus` + `DomainVerifiedAt`, `SendingIp`, `TrackingEventsCsv`, `RatePerSecond`, `IpReputationScore` / `DomainReputationScore`, `BounceRate` / `SpamRate`, `CostPerEmail` + `CurrencyId`, `LastEmailSentAt`.
- **Verdict:** **this is the reference design.** Multi-provider, failover-capable, JSON-config, observability fields.
- **Findings:**
  - **E1** — no plan-allowance panel. The tenant sees provider caps (L2) and nothing about L1.
  - **E2** — credentials live inside `ProviderConfiguration` JSON; confirm the read path masks them before returning to the client (P-09 §④ already mandates write-only + masked for the platform twin; the tenant twin needs the same audit).
  - **E3** — stray `Base.Infrastructure/Repositories/Email - Backup/` folder shadowing the live repositories. Dead weight, delete when convenient.

### 3.2 SMS — `setting/communicationconfig/smssetup` (menu `SMSSETUP`)

- **Storage:** `notify.SmsSettings` — **singleton per company**, one `Provider` string, and **one typed column block per vendor**: `TwilioAccountSid` / `TwilioAuthToken` / `TwilioMessagingServiceSid` / `TwilioDefaultFromNumber` / `TwilioStatusCallbackUrl`, `BirdApiKey` / `BirdOriginator` / `BirdChannelId`, `VonageApiKey` / `VonageApiSecret` / `VonageApplicationId` / `VonageDefaultFromNumber`, `Local*` (7 cols), `Custom*` (6 cols).
- **Depth:** rich behaviourally — 14 command/query folders covering connection, sender configuration, sender registration (10DLC-style), opt-in/opt-out keywords, DND registry sync, budget configuration, webhook events, usage analytics, test send, test connection.
- **Verdict:** **behaviourally the richest, structurally the weakest.**
- **Findings:**
  - **S1 — no failover, no priority, no multi-provider.** One provider at a time, by construction. If Twilio is down, SMS is down. Email has failover; SMS cannot.
  - **S2 — secrets in typed plaintext columns.** `TwilioAuthToken`, `BirdApiKey`, `VonageApiSecret`, `LocalApiKey`, `LocalApiSecret`, `CustomAuthValue` are `string?` columns. Adding a sixth vendor means a migration; the email design needs none.
  - **S3 — vendor columns are a schema-per-vendor tax.** 30+ columns exist so five vendors can each use five. `SmsProviderFactory` already deserializes a config shape (`Base.Support/Sms/Providers/Abstractions/SmsSettingSnapshot.cs`), so the JSON path is available.
  - **S4** — `MonthlyBudgetCap` (L3) sits on the same screen where a plan allowance (L1) would go. High conflation risk; see I-3.

### 3.3 WhatsApp — `setting/communicationconfig/whatsappsetup` (menu `WHATSAPPSETUP`, reuses `crm/whatsapp/whatsappconfiguration`)

- **Storage:** `notify.WhatsAppSettings` — **singleton per company**, Meta Cloud only: `AppId` / `AppSecret` / `AccessToken` / `TokenExpiresAt` / `WabaId` / `PhoneNumberId` / `GraphApiVersion`, webhook verify token + events, business profile block, compliance URLs.
- **Depth:** the largest runtime surface of the three — `WhatsAppTemplates`, `WhatsAppCampaigns` (12 handlers incl. Schedule / SendNow / Pause / Resume / Cancel / PreviewAudience / Checklist / Report / Summary), `WhatsAppConversations` incl. `IngestInboundWhatsAppMessage`.
- **Verdict:** correct for a single-vendor channel; Meta Cloud is genuinely the only real option, so singleton is defensible.
- **Findings:**
  - **W1 — `AccessToken` expires (`TokenExpiresAt` exists) but nothing watches it.** No expiry warning, no refresh job. Silent channel death is the failure mode.
  - **W2 — `AppSecret` / `AccessToken` are plaintext typed columns**, same exposure as S2.
  - **W3** — no send cap of any kind (no L2, no L3). Meta bills per conversation; the tenant has no ceiling.
  - **W4** — the settings component lives under `crm/whatsapp/` while its sibling channels live under `setting/communicationconfig/`. Cosmetic, but it breaks the "all channel config in one place" mental model.

### 3.4 Cross-channel summary

| | Email | SMS | WhatsApp |
|---|---|---|---|
| Rows per company | **many** | 1 | 1 |
| Multi-vendor | ✅ | ✅ (one active) | ❌ (Meta only) |
| Failover / priority | ✅ | ❌ | n/a |
| Credential storage | JSON blob | typed plaintext cols | typed plaintext cols |
| Rate cap (L2) | ✅ hourly/daily/monthly + rps | ❌ | ❌ |
| Spend cap (L3) | ❌ | ✅ | ❌ |
| Plan allowance shown (L1) | ❌ | ❌ | ❌ |
| Test send | ✅ (**and it is the only metered command in the system**) | ✅ | via campaign |
| Health / reputation fields | ✅ | ❌ | ❌ |

Three channels, three storage philosophies, and **zero** of them show the tenant what their plan actually allows.

---

## ④ The quota gap — how the 50,000 becomes real

### 4.1 Why the current attribute cannot work for bulk

`QuotaBehavior` runs as a MediatR pipeline behavior. It increments a FLOW meter **after** the handler returns, by `IBulkMeteredRequest.UnitCount` (default 1). That is correct for a single transactional send.

It cannot meter a campaign, because **the campaign send does not run in MediatR at all**. `CreateEmailSendJobCommand` only enqueues Hangfire; the actual per-recipient loop is `Base.Support/Email/Workers/ParallelEmailOrchestrator.ProcessJobAsync` — a background worker with **no `IMediator` and no `IUsageMeterService`** in scope. Putting `[MeteredResource]` on `CreateEmailSendJob` would meter *one unit per job*, i.e. count a 40,000-recipient campaign as 1.

So there are exactly two viable metering points, and they trade off:

| | **A — Reserve at job create** | **B — Count at send** |
|---|---|---|
| Where | `CreateEmailSendJobHandler`, after audience resolution | `ParallelEmailOrchestrator`, per batch |
| Counts | intended recipients | actually-attempted messages |
| Blocks | **before** any money is spent | mid-campaign, partial delivery |
| Accuracy | overcounts suppressed/bounced/opted-out | exact |
| UX on breach | "This campaign needs 40,000; you have 12,000 left" — clean | half the list gets mail, half doesn't — bad |
| Needs | audience count at create time | DI of `IUsageMeterService` into `Base.Support` |

**Recommendation: A as the gate, B as the truth.** Reserve the resolved recipient count at create time and refuse the whole campaign if it will not fit — that is the only breach message a user can act on. Then have the orchestrator reconcile the counter against actual attempts when the job completes (release the unused reservation). This also matches the existing STOCK pattern, where `QuotaBehavior` is the cheap pre-check and `EnsureStockCapacityAsync` under `pg_advisory_xact_lock` is the guarantee.

**I-5.** Never block mid-campaign. A campaign either passes the gate whole or does not start.
**I-6.** Reconcile on job completion; a reservation that is never reconciled leaks allowance.
**I-7.** System/transactional mail (activation, password reset, receipt, support) is **never** metered — this is already the documented rule on `CreateEmailSendJob` and must survive the change.
**I-8.** The metering write must never break the send it is metering — `IncrementFlowAsync` already swallows the unique-race; the reservation path must be equally forgiving in the *release* direction only, never in the *gate* direction.

### 4.2 Missing meter codes

`MeterCodes` has no `SMS` and no `WHATSAPP`. Both channels are feature-gated and completely unmetered. Adding them is a code change plus a **user-owned** plan-catalog seed:

```csharp
public const string Sms      = "SMS";       // FLOW / MONTH
public const string WhatsApp = "WHATSAPP";  // FLOW / MONTH
// MeterCodes.All  → [Contacts, Donations, Users, Emails, Sms, WhatsApp]
// MeterCodes.TypeOf → Emails|Sms|WhatsApp => Flow
```

`billing.Features` is the runtime authority since P-18, but `MeterCodes.All` is still what drives the Limits band of the plan matrix — so this array does need the two new entries, and every plan needs a `PlanEntitlement` row per new meter or the catalog renders them as an implicit OFF.

**I-9.** A meter code added in C# without a matching `billing.PlanEntitlement` row resolves to limit `0` — which `QuotaBehavior` treats as **fail-closed and blocks every send**. The seed is therefore not optional; it must land in the same deployment as the code. **This is the single highest-risk item in this document.**

### 4.3 What the tenant must be able to see

Both the plan gates are invisible today. Minimum viable surface:

- On each channel config screen, a read-only **Plan allowance** panel: `used / limit`, period end, and a warning state at ≥80% (matching T-A18's soft-block policy).
- Distinct from, and visually separated from, the L2/L3 controls on the same page (I-3).
- Sourced from `getMyEntitlements` — the same number the server enforces, per the explicit note in `UsageMeterService`: *"what the tenant is SHOWN and what the server ENFORCES must be the same number."*

### 4.4 The BYO-provider question, settled

The tenant supplying their own SendGrid key does **not** weaken enforcement — the key is data we hold and use; the send still runs in our worker. Two policy options, and they are a **commercial decision, not a technical one**:

1. **Meter regardless of whose credentials.** Simple, uniform, defensible ("the platform charges for the sending infrastructure, not the postage"). **Recommended.**
2. **Make BYO-provider itself a plan feature that lifts or raises the count.** Coherent if the platform's own provider cost is what the allowance is really pricing. Costs a `FeatureCodes.ByoProvider` code, a per-plan entitlement, and a branch in the gate.

Whichever is chosen must be stated on the pricing page, because the tenant will ask exactly the question that prompted this document.

---

## ⑤ Recommendations, in priority order

| # | Action | Owner | Why first |
|---|---|---|---|
| **R1** | **Apply PROMPT-08's migration `20260729062510_Add_PlatformCommunicationProvider` + its seed.** | **user** | Until this lands, platform mail silently uses the legacy appsettings key. Zero code needed. |
| **R2** | **Execute PROMPT-09 as written** (platform CRUD + `(master)` CONFIG screen, set-default, test-send, `PLATFORM_*` capability, masked write-only audited credentials). | build | The user's "no platform UI" gap, already fully specified. Its PROMPT-14 gate is clear. |
| **R3** | **Wire real EMAIL metering** — §4.1 option A gate + B reconcile. | build | Turns the 50,000 from a boolean into a number. Highest commercial value. |
| **R4** | **Add `SMS` + `WHATSAPP` meter codes** and their plan-catalog seed **together** (I-9). | build + **user** seed | Two channels are currently unlimited on every plan including FREE. |
| **R5** | **Add the read-only Plan allowance panel** to all three tenant channel screens, labelled per I-3. | build | The 80%-warn half of T-A18 is unreachable without it. |
| **R6** | **WhatsApp token-expiry warning** (W1) — surface `TokenExpiresAt` on the config screen, warn at T-14d. | build | Cheapest fix for the worst silent failure. |
| **R7** | **Audit credential masking** on tenant email/SMS/WhatsApp read paths (E2, S2, W2) against the standard P-09 already sets for the platform twin. | build | Consistency; PROMPT-09 has the pattern to copy. |
| **R8** | Converge SMS onto the email design — JSON `ProviderConfiguration`, multi-row, priority/failover (S1–S3). | **deferred** | Real improvement, real migration, real data move. Not urgent; note it and move on. |
| **R9** | Delete `Base.Infrastructure/Repositories/Email - Backup/` (E3); consider relocating the WhatsApp config component next to its siblings (W4). | housekeeping | Cosmetic. |

**Explicitly out of scope of this document:** rewriting SMS storage (R8), any cross-tenant `/ops/usage` table (previously declined), and any change to `FeatureEntitlementBehavior`.

---

## ⑥ Open questions — these block build steps

| # | Question | Blocks |
|---|---|---|
| **Q1** | **Meter regardless of BYO-provider, or make BYO a plan feature?** (§4.4) | R3 — changes the gate's shape |
| **Q2** | **What are the SMS and WhatsApp allowances per plan** (FREE / PLAN_50K / PLAN_100K / CUSTOM)? Without numbers the seed cannot be written, and without the seed R4 blocks every send (I-9). | R4 — **hard blocker** |
| **Q3** | Reserve-at-create (recommended) or count-at-send? If reserve, is overcounting suppressed/bounced recipients acceptable, or must the reconcile pass run? | R3 |
| **Q4** | Does a campaign that would straddle the limit get refused whole (I-5, recommended) or truncated to the remaining allowance? | R3 |
| **Q5** | Is the WhatsApp meter per **message** or per **Meta conversation window**? Meta bills per conversation; metering per message will not match the invoice. | R4 |
| **Q6** | Should the platform meter itself at all? (Recommendation: no — I-4.) | R2 scope |
| **Q7** | Is R8 (SMS convergence) wanted at all, or is single-provider SMS an accepted permanent constraint? | R8 only |

---

## ⑦ Invariants (carry into any prompt derived from this)

- **I-1** L1 plan quota is platform-set; tenant-side render is read-only.
- **I-2** L2 provider rate caps and L3 spend budgets are tenant-owned and are never validated against plan limits.
- **I-3** The three layers must be labelled distinctly on screen.
- **I-4** The platform does not meter itself.
- **I-5** A campaign passes the quota gate whole or does not start; never block mid-send.
- **I-6** Reservations must be reconciled on job completion or allowance leaks.
- **I-7** System/transactional mail is never metered.
- **I-8** A metering failure must never break the send.
- **I-9** A new meter code without its `PlanEntitlement` seed resolves to limit 0 and **blocks everything** — code and seed ship together.
- **I-10** `ops` rows carry no `CompanyId`; platform reads need `IgnoreQueryFilters()` + explicit `IsDeleted != true`.
- **I-11** The tenant's own provider credentials change nothing about enforceability — the send always runs in our worker.

---

## ⑨ Shared platform sender ("BYO provider **or** ours") — NOTED, NOT BUILT

**Raised 2026-08-05:** *"some client not have email providers account — that time they want expect to use our accounts with dynamic from name and from email … if client have provider means they can configure or else they can use our configured providers like send grid."*

**Verdict: valid, worth building, and half of it is already happening — by accident rather than by design.**

**DECIDED 2026-08-05 — no implicit fallback, anywhere:** *"no fallback buddy — everything need to work configuration based. each tenant management need to configure provider and else select our provider then only we need to send. then the fall back also they need to configure — otherwise we no need to send. email sending configuration section area we need to show the warning … 'please configure your email communications providers'."*

**The rule: sending is fail-closed. An unconfigured tenant does not send.** The `appsettings` fallback at `EmailTemplateService.cs:131/248/359` is **deleted**, not improved. Both the primary provider *and* any failover provider are explicit tenant choices. Choosing our shared sender is itself a configuration act, never a default that happens when the tenant does nothing.

### ⑨.1 What the code does today — verified on disk 2026-08-05

| Where | Behaviour |
|---|---|
| `Base.Infrastructure/Services/EmailTemplateService.cs:169-237` | Tenant path calls `GetCompanyEmailProvidersAsync(companyId)` and uses the active provider when `DefaultFromEmail` is set. |
| `EmailTemplateService.cs:237` | No active provider → logs *"No active CompanyEmailProvider for CompanyId={CompanyId}; using global email key"*. |
| `EmailTemplateService.cs:248-258` | **Falls through to the GLOBAL `appsettings` SendGrid key and sends anyway.** The send does not fail. |
| `EmailTemplateService.cs:359-370` | Same fallback, duplicated for the composed-email path. |
| `EmailTemplateService.cs:131` | Same fallback again on the platform path. Three copies of one decision. |
| `Base.Infrastructure/Repositories/Email/EmailProviderConfigRepository.cs:14` | Provider lookup is strictly `CompanyId == companyId`. **There is no notion of a shared or platform-owned provider row.** |
| `Base.Domain/Models/NotifyModels/CompanyEmailProvider.cs` | 40 properties. **No flag distinguishing "tenant's own account" from "platform shared sender".** |

**So tenants with no provider are already sending on our SendGrid key.** The capability exists; the controls do not.

### ⑨.2 Why the current accidental behaviour is unsafe

| ID | Gap | Consequence |
|---|---|---|
| **P-1** | The fallback is silent — a log line and nothing else. | No query answers *"which tenants are sending on our key?"* Cost is unattributable. |
| **P-2** | **Unmetered.** `[MeteredResource(MeterCodes.Emails, MeterTypes.Flow)]` appears on exactly one command (`SendTestEmail.cs:11`). See §④. | A tenant on a 1,000-email plan can send 100,000 **on our account**. We pay the bill. This is the commercial hole. |
| **P-3** | From-address is whatever `render.TemplateFrom` contains — no verification, no ownership check. | Tenant A can send as Tenant B. Trivially. |
| **P-4** | No verified-sender or authenticated-domain requirement on the shared key. | Arbitrary from-addresses on one shared key → spam complaints land on **our** sending reputation. **One bad tenant degrades deliverability for every tenant on the key.** This is the operational hole. |
| **P-5** | The fallback reads `appsettings`, not `ops.PlatformCommunicationProviders` — which is built and has an `EMAIL` channel row. | Two sources of truth for one credential. Same root cause as the silent-no-mail platform bug (see PROMPT-08). |
| **P-6** | Nothing in the UI tells a tenant whose account they are on. | The tenant cannot make an informed choice, and cannot be upsold off it. |

### ⑨.3 The resolution rule — explicit, ordered, fail-closed

Replaces every `appsettings` fallback. One resolver, used by all three send paths.

```
resolve(companyId):
  rows = CompanyEmailProviders
           .Where(CompanyId == companyId && IsActive && !IsDeleted)
           .OrderBy(Priority)                    // column already exists
  for row in rows:
      if row.SenderMode == OWN:
          credential = decrypt(row.ProviderConfiguration)
      else:                                       // PLATFORM_SHARED
          credential = IPlatformCommunicationProviderResolver
                         .GetDefaultAsync(EMAIL)  // ops.PlatformCommunicationProviders
          if credential == null:  continue        // platform mis-config → try next row
      if row.SendingIdentity not verified:  continue
      return (row, credential)

  return NOT_CONFIGURED                           // ← do NOT send. No appsettings. No default.
```

Four properties that matter:

1. **`Priority` is the failover chain.** The column already exists on `CompanyEmailProvider` and the screen already exposes it. **A "fallback provider" is just a second row with `Priority = 2`** — it is configured, visible, and tenant-owned, exactly as asked. No new column, no hidden behaviour.
2. **`PLATFORM_SHARED` is a row, not an absence of rows.** The tenant must actively create it. Doing nothing yields `NOT_CONFIGURED`, never our key.
3. **A single resolver, called from all three sites** (`:131`, `:248`, `:359`). Today the fallback decision is written out three separate times, which is why it drifted. Collapse it.
4. **`NOT_CONFIGURED` is a real return value**, not an exception swallowed by the existing `catch` at `:242`. That catch currently converts *any* provider failure into a silent global-key send — it must stop doing that.

### ⑨.4 What happens to an email that cannot be sent

**Park it, never drop it.** Write the row to `EmailSendQueue` with a blocked status and a reason code, and surface a count. Silently discarding a donation receipt is worse than not sending it.

| Reason code | Meaning | Tenant sees |
|---|---|---|
| `NO_PROVIDER_CONFIGURED` | Zero active rows | Banner: *"Email sending is not configured. Please configure your email communication provider."* |
| `SENDER_NOT_VERIFIED` | Row exists, from-address unverified | Banner naming the address and the verification step |
| `PLATFORM_PROVIDER_UNAVAILABLE` | Row is `PLATFORM_SHARED` but `ops` has no active `EMAIL` row | Tenant-facing: *"temporarily unavailable"*. **Platform-facing: alert.** Tenant did nothing wrong |
| `QUOTA_EXCEEDED` | L1 plan allowance spent | Upgrade prompt (§④) |
| `CAP_EXCEEDED` | L2 shared-sender cap hit | Existing L2 language |

Queued rows are retryable: once the tenant configures a provider, a resend action drains the backlog. That turns fail-closed from a data-loss risk into a recoverable delay.

### ⑨.5 ⚠️ The chicken-and-egg — this is the thing that will bite

**A brand-new tenant has zero `CompanyEmailProvider` rows at the moment provisioning tries to send its welcome and activation email.** Under fail-closed, that email does not send — so the first admin never receives credentials and **cannot log in to configure the provider that would have let the email send.** The tenant is bricked at birth.

`ProvisionTenant` Step 9 `SEND_WELCOME` is directly exposed. So are password reset and user activation for any tenant that has not configured yet.

Three ways out:

| Option | How | Verdict |
|---|---|---|
| **A. Provisioning seeds a `PLATFORM_SHARED` row** at a new Step 6b, before Step 9. | New tenants start on our sender explicitly — a real, visible, tenant-owned row they can see and replace. | ✅ **Recommended.** Preserves fail-closed (the row exists, it was configured — by provisioning, on the tenant's behalf) and keeps onboarding working. |
| **B. Platform-origin mail bypasses tenant resolution** and always uses `ops.PlatformCommunicationProviders`. | Welcome/activation/reset are *platform* messages about the account, not *tenant* messages to donors. Arguably they were never tenant mail. | ✅ Also sound, and complements A. **Do both**: A for tenant mail, B for account mail. |
| **C. Accept the breakage** and require the platform to send credentials out-of-band. | — | ❌ Unworkable. |

**Decision needed — see Q12.** Nothing else in §⑨ can be built until this is settled.

### ⑨.6 UI — the warning the user asked for

On the email configuration screen (#28), above every other card, driven by resolver state — not by a client-side guess:

| State | Banner | Tone |
|---|---|---|
| No active row | **"Email sending is not configured."** *No emails will be sent — receipts, campaigns, and notifications are all blocked. Configure a provider or select PeopleServe's shared sender to start sending.* + primary action button | 🔴 destructive, not dismissible |
| Row exists, sender unverified | *"Verify `x@y.org` before sending."* + verify action | 🟠 warning |
| Only one active row | *"No failover provider. If this provider fails, sending stops."* + add-failover action | 🟡 informational, dismissible |
| Configured + verified | Provider name, mode (Own / PeopleServe shared), volume vs cap | ✅ neutral |

Extend the same treatment to **SMS (#157)** and **WhatsApp (#34)** — all three screens carry the identical banner component, since all three channels are equally silent when unconfigured today.

**Also needed:** a global indicator outside the settings screen. An admin who never opens Settings will not see the banner and will not know why receipts stopped. Put a badge on the Communications menu, and block campaign send with the same message rather than failing at send time.

### ⑨.7 Full build shape

1. **`SenderMode`** on `CompanyEmailProvider` — `OWN` | `PLATFORM_SHARED`. One nullable string/enum column. Existing rows backfill to `OWN`.
2. **The §⑨.3 resolver**, replacing all three fallback sites. `IEmailProviderResolver.ResolveAsync(companyId)` returning provider + credential + reason code.
3. **Delete** the `appsettings` SendGrid path and the catch-all at `:242` that silently reroutes to it. **This is the change that enforces the decision — everything else is scaffolding around it.**
4. In `PLATFORM_SHARED`, the tenant supplies **from-name and from-email only**. Credentials resolve from `ops`, are never written to `ProviderConfiguration`, never returned to the client.
5. **From-address verification mandatory before first send** — owned authenticated domain, or an address on our domain with the tenant's as reply-to. Closes P-3, P-4.
6. **Metering mandatory** on the shared path (§④, §⑥ Q1).
7. **Per-tenant cap + bounce/spam cut-off, same release.** Reuse `HourlyEmailLimit`/`DailyEmailLimit`/`MonthlyEmailLimit` (platform-set, tenant-read-only in shared mode) and the unused `BounceRate`/`SpamRate` columns for auto-suspend. **Without this, P-4 is live.**
8. `EmailSendQueue` blocked-status + reason code + resend-backlog action (§⑨.4).
9. The §⑨.6 banners on all three screens, plus the menu badge and the campaign-send pre-check.
10. Provisioning Step 6b per §⑨.5 Option A, and platform-origin routing per Option B.
11. Platform-side view: every tenant, its mode, its volume. Answers P-1.

### ⑨.8 Why it is worth doing

It removes the largest onboarding blocker. A charity that must open and verify a SendGrid account before sending a single receipt will stall during trial. Shared sender turns that into a choice; metering turns the shared send into a plan lever rather than an unpriced cost. Fail-closed turns "why did our receipts stop?" — currently unanswerable — into a banner that names the cause.

### ⑨.9 Sequencing — do not build this first

| Order | Item | Why |
|---|---|---|
| 1 | Answer **Q12** (§⑨.5) | Ship fail-closed without it and every newly provisioned tenant is bricked. Hard blocker. |
| 2 | §④ metering (§⑥ Q1, Q2) | Shared sending without metering is an uncapped bill on our account. P-2 alone is worse than the status quo. |
| 3 | R1 — apply PROMPT-08's migration + seed | `ops.PlatformCommunicationProviders` must hold an active `EMAIL` row, or **every** `PLATFORM_SHARED` tenant resolves to `PLATFORM_PROVIDER_UNAVAILABLE` at once. |
| 4 | Items 7, 8 — cap, bounce cut-off, queue-and-park | Must land in the same release as the feature, never after. |
| 5 | Items 1–5, 9, 10, 11 | The feature proper. |
| 6 | Flip fail-closed on **last** | Steps 1–5 make configuration possible and visible; only then is it fair to stop sending. Land the banners at least one release before the enforcement. |

### ⑨.10 New open questions

- **Q12 — BLOCKING.** The §⑨.5 chicken-and-egg: provisioning seeds a `PLATFORM_SHARED` row (A), platform-origin mail bypasses tenant resolution (B), or both? Recommendation: **both**.
- **Q13 — Migration of existing tenants.** Every tenant sending on the global key today breaks the moment fail-closed lands. Do we (a) auto-create a `PLATFORM_SHARED` row for every tenant with no provider, (b) notify and give a deadline, or (c) both? Recommendation: **(c)** — auto-create so nothing breaks, notify so they choose deliberately. **Needs a one-off backfill script; count the affected tenants before deciding.**
- **Q8** — Is shared sender on every plan, or is it a paid feature? (Charging for BYO is backwards; gating shared sender by plan is defensible. Ties to §⑥ Q1.)
- **Q9** — In shared mode: from-address on **our** domain (best deliverability, weakest branding) or the tenant's verified domain (best branding, needs DKIM/SPF onboarding)? Recommendation: **allow both**, default to ours, sell domain authentication as the upgrade.
- **Q10** — Does fail-closed and shared sending extend to **SMS** and **WhatsApp**? Fail-closed and the banners: **yes, all three**. Shared *sending*: **email only** — SMS costs real money per unit and WhatsApp needs a Meta WABA per business.
- **Q11** — Shared-sender cap exceeded: hard block or queued-and-delayed? (SMS auto-pauses; email has no equivalent.) Note this is `CAP_EXCEEDED`, distinct from `QUOTA_EXCEEDED`.
- **Q14** — Does fail-closed apply to **transactional** mail (password reset, activation) as strictly as to campaigns? Blocking a password reset locks a user out permanently. Recommendation: route all account-level mail through Option B so the question does not arise.

---

## ⑧ Build log

| Date | Who | What |
|---|---|---|
| 2026-08-04 | agent | Document created. Review + plan only; nothing built. Verified all §⓪ rows on disk. |
| 2026-08-05 | agent | Added §⑨ shared platform sender. Verified the `appsettings` fallback at `EmailTemplateService.cs:248/359/131`, the strict `CompanyId ==` lookup at `EmailProviderConfigRepository.cs:14`, and the absence of any sender-mode flag on `CompanyEmailProvider`. Nothing built. |
| 2026-08-05 | agent | **Design correction — fail-closed.** User: *"no fallback buddy — everything need to work configuration based."* Rewrote §⑨.3–⑨.10: implicit `appsettings` fallback is **deleted**, not improved; explicit `Priority`-ordered failover (column already exists — no new column); unsendable mail parks in `EmailSendQueue` with a reason code; configuration-warning banners on #28/#157/#34. Recorded the **provisioning chicken-and-egg** (Step 9 `SEND_WELCOME` fires before any provider exists) as new blocking **Q12**, and existing-tenant cutover as **Q13**. Nothing built. |
