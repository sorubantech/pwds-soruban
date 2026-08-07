# PROMPT-16 — Billing BE gap closure (P-14 follow-up)

**Blueprint:** PSS-2.0-ONBOARDING-PROMPT-14-BILLING-GATEWAY.md §⑬ Known Issues
**Surface:** **BE only.** No frontend file is touched by this session.
**Depends on:** PROMPT-13 (billing foundation) and PROMPT-14 (platform gateway) — both built.
**Migration:** `20260731075733_Add_PlatformPaymentGateways` must already be applied.

---

## ⚠️ BE-ONLY SESSION — START HERE

This session exists because the PROMPT-14 **frontend** session hit five backend contracts that
did not exist, and — correctly — refused to invent them. Each gap below was recorded in P-14 §⑬
with the screen it blocked. This session closes them and nothing else.

**Rules for this session, all of them hard:**

| Rule | Detail |
|---|---|
| **Do not touch the frontend** | No file under `PSS_2.0_Frontend/`. The FE work is a separate session that follows this one. If you believe an FE change is required, write it into §⑦ below, don't make it. |
| **Do not run `dotnet build`** | The user builds. Write code that compiles by inspection; read the surrounding file before you add to it. |
| **Do not author a migration** | Gap 1 adds *queries and commands over an existing table*; gaps 2–5 add *fields to result records*. **Nothing here needs a schema change.** If you find yourself reaching for `dotnet ef migrations add`, stop — you have misread the gap. Write the schema need into §⑧ and leave the code compiling without it. |
| **Verify every property name** | Never assume a column, DTO property or GraphQL field name. Read the entity or the resolver first. Audit fields are `createdDate` / `modifiedDate`. |
| **UTC only** | Every Postgres date column is `timestamp with time zone`; Npgsql throws on `Kind = Unspecified`. `DateTime.UtcNow`, never `DateTime.Today` inside an EF predicate. |
| **HotChocolate naming** | `Get` is stripped from every resolver (`GetMyPaymentMethod` → `myPaymentMethod`); input types get `Input` appended. A wrong name compiles clean and fails only at runtime — so §⑨ requires you to execute each new field once. |

---

## ⓪ Where the code lives (read before writing)

```
Base.Domain/Models/BillingModels/TenantPaymentMethod.cs          ← the entity (exists, unchanged)
Base.Infrastructure/Data/Configurations/BillingConfigurations/
    TenantPaymentMethodConfiguration.cs                          ← the filtered unique index
Base.Application/Business/BillingBusiness/
    TenantBilling/Queries/GetMyBillingOverview.cs                ← gap 4
    Subscriptions/Queries/GetSubscriptionForCompany.cs           ← gap 5
    PlatformPolicy/Queries/GetPlatformWebhookLogs.cs             ← gap 2
    PlatformPolicy/Queries/GetPlatformWebhookLogById.cs          ← gap 2
    Checkout/…  (InitiateSubscriptionCheckout)                   ← gap 3
Base.Application/Services/PlatformBilling/                       ← providers + renewal service
Base.API/EndPoints/Billing/Queries/BillingQueries.cs             ← tenant resolvers
Base.API/EndPoints/Billing/Mutations/BillingMutations.cs         ← tenant resolvers
```

Note the real path segment is `Business/BillingBusiness/`, **not** `BusinessLogics/` — an earlier
inventory in P-14 §⑬ got this wrong (Known Issue 15). Correct it there while you are in the file.

---

## ⓪b The menus these gaps sit behind — read this before writing a `[CustomAuthorize]`

The tenant billing surface is **a parent header plus three leaves**, seeded by
`sql-scripts-dyanmic/billing-capability-seed.sql` under the always-on `SETTING` module:

| MenuCode | Menu | Route | Screen |
|---|---|---|---|
| `BILLING` | *Billing* (header, **no URL**) | — | not a page |
| `BILLING_OVERVIEW` | Overview | `/billing` | current plan, usage, renewal, **payment method** |
| `BILLING_PLANS` | Plans | `/billing/plans` | published plans, upgrade entry point |
| `BILLING_INVOICES` | Invoices | `/billing/invoices` | invoice history and payment status |

The parent carries no URL on purpose: `mapMenuToClassicConfig` renders every top-level menu as a
non-clickable header and links only its children, so a single top-level `BILLING` row with
`MenuUrl = '/billing'` would render as dead label text.

### The rule that actually matters here

**`HasAccessAsync` matches on `MenuCode` only, and every existing billing resolver authorizes
against the parent code `BILLING`.** So:

> **Every new tenant-side query and command in this prompt is gated
> `[CustomAuthorize("BILLING", "BILLING_VIEW")]` or `[CustomAuthorize("BILLING", "BILLING_MANAGE")]`
> — the parent code, never a leaf code.**

Gating on `BILLING_OVERVIEW` would compile, read plausibly, and **fail at runtime for every user**:
the leaf rows carry `ISMENURENDER` (that is what draws them in the sidebar) and the VIEW/MANAGE
grants that let the API through are on the parent. Two different checks, two different rows — the
seed header spells this out and it is the easiest thing in this codebase to get backwards.

The ops-side equivalents are `PLATFORM_BILLING` (gateway config, §7.2 screens) and
`PLATFORM_WEBHOOK_LOGS` (navigation only — see §② below, and P-14 Known Issue 16).

### Which screen each gap serves

| Gap | Lands on | Menu |
|---|---|---|
| §① payment method | Overview — the card beside the renewal block | `BILLING_OVERVIEW` |
| §③ PayU return leg | a new `/billing/checkout/result` route | none — see below |
| §④ past-due banner | Overview, above the plan block | `BILLING_OVERVIEW` |
| §⑤ ops payment history | ops tenant detail panel | `PLATFORM_TENANTS` (unchanged) |

**Checkout gets no menu row, and neither does the return leg.** `/billing/checkout` and
`/billing/checkout/result` are transient flows entered from the Plans screen and returned to by a
gateway. A sidebar entry for a checkout you are not currently in the middle of is a dead link — and
the return route is meaningless without the `?ref=` a gateway supplies. They are reachable because
they are routes, not because they are menus. **Do not seed them.**

Two further things not to do: do not add any `BILLING_*` code to `MenuFeatureMap` — billing must stay
reachable on every plan including a lapsed one, which is the whole reason it lives under `SETTING` —
and do not add a fourth leaf for the payment method. It is a card on Overview, not a page.

---

## ① Gap 1 — Payment method has no read or management API *(P-14 Known Issue 5 — the big one)*

**The state today.** `billing.TenantPaymentMethods` is **written** by `ConfirmSubscriptionPayment`
when `saveForFuture: true`, and **never read out**. No query returns a saved instrument; no mutation
sets a default or removes one. The only signals the FE has are a bare boolean
(`setAutoRenew.hasDefaultPaymentMethod`) and `confirmSubscriptionPayment.paymentMethodSaved`.

**The consequence.** P-14 §7.1's payment-method card could not be built. A tenant with auto-renew on
cannot see which card will be charged, cannot replace an expiring one, and cannot remove it — while
the renewal job charges it every cycle. That is the single worst gap in the billing surface.

### 1.1 `GetMyPaymentMethodQuery`

* No arguments. `CompanyId` comes from `ITenantContext`, **never** from the caller — a tenant-supplied
  companyId on a billing query is a cross-tenant disclosure, and no downstream filter makes an
  accepted argument safe. Follow the fail-closed pattern already in `GetMyBillingOverviewHandler`:
  `companyId is null or <= 0` → return the empty result, never "the first company".
* Gated `[CustomAuthorize("BILLING", "BILLING_VIEW")]` — the **parent** menu code, same as the
  overview. Not `BILLING_OVERVIEW`; see §⓪b.
* Returns the tenant's **default, non-deleted** method, or null.

```csharp
public record MyPaymentMethodResult(
    int? TenantPaymentMethodId,
    string? MethodType,      // CARD | UPI | NETBANKING | MANDATE
    string? Brand,
    string? Last4,
    int? ExpiryMonth,
    int? ExpiryYear,
    string? HolderName,
    bool IsDefault,
    string? GatewayCode,     // which platform gateway vaulted it — a sandbox token is inert in production
    bool IsExpired,          // server-derived, see 1.2
    bool ExpiresSoon);       // server-derived, see 1.2
```

> **`GatewayTokenId` NEVER LEAVES THE BACKEND.** It is not on this record, not on any other DTO,
> not in a log line, not in an error message. It is the credential. The whole reason the FE collects
> a gateway nonce and renders no card field of its own is to keep PCI scope at the gateway iframe;
> returning the vault token drags it straight back over the fence. Same for PAN and CVV, which we
> never hold in the first place — `Last4` is the only part of the number that exists in our database.

### 1.2 Expiry derivation belongs on the server

`IsExpired` and `ExpiresSoon` are computed in the handler, not in the browser. A card expires
against **UTC now**, and the client clock is neither trustworthy nor in our timezone.

* `IsExpired` — true when `ExpiryYear`/`ExpiryMonth` are present and the **last instant of that
  month** is in the past. A card marked `06/2028` is valid through 30 June 2028, not through 1 June.
* `ExpiresSoon` — true when it expires within the next 60 days and is not already expired. Sixty
  days covers two monthly renewal attempts, so the tenant is warned before the first failure, not
  after it.
* Both false when the fields are null (UPI and mandate methods have no expiry — that is not "expired").

### 1.3 `SetDefaultPaymentMethodCommand`

* Argument: `int tenantPaymentMethodId`. Gated `[CustomAuthorize("BILLING", "BILLING_MANAGE")]`.
* **Load the row scoped by `CompanyId` from the token.** Never `FindAsync(id)` alone — an
  unscoped lookup on a caller-supplied id is a cross-tenant write, and it is the exact shape of bug
  this codebase's tenant filter is meant to prevent.
* The table carries `UNIQUE (CompanyId) WHERE IsDefault = true AND IsDeleted = false`. So clearing
  the old default and setting the new one **must happen in one `SaveChangesAsync`**, or the
  intermediate state violates the index and the whole operation throws. Clear first, set second,
  save once.
* Idempotent: setting the current default as default is a success, not an error.

### 1.4 `RemovePaymentMethodCommand`

* Argument: `int tenantPaymentMethodId`. Same capability, same tenant scoping.
* Soft delete (`IsDeleted = true`) — the audit trail behind past charges must survive.
* **Guard: refuse to remove the last remaining default while `AutoRenew` is true on a live
  subscription.** Removing it does not stop the renewal; it makes the renewal *fail*, which lands the
  tenant in the dunning ladder for a reason they chose and did not understand. Return a failure whose
  message names the fix: *turn auto-renew off first, or add a replacement method.* An explicit refusal
  is far kinder than a silent path to suspension.
* Also detokenize at the gateway where the provider supports it (Braintree `PaymentMethod.Delete`).
  If that call fails, **still soft-delete locally** and log — a stranded vault token at the gateway is
  a housekeeping problem; a row we cannot remove is a support ticket. Never surface the token in that
  log line.

### 1.5 Resolvers

Add to `Base.API/EndPoints/Billing/`. After `Get`-stripping these become
`myPaymentMethod`, `setDefaultPaymentMethod`, `removePaymentMethod`. Give the id parameters **no
default value** so they render as `Int!` — a defaulted `int x = 0` renders `Int! = 0` and quietly
accepts a call that forgot to pass one.

---

## ② Gap 2 — A read-only screen requires a write capability *(Known Issue 9)*

`GetPlatformWebhookLogs` and `GetPlatformWebhookLogById` are both decorated
`[CustomAuthorize("PLATFORM_BILLING", "PLATFORM_BILLING_MANAGE")]`. The webhook-log viewer reads
traffic — it changes nothing. Requiring MANAGE means PLATFORM_FINANCE and PLATFORM_SUPPORT, the two
roles that actually triage a failed payment, cannot open the log without also being handed the power
to enter a merchant credential and flip the platform to production.

**Fix:** change the required capability on **both** queries to `PLATFORM_BILLING_VIEW`.
`GetPlatformGatewayConfig` **keeps MANAGE** — it is the credential-configuration screen, and although
it returns no secrets it does enumerate merchant identifiers.

The seed already grants `PLATFORM_BILLING_VIEW` to PLATFORM_ADMIN, SUPERADMIN, PLATFORM_FINANCE and
PLATFORM_SUPPORT, so this change needs **no seed edit** — it starts working the moment the attribute
changes. Verify that claim against `sql-scripts-dyanmic/billing-gateway-platform-seed.sql` §5 before
you rely on it.

---

## ③ Gap 3 — Checkout never sets a return URL, so PayU cannot complete *(Known Issue 10)*

`ReturnUrl` does not appear anywhere in the billing business layer or the platform-billing services —
grep confirms zero occurrences. PayU is a **redirect** gateway: it requires `surl` (success URL) and
`furl` (failure URL) on the request, and without them the hosted page has nowhere to send the payer
back. Braintree and Razorpay are nonce/handle flows and do not need this, which is why the gap went
unnoticed — the two gateways that were tested don't exercise it.

**Fix:**

* Add a platform setting `BILLING_CHECKOUT_RETURN_BASE_URL` (platform-scoped, `CompanyId IS NULL`,
  `CanUserOverride = false`) holding the public origin of the tenant app, e.g.
  `https://app.example.org`. **A setting, not `appsettings.json`** — it differs per environment and
  must be changeable without a deploy, and the same reasoning that put `PLATFORM_GATEWAY_ENVIRONMENT`
  in the database applies here. Read it through `IPlatformSettingsService` exactly as
  `SubscriptionRenewalService` reads the dunning values.
* `InitiateSubscriptionCheckout` composes `{base}/billing/checkout/result?ref={subscriptionPaymentId}`
  for both success and failure and passes them to the provider. Include the payment id so the return
  page can resolve which attempt it is looking at.
* **Fail closed for PayU only.** If the setting is empty *and* the resolved gateway is `PAYU`, fail
  the checkout with a clear configuration message rather than calling PayU with no `surl` — a payer
  stranded on a gateway page after their card was charged is materially worse than a checkout that
  refuses to start. Braintree and Razorpay proceed normally with an empty setting.
* Write the setting row into a new seed file under `sql-scripts-dyanmic/`. **Do not apply it** —
  seeds are user-owned.

---

## ④ Gap 4 — The past-due banner cannot name the amount or the next retry *(Known Issue 11, narrowed)*

**Correction to the issue as recorded.** `MyBillingOverviewResult` **already carries**
`DunningAttemptCount` and `GracePeriodEndsOn`. So "attempt 2 of 3" and the suspension date are
available today. What is genuinely missing is narrower:

* `OutstandingAmount` (`decimal?`) — the unpaid total across open/overdue invoices for the current
  subscription. Null when nothing is outstanding. Sum it from the invoices already being queried in
  the handler; do not add a second round-trip.
* `NextRetryOn` (`DateTime?`) — the date the next charge attempt falls on. Derive it the same way
  `SubscriptionRenewalService` does: read `BILLING_DUNNING_RETRY_DAYS` (default `"3,7"`) through
  `IPlatformSettingsService`, take the next offset past the attempts already made, and add it to the
  first-failure date. Null when the subscription is healthy or the ladder is exhausted.

> **Derive, never duplicate.** If you find yourself re-implementing the offset parsing, extract the
> shared helper out of `SubscriptionRenewalService` and call it from both. Two copies of a dunning
> schedule is a bug that only appears when someone changes the setting and one screen disagrees with
> what actually gets charged.

Also add `DunningMaxAttempts` (`int`) so the banner can render "attempt 2 of **3**" without the FE
hardcoding the ladder length — the value is a setting and the client must not assume it.

---

## ⑤ Gap 5 — `subscriptionForCompany` returns no payment history *(Known Issue 6)*

`SubscriptionForCompanyResult` is the ops per-tenant view. It carries plan, price, period and
derivation trail — but no payment collection and no dunning state. The P-14 FE session worked around
this by building the per-tenant payment strip from `platformWebhookLogs(companyId:)`, which is an
honest substitution and the wrong data: a webhook is the gateway telling us something happened, not
our own record of what we charged.

**Fix — add to `SubscriptionForCompanyResult`:**

* `IReadOnlyList<SubscriptionPaymentDto> RecentPayments` — the last 10 attempts, newest first:
  `SubscriptionPaymentId`, `AttemptedOn`, `Amount`, `CurrencyCode`, `Status`, `FailureKind`,
  `FailureCode`, `FailureMessage`, `GatewayCode`, `InvoiceNumber`.
* `int DunningAttemptCount` and `DateTime? GracePeriodEndsOn`, mirroring gap 4 so ops sees the same
  dunning story the tenant sees.

> **No gateway reference, no raw response, no token.** `FailureCode` and `FailureMessage` are the
> gateway's classification and are safe. The raw payload is not — it can carry payer detail that has
> no business on an ops screen. `RawResponse` stays in the webhook log where a deliberate,
> capability-gated click can reach it.

`FailureKind` keeps its P-14 meaning and the ops screen should lean on it: `ConfigError` is **our**
fault and must never be presented as the tenant's payment problem.

---

## ⑥ What this session does NOT do

Named so nobody quietly widens the scope:

* No FE work of any kind. The screens that consume these contracts are the next session.
* No new entity, no new table, no migration. Every gap is served by existing tables.
* No change to `ConfirmSubscriptionPayment`'s decline semantics — a decline is still
  `success: true` at the envelope with `success: false` and a classified `failureKind` in the
  payload, and retrying still means calling `initiateSubscriptionCheckout` again, never re-confirming
  a spent attempt.
* No change to the renewal schedule, the dunning ladder's behaviour, or the fail-closed currency
  resolver. Gap 4 *reads* the ladder; it does not alter it.

---

## ⑦ FE follow-ups this session must record (and not perform)

Append to P-14 §⑬ as they become true, for the FE session that follows:

1. **Overview (`/billing`, `BILLING_OVERVIEW`)** — §7.1's payment-method card is now buildable; bind
   `myPaymentMethod`, with `setDefaultPaymentMethod` / `removePaymentMethod` behind it. Render
   `ExpiresSoon` as a warning and `IsExpired` as an error; both are server-derived, so do not
   recompute them from the browser clock.
2. **Overview** — the past-due banner can now name the outstanding amount, the retry date and
   "attempt N of M" (`dunningMaxAttempts`, never a hardcoded 3).
3. **Ops tenant detail** — drop the `platformWebhookLogs(companyId:)` substitution in
   `tenant-gateway-activity.tsx` and bind `subscriptionForCompany.recentPayments` instead.
4. **New route `/billing/checkout/result`** — the PayU return leg; reads `?ref=` and resolves the
   attempt. No menu row (§⓪b); it is entered only by a gateway redirect.

---

## ⑧ Anything needing a schema change

If any gap turns out to need a column that does not exist, **stop and write it here** rather than
generating a migration. State the table, the column, the type, the nullability and why it cannot be
derived. The user authors and runs every migration; this file is how the need reaches them.

*(Expected to stay empty. Every gap above was scoped against columns already on disk.)*

---

## ⑨ Acceptance

| # | Check |
|---|---|
| 0 | Every new tenant-side resolver is gated on the **parent** code `BILLING`, not on `BILLING_OVERVIEW` / `_PLANS` / `_INVOICES`. A BUSINESSADMIN who can already open `/billing` can call all three new fields without any seed change. If a new grant seems necessary, the attribute is wrong — re-read §⓪b. |
| 1 | `myPaymentMethod` returns brand / last4 / expiry / gateway for a tenant with a saved card, and a null-ish result for one without. |
| 2 | **`GatewayTokenId` appears in no response, no DTO and no log.** Grep the diff for it before you finish. |
| 3 | `IsExpired` is true for `06/2025` and false for a card expiring *this* month; both derived from UTC. |
| 4 | `setDefaultPaymentMethod` moves the default in one save, with no unique-index violation, and is idempotent when re-run. |
| 5 | `setDefaultPaymentMethod` / `removePaymentMethod` with **another tenant's** id fail — the row is never found, because the query is scoped by the token's CompanyId. |
| 6 | `removePaymentMethod` refuses to remove the last default while auto-renew is on, and says why. |
| 7 | PLATFORM_FINANCE can open `platformWebhookLogs` and `platformWebhookLogById` without MANAGE; `platformGatewayConfig` still requires MANAGE. |
| 8 | A PayU checkout carries `surl` and `furl`; with the setting empty it fails with a configuration message instead of calling the gateway. A Braintree checkout is unaffected by the setting being empty. |
| 9 | `myBillingOverview` returns `outstandingAmount`, `nextRetryOn` and `dunningMaxAttempts`; `nextRetryOn` matches what `SubscriptionRenewalService` would actually do next. |
| 10 | `subscriptionForCompany` returns `recentPayments` with no raw response and no gateway token. |
| 11 | **Every new GraphQL field is executed once against the running API.** Names only fail at runtime — `GetMyPaymentMethod` → `myPaymentMethod` is the trap. This is the acceptance item that P-14's FE session could not perform; do not skip it here. |
| 12 | No file under `PSS_2.0_Frontend/` changed. No `Migrations/` file and no change to `ApplicationDbContextModelSnapshot.cs`. **Check this against the filesystem — both trees are gitignored, so `git status` will look clean either way.** |

---

## ⑩ Build log

*(Append one entry per session: what was built, what was substituted and why, what acceptance items
were and were not performed, and any Known Issue opened. Record acceptance 11 honestly — if the API
would not start, say so rather than implying the fields were exercised.)*
