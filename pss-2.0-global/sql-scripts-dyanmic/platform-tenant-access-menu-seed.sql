-- =====================================================================================
--  PSS 2.0 — P-24 follow-up: TENANT ACCESS CONTROL menu
--
--  WHY THIS EXISTS
--  ---------------
--  "Staff & Access" (PLATFORM_STAFF) was carrying two unrelated things: the platform's own
--  people and roles, and a break-glass editor for a CUSTOMER's live RBAC. Those are different
--  subjects with different blast radii, and putting them behind one menu meant one grant bought
--  both. The tenant-RBAC surface has moved onto the tenant page — /ops/tenants/{companyId},
--  "Access" tab — where the rest of that customer's facts already live.
--
--  The gate had to move with it. Leaving it on PLATFORM_STAFF would re-create the mixing the
--  move removes; folding it into PLATFORM_TENANTS would make "may look at a tenant" imply "may
--  rewrite that tenant's permissions". So it gets its own menu.
--
--  IsVisible = true, and it has a route of its own: /ops/tenant-access.
--
--  The first cut of this script made it a hidden capability container on the reasoning that the
--  surface it governs is a TAB, so there was nothing to navigate to. That produced a menu leading
--  to a 404. It now has a real landing page — a tenant picker that deep-links into
--  /ops/tenants/{companyId}?tab=access. The picker deliberately does NOT duplicate the matrix:
--  one editor, one audit path.
--
--  ⚠ THE BACKEND IS ALREADY RE-GATED. GetTenantRoleMatrixQuery and OverrideTenantRoleCapability-
--    Command now demand PLATFORM_TENANT_ACCESS. Until this script is applied, nothing grants
--    those capabilities and BOTH operations will refuse every caller, including PLATFORM_ADMIN.
--
--  NOT A REVOCATION. §6 retires the old PLATFORM_STAFF-scoped override grant only AFTER §5 has
--  written the replacement on the new menu, and only for roles that received it. Every operator
--  who could override before can override after. (⚠ Rule 5 — the platform never silently revokes.)
--
--  DEPENDS ON:  ops-platform-rbac-seed.sql, platform-staff-rbac-seed.sql
--  IDEMPOTENT:  yes — re-running changes nothing.
--  APPLY AS:    the DB owner, against the PSS 2.0 database.
-- =====================================================================================

BEGIN;

-- ── 0. Guards ────────────────────────────────────────────────────────────────────────
-- Fail loudly on a missing prerequisite rather than half-applying. A NOT EXISTS-guarded
-- INSERT whose join matches nothing inserts zero rows and reports success — that silence is
-- the failure mode this block exists to prevent.
DO $$
DECLARE
  v_root       int;
  v_module     int;
  v_staff_menu int;
  v_override   int;
BEGIN
  SELECT COUNT(*) INTO v_root
    FROM auth."Menus" WHERE "MenuCode" = 'PLATFORMCONTROLPLANE';
  IF v_root = 0 THEN
    RAISE EXCEPTION 'Menu PLATFORMCONTROLPLANE not found. Apply ops-platform-rbac-seed.sql first.';
  END IF;

  SELECT COUNT(*) INTO v_module
    FROM auth."Modules" WHERE "ModuleCode" = 'PLATFORM';
  IF v_module = 0 THEN
    RAISE EXCEPTION 'Module PLATFORM not found. Apply ops-platform-rbac-seed.sql first.';
  END IF;

  SELECT COUNT(*) INTO v_staff_menu
    FROM auth."Menus" WHERE "MenuCode" = 'PLATFORM_STAFF';
  IF v_staff_menu = 0 THEN
    RAISE EXCEPTION 'Menu PLATFORM_STAFF not found. Apply platform-staff-rbac-seed.sql first.';
  END IF;

  SELECT COUNT(*) INTO v_override
    FROM auth."Capabilities"
   WHERE "CapabilityCode" = 'PLATFORM_TENANT_RBAC_OVERRIDE'
     AND COALESCE("IsDeleted", false) = false;
  IF v_override = 0 THEN
    RAISE EXCEPTION
      'Capability PLATFORM_TENANT_RBAC_OVERRIDE not found. Apply platform-staff-rbac-seed.sql first.';
  END IF;
END $$;

-- ── 1. Menu — PLATFORM_TENANT_ACCESS ─────────────────────────────────────────────────
-- Sibling of PLATFORM_STAFF (950) under the same control-plane root, OrderBy 955 so it sorts
-- next to it in the platform role matrix, where a granter will look for it.
--
-- MenuUrl is its OWN path, /ops/tenant-access — deliberately NOT /ops/tenants, which
-- PLATFORM_TENANTS already owns. MenuUrl is how the nav builder and the sidebar active-state
-- matcher identify a menu; two menus on one path make them indistinguishable, so the wrong item
-- highlights and any future url→menu lookup resolves to whichever row it reads first.
--
-- IsVisible = true, and the route exists: /ops/tenant-access renders a tenant PICKER whose rows
-- deep-link into /ops/tenants/{companyId}?tab=access. The editing surface is still the TAB — the
-- picker deliberately does not duplicate the matrix, so there stays exactly one editor and one
-- audit path.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Tenant Access Control', 'PLATFORM_TENANT_ACCESS',
  (SELECT p."MenuId" FROM auth."Menus" p WHERE p."MenuCode" = 'PLATFORMCONTROLPLANE'),
  'ph-shield-check',
  (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'PLATFORM'),
  '/ops/tenant-access',
  'Read and break-glass edit of a live tenant''s own role/capability matrix. Landing page picks the tenant; editing happens on the Access tab of the tenant page.',
  955,
  true, 'Internal', true, now(), true, false
WHERE NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = 'PLATFORM_TENANT_ACCESS');

-- Repair for an EARLIER RUN of this script, which seeded this menu on '/ops/tenants' — the same
-- path PLATFORM_TENANTS owns. The INSERT above is NOT EXISTS-guarded on MenuCode, so it will not
-- correct a row that already exists; this will. Narrowed to the exact wrong value so it can never
-- clobber a URL someone set on purpose, and a no-op once the value is right (idempotent).
UPDATE auth."Menus"
   SET "MenuUrl" = '/ops/tenant-access',
       "ModifiedDate" = now()
 WHERE "MenuCode" = 'PLATFORM_TENANT_ACCESS'
   AND "MenuUrl"  = '/ops/tenants';

-- Same reason, second value: an earlier run seeded this menu hidden, because at that point it had
-- no page to open. It has one now, so flip it visible. Guarded on the wrong value so it is a no-op
-- on re-run and never re-shows a menu an admin hid on purpose... except that admin-hiding is not a
-- thing on this menu yet, and a hidden row here is only ever the old default.
UPDATE auth."Menus"
   SET "IsVisible" = true,
       "ModifiedDate" = now()
 WHERE "MenuCode" = 'PLATFORM_TENANT_ACCESS'
   AND COALESCE("IsVisible", false) = false;

-- ── 2. Capability — one new, read side ───────────────────────────────────────────────
-- Only the READ capability is new. The write capability, PLATFORM_TENANT_RBAC_OVERRIDE, already
-- exists from platform-staff-rbac-seed.sql §4 and is REUSED — auth."Capabilities" has a UNIQUE
-- index on (CapabilityName, IsActive), and a second row for the same authority would be both a
-- constraint fight and a lie about how many distinct powers exist.
--
-- Name carries the "Platform " prefix for the same UNIQUE index; the guard checks CapabilityName
-- (the constrained column), not the code. OrderBy 104 continues the 96-103 block.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT
  v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Platform View Tenant Access', 'PLATFORM_TENANT_ACCESS_VIEW',
   'Read a live tenant''s role/capability matrix from the tenant page. Read-only; editing needs the override capability.', 104)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 3. MenuCapabilities — wire both capabilities to the new menu ─────────────────────
-- PlatformRoleMatrixBuilder builds its ROWS from menus that have ≥1 MenuCapability (it skips
-- any menu whose capability list is empty). Without this block the new menu exists but is
-- invisible to the platform role matrix, so nobody could ever grant it through the UI.
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'PLATFORM_TENANT_ACCESS'
  AND c."CapabilityCode" IN ('PLATFORM_TENANT_ACCESS_VIEW','PLATFORM_TENANT_RBAC_OVERRIDE')
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- ── 4. Backfill — PLATFORM_STAFF's own four capabilities ─────────────────────────────
-- platform-staff-rbac-seed.sql wrote RoleCapabilities directly and never wrote MenuCapabilities
-- (the authorization check does not need them). The consequence is that "Staff & Access" has
-- never appeared as a ROW in the platform role matrix — the four staff/RBAC-template
-- capabilities can be enforced but not granted through the UI.
--
-- This fixes that, and it is the moment to fix it: the same screen is now the only place the
-- platform's own access is administered. PLATFORM_TENANT_RBAC_OVERRIDE is deliberately absent
-- from this list — it belongs to the new menu now, and §6 retires it from this one.
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'PLATFORM_STAFF'
  AND c."CapabilityCode" IN ('PLATFORM_STAFF_VIEW','PLATFORM_STAFF_MANAGE',
                             'PLATFORM_RBAC_TEMPLATE_EDIT','PLATFORM_RBAC_ROLLOUT')
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- ── 5. Grants — the replacement, written BEFORE anything is retired ──────────────────
-- VIEW goes to the roles that already read tenants: ADMIN, SUPPORT, IMPLEMENTATION. Reading a
-- customer's permission grid is how a support call gets answered, and a read leaves the customer's
-- access exactly as it was.
--
-- PLATFORM_TENANT_RBAC_OVERRIDE goes to PLATFORM_ADMIN ONLY — unchanged from
-- platform-staff-rbac-seed.sql §5. This script MOVES that authority to a different menu; it does
-- not widen it. FINANCE and SALES get nothing here.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_ADMIN',          'PLATFORM_TENANT_ACCESS_VIEW'),
  ('PLATFORM_ADMIN',          'PLATFORM_TENANT_RBAC_OVERRIDE'),
  ('PLATFORM_SUPPORT',        'PLATFORM_TENANT_ACCESS_VIEW'),
  ('PLATFORM_IMPLEMENTATION', 'PLATFORM_TENANT_ACCESS_VIEW')
) AS v(role_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
                          AND COALESCE(r."IsDeleted", false) = false
JOIN auth."Menus"        m ON m."MenuCode" = 'PLATFORM_TENANT_ACCESS'
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
                          AND COALESCE(c."IsDeleted", false) = false
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- ── 5b. SUPERADMIN superset ──────────────────────────────────────────────────────────
-- ⚠ SEPARATE INSERT, matching SUPERADMIN by RoleCode ALONE — same reasoning as
--   platform-staff-rbac-seed.sql §6. ops-platform-rbac-seed.sql joins SUPERADMIN with
--   `AND r."CompanyId" IS NULL`; if the SUPERADMIN row in this database is not CompanyId-null,
--   that join silently inserted nothing. Do not add a CompanyId predicate here.
--
--   SUPERADMIN is never revoked and never overwritten (⚠ Rule 7); it is only ever added to.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_TENANT_ACCESS_VIEW'),
  ('PLATFORM_TENANT_RBAC_OVERRIDE')
) AS v(cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = 'SUPERADMIN' AND COALESCE(r."IsDeleted", false) = false
JOIN auth."Menus"        m ON m."MenuCode" = 'PLATFORM_TENANT_ACCESS'
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
                          AND COALESCE(c."IsDeleted", false) = false
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- ── 5c. SUPERADMIN backfill across EVERY platform menu ───────────────────────────────
-- §5b covers the two capabilities this script introduces. This block covers the ones it does
-- NOT, and it exists because SUPERADMIN can currently be missing the platform almost entirely.
--
-- Two independent causes, both silent:
--
--   (a) ops-platform-rbac-seed.sql §5 joins EVERY grant — SUPERADMIN's included — with
--       `AND r."CompanyId" IS NULL`. If the SUPERADMIN row in this database is not CompanyId-null
--       (PROMPT-24 §⑨ Q3, still unanswered), all ten of its grants there inserted ZERO rows and
--       reported success. That takes PLATFORM_TENANT_VIEW with it — the capability that opens
--       /ops/tenants at all, and therefore every tab on the tenant page.
--   (b) That script predates PLATFORM_PLANS' read capability, PLATFORM_BILLING, the comms and
--       webhook menus, and PLATFORM_STAFF. Nothing ever granted SUPERADMIN any of them, whatever
--       its CompanyId is. The tenant page's Features / Usage / Payments tabs sit behind exactly
--       those.
--
-- The definition used here is "SUPERADMIN holds the UNION of what the platform roles hold" —
-- derived from the data rather than from a hand-kept list, so it stays correct as menus are added
-- and it cannot re-introduce the CompanyId assumption. Matched by RoleCode ALONE, additive, and
-- NOT EXISTS-guarded: nothing is revoked or overwritten (⚠ Rule 7 holds — that rule forbids
-- taking authority away from SUPERADMIN, not giving it).
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT DISTINCT
  sa."RoleId", src."MenuId", src."CapabilityId", true, now(), true, false
FROM (
  -- (i) everything any PLATFORM_* role can already reach …
  SELECT rc."MenuId", rc."CapabilityId"
    FROM auth."RoleCapabilities" rc
    JOIN auth."Roles" pr ON pr."RoleId" = rc."RoleId"
   WHERE pr."RoleCode" LIKE 'PLATFORM\_%'
     AND COALESCE(pr."IsDeleted", false) = false
     AND rc."HasAccess" = true
     AND COALESCE(rc."IsDeleted", false) = false
  UNION
  -- (ii) … plus every capability wired to a menu in the PLATFORM module, which catches a menu
  --      that exists and is wired but that no platform role happens to hold yet.
  SELECT mc."MenuId", mc."CapabilityId"
    FROM auth."MenuCapabilities" mc
    JOIN auth."Menus"   m  ON m."MenuId"   = mc."MenuId"
    JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'PLATFORM'
   WHERE COALESCE(mc."IsDeleted", false) = false
     AND COALESCE(m."IsDeleted",  false) = false
) AS src
CROSS JOIN (
  SELECT "RoleId" FROM auth."Roles"
   WHERE "RoleCode" = 'SUPERADMIN' AND COALESCE("IsDeleted", false) = false
) AS sa
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc2
  WHERE rc2."RoleId"       = sa."RoleId"
    AND rc2."MenuId"       = src."MenuId"
    AND rc2."CapabilityId" = src."CapabilityId"
);

-- ── 6. Retire the old PLATFORM_STAFF-scoped override grant ───────────────────────────
-- The cell it represents no longer has a surface: the backend now demands
-- PLATFORM_TENANT_ACCESS, so a PLATFORM_STAFF-scoped override grant authorises nothing. Leaving
-- it would leave a dead switch in the platform role matrix that reads as if it still confers
-- break-glass power.
--
-- The correlated EXISTS is the safety catch: a role's old grant is retired ONLY once the same
-- role holds the replacement on the new menu (written in §5/§5b above, same transaction). A role
-- that somehow missed the replacement keeps what it had. Nobody loses authority in this file.
--
-- Soft delete, not DELETE — the row is history, and BulkUpdatePlatformRoleMatrix will happily
-- re-create it if a human ever ticks it again.
UPDATE auth."RoleCapabilities" rc
   SET "IsDeleted"    = true,
       "IsActive"     = false,
       "ModifiedDate" = now()
  FROM auth."Menus" m, auth."Capabilities" c
 WHERE rc."MenuId"       = m."MenuId"
   AND rc."CapabilityId" = c."CapabilityId"
   AND m."MenuCode"      = 'PLATFORM_STAFF'
   AND c."CapabilityCode" = 'PLATFORM_TENANT_RBAC_OVERRIDE'
   AND COALESCE(rc."IsDeleted", false) = false
   AND EXISTS (
     SELECT 1
       FROM auth."RoleCapabilities" repl
       JOIN auth."Menus" nm ON nm."MenuId" = repl."MenuId" AND nm."MenuCode" = 'PLATFORM_TENANT_ACCESS'
      WHERE repl."RoleId"       = rc."RoleId"
        AND repl."CapabilityId" = c."CapabilityId"
        AND repl."HasAccess"    = true
        AND COALESCE(repl."IsDeleted", false) = false
   );

COMMIT;

-- =====================================================================================
--  VERIFY (run after COMMIT)
-- =====================================================================================
--
-- 1. The menu exists, is VISIBLE (it has a landing page now), and does NOT share
--    PLATFORM_TENANTS' path — expect /ops/tenants vs /ops/tenant-access, never both the same:
--
--    SELECT "MenuId","MenuCode","MenuName","MenuUrl","OrderBy","IsVisible","IsActive"
--      FROM auth."Menus" WHERE "MenuCode" IN ('PLATFORM_STAFF','PLATFORM_TENANT_ACCESS')
--     ORDER BY "OrderBy";
--
-- 2. Both menus now carry MenuCapabilities, so both appear as rows in the platform role
--    matrix. Expect 4 for PLATFORM_STAFF and 2 for PLATFORM_TENANT_ACCESS:
--
--    SELECT m."MenuCode", COUNT(*) AS caps
--      FROM auth."MenuCapabilities" mc
--      JOIN auth."Menus" m ON m."MenuId" = mc."MenuId"
--     WHERE m."MenuCode" IN ('PLATFORM_STAFF','PLATFORM_TENANT_ACCESS')
--       AND COALESCE(mc."IsDeleted", false) = false
--     GROUP BY m."MenuCode";
--
-- 3. Who can now read / override a tenant's matrix. Expect PLATFORM_ADMIN and SUPERADMIN with
--    both, PLATFORM_SUPPORT and PLATFORM_IMPLEMENTATION with VIEW only:
--
--    SELECT r."RoleCode", c."CapabilityCode", rc."HasAccess"
--      FROM auth."RoleCapabilities" rc
--      JOIN auth."Roles"        r ON r."RoleId"       = rc."RoleId"
--      JOIN auth."Menus"        m ON m."MenuId"       = rc."MenuId"
--      JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--     WHERE m."MenuCode" = 'PLATFORM_TENANT_ACCESS'
--       AND COALESCE(rc."IsDeleted", false) = false
--     ORDER BY r."RoleCode", c."CapabilityCode";
--
-- 4. Nobody was left behind by §6 — this must return ZERO rows. Any row here is a role whose
--    old override grant was retired without a replacement, which would be a real revocation:
--
--    SELECT r."RoleCode"
--      FROM auth."RoleCapabilities" rc
--      JOIN auth."Roles"        r  ON r."RoleId"       = rc."RoleId"
--      JOIN auth."Menus"        m  ON m."MenuId"       = rc."MenuId" AND m."MenuCode" = 'PLATFORM_STAFF'
--      JOIN auth."Capabilities" c  ON c."CapabilityId" = rc."CapabilityId"
--                                 AND c."CapabilityCode" = 'PLATFORM_TENANT_RBAC_OVERRIDE'
--     WHERE rc."IsDeleted" = true
--       AND NOT EXISTS (
--         SELECT 1 FROM auth."RoleCapabilities" x
--           JOIN auth."Menus" nm ON nm."MenuId" = x."MenuId" AND nm."MenuCode" = 'PLATFORM_TENANT_ACCESS'
--          WHERE x."RoleId" = rc."RoleId" AND x."CapabilityId" = rc."CapabilityId"
--            AND x."HasAccess" = true AND COALESCE(x."IsDeleted", false) = false);
--
-- 5. STILL OPEN — PROMPT-24 §⑨ Q3. Please run and send me the result; it decides whether the
--    earlier SUPERADMIN grants in ops-platform-rbac-seed.sql landed at all:
--
--    SELECT "RoleId","RoleCode","CompanyId","IsSystem","IsAssignable"
--      FROM auth."Roles"
--     WHERE "RoleCode" = 'SUPERADMIN' AND COALESCE("IsDeleted", false) = false;
--
-- 6. §5c landed — SUPERADMIN now reaches every platform menu. Expect one row per PLATFORM
--    menu, and every menu that appears for any PLATFORM_* role must also appear here:
--
--    SELECT m."MenuCode", COUNT(*) AS caps
--      FROM auth."RoleCapabilities" rc
--      JOIN auth."Roles" r ON r."RoleId" = rc."RoleId" AND r."RoleCode" = 'SUPERADMIN'
--      JOIN auth."Menus" m ON m."MenuId" = rc."MenuId"
--      JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'PLATFORM'
--     WHERE rc."HasAccess" = true AND COALESCE(rc."IsDeleted", false) = false
--     GROUP BY m."MenuCode" ORDER BY m."MenuCode";
--
-- 7. The gap §5c closes — this must return ZERO rows after the run. Each row is a platform
--    capability some PLATFORM_* role holds but SUPERADMIN does not:
--
--    SELECT DISTINCT m."MenuCode", c."CapabilityCode"
--      FROM auth."RoleCapabilities" rc
--      JOIN auth."Roles"        pr ON pr."RoleId"       = rc."RoleId"
--                                 AND pr."RoleCode" LIKE 'PLATFORM\_%'
--      JOIN auth."Menus"        m  ON m."MenuId"        = rc."MenuId"
--      JOIN auth."Capabilities" c  ON c."CapabilityId"  = rc."CapabilityId"
--     WHERE rc."HasAccess" = true AND COALESCE(rc."IsDeleted", false) = false
--       AND NOT EXISTS (
--         SELECT 1 FROM auth."RoleCapabilities" x
--           JOIN auth."Roles" sa ON sa."RoleId" = x."RoleId" AND sa."RoleCode" = 'SUPERADMIN'
--          WHERE x."MenuId" = rc."MenuId" AND x."CapabilityId" = rc."CapabilityId"
--            AND x."HasAccess" = true AND COALESCE(x."IsDeleted", false) = false)
--     ORDER BY 1, 2;
-- =====================================================================================
