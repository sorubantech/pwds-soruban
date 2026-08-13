-- =============================================================================
-- PSS 2.0 — Recycle Bin ("Recently Deleted") menu + capability seed
--
-- Screen  : setting/dataconfig/recyclebin   (MenuCode RECYCLEBIN)
-- Parent  : Settings → Data  (MenuCode SET_DATACONFIG, resolved BY CODE — never by id,
--           because the id differs per environment)
-- Module  : SETTING
--
-- WHAT THIS MENU DOES AND DOES NOT CONTROL
--   RECYCLEBIN decides ONE thing: whether the screen renders at all. It does NOT decide what
--   a user sees inside it. Visibility of each deleted record is Read on that record's OWN menu
--   (CONTACT / GLOBALDONATION / CAMPAIGN), and restoring it is Delete on that same menu, both
--   enforced server-side in RecycleBinAccess. So a user granted RECYCLEBIN but holding no
--   Read anywhere sees an empty bin — correctly, and without a permission error.
--
--   That is also why only READ and ISMENURENDER are seeded here. There is deliberately no
--   RECYCLEBIN "Delete" capability: restore authority is borrowed from the record's own menu,
--   and inventing a second, competing grant here would let someone hold restore rights over
--   records they cannot otherwise see.
--
-- SCHEMA NOTE — do NOT qualify these with `app`:
--   auth."Modules" / "Menus" / "Capabilities" / "MenuCapabilities" / "Roles" / "RoleCapabilities"
--
-- TWO SEPARATE CHECKS, BOTH REQUIRED:
--   1. API authorization — auth."RoleCapabilities" joining Role → Menu(MenuCode) → Capability.
--                          auth."MenuCapabilities" is NOT consulted by HasAccessAsync.
--   2. Sidebar rendering — the nav is built from menus the user holds ISMENURENDER on. A menu
--                          with READ but no ISMENURENDER grant is reachable by URL and
--                          completely invisible in the nav.
--   auth."MenuCapabilities" is still seeded because it is what the role matrix enumerates —
--   omit it and these grants become unmanageable through the Access Control UI.
--
-- MenuUrl has NO leading slash: 'setting/dataconfig/recyclebin'. That matches its siblings
-- (MASTERDATA, ORGANIZATIONBANKACCOUNT) — the nav matcher identifies a row by this string, so
-- a lone leading slash in this subtree would break the link.
--
-- NO DDL, NO DELETE. app."RecycleBinEntries" comes from an EF migration, which is a separate,
-- user-owned step; this script never creates a table. Nothing here removes a row either —
-- superseding is IsDeleted = true / IsActive = false, never DELETE.
--
-- SUPERADMIN is matched by RoleCode alone and is never revoked or overwritten: every INSERT is
-- guarded by NOT EXISTS, and no UPDATE below touches a SUPERADMIN row.
--
-- UNTIL THE MIGRATION AND THIS SCRIPT ARE BOTH APPLIED, the screen 404s and the feature is
-- inert — deletes still work, they simply record no episode.
--
-- SAFE TO RE-RUN. Idempotent throughout.
-- =============================================================================

BEGIN;

-- ─── STEP 1: Menu — RECYCLEBIN ───────────────────────────────────────────────
-- OrderBy 90 parks it at the end of Settings → Data. It is a destination people arrive at in a
-- hurry, but it is not something they configure, so it does not belong above Master Data.
INSERT INTO auth."Menus"(
    "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description",
    "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "IsLeastMenu", "IsVisible")
SELECT
    'Recently Deleted', 'RECYCLEBIN',
    (SELECT "MenuId" FROM auth."Menus" WHERE "MenuCode" = 'SET_DATACONFIG'),
    'solar:trash-bin-trash-bold',
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = 'SETTING'),
    'setting/dataconfig/recyclebin',
    'Records deleted in the last 30 days, and who deleted them. Restore one at a time. This is not a backup.',
    90, 2, now(), null, null,
    true, false, true, true
WHERE NOT EXISTS (
    SELECT 1 FROM auth."Menus" WHERE "MenuCode" = 'RECYCLEBIN'
);

-- Repair an already-present row (url drift / soft-deleted / demoted to a non-leaf).
-- Guarded on the wrong values, so this is a no-op once the row is correct.
UPDATE auth."Menus"
SET "MenuName"     = 'Recently Deleted',
    "MenuUrl"      = 'setting/dataconfig/recyclebin',
    "IsLeastMenu"  = true,
    "IsActive"     = true,
    "IsVisible"    = true,
    "IsDeleted"    = false,
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE "MenuCode" = 'RECYCLEBIN'
  AND (
        "MenuUrl"     IS DISTINCT FROM 'setting/dataconfig/recyclebin'
     OR "IsLeastMenu" IS DISTINCT FROM true
     OR "IsActive"    IS DISTINCT FROM true
     OR "IsVisible"   IS DISTINCT FROM true
     OR "IsDeleted"   IS DISTINCT FROM false
  );

-- ─── STEP 2: Capabilities — READ and ISMENURENDER ────────────────────────────
-- Both are base-app capabilities that already exist in every environment; the insert below is a
-- safety net, not the normal path. The guard checks CapabilityName as well as CapabilityCode
-- because auth."Capabilities" carries a UNIQUE index on (CapabilityName, IsActive) — guarding on
-- the code alone would collide with an existing row that happens to share the name.
INSERT INTO auth."Capabilities"(
    "CapabilityName", "CapabilityCode", "Description", "IsSpecial", "OrderBy",
    "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
SELECT v.cap_name, v.cap_code, v.cap_desc, false, v.order_by, 2, now(), true, false
FROM (VALUES
  ('Read', 'READ', 'View records on a screen.', 1)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityCode" = v.cap_code)
  AND NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ISMENURENDER is never inserted — it is a base-app capability and creating a second row for it
-- would split every existing grant in two.

-- ─── STEP 3: MenuCapabilities — what the role matrix can offer for this menu ─
-- READ and ISMENURENDER only. No CREATE/MODIFY/DELETE: nothing is authored on this screen, and
-- restore authority deliberately lives on the deleted record's own menu (see the header).
INSERT INTO auth."MenuCapabilities"(
    "MenuId", "CapabilityId", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted")
SELECT m."MenuId", c."CapabilityId", 2, now(), null, null, true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'RECYCLEBIN'
  AND c."CapabilityCode" IN ('READ', 'ISMENURENDER')
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
      SELECT 1 FROM auth."MenuCapabilities" mc
      WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- Re-activate any that were previously superseded.
UPDATE auth."MenuCapabilities" mc
SET "IsActive" = true, "IsDeleted" = false, "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m
WHERE mc."MenuId" = m."MenuId"
  AND m."MenuCode" = 'RECYCLEBIN'
  AND (mc."IsActive" = false OR mc."IsDeleted" = true);

-- ─── STEP 4a: Role grants — BUSINESSADMIN, per tenant ────────────────────────
INSERT INTO auth."RoleCapabilities"(
    "RoleId", "MenuId", "CapabilityId", "HasAccess", "CreatedBy", "CreatedDate",
    "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, 2, now(), null, null, true, false
FROM auth."Roles" r
CROSS JOIN auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE r."RoleCode" = 'BUSINESSADMIN'
  AND r."IsDeleted" IS NOT TRUE
  AND m."MenuCode" = 'RECYCLEBIN'
  AND c."CapabilityCode" IN ('READ', 'ISMENURENDER')
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
      SELECT 1 FROM auth."RoleCapabilities" rc
      WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
  );

-- Re-activate BUSINESSADMIN grants only. SUPERADMIN is deliberately excluded from this UPDATE:
-- its rows are inserted if absent (4b) and otherwise left exactly as an administrator set them.
UPDATE auth."RoleCapabilities" rc
SET "HasAccess" = true, "IsActive" = true, "IsDeleted" = false, "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m, auth."Roles" r
WHERE rc."MenuId" = m."MenuId" AND rc."RoleId" = r."RoleId"
  AND m."MenuCode" = 'RECYCLEBIN'
  AND r."RoleCode" = 'BUSINESSADMIN'
  AND (rc."HasAccess" = false OR rc."IsActive" = false OR rc."IsDeleted" = true);

-- ─── STEP 4b: Role grants — SUPERADMIN ───────────────────────────────────────
-- Matched by RoleCode alone (SUPERADMIN is global, CompanyId IS NULL). Insert-if-absent only:
-- nothing here revokes or overwrites an existing SUPERADMIN row.
INSERT INTO auth."RoleCapabilities"(
    "RoleId", "MenuId", "CapabilityId", "HasAccess", "CreatedBy", "CreatedDate",
    "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, 2, now(), null, null, true, false
FROM auth."Roles" r
CROSS JOIN auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE r."RoleCode" = 'SUPERADMIN'
  AND r."IsDeleted" IS NOT TRUE
  AND m."MenuCode" = 'RECYCLEBIN'
  AND c."CapabilityCode" IN ('READ', 'ISMENURENDER')
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
      SELECT 1 FROM auth."RoleCapabilities" rc
      WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
  );

-- No other role is granted the screen here. Widen it through the Access Control screen if the
-- business asks — not by editing this file after it has been applied.

COMMIT;

-- ─── VERIFICATION (run after commit) ─────────────────────────────────────────

-- Menu exists as a leaf under Settings → Data (expect 1 row, parent SET_DATACONFIG):
SELECT m."MenuId", m."MenuCode", m."MenuName", m."MenuUrl", p."MenuCode" AS parent,
       m."OrderBy", m."IsLeastMenu", m."IsVisible", m."IsActive"
FROM auth."Menus" m
LEFT JOIN auth."Menus" p ON p."MenuId" = m."ParentMenuId"
WHERE m."MenuCode" = 'RECYCLEBIN';
-- A NULL parent means SET_DATACONFIG was not found — fix the parent before shipping, or the
-- screen renders but never appears in the sidebar.

-- No other menu claims the same path (expect exactly 1 row):
SELECT "MenuCode" FROM auth."Menus"
WHERE "MenuUrl" = 'setting/dataconfig/recyclebin' AND COALESCE("IsDeleted", false) = false;

-- MenuCapabilities registered (expect 2 — ISMENURENDER, READ):
SELECT c."CapabilityCode"
FROM auth."MenuCapabilities" mc
JOIN auth."Menus" m        ON m."MenuId"       = mc."MenuId"
JOIN auth."Capabilities" c ON c."CapabilityId" = mc."CapabilityId"
WHERE m."MenuCode" = 'RECYCLEBIN' AND mc."IsDeleted" = false
ORDER BY c."CapabilityCode";

-- Who can reach the screen (expect SUPERADMIN plus each tenant's BUSINESSADMIN, 2 rows each):
SELECT r."RoleCode", r."CompanyId", c."CapabilityCode", rc."HasAccess"
FROM auth."RoleCapabilities" rc
JOIN auth."Roles" r        ON r."RoleId"       = rc."RoleId"
JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
JOIN auth."Menus" m        ON m."MenuId"       = rc."MenuId"
WHERE m."MenuCode" = 'RECYCLEBIN' AND rc."IsDeleted" = false
ORDER BY r."RoleCode", c."CapabilityCode";

-- The episode table exists and this script created nothing in it (expect 0):
SELECT count(*) AS recycle_bin_entries FROM app."RecycleBinEntries";
-- "relation does not exist" here means the EF migration for app."RecycleBinEntries" has not been
-- applied yet. The screen will render and then error until it is.
