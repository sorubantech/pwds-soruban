-- =============================================================================
-- Screen #10 Online Donation Page — ISSUE-50 recovery (2026-07-20)
--
-- Symptom: previously-saved Landing Content sub-sections (testimonials, footer,
-- impact stats …) vanished from both the editor and the public page after the
-- user edited an UNRELATED sub-section.
--
-- Cause: SaveOnlineDonationPageLandingContent ran a "drop-sweep" that soft-deleted
-- every active fund.OnlineDonationPageSettings row absent from the payload, while
-- the Card 9 editor autosaves DIFF-ONLY (it POSTs just the changed params). So the
-- first edit after a save soft-deleted everything the user had not just touched.
-- Fixed in code by removing the sweep; this script restores the rows it destroyed.
--
-- Safety: only restores a soft-deleted row when NO active row exists for the same
-- (OnlineDonationPageId, ParamCode) — never creates a duplicate, never overwrites
-- a value the user has since re-entered. Keeps the newest deleted row per param.
-- Idempotent: re-running it after a successful run restores nothing further.
--
-- USER-OWNED: review the SELECT preview, then run the UPDATE inside a transaction.
-- =============================================================================

-- To scope to a single page, add
--     AND s."OnlineDonationPageId" = <id>
-- to the WHERE clause of both CTEs below. Find the id with:
--     SELECT "OnlineDonationPageId", "PageTitle", "Slug"
--     FROM fund."OnlineDonationPages" WHERE "IsDeleted" = false;


-- ── Step 1 — PREVIEW: what would be restored ────────────────────────────────
WITH recoverable AS (
    SELECT DISTINCT ON (s."OnlineDonationPageId", upper(s."ParamCode"))
           s."OnlineDonationPageSettingId",
           s."OnlineDonationPageId",
           s."SectionCode",
           s."ParamCode",
           left(coalesce(s."ParamValue", ''), 80) AS "ParamValuePreview"
    FROM   fund."OnlineDonationPageSettings" s
    WHERE  s."IsDeleted" = true
      AND  NOT EXISTS (
               SELECT 1
               FROM   fund."OnlineDonationPageSettings" a
               WHERE  a."OnlineDonationPageId" = s."OnlineDonationPageId"
                 AND  upper(a."ParamCode")     = upper(s."ParamCode")
                 AND  a."IsDeleted"            = false)
    ORDER  BY s."OnlineDonationPageId",
              upper(s."ParamCode"),
              s."OnlineDonationPageSettingId" DESC   -- newest deleted row wins
)
SELECT * FROM recoverable
ORDER BY "OnlineDonationPageId", "SectionCode", "ParamCode";


-- ── Step 2 — RESTORE (run after the preview looks right) ────────────────────
BEGIN;

WITH recoverable AS (
    SELECT DISTINCT ON (s."OnlineDonationPageId", upper(s."ParamCode"))
           s."OnlineDonationPageSettingId"
    FROM   fund."OnlineDonationPageSettings" s
    WHERE  s."IsDeleted" = true
      AND  NOT EXISTS (
               SELECT 1
               FROM   fund."OnlineDonationPageSettings" a
               WHERE  a."OnlineDonationPageId" = s."OnlineDonationPageId"
                 AND  upper(a."ParamCode")     = upper(s."ParamCode")
                 AND  a."IsDeleted"            = false)
    ORDER  BY s."OnlineDonationPageId",
              upper(s."ParamCode"),
              s."OnlineDonationPageSettingId" DESC
)
UPDATE fund."OnlineDonationPageSettings" t
SET    "IsDeleted"    = false,
       "ModifiedDate" = now()          -- column is timestamptz; now() is UTC-correct
FROM   recoverable r
WHERE  t."OnlineDonationPageSettingId" = r."OnlineDonationPageSettingId";

-- Verify the row count matches the preview, then:
COMMIT;
-- ROLLBACK;   -- ← use instead if the count looks wrong
