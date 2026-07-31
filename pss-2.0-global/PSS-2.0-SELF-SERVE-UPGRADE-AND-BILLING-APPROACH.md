# PSS 2.0 — Tenant self-serve upgrade & subscription payments

**Status:** approach / plan. Nothing here is built yet.
**Date:** 2026-07-30
**Depends on:** T-A17 (plan catalog + subscription assignment), T-A18 (entitlement & quota enforcement)
**Related:** `PSS-2.0-PLANS-AND-ENTITLEMENTS-APPROACH.md`, `PSS-2.0-GTM-LEAD-ONBOARDING-AND-PRODUCT-ADMIN-APPROACH.md`

---

## ① The placement question — answer first

> *"currently the subscription & plan comes from company setting menu screen as one settings record — we can keep this same structure or else we can move separate menu"*

**Recommendation: promote it out of Company Settings into its own top-level tenant menu item — "Billing & Plan".**

Not a style preference. Four concrete reasons, in order of weight:

1. **It must stay reachable when everything else is locked.** The whole point of trial expiry
   (`EntitlementService` returns an empty feature map once `TrialEndsOn < UtcNow`) and of T-A18's
   module hiding is that an unpaid tenant loses modules. If Billing lives *inside* Company Settings,
   it inherits Settings' entitlement/capability gating — the one screen a lapsed tenant needs is
   behind the gate that lapsing closed. A dedicated route can be explicitly exempted from
   `FeatureEntitlementBehavior` and from menu hiding. This alone decides it.

2. **The 402/403 dialogs need a deep link.** T-A18 raises `PLAN_QUOTA_EXCEEDED` /
   `PLAN_FEATURE_NOT_ENTITLED` from anywhere in the app, and `upgrade-cta.tsx` currently degrades to
   *"Contact your account manager"* because there is nowhere to send them. `/billing/plans?from=CONTACTS`
   is a real destination; "Settings → scroll to the Subscription section" is not.

3. **Different job, different shape.** Settings screens are save-a-form surfaces (load → edit →
   diff-only PATCH). Billing is transactional and largely read-only history: pick a plan → pay →
   receipt → invoice list → payment method. A checkout does not belong in a settings tab.

4. **Different authority.** Settings-admin and billing-admin are not the same person in a real
   charity — the ops manager configures receipt numbering, the trustee/finance lead authorises
   spend. Splitting the surface lets a distinct `BILLING_MANAGE` capability gate the money, while
   Settings keeps `COMPANYSETTINGS_*`. Today `useEntitlements().isBillingAdmin` is a
   BUSINESSADMIN-only self-gate — that becomes a real capability.

**What happens to what exists:**

| Today | After |
| --- | --- |
| `setting/orgsettings/companysettings/sections/subscription-section.tsx` (66 lines, renders `PlanUsagePanel`) | Deleted from Settings. Settings keeps at most a one-line read-only summary linking to `/billing`. |
| `plan/plan-usage-panel.tsx` (306 lines) | **Kept verbatim** — it already resolves its own data from `myEntitlements` and needs no props. It becomes the top card of the Billing overview. |
| `plan/upgrade-cta.tsx` + `NEXT_PUBLIC_UPGRADE_CONTACT` | `href` flips from the env-var contact to `/billing/plans`. Env var retained as the fallback for a deployment with self-serve switched off. |
| `plan-enforcement-provider.tsx` 402/403 dialogs | Primary button becomes "View plans" → `/billing/plans`. |

**Route/menu shape** (mirrors how `(core)` groups already work):

```
/[lang]/(core)/billing/                 → overview: current plan, usage (PlanUsagePanel), next charge, trial banner
/[lang]/(core)/billing/plans            → plan comparison + "Choose plan" (the self-serve upgrade screen)
/[lang]/(core)/billing/checkout/[id]    → gateway hand-off / drop-in
/[lang]/(core)/billing/invoices         → invoice + payment history, PDF download
/[lang]/(core)/billing/payment-methods  → saved mandate / card on file
```

New module + capabilities seed: `BILLING` module, `BILLING_VIEW` / `BILLING_MANAGE`, granted to
BUSINESSADMIN by default. **Both must be exempt from entitlement gating** — add an allow-list to
`FeatureEntitlementBehavior` rather than relying on the module map.

### ①b Self-serve is switchable — the menu exists either way

The Billing menu is **not** conditional on self-serve. Every tenant sees their plan, usage, invoices
and payment history; what the switch controls is whether the "Choose plan" button is a checkout or a
"contact us". Three cases make this non-optional:

- **Invoice-billed tenants.** A negotiated CUSTOM-plan charity paying by bank transfer must never be
  offered "Pay now" — that is a double-billing incident, not a UX wrinkle.
- **Kill switch.** Gateway outage, bad merchant config, a wrong price in the catalogue — checkout has
  to stop in seconds, without a deploy.
- **Staged rollout.** Self-serve goes live for INR before the rest of the world. That should be a
  config change, not a branch.

**Most of the eligibility is derived, so only one stored flag is genuinely new:**

```
canSelfServe(company, targetPlan) =
      ops setting  SELF_SERVE_UPGRADE_ENABLED   -- platform kill switch, default TRUE
  AND (Company.AllowSelfServeUpgrade ?? true)   -- ONE nullable bool column; null = inherit platform
  AND targetPlan.PlanCode <> 'CUSTOM'           -- negotiated plans are never self-purchasable
  AND a platform gateway supports the subscription's billing currency   -- §④ resolver
```

Storage cost: one `ops.PlatformSettings`-style row plus one nullable column on `app.Companies`.
Nullable-with-inherit rather than `NOT NULL DEFAULT true` so "this tenant was deliberately excluded"
stays distinguishable from "nobody has thought about this tenant" — the same reason the platform
switch can't be expressed as a per-tenant default.

**Both surfaces enforce it:**
- FE — `GetMyBillingOverviewQuery` returns `canSelfServe` + a `selfServeBlockedReason` enum
  (`PLATFORM_DISABLED` / `TENANT_DISABLED` / `CUSTOM_PLAN` / `NO_GATEWAY_FOR_CURRENCY`). The read-only
  render path already exists: `upgrade-cta.tsx`'s "no target configured → show guidance text instead
  of a dead link" branch is exactly this mode, so it costs almost nothing.
- BE — `InitiateSubscriptionCheckoutCommand` re-evaluates the same predicate and throws
  `BadRequestException`. A hidden button is not a control.

Ops UI: a toggle on the tenant detail page next to the Subscription panel, audited as
`SELF_SERVE_TOGGLED`. Roughly half a day inside MVP-1 — build it with the rest, not as a later phase.

---

## ② What already exists (reuse inventory)

Materially more than expected. The self-serve build is mostly *wiring*, not new payment engineering.

| Capability | Where | Reusable for platform billing? |
| --- | --- | --- |
| Gateway provider abstraction incl. **recurring**: `CreateSubscriptionAsync` / `CancelSubscriptionAsync` / `RetrySubscriptionChargeAsync` / `UpdateSubscriptionAmountAsync` / `VaultPaymentMethodAsync` | `Base.Support/Payment/Providers/Abstractions/IPaymentGatewayProvider.cs` | **Yes, as-is.** The mandate lifecycle we need is already the interface. |
| Providers: Braintree, Razorpay, PayU India | `Base.Support/Payment/Providers/*` | Yes. Currency support drives which one is used (see §④). |
| `IPaymentService` + `IPaymentGatewayFactory` | `Base.Support/Payment/Services`, `/Factories` | **Yes, as-is — the key finding.** Every method takes `PaymentGatewayConfiguration` as a *parameter*, so both are already stateless and tenant-agnostic. Two methods are missing (§④a.2); the factory's gateway switch is hardcoded (§④a.1). |
| Tenant-bound entry point | `Base.API/PaymentFlow/PaymentFlowService.cs` | **No.** `BuildConfig` decrypts via `DecryptForCompany(…, gw.CompanyId)` and `BuildProviderFor` re-implements the factory switch inline. This is the one piece platform billing must not reuse — hence §④a. |
| Webhook receive + signature validation + logging | `Base.API/Controller/PaymentWebhookController.cs`, `PaymentWebhookProcessor` | Pattern yes; **routes no** — every route today is `/{companyCode}` and resolves a *tenant's* gateway. |
| Config decryption per company | `PaymentFlowService.BuildConfig` via `IEncryptionService.DecryptForCompany` | Pattern yes; needs a platform-scoped sibling. |
| Plan catalog, price book, FX-derived fallback pricing | `IPlanPricingService.ResolveAsync` | **Yes** — and it already does more than expected: the FREE → BOOK → FX → null ladder is built and the `Source` discriminator is already returned. It needs a gate, an uplift and a rounding rule, not a rewrite. See §③b. |
| Subscription lifecycle + filtered-unique-safe transition | `AssignSubscription.cs`, `ChangeSubscriptionStatus.cs` | Logic yes; **authorization no** — both are `[CustomAuthorize("PLATFORM_PLANS","PLATFORM_PLAN_EDIT")]`. See §⑤. |
| One-trial-per-company guard | `AssignSubscription.cs` (built 2026-07-30) | Yes — this is precisely the rule that stops a tenant farming free windows once they can drive the flow themselves. |
| Entitlement cache invalidation | `IEntitlementService.Invalidate(companyId)` | Yes — must fire the moment a payment confirms, not on the next 60 s TTL. |

**The critical distinction:** `fund.CompanyPaymentGateways` is the *tenant's* gateway — how a charity
collects donations from its donors. Platform billing is the opposite direction: how **we** collect
from the charity. It must never resolve through a tenant's merchant account. Same architectural split
we already made for `ops.PlatformCommunicationProviders`.

---

## ③ New schema (all user-owned migrations)

Five additions. Nothing existing is altered except two nullable columns on `billing.Subscriptions`.

**1. `ops.PlatformPaymentGateways`** — the platform's own merchant config. Mirrors
`ops.PlatformCommunicationProviders`: no `CompanyId`, one active row per gateway code.

```
PlatformPaymentGatewayId  int PK
PaymentGatewayId          int FK → shared.PaymentGateways   (reuse the existing gateway master)
GatewayEnvironment        text  'sandbox' | 'production'
EncryptedApiKey           text
EncryptedApiSecret        text
EncryptedWebhookSecret    text null
MerchantId                text null
SupportedCurrencies       text null   -- JSON array of ISO codes  e.g. ["INR"] / ["USD","GBP","EUR",...]
SupportedCountryCodes     text null   -- JSON array, null = any
SupportedPaymentMethods   text null   -- JSON array  e.g. ["CARD","UPI","NETBANKING"] / ["CARD","PAYPAL"]
SupportsRecurring         bool        -- has a mandate/subscription product, not just one-off charges
Priority                  int         -- lower wins; the resolver's tie-break and failover order
AdditionalConfig          text null
IsDefault                 bool
+ Entity audit columns
```

These four capability columns are what make §④ a **declarative matrix** rather than a hardcoded
currency→gateway map. Adding a EUR-specific acquirer later is then a seed row, not a code change.

**2. `billing.Invoices`** — what the tenant owes / owed. Not optional: a paying customer is legally
entitled to an invoice, and GST/VAT numbering cannot be derived retroactively.

```
InvoiceId, CompanyId, SubscriptionId, InvoiceNumber (unique per company — use NumberSequenceGenerator),
Status ('Draft','Issued','Paid','Failed','Void','Refunded'),
PeriodStart, PeriodEnd, IssuedOn, DueOn, PaidOn,
Subtotal, TaxAmount, TotalAmount, CurrencyId,
PlanCode, BillingCycle,        -- snapshot, same discipline as Subscription
Notes
```

**3. `billing.InvoiceLines`** — `InvoiceLineId, InvoiceId, Description, Quantity, UnitAmount, LineTotal, TaxRate`.
One line in MVP (the plan), but tax and any future add-on need the table to exist from day one.

**4. `billing.SubscriptionPayments`** — the gateway attempt log. Separate from `Invoices` because one
invoice can have several attempts (fail → retry → succeed).

```
SubscriptionPaymentId, CompanyId, SubscriptionId, InvoiceId null,
PlatformPaymentGatewayId null,  -- NULL for an offline payment (§④c). Not every payment has a gateway.
Method,                         -- 'GATEWAY' | 'BANK_TRANSFER' | 'CHEQUE' | 'CASH' | 'ADJUSTMENT' | 'COMPLIMENTARY'
GatewayTransactionId, GatewayReference,
Reference null, Note null,      -- UTR / cheque no. / why it was comped — §④c requires one of them
Amount, CurrencyId, Status ('Initiated','Pending','Succeeded','Failed','Refunded'),
FailureCode, FailureMessage, AttemptedOn, CompletedOn, RecordedByUserId null,
IdempotencyKey null UNIQUE      -- §④ idempotency; NULL for hand-entered payments (Postgres UNIQUE
                                -- treats NULLs as distinct, so many offline rows coexist happily)
RawResponse                     -- redacted; never store PAN/CVV
```

**5. `billing.TenantPaymentMethods`** — the vaulted mandate. **No card data ever touches our DB**;
this stores the gateway's token plus display-safe crumbs.

```
TenantPaymentMethodId, CompanyId, PlatformPaymentGatewayId,
GatewayCustomerId, GatewayToken, MethodType ('card','upi','netbanking','mandate'),
Brand, Last4, ExpiryMonth, ExpiryYear, IsDefault, MandateStatus, MandateExpiresOn
```

**Plus five columns on `billing.Subscriptions`:**

```
GatewaySubscriptionId  text null   -- gateway-side recurring subscription, when the gateway owns the schedule
AutoRenew              bool not null default true
PriceSource            text null   -- 'FREE' | 'BOOK' | 'FX' — how the snapshotted Amount was arrived at (§③b)
FxRateUsed             numeric null -- the rate VALUE, never an FK. Non-null only when PriceSource = 'FX'
FxRateDate             date null    -- the RateDate that rate came from
```

The last three exist so "why is this customer paying $59?" is answerable in one query rather than by
archaeology. They are the snapshot discipline extended to the *derivation*, not just the result.

PCI scope stays at the gateway iframe/drop-in — same rule already recorded for the public donation
pages.

---

## ③b Pricing resolution — configured price wins, FX fills the gaps

**Settled 2026-07-30.** Three options were on the table: (a) a hand-set price per currency, (b) every
price FX-derived from the INR anchor, (c) a switch between them. **(c) — but shaped as a fallback with
a hard precedence rule, not as a mode.**

The distinction matters. A *mode* means "this month we bill by FX" and a hand-set USD price can be
silently overridden by the currency market. A *fallback* means a configured price always wins and FX
only answers for currencies nobody has priced yet. Only the second is safe.

### The resolution ladder — already built

`Base.Infrastructure/Services/Billing/PlanPricingService.cs` already implements exactly this order:

```
1. plan.Price <= 0                          → Amount 0        Source = 'FREE'    (sellable everywhere)
2. billing.PlanPrices row for
   (PlanId, CurrencyId, BillingCycle)       → that amount     Source = 'BOOK'    ← a hand-set price ALWAYS wins
3. FX-derive from the plan's base price      → converted      Source = 'FX'      ← the fallback
4. neither                                   → null           → "Contact us"     (fail-closed)
```

Two consequences worth stating plainly, because they change the shape of the work:

- **FX-derived pricing is not a feature to build — it is a feature to *gate*.** Step 3 is live today
  and unconditional. What the toggle adds is the ability to turn it *off*.
- The ladder's precedence is already correct. `BOOK` is checked before `FX`, so a curated price can
  never be overridden by a rate. That property must be preserved, not introduced.

### What is actually missing

**1. The switch.** Same home as `SELF_SERVE_UPGRADE_ENABLED` (§①b) — a platform-level ops setting,
not a per-tenant one, because a price policy that varies by tenant is not a policy.

```
FX_DERIVED_PRICING_ENABLED   bool     -- OFF ⇒ step 3 is skipped entirely; an unpriced currency
                                      --       falls straight through to null ⇒ "Contact us"
FX_PRICING_UPLIFT_PERCENT    decimal  -- applied to the converted amount before rounding. Default 20
FX_PRICING_ROUNDING          text     -- 'NONE' | 'NEAREST_10' | 'ENDING_9' | 'ENDING_99'. Default ENDING_9
```

**2. The uplift.** Today step 3 converts at the raw rate. That sells internationally at the Indian
margin *minus* FX spread, minus higher card fees on foreign acquiring, minus the cost of supporting a
timezone we do not work in. A raw conversion is not a price; it is a currency translation of a price
set for a different market.

**3. The rounding.** Today: `Math.Round(plan.Price * rate, 2)` → the invoice reads **$50.37**. Round
**up** to a real price point — $50.37 → $59 under `ENDING_9`. Rounding *down* is a discount nobody
approved, so the rule is always ceiling-to-the-next-point, never nearest.

### Two constraints that bound how far this can reach

- **Direct-pair only.** `IFxRateService` is strict `(From, To, RateDate)` with no inverse and no USD
  triangulation — a locked project decision. So INR→GBP resolves only if an admin has curated that
  exact pair. The toggle does not unlock "every currency"; it unlocks "every currency someone entered a
  direct rate for." Everything else still lands on "Contact us", which is the correct outcome.
- **The rate is snapshotted, never re-derived.** `AssignSubscription` already writes the resolved
  `Amount` onto the subscription and never rewrites it, so a tenant who signs up at $59 pays $59 every
  period — the invoice does not drift with the market. This is the single property that makes FX-derived
  pricing acceptable at all, and it is already the discipline. Renewals must not call `ResolveAsync`
  again; a price change is a deliberate act (a re-assignment), not a market event.

### Launch configuration

| Setting | Launch value | Why |
| --- | --- | --- |
| INR prices | hand-set (`BOOK`) | The home market. Already seeded. |
| USD prices | **hand-set (`BOOK`) — still needed** | Set on its own merits, not by dividing ₹4,199 by a rate. See the §⑨ blocker. |
| `FX_DERIVED_PRICING_ENABLED` | **false** | Note this is a *change* from today's always-on behaviour. |
| `FX_PRICING_UPLIFT_PERCENT` | 20 | Configured but idle while the switch is off. |
| `FX_PRICING_ROUNDING` | `ENDING_9` | Configured but idle while the switch is off. |

Defaulting the switch **off** at launch is deliberate. We do not yet know what an international buyer
pays. Letting the first handful of foreign enquiries hit "Contact us" forces an ops conversation, and
five of those conversations teach the real USD/GBP price far better than a conversion would. Flip it on
once that is known — at which point it becomes what it should be: a sensible floor for markets too
small to price by hand.

---

## ④ Payment integration design

### ④a A separate ops payment service — but not a separate payment stack

Platform billing gets its **own service**, because the existing entry point is hard-bound to tenants:
`PaymentFlowService.BuildConfig(CompanyPaymentGateway)` decrypts with
`IEncryptionService.DecryptForCompany(cipher, gw.CompanyId)`, and `BuildProviderFor` duplicates the
factory switch inline. Neither can express "no company owns this account".

What it must **not** do is fork the payment stack. `IPaymentService` and `IPaymentGatewayFactory` are
already stateless and tenant-agnostic — every method takes a `PaymentGatewayConfiguration` as a
*parameter*, so they neither know nor care whose merchant account it is:

```csharp
IPaymentGatewayProvider CreateProvider(PaymentGatewayConfiguration configuration);
Task<SubscriptionResult> CreateSubscriptionAsync(PaymentGatewayConfiguration config, SubscriptionRequest request, CancellationToken ct = default);
```

So the new service is thin, and the Braintree/Razorpay/PayU providers stay single-sourced — a provider
fix lands for donations and platform billing at once:

```
IPlatformBillingPaymentService              (new, Base.Application + Base.API)
  ├─ resolve   ops.PlatformPaymentGateways  by currency  (§④b resolver)
  ├─ decrypt   with a PLATFORM key, not DecryptForCompany
  ├─ build     PaymentGatewayConfiguration
  └─ delegate  to the EXISTING IPaymentService / IPaymentGatewayFactory / providers   ← unchanged
```

**Two concrete gaps to close in the shared stack:**
1. `PaymentGatewayFactory` dispatches on a hardcoded switch (`"BRAINTREE"`, `"RAZORPAY"`, `"PAYU"`,
   else `NotSupportedException`). A new gateway is therefore a seed row **plus** one case. Acceptable —
   a new gateway needs a provider class anyway — but it means the matrix in §④b cannot introduce a
   gateway on its own. Do not "fix" this with reflection; the explicit switch is the honest form.
2. `IPaymentService` omits `RetrySubscriptionChargeAsync` and `UpdateSubscriptionAmountAsync` — both
   exist on `IPaymentGatewayProvider` but were never lifted to the service. The dunning ladder needs
   the first; mid-term plan changes need the second. Lift both.

### ④b Gateway selection — capability matrix, not a hardcoded map

The tenant's billing currency is already fixed on the subscription (`Subscription.CurrencyId`, from
the deal wizard — deliberately independent of the tenant's *operating* currency). At checkout:

1. Resolve price via `IPlanPricingService.ResolveAsync(planCode, currencyId, billingCycle)`. A null
   result is a hard stop — never invent a rate, never fall back to the plan's base currency. Same
   rule as `AssignSubscription`.
2. Resolve the gateway by **matching capabilities, ordered by `Priority`**:
   `IsActive` ∧ `SupportedCurrencies ∋ currencyCode` ∧ (`SupportedCountryCodes` null ∨ ∋ country) ∧
   (`SupportsRecurring` if the plan is recurring). First match wins; the next match is the failover if
   the first errors at hand-off. `IsDefault` breaks a `Priority` tie.
3. No supporting gateway ⇒ `selfServeBlockedReason = NO_GATEWAY_FOR_CURRENCY`, the plan card renders
   "Contact us" instead of "Choose plan". A checkout that can't complete must never be *offered*.

**Seeded config: INR → Razorpay, everything else → Braintree.** This split is technically forced, not
a preference — India domestic recurring runs under the RBI e-mandate framework (mandate registration
with additional-factor auth, pre-debit notification ahead of each auto-debit, AFA again above the
per-transaction ceiling). Razorpay Subscriptions implements that; Braintree has no INR domestic
acquiring or eMandate product, so it cannot serve Indian recurring at all. *Confirm the current AFA
ceiling with Razorpay before building the dunning ladder — RBI has revised it more than once.*

**Alternatives considered:**

| Option | Verdict |
| --- | --- |
| Hardcode `INR→Razorpay, else Braintree` in C# | Works today; adding PayU or a EUR acquirer becomes a code change + deploy. Rejected — the matrix is the same effort. |
| **Capability matrix (above)** | **Chosen.** Superset of the hardcoded map, gives failover and per-currency sandbox/prod independence for free. |
| Gateway orchestrator (Spreedly, Primer) | Overkill at two gateways; adds a vendor between us and the money. |
| Merchant-of-record (Paddle, Lemon Squeezy, FastSpring) | Genuinely removes global VAT/GST registration — the right answer for a US/EU-first SaaS, and it would delete the tax problem in §⑦. **Rejected for launch:** ~5% of revenue and weak INR-domestic support, and India is the first market. Revisit if international revenue outgrows Indian. |

### ④c Offline / manual payment — the ops-side direct upgrade

Rare but real: a known client wires the money or deposits it at the bank, or the tenant is a relative
and the plan is granted outright. **The upgrade itself already works** — `AssignSubscription` is
`[CustomAuthorize("PLATFORM_PLANS","PLATFORM_PLAN_EDIT")]` and touches no payment code, so an ops
member can already put a tenant on a paid plan with no money moving. Nothing about self-serve changes
that, and it must stay that way: the gateway is *a* way to pay, never the only way to become paid.

What's missing is the **record**, and without it two things go wrong: the invoice sits unpaid forever,
and once dunning exists it chases a tenant who has already paid. So:

- **The upgrade requires no payment details at all.** `AssignSubscription` stays exactly as it is:
  zero required payment input. Recording the money is a **separate, later, optional** action, so an
  ops member is never blocked at 11pm because the UTR is on someone's desk.
- **`RecordOfflinePaymentCommand`** (platform-only) writes a `billing.SubscriptionPayments` row with
  `PlatformPaymentGatewayId = NULL`, `Status = 'Succeeded'`, `Method ∈ { BANK_TRANSFER, CHEQUE, CASH,
  ADJUSTMENT, COMPLIMENTARY }` and an `Amount`. Marks the linked invoice `Paid`.
  **Required: `Method` + `Amount`, nothing else.** `Reference` (UTR / cheque no.) is *prompted* for
  BANK_TRANSFER and CHEQUE but never enforced — a mandatory reference just produces `na` and `-` in
  the ledger, which is worse than an honest blank. The **one** exception: `COMPLIMENTARY` (or any
  zero amount) requires a `Note`. "Who got a free year, and why" is the question an auditor actually
  asks, and it is one sentence to answer.
- **An unrecorded payment leaves the invoice visibly `Issued`.** That is the correct state and a
  useful ops worklist — a silent fake payment is neither.
- ⇒ **`SubscriptionPayments.PlatformPaymentGatewayId` must be nullable** in §③, and
  `IdempotencyKey` nullable too (there is no client intent for a hand-entered payment).
- **`AutoRenew = false`** on offline-billed subscriptions. Renewal then raises an invoice and an ops
  reminder rather than attempting a charge on a mandate that doesn't exist.
- **Set `Company.AllowSelfServeUpgrade = false`** for these tenants (§①b) so they never see "Pay now"
  alongside an invoice they settle by transfer.
- Audit actions `OFFLINE_PAYMENT_RECORDED` / `SUBSCRIPTION_COMPLIMENTARY_GRANTED`. A free year granted
  to a relative is legitimate; a free year granted with no trace is not.

The complimentary case is genuinely just an offline payment of zero — resist inventing a parallel
"free grant" concept. One ledger, one set of invoices, one place to answer "what has this tenant paid".

**Two payment shapes, both already on the provider interface:**

- **Gateway-managed recurring (preferred).** `CreateSubscriptionAsync` → the gateway owns the
  schedule and dunning; we store `GatewaySubscriptionId` and react to webhooks. No renewal job to
  write, which matters because there is no scheduler for billing today.
- **Vault + charge (fallback, for gateways/methods without a mandate product).** `VaultPaymentMethodAsync`
  once, then a renewal job charges each period. Only build this if a target market forces it — it
  drags in the scheduler, retry ladder, and dunning we otherwise get free.

**Idempotency is mandatory, at three layers:**
- Client generates an `IdempotencyKey` per checkout intent; the UNIQUE index on
  `SubscriptionPayments.IdempotencyKey` makes a double-submit a no-op.
- The webhook handler keys on `GatewayTransactionId` — gateways redeliver, sometimes for days.
- The subscription transition itself already reads-then-writes under the filtered
  `UNIQUE(CompanyId) WHERE Status IN (Trial,Active,PastDue)` index, so a duplicate confirm cannot
  produce two live subscriptions. Take `pg_advisory_xact_lock(CompanyId)` around confirm, the same
  way the fund guard and quota TOCTOU check do.

**Webhook route:** `POST /api/webhooks/platform-billing/{gatewayCode}` — `[AllowAnonymous]`, signature
validated against `ops.PlatformPaymentGateways.EncryptedWebhookSecret`, every payload written to the
existing webhook log before processing. Deliberately **not** under the `/{companyCode}` routes: those
resolve a tenant merchant account and must not be reachable with platform credentials.

**The webhook is the source of truth, not the browser redirect.** The return URL only navigates; a
tenant that closes the tab mid-payment must still end up Active. Redirect shows "confirming…" and
polls the payment row.

---

## ⑤ Backend work

**Authorization is the sharp edge.** `AssignSubscriptionCommand` and `ChangeSubscriptionStatusCommand`
are `[CustomAuthorize("PLATFORM_PLANS","PLATFORM_PLAN_EDIT")]` — platform staff only. Do **not**
loosen them. Self-serve gets its own tenant-scoped commands where **`CompanyId` comes from the token,
never from an argument**; a tenant-supplied `companyId` on a billing mutation is a cross-tenant
billing forgery.

New, all `[CustomAuthorize("BILLING", "BILLING_MANAGE")]` unless noted:

| Command / Query | Purpose |
| --- | --- |
| `GetMyBillingOverviewQuery` *(BILLING_VIEW)* | Current plan, status, trial end, next charge date+amount, default payment method, last 3 invoices. One round-trip for the overview page. |
| `GetSellablePlansQuery` *(BILLING_VIEW)* | Catalog filtered to plans sellable in the tenant's billing currency, each flagged `isCurrent` / `isUpgrade` / `isDowngrade` / `requiresContact` (CUSTOM). |
| `InitiateSubscriptionCheckoutCommand` | Validates the target plan, resolves price + gateway, writes `SubscriptionPayments` row `Initiated` + `Invoices` row `Issued`, returns the client token / redirect payload. **Does not touch the subscription.** |
| `ConfirmSubscriptionPaymentCommand` | Called by the webhook (and by the poll fallback). Verifies with the gateway, marks payment `Succeeded` + invoice `Paid`, then performs the cancel-incumbent/insert-successor transition, then `entitlementService.Invalidate(companyId)`. |
| `SetAutoRenewCommand` | Tenant-controlled, both directions. **Off:** `AutoRenew = false` + `CancelSubscriptionAsync` at the gateway; access runs to `CurrentPeriodEnd`, then lapses — never an instant cutoff on a paid period. **On:** cancelling usually revoked the mandate, so this is a fresh `CreateSubscriptionAsync`, not a flag flip — it returns a checkout payload and the UI must say "re-enable and confirm payment method". Refused with `BadRequestException` when the subscription has no `GatewaySubscriptionId` (offline-billed, §④c). |
| `SavePlatformPaymentGatewayCommand` *(PLATFORM_*)* | Control-plane CRUD for §③.1, incl. the capability columns the §④b resolver reads. |
| `RecordOfflinePaymentCommand` *(PLATFORM_*)* | §④c. Logs a bank transfer / cheque / cash / complimentary payment against an invoice with no gateway involved. Requires a `Reference`, or a `Note` when the amount is zero. |
| `SetTenantSelfServeCommand` *(PLATFORM_*)* | §①b. Sets `Company.AllowSelfServeUpgrade` (true / false / null=inherit). Audited as `SELF_SERVE_TOGGLED`. |
| `SavePlatformPricingPolicyCommand` *(PLATFORM_*)* | §③b. Writes `FX_DERIVED_PRICING_ENABLED` / `FX_PRICING_UPLIFT_PERCENT` / `FX_PRICING_ROUNDING`. Audited as `PRICING_POLICY_CHANGED` — a change here alters what every future customer is charged, so it is never a silent settings write. |

**Reuse, don't fork, the transition logic.** `ConfirmSubscriptionPaymentCommand` should call the same
internal path `AssignSubscription` uses (extract the cancel-then-insert into a shared service, or
have the handler `Send` an internal command not exposed on the schema). Two copies of a filtered-unique
transition is a data-integrity bug waiting to happen.

**HotChocolate naming reminder:** `Get` is stripped from every resolver — `GetMyBillingOverview`
resolves as `myBillingOverview`, `GetSellablePlans` as `sellablePlans`; input types get `Input`
appended. `tsc` cannot see GraphQL field names, so a wrong name compiles clean and fails only at
runtime.

**Status machine, unchanged from `SubscriptionStatuses`:**

```
Trial ──pay──► Active ──renewal fails──► PastDue ──dunning exhausted──► Suspended
  │                │                                                        │
  └─expires──► (entitlements empty, fail-closed — already enforced)         └──pay──► Active
                   └──cancel auto-renew──► Active until period end ──► Cancelled
```

`PastDue` is already in `SubscriptionStatuses.Live`, so a tenant in dunning keeps working — correct,
and it means the grace period needs no new state.

---

## ⑥ Frontend work

- `/billing` — overview. `PlanUsagePanel` (unchanged) + a status card (plan, status badge, next
  charge, trial countdown) + a trial/past-due banner. This is where a lapsed tenant lands.
- `/billing/plans` — plan comparison cards from `sellablePlans`. Current plan marked, upgrades
  actionable, CUSTOM shows "Talk to us". Feature/quota rows come from the same entitlement metadata
  the catalog screen already renders, so labels stay consistent.
- `/billing/checkout/[id]` — gateway drop-in or redirect, then a confirming state that polls until
  the webhook lands. Never claims success off the redirect alone.
- `/billing/invoices` — table + PDF. **Print-CSS or a template engine, never an HTML screenshot**
  (house rule for document output).
- `/billing/payment-methods` — the vaulted method, replace/remove, mandate status, and the
  **auto-renew toggle**. Off shows "your plan runs until {CurrentPeriodEnd}, then stops" — not
  "cancelled". On, from off, opens the payment-method confirmation rather than flipping silently.
  For an offline-billed tenant the control renders disabled as "Billed by invoice — contact your
  account manager", because there is no mandate to cancel.

Every amount right-aligned; icon containers and status badges solid `bg-X-600` + `text-white`.

---

## ⑦ Guards and edge cases

| Case | Decision |
| --- | --- |
| **Trial re-claim** | Already closed (2026-07-30). Any prior non-deleted subscription with a `TrialEndsOn` blocks a second time-boxed assignment; platform staff can override with `allowTrialReclaim`, which is audited as an explicit re-grant. Tenants get no such flag. |
| **Mid-cycle upgrade, Trial/Free → paid** | Charge full price, new period starts at payment, trial subscription cancelled in the same transaction. No proration — nothing was paid. **This is the only self-serve path in MVP-1.** |
| **Paid → paid upgrade** | Needs proration. **Deferred** — MVP-1 routes it to "Contact us" so we don't ship a half-correct credit calculation against real money. |
| **Downgrade** | Never instant. Takes effect at `CurrentPeriodEnd`; if current usage exceeds the target plan's quotas, T-A18's read-only-over-limit policy applies — existing data stays editable, new creates block. Show the over-limit warning *before* confirming. |
| **Downgrade below usage** | Warn explicitly with the numbers ("you have 62,400 contacts; this plan allows 50,000"). Never delete. |
| **Payment fails at renewal** | `Active → PastDue`, entitlements unchanged (PastDue is Live), dunning emails on a ladder, then `Suspended`. Suspension is the first point access is lost. |
| **Currency has no gateway** | Plan card renders "Contact us"; the checkout command refuses. |
| **Currency has no price** | §③b. With `FX_DERIVED_PRICING_ENABLED` off — or on, but with no direct-pair rate — `ResolveAsync` returns null and the plan is not sellable in that currency. Fail-closed and correct: "Contact us", never a guessed amount. |
| **FX rate changes after signup** | Nothing happens. `Subscription.Amount` is a snapshot; renewals bill the snapshot and never re-call `ResolveAsync`. A price change is a re-assignment by a human, not a market event. |
| **Auto-renew off** | Tenant-controlled. Not a cancellation — access runs to `CurrentPeriodEnd`, then the subscription lapses. Re-enabling is a fresh mandate, not a flag flip. Unavailable (disabled, explained) for offline-billed tenants, who have no mandate. |
| **Self-serve switched off** | §①b. Billing menu still renders in full — plan, usage, invoices, history. Only the action changes to "Contact us", and `InitiateSubscriptionCheckout` refuses server-side. |
| **Offline / bank-transfer / complimentary upgrade** | §④c. Ops assigns the plan through the existing `AssignSubscription` (no payment code involved) and logs a `RecordOfflinePayment` against the invoice. Set `AutoRenew = false` and `AllowSelfServeUpgrade = false` on that tenant so dunning never chases a payer who settles by transfer and no "Pay now" appears beside an invoice they wire. |
| **Refund** | Platform-staff-only, out of the tenant surface. `RefundAsync` exists on the provider; the invoice goes `Refunded` and a credit note is issued. Not MVP-1. |
| **Tax/GST** | Table columns exist from day one; computation deferred. Rate config per country is its own piece of work. |
| **Audit** | Every state change writes through `IAuditLogWriter`, same as `SUBSCRIPTION_ASSIGNED` / `SUBSCRIPTION_STATUS_CHANGED`. Money moves get their own actions: `CHECKOUT_INITIATED`, `PAYMENT_SUCCEEDED`, `PAYMENT_FAILED`, `AUTORENEW_CANCELLED`. |

---

## ⑧ Phasing

**MVP-1 — the menu move + the one flow that matters.**
Billing menu/route/capabilities; `subscription-section.tsx` removed from Settings; `PlanUsagePanel`
rehosted; `/billing/plans` reading `sellablePlans`; `ops.PlatformPaymentGateways` +
`billing.SubscriptionPayments` + `billing.Invoices(+Lines)`; `InitiateSubscriptionCheckout` +
`ConfirmSubscriptionPayment` + the platform webhook route; **Trial/Free → paid only**, gateway-managed
recurring, one gateway seeded for the launch currency. Upgrade CTAs and 402/403 dialogs re-pointed
at `/billing/plans`. Plus `IPlatformBillingPaymentService` (§④a) with the two `IPaymentService` gaps
lifted; the self-serve switch (§①b, ~half a day); `RecordOfflinePayment` (§④c) — cheap, and the
first real customer may well pay by transfer before anyone uses the gateway; **both Razorpay and
Braintree seeded**; the §③b pricing policy (gate the existing FX fallback, add uplift + ceiling
rounding, snapshot `PriceSource`/`FxRateUsed`/`FxRateDate`) — a day's work on a service that already
exists; and **`PlanPrice` rows for every currency Braintree will sell in** — without those the non-INR
half of the launch is unreachable (see the ⚠ in §⑨).

**MVP-2 — the money hygiene.** Invoice PDF + numbering via `NumberSequenceGenerator`; payment-method
management + mandate replacement; dunning ladder and `PastDue → Suspended`; auto-renew cancel;
platform-side gateway CRUD screen (capability columns editable there).

**MVP-3 — the hard parts.** Paid→paid proration; scheduled downgrade at period end; tax/GST; refunds
and credit notes; multi-gateway per currency with failover (the §④b resolver already orders by
`Priority` — MVP-3 is where the *fallback on error* path gets built).

---

## ⑨ Decisions needed before MVP-1 starts

**Settled 2026-07-30:** the self-serve switch is in scope (§①b); platform billing gets its own
service but reuses the shared payment stack (§④a); gateway selection is a capability matrix (§④b);
offline and complimentary upgrades stay an ops-side path with a ledger entry, and the upgrade itself
requires no payment details (§④c); auto-renew is tenant-controlled with a mandate-aware re-enable
(§⑤ `SetAutoRenewCommand`). **Both Razorpay and Braintree go live at launch** — Razorpay for INR,
Braintree for the rest — so self-serve is global from day one, not INR-only. Pricing is
**configured-price-wins with FX as a gated fallback** (§③b): hand-set INR + USD, `FX_DERIVED_PRICING_ENABLED`
default **off** at launch, uplift and rounding configured but idle.

> ⚠ **Blocker that falls out of "both gateways at launch" — it is the price book, not the gateway.**
> All four plans are seeded INR-only, behind a `NOT EXISTS` guard in `billing-plan-catalog-seed.sql`
> (~lines 55-58). With `FX_DERIVED_PRICING_ENABLED` off (the launch setting, §③b),
> `IPlanPricingService.ResolveAsync(planCode, USD, cycle)` returns null, and a null resolution is a
> deliberate hard stop. With Braintree configured but no non-INR price rows, **every non-INR tenant
> still sees "Contact us"** — a correctly configured gateway that can never be reached. Global
> self-serve needs `PlanPrice` rows per sellable currency *before* it needs Braintree credentials.
> This lands in MVP-1.
>
> Turning the FX switch on would paper over this, and that is exactly why it defaults off: a derived
> price is a fallback for markets nobody has priced, not a substitute for pricing the market you are
> launching into.

Still open:

1. **Which currencies is Braintree actually enabled for**, and sandbox vs production credentials per
   gateway — who holds them. Drives the `SupportedCurrencies` seed in §④b and the price-book rows above.
1b. **The USD price for PLAN_50K and PLAN_100K** (FREE = 0). Set on its own merits — what a US or UK
   charity of that size will pay — not by converting ₹4,199. This is the one input MVP-1 cannot start
   the non-INR half without.
2. **Gateway-managed recurring, or vault + our own renewal job?** Recommendation: gateway-managed —
   both chosen gateways have a subscription product (Razorpay Subscriptions, Braintree Subscriptions),
   so this removes a scheduler, a retry ladder, and a dunning engine from scope with no coverage gap.
3. **Is FREE self-selectable?** If a tenant can pick FREE from `/billing/plans`, the one-trial guard
   is the only thing between them and a perpetual free ride — it holds, but the plan card should say
   "trial already used" rather than failing at click time.
4. **Tax registration and invoice numbering format** — needed before the first real invoice is issued,
   not after.
5. **Confirm `BILLING`/`BILLING_MANAGE` as new capabilities** vs reusing `COMPANYSETTINGS_EDIT`. The
   recommendation assumes new ones.
