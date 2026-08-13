-- =============================================================================
-- Generic Import — capability seed + per-grid authorization wiring (P1.1)
-- =============================================================================
-- PostgreSQL. Idempotent and re-runnable.
--
-- Import previously had NO capability enforcement at all. This script makes
-- contact-import and donation-import separately grantable by wiring each grid
-- definition to its own (menu, capability) pair:
--
--     grid CONTACT      -> menu CONTACTIMPORT + capability IMPORT
--     grid BULKDONATION -> menu BULKDONATION  + capability IMPORT
--
-- MODIFY is seeded on the same two menus for the execution queue (P9.5). Reordering the queue
-- decides whose colleague waits, so ReorderImportQueueHandler requires MODIFY rather than IMPORT —
-- which every importer holds. Without this the reorder mutation is 403 for everyone.
--
-- Both menus are created by Pss2.0_Global_Menus_List.sql with the full capability
-- set, so STEP 1/2 are no-ops on a cleanly seeded database and act as a repair on
-- drifted tenants. STEP 3 is the part that is genuinely new.
--
-- PREREQUISITE: migration Add_ImportGrid_RequiredCapability must be applied first
-- (adds import."ImportGridDefinitions"."RequiredMenuCode" / "RequiredCapabilityCode").
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- STEP 1: Ensure the IMPORT capability is attached to both import menus.
-- -----------------------------------------------------------------------------
INSERT INTO auth."MenuCapabilities"(
    "MenuId", "CapabilityId", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT m."MenuId", c."CapabilityId", 2, now(), null, null, true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" IN ('CONTACTIMPORT', 'BULKDONATION')
  AND c."CapabilityCode" IN ('IMPORT', 'MODIFY')
  AND NOT EXISTS (
      SELECT 1 FROM auth."MenuCapabilities" mc
      WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- Re-activate any row that was previously soft-deleted / deactivated.
UPDATE auth."MenuCapabilities" mc
SET "IsActive" = true, "IsDeleted" = false, "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m, auth."Capabilities" c
WHERE mc."MenuId" = m."MenuId"
  AND mc."CapabilityId" = c."CapabilityId"
  AND m."MenuCode" IN ('CONTACTIMPORT', 'BULKDONATION')
  AND c."CapabilityCode" IN ('IMPORT', 'MODIFY')
  AND (mc."IsActive" IS DISTINCT FROM true OR mc."IsDeleted" IS DISTINCT FROM false);

-- -----------------------------------------------------------------------------
-- STEP 2: Grant IMPORT on both menus to BUSINESSADMIN (all tenants).
-- -----------------------------------------------------------------------------
INSERT INTO auth."RoleCapabilities"(
    "RoleId", "MenuId", "CapabilityId", "HasAccess",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, 2, now(), null, null, true, false
FROM auth."Roles" r
CROSS JOIN auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE r."RoleCode" = 'BUSINESSADMIN'
  AND m."MenuCode" IN ('CONTACTIMPORT', 'BULKDONATION')
  AND c."CapabilityCode" IN ('IMPORT', 'MODIFY')
  AND NOT EXISTS (
      SELECT 1 FROM auth."RoleCapabilities" rc
      WHERE rc."RoleId" = r."RoleId"
        AND rc."MenuId" = m."MenuId"
        AND rc."CapabilityId" = c."CapabilityId"
  );

-- Repair rows that exist but are revoked / inactive.
UPDATE auth."RoleCapabilities" rc
SET "HasAccess" = true, "IsActive" = true, "IsDeleted" = false,
    "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Roles" r, auth."Menus" m, auth."Capabilities" c
WHERE rc."RoleId" = r."RoleId"
  AND rc."MenuId" = m."MenuId"
  AND rc."CapabilityId" = c."CapabilityId"
  AND r."RoleCode" = 'BUSINESSADMIN'
  AND m."MenuCode" IN ('CONTACTIMPORT', 'BULKDONATION')
  AND c."CapabilityCode" IN ('IMPORT', 'MODIFY')
  AND (rc."HasAccess" IS DISTINCT FROM true
       OR rc."IsActive" IS DISTINCT FROM true
       OR rc."IsDeleted" IS DISTINCT FROM false);

-- -----------------------------------------------------------------------------
-- STEP 3: Point each grid definition at the (menu, capability) pair the upload
--         handler must check at runtime.
-- -----------------------------------------------------------------------------
UPDATE import."ImportGridDefinitions"
SET "RequiredMenuCode" = 'CONTACTIMPORT',
    "RequiredCapabilityCode" = 'IMPORT',
    "ModifiedBy" = 2,
    "ModifiedDate" = now()
WHERE "GridCode" = 'CONTACT'
  AND ("RequiredMenuCode" IS DISTINCT FROM 'CONTACTIMPORT'
       OR "RequiredCapabilityCode" IS DISTINCT FROM 'IMPORT');

UPDATE import."ImportGridDefinitions"
SET "RequiredMenuCode" = 'BULKDONATION',
    "RequiredCapabilityCode" = 'IMPORT',
    "ModifiedBy" = 2,
    "ModifiedDate" = now()
WHERE "GridCode" = 'BULKDONATION'
  AND ("RequiredMenuCode" IS DISTINCT FROM 'BULKDONATION'
       OR "RequiredCapabilityCode" IS DISTINCT FROM 'IMPORT');

COMMIT;

-- =============================================================================
-- VERIFICATION
-- =============================================================================
-- Expect 4 rows (CONTACTIMPORT / BULKDONATION x IMPORT / MODIFY), all active.
SELECT m."MenuCode", c."CapabilityCode", mc."IsActive", mc."IsDeleted"
FROM auth."MenuCapabilities" mc
JOIN auth."Menus" m ON m."MenuId" = mc."MenuId"
JOIN auth."Capabilities" c ON c."CapabilityId" = mc."CapabilityId"
WHERE m."MenuCode" IN ('CONTACTIMPORT', 'BULKDONATION')
  AND c."CapabilityCode" IN ('IMPORT', 'MODIFY');

-- Expect 4 rows per BUSINESSADMIN role (one per tenant), all HasAccess = true.
SELECT r."RoleCode", r."CompanyId", m."MenuCode", c."CapabilityCode", rc."HasAccess"
FROM auth."RoleCapabilities" rc
JOIN auth."Roles" r ON r."RoleId" = rc."RoleId"
JOIN auth."Menus" m ON m."MenuId" = rc."MenuId"
JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
WHERE r."RoleCode" = 'BUSINESSADMIN'
  AND m."MenuCode" IN ('CONTACTIMPORT', 'BULKDONATION')
  AND c."CapabilityCode" IN ('IMPORT', 'MODIFY')
ORDER BY r."CompanyId", m."MenuCode";

-- Expect both grids wired (expect 2).
SELECT "GridCode", "RequiredMenuCode", "RequiredCapabilityCode"
FROM import."ImportGridDefinitions"
ORDER BY "DisplayOrder";
