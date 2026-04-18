# Screen Prompt Template — DASHBOARD (v2 — stub)

> For screens that show **summary widgets, KPI cards, charts, and drill-down filters** (no CRUD grid as primary UI).
> Canonical reference: **TBD** (not yet built — first dashboard will set the convention).
>
> Use this when: the mockup is a dashboard/overview page with widget grid, charts, date-range filters,
> and navigation-to-detail behavior. Entity backing may be aggregate queries across multiple source tables.
>
> **STATUS**: Stub — the common sections (①-④, ⑦-⑫) follow the same conventions as `_MASTER_GRID.md`/`_FLOW.md`.
> Sections ⑤ and ⑥ are dashboard-specific — expand when the first dashboard is planned.

---

## Template

```markdown
---
screen: {EntityName}
registry_id: {#}
module: {Module Name}
status: PENDING
scope: {FULL | BE_ONLY | FE_ONLY | ALIGN}
screen_type: DASHBOARD
complexity: {Low | Medium | High}
new_module: {YES — schema name | NO}
planned_date: {YYYY-MM-DD}
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (widgets, charts, filters identified)
- [x] Aggregate query sources identified
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (widget grid + chart specs)
- [ ] User Approval received
- [ ] Backend aggregate queries generated
- [ ] Frontend dashboard page generated
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — dashboard loads
- [ ] Each widget fetches and displays correct data
- [ ] Charts render correctly with sample data
- [ ] Date-range / filter controls update widgets + charts
- [ ] Drill-down clicks navigate to correct detail screen
- [ ] Empty/loading/error states render

---

## ① Screen Identity & Context

> Follow same format as `_MASTER_GRID.md` §①. Emphasize:
> - Target audience (exec, operations, staff)
> - What decisions/actions this dashboard supports
> - How it rolls up data from which source modules

Screen: {EntityName}
Module: {ModuleName}
Schema: {db_schema — usually NONE; aggregates across schemas}
Group: {BackendGroupName — e.g., DashboardModels or reuses module group}

Business: {...}

---

## ② Entity Definition

> Dashboards usually don't own a table — they compose views over existing entities.
> If a summary table IS needed (e.g., cached aggregates), define it here.
> Otherwise write: "No entity — composes aggregate queries over {source entities}."

{Entity or note}

---

## ③ FK Resolution Table

> List the SOURCE entities whose data this dashboard aggregates.
> Dashboards typically read from many tables — list each with its file path and aggregate query path.

| Source Entity | Entity File Path | Aggregate Query | Fields Consumed |
|--------------|-------------------|-----------------|-----------------|
| ... | ... | ... | ... |

---

## ④ Business Rules & Validation

> Rules are less about CRUD validation, more about:
> - Date range defaults (e.g., "last 30 days")
> - Role-based data scoping (what each role can see)
> - Calculation rules (how KPIs are computed)

{Rules}

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver

**Screen Type**: DASHBOARD
**Type Classification**: {TBD — introduce dashboard types as built}
**Reason**: {why}

**Backend Patterns Required:**
- [ ] Aggregate query endpoint (Get{Entity}DashboardData) — returns composite DTO
- [ ] Tenant scoping (CompanyId from HttpContext)
- [ ] Date-range parameterized queries
- [ ] Role-scoped filtering (per user role)
- [ ] Cached/materialized view — {if performance requires}

**Frontend Patterns Required:**
- [ ] Dashboard shell page (no FlowDataTable)
- [ ] Widget grid component
- [ ] KPI card components
- [ ] Chart library wrapper (bar, line, pie, etc.)
- [ ] Date-range picker
- [ ] Filter/segment controls
- [ ] Drill-down link handlers

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Dashboards are widget grids — extract each widget, chart, and filter from the mockup.

### Page Layout

**Grid Layout**: {e.g., "12-column grid, responsive"}

| Row | Widgets / Cards / Charts | Span |
|-----|--------------------------|------|
| 1 | KPI: Total X, KPI: Total Y, KPI: Growth Z | 4-4-4 |
| 2 | Chart: Revenue by Month | 12 |
| 3 | Table: Top 10 Donors, Chart: Breakdown by Type | 6-6 |
| ... | ... | ... |

### KPI Cards / Counters

| # | Title | Value Source | Format | Sparkline/Trend | Drill-down Link |
|---|-------|-------------|--------|-----------------|-----------------|
| 1 | {e.g., "Total Donations"} | {query.totalDonations} | currency | Yes/No | /crm/donation/globaldonation |
| ... | ... | ... | ... | ... | ... |

### Charts

| # | Title | Type | X-Axis | Y-Axis | Source Query | Filters Honored |
|---|-------|------|--------|--------|--------------|-----------------|
| 1 | {e.g., "Revenue by Month"} | bar | Month | Amount | {GQL query} | dateRange, campaign |
| ... | ... | ... | ... | ... | ... | ... |

### Filter Controls

| Filter | Type | Default | Applies To |
|--------|------|---------|-----------|
| Date Range | date-range picker | Last 30 days | All widgets |
| Campaign | multi-select | All | Revenue chart, donor table |
| ... | ... | ... | ... |

### Drill-Down / Navigation

| From | Click On | Navigates To |
|------|---------|--------------|
| KPI: Total Donations | Card click | /crm/donation/globaldonation |
| Chart bar | Bar click | /crm/donation/globaldonation?mode=read&id=... |
| Top Donor row | Row click | /crm/contact/contact?mode=read&id=... |
| ... | ... | ... |

### User Interaction Flow

1. User opens dashboard → default date range applied → all widgets load
2. User changes date range → all widgets refetch
3. User changes filter (e.g., campaign) → dependent widgets refetch
4. User clicks KPI or chart element → navigates to underlying list/detail
5. Back → returns to dashboard (filters preserved in URL params if possible)

---

## ⑦ Substitution Guide

> **TBD** — set when first dashboard is built.

---

## ⑧ File Manifest

### Backend Files ({N})

| # | File | Path |
|---|------|------|
| 1 | Dashboard DTO | Pss2.0_Backend/.../Base.Application/Schemas/{Group}Schemas/{EntityName}DashboardSchemas.cs |
| 2 | Dashboard Query | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/DashboardQuery/Get{EntityName}Dashboard.cs |
| 3 | Queries endpoint | Pss2.0_Backend/.../Base.API/EndPoints/{Group}/Queries/{EntityName}Queries.cs (add GetDashboard) |
| ... | ... | ... |

### Frontend Files ({N})

| # | File | Path |
|---|------|------|
| 1 | DTO Types | Pss2.0_Frontend/src/domain/entities/{group}-service/{EntityName}DashboardDto.ts |
| 2 | GQL Query | Pss2.0_Frontend/src/infrastructure/gql-queries/{group}-queries/{EntityName}DashboardQuery.ts |
| 3 | Dashboard Page | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/dashboard-page.tsx |
| 4 | Widget Components | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/widgets/*.tsx |
| 5 | Route Page | Pss2.0_Frontend/src/app/[lang]/(core)/{group}/{feFolder}/{entity-lower}/page.tsx |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: {FULL | BE_ONLY | FE_ONLY}

MenuName: {Display Name}
MenuCode: {ENTITYUPPER}
ParentMenu: {PARENTMENUCODE}
Module: {MODULECODE}
MenuUrl: {group/feFolder/entitylower}
GridType: DASHBOARD

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT

GridFormSchema: SKIP
GridCode: {ENTITYUPPER}
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| Get{EntityName}Dashboard | {EntityName}DashboardDto | dateFrom, dateTo, filters... |

**Dashboard DTO** (composite — groups all widget/chart data):
| Field | Type | Notes |
|-------|------|-------|
| totalX | number | For KPI card 1 |
| totalY | number | For KPI card 2 |
| revenueByMonth | [ChartPointDto] | For line chart |
| topDonors | [DonorRowDto] | For top-N table |
| ... | ... | ... |

---

## ⑪ Acceptance Criteria

- [ ] Dashboard loads with default date range
- [ ] All KPI cards show correct values
- [ ] All charts render with correct data
- [ ] Date range change refetches all widgets
- [ ] Filter change refetches affected widgets only
- [ ] Drill-down navigation works to correct detail screen
- [ ] Empty state renders when no data
- [ ] Loading skeleton renders during fetch
- [ ] Role-based data scoping enforced on backend

---

## ⑫ Special Notes & Warnings

- Dashboards read-only — no CRUD
- Single composite query preferred over N separate queries (performance)
- Use materialized views if aggregation is slow
- {e.g., "This is the first dashboard — establish patterns for widget component lib"}

**Service Dependencies**: {usually NONE for dashboards, but note if export to Excel/PDF uses external service}

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — no issues raised yet) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}
```

---

## Section Purpose Summary

| # | Section | Who Reads It | What It Answers |
|---|---------|-------------|-----------------|
| ⑤ | Classification | Solution Resolver | "Dashboard patterns (no CRUD)" |
| ⑥ | UI/UX Blueprint | UX Architect → FE Dev | "Widget grid layout + KPI cards + charts + filters + drill-downs" |

**Note to /plan-screens**: When planning the first DASHBOARD screen, expand this stub with real conventions based on the mockup. Commit the enriched template back so subsequent dashboards reuse it.
