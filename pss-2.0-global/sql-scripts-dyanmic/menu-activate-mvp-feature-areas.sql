-- ═════════════════════════════════════════════════════════════════════════════════════
--  menu-activate-mvp-feature-areas.sql
--
--  WHY THIS EXISTS
--  Eight whole feature areas are switched off in auth."Menus" (IsActive = false) even
--  though PLAN_100K and CUSTOM sell them:
--
--      Membership          Field collection    Intelligence / AI    Prayer requests
--      Automation          Certificates        SMS                  WhatsApp
--
--  plus a few stragglers inside areas that are otherwise live (PLEDGE, BULKDONATION,
--  RECONCILIATION, GRANTFORM, BENEFICIARYFORM, AMBASSADORDASHBOARD) and one parent that
--  is inactive while its own children are active (MATCHINGGIFT).
--
--  A menu that is inactive is skipped by plan-role-baseline-generate-from-plan-features.sql,
--  so those areas would produce ZERO baseline cells - a PLAN_100K tenant would be entitled
--  to Membership and still see nothing. This script switches them on so the entitlement,
--  the menu and the capability all line up.
--
--  RUN THIS **BEFORE** plan-role-baseline-generate-from-plan-features.sql.
--
--  WHAT IT DOES NOT TOUCH
--    - IsVisible / MenuType: every one of these rows is already IsVisible = true,
--      MenuType = 'Internal'. Only IsActive is wrong.
--    - Soft-deleted menus: never revived.
--    - Menus that are already active: left alone, so re-running is a no-op.
--    - PLATFORM menus: not in this list and never will be.
--
--  TWO SCREENS DELIBERATELY LEFT OFF THE LIST
--    VOLUNTEERFORM    MenuUrl 'crm/volunteer/registervolunteer' - that page does not exist
--                     in the frontend. Activating it would put a 404 in the menu. The live
--                     volunteer routes are volunteerlist / volunteerscheduling /
--                     volunteerhourtracking / volunteerconversion, all already active.
--    WHATSAPPMESSAGE  A root-level group with no MenuUrl and no children. Activating it
--                     adds an empty dead node next to CRM_WHATSAPP.
--    Every other menu in this list was checked against the frontend app router and has a
--    real page behind it.
--
--  SAFETY
--    Whole thing is one transaction. Result 1 tells you exactly what flipped, Result 2
--    warns you about any leaf that has no capability rows - such a leaf would still
--    generate zero baseline cells even after activation.
-- ═════════════════════════════════════════════════════════════════════════════════════

BEGIN;

DROP TABLE IF EXISTS tmp_menu_activate;

CREATE TEMP TABLE tmp_menu_activate (menu_code text PRIMARY KEY, area text);

INSERT INTO tmp_menu_activate (menu_code, area) VALUES
-- ── Membership ──────────────────────────────────────────────────────────────────────
  ('CRM_MEMBERSHIP',          'Membership'),
  ('MEMBERLIST',              'Membership'),
  ('MEMBERENROLLMENT',        'Membership'),
  ('MEMBERSHIPTIER',          'Membership'),
  ('MEMBERPORTAL',            'Membership'),
  ('MEMBERSHIPRENEWAL',       'Membership'),
  ('MEMBERSHIPTIERCONFIG',    'Membership'),

-- ── Field collection ────────────────────────────────────────────────────────────────
  ('CRM_FIELDCOLLECTION',     'Field collection'),
  ('AMBASSADORS',             'Field collection'),
  ('COLLECTIONLIST',          'Field collection'),
  ('RECEIPTBOOK',             'Field collection'),
  ('AMBASSADORPERFORMANCE',   'Field collection'),
  ('AMBASSADORDASHBOARD',     'Field collection'),

-- ── Intelligence / AI ───────────────────────────────────────────────────────────────
  ('CRM_INTELLIGENCE',        'Intelligence'),
  ('ENGAGEMENTSCORING',       'Intelligence'),
  ('CHURNPREDICTION',         'Intelligence'),
  ('ACTIONBOARD',             'Intelligence'),
  ('AIDRAFT',                 'Intelligence'),
  ('AIREPORTING',             'Intelligence'),
  ('PREDICTIVEANALYTICS',     'Intelligence'),

-- ── Prayer requests ─────────────────────────────────────────────────────────────────
  ('CRM_PRAYERREQUEST',       'Prayer requests'),
  ('PRAYERREQUESTS',          'Prayer requests'),
  ('PRAYERREQUESTPAGE',       'Prayer requests'),

-- ── Automation ──────────────────────────────────────────────────────────────────────
  ('CRM_AUTOMATION',          'Automation'),
  ('AUTOMATIONWORKFLOW',      'Automation'),

-- ── Certificates ────────────────────────────────────────────────────────────────────
  ('CRM_CERTIFICATE',         'Certificates'),
  ('CERTIFICATETEMPLATE',     'Certificates'),
  ('CERTIFICATEOPERATIONS',   'Certificates'),

-- ── SMS ─────────────────────────────────────────────────────────────────────────────
  ('CRM_SMS',                 'SMS'),
  ('SMSTEMPLATE',             'SMS'),
  ('SMSCAMPAIGN',             'SMS'),

-- ── WhatsApp ────────────────────────────────────────────────────────────────────────
  ('CRM_WHATSAPP',            'WhatsApp'),
  ('WHATSAPPTEMPLATE',        'WhatsApp'),
  ('WHATSAPPCAMPAIGN',        'WhatsApp'),
  ('WHATSAPPCONVERSATION',    'WhatsApp'),

-- ── Stragglers inside areas that are otherwise already live ─────────────────────────
  ('MATCHINGGIFT',            'Donation - matching gift parent (its children are already active)'),
  ('PLEDGE',                  'Donation'),
  ('BULKDONATION',            'Donation'),
  ('RECONCILIATION',          'Donation'),
  ('GRANTFORM',               'Grant'),
  ('BENEFICIARYFORM',         'Case management');

-- ═════════════════════════════════════════════════════════════════════════════════════
--  Activate. Soft-deleted rows are never revived; already-active rows are untouched.
-- ═════════════════════════════════════════════════════════════════════════════════════

UPDATE auth."Menus" m
SET    "IsActive"     = true,
       "IsVisible"    = true,
       "ModifiedDate" = now()
FROM   tmp_menu_activate a
WHERE  upper(m."MenuCode") = upper(a.menu_code)
  AND  m."IsDeleted" IS DISTINCT FROM true
  AND  (m."IsActive" IS DISTINCT FROM true OR m."IsVisible" IS DISTINCT FROM true);

COMMIT;

-- ═════════════════════════════════════════════════════════════════════════════════════
--  RESULT 1 - one row per listed code, so you can see what the database actually holds.
--  status: ACTIVE = on and usable   DELETED = soft-deleted, not revived on purpose
--          NOT-FOUND = the code is not in auth."Menus" at all (list is wrong)
-- ═════════════════════════════════════════════════════════════════════════════════════

SELECT a.area,
       a.menu_code,
       CASE WHEN m."MenuId" IS NULL              THEN 'NOT-FOUND'
            WHEN m."IsDeleted" IS TRUE           THEN 'DELETED'
            WHEN m."IsActive"  IS DISTINCT FROM true THEN 'STILL-INACTIVE'
            ELSE 'ACTIVE'
       END                        AS status,
       m."IsLeastMenu"            AS is_leaf,
       m."MenuUrl"                AS menu_url
FROM   tmp_menu_activate a
LEFT   JOIN auth."Menus" m ON upper(m."MenuCode") = upper(a.menu_code)
ORDER  BY a.area, a.menu_code;

-- ═════════════════════════════════════════════════════════════════════════════════════
--  RESULT 2 - WARNING LIST. Leaf menus that are now active but own NO live capability
--  rows. The baseline generator will still write zero cells for these, so the screen
--  will be invisible to BUSINESSADMIN. If anything shows up here it needs a
--  MenuCapabilities seed before the generator is run.
--  Empty result = nothing to do.
-- ═════════════════════════════════════════════════════════════════════════════════════

SELECT a.area,
       a.menu_code,
       m."MenuUrl" AS menu_url
FROM   tmp_menu_activate a
JOIN   auth."Menus" m ON upper(m."MenuCode") = upper(a.menu_code)
WHERE  m."IsDeleted"    IS DISTINCT FROM true
  AND  m."IsActive"     IS DISTINCT FROM false
  AND  m."IsLeastMenu"  IS TRUE
  AND  NOT EXISTS (SELECT 1
                   FROM   auth."MenuCapabilities" mc
                   WHERE  mc."MenuId"    = m."MenuId"
                     AND  mc."IsDeleted" IS DISTINCT FROM true
                     AND  mc."IsActive"  IS DISTINCT FROM false)
ORDER  BY a.area, a.menu_code;
