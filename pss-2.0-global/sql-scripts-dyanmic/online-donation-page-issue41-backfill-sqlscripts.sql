-- =====================================================================================
-- ISSUE-41 + ISSUE-42 — Online Donation Page (Screen #10) thin-core column relocation
-- STEP 1 of 2 : ADDITIVE BACKFILL  (run BEFORE the single combined DROP COLUMN step)
-- -------------------------------------------------------------------------------------
-- Copies BOTH relocation sets that used to live as typed columns on
--   fund."OnlineDonationPages"
-- into EAV rows on
--   fund."OnlineDonationPageSettings":
--   * ISSUE-41 : the 15 cosmetic/presentational columns (THEME/EMBED/THANKYOU/SOCIAL/
--                RECEIPT/SEO sections)
--   * ISSUE-42 : the 3 template-MEDIA columns (LogoUrl, HeroImageUrl, CarouselSlidesJson)
--                → MEDIA section
-- so the new BE (which no longer maps those columns) reads them back via
-- PresentationOnlineDonationPageSettings.Assemble(...).
--
-- SINGLE-MIGRATION DECISION (session 53): ISSUE-41's DROP was intentionally NOT run on its
-- own. This one backfill feeds all 18 columns; the live fund."OnlineDonationPages" table is
-- then altered EXACTLY ONCE by STEP 2 (drop 15 + 3 together).
--
-- SAFE TO RUN WHILE THE 15 COLUMNS STILL EXIST. EF Core ignores unmapped columns, so the
-- new application build can be deployed first; this script then populates settings for all
-- PRE-EXISTING pages. Pages created AFTER the new build already self-seed on Create.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on (OnlineDonationPageId, ParamCode)
-- for active rows, so re-running never duplicates.
--
-- VALUE RULES (mirror PresentationOnlineDonationPageSettings.BuildRows):
--   * Nullable string/text/url/color columns → row SKIPPED when NULL or blank
--     (the assembler's coded fallback applies on read).
--   * Nullable bool columns (IframeShowHeader/Footer) → row SKIPPED when NULL,
--     else serialized lowercase 'true' / 'false'.
--   * The 3 NON-NULLABLE bools (ShowDonorCount, ShowSocialShare, RobotsIndexable) →
--     ALWAYS emit a row, serialized lowercase 'true' / 'false'.
--   * Backfills EVERY page (incl. soft-deleted) so no value is lost before the drop.
--   * CUSTOM_CSS is copied verbatim (NOT re-sanitized here); runtime CSP still guards it
--     and the next Update re-strips <script> via the BE writer.
-- =====================================================================================

BEGIN;

-- ── THEME ────────────────────────────────────────────────────────────────────────────

-- 1. PRIMARY_COLOR  (color)  ← PrimaryColorHex  [nullable, skip blank]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'THEME', 'PRIMARY_COLOR', 'Primary Colour', 'color', p."PrimaryColorHex", 1, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NULLIF(btrim(p."PrimaryColorHex"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'PRIMARY_COLOR' AND s."IsDeleted" = false);

-- 2. DONATE_BUTTON_TEXT  (string)  ← ButtonText  [nullable, skip blank]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'THEME', 'DONATE_BUTTON_TEXT', 'Donate Button Text', 'string', p."ButtonText", 2, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NULLIF(btrim(p."ButtonText"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'DONATE_BUTTON_TEXT' AND s."IsDeleted" = false);

-- 3. PAGE_LAYOUT  (string)  ← PageLayout  [nullable, skip blank]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'THEME', 'PAGE_LAYOUT', 'Page Layout', 'string', p."PageLayout", 3, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NULLIF(btrim(p."PageLayout"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'PAGE_LAYOUT' AND s."IsDeleted" = false);

-- 4. CUSTOM_CSS  (text)  ← CustomCssOverride  [nullable, skip blank; copied verbatim]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'THEME', 'CUSTOM_CSS', 'Custom CSS Override', 'text', p."CustomCssOverride", 4, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NULLIF(btrim(p."CustomCssOverride"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'CUSTOM_CSS' AND s."IsDeleted" = false);

-- ── EMBED ────────────────────────────────────────────────────────────────────────────

-- 5. IFRAME_SHOW_HEADER  (bool)  ← IframeShowHeader  [nullable, skip NULL]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'EMBED', 'IFRAME_SHOW_HEADER', 'Show Header (Iframe)', 'bool',
       CASE WHEN p."IframeShowHeader" THEN 'true' ELSE 'false' END, 1, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE p."IframeShowHeader" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'IFRAME_SHOW_HEADER' AND s."IsDeleted" = false);

-- 6. IFRAME_SHOW_FOOTER  (bool)  ← IframeShowFooter  [nullable, skip NULL]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'EMBED', 'IFRAME_SHOW_FOOTER', 'Show Footer (Iframe)', 'bool',
       CASE WHEN p."IframeShowFooter" THEN 'true' ELSE 'false' END, 2, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE p."IframeShowFooter" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'IFRAME_SHOW_FOOTER' AND s."IsDeleted" = false);

-- ── THANKYOU ─────────────────────────────────────────────────────────────────────────

-- 7. THANKYOU_MESSAGE  (text)  ← ThankYouMessage  [nullable, skip blank]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'THANKYOU', 'THANKYOU_MESSAGE', 'Thank-You Message', 'text', p."ThankYouMessage", 1, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NULLIF(btrim(p."ThankYouMessage"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'THANKYOU_MESSAGE' AND s."IsDeleted" = false);

-- 8. THANKYOU_REDIRECT_URL  (url)  ← ThankYouRedirectUrl  [nullable, skip blank]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'THANKYOU', 'THANKYOU_REDIRECT_URL', 'Thank-You Redirect URL', 'url', p."ThankYouRedirectUrl", 2, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NULLIF(btrim(p."ThankYouRedirectUrl"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'THANKYOU_REDIRECT_URL' AND s."IsDeleted" = false);

-- ── SOCIAL (non-nullable bools — always emit) ────────────────────────────────────────

-- 9. SHOW_DONOR_COUNT  (bool)  ← ShowDonorCount  [non-nullable]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'SOCIAL', 'SHOW_DONOR_COUNT', 'Show Donor Count', 'bool',
       CASE WHEN p."ShowDonorCount" THEN 'true' ELSE 'false' END, 1, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'SHOW_DONOR_COUNT' AND s."IsDeleted" = false);

-- 10. SHOW_SOCIAL_SHARE  (bool)  ← ShowSocialShare  [non-nullable]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'SOCIAL', 'SHOW_SOCIAL_SHARE', 'Show Social Share', 'bool',
       CASE WHEN p."ShowSocialShare" THEN 'true' ELSE 'false' END, 2, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'SHOW_SOCIAL_SHARE' AND s."IsDeleted" = false);

-- ── RECEIPT ──────────────────────────────────────────────────────────────────────────

-- 11. TAX_RECEIPT_NOTE  (text)  ← TaxReceiptNote  [nullable, skip blank]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'RECEIPT', 'TAX_RECEIPT_NOTE', 'Tax Receipt Note', 'text', p."TaxReceiptNote", 1, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NULLIF(btrim(p."TaxReceiptNote"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'TAX_RECEIPT_NOTE' AND s."IsDeleted" = false);

-- ── SEO ──────────────────────────────────────────────────────────────────────────────
-- NOTE: verify these SEO rows + the public SSR <head> (og:title / og:description /
-- og:image / robots) render correctly from settings BEFORE running STEP 2 (drop).

-- 12. OG_TITLE  (string)  ← OgTitle  [nullable, skip blank]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'SEO', 'OG_TITLE', 'OG Title', 'string', p."OgTitle", 1, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NULLIF(btrim(p."OgTitle"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'OG_TITLE' AND s."IsDeleted" = false);

-- 13. OG_DESCRIPTION  (text)  ← OgDescription  [nullable, skip blank]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'SEO', 'OG_DESCRIPTION', 'OG Description', 'text', p."OgDescription", 2, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NULLIF(btrim(p."OgDescription"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'OG_DESCRIPTION' AND s."IsDeleted" = false);

-- 14. OG_IMAGE_URL  (url)  ← OgImageUrl  [nullable, skip blank]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'SEO', 'OG_IMAGE_URL', 'OG Image URL', 'url', p."OgImageUrl", 3, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NULLIF(btrim(p."OgImageUrl"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'OG_IMAGE_URL' AND s."IsDeleted" = false);

-- 15. ROBOTS_INDEXABLE  (bool)  ← RobotsIndexable  [non-nullable]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'SEO', 'ROBOTS_INDEXABLE', 'Search-Engine Indexable', 'bool',
       CASE WHEN p."RobotsIndexable" THEN 'true' ELSE 'false' END, 4, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'ROBOTS_INDEXABLE' AND s."IsDeleted" = false);

-- ── MEDIA (ISSUE-42 — template media relocation) ─────────────────────────────────────
-- Mirrors PresentationOnlineDonationPageSettings.BuildRows MEDIA catalog. All three are
-- nullable-source → SKIP when NULL/blank/empty (assembler falls back to null/empty list).
-- CAROUSEL_SLIDES stored jsonb is copied verbatim as text; the assembler deserializes it
-- back into List<CarouselSlide> and TRUNCATES to the first 5 by Order on read, so legacy
-- rows holding >5 slides are safe here (no truncation needed in the backfill).

-- 16. LOGO_URL  (url)  ← LogoUrl  [nullable, skip blank]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'MEDIA', 'LOGO_URL', 'Logo URL', 'url', p."LogoUrl", 1, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NULLIF(btrim(p."LogoUrl"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'LOGO_URL' AND s."IsDeleted" = false);

-- 17. HERO_IMAGE_URL  (url)  ← HeroImageUrl  [nullable, skip blank]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'MEDIA', 'HERO_IMAGE_URL', 'Hero Image URL', 'url', p."HeroImageUrl", 2, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NULLIF(btrim(p."HeroImageUrl"), '') IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'HERO_IMAGE_URL' AND s."IsDeleted" = false);

-- 18. CAROUSEL_SLIDES  (json)  ← CarouselSlidesJson  [nullable jsonb, skip NULL / empty array]
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'MEDIA', 'CAROUSEL_SLIDES', 'Carousel Slides', 'json', p."CarouselSlidesJson"::text, 3, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE p."CarouselSlidesJson" IS NOT NULL
  AND jsonb_typeof(p."CarouselSlidesJson") = 'array'
  AND jsonb_array_length(p."CarouselSlidesJson") > 0
  AND NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'CAROUSEL_SLIDES' AND s."IsDeleted" = false);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT; expect one row per managed ParamCode per page that had a value):
--   SELECT "OnlineDonationPageId", "SectionCode", "ParamCode", "ParamValue"
--   FROM fund."OnlineDonationPageSettings"
--   WHERE "ParamCode" IN ('PRIMARY_COLOR','DONATE_BUTTON_TEXT','PAGE_LAYOUT','CUSTOM_CSS',
--                         'IFRAME_SHOW_HEADER','IFRAME_SHOW_FOOTER','THANKYOU_MESSAGE',
--                         'THANKYOU_REDIRECT_URL','SHOW_DONOR_COUNT','SHOW_SOCIAL_SHARE',
--                         'TAX_RECEIPT_NOTE','OG_TITLE','OG_DESCRIPTION','OG_IMAGE_URL',
--                         'ROBOTS_INDEXABLE')
--     AND "IsDeleted" = false
--   ORDER BY "OnlineDonationPageId", "SectionCode", "OrderBy";
-- =====================================================================================
