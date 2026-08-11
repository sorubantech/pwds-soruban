-- =====================================================================================
-- S10 — PLATFORM_TENANT_ROOT_DOMAIN + token-form URL templates
-- -------------------------------------------------------------------------------------
-- ONE new platform-global row in sett."OrganizationSettings" (CompanyId IS NULL), plus a
-- rewrite of the two URL templates so the root domain is named ONCE instead of being
-- baked into every pattern.
--
-- WHY
--   The wildcard root ("peopleserve.app") was a literal repeated across
--   ops-lead-deal-seed.sql, platform-login-url-template-seed.sql and every hand-run
--   UPDATE since. Moving the domain to the actual DNS name behind the deployment meant
--   editing each of those in turn, and forgetting one sends an invitee to a host that
--   does not exist. After this file the templates carry {ROOTDOMAIN} and the root lives
--   in exactly one row.
--
--   Backend reader: Base.Application/Business/AuthBusiness/AccountActivation/
--   TenantHostResolver.cs — GetRootDomainAsync / ResolveTenantHostAsync /
--   ResolveLoginUrlAsync, all via LeadHelper.GetPlatformSettingAsync
--   (CurrentValue ?? ParamDefaultValue, trimmed, blank → null).
--
-- VALUE FORMAT — bare host, and nothing else:
--       peopleserve.app          ✓
--       .peopleserve.app         ✗ leading dot
--       https://peopleserve.app  ✗ scheme
--       peopleserve.app/         ✗ trailing slash
--   TenantHostResolver.NormalizeDomain defends against all three, but the row should be
--   right in the database, not right by rescue.
--
-- ⚠ SET THE REAL ROOT DOMAIN BELOW. The value seeded here is the literal that was
--   already in the historical seeds ('peopleserve.app'). If this deployment's wildcard is
--   a different apex, change it in §1 AND in the two WHERE clauses of §2/§3 — those match
--   on the OLD literal on purpose, so they never rewrite a host they did not recognise.
--
-- ⚠ RUN ORDER — apply S9's hand-run UPDATE (the one that points
--   PLATFORM_ACTIVATION_URL_TEMPLATE."CurrentValue" at the real wildcard host) BEFORE this
--   file. GetPlatformSettingAsync prefers CurrentValue, so a stale CurrentValue would
--   shadow a freshly tokenised ParamDefaultValue. §2/§3 rewrite BOTH columns, so running
--   this file after S9 converts whatever S9 left behind.
--
-- ⚠ DEV localhost is protected. dev-localhost-activation-url.sql sets
--   CurrentValue = 'http://localhost:3000/{LANG}/activate?token={TOKEN}' — that value does
--   not match the WHERE clauses below and is deliberately left alone, so a dev box that
--   applies this file keeps working.
--
-- IDEMPOTENT: §1 is guarded by NOT EXISTS; §2/§3 match only the old literal form, so a
-- second run updates 0 rows. Additive + in-place UPDATE only — no DROP, no schema change,
-- no EF migration.
--
-- USER-OWNED: written here, applied by the user. Never executed from code.
-- PREREQUISITE: ops-lead-deal-seed.sql (the hidden PLATFORM SettingGroup and both
-- templates) and platform-login-url-template-seed.sql must already be applied.
--
-- EXPECTED ROW COUNTS (first run, on a database where both templates still hold the old
-- literal in ParamDefaultValue and no CurrentValue override):
--     §1 INSERT ............ 1     (0 on every re-run)
--     §2 UPDATE activation . 1     (0 on every re-run)
--     §3 UPDATE login ...... 1     (0 on every re-run)
-- If §2 or §3 report 0 on a FIRST run, the live value is not the old literal — read the
-- §0 pre-flight output below and convert that row by hand rather than loosening the match.
-- =====================================================================================


-- ── 0. PRE-FLIGHT — read what is actually in force before changing anything ──────────
--    Run this on its own first. It is the "read the live rows" step: it shows which of
--    ParamDefaultValue / CurrentValue is winning, so you can see what §2/§3 will touch.
SELECT "ParamCode",
       "ParamDefaultValue",
       "CurrentValue",
       COALESCE(NULLIF(btrim("CurrentValue"), ''), "ParamDefaultValue") AS live_value
FROM sett."OrganizationSettings"
WHERE "CompanyId" IS NULL
  AND "ParamCode" IN ('PLATFORM_ACTIVATION_URL_TEMPLATE',
                      'PLATFORM_LOGIN_URL_TEMPLATE',
                      'PLATFORM_DEFAULT_LANG',
                      'PLATFORM_TENANT_ROOT_DOMAIN')
  AND "IsDeleted" = FALSE
ORDER BY "ParamCode";


BEGIN;

-- ── 1. The root domain, named once ───────────────────────────────────────────────────
--    CanUserOverride = FALSE: a tenant user must never shadow control-plane policy with
--    a UserSetting. This row decides where every tenant lives.
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
    'Platform Tenant Root Domain',
    'PLATFORM_TENANT_ROOT_DOMAIN',
    'STRING',
    NULL,
    'peopleserve.app',          -- ⚠ the real wildcard root: bare host, no dot, no scheme
    NULL,                       -- CurrentValue NULL → ParamDefaultValue is the live value
    'The wildcard root domain every tenant subdomain hangs off (app.Companies.Subdomain holds the bare label only, e.g. "hope" → hope.peopleserve.app). Bare host: no leading dot, no scheme, no trailing slash. Substituted into {ROOTDOMAIN} in PLATFORM_ACTIVATION_URL_TEMPLATE and PLATFORM_LOGIN_URL_TEMPLATE. A tenant''s CustomDomain, when set, outranks it.',
    FALSE,
    2, now(), NULL, NULL, TRUE, FALSE
FROM g
WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings" s
    WHERE s."CompanyId" IS NULL
      AND s."ParamCode" = 'PLATFORM_TENANT_ROOT_DOMAIN'
      AND s."IsDeleted" = FALSE
);


-- ── 2. Activation template → token form ──────────────────────────────────────────────
--    Both columns are converted in one statement, each guarded independently, so a row
--    with a stale CurrentValue (S9, or an earlier hand-run UPDATE) is fully migrated and
--    a row with only a ParamDefaultValue is too. Anything that is NOT the old literal —
--    the dev localhost value, a hand-tuned pattern, an already-tokenised value — is left
--    exactly as it is.
UPDATE sett."OrganizationSettings"
SET "ParamDefaultValue" = CASE
        WHEN "ParamDefaultValue" = 'https://{SUBDOMAIN}.peopleserve.app/{LANG}/activate?token={TOKEN}'
        THEN 'https://{SUBDOMAIN}.{ROOTDOMAIN}/{LANG}/activate?token={TOKEN}'
        ELSE "ParamDefaultValue" END,
    "CurrentValue" = CASE
        WHEN "CurrentValue" = 'https://{SUBDOMAIN}.peopleserve.app/{LANG}/activate?token={TOKEN}'
        THEN 'https://{SUBDOMAIN}.{ROOTDOMAIN}/{LANG}/activate?token={TOKEN}'
        ELSE "CurrentValue" END,
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE "CompanyId" IS NULL
  AND "ParamCode"  = 'PLATFORM_ACTIVATION_URL_TEMPLATE'
  AND "IsDeleted"  = FALSE
  AND ("ParamDefaultValue" = 'https://{SUBDOMAIN}.peopleserve.app/{LANG}/activate?token={TOKEN}'
    OR "CurrentValue"      = 'https://{SUBDOMAIN}.peopleserve.app/{LANG}/activate?token={TOKEN}');


-- ── 3. Login template → token form ───────────────────────────────────────────────────
UPDATE sett."OrganizationSettings"
SET "ParamDefaultValue" = CASE
        WHEN "ParamDefaultValue" = 'https://{SUBDOMAIN}.peopleserve.app/{LANG}/login'
        THEN 'https://{SUBDOMAIN}.{ROOTDOMAIN}/{LANG}/login'
        ELSE "ParamDefaultValue" END,
    "CurrentValue" = CASE
        WHEN "CurrentValue" = 'https://{SUBDOMAIN}.peopleserve.app/{LANG}/login'
        THEN 'https://{SUBDOMAIN}.{ROOTDOMAIN}/{LANG}/login'
        ELSE "CurrentValue" END,
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE "CompanyId" IS NULL
  AND "ParamCode"  = 'PLATFORM_LOGIN_URL_TEMPLATE'
  AND "IsDeleted"  = FALSE
  AND ("ParamDefaultValue" = 'https://{SUBDOMAIN}.peopleserve.app/{LANG}/login'
    OR "CurrentValue"      = 'https://{SUBDOMAIN}.peopleserve.app/{LANG}/login');

COMMIT;


-- =====================================================================================
-- VERIFY (run after COMMIT):
--
--   -- all three rows, platform-global; both templates should now read {ROOTDOMAIN}
--   SELECT "ParamCode",
--          COALESCE(NULLIF(btrim("CurrentValue"), ''), "ParamDefaultValue") AS live_value
--   FROM sett."OrganizationSettings"
--   WHERE "CompanyId" IS NULL
--     AND "ParamCode" IN ('PLATFORM_TENANT_ROOT_DOMAIN',
--                         'PLATFORM_ACTIVATION_URL_TEMPLATE',
--                         'PLATFORM_LOGIN_URL_TEMPLATE',
--                         'PLATFORM_DEFAULT_LANG')
--     AND "IsDeleted" = FALSE
--   ORDER BY "ParamCode";
--
--   -- what each tenant will now resolve to (CustomDomain wins; Subdomain is a BARE label)
--   SELECT c."CompanyId", c."CompanyName", c."Subdomain", c."CustomDomain",
--          COALESCE(c."CustomDomain", c."Subdomain" || '.' || r.live) AS resolved_host
--   FROM app."Companies" c
--   CROSS JOIN (
--        SELECT COALESCE(NULLIF(btrim("CurrentValue"), ''), "ParamDefaultValue") AS live
--        FROM sett."OrganizationSettings"
--        WHERE "CompanyId" IS NULL AND "ParamCode" = 'PLATFORM_TENANT_ROOT_DOMAIN'
--          AND "IsDeleted" = FALSE
--   ) r
--   WHERE c."IsDeleted" IS DISTINCT FROM TRUE
--   ORDER BY c."CompanyId";
--
-- REVERT (§1 only — the templates are safe to leave tokenised):
--   UPDATE sett."OrganizationSettings" SET "IsDeleted" = TRUE, "ModifiedBy" = 2,
--          "ModifiedDate" = now()
--   WHERE "CompanyId" IS NULL AND "ParamCode" = 'PLATFORM_TENANT_ROOT_DOMAIN';
--   -- ⚠ with the row gone, {ROOTDOMAIN} cannot be substituted and both templates yield
--   --   NULL (a normal answer — the frontend falls back to a relative /{lang}/login).
-- =====================================================================================
