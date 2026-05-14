---
screen: HtmlReport
registry_id: 100
module: Report & Audit
status: COMPLETED
scope: FULL
screen_type: REPORT
report_subtype: DOCUMENT
source_pattern: query-only
pagination_strategy: client-paginate
complexity: Medium
new_module: NO
planned_date: 2026-05-13
completed_date: 2026-05-14
last_session_date: 2026-05-14
last_continue_session: Session 2 — FK rework (ReportType + ReportCategory → sett.MasterDatas)
---

> **⚠ READ THIS FIRST — Type re-classification (registry stamp is wrong)**
>
> 1. **Registry says Type=Config, Status=SKIP_CONFIG, Notes="Custom viewer".** That's stale.
>    The mockup is NOT a config screen. There is no settings record being edited, no palette/
>    canvas designer, no N×M matrix. The mockup shows a **REPORT viewer** with the classic
>    REPORT shape: filter panel → Generate → result render → export menu.
>
> 2. **Actual shape** = a **DOCUMENT-type REPORT** — categorized template sidebar (left) +
>    parameter form (top-collapsible) + toolbar (Print / PDF / Excel / Email / Share +
>    zoom + fullscreen) + A4-styled "paper" preview area (header / summary cards / data
>    tables / chart placeholders / page-break / footer with "Page X of Y") + email modal.
>    This is the printable companion to #154 Generate Report (TABULAR) — same `rep.Reports`
>    catalog, different render. The mockup's hero example is "Monthly Collection Summary"
>    rendered as a multi-page A4 document with sub-sections; 16 other report templates
>    appear in the sidebar (80G Certificate, Donor Acknowledgment, Annual Giving Statement,
>    Tax Receipt Summary, Staff Activity, Branch Collection, Ambassador Performance,
>    Receipt Book Audit, Purpose-wise Collection, FCRA Returns, Donor Disclosure,
>    Audit Trail, Annual Return Summary, Board Meeting Package, Quarterly Review Deck,
>    Year-End Summary, Campaign Impact Report).
>
> 3. **Best-fit template** = `_REPORT.md` / `DOCUMENT` sub-type (`source_pattern: query-only`).
>    Per-record fixed-layout printable output with page-breaks, header/body/footer, A4
>    width — textbook DOCUMENT fit. The "viewer with sidebar of templates" framing is the
>    DOCUMENT version of the same "filter → Generate → render" pattern that #154
>    Generate Report (TABULAR) and #98 Retention Dashboard (DASHBOARD) handle for their
>    sub-types.
>
> 4. **Effective scope = FULL but SMALL BE work**:
>    - **REUSE** existing `rep.Reports` (catalog), `rep.ReportExecutionLogs` (run history),
>      `rep.ReportRoles`, `Module`, `Branch`, `DonationPurpose`, `Campaign`, `Ambassador`,
>      `Language`.
>    - **REUSE** existing GQL queries: `GetReports`, `GetReportsByModule`, `GetReportById`,
>      `GenerateReports` (the engine that runs a report's `StoredProcedureName` with filter
>      args and returns row data — already exposed at `Base.API/EndPoints/Report/Queries/ReportQueries.cs:114`).
>    - **ADD** ONE new column to `rep.Reports`: `ReportCategory` (nullable string,
>      enum-like: `Financial | Operational | Compliance | Management`). Drives the
>      left-sidebar grouping in the mockup. Backed by an EF migration. Seed updates
>      apply category to the 17 report rows shown in the sidebar (and to any future
>      reports as they're registered).
>    - **ADD** ONE new composite query: `GetHtmlReportTemplates` — returns reports filtered
>      to `ReportType IN ('document','html')` (HTML-renderable templates) grouped by
>      `ReportCategory` plus per-user `RunCount` derived from `ReportExecutionLog` (sidebar
>      badges). No new mutations.
>    - **ADD** FE viewer page from scratch (the route exists as `UnderConstruction` stub at
>      `app/[lang]/reportaudit/reports/htmlreport/page.tsx`).
>    - **ADD** an extensible `template-registry` on the FE that maps `reportCode → React
>      component`. Ship ONE fully-implemented template (`MonthlyCollectionSummary`) as the
>      canonical reference; the other 16 sidebar items render a "Template not yet
>      implemented" placeholder card with the report metadata, until each is built in a
>      follow-up session. This is intentional — each document template is its own design
>      task and would balloon scope if all 17 were inlined here.
>
> 5. **Menu seeding is already done** — `_seed_child_menu('HTML Reports','HTMLREPORT','RA_REPORTS','REPORTAUDIT','reportaudit/reports/htmlreport','solar:code-bold',6)`
>    is at `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/Pss2.0_Global_Menus_List.sql:520`.
>    The DB Seed step adds menu capabilities (READ/EXPORT/PRINT/EMAIL/ISMENURENDER) and
>    BUSINESSADMIN role-capability rows + the `ReportCategory` seed updates on `rep.Reports`.
>
> 6. **Export PDF / Email / Share Link / Excel are SERVICE_PLACEHOLDER** — none of those
>    backend services are wired in this repo today:
>    - PDF: no PDF engine in `Base.Application.csproj` — handler returns a mocked URL +
>      `SERVICE_PLACEHOLDER` toast.
>    - Excel: ClosedXML / EPPlus not present — same treatment.
>    - Email: mail service exists in part (see `NotifyBusiness/`) but the document-attachment
>      flow doesn't — same treatment, full modal UI built.
>    - Share Link: needs signed-URL service that doesn't exist — same treatment.
>    - Print + Zoom + Fullscreen are real — `window.print()` with print-CSS, CSS transform
>      scale, and `requestFullscreen()` respectively.
>
> 7. **Canonical precedent**: This will be the **first DOCUMENT REPORT screen** in the
>    codebase. `_REPORT.md §⑦` lists DOCUMENT as TBD. After this build completes, update
>    `_REPORT.md` to point future DOCUMENT screens at `htmlreport.md` as canonical. The
>    template-registry pattern + paper-renderer + print-CSS module set the convention for
>    future documents (tax receipts, donor statements, certificates).

---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type identified: DOCUMENT — sidebar + parameter form + paper preview + email modal)
- [x] Source data identified (reuse `rep.Reports` + `GenerateReports` engine; add `ReportCategory` column)
- [x] Filter panel inventoried (Period type + Period + Year + Branch + Purpose + Grouping + 3 toggles + Language)
- [x] Result shape inventoried (A4 paper with header / summary cards / data tables / chart placeholder / page-break / footer with page numbers)
- [x] Scale estimated (typical 1-3 pages per document; max ~20 pages; client-paginate)
- [x] Pagination strategy chosen (`client-paginate` — per-document client-side page navigation)
- [x] Export formats confirmed (PDF / Excel / Print / Email / Share Link — first 4 SERVICE_PLACEHOLDER except Print)
- [x] Role-scoping rules captured (BUSINESSADMIN sees all; STAFFADMIN sees own branch data; FIELDAGENT excluded from financial documents)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (analyst/board persona; 17 templates; printable output for stakeholders; per-template scope decisions) — folded into orchestrator synthesis 2026-05-14; prompt already contained the analysis
- [x] Solution Resolution complete (DOCUMENT confirmed; query-only + GenerateReports reuse confirmed; ReportCategory column + GetHtmlReportTemplates query confirmed; SERVICE_PLACEHOLDER for PDF/Email/Excel/Share)
- [x] UX Design finalized (two-pane layout: sidebar [270px] + main; parameter card collapsible; A4 paper centered with shadow; email modal; template-registry pattern)
- [x] User Approval received (2026-05-14 — 4 issues resolved with recommended defaults: mock data for MonthlyCollectionSummary, per-user runCount, placeholder branding, BUSINESSADMIN-only seed)
- [x] Backend: ADD `ReportCategory` (string?) column to `rep.Reports`; EF Configuration update; migration
- [x] Backend: ADD `GetHtmlReportTemplates` query (composite DTO grouped by category, with run-count subquery — per-user only, `ReportExecutionLog` has no `CompanyId` column; runCount is implicitly per-user-per-tenant since UserId is tenant-scoped)
- [x] Backend: Endpoint registration in `Base.API/EndPoints/Report/Queries/ReportQueries.cs`
- [x] Backend: SERVICE_PLACEHOLDER mutations for `GenerateHtmlReportPdf`, `EmailHtmlReport`, `ExportHtmlReportExcel`, `CreateHtmlReportShareLink` (return mocked URLs + log call)
- [x] Frontend: New page-component tree at `page-components/reportaudit/reports/htmlreport/` (sidebar + parameter form + toolbar + paper renderer + template registry + 1 example template + email modal + print-CSS)
- [x] Frontend: Replace `UnderConstruction` stub at `app/[lang]/reportaudit/reports/htmlreport/page.tsx` with real page
- [x] Frontend: Page config at `presentation/pages/reportaudit/reports/htmlreport.tsx`
- [x] Frontend: GQL — INSTEAD of separate `GetReportByIdQuery.ts` + `GenerateReportsQuery.ts` (those already live consolidated in `ReportQuery.ts`), added NEW `HtmlReportTemplateQuery.ts` + 4 placeholder mutation files + barrel-export updates
- [x] DB Seed: `HtmlReport-sqlscripts.sql` adds Menu Capabilities (READ/EXPORT/PRINT/EMAIL/ISMENURENDER) + BUSINESSADMIN role-capability rows + INSERT statements on `rep.Reports` (not UPDATE — all 17 rows are new; idempotent with `WHERE NOT EXISTS` guards) + MonthlyCollectionSummary FilterSchema JSON + GridFormSchema=SKIP (no Grid form; one Grids row inserted as placeholder forward-compat)
- [x] Registry updated to COMPLETED + Notes column corrected (drop "SKIP_CONFIG / Custom viewer" tag)

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes; migration applies cleanly to a freshly-seeded DB
- [ ] `pnpm dev` — `/{lang}/reportaudit/reports/htmlreport` loads (no UnderConstruction stub)
- [ ] **Sidebar (categorized template list)**:
  - [ ] 4 group headers render: Financial Reports / Operational Reports / Compliance Reports / Management Reports
  - [ ] Each category icon matches mockup (`fa-file-invoice-dollar` / `fa-chart-bar` / `fa-shield-alt` / `fa-building`)
  - [ ] Reports listed under each category match `ReportCategory` value
  - [ ] Per-template `runCount` badge renders (e.g. "5", "8", "12") from `ReportExecutionLog` aggregate
  - [ ] Click template → main pane updates: title in parameter card header, parameter form re-renders from `report.FilterSchema`, paper area re-renders from template registry
  - [ ] Active template highlighted with `border-left + report-accent-bg` per mockup
  - [ ] Sidebar scroll works independently of main area
- [ ] **Parameter form (collapsible)**:
  - [ ] Header shows `Report: {selectedReportName}` + chevron icon
  - [ ] Click header → collapses/expands body; icon rotates
  - [ ] Form fields render dynamically from `report.FilterSchema` JSON (RJSF) — NOT hardcoded
  - [ ] Required-field affordance (red asterisk) per schema
  - [ ] Default values per schema
  - [ ] "Generate Report" + "Reset Parameters" buttons render
  - [ ] Generate triggers `GenerateReports` GQL query with filter args; loading skeleton inside paper area
  - [ ] Reset clears form back to defaults
- [ ] **Toolbar**:
  - [ ] Renders Print / Export PDF / Export Excel / Email Report / Share Link buttons on the left
  - [ ] Renders Zoom controls (`-` button, `{N}%` label, `+` button) + Fullscreen on the right
  - [ ] Print → `window.print()` with `@media print` CSS (hides app chrome, sidebar, toolbar — paper-only)
  - [ ] Export PDF → SERVICE_PLACEHOLDER toast "PDF export coming soon"
  - [ ] Export Excel → SERVICE_PLACEHOLDER toast "Excel export coming soon"
  - [ ] Email Report → opens email modal
  - [ ] Share Link → SERVICE_PLACEHOLDER toast "Share link coming soon"
  - [ ] Zoom +/- updates a scale factor (50% / 75% / 100% / 125% / 150% / 200%); CSS transform applies to `.report-paper`
  - [ ] Fullscreen → `requestFullscreen()` on the paper wrapper; ESC exits
- [ ] **Paper renderer (A4 page)**:
  - [ ] Centered max-width 850px white card with shadow per mockup
  - [ ] Padding 2.5rem; padding doesn't change on zoom
  - [ ] Header section: tenant logo + tenant org-name (uppercase) + report title (report-accent color) + period + "Generated: {timestamp}"
  - [ ] Section titles styled with bottom-border + uppercase tracking
  - [ ] Summary cards (4-up grid) when template has KPIs — value in report-accent color, label uppercase
  - [ ] Data tables with header/body/footer (right-align numerics, monospace amounts, bold footer-total row)
  - [ ] Chart placeholder block — uses real chart library (recharts/chart.js) where data is available, else "Bar chart by branch" dashed placeholder for templates not yet implemented
  - [ ] Page-break renders as dashed border with "Page Break" label (only visible on screen; clean break on print)
  - [ ] Footer: `Page {N} of {M}` left, tenant name + "Confidential" right
- [ ] **Template registry**:
  - [ ] `MonthlyCollectionSummary` template fully renders against `GenerateReports` payload (canonical example)
  - [ ] Other 16 templates render a "Template not yet implemented" notice card with reportName + reportCode + "Open ticket" link — NOT a crash
  - [ ] Registry is exported from `template-registry.tsx` as `Record<string, ReportTemplateComponent>` keyed by `reportCode`
- [ ] **Pagination (per-document)**:
  - [ ] When document is multi-page, "Page X of Y" indicator renders below the paper
  - [ ] Chevron buttons advance / retreat pages
  - [ ] CSS uses `page-break-after: always` between paper pages for print; on screen, separator is the visible dashed `page-break` rule
- [ ] **Email modal**:
  - [ ] Opens centered with overlay; ESC + Cancel + click-outside close it
  - [ ] Fields: To (comma-separated emails) + Subject (defaulted to `{reportName} — {period}`) + Message (textarea) + Format dropdown (PDF Attachment / Excel Attachment / Inline HTML)
  - [ ] Required-field validation (To is required, comma-separated email syntax)
  - [ ] Send Email button → SERVICE_PLACEHOLDER toast "Email send queued (placeholder)"
- [ ] **Print preview** (`window.print()`):
  - [ ] App chrome / sidebar / toolbar / parameter card / pagination controls all hidden
  - [ ] Paper area expands to full page width
  - [ ] `page-break-after: always` between pages
  - [ ] Page numbers update natively (browser print page numbering)
- [ ] **Role-scoping**:
  - [ ] BUSINESSADMIN sees all categories + all templates
  - [ ] STAFFADMIN sees only Operational + Management + own-branch Financial (subset)
  - [ ] FIELDAGENT sees Operational only (no Financial / Compliance access)
  - [ ] Sidebar templates filtered server-side per role
- [ ] **DB Seed**:
  - [ ] Menu visible at Report & Audit → Reports → HTML Reports
  - [ ] BUSINESSADMIN gets READ/EXPORT/PRINT/EMAIL on HTMLREPORT
  - [ ] `rep.Reports` rows have `ReportCategory` populated for the 17 sidebar templates
  - [ ] At least 1 report (`MonthlyCollectionSummary`) has a valid `FilterSchema` JSON that drives the parameter form

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: HTML Report Viewer
Module: Report & Audit (`REPORTAUDIT`)
Schema: `rep` (existing Reports schema — adding ONE new column `ReportCategory`)
Group: Report (existing `Base.Application/Business/ReportBusiness/Reports/`)

Business: The HTML Report Viewer is the **printable / boardroom-ready report rendering surface**
of PSS 2.0. It is the DOCUMENT-shaped sibling of #154 Generate Report (TABULAR). Where Generate
Report exposes the result of a stored procedure as a sortable data grid for analysts to slice
and filter, the HTML Report Viewer renders the **same data** through a per-template A4-styled
"paper" layout suited for printing, PDF export, board presentation, donor distribution, or
compliance filing. The audience is **BUSINESSADMIN** (Finance team running monthly close +
board reporting), **STAFFADMIN** (branch managers running operational summaries), and
indirectly the **board / donors / regulators** who consume the printed output. Frequency varies
by template: monthly collection summary is run monthly; tax receipt summaries / FCRA Returns
are annual; ad-hoc audit / board / quarterly templates are run as needed.

Data sensitivity is high — most reports include financial detail and donor PII. Tenant scoping
(`CompanyId` from logged-in user) is applied server-side in the existing `GenerateReports`
engine. Role-scoping filters which templates appear in the sidebar (FIELDAGENT does not see
Financial / Compliance categories).

Format expectations: per-template A4 paper layout with tenant logo + org name header, report
title + period, optional summary KPI strip, multiple titled sections containing tables /
totals / chart placeholders, page-break support, and footer with page numbers + tenant
tagline. Output formats: on-screen viewer (canonical), Print (always works), PDF (placeholder
until PDF service exists), Excel (placeholder), Email attachment (placeholder), Share Link
(placeholder).

Relationship to other screens:
- **#154 Generate Report** — same `rep.Reports` catalog, TABULAR sub-type. Both engines coexist;
  Generate Report dropdown lists the same reports for grid view. A future enhancement could
  add a "View as Document" / "View as Table" toggle on each report row.
- **#99 Report Catalog** — central launcher for all reports including HTML reports. A report
  rendered as HTML/document is launched from Report Catalog's Run modal with `output=html`,
  which navigates here with `?reportCode={code}`.
- **#101 Scheduled Reports** — out of scope (SKIP_CONFIG). When implemented, HTML reports
  will be scheduleable so the email handler scheduled-sends the rendered PDF.
- **Per-template detail screens** — each of the 17 templates is its own follow-up build
  ticket. This prompt scaffolds the viewer + ONE canonical template (`MonthlyCollectionSummary`)
  and leaves the others as "Template not yet implemented" placeholders.

> **Why this section is heavier**: REPORT design is shaped by the audience and decision more
> than by the source data. The HTML Report Viewer is intentionally a different surface from
> Generate Report despite sharing the engine — different recipients (board / donors / regulators)
> need a different format than analysts. Document layout is dictated by the *recipient*,
> not the source.

---

## ② Source Model

> **Consumer**: BA Agent → Backend Developer
> Reports rarely own a table — they query existing entities. State the source pattern.

**Source Pattern**: `query-only`

The screen does not own a new storage table. It consumes:
- The existing `rep.Reports` catalog (one row per registered report — `ReportCode`, `ReportName`,
  `ModuleId`, `StoredProcedureName`, `FilterSchema`, `ReportType`, `IsSystem`, `CompanyId`) —
  augmented by **ONE new column** `ReportCategory` (nullable string) added in this build.
- The existing `rep.ReportExecutionLogs` table for per-user run-count aggregation
  (sidebar badges).
- Per-report execution flows through `GenerateReports(reportCode, filterArgs)` which routes to
  `Report.StoredProcedureName` and returns row data + column metadata.

**Stamp**: `query-only` (no new storage table; one new column on existing catalog table)

### Source Entities (consumed by the engine)

| Source Entity | Entity File Path | Fields Consumed | Purpose |
|---------------|------------------|-----------------|---------|
| `Report` | `Base.Domain/Models/ReportModels/Report.cs` | `ReportId`, `ReportName`, `ReportCode`, `Description`, `ReportType`, `ModuleId`, `StoredProcedureName`, `FilterSchema`, `IsSystem`, `CompanyId`, **+ NEW `ReportCategory`** | Sidebar + parameter form schema + execution routing |
| `Module` | `Base.Domain/Models/AuthModels/Module.cs` | `ModuleId`, `ModuleCode`, `ModuleName` | FK target on `Report.ModuleId`; filter dimension |
| `ReportExecutionLog` | `Base.Domain/Models/ReportModels/ReportExecutionLog.cs` | `ReportId`, `UserId`, `CompanyId`, `ExecutedAt`, `RowCount` | Per-user run-count for sidebar badges |
| Per-report stored procedure | DB (Postgres) | named in `Report.StoredProcedureName` | Returns rows + column metadata + (optionally) summary/aggregate sections |

### Storage Table — Column Addition (only this build, no new table)

Modify existing `rep.Reports` table to add ONE column:

| Field | C# Type | MaxLen | Notes |
|-------|---------|--------|-------|
| ReportCategory | string? | 50 | Nullable. Enum-like values: `Financial`, `Operational`, `Compliance`, `Management`, or NULL (uncategorized — won't appear in HTML Report Viewer sidebar). Drives the 4 sidebar group headers. |

Migration:
```
ALTER TABLE rep."Reports" ADD COLUMN "ReportCategory" varchar(50) NULL;
COMMENT ON COLUMN rep."Reports"."ReportCategory" IS 'Drives HTML Report Viewer left-sidebar grouping. Values: Financial, Operational, Compliance, Management, or NULL.';
```

Seed update — set Category for the 17 sidebar templates (run AFTER `_seed_report` for each report code exists):
```
UPDATE rep."Reports" SET "ReportCategory" = 'Financial' WHERE "ReportCode" IN
  ('CERTIFICATE80G','DONATIONACKNOWLEDGMENT','ANNUALGIVINGSTATEMENT','TAXRECEIPTSUMMARY','MONTHLYCOLLECTIONSUMMARY');
UPDATE rep."Reports" SET "ReportCategory" = 'Operational' WHERE "ReportCode" IN
  ('STAFFACTIVITY','BRANCHCOLLECTION','AMBASSADORPERFORMANCE','RECEIPTBOOKAUDIT','PURPOSEWISECOLLECTION');
UPDATE rep."Reports" SET "ReportCategory" = 'Compliance' WHERE "ReportCode" IN
  ('FCRARETURNS','DONORDISCLOSURE','AUDITTRAIL','ANNUALRETURNSUMMARY');
UPDATE rep."Reports" SET "ReportCategory" = 'Management' WHERE "ReportCode" IN
  ('BOARDMEETINGPACKAGE','QUARTERLYREVIEWDECK','YEARENDSUMMARY','CAMPAIGNIMPACT');
```

> If some of these `ReportCode` rows don't exist in `rep.Reports` yet, the seed should INSERT
> stub rows (StoredProcedureName=NULL, FilterSchema=NULL) so the sidebar is populated. The
> renderer will mark these as "Template not yet implemented" placeholders.

### Computed / Derived Columns

| Column | Formula | Source | Notes |
|--------|---------|--------|-------|
| `runCount` (per template, sidebar badge) | `COUNT(*) FROM rep.ReportExecutionLogs WHERE ReportId = r.ReportId AND UserId = currentUser AND CompanyId = currentCompany` | aggregated subquery | per-user, per-tenant; computed in `GetHtmlReportTemplates` |
| `lastRunAt` (optional, not in mockup but available) | `MAX(ExecutedAt) FROM rep.ReportExecutionLogs WHERE ReportId = r.ReportId AND UserId = currentUser` | subquery | for "Sort by recent" if added later |
| `hasFilterSchema` | `Report.FilterSchema IS NOT NULL` | bool | drives parameter form render |
| `isImplemented` | client-side: `templateRegistry.has(reportCode)` | client | drives "Template not yet implemented" placeholder |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and joins) + Frontend Developer (for ApiSelect filter dropdowns).
>
> Note: most of these are sourced indirectly through the per-report `FilterSchema` JSON
> (RJSF), not hardcoded on the screen. The schema declares e.g. `branch: { $ref: 'ApiSelect',
> source: 'GetBranches' }` and the parameter form renders the dropdown. The list below is the
> set of FK sources that the mockup's example template's filter form needs.

| FK / Filter Source | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type | Used For |
|--------------------|--------------|-------------------|----------------|---------------|-------------------|----------|
| ReportId (sidebar) | Report | `Base.Domain/Models/ReportModels/Report.cs` | `GetHtmlReportTemplates` (NEW) — composite | `ReportName` | `HtmlReportTemplateGroupDto` | Left sidebar template list (grouped by category, with run count) |
| ReportId (header) | Report | (same) | `GetReportById` (existing) | `ReportName` + `FilterSchema` | `ReportResponseDto` | Selected report metadata + filter schema for parameter form |
| Generate execution | (varies per report) | (varies) | `GenerateReports` (existing) | — | `BaseApiResponse<ReportResult>` | Executes the report's stored procedure with filter args; returns row data + column metadata |
| ModuleId (data scope) | Module | `Base.Domain/Models/AuthModels/Module.cs` | `GetModules` | `ModuleName` | `ModuleResponseDto` | (Internal — not exposed in mockup filter form, but used to scope reports per module) |
| BranchId (filter) | Branch | `Base.Domain/Models/ApplicationModels/Branch.cs` | `GetBranches` | `BranchName` | `BranchResponseDto` | Branch dropdown in the parameter form (per-report FilterSchema) |
| DonationPurposeId (filter) | DonationPurpose | `Base.Domain/Models/DonationModels/DonationPurpose.cs` | `GetDonationPurposes` | `DonationPurposeName` | `DonationPurposeResponseDto` | Purpose Filter dropdown |
| CampaignId (filter, optional) | Campaign | `Base.Domain/Models/ApplicationModels/Campaign.cs` | `GetCampaigns` | `CampaignName` | `CampaignListDto` | Some templates (Campaign Impact, Year-End) need this |
| AmbassadorId (filter, optional) | Ambassador | `Base.Domain/Models/FieldCollectionModels/Ambassador.cs` | `GetAmbassadors` | `AmbassadorCode` (or `AmbassadorName`) | `AmbassadorResponseDto` | Ambassador Performance template |
| LanguageCode (output language) | Language | `Base.Domain/Models/SharedModels/Language.cs` | `GetLanguages` | `LanguageName` | `LanguageResponseDto` | Output Language dropdown (English / Hindi / Arabic / Bengali per mockup) |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (filter validation)

**Required Filters** (declarative per-report via `Report.FilterSchema`):
- Each report's `FilterSchema` JSON declares its own required fields. The screen-level shell
  has only ONE implicit required: "a report must be selected from the sidebar before Generate
  can fire."
- For the canonical `MonthlyCollectionSummary` template: Period type (Month/Quarter/Year/Custom)
  + Period values are required; Branch / Purpose / Grouping default to "All / By Branch"; toggles
  default per mockup (Include Sub-branches ON, Include Charts ON, Letterhead ON).

**Filter Validation**:
- Required-field validation comes from the RJSF schema (auto-rendered).
- Custom-range period must satisfy `endDate >= startDate` and span ≤ 24 months.
- Email modal: To field accepts comma-separated emails, each must match RFC-5322 simple
  pattern; max 50 recipients per send.

**Computed-Column Rules** (per-template, defined in the stored procedure):
- Summary KPIs reflect the *filtered* data set (not pre-filter aggregates).
- Branch totals + Purpose totals + Grand total must reconcile (footer total = sum of group totals).
- Empty groups (zero rows for a branch) are excluded from the table.

**Role-Based Data Scoping** (row-level security — enforced in `GenerateReports` + sidebar query):

| Role | Sees in Sidebar | Excluded |
|------|-----------------|----------|
| BUSINESSADMIN | All 4 categories, all 17 templates | none |
| STAFFADMIN | Operational + Management + own-branch Financial | Compliance, other-branch Financial |
| STAFFENTRY | Operational only | Financial, Compliance, Management |
| FIELDAGENT | (no access — `READ` capability not granted) | all |

> **Implementation note**: scoping happens server-side in `GetHtmlReportTemplates` — the
> query joins `rep.ReportRoles` and filters by current user's role + report-category
> permissions. The FE never trusts client-provided role for data filtering.

**Sensitive Data Handling**:

| Field | Sensitivity | Display Treatment | Export Treatment |
|-------|-------------|-------------------|------------------|
| Donor PAN / Tax ID (80G template) | PII | Masked (`••••XXXX`) on screen for non-FINANCE roles | Omitted entirely from non-admin exports |
| Donor full address | PII | Visible to admin + donor (own); hidden from STAFFENTRY | Excluded from STAFFENTRY exports |
| Bank account numbers (Reconciliation reports) | Secret | Never displayed | Never exported |
| Donation amount | Financial | Visible to admin; hidden from FIELDAGENT (moot since FIELDAGENT lacks READ) | — |

**Max-Row Guard** (per template):
- On-screen render limit: 1,000 rows per template. If a template's stored procedure returns
  >1k rows, the renderer shows the first 1k + a notice "Showing first 1,000 rows — please
  narrow filters or use Export Excel for the full result."
- Excel/CSV export limit: 50,000 rows (when Excel export becomes real).
- PDF export limit: 100 pages.

**Workflow**: None. The screen is purely read-only (no submit / approve / generate-record
lifecycle). Each execution writes a `ReportExecutionLog` row for audit; the rendered output
is not persisted (regenerated on each request — `query-only` source pattern).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: REPORT
**Report Sub-type**: `DOCUMENT`
**Source Pattern**: `query-only`
**Pagination Strategy**: `client-paginate`

| Strategy | When to pick | Why this fits |
|----------|--------------|---------------|
| `client-paginate` | Result fits in memory (≤1k rows), single GQL fetch | Document reports are intentionally narrow (one month, one branch, one campaign) — typical row count is 50-500. Multi-page on screen comes from layout (page-break CSS), not from server-side pagination. |

**Reason**: Document-style reports are tuned for narrow, recipient-bound result sets (one donor
statement = one donor's data; one monthly summary = one tenant's month). Server pagination
adds complexity for no benefit at this scale. The page-break inside the rendered document is
a CSS concern, not a fetch concern.

**Backend Patterns Required** (for DOCUMENT sub-type):

- [x] `GetHtmlReportTemplates` query — returns categorized list of HTML-renderable reports with per-user run count + filter-schema presence flag. (NEW)
- [x] `GetReportById` query — fetches the selected report's metadata (incl. FilterSchema JSON). (REUSE — existing)
- [x] `GenerateReports` query — executes the report's stored procedure with filter args; returns row data + column metadata. (REUSE — existing at `ReportQueries.cs:114`)
- [x] Tenant scoping (CompanyId from HttpContext) — already enforced in existing handlers
- [x] Role-based filtering — applied in `GetHtmlReportTemplates` against `rep.ReportRoles`
- [ ] PDF generation handler — SERVICE_PLACEHOLDER (no PDF service in repo)
- [ ] Excel export handler — SERVICE_PLACEHOLDER (no ClosedXML / EPPlus in repo)
- [ ] Email send handler — SERVICE_PLACEHOLDER (mail service exists for some flows but no document-attachment path)
- [ ] Share link generation — SERVICE_PLACEHOLDER (no signed-URL service)
- [x] `ReportExecutionLog` write — existing handler already writes a row on each `GenerateReports` call

**Frontend Patterns Required**:

- [x] Two-pane shell — left sidebar (270px) + main pane (filter card + toolbar + paper + pagination + email modal)
- [x] Template sidebar — grouped by category with collapsible/permanent sections (mockup shows permanent — no collapse)
- [x] Parameter form — collapsible card; renders from `report.FilterSchema` via RJSF (reuse existing RJSF setup from #154 Generate Report)
- [x] Toolbar — Print / Export PDF / Export Excel / Email / Share + zoom + fullscreen
- [x] Paper renderer — A4-styled white card centered with shadow; per-template content via template registry
- [x] Template registry — `Record<reportCode, ReactComponent>`; ONE fully-implemented (MonthlyCollectionSummary) + 16 placeholder fallback
- [x] Per-document pagination — `Page X of Y` indicator + chevron buttons; works against `page-break-after` CSS
- [x] Print-CSS module — hides chrome, exposes paper, page-break-after between paper pages
- [x] Zoom controls — CSS transform `scale(N)` on the paper wrapper; 50% / 75% / 100% / 125% / 150% / 200%
- [x] Fullscreen mode — `element.requestFullscreen()` on the paper wrapper
- [x] Email modal — overlay + 4 fields (To/Subject/Message/Format) + Cancel/Send
- [x] Empty state — initial state ("Select a report from the sidebar to begin"); zero-rows state per template ("No data matches the selected filters")
- [x] Loading state — skeleton matching the A4 paper outline (NOT generic shimmer)
- [x] Error state — error card inside the paper with retry button

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: This section is the design spec. DOCUMENT sub-type — see Block C below.

### 🎨 Visual Treatment Rules

1. **Two-pane layout, never stack on desktop** — left sidebar (270px) stays anchored; main
   area flexes. At ≤992px, sidebar shrinks to 220px; at ≤768px, sidebar collapses above
   the main area (vertical stack).
2. **Sidebar treatment** — purple-accent (`#7c3aed`, `--report-accent`) for active/hover.
   Each category gets a Font Awesome icon (`fa-file-invoice-dollar`, `fa-chart-bar`,
   `fa-shield-alt`, `fa-building`). Run-count badge is small + uppercase weight; flips to
   purple background when the row is active.
3. **Parameter card** — collapsible with chevron icon. Header is a colored band; body
   has a 3-column form grid (`.form-row` with `.form-group { flex: 1; min-width: 180px }`).
   Three toggle-row controls (Include Sub-branches / Include Charts / Letterhead) sit in
   a single row. Action buttons (`btn-generate` purple + `btn-reset` ghost) below toggles.
4. **Paper area** — light gray wrapper (`#e2e8f0`) frames the white paper card; the paper
   itself is centered, max-width 850px, padding 2.5rem, with `box-shadow: 0 4px 20px`.
   Background body is `#f1f5f9` so the paper sits inside a frame inside the layout.
5. **Paper content** — every section title uses uppercase + bottom-border + 1.5rem top margin.
   Summary cards are a 4-column grid; each value is purple (`--report-accent`), large + bold,
   label is uppercase small-caps. Tables have header `#f8fafc` background, footer also
   `#f8fafc` with bold totals.
6. **Print CSS** — `@media print { sidebar, .page-top-header, .param-card, .report-toolbar,
   .report-pagination { display: none } .report-paper { box-shadow: none; max-width: 100%;
   padding: 0 } }`. Each in-paper `.page-break` becomes a `page-break-after: always`.
7. **Loading skeleton** — faded paper outline (matches `.report-paper` shape) with shimmer
   bars for header / summary cards / table rows. NOT a generic rectangle.
8. **Empty state inside paper** — "Set parameters and click Generate to render this report"
   (initial). After Generate with zero rows: "No data matches Period={X}, Branch={Y} —
   try widening the date range or selecting a different branch."

**Anti-patterns to refuse**:
- A single generic "table component" for all 17 templates — each template has its own layout
- PDF that's an HTML screenshot — use print-CSS or a real PDF template engine when one exists
- Sidebar treated as a navigation menu — it's a tab/template picker; clicking it switches
  the right pane, NOT navigates to a new route
- Hard-coding the 4 categories in the FE — they MUST come from the BE query response so
  adding a new category later (e.g. "Tax") doesn't require a FE change
- Zoom that re-fetches data — zoom is a pure CSS transform

---

### 🅲 Block C — DOCUMENT (sub-type stamp)

#### Layout (two-pane)

```
┌──────────────────────────────────────────────────────────────────────────┐
│  HTML Reports                                                            │ ← .page-top-header
│  Generate and view formatted printable reports                           │   (white, border-bottom)
├────────────────────┬─────────────────────────────────────────────────────┤
│ FINANCIAL REPORTS  │  ┌─────────────────────────────────────────────┐   │
│  80G Cert    [5]   │  │ ▼ Report: Monthly Collection Summary       │   │ ← param-card (collapsible)
│  Acknowledgmt[8]   │  │ ┌─Period ─┬─Month─┬─Year─┐                │   │
│  Annual Stmt [2]   │  │ │ Month ▼ │April ▼│2026▼ │                │   │
│  Tax Receipt [3]   │  │ ├─Branch──┬Purpose┬Group┤                │   │
│  Monthly Sum [12]● │  │ │ All ▼  │ All ▼ │By Br▼│                │   │
│                    │  │ ├─[●]SubBr─[●]Charts─[●]LH─┤             │   │
│ OPERATIONAL …      │  │ ├─Language: English ▼─┤                  │   │
│  Staff Activ [4]   │  │ │ [Generate Report] [Reset]              │   │
│  Branch Coll [7]   │  │ └────────────────────────────────────────┘   │
│  Ambassador  [3]   │                                                    │
│  Receipt Bk  [6]   │  ┌─────────────────────────────────────────────┐   │
│  Purpose-wise[9]   │  │ [Print][PDF][Excel][Email][Share]  Zoom +/- │   │ ← report-toolbar
│                    │  └─────────────────────────────────────────────┘   │
│ COMPLIANCE …       │                                                    │
│  FCRA Returns[1]   │  ┌────────────────────────────────────────────┐    │
│  Donor Disc  [2]   │  │            ┌──────────────────────────┐    │    │
│  Audit Trail [4]   │  │            │ [LOGO] GLOBAL HUMANIT… │    │    │ ← report-paper
│  Annual Ret  [1]   │  │            │  Monthly Coll. Summary  │    │    │   (centered, A4)
│                    │  │            │  Period: April 2026     │    │    │
│ MANAGEMENT …       │  │            ├──────────────────────────┤    │    │
│  Board Meet  [1]   │  │            │  SUMMARY                 │    │    │
│  Quarterly   [1]   │  │            │  ┌──┬──┬──┬──┐           │    │    │
│  Year-End    [0]   │  │            │  │$$│#$│Br│Am│           │    │    │
│  Campaign    [2]   │  │            │  └──┴──┴──┴──┘           │    │    │
│                    │  │            │  COLLECTIONS BY BRANCH   │    │    │
│                    │  │            │  ┌────┬────┬────┬────┐   │    │    │
│                    │  │            │  │ … │ … │ … │ … │    │    │    │
│                    │  │            │  └────┴────┴────┴────┘   │    │    │
│                    │  │            │  [bar chart placeholder] │    │    │
│                    │  │            │  ----- Page Break -----  │    │    │
│                    │  │            │  COLLECTIONS BY PURPOSE  │    │    │
│                    │  │            │  …                       │    │    │
│                    │  │            │  Page 1 of 3   GHF · Conf│    │    │
│                    │  │            └──────────────────────────┘    │    │
│                    │  └────────────────────────────────────────────┘    │
│                    │             ◀  Page 1 of 3  ▶                       │ ← report-pagination
└────────────────────┴─────────────────────────────────────────────────────┘
                 (Email Modal — overlay when triggered from toolbar)
```

#### Left Sidebar — Template List

| Property | Value |
|----------|-------|
| Width | 270px (desktop), 220px (≤992px), full-width above main (≤768px) |
| Background | white; right-border `--border-color` |
| Scroll | independent of main area |
| Sections | one per `ReportCategory` value returned by `GetHtmlReportTemplates` |
| Section header | uppercase 0.6875rem, font-weight 700, letter-spacing 0.05em; FA icon left of text |
| Section icons | Financial → `fa-file-invoice-dollar`, Operational → `fa-chart-bar`, Compliance → `fa-shield-alt`, Management → `fa-building` (icons hardcoded on FE; categories from BE) |
| Item label | `report.reportName` |
| Item run-count badge | `report.runCount`; small pill (0.625rem); gray bg when inactive, purple bg + white text when active |
| Active state | `border-left: 3px solid var(--report-accent)` + bg `--report-accent-bg` + font-weight 600 + color `--report-accent` |
| Hover state | bg `#f8fafc`, color `--report-accent` |
| Click behavior | Calls `selectTemplate(reportCode)`; main pane updates parameter form (fetches report metadata via `GetReportById`) and re-renders paper area via `templateRegistry[reportCode]` (or placeholder) |

#### Parameter Form (Collapsible Card)

| Property | Value |
|----------|-------|
| Card | `param-card` (white bg, rounded, shadow) |
| Header | Title `Report: {selectedReportName}` + chevron icon (rotates 180° on collapse) |
| Header icon | `fa-sliders-h` purple, left of title |
| Body | RJSF-rendered form from `report.FilterSchema` — NOT hardcoded |
| Required marker | red asterisk per RJSF rules |
| Default values | per `FilterSchema.uiSchema.defaultValues` |
| Action buttons | `[Generate Report]` purple primary + `[Reset Parameters]` ghost |
| Generate behavior | Validates required fields → calls `GenerateReports({reportCode, filters})` → updates paper area; on error shows toast + keeps form |
| Reset behavior | Resets form to schema defaults; does NOT clear paper area (last-rendered output persists) |
| Loading state | Generate button shows spinner + disabled; paper area shows skeleton |

For the canonical `MonthlyCollectionSummary` template's filter form (per mockup):

| # | Field | Widget | Default | Required | Notes |
|---|-------|--------|---------|----------|-------|
| 1 | Report Period type | select (Month/Quarter/Year/Custom Range) | Month | YES | toggle field |
| 2 | Period value (Month) | select (Jan-Dec) | April | YES if type=Month | dynamic per type |
| 3 | Period value (Year) | select (current year + 4 prior) | 2026 | YES | always present |
| 4 | Custom From | date | — | YES if type=Custom | hidden unless type=Custom |
| 5 | Custom To | date | — | YES if type=Custom | hidden unless type=Custom |
| 6 | Branch | ApiSelect → `GetBranches` | All Branches | NO | multi-tenant-scoped |
| 7 | Purpose Filter | ApiSelect → `GetDonationPurposes` | All Purposes | NO | — |
| 8 | Grouping | select (By Branch / By Purpose / By Ambassador / By Payment Mode) | By Branch | YES | drives table grouping in paper |
| 9 | Include Sub-branches | toggle | ON | NO | applies to Branch filter |
| 10 | Include Charts | toggle | ON | NO | shows/hides chart sections in paper |
| 11 | Letterhead | toggle | ON | NO | shows/hides tenant logo block in paper |
| 12 | Language | select (English / Hindi / Arabic / Bengali) | English | YES | future i18n; for v1, English only — other options visible but disabled |

#### Toolbar

| Group | Item | Action | Status |
|-------|------|--------|--------|
| Left | Print | `window.print()` with print-CSS | FULL |
| Left | Export PDF | Call `GenerateHtmlReportPdf` mutation → toast | SERVICE_PLACEHOLDER |
| Left | Export Excel | Call `ExportHtmlReportExcel` mutation → toast | SERVICE_PLACEHOLDER |
| Left | Email Report | Open email modal | FULL UI |
| Left | Share Link | Call `CreateHtmlReportShareLink` mutation → toast | SERVICE_PLACEHOLDER |
| Right | Zoom − | Reduce paper scale (50/75/100/125/150/200 steps; floor=50%) | FULL |
| Right | Zoom label | Current scale label (e.g. `100%`) | FULL |
| Right | Zoom + | Increase paper scale (ceiling=200%) | FULL |
| Right | Fullscreen | `paperRef.current.requestFullscreen()` | FULL |

Implementation note: Zoom transforms apply `transform: scale(${factor})` on `.report-paper`
inside `.report-paper-wrapper` with `transform-origin: top center`. The wrapper's overflow
auto-scrolls to handle wider-than-viewport scaled output.

#### Paper Renderer (A4 Document)

| Block | Position | Source |
|-------|----------|--------|
| Logo block | top, full-width, centered | `tenant.logoUrl` from current company settings; falls back to FA `fa-hand-holding-heart` purple gradient |
| Org name | below logo, uppercase | `tenant.organizationName` |
| Report title | below org name, purple | `selectedReport.reportName` |
| Period | below title, gray | computed: `"Period: {periodLabel}"` |
| Generated stamp | below period, smaller gray | computed: `"Generated: {DateTime.Now}"` |
| Summary section | first content section, 4-column KPI grid | template-specific (e.g. MonthlyCollection → Total Collections / Total Transactions / Active Branches / Active Ambassadors) |
| Data tables | one or more per template, with header + body + tfoot | template-specific; each row maps from `generateReports.data` |
| Chart placeholder / real chart | optional per template | placeholder if `includeCharts=true` and no chart library configured for this template; real chart (recharts) when wired |
| Page break | between sections that should print on new pages | `.page-break` div renders dashed line on screen; CSS becomes `page-break-after: always` on print |
| Footer | bottom, full-width, two-up | `"Page {N} of {M}"` left, `"{tenant.organizationName} — Confidential"` right |

**Template Registry** (FE-side):

```typescript
// page-components/reportaudit/reports/htmlreport/components/template-registry.tsx
export type ReportTemplateProps = {
  metadata: ReportResponseDto;
  filters: Record<string, unknown>;
  data: ReportResult; // result of GenerateReports
};

export type ReportTemplateComponent = React.FC<ReportTemplateProps>;

export const templateRegistry: Record<string, ReportTemplateComponent> = {
  MONTHLYCOLLECTIONSUMMARY: MonthlyCollectionSummary,
  // 16 others = NOT_IMPLEMENTED for v1; PaperFallback renders the placeholder card
};

export function getTemplate(reportCode: string): ReportTemplateComponent {
  return templateRegistry[reportCode] ?? PaperFallback;
}
```

`PaperFallback` renders a centered card inside the paper:
> "**{ReportName}** template is not yet implemented.
> Report Code: `{ReportCode}` · Category: `{ReportCategory}`
> [Open ticket to request implementation]"

#### Pagination (Per-Document)

| Property | Value |
|----------|-------|
| Trigger | Renders only when current template emits >1 paper page |
| UI | Below the paper-wrapper: chevron-left + `Page X of Y` + chevron-right |
| Behavior | Scrolls the paper-wrapper to the corresponding `.paper-page` block (CSS `scroll-snap-align: start`) |
| Print | `page-break-after: always` between `.paper-page` blocks; native browser page numbering on print |

#### Email Modal

| Property | Value |
|----------|-------|
| Trigger | "Email Report" button in toolbar |
| Overlay | Black 40% opacity; click-outside closes |
| Box | 500px max-width; rounded `--card-radius`; shadow |
| Header | `fa-envelope` purple + "Email Report" + close button |
| Field 1 | To* — text input, comma-separated emails; default `tenant.defaultRecipients` if configured |
| Field 2 | Subject — text input; default `{reportName} - {periodLabel}` |
| Field 3 | Message — textarea (min 60px); default `"Please find attached the {reportName} report for {periodLabel}."` |
| Field 4 | Format — select (PDF Attachment / Excel Attachment / Inline HTML); default PDF |
| Footer | `[Cancel]` ghost + `[Send Email]` purple primary |
| Send action | Calls `EmailHtmlReport` mutation → toast "Email queued (placeholder)" → closes modal |
| Validation | To is required; each email must match RFC-5322 simple pattern; max 50 recipients |

#### User Interaction Flow (DOCUMENT)

1. User opens screen → sidebar renders categorized templates → main pane shows "Select a report from the sidebar to begin" empty state
2. User clicks sidebar item → main pane fetches `GetReportById(reportId)` → parameter form re-renders from FilterSchema → paper area shows "Set parameters and click Generate" empty state
3. User adjusts filters → clicks Generate Report → loading skeleton replaces empty state in paper → `GenerateReports({reportCode, filters})` fires → on success, paper renders the template's output (or PaperFallback for unimplemented templates)
4. User clicks Print → `window.print()` runs with print-CSS (sidebar, parameter card, toolbar, pagination hidden; paper only)
5. User clicks Export PDF / Excel / Share → SERVICE_PLACEHOLDER toast
6. User clicks Email Report → email modal opens → fills To/Subject/Message → clicks Send → modal closes + toast
7. User adjusts Zoom +/− → CSS transform applies; scrollbar appears on wrapper if scaled wider than viewport
8. User clicks Fullscreen → paper wrapper enters fullscreen; ESC exits
9. User clicks a different sidebar item → main pane state resets (filter form re-renders, paper shows new empty state) — last result is NOT retained
10. User clicks Reset Parameters → form resets to schema defaults; paper area unchanged

### Shared blocks (apply across REPORT sub-types)

#### Page Header & Breadcrumbs

| Element | Content |
|---------|---------|
| Breadcrumb | Report & Audit › Reports › HTML Reports |
| Page title | "HTML Reports" with `fa-file-alt` purple icon |
| Subtitle | "Generate and view formatted printable reports" |
| Right actions | (none in mockup — keep clean) |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Initial (no template selected) | Page first loads | Sidebar visible; main shows "Select a report from the sidebar to begin viewing or generating documents." |
| Template selected, pre-Generate | Sidebar click | Parameter form visible; paper area shows "Set parameters and click Generate Report to render this template." |
| Loading | After Generate click | Paper area shows skeleton matching A4 outline (logo strip + 4 summary boxes + 2 table outlines) |
| Empty (zero rows) | Generate returns no data | Paper shows partial header + "No data matches the selected filters. Try widening the date range or selecting a different branch." |
| Error | Query / network failure | Paper shows error card: "Failed to generate report. {errorCode}" + Retry button |
| Template not implemented | Sidebar click on a reportCode not in `templateRegistry` | PaperFallback card (see Template Registry block) |
| Max rows exceeded | `data.rows.length > 1000` | Paper renders first 1k rows + banner: "Showing first 1,000 rows. Use Export Excel for the full result." |

#### Print View CSS (`@media print`)

```css
@media print {
  body { background: white; overflow: visible; height: auto; }
  .page-top-header, .report-sidebar, .param-card, .report-toolbar, .report-pagination { display: none !important; }
  .report-main { padding: 0; overflow: visible; }
  .report-paper-wrapper { background: white; padding: 0; border: none; }
  .report-paper { box-shadow: none; max-width: 100%; padding: 1.5rem; border: none; }
  .page-break { page-break-after: always; border: none; height: 0; }
  .page-break::after { display: none; }
  thead { display: table-header-group; }
  tr, td, th { page-break-inside: avoid; }
}
```

#### Schedule (out of scope)

Scheduling is deferred to #101 Scheduled Reports (SKIP_CONFIG). When that screen lands, the HTML
Report Viewer toolbar can grow a "Schedule" button alongside Email.

---

## ⑦ Substitution Guide

> **TBD — first DOCUMENT REPORT** in the codebase. This build sets the canonical reference.
> Future DOCUMENT screens (tax receipts, donor statements, certificates) should copy from
> `htmlreport.md` and adapt the table below.

After this build completes, this section should be replaced with:

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| HtmlReport | {NewDocumentName} | Screen class name |
| htmlreport | {newdocumentname} | route / kebab |
| HTMLREPORT | {NEWDOCUMENT} | MenuCode / GridCode / capability constant |
| HtmlReportTemplate | {NewDocumentTemplate} | template-registry entry name |
| rep | {schema} | DB schema |
| Report | {NewDocumentEntity} | Backend group entity name |
| reportaudit/reports/htmlreport | {module/group/route} | FE route |

For this initial build, mirror these existing screens for the engine pieces:
- **`generatereport` (#154)** — for the report-engine integration (`GenerateReports` reuse, `useInitializeReportDataTableDatas` analog)
- **`reportcatalog` (#99)** — for the `GetReportCatalog` composite-query pattern (grouped responses)
- **No existing precedent for the DOCUMENT paper renderer + template registry** — those are new conventions this build establishes.

---

## ⑧ File Manifest

### Backend Files (NEW + MODIFIED)

| # | File | Path | New / Modified |
|---|------|------|----------------|
| 1 | Report entity | `Pss2.0_Backend/.../Base.Domain/Models/ReportModels/Report.cs` | MODIFIED (add `ReportCategory` property) |
| 2 | Report EF Configuration | `Pss2.0_Backend/.../Base.Infrastructure/Configurations/ReportConfiguration.cs` (or wherever existing config lives — confirm path) | MODIFIED (add column config for ReportCategory with maxLen 50) |
| 3 | Migration | `Pss2.0_Backend/.../Base.Infrastructure/Migrations/{timestamp}_Add_ReportCategory_To_Reports.cs` | NEW |
| 4 | Schemas / DTOs | `Pss2.0_Backend/.../Base.Application/Schemas/ReportSchemas/HtmlReportTemplateSchemas.cs` | NEW (`HtmlReportTemplateGroupDto` + `HtmlReportTemplateDto`) |
| 5 | Query: GetHtmlReportTemplates | `Pss2.0_Backend/.../Base.Application/Business/ReportBusiness/Reports/Queries/GetHtmlReportTemplatesQuery.cs` | NEW |
| 6 | Endpoint registration | `Pss2.0_Backend/.../Base.API/EndPoints/Report/Queries/ReportQueries.cs` | MODIFIED (add `GetHtmlReportTemplates` field) |
| 7 | Mutation: GenerateHtmlReportPdf (PLACEHOLDER) | `Pss2.0_Backend/.../Base.Application/Business/ReportBusiness/Reports/Mutations/GenerateHtmlReportPdfMutation.cs` | NEW (returns mocked URL) |
| 8 | Mutation: ExportHtmlReportExcel (PLACEHOLDER) | `Pss2.0_Backend/.../Base.Application/Business/ReportBusiness/Reports/Mutations/ExportHtmlReportExcelMutation.cs` | NEW (returns mocked URL) |
| 9 | Mutation: EmailHtmlReport (PLACEHOLDER) | `Pss2.0_Backend/.../Base.Application/Business/ReportBusiness/Reports/Mutations/EmailHtmlReportMutation.cs` | NEW (returns bool=true) |
| 10 | Mutation: CreateHtmlReportShareLink (PLACEHOLDER) | `Pss2.0_Backend/.../Base.Application/Business/ReportBusiness/Reports/Mutations/CreateHtmlReportShareLinkMutation.cs` | NEW (returns mocked URL) |
| 11 | Mutations endpoint registration | `Pss2.0_Backend/.../Base.API/EndPoints/Report/Mutations/ReportMutations.cs` (existing file — confirm path) | MODIFIED |
| 12 | Mapster mappings | `Pss2.0_Backend/.../Base.Application/Mappings/ReportMappings.cs` (existing — confirm path) | MODIFIED (HtmlReportTemplate DTO mappings) |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext.cs` | (no change — reuses existing DbSet<Report>) |
| 2 | `ReportDbContext.cs` | (no change — column added via migration not model) |
| 3 | `ReportMappings.cs` | Mapster config for `HtmlReportTemplateDto` |

### Frontend Files (NEW + MODIFIED)

| # | File | Path | New / Modified |
|---|------|------|----------------|
| 1 | DTO types | `Pss2.0_Frontend/src/domain/entities/report-service/HtmlReportTemplateDto.ts` | NEW |
| 2 | Reuse Report DTO | `Pss2.0_Frontend/src/domain/entities/report-service/ReportDto.ts` (existing) | (UNCHANGED — verify export of FilterSchema field) |
| 3 | GQL: GetHtmlReportTemplates | `Pss2.0_Frontend/src/infrastructure/gql-queries/report-queries/GetHtmlReportTemplatesQuery.ts` | NEW |
| 4 | GQL: GetReportById (reuse) | `Pss2.0_Frontend/src/infrastructure/gql-queries/report-queries/GetReportByIdQuery.ts` (existing) | (UNCHANGED) |
| 5 | GQL: GenerateReports (reuse) | `Pss2.0_Frontend/src/infrastructure/gql-queries/report-queries/GenerateReportsQuery.ts` (existing) | (UNCHANGED) |
| 6 | GQL: EmailHtmlReport (PLACEHOLDER) | `Pss2.0_Frontend/src/infrastructure/gql-queries/report-queries/EmailHtmlReportMutation.ts` | NEW |
| 7 | GQL: GenerateHtmlReportPdf (PLACEHOLDER) | `Pss2.0_Frontend/src/infrastructure/gql-queries/report-queries/GenerateHtmlReportPdfMutation.ts` | NEW |
| 8 | Report viewer page (main) | `Pss2.0_Frontend/src/presentation/components/page-components/reportaudit/reports/htmlreport/report-viewer-page.tsx` | NEW |
| 9 | Sidebar component | `…/htmlreport/components/report-sidebar.tsx` | NEW |
| 10 | Parameter form | `…/htmlreport/components/parameter-form.tsx` | NEW (RJSF + schema binding) |
| 11 | Toolbar | `…/htmlreport/components/report-toolbar.tsx` | NEW |
| 12 | Paper renderer | `…/htmlreport/components/paper-renderer.tsx` | NEW (wrapper + zoom + pagination integration) |
| 13 | Template registry | `…/htmlreport/components/template-registry.tsx` | NEW (typed registry + getTemplate fn) |
| 14 | Template: MonthlyCollectionSummary | `…/htmlreport/components/templates/monthly-collection-summary.tsx` | NEW (canonical example) |
| 15 | Template: PaperFallback | `…/htmlreport/components/templates/paper-fallback.tsx` | NEW (placeholder for unimplemented) |
| 16 | Email modal | `…/htmlreport/components/email-modal.tsx` | NEW |
| 17 | Print CSS | `…/htmlreport/components/print-styles.module.css` | NEW |
| 18 | Page config | `Pss2.0_Frontend/src/presentation/pages/reportaudit/reports/htmlreport.tsx` | NEW |
| 19 | Route page | `Pss2.0_Frontend/src/app/[lang]/reportaudit/reports/htmlreport/page.tsx` | MODIFIED (replace `<UnderConstruction />` with `<HtmlReportPageConfig />`) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | Page index | `Pss2.0_Frontend/src/presentation/pages/reportaudit/reports/index.ts` | Add `export { default as HtmlReportPageConfig } from './htmlreport';` |
| 2 | entity-operations.ts / operations-config.ts | (N/A per `#154 generatereport` build notes — these files don't exist in this codebase; capability gating uses `useAccessCapability({ menuCode: 'HTMLREPORT' })`) | — |
| 3 | sidebar menu | (already seeded via `_seed_child_menu` at `Pss2.0_Global_Menus_List.sql:520`) | — |

### DB Seed Files

| # | File | Path |
|---|------|------|
| 1 | HtmlReport seed | `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/HtmlReport-sqlscripts.sql` (preserve `dyanmic` typo per existing convention) |

Seed content:
- Menu capabilities for HTMLREPORT (READ / EXPORT / PRINT / EMAIL / ISMENURENDER)
- BUSINESSADMIN role-capability rows for the above
- 17 UPDATE statements on `rep.Reports` setting `ReportCategory` per `ReportCode`
- (If missing) INSERT placeholder rows for the 17 ReportCodes with NULL StoredProcedureName + NULL FilterSchema so the sidebar is populated even before each stored procedure is implemented
- ONE seed for `MonthlyCollectionSummary` with a real `FilterSchema` JSON matching the form fields above
- GridFormSchema = SKIP (no RJSF form schema for this menu — the screen is a custom viewer)

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: HTML Reports
MenuCode: HTMLREPORT
ParentMenu: RA_REPORTS
Module: REPORTAUDIT
MenuUrl: reportaudit/reports/htmlreport
GridType: REPORT

MenuCapabilities: READ, EXPORT, PRINT, EMAIL, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT, PRINT, EMAIL

GridFormSchema: SKIP
GridCode: HTMLREPORT
---CONFIG-END---
```

> Capabilities rationale (DOCUMENT sub-type):
> - `READ` — view reports in sidebar + render in paper
> - `EXPORT` — gates PDF / Excel buttons (SERVICE_PLACEHOLDER backends still need the capability check)
> - `PRINT` — gates Print button (always feasible since it's `window.print()`)
> - `EMAIL` — gates Email Report modal trigger
> - `ISMENURENDER` — gates menu visibility per current `auth.Modules` rules
>
> `GridFormSchema: SKIP` — the screen is a custom viewer, not a RJSF modal form.
>
> Role-scoping for sidebar (server-side filter, enforced in `GetHtmlReportTemplates`):
> - BUSINESSADMIN — all categories
> - STAFFADMIN — Operational + Management + own-branch Financial
> - STAFFENTRY — Operational only
> - FIELDAGENT — (no capability granted; menu hidden)
>
> Only BUSINESSADMIN is explicitly listed in `RoleCapabilities` per memory `[[feedback_prefer_sonnet_over_opus]]` guidance to keep config blocks minimal. Other role rows can be added via the standard /build-screen approval flow.

---

## ⑩ Expected BE→FE Contract

### GraphQL Queries (NEW + REUSED)

| GQL Field | Returns | Key Args | New / Reused |
|-----------|---------|----------|--------------|
| `GetHtmlReportTemplates` | `BaseApiResponse<List<HtmlReportTemplateGroupDto>>` | (none — auto-scoped by user identity + tenant) | NEW |
| `GetReportById` | `BaseApiResponse<ReportResponseDto>` | `reportId: Int!` | REUSE (existing `ReportQueries.cs:82`) |
| `GenerateReports` | `BaseApiResponse<ReportResult>` | `reportCode: String!`, `filterArgs: JSON` | REUSE (existing `ReportQueries.cs:114`) |

### GraphQL Mutations (NEW — all PLACEHOLDER)

| GQL Field | Input | Returns | Notes |
|-----------|-------|---------|-------|
| `GenerateHtmlReportPdf` | `{ reportCode: String!, filterArgs: JSON, language: String }` | `BaseApiResponse<String>` (URL) | PLACEHOLDER — returns mocked URL `"https://placeholder.local/pdf/{reportCode}-{ticks}.pdf"` |
| `ExportHtmlReportExcel` | `{ reportCode: String!, filterArgs: JSON }` | `BaseApiResponse<String>` (URL) | PLACEHOLDER |
| `EmailHtmlReport` | `{ reportCode, filterArgs, to, subject, message, format }` | `BaseApiResponse<Boolean>` | PLACEHOLDER — logs the request + returns true |
| `CreateHtmlReportShareLink` | `{ reportCode, filterArgs, expiryDays }` | `BaseApiResponse<String>` (URL) | PLACEHOLDER |

### DTOs

**`HtmlReportTemplateGroupDto`** (returned by `GetHtmlReportTemplates`):

```typescript
{
  category: string;                  // "Financial" | "Operational" | "Compliance" | "Management"
  categoryIcon: string;              // FA icon name (e.g. "fa-file-invoice-dollar") — optional; FE can hardcode if not returned
  templates: HtmlReportTemplateDto[];
}
```

**`HtmlReportTemplateDto`**:

```typescript
{
  reportId: number;
  reportCode: string;                // e.g. "MONTHLYCOLLECTIONSUMMARY"
  reportName: string;                // e.g. "Monthly Collection Summary"
  description: string | null;
  reportType: string | null;         // "document" | "html" — filter dimension
  category: string;                  // duplicate of group's category (convenience)
  runCount: number;                  // per-user, per-tenant; from ReportExecutionLog aggregate
  hasFilterSchema: boolean;          // true if Report.FilterSchema IS NOT NULL
}
```

**`ReportResponseDto`** (REUSED — already exists; verify these fields are exported):

```typescript
{
  reportId: number;
  reportName: string;
  reportCode: string;
  description: string | null;
  reportType: string | null;
  moduleId: string;                  // UUID
  storedProcedureName: string;
  filterSchema: string | null;       // JSON string — parsed by FE into RJSF schema + uiSchema
  isSystem: boolean;
  companyId: number | null;
}
```

**`ReportResult`** (REUSED — already returned by `GenerateReports`):

```typescript
{
  data: Array<Record<string, unknown>>;     // rows from the stored procedure
  metadata: { columns: Array<{ key, label, type, format }> };
  totals: Record<string, number>;           // optional footer totals per column
  summary: Record<string, unknown>;         // optional KPI bag (drives summary cards)
}
```

**Note on `summary` payload**: The canonical `MonthlyCollectionSummary` template expects
`summary = { totalCollections, totalTransactions, activeBranches, activeAmbassadors }`. Each
template's stored procedure decides its own summary keys; the template component reads them
by name. The BA should confirm the per-template summary contract during build.

### FE Variable Nullability (Memory: [[feedback_fe_query_nullability_must_match_be]])

| BE Type | FE Variable Declaration | Notes |
|---------|-------------------------|-------|
| `int!` reportId | `Int!` | required |
| `string!` reportCode | `String!` | required |
| `JSON` filterArgs | `JSON` (HotChocolate built-in scalar) | nullable optional |
| `string?` language | `String` | nullable; default English |
| `string[]?` to (email modal) | `[String!]` | per the memory rule — non-nullable inner type because BE will reject nulls inside list |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` passes
- [ ] Migration applies cleanly: `rep."Reports"."ReportCategory" varchar(50) NULL` exists
- [ ] `pnpm dev` — page loads at `/{lang}/reportaudit/reports/htmlreport`
- [ ] `pnpm tsc --noEmit` clean

**DOCUMENT-specific E2E:**
- [ ] Sidebar renders 4 categories with correct FA icons; reports listed per `ReportCategory`
- [ ] Per-template `runCount` badge reflects current user's run history
- [ ] Click sidebar item → main pane updates: parameter card title + form (from FilterSchema); paper area shows pre-Generate empty state
- [ ] Parameter form renders dynamically from `report.FilterSchema` (NOT hardcoded)
- [ ] Required-field affordance + validation per FilterSchema
- [ ] Generate triggers `GenerateReports` GQL query; loading skeleton in paper area
- [ ] Paper renders A4-styled card matching mockup colors, padding, border-radius, shadow
- [ ] Tenant logo + org name + report title + period + generated stamp render
- [ ] Summary section (4-col grid) renders KPIs from `data.summary`
- [ ] Data tables render with correct header/body/footer styling (tabular-nums, monospace amounts)
- [ ] Page-break renders dashed line on screen; CSS becomes `page-break-after: always` on print
- [ ] Footer renders "Page X of Y" + tenant tagline
- [ ] Toolbar Print → `window.print()` works; chrome / sidebar / toolbar / param card hidden
- [ ] Toolbar Export PDF / Excel / Share → SERVICE_PLACEHOLDER toasts
- [ ] Toolbar Zoom +/- updates CSS scale (50/75/100/125/150/200 steps); current % displays
- [ ] Toolbar Fullscreen enters/exits fullscreen
- [ ] Email modal opens / accepts inputs / validates emails / Send → SERVICE_PLACEHOLDER toast
- [ ] Pagination chevrons scroll to per-page `.paper-page` block
- [ ] `MonthlyCollectionSummary` template renders fully against `GenerateReports` payload
- [ ] Other 16 templates show PaperFallback placeholder (not crash) when clicked
- [ ] Empty state with zero rows shows diagnostic message referencing active filters
- [ ] Error state renders error card + retry button
- [ ] BUSINESSADMIN sees all categories; STAFFENTRY sees only Operational
- [ ] Sensitive data masked per role (e.g. donor PAN masked for non-BUSINESSADMIN)
- [ ] Max-row guard (>1k rows) renders banner with Excel-export CTA

**DB Seed Verification:**
- [ ] Menu visible at Report & Audit → Reports → HTML Reports
- [ ] BUSINESSADMIN role-capability rows for HTMLREPORT exist
- [ ] `rep.Reports` rows for the 17 sidebar templates exist with non-NULL `ReportCategory`
- [ ] `MonthlyCollectionSummary` has a valid FilterSchema JSON that drives the parameter form

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

### Universal REPORT warnings

- **Reports are read-only at the UI** — no in-place editing. No CREATE/MODIFY/DELETE capabilities; the only "write" is `ReportExecutionLog` rows on each Generate (already handled by existing engine).
- **GridFormSchema = SKIP** — this is a custom viewer, not a RJSF modal form.
- **Tenant scoping is enforced server-side** — `GetHtmlReportTemplates` + `GenerateReports` both apply `CompanyId` from HttpContext.
- **Role-scoped sidebar is server-side** — never trust the FE to filter the categories. `GetHtmlReportTemplates` joins `rep.ReportRoles` and filters.

### DOCUMENT-specific gotchas

- **PDF export is NOT a screenshot** — when the real PDF service lands, it must use print-CSS or a real PDF template engine, NOT html-to-canvas or `puppeteer.screenshot()`. For now the handler is a placeholder.
- **Page-break between pages is CSS-only** — do NOT generate separate `<iframe>` or new `<html>` documents per page. The `.paper-page` divs separated by `.page-break` work for both screen pagination (scroll-snap) and print (`page-break-after: always`).
- **Tenant branding pulled from tenant settings** — logo URL + org name + signatory name should come from the current company's settings, NOT hardcoded. If tenant settings don't expose these yet, fall back to a default purple gradient + "PSS 2.0" placeholder for v1.
- **The template registry is the extensibility seam** — each new template is its own React component file + one line in `templateRegistry`. The Backend doesn't need a code change to add a template (just a `rep.Reports` row + a stored procedure + `ReportCategory` value).
- **Each report's `FilterSchema` drives its own form** — do NOT hardcode the form fields seen in the mockup. The mockup's filter form is specific to `MonthlyCollectionSummary`; other templates will have different schemas.

### Module / module-instance notes

- **Menu already seeded** — `_seed_child_menu('HTML Reports','HTMLREPORT','RA_REPORTS','REPORTAUDIT','reportaudit/reports/htmlreport','solar:code-bold',6)` is at `Pss2.0_Global_Menus_List.sql:520`. The DB seed file in this build only adds capabilities + role-capabilities + the `ReportCategory` updates.
- **First DOCUMENT REPORT in the codebase** — sets canonical reference for `_REPORT.md §⑦` DOCUMENT sub-type. Replace the TBD block there after this build completes.
- **Coordination with #99 Report Catalog** — Report Catalog (PROMPT_READY) launches reports including HTML ones. Once both lands, Report Catalog's Run modal should support output format = HTML, which navigates here with `?reportCode={code}&filters={base64}`. The HTML Report Viewer should accept those query params on load and auto-select the sidebar item + pre-fill the form.
- **`ReportCategory` is shared infra** — if #99 Report Catalog wants to filter by category too, it should consume the same column. Document this in #99's build notes after this lands.

### Service Dependencies (UI-only — no backend service implementation)

> Full UI must be built; only the handler for the external service call is mocked.

- ⚠ **SERVICE_PLACEHOLDER: PDF Export** — Full UI implemented (toolbar button + loading state + download link). Backend mutation `GenerateHtmlReportPdf` returns a mocked URL because no PDF service (puppeteer / DinkToPdf / WkHtmlToPdf / PdfSharp) is wired in `Base.Application.csproj`. Add a TODO in the mutation file: "Replace with real PDF service when one is integrated."

- ⚠ **SERVICE_PLACEHOLDER: Excel Export** — Full UI implemented. Backend mutation `ExportHtmlReportExcel` returns a mocked URL because no Excel library (ClosedXML / EPPlus / NPOI) is wired. Add a TODO in the mutation.

- ⚠ **SERVICE_PLACEHOLDER: Email Report** — Full modal UI implemented (To/Subject/Message/Format + validation). Backend mutation `EmailHtmlReport` returns `true` and writes a log entry; does NOT actually send. A mail service exists for some flows (`NotifyBusiness/`) but the document-attachment path isn't wired. Add a TODO.

- ⚠ **SERVICE_PLACEHOLDER: Share Link** — Full UI implemented (button + toast). Backend mutation `CreateHtmlReportShareLink` returns a mocked URL. Needs signed-URL service that doesn't exist. Add a TODO.

- ⚠ **TEMPLATE_PLACEHOLDER: 16 of 17 templates** — Sidebar lists 17 templates; only `MonthlyCollectionSummary` has a real React component. The other 16 render `PaperFallback` ("Template not yet implemented"). Each follow-up template is its own per-screen build ticket. This is intentional scoping — inlining all 17 would be ~17 stored procedures + ~17 React templates + ~17 RJSF schemas, easily a separate epic.

- ⚠ **Tenant branding** — Logo URL / org name / signatory pulled from tenant settings. If those aren't surfaced via a query yet, the FE should fall back to a default (purple gradient + "PSS 2.0" placeholder) and add a TODO to wire to real tenant settings.

### Out of Scope (defer to follow-up builds)

- **Scheduled HTML reports** — see #101 Scheduled Reports (SKIP_CONFIG)
- **Per-report stored procedures for 16 not-yet-implemented templates** — each is its own ticket
- **Real chart rendering inside the paper** — placeholder block + dashed border for now; recharts/chart.js wiring deferred to per-template builds
- **PDF / Excel / Email / Share real backends** — see SERVICE_PLACEHOLDER block
- **Tenant branding query** — falls back to defaults; real wiring deferred
- **i18n (Hindi / Arabic / Bengali)** — UI shows the dropdown but only English is enabled in v1; full i18n is a platform-wide effort, not this screen's job

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | (planning, 2026-05-13) | HIGH | Backend | The `ReportConfiguration.cs` (Mapster / EF) path needs to be confirmed before adding the `ReportCategory` column config. | CLOSED (Session 1, 2026-05-14): Confirmed at `Base.Infrastructure/Data/Configurations/ReportConfigurations/ReportConfiguration.cs` (note the `Data/` subfolder). Column config added with `HasMaxLength(50)`. |
| ISSUE-2 | (planning, 2026-05-13) | MED | Backend | The 17 `ReportCode` values listed in the seed UPDATE statements assume those rows already exist in `rep.Reports`. | CLOSED (Session 1, 2026-05-14): Confirmed NONE of the 17 codes exist in seed scripts. Seed uses INSERT with `WHERE NOT EXISTS (ReportCode, ModuleId)` guards (idempotent). |
| ISSUE-3 | (planning, 2026-05-13) | MED | Backend | `MonthlyCollectionSummary` needs a real stored procedure to be useful. | DEFERRED (Session 1, 2026-05-14): User decision = mock data inside the React template. Seed sets `StoredProcedureName='usp_MonthlyCollectionSummary'` as placeholder name; future build authors the real proc and flips the template to call `generateReports`. |
| ISSUE-4 | (planning, 2026-05-13) | LOW | Frontend | Tenant branding (logo URL / org name / signatory) source query is unknown. | DEFERRED (Session 1, 2026-05-14): User decision = placeholder fallback. Hardcoded "GLOBAL HUMANITARIAN FOUNDATION" + purple gradient + "Confidential" tagline in `monthly-collection-summary.tsx` with TODO comment. |
| ISSUE-5 | (planning, 2026-05-13) | LOW | Frontend | The mockup's "Generate Report" button does NOT show a loading state. | CLOSED (Session 1, 2026-05-14): Implemented — paper area renders skeleton in `paper-renderer.tsx` during `metaLoading`. Generate button disabled while form invalid. |
| ISSUE-6 | (planning, 2026-05-13) | LOW | Frontend | The "Last Run" badge in the sidebar — per-user or per-tenant? | RESOLVED (Session 1, 2026-05-14): Decision = per-user. Implemented at `GetHtmlReportTemplatesQuery.cs:48-50` as `Count(l => l.ReportId == r.ReportId && l.UserId == userId)`. **Note**: `ReportExecutionLog` has no `CompanyId` column (testing surfaced this), so per-user-per-tenant becomes effectively per-user (tenant scoping is implicit via UserId). |
| ISSUE-7 | (build, 2026-05-14) | LOW | Frontend | `api-select` parameter-form field type falls back to plain text input — no `ApiSelectBySource` wrapper exists in the codebase that accepts a GQL query name as a string prop. Branch / DonationPurpose / Campaign / Ambassador / Language dropdowns in the MonthlyCollectionSummary FilterSchema render as text inputs in v1. Need a follow-up build to author `ApiSelectBySource` that wraps `ApiSelectV2`. | OPEN |
| ISSUE-8 | (build, 2026-05-14) | LOW | Frontend | `ScreenHeader` component does not expose a `subtitle` prop — the FE Dev fell back to `description` which renders as an info-icon tooltip rather than inline subtitle. Page title "HTML Reports" displays correctly but the "Generate and view formatted printable reports" subtitle from the mockup is tooltipped not displayed inline. Acceptable minor UX delta; future enhancement when `ScreenHeader` grows a `subtitle` prop. | OPEN |
| ISSUE-9 | (build, 2026-05-14) | LOW | Frontend | The 16 unimplemented templates render `PaperFallback` placeholder. Each template needs its own React component + stored procedure + FilterSchema JSON before it produces real output. Tracked as 16 follow-up build tickets — one per template (80G Certificate, Donation Acknowledgment, Annual Giving Statement, Tax Receipt Summary, Staff Activity, Branch Collection, Ambassador Performance, Receipt Book Audit, Purpose-wise Collection, FCRA Returns, Donor Disclosure, Audit Trail, Annual Return Summary, Board Meeting Package, Quarterly Review Deck, Year-End Summary, Campaign Impact). | OPEN |
| ISSUE-10 | (build, 2026-05-14) | LOW | Backend | `EmailHtmlReport` mutation uses `[CustomAuthorize(..., Permissions.Read)]` because no `Permissions.Email` enum member exists in the codebase. The EMAIL capability seeded for HTMLREPORT is checked at the menu level but the mutation authorization falls back to Read. Add an `Email` permission constant if the team wants distinct mutation-level enforcement. | OPEN |
| ISSUE-11 | (build, 2026-05-14) | LOW | Backend | `ReportExecutionLog` has no `CompanyId` column — testing flagged this; query was fixed to drop the tenant filter. If multi-tenancy needs to enforce per-tenant run-count isolation (e.g. a user belonging to multiple tenants), add `CompanyId` to `ReportExecutionLog` and re-include in the subquery. Currently per-user is sufficient since `UserId` is single-tenant in this codebase. | OPEN |
| ISSUE-12 | (build, 2026-05-14) | LOW | Backend | `ExportHtmlReportExcelMutation` accepts 3 args on the BE (`reportCode`, `filterArgs`, `language`) but the FE mutation file only sends 2 (`reportCode`, `filterArgs`) — the `language` arg is dropped because Excel exports don't need language. Minor asymmetry vs `GenerateHtmlReportPdf` which DOES send language. Acceptable as-is. | OPEN |
| ISSUE-13 | (build, 2026-05-14) | LOW | Backend | DB seed inserts a row into `sett.Grids` with `GridTypeId = 1` (raw int) rather than a `GridTypeCode` subquery lookup. Was kept for forward-compat. If the `Grids` table is consulted by HTMLREPORT later, verify the type id maps to the correct GridType. The screen uses `GridFormSchema = SKIP` so no RJSF form is associated. | OPEN |
| ISSUE-14 | (continue, 2026-05-14) | LOW | Backend/DB | Migration `20260514120000_Add_ReportCategory_To_Reports.cs` rewritten to drop legacy `rep.Reports.ReportType` (string) and add `ReportTypeId` (int NOT NULL) + `ReportCategoryId` (int NULL) FK columns to `sett.MasterDatas`. Greenfield/dev safe (existing `ReportType` string values are NOT backfilled — production rollout must seed `MasterDataType + MasterData` rows for `REPORTTYPE` / `REPORTCATEGORY` and UPDATE `ReportTypeId` based on legacy string values BEFORE applying this migration, or run migration immediately followed by `HtmlReport-sqlscripts.sql`). | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-14 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. First DOCUMENT REPORT in the codebase — sets canonical reference for `_REPORT.md §⑦` DOCUMENT sub-type.
- **Files touched**:
  - BE (13):
    - `Base.Domain/Models/ReportModels/Report.cs` (modified — added `ReportCategory?` property)
    - `Base.Infrastructure/Data/Configurations/ReportConfigurations/ReportConfiguration.cs` (modified — `HasMaxLength(50)`)
    - `Base.Infrastructure/Migrations/20260514120000_Add_ReportCategory_To_Reports.cs` (created)
    - `Base.Application/Schemas/ReportSchemas/HtmlReportTemplateSchemas.cs` (created)
    - `Base.Application/Business/ReportBusiness/Reports/Queries/GetHtmlReportTemplatesQuery.cs` (created — fix-up dropped `l.CompanyId` filter mid-session, see ISSUE-11)
    - `Base.Application/Business/ReportBusiness/Reports/Mutations/GenerateHtmlReportPdfMutation.cs` (created — SERVICE_PLACEHOLDER)
    - `Base.Application/Business/ReportBusiness/Reports/Mutations/ExportHtmlReportExcelMutation.cs` (created — SERVICE_PLACEHOLDER)
    - `Base.Application/Business/ReportBusiness/Reports/Mutations/EmailHtmlReportMutation.cs` (created — SERVICE_PLACEHOLDER)
    - `Base.Application/Business/ReportBusiness/Reports/Mutations/CreateHtmlReportShareLinkMutation.cs` (created — SERVICE_PLACEHOLDER)
    - `Base.API/EndPoints/Report/Queries/ReportQueries.cs` (modified — registered `GetHtmlReportTemplates`)
    - `Base.API/EndPoints/Report/Mutations/ReportMutations.cs` (modified — registered 4 new mutations)
    - `Base.Application/Mappings/ReportMappings.cs` (modified — added `Report → HtmlReportTemplateDto` Mapster config)
    - `Base.API/...` and `Base.Application/...` various `using` directives added by BE Dev (incremental, non-disruptive)
  - FE (19):
    - `src/domain/entities/report-service/HtmlReportTemplateDto.ts` (created)
    - `src/domain/entities/report-service/index.ts` (modified — added barrel export)
    - `src/domain/types/report-types/FilterSchemaField.ts` (created — shared extended type)
    - `src/infrastructure/gql-queries/report-queries/HtmlReportTemplateQuery.ts` (created)
    - `src/infrastructure/gql-queries/report-queries/GenerateHtmlReportPdfMutation.ts` (created)
    - `src/infrastructure/gql-queries/report-queries/ExportHtmlReportExcelMutation.ts` (created)
    - `src/infrastructure/gql-queries/report-queries/EmailHtmlReportMutation.ts` (created)
    - `src/infrastructure/gql-queries/report-queries/CreateHtmlReportShareLinkMutation.ts` (created)
    - `src/infrastructure/gql-queries/report-queries/index.ts` (modified — added 5 barrel exports)
    - `src/presentation/pages/reportaudit/reports/htmlreport.tsx` (created — page config)
    - `src/presentation/pages/reportaudit/reports/index.ts` (modified — added export)
    - `src/app/[lang]/reportaudit/reports/htmlreport/page.tsx` (modified — replaced `UnderConstruction` with `HtmlReportPageConfig`)
    - `src/presentation/components/page-components/reportaudit/reports/htmlreport/report-viewer-page.tsx` (created — fix-up restructured `useLazyQuery` for Apollo Client 4 compat, see ISSUE-fix below)
    - `src/presentation/components/page-components/reportaudit/reports/htmlreport/components/report-sidebar.tsx` (created — fix-up swapped raw className to `styles.reportSidebar`)
    - `src/presentation/components/page-components/reportaudit/reports/htmlreport/components/parameter-form.tsx` (created — fix-up swapped raw className to `styles.paramCard`)
    - `src/presentation/components/page-components/reportaudit/reports/htmlreport/components/report-toolbar.tsx` (created — fix-up swapped raw className to `styles.reportToolbar`)
    - `src/presentation/components/page-components/reportaudit/reports/htmlreport/components/paper-renderer.tsx` (created)
    - `src/presentation/components/page-components/reportaudit/reports/htmlreport/components/template-registry.tsx` (created)
    - `src/presentation/components/page-components/reportaudit/reports/htmlreport/components/templates/monthly-collection-summary.tsx` (created — fix-up: periodMonth/periodYear typed as string not number per actual schema values)
    - `src/presentation/components/page-components/reportaudit/reports/htmlreport/components/templates/paper-fallback.tsx` (created)
    - `src/presentation/components/page-components/reportaudit/reports/htmlreport/components/email-modal.tsx` (created)
    - `src/presentation/components/page-components/reportaudit/reports/htmlreport/components/print-styles.module.css` (created)
    - `src/presentation/components/page-components/reportaudit/reports/htmlreport/index.ts` (created — local barrel for `HtmlReportViewerPage`)
  - DB Seed: `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/HtmlReport-sqlscripts.sql` (created — preserved `dyanmic` typo)
- **Deviations from spec**:
  - User-locked decisions (recorded pre-build): MonthlyCollectionSummary uses mock data inside FE template; runCount per-user (effectively per-user since `ReportExecutionLog` has no `CompanyId`); tenant branding hardcoded; BUSINESSADMIN-only role seed.
  - Filter-schema parsing uses **custom `FilterSchemaField[]` JSON** format (mirrors `reportcatalog/run-modal.tsx`), **NOT RJSF**. Prompt assumed RJSF — codebase doesn't have RJSF for this pattern.
  - Existing GQL files NOT created as separate `GetReportByIdQuery.ts` / `GenerateReportsQuery.ts` — both queries already live consolidated in `ReportQuery.ts` (FE-spawn-1 discovery).
  - `api-select` field type in parameter-form falls back to plain text input (see ISSUE-7) — no `ApiSelectBySource` exists.
  - `ScreenHeader` `subtitle` → rendered as info-icon tooltip via `description` prop (see ISSUE-8).
  - Inline mid-build fix-ups applied (testing-flagged): RunCount subquery dropped `l.CompanyId` (column doesn't exist); `useLazyQuery` `onCompleted` replaced with `useEffect` watching returned `data` (Apollo Client 4 compat); 3 className strings switched from raw to `styles.*` CSS-Modules refs so print rules target correctly; `monthly-collection-summary.tsx` periodMonth/Year cast string not number; barrel exports added for the 1 DTO + 5 GQL files.
- **Known issues opened**: ISSUE-7 (api-select fallback), ISSUE-8 (ScreenHeader subtitle), ISSUE-9 (16 templates unimplemented), ISSUE-10 (Permissions.Email constant missing), ISSUE-11 (ReportExecutionLog.CompanyId missing), ISSUE-12 (Excel mutation language asymmetry), ISSUE-13 (Grids row GridTypeId=1 raw int).
- **Known issues closed**: ISSUE-1 (ReportConfiguration path resolved), ISSUE-2 (seed INSERT-vs-UPDATE decision resolved → INSERT with guards), ISSUE-5 (loading state implemented), ISSUE-6 (runCount per-user decision implemented).
- **Known issues deferred**: ISSUE-3 (real MonthlyCollectionSummary stored proc → future), ISSUE-4 (tenant branding query → future).
- **Build verification**:
  - `dotnet build Base.Application.csproj` → **0 errors, 404 warnings** (all pre-existing in unrelated files)
  - `pnpm tsc --noEmit` → **0 errors in new files** (existing pre-existing errors unaffected)
  - Wiring spot-checks (testing-agent) → PASS after mid-session fix-ups
  - GQL contract match (BE schema ↔ FE queries) → PASS
  - Seed integrity (17 INSERTs idempotent, ModuleId subquery-resolved, FilterSchema JSON parses) → PASS
- **User action required before runtime test**:
  - Run migration: `dotnet ef database update --project Services/Base/Base.Infrastructure --startup-project Services/Base/Base.API --context ApplicationDbContext` (or run the hand-written migration file at `Base.Infrastructure/Migrations/20260514120000_Add_ReportCategory_To_Reports.cs` — EF will auto-generate the `.Designer.cs` snapshot on `ef migrations add`)
  - Run seed: `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/HtmlReport-sqlscripts.sql`
  - Then `pnpm dev` → navigate to `/{lang}/reportaudit/reports/htmlreport` to verify full-flow (sidebar templates load, click → parameter form renders, Generate → mocked MonthlyCollectionSummary paper renders, Print/Email/Zoom/Fullscreen work, other templates show PaperFallback).
- **Next step**: None (build COMPLETED). Follow-up tickets: ISSUE-7/8/9/10/11/12/13 prioritization. First DOCUMENT REPORT canonical reference established — update `_REPORT.md §⑦` DOCUMENT block to point at this prompt.

### Session 2 — 2026-05-14 — CONTINUE — COMPLETED

- **Scope**: ReportType + ReportCategory FK rework. User requested converting both `Report.ReportType` (legacy free-form string) and the just-added `Report.ReportCategory` (string) into FK columns referencing `sett.MasterDatas`. Both columns now reference their respective `MasterDataType` (REPORTTYPE / REPORTCATEGORY). `ReportTypeId` is REQUIRED; `ReportCategoryId` is OPTIONAL. Sample REPORTTYPE values seeded: Document / Grid / Dashboard / Custom. Sample REPORTCATEGORY values seeded: Financial / Operational / Compliance / Management.
- **Files touched**:
  - BE (9 modified):
    - `Base.Domain/Models/ReportModels/Report.cs` (modified — replaced `string? ReportType` + `string? ReportCategory` with `int ReportTypeId` + `MasterData ReportType` nav and `int? ReportCategoryId` + `MasterData? ReportCategory` nav)
    - `Base.Domain/Models/SettingModels/MasterData.cs` (modified — added `ICollection<Report>? ReportTypes` and `ICollection<Report>? ReportCategories` back-navs)
    - `Base.Infrastructure/Data/Configurations/ReportConfigurations/ReportConfiguration.cs` (modified — dropped property `HasMaxLength` configs, added FK `HasOne(...).WithMany(...).HasForeignKey(...)` for both refs + FK indexes)
    - `Base.Infrastructure/Migrations/20260514120000_Add_ReportCategory_To_Reports.cs` (rewritten — drops legacy `ReportType` string col, adds `ReportTypeId` + `ReportCategoryId` int cols with indexes + FK constraints to `sett.MasterDatas`)
    - `Base.Application/Business/ReportBusiness/Reports/Queries/GetHtmlReportTemplatesQuery.cs` (modified — filter changed from `r.ReportCategory != null` to `r.ReportCategoryId != null`, projection now reads from nav: `r.ReportType.DataValue` / `r.ReportCategory!.DataName`)
    - `Base.Application/Business/ReportBusiness/ReportCatalog/GetReportCatalogQuery/GetReportCatalog.cs` (modified — added `.Include(r => r.ReportType)`, ReportType + IsEditable projections rewritten to use `r.ReportType.DataValue` instead of free-string compare against "Custom")
    - `Base.Application/Business/AuthBusiness/ReportRoles/Queries/GetReportRolesByModule.cs` (modified — legacy `r.ReportType == null` filter (which excluded Custom reports under the string convention) translated to `r.ReportType.DataValue != "CUSTOM"`; ReportRequestDto projection now sets both `ReportTypeId` and the display-only `ReportType` field)
    - `Base.Application/Mappings/ReportMappings.cs` (modified — `Report → HtmlReportTemplateDto` Mapster config now reads `ReportType.DataValue` and `ReportCategory.DataName`)
    - `Base.Application/Schemas/ReportSchemas/ReportSchemas.cs` (modified — `ReportRequestDto` gained `int? ReportTypeId` and `int? ReportCategoryId` for FK create/update; legacy `string? ReportType` retained as display-only convenience populated by server from nav)
  - DB Seed (1 rewritten):
    - `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/HtmlReport-sqlscripts.sql` — added STEP 0a/0b/0c (seed `MasterDataTypes` for REPORTTYPE + REPORTCATEGORY, seed 4 REPORTTYPE rows and 4 REPORTCATEGORY rows under `sett.MasterDatas`); rewrote 17 `rep.Reports` INSERTs to resolve `ReportTypeId` / `ReportCategoryId` via subquery against `sett.MasterDatas` instead of literal strings; rewrote STEP 6 backfill UPDATEs to target `ReportCategoryId` with subquery lookups.
- **Deviations from spec**: None — followed the user-chosen option (option 1 of 4 in the FK rework question): both columns FK, ReportType required, ReportCategory optional.
- **Known issues opened**: ISSUE-14 (migration is greenfield/dev-safe; production rollouts must backfill `ReportTypeId` before applying or risk losing legacy string values).
- **Known issues closed**: None (the FK rework supersedes the original `ReportCategory` string-column design from Session 1; ISSUE-7 through ISSUE-13 remain OPEN as they are FE/feature-scoped, not schema-scoped).
- **Build verification**:
  - `dotnet build Base.API.csproj` (transitively builds Base.Application, Base.Infrastructure, Base.Domain) → **0 errors, 487 warnings** (all pre-existing in unrelated files)
- **User action required before runtime test**:
  - Regenerate migration snapshot: `dotnet ef migrations remove --project Services/Base/Base.Infrastructure --startup-project Services/Base/Base.API --context ApplicationDbContext` then `dotnet ef migrations add Add_ReportCategory_To_Reports --project Services/Base/Base.Infrastructure --startup-project Services/Base/Base.API --context ApplicationDbContext` to let EF regenerate the `.Designer.cs` snapshot for the rewritten migration.
  - Run migration: `dotnet ef database update --project Services/Base/Base.Infrastructure --startup-project Services/Base/Base.API --context ApplicationDbContext`
  - Run seed: `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/HtmlReport-sqlscripts.sql` (MUST run AFTER migration — depends on the new FK columns and inserts the MasterData rows the 17 Report INSERTs reference).
- **Next step**: None (FK rework COMPLETED).
