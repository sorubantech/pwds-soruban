-- ═══════════════════════════════════════════════════════════════════════════════════════════════
--  P-21 (§3.7) — LEAD ASSIGNMENT HISTORY BACKFILL                                     [OPTIONAL]
--
--  WHY THIS EXISTS
--  ops.Leads.OwnerUserId shipped in P-05, long before ops.LeadAssignments existed. So every lead
--  created before the Add_LeadAssignment_And_AccountManager migration has a current owner and an
--  EMPTY ownership history. The detail panel then renders "Owner: Priya" above "No assignment
--  history", which is literally true — we genuinely never recorded who assigned those leads — but
--  reads to a user as a broken screen.
--
--  This script closes that gap by synthesising ONE OPEN EPISODE per affected lead. It does not
--  invent an assigner: AssignedByUserId is set to the owner themselves, which is the same shape a
--  self-claim produces, and the Note says plainly that the row is reconstructed. Nobody is recorded
--  as having done something they did not do.
--
--  OPTIONAL. Skipping it is a valid choice — the feature works either way, legacy leads just show an
--  empty history. Run it if you would rather the screen be complete than the audit trail be pristine.
--
--  PREREQUISITE: the Add_LeadAssignment_And_AccountManager migration (ops.LeadAssignments must
--  exist, and ops.Leads must have AssignedByUserId / AssignedOn).
--
--  IDEMPOTENT. Guarded on "this lead has no LeadAssignments row at all", so a second run inserts
--  nothing. Note that guard is deliberately NOT "has no OPEN row": if a lead already has any history
--  it is being managed by AssignLeadHandler and this script must keep its hands off it entirely.
--
--  SAFE TO RUN ON A LIVE DB. Insert-only plus one narrow UPDATE; touches no lead that already has
--  history, and never changes OwnerUserId.
--
--  RUN THE PREVIEW (section 0) FIRST. It shows exactly what section 1 will create.
-- ═══════════════════════════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  0. PREVIEW — run this on its own before the transaction below. Read-only.
-- ───────────────────────────────────────────────────────────────────────────────────────────────
-- SELECT l."LeadId", l."OrganizationName", l."Status", l."OwnerUserId",
--        COALESCE(l."ModifiedDate", l."CreatedDate") AS "AssignedOn_will_be"
--   FROM ops."Leads" l
--  WHERE l."OwnerUserId" IS NOT NULL
--    AND l."IsDeleted" IS DISTINCT FROM TRUE
--    AND NOT EXISTS (SELECT 1 FROM ops."LeadAssignments" a WHERE a."LeadId" = l."LeadId")
--  ORDER BY l."LeadId";


BEGIN;

-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  1. Synthesise one open episode per owned lead that has no history.
--
--  AssignedOn = ModifiedDate ?? CreatedDate. Not now(): stamping today would make a two-year-old
--  relationship show as "assigned 0 days ago" and poison the assignment-age column the grid sorts on.
--  ModifiedDate is the closest defensible proxy for when ownership was last touched.
--
--  UnassignedOn stays NULL — this IS the current episode, matching OwnerUserId.
-- ───────────────────────────────────────────────────────────────────────────────────────────────
INSERT INTO ops."LeadAssignments"
  ("LeadId","AssignedToUserId","AssignedByUserId","AssignedOn","UnassignedOn","Note",
   "CreatedBy","CreatedDate","IsActive","IsDeleted")
SELECT
  l."LeadId",
  l."OwnerUserId",
  l."OwnerUserId",                                    -- no assigner on record; see header
  COALESCE(l."ModifiedDate", l."CreatedDate"),
  NULL,
  'Reconstructed from the lead''s existing owner when assignment history was introduced. The original assigner was not recorded.',
  COALESCE(l."ModifiedBy", l."CreatedBy"),
  now(),
  TRUE,
  FALSE
FROM ops."Leads" l
WHERE l."OwnerUserId" IS NOT NULL
  AND l."IsDeleted" IS DISTINCT FROM TRUE
  AND NOT EXISTS (
    SELECT 1 FROM ops."LeadAssignments" a WHERE a."LeadId" = l."LeadId"
  );

-- ───────────────────────────────────────────────────────────────────────────────────────────────
--  2. Bring the denormalised columns on ops.Leads in step with the episodes just created.
--
--  AssignedByUserId / AssignedOn are the grid's join-free "Assigned By" and "assigned N days ago"
--  columns. AssignLeadHandler writes them alongside every episode; the rows section 1 created need
--  the same treatment or the grid stays blank for exactly the leads we just fixed the panel for.
--
--  Scoped to leads whose ONLY episode is an open one we could have created — a lead already managed
--  by the handler has correct values and is left alone.
-- ───────────────────────────────────────────────────────────────────────────────────────────────
UPDATE ops."Leads" l
   SET "AssignedByUserId" = a."AssignedByUserId",
       "AssignedOn"       = a."AssignedOn"
  FROM ops."LeadAssignments" a
 WHERE a."LeadId" = l."LeadId"
   AND a."UnassignedOn" IS NULL
   AND a."IsDeleted" IS DISTINCT FROM TRUE
   AND l."AssignedOn" IS NULL                        -- only the never-stamped ones
   AND l."OwnerUserId" = a."AssignedToUserId";       -- and only where they genuinely agree

COMMIT;


-- ═══════════════════════════════════════════════════════════════════════════════════════════════
--  VERIFY — run after COMMIT.
-- ═══════════════════════════════════════════════════════════════════════════════════════════════

-- Owned leads still lacking any history. Expect 0 rows.
-- SELECT l."LeadId", l."OrganizationName", l."OwnerUserId"
--   FROM ops."Leads" l
--  WHERE l."OwnerUserId" IS NOT NULL
--    AND l."IsDeleted" IS DISTINCT FROM TRUE
--    AND NOT EXISTS (SELECT 1 FROM ops."LeadAssignments" a WHERE a."LeadId" = l."LeadId");

-- The invariant AssignLeadHandler enforces in code: at most one open episode per lead.
-- Expect 0 rows. If this returns anything, STOP — do not let the app write further assignments
-- until it is resolved, because the handler assumes SingleOrDefault on the open row.
-- SELECT "LeadId", COUNT(*) AS open_episodes
--   FROM ops."LeadAssignments"
--  WHERE "UnassignedOn" IS NULL AND "IsDeleted" IS DISTINCT FROM TRUE
--  GROUP BY "LeadId"
-- HAVING COUNT(*) > 1;

-- The open episode must agree with OwnerUserId. Expect 0 rows.
-- SELECT l."LeadId", l."OwnerUserId", a."AssignedToUserId"
--   FROM ops."Leads" l
--   JOIN ops."LeadAssignments" a
--     ON a."LeadId" = l."LeadId" AND a."UnassignedOn" IS NULL AND a."IsDeleted" IS DISTINCT FROM TRUE
--  WHERE l."OwnerUserId" IS DISTINCT FROM a."AssignedToUserId";

-- What was created, for the record.
-- SELECT COUNT(*) AS backfilled
--   FROM ops."LeadAssignments"
--  WHERE "Note" LIKE 'Reconstructed from the lead%';
