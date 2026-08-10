-- =============================================================================
-- MVP-1 — Withdraw non-shippable features (S4)
-- =============================================================================
-- Written     : 2026-08-10
-- Applies to  : auth."Menus", auth."RoleCapabilities", billing."PlanRoleBaselines"
-- No DDL. No migration. No new columns. Data-level configuration only.
--
-- WHY THIS SCRIPT EXISTS
--   Each feature below reports success while doing nothing. That is worse than
--   the feature being absent: a refund that says "complete" and moves no money is
--   a finance incident, not a missing feature.
--
--     REFUND               (#41,#53) never reaches the gateway; a refund is born
--                                    "complete" and writes the ledger anyway.
--     SCHEDULEDREPORT      (#10)     no execution engine; runs stick on RUNNING.
--     CUSTOMREPORTBUILDER  (#61)     preview / run / export are all fabricated.
--     MEMBERPORTAL + MP_*  (#86)     "auth" is a localStorage check. S3 blocks the
--                                    route in middleware.ts; this closes the door
--                                    in the sidebar.
--
--   The recurring-donation manual Retry (#39) is withdrawn too, but it is a button,
--   not a menu — it is removed in the frontend, in
--   crm/donation/recurringdonors/recurring-schedule-detail-drawer.tsx.
--   RECURRING DONATIONS THEMSELVES ARE IN SCOPE FOR MVP-1 AND ARE NOT TOUCHED HERE.
--   Nothing in this file references a recurring-donation menu. If you are editing
--   this script and about to add one, stop — that is an overshoot.
--
-- HOW THE HIDE WORKS — and why it is not IsActive = false, nor a DELETE
--   GetParentChildMenu.cs builds the sidebar from Menus.IsActive = true AND a
--   granted ISMENURENDER role capability. So the operative lever is the
--   ISMENURENDER revoke.
--
--   IsActive STAYS TRUE, deliberately. Setting it false takes the menu out of grid
--   capability resolution (a shared grid resolves its CRUD rights through the menu
--   row) and out of GetRoleCapabilityMatrix.cs, which filters
--   `IsDeleted = false AND IsActive = true` — the grant switch would become
--   unreachable from the role-permission UI and only a DBA could put it back.
--
--   IsVisible / IsLeastMenu are set alongside the revoke because some admin
--   surfaces read those instead of the capability.
--
--   NOTHING IS DELETED. Every menu row, capability row, MenuCapabilities pair and
--   RoleCapabilities row stays exactly where it is. MVP-2 flips them back with the
--   single REVERSAL block at the foot of this file.
--
-- WHY STEP 3 EXISTS — the revoke is not durable without it
--   PlanBaselineApplier.cs pushes billing."PlanRoleBaselines" into a tenant's
--   auth."RoleCapabilities" at provisioning and on every baseline push. It reads
--   `WHERE b.HasAccess` and, for a row that already exists with HasAccess = false,
--   it sets it BACK to true. So a STEP-1-only script survives until the next
--   provision or push and then silently un-hides all five features. STEP 3 turns
--   the same cells off in the baseline, which the applier then skips.
--
--   HasAccess = false rather than a DELETE: the baseline generator
--   (plan-role-baseline-generate-from-plan-features.sql) inserts under NOT EXISTS,
--   so a deleted row is re-created on its next run — a disabled row is not.
--
-- SAFE TO RE-RUN. Every statement is a guarded, value-stable UPDATE. Second run
-- reports 0 rows affected and no error.
-- =============================================================================

BEGIN;

-- ─── The menus being withdrawn ───────────────────────────────────────────────
-- Held once, in a temp table, so STEP 1/2/3 and the verification queries below
-- cannot drift apart. MEMBERPORTAL_AREA is deliberately NOT in this list — see
-- STEP 2b.
--
--   REFUND               crm/donation/refund
--   SCHEDULEDREPORT      reportaudit/reports/scheduledreport
--   CUSTOMREPORTBUILDER  reportaudit/reports/customreportbuilder
--   MEMBERPORTAL         setting/publicpages/memberportal   (the config screen)
--   MP_DASHBOARD / MP_PROFILE / MP_BENEFITS / MP_PAYMENTS / MP_EVENTS
--                        the Member Portal area's five leaves

CREATE TEMP TABLE tmp_mvp1_hidden_menus ("MenuCode" varchar(100) PRIMARY KEY)
ON COMMIT DROP;

INSERT INTO tmp_mvp1_hidden_menus ("MenuCode")
VALUES ('REFUND'),
       ('SCHEDULEDREPORT'),
       ('CUSTOMREPORTBUILDER'),
       ('MEMBERPORTAL'),
       ('MP_DASHBOARD'),
       ('MP_PROFILE'),
       ('MP_BENEFITS'),
       ('MP_PAYMENTS'),
       ('MP_EVENTS');

-- ─── STEP 1: revoke ISMENURENDER — the operative change ─────────────────────
-- HasAccess = false, not IsDeleted = true, so the role matrix still shows the
-- switch in its off position and MVP-2 can flip it from the UI without a DBA.
--
-- Every role is revoked, BUSINESSADMIN included: acceptance requires the entries
-- absent from the sidebar for all roles. SUPERADMIN is excluded per the house
-- rule — it is never revoked by a seed, and it is not a customer-facing login.

UPDATE auth."RoleCapabilities" rc
   SET "HasAccess"    = false,
       "ModifiedDate" = now()
  FROM auth."Menus" m, auth."Capabilities" c, auth."Roles" r
 WHERE rc."MenuId"        = m."MenuId"
   AND rc."CapabilityId"  = c."CapabilityId"
   AND rc."RoleId"        = r."RoleId"
   AND m."MenuCode"       IN (SELECT "MenuCode" FROM tmp_mvp1_hidden_menus)
   AND c."CapabilityCode" = 'ISMENURENDER'
   AND r."RoleCode"       <> 'SUPERADMIN'
   AND rc."HasAccess" IS DISTINCT FROM false;

-- ─── STEP 2: mark the rows hidden for the surfaces that read the flag ───────
-- Belt and braces. IsActive stays TRUE on purpose (see the header).

UPDATE auth."Menus"
   SET "IsVisible"    = false,
       "IsLeastMenu"  = false,
       "ModifiedDate" = now()
 WHERE "MenuCode" IN (SELECT "MenuCode" FROM tmp_mvp1_hidden_menus)
   AND ("IsVisible" IS DISTINCT FROM false OR "IsLeastMenu" IS DISTINCT FROM false);

-- ─── STEP 2b: the Member Portal group node ──────────────────────────────────
-- MEMBERPORTAL_AREA is a group (ParentMenuId NULL, MenuUrl NULL, IsLeastMenu
-- false). It carries no ISMENURENDER grant of its own — GetParentChildMenu.cs
-- collects authorised LEAVES and then walks ancestors in memory to add parents.
-- So revoking the five MP_* leaves in STEP 1 already removes the group from the
-- sidebar; there is nothing to revoke on the group itself.
--
-- IsVisible is still cleared for the admin surfaces that read the flag directly.
-- IsLeastMenu is left alone here: it is already false and it is what marks this
-- row as a group rather than a screen.

UPDATE auth."Menus"
   SET "IsVisible"    = false,
       "ModifiedDate" = now()
 WHERE "MenuCode" = 'MEMBERPORTAL_AREA'
   AND "IsVisible" IS DISTINCT FROM false;

-- ─── STEP 3: turn the same cells off in the plan baseline ───────────────────
-- Without this the next tenant provision or baseline push re-grants everything
-- STEP 1 just revoked. See the header for why this is an UPDATE and not a DELETE.

UPDATE billing."PlanRoleBaselines" b
   SET "HasAccess"    = false,
       "ModifiedDate" = now()
  FROM auth."Menus" m, auth."Capabilities" c
 WHERE b."MenuId"        = m."MenuId"
   AND b."CapabilityId"  = c."CapabilityId"
   AND m."MenuCode"      IN (SELECT "MenuCode" FROM tmp_mvp1_hidden_menus)
   AND c."CapabilityCode" = 'ISMENURENDER'
   AND b."HasAccess" IS DISTINCT FROM false;

-- ─── STEP 4: nothing else ───────────────────────────────────────────────────
-- Explicitly NOT done here, and each for a reason:
--   • Menus.IsActive — untouched. See the header.
--   • The non-ISMENURENDER capabilities on these menus (VIEW/CREATE/EDIT/DELETE)
--     — untouched. They are what the screen resolves its grid rights from if a
--     bookmark reaches the route, and they are what MVP-2 needs intact.
--   • auth."MenuCapabilities" — untouched. Removing a pair would strip the row
--     from the role matrix, i.e. remove the ability to grant it back at all.
--   • SUPERADMIN — never revoked, per the house rule.
--   • Any recurring-donation menu — untouched, by design. Retry is a frontend
--     button and is removed there.

COMMIT;

-- ─── VERIFICATION (run after commit) ─────────────────────────────────────────

-- 1) Expect 10 rows, all IsActive = true, all IsVisible = false.
--    IsActive = true is the point — do not "fix" it.
SELECT m."MenuCode", m."MenuName", m."MenuUrl",
       m."IsActive", m."IsVisible", m."IsLeastMenu"
FROM auth."Menus" m
WHERE m."MenuCode" IN ('REFUND','SCHEDULEDREPORT','CUSTOMREPORTBUILDER',
                       'MEMBERPORTAL','MEMBERPORTAL_AREA',
                       'MP_DASHBOARD','MP_PROFILE','MP_BENEFITS','MP_PAYMENTS','MP_EVENTS')
ORDER BY m."MenuCode";

-- 2) Expect 0 rows — no non-SUPERADMIN role still renders these sidebar entries.
SELECT r."RoleCode", m."MenuCode"
FROM auth."RoleCapabilities" rc
JOIN auth."Menus"        m ON m."MenuId"       = rc."MenuId"
JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
JOIN auth."Roles"        r ON r."RoleId"       = rc."RoleId"
WHERE m."MenuCode" IN ('REFUND','SCHEDULEDREPORT','CUSTOMREPORTBUILDER','MEMBERPORTAL',
                       'MP_DASHBOARD','MP_PROFILE','MP_BENEFITS','MP_PAYMENTS','MP_EVENTS')
  AND c."CapabilityCode" = 'ISMENURENDER'
  AND rc."HasAccess" = true
  AND r."RoleCode" <> 'SUPERADMIN'
ORDER BY r."RoleCode", m."MenuCode";

-- 3) Expect 0 rows — no plan baseline will push these back on at provisioning.
SELECT b."PlanId", b."RoleCode", m."MenuCode"
FROM billing."PlanRoleBaselines" b
JOIN auth."Menus"        m ON m."MenuId"       = b."MenuId"
JOIN auth."Capabilities" c ON c."CapabilityId" = b."CapabilityId"
WHERE m."MenuCode" IN ('REFUND','SCHEDULEDREPORT','CUSTOMREPORTBUILDER','MEMBERPORTAL',
                       'MP_DASHBOARD','MP_PROFILE','MP_BENEFITS','MP_PAYMENTS','MP_EVENTS')
  AND c."CapabilityCode" = 'ISMENURENDER'
  AND b."HasAccess" = true
ORDER BY b."PlanId", b."RoleCode", m."MenuCode";

-- 4) THE IMPORTANT ONE — the counter-check. Recurring donations must be
--    UNAFFECTED. Expect the recurring-donation menu still active, still visible,
--    and still granted to BUSINESSADMIN. If any of this is false, STOP: the
--    script has overshot and must be reverted.
SELECT m."MenuCode", m."MenuName", m."IsActive", m."IsVisible",
       count(rc."RoleCapabilityId") FILTER (WHERE rc."HasAccess" = true) AS granted_roles
FROM auth."Menus" m
LEFT JOIN auth."Capabilities" c
       ON c."CapabilityCode" = 'ISMENURENDER'
LEFT JOIN auth."RoleCapabilities" rc
       ON rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
WHERE m."MenuCode" LIKE 'RECURRING%'
GROUP BY m."MenuCode", m."MenuName", m."IsActive", m."IsVisible"
ORDER BY m."MenuCode";

-- 5) Nothing was destroyed — capability rows still present on the hidden menus.
--    Expect a non-zero count per menu, not zero.
SELECT m."MenuCode", count(*) AS rolecapability_rows
FROM auth."RoleCapabilities" rc
JOIN auth."Menus" m ON m."MenuId" = rc."MenuId"
WHERE m."MenuCode" IN ('REFUND','SCHEDULEDREPORT','CUSTOMREPORTBUILDER','MEMBERPORTAL',
                       'MP_DASHBOARD','MP_PROFILE','MP_BENEFITS','MP_PAYMENTS','MP_EVENTS')
GROUP BY m."MenuCode"
ORDER BY m."MenuCode";

-- ─── REVERSAL — MVP-2 restores all five features ─────────────────────────────
-- Run this ONLY once each feature actually reaches its service:
--   • Refund calls the gateway before writing the ledger
--   • Scheduled Reports has an execution engine
--   • Custom Report Builder runs and exports for real
--   • Member Portal authenticates server-side (and S3's middleware block is lifted)
-- The frontend Refund and Retry actions must be restored in the same release —
-- both are commented at their call sites, not deleted from the mutation layer.
--
--   BEGIN;
--
--   UPDATE auth."Menus"
--      SET "IsVisible" = true, "ModifiedDate" = now()
--    WHERE "MenuCode" = 'MEMBERPORTAL_AREA';
--
--   UPDATE auth."Menus"
--      SET "IsVisible" = true, "IsLeastMenu" = true, "ModifiedDate" = now()
--    WHERE "MenuCode" IN ('REFUND','SCHEDULEDREPORT','CUSTOMREPORTBUILDER','MEMBERPORTAL',
--                         'MP_DASHBOARD','MP_PROFILE','MP_BENEFITS','MP_PAYMENTS','MP_EVENTS');
--
--   UPDATE auth."RoleCapabilities" rc
--      SET "HasAccess" = true, "ModifiedDate" = now()
--     FROM auth."Menus" m, auth."Capabilities" c
--    WHERE rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
--      AND c."CapabilityCode" = 'ISMENURENDER'
--      AND m."MenuCode" IN ('REFUND','SCHEDULEDREPORT','CUSTOMREPORTBUILDER','MEMBERPORTAL',
--                           'MP_DASHBOARD','MP_PROFILE','MP_BENEFITS','MP_PAYMENTS','MP_EVENTS');
--
--   UPDATE billing."PlanRoleBaselines" b
--      SET "HasAccess" = true, "ModifiedDate" = now()
--     FROM auth."Menus" m, auth."Capabilities" c
--    WHERE b."MenuId" = m."MenuId" AND b."CapabilityId" = c."CapabilityId"
--      AND c."CapabilityCode" = 'ISMENURENDER'
--      AND m."MenuCode" IN ('REFUND','SCHEDULEDREPORT','CUSTOMREPORTBUILDER','MEMBERPORTAL',
--                           'MP_DASHBOARD','MP_PROFILE','MP_BENEFITS','MP_PAYMENTS','MP_EVENTS');
--
--   COMMIT;
--
-- NOTE: MEMBERPORTAL was already IsActive = false before this script ran. If MVP-2
-- restores the Member Portal, that row needs IsActive = true as well — the reversal
-- above deliberately does not set it, because this script never cleared it.
