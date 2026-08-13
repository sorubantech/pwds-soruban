-- ═════════════════════════════════════════════════════════════════════════════════════════════
--  billing-baseline-parent-menu-repair.sql
--
--  Repairs the missing BILLING grants on plans and tenants that already exist.
--  Idempotent. Safe to re-run. PostgreSQL.
--
--  ── THE BUG ─────────────────────────────────────────────────────────────────────────────────
--  auth."Menus" row 'BILLING' (MenuId 555) is a group menu: IsLeastMenu = false.
--  plan-role-baseline-generate-from-plan-features.sql wrote baseline cells for LEAF menus only,
--  so it emitted cells for BILLING_OVERVIEW / BILLING_PLANS / BILLING_INVOICES and reported
--  'BILLING' as SKIP-GROUP - and its section 4 then HARD-DELETED any 'BILLING' cell an earlier
--  run (or the C# PlanBaselineGenerator, which has no leaf filter) had left behind.
--
--  But CustomAuthorizeService.HasAccessAsync matches MenuCode EXACTLY, and every tenant-facing
--  billing handler is gated on the PARENT code:
--      [CustomAuthorize("BILLING", "BILLING_VIEW")]     GetMySellablePlans
--                                                       GetMyBillingOverview
--                                                       GetTenantInvoices
--      [CustomAuthorize("BILLING", "BILLING_MANAGE")]   InitiateSubscriptionCheckout
--                                                       ConfirmSubscriptionPayment
--                                                       SetAutoRenew
--
--  ProvisionTenant step 4 gives a new tenant its RoleCapabilities from billing."PlanRoleBaselines"
--  and from nowhere else (IPlanBaselineApplier.ApplyAsync, additive-only). No baseline cell on
--  'BILLING' => no RoleCapability on 'BILLING' => the Billing nav renders (ISMENURENDER sits on
--  the leaves) but every call behind it returns
--      "User is unauthorized to perform this action on the specified resource."
--  which is exactly the reported symptom set: empty plans list on upgrade, blocked billing
--  overview, 403 on checkout.
--
--  Tenants provisioned BEFORE billing-capability-seed.sql was last run are unaffected, because
--  that seed cross-joins every BUSINESSADMIN role existing at run time. That is why this looks
--  environment-dependent: old tenants work, new ones do not.
--
--  ── WHAT THIS SCRIPT DOES ───────────────────────────────────────────────────────────────────
--   1. Prerequisites - fails loudly if the BILLING menu / capability / MenuCapability rows are
--      absent, because then the real fix is to run billing-capability-seed.sql first.
--   2. billing."PlanRoleBaselines" - adds the 'BILLING' + BILLING_VIEW / BILLING_MANAGE cells for
--      RoleCode 'BUSINESSADMIN' on every plan that already has billing leaf cells. Plans with no
--      baseline at all are left alone (same invariant as the generator: never invent a baseline).
--      ISMENURENDER is deliberately NOT added on the parent - the nav walks parents up from
--      authorized leaves, and a render grant on the header would leave an empty "Billing" label
--      behind if the leaves were ever revoked.
--   3. auth."RoleCapabilities" - back-fills the same two grants for every already-provisioned
--      tenant's BUSINESSADMIN role (plus SUPERADMIN), revives soft-deleted / HasAccess=false rows
--      rather than inserting a duplicate, and never touches any other role.
--   4. Verification output.
--
--  ── AFTER RUNNING ───────────────────────────────────────────────────────────────────────────
--   · Affected users must SIGN OUT AND BACK IN - capabilities are resolved at login.
--   · Fix already applied to the generator (SKIP-GROUP branch now exempts BILLING%), so the next
--     regenerate will not delete these rows again.
-- ═════════════════════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. Prerequisites ────────────────────────────────────────────────────────────────────────
DO $pre$
DECLARE
    v_menu_id int;
    v_caps    int;
    v_mcaps   int;
BEGIN
    SELECT m."MenuId" INTO v_menu_id
    FROM   auth."Menus" m
    WHERE  upper(m."MenuCode") = 'BILLING'
      AND  m."IsDeleted" IS DISTINCT FROM true
    LIMIT  1;

    IF v_menu_id IS NULL THEN
        RAISE EXCEPTION 'auth."Menus" has no live BILLING row. Run billing-capability-seed.sql first.';
    END IF;

    SELECT count(*) INTO v_caps
    FROM   auth."Capabilities" c
    WHERE  upper(c."CapabilityCode") IN ('BILLING_VIEW','BILLING_MANAGE')
      AND  c."IsDeleted" IS DISTINCT FROM true
      AND  c."IsActive"  IS DISTINCT FROM false;

    IF v_caps < 2 THEN
        RAISE EXCEPTION 'BILLING_VIEW / BILLING_MANAGE missing from auth."Capabilities" (found %). Run billing-capability-seed.sql first.', v_caps;
    END IF;

    -- Not read by HasAccessAsync, but the Access Control screen enumerates it - without these the
    -- grants below are invisible and un-manageable in the UI.
    SELECT count(*) INTO v_mcaps
    FROM   auth."MenuCapabilities" mc
    JOIN   auth."Capabilities"     c ON c."CapabilityId" = mc."CapabilityId"
    WHERE  mc."MenuId" = v_menu_id
      AND  upper(c."CapabilityCode") IN ('BILLING_VIEW','BILLING_MANAGE')
      AND  mc."IsDeleted" IS DISTINCT FROM true;

    IF v_mcaps < 2 THEN
        RAISE EXCEPTION 'auth."MenuCapabilities" is missing BILLING_VIEW / BILLING_MANAGE on the BILLING menu (found %). Run billing-capability-seed.sql first.', v_mcaps;
    END IF;

    RAISE NOTICE 'prerequisites OK - BILLING MenuId = %', v_menu_id;
END
$pre$;

-- Resolved once, reused by both writes.
CREATE TEMP TABLE tmp_billing_cell ON COMMIT DROP AS
SELECT m."MenuId", c."CapabilityId", upper(c."CapabilityCode") AS cap_code
FROM   auth."Menus" m
CROSS  JOIN auth."Capabilities" c
WHERE  upper(m."MenuCode") = 'BILLING'
  AND  m."IsDeleted" IS DISTINCT FROM true
  AND  upper(c."CapabilityCode") IN ('BILLING_VIEW','BILLING_MANAGE')
  AND  c."IsDeleted" IS DISTINCT FROM true
  AND  c."IsActive"  IS DISTINCT FROM false;

-- ── 2. billing."PlanRoleBaselines" - so NEW tenants provision correctly ─────────────────────
-- Scope: plans that already carry BUSINESSADMIN cells on a billing LEAF. A plan with no baseline
-- at all is not given one here; that is the generator's job and inventing one would hand a plan
-- grants nobody configured.
CREATE TEMP TABLE tmp_target_plan ON COMMIT DROP AS
SELECT DISTINCT b."PlanId"
FROM   billing."PlanRoleBaselines" b
JOIN   auth."Menus" m ON m."MenuId" = b."MenuId"
WHERE  upper(b."RoleCode") = 'BUSINESSADMIN'
  AND  b."IsDeleted" IS DISTINCT FROM true
  AND  b."HasAccess" = true
  AND  upper(m."MenuCode") IN ('BILLING_OVERVIEW','BILLING_PLANS','BILLING_INVOICES');

-- 2a. revive rows that exist but are soft-deleted / inactive / HasAccess = false.
-- The unique index on (PlanId, RoleCode, MenuId, CapabilityId) ignores IsDeleted, so a plain
-- insert would collide instead of adding.
UPDATE billing."PlanRoleBaselines" b
SET    "HasAccess"    = true,
       "IsActive"     = true,
       "IsDeleted"    = false,
       "ModifiedDate" = now()
FROM   tmp_billing_cell x
WHERE  b."PlanId" IN (SELECT "PlanId" FROM tmp_target_plan)
  AND  upper(b."RoleCode") = 'BUSINESSADMIN'
  AND  b."MenuId"       = x."MenuId"
  AND  b."CapabilityId" = x."CapabilityId"
  AND  (b."IsDeleted" = true OR b."HasAccess" = false OR b."IsActive" IS DISTINCT FROM true);

-- 2b. insert the ones that are not there at all.
INSERT INTO billing."PlanRoleBaselines"
       ("PlanId", "RoleCode", "MenuId", "CapabilityId", "HasAccess", "IsActive", "IsDeleted", "CreatedDate")
SELECT p."PlanId", 'BUSINESSADMIN', x."MenuId", x."CapabilityId", true, true, false, now()
FROM   tmp_target_plan p
CROSS  JOIN tmp_billing_cell x
WHERE  NOT EXISTS (
           SELECT 1 FROM billing."PlanRoleBaselines" b
           WHERE  b."PlanId"          = p."PlanId"
             AND  upper(b."RoleCode") = 'BUSINESSADMIN'
             AND  b."MenuId"          = x."MenuId"
             AND  b."CapabilityId"    = x."CapabilityId"
       );

-- ── 3. auth."RoleCapabilities" - so EXISTING tenants are unblocked without re-provisioning ──
-- BUSINESSADMIN of every tenant, plus the platform SUPERADMIN. No other role is touched: curated
-- roles (FINANCE, FUNDRAISER, …) are configured by hand and this script must not widen them.
CREATE TEMP TABLE tmp_target_role ON COMMIT DROP AS
SELECT r."RoleId"
FROM   auth."Roles" r
WHERE  upper(r."RoleCode") IN ('BUSINESSADMIN','SUPERADMIN')
  AND  r."IsDeleted" IS DISTINCT FROM true;

-- 3a. revive existing rows.
UPDATE auth."RoleCapabilities" rc
SET    "HasAccess"    = true,
       "IsActive"     = true,
       "IsDeleted"    = false,
       "ModifiedDate" = now()
FROM   tmp_billing_cell x
WHERE  rc."RoleId" IN (SELECT "RoleId" FROM tmp_target_role)
  AND  rc."MenuId"       = x."MenuId"
  AND  rc."CapabilityId" = x."CapabilityId"
  AND  (rc."IsDeleted" = true OR rc."HasAccess" = false OR rc."IsActive" IS DISTINCT FROM true);

-- 3b. insert the missing ones.
INSERT INTO auth."RoleCapabilities"
       ("RoleId", "MenuId", "CapabilityId", "HasAccess", "CreatedDate", "IsActive", "IsDeleted")
SELECT t."RoleId", x."MenuId", x."CapabilityId", true, now(), true, false
FROM   tmp_target_role t
CROSS  JOIN tmp_billing_cell x
WHERE  NOT EXISTS (
           SELECT 1 FROM auth."RoleCapabilities" rc
           WHERE  rc."RoleId"       = t."RoleId"
             AND  rc."MenuId"       = x."MenuId"
             AND  rc."CapabilityId" = x."CapabilityId"
       );

-- ── 4. Verification ─────────────────────────────────────────────────────────────────────────
-- Result 1: plans, and whether the parent grant is now present. Expect 2 for every row.
SELECT p."PlanCode",
       count(*) FILTER (WHERE upper(c."CapabilityCode") = 'BILLING_VIEW')   AS view_cell,
       count(*) FILTER (WHERE upper(c."CapabilityCode") = 'BILLING_MANAGE') AS manage_cell
FROM   billing."Plans" p
JOIN   tmp_target_plan tp        ON tp."PlanId" = p."PlanId"
LEFT   JOIN billing."PlanRoleBaselines" b
       ON  b."PlanId" = p."PlanId"
       AND upper(b."RoleCode") = 'BUSINESSADMIN'
       AND b."IsDeleted" IS DISTINCT FROM true
       AND b."HasAccess" = true
       AND b."MenuId" IN (SELECT "MenuId" FROM tmp_billing_cell)
LEFT   JOIN auth."Capabilities" c ON c."CapabilityId" = b."CapabilityId"
GROUP  BY p."PlanCode"
ORDER  BY p."PlanCode";

-- Result 2: tenants whose BUSINESSADMIN still cannot call a billing endpoint. Expect ZERO rows.
SELECT r."CompanyId", r."RoleId", r."RoleCode"
FROM   auth."Roles" r
WHERE  upper(r."RoleCode") = 'BUSINESSADMIN'
  AND  r."IsDeleted" IS DISTINCT FROM true
  AND  NOT EXISTS (
           SELECT 1
           FROM   auth."RoleCapabilities" rc
           JOIN   tmp_billing_cell x ON x."MenuId" = rc."MenuId" AND x."CapabilityId" = rc."CapabilityId"
           WHERE  rc."RoleId" = r."RoleId"
             AND  rc."HasAccess" = true
             AND  rc."IsDeleted" IS DISTINCT FROM true
       )
ORDER  BY r."CompanyId";

COMMIT;

-- Reminder: affected users must sign out and back in before the new grants take effect.
