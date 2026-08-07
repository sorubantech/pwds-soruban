-- =====================================================================================
-- PROMPT-24 — PLATFORM_STAFF_MANAGE grant repair + verification
-- -------------------------------------------------------------------------------------
-- WHY THIS EXISTS
--
-- The platform-staff lock-out guard (PlatformStaffHelper.CountActivePlatformAdminsAsync /
-- RolesGrantStaffManageAsync) no longer asks "is this role called PLATFORM_ADMIN". It asks
-- RBAC: "does anyone still hold a LIVE grant of PLATFORM_STAFF_MANAGE on menu
-- PLATFORM_STAFF, through a platform-global role, on a live account?"
--
-- That makes the guard exactly as good as the grant rows. Three ways it silently reads 0:
--
--   A. platform-staff-rbac-seed.sql §4/§5/§6 were never applied  -> no rows at all.
--   B. A grant row exists but with "IsActive" NULL (older inserts that omitted the column
--      let it default, and some paths write NULL). The guard tests IsActive = true, so a
--      NULL row does NOT count. auth."RoleCapabilities" rows written by the tenant matrix
--      screen are the usual source.
--   C. SUPERADMIN's auth."Roles" row is NOT CompanyId-null (PROMPT-24 §⑨ Q3, still open).
--      §6 of the main seed matches SUPERADMIN by RoleCode alone, so the grant row lands —
--      but the guard only counts roles with "CompanyId" IS NULL, because a company-scoped
--      role is not authority over the control plane. In that case SUPERADMIN holds the
--      capability and still does not count. §D below REPORTS this; it does not change
--      SUPERADMIN's CompanyId, which is not a decision a seed script should make.
--
-- Symptom of a 0 count: the LAST_PLATFORM_ADMIN refusal stops firing entirely and the last
-- operator who can administer staff becomes deactivatable. Symptom of a partial count: the
-- refusal fires against someone who plainly is not the last admin.
--
-- SAFE / IDEMPOTENT: inserts are NOT EXISTS-guarded; the one UPDATE is set-to-constant and
-- scoped to the five PLATFORM_* capabilities on the PLATFORM_STAFF menu. No DELETE, no DDL.
-- Re-running is a no-op.
--
-- PREREQUISITES: ops-platform-rbac-seed.sql and platform-staff-rbac-seed.sql. This script
-- is a superset of that file's §4/§5/§6 and can be run on its own if you are unsure whether
-- they landed — EXCEPT that it does not create the PLATFORM_STAFF menu (§3 there does,
-- because it needs the PLATFORMCONTROLPLANE parent). It raises if the menu is missing.
--
-- RESTART THE API after applying — capability lookups are cached per process.
-- =====================================================================================

BEGIN;

-- ── 0. Guard — the menu must exist, everything below hangs off it ────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth."Menus" WHERE "MenuCode" = 'PLATFORM_STAFF') THEN
    RAISE EXCEPTION
      'Menu PLATFORM_STAFF not found. Apply platform-staff-rbac-seed.sql (§3) first — it '
      'resolves the PLATFORMCONTROLPLANE parent that this script deliberately does not.';
  END IF;
END $$;

-- ── A. Capabilities — the five PLATFORM_* rows ───────────────────────────────────────
-- Idempotency is on "CapabilityName", not the code: auth."Capabilities" has a UNIQUE index
-- on (CapabilityName, IsActive), so the name is the column that can actually collide.
-- Identical to platform-staff-rbac-seed.sql §4; repeated here so this script stands alone.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Platform View Staff',          'PLATFORM_STAFF_VIEW',
   'See platform staff accounts and their platform roles.', 96),
  ('Platform Manage Staff',        'PLATFORM_STAFF_MANAGE',
   'Invite, edit, deactivate and unlock platform staff.', 97),
  ('Platform Edit RBAC Template',  'PLATFORM_RBAC_TEMPLATE_EDIT',
   'Edit the platform role matrix and the per-plan role baselines.', 98),
  ('Platform RBAC Rollout',        'PLATFORM_RBAC_ROLLOUT',
   'Grant a capability additively across existing tenants.', 99),
  ('Platform Override Tenant RBAC','PLATFORM_TENANT_RBAC_OVERRIDE',
   'Break-glass: change one capability cell inside a live tenant (audited, reason required).', 100)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── B. Grants to the platform-global PLATFORM_* roles ────────────────────────────────
-- PLATFORM_ADMIN gets all five — it is the role the guard expects to find holders in.
-- SUPPORT / IMPLEMENTATION get VIEW only: they need to see the team, not change access.
-- Note what this means under the new guard: granting PLATFORM_STAFF_MANAGE to any further
-- platform role (from the role-matrix screen or by adding a row here) immediately makes its
-- holders count as rescuers. That is the intent — authority follows the capability.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
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
                          AND COALESCE(r."IsDeleted", false) = false
JOIN auth."Menus"        m ON m."MenuCode" = v.menu_code
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- ── C. SUPERADMIN superset ───────────────────────────────────────────────────────────
-- Matched by RoleCode alone, deliberately — see the §6 note in platform-staff-rbac-seed.sql
-- and §D below for what happens if this role is not CompanyId-null.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
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

-- ── D. Repair rows the guard cannot see (cause B above) ──────────────────────────────
-- A pre-existing row with "IsActive" NULL, "IsDeleted" true, or "HasAccess" false is
-- invisible to BOTH the guard and CustomAuthorizeService.HasAccessAsync — the endpoint
-- would 403 before the guard ever ran. This normalises them.
--
-- SCOPE IS NARROW ON PURPOSE: only the five PLATFORM_* capabilities, only on the
-- PLATFORM_STAFF menu, only for the roles §B/§C grant them to. It cannot resurrect a
-- capability an operator deliberately revoked from some other role, and it cannot touch a
-- single tenant row. If you have deliberately revoked one of these five from
-- PLATFORM_SUPPORT/PLATFORM_IMPLEMENTATION, delete that role_code from the list first.
UPDATE auth."RoleCapabilities" rc
   SET "HasAccess"    = true,
       "IsActive"     = true,
       "IsDeleted"    = false,
       "ModifiedDate" = now()
  FROM auth."Roles" r, auth."Menus" m, auth."Capabilities" c
 WHERE rc."RoleId"       = r."RoleId"
   AND rc."MenuId"       = m."MenuId"
   AND rc."CapabilityId" = c."CapabilityId"
   AND m."MenuCode"      = 'PLATFORM_STAFF'
   AND (
        (r."RoleCode" = 'PLATFORM_ADMIN' AND r."CompanyId" IS NULL
         AND c."CapabilityCode" IN ('PLATFORM_STAFF_VIEW','PLATFORM_STAFF_MANAGE',
             'PLATFORM_RBAC_TEMPLATE_EDIT','PLATFORM_RBAC_ROLLOUT','PLATFORM_TENANT_RBAC_OVERRIDE'))
     OR (r."RoleCode" IN ('PLATFORM_SUPPORT','PLATFORM_IMPLEMENTATION') AND r."CompanyId" IS NULL
         AND c."CapabilityCode" = 'PLATFORM_STAFF_VIEW')
     OR (r."RoleCode" = 'SUPERADMIN'
         AND c."CapabilityCode" IN ('PLATFORM_STAFF_VIEW','PLATFORM_STAFF_MANAGE',
             'PLATFORM_RBAC_TEMPLATE_EDIT','PLATFORM_RBAC_ROLLOUT','PLATFORM_TENANT_RBAC_OVERRIDE'))
   )
   AND (rc."HasAccess" IS DISTINCT FROM true
     OR rc."IsActive"  IS DISTINCT FROM true
     OR COALESCE(rc."IsDeleted", false) <> false);

-- ── E. Report, do not fix, the SUPERADMIN CompanyId question (cause C / §⑨ Q3) ───────
DO $$
DECLARE
  v_company_id int;
  v_rescuers   int;
BEGIN
  SELECT "CompanyId" INTO v_company_id
  FROM auth."Roles"
  WHERE "RoleCode" = 'SUPERADMIN' AND COALESCE("IsDeleted", false) = false
  LIMIT 1;

  IF v_company_id IS NOT NULL THEN
    RAISE WARNING
      'SUPERADMIN is CompanyId = % (not platform-global). Its PLATFORM_STAFF_MANAGE grant '
      'exists but the lock-out guard will NOT count its holders, because a company-scoped '
      'role is not control-plane authority. Report this back before anything is changed — '
      'the fix is a decision (move SUPERADMIN to CompanyId NULL, or relax the guard), not a '
      'seed edit. PROMPT-24 §⑨ Q3.', v_company_id;
  END IF;

  -- Exactly the guard's own predicate. If this is 0 the lock-out protection is OFF.
  SELECT count(DISTINCT ur."UserId") INTO v_rescuers
  FROM auth."UserRoles" ur
  JOIN auth."Roles" r ON r."RoleId" = ur."RoleId"
  JOIN auth."Users" u ON u."UserId" = ur."UserId"
  WHERE COALESCE(ur."IsActive", false) = true AND COALESCE(ur."IsDeleted", false) = false
    AND r."CompanyId" IS NULL AND COALESCE(r."IsDeleted", false) = false
    AND COALESCE(u."IsActive", false) = true AND COALESCE(u."IsDeleted", false) = false
    AND EXISTS (
      SELECT 1 FROM auth."RoleCapabilities" rc
      JOIN auth."Menus" m        ON m."MenuId" = rc."MenuId"
      JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
      WHERE rc."RoleId" = ur."RoleId" AND rc."HasAccess" = true
        AND COALESCE(rc."IsActive", false) = true AND COALESCE(rc."IsDeleted", false) = false
        AND m."MenuCode" = 'PLATFORM_STAFF' AND c."CapabilityCode" = 'PLATFORM_STAFF_MANAGE');

  RAISE NOTICE 'Accounts that can administer platform staff after this script: %', v_rescuers;

  IF v_rescuers = 0 THEN
    RAISE WARNING
      'ZERO accounts hold PLATFORM_STAFF_MANAGE through a platform-global role. The '
      'LAST_PLATFORM_ADMIN guard cannot protect anyone, and every write on the staff screen '
      'will 403 at CustomAuthorize. Assign PLATFORM_ADMIN to at least one live operator.';
  END IF;
END $$;

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT)
--
--   -- 1. Which roles now grant PLATFORM_STAFF_MANAGE, and would the guard count them?
--   --    Anything with counts_as_rescuer = false is a grant the guard ignores.
--   SELECT r."RoleId", r."RoleCode", r."CompanyId", rc."HasAccess", rc."IsActive", rc."IsDeleted",
--          (r."CompanyId" IS NULL
--           AND rc."HasAccess" = true
--           AND COALESCE(rc."IsActive", false) = true
--           AND COALESCE(rc."IsDeleted", false) = false) AS counts_as_rescuer
--     FROM auth."RoleCapabilities" rc
--     JOIN auth."Roles" r        ON r."RoleId" = rc."RoleId"
--     JOIN auth."Menus" m        ON m."MenuId" = rc."MenuId"
--     JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--    WHERE m."MenuCode" = 'PLATFORM_STAFF' AND c."CapabilityCode" = 'PLATFORM_STAFF_MANAGE'
--    ORDER BY r."RoleCode";
--
--   -- 2. WHO are the rescuers — the guard's count, itemised. Deactivating any one of these
--   --    is allowed; deactivating the last one is what LAST_PLATFORM_ADMIN refuses.
--   SELECT DISTINCT u."UserId", u."UserName", u."Email", r."RoleCode"
--     FROM auth."UserRoles" ur
--     JOIN auth."Roles" r ON r."RoleId" = ur."RoleId"
--     JOIN auth."Users" u ON u."UserId" = ur."UserId"
--    WHERE COALESCE(ur."IsActive",false) AND NOT COALESCE(ur."IsDeleted",false)
--      AND r."CompanyId" IS NULL AND NOT COALESCE(r."IsDeleted",false)
--      AND COALESCE(u."IsActive",false) AND NOT COALESCE(u."IsDeleted",false)
--      AND EXISTS (SELECT 1 FROM auth."RoleCapabilities" rc
--                    JOIN auth."Menus" m        ON m."MenuId" = rc."MenuId"
--                    JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--                   WHERE rc."RoleId" = ur."RoleId" AND rc."HasAccess"
--                     AND COALESCE(rc."IsActive",false) AND NOT COALESCE(rc."IsDeleted",false)
--                     AND m."MenuCode" = 'PLATFORM_STAFF'
--                     AND c."CapabilityCode" = 'PLATFORM_STAFF_MANAGE')
--    ORDER BY u."UserId";
--
--   -- 3. PROMPT-24 §⑨ Q3 — the still-open question. Paste this result back.
--   SELECT "RoleId","RoleCode","CompanyId","IsSystem","IsPlatform","IsAssignable"
--     FROM auth."Roles" WHERE "RoleCode" = 'SUPERADMIN' AND COALESCE("IsDeleted",false) = false;
-- =====================================================================================
