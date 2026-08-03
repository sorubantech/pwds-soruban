# PROMPT-14 (T-A20) — Migration spec, user-owned

Backend code for the billing gateway is complete and compiles against the entity model described
below. **The migration has not been created.** Per standing policy the EF migration is authored, run
and committed by you, not by me. This file is the spec to author it from.

```
cd PSS_2.0_Backend/PeopleServe/Services/Base
dotnet build                                   # prove it compiles first
dotnet ef migrations add P14_BillingGateway -p Base.Infrastructure -s Base.API
dotnet ef database update -p Base.Infrastructure -s Base.API
```

The EF configurations already encode every column type, default and index below, so a scaffolded
migration should match this spec without hand-editing. **Diff it against this list before applying**
— if the generated migration is missing an index, the guarantee that index enforces is missing too,
and each one here is load-bearing.

---

## 1. `billing.SubscriptionPayments` — 7 new columns

| Column | Type | Null | Default | Why |
|---|---|---|---|---|
| `GatewayTransactionId` | `varchar(200)` | yes | — | The gateway's own reference; the only handle support has when reconciling a disputed charge. |
| `IdempotencyKey` | `varchar(200)` | yes | — | **The double-charge guard.** See the index below. |
| `FailureCode` | `varchar(100)` | yes | — | Machine-readable decline reason; drives the §6.5 hard-vs-soft branch. |
| `FailureMessage` | `varchar(500)` | yes | — | Human-readable, shown to the tenant. |
| `RawResponse` | `text` | yes | — | Gateway payload. **In the row, never in a log statement.** |
| `AttemptedOn` | `timestamptz` | yes | — | When the charge was tried. |
| `CompletedOn` | `timestamptz` | yes | — | When it settled. Null on a failed attempt. |

```sql
CREATE UNIQUE INDEX "IX_SubscriptionPayments_IdempotencyKey"
  ON billing."SubscriptionPayments" ("IdempotencyKey")
  WHERE "IdempotencyKey" IS NOT NULL AND "IsDeleted" = false;
```

This index **is** the no-double-charge guarantee — not the application logic that reads it first.
Two concurrent checkout requests, or a renewal retry racing a webhook, both resolve to the same key;
the database refuses the second insert. Remove the index and the guard becomes a check-then-act race
that will eventually charge a card twice. Nullable + filtered because manually recorded payments
(bank transfer, cheque) have no key and must not collide with each other.

## 2. `billing.TenantPaymentMethods` — new table

| Column | Type | Null | Default |
|---|---|---|---|
| `TenantPaymentMethodId` | `serial` PK | no | — |
| `CompanyId` | `int` FK → `app."Companies"` | no | — |
| `PlatformPaymentGatewayId` | `int` FK → `ops."PlatformPaymentGateways"` | no | — |
| `GatewayCustomerId` | `varchar(200)` | yes | — |
| `GatewayToken` | `varchar(500)` | no | — |
| `Brand` | `varchar(50)` | yes | — |
| `Last4` | `varchar(4)` | yes | — |
| `ExpiryMonth` | `int` | yes | — |
| `ExpiryYear` | `int` | yes | — |
| `IsDefault` | `boolean` | no | `false` |
| + `Entity` audit columns | | | |

```sql
CREATE UNIQUE INDEX "IX_TenantPaymentMethods_DefaultPerCompany"
  ON billing."TenantPaymentMethods" ("CompanyId")
  WHERE "IsDefault" = true AND "IsDeleted" = false;
```

**`Last4` is four characters because four characters is all we are permitted to hold.** There is no
PAN column, no CVV column, and `GatewayToken` is the gateway's vault reference — useless to anyone
who steals the database, because it can only be replayed against our own merchant account. Do not
add a "full card number for reconciliation" column later; that single column moves the whole
application into PCI scope.

The filtered unique index makes "the default card" a database fact rather than a convention. Without
it, a failed swap leaves two defaults and the renewal job silently picks one at random.

## 3. `ops.PlatformPaymentGateways` — new table

| Column | Type | Null | Default |
|---|---|---|---|
| `PlatformPaymentGatewayId` | `serial` PK | no | — |
| `GatewayCode` | `varchar(50)` | no | — |
| `GatewayName` | `varchar(200)` | no | — |
| `GatewayEnvironment` | `varchar(20)` | no | `'sandbox'` |
| `MerchantId` / `ApiKey` / `ApiSecret` / `WebhookSecret` / `PublicKey` / `ExtraConfig` | `text` | yes | — |
| `Priority` | `int` | no | `0` |
| + `Entity` audit columns | | | |

```sql
CREATE UNIQUE INDEX "IX_PlatformPaymentGateways_CodeEnvironment"
  ON ops."PlatformPaymentGateways" ("GatewayCode", "GatewayEnvironment")
  WHERE "IsDeleted" = false;
```

**No `CompanyId`, deliberately and permanently.** This is the platform's own merchant account —
money flowing *from* tenants *to* us. `fund.CompanyPaymentGateways` is the opposite direction and
must never be conflated with it. If a future change adds a `CompanyId` here, the platform has
started charging tenants through the tenants' own gateways.

The credential columns hold AES-GCM ciphertext produced by `EncryptForPlatform` (`v2:` prefix, a
platform-scoped HKDF label). They are **write-only from the API's perspective**: no query returns
them. The environment pair in the unique key is what lets sandbox and production credentials coexist
as separate rows with exactly one live at a time.

## 4. `ops.PlatformGatewayCurrencies` — new table

| Column | Type | Null | Default |
|---|---|---|---|
| `PlatformGatewayCurrencyId` | `serial` PK | no | — |
| `PlatformPaymentGatewayId` | `int` FK | no | — |
| `CurrencyId` | `int` FK → `shared."Currencies"` | no | — |
| `IsEnabled` | `boolean` | no | `true` |
| + `Entity` audit columns | | | |

```sql
CREATE UNIQUE INDEX "IX_PlatformGatewayCurrencies_GatewayCurrency"
  ON ops."PlatformGatewayCurrencies" ("PlatformPaymentGatewayId", "CurrencyId")
  WHERE "IsDeleted" = false;
```

An empty matrix means **no currency is chargeable**, by design. The resolver fails closed. This
reads as broken on a fresh install and is the correct behaviour: an absent matrix blocks a checkout,
whereas a guessed one charges in a currency the gateway will later reject or reverse — after the
tenant's card has already been debited.

## 5. `ops.PlatformWebhookLogs` — new table

| Column | Type | Null | Default |
|---|---|---|---|
| `PlatformWebhookLogId` | `serial` PK | no | — |
| `PlatformPaymentGatewayId` | `int` FK | no | — |
| `CompanyId` | `int` FK | **yes** | — |
| `GatewayEventId` | `varchar(200)` | yes | — |
| `EventType` | `varchar(100)` | yes | — |
| `RawPayload` | `text` | yes | — |
| `ProcessingStatus` | `varchar(30)` | no | — |
| `ProcessingNotes` | `varchar(1000)` | yes | — |
| `ReceivedOn` | `timestamptz` | no | — |
| `ProcessedOn` | `timestamptz` | yes | — |
| + `Entity` audit columns | | | |

```sql
CREATE UNIQUE INDEX "IX_PlatformWebhookLogs_GatewayEvent"
  ON ops."PlatformWebhookLogs" ("PlatformPaymentGatewayId", "GatewayEventId")
  WHERE "GatewayEventId" IS NOT NULL AND "IsDeleted" = false;
```

**`CompanyId` is nullable on purpose** — the one place in the codebase where a tenant column may be
null. A webhook that cannot be matched to a subscription still has to be recorded (as `Ignored`,
answered `200`, with `CompanyId` null), because an unmatched callback is exactly the evidence you
need when a charge is disputed. Note this differs from `fund.PaymentWebhookLogs`, where `CompanyId`
is non-nullable; the two tables are not interchangeable.

The unique index turns a replayed webhook into a caught constraint violation rather than a second
invoice. Gateways retry aggressively and will deliver the same event three times on a slow response.

## 6. `billing.Subscriptions` — 5 new columns

| Column | Type | Null | Default | Why |
|---|---|---|---|---|
| `AutoRenew` | `boolean` | no | `true` | Off means the subscription lapses at period end instead of being charged. |
| `GatewaySubscriptionId` | `varchar(200)` | yes | — | **A mandate handle, not a schedule** (§⓪). Nothing reads it to decide *when* to bill. |
| `DunningAttemptCount` | `int` | no | `0` | Position in the §6.5 ladder; reset to 0 on success. |
| `LastDunningAttemptOn` | `timestamptz` | yes | — | The ladder's clock — retry timing is reconstructed from this, so no extra schedule column is needed. |
| `GracePeriodEndsOn` | `timestamptz` | yes | — | Set on the first failure only; suspension happens when it passes. |

The existing filtered `UNIQUE ("CompanyId") WHERE "Status" IN ('TRIAL','ACTIVE','PASTDUE')` stays as
it is. `PastDue` is inside that set on purpose: a tenant who has failed to pay still holds their one
active subscription slot and must not be able to start a second one.

---

## After the migration

1. Apply `sql-scripts-dyanmic/billing-gateway-platform-seed.sql`, **then restart the API** (the
   platform settings snapshot is cached at startup).
2. Configure gateway credentials and the currency matrix **through the ops UI, not SQL** — the
   values must be encrypted with the running master key. Blocked until §⑦ FE exists (Known Issue 1).
3. Leave `PLATFORM_GATEWAY_ENVIRONMENT = 'sandbox'` until the §⑨ acceptance list passes.
4. Register `https://<host>/api/webhooks/platform/{gatewayCode}` in each gateway dashboard and store
   the webhook secret through the UI.

## Still needed from you

- USD price points for `PLAN_50K` and `PLAN_100K`.
- Braintree's actually-enabled currency list — this becomes the §3.3 matrix.
- Sandbox and production credentials per gateway, and who holds them.
- Confirmation of the grace/retry numbers if `14` days, retries at day `3,7`, max `3` attempts are wrong.
- Bodies for the five billing email templates (Known Issue 2).
