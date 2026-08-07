# PSS 2.0 — ONBOARDING PROMPT 14 — Billing Gateway (platform gateway config · checkout · webhook · renewal · dunning)

**Task ID:** T-A20 (P2 phase — the second half of self-serve billing)
**Surface:** ~~BE (platform gateway config + encryption · gateway↔currency matrix · platform billing payment service · checkout pair · platform webhook route · renewal job · dunning ladder)~~ **✅ COMPLETE — session 1, 2026-07-31** · **FE (tenant checkout + payment method + auto-renew · ops gateway config screen + webhook log viewer) — ⬅ THE REMAINING SCOPE**
**Model:** Sonnet — but see §⑪; §④ (the schedule-ownership decision) and §⑧ (webhook idempotency) are the two places to slow down.
**Depends on:** **PROMPT-13 must be merged and its migration applied.** This prompt writes into `billing.Invoices`, `billing.SubscriptionPayments` and `IPlatformSettingsService`, all of which PROMPT-13 creates. It also assumes §③b pricing resolution is live.

> **Blueprint:** `PSS-2.0-SELF-SERVE-UPGRADE-AND-BILLING-APPROACH.md` — §④ payment integration, §④a separate ops service, §④b capability matrix, §⑤ backend, §⑥ frontend, §⑦ guards, §⑧ phasing.

---

## ⚠️ FE-ONLY SESSION — START HERE

The backend half of this prompt is **built and on disk** (verified against the tree 2026-07-31; file list in
§⑬ session 1). This session builds **§⑦ and nothing else**.

**How to read this file:**

| Section | Your relationship to it |
|---|---|
| §⓪ | **Read it.** It explains why there is no gateway-side subscription object, which is why the checkout screen charges per-cycle and says so. |
| §③ §④ §⑤ §⑥ §⑧ | **Reference, not work.** These describe contracts that already exist. Read the ones your screens consume; do **not** re-implement, re-shape, or "improve" them. |
| **§⑦** | **The build.** |
| §⑨ | Narrowed — see §9.0 for the FE-session subset. |
| §⑪ | **Read it.** The HotChocolate naming trap is the single most likely way this session ships something broken. |

**Do not touch the backend.** No new commands, queries, DTOs, entities, EF configs, resolvers, or
`Program.cs`/DI edits. If a field you need is genuinely absent from the built API, **stop and record it in
§⑬ Known Issues** rather than adding it — a BE change here would collide with the migration the user has
not yet applied.

**No migration, ever.** `git status` at the end of this session must show **no** new file under
`Migrations/` and **no** change to `ApplicationDbContextModelSnapshot.cs`. The §⑫ migration is still
outstanding and user-owned; a second one authored now would silently merge against a stale snapshot.

**The GraphQL surface you are binding to (already built — these are the real, `Get`-stripped names):**

| Operation | GraphQL field | Source |
|---|---|---|
| Tenant billing overview | `myBillingOverview` | `Billing/Queries/BillingQueries.cs` |
| Sellable plans + `canSelfServe` / `selfServeBlockedReason` | `mySellablePlans` | same |
| Tenant invoices (paginated) | `tenantInvoices` | same |
| Start a checkout | `initiateSubscriptionCheckout` | `Billing/Mutations/BillingMutations.cs` |
| Complete a checkout | `confirmSubscriptionPayment` | same |
| Auto-renew toggle | `setAutoRenew` | same |
| Ops gateway config read | `platformGatewayConfig` | `Billing/Queries/PlatformGatewayQueries.cs` |
| Ops webhook log list | `platformWebhookLogs` | same |
| Ops webhook log detail | `platformWebhookLogById` | same |
| Ops gateway upsert | `upsertPlatformPaymentGateway` | `Billing/Mutations/PlatformGatewayMutations.cs` |
| Ops currency matrix save | `savePlatformGatewayCurrencies` | same |
| Ops environment switch | `setPlatformGatewayEnvironment` | same |
| Pricing policy read / save | `platformPricingPolicy` / `savePlatformPricingPolicy` | `BillingQueries.cs` / `BillingMutations.cs` |

Input types get `Input` **appended** (`UpsertPlatformPaymentGatewayDto` → `UpsertPlatformPaymentGatewayDtoInput`).
**Verify every field name and every argument against the running schema before writing the document** —
`tsc` cannot see gql strings, so a wrong name compiles clean and fails only in the browser. Read the
resolver's actual signature and its result DTO; do not infer property names from this table.

Audit fields are `createdDate` / `modifiedDate` — never `createdAt` / `modifiedAt`.

**Expect runtime errors until the §⑫ migration is applied.** The `ops.PlatformPaymentGateways`,
`ops.PlatformGatewayCurrencies`, `ops.PlatformWebhookLogs` and `billing.TenantPaymentMethods` tables do
not exist in the database yet. Any screen that reads them will throw a Postgres "relation does not
exist". That is **not** an FE bug and must not be worked around by mocking, try/catching, or changing the
query — build against the real contract, note it in §⑬, and let the user apply the migration.

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

## ⑦ FE — **this session's entire scope**

### 7.0 Where the code goes

What exists today (PROMPT-13): `src/app/(core)/billing/page.tsx`, `billing/invoices/`, `billing/plans/`.
Under `(master)/platform/` there is only `dashboards/`. So: **extend these route groups, do not
restructure them.** New routes are `(core)/billing/checkout/` and `(master)/platform/gateways/` (config)
plus `(master)/platform/webhook-logs/` (log viewer) — reuse the existing platform layout and nav
patterns rather than inventing a second shell.

Follow the house conventions already in `billing/plans/` for DTO placement, GraphQL document location,
and service wiring. Search the component registries first: reuse what exists, create only what is
genuinely missing and static, escalate anything that would need a new MASTER_GRID or FLOW primitive.

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

### 9.0 FE-session subset — read this first

Items **1, 2, 3, 5, 23, 25** are the ones this session owns and can verify from the UI. Items **4, 6–22,
24** are backend behaviour already implemented; they are **not** re-verified here — several are blocked on
the unapplied migration and on sandbox credentials the user has not supplied (§⑫.6). Do not claim them.

Two additions specific to this session:

- **26. No BE drift.** `git status` shows changes under `PSS_2.0_Frontend/` only — no new migration, no
  edit to `ApplicationDbContextModelSnapshot.cs`, no new/modified `.cs` file.
- **27. Every gql field resolves.** Each new query and mutation is executed once against the running API
  (browser or playground) and returns without an "unknown field" error. This is the only check that
  catches the §⑪ `Get`-stripping trap; `tsc` will not.

Note that items 1–3 exercise the *fail-closed* paths, which are testable **without** any gateway
configured — an empty `ops.PlatformPaymentGateways` is the correct starting state for this session.

_(Original full list follows; sandbox credentials required for 6–11.)_

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
| 1 | 2026-07-31 | **Backend complete (§③–§⑥, §⑧). FE deferred by user instruction.** Platform encryption overload (`EncryptForPlatform`/`DecryptForPlatform`, own HKDF label — a tenant subkey cannot read a platform ciphertext); 4 entities + EF configs (`PlatformPaymentGateway`, `PlatformGatewayCurrency`, `PlatformWebhookLog`, `TenantPaymentMethod`) + 12 columns on existing billing tables; `IPlatformGatewayResolver` (fail-closed on no config **and** on an empty currency matrix); `IPlatformBillingPaymentService` (the only seam that touches `IPaymentService` — no command sees a `PaymentGatewayConfiguration`); `canSelfServe` gateway clause + `NO_GATEWAY_FOR_CURRENCY`; ops queries/mutations (credentials write-only, blank = unchanged); `InitiateSubscriptionCheckout` / `ConfirmSubscriptionPayment` / `SetAutoRenew`; `SubscriptionRenewalService` (4 passes: renew → dunning → suspend → trial-expiry) on a daily 03:00 UTC Hangfire cron; platform webhook endpoint with signature verification + duplicate/repair handling; seed `billing-gateway-platform-seed.sql`. | §⓪ held throughout — no gateway-side plan object anywhere; `GatewaySubscriptionId` is only a mandate handle. Renewal job needs no MediatR command (a renewal never re-prices), which sidesteps the `AuthorizationBehavior` HttpContext trap; every read uses `IgnoreQueryFilters()` because a cron carries no tenant. Idempotency is the DB's job: `UNIQUE(IdempotencyKey)` + a deterministic `sub-{id}-period-{yyyyMMdd}` key means a retry updates the existing row instead of inserting a second charge. Dunning cadence read from settings, not constants. **Not built:** all of §⑦ (FE), by user instruction. **Not run:** `dotnet build` (user-owned), migration, seed. |
| 2 | 2026-07-31 | **Frontend complete (§⑦ only). Backend untouched.** Tenant: `/billing/checkout` (order summary + "charged X now, then X every cycle", nonce-only drop-in, `FailureKind`-classified declines, double-submit disabled); plans cards route to checkout on `canSelfServe` else render the specific `selfServeBlockedReason` incl. `NO_GATEWAY_FOR_CURRENCY`; auto-renew toggle stating what happens at period end; past-due banner. Ops: `/platform/gateways` (card per gateway, environment/merchant/credentials/priority + currency matrix multi-select, **credentials write-only — masked when set, blank submit = unchanged**), `/platform/webhook-logs` (read-only ledger + detail dialog), gateway-environment panel on the pricing-policy surface with an explicit production confirm, and a per-tenant **Gateway activity** section + PastDue dunning banner on the tenant Subscription panel. `/platform/billing` is a redirect so the seeded `MenuUrl` lands somewhere. | `npx tsc --noEmit --incremental false` → **exit 0, no output** (verified in `PSS_2.0_Frontend`, not a zero-file run). No BE file touched, no `Migrations/` file added, `ApplicationDbContextModelSnapshot.cs` unchanged. Every resolver name/arg was read out of `PlatformGatewayQueries.cs` / `PlatformGatewayMutations.cs` on disk rather than assumed — `tsc` cannot see gql strings. Two substitutions made honestly rather than inventing BE: the ops per-tenant payment history is built from `platformWebhookLogs(companyId:)` because no per-tenant payment read exists, and the dunning banner states on screen that attempt count / grace end are not returned by `subscriptionForCompany`. **Acceptance 27 (execute each operation against the running API) NOT done** — see Known Issue 13. |

### Backend inventory — verified on disk 2026-07-31 (reference for the FE session)

Base path `PSS_2.0_Backend/PeopleServe/Services/Base/`.

- `Base.Application/BusinessLogics/BillingBusiness/PlatformPolicy/Commands/` — `UpsertPlatformPaymentGateway.cs`, `SavePlatformGatewayCurrencies.cs`, `SetPlatformGatewayEnvironment.cs`, `SavePlatformPricingPolicy.cs`, `SetTenantSelfServe.cs`
- `…/PlatformPolicy/Queries/` — `GetPlatformGatewayConfig.cs`, `GetPlatformPricingPolicy.cs`, `GetPlatformWebhookLogs.cs`, `GetPlatformWebhookLogById.cs`
- `…/BillingBusiness/TenantBilling/Commands/` — `InitiateSubscriptionCheckout.cs`, `ConfirmSubscriptionPayment.cs`, `SetAutoRenew.cs`
- `Base.API/EndPoints/Billing/` — `Queries/PlatformGatewayQueries.cs`, `Mutations/PlatformGatewayMutations.cs` (plus the tenant operations on `BillingQueries.cs` / `BillingMutations.cs`)
- `Base.API/Controller/PlatformBillingWebhookController.cs`
- `Base.Application/Services/PlatformBilling/` — `IPlatformBillingPaymentService.cs`, `ISubscriptionRenewalService.cs`, `SubscriptionRenewalService.cs` (§6.4 renewals + §6.5 dunning, cadence from `PlatformSettingCodes.Billing*`)
- `Base.Support/Payment/Platform/` — `IPlatformGatewayResolver.cs`, `PlatformGatewayResolver.cs`, `PlatformBillingPaymentService.cs`
- `Base.API/Extensions/SubscriptionRenewalRegistrationExtension.cs` — daily 03:00 UTC Hangfire cron
- `ops` entities + configs: `PlatformPaymentGateway`, `PlatformGatewayCurrency`, `PlatformWebhookLog`; `billing.TenantPaymentMethods` + the 12 added columns
- Seed: `sql-scripts-dyanmic/billing-gateway-platform-seed.sql` — **written, not applied**

**Migration status — corrected 2026-07-31, session 2.** The line that stood here said no PROMPT-14
migration existed. That is no longer true: `Migrations/20260731075733_Add_PlatformPaymentGateways.cs`
(+ `.Designer.cs`) is on disk, timestamped 13:27 on 2026-07-31, and `ApplicationDbContextModelSnapshot.cs`
now carries the new tables (28 `PlatformPaymentGateway` references). **It was generated by the user, not
by this session** — the FE session touched no file outside `PSS_2.0_Frontend/`. It is recorded here only
so the next reader is not misled; whether it has been *applied* to the database is a separate question
(Known Issue 14). Migrations remain user-owned (§⑫.2). Note that the backend tree is gitignored, so no
migration ever appears in `git status` — the check has to be made against the filesystem.

### Frontend inventory — written session 2, 2026-07-31

Base path `PSS_2.0_Frontend/src/`.

- Routes (thin wrappers): `app/[lang]/(core)/billing/checkout/page.tsx`,
  `app/[lang]/(master)/platform/gateways/page.tsx`, `…/platform/webhook-logs/page.tsx`,
  `…/platform/billing/page.tsx` (redirect — the seeded `MenuUrl` is `/platform/billing`, see Known Issue 7)
- Tenant: `presentation/components/page-components/billing/billing-checkout-page.tsx` (new);
  `billing-overview-page.tsx`, `billing-plans-page.tsx`, `billing-format.ts`, `index.ts` (edited)
- Ops: `page-components/ops/gateways/` — `platform-gateway-config-page.tsx`, `gateway-form-dialog.tsx`, `index.ts` (all new);
  `page-components/ops/webhooklogs/` — `platform-webhook-logs-page.tsx`, `index.ts` (new);
  `ops/plans/platform-gateway-environment-panel.tsx` (new, wired into `plan-matrix-page.tsx`);
  `ops/tenants/tenant-gateway-activity.tsx` (new, wired into `tenant-subscription-panel.tsx`)
- Contracts: `domain/entities/ops-service/BillingDto.ts`, `infrastructure/gql-queries/ops-queries/BillingQuery.ts`,
  `application/configs/navigation-configs/BaseUrlConfig.ts`

### Known Issues

| # | Issue | Impact | Status |
|---|---|---|---|
| 1 | Frontend (§⑦) not built — no checkout screen, no payment-method card, no auto-renew toggle, no ops gateway-config or webhook-log screens. | The backend is unreachable from the UI: gateway credentials **cannot be entered at all** until the ops screen exists (SQL insert is not an option — see the seed file header). Nothing is chargeable end-to-end yet. | **CLOSED** 2026-07-31 (session 2) — all of §⑦ built except the payment-method card, which has no contract to bind to (Known Issue 5). |
| 2 | Five billing email templates are not seeded: `BILLING_RENEWAL_RECEIPT`, `BILLING_PAYMENT_FAILED`, `BILLING_FINAL_NOTICE`, `BILLING_SUSPENDED`, `BILLING_TRIAL_EXPIRED`. | The renewal job degrades safely (a missing template makes the send skip and return false, the charge still settles) but tenants get **no notice at all** — they discover a failed renewal by being suspended. | **OPEN** — needs template bodies from the business, then a `notify.EmailTemplates` seed. |
| 3 | `ConfirmSubscriptionPaymentResult.Status_Subscription` surfaces in GraphQL as `status_Subscription`. | Cosmetic; an odd field name in the schema. | **OPEN** — rename to `SubscriptionStatus` when the FE binds it (§⑦), before any client depends on the current name. |
| 4 | Acceptance §9.6–§9.11 (happy path, decline, concurrent double-charge, renewal double-charge, webhook duplicate, webhook-as-repair) cannot be executed. | The idempotency guarantees are argued from the schema, not yet demonstrated against a real gateway. | **BLOCKED** — needs sandbox credentials. The §⑦ FE half of the blocker is now cleared. Run before any production switch. |
| 5 | **No payment-method API exists at all.** There is no query returning a saved card and no mutation to update or remove one; `billing.TenantPaymentMethods` is written by `ConfirmSubscriptionPayment` and never read out. The only signals a client can see are `setAutoRenew.hasDefaultPaymentMethod` (a bool) and `confirmSubscriptionPayment.paymentMethodSaved`. | §7.1's payment-method card (brand, `•••• last4`, expiry, Update, Remove — and the "removing the default while AutoRenew is on will fail the renewal" warning) **could not be built**. The tenant can see *that* a card is on file, not *which*, and cannot replace or remove it without going through a fresh checkout. | **QUEUED → PROMPT-16 §①** — `GetMyPaymentMethodQuery` (brand/last4/expiry/isDefault only — never the vault token) plus `SetDefaultPaymentMethod` / `RemovePaymentMethod`. Removal must refuse, or warn-and-confirm, while `AutoRenew` is on; it must **not** silently flip AutoRenew off. |
| 6 | `subscriptionForCompany` (`GetSubscriptionForCompany.cs:21-50`) returns **no payment collection and no dunning fields**, although `Subscription.DunningAttemptCount` / `LastDunningAttemptOn` / `GracePeriodEndsOn` exist on the entity and *are* returned by the tenant-facing `myBillingOverview`. | The ops tenant-detail panel cannot show real gateway payment rows or a real attempt count / grace end. Built instead from `platformWebhookLogs(companyId:)` — the settlement callbacks — and the PastDue banner says on screen that the counters are not returned by this query rather than inventing them. Callbacks the platform could not match to a tenant carry no `companyId` and so never appear in the per-tenant view. | **QUEUED → PROMPT-16 §⑤** — add the dunning fields and a payment list to `SubscriptionForCompanyResult`, then swap the tenant panel over. |
| 7 | Route discrepancy: the seed sets `MenuUrl = /platform/billing`, but §7.0 specifies `/platform/gateways` (config) and `/platform/webhook-logs` (logs). | A seeded menu item would 404. | **MITIGATED** — `/platform/billing` is a redirect to `/platform/gateways`. Decide which is canonical and fix the seed, then drop the redirect. |
| 8 | Capability mismatch on the environment switch: §7.2 puts it on the PROMPT-13 pricing-policy surface, which is gated `PLATFORM_PLAN_*`, but `setPlatformGatewayEnvironment` requires `PLATFORM_BILLING_MANAGE`, and `platformPricingPolicy` carries no environment field. | A plan-only operator would see a control the server refuses. | **MITIGATED** — built as a separate panel on the same page, reading `platformGatewayConfig.currentEnvironment` and gated on `PLATFORM_BILLING_MANAGE`, so it is invisible without the capability. |
| 9 | `GetPlatformWebhookLogs` is gated `[CustomAuthorize("PLATFORM_BILLING","PLATFORM_BILLING_MANAGE")]`, not `_VIEW`. | A view-only platform operator cannot read the webhook ledger — a read-only screen needs a write capability. | **QUEUED → PROMPT-16 §②** — both FE gates were matched to the server's so nothing renders that would be refused. Relaxing the query to `PLATFORM_BILLING_VIEW` needs no seed edit; the grants already exist. |
| 10 | The platform billing checkout path never sets `ReturnUrl`, so PayU has no `surl`/`furl` and cannot return the tenant to `/billing`. | For a redirect-style gateway, settlement can only arrive by webhook; the browser is left where it lands. Non-blocking for a drop-in/nonce gateway. | **QUEUED → PROMPT-16 §③** — the return URL belongs on the BE command, not invented by the FE; it lands as a platform setting, and PayU fails closed without it. |
| 11 | `MyBillingOverviewDto` has no outstanding-balance field and no next-retry date. | §7.1's past-due banner is required to name "the amount, the retry date and the suspension date". It can name the suspension date (grace end) and the attempt count; **the amount and the retry date are not available** and the banner points at the invoice instead. | **QUEUED → PROMPT-16 §④, narrowed** — verified on disk 2026-08-03: `MyBillingOverviewResult` **already carries** `DunningAttemptCount` and `GracePeriodEndsOn`, so the attempt count and suspension date are available today. Only `OutstandingAmount`, `NextRetryOn` and `DunningMaxAttempts` are actually missing. |
| 12 | `ConfirmSubscriptionPaymentResult.Status_Subscription` → gql `status_Subscription` (duplicate of #3, now bound). | The checkout screen reads `status_Subscription`. Renaming it is a breaking change from today. | **OPEN** — rename to `SubscriptionStatus`; one FE call site (`billing-checkout-page.tsx`) changes with it. |
| 13 | Acceptance item 27 (execute every new query and mutation once against the running API) **was not performed**. | Field names, argument names and nullability are verified only by reading `PlatformGatewayQueries.cs`, `PlatformGatewayMutations.cs`, `BillingQueries.cs` and `BillingMutations.cs` on disk, plus the HotChocolate naming rules. `tsc` cannot see gql strings, so a wrong name would fail at runtime only. | **OPEN** — `dotnet run` was started and stalled mid-build; the machine ran out of paging file ("The paging file is too small for this operation to complete") and the API never bound its port. Re-run once the API is up: `platformGatewayConfig`, `platformWebhookLogs`, `platformWebhookLogById`, `upsertPlatformPaymentGateway`, `savePlatformGatewayCurrencies`, `setPlatformGatewayEnvironment`, `initiateSubscriptionCheckout`, `confirmSubscriptionPayment`, `setAutoRenew`, `mySellablePlans`. A `relation "ops.…" does not exist` error is the **expected** pre-migration result; an *unknown field/argument* error is a real defect. |
| 14 | The §⑫ migration has not been applied — `ops.PlatformPaymentGateways`, `ops.PlatformGatewayCurrencies`, `ops.PlatformWebhookLogs` and `billing.TenantPaymentMethods` do not exist in the database. | Every new screen will throw "relation does not exist" at runtime. This is **not an FE bug** and was deliberately not worked around: no mocking, no try/catch, no altered query. Each screen shows its error state and a Try again. | **OPEN — user-owned.** See `PSS-2.0-ONBOARDING-PROMPT-14-MIGRATION-SPEC.md`, then apply `sql-scripts-dyanmic/billing-gateway-platform-seed.sql`. |
| 15 | This file's §⑬ backend inventory names `Base.Application/BusinessLogics/BillingBusiness/…`; the real path on disk is `Base.Application/Business/BillingBusiness/…`. | Documentation only — a reader following the path finds nothing. | **QUEUED → PROMPT-16 §⓪** — cosmetic; the correct path is carried in PROMPT-16 and gets fixed here in the same pass. |
| 16 | No menu row existed for `/platform/webhook-logs`. The seed created only `PLATFORM_BILLING` → `/platform/billing`, and the FE redirect bridges that to `/platform/gateways` only. | The webhook-log viewer was built, typechecked and unreachable — the only way in was to type the URL. | **CLOSED** 2026-08-03 — `billing-gateway-platform-seed.sql` §6 now seeds a sibling `PLATFORM_WEBHOOK_LOGS` menu with `PLATFORM_BILLING_VIEW` + `ISMENURENDER` grants for the same four roles. The row is navigation only: `GetPlatformWebhookLogs` still authorizes against the `PLATFORM_BILLING` menu. |
