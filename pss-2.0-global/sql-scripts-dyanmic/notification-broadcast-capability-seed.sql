-- =====================================================================================
-- PROMPT-22 (T-A24) — In-App Notification Service — BROADCAST RBAC + platform inbox menu
-- -------------------------------------------------------------------------------------
-- Seeds the two capabilities that gate COMPOSING a notification, on both surfaces, plus
-- the one menu row the platform inbox needs to hang its capability off:
--   1. auth."Menus"            — PLATFORM_NOTIFICATIONS leaf under PLATFORMCONTROLPLANE (NEW)
--   2. auth."Capabilities"     — NOTIFICATION_BROADCAST + PLATFORM_NOTIFY_BROADCAST
--   3. auth."MenuCapabilities" — so both are manageable from the role editor
--   4. auth."RoleCapabilities" — grants
--
-- ── UNTIL THIS SCRIPT RUNS, NOBODY CAN SEND ANYTHING ─────────────────────────────────
-- The dispatcher shipped with PROMPT-22 has never executed in this codebase. Composing is
-- gated in TWO places and both read these rows: the Compose button is drawn from the
-- capability the client already holds, and SendNotificationCommandHandler re-checks it
-- server-side before it resolves a single recipient. Reading an inbox needs NO capability —
-- your own notifications are yours — so a missing grant looks like "the inbox works but
-- the Compose button is gone", not like a broken screen.
--
-- ── WHY BROADCAST IS THE ONLY THING GATED ────────────────────────────────────────────
-- Every other notification in the system is emitted by a handler as a side-effect of an
-- action the user was already authorized to take (assign a lead, fail a provisioning run).
-- Re-checking a capability at dispatch time would be checking the WRONG user — the one who
-- triggered it, not the ones receiving it — which is why the check lives in the compose
-- command and NEVER inside SendAsync. Do not "harden" the dispatcher by adding one there;
-- it would silently kill the system-emitted notifications, which have no user context.
--
-- ── THE NEW PLATFORM MENU ────────────────────────────────────────────────────────────
-- PLATFORM_NOTIFICATIONS did not exist. It is created here rather than in ops-platform-
-- rbac-seed.sql because that file describes the control plane as it shipped in P-08, and a
-- capability cannot be granted without an owning menu — CustomAuthorizeService.HasAccessAsync
-- joins UserRole → Menu(MenuCode) → Capability(CapabilityCode), so the grant row needs a
-- real MenuId. OrderBy 950 continues the existing leaf run (910 Tenants / 920 Leads /
-- 930 Plans / 940 Audit).
--
-- No ISMENURENDER grant, deliberately: the (master) control-plane surface does not build its
-- nav from GetParentChildMenuHandler — none of the four existing platform leaves have one
-- either. The menu row here exists to OWN the capability, not to draw a sidebar item.
--
-- ── ROLE SCOPE DIFFERS BETWEEN THE TWO HALVES ────────────────────────────────────────
-- PLATFORM_* roles are global (CompanyId IS NULL) and §4a joins accordingly. BUSINESSADMIN
-- is a PER-TENANT system role — one row per company — so §4b deliberately does NOT constrain
-- CompanyId: every existing tenant's BUSINESSADMIN gets the grant, which is the intent.
--
-- ⚠ TENANTS PROVISIONED AFTER THIS SCRIPT RUNS inherit RoleCapabilities cloned from the
--   template company by ProvisionTenant Step 4a. If your environment has no '__TEMPLATE__'
--   company, re-run this script after each provisioning run.
--
-- ⚠ CapabilityName, NOT CapabilityCode, is the idempotency key below. The UNIQUE index on
--   auth."Capabilities" is (CapabilityName, IsActive) — guarding on the code would let a
--   re-run collide on the name it does not check.
--
-- PREREQUISITE: run AFTER the PROMPT-22 EF migration
--   (PSS-2.0-ONBOARDING-PROMPT-22-MIGRATION-SPEC.md) and AFTER ops-platform-rbac-seed.sql.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on the natural key — re-running is a no-op.
-- SAFE: additive only. No DROP, no UPDATE, no schema change.
-- =====================================================================================

BEGIN;

-- ── 1. Menu — PLATFORM_NOTIFICATIONS leaf under the control-plane root ───────────────────────
-- ModuleId is RESOLVED from ModuleCode = 'PLATFORM' rather than hardcoded, so if the PLATFORM
-- module is absent this insert quietly does nothing instead of violating the FK. A zero-row
-- VERIFY result at the bottom means exactly that — fix the module, then re-run.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Notifications', 'PLATFORM_NOTIFICATIONS',
  (SELECT p."MenuId" FROM auth."Menus" p WHERE p."MenuCode" = 'PLATFORMCONTROLPLANE'),
  'ph-bell-ringing',
  (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'PLATFORM'),
  '/ops/notifications', 'Platform-scope notification inbox and announcements.', 950,
  true, 'Internal', true, now(), true, false
WHERE NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = 'PLATFORM_NOTIFICATIONS');

-- ── 2. Capabilities ──────────────────────────────────────────────────────────────────────────
-- IsSpecial = true: neither is one of the CRUD flags the generic grid permission block renders;
-- both are read through useAccessCapability's named allow-list on the client and through an
-- explicit [Menu, Capability] attribute on the server.
--
-- OrderBy continues the platform capability run (…, 100/101 = P-20, 102 = P-21 lead assign).
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT
  v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Broadcast Notifications',
   'NOTIFICATION_BROADCAST',
   'Compose an in-app notification addressed to a ROLE or to all staff in the organization. Sending to a handful of named individuals does not need this; crossing the broadcast threshold does.',
   103),
  ('Platform Broadcast Notifications',
   'PLATFORM_NOTIFY_BROADCAST',
   'Compose a PLATFORM-scope in-app notification to internal staff roles. Platform scope only — this grants nothing inside any tenant.',
   104)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 3. Menu → capability association ─────────────────────────────────────────────────────────
-- Not consulted by HasAccessAsync. It is what the role editor lists as available when someone
-- edits a role, so omitting it makes these grants un-manageable through the UI.
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM (VALUES
  ('NOTIFICATION',           'NOTIFICATION_BROADCAST'),
  ('PLATFORM_NOTIFICATIONS', 'PLATFORM_NOTIFY_BROADCAST')
) AS v(menu_code, cap_code)
JOIN auth."Menus"        m ON m."MenuCode" = v.menu_code
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
WHERE NOT EXISTS (
  SELECT 1 FROM auth."MenuCapabilities" mc
  WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
);

-- ── 4a. Grants — PLATFORM_NOTIFY_BROADCAST to the global internal roles ──────────────────────
-- PLATFORM_ADMIN and SUPERADMIN only. A platform broadcast reaches every internal staff member;
-- PLATFORM_SALES / _SUPPORT / _IMPLEMENTATION / _FINANCE deliberately receive but cannot send.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_ADMIN', 'PLATFORM_NOTIFICATIONS', 'PLATFORM_NOTIFY_BROADCAST'),
  ('SUPERADMIN',     'PLATFORM_NOTIFICATIONS', 'PLATFORM_NOTIFY_BROADCAST')
) AS v(role_code, menu_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
JOIN auth."Menus"        m ON m."MenuCode" = v.menu_code
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- ── 4b. Grants — NOTIFICATION_BROADCAST to every tenant's BUSINESSADMIN ──────────────────────
-- NOTE the missing CompanyId predicate: this is per-tenant on purpose (see header). ORGADMIN is
-- included where it exists; the join simply produces no rows for environments without it.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('BUSINESSADMIN', 'NOTIFICATION', 'NOTIFICATION_BROADCAST'),
  ('ORGADMIN',      'NOTIFICATION', 'NOTIFICATION_BROADCAST')
) AS v(role_code, menu_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code
JOIN auth."Menus"        m ON m."MenuCode" = v.menu_code
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

COMMIT;

-- =====================================================================================
-- VERIFY (run manually after COMMIT)
-- =====================================================================================
-- -- The new platform menu resolved its parent AND its module (neither may be NULL):
-- SELECT "MenuCode", "ParentMenuId", "ModuleId", "MenuUrl", "OrderBy"
--   FROM auth."Menus" WHERE "MenuCode" = 'PLATFORM_NOTIFICATIONS';
--
-- -- Both capabilities exist exactly once:
-- SELECT "CapabilityCode", "CapabilityName", "OrderBy"
--   FROM auth."Capabilities"
--  WHERE "CapabilityCode" IN ('NOTIFICATION_BROADCAST','PLATFORM_NOTIFY_BROADCAST');
--
-- -- Who can broadcast where. Expect 2 platform rows and one tenant row per company:
-- SELECT c."CapabilityCode", r."RoleCode", r."CompanyId", m."MenuCode"
--   FROM auth."RoleCapabilities" rc
--   JOIN auth."Roles"        r ON r."RoleId" = rc."RoleId"
--   JOIN auth."Menus"        m ON m."MenuId" = rc."MenuId"
--   JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--  WHERE c."CapabilityCode" IN ('NOTIFICATION_BROADCAST','PLATFORM_NOTIFY_BROADCAST')
--    AND rc."HasAccess" = true
--  ORDER BY c."CapabilityCode", r."CompanyId" NULLS FIRST;
--
-- -- Tenants that did NOT get the grant (missing BUSINESSADMIN, or provisioned later):
-- SELECT co."CompanyId", co."CompanyName"
--   FROM app."Companies" co
--  WHERE NOT EXISTS (
--        SELECT 1 FROM auth."RoleCapabilities" rc
--          JOIN auth."Roles"        r ON r."RoleId" = rc."RoleId" AND r."CompanyId" = co."CompanyId"
--          JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--         WHERE c."CapabilityCode" = 'NOTIFICATION_BROADCAST');
-- =====================================================================================
