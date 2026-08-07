-- =====================================================================================
-- PROMPT-24 T-A26 — Platform Staff & RBAC administration seed
-- -------------------------------------------------------------------------------------
-- Companion to ops-platform-rbac-seed.sql. Adds the RBAC surface for the new
-- (master)/platform/staff screen, and closes two live leaks (D1 / D2 in PROMPT-24 §⓪).
--
--   1. auth."Roles"           — flag the 5 PLATFORM_* roles with the NEW IsPlatform column
--   2. auth."Roles"           — IsAssignable = false on those same roles (defence in depth)
--   3. auth."Menus"           — 1 new leaf menu: PLATFORM_STAFF -> /platform/staff
--   4. auth."Capabilities"    — 5 new capabilities (IsSpecial = true)
--   5. auth."RoleCapabilities"— grants for PLATFORM_ADMIN / SUPPORT / IMPLEMENTATION
--   6. auth."RoleCapabilities"— SUPERADMIN superset (separate insert — see the note on §6)
--
-- ⚠ PREREQUISITE — the migration Add_PlatformStaffRbacAdmin MUST be applied first.
--    It creates auth."Roles"."IsPlatform". Steps 1 and 2 below fail with
--    `column "IsPlatform" does not exist` if you run this script before the migration.
--    Full DDL: PSS-2.0-ONBOARDING-PROMPT-24-MIGRATION-SPEC.md
--
-- ⚠ PREREQUISITE — ops-platform-rbac-seed.sql must already be applied. This script does
--    NOT create the PLATFORM module, the PLATFORMCONTROLPLANE root menu, or the 5 roles;
--    it resolves all of them by code and raises if they are missing.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on the natural code key; the two
-- UPDATEs are set-to-a-constant and therefore re-runnable. Re-running is a no-op.
-- SAFE: additive, apart from the two deliberate UPDATEs in §1/§2 which are the point of
-- the script. No DROP, no DELETE, no schema change.
--
-- RESTART THE API after applying — menu and capability caches are process-scoped.
-- =====================================================================================

BEGIN;

-- ── 0. Guards — fail loudly rather than half-seeding ─────────────────────────────────
DO $$
DECLARE
  v_role_count int;
  v_root_menu  int;
BEGIN
  SELECT count(*) INTO v_role_count
  FROM auth."Roles"
  WHERE "CompanyId" IS NULL
    AND COALESCE("IsDeleted", false) = false
    AND "RoleCode" IN ('PLATFORM_SALES','PLATFORM_IMPLEMENTATION','PLATFORM_SUPPORT',
                       'PLATFORM_FINANCE','PLATFORM_ADMIN');

  IF v_role_count <> 5 THEN
    RAISE EXCEPTION
      'Expected 5 global PLATFORM_* roles, found %. Apply ops-platform-rbac-seed.sql first.',
      v_role_count;
  END IF;

  SELECT count(*) INTO v_root_menu
  FROM auth."Menus" WHERE "MenuCode" = 'PLATFORMCONTROLPLANE';

  IF v_root_menu = 0 THEN
    RAISE EXCEPTION
      'Menu PLATFORMCONTROLPLANE not found. Apply ops-platform-rbac-seed.sql first.';
  END IF;
END $$;

-- ── 1. Flag the platform roles ───────────────────────────────────────────────────────
-- THIS IS THE FIX FOR D1 AND D2.
--
-- Why a dedicated column and not IsSystem: SYSTEMROLE and SUPERADMIN are also
-- IsSystem = true and MUST stay visible on tenant surfaces. IsSystem therefore cannot
-- tell "platform-owned role" apart from "product-owned role", which is exactly why
-- GetRoleCapabilityMatrix (`r.CompanyId == tenantId || r.IsSystem == true`) currently
-- renders Platform Sales / Platform Admin as editable columns on every tenant's
-- role-capability screen, and why GrantCapabilityToAllRoles writes tenant grants onto
-- PLATFORM_ADMIN.
--
-- SUPERADMIN is deliberately NOT flagged — it stays a visible read-only column inside
-- tenant matrices, exactly as it is today.
UPDATE auth."Roles"
   SET "IsPlatform"   = true,
       "ModifiedDate" = now()
 WHERE "CompanyId" IS NULL
   AND COALESCE("IsDeleted", false) = false
   AND "RoleCode" IN ('PLATFORM_SALES','PLATFORM_IMPLEMENTATION','PLATFORM_SUPPORT',
                      'PLATFORM_FINANCE','PLATFORM_ADMIN')
   AND "IsPlatform" IS DISTINCT FROM true;

-- ── 2. Make them un-assignable inside tenants ────────────────────────────────────────
-- ops-platform-rbac-seed.sql §4 seeded these IsAssignable = true. GetRoles filters on
-- IsAssignable with NO CompanyId predicate, so they appear in tenant role pickers today.
-- Assigning one produces a user holding both a platform role and a tenant role — which
-- the P-19 §12.8 host gate rejects on BOTH host kinds, i.e. the user is locked out of the
-- product entirely, with no error surfaced anywhere.
--
-- IsPlatform (§1) is the real fix; this closes the same hole for any code path that still
-- reads only IsAssignable. This is the same reason SYSTEMROLE is seeded IsAssignable=false.
--
-- The platform's OWN role picker (screen tab 1) queries by IsPlatform, never IsAssignable,
-- so this does not hide the roles from the people who need them.
UPDATE auth."Roles"
   SET "IsAssignable" = false,
       "ModifiedDate" = now()
 WHERE "IsPlatform" = true
   AND "IsAssignable" = true;

-- ── 3. Menu — PLATFORM_STAFF leaf under the control-plane root ───────────────────────
-- MenuUrl matches the FE route (master)/platform/staff/page.tsx. OrderBy 950 sits after
-- PLATFORM_AUDIT (940). ParentMenuId + ModuleId resolved from codes, never hardcoded.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Staff & Access', 'PLATFORM_STAFF',
  (SELECT p."MenuId" FROM auth."Menus" p WHERE p."MenuCode" = 'PLATFORMCONTROLPLANE'),
  'ph-users-three',
  (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'PLATFORM'),
  '/platform/staff', 'Platform staff accounts, platform roles, tenant role template & capability rollout.', 950,
  true, 'Internal', true, now(), true, false
WHERE NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = 'PLATFORM_STAFF');

-- ── 4. Capabilities — 5 new, IsSpecial = true ────────────────────────────────────────
-- NAMES are prefixed "Platform " because auth."Capabilities" has a UNIQUE index on
-- (CapabilityName, IsActive) — bare names collide with base-app capabilities. The
-- idempotency guard therefore checks CapabilityName (the constrained column), not the code.
-- OrderBy 96-100 continues the 86-95 block seeded by ops-platform-rbac-seed.sql.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT
  v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Platform View Staff',        'PLATFORM_STAFF_VIEW',
   'See platform staff accounts and their platform roles.', 96),
  ('Platform Manage Staff',      'PLATFORM_STAFF_MANAGE',
   'Invite, edit, deactivate and unlock platform staff.', 97),
  ('Platform Edit RBAC Template','PLATFORM_RBAC_TEMPLATE_EDIT',
   'Edit the platform role matrix and the per-plan role baselines (what a tenant on a plan is born with).', 98),
  ('Platform RBAC Rollout',      'PLATFORM_RBAC_ROLLOUT',
   'Grant a capability additively across existing tenants.', 99),
  ('Platform Override Tenant RBAC','PLATFORM_TENANT_RBAC_OVERRIDE',
   'Break-glass: change one capability cell inside a live tenant (audited, reason required).', 100)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 5. Grants to the PLATFORM_* roles ────────────────────────────────────────────────
-- PLATFORM_ADMIN gets all five. SUPPORT and IMPLEMENTATION get VIEW only — they need to
-- see who is on the team, not to change access. FINANCE and SALES get nothing here.
--
-- PLATFORM_TENANT_RBAC_OVERRIDE goes to PLATFORM_ADMIN ONLY. It is the single path by
-- which we may write into a customer's own access control; support does not get it.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_ADMIN',          'PLATFORM_STAFF', 'PLATFORM_STAFF_VIEW'),
  ('PLATFORM_ADMIN',          'PLATFORM_STAFF', 'PLATFORM_STAFF_MANAGE'),
  ('PLATFORM_ADMIN',          'PLATFORM_STAFF', 'PLATFORM_RBAC_TEMPLATE_EDIT'),
  ('PLATFORM_ADMIN',          'PLATFORM_STAFF', 'PLATFORM_RBAC_ROLLOUT'),
  ('PLATFORM_ADMIN',          'PLATFORM_STAFF', 'PLATFORM_TENANT_RBAC_OVERRIDE'),
  ('PLATFORM_SUPPORT',        'PLATFORM_STAFF', 'PLATFORM_STAFF_VIEW'),
  ('PLATFORM_IMPLEMENTATION', 'PLATFORM_STAFF', 'PLATFORM_STAFF_VIEW')
) AS v(role_code, menu_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
JOIN auth."Menus"        m ON m."MenuCode" = v.menu_code
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- ── 6. SUPERADMIN superset ───────────────────────────────────────────────────────────
-- ⚠ SEPARATE INSERT ON PURPOSE. ops-platform-rbac-seed.sql §5 joins SUPERADMIN with
--   `AND r."CompanyId" IS NULL`. If the SUPERADMIN row is NOT CompanyId-null in this
--   database, all 20 of that script's SUPERADMIN grants inserted ZERO rows and SUPERADMIN
--   holds no platform capability at all today — silently, because a join that matches
--   nothing is not an error. See PROMPT-24 §⑨ Q3.
--
--   This block therefore matches SUPERADMIN by RoleCode alone. Run the verification query
--   at the foot of this file and tell me the result; if the older script did no-op, the
--   fix for it is a separate one-line re-run, not an edit to this file.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_STAFF', 'PLATFORM_STAFF_VIEW'),
  ('PLATFORM_STAFF', 'PLATFORM_STAFF_MANAGE'),
  ('PLATFORM_STAFF', 'PLATFORM_RBAC_TEMPLATE_EDIT'),
  ('PLATFORM_STAFF', 'PLATFORM_RBAC_ROLLOUT'),
  ('PLATFORM_STAFF', 'PLATFORM_TENANT_RBAC_OVERRIDE')
) AS v(menu_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = 'SUPERADMIN' AND COALESCE(r."IsDeleted", false) = false
JOIN auth."Menus"        m ON m."MenuCode" = v.menu_code
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--
--   -- 1. The five platform roles are flagged and un-assignable (expect exactly 5 rows,
--   --    all CompanyId NULL, IsPlatform true, IsAssignable false):
--   SELECT "RoleCode","CompanyId","IsSystem","IsPlatform","IsAssignable"
--     FROM auth."Roles" WHERE "IsPlatform" = true ORDER BY "OrderBy";
--
--   -- 2. Nothing else got flagged (expect 0):
--   SELECT count(*) AS wrongly_flagged FROM auth."Roles"
--    WHERE "IsPlatform" = true AND "CompanyId" IS NOT NULL;
--
--   -- 3. New menu + capabilities (expect 1 and 5):
--   SELECT (SELECT count(*) FROM auth."Menus"        WHERE "MenuCode" = 'PLATFORM_STAFF')      AS menu,
--          (SELECT count(*) FROM auth."Capabilities" WHERE "CapabilityCode" IN
--             ('PLATFORM_STAFF_VIEW','PLATFORM_STAFF_MANAGE','PLATFORM_RBAC_TEMPLATE_EDIT',
--              'PLATFORM_RBAC_ROLLOUT','PLATFORM_TENANT_RBAC_OVERRIDE'))                        AS capabilities;
--
--   -- 4. Who can override a tenant's RBAC?  expect PLATFORM_ADMIN and SUPERADMIN only:
--   SELECT r."RoleCode" FROM auth."RoleCapabilities" rc
--     JOIN auth."Roles" r        ON r."RoleId" = rc."RoleId"
--     JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--    WHERE c."CapabilityCode" = 'PLATFORM_TENANT_RBAC_OVERRIDE' AND rc."HasAccess";
--
--   -- 5. PROMPT-24 §⑨ Q3 — is SUPERADMIN CompanyId-null?  If CompanyId is NOT NULL, the
--   --    20 SUPERADMIN grants in ops-platform-rbac-seed.sql §5 never landed:
--   SELECT "RoleId","RoleCode","CompanyId","IsSystem","IsAssignable"
--     FROM auth."Roles" WHERE "RoleCode" = 'SUPERADMIN' AND COALESCE("IsDeleted",false) = false;
--
--   -- 5b. …and the direct check (expect 10 if that script worked, 0 if it silently no-opped):
--   SELECT count(*) AS superadmin_platform_grants
--     FROM auth."RoleCapabilities" rc
--     JOIN auth."Roles" r        ON r."RoleId" = rc."RoleId"
--     JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--    WHERE r."RoleCode" = 'SUPERADMIN' AND c."CapabilityCode" LIKE 'PLATFORM_%'
--      AND c."CapabilityCode" NOT IN ('PLATFORM_STAFF_VIEW','PLATFORM_STAFF_MANAGE',
--          'PLATFORM_RBAC_TEMPLATE_EDIT','PLATFORM_RBAC_ROLLOUT','PLATFORM_TENANT_RBAC_OVERRIDE');
--
--   -- 6. D2 regression check — no tenant user holds a platform role (expect 0 rows):
--   SELECT u."UserId", u."UserName", r."RoleCode"
--     FROM auth."UserRoles" ur
--     JOIN auth."Users" u ON u."UserId" = ur."UserId"
--     JOIN auth."Roles" r ON r."RoleId" = ur."RoleId"
--    WHERE r."IsPlatform" = true AND u."CompanyId" IS NOT NULL
--      AND COALESCE(ur."IsDeleted",false) = false;
-- =====================================================================================
