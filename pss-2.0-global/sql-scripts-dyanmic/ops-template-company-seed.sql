-- =====================================================================================
-- P-01 T-A3 — Template-company SHELL seed (tenant-provisioning clone source)
-- -------------------------------------------------------------------------------------
-- Inserts a SINGLE app."Companies" row that the ProvisionTenantCommand (P-03) clones from
-- when standing up a new tenant. This is only the SHELL: its roles / master data / settings
-- / fields are populated LATER by configuring this company through the normal app UI
-- (design §9.2 option A) — that population is an operational step, NOT part of this script.
--
-- Marker row:
--   CompanyCode = '__TEMPLATE__'            (the clone-source lookup key)
--   CompanyName = '[TEMPLATE] Do Not Delete'
--   IsInternal  = true                       (platform-internal; excluded from tenant lists)
--   Status      = 'PROVISIONING'             (deliberately non-ACTIVE marker)
--
-- NOT-NULL columns supplied (per app."Companies" schema): CompanyCode, CompanyName,
-- CompanyHeader, CompanyFooter, Address, CountryId, IsInternal. CountryId resolves to the
-- lowest existing active country so the FK is valid on any environment.
--
-- IDEMPOTENT: guarded by NOT EXISTS on CompanyCode='__TEMPLATE__' — re-running is a no-op.
-- SAFE: additive only. No DROP, no UPDATE, no schema change.
--
-- PREREQUISITE: run AFTER the P-01 migration (which adds Companies.Status / IsInternal /
-- OnboardedOn / SourceLeadId) has been applied, and after at least one row exists in
-- com."Countries".
-- =====================================================================================

BEGIN;

INSERT INTO app."Companies"
  ("CompanyCode","CompanyName","CompanyHeader","CompanyFooter","Address","CountryId",
   "Status","IsInternal","CreatedDate","IsActive","IsDeleted")
SELECT
  '__TEMPLATE__',
  '[TEMPLATE] Do Not Delete',
  '[TEMPLATE] Do Not Delete',
  '[TEMPLATE] Do Not Delete',
  'N/A',
  (SELECT MIN("CountryId") FROM com."Countries" WHERE COALESCE("IsDeleted", false) = false),
  'PROVISIONING',
  true,
  now(),
  true,
  false
WHERE NOT EXISTS (
  SELECT 1 FROM app."Companies" c WHERE c."CompanyCode" = '__TEMPLATE__'
);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT; expect exactly one row):
--   SELECT "CompanyId","CompanyCode","CompanyName","Status","IsInternal"
--   FROM app."Companies" WHERE "CompanyCode" = '__TEMPLATE__';
-- =====================================================================================
