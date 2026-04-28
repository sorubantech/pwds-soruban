# Code Reference — DASHBOARD (Frontend)

> **Loaded by**: `frontend-developer.md` agent when prompt frontmatter has `screen_type: DASHBOARD`.
> **Companion**: `code-reference-backend.md` (same folder).
> **Template**: `.claude/screen-tracker/prompts/_DASHBOARD.md`.

Dashboards reuse the existing rendering layer (`<DashboardComponent />` at [`PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/index.tsx`](../../../PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/index.tsx)). **Skip** the standard 7-file FE pipeline.

Read `dashboard_variant` from prompt frontmatter (`STATIC_DASHBOARD` | `MENU_DASHBOARD`) — affects ROUTE handling but NOT what files you create.

---

## How a Widget Reaches the Screen — the indirection chain

The system is **data-driven**. A seeded `Widget` row carries everything `<DashboardComponent />` needs to render and fetch data. There is **no per-widget React file required** unless the mockup demands a brand-new chart/visual primitive.

```
DashboardLayout.ConfiguredWidget JSON (instance placement + per-instance config)
         │
         ▼  resolves to
sett.Widgets row  →  WidgetType.ComponentPath  →  WIDGET_REGISTRY[componentPath] in dashboard-widget-registry.tsx
         │                                                  │
         │                                                  └─ React component (renderer)
         │
         └─ Widget.DefaultQuery (name)  →  QUERY_REGISTRY[name] in dashboard-widget-query-registry.tsx
         │                                       │
         │                                       └─ gql document
         │
         └─ Widget.DefaultParameters (JSON string passed as $parameters)
         └─ Widget.StoredProcedureName (alternative — generic generateWidgets handler runs SP server-side)
```

**Three FE wiring paths — pick per widget**:

| Path | When | FE work needed |
|------|------|----------------|
| **A. Reuse renderer + `generateWidgets`+ SP** | Widget data is row/column tabular and already covered by `Widget.StoredProcedureName` | NONE on FE — SP returns generic key/value pairs, generic renderer reads `widgetProperties` to format |
| **B. Reuse renderer + named GQL query** | Renderer in registry is fine, but data shape is custom — needs a typed GraphQL query | Add a gql query file under `infrastructure/gql-queries/{group}-queries/`, then **register its name in `dashboard-widget-query-registry.tsx`** so widget runtime can resolve `Widget.DefaultQuery` to the doc |
| **C. New renderer (and optionally new query)** | Mockup demands a chart/visual not covered by any existing renderer (e.g., Sankey, calendar heatmap) | Create new widget under `dashboards/widgets/{type}/`, register in `dashboard-widget-registry.tsx` under the new `componentPath` key, optionally seed a new `WidgetType` row whose `ComponentPath` matches |

**Always exhaust path A before B, and path B before C.** Escalate to user only when a brand-new visual primitive is genuinely required.

---

## Files to Generate

| # | File | Path | Always |
|---|------|------|--------|
| 1 | `{EntityName}DashboardDto.ts` (matches BE composite/per-widget DTOs) | `src/domain/entities/{group}-service/` | only if path B/C — typed query needed |
| 2 | Per-widget GraphQL query file(s) | `src/infrastructure/gql-queries/{group}-queries/{EntityName}DashboardQuery.ts` | only if path B/C |
| 3 | Register query name → gql doc | **`src/presentation/components/custom-components/dashboards/dashboard-widget-query-registry.tsx`** (existing file — extend `QUERY_REGISTRY`) | only if path B/C |
| 4 | New widget renderer component(s) | `src/presentation/components/custom-components/dashboards/widgets/{type}/{Name}.tsx` | only if path C |
| 5 | Register new renderer | **`src/presentation/components/custom-components/dashboards/dashboard-widget-registry.tsx`** (existing file — extend `WIDGET_REGISTRY`) | only if path C |

**Filename pin-down (do NOT invent):**
- Widget renderer registry → `dashboard-widget-registry.tsx` (NOT `widget-registry.ts`)
- Widget query registry → `dashboard-widget-query-registry.tsx`
- Widget component folders → `dashboards/widgets/{type}/` (e.g. `bar-chart-widgets/`, `pie-chart-widgets/`, `chart-widgets/`, `table-widgets/`, `status-widgets/`, `html-widgets/`, `geographic-heatmap-widgets/`, `meeting-schedule-widgets/`, `profile-widgets/`, `radial-bar-chart-widgets/`, `columns-chart-widgets/`)

---

## Files NOT to Generate

- ❌ `Mutation.ts` — dashboards are read-only
- ❌ Page config (`pages/{group}/...`)
- ❌ `index-page.tsx` / `view-page.tsx` / `data-table.tsx`
- ❌ Zustand store (`{entity}-store.ts`)
- ❌ `entity-operations` / `operations-config` registration
- ❌ Per-dashboard route page — variant decides:
  - **STATIC_DASHBOARD**: existing module dashboard route already renders `<DashboardComponent />`. Do NOT create a new route page.
  - **MENU_DASHBOARD**: dynamic `/[lang]/(core)/[module]/dashboards/[slug]/page.tsx` route covers ALL menu dashboards. Created ONCE when the first MENU_DASHBOARD ships (per `_DASHBOARD.md` template preamble). Do NOT create a per-dashboard page.

---

## How the Dashboard Reaches the User

| Variant | Route shape | Component |
|---------|-------------|-----------|
| STATIC_DASHBOARD | `/[lang]/{module}/dashboards` (existing) | `<DashboardComponent moduleCode={module.toUpperCase()} />` — auto-picks `IsDefault=true` Dashboard, lists `IsMenuVisible=false` rows in dropdown |
| MENU_DASHBOARD | `/[lang]/{module}/dashboards/{slug}` (dynamic [slug] route) | `<DashboardComponent slugOverride={slug} />` — finds Dashboard by `effectiveSlug`, no dropdown, no edit chrome |

---

## Existing Renderers in `dashboard-widget-registry.tsx` (reference catalog)

> Reuse these ComponentPath keys whenever the widget shape matches. Grep the registry file for the live list before adding a new renderer.

| ComponentPath key | Visual | Typical use |
|-------------------|--------|-------------|
| `MultiChartWidget` | Unified chart (line/bar/area/donut configurable) | First-resort for any chart — supports most chart types via config |
| `NegativeLineChartWidget` | Line chart with threshold-based color | Trend lines that need green-above / red-below split |
| `StatusWidgetType1` / `StatusWidgetType2` | KPI card variants | Single-number KPIs (Total / Avg / Count / %) |
| `RadialBarChartWidgetType1` | Radial / gauge | Single-metric % indicators |
| `BarChartWidgetType1` / `BarChartWidgetType2` | Vertical bar | Comparisons / ranked categories |
| `ColumnChartWidgetType1` | Column chart | Time-series buckets |
| `PieChartWidgetType1` / `PieChartWidgetType2` | Pie / donut | Category distribution |
| `TableWidgetType1` | Data table | Tabular widget |
| `NormalTableWidget` / `FilterTableWidget` | Inline tables under the chart-widgets bucket | Alternative table renderers |
| `ProfileWidgetType1` | Profile card | "Member of the month" style |
| `MeetingScheduleWidgetType1` | Schedule list | Upcoming items list |
| `HtmlWidgetType1` / `HtmlWidgetType2` | Raw HTML | Templated impact statements / announcements |
| `GeographicHeatmapWidgetType1` | Map heatmap | Geo-distribution KPIs |

---

## Widget Component Skeleton (path C only — when adding a NEW renderer)

```tsx
// dashboards/widgets/{type}/{NewWidgetName}.tsx
"use client";
import { Card, CardContent } from "@/presentation/components/atoms/card";
import { Skeleton } from "@/presentation/components/atoms/skeleton";
import { useQuery } from "@apollo/client";
import { getQueryByName } from "../../dashboard-widget-query-registry";

export default function NewWidgetName({ widget }: { widget: WidgetDto }) {
  const queryName = widget.defaultQuery || "GENERATE_WIDGETS_QUERY";
  const params = widget.defaultParameters ? JSON.parse(widget.defaultParameters) : {};
  const queryDoc = getQueryByName(queryName);
  const { data, loading, error } = useQuery(queryDoc, { variables: { ...params, widgetId: widget.widgetId } });

  if (loading) return <Skeleton className="h-full w-full rounded-lg" />;
  if (error) return <Card className="p-4 text-destructive">Failed to load — Retry</Card>;

  // Map data → chart/widget content with design tokens (no inline hex / px)
  return <Card><CardContent>...</CardContent></Card>;
}
```

---

## Widget Registry Registration (path C only)

```ts
// dashboard-widget-registry.tsx — add the import + WIDGET_REGISTRY entry
import NewWidgetName from "./widgets/{type}/NewWidgetName";

const WIDGET_REGISTRY: Record<string, any> = {
  // ... existing entries ...
  NewWidgetName: NewWidgetName,   // key MUST match seeded WidgetType.ComponentPath
};
```

## Query Registry Registration (path B/C only)

```ts
// dashboard-widget-query-registry.tsx — extend QUERY_REGISTRY with the new GQL doc
import * as Queries from "@/infrastructure/gql-queries";

const QUERY_REGISTRY: Record<string, any> = {
  STAFFS_QUERY: Queries.STAFFS_QUERY,
  GENERATE_WIDGETS_QUERY: Queries.GENERATE_WIDGETS_QUERY,
  // ... add new entry — name MUST match seeded Widget.DefaultQuery ...
  GET_CASE_DASHBOARD_DATA: Queries.GET_CASE_DASHBOARD_DATA,
};
```

---

## MUST DOs

1. **Path-A first** — if a stored procedure can return the data as key/value pairs, seed `Widget.StoredProcedureName` and skip FE work entirely. The renderer + `GENERATE_WIDGETS_QUERY` already handle it.
2. **Search registry first** — before creating any new renderer, grep `WIDGET_REGISTRY` in `dashboard-widget-registry.tsx`. Match the visual to an existing `ComponentPath` key when possible.
3. **Skeleton sized to widget shape** — KPI card → `h-24`, chart → `h-64`, table → row-shaped placeholders. Empty Skeleton bands break visual rhythm.
4. **Filter bindings** — every widget that the prompt's Section ⑥ "Filters Honored" column lists must consume those filter args via the page-level filter context (or via `defaultParameters` mutation when filters change).
5. **Drill-down handlers** — every drill-down per Section ⑥ Drill-Down Map must call `router.push()` with the correct prefill query params.
6. **Empty / error states** — every widget renders an empty state when no data, an error state with Retry on query failure.
7. **NO inline hex colors** in widget components — use design tokens. Brand-mapped colors (e.g., chart series palette) belong in a constants file, not inline `style={{}}`.
8. **`useQuery` cache keys** — widgets sharing the same composite query share Apollo cache. Filter args change → single network round-trip refreshes all bound widgets. Don't issue redundant per-widget queries against the composite handler.
9. **Toolbar / chrome overrides** — if the mockup shows export / print / custom buttons in the dashboard header, surface them via the chrome props supported by `<DashboardComponent />` (or, if absent, escalate as a one-time chrome enhancement). Don't open-code them inside the dashboard slug page.

---

## MENU_DASHBOARD First-Time Infrastructure (read-only context here — orchestrator handles)

If the prompt is the FIRST MENU_DASHBOARD ever built, additional one-time FE work is in scope (per `_DASHBOARD.md` template preamble):
- Create the dynamic `[lang]/(core)/[module]/dashboards/[slug]/page.tsx` route
- DELETE per-name hardcoded dashboard pages (`crm/dashboards/contactdashboard/page.tsx`, etc.) — pre-flight grep for any imports first
- Update `<DashboardComponent />` to read `slugOverride` prop and skip the `IsDefault` auto-pick when slug is present
- Update `<DashboardHeader />` to add "Promote to menu" / "Hide from menu" kebab actions
- Update sidebar menu-tree composer to inject `menuVisibleDashboardsByModuleCode` results as leaves under each `*_DASHBOARDS` parent (batched, not N+1)

The orchestrator will spell this out explicitly in the prompt's Tasks list. If it's NOT spelled out, this work is already done.
