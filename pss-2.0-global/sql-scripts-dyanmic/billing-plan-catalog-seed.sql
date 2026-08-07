-- =====================================================================================
-- P-02 T-A5 — Billing plan catalog seed (Plans + PlanEntitlements + PlanQuotas)
-- -------------------------------------------------------------------------------------
-- Seeds the FOUR commercial tiers and their entitlement/quota matrix, verbatim from the
-- DECIDED map in PSS-2.0-ONBOARDING-DQ4-MODULE-PLAN-MAP.md (decided 2026-07-24):
--
--   Feature / Meter        Type      FREE      PLAN_50K   PLAN_100K   CUSTOM
--   FEATURE:CONTACTS        ent       on        on         on          on
--   FEATURE:DONATION        ent       on        on         on          on
--   FEATURE:EVENT           ent       off       on         on          on
--   FEATURE:VOLUNTEER       ent       off       on         on          on
--   FEATURE:MEMBERSHIP      ent       off       on         on          on
--   FEATURE:CASE            ent       off       off        on          on
--   FEATURE:GRANT           ent       off       off        on          on
--   CHANNEL:EMAIL          feat      on(cap)   on         on          on
--   CHANNEL:WHATSAPP       feat      off       off        on          on
--   CHANNEL:SMS            feat      off       off        on          on
--   CONTACTS               STOCK     2,000     500,000    1,000,000   unlimited*
--   DONATIONS              STOCK     25,000    5,000,000  10,000,000  unlimited*
--   EMAILS                 FLOW/mo   500       50,000     200,000     unlimited*
--   USERS                  STOCK     2         15         50          unlimited*
--
-- * CUSTOM = enterprise: all modules/channels on and quotas UNLIMITED (LimitValue NULL) by
--   default; real per-company values are set via billing.SubscriptionOverrides, not here.
--
-- PLACEHOLDER VALUES (editable later via the Plan Catalog screen; MVP only needs the
--   module->tier SHAPE right, per the DQ4 doc's MVP note):
--     - Price / Currency / BillingCycle are illustrative (INR; FREE monthly, paid annual).
--     - PLAN_50K / PLAN_100K EMAILS/mo limits (50,000 / 200,000) are not pinned by DQ4 —
--       the map says "plan limit" with no number. Adjust as needed.
--
-- FeatureCode vocabulary NOTE: FEATURE:* / CHANNEL:* are FREE STRINGS with NO FK to
--   auth.Modules (auth modules are coarse — CRM/SETTING/... with Guid keys). The P-03
--   capability-∩-entitlement step will need an auth ModuleCode -> FeatureCode mapping layer.
--
-- IDEMPOTENT: every INSERT is guarded (NOT EXISTS on the natural key). Re-running is a no-op.
-- SAFE: additive only. No DROP / UPDATE / schema change.
-- PREREQUISITE: run AFTER the P-02 migration (billing schema + tables) is applied, AND after
--   com."Currencies" is seeded (Currency is an FK now — INR must exist to resolve "CurrencyId").
-- ORDER: run this BEFORE billing-backfill-subscriptions.sql (that script needs CUSTOM to exist).
-- =====================================================================================

BEGIN;

-- ── 1. Plans ────────────────────────────────────────────────────────────────────────
-- Currency identity is an FK (billing."Plans"."CurrencyId" -> com."Currencies"): the base/anchor
-- currency code below is resolved to its CurrencyId via a JOIN. Requires com."Currencies" to be
-- seeded (INR must exist); if a currency code is missing, its plan row is skipped by the JOIN.
INSERT INTO billing."Plans"
  ("PlanCode","PlanName","Description","Price","CurrencyId","BillingCycle","IsCustom","SortOrder",
   "CreatedDate","IsActive","IsDeleted")
SELECT v."PlanCode", v."PlanName", v."Description", v."Price", cur."CurrencyId", v."BillingCycle",
       v."IsCustom", v."SortOrder", now(), true, false
FROM (VALUES
  ('FREE',      'Free',       'Trial / tiny NGO — Contacts, Donation and a capped Email channel.',      0::numeric,      'INR', 'Monthly', false, 1),
  ('PLAN_50K',  'Growth',     'Growing NGO — adds Event, Volunteer and Membership plus full Email.',     50000::numeric,  'INR', 'Annual',  false, 2),
  ('PLAN_100K', 'Full Suite', 'Full suite — everything, including Case, Grant and premium channels.',    100000::numeric, 'INR', 'Annual',  false, 3),
  ('CUSTOM',    'Enterprise', 'Enterprise — all modules on; real limits set per-company via override.',  0::numeric,      'INR', 'Annual',  true,  4)
) AS v("PlanCode","PlanName","Description","Price","CurrencyCode","BillingCycle","IsCustom","SortOrder")
JOIN com."Currencies" cur ON cur."CurrencyCode" = v."CurrencyCode" AND COALESCE(cur."IsDeleted", false) = false
WHERE NOT EXISTS (
  SELECT 1 FROM billing."Plans" p WHERE p."PlanCode" = v."PlanCode"
);

-- ── 2. PlanEntitlements (FEATURE:* / CHANNEL:* booleans) ───────────────────────────────
INSERT INTO billing."PlanEntitlements"
  ("PlanId","FeatureCode","IsEnabled","CreatedDate","IsActive","IsDeleted")
SELECT p."PlanId", v."FeatureCode", v."IsEnabled", now(), true, false
FROM billing."Plans" p
JOIN (VALUES
  -- FREE
  ('FREE','FEATURE:CONTACTS',   true),
  ('FREE','FEATURE:DONATION',   true),
  ('FREE','FEATURE:EVENT',      false),
  ('FREE','FEATURE:VOLUNTEER',  false),
  ('FREE','FEATURE:MEMBERSHIP', false),
  ('FREE','FEATURE:CASE',       false),
  ('FREE','FEATURE:GRANT',      false),
  ('FREE','CHANNEL:EMAIL',     true),
  ('FREE','CHANNEL:WHATSAPP',  false),
  ('FREE','CHANNEL:SMS',       false),
  -- PLAN_50K
  ('PLAN_50K','FEATURE:CONTACTS',   true),
  ('PLAN_50K','FEATURE:DONATION',   true),
  ('PLAN_50K','FEATURE:EVENT',      true),
  ('PLAN_50K','FEATURE:VOLUNTEER',  true),
  ('PLAN_50K','FEATURE:MEMBERSHIP', true),
  ('PLAN_50K','FEATURE:CASE',       false),
  ('PLAN_50K','FEATURE:GRANT',      false),
  ('PLAN_50K','CHANNEL:EMAIL',     true),
  ('PLAN_50K','CHANNEL:WHATSAPP',  false),
  ('PLAN_50K','CHANNEL:SMS',       false),
  -- PLAN_100K
  ('PLAN_100K','FEATURE:CONTACTS',   true),
  ('PLAN_100K','FEATURE:DONATION',   true),
  ('PLAN_100K','FEATURE:EVENT',      true),
  ('PLAN_100K','FEATURE:VOLUNTEER',  true),
  ('PLAN_100K','FEATURE:MEMBERSHIP', true),
  ('PLAN_100K','FEATURE:CASE',       true),
  ('PLAN_100K','FEATURE:GRANT',      true),
  ('PLAN_100K','CHANNEL:EMAIL',     true),
  ('PLAN_100K','CHANNEL:WHATSAPP',  true),
  ('PLAN_100K','CHANNEL:SMS',       true),
  -- CUSTOM (all on by default)
  ('CUSTOM','FEATURE:CONTACTS',   true),
  ('CUSTOM','FEATURE:DONATION',   true),
  ('CUSTOM','FEATURE:EVENT',      true),
  ('CUSTOM','FEATURE:VOLUNTEER',  true),
  ('CUSTOM','FEATURE:MEMBERSHIP', true),
  ('CUSTOM','FEATURE:CASE',       true),
  ('CUSTOM','FEATURE:GRANT',      true),
  ('CUSTOM','CHANNEL:EMAIL',     true),
  ('CUSTOM','CHANNEL:WHATSAPP',  true),
  ('CUSTOM','CHANNEL:SMS',       true)
) AS v("PlanCode","FeatureCode","IsEnabled") ON v."PlanCode" = p."PlanCode"
WHERE NOT EXISTS (
  SELECT 1 FROM billing."PlanEntitlements" pe
  WHERE pe."PlanId" = p."PlanId" AND pe."FeatureCode" = v."FeatureCode"
);

-- ── 3. PlanQuotas (STOCK counts + FLOW/mo rates; NULL LimitValue = unlimited) ─────────
INSERT INTO billing."PlanQuotas"
  ("PlanId","MeterCode","MeterType","LimitValue","Period","CreatedDate","IsActive","IsDeleted")
SELECT p."PlanId", v."MeterCode", v."MeterType", v."LimitValue", v."Period", now(), true, false
FROM billing."Plans" p
JOIN (VALUES
  -- FREE
  ('FREE','CONTACTS',  'STOCK', 2000::bigint,     NULL::varchar),
  ('FREE','DONATIONS', 'STOCK', 25000::bigint,    NULL::varchar),
  ('FREE','EMAILS',    'FLOW',  500::bigint,       'MONTH'),
  ('FREE','USERS',     'STOCK', 2::bigint,         NULL::varchar),
  -- PLAN_50K
  ('PLAN_50K','CONTACTS',  'STOCK', 500000::bigint,   NULL::varchar),
  ('PLAN_50K','DONATIONS', 'STOCK', 5000000::bigint,  NULL::varchar),
  ('PLAN_50K','EMAILS',    'FLOW',  50000::bigint,     'MONTH'),
  ('PLAN_50K','USERS',     'STOCK', 15::bigint,        NULL::varchar),
  -- PLAN_100K
  ('PLAN_100K','CONTACTS',  'STOCK', 1000000::bigint,  NULL::varchar),
  ('PLAN_100K','DONATIONS', 'STOCK', 10000000::bigint, NULL::varchar),
  ('PLAN_100K','EMAILS',    'FLOW',  200000::bigint,    'MONTH'),
  ('PLAN_100K','USERS',     'STOCK', 50::bigint,        NULL::varchar),
  -- CUSTOM (unlimited by default — NULL LimitValue; real values via SubscriptionOverride)
  ('CUSTOM','CONTACTS',  'STOCK', NULL::bigint, NULL::varchar),
  ('CUSTOM','DONATIONS', 'STOCK', NULL::bigint, NULL::varchar),
  ('CUSTOM','EMAILS',    'FLOW',  NULL::bigint, 'MONTH'),
  ('CUSTOM','USERS',     'STOCK', NULL::bigint, NULL::varchar)
) AS v("PlanCode","MeterCode","MeterType","LimitValue","Period") ON v."PlanCode" = p."PlanCode"
WHERE NOT EXISTS (
  SELECT 1 FROM billing."PlanQuotas" pq
  WHERE pq."PlanId" = p."PlanId" AND pq."MeterCode" = v."MeterCode"
);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--   SELECT "PlanCode","PlanName","Price","IsCustom","SortOrder" FROM billing."Plans" ORDER BY "SortOrder";
--     -> expect 4 rows: FREE, PLAN_50K, PLAN_100K, CUSTOM
--   SELECT p."PlanCode", count(*) FROM billing."PlanEntitlements" e
--     JOIN billing."Plans" p ON p."PlanId"=e."PlanId" GROUP BY p."PlanCode";  -> 10 each
--   SELECT p."PlanCode", count(*) FROM billing."PlanQuotas" q
--     JOIN billing."Plans" p ON p."PlanId"=q."PlanId" GROUP BY p."PlanCode";  -> 4 each
-- =====================================================================================
