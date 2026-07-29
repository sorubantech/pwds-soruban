# P-02b Migration Spec (amendment) — Multi-currency plan pricing

> **Fold into the P-02 billing migration if it has NOT been run yet.** If P-02's migration
> (`Add_Billing_Plans_Subscriptions_Usage`) is already applied, treat everything below as a
> **standalone follow-up migration** instead (suggested name:
> `Add_Billing_PlanPrices_Subscription_PriceSnapshot_And_CurrencyFks`).
>
> **⚠ Currency is a FK (`int CurrencyId → com."Currencies"`), NOT a string.** To match the
> platform-wide convention (every money-bearing entity carries `int CurrencyId` + a `Currency` nav —
> e.g. `grant.GrantFundReceipt`), **all three** billing currency columns are int FKs:
> `Plans.CurrencyId`, `PlanPrices.CurrencyId`, `Subscriptions.CurrencyId`. **This changes a P-02
> column** (`Plans."Currency" varchar` → `Plans."CurrencyId" int`) — see §0. The snapshot rule is
> unaffected: it governs the price/rate **VALUE** (`Subscriptions."Amount"`), never currency identity.
>
> **Author/run policy:** migrations are strictly user-owned. This session did **not** run
> `dotnet ef migrations add` / `database update` / `remove` and did **not** hand-author a migration
> or model-snapshot file. The new entity + EF configs + the changed/added columns compile and map;
> author the migration (or amend the P-02 one) from this spec, run it, and commit it.
>
> **Prerequisite:** `com."Currencies"` must be seeded before the seeds run (currency codes are
> resolved to `CurrencyId` by JOIN). **Seed order after migrating:** (1) `billing-plan-catalog-seed.sql`,
> then (2) `billing-backfill-subscriptions.sql`, then (3) **`billing-plan-prices-seed.sql`** (new —
> needs the plans to exist).

---

## 0. Change existing column — `billing."Plans"."Currency"` → `"CurrencyId"` (FK)

The P-02 `Plans` table shipped `Currency varchar(10)` (a string ISO code). Convert it to an int FK.

| Column | Type | Null | Notes |
|---|---|---|---|
| `CurrencyId` | `integer` | NOT NULL | **FK → com."Currencies"(CurrencyId)**, `ON DELETE RESTRICT` |

- **If folding into the P-02 migration (not yet run):** simply define `Plans."CurrencyId" integer NOT NULL`
  with the FK instead of the old `Currency varchar` column — the string column never existed.
- **If P-02 is already applied:** this is a type-changing alter. Recommended order in `Up`:
  1. `ADD COLUMN "CurrencyId" integer NULL;`
  2. backfill: `UPDATE billing."Plans" p SET "CurrencyId" = c."CurrencyId" FROM com."Currencies" c WHERE c."CurrencyCode" = p."Currency";`
  3. `ALTER COLUMN "CurrencyId" SET NOT NULL;` add `FK_Plans_Currencies_CurrencyId` (RESTRICT);
  4. `DROP COLUMN "Currency";`
  (EF's generated migration will express this as `AddColumn` + `DropColumn` + `AddForeignKey`; insert the
  backfill `UPDATE` between the add and the `SET NOT NULL` so no row violates the constraint.)

FK: `FK_Plans_Currencies_CurrencyId`: `Plans."CurrencyId" → com."Currencies"(CurrencyId)`, **`ON DELETE RESTRICT`**.

---

## 1. New table — `billing."PlanPrices"` (the curated price book)

One row per sellable **(Plan, Currency, BillingCycle)** combination. Carries the Entity base audit
columns (`CreatedBy` int NULL, `CreatedDate` timestamptz NULL, `ModifiedBy` int NULL, `ModifiedDate`
timestamptz NULL, `IsActive` boolean NULL, `IsDeleted` boolean NULL) — omitted below for brevity, as
elsewhere in the P-02 spec.

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `PlanPriceId` | `integer` | NOT NULL | identity (always) | PK |
| `PlanId` | `integer` | NOT NULL | — | **FK → billing."Plans"(PlanId)** |
| `CurrencyId` | `integer` | NOT NULL | — | **FK → com."Currencies"(CurrencyId)** |
| `Amount` | `numeric(18,2)` | NOT NULL | — | hand-set marketing price in the currency |
| `BillingCycle` | `varchar(20)` | NOT NULL | — | `Monthly\|Annual` |

**FKs**
- `FK_PlanPrices_Plans_PlanId`: `PlanId → billing."Plans"(PlanId)`, **`ON DELETE CASCADE`**
  (deleting a plan removes its price rows).
- `FK_PlanPrices_Currencies_CurrencyId`: `CurrencyId → com."Currencies"(CurrencyId)`,
  **`ON DELETE RESTRICT`** (a currency in use by a price row is never cascade-deleted).

**Indexes**
- `IX_PlanPrices_PlanId_CurrencyId_BillingCycle` — **UNIQUE** on (`PlanId`, `CurrencyId`, `BillingCycle`)
  — at most one price row per sellable combo.

> Note: `IsActive` (deactivate a price without deleting) reuses the Entity base column — **not**
> re-declared on the entity, so there is no duplicate/shadow column. `billing."Plans"` keeps its base
> `Price`/`CurrencyId`/`BillingCycle` (the anchor list price and the FX-fallback source); `PlanPrices`
> is the curated override layer on top.

---

## 2. Amend existing table — `billing."Subscriptions"` (currency/amount snapshot)

Add **4 additive, nullable** columns to the (already-specified in P-02 §5) `Subscriptions` table so
existing / backfilled rows stay valid:

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `CurrencyId` | `integer` | NULL | — | **FK → com."Currencies"(CurrencyId)** — currency the tenant subscribed in (snapshot of identity) |
| `Amount` | `numeric(18,2)` | NULL | — | price charged at subscription time (snapshot VALUE) |
| `BillingCycle` | `varchar(20)` | NULL | — | `Monthly\|Annual` at subscription time (snapshot) |
| `PaymentGatewayCode` | `varchar(30)` | NULL | — | e.g. `RAZORPAY`/`STRIPE` — **plain string, NO FK** (gateway config deferred) |

**FK**
- `FK_Subscriptions_Currencies_CurrencyId`: `CurrencyId → com."Currencies"(CurrencyId)`,
  **`ON DELETE RESTRICT`**. Nullable (NULL on P-02-backfilled rows). This is a snapshot of currency
  **identity**; the snapshot rule concerns the price/rate **VALUE** (`Amount`), which is never rewritten
  by a later price-book / FX edit.

No new unique index. `CurrencyId` gets the ordinary FK index EF emits for a foreign key.

> If folding into the P-02 migration (not yet run), just add these 4 columns to the `Subscriptions`
> `CreateTable` call. If P-02 is already applied, emit them as `AddColumn` steps + `AddForeignKey`.

---

## 3. Backfill — snapshot columns on existing subscription rows

For subscription rows that predate this amendment (the P-02 CUSTOM/Active backfill rows), copy a
coherent snapshot from their plan so history is at least self-consistent. Run this **after** the
columns exist (part of the same migration's `Up`, or a one-off script the user applies):

```sql
UPDATE billing."Subscriptions" s
SET "CurrencyId"   = p."CurrencyId",     -- copy the plan's base currency FK (Plans.CurrencyId, now int)
    "BillingCycle" = COALESCE(p."BillingCycle", 'Monthly'),
    "Amount"       = p."Price",
    "PaymentGatewayCode" = NULL          -- unknown for legacy / CUSTOM-backfill rows
FROM billing."Plans" p
WHERE s."PlanId" = p."PlanId"
  AND s."CurrencyId" IS NULL;            -- idempotent: only unstamped rows
```

- `CurrencyId` copies the plan's base currency FK (`Plans."CurrencyId"`, itself an int FK after §0).
- `PaymentGatewayCode` stays NULL — the gateway is genuinely unknown for legacy rows.
- The `AND s."CurrencyId" IS NULL` guard makes the backfill idempotent and non-destructive to any row
  already carrying a real snapshot.

---

## 4. Summary of migration objects

| Object | Kind | Action |
|---|---|---|
| `billing."Plans"."Currency"` → `"CurrencyId"` | column | change `varchar(10)` → `integer` NOT NULL, FK→com."Currencies" RESTRICT (backfill by code; §0) |
| `billing."PlanPrices"` | table | create (PK identity, FK→Plans CASCADE, FK→com."Currencies" RESTRICT, unique `(PlanId,CurrencyId,BillingCycle)`) |
| `billing."Subscriptions"."CurrencyId"` | column | add `integer` NULL, FK→com."Currencies" RESTRICT |
| `billing."Subscriptions"."Amount"` | column | add `numeric(18,2)` NULL |
| `billing."Subscriptions"."BillingCycle"` | column | add `varchar(20)` NULL |
| `billing."Subscriptions"."PaymentGatewayCode"` | column | add `varchar(30)` NULL |
| (data) `Plans` currency backfill | UPDATE…FROM | resolve old `Currency` code → `CurrencyId` before `SET NOT NULL` (§0) |
| (data) subscription snapshot backfill | UPDATE…FROM | run after columns exist |

`Plans` changes only its currency column (§0). No changes to `PlanEntitlements`, `PlanQuotas`,
`SubscriptionOverrides`, `UsageCounters`.
