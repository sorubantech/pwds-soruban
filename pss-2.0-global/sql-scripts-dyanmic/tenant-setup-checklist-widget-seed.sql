-- =====================================================================================
-- Tenant First-Login Setup Wizard — §⑤.4 dashboard checklist widget registration
-- =====================================================================================
-- Registers the "Setup checklist" widget so the frontend renderer actually appears on a
-- tenant's landing dashboard. Without this script the React component exists but is never
-- instantiated — the dashboard is fully DB-driven.
--
-- What it does (all idempotent, safe to re-run):
--   1. sett."WidgetTypes"  — one row whose "ComponentPath" is the EXACT registry key
--                            'TenantSetupChecklistWidget'. A mismatch here surfaces at
--                            runtime as "Widget component not found in registry".
--   2. sett."Widgets"      — one system widget (CompanyId NULL) on the CRM module, which
--                            is the OrderBy=1 landing module.
--   3. auth."WidgetRoles"  — visibility grant. GetWidgetByModuleCode filters widgets by the
--                            caller's roles, so a widget with no WidgetRoles row is
--                            invisible to everyone. Granted to every active role.
--   4. sett."DashboardLayouts" — places the widget top-left on the CRM module-overview
--                            dashboard(s) (MenuId IS NULL = the static overview partition).
--                            react-grid-layout compacts vertically, so inserting at y=0
--                            pushes the existing tiles down rather than overlapping them.
--
-- The widget hides itself once every applicable task is completed or skipped, so this is a
-- one-time placement — nobody has to come back and remove it.
--
-- IDs are GENERATED ALWAYS (UseIdentityAlwaysColumn) — never insert them explicitly.
-- Run as the application/owner role. Apply AFTER
-- sql-scripts-dyanmic/tenant-setup-wizard-existing-tenant-backfill.sql.
-- =====================================================================================

BEGIN;

-- ── 1. Widget type ───────────────────────────────────────────────────────────────────
INSERT INTO sett."WidgetTypes"
    ("WidgetTypeName", "WidgetTypeCode", "Description", "ComponentPath",
     "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
SELECT 'Tenant Setup Checklist',
       'TENANTSETUPCHECKLIST',
       'First-login setup checklist. Self-hiding once every applicable task is settled.',
       'TenantSetupChecklistWidget',
       1, NOW() AT TIME ZONE 'UTC', true, false
WHERE NOT EXISTS (
    SELECT 1 FROM sett."WidgetTypes"
    WHERE "WidgetTypeCode" = 'TENANTSETUPCHECKLIST'
);

-- Keep an existing row honest if it was seeded earlier with a different component path.
UPDATE sett."WidgetTypes"
   SET "ComponentPath" = 'TenantSetupChecklistWidget',
       "ModifiedBy"    = 1,
       "ModifiedDate"  = NOW() AT TIME ZONE 'UTC'
 WHERE "WidgetTypeCode" = 'TENANTSETUPCHECKLIST'
   AND "ComponentPath" IS DISTINCT FROM 'TenantSetupChecklistWidget';

-- ── 2. Widget ────────────────────────────────────────────────────────────────────────
-- CRM ('e5400835-62e5-4ca0-8ce1-f0d841892ab6') is the OrderBy=1 module, i.e. where a
-- freshly provisioned tenant lands after the wizard hands them back to the dashboard.
INSERT INTO sett."Widgets"
    ("WidgetName", "WidgetTypeId", "Description", "MinHeight", "MinWidth",
     "ModuleId", "OrderBy", "IsSystem", "CompanyId",
     "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
SELECT 'Setup Checklist',
       wt."WidgetTypeId",
       'Remaining first-login setup tasks for this organisation.',
       4, 3,
       'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid,
       0, true, NULL,
       1, NOW() AT TIME ZONE 'UTC', true, false
  FROM sett."WidgetTypes" wt
 WHERE wt."WidgetTypeCode" = 'TENANTSETUPCHECKLIST'
   AND NOT EXISTS (
       SELECT 1
         FROM sett."Widgets" w
        WHERE w."WidgetTypeId" = wt."WidgetTypeId"
          AND w."ModuleId" = 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid
          AND w."CompanyId" IS NULL
   );

-- ── 3. Role visibility ───────────────────────────────────────────────────────────────
-- GetWidgetByModuleCode intersects widgets with the caller's WidgetRoles. Setup progress
-- is not sensitive — it is a to-do list of configuration screens the user's capabilities
-- already gate — so every active role gets it; the row-level deep links stay capability
-- guarded on their own screens.
INSERT INTO auth."WidgetRoles"
    ("WidgetId", "RoleId", "HasAccess", "CreatedBy", "CreatedDate", "IsActive", "IsDeleted")
SELECT w."WidgetId", r."RoleId", true, 1, NOW() AT TIME ZONE 'UTC', true, false
  FROM sett."Widgets" w
  JOIN sett."WidgetTypes" wt ON wt."WidgetTypeId" = w."WidgetTypeId"
 CROSS JOIN auth."Roles" r
 WHERE wt."WidgetTypeCode" = 'TENANTSETUPCHECKLIST'
   AND w."CompanyId" IS NULL
   AND r."IsActive" = true
   AND r."IsDeleted" = false
   AND NOT EXISTS (
       SELECT 1 FROM auth."WidgetRoles" x
        WHERE x."WidgetId" = w."WidgetId" AND x."RoleId" = r."RoleId"
   );

-- Re-open access if a prior run left the grant switched off.
UPDATE auth."WidgetRoles" wr
   SET "HasAccess" = true, "IsActive" = true, "IsDeleted" = false,
       "ModifiedBy" = 1, "ModifiedDate" = NOW() AT TIME ZONE 'UTC'
  FROM sett."Widgets" w
  JOIN sett."WidgetTypes" wt ON wt."WidgetTypeId" = w."WidgetTypeId"
 WHERE wr."WidgetId" = w."WidgetId"
   AND wt."WidgetTypeCode" = 'TENANTSETUPCHECKLIST'
   AND (wr."HasAccess" = false OR wr."IsActive" = false OR wr."IsDeleted" = true);

-- ── 4. Dashboard placement ───────────────────────────────────────────────────────────
-- LayoutConfig is breakpoint-keyed JSON ({lg:[…], md:[…], …}) on newer seeds and a flat
-- array on legacy ones; parseLayoutConfig in the frontend accepts both, so this handles
-- both. ConfiguredWidget maps instance code -> widgetId; the frontend rewrites each
-- layout item's `i` through that map before handing it to react-grid-layout.
DO $$
DECLARE
    v_widget_id  int;
    v_instance   text := 'tenant-setup-checklist';
    v_item       jsonb;
    v_cfg_entry  jsonb;
    r            record;
    v_layout     jsonb;
    v_configured jsonb;
    v_bp         text;
BEGIN
    SELECT w."WidgetId"
      INTO v_widget_id
      FROM sett."Widgets" w
      JOIN sett."WidgetTypes" wt ON wt."WidgetTypeId" = w."WidgetTypeId"
     WHERE wt."WidgetTypeCode" = 'TENANTSETUPCHECKLIST'
       AND w."CompanyId" IS NULL
     LIMIT 1;

    IF v_widget_id IS NULL THEN
        RAISE EXCEPTION 'Tenant setup checklist widget was not created — aborting placement.';
    END IF;

    -- w=4 of 12 columns, h=4 rows (rowHeight 100 + margin) ≈ a tall narrow checklist
    -- column beside the KPI row. y=0 puts it first; RGL vertical compaction shifts the
    -- existing tiles down instead of overlapping them.
    v_item      := jsonb_build_object('i', v_instance, 'x', 0, 'y', 0, 'w', 4, 'h', 4,
                                      'minW', 3, 'minH', 4);
    v_cfg_entry := jsonb_build_object('i', v_instance, 'widgetId', v_widget_id);

    FOR r IN
        SELECT dl."DashboardLayoutId", dl."LayoutConfig", dl."ConfiguredWidget"
          FROM sett."DashboardLayouts" dl
          JOIN sett."Dashboards" d ON d."DashboardId" = dl."DashboardId"
         WHERE d."ModuleId" = 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid
           AND d."MenuId" IS NULL          -- static module-overview partition
           AND d."IsActive" = true
           AND d."IsDeleted" = false
           AND dl."IsDeleted" = false
    LOOP
        v_configured := COALESCE(NULLIF(r."ConfiguredWidget", '')::jsonb, '[]'::jsonb);
        IF jsonb_typeof(v_configured) <> 'array' THEN
            v_configured := '[]'::jsonb;
        END IF;

        -- Already placed on this dashboard? leave it exactly as the admin arranged it.
        IF EXISTS (
            SELECT 1 FROM jsonb_array_elements(v_configured) e
             WHERE e->>'i' = v_instance
                OR e->>'widgetId' = v_widget_id::text
        ) THEN
            CONTINUE;
        END IF;

        v_configured := v_configured || jsonb_build_array(v_cfg_entry);
        v_layout     := COALESCE(NULLIF(r."LayoutConfig", '')::jsonb, '[]'::jsonb);

        IF jsonb_typeof(v_layout) = 'array' THEN
            -- Legacy flat array: one shared item list across every breakpoint.
            v_layout := v_layout || jsonb_build_array(v_item);
        ELSIF jsonb_typeof(v_layout) = 'object' THEN
            FOREACH v_bp IN ARRAY ARRAY['xl', 'lg', 'md', 'sm', 'xs'] LOOP
                IF jsonb_typeof(v_layout -> v_bp) = 'array' THEN
                    v_layout := jsonb_set(
                        v_layout, ARRAY[v_bp],
                        (v_layout -> v_bp) || jsonb_build_array(
                            -- sm has 6 columns and xs has 1, so a 4-wide tile is clamped
                            -- to what the breakpoint can actually hold.
                            CASE v_bp
                                WHEN 'xs' THEN jsonb_set(v_item, '{w}', to_jsonb(1))
                                WHEN 'sm' THEN jsonb_set(v_item, '{w}', to_jsonb(3))
                                ELSE v_item
                            END
                        )
                    );
                END IF;
            END LOOP;
        ELSE
            CONTINUE;   -- unparseable layout: don't guess, leave it alone
        END IF;

        UPDATE sett."DashboardLayouts"
           SET "LayoutConfig"     = v_layout::text,
               "ConfiguredWidget" = v_configured::text,
               "ModifiedBy"       = 1,
               "ModifiedDate"     = NOW() AT TIME ZONE 'UTC'
         WHERE "DashboardLayoutId" = r."DashboardLayoutId";
    END LOOP;
END $$;

COMMIT;

-- =====================================================================================
-- VERIFICATION
-- =====================================================================================
-- RESULT 1 — must return exactly one row, ComponentPath 'TenantSetupChecklistWidget'.
SELECT wt."WidgetTypeCode", wt."ComponentPath", w."WidgetId", w."WidgetName", w."IsActive"
  FROM sett."WidgetTypes" wt
  LEFT JOIN sett."Widgets" w ON w."WidgetTypeId" = wt."WidgetTypeId"
 WHERE wt."WidgetTypeCode" = 'TENANTSETUPCHECKLIST';

-- RESULT 2 — role grants; should equal the count of active roles.
SELECT COUNT(*) AS granted_roles
  FROM auth."WidgetRoles" wr
  JOIN sett."Widgets" w   ON w."WidgetId" = wr."WidgetId"
  JOIN sett."WidgetTypes" wt ON wt."WidgetTypeId" = w."WidgetTypeId"
 WHERE wt."WidgetTypeCode" = 'TENANTSETUPCHECKLIST'
   AND wr."HasAccess" = true;

-- RESULT 3 — placement; one row per CRM overview dashboard, each containing the instance.
SELECT d."DashboardId", d."DashboardCode", dl."ConfiguredWidget"
  FROM sett."DashboardLayouts" dl
  JOIN sett."Dashboards" d ON d."DashboardId" = dl."DashboardId"
 WHERE d."ModuleId" = 'e5400835-62e5-4ca0-8ce1-f0d841892ab6'::uuid
   AND d."MenuId" IS NULL
   AND dl."ConfiguredWidget" LIKE '%tenant-setup-checklist%';
