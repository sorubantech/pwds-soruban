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
| STATIC_DASHBOARD | `/[lang]/{module}/dashboards` (existing) | `<DashboardComponent moduleCode={module.toUpperCase()} />` — auto-picks `UserDashboard.IsDefault=true`, dropdown lists Dashboards where `MenuId IS NULL` (system + user-created not promoted to sidebar) |
| MENU_DASHBOARD | `/[lang]/{module}/dashboards/{slug}` (dynamic [slug] route) | `<MenuDashboardComponent moduleCode={...} dashboardCode={slugToCode(slug)} />` — **separate component** at `custom-components/menu-dashboards/index.tsx` (NOT `<DashboardComponent />`). Calls new `dashboardByModuleAndCode` query (no UserDashboard join), validates `MenuId IS NOT NULL`, no dropdown, no edit chrome. See `_DASHBOARD.md` § H/I for rationale. |

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

## Widget Design Quality Standards — make them feel professional

> Distilled from the Case Management Dashboard build (17 widgets shipped). These specs are the bar — match them or beat them; do not regress below them. Every widget you generate or modify MUST adhere.

### A. Page Layout — react-grid-layout configuration

**Breakpoints (canonical):**

| BP | Min width | Cols | Typical KPI placement | Typical chart/table placement |
|----|-----------|------|------------------------|------------------------------|
| `xs` | 0 | 4 | All widgets `w=4` (single column, stacked) | `w=4` full width |
| `sm` | 640 | 6 | KPIs 2 per row (`w=3`) | `w=6` full width |
| `md` | 768 | 8 | KPIs 2 per row (`w=4`) or 3 (`w=3`) | tables `w=8`, charts `w=4` half |
| `lg` | 1024 | 12 | **Canonical layout** — 3 KPIs/row (`w=4`) or 4/row (`w=3`) | full-width tables (`w=12`), half-width charts (`w=6`) |
| `xl` | 1280 | 12 | same as `lg` | same as `lg` |

**Authoring rules:**
- Define the `lg` layout fully (every widget); other breakpoints can be partial — react-grid-layout auto-derives but quality dashboards explicitly override `xs` (`w=4` for everything) and `md`.
- Set `minW` and `minH` on every widget — prevents users from collapsing widgets to unreadable sizes during edit-layout. Common values: KPI `minW=3 minH=2`, table `minW=8 minH=5`, chart `minW=4 minH=4`.
- Each `LayoutConfig.{breakpoint}[i].i` MUST equal the corresponding `ConfiguredWidget[].instanceId`. Mismatches cause widget swap / orphan-cell bugs.
- KPI rows go ON TOP (`y=0`, `y=2`). Tables/charts BELOW. This is reading order — don't bury the headline numbers.

### B. KPI Card (`StatusWidgetType1`) — design contract

**Data shape from BE (Path A `data jsonb` field):**
```json
{
  "value": 2456,
  "formatted": "2,456",
  "subtitle": "↑ 234 new this year",
  "deltaLabel": "234 new this year",
  "deltaColor": "positive",
  "icon": "users-light",
  "color": "teal"
}
```

**Visual hierarchy:**
- Icon pill (top-left): `h-10 w-10 rounded-full bg-{color}-100`, icon `h-5 w-5 text-{color}-600`. Pull `{color}` from `data.color` (`teal` | `blue` | `green` | `orange` | `purple` | `cyan`).
- Title: `text-sm font-medium text-muted-foreground` (Title Case).
- Value: `text-3xl font-bold text-foreground`, with `mb-2` spacing.
- Subtitle (delta): `text-xs`, color from `data.deltaColor`:
  - `positive` → `text-emerald-600`
  - `warning` → `text-amber-600`
  - `neutral` → `text-muted-foreground`
- Card: `bg-card rounded-lg p-4 hover:shadow-md transition-shadow`. No border (flat).

**Skeleton (must match shape):**
```tsx
<div className="space-y-2">
  <Skeleton className="h-3.5 w-1/4" />      {/* title (matches text-sm) */}
  <Skeleton className="h-8  w-1/2 mt-2" />  {/* value (matches text-3xl) */}
  <Skeleton className="h-3  w-3/5" />       {/* subtitle (matches text-xs) */}
</div>
```

**Empty state:** none — KPI always returns a value (zero is a valid result, format as `"0"`).

### C. Table Widget (`FilterTableWidget` / `NormalTableWidget`) — design contract

**Data shape:** `{ rows: [{ ...columns }] }` where each row is a flat object. Status colors come pre-computed from BE (`outcomeColor: 'green'`, `statusBadge: 'red'`).

**Row density & spacing:**
- Row height: `h-12` (48px) — comfortable but compact.
- Row padding: `px-3 py-2`.
- Header: sticky on scroll (`sticky top-0 bg-card`).
- Body: vertical scroll after 8–10 rows visible (`max-h-[480px] overflow-y-auto`).

**Cell renders by column type:**

| Column kind | Render |
|-------------|--------|
| Identifier (with icon) | `<span>{row.icon} {row.name}</span>` — emoji + name, left-aligned |
| Numeric | right-aligned, monospace optional, formatted with thousands separator |
| Percentage with bar | `<div class="h-2 bg-muted rounded-full"><div class="h-full bg-{color}" style="width:{pct}%"/></div>` + label `{pct}%` after |
| Status pill (badge) | `<span class="rounded-full px-2 py-1 text-xs font-medium bg-{color}-100 text-{color}-700">{label}</span>` |
| Threshold count | red badge if > redThreshold, yellow if > yellowThreshold, else plain text |
| Trend (↑ → ↓) | unicode arrow + label, color matches direction (green/gray/red) |

**Status pill color map (semantic):**

| Status | Bg | Text |
|--------|----|----|
| On Track / Healthy / Resolved | `bg-emerald-100` | `text-emerald-700` |
| Needs Attention / At Risk | `bg-amber-100` | `text-amber-700` |
| Below Target / Overdue | `bg-red-100` | `text-red-700` |
| Standby / Inactive | `bg-gray-100` | `text-gray-700` |

**Search bar (FilterTableWidget):** placeholder `"Search {entity}..."`, `input-sm` width full, clear icon `ph:x-circle` on right (only when text entered).

**Row click:** if drill-down configured, whole row gets `cursor-pointer hover:bg-muted/40`. `onClick` calls `router.push(buildRouteWithArgs(row.{idColumn}))`.

**Skeleton (match row shape):**
```tsx
<div className="space-y-2">
  {Array.from({ length: 4 }).map((_, i) => (
    <div key={i} className="flex gap-2 h-12">
      <Skeleton className="flex-1 h-full" />
      <Skeleton className="w-20 h-full" />
      <Skeleton className="w-20 h-full" />
    </div>
  ))}
</div>
```

### D. Chart Widget (`MultiChartWidget` / `PieChartWidgetType1` / `BarChartWidgetType1`) — design contract

**Data shape (line/area/bar):** `{ type: 'area'|'line'|'bar', labels: [...], series: [{name, color, data}] }`. Hex colors come from BE (`#6366f1`); FE consumes verbatim.

**Data shape (pie/donut):** `{ total: number, segments: [{label, value, pct, color}] }`. Render donut with total centered.

**Chart config defaults:**
- Height: chart body `h-72` to `h-80` (288–320px). Total card incl. title/legend `h-96`.
- Tooltip: dark background, white text, `rounded-md shadow-lg`, padding `p-2`. Show all series' values for the hovered x-coord.
- Legend: below chart for line/bar/area, right side for donut. `text-xs`. Color swatches match series colors.
- X-axis labels (time-series): tilt 45° if more than 6 buckets to prevent overlap. Format month labels as `"Jan 2025"`.
- Y-axis: numeric, auto-scale. Show grid lines with `border-muted/40`.

**Skeleton:**
```tsx
<div className="h-80 bg-muted/30 rounded-lg animate-pulse" />
```

**Color palette (BE-driven):**
- Series colors come from BE (`Program.ColorHex`, hardcoded hex in SQL for buckets, severity scales). NEVER override server colors in the FE.
- Default if BE returns null: `#6366f1` (Indigo-500).

### E. Alert/List Widget (`AlertListWidget` — case-dashboard pattern) — design contract

**Data shape:** `{ alerts: [{ severity, iconCode, message, link: { label, route, args } }] }`. Severity is `warning | info | success` (closed enum).

**Per-row design:**
```tsx
<div class="flex items-start gap-3 rounded-md bg-card p-3 border-l-4 border-{severity}-500 hover:bg-muted/40 transition-colors">
  {/* icon pill */}
  <div class="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full bg-{severity}-100">
    <Icon icon="ph:{iconCode}" class="h-5 w-5 text-{severity}-600" />
  </div>
  {/* message */}
  <p class="flex-1 text-sm text-foreground leading-relaxed">{sanitizedMessage}</p>
  {/* CTA */}
  <button class="flex-shrink-0 inline-flex items-center gap-1 rounded-md px-3 py-1.5 text-xs font-medium text-{severity}-700 hover:bg-{severity}-100">
    <span>{link.label}</span><Icon icon="ph:arrow-right" class="h-3.5 w-3.5" />
  </button>
</div>
```

**Severity color map (use exactly these):**

| Severity | Border-left | Icon bg | Icon | Button text | Button hover bg |
|----------|-------------|---------|------|-------------|-----------------|
| `warning` | `border-amber-500` | `bg-amber-100` | `text-amber-600` | `text-amber-700` | `bg-amber-100` |
| `info` | `border-blue-500` | `bg-blue-100` | `text-blue-600` | `text-blue-700` | `bg-blue-100` |
| `success` | `border-emerald-500` | `bg-emerald-100` | `text-emerald-600` | `text-emerald-700` | `bg-emerald-100` |

**Message sanitization (mandatory — alerts may contain `<strong>` for emphasis):**
```ts
function sanitizeAlertMessage(raw: string): string {
  if (!raw) return "";
  const escaped = raw.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  return escaped
    .replace(/&lt;strong&gt;/gi, "<strong>").replace(/&lt;\/strong&gt;/gi, "</strong>")
    .replace(/&lt;em&gt;/gi, "<em>").replace(/&lt;\/em&gt;/gi, "</em>");
}
```
Render with `dangerouslySetInnerHTML={{ __html: sanitized }}`. Only `<strong>` and `<em>` permitted; everything else escaped.

**Icon normalization:** input is bare (`"clock-countdown-light"`); prepend `ph:` if missing before passing to `<DynamicIcon icon={...} />`.

**Container:** `flex flex-col gap-2 w-full h-full overflow-y-auto pr-1`. Scrollable when >6 alerts.

### F. Loading / Empty / Error State Patterns (cross-widget)

**Loading (skeleton)** — every widget renders a shape-matching skeleton. NEVER a generic `h-10 bg-gray-200`. Examples are in sections B–E above.

**Empty state — universal shape:**
```tsx
<div className="flex flex-col items-center justify-center h-32 gap-2">
  <DynamicIcon icon="ph:{contextIcon}" className="h-10 w-10 text-muted-foreground" />
  <p className="text-sm font-medium text-muted-foreground">{message}</p>
</div>
```

| Widget kind | Empty icon | Empty message |
|-------------|-----------|---------------|
| KPI | (no empty — always shows a value) | — |
| Table (programs) | `ph:briefcase` | "No programs in scope" |
| Chart (trend) | `ph:chart-line` | "No data in selected period" |
| Pie (distribution) | `ph:users` | "No records match the filter" |
| Alert | `ph:check-circle` | "No alerts — all clear." |

Min height: `h-32` for compact widgets, `h-52` for full-width tables.

**Error state — universal shape:**
```tsx
<div className="flex flex-col items-center justify-center h-32 gap-2">
  <div className="flex items-center gap-2 rounded-md bg-red-50 px-3 py-2 text-destructive">
    <DynamicIcon icon="ph:warning-circle" className="h-4 w-4" />
    <span className="text-sm font-medium">Failed to load {widgetName}</span>
  </div>
  <button onClick={onRetry} className="rounded-md bg-muted px-3 py-1 text-xs hover:bg-muted/80">Retry</button>
</div>
```

### G. Iconography & Color Conventions

**Icon library: Phosphor only.** Always use the `ph:` prefix at render time (registry adds it if BE supplies bare names). Prefer `-light` variants for KPI/widget chrome (cleaner outlines at small sizes).

Common icons by purpose:
- People/community: `users-light`, `users-three-light`
- Programs/projects: `stack-light`, `briefcase`
- Cases/records: `folder-open-light`
- Outcomes/targets: `target-light`
- Time/overdue: `clock-countdown-light`
- Funding/donations: `hand-heart-light`, `hand-coins`
- Status/feedback: `check-circle`, `warning-circle`, `info`
- Actions: `arrow-right`, `gear`, `download`, `eye`

**Color palette — semantic via Tailwind tokens (never inline hex in components):**

| Use | Class |
|-----|-------|
| Healthy / on-track / positive trend | `text-emerald-600` (≥ 85% threshold) |
| At risk / needs attention | `text-amber-600` (70–84%) |
| Below target / critical | `text-red-600` (< 70%) |
| Inactive / standby | `text-gray-600` |
| Brand accent (default) | `text-primary` |

**Chart series colors come from the BE** (`Program.ColorHex`, hardcoded hex per bucket). The FE never decides chart colors — that ensures cross-widget consistency for the same dimension.

### H. Anti-patterns — these WILL fail review

```tsx
// ❌ Inline hex / px — un-themable, breaks design tokens
<div style={{ color: '#0d9488', marginRight: '12px' }}>
// ✅ Tailwind classes
<div className="text-teal-600 mr-3">

// ❌ Hardcoded widget switch — bypasses registry
if (widget.widgetType === 'KPI') return <StatusWidgetType1 ... />;
// ✅ Registry lookup
const Comp = WIDGET_REGISTRY[widget.widgetType.componentPath];
return <Comp ... />;

// ❌ Crashes on loading state
const W = ({ data }) => <div>{data.alerts.map(...)}</div>;
// ✅ Always handle the three states
if (loading) return <Skeleton... />;
if (error)   return <ErrorBanner onRetry={refetch} />;
if (!alerts.length) return <EmptyState />;

// ❌ Generic skeleton — breaks visual rhythm
if (loading) return <div className="h-10 bg-gray-200" />;
// ✅ Shape-matching skeleton (matches text-sm, text-3xl, text-xs heights)
if (loading) return (
  <div className="space-y-2">
    <Skeleton className="h-3.5 w-1/4" />
    <Skeleton className="h-8 w-1/2 mt-2" />
    <Skeleton className="h-3 w-3/5" />
  </div>
);

// ❌ Unsafe HTML (XSS)
<p dangerouslySetInnerHTML={{ __html: alert.message }} />
// ✅ Sanitize first; only <strong>/<em> permitted
<p dangerouslySetInnerHTML={{ __html: sanitizeAlertMessage(alert.message) }} />
```

---

## MENU_DASHBOARD First-Time Infrastructure (read-only context here — orchestrator handles)

If the prompt is the FIRST MENU_DASHBOARD ever built, additional one-time FE work is in scope (per `_DASHBOARD.md` template preamble):
- Create the dynamic `[lang]/(core)/[module]/dashboards/[slug]/page.tsx` route
- Create the NEW `<MenuDashboardComponent />` at `custom-components/menu-dashboards/index.tsx` — separate from existing `<DashboardComponent />`. Owns its own header (no `<DashboardHeader />` import — that prevents Create/Switcher/Edit chrome leakage). Single Apollo query: `dashboardByModuleAndCode(moduleCode, dashboardCode)`. Reuses existing `WIDGET_REGISTRY` / `QUERY_REGISTRY`.
- Add the new gql doc `dashboardByModuleAndCode` to `infrastructure/gql-queries/setting-queries/` and barrel-export it.
- DELETE per-name hardcoded dashboard pages (`crm/dashboards/contactdashboard/page.tsx`, etc.) — pre-flight grep for any imports first.
- Update `<DashboardHeader />` to add "Promote to menu" / "Hide from menu" kebab actions (only on the existing STATIC component — the new menu component has no edit chrome by design).
- Update sidebar menu-tree composer to inject `menuLinkedDashboardsByModuleCode` results as leaves under each `*_DASHBOARDS` parent (batched, not N+1).

The orchestrator will spell this out explicitly in the prompt's Tasks list. If it's NOT spelled out, this work is already done.
