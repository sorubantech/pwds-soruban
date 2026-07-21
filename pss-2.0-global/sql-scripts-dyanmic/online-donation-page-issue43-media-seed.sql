-- =====================================================================================
-- ISSUE-43 — Online Donation Page (Screen #10) STANDARD (Aurora) enrichment MEDIA seed
-- -------------------------------------------------------------------------------------
-- Seeds the two MEDIA-typed ISSUE-43 landing ParamCodes that DefaultOnlineDonationPageSettings
-- .BuildDefaultRows() intentionally leaves BLANK (no sensible coded default — an image URL
-- / avatar list can't be guessed for an arbitrary tenant):
--
--   MISSION      / MISSION_IMAGE_URL     url     ISSUE-43(A) — mission-column secondary image
--   IMPACT_STATS / IMPACT_AVATARS_JSON   json    ISSUE-43(D) — donor-avatar strip (array of urls)
--
-- Scope: the ONE sample published reference page seeded by the original Screen #10 build
-- (CompanyId = 3, Slug = 'give' — see sql-scripts-dyanmic/online-donation-page-sqlscripts.sql).
-- This is a demo/reference-fidelity seed, NOT a tenant backfill: every OTHER page keeps the
-- blank default from BuildDefaultRows() (NullIfBlank → the section renders only when an
-- admin fills it in via the Card 9 editor). Placeholder image URLs point at a stable public
-- placeholder host so the reference page renders complete out-of-the-box without needing a
-- blob-storage upload.
--
-- IDEMPOTENT: guarded by NOT EXISTS on (OnlineDonationPageId, ParamCode) for active rows —
-- safe to re-run. No FK ids are hardcoded — the target page is resolved via SELECT subquery
-- on (CompanyId, Slug).
--
-- No schema change. No migration. EAV rows only — user-owned to apply.
-- =====================================================================================

BEGIN;

-- ── MISSION_IMAGE_URL  (string)  — ISSUE-43(A), mission-column secondary image ───────────
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId", "CompanyId", "SectionCode", "ParamCode", "ParamName", "ParamDataType", "ParamValue", "OrderBy",
   "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'MISSION', 'MISSION_IMAGE_URL', 'Mission Secondary Image URL', 'url',
       'https://images.unsplash.com/photo-1509099836639-18ba1795216d?w=800&q=80',
       6, 2, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE p."CompanyId" = 3
  AND p."Slug" = 'give'
  AND p."IsDeleted" = false
  AND NOT EXISTS (
    SELECT 1 FROM fund."OnlineDonationPageSettings" s
    WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId"
      AND s."ParamCode" = 'MISSION_IMAGE_URL'
      AND s."IsDeleted" = false
  );

-- ── IMPACT_AVATARS_JSON  (json)  — ISSUE-43(D), donor-avatar strip ("Trusted by...") ─────
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId", "CompanyId", "SectionCode", "ParamCode", "ParamName", "ParamDataType", "ParamValue", "OrderBy",
   "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'IMPACT_STATS', 'IMPACT_AVATARS_JSON', 'Trust Avatars', 'json',
       '["https://randomuser.me/api/portraits/women/68.jpg","https://randomuser.me/api/portraits/men/32.jpg","https://randomuser.me/api/portraits/women/44.jpg","https://randomuser.me/api/portraits/men/76.jpg","https://randomuser.me/api/portraits/women/21.jpg"]',
       4, 2, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE p."CompanyId" = 3
  AND p."Slug" = 'give'
  AND p."IsDeleted" = false
  AND NOT EXISTS (
    SELECT 1 FROM fund."OnlineDonationPageSettings" s
    WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId"
      AND s."ParamCode" = 'IMPACT_AVATARS_JSON'
      AND s."IsDeleted" = false
  );

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT; expect exactly one row per ParamCode for the 'give' page):
--   SELECT s."OnlineDonationPageId", s."SectionCode", s."ParamCode", left(s."ParamValue", 60) AS val
--   FROM fund."OnlineDonationPageSettings" s
--   JOIN fund."OnlineDonationPages" p ON p."OnlineDonationPageId" = s."OnlineDonationPageId"
--   WHERE p."CompanyId" = 3 AND p."Slug" = 'give'
--     AND s."ParamCode" IN ('MISSION_IMAGE_URL','IMPACT_AVATARS_JSON')
--     AND s."IsDeleted" = false
--   ORDER BY s."SectionCode", s."OrderBy";
-- =====================================================================================
