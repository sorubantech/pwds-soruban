-- =====================================================================================
-- number-sequence-import-audit-queries.sql
--
-- READ-ONLY. Nothing here writes, and nothing here has been executed — run it yourself.
-- Companion to the import code-generation fix:
--   PSS_2.0_Backend/DatabaseScripts/Functions/import/generate_sequence_number.sql
--   PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/ContactImport-fn-execute.sql
--   PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/BulkDonationImport-fn-execute.sql
--
--   § 1  Is CONTACT / GLOBALDONATION actually registered in the NumberSequence tables?
--   § 2  How many existing contacts carry an import-shaped ContactCode?
--   § 3  Which tenants would generate what, today (no mutation)?
--
-- NO BACKFILL IS PERFORMED OR PROPOSED HERE. § 2 counts the damage; it does not repair
-- it. Rewriting historical ContactCodes would break every external reference already
-- issued against them (exports, mail merges, third-party keys) and would have to be
-- reconciled against the live counter to avoid manufacturing the exact collision the
-- fix exists to prevent. That is a separate, deliberate decision.
-- =====================================================================================


-- =====================================================================================
-- § 1  NumberSequence registration for the two import entity types
--
-- Expected: one row each for CONTACT and GLOBALDONATION. A missing row means
-- import.generate_sequence_number will RAISE EXCEPTION on every row of that import
-- (deliberately loud). "IsEnabled" = false means it returns NULL and the code column
-- is left empty — which is the same thing the UI does, not a failure.
--
-- Both are seeded by:
--   PeopleServe/Services/Base/sql-scripts-dyanmic/NumberSequenceEntityType-BulkRegister-sqlscripts.sql  (CONTACT)
--   PeopleServe/Services/Base/sql-scripts-dyanmic/NumberSequenceEntityType-sqlscripts.sql               (GLOBALDONATION)
-- so on any environment where those have been applied this query returns two rows and
-- no additional seed script is required.
-- =====================================================================================
SELECT et."EntityTypeCode",
       et."EntityTypeName",
       ns."NumberSequenceEntityTypeId",
       ns."DefaultPrefix",
       ns."DefaultSuffix",
       ns."DefaultPattern",
       ns."DefaultSequenceResetPolicy",
       ns."IsEnabled",
       et."IsDeleted"                             AS entity_type_is_deleted,
       -- The advisory-lock key the two implementations must agree on, for company 1.
       ((1313426259::BIGINT << 24) # (ns."NumberSequenceEntityTypeId"::BIGINT << 24)) # 1::BIGINT
                                                  AS lock_key_for_company_1
  FROM public."EntityTypes" et
  LEFT JOIN sett."NumberSequenceEntityTypes" ns
         ON ns."EntityTypeId" = et."EntityTypeId"
 WHERE et."EntityTypeCode" IN ('CONTACT', 'GLOBALDONATION')
 ORDER BY et."EntityTypeCode";


-- § 1b  Per-tenant counters for those two entity types (what the sequence is up to).
SELECT et."EntityTypeCode",
       c."CompanyId",
       c."NumberSequenceConfigId",
       COALESCE(c."Prefix",              ns."DefaultPrefix")              AS effective_prefix,
       COALESCE(c."Suffix",              ns."DefaultSuffix")              AS effective_suffix,
       COALESCE(c."Pattern",             ns."DefaultPattern")             AS effective_pattern,
       COALESCE(c."SequenceResetPolicy", ns."DefaultSequenceResetPolicy") AS effective_policy,
       c."LastSequence",
       c."LastResetPeriodKey",
       c."IsEnabled"                                                     AS config_enabled,
       ns."IsEnabled"                                                    AS eligibility_enabled
  FROM sett."NumberSequenceConfigs" c
  JOIN sett."NumberSequenceEntityTypes" ns ON ns."NumberSequenceEntityTypeId" = c."NumberSequenceEntityTypeId"
  JOIN public."EntityTypes" et             ON et."EntityTypeId" = ns."EntityTypeId"
 WHERE et."EntityTypeCode" IN ('CONTACT', 'GLOBALDONATION')
   AND c."IsDeleted" = FALSE
 ORDER BY et."EntityTypeCode", c."CompanyId";


-- =====================================================================================
-- § 2  Existing rows carrying an import-shaped ContactCode
--
-- The old step 5e wrote ContactCode = ContactId::TEXT. Those rows are identifiable
-- exactly: the code is all digits AND numerically equal to the row's own ContactId.
-- A purely-numeric code that does NOT equal the ContactId came from somewhere else
-- (a legacy migration, a hand edit) and is reported separately rather than lumped in.
-- =====================================================================================
SELECT "CompanyId",
       COUNT(*)                                                                    AS total_contacts,
       COUNT(*) FILTER (WHERE "ContactCode" IS NULL)                               AS code_null,
       COUNT(*) FILTER (WHERE "ContactCode" ~ '^\d+$'
                          AND "ContactCode" = "ContactId"::TEXT)                   AS import_shaped_code,
       COUNT(*) FILTER (WHERE "ContactCode" ~ '^\d+$'
                          AND "ContactCode" <> "ContactId"::TEXT)                  AS numeric_but_not_identity,
       COUNT(*) FILTER (WHERE "ContactCode" IS NOT NULL
                          AND "ContactCode" !~ '^\d+$')                            AS patterned_code
  FROM corg."Contacts"
 WHERE "IsDeleted" = FALSE
 GROUP BY "CompanyId"
 ORDER BY "CompanyId";


-- § 2b  Grand total across all tenants (the single number for the report).
SELECT COUNT(*) AS import_shaped_contact_codes_total
  FROM corg."Contacts"
 WHERE "IsDeleted" = FALSE
   AND "ContactCode" ~ '^\d+$'
   AND "ContactCode" = "ContactId"::TEXT;


-- § 2c  Collision exposure: an import-shaped code that the live counter could still
-- reach. Only meaningful where the effective pattern renders to a bare number, which
-- the shipped defaults do not — this should normally return zero rows. It is here so
-- that a tenant who has customised "Pattern" to something digits-only is visible
-- before the counter walks into an existing row.
SELECT c."CompanyId",
       COALESCE(c."Pattern", ns."DefaultPattern") AS effective_pattern,
       c."LastSequence"
  FROM sett."NumberSequenceConfigs" c
  JOIN sett."NumberSequenceEntityTypes" ns ON ns."NumberSequenceEntityTypeId" = c."NumberSequenceEntityTypeId"
  JOIN public."EntityTypes" et             ON et."EntityTypeId" = ns."EntityTypeId"
 WHERE et."EntityTypeCode" = 'CONTACT'
   AND c."IsDeleted" = FALSE
   -- pattern contains no literal text outside its SEQ token(s)
   AND regexp_replace(COALESCE(c."Pattern", ns."DefaultPattern"), '\{SEQ:\d+\}', '', 'g') = ''
 ORDER BY c."CompanyId";


-- =====================================================================================
-- § 3  ReceiptNumber on fund."GlobalDonations"
--
-- There is NO uniqueness constraint on this column today: GlobalDonationConfiguration.cs
-- declares only .HasMaxLength(100). (For contrast, GeneratedTaxReceiptConfiguration has a
-- filtered unique index on (CompanyId, ReceiptNumber), and AmbassadorCollectionConfiguration
-- one on (CompanyId, ReceiptBookId, ReceiptNumber) — so the pattern exists in the codebase,
-- it just was never applied here.)
--
-- Run this BEFORE deciding whether to add one. Any non-zero duplicate count means a
-- unique index cannot be created without first reconciling the existing data, and a
-- migration that adds it blind would fail on deploy.
-- =====================================================================================
SELECT "CompanyId",
       COUNT(*)                                                   AS total_donations,
       COUNT(*) FILTER (WHERE "ReceiptNumber" IS NULL
                           OR TRIM("ReceiptNumber") = '')         AS receipt_missing,
       COUNT(DISTINCT "ReceiptNumber") FILTER (WHERE "ReceiptNumber" IS NOT NULL)
                                                                  AS distinct_receipts
  FROM fund."GlobalDonations"
 WHERE "IsDeleted" = FALSE
 GROUP BY "CompanyId"
 ORDER BY "CompanyId";


-- § 3b  Actual duplicate receipt numbers within a tenant.
SELECT "CompanyId", "ReceiptNumber", COUNT(*) AS occurrences
  FROM fund."GlobalDonations"
 WHERE "IsDeleted" = FALSE
   AND "ReceiptNumber" IS NOT NULL
   AND TRIM("ReceiptNumber") <> ''
 GROUP BY "CompanyId", "ReceiptNumber"
HAVING COUNT(*) > 1
 ORDER BY occurrences DESC, "CompanyId"
 LIMIT 200;
