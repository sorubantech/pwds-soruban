-- =====================================================================================
-- P-02b — Billing curated price book seed (billing.PlanPrices)
-- -------------------------------------------------------------------------------------
-- Seeds the per-currency marketing price book for the PAID plans (PLAN_50K, PLAN_100K)
-- across a starter set of currencies in BOTH billing cycles. This is the "BOOK" layer
-- resolved by IPlanPricingService: a curated PlanPrice hit wins over the FX fallback that
-- converts a plan's base Price/Currency (INR).
--
--   Currencies: INR (base), USD, EUR, GBP, AUD, SGD, AED, CAD.
--
-- FREE   -> NO price rows. IPlanPricingService special-cases a zero-price plan and returns
--           Amount=0 in whatever currency is requested (Source="FREE"). Seeding 0-rows here
--           would be redundant, so we deliberately omit them.
-- CUSTOM -> NO price rows. Enterprise is priced per-deal; a subscription snapshots its own
--           negotiated Amount/Currency, so there is no catalog book row.
--
-- PLACEHOLDER VALUES: every amount below is ILLUSTRATIVE marketing pricing (round numbers,
--   not FX-exact). They are edited later via the Plan Catalog admin screen. Only the SHAPE
--   (which currencies × cycles are sellable per plan) matters for the MVP.
--
-- IDEMPOTENT: every INSERT is guarded (NOT EXISTS on the natural key
--   (PlanId, CurrencyId, BillingCycle)). Re-running is a no-op.
-- SAFE: additive only. No DROP / UPDATE / schema change.
-- CURRENCY IS AN FK: billing."PlanPrices"."CurrencyId" -> com."Currencies". The ISO code in each
--   VALUES row is resolved to its CurrencyId via a JOIN to com."Currencies"; any code missing from
--   com."Currencies" is silently skipped (its price row is not seeded).
-- PREREQUISITE: run AFTER the P-02 (+P-02b amendment) migration is applied AND AFTER
--   billing-plan-catalog-seed.sql (needs billing.Plans rows to resolve PlanId by PlanCode) AND
--   after com."Currencies" is seeded (INR/USD/EUR/GBP/AUD/SGD/AED/CAD must exist).
-- =====================================================================================

BEGIN;

INSERT INTO billing."PlanPrices"
  ("PlanId","CurrencyId","Amount","BillingCycle","CreatedDate","IsActive","IsDeleted")
SELECT p."PlanId", cur."CurrencyId", v."Amount", v."BillingCycle", now(), true, false
FROM billing."Plans" p
JOIN (VALUES
  -- ── PLAN_50K (Growth) ─────────────────────────────────────────────────────────────
  --   Annual
  ('PLAN_50K','INR',  50000::numeric, 'Annual'),
  ('PLAN_50K','USD',    599::numeric, 'Annual'),
  ('PLAN_50K','EUR',    559::numeric, 'Annual'),
  ('PLAN_50K','GBP',    479::numeric, 'Annual'),
  ('PLAN_50K','AUD',    899::numeric, 'Annual'),
  ('PLAN_50K','SGD',    799::numeric, 'Annual'),
  ('PLAN_50K','AED',   2199::numeric, 'Annual'),
  ('PLAN_50K','CAD',    799::numeric, 'Annual'),
  --   Monthly
  ('PLAN_50K','INR',   5000::numeric, 'Monthly'),
  ('PLAN_50K','USD',     59::numeric, 'Monthly'),
  ('PLAN_50K','EUR',     55::numeric, 'Monthly'),
  ('PLAN_50K','GBP',     47::numeric, 'Monthly'),
  ('PLAN_50K','AUD',     89::numeric, 'Monthly'),
  ('PLAN_50K','SGD',     79::numeric, 'Monthly'),
  ('PLAN_50K','AED',    219::numeric, 'Monthly'),
  ('PLAN_50K','CAD',     79::numeric, 'Monthly'),
  -- ── PLAN_100K (Full Suite) ────────────────────────────────────────────────────────
  --   Annual
  ('PLAN_100K','INR', 100000::numeric, 'Annual'),
  ('PLAN_100K','USD',   1199::numeric, 'Annual'),
  ('PLAN_100K','EUR',   1099::numeric, 'Annual'),
  ('PLAN_100K','GBP',    949::numeric, 'Annual'),
  ('PLAN_100K','AUD',   1799::numeric, 'Annual'),
  ('PLAN_100K','SGD',   1599::numeric, 'Annual'),
  ('PLAN_100K','AED',   4399::numeric, 'Annual'),
  ('PLAN_100K','CAD',   1599::numeric, 'Annual'),
  --   Monthly
  ('PLAN_100K','INR',  10000::numeric, 'Monthly'),
  ('PLAN_100K','USD',    119::numeric, 'Monthly'),
  ('PLAN_100K','EUR',    109::numeric, 'Monthly'),
  ('PLAN_100K','GBP',     94::numeric, 'Monthly'),
  ('PLAN_100K','AUD',    179::numeric, 'Monthly'),
  ('PLAN_100K','SGD',    159::numeric, 'Monthly'),
  ('PLAN_100K','AED',    439::numeric, 'Monthly'),
  ('PLAN_100K','CAD',    159::numeric, 'Monthly')
) AS v("PlanCode","Currency","Amount","BillingCycle") ON v."PlanCode" = p."PlanCode"
JOIN com."Currencies" cur ON cur."CurrencyCode" = v."Currency" AND COALESCE(cur."IsDeleted", false) = false
WHERE NOT EXISTS (
  SELECT 1 FROM billing."PlanPrices" pp
  WHERE pp."PlanId" = p."PlanId"
    AND pp."CurrencyId" = cur."CurrencyId"
    AND pp."BillingCycle" = v."BillingCycle"
);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--   SELECT p."PlanCode", pp."BillingCycle", count(*) AS currencies
--     FROM billing."PlanPrices" pp
--     JOIN billing."Plans" p ON p."PlanId" = pp."PlanId"
--     GROUP BY p."PlanCode", pp."BillingCycle" ORDER BY 1,2;
--     -> expect PLAN_50K/Annual=8, PLAN_50K/Monthly=8, PLAN_100K/Annual=8, PLAN_100K/Monthly=8
--   SELECT count(*) FROM billing."PlanPrices";  -> expect 32
-- =====================================================================================
