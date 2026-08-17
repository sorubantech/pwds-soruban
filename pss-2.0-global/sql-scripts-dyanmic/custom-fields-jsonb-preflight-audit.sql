-- ============================================================================
-- Custom fields: text -> jsonb PRE-FLIGHT AUDIT  (read-only, safe to re-run)
-- ============================================================================
-- Run this BEFORE the Change_Text_To_JsonB_To_CustomFields_In_Contact_Entities
-- migration. It changes nothing. It answers one question: which rows will make
-- the ALTER COLUMN abort?
--
-- The migration casts with:
--     USING NULLIF(BTRIM("CustomFields"), '')::jsonb
--
-- so NULL, '' and whitespace-only are already handled and land as NULL. What
-- still aborts the whole migration is a row holding text that is not parseable
-- as JSON. One such row in any of the three tables rolls the entire migration
-- back -- there is no partial application and no row-level skip.
--
-- A row whose JSON parses but is not an OBJECT (e.g. a bare "123", "null" or
-- an array) will NOT abort the migration -- jsonb accepts all of those. It will
-- however be rejected on the next write by CustomFieldDocumentValidator, which
-- requires the root to be an object. Those rows are reported separately because
-- they are a data-quality problem, not a migration blocker.
-- ============================================================================

-- Parse probe. Cannot be done inline portably: a failed ::jsonb cast raises
-- rather than returning false, and pg_input_is_valid() only exists on PG16+.
-- Written as a temporary function so this script leaves no schema residue --
-- it disappears with the session.
CREATE OR REPLACE FUNCTION pg_temp.cf_is_valid_json(txt text)
RETURNS boolean
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
    IF txt IS NULL THEN RETURN TRUE; END IF;          -- NULL casts to NULL, fine
    IF BTRIM(txt) = '' THEN RETURN TRUE; END IF;      -- NULLIF handles it, fine
    PERFORM txt::jsonb;
    RETURN TRUE;
EXCEPTION WHEN others THEN
    RETURN FALSE;
END;
$$;

-- ---------------------------------------------------------------------------
-- 1. SUMMARY -- one row per carrier table.
--    blocking_invalid_json > 0 anywhere means DO NOT RUN THE MIGRATION YET.
-- ---------------------------------------------------------------------------
SELECT 'corg.Contacts' AS table_name,
       COUNT(*)                                                            AS total_rows,
       COUNT(*) FILTER (WHERE "CustomFields" IS NULL)                      AS is_null,
       COUNT(*) FILTER (WHERE "CustomFields" = '')                         AS is_empty_string,
       COUNT(*) FILTER (WHERE "CustomFields" <> '' AND BTRIM("CustomFields") = '') AS is_whitespace_only,
       COUNT(*) FILTER (WHERE NOT pg_temp.cf_is_valid_json("CustomFields")) AS blocking_invalid_json,
       COUNT(*) FILTER (WHERE pg_temp.cf_is_valid_json("CustomFields")
                          AND BTRIM(COALESCE("CustomFields",'')) <> ''
                          AND jsonb_typeof(BTRIM("CustomFields")::jsonb) <> 'object') AS valid_json_not_object
FROM corg."Contacts"
UNION ALL
SELECT 'corg.ContactEmailAddresses',
       COUNT(*),
       COUNT(*) FILTER (WHERE "CustomFields" IS NULL),
       COUNT(*) FILTER (WHERE "CustomFields" = ''),
       COUNT(*) FILTER (WHERE "CustomFields" <> '' AND BTRIM("CustomFields") = ''),
       COUNT(*) FILTER (WHERE NOT pg_temp.cf_is_valid_json("CustomFields")),
       COUNT(*) FILTER (WHERE pg_temp.cf_is_valid_json("CustomFields")
                          AND BTRIM(COALESCE("CustomFields",'')) <> ''
                          AND jsonb_typeof(BTRIM("CustomFields")::jsonb) <> 'object')
FROM corg."ContactEmailAddresses"
UNION ALL
SELECT 'com.Countries',
       COUNT(*),
       COUNT(*) FILTER (WHERE "CustomFields" IS NULL),
       COUNT(*) FILTER (WHERE "CustomFields" = ''),
       COUNT(*) FILTER (WHERE "CustomFields" <> '' AND BTRIM("CustomFields") = ''),
       COUNT(*) FILTER (WHERE NOT pg_temp.cf_is_valid_json("CustomFields")),
       COUNT(*) FILTER (WHERE pg_temp.cf_is_valid_json("CustomFields")
                          AND BTRIM(COALESCE("CustomFields",'')) <> ''
                          AND jsonb_typeof(BTRIM("CustomFields")::jsonb) <> 'object')
FROM com."Countries";

-- ---------------------------------------------------------------------------
-- 2. THE BLOCKING ROWS themselves, with enough identity to go and look at them.
--    If this returns nothing, the migration will succeed.
-- ---------------------------------------------------------------------------
SELECT 'corg.Contacts' AS table_name,
       "ContactId"     AS row_id,
       "CompanyId",
       LEFT("CustomFields", 300) AS custom_fields_head,
       LENGTH("CustomFields")    AS value_length
FROM corg."Contacts"
WHERE NOT pg_temp.cf_is_valid_json("CustomFields")
UNION ALL
SELECT 'corg.ContactEmailAddresses',
       "ContactEmailAddressId",
       "CompanyId",
       LEFT("CustomFields", 300),
       LENGTH("CustomFields")
FROM corg."ContactEmailAddresses"
WHERE NOT pg_temp.cf_is_valid_json("CustomFields")
UNION ALL
-- Countries is shared reference data and carries no CompanyId column.
SELECT 'com.Countries',
       "CountryId",
       NULL::int,
       LEFT("CustomFields", 300),
       LENGTH("CustomFields")
FROM com."Countries"
WHERE NOT pg_temp.cf_is_valid_json("CustomFields")
ORDER BY 1, 2;

-- ---------------------------------------------------------------------------
-- 3. NON-BLOCKING but wrong: parses as JSON, root is not an object.
--    These migrate fine and then fail their next save. Worth knowing about now.
-- ---------------------------------------------------------------------------
SELECT 'corg.Contacts' AS table_name,
       "ContactId"     AS row_id,
       "CompanyId",
       jsonb_typeof(BTRIM("CustomFields")::jsonb) AS json_root_type,
       LEFT("CustomFields", 300)                  AS custom_fields_head
FROM corg."Contacts"
WHERE pg_temp.cf_is_valid_json("CustomFields")
  AND BTRIM(COALESCE("CustomFields",'')) <> ''
  AND jsonb_typeof(BTRIM("CustomFields")::jsonb) <> 'object'
UNION ALL
SELECT 'corg.ContactEmailAddresses',
       "ContactEmailAddressId",
       "CompanyId",
       jsonb_typeof(BTRIM("CustomFields")::jsonb),
       LEFT("CustomFields", 300)
FROM corg."ContactEmailAddresses"
WHERE pg_temp.cf_is_valid_json("CustomFields")
  AND BTRIM(COALESCE("CustomFields",'')) <> ''
  AND jsonb_typeof(BTRIM("CustomFields")::jsonb) <> 'object'
UNION ALL
SELECT 'com.Countries',
       "CountryId",
       NULL::int,
       jsonb_typeof(BTRIM("CustomFields")::jsonb),
       LEFT("CustomFields", 300)
FROM com."Countries"
WHERE pg_temp.cf_is_valid_json("CustomFields")
  AND BTRIM(COALESCE("CustomFields",'')) <> ''
  AND jsonb_typeof(BTRIM("CustomFields")::jsonb) <> 'object'
ORDER BY 1, 2;

-- ---------------------------------------------------------------------------
-- WHAT TO DO WITH BLOCKING ROWS
--
-- There is no automatic answer, and there should not be one -- the content is
-- tenant data and a script that "cleans" it is a script that deletes it.
-- Look at query 2's output and decide per pattern:
--
--   * Column holds something that was never JSON (a name, a CSV fragment, a
--     stray id). Almost certainly a bug in an old writer. Quarantine the value
--     into an audit table, then NULL the column -- see the companion script
--     custom-fields-jsonb-normalise.sql, which does exactly that and nothing
--     more.
--
--   * Column holds nearly-JSON (single quotes, trailing comma, unquoted key).
--     Repairable, but repair it deliberately with an UPDATE you have read,
--     not with a regex sweep.
--
--   * Handful of rows on a demo/seed tenant. Deleting the value is fine --
--     but confirm the tenant first with the CompanyId in the output.
--
-- Re-run this script after any remediation. Proceed to the migration only when
-- query 2 returns zero rows.
-- ---------------------------------------------------------------------------
