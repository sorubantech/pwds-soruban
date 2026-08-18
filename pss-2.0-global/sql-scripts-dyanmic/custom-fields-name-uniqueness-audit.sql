-- =====================================================================================
-- custom-fields-name-uniqueness-audit.sql
--
-- READ-ONLY.  Nothing here writes, renames, deletes or creates anything.
-- Run this BEFORE the unique-index migration. If any section returns rows, the
-- CREATE UNIQUE INDEX will fail, and it must fail — those rows are the pre-existing
-- collisions the index exists to prevent.
--
-- Idempotent by construction: it is four SELECTs.
--
-- ---------------------------------------------------------------------------------
-- THE RULE BEING AUDITED
--
--   Field.IsSystem = true    the name is unique GLOBALLY. A built-in field is the same
--                            field for every organisation on the installation.
--   Field.IsSystem = false   the name is unique WITHIN A COMPANY. Two organisations may
--                            both define "Region"; that is the point of a custom field.
--   Cross-partition          a custom field may not reuse a SYSTEM field's name, because
--                            the tenant sees system and custom fields in one list and one
--                            form, and a duplicate label there is indistinguishable.
--
-- Comparison is case-insensitive, on lower("FieldName"). Field.FieldName carries
-- [CaseFormat("title")], which AuditableEntityInterceptor applies at SaveChanges — so
-- values written through the API are already title-cased, but values written by seeds,
-- migrations and raw SQL bypass the interceptor entirely and are whatever was typed.
-- lower() is the only comparison that is true for both populations.
--
-- ---------------------------------------------------------------------------------
-- THE INDEXES THIS AUDIT CLEARS THE WAY FOR
--
-- Two PARTIAL unique indexes, split on IsSystem, because the SCOPE of the rule changes
-- with IsSystem and a single index cannot express two different scopes:
--
--   ux_fields_system_name  UNIQUE (lower("FieldName"))
--                          WHERE "IsSystem" = true AND "IsDeleted" = false
--
--   ux_fields_custom_name  UNIQUE (COALESCE("CompanyId", 0), lower("FieldName"))
--                          WHERE "IsSystem" = false AND "IsDeleted" = false
--
-- WHY COALESCE AND NOT NULLS NOT DISTINCT.  "CompanyId" is nullable, and in a plain
-- multi-column unique index PostgreSQL treats NULLs as distinct from each other — so ten
-- platform-wide rows all named "Region" with a NULL CompanyId would all be permitted, and
-- the one case that most needs catching (a field inherited by EVERY tenant) would be the
-- one case unprotected. PostgreSQL 15 added UNIQUE NULLS NOT DISTINCT for exactly this,
-- but pinning a schema constraint to a server major version is a deployment liability that
-- COALESCE("CompanyId", 0) avoids at no cost: company id 0 does not exist (app."Companies"
-- identity starts at 1), so folding NULL onto 0 collides with nothing real and makes the
-- platform-wide rows a single ordinary bucket that the index polices like any other.
--
-- WHY PARTIAL ON IsDeleted.  Soft-deleted rows stay in the table forever. Without the
-- predicate, deleting "Region" and creating it again would be refused by the index — the
-- old row still holds the name. Every reader of sett."Fields" already filters
-- IsDeleted = false, so the index agrees with what the application considers to exist.
--
-- IsActive is deliberately NOT in the predicate. A deactivated field is still present and
-- may be reactivated, so its name must stay reserved; and CreateCustomFieldValidator's
-- check omits IsActive too, which is what keeps the friendly message and the hard
-- constraint from disagreeing.
--
-- WHAT THE INDEXES CANNOT DO.  The cross-partition rule — a CUSTOM field may not reuse a
-- SYSTEM field's name — is not expressible as a unique index at all: the two rows live in
-- different partial indexes and neither sees the other. PostgreSQL has no cross-row CHECK.
-- It is enforced in CreateCustomFieldValidator only, and is therefore best-effort under
-- concurrency: two simultaneous requests could in principle create a custom field named
-- after a system field created in the same instant. The consequence is a duplicate LABEL,
-- not data corruption — the two rows have different FieldIds and different documents key
-- off FieldKey — so an exclusion constraint or a trigger is not warranted. Section 3
-- below is how you find any that slip through.
-- =====================================================================================


-- -------------------------------------------------------------------------------------
-- 0. Population. Run this first so the numbers below have a denominator.
-- -------------------------------------------------------------------------------------
SELECT
    count(*)                                                        AS total_rows,
    count(*) FILTER (WHERE "IsDeleted" = false)                     AS live_rows,
    count(*) FILTER (WHERE "IsDeleted" = false AND "IsSystem")      AS live_system,
    count(*) FILTER (WHERE "IsDeleted" = false AND NOT "IsSystem")  AS live_custom,
    count(*) FILTER (WHERE "IsDeleted" = false AND NOT "IsSystem"
                       AND "CompanyId" IS NULL)                     AS live_custom_no_company
FROM sett."Fields";

-- NOTE ON live_custom_no_company.  Every row in that count is a custom field with no
-- owning company, which every tenant on the installation inherits and sees in their own
-- field list. CreateCustomFieldHandler now refuses to create these, but rows that predate
-- that refusal are still here. They are not necessarily wrong — a deliberately
-- platform-wide field is legitimate — but each one should be a decision somebody made,
-- not a side effect of a request that ran without an organisation context. Review them:
--
--   SELECT "FieldId", "FieldName", "FieldCode", "FieldKey", "CreatedDate", "CreatedBy"
--   FROM sett."Fields"
--   WHERE "IsDeleted" = false AND NOT "IsSystem" AND "CompanyId" IS NULL
--   ORDER BY "CreatedDate";


-- -------------------------------------------------------------------------------------
-- 1. SYSTEM vs SYSTEM  — blocks ux_fields_system_name.
--
-- Two built-in fields sharing a name, case-insensitively. Almost always a seed applied
-- twice, or the same field seeded under two migrations.
-- -------------------------------------------------------------------------------------
SELECT
    lower(f."FieldName")                                    AS collides_on,
    count(*)                                                AS row_count,
    array_agg(f."FieldId"    ORDER BY f."FieldId")          AS field_ids,
    array_agg(f."FieldName"  ORDER BY f."FieldId")          AS names_as_stored,
    array_agg(f."FieldCode"  ORDER BY f."FieldId")          AS field_codes,
    array_agg(f."CompanyId"  ORDER BY f."FieldId")          AS company_ids
FROM   sett."Fields" f
WHERE  f."IsDeleted" = false
  AND  f."IsSystem"  = true
GROUP  BY lower(f."FieldName")
HAVING count(*) > 1
ORDER  BY count(*) DESC, 1;


-- -------------------------------------------------------------------------------------
-- 2. CUSTOM vs CUSTOM, WITHIN ONE COMPANY  — blocks ux_fields_custom_name.
--
-- company_id 0 in the output means the real CompanyId is NULL: platform-wide rows, folded
-- into one bucket exactly as the index folds them.
-- -------------------------------------------------------------------------------------
SELECT
    COALESCE(f."CompanyId", 0)                              AS company_id,
    c."CompanyName"                                         AS company_name,
    lower(f."FieldName")                                    AS collides_on,
    count(*)                                                AS row_count,
    array_agg(f."FieldId"    ORDER BY f."FieldId")          AS field_ids,
    array_agg(f."FieldName"  ORDER BY f."FieldId")          AS names_as_stored,
    array_agg(f."FieldKey"   ORDER BY f."FieldId")          AS field_keys
FROM   sett."Fields" f
LEFT   JOIN app."Companies" c ON c."CompanyId" = f."CompanyId"
WHERE  f."IsDeleted" = false
  AND  f."IsSystem"  = false
GROUP  BY COALESCE(f."CompanyId", 0), c."CompanyName", lower(f."FieldName")
HAVING count(*) > 1
ORDER  BY count(*) DESC, 1, 3;


-- -------------------------------------------------------------------------------------
-- 3. CUSTOM vs SYSTEM  — does NOT block either index. Validator-only rule.
--
-- These rows will survive the migration. They are reported because they are the ones a
-- unique index can never catch (section header explains why), so this query is the only
-- instrument that finds them. Each row is a tenant seeing two identically-labelled fields
-- in one list.
--
-- Fix by renaming the CUSTOM side, never the system side: the system name is referenced by
-- seeds, grid configuration and export column headers across every tenant.
-- -------------------------------------------------------------------------------------
SELECT
    cf."FieldId"                                            AS custom_field_id,
    cf."FieldName"                                          AS custom_field_name,
    cf."FieldKey"                                           AS custom_field_key,
    COALESCE(cf."CompanyId", 0)                             AS company_id,
    c."CompanyName"                                         AS company_name,
    sf."FieldId"                                            AS system_field_id,
    sf."FieldName"                                          AS system_field_name,
    sf."FieldCode"                                          AS system_field_code
FROM   sett."Fields" cf
JOIN   sett."Fields" sf
       ON  sf."IsDeleted" = false
       AND sf."IsSystem"  = true
       AND lower(sf."FieldName") = lower(cf."FieldName")
LEFT   JOIN app."Companies" c ON c."CompanyId" = cf."CompanyId"
WHERE  cf."IsDeleted" = false
  AND  cf."IsSystem"  = false
ORDER  BY 4, 2;


-- -------------------------------------------------------------------------------------
-- 4. INHERITED vs OWNED  — does NOT block either index. Reported for completeness.
--
-- A tenant's own custom field with the same name as a platform-wide (NULL CompanyId)
-- custom field. The index puts these in different buckets (0 and the real company id) and
-- permits them; the validator refuses to create new ones. Existing pairs mean the tenant
-- sees the label twice.
-- -------------------------------------------------------------------------------------
SELECT
    owned."CompanyId"                                       AS company_id,
    c."CompanyName"                                         AS company_name,
    owned."FieldId"                                         AS owned_field_id,
    owned."FieldName"                                       AS owned_field_name,
    inherited."FieldId"                                     AS inherited_field_id,
    inherited."FieldName"                                   AS inherited_field_name
FROM   sett."Fields" owned
JOIN   sett."Fields" inherited
       ON  inherited."IsDeleted" = false
       AND inherited."IsSystem"  = false
       AND inherited."CompanyId" IS NULL
       AND lower(inherited."FieldName") = lower(owned."FieldName")
LEFT   JOIN app."Companies" c ON c."CompanyId" = owned."CompanyId"
WHERE  owned."IsDeleted"  = false
  AND  owned."IsSystem"   = false
  AND  owned."CompanyId" IS NOT NULL
ORDER  BY 1, 4;


-- =====================================================================================
-- WHAT TO DO WITH THE OUTPUT
--
--   Sections 1 and 2 empty  -> the migration will apply. Create it.
--   Section 1 or 2 returns  -> resolve before migrating. Do not resolve it by deleting
--                              rows: a custom field's values live under its FieldKey in
--                              every row's CustomFields document, and dropping the
--                              definition orphans that data. Rename the newer row
--                              (highest FieldId) and leave the data alone. Renaming
--                              FieldName does not move stored values — the jsonb key is
--                              FieldKey, and it is not touched by a rename.
--   Sections 3 and 4 return -> clean up at leisure. Neither blocks anything.
--
-- FieldCode / FieldKey ARE NOT AUDITED HERE, DELIBERATELY.
-- CreateCustomFieldHandler derives both from FieldName with no uniqueness check, so two
-- tenants who both create "Region" both get FieldCode 'REGION' and FieldKey 'region'.
-- That is correct and must stay possible: the key names a member of a jsonb document that
-- belongs to one tenant's row, so it only has to be unique within that document. The one
-- place a global name IS required — the import staging column — does not assume it:
-- ImportCustomFieldNaming.BuildFieldName emits CF_{key}_{fieldId}, and the FieldId suffix
-- is what makes it unique by construction. Nothing else in the solution looks a custom
-- field up by FieldCode or FieldKey without a grid or company already in hand.
-- (rept."CustomReportFieldMetadata" is looked up by FieldKey globally and has no
-- CompanyId column, but it is a separate platform-seeded catalogue that contains no
-- tenant custom fields at all.)
-- =====================================================================================
