-- =====================================================================================
-- PROMPT-24 (v2) — Plan role baseline bootstrap
--        billing."PlanRoleBaselines" — one row per (PlanId, RoleCode, MenuId, CapabilityId)
-- -------------------------------------------------------------------------------------
-- WHY THIS EXISTS
--
--   Provisioning used to copy the __TEMPLATE__ company's capability matrix into every new
--   tenant, identically, regardless of which plan that tenant bought. A 50K tenant was
--   therefore GRANTED every 100K menu, and the only thing hiding them was PlanMenuFilter
--   — which its own doc calls "COSMETIC ONLY" and which fails OPEN on any menu nobody
--   remembered to map. PROMPT-24 §D6.
--
--   The fix is to grant per plan: ProvisionTenant Step 4 now reads THIS table instead of
--   the template's RoleCapability rows. No row here => no grant => nothing to leak.
--
--   This script seeds a sensible starting point so the platform team does not face four
--   empty matrices on day one. After it runs, the Plan Baselines screen is the way to
--   edit them; this file is a bootstrap, not the source of truth.
--
-- ⚠ NOT OPTIONAL. Once the new Step 4 ships, a plan with zero baseline rows makes tenant
--   provisioning FAIL (PROMPT-24 INV-13, deliberately loud). Run this before creating the
--   next tenant, and read the per-plan counts printed at the end — a plan showing 0 is a
--   plan nobody can be provisioned onto.
--
-- WHAT IT GRANTS, PER PLAN
--
--   Every (menu, capability) pair from auth."MenuCapabilities" where:
--     • the menu is NOT platform-owned (module PLATFORM is staff-only, never a tenant's), and
--     • the menu is not plan-blocked for that plan.
--
--   "Plan-blocked" is computed the same way PlanMenuFilter computes it at runtime, so the
--   baseline and the sidebar agree:
--     • a menu is blocked if IT or ANY ANCESTOR maps (billing."FeatureMenuMaps") to a
--       feature the plan explicitly disables (billing."PlanEntitlements"."IsEnabled" = false);
--     • an UNMAPPED menu is NOT blocked — absence of a map row means "always visible",
--       never "hidden". A typo'd MenuCode stays inert, exactly as in the runtime filter;
--     • BILLING* / SETTING* / ACCESSCONTROL* are never blocked whatever the map says. A
--       tenant whose plan lapsed must still reach the pay screen and its own settings;
--     • ancestor walk is depth-capped at 32, same as the runtime cycle guard.
--
--   HasAccess ticks come from the __TEMPLATE__ company's role of the same RoleCode when
--   that company has any rows for it (so an existing curated template is preserved), and
--   default to true otherwise.
--
-- WHAT IT DELIBERATELY DOES NOT DO
--
--   • It does not touch any live tenant. Baselines describe what FUTURE tenants are born
--     with; pushing to existing tenants is an explicit act on the Plan Baselines screen.
--   • It does not account for per-subscription entitlement OVERRIDES. Those belong to one
--     tenant, a baseline belongs to a plan. A tenant with an override is expected to drift
--     from its baseline; the drift table reports it, and nothing removes it.
--   • It does not seed roles other than BUSINESSADMIN (PROMPT-24 §⑨ Q4 default). Other
--     role codes are configured on the screen.
--   • It never deletes or overwrites. A cell already present is left exactly as curated.
--
-- IDEMPOTENT: guarded by NOT EXISTS on the natural key (PlanId, RoleCode, MenuId,
--   CapabilityId). Re-running adds only what is missing. ADDITIVE ONLY — no DROP, no
--   UPDATE, no DELETE, no schema change.
--
-- PREREQUISITES (in order):
--   1. migration Add_PlatformStaffRbacAdmin applied (creates billing."PlanRoleBaselines")
--   2. billing-plan-catalog-seed.sql      (Plans + PlanEntitlements)
--   3. billing-feature-menu-map-seed.sql  (Features + FeatureMenuMaps)
--   4. menu/capability seeds applied      (auth."MenuCapabilities" populated)
--   Optional: ops-template-company-seed.sql + a configured __TEMPLATE__ BUSINESSADMIN,
--             which supplies the HasAccess ticks. Without it every allowed cell is true.
-- =====================================================================================

BEGIN;

-- ── 0. Which role codes to bootstrap ────────────────────────────────────────────────
-- Add rows here to bootstrap more roles. BUSINESSADMIN is the one Step 4 requires.
CREATE TEMP TABLE tmp_baseline_roles(role_code varchar(50)) ON COMMIT DROP;
INSERT INTO tmp_baseline_roles(role_code) VALUES ('BUSINESSADMIN');

-- ── 1. Every menu -> itself and each of its ancestors (depth-capped at 32) ───────────
CREATE TEMP TABLE tmp_menu_anc(menu_id int, ancestor_id int) ON COMMIT DROP;

WITH RECURSIVE walk AS (
    SELECT m."MenuId" AS menu_id, m."MenuId" AS ancestor_id, m."ParentMenuId", 0 AS depth
    FROM auth."Menus" m
    WHERE COALESCE(m."IsDeleted", false) = false
    UNION ALL
    SELECT w.menu_id, p."MenuId", p."ParentMenuId", w.depth + 1
    FROM walk w
    JOIN auth."Menus" p
      ON p."MenuId" = w."ParentMenuId"
     AND COALESCE(p."IsDeleted", false) = false
    WHERE w.depth < 32
)
INSERT INTO tmp_menu_anc(menu_id, ancestor_id)
SELECT DISTINCT menu_id, ancestor_id FROM walk;

-- ── 2. (Plan, Menu) pairs the plan BLOCKS ───────────────────────────────────────────
CREATE TEMP TABLE tmp_plan_blocked(plan_id int, menu_id int) ON COMMIT DROP;

INSERT INTO tmp_plan_blocked(plan_id, menu_id)
SELECT DISTINCT p."PlanId", a.menu_id
FROM billing."Plans" p
CROSS JOIN tmp_menu_anc a
JOIN auth."Menus" am
  ON am."MenuId" = a.ancestor_id
JOIN billing."FeatureMenuMaps" fm
  ON fm."MenuCode" = am."MenuCode"
 AND COALESCE(fm."IsDeleted", false) = false
JOIN billing."PlanEntitlements" pe
  ON pe."PlanId" = p."PlanId"
 AND pe."FeatureCode" = fm."FeatureCode"
 AND COALESCE(pe."IsDeleted", false) = false
WHERE pe."IsEnabled" = false
  AND COALESCE(p."IsDeleted", false) = false
  AND p."IsActive" = true;

-- Never-blocked prefixes win over anything the map says (mirrors PlanMenuFilter).
DELETE FROM tmp_plan_blocked b
USING auth."Menus" m
WHERE m."MenuId" = b.menu_id
  AND (   m."MenuCode" LIKE 'BILLING%'
       OR m."MenuCode" LIKE 'SETTING%'
       OR m."MenuCode" LIKE 'ACCESSCONTROL%');

-- ── 3. The __TEMPLATE__ ticks, when that company has been configured ────────────────
-- One row per (role_code, menu_id, capability_id) the template grants. Used only as the
-- HasAccess source; the ALLOWED set is decided by the plan, never by the template.
CREATE TEMP TABLE tmp_template_tick(role_code varchar(50), menu_id int, capability_id int)
  ON COMMIT DROP;

INSERT INTO tmp_template_tick(role_code, menu_id, capability_id)
SELECT r."RoleCode", rc."MenuId", rc."CapabilityId"
FROM app."Companies" c
JOIN auth."Roles" r
  ON r."CompanyId" = c."CompanyId"
 AND COALESCE(r."IsDeleted", false) = false
JOIN tmp_baseline_roles br
  ON br.role_code = r."RoleCode"
JOIN auth."RoleCapabilities" rc
  ON rc."RoleId" = r."RoleId"
 AND COALESCE(rc."IsDeleted", false) = false
 AND rc."HasAccess" = true
WHERE c."CompanyCode" = '__TEMPLATE__'
  AND COALESCE(c."IsDeleted", false) = false;

-- Role codes for which the template actually has an opinion. For any other role code we
-- grant every allowed cell rather than granting nothing — an administrator with zero
-- capabilities is the failure mode this whole prompt exists to prevent.
CREATE TEMP TABLE tmp_template_configured(role_code varchar(50)) ON COMMIT DROP;
INSERT INTO tmp_template_configured(role_code)
SELECT DISTINCT role_code FROM tmp_template_tick;

-- ── 4. Insert the baselines ─────────────────────────────────────────────────────────
INSERT INTO billing."PlanRoleBaselines"
  ("PlanId","RoleCode","MenuId","CapabilityId","HasAccess","CreatedDate","IsActive","IsDeleted")
SELECT p."PlanId", br.role_code, mc."MenuId", mc."CapabilityId", true, now(), true, false
FROM billing."Plans" p
CROSS JOIN tmp_baseline_roles br
JOIN auth."MenuCapabilities" mc
  ON COALESCE(mc."IsDeleted", false) = false
JOIN auth."Menus" m
  ON m."MenuId" = mc."MenuId"
 AND COALESCE(m."IsDeleted", false) = false
LEFT JOIN auth."Modules" mo
  ON mo."ModuleId" = m."ModuleId"
WHERE COALESCE(p."IsDeleted", false) = false
  AND p."IsActive" = true
  -- platform control-plane menus are staff-only; a tenant role never gets them
  AND COALESCE(mo."ModuleCode", '') <> 'PLATFORM'
  -- the plan must not block this menu
  AND NOT EXISTS (
        SELECT 1 FROM tmp_plan_blocked b
        WHERE b.plan_id = p."PlanId" AND b.menu_id = mc."MenuId")
  -- if the template has an opinion for this role, honour it; otherwise grant all allowed
  AND (
        NOT EXISTS (SELECT 1 FROM tmp_template_configured tc WHERE tc.role_code = br.role_code)
        OR EXISTS (SELECT 1 FROM tmp_template_tick tt
                   WHERE tt.role_code = br.role_code
                     AND tt.menu_id = mc."MenuId"
                     AND tt.capability_id = mc."CapabilityId")
      )
  -- idempotency guard on the natural key
  AND NOT EXISTS (
        SELECT 1 FROM billing."PlanRoleBaselines" x
        WHERE x."PlanId" = p."PlanId"
          AND x."RoleCode" = br.role_code
          AND x."MenuId" = mc."MenuId"
          AND x."CapabilityId" = mc."CapabilityId");

-- ── 5. Report ───────────────────────────────────────────────────────────────────────
-- A plan showing 0 cannot be provisioned onto. Fix it on the Plan Baselines screen
-- before creating a tenant on that plan.
DO $$
DECLARE
    r RECORD;
    v_template_found boolean;
BEGIN
    SELECT EXISTS (SELECT 1 FROM tmp_template_tick) INTO v_template_found;
    IF v_template_found THEN
        RAISE NOTICE 'HasAccess ticks sourced from the __TEMPLATE__ company.';
    ELSE
        RAISE NOTICE '__TEMPLATE__ has no capability rows — every plan-allowed cell was granted.';
    END IF;

    FOR r IN
        SELECT p."PlanCode",
               COALESCE(b."RoleCode", '(none)') AS role_code,
               COUNT(b."PlanRoleBaselineId")    AS cells
        FROM billing."Plans" p
        LEFT JOIN billing."PlanRoleBaselines" b
               ON b."PlanId" = p."PlanId"
              AND COALESCE(b."IsDeleted", false) = false
        WHERE COALESCE(p."IsDeleted", false) = false AND p."IsActive" = true
        GROUP BY p."PlanCode", b."RoleCode"
        ORDER BY p."PlanCode", 2
    LOOP
        IF r.cells = 0 THEN
            RAISE WARNING 'plan % / % -> 0 baseline cells. Provisioning on this plan will FAIL.',
                          r."PlanCode", r.role_code;
        ELSE
            RAISE NOTICE 'plan % / % -> % baseline cells', r."PlanCode", r.role_code, r.cells;
        END IF;
    END LOOP;
END $$;

COMMIT;

-- =====================================================================================
-- VERIFY
--
--   -- per-plan totals; every active plan must be non-zero
--   SELECT p."PlanCode", b."RoleCode", COUNT(*) AS cells
--   FROM billing."PlanRoleBaselines" b
--   JOIN billing."Plans" p ON p."PlanId" = b."PlanId"
--   WHERE COALESCE(b."IsDeleted",false) = false
--   GROUP BY p."PlanCode", b."RoleCode" ORDER BY 1,2;
--
--   -- the whole point: the plans must DIFFER. If two plans on different tiers show the
--   -- same menu list, plan gating is not reaching the baseline and D6 is still open.
--   SELECT p."PlanCode", COUNT(DISTINCT b."MenuId") AS menus
--   FROM billing."PlanRoleBaselines" b
--   JOIN billing."Plans" p ON p."PlanId" = b."PlanId"
--   WHERE COALESCE(b."IsDeleted",false) = false AND b."RoleCode" = 'BUSINESSADMIN'
--   GROUP BY p."PlanCode" ORDER BY 1;
--
--   -- spot-check one plan's menu list
--   SELECT DISTINCT m."MenuCode", m."MenuName"
--   FROM billing."PlanRoleBaselines" b
--   JOIN billing."Plans" p ON p."PlanId" = b."PlanId"
--   JOIN auth."Menus" m    ON m."MenuId" = b."MenuId"
--   WHERE p."PlanCode" = 'PLAN_50K' AND b."RoleCode" = 'BUSINESSADMIN'
--     AND COALESCE(b."IsDeleted",false) = false
--   ORDER BY 1;
-- =====================================================================================
