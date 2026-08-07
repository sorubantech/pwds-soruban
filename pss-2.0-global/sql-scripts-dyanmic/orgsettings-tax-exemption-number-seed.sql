-- =====================================================================================
-- ISSUE-3 — Online Donation Page (Screen #10) donation tax-receipt
-- Seeds the new "TAX_EXEMPTION_NUMBER" OrganizationSettings ParamCode (RECEIPTS group)
-- for every EXISTING tenant. Mirrors the OrgSettingsDefaultSeeder.cs entry added in the
-- same change (Base.Infrastructure/Seeders/OrgSettingsDefaultSeeder.cs, RECEIPTS group) —
-- that C# seeder already self-heals NEW tenants (and any tenant that first loads the
-- OrganizationSettings screen after this deploy), but existing tenants that never
-- re-trigger the seeder should get the row proactively so
-- DonationReceiptService.GenerateReceiptPdfAsync's GetStringAsync("TAX_EXEMPTION_NUMBER", ...)
-- resolves a per-tenant CurrentValue instead of always falling through to
-- Company.TaxId.
--
-- IDEMPOTENT: guarded by NOT EXISTS on (CompanyId, ParamCode) for active rows — safe to
-- re-run.
--
-- CurrentValue is intentionally left NULL/blank here (same as ParamDefaultValue = '' in
-- the C# default) — GenerateReceiptPdfAsync's caller supplies the fallback:
--   GetStringAsync("TAX_EXEMPTION_NUMBER", companyId, fallback: company.TaxId)
-- so a tenant with no explicit value still gets Company.TaxId at read time.
-- =====================================================================================

BEGIN;

INSERT INTO sett."OrganizationSettings"(
    "CompanyId", "SettingGroupId", "ParamName", "ParamCode", "ParamDataType",
    "AllValues", "ParamDefaultValue", "CurrentValue", "Description", "CanUserOverride",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT
    c."CompanyId",
    sg."SettingGroupId",
    'Tax Exemption Number',
    'TAX_EXEMPTION_NUMBER',
    'STRING',
    NULL,
    '',
    NULL,
    'Tax exemption / registration number printed on donation receipts',
    true,
    2, now(), null, null, true, false
FROM auth."Companies" c
CROSS JOIN sett."SettingGroups" sg
WHERE sg."SettingGroupCode" = 'RECEIPTS'
  AND sg."IsDeleted" = false
  AND NOT EXISTS (
      SELECT 1 FROM sett."OrganizationSettings" s
      WHERE s."CompanyId" = c."CompanyId"
        AND s."ParamCode" = 'TAX_EXEMPTION_NUMBER'
        AND s."IsDeleted" = false
  );

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--   SELECT "CompanyId", "ParamCode", "CurrentValue", "ParamDefaultValue"
--   FROM sett."OrganizationSettings"
--   WHERE "ParamCode" = 'TAX_EXEMPTION_NUMBER' AND "IsDeleted" = false
--   ORDER BY "CompanyId";
-- =====================================================================================
