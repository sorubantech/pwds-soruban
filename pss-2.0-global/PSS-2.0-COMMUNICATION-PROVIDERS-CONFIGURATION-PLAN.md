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

## ⑧ Build log

| Date | Who | What |
|---|---|---|
| 2026-08-04 | agent | Document created. Review + plan only; nothing built. Verified all §⓪ rows on disk. |
