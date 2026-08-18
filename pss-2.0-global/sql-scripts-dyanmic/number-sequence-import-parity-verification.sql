-- =====================================================================================
-- number-sequence-import-parity-verification.sql
--
-- Proves that import.generate_sequence_number (PL/pgSQL) behaves identically to
-- NumberSequenceGenerator.GenerateAsync (C#) on the four things that can silently
-- diverge:
--
--   § 1  the advisory-lock key                       (read-only)
--   § 2  pattern rendering, incl. {SEQ:0000} at 1 / 9999 / 10000   (rolled back)
--   § 3  FY period-key resolution for a tenant that has FINANCIAL_YEAR_START set,
--        one that does not, and one whose value is unparseable    (rolled back)
--   § 4  the current ContactCode format distribution              (read-only)
--
-- THIS SCRIPT HAS NOT BEEN EXECUTED. Run it yourself.
--
-- SAFETY: §§ 2 and 3 mutate rows (they have to — the counter and the FY setting are
-- exactly what is under test), so each is wrapped in its own BEGIN … ROLLBACK. Nothing
-- survives. Do not replace ROLLBACK with COMMIT. Run against a non-production database
-- if you can: § 2 takes the CONTACT advisory lock for the duration of its transaction,
-- which blocks concurrent contact creation for that one tenant until it rolls back.
--
-- PREREQUISITE: DatabaseScripts/Functions/import/generate_sequence_number.sql deployed.
-- =====================================================================================


-- =====================================================================================
-- § 1  ADVISORY-LOCK KEY EQUIVALENCE                                        (read-only)
--
--   C#:  ((long)0x4E554D53L << 24) ^ ((long)entityTypeId << 24) ^ (long)companyId
--   SQL: ((1313426259::BIGINT << 24) # (entityTypeId::BIGINT << 24)) # companyId::BIGINT
--
-- 0x4E554D53 = 1313426259. C# '^' is XOR; PostgreSQL spells integer XOR '#'. XOR is
-- associative and commutative, so C#'s left-to-right chain and the parenthesised SQL
-- form are the same value.
--
-- The check below is not a restatement of the formula — it derives the key a SECOND,
-- independent way. Both XOR operands are a value shifted left 24 places, so their low
-- 24 bits are zero and the XOR touches only the high part:
--       (1313426259 # entityTypeId) * 2^24
-- and the company id then occupies those zeroed low 24 bits, so the final XOR is a
-- plain addition (valid while companyId < 16,777,216 — every tenant id in this system).
-- If the shift/XOR form and the multiply/add form agree for every real entity type and
-- tenant, the operator semantics are what we think they are.
--
-- Third check: the hand-computed constant from the function header
-- (entityTypeId = 7, companyId = 3 -> 22035636064092163).
-- =====================================================================================

-- 1a — hand-computed reference value
SELECT 22035636064092163::BIGINT                                              AS expected_by_hand,
       ((1313426259::BIGINT << 24) # (7::BIGINT << 24)) # 3::BIGINT           AS computed_by_pg,
       (((1313426259::BIGINT << 24) # (7::BIGINT << 24)) # 3::BIGINT) = 22035636064092163::BIGINT
                                                                              AS ok;

-- 1b — every real (entity type, tenant) pair, two independent derivations
SELECT et."EntityTypeCode",
       ns."NumberSequenceEntityTypeId"                                        AS entity_type_id,
       co."CompanyId",
       ((1313426259::BIGINT << 24) # (ns."NumberSequenceEntityTypeId"::BIGINT << 24))
           # co."CompanyId"::BIGINT                                           AS key_shift_xor,
       ((1313426259 # ns."NumberSequenceEntityTypeId")::BIGINT * 16777216::BIGINT)
           + co."CompanyId"::BIGINT                                           AS key_multiply_add,
       (((1313426259::BIGINT << 24) # (ns."NumberSequenceEntityTypeId"::BIGINT << 24))
           # co."CompanyId"::BIGINT)
       = (((1313426259 # ns."NumberSequenceEntityTypeId")::BIGINT * 16777216::BIGINT)
           + co."CompanyId"::BIGINT)                                          AS ok
  FROM sett."NumberSequenceEntityTypes" ns
  JOIN public."EntityTypes" et ON et."EntityTypeId" = ns."EntityTypeId"
 CROSS JOIN (SELECT DISTINCT "CompanyId" FROM app."Companies" WHERE "IsDeleted" = FALSE) co
 WHERE et."EntityTypeCode" IN ('CONTACT', 'GLOBALDONATION')
 ORDER BY et."EntityTypeCode", co."CompanyId";

-- 1c — headroom. Every key must stay inside BIGINT with room to spare, and no two
-- (entity type, tenant) pairs may collide onto one key.
SELECT COUNT(*)                                        AS pair_count,
       COUNT(DISTINCT k.lock_key)                      AS distinct_keys,
       COUNT(*) = COUNT(DISTINCT k.lock_key)           AS no_collisions,
       MAX(k.lock_key)                                 AS max_key,
       MAX(k.lock_key) < 9223372036854775807::BIGINT   AS within_bigint
  FROM (
        SELECT ((1313426259::BIGINT << 24) # (ns."NumberSequenceEntityTypeId"::BIGINT << 24))
                   # co."CompanyId"::BIGINT AS lock_key
          FROM sett."NumberSequenceEntityTypes" ns
         CROSS JOIN (SELECT DISTINCT "CompanyId" FROM app."Companies" WHERE "IsDeleted" = FALSE) co
       ) k;


-- =====================================================================================
-- § 2  PATTERN RENDERING                                        (mutates, ROLLED BACK)
--
-- Drives import.generate_sequence_number through every token, then through the
-- {SEQ:0000} boundary the C# and PL/pgSQL implementations are most likely to disagree
-- on: PostgreSQL's lpad() TRUNCATES a value longer than the target width, while C#'s
-- PadLeft never does. Sequence 10000 under {SEQ:0000} must render '10000', NOT '1000'
-- (which would collide with sequence 1000). The width is the NUMBER OF DIGITS TYPED,
-- not their numeric value: {SEQ:0000} is width 4, not width zero and not a cap of 9999.
-- =====================================================================================
BEGIN;

DO $$
DECLARE
    v_company_id   INT;
    v_ns_type_id   INT;
    v_config_id    INT;
    v_out          TEXT;
    v_ctx          DATE := DATE '2026-03-07';
    v_fail         INT  := 0;

    -- one case: pattern, seed LastSequence, expected render
    -- (a NULL expected value is computed at run time — it depends on the tenant id)
    v_cases        TEXT[][] := ARRAY[
        ['{PREFIX}-{SEQ:0000}',              '0',    'CON-0001'],
        ['{PREFIX}-{SEQ:0000}',              '9998', 'CON-9999'],
        ['{PREFIX}-{SEQ:0000}',              '9999', 'CON-10000'],
        ['{SEQ:1}',                          '9999', '10000'],
        ['{SEQ:000000}',                     '0',    '000001'],
        ['{PREFIX}-{YYYY}-{MM}-{DD}-{SEQ:0000}', '0', 'CON-2026-03-07-0001'],
        ['{PREFIX}{SUFFIX}-{YY}-{SEQ:000}',  '0',    'CON-26-001'],
        ['C{COMPANYID}-{SEQ:00}',            '0',    NULL],   -- expected filled in below
        ['{PREFIX}-{SEQ:00}-{SEQ:0000}',     '0',    'CON-01-0001']
    ];
    v_i            INT;
    v_pattern      TEXT;
    v_seed         TEXT;
    v_expected     TEXT;
BEGIN
    SELECT ns."NumberSequenceEntityTypeId" INTO v_ns_type_id
      FROM sett."NumberSequenceEntityTypes" ns
      JOIN public."EntityTypes" et ON et."EntityTypeId" = ns."EntityTypeId"
     WHERE et."EntityTypeCode" = 'CONTACT' AND et."IsDeleted" = FALSE
     LIMIT 1;

    IF v_ns_type_id IS NULL THEN
        RAISE EXCEPTION 'CONTACT is not registered in sett."NumberSequenceEntityTypes" — run the seed first';
    END IF;

    SELECT MIN("CompanyId") INTO v_company_id FROM app."Companies" WHERE "IsDeleted" = FALSE;

    -- Force the eligibility row on for the duration of this (rolled-back) transaction so
    -- the test does not silently pass by returning NULL everywhere.
    UPDATE sett."NumberSequenceEntityTypes"
       SET "IsEnabled" = TRUE, "DefaultPrefix" = 'CON', "DefaultSuffix" = ''
     WHERE "NumberSequenceEntityTypeId" = v_ns_type_id;

    -- First call bootstraps the config row if this tenant has never generated one.
    PERFORM import.generate_sequence_number(v_company_id, 'CONTACT', v_ctx);

    SELECT "NumberSequenceConfigId" INTO v_config_id
      FROM sett."NumberSequenceConfigs"
     WHERE "CompanyId" = v_company_id
       AND "NumberSequenceEntityTypeId" = v_ns_type_id
       AND "IsDeleted" = FALSE
     LIMIT 1;

    FOR v_i IN 1 .. array_length(v_cases, 1) LOOP
        v_pattern  := v_cases[v_i][1];
        v_seed     := v_cases[v_i][2];
        v_expected := COALESCE(v_cases[v_i][3], 'C' || v_company_id::TEXT || '-01');

        UPDATE sett."NumberSequenceConfigs"
           SET "Pattern"             = v_pattern,
               "Prefix"              = 'CON',
               "Suffix"              = '',
               "SequenceResetPolicy" = 'NEVER',
               "IsEnabled"           = TRUE,
               "LastSequence"        = v_seed::INT,
               "LastResetPeriodKey"  = ''      -- matches NEVER, so no rollover reset fires
         WHERE "NumberSequenceConfigId" = v_config_id;

        v_out := import.generate_sequence_number(v_company_id, 'CONTACT', v_ctx);

        IF v_out IS DISTINCT FROM v_expected THEN
            v_fail := v_fail + 1;
            RAISE WARNING 'FAIL  pattern=%  seed=%  expected=%  actual=%',
                v_pattern, v_seed, v_expected, v_out;
        ELSE
            RAISE NOTICE  'pass  pattern=%  seed=%  ->  %', v_pattern, v_seed, v_out;
        END IF;
    END LOOP;

    -- Kill switches: per-tenant off, then global off. Both must yield NULL, not a code.
    UPDATE sett."NumberSequenceConfigs" SET "IsEnabled" = FALSE WHERE "NumberSequenceConfigId" = v_config_id;
    v_out := import.generate_sequence_number(v_company_id, 'CONTACT', v_ctx);
    IF v_out IS NOT NULL THEN
        v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  tenant kill-switch off but returned %', v_out;
    ELSE
        RAISE NOTICE  'pass  tenant kill-switch -> NULL';
    END IF;

    UPDATE sett."NumberSequenceConfigs"      SET "IsEnabled" = TRUE  WHERE "NumberSequenceConfigId" = v_config_id;
    UPDATE sett."NumberSequenceEntityTypes"  SET "IsEnabled" = FALSE WHERE "NumberSequenceEntityTypeId" = v_ns_type_id;
    v_out := import.generate_sequence_number(v_company_id, 'CONTACT', v_ctx);
    IF v_out IS NOT NULL THEN
        v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  global kill-switch off but returned %', v_out;
    ELSE
        RAISE NOTICE  'pass  global kill-switch -> NULL';
    END IF;

    -- Unregistered entity type must RAISE, not return NULL.
    BEGIN
        v_out := import.generate_sequence_number(v_company_id, 'NO_SUCH_ENTITY_TYPE_XYZ', v_ctx);
        v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  unregistered entity type returned % instead of raising', v_out;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'pass  unregistered entity type raised: %', SQLERRM;
    END;

    IF v_fail = 0 THEN
        RAISE NOTICE '=== § 2 RENDERING: ALL CHECKS PASSED ===';
    ELSE
        RAISE WARNING '=== § 2 RENDERING: % CHECK(S) FAILED ===', v_fail;
    END IF;
END $$;

ROLLBACK;   -- <<< do not change to COMMIT


-- =====================================================================================
-- § 3  FY PERIOD-KEY RESOLUTION                                 (mutates, ROLLED BACK)
--
-- Mirror of NumberSequenceGenerator.BuildFyKey / ParseMonth:
--   • tenant row wins over the CompanyId IS NULL platform default
--   • CurrentValue wins over ParamDefaultValue
--   • the value may be a month NUMBER (1..12) or an invariant full month NAME ("April")
--   • month >= start -> FY of this calendar year, else FY of the previous one
--   • unset or unparseable -> falls back to the plain calendar year
--
-- The three scenarios the prompt asks for are produced by rewriting the setting inside
-- this transaction. Rows are physically deleted rather than soft-deleted because the
-- unique index on (CompanyId, ParamCode) is filtered to "IsDeleted" = false and would
-- otherwise reject the replacement. Everything rolls back.
-- =====================================================================================
BEGIN;

DO $$
DECLARE
    v_company_id      INT;
    v_group_id        INT;
    v_had_platform    BOOLEAN;
    v_key             TEXT;
    v_fail            INT := 0;
BEGIN
    SELECT MIN("CompanyId") INTO v_company_id FROM app."Companies" WHERE "IsDeleted" = FALSE;
    SELECT MIN("SettingGroupId") INTO v_group_id FROM sett."SettingGroups";

    SELECT EXISTS (SELECT 1 FROM sett."OrganizationSettings"
                    WHERE "ParamCode" = 'FINANCIAL_YEAR_START'
                      AND "CompanyId" IS NULL AND "IsDeleted" = FALSE)
      INTO v_had_platform;
    RAISE NOTICE 'platform-default FINANCIAL_YEAR_START present: %', v_had_platform;

    -- Clear the field so each scenario starts from a known state.
    DELETE FROM sett."OrganizationSettings"
     WHERE "ParamCode" = 'FINANCIAL_YEAR_START'
       AND ("CompanyId" = v_company_id OR "CompanyId" IS NULL);

    ---------------------------------------------------------------------------
    -- Scenario A — tenant HAS the setting: April (month name)
    ---------------------------------------------------------------------------
    INSERT INTO sett."OrganizationSettings"
        ("CompanyId","SettingGroupId","ParamCode","ParamName","ParamDataType",
         "ParamDefaultValue","CurrentValue","CanUserOverride","IsActive","IsDeleted","CreatedDate")
    VALUES (v_company_id, v_group_id, 'FINANCIAL_YEAR_START','Financial Year Start','STRING',
            'January','April', TRUE, TRUE, FALSE, NOW());

    -- 2026-03-07 is BEFORE April -> still FY2025
    v_key := import.compute_sequence_period_key('FY', v_company_id, DATE '2026-03-07');
    IF v_key <> 'FY2025' THEN v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  A/before-start: expected FY2025 got %', v_key;
    ELSE RAISE NOTICE 'pass  A/before-start 2026-03-07 -> %', v_key; END IF;

    -- 2026-04-01 is ON the start -> FY2026
    v_key := import.compute_sequence_period_key('FY', v_company_id, DATE '2026-04-01');
    IF v_key <> 'FY2026' THEN v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  A/on-start: expected FY2026 got %', v_key;
    ELSE RAISE NOTICE 'pass  A/on-start 2026-04-01 -> %', v_key; END IF;

    -- Same setting expressed as a month NUMBER must give the same answer.
    UPDATE sett."OrganizationSettings" SET "CurrentValue" = '4'
     WHERE "ParamCode" = 'FINANCIAL_YEAR_START' AND "CompanyId" = v_company_id;
    v_key := import.compute_sequence_period_key('FY', v_company_id, DATE '2026-03-07');
    IF v_key <> 'FY2025' THEN v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  A/numeric-month: expected FY2025 got %', v_key;
    ELSE RAISE NOTICE 'pass  A/numeric-month ''4'' -> %', v_key; END IF;

    -- Blank CurrentValue must fall through to ParamDefaultValue ('January' -> FY2026).
    UPDATE sett."OrganizationSettings" SET "CurrentValue" = ''
     WHERE "ParamCode" = 'FINANCIAL_YEAR_START' AND "CompanyId" = v_company_id;
    v_key := import.compute_sequence_period_key('FY', v_company_id, DATE '2026-03-07');
    IF v_key <> 'FY2026' THEN v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  A/default-fallback: expected FY2026 got %', v_key;
    ELSE RAISE NOTICE 'pass  A/blank-CurrentValue -> ParamDefaultValue -> %', v_key; END IF;

    ---------------------------------------------------------------------------
    -- Scenario B — tenant has NO setting and there is no platform default
    --              -> calendar year
    ---------------------------------------------------------------------------
    DELETE FROM sett."OrganizationSettings"
     WHERE "ParamCode" = 'FINANCIAL_YEAR_START'
       AND ("CompanyId" = v_company_id OR "CompanyId" IS NULL);

    v_key := import.compute_sequence_period_key('FY', v_company_id, DATE '2026-03-07');
    IF v_key <> 'FY2026' THEN v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  B/unset: expected FY2026 got %', v_key;
    ELSE RAISE NOTICE 'pass  B/unset -> %', v_key; END IF;

    ---------------------------------------------------------------------------
    -- Scenario B2 — tenant row absent but a PLATFORM DEFAULT exists (July)
    --               -> platform default is used
    ---------------------------------------------------------------------------
    INSERT INTO sett."OrganizationSettings"
        ("CompanyId","SettingGroupId","ParamCode","ParamName","ParamDataType",
         "ParamDefaultValue","CurrentValue","CanUserOverride","IsActive","IsDeleted","CreatedDate")
    VALUES (NULL, v_group_id, 'FINANCIAL_YEAR_START','Financial Year Start','STRING',
            'January','July', TRUE, TRUE, FALSE, NOW());

    v_key := import.compute_sequence_period_key('FY', v_company_id, DATE '2026-03-07');
    IF v_key <> 'FY2025' THEN v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  B2/platform-default: expected FY2025 got %', v_key;
    ELSE RAISE NOTICE 'pass  B2/platform-default July -> %', v_key; END IF;

    -- ...and a tenant row must OVERRIDE that platform default.
    INSERT INTO sett."OrganizationSettings"
        ("CompanyId","SettingGroupId","ParamCode","ParamName","ParamDataType",
         "ParamDefaultValue","CurrentValue","CanUserOverride","IsActive","IsDeleted","CreatedDate")
    VALUES (v_company_id, v_group_id, 'FINANCIAL_YEAR_START','Financial Year Start','STRING',
            'January','January', TRUE, TRUE, FALSE, NOW());

    v_key := import.compute_sequence_period_key('FY', v_company_id, DATE '2026-03-07');
    IF v_key <> 'FY2026' THEN v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  B2/tenant-overrides-platform: expected FY2026 got %', v_key;
    ELSE RAISE NOTICE 'pass  B2/tenant overrides platform -> %', v_key; END IF;

    ---------------------------------------------------------------------------
    -- Scenario C — unparseable value -> calendar year (never an exception)
    ---------------------------------------------------------------------------
    DELETE FROM sett."OrganizationSettings"
     WHERE "ParamCode" = 'FINANCIAL_YEAR_START' AND "CompanyId" IS NULL;

    UPDATE sett."OrganizationSettings" SET "CurrentValue" = 'Smarch'
     WHERE "ParamCode" = 'FINANCIAL_YEAR_START' AND "CompanyId" = v_company_id;
    v_key := import.compute_sequence_period_key('FY', v_company_id, DATE '2026-03-07');
    IF v_key <> 'FY2026' THEN v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  C/garbage-name: expected FY2026 got %', v_key;
    ELSE RAISE NOTICE 'pass  C/garbage ''Smarch'' -> %', v_key; END IF;

    -- Out-of-range number, and an abbreviation the C# "MMMM" format rejects.
    UPDATE sett."OrganizationSettings" SET "CurrentValue" = '13'
     WHERE "ParamCode" = 'FINANCIAL_YEAR_START' AND "CompanyId" = v_company_id;
    v_key := import.compute_sequence_period_key('FY', v_company_id, DATE '2026-03-07');
    IF v_key <> 'FY2026' THEN v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  C/month-13: expected FY2026 got %', v_key;
    ELSE RAISE NOTICE 'pass  C/month 13 -> %', v_key; END IF;

    UPDATE sett."OrganizationSettings" SET "CurrentValue" = 'Apr'
     WHERE "ParamCode" = 'FINANCIAL_YEAR_START' AND "CompanyId" = v_company_id;
    v_key := import.compute_sequence_period_key('FY', v_company_id, DATE '2026-03-07');
    IF v_key <> 'FY2026' THEN v_fail := v_fail + 1;
        RAISE WARNING 'FAIL  C/abbreviation: expected FY2026 (C# MMMM rejects "Apr") got %', v_key;
    ELSE RAISE NOTICE 'pass  C/abbreviation ''Apr'' rejected -> %', v_key; END IF;

    ---------------------------------------------------------------------------
    -- Non-FY policies (these never touch OrganizationSettings)
    ---------------------------------------------------------------------------
    IF import.compute_sequence_period_key('NEVER',   v_company_id, DATE '2026-03-07') <> ''        THEN v_fail := v_fail + 1; RAISE WARNING 'FAIL  NEVER'; END IF;
    IF import.compute_sequence_period_key('YEARLY',  v_company_id, DATE '2026-03-07') <> '2026'    THEN v_fail := v_fail + 1; RAISE WARNING 'FAIL  YEARLY'; END IF;
    IF import.compute_sequence_period_key('MONTHLY', v_company_id, DATE '2026-03-07') <> '2026-03' THEN v_fail := v_fail + 1; RAISE WARNING 'FAIL  MONTHLY'; END IF;
    IF import.compute_sequence_period_key('yearly',  v_company_id, DATE '2026-03-07') <> '2026'    THEN v_fail := v_fail + 1; RAISE WARNING 'FAIL  case-insensitive policy'; END IF;
    IF import.compute_sequence_period_key('NONSENSE',v_company_id, DATE '2026-03-07') <> '2026'    THEN v_fail := v_fail + 1; RAISE WARNING 'FAIL  unknown policy must behave as YEARLY'; END IF;
    IF import.compute_sequence_period_key(NULL,      v_company_id, DATE '2026-03-07') <> '2026'    THEN v_fail := v_fail + 1; RAISE WARNING 'FAIL  NULL policy must behave as YEARLY'; END IF;
    RAISE NOTICE 'pass  NEVER / YEARLY / MONTHLY / unknown / NULL policies';

    IF v_fail = 0 THEN
        RAISE NOTICE '=== § 3 PERIOD KEY: ALL CHECKS PASSED ===';
    ELSE
        RAISE WARNING '=== § 3 PERIOD KEY: % CHECK(S) FAILED ===', v_fail;
    END IF;
END $$;

ROLLBACK;   -- <<< do not change to COMMIT


-- =====================================================================================
-- § 4  CONTACT-CODE FORMAT DISTRIBUTION                                    (read-only)
--
-- What the column actually holds today. "import_shaped" is the old defect: a purely
-- numeric code equal to the row's own ContactId, written by the deleted step 5e.
-- Reported, NOT repaired — see number-sequence-import-audit-queries.sql § 2 for the
-- reasoning behind not backfilling.
-- =====================================================================================
SELECT "CompanyId",
       COUNT(*)                                                     AS total_contacts,
       COUNT(*) FILTER (WHERE "ContactCode" IS NULL)                AS code_null,
       COUNT(*) FILTER (WHERE "ContactCode" ~ '^\d+$'
                          AND "ContactCode" = "ContactId"::TEXT)    AS import_shaped,
       COUNT(*) FILTER (WHERE "ContactCode" ~ '^\d+$'
                          AND "ContactCode" <> "ContactId"::TEXT)   AS numeric_other,
       COUNT(*) FILTER (WHERE "ContactCode" IS NOT NULL
                          AND "ContactCode" !~ '^\d+$')             AS patterned
  FROM corg."Contacts"
 WHERE "IsDeleted" = FALSE
 GROUP BY "CompanyId"
 ORDER BY "CompanyId";

-- § 4b — after the fix, newly imported contacts must look like UI-created ones.
-- Sample the most recent contacts of each origin and eyeball that the shapes match.
SELECT "ContactId", "CompanyId", "ContactCode", "CreatedDate"
  FROM corg."Contacts"
 WHERE "IsDeleted" = FALSE
 ORDER BY "ContactId" DESC
 LIMIT 50;
