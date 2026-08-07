-- =====================================================================================
-- Screen #170 P2PCampaignPage — EAV relocation backfill (spec: publicpages-EAV-SETTINGS-PORT-SPEC.md §6)
--
-- Copies the 17 presentation columns off fund."P2PCampaignPages" into the generic
-- per-page EAV table fund."P2PCampaignPageSettings", one row per column per page.
--
-- RUN ORDER (never collapse):
--   1. Migration 1  — create fund."P2PCampaignPageSettings" + its 2 indexes
--   2. THIS SCRIPT  — backfill
--   3. Deploy the EAV-reading backend
--   4. Migration 2  — drop the 17 columns from fund."P2PCampaignPages"
--
-- Idempotent: every INSERT is guarded by NOT EXISTS on (P2PCampaignPageId, upper(ParamCode)).
-- Re-running is a no-op. Skip rules mirror PresentationP2PCampaignPageSettings.BuildRows
-- exactly — optional string columns that are NULL or blank produce NO row (a missing row
-- means "renderer uses its built-in default").
--
-- Timestamps use plain now() — the column is timestamptz and Postgres stores UTC.
-- =====================================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────────────
-- PREVIEW — how many rows will this insert? Run this first, then decide.
-- ─────────────────────────────────────────────────────────────────────────────────────
SELECT
    count(*)                                                        AS active_pages,
    count(*) * 7                                                    AS always_written_rows,
    count(*) FILTER (WHERE coalesce(btrim("CustomCssOverride"), '') <> '')  AS custom_css_rows,
    count(*) FILTER (WHERE coalesce(btrim("LogoUrl"), '')           <> '')  AS logo_rows,
    count(*) FILTER (WHERE coalesce(btrim("DefaultShareMessage"),'')<> '')  AS share_msg_rows,
    count(*) FILTER (WHERE coalesce(btrim("OgTitle"), '')           <> '')  AS og_title_rows,
    count(*) FILTER (WHERE coalesce(btrim("OgDescription"), '')     <> '')  AS og_desc_rows,
    count(*) FILTER (WHERE coalesce(btrim("OgImageUrl"), '')        <> '')  AS og_image_rows
FROM fund."P2PCampaignPages"
WHERE "IsDeleted" = false;


-- ─────────────────────────────────────────────────────────────────────────────────────
-- THEME
-- ─────────────────────────────────────────────────────────────────────────────────────

-- THEME / PAGE_THEME  (string, always — source column is NOT NULL)
INSERT INTO fund."P2PCampaignPageSettings"
    ("P2PCampaignPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."P2PCampaignPageId", p."CompanyId", 'THEME', 'PAGE_THEME', 'Page Theme', 'string',
       p."PageTheme", 1, now(), true, false
FROM fund."P2PCampaignPages" p
WHERE p."IsDeleted" = false
  AND NOT EXISTS (SELECT 1 FROM fund."P2PCampaignPageSettings" s
                  WHERE s."P2PCampaignPageId" = p."P2PCampaignPageId"
                    AND upper(s."ParamCode") = 'PAGE_THEME');

-- THEME / PRIMARY_COLOR  (color, always)
INSERT INTO fund."P2PCampaignPageSettings"
    ("P2PCampaignPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."P2PCampaignPageId", p."CompanyId", 'THEME', 'PRIMARY_COLOR', 'Primary Colour', 'color',
       p."PrimaryColorHex", 2, now(), true, false
FROM fund."P2PCampaignPages" p
WHERE p."IsDeleted" = false
  AND NOT EXISTS (SELECT 1 FROM fund."P2PCampaignPageSettings" s
                  WHERE s."P2PCampaignPageId" = p."P2PCampaignPageId"
                    AND upper(s."ParamCode") = 'PRIMARY_COLOR');

-- THEME / SECONDARY_COLOR  (color, always)
INSERT INTO fund."P2PCampaignPageSettings"
    ("P2PCampaignPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."P2PCampaignPageId", p."CompanyId", 'THEME', 'SECONDARY_COLOR', 'Secondary Colour', 'color',
       p."SecondaryColorHex", 3, now(), true, false
FROM fund."P2PCampaignPages" p
WHERE p."IsDeleted" = false
  AND NOT EXISTS (SELECT 1 FROM fund."P2PCampaignPageSettings" s
                  WHERE s."P2PCampaignPageId" = p."P2PCampaignPageId"
                    AND upper(s."ParamCode") = 'SECONDARY_COLOR');

-- THEME / HEADER_STYLE  (string, always)
INSERT INTO fund."P2PCampaignPageSettings"
    ("P2PCampaignPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."P2PCampaignPageId", p."CompanyId", 'THEME', 'HEADER_STYLE', 'Header Style', 'string',
       p."HeaderStyle", 4, now(), true, false
FROM fund."P2PCampaignPages" p
WHERE p."IsDeleted" = false
  AND NOT EXISTS (SELECT 1 FROM fund."P2PCampaignPageSettings" s
                  WHERE s."P2PCampaignPageId" = p."P2PCampaignPageId"
                    AND upper(s."ParamCode") = 'HEADER_STYLE');

-- THEME / CUSTOM_CSS  (text, SKIP IF BLANK)
INSERT INTO fund."P2PCampaignPageSettings"
    ("P2PCampaignPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."P2PCampaignPageId", p."CompanyId", 'THEME', 'CUSTOM_CSS', 'Custom CSS', 'text',
       p."CustomCssOverride", 5, now(), true, false
FROM fund."P2PCampaignPages" p
WHERE p."IsDeleted" = false
  AND coalesce(btrim(p."CustomCssOverride"), '') <> ''
  AND NOT EXISTS (SELECT 1 FROM fund."P2PCampaignPageSettings" s
                  WHERE s."P2PCampaignPageId" = p."P2PCampaignPageId"
                    AND upper(s."ParamCode") = 'CUSTOM_CSS');


-- ─────────────────────────────────────────────────────────────────────────────────────
-- MEDIA
-- ─────────────────────────────────────────────────────────────────────────────────────

-- MEDIA / LOGO_URL  (url, SKIP IF BLANK)
INSERT INTO fund."P2PCampaignPageSettings"
    ("P2PCampaignPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."P2PCampaignPageId", p."CompanyId", 'MEDIA', 'LOGO_URL', 'Logo URL', 'url',
       p."LogoUrl", 1, now(), true, false
FROM fund."P2PCampaignPages" p
WHERE p."IsDeleted" = false
  AND coalesce(btrim(p."LogoUrl"), '') <> ''
  AND NOT EXISTS (SELECT 1 FROM fund."P2PCampaignPageSettings" s
                  WHERE s."P2PCampaignPageId" = p."P2PCampaignPageId"
                    AND upper(s."ParamCode") = 'LOGO_URL');


-- ─────────────────────────────────────────────────────────────────────────────────────
-- SECTIONS  (all bool, all always-written)
-- ─────────────────────────────────────────────────────────────────────────────────────

INSERT INTO fund."P2PCampaignPageSettings"
    ("P2PCampaignPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."P2PCampaignPageId", p."CompanyId", 'SECTIONS', v."ParamCode", v."ParamName", 'bool',
       CASE WHEN v."Value" THEN 'true' ELSE 'false' END, v."OrderBy", now(), true, false
FROM fund."P2PCampaignPages" p
CROSS JOIN LATERAL (VALUES
    ('SHOW_ORGANIZATION_INFO',     'Show Organization Info',     p."ShowOrganizationInfo",     1),
    ('SHOW_IMPACT_STATS',          'Show Impact Stats',          p."ShowImpactStats",          2),
    ('SHOW_DONOR_WALL',            'Show Donor Wall',            p."ShowDonorWall",            3),
    ('SHOW_LEADERBOARD',           'Show Leaderboard',           p."ShowLeaderboard",          4),
    ('SHOW_FUNDRAISER_COUNT',      'Show Fundraiser Count',      p."ShowFundraiserCount",      5),
    ('ACHIEVEMENT_BADGES_ENABLED', 'Achievement Badges Enabled', p."AchievementBadgesEnabled", 6)
) AS v("ParamCode","ParamName","Value","OrderBy")
WHERE p."IsDeleted" = false
  AND NOT EXISTS (SELECT 1 FROM fund."P2PCampaignPageSettings" s
                  WHERE s."P2PCampaignPageId" = p."P2PCampaignPageId"
                    AND upper(s."ParamCode") = v."ParamCode");


-- ─────────────────────────────────────────────────────────────────────────────────────
-- SOCIAL
-- ─────────────────────────────────────────────────────────────────────────────────────

-- SOCIAL / DEFAULT_SHARE_MESSAGE  (text, SKIP IF BLANK)
INSERT INTO fund."P2PCampaignPageSettings"
    ("P2PCampaignPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."P2PCampaignPageId", p."CompanyId", 'SOCIAL', 'DEFAULT_SHARE_MESSAGE', 'Default Share Message', 'text',
       p."DefaultShareMessage", 1, now(), true, false
FROM fund."P2PCampaignPages" p
WHERE p."IsDeleted" = false
  AND coalesce(btrim(p."DefaultShareMessage"), '') <> ''
  AND NOT EXISTS (SELECT 1 FROM fund."P2PCampaignPageSettings" s
                  WHERE s."P2PCampaignPageId" = p."P2PCampaignPageId"
                    AND upper(s."ParamCode") = 'DEFAULT_SHARE_MESSAGE');


-- ─────────────────────────────────────────────────────────────────────────────────────
-- SEO
-- ─────────────────────────────────────────────────────────────────────────────────────

-- SEO / OG_TITLE  (string, SKIP IF BLANK)
INSERT INTO fund."P2PCampaignPageSettings"
    ("P2PCampaignPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."P2PCampaignPageId", p."CompanyId", 'SEO', 'OG_TITLE', 'OG Title', 'string',
       p."OgTitle", 1, now(), true, false
FROM fund."P2PCampaignPages" p
WHERE p."IsDeleted" = false
  AND coalesce(btrim(p."OgTitle"), '') <> ''
  AND NOT EXISTS (SELECT 1 FROM fund."P2PCampaignPageSettings" s
                  WHERE s."P2PCampaignPageId" = p."P2PCampaignPageId"
                    AND upper(s."ParamCode") = 'OG_TITLE');

-- SEO / OG_DESCRIPTION  (text, SKIP IF BLANK)
INSERT INTO fund."P2PCampaignPageSettings"
    ("P2PCampaignPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."P2PCampaignPageId", p."CompanyId", 'SEO', 'OG_DESCRIPTION', 'OG Description', 'text',
       p."OgDescription", 2, now(), true, false
FROM fund."P2PCampaignPages" p
WHERE p."IsDeleted" = false
  AND coalesce(btrim(p."OgDescription"), '') <> ''
  AND NOT EXISTS (SELECT 1 FROM fund."P2PCampaignPageSettings" s
                  WHERE s."P2PCampaignPageId" = p."P2PCampaignPageId"
                    AND upper(s."ParamCode") = 'OG_DESCRIPTION');

-- SEO / OG_IMAGE_URL  (url, SKIP IF BLANK)
INSERT INTO fund."P2PCampaignPageSettings"
    ("P2PCampaignPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."P2PCampaignPageId", p."CompanyId", 'SEO', 'OG_IMAGE_URL', 'OG Image URL', 'url',
       p."OgImageUrl", 3, now(), true, false
FROM fund."P2PCampaignPages" p
WHERE p."IsDeleted" = false
  AND coalesce(btrim(p."OgImageUrl"), '') <> ''
  AND NOT EXISTS (SELECT 1 FROM fund."P2PCampaignPageSettings" s
                  WHERE s."P2PCampaignPageId" = p."P2PCampaignPageId"
                    AND upper(s."ParamCode") = 'OG_IMAGE_URL');

-- SEO / ROBOTS_INDEXABLE  (bool, always — reader defaults to TRUE when the row is absent)
INSERT INTO fund."P2PCampaignPageSettings"
    ("P2PCampaignPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."P2PCampaignPageId", p."CompanyId", 'SEO', 'ROBOTS_INDEXABLE', 'Indexable by Search Engines', 'bool',
       CASE WHEN p."RobotsIndexable" THEN 'true' ELSE 'false' END, 4, now(), true, false
FROM fund."P2PCampaignPages" p
WHERE p."IsDeleted" = false
  AND NOT EXISTS (SELECT 1 FROM fund."P2PCampaignPageSettings" s
                  WHERE s."P2PCampaignPageId" = p."P2PCampaignPageId"
                    AND upper(s."ParamCode") = 'ROBOTS_INDEXABLE');


-- ─────────────────────────────────────────────────────────────────────────────────────
-- VERIFY — every page should now have its 7 always-written params plus its non-blank ones.
-- ─────────────────────────────────────────────────────────────────────────────────────
SELECT p."P2PCampaignPageId", p."Slug", count(s.*) AS setting_rows
FROM fund."P2PCampaignPages" p
LEFT JOIN fund."P2PCampaignPageSettings" s
       ON s."P2PCampaignPageId" = p."P2PCampaignPageId" AND s."IsDeleted" = false
WHERE p."IsDeleted" = false
GROUP BY p."P2PCampaignPageId", p."Slug"
ORDER BY p."P2PCampaignPageId";

COMMIT;
-- ROLLBACK;   -- ← swap for COMMIT above if the preview/verify output looks wrong
