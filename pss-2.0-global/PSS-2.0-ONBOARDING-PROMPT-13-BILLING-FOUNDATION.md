# PSS 2.0 — ONBOARDING PROMPT 13 — Billing Foundation (pricing policy · self-serve switch · invoices · offline payments)

**Task ID:** T-A19 (P2 phase — the first half of self-serve billing)
**Surface:** BE (platform settings home · pricing policy in `PlanPricingService` · 3 new billing tables · 3 new commands · 2 new queries) · FE (Billing moved out of Settings into its own menu · 3 read-only tenant screens · ops offline-payment dialog)
**Model:** Sonnet — §①–⑫ below are detailed and every pattern has a named precedent in-repo.
**Depends on:** PROMPT-11 (plan catalog editable, `myEntitlements` real), PROMPT-12 (entitlement/quota gates), `IPlanPricingService` (exists), `IEntitlementService` (exists), `NumberSequenceGenerator` (exists).

> **Blueprint:** `PSS-2.0-SELF-SERVE-UPGRADE-AND-BILLING-APPROACH.md` — §① placement, §①b self-serve switch, §② reuse inventory, §③ schema, **§③b pricing resolution**, §④c offline payment, §⑤ backend, §⑥ frontend, §⑦ guards, §⑧ phasing (this prompt is the non-gateway half of MVP-1).

---

## ⓪ Scope boundary — read this first

This prompt builds **everything up to but not including taking a card.** That line is deliberate: the
gateway half needs two inputs we do not have yet (Braintree's enabled currency list, and sandbox/prod
credentials), and the USD price points are a business decision, not a build input. Everything below is
buildable today with zero pending decisions.

**In scope**

1. A platform-scoped settings read path (`CompanyId IS NULL` rows in `sett.OrganizationSettings`).
2. §③b pricing policy — gate the *already-existing* FX fallback, add uplift + ceiling rounding, snapshot the derivation.
3. §①b the self-serve switch — one ops setting + one nullable column + a server-side predicate.
4. `billing.Invoices` / `billing.InvoiceLines` / `billing.SubscriptionPayments` + `RecordOfflinePaymentCommand` (§④c).
5. FE: Billing leaves Settings and becomes its own menu — `/billing`, `/billing/plans`, `/billing/invoices`, all **read-only** (no checkout button yet; the CTA says "Contact us" exactly as §①b's disabled state does).

**Explicitly OUT of scope — do not build, do not stub, do not "prepare for"**

`ops.PlatformPaymentGateways`, `IPlatformBillingPaymentService`, the gateway capability resolver, the
platform webhook route, `InitiateSubscriptionCheckout`, `ConfirmSubscriptionPayment`,
`billing.TenantPaymentMethods`, `SetAutoRenewCommand`, the dunning ladder, invoice PDF, tax
computation, proration, refunds. All of that is PROMPT-14. A half-built checkout is worse than none.

---

## ① Why this exists

Three problems, all of which bite before any card is ever charged.

**1. FX-derived pricing is live and nobody decided that.** `PlanPricingService.cs` lines 80-93 already
convert the INR anchor into any requested currency whenever a curated `PlanPrice` row is missing, at the
raw rate, rounded to 2 dp. So the system will today quote a US foundation **$50.37/month** derived from
₹4,199 — no uplift for foreign card fees, no price point, and no record afterwards of how that number
was reached. The fix is not to remove the fallback (it is genuinely useful for markets too small to
price by hand) but to **gate it, mark it up, round it, and record it.**

**2. There is no invoice.** A paying customer is legally entitled to one, and GST/VAT numbering cannot
be derived retroactively — you cannot issue invoice #7 next year for a payment taken this year. The
tables have to exist before the first rupee is collected, even if the first rupee arrives by bank
transfer.

**3. Money already moves with no ledger entry.** `AssignSubscriptionCommand` contains no payment code
at all, so an ops member can already put a tenant on PLAN_50K after a bank transfer — and nothing
anywhere records that money arrived. §④c closes that with the smallest honest thing: an invoice, and a
payment row against it.

The FE half is the §① placement decision landing: Subscription stops being one record inside Company
Settings and becomes its own menu, because "what am I paying and what did I get" is not a setting.

---

## ② Reuse-first — copy these precedents, do not invent

| Need | Copy from | Location |
|---|---|---|
| Platform-global settings rows | `CompanyId IS NULL` is **already documented as reserved** for platform baseline rows in the entity itself — read its comment before writing anything | `Base.Domain/Models/SettingModels/OrganizationSetting.cs` (the `CompanyId` comment) |
| Scoped settings service shape, per-request dictionary cache, typed getters, `Invalidate*` | `OrgSettingsService` — the new platform service is this with the `companyId` parameter removed | `Base.Application/Services/OrgSettings/IOrgSettingsService.cs`, `Base.Infrastructure/Services/.../OrgSettingsService.cs` |
| Platform-owned table with **no CompanyId** | `PlatformCommunicationProvider` + its EF configuration + its migration are the exact precedent for a `billing`/`ops` row that belongs to the platform, not a tenant | `Base.Domain/Models/OpsModels/PlatformCommunicationProvider.cs`, `Base.Infrastructure/Data/Configurations/OpsConfigurations/PlatformCommunicationProviderConfiguration.cs`, `Migrations/20260729062510_Add_PlatformCommunicationProvider.cs` |
| Price resolution ladder + `Source` discriminator | **Already built** — extend, do not rewrite | `Base.Infrastructure/Services/Billing/PlanPricingService.cs` |
| Snapshot discipline (store the VALUE, never an FK to a mutable rate/price row) | `AssignSubscription` lines 88-95 + 189-204, and the header comment explaining why | `Base.Application/Business/BillingBusiness/Subscriptions/Commands/AssignSubscription.cs` |
| Direct-pair FX, null on miss | `IFxRateService.GetRateAsync(from, to, rateDate, ct)` — strict `(From, To, RateDate)`, **no inverse, no USD triangulation**. This is a locked project decision. | `Base.Application/Interfaces/IFxRateService.cs` |
| Per-company unique business code | `NumberSequenceGenerator` — invoice numbers go through it, never `count(*) + 1` | `Base.Infrastructure/.../NumberSequenceGenerator.cs` |
| Command + validator + handler + audit shape | `AssignSubscription.cs` end to end — `[CustomAuthorize]`, `BaseCommandFluentValidator`, `IAuditLogWriter.WriteEntityChange`, `DbUpdateException` → `InternalServerException` | same file |
| Platform-only authorization | `[CustomAuthorize("PLATFORM_PLANS", "PLATFORM_PLAN_EDIT")]` | `AssignSubscription.cs` line 23 |
| Billing code constants | `FeatureCodes` / `MeterCodes` / `MeterTypes` — new setting ParamCodes and payment methods become constants here, never string literals at call sites | `Base.Application/Interfaces/BillingCodes.cs` |

---

## ③ BE — a platform-scoped settings read path

`IOrgSettingsService` takes a **non-nullable `int companyId`** on every method, so it cannot read a
platform row. Do not widen it — a nullable `companyId` on a tenant settings service is exactly the kind
of signature that later resolves a platform setting for a tenant by accident.

### 3.1 `IPlatformSettingsService` (new — `Base.Application/Services/OrgSettings/`)

```csharp
public interface IPlatformSettingsService
{
    Task<string?> GetStringAsync (string paramCode, string? fallback = null, CancellationToken ct = default);
    Task<bool>    GetBoolAsync   (string paramCode, bool fallback = false, CancellationToken ct = default);
    Task<int>     GetIntAsync    (string paramCode, int fallback = 0, CancellationToken ct = default);
    Task<decimal> GetDecimalAsync(string paramCode, decimal fallback = 0m, CancellationToken ct = default);
    void Invalidate();
}
```

Implementation mirrors `OrgSettingsService` exactly, with two differences:

- the query is `.IgnoreQueryFilters().Where(s => s.CompanyId == null && s.IsDeleted != true)`;
- resolution is `CurrentValue ?? ParamDefaultValue ?? fallback`. There is no third tier — a platform
  setting has no tenant to override it.

Register **Scoped**, same as `OrgSettingsService`.

> **The fallback argument is load-bearing, not defensive padding.** Every call site below passes the
> safe value explicitly, so a missing seed row degrades to the conservative behaviour (FX off, uplift 0,
> self-serve on) rather than throwing on a page load.

### 3.2 New ParamCodes

Add to `BillingCodes.cs` as constants:

| ParamCode | DataType | Default | Meaning |
|---|---|---|---|
| `SELF_SERVE_UPGRADE_ENABLED` | BOOLEAN | `true` | §①b platform kill switch. |
| `FX_DERIVED_PRICING_ENABLED` | BOOLEAN | **`false`** | §③b. Off ⇒ the FX step is skipped entirely. |
| `FX_PRICING_UPLIFT_PERCENT` | NUMBER | `20` | Applied to the converted amount before rounding. |
| `FX_PRICING_ROUNDING` | SELECT | `ENDING_9` | `NONE` \| `NEAREST_10` \| `ENDING_9` \| `ENDING_99`. |

⚠ **`FX_DERIVED_PRICING_ENABLED = false` is a behaviour change from today**, where the FX step is
unconditional. That is intentional and was decided in blueprint §③b — but it means an existing tenant
sitting on an FX-derived price must not be re-resolved. It won't be: `Subscription.Amount` is a snapshot
and nothing re-reads it. Verify that in acceptance (§⑦.4).

---

## ④ BE — §③b pricing policy in `PlanPricingService`

The ladder is already correct — `FREE → BOOK → FX → null`, with `BOOK` checked **before** `FX` so a
hand-set price can never be overridden by a rate. **Preserve that ordering.** Three changes only.

### 4.1 Gate the FX step

```csharp
// step 3 — FX fallback (§③b). Gated: a derived price is a fallback for currencies nobody has
// priced, never a substitute for pricing the market we are launching into.
if (!await platformSettings.GetBoolAsync(BillingCodes.FxDerivedPricingEnabled, false, ct))
    return null;   // unpriced currency ⇒ not sellable ⇒ "Contact us". Fail-closed, unchanged.
```

Placed after the `BOOK` miss and before the `IFxRateService` call — so with the switch off we do not
even take the FX round-trip.

### 4.2 Uplift + ceiling rounding

Replace `Math.Round(plan.Price * rate.Value, 2, MidpointRounding.AwayFromZero)` with:

```
raw       = plan.Price * rate
uplifted  = raw * (1 + uplift/100)
final     = ApplyRounding(uplifted, mode)
```

`ApplyRounding` — a private static helper, **always rounds up**:

| Mode | 50.37 → | Rule |
|---|---|---|
| `NONE` | 50.37 | `Math.Round(x, 2, AwayFromZero)` — the current behaviour, kept for a caller who genuinely wants the raw figure |
| `NEAREST_10` | 60 | `Math.Ceiling(x / 10) * 10` |
| `ENDING_9` | 59 | smallest `n*10 + 9 >= x` |
| `ENDING_99` | 99 | smallest `n*100 + 99 >= x` |

Rounding **down is a discount nobody approved** — there is no "nearest" mode for the price-point
options, only ceiling. An unrecognised mode string falls back to `NONE` (never throws: a typo in a
settings row must not take the plan page down).

### 4.3 Surface the derivation

`PriceResolution` gains two nullable members — additive, so existing call sites keep compiling:

```csharp
public sealed record PriceResolution(
    decimal Amount, int CurrencyId, string CurrencyCode, string BillingCycle, string Source,
    decimal? FxRateUsed = null,      // the rate VALUE. Non-null only when Source == "FX"
    DateOnly? FxRateDate = null);    // the RateDate it came from
```

`AssignSubscription` then snapshots `PriceSource` / `FxRateUsed` / `FxRateDate` onto the subscription
alongside `Amount` (§⑤.1). This is the snapshot discipline extended to the *derivation*: "why is this
customer paying $59?" must be answerable in one query, not by archaeology across a rate table that has
since moved.

Update the XML doc on both `IPlanPricingService` and `PriceResolution` — the current comments state the
FX step is unconditional, and a stale comment on a pricing service is a future bug.

---

## ⑤ BE — schema (migration specs, **user-owned**)

> **Do not run `dotnet ef migrations add`, `database update`, or `remove`. Do not hand-author a
> migration or a snapshot.** Write the entities + EF configurations, build to prove they compile, and
> hand over the migration spec below. The user authors, runs and commits the migration. Seed SQL: you
> write it into `sql-scripts-dyanmic/`, the user applies it.

### 5.1 `billing.Subscriptions` — three new nullable columns

```
PriceSource   text    null   -- 'FREE' | 'BOOK' | 'FX'
FxRateUsed    numeric(18,8) null
FxRateDate    date    null
```

All nullable, no backfill — existing rows legitimately do not know how their price was derived, and
inventing `'BOOK'` for them would be a lie in an audit column.

### 5.2 `app.Companies` — one new nullable column

```
AllowSelfServeUpgrade  boolean  null   -- null = inherit the platform setting
```

Nullable **on purpose** (blueprint §①b): `NOT NULL DEFAULT true` would make "deliberately excluded from
self-serve" indistinguishable from "nobody has thought about this tenant yet", and those two need
different treatment the day a billing dispute happens.

### 5.3 `billing.Invoices`

```
InvoiceId int PK
CompanyId int FK → app.Companies          (NOT NULL — an invoice always belongs to a tenant)
SubscriptionId int FK → billing.Subscriptions
InvoiceNumber text NOT NULL               -- via NumberSequenceGenerator; UNIQUE (CompanyId, InvoiceNumber)
Status text NOT NULL                      -- 'Draft'|'Issued'|'Paid'|'Failed'|'Void'|'Refunded'
PeriodStart / PeriodEnd    timestamptz
IssuedOn / DueOn / PaidOn  timestamptz null
Subtotal / TaxAmount / TotalAmount  numeric(18,2) NOT NULL
CurrencyId int FK → com.Currencies
PlanCode text, BillingCycle text          -- SNAPSHOT, same discipline as Subscription
Notes text null
+ Entity audit columns (CreatedBy/CreatedDate/ModifiedBy/ModifiedDate/IsActive/IsDeleted)
```

Indexes: `UNIQUE (CompanyId, InvoiceNumber) WHERE IsDeleted = false`; `(CompanyId, Status)`;
`(SubscriptionId)`.

`TaxAmount` exists from day one and is written as `0` — the *computation* is deferred, the *column* is
not, because adding a tax column to an invoice table that already has issued invoices in it is a
migration nobody wants.

### 5.4 `billing.InvoiceLines`

```
InvoiceLineId int PK, InvoiceId int FK (cascade), Description text NOT NULL,
Quantity numeric(18,4) NOT NULL default 1, UnitAmount numeric(18,2) NOT NULL,
LineTotal numeric(18,2) NOT NULL, TaxRate numeric(9,4) null
+ Entity audit columns
```

One line in this build (the plan). The table exists because tax and add-ons need it and retrofitting
lines onto flat invoices is worse.

### 5.5 `billing.SubscriptionPayments`

```
SubscriptionPaymentId int PK
CompanyId int FK, SubscriptionId int FK, InvoiceId int FK null
Method text NOT NULL      -- 'GATEWAY'|'BANK_TRANSFER'|'CHEQUE'|'CASH'|'ADJUSTMENT'|'COMPLIMENTARY'
Reference text null        -- UTR / cheque number
Note text null             -- free text; REQUIRED when Amount = 0 (§⑥.3)
Amount numeric(18,2) NOT NULL, CurrencyId int FK
Status text NOT NULL       -- 'Initiated'|'Pending'|'Succeeded'|'Failed'|'Refunded'
AttemptedOn timestamptz NOT NULL, CompletedOn timestamptz null
RecordedByUserId int null  -- who keyed it in; NULL for a future gateway/webhook row
+ Entity audit columns
```

**Deliberately omitted in this build** (they belong with the gateway, PROMPT-14):
`PlatformPaymentGatewayId`, `GatewayTransactionId`, `GatewayReference`, `FailureCode`,
`FailureMessage`, `IdempotencyKey`, `RawResponse`. Adding a nullable column later is a one-line
migration; carrying six unused columns through a build is six chances to populate them wrongly.

Indexes: `(CompanyId, SubscriptionId)`, `(InvoiceId)`, `(Status)`.

### 5.6 Seed SQL — `sql-scripts-dyanmic/billing-platform-settings-seed.sql`

Idempotent (`WHERE NOT EXISTS` on `ParamCode` + `CompanyId IS NULL`, the shape used by
`system-staff-category-and-admin-staff-backfill.sql` PART A). Inserts the four §3.2 rows with
`CompanyId = NULL`, `CanUserOverride = false`, `CurrentValue = NULL` (so `ParamDefaultValue` governs).
Resolve `SettingGroupId` by group code in the `SELECT`, never a hardcoded id.

Include a PART B verification block that selects the four rows back, and a header note that **the API
must be restarted after COMMIT** because the settings services cache per request/scope — same note
`fix-tenant-currency-from-country-backfill.sql` carries.

---

## ⑥ BE — commands and queries

### 6.1 `GetMyBillingOverviewQuery` *(tenant, `[CustomAuthorize("BILLING", "BILLING_VIEW")]`)*

**`CompanyId` comes from the token, never from an argument.** A tenant-supplied `companyId` on a
billing query is a cross-tenant billing disclosure. Returns, in one round-trip:

```
planCode, planName, status, trialEndsOn, currentPeriodStart, currentPeriodEnd,
amount, currencyCode, billingCycle, autoRenew,
priceSource, fxRateUsed, fxRateDate,          -- §④.3; FE shows these to platform staff only
canSelfServe, selfServeBlockedReason,          -- §6.2
recentInvoices[]                               -- last 3: number, status, periodEnd, totalAmount, currencyCode
```

### 6.2 The self-serve predicate (§①b)

A single shared internal helper — **not** duplicated between the query and the (future) checkout
command:

```
canSelfServe(company, targetPlan) =
      platformSettings.GetBool(SELF_SERVE_UPGRADE_ENABLED, fallback: true)
  AND (company.AllowSelfServeUpgrade ?? true)
  AND targetPlan.PlanCode != 'CUSTOM'
  AND price resolves for the subscription's currency        -- §④, i.e. ResolveAsync != null
```

`selfServeBlockedReason` is an enum-shaped string returning the **first** failing clause:
`PLATFORM_DISABLED` | `TENANT_DISABLED` | `CUSTOM_PLAN` | `NO_PRICE_FOR_CURRENCY`.

The gateway clause (`NO_GATEWAY_FOR_CURRENCY`) from blueprint §①b is **not** evaluated in this build —
there is no gateway table yet. Leave a `// PROMPT-14:` comment at the exact spot it goes; do not
pre-add the enum value, or the FE will ship a message for a state that cannot occur.

Put the helper where both callers can reach it (`Base.Application/Business/BillingBusiness/Common/`).
In this build nothing acts on `false` beyond rendering — but write it server-side anyway, because a
hidden button is not a control.

### 6.3 `RecordOfflinePaymentCommand` *(platform-only)*

`[CustomAuthorize("PLATFORM_PLANS", "PLATFORM_PLAN_EDIT")]` — same pair as `AssignSubscription`, since
this is the same operator doing the same job.

```csharp
public record RecordOfflinePaymentCommand(
    int CompanyId, int SubscriptionId, int? InvoiceId,
    string Method, decimal Amount, int? CurrencyId,
    string? Reference, string? Note, DateTime? ReceivedOn) : ICommand<RecordOfflinePaymentResult>;
```

Handler:

1. Validate the company + subscription exist and the subscription belongs to that company. A payment
   filed against another tenant's subscription is a reconciliation bug that surfaces months later.
2. `Method` must be in the allowed set **and must not be `GATEWAY`** — a gateway payment is written by
   the webhook, never by hand. Reject with `BadRequestException`.
3. `CurrencyId ?? subscription.CurrencyId`. `Amount >= 0`.
4. **`Amount == 0` requires a non-blank `Note`.** A free grant with no stated reason is
   indistinguishable from a mistake.
5. `Reference` is **prompted but never enforced** for `BANK_TRANSFER`/`CHEQUE`. Deliberate: a mandatory
   reference just produces `na` and `-` in the ledger, which is less honest than a visible blank.
6. If `InvoiceId` is null, create the invoice — `Status='Issued'`, period = the subscription's current
   period, `PlanCode`/`BillingCycle` snapshotted, one `InvoiceLine` for the plan, number from
   `NumberSequenceGenerator`. An offline payment with nothing to settle against is a dead-end row.
7. Insert the payment `Status='Succeeded'`, `CompletedOn = ReceivedOn ?? UtcNow`, `RecordedByUserId` =
   current user.
8. If the invoice's succeeded payments now cover `TotalAmount`, set `Status='Paid'` + `PaidOn`.
   Otherwise leave it `Issued` — a partially-paid invoice showing as `Issued` **is the correct state
   and a useful ops worklist**; a silent fake `Paid` is neither.
9. One `SaveChangesAsync`. Audit `OFFLINE_PAYMENT_RECORDED`, or
   `SUBSCRIPTION_COMPLIMENTARY_GRANTED` when `Amount == 0`.

**This command never touches the subscription.** The upgrade is `AssignSubscription`, already built and
already requiring no payment details. Keeping them separate is what makes "ops upgraded them, the
transfer lands next week" representable.

### 6.4 `GetTenantInvoicesQuery` *(tenant, `BILLING_VIEW`)*

Paged, `CompanyId` from the token, newest first. Number, status, period, totals, currency, and the
succeeded-payment sum.

### 6.5 `SavePlatformPricingPolicyCommand` + `SetTenantSelfServeCommand` *(both platform-only)*

Thin writers over §3.2 / §5.2. Both **must** audit — `PRICING_POLICY_CHANGED` and
`SELF_SERVE_TOGGLED`. A change to `FX_PRICING_UPLIFT_PERCENT` alters what every future customer is
charged; that is not a silent settings write. Both call `Invalidate()` after saving.

Validate `FX_PRICING_ROUNDING` against the four allowed values with
`ValidateStringIsInAllowedValues` (the existing validator helper) and `FX_PRICING_UPLIFT_PERCENT` to
`0 <= x <= 200`.

### 6.6 GraphQL

New `BillingQueries` / `BillingMutations` classes under
`Base.API/EndPoints/Billing/{Queries,Mutations}`, `[ExtendObjectType]`, `BaseApiResponse<T>` wrappers,
`try/catch → .Error(ex.Message)` — copy `SubscriptionMutations.cs` exactly.

> **HotChocolate naming — the one thing `tsc` cannot catch.** `Get` is stripped from **every**
> resolver: `GetMyBillingOverview` → **`myBillingOverview`**, `GetTenantInvoices` →
> **`tenantInvoices`**. Input types get `Input` appended. A wrong field name compiles clean and fails
> only at runtime, so verify each name against the generated schema before writing the FE query.

### 6.7 Capabilities

`BILLING` (module) + `BILLING_VIEW` + `BILLING_MANAGE`. `BILLING_MANAGE` is unused in this build —
seed it now so PROMPT-14 does not need a second capability migration mid-flight. Seed into
`sql-scripts-dyanmic/`, same shape as `ops-platform-plan-view-capability-seed.sql`. **BUSINESSADMIN
only** on the tenant side.

---

## ⑦ FE — Billing leaves Settings

### 7.1 Remove, don't fork

`src/presentation/components/page-components/setting/orgsettings/companysettings/sections/subscription-section.tsx`
is **deleted**, and its entry removed from the Company Settings section registry. Not hidden, not
feature-flagged — two places showing a tenant their plan will drift, and the one in Settings will be
the stale one.

`plan-usage-panel.tsx` is **rehosted unchanged** onto `/billing`. Do not modify it; it already renders
`myEntitlements` correctly.

`upgrade-cta.tsx` keeps its existing read-only "Contact us" rendering and re-points its link at
`/billing/plans`. It already has this exact state — that is why §①b was cheap.

### 7.2 Routes (all under `(core)`, `BILLING_VIEW`)

- **`/billing`** — status card (plan · status badge · next-charge date + amount · trial countdown) +
  `PlanUsagePanel` + a trial/past-due banner + last-3-invoices strip. This is where a lapsed tenant
  lands, so the banner must state *what happens next and when*, not just that something is wrong.
- **`/billing/plans`** — comparison cards from the existing sellable-plans data. Current plan marked;
  CUSTOM shows "Talk to us". **Every actionable card renders "Contact us" in this build**, driven by
  `canSelfServe`/`selfServeBlockedReason` — not by a hardcoded string, so PROMPT-14 flips behaviour by
  making the predicate return true, not by editing JSX.
- **`/billing/invoices`** — table from `tenantInvoices`: number, period, total, status badge, paid-on.
  No PDF button (PROMPT-14). An empty state that says "no invoices yet" is correct for every tenant on
  FREE and must not read like an error.

### 7.3 Ops side

On the existing `/ops/tenants/{id}` Subscription panel add: a **Record offline payment** dialog
(Method select · Amount · Currency · Received on · Reference · Note — with `Note` becoming required the
moment Amount is 0), a **self-serve** tri-state control (Enabled / Disabled / Inherit platform), and a
read-only line showing `priceSource` + `fxRateUsed` + `fxRateDate` when the source is `FX`.

The pricing-policy form (§6.5) goes on the existing ops settings surface, not on the tenant page — it
is platform-wide.

### 7.4 House rules (non-negotiable)

- Design tokens only — **no hex, no raw px**.
- Every **amount right-aligned** — inputs, grid cells, KPI tiles.
- Icon containers, status badges and helper chips: **solid `bg-X-600` + `text-white`**. Never
  `bg-X-50/100`, `text-X-700/800`, `bg-muted`, or `text-muted-foreground`.
- Shaped `Skeleton`s while loading; explicit empty and error states on all three routes.
- `@iconify` Phosphor icons.
- Responsive xs→xl.
- Page-header Save/Create enablement comes from RHF `formState.isValid`, **never** from
  `canCreate`/`canUpdate` — capability governs *visibility* of the entry point only.

---

## ⑧ Acceptance

1. **Pricing, switch off (launch config).** `ResolveAsync('PLAN_50K', USD, 'Monthly')` → **null**, and
   `/billing/plans` shows "Contact us" for that plan. No FX round-trip is made (verify: the settings
   read happens before the `IFxRateService` call).
2. **Pricing, switch on, uplift 20, `ENDING_9`.** With a direct INR→USD rate of `0.012`:
   `4199 × 0.012 = 50.388` → `× 1.20 = 60.47` → **`69`**. `Source='FX'`, `FxRateUsed=0.012`,
   `FxRateDate` = today.
3. **`BOOK` still wins.** With the switch **on** and a curated USD `PlanPrice` of `49`, `ResolveAsync`
   returns `49` / `Source='BOOK'` / `FxRateUsed=null`. The FX path must not run at all.
4. **No drift.** Change the INR→USD rate, then re-read an existing subscription: `Amount` is unchanged.
   Nothing re-resolves a live subscription.
5. **No direct pair ⇒ still not sellable.** Switch on, no INR→GBP rate row → `ResolveAsync(GBP)` is
   null. Confirm no triangulation through USD occurred.
6. **Rounding never discounts.** For each mode, `final >= uplifted` for a spread of inputs
   (0.01, 9.99, 50.37, 99.00, 100.01).
7. **Unknown rounding mode.** Set `FX_PRICING_ROUNDING='BANANA'` → falls back to `NONE`, page loads,
   nothing throws.
8. **Offline payment, full.** Ops assigns PLAN_50K via the existing flow, then records a
   `BANK_TRANSFER` for the full amount with no `InvoiceId` → an `Issued` invoice is created with a
   sequenced number, then flipped to `Paid`. Audit shows `OFFLINE_PAYMENT_RECORDED`.
9. **Offline payment, partial.** Half the amount → invoice stays **`Issued`**. It must appear in the
   ops worklist, not silently read as settled.
10. **Complimentary.** `Amount = 0` with a blank `Note` → `BadRequestException`. With a Note → succeeds,
    audit shows `SUBSCRIPTION_COMPLIMENTARY_GRANTED`.
11. **`GATEWAY` refused by hand.** `Method='GATEWAY'` → `BadRequestException`.
12. **Cross-tenant guard.** A payment posted with company A's `CompanyId` and company B's
    `SubscriptionId` → rejected.
13. **Self-serve reasons.** Platform off → `PLATFORM_DISABLED`. Platform on + tenant false →
    `TENANT_DISABLED`. Both on + CUSTOM plan → `CUSTOM_PLAN`. Both on + unpriced currency →
    `NO_PRICE_FOR_CURRENCY`. Precedence is first-failing-clause, in that order.
14. **Token scoping.** `myBillingOverview` and `tenantInvoices` accept **no** `companyId` argument and
    return only the caller's tenant.
15. **Settings gone from Settings.** Company Settings no longer offers a Subscription section
   anywhere.
16. **Missing seed rows degrade safely.** With `billing-platform-settings-seed.sql` *not yet applied*,
    every route loads: FX off, uplift 0, self-serve on. This is the state the user's DB is in until they
    run the script, so it must be a working state, not a 500.
17. **UTC.** Every `DateTime` written is `Kind=Utc`; `ReceivedOn` arriving from the wire is normalised at
    handler entry. Npgsql throws on `Kind=Unspecified` against `timestamptz` — verify by actually saving
    a hand-picked date from the dialog, not by reading the code.
18. **Typecheck clean.** `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, **no pipe**,
    **exit 0**. A run that reports only a "pre-existing" `TS2688` config error has checked **zero
    files** and is not a pass.

---

## ⑨ Hand-off to the user (do not do these yourself)

1. `dotnet build` — the user builds the backend.
2. **Migration** covering §5.1–§5.5 (3 columns on `billing.Subscriptions`, 1 on `app.Companies`, 3 new
   tables). The spec above is written to be authored directly; do not generate it.
3. Apply `sql-scripts-dyanmic/billing-platform-settings-seed.sql`, then the `BILLING` capability seed,
   **then restart the API** (settings cache).
4. **Still needed before PROMPT-14 can start:** the USD price points for PLAN_50K and PLAN_100K
   (FREE = 0) — set on their own merits, not by converting ₹4,199; Braintree's actually-enabled
   currency list; sandbox vs production credentials per gateway and who holds them.

---

## ⑩ Known traps

- **`PSS_2.0_Backend/` is gitignored**, so the Grep tool (ripgrep) returns **zero** `.cs` matches. Use
  `find -iname` to locate files, or scope `grep -rn --include=*.cs` to **one** project subdirectory — a
  repo-wide backend grep times out at 120 s. Absolute-path `Read` works fine.
- **Never assume a GraphQL field name, DTO property, or column mapping.** Read the backend file first.
  Audit fields are `createdDate` / `modifiedDate`, not `createdAt` / `modifiedAt`.
- **Currency identity is `int CurrencyId`** across the platform, but `IFxRateService` is keyed on **ISO
  code strings**. `PlanPricingService` already resolves ids → codes in one `com.Currencies` read; reuse
  that, do not add a second query.
- `PlanPrice` lookup already compares `BillingCycle.ToLower()`. Keep it — the seed data is not
  case-consistent.
- `billing.Subscriptions` has a **filtered `UNIQUE(CompanyId) WHERE Status IN (Trial, Active, PastDue)`**.
  Nothing in this prompt inserts a subscription, but if you touch that path at all, cancel-then-insert
  must happen in **one** `SaveChangesAsync`.
- Decimal money is `numeric(18,2)`; the FX rate is `numeric(18,8)`. Do not store a rate at 2 dp.

---

## ⑬ Build Log

_(append one entry per session; keep the last 5 — git holds the rest. Preserve Known Issues in full.)_

| Session | Date | What shipped | Notes |
|---|---|---|---|
| — | — | not started | Blueprint §③b settled 2026-07-30. |
| 1 | 2026-07-30 | **T-A19 code-complete.** BE §3–§6: `billing.Invoices`/`InvoiceLines`/`SubscriptionPayments` entities + EF configs, 3 columns on `Subscriptions` + `AllowSelfServeUpgrade` on `app.Companies`, `IPlanPricingService` price ladder (FREE→BOOK→FX→null, fail-closed), `SelfServeEvaluator` + `SelfServeBlockedReasons`, `IPlatformSettingsService`. Reads/writes: `myBillingOverview`, `tenantInvoices`, `mySellablePlans` (new — tenant-gated, one quote per plan), `platformPricingPolicy`, `savePlatformPricingPolicy`, `recordOfflinePayment`, `setTenantSelfServe`. FE §7: ops pricing-policy form + tenant self-serve toggle + offline-payment recorder; tenant `/billing`, `/billing/plans`, `/billing/invoices` under `(core)`; `upgrade-cta.tsx` re-pointed at `/billing/plans`; `subscription-section.tsx` deleted and de-referenced from Settings; `PlanUsagePanel` rehosted unchanged. | BE `dotnet build` clean (0 errors); FE `npx tsc --noEmit --incremental false` exit 0. **Migration is user-owned and UNAPPLIED** (§5.1–5.5: 3 cols on `billing.Subscriptions`, 1 on `app.Companies`, 3 new tables). Seeds written but **unapplied**: `billing-platform-settings-seed.sql` then `billing-capability-seed.sql` — **restart the API after** (settings cache). |
| 2 | 2026-07-30 | **`billing-capability-seed.sql` rewritten — the first version could not have worked.** Three defects found on review: (a) it granted `BILLING_VIEW`/`BILLING_MANAGE` but **not `ISMENURENDER`**, which is the only capability `GetParentChildMenuHandler` reads when building the nav (`GetParentChildMenu.cs:71`) — the menu would have been invisible; (b) it seeded ONE top-level menu carrying `MenuUrl '/billing'`, but `mapMenuToClassicConfig` renders every top-level menu as a **non-clickable header** (`href: "#"`) and only children as links — restructured to a `BILLING` header + 3 leaves (`BILLING_OVERVIEW` `/billing`, `BILLING_PLANS` `/billing/plans`, `BILLING_INVOICES` `/billing/invoices`); (c) it hung the menu off the **`ORGANIZATION`** module, which `ProvisionTenant.ModuleFeatureMap` gates on `MODULE:ORGANIZATION`/`EVENTS`/`CAMPAIGNS` — billing would have vanished for tenants whose plan lacks those, i.e. exactly the ones needing to upgrade. Moved to **`SETTING`**, which is in `AlwaysOnModuleCodes`. Also added the missing `auth."MenuCapabilities"` rows so the grants are editable from Access Control. | SQL only; no code change, no migration. Still **unapplied** — user-owned. `BILLING*` codes remain absent from `MenuFeatureMap` on purpose (billing must survive a lapsed plan). |

### Known Issues

1. **`NEXT_PUBLIC_UPGRADE_CONTACT` is now unused.** The CTA rewrite removed its only reader; drop it from the deployment env.
2. **No in-product contact route.** Every blocked plan card says "Contact us" as static copy rather than a link, because no `/contact-us` page exists and the old env-var mailto is gone. P-14 replaces the block with a real checkout; if P-14 slips, give this a destination.
3. **`useCapablities` cannot express `BILLING_VIEW`** — it only maps `READ/CREATE/MODIFY/DELETE/IMPORT/EXPORT/TOGGLE`. The three tenant pages gate their render on `useEntitlements().isBillingAdmin`; **authorization itself is the server's** (`[CustomAuthorize("BILLING","BILLING_VIEW")]`), so this is an audience filter, not the security boundary.
4. **Tenants with no live subscription are quoted in each plan's anchor currency.** `app.Companies` has no currency column, so `mySellablePlans` falls back to `plan.CurrencyId` (matching `AssignSubscription.cs:89`) and returns `quoteCurrencyCode: null` so the page says so. Revisit if a tenant-level billing currency is ever added.
5. **Blocked for P-14 (PROMPT-14):** Braintree's enabled-currency list, sandbox vs production credentials per gateway, and USD price points for `PLAN_50K` / `PLAN_100K`. `NO_GATEWAY_FOR_CURRENCY` is deliberately withheld from `SelfServeBlockedReasons` until then.
