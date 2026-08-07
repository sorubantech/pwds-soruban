-- =============================================================================
-- Consolidate "Tenant Access Control" into the Tenants screen — MENU HIDE seed
-- =============================================================================
-- Menu hidden : PLATFORM_TENANT_ACCESS  →  /ops/tenant-access
-- Menu kept   : PLATFORM_TENANTS        →  /ops/tenants
-- Written     : 2026-08-05
-- Applies to  : auth."Menus" + auth."RoleCapabilities"   (no DDL, no migration)
--
-- WHY THIS SCRIPT EXISTS
--   The control plane showed TWO tenant lists. "Tenants" is the hub — seven tabs
--   (identity, subscription, usage, provisioning, audit, gateway activity, access).
--   "Tenant Access Control" was only ever a PICKER: it listed tenants and then
--   navigated into  /ops/tenants/{companyId}?tab=access  — i.e. into a tab of the
--   screen above. Two doors, one room.
--
--   This closes the second door. The access matrix itself is NOT removed; it stays
--   exactly where it already lives, as the Access tab of the tenant hub.
--
-- WHAT IS DELIBERATELY PRESERVED — read before editing
--   Platform-side control of a tenant's access must survive this change intact:
--     • PLATFORM_TENANT_ACCESS_VIEW      — read the tenant's live role matrix
--     • PLATFORM_TENANT_RBAC_OVERRIDE    — break-glass edit of it (PLATFORM_ADMIN only)
--   Both are granted ON the PLATFORM_TENANT_ACCESS menu, and both are LEFT ALONE
--   here. The frontend hook usePlatformCapabilities matches on menu.menuCode, never
--   on the menu's visibility, so tenant-access-tab.tsx keeps resolving its gate from
--   a hidden menu without a single code change.
--
-- HOW THE HIDE WORKS — and why it is not IsActive = false, nor a DELETE
--   auth."RoleCapabilities" is keyed by MenuId. Deleting or deactivating the menu
--   row would orphan the two capabilities above — destroying the exact authority we
--   are trying to keep. GetRoleCapabilityMatrix.cs:59 also filters
--   `IsDeleted = false AND IsActive = true`, so a deactivated menu vanishes from the
--   platform role matrix and the grant switch itself becomes unreachable.
--
--   GetParentChildMenu.cs builds the sidebar from Menus.IsActive = true AND a granted
--   ISMENURENDER role capability. It does NOT read IsVisible (verified 2026-08-05:
--   no read path in AuthBusiness filters that flag). So the operative lever is the
--   ISMENURENDER revoke; IsVisible/IsLeastMenu are set alongside it because some
--   admin surfaces read those instead.
--
--   Net effect: menu row alive · capabilities alive · grants alive · matrix row alive
--   · route still resolves for bookmarks · sidebar entry gone.
--
--   This is the same pattern already used by masterdata-combined-menu-seed.sql when
--   MASTERDATATYPE was folded into MASTERDATA. Nothing new is being invented here.
--
-- SAFE TO RE-RUN. Idempotent throughout. No DDL, no DELETE, no migration.
-- REVERSAL is at the bottom of this file.
-- =============================================================================

BEGIN;

-- ─── STEP 1: drop the sidebar entry ─────────────────────────────────────────
-- The operative change. HasAccess = false rather than IsDeleted = true, so the
-- platform role matrix still shows the switch in its off position and an admin can
-- turn the second menu back on from the UI without a DBA.

UPDATE auth."RoleCapabilities" rc
   SET "HasAccess"    = false,
       "ModifiedDate" = now()
  FROM auth."Menus" m, auth."Capabilities" c
 WHERE rc."MenuId"       = m."MenuId"
   AND rc."CapabilityId" = c."CapabilityId"
   AND m."MenuCode"      = 'PLATFORM_TENANT_ACCESS'
   AND c."CapabilityCode" = 'ISMENURENDER'
   AND rc."HasAccess" IS DISTINCT FROM false;

-- ─── STEP 2: mark the row hidden for the surfaces that read the flag ────────
-- Belt and braces. IsActive stays TRUE on purpose (see the header) — the route must
-- keep resolving and the matrix row must keep existing.

UPDATE auth."Menus"
   SET "IsVisible"    = false,
       "IsLeastMenu"  = false,
       "ModifiedDate" = now()
 WHERE "MenuCode" = 'PLATFORM_TENANT_ACCESS'
   AND ("IsVisible" IS DISTINCT FROM false OR "IsLeastMenu" IS DISTINCT FROM false);

-- ─── STEP 3: nothing else ───────────────────────────────────────────────────
-- Explicitly NOT done here, and each for a reason:
--   • PLATFORM_TENANT_ACCESS_VIEW / PLATFORM_TENANT_RBAC_OVERRIDE grants — untouched.
--     These ARE the platform-side access control the change is meant to preserve.
--   • The MenuCapabilities pairs — untouched. Removing them would strip the rows from
--     the platform role matrix, i.e. remove the ability to grant the authority at all.
--   • SUPERADMIN — never revoked, never overwritten, per the house rule.
--   • auth."Menus" row for PLATFORM_TENANTS — untouched.

COMMIT;

-- ─── VERIFICATION (run after commit) ─────────────────────────────────────────

-- 1) Expect PLATFORM_TENANTS visible, PLATFORM_TENANT_ACCESS active but not visible:
SELECT m."MenuCode", m."MenuName", m."MenuUrl", m."OrderBy",
       m."IsActive", m."IsVisible", m."IsLeastMenu"
FROM auth."Menus" m
WHERE m."MenuCode" IN ('PLATFORM_TENANTS','PLATFORM_TENANT_ACCESS')
ORDER BY m."OrderBy";

-- 2) Expect 0 rows — no role should still render the second sidebar entry.
--    NOTE: if this returned 0 rows BEFORE the script ran too, then ISMENURENDER was
--    never the mechanism that put this menu in your sidebar. Tell me — the control
--    plane nav would then be coming from somewhere STEP 1 does not reach, and STEP 2
--    alone is not enough.
SELECT r."RoleCode"
FROM auth."RoleCapabilities" rc
JOIN auth."Menus"        m ON m."MenuId"       = rc."MenuId"
JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
JOIN auth."Roles"        r ON r."RoleId"       = rc."RoleId"
WHERE m."MenuCode" = 'PLATFORM_TENANT_ACCESS'
  AND c."CapabilityCode" = 'ISMENURENDER'
  AND rc."HasAccess" = true;

-- 3) THE IMPORTANT ONE — the preserved authority. Expect PLATFORM_ADMIN with both
--    capabilities, PLATFORM_SUPPORT and PLATFORM_IMPLEMENTATION with VIEW, plus
--    SUPERADMIN. If this comes back empty, STOP and run the reversal.
SELECT r."RoleCode", c."CapabilityCode", rc."HasAccess"
FROM auth."RoleCapabilities" rc
JOIN auth."Menus"        m ON m."MenuId"       = rc."MenuId"
JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
JOIN auth."Roles"        r ON r."RoleId"       = rc."RoleId"
WHERE m."MenuCode" = 'PLATFORM_TENANT_ACCESS'
  AND c."CapabilityCode" IN ('PLATFORM_TENANT_ACCESS_VIEW','PLATFORM_TENANT_RBAC_OVERRIDE')
  AND COALESCE(rc."IsDeleted", false) = false
ORDER BY r."RoleCode", c."CapabilityCode";

-- 4) Matrix row survives — expect 2 rows, so the switch is still grantable in the UI:
SELECT c."CapabilityCode"
FROM auth."MenuCapabilities" mc
JOIN auth."Menus"        m ON m."MenuId"       = mc."MenuId"
JOIN auth."Capabilities" c ON c."CapabilityId" = mc."CapabilityId"
WHERE m."MenuCode" = 'PLATFORM_TENANT_ACCESS'
  AND COALESCE(mc."IsDeleted", false) = false
ORDER BY c."CapabilityCode";

-- ─── REVERSAL (bring the second sidebar entry back) ──────────────────────────
--   BEGIN;
--   UPDATE auth."Menus"
--      SET "IsVisible" = true, "IsLeastMenu" = true, "ModifiedDate" = now()
--    WHERE "MenuCode" = 'PLATFORM_TENANT_ACCESS';
--
--   UPDATE auth."RoleCapabilities" rc
--      SET "HasAccess" = true, "ModifiedDate" = now()
--     FROM auth."Menus" m, auth."Capabilities" c
--    WHERE rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
--      AND m."MenuCode" = 'PLATFORM_TENANT_ACCESS'
--      AND c."CapabilityCode" = 'ISMENURENDER';
--   COMMIT;
