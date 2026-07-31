-- =====================================================================================
-- P-11 T-A17 — PLATFORM_PLAN_VIEW capability + role grants
-- -------------------------------------------------------------------------------------
-- WHY THIS EXISTS
-- The P-03 RBAC seed (ops-platform-rbac-seed.sql) created PLATFORM_PLAN_EDIT but no read-only
-- counterpart, so the only way to see the plan catalogue was to be able to rewrite it. T-A17 gates
-- its two reads as:
--
--   [CustomAuthorize("PLATFORM_PLANS", "PLATFORM_PLAN_VIEW", "PLATFORM_PLAN_EDIT")]
--        → GetPlanCatalogQuery, GetSubscriptionForCompanyQuery      (EITHER capability passes)
--   [CustomAuthorize("PLATFORM_PLANS", "PLATFORM_PLAN_EDIT")]
--        → every catalogue and subscription write
--
-- so PLATFORM_PLAN_VIEW is what lets Finance and Support READ plans and a tenant's subscription
-- without also being able to reprice the product. Nothing breaks without this script — an ADMIN
-- already reads through PLAN_EDIT — but the read-only roles stay locked out until it runs.
--
-- GRANTS
--   PLATFORM_FINANCE        — approves commercial terms; must see plans, pricing and subscriptions.
--   PLATFORM_SUPPORT        — needs a tenant's plan and effective entitlements to triage a ticket.
--   PLATFORM_IMPLEMENTATION — assigns an onboarding tenant to a plan; reads the catalogue to do it.
--   PLATFORM_ADMIN          — superset (holds PLAN_EDIT already; granted for completeness).
--   SUPERADMIN              — superset, mirrors the P-03 script's SUPERADMIN block.
--
-- Write capability (PLATFORM_PLAN_EDIT) is deliberately NOT widened here: it stays with
-- PLATFORM_ADMIN and SUPERADMIN exactly as P-03 left it.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on the natural key — re-running is a no-op.
-- SAFE: additive only. No DROP, no UPDATE, no schema change.
-- PREREQUISITE: run AFTER ops-platform-rbac-seed.sql (needs the PLATFORM_PLANS menu and the roles).
-- =====================================================================================

BEGIN;

-- ── 1. Capability ────────────────────────────────────────────────────────────────────────────
-- auth."Capabilities" has a UNIQUE index on (CapabilityName, IsActive), so the guard checks the
-- CONSTRAINED column (CapabilityName) rather than the code — same rule the P-03 seed follows.
-- OrderBy 96 continues that script's PLATFORM_* block (which ended at 95).
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT
  'Platform View Plans', 'PLATFORM_PLAN_VIEW',
  'View the plan catalogue, pricing and a tenant''s subscription (read-only).', true, 96,
  now(), true, false
WHERE NOT EXISTS (
  SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = 'Platform View Plans'
);

-- ── 2. Role → capability grants on the PLATFORM_PLANS menu ───────────────────────────────────
-- A grant is a RoleCapability row joining UserRole(RoleId) → Menu(MenuCode) → Capability(Code)
-- with HasAccess = true; CustomAuthorizeService.HasAccessAsync needs no MenuCapability row.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM (VALUES
  ('PLATFORM_FINANCE',        'PLATFORM_PLANS', 'PLATFORM_PLAN_VIEW'),
  ('PLATFORM_SUPPORT',        'PLATFORM_PLANS', 'PLATFORM_PLAN_VIEW'),
  ('PLATFORM_IMPLEMENTATION', 'PLATFORM_PLANS', 'PLATFORM_PLAN_VIEW'),
  ('PLATFORM_ADMIN',          'PLATFORM_PLANS', 'PLATFORM_PLAN_VIEW'),
  ('SUPERADMIN',              'PLATFORM_PLANS', 'PLATFORM_PLAN_VIEW')
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
--   -- The capability exists exactly once:
--   SELECT "CapabilityId","CapabilityCode","CapabilityName"
--     FROM auth."Capabilities" WHERE "CapabilityCode" = 'PLATFORM_PLAN_VIEW';
--
--   -- Who can now READ the catalogue (expect the 5 roles above, plus PLAN_EDIT holders):
--   SELECT r."RoleCode", c."CapabilityCode"
--     FROM auth."RoleCapabilities" rc
--     JOIN auth."Roles" r        ON r."RoleId" = rc."RoleId"
--     JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--     JOIN auth."Menus" m        ON m."MenuId" = rc."MenuId"
--    WHERE m."MenuCode" = 'PLATFORM_PLANS' AND rc."HasAccess" AND r."CompanyId" IS NULL
--    ORDER BY r."RoleCode", c."CapabilityCode";
--
--   -- Write stayed narrow (expect ONLY PLATFORM_ADMIN and SUPERADMIN):
--   SELECT r."RoleCode" FROM auth."RoleCapabilities" rc
--     JOIN auth."Roles" r        ON r."RoleId" = rc."RoleId"
--     JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
--    WHERE c."CapabilityCode" = 'PLATFORM_PLAN_EDIT' AND rc."HasAccess" AND r."CompanyId" IS NULL;
-- =====================================================================================
