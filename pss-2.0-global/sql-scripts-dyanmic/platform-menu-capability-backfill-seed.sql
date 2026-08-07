-- =====================================================================================
--  P-24 — auth."MenuCapabilities" backfill for the PLATFORM module
--
--  SYMPTOM
--    The platform role matrix (/platform/staff → "Platform Roles") renders only two rows —
--    "Billing & Gateways" and "Communications". Leads, Tenants, Plans, Audit, Staff & Access
--    and Tenant Access Control are all missing, even though roles demonstrably HOLD those
--    capabilities and the corresponding screens work.
--
--  CAUSE
--    PlatformRoleMatrixBuilder builds its ROWS from auth."MenuCapabilities" — a menu with zero
--    MenuCapability rows is skipped outright (`if (caps.Count == 0) continue;`). Authorization,
--    by contrast, reads auth."RoleCapabilities" and never consults MenuCapabilities at all.
--
--    So the two tables drifted. ops-platform-rbac-seed.sql created the PLATFORM menus, the
--    capabilities and the RoleCapabilities grants, but never wrote a single MenuCapability —
--    it did not need to, because nothing enforced against it. The later seeds
--    (billing-capability-seed, billing-gateway-platform-seed, platform-comms-crud-menu-capability-seed,
--    notification-broadcast-capability-seed) DID write them. Those are exactly the menus that show.
--
--    A capability can therefore be enforced but not GRANTED through the UI — which is the worse
--    half of the failure, because the matrix is now the only place platform access is administered.
--
--  WHAT THIS DOES
--    §1 derives the missing (MenuId, CapabilityId) pairs from the grants that already exist, and
--    §2 adds the pairs that no role holds yet (a capability nobody has been granted still has to
--    appear as a column, or it can never be granted). §3 repairs rows whose IsDeleted/IsActive is
--    NULL rather than false/true — the builder tests `mc.IsDeleted == false`, so a NULL there is
--    invisible in exactly the same way a missing row is.
--
--    Derivation over a hand-typed list is deliberate: the pair set stays correct as capabilities
--    are added, and it cannot invent a pairing that contradicts what is already granted.
--
--  WHAT THIS DOES NOT DO
--    It grants nothing. Not one auth."RoleCapabilities" row is written, updated or deleted, so no
--    role gains or loses a single capability. MenuCapabilities describes which capabilities a menu
--    OFFERS; RoleCapabilities decides who HAS them. This script only makes the offer visible.
--
--  ORDER — run AFTER ops-platform-rbac-seed.sql and platform-tenant-access-menu-seed.sql.
--  Re-runnable: every statement is NOT EXISTS-guarded or narrowed to the wrong value.
-- =====================================================================================

BEGIN;

-- ── 1. Derived — every (menu, capability) pair some platform role already holds ───────
-- Source is the grants themselves. If a role has been granted PLATFORM_LEAD_EXPORT on the
-- PLATFORM_LEADS menu, then by construction that menu offers that capability, and the matrix
-- should have been able to show the cell all along.
--
-- Scoped to menus under the PLATFORM module so this can never touch a tenant menu. HasAccess is
-- NOT filtered: a grant explicitly set to false is still evidence the pair is meaningful, and it
-- is precisely the cell an admin needs to see in order to flip it on.
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT DISTINCT rc."MenuId", rc."CapabilityId", now(), true, false
FROM auth."RoleCapabilities" rc
JOIN auth."Menus"        m  ON m."MenuId"    = rc."MenuId"
JOIN auth."Modules"      md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'PLATFORM'
JOIN auth."Capabilities" c  ON c."CapabilityId" = rc."CapabilityId"
WHERE COALESCE(rc."IsDeleted", false) = false
  AND COALESCE(m."IsDeleted",  false) = false
  AND COALESCE(c."IsDeleted",  false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = rc."MenuId" AND mc."CapabilityId" = rc."CapabilityId"
  );

-- ── 2. Declared — pairs that exist by design but that no role holds yet ──────────────
-- §1 can only discover a pair from a grant. A capability that was seeded and then never granted
-- to anybody — the usual state of a newly-added authority — leaves no trace to derive from, and
-- would stay permanently ungrantable: absent from the matrix, so absent from the only UI that
-- could grant it. This is the ownership map, stated once.
--
-- Menus deliberately absent: PLATFORMCONTROLPLANE (a container, it renders nothing and enforces
-- nothing) and PLATFORM_TENANT_ACCESS / PLATFORM_STAFF (platform-tenant-access-menu-seed.sql §3
-- and §4 own those pairs; duplicating them here would be a second source of truth).
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM (VALUES
  ('PLATFORM_LEADS',    'PLATFORM_LEAD_VIEW'),
  ('PLATFORM_LEADS',    'PLATFORM_LEAD_EDIT'),
  ('PLATFORM_LEADS',    'PLATFORM_LEAD_EXPORT'),
  ('PLATFORM_LEADS',    'PLATFORM_LEAD_ASSIGN'),
  ('PLATFORM_LEADS',    'PLATFORM_DEAL_APPROVE'),
  ('PLATFORM_TENANTS',  'PLATFORM_TENANT_VIEW'),
  ('PLATFORM_TENANTS',  'PLATFORM_TENANT_PROVISION'),
  ('PLATFORM_TENANTS',  'PLATFORM_TENANT_SUSPEND'),
  ('PLATFORM_TENANTS',  'PLATFORM_IMPERSONATE'),
  ('PLATFORM_PLANS',    'PLATFORM_PLAN_VIEW'),
  ('PLATFORM_PLANS',    'PLATFORM_PLAN_EDIT'),
  ('PLATFORM_AUDIT',    'PLATFORM_AUDIT_VIEW')
) AS v(menu_code, cap_code)
JOIN auth."Menus"        m ON m."MenuCode"       = v.menu_code
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
WHERE COALESCE(m."IsDeleted", false) = false
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- ── 3. Repair — NULL IsDeleted / IsActive on existing PLATFORM MenuCapabilities ──────
-- The builder's filter is `mc.IsDeleted == false`, not `!= true`. A row seeded without those
-- columns lands NULL and is dropped as silently as a row that was never written — same symptom,
-- different cause, so fix it here rather than leave a second way for a menu to vanish.
--
-- Narrowed to NULL only. A row deliberately marked deleted stays deleted.
UPDATE auth."MenuCapabilities" mc
   SET "IsDeleted" = COALESCE(mc."IsDeleted", false),
       "IsActive"  = COALESCE(mc."IsActive",  true),
       "ModifiedDate" = now()
  FROM auth."Menus"   m
  JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'PLATFORM'
 WHERE mc."MenuId" = m."MenuId"
   AND (mc."IsDeleted" IS NULL OR mc."IsActive" IS NULL);

-- ── 4. Repair — NULL IsActive on the PLATFORM menus themselves ───────────────────────
-- Same class of defect one level up: the builder also requires `m.IsActive == true`, so a menu
-- row with a NULL IsActive is skipped before its capabilities are even looked at.
UPDATE auth."Menus" m
   SET "IsActive" = true,
       "ModifiedDate" = now()
  FROM auth."Modules" md
 WHERE md."ModuleId" = m."ModuleId"
   AND md."ModuleCode" = 'PLATFORM'
   AND m."IsActive" IS NULL
   AND COALESCE(m."IsDeleted", false) = false;

COMMIT;

-- =====================================================================================
--  VERIFY (run after COMMIT)
-- =====================================================================================
--
-- 1. Every PLATFORM menu that should be a matrix row now has ≥1 live MenuCapability.
--    Expect a non-zero cap_count on LEADS, TENANTS, PLANS, AUDIT, STAFF, TENANT_ACCESS,
--    BILLING, WEBHOOK_LOGS, COMMS, NOTIFICATIONS. PLATFORMCONTROLPLANE staying at 0 is correct —
--    it is the container, and the builder is meant to skip it:
--
--    SELECT m."MenuCode", m."MenuName", m."OrderBy", m."IsActive",
--           count(mc."MenuCapabilityId") FILTER (
--             WHERE mc."IsDeleted" = false AND mc."IsActive" = true) AS cap_count
--      FROM auth."Menus"   m
--      JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'PLATFORM'
--      LEFT JOIN auth."MenuCapabilities" mc ON mc."MenuId" = m."MenuId"
--     WHERE COALESCE(m."IsDeleted", false) = false
--     GROUP BY m."MenuCode", m."MenuName", m."OrderBy", m."IsActive"
--     ORDER BY m."OrderBy";
--
-- 2. The defect itself, restated as a query — a granted capability with no matching
--    MenuCapability row. MUST return zero rows. Anything here is a cell the matrix cannot draw,
--    which means a capability that can be enforced but not administered:
--
--    SELECT r."RoleCode", m."MenuCode", c."CapabilityCode"
--      FROM auth."RoleCapabilities" rc
--      JOIN auth."Roles"        r  ON r."RoleId"     = rc."RoleId"
--      JOIN auth."Menus"        m  ON m."MenuId"     = rc."MenuId"
--      JOIN auth."Modules"      md ON md."ModuleId"  = m."ModuleId" AND md."ModuleCode" = 'PLATFORM'
--      JOIN auth."Capabilities" c  ON c."CapabilityId" = rc."CapabilityId"
--     WHERE COALESCE(rc."IsDeleted", false) = false
--       AND NOT EXISTS (
--         SELECT 1 FROM auth."MenuCapabilities" mc
--         WHERE mc."MenuId" = rc."MenuId" AND mc."CapabilityId" = rc."CapabilityId"
--           AND mc."IsDeleted" = false)
--     ORDER BY 1, 2, 3;
--
-- 3. Nothing was granted. Run this BEFORE and AFTER; the two counts must be identical:
--
--    SELECT count(*) FROM auth."RoleCapabilities" WHERE "HasAccess" = true;
--
-- 4. No duplicate pairs (the table has no unique constraint, so a bad re-run would show up here).
--    MUST return zero rows:
--
--    SELECT "MenuId","CapabilityId", count(*)
--      FROM auth."MenuCapabilities"
--     WHERE COALESCE("IsDeleted", false) = false
--     GROUP BY 1,2 HAVING count(*) > 1;
