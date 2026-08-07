-- =====================================================================================
--  P-20 §④ step 5 — publish the plan catalogue to the anonymous product landing page.
--
--  USER-OWNED: this file is written here and applied by the user. It is never executed from code.
--
--  PREREQUISITE: run the Add_LeadEnquiryFields migration FIRST. It adds
--  billing."Plans"."IsPubliclyListed"; every UPDATE below targets that column and will fail with
--  42703 (undefined_column) if the migration has not been applied.
--
--  WHY THIS FILE EXISTS
--  Plan.IsPubliclyListed defaults to FALSE — the migration leaves every existing plan unlisted, on
--  purpose. Publication of commercial pricing to a public URL is a deliberate business act, not a
--  side effect of a deploy. This script is that act, performed once, reviewably, in SQL.
--
--  WHAT GETS PUBLISHED (the four seeded tiers from billing-plan-catalog-seed.sql)
--    FREE      Free         0             — listed
--    PLAN_50K  Growth       50,000 INR/yr — listed
--    PLAN_100K Full Suite  100,000 INR/yr — listed
--    CUSTOM    Enterprise   IsCustom      — listed, but the card renders the word "Custom", never
--                                           the 0 anchor price. GetPublicPlanTeasers returns
--                                           IsCustom so the FE can make that substitution; the
--                                           number is carried but must not be printed.
--  Any plan created later — a one-off tier negotiated for a single customer — stays FALSE and stays
--  off the page until someone explicitly lists it.
--
--  HIGHLIGHT BULLETS
--  Section 2 seeds sett."OrganizationSettings" rows, platform-global (CompanyId NULL), one per plan,
--  ParamCode PLATFORM_PLAN_HIGHLIGHTS_{PLANCODE}, value pipe-separated.
--
--  These are MARKETING COPY, hand-written, and that is the whole point. GetPublicPlanTeasers is
--  forbidden from deriving a single bullet from billing."PlanEntitlements" or billing."PlanQuotas":
--  those tables carry the FEATURE:* / CHANNEL:* feature codes and the meter codes the entitlement
--  gate is written in, and publishing them at an anonymous URL would hand a reader the internal
--  shape of our packaging and our authorisation vocabulary. A bullet that says "up to 50,000
--  contacts" is written by a human who checked the quota; it is never generated from the quota row.
--
--  Copy lives in settings rather than a column so rewording a bullet is an UPDATE, not a migration.
--
--  Idempotent: every statement is guarded. Safe to re-run. Additive only — no DROP, no schema change.
-- =====================================================================================

BEGIN;

-- ── 1. Publish the four catalogue tiers ─────────────────────────────────────────────
-- Guarded on the current value so a re-run touches zero rows, and so an operator who has
-- deliberately UNLISTED a plan in the UI does not have it silently re-published by a re-run.
UPDATE billing."Plans"
   SET "IsPubliclyListed" = TRUE,
       "ModifiedDate"     = now()
 WHERE "PlanCode" IN ('FREE', 'PLAN_50K', 'PLAN_100K', 'CUSTOM')
   AND COALESCE("IsDeleted", false) = false
   AND COALESCE("IsPubliclyListed", false) = false;


-- ── 2. Highlight bullets (platform-global settings) ─────────────────────────────────
-- Attaches to the PLATFORM setting group seeded by ops-lead-deal-seed.sql section 1. If that group
-- is absent the CROSS JOIN yields no rows and this section is a no-op — plans still render on the
-- page, just without bullets. Run ops-lead-deal-seed.sql first if you want the copy.
INSERT INTO sett."OrganizationSettings"
  ("CompanyId","SettingGroupId","ParamName","ParamCode","ParamDataType","AllValues",
   "ParamDefaultValue","CurrentValue","Description","CanUserOverride",
   "CreatedBy","CreatedDate","ModifiedBy","ModifiedDate","IsActive","IsDeleted")
SELECT NULL, g."SettingGroupId", c.param_name, c.param_code, 'STRING', NULL,
       c.default_value, NULL, c.description, FALSE,
       2, now(), NULL, NULL, TRUE, FALSE
FROM (VALUES
  ('Public plan highlights — Free',
   'PLATFORM_PLAN_HIGHLIGHTS_FREE',
   'Contacts and donor records|Online donation collection|Receipting and acknowledgements|Email notifications|Community support',
   'Pipe-separated bullet copy shown on the Free card of the public product page.'),

  ('Public plan highlights — Growth',
   'PLATFORM_PLAN_HIGHLIGHTS_PLAN_50K',
   'Everything in Free|Events and registrations|Volunteer management|Membership records|Full email channel|Standard support',
   'Pipe-separated bullet copy shown on the Growth card of the public product page.'),

  ('Public plan highlights — Full Suite',
   'PLATFORM_PLAN_HIGHLIGHTS_PLAN_100K',
   'Everything in Growth|Case management|Grant management|SMS and WhatsApp channels|Advanced reporting|Priority support',
   'Pipe-separated bullet copy shown on the Full Suite card of the public product page.'),

  ('Public plan highlights — Enterprise',
   'PLATFORM_PLAN_HIGHLIGHTS_CUSTOM',
   'Every module enabled|Limits agreed with you, not a price list|Dedicated onboarding|Named account contact|Custom commercial terms',
   'Pipe-separated bullet copy shown on the Enterprise card of the public product page.')
) AS c(param_name, param_code, default_value, description)
CROSS JOIN (
  SELECT "SettingGroupId" FROM sett."SettingGroups"
   WHERE "SettingGroupCode" = 'PLATFORM' AND COALESCE("IsDeleted", false) = false
   LIMIT 1
) g
WHERE NOT EXISTS (
  SELECT 1 FROM sett."OrganizationSettings" os
   WHERE os."CompanyId" IS NULL
     AND os."ParamCode" = c.param_code
     AND os."IsDeleted" = FALSE
);

COMMIT;


-- =====================================================================================
--  VERIFY (run after COMMIT):
--
--   -- 1. Exactly the four tiers are listed, and nothing else is:
--   SELECT "PlanCode","PlanName","Price","IsCustom","IsPubliclyListed","IsActive"
--     FROM billing."Plans" ORDER BY "SortOrder";
--   -- expect IsPubliclyListed = true on FREE / PLAN_50K / PLAN_100K / CUSTOM, false elsewhere.
--
--   -- 2. Four bullet rows, all platform-global:
--   SELECT "ParamCode","ParamDefaultValue" FROM sett."OrganizationSettings"
--    WHERE "ParamCode" LIKE 'PLATFORM_PLAN_HIGHLIGHTS_%' AND "CompanyId" IS NULL
--    ORDER BY "ParamCode";
--   -- if this returns 0 rows, the PLATFORM SettingGroup is missing — run ops-lead-deal-seed.sql.
--
--   -- 3. End to end: the anonymous query must return 4 cards.
--   --    POST /graphql with no Authorization header:
--   --      query { publicPlanTeasers { data { planCode planName price currencyCode isCustom highlights } } }
-- =====================================================================================
