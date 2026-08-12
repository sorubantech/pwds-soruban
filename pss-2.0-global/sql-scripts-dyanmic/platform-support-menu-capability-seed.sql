-- =====================================================================================
-- P-6 — Platform Support inbox: menu, capabilities and grants
-- -------------------------------------------------------------------------------------
-- Companion to ops-platform-rbac-seed.sql. Adds the RBAC surface for (master)/ops/support,
-- the platform side of the T-9 tenant feedback loop (D-2).
--
--   1. auth."Menus"            — 1 new leaf: PLATFORM_SUPPORTDESK -> /ops/support
--   2. auth."Capabilities"     — 2 new: PLATFORM_SUPPORTDESK_VIEW / _MANAGE
--   3. auth."MenuCapabilities" — the 3 pairs the role matrix enumerates (incl. ISMENURENDER)
--   4. auth."RoleCapabilities" — grants to PLATFORM_ADMIN, PLATFORM_SUPPORT, SUPERADMIN
--
-- ⚠ WHY A NEW MENU AND NOT 'PLATFORM_SUPPORT': that code is already taken — by a ROLE
--   (ops-platform-rbac-seed.sql §4). Menus and roles live in different tables, but reusing
--   the string across both makes every grant tuple ambiguous to read and one careless join
--   away from wrong. The menu is PLATFORM_SUPPORTDESK; 'PLATFORM_SUPPORT' appears in this
--   file ONLY in the role-code position.
--
-- ⚠ PLATFORM_AUDIT (P-3) needs nothing from this script. Its menu and its view capability were
--   seeded by ops-platform-rbac-seed.sql and are already granted; P-3 only replaces the
--   placeholder page behind them. Deliberately not touched here — re-seeding an existing
--   MenuCode is how join keys get broken.
--
-- ⚠ PREREQUISITE — ops-platform-rbac-seed.sql must already be applied (PLATFORM module,
--   PLATFORMCONTROLPLANE root menu, the 5 PLATFORM_* roles). The guard block below raises
--   rather than half-seeding.
--
-- ⚠ PREREQUISITE — the EF migration creating ops."SupportTicket" / ops."SupportTicketNote"
--   should be applied first. This script never creates a table and does not depend on those
--   two existing, but the screen it unlocks 500s without them.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on the natural code key; the single
-- UPDATE is a guarded repair that is a no-op once the row is correct. Re-running changes nothing.
-- SAFE: additive only. No DROP, no DELETE, no schema change. ISMENURENDER is a base-app
-- capability — it is MATCHED and GRANTED here, never inserted.
--
-- RESTART THE API after applying — menu and capability caches are process-scoped.
-- =====================================================================================

BEGIN;

-- ── 0. Guards — fail loudly rather than half-seeding ─────────────────────────────────
DO $$
DECLARE
  v_root_menu int;
  v_module    int;
BEGIN
  SELECT count(*) INTO v_root_menu
  FROM auth."Menus" WHERE "MenuCode" = 'PLATFORMCONTROLPLANE';

  IF v_root_menu = 0 THEN
    RAISE EXCEPTION
      'Menu PLATFORMCONTROLPLANE not found. Apply ops-platform-rbac-seed.sql first.';
  END IF;

  SELECT count(*) INTO v_module
  FROM auth."Modules" WHERE "ModuleCode" = 'PLATFORM';

  IF v_module = 0 THEN
    RAISE EXCEPTION
      'Module PLATFORM not found. Apply ops-platform-rbac-seed.sql first.';
  END IF;
END $$;

-- ── 1. Menu — PLATFORM_SUPPORTDESK leaf under the control-plane root ─────────────────
-- MenuUrl matches the FE route (master)/ops/support/page.tsx. OrderBy 970 continues the ops
-- run past Tenant Notices (965) and Data Cleanup (960) — support sits at the end of the
-- operator's list because it is where the day ends, not where it starts.
-- ParentMenuId + ModuleId resolved from codes, never hardcoded (the FK-safety lesson).
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Support', 'PLATFORM_SUPPORTDESK',
  (SELECT p."MenuId" FROM auth."Menus" p WHERE p."MenuCode" = 'PLATFORMCONTROLPLANE'),
  'ph-lifebuoy',
  (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'PLATFORM'),
  '/ops/support',
  'Bugs, ideas and questions sent in by tenants from the in-product feedback widget.',
  970,
  true, 'Internal', true, now(), true, false
WHERE NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = 'PLATFORM_SUPPORTDESK');

-- Repair an already-present row (url drift / soft-deleted / demoted to a non-leaf).
-- IsLeastMenu = true is required or the sidebar renders it as a non-clickable group header.
-- Guarded on the wrong values, so this is a no-op once the row is correct.
UPDATE auth."Menus"
   SET "MenuUrl"      = '/ops/support',
       "IsLeastMenu"  = true,
       "IsVisible"    = true,
       "IsActive"     = true,
       "IsDeleted"    = false,
       "ModifiedDate" = now()
 WHERE "MenuCode" = 'PLATFORM_SUPPORTDESK'
   AND ("MenuUrl" IS DISTINCT FROM '/ops/support'
        OR "IsLeastMenu" IS NOT TRUE
        OR "IsVisible"   IS NOT TRUE
        OR "IsActive"    IS NOT TRUE
        OR "IsDeleted"   IS TRUE);

-- ── 2. Capabilities — VIEW + MANAGE ──────────────────────────────────────────────────
-- The idempotency guard checks CapabilityName, NOT CapabilityCode: auth."Capabilities" carries
-- a UNIQUE index on (CapabilityName, IsActive), so the name is the constrained column. Names are
-- prefixed "Platform " for the same collision reason as the rest of the family.
-- OrderBy continues the platform run past 108 (PLATFORM_INTIMATIONS_MANAGE).
-- IsSpecial = true: neither is part of the generic READ/CREATE/MODIFY grid family.
-- ISMENURENDER is NOT inserted here — it is a base-app capability that already exists.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Platform View Support Desk',   'PLATFORM_SUPPORTDESK_VIEW',
   'Read the tickets tenants have sent in — subject, description, the captured technical context and the internal note thread. Read-only; grants no access to tenant data.', 109),
  ('Platform Manage Support Desk', 'PLATFORM_SUPPORTDESK_MANAGE',
   'Move a ticket''s status, assign it to a member of platform staff, and append internal notes. Notes are never shown to the tenant and nothing here sends mail.', 110)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 3. MenuCapabilities ──────────────────────────────────────────────────────────────
-- PlatformRoleMatrixBuilder builds its ROWS from menus that have >= 1 MenuCapability and skips
-- any menu whose capability list is empty. Without this block the menu exists and the backend
-- enforces the capabilities, but nobody could ever grant them through the UI.
-- ISMENURENDER is MATCHED here (it already exists), never created.
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" = 'PLATFORM_SUPPORTDESK'
  AND c."CapabilityCode" IN ('PLATFORM_SUPPORTDESK_VIEW','PLATFORM_SUPPORTDESK_MANAGE','ISMENURENDER')
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- ── 4. Role grants — platform operator roles only ────────────────────────────────────
-- BOTH checks are required for the item to work: the API reads auth."RoleCapabilities" for the
-- VIEW/MANAGE codes, and GetParentChildMenuHandler renders the sidebar entry only for a user
-- who holds ISMENURENDER on this menu. A grant without ISMENURENDER is URL-callable and
-- completely invisible in the nav — so ISMENURENDER is granted alongside VIEW every time.
--
-- PLATFORM_SUPPORT gets VIEW + MANAGE: working this inbox is literally the job that role names.
-- PLATFORM_ADMIN gets the same. SALES, FINANCE and IMPLEMENTATION get nothing — widen it
-- through the Access Control screen if operations asks, not by editing this file after it runs.
--
-- PLATFORM_* roles are GLOBAL (CompanyId IS NULL) and the join constrains that; a tenant role
-- here would leak one tenant's reports to another. SUPERADMIN is matched by RoleCode alone
-- (see platform-staff-rbac-seed.sql §6 — the CompanyId-null assumption has bitten before) and
-- is only ever granted, never revoked.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_ADMIN',   'PLATFORM_SUPPORTDESK_VIEW'),
  ('PLATFORM_ADMIN',   'PLATFORM_SUPPORTDESK_MANAGE'),
  ('PLATFORM_ADMIN',   'ISMENURENDER'),
  ('PLATFORM_SUPPORT', 'PLATFORM_SUPPORTDESK_VIEW'),
  ('PLATFORM_SUPPORT', 'PLATFORM_SUPPORTDESK_MANAGE'),
  ('PLATFORM_SUPPORT', 'ISMENURENDER')
) AS v(role_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
                          AND r."IsDeleted" IS NOT TRUE
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
JOIN auth."Menus"        m ON m."MenuCode" = 'PLATFORM_SUPPORTDESK'
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- SUPERADMIN, matched by RoleCode alone — separate insert on purpose (see the note above).
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_SUPPORTDESK_VIEW'),
  ('PLATFORM_SUPPORTDESK_MANAGE'),
  ('ISMENURENDER')
) AS v(cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = 'SUPERADMIN' AND COALESCE(r."IsDeleted", false) = false
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
JOIN auth."Menus"        m ON m."MenuCode" = 'PLATFORM_SUPPORTDESK'
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT)
-- =====================================================================================
--
--   -- 1. Menu exists as a leaf under the control-plane root (expect 1 row,
--   --    /ops/support, IsLeastMenu true, OrderBy 970):
--   SELECT "MenuCode","MenuUrl","ParentMenuId","ModuleId","OrderBy","IsLeastMenu","IsVisible"
--   FROM   auth."Menus" WHERE "MenuCode" = 'PLATFORM_SUPPORTDESK';
--
--   -- 2. No other menu claims the same path (expect exactly 1 row):
--   SELECT "MenuCode" FROM auth."Menus"
--   WHERE  "MenuUrl" = '/ops/support' AND COALESCE("IsDeleted", false) = false;
--
--   -- 3. Both capabilities exist (expect 2, IsSpecial true, OrderBy 109/110):
--   SELECT "CapabilityCode","CapabilityName","IsSpecial","OrderBy" FROM auth."Capabilities"
--   WHERE  "CapabilityCode" IN ('PLATFORM_SUPPORTDESK_VIEW','PLATFORM_SUPPORTDESK_MANAGE');
--
--   -- 4. MenuCapabilities registered (expect 3 — VIEW, MANAGE, ISMENURENDER):
--   SELECT c."CapabilityCode"
--   FROM   auth."MenuCapabilities" mc
--   JOIN   auth."Menus" m        ON m."MenuId" = mc."MenuId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = mc."CapabilityId"
--   WHERE  m."MenuCode" = 'PLATFORM_SUPPORTDESK' ORDER BY c."CapabilityCode";
--
--   -- 5. Who can do what (expect 9 rows — ADMIN, SUPPORT, SUPERADMIN x 3):
--   SELECT r."RoleCode", c."CapabilityCode", r."CompanyId"
--   FROM   auth."RoleCapabilities" rc
--   JOIN   auth."Roles" r        ON r."RoleId" = rc."RoleId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--   JOIN   auth."Menus" m        ON m."MenuId" = rc."MenuId"
--   WHERE  m."MenuCode" = 'PLATFORM_SUPPORTDESK' AND rc."HasAccess"
--   ORDER BY r."RoleCode", c."CapabilityCode";
--
--   -- 6. THE TWO THAT MUST BOTH RETURN 0 ------------------------------------------
--   -- 6a. No tenant role was granted anything on this menu (a tenant seeing another
--   --     tenant's bug reports is the leak this whole surface must not have):
--   SELECT count(*) AS tenant_scoped_grants
--   FROM   auth."RoleCapabilities" rc
--   JOIN   auth."Roles" r ON r."RoleId" = rc."RoleId"
--   JOIN   auth."Menus" m ON m."MenuId" = rc."MenuId"
--   WHERE  m."MenuCode" = 'PLATFORM_SUPPORTDESK' AND r."CompanyId" IS NOT NULL;
--
--   -- 6b. No role holds VIEW on this menu without also holding ISMENURENDER — i.e. no
--   --     invisible-but-callable grant (§⑨ rule 9):
--   SELECT count(*) AS view_without_menurender
--   FROM   auth."RoleCapabilities" rc
--   JOIN   auth."Menus" m        ON m."MenuId" = rc."MenuId"
--   JOIN   auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--   WHERE  m."MenuCode" = 'PLATFORM_SUPPORTDESK'
--     AND  c."CapabilityCode" = 'PLATFORM_SUPPORTDESK_VIEW'
--     AND  rc."HasAccess" AND COALESCE(rc."IsDeleted", false) = false
--     AND  NOT EXISTS (
--            SELECT 1 FROM auth."RoleCapabilities" rc2
--            JOIN auth."Capabilities" c2 ON c2."CapabilityId" = rc2."CapabilityId"
--            WHERE rc2."RoleId" = rc."RoleId" AND rc2."MenuId" = rc."MenuId"
--              AND c2."CapabilityCode" = 'ISMENURENDER'
--              AND rc2."HasAccess" AND COALESCE(rc2."IsDeleted", false) = false);
--
--   -- 7. Confirm this script created no tickets (expect 0). Errors with "relation does
--   --    not exist" until the SupportTicket migration is applied — that is a separate,
--   --    user-owned step; this script never creates a table:
--   SELECT count(*) FROM ops."SupportTicket";
-- =====================================================================================
