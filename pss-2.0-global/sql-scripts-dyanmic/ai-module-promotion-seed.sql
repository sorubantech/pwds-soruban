-- =====================================================================================
-- ai-module-promotion-seed.sql
--
-- Promotes the dead `crm/intelligence` sub-group into a top-level **AI** module with
-- twelve screens: six existing menus are RE-POINTED, six new menus are inserted, and two
-- new group headers frame them.
--
-- HARD RULES honoured by this script:
--   * Menu CODES are never renamed. auth."RoleCapabilities" joins Role → Menu(MenuCode) →
--     Capability, so a rename silently revokes every grant. Only ModuleId, ParentMenuId,
--     MenuName, MenuUrl and OrderBy change. `CRM_INTELLIGENCE` therefore keeps its
--     CRM_-prefixed code while living in the AI module — that is deliberate.
--   * `ISMENURENDER` already exists in auth."Capabilities" and is only ever SELECTed or
--     joined here — never inserted.
--   * No DDL. No DELETE against auth. Retirement is soft (IsDeleted=true, IsActive=false).
--   * SUPERADMIN is not touched.
--   * Section 7 derives the roles to grant from whoever already holds ACTIONBOARD, so the
--     new screens land with exactly the same audience as the group they joined — no
--     hardcoded role list.
--
-- Idempotent and re-runnable. Verify block is the trailing statement set, after COMMIT.
-- =====================================================================================

BEGIN;

-- ─── 1. Module — 'AI', ordered immediately after CRM ─────────────────────────────────
--
-- auth."Modules" carries a UNIQUE index on ("OrderBy","IsActive"), so "CRM's OrderBy + 1"
-- is NOT safely assignable — on this database ORGANIZATION already holds it. Rather than
-- renumber live rows (which would churn every module's sidebar position), the insert takes
-- the SMALLEST FREE active OrderBy greater than CRM's. That keeps AI as close after CRM as
-- the numbering allows without moving anything else.

INSERT INTO auth."Modules"
  ("ModuleName","ModuleCode","ModuleUrl","ModuleIcon","Description","OrderBy",
   "CreatedBy","CreatedDate","IsActive","IsDeleted")
SELECT
  'AI', 'AI', '/ai/ask', 'ph-sparkle',
  'Assistant, insights and governance for the tenant''s AI surface.',
  COALESCE(
    (SELECT MIN(g)
     FROM generate_series(
            COALESCE((SELECT c."OrderBy" + 1 FROM auth."Modules" c
                      WHERE c."ModuleCode" = 'CRM' AND c."IsActive"), 2),
            899) g
     WHERE NOT EXISTS (
       SELECT 1 FROM auth."Modules" m WHERE m."OrderBy" = g AND m."IsActive")),
    500),
  2, now(), true, false
WHERE NOT EXISTS (SELECT 1 FROM auth."Modules" md WHERE md."ModuleCode" = 'AI');

-- Repair a previously soft-deleted module row rather than leaving a dead duplicate.
UPDATE auth."Modules"
SET "IsActive" = true, "IsDeleted" = false, "ModuleName" = 'AI',
    "ModuleIcon" = 'ph-sparkle', "ModuleUrl" = '/ai/ask',
    "ModifiedBy" = 2, "ModifiedDate" = now()
WHERE "ModuleCode" = 'AI'
  AND ("IsActive" = false OR "IsDeleted" = true);


-- ─── 2. Group headers — AI_ASSISTANT and AI_GOVERNANCE (IsLeastMenu = false) ─────────
--
-- These are containers, not screens: no MenuUrl, no capabilities, no grants. The third
-- group header is the EXISTING `CRM_INTELLIGENCE` row, re-pointed in section 3.

INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description",
   "OrderBy","IsLeastMenu","MenuType","IsVisible",
   "CreatedBy","CreatedDate","IsActive","IsDeleted")
SELECT
  v.menu_name, v.menu_code, NULL, v.menu_icon,
  (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'AI'),
  NULL, v.menu_desc, v.order_by, false, 'Internal', true,
  2, now(), true, false
FROM (VALUES
  ('Assistant',  'AI_ASSISTANT',  'ph-chat-circle-dots', 'Conversational assistant, skills, agents and drafting.', 100),
  ('Governance', 'AI_GOVERNANCE', 'ph-shield-check',     'Connections, usage and tenant-wide AI settings.',        300)
) AS v(menu_name, menu_code, menu_icon, menu_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = v.menu_code);

-- Guarded repair: re-home / re-activate the headers if a prior run left them stale.
UPDATE auth."Menus" m
SET "ModuleId"     = (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'AI'),
    "ParentMenuId" = NULL,
    "IsLeastMenu"  = false,
    "IsActive"     = true,
    "IsDeleted"    = false,
    "IsVisible"    = true,
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE m."MenuCode" IN ('AI_ASSISTANT','AI_GOVERNANCE');


-- ─── 3. Re-point CRM_INTELLIGENCE → the AI module, renamed "Insights" in the UI ──────
--
-- CODE UNCHANGED. Only the placement and the display name move. OrderBy 200 sits between
-- Assistant (100) and Governance (300).

UPDATE auth."Menus" m
SET "ModuleId"     = (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'AI'),
    "MenuName"     = 'Insights',
    "ParentMenuId" = NULL,
    "MenuIcon"     = 'ph-chart-line-up',
    "OrderBy"      = 200,
    "IsLeastMenu"  = false,
    "IsActive"     = true,
    "IsDeleted"    = false,
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE m."MenuCode" = 'CRM_INTELLIGENCE'
  -- Guard: only act while the row is still where it was, so a re-run is a no-op rather
  -- than a second write.
  AND (m."ModuleId" IS DISTINCT FROM (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'AI')
       OR m."MenuName" IS DISTINCT FROM 'Insights'
       OR m."ParentMenuId" IS NOT NULL
       OR m."OrderBy" IS DISTINCT FROM 200
       OR m."IsActive" = false
       OR m."IsDeleted" = true);


-- ─── 4. Re-point the six existing leaves onto their new /ai/… routes ─────────────────
--
-- Five stay under CRM_INTELLIGENCE (now "Insights"). AIDRAFT ALSO re-parents, to
-- AI_ASSISTANT — it is a drafting tool, not an insight. Every MenuUrl moves off /crm/.
-- CHURNPREDICTION is relabelled "Lapse Prediction" in the UI only; its code is untouched.

UPDATE auth."Menus" m
SET "ModuleId"     = (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'AI'),
    "ParentMenuId" = (SELECT p."MenuId" FROM auth."Menus" p WHERE p."MenuCode" = v.parent_code),
    "MenuName"     = v.menu_name,
    "MenuIcon"     = v.menu_icon,
    "MenuUrl"      = v.menu_url,
    "OrderBy"      = v.order_by,
    "IsLeastMenu"  = true,
    "IsVisible"    = true,
    "IsActive"     = true,
    "IsDeleted"    = false,
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
FROM (VALUES
  ('AIDRAFT',             'AI_ASSISTANT',     'Draft Studio',         'ph-pen-nib',          '/ai/draft',                140),
  ('ACTIONBOARD',         'CRM_INTELLIGENCE', 'Action Board',         'ph-kanban',           '/ai/actionboard',          210),
  ('ENGAGEMENTSCORING',   'CRM_INTELLIGENCE', 'Engagement Scoring',   'ph-gauge',            '/ai/engagementscoring',    220),
  ('CHURNPREDICTION',     'CRM_INTELLIGENCE', 'Lapse Prediction',     'ph-trend-down',       '/ai/churnprediction',      230),
  ('PREDICTIVEANALYTICS', 'CRM_INTELLIGENCE', 'Predictive Analytics', 'ph-chart-line-up',    '/ai/predictiveanalytics',  240),
  ('AIREPORTING',         'CRM_INTELLIGENCE', 'AI Reporting',         'ph-file-magnifying-glass', '/ai/reporting',       250)
) AS v(menu_code, parent_code, menu_name, menu_icon, menu_url, order_by)
WHERE m."MenuCode" = v.menu_code;


-- ─── 5. Six NEW leaves ───────────────────────────────────────────────────────────────

INSERT INTO auth."Menus"
  ("MenuName","MenuCode","ParentMenuId","MenuIcon","ModuleId","MenuUrl","Description",
   "OrderBy","IsLeastMenu","MenuType","IsVisible",
   "CreatedBy","CreatedDate","IsActive","IsDeleted")
SELECT
  v.menu_name, v.menu_code,
  (SELECT p."MenuId" FROM auth."Menus" p WHERE p."MenuCode" = v.parent_code),
  v.menu_icon,
  (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'AI'),
  v.menu_url, v.menu_desc, v.order_by, true, 'Internal', true,
  2, now(), true, false
FROM (VALUES
  ('Ask AI',            'AI_ASK',         'AI_ASSISTANT',  'ph-chat-teardrop-text', '/ai/ask',         'Conversational assistant over tenant data.',      110),
  ('Skills',            'AI_SKILLS',      'AI_ASSISTANT',  'ph-puzzle-piece',       '/ai/skills',      'Reusable prompts the assistant can run.',         120),
  ('Agents',            'AI_AGENTS',      'AI_ASSISTANT',  'ph-robot',              '/ai/agents',      'Scheduled and triggered background agents.',      130),
  ('Connections',       'AI_CONNECTIONS', 'AI_GOVERNANCE', 'ph-plugs-connected',    '/ai/connections', 'Data sources and tools the AI may reach.',        310),
  ('Usage & Analytics', 'AI_ANALYTICS',   'AI_GOVERNANCE', 'ph-chart-donut',        '/ai/analytics',   'AI credit spend by user, feature and period.',    320),
  ('AI Settings',       'AI_SETTINGS',    'AI_GOVERNANCE', 'ph-sliders-horizontal', '/ai/settings',    'Tenant-wide assistant behaviour and retention.',  330)
) AS v(menu_name, menu_code, parent_code, menu_icon, menu_url, menu_desc, order_by)
WHERE NOT EXISTS (SELECT 1 FROM auth."Menus" mn WHERE mn."MenuCode" = v.menu_code);

-- Guarded repair for the six new leaves, in case an earlier partial run left them stale.
UPDATE auth."Menus" m
SET "ModuleId"     = (SELECT md."ModuleId" FROM auth."Modules" md WHERE md."ModuleCode" = 'AI'),
    "ParentMenuId" = (SELECT p."MenuId" FROM auth."Menus" p WHERE p."MenuCode" = v.parent_code),
    "MenuUrl"      = v.menu_url,
    "OrderBy"      = v.order_by,
    "IsLeastMenu"  = true,
    "IsVisible"    = true,
    "IsActive"     = true,
    "IsDeleted"    = false,
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
FROM (VALUES
  ('AI_ASK',         'AI_ASSISTANT',  '/ai/ask',         110),
  ('AI_SKILLS',      'AI_ASSISTANT',  '/ai/skills',      120),
  ('AI_AGENTS',      'AI_ASSISTANT',  '/ai/agents',      130),
  ('AI_CONNECTIONS', 'AI_GOVERNANCE', '/ai/connections', 310),
  ('AI_ANALYTICS',   'AI_GOVERNANCE', '/ai/analytics',   320),
  ('AI_SETTINGS',    'AI_GOVERNANCE', '/ai/settings',    330)
) AS v(menu_code, parent_code, menu_url, order_by)
WHERE m."MenuCode" = v.menu_code;


-- ─── 6. MenuCapabilities for the six new menus ───────────────────────────────────────
--
-- The canonical eight, top-up style. ISMENURENDER is MATCHED here, never created — it is
-- an existing row in auth."Capabilities" and inserting a second one would break the
-- UNIQUE (CapabilityName, IsActive) index and split the sidebar-render check in two.

INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedBy","CreatedDate","ModifiedBy","ModifiedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", 2, now(), null, null, true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" IN ('AI_ASK','AI_SKILLS','AI_AGENTS','AI_CONNECTIONS','AI_ANALYTICS','AI_SETTINGS')
  AND c."CapabilityCode" IN ('READ','CREATE','MODIFY','DELETE','EXPORT','IMPORT','TOGGLE','ISMENURENDER')
  AND NOT EXISTS (
      SELECT 1 FROM auth."MenuCapabilities" mc
      WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

UPDATE auth."MenuCapabilities" mc
SET "IsActive" = true, "IsDeleted" = false, "ModifiedBy" = 2, "ModifiedDate" = now()
FROM auth."Menus" m
WHERE mc."MenuId" = m."MenuId"
  AND m."MenuCode" IN ('AI_ASK','AI_SKILLS','AI_AGENTS','AI_CONNECTIONS','AI_ANALYTICS','AI_SETTINGS')
  AND (mc."IsActive" = false OR mc."IsDeleted" = true);


-- ─── 7. RoleCapabilities — grant the six new menus to whoever already holds ACTIONBOARD ──
--
-- The audience is DERIVED, not listed. Any role that can already see the Intelligence
-- group gets the new screens with the same reach; a tenant that has customised its roles
-- keeps that customisation instead of being overwritten by a hardcoded BUSINESSADMIN row.
-- Both halves of the pair are written: the view capability (API authorization reads
-- auth."RoleCapabilities") and ISMENURENDER (sidebar rendering is a SEPARATE check).
-- Nothing is revoked here.

INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedBy","CreatedDate",
   "ModifiedBy","ModifiedDate","IsActive","IsDeleted")
SELECT src."RoleId", m."MenuId", c."CapabilityId", true, 2, now(), null, null, true, false
FROM (
    -- Roles holding a live grant on ACTIONBOARD today.
    SELECT DISTINCT rc."RoleId"
    FROM auth."RoleCapabilities" rc
    JOIN auth."Menus" am ON am."MenuId" = rc."MenuId" AND am."MenuCode" = 'ACTIONBOARD'
    WHERE rc."HasAccess" = true
      AND rc."IsActive" = true
      AND rc."IsDeleted" IS DISTINCT FROM true
) src
CROSS JOIN auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" IN ('AI_ASK','AI_SKILLS','AI_AGENTS','AI_CONNECTIONS','AI_ANALYTICS','AI_SETTINGS')
  AND c."CapabilityCode" IN ('READ','ISMENURENDER')
  AND NOT EXISTS (
      SELECT 1 FROM auth."RoleCapabilities" rc2
      WHERE rc2."RoleId" = src."RoleId"
        AND rc2."MenuId" = m."MenuId"
        AND rc2."CapabilityId" = c."CapabilityId"
  );

-- The two group headers need ISMENURENDER too, or the sidebar has leaves with no section
-- to hang under. Same derived audience.
INSERT INTO auth."MenuCapabilities"
  ("MenuId","CapabilityId","CreatedBy","CreatedDate","ModifiedBy","ModifiedDate","IsActive","IsDeleted")
SELECT m."MenuId", c."CapabilityId", 2, now(), null, null, true, false
FROM auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" IN ('AI_ASSISTANT','AI_GOVERNANCE')
  AND c."CapabilityCode" IN ('READ','ISMENURENDER')
  AND NOT EXISTS (
      SELECT 1 FROM auth."MenuCapabilities" mc
      WHERE mc."MenuId" = m."MenuId" AND mc."CapabilityId" = c."CapabilityId"
  );

INSERT INTO auth."RoleCapabilities"
  ("RoleId","MenuId","CapabilityId","HasAccess","CreatedBy","CreatedDate",
   "ModifiedBy","ModifiedDate","IsActive","IsDeleted")
SELECT src."RoleId", m."MenuId", c."CapabilityId", true, 2, now(), null, null, true, false
FROM (
    SELECT DISTINCT rc."RoleId"
    FROM auth."RoleCapabilities" rc
    JOIN auth."Menus" am ON am."MenuId" = rc."MenuId" AND am."MenuCode" = 'ACTIONBOARD'
    WHERE rc."HasAccess" = true
      AND rc."IsActive" = true
      AND rc."IsDeleted" IS DISTINCT FROM true
) src
CROSS JOIN auth."Menus" m
CROSS JOIN auth."Capabilities" c
WHERE m."MenuCode" IN ('AI_ASSISTANT','AI_GOVERNANCE')
  AND c."CapabilityCode" IN ('READ','ISMENURENDER')
  AND NOT EXISTS (
      SELECT 1 FROM auth."RoleCapabilities" rc2
      WHERE rc2."RoleId" = src."RoleId"
        AND rc2."MenuId" = m."MenuId"
        AND rc2."CapabilityId" = c."CapabilityId"
  );


-- ─── 8. D-4 — retire the phantom NLREPORTING feature map row ─────────────────────────
--
-- `menu-activate-mvp-feature-areas.sql` activates AIREPORTING; the leaf-level feature map
-- claimed NLREPORTING, a code that has no menu. The live code is AIREPORTING. Soft-delete
-- the phantom; the correct row is (re)asserted in section 9 alongside the new codes, so
-- the replacement is written in the same transaction as the retirement.

UPDATE billing."FeatureMenuMaps"
SET "IsActive" = false, "IsDeleted" = true, "ModifiedDate" = now()
WHERE upper("FeatureCode") = 'FEATURE:INTELLIGENCE'
  AND upper("MenuCode")    = 'NLREPORTING'
  AND "IsDeleted" IS DISTINCT FROM true;


-- ─── 9. billing."FeatureMenuMaps" — hand-curated rows for the AI menus ───────────────
--
-- Written by hand, NOT generated from auth."Modules" or the menu tree: this table is a
-- curated business vocabulary and an unmapped menu is deliberately always-visible. All
-- thirteen AI menu codes map to the existing FEATURE:INTELLIGENCE so the module gates as
-- one unit. AIREPORTING is re-asserted here as the replacement for the retired row above.

INSERT INTO billing."FeatureMenuMaps"
  ("FeatureCode","MenuCode","IsActive","IsDeleted","CreatedDate")
SELECT 'FEATURE:INTELLIGENCE', v.menu_code, true, false, now()
FROM (VALUES
  ('AI_ASSISTANT'), ('AI_ASK'), ('AI_SKILLS'), ('AI_AGENTS'), ('AIDRAFT'),
  ('CRM_INTELLIGENCE'), ('ACTIONBOARD'), ('ENGAGEMENTSCORING'), ('CHURNPREDICTION'),
  ('PREDICTIVEANALYTICS'), ('AIREPORTING'),
  ('AI_GOVERNANCE'), ('AI_CONNECTIONS'), ('AI_ANALYTICS'), ('AI_SETTINGS')
) AS v(menu_code)
WHERE NOT EXISTS (
  SELECT 1 FROM billing."FeatureMenuMaps" fm
  WHERE upper(fm."FeatureCode") = 'FEATURE:INTELLIGENCE'
    AND upper(fm."MenuCode")    = v.menu_code
);

-- Re-activate any of the above that a prior sweep soft-deleted.
UPDATE billing."FeatureMenuMaps"
SET "IsActive" = true, "IsDeleted" = false, "ModifiedDate" = now()
WHERE upper("FeatureCode") = 'FEATURE:INTELLIGENCE'
  AND upper("MenuCode") IN (
    'AI_ASSISTANT','AI_ASK','AI_SKILLS','AI_AGENTS','AIDRAFT',
    'CRM_INTELLIGENCE','ACTIONBOARD','ENGAGEMENTSCORING','CHURNPREDICTION',
    'PREDICTIVEANALYTICS','AIREPORTING',
    'AI_GOVERNANCE','AI_CONNECTIONS','AI_ANALYTICS','AI_SETTINGS')
  AND ("IsActive" = false OR "IsDeleted" = true);

COMMIT;


-- =====================================================================================
-- 10. VERIFY — run after COMMIT.
-- =====================================================================================

-- 10a. The AI module's menu tree, in render order. Expect 3 headers + 12 leaves = 15 rows.
SELECT p."MenuCode" AS parent_code,
       m."MenuCode",
       m."MenuName",
       m."MenuUrl",
       m."OrderBy",
       m."IsLeastMenu"
FROM auth."Menus" m
JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'AI'
LEFT JOIN auth."Menus" p ON p."MenuId" = m."ParentMenuId"
WHERE m."IsDeleted" = false
ORDER BY COALESCE(p."OrderBy", m."OrderBy"), m."OrderBy";

-- 10b. AI menus still pointing at a /crm/ URL. MUST be 0.
SELECT count(*) AS ai_menus_still_on_crm_url
FROM auth."Menus" m
JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'AI'
WHERE m."IsDeleted" = false
  AND m."MenuUrl" ILIKE '%/crm/%';

-- 10c. AI menus with no live ISMENURENDER grant to any role. MUST be 0.
SELECT count(*) AS ai_menus_without_ismenurender_grant
FROM auth."Menus" m
JOIN auth."Modules" md ON md."ModuleId" = m."ModuleId" AND md."ModuleCode" = 'AI'
WHERE m."IsDeleted" = false
  AND NOT EXISTS (
    SELECT 1
    FROM auth."RoleCapabilities" rc
    JOIN auth."Capabilities" c ON c."CapabilityId" = rc."CapabilityId"
    WHERE rc."MenuId" = m."MenuId"
      AND c."CapabilityCode" = 'ISMENURENDER'
      AND rc."HasAccess" = true
      AND rc."IsActive" = true
      AND rc."IsDeleted" IS DISTINCT FROM true
  );

-- 10d. D-4 closed: NLREPORTING retired, AIREPORTING live.
SELECT upper("MenuCode") AS menu_code, "IsActive", "IsDeleted"
FROM billing."FeatureMenuMaps"
WHERE upper("FeatureCode") = 'FEATURE:INTELLIGENCE'
  AND upper("MenuCode") IN ('NLREPORTING','AIREPORTING');
