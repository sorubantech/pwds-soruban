# PSS 2.0 — Communication Metering, Provider Strategy & Billing

**Status:** ANALYSIS + RECOMMENDATION. Nothing is built by this file.
**Date:** 2026-08-05
**Companion docs:** `PSS-2.0-COMMUNICATION-PROVIDERS-CONFIGURATION-PLAN.md` (fail-closed sending decision), `PSS-2.0-PLANS-AND-ENTITLEMENTS-APPROACH.md` (plan layer), `PSS-2.0-TENANT-COMMS-CONFIG-UI-FIX-PROMPT.md` (screen fixes)
**Question answered:** how plans, quotas, providers, overage and billing fit together for Email / SMS / WhatsApp.

---

## ⓪ Verified on disk before writing this

Every claim below about existing behaviour was read from source, not assumed.

| Fact | Source | Consequence |
|---|---|---|
| `PlanQuota.LimitValue` NULL = **unlimited**; Period = MONTH for FLOW | `Base.Domain/Models/BillingModels/PlanQuota.cs` | "Unlimited" is already modelled correctly. Nothing to build. |
| A **missing** `PlanQuota` row resolves to **`0L`**, not null | `EntitlementService.cs:69` — *"Absent → 0 (not provisioned / fail-closed)"* | ⚠️ **Adding a meter code without seeding a row for every plan blocks 100 % of that action for every tenant.** This is the single highest-risk item in the whole billing layer. |
| `limit == 0` throws `PlanQuotaExceededException` | `QuotaBehavior.cs` | Same. |
| FLOW consumption is recorded **after** the handler succeeds | `QuotaBehavior.cs` — `IncrementFlowAsync` post-`next()` | Correct design. A failed send consumes nothing. Keep it. |
| Bulk is checked as a whole via `IBulkMeteredRequest.UnitCount` | `QuotaBehavior.cs` §4.5 | Campaign sends can be gated correctly today. |
| `MeterCodes.All = [CONTACTS, DONATIONS, USERS, EMAILS]` | `BillingCodes.cs:67` | **No SMS meter. No WhatsApp meter.** |
| `[MeteredResource(MeterCodes.Emails, …)]` appears on exactly **one** command | `SendTestEmail.cs:11` | The 10,000-email allowance is currently decorative. Only test emails count. |
| `FeatureCodes.ChannelEmail / ChannelSms / ChannelWhatsApp` exist | `BillingCodes.cs:32-34` | Channel **on/off** is gateable today; channel **volume** is not. |
| `PlanEntitlement` (boolean) and `PlanQuota` (numeric) are **separate tables** | both entity files | Correct separation. Do not merge them. |
| No add-on / overage / wallet entity exists anywhere | `find` across `BillingModels` | Everything in §④ is greenfield. |
| Trial expiry is evaluated live, not by a job | `EntitlementService.cs:98-101` | Good. Lapsed trial → all limits 0 → no sending. Consistent with fail-closed. |

**Bottom line on the existing foundation: it is well built.** The gates, the null-means-unlimited semantics, the post-success FLOW increment, the bulk unit count — all correct. What is missing is not architecture, it is **coverage** (two of three channels unmetered) and **commerce** (no way to buy more).

---

## ① The correction that matters most

You wrote:

> *"the main point is our platform maintain 10000 email tracking records and 10000 emails seding service. this is our plan based feature."*

**You are right, and the instinct is a good one. But "10,000 emails" is not one number — it is two, and they behave completely differently.**

| | **Delivery** | **Processing** |
|---|---|---|
| What it is | Handing the message to a mail server that puts it in an inbox | Compose, template, queue, retry, log, track opens/clicks, store history, report |
| Who pays the cost | Whoever owns the provider account | **Always us** |
| Real cost per email | ~$0.0001 – $0.001 | Storage + compute + webhook ingestion. Small, but never zero, and it is *ours* |
| Exists when tenant uses **our** provider | ✅ our cost | ✅ our cost |
| Exists when tenant uses **their own** provider | ❌ their cost | ✅ **still our cost** |

This is why the question *"should we charge when they bring their own provider?"* has a clean answer: **yes — but not for the same thing.**

They are buying a CRM that happens to send email. They are not buying an SMTP relay. HubSpot, Zendesk and Intercom charge full price and do not let you bring your own bulk sender at all. Salesforce lets you relay through your own M365 — and charges you exactly the same.

### The consequence: two meters, not one

| Meter | Type | Counts | Purpose |
|---|---|---|---|
| `EMAILS` *(existing code, keep it)* | FLOW / MONTH | **Every** email the platform processes — both modes | The **value** meter. What the plan sells. |
| `EMAILS_PLATFORM` *(new)* | FLOW / MONTH | The subset actually delivered on **our** infrastructure | The **cost** meter. Protects our provider bill and our sending reputation. |

A BYO tenant burns `EMAILS` only. A platform-sender tenant burns both. One plan, one headline number to the customer, two numbers internally.

**Why bother, when one number is simpler?**

Because without the split you must choose between two bad options:

- Count everything against one quota → the BYO tenant pays SendGrid *and* burns your allowance. They will notice and complain, and they will be right.
- Count nothing for BYO → your own storage and tracking cost is unbounded and unpriced, and a tenant can pipe a million emails through your tracking layer for free.

The split costs one extra constant and one extra seed row per plan, **today**. Retrofitting it after tenants are live means re-deriving historical usage. Do it now.

> **Optional refinement (recommended for the price sheet, not the schema):** advertise the plan as *"10,000 emails/mo included — with our sender or yours"*, and set `EMAILS` generously above `EMAILS_PLATFORM` (say 25,000 vs 10,000). BYO tenants then effectively get a bigger allowance, which is both fair and a nudge you can point at in sales conversations.

---

## ② Answering your four scenarios directly

### Scenario 1 — platform sends the email · **CORRECT, with one addition**

Your understanding is right and it is how HubSpot, Zendesk, Intercom, Customer.io and Mailchimp all work. Platform-managed sending is the default in modern SaaS because BYO configuration is the #1 cause of failed onboarding.

Advantages: instant time-to-value, one support surface, deliverability you control, sending becomes a plan lever.

**The one thing you added that is wrong:**

> *"The customer should not need to configure an external provider."*

True for the *provider*. **Not true for the domain.** A tenant sending bulk mail as `donations@theircharity.org` from your SendGrid account, with no SPF/DKIM alignment, lands in spam and — worse — trains inbox providers that *your* sending IPs send unauthenticated mail for domains that did not authorise it. One bad tenant degrades delivery for every other tenant on the pool.

So the honest rule is:

| Tenant has done | May send |
|---|---|
| Nothing | **Transactional only**, from `noreply@<yourdomain>` with their address as `Reply-To`, at a low rate cap |
| Verified sending domain (added your CNAME/TXT records) | Everything, from their own domain, full cap |

Domain verification is not a feature. **It is the abuse gate.** Treat it as a hard prerequisite for bulk on the shared sender.

Disadvantage you must accept: your provider bill becomes a COGS line that scales with customer success, and **their** reputation problems become **your** operational problems. §⑤ is about containing that.

---

### Scenario 2 — the platform-provider configuration screen · **RIGHT LIST, WRONG OWNER ON HALF OF IT**

Your list is good. The correction is *who does what*.

| Setting | Platform sender | BYO sender |
|---|---|---|
| Choose provider (SendGrid / SES / …) | ❌ **Platform decides.** Never expose ours — it is an implementation detail and a security surface | ✅ Tenant |
| API key / SMTP credentials | ❌ **Never shown, never stored on the tenant row.** Resolves from `ops.PlatformCommunicationProviders` | ✅ Tenant, write-only + masked |
| Sending domain | ✅ Tenant enters it | ✅ Tenant enters it |
| **DNS records to publish** | ✅ **We generate and display them** (we own the provider, so we own the DKIM keys) | ❌ **Their provider generates them.** We only record the domain and its status |
| Verification check | ✅ We call the provider API and poll | 🟡 We can do a DNS lookup, but the authority is their provider. Show "as seen in DNS", not "verified" |
| SPF / DKIM / DMARC guidance | ✅ Ours, exact records | 🟡 Generic guidance + link to their provider's docs |
| Default from-name / from-email | ✅ Both | ✅ Both |
| Reply-To | ✅ Both | ✅ Both |
| Rate limits (`Hourly/Daily/MonthlyEmailLimit`) | ❌ **Platform-set, tenant read-only.** This is our infrastructure | ✅ Tenant-editable — it is their account and their bill |
| Plan quota usage (`EMAILS`) | ✅ Shown | ✅ **Shown — this is the point of §①** |
| Delivery cost | ✅ Included in plan; show allowance used | ❌ **Not our business.** Never show a cost figure for their account |
| Suppression list | ✅ Tenant view + **platform-global list they cannot edit** | ✅ Tenant list only |
| Bounce / complaint rate | ✅ Shown, and enforced (auto-suspend) | ✅ Shown, advisory only |
| Failover provider (`Priority` 2) | ✅ Both | ✅ Both |

**Enterprise features missing from your list**, in order of importance:

1. **Suppression list** (hard bounces, complaints, unsubscribes). Non-negotiable. On the shared sender it must be **two-tier**: a per-tenant list *and* a platform-global list. If tenant A hard-bounces an address, tenant B must not retry it from the same IP pool.
2. **Separate transactional and marketing streams.** A receipt must never be delayed or blocked behind a campaign, and must never inherit a campaign's reputation damage. Different queues, different rate classes, ideally different IPs.
3. **Warm-up ramp.** A new tenant on the shared sender starts at a low daily cap that rises with clean sending history. Prevents day-one blast damage.
4. **Webhook ingestion per provider.** This is the hidden cost of BYO — every provider has a different event payload. It is why most SaaS supports 3-4 BYO providers, not 8.
5. **Test-send / preview to a seed address**, before anything goes to a list.
6. **Send-time DMARC alignment check** with a plain-language failure message.

---

### Scenario 3 — customer's own provider · **MOSTLY RIGHT, ONE FALSE ASSUMPTION**

Your split of responsibilities is correct. The false assumption is this one:

> *"Our platform still manages: tracking, analytics, delivery reports."*

Only partly. It depends on **how** they connect.

| Signal | Who produces it | Works on plain SMTP BYO? |
|---|---|---|
| **Open** | Our tracking pixel | ✅ Yes |
| **Click** | Our link redirect | ✅ Yes |
| **Sent / accepted** | Us, at handoff | ✅ Yes |
| **Delivered** | Provider webhook | ❌ **No** |
| **Bounced (hard/soft)** | Provider webhook | ❌ **No** — you would need a bounce mailbox and a parser |
| **Spam complaint** | Provider FBL webhook | ❌ **No** |
| **Unsubscribe (list-unsub header)** | Provider | ❌ Ours only, via our own footer link |

**Design consequence:** offer **two BYO tiers**, and say so on the screen.

- **API providers** (SendGrid, Mailgun, Postmark, SES, Brevo) → full analytics, because we ingest their webhooks.
- **Plain SMTP / M365 / Google Workspace** → opens, clicks and send-log only. Show a note: *"Delivery and bounce reporting is not available over SMTP."*

Do **not** silently show an empty Delivered chart and let them think the product is broken.

**Should tracking count against plan limits?** Yes — `EMAILS`. That is exactly what §① exists to make defensible.
**Should analytics stay in the subscription?** Yes. It is the product.
**Should we charge extra for BYO?** No. Charging a customer for *not* using your infrastructure is backwards and reads as a penalty.

**Scope limit for MVP:** support **SMTP + SendGrid + one more**. Every additional API provider is a webhook ingester, an event mapper, a credential shape, a connection test and a support burden. Adding providers later is easy; supporting eight badly is not.

---

## ②a Custom domain creation — verified against real products

**Your rule:** *custom domain creation and verification is offered ONLY when the tenant uses our platform provider; when the tenant brings their own provider we cannot offer it.*

**This is correct, and it is not a limitation of our design — it is a property of how DKIM works.** Every major CRM and helpdesk lands on the same rule, independently.

### Why it is technically forced

DKIM is a **private-key signature**. The key pair is generated by, and lives on, the machine that actually signs and sends the message.

| | Who generates the DKIM key | Who publishes DNS | Who can say "verified" |
|---|---|---|---|
| **Our platform provider** | Our provider account (SendGrid/SES) — we hold it | The tenant, in their DNS | ✅ **We can** — we call the provider API and poll |
| **Tenant's own provider** | **Their** provider account — we never see the key | The tenant, in their DNS | ❌ **Only their provider can** |

SendGrid generates the DKIM keys and returns **CNAME** records that point back into SendGrid, so SendGrid can rotate keys without the customer touching DNS again. That CNAME points at *our* account's infrastructure. We cannot mint a CNAME into a SendGrid account we do not own.

> **Plain version:** the DKIM record is the address of the postbox that signs the letter. We can only give out the address of **our** postbox. If they use their own postbox, only their postbox provider knows its address.

### Every real product does exactly this

| Product | Rule | Evidence |
|---|---|---|
| **Zoho CRM** | *"DKIM signing is applicable only for the From Addresses for which you **haven't** configured the Custom SMTP."* | This is your rule stated word for word by a product with millions of tenants |
| **Freshdesk** | *"DKIM is **not applicable** if you have a custom mailbox."* Custom SMTP is a paid-tier (Forest) feature; DKIM is on all plans — but the two are mutually exclusive | Same rule |
| **Zendesk** | DKIM = two **CNAME** records pointing your domain at **Zendesk's** domain for signing. Their Authenticated SMTP Connector is a **separate, parallel mode** for outbound relay | Same rule — DKIM belongs to the Zendesk-sends path |
| **HubSpot** | "Connect your email sending domain" = DKIM, *"gives HubSpot permission to send on your behalf."* Marketing email always goes over HubSpot infrastructure. **No custom SMTP for marketing email at all** | Strictest version — they don't even offer BYO for bulk |
| **Salesforce Marketing Cloud** | Sender Authentication Package: *"DKIM is signed by your owned domain using **SFMC's private key**"* + dedicated IP + branded links. Email Relay (your own M365/SMTP) is a **different** feature | Explicitly: **their** key, so it only works on **their** send path |
| **Mailgun / SendGrid (as infrastructure)** | Multi-tenant platforms isolate tenants via **subaccounts** and send with `X-Mailgun-On-Behalf-Of`; per-tenant domains, per-tenant rate limits at the tenant boundary | This is the pattern for our platform-sender mode |

**Nobody offers DKIM setup for a customer's own SMTP server.** Not one. The reason is the same everywhere: they do not hold the key.

### Zoho also confirms a second thing you should copy

> *"Mass emails and emails sent from the organization email address are **always** sent from Zoho's server, regardless of SMTP configuration."*

Zoho lets you plug in your own SMTP for **1:1 mail**, but bulk always goes over Zoho. That is deliberate — a customer's Google Workspace or M365 mailbox will throttle or suspend on bulk volume, and the resulting failures become Zoho's support tickets.

**Recommendation: adopt the same split.**

| Mail type | Platform sender | Tenant's own SMTP (M365/Gmail) | Tenant's own API provider (SendGrid/SES/Mailgun) |
|---|---|---|---|
| Transactional (receipt, reset, reminder) | ✅ | ✅ | ✅ |
| Bulk / campaign | ✅ | ❌ **Block it** — their mailbox will throttle and get suspended | ✅ |

### What our screen must therefore show

| Mode | Domain section shows |
|---|---|
| **PLATFORM_SHARED** | Full flow: *Add domain → we generate and display the CNAME/TXT records → Copy button → "Verify" button → we poll the provider API → status Verified / Pending / Failed*. Re-check on a schedule |
| **OWN** | Registration only: *Domain name*, *"Verified in your provider?"* checkbox or an advisory DNS lookup, and a link out to their provider's docs. **No records generated. No Verify button. Status shows "Managed by your provider"** |

**Do not** put a Verify button in OWN mode that runs a plain DNS lookup and prints "Verified". A DNS lookup can tell you a DKIM record exists; it cannot tell you it matches the key their provider will actually sign with. That is a false green tick, and false green ticks on deliverability screens generate the worst support tickets — the customer believes they are configured and their mail is silently going to spam.

If you want to give BYO tenants *something*, give an **advisory read-only panel**: "We found SPF / DKIM / DMARC records for this domain" with a ⓘ note that the authority is their provider. Label it **"as seen in DNS"**, never "Verified".

### One thing worth building later, not now

If a BYO tenant is on **SendGrid or Mailgun specifically**, they can give us an API key with domain scope and we *can* drive their domain setup through their own account's API — their key, their account, our UI. Mailgun's subaccount model and `X-Mailgun-On-Behalf-Of` header exist for exactly this. It is a genuine differentiator, and it is also a per-provider integration with its own credential scopes and failure modes. **Phase 3 at the earliest, after §⑦ Must-have ships.**

---

### Scenario 4 — going over the allowance · **DECIDED 2026-08-05: UPGRADE IS THE DEFAULT. PACKS EXIST, BUT OFF BY DEFAULT AND PLATFORM-ENABLED PER TENANT.**

> ✅ **User decision, part 1:** *"we can give plan upgrade - we can avoid the packs upgrade."*
> ✅ **User decision, part 2 (same day, refinement):** *"this packs should work based on platform enable the email packs for this tenant means we need to show that option - then they can purchase like Diwali or Christmas time period."*

**The two together are better than either alone**, and this is the design:

| | |
|---|---|
| **Default for every tenant** | Over the limit → **upgrade the plan**. That is the only thing they see. Nothing else exists in the UI |
| **Packs are a platform switch** | The platform turns "email packs" **on for one named tenant**. Only then does a *Buy email pack* option appear for them |
| **What packs are for** | A **seasonal peak** — Diwali, Christmas, a disaster appeal, a matched-giving week. A one-off spike that does not justify a permanent plan increase |
| **What packs are not for** | A tenant who is over the limit **every month**. That tenant gets an upgrade conversation, not a pack. The platform simply does not enable packs for them |

This keeps the commercial discipline of "upgrade only" — because the tenant cannot self-select a pack to dodge an upgrade — while giving us a real answer for the charity that runs one enormous appeal a year and is otherwise a perfect 50K customer. **The judgement stays with us, which is exactly where it should be.**

**Consequence table** — all options assessed, for the record:

| | Verdict | Why |
|---|---|---|
| **A. Charge per extra email automatically** | ❌ Rejected | Surprise bills; nonprofits on fixed budgets churn on them |
| **B. Self-serve prepaid packs, on for everyone** | ❌ Rejected 2026-08-05 | Cannibalises plan upgrades; a growing tenant stays on a cheap plan forever |
| **C. Pure usage-based** | ❌ Rejected | Right for Twilio, wrong for this market |
| **D. Plan upgrade only** | ✅ **The default path** | Simplest, safest, strongest upgrade signal |
| **E. Platform-gated seasonal packs** | ✅ **CHOSEN as the exception**, on top of D | Covers the seasonal spike without opening a self-serve escape hatch from upgrades |

#### How the gate works — no new gating code

Packs are gated by a **boolean feature**, which the platform already has machinery for:

| Step | Mechanism | Exists? |
|---|---|---|
| New feature code `ADDON:EMAIL_PACKS` | `FeatureCodes` constant + `PlanEntitlement` row = **0 on every plan** | Table exists, code is new |
| Platform enables it for one tenant | `SetSubscriptionOverrideCommand(SubscriptionId, FeatureCode: "ADDON:EMAIL_PACKS", OverrideValue: 1, Note: "Diwali 2026")` | ✅ **Already built** |
| Tenant sees the *Buy email pack* option | `GetMyEntitlements` already returns feature flags to the FE | ✅ Already built |
| Platform turns it off after the season | Soft-delete the override row | ✅ Already built |

> The `Note` field on the override is where *"approved for Diwali 2026, ref DEAL-114"* lives. That makes the exception auditable, which is the whole point of keeping it platform-controlled.

#### What this forces us to get right anyway

Packs are an exception granted by us, not a safety valve the tenant can reach for. For the 95 % of tenants who never get the switch, **nothing has changed** — so all three obligations stand:

1. ⚠️ **Set the allowances with headroom.** A tenant should hit the limit because they *grew*, not because they ran one seasonal appeal. Size the number for a **peak** month, not an average one. This raises the stakes on decision **D1**.
2. ⚠️ **The top plan must not be a dead end.** If PLAN_100K runs out, "upgrade" points where? Answer: **CUSTOM**, sold by conversation, with the number written into the contract, applied as a `SubscriptionOverride`. The over-limit message on the top plan must say *"Contact us"*, not *"Upgrade"*.
3. ⚠️ **Warn before blocking, always.** Hitting 100 % is a full stop mid-campaign. Notify the tenant admin at **80 %** and **95 %**, by email and by an in-app banner. Mandatory, not nice-to-have. For a pack-enabled tenant the 80 % warning is also the moment they are most likely to buy — put the pack button in it.

#### The over-limit message

The button now varies by **two** things — the tier, and whether packs are switched on for that tenant:

| Situation | Message | Button |
|---|---|---|
| Limit hit, plan below top tier, **packs OFF** *(the default)* | *"You've used all N emails this period. Upgrade for a larger allowance."* | **Upgrade plan →** |
| Limit hit, **packs ON for this tenant** | *"You've used all N emails this period. Buy a top-up pack, or upgrade for a permanently larger allowance."* | **Buy email pack →** *(primary)* + **Upgrade plan →** *(secondary)* |
| Limit hit, already on the top tier | *"You've used all N emails this period. Contact us to raise your limit."* | **Contact us →** |
| CUSTOM plan | *"You've reached the email limit agreed in your contract."* | **Contact us →** |
| No live subscription *(lapsed trial)* | *"Your trial has ended. Choose a plan to keep sending."* | **View plans →** |
| Multiple limits hit (emails + contacts) | *"You've reached your plan limits."* | **Upgrade plan →** |

> ⚠️ **Never show a Buy-pack button to a tenant whose switch is off.** Not greyed out, not "contact us to unlock" — absent. A visible-but-disabled button turns every seasonal exception into a support conversation with every other tenant.

#### Quota resolution — now has one extra term

```
base   = SubscriptionOverride.OverrideValue ?? PlanQuota.LimitValue    -- NULL ⇒ unlimited
packs  = SUM(units remaining on active, unexpired packs for this meter)
effective_limit(company, meter) = base IS NULL ? unlimited : base + packs
```

This is the **only** change to `EntitlementService.GetLimitAsync` — and it is skipped entirely when `base` is NULL. It stays cheap: pack rows are few and already inside the ~60 s entitlement cache.

> ⚠️ **Cache invalidation.** Buying a pack must call `entitlementService.Invalidate(companyId)`, exactly as `AssignSubscription` already does. Without it the tenant pays and stays blocked for up to a minute — the worst possible sixty seconds in the product.

---

### Scenario 5 — "Unlimited" · **ALREADY SOLVED IN YOUR SCHEMA. DO NOT SELL IT ANYWAY.**

`PlanQuota.LimitValue = NULL` means unlimited, and `QuotaBehavior` skips the count entirely when it sees null. That is correct and efficient. Nothing to build.

**What "unlimited" means in every enterprise SaaS contract that offers it:** unlimited *subject to fair use*, where fair use is enforced by three things that have nothing to do with the quota:

| Layer | What it is | Where it lives in your code today |
|---|---|---|
| **L1 plan quota** | The commercial allowance | `PlanQuota` + `UsageCounter` — ✅ exists |
| **L2 rate cap** | Per-second / hour / day ceiling. Protects infrastructure regardless of plan | `CompanyEmailProvider.HourlyEmailLimit` / `DailyEmailLimit` / `RatePerSecond` — ✅ exists, ❌ not enforced |
| **L3 abuse suspension** | Bounce rate, complaint rate, sudden 100× volume spike → auto-pause + alert | `BounceRate` / `SpamRate` columns exist, unused |

**Because L2 and L3 are independent of L1, an unlimited plan is technically safe.** You already have the right shape. It just is not wired up.

**Commercial advice, which is separate:** do not put "Unlimited emails" on a self-serve price card. It attracts exactly the customers who cost the most, and it is impossible to walk back. Say **"Volume by agreement"** on CUSTOM and set a real number per contract. The plan row still holds a number; the customer still feels bespoke.

---

## ③ The hard truth about SMS and WhatsApp

**This is the part of your model that will not survive contact with reality, and it is worth reading twice.**

You are planning to bundle SMS and WhatsApp allowances into plans the same way as email. **Do not.**

| | Cost spread across countries | Bundleable as a unit quota? |
|---|---|---|
| **Email** | Essentially flat worldwide, fractions of a cent | ✅ **Yes** |
| **SMS** | ~30× between cheapest and dearest destinations, plus per-country carrier surcharges and registration fees (DLT in India, 10DLC in the US, sender-ID registration elsewhere) | ❌ **No** |
| **WhatsApp** | Meta prices per **24-hour conversation window**, by **category** (marketing / utility / authentication / service) and by **country**. Marketing costs many times utility. Rate card changes periodically | ❌ **No** |

Two things follow.

**1. "1,000 SMS included" is not a sellable unit once you sell in more than one country.** The same 1,000 messages can cost you £2 or £60 depending on where they land. Every global SaaS solves this the same way: **a prepaid balance in money, not a quota in units.**

> **Recommendation — a communication wallet.** The tenant tops up a currency balance. Each send debits it at that destination's rate. Balance low → alert. Balance zero → sending pauses. That is Twilio, MessageBird, Gupshup and every CPaaS reseller, and it is the only model that is correct in every country at once.
>
> **Or, much simpler and perfectly respectable for v1: SMS and WhatsApp are BYO-only.** The tenant brings their own Twilio / Gupshup / Meta WABA. We charge for the *management* — templates, campaigns, opt-in/opt-out, DND compliance, delivery logs, analytics. We never touch their message cost. This removes an entire category of financial risk and is genuinely how many vertical CRMs operate.

**2. If you meter WhatsApp per message, your numbers will be wrong.** Meta bills per conversation window, not per message. A 20-message support thread inside 24 hours is *one* billable conversation. Count messages and you will over-report usage by an order of magnitude and mis-price the plan.

**Meter these correctly or not at all:**

| Meter | Unit that matters | Never use |
|---|---|---|
| `SMS_SEGMENTS` | **Segments.** 160 chars GSM-7, 70 chars if any Unicode (emoji, most non-Latin scripts). A 200-char message is 2 segments and costs double | "messages" |
| `WHATSAPP_CONVERSATIONS` | **24-hour conversation windows**, split by category | "messages" |

A tenant writing in Tamil, Hindi or Arabic hits the 70-character Unicode limit almost immediately. If you meter "messages", their real cost is 3-4× what you counted.

---

## ④ Recommended meter set

⚠️ **Read `EntitlementService.cs:69` first.** A meter code with no `PlanQuota` row resolves to **0**, and 0 blocks everything. **Every code added below must ship with a `PlanQuota` row for every plan — FREE, PLAN_50K, PLAN_100K, CUSTOM — in the same release.** Ship the constant without the seed and you take the whole channel offline for every tenant at once.

| Code | Type | Period | Meaning | FREE | 50K | 100K | CUSTOM |
|---|---|---|---|---|---|---|---|
| `CONTACTS` | STOCK | — | *existing* | — | — | — | — |
| `DONATIONS` | STOCK | — | *existing* | — | — | — | — |
| `USERS` | STOCK | — | *existing* | — | — | — | — |
| `EMAILS` | FLOW | MONTH | *existing.* Redefine as **emails processed, either mode** | ? | ? | ? | NULL |
| `EMAILS_PLATFORM` | FLOW | MONTH | **new** — delivered on our infrastructure | **0** | ? | ? | ? |
| `SMS_SEGMENTS` | FLOW | MONTH | **new** — segments, not messages | **0** | ? | ? | ? |
| `WHATSAPP_CONVERSATIONS` | FLOW | MONTH | **new** — 24 h windows, not messages | **0** | ? | ? | ? |
| `PUSH_NOTIFICATIONS` | FLOW | MONTH | **new** — near-zero cost, be generous | ? | ? | ? | NULL |

`?` = your commercial decision, still owed (this is §⑥ Q2 of the companion plan).

**`EMAILS_PLATFORM = 0` on FREE is deliberate and useful.** Free tenants may connect their own provider and use the whole product; they may not send on our reputation. That is the cheapest possible abuse defence and it costs nothing to implement — 0 is already fail-closed.

**Where the attributes go** — currently only `SendTestEmail` is metered. Also needed:

| Command | Meter | Unit count |
|---|---|---|
| Bulk / campaign email send | `EMAILS` + `EMAILS_PLATFORM` | `IBulkMeteredRequest.UnitCount` = recipient count |
| Transactional email (receipt, reminder, welcome) | same | 1 |
| SMS send / campaign | `SMS_SEGMENTS` | **computed segments**, not recipients |
| WhatsApp send | `WHATSAPP_CONVERSATIONS` | conversations opened, not messages |

`QuotaBehavior` supports exactly one meter per command. Two meters on one send needs either a second attribute or an explicit `IUsageMeterService` call in the handler — **the handler call is the simpler change** and keeps the behavior untouched.

---

## ⑤ Deliverability — the risk you have not costed

Everything above is commerce. This section is survival, and it is the one thing on this page that can take the platform down for every customer at once.

**The shared sender means every tenant sends from your reputation.** One tenant uploading a purchased list generates spam complaints that get *your* sending domain and IPs blocklisted. Every other tenant's receipts then go to junk. You will find out from support tickets, and recovery takes weeks.

Minimum defences, in build order:

| # | Defence | Why |
|---|---|---|
| 1 | **Domain verification required for bulk on the shared sender** | The single highest-value gate. Unverified tenants get transactional-only at a low cap |
| 2 | **Two-tier suppression list** (per-tenant + platform-global) | Stops tenant B re-mailing an address tenant A hard-bounced from the same IP pool |
| 3 | **Auto-suspend on bounce/complaint threshold** — e.g. >5 % bounce or >0.1 % complaint over a rolling window | `BounceRate` / `SpamRate` columns already exist. Wire them |
| 4 | **Separate transactional and marketing streams** | A donation receipt must never queue behind, or inherit the reputation of, a campaign |
| 5 | **Warm-up ramp** — new tenants start low, cap rises with clean history | Prevents day-one blast damage |
| 6 | **Provider subaccount per high-volume tenant** (SendGrid Subusers, SES configuration sets) | Isolates reputation. Only needed above a volume threshold |
| 7 | **Enforce L2 rate caps** | Currently columns with no enforcement |

Items 1, 2 and 3 must land **in the same release as the shared sender**. Not after.

---

## ⑥ Data model — what to add

Everything below is greenfield. Nothing here exists today.

### Email packs — ✅ **BUILDING, v1.1, platform-gated**

Two tables. One is the platform's catalogue of what a pack *is*; the other is what a tenant actually bought.

```
billing.AddOnPackCatalog          -- platform-owned SKU list
  AddOnPackId        int PK
  PackCode           string       EMAIL_10K, EMAIL_25K, EMAIL_50K
  MeterCode          string       EMAILS  (constrained to FLOW meters)
  Units              long         10000
  ValidityDays       int          how long the pack lives once bought — see below
  IsActive           bool
  UNIQUE (PackCode)

billing.AddOnPackPrices           -- mirrors billing.PlanPrices exactly; reuse the FX/sellable path
  AddOnPackPriceId, AddOnPackId, CurrencyId, Amount
  UNIQUE (AddOnPackId, CurrencyId)

billing.CompanyAddOnPacks         -- one row per purchase
  CompanyAddOnPackId int PK
  CompanyId          int
  SubscriptionId     int          the subscription live at purchase time
  AddOnPackId        int
  MeterCode          string       denormalised from the catalogue — the catalogue is mutable
  UnitsPurchased     long         snapshot, NOT a FK read at consumption time
  UnitsConsumed      long         starts 0
  ValidFrom          timestamptz
  ValidUntil         timestamptz  ValidFrom + ValidityDays
  Status             string       Active | Exhausted | Expired | Refunded
  CurrencyId, Amount              snapshot of what they paid
  PaymentReference   string?      gateway txn id, or the offline-payment row
  GrantedByUserId    int?         set when the platform grants a pack rather than selling it
  Note               string?
```

**Design rules — each of these prevents a specific, real bug:**

| Rule | Why |
|---|---|
| **Packs are consumption-tracked (`UnitsConsumed`), not period-bound** | The FLOW counter resets on the billing anniversary *and* on any plan change. A pack expressed as "+10,000 this period" would be **re-granted in full** every reset. Tracking consumption on the pack row makes that impossible |
| **A pack spans billing periods** | Diwali and Christmas do not align to anyone's signup date. `ValidityDays` (recommend **90**) lets a pack bought in October cover the whole season |
| **Base allowance is consumed first, packs second** | The tenant must never burn a paid pack while free plan units remain |
| **FIFO by earliest `ValidUntil`** | Consume the pack that expires soonest, or tenants lose units they paid for while a later pack sits full |
| **Snapshot `UnitsPurchased`, `MeterCode`, `Amount`, `CurrencyId`** | Editing an SKU next year must not retroactively change what someone bought — the same snapshot discipline already used for `Subscription.Amount` / `FxRateUsed` |
| **Unused units expire. No refund, no rollover** | Stated at purchase. Rollover turns a top-up into a wallet, which is the model §③ deliberately rejected |
| **Packs are per-meter and non-transferable** | An email pack cannot become SMS credit |
| **`EMAILS` and `EMAILS_PLATFORM` both debit** | A pack raises the value meter *and* the delivery meter, or the tenant buys headroom they cannot actually send through |

**Consumption path** — the one piece of new logic in the metering layer:

```
after a successful send of N units:
  IncrementFlowAsync(company, meter, N)                    -- unchanged, exactly as today
  overflow = max(0, counter_after - base_limit)
  overflow -= max(0, counter_before - base_limit)          -- only the part that crossed
  if overflow > 0: debit `overflow` across active packs, FIFO by ValidUntil
                   mark a pack Exhausted when UnitsConsumed = UnitsPurchased
```

> ⚠️ Debit inside the **same transaction** as the counter increment, and take the existing `pg_advisory_xact_lock` on `(company, meter)` — the same lock `EnsureStockCapacityAsync` already uses. Two concurrent campaigns must not both spend the last 500 units of the same pack.

**An expiry job** flips `Active → Expired` past `ValidUntil`. It is a tidy-up only: `GetLimitAsync` must filter on `ValidUntil` directly and never trust `Status`, so a job that fails to run cannot hand out free email.

### `notify.EmailSendingDomains` — both modes

```
EmailSendingDomainId int PK
CompanyId            int
DomainName           string
SenderMode           string     OWN | PLATFORM_SHARED
DkimSelector         string?    we generate for PLATFORM_SHARED
DkimPublicKey        string?    ditto
VerificationStatus   string     Pending | Verified | Failed
VerifiedOn           timestamptz?
LastCheckedOn        timestamptz?
UNIQUE (CompanyId, DomainName)
```

### `notify.EmailSuppressions` — two-tier

```
EmailSuppressionId int PK
CompanyId          int?         NULL = PLATFORM-GLOBAL  ⚠️ needs IgnoreQueryFilters like ops
EmailAddress       string
Reason             string       HardBounce | Complaint | Unsubscribe | Manual
SuppressedOn       timestamptz
SourceMessageId    string?
```

> ⚠️ A `CompanyId IS NULL` row will be hidden by the global tenant query filter. Every read of the platform-global list needs `IgnoreQueryFilters()` **plus** an explicit `IsDeleted != true` guard — the same rule that already applies to `ops`.

### `CompanyEmailProvider` — one new column

`SenderMode` = `OWN` | `PLATFORM_SHARED`. Existing rows backfill to `OWN`. See the companion plan §⑨ for the resolver.

### Communication wallet — only if you bundle SMS/WhatsApp

```
billing.CommunicationWallets      CompanyId, CurrencyId, Balance, LowBalanceThreshold, AutoTopUp…
billing.WalletTransactions        WalletId, Type (TopUp|Debit|Refund|Adjustment), Amount,
                                  MeterCode, Quantity, UnitRate, CountryCode, ReferenceId
```

If you take the BYO-only route for SMS/WhatsApp (recommended for v1), **skip this entirely.**

### What NOT to build

- ❌ Do not merge `PlanQuota` and `PlanEntitlement`. Boolean features and numeric limits have different lifecycles. The current separation is right.
- ❌ Do not put per-country SMS rate cards in the plan tables. That is a pricing catalog, and it changes monthly.
- ❌ Do not store a delivery cost figure for BYO tenants. It is not your data and it will be wrong.

---

## ⑥a Upgrade mechanics — what the upgrade-first decision left unanswered

> Added 2026-08-05. **"Upgrade is the only route" is now the entire commercial safety valve, so the upgrade path itself has to be correct.** Every row below was verified against code on disk, not assumed.

### The good news first — two things already work, with zero new code

**1. An upgrade unblocks the tenant instantly.** `AssignSubscription.cs:174-196` cancels the incumbent subscription and inserts a **new** one with `CurrentPeriodStart = now`. `UsageMeterService.CountFlowAsync` keys the counter on `(CompanyId, MeterCode, PeriodStart)`. A new period start means **the FLOW counter reads 0 immediately** and the blocked campaign goes out on the next attempt.

> Without this, "upgrade" would take the customer's money and leave them blocked until the next billing date — the single worst possible outcome for a product whose default remedy is an upgrade. It already behaves correctly. **Do not "fix" it.**

**2. "Contact us" on the top tier is already implementable.** `billing.SubscriptionOverride` exists (`SubscriptionOverride.cs`), resolution is **`override ?? plan`**, and `SetSubscriptionOverrideCommand(SubscriptionId, FeatureCode, MeterCode, OverrideValue, Note)` is already built behind `PLATFORM_PLANS` / `PLATFORM_PLAN_EDIT`.

| The contract says | We do |
|---|---|
| "CUSTOM plan, 250,000 emails/month" | One override row: `MeterCode = EMAILS`, `OverrideValue = 250000`, `Note` = contract ref |
| "Unlimited by agreement" | Same row, `OverrideValue = NULL` |

**This closes the implementation half of D1b.** The commercial half — *what* we quote — is still owed. No new table, no new command, no new screen. Note that `OverrideValue = NULL` means unlimited, so **clearing an override is a soft-delete of the row, not a null write**.

### The problems — six, in order of how much they will hurt

**1. ⚠️ A bulk send is all-or-nothing, and upgrade-first makes that worse.**
`QuotaBehavior` rejects when `used + unitCount > limit`. A 5,000-recipient campaign with 4,000 remaining sends **zero**, not 4,000. Before, they bought a pack and carried on. Now the campaign simply stops.

| Option | Verdict |
|---|---|
| **Block the whole batch** | ✅ **Recommend.** Predictable, no half-sent appeal, no "who got it?" support ticket |
| Send up to the limit, drop the rest | ❌ A donor appeal that reaches 4,000 of 5,000 people silently is worse than one that does not send |

But blocking is only acceptable **with a pre-flight check**: the campaign screen must show *"This send will use 5,000 emails. You have 4,000 left this period."* **before** they press send, not a 500 after. → new MVP item.

**2. ⚠️ The period is the billing anniversary, not the calendar month.**
`GetCurrentPeriodStartAsync` reads `Subscription.CurrentPeriodStart`; `SubscriptionRenewalService.cs:376` rolls it on renewal. So a tenant who signed up on the 14th resets on the 14th.

> Every usage panel, warning email and error message must say **"resets on {CurrentPeriodEnd:d}"** — never "this month". Getting this wrong generates support tickets from customers who watch the 1st come and go while still blocked.

**3. ⚠️ Any plan change resets the FLOW counter — including a downgrade.**
The reset is a side effect of the new `CurrentPeriodStart`, not a rule anyone wrote. Consequences:

| | |
|---|---|
| Upgrade mid-period | Counter resets to 0, **and** a fresh billing period starts. **There is no proration today** — they pay a full cycle for a part-used one. Acceptable for v1, but say so on the upgrade screen |
| Downgrade then upgrade | Resets the meter. A determined tenant could cycle plans to refresh the allowance. Low risk (each hop is a real charge), but log plan changes and watch |
| Usage history | Old `UsageCounter` rows survive under the previous `PeriodStart`, so nothing is lost — but any "last 6 months" chart must group by row, not assume 1 row per calendar month |

**4. ⚠️ FLOW counts *attempted* sends, not delivered ones.**
`QuotaBehavior` increments after the handler succeeds — i.e. after the message is accepted by the provider. A hard bounce arriving by webhook two minutes later does **not** credit the quota back.

> **Recommend: no credit-back, ever.** The send cost us money regardless. But this must be one line in the plan T&Cs and in the usage panel tooltip, or the first customer to compare our number with SendGrid's will open a ticket. It also gives the tenant a real incentive to keep their list clean, which is exactly what §⑤ wants.
> **Retries must not double-count.** A provider-level retry of the same message is one send. If a retry re-enters the command pipeline it will meter twice — check this when wiring item 2 of §⑦.

**5. ⚠️ A lapsed trial blocks email with the wrong message.**
No live subscription ⇒ `GetLimitAsync` returns `0L` ⇒ `PlanQuotaExceededException`. Correct behaviour, wrong words: the tenant reads *"email quota exceeded"* when the truth is *"your trial ended"*. The over-limit UI must distinguish **no live subscription** from **limit reached** and route to the plan page, not to an upgrade of a plan they no longer hold.

**6. ⚠️ STOCK meters do not reset, and a downgrade can leave a tenant over the line.**
Drop from 100K to 50K with 60,000 contacts and `EnsureStockCapacityAsync` blocks every new contact while nothing is deleted. That grandfathering is right — **never delete tenant data to fit a plan** — but it must be stated on the downgrade confirmation: *"You have 60,000 contacts. The plan you are moving to allows 50,000. You will not lose data, but you will not be able to add contacts until you are under the limit."*

### Warnings — the details that decide whether item 11 actually works

| | Rule |
|---|---|
| **Thresholds** | 80 % and 95 % of `LimitValue`. Skip entirely when the limit is NULL (unlimited) |
| **Idempotency** | Fire **once per threshold per period**, keyed on `(CompanyId, MeterCode, PeriodStart, Threshold)`. Without this, every send past 80 % emails them again |
| **Recipients** | Tenant admins — reuse the existing `NOTIFY_ADMIN_ROLE_CODES` resolution rather than inventing a second rule |
| **Delivery** | ⚠️ **The warning is itself an email.** Under fail-closed it needs a working provider, and it must never be blocked by the very quota it is warning about — send it outside the metered path |
| **In-app** | Banner on the communication screens + the usage panel, not only email |

### Where the Upgrade button goes

The button must land on the plan page with the **price already resolved in the tenant's currency** — the server-computed sellable matrix from the existing deal-pricing work. An Upgrade button that opens a page showing USD to an INR tenant is a dead end in a different way.

---

## ⑦ MVP

### Must have — v1

| # | Item | Effort | Notes |
|---|---|---|---|
| 1 | Seed `PlanQuota` rows for **every** plan × **every** meter | 🟢 S | ⚠️ Blocks everything else. Missing row = 0 = blocked |
| 2 | `[MeteredResource]` on all real send commands (bulk + transactional) | 🟢 S | The allowance is decorative until this ships |
| 3 | `EMAILS_PLATFORM` meter + `SenderMode` column | 🟡 M | §① — cheap now, expensive later |
| 4 | Fail-closed resolver, delete the appsettings fallback | 🟡 M | Companion plan §⑨ |
| 5 | Provisioning seeds a `PLATFORM_SHARED` row *(or platform mail bypasses tenant resolution)* | 🟡 M | Companion plan **Q12 — blocking.** Without it every new tenant is bricked |
| 6 | Domain verification for the platform sender | 🔴 L | The abuse gate. Not optional |
| 7 | Suppression list, two-tier | 🟡 M | Non-negotiable for shared sending |
| 8 | Enforce L2 rate caps | 🟢 S | Columns exist; wire them |
| 9 | Usage display + hard cap + **upgrade prompt** on the config screens | 🟡 M | Zero new billing code — reuses `PlanQuotaExceededException`. Wording varies by tier — see Scenario 4 |
| 10 | `SMS_SEGMENTS` computed correctly (GSM-7 vs Unicode) | 🟢 S | Get the unit right from day one or every number is wrong |
| 11 | **80 % / 95 % usage warnings** — in-app banner + email to tenant admin | 🟢 S | ⚠️ **Promoted to Must-have by the upgrade-first decision.** For the overwhelming majority of tenants there is no pack to buy — packs are off by default — so hitting 100 % is a full stop mid-campaign. They must see it coming. Once per threshold per period; sent outside the metered path — see §⑥a |
| 12 | **Pre-flight quota check on the campaign screen** — *"this send will use N, you have M left"* **before** the send button | 🟢 S | ⚠️ **§⑥a problem 1.** A bulk send is all-or-nothing: 5,000 recipients with 4,000 left sends **zero**. Without this they discover it as a 500 error mid-appeal |
| 13 | **Period wording = "resets on {CurrentPeriodEnd}"** everywhere, never "this month" | 🟢 S | §⑥a problem 2 — the period is the billing anniversary, not the calendar month |
| 14 | **Distinguish "no live subscription" from "limit reached"** in the block message | 🟢 S | §⑥a problem 5 — a lapsed trial currently reads as "quota exceeded" |

### Should have — v1.1

**S1–S5 are the platform-gated email packs**, in strict build order. S1 alone is safe to ship early: with the flag off everywhere, the feature is invisible and unreachable.

| # | Item | Effort |
|---|---|---|
| **S1** | **`ADDON:EMAIL_PACKS` feature code + `PlanEntitlement` rows = 0 on every plan.** The gate | 🟢 S |
| **S2** | **`AddOnPackCatalog` / `AddOnPackPrices` / `CompanyAddOnPacks`** + the `+ packs` term in `GetLimitAsync` + FIFO consumption inside the counter transaction, under the existing advisory lock | 🔴 L |
| **S3** | **Platform screen:** enable/disable packs per tenant *(this is `SetSubscriptionOverride` + a toggle — reuse, do not rebuild)*, manage the SKU catalogue, grant a pack manually, list who has packs on and why | 🟡 M |
| **S4** | **Tenant screen:** buy a pack — rendered **only** when entitled. Reuses the existing gateway checkout + FX sellable-price path. Must call `Invalidate(companyId)` on success | 🟡 M |
| **S5** | **Pack balance in the usage panel and in the 80 % warning** — units left, expiry date, "base allowance is used first" | 🟢 S |
| S6 | Bounce/complaint auto-suspend | 🟡 M |
| S7 | Separate transactional and marketing streams | 🟡 M |
| S8 | Warm-up ramp for new shared-sender tenants | 🟡 M |
| S9 | Provider webhook ingestion for the 2-3 supported BYO API providers | 🔴 L |
| S10 | WhatsApp conversation-window metering | 🟡 M |
| S11 | Platform-side view: every tenant, mode, volume, bounce rate | 🟡 M |

### Future

| # | Item |
|---|---|
| F1 | Communication wallet for SMS/WhatsApp — only if you decide to resell |
| F2 | Metered overage invoicing, CUSTOM plans only |
| F3 | Dedicated IP pools / provider subaccounts above a volume threshold |
| F4 | Per-tenant deliverability dashboard with DMARC reporting |
| F5 | Packs for `SMS_SEGMENTS` / `WHATSAPP_CONVERSATIONS` — same tables, different meter. **Blocked on D2**: pointless while those channels are BYO-only |

---

## ⑧ Final recommendation

1. **Sell the plan on `EMAILS` — emails the platform processes, either mode.** Meter `EMAILS_PLATFORM` separately and quietly, to protect your provider bill and your reputation.
2. **Always offer both provider modes.** Platform sender is the default because it makes onboarding a single click; BYO exists because enterprise procurement and compliance teams will demand it, and refusing loses those deals.
3. **Charge the same either way.** They are buying the CRM, not the pipe. Optionally give BYO a larger `EMAILS` allowance — it is fair, it costs you nothing, and it is a good line in a sales conversation.
4. **Past the limit, upgrading the plan is the default route — and the only self-serve one.** ✅ Decided 2026-08-05. Add-on email packs exist as a **platform-granted seasonal exception**: off on every plan, switched on for one named tenant for a named reason (Diwali, Christmas, a disaster appeal), invisible when off. There is still no metered overage and no surprise invoice — nothing is ever auto-charged; every rupee is a deliberate click. The cost of that discipline is that the plan numbers must carry real headroom, the top tier must route to "Contact us" rather than a dead Upgrade button, and 80 %/95 % warnings become mandatory.
5. **Do not bundle SMS or WhatsApp as unit quotas.** Cost varies too much by country. Either BYO-only (simple, safe, recommended for v1) or a money wallet (correct, more work). Bundling units is the one option that is wrong everywhere.
6. **"Unlimited" already works in your schema** (`LimitValue` NULL). Keep it off the self-serve price card; use "volume by agreement" on CUSTOM and set a real number per contract.
7. **Deliverability is the existential risk, not billing.** Domain verification, two-tier suppression and bounce auto-suspend must ship *with* the shared sender, never after.
8. **Meter *and feature* codes are effectively one-way doors.** A missing `PlanQuota` row is a hard block; a missing `PlanEntitlement` row likewise resolves to deny. So every new code — including the boolean `ADDON:EMAIL_PACKS` — ships with a row for **every** plan in the **same** release. Decide the full meter set now — §④ — and seed it once.

**What is genuinely good already:** the three-gate design, `LimitValue` NULL = unlimited, post-success FLOW increment, bulk unit counting, live trial-expiry evaluation, and the `PlanQuota` / `PlanEntitlement` separation. The foundation is sound. What is missing is coverage, commerce and deliverability — not architecture.

---

## ⑨ Decisions still owed

| # | Question | Blocks |
|---|---|---|
| **D1** | The numbers: `EMAILS`, `EMAILS_PLATFORM`, `SMS_SEGMENTS`, `WHATSAPP_CONVERSATIONS`, `PUSH` per plan | ⚠️ **The seed. Nothing in §⑦ can ship without these.** Now higher-stakes: packs are off by default, so a tenant who runs out has only one route — upgrade, and pay more *every* month thereafter. Size for a **peak** month, not an average one |

### ✅ Decided by the project manager, 2026-08-05

*User: "you can decide buddy — as a project manager." These are settled. Reopen only with a reason.*

| # | Decision | Rationale |
|---|---|---|
| **D1b** | **PLAN_100K upgrades to CUSTOM**, sold by conversation, the agreed number written into the contract and applied as one `SubscriptionOverride` row (`MeterCode = EMAILS`, `OverrideValue = n`, `Note` = contract ref). Top-tier button says **"Contact us"**, never "Upgrade" | The mechanism is already built. A top plan whose Upgrade button leads nowhere is worse than no button |
| **D1c** | **No proration in v1.** A mid-period upgrade starts a fresh billing period and a fresh allowance; the tenant pays a full cycle. The upgrade screen states this in one plain sentence before they confirm | Proration is a genuine billing sub-system. The current behaviour is *generous* — they also get a full new allowance — so it is defensible as long as it is disclosed |
| **D1d** | **No credit-back on bounces.** The meter counts attempted sends. One line in the T&Cs and a usage-panel tooltip | The send cost us money either way, and it gives the tenant a direct incentive to keep lists clean — which §⑤ needs anyway |
| **D1e** | **Block the whole batch.** A campaign that exceeds the remaining allowance sends **zero**, with a pre-flight warning before the button | A donor appeal that silently reaches 4,000 of 5,000 people is a worse failure than one that does not send. Partial sends are unrecoverable — you cannot tell who got it |
| **D9** | **Pack validity = 90 days** from purchase, no rollover, no refund, FIFO by earliest expiry | Covers a full festival season across billing boundaries without becoming a wallet |
| **D10** | **Packs are never self-serve.** Off by default on every plan; enabled per tenant by the platform, with a reason in the override `Note`; hidden entirely when off — not greyed out | This is the whole point of the user's refinement. A visible-but-locked button makes every exception public |
| **D11** | **Pack SKUs mirror `PlanPrices`** — per-currency rows through the existing FX sellable-price path, not a single USD number | Same currency discipline the plan catalogue already enforces |
| **D2** | SMS/WhatsApp — BYO-only, or do we resell via a wallet? | The whole SMS/WhatsApp billing layer |
| **D3** | Which countries are you selling into? | Per-country registration, DND registry, sender-ID legality, SMS rate cards |
| **D4** | Which BYO providers at MVP? (recommend SMTP + SendGrid + one) | Webhook ingestion scope |
| **D5** | Companion plan **Q12** — how does provisioning send the welcome email under fail-closed? | New-tenant onboarding. **Hard blocker** |
| **D6** | Companion plan **Q13** — cutover for existing tenants on the global key | Fail-closed release |
| **D7** | Is BYO itself a paid/plan-gated feature? *(recommend: no — available on all paid plans)* | Plan matrix |
| **D8** | **Add-on pack SKU sizes and per-currency prices.** ♻️ **Reopened 2026-08-05** — packs are back as a platform-granted seasonal exception. Recommend three SKUs only: `EMAIL_10K`, `EMAIL_25K`, `EMAIL_50K`. Needs a price row per sellable currency (D11 — same FX path as `PlanPrices`) | Blocks **S2/S3/S4**, not v1. Price these *above* the per-email rate implied by the plans, or a pack becomes cheaper than upgrading and the default route dies |

---

## ⑩ Change log

| Date | By | Change |
|---|---|---|
| 2026-08-05 | agent | Created. All §⓪ rows verified against `PlanQuota.cs`, `UsageCounter.cs`, `QuotaBehavior.cs`, `EntitlementService.cs`, `BillingCodes.cs`. Nothing built. |
| 2026-08-05 | agent | Added **§②a** — custom-domain rule verified against Zoho CRM, Freshdesk, Zendesk, HubSpot, Salesforce Marketing Cloud, SendGrid and Mailgun docs. User's rule (custom domain only in platform-sender mode) **confirmed correct and universal**. Added the bulk-over-BYO-SMTP block rule (Zoho pattern) and the "no false green tick in OWN mode" constraint. Nothing built. |
| 2026-08-05 | agent | **DECISION — plan upgrade only, no packs.** User: *"we can give plan upgrade - we can avoid the packs upgrade."* Rewrote Scenario 4; **cancelled `billing.UsageAddOns`** (§⑥) so `GetLimitAsync` needs no change at all; **promoted 80 %/95 % usage warnings to Must-have** (§⑦ item 11) since there is no longer a safety valve; added tier-aware over-limit wording; raised the stakes on **D1** (size for peak, not average) and opened **D1b** (what does the top plan upgrade to?); closed **D8**. Nothing built. |
| 2026-08-05 | agent | Added **§⑥a — upgrade mechanics**, the gap the no-packs decision opened. Verified on disk: `AssignSubscription.cs:174-196` (plan change cancels + re-inserts with `CurrentPeriodStart = now`, so **an upgrade resets the FLOW counter and unblocks instantly — zero new code**), `SubscriptionOverride.cs` + `SetSubscriptionOverride.cs` (**the "Contact us" limit raise is already built** — `override ?? plan`), `UsageMeterService.cs:98-117` (period = billing anniversary, **not** calendar month). Documented six problems: all-or-nothing bulk sends, anniversary wording, counter reset on any plan change + no proration, no credit-back on bounces + retry double-count risk, lapsed trial showing the wrong message, STOCK grandfathering on downgrade. Added §⑦ items **12-14**, decisions **D1c/D1d/D1e**, and the warning idempotency/recipient/delivery rules for item 11. Nothing built. |
| 2026-08-05 | agent | **DECISION — packs reinstated as a platform-gated seasonal exception** (supersedes the "no packs" row above; **upgrade stays the default and the only self-serve route**). User: *"this packs should work based on plat for enable the email packs for this tenant means we need to show that option - then they can purpose like diwali or christmas time period."* Rewrote **Scenario 4** (option **E** added and chosen alongside **D**); over-limit message table expanded to six tier × entitlement rows with the rule *never render a disabled Buy-pack button*; quota resolution becomes `(override ?? plan) + packs`, unlimited stays unlimited. The gate is **zero new code** — a boolean `ADDON:EMAIL_PACKS` seeded to **0 on every plan**, flipped per tenant by the already-built `SetSubscriptionOverrideCommand` with the reason in `Note`, surfaced by the already-built `GetMyEntitlements`. Reinstated **§⑥** with three tables (`AddOnPackCatalog`, `AddOnPackPrices`, `CompanyAddOnPacks`) — **consumption-tracked, not period-bound**, because the FLOW counter resets each period and would otherwise re-grant the pack in full every time; FIFO by earliest `ValidUntil`, debited in the same transaction as the counter increment under the existing advisory lock, `GetLimitAsync` filtering on `ValidUntil` and never trusting `Status`. §⑦ Should-have renumbered **S1–S11** (packs = S1–S5, in build order) and Future **F1–F5**. As acting PM, settled **D1b** (top tier → CUSTOM via one override; button says *Contact us*), **D1c** (no proration in v1), **D1d** (no credit-back on bounces), **D1e** (block the whole batch), **D9** (90-day validity, no rollover, no refund), **D10** (never self-serve; off by default; reason recorded), **D11** (pack SKUs priced per currency through the existing FX sellable path). **Reopened D8** (SKU sizes + prices). Nothing built. |
| 2026-08-05 | agent | **§⑦ Must-have (items 1–14) turned into a runnable build prompt: `PSS-2.0-COMMUNICATION-METERING-BUILD-PROMPT.md`.** Verification pass against the code found the fact that decides the whole build: **the bulk email path never passes through MediatR.** `CreateEmailSendJob.cs:139/147/158` (and `UpdateEmailSendJob.cs:141/160/180`) hand off to Hangfire, and `EmailExecutorService` / `EmailSenderService` are plain injected services — so `QuotaBehavior`, an `IPipelineBehavior`, can never see them. Annotating `CreateEmailSendJobCommand` with `[MeteredResource]` would compile, review clean and meter nothing. The prompt therefore places a **pre-flight block** inside `EmailExecutorService.ProcessBulkEmailJobAsync` at `:224` where `bulkData.TotalRecipients` is known, and the **increment** inside `EmailSenderService.SendQueuedEmailAsync` from `result.TotalSuccess` — block on intent, count on delivery. Also found: **no ownership discriminator on `CompanyEmailProvider`**, so `EMAILS_PLATFORM` is uncomputable → one additive column `IsPlatformProvider` (the build's only schema change), and `EmailSendJob.IsSystem` already exists as the transactional-mail exemption. Confirmed the full `[MeteredResource]` census is **four commands product-wide**, only `SendTestEmail.cs:11` for email. Prompt states the D1 numbers as an explicit assumption (§⑨ Q1) that changes one seed file and no code. Packs (S1–S5), SMS/WhatsApp enforcement, provider rate caps (L2), suspension (L3), overage/wallets all explicitly out of scope. Nothing built. |
| 2026-08-05 | agent | **Second build prompt written: `PSS-2.0-BULK-EMAIL-JOB-RELIABILITY-BUILD-PROMPT.md`** — the job pipeline itself, deliberately separate from metering and marked *depends on the metering prompt being executed first* (both edit `EmailExecutorService.cs` and `EmailSenderService.cs`; metering is the smaller diff). Verification pass found ten defects, led by one that changes the risk profile of the metering build: **neither `ProcessBulkEmailJobAsync` nor `SendQueuedEmailAsync` carries `[AutomaticRetry(Attempts = 0)]`, while ten other Hangfire jobs across the codebase do** (`OnlineDonationMapJobRunner.cs:35` *"never let Hangfire silently re-run"*, `SubscriptionRenewalService.cs:54` *"never silently re-charge"*, `ImportExecutionService.cs:55`, `EventCommunicationDispatcher.cs:62`, …). Hangfire’s default is 10 attempts and step 2 has **no idempotency guard**, so a throwing campaign re-queues and re-sends up to ten times — and once metering ships, burns quota ten times over. Also verified: retry columns `RetryCount`/`MaxRetryAttempts`/`NextRetryAt`/`LastRetryAt` are written **once** at `EmailExecutorService.cs:302-303` and never read (nothing retries); `EmailSenderService.cs:106-107` reports **COMPLETED when 1 of 5,000 sent**; the queuing-phase status write is commented out at `:335-340`; `ToggleEmailSendJobStatus` flips `IsActive` and never touches Hangfire, so a “paused” recurring job keeps firing (`DeleteEmailSendJob.cs:59-64` does it correctly — the pattern to copy); there is no cancel-in-flight; the fallback provider is fetched then discarded at `:176-185`; `batchNumber` is initialised to 1 at `:275` and never incremented, so batching is vestigial (left as is, out of scope). `CANCELLED`, `PAUSED` and every retry column **already exist** — the build adds one master-data code (`PARTIAL`) and **no migration**. Metering, L2 provider rate caps, L3 suspension, soft-bounce webhooks, warm-up ramps and packs all explicitly out of scope. Nothing built. |
