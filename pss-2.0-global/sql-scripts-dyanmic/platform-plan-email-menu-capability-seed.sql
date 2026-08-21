-- =============================================================================
-- PSS 2.0 — #179: Plan Email Provider Setting — menu, RBAC, grid
--
-- Registers the control-plane screen at /platform/communications/plan-email: the
-- tenant/plan email-account ASSIGNMENT workbench (which of our own
-- ops."PlatformCommunicationProviders" (Channel='EMAIL') rows a given tenant or plan
-- tier sends through) and the tenant domain-verification request queue.
-- Until this runs, every resolver decorated
--   [CustomAuthorize("PLATFORM_PLAN_EMAIL", "PLATFORM_PLAN_EMAIL_MANAGE")]
-- returns unauthorized for everyone, because HasAccessAsync matches on MenuCode and no
-- grant can exist without the menu row.
--
-- SCHEMA NOTE — do NOT qualify these with `app`:
--   auth."Modules" / "Menus" / "Capabilities" / "MenuCapabilities" / "Roles" / "RoleCapabilities"
--   sett."Grids" / "GridTypes"
--
-- TWO SEPARATE CHECKS, BOTH REQUIRED:
--   1. API authorization  — auth."RoleCapabilities" joining Role → Menu(MenuCode) → Capability.
--                           auth."MenuCapabilities" is NOT consulted by HasAccessAsync.
--   2. Sidebar rendering  — GetParentChildMenuHandler builds the nav from menus the user holds
--                           ISMENURENDER on. A menu with PLATFORM_PLAN_EMAIL but no ISMENURENDER
--                           grant is callable by URL and completely invisible in the nav.
--   auth."MenuCapabilities" is still seeded because it is what the Access Control screen
--   enumerates — omit it and these grants become unmanageable through the UI.
--
-- ISMENURENDER is NEVER inserted here; it is a base-app capability that already exists.
--
-- MenuUrl carries a LEADING SLASH ('/platform/communications/plan-email') per §⑦ of the
-- #179 prompt and matches the stored convention every prior PLATFORM_* seed uses.
--
-- sett."Fields" / "GridFields" are deliberately NOT seeded — §⑤ classifies this a FLOW
-- screen with developer-owned tab components (card grid + AdvancedDataTable + inbox),
-- not the generic RJSF grid form. The sett."Grids" header row is still registered per
-- house convention.
--
-- ROLE GRANTS — PLATFORM SIDE ONLY. This is a control-plane workbench; tenant-side roles
-- (BUSINESSADMIN and every other CompanyId-scoped role) must NEVER see it. Tenants raise
-- their domain-verification requests from #84 (their own screen) — they do not review them
-- here. Granted to SUPERADMIN only (CompanyId IS NULL); further platform roles are applied
-- manually by the platform owner afterwards.
--
-- PREREQUISITE: platform-comms-crud-menu-capability-seed.sql (PLATFORM_COMMS, the anchor
-- row). Zero rows from the menu VERIFY query means the anchor is missing — run that first,
-- then re-run this.
--
-- SAFE TO RE-RUN. Idempotent throughout; no DDL, no migration, no credential values.
-- =============================================================================

BEGIN;

-- ── 1. Menu — PLATFORM_PLAN_EMAIL ────────────────────────────────────────────────────
-- Parent and module are RESOLVED FROM PLATFORM_COMMS rather than hardcoded, so this lands
-- as PLATFORM_COMMS's sibling wherever the earlier seed put the control plane in this
-- environment. Anchored one slot further down (PLATFORM_COMMS.OrderBy + 1).
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Plan Email Provider', 'PLATFORM_PLAN_EMAIL', p."ParentMenuId", 'ph-envelope-simple',
  p."ModuleId",
  '/platform/communications/plan-email',
  'Assign platform email accounts to tenants and plan tiers, and review tenant domain/from-email verification requests.',
  COALESCE(p."OrderBy", 0) + 1,
  true, 'Internal', true, now(), true, false
FROM auth."Menus" p
WHERE p."MenuCode" = 'PLATFORM_COMMS'
  AND NOT EXISTS (SELECT 1 FROM auth."Menus" m WHERE m."MenuCode" = 'PLATFORM_PLAN_EMAIL');

-- Repair an already-present row (url drift / soft-deleted / demoted to a non-leaf).
-- IsLeastMenu = true is required or the sidebar renders it as a non-clickable group header.
UPDATE auth."Menus"
SET "MenuUrl"      = '/platform/communications/plan-email',
    "IsLeastMenu"  = true,
    "IsVisible"    = true,
    "IsActive"     = true,
    "IsDeleted"    = false,
    "ModifiedDate" = now()
WHERE "MenuCode" = 'PLATFORM_PLAN_EMAIL'
  AND ("MenuUrl" IS DISTINCT FROM '/platform/communications/plan-email'
       OR "IsLeastMenu" IS NOT TRUE
       OR "IsVisible"   IS NOT TRUE
       OR "IsActive"    IS NOT TRUE
       OR "IsDeleted"   IS TRUE);

-- ── 2. Capabilities — PLATFORM_PLAN_EMAIL + PLATFORM_PLAN_EMAIL_MANAGE ───────────────
-- The idempotency guard checks CapabilityName, NOT CapabilityCode: auth."Capabilities" carries
-- a UNIQUE index on (CapabilityName, IsActive), so the name is the constrained column.
-- Names are prefixed "Platform " for the same collision reason as the rest of the family.
-- OrderBy continues the series past 103 (PLATFORM_COMMS_MANAGE).
-- IsSpecial = true: these are not part of the generic READ/CREATE/MODIFY grid family.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Platform View Plan Email Provider',   'PLATFORM_PLAN_EMAIL',
   'View platform email account assignments per tenant/plan and the tenant domain verification queue (never credentials).', 104),
  ('Platform Manage Plan Email Provider', 'PLATFORM_PLAN_EMAIL_MANAGE',
   'Assign/reassign platform email accounts to tenants and plans, and issue/approve/reject tenant domain verification requests.', 105)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 3. MenuCapabilities ──────────────────────────────────────────────────────────────
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'PLATFORM_PLAN_EMAIL'
  AND c."CapabilityCode" IN ('PLATFORM_PLAN_EMAIL','PLATFORM_PLAN_EMAIL_MANAGE','ISMENURENDER')
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- ── 4. Role grants — SUPERADMIN only ─────────────────────────────────────────────────
-- GLOBAL role only (CompanyId IS NULL). No tenant-scoped role is granted: a tenant admin
-- raises domain-verification requests on #84 and must not reach this control-plane queue.
-- Additional platform roles are granted manually by the platform owner later.
--
-- ISMENURENDER is granted alongside VIEW for every granted role, or the item never
-- appears in that role's nav.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM auth."Roles" r
CROSS JOIN auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'PLATFORM_PLAN_EMAIL'
  AND c."CapabilityCode" IN ('PLATFORM_PLAN_EMAIL','PLATFORM_PLAN_EMAIL_MANAGE','ISMENURENDER')
  AND r."IsDeleted" IS NOT TRUE
  AND (
        r."RoleCode" = 'SUPERADMIN' AND r."CompanyId" IS NULL
  )
  AND NOT EXISTS (
    SELECT 1 FROM auth."RoleCapabilities" rc
    WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
  );

-- ── 5. Grid registration — sett."Grids" ──────────────────────────────────────────────
-- Header row only (see the note at the top on why Fields/GridFields are omitted).
-- ModuleId resolves from PLATFORM_PLAN_EMAIL's own menu row (already resolved from
-- PLATFORM_COMMS above); GridTypeId from GridTypeCode = 'MASTER_GRID' per house convention
-- for the header row, even though the tabs themselves are custom components.
INSERT INTO sett."Grids"
  ("GridName","GridCode","Description","GridTypeId","ModuleId",
   "CreatedDate","IsActive","IsDeleted","GridFormSchema")
SELECT
  'Plan Email Provider', 'PLATFORMPLANEMAILPROVIDER',
  'Platform email account assignment per tenant/plan and tenant domain verification queue. Custom tabbed screen — no generated form schema.',
  gt."GridTypeId", m."ModuleId",
  now(), true, false, null
FROM sett."GridTypes" gt
CROSS JOIN auth."Menus" m
WHERE gt."GridTypeCode" = 'MASTER_GRID'
  AND m."MenuCode"      = 'PLATFORM_PLAN_EMAIL'
  AND NOT EXISTS (
    SELECT 1 FROM sett."Grids" g WHERE g."GridCode" = 'PLATFORMPLANEMAILPROVIDER'
  );

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--
--   -- Menu exists and sits beside PLATFORM_COMMS (expect 2 rows, same parent + module):
--   SELECT "MenuCode","MenuUrl","ParentMenuId","ModuleId","OrderBy","IsLeastMenu","IsVisible"
--   FROM   auth."Menus"
--   WHERE  "MenuCode" IN ('PLATFORM_COMMS','PLATFORM_PLAN_EMAIL')
--   ORDER BY "OrderBy";
--   -- Only PLATFORM_COMMS returned means the anchor lookup found nothing — run
--   -- platform-comms-crud-menu-capability-seed.sql first, then re-run this.
--   -- PLATFORM_PLAN_EMAIL must read /platform/communications/plan-email with IsLeastMenu = true.
--
--   -- Both capabilities exist (expect 2, IsSpecial true, OrderBy 104/105):
--   SELECT "CapabilityCode","CapabilityName","IsSpecial","OrderBy" FROM auth."Capabilities"
--   WHERE  "CapabilityCode" IN ('PLATFORM_PLAN_EMAIL','PLATFORM_PLAN_EMAIL_MANAGE');
--
--   -- MenuCapabilities registered (expect 3 — VIEW, MANAGE, ISMENURENDER):
--   SELECT c."CapabilityCode"
--   FROM   auth."MenuCapabilities" mc
--   JOIN   auth."Menus" m        ON m."MenuId" = mc."MenuId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = mc."CapabilityId"
--   WHERE  m."MenuCode" = 'PLATFORM_PLAN_EMAIL' ORDER BY c."CapabilityCode";
--
--   -- Who can do what (expect exactly 3 rows: SUPERADMIN x VIEW/MANAGE/ISMENURENDER):
--   SELECT r."RoleCode", r."CompanyId", c."CapabilityCode"
--   FROM   auth."RoleCapabilities" rc
--   JOIN   auth."Roles" r        ON r."RoleId" = rc."RoleId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--   JOIN   auth."Menus" m        ON m."MenuId" = rc."MenuId"
--   WHERE  m."MenuCode" = 'PLATFORM_PLAN_EMAIL' AND rc."HasAccess"
--   ORDER BY r."RoleCode", r."CompanyId", c."CapabilityCode";
--   -- A row here for any role other than SUPERADMIN, or with a non-null CompanyId, is a bug.
--
--   -- Grid registered (expect 1 row, GridTypeCode MASTER_GRID):
--   SELECT g."GridCode", gt."GridTypeCode", g."IsActive"
--   FROM   sett."Grids" g
--   JOIN   sett."GridTypes" gt ON gt."GridTypeId" = g."GridTypeId"
--   WHERE  g."GridCode" = 'PLATFORMPLANEMAILPROVIDER';
-- =====================================================================================
