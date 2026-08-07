-- =====================================================================================
-- PSS 2.0 — EMAIL PROVIDER OWNERSHIP §⑤
-- Pre-flight + idempotent seed for the two MasterData rows the PLATFORM-mode switch needs.
--
-- WHY THIS EXISTS
-- `usePlatformEmailProvider` writes a notify."CompanyEmailProviders" row whose EmailProviderId
-- and EmailProviderTypeId are FKs into sett."MasterDatas". The handler resolves them BY CODE at
-- runtime — never by hard-coded id, because the ids differ per environment depending on the order
-- the seeds were applied — and throws a message naming the missing code rather than letting it
-- surface as an opaque FK violation at SaveChanges:
--
--     EMAILPROVIDER      / SENDGRID   → which vendor the row points at
--     EMAILPROVIDERTYPE  / PRIMARY    → its role in the send chain
--
-- If either is absent, switching a tenant to platform sending fails with
-- "MasterData 'X' of type 'Y' is missing. Seed it before enabling platform email sending."
-- That is a hard stop by design: silently inventing the row would create a provider record
-- pointing at a vendor nobody chose.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS. Re-running is a no-op.
-- Additive only: no DROP, no UPDATE of existing rows, no schema change, no migration.
-- USER-OWNED: written here, applied by you. Never executed from application code.
--
-- These rows are GLOBAL (CompanyId NULL, IsSystem TRUE) — the vendor list is the platform's
-- vocabulary, not a per-tenant one.
-- =====================================================================================


-- ── 1. PRE-CHECK — run this first. In most databases both rows already exist ──────────────────
-- (the email-provider screen's vendor dropdown is fed from EMAILPROVIDER), in which case blocks
-- 2–4 all no-op and you only need block 5's verification.
SELECT mdt."TypeCode",
       md."DataValue",
       md."DataName",
       md."CompanyId",
       md."IsActive",
       md."IsDeleted"
FROM sett."MasterDataTypes" mdt
LEFT JOIN sett."MasterDatas" md ON md."MasterDataTypeId" = mdt."MasterDataTypeId"
WHERE mdt."TypeCode" IN ('EMAILPROVIDER', 'EMAILPROVIDERTYPE')
ORDER BY mdt."TypeCode", md."OrderBy", md."DataValue";


-- ── 2. The two MasterDataTypes ───────────────────────────────────────────────────────────────
INSERT INTO sett."MasterDataTypes"(
    "TypeCode", "TypeName", "Description", "IsSystem",
    "AllowMultipleSelection", "AllowUserInput",
    "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
SELECT v.code, v.name, v.descr, TRUE, FALSE, FALSE, 2, now(), TRUE, FALSE
FROM (VALUES
    ('EMAILPROVIDER',     'Email Provider',      'Email delivery vendors (SendGrid, SMTP, …)'),
    ('EMAILPROVIDERTYPE', 'Email Provider Type', 'Role of a configured provider in the send chain')
) AS v(code, name, descr)
WHERE NOT EXISTS (
    SELECT 1 FROM sett."MasterDataTypes" t WHERE t."TypeCode" = v.code
);


-- ── 3. EMAILPROVIDER / SENDGRID ──────────────────────────────────────────────────────────────
-- The vendor the platform sends through. The tenant row created by usePlatformEmailProvider is a
-- POINTER at ops."PlatformCommunicationProviders" — it stores ProviderConfiguration = '{}' and the
-- real API key is resolved at send time — so this row names the vendor, it does not carry a key.
INSERT INTO sett."MasterDatas"(
    "MasterDataTypeId", "DataName", "DataValue", "DataSetting", "Description",
    "OrderBy", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted", "IsSystem", "CompanyId")
SELECT
    mdt."MasterDataTypeId",
    'SendGrid', 'SENDGRID', 'SendGrid', 'Twilio SendGrid HTTP API',
    (SELECT COALESCE(MAX(m."OrderBy"), 0) + 1
     FROM sett."MasterDatas" m WHERE m."MasterDataTypeId" = mdt."MasterDataTypeId"),
    2, now(), TRUE, FALSE, TRUE, NULL
FROM sett."MasterDataTypes" mdt
WHERE mdt."TypeCode" = 'EMAILPROVIDER'
  AND NOT EXISTS (
    SELECT 1 FROM sett."MasterDatas" md
    WHERE md."MasterDataTypeId" = mdt."MasterDataTypeId"
      AND md."DataValue" = 'SENDGRID'
);


-- ── 4. EMAILPROVIDERTYPE / PRIMARY ───────────────────────────────────────────────────────────
INSERT INTO sett."MasterDatas"(
    "MasterDataTypeId", "DataName", "DataValue", "DataSetting", "Description",
    "OrderBy", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted", "IsSystem", "CompanyId")
SELECT
    mdt."MasterDataTypeId",
    'Primary', 'PRIMARY', 'Primary', 'The provider all sends go through first',
    (SELECT COALESCE(MAX(m."OrderBy"), 0) + 1
     FROM sett."MasterDatas" m WHERE m."MasterDataTypeId" = mdt."MasterDataTypeId"),
    2, now(), TRUE, FALSE, TRUE, NULL
FROM sett."MasterDataTypes" mdt
WHERE mdt."TypeCode" = 'EMAILPROVIDERTYPE'
  AND NOT EXISTS (
    SELECT 1 FROM sett."MasterDatas" md
    WHERE md."MasterDataTypeId" = mdt."MasterDataTypeId"
      AND md."DataValue" = 'PRIMARY'
);


-- ── 5. VERIFICATION — expect exactly two rows, both IsActive TRUE / IsDeleted FALSE ───────────
-- The handler filters on IsActive = TRUE AND IsDeleted = FALSE, so a soft-deleted or deactivated
-- row reads as missing.
SELECT mdt."TypeCode", md."DataValue", md."MasterDataId", md."IsActive", md."IsDeleted"
FROM sett."MasterDatas" md
JOIN sett."MasterDataTypes" mdt ON mdt."MasterDataTypeId" = md."MasterDataTypeId"
WHERE (mdt."TypeCode" = 'EMAILPROVIDER'     AND md."DataValue" = 'SENDGRID')
   OR (mdt."TypeCode" = 'EMAILPROVIDERTYPE' AND md."DataValue" = 'PRIMARY')
ORDER BY mdt."TypeCode";


-- ── 6. RELATED PRE-FLIGHT — the ops row the platform mode actually sends through ──────────────
-- Platform mode fails CLOSED: with no active default EMAIL row here, usePlatformEmailProvider
-- refuses with "Platform email sending is not configured. Contact support." and platformEmailSenderInfo
-- reports isAvailable = false. Seeded separately by ops-platform-communication-provider-seed.sql.
-- The sending domain the tenant's From address is locked to is DERIVED from "DefaultFromEmail"
-- below — whatever sits to the right of the '@'.
SELECT "PlatformCommunicationProviderId", "Channel", "ProviderType", "DisplayName",
       "DefaultFromEmail", "DefaultFromName", "IsDefault", "IsActive", "IsDeleted"
FROM ops."PlatformCommunicationProviders"
WHERE "Channel" = 'EMAIL'
ORDER BY "IsDefault" DESC, "Priority";
