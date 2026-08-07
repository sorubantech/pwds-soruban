-- =====================================================================================
-- PSS 2.0 — BULK EMAIL JOB RELIABILITY §③.1
-- Seed the EMAILSENDJOBSTATUS value PARTIAL ("Partially Sent").
--
-- WHY THIS EXISTS (defect D4): a bulk job that sent 12 of 40,000 emails reported COMPLETED,
-- because the only two outcomes the code could express were "finished" and "threw". The build
-- now derives the final status honestly:
--
--     failed = 0                → COMPLETED
--     sent   = 0 and failed > 0 → FAILED
--     otherwise                 → PARTIAL      ← this row
--
-- Until this seed is applied, both EmailSenderService and EmailRetrySweepService fall back to
-- COMPLETED when PARTIAL cannot be resolved. That is deliberate — a missing MasterData row must
-- not throw in the middle of a send — but it also means the D4 fix is INERT until you run this.
--
-- IDEMPOTENT: the INSERT is guarded by NOT EXISTS on (TypeCode, DataValue). Re-running is a no-op.
-- Additive only: no DROP, no UPDATE of existing rows, no schema change, no migration.
--
-- USER-OWNED: written here, applied by you. Never executed from application code.
--
-- NOTE ON SCHEMA: MasterDatas / MasterDataTypes live in **sett**, not app. (The build prompt's
-- verification query said app."MasterDatas"; that is a typo in the prompt — sett is correct.)
-- =====================================================================================


-- ── 1. Pre-check: what is already seeded under EMAILSENDJOBSTATUS? ───────────────────────────
-- CANCELLED and PAUSED may never have been seeded in this database. §④.4 (pause/resume) and
-- §④.5 (cancel) both degrade gracefully when their status row is absent — the Hangfire side of
-- the operation still happens, only the status label stays unchanged — but the job list will
-- then show a stale status. Run this first and compare against the expected set below.
SELECT md."DataValue" AS code, md."DataName" AS name, md."OrderBy", md."IsActive"
FROM sett."MasterDatas" md
JOIN sett."MasterDataTypes" mdt ON mdt."MasterDataTypeId" = md."MasterDataTypeId"
WHERE mdt."TypeCode" = 'EMAILSENDJOBSTATUS'
ORDER BY md."OrderBy", md."DataValue";


-- ── 2. Insert PARTIAL ────────────────────────────────────────────────────────────────────────
-- OrderBy is computed as COMPLETED's + 1 so PARTIAL sorts immediately after it in every status
-- dropdown, which is where a reader looking for "did it finish?" expects to find it. If
-- COMPLETED is somehow absent, fall to the end of the list rather than to 0.
INSERT INTO sett."MasterDatas"(
    "MasterDataTypeId", "DataName", "DataValue", "DataSetting",
    "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "IsSystem")
SELECT
    mdt."MasterDataTypeId",
    'Partially Sent',
    'PARTIAL',
    'Partially Sent',
    COALESCE(
        (SELECT c."OrderBy" + 1
         FROM sett."MasterDatas" c
         WHERE c."MasterDataTypeId" = mdt."MasterDataTypeId"
           AND c."DataValue" = 'COMPLETED'
         LIMIT 1),
        (SELECT COALESCE(MAX(m."OrderBy"), 0) + 1
         FROM sett."MasterDatas" m
         WHERE m."MasterDataTypeId" = mdt."MasterDataTypeId")
    ),
    2, now(), NULL, NULL,
    TRUE, FALSE, TRUE
FROM sett."MasterDataTypes" mdt
WHERE mdt."TypeCode" = 'EMAILSENDJOBSTATUS'
  AND NOT EXISTS (
    SELECT 1
    FROM sett."MasterDatas" md
    WHERE md."MasterDataTypeId" = mdt."MasterDataTypeId"
      AND md."DataValue" = 'PARTIAL'
);


-- ── 3. Verification (§③.1 Q4) ────────────────────────────────────────────────────────────────
-- Expected: CANCELLED, COMPLETED, FAILED, PARTIAL, PAUSED, PENDING, PROCESSING, QUEUED, SENDING
--
-- If CANCELLED or PAUSED is missing from your result, seed it the same way as block 2 above
-- (DataName 'Cancelled' / 'Paused'). They are prerequisites for §④.4 and §④.5 showing the right
-- status, not for those operations working.
SELECT md."DataValue"
FROM sett."MasterDatas" md
JOIN sett."MasterDataTypes" mdt ON mdt."MasterDataTypeId" = md."MasterDataTypeId"
WHERE mdt."TypeCode" = 'EMAILSENDJOBSTATUS'
  AND md."IsDeleted" = FALSE
ORDER BY md."DataValue";


-- ── 4. Related pre-flight check — EMAILSENDSTATUS (row-level, not job-level) ─────────────────
-- No insert here; this build seeds no row-level status. But §④.5 (Cancel) hard-refuses to run
-- unless BOTH 'QUEUED' and 'BLOCKED' resolve, because blocking rows is the whole point of the
-- operation and half-doing it would leave un-started recipients that a later tick still picks up.
-- Confirm they are present before demoing Cancel.
-- Expected to include at least: QUEUED, SENDING, SENT, FAILED, BLOCKED
SELECT md."DataValue"
FROM sett."MasterDatas" md
JOIN sett."MasterDataTypes" mdt ON mdt."MasterDataTypeId" = md."MasterDataTypeId"
WHERE mdt."TypeCode" = 'EMAILSENDSTATUS'
  AND md."IsDeleted" = FALSE
ORDER BY md."DataValue";


-- ── 5. Job-list status chip (§⑤.1) — point the grid column at the new renderer ────────────────
-- The list column is rendered from sett."GridFields"."GridComponentName": the FE switch in
-- data-tables/flow/data-table-column-types/component-column.tsx now understands
-- 'email-job-status-badge'. Until this UPDATE runs the list falls back to plain text, and PARTIAL
-- reads exactly like COMPLETED — which is the one thing §④.7 exists to prevent.
--
-- 5a. DISCOVERY — run this first and look at the result before running 5b.
-- It shows every column of the EMAILSENDJOB grid so you can confirm which row is the status column
-- and what it currently renders with. No email-job grid seed exists in this repo, so the column was
-- configured by hand and its FieldCode cannot be assumed.
SELECT gf."GridFieldId",
       f."FieldCode",
       f."FieldKey",
       gf."ParentObject",
       gf."GridComponentName",
       gf."OrderBy",
       gf."IsVisible"
FROM sett."GridFields" gf
JOIN sett."Grids"  g ON g."GridId"  = gf."GridId"
JOIN sett."Fields" f ON f."FieldId" = gf."FieldId"
WHERE g."GridCode" = 'EMAILSENDJOB'
  AND gf."IsDeleted" = FALSE
ORDER BY gf."OrderBy";

-- 5b. UPDATE — guarded and idempotent. Targets the column whose ParentObject is the nested job
-- status object ('emailJobStatus', matching EmailSendJobResponseDto). Re-running it is a no-op.
--
-- If 5a shows the status column with a NULL or differently-named "ParentObject", do NOT edit the
-- predicate blindly: set "ParentObject" to 'emailJobStatus' on that row as well, otherwise the
-- renderer receives the flat jobStatusId and prints an id where a chip should be.
UPDATE sett."GridFields" gf
SET "GridComponentName" = 'email-job-status-badge',
    "ModifiedBy"        = 2,
    "ModifiedDate"      = now()
FROM sett."Grids" g
WHERE g."GridId" = gf."GridId"
  AND g."GridCode" = 'EMAILSENDJOB'
  AND gf."IsDeleted" = FALSE
  AND gf."ParentObject" = 'emailJobStatus'
  AND gf."GridComponentName" IS DISTINCT FROM 'email-job-status-badge';

-- 5c. Verification — expect exactly one row, GridComponentName = 'email-job-status-badge'.
SELECT gf."GridFieldId", f."FieldCode", gf."ParentObject", gf."GridComponentName"
FROM sett."GridFields" gf
JOIN sett."Grids"  g ON g."GridId"  = gf."GridId"
JOIN sett."Fields" f ON f."FieldId" = gf."FieldId"
WHERE g."GridCode" = 'EMAILSENDJOB'
  AND gf."GridComponentName" = 'email-job-status-badge';
