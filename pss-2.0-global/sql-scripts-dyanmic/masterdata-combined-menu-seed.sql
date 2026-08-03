-- =============================================================================
-- Screen #76 Master Data (combined with #162 Master Data Type) — MENU seed
-- =============================================================================
-- Screen  : setting/dataconfig/masterdata   (MenuCode MASTERDATA)
-- Legacy   : setting/dataconfig/masterdatatype (MenuCode MASTERDATATYPE) — now hidden
--
-- WHY THIS SCRIPT EXISTS
--   Types and their values used to be two separate screens. They are now one
--   split-panel screen: pick a type on the left, manage its values on the right.
--   The MASTERDATATYPE route still resolves (existing bookmarks, saved links and
--   any role granted only that menu) and renders the same combined component —
--   it just must not appear twice in the sidebar.
--
-- HOW THE HIDE WORKS — and why it is not IsActive = false
--   GetParentChildMenu builds the sidebar from  Menus.IsActive = true  AND  a
--   granted ISMENURENDER role capability. GetRoleCapabilityByUser — which is what
--   the legacy page config calls to decide canRead — ALSO requires
--   Menus.IsActive = true. Deactivating the menu would therefore hide it *and*
--   turn the legacy route into an Access Denied page.
--   So: keep the menu active, revoke only ISMENURENDER. The sidebar drops it, the
--   route keeps working, and every capability row stays intact and reversible.
--   IsVisible is set false as well — some surfaces read that flag instead.
--
-- SAFE TO RE-RUN. Idempotent throughout; no DDL, no DELETE, no migration.
-- Apply AFTER the migration in PSS-2.0-SCREEN-76-MASTERDATA-MIGRATION-SPEC.md.
-- =============================================================================

BEGIN;

-- ─── STEP 1: MASTERDATA menu row — the surviving, visible entry ──────────────

INSERT INTO auth."Menus"(
    "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description",
    "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "IsLeastMenu")
SELECT
    'Master Data', 'MASTERDATA',
    (SELECT "MenuId" FROM auth."Menus" WHERE "MenuCode" = 'SET_DATACONFIG'),
    'solar:database-bold',
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = 'SETTING'),
    'setting/dataconfig/masterdata',
    'Lookup types and their values — categories and reference data',
    1, 2, now(), null, null,
    true, false, true
WHERE NOT EXISTS (
    SELECT 1 FROM auth."Menus" WHERE "MenuCode" = 'MASTERDATA'
);

-- Repair an already-present row (url drift / soft-deleted / not a leaf).
-- IsLeastMenu = true is required or the sidebar treats it as a non-clickable group.
UPDATE auth."Menus"
SET "MenuName"     = 'Master Data',
    "MenuUrl"      = 'setting/dataconfig/masterdata',
    "OrderBy"      = 1,
    "IsLeastMenu"  = true,
    "IsActive"     = true,
    "IsVisible"    = true,
    "IsDeleted"    = false,
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE "MenuCode" = 'MASTERDATA'
  AND (
        "MenuUrl" IS DISTINCT FROM 'setting/dataconfig/masterdata'
     OR "OrderBy" IS DISTINCT FROM 1
     OR "IsLeastMenu" IS DISTINCT FROM true
     OR "IsActive"    IS DISTINCT FROM true
     OR "IsVisible"   IS DISTINCT FROM true
     OR "IsDeleted"   IS DISTINCT FROM false
  );

-- ─── STEP 2: MASTERDATA menu capabilities (8 canonical, top-up style) ────────

INSERT INTO auth."MenuCapabilities"(
    "MenuId", "CapabilityId", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT m."MenuId", c."CapabilityId", 2, now(), null, null, true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'MASTERDATA'
  AND c."CapabilityCode" IN ('READ','CREATE','MODIFY','DELETE','EXPORT','IMPORT','TOGGLE','ISMENURENDER')
  AND NOT EXISTS (
      SELECT 1 FROM auth."MenuCapabilities" mc
      WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

UPDATE auth."MenuCapabilities" mc
SET "IsActive" = true, "IsDeleted" = false, "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m
WHERE mc."MenuId" = m."MenuId"
  AND m."MenuCode" = 'MASTERDATA'
  AND (mc."IsActive" = false OR mc."IsDeleted" = true);

-- ─── STEP 3: MASTERDATA role capabilities — BUSINESSADMIN only ───────────────

INSERT INTO auth."RoleCapabilities"(
    "RoleId", "MenuId", "CapabilityId", "HasAccess", "CreatedBy", "CreatedDate",
    "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, 2, now(), null, null, true, false
FROM auth."Roles" r
CROSS JOIN auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE r."RoleCode" = 'BUSINESSADMIN'
  AND m."MenuCode" = 'MASTERDATA'
  AND c."CapabilityCode" IN ('READ','CREATE','MODIFY','DELETE','EXPORT','IMPORT','TOGGLE','ISMENURENDER')
  AND NOT EXISTS (
      SELECT 1 FROM auth."RoleCapabilities" rc
      WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
  );

UPDATE auth."RoleCapabilities" rc
SET "HasAccess" = true, "IsActive" = true, "IsDeleted" = false, "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m, auth."Roles" r
WHERE rc."MenuId" = m."MenuId" AND rc."RoleId" = r."RoleId"
  AND m."MenuCode" = 'MASTERDATA'
  AND r."RoleCode" = 'BUSINESSADMIN'
  AND (rc."HasAccess" = false OR rc."IsActive" = false OR rc."IsDeleted" = true);

-- ─── STEP 4: MASTERDATATYPE — keep reachable, drop from the sidebar ──────────
-- IsActive stays TRUE on purpose (see header): GetRoleCapabilityByUser needs it
-- for the legacy route to resolve canRead.

UPDATE auth."Menus"
SET "IsVisible"    = false,
    "IsLeastMenu"  = false,
    "Description"  = 'Merged into Master Data (#76). Route kept for existing links.',
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE "MenuCode" = 'MASTERDATATYPE'
  AND ("IsVisible" IS DISTINCT FROM false OR "IsLeastMenu" IS DISTINCT FROM false);

-- Revoke ONLY the render capability — every other grant is left untouched so a
-- role that had MASTERDATATYPE still reaches the combined screen by URL.
UPDATE auth."RoleCapabilities" rc
SET "HasAccess" = false, "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m, auth."Capabilities" c
WHERE rc."MenuId" = m."MenuId"
  AND rc."CapabilityId" = c."CapabilityId"
  AND m."MenuCode" = 'MASTERDATATYPE'
  AND c."CapabilityCode" = 'ISMENURENDER'
  AND rc."HasAccess" IS DISTINCT FROM false;

COMMIT;

-- ─── VERIFICATION (run after commit) ─────────────────────────────────────────

-- Expect MASTERDATA visible leaf, MASTERDATATYPE active but not visible/leaf:
SELECT m."MenuCode", m."MenuName", m."MenuUrl", m."OrderBy",
       m."IsActive", m."IsVisible", m."IsLeastMenu"
FROM auth."Menus" m
WHERE m."MenuCode" IN ('MASTERDATA','MASTERDATATYPE')
ORDER BY m."MenuCode";

-- Expect 8:
SELECT count(*) AS masterdata_menu_capabilities
FROM auth."MenuCapabilities" mc
JOIN auth."Menus" m ON m."MenuId" = mc."MenuId"
WHERE m."MenuCode" = 'MASTERDATA' AND mc."IsDeleted" = false;

-- Expect 8 granted:
SELECT count(*) AS businessadmin_masterdata_grants
FROM auth."RoleCapabilities" rc
JOIN auth."Menus" m ON m."MenuId" = rc."MenuId"
JOIN auth."Roles" r ON r."RoleId" = rc."RoleId"
WHERE m."MenuCode" = 'MASTERDATA' AND r."RoleCode" = 'BUSINESSADMIN'
  AND rc."HasAccess" = true AND rc."IsDeleted" = false;

-- Expect 0 rows — no role should still render the legacy entry:
SELECT r."RoleCode"
FROM auth."RoleCapabilities" rc
JOIN auth."Menus" m ON m."MenuId" = rc."MenuId"
JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
JOIN auth."Roles" r ON r."RoleId" = rc."RoleId"
WHERE m."MenuCode" = 'MASTERDATATYPE' AND c."CapabilityCode" = 'ISMENURENDER'
  AND rc."HasAccess" = true;

-- ─── REVERSAL (restore the two separate sidebar entries) ─────────────────────
--   UPDATE auth."Menus" SET "IsVisible" = true, "IsLeastMenu" = true, "ModifiedDate" = now()
--    WHERE "MenuCode" = 'MASTERDATATYPE';
--   UPDATE auth."RoleCapabilities" rc SET "HasAccess" = true, "ModifiedDate" = now()
--     FROM auth."Menus" m, auth."Capabilities" c
--    WHERE rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
--      AND m."MenuCode" = 'MASTERDATATYPE' AND c."CapabilityCode" = 'ISMENURENDER';
