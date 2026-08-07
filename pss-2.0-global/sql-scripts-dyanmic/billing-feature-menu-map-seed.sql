-- =====================================================================================
-- P-17 — Plan → menu gating catalog seed (billing.Features + billing.FeatureMenuMaps
--        + the four NEW billing.PlanEntitlements rows per plan)
-- -------------------------------------------------------------------------------------
-- Moves the plan → menu gating rules out of the hardcoded C# dictionary
-- (Base.Application/Interfaces/MenuFeatureMap.cs, now IMenuFeatureMap +
-- MenuFeatureMapService) into two ops-editable tables.
--
--   billing."Features"         — the feature vocabulary; one row per FeatureCode.
--                                SortOrder drives the ops plan-matrix ROW ORDER.
--   billing."FeatureMenuMaps"  — FeatureCode -> auth."Menus"."MenuCode". Group OR leaf.
--
-- READ THIS BEFORE EDITING THE MAP TABLE:
--
--   1. An UNMAPPED MenuCode is NEVER hidden. Absence of a row means "always visible".
--      Adding a row is what turns gating ON for a menu, so a typo'd MenuCode is inert,
--      never a lockout.
--   2. BILLING* menus must NEVER get a FeatureMenuMaps row. A tenant whose plan lapsed
--      has to be able to reach the pay screen. SETTING* / ACCESSCONTROL* likewise — the
--      filter hard-refuses to block those three prefixes whatever this table says.
--   3. Blocking is COSMETIC. It hides nav; it does not authorise. [RequiresFeature] on
--      the resolver is the security control.
--   4. There is deliberately NO FK from "MenuCode" to auth."Menus". It would cross
--      schemas, and a map row for a not-yet-seeded menu must sit dormant rather than
--      break the insert.
--
-- IDEMPOTENT: every INSERT is guarded (NOT EXISTS on the natural key). Re-running is a
--   no-op. SAFE: additive only. No DROP / UPDATE / DELETE / schema change.
-- PREREQUISITE: run AFTER the P-17 migration (Add_BillingFeatureCatalog) is applied AND
--   after billing-plan-catalog-seed.sql (the PlanEntitlements block joins billing."Plans").
-- =====================================================================================

BEGIN;

-- ── 1. Features — the vocabulary (14 codes: 11 FEATURE:* then 3 CHANNEL:*) ────────────
-- Keep in step with Base.Application/Interfaces/BillingCodes.cs -> FeatureCodes.All.
-- SortOrder groups FEATURE:* (10-110) before CHANNEL:* (200-220), leaving gaps so a new
-- code can be slotted between two existing ones without renumbering.
INSERT INTO billing."Features"
  ("FeatureCode","FeatureName","Description","SortOrder","CreatedDate","IsActive","IsDeleted")
SELECT v."FeatureCode", v."FeatureName", v."Description", v."SortOrder", now(), true, false
FROM (VALUES
  -- Existing vocabulary (unchanged — these already drive PlanEntitlements).
  ('FEATURE:CONTACTS',       'Contacts',         'Contacts, families and the supporter record.',            10),
  ('FEATURE:DONATION',       'Donations',        'Donations, receipting, pledges and P2P fundraising.',      20),
  ('FEATURE:EVENT',          'Events',           'Event management, registration and attendance.',           30),
  ('FEATURE:VOLUNTEER',      'Volunteers',       'Volunteer records, shifts and hours.',                     40),
  ('FEATURE:MEMBERSHIP',     'Membership',       'Membership plans, subscriptions and renewals.',            50),
  ('FEATURE:CASE',           'Case Management',  'Beneficiary case management and service delivery.',        60),
  ('FEATURE:GRANT',          'Grants',           'Grant pipeline, tranches, expenses and reporting.',        70),
  -- NEW in P-17 — menu groups that had no feature code and were therefore never gated.
  ('FEATURE:FIELDCOLLECTION','Field Collection', 'Ambassadors, field receipt books and collection routes.',  80),
  ('FEATURE:AUTOMATION',     'Automation',       'Workflow automation, journeys and scheduled actions.',     90),
  ('FEATURE:PRAYERREQUEST',  'Prayer Requests',  'Prayer request intake, assignment and follow-up.',        100),
  ('FEATURE:INTELLIGENCE',   'Intelligence',     'Analytics, insights and AI-assisted decision support.',   110),
  -- Channels.
  ('CHANNEL:EMAIL',         'Email Channel',    'Outbound email campaigns and transactional email.',       200),
  ('CHANNEL:WHATSAPP',      'WhatsApp Channel', 'Outbound WhatsApp campaigns and templates.',              210),
  ('CHANNEL:SMS',           'SMS Channel',      'Outbound SMS campaigns.',                                 220)
) AS v("FeatureCode","FeatureName","Description","SortOrder")
WHERE NOT EXISTS (
  SELECT 1 FROM billing."Features" f WHERE f."FeatureCode" = v."FeatureCode"
);

-- ── 2. FeatureMenuMaps — which menus each feature gates ──────────────────────────────
-- The first 12 rows are the hardcoded C# dictionary this table replaces, carried over
-- VERBATIM so applying this script is behaviour-neutral for existing tenants.
--
-- Deliberately NOT mapped (and why):
--   CRM_ORGANIZATION    — org structure/branches; every plan needs it.
--   CRM_NOTIFICATION    — platform infrastructure, not a sold module.
--   CRM_DASHBOARDS      — the GROUP stays visible; its LEAVES are mapped individually
--                         below, so a FREE tenant still gets the dashboards it paid for
--                         instead of losing the whole section.
--   CONTACTDASHBOARD    — every plan has FEATURE:CONTACTS, so a row would be inert.
--   BILLING* / SETTING* / ACCESSCONTROL* — see header note 2.
INSERT INTO billing."FeatureMenuMaps"
  ("FeatureCode","MenuCode","CreatedDate","IsActive","IsDeleted")
SELECT v."FeatureCode", v."MenuCode", now(), true, false
FROM (VALUES
  -- ── Carried over verbatim from the C# dictionary (12 rows) ──
  ('FEATURE:CONTACTS',       'CRM_CONTACT'),
  ('FEATURE:CONTACTS',       'CRM_FAMILY'),
  ('FEATURE:DONATION',       'CRM_DONATION'),
  ('FEATURE:DONATION',       'CRM_P2PFUNDRAISING'),
  ('FEATURE:EVENT',          'CRM_EVENT'),
  ('FEATURE:VOLUNTEER',      'CRM_VOLUNTEER'),
  ('FEATURE:MEMBERSHIP',     'CRM_MEMBERSHIP'),
  ('FEATURE:CASE',           'CRM_CASEMANAGEMENT'),
  ('FEATURE:GRANT',          'CRM_GRANT'),
  ('CHANNEL:EMAIL',         'CRM_COMMUNICATION'),
  ('CHANNEL:SMS',           'CRM_SMS'),
  ('CHANNEL:WHATSAPP',      'CRM_WHATSAPP'),
  -- ── Bundled into an EXISTING code (no new plan row needed) ──
  -- Maintenance = the reference data behind contacts (types, sources, tags).
  ('FEATURE:CONTACTS',       'CRM_MAINTENANCE'),
  -- Certificates are issued off donations (80G / tax receipts).
  ('FEATURE:DONATION',       'CRM_CERTIFICATE'),
  -- ── NEW codes ──
  ('FEATURE:FIELDCOLLECTION','CRM_FIELDCOLLECTION'),
  ('FEATURE:AUTOMATION',     'CRM_AUTOMATION'),
  ('FEATURE:PRAYERREQUEST',  'CRM_PRAYERREQUEST'),
  ('FEATURE:INTELLIGENCE',   'CRM_INTELLIGENCE'),
  -- ── Dashboard LEAVES (the CRM_DASHBOARDS group itself stays unmapped) ──
  ('FEATURE:DONATION',       'DONATIONDASHBOARD'),
  ('CHANNEL:EMAIL',         'COMMUNICATIONDASHBOARD'),
  ('FEATURE:CASE',           'CASEDASHBOARD'),
  ('FEATURE:VOLUNTEER',      'VOLUNTEERDASHBOARD'),
  ('FEATURE:FIELDCOLLECTION','AMBASSADORDASHBOARD')
) AS v("FeatureCode","MenuCode")
WHERE NOT EXISTS (
  SELECT 1 FROM billing."FeatureMenuMaps" m
  WHERE m."FeatureCode" = v."FeatureCode" AND m."MenuCode" = v."MenuCode"
);

-- ── 3. PlanEntitlements for the four NEW feature codes ───────────────────────────────
-- Extends the DQ4 matrix seeded by billing-plan-catalog-seed.sql. The ten existing codes
-- are untouched. Tier shape per PROMPT-17 §④:
--
--   Feature                  FREE   PLAN_50K   PLAN_100K   CUSTOM
--   FEATURE:FIELDCOLLECTION   off    on         on          on
--   FEATURE:AUTOMATION        off    off        on          on
--   FEATURE:PRAYERREQUEST     off    off        on          on
--   FEATURE:INTELLIGENCE      off    off        on          on
--
-- Rows are written for OFF as well as ON: the plan-catalog matrix renders one row per
-- code and treats a missing row as an explicit OFF, but an explicit false row is what
-- lets ops flip the toggle without first creating the row.
INSERT INTO billing."PlanEntitlements"
  ("PlanId","FeatureCode","IsEnabled","CreatedDate","IsActive","IsDeleted")
SELECT p."PlanId", v."FeatureCode", v."IsEnabled", now(), true, false
FROM billing."Plans" p
JOIN (VALUES
  -- FREE
  ('FREE','FEATURE:FIELDCOLLECTION', false),
  ('FREE','FEATURE:AUTOMATION',      false),
  ('FREE','FEATURE:PRAYERREQUEST',   false),
  ('FREE','FEATURE:INTELLIGENCE',    false),
  -- PLAN_50K
  ('PLAN_50K','FEATURE:FIELDCOLLECTION', true),
  ('PLAN_50K','FEATURE:AUTOMATION',      false),
  ('PLAN_50K','FEATURE:PRAYERREQUEST',   false),
  ('PLAN_50K','FEATURE:INTELLIGENCE',    false),
  -- PLAN_100K
  ('PLAN_100K','FEATURE:FIELDCOLLECTION', true),
  ('PLAN_100K','FEATURE:AUTOMATION',      true),
  ('PLAN_100K','FEATURE:PRAYERREQUEST',   true),
  ('PLAN_100K','FEATURE:INTELLIGENCE',    true),
  -- CUSTOM (all on by default; real values via billing.SubscriptionOverrides)
  ('CUSTOM','FEATURE:FIELDCOLLECTION', true),
  ('CUSTOM','FEATURE:AUTOMATION',      true),
  ('CUSTOM','FEATURE:PRAYERREQUEST',   true),
  ('CUSTOM','FEATURE:INTELLIGENCE',    true)
) AS v("PlanCode","FeatureCode","IsEnabled") ON v."PlanCode" = p."PlanCode"
WHERE NOT EXISTS (
  SELECT 1 FROM billing."PlanEntitlements" pe
  WHERE pe."PlanId" = p."PlanId" AND pe."FeatureCode" = v."FeatureCode"
);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--   SELECT count(*) FROM billing."Features";                          -> 14
--   SELECT count(*) FROM billing."FeatureMenuMaps";                   -> 23
--   SELECT p."PlanCode", count(*) FROM billing."PlanEntitlements" e
--     JOIN billing."Plans" p ON p."PlanId"=e."PlanId" GROUP BY p."PlanCode";  -> 14 each
--
--   -- No map row may point at a menu that must always be reachable:
--   SELECT * FROM billing."FeatureMenuMaps"
--    WHERE "MenuCode" LIKE 'BILLING%' OR "MenuCode" LIKE 'SETTING%'
--       OR "MenuCode" LIKE 'ACCESSCONTROL%';                          -> 0 rows
--
--   -- Dormant map rows (MenuCode not seeded in auth."Menus") — informational, not an
--   -- error; they simply gate nothing until that menu exists:
--   SELECT m."MenuCode" FROM billing."FeatureMenuMaps" m
--    WHERE NOT EXISTS (SELECT 1 FROM auth."Menus" x WHERE x."MenuCode" = m."MenuCode");
--
--   -- Every mapped FeatureCode must exist in the vocabulary:
--   SELECT DISTINCT m."FeatureCode" FROM billing."FeatureMenuMaps" m
--    WHERE NOT EXISTS (SELECT 1 FROM billing."Features" f WHERE f."FeatureCode" = m."FeatureCode");
--                                                                     -> 0 rows
-- =====================================================================================
