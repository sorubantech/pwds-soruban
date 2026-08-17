-- ============================================================================
-- Custom fields: text -> jsonb NORMALISATION  (idempotent, re-runnable)
-- ============================================================================
-- Run AFTER custom-fields-jsonb-preflight-audit.sql and BEFORE the migration.
--
-- This script does exactly two things, and deliberately nothing else:
--
--   1. QUARANTINE. Every value that will not parse as JSON is copied verbatim
--      into app."CustomFieldsQuarantine" before it is touched. Nothing is
--      destroyed -- the original text stays recoverable indefinitely, and the
--      restore statement is at the bottom of this file.
--
--   2. NULL the offending column, so the migration's cast succeeds.
--
-- It does NOT attempt to repair nearly-JSON (single quotes, trailing commas,
-- unquoted keys). A regex that "fixes" tenant data is a regex that eventually
-- corrupts tenant data silently. If the audit showed repairable patterns,
-- repair them with a deliberate UPDATE you have read, then re-run the audit.
--
-- Empty string and whitespace-only are NOT touched here. The migration's
-- USING NULLIF(BTRIM(...), '') already converts them to NULL as part of the
-- cast, so handling them twice would be noise.
-- ============================================================================

BEGIN;

-- WHY THIS TABLE IS NOT AN EF ENTITY
--
-- Ordering forces it. This script must run BEFORE the text->jsonb migration --
-- that is its whole purpose. An EF-managed table only exists after a migration
-- creates it, so making this an entity would mean shipping a separate
-- preparatory migration for a one-time cleanup, and the table would then live
-- in the domain model permanently.
--
-- It is migration scaffolding, not domain. Consequences of being outside EF,
-- stated plainly because they are real: no global tenant query filter, no soft
-- delete, no retention policy, and it does not appear in the model snapshot.
-- It holds raw tenant custom-field values, which may be PII.
--
-- Therefore it is TEMPORARY. Once the migration has been applied and the data
-- verified, drop it -- the DROP is at the bottom of this file. If you decide
-- you want a permanent quarantine/audit facility instead, it should be a
-- proper EF entity with a CompanyId, a tenant filter and a retention sweep;
-- do not simply leave this one in place and call it that.
CREATE TABLE IF NOT EXISTS app."CustomFieldsQuarantine" (
    "QuarantineId"   bigserial    PRIMARY KEY,
    "SchemaName"     varchar(128) NOT NULL,
    "TableName"      varchar(128) NOT NULL,
    "RowId"          int          NOT NULL,
    "CompanyId"      int          NULL,
    "OriginalValue"  text         NOT NULL,
    "QuarantinedAt"  timestamptz  NOT NULL DEFAULT now(),
    "Reason"         varchar(200) NOT NULL
);

-- Re-runnable: a row already quarantined is not quarantined a second time.
CREATE UNIQUE INDEX IF NOT EXISTS "ux_customfieldsquarantine_row"
    ON app."CustomFieldsQuarantine" ("SchemaName", "TableName", "RowId");

CREATE OR REPLACE FUNCTION pg_temp.cf_is_valid_json(txt text)
RETURNS boolean
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
    IF txt IS NULL THEN RETURN TRUE; END IF;
    IF BTRIM(txt) = '' THEN RETURN TRUE; END IF;
    PERFORM txt::jsonb;
    RETURN TRUE;
EXCEPTION WHEN others THEN
    RETURN FALSE;
END;
$$;

-- --- corg."Contacts" -------------------------------------------------------
INSERT INTO app."CustomFieldsQuarantine"
    ("SchemaName","TableName","RowId","CompanyId","OriginalValue","Reason")
SELECT 'corg', 'Contacts', c."ContactId", c."CompanyId", c."CustomFields",
       'CustomFields text is not parseable as JSON; nulled for text->jsonb migration'
FROM corg."Contacts" c
WHERE NOT pg_temp.cf_is_valid_json(c."CustomFields")
ON CONFLICT ("SchemaName","TableName","RowId") DO NOTHING;

UPDATE corg."Contacts"
SET "CustomFields" = NULL
WHERE NOT pg_temp.cf_is_valid_json("CustomFields");

-- --- corg."ContactEmailAddresses" ------------------------------------------
INSERT INTO app."CustomFieldsQuarantine"
    ("SchemaName","TableName","RowId","CompanyId","OriginalValue","Reason")
SELECT 'corg', 'ContactEmailAddresses', e."ContactEmailAddressId", e."CompanyId", e."CustomFields",
       'CustomFields text is not parseable as JSON; nulled for text->jsonb migration'
FROM corg."ContactEmailAddresses" e
WHERE NOT pg_temp.cf_is_valid_json(e."CustomFields")
ON CONFLICT ("SchemaName","TableName","RowId") DO NOTHING;

UPDATE corg."ContactEmailAddresses"
SET "CustomFields" = NULL
WHERE NOT pg_temp.cf_is_valid_json("CustomFields");

-- --- com."Countries" (shared reference data, no CompanyId) ------------------
INSERT INTO app."CustomFieldsQuarantine"
    ("SchemaName","TableName","RowId","CompanyId","OriginalValue","Reason")
SELECT 'com', 'Countries', c."CountryId", NULL, c."CustomFields",
       'CustomFields text is not parseable as JSON; nulled for text->jsonb migration'
FROM com."Countries" c
WHERE NOT pg_temp.cf_is_valid_json(c."CustomFields")
ON CONFLICT ("SchemaName","TableName","RowId") DO NOTHING;

UPDATE com."Countries"
SET "CustomFields" = NULL
WHERE NOT pg_temp.cf_is_valid_json("CustomFields");

-- Verification: must return zero rows before COMMIT.
SELECT 'corg.Contacts' AS still_blocking, COUNT(*) FROM corg."Contacts"
    WHERE NOT pg_temp.cf_is_valid_json("CustomFields")
UNION ALL SELECT 'corg.ContactEmailAddresses', COUNT(*) FROM corg."ContactEmailAddresses"
    WHERE NOT pg_temp.cf_is_valid_json("CustomFields")
UNION ALL SELECT 'com.Countries', COUNT(*) FROM com."Countries"
    WHERE NOT pg_temp.cf_is_valid_json("CustomFields");

-- Review the counts above (all must be 0), then:
COMMIT;
-- ROLLBACK;  -- use this instead if anything looks wrong

-- ---------------------------------------------------------------------------
-- RESTORE, if a quarantined value turns out to have mattered. Note the column
-- is jsonb by then, so the value must be repaired into valid JSON first --
-- which is the point: the original text is still here to repair FROM.
--
--   SELECT * FROM app."CustomFieldsQuarantine" ORDER BY "QuarantinedAt" DESC;
--
--   UPDATE corg."Contacts" c
--   SET "CustomFields" = '<hand-repaired JSON>'::jsonb
--   FROM app."CustomFieldsQuarantine" q
--   WHERE q."TableName" = 'Contacts' AND q."RowId" = c."ContactId"
--     AND q."QuarantineId" = <the row you reviewed>;
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- TEARDOWN -- run once the migration is applied and the quarantined rows have
-- been reviewed. This table is scaffolding and holds raw tenant values outside
-- EF, outside the tenant query filter and outside any retention policy. It
-- should not survive the migration it exists for.
--
-- Export first if you want to keep a record:
--   \copy (SELECT * FROM app."CustomFieldsQuarantine")
--       TO 'custom-fields-quarantine-backup.csv' WITH CSV HEADER
--
--   DROP TABLE app."CustomFieldsQuarantine";
-- ---------------------------------------------------------------------------
