-- =====================================================================================
--  PSS 2.0 — P-DATA-PURGE §⑤ : Data cleanup capabilities + menu
--
--  WHY TWO CAPABILITIES
--  --------------------
--  Soft delete and hard delete are not degrees of the same authority — they are different
--  actions with different blast radii. A soft delete is reversible: the rows are flagged, a
--  manifest is written, and Data cleanup can put every one of them back for the length of the
--  cooling-off window. A hard delete is not: the rows leave the database and no restore exists.
--
--  Folding them into one capability would mean that granting an operator the routine cleanup
--  action also hands them the irreversible one, which is exactly the grant nobody intends to
--  make. So:
--
--    PLATFORM_DATA_PURGE        soft delete, restore, preview, and the candidate list.
--                               Everything on this feature that can be undone.
--    PLATFORM_DATA_PURGE_HARD   permanent deletion after the cooling-off window. Nothing else.
--                               Useless on its own — the screen it acts on needs …_PURGE to open.
--
--  The backend already enforces both ([CustomAuthorize] on the commands/queries). Until this
--  script is applied nothing grants them, so every purge operation refuses every caller —
--  including PLATFORM_ADMIN. That is the intended failure direction, but it does mean the
--  feature is inert until this runs.
--
--  ⚠ Deleting a lead from the LEAD LIST is unaffected. It still runs under PLATFORM_LEAD_EDIT;
--    it merely writes a purge manifest now so it can be restored. Nothing in the lead screens
--    can reach the hard-delete path.
--
--  DEPENDS ON:  ops-platform-rbac-seed.sql (PLATFORMCONTROLPLANE menu, PLATFORM module,
--               SUPERADMIN/PLATFORM_ADMIN roles)
--  IDEMPOTENT:  yes — every write is NOT EXISTS-guarded; re-running changes nothing.
--  ADDITIVE:    no DELETE, no revocation, no UPDATE of anyone's existing grant.
--  APPLY AS:    the DB owner, against the PSS 2.0 database.
-- =====================================================================================

BEGIN;

-- ── 0. Guards ────────────────────────────────────────────────────────────────────────
-- Fail loudly rather than half-apply. A NOT EXISTS-guarded INSERT whose join matches nothing
-- inserts zero rows and still reports success — that silence is what this block prevents.
DO $$
DECLARE
  v_root   int;
  v_module int;
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
END $$;

-- ── 1. Capabilities ──────────────────────────────────────────────────────────────────
-- auth."Capabilities" has a UNIQUE index on (CapabilityName, IsActive), so the idempotency
-- guard checks CapabilityName — the constrained column — not the code. Names carry the
-- "Platform " prefix for the same reason every other platform capability does: the index is
-- global, and "Purge Data" would collide with a tenant-side name someone adds later.
--
-- OrderBy 105/106 continues the 96-104 block (104 = PLATFORM_TENANT_ACCESS_VIEW).
-- IsSpecial = true: these are platform authorities, not tenant-visible ones.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT
  v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Platform Purge Data', 'PLATFORM_DATA_PURGE',
   'Open Data cleanup: preview the blast radius of a deletion, soft-delete a lead or tenant, and restore one during the cooling-off window. Reversible actions only.', 105),
  ('Platform Hard Delete Data', 'PLATFORM_DATA_PURGE_HARD',
   'Permanently delete a soft-deleted lead or tenant once its cooling-off window has elapsed. IRREVERSIBLE — there is no restore after this runs. Requires Platform Purge Data to reach the screen.', 106)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 2. Menu — PLATFORM_DATA_CLEANUP ──────────────────────────────────────────────────
-- Sibling of PLATFORM_STAFF (950) and PLATFORM_TENANT_ACCESS (955) under the control-plane
-- root; OrderBy 960 puts it last in that block, which is where a destructive tool belongs in a
-- list someone scans top-down.
--
-- MenuUrl is its own path, /ops/data-cleanup. MenuUrl is how the nav builder and the sidebar
-- active-state matcher identify a menu, so it must not be shared with another row.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Data Cleanup', 'PLATFORM_DATA_CLEANUP',
  (SELECT p."MenuId" FROM auth."Menus" p WHERE p."MenuCode" = 'PLATFORMCONTROLPLANE'),
  'ph-trash-simple',
  (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'PLATFORM'),
  '/ops/data-cleanup',
  'Review stale leads and abandoned tenants, preview what a deletion would remove, soft-delete or restore, and permanently delete after the cooling-off window.',
  960,
  true, 'Internal', true, now(), true, false
WHERE NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = 'PLATFORM_DATA_CLEANUP');

-- ── 3. MenuCapabilities — wire both capabilities to the menu ─────────────────────────
-- PlatformRoleMatrixBuilder builds its ROWS from menus that have ≥1 MenuCapability; it skips
-- any menu whose capability list is empty. Without this block the menu exists and the backend
-- enforces the capabilities, but the platform role matrix never shows a row for it — so nobody
-- could grant either capability through the UI, ever.
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'PLATFORM_DATA_CLEANUP'
  AND c."CapabilityCode" IN ('PLATFORM_DATA_PURGE','PLATFORM_DATA_PURGE_HARD')
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- ── 4. Grant — PLATFORM_ADMIN gets the reversible half only ──────────────────────────
-- PLATFORM_ADMIN can soft-delete, restore and preview. It does NOT get the hard delete by
-- default, and that is deliberate: the irreversible action should be an explicit decision
-- someone makes in the role matrix, for a named person, not something a role inherits because
-- it happens to be called "admin".
--
-- SUPPORT, IMPLEMENTATION, FINANCE and SALES get nothing here. Cleanup is not a support action.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_ADMIN', 'PLATFORM_DATA_PURGE')
) AS v(role_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
                          AND COALESCE(r."IsDeleted", false) = false
JOIN auth."Menus"        m ON m."MenuCode" = 'PLATFORM_DATA_CLEANUP'
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
                          AND COALESCE(c."IsDeleted", false) = false
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- ── 5. SUPERADMIN superset ───────────────────────────────────────────────────────────
-- ⚠ SEPARATE INSERT, matching SUPERADMIN by RoleCode ALONE — same reasoning as
--   platform-tenant-access-menu-seed.sql §5b. ops-platform-rbac-seed.sql joins SUPERADMIN with
--   `AND r."CompanyId" IS NULL`; if the SUPERADMIN row in this database is not CompanyId-null,
--   that join silently inserted nothing. Do not add a CompanyId predicate here.
--
--   SUPERADMIN gets BOTH capabilities, including the hard delete. It is the one role that is
--   meant to hold every authority the platform has, and someone must be able to complete a
--   deletion after the cooling-off window without first editing the role matrix.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_DATA_PURGE'),
  ('PLATFORM_DATA_PURGE_HARD')
) AS v(cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = 'SUPERADMIN' AND COALESCE(r."IsDeleted", false) = false
JOIN auth."Menus"        m ON m."MenuCode" = 'PLATFORM_DATA_CLEANUP'
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
                          AND COALESCE(c."IsDeleted", false) = false
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--
--   -- 1. Both capabilities exist, exactly once each:
--   SELECT "CapabilityCode","CapabilityName","OrderBy","IsSpecial"
--   FROM   auth."Capabilities"
--   WHERE  "CapabilityCode" LIKE 'PLATFORM\_DATA\_PURGE%' AND COALESCE("IsDeleted",false) = false
--   ORDER  BY "OrderBy";
--   -- expect 2 rows, OrderBy 105 and 106
--
--   -- 2. Menu is parented, routed and visible:
--   SELECT m."MenuCode", m."MenuUrl", m."OrderBy", m."IsVisible", p."MenuCode" AS parent
--   FROM   auth."Menus" m LEFT JOIN auth."Menus" p ON p."MenuId" = m."ParentMenuId"
--   WHERE  m."MenuCode" = 'PLATFORM_DATA_CLEANUP';
--   -- expect 1 row, /ops/data-cleanup, 960, true, parent PLATFORMCONTROLPLANE
--
--   -- 3. The role matrix will show a row for it (this is the block that is easy to forget):
--   SELECT c."CapabilityCode"
--   FROM   auth."MenuCapabilities" mc
--   JOIN   auth."Menus" m        ON m."MenuId" = mc."MenuId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = mc."CapabilityId"
--   WHERE  m."MenuCode" = 'PLATFORM_DATA_CLEANUP';
--   -- expect 2 rows
--
--   -- 4. Grants landed — and SUPERADMIN in particular is NOT empty:
--   SELECT r."RoleCode", c."CapabilityCode", rc."HasAccess"
--   FROM   auth."RoleCapabilities" rc
--   JOIN   auth."Roles" r        ON r."RoleId" = rc."RoleId"
--   JOIN   auth."Menus" m        ON m."MenuId" = rc."MenuId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--   WHERE  m."MenuCode" = 'PLATFORM_DATA_CLEANUP'
--   ORDER  BY r."RoleCode", c."CapabilityCode";
--   -- expect SUPERADMIN × 2 and PLATFORM_ADMIN × 1 (PLATFORM_DATA_PURGE only).
--   -- If SUPERADMIN is missing, the SUPERADMIN role row does not match RoleCode 'SUPERADMIN' —
--   -- check the actual code before adding any predicate to §5.
-- =====================================================================================
