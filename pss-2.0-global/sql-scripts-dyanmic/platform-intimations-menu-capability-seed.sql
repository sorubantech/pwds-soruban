-- =============================================================================
-- PSS 2.0 — PHASE-6 (F-7.11): Tenant Intimations — menu, RBAC, grid registration
--
-- Registers the control-plane screen at /ops/intimations: the platform's list of notices
-- addressed to TENANTS (notify."Intimations" — one row per tenant per condition), plus the
-- manual "post a notice" dialog.
--
-- INV-10 restated, because it is the reason this screen looks the way it does: an intimation is
-- addressed to a COMPANY, never to a user in another address space. Nothing seeded here grants
-- anyone visibility of a tenant's users; the capabilities below only reach the intimation rows
-- themselves. Who inside the tenant sees the banner is decided tenant-side.
--
-- SCHEMA NOTE — do NOT qualify these with `app`:
--   auth."Modules" / "Menus" / "Capabilities" / "MenuCapabilities" / "Roles" / "RoleCapabilities"
--   sett."Grids" / "GridTypes"
--
-- TWO SEPARATE CHECKS, BOTH REQUIRED:
--   1. API authorization  — auth."RoleCapabilities" joining Role → Menu(MenuCode) → Capability.
--                           auth."MenuCapabilities" is NOT consulted by HasAccessAsync.
--   2. Sidebar rendering  — GetParentChildMenuHandler builds the nav from menus the user holds
--                           ISMENURENDER on. A menu with PLATFORM_INTIMATIONS but no ISMENURENDER
--                           grant is callable by URL and completely invisible in the nav.
--   auth."MenuCapabilities" is still seeded because it is what the platform role matrix
--   enumerates — omit it and these grants become unmanageable through the UI.
--
-- ISMENURENDER is NEVER inserted here; it is a base-app capability that already exists.
--
-- MenuUrl is '/ops/intimations', with a LEADING SLASH, matching the Next.js route at
-- app/[lang]/(master)/ops/intimations and the sibling ops rows ('/ops/notifications',
-- '/ops/data-cleanup', '/ops/tenant-access'). It must not be shared with another menu: MenuUrl is
-- how the nav builder and the sidebar active-state matcher identify a row.
--
-- sett."Fields" / "GridFields" are deliberately NOT seeded. This is a developer-owned screen
-- (bespoke list + create dialog, like every other (master)/ops surface), so per-field grid
-- metadata would be dead rows. The sett."Grids" header row is still registered per house
-- convention.
--
-- PREREQUISITE: ops-platform-rbac-seed.sql (PLATFORM module + PLATFORMCONTROLPLANE parent).
-- Zero rows from the menu VERIFY query means the parent or module lookup found nothing — run
-- that first, then re-run this.
--
-- ALSO REQUIRED, separately: the notify."Intimations" / notify."IntimationDismissals" tables come
-- from an EF migration, not from this file. This script contains no DDL.
--
-- SAFE TO RE-RUN. Idempotent throughout; no DDL, no migration, no intimation rows.
-- =============================================================================

BEGIN;

-- ── 1. Menu — PLATFORM_INTIMATIONS ───────────────────────────────────────────────────
-- Parent and module are RESOLVED by code rather than hardcoded, so this lands wherever the
-- earlier seeds put the control plane in this environment. OrderBy 965 puts it after Data
-- Cleanup (960) and Tenant Access (955), continuing the ops run that starts at Notifications
-- (950) — a granter looking for it in the platform role matrix will find it beside its family.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Tenant Notices', 'PLATFORM_INTIMATIONS',
  (SELECT p."MenuId" FROM auth."Menus" p WHERE p."MenuCode" = 'PLATFORMCONTROLPLANE'),
  'ph-megaphone',
  (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'PLATFORM'),
  '/ops/intimations',
  'Notices raised against a tenant — detector-raised conditions and manually posted announcements — with resolve and expire.',
  965,
  true, 'Internal', true, now(), true, false
WHERE NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = 'PLATFORM_INTIMATIONS');

-- Repair an already-present row (url drift / soft-deleted / demoted to a non-leaf).
-- IsLeastMenu = true is required or the sidebar renders it as a non-clickable group header.
-- Guarded on the wrong values, so this is a no-op once the row is correct.
UPDATE auth."Menus"
   SET "MenuUrl"      = '/ops/intimations',
       "IsLeastMenu"  = true,
       "IsVisible"    = true,
       "IsActive"     = true,
       "IsDeleted"    = false,
       "ModifiedDate" = now()
 WHERE "MenuCode" = 'PLATFORM_INTIMATIONS'
   AND ("MenuUrl" IS DISTINCT FROM '/ops/intimations'
        OR "IsLeastMenu" IS NOT TRUE
        OR "IsVisible"   IS NOT TRUE
        OR "IsActive"    IS NOT TRUE
        OR "IsDeleted"   IS TRUE);

-- ── 2. Capabilities — PLATFORM_INTIMATIONS + PLATFORM_INTIMATIONS_MANAGE ─────────────
-- The idempotency guard checks CapabilityName, NOT CapabilityCode: auth."Capabilities" carries
-- a UNIQUE index on (CapabilityName, IsActive), so the name is the constrained column. Names are
-- prefixed "Platform " for the same collision reason as the rest of the family.
-- OrderBy continues the platform run past 106 (PLATFORM_DATA_PURGE_HARD).
-- IsSpecial = true: neither is part of the generic READ/CREATE/MODIFY grid family.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Platform View Tenant Notices',   'PLATFORM_INTIMATIONS',
   'View the notices raised against tenants — condition, severity, when it was raised and how many users dismissed it. Read-only; grants no access to tenant data or tenant users.', 107),
  ('Platform Manage Tenant Notices', 'PLATFORM_INTIMATIONS_MANAGE',
   'Post a manual notice to a tenant, and resolve or expire an open one. A detector-raised notice resolved by hand is re-raised by the nightly sweep while its condition still holds.', 108)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 3. MenuCapabilities ──────────────────────────────────────────────────────────────
-- PlatformRoleMatrixBuilder builds its ROWS from menus that have >= 1 MenuCapability and skips
-- any menu whose capability list is empty. Without this block the menu exists and the backend
-- enforces the capabilities, but nobody could ever grant them through the UI.
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'PLATFORM_INTIMATIONS'
  AND c."CapabilityCode" IN ('PLATFORM_INTIMATIONS','PLATFORM_INTIMATIONS_MANAGE','ISMENURENDER')
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- ── 4. Role grants — platform operator roles only ────────────────────────────────────
-- PLATFORM_* roles are GLOBAL (CompanyId IS NULL); the join constrains that. A row here for any
-- tenant role would be a bug — this surface is control-plane only, and a tenant seeing the list
-- of notices raised against OTHER tenants is precisely the leak INV-10 exists to prevent.
--
-- ISMENURENDER is granted alongside VIEW or the item never appears in the nav.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_ADMIN', 'PLATFORM_INTIMATIONS'),
  ('PLATFORM_ADMIN', 'PLATFORM_INTIMATIONS_MANAGE'),
  ('PLATFORM_ADMIN', 'ISMENURENDER'),
  ('SUPERADMIN',     'PLATFORM_INTIMATIONS'),
  ('SUPERADMIN',     'PLATFORM_INTIMATIONS_MANAGE'),
  ('SUPERADMIN',     'ISMENURENDER')
) AS v(role_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
                          AND r."IsDeleted" IS NOT TRUE
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
JOIN auth."Menus"        m ON m."MenuCode" = 'PLATFORM_INTIMATIONS'
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- PLATFORM_SUPPORT deliberately gets nothing here, not even VIEW. Support already reads a
-- tenant's health from the tenant page; the notice list is where announcements are composed, and
-- posting to a tenant is an act with the platform's name on it. Widen this through the Access
-- Control screen if operations asks — do not widen it by editing this file after it is applied.

-- ── 5. Grid registration — sett."Grids" ──────────────────────────────────────────────
-- Header row only (see the note at the top on why Fields/GridFields are omitted).
-- ModuleId resolves from ModuleCode = 'PLATFORM'; GridTypeId from GridTypeCode = 'MASTER_GRID'.
INSERT INTO sett."Grids"
  ("GridName","GridCode","Description","GridTypeId","ModuleId",
   "CreatedDate","IsActive","IsDeleted","GridFormSchema")
SELECT
  'Tenant Intimations', 'PLATFORMINTIMATION',
  'Notices raised against tenants. Custom screen — no generated form schema.',
  gt."GridTypeId", md."ModuleId",
  now(), true, false, null
FROM sett."GridTypes" gt
CROSS JOIN auth."Modules" md
WHERE gt."GridTypeCode" = 'MASTER_GRID'
  AND md."ModuleCode"   = 'PLATFORM'
  AND NOT EXISTS (
    SELECT 1 FROM sett."Grids" g WHERE g."GridCode" = 'PLATFORMINTIMATION'
  );

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--
--   -- Menu exists as a leaf under the control-plane root (expect 1 row):
--   SELECT "MenuCode","MenuUrl","ParentMenuId","ModuleId","OrderBy","IsLeastMenu","IsVisible"
--   FROM   auth."Menus" WHERE "MenuCode" = 'PLATFORM_INTIMATIONS';
--   -- Zero rows means the PLATFORMCONTROLPLANE parent or the PLATFORM module is missing —
--   -- run ops-platform-rbac-seed.sql, then re-run this.
--   -- MenuUrl must read /ops/intimations with IsLeastMenu = true.
--
--   -- No other menu claims the same path (expect exactly 1 row):
--   SELECT "MenuCode" FROM auth."Menus"
--   WHERE  "MenuUrl" = '/ops/intimations' AND COALESCE("IsDeleted", false) = false;
--
--   -- Both capabilities exist (expect 2, IsSpecial true, OrderBy 107/108):
--   SELECT "CapabilityCode","CapabilityName","IsSpecial","OrderBy" FROM auth."Capabilities"
--   WHERE  "CapabilityCode" IN ('PLATFORM_INTIMATIONS','PLATFORM_INTIMATIONS_MANAGE');
--
--   -- MenuCapabilities registered (expect 3 — VIEW, MANAGE, ISMENURENDER):
--   SELECT c."CapabilityCode"
--   FROM   auth."MenuCapabilities" mc
--   JOIN   auth."Menus" m        ON m."MenuId" = mc."MenuId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = mc."CapabilityId"
--   WHERE  m."MenuCode" = 'PLATFORM_INTIMATIONS' ORDER BY c."CapabilityCode";
--
--   -- Who can do what (expect exactly PLATFORM_ADMIN + SUPERADMIN x 3 = 6 rows):
--   SELECT r."RoleCode", c."CapabilityCode", r."CompanyId"
--   FROM   auth."RoleCapabilities" rc
--   JOIN   auth."Roles" r        ON r."RoleId" = rc."RoleId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--   JOIN   auth."Menus" m        ON m."MenuId" = rc."MenuId"
--   WHERE  m."MenuCode" = 'PLATFORM_INTIMATIONS' AND rc."HasAccess"
--   ORDER BY r."RoleCode", c."CapabilityCode";
--   -- Any row with CompanyId IS NOT NULL is a bug — see the note in section 4.
--
--   -- Grid registered (expect 1 row, GridTypeCode MASTER_GRID, ModuleCode PLATFORM):
--   SELECT g."GridCode", gt."GridTypeCode", md."ModuleCode", g."IsActive"
--   FROM   sett."Grids" g
--   JOIN   sett."GridTypes" gt ON gt."GridTypeId" = g."GridTypeId"
--   JOIN   auth."Modules" md   ON md."ModuleId"   = g."ModuleId"
--   WHERE  g."GridCode" = 'PLATFORMINTIMATION';
--
--   -- Confirm NO intimation rows were created by this script (expect 0):
--   SELECT count(*) FROM notify."Intimations";
--   -- This errors with "relation does not exist" until the EF migration for
--   -- notify."Intimations" / notify."IntimationDismissals" has been applied. That migration is a
--   -- separate, developer-created step — this script never creates tables.
-- =====================================================================================
