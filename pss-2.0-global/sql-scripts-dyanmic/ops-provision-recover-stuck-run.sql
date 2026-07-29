-- ─────────────────────────────────────────────────────────────────────────────────────────────
--  Recovery: re-arm a stuck / abandoned PRE-STEP-8 provisioning run so the engine can RESUME it
--  from the first non-SUCCEEDED step. Steps already SUCCEEDED are preserved and skipped by the
--  engine — this honours "don't re-run steps that already succeeded, only continue from the failed
--  one".
--
--  WHY THIS IS NEEDED (one-off data repair):
--    The provisioning validator only lets a re-submit through if it can tie the existing half-built
--    company back to a NON-ABANDONED run via that run's IdempotencyKey + CompanyId. If the stuck run
--    was Abandoned (or lost its CompanyId link), the validator can no longer see it as "own", so the
--    lingering PROVISIONING company keeps tripping "This subdomain is already taken." / "A company
--    with this code already exists." on every retry. This script relinks + re-arms that run.
--
--  IDEMPOTENT: safe to run more than once. It only touches non-SUCCEEDED runs for the given code.
--
--  HOW TO USE:
--    1. Edit v_code below to the stuck tenant's CompanyCode.
--    2. Run this once.
--    3. Make sure the API was RESTARTED after the last backend build, and that the
--       Rescope_Role_Unique_Indexes_Per_Company migration is applied (else Step 3 SEED_ROLES
--       crashes again on the old global role index).
--    4. Open the run's detail page (control plane → Provisioning Runs → the run) and click Resume.
-- ─────────────────────────────────────────────────────────────────────────────────────────────

DO $$
DECLARE
    v_code       text := 'REPLACE_WITH_COMPANYCODE';   -- <<< EDIT ME: the stuck tenant's CompanyCode
    v_company_id int;
    v_rows       int;
BEGIN
    SELECT "CompanyId" INTO v_company_id
    FROM app."Companies"
    WHERE "CompanyCode" = v_code AND "IsDeleted" IS NOT TRUE
    ORDER BY "CompanyId" DESC
    LIMIT 1;

    IF v_company_id IS NULL THEN
        RAISE NOTICE 'No live company found for code "%". Nothing to recover.', v_code;
        RETURN;
    END IF;

    -- Relink the company (in case the run header lost it) and re-arm the run to a resumable state.
    UPDATE ops."TenantProvisioningRuns"
    SET "CompanyId"   = COALESCE("CompanyId", v_company_id),
        "Status"      = 'PAUSED_ON_ERROR',
        "CompletedOn" = NULL
    WHERE "IsDeleted" IS NOT TRUE
      AND "Status" <> 'SUCCEEDED'
      AND ("CompanyId" = v_company_id OR "IdempotencyKey" LIKE '%CODE:' || v_code);
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    -- Cosmetic: clear any non-terminal steps a prior Abandon marked SKIPPED (or a crash left FAILED/
    -- RUNNING) back to PENDING so the timeline reads cleanly. The engine re-runs every non-SUCCEEDED
    -- step regardless — SUCCEEDED rows are never touched here.
    UPDATE ops."TenantProvisioningRunSteps" s
    SET "Status" = 'PENDING', "ErrorMessage" = NULL, "StartedOn" = NULL, "CompletedOn" = NULL
    WHERE s."IsDeleted" IS NOT TRUE
      AND s."Status" IN ('SKIPPED', 'FAILED', 'RUNNING')
      AND s."RunId" IN (
          SELECT "RunId" FROM ops."TenantProvisioningRuns"
          WHERE "CompanyId" = v_company_id AND "IsDeleted" IS NOT TRUE AND "Status" <> 'SUCCEEDED'
      );

    RAISE NOTICE 'Re-armed % run(s) for company % (code "%"). Open the run detail page and click Resume.',
        v_rows, v_company_id, v_code;
END $$;
