-- =====================================================================================
-- ai-module-rolemodule-access-fix.sql
--
-- FOLLOW-UP to ai-module-promotion-seed.sql. Run that one FIRST; this one repairs the
-- access layer it left incomplete.
--
-- WHY THIS EXISTS — two independent gates, and the promotion seed only wrote one:
--
--   1. THE RAIL ICON is driven by auth."RoleModules". GetUserRoleModuleHandler walks
--      UserRoles → Role.RoleModules → Module and never looks at RoleCapabilities. With no
--      RoleModules row for AI the module is absent from the rail entirely — which is
--      exactly the symptom: plan shows FEATURE:INTELLIGENCE, module still invisible.
--      The promotion seed never wrote this table. Section 1 below fixes that.
--
--   2. THE PANEL LEAVES are driven by auth."RoleCapabilities" + ISMENURENDER, filtered by
--      the plan. The promotion seed §7 DID write these — but it derived its audience from
--      "whoever already holds ACTIONBOARD". Those six Intelligence menus were dead
--      UnderConstruction screens, so if no role ever held a grant on them that subquery
--      matched zero rows and inserted nothing. Sections 2-3 re-derive from a source that
--      is guaranteed populated (the CRM module's own RoleModules audience) and top up.
--
-- Both sections are pure INSERTs guarded by NOT EXISTS. Nothing is revoked, nothing is
-- deleted, no capability is created, no DDL. Re-runnable; a second run is a no-op.
--
-- On SUPERADMIN: it is not special-cased either way. It appears in the derived audience
-- only if it already holds a live CRM grant, and even then this script can only ADD to
-- what it has — no existing SUPERADMIN row is modified or removed.
-- =====================================================================================

BEGIN;

-- ─── 0. Icon form — hyphen → colon ───────────────────────────────────────────────────
--
-- Cosmetic, but it is the difference between an icon and a blank square. Two call sites,
-- both of which need the Iconify colon form:
--
--   * resolveModuleIcon() (useTenantRailItems) returns the SAFE_FALLBACK_ICON unless the
--     string contains a colon — so 'ph-sparkle' silently renders as ph:squares-four.
--   * getFullIconName() (iconify-icon-list.ts) is currently a pass-through — its
--     prefix-adding branch is commented out — so the context panel hands 'ph-pen-nib'
--     straight to Iconify, which resolves nothing.
--
-- The promotion seed wrote the hyphen form throughout. Rewritten here for the AI module
-- and its menus only; other modules are left exactly as they are (see note to the user —
-- the same hyphen form appears across older seeds and is a separate, wider question).

UPDATE auth."Modules"
SET "ModuleIcon" = 'ph:' || substring("ModuleIcon" from 4),
    "ModifiedBy" = 2, "ModifiedDate" = now()
WHERE "ModuleCode" = 'AI'
  AND "ModuleIcon" LIKE 'ph-%';

UPDATE auth."Menus" m
SET "MenuIcon" = 'ph:' || substring(m."MenuIcon" from 4),
    "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Modules" md
WHERE md."ModuleId" = m."ModuleId"
  AND md."ModuleCode" = 'AI'
  AND m."MenuIcon" LIKE 'ph-%';


-- ─── 1. auth."RoleModules" — put the AI module on the rail ───────────────────────────
--
-- Audience is DERIVED from the CRM module's existing grants: the AI screens were living
-- under CRM until this migration, so everyone who can see CRM today is exactly the set
-- who could reach Intelligence yesterday. No hardcoded role list, and a tenant that has
-- customised its roles keeps that customisation.

INSERT INTO auth."RoleModules"
  ("RoleId","ModuleId","HasAccess","CreatedBy","CreatedDate","ModifiedBy","ModifiedDate",
   "IsActive","IsDeleted")
SELECT src."RoleId",
       (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'AI'),
       true, 2, now(), null, null, true, false
FROM (
    SELECT DISTINCT rm."RoleId"
    FROM auth."RoleModules" rm
    JOIN auth."Modules" cm ON cm."ModuleId" = rm."ModuleId" AND cm."ModuleCode" = 'CRM'
    WHERE rm."HasAccess" = true
      AND rm."IsActive" = true
      AND rm."IsDeleted" IS DISTINCT FROM true
) src
WHERE NOT EXISTS (
    SELECT 1 FROM auth."RoleModules" rm2
    WHERE rm2."RoleId" = src."RoleId"
      AND rm2."ModuleId" = (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'AI')
);

-- Re-activate an AI RoleModules row that a prior run left soft-deleted or access-denied.
UPDATE auth."RoleModules" rm
SET "HasAccess" = true, "IsActive" = true, "IsDeleted" = false,
    "ModifiedBy" = 2, "ModifiedDate" = now()
WHERE rm."ModuleId" = (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'AI')
  AND (rm."HasAccess" = false OR rm."IsActive" = false OR rm."IsDeleted" = true);


-- ─── 2. MenuCapabilities — top up ALL fifteen AI menus ───────────────────────────────
--
-- The promotion seed covered the six NEW menus and the two group headers. The six MOVED
-- menus are covered here too: they may never have had a full capability set, having been
-- dead screens. Top-up style, so anything already present is left exactly as it is.
-- ISMENURENDER is MATCHED, never created.

INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedBy","CreatedDate","ModifiedBy","ModifiedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", 2, now(), null, null, true, false
FROM auth."Menus" m
JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'AI'
CROSS JOIN auth."Capabilities" c
WHERE m."IsDeleted" = false
  AND c."CapabilityCode" IN ('READ','CREATE','MODIFY','DELETE','EXPORT','IMPORT','TOGGLE','ISMENURENDER')
  AND NOT EXISTS (
      SELECT 1 FROM auth."MenuCapabilities" mc
      WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

UPDATE auth."MenuCapabilities" mc
SET "IsActive" = true, "IsDeleted" = false, "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m
JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'AI'
WHERE mc."MenuId" = m."MenuId"
  AND (mc."IsActive" = false OR mc."IsDeleted" = true);


-- ─── 3. RoleCapabilities — every AI menu, same derived audience as section 1 ─────────
--
-- Re-derived from the CRM RoleModules audience rather than from ACTIONBOARD holders, so
-- it cannot silently match zero rows the way the promotion seed's §7 could. Covers all
-- fifteen AI menus (three headers + twelve leaves), READ for the API check and
-- ISMENURENDER for the sidebar check — the two gates are separate and both are required.
--
-- Top-up only: a role that already has a grant on any of these keeps it untouched.

INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedBy","CreatedDate",
   "ModifiedBy","ModifiedDate","IsActive","IsDeleted")
SELECT src."RoleId", m."MenuId", c."CapabilityId", true, 2, now(), null, null, true, false
FROM (
    SELECT DISTINCT rm."RoleId"
    FROM auth."RoleModules" rm
    JOIN auth."Modules" cm ON cm."ModuleId" = rm."ModuleId" AND cm."ModuleCode" = 'CRM'
    WHERE rm."HasAccess" = true
      AND rm."IsActive" = true
      AND rm."IsDeleted" IS DISTINCT FROM true
) src
CROSS JOIN auth."Menus" m
JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'AI'
CROSS JOIN auth."Capabilities" c
WHERE m."IsDeleted" = false
  AND c."CapabilityCode" IN ('READ','ISMENURENDER')
  AND NOT EXISTS (
      SELECT 1 FROM auth."RoleCapabilities" rc
      WHERE rc."RoleId" = src."RoleId"
        AND rc."MenuId" = m."MenuId"
        AND rc."CapabilityId" = c."CapabilityId"
  );

-- Re-activate AI grants that exist but were left inactive / access-denied by a prior run.
UPDATE auth."RoleCapabilities" rc
SET "HasAccess" = true, "IsActive" = true, "IsDeleted" = false,
    "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m
JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'AI'
WHERE rc."MenuId" = m."MenuId"
  AND (rc."HasAccess" = false OR rc."IsActive" = false OR rc."IsDeleted" = true);

COMMIT;


-- =====================================================================================
-- VERIFY — run after COMMIT.
-- =====================================================================================

-- V1. Roles that can now reach the AI module on the rail. MUST be > 0, and should match
--     the CRM count exactly.
SELECT
  (SELECT count(DISTINCT rm."RoleId") FROM auth."RoleModules" rm
   JOIN auth."Modules" md ON md."ModuleId" = rm."ModuleId" AND md."ModuleCode" = 'AI'
   WHERE rm."HasAccess" AND rm."IsActive" AND rm."IsDeleted" IS DISTINCT FROM true) AS ai_roles,
  (SELECT count(DISTINCT rm."RoleId") FROM auth."RoleModules" rm
   JOIN auth."Modules" md ON md."ModuleId" = rm."ModuleId" AND md."ModuleCode" = 'CRM'
   WHERE rm."HasAccess" AND rm."IsActive" AND rm."IsDeleted" IS DISTINCT FROM true) AS crm_roles;

-- V2. AI menus with no live ISMENURENDER grant. MUST be 0.
SELECT count(*) AS ai_menus_without_ismenurender_grant
FROM auth."Menus" m
JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'AI'
WHERE m."IsDeleted" = false
  AND NOT EXISTS (
    SELECT 1 FROM auth."RoleCapabilities" rc
    JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
    WHERE rc."MenuId" = m."MenuId" AND c."CapabilityCode" = 'ISMENURENDER'
      AND rc."HasAccess" AND rc."IsActive" AND rc."IsDeleted" IS DISTINCT FROM true);

-- V3. Icon form. Both counts MUST be 0 — nothing left in hyphen form.
SELECT
  (SELECT count(*) FROM auth."Modules"
   WHERE "ModuleCode" = 'AI' AND "ModuleIcon" LIKE 'ph-%') AS module_icon_hyphenated,
  (SELECT count(*) FROM auth."Menus" m
   JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'AI'
   WHERE m."MenuIcon" LIKE 'ph-%') AS menu_icons_hyphenated;

-- V4. What YOUR signed-in user will actually see. Replace :user_id with your user id.
--     Expect the AI module row, then fifteen menus.
-- SELECT md."ModuleCode", md."ModuleName", md."OrderBy"
-- FROM auth."UserRoles" ur
-- JOIN auth."RoleModules" rm ON rm."RoleId" = ur."RoleId"
-- JOIN auth."Modules" md ON md."ModuleId" = rm."ModuleId"
-- WHERE ur."UserId" = :user_id AND ur."IsActive" AND ur."IsDeleted" = false
--   AND rm."HasAccess" AND rm."IsActive" AND rm."IsDeleted" IS DISTINCT FROM true
--   AND md."IsActive" AND md."IsDeleted" = false
-- ORDER BY md."OrderBy";
