-- ═════════════════════════════════════════════════════════════════════════════════════════════
--  BACKFILL (idempotent) — flip already-activated tenants stuck in PROVISIONING to ACTIVE
--
--  WHY: Before the go-live fix, ProvisionTenant stamped OnboardedOn at creation and NOTHING ever
--  flipped Company.Status. So tenants whose primary admin already activated (chose a password via
--  the welcome link) are stuck at Status='PROVISIONING'. Their activation token is already burned,
--  so re-activating won't re-trigger the new flip — they need this one-time data correction.
--
--  Going forward (new fix): AccountActivation flips Status PROVISIONING→ACTIVE + stamps OnboardedOn
--  at the moment the primary admin activates. This script only heals rows created BEFORE that fix.
--
--  Heuristic for "already activated": the company has at least one usable admin user —
--    IsActive = true, IsPendingInvitation = false, a non-empty PasswordHash, not deleted.
--  OnboardedOn is set to that admin's activation time (earliest such user's ModifiedDate), or now.
--
--  Idempotent: only touches Status='PROVISIONING' rows; once ACTIVE, re-runs are no-ops.
-- ═════════════════════════════════════════════════════════════════════════════════════════════

-- Preview what will change (run first to eyeball it):
SELECT c."CompanyId", c."CompanyCode", c."CompanyName", c."Subdomain", c."Status"
FROM app."Companies" c
WHERE c."Status" = 'PROVISIONING'
  AND c."IsDeleted" IS DISTINCT FROM true
  AND EXISTS (
      SELECT 1 FROM auth."Users" u
      WHERE u."CompanyId" = c."CompanyId"
        AND u."IsActive" = true
        AND u."IsPendingInvitation" = false
        AND u."PasswordHash" IS NOT NULL
        AND octet_length(u."PasswordHash") > 0
        AND u."IsDeleted" IS DISTINCT FROM true
  );

-- Apply the flip:
UPDATE app."Companies" c
   SET "Status"       = 'ACTIVE',
       "OnboardedOn"  = COALESCE(
                          (SELECT MIN(u."ModifiedDate")
                             FROM auth."Users" u
                            WHERE u."CompanyId" = c."CompanyId"
                              AND u."IsActive" = true
                              AND u."IsPendingInvitation" = false
                              AND u."PasswordHash" IS NOT NULL
                              AND octet_length(u."PasswordHash") > 0
                              AND u."IsDeleted" IS DISTINCT FROM true),
                          (now() AT TIME ZONE 'utc')),
       "ModifiedDate" = (now() AT TIME ZONE 'utc')
 WHERE c."Status" = 'PROVISIONING'
   AND c."IsDeleted" IS DISTINCT FROM true
   AND EXISTS (
       SELECT 1 FROM auth."Users" u
       WHERE u."CompanyId" = c."CompanyId"
         AND u."IsActive" = true
         AND u."IsPendingInvitation" = false
         AND u."PasswordHash" IS NOT NULL
         AND octet_length(u."PasswordHash") > 0
         AND u."IsDeleted" IS DISTINCT FROM true
   );

-- Verify:
SELECT c."CompanyId", c."CompanyCode", c."Subdomain", c."Status", c."OnboardedOn"
FROM app."Companies" c
ORDER BY c."CompanyId";
