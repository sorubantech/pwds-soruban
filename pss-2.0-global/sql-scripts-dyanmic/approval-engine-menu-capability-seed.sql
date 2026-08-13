-- =============================================================================
-- PSS 2.0 — Generic Approval Engine: menus + capabilities (§⑨ of
-- PSS-2.0-APPROVAL-ENGINE-BUILD-PROMPT.md)
--
-- Registers the three surfaces the engine needs, on both homes:
--
--   TENANT (app / Next.js "(core)")
--     APPROVALSETTING   setting/dataconfig/approvals   the switchboard — one row per
--                                                      registered area, with the step ladder
--                                                      under each switched-on row.
--     MYAPPROVALS       /approvals                     the personal queue — requests where the
--                                                      signed-in user is a pending approver.
--
--   PLATFORM (ops / Next.js "(master)")
--     PLATFORM_APPROVALS  /ops/approvals               the control-plane twin of both, one
--                                                      screen, under the control-plane root.
--
-- WHAT THESE MENUS DECIDE, AND WHAT THEY DO NOT
-- ---------------------------------------------
--   APPROVALSETTING gates CONFIGURATION: turning approval on for an area and authoring its
--   ladder (approvalSettings / approvalPolicy queries, updateApprovalSetting /
--   saveApprovalPolicy mutations). It does NOT decide who may approve anything — that is the
--   policy's own approver list, snapshotted onto the request and evaluated at runtime.
--
--   MYAPPROVALS gates the QUEUE and the act of deciding. Holding APPROVEREQUEST here is
--   necessary but not sufficient: ApprovalService still checks that the caller is an eligible
--   approver for the request's current step per its snapshot, and honours AllowSelfApprove. A
--   user with APPROVEREQUEST who is on nobody's ladder sees an empty queue — correctly, and
--   without a permission error.
--
--   SENDFORAPPROVAL on MYAPPROVALS gates the explicit submitForApproval mutation. It is NOT
--   what routes a grant when SubmitGrantApplication runs, nor what routes a tenant when
--   LaunchTenant runs — those call the engine internally, behind their own existing
--   capabilities (Grant/MODIFY and PLATFORM_TENANT_PROVISION respectively). Nobody needs
--   SENDFORAPPROVAL to keep doing what they do today.
--
-- SCHEMA NOTE — do NOT qualify these with `app`:
--   auth."Modules" / "Menus" / "Capabilities" / "MenuCapabilities" / "Roles" / "RoleCapabilities"
--
-- TWO SEPARATE CHECKS, BOTH REQUIRED:
--   1. API authorization  — auth."RoleCapabilities" joining Role → Menu(MenuCode) → Capability.
--                           auth."MenuCapabilities" is NOT consulted by HasAccessAsync.
--   2. Sidebar rendering  — the nav is built from menus the user holds ISMENURENDER on. A menu
--                           with READ but no ISMENURENDER grant is reachable by URL and
--                           completely invisible in the nav.
--   auth."MenuCapabilities" is still seeded because it is what the role matrix enumerates —
--   omit it and these grants become unmanageable through the Access Control screen.
--
-- ISMENURENDER is NEVER inserted here. It is a base-app capability that already exists in every
-- environment, and creating a second row for it would split every existing grant in two.
--
-- MenuUrl conventions differ by depth, and both are deliberate — MenuUrl is how the nav builder
-- and the sidebar active-state matcher identify a row, so each menu matches ITS OWN siblings:
--   • APPROVALSETTING     NO leading slash — 'setting/dataconfig/approvals', matching its
--                         siblings under Settings → Data (MASTERDATA, RECYCLEBIN,
--                         ORGANIZATIONBANKACCOUNT).
--   • MYAPPROVALS         LEADING slash — '/approvals', matching root-level leaves (CRM_MENTIONS).
--   • PLATFORM_APPROVALS  LEADING slash — '/ops/approvals', matching the control-plane tree.
--
-- MYAPPROVALS SITS IN THE SETTING MODULE WITH NO PARENT. It is a root-level leaf, so
-- BuildMenuHierarchy emits it at the top of that module's tree rather than buried under
-- Settings → Data. SETTING is where the backend already groups it (DecoratorSettingModules
-- .MyApprovals), and keeping the two engine screens in one module keeps the role matrix
-- readable. If the business would rather see it elsewhere, that is a one-line UPDATE of
-- "ModuleId" / "OrderBy" — nothing in the engine reads the module.
--
-- NO ApprovalSetting ROWS ARE SEEDED. Approval is off by default, and default-off is the
-- ABSENCE of a row, not a row with IsApprovalEnabled = false (§④.2 — the switchboard is lazily
-- materialised). Seeding twelve disabled rows would make the switchboard look configured and
-- would pre-commit every tenant to the descriptor list as it stands today.
--
-- SUPERADMIN is inserted-if-absent only, matched by RoleCode ALONE, and is never revoked or
-- overwritten (⚠ Rule 7). Nothing in this file replaces an existing grant; if a future revision
-- ever needs to, it must soft-delete (IsDeleted = true, IsActive = false) — never DELETE.
--
-- NO DDL. The twelve app.Approval* / ops.PlatformApproval* tables come from an EF migration,
-- which is a separate, user-authored step (§⑧). This script never creates a table.
--
-- SAFE TO RE-RUN. Idempotent throughout.
-- =============================================================================

BEGIN;

-- ─── STEP 0: Guards ──────────────────────────────────────────────────────────
-- Fail loudly on a missing prerequisite rather than half-applying. A NOT EXISTS-guarded INSERT
-- whose parent lookup returns NULL still inserts — as an orphan at the root of the tree — and a
-- guarded grant whose join matches nothing inserts zero rows and reports success. That silence
-- is the failure mode this block exists to prevent.
DO $$
DECLARE
  v_setting_module int;
  v_dataconfig     int;
  v_platform_mod   int;
  v_platform_root  int;
BEGIN
  SELECT COUNT(*) INTO v_setting_module FROM auth."Modules" WHERE "ModuleCode" = 'SETTING';
  IF v_setting_module = 0 THEN
    RAISE EXCEPTION 'Module SETTING not found — this is a base-app row. Restore it before seeding.';
  END IF;

  SELECT COUNT(*) INTO v_dataconfig FROM auth."Menus" WHERE "MenuCode" = 'SET_DATACONFIG';
  IF v_dataconfig = 0 THEN
    RAISE EXCEPTION 'Menu SET_DATACONFIG not found — APPROVALSETTING would be orphaned at the tree root.';
  END IF;

  SELECT COUNT(*) INTO v_platform_mod FROM auth."Modules" WHERE "ModuleCode" = 'PLATFORM';
  IF v_platform_mod = 0 THEN
    RAISE EXCEPTION 'Module PLATFORM not found. Apply ops-platform-rbac-seed.sql first.';
  END IF;

  SELECT COUNT(*) INTO v_platform_root FROM auth."Menus" WHERE "MenuCode" = 'PLATFORMCONTROLPLANE';
  IF v_platform_root = 0 THEN
    RAISE EXCEPTION 'Menu PLATFORMCONTROLPLANE not found. Apply ops-platform-rbac-seed.sql first.';
  END IF;
END $$;

-- ─── STEP 1: Capabilities ────────────────────────────────────────────────────
-- READ / MODIFY / SENDFORAPPROVAL / APPROVEREQUEST are base-app capabilities that already exist
-- in every environment (the last two arrive with seed_program_approval_capabilities.sql); the
-- insert below is a safety net, not the normal path. The guard checks CapabilityName as well as
-- CapabilityCode because auth."Capabilities" carries a UNIQUE index on (CapabilityName,
-- IsActive) — guarding on the code alone would collide with an existing row sharing the name.
INSERT INTO auth."Capabilities"(
    "CapabilityName", "CapabilityCode", "Description", "IsSpecial", "OrderBy",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT v.cap_name, v.cap_code, v.cap_desc, false, v.order_by, 2, now(), null, null, true, false
FROM (VALUES
  ('Read',              'READ',            'View records on a screen.',                                  1),
  ('Modify',            'MODIFY',          'Edit existing records on a screen.',                         3),
  ('Send for Approval', 'SENDFORAPPROVAL', 'Submit a draft/rejected record into the approval workflow.', 84),
  ('Approve Request',   'APPROVEREQUEST',  'Approve or reject a record pending approval.',               85)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityCode" = v.cap_code)
  AND NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- The three platform capabilities ARE new — nothing else in the control plane confers them.
-- Names carry the "Platform " prefix for the same UNIQUE index, and the guard checks the NAME
-- (the constrained column). IsSpecial = true: these are not part of the generic
-- READ/CREATE/MODIFY grid family.
--
-- VIEW and MANAGE are split for the same reason they are split on the tenant side: reading who
-- is holding a tenant launch is a support question, rewriting the ladder that decides it is not.
-- ACT is separate again — a platform operator who may not author policy may still be ON one.
INSERT INTO auth."Capabilities"(
    "CapabilityName", "CapabilityCode", "Description", "IsSpecial", "OrderBy",
    "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT v.cap_name, v.cap_code, v.cap_desc, true, v.order_by, 2, now(), null, null, true, false
FROM (VALUES
  ('Platform View Approvals',   'PLATFORM_APPROVAL_VIEW',
   'Read the control-plane approval switchboard, its policies, and every platform approval request.', 105),
  ('Platform Manage Approvals', 'PLATFORM_APPROVAL_MANAGE',
   'Turn platform approval on or off for an area and author its step ladder. Does not confer the right to decide a request.', 106),
  ('Platform Act on Approvals', 'PLATFORM_APPROVAL_ACT',
   'Submit, approve, reject, request revision on or withdraw a platform approval request — subject to being an eligible approver on the request''s own snapshotted step.', 107)
) AS v(cap_name, cap_code, cap_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Capabilities" c WHERE c."CapabilityName" = v.cap_name);

-- ─── STEP 2a: Menu — APPROVALSETTING (Settings → Data) ───────────────────────
-- Parent is resolved BY MenuCode, never hardcoded to an id, so this lands correctly in every
-- environment. OrderBy 91 puts it immediately after Recently Deleted (90) at the end of the run.
INSERT INTO auth."Menus"(
    "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description",
    "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "IsLeastMenu", "IsVisible")
SELECT
    'Approvals', 'APPROVALSETTING',
    (SELECT "MenuId" FROM auth."Menus" WHERE "MenuCode" = 'SET_DATACONFIG'),
    'solar:clipboard-check-bold',
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = 'SETTING'),
    'setting/dataconfig/approvals',
    'Turn approval on for an area and author who signs off, in what order. Off by default — switch it on only where it is needed.',
    91, 2, now(), null, null,
    true, false, true, true
WHERE NOT EXISTS (
    SELECT 1 FROM auth."Menus" WHERE "MenuCode" = 'APPROVALSETTING'
);

-- Repair an already-present row (url drift / soft-deleted / demoted to a non-leaf).
-- Guarded on the wrong values, so this is a no-op once the row is correct.
UPDATE auth."Menus"
SET "MenuUrl"      = 'setting/dataconfig/approvals',
    "IsLeastMenu"  = true,
    "IsActive"     = true,
    "IsVisible"    = true,
    "IsDeleted"    = false,
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE "MenuCode" = 'APPROVALSETTING'
  AND (
        "MenuUrl"     IS DISTINCT FROM 'setting/dataconfig/approvals'
     OR "IsLeastMenu" IS DISTINCT FROM true
     OR "IsActive"    IS DISTINCT FROM true
     OR "IsVisible"   IS DISTINCT FROM true
     OR "IsDeleted"   IS DISTINCT FROM false
  );

-- ─── STEP 2b: Menu — MYAPPROVALS (root-level leaf) ───────────────────────────
-- ParentMenuId NULL with a MenuUrl: BuildMenuHierarchy emits it at the top of the SETTING tree
-- with LeastMenu = true (LeastMenu is computed from ChildMenus.Count, not read from the column).
-- A personal work queue is not a sub-area of configuration, so it has no natural parent.
INSERT INTO auth."Menus"(
    "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description",
    "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "IsLeastMenu", "IsVisible")
SELECT
    'My Approvals', 'MYAPPROVALS',
    NULL,
    'solar:hand-stars-bold',
    (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = 'SETTING'),
    '/approvals',
    'Requests waiting on you, with their full decision history. Approve, reject, or send back for revision.',
    1, 2, now(), null, null,
    true, false, true, true
WHERE NOT EXISTS (
    SELECT 1 FROM auth."Menus" WHERE "MenuCode" = 'MYAPPROVALS'
);

UPDATE auth."Menus"
SET "MenuUrl"      = '/approvals',
    "IsLeastMenu"  = true,
    "IsActive"     = true,
    "IsVisible"    = true,
    "IsDeleted"    = false,
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE "MenuCode" = 'MYAPPROVALS'
  AND (
        "MenuUrl"     IS DISTINCT FROM '/approvals'
     OR "IsLeastMenu" IS DISTINCT FROM true
     OR "IsActive"    IS DISTINCT FROM true
     OR "IsVisible"   IS DISTINCT FROM true
     OR "IsDeleted"   IS DISTINCT FROM false
  );

-- ─── STEP 2c: Menu — PLATFORM_APPROVALS (control-plane twin) ─────────────────
-- One menu, not two: the control plane has a single registered area (TENANT_LAUNCH), so
-- splitting its switchboard from its queue would produce two screens each showing one row.
-- OrderBy 960 sits it after Tenant Access Control (955).
INSERT INTO auth."Menus"(
    "MenuName", "MenuCode", "ParentMenuId", "MenuIcon", "ModuleId", "MenuUrl", "Description",
    "OrderBy", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted", "IsLeastMenu", "IsVisible")
SELECT
    'Approvals', 'PLATFORM_APPROVALS',
    (SELECT p."MenuId" FROM auth."Menus" p WHERE p."MenuCode" = 'PLATFORMCONTROLPLANE'),
    'solar:clipboard-check-bold',
    (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'PLATFORM'),
    '/ops/approvals',
    'Control-plane approval: which platform actions require sign-off, who signs off, and every request in flight. Tenant launch is the area this governs today.',
    960, 2, now(), null, null,
    true, false, true, true
WHERE NOT EXISTS (
    SELECT 1 FROM auth."Menus" WHERE "MenuCode" = 'PLATFORM_APPROVALS'
);

UPDATE auth."Menus"
SET "MenuUrl"      = '/ops/approvals',
    "IsLeastMenu"  = true,
    "IsActive"     = true,
    "IsVisible"    = true,
    "IsDeleted"    = false,
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE "MenuCode" = 'PLATFORM_APPROVALS'
  AND (
        "MenuUrl"     IS DISTINCT FROM '/ops/approvals'
     OR "IsLeastMenu" IS DISTINCT FROM true
     OR "IsActive"    IS DISTINCT FROM true
     OR "IsVisible"   IS DISTINCT FROM true
     OR "IsDeleted"   IS DISTINCT FROM false
  );

-- ─── STEP 3: MenuCapabilities — what the role matrix can offer ───────────────
-- The role matrix builds its ROWS from menus that have >= 1 MenuCapability and skips any menu
-- whose capability list is empty. Without this block the menus exist and the backend enforces
-- the capabilities, but nobody could ever grant them through the UI.
--
-- APPROVALSETTING gets READ + MODIFY only. No CREATE and no DELETE: the switchboard is lazily
-- materialised, so "create" and "delete" are not user-facing acts — turning an area off leaves
-- its row and its ladder in place, ready to be turned back on.
INSERT INTO auth."MenuCapabilities"(
    "MenuId", "CapabilityId", "CreatedBy", "CreatedDate", "ModifiedBy", "ModifiedDate",
    "IsActive", "IsDeleted")
SELECT m."MenuId", c."CapabilityId", 2, now(), null, null, true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE (
        (m."MenuCode" = 'APPROVALSETTING'
           AND c."CapabilityCode" IN ('READ', 'MODIFY', 'ISMENURENDER'))
     OR (m."MenuCode" = 'MYAPPROVALS'
           AND c."CapabilityCode" IN ('READ', 'SENDFORAPPROVAL', 'APPROVEREQUEST', 'ISMENURENDER'))
     OR (m."MenuCode" = 'PLATFORM_APPROVALS'
           AND c."CapabilityCode" IN ('PLATFORM_APPROVAL_VIEW', 'PLATFORM_APPROVAL_MANAGE',
                                      'PLATFORM_APPROVAL_ACT'))
      )
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
      SELECT 1 FROM auth."MenuCapabilities" mc
      WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

-- Re-activate any that were previously superseded.
UPDATE auth."MenuCapabilities" mc
SET "IsActive" = true, "IsDeleted" = false, "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m
WHERE mc."MenuId" = m."MenuId"
  AND m."MenuCode" IN ('APPROVALSETTING', 'MYAPPROVALS', 'PLATFORM_APPROVALS')
  AND (mc."IsActive" = false OR mc."IsDeleted" = true);

-- ─── STEP 4a: Tenant role grants — BUSINESSADMIN, per tenant ─────────────────
-- BUSINESSADMIN gets the full engine: it configures the ladders AND, as the tenant's
-- administrator, is the party most often standing on one. APPROVEREQUEST here still does not
-- let it decide a request it is not an eligible approver for — the snapshot decides that.
--
-- No other tenant role is granted anything here. Approval is off by default, so nothing is
-- broken by that; widen it through the Access Control screen when a tenant turns the engine on
-- and puts other roles on a ladder — not by editing this file after it has been applied.
INSERT INTO auth."RoleCapabilities"(
    "RoleId", "MenuId", "CapabilityId", "HasAccess", "CreatedBy", "CreatedDate",
    "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, 2, now(), null, null, true, false
FROM auth."Roles" r
CROSS JOIN auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE r."RoleCode" = 'BUSINESSADMIN'
  AND r."IsDeleted" IS NOT TRUE
  AND (
        (m."MenuCode" = 'APPROVALSETTING'
           AND c."CapabilityCode" IN ('READ', 'MODIFY', 'ISMENURENDER'))
     OR (m."MenuCode" = 'MYAPPROVALS'
           AND c."CapabilityCode" IN ('READ', 'SENDFORAPPROVAL', 'APPROVEREQUEST', 'ISMENURENDER'))
      )
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
      SELECT 1 FROM auth."RoleCapabilities" rc
      WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
  );

-- Re-activate BUSINESSADMIN grants only. SUPERADMIN is deliberately excluded from this UPDATE:
-- its rows are inserted if absent (4c) and otherwise left exactly as an administrator set them.
UPDATE auth."RoleCapabilities" rc
SET "HasAccess" = true, "IsActive" = true, "IsDeleted" = false, "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m, auth."Roles" r
WHERE rc."MenuId" = m."MenuId" AND rc."RoleId" = r."RoleId"
  AND m."MenuCode" IN ('APPROVALSETTING', 'MYAPPROVALS')
  AND r."RoleCode" = 'BUSINESSADMIN'
  AND (rc."HasAccess" = false OR rc."IsActive" = false OR rc."IsDeleted" = true);

-- ─── STEP 4b: Platform role grants ───────────────────────────────────────────
-- PLATFORM_ADMIN gets all three. PLATFORM_SUPPORT and PLATFORM_IMPLEMENTATION get VIEW only —
-- reading who is holding a launch answers a support call; rewriting the ladder that decides it
-- is a different authority. ACT is not handed out broadly: being able to press Approve is the
-- decision itself, and the operators who should hold it are the ones a platform administrator
-- deliberately places on a ladder.
--
-- Joined with `r."CompanyId" IS NULL` — these are the platform's own global roles. SUPERADMIN is
-- handled separately in 4c precisely because that predicate cannot be assumed for it.
INSERT INTO auth."RoleCapabilities"(
    "RoleId", "MenuId", "CapabilityId", "HasAccess", "CreatedBy", "CreatedDate",
    "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, 2, now(), null, null, true, false
FROM (VALUES
  ('PLATFORM_ADMIN',          'PLATFORM_APPROVAL_VIEW'),
  ('PLATFORM_ADMIN',          'PLATFORM_APPROVAL_MANAGE'),
  ('PLATFORM_ADMIN',          'PLATFORM_APPROVAL_ACT'),
  ('PLATFORM_SUPPORT',        'PLATFORM_APPROVAL_VIEW'),
  ('PLATFORM_IMPLEMENTATION', 'PLATFORM_APPROVAL_VIEW')
) AS v(role_code, cap_code)
JOIN auth."Roles"        r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL
                          AND COALESCE(r."IsDeleted", false) = false
JOIN auth."Menus"        m ON m."MenuCode" = 'PLATFORM_APPROVALS'
JOIN auth."Capabilities" c ON c."CapabilityCode" = v.cap_code
                          AND COALESCE(c."IsDeleted", false) = false
WHERE NOT EXISTS (
  SELECT 1 FROM auth."RoleCapabilities" rc
  WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
);

-- ─── STEP 4c: SUPERADMIN ─────────────────────────────────────────────────────
-- Matched by RoleCode ALONE — deliberately no CompanyId predicate. ops-platform-rbac-seed.sql
-- joins SUPERADMIN with `AND r."CompanyId" IS NULL`; if the SUPERADMIN row in this database is
-- not CompanyId-null, that join silently inserted nothing and reported success. Do not add the
-- predicate back here.
--
-- Insert-if-absent only: nothing in this block revokes or overwrites an existing SUPERADMIN row
-- (⚠ Rule 7 — that rule forbids taking authority away from SUPERADMIN, not giving it).
INSERT INTO auth."RoleCapabilities"(
    "RoleId", "MenuId", "CapabilityId", "HasAccess", "CreatedBy", "CreatedDate",
    "ModifiedBy", "ModifiedDate", "IsActive", "IsDeleted")
SELECT r."RoleId", m."MenuId", c."CapabilityId", true, 2, now(), null, null, true, false
FROM auth."Roles" r
CROSS JOIN auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE r."RoleCode" = 'SUPERADMIN'
  AND r."IsDeleted" IS NOT TRUE
  AND (
        (m."MenuCode" = 'APPROVALSETTING'
           AND c."CapabilityCode" IN ('READ', 'MODIFY', 'ISMENURENDER'))
     OR (m."MenuCode" = 'MYAPPROVALS'
           AND c."CapabilityCode" IN ('READ', 'SENDFORAPPROVAL', 'APPROVEREQUEST', 'ISMENURENDER'))
     OR (m."MenuCode" = 'PLATFORM_APPROVALS'
           AND c."CapabilityCode" IN ('PLATFORM_APPROVAL_VIEW', 'PLATFORM_APPROVAL_MANAGE',
                                      'PLATFORM_APPROVAL_ACT'))
      )
  AND COALESCE(c."IsDeleted", false) = false
  AND NOT EXISTS (
      SELECT 1 FROM auth."RoleCapabilities" rc
      WHERE rc."RoleId" = r."RoleId" AND rc."MenuId" = m."MenuId" AND rc."CapabilityId" = c."CapabilityId"
  );

COMMIT;

-- ─── VERIFICATION (run after commit) ─────────────────────────────────────────

-- All three menus, with their resolved parents (expect 3 rows; APPROVALSETTING parented by
-- SET_DATACONFIG, PLATFORM_APPROVALS by PLATFORMCONTROLPLANE, MYAPPROVALS parent NULL by design):
SELECT m."MenuCode", m."MenuName", m."MenuUrl", p."MenuCode" AS parent, md."ModuleCode",
       m."OrderBy", m."IsLeastMenu", m."IsVisible", m."IsActive"
FROM auth."Menus" m
LEFT JOIN auth."Menus"   p  ON p."MenuId"   = m."ParentMenuId"
LEFT JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId"
WHERE m."MenuCode" IN ('APPROVALSETTING', 'MYAPPROVALS', 'PLATFORM_APPROVALS')
ORDER BY m."MenuCode";
-- A NULL parent on APPROVALSETTING or PLATFORM_APPROVALS means the parent lookup missed — fix it
-- before shipping, or the screen renders but never appears in the sidebar.

-- No other menu claims these paths (expect exactly 3 rows, one per path):
SELECT "MenuUrl", count(*) AS claimants, string_agg("MenuCode", ', ') AS codes
FROM auth."Menus"
WHERE "MenuUrl" IN ('setting/dataconfig/approvals', '/approvals', '/ops/approvals')
  AND COALESCE("IsDeleted", false) = false
GROUP BY "MenuUrl";

-- MenuCapabilities registered (expect APPROVALSETTING 3, MYAPPROVALS 4, PLATFORM_APPROVALS 3):
SELECT m."MenuCode", c."CapabilityCode"
FROM auth."MenuCapabilities" mc
JOIN auth."Menus" m        ON m."MenuId"       = mc."MenuId"
JOIN auth."Capabilities" c ON c."CapabilityId" = mc."CapabilityId"
WHERE m."MenuCode" IN ('APPROVALSETTING', 'MYAPPROVALS', 'PLATFORM_APPROVALS')
  AND COALESCE(mc."IsDeleted", false) = false
ORDER BY m."MenuCode", c."CapabilityCode";

-- Who can reach what (expect each tenant's BUSINESSADMIN with 7 tenant-side rows, SUPERADMIN
-- with 10, PLATFORM_ADMIN with 3, PLATFORM_SUPPORT / PLATFORM_IMPLEMENTATION with 1 each):
SELECT r."RoleCode", r."CompanyId", m."MenuCode", c."CapabilityCode", rc."HasAccess"
FROM auth."RoleCapabilities" rc
JOIN auth."Roles" r        ON r."RoleId"       = rc."RoleId"
JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
JOIN auth."Menus" m        ON m."MenuId"       = rc."MenuId"
WHERE m."MenuCode" IN ('APPROVALSETTING', 'MYAPPROVALS', 'PLATFORM_APPROVALS')
  AND COALESCE(rc."IsDeleted", false) = false
ORDER BY r."RoleCode", r."CompanyId", m."MenuCode", c."CapabilityCode";

-- The engine tables exist and this script created nothing in them (expect 0 and 0):
SELECT (SELECT count(*) FROM app."ApprovalSettings")          AS tenant_switchboard_rows,
       (SELECT count(*) FROM ops."PlatformApprovalSettings")  AS platform_switchboard_rows;
-- "relation does not exist" here means the EF migration from §⑧ has not been applied yet. The
-- menus will render and the screens will error until it is.
-- Both counts MUST be 0 on a fresh apply: approval is off by default, and default-off is the
-- ABSENCE of a row (§④.2). A non-zero count means something else seeded the switchboard.
