# PSS 2.0 — ONBOARDING PROMPT 14 — Billing Gateway (platform gateway config · checkout · webhook · renewal · dunning)

**Task ID:** T-A20 (P2 phase — the second half of self-serve billing)
**Surface:** BE (platform gateway config + encryption · gateway↔currency matrix · platform billing payment service · checkout pair · platform webhook route · renewal job · dunning ladder) · FE (tenant checkout + payment method + auto-renew · ops gateway config screen)
**Model:** Sonnet — but see §⑪; §④ (the schedule-ownership decision) and §⑧ (webhook idempotency) are the two places to slow down.
**Depends on:** **PROMPT-13 must be merged and its migration applied.** This prompt writes into `billing.Invoices`, `billing.SubscriptionPayments` and `IPlatformSettingsService`, all of which PROMPT-13 creates. It also assumes §③b pricing resolution is live.

> **Blueprint:** `PSS-2.0-SELF-SERVE-UPGRADE-AND-BILLING-APPROACH.md` — §④ payment integration, §④a separate ops service, §④b capability matrix, §⑤ backend, §⑥ frontend, §⑦ guards, §⑧ phasing.

---

## ⓪ The decision this prompt is built on — read before anything else

**We own the billing schedule. The gateway does not.**

The provider abstraction offers gateway-owned subscriptions (`CreateSubscriptionAsync` /
`CancelSubscriptionAsync` / `RetrySubscriptionChargeAsync` / `UpdateSubscriptionAmountAsync`), and
using them would look like less work. It is not, because the three providers implement three
incompatible models:

| Provider | Model | State in this repo |
|---|---|---|
| **Braintree** | true gateway-owned subscription | all four methods implemented |
| **Razorpay** | gateway-owned, but a subscription must reference a **gateway-side Plan object** (`RazorpayProvider.CreatePlanAsync`) | `RetrySubscriptionChargeAsync` returns `Success=false` ("Razorpay handles retries per dashboard config"); `UpdateSubscriptionAmountAsync` returns `Success=false` ("not yet implemented") |
| **PayU India** | **no subscription object exists** — an SI mandate plus a merchant-initiated debit each cycle | `CreateSubscriptionAsync` only echoes the mandate id; the actual charge goes through `RetrySubscriptionChargeAsync(command=si_transaction)`; needs SI activation on the merchant account |

Delegating the schedule therefore means: a per-provider branch at every lifecycle point, a
`billing.Plans` → gateway-plan-id mapping table that exists only for Razorpay, a price change that
silently fails to reach the gateway on two of three providers, and dunning behaviour we cannot observe
or test. **A price change that does not reach the gateway is a customer billed the wrong amount
indefinitely** — that is the failure this decision avoids.

**What we build instead:** vault the payment instrument once, then a renewal job we own charges it each
cycle through `ProcessPaymentAsync` (Braintree/Razorpay) or `RetrySubscriptionChargeAsync`
(PayU SI). `Subscription.GatewaySubscriptionId` — the column PROMPT-13 specced — is kept as a
**mandate handle**, not as a schedule we defer to. One code path, one place dunning lives, and the
amount charged is always the amount in our own snapshot.

**Consequence to accept honestly:** we now own retry timing, failure classification and the clock. That
is §⑨ and it is the bulk of this prompt. The alternative was not less work — it was the same work,
three times, on two providers that cannot do it.

---

## ① Why this exists

PROMPT-13 built everything except taking money. A tenant can see their plan, see their invoices, and
be upgraded by an ops member who then records a bank transfer by hand. That is a working business —
for about thirty customers. It does not survive self-serve, because three things are missing:

1. **No platform merchant account.** `fund.CompanyPaymentGateways` is the *tenant's* gateway — the
   charity collecting from its donors. Platform billing is the opposite direction of money and must
   never resolve through it. Same split already made for `ops.PlatformCommunicationProviders`.
2. **No card path.** `canSelfServe` returns true today and the button still says "Contact us", because
   there is nothing behind it.
3. **Nothing renews.** `CurrentPeriodEnd` passes and nothing happens — no charge, no status change, no
   email. A subscription that never renews is a free plan with extra steps.

---

## ② Reuse-first — the payment stack is already tenant-agnostic

This is the good news, and it is worth stating precisely because it determines how small this prompt
can be. **Every method on `IPaymentService` takes `PaymentGatewayConfiguration` as a parameter**:

```csharp
Task<PaymentProcessResult> ProcessPaymentAsync(PaymentGatewayConfiguration config, PaymentProcessRequest request, CancellationToken ct = default);
```

`PaymentGatewayConfiguration` carries `GatewayCode` / `Environment` / `MerchantId` / `ApiKey` /
`ApiSecret` / `WebhookSecret` / `AdditionalConfig` and **no `CompanyId`**. So the factory, the service
and all three providers are reusable as-is. The tenant coupling lives in exactly two places, and both
are *callers*, not the stack itself:

- `Base.API/PaymentFlow/PaymentFlowService.cs` — its `BuildConfig` reads `fund.CompanyPaymentGateways` and decrypts with `DecryptForCompany`.
- `Base.API/Controller/PaymentWebhookController.cs` — routes are `api/webhooks/{gateway}/{companyCode}` and resolve the tenant's gateway row.

**Do not modify either file.** Build platform-side siblings.

| Need | Copy from | Notes |
|---|---|---|
| Platform-owned config row, no `CompanyId` | `Base.Domain/Models/OpsModels/PlatformCommunicationProvider.cs` + its EF config + migration `20260729062510_Add_PlatformCommunicationProvider.cs` | the exact precedent |
| Build a `PaymentGatewayConfiguration` from a stored row | `PaymentFlowService.BuildConfig` | copy the shape, swap the source table and the decrypt call |
| Charge / verify / refund / vault | `IPaymentService` — **unchanged**, pass a platform config | `Base.Support/Payment/Services/IPaymentService.cs` |
| Webhook signature validation + parse | `IPaymentWebhookProcessor` — **unchanged** | `Base.Support/Payment/Webhooks/` |
| Webhook logging, duplicate-event guard, status master-data lookup | `PaymentWebhookController.BraintreeWebhook` lines 41-160 | logic reusable, table is not — see §⑧ |
| Invoice number generation | `NumberSequenceGenerator` | never `count(*) + 1` |
| Platform settings read | `IPlatformSettingsService` (PROMPT-13 §③) | already exists after 13 |
| Command/handler/validator/audit shape | `AssignSubscription.cs` | end to end |

---

## ③ BE — platform gateway config

### 3.1 The encryption gap — resolve this first

`IEncryptionService` exposes **only** `EncryptForCompany(string, int companyId)` /
`DecryptForCompany(string, int companyId)` (AES-GCM + HKDF per-tenant subkey, ciphertext prefixed
`v2:`, master key from `PaymentGateway:CredentialEncryptionKey`). There is **no platform-scoped
overload**, and platform credentials have no tenant.

Add one — do **not** pass `companyId: 0` to the tenant method. A sentinel tenant id derives a real
per-tenant subkey for a tenant that does not exist; the day someone provisions company 0, or the day
someone audits "which tenants have gateway credentials", the answer is wrong.

```csharp
// Same AES-GCM + HKDF construction as EncryptForCompany, but the HKDF info/salt is derived from a
// fixed platform label instead of a company id. Platform billing credentials have no tenant.
string EncryptForPlatform(string plainText);
string DecryptForPlatform(string cipherText);
```

Keep the `v2:` prefix convention. Use a distinct HKDF info string (e.g. `"platform-billing"`) so a
platform ciphertext can never be decrypted by a tenant subkey or vice versa — that separation is the
point of the derivation.

> `ops.PlatformCommunicationProviders` stores its config JSON in **plaintext**. Do not follow that
> precedent here. Email credentials leaking is bad; merchant credentials leaking is a chargeback
> liability with our name on it.

### 3.2 `ops.PlatformPaymentGateways`

```
PlatformPaymentGatewayId int PK
PaymentGatewayId    int FK → com.PaymentGateways      -- which gateway (BRAINTREE/RAZORPAY/PAYU)
GatewayEnvironment  text NOT NULL default 'sandbox'   -- 'sandbox' | 'production'
MerchantId          text null
EncryptedApiKey     text NOT NULL
EncryptedApiSecret  text NOT NULL
EncryptedWebhookSecret text null
AdditionalConfig    text null      -- provider-specific JSON, NOT credentials
Priority            int NOT NULL default 0   -- tie-break when two gateways both cover a currency
+ Entity audit columns (IsActive/IsDeleted/CreatedBy/CreatedDate/ModifiedBy/ModifiedDate)
```

**No `CompanyId`. Ever.** Add an EF `HasQueryFilter`-free configuration (this table is outside the
tenant filter entirely — mirror `PlatformCommunicationProviderConfiguration`).

Index: `UNIQUE (PaymentGatewayId, GatewayEnvironment) WHERE IsDeleted = false` — one sandbox row and
one production row per gateway, no more. Two production Braintree rows is a coin-flip over which
merchant account a customer's card lands in.

### 3.3 `ops.PlatformGatewayCurrencies` — the §④b capability matrix

```
PlatformGatewayCurrencyId int PK
PlatformPaymentGatewayId  int FK (cascade)
CurrencyId                int FK → com.Currencies
+ IsActive / IsDeleted / audit
UNIQUE (PlatformPaymentGatewayId, CurrencyId) WHERE IsDeleted = false
```

A child table, not a JSON list on the parent, because this is joined on in the resolver on every
checkout and a JSON `LIKE` scan is the wrong tool.

**This table is the answer to "can we charge this customer?"** — and it is *configuration*, not
discovery. No provider API tells us reliably which currencies a merchant account is enabled for, so an
ops member enters what the gateway contract actually says. An empty matrix means **no currency is
chargeable**, which is the correct fail-closed default for a table nobody has filled in yet.

### 3.4 `IPlatformGatewayResolver`

```csharp
public interface IPlatformGatewayResolver
{
    /// Resolves the active platform gateway able to charge in the given currency, in the environment
    /// named by the PLATFORM_GATEWAY_ENVIRONMENT setting. Returns null when no gateway covers it —
    /// the caller must fail closed, never fall back to another currency or another environment.
    Task<PlatformGatewayResolution?> ResolveForCurrencyAsync(int currencyId, CancellationToken ct = default);
}

public sealed record PlatformGatewayResolution(
    int PlatformPaymentGatewayId, string GatewayCode, PaymentGatewayConfiguration Config);
```

Selection: active + not deleted + environment matches + a matching active row in the currency matrix,
ordered by `Priority` then `PlatformPaymentGatewayId`. Deterministic — never "first row found".

The `Config` is built here, decrypted with `DecryptForPlatform`, and is **request-scoped and never
logged, never returned through GraphQL, never cached**. `PaymentGatewayConfiguration`'s own comment
says "never persisted, only in memory during request" — honour it.

New platform setting (same `CompanyId IS NULL` mechanism as PROMPT-13 §3.2):

| ParamCode | DataType | Default | Meaning |
|---|---|---|---|
| `PLATFORM_GATEWAY_ENVIRONMENT` | SELECT | `sandbox` | `sandbox` \| `production`. Nothing goes to production because a config row exists — it goes when someone flips this. |

### 3.5 Extend the self-serve predicate

PROMPT-13 §6.2 left a `// PROMPT-14:` marker in the shared `canSelfServe` helper. Fill it in now:

```
AND resolver.ResolveForCurrencyAsync(subscription.CurrencyId) != null
```

and add the enum value `NO_GATEWAY_FOR_CURRENCY` to `selfServeBlockedReason`, after
`NO_PRICE_FOR_CURRENCY` in the first-failing-clause order — a price we cannot charge is still a price,
so "we have no price" is the more accurate message when both are true.

FE must render the new reason. It is a real state now: INR priced and chargeable, USD priced but no
USD-enabled gateway.

---

## ④ BE — `IPlatformBillingPaymentService`

The one new service. It wraps `IPaymentService` with platform config resolution so that **no command
ever touches `IPlatformGatewayResolver` or `PaymentGatewayConfiguration` directly** — that is what
keeps decrypted credentials out of handler code.

```csharp
public interface IPlatformBillingPaymentService
{
    Task<PlatformCheckoutSession?> BeginCheckoutAsync(int companyId, int subscriptionId, CancellationToken ct = default);
    Task<PlatformChargeOutcome>    ChargeAsync(PlatformChargeRequest request, CancellationToken ct = default);
    Task<PlatformVaultOutcome>     VaultAsync(int companyId, int currencyId, string paymentMethodNonce, CancellationToken ct = default);
    Task<PlatformChargeOutcome>    ChargeVaultedAsync(int tenantPaymentMethodId, decimal amount, int currencyId, string idempotencyKey, CancellationToken ct = default);
}
```

`PlatformChargeOutcome` must carry: `Success`, `GatewayTransactionId`, `GatewayReference`,
`FailureCode`, `FailureMessage`, and a **classified** `FailureKind` ∈
`{ None, SoftDecline, HardDecline, GatewayError, ConfigError }`. The classification is not decoration —
§⑨ branches on it, and a hard decline retried on a schedule is how you get a merchant account
reviewed.

Map provider `ErrorMessage`/`ErrorCode` to `FailureKind` in one place, per provider, with an explicit
`default → GatewayError` (unknown means retryable-with-backoff, not "give up" and not "retry hard").

`ChargeVaultedAsync` dispatches by gateway code: `ProcessPaymentAsync` with the vault token for
Braintree/Razorpay, `RetrySubscriptionChargeAsync(command=si_transaction)` for PayU SI. **That branch
is the only place provider recurring differences are allowed to appear.** Everything upstream sees one
method.

---

## ⑤ BE — schema (migration specs, **user-owned**)

> **Do not run `dotnet ef migrations add`, `database update`, or `remove`. Do not hand-author a
> migration or a snapshot.** Write entities + EF configurations, build to prove they compile, hand over
> this spec. The user authors, runs and commits. Seed SQL goes in `sql-scripts-dyanmic/`; the user
> applies it.

### 5.1 `billing.SubscriptionPayments` — the six columns PROMPT-13 deliberately deferred

```
PlatformPaymentGatewayId int  null  FK → ops.PlatformPaymentGateways
GatewayTransactionId     text null
GatewayReference         text null
FailureCode              text null
FailureMessage           text null
IdempotencyKey           text null
RawResponse              text null   -- provider payload, for disputes
```

Index: `UNIQUE (IdempotencyKey) WHERE IdempotencyKey IS NOT NULL AND IsDeleted = false`. This index
**is** the double-charge guard — see §⑧.2. It is not a nicety and it is not enforceable in
application code alone.

All nullable: the offline rows PROMPT-13 already wrote legitimately have none of this.

### 5.2 `billing.TenantPaymentMethods`

```
TenantPaymentMethodId int PK
CompanyId int FK NOT NULL
PlatformPaymentGatewayId int FK NOT NULL
GatewayTokenId text NOT NULL        -- vault token / SI mandate handle
MethodType text null                -- 'CARD' | 'UPI' | 'NETBANKING' | 'MANDATE'
Brand text null, Last4 text null, ExpiryMonth int null, ExpiryYear int null
HolderName text null
IsDefault bool NOT NULL default false
+ audit columns
```

**Store `Last4` and `Brand` only.** No PAN, no CVV, no expiry-bearing full number — the card never
touches our servers (the FE talks to the gateway's own drop-in/checkout and hands us a nonce), and
that is what keeps PCI scope at the gateway. A field that *could* hold a PAN eventually will.

Index: `(CompanyId) WHERE IsDefault = true AND IsDeleted = false` — **unique**, so "the default card"
is never ambiguous.

### 5.3 `ops.PlatformWebhookLogs`

A separate table from `fund.PaymentWebhookLogs`. That table has `CompanyId int` **non-nullable** with a
required `Company` navigation, lives in the `fund` (donation) schema, and is the data source for the
tenant-facing `GetPaymentWebhookLog` reconciliation queries. Writing platform billing events into it
would put our own merchant traffic inside every tenant's donation reconciliation view.

```
PlatformWebhookLogId int PK
PlatformPaymentGatewayId int FK NOT NULL
CompanyId int null                 -- the PAYING tenant, resolved from the payload; null until matched
EventType text NOT NULL
GatewayEventId text null
RawPayload text NOT NULL
SignatureHeader text null
SignatureValid bool NOT NULL
ProcessingStatus text NOT NULL     -- 'Received'|'Processed'|'Failed'|'Ignored'|'Duplicate'
ProcessingError text null
SubscriptionPaymentId int null
ReceivedAt timestamptz NOT NULL, ProcessedAt timestamptz null
IPAddress text null, RetryCount int NOT NULL default 0
+ audit columns
```

`ProcessingStatus` is a **text status here, not a MasterData FK** — the tenant table uses
`WEBHOOKPROCESSINGSTATUS` master data, which is tenant-scoped seed data, and platform infrastructure
must not depend on a tenant's master-data rows existing.

`CompanyId` is **nullable on purpose**: a webhook arrives before we have necessarily matched it to a
tenant, and an unmatched webhook must still be logged. An unmatched-but-signed webhook is exactly the
thing you need in hand when a gateway says "we told you about this".

Index: `UNIQUE (PlatformPaymentGatewayId, GatewayEventId) WHERE GatewayEventId IS NOT NULL AND IsDeleted = false`,
plus `(ProcessingStatus)`, `(CompanyId)`.

### 5.4 `billing.Subscriptions` — dunning columns

```
DunningAttemptCount   int      NOT NULL default 0
LastDunningAttemptOn  timestamptz null
GracePeriodEndsOn     timestamptz null
```

`GatewaySubscriptionId` and `AutoRenew` already exist from PROMPT-13 §5.1. No new status values —
`PastDue` is already in `SubscriptionStatuses.Live`, so a dunning tenant keeps working, which is the
intended behaviour and needs no state machine change.

### 5.5 Seed SQL — `sql-scripts-dyanmic/billing-gateway-platform-seed.sql`

Idempotent `WHERE NOT EXISTS`. Inserts: the `PLATFORM_GATEWAY_ENVIRONMENT` setting row
(`CompanyId = NULL`, default `sandbox`), and the `PLATFORM_BILLING` / `PLATFORM_BILLING_MANAGE`
capabilities.

**Insert no gateway rows and no currency-matrix rows.** Credentials are entered through the ops UI
(§⑦.2) so they are encrypted by the application with the live master key — a seeded credential is
either plaintext in a committed file or encrypted with a key the script cannot access. Ship the schema
empty and let the resolver fail closed until someone configures it. Include the standard
restart-the-API note after `COMMIT`.

---

## ⑥ BE — checkout, renewal, dunning

### 6.1 `InitiateSubscriptionCheckoutCommand` *(tenant, `[CustomAuthorize("BILLING","BILLING_MANAGE")]`)*

**`CompanyId` from the token, never an argument.** A tenant-supplied `companyId` on a checkout command
lets one tenant start a payment against another's subscription.

1. Re-evaluate `canSelfServe` **server-side** (§3.5). A blocked tenant is refused here even though the
   FE hid the button — a hidden button is not a control.
2. Resolve the target plan's price through `IPlanPricingService` (§③b). Null ⇒ `BadRequestException`.
3. Resolve the gateway for that currency. Null ⇒ `BadRequestException` naming the currency.
4. Create the invoice in `Draft` — number from `NumberSequenceGenerator`, one line, `TaxAmount = 0`,
   `PlanCode`/`BillingCycle` snapshotted.
5. Create the `SubscriptionPayments` row `Status='Initiated'` with a **server-generated
   `IdempotencyKey`** (§⑧.2). The FE never supplies it.
6. Return `{ invoiceId, subscriptionPaymentId, clientToken, gatewayCode, amount, currencyCode }` —
   `clientToken` from `GenerateClientTokenAsync`.

The invoice is `Draft` until money moves, so an abandoned checkout does not consume an invoice number
in the issued sequence. Tax authorities care about gaps in *issued* numbers; drafts are ours.

### 6.2 `ConfirmSubscriptionPaymentCommand` *(tenant, `BILLING_MANAGE`)*

Takes `subscriptionPaymentId` + `paymentMethodNonce` + `saveForFuture`.

1. Load the payment row; must be `Initiated` **and belong to the caller's company**. Anything else ⇒
   refuse. This is the cross-tenant guard and it must be an equality check on the token's company, not
   a filter.
2. `ChargeAsync`.
3. **Success:** payment `Succeeded` + `CompletedOn` + gateway ids; invoice → `Issued` then `Paid`;
   `AssignSubscriptionCommand` performs the actual plan change (**do not duplicate its logic** — it
   owns the cancel-incumbent + insert-successor transaction and the filtered unique index); vault the
   instrument if `saveForFuture`; `entitlementService.Invalidate(companyId)`; audit
   `SUBSCRIPTION_PAYMENT_SUCCEEDED`.
4. **Failure:** payment `Failed` + `FailureCode`/`FailureMessage`/`RawResponse`; invoice stays `Draft`;
   **the subscription does not change**; audit `SUBSCRIPTION_PAYMENT_FAILED`. Return the classified
   `FailureKind` so the FE can say "your bank declined this" rather than "something went wrong".
5. A tenant may retry: a new `InitiateSubscriptionCheckout` mints a fresh idempotency key. Never reuse
   a failed row.

> **Ordering matters and is not arbitrary.** Charge, *then* assign. Assigning first and charging second
> means a declined card leaves a tenant upgraded for free. Charging first means a crash between the two
> leaves a paid-but-not-upgraded tenant — recoverable by an ops member with the payment row in hand, and
> the webhook (§⑧) is the automatic repair. Pick the failure you can fix.

### 6.3 `SetAutoRenewCommand` *(tenant, `BILLING_MANAGE`)*

Toggles `Subscription.AutoRenew`. Turning it **off** does not cancel — the subscription runs to
`CurrentPeriodEnd` and then lapses. Audit `AUTO_RENEW_CHANGED`. Off with no saved payment method is
the normal state, not an error.

### 6.4 The renewal job

A scheduled worker in the existing job infrastructure (find how the other recurring jobs are hosted
and follow it — **do not introduce a new scheduling mechanism**). Runs daily.

Selects: `Status IN (Active, PastDue)` AND `AutoRenew = true` AND `CurrentPeriodEnd <= now` AND not
deleted AND a default `TenantPaymentMethod` exists.

Per subscription:

1. **Bill the snapshot.** `Amount` / `CurrencyId` / `BillingCycle` from the subscription row. **Never
   re-call `ResolveAsync`** — a price change is a deliberate re-assignment by a human, not a market
   event, and re-resolving at renewal is how an FX movement silently re-prices a live customer.
2. Create invoice (`Issued`) + payment row with a **deterministic** idempotency key:
   `sub-{SubscriptionId}-period-{CurrentPeriodEnd:yyyyMMdd}`. Deterministic, so a job that runs twice
   — a retry, an overlapping instance, a redeploy mid-run — collides on the unique index instead of
   double-charging.
3. `ChargeVaultedAsync`.
4. **Success:** invoice `Paid`; roll `CurrentPeriodStart = CurrentPeriodEnd`,
   `CurrentPeriodEnd += cycle`; `Status = Active`; reset `DunningAttemptCount = 0`,
   `GracePeriodEndsOn = null`. Email the receipt.
5. **Failure:** enter/advance dunning (§6.5). **Do not roll the period.** Rolling it on a failed
   charge means the next run thinks it already billed that period.
6. Wrap each subscription in its own try/catch. One tenant's gateway timeout must not abort the run for
   everyone behind it in the loop.

**Time-boxed plans** (`TrialDurationDays > 0`, i.e. FREE) have no payment method and must not enter
dunning — a trial ending is a lapse, not a failure. Handle trial expiry as a separate selection:
`Status = Trial` AND `TrialEndsOn <= now` → `Status = Suspended` (or whatever PROMPT-12's entitlement
gates expect), plus a notification. Verify against PROMPT-12 rather than assuming.

### 6.5 The dunning ladder

| Attempt | When | Status | Tenant sees |
|---|---|---|---|
| 1 | on first failure | `PastDue`, `GracePeriodEndsOn = now + grace` | banner + email: what failed, when we retry, when access ends |
| 2 | +3 days | `PastDue` | reminder |
| 3 | +7 days | `PastDue` | final notice, names the exact suspension date |
| — | grace expiry | `Suspended` | access gated, data retained |

Grace days, retry offsets and max attempts are platform settings, not constants
(`BILLING_GRACE_PERIOD_DAYS` default 14, `BILLING_DUNNING_RETRY_DAYS` default `3,7`,
`BILLING_DUNNING_MAX_ATTEMPTS` default 3).

**`FailureKind` gates retry.** `SoftDecline`/`GatewayError` → advance the ladder. `HardDecline`
(stolen/closed/invalid) → **do not retry**; go straight to the final notice and let the grace period
run out. Retrying a hard decline on a schedule is what gets a merchant account flagged.
`ConfigError` → **alert ops, do not touch the subscription.** Our misconfiguration is not the
customer's dunning event, and marking them `PastDue` for it is both wrong and a support ticket.

`Suspended` never deletes anything. Data retention on suspension is a separate policy decision nobody
has made; deleting on non-payment is not recoverable and is not in scope.

---

## ⑦ FE

### 7.1 Tenant

- **`/billing/checkout`** — the gateway's own drop-in / hosted field container (nonce only, never a
  card field of ours), order summary, plan + amount + currency, explicit "you will be charged X now
  and X every cycle" line. Declines render the classified message from `FailureKind`, not a generic
  toast. Double-submit disabled while in flight.
- **`/billing`** — replace PROMPT-13's read-only CTA path: `/billing/plans` cards now route to
  checkout when `canSelfServe`, and still render "Contact us" with the specific
  `selfServeBlockedReason` when not — including the new `NO_GATEWAY_FOR_CURRENCY`.
- **Payment method card** — brand + `•••• last4` + expiry, "Update", "Remove". Removing the default
  while `AutoRenew` is on must warn that renewal will fail, and must not silently flip `AutoRenew`
  off — an implicit cancellation is worse than an explicit warning.
- **Auto-renew toggle** — states plainly what happens at period end when off.
- **Past-due banner** — the amount, the retry date, and the suspension date. A banner that says only
  "payment failed" generates a support ticket; one that names the date resolves itself.

### 7.2 Ops

- **Platform gateway config screen** (`PLATFORM_BILLING_MANAGE`) — one card per gateway: environment,
  merchant id, credentials, priority, plus the currency matrix as multi-select. Credentials are
  **write-only**: never returned by any query, rendered as `••••••••` when set, and a blank submit
  means "unchanged", not "clear". Same discipline as every other masked credential field in the app.
- The environment switch (`PLATFORM_GATEWAY_ENVIRONMENT`) sits on the pricing-policy settings surface
  from PROMPT-13 §6.5, with an explicit confirm — flipping to `production` means real money.
- **Platform webhook log viewer** — read-only list from `ops.PlatformWebhookLogs`: event type, status,
  received, signature valid, matched tenant, error. The first thing anyone asks during a payment
  incident is "did the webhook arrive", and grepping application logs is not an answer.
- Tenant detail Subscription panel: gateway payment history alongside PROMPT-13's offline payments, and
  the dunning state (attempt count, grace end).

### 7.3 House rules (non-negotiable)

Design tokens only — no hex, no raw px. Amounts right-aligned in every data context. Icon containers,
status badges and helper chips **solid `bg-X-600` + `text-white`** — never `bg-X-50/100`,
`text-X-700/800`, `bg-muted`, or `text-muted-foreground`. Shaped `Skeleton`s; explicit empty and error
states. `@iconify` Phosphor icons. Responsive xs→xl. Save/Create enablement from RHF
`formState.isValid`, never from `canCreate`/`canUpdate` — capability governs entry-point visibility
only.

---

## ⑧ BE — the platform webhook

### 8.1 Route

`POST api/webhooks/platform/{gatewayCode}` — `[AllowAnonymous]`, **no `{companyCode}` segment**. The
tenant is not in the URL because the platform gateway is not per-tenant; it is resolved *from the
payload* by looking the gateway transaction id up in `billing.SubscriptionPayments`.

New controller, `PlatformBillingWebhookController`. Do not add routes to
`PaymentWebhookController` — its every path assumes a tenant gateway, and a shared controller will
eventually resolve the wrong config for the wrong direction of money.

Order of operations, copied in spirit from `PaymentWebhookController.BraintreeWebhook`:

1. Read the raw body **before** anything else (Braintree posts form-encoded `bt_signature` +
   `bt_payload`; the others differ — branch per gateway, as the existing controller does).
2. Resolve the platform gateway row by `gatewayCode` + the environment setting.
3. **Log the raw payload first, then validate.** An invalid signature is exactly the event you most
   want a record of.
4. Validate signature. Invalid ⇒ persist `SignatureValid=false`, `ProcessingStatus='Failed'`, return
   `401`. Never process an unsigned payload.
5. Parse. Duplicate `GatewayEventId` ⇒ `ProcessingStatus='Duplicate'`, return **`200`**. A gateway that
   gets a non-2xx retries; returning an error for a duplicate produces an infinite retry loop.
6. Match to a `SubscriptionPayments` row by `GatewayTransactionId`. No match ⇒
   `ProcessingStatus='Ignored'` + `200`. Unmatched is normal (events for things we do not model), not
   an error.
7. Apply the transition, set `CompanyId` on the log, `ProcessingStatus='Processed'`, `200`.
8. Any unexpected exception ⇒ `ProcessingStatus='Failed'` + the message + return **`500`** so the
   gateway retries. Swallowing an exception with a `200` loses the event permanently.

### 8.2 Idempotency — the one thing that must be right

Money moves here. Three layers, and all three are needed:

1. **`UNIQUE (IdempotencyKey)`** on `billing.SubscriptionPayments` (§5.1). Two concurrent charge
   attempts for the same period lose one at the database, not at a `Any()` check that raced.
2. **`UNIQUE (PlatformPaymentGatewayId, GatewayEventId)`** on `ops.PlatformWebhookLogs` (§5.3). The
   same webhook delivered five times is logged once and processed once.
3. **Idempotent transitions.** `Succeeded → Succeeded` is a no-op returning `200`, not an error and not
   a second invoice. Webhooks arrive out of order and arrive after the synchronous confirm has already
   applied the same outcome — that is the normal case, not the edge case.

The webhook is also the **repair path** for §6.2's crash window: a payment that succeeded at the
gateway while our process died mid-transaction gets completed when the webhook lands. Write it so that
it can complete a payment the synchronous path never finished, not merely acknowledge one it did.

---

## ⑨ Acceptance

Sandbox credentials required for 6-11. Everything else is exercisable without them.

1. **Fail closed, no config.** Empty `ops.PlatformPaymentGateways` → `ResolveForCurrencyAsync` returns
   null; `/billing/plans` shows "Contact us" with `NO_GATEWAY_FOR_CURRENCY`; `InitiateCheckout` throws
   `BadRequestException`. No unhandled exception anywhere on the path.
2. **Fail closed, empty matrix.** Gateway row configured, currency matrix empty → still null.
3. **Environment isolation.** A production row exists but `PLATFORM_GATEWAY_ENVIRONMENT='sandbox'` and
   no sandbox row → resolves null. It must **not** silently use production.
4. **Credential round-trip.** Save via the ops UI → `EncryptedApiKey` is `v2:`-prefixed ciphertext in
   the DB; `DecryptForPlatform` returns the original; `DecryptForCompany(cipher, anyCompanyId)` on that
   same ciphertext **fails or returns garbage** — the derivations must not be interchangeable.
5. **Write-only credentials.** No GraphQL query returns any credential field. Submitting the form with
   blank credential fields leaves the stored values unchanged.
6. **Happy path.** Checkout → charge → invoice `Paid` → plan assigned via `AssignSubscription` →
   entitlements invalidated → `PriceSource` snapshotted. One `SubscriptionPayments` row, `Succeeded`.
7. **Decline.** Test-decline card → payment `Failed` with `FailureKind='HardDecline'` or
   `SoftDecline`; invoice stays `Draft`; **subscription unchanged**; tenant sees the specific message.
8. **No double-charge, concurrent.** Fire `ConfirmSubscriptionPayment` twice concurrently for one
   payment row → exactly one gateway charge. Verify at the **gateway dashboard**, not only in our DB.
9. **No double-charge, renewal.** Run the renewal job twice in the same day → the second run charges
   nothing (deterministic key collides on the unique index).
10. **Webhook duplicate.** POST the same signed payload three times → one `Processed`, two
    `Duplicate`, all three `200`, one invoice.
11. **Webhook as repair.** Kill the process between charge and assign (or simulate by leaving a
    `Succeeded` payment with the subscription unchanged), then deliver the webhook → the payment
    completes and the plan is assigned. This is the crash-window test and it is the one most likely to
    be skipped — do not skip it.
12. **Unsigned webhook.** Tampered signature → `401`, logged with `SignatureValid=false`, nothing
    processed.
13. **Unmatched webhook.** Unknown `GatewayTransactionId` → `Ignored` + `200` + `CompanyId` null.
14. **Cross-tenant checkout.** Company A confirms company B's `subscriptionPaymentId` → refused.
15. **No re-pricing at renewal.** Change `plan.Price` and the FX rate, run the renewal job → the
    invoice is for the subscription's snapshotted `Amount`. Assert the exact figure.
16. **Dunning ladder.** Force three consecutive failures → `PastDue` with `GracePeriodEndsOn`,
    `DunningAttemptCount` 1→2→3, three distinct emails, period **never rolls**. At grace expiry →
    `Suspended` and entitlement gates deny. Data still present.
17. **Hard decline short-circuits.** `FailureKind='HardDecline'` → **no** scheduled retries; final
    notice sent; grace still runs to expiry.
18. **Config error is not the tenant's problem.** Force `ConfigError` (wrong credentials) → ops
    alerted, subscription **not** marked `PastDue`, `DunningAttemptCount` unchanged.
19. **Auto-renew off.** Period end passes → no charge, no dunning, subscription lapses; the tenant was
    told in advance.
20. **Trial expiry is not dunning.** A FREE time-boxed subscription reaching `TrialEndsOn` → no charge
    attempt, no `PastDue`, no payment row.
21. **One tenant's failure is contained.** Make one subscription throw inside the renewal loop → every
    other due subscription still processes.
22. **Default payment method uniqueness.** Two `IsDefault=true` rows for one company → rejected by the
    filtered unique index.
23. **No PAN anywhere.** Grep the new code and the DB for full card numbers / CVV. Only `Brand` and
    `Last4` are stored. No credential or nonce appears in any log statement.
24. **UTC.** Every `DateTime` written is `Kind=Utc`; wire values normalised at handler entry; the
    renewal job's date arithmetic is UTC throughout. Verify by saving, not by reading code — Npgsql
    throws on `Kind=Unspecified` against `timestamptz`.
25. **Typecheck.** `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, **no pipe**, **exit
    0**. A run reporting only a "pre-existing" `TS2688` config error checked **zero files** and is not
    a pass.

---

## ⑩ Out of scope — do not build

Invoice PDF generation; tax computation (`TaxAmount` stays 0 — the *column* exists, the arithmetic does
not); proration and credit notes (a mid-cycle upgrade charges a full new cycle from today and says so
on the checkout screen — the honest simple rule); refunds through the UI (`RefundAsync` exists; the ops
flow does not); gateway-owned subscription objects (§⓪); Razorpay gateway-plan mapping; dunning via SMS
or WhatsApp (email only); multi-gateway failover on a live decline (`Priority` picks one gateway at
resolve time, it does not retry the next); usage-based or metered billing; annual→monthly downgrade
mechanics beyond what `AssignSubscription` already does.

---

## ⑪ Known traps

- **`PSS_2.0_Backend/` is gitignored**, so the Grep tool returns **zero** `.cs` matches. Use
  `find -iname`, or scope `grep -rn --include=*.cs` to **one** project directory — a repo-wide backend
  grep times out at 120 s. Absolute-path `Read` works.
- **HotChocolate strips `Get` from every resolver** and appends `Input` to input types.
  `GetPlatformPaymentGateways` → **`platformPaymentGateways`**. `tsc` cannot see gql field names, so a
  wrong name builds clean and fails only at runtime. Verify against the generated schema.
- **`fund.PaymentWebhookLogs.CompanyId` is non-nullable with a required `Company` nav.** That is why
  §5.3 is a new table. Do not "just make it nullable" — the tenant reconciliation queries depend on it.
- **`IEncryptionService` has no platform overload** (§3.1). Adding one is part of this prompt.
- **`PaymentGatewayConfiguration` has no currency field.** Chargeable currency is *our* matrix (§3.3),
  not something the provider tells us.
- **Razorpay subscriptions need a gateway-side Plan object**; PayU has no subscription object at all.
  Both are why §⓪ decided as it did. If you find yourself adding a `RazorpayPlanId` column, stop and
  re-read §⓪.
- **`billing.Subscriptions` has a filtered `UNIQUE(CompanyId) WHERE Status IN (Trial,Active,PastDue)`**.
  `AssignSubscription` already handles cancel-then-insert in one `SaveChangesAsync`. Call it; do not
  reimplement it.
- **Money is `numeric(18,2)`; FX rates are `numeric(18,8)`.** Gateways take minor units (paise/cents) —
  convert at the provider boundary only, and never store minor units in our columns.
- **Never log a credential, a nonce, a vault token or a raw webhook body at Information level.**
  `RawResponse`/`RawPayload` belong in the DB row, not the application log.

---

## ⑫ Hand-off to the user (do not do these yourself)

1. `dotnet build` — the user builds the backend.
2. **Migration** covering §5.1–§5.4: 7 columns on `billing.SubscriptionPayments`, 3 on
   `billing.Subscriptions`, and the new `billing.TenantPaymentMethods`, `ops.PlatformPaymentGateways`,
   `ops.PlatformGatewayCurrencies`, `ops.PlatformWebhookLogs`.
3. Apply `sql-scripts-dyanmic/billing-gateway-platform-seed.sql`, **then restart the API** (settings
   cache).
4. **Configure through the ops UI, not SQL:** gateway credentials + the currency matrix. Sandbox first;
   leave `PLATFORM_GATEWAY_ENVIRONMENT = sandbox` until acceptance passes.
5. **Register the webhook URL** `https://<host>/api/webhooks/platform/{gatewayCode}` in each gateway
   dashboard, and store the webhook secret through the UI.
6. **Still needed:** the USD price points for PLAN_50K / PLAN_100K; Braintree's actually-enabled
   currency list (this becomes the §3.3 matrix); sandbox and production credentials per gateway and who
   holds them; the grace-period and retry-cadence numbers if the §6.5 defaults are wrong.

---

## ⑬ Build Log

_(append one entry per session; keep the last 5 — git holds the rest. Preserve Known Issues in full.)_

| Session | Date | What shipped | Notes |
|---|---|---|---|
| — | — | not started | Authored 2026-07-30. Schedule-ownership decision (§⓪) taken after reading all three providers. |

### Known Issues

_(none yet)_
