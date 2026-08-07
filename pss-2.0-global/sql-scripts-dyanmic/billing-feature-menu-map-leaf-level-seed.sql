-- =====================================================================================
--  billing-feature-menu-map-leaf-level-seed.sql
--
--  Rewrites billing."FeatureMenuMaps" at LEAF-MENU level.
--
--  WHY THIS FILE EXISTS
--    The earlier map (billing-feature-menu-map-complete-seed.sql) only listed the PARENT
--    menu group - CRM_CONTACT, CRM_FAMILY, CRM_MAINTENANCE - on the assumption that the
--    children cascade. They do not. The "Menus unlocked by Contacts" dialog reads every
--    leaf (auth."Menus"."IsLeastMenu" = true) straight out of this table, so the leaves
--    showed as unticked and the footer said "3 menus mapped".
--
--    This file maps every leaf explicitly. The parent group row is kept as well, so the
--    group header itself disappears when the feature is not sold.
--
--  WHAT A ROW MEANS
--    "This menu is SOLD as part of this feature."
--    A menu with NO row is ALWAYS VISIBLE - absence means "everyone gets it", never
--    "blocked". A missing row is safe; a wrong row hides a screen.
--    Hiding is COSMETIC. [RequiresFeature] on the resolver is the real security control.
--    The map is not per-plan: it applies to every plan that has the feature ticked.
--
--  WHAT IT DOES
--    1. Revives-or-inserts every (feature, menu) pair listed below, one row at a time.
--       Matching ignores IsDeleted, so a previously retired row is revived, not collided
--       with.
--    2. Soft-deletes any live row for one of the curated feature codes that is NOT in the
--       list below. Never a hard DELETE.
--    3. Reports, per row, whether the MenuCode actually exists in auth."Menus" and whether
--       it is a leaf. An unknown MenuCode still inserts - it is inert, it hides nothing -
--       but it is almost always a typo, so it is printed.
--
--  DELIBERATELY NOT MAPPED - every tenant gets these whatever they pay:
--    CRM_ORGANIZATION + CAMPAIGN + ORGANIZATIONALUNIT, CRM_NOTIFICATION + its leaves,
--    CRM_DASHBOARDS + CONTACTDASHBOARD, ORG_COMPANY, ORG_STAFF, AC_USERSROLES,
--    AC_GOVERNANCE, GEN_REGION, GEN_MASTERS, SET_DATACONFIG, SET_GRIDMANAGEMENT,
--    SET_DASHBOARDWIDGET, SET_ORGSETTINGS, SET_DOCUMENT (except CERTIFICATETEMPLATECONFIG),
--    SET_PAYMENTCONFIG, SET_COMMUNICATIONCONFIG (the group itself), SET_PUBLICPAGES
--    (the group itself), RA_REPORTS + REPORTCATALOG/FUNDRAISINGSUMMARY/GENERATEREPORT,
--    RA_AUDIT + AUDITTRAIL, and everything under BILLING*.
--
--  Run the whole file, once. It is idempotent.
--
--  AFTER THIS FILE, RE-RUN plan-role-baseline-generate-from-plan-features.sql.
-- =====================================================================================

BEGIN;

DROP TABLE IF EXISTS tmp_feature_menu_want;

CREATE TEMP TABLE tmp_feature_menu_want (
    feature_code text,
    menu_code    text,
    PRIMARY KEY (feature_code, menu_code)
);

INSERT INTO tmp_feature_menu_want (feature_code, menu_code) VALUES

-- ══ CONTACTS ═════════════════════════════════════════════════════════════════════════
-- Sell Contacts and the tenant gets the contact list, its own reference data (types,
-- sources, tags, segments), the importer, families, and the dedupe tool.
  ('FEATURE:CONTACTS',          'CRM_CONTACT'),
  ('FEATURE:CONTACTS',          'ALLCONTACTS'),
  ('FEATURE:CONTACTS',          'CONTACT'),
  ('FEATURE:CONTACTS',          'CONTACTTYPE'),
  ('FEATURE:CONTACTS',          'CONTACTSOURCE'),
  ('FEATURE:CONTACTS',          'CONTACTIMPORT'),
  ('FEATURE:CONTACTS',          'TAGSEGMENTATION'),
  ('FEATURE:CONTACTS',          'TAG'),
  ('FEATURE:CONTACTS',          'SEGMENT'),
  ('FEATURE:CONTACTS',          'CRM_FAMILY'),
  ('FEATURE:CONTACTS',          'FAMILY'),
  ('FEATURE:CONTACTS',          'CRM_MAINTENANCE'),
  ('FEATURE:CONTACTS',          'DUPLICATECONTACT'),

-- ══ DONATIONS ════════════════════════════════════════════════════════════════════════
-- The money-in engine: every capture mode, the P2P/crowdfunding surfaces that feed it,
-- receipting and tax certificates, and the donation reference data that only makes sense
-- when donations are sold.
  ('FEATURE:DONATION',          'CRM_DONATION'),
  ('FEATURE:DONATION',          'GLOBALDONATION'),
  ('FEATURE:DONATION',          'BULKDONATION'),
  ('FEATURE:DONATION',          'CHEQUEDONATION'),
  ('FEATURE:DONATION',          'DONATIONINKIND'),
  ('FEATURE:DONATION',          'DONATIONPURPOSE'),
  ('FEATURE:DONATION',          'ONLINEDONATIONPAGE'),
  ('FEATURE:DONATION',          'ONLINEDONATIONINBOX'),
  ('FEATURE:DONATION',          'PLEDGE'),
  ('FEATURE:DONATION',          'RECURRINGDONOR'),
  ('FEATURE:DONATION',          'RECONCILIATION'),
  ('FEATURE:DONATION',          'REFUND'),
  ('FEATURE:DONATION',          'CRM_P2PFUNDRAISING'),
  ('FEATURE:DONATION',          'P2PCAMPAIGN'),
  ('FEATURE:DONATION',          'P2PCAMPAIGNPAGE'),
  ('FEATURE:DONATION',          'P2PFUNDRAISER'),
  ('FEATURE:DONATION',          'CROWDFUNDING'),
  ('FEATURE:DONATION',          'CROWDFUNDINGPAGE'),
  ('FEATURE:DONATION',          'MATCHINGGIFT'),
  ('FEATURE:DONATION',          'MATCHINGCOMPANY'),
  ('FEATURE:DONATION',          'MATCHINGGIFTRECORD'),
  ('FEATURE:DONATION',          'MATCHINGGIFTSETTINGS'),
  ('FEATURE:DONATION',          'CRM_CERTIFICATE'),
  ('FEATURE:DONATION',          'CERTIFICATETEMPLATE'),
  ('FEATURE:DONATION',          'CERTIFICATEOPERATIONS'),
  ('FEATURE:DONATION',          'PROCESSCERTIFICATE'),
  ('FEATURE:DONATION',          'PRINTCERTIFICATE'),
  ('FEATURE:DONATION',          'CERTIFICATETEMPLATECONFIG'),
  ('FEATURE:DONATION',          'SET_DONATIONCONFIG'),
  ('FEATURE:DONATION',          'DONATIONCATEGORY'),
  ('FEATURE:DONATION',          'DONATIONGROUP'),
  ('FEATURE:DONATION',          'DONATIONVERSE'),
  ('FEATURE:DONATION',          'RECEIPTMANAGEMENT'),
  ('FEATURE:DONATION',          'RECEIPTTEMPLATE'),
  ('FEATURE:DONATION',          'GLOBALRECEIPTSETTING'),
  ('FEATURE:DONATION',          'GENERATEDTAXRECEIPT'),
  ('FEATURE:DONATION',          'COUNTRYTAXCONFIG'),
  ('FEATURE:DONATION',          'DONATIONDASHBOARD'),

-- ══ EVENTS ═══════════════════════════════════════════════════════════════════════════
-- Events, ticketing and the auction module that only ever runs inside an event, plus the
-- public registration page.
  ('FEATURE:EVENT',             'CRM_EVENT'),
  ('FEATURE:EVENT',             'EVENT'),
  ('FEATURE:EVENT',             'EVENTTICKETING'),
  ('FEATURE:EVENT',             'EVENTTICKETTEMPLATE'),
  ('FEATURE:EVENT',             'EVENTANALYTICS'),
  ('FEATURE:EVENT',             'AUCTIONMANAGEMENT'),
  ('FEATURE:EVENT',             'EVENTAUCTION'),
  ('FEATURE:EVENT',             'AUCTIONITEM'),
  ('FEATURE:EVENT',             'AUCTIONBID'),
  ('FEATURE:EVENT',             'AUCTIONWINNER'),
  ('FEATURE:EVENT',             'EVENTREGPAGE'),

-- ══ VOLUNTEERS ═══════════════════════════════════════════════════════════════════════
  ('FEATURE:VOLUNTEER',         'CRM_VOLUNTEER'),
  ('FEATURE:VOLUNTEER',         'VOLUNTEERLIST'),
  ('FEATURE:VOLUNTEER',         'VOLUNTEERFORM'),
  ('FEATURE:VOLUNTEER',         'VOLUNTEERSCHEDULING'),
  ('FEATURE:VOLUNTEER',         'VOLUNTEERHOURTRACKING'),
  ('FEATURE:VOLUNTEER',         'VOLUNTEERCONVERSION'),
  ('FEATURE:VOLUNTEER',         'VOLUNTEERREGPAGE'),
  ('FEATURE:VOLUNTEER',         'VOLUNTEERDASHBOARD'),

-- ══ MEMBERSHIP ═══════════════════════════════════════════════════════════════════════
-- The staff-side membership screens, the tier configuration, and the whole member portal
-- area - the portal has no meaning without membership.
  ('FEATURE:MEMBERSHIP',        'CRM_MEMBERSHIP'),
  ('FEATURE:MEMBERSHIP',        'MEMBERLIST'),
  ('FEATURE:MEMBERSHIP',        'MEMBERENROLLMENT'),
  ('FEATURE:MEMBERSHIP',        'MEMBERSHIPRENEWAL'),
  ('FEATURE:MEMBERSHIP',        'MEMBERSHIPTIER'),
  ('FEATURE:MEMBERSHIP',        'SET_MEMBERSHIPCONFIG'),
  ('FEATURE:MEMBERSHIP',        'MEMBERSHIPTIERCONFIG'),
  ('FEATURE:MEMBERSHIP',        'MEMBERPORTAL'),
  ('FEATURE:MEMBERSHIP',        'MEMBERPORTAL_AREA'),
  ('FEATURE:MEMBERSHIP',        'MP_DASHBOARD'),
  ('FEATURE:MEMBERSHIP',        'MP_PROFILE'),
  ('FEATURE:MEMBERSHIP',        'MP_BENEFITS'),
  ('FEATURE:MEMBERSHIP',        'MP_EVENTS'),
  ('FEATURE:MEMBERSHIP',        'MP_PAYMENTS'),

-- ══ CASE MANAGEMENT ══════════════════════════════════════════════════════════════════
-- Beneficiaries, cases and programs are one product. Program fund allocation sits here
-- because it is the program side of the grant loop, not the grant side.
  ('FEATURE:CASE',              'CRM_CASEMANAGEMENT'),
  ('FEATURE:CASE',              'CASELIST'),
  ('FEATURE:CASE',              'CASENOTE'),
  ('FEATURE:CASE',              'CASEACTIONITEM'),
  ('FEATURE:CASE',              'CASEDOCUMENTS'),
  ('FEATURE:CASE',              'CASEREFERRAL'),
  ('FEATURE:CASE',              'BENEFICIARYLIST'),
  ('FEATURE:CASE',              'BENEFICIARYFORM'),
  ('FEATURE:CASE',              'BENEFICIARYDOCUMENT'),
  ('FEATURE:CASE',              'BENEFICIARYHOUSEHOLDMEMBER'),
  ('FEATURE:CASE',              'BENEFICIARYMILESTONE'),
  ('FEATURE:CASE',              'BENEFICIARYPROGRAMENROLLMENT'),
  ('FEATURE:CASE',              'BENEFICIARYSERVICELOG'),
  ('FEATURE:CASE',              'BENEFICIARYVERIFICATION'),
  ('FEATURE:CASE',              'PROGRAM'),
  ('FEATURE:CASE',              'PROGRAMMANAGEMENT'),
  ('FEATURE:CASE',              'PROGRAMFUNDALLOCATION'),
  ('FEATURE:CASE',              'CASEDASHBOARD'),

-- ══ GRANTS ═══════════════════════════════════════════════════════════════════════════
  ('FEATURE:GRANT',             'CRM_GRANT'),
  ('FEATURE:GRANT',             'GRANT'),
  ('FEATURE:GRANT',             'GRANTLIST'),
  ('FEATURE:GRANT',             'GRANTFORM'),
  ('FEATURE:GRANT',             'GRANTDOCUMENT'),
  ('FEATURE:GRANT',             'GRANTCALENDAR'),
  ('FEATURE:GRANT',             'GRANTREPORTING'),

-- ══ FIELD COLLECTION ═════════════════════════════════════════════════════════════════
-- Ambassadors, their receipt books and the cash they hand in.
  ('FEATURE:FIELDCOLLECTION',   'CRM_FIELDCOLLECTION'),
  ('FEATURE:FIELDCOLLECTION',   'AMBASSADORLIST'),
  ('FEATURE:FIELDCOLLECTION',   'AMBASSADORCOLLECTION'),
  ('FEATURE:FIELDCOLLECTION',   'AMBASSADORPERFORMANCE'),
  ('FEATURE:FIELDCOLLECTION',   'COLLECTIONLIST'),
  ('FEATURE:FIELDCOLLECTION',   'COLLECTIONDISTRIBUTION'),
  ('FEATURE:FIELDCOLLECTION',   'RECEIPTBOOK'),
  ('FEATURE:FIELDCOLLECTION',   'RECEIPTBOOKMASTER'),
  ('FEATURE:FIELDCOLLECTION',   'AMBASSADORDASHBOARD'),

-- ══ AUTOMATION ═══════════════════════════════════════════════════════════════════════
  ('FEATURE:AUTOMATION',        'CRM_AUTOMATION'),
  ('FEATURE:AUTOMATION',        'AUTOMATIONWORKFLOW'),

-- ══ PRAYER REQUESTS ══════════════════════════════════════════════════════════════════
-- Intake, the reply pipeline, and the public request page.
  ('FEATURE:PRAYERREQUEST',     'CRM_PRAYERREQUEST'),
  ('FEATURE:PRAYERREQUEST',     'PRAYERREQUESTENTRY'),
  ('FEATURE:PRAYERREQUEST',     'REPLYQUEUE'),
  ('FEATURE:PRAYERREQUEST',     'REVIEWREPLY'),
  ('FEATURE:PRAYERREQUEST',     'PERSONALREPLY'),
  ('FEATURE:PRAYERREQUEST',     'CANCELREPLY'),
  ('FEATURE:PRAYERREQUEST',     'ACKLETTER'),
  ('FEATURE:PRAYERREQUEST',     'PRINTREPLYBATCH'),
  ('FEATURE:PRAYERREQUEST',     'PRAYERREQUESTPAGE'),

-- ══ INTELLIGENCE (AI) ════════════════════════════════════════════════════════════════
  ('FEATURE:INTELLIGENCE',      'CRM_INTELLIGENCE'),
  ('FEATURE:INTELLIGENCE',      'ACTIONBOARD'),
  ('FEATURE:INTELLIGENCE',      'AIDRAFT'),
  ('FEATURE:INTELLIGENCE',      'CHURNPREDICTION'),
  ('FEATURE:INTELLIGENCE',      'ENGAGEMENTSCORING'),
  ('FEATURE:INTELLIGENCE',      'NLREPORTING'),
  ('FEATURE:INTELLIGENCE',      'PREDICTIVEANALYTICS'),

-- ══ ADVANCED REPORTING ═══════════════════════════════════════════════════════════════
-- The RA_REPORTS group and the canned reports stay ungated. Only the builder, the
-- scheduler, the HTML designer and the retention dashboard are sold.
  ('FEATURE:ADVANCEDREPORTING', 'CUSTOMREPORTBUILDER'),
  ('FEATURE:ADVANCEDREPORTING', 'SCHEDULEDREPORT'),
  ('FEATURE:ADVANCEDREPORTING', 'HTMLREPORT'),
  ('FEATURE:ADVANCEDREPORTING', 'RETENTIONDASHBOARD'),

-- ══ POWER BI ═════════════════════════════════════════════════════════════════════════
  ('FEATURE:POWERBI',           'POWERBIREPORT'),
  ('FEATURE:POWERBI',           'RA_REPORTSETUP'),
  ('FEATURE:POWERBI',           'POWERBIREPORTMASTER'),
  ('FEATURE:POWERBI',           'POWERBIUSERMAPPING'),

-- ══ INTEGRATIONS ═════════════════════════════════════════════════════════════════════
  ('FEATURE:INTEGRATION',       'SET_INTEGRATION'),
  ('FEATURE:INTEGRATION',       'ACCOUNTINGINTEGRATION'),
  ('FEATURE:INTEGRATION',       'APIMANAGEMENT'),
  ('FEATURE:INTEGRATION',       'INTEGRATIONMARKETPLACE'),
  ('FEATURE:INTEGRATION',       'SOCIALMEDIAINTEGRATION'),

-- ══ EMAIL CHANNEL ════════════════════════════════════════════════════════════════════
-- The SET_COMMUNICATIONCONFIG group itself stays ungated - a tenant on SMS only still
-- needs to reach it. Only the email provider screens under it are sold.
  ('CHANNEL:EMAIL',             'CRM_COMMUNICATION'),
  ('CHANNEL:EMAIL',             'EMAILCAMPAIGN'),
  ('CHANNEL:EMAIL',             'EMAILTEMPLATE'),
  ('CHANNEL:EMAIL',             'EMAILKEYWORD'),
  ('CHANNEL:EMAIL',             'EMAILANALYTICS'),
  ('CHANNEL:EMAIL',             'PLACEHOLDERDEFINITION'),
  ('CHANNEL:EMAIL',             'SAVEDFILTER'),
  ('CHANNEL:EMAIL',             'EMAILPROVIDERCONFIG'),
  ('CHANNEL:EMAIL',             'COMPANYEMAILPROVIDER'),
  ('CHANNEL:EMAIL',             'COMPANYEMAILCONFIGURATION'),
  ('CHANNEL:EMAIL',             'COMMUNICATIONDASHBOARD'),

-- ══ SMS CHANNEL ══════════════════════════════════════════════════════════════════════
  ('CHANNEL:SMS',               'CRM_SMS'),
  ('CHANNEL:SMS',               'SMSCAMPAIGN'),
  ('CHANNEL:SMS',               'SMSTEMPLATE'),
  ('CHANNEL:SMS',               'SMSSETUP'),

-- ══ WHATSAPP CHANNEL ═════════════════════════════════════════════════════════════════
  ('CHANNEL:WHATSAPP',          'CRM_WHATSAPP'),
  ('CHANNEL:WHATSAPP',          'WHATSAPPCAMPAIGN'),
  ('CHANNEL:WHATSAPP',          'WHATSAPPTEMPLATE'),
  ('CHANNEL:WHATSAPP',          'WHATSAPPCONVERSATION'),
  ('CHANNEL:WHATSAPP',          'WHATSAPPSETUP');


DO $map$
DECLARE
    v_want      record;
    v_dead      record;
    v_revived   int := 0;
    v_kept      int := 0;
    v_inserted  int := 0;
    v_retired   int := 0;
    v_unknown   int := 0;
    v_notleaf   int := 0;
    v_isleaf    boolean;
BEGIN

-- ---------------------------------------------------------------------------------
-- 1. Revive-or-insert, one row at a time.
-- ---------------------------------------------------------------------------------
FOR v_want IN SELECT feature_code, menu_code
              FROM   tmp_feature_menu_want
              ORDER  BY feature_code, menu_code
LOOP
    -- The feature must be live in the curated catalogue, or nothing downstream reads it.
    PERFORM 1 FROM billing."Features" f
    WHERE  upper(f."FeatureCode") = upper(v_want.feature_code)
      AND  f."IsDeleted" IS DISTINCT FROM true;

    IF NOT FOUND THEN
        RAISE NOTICE 'NO SUCH FEATURE: %  (menu % skipped) - check billing."Features"',
                     v_want.feature_code, v_want.menu_code;
        CONTINUE;
    END IF;

    -- Does the menu exist at all? An unknown code is inert, not dangerous - but say so.
    v_isleaf := NULL;
    SELECT m."IsLeastMenu" INTO v_isleaf
    FROM   auth."Menus" m
    WHERE  upper(m."MenuCode") = upper(v_want.menu_code)
      AND  m."IsDeleted" IS DISTINCT FROM true
    LIMIT  1;

    IF NOT FOUND THEN
        RAISE NOTICE 'UNKNOWN MENU: % -> %  (row still written, it simply hides nothing)',
                     v_want.feature_code, v_want.menu_code;
        v_unknown := v_unknown + 1;
    ELSIF v_isleaf IS DISTINCT FROM true THEN
        -- Expected for the group rows (CRM_CONTACT, SET_DONATIONCONFIG, ...). Counted so
        -- the totals below can be read against the leaf count.
        v_notleaf := v_notleaf + 1;
    END IF;

    -- Revive a retired row rather than inserting next to it.
    UPDATE billing."FeatureMenuMaps"
    SET    "IsActive"     = true,
           "IsDeleted"    = false,
           "ModifiedDate" = now()
    WHERE  upper("FeatureCode") = upper(v_want.feature_code)
      AND  upper("MenuCode")    = upper(v_want.menu_code)
      AND  "IsDeleted" = true;

    IF FOUND THEN
        v_revived := v_revived + 1;
        CONTINUE;
    END IF;

    -- Already live?
    PERFORM 1 FROM billing."FeatureMenuMaps"
    WHERE  upper("FeatureCode") = upper(v_want.feature_code)
      AND  upper("MenuCode")    = upper(v_want.menu_code)
      AND  "IsDeleted" IS DISTINCT FROM true;

    IF FOUND THEN
        UPDATE billing."FeatureMenuMaps"
        SET    "IsActive" = true, "ModifiedDate" = now()
        WHERE  upper("FeatureCode") = upper(v_want.feature_code)
          AND  upper("MenuCode")    = upper(v_want.menu_code)
          AND  "IsDeleted" IS DISTINCT FROM true
          AND  "IsActive" IS DISTINCT FROM true;
        v_kept := v_kept + 1;
        CONTINUE;
    END IF;

    INSERT INTO billing."FeatureMenuMaps"
           ("FeatureCode", "MenuCode", "IsActive", "IsDeleted", "CreatedDate")
    VALUES (upper(v_want.feature_code), upper(v_want.menu_code), true, false, now());
    v_inserted := v_inserted + 1;
END LOOP;

-- ---------------------------------------------------------------------------------
-- 2. Retire anything live that this file no longer claims. Soft-delete, never DELETE.
--    Scoped to feature codes that appear above, so an unrelated experiment is untouched.
-- ---------------------------------------------------------------------------------
FOR v_dead IN
    SELECT m."FeatureCode", m."MenuCode"
    FROM   billing."FeatureMenuMaps" m
    WHERE  m."IsDeleted" IS DISTINCT FROM true
      AND  upper(m."FeatureCode") IN (SELECT upper(feature_code) FROM tmp_feature_menu_want)
      AND  NOT EXISTS (
             SELECT 1 FROM tmp_feature_menu_want w
             WHERE upper(w.feature_code) = upper(m."FeatureCode")
               AND upper(w.menu_code)    = upper(m."MenuCode"))
LOOP
    UPDATE billing."FeatureMenuMaps"
    SET    "IsActive" = false, "IsDeleted" = true, "ModifiedDate" = now()
    WHERE  upper("FeatureCode") = upper(v_dead."FeatureCode")
      AND  upper("MenuCode")    = upper(v_dead."MenuCode")
      AND  "IsDeleted" IS DISTINCT FROM true;

    RAISE NOTICE 'RETIRED: % -> %', v_dead."FeatureCode", v_dead."MenuCode";
    v_retired := v_retired + 1;
END LOOP;

RAISE NOTICE '----------------------------------------------------------------';
RAISE NOTICE 'inserted: %  revived: %  already live: %  retired: %',
             v_inserted, v_revived, v_kept, v_retired;
RAISE NOTICE 'unknown menu codes: %   group (non-leaf) rows: %', v_unknown, v_notleaf;
RAISE NOTICE '----------------------------------------------------------------';

END
$map$;

COMMIT;

-- Result 1. Rows per feature, split by what the dialog will actually tick.
--           "leaf" is the number the "Menus unlocked by X" footer counts.
SELECT m."FeatureCode",
       count(*)                                                      AS mapped_rows,
       count(*) FILTER (WHERE x."IsLeastMenu" = true)                 AS leaf,
       count(*) FILTER (WHERE x."IsLeastMenu" IS DISTINCT FROM true
                          AND x."MenuCode" IS NOT NULL)               AS groups,
       count(*) FILTER (WHERE x."MenuCode" IS NULL)                   AS unknown
FROM   billing."FeatureMenuMaps" m
LEFT   JOIN auth."Menus" x
       ON upper(x."MenuCode") = upper(m."MenuCode")
      AND x."IsDeleted" IS DISTINCT FROM true
WHERE  m."IsDeleted" IS DISTINCT FROM true
GROUP  BY m."FeatureCode"
ORDER  BY m."FeatureCode";

-- Result 2. Every mapped code that does not exist as a live menu. Expect none.
--           Anything here is a typo - the row hides nothing.
SELECT m."FeatureCode", m."MenuCode" AS unknown_menu_code
FROM   billing."FeatureMenuMaps" m
WHERE  m."IsDeleted" IS DISTINCT FROM true
  AND  NOT EXISTS (SELECT 1 FROM auth."Menus" x
                   WHERE upper(x."MenuCode") = upper(m."MenuCode")
                     AND x."IsDeleted" IS DISTINCT FROM true)
ORDER  BY m."FeatureCode", m."MenuCode";

-- Result 3. Live LEAF menus that no feature claims. These are visible to every tenant on
--           every plan. Read this list and confirm each one is deliberate.
SELECT x."MenuCode", x."MenuName"
FROM   auth."Menus" x
WHERE  x."IsDeleted" IS DISTINCT FROM true
  AND  x."IsActive"  IS DISTINCT FROM false
  AND  x."IsLeastMenu" = true
  AND  NOT EXISTS (SELECT 1 FROM billing."FeatureMenuMaps" m
                   WHERE upper(m."MenuCode") = upper(x."MenuCode")
                     AND m."IsDeleted" IS DISTINCT FROM true)
ORDER  BY x."MenuCode";

DROP TABLE tmp_feature_menu_want;
