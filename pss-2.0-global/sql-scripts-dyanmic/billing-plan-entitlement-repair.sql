-- =====================================================================================
--  billing-plan-entitlement-repair.sql
--
--  Restores billing."PlanEntitlements" to the 17 x 4 matrix.
--
--  WHY THIS FILE EXISTS
--    The entitlement block in billing-feature-menu-map-complete-seed.sql guards its insert
--    with NOT EXISTS on (PlanId, FeatureCode) WITHOUT filtering IsDeleted. So once a row
--    has been soft-deleted, re-running that seed can never bring it back - the guard sees
--    the dead row and skips.
--
--    That is what happened after the MODULE: -> FEATURE: rename. The entitlements had been
--    written under the old MODULE: codes; billing-feature-catalog-cleanup.sql then retired
--    every code outside the curated 17, which those MODULE: rows were. The three CHANNEL:
--    codes were never renamed, so only they survived - which is exactly what the plan
--    matrix shows: every CHANNEL row ticked, every FEATURE row blank.
--
--  WHAT IT DOES
--    Revives-or-inserts each (plan, feature) cell and sets IsEnabled to the value below.
--    Matching ignores IsDeleted, so a retired row is revived instead of collided with.
--    Any leftover MODULE: row is left retired - it is not part of the vocabulary.
--
--  This file is the source of truth for the matrix. Edit the values here, re-run, done.
--
--  Run the whole file, once. It is idempotent.
--
--  AFTER THIS FILE, RE-RUN plan-role-baseline-generate-from-plan-features.sql.
--  The baseline was generated against the broken entitlements, so it currently grants only
--  the ungated menus plus email. The generator will add the missing cells on the next run.
-- =====================================================================================

BEGIN;

DROP TABLE IF EXISTS tmp_entitlement_want;

CREATE TEMP TABLE tmp_entitlement_want (
    plan_code    text,
    feature_code text,
    enabled      boolean,
    PRIMARY KEY (plan_code, feature_code)
);

INSERT INTO tmp_entitlement_want (plan_code, feature_code, enabled) VALUES
  ('FREE','FEATURE:CONTACTS',true),          ('FREE','FEATURE:DONATION',true),
  ('FREE','FEATURE:EVENT',false),            ('FREE','FEATURE:VOLUNTEER',false),
  ('FREE','FEATURE:MEMBERSHIP',false),       ('FREE','FEATURE:CASE',false),
  ('FREE','FEATURE:GRANT',false),            ('FREE','FEATURE:FIELDCOLLECTION',false),
  ('FREE','FEATURE:AUTOMATION',false),       ('FREE','FEATURE:PRAYERREQUEST',false),
  ('FREE','FEATURE:INTELLIGENCE',false),     ('FREE','FEATURE:ADVANCEDREPORTING',false),
  ('FREE','FEATURE:POWERBI',false),          ('FREE','FEATURE:INTEGRATION',false),
  ('FREE','CHANNEL:EMAIL',true),             ('FREE','CHANNEL:WHATSAPP',false),
  ('FREE','CHANNEL:SMS',false),

  ('PLAN_50K','FEATURE:CONTACTS',true),      ('PLAN_50K','FEATURE:DONATION',true),
  ('PLAN_50K','FEATURE:EVENT',true),         ('PLAN_50K','FEATURE:VOLUNTEER',true),
  ('PLAN_50K','FEATURE:MEMBERSHIP',true),    ('PLAN_50K','FEATURE:CASE',false),
  ('PLAN_50K','FEATURE:GRANT',false),        ('PLAN_50K','FEATURE:FIELDCOLLECTION',true),
  ('PLAN_50K','FEATURE:AUTOMATION',false),   ('PLAN_50K','FEATURE:PRAYERREQUEST',false),
  ('PLAN_50K','FEATURE:INTELLIGENCE',false), ('PLAN_50K','FEATURE:ADVANCEDREPORTING',false),
  ('PLAN_50K','FEATURE:POWERBI',false),      ('PLAN_50K','FEATURE:INTEGRATION',false),
  ('PLAN_50K','CHANNEL:EMAIL',true),         ('PLAN_50K','CHANNEL:WHATSAPP',false),
  ('PLAN_50K','CHANNEL:SMS',false),

  ('PLAN_100K','FEATURE:CONTACTS',true),     ('PLAN_100K','FEATURE:DONATION',true),
  ('PLAN_100K','FEATURE:EVENT',true),        ('PLAN_100K','FEATURE:VOLUNTEER',true),
  ('PLAN_100K','FEATURE:MEMBERSHIP',true),   ('PLAN_100K','FEATURE:CASE',true),
  ('PLAN_100K','FEATURE:GRANT',true),        ('PLAN_100K','FEATURE:FIELDCOLLECTION',true),
  ('PLAN_100K','FEATURE:AUTOMATION',true),   ('PLAN_100K','FEATURE:PRAYERREQUEST',true),
  ('PLAN_100K','FEATURE:INTELLIGENCE',true), ('PLAN_100K','FEATURE:ADVANCEDREPORTING',true),
  ('PLAN_100K','FEATURE:POWERBI',false),     ('PLAN_100K','FEATURE:INTEGRATION',true),
  ('PLAN_100K','CHANNEL:EMAIL',true),        ('PLAN_100K','CHANNEL:WHATSAPP',true),
  ('PLAN_100K','CHANNEL:SMS',true),

  ('CUSTOM','FEATURE:CONTACTS',true),        ('CUSTOM','FEATURE:DONATION',true),
  ('CUSTOM','FEATURE:EVENT',true),           ('CUSTOM','FEATURE:VOLUNTEER',true),
  ('CUSTOM','FEATURE:MEMBERSHIP',true),      ('CUSTOM','FEATURE:CASE',true),
  ('CUSTOM','FEATURE:GRANT',true),           ('CUSTOM','FEATURE:FIELDCOLLECTION',true),
  ('CUSTOM','FEATURE:AUTOMATION',true),      ('CUSTOM','FEATURE:PRAYERREQUEST',true),
  ('CUSTOM','FEATURE:INTELLIGENCE',true),    ('CUSTOM','FEATURE:ADVANCEDREPORTING',true),
  ('CUSTOM','FEATURE:POWERBI',true),         ('CUSTOM','FEATURE:INTEGRATION',true),
  ('CUSTOM','CHANNEL:EMAIL',true),           ('CUSTOM','CHANNEL:WHATSAPP',true),
  ('CUSTOM','CHANNEL:SMS',true);

DO $repair$
DECLARE
    v_want      record;
    v_plan_id   int;
    v_revived   int := 0;
    v_updated   int := 0;
    v_inserted  int := 0;
    v_no_plan   int := 0;
    v_no_feat   int := 0;
BEGIN

FOR v_want IN SELECT plan_code, feature_code, enabled
              FROM   tmp_entitlement_want
              ORDER  BY plan_code, feature_code
LOOP
    -- The plan must exist.
    v_plan_id := NULL;
    SELECT p."PlanId" INTO v_plan_id
    FROM   billing."Plans" p
    WHERE  upper(p."PlanCode") = upper(v_want.plan_code)
      AND  p."IsDeleted" IS DISTINCT FROM true;

    IF v_plan_id IS NULL THEN
        RAISE NOTICE 'NO SUCH PLAN: %', v_want.plan_code;
        v_no_plan := v_no_plan + 1;
        CONTINUE;
    END IF;

    -- The feature must be live in the catalogue, or the matrix has nothing to draw.
    PERFORM 1 FROM billing."Features" f
    WHERE  upper(f."FeatureCode") = upper(v_want.feature_code)
      AND  f."IsDeleted" IS DISTINCT FROM true;

    IF NOT FOUND THEN
        RAISE NOTICE 'NO SUCH FEATURE: % - run billing-feature-menu-map-complete-seed.sql first',
                     v_want.feature_code;
        v_no_feat := v_no_feat + 1;
        CONTINUE;
    END IF;

    -- Revive a retired row rather than inserting next to it.
    UPDATE billing."PlanEntitlements"
    SET    "IsEnabled"    = v_want.enabled,
           "IsActive"     = true,
           "IsDeleted"    = false,
           "ModifiedDate" = now()
    WHERE  "PlanId" = v_plan_id
      AND  upper("FeatureCode") = upper(v_want.feature_code)
      AND  "IsDeleted" = true;

    IF FOUND THEN
        v_revived := v_revived + 1;
        CONTINUE;
    END IF;

    -- Live row: correct it only if it actually differs.
    UPDATE billing."PlanEntitlements"
    SET    "IsEnabled"    = v_want.enabled,
           "IsActive"     = true,
           "ModifiedDate" = now()
    WHERE  "PlanId" = v_plan_id
      AND  upper("FeatureCode") = upper(v_want.feature_code)
      AND  "IsDeleted" IS DISTINCT FROM true
      AND  ("IsEnabled" IS DISTINCT FROM v_want.enabled
            OR "IsActive" IS DISTINCT FROM true);

    IF FOUND THEN
        v_updated := v_updated + 1;
        CONTINUE;
    END IF;

    -- Nothing there at all?
    PERFORM 1 FROM billing."PlanEntitlements"
    WHERE  "PlanId" = v_plan_id
      AND  upper("FeatureCode") = upper(v_want.feature_code);

    IF NOT FOUND THEN
        INSERT INTO billing."PlanEntitlements"
               ("PlanId", "FeatureCode", "IsEnabled", "IsActive", "IsDeleted", "CreatedDate")
        VALUES (v_plan_id, upper(v_want.feature_code), v_want.enabled, true, false, now());
        v_inserted := v_inserted + 1;
    END IF;
END LOOP;

RAISE NOTICE 'revived: %  corrected: %  inserted: %  missing plans: %  missing features: %',
             v_revived, v_updated, v_inserted, v_no_plan, v_no_feat;

END
$repair$;

COMMIT;

-- Result 1. Must be 17 live rows per plan. "enabled" is what the matrix ticks.
SELECT p."PlanCode",
       count(e.*)                                        AS entitlements,
       count(*) FILTER (WHERE e."IsEnabled" = true)       AS enabled
FROM   billing."Plans" p
LEFT   JOIN billing."PlanEntitlements" e
       ON e."PlanId" = p."PlanId" AND e."IsDeleted" IS DISTINCT FROM true
WHERE  p."IsDeleted" IS DISTINCT FROM true
GROUP  BY p."PlanCode"
ORDER  BY p."PlanCode";

-- Result 2. The full matrix, exactly as the screen should render it.
SELECT p."PlanCode", e."FeatureCode", e."IsEnabled"
FROM   billing."PlanEntitlements" e
JOIN   billing."Plans" p ON p."PlanId" = e."PlanId"
WHERE  e."IsDeleted" IS DISTINCT FROM true
  AND  p."IsDeleted" IS DISTINCT FROM true
ORDER  BY p."PlanCode", e."FeatureCode";

-- Result 3. Entitlement codes that are NOT in the curated vocabulary. Expect none.
-- Anything here is a leftover from before the FEATURE: rename and should stay retired.
SELECT DISTINCT e."FeatureCode" AS stale_live_code
FROM   billing."PlanEntitlements" e
WHERE  e."IsDeleted" IS DISTINCT FROM true
  AND  NOT EXISTS (SELECT 1 FROM billing."Features" f
                   WHERE upper(f."FeatureCode") = upper(e."FeatureCode")
                     AND f."IsDeleted" IS DISTINCT FROM true);

DROP TABLE tmp_entitlement_want;
