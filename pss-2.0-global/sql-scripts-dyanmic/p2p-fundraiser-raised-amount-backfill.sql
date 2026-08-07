-- =============================================================================
-- Screen #135 P2PFundraiser — RaisedAmount / DonorCount backfill
-- Bug: P2PFundraiser.RaisedAmount + DonorCount are denormalized aggregates that
--      every create path initialised to 0 and NO path ever recomputed. Result:
--      the admin grid, fundraiser detail, public fundraiser page and both
--      leaderboards all showed 0% progress regardless of real donations.
--
-- Code fix (2026-07-20): P2PFundraiserRollup.RecalculateAsync, called from both
--      promote paths (PromoteOnlineDonationStaging / ResolveOnlineDonationStaging).
--      That only fixes donations promoted FROM NOW ON — this script repairs the
--      rows already sitting in fund."GlobalDonations".
--
-- Safe to re-run: it is a full recompute, identical to the C# helper, not a delta.
-- Run once after deploying the code fix.
-- =============================================================================

BEGIN;

-- Preview (optional) — run this SELECT alone first to see what will change.
-- SELECT f."P2PFundraiserId", f."PageTitle", f."RaisedAmount" AS old_raised, a.raised AS new_raised,
--        f."DonorCount" AS old_donors, a.donors AS new_donors
-- FROM fund."P2PFundraisers" f
-- LEFT JOIN LATERAL (
--     SELECT COALESCE(SUM(g."NetAmount" - COALESCE(g."RefundedAmount", 0)), 0) AS raised,
--            COUNT(DISTINCT g."ContactId") + COUNT(*) FILTER (WHERE g."ContactId" IS NULL) AS donors
--     FROM fund."GlobalDonations" g
--     WHERE g."P2PFundraiserId" = f."P2PFundraiserId"
--       AND g."CompanyId" = f."CompanyId"
--       AND g."IsDeleted" = false
-- ) a ON TRUE
-- WHERE f."IsDeleted" = false
--   AND (f."RaisedAmount" <> a.raised OR f."DonorCount" <> a.donors);

UPDATE fund."P2PFundraisers" f
SET "RaisedAmount" = a.raised,
    "DonorCount"   = a.donors
FROM (
    SELECT f2."P2PFundraiserId",
           COALESCE(SUM(g."NetAmount" - COALESCE(g."RefundedAmount", 0)), 0) AS raised,
           -- COUNT(DISTINCT) ignores NULLs, so anonymous donations (ContactId NULL)
           -- are counted separately and added back — matches the C# helper exactly.
           COUNT(DISTINCT g."ContactId")
             + COUNT(*) FILTER (WHERE g."P2PFundraiserId" IS NOT NULL AND g."ContactId" IS NULL) AS donors
    FROM fund."P2PFundraisers" f2
    LEFT JOIN fund."GlobalDonations" g
           ON g."P2PFundraiserId" = f2."P2PFundraiserId"
          AND g."CompanyId"       = f2."CompanyId"
          AND g."IsDeleted"       = false
    WHERE f2."IsDeleted" = false
    GROUP BY f2."P2PFundraiserId"
) a
WHERE f."P2PFundraiserId" = a."P2PFundraiserId"
  AND (f."RaisedAmount" IS DISTINCT FROM a.raised
    OR f."DonorCount"   IS DISTINCT FROM a.donors);

COMMIT;
