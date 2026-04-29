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
| `sett.Dashboards` | DashboardId, DashboardCode, DashboardName, ModuleId, IsSystem, IsActive, CompanyId, MenuId | One row per dashboard. `MenuId` (FK → `auth.Menus`, nullable) — NULL = STATIC_DASHBOARD; NOT NULL = MENU_DASHBOARD. Slug, sort, visibility all live on the linked Menu row + RoleCapability. NO MenuUrl/OrderBy/IsMenuVisible columns on Dashboard. |
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

## Path-A Recipe Library — copy-paste templates per widget kind

> Distilled from the 17-function Case Management Dashboard (`DatabaseScripts/Functions/case/fn_case_dashboard_*.sql`). Every recipe conforms to the 5-arg / 4-return contract. Adapt names + columns; keep the structural patterns verbatim.

### Filter extraction (top-of-function — same for every recipe)

```sql
DECLARE
    v_date_from        DATE    := NULLIF(p_filter_json ->> 'dateFrom', '')::DATE;
    v_date_to          DATE    := NULLIF(p_filter_json ->> 'dateTo',   '')::DATE;
    v_program_id       INTEGER := NULLIF(p_filter_json ->> 'programId', '')::INT;
    v_branch_id        INTEGER := NULLIF(p_filter_json ->> 'branchId',  '')::INT;
    v_assigned_staff_id INTEGER := NULLIF(p_filter_json ->> 'assignedStaffId', '')::INT;
    result_json jsonb;
    meta_json   jsonb;
BEGIN
    -- Defaults applied AFTER declarations
    IF v_date_from IS NULL THEN v_date_from := DATE_TRUNC('year', CURRENT_DATE)::DATE; END IF;
    IF v_date_to   IS NULL THEN v_date_to   := CURRENT_DATE; END IF;
```

**Why `NULLIF(... , '')`:** prevents empty-string filter values from casting to `0` (which would silently include `programId=0`, etc.). Always use this idiom — never bare `(p_filter_json->>'key')::int`.

### Tenant scoping (every query — never omit)

```sql
WHERE x."IsDeleted" = false
  AND (p_company_id IS NULL OR x."CompanyId" = p_company_id)   -- ← MANDATORY
  AND (v_branch_id  IS NULL OR x."BranchId"   = v_branch_id)
  AND (v_program_id IS NULL OR x."ProgramId"  = v_program_id)
```

`p_company_id IS NULL` allows super-admins (no tenant) to see all companies; otherwise the row's `CompanyId` must match. Apply on EVERY tenant-scoped table touched, including transitive joins.

### Recipe 1 — KPI function (single-number aggregate)

```sql
-- Compute the headline value
SELECT COUNT(DISTINCT b."BeneficiaryId")::INTEGER INTO v_total_count
FROM "case"."Beneficiaries" b
WHERE b."IsDeleted" = false
  AND b."EnrollmentDate" BETWEEN v_date_from AND v_date_to
  AND (p_company_id IS NULL OR b."CompanyId" = p_company_id)
  AND (v_branch_id  IS NULL OR b."BranchId"  = v_branch_id);

-- Compute the delta on its OWN date window (typically YTD), not the filter window
SELECT COUNT(DISTINCT b."BeneficiaryId")::INTEGER INTO v_delta_this_year
FROM "case"."Beneficiaries" b
WHERE b."IsDeleted" = false
  AND b."EnrollmentDate" >= DATE_TRUNC('year', CURRENT_DATE)::DATE
  AND b."EnrollmentDate" <= CURRENT_DATE
  AND (p_company_id IS NULL OR b."CompanyId" = p_company_id);

-- Build the FE payload — keys MUST match StatusWidgetType1 contract
SELECT json_build_object(
    'value',      v_total_count,
    'formatted',  TO_CHAR(v_total_count, 'FM999,999,999'),
    'subtitle',   '↑ ' || v_delta_this_year || ' new this year',
    'deltaLabel', v_delta_this_year::text || ' new this year',
    'deltaColor', 'positive',                    -- 'positive' | 'warning' | 'neutral'
    'icon',       'users-light',                 -- bare Phosphor name (no ph: prefix)
    'color',      'teal'                         -- Tailwind color name
) INTO result_json;

IF result_json IS NULL THEN result_json := '{}'::json; END IF;

meta_json := jsonb_build_object('generatedAt', NOW(), 'filtersApplied', p_filter_json);

-- KPIs do NOT paginate — return -1 for total/filtered counts
RETURN QUERY SELECT result_json::text, meta_json::text, -1, -1;
```

**Rules:**
- Two SELECTs (value + delta) — delta uses its OWN date window (e.g., YTD), not `v_date_from..v_date_to`.
- Format with `TO_CHAR(..., 'FM999,999,999')` for thousands separators (the `FM` modifier strips leading whitespace).
- Use `deltaColor: 'positive'` for upward improvement, `'warning'` for trends going the wrong way, `'neutral'` for flat. Flip direction for KPIs where lower = better (fewer overdue cases = `positive`).
- Always end with `RETURN QUERY SELECT ..., -1, -1;` for KPIs (signals "not paginated").

### Recipe 2 — Donut/Pie chart function (bucketed segments)

```sql
WITH age_calc AS (
    SELECT CASE WHEN b."DateOfBirth" IS NOT NULL
                THEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, b."DateOfBirth"))::INTEGER
                ELSE b."ApproximateAge" END AS age
    FROM "case"."Beneficiaries" b
    WHERE b."IsDeleted" = false
      AND (p_company_id IS NULL OR b."CompanyId" = p_company_id)
      AND b."EnrollmentDate" BETWEEN v_date_from AND v_date_to
),
bucketed AS (
    SELECT
        CASE
            WHEN age BETWEEN 0 AND 5   THEN '0-5'
            WHEN age BETWEEN 6 AND 12  THEN '6-12'
            WHEN age BETWEEN 13 AND 17 THEN '13-17'
            WHEN age BETWEEN 18 AND 25 THEN '18-25'
            WHEN age BETWEEN 26 AND 35 THEN '26-35'
            ELSE '35+'
        END AS bucket,
        CASE
            WHEN age BETWEEN 0 AND 5   THEN 1
            WHEN age BETWEEN 6 AND 12  THEN 2
            WHEN age BETWEEN 13 AND 17 THEN 3
            WHEN age BETWEEN 18 AND 25 THEN 4
            WHEN age BETWEEN 26 AND 35 THEN 5
            ELSE 6
        END AS sort_ord,
        CASE
            WHEN age BETWEEN 0 AND 5   THEN '#06b6d4'   -- Cyan-500
            WHEN age BETWEEN 6 AND 12  THEN '#3b82f6'   -- Blue-500
            WHEN age BETWEEN 13 AND 17 THEN '#8b5cf6'   -- Purple-500
            WHEN age BETWEEN 18 AND 25 THEN '#10b981'   -- Emerald-500
            WHEN age BETWEEN 26 AND 35 THEN '#f59e0b'   -- Amber-500
            ELSE '#ef4444'                              -- Red-500
        END AS color
    FROM age_calc WHERE age IS NOT NULL
),
agg AS (
    SELECT bucket, sort_ord, color, COUNT(*) AS cnt
    FROM bucketed GROUP BY bucket, sort_ord, color
)
SELECT json_build_object(
    'total', (SELECT SUM(cnt)::int FROM agg),
    'segments', COALESCE(
        json_agg(json_build_object(
            'label', a.bucket,
            'value', a.cnt,
            'pct',   CASE WHEN (SELECT SUM(cnt) FROM agg) > 0
                          THEN ROUND(a.cnt::NUMERIC / (SELECT SUM(cnt) FROM agg)::NUMERIC * 100, 1)
                          ELSE 0 END,
            'color', a.color
        ) ORDER BY a.sort_ord),       -- ← order by sort_ord, NOT by count
        '[]'::json
    )
) INTO result_json
FROM agg a;
```

**Rules:**
- 3-CTE stack: `compute → bucket+order+color → aggregate`. Keeps each layer single-purpose; easier to debug than a monolithic query.
- Hex colors are inline in the SQL (the FE consumes them verbatim — no Tailwind translation server-side).
- Order segments by a dedicated `sort_ord` column, NEVER by `cnt`. Bucket order must be stable across filter changes.
- Wrap `json_agg(...)` with `COALESCE(..., '[]'::json)` — empty result sets must yield `[]`, not `null`.

### Recipe 3 — Multi-row table function (FilterTableWidget / NormalTableWidget)

```sql
WITH enrolled_counts AS (
    SELECT e."ProgramId", COUNT(DISTINCT e."BeneficiaryId") AS enrolled_count
    FROM "case"."BeneficiaryProgramEnrollments" e
    INNER JOIN "case"."Beneficiaries" b ON b."BeneficiaryId" = e."BeneficiaryId"
    WHERE e."IsDeleted" = false AND b."IsDeleted" = false
      AND e."EnrolledOn" BETWEEN v_date_from AND v_date_to
      AND (v_branch_id IS NULL OR b."BranchId" = v_branch_id)
    GROUP BY e."ProgramId"
),
case_counts AS (...),       -- one CTE per aggregate dimension
outcome_rates AS (...),
program_rows AS (
    SELECT
        p."ProgramId" AS program_id,
        p."ProgramName" AS program_name,
        COALESCE(p."IconEmoji", '📋') AS icon,
        COALESCE(ec.enrolled_count, 0) AS beneficiaries,
        COALESCE(p."MaximumCapacity", 0) AS capacity,
        COALESCE(cc.open_cases, 0) AS cases_open,
        COALESCE(ors.outcome_rate, 0) AS outcome_rate,
        -- Status badge logic (keep CASE blocks here, NOT in the final SELECT)
        CASE
            WHEN COALESCE(ors.outcome_rate, 0) >= 85 THEN 'green'
            WHEN COALESCE(ors.outcome_rate, 0) >= 70 THEN 'yellow'
            ELSE 'red'
        END AS outcome_color,
        CASE
            WHEN COALESCE(ors.outcome_rate, 0) >= 80 THEN 'On Track'
            WHEN COALESCE(ors.outcome_rate, 0) BETWEEN 70 AND 79.9 THEN 'Needs Attention'
            ELSE 'Below Target'
        END AS status_label
    FROM "case"."Programs" p
    LEFT JOIN enrolled_counts ec  ON ec.ProgramId  = p."ProgramId"
    LEFT JOIN case_counts     cc  ON cc.ProgramId  = p."ProgramId"
    LEFT JOIN outcome_rates   ors ON ors.ProgramId = p."ProgramId"
    WHERE p."IsDeleted" = false
      AND (p_company_id IS NULL OR p."CompanyId" = p_company_id)
)
SELECT json_build_object(
    'rows', COALESCE(
        json_agg(json_build_object(
            'programId',     pr.program_id,
            'programName',   pr.program_name,
            'icon',          pr.icon,
            'beneficiaries', pr.beneficiaries,
            'capacity',      pr.capacity,
            'casesOpen',     pr.cases_open,
            'outcomeRate',   pr.outcome_rate,
            'outcomeColor',  pr.outcome_color,
            'status',        pr.status_label
        ) ORDER BY pr.program_name),    -- ← stable column, NOT a computed measure
        '[]'::json
    )
) INTO result_json
FROM program_rows pr;
```

**Rules:**
- CTE order: aggregates first (`enrolled_counts`, `case_counts`, `outcome_rates`), then the join (`program_rows`), then the final JSON SELECT. Each layer is single-responsibility.
- Use `FILTER (WHERE ...)` clauses for conditional aggregation: `COUNT(*) FILTER (WHERE m."MeasurementText" IS NOT NULL)` instead of `SUM(CASE ... END)`. Cleaner Postgres idiom.
- All status-badge / color / label CASE expressions live INSIDE `program_rows`, not in the outer SELECT. Easier to read and reuse.
- `COALESCE` every dimension lookup to a sensible default (`COALESCE(p."IconEmoji", '📋')`, `COALESCE(ec.enrolled_count, 0)`).
- Order by a stable column (`program_name`), not by a computed measure — measures jump on filter change and confuse users.

### Recipe 4 — Alert/Rules-Engine function (multi-rule list)

```sql
DECLARE
    v_alerts        jsonb := '[]'::jsonb;
    v_overdue_count int   := 0;
    v_oldest_case   text  := NULL;
BEGIN
    -- ============ Rule 1 — overdue follow-ups ============
    SELECT COUNT(*), MAX(c."CaseCode")
      INTO v_overdue_count, v_oldest_case
    FROM "case"."Cases" c
    WHERE c."IsDeleted" = false
      AND c."FollowUpDate" < CURRENT_DATE
      AND (p_company_id IS NULL OR c."CompanyId" = p_company_id);

    IF v_overdue_count > 0 THEN
        v_alerts := v_alerts || jsonb_build_array(
            jsonb_build_object(
                'severity', 'warning',                              -- warning | info | success
                'iconCode', 'clock-countdown-light',                -- bare Phosphor name
                'message',  '<strong>' || v_overdue_count || '</strong> overdue follow-up(s) — Oldest: '
                            || COALESCE(v_oldest_case, 'N/A'),
                'link', jsonb_build_object(
                    'label', 'View Overdue Cases',
                    'route', '/crm/casemanagement/caselist',
                    'args',  jsonb_build_object('overdue', 'true')
                )
            )
        );
    END IF;

    -- ============ Rule 2, 3, 4... follow same shape ============
    -- (declare counters, run the check, IF triggered → append jsonb_build_object)

    -- Hard cap to 10 (UI-side scrolling beyond this is noise)
    SELECT json_build_object(
        'alerts', COALESCE(
            (SELECT json_agg(elem)
             FROM (SELECT elem FROM jsonb_array_elements(v_alerts) AS elem LIMIT 10) sub),
            '[]'::json)
    ) INTO result_json;

    IF result_json IS NULL THEN result_json := '{"alerts":[]}'::json; END IF;

    meta_json := jsonb_build_object(
        'generatedAt', NOW(),
        'alertCount', jsonb_array_length(v_alerts),     -- handy for UI badge counts
        'filtersApplied', p_filter_json
    );

    RETURN QUERY SELECT result_json::text, meta_json::text, -1, -1;
```

**Rules:**
- Initialize `v_alerts JSONB := '[]'::jsonb` — never `NULL`; concatenation must always succeed.
- Append with `v_alerts := v_alerts || jsonb_build_array(jsonb_build_object(...))`. Each rule independently decides whether to append.
- Severity is a closed enum: `warning | info | success`. The FE has style maps for these three only — invent new ones at your peril.
- Allow `<strong>` and `<em>` in messages (sanitized FE-side); everything else is HTML-escaped. Use `<strong>` to draw the eye to numbers.
- Hard-cap output to 10 alerts (LIMIT in the final aggregation). More is noise — surface a summary alert instead.
- Include `alertCount` in metadata so the UI can show a badge without re-counting.

---

## Anti-patterns — these WILL fail review

### SQL anti-patterns

```sql
-- ❌ Missing tenant scope
SELECT COUNT(*) FROM "case"."Cases" WHERE "IsDeleted" = false;
-- ✅ Always include
... AND (p_company_id IS NULL OR "CompanyId" = p_company_id);

-- ❌ SQL Server syntax (will fail to compile in Postgres)
CREATE PROCEDURE dbo.myproc @param INT AS SELECT * FROM [Table];
-- ✅ Postgres
CREATE OR REPLACE FUNCTION "schema".myfunc(p_param int) RETURNS TABLE(...) LANGUAGE plpgsql AS $$ ... $$;

-- ❌ Bare cast without NULLIF (empty string → 0 → wrong scope)
v_program_id INTEGER := (p_filter_json ->> 'programId')::INT;
-- ✅ NULLIF guards empty string
v_program_id INTEGER := NULLIF(p_filter_json ->> 'programId', '')::INT;

-- ❌ Hardcoded "demo" values in SQL
SELECT json_build_object('outcomeRate', 85);
-- ✅ Computed from real data
SELECT ROUND(...) INTO v_outcome_rate; ... json_build_object('outcomeRate', v_outcome_rate);

-- ❌ Using p_page/p_page_size in a KPI (KPIs are single-row aggregates)
LIMIT p_page_size OFFSET p_page * p_page_size;
-- ✅ KPIs return -1, -1 for total/filtered counts
RETURN QUERY SELECT result_json::text, meta_json::text, -1, -1;

-- ❌ Ordering chart segments by count (jumps on filter change)
... ORDER BY a.cnt DESC
-- ✅ Stable sort by an explicit sort_ord column
... ORDER BY a.sort_ord
```

### Seed-script anti-patterns

```sql
-- ❌ Non-idempotent INSERT (re-run fails with unique-constraint violation)
INSERT INTO sett."Widgets" (...) VALUES (...);
-- ✅ Guard with NOT EXISTS
INSERT INTO sett."Widgets" (...)
SELECT ... WHERE NOT EXISTS (
    SELECT 1 FROM sett."Widgets" WHERE "Description" = 'KPI_OPEN_CASES' AND COALESCE("IsDeleted", false) = false
);

-- ❌ Hardcoded ID (different DB → wrong row)
INSERT INTO sett."Widgets" (..., "ModuleId", ...) VALUES (..., 12, ...);
-- ✅ Resolve at seed time
INSERT INTO sett."Widgets" (..., "ModuleId", ...)
VALUES (..., (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode" = 'CRM'), ...);

-- ❌ Unqualified DROP (Postgres needs schema + signature for exact match)
DROP FUNCTION IF EXISTS fn_case_dashboard_kpi_open_cases;
-- ✅ Qualified + full signature
DROP FUNCTION IF EXISTS "case".fn_case_dashboard_kpi_open_cases(jsonb, int4, int4, int4, int4);
```

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
- Add **1 column** to `Dashboard` entity: `MenuId int? FK auth.Menus` (Restrict). NULL ⇒ STATIC; NOT NULL ⇒ MENU-linked. **Do NOT add `MenuUrl`, `OrderBy`, or `IsMenuVisible`** — those duplicate fields already on `auth.Menus`/`auth.RoleCapabilities`. Update `DashboardConfiguration.cs` + generate EF migration; no new unique index needed (uniqueness lives on `auth.Menus.MenuUrl`).
- Add `LinkDashboardToMenu` / `UnlinkDashboardFromMenu` mutations (link sets `Dashboard.MenuId`; validates `Menu.ModuleId == Dashboard.ModuleId`).
- Add `GetMenuLinkedDashboardsByModuleCode` query — joins to `auth.Menus`, lean projection (no widget data), batched per render.
- Add a NEW `GetDashboardByModuleAndCode(moduleCode, dashboardCode)` query — single row, **no UserDashboard join**, validates `MenuId IS NOT NULL`. The existing `dashboardByModuleCode` handler is left UNTOUCHED (it joins `UserDashboard` and serves STATIC mode).

The orchestrator will spell this out explicitly in the prompt's Tasks list. If it's NOT spelled out, this work is already done.
