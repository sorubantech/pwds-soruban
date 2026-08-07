-- ============================================================================
-- Screen #2 (Donation Purpose) — ISSUE-5 channel-attribution backfill
-- ----------------------------------------------------------------------------
-- Crowdfund and P2P donations were promoted with a NULL GlobalDonationDistribution
-- OrganizationalUnitId, so they never counted toward their Donation Purpose's
-- "Raised" (Raised = Σ GlobalDonationDistribution.AllocatedAmount WHERE
-- OrganizationalUnitId == the purpose's dedicated node — DonationPurposeRaisedHelper).
--
-- The forward code fix (InitiateCrowdFundDonation / InitiateP2PDonation stamp the
-- purpose node at initiate; ResolveOnlineDonationStaging derives it when null) makes
-- all NEW donations correct. This script back-fills the EXISTING promoted rows.
--
-- Linkage: OnlineDonationStagings.PromotedGlobalDonationId → the promoted
-- GlobalDonation. The purpose node comes from the source page's DonationPurpose
-- (CrowdFund.DonationPurposeId / P2PCampaignPage.DonationPurposeId → node).
--
-- Idempotent: only fills rows that are currently NULL. Safe to re-run.
-- Owner: USER reviews + runs + commits (per migration ownership policy).
-- ============================================================================

BEGIN;

-- ── 0) PRE-CHECK: rows that will be affected (review before committing) ──────
WITH src AS (
    SELECT s."PromotedGlobalDonationId"        AS gdid,
           COALESCE(cf."DonationPurposeId", p2p."DonationPurposeId") AS purpose_id,
           dp."OrganizationalUnitId"           AS node
    FROM fund."OnlineDonationStagings" s
    LEFT JOIN fund."CrowdFunds" cf        ON cf."CrowdFundId"       = s."CrowdFundId"
    LEFT JOIN fund."P2PCampaignPages" p2p ON p2p."P2PCampaignPageId" = s."P2PCampaignPageId"
    JOIN fund."DonationPurposes" dp
           ON dp."DonationPurposeId" = COALESCE(cf."DonationPurposeId", p2p."DonationPurposeId")
    WHERE s."PromotedGlobalDonationId" IS NOT NULL
      AND (s."CrowdFundId" IS NOT NULL OR s."P2PCampaignPageId" IS NOT NULL)
      AND dp."OrganizationalUnitId" IS NOT NULL
)
SELECT d."GlobalDonationDistributionId", d."GlobalDonationId",
       d."AllocatedAmount", d."OrganizationalUnitId" AS current_unit,
       src.purpose_id, src.node AS will_set_to
FROM fund."GlobalDonationDistributions" d
JOIN src ON src.gdid = d."GlobalDonationId"
WHERE d."IsDeleted" = false
  AND d."OrganizationalUnitId" IS NULL
ORDER BY d."GlobalDonationId";

-- ── 1) Back-fill the DISTRIBUTION rows (what "Raised" actually sums) ─────────
WITH src AS (
    SELECT s."PromotedGlobalDonationId" AS gdid,
           dp."OrganizationalUnitId"    AS node
    FROM fund."OnlineDonationStagings" s
    LEFT JOIN fund."CrowdFunds" cf        ON cf."CrowdFundId"       = s."CrowdFundId"
    LEFT JOIN fund."P2PCampaignPages" p2p ON p2p."P2PCampaignPageId" = s."P2PCampaignPageId"
    JOIN fund."DonationPurposes" dp
           ON dp."DonationPurposeId" = COALESCE(cf."DonationPurposeId", p2p."DonationPurposeId")
    WHERE s."PromotedGlobalDonationId" IS NOT NULL
      AND (s."CrowdFundId" IS NOT NULL OR s."P2PCampaignPageId" IS NOT NULL)
      AND dp."OrganizationalUnitId" IS NOT NULL
)
UPDATE fund."GlobalDonationDistributions" d
SET "OrganizationalUnitId" = src.node
FROM src
WHERE d."GlobalDonationId" = src.gdid
  AND d."IsDeleted" = false
  AND d."OrganizationalUnitId" IS NULL;

-- ── 2) Keep the DONATION HEADER consistent with its distributions ───────────
WITH src AS (
    SELECT s."PromotedGlobalDonationId" AS gdid,
           dp."OrganizationalUnitId"    AS node
    FROM fund."OnlineDonationStagings" s
    LEFT JOIN fund."CrowdFunds" cf        ON cf."CrowdFundId"       = s."CrowdFundId"
    LEFT JOIN fund."P2PCampaignPages" p2p ON p2p."P2PCampaignPageId" = s."P2PCampaignPageId"
    JOIN fund."DonationPurposes" dp
           ON dp."DonationPurposeId" = COALESCE(cf."DonationPurposeId", p2p."DonationPurposeId")
    WHERE s."PromotedGlobalDonationId" IS NOT NULL
      AND (s."CrowdFundId" IS NOT NULL OR s."P2PCampaignPageId" IS NOT NULL)
      AND dp."OrganizationalUnitId" IS NOT NULL
)
UPDATE fund."GlobalDonations" g
SET "OrganizationalUnitId" = src.node
FROM src
WHERE g."GlobalDonationId" = src.gdid
  AND g."OrganizationalUnitId" IS NULL;

-- ── 3) POST-CHECK: verify nothing crowdfund/P2P is still orphaned ───────────
--     (expect 0 rows once the back-fill has run)
SELECT COUNT(*) AS still_null_distributions
FROM fund."GlobalDonationDistributions" d
JOIN fund."OnlineDonationStagings" s ON s."PromotedGlobalDonationId" = d."GlobalDonationId"
LEFT JOIN fund."CrowdFunds" cf        ON cf."CrowdFundId"       = s."CrowdFundId"
LEFT JOIN fund."P2PCampaignPages" p2p ON p2p."P2PCampaignPageId" = s."P2PCampaignPageId"
JOIN fund."DonationPurposes" dp
       ON dp."DonationPurposeId" = COALESCE(cf."DonationPurposeId", p2p."DonationPurposeId")
WHERE (s."CrowdFundId" IS NOT NULL OR s."P2PCampaignPageId" IS NOT NULL)
  AND dp."OrganizationalUnitId" IS NOT NULL
  AND d."IsDeleted" = false
  AND d."OrganizationalUnitId" IS NULL;

-- Review the PRE/POST-CHECK output, then:  COMMIT;   (or ROLLBACK; to abort)
COMMIT;
