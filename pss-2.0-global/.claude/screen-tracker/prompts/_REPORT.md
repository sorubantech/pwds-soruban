# Screen Prompt Template — REPORT (v2 — stub)

> For screens that are **parameterized reports** — filters at the top, data table or chart in the middle,
> and export (PDF / Excel / CSV) actions. Different from DASHBOARD: focused on a single report view,
> not a widget overview.
> Canonical reference: **TBD** (first report will set the convention).
>
> Use this when: the mockup is a report page with filter panel → generate → results table/chart → export.
>
> **STATUS**: Stub — common sections (①-④, ⑦-⑫) follow the same conventions as `_MASTER_GRID.md`/`_FLOW.md`.
> Sections ⑤ and ⑥ are report-specific — expand when the first report is planned.

---

## Template

```markdown
---
screen: {EntityName}
registry_id: {#}
module: {Module Name}
status: PENDING
scope: {FULL | BE_ONLY | FE_ONLY | ALIGN}
screen_type: REPORT
complexity: {Low | Medium | High}
new_module: {YES — schema name | NO}
planned_date: {YYYY-MM-DD}
completed_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (filter panel + result view + export identified)
- [x] Source data identified
- [x] Export formats confirmed
- [x] File manifest computed
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (filter panel + result display spec)
- [ ] User Approval received
- [ ] Backend report query generated
- [ ] Frontend report page generated
- [ ] Export handlers implemented (or flagged as SERVICE_PLACEHOLDER)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — report loads
- [ ] Filter panel renders with all controls
- [ ] Generate button triggers query
- [ ] Results render in table / chart / pivot
- [ ] Pagination works (if many rows)
- [ ] Export buttons trigger handlers (real or SERVICE_PLACEHOLDER)
- [ ] Empty/loading/error states render

---

## ① Screen Identity & Context

Screen: {EntityName} Report
Module: {ModuleName}
Schema: {db_schema — usually reuses source schema}
Group: {BackendGroupName}

Business: {What this report shows, who requests it, decision it informs, frequency (daily/monthly)}

---

## ② Entity Definition

> Reports usually don't own a table. Write: "No entity — parameterized query over {source entities}."
> If a cached/materialized view table backs the report, define it.

{Entity or note}

---

## ③ FK Resolution Table

> List source entities for the report.

| Source Entity | Entity File Path | Source Query | Fields Consumed |
|--------------|-------------------|--------------|-----------------|
| ... | ... | ... | ... |

---

## ④ Business Rules & Validation

> Report-specific rules:
> - Required filters (e.g., "Date range is required")
> - Maximum range (e.g., "Max 12 months at a time")
> - Role-based data scoping
> - Derived/computed columns

{Rules}

---

## ⑤ Screen Classification & Pattern Selection

**Screen Type**: REPORT
**Type Classification**: {TBD — tabular / pivot / chart / mixed}

**Backend Patterns Required:**
- [ ] Parameterized report query (Get{Entity}Report)
- [ ] Tenant scoping
- [ ] Role-scoped data filtering
- [ ] Pagination / streaming for large result sets
- [ ] Export formatters (Excel via ClosedXML / PDF via template / CSV) — OR SERVICE_PLACEHOLDER if infrastructure missing

**Frontend Patterns Required:**
- [ ] Report shell page
- [ ] Filter panel (collapsible / sidebar)
- [ ] Generate button → triggers query
- [ ] Results component (table / chart / pivot)
- [ ] Pagination (if tabular)
- [ ] Export action menu (Excel, PDF, CSV)
- [ ] Print view CSS

---

## ⑥ UI/UX Blueprint

### Page Layout

{e.g., "Filter panel top, Generate button, Results below. Or filter panel left, results right."}

### Filter Panel

| # | Filter | Widget | Default | Required | Options Source |
|---|--------|--------|---------|----------|----------------|
| 1 | Date Range | date-range picker | Last month | YES | — |
| 2 | Campaign | multi-select | All | NO | {GQL query} |
| 3 | Status | dropdown | All | NO | enum |
| ... | ... | ... | ... | ... | ... |

### Result View

**Display Type**: {tabular / pivot / chart / mixed}

**Result Columns** (tabular):
| # | Header | Field Key | Format | Aggregation (footer) | Notes |
|---|--------|-----------|--------|---------------------|-------|
| 1 | Date | date | DD-MMM-YYYY | — | — |
| 2 | Contact | contactName | text | — | — |
| 3 | Amount | amount | currency | SUM | Footer total |
| ... | ... | ... | ... | ... | ... |

**Grouping / Subtotals** (if mockup shows):
| Group By | Subtotal Columns | Display |
|----------|------------------|---------|
| Campaign | amount | Group header rows with totals |

**Charts** (if report includes chart view):
| Title | Type | X | Y | Source |
|-------|------|---|---|--------|
| ... | ... | ... | ... | ... |

### Export Actions

| Action | Format | Handler | Notes |
|--------|--------|---------|-------|
| Export Excel | .xlsx | ClosedXML backend endpoint | Or SERVICE_PLACEHOLDER if missing |
| Export PDF | .pdf | PDF service | Often SERVICE_PLACEHOLDER |
| Export CSV | .csv | Frontend CSV generator | Usually feasible client-side |

### User Interaction Flow

1. User opens report → filter panel shows with defaults
2. User sets filters → clicks Generate → query runs → results render
3. User paginates / sorts / groups within results
4. User clicks Export → format menu → handler runs
5. User changes filters → Generate re-fetches

---

## ⑦ Substitution Guide

> **TBD** — set when first report is built.

---

## ⑧ File Manifest

### Backend Files

| # | File | Path |
|---|------|------|
| 1 | Report DTO | Pss2.0_Backend/.../Base.Application/Schemas/{Group}Schemas/{EntityName}ReportSchemas.cs |
| 2 | Report Query | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/ReportQuery/Get{EntityName}Report.cs |
| 3 | Export Handler (if impl) | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/ReportExport/Export{EntityName}Report.cs |
| 4 | Queries endpoint | Pss2.0_Backend/.../Base.API/EndPoints/{Group}/Queries/{EntityName}Queries.cs (add GetReport) |

### Frontend Files

| # | File | Path |
|---|------|------|
| 1 | DTO Types | Pss2.0_Frontend/src/domain/entities/{group}-service/{EntityName}ReportDto.ts |
| 2 | GQL Query | Pss2.0_Frontend/src/infrastructure/gql-queries/{group}-queries/{EntityName}ReportQuery.ts |
| 3 | Report Page | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/report-page.tsx |
| 4 | Filter Panel | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/filter-panel.tsx |
| 5 | Result View | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/result-view.tsx |
| 6 | Route Page | Pss2.0_Frontend/src/app/[lang]/(core)/{group}/{feFolder}/{entity-lower}/page.tsx |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: {FULL | BE_ONLY | FE_ONLY}

MenuName: {Report Display Name}
MenuCode: {ENTITYUPPER}
ParentMenu: {PARENTMENUCODE}
Module: {MODULECODE}
MenuUrl: {group/feFolder/entitylower}
GridType: REPORT

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
| Get{EntityName}Report | {EntityName}ReportDto | dateFrom, dateTo, {filter1}, {filter2}, pageNo, pageSize |
| Export{EntityName}Report | string (file URL or base64) | same filters + format |

**Report DTO:**
| Field | Type | Notes |
|-------|------|-------|
| rows | [ReportRowDto] | Result rows |
| totalCount | number | For pagination |
| subtotals | [SubtotalDto] | If grouping |
| footerTotals | {column: number} | Column sums/aggregates |

---

## ⑪ Acceptance Criteria

- [ ] Filter panel renders all controls with defaults
- [ ] Required filters enforce validation
- [ ] Generate button triggers report query
- [ ] Results render in correct format (table/chart/pivot)
- [ ] Pagination / sort / group works
- [ ] Footer totals correct
- [ ] Export actions trigger handlers
- [ ] Empty state when no rows match filters
- [ ] Role-scoped data enforced

---

## ⑫ Special Notes & Warnings

- Reports are read-only — no CRUD
- Large result sets need pagination or streaming
- PDF export often requires external service — flag as SERVICE_PLACEHOLDER if not in codebase
- {e.g., "Financial reports require role-gated access — STAFFDATAENTRY should not see donor amounts"}

**Service Dependencies**: {list exports that depend on missing services}
- {e.g., "⚠ SERVICE_PLACEHOLDER: PDF export — full UI implemented, handler shows toast. Reason: no PDF generator in codebase."}
```

---

## Section Purpose Summary

| # | Section | Who Reads It | What It Answers |
|---|---------|-------------|-----------------|
| ⑤ | Classification | Solution Resolver | "Report patterns (parameterized, export)" |
| ⑥ | UI/UX Blueprint | UX Architect → FE Dev | "Filter panel + result view + export actions" |

**Note to /plan-screens**: When planning the first REPORT screen, expand this stub with real conventions.
