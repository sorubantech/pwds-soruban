# PROMPT 23 — Commercial Term UX (plan-driven currency / cycle / gateway) + deal→subscription pricing integrity

**Status:** NOT BUILT.
**Surface:** BE (2 new queries in `OpsBusiness/LeadManagement/Queries`, 2 resolvers on `LeadQueries.cs`, 2 validator additions, 1 provisioning Step-2 rewrite, 1 pricing-service guard) · FE (`deal-form-dialog.tsx`, `deal-form-schemas.ts`, 2 constant files, 1 new gql query file section) · **no migration** (no schema change) · **no seed SQL**.
**Depends on:** PROMPT-13 (`billing.PlanPrice` + `IPlanPricingService`), PROMPT-14 (plan catalog), PROMPT-15 (`ops.PlatformPaymentGateways` + `PlatformGatewayCurrencies`), P-05/P-05c (the deal form as it stands today).
**Trigger:** *"ok then the currency fields we need to display planprice distict currency only. Then billing cyclselection based those relevant amunts and other detailis we need to show in that below - ux improvement. Then payment gateway alsoauto select based on plan selected currency"* and *"ok now our discussion based create the prompt for that commercial term ux improvement and we dicussed issue"*

---

## ⚠️ Rules for whoever builds this

1. **Do NOT run `dotnet build`.** The user builds the backend. Write the code, stop.
2. **Migrations are strictly user-owned.** Never run `dotnet ef migrations add/remove` or `database update`, never hand-author a migration or a snapshot. *This prompt needs none — if you think it does, you have gone out of scope; stop and ask.*
3. **Seed SQL:** none is required here. Do not invent a seed file.
4. **`PSS_2.0_Backend/` is gitignored** → the Grep/Glob tools return ZERO `.cs` matches. Use `find -iname` to locate files, or scope `grep -rn --include=*.cs` to ONE project subdirectory (a repo-wide backend grep times out at 120s). Absolute-path `Read` works fine.
5. **Frontend typecheck:** `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` with NO pipe. Only exit 0 counts as clean.
6. **HotChocolate strips `Get`** from every resolver name and appends `Input` to input types. `GetPlanSellableMatrix` surfaces as `planSellableMatrix`. tsc cannot see gql field names — a wrong name builds clean and fails only at runtime. Read the resolver, then write the query document.
7. **DB is UTC-only.** Every Postgres date column is `timestamp with time zone`; Npgsql throws on `Kind=Unspecified`.
8. **`ops` is platform-global.** Every read of an `ops` table needs `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true` guard.
9. **Money is never computed on the client.** The deal form's own header comment already says so. The new panel *displays* server-returned numbers; it must not multiply `amount × (1 - discount/100)` in TSX.

---

## ⓪ Verified on disk 2026-08-04

| What | Where | State |
|---|---|---|
| Deal form dialog | `PSS_2.0_Frontend/src/presentation/components/page-components/ops/deals/deal-form-dialog.tsx` (257 lines) | Currency picker runs an **unfiltered** `CURRENCIES_QUERY`; no price preview anywhere; gateway is a hard-coded 3-option `FormSelect` |
| Deal form zod schema | `.../deals/deal-form-schemas.ts` (39 lines) | `termMonths` = int 1..120, no relation to `billingCycle` |
| Plan picker options | `src/domain/entities/ops-service/LeadDto.ts:25-36` `PLAN_CODE_OPTIONS` | Static 4-entry list. Its comment ("the billing schema exposes no GraphQL read yet") is **stale** — `Base.API/EndPoints/Billing/` exists |
| Gateway picker options | `src/domain/entities/ops-service/CommercialTermDto.ts:10-32` `PAYMENT_GATEWAY_OPTIONS` | Static `RAZORPAY`/`STRIPE` + a blank. Carries a `TODO:` to source it from a platform setting |
| Term entity | `Base.Domain/Models/OpsModels/CommercialTerm.cs` | 15 business columns incl. `ListAmount`, `DiscountPercent`, `DiscountAmount`, `NetAmount`, `TermMonths`, `PaymentGatewayCode` (plain string, no FK) |
| Create command | `Base.Application/Business/OpsBusiness/LeadManagement/Commands/CreateCommercialTerm.cs` | `[CustomAuthorize("PLATFORM_LEADS", "PLATFORM_LEAD_EDIT")]`. Validator has **no** PlanCode-exists rule and **no** cross-field cycle↔term rule. Pricing via `internal static class CommercialTermPricing` (line 98) → `IPlanPricingService` |
| Price book | `Base.Domain/Models/BillingModels/PlanPrice.cs` | UNIQUE (PlanId, CurrencyId, BillingCycle); `Amount` decimal(18,2) |
| Price resolver | `Base.Infrastructure/Services/Billing/PlanPricingService.cs` | FREE → BOOK (line 75) → FX (line 90, gated by `FX_DERIVED_PRICING_ENABLED`, default OFF) → null |
| Resolution DTO | `Base.Application/Interfaces/IPlanPricingService.cs` | `PriceResolution(Amount, CurrencyId, CurrencyCode, BillingCycle, Source, FxRateUsed?, FxRateDate?)` |
| Gateway↔currency map | `Base.Domain/Models/OpsModels/PlatformGatewayCurrency.cs`, `PlatformPaymentGateway.cs` | Join row (GatewayId, CurrencyId); gateway carries `PaymentGatewayId`, `Priority`, `GatewayEnvironment`, encrypted secrets |
| Existing plan read | `Base.Application/Business/BillingBusiness/PlanCatalog/Queries/GetPlanCatalog.cs` | Returns `PlanPriceDto` list — but gated `PLATFORM_PLANS`/`PLATFORM_PLAN_VIEW`/`PLATFORM_PLAN_EDIT`, and ships entitlements + quotas. **Wrong capability and wrong payload for a salesperson.** |
| Existing gateway read | `Base.API/EndPoints/Billing/Queries/PlatformGatewayQueries.cs` | `GetPlatformGatewayConfig`, gated `PLATFORM_BILLING`. **Wrong audience.** |
| Where the new resolvers go | `Base.API/EndPoints/Ops/Queries/LeadQueries.cs` | Already hosts `GetLeads` (36), `GetLeadById` (65), `GetAssignableLeadOwners` (90), `GetCommercialTerms` (110), `GetCommercialTermById` (135) |
| Provisioning step 2 | `Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs` (~line 520) | Re-resolves the **list** price from the wizard payload; never loads the CommercialTerm |

### The four defects this prompt exists to close

**D1 — the discount dies at the ops→billing boundary (most business-visible).**
`ProvisionTenant` Step 2 stores `CommercialTermId` on the new `Subscription` but never reads the row. It calls `_planPricingService.ResolveAsync(req.PlanCode, req.CurrencyId, req.BillingCycle, ct)` and writes `Amount = price.Amount` — the **list** price. So an approved 20 %-off deal provisions a tenant billed at full list. `DiscountPercent`, `DiscountAmount`, `NetAmount` and `TermMonths` are all lost. Nothing asserts that the wizard's plan/currency/cycle even match the APPROVED term. Additionally `PriceSource`, `FxRateUsed` and `FxRateDate` are left null on the subscription although `PriceResolution` returns all three.

**D2 — the FX fallback can mislabel a cycle and overcharge 12×.**
`PlanPricingService` line 110 computes `plan.Price * rate` and line 118 returns it tagged with the **requested** `cycle`. `Plan.BillingCycle` is never compared to the request. An Annual-anchored plan priced 5000 returns 5000 labelled "Monthly" whenever the BOOK row is missing and `FX_DERIVED_PRICING_ENABLED` is on. The BOOK path (line 81) is correct — this is FX-only.

**D3 — `TermMonths` is inert.**
Validated (1..120), stored, rendered (`· 6 mo` in `deal-list-page.tsx:347`) — and read by no business logic anywhere. No cancellation guard, no contract end date, no effect on `AutoRenew`, not carried to the subscription. *See §⑨ Q1: its intended meaning is still unanswered, so this prompt does **not** implement contract semantics — it only stops the nonsense combinations (D4) and carries the value forward.*

**D4 — no cross-field validation on cycle × term.**
"Annual + 2 months" saves cleanly today in both `CreateCommercialTerm.cs:41` (BE validator) and `deal-form-schemas.ts:18` (FE zod). A term shorter than one billing period cannot be billed by any renewal path.

---

## ① The one idea

**The deal form must only offer combinations the server can actually sell, and the approved number must be the number the tenant is billed.**

Today the salesperson guesses (any currency × any cycle × any gateway), the server rejects at provisioning time, and when it *doesn't* reject, the discount they negotiated silently evaporates. This prompt makes the plan drive the form — currency list, cycle list, live amounts, gateway — and makes provisioning copy the approved `NetAmount` instead of re-deriving list price.

---

## ② Design

### 2a. One query feeds requests 1 and 2

A single new read returns the plan's whole sellable matrix; the FE derives both the currency dropdown and the amount panel from it. No second round-trip when the cycle changes.

```
GetPlanSellableMatrixQuery(string PlanCode, decimal DiscountPercent)
  → PlanSellableMatrixResult(
        bool PlanFound,
        string PlanCode,
        string PlanName,
        IReadOnlyList<SellableCurrencyDto> Currencies)

SellableCurrencyDto(int CurrencyId, string CurrencyCode, string CurrencySymbol,
                    IReadOnlyList<SellableCycleDto> Cycles)

SellableCycleDto(string BillingCycle,       // Monthly | Annual
                 decimal ListAmount,
                 decimal DiscountAmount,    // server-computed from DiscountPercent
                 decimal NetAmount,
                 string PriceSource)        // FREE | BOOK | FX
```

- Built by calling `IPlanPricingService.ResolveAsync(planCode, currencyId, cycle, ct)` for each candidate (currency, cycle) pair and **dropping every null** — a null *is* "not sellable", so the matrix is by construction only sellable combinations.
- Candidate currency set = `DISTINCT CurrencyId` from `billing.PlanPrice` for that plan, **plus** the plan's own anchor `Plan.CurrencyId`. (A FREE plan is sellable everywhere — see §⑥ INV-4.)
- `DiscountPercent` is a query argument so the panel shows the *negotiated* net, not just list. It is a display convenience; the authoritative computation still happens in `CreateCommercialTerm`/`UpdateCommercialTerm`. **Reuse `CommercialTermPricing`'s arithmetic — do not re-implement rounding.**
- Gated `[CustomAuthorize("PLATFORM_LEADS", "PLATFORM_LEAD_EDIT")]` to match `CreateCommercialTermCommand`. **Do not reuse `GetPlanCatalog`** — a `PLATFORM_SALES` user does not hold `PLATFORM_PLAN_VIEW`, and the catalogue payload leaks entitlements and quotas they have no business seeing.

### 2b. Gateway routing query

```
GetGatewaysForCurrencyQuery(int CurrencyId)
  → IReadOnlyList<GatewayRouteDto>(string PaymentGatewayCode, string PaymentGatewayName,
                                   int Priority, bool IsDefault)
```

- Join `ops.PlatformGatewayCurrencies` → `ops.PlatformPaymentGateways`, active + not deleted, ordered by `Priority` ascending. `IsDefault = true` on the lowest-priority row only.
- Same capability gate. **Returns no credential of any kind** — code, name and priority only. (`PlatformGatewayQueries.cs` states the rule: "There is no query in the product that can read a stored credential back out." Keep it true.)

### 2c. The plan picker stops being a hard-coded list

`PLAN_CODE_OPTIONS` in `LeadDto.ts` is a static 4-entry array whose comment is now false. Replace it with a lean plan-code read on the same capability:

```
GetSellablePlanCodesQuery() → IReadOnlyList<PlanOptionDto>(string PlanCode, string PlanName, bool IsCustom)
```

Active, non-deleted plans, ordered by `SortOrder`. Delete the constant and its stale comment.

### 2d. Provisioning reads the contract (D1)

`ProvisionTenant` Step 2 becomes:

1. If `req.CommercialTermId` is set → load the term (`IgnoreQueryFilters()` + `IsDeleted != true`).
2. **Assert `ApprovalStatus == APPROVED`** → otherwise `BadRequestException`. A DRAFT or REJECTED quote must never provision.
3. **Assert the term's `PlanCode` / `CurrencyId` / `BillingCycle` equal the wizard request's** → otherwise `BadRequestException` naming both sides. Silent divergence is how D1 became invisible.
4. Still call `ResolveAsync` — but only to obtain `PriceSource`, `FxRateUsed`, `FxRateDate` and to prove the combination is still sellable. Null ⇒ hard fail, unchanged.
5. Write `Amount = term.NetAmount` (**not** `price.Amount`), plus `PriceSource`, `FxRateUsed`, `FxRateDate` from the resolution.
6. **No term (direct sign-up, no quote)** → current behaviour exactly: `Amount = price.Amount`.

Step 2 keeps its "one transaction, idempotent, already-done check first" shape. Do not touch the other eight steps.

### 2e. Cycle-aware FX (D2)

In `PlanPricingService`, inside the FX branch **before** the conversion: if `plan.BillingCycle` does not equal the requested `cycle` (case-insensitive), **return null**. No derived cross-cycle price. Deriving Monthly from an Annual anchor requires a division policy nobody has decided — and guessing it is the 12× bug. A tenant who needs the other cycle gets a curated `PlanPrice` row, which is the intended mechanism anyway. Leave the BOOK path untouched.

---

## ③ Data

**No schema change. No migration. No seed.** Every column this prompt reads or writes already exists:

| Column | Table | Used for |
|---|---|---|
| `Amount`, `CurrencyId`, `BillingCycle` | `billing.PlanPrice` | matrix candidates |
| `Price`, `CurrencyId`, `BillingCycle`, `SortOrder`, `IsCustom` | `billing.Plans` | anchor price + plan options |
| `NetAmount`, `ListAmount`, `DiscountPercent`, `DiscountAmount`, `TermMonths`, `ApprovalStatus`, `PlanCode`, `CurrencyId`, `BillingCycle` | `ops.CommercialTerms` | contract read at Step 2 |
| `PaymentGatewayCode`, `Priority`, `IsActive` | `ops.PlatformPaymentGateways` | routing |
| `CurrencyId`, `PlatformPaymentGatewayId` | `ops.PlatformGatewayCurrencies` | routing |
| `Amount`, `PriceSource`, `FxRateUsed`, `FxRateDate`, `CommercialTermId` | `billing.Subscriptions` | Step 2 write (three of these are written for the first time) |

---

## ④ Build steps

**BE**

1. `Base.Application/Business/OpsBusiness/LeadManagement/Queries/GetPlanSellableMatrix.cs` — query record + result DTOs + handler per §2a. Capability `PLATFORM_LEADS` / `PLATFORM_LEAD_EDIT`.
2. `.../Queries/GetGatewaysForCurrency.cs` — per §2b.
3. `.../Queries/GetSellablePlanCodes.cs` — per §2c.
4. `Base.API/EndPoints/Ops/Queries/LeadQueries.cs` — three resolvers after `GetCommercialTermById` (line 135), following the file's existing shape exactly: `[Service] IMediator mediator`, try/catch, `ApiResponseHelper.ReturnObjectApiResponse(result)` / `BaseApiResponse<T>.Error(ex.Message)`. **Write down the field names HotChocolate will emit** (`planSellableMatrix`, `gatewaysForCurrency`, `sellablePlanCodes`) before writing the FE documents.
5. `CreateCommercialTerm.cs` validator — add (a) a PlanCode-exists rule against `billing.Plans` (active, not deleted); (b) the D4 cross-field rule: when `BillingCycle == "Annual"`, `TermMonths` (when supplied) must be `>= 12` **and** `% 12 == 0`; when `Monthly`, `>= 1`. Mirror both into `UpdateCommercialTerm.cs`.
6. `PlanPricingService.cs` — the §2e cycle guard, with a comment naming D2 so it is never "simplified" away.
7. `ProvisionTenant.cs` Step 2 — the §2d rewrite.

**FE**

8. `src/infrastructure/gql-queries/ops-queries/LeadQuery.ts` — three query documents matching the resolver-derived names.
9. `src/domain/entities/ops-service/CommercialTermDto.ts` — add the matrix/gateway/plan-option types; **delete `PAYMENT_GATEWAY_OPTIONS`** and its TODO.
10. `src/domain/entities/ops-service/LeadDto.ts` — **delete `PLAN_CODE_OPTIONS`** and its stale comment.
11. `deal-form-schemas.ts` — a `superRefine` carrying the same D4 rule as step 5, so the user sees it before submitting. (The BE rule stays — the FE can be bypassed.)
12. `deal-form-dialog.tsx` — §⑤.

---

## ⑤ UI notes

Field order in the existing `grid-cols-1 sm:grid-cols-2` is unchanged. What changes:

- **Plan** — `FormSelect` fed by `sellablePlanCodes`. Changing the plan **resets** `currencyId` to 0, `billingCycle` to "", and `paymentGatewayCode` to "" (a currency valid for plan A may not exist for plan B; leaving a stale value is how the server-side rejection happens today).
- **Currency** — no longer `CURRENCIES_QUERY`. A `FormSelect` over `matrix.currencies`, **disabled with the helper text "Select a plan first"** until a plan is chosen. When the matrix returns an empty list: disabled, helper text *"This plan has no published price yet — ask billing to add one."*
- **Billing cycle** — options narrowed to the cycles present for the chosen currency. If a currency only sells Annual, Monthly is simply absent.
- **Amount panel** (new, spanning both columns, directly under Billing cycle): `List <cur> <ListAmount>` → `Discount <DiscountPercent>% − <cur> <DiscountAmount>` → **`Net <cur> <NetAmount>`** emphasised. Amounts `text-right` (data context). Below it a muted line showing the price source: `Curated price` (BOOK) / `Converted at today's rate` (FX) / `Free plan` (FREE). All five numbers come from the query — **no arithmetic in TSX** (§⚠️ rule 9). Before a currency+cycle pair is chosen, render a shaped `Skeleton`, not an empty box.
- **Discount %** — unchanged input, but on change re-runs the matrix query (debounced ~300 ms) so the panel tracks it. Keep the existing `helperText`.
- **Term (months)** — unchanged input; helper text becomes cycle-aware: on Annual, *"Whole years only (12, 24, 36…)"*.
- **Payment gateway** — `FormSelect` fed by `gatewaysForCurrency(currencyId)`. On a currency change, **auto-select the `IsDefault` row** and show helper text *"Auto-selected for <CUR> — change if the deal needs a different processor."* Remains manually overridable and remains optional (blank → null on submit). The existing NaN-normalising `onChangeCallback` stays — `FormSelect` still numeric-coerces. If no gateway serves the currency: disabled, helper text *"No gateway configured for <CUR> — billing will route this manually."* (**not** a blocking error; the column is nullable today).
- Submit stays `disabled={!form.formState.isValid || saving}`. The DRAFT/threshold footer note is unchanged.
- All of the above is edit-mode-aware: an APPROVED term is already read-only (`CanEdit`), so the panel renders the stored `ListAmount`/`DiscountAmount`/`NetAmount` from the term rather than the live matrix. **A stored term never re-prices itself on open** — that would silently restate what was sold.

---

## ⑥ Invariants

- **INV-1** — money is server-computed. The FE displays; it never multiplies.
- **INV-2** — a `null` from `ResolveAsync` means "not sellable". Never substitute the base currency, never invent a rate.
- **INV-3** — a subscription's `Amount` is a **snapshot**. Step 2 copies the approved `NetAmount` by value; a later PlanPrice or FX edit must not restate it.
- **INV-4** — a FREE plan (`Price <= 0`) is sellable in every currency, `Source = "FREE"`, `Amount = 0`. The matrix must not filter it out.
- **INV-5** — an FX-derived price is only ever returned for the plan's own anchor cycle (D2).
- **INV-6** — only an `APPROVED` term may provision a tenant, and its plan/currency/cycle must match the provisioning request.
- **INV-7** — no query added here returns an API key, secret, webhook secret or any credential.
- **INV-8** — every `ops` read carries `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true` guard.
- **INV-9** — capability gating lives on the query **record**, not on the resolver method.

---

## ⑦ Out of scope

- Any schema change, migration or seed file. If the design seems to need one, stop and ask.
- Contract semantics for `TermMonths` — cancellation guards, contract end dates, `AutoRenew` interaction (blocked on §⑨ Q1). D3 is *documented* here, not *fixed*.
- Carrying `TermMonths` onto `billing.Subscriptions` (there is no column, and adding one is a migration).
- A currency-conversion UX, a rate-picker, or anything that turns `FX_DERIVED_PRICING_ENABLED` on.
- Gateway CRUD, gateway credential entry, or the `PlatformPaymentGateway` admin screen (PROMPT-15).
- Merging `ops.CommercialTerms` into `billing.Subscriptions` — considered and **rejected**: different owner FK (Lead vs Company, and no company exists at quote time), opposite cardinality (many quotes per lead vs the filtered unique index allowing one active subscription per company), and two unrelated state machines. The five overlapping columns are deliberate snapshots, not redundancy.
- Touching provisioning steps 1 and 3–9.

---

## ⑧ Acceptance

1. Opening the deal form with no plan chosen shows Currency **disabled** with "Select a plan first".
2. Choosing a plan populates Currency with **only** currencies that plan is priced in — verified against `SELECT DISTINCT "CurrencyId" FROM billing."PlanPrice" WHERE "PlanId" = …` plus the anchor currency.
3. Choosing a currency narrows Billing cycle to the cycles that exist for it.
4. Choosing a cycle renders the amount panel: list, discount, net, price source. Numbers match a direct `IPlanPricingService` resolution for the same triple.
5. Typing a discount updates the panel's discount and net (server-computed) without a page reload.
6. Changing the plan clears currency, cycle and gateway.
7. A plan with no published price shows the empty-state helper text and cannot be submitted.
8. Choosing a currency auto-selects the lowest-`Priority` active gateway serving it; the helper text names the currency; the picker can still be changed manually.
9. A currency with no configured gateway disables the picker with the manual-routing note and **still allows submit**.
10. Annual + `TermMonths = 2` is rejected by the FE **and** — with the FE bypassed via a direct GraphQL call — by the BE validator.
11. A non-existent `PlanCode` posted directly to `createCommercialTerm` is rejected by the validator.
12. **D1:** provisioning a tenant from an APPROVED 20 %-off term produces `billing.Subscriptions.Amount = term.NetAmount`, not the list price, and `PriceSource` / `FxRateUsed` / `FxRateDate` are populated.
13. **D1:** provisioning against a DRAFT term fails with a clear message; provisioning where the wizard's currency differs from the term's fails naming both.
14. **D1:** a direct sign-up with no `CommercialTermId` still provisions at list price exactly as before.
15. **D2:** with `FX_DERIVED_PRICING_ENABLED` on and an Annual-anchored plan, requesting Monthly in an unpriced currency returns `null` (not sellable) instead of the annual figure labelled Monthly.
16. An APPROVED term opened for viewing shows its **stored** amounts and does not re-price.
17. `npx tsc --noEmit --incremental false` exits 0.
18. `PLAN_CODE_OPTIONS` and `PAYMENT_GATEWAY_OPTIONS` no longer exist anywhere in the frontend.

---

## ⑨ Open questions

**Q1 (blocks D3) — what does `TermMonths` actually mean?** Three readings, three different builds:
   (a) **Commitment period** — the tenant may not cancel before it elapses ⇒ needs a cancellation guard in the subscription-cancel path.
   (b) **Contract end** — the subscription stops renewing after it ⇒ needs an end date on the subscription and an `AutoRenew` interaction (**and a migration**, which is why it is out of scope until answered).
   (c) **Sales note only** — no billing effect ⇒ relabel the field "Contract length (informational)" and stop implying it does something.
   *Until answered, this prompt only enforces D4 and carries the value nowhere.*

**Q2** — should the amount panel show the platform discount-approval threshold inline (e.g. "above 15 % this goes to the approval queue") so the salesperson knows before submitting? The value is in `sett.OrganizationSettings` `PLATFORM_DISCOUNT_APPROVAL_THRESHOLD_PCT` (CompanyId NULL); exposing it needs a decision on whether sales may see it.

**Q3** — for a CUSTOM/enterprise plan, is the price book expected to be empty (deal-desk prices it by hand)? If so the "no published price" empty state is wrong for that plan and needs a manual-amount path — which *would* be a schema change.

**Q4** — when a term is APPROVED and the underlying `PlanPrice` later changes, should the deal list flag the drift? (Snapshot rule says the term is right; the question is only whether to surface it.)

---

## ⑩ Build log

### 2026-08-04 — BUILT (D1, D2, D4 + sellable-matrix UX). D3 deliberately not built.

**Backend** — no migration, no seed, no schema change (as predicted by §⑦).

| # | File | Change |
|---|---|---|
| BE1 | `Base.Application/.../OpsBusiness/LeadManagement/Queries/GetPlanSellableMatrix.cs` | **NEW.** `GetPlanSellableMatrixQuery(planCode, discountPercent = 0m)` → `PlanSellableMatrixDto` / `SellableCurrencyDto` / `SellableCycleDto`. Probes every live currency × {Monthly, Annual} through `IPlanPricingService.ResolveAsync`; a pair it cannot resolve is simply absent. Amounts computed by the shared `CommercialTermPricing.Compute`, so the panel shows the rounding the write path will persist. Currencies with zero sellable cycles are dropped. |
| BE2 | `.../Queries/GetGatewaysForCurrency.cs` | **NEW.** `GatewayRouteDto` list for a currency: live `PlatformGatewayCurrency` row + `PaymentGateway.IsImplemented`, scoped to the live `PLATFORM_GATEWAY_ENVIRONMENT` (default Sandbox), ordered `Priority` then id, `IsDefault = index 0`. |
| BE3 | `.../Queries/GetSellablePlanCodes.cs` | **NEW.** `PlanOptionDto(PlanCode, PlanName, IsCustom)` from `billing.Plans` (`IsDeleted != true && IsActive`). Not filtered by `IsPubliclyListed` — the internal desk is exactly where an unlisted plan gets sold; `IsCustom` marks it. |
| BE4 | `Base.API/EndPoints/Ops/Queries/LeadQueries.cs` | Three resolvers appended → fields `sellablePlanCodes`, `planSellableMatrix`, `gatewaysForCurrency`. |
| BE5 | `.../Commands/CreateCommercialTerm.cs`, `UpdateCommercialTerm.cs` | **D4.** `CommercialTermPricing` gained `Compute`, `IsTermCoherentWithCycle` (Annual ⇒ `TermMonths >= 12 && % 12 == 0`) and `PlanExistsAsync`; both validators enforce them. "Annual + 2 months" no longer saves. |
| BE6 | `Base.Infrastructure/Services/Billing/PlanPricingService.cs` | **D2.** The FX branch now projects `Plan.BillingCycle` and returns `null` unless it matches the requested cycle. An Annual-anchored plan can no longer return an annual figure labelled Monthly (12× overcharge). |
| BE7 | `.../TenantProvisioning/Commands/ProvisionTenant.cs` | **D1.** `Step2_CreateSubscriptionAsync` loads the `CommercialTerm` when `CommercialTermId` is present, rejects anything not `APPROVED`, takes plan/currency/cycle/gateway from the term, still calls `ResolveAsync` (fail-closed + provenance) and persists `Amount = term.NetAmount`, plus `PriceSource` / `FxRateUsed` / `FxRateDate` — previously all null and the tenant was billed list price. Steps 1 and 3–9 untouched. |

**Frontend** — `npx tsc --noEmit --incremental false` → **exit 0**.

| # | File | Change |
|---|---|---|
| FE8 | `infrastructure/gql-queries/ops-queries/LeadQuery.ts` | `SELLABLE_PLAN_CODES_QUERY`, `PLAN_SELLABLE_MATRIX_QUERY`, `GATEWAYS_FOR_CURRENCY_QUERY`. |
| FE9 | `domain/entities/ops-service/CommercialTermDto.ts` | `PlanOptionDto`, `SellableCycleDto`, `SellableCurrencyDto`, `PlanSellableMatrixDto`, `GatewayRouteDto` added; **`PAYMENT_GATEWAY_OPTIONS` deleted**. |
| FE10 | `domain/entities/ops-service/LeadDto.ts` | **`PLAN_CODE_OPTIONS` deleted** (tombstone comment left in place). |
| FE11 | `.../ops/deals/deal-form-schemas.ts` | D4 mirrored as a `.superRefine` on `termMonths`; `emptyDealForm.billingCycle` `"Monthly"` → `""` (the cycle is a property of plan × currency, so pre-selecting one asserted a combination we may not sell). |
| FE12 | `.../ops/deals/deal-form-dialog.tsx` | Rewritten. Currency and cycle now come from the matrix (300 ms-debounced on `discountPercent`); gateway from `gatewaysForCurrency` with the `isDefault` route auto-selected; amount panel **displays** server numbers only (no `amount × (1 - d/100)` in TSX). A stored term shows its own persisted amounts until the operator touches plan/currency/cycle/discount (`pricingTouched`). Apollo cache staleness guarded by a `planCode` match check. |
| FE13 | `.../ops/deals/deal-list-page.tsx` | Plan filter dropdown now fed by `SELLABLE_PLAN_CODES_QUERY`. |
| FE14 | `.../ops/leads/lead-form-dialog.tsx` | `estimatedPlanCode` picker moved to `SELLABLE_PLAN_CODES_QUERY`; a lead sized against a since-retired plan keeps its stored code as a `"(retired)"` option rather than silently blanking. |

**Not built (deliberate):** D3 / `TermMonths` semantics — blocked on §⑨ Q1, value still carried nowhere.

**Interpretation calls made:**
1. §2b says gateways must be "active + not deleted"; the unique index is `(PaymentGatewayId, GatewayEnvironment)`, so an unfiltered read lists every gateway twice. `GetGatewaysForCurrency` therefore scopes to the live `PLATFORM_GATEWAY_ENVIRONMENT`.
2. §④ step 10 implies one `PLAN_CODE_OPTIONS` consumer; there were **three** (deal form, deal list filter, lead form). All three migrated.

**Deferred to the user (per CLAUDE.md):** nothing — this build needed no migration and no seed SQL. `dotnet build` not run.
