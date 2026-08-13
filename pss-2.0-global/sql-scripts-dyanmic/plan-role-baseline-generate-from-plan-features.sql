-- =====================================================================================
--  plan-role-baseline-generate-from-plan-features.sql
--
--  Rebuilds billing."PlanRoleBaselines" for RoleCode = 'BUSINESSADMIN'.
--
--  ONLY LEAF MENUS GET BASELINE ROWS.
--    Capabilities (READ / CREATE / MODIFY / DELETE / EXPORT / IMPORT / TOGGLE /
--    ISMENURENDER) are seeded per LEAF menu only - auth."Menus"."IsLeastMenu" = true.
--    A parent / group menu has NO capability rows at all, so a baseline row for a group
--    can never resolve to a tenant RoleCapability. Writing one is pure noise and it is
--    what made the earlier runs report big "missing" counts.
--
--    So: groups are still LISTED below (the cascade needs them - blocking a group must
--    block its children), but they are never WRITTEN. Section 3 reports them as
--    SKIP-GROUP.
--
--  THE MENU LIST IS HAND-WRITTEN, NOT DISCOVERED.
--    Section 1 lists every menu of the product, one line each, with the parent it hangs
--    under and the feature that sells it. That list is a business decision, exactly like
--    billing-feature-menu-map-leaf-level-seed.sql. Nothing is read out of the menu tree
--    to decide what a plan gets, and no join grants anything.
--
--      feature_code = NULL   the menu is part of the platform - every plan gets it.
--      feature_code = 'X'    the menu appears only if the plan buys X.
--      A child is blocked when its own feature is unsold OR its parent is blocked.
--
--    The codes below were transcribed from a dump of the LIVE auth."Menus" table
--    (menus.sql + modules.sql, taken 2026-08-07) - not from the backend seed files and not
--    from any doc. The seed files are behind the database and MODULE_MENU_REFERENCE.md is
--    stale; neither is a safe source for a MenuCode.
--
--    Codes that look wrong but are correct in the live tree, so do not "fix" them:
--      CONTACT              (not ALLCONTACTS)
--      PRAYERREQUESTS       (one screen, not seven)
--      AIREPORTING          (not NLREPORTING)
--      EMAILSENDJOB         (not EMAILCAMPAIGN)
--      STAFF                (not STAFFS)
--      EVENTTICKET          (not EVENTTICKETING)
--      VOLUNTEERSHIFT       (not VOLUNTEERSCHEDULING)
--      AMBASSADORS          (not AMBASSADORLIST)
--      NOTIFICATION         (not NOTIFICATIONCENTER)
--      DASHBOARD            (not DASHBOARD_SETTING)
--      COMPANYEMAILPROVIDER (not EMAILPROVIDERCONFIG)
--    The donation reference screens (DONATIONCATEGORY / DONATIONGROUP / DONATIONPURPOSE /
--    DONATIONCONFIG) live under CRM_ORGANIZATION, not under SET_DONATIONCONFIG.
--
--    IsLeastMenu is NOT "has no children". It is a hand-set "this row owns capability rows"
--    flag, and several menus are both a leaf and a parent (TAGSEGMENTATION, AUCTIONMANAGEMENT,
--    MATCHINGGIFT, RECEIPTMANAGEMENT, ROLEMANAGEMENT). The script reads the flag from the
--    database and never infers it from this list.
--
--  WHAT THE SCRIPT DOES WITH THAT LIST
--    Section 2  checks each listed code one at a time against auth."Menus"
--               (exists / not deleted / active / not PLATFORM) and records whether it is
--               a leaf. It also reports LIVE LEAF menus that are NOT in the list.
--    Section 3  for every plan, decides each listed menu one at a time (parents first,
--               then children), then writes capability cells for the LEAVES only.
--    Section 4  removes the cells the plan no longer sells, one row at a time.
--
--  Only touches RoleCode = 'BUSINESSADMIN'. Curated role codes are never read or deleted.
--  Never touches auth."RoleCapabilities" - no live tenant is changed by this script.
--
--  A menu whose feature does not exist in billing."Features" is reported as
--  UNKNOWN-FEATURE and then decided by billing."PlanEntitlements" like any other - if no
--  plan has an entitlement row for that code, the menu is blocked everywhere. Fix the
--  catalogue, do not fix it here.
--
--  Unticking a cell is a HARD delete on purpose: the unique index is
--  (PlanId, RoleCode, MenuId, CapabilityId) without IsDeleted, so a soft-deleted row would
--  permanently block re-adding that cell. Do not change this to a soft delete.
--
--  A plan that produces zero cells is SKIPPED, never emptied - a wrong list can never wipe
--  a baseline that is currently working.
--
--  Run the whole file, once. It is idempotent - running it again changes nothing.
--
--  RUN ORDER
--    1. billing-feature-menu-map-leaf-level-seed.sql
--    2. billing-feature-catalog-cleanup.sql
--    3. billing-plan-entitlement-repair.sql
--    4. THIS FILE
-- =====================================================================================

BEGIN;

DROP TABLE IF EXISTS tmp_menu_grant;
DROP TABLE IF EXISTS tmp_menu_ok;
DROP TABLE IF EXISTS tmp_decision;
DROP TABLE IF EXISTS tmp_baseline_target;
DROP TABLE IF EXISTS tmp_baseline_report;
DROP TABLE IF EXISTS tmp_plans_in_scope;

-- ═════════════════════════════════════════════════════════════════════════════════════
--  SECTION 1 - THE HAND-WRITTEN MENU LIST
--  Edit THIS when a screen is added, moved, or sold differently. Nothing else.
--  Group rows are here for the cascade only - they never receive a baseline cell.
-- ═════════════════════════════════════════════════════════════════════════════════════

CREATE TEMP TABLE tmp_menu_grant (
    menu_code    text PRIMARY KEY,
    parent_code  text,          -- NULL = top-level menu group
    feature_code text           -- NULL = always granted, never plan-gated
);

INSERT INTO tmp_menu_grant (menu_code, parent_code, feature_code) VALUES

-- ═══ MODULE: CRM ═════════════════════════════════════════════════════════════════════

-- ── Dashboards ──────────────────────────────────────────────────────────────────────
-- The group itself is never gated - gating it would hide every dashboard at once. Each
-- dashboard is sold with the area it reports on. CASEDASHBOARD is NOT here; in the live
-- tree it sits under CRM_CASEMANAGEMENT.
  ('CRM_DASHBOARDS',              NULL,                     NULL),
  ('CONTACTDASHBOARD',            'CRM_DASHBOARDS',         NULL),
  ('DONATIONDASHBOARD',           'CRM_DASHBOARDS',         'FEATURE:DONATION'),
  ('COMMUNICATIONDASHBOARD',      'CRM_DASHBOARDS',         'CHANNEL:EMAIL'),
  ('AMBASSADORDASHBOARD',         'CRM_DASHBOARDS',         'FEATURE:FIELDCOLLECTION'),
  ('VOLUNTEERDASHBOARD',          'CRM_DASHBOARDS',         'FEATURE:VOLUNTEER'),

-- ── Contacts ────────────────────────────────────────────────────────────────────────
-- The list screen is CONTACT ("All Contacts"), not ALLCONTACTS. TAGSEGMENTATION is both a
-- screen and a parent - it carries capabilities of its own and also owns TAG / SEGMENT.
  ('CRM_CONTACT',                 NULL,                     'FEATURE:CONTACTS'),
  ('CONTACT',                     'CRM_CONTACT',            'FEATURE:CONTACTS'),
  ('CONTACTTYPE',                 'CRM_CONTACT',            'FEATURE:CONTACTS'),
  ('CONTACTSOURCE',               'CRM_CONTACT',            'FEATURE:CONTACTS'),
  ('TAGSEGMENTATION',             'CRM_CONTACT',            'FEATURE:CONTACTS'),
  ('TAG',                         'TAGSEGMENTATION',        'FEATURE:CONTACTS'),
  ('SEGMENT',                     'TAGSEGMENTATION',        'FEATURE:CONTACTS'),
  ('CONTACTIMPORT',               'CRM_CONTACT',            'FEATURE:CONTACTS'),

  ('CRM_FAMILY',                  NULL,                     'FEATURE:CONTACTS'),
  ('FAMILY',                      'CRM_FAMILY',             'FEATURE:CONTACTS'),

  ('CRM_MAINTENANCE',             NULL,                     'FEATURE:CONTACTS'),
  ('DUPLICATECONTACT',            'CRM_MAINTENANCE',        'FEATURE:CONTACTS'),

-- ── Certificates ────────────────────────────────────────────────────────────────────
-- Donor-facing certificates. Two screens only; there is no PROCESSCERTIFICATE or
-- PRINTCERTIFICATE menu in the live tree.
  ('CRM_CERTIFICATE',             NULL,                     'FEATURE:DONATION'),
  ('CERTIFICATETEMPLATE',         'CRM_CERTIFICATE',        'FEATURE:DONATION'),
  ('CERTIFICATEOPERATIONS',       'CRM_CERTIFICATE',        'FEATURE:DONATION'),

-- ── Organization reference data ─────────────────────────────────────────────────────
-- Mixed group: org units and campaigns ship with every plan, the four donation reference
-- screens do not. So the group is ungated and each child decides for itself.
  ('CRM_ORGANIZATION',            NULL,                     NULL),
  ('ORGANIZATIONALUNIT',          'CRM_ORGANIZATION',       NULL),
  ('CAMPAIGN',                    'CRM_ORGANIZATION',       NULL),
  ('DONATIONCATEGORY',            'CRM_ORGANIZATION',       'FEATURE:DONATION'),
  ('DONATIONCONFIG',              'CRM_ORGANIZATION',       'FEATURE:DONATION'),
  ('DONATIONGROUP',               'CRM_ORGANIZATION',       'FEATURE:DONATION'),
  ('DONATIONPURPOSE',             'CRM_ORGANIZATION',       'FEATURE:DONATION'),

-- ── Donations ───────────────────────────────────────────────────────────────────────
  ('CRM_DONATION',                NULL,                     'FEATURE:DONATION'),
  ('GLOBALDONATION',              'CRM_DONATION',           'FEATURE:DONATION'),
  ('GLOBALONLINEDONATION',        'CRM_DONATION',           'FEATURE:DONATION'),
  ('RECURRINGDONOR',              'CRM_DONATION',           'FEATURE:DONATION'),
  ('CHEQUEDONATION',              'CRM_DONATION',           'FEATURE:DONATION'),
  ('PAYMENTTRANSACTION',          'CRM_DONATION',           'FEATURE:DONATION'),
  ('DONATIONINKIND',              'CRM_DONATION',           'FEATURE:DONATION'),
  ('PAYMENTSETTLEMENT',           'CRM_DONATION',           'FEATURE:DONATION'),
  ('PLEDGE',                      'CRM_DONATION',           'FEATURE:DONATION'),
  ('BULKDONATION',                'CRM_DONATION',           'FEATURE:DONATION'),
  ('RECONCILIATION',              'CRM_DONATION',           'FEATURE:DONATION'),
  ('REFUND',                      'CRM_DONATION',           'FEATURE:DONATION'),
  ('ONLINEDONATIONINBOX',         'CRM_DONATION',           'FEATURE:DONATION'),
  ('ONLINEDONATIONPAGE',          'CRM_DONATION',           'FEATURE:DONATION'),
  ('ONLINEDONATIONPAGEPURPOSE',   'CRM_DONATION',           'FEATURE:DONATION'),

-- ── Field collection ────────────────────────────────────────────────────────────────
  ('CRM_FIELDCOLLECTION',         NULL,                     'FEATURE:FIELDCOLLECTION'),
  ('AMBASSADORS',                 'CRM_FIELDCOLLECTION',    'FEATURE:FIELDCOLLECTION'),
  ('COLLECTIONLIST',              'CRM_FIELDCOLLECTION',    'FEATURE:FIELDCOLLECTION'),
  ('RECEIPTBOOK',                 'CRM_FIELDCOLLECTION',    'FEATURE:FIELDCOLLECTION'),
  ('AMBASSADORPERFORMANCE',       'CRM_FIELDCOLLECTION',    'FEATURE:FIELDCOLLECTION'),

-- ── Peer-to-peer fundraising ────────────────────────────────────────────────────────
-- Sold as part of donations, not as its own line item. MATCHINGGIFT is a screen and a
-- parent at the same time.
  ('CRM_P2PFUNDRAISING',          NULL,                     'FEATURE:DONATION'),
  ('P2PCAMPAIGN',                 'CRM_P2PFUNDRAISING',     'FEATURE:DONATION'),
  ('P2PFUNDRAISER',               'CRM_P2PFUNDRAISING',     'FEATURE:DONATION'),
  ('P2PCAMPAIGNPAGE',             'CRM_P2PFUNDRAISING',     'FEATURE:DONATION'),
  ('MATCHINGGIFT',                'CRM_P2PFUNDRAISING',     'FEATURE:DONATION'),
  ('MATCHINGCOMPANY',             'MATCHINGGIFT',           'FEATURE:DONATION'),
  ('MATCHINGGIFTRECORD',          'MATCHINGGIFT',           'FEATURE:DONATION'),
  ('MATCHINGGIFTSETTINGS',        'MATCHINGGIFT',           'FEATURE:DONATION'),

-- ── Crowdfunding + event registration ───────────────────────────────────────────────
-- Mixed group. In the live tree the two event-registration screens hang off the
-- crowdfunding group (and carry the SETTING ModuleId - a data oddity, but real), so they
-- are listed here with their real parent and gated on events, not on donations.
  ('CROWDFUNDINGMANAGEMENT',      NULL,                     NULL),
  ('CROWDFUNDINGPAGE',            'CROWDFUNDINGMANAGEMENT', 'FEATURE:DONATION'),
  ('CROWDFUNDING',                'CROWDFUNDINGMANAGEMENT', 'FEATURE:DONATION'),
  ('EVENTREG',                    'CROWDFUNDINGMANAGEMENT', 'FEATURE:EVENT'),
  ('EVENTREGPAGE',                'CROWDFUNDINGMANAGEMENT', 'FEATURE:EVENT'),

-- ── Grants ──────────────────────────────────────────────────────────────────────────
  ('CRM_GRANT',                   NULL,                     'FEATURE:GRANT'),
  ('GRANT',                       'CRM_GRANT',              'FEATURE:GRANT'),
  ('GRANTFORM',                   'CRM_GRANT',              'FEATURE:GRANT'),
  ('GRANTCALENDAR',               'CRM_GRANT',              'FEATURE:GRANT'),
  ('GRANTREPORTING',              'CRM_GRANT',              'FEATURE:GRANT'),

-- ── Case management ─────────────────────────────────────────────────────────────────
  ('CRM_CASEMANAGEMENT',          NULL,                     'FEATURE:CASE'),
  ('CASEDASHBOARD',               'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('PROGRAM',                     'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('PROGRAMFUNDALLOCATION',       'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('BENEFICIARYLIST',             'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('CASELIST',                    'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('BENEFICIARYFORM',             'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('BENEFICIARYHOUSEHOLDMEMBER',  'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('BENEFICIARYPROGRAMENROLLMENT','CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('BENEFICIARYMILESTONE',        'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('BENEFICIARYSERVICELOG',       'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('BENEFICIARYVERIFICATION',     'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('BENEFICIARYDOCUMENT',         'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('CASENOTE',                    'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('CASEACTIONITEM',              'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('CASEREFERRAL',                'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),
  ('CASEDOCUMENTS',               'CRM_CASEMANAGEMENT',     'FEATURE:CASE'),

-- ── Events ──────────────────────────────────────────────────────────────────────────
-- AUCTIONMANAGEMENT carries capabilities itself and also parents the five auction screens.
  ('CRM_EVENT',                   NULL,                     'FEATURE:EVENT'),
  ('EVENT',                       'CRM_EVENT',              'FEATURE:EVENT'),
  ('EVENTCQ',                     'CRM_EVENT',              'FEATURE:EVENT'),
  ('EVENTSETTING',                'CRM_EVENT',              'FEATURE:EVENT'),
  ('EVENTTICKET',                 'CRM_EVENT',              'FEATURE:EVENT'),
  ('EVENTTICKETTEMPLATE',         'CRM_EVENT',              'FEATURE:EVENT'),
  ('EVENTANALYTICS',              'CRM_EVENT',              'FEATURE:EVENT'),
  ('AUCTIONMANAGEMENT',           'CRM_EVENT',              'FEATURE:EVENT'),
  ('AUCTIONBID',                  'AUCTIONMANAGEMENT',      'FEATURE:EVENT'),
  ('AUCTIONITEM',                 'AUCTIONMANAGEMENT',      'FEATURE:EVENT'),
  ('EVENTAUCTION',                'AUCTIONMANAGEMENT',      'FEATURE:EVENT'),
  ('EVENTAUCTIONCONFIG',          'AUCTIONMANAGEMENT',      'FEATURE:EVENT'),
  ('AUCTIONWINNER',               'AUCTIONMANAGEMENT',      'FEATURE:EVENT'),

-- ── Volunteers ──────────────────────────────────────────────────────────────────────
  ('CRM_VOLUNTEER',               NULL,                     'FEATURE:VOLUNTEER'),
  ('VOLUNTEERLIST',               'CRM_VOLUNTEER',          'FEATURE:VOLUNTEER'),
  ('VOLUNTEERFORM',               'CRM_VOLUNTEER',          'FEATURE:VOLUNTEER'),
  ('VOLUNTEERSHIFT',              'CRM_VOLUNTEER',          'FEATURE:VOLUNTEER'),
  ('VOLUNTEERHOURTRACKING',       'CRM_VOLUNTEER',          'FEATURE:VOLUNTEER'),
  ('VOLUNTEERREGPAGE',            'CRM_VOLUNTEER',          'FEATURE:VOLUNTEER'),

-- ── Membership ──────────────────────────────────────────────────────────────────────
-- Three separate roots in the live tree, all sold together.
  ('CRM_MEMBERSHIP',              NULL,                     'FEATURE:MEMBERSHIP'),
  ('MEMBERLIST',                  'CRM_MEMBERSHIP',         'FEATURE:MEMBERSHIP'),
  ('MEMBERENROLLMENT',            'CRM_MEMBERSHIP',         'FEATURE:MEMBERSHIP'),
  ('MEMBERSHIPTIER',              'CRM_MEMBERSHIP',         'FEATURE:MEMBERSHIP'),
  ('MEMBERPORTAL',                'CRM_MEMBERSHIP',         'FEATURE:MEMBERSHIP'),
  ('MEMBERSHIPRENEWAL',           'CRM_MEMBERSHIP',         'FEATURE:MEMBERSHIP'),
  ('MEMBERSHIPTIERCONFIG',        'CRM_MEMBERSHIP',         'FEATURE:MEMBERSHIP'),

  ('MEMBERPORTAL_AREA',           NULL,                     'FEATURE:MEMBERSHIP'),
  ('MP_DASHBOARD',                'MEMBERPORTAL_AREA',      'FEATURE:MEMBERSHIP'),
  ('MP_PROFILE',                  'MEMBERPORTAL_AREA',      'FEATURE:MEMBERSHIP'),
  ('MP_BENEFITS',                 'MEMBERPORTAL_AREA',      'FEATURE:MEMBERSHIP'),
  ('MP_PAYMENTS',                 'MEMBERPORTAL_AREA',      'FEATURE:MEMBERSHIP'),
  ('MP_EVENTS',                   'MEMBERPORTAL_AREA',      'FEATURE:MEMBERSHIP'),

  ('MEMBERSHIPRENEWALCONFIG',     NULL,                     'FEATURE:MEMBERSHIP'),

-- ── Prayer requests ─────────────────────────────────────────────────────────────────
-- Two screens in the live tree - the seven-screen list in the old seed files never shipped.
  ('CRM_PRAYERREQUEST',           NULL,                     'FEATURE:PRAYERREQUEST'),
  ('PRAYERREQUESTS',              'CRM_PRAYERREQUEST',      'FEATURE:PRAYERREQUEST'),
  ('PRAYERREQUESTPAGE',           'CRM_PRAYERREQUEST',      'FEATURE:PRAYERREQUEST'),

-- ── Email ───────────────────────────────────────────────────────────────────────────
-- SAVEDFILTER and PLACEHOLDERDEFINITION only exist to serve the email composer, so they
-- follow the email channel rather than shipping with every plan.
  ('CRM_COMMUNICATION',           NULL,                     'CHANNEL:EMAIL'),
  ('EMAILTEMPLATE',               'CRM_COMMUNICATION',      'CHANNEL:EMAIL'),
  ('EMAILSENDJOB',                'CRM_COMMUNICATION',      'CHANNEL:EMAIL'),
  ('EMAILANALYTICS',              'CRM_COMMUNICATION',      'CHANNEL:EMAIL'),
  ('EMAILKEYWORD',                'CRM_COMMUNICATION',      'CHANNEL:EMAIL'),
  ('PLACEHOLDERDEFINITION',       'CRM_COMMUNICATION',      'CHANNEL:EMAIL'),
  ('SAVEDFILTER',                 'CRM_COMMUNICATION',      'CHANNEL:EMAIL'),

-- ── WhatsApp ────────────────────────────────────────────────────────────────────────
  ('CRM_WHATSAPP',                NULL,                     'CHANNEL:WHATSAPP'),
  ('WHATSAPPTEMPLATE',            'CRM_WHATSAPP',           'CHANNEL:WHATSAPP'),
  ('WHATSAPPCAMPAIGN',            'CRM_WHATSAPP',           'CHANNEL:WHATSAPP'),
  ('WHATSAPPCONVERSATION',        'CRM_WHATSAPP',           'CHANNEL:WHATSAPP'),
  ('WHATSAPPMESSAGE',             NULL,                     'CHANNEL:WHATSAPP'),

-- ── SMS ─────────────────────────────────────────────────────────────────────────────
  ('CRM_SMS',                     NULL,                     'CHANNEL:SMS'),
  ('SMSTEMPLATE',                 'CRM_SMS',                'CHANNEL:SMS'),
  ('SMSCAMPAIGN',                 'CRM_SMS',                'CHANNEL:SMS'),

-- ── In-app notifications ────────────────────────────────────────────────────────────
-- Product plumbing, not a sold channel. Every tenant gets it.
  ('CRM_NOTIFICATION',            NULL,                     NULL),
  ('NOTIFICATIONTEMPLATE',        'CRM_NOTIFICATION',       NULL),
  ('NOTIFICATION',                'CRM_NOTIFICATION',       NULL),

-- ── Automation ──────────────────────────────────────────────────────────────────────
  ('CRM_AUTOMATION',              NULL,                     'FEATURE:AUTOMATION'),
  ('AUTOMATIONWORKFLOW',          'CRM_AUTOMATION',         'FEATURE:AUTOMATION'),

-- ── Intelligence / AI ───────────────────────────────────────────────────────────────
  ('CRM_INTELLIGENCE',            NULL,                     'FEATURE:INTELLIGENCE'),
  ('ENGAGEMENTSCORING',           'CRM_INTELLIGENCE',       'FEATURE:INTELLIGENCE'),
  ('CHURNPREDICTION',             'CRM_INTELLIGENCE',       'FEATURE:INTELLIGENCE'),
  ('ACTIONBOARD',                 'CRM_INTELLIGENCE',       'FEATURE:INTELLIGENCE'),
  ('AIDRAFT',                     'CRM_INTELLIGENCE',       'FEATURE:INTELLIGENCE'),
  ('AIREPORTING',                 'CRM_INTELLIGENCE',       'FEATURE:INTELLIGENCE'),
  ('PREDICTIVEANALYTICS',         'CRM_INTELLIGENCE',       'FEATURE:INTELLIGENCE'),

-- ── Global search ───────────────────────────────────────────────────────────────────
  ('SEARCHABLEENTITY',            NULL,                     NULL),

-- ═══ MODULE: ORGANIZATION ════════════════════════════════════════════════════════════
-- The tenant's own identity and people. Never sold, never gated.
  ('ORG_COMPANY',                 NULL,                     NULL),
  ('COMPANY',                     'ORG_COMPANY',            NULL),
  ('BRANCH',                      'ORG_COMPANY',            NULL),

  ('ORG_STAFF',                   NULL,                     NULL),
  ('STAFF',                       'ORG_STAFF',              NULL),
  ('STAFFCATEGORY',               'ORG_STAFF',              NULL),

-- ═══ MODULE: ACCESSCONTROL ═══════════════════════════════════════════════════════════
-- A tenant admin must always be able to manage their own users and roles, on every plan.
-- ROLEMANAGEMENT carries capabilities itself and also parents ROLE / CAPABILITY.
  ('AC_USERSROLES',               NULL,                     NULL),
  ('ROLEMANAGEMENT',              'AC_USERSROLES',          NULL),
  ('ROLE',                        'ROLEMANAGEMENT',         NULL),
  ('CAPABILITY',                  'ROLEMANAGEMENT',         NULL),
  ('USER',                        'AC_USERSROLES',          NULL),
  ('ROLECAPABILITY',              'AC_USERSROLES',          NULL),
  ('USERROLE',                    'AC_USERSROLES',          NULL),
  ('WIDGETROLE',                  'AC_USERSROLES',          NULL),

  ('AC_GOVERNANCE',               NULL,                     NULL),
  ('MENU',                        'AC_GOVERNANCE',          NULL),
  ('MODULE',                      'AC_GOVERNANCE',          NULL),

-- ═══ MODULE: SETTING ═════════════════════════════════════════════════════════════════

-- ── General masters ─────────────────────────────────────────────────────────────────
  ('GEN_MASTERS',                 NULL,                     NULL),
  ('CURRENCY',                    'GEN_MASTERS',            NULL),
  ('CURRENCYCONVERSION',          'GEN_MASTERS',            NULL),
  ('BANK',                        'GEN_MASTERS',            NULL),
  ('GENDER',                      'GEN_MASTERS',            NULL),
  ('SALUTATION',                  'GEN_MASTERS',            NULL),
  ('BLOODGROUP',                  'GEN_MASTERS',            NULL),
  ('LANGUAGE',                    'GEN_MASTERS',            NULL),
  ('OCCUPATION',                  'GEN_MASTERS',            NULL),
  ('RELATION',                    'GEN_MASTERS',            NULL),
  ('PAYMENTMODE',                 'GEN_MASTERS',            NULL),

-- ── Region masters ──────────────────────────────────────────────────────────────────
  ('GEN_REGION',                  NULL,                     NULL),
  ('COUNTRY',                     'GEN_REGION',             NULL),
  ('STATE',                       'GEN_REGION',             NULL),
  ('DISTRICT',                    'GEN_REGION',             NULL),
  ('CITY',                        'GEN_REGION',             NULL),
  ('PINCODE',                     'GEN_REGION',             NULL),
  ('LOCALITY',                    'GEN_REGION',             NULL),
  ('NATIONALITY',                 NULL,                     NULL),

-- ── Organization settings ───────────────────────────────────────────────────────────
  ('SET_ORGSETTINGS',             NULL,                     NULL),
  ('COMPANYSETTINGS',             'SET_ORGSETTINGS',        NULL),
  ('SETTINGGROUP',                'SET_ORGSETTINGS',        NULL),
  ('ORGANIZATIONSETTING',         'SET_ORGSETTINGS',        NULL),
  ('USERSETTING',                 'SET_ORGSETTINGS',        NULL),

-- ── Payment configuration ───────────────────────────────────────────────────────────
-- Ungated on purpose: a tenant that cannot reach its gateway config cannot take money,
-- and that would break the pay-for-your-plan path too.
  ('SET_PAYMENTCONFIG',           NULL,                     NULL),
  ('COMPANYPAYMENTGATEWAY',       'SET_PAYMENTCONFIG',      NULL),
  ('PAYMENTGATEWAY',              'SET_PAYMENTCONFIG',      NULL),
  ('ORGANIZATIONBANKACCOUNT',     'SET_PAYMENTCONFIG',      NULL),

-- ── Donation configuration ──────────────────────────────────────────────────────────
-- Receipts and tax certificates only make sense with donations, so the whole branch is
-- gated on it. RECEIPTMANAGEMENT is a screen and a parent at the same time.
  ('SET_DONATIONCONFIG',          NULL,                     'FEATURE:DONATION'),
  ('DONATIONVERSE',               'SET_DONATIONCONFIG',     'FEATURE:DONATION'),
  ('RECEIPTMANAGEMENT',           'SET_DONATIONCONFIG',     'FEATURE:DONATION'),
  ('RECEIPTTEMPLATE',             'RECEIPTMANAGEMENT',      'FEATURE:DONATION'),
  ('COUNTRYTAXCONFIG',            'RECEIPTMANAGEMENT',      'FEATURE:DONATION'),
  ('GLOBALRECEIPTSETTING',        'RECEIPTMANAGEMENT',      'FEATURE:DONATION'),
  ('GENERATEDTAXRECEIPT',         'RECEIPTMANAGEMENT',      'FEATURE:DONATION'),

-- ── Communication configuration ─────────────────────────────────────────────────────
-- Mixed group: each provider setup screen follows its own channel.
  ('SET_COMMUNICATIONCONFIG',     NULL,                     NULL),
  ('COMPANYEMAILCONFIGURATION',   'SET_COMMUNICATIONCONFIG','CHANNEL:EMAIL'),
  ('COMPANYEMAILPROVIDER',        'SET_COMMUNICATIONCONFIG','CHANNEL:EMAIL'),
  ('WHATSAPPSETUP',               'SET_COMMUNICATIONCONFIG','CHANNEL:WHATSAPP'),
  ('SMSSETUP',                    'SET_COMMUNICATIONCONFIG','CHANNEL:SMS'),

-- ── Data configuration ──────────────────────────────────────────────────────────────
  ('SET_DATACONFIG',              NULL,                     NULL),
  ('MASTERDATA',                  'SET_DATACONFIG',         NULL),
  ('MASTERDATATYPE',              'SET_DATACONFIG',         NULL),
  ('REGIONHIERARCHY',             'SET_DATACONFIG',         NULL),

-- ── Grid / field configuration ──────────────────────────────────────────────────────
  ('SET_GRIDMANAGEMENT',          NULL,                     NULL),
  ('GRID',                        'SET_GRIDMANAGEMENT',     NULL),
  ('FIELD_SETTING',               'SET_GRIDMANAGEMENT',     NULL),
  ('CUSTOMFIELDS',                'SET_GRIDMANAGEMENT',     NULL),

-- ── Dashboards and widgets ──────────────────────────────────────────────────────────
  ('SET_DASHBOARDWIDGET',         NULL,                     NULL),
  ('DASHBOARD',                   'SET_DASHBOARDWIDGET',    NULL),
  ('DASHBOARDLAYOUT',             'SET_DASHBOARDWIDGET',    NULL),
  ('WIDGET',                      'SET_DASHBOARDWIDGET',    NULL),
  ('WIDGETTYPE',                  'SET_DASHBOARDWIDGET',    NULL),
  ('WIDGETPROPERTY',              'SET_DASHBOARDWIDGET',    NULL),

-- ── Integrations ────────────────────────────────────────────────────────────────────
  ('SET_INTEGRATION',             NULL,                     'FEATURE:INTEGRATION'),
  ('ACCOUNTINGINTEGRATION',       'SET_INTEGRATION',        'FEATURE:INTEGRATION'),
  ('SOCIALMEDIAINTEGRATION',      'SET_INTEGRATION',        'FEATURE:INTEGRATION'),
  ('APIMANAGEMENT',               'SET_INTEGRATION',        'FEATURE:INTEGRATION'),
  ('INTEGRATIONMARKETPLACE',      'SET_INTEGRATION',        'FEATURE:INTEGRATION'),

-- ── Documents ───────────────────────────────────────────────────────────────────────
-- Mixed group: document types are generic, the certificate template config is donation
-- machinery.
  ('SET_DOCUMENT',                NULL,                     NULL),
  ('DOCUMENTTYPE',                'SET_DOCUMENT',           NULL),
  ('CERTIFICATETEMPLATECONFIG',   'SET_DOCUMENT',           'FEATURE:DONATION'),

-- ── Billing ─────────────────────────────────────────────────────────────────────────
-- Force-allowed by the code below in any case; listed so Result 2 stays quiet.
  ('BILLING',                     NULL,                     NULL),
  ('BILLING_OVERVIEW',            'BILLING',                NULL),
  ('BILLING_PLANS',               'BILLING',                NULL),
  ('BILLING_INVOICES',            'BILLING',                NULL),

-- ═══ MODULE: REPORTAUDIT ═════════════════════════════════════════════════════════════
-- Mixed group: the catalog, the fundraising summary and the basic generator ship with
-- every plan; the builder, the retention view, scheduling, HTML output and Power BI do not.
  ('RA_REPORTS',                  NULL,                     NULL),
  ('REPORTCATALOG',               'RA_REPORTS',             NULL),
  ('FUNDRAISINGSUMMARY',          'RA_REPORTS',             NULL),
  ('GENERATEREPORT',              'RA_REPORTS',             NULL),
  ('HTMLREPORT',                  'RA_REPORTS',             'FEATURE:ADVANCEDREPORTING'),
  ('CUSTOMREPORTBUILDER',         'RA_REPORTS',             'FEATURE:ADVANCEDREPORTING'),
  ('RETENTIONDASHBOARD',          'RA_REPORTS',             'FEATURE:ADVANCEDREPORTING'),
  ('SCHEDULEDREPORT',             'RA_REPORTS',             'FEATURE:ADVANCEDREPORTING'),
  ('POWERBIREPORT',               'RA_REPORTS',             'FEATURE:POWERBI'),

  ('RA_REPORTSETUP',              NULL,                     'FEATURE:POWERBI'),
  ('POWERBIREPORTMASTER',         'RA_REPORTSETUP',         'FEATURE:POWERBI'),
  ('POWERBIUSERMAPPING',          'RA_REPORTSETUP',         'FEATURE:POWERBI'),

  ('RA_AUDIT',                    NULL,                     NULL),
  ('AUDITTRAIL',                  'RA_AUDIT',               NULL);

-- ═══ MODULE: PLATFORM - deliberately absent ══════════════════════════════════════════
-- PLATFORMCONTROLPLANE and every PLATFORM_* screen belong to the control plane, never to
-- a tenant. Section 2d blocks the whole module regardless; listing them here would only
-- create a chance of granting them by accident.

-- NOTE on BILLING menus. Any menu code starting with BILLING is force-allowed by the code
-- below even when it is not in the list above - a lapsed tenant must always reach the pay
-- screen (same invariant as FeatureCodeRules.IsProtectedMenuCode). The UNLISTED lines in
-- Result 2 will show you the real BILLING codes so you can add them here by hand.
--
-- BILLING is also the ONE exception to the leaves-only rule in section 3c. 'BILLING' itself is
-- IsLeastMenu = false, but every tenant billing handler is gated on that exact parent code
-- ([CustomAuthorize("BILLING", "BILLING_VIEW" | "BILLING_MANAGE")]) and HasAccessAsync matches
-- MenuCode exactly - so the group menu needs real cells or the tenant sees the nav and gets a
-- 403 from every call behind it. See the comment at the SKIP-GROUP branch.

-- ═════════════════════════════════════════════════════════════════════════════════════
--  Working tables
-- ═════════════════════════════════════════════════════════════════════════════════════

-- Listed codes that resolved to a usable live menu, with the leaf flag as the DB has it.
-- Column types are taken from the menu table itself, so nothing here guesses the MenuId
-- type.
CREATE TEMP TABLE tmp_menu_ok AS
SELECT m."MenuId", upper(m."MenuCode") AS menu_code, true AS is_leaf
FROM   auth."Menus" m
WHERE  false;

-- One row per (plan, listed menu) verdict.
CREATE TEMP TABLE tmp_decision (
    plan_id   int,
    menu_code text,
    allowed   boolean,
    reason    text,
    PRIMARY KEY (plan_id, menu_code)
);

-- The cells this run decided the plan sells. Types inherited from the destination table.
CREATE TEMP TABLE tmp_baseline_target AS
SELECT b."PlanId", b."MenuId", b."CapabilityId"
FROM   billing."PlanRoleBaselines" b
WHERE  false;

CREATE TEMP TABLE tmp_baseline_report (
    plan_code text,
    menu_code text,
    decision  text,   -- ALLOW / BLOCK / SKIP / SKIP-GROUP / MISSING / BAD-PARENT /
                      -- UNKNOWN-FEATURE / UNLISTED
    reason    text,
    cells     int
);

CREATE TEMP TABLE tmp_plans_in_scope ("PlanId" int PRIMARY KEY);

-- ═════════════════════════════════════════════════════════════════════════════════════
--  SECTION 2 - CHECK THE LIST, ONE CODE AT A TIME
-- ═════════════════════════════════════════════════════════════════════════════════════

DO $validate$
DECLARE
    v_row         record;
    v_menu        record;
    v_live        record;
    v_module_code text;
BEGIN

FOR v_row IN SELECT menu_code, parent_code, feature_code
             FROM   tmp_menu_grant
             ORDER  BY COALESCE(parent_code, menu_code), menu_code
LOOP
    -- 2a. the parent must be listed too, otherwise the cascade cannot be evaluated.
    IF v_row.parent_code IS NOT NULL THEN
        PERFORM 1 FROM tmp_menu_grant WHERE menu_code = v_row.parent_code;
        IF NOT FOUND THEN
            INSERT INTO tmp_baseline_report VALUES
                (NULL, v_row.menu_code, 'BAD-PARENT',
                 'parent ' || v_row.parent_code || ' is not in the list', 0);
            RAISE NOTICE 'BAD-PARENT: % -> %', v_row.menu_code, v_row.parent_code;
        END IF;
    END IF;

    -- 2b. the feature must exist in the catalogue.
    IF v_row.feature_code IS NOT NULL THEN
        PERFORM 1 FROM billing."Features" f
        WHERE  upper(f."FeatureCode") = upper(v_row.feature_code)
          AND  f."IsDeleted" IS DISTINCT FROM true;
        IF NOT FOUND THEN
            INSERT INTO tmp_baseline_report VALUES
                (NULL, v_row.menu_code, 'UNKNOWN-FEATURE',
                 v_row.feature_code || ' is not in billing."Features" - the menu is still '
                 || 'decided by billing."PlanEntitlements"', 0);
            RAISE NOTICE 'UNKNOWN-FEATURE: % on %', v_row.feature_code, v_row.menu_code;
        END IF;
    END IF;

    -- 2c. resolve the menu row itself.
    SELECT m."MenuId", m."ModuleId",
           m."IsActive"    AS is_active,
           m."IsDeleted"   AS is_deleted,
           m."IsLeastMenu" AS is_leaf
    INTO   v_menu
    FROM   auth."Menus" m
    WHERE  upper(m."MenuCode") = v_row.menu_code;

    IF NOT FOUND THEN
        INSERT INTO tmp_baseline_report VALUES
            (NULL, v_row.menu_code, 'MISSING', 'no such menu code in auth."Menus"', 0);
        RAISE NOTICE 'MISSING menu code %', v_row.menu_code;
        CONTINUE;
    END IF;

    IF v_menu.is_deleted IS NOT DISTINCT FROM true THEN
        INSERT INTO tmp_baseline_report VALUES
            (NULL, v_row.menu_code, 'SKIP', 'menu is deleted', 0);
        CONTINUE;
    END IF;

    IF v_menu.is_active IS NOT DISTINCT FROM false THEN
        INSERT INTO tmp_baseline_report VALUES
            (NULL, v_row.menu_code, 'SKIP', 'menu is inactive', 0);
        CONTINUE;
    END IF;

    -- 2d. control-plane menus never belong to a tenant baseline.
    v_module_code := NULL;
    SELECT upper(md."ModuleCode") INTO v_module_code
    FROM   auth."Modules" md
    WHERE  md."ModuleId" = v_menu."ModuleId";

    IF v_module_code = 'PLATFORM' THEN
        INSERT INTO tmp_baseline_report VALUES
            (NULL, v_row.menu_code, 'SKIP', 'control-plane menu (PLATFORM module)', 0);
        CONTINUE;
    END IF;

    -- The leaf flag is read from the DB, never assumed from the shape of the list above.
    INSERT INTO tmp_menu_ok ("MenuId", menu_code, is_leaf)
    VALUES (v_menu."MenuId", v_row.menu_code, v_menu.is_leaf IS NOT DISTINCT FROM true);
END LOOP;

-- 2e. Live tenant LEAF menus the list does not mention. They get NO baseline cell. This is
--     the "what did I forget" list - read it after every run. Group menus are not reported
--     here because they carry no capabilities and so can never be granted anyway.
--     BILLING is the one exception: it is auto-granted, because a lapsed tenant must reach
--     the pay screen.
FOR v_live IN SELECT m."MenuId", upper(m."MenuCode") AS menu_code, m."ModuleId"
              FROM   auth."Menus" m
              WHERE  m."IsDeleted"   IS DISTINCT FROM true
                AND  m."IsActive"    IS DISTINCT FROM false
                AND  m."IsLeastMenu" = true
              ORDER  BY upper(m."MenuCode")
LOOP
    PERFORM 1 FROM tmp_menu_grant WHERE menu_code = v_live.menu_code;
    CONTINUE WHEN FOUND;

    v_module_code := NULL;
    SELECT upper(md."ModuleCode") INTO v_module_code
    FROM   auth."Modules" md
    WHERE  md."ModuleId" = v_live."ModuleId";

    CONTINUE WHEN v_module_code = 'PLATFORM';

    IF v_live.menu_code LIKE 'BILLING%' THEN
        INSERT INTO tmp_menu_grant (menu_code, parent_code, feature_code)
        VALUES (v_live.menu_code, NULL, NULL);

        INSERT INTO tmp_menu_ok ("MenuId", menu_code, is_leaf)
        VALUES (v_live."MenuId", v_live.menu_code, true);

        INSERT INTO tmp_baseline_report VALUES
            (NULL, v_live.menu_code, 'UNLISTED',
             'billing menu - auto-granted, never plan-gated. Add it to the list.', 0);
    ELSE
        INSERT INTO tmp_baseline_report VALUES
            (NULL, v_live.menu_code, 'UNLISTED',
             'live leaf menu is not in the list - no baseline cell was written for it', 0);
        RAISE NOTICE 'UNLISTED leaf menu %', v_live.menu_code;
    END IF;
END LOOP;

END
$validate$;

-- ═════════════════════════════════════════════════════════════════════════════════════
--  SECTION 3 - DECIDE AND WRITE, ONE MENU AND ONE CAPABILITY AT A TIME
-- ═════════════════════════════════════════════════════════════════════════════════════

DO $generate$
DECLARE
    v_plan     record;
    v_item     record;
    v_dec      record;
    v_cap      record;
    v_caprow   record;
    v_row      record;

    v_menu_id       auth."Menus"."MenuId"%TYPE;
    v_is_leaf       boolean;
    v_parent_allow  boolean;
    v_allowed       boolean;
    v_entitled      boolean;
    v_reason        text;
    v_menu_cells    int;
    v_plan_cells    int;
    v_written       int := 0;
    v_deleted       int := 0;
BEGIN

FOR v_plan IN SELECT p."PlanId", p."PlanCode"
              FROM   billing."Plans" p
              WHERE  p."IsDeleted" IS DISTINCT FROM true
              ORDER  BY p."PlanId"
LOOP
    v_plan_cells := 0;
    RAISE NOTICE '--- plan % ---------------------------------------------', v_plan."PlanCode";

    -- ── 3a. Top-level groups first ──────────────────────────────────────────────────
    FOR v_item IN SELECT menu_code, feature_code
                  FROM   tmp_menu_grant
                  WHERE  parent_code IS NULL
                  ORDER  BY menu_code
    LOOP
        IF v_item.menu_code LIKE 'BILLING%' THEN
            v_allowed := true;
            v_reason  := 'billing menu - never plan-gated';
        ELSIF v_item.feature_code IS NULL THEN
            v_allowed := true;
            v_reason  := 'not plan-gated';
        ELSE
            SELECT EXISTS (
                SELECT 1 FROM billing."PlanEntitlements" e
                WHERE  e."PlanId" = v_plan."PlanId"
                  AND  upper(e."FeatureCode") = upper(v_item.feature_code)
                  AND  e."IsDeleted" IS DISTINCT FROM true
                  AND  e."IsEnabled" = true)
            INTO v_entitled;

            v_allowed := v_entitled;
            v_reason  := CASE WHEN v_entitled
                              THEN 'plan buys ' || v_item.feature_code
                              ELSE 'plan does not buy ' || v_item.feature_code END;
        END IF;

        INSERT INTO tmp_decision (plan_id, menu_code, allowed, reason)
        VALUES (v_plan."PlanId", v_item.menu_code, v_allowed, v_reason);
    END LOOP;

    -- ── 3b. Children, using the parent verdict just written ─────────────────────────
    --     Two passes: direct children of a root first, then the sub-group children
    --     (TAG / AUCTION* / MATCHING* / RECEIPT* / MP_* etc.), so a sub-group's own
    --     verdict is always decided before its children read it.
    FOR v_item IN SELECT g.menu_code, g.parent_code, g.feature_code
                  FROM   tmp_menu_grant g
                  JOIN   tmp_menu_grant p ON p.menu_code = g.parent_code
                  WHERE  g.parent_code IS NOT NULL
                    AND  p.parent_code IS NULL
                  ORDER  BY g.parent_code, g.menu_code
    LOOP
        v_parent_allow := NULL;
        SELECT d.allowed INTO v_parent_allow
        FROM   tmp_decision d
        WHERE  d.plan_id = v_plan."PlanId" AND d.menu_code = v_item.parent_code;

        -- blocking a parent has to cascade, or the child stays reachable by deep link.
        IF v_parent_allow IS NOT DISTINCT FROM false THEN
            INSERT INTO tmp_decision (plan_id, menu_code, allowed, reason)
            VALUES (v_plan."PlanId", v_item.menu_code, false,
                    'parent ' || v_item.parent_code || ' is blocked');
            CONTINUE;
        END IF;

        IF v_item.menu_code LIKE 'BILLING%' THEN
            v_allowed := true;
            v_reason  := 'billing menu - never plan-gated';
        ELSIF v_item.feature_code IS NULL THEN
            v_allowed := true;
            v_reason  := 'not plan-gated';
        ELSE
            SELECT EXISTS (
                SELECT 1 FROM billing."PlanEntitlements" e
                WHERE  e."PlanId" = v_plan."PlanId"
                  AND  upper(e."FeatureCode") = upper(v_item.feature_code)
                  AND  e."IsDeleted" IS DISTINCT FROM true
                  AND  e."IsEnabled" = true)
            INTO v_entitled;

            v_allowed := v_entitled;
            v_reason  := CASE WHEN v_entitled
                              THEN 'plan buys ' || v_item.feature_code
                              ELSE 'plan does not buy ' || v_item.feature_code END;
        END IF;

        INSERT INTO tmp_decision (plan_id, menu_code, allowed, reason)
        VALUES (v_plan."PlanId", v_item.menu_code, v_allowed, v_reason);
    END LOOP;

    -- second pass: everything still undecided, i.e. children of a sub-group.
    FOR v_item IN SELECT g.menu_code, g.parent_code, g.feature_code
                  FROM   tmp_menu_grant g
                  WHERE  g.parent_code IS NOT NULL
                    AND  NOT EXISTS (SELECT 1 FROM tmp_decision d
                                     WHERE d.plan_id = v_plan."PlanId"
                                       AND d.menu_code = g.menu_code)
                  ORDER  BY g.parent_code, g.menu_code
    LOOP
        v_parent_allow := NULL;
        SELECT d.allowed INTO v_parent_allow
        FROM   tmp_decision d
        WHERE  d.plan_id = v_plan."PlanId" AND d.menu_code = v_item.parent_code;

        IF v_parent_allow IS NOT DISTINCT FROM false THEN
            INSERT INTO tmp_decision (plan_id, menu_code, allowed, reason)
            VALUES (v_plan."PlanId", v_item.menu_code, false,
                    'parent ' || v_item.parent_code || ' is blocked');
            CONTINUE;
        END IF;

        IF v_item.menu_code LIKE 'BILLING%' THEN
            v_allowed := true;
            v_reason  := 'billing menu - never plan-gated';
        ELSIF v_item.feature_code IS NULL THEN
            v_allowed := true;
            v_reason  := 'not plan-gated';
        ELSE
            SELECT EXISTS (
                SELECT 1 FROM billing."PlanEntitlements" e
                WHERE  e."PlanId" = v_plan."PlanId"
                  AND  upper(e."FeatureCode") = upper(v_item.feature_code)
                  AND  e."IsDeleted" IS DISTINCT FROM true
                  AND  e."IsEnabled" = true)
            INTO v_entitled;

            v_allowed := v_entitled;
            v_reason  := CASE WHEN v_entitled
                              THEN 'plan buys ' || v_item.feature_code
                              ELSE 'plan does not buy ' || v_item.feature_code END;
        END IF;

        INSERT INTO tmp_decision (plan_id, menu_code, allowed, reason)
        VALUES (v_plan."PlanId", v_item.menu_code, v_allowed, v_reason);
    END LOOP;

    -- ── 3c. Turn every ALLOW into cells, one capability at a time - LEAVES ONLY ──────
    FOR v_dec IN SELECT d.menu_code, d.allowed, d.reason
                 FROM   tmp_decision d
                 WHERE  d.plan_id = v_plan."PlanId"
                 ORDER  BY d.menu_code
    LOOP
        IF NOT v_dec.allowed THEN
            INSERT INTO tmp_baseline_report VALUES
                (v_plan."PlanCode", v_dec.menu_code, 'BLOCK', v_dec.reason, 0);
            CONTINUE;
        END IF;

        -- the menu must have survived section 2.
        v_menu_id := NULL;
        v_is_leaf := NULL;
        SELECT o."MenuId", o.is_leaf INTO v_menu_id, v_is_leaf
        FROM   tmp_menu_ok o
        WHERE  o.menu_code = v_dec.menu_code;

        CONTINUE WHEN v_menu_id IS NULL;   -- already reported in section 2

        -- A parent / group menu has no capability rows, so it never gets a baseline row.
        -- It stays in the list only so its verdict can cascade to the leaves above.
        --
        -- BILLING IS THE EXCEPTION, AND IT IS LOAD-BEARING.
        -- 'BILLING' (MenuId 555) is IsLeastMenu = false, so the rule above would skip it - but
        -- CustomAuthorizeService.HasAccessAsync matches MenuCode EXACTLY, and every tenant
        -- billing handler is gated on the PARENT code:
        --     [CustomAuthorize("BILLING", "BILLING_VIEW")]    GetMySellablePlans /
        --                                                     GetMyBillingOverview / GetTenantInvoices
        --     [CustomAuthorize("BILLING", "BILLING_MANAGE")]  InitiateSubscriptionCheckout /
        --                                                     ConfirmSubscriptionPayment / SetAutoRenew
        -- Skipping the group here left a newly provisioned tenant with cells on the three leaves
        -- (so the nav rendered) and NO cell on 'BILLING' itself - the plans list came back empty
        -- and checkout returned "User is unauthorized to perform this action on the specified
        -- resource." billing-capability-seed.sql masked this for tenants that already existed when
        -- it was last run; every tenant provisioned afterwards got nothing.
        -- auth."MenuCapabilities" already carries BILLING_VIEW / BILLING_MANAGE / ISMENURENDER on
        -- MenuId 555 (billing-capability-seed.sql section 3), so the cell loop below has real work.
        -- The C# PlanBaselineGenerator has no leaf filter at all and always emitted this cell -
        -- this change removes that divergence rather than introducing one.
        IF v_is_leaf IS DISTINCT FROM true AND v_dec.menu_code NOT LIKE 'BILLING%' THEN
            INSERT INTO tmp_baseline_report VALUES
                (v_plan."PlanCode", v_dec.menu_code, 'SKIP-GROUP',
                 'group menu (IsLeastMenu = false) - carries no capabilities', 0);
            CONTINUE;
        END IF;

        v_menu_cells := 0;

        FOR v_cap IN SELECT DISTINCT mc."CapabilityId"
                     FROM   auth."MenuCapabilities" mc
                     WHERE  mc."MenuId"    = v_menu_id
                       AND  mc."IsDeleted" IS DISTINCT FROM true
                       AND  mc."IsActive"  IS DISTINCT FROM false
        LOOP
            SELECT c."IsActive" AS is_active, c."IsDeleted" AS is_deleted,
                   upper(c."CapabilityCode") AS cap_code
            INTO   v_caprow
            FROM   auth."Capabilities" c
            WHERE  c."CapabilityId" = v_cap."CapabilityId";

            CONTINUE WHEN NOT FOUND;
            CONTINUE WHEN v_caprow.is_deleted IS NOT DISTINCT FROM true;
            CONTINUE WHEN v_caprow.is_active  IS NOT DISTINCT FROM false;

            -- Only reachable for the BILLING group exception above. A group menu must never carry
            -- ISMENURENDER: GetParentChildMenuHandler walks parents up from authorized LEAVES, so
            -- the "Billing" header appears on its own, and granting render on the header itself
            -- would leave an empty label behind if every leaf were later revoked. Same rule as
            -- billing-capability-seed.sql section 4. The API grants (BILLING_VIEW / BILLING_MANAGE)
            -- still land, which is the whole point of the exception.
            CONTINUE WHEN v_is_leaf IS DISTINCT FROM true AND v_caprow.cap_code = 'ISMENURENDER';

            INSERT INTO tmp_baseline_target ("PlanId", "MenuId", "CapabilityId")
            VALUES (v_plan."PlanId", v_menu_id, v_cap."CapabilityId");

            v_menu_cells := v_menu_cells + 1;
        END LOOP;

        v_plan_cells := v_plan_cells + v_menu_cells;

        INSERT INTO tmp_baseline_report VALUES
            (v_plan."PlanCode", v_dec.menu_code,
             CASE WHEN v_menu_cells = 0 THEN 'SKIP' ELSE 'ALLOW' END,
             CASE WHEN v_menu_cells = 0
                  THEN 'leaf menu, allowed, but it has no active capability grid'
                  ELSE v_dec.reason END,
             v_menu_cells);
    END LOOP;

    -- A plan that produced nothing is SKIPPED, not emptied.
    IF v_plan_cells > 0 THEN
        INSERT INTO tmp_plans_in_scope ("PlanId") VALUES (v_plan."PlanId");
        RAISE NOTICE 'plan % -> % cells', v_plan."PlanCode", v_plan_cells;
    ELSE
        RAISE NOTICE 'plan % -> 0 cells, SKIPPED (existing baseline left untouched)',
                     v_plan."PlanCode";
    END IF;
END LOOP;

-- ── 3d. Write each wanted cell: revive the row if it is already there, else insert ──
--     The unique index ignores IsDeleted, so a soft-deleted row must be revived - a plain
--     insert would collide instead of adding.
FOR v_row IN SELECT t."PlanId", t."MenuId", t."CapabilityId"
             FROM   tmp_baseline_target t
             WHERE  t."PlanId" IN (SELECT "PlanId" FROM tmp_plans_in_scope)
LOOP
    UPDATE billing."PlanRoleBaselines"
    SET    "HasAccess"    = true,
           "IsActive"     = true,
           "IsDeleted"    = false,
           "ModifiedDate" = now()
    WHERE  "PlanId"          = v_row."PlanId"
      AND  upper("RoleCode") = 'BUSINESSADMIN'
      AND  "MenuId"          = v_row."MenuId"
      AND  "CapabilityId"    = v_row."CapabilityId"
      AND  ("IsDeleted" = true OR "HasAccess" = false OR "IsActive" IS DISTINCT FROM true);

    IF NOT FOUND THEN
        PERFORM 1 FROM billing."PlanRoleBaselines"
        WHERE  "PlanId"          = v_row."PlanId"
          AND  upper("RoleCode") = 'BUSINESSADMIN'
          AND  "MenuId"          = v_row."MenuId"
          AND  "CapabilityId"    = v_row."CapabilityId";

        IF NOT FOUND THEN
            INSERT INTO billing."PlanRoleBaselines"
                   ("PlanId", "RoleCode", "MenuId", "CapabilityId", "HasAccess",
                    "IsActive", "IsDeleted", "CreatedDate")
            VALUES (v_row."PlanId", 'BUSINESSADMIN', v_row."MenuId", v_row."CapabilityId", true,
                    true, false, now());
            v_written := v_written + 1;
        END IF;
    ELSE
        v_written := v_written + 1;
    END IF;
END LOOP;

-- ═════════════════════════════════════════════════════════════════════════════════════
--  SECTION 4 - REMOVE THE CELLS THE PLAN NO LONGER SELLS, ONE AT A TIME
--  This is what clears out the old group-menu rows. Hard delete on purpose - see the
--  header. Only plans that produced cells are touched.
-- ═════════════════════════════════════════════════════════════════════════════════════
FOR v_row IN SELECT b."PlanId", b."MenuId", b."CapabilityId"
             FROM   billing."PlanRoleBaselines" b
             WHERE  upper(b."RoleCode") = 'BUSINESSADMIN'
               AND  b."PlanId" IN (SELECT "PlanId" FROM tmp_plans_in_scope)
LOOP
    PERFORM 1 FROM tmp_baseline_target t
    WHERE  t."PlanId"       = v_row."PlanId"
      AND  t."MenuId"       = v_row."MenuId"
      AND  t."CapabilityId" = v_row."CapabilityId";

    IF NOT FOUND THEN
        DELETE FROM billing."PlanRoleBaselines"
        WHERE  "PlanId"          = v_row."PlanId"
          AND  upper("RoleCode") = 'BUSINESSADMIN'
          AND  "MenuId"          = v_row."MenuId"
          AND  "CapabilityId"    = v_row."CapabilityId";

        v_deleted := v_deleted + 1;
    END IF;
END LOOP;

RAISE NOTICE 'written/revived: %  hard-deleted: %', v_written, v_deleted;

END
$generate$;

COMMIT;

-- Result 1. Every plan you intend to sell must appear here with BUSINESSADMIN and a
-- non-zero count, or ProvisionTenant Step 3 and Step 4a both throw
-- "Plan 'X' has no RBAC baseline configured".
-- "leaf_menus" must equal "menus" - a group menu in the baseline is a bug.
SELECT p."PlanCode",
       b."RoleCode",
       count(b.*)                                              AS cells,
       count(DISTINCT b."MenuId")                              AS menus,
       count(DISTINCT b."MenuId") FILTER (WHERE m."IsLeastMenu" = true) AS leaf_menus
FROM   billing."Plans" p
LEFT   JOIN billing."PlanRoleBaselines" b
       ON b."PlanId" = p."PlanId" AND b."IsDeleted" IS DISTINCT FROM true AND b."HasAccess" = true
LEFT   JOIN auth."Menus" m ON m."MenuId" = b."MenuId"
WHERE  p."IsDeleted" IS DISTINCT FROM true
GROUP  BY 1, 2
ORDER  BY 1, 2;

-- Result 2. Everything that is not a plain ALLOW.
--   MISSING / BAD-PARENT / UNKNOWN-FEATURE -> fix the list in section 1.
--   UNLISTED   -> a live LEAF menu nobody granted. Decide what sells it and add it.
--   SKIP-GROUP -> working as designed: a group menu carries no capabilities.
--   SKIP       -> the menu is deleted, inactive, control-plane, or has no capability grid.
--   BLOCK      -> working as designed. Read the reason.
SELECT COALESCE(plan_code, '(list check)') AS plan,
       decision, menu_code, reason, cells
FROM   tmp_baseline_report
WHERE  decision <> 'ALLOW'
ORDER  BY plan, decision, menu_code;

-- Result 3. Per-plan summary of the same decisions.
SELECT COALESCE(plan_code, '(list check)') AS plan,
       decision,
       count(*)   AS menus,
       sum(cells) AS cells
FROM   tmp_baseline_report
GROUP  BY 1, 2
ORDER  BY 1, 2;

DROP TABLE tmp_menu_grant;
DROP TABLE tmp_menu_ok;
DROP TABLE tmp_decision;
DROP TABLE tmp_baseline_target;
DROP TABLE tmp_baseline_report;
DROP TABLE tmp_plans_in_scope;
