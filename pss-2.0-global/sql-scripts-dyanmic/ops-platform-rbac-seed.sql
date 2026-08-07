-- =====================================================================================
-- P-03 T-A9 — PLATFORM_* control-plane RBAC seed
-- -------------------------------------------------------------------------------------
-- Seeds the GLOBAL (non-tenant) authorization scaffold the control-plane commands hang off:
--   1. auth."Modules"        — one PLATFORM module (the /ops control-plane surface)
--   2. auth."Menus"          — 5 (master) menus: a PLATFORMCONTROLPLANE root + 4 children
--                              (PLATFORM_TENANTS, PLATFORM_LEADS, PLATFORM_PLANS, PLATFORM_AUDIT)
--   3. auth."Capabilities"   — the fixed 10-capability family (IsSpecial = true)
--   4. auth."Roles"          — 5 internal-staff roles (IsSystem = true, CompanyId = NULL, IsAssignable = true)
--   5. auth."RoleCapabilities" — the D-Q7 role → capability bundles (HasAccess = true)
--
-- Authorization model (verified against CustomAuthorizeService.HasAccessAsync): a grant is a
-- RoleCapability row joining UserRole(RoleId) → Menu(MenuCode) → Capability(CapabilityCode) with
-- HasAccess = true. No MenuCapability row is required by the check, so none is seeded here.
--
-- ProvisionTenantCommand      is gated [PLATFORM_TENANTS , PLATFORM_TENANT_PROVISION]  → IMPLEMENTATION + ADMIN
-- AbandonProvisioningRunCommand is gated [PLATFORM_TENANTS , PLATFORM_TENANT_SUSPEND] → ADMIN only
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on the natural code key — re-running is a no-op.
-- SAFE: additive only. No DROP, no UPDATE, no schema change.
--
-- FK-SAFE (fix 2026-07-27): the menu rows resolve their ModuleId by LOOKING UP ModuleCode='PLATFORM'
-- rather than hardcoding a GUID. This is correct whether the module was just inserted by step 1
-- OR already existed with a different ModuleId (e.g. a prior partial run) — the previous version
-- hardcoded a GUID that step 1 would skip inserting if a PLATFORM module already existed, causing a
-- foreign-key violation on the menu insert (which surfaced downstream as SQLSTATE 25P02).
--
-- PREREQUISITE: run AFTER the auth schema exists (auth.Modules/Menus/Capabilities/Roles/RoleCapabilities).
-- Binding real internal users to these roles (auth.UserRoles) is an operational step (P-04 / A-14),
-- deliberately NOT part of this script.
-- =====================================================================================

BEGIN;
-- ── 1. Module — the PLATFORM control-plane module ─────────────────────────────────────────────
-- This row is the anchor every menu below resolves its ModuleId from. Without it the
-- `(SELECT ModuleId ... WHERE ModuleCode='PLATFORM')` sub-selects in step 2 return NULL and the
-- menu inserts violate the ModuleId FK (this was the missing step — added 2026-07-28).
--
-- ModuleUrl = '/platform/dashboards' — the module-navigator (module-navigator-item.tsx) pushes the
-- user straight to `/{lang}{ModuleUrl}` on click, so this is the module's landing route. The empty
-- landing page lives at app/[lang]/(master)/platform/dashboards/page.tsx.
-- ModuleId is DB-defaulted (gen_random_uuid()) so it is intentionally NOT listed here.
-- Unique indexes on this table: (ModuleName,IsActive), (ModuleCode,IsActive), (OrderBy,IsActive) —
-- OrderBy 900 keeps the control-plane module clear of the low ordinals the tenant modules use.
INSERT INTO auth."Modules"
  ("ModuleName","ModuleCode","ModuleUrl","Description","OrderBy","ModuleIcon",
   "CreatedDate","IsActive","IsDeleted")
SELECT
  'Control Plane', 'PLATFORM', '/platform/dashboards',
  'Platform control-plane: tenant provisioning, leads, deals & onboarding.', 900, 'ph-buildings',
  now(), true, false
WHERE NOT EXISTS (SELECT 1 FROM auth."Modules" md WHERE md."ModuleCode" = 'PLATFORM');

-- ── 2. Menus — PLATFORMCONTROLPLANE root + 4 children (all under the PLATFORM module) ─────────
-- ModuleId is RESOLVED from ModuleCode='PLATFORM' (not hardcoded) so the FK is valid whether the
-- module was just inserted above or already existed with a different ModuleId.

-- 2a. Root (parent) menu.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Control Plane', 'PLATFORMCONTROLPLANE', NULL, 'ph-buildings',
  (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'PLATFORM'),
  '/ops', 'Control-plane root.', 900,
  false, 'Internal', true, now(), true, false
WHERE NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = 'PLATFORMCONTROLPLANE');

-- 2b. Child (leaf) menus. ParentMenuId + ModuleId resolved from codes so the script is env-agnostic.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  v.menu_name, v.menu_code,
  (SELECT p."MenuId" FROM auth."Menus" p WHERE p."MenuCode" = 'PLATFORMCONTROLPLANE'),
  v.menu_icon,
  (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'PLATFORM'),
  v.menu_url, v.menu_desc, v.order_by,
  true, 'Internal', true, now(), true, false
FROM (VALUES
  ('Tenants', 'PLATFORM_TENANTS', 'ph-buildings',   '/ops/tenants', 'Tenant lifecycle & provisioning.', 910),
  ('Leads',   'PLATFORM_LEADS',   'ph-user-focus',  '/ops/leads',   'Sales pipeline & commercial deals.', 920),
  ('Plans',   'PLATFORM_PLANS',   'ph-stack',       '/ops/plans',   'Plan catalogue & pricing.', 930),
  ('Audit',   'PLATFORM_AUDIT',   'ph-list-magnifying-glass', '/ops/audit', 'Control-plane audit trail.', 940)
) AS v(menu_name, menu_code, menu_icon, menu_url, menu_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = v.menu_code);

-- ── 3. Capabilities — the fixed 10-capability family (IsSpecial = true) ───────────────────────
-- NAMES are prefixed "Platform " because auth."Capabilities" has a UNIQUE index on
-- (CapabilityName, IsActive) — bare names like "Impersonate" / "View Tenant" collide with
-- existing base-app capabilities. The idempotency guard therefore checks CapabilityName (the
-- constrained column), not CapabilityCode.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT
  v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Platform View Leads',       'PLATFORM_LEAD_VIEW',       'See leads in the sales pipeline.', 86),
  ('Platform Edit Leads',       'PLATFORM_LEAD_EDIT',       'Create and edit leads.', 87),
  ('Platform Export Leads',     'PLATFORM_LEAD_EXPORT',     'Export lead data (audited).', 88),
  ('Platform Approve Deal',     'PLATFORM_DEAL_APPROVE',    'Approve commercial terms / discounts.', 89),
  ('Platform View Tenant',      'PLATFORM_TENANT_VIEW',     'View tenant metadata & subscriptions.', 90),
  ('Platform Provision Tenant', 'PLATFORM_TENANT_PROVISION','Stand up (provision) a new tenant.', 91),
  ('Platform Suspend Tenant',   'PLATFORM_TENANT_SUSPEND',  'Suspend / abandon a tenant provisioning run.', 92),
  ('Platform Edit Plans',       'PLATFORM_PLAN_EDIT',       'Edit the plan catalogue & pricing.', 93),
  ('Platform Impersonate',      'PLATFORM_IMPERSONATE',     'Impersonate a tenant user for support.', 94),
  ('Platform View Audit',       'PLATFORM_AUDIT_VIEW',      'View the control-plane audit trail.', 95)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 4. Roles — 5 global internal-staff roles ─────────────────────────────────────────────────
INSERT INTO auth."Roles"
  ("RoleName","RoleCode","Description","IsSystem","IsAssignable","CompanyId","OrderBy","ColorHex",
   "CreatedDate","IsActive","IsDeleted")
SELECT
  v.role_name, v.role_code, v.role_desc, true, true, NULL, v.order_by, v.color_hex,
  now(), true, false
FROM (VALUES
  ('Platform Sales',          'PLATFORM_SALES',          'Works the sales pipeline: view & edit leads.', 10, '#2563eb'),
  ('Platform Implementation', 'PLATFORM_IMPLEMENTATION', 'Runs assisted onboarding: provisions & configures tenants.', 11, '#7c3aed'),
  ('Platform Support',        'PLATFORM_SUPPORT',        'Tenant troubleshooting: view & impersonate.', 12, '#0d9488'),
  ('Platform Finance',        'PLATFORM_FINANCE',        'Approves commercial terms; views subscriptions.', 13, '#ca8a04'),
  ('Platform Admin',          'PLATFORM_ADMIN',          'Internal superset: plans, suspend, audit, export.', 14, '#dc2626')
) AS v(role_name, role_code, role_desc, order_by, color_hex)
WHERE NOT EXISTS (SELECT 1 FROM auth."Roles" r WHERE r."RoleCode" = v.role_code AND r."CompanyId" IS NULL);

-- ── 5. Role → capability bundles (D-Q7 matrix). Each cell = (role, owning-menu, capability). ───
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  -- PLATFORM_SALES
  ('PLATFORM_SALES',          'PLATFORM_LEADS',    'PLATFORM_LEAD_VIEW'),
  ('PLATFORM_SALES',          'PLATFORM_LEADS',    'PLATFORM_LEAD_EDIT'),
  -- PLATFORM_IMPLEMENTATION
  ('PLATFORM_IMPLEMENTATION', 'PLATFORM_LEADS',    'PLATFORM_LEAD_VIEW'),
  ('PLATFORM_IMPLEMENTATION', 'PLATFORM_TENANTS',  'PLATFORM_TENANT_VIEW'),
  ('PLATFORM_IMPLEMENTATION', 'PLATFORM_TENANTS',  'PLATFORM_TENANT_PROVISION'),
  ('PLATFORM_IMPLEMENTATION', 'PLATFORM_TENANTS',  'PLATFORM_IMPERSONATE'),
  -- PLATFORM_SUPPORT
  ('PLATFORM_SUPPORT',        'PLATFORM_TENANTS',  'PLATFORM_TENANT_VIEW'),
  ('PLATFORM_SUPPORT',        'PLATFORM_TENANTS',  'PLATFORM_IMPERSONATE'),
  -- PLATFORM_FINANCE
  ('PLATFORM_FINANCE',        'PLATFORM_LEADS',    'PLATFORM_DEAL_APPROVE'),
  ('PLATFORM_FINANCE',        'PLATFORM_TENANTS',  'PLATFORM_TENANT_VIEW'),
  -- PLATFORM_ADMIN (full superset)
  ('PLATFORM_ADMIN',          'PLATFORM_LEADS',    'PLATFORM_LEAD_VIEW'),
  ('PLATFORM_ADMIN',          'PLATFORM_LEADS',    'PLATFORM_LEAD_EDIT'),
  ('PLATFORM_ADMIN',          'PLATFORM_LEADS',    'PLATFORM_LEAD_EXPORT'),
  ('PLATFORM_ADMIN',          'PLATFORM_LEADS',    'PLATFORM_DEAL_APPROVE'),
  ('PLATFORM_ADMIN',          'PLATFORM_TENANTS',  'PLATFORM_TENANT_VIEW'),
  ('PLATFORM_ADMIN',          'PLATFORM_TENANTS',  'PLATFORM_TENANT_PROVISION'),
  ('PLATFORM_ADMIN',          'PLATFORM_TENANTS',  'PLATFORM_TENANT_SUSPEND'),
  ('PLATFORM_ADMIN',          'PLATFORM_TENANTS',  'PLATFORM_IMPERSONATE'),
  ('PLATFORM_ADMIN',          'PLATFORM_PLANS',    'PLATFORM_PLAN_EDIT'),
  ('PLATFORM_ADMIN',          'PLATFORM_AUDIT',    'PLATFORM_AUDIT_VIEW'),
  
  ('SUPERADMIN',          'PLATFORM_LEADS',    'PLATFORM_LEAD_VIEW'),
  ('SUPERADMIN',          'PLATFORM_LEADS',    'PLATFORM_LEAD_EDIT'),
  -- PLATFORM_IMPLEMENTATION
  ('SUPERADMIN', 'PLATFORM_LEADS',    'PLATFORM_LEAD_VIEW'),
  ('SUPERADMIN', 'PLATFORM_TENANTS',  'PLATFORM_TENANT_VIEW'),
  ('SUPERADMIN', 'PLATFORM_TENANTS',  'PLATFORM_TENANT_PROVISION'),
  ('SUPERADMIN', 'PLATFORM_TENANTS',  'PLATFORM_IMPERSONATE'),
  -- PLATFORM_SUPPORT
  ('SUPERADMIN',        'PLATFORM_TENANTS',  'PLATFORM_TENANT_VIEW'),
  ('SUPERADMIN',        'PLATFORM_TENANTS',  'PLATFORM_IMPERSONATE'),
  -- PLATFORM_FINANCE
  ('SUPERADMIN',        'PLATFORM_LEADS',    'PLATFORM_DEAL_APPROVE'),
  ('SUPERADMIN',        'PLATFORM_TENANTS',  'PLATFORM_TENANT_VIEW'),
  -- PLATFORM_ADMIN (full superset)
  ('SUPERADMIN',          'PLATFORM_LEADS',    'PLATFORM_LEAD_VIEW'),
  ('SUPERADMIN',          'PLATFORM_LEADS',    'PLATFORM_LEAD_EDIT'),
  ('SUPERADMIN',          'PLATFORM_LEADS',    'PLATFORM_LEAD_EXPORT'),
  ('SUPERADMIN',          'PLATFORM_LEADS',    'PLATFORM_DEAL_APPROVE'),
  ('SUPERADMIN',          'PLATFORM_TENANTS',  'PLATFORM_TENANT_VIEW'),
  ('SUPERADMIN',          'PLATFORM_TENANTS',  'PLATFORM_TENANT_PROVISION'),
  ('SUPERADMIN',          'PLATFORM_TENANTS',  'PLATFORM_TENANT_SUSPEND'),
  ('SUPERADMIN',          'PLATFORM_TENANTS',  'PLATFORM_IMPERSONATE'),
  ('SUPERADMIN',          'PLATFORM_PLANS',    'PLATFORM_PLAN_EDIT'),
  ('SUPERADMIN',          'PLATFORM_AUDIT',    'PLATFORM_AUDIT_VIEW')
) AS v(role_code, menu_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
JOIN auth."Menus"        m ON m."MenuCode" = v.menu_code
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--   -- 1 module, 5 menus, 10 capabilities, 5 roles, 20 role-capability grants
--   SELECT (SELECT count(*) FROM auth."Modules"       WHERE "ModuleCode"='PLATFORM')                    AS modules,
--          (SELECT count(*) FROM auth."Menus"          WHERE "MenuCode" LIKE 'PLATFORM%')                AS menus,
--          (SELECT count(*) FROM auth."Capabilities"   WHERE "CapabilityCode" LIKE 'PLATFORM%')          AS capabilities,
--          (SELECT count(*) FROM auth."Roles"          WHERE "RoleCode" LIKE 'PLATFORM%' AND "CompanyId" IS NULL) AS roles,
--          (SELECT count(*) FROM auth."RoleCapabilities" rc
--             JOIN auth."Roles" r ON r."RoleId"=rc."RoleId"
--             WHERE r."RoleCode" LIKE 'PLATFORM%' AND r."CompanyId" IS NULL)                             AS grants;
--   -- Every menu points at a real module (expect 0 orphans):
--   SELECT count(*) AS orphan_menus FROM auth."Menus" mn
--     WHERE mn."MenuCode" LIKE 'PLATFORM%'
--       AND NOT EXISTS (SELECT 1 FROM auth."Modules" md WHERE md."ModuleId" = mn."ModuleId");
--   -- Who can provision?  expect PLATFORM_IMPLEMENTATION and PLATFORM_ADMIN
--   SELECT r."RoleCode" FROM auth."RoleCapabilities" rc
--     JOIN auth."Roles" r ON r."RoleId"=rc."RoleId"
--     JOIN auth."Capabilities" c ON c."CapabilityId"=rc."CapabilityId"
--     WHERE c."CapabilityCode"='PLATFORM_TENANT_PROVISION' AND r."CompanyId" IS NULL AND rc."HasAccess";
-- =====================================================================================
