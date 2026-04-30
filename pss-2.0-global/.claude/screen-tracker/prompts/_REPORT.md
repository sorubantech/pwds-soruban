# Screen Prompt Template — REPORT (v1)

> For screens that are **parameterized analytical / operational reports** — filter panel selects
> the data slice, the screen renders the result (table / pivot / chart / document), and the user
> typically exports or prints the output.
>
> Canonical reference: **TBD** — first proper REPORT sets the convention per sub-type.
>
> Use this when the mockup is one of:
> - **Tabular report** with filters → grid → grouping/subtotals/footer + Excel/CSV/PDF export — `TABULAR`
> - **Pivot or chart-primary analytical view** with row × column dimensions or a hero chart + supporting data — `PIVOT_CHART`
> - **Per-record fixed-layout document** (donor statement, tax receipt, certificate, compliance form) — `DOCUMENT`
>
> Do NOT use for:
> - Transactional CRUD with submit/approve workflow even if named "Report" (e.g. `grantreport` is FLOW — funder progress narratives with a submit/accept lifecycle)
> - Widget overviews (use `_DASHBOARD.md` — many widgets vs one focused report)
> - Configuration screens (use `_CONFIG.md`)
> - Lookup CRUDs (use `_MASTER_GRID.md`)
>
> ---
>
> ### 🧠 Each REPORT is UNIQUE — the developer owns the design
>
> A donor statement is not a monthly donation summary is not a campaign performance pivot.
> The patterns below are scaffolding, not a frozen spec. Same principle as CONFIG/DASHBOARD:
>
> 1. **Read the business context first** — who runs this report, how often, what decision it
>    informs, what data sensitivity, what scale (rows? recipients? frequency?). The answer
>    shapes the filter panel, the result view, the pagination strategy, and the export format —
>    not a template.
> 2. **Pick the sub-type that fits** — `TABULAR` / `PIVOT_CHART` / `DOCUMENT` (or hybrid). Stamp
>    it in §⑤. If none fit cleanly (mixed layout with KPIs + chart + table + document), pick
>    the dominant flavor and document the hybrid in §⑫.
> 3. **Design the result view per shape** — a 30-row donor statement looks different from a
>    100k-row donation register which looks different from a 12×12 month-vs-campaign pivot.
>    Identical "table for everything" treatment is wrong.
> 4. **Pagination, max-row guards, and streaming match the scale** — small report (<5k rows):
>    fetch all + client paginate. Mid (<100k): server pagination. Large (>100k): streaming
>    export only, no on-screen render of the full set.
> 5. **Document deviations** — if the developer departs from the prompt's filter list or
>    column list based on business context, log the deviation in §⑫ ISSUE entry.

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
report_subtype: {TABULAR | PIVOT_CHART | DOCUMENT}
complexity: {Low | Medium | High}
new_module: {YES — schema name | NO}
planned_date: {YYYY-MM-DD}
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type identified: TABULAR / PIVOT_CHART / DOCUMENT)
- [x] Source data identified (entities + how they join + computed columns)
- [x] Filter panel inventoried (each filter: required/optional, default, validation)
- [x] Result shape inventoried (columns / pivot axes / chart type / document layout)
- [x] Scale estimated (typical row count, max row count, frequency of run)
- [x] Pagination strategy chosen (client-paginate / server-paginate / streaming)
- [x] Export formats confirmed (Excel / PDF / CSV / Print) and SERVICE_PLACEHOLDER flags set
- [x] Role-scoping rules captured (data row-level security per role)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated (audience, frequency, decisions, data sensitivity)
- [ ] Solution Resolution complete (sub-type confirmed, pagination + export formats confirmed)
- [ ] UX Design finalized (filter panel + result view + export menu — per sub-type)
- [ ] User Approval received
- [ ] Backend report query generated   ← skip if FE_ONLY
- [ ] Backend export handlers (real or SERVICE_PLACEHOLDER)
- [ ] Backend wiring complete          ← skip if FE_ONLY
- [ ] Frontend report page generated   ← skip if BE_ONLY
- [ ] Frontend wiring complete         ← skip if BE_ONLY
- [ ] DB Seed script generated (menu entry; usually no GridFormSchema)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — report loads at correct route
- [ ] Filter panel renders all controls with defaults
- [ ] Required filters enforce validation; "Generate" disabled until valid
- [ ] Generate button triggers query (loading state visible)
- [ ] **Sub-type-specific result checks** (pick the matching block):
  - TABULAR:
    - [ ] Result table renders with all columns + correct widths + alignments
    - [ ] Sort + pagination work (server-side for large reports, client-side OK for small)
    - [ ] Grouping renders group header rows with subtotals (if grouping enabled)
    - [ ] Footer totals render (if mockup shows footer aggregates)
    - [ ] Empty state renders when filters return zero rows
    - [ ] Drill-down click navigates to source record (if drill-down enabled)
  - PIVOT_CHART:
    - [ ] Pivot renders with correct row × column axes + cell values
    - [ ] Pivot row/column totals render
    - [ ] Charts render with correct type per data shape (no "bar chart for everything")
    - [ ] Chart legend + tooltip + axis labels readable; supporting palette semantic
    - [ ] Drill-down click on pivot cell or chart segment navigates correctly (if enabled)
  - DOCUMENT:
    - [ ] Document renders matching the print/PDF layout exactly (header / body / footer)
    - [ ] Per-record paging (one record per page) — page break CSS verified
    - [ ] Header has tenant logo + tenant address + report title (if applicable)
    - [ ] Footer has page number + generation date + "X of Y" (if multi-page)
    - [ ] Print preview matches on-screen render
    - [ ] PDF export produces identical layout (NOT a screenshot)
- [ ] Export Excel / PDF / CSV trigger handlers (real or SERVICE_PLACEHOLDER toast)
- [ ] Pagination / max-row guard kicks in if user requests beyond limit (e.g. "Result exceeds 30k rows — please narrow filters or use Excel export")
- [ ] Loading / empty / error states render with shape-matched skeletons
- [ ] Role-scoped data enforced (e.g. STAFFENTRY sees only own branch data)
- [ ] Saved views / saved filters work (if implemented)
- [ ] Print view CSS verified (`@media print` rules hide filters + actions)
- [ ] DB Seed — menu visible in sidebar at correct parent

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: {EntityName} Report
Module: {ModuleName}
Schema: {db_schema} (typically reuses source entity schema — reports rarely own a table)
Group: {BackendGroupName}

Business: {Rich description — 5-7 sentences covering:
  - WHAT this report shows (rows / cells / sections)
  - WHO runs it (BUSINESSADMIN, STAFFADMIN, FIELDAGENT, donor-facing self-service?) and HOW OFTEN (daily reconciliation / monthly close / ad-hoc / scheduled email)
  - WHY it exists — what decision it informs, what compliance need it serves, what stakeholder receives it
  - WHAT'S the typical and maximum scale (rows × frequency × concurrency) — drives pagination/export strategy
  - WHAT data sensitivity (PII, donation amounts, financial detail) and which roles see what subset
  - WHAT format the recipient expects (Excel for analyst, PDF for board, printed letter for donor) — drives export priority
  - HOW it relates to other screens (drill-down to source records? feeds Dashboard widgets? exported to file the donor receives?)}

> **Why this section is heavier**: REPORT design is shaped by the audience and decision more
> than by the source data. A "donor statement" emailed to donors needs a polished PDF document;
> a "donation register" run by an accountant needs an Excel-clean tabular export with subtotals;
> a "campaign performance" run by a fundraiser needs a chart and a few KPIs. Same source data,
> three completely different REPORT screens.

---

## ② Source Model

> **Consumer**: BA Agent → Backend Developer
> Reports rarely own a table — they query existing entities. State the source pattern.

**Source Pattern** (REQUIRED — stamp one):

| Pattern | Use when | Storage |
|---------|----------|---------|
| `query-only` | Aggregating existing entities at run time (default for analytical reports) | No new table — query joins source entities |
| `materialized-view` | High-frequency / heavy-aggregation report where on-demand query is too slow | Postgres materialized view refreshed on schedule |
| `snapshot-table` | Compliance/audit report that must show point-in-time data even if source records change later | Snapshot table populated on-demand or scheduled (rare) |
| `report-row-table` | Per-recipient document that's emitted (e.g. tax-receipt records the certificate as a row) | Reports table with one row per generated document |

**Stamp**: `{query-only | materialized-view | snapshot-table | report-row-table}`

### Source Entities

> List every entity the report queries. For `query-only`, this is the source-of-truth. For
> `materialized-view` / `snapshot-table` / `report-row-table`, also state the storage table.

| Source Entity | Entity File Path | Fields Consumed | Join Cardinality | Filter |
|---------------|------------------|-----------------|------------------|--------|
| {e.g. Donation} | Base.Domain/Models/{Group}Models/Donation.cs | DonationDate, Amount, ContactId, CampaignId, Status | parent | IsActive=true, CompanyId from HttpContext |
| {e.g. Contact} | …/CorgModels/Contact.cs | ContactName, Email, ContactTypeId | 1:1 via ContactId | — |
| {e.g. Campaign} | …/CampModels/Campaign.cs | CampaignName, FundraisingGoal | 1:1 via CampaignId | optional |
| ... | ... | ... | ... | ... |

### Storage Table (only when source pattern is NOT query-only)

| Field | C# Type | MaxLen | Notes |
|-------|---------|--------|-------|
| {EntityName}Id | int | — | PK |
| CompanyId | int | — | tenant scope |
| GeneratedAt | DateTime | — | for snapshot/report-row |
| FilterJson | string | — | params used to generate |
| ResultPayload | jsonb | — | snapshot payload OR fk to recipient + rendered fields |
| ... | ... | ... | ... |

### Computed / Derived Columns

| Column Name | Formula | Source | Notes |
|-------------|---------|--------|-------|
| {RemainingDays} | DueDate - today | parent | client-side acceptable |
| {RecognitionAmount} | sum(Amount) WHERE … | aggregated | server-side (LINQ subquery or PG function) |
| {YearOnYearGrowth} | (ThisYear - LastYear) / LastYear | aggregated | server |
| ... | ... | ... | ... |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and joins) + Frontend Developer (for ApiSelect filter dropdowns).

| FK / Filter Source | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type | Used For |
|--------------------|--------------|-------------------|----------------|---------------|-------------------|----------|
| ContactId (filter) | Contact | …/CorgModels/Contact.cs | GetAllContactList | ContactName | ContactResponseDto | filter dropdown + result column |
| CampaignId (filter) | Campaign | …/CampModels/Campaign.cs | GetAllCampaignList | CampaignName | CampaignResponseDto | filter chips |
| BranchId (data scope) | Branch | …/AppModels/Branch.cs | GetAllBranchList | BranchName | BranchResponseDto | role-scoping filter |
| ... | ... | ... | ... | ... | ... | ... |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (filter validation)

**Required Filters:**
- {e.g. "Date range is required — defaults to current month"}
- {e.g. "At least one of Campaign / Donor / Status must be set when running unfiltered would exceed 100k rows"}

**Filter Validation:**
- {e.g. "Date range max 12 months — show inline error 'Please narrow to 12 months or less'"}
- {e.g. "Donor multi-select max 50 selections — performance ceiling"}
- {e.g. "Date end must be ≥ Date start"}

**Computed-Column Rules:**
- {e.g. "RecognitionAmount excludes refunded donations"}
- {e.g. "VarianceStatus = OK if -10% ≤ delta ≤ 10%, AT_RISK if -25% ≤ delta < -10%, CRITICAL if delta < -25%"}

**Role-Based Data Scoping** (row-level security):
| Role | Sees | Excluded |
|------|------|----------|
| BUSINESSADMIN | all data for tenant | none |
| {e.g. STAFFADMIN} | all data for own branches | other branches |
| {e.g. FIELDAGENT} | only records assigned to user | rest |
| {e.g. DONOR-SELFSERVE} | only own donations / receipts | rest |

> **Implementation note**: scoping happens in BE — adjust query's `WHERE` clauses based on
> identity. FE never trusts client-provided role for data filtering.

**Sensitive Data Handling:**
| Field | Sensitivity | Display Treatment | Export Treatment |
|-------|-------------|-------------------|------------------|
| {Tax ID / SSN} | PII | masked (`••••XXXX`) on screen for non-admin | omitted from CSV; admin-only PDF |
| {Donation amount} | financial | visible to admin + donor (own); hidden from FIELDAGENT | excluded from FIELDAGENT exports |
| {Bank account} | secret | never displayed | never exported |

**Max-Row Guard** (REQUIRED for query-only / large-set reports):
- On-screen render limit: {e.g. 30,000 rows} — beyond this, show "Result exceeds {N} rows — narrow filters or use Excel export" with disable-render + offer Excel
- Excel/CSV export limit: {e.g. 250,000 rows} — beyond this, queue async + email link (SERVICE_PLACEHOLDER if email service missing)

**Workflow** (rare for REPORT — only if reports have draft/finalize lifecycle):
- {e.g. "Donor statements: GENERATED → SENT → ACKNOWLEDGED. Once SENT, cannot regenerate without 'Reissue' confirmation + audit"}
- Or "Workflow: None"

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: REPORT
**Report Sub-type**: `{TABULAR | PIVOT_CHART | DOCUMENT}`
**Source Pattern**: `{query-only | materialized-view | snapshot-table | report-row-table}`
**Pagination Strategy** (REQUIRED — stamp one):

| Strategy | When to pick | UI cue |
|----------|--------------|--------|
| `client-paginate` | Result fits in memory (<5k rows), single GraphQL fetch returns all | Standard pagination control on the table |
| `server-paginate` | Mid-scale (<100k rows), each page is a separate fetch | Pagination triggers fetch with `pageNo` arg |
| `streaming-export-only` | Very large (>100k rows). Screen shows summary or first N preview rows; full result only via Excel export streamed | "Preview shows first 100 rows — use Export Excel for full result" notice |

**Reason**: {1-2 sentences — why this sub-type, source pattern, and pagination from §①}

**Backend Patterns Required:**

For **TABULAR** report:
- [x] Get{Entity}Report query — accepts filter args + pageNo/pageSize/sortField/sortDir, returns `{rows, totalCount, footerTotals, subtotals}`
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Role-based data filtering applied in WHERE clauses
- [ ] Grouping/subtotal computation in query (LINQ GroupBy + projection) — only when mockup shows grouping
- [x] Footer totals computation (server-side aggregate over filtered set, NOT just current page)
- [ ] Excel export handler (ClosedXML / EPPlus) — OR SERVICE_PLACEHOLDER
- [ ] PDF export handler — OR SERVICE_PLACEHOLDER
- [ ] CSV export handler — usually feasible without external service
- [ ] Materialized-view refresh job (if source pattern is materialized-view)

For **PIVOT_CHART** report:
- [x] Get{Entity}PivotData query — returns `{rows: [{rowDim, columnDim, value}], rowAxes, columnAxes, totals}`
- [x] Tenant scoping + role filtering
- [x] Aggregation (SUM / COUNT / AVG / MIN / MAX) computed server-side
- [ ] Multi-aggregate support (e.g. count + sum in same pivot) — only when needed
- [ ] Time-series query for chart (when chart type is line/area)
- [ ] Drill-down query — `Get{Entity}DetailsByPivotCell` returns the rows behind a cell

For **DOCUMENT** report:
- [x] Get{Entity}Document query — returns the data for ONE document (or batch of N for bulk generation)
- [ ] PDF generation handler — typically SERVICE_PLACEHOLDER unless external service exists
- [ ] Document-row persistence (when source pattern is report-row-table — e.g. one tax-receipt row per generated document)
- [ ] Bulk-generate command — `Generate{Entity}DocumentsBulk(filters)` returns count + zip URL OR queue id (SERVICE_PLACEHOLDER if streaming missing)
- [ ] Reissue command + audit-log entry (if workflow has reissue)

**Frontend Patterns Required:**

For **TABULAR**:
- [x] Report page shell (header + filter panel + result region + export menu)
- [x] Filter panel (collapsible top OR fixed sidebar)
- [x] Generate button (disabled until required filters valid)
- [x] Result table (`<AdvancedDataTable>` with footer totals + group rows)
- [x] Pagination (server / client per strategy)
- [x] Export menu (Excel / CSV / PDF / Print)
- [x] Print view CSS (`@media print` hides filter + action chrome)
- [x] Empty state (when zero rows)
- [x] Max-row guard banner (when over limit)
- [ ] Saved Views (named filter combos saved per user)

For **PIVOT_CHART**:
- [x] Report page shell
- [x] Filter panel
- [x] Generate button
- [x] Pivot table component (sticky header row + column, cell formatting per measure type)
- [x] Chart components (one or more — line / area / donut / stacked-bar / grouped-bar — picked per data shape)
- [x] Chart legend + tooltip + axis label spec
- [x] Drill-down navigation (cell click → navigate to TABULAR detail or source list)
- [x] Empty state
- [ ] Toggle table ↔ chart view (if mockup offers both)

For **DOCUMENT**:
- [x] Report page shell — minimal (filter panel + recipient picker + Generate)
- [x] Document component (matches PDF/print layout — A4 dimensions, header/body/footer)
- [x] Per-record pagination (when bulk — each record on its own page)
- [x] Print preview view
- [x] Export PDF (single or zipped bulk)
- [x] Send by email button (typically SERVICE_PLACEHOLDER)
- [x] Print view CSS (`@media print` exact match — page-break-after, page-break-inside-avoid)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: This section is the design spec. Each REPORT has a UNIQUE shape — fill in
> ONLY the matching sub-type block plus the shared blocks at the bottom. Delete the blocks
> that don't apply when generating the actual screen prompt.

### 🎨 Visual Treatment Rules (apply to ALL sub-types)

> Same intent as DASHBOARD/CONFIG: avoid uniform-clone treatments.

1. **Filter panel structure reflects user mental model** — group filters by domain
   (Date / Donor / Campaign / Status), not alphabetically or in source-table order. Required
   filters cluster at top with subtle "required" affordance; optional filters can collapse.
2. **Result region treatment matches sub-type**:
   - TABULAR → dense table with right-aligned numerics, monospace amounts, group-row chrome distinct from data rows, footer-total row visually separated (top-border + bold)
   - PIVOT_CHART → pivot has sticky row+column header bands; chart has semantic palette (success/warning/error meaningful, not random rainbow)
   - DOCUMENT → centered max-width A4 white card with the tenant brand at the top; no app chrome inside the document area
3. **Pick chart type per data shape, not preference** — trends → line/area; parts-of-whole →
   donut/stacked-bar; comparisons across categories → grouped-bar; distributions → histogram;
   geographic → map. Don't toggle `chartType` on a single component for everything.
4. **Loading skeletons match the actual shape** — table skeletons show row outlines; pivot shows
   a faded matrix; document shows a faded A4 page outline. Generic shimmer rectangles are wrong.
5. **Export menu groups formats by use** — Analyst (Excel, CSV) | Stakeholder (PDF, Print) |
   Schedule (Email, Subscribe) — not a flat list.
6. **Empty states are diagnostic** — instead of "No results", say "No donations match Status =
   Refunded between Apr 1 – Apr 30. Try widening the date range." (specific to filters set)

**Anti-patterns to refuse**:
- Filter panel as one giant flat form with 20 fields and no grouping
- "Generate" button hardcoded, even when filters haven't changed (re-fetch wastes server)
- Excel export that's just CSV-with-xlsx-extension (no formatting, no totals row formatting)
- PDF that's a screenshot of HTML (use a layout engine — print-CSS or PDF template)
- Drill-down that opens in same window without preserving back-navigation state
- Chart with random rainbow palette where colors carry no semantic
- 100k+ row report rendered fully on screen with no pagination or max-row guard

---

### 🅰️ Block A — TABULAR (fill if sub-type = TABULAR)

#### Filter Panel

**Panel Position** (REQUIRED — stamp one): `{top-collapsible | fixed-top | left-sidebar}`

| Position | When to pick |
|----------|--------------|
| `top-collapsible` | 4-8 filters, occasional re-run | header bar that collapses after Generate |
| `fixed-top` | 2-4 filters, frequent re-run, filters are quick-access | always-visible compact bar |
| `left-sidebar` | 8+ filters with deep grouping (date / donor / campaign / status / advanced) | sidebar nav-style |

**Filter Definitions** (in display order):

| # | Filter | Widget | Default | Required | Group | Options Source | Validation |
|---|--------|--------|---------|----------|-------|----------------|------------|
| 1 | Date Range | date-range picker | Last month | YES | Date | — | start ≤ end, ≤ 12mo |
| 2 | Campaign | multi-select | All | NO | Donor | GetAllCampaignList | — |
| 3 | Status | dropdown | All | NO | Status | enum | — |
| 4 | Min Amount | currency input | — | NO | Amount | — | ≥ 0 |
| 5 | Donor Type | chip-toggle (multi) | All | NO | Donor | enum (Individual/Corporate/Foundation) | — |
| ... | ... | ... | ... | ... | ... | ... | ... |

**Saved Views** (optional — only if mockup shows):
- "Save Current Filters" → name + share-with-team toggle → POST SaveReportView
- Saved Views dropdown loads named filter combos
- Default View selectable per user

#### Result Table

**Display Type**: tabular, paginated
**Pagination Strategy**: `{client-paginate | server-paginate | streaming-export-only}` (matches §⑤ stamp)
**Page Size**: {25 | 50 | 100} (default {50})
**Default Sort**: `{column} {asc | desc}`

**Columns** (in display order):

| # | Header | Field Key | Display Type | Width | Align | Sortable | Aggregation (footer) | Group | Notes |
|---|--------|-----------|--------------|-------|-------|----------|---------------------|-------|-------|
| 1 | Date | date | DD-MMM-YYYY | 110px | left | YES | — | optional group-by | — |
| 2 | Receipt # | receiptNo | text | 120px | left | YES | — | — | drill-down link to donation record |
| 3 | Donor | contactName | text | auto | left | YES | — | optional group-by | drill-down to donor profile |
| 4 | Campaign | campaignName | text | 200px | left | YES | — | optional group-by | — |
| 5 | Mode | donationMode | badge | 100px | left | YES | COUNT (per group) | — | color-coded |
| 6 | Amount | amount | currency | 130px | right | YES | SUM (per group + grand total) | — | monospace |
| 7 | Status | status | badge | 100px | left | YES | COUNT (per group) | — | — |
| ... | ... | ... | ... | ... | ... | ... | ... | ... | ... |

**Grouping / Subtotals** (only if mockup shows):

| Group By Field | Display | Subtotal Columns | Default State |
|----------------|---------|------------------|---------------|
| {Campaign} | Group header row with campaign name + count + sum | amount (SUM), donations (COUNT) | expanded |
| {Month} | Group header row | amount (SUM) | collapsed (click to expand) |

**Footer Totals** (always — over filtered full set, NOT just current page):

| Column | Aggregate | Notes |
|--------|-----------|-------|
| Mode | COUNT | total transactions |
| Amount | SUM | bold + top-border row |

**Drill-down** (per row):
- Row click → navigate to source record `?mode=read&id={id}` (if applicable)
- Donor name click → navigate to `/crm/contact/contact?mode=read&id={contactId}`
- Campaign click → navigate to campaign detail

**Empty State**: "No donations match {filterSummary}. Try widening Date Range or clearing Status."

#### Export Actions

| Action | Format | Handler | Notes |
|--------|--------|---------|-------|
| Export Excel | .xlsx (formatted: bold header, currency cells, group totals styled) | ClosedXML BE endpoint | Include filter summary in row 1 + frozen header |
| Export CSV | .csv | client-side CSV generator | Plain rows, no totals (analyst slices) |
| Export PDF | .pdf | print-CSS → `window.print()` OR PDF template | SERVICE_PLACEHOLDER if no PDF service |
| Print | print-CSS rendered | browser print | always feasible |

#### User Interaction Flow (TABULAR)

1. User opens report → filter panel renders with defaults → Generate button enabled if defaults are valid
2. User adjusts filters → Generate button stays enabled (filters dirty) — re-fetch on click
3. User clicks Generate → loading skeleton (table-shape) → result loads with totals
4. User sorts / paginates → server-side fetch refreshes result (state preserved)
5. User clicks group toggle → row collapses / expands
6. User clicks Export → menu shows Excel / CSV / PDF / Print → handler runs → file downloads (or toast for placeholder)
7. User clicks row drill-down → opens source record in new tab OR navigates with back-button preserving filter state
8. User changes filters and clicks Generate → re-fetches; "filters dirty" indicator clears

---

### 🅱️ Block B — PIVOT_CHART (fill if sub-type = PIVOT_CHART)

#### Filter Panel

(Same structure as TABULAR — see Block A. Often fewer filters because pivot is narrower in scope.)

#### Pivot Layout (if pivot is primary)

```
              ┌──────────────┬──────────────┬──────────────┬──────────────┐
              │ Q1 2026      │ Q2 2026      │ Q3 2026      │ Total        │
┌─────────────┼──────────────┼──────────────┼──────────────┼──────────────┤
│ Annual Fund │   $ 240,000  │   $ 320,000  │   $ 410,000  │   $ 970,000  │
│ Year-End    │   $  80,000  │   $  90,000  │   $ 110,000  │   $ 280,000  │
│ Capital     │   $   5,000  │   $  20,000  │   $  60,000  │   $  85,000  │
│ ─────────── │ ──────────── │ ──────────── │ ──────────── │ ──────────── │
│ Total       │   $ 325,000  │   $ 430,000  │   $ 580,000  │ $ 1,335,000  │
└─────────────┴──────────────┴──────────────┴──────────────┴──────────────┘
   Drill: click any cell → opens TABULAR detail of donations in that row × column
```

| Axis | Source | Order | Display |
|------|--------|-------|---------|
| Rows | Campaign category | enum order | CampaignName |
| Columns | Time bucket | chronological | Quarter / Month / Year (user-selectable) |
| Cells | SUM(Amount) | currency | right-aligned, monospace |

**Multi-Aggregate** (if applicable): each cell shows {SUM, COUNT} stacked or as tooltip.

#### Charts (if charts are primary OR support the pivot)

> Pick chart type per data shape — see Visual Treatment Rules.

| # | Title | Type | X | Y | Source | Palette | Notes |
|---|-------|------|---|---|--------|---------|-------|
| 1 | Monthly Donation Trend | line | Month | SUM(Amount) | aggregated | brand-accent | Shows 12 months trailing |
| 2 | By Campaign Category | donut | — | category share | aggregated | semantic per category | Click slice → drill |
| 3 | Online vs Offline | grouped-bar | Month | SUM(Amount) split by Mode | aggregated | accent + neutral | Comparison across modes |
| ... | ... | ... | ... | ... | ... | ... | ... |

#### Drill-down

| Trigger | Target |
|---------|--------|
| Pivot cell click | TABULAR detail of underlying rows (`/donations?campaignId=…&dateFrom=…&dateTo=…`) |
| Donut slice click | TABULAR detail filtered by that segment |
| Line/area data point click | TABULAR detail for that month |

#### Toggle (table ↔ chart view)

If mockup offers both views: tab switch at the top, filter panel + Generate shared, result region swaps.

#### Export Actions

| Action | Format | Handler | Notes |
|--------|--------|---------|-------|
| Export Pivot Excel | .xlsx | ClosedXML pivot writer | Preserves row/column hierarchy |
| Export Charts PNG | .png per chart | client-side canvas-to-PNG | Always feasible |
| Export PDF (charts + pivot) | .pdf | PDF service | SERVICE_PLACEHOLDER if missing |

#### User Interaction Flow (PIVOT_CHART)

1. User adjusts filters + axis controls (Row=Campaign, Column=Quarter, Aggregate=SUM(Amount))
2. Clicks Generate → pivot loads with row + column totals
3. Clicks chart tab → same data rendered as line / donut / bar
4. Clicks pivot cell → drill-down navigates to TABULAR detail with cell's filter applied
5. Clicks Export → Excel / PDF / PNG → handler runs

---

### 🅲 Block C — DOCUMENT (fill if sub-type = DOCUMENT)

#### Recipient Picker / Filter Panel

| # | Filter / Picker | Widget | Default | Required | Notes |
|---|-----------------|--------|---------|----------|-------|
| 1 | Recipient | ApiSelect (search by name/code/email) — single OR multi | — | YES | The donor / member / case-recipient the document is generated for |
| 2 | Period / Period End | date / fiscal-year picker | current FY | YES | Document content scoped to this period |
| 3 | Template | dropdown | default tenant template | NO | If multiple document templates exist |
| 4 | Format | radio (PDF / Print / Email) | PDF | YES | Affects post-Generate action |
| ... | ... | ... | ... | ... | ... |

**Bulk Mode** (when applicable): "Generate for All Donors with Donations in {period}" → background job
returns zip URL; SERVICE_PLACEHOLDER if no async/storage service.

#### Document Layout (matches PDF / print exactly)

```
┌─────────────────────────────────────────────────────────┐  ← A4 page (210mm × 297mm)
│  [Tenant Logo]                       Tax Receipt #1234  │
│                                       Date: Apr 30, 2026│
│  {TenantAddress lines}                                  │
├─────────────────────────────────────────────────────────┤
│  To,                                                    │
│  {DonorName}                                            │
│  {DonorAddress}                                         │
│                                                         │
│  Subject: Acknowledgment of donation under Section 80G  │
│                                                         │
│  We acknowledge receipt of your donation of:            │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Date    | Amount  | Mode    | Receipt #         │   │
│  │ 15-Mar  | ₹50,000 | Online  | RC-2026-001234    │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  This donation is exempt under Section 80G of the …     │
│                                                         │
│  Sincerely,                                             │
│  {AuthorizedSignatory}                                  │
│  {Designation}                                          │
├─────────────────────────────────────────────────────────┤
│  Page 1 of 1                  Generated: 30-Apr-2026    │
└─────────────────────────────────────────────────────────┘
```

| Block | Position | Content |
|-------|----------|---------|
| Header | top, full-width | Tenant logo (left) + Receipt # (right) + Tenant address (below logo) |
| Recipient | top-body, left-aligned | "To," + DonorName + DonorAddress |
| Subject line | body, bold | Per template |
| Body | body | Salutation + acknowledgment paragraph + data table + closing paragraph |
| Data table | inline body | Per-record table (one row per donation in period) |
| Signature | bottom-body, right or left aligned | Signatory name + designation + (optional digital signature image) |
| Footer | bottom, full-width | Page number + generation date + tenant tagline |

**Per-Record Paging** (bulk mode): each recipient renders on its own A4 page; CSS `page-break-after: always` between recipients.

**Tenant Branding**: logo / colors / signatory image pulled from tenant settings (CONFIG screen).

#### Export Actions

| Action | Format | Handler | Notes |
|--------|--------|---------|-------|
| Download PDF | .pdf | PDF template engine OR print-CSS via headless-browser | SERVICE_PLACEHOLDER if no PDF service |
| Print | print-CSS | browser print | always feasible |
| Email to Recipient | email + PDF attachment | mail service | SERVICE_PLACEHOLDER if no mail service |
| Bulk Download (zip) | .zip of N PDFs | async job + storage | SERVICE_PLACEHOLDER unless infra exists |
| Re-issue (when source pattern is report-row-table) | regenerate + invalidate prior | command + audit | confirm dialog required |

#### User Interaction Flow (DOCUMENT)

1. User opens screen → recipient picker + period picker → Generate disabled until both set
2. User picks recipient + period → clicks Generate → document renders on screen (preview)
3. User reviews → clicks Download PDF → handler runs → file downloads (or toast for placeholder)
4. User clicks Email to Recipient → confirm dialog → handler runs → toast "Email sent" (or placeholder)
5. Bulk: user picks "All donors with donations in FY2026" → clicks Generate Bulk → background job → toast "Bulk generation in progress — link will be emailed when ready" (or placeholder)
6. Re-issue (when applicable): user clicks Re-issue from a prior document → confirm dialog → audit-log entry → new PDF replaces old

---

### Shared blocks (apply to all sub-types)

#### Page Header & Breadcrumbs

| Element | Content |
|---------|---------|
| Breadcrumb | {Module} › Reports › {Entity} Report |
| Page title | {Entity} Report |
| Subtitle | One-sentence description (e.g. "Donation transactions filtered by donor, campaign, and period") |
| Right actions | {Saved Views / Schedule / Help} |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Initial (pre-Generate) | Page first loads | Filter panel visible; result region shows "Set filters and click Generate" hint |
| Loading | After Generate | Skeleton matching the actual result shape (table outline / pivot grid / A4 page) — NOT generic shimmer |
| Empty | Generate returns zero rows | Diagnostic message referencing the active filters with a "Widen filters" CTA |
| Error | Query fails | Error card with retry + error code |
| Max-row exceeded | Result > render-limit | Banner: "Result exceeds {N} rows — narrow filters or use Excel export" + Export Excel button highlighted |

#### Print View CSS (`@media print`)

- Hide filter panel + page header actions + nav/sidebar
- Result region expands to full page width
- TABULAR: repeat header row on each page (`thead { display: table-header-group }`)
- DOCUMENT: page-break-after between recipients; page-break-inside-avoid on signatures
- PIVOT_CHART: charts render at 600×400 fixed-size; pivot has full-width

#### Schedule (optional — only if mockup shows)

> Scheduling typically requires a job runner / email service. Almost always SERVICE_PLACEHOLDER.

| Field | Notes |
|-------|-------|
| Frequency | Daily / Weekly / Monthly / Quarterly / Custom CRON |
| Recipients | List of email addresses (validated) |
| Format | PDF / Excel / CSV |
| Subject template | "{ReportName} — {GeneratedDate}" |

---

## ⑦ Substitution Guide

> **TBD** — first proper REPORT of each sub-type sets the canonical reference. Until then, copy
> from the closest existing screen and adapt:
>
> - TABULAR → no precedent. First builder sets convention.
> - PIVOT_CHART → no precedent. First builder sets convention.
> - DOCUMENT → no precedent. First builder sets convention.
>
> Maintainer: when the first REPORT of each sub-type completes, replace this block with a real
> substitution table mirroring `_MASTER_GRID.md` §⑦.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| {CanonicalName} | {EntityName} | Report class name |
| {canonicalCamel} | {entityCamelCase} | Variable / field names |
| {schema} | {schema} | DB schema |
| {Group} | {Group} | Backend group name |
| ... | ... | ... |

---

## ⑧ File Manifest

> Counts vary by sub-type. Pick the matching block; discard others.

### Backend Files — TABULAR

| # | File | Path |
|---|------|------|
| 1 | Report DTO + Filter DTO + Row DTO | Pss2.0_Backend/.../Base.Application/Schemas/{Group}Schemas/{EntityName}ReportSchemas.cs |
| 2 | Report Query | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/ReportQuery/Get{EntityName}Report.cs |
| 3 | Excel Export Handler | …/{PluralName}/ReportExport/Export{EntityName}ReportExcel.cs |
| 4 | PDF Export Handler (if real) | …/{PluralName}/ReportExport/Export{EntityName}ReportPdf.cs |
| 5 | (Optional) Saved View entity + CRUD | …/SavedReportView*.cs (only if Saved Views feature) |
| 6 | (Optional) Materialized View migration | Pss2.0_Backend/.../Base.Infrastructure/Migrations/{N}_Create_{Entity}ReportView.cs |
| 7 | Queries endpoint | Pss2.0_Backend/.../Base.API/EndPoints/{Group}/Queries/{EntityName}ReportQueries.cs |

### Backend Files — PIVOT_CHART

| # | File | Path |
|---|------|------|
| 1 | Pivot DTO (rows + columns + cells + totals) | …/{Group}Schemas/{EntityName}PivotSchemas.cs |
| 2 | Pivot Query | …/{PluralName}/PivotQuery/Get{EntityName}Pivot.cs |
| 3 | Drill-down Query | …/{PluralName}/PivotQuery/Get{EntityName}DetailsByPivotCell.cs |
| 4 | Excel Export (pivot writer) | …/{PluralName}/ReportExport/Export{EntityName}PivotExcel.cs |
| 5 | (Optional) Time-series Query (chart) | …/{PluralName}/ChartQuery/Get{EntityName}TimeSeries.cs |
| 6 | Queries endpoint | …/EndPoints/{Group}/Queries/{EntityName}PivotQueries.cs |

### Backend Files — DOCUMENT

| # | File | Path |
|---|------|------|
| 1 | Document DTO | …/{Group}Schemas/{EntityName}DocumentSchemas.cs |
| 2 | Get Document Query (single) | …/{PluralName}/DocumentQuery/Get{EntityName}Document.cs |
| 3 | Get Bulk Documents Query | …/{PluralName}/DocumentQuery/Get{EntityName}DocumentsBulk.cs |
| 4 | (Optional) Document Row Entity | …/{Group}Models/{EntityName}DocumentRecord.cs (when source pattern = report-row-table) |
| 5 | (Optional) EF Config | …/{Group}Configurations/{EntityName}DocumentRecordConfiguration.cs |
| 6 | Generate PDF Handler (or PLACEHOLDER) | …/{PluralName}/DocumentExport/Generate{EntityName}Pdf.cs |
| 7 | Bulk Generate Command (or PLACEHOLDER) | …/{PluralName}/DocumentExport/GenerateBulk{EntityName}.cs |
| 8 | (Optional) Reissue Command | …/{PluralName}/DocumentCommand/Reissue{EntityName}.cs |
| 9 | Email Send Handler (or PLACEHOLDER) | …/{PluralName}/DocumentExport/Email{EntityName}.cs |
| 10 | Mutations endpoint | …/EndPoints/{Group}/Mutations/{EntityName}DocumentMutations.cs |
| 11 | Queries endpoint | …/EndPoints/{Group}/Queries/{EntityName}DocumentQueries.cs |

### Backend Wiring Updates (only when source pattern requires storage)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | DbSet<{EntityName}DocumentRecord> (only for report-row-table) |
| 2 | {Group}DbContext.cs | DbSet entry |
| 3 | {Group}Mappings.cs | Mapster mapping config |

> For `query-only` source pattern: NO entity / DbSet / Mapping changes — the report only adds
> a query + endpoint registration.

### Frontend Files — TABULAR

| # | File | Path |
|---|------|------|
| 1 | DTO Types | Pss2.0_Frontend/src/domain/entities/{group}-service/{EntityName}ReportDto.ts |
| 2 | GQL Query | Pss2.0_Frontend/src/infrastructure/gql-queries/{group}-queries/{EntityName}ReportQuery.ts |
| 3 | Report Page | …/page-components/{group}/{feFolder}/{entity-lower}/report-page.tsx |
| 4 | Filter Panel | …/{entity-lower}/components/filter-panel.tsx |
| 5 | Result Table | …/{entity-lower}/components/result-table.tsx |
| 6 | Export Menu | …/{entity-lower}/components/export-menu.tsx |
| 7 | Print View CSS | …/{entity-lower}/components/print-styles.module.css |
| 8 | Page Config | Pss2.0_Frontend/src/presentation/pages/{group}/{feFolder}/{entity-lower}.tsx |
| 9 | Route Page | Pss2.0_Frontend/src/app/[lang]/(core)/{group}/{feFolder}/{entity-lower}/page.tsx |

### Frontend Files — PIVOT_CHART

| # | File | Path |
|---|------|------|
| 1-2 | DTO + GQL Query | (same pattern) |
| 3 | Report Page | …/{entity-lower}/report-page.tsx |
| 4 | Filter Panel | …/{entity-lower}/components/filter-panel.tsx |
| 5 | Pivot Table | …/{entity-lower}/components/pivot-table.tsx |
| 6 | Chart Components (per chart) | …/{entity-lower}/components/charts/{chart-name}.tsx |
| 7 | View Toggle (table ↔ chart) | …/{entity-lower}/components/view-toggle.tsx (only if toggle exists) |
| 8 | Export Menu | …/{entity-lower}/components/export-menu.tsx |
| 9 | Page Config + Route Page | (same pattern) |

### Frontend Files — DOCUMENT

| # | File | Path |
|---|------|------|
| 1-2 | DTO + GQL Query | (same pattern) |
| 3 | Report Page | …/{entity-lower}/report-page.tsx |
| 4 | Recipient + Period Picker | …/{entity-lower}/components/recipient-picker.tsx |
| 5 | Document Component | …/{entity-lower}/components/document.tsx |
| 6 | Print Styles | …/{entity-lower}/components/print-styles.module.css |
| 7 | Bulk Progress Indicator | …/{entity-lower}/components/bulk-progress.tsx (when bulk supported) |
| 8 | Page Config + Route Page | (same pattern) |

### Frontend Wiring Updates (all sub-types)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | {ENTITY_UPPER}_REPORT operations config |
| 2 | operations-config.ts | Import + register |
| 3 | sidebar menu config | Menu entry under {Reports parent} |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: {FULL | BE_ONLY | FE_ONLY}

MenuName: {Report Display Name}
MenuCode: {ENTITYUPPER}REPORT
ParentMenu: {PARENTMENUCODE — typically a REPORTS / ANALYTICS parent}
Module: {MODULECODE}
MenuUrl: {group/feFolder/entitylower}
GridType: REPORT

MenuCapabilities: READ, EXPORT, ISMENURENDER {+ PRINT / EMAIL / SCHEDULE as applicable}

RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT {+ PRINT / EMAIL / SCHEDULE as applicable}

GridFormSchema: SKIP
GridCode: {ENTITYUPPER}REPORT
---CONFIG-END---
```

> Capabilities by sub-type:
> - TABULAR / PIVOT_CHART: typically `READ, EXPORT` (no CREATE/MODIFY/DELETE).
> - DOCUMENT (when source pattern = report-row-table): add `CREATE` (generate document) + `REISSUE` (re-generate). EMAIL capability if emailing supported.
> - SCHEDULE capability only when scheduling feature is in mockup.
>
> `GridFormSchema: SKIP` for all REPORT sub-types — these are custom UIs, not RJSF modal forms.

---

## ⑩ Expected BE→FE Contract

### TABULAR

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| Get{EntityName}Report | {EntityName}ReportDto | {filters}, pageNo, pageSize, sortField, sortDir |
| Export{EntityName}ReportExcel | string (file URL or base64) | {filters}, sortField, sortDir |
| (Optional) GetSaved{EntityName}Views | [{ReportViewDto}] | — |

**Report DTO:**
| Field | Type | Notes |
|-------|------|-------|
| rows | [{Entity}ReportRowDto] | result rows |
| totalCount | int | for pagination |
| subtotals | [{groupKey, columnKey, value}] | when grouping |
| footerTotals | { columnKey: number } | column totals over filtered set |
| filterSummary | string | human-readable applied filters (for export header) |

### PIVOT_CHART

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| Get{EntityName}Pivot | {EntityName}PivotDto | {filters}, rowDimension, columnDimension, aggregate |
| Get{EntityName}DetailsByPivotCell | [{Entity}DetailRowDto] | {filters}, rowKey, columnKey |
| Get{EntityName}TimeSeries (if chart) | [{ts, value}] | {filters}, granularity (day/month/quarter) |

**Pivot DTO:**
```
{
  rowAxes: [{ key, label, order }],
  columnAxes: [{ key, label, order }],
  cells: [{ rowKey, columnKey, value, count? }],
  rowTotals: [{ rowKey, value }],
  columnTotals: [{ columnKey, value }],
  grandTotal: number
}
```

### DOCUMENT

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| Get{EntityName}Document | {EntityName}DocumentDto | recipientId, periodStart, periodEnd, templateId? |
| Get{EntityName}DocumentsBulk | [{EntityName}DocumentDto] OR jobId | {filters}, recipientType |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| Generate{EntityName}Pdf | DocumentRequestDto | string (file URL or base64) |
| GenerateBulk{EntityName} | BulkRequestDto | string (job id or zip URL) |
| Email{EntityName} | EmailRequestDto | bool |
| Reissue{EntityName} | recordId | int |

**Document DTO:**
| Field | Type | Notes |
|-------|------|-------|
| documentNo | string | display number (e.g. RC-2026-001234) |
| recipient | {…} | name + address + email + tax id |
| issuer | {…} | tenant + signatory |
| period | { start, end, label } | — |
| lineItems | [{date, amount, mode, receiptNo, …}] | per-record table content |
| computed | { totalAmount, taxAmount, sectionRef } | document-level totals |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/{group}/{feFolder}/{entitylower}`

**Functional Verification (Full E2E — MANDATORY) — pick the sub-type block:**

### TABULAR
- [ ] Filter panel renders all filters with defaults; required-filter affordance visible
- [ ] Generate button disabled until required filters valid
- [ ] Generate triggers fetch; loading skeleton matches table shape
- [ ] Result table renders all columns + correct widths + alignments
- [ ] Sort works (server or client per strategy)
- [ ] Pagination works (server-side fetch refreshes)
- [ ] Grouping renders group headers + subtotals (if grouping)
- [ ] Footer totals reflect filtered full set, not just current page
- [ ] Drill-down click navigates correctly + back-button preserves filter state
- [ ] Empty state diagnostic (references active filters)
- [ ] Max-row guard kicks in at threshold + offers Excel export
- [ ] Excel export produces formatted .xlsx (header bold, currency cells, totals styled)
- [ ] CSV export produces plain rows
- [ ] PDF export OR Print produces correct print-CSS layout
- [ ] Saved Views save / load / delete (if implemented)
- [ ] Role-scoped data: STAFFADMIN sees only own branch; FIELDAGENT sees only own records
- [ ] Sensitive fields masked / excluded per role

### PIVOT_CHART
- [ ] Filter panel + axis controls render
- [ ] Generate triggers fetch; loading skeleton matches matrix shape
- [ ] Pivot renders rows × columns with correct cell values
- [ ] Row + column totals correct; grand total correct
- [ ] Charts render with type matched to data shape (line/donut/bar/area as designed)
- [ ] Chart palette is semantic (not random rainbow); legend + tooltip + axis labels readable
- [ ] Drill-down: cell click navigates to detail with correct filter applied
- [ ] Toggle table ↔ chart works (if implemented)
- [ ] Export Excel preserves pivot hierarchy
- [ ] Empty state diagnostic
- [ ] Role-scoped data enforced

### DOCUMENT
- [ ] Recipient + period pickers render with defaults
- [ ] Generate disabled until both set
- [ ] Document renders matching A4 layout (header / body / footer / signature)
- [ ] Tenant logo + address + signatory pulled from tenant settings
- [ ] Per-record paging — `page-break-after: always` between recipients (bulk)
- [ ] Print preview matches on-screen render (no app chrome, no nav)
- [ ] PDF export produces identical layout (NOT a screenshot)
- [ ] Email send triggers handler (real or SERVICE_PLACEHOLDER toast)
- [ ] Bulk generate triggers job (real or SERVICE_PLACEHOLDER)
- [ ] Re-issue (when applicable): confirm dialog + audit-log entry written
- [ ] Role-scoped data: donor self-serve only sees own documents
- [ ] Sensitive fields (Tax ID, addresses) handled per role rules

**DB Seed Verification:**
- [ ] Menu appears in sidebar at `{ParentMenu}` (Reports / Analytics)
- [ ] Page renders without crashing on a freshly-seeded DB

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Universal REPORT warnings:**

- **Reports are read-only at the UI** — no in-place editing. CRUD on report-row-table is at most generate/reissue.
- **`screen_type: REPORT` is for parameterized OUTPUT** — if the screen is a transactional CRUD with submit/approve workflow that happens to be named "Report" (e.g. `grantreport` is FLOW), use `_FLOW.md` instead.
- **GridFormSchema = SKIP** for all REPORT sub-types — these are custom UIs.
- **Tenant scoping happens in BE** — every query applies CompanyId from HttpContext.
- **Role-scoped data filtering is in BE** — never trust the FE for permission enforcement; FE only reflects.
- **Footer totals are over the filtered set, NOT current page** — paginated tables must compute totals via separate aggregate query, not by summing visible rows.
- **Max-row guard mandatory for query-only large reports** — pick a render-limit (typically 30k) + offer Excel as the streaming alternative.
- **Sensitive data**: PII / financial fields gated per role. Excluded fields don't appear in DTOs returned to that role — not just hidden in UI.
- **Materialized views** (when source pattern is `materialized-view`): refresh strategy must be specified in §② — scheduled job + frequency + refresh trigger.
- **Drill-down** must preserve back-navigation state — use proper routing, not full page reloads.

**Sub-type-specific gotchas:**

| Sub-type | Easy mistakes |
|----------|---------------|
| TABULAR | Footer totals computed from current page only (wrong); group rows treated as data rows in export; Excel export that's CSV-with-xlsx; sort that re-fetches everything instead of just changing order |
| PIVOT_CHART | "Bar chart for everything" instead of picking type per data shape; rainbow palette; pivot without row/column totals; drill-down that doesn't preserve the cell's filter context; chart axes unreadable on small screens |
| DOCUMENT | PDF that's a screenshot of HTML (use print-CSS or template engine); page-break missing between bulk recipients; tenant branding hardcoded instead of pulled from tenant settings; emailing without unsubscribe / privacy footer; reissue without audit-log entry |

**Module / module-instance notes:**
- {e.g. "Parent menu `REPORTS` does not exist yet — register it in seed before this REPORT screen"}
- {e.g. "This report depends on a materialized view — migration must run before page works"}
- {e.g. "For ALIGN scope: only modify existing files, do not regenerate from scratch"}

**Service Dependencies** (UI-only — no backend service implementation):

> Everything shown in the mockup is in scope. List items here ONLY if they require an
> external service or infrastructure that doesn't exist in the codebase yet.

{Only list genuine external-service dependencies — leave empty if none.}
- {e.g. "⚠ SERVICE_PLACEHOLDER: PDF export — full UI implemented. Handler returns mocked URL because PDF generation service doesn't exist yet."}
- {e.g. "⚠ SERVICE_PLACEHOLDER: Email Document — same reason as above (no mail service)."}
- {e.g. "⚠ SERVICE_PLACEHOLDER: Schedule report — full schedule UI implemented; backend job runner doesn't exist yet."}
- {e.g. "⚠ SERVICE_PLACEHOLDER: Bulk Generate — async job + storage layer missing; UI shows queue indicator and 'placeholder' toast."}

Full UI must be built (filter panel, result render, export menu, drill-down, print CSS). Only the handler for the external service call is mocked.

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
| ① | Identity & Context | All agents | "Who runs it, how often, what decision it informs, what scale, what sensitivity?" |
| ② | Source Model | BA → BE Dev | "Source pattern (query-only / mat-view / snapshot / report-row), source entities, computed columns" |
| ③ | FK Resolution | BE Dev + FE Dev | "Where each filter source / drill-down target lives" |
| ④ | Business Rules | BA → BE Dev → FE Dev | "Required filters, validation, role-scoping, sensitive-data handling, max-row guard" |
| ⑤ | Classification | Solution Resolver | "Sub-type (TABULAR / PIVOT_CHART / DOCUMENT), pagination strategy, BE+FE patterns" |
| ⑥ | UI/UX Blueprint | UX Architect → FE Dev | "Per sub-type: filter panel + result view + export menu + visual-treatment rules" |
| ⑦ | Substitution Guide | BE Dev + FE Dev | "How to map canonical → this entity (TBD until first per sub-type lands)" |
| ⑧ | File Manifest | BE Dev + FE Dev | "Exact files per sub-type" |
| ⑨ | Approval Config | User | "Capabilities differ by sub-type; GridFormSchema always SKIP" |
| ⑩ | BE→FE Contract | FE Dev | "Per-sub-type queries + DTOs (incl. footerTotals, pivotDto shape, document layout)" |
| ⑪ | Acceptance Criteria | Verification | "Sub-type-specific E2E checks + role-scoping + sensitive-data + max-row guard" |
| ⑫ | Special Notes | All agents | "Reports are read-only; tenant + role scoping in BE; sub-type gotchas; SERVICE_PLACEHOLDERs" |

---

## Notes for `/plan-screens`

- Detect REPORT by: filter panel + Generate → result view + export — NOT a list-of-N CRUD with per-row Add/Edit/Delete.
- Distinguish from FLOW: FLOW has submit/accept lifecycle (e.g. `grantreport`); REPORT has parameterized output for analysis or distribution.
- Distinguish from DASHBOARD: DASHBOARD is a widget overview with many KPIs / charts / drill-downs; REPORT is one focused parameterized result.
- Distinguish from CONFIG: CONFIG configures the system; REPORT queries the system.
- Stamp `report_subtype` in frontmatter — TABULAR / PIVOT_CHART / DOCUMENT.
- Stamp `source_pattern` in §② — query-only / materialized-view / snapshot-table / report-row-table.
- Stamp `pagination_strategy` in §⑤ — client-paginate / server-paginate / streaming-export-only.
- Pre-fill §⑨ Approval Config based on sub-type capability matrix above.
- §⑥: include only the relevant sub-type block; delete the others before writing the screen prompt.
- §⑪ Acceptance: include only the matching sub-type block.

## Notes on canonical references

When the first TABULAR / PIVOT_CHART / DOCUMENT REPORT completes:

1. Replace §⑦ TBD block with a real substitution table modeled on `_MASTER_GRID.md` §⑦.
2. Update `_COMMON.md` § Substitution Guide table with the new canonical per sub-type.
3. Add a one-line note to this file's header listing the canonical reference.
