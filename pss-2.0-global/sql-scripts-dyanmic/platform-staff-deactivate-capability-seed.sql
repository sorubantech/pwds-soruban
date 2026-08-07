-- =====================================================================================
--  PSS 2.0 — P-24 follow-up: PLATFORM_STAFF_DEACTIVATE
--
--  WHY THIS EXISTS
--  ---------------
--  Deactivating an operator was folded into PLATFORM_STAFF_MANAGE, alongside invite, edit,
--  unlock and resend-invite. Those are not the same power. Inviting an operator adds access;
--  deactivating one TAKES ACCESS AWAY from a person who is very likely logged in right now, and
--  it is the operation that can lock the control plane out entirely. Granting "manage staff" so
--  someone can resend an invitation should not also hand them the off switch.
--
--  So deactivate/reactivate gets a capability of its own. This mirrors what the tenant side has
--  always done: TOGGLE is the app's canonical activate/deactivate capability, distinct from
--  CREATE and MODIFY. The platform menus had no analogue until now.
--
--  ⚠ APPLY THIS BEFORE (OR WITH) THE BACKEND CHANGE.
--    SetPlatformStaffActiveCommand now declares
--        [CustomAuthorize("PLATFORM_STAFF", "PLATFORM_STAFF_DEACTIVATE")]
--    Until this script is applied, NOTHING grants that capability and Deactivate/Reactivate will
--    refuse every caller — including PLATFORM_ADMIN and SUPERADMIN.
--
--  NOT A REVOCATION (⚠ Rule 5). §3 does not name roles. It grants the new capability to exactly
--  the roles that hold PLATFORM_STAFF_MANAGE on this menu TODAY, read out of the data. Everyone
--  who could deactivate before this script can deactivate after it; the split only means the two
--  powers can DIVERGE from here on, when someone unticks one cell in the role matrix.
--
--  PLATFORM_STAFF_MANAGE is untouched and keeps every other operation. In particular the
--  lock-out guard (PlatformStaffHelper.EnsureNotLastPlatformAdminAsync → RolesGrantStaffManage-
--  Async) deliberately still keys on PLATFORM_STAFF_MANAGE: it asks "will anyone still be able to
--  ADMINISTER staff", and an operator who can only switch accounts off is not a rescuer.
--
--  DEPENDS ON:  ops-platform-rbac-seed.sql, platform-staff-rbac-seed.sql,
--               platform-tenant-access-menu-seed.sql (§4 — it is what gave PLATFORM_STAFF its
--               MenuCapabilities rows in the first place)
--  IDEMPOTENT:  yes — re-running changes nothing.
--  APPLY AS:    the DB owner, against the PSS 2.0 database.
-- =====================================================================================

BEGIN;

-- ── 0. Guards ────────────────────────────────────────────────────────────────────────
-- A NOT EXISTS-guarded INSERT whose join matches nothing inserts zero rows and reports
-- success. Fail loudly instead.
DO $$
DECLARE
  v_menu int;
  v_mng  int;
BEGIN
  SELECT COUNT(*) INTO v_menu
    FROM auth."Menus" WHERE "MenuCode" = 'PLATFORM_STAFF';
  IF v_menu = 0 THEN
    RAISE EXCEPTION 'Menu PLATFORM_STAFF not found. Apply platform-staff-rbac-seed.sql first.';
  END IF;

  SELECT COUNT(*) INTO v_mng
    FROM auth."Capabilities"
   WHERE "CapabilityCode" = 'PLATFORM_STAFF_MANAGE'
     AND COALESCE("IsDeleted", false) = false;
  IF v_mng = 0 THEN
    RAISE EXCEPTION
      'Capability PLATFORM_STAFF_MANAGE not found. Apply platform-staff-rbac-seed.sql first.';
  END IF;
END $$;

-- ── 1. Capability ────────────────────────────────────────────────────────────────────
-- Name carries the "Platform " prefix because auth."Capabilities" has a UNIQUE index on
-- (CapabilityName, IsActive) shared with the tenant capability set — an unprefixed
-- "Deactivate Staff" would collide with whatever a tenant menu names its own. The idempotency
-- guard therefore checks CapabilityName (the constrained column), NOT the code: a name clash is
-- a constraint violation that aborts the transaction, a code clash is only a duplicate.
--
-- OrderBy 105 continues the 96-104 platform block, so it sorts next to PLATFORM_STAFF_MANAGE in
-- the role matrix, where a granter will look for it.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT
  v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Platform Deactivate Staff', 'PLATFORM_STAFF_DEACTIVATE',
   'Deactivate and reactivate a platform operator''s account. Separate from Manage Staff: this is the power to switch an operator off, not to invite or edit one. Self-deactivation and deactivating the last remaining staff administrator are refused regardless.',
   105)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 2. MenuCapabilities — make it grantable through the UI ───────────────────────────
-- PlatformRoleMatrixBuilder builds its CELLS from MenuCapabilities. HasAccessAsync does not
-- consult this table at all, so without this block the capability is fully enforceable and
-- completely ungrantable: the only way to hand it out would be hand-written SQL.
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'PLATFORM_STAFF'
  AND c."CapabilityCode" = 'PLATFORM_STAFF_DEACTIVATE'
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- Same row, wrong flags: an earlier soft-deleted MenuCapabilities row would make the INSERT
-- above a no-op and still hide the cell. Narrowed to the exact wrong values, no-op once right.
UPDATE auth."MenuCapabilities" mc
   SET "IsActive" = true, "IsDeleted" = false, "ModifiedDate" = now()
  FROM auth."Menus" m, auth."Capabilities" c
 WHERE mc."MenuId" = m."MenuId"
   AND mc."CapabilityId" = c."CapabilityId"
   AND m."MenuCode" = 'PLATFORM_STAFF'
   AND c."CapabilityCode" = 'PLATFORM_STAFF_DEACTIVATE'
   AND (COALESCE(mc."IsActive", false) = false OR COALESCE(mc."IsDeleted", false) = true);

-- ── 3. Grants — derived from who holds MANAGE today, not from a role list ────────────
-- ⚠ Deliberately NOT a VALUES list of role codes. This script SPLITS an existing power; it must
--   not silently narrow it. Reading the current holders of PLATFORM_STAFF_MANAGE out of the data
--   means the split is access-neutral on the day it is applied, and it stays correct in a
--   database where someone has already re-arranged the platform role matrix by hand.
--
--   Only live grants qualify — HasAccess = true and not soft-deleted. A role whose MANAGE cell is
--   unticked does not get the new capability handed to it.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT DISTINCT
  src."RoleId", src."MenuId", newc."CapabilityId", true, now(), true, false
FROM (
  SELECT rc."RoleId", rc."MenuId"
    FROM auth."RoleCapabilities" rc
    JOIN auth."Menus"        m ON m."MenuId"       = rc."MenuId"
                             AND m."MenuCode"      = 'PLATFORM_STAFF'
    JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
                             AND c."CapabilityCode" = 'PLATFORM_STAFF_MANAGE'
   WHERE rc."HasAccess" = true
     AND COALESCE(rc."IsDeleted", false) = false
) AS src
CROSS JOIN (
  SELECT "CapabilityId" FROM auth."Capabilities"
   WHERE "CapabilityCode" = 'PLATFORM_STAFF_DEACTIVATE'
     AND COALESCE("IsDeleted", false) = false
) AS newc
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc2
  WHERE rc2."RoleId"       = src."RoleId"
    AND rc2."MenuId"       = src."MenuId"
    AND rc2."CapabilityId" = newc."CapabilityId"
);

-- ── 4. SUPERADMIN superset ───────────────────────────────────────────────────────────
-- ⚠ SEPARATE INSERT, matched by RoleCode ALONE — same reasoning as platform-staff-rbac-seed.sql
--   §6. The other platform seeds join SUPERADMIN with `AND r."CompanyId" IS NULL`; if the
--   SUPERADMIN row in this database is not CompanyId-null (PROMPT-24 §⑨ Q3, still unanswered)
--   those joins inserted nothing, which would also mean §3 above finds no MANAGE grant to copy.
--   Do not add a CompanyId predicate here.
--
--   SUPERADMIN is only ever added to, never revoked or overwritten (⚠ Rule 7).
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM auth."Roles"        r
CROSS JOIN auth."Menus"        m
CROSS JOIN auth."Capabilities" c
WHERE r."RoleCode" = 'SUPERADMIN' AND COALESCE(r."IsDeleted", false) = false
  AND m."MenuCode" = 'PLATFORM_STAFF'
  AND c."CapabilityCode" = 'PLATFORM_STAFF_DEACTIVATE'
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."RoleCapabilities" rc
    WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
  );

-- ── 5. Normalise flags on any pre-existing row ───────────────────────────────────────
-- Same failure mode platform-staff-manage-capability-repair.sql §D exists for: a row that is
-- present but HasAccess = false / IsActive NULL reads to HasAccessAsync as "no", and the NOT
-- EXISTS guards above will not correct it. Narrowed to rows that are actually wrong.
UPDATE auth."RoleCapabilities" rc
   SET "HasAccess" = true, "IsActive" = true, "IsDeleted" = false, "ModifiedDate" = now()
  FROM auth."Roles" r, auth."Menus" m, auth."Capabilities" c
 WHERE rc."RoleId"       = r."RoleId"
   AND rc."MenuId"       = m."MenuId"
   AND rc."CapabilityId" = c."CapabilityId"
   AND m."MenuCode"      = 'PLATFORM_STAFF'
   AND c."CapabilityCode" = 'PLATFORM_STAFF_DEACTIVATE'
   AND (
     r."RoleCode" = 'SUPERADMIN'
     OR EXISTS (
       SELECT 1
         FROM auth."RoleCapabilities" mng
         JOIN auth."Capabilities" mc2 ON mc2."CapabilityId" = mng."CapabilityId"
                                     AND mc2."CapabilityCode" = 'PLATFORM_STAFF_MANAGE'
        WHERE mng."RoleId"   = rc."RoleId"
          AND mng."MenuId"   = rc."MenuId"
          AND mng."HasAccess" = true
          AND COALESCE(mng."IsDeleted", false) = false
     )
   )
   AND (rc."HasAccess" IS DISTINCT FROM true
     OR rc."IsActive"  IS DISTINCT FROM true
     OR COALESCE(rc."IsDeleted", false) <> false);

-- ── 6. Report — did anyone actually end up able to deactivate? ───────────────────────
-- If §3 found no MANAGE grant to copy and §4's SUPERADMIN row is missing, this script commits
-- cleanly and the Deactivate button 403s for everybody. Say so at apply time rather than leaving
-- it to be discovered by clicking.
DO $$
DECLARE
  v_roles int;
  v_users int;
BEGIN
  SELECT COUNT(DISTINCT rc."RoleId") INTO v_roles
    FROM auth."RoleCapabilities" rc
    JOIN auth."Menus"        m ON m."MenuId"       = rc."MenuId" AND m."MenuCode" = 'PLATFORM_STAFF'
    JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
                             AND c."CapabilityCode" = 'PLATFORM_STAFF_DEACTIVATE'
   WHERE rc."HasAccess" = true
     AND COALESCE(rc."IsDeleted", false) = false
     AND COALESCE(rc."IsActive", false) = true;

  SELECT COUNT(DISTINCT ur."UserId") INTO v_users
    FROM auth."UserRoles" ur
    JOIN auth."Users" u ON u."UserId" = ur."UserId"
                       AND COALESCE(u."IsActive", false) = true
                       AND COALESCE(u."IsDeleted", false) = false
    JOIN auth."RoleCapabilities" rc ON rc."RoleId" = ur."RoleId"
    JOIN auth."Menus"        m ON m."MenuId"       = rc."MenuId" AND m."MenuCode" = 'PLATFORM_STAFF'
    JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
                             AND c."CapabilityCode" = 'PLATFORM_STAFF_DEACTIVATE'
   WHERE COALESCE(ur."IsActive", false) = true
     AND COALESCE(ur."IsDeleted", false) = false
     AND rc."HasAccess" = true
     AND COALESCE(rc."IsDeleted", false) = false
     AND COALESCE(rc."IsActive", false) = true;

  IF v_roles = 0 THEN
    RAISE WARNING
      'PLATFORM_STAFF_DEACTIVATE is granted to NO role. Deactivate/Reactivate will refuse every caller. Apply platform-staff-manage-capability-repair.sql (it fixes the PLATFORM_STAFF_MANAGE grants this script copies from) and re-run this file.';
  ELSE
    RAISE NOTICE 'PLATFORM_STAFF_DEACTIVATE granted to % role(s), reachable by % active user(s).',
      v_roles, v_users;
  END IF;

  IF v_roles > 0 AND v_users = 0 THEN
    RAISE WARNING
      'PLATFORM_STAFF_DEACTIVATE is granted, but NO active user holds a role that has it. Nobody can deactivate an operator.';
  END IF;
END $$;

COMMIT;

-- =====================================================================================
--  VERIFY (run after COMMIT)
-- =====================================================================================
--
-- 1. The capability exists exactly once and sits next to the rest of the platform block:
--
--    SELECT "CapabilityId","CapabilityCode","CapabilityName","OrderBy","IsSpecial","IsActive"
--      FROM auth."Capabilities"
--     WHERE "CapabilityCode" LIKE 'PLATFORM\_STAFF%'
--       AND COALESCE("IsDeleted", false) = false
--     ORDER BY "OrderBy";
--
-- 2. It is grantable in the platform role matrix — PLATFORM_STAFF should now report 5
--    MenuCapabilities (VIEW, MANAGE, DEACTIVATE, RBAC_TEMPLATE_EDIT, RBAC_ROLLOUT):
--
--    SELECT c."CapabilityCode", mc."IsActive", mc."IsDeleted"
--      FROM auth."MenuCapabilities" mc
--      JOIN auth."Menus"        m ON m."MenuId"       = mc."MenuId" AND m."MenuCode" = 'PLATFORM_STAFF'
--      JOIN auth."Capabilities" c ON c."CapabilityId" = mc."CapabilityId"
--     ORDER BY c."OrderBy";
--
-- 3. THE ACCESS-NEUTRALITY CHECK. Every role that holds MANAGE must also hold DEACTIVATE —
--    this must return ZERO rows. Any row is a role that lost the ability to deactivate:
--
--    SELECT r."RoleCode"
--      FROM auth."RoleCapabilities" rc
--      JOIN auth."Roles"        r ON r."RoleId"       = rc."RoleId"
--      JOIN auth."Menus"        m ON m."MenuId"       = rc."MenuId" AND m."MenuCode" = 'PLATFORM_STAFF'
--      JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--                                AND c."CapabilityCode" = 'PLATFORM_STAFF_MANAGE'
--     WHERE rc."HasAccess" = true AND COALESCE(rc."IsDeleted", false) = false
--       AND NOT EXISTS (
--         SELECT 1 FROM auth."RoleCapabilities" x
--           JOIN auth."Capabilities" xc ON xc."CapabilityId" = x."CapabilityId"
--                                      AND xc."CapabilityCode" = 'PLATFORM_STAFF_DEACTIVATE'
--          WHERE x."RoleId" = rc."RoleId" AND x."MenuId" = rc."MenuId"
--            AND x."HasAccess" = true AND COALESCE(x."IsDeleted", false) = false);
--
-- 4. Who can deactivate, and who that actually is:
--
--    SELECT r."RoleCode", u."UserName", u."Email"
--      FROM auth."RoleCapabilities" rc
--      JOIN auth."Roles"        r ON r."RoleId"       = rc."RoleId"
--      JOIN auth."Menus"        m ON m."MenuId"       = rc."MenuId" AND m."MenuCode" = 'PLATFORM_STAFF'
--      JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--                                AND c."CapabilityCode" = 'PLATFORM_STAFF_DEACTIVATE'
--      LEFT JOIN auth."UserRoles" ur ON ur."RoleId" = r."RoleId"
--                                   AND COALESCE(ur."IsActive", false) = true
--                                   AND COALESCE(ur."IsDeleted", false) = false
--      LEFT JOIN auth."Users"     u  ON u."UserId" = ur."UserId"
--                                   AND COALESCE(u."IsDeleted", false) = false
--     WHERE rc."HasAccess" = true AND COALESCE(rc."IsDeleted", false) = false
--     ORDER BY r."RoleCode", u."UserName";
-- =====================================================================================
