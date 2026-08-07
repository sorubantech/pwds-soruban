-- =====================================================================================
-- PROMPT-13 (T-A19) — Billing Foundation §3.2
-- Seeds the four PLATFORM-scoped billing/pricing-policy settings.
--
-- These are PLATFORM rows, not tenant rows: CompanyId IS NULL. That NULL scope is the
-- documented reservation on sett.OrganizationSettings.CompanyId ("NULL is reserved for
-- platform-global baseline rows"), and it is what IPlatformSettingsService reads. Per-tenant
-- queries filter CompanyId = :companyId, which excludes these automatically — so no tenant's
-- Organization Settings screen picks them up.
--
-- They land in a NEW settings group 'PLATFORM' with IsVisibleInUI = false. A visible group
-- would render the platform's own pricing policy inside every tenant's settings UI.
--
-- CurrentValue is NULL on purpose so ParamDefaultValue governs; the platform pricing-policy
-- form (SavePlatformPricingPolicyCommand) writes CurrentValue when ops changes a value.
-- CanUserOverride = false: a tenant user must never override the platform's own pricing.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on (ParamCode + CompanyId IS NULL) for
-- active rows, and the group by SettingGroupCode. Safe to re-run.
--
-- ⚠ RESTART THE API AFTER COMMIT. PlatformSettingsService caches the whole platform snapshot
--   per scope; a running instance will not see these rows until it restarts.
--
-- NOTE ON DEFAULTS: FX_DERIVED_PRICING_ENABLED seeds 'false'. That is a deliberate behaviour
--   change from the pre-P-13 code, where the FX fallback was unconditional. Existing
--   subscriptions are unaffected — Subscription.Amount is a snapshot and is never re-resolved.
-- =====================================================================================

BEGIN;

-- ── PART A1 — the PLATFORM settings group (hidden from tenant UI) ────────────────────
INSERT INTO sett."SettingGroups"(
    "SettingGroupName", "SettingGroupCode", "SettingGroupIcon", "IsVisibleInUI", "OrderBy",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT 'Platform', 'PLATFORM', '🛠', false, 99, 2, now(), null, null, true, false
WHERE NOT EXISTS (
    SELECT 1 FROM sett."SettingGroups" g
    WHERE g."SettingGroupCode" = 'PLATFORM' AND g."IsDeleted" = false
);

-- ── PART A2 — the four §3.2 platform settings ───────────────────────────────────────
INSERT INTO sett."OrganizationSettings"(
    "CompanyId", "SettingGroupId", "ParamName", "ParamCode", "ParamDataType",
    "AllValues", "ParamDefaultValue", "CurrentValue", "Description", "CanUserOverride",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT
    NULL,
    sg."SettingGroupId",
    v.param_name,
    v.param_code,
    v.data_type,
    v.all_values,
    v.default_value,
    NULL,
    v.description,
    false,
    2, now(), null, null, true, false
FROM (VALUES
    ('SELF_SERVE_UPGRADE_ENABLED', 'Self Serve Upgrade Enabled', 'BOOLEAN', NULL,
     'true',
     'Platform kill switch for tenant self-serve plan upgrades. Off blocks every tenant regardless of their own setting.'),
    ('FX_DERIVED_PRICING_ENABLED', 'Fx Derived Pricing Enabled', 'BOOLEAN', NULL,
     'false',
     'When on, a plan with no curated price in the requested currency falls back to an FX-converted price. Off means such a plan simply has no price in that currency.'),
    ('FX_PRICING_UPLIFT_PERCENT',  'Fx Pricing Uplift Percent',  'NUMBER',  NULL,
     '20',
     'Percent added to an FX-converted amount before rounding, to absorb rate movement and gateway cross-currency cost. 0-200.'),
    ('FX_PRICING_ROUNDING',        'Fx Pricing Rounding',        'SELECT',
     'NONE,NEAREST_10,ENDING_9,ENDING_99',
     'ENDING_9',
     'How an FX-derived amount is rounded. Always rounds UP, so the derived price never lands below the converted-plus-uplift figure.')
) AS v(param_code, param_name, data_type, all_values, default_value, description)
CROSS JOIN sett."SettingGroups" sg
WHERE sg."SettingGroupCode" = 'PLATFORM'
  AND sg."IsDeleted" = false
  AND NOT EXISTS (
      SELECT 1 FROM sett."OrganizationSettings" s
      WHERE s."CompanyId" IS NULL
        AND s."ParamCode" = v.param_code
        AND s."IsDeleted" = false
  );

-- ── PART A3 — NumberSequence registration for INVOICE ───────────────────────────────
-- RecordOfflinePaymentCommand asks NumberSequenceGenerator for an invoice number.
-- The generator THROWS InvalidOperationException when the entity type has no eligibility
-- row, so these two inserts are not optional decoration. (The handler degrades to a
-- timestamped fallback rather than 500-ing, but a real sequence is the intended path —
-- and invoice numbering is statutory in most markets we sell into.)
--
-- Two tables, in order: public.EntityTypes (the identity) then sett.NumberSequenceEntityTypes
-- (the eligibility + defaults, FK'd to it).

INSERT INTO public."EntityTypes"(
    "EntityTypeName", "EntityTypeCode", "SchemaName", "TableName",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT 'Invoice', 'INVOICE', 'billing', 'Invoices', 2, now(), null, null, true, false
WHERE NOT EXISTS (
    SELECT 1 FROM public."EntityTypes" e
    WHERE e."EntityTypeCode" = 'INVOICE' AND e."IsDeleted" = false
);

-- Reset policy NEVER, matching the platform-wide choice made during the NumberSequence
-- entity rollout: an invoice series that restarts at 1 every January produces duplicate
-- numbers across years for anyone reading the number alone.
INSERT INTO sett."NumberSequenceEntityTypes"(
    "EntityTypeId", "NumberColumnName", "DefaultPrefix", "DefaultSuffix",
    "DefaultPattern", "DefaultSequenceResetPolicy", "IsEnabled",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT e."EntityTypeId", 'InvoiceNumber', 'INV', NULL,
       '{PREFIX}-{YYYY}-{SEQ:00000}', 'NEVER', true,
       2, now(), null, null, true, false
FROM public."EntityTypes" e
WHERE e."EntityTypeCode" = 'INVOICE'
  AND e."IsDeleted" = false
  AND NOT EXISTS (
      SELECT 1 FROM sett."NumberSequenceEntityTypes" t
      WHERE t."EntityTypeId" = e."EntityTypeId" AND t."IsDeleted" = false
  );

COMMIT;

-- =====================================================================================
-- PART B — VERIFY (run after COMMIT)
--
--   SELECT s."ParamCode", s."ParamDataType", s."ParamDefaultValue", s."CurrentValue",
--          s."AllValues", s."CanUserOverride", g."SettingGroupCode", g."IsVisibleInUI"
--   FROM   sett."OrganizationSettings" s
--   JOIN   sett."SettingGroups" g ON g."SettingGroupId" = s."SettingGroupId"
--   WHERE  s."CompanyId" IS NULL
--     AND  s."ParamCode" IN ('SELF_SERVE_UPGRADE_ENABLED','FX_DERIVED_PRICING_ENABLED',
--                            'FX_PRICING_UPLIFT_PERCENT','FX_PRICING_ROUNDING')
--     AND  s."IsDeleted" = false
--   ORDER BY s."ParamCode";
--   -- Expect exactly 4 rows, all CurrentValue NULL, all CanUserOverride false,
--   -- group PLATFORM with IsVisibleInUI = false.
--
--   SELECT e."EntityTypeCode", e."SchemaName", e."TableName",
--          t."NumberColumnName", t."DefaultPrefix", t."DefaultPattern",
--          t."DefaultSequenceResetPolicy", t."IsEnabled"
--   FROM   sett."NumberSequenceEntityTypes" t
--   JOIN   public."EntityTypes" e ON e."EntityTypeId" = t."EntityTypeId"
--   WHERE  e."EntityTypeCode" = 'INVOICE';      -- expect exactly 1 row, IsEnabled true
--
--   -- No tenant should have picked these up:
--   SELECT count(*) FROM sett."OrganizationSettings"
--   WHERE "CompanyId" IS NOT NULL
--     AND "ParamCode" LIKE 'FX_PRICING%' AND "IsDeleted" = false;   -- expect 0
-- =====================================================================================
