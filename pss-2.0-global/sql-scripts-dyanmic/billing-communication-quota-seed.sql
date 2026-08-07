-- =====================================================================================
-- P-25 §③.4 — Communication metering quota seed (billing."PlanQuotas")
-- -------------------------------------------------------------------------------------
-- Ships a PlanQuota row for EVERY plan × EVERY communication meter, in the same release as
-- the three new meter codes.
--
-- WHY THAT MATTERS: EntitlementService.GetLimitAsync resolves an ABSENT PlanQuota row to 0,
-- not to unlimited. A new meter code without a row on some plan is a silent hard block for
-- every tenant on that plan the moment the code deploys. There is no "default" to fall back
-- on — this file IS the default.
--
--   Meter                     Type    FREE     PLAN_50K   PLAN_100K   CUSTOM
--   EMAILS                    FLOW    1,000    50,000     100,000     NULL (unlimited)
--   EMAILS_PLATFORM           FLOW    1,000    50,000     100,000     NULL (unlimited)
--   SMS_SEGMENTS              FLOW    0        0          0           0
--   WHATSAPP_CONVERSATIONS    FLOW    0        0          0           0
--
-- EMAILS is the VALUE meter — every email the tenant sends, whether through their own
-- provider (BYO) or ours. EMAILS_PLATFORM is the COST meter — only the subset that goes out
-- on our infrastructure and that we pay for. A platform-sent email increments BOTH, never
-- one instead of the other, so EMAILS_PLATFORM <= EMAILS always.
--
-- SMS_SEGMENTS and WHATSAPP_CONVERSATIONS ship at 0 on every plan on purpose: declared and
-- seeded now, ENFORCED LATER. Nothing in this release reads them. Zero is honest — SMS and
-- WhatsApp are BYO-only today. Seeding them now means the later enforcement release is code
-- only, with no second seed run against live tenants.
--
-- ⚠️ THE NUMBERS ARE AN ASSUMPTION, NOT A RATIFIED DECISION (strategy doc D1 / prompt §⑨ Q1).
--    Add-on packs are out of scope, so a tenant who runs out has exactly one route: upgrade,
--    and pay more every month thereafter. Size for a PEAK month (Diwali, Christmas, a disaster
--    appeal), not an average one. If different numbers are ratified, only this file changes —
--    no code changes.
--
-- ⚠️ 'MONTH', not 'BILLING_PERIOD'. The build prompt asked for Period = 'BILLING_PERIOD'; that
--    value cannot be stored. PlanQuotaConfiguration declares Period HasMaxLength(10) (the
--    string is 14 characters) AND SavePlanQuotas.cs validates every FLOW period against
--    MeterPeriods.All, whose only member is 'MONTH'. Nothing is lost: Period is a LABEL, and
--    the anniversary semantics live in the enforcement layer — UsageMeterService
--    .GetCurrentPeriodStartAsync reads the tenant's live Subscription.CurrentPeriodStart, so
--    the window already is the billing anniversary regardless of what this column says.
--
-- ⚠️ EMAILS ROWS MAY ALREADY EXIST. billing-plan-catalog-seed.sql seeded EMAILS at
--    500 / 50,000 / 200,000 / NULL. This script is guarded by NOT EXISTS on (PlanId,MeterCode),
--    so on an already-seeded database the EMAILS rows are LEFT ALONE and only the three new
--    meters are inserted. That is deliberate: silently rewriting a live tenant's email
--    allowance — down from 200,000 to 100,000 on PLAN_100K — is not a seed's decision to make.
--    If the §③.4 numbers are ratified, run the OPTIONAL RE-ALIGNMENT block at the bottom
--    explicitly, after telling anyone on PLAN_100K.
--
-- IDEMPOTENT: guarded by NOT EXISTS on the natural key (PlanId, MeterCode) — the same key the
--   unique index enforces. Re-running is a no-op.
-- SAFE: additive only. No DROP / UPDATE / schema change above the COMMIT.
-- PREREQUISITE: billing-plan-catalog-seed.sql (the four Plans must exist).
-- =====================================================================================

BEGIN;

INSERT INTO billing."PlanQuotas"
  ("PlanId","MeterCode","MeterType","LimitValue","Period","CreatedDate","IsActive","IsDeleted")
SELECT p."PlanId", v."MeterCode", v."MeterType", v."LimitValue", v."Period", now(), true, false
FROM billing."Plans" p
JOIN (VALUES
  -- FREE
  ('FREE','EMAILS',                 'FLOW', 1000::bigint,   'MONTH'),
  ('FREE','EMAILS_PLATFORM',        'FLOW', 1000::bigint,   'MONTH'),
  ('FREE','SMS_SEGMENTS',           'FLOW', 0::bigint,      'MONTH'),
  ('FREE','WHATSAPP_CONVERSATIONS', 'FLOW', 0::bigint,      'MONTH'),
  -- PLAN_50K
  ('PLAN_50K','EMAILS',                 'FLOW', 50000::bigint, 'MONTH'),
  ('PLAN_50K','EMAILS_PLATFORM',        'FLOW', 50000::bigint, 'MONTH'),
  ('PLAN_50K','SMS_SEGMENTS',           'FLOW', 0::bigint,     'MONTH'),
  ('PLAN_50K','WHATSAPP_CONVERSATIONS', 'FLOW', 0::bigint,     'MONTH'),
  -- PLAN_100K
  ('PLAN_100K','EMAILS',                 'FLOW', 100000::bigint, 'MONTH'),
  ('PLAN_100K','EMAILS_PLATFORM',        'FLOW', 100000::bigint, 'MONTH'),
  ('PLAN_100K','SMS_SEGMENTS',           'FLOW', 0::bigint,      'MONTH'),
  ('PLAN_100K','WHATSAPP_CONVERSATIONS', 'FLOW', 0::bigint,      'MONTH'),
  -- CUSTOM — email unlimited (NULL); real per-company values via billing.SubscriptionOverrides.
  -- SMS/WhatsApp stay 0 even here: unenforced meters must not read as "sold".
  ('CUSTOM','EMAILS',                 'FLOW', NULL::bigint, 'MONTH'),
  ('CUSTOM','EMAILS_PLATFORM',        'FLOW', NULL::bigint, 'MONTH'),
  ('CUSTOM','SMS_SEGMENTS',           'FLOW', 0::bigint,    'MONTH'),
  ('CUSTOM','WHATSAPP_CONVERSATIONS', 'FLOW', 0::bigint,    'MONTH')
) AS v("PlanCode","MeterCode","MeterType","LimitValue","Period") ON v."PlanCode" = p."PlanCode"
WHERE COALESCE(p."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM billing."PlanQuotas" pq
    WHERE pq."PlanId" = p."PlanId" AND pq."MeterCode" = v."MeterCode"
  );

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--
-- 1. Every plan × every communication meter is present. THIS IS THE ACCEPTANCE CHECK —
--    a LEFT JOIN that returns any row means some tenant is about to be hard-blocked.
--
--   SELECT p."PlanCode", m."MeterCode"
--   FROM billing."Plans" p
--   CROSS JOIN (VALUES ('EMAILS'),('EMAILS_PLATFORM'),('SMS_SEGMENTS'),('WHATSAPP_CONVERSATIONS'))
--        AS m("MeterCode")
--   LEFT JOIN billing."PlanQuotas" q
--          ON q."PlanId" = p."PlanId" AND q."MeterCode" = m."MeterCode"
--         AND COALESCE(q."IsDeleted", false) = false
--   WHERE COALESCE(p."IsDeleted", false) = false AND q."PlanQuotaId" IS NULL;
--     -> expect ZERO rows.
--
-- 2. The values that actually landed (EMAILS may show the pre-existing catalog numbers):
--
--   SELECT p."PlanCode", q."MeterCode", q."LimitValue", q."Period"
--   FROM billing."PlanQuotas" q JOIN billing."Plans" p ON p."PlanId" = q."PlanId"
--   WHERE q."MeterCode" IN ('EMAILS','EMAILS_PLATFORM','SMS_SEGMENTS','WHATSAPP_CONVERSATIONS')
--   ORDER BY p."SortOrder", q."MeterCode";
-- =====================================================================================

-- =====================================================================================
-- OPTIONAL RE-ALIGNMENT — DO NOT RUN BLIND.
-- -------------------------------------------------------------------------------------
-- Only if the §③.4 EMAILS numbers are ratified AND you accept that PLAN_100K tenants drop
-- from 200,000 to 100,000 and FREE tenants rise from 500 to 1,000. Uncomment and run
-- deliberately; this is an UPDATE against live allowances, not a seed.
--
-- BEGIN;
-- UPDATE billing."PlanQuotas" q
--    SET "LimitValue" = v."LimitValue", "ModifiedDate" = now()
--   FROM (VALUES
--     ('FREE',      1000::bigint),
--     ('PLAN_50K',  50000::bigint),
--     ('PLAN_100K', 100000::bigint)
--   ) AS v("PlanCode","LimitValue")
--   JOIN billing."Plans" p ON p."PlanCode" = v."PlanCode"
--  WHERE q."PlanId" = p."PlanId" AND q."MeterCode" = 'EMAILS';
-- COMMIT;
-- =====================================================================================
