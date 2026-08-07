-- =====================================================================================
-- P-15 T-A21 — Payment gateway catalogue: implemented flags + per-gateway currency capability
-- -------------------------------------------------------------------------------------
-- WHY THIS EXISTS
-- The gateway catalogue in com."PaymentGateways" and the provider switch in PaymentGatewayFactory
-- had drifted apart, in both directions:
--
--   * PAYU is implemented in code (PayUIndiaProvider, matched on the code "PAYU") but has NO
--     catalogue row — so an Indian tenant could not select the one gateway built for it.
--   * STRIPE, PAYPAL and SQUARE have catalogue rows but NO provider — so a tenant could pick one,
--     save real credentials, mark it default, and first learn it does not work when a donor's
--     checkout throws NotSupportedException.
--
-- This script closes both halves and then catalogues which currencies each implemented gateway can
-- actually settle, which is what drives the Recommended / Usable / Mismatch advice on screen #167
-- and the one narrow save-time refusal in Create/UpdateCompanyPaymentGateway.
--
-- FAIL-OPEN BY DESIGN: a gateway with zero com."PaymentGatewayCurrencies" rows is treated as
-- "not catalogued yet" — it renders as Unknown and stays fully configurable. It is NOT treated as
-- "supports nothing". This is deliberately the opposite of the platform-side ops."PlatformGateway-
-- Currencies" table, which fails closed because it gates our own billing. Do not harmonise them.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on the natural key; every UPDATE is guarded by
-- a code list and is value-stable. Re-running is a no-op.
-- SAFE: no DROP, no DELETE, no schema change. STRIPE/PAYPAL/SQUARE are DEACTIVATED, never removed —
-- an existing fund."CompanyPaymentGateways" row pointing at one must still load and explain itself.
--
-- PREREQUISITE: run AFTER the T-A21 migration that adds com."PaymentGateways"."IsImplemented",
-- ."SupportsRecurring" and creates com."PaymentGatewayCurrencies". Without it, section 2 fails on
-- an unknown column.
-- =====================================================================================

BEGIN;

-- ── 1. PAYU catalogue row ────────────────────────────────────────────────────────────────────
-- The code must be exactly 'PAYU'. PaymentGatewayFactory switches on "PAYU"; the provider CLASS is
-- named PayUIndiaProvider, and seeding 'PAYUINDIA' to match the class name is the exact mistake
-- that produced a silent no-provider failure once already.
INSERT INTO com."PaymentGateways"
  ("PaymentGatewayCode","PaymentGatewayName","IsImplemented","SupportsRecurring",
   "CreatedDate","IsActive","IsDeleted")
SELECT 'PAYU', 'PayU India', true, true, now(), true, false
WHERE NOT EXISTS (
  SELECT 1 FROM com."PaymentGateways" g WHERE upper(g."PaymentGatewayCode") = 'PAYU'
);

-- ── 2. Capability flags ──────────────────────────────────────────────────────────────────────
-- IsImplemented is the selectable-catalogue filter: a code the factory can turn into a provider.
UPDATE com."PaymentGateways"
   SET "IsImplemented" = true,
       "SupportsRecurring" = true,
       "ModifiedDate" = now()
 WHERE upper("PaymentGatewayCode") IN ('BRAINTREE','RAZORPAY','PAYU')
   AND ("IsImplemented" IS DISTINCT FROM true OR "SupportsRecurring" IS DISTINCT FROM true);

-- Everything else is explicitly not implemented. Stated rather than assumed, so a row added by hand
-- later cannot inherit a stale true.
UPDATE com."PaymentGateways"
   SET "IsImplemented" = false,
       "ModifiedDate" = now()
 WHERE upper("PaymentGatewayCode") NOT IN ('BRAINTREE','RAZORPAY','PAYU')
   AND "IsImplemented" IS DISTINCT FROM false;

-- Deactivate the three that can never work. MANUAL is deliberately LEFT ACTIVE: it is an
-- offline-payment marker that never reaches the factory at all, and deactivating it would orphan
-- existing manual donation records.
UPDATE com."PaymentGateways"
   SET "IsActive" = false,
       "ModifiedDate" = now()
 WHERE upper("PaymentGatewayCode") IN ('STRIPE','PAYPAL','SQUARE')
   AND "IsActive" IS DISTINCT FROM false;

-- ── 3. Per-gateway currency capability ───────────────────────────────────────────────────────
-- RequiresActivation = true means "the provider settles this currency, but only after the merchant
-- enables it on their account" — Usable, not Recommended, and never a block.
--
-- Any currency code absent from com."Currencies" is SKIPPED with a notice rather than inserted with
-- a NULL FK: a broken row here would silently downgrade a gateway's advice for every tenant.
DO $$
DECLARE
  r            RECORD;
  v_gateway_id INT;
  v_currency_id INT;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      -- PayU India — domestic INR only.
      ('PAYU',      'INR', false),

      -- Razorpay — INR domestically; the rest require Razorpay International to be activated on
      -- the merchant account. The old hardcoded ValidateRazorpayCurrencies claimed INR-only and was
      -- simply wrong: it rejected configurations that work in production.
      ('RAZORPAY',  'INR', false),
      ('RAZORPAY',  'USD', true),
      ('RAZORPAY',  'GBP', true),
      ('RAZORPAY',  'EUR', true),
      ('RAZORPAY',  'SGD', true),
      ('RAZORPAY',  'AED', true),
      ('RAZORPAY',  'AUD', true),
      ('RAZORPAY',  'CAD', true),

      -- Braintree — TODO(user): replace with the currency list actually enabled on our Braintree
      -- merchant account. Braintree's *possible* currency list is long and its *enabled* list is
      -- per-account; an over-broad seed produces a false "Recommended", which is worse than
      -- "Unknown". The set below is a conservative placeholder.
      --
      -- The one entry that can be asserted without the account is the NEGATIVE: Braintree has no
      -- INR row, deliberately. Do not add one.
      ('BRAINTREE', 'USD', false),
      ('BRAINTREE', 'GBP', false),
      ('BRAINTREE', 'EUR', false),
      ('BRAINTREE', 'AUD', false),
      ('BRAINTREE', 'CAD', false)
    ) AS t(gateway_code, currency_code, requires_activation)
  LOOP
    SELECT g."PaymentGatewayId" INTO v_gateway_id
      FROM com."PaymentGateways" g
     WHERE upper(g."PaymentGatewayCode") = r.gateway_code
     LIMIT 1;

    IF v_gateway_id IS NULL THEN
      RAISE NOTICE 'Skipped % / % — gateway code not found in com."PaymentGateways".',
        r.gateway_code, r.currency_code;
      CONTINUE;
    END IF;

    SELECT c."CurrencyId" INTO v_currency_id
      FROM com."Currencies" c
     WHERE upper(c."CurrencyCode") = r.currency_code
       AND c."IsDeleted" IS DISTINCT FROM true
     LIMIT 1;

    IF v_currency_id IS NULL THEN
      RAISE NOTICE 'Skipped % / % — currency code not found in com."Currencies".',
        r.gateway_code, r.currency_code;
      CONTINUE;
    END IF;

    INSERT INTO com."PaymentGatewayCurrencies"
      ("PaymentGatewayId","CurrencyId","RequiresActivation","CreatedDate","IsActive","IsDeleted")
    SELECT v_gateway_id, v_currency_id, r.requires_activation, now(), true, false
    WHERE NOT EXISTS (
      SELECT 1 FROM com."PaymentGatewayCurrencies" pc
       WHERE pc."PaymentGatewayId" = v_gateway_id
         AND pc."CurrencyId" = v_currency_id
         AND pc."IsDeleted" IS DISTINCT FROM true
    );
  END LOOP;
END $$;

COMMIT;

-- ── Verification (run after COMMIT) ──────────────────────────────────────────────────────────
-- Expect exactly BRAINTREE, PAYU, RAZORPAY as implemented+active:
--   SELECT "PaymentGatewayCode","IsImplemented","SupportsRecurring","IsActive"
--     FROM com."PaymentGateways" ORDER BY "PaymentGatewayCode";
--
-- Expect PayU 1 row, Razorpay 8, Braintree 5 (and NO Braintree/INR pair):
--   SELECT g."PaymentGatewayCode", c."CurrencyCode", pc."RequiresActivation"
--     FROM com."PaymentGatewayCurrencies" pc
--     JOIN com."PaymentGateways" g ON g."PaymentGatewayId" = pc."PaymentGatewayId"
--     JOIN com."Currencies"      c ON c."CurrencyId"       = pc."CurrencyId"
--    ORDER BY g."PaymentGatewayCode", c."CurrencyCode";
