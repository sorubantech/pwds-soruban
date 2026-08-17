-- =====================================================================================
-- Custom-field GOVERNANCE quota seed (billing."PlanQuotas")
-- -------------------------------------------------------------------------------------
-- Makes custom-field plan tiering ACTUALLY TAKE EFFECT.
--
-- The three-tier resolution (CustomFieldPolicyOptions -> billing.PlanQuotas ->
-- billing.SubscriptionOverrides) has been wired and working for a while, but no PlanQuota row
-- has ever declared either governance code, so tier 2 has never fired: every tenant on every
-- plan resolves to the SAME configured default. This file is the missing tier-2 data.
--
--   Meter                       Type     FREE   PLAN_50K   PLAN_100K   CUSTOM
--   CUSTOM_FIELDS               STOCK      10         50         150      300
--   CUSTOM_FIELDS_FILTERABLE    STOCK       2          5          12       25
--
-- WHY THESE ARE NOT LIKE THE OTHER QUOTA ROWS -------------------------------------------
-- Every other meter in billing.PlanQuotas is a CONSUMPTION meter that resolves through
-- EntitlementService.GetLimitAsync, which is FAIL-CLOSED: an absent row means 0, so a missing
-- row hard-blocks the tenant. These two do NOT resolve that way. CustomFieldPolicy.Merge
-- distinguishes ABSENT (-> fall back to the configured default in appsettings "CustomFields")
-- from PRESENT-AND-ZERO (-> the plan forbids it outright). That is why nothing was broken by
-- the absence of this file, and it is also why running it is a real change in behaviour:
-- after this runs, the plan is the authority, not appsettings.
--
-- Consequence worth stating out loud: FREE tenants drop from the configured default of 50/5 to
-- 10/2 the moment this commits. Run the AUDIT QUERY at the bottom FIRST.
--
-- ⚠️ THE NUMBERS ARE AN ASSUMPTION, NOT A RATIFIED DECISION. The user owns the final numbers;
--    everything above the COMMIT is data, and changing a number here changes nothing in code.
--    The rationale each one was chosen on:
--
--    CUSTOM_FIELDS
--      FREE      10   Enough to prove the feature is real (a couple of fields on contacts, a
--                     couple on donations) and not enough to build a production data model on
--                     a plan nobody pays for. Every definition is a key in a jsonb document
--                     carried on EVERY row of the owning table.
--      PLAN_50K  50   DELIBERATELY EQUAL TO THE CONFIGURED DEFAULT. The mid tier is where most
--                     paying tenants sit, so setting it to the current effective value means
--                     seed day is a no-op for them: nobody wakes up newly over their ceiling.
--                     If any tier is going to be argued about, it should not be this one.
--      PLAN_100K 150  3x the default. The plan a tenant upgrades to precisely because they hit
--                     50 needs materially more headroom than "a bit more", or the upgrade does
--                     not feel like it bought anything.
--      CUSTOM    300  Negotiated tier. A generous but real number; a specific enterprise that
--                     needs more gets a billing.SubscriptionOverrides row, which is exactly what
--                     that table is for. NOT unlimited — see below.
--
--    CUSTOM_FIELDS_FILTERABLE  (this is an INDEX BUDGET, not a feature count)
--      FREE       2   Two filter columns is a demonstration.
--      PLAN_50K   5   Again equal to the configured default, for the same no-op reason.
--      PLAN_100K 12   Roughly the point at which a grid's filter bar stops being usable anyway.
--      CUSTOM    25   The high-water mark anyone has actually asked for, with room.
--
-- ⚠️ NO TIER IS UNLIMITED (NULL) FOR CUSTOM_FIELDS_FILTERABLE. This is the one number in this
--    file that is a technical constraint rather than a commercial preference, so it should not
--    be softened without someone accepting the cost explicitly.
--
--    Every filterable custom field earns a B-tree EXPRESSION index over the jsonb extraction on
--    the owning table. On a tenant table holding ~500,000 rows, one such index is roughly
--    15-40 MB on disk (text keys, no dedup benefit), and it must be maintained on every INSERT
--    and on every UPDATE that touches the document — Postgres cannot do a HOT update when an
--    indexed expression changes, so each write turns into a new heap tuple plus an index entry
--    in EVERY one of these indexes. Twenty-five filterable fields is therefore ~0.4-1 GB of
--    index per large table, a 25-entry index maintenance cost on each write, correspondingly
--    more WAL, a slower VACUUM, and a planner with 25 more candidate paths to cost on every
--    query against that table. Bulk import is where this shows up first and worst: an import of
--    100K rows does 100K x N index inserts. That is a real, measurable ceiling on write
--    throughput, and it is the reason the number is small and explicit.
--
--    "Unlimited indexes" is not a product decision anyone means to make — it is the absence of
--    one. If an unlimited tier is genuinely wanted, the honest form is a large explicit number
--    (say 50) that someone has looked at, not NULL.
--
--    CUSTOM_FIELDS itself is not NULL on any tier either, for a weaker but still real reason:
--    the document grows on every row of the table and MaxDocumentKeys / MaxDocumentBytes are
--    separate guards that would then become the only ceiling. An explicit number is clearer.
--
-- MeterType STOCK, Period NULL — confirmed against PlanQuota's doc comment and against the
--   existing seeded rows: CONTACTS and USERS are the STOCK precedent ('STOCK', NULL::varchar).
--   These are live counts of a thing that exists right now, not a rate consumed per period, so
--   STOCK is correct. MeterCodes.TypeOf also returns STOCK for any unrecognised code, so
--   SavePlanQuotas' meter-kind consistency rule agrees with these rows without a code change.
--
-- These two codes are deliberately NOT in MeterCodes.All and this file does not change that.
--   That array is the CONSUMPTION universe that billing seeding, GetTenantUsage and every tenant
--   usage bar walk. A governance ceiling is not billed and has no usage to report.
--
-- IDEMPOTENT: guarded by NOT EXISTS on the natural key (PlanId, MeterCode) — the same key the
--   UNIQUE index enforces. Re-running is a no-op; it will never overwrite a number an operator
--   has since changed in the plan editor.
-- SAFE: additive only. No DROP / UPDATE / schema change above the COMMIT.
-- PREREQUISITE: billing-plan-catalog-seed.sql (the four Plans must exist).
-- NO MIGRATION REQUIRED: billing."PlanQuotas" already exists and gains no column. This is data.
-- =====================================================================================

BEGIN;

INSERT INTO billing."PlanQuotas"
  ("PlanId","MeterCode","MeterType","LimitValue","Period","CreatedDate","IsActive","IsDeleted")
SELECT p."PlanId", v."MeterCode", v."MeterType", v."LimitValue", v."Period", now(), true, false
FROM billing."Plans" p
JOIN (VALUES
  -- FREE
  ('FREE','CUSTOM_FIELDS',              'STOCK',  10::bigint, NULL::varchar),
  ('FREE','CUSTOM_FIELDS_FILTERABLE',   'STOCK',   2::bigint, NULL::varchar),
  -- PLAN_50K — equal to the configured defaults, so seed day changes nothing here
  ('PLAN_50K','CUSTOM_FIELDS',            'STOCK',  50::bigint, NULL::varchar),
  ('PLAN_50K','CUSTOM_FIELDS_FILTERABLE', 'STOCK',   5::bigint, NULL::varchar),
  -- PLAN_100K
  ('PLAN_100K','CUSTOM_FIELDS',            'STOCK', 150::bigint, NULL::varchar),
  ('PLAN_100K','CUSTOM_FIELDS_FILTERABLE', 'STOCK',  12::bigint, NULL::varchar),
  -- CUSTOM — negotiated tier. Explicit numbers, NOT NULL/unlimited; a specific enterprise that
  -- needs more gets a billing.SubscriptionOverrides row.
  ('CUSTOM','CUSTOM_FIELDS',            'STOCK', 300::bigint, NULL::varchar),
  ('CUSTOM','CUSTOM_FIELDS_FILTERABLE', 'STOCK',  25::bigint, NULL::varchar)
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
-- 1. Every plan carries both governance codes. Any row returned is a plan that silently keeps
--    falling back to the appsettings default — not broken, but not tiered either.
--
--   SELECT p."PlanCode", m."MeterCode"
--   FROM billing."Plans" p
--   CROSS JOIN (VALUES ('CUSTOM_FIELDS'),('CUSTOM_FIELDS_FILTERABLE')) AS m("MeterCode")
--   LEFT JOIN billing."PlanQuotas" q
--          ON q."PlanId" = p."PlanId" AND q."MeterCode" = m."MeterCode"
--         AND COALESCE(q."IsDeleted", false) = false
--   WHERE COALESCE(p."IsDeleted", false) = false AND q."PlanQuotaId" IS NULL;
--     -> expect ZERO rows.
--
-- 2. The values that actually landed, and that no STOCK row picked up a Period:
--
--   SELECT p."PlanCode", q."MeterCode", q."MeterType", q."LimitValue", q."Period"
--   FROM billing."PlanQuotas" q JOIN billing."Plans" p ON p."PlanId" = q."PlanId"
--   WHERE q."MeterCode" IN ('CUSTOM_FIELDS','CUSTOM_FIELDS_FILTERABLE')
--     AND COALESCE(q."IsDeleted", false) = false
--   ORDER BY p."SortOrder", q."MeterCode";
--     -> expect MeterType = 'STOCK' and Period IS NULL on every row.
-- =====================================================================================
