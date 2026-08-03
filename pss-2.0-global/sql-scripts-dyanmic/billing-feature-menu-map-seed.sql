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

-- ── 1. Features — the vocabulary (14 codes: 11 MODULE:* then 3 CHANNEL:*) ────────────
-- Keep in step with Base.Application/Interfaces/BillingCodes.cs -> FeatureCodes.All.
-- SortOrder groups MODULE:* (10-110) before CHANNEL:* (200-220), leaving gaps so a new
-- code can be slotted between two existing ones without renumbering.
INSERT INTO billing."Features"
  ("FeatureCode","FeatureName","Description","SortOrder","CreatedDate","IsActive","IsDeleted")
SELECT v."FeatureCode", v."FeatureName", v."Description", v."SortOrder", now(), true, false
FROM (VALUES
  -- Existing vocabulary (unchanged — these already drive PlanEntitlements).
  ('MODULE:CONTACTS',       'Contacts',         'Contacts, families and the supporter record.',            10),
  ('MODULE:DONATION',       'Donations',        'Donations, receipting, pledges and P2P fundraising.',      20),
  ('MODULE:EVENT',          'Events',           'Event management, registration and attendance.',           30),
  ('MODULE:VOLUNTEER',      'Volunteers',       'Volunteer records, shifts and hours.',                     40),
  ('MODULE:MEMBERSHIP',     'Membership',       'Membership plans, subscriptions and renewals.',            50),
  ('MODULE:CASE',           'Case Management',  'Beneficiary case management and service delivery.',        60),
  ('MODULE:GRANT',          'Grants',           'Grant pipeline, tranches, expenses and reporting.',        70),
  -- NEW in P-17 — menu groups that had no feature code and were therefore never gated.
  ('MODULE:FIELDCOLLECTION','Field Collection', 'Ambassadors, field receipt books and collection routes.',  80),
  ('MODULE:AUTOMATION',     'Automation',       'Workflow automation, journeys and scheduled actions.',     90),
  ('MODULE:PRAYERREQUEST',  'Prayer Requests',  'Prayer request intake, assignment and follow-up.',        100),
  ('MODULE:INTELLIGENCE',   'Intelligence',     'Analytics, insights and AI-assisted decision support.',   110),
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
--   CONTACTDASHBOARD    — every plan has MODULE:CONTACTS, so a row would be inert.
--   BILLING* / SETTING* / ACCESSCONTROL* — see header note 2.
INSERT INTO billing."FeatureMenuMaps"
  ("FeatureCode","MenuCode","CreatedDate","IsActive","IsDeleted")
SELECT v."FeatureCode", v."MenuCode", now(), true, false
FROM (VALUES
  -- ── Carried over verbatim from the C# dictionary (12 rows) ──
  ('MODULE:CONTACTS',       'CRM_CONTACT'),
  ('MODULE:CONTACTS',       'CRM_FAMILY'),
  ('MODULE:DONATION',       'CRM_DONATION'),
  ('MODULE:DONATION',       'CRM_P2PFUNDRAISING'),
  ('MODULE:EVENT',          'CRM_EVENT'),
  ('MODULE:VOLUNTEER',      'CRM_VOLUNTEER'),
  ('MODULE:MEMBERSHIP',     'CRM_MEMBERSHIP'),
  ('MODULE:CASE',           'CRM_CASEMANAGEMENT'),
  ('MODULE:GRANT',          'CRM_GRANT'),
  ('CHANNEL:EMAIL',         'CRM_COMMUNICATION'),
  ('CHANNEL:SMS',           'CRM_SMS'),
  ('CHANNEL:WHATSAPP',      'CRM_WHATSAPP'),
  -- ── Bundled into an EXISTING code (no new plan row needed) ──
  -- Maintenance = the reference data behind contacts (types, sources, tags).
  ('MODULE:CONTACTS',       'CRM_MAINTENANCE'),
  -- Certificates are issued off donations (80G / tax receipts).
  ('MODULE:DONATION',       'CRM_CERTIFICATE'),
  -- ── NEW codes ──
  ('MODULE:FIELDCOLLECTION','CRM_FIELDCOLLECTION'),
  ('MODULE:AUTOMATION',     'CRM_AUTOMATION'),
  ('MODULE:PRAYERREQUEST',  'CRM_PRAYERREQUEST'),
  ('MODULE:INTELLIGENCE',   'CRM_INTELLIGENCE'),
  -- ── Dashboard LEAVES (the CRM_DASHBOARDS group itself stays unmapped) ──
  ('MODULE:DONATION',       'DONATIONDASHBOARD'),
  ('CHANNEL:EMAIL',         'COMMUNICATIONDASHBOARD'),
  ('MODULE:CASE',           'CASEDASHBOARD'),
  ('MODULE:VOLUNTEER',      'VOLUNTEERDASHBOARD'),
  ('MODULE:FIELDCOLLECTION','AMBASSADORDASHBOARD')
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
--   MODULE:FIELDCOLLECTION   off    on         on          on
--   MODULE:AUTOMATION        off    off        on          on
--   MODULE:PRAYERREQUEST     off    off        on          on
--   MODULE:INTELLIGENCE      off    off        on          on
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
  ('FREE','MODULE:FIELDCOLLECTION', false),
  ('FREE','MODULE:AUTOMATION',      false),
  ('FREE','MODULE:PRAYERREQUEST',   false),
  ('FREE','MODULE:INTELLIGENCE',    false),
  -- PLAN_50K
  ('PLAN_50K','MODULE:FIELDCOLLECTION', true),
  ('PLAN_50K','MODULE:AUTOMATION',      false),
  ('PLAN_50K','MODULE:PRAYERREQUEST',   false),
  ('PLAN_50K','MODULE:INTELLIGENCE',    false),
  -- PLAN_100K
  ('PLAN_100K','MODULE:FIELDCOLLECTION', true),
  ('PLAN_100K','MODULE:AUTOMATION',      true),
  ('PLAN_100K','MODULE:PRAYERREQUEST',   true),
  ('PLAN_100K','MODULE:INTELLIGENCE',    true),
  -- CUSTOM (all on by default; real values via billing.SubscriptionOverrides)
  ('CUSTOM','MODULE:FIELDCOLLECTION', true),
  ('CUSTOM','MODULE:AUTOMATION',      true),
  ('CUSTOM','MODULE:PRAYERREQUEST',   true),
  ('CUSTOM','MODULE:INTELLIGENCE',    true)
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
