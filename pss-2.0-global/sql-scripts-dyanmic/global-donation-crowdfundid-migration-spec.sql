-- =============================================================================
-- MIGRATION SPEC — GlobalDonation.CrowdFundId direct FK  (replaces the
--                  fund.CrowdFundDonations junction)   —  2026-07-17
-- Screens: #16 / #173 (Crowdfunding) + #175 (Online Donation Inbox)
-- =============================================================================
--
-- OWNERSHIP:  This file is a HAND-OFF SPEC, not an applied migration.
--   * Claude authored the C# model/config/query/command changes (build-clean).
--   * YOU author the real EF migration + run it + commit it.
--   * The EF migration you scaffold (`dotnet ef migrations add
--     AddGlobalDonationCrowdFundId`) will generate the Up/Down + snapshot from
--     the already-changed model. The SQL below is the EXPECTED shape — use it to
--     (a) sanity-check the scaffold, and (b) run the DATA BACKFILL, which EF will
--     NOT generate for you (steps 2 & 4 must be done by hand, in order).
--
-- APPLY ORDER (do NOT reorder — the drop must come AFTER the backfill verifies):
--   1. Schema: add column + FK + index + widen CHECK        (EF scaffold covers)
--   2. Backfill: copy junction rows → new column             (MANUAL — this file)
--   3. VERIFY backfill parity                                (MANUAL — this file)
--   4. Drop the junction table                               (EF scaffold covers,
--                                                             but only run after 3)
--
-- =============================================================================
-- STEP 1 — SCHEMA (EF migration Up() should emit equivalent DDL)
-- =============================================================================

-- 1a. New nullable FK column
ALTER TABLE fund."GlobalDonations"
    ADD COLUMN "CrowdFundId" integer NULL;

-- 1b. FK → fund.CrowdFunds (RESTRICT, matching every other GlobalDonation source FK)
ALTER TABLE fund."GlobalDonations"
    ADD CONSTRAINT "FK_GlobalDonations_CrowdFunds_CrowdFundId"
    FOREIGN KEY ("CrowdFundId")
    REFERENCES fund."CrowdFunds" ("CrowdFundId")
    ON DELETE RESTRICT;

-- 1c. Lookup index (mirrors IX_GlobalDonations_OnlineDonationPageId / _P2PCampaignPageId)
CREATE INDEX "IX_GlobalDonations_CrowdFundId"
    ON fund."GlobalDonations" ("CrowdFundId");

-- 1d. Widen the one-source CHECK from 2 cols → 3 cols.
--     The existing constraint was added by the ODP/P2P work and lists only two
--     columns, so it must be DROPPED and re-created (Postgres CHECKs are immutable).
ALTER TABLE fund."GlobalDonations"
    DROP CONSTRAINT IF EXISTS "CK_GlobalDonations_OnePageSource";

ALTER TABLE fund."GlobalDonations"
    ADD CONSTRAINT "CK_GlobalDonations_OnePageSource"
    CHECK (num_nonnulls("OnlineDonationPageId", "P2PCampaignPageId", "CrowdFundId") <= 1);

-- =============================================================================
-- STEP 2 — DATA BACKFILL  (MANUAL — EF will NOT generate this)
--     Copy every live junction link onto the new column BEFORE dropping the table.
--     Only non-deleted junction rows are carried over; a GlobalDonation funds at
--     most one campaign, so there is no many-row collision on the target column.
-- =============================================================================

UPDATE fund."GlobalDonations" g
   SET "CrowdFundId" = j."CrowdFundId"
  FROM fund."CrowdFundDonations" j
 WHERE j."GlobalDonationId" = g."GlobalDonationId"
   AND j."IsDeleted" = false;

-- =============================================================================
-- STEP 3 — VERIFY PARITY  (MANUAL — run and eyeball BEFORE step 4)
--     Every live junction link must now have a matching column value.
--     Expected result: ZERO rows. If any row returns, STOP and investigate —
--     do NOT drop the junction table.
-- =============================================================================

SELECT j."CrowdFundId",
       j."GlobalDonationId",
       g."CrowdFundId" AS "BackfilledCrowdFundId"
  FROM fund."CrowdFundDonations" j
  JOIN fund."GlobalDonations"   g ON g."GlobalDonationId" = j."GlobalDonationId"
 WHERE j."IsDeleted" = false
   AND (g."CrowdFundId" IS NULL OR g."CrowdFundId" <> j."CrowdFundId");
-- (also: SELECT count(*) FROM fund."CrowdFundDonations" WHERE "IsDeleted" = false;
--  compare to SELECT count(*) FROM fund."GlobalDonations" WHERE "CrowdFundId" IS NOT NULL;)

-- =============================================================================
-- STEP 4 — DROP THE JUNCTION  (EF scaffold covers — run ONLY after step 3 is clean)
--     The C# side has already removed: CrowdFundDonation.cs entity,
--     CrowdFundDonationConfiguration.cs, the CrowdFundDonations DbSet on
--     DonationDbContext/IDonationDbContext, and every consumer query/command.
-- =============================================================================

DROP TABLE fund."CrowdFundDonations";

-- =============================================================================
-- DOWN (rollback) — recreate the table, backfill from the column, drop the column.
-- Provided for completeness; EF's Down() should mirror the reverse of step 1.
-- Note: the junction's original schema (audit cols + unique index on
-- GlobalDonationId) must be recreated exactly from the pre-drop snapshot before
-- any data is copied back.
-- =============================================================================
