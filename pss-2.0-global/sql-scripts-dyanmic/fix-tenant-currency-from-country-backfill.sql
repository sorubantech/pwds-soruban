-- ═══════════════════════════════════════════════════════════════════════════════════════════════
--  Backfill — align every tenant's currency/country OrganizationSettings to its OWN country.
--
--  Defect: ProvisionTenant Step 6 (SEED_SETTINGS) cloned sett."OrganizationSettings" verbatim from
--  the __TEMPLATE__ company, CurrentValue included. DEFAULT_CURRENCY / ALLOWED_CURRENCIES /
--  DEFAULT_COUNTRY are country-derived facts, so every tenant inherited the template's values
--  regardless of the country captured in Step 1. An Indian tenant came out with the template's
--  currency, not INR.
--
--  com.Countries."CurrencyId" is the authority. Stored forms mirror UpdateCompanySettings so
--  Screen #75/#85 round-trip cleanly:
--      DEFAULT_CURRENCY    Currency.CurrencyCode   ISO string, e.g. 'INR'
--      ALLOWED_CURRENCIES  JSON array of codes,    e.g. '["INR"]'
--      DEFAULT_COUNTRY     Country.CountryName     the NAME, not the short code
--
--  NOTE this is the OPERATING currency. The BILLING currency (billing."Subscriptions"."CurrencyId",
--  set from the wizard's CurrencyId) is a separate fact and is deliberately NOT touched here — an
--  Indian charity may legitimately be invoiced in USD.
--
--  The code fix lands in ProvisionTenant.AlignRegionalSettingsToCountryAsync, so new tenants are
--  correct at provisioning time. This script repairs the ones already created.
--
--  RUN PART A FIRST.
-- ═══════════════════════════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  PART A — verification: what each tenant HAS vs what its country says it SHOULD have.
--  Rows where mismatch = true are what PART B rewrites.
-- ───────────────────────────────────────────────────────────────────────────────────────────────
SELECT c."CompanyId",
       c."CompanyCode",
       ctry."CountryName",
       cur."CurrencyCode"                      AS should_be,
       cur_now."CurrentValue"                  AS default_currency_now,
       allowed_now."CurrentValue"              AS allowed_currencies_now,
       country_now."CurrentValue"              AS default_country_now,
       (cur_now."CurrentValue" IS DISTINCT FROM cur."CurrencyCode") AS mismatch
FROM app."Companies" c
LEFT JOIN com."Countries"  ctry ON ctry."CountryId"  = c."CountryId"
LEFT JOIN com."Currencies" cur  ON cur."CurrencyId"  = ctry."CurrencyId"
LEFT JOIN sett."OrganizationSettings" cur_now
       ON cur_now."CompanyId" = c."CompanyId"
      AND cur_now."ParamCode" = 'DEFAULT_CURRENCY'   AND cur_now."IsDeleted" IS NOT TRUE
LEFT JOIN sett."OrganizationSettings" allowed_now
       ON allowed_now."CompanyId" = c."CompanyId"
      AND allowed_now."ParamCode" = 'ALLOWED_CURRENCIES' AND allowed_now."IsDeleted" IS NOT TRUE
LEFT JOIN sett."OrganizationSettings" country_now
       ON country_now."CompanyId" = c."CompanyId"
      AND country_now."ParamCode" = 'DEFAULT_COUNTRY'  AND country_now."IsDeleted" IS NOT TRUE
WHERE c."IsDeleted" IS NOT TRUE
ORDER BY c."CompanyId";

-- A2. Countries whose CurrencyId does not resolve. PART B SKIPS these companies rather than
--     blanking their settings — fix the country data, then re-run.
SELECT DISTINCT ctry."CountryId", ctry."CountryName", ctry."CurrencyId"
FROM app."Companies" c
JOIN com."Countries" ctry ON ctry."CountryId" = c."CountryId"
LEFT JOIN com."Currencies" cur
       ON cur."CurrencyId" = ctry."CurrencyId" AND cur."IsDeleted" IS NOT TRUE
WHERE c."IsDeleted" IS NOT TRUE AND cur."CurrencyId" IS NULL;


-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  PART B — rewrite. Update-then-insert per ParamCode; only touches tenant rows
--  (CompanyId IS NOT NULL), never the platform-default row.
--
--  SettingGroupIds mirror sett."SettingGroups" / UpdateCompanySettings.ParamCatalog:
--      2  = Fundraising  (DEFAULT_CURRENCY, ALLOWED_CURRENCIES)
--      11 = Regional     (DEFAULT_COUNTRY)
-- ───────────────────────────────────────────────────────────────────────────────────────────────
BEGIN;

-- Resolved target per company. Companies with an unresolvable currency drop out of the join
-- entirely and are therefore left untouched.
CREATE TEMP TABLE tmp_target ON COMMIT DROP AS
SELECT c."CompanyId",
       cur."CurrencyCode",
       ctry."CountryName"
FROM app."Companies" c
JOIN com."Countries"  ctry ON ctry."CountryId" = c."CountryId" AND ctry."IsDeleted" IS NOT TRUE
JOIN com."Currencies" cur  ON cur."CurrencyId" = ctry."CurrencyId" AND cur."IsDeleted" IS NOT TRUE
WHERE c."IsDeleted" IS NOT TRUE;

-- B1 — update existing rows
UPDATE sett."OrganizationSettings" os
SET "CurrentValue" = t."CurrencyCode",
    "ModifiedDate" = now() AT TIME ZONE 'UTC'
FROM tmp_target t
WHERE os."CompanyId" = t."CompanyId"
  AND os."ParamCode" = 'DEFAULT_CURRENCY'
  AND os."IsDeleted" IS NOT TRUE
  AND os."CurrentValue" IS DISTINCT FROM t."CurrencyCode";

UPDATE sett."OrganizationSettings" os
SET "CurrentValue" = json_build_array(t."CurrencyCode")::text,
    "ModifiedDate" = now() AT TIME ZONE 'UTC'
FROM tmp_target t
WHERE os."CompanyId" = t."CompanyId"
  AND os."ParamCode" = 'ALLOWED_CURRENCIES'
  AND os."IsDeleted" IS NOT TRUE
  AND os."CurrentValue" IS DISTINCT FROM json_build_array(t."CurrencyCode")::text;

UPDATE sett."OrganizationSettings" os
SET "CurrentValue" = t."CountryName",
    "ModifiedDate" = now() AT TIME ZONE 'UTC'
FROM tmp_target t
WHERE os."CompanyId" = t."CompanyId"
  AND os."ParamCode" = 'DEFAULT_COUNTRY'
  AND os."IsDeleted" IS NOT TRUE
  AND os."CurrentValue" IS DISTINCT FROM t."CountryName";

-- B2 — insert rows for tenants that never had them
INSERT INTO sett."OrganizationSettings"
    ("CompanyId","SettingGroupId","ParamCode","ParamName","ParamDataType",
     "ParamDefaultValue","AllValues","CanUserOverride","CurrentValue","Description",
     "CreatedDate","IsActive","IsDeleted")
SELECT t."CompanyId", v.group_id, v.param_code, v.param_name, v.data_type,
       NULL, NULL, FALSE, v.value, NULL,
       now() AT TIME ZONE 'UTC', TRUE, FALSE
FROM tmp_target t
CROSS JOIN LATERAL (VALUES
    (2,  'DEFAULT_CURRENCY',   'Default Currency',   'SELECT', t."CurrencyCode"),
    (2,  'ALLOWED_CURRENCIES', 'Allowed Currencies', 'JSON',   json_build_array(t."CurrencyCode")::text),
    (11, 'DEFAULT_COUNTRY',    'Default Country',    'SELECT', t."CountryName")
) AS v(group_id, param_code, param_name, data_type, value)
WHERE NOT EXISTS (
    SELECT 1 FROM sett."OrganizationSettings" x
    WHERE x."CompanyId" = t."CompanyId"
      AND x."ParamCode" = v.param_code
      AND x."IsDeleted" IS NOT TRUE);

-- Post-check: re-run PART A's first query. Every row should show mismatch = false.

COMMIT;
-- ROLLBACK;

--  After COMMIT: IOrgSettingsService caches per company. Restart the API (or let the cache expire)
--  before reading Screen #75 / #85, otherwise the old currency lingers in the response.
