-- =====================================================================================
--  billing-feature-menu-map-complete-seed.sql
--
--  The CURATED feature catalogue and feature -> menu map, decided menu by menu against
--  the live menu tree (.claude/screen-tracker/MODULE_MENU_REFERENCE.md).
--
--  SUPERSEDES  billing-feature-menu-map-seed.sql  (P-17). This file is a strict superset:
--  it repeats those 23 rows and adds the menus that were introduced after P-17 was written.
--  Run THIS file. Running the old one as well is harmless (both are additive + idempotent).
--
--  Prerequisites: the Add_BillingFeatureCatalog migration, then billing-plan-catalog-seed.sql.
--
--  HOW TO READ THE MAP
--    A row means "this menu is SOLD as part of this feature". If the plan does not have the
--    feature, the menu is hidden - and so is every menu under it (children cascade).
--    A menu with NO row is ALWAYS VISIBLE. The map is deliberately PARTIAL: absence means
--    "everyone gets it", never "blocked". So a missing row is safe; a wrong row hides a screen.
--    Hiding is COSMETIC. [RequiresFeature] on the resolver is the actual security control.
--
--    A row may name a GROUP (CRM_DONATION) or a LEAF (DONATIONPURPOSE). Group rows are used
--    when the whole group belongs to one feature. Leaf rows are used when a group mixes
--    features - e.g. SET_PUBLICPAGES holds a donation page, an event page and a volunteer
--    page, so the GROUP stays unmapped and each LEAF is mapped to its own feature.
--
--  DELIBERATELY UNMAPPED - every tenant gets these whatever they pay:
--    CRM_ORGANIZATION group   org units + campaigns are the spine of every plan.
--                             (its three donation-config leaves ARE mapped, see below)
--    CRM_NOTIFICATION         platform plumbing, not a sold module.
--    CRM_DASHBOARDS group     the group must stay visible or a small plan loses its whole
--                             dashboard section; the LEAVES are mapped one by one instead.
--    CONTACTDASHBOARD         every plan has FEATURE:CONTACTS, so a row would be inert.
--    ORG_COMPANY, ORG_STAFF   company, branches, staff - core to every tenant.
--    AC_USERSROLES, AC_GOVERNANCE   a tenant must always reach its own access control.
--    GEN_REGION, GEN_MASTERS  reference data every screen depends on.
--    SET_DATACONFIG, SET_GRIDMANAGEMENT, SET_DASHBOARDWIDGET, SET_ORGSETTINGS, SET_DOCUMENT
--                             configuration surface of the product itself.
--    SET_PAYMENTCONFIG        gateways collect for donations AND membership AND ticketing.
--                             Tying it to one feature would break the others.
--    SET_COMMUNICATIONCONFIG group   mixes three channels; leaves mapped individually.
--    SET_PUBLICPAGES group    mixes five features; leaves mapped individually.
--    RA_REPORTS group + REPORTCATALOG, FUNDRAISINGSUMMARY, HTMLREPORT, GENERATEREPORT
--                             baseline reporting ships with every plan.
--    RA_AUDIT                 audit trail is a compliance floor, never an upsell.
--    BILLING*                 a tenant must always be able to pay us and upgrade.
-- =====================================================================================

BEGIN;

-- ── 1. Features - the sellable vocabulary ────────────────────────────────────────────
--  SortOrder leaves gaps on purpose so a new feature can slot in without a renumber.
INSERT INTO billing."Features"
       ("FeatureCode", "FeatureName", "Description", "SortOrder",
        "IsActive", "IsDeleted", "CreatedDate")
SELECT v.code, v.name, v.descr, v.sort, true, false, now()
FROM (VALUES
  ('FEATURE:CONTACTS',         'Contacts',          'Contacts, families, segmentation and the supporter record.',   10),
  ('FEATURE:DONATION',         'Donations',         'Donations, receipting, pledges, P2P and the donation pages.',   20),
  ('FEATURE:EVENT',            'Events',            'Event management, ticketing, auctions and attendance.',         30),
  ('FEATURE:VOLUNTEER',        'Volunteers',        'Volunteer records, scheduling, hours and conversion.',          40),
  ('FEATURE:MEMBERSHIP',       'Membership',        'Membership tiers, enrollment, renewals and member portal.',     50),
  ('FEATURE:CASE',             'Case Management',   'Beneficiaries, cases, programs and service delivery.',          60),
  ('FEATURE:GRANT',            'Grants',            'Grant pipeline, tranches, expenses and funder reporting.',      70),
  ('FEATURE:FIELDCOLLECTION',  'Field Collection',  'Ambassadors, receipt books, collection routes and payouts.',    80),
  ('FEATURE:AUTOMATION',       'Automation',        'Workflow automation, journeys and scheduled actions.',          90),
  ('FEATURE:PRAYERREQUEST',    'Prayer Requests',   'Prayer request intake, reply queue and public request page.',  100),
  ('FEATURE:INTELLIGENCE',     'Intelligence',      'Scoring, churn prediction, action board and AI assistance.',   110),
  ('FEATURE:ADVANCEDREPORTING','Advanced Reporting','Custom report builder, scheduled delivery and retention.',     120),
  ('FEATURE:POWERBI',          'PowerBI',           'Embedded PowerBI reports and per-user report mapping.',        130),
  ('FEATURE:INTEGRATION',      'Integrations',      'Accounting, social, API keys and the integration marketplace.',140),
  ('CHANNEL:EMAIL',           'Email Channel',     'Outbound email campaigns, templates and provider setup.',      200),
  ('CHANNEL:WHATSAPP',        'WhatsApp Channel',  'Outbound WhatsApp campaigns, templates and provider setup.',   210),
  ('CHANNEL:SMS',             'SMS Channel',       'Outbound SMS campaigns, templates and provider setup.',        220)
) AS v(code, name, descr, sort)
WHERE NOT EXISTS (
  SELECT 1 FROM billing."Features" f WHERE f."FeatureCode" = v.code
);

-- ── 2. FeatureMenuMaps - the manual assignment ───────────────────────────────────────
INSERT INTO billing."FeatureMenuMaps"
       ("FeatureCode", "MenuCode", "IsActive", "IsDeleted", "CreatedDate")
SELECT v.feature, v.menu, true, false, now()
FROM (VALUES

  -- ══ CONTACTS ═══════════════════════════════════════════════════════════════════════
  -- If I sell Contacts, the tenant gets: the contact list, its own reference data
  -- (types, sources, tags), the importer, families, and dedupe.
  ('FEATURE:CONTACTS',        'CRM_CONTACT'),              -- + CONTACT, CONTACTTYPE, CONTACTSOURCE, TAGSEGMENTATION, CONTACTIMPORT
  ('FEATURE:CONTACTS',        'CRM_FAMILY'),               -- households are part of the supporter record
  ('FEATURE:CONTACTS',        'CRM_MAINTENANCE'),          -- DUPLICATECONTACT dedupes contacts, nothing else

  -- ══ DONATIONS ══════════════════════════════════════════════════════════════════════
  -- The biggest feature. It carries everything money-in: the ledger, the ways money
  -- arrives (P2P, online pages), and what goes back out to the donor (receipts,
  -- certificates), plus the reference data those rows are coded against.
  ('FEATURE:DONATION',        'CRM_DONATION'),             -- + all donations, recurring, cheque, in-kind, pledge, bulk, reconciliation, refund
  ('FEATURE:DONATION',        'CRM_P2PFUNDRAISING'),       -- P2P campaigns/fundraisers/crowdfunding/matching gifts all book donations
  ('FEATURE:DONATION',        'CRM_CERTIFICATE'),          -- 80G / tax certificates are issued off donations
  ('FEATURE:DONATION',        'CERTIFICATETEMPLATECONFIG'),-- leaf of SET_DOCUMENT; the template behind those certificates
  ('FEATURE:DONATION',        'SET_DONATIONCONFIG'),       -- + DONATIONVERSE, RECEIPTMANAGEMENT - both donation-only
  -- These three sit under CRM_ORGANIZATION but are pure donation reference data. The
  -- GROUP stays unmapped (org units + campaigns are needed by every plan), so they are
  -- mapped as leaves.
  ('FEATURE:DONATION',        'DONATIONCATEGORY'),
  ('FEATURE:DONATION',        'DONATIONGROUP'),
  ('FEATURE:DONATION',        'DONATIONPURPOSE'),
  -- Public pages that collect donations. Leaves of SET_PUBLICPAGES.
  ('FEATURE:DONATION',        'ONLINEDONATIONPAGE'),
  ('FEATURE:DONATION',        'P2PCAMPAIGNPAGE'),
  ('FEATURE:DONATION',        'DONATIONDASHBOARD'),        -- dashboard leaf

  -- ══ EVENTS ═════════════════════════════════════════════════════════════════════════
  ('FEATURE:EVENT',           'CRM_EVENT'),                -- + events, ticketing, auctions, analytics
  ('FEATURE:EVENT',           'EVENTREGPAGE'),             -- the public page that feeds event registration

  -- ══ VOLUNTEERS ═════════════════════════════════════════════════════════════════════
  ('FEATURE:VOLUNTEER',       'CRM_VOLUNTEER'),            -- + list, register, scheduling, hours, donor conversion
  ('FEATURE:VOLUNTEER',       'VOLUNTEERREGPAGE'),         -- public sign-up page
  ('FEATURE:VOLUNTEER',       'VOLUNTEERDASHBOARD'),

  -- ══ MEMBERSHIP ═════════════════════════════════════════════════════════════════════
  ('FEATURE:MEMBERSHIP',      'CRM_MEMBERSHIP'),           -- + member list, enrollment, tiers, renewals
  ('FEATURE:MEMBERSHIP',      'SET_MEMBERSHIPCONFIG'),     -- + MEMBERSHIPTIERCONFIG - useless without membership
  ('FEATURE:MEMBERSHIP',      'MEMBERPORTAL'),             -- the members' own public portal

  -- ══ CASE MANAGEMENT ════════════════════════════════════════════════════════════════
  ('FEATURE:CASE',            'CRM_CASEMANAGEMENT'),       -- + beneficiaries, cases, programs
  ('FEATURE:CASE',            'CASEDASHBOARD'),

  -- ══ GRANTS ═════════════════════════════════════════════════════════════════════════
  -- Funder reports live inside the group, so one row covers the feature.
  ('FEATURE:GRANT',           'CRM_GRANT'),                -- + grants, application, calendar, funder reports

  -- ══ FIELD COLLECTION ═══════════════════════════════════════════════════════════════
  ('FEATURE:FIELDCOLLECTION', 'CRM_FIELDCOLLECTION'),      -- + ambassadors, collection, receipt books, performance, distribution
  ('FEATURE:FIELDCOLLECTION', 'AMBASSADORDASHBOARD'),

  -- ══ AUTOMATION ═════════════════════════════════════════════════════════════════════
  ('FEATURE:AUTOMATION',      'CRM_AUTOMATION'),

  -- ══ PRAYER REQUESTS ════════════════════════════════════════════════════════════════
  ('FEATURE:PRAYERREQUEST',   'CRM_PRAYERREQUEST'),        -- one menu, three capability-gated tabs
  ('FEATURE:PRAYERREQUEST',   'PRAYERREQUESTPAGE'),        -- the public intake page that feeds it

  -- ══ INTELLIGENCE ═══════════════════════════════════════════════════════════════════
  ('FEATURE:INTELLIGENCE',    'CRM_INTELLIGENCE'),         -- + scoring, churn, action board, AI draft, ask-your-data, predictive

  -- ══ ADVANCED REPORTING ═════════════════════════════════════════════════════════════
  -- Leaves only. The RA_REPORTS group and the standard reports stay visible on every
  -- plan; only the build-your-own and deliver-it-for-me pieces are sold.
  ('FEATURE:ADVANCEDREPORTING','CUSTOMREPORTBUILDER'),
  ('FEATURE:ADVANCEDREPORTING','SCHEDULEDREPORT'),
  ('FEATURE:ADVANCEDREPORTING','RETENTIONDASHBOARD'),

  -- ══ POWERBI ════════════════════════════════════════════════════════════════════════
  -- A licensed add-on, not part of the product. Viewer leaf + the whole setup group.
  ('FEATURE:POWERBI',         'POWERBIREPORT'),
  ('FEATURE:POWERBI',         'RA_REPORTSETUP'),           -- + POWERBIREPORTMASTER, POWERBIUSERMAPPING

  -- ══ INTEGRATIONS ═══════════════════════════════════════════════════════════════════
  ('FEATURE:INTEGRATION',     'SET_INTEGRATION'),          -- + accounting, social, API keys, marketplace

  -- ══ EMAIL CHANNEL ══════════════════════════════════════════════════════════════════
  -- The channel sells the campaign surface AND its provider setup together - the setup
  -- screen is meaningless to a tenant who cannot send.
  ('CHANNEL:EMAIL',          'CRM_COMMUNICATION'),        -- + templates, campaigns, analytics, keywords, placeholders, saved filters
  ('CHANNEL:EMAIL',          'EMAILPROVIDERCONFIG'),      -- leaf of SET_COMMUNICATIONCONFIG
  ('CHANNEL:EMAIL',          'COMMUNICATIONDASHBOARD'),

  -- ══ SMS CHANNEL ════════════════════════════════════════════════════════════════════
  ('CHANNEL:SMS',            'CRM_SMS'),                  -- + SMS templates, campaigns
  ('CHANNEL:SMS',            'SMSSETUP'),

  -- ══ WHATSAPP CHANNEL ═══════════════════════════════════════════════════════════════
  ('CHANNEL:WHATSAPP',       'CRM_WHATSAPP'),             -- + templates, campaigns, conversations
  ('CHANNEL:WHATSAPP',       'WHATSAPPSETUP')

) AS v(feature, menu)
WHERE NOT EXISTS (
  SELECT 1 FROM billing."FeatureMenuMaps" m
  WHERE m."FeatureCode" = v.feature AND m."MenuCode" = v.menu
);

-- ── 3. PlanEntitlements - which plan sells which feature ─────────────────────────────
--  All 17 codes x 4 plans. Idempotent, so the ten rows already written by
--  billing-plan-catalog-seed.sql are left exactly as they are.
INSERT INTO billing."PlanEntitlements"
       ("PlanId", "FeatureCode", "IsEnabled", "IsActive", "IsDeleted", "CreatedDate")
SELECT p."PlanId", v.feature, v.enabled, true, false, now()
FROM (VALUES
  ('FREE','FEATURE:CONTACTS',true),          ('FREE','FEATURE:DONATION',true),
  ('FREE','FEATURE:EVENT',false),            ('FREE','FEATURE:VOLUNTEER',false),
  ('FREE','FEATURE:MEMBERSHIP',false),       ('FREE','FEATURE:CASE',false),
  ('FREE','FEATURE:GRANT',false),            ('FREE','FEATURE:FIELDCOLLECTION',false),
  ('FREE','FEATURE:AUTOMATION',false),       ('FREE','FEATURE:PRAYERREQUEST',false),
  ('FREE','FEATURE:INTELLIGENCE',false),     ('FREE','FEATURE:ADVANCEDREPORTING',false),
  ('FREE','FEATURE:POWERBI',false),          ('FREE','FEATURE:INTEGRATION',false),
  ('FREE','CHANNEL:EMAIL',true),            ('FREE','CHANNEL:WHATSAPP',false),
  ('FREE','CHANNEL:SMS',false),

  ('PLAN_50K','FEATURE:CONTACTS',true),      ('PLAN_50K','FEATURE:DONATION',true),
  ('PLAN_50K','FEATURE:EVENT',true),         ('PLAN_50K','FEATURE:VOLUNTEER',true),
  ('PLAN_50K','FEATURE:MEMBERSHIP',true),    ('PLAN_50K','FEATURE:CASE',false),
  ('PLAN_50K','FEATURE:GRANT',false),        ('PLAN_50K','FEATURE:FIELDCOLLECTION',true),
  ('PLAN_50K','FEATURE:AUTOMATION',false),   ('PLAN_50K','FEATURE:PRAYERREQUEST',false),
  ('PLAN_50K','FEATURE:INTELLIGENCE',false), ('PLAN_50K','FEATURE:ADVANCEDREPORTING',false),
  ('PLAN_50K','FEATURE:POWERBI',false),      ('PLAN_50K','FEATURE:INTEGRATION',false),
  ('PLAN_50K','CHANNEL:EMAIL',true),        ('PLAN_50K','CHANNEL:WHATSAPP',false),
  ('PLAN_50K','CHANNEL:SMS',false),

  ('PLAN_100K','FEATURE:CONTACTS',true),     ('PLAN_100K','FEATURE:DONATION',true),
  ('PLAN_100K','FEATURE:EVENT',true),        ('PLAN_100K','FEATURE:VOLUNTEER',true),
  ('PLAN_100K','FEATURE:MEMBERSHIP',true),   ('PLAN_100K','FEATURE:CASE',true),
  ('PLAN_100K','FEATURE:GRANT',true),        ('PLAN_100K','FEATURE:FIELDCOLLECTION',true),
  ('PLAN_100K','FEATURE:AUTOMATION',true),   ('PLAN_100K','FEATURE:PRAYERREQUEST',true),
  ('PLAN_100K','FEATURE:INTELLIGENCE',true), ('PLAN_100K','FEATURE:ADVANCEDREPORTING',true),
  ('PLAN_100K','FEATURE:POWERBI',false),     ('PLAN_100K','FEATURE:INTEGRATION',true),
  ('PLAN_100K','CHANNEL:EMAIL',true),       ('PLAN_100K','CHANNEL:WHATSAPP',true),
  ('PLAN_100K','CHANNEL:SMS',true),

  ('CUSTOM','FEATURE:CONTACTS',true),        ('CUSTOM','FEATURE:DONATION',true),
  ('CUSTOM','FEATURE:EVENT',true),           ('CUSTOM','FEATURE:VOLUNTEER',true),
  ('CUSTOM','FEATURE:MEMBERSHIP',true),      ('CUSTOM','FEATURE:CASE',true),
  ('CUSTOM','FEATURE:GRANT',true),           ('CUSTOM','FEATURE:FIELDCOLLECTION',true),
  ('CUSTOM','FEATURE:AUTOMATION',true),      ('CUSTOM','FEATURE:PRAYERREQUEST',true),
  ('CUSTOM','FEATURE:INTELLIGENCE',true),    ('CUSTOM','FEATURE:ADVANCEDREPORTING',true),
  ('CUSTOM','FEATURE:POWERBI',true),         ('CUSTOM','FEATURE:INTEGRATION',true),
  ('CUSTOM','CHANNEL:EMAIL',true),          ('CUSTOM','CHANNEL:WHATSAPP',true),
  ('CUSTOM','CHANNEL:SMS',true)
) AS v(plan_code, feature, enabled)
JOIN billing."Plans" p
     ON p."PlanCode" = v.plan_code AND p."IsDeleted" IS DISTINCT FROM true
WHERE NOT EXISTS (
  SELECT 1 FROM billing."PlanEntitlements" e
  WHERE e."PlanId" = p."PlanId" AND e."FeatureCode" = v.feature
);

COMMIT;

-- Result. Expect: 17 features, 44 map rows, 17 entitlements per plan, and an empty
-- orphan list. A map row whose MenuCode is not in auth."Menus" is inert, never a lockout -
-- but it is almost always a typo, so it is listed.
SELECT 'features'      AS what, count(*)::text AS value FROM billing."Features"          WHERE "IsDeleted" IS DISTINCT FROM true
UNION ALL
SELECT 'map rows',           count(*)::text FROM billing."FeatureMenuMaps"               WHERE "IsDeleted" IS DISTINCT FROM true
UNION ALL
SELECT 'entitlements ' || p."PlanCode", count(e.*)::text
FROM   billing."Plans" p
LEFT   JOIN billing."PlanEntitlements" e ON e."PlanId" = p."PlanId" AND e."IsDeleted" IS DISTINCT FROM true
WHERE  p."IsDeleted" IS DISTINCT FROM true
GROUP  BY p."PlanCode"
UNION ALL
SELECT 'ORPHAN MenuCode', m."MenuCode"
FROM   billing."FeatureMenuMaps" m
WHERE  m."IsDeleted" IS DISTINCT FROM true
  AND  NOT EXISTS (SELECT 1 FROM auth."Menus" x WHERE upper(x."MenuCode") = upper(m."MenuCode"));
