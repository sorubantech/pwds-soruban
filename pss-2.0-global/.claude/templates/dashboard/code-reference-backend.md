# Code Reference — DASHBOARD (Backend)

> **Loaded by**: `backend-developer.md` agent when prompt frontmatter has `screen_type: DASHBOARD`.
> **Companion**: `code-reference-frontend.md` (same folder).
> **Template**: `.claude/screen-tracker/prompts/_DASHBOARD.md`.

Dashboards do **NOT** introduce a new entity. They aggregate over existing source entities and either reuse a generic widget query handler (cheap path) or return composite DTOs (typed path). **Skip** the standard 11-file CRUD pipeline.

The `dashboard_variant` (`STATIC_DASHBOARD` | `MENU_DASHBOARD`) does NOT change what BE files you generate — both variants share the same backend shape. The variant only affects the DB seed (handled by orchestrator per `generate-screen/SKILL.md` § DASHBOARD seed).

---

## How a Widget Reaches Data — three paths

The seeded `Widget` row drives data fetching via one of three mechanisms. **Pick per widget — different widgets in the same dashboard can mix paths.**

| Path | Driver column on `sett.Widgets` | Server-side handler | When to choose | New BE C# code? |
|------|---------------------------------|---------------------|----------------|-----------------|
| **A. Postgres function (generic)** | `StoredProcedureName` populated (despite the column name, it stores a Postgres function name) | Existing `generateWidgets` GraphQL field — calls the named function with the FIXED 5-arg / 4-return contract below, returns generic `{ data, metadata, totalCount, filteredCount }` | Tabular / KPI / chart data expressible as a single SQL — keeps surface area near zero | **NO** new C# (write the Postgres function only — counts as a SQL deliverable) |
| **B. Named GraphQL query (typed)** | `DefaultQuery` = name of a registered gql doc | New CQRS query handler returning a typed DTO via existing GraphQL endpoint | Data shape is non-tabular (nested DTOs, computed fields, multi-section payload) but still single-fetch | **YES** — handler + DTO + gql field |
| **C. Composite DTO (fat handler)** | `DefaultQuery` = name of a single composite query | One handler returning the entire dashboard's data in one shot | Multi-widget dashboard whose widgets all refresh together on filter change — minimizes round-trips | **YES** — handler + composite DTO + gql field |

> Section ⑤ of the prompt MUST declare each widget's path. The BE Dev agent generates files only for paths B/C.

---

## Path A — The Generic-Widget Function Contract (NON-NEGOTIABLE)

`GenerateWidgetHandler` (PSS_2.0_Backend/.../Base.Application/Business/SettingBusiness/Widgets/Queries/GenerateWidget.cs) executes:

```csharp
SELECT * FROM {schema}."{functionName}"(@p_filter_json::jsonb, @p_page, @p_page_size, @p_user_id, @p_company_id)
```

Every Path-A function MUST conform to this contract:

**Inputs (in this exact order — the handler always passes 5 args):**
| # | Name | PG type | Source |
|---|------|---------|--------|
| 1 | `p_filter_json` | `jsonb` | Widget runtime serializes filter context (`Widget.DefaultParameters` JSON merged with FE filter args + QuickFilterSchema overlay) |
| 2 | `p_page` | `integer` | Widget runtime (paged tables) |
| 3 | `p_page_size` | `integer` | Widget runtime |
| 4 | `p_user_id` | `integer` | `httpContextAccessor.GetCurrentUserId()` |
| 5 | `p_company_id` | `integer` | `httpContextAccessor.GetCurrentUserStaffCompanyId()` (NULL when caller is super-admin) |

Functions MAY declare additional optional parameters with DEFAULTs (the handler will not supply them — they fall to default). Order them BEFORE `p_company_id` to match the existing `rep.donation_summary_report` precedent.

**Returns (exactly 4 columns — single row):**
| Column | PG type | Maps to FE |
|--------|---------|------------|
| `data` | `jsonb` | `data` array (one element per row — JSON object with the column keys the widget renderer expects) |
| `metadata` | `jsonb` | `metadata` object (e.g., totals, formatters, color hints) |
| `total_count` | `integer` | `totalCount` |
| `filtered_count` | `integer` | `filteredCount` |

**File location**: `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/{schema}/{function_name}.sql` (preserve folder convention — see existing `rep/donation_summary_report.sql`). Use snake_case for function names.

**Filter convention**: extract every filter from `p_filter_json` inside the function body — `NULLIF(p_filter_json->>'fromDate','')::timestamp` etc. NEVER as native function parameters. The widget seed's `Widget.DefaultParameters` JSON keys MUST match the keys you read inside the function.

---

## Files to Generate (paths B/C only)

| # | File | Path | Always |
|---|------|------|--------|
| 1 | `{EntityName}DashboardSchemas.cs` (composite DTO + per-widget DTOs) | `Base.Application/Schemas/{Group}Schemas/` | ✓ for B/C |
| 2 | `Get{EntityName}DashboardData.cs` (composite query handler) | `Base.Application/Business/{Group}Business/Dashboards/Queries/` | ✓ for path C |
| 3 | `Get{EntityName}{WidgetName}.cs` per-widget handler | same folder | ✓ for each path B widget |
| 4 | `{Group}DashboardQueries.cs` (or extend existing `{Group}Queries.cs`) — register the new GQL fields | `Base.API/EndPoints/{Group}/Queries/` | ✓ for B/C |
| 5 | `{Group}Mappings.cs` — `TypeAdapterConfig` for any new projections | `Base.Application/Mappings/` | only if projection is non-trivial |
| 6 | Postgres functions (one file per function — match the `rep/donation_summary_report.sql` precedent) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/DatabaseScripts/Functions/{schema}/{function_name}.sql` | ✓ for path A widgets only |

---

## Files NOT to Generate

- ❌ Entity (`*.cs` in `Base.Domain/Models/`)
- ❌ EF `Configuration.cs`
- ❌ EF Migration (UNLESS this is the first MENU_DASHBOARD — then add Dashboard.MenuId/MenuUrl/OrderBy/IsMenuVisible columns + filtered unique index per template preamble § A)
- ❌ Standard `Schemas.cs` for an entity (just the DashboardDto)
- ❌ `Create*` / `Update*` / `Delete*` / `Toggle*` commands (read-only)
- ❌ `GetAll*` / `GetById*` queries (no entity list/detail — composite query covers it)
- ❌ `Mutations.cs` endpoint (read-only — UNLESS this is the first MENU_DASHBOARD then add `linkDashboardToMenu` / `unlinkDashboardFromMenu` per template preamble § C)

---

## Key Tables / Columns You'll Touch (read-only — do not redefine)

| Table | Key columns | Purpose |
|-------|-------------|---------|
| `sett.Dashboards` | DashboardId, DashboardCode, DashboardName, ModuleId, IsSystem, IsActive, CompanyId | One row per dashboard. **First MENU_DASHBOARD adds**: MenuId, MenuUrl, OrderBy, IsMenuVisible |
| `sett.DashboardLayouts` | DashboardLayoutId, DashboardId, LayoutConfig (JSON), ConfiguredWidget (JSON) | One row per dashboard. `LayoutConfig` is react-grid-layout breakpoints; `ConfiguredWidget` is per-instance config (instanceId → widgetId/title/params) |
| `sett.Widgets` | WidgetId, WidgetName, WidgetTypeId, **DefaultQuery**, **DefaultParameters** (JSON string), **StoredProcedureName**, MinHeight, MinWidth, ModuleId, OrderBy, IsSystem | One row per logical widget. The 3 driver columns choose path A/B/C |
| `sett.WidgetTypes` | WidgetTypeId, WidgetTypeName, **WidgetTypeCode**, **ComponentPath**, Description | Catalog of available renderers — `ComponentPath` is the FE registry key. New types are rare |
| `sett.WidgetProperties` | WidgetPropertyId, WidgetId, PropertyKey, PropertyValue, DataTypeId | Optional per-widget config (icon, color, formatter, threshold) — alternative to baking into `DefaultParameters` JSON |
| `auth.WidgetRoles` | WidgetRoleId, RoleId, WidgetId, HasAccess | Role gate for visibility |

---

## Composite Handler Skeleton (path C)

```csharp
public record Get{EntityName}DashboardDataQuery(
    DateOnly DateFrom,
    DateOnly DateTo,
    int[]? ProgramIds,
    int? BranchId
) : IRequest<{EntityName}DashboardDto>;

public class Get{EntityName}DashboardDataHandler(
    IApplicationDbContext db,
    ITenantContext tenant
) : IRequestHandler<Get{EntityName}DashboardDataQuery, {EntityName}DashboardDto>
{
    public async Task<{EntityName}DashboardDto> Handle(...)
    {
        var companyId = tenant.CurrentCompanyId;
        // tenant + date range + role-scope filters applied UPFRONT
        var beneficiaries = db.Beneficiaries
            .Where(b => b.CompanyId == companyId && b.IsActive && !b.IsDeleted)
            .Where(b => b.EnrollmentDate >= request.DateFrom.ToDateTime(TimeOnly.MinValue));

        // role-scoped
        if (tenant.RoleCode == "BRANCH_MANAGER") beneficiaries = beneficiaries.Where(b => b.BranchId == tenant.UserBranchId);

        return new {EntityName}DashboardDto
        {
            TotalBeneficiaries = await beneficiaries.CountAsync(ct),
            // ... other KPIs / chart slices via GroupBy projections ...
        };
    }
}
```

---

## Path A Recipe — Postgres Function (matches `rep.donation_summary_report` precedent)

```sql
-- DatabaseScripts/Functions/case/case_dashboard_open_cases_by_status.sql
-- Re-run safe — explicit drop before create. Keep the dropped signature aligned with the new one.

DROP FUNCTION IF EXISTS "case".case_dashboard_open_cases_by_status(jsonb, int4, int4, int4, int4);

CREATE OR REPLACE FUNCTION "case".case_dashboard_open_cases_by_status(
    p_filter_json   jsonb   DEFAULT NULL,
    p_page          integer DEFAULT 0,
    p_page_size     integer DEFAULT 10,
    p_user_id       integer DEFAULT NULL,
    p_company_id    integer DEFAULT NULL
) RETURNS TABLE(data jsonb, metadata jsonb, total_count integer, filtered_count integer)
  LANGUAGE plpgsql
AS $function$
DECLARE
    v_from_date  timestamp := NULL;
    v_to_date    timestamp := NULL;
    v_branch_id  int       := NULL;
    v_program_id int       := NULL;

    v_total      int       := 0;
    v_filtered   int       := 0;
    v_data       jsonb     := '[]'::jsonb;
    v_metadata   jsonb     := '{}'::jsonb;
BEGIN
    /* ============ FILTERS — every arg lives in p_filter_json ============ */
    IF p_filter_json IS NOT NULL THEN
        v_from_date  := NULLIF(p_filter_json->>'fromDate','')::timestamp;
        v_to_date    := NULLIF(p_filter_json->>'toDate','')::timestamp;
        v_branch_id  := NULLIF(p_filter_json->>'branchId','')::int;
        v_program_id := NULLIF(p_filter_json->>'programId','')::int;
    END IF;

    /* ============ COUNTS ============ */
    SELECT COUNT(*)::int INTO v_total
    FROM "case"."Cases" c
    WHERE c."IsActive" = TRUE AND c."IsDeleted" = FALSE
      AND (p_company_id IS NULL OR c."CompanyId" = p_company_id);

    SELECT COUNT(*)::int INTO v_filtered
    FROM "case"."Cases" c
    WHERE c."IsActive" = TRUE AND c."IsDeleted" = FALSE
      AND (p_company_id IS NULL OR c."CompanyId" = p_company_id)
      AND (v_from_date  IS NULL OR c."OpenedDate" >= v_from_date)
      AND (v_to_date    IS NULL OR c."OpenedDate" <= v_to_date)
      AND (v_branch_id  IS NULL OR c."BranchId"   = v_branch_id)
      AND (v_program_id IS NULL OR c."ProgramId"  = v_program_id);

    /* ============ MAIN PAYLOAD — JSON array of rows ============ */
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
              'statusCode', md."MasterDataCode",
              'statusName', md."MasterDataValue",
              'count',      x.cnt,
              'colorHex',   md."DataSetting"->>'colorHex'   -- if status MasterData carries color
           )), '[]'::jsonb)
    INTO v_data
    FROM (
        SELECT c."StatusId", COUNT(*) AS cnt
        FROM   "case"."Cases" c
        WHERE  c."IsActive" = TRUE AND c."IsDeleted" = FALSE
          AND (p_company_id IS NULL OR c."CompanyId" = p_company_id)
          AND (v_from_date  IS NULL OR c."OpenedDate" >= v_from_date)
          AND (v_to_date    IS NULL OR c."OpenedDate" <= v_to_date)
          AND (v_branch_id  IS NULL OR c."BranchId"   = v_branch_id)
          AND (v_program_id IS NULL OR c."ProgramId"  = v_program_id)
        GROUP BY c."StatusId"
    ) x
    INNER JOIN "sett"."MasterDatas" md ON md."MasterDataId" = x."StatusId";

    RETURN QUERY SELECT v_data, v_metadata, v_total, v_filtered;
END;
$function$;
```

The corresponding Widget seed sets `StoredProcedureName='case.case_dashboard_open_cases_by_status'`. The existing `generateWidgets` GraphQL field will execute the function at runtime — no C# handler required.

**Widget.DefaultParameters JSON for this widget:**
```json
{ "fromDate": "{dateFrom}", "toDate": "{dateTo}", "branchId": "{branchId}", "programId": "{programId}" }
```
(The widget runtime substitutes the placeholders from the dashboard filter context before calling.)

---

## MUST DOs

1. **Tenant scope on every aggregate** — `WHERE CompanyId = @CompanyId` in SPs and `.Where(x => x.CompanyId == companyId)` in handlers. Non-negotiable. Easy to forget on a new query.
2. **Date range parameterized** — never hardcode "last 30 days" in the handler/SP; use the request args.
3. **Role-scoped filters when ④ rules require** — Branch Manager only sees their branch, etc. Apply BEFORE the aggregations.
4. **Multi-currency**: if `④` flags it, normalize amounts to Company default currency in the projection. Never silently sum across currencies.
5. **N+1 sentinels**: any per-row aggregate inside a Top-N projection (e.g., "top staff with their overdue case count") must use a single LINQ Group/Subquery — not a foreach over the parent rows.
6. **Register GQL fields**: extend `{Group}Queries.cs` (or create `{Group}DashboardQueries.cs`) with the new field. NO Mutations endpoint addition unless first MENU_DASHBOARD.
7. **Path-A function naming**: snake_case, schema-qualified — `{schema}.{entity}_dashboard_{widget_slug}` (e.g., `case.case_dashboard_open_cases_by_status`). Always `DROP FUNCTION IF EXISTS {schema}.{name}(jsonb, int4, int4, int4, int4)` before `CREATE OR REPLACE FUNCTION` — idempotent. Stick to the FIXED 5-arg / 4-return contract above. Filter args MUST come from `p_filter_json`, not native parameters.
8. **DefaultParameters JSON shape** — when seeding `Widget.DefaultParameters`, use a flat JSON object whose keys match the keys you read from `p_filter_json` inside the function (path A) or the gql query variable names (path B/C). Use placeholder values like `"{dateFrom}"` — the widget runtime substitutes from the dashboard filter context.
9. **Path-A is Postgres, NOT SQL Server.** Do NOT write `CREATE PROCEDURE` / `IF OBJECT_ID(...) IS NOT NULL DROP PROCEDURE` / `BEGIN...END` blocks / `[bracketed]` identifiers / native filter params. The DB is Postgres — use `CREATE FUNCTION`, `DROP FUNCTION IF EXISTS`, `LANGUAGE plpgsql`, `"PascalCase"` quoted identifiers, jsonb returns.

---

## MENU_DASHBOARD First-Time Infrastructure (read-only context here — orchestrator handles)

If the prompt is the FIRST MENU_DASHBOARD ever built, additional one-time BE work is in scope (per `_DASHBOARD.md` template preamble). You may need to:
- Add 4 columns to `Dashboard` entity (`MenuId int? FK auth.Menus`, `MenuUrl varchar(250)?`, `OrderBy int default 999`, `IsMenuVisible bool default false`) + `DashboardConfiguration.cs` updates + EF migration with the filtered unique index `(CompanyId, MenuUrl) WHERE MenuUrl IS NOT NULL AND IsDeleted = 0`
- Add `LinkDashboardToMenu` / `UnlinkDashboardFromMenu` mutations
- Add `GetMenuVisibleDashboardsByModuleCode` query
- Extend the existing `dashboardByModuleCode` projection to include the 4 new fields + computed `menuName`, `menuParentName`, `effectiveSlug`

The orchestrator will spell this out explicitly in the prompt's Tasks list. If it's NOT spelled out, this work is already done.
