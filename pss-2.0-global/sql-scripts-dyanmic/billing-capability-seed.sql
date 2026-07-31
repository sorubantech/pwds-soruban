-- =====================================================================================
-- PROMPT-13 (T-A19) — Billing Foundation §6.7 — tenant-side BILLING RBAC + menu seed
-- -------------------------------------------------------------------------------------
-- Seeds the authorization scaffold AND the sidebar entries behind the tenant's own
-- /billing surface:
--   1. auth."Menus"            — BILLING parent (header) + 3 leaves (Overview/Plans/Invoices)
--   2. auth."Capabilities"     — BILLING_VIEW + BILLING_MANAGE
--   3. auth."MenuCapabilities" — which capabilities each billing menu supports
--   4. auth."RoleCapabilities" — grants to BUSINESSADMIN (every tenant) + SUPERADMIN
--
-- ── TWO DIFFERENT CHECKS, BOTH MUST BE SEEDED ────────────────────────────────────────
-- (a) API AUTHORIZATION — CustomAuthorizeService.HasAccessAsync joins
--       UserRole(RoleId) → Menu(MenuCode) → Capability(CapabilityCode) with HasAccess = true.
--     It matches on MenuCode ONLY, so the grants on MenuCode 'BILLING' are what let
--     GetMyBillingOverviewQuery / GetTenantInvoicesQuery ([BILLING, BILLING_VIEW]) pass.
--     No MenuCapability row is consulted by this check.
--
-- (b) SIDEBAR RENDERING — GetParentChildMenuHandler builds the nav from menus the user
--     holds the **ISMENURENDER** capability on (GetParentChildMenu.cs:71), then walks
--     parents up from those authorized LEAVES. A menu with BILLING_VIEW but no
--     ISMENURENDER grant is callable by URL and completely invisible in the nav.
--     ISMENURENDER already exists in auth."Capabilities" (base-app seed) — it is
--     referenced here, never inserted.
--
-- ── WHY THE 'SETTING' MODULE AND NOT 'ORGANIZATION' ──────────────────────────────────
-- auth."Modules" are granted to a tenant's roles per plan. ProvisionTenant's
-- ModuleFeatureMap (ProvisionTenant.cs:170) maps ORGANIZATION → MODULE:ORGANIZATION /
-- MODULE:EVENTS / MODULE:CAMPAIGNS, so a tenant whose plan enables none of those gets no
-- RoleModule for ORGANIZATION and never sees anything under it. Putting billing there
-- would hide the upgrade surface from exactly the tenants who need it — and from any
-- tenant whose subscription lapses.
-- SETTING is in AlwaysOnModuleCodes (ProvisionTenant.cs:175) alongside GENERAL /
-- ACCESSCONTROL / PSSCORE / ADMIN: infra, granted regardless of plan. Billing must behave
-- the same way, so it lives under SETTING.
--
-- ── WHY A PARENT + THREE LEAVES, NOT ONE LEAF ────────────────────────────────────────
-- mapMenuToClassicConfig (menu-mapping.tsx:35-45) renders every TOP-LEVEL menu as a
-- non-clickable header with href "#" and only its childMenus as links. A single
-- top-level BILLING row carrying MenuUrl '/billing' would therefore render as dead
-- label text — its URL is never read. The three FE routes built in §7 each get a leaf:
--     /billing            → Overview
--     /billing/plans      → Plans
--     /billing/invoices   → Invoices
-- Hrefs are stored WITHOUT the [lang] segment; single-menu-item.tsx:24 prefixes
-- `/${lang}/` and strips leading slashes, so '/billing' and 'billing' are equivalent.
--
-- ── WHO GETS WHAT ────────────────────────────────────────────────────────────────────
--   BILLING_MANAGE is UNUSED in this build. It is seeded now on purpose so PROMPT-14
--   (taking a card) does not need a second capability migration mid-flight.
--   BUSINESSADMIN ONLY on the tenant side — billing is an owner-level surface, and no other
--   tenant role should see plan spend or invoices.
--
-- ⚠ ROLE SCOPE DIFFERS FROM ops-platform-rbac-seed.sql. The PLATFORM_* roles are global
--   (CompanyId IS NULL) and that script joins `AND r."CompanyId" IS NULL`. BUSINESSADMIN is a
--   PER-TENANT system role — there is one row per company — so the join here deliberately does
--   NOT constrain CompanyId. Every existing tenant's BUSINESSADMIN role gets the grant, which is
--   exactly the intent. SUPERADMIN is matched the same way (whatever scope it exists at).
--
-- ⚠ PLAN ENTITLEMENT FILTER: GetParentChildMenuHandler also drops menus whose MenuCode is
--   mapped in MenuFeatureMap to a feature the tenant's plan does not enable. The BILLING_*
--   codes are deliberately NOT in MenuFeatureMap — billing must stay reachable on every
--   plan, including a lapsed one. Do not add them there.
--
-- ⚠ TENANTS PROVISIONED AFTER THIS SCRIPT RUNS get their RoleCapabilities cloned from the
--   template company by ProvisionTenant Step 4a. If the template company's BUSINESSADMIN role is
--   picked up by the join below, new tenants inherit these grants automatically. If your
--   environment still has no '__TEMPLATE__' company (the defect fix-aram-tenant-rolecapability-
--   backfill.sql documents), re-run this script after each provisioning run, or fix the template.
--
-- IDEMPOTENT: every INSERT is guarded by NOT EXISTS on the natural key — re-running is a no-op.
-- SAFE: additive only. No DROP, no UPDATE, no schema change.
-- =====================================================================================

BEGIN;

-- ── 1a. Menu — BILLING parent (header row) under the always-on SETTING module ────────────────
-- ModuleId is RESOLVED from ModuleCode = 'SETTING' rather than hardcoded (the FK-safety lesson
-- from ops-platform-rbac-seed.sql). Driving the INSERT off `FROM auth."Modules"` means that if
-- no SETTING module is present this insert quietly does nothing rather than violating the
-- ModuleId FK — check the VERIFY block below for a zero-row result and re-point it if so.
--
-- IsLeastMenu = false: it is a header, its children own the URLs. MenuUrl is still populated
-- because mapMenuToMainConfig (horizontal layout) reads parent hrefs.
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  'Billing', 'BILLING', NULL, 'ph-receipt',
  md."ModuleId",
  null, 'Plan, usage and invoices for this organization.', 700,
  false, 'Internal', true, now(), true, false
FROM auth."Modules" md
WHERE md."ModuleCode" = 'SETTING'
  AND NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = 'BILLING');

-- ── 1b. Menus — the three leaves that actually render as sidebar links ───────────────────────
INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description","OrderBy",
   "IsLeastMenu","MenuType","IsVisible","CreatedDate","IsActive","IsDeleted")
SELECT
  v.menu_name, v.menu_code,
  (SELECT p."MenuId" FROM auth."Menus" p WHERE p."MenuCode" = 'BILLING'),
  v.menu_icon,
  (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'SETTING'),
  v.menu_url, v.menu_desc, v.order_by,
  true, 'Internal', true, now(), true, false
FROM (VALUES
  ('Overview', 'BILLING_OVERVIEW', 'ph-gauge',     '/billing',          'Current plan, usage and renewal.', 710),
  ('Plans',    'BILLING_PLANS',    'ph-stack',     '/billing/plans',    'Compare published plans and pricing.', 720),
  ('Invoices', 'BILLING_INVOICES', 'ph-file-text', '/billing/invoices', 'Invoice history and payment status.', 730)
) AS v(menu_name, menu_code, menu_icon, menu_url, menu_desc, order_by)
WHERE EXISTS (SELECT 1 FROM auth."Menus" p WHERE p."MenuCode" = 'BILLING')
  AND NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = v.menu_code);

-- ── 2. Capabilities — BILLING_VIEW + BILLING_MANAGE ──────────────────────────────────────────
-- The idempotency guard checks CapabilityName, NOT CapabilityCode: auth."Capabilities" has a
-- UNIQUE index on (CapabilityName, IsActive), so the name is the constrained column.
-- Names are prefixed "Billing " for the same collision reason the PLATFORM_* family is prefixed.
-- OrderBy continues the series past 96 (PLATFORM_PLAN_VIEW).
-- IsSpecial = true: these are not part of the generic READ/CREATE/MODIFY grid family.
-- ISMENURENDER is NOT inserted here — it is a base-app capability that already exists.
INSERT INTO auth."Capabilities"
  ("CapabilityName","CapabilityCode","Description","IsSpecial","OrderBy",
   "CreatedDate","IsActive","IsDeleted")
SELECT
  v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, now(), true, false
FROM (VALUES
  ('Billing View',   'BILLING_VIEW',   'View this organization''s plan, usage and invoices.', 97),
  ('Billing Manage', 'BILLING_MANAGE', 'Change plan and pay online (self-serve upgrade). Unused until PROMPT-14.', 98)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ── 3. MenuCapabilities — which capabilities each billing menu supports ──────────────────────
-- Not read by HasAccessAsync, but it is what the Access Control screen enumerates when an admin
-- edits a role, so omitting it makes these grants un-manageable through the UI.
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", now(), true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" IN ('BILLING','BILLING_OVERVIEW','BILLING_PLANS','BILLING_INVOICES')
  AND c."CapabilityCode" IN ('BILLING_VIEW','BILLING_MANAGE','ISMENURENDER')
  AND NOT EXISTS (
    SELECT 1 FROM auth."MenuCapabilities" mc
    WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- ── 4. Role → capability grants ──────────────────────────────────────────────────────────────
-- NOTE the missing `AND r."CompanyId" IS NULL` compared with ops-platform-rbac-seed.sql — see the
-- header. This joins EVERY BUSINESSADMIN role in the system (one per tenant) plus SUPERADMIN.
--
-- ISMENURENDER is granted on the three LEAVES only. The handler walks parents up from authorized
-- leaves, so the BILLING header appears automatically; granting render on the header itself would
-- leave an empty "Billing" label behind if every leaf were later revoked.
INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT
  r."RoleId", m."MenuId", c."CapabilityId", true, now(), true, false
FROM auth."Roles" r
CROSS JOIN auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE r."RoleCode" IN ('BUSINESSADMIN','SUPERADMIN')
  AND r."IsDeleted" IS NOT TRUE
  AND (
        -- API authorization: HasAccessAsync matches MenuCode 'BILLING' exactly.
        (m."MenuCode" = 'BILLING' AND c."CapabilityCode" IN ('BILLING_VIEW','BILLING_MANAGE'))
        -- Sidebar rendering + per-leaf access, so Access Control shows them consistently.
     OR (m."MenuCode" IN ('BILLING_OVERVIEW','BILLING_PLANS','BILLING_INVOICES')
         AND c."CapabilityCode" IN ('BILLING_VIEW','BILLING_MANAGE','ISMENURENDER'))
  )
  AND NOT EXISTS (
    SELECT 1 FROM auth."RoleCapabilities" rc
    WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
  );

COMMIT;

-- =====================================================================================
-- VERIFY (run after COMMIT):
--
--   -- All 4 menus exist, sit under SETTING, and the leaves hang off the header
--   -- (expect 4 rows, module_code = 'SETTING', 3 with parent_code = 'BILLING'):
--   SELECT mn."MenuCode", mn."MenuUrl", mn."IsLeastMenu", mn."IsVisible", md."ModuleCode",
--          p."MenuCode" AS parent_code, (md."ModuleId" IS NULL) AS orphan
--   FROM   auth."Menus" mn
--   LEFT JOIN auth."Modules" md ON md."ModuleId" = mn."ModuleId"
--   LEFT JOIN auth."Menus"   p  ON p."MenuId"    = mn."ParentMenuId"
--   WHERE  mn."MenuCode" IN ('BILLING','BILLING_OVERVIEW','BILLING_PLANS','BILLING_INVOICES')
--   ORDER BY mn."OrderBy";
--   -- Zero rows means the SETTING module was not found under that exact code — check
--   -- `SELECT "ModuleCode" FROM auth."Modules" ORDER BY 1;` and re-point sections 1a/1b.
--
--   -- Both capabilities exist (expect 2 rows), and ISMENURENDER is present (expect 1):
--   SELECT "CapabilityCode", "CapabilityName", "IsSpecial", "OrderBy"
--   FROM   auth."Capabilities"
--   WHERE  "CapabilityCode" IN ('BILLING_VIEW','BILLING_MANAGE','ISMENURENDER');
--   -- If ISMENURENDER is missing, this environment predates the base-app seed and the sidebar
--   -- entries will not render for ANY screen — fix that globally, not here.
--
--   -- Grants, one block per tenant. Expect 2 rows on BILLING + 3 on each of the 3 leaves
--   -- = 11 rows per role:
--   SELECT r."RoleCode", r."CompanyId", cmp."CompanyCode", m."MenuCode", cap."CapabilityCode",
--          rc."HasAccess"
--   FROM   auth."RoleCapabilities" rc
--   JOIN   auth."Roles" r          ON r."RoleId"         = rc."RoleId"
--   JOIN   auth."Capabilities" cap ON cap."CapabilityId" = rc."CapabilityId"
--   JOIN   auth."Menus" m          ON m."MenuId"         = rc."MenuId"
--   LEFT JOIN app."Companies" cmp  ON cmp."CompanyId"    = r."CompanyId"
--   WHERE  m."MenuCode" LIKE 'BILLING%'
--   ORDER BY r."CompanyId", r."RoleCode", m."OrderBy", cap."CapabilityCode";
--
--   -- Every leaf carries ISMENURENDER for BUSINESSADMIN — this is the row that makes the
--   -- sidebar entry appear (expect 3 per tenant, NOT 0):
--   SELECT r."CompanyId", count(*) AS render_grants
--   FROM   auth."RoleCapabilities" rc
--   JOIN   auth."Roles" r          ON r."RoleId"         = rc."RoleId"
--   JOIN   auth."Capabilities" cap ON cap."CapabilityId" = rc."CapabilityId"
--   JOIN   auth."Menus" m          ON m."MenuId"         = rc."MenuId"
--   WHERE  m."MenuCode" LIKE 'BILLING\_%' AND cap."CapabilityCode" = 'ISMENURENDER'
--     AND  r."RoleCode" = 'BUSINESSADMIN' AND rc."HasAccess" = true
--   GROUP BY r."CompanyId" ORDER BY r."CompanyId";
--
--   -- No non-BUSINESSADMIN tenant role picked up billing access (expect 0):
--   SELECT count(*)
--   FROM   auth."RoleCapabilities" rc
--   JOIN   auth."Roles" r ON r."RoleId" = rc."RoleId"
--   JOIN   auth."Menus" m ON m."MenuId" = rc."MenuId"
--   WHERE  m."MenuCode" LIKE 'BILLING%'
--     AND  r."CompanyId" IS NOT NULL
--     AND  r."RoleCode" <> 'BUSINESSADMIN';
-- =====================================================================================
