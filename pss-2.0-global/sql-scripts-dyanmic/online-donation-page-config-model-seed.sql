-- =====================================================================================
-- ISSUE-44 / ISSUE-45 — Online Donation Page (Screen #10) STANDARD (Aurora) config-model
-- extension : ADDITIVE BACKFILL of the NEW landing ParamCodes for PRE-EXISTING pages.
-- -------------------------------------------------------------------------------------
-- Pages created AFTER the new build self-seed these rows on Create via
--   DefaultOnlineDonationPageSettings.BuildDefaultRows(...).
-- This script seeds the same DEFAULTS into pages that already existed before the build,
-- so their Aurora renderer shows the new sections (two-tone mission title, donate-card
-- heading, Testimonials, FAQ, recursive footer tree) out-of-the-box.
--
-- Unlike the ISSUE-41 backfill, these rows are NOT copied from typed columns — they are
-- literal STANDARD-template defaults (no source column exists). Existing MISSION_TITLE /
-- MISSION_BODY rows are LEFT UNTOUCHED; only the NEW ParamCodes are added.
--
-- NEW ParamCodes seeded (7):
--   MISSION      / MISSION_TITLE_ACCENT   string   'Change Lives'            (ISSUE-45a)
--   MISSION      / DONATE_CARD_HEADING    string   'Make Your Donation'      (ISSUE-45a)
--   TESTIMONIALS / TESTIMONIALS_TITLE     string   'What Our Supporters Say' (ISSUE-45)
--   TESTIMONIALS / TESTIMONIALS           json     [2 default testimonials]  (ISSUE-45)
--   FAQ          / FAQ_TITLE              string   'Frequently Asked Questions'
--   FAQ          / FAQS                   json     [4 default Q&A]           (ISSUE-45)
--   FOOTER       / FOOTER_TREE            json     []  (empty — assembler synthesizes
--                                                   from flat FOOTER_LINKS on read)  (ISSUE-44)
--
-- JSON ParamValues are camelCase to match LandingContentDto (quote/authorName/authorRole/
-- rating ; question/answer ; label/url/iconName/imageUrl/children), i.e. exactly what
-- DefaultOnlineDonationPageSettings.Serialize(...) writes and AssembleLandingContentDto reads.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on (OnlineDonationPageId, ParamCode)
-- for active rows, so re-running never duplicates.
--
-- SAFE: additive only. No DROP, no UPDATE, no schema change. Backfills EVERY page (a
-- non-STANDARD template simply ignores unknown landing ParamCodes on render).
-- =====================================================================================

BEGIN;

-- ── MISSION (two-tone title + donate-card heading — ISSUE-45a) ────────────────────────

-- 1. MISSION_TITLE_ACCENT  (string)  — second-tone half of the mission heading
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'MISSION', 'MISSION_TITLE_ACCENT', 'Mission Title Accent', 'string', 'Change Lives', 2, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'MISSION_TITLE_ACCENT' AND s."IsDeleted" = false);

-- 2. DONATE_CARD_HEADING  (string)  — heading above the embedded donation form card
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'MISSION', 'DONATE_CARD_HEADING', 'Donate Card Heading', 'string', 'Make Your Donation', 4, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'DONATE_CARD_HEADING' AND s."IsDeleted" = false);

-- ── TESTIMONIALS (new section — ISSUE-45) ─────────────────────────────────────────────

-- 3. TESTIMONIALS_TITLE  (string)
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'TESTIMONIALS', 'TESTIMONIALS_TITLE', 'Testimonials Heading', 'string', 'What Our Supporters Say', 1, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'TESTIMONIALS_TITLE' AND s."IsDeleted" = false);

-- 4. TESTIMONIALS  (json — array of {quote,authorName,authorRole,rating})
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'TESTIMONIALS', 'TESTIMONIALS', 'Testimonials', 'json',
       '[{"quote":"Giving here was effortless and I received my receipt instantly. I finally feel confident my donation reaches the people who need it.","authorName":"A Grateful Supporter","authorRole":"Monthly Donor","rating":5},{"quote":"Transparent, professional, and deeply impactful. I have seen first-hand the difference these programs make in the community.","authorName":"A Long-Term Partner","authorRole":"Corporate Sponsor","rating":5}]',
       2, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'TESTIMONIALS' AND s."IsDeleted" = false);

-- ── FAQ (new section — ISSUE-45) ──────────────────────────────────────────────────────

-- 5. FAQ_TITLE  (string)
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'FAQ', 'FAQ_TITLE', 'FAQ Heading', 'string', 'Frequently Asked Questions', 1, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'FAQ_TITLE' AND s."IsDeleted" = false);

-- 6. FAQS  (json — array of {question,answer})
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'FAQ', 'FAQS', 'FAQs', 'json',
       '[{"question":"Is my donation secure?","answer":"Yes. Every payment is processed over an encrypted, PCI-compliant gateway. We never store your card details."},{"question":"Will I receive a receipt?","answer":"An official receipt is issued automatically to your email for every eligible contribution."},{"question":"Can I make a recurring gift?","answer":"Absolutely. Choose the recurring option on the donation form to support us monthly."},{"question":"Where does my money go?","answer":"The vast majority of every gift goes directly to program delivery. We publish how contributions are put to work."}]',
       2, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'FAQS' AND s."IsDeleted" = false);

-- ── FOOTER (recursive tree — ISSUE-44) ────────────────────────────────────────────────
-- Seed an EMPTY tree. On read the assembler synthesizes a "Useful Information" column from
-- the existing flat FOOTER_LINKS when this is empty, so an empty seed is the correct default
-- (an explicit tree, once curated in the editor, then takes over).

-- 7. FOOTER_TREE  (json — recursive array of {label,iconName,imageUrl,url,children})
INSERT INTO fund."OnlineDonationPageSettings"
  ("OnlineDonationPageId","CompanyId","SectionCode","ParamCode","ParamName","ParamDataType","ParamValue","OrderBy","CreatedDate","IsActive","IsDeleted")
SELECT p."OnlineDonationPageId", p."CompanyId", 'FOOTER', 'FOOTER_TREE', 'Footer Tree', 'json', '[]', 4, now(), true, false
FROM fund."OnlineDonationPages" p
WHERE NOT EXISTS (SELECT 1 FROM fund."OnlineDonationPageSettings" s
                  WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId" AND s."ParamCode" = 'FOOTER_TREE' AND s."IsDeleted" = false);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT; expect one row per new ParamCode per page):
--   SELECT "OnlineDonationPageId", "SectionCode", "ParamCode", left("ParamValue", 40) AS val
--   FROM fund."OnlineDonationPageSettings"
--   WHERE "ParamCode" IN ('MISSION_TITLE_ACCENT','DONATE_CARD_HEADING','TESTIMONIALS_TITLE',
--                         'TESTIMONIALS','FAQ_TITLE','FAQS','FOOTER_TREE')
--     AND "IsDeleted" = false
--   ORDER BY "OnlineDonationPageId", "SectionCode", "OrderBy";
-- =====================================================================================
