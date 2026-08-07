-- =====================================================================================
--  billing-feature-catalog-cleanup.sql
--
--  Removes the module-level feature rows that were back-filled from auth."Modules"
--  (FEATURE:CRM, FEATURE:ORGANIZATION, FEATURE:ACCESSCONTROL, FEATURE:GENERAL, FEATURE:SETTING,
--  FEATURE:REPORTAUDIT ...) together with their menu maps and plan entitlements.
--
--  Those codes are wrong at the grain: CRM is a MODULE, not something a tenant buys.
--  The sellable vocabulary is the 17 codes in billing-feature-menu-map-complete-seed.sql.
--  This file keeps exactly those 17 and retires everything else.
--
--  It does NOT match on a description marker. It matches on "not in the curated list",
--  so it also catches anything else that ever crept into the catalogue.
--
--  Soft delete, per house rule - IsDeleted = true, IsActive = false. Nothing is dropped.
--  The generator and the runtime both filter on IsDeleted, so a retired row is invisible.
--
--  RUN ORDER
--    1. billing-feature-menu-map-complete-seed.sql   (writes the 17 correct codes)
--    2. THIS FILE                                    (retires everything else)
--    3. plan-role-baseline-generate-from-plan-features.sql
--  Step 3 is not optional. Stale billing."PlanRoleBaselines" cells left behind by the bad
--  codes are cleaned up by the generator's own delete pass, not by this file.
-- =====================================================================================

BEGIN;

-- The curated vocabulary. Anything outside this list is retired below.
CREATE TEMP TABLE tmp_keep_feature_codes (code text PRIMARY KEY);
INSERT INTO tmp_keep_feature_codes (code) VALUES
  ('FEATURE:CONTACTS'), ('FEATURE:DONATION'), ('FEATURE:EVENT'), ('FEATURE:VOLUNTEER'),
  ('FEATURE:MEMBERSHIP'), ('FEATURE:CASE'), ('FEATURE:GRANT'), ('FEATURE:FIELDCOLLECTION'),
  ('FEATURE:AUTOMATION'), ('FEATURE:PRAYERREQUEST'), ('FEATURE:INTELLIGENCE'),
  ('FEATURE:ADVANCEDREPORTING'), ('FEATURE:POWERBI'), ('FEATURE:INTEGRATION'),
  ('CHANNEL:EMAIL'), ('CHANNEL:WHATSAPP'), ('CHANNEL:SMS');

-- Record what is about to go, so the result at the bottom can show it after the fact.
CREATE TEMP TABLE tmp_retired AS
SELECT DISTINCT upper(f."FeatureCode") AS code
FROM   billing."Features" f
WHERE  f."IsDeleted" IS DISTINCT FROM true
  AND  upper(f."FeatureCode") NOT IN (SELECT code FROM tmp_keep_feature_codes)
UNION
SELECT DISTINCT upper(m."FeatureCode")
FROM   billing."FeatureMenuMaps" m
WHERE  m."IsDeleted" IS DISTINCT FROM true
  AND  upper(m."FeatureCode") NOT IN (SELECT code FROM tmp_keep_feature_codes)
UNION
SELECT DISTINCT upper(e."FeatureCode")
FROM   billing."PlanEntitlements" e
WHERE  e."IsDeleted" IS DISTINCT FROM true
  AND  upper(e."FeatureCode") NOT IN (SELECT code FROM tmp_keep_feature_codes);

-- 1. Menu maps first. This is the row that actually hides screens - retiring it is what
--    un-gates the menus the bad codes were wrongly blocking.
UPDATE billing."FeatureMenuMaps"
SET    "IsDeleted" = true, "IsActive" = false, "ModifiedDate" = now()
WHERE  "IsDeleted" IS DISTINCT FROM true
  AND  upper("FeatureCode") NOT IN (SELECT code FROM tmp_keep_feature_codes);

-- 2. Plan entitlements for the retired codes.
UPDATE billing."PlanEntitlements"
SET    "IsDeleted" = true, "IsActive" = false, "ModifiedDate" = now()
WHERE  "IsDeleted" IS DISTINCT FROM true
  AND  upper("FeatureCode") NOT IN (SELECT code FROM tmp_keep_feature_codes);

-- 3. The feature rows themselves, last - so nothing points at a retired parent mid-way.
UPDATE billing."Features"
SET    "IsDeleted" = true, "IsActive" = false, "ModifiedDate" = now()
WHERE  "IsDeleted" IS DISTINCT FROM true
  AND  upper("FeatureCode") NOT IN (SELECT code FROM tmp_keep_feature_codes);

COMMIT;

-- Result.
--   "retired"  - one line per bad code that was just removed. Expect the module-level ones.
--   "features" - must be 17.
--   "map rows" - must be 44.
--   "entitlements <plan>" - must be 17 for every plan.
--   "MISSING"  - a curated code that is not in the catalogue at all. Expect none; if any
--                appear, billing-feature-menu-map-complete-seed.sql was not run first.
SELECT 'retired' AS what, code AS value FROM tmp_retired
UNION ALL
SELECT 'features', count(*)::text FROM billing."Features" WHERE "IsDeleted" IS DISTINCT FROM true
UNION ALL
SELECT 'map rows', count(*)::text FROM billing."FeatureMenuMaps" WHERE "IsDeleted" IS DISTINCT FROM true
UNION ALL
SELECT 'entitlements ' || p."PlanCode", count(e.*)::text
FROM   billing."Plans" p
LEFT   JOIN billing."PlanEntitlements" e
       ON e."PlanId" = p."PlanId" AND e."IsDeleted" IS DISTINCT FROM true
WHERE  p."IsDeleted" IS DISTINCT FROM true
GROUP  BY p."PlanCode"
UNION ALL
SELECT 'MISSING', k.code
FROM   tmp_keep_feature_codes k
WHERE  NOT EXISTS (SELECT 1 FROM billing."Features" f
                   WHERE upper(f."FeatureCode") = k.code AND f."IsDeleted" IS DISTINCT FROM true);

DROP TABLE tmp_retired;
DROP TABLE tmp_keep_feature_codes;
