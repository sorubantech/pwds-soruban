-- =============================================================================
-- Organization Bank Accounts — MENU + CAPABILITY seed
-- =============================================================================
-- Screen  : setting/orgsettings/organizationbankaccount  (MenuCode ORGANIZATIONBANKACCOUNT)
-- Parent   : SET_PAYMENTCONFIG  ("Payment Config")
-- Table    : app."OrganizationBankAccounts"  (already migrated 20260707050351)
--
-- WHY THIS SCRIPT EXISTS
--   Backend CQRS, GraphQL endpoints and the whole frontend screen already ship
--   in code. Only the auth.* menu rows were never applied, so the screen is
--   reachable by URL but invisible in the sidebar.
--
--   The older per-feature script
--     PSS_2.0_Backend/.../sql-scripts-dyanmic/GrantFundReceipt-OrganizationBankAccount-sqlscripts.sql
--   seeded only 5 capabilities (READ/CREATE/MODIFY/DELETE/TOGGLE) and skipped
--   ISMENURENDER — the capability the sidebar renderer checks. If that script was
--   already run the menu exists but still does not render. This script REPAIRS
--   that case: it tops up whichever of the 8 canonical capabilities are missing
--   instead of bailing out when a menu already has some.
--
--   It also does NOT re-seed sett."Grids"/"Fields"/"GridFields". This screen is a
--   developer-owned CONFIG page (custom list + dialog form, per the config-screens
--   convention) because the sensitive AccountNumber needs a masked write-only
--   widget the generic RJSF grid form cannot express — so grid metadata is unused.
--
-- SAFE TO RE-RUN. Idempotent throughout; no DDL, no migration.
-- =============================================================================

BEGIN;

-- ─── STEP 1: Menu row ────────────────────────────────────────────────────────

INSERT INTO auth."Menus"(
    "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description",
    "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "IsLeastMenu")
SELECT
    'Organization Bank Accounts', 'ORGANIZATIONBANKACCOUNT',
    (SELECT "MenuId" FROM auth."Menus" WHERE "MenuCode" = 'SET_PAYMENTCONFIG'),
    'solar:card-bold',
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = 'SETTING'),
    'setting/orgsettings/organizationbankaccount', null, 3, 2, now(), null, null,
    true, false, true
WHERE NOT EXISTS (
    SELECT 1 FROM auth."Menus" WHERE "MenuCode" = 'ORGANIZATIONBANKACCOUNT'
);

-- Repair an already-present row (wrong parent / url drift / soft-deleted / not a leaf).
-- IsLeastMenu=true is required or the sidebar treats it as a non-clickable group.
UPDATE auth."Menus"
SET "ParentMenuId" = (SELECT "MenuId" FROM auth."Menus" WHERE "MenuCode" = 'SET_PAYMENTCONFIG'),
    "ModuleId"     = (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = 'SETTING'),
    "MenuUrl"      = 'setting/orgsettings/organizationbankaccount',
    "MenuIcon"     = 'solar:card-bold',
    "IsLeastMenu"  = true,
    "IsActive"     = true,
    "IsDeleted"    = false,
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE "MenuCode" = 'ORGANIZATIONBANKACCOUNT'
  AND (
        "ParentMenuId" IS DISTINCT FROM (SELECT "MenuId" FROM auth."Menus" WHERE "MenuCode" = 'SET_PAYMENTCONFIG')
     OR "MenuUrl" IS DISTINCT FROM 'setting/orgsettings/organizationbankaccount'
     OR "IsLeastMenu" = false OR "IsActive" = false OR "IsDeleted" = true
  );

-- ─── STEP 2: Menu capabilities (all 8 canonical, top-up style) ───────────────

INSERT INTO auth."MenuCapabilities"(
    "MenuId", "CapabilityId", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT m."MenuId", c."CapabilityId", 2, now(), null, null, true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'ORGANIZATIONBANKACCOUNT'
  AND c."CapabilityCode" IN ('READ','CREATE','MODIFY','DELETE','EXPORT','IMPORT','TOGGLE','ISMENURENDER')
  AND NOT EXISTS (
      SELECT 1 FROM auth."MenuCapabilities" mc
      WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- Re-activate any that were previously soft-deleted.
UPDATE auth."MenuCapabilities" mc
SET "IsActive" = true, "IsDeleted" = false, "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m
WHERE mc."MenuId" = m."MenuId"
  AND m."MenuCode" = 'ORGANIZATIONBANKACCOUNT'
  AND (mc."IsActive" = false OR mc."IsDeleted" = true);

-- ─── STEP 3: Role capabilities — BUSINESSADMIN only ──────────────────────────

INSERT INTO auth."RoleCapabilities"(
    "RoleId", "MenuId", "CapabilityId", "HasAccess", "CreatedBy", "CreatedDate",
    "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, 2, now(), null, null, true, false
FROM auth."Roles" r
CROSS JOIN auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE r."RoleCode" = 'BUSINESSADMIN'
  AND m."MenuCode" = 'ORGANIZATIONBANKACCOUNT'
  AND c."CapabilityCode" IN ('READ','CREATE','MODIFY','DELETE','EXPORT','IMPORT','TOGGLE','ISMENURENDER')
  AND NOT EXISTS (
      SELECT 1 FROM auth."RoleCapabilities" rc
      WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
  );

UPDATE auth."RoleCapabilities" rc
SET "HasAccess" = true, "IsActive" = true, "IsDeleted" = false, "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m, auth."Roles" r
WHERE rc."MenuId" = m."MenuId" AND rc."RoleId" = r."RoleId"
  AND m."MenuCode" = 'ORGANIZATIONBANKACCOUNT'
  AND r."RoleCode" = 'BUSINESSADMIN'
  AND (rc."HasAccess" = false OR rc."IsActive" = false OR rc."IsDeleted" = true);

COMMIT;

-- ─── VERIFICATION (run after commit; expect 1 / 8 / 8) ───────────────────────

SELECT m."MenuId", m."MenuName", m."MenuUrl", p."MenuCode" AS parent, m."OrderBy",
       m."IsLeastMenu", m."IsActive"
FROM auth."Menus" m
LEFT JOIN auth."Menus" p ON p."MenuId" = m."ParentMenuId"
WHERE m."MenuCode" = 'ORGANIZATIONBANKACCOUNT';

SELECT count(*) AS menu_capabilities
FROM auth."MenuCapabilities" mc
JOIN auth."Menus" m ON m."MenuId" = mc."MenuId"
WHERE m."MenuCode" = 'ORGANIZATIONBANKACCOUNT' AND mc."IsDeleted" = false;

SELECT count(*) AS businessadmin_role_capabilities
FROM auth."RoleCapabilities" rc
JOIN auth."Menus" m ON m."MenuId" = rc."MenuId"
JOIN auth."Roles" r ON r."RoleId" = rc."RoleId"
WHERE m."MenuCode" = 'ORGANIZATIONBANKACCOUNT'
  AND r."RoleCode" = 'BUSINESSADMIN' AND rc."IsDeleted" = false;
