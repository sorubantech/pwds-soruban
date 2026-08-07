-- =====================================================================================
-- P-04 — PLATFORM_LOGIN_URL_TEMPLATE (tenant-aware "Go to Sign In" after activation)
-- -------------------------------------------------------------------------------------
-- ONE platform-global row in sett."OrganizationSettings" (CompanyId IS NULL), read by
-- Base.Application/Business/AuthBusiness/AccountActivation/TenantLoginUrlHelper.ResolveAsync
-- via LeadHelper.GetPlatformSettingAsync.
--
-- WHY: the activation page is reachable on ANY host (the invitee opens whatever link the welcome
-- email carried), but the tenant's LOGIN lives on the tenant's own subdomain — or on its custom
-- domain. Until now the success panel's "Go to Sign In" button was a host-relative /{lang}/login,
-- which on a wildcard-host deployment is the wrong door. The backend now resolves the tenant's own
-- login URL and returns it on both activateAccount and validateActivationToken.
--
-- RESOLUTION ORDER in the helper (this row is only step 2):
--   1. Company."CustomDomain"  — when set it IS the tenant's address and outranks this pattern.
--   2. this pattern + Company."Subdomain".
--   3. NULL — a NORMAL answer, not a failure. Single-host / dev deployments and platform staff
--      (no CompanyId) get NULL and the frontend keeps its relative /{lang}/login. So a single-host
--      environment can simply NOT apply this file and everything behaves exactly as before.
--
-- Tokens: {SUBDOMAIN} {LANG}. {LANG} comes from PLATFORM_DEFAULT_LANG (seeded by
-- ops-lead-deal-seed.sql, default 'en') — this file does NOT re-seed it.
--
-- The /{lang}/login path segment is the REAL Next.js route (src/app/[lang]/(auth)/login); it is not
-- invented here. ADJUST THE APEX DOMAIN BELOW to the real tenant wildcard host before applying —
-- it must match the host used by PLATFORM_ACTIVATION_URL_TEMPLATE.
--
-- CanUserOverride = FALSE: a tenant user must never shadow control-plane policy with a UserSetting.
--
-- IDEMPOTENT: guarded by NOT EXISTS on (CompanyId IS NULL, ParamCode). Additive only — no DROP, no
-- UPDATE, no schema change.
--
-- USER-OWNED: written here, applied by the user. Never executed from code.
-- PREREQUISITE: run AFTER ops-lead-deal-seed.sql (the hidden PLATFORM SettingGroup must exist).
-- =====================================================================================

BEGIN;

WITH g AS (
    SELECT "SettingGroupId"
    FROM sett."SettingGroups"
    WHERE "SettingGroupCode" = 'PLATFORM' AND "IsDeleted" = FALSE
    LIMIT 1
)
INSERT INTO sett."OrganizationSettings" (
    "CompanyId", "SettingGroupId", "ParamName", "ParamCode",
    "ParamDataType", "AllValues", "ParamDefaultValue", "CurrentValue",
    "Description", "CanUserOverride",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT
    NULL,                       -- platform-global: no tenant owns this
    g."SettingGroupId",
    'Platform Login Url Template',
    'PLATFORM_LOGIN_URL_TEMPLATE',
    'STRING',
    NULL,
    'https://{SUBDOMAIN}.peopleserve.app/{LANG}/login',
    NULL,                       -- CurrentValue left NULL → ParamDefaultValue is the live value
    'Pattern for a tenant''s own login page, used by the account-activation success panel. Tokens: {SUBDOMAIN} {LANG}. A tenant''s CustomDomain, when set, wins over this pattern. Blank or absent leaves the frontend on its host-relative /{lang}/login.',
    FALSE,
    2, now(), NULL, NULL, TRUE, FALSE
FROM g
WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings" s
    WHERE s."CompanyId" IS NULL
      AND s."ParamCode" = 'PLATFORM_LOGIN_URL_TEMPLATE'
      AND s."IsDeleted" = FALSE
);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--
--   -- the row exists exactly once, platform-global, in the hidden PLATFORM group
--   SELECT s."ParamCode", s."ParamDefaultValue", s."CurrentValue", s."CanUserOverride",
--          g."SettingGroupCode"
--   FROM sett."OrganizationSettings" s
--   JOIN sett."SettingGroups" g ON g."SettingGroupId" = s."SettingGroupId"
--   WHERE s."CompanyId" IS NULL
--     AND s."ParamCode" = 'PLATFORM_LOGIN_URL_TEMPLATE'
--     AND s."IsDeleted" = FALSE;
--
--   -- the login host should match the activation host (same apex domain, different path)
--   SELECT "ParamCode", COALESCE("CurrentValue", "ParamDefaultValue") AS live_value
--   FROM sett."OrganizationSettings"
--   WHERE "CompanyId" IS NULL
--     AND "ParamCode" IN ('PLATFORM_ACTIVATION_URL_TEMPLATE','PLATFORM_LOGIN_URL_TEMPLATE',
--                         'PLATFORM_DEFAULT_LANG')
--     AND "IsDeleted" = FALSE
--   ORDER BY "ParamCode";
--
--   -- tenants that will resolve a login URL: a CustomDomain, or a Subdomain + this pattern
--   SELECT "CompanyId", "CompanyName", "Subdomain", "CustomDomain"
--   FROM app."Companies"
--   WHERE "IsDeleted" IS DISTINCT FROM TRUE
--   ORDER BY "CompanyId";
-- =====================================================================================
