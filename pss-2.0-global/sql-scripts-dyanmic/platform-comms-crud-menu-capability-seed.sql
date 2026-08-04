-- =============================================================================
-- PSS 2.0 — PROMPT-09 (T-A15): Platform Communication Providers — menu, RBAC, grid
--
-- Registers the control-plane screen at /platform/communications: the platform's OWN
-- email / SMS / WhatsApp senders (ops."PlatformCommunicationProviders" — no CompanyId).
-- Until this runs, every resolver decorated
--   [CustomAuthorize("PLATFORM_COMMS", "PLATFORM_COMMS_MANAGE")]
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
--                           ISMENURENDER on. A menu with PLATFORM_COMMS but no ISMENURENDER
--                           grant is callable by URL and completely invisible in the nav.
--   auth."MenuCapabilities" is still seeded because it is what the Access Control screen
--   enumerates — omit it and these grants become unmanageable through the UI.
--
-- ISMENURENDER is NEVER inserted here; it is a base-app capability that already exists.
--
-- MenuUrl carries a LEADING SLASH ('/platform/communications') to match the rows the P-03 and
-- P-14 seeds already wrote ('/platform/billing', '/platform/webhook-logs'). PROMPT-09 §⑦ writes
-- it without the slash; the stored convention wins, since the FE matches the stored value.
--
-- sett."Fields" / "GridFields" are deliberately NOT seeded. This is a developer-owned screen
-- (custom list + dialog form) because the write-only credential JSON cannot be expressed by the
-- generic RJSF grid form, so per-field grid metadata would be dead rows. The sett."Grids"
-- header row is still registered per house convention.
--
-- PREREQUISITE: ops-platform-rbac-seed.sql (PLATFORM module + PLATFORMCONTROLPLANE parent) and
-- billing-gateway-platform-seed.sql (PLATFORM_BILLING, the anchor row). Zero rows from the
-- menu VERIFY query means the anchor is missing — run those first, then re-run this.
--
-- SAFE TO RE-RUN. Idempotent throughout; no DDL, no migration, no credential values.
-- =============================================================================

BEGIN;

-- ── 1. Menu — PLATFORM_COMMS ─────────────────────────────────────────────────────────
-- Parent and module are RESOLVED FROM PLATFORM_BILLING rather than hardcoded, so this lands
-- wherever the earlier seeds put the control plane in this environment. Anchored as its
-- sibling, one slot further down.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Communications', 'PLATFORM_COMMS', p."ParentMenuId", 'ph-paper-plane-tilt',
  p."ModuleId",
  '/platform/communications',
  'Platform email, SMS and WhatsApp senders, per-channel defaults and test sends.',
  COALESCE(p."OrderBy", 0) + 2,
  true, 'Internal', true, now(), true, false
FROM auth."Menus" p
WHERE p."MenuCode" = 'PLATFORM_BILLING'
  AND NOT EXISTS (SELECT 1 FROM auth."Menus" m WHERE m."MenuCode" = 'PLATFORM_COMMS');

-- Repair an already-present row (url drift / soft-deleted / demoted to a non-leaf).
-- IsLeastMenu = true is required or the sidebar renders it as a non-clickable group header.
UPDATE auth."Menus"
SET "MenuUrl"      = '/platform/communications',
    "IsLeastMenu"  = true,
    "IsVisible"    = true,
    "IsActive"     = true,
    "IsDeleted"    = false,
    "ModifiedDate" = now()
WHERE "MenuCode" = 'PLATFORM_COMMS'
  AND ("MenuUrl" IS DISTINCT FROM '/platform/communications'
       OR "IsLeastMenu" IS NOT TRUE
       OR "IsVisible"   IS NOT TRUE
       OR "IsActive"    IS NOT TRUE
       OR "IsDeleted"   IS TRUE);

-- ── 2. Capabilities — PLATFORM_COMMS + PLATFORM_COMMS_MANAGE ─────────────────────────
-- The idempotency guard checks CapabilityName, NOT CapabilityCode: auth."Capabilities" carries
-- a UNIQUE index on (CapabilityName, IsActive), so the name is the constrained column.
-- Names are prefixed "Platform " for the same collision reason as the rest of the family.
-- OrderBy continues the series past 101 (PLATFORM_BILLING_MANAGE, P-14).
-- IsSpecial = true: these are not part of the generic READ/CREATE/MODIFY grid family.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Platform View Communications',   'PLATFORM_COMMS',
   'View the platform''s communication providers, their channel defaults and last-used stamps (never credentials).', 102),
  ('Platform Manage Communications', 'PLATFORM_COMMS_MANAGE',
   'Create, edit, delete and set the default platform communication provider, and send test messages.', 103)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 3. MenuCapabilities ──────────────────────────────────────────────────────────────
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'PLATFORM_COMMS'
  AND c."CapabilityCode" IN ('PLATFORM_COMMS','PLATFORM_COMMS_MANAGE','ISMENURENDER')
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- ── 4. Role grants — the platform operator role ONLY ─────────────────────────────────
-- PLATFORM_* roles are GLOBAL (CompanyId IS NULL); the join constrains that.
--
-- Narrower than the gateway seed on purpose. PROMPT-09 §⑧.4 says "the platform operator role
-- only", and this screen is the one place a SendGrid / Twilio credential is entered and a
-- billable test send is fired — so PLATFORM_FINANCE and PLATFORM_SUPPORT get nothing here, not
-- even VIEW. Widen it through the Access Control screen if operations asks; do not widen it by
-- editing this file after it has been applied.
--
-- ISMENURENDER is granted alongside VIEW or the item never appears in the nav.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_ADMIN', 'PLATFORM_COMMS'),
  ('PLATFORM_ADMIN', 'PLATFORM_COMMS_MANAGE'),
  ('PLATFORM_ADMIN', 'ISMENURENDER'),
  ('SUPERADMIN',     'PLATFORM_COMMS'),
  ('SUPERADMIN',     'PLATFORM_COMMS_MANAGE'),
  ('SUPERADMIN',     'ISMENURENDER')
) AS v(role_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
                          AND r."IsDeleted" IS NOT TRUE
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
JOIN auth."Menus"        m ON m."MenuCode" = 'PLATFORM_COMMS'
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- ── 5. Grid registration — sett."Grids" ──────────────────────────────────────────────
-- Header row only (see the note at the top on why Fields/GridFields are omitted).
-- ModuleId resolves from ModuleCode = 'PLATFORM'; GridTypeId from GridTypeCode = 'MASTER_GRID'.
INSERT INTO sett."Grids"
  ("GridName","GridCode","Description","GridTypeId","ModuleId",
   "CreatedDate","IsActive","IsDeleted","GridFormSchema")
SELECT
  'Platform Communication Providers', 'PLATFORMCOMMUNICATIONPROVIDER',
  'Platform-owned email / SMS / WhatsApp senders. Custom screen — no generated form schema.',
  gt."GridTypeId", md."ModuleId",
  now(), true, false, null
FROM sett."GridTypes" gt
CROSS JOIN auth."Modules" md
WHERE gt."GridTypeCode" = 'MASTER_GRID'
  AND md."ModuleCode"   = 'PLATFORM'
  AND NOT EXISTS (
    SELECT 1 FROM sett."Grids" g WHERE g."GridCode" = 'PLATFORMCOMMUNICATIONPROVIDER'
  );

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--
--   -- Menu exists and sits beside PLATFORM_BILLING (expect 2 rows, same parent + module):
--   SELECT "MenuCode","MenuUrl","ParentMenuId","ModuleId","OrderBy","IsLeastMenu","IsVisible"
--   FROM   auth."Menus"
--   WHERE  "MenuCode" IN ('PLATFORM_BILLING','PLATFORM_COMMS')
--   ORDER BY "OrderBy";
--   -- Only PLATFORM_BILLING returned means the anchor lookup found nothing — run
--   -- billing-gateway-platform-seed.sql (and ops-platform-rbac-seed.sql before it), then re-run.
--   -- PLATFORM_COMMS must read /platform/communications with IsLeastMenu = true.
--
--   -- Both capabilities exist (expect 2, IsSpecial true, OrderBy 102/103):
--   SELECT "CapabilityCode","CapabilityName","IsSpecial","OrderBy" FROM auth."Capabilities"
--   WHERE  "CapabilityCode" IN ('PLATFORM_COMMS','PLATFORM_COMMS_MANAGE');
--
--   -- MenuCapabilities registered (expect 3 — VIEW, MANAGE, ISMENURENDER):
--   SELECT c."CapabilityCode"
--   FROM   auth."MenuCapabilities" mc
--   JOIN   auth."Menus" m        ON m."MenuId" = mc."MenuId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = mc."CapabilityId"
--   WHERE  m."MenuCode" = 'PLATFORM_COMMS' ORDER BY c."CapabilityCode";
--
--   -- Who can do what (expect exactly PLATFORM_ADMIN + SUPERADMIN × 3 = 6 rows):
--   SELECT r."RoleCode", c."CapabilityCode"
--   FROM   auth."RoleCapabilities" rc
--   JOIN   auth."Roles" r        ON r."RoleId" = rc."RoleId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--   JOIN   auth."Menus" m        ON m."MenuId" = rc."MenuId"
--   WHERE  m."MenuCode" = 'PLATFORM_COMMS' AND rc."HasAccess"
--   ORDER BY r."RoleCode", c."CapabilityCode";
--   -- A row here for any tenant role (CompanyId IS NOT NULL) is a bug — this surface is
--   -- control-plane only.
--
--   -- Grid registered (expect 1 row, GridTypeCode MASTER_GRID, ModuleCode PLATFORM):
--   SELECT g."GridCode", gt."GridTypeCode", md."ModuleCode", g."IsActive"
--   FROM   sett."Grids" g
--   JOIN   sett."GridTypes" gt ON gt."GridTypeId" = g."GridTypeId"
--   JOIN   auth."Modules" md   ON md."ModuleId"   = g."ModuleId"
--   WHERE  g."GridCode" = 'PLATFORMCOMMUNICATIONPROVIDER';
--
--   -- Confirm NO provider rows were created by this script (expect 0):
--   SELECT count(*) FROM ops."PlatformCommunicationProviders";
--   -- Stays 0 until an operator configures a sender through the UI. Until then platform email
--   -- still falls back to the legacy global appsettings key — which is exactly the condition
--   -- the screen's empty state calls out.
-- =====================================================================================
