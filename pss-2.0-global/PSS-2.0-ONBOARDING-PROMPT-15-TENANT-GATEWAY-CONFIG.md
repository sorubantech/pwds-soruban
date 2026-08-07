# PSS 2.0 — ONBOARDING PROMPT 15 — Tenant Payment Gateway Configuration (combine master + per-company · implemented-only catalogue · fit recommendation)

**Task ID:** T-A21 (P2 phase — finishes REGISTRY screen #167, absorbs #168)
**Surface:** BE (gateway capability data · fit-recommendation query · replace the hardcoded Razorpay throw · remove master create/delete) · FE (2-tab combined CONFIG screen · retire the duplicate master surface · finish the four card stubs)
**Model:** Sonnet — §③ (the capability table) and §⑤ (warn-don't-block) are the two places to slow down.
**Depends on:** nothing in PROMPT-14. This prompt touches `com.*` / `fund.*` only; PROMPT-14 touches `ops.*`. They can be built in either order or in parallel. §③ deliberately mirrors PROMPT-14 §3.3's shape so the two capability tables answer the same question the same way.

> **Registry:** screen **#167 "Payment Gateways (combined: Per-Company + Gateway Master)"** — `REGISTRY.md` line 331 already specifies this screen. It was built on 2026-05-15 (line 632) as the per-company card-grid **only**; the combined tab structure and the absorption of **#168** never happened. This prompt is the completion of a plan of record, not a new design.

---

## ⓪ The decision this prompt is built on — read before anything else

**The gateway catalogue is a code artefact, not user data.**

A row in `com.PaymentGateways` is only meaningful if `PaymentGatewayFactory` can turn it into a provider. It cannot be created by a tenant, by an ops operator, or by an admin — it is created by a developer shipping a provider class, and the database row is the *registration* of that fact.

Today the system does not believe this, and it is a live bug in both directions:

| | In `PaymentGatewayFactory` | In the seeded catalogue |
|---|---|---|
| BRAINTREE | ✅ implemented | ✅ seeded |
| RAZORPAY | ✅ implemented | ✅ seeded |
| **PAYU** | ✅ implemented | ❌ **absent** |
| STRIPE | ❌ `NotSupportedException` | ✅ seeded |
| PAYPAL | ❌ `NotSupportedException` | ✅ seeded |
| SQUARE | ❌ `NotSupportedException` | ✅ seeded |
| MANUAL | n/a — never reaches the factory | ✅ seeded |

Source of truth for the left column, `Base.Support/Payment/Factories/PaymentGatewayFactory.cs`:

```csharp
return configuration.GatewayCode.ToUpperInvariant() switch
{
    "BRAINTREE" => new BraintreeProvider(...),
    "RAZORPAY"  => new RazorpayProvider(...),
    "PAYU"      => new PayUIndiaProvider(...),
    _ => throw new NotSupportedException($"Payment gateway '{configuration.GatewayCode}' is not supported.")
};
```

Source of truth for the right column, `sql-scripts-dyanmic/companypaymentgateway-sqlscripts.sql` §5.

So a tenant in India **cannot select the gateway they actually need**, while a tenant anywhere can select one of three gateways, enter real merchant credentials, save successfully, mark it default — and discover the failure at the first donation, as an unhandled `NotSupportedException` on the donor's checkout. **That is the bug this prompt fixes.** Removing the create-a-gateway button is the smaller half of it.

**Consequence to accept honestly:** the catalogue becomes developer-owned, so "we need Cashfree" stops being a screen and becomes a work item. That is correct — there is no Cashfree provider class, so a Cashfree row would be a lie the UI tells. A request path (ticketing) is deliberately out of scope per §⑩.

---

## ① What "not fully implemented" actually means

Enumerated against the built files, so the builder does not have to rediscover it.

### 1a. Edit and Toggle are no-ops — confirmed, not suspected

`companypaymentgateway/index-page.tsx` lines 24-32:

```tsx
const cardConfig: PaymentGatewayCardConfig = {
  variant: "payment-gateway",
  // ... "for custom cards with their own Edit button we pass a no-op here — the
  // GatewayCard calls onEdit which is wired by the DataTableContainer via the
  // cardConfig callbacks."
  onEdit: () => {},
  onToggle: () => {},
};
```

**The comment is wrong.** `advanced/data-table-container.tsx` line 379 passes the object straight through — `config={tableConfig.cardConfig}` — and `card-grid/variants/payment-gateway-card.tsx` line 15-16 forwards `cfg.onEdit` / `cfg.onToggle` verbatim into `GatewayCard`. Nothing overrides them anywhere. The Edit and Disable buttons on every card are dead on click, and have been since 2026-05-15.

This is why the clean typecheck proves nothing here: `() => {}` satisfies `(row) => void` perfectly.

### 1b. Four stubs, two fakes

`companypaymentgateway/gateway-card.tsx`:

| Line | What |
|---|---|
| 110-112 | `handleTestConnection` → `toast.info("...coming in V2")` |
| 114-116 | `handleViewLogs` → `toast.info("Log viewer coming soon")` |
| 174-187 | hardcoded `Webhook Status: Not monitored` and `Monthly Volume: —` — not bound to any field |
| 9-16 | `GATEWAY_ICON_MAP` has STRIPE / PAYPAL / SQUARE, **no PAYU** |

### 1c. Three surfaces, two of them the same file

- `page-components/setting/paymentconfig/paymentgateway/data-table.tsx`
- `page-components/shared/commonasset/generalmaster/paymentgateway/data-table.tsx`

**Byte-identical.** Same exported symbol `PaymentGatewayDataTable`, same `gridCode = "PAYMENTGATEWAY"`, same `enableAdd: true`. Plus routes at `setting/paymentconfig/paymentgateway/page.tsx` and `shared/commonasset/generalmaster/paymentgateway.tsx`. And **no menu row is seeded for `PAYMENTGATEWAY` as a leaf anywhere** — `PaymentGateway-Menus-seed.sql` creates it only as the non-leaf parent container, and `companypaymentgateway-sqlscripts.sql` §1 re-parents the *company* menu under `SET_PAYMENTCONFIG`. So #168 was never navigable. It is dead code with two copies.

### 1d. The create affordance, in three places

1. `index-page.tsx` line 41 — `enableAdd: true` on the per-company grid.
2. `PaymentGateway-Menus-seed.sql` — grants **CREATE and DELETE** on `COMPANYPAYMENTGATEWAY` to both BUSINESSADMIN and ADMINISTRATOR.
3. `Base.API/EndPoints/Shared/Mutations/PaymentGatewayMutations.cs` — `CreatePaymentGateway` / `DeletePaymentGateway` on the **master**, reachable by any caller with the capability.

Note the distinction the user drew, and keep it: **creating a per-company configuration is legitimate** (a tenant configuring Razorpay for the first time). **Creating a master gateway row is not.** Item 1 above is about the entry point into configuration and needs care (§⑥); item 3 is the one that gets deleted outright.

### 1e. A hardcoded, hard-blocking, single-provider currency rule already exists

`CompanyPaymentGateways/Commands/CreateCompanyPaymentGateway.cs`:

```csharp
if (gateway != null && string.Equals(gateway.PaymentGatewayCode, "RAZORPAY", StringComparison.OrdinalIgnoreCase))
{
    ValidateRazorpayCurrencies(command.companyPaymentGateway.SupportedCurrencies);
}
```

and `ValidateRazorpayCurrencies` throws `BadRequestException` on any non-INR code. `UpdateCompanyPaymentGateway.cs:30-32` calls the same static — so at least there is no drift.

This is the recommendation feature, already attempted, in the wrong shape three ways: it covers one gateway out of three, it is a hard throw where the requirement is advice, and **it is factually too strict** — Razorpay International settles non-INR for accounts with it activated. It blocks the multi-currency charity §⑤ exists to protect. It gets replaced, not extended.

---

## ② Reuse-first

Everything the four stubs need already exists. Nothing in `Base.Support/Payment/` needs to change.

| Need | Use | Notes |
|---|---|---|
| Test Connection | `IPaymentService.GenerateClientTokenAsync(config, request, ct)` | implemented on **all three** providers (`BraintreeProvider:31`, `RazorpayProvider:50`, `PayUIndiaProvider:77`). A real credential round-trip — the correct connection test, and it charges nobody. |
| Build a `PaymentGatewayConfiguration` from a stored tenant row | `Base.API/PaymentFlow/PaymentFlowService.cs` → `BuildConfig` | ⚠️ **`private`, and reached only via the default gateway** — see §2.1. Reuse it, but you must add a method to do so. |
| View Logs | `PaymentWebhookLogs/Queries/GetPaymentWebhookLog.cs` | exists; needs a gateway filter, see §⑥ |
| Toggle a per-company row | `ToggleCompanyPaymentGatewayCommand` → mutation `ActivateDeactivateCompanyPaymentGateway` | **already built.** The FE no-op is the only missing link. |
| Tenant home currency | `Company.CountryId` → `Country.CurrencyId` → `com.Currencies` | confirmed on the entities; no new column needed |
| Capability child-table shape | PROMPT-14 §3.3 `ops.PlatformGatewayCurrencies` | mirror it deliberately |
| Command/handler/validator/audit shape | `AssignSubscription.cs` | end to end |

### 2.1 The one file this prompt must modify — `PaymentFlowService.cs`

`GenerateClientTokenAsync` cannot be reused unchanged. Line 109-115:

```csharp
public async Task<GenerateClientTokenResponse> GenerateClientTokenAsync(int companyId, string? gatewayCustomerId, CancellationToken ct)
{
    var gw = await GetDefaultGateway(companyId, ct);   // ← resolves the DEFAULT row, not a chosen one
    ...
    var config = BuildConfig(gw);                       // ← private, line 46
```

It takes a **company**, not a gateway. Calling it to test a specific card would test whichever gateway is flagged `IsDefault` and report success — the worst possible failure for a connection test, because it is green when it should be red, on exactly the row the tenant is trying to diagnose.

Add **one new public method** alongside it, additive, touching no existing member:

```csharp
public async Task<GenerateClientTokenResponse> TestGatewayConnectionAsync(
    int companyPaymentGatewayId, int companyId, CancellationToken ct)
```

It loads the row **filtered by both ids** (never by `companyPaymentGatewayId` alone — that is a cross-tenant read), returns a clean failure if not found, then calls the existing private `BuildConfig(gw)` and `_paymentService.GenerateClientTokenAsync`. Add the signature to `IPaymentFlowService` too.

Do **not** widen `BuildConfig` to public, and do not copy it into a handler — the decryption and environment logic must stay in one place.

> **Note for parallel builds:** PROMPT-14 §② says *"do not modify"* this file. That instruction means *do not alter the existing donation paths* — appending one method does not. But it is the **only file both prompts can touch**, so if PROMPT-14 and PROMPT-15 are being built concurrently, PROMPT-15 owns this edit and PROMPT-14 must not enter the file at all.

---

## ③ BE — gateway capability data (prerequisite for §④ and §⑤)

The catalogue has no capability data to recommend from. `com.PaymentGateways` is:

```csharp
public int PaymentGatewayId { get; set; }
public string PaymentGatewayCode { get; set; }
public string PaymentGatewayName { get; set; }
public ICollection<GlobalOnlineDonation> GlobalOnlineDonations { get; set; }
```

The only currency data today is `SupportedCurrencies` / `SupportedCountryCodes` — **CSV text on `fund.CompanyPaymentGateways`, the tenant's own row.** That is the tenant declaring its intent. It cannot validate itself, so it cannot drive a recommendation. Leave those columns alone (§⑩) — they are the tenant's selection, and §⑤ checks the selection *against* the catalogue.

### 3.1 Two columns on `com.PaymentGateways`

```
IsImplemented      boolean NOT NULL DEFAULT false   -- a provider class exists in PaymentGatewayFactory
SupportsRecurring  boolean NOT NULL DEFAULT false   -- can vault + charge on a schedule
```

`IsImplemented` is stored rather than derived in code because the dropdown query must filter in SQL — a `List<string>` in C# would have to be applied after materialisation, and would drift from the factory switch silently the day a fourth provider ships. Storing it means the seed and the factory are reviewed together.

`SupportsRecurring` is true for all three today but they are not equivalent (PROMPT-14 §⓪: PayU has no subscription object, only an SI mandate). The column exists so the recurring-donation screen can filter without re-deriving that table.

### 3.2 `com.PaymentGatewayCurrencies`

```
PaymentGatewayCurrencyId int PK
PaymentGatewayId         int NOT NULL FK → com.PaymentGateways
CurrencyId               int NOT NULL FK → com.Currencies
RequiresActivation       boolean NOT NULL DEFAULT false  -- supported, but only on an enabled merchant account
+ Entity base (IsActive, IsDeleted, CreatedDate, ModifiedDate, …)

UNIQUE (PaymentGatewayId, CurrencyId) WHERE IsDeleted = false
```

`RequiresActivation` is what makes §⑤ honest rather than merely permissive: Razorpay International and PayU cross-border are real but not on by default. A row with `RequiresActivation = true` produces *"supported once activated with the provider"* — advice, not a block, and not a false "fully supported" either.

**Fail-open, not fail-closed — the opposite of PROMPT-14 §3.3.** A gateway with zero currency rows means *"we have not catalogued this gateway's currencies yet"*, and must produce **no recommendation and no block**. PROMPT-14 fails closed because an uncatalogued platform gateway means we would charge our own customers through an unverified path — our money, our risk, and there is exactly one operator to tell. Here an empty catalogue would silently lock every tenant out of a working gateway over missing reference data. Different blast radius, opposite default. State this in the handler comment or the next reader will "fix" the inconsistency.

---

## ④ BE — catalogue queries

### 4.1 Filter the selectable catalogue

`GetAllPaymentGatewayList` (`SharedBusiness/PaymentGateways/Queries/GetAllPaymentGatewayList.cs`) is what feeds the gateway dropdown. Add `IsImplemented == true && IsActive == true && IsDeleted != true`.

Do **not** filter `GetPaymentGateways` (the paginated grid) the same way — Tab 1 must show the deactivated legacy rows, greyed, so an existing STRIPE configuration remains explicable rather than vanishing.

### 4.2 `GetGatewayRecommendations`

New query, `SharedBusiness/PaymentGateways/Queries/GetGatewayRecommendations.cs`. No parameters — the tenant comes from the ambient company context, as everywhere else.

```
GatewayRecommendationDto
  PaymentGatewayId      int
  PaymentGatewayCode    string
  PaymentGatewayName    string
  Fit                   string   -- "Recommended" | "Usable" | "Mismatch" | "Unknown"
  Reason                string   -- one sentence, shown verbatim in the UI
  HomeCurrencyCode      string?  -- echoed for the header line
  SupportedCurrencyCodes List<string>
```

Resolution, in order:

1. Home currency := `Company.CountryId → Country.CurrencyId → Currency.CurrencyCode`. Null `CountryId` or no currency on the country ⇒ every gateway is `Unknown`, reason *"Set your organisation's country in Company Settings to get gateway recommendations."*
2. Gateway has no `PaymentGatewayCurrencies` rows ⇒ `Unknown`, reason *"Currency support for this gateway has not been catalogued."* (§3.2 fail-open.)
3. Home currency present with `RequiresActivation = false` ⇒ **`Recommended`** — *"Settles {INR}, your organisation's currency."*
4. Home currency present with `RequiresActivation = true` ⇒ **`Usable`** — *"Can settle {INR} once cross-border settlement is activated with {Razorpay}."*
5. Home currency absent ⇒ **`Mismatch`** — *"Does not settle {INR}. Choose this only if you collect in {USD, GBP, EUR}."* (list the gateway's actual currencies — that sentence is the whole point: it tells a multi-currency charity that this gateway is the *right* choice for its USD stream.)

`Mismatch` is **advice**. It never prevents a save. That is §⑤.

Register on `Base.API/EndPoints/Shared/Queries/PaymentGatewayQueries.cs`. **HotChocolate strips `Get`** — the FE field is `gatewayRecommendations`, not `getGatewayRecommendations`. tsc cannot see gql field names; a wrong name compiles clean and fails at runtime only.

### 4.3 Delete the master create/delete path

Remove, don't orphan:

- `SharedBusiness/PaymentGateways/Commands/CreatePaymentGateway.cs`
- `SharedBusiness/PaymentGateways/Commands/DeletePaymentGateway.cs`
- `PaymentGatewayMutations.CreatePaymentGateway` (line 18) and `.DeletePaymentGateway` (line 121)
- the FE mutation documents for both

**Keep** `UpdatePaymentGateway` (renaming a display label is legitimate) and `TogglePaymentGatewayStatus` (a developer-owned kill switch for a provider going offline — and it is what the §⑧ seed uses conceptually).

Leaving these reachable-but-unlinked is not neutral. A mutation with no UI is a mutation the next person to wire a screen finds, assumes is supported, and uses.

---

## ⑤ BE — warn, never block

**Delete** `ValidateRazorpayCurrencies` from `CreateCompanyPaymentGateway.cs` and its call site in `UpdateCompanyPaymentGateway.cs:30-32`.

Replace with one general guard on both paths, in the handler (not the validator — the validator cannot query the catalogue):

> Reject **only** when the gateway has ≥1 catalogued currency **and** the tenant's `SupportedCurrencies` selection intersects it in **zero** places.

That refuses the genuinely impossible — a configuration that can never take a payment — and permits everything else, including:

- an Indian charity putting USD on Razorpay International (today: rejected outright);
- a charity running Braintree for its USD/GBP stream alongside PayU for INR (today: permitted, but the Braintree row is unusable because §① means it throws at charge time anyway);
- a gateway we have not catalogued yet (fail-open, §3.2).

Error text on rejection must name both sides, because the fix is a data edit the user makes:

> *"Braintree does not settle any of the currencies you selected (INR). It settles USD, GBP, EUR, AUD. Either add one of those to Supported Currencies, or configure Razorpay or PayU for INR."*

The `Mismatch` **warning** is FE-side (§⑥) and non-blocking by construction — the server never sees a "did you acknowledge" flag, and must not grow one. A confirmation checkbox would make the rare case annoying rather than possible, and the rare case is the one the user specifically asked to keep working.

---

## ⑥ FE — the combined screen

### 6.1 Route: keep `companypaymentgateway`

Build at the **existing** `setting/paymentconfig/companypaymentgateway`. REGISTRY line 331 proposes renaming to `.../paymentgateways`; **do not.** The rename would orphan the seeded `COMPANYPAYMENTGATEWAY.MenuUrl` (`companypaymentgateway-sqlscripts.sql` §1 sets `setting/paymentconfig/companypaymentgateway`), requiring another user-owned SQL edit, and buys nothing a tab label does not. Record the deviation in §⑬.

Two tabs, per REGISTRY #167:

**Tab 1 — Available Gateways.** Read-only. Source: `paymentGateways` (paginated master, §4.1) joined to `gatewayRecommendations`. Per row: brand icon, name, fit badge, `Reason` sentence, currency chips. Deactivated legacy rows (STRIPE/PAYPAL/SQUARE) render greyed with *"No longer available"* and no action. Implemented rows get a **"Configure"** button → opens the per-company create form pre-bound to that `PaymentGatewayId`.

Tab 1 is where the master table goes to live. No Add, no Delete, no Edit.

**Tab 2 — My Configuration.** The existing card-grid, `enableAdd: false`. Configuration begins in Tab 1, where it is bounded to real providers, rather than from a bare "+ New" whose first field is an unbounded gateway dropdown. Empty state points at Tab 1.

`enableActions.enableDelete` stays **true** — a tenant removing its own mis-entered Razorpay config is legitimate; that is `DeleteCompanyPaymentGateway`, not `DeletePaymentGateway`.

### 6.2 Wire the no-ops

`onEdit` → the DataTable's edit flow for the row (RJSF modal from `GridFormSchema`, as every other card-grid screen does). `onToggle` → `ActivateDeactivateCompanyPaymentGateway(companyPaymentGatewayId)`, which already exists. Refetch on success.

Delete the misleading comment at `index-page.tsx:26-29` — it is what caused this.

### 6.3 The four stubs

| Stub | Replacement |
|---|---|
| `handleTestConnection` | new mutation → `TestGatewayConnectionAsync(companyPaymentGatewayId, companyId, ct)` from §2.1 — **row-specific, not the default gateway**. Success ⇒ *"Connected — credentials accepted by {Razorpay} ({sandbox})."* Failure ⇒ the provider's message. **Never echo the credential back**, in the toast or the response. |
| `handleViewLogs` | drawer over `paymentWebhookLogs` filtered to the row's gateway, newest first. |
| `Webhook Status: Not monitored` (line 174-180) | **delete the row.** Bind it to "last webhook received" only if the log query already exposes a max timestamp; otherwise a fabricated status line is worse than no line. |
| `Monthly Volume: —` (line 181-186) | **delete the row.** Volume belongs on a donation report, not a config card, and there is no query for it. |

Add `PAYU: "ph:currency-inr"` to `GATEWAY_ICON_MAP`; remove STRIPE / PAYPAL / SQUARE; keep MANUAL.

### 6.4 House-rule fixes in `gateway-card.tsx`

Per the badge rule — **solid `bg-X-600` + `text-white`**, never `bg-X-50` / `text-X-700` / `bg-muted` for a badge:

- `EnvBadge` line 30-34: `bg-emerald-50 text-emerald-700` → `bg-emerald-600 text-white`; `bg-orange-50 text-orange-700` → `bg-orange-600 text-white`.
- Default star line 129: `bg-yellow-50 text-yellow-700` → `bg-amber-600 text-white`.
- `ChipStrip` line 63: `bg-muted` → `bg-slate-600 text-white`.
- Arbitrary sizes `text-[10px]` / `text-[11px]` (lines 30, 63, 71, 90, 153, 178, 184, 195, 205, 215, 226) → `text-xs`.
- New fit badge: `Recommended` = `bg-emerald-600 text-white`, `Usable` = `bg-blue-600 text-white`, `Mismatch` = `bg-amber-600 text-white`, `Unknown` = `bg-slate-600 text-white`. **`Mismatch` is amber, not red** — it is advice, and red on a legitimate multi-currency configuration reads as an error the tenant cannot clear.

### 6.5 Retire the duplicate master surface

Delete both copies and their routes:

- `page-components/shared/commonasset/generalmaster/paymentgateway/` (+ `index.ts`)
- `presentation/pages/shared/commonasset/generalmaster/paymentgateway.tsx`
- `page-components/setting/paymentconfig/paymentgateway/` (+ `index.ts`)
- `presentation/pages/setting/paymentconfig/paymentgateway.tsx`
- `app/[lang]/(core)/setting/paymentconfig/paymentgateway/page.tsx`

Grep for `PaymentGatewayDataTable` before deleting and clear every import. Neither route was reachable from a seeded menu (§1c), so nothing user-facing regresses.

---

## ⑦ Menus — hide, never delete

`PAYMENTGATEWAY` keeps its `auth.Menus` row with `IsLeastMenu = false` and `IsActive = false`: invisible in navigation, capability rows intact. Deleting the row would strand `MenuCapabilities` and `RoleCapabilities` children and break any role-permission screen that joins them.

On `COMPANYPAYMENTGATEWAY`, **revoke nothing.** CREATE and DELETE are correct there — a tenant creates and deletes its *own* configurations (§1d). The user's "no create" is about the master catalogue, which §4.3 removes at the mutation level, and about the unbounded "+ New" entry point, which §6.1 replaces with Tab 1's bounded Configure.

Seed SQL for the menu change goes in `sql-scripts-dyanmic/` for the user to apply. Idempotent, `WHERE NOT EXISTS` / guarded `UPDATE`, matching the style of `companypaymentgateway-sqlscripts.sql`.

---

## ⑧ Seed — `sql-scripts-dyanmic/paymentgateway-capability-seed.sql`

Idempotent, in this order:

1. **Insert PAYU** — `('PAYU', 'PayU India')`, guarded `WHERE NOT EXISTS`. Code must be exactly `PAYU`: the factory matches `"PAYU"`, not `PAYUINDIA`, and the provider *class* being `PayUIndiaProvider` is the trap that produced the same error in PROMPT-14 §3.2.
2. **`IsImplemented = true`** for BRAINTREE, RAZORPAY, PAYU. All others left `false`.
3. **`IsActive = false`** for STRIPE, PAYPAL, SQUARE. **MANUAL stays active** — it is an offline-payment marker that never reaches the factory, and deactivating it would break existing manual-donation records.
4. **`SupportsRecurring = true`** for all three implemented rows.
5. **`PaymentGatewayCurrencies` rows**, resolving `CurrencyId` by `CurrencyCode` subselect against `com."Currencies"`, guarded per pair:
   - **PayU** — INR only, `RequiresActivation = false`.
   - **Razorpay** — INR (`false`); USD, GBP, EUR, SGD, AED, AUD, CAD (`RequiresActivation = true` — Razorpay International).
   - **Braintree** — ⚠️ **PENDING USER INPUT.** Write the block with a documented placeholder set (USD, GBP, EUR, AUD, CAD) and a `-- TODO(user): replace with the currency list actually enabled on our Braintree merchant account` marker. Do not guess silently: Braintree's *possible* currency list is long and its *enabled* list is per-account, and an over-broad seed produces a false `Recommended`, which is worse than `Unknown`. The one currency that can be asserted without the account is the negative the user gave: **Braintree has no INR row.**
6. Skip any currency code absent from `com."Currencies"` rather than inserting a NULL FK. Emit a `RAISE NOTICE` per skip.

**Pre-existing bug, adjacent, do not silently absorb:** `PaymentGateway-MasterData-seed.sql` inserts TRANSACTIONSTATUS and SETTLEMENTSTATUS `sett.MasterDatas` whose parent `TypeCode` rows it never creates in that file, so those subselects resolve NULL. Out of scope here — flag it in §⑬ and leave it to the user.

---

## ⑨ Acceptance

Fit / recommendation:
1. Tenant with `Country = India` sees Razorpay **Recommended**, PayU **Recommended**, Braintree **Mismatch** with the INR reason sentence.
2. Tenant with `Country = United States` sees Braintree **Recommended**, Razorpay **Mismatch** or **Usable** per its seeded `RequiresActivation`.
3. Tenant with null `CountryId` sees all **Unknown** plus the Company-Settings hint. No crash.
4. A gateway with zero `PaymentGatewayCurrencies` rows renders **Unknown** and is still fully configurable (fail-open).
5. Indian tenant saves Braintree with `SupportedCurrencies = "USD,GBP"` — **succeeds**, with the amber Mismatch badge visible. This is the rare multi-currency case; if it fails, §⑤ is wrong.
6. Indian tenant saves Braintree with `SupportedCurrencies = "INR"` — **rejected**, error naming both INR and Braintree's actual currencies.
7. Razorpay + `"USD"` — **succeeds** (the old `ValidateRazorpayCurrencies` rejected this).
8. `grep -rn "ValidateRazorpayCurrencies"` across the backend returns **nothing**.

Catalogue:
9. The gateway dropdown offers exactly Braintree, Razorpay, PayU. STRIPE/PAYPAL/SQUARE absent.
10. `com."PaymentGateways"` has a `PAYU` row and `PaymentGatewayFactory` resolves it — the §⓪ bug is closed.
11. Tab 1 still lists deactivated legacy gateways, greyed, no actions.
12. `createPaymentGateway` and `deletePaymentGateway` are absent from the GraphQL schema.
13. An existing STRIPE per-company row still loads without exception.

Screen:
14. Edit on a card opens the edit modal. Toggle flips `IsActive` and the card reflects it after refetch. **Neither is a no-op.**
15. Test Connection returns a real provider verdict; no credential appears in the response, the toast, or the browser console.
15b. **Test Connection on a NON-default gateway with deliberately wrong credentials FAILS.** If it reports success, §2.1 was skipped and the default gateway was tested instead. Then break the *default* row's credentials and confirm a correctly-configured non-default row still passes.
15c. Test Connection with another tenant's `companyPaymentGatewayId` returns not-found, never a token (§2.1 double-id filter).
16. View Logs shows webhook rows for that gateway only; empty state when none.
17. "Webhook Status" and "Monthly Volume" lines are gone, not restyled.
18. No `+ New` on Tab 2. Configure on Tab 1 opens the form with the gateway pre-bound and not editable.
19. PayU renders its icon, not the `ph:credit-card` fallback.
20. No `bg-X-50`, `text-X-700`, `bg-muted` badge, or `text-[Npx]` remains in `gateway-card.tsx`.
21. `PAYMENTGATEWAY` menu is invisible in navigation; its `MenuCapabilities` rows still exist.
22. `grep -rn "PaymentGatewayDataTable"` returns nothing.
23. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` exits **0**. (Note: it exited 0 *before* this prompt too, with the no-op handlers in place — a clean typecheck is necessary, not sufficient. Items 14 and 19 need a browser.)

---

## ⑩ Out of scope — do not build

- **A gateway request/ticketing flow.** The user was explicit: ticketing comes later; build only against what exists. Tab 1 may state that unavailable gateways are added by the product team — as static text, with no form.
- **A Cashfree provider.** Mentioned as a likely future Indian option; there is no provider class, so a catalogue row would be a false promise. `SupportsRecurring` / `IsImplemented` make adding it later a seed row plus a provider class.
- **Touching `SupportedCurrencies` / `SupportedCountryCodes` / `SupportedPaymentMethods` on `fund.CompanyPaymentGateways`.** They stay CSV text on the tenant row. Normalising them is a migration across live tenant data for no behaviour §⑤ does not already give.
- **`ops.PlatformPaymentGateways` and the ops config screen** — PROMPT-14 §3.2 / §7.2, task T-A20. Different schema, different direction of money.
- **Monthly volume metrics.** §6.3 deletes the fake line; it does not build the real one.
- **Fixing the TRANSACTIONSTATUS / SETTLEMENTSTATUS master-data bug** (§⑧). Flag only.
- **REGISTRY ISSUE-14** (`.Designer.cs` missing for #167's migration) and **ISSUE-16** (`GET_PAYMENTGATEWAY_LIST` wrapped-shape unverified). ISSUE-16 becomes moot if §4.1 rewrites that query's consumer — say so in §⑬ rather than closing it silently.

---

## ⑪ Known traps

1. **`PAYU`, not `PAYUINDIA`.** The class is `PayUIndiaProvider`; the factory matches `"PAYU"`. This exact error shipped in PROMPT-14 §3.2 and had to be corrected.
2. **HotChocolate strips `Get`.** `GetGatewayRecommendations` → `gatewayRecommendations`. Input DTOs get `Input` appended. tsc cannot see gql field names — a wrong name builds clean and fails only at runtime.
3. **A clean typecheck proves nothing about the no-ops.** `() => {}` satisfies `(row) => void`. Items 14/15/19 require a browser.
4. **Fail-open here, fail-closed in PROMPT-14.** Deliberate (§3.2). Comment it or it gets "harmonised".
5. **`CreateCompanyPaymentGateway` returns plaintext credentials** — `result.EncryptedApiKey = command.companyPaymentGateway.EncryptedApiKey` echoes what the caller sent, post-encryption-to-DB. Pre-existing. Do not extend the pattern to Test Connection. Fixing the echo is a small, safe win if the builder is already in the file; if it turns out other callers depend on it, leave it and flag it.
6. **DB is UTC-only.** `timestamp with time zone` throughout; Npgsql throws on `Kind=Unspecified`. Use `DateTime.UtcNow`.
7. **The backend tree is gitignored** — the Grep tool returns zero `.cs` matches. Use `find -iname`, or scope `grep -rn --include=*.cs` to one project directory; a repo-wide backend grep times out. Absolute-path `Read` works.
8. **Deactivating MANUAL breaks manual donations.** Step 3 of §⑧ lists three codes. Not four.
9. **`GenerateClientTokenAsync` tests the DEFAULT gateway, not a chosen one** (§2.1). Reusing it directly makes Test Connection green on a broken row. Acceptance 15b exists to catch exactly this.
10. **`PaymentFlowService.cs` is the only file shared with PROMPT-14.** If both are in flight, PROMPT-15 owns it (§2.1).

---

## ⑫ Hand-off to the user (do not do these yourself)

1. **Author + apply the migration** for §3.1 (two columns on `com.PaymentGateways`) and §3.2 (`com.PaymentGatewayCurrencies` + its filtered unique index). Migrations are strictly user-owned — the build proves compile, nothing more.
2. **Apply `paymentgateway-capability-seed.sql`** (§⑧) after the migration.
3. **Apply the menu seed** (§⑦), then restart the API to clear the menu cache.
4. **Supply Braintree's enabled currency list** for §⑧ step 5 — the one blocking input. Everything else ships with the placeholder in place.
5. **Verify in a browser:** items 14, 15, 19 of §⑨.
6. `dotnet build` — the user's, always.

---

## ⑬ Build Log

_(Append one entry per session: date · what was built · what deviated from this spec and why · issues opened. Cap at the last 5 sessions — git keeps the rest. Preserve Known Issues across trims.)_

### 2026-07-30 — T-A21 built (BE + FE), migration + seeds handed off

**Built**
- BE: `IsImplemented` / `SupportsRecurring` on `com.PaymentGateways`; `com.PaymentGatewayCurrencies` (fail-open, commented); catalogue filter (§4.1); `GetGatewayRecommendations` → field `gatewayRecommendations`, no arguments; `TestGatewayConnection(companyPaymentGatewayId)` — row-specific, company from tenant context, failure returned inside a **success** envelope as `GatewayConnectionTestDto`; save-time warn-not-block (§⑤); `GetPaymentWebhookLogs` gained an optional `paymentGatewayId`, applied to the base query so `totalCount` is gateway-scoped.
- BE: catalogue create/delete path deleted (§4.3).
- FE: screen #167 is now two tabs on the **existing** route. Tab 1 `available-gateways-tab.tsx` — read-only catalogue joined to fit advice, `reason` rendered verbatim, retired rows greyed with "No longer available", implemented rows get **Configure**. Tab 2 — the existing card grid, `enableAdd: false`.
- FE: `gateway-card.tsx` rewritten — Edit/Toggle are now the DataTable's own `DataTableUpdateOption` / `DataTableToggleOption` fed a `makeRowMock` row; Test Connection calls the new mutation and reports a verdict only; Logs opens the new `webhook-log-drawer.tsx`; both SERVICE_PLACEHOLDER rows deleted; icon map = RAZORPAY / BRAINTREE / PAYU / MANUAL.
- FE: §6.4 house-rule pass (solid `bg-X-600` + `text-white`; every `text-[10px]`/`text-[11px]` → `text-xs`). Fit badges: Recommended emerald, Usable blue, **Mismatch amber (advice, not an error)**, Unknown slate.
- FE: §6.5 retirement — both duplicate master surfaces, their route file, the app-router folder, the `PAYMENTGATEWAY` gridCode operations entry, and the catalogue create/delete mutation documents are gone; barrels cleaned.
- Seeds written, not applied: `paymentgateway-capability-seed.sql`, `paymentgateway-menu-hide-seed.sql`.
- `npx tsc --noEmit --incremental false` → **exit 0** (real run, not a config-error no-op). `dotnet build` is the user's.

**Deviations this session**
- `PaymentGatewayCardConfig` reduced to `onViewLogs` only. Edit/Toggle cannot be page-level callbacks — the page sits outside the advanced-table provider, which is precisely why the old `() => {}` pair was dead. The card renders the store-driven CRUD options instead.
- Tab 1 "Configure" switches to Tab 2 and opens the create dialog via the modal store's `triggerGridAction("new-record")` — the same bridge Alt+N uses. It does **not** pre-bind `PaymentGatewayId`: the shared RJSF pipeline seeds form data from the primary key alone. A toast names the gateway to select. Pre-binding would mean changing `data-table-add-option.tsx` for one screen.
- The menu seed also sets `IsVisible`, beyond the two columns the spec named.
- Webhook-log query deliberately omits `rawPayload` (provider payloads carry customer/card metadata the drawer has no use for).
- ISSUE-16 is moot — `GET_PAYMENTGATEWAY_LIST` is now only the form dropdown source and its wrapped shape was verified against the resolver.

**Deviations to record when building:**
- Route kept at `companypaymentgateway`, not REGISTRY #167's proposed `paymentgateways` (§6.1) — avoids orphaning the seeded `MenuUrl`.
- `com.PaymentGatewayCurrencies` fails **open**; PROMPT-14 §3.3's `ops.PlatformGatewayCurrencies` fails **closed** (§3.2).
- Braintree currency rows seeded from a placeholder set pending §⑫ item 4.

**Known Issues carried in:**
- ISSUE-14 (#167) — `.Designer.cs` not generated for the original migration. OPEN MED.
- ISSUE-16 (#167) — `GET_PAYMENTGATEWAY_LIST` wrapped-shape assumption unverified. CLOSED 2026-07-30 — verified against the resolver.
- `PaymentGateway-MasterData-seed.sql` inserts TRANSACTIONSTATUS / SETTLEMENTSTATUS MasterDatas with no parent `MasterDataTypes` row → NULL subselects. OPEN, out of scope (§⑩).
- `CreateCompanyPaymentGateway` echoes plaintext credentials in its response (§⑪.5). OPEN LOW.
