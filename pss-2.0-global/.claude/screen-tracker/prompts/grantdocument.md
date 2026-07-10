---
screen: GrantDocument
registry_id: 178
module: Grants (CRM)
status: COMPLETED
scope: FULL
screen_type: REPORT
report_subtype: DOCUMENT
source_pattern: query-only
pagination_strategy: n/a (single-record document; optional bulk = per-record A4 paging)
complexity: High
new_module: NO — reuses `grant` schema (bootstrapped by #62 Grant). NO new entity, NO migration.
planned_date: 2026-07-10
completed_date: 2026-07-10
last_session_date: 2026-07-10
---

## Tasks

### Planning (by /plan-screens)
- [x] Sub-type identified: DOCUMENT (per-grant fixed A4 printable — Financial Report + Impact Report)
- [x] Source data identified — DERIVED from existing grant engine (no mockup; spec derived from code). Source entities + how they join + computed columns mapped in §②.
- [x] Filter/recipient panel inventoried (Grant picker + Document Type + period/as-of)
- [x] Result shape inventoried (two A4 document layouts: FINANCIAL, IMPACT)
- [x] Scale estimated (one grant per render; optional bulk = N grants, per-record page break)
- [x] Pagination strategy chosen (single document; no table pagination)
- [x] Export formats confirmed (Print + PDF via print-CSS = REAL; server-PDF/email-attachment = SERVICE_PLACEHOLDER)
- [x] Role-scoping rules captured (BE query applies CompanyId + branch scope; InternalNotes never leaves BE)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (audience = grant manager + funder; frequency = per reporting cycle / ad-hoc)
- [x] Solution Resolution complete (DOCUMENT confirmed, query-only, print-CSS PDF)
- [x] UX Design finalized (recipient panel + two document layouts + export menu)
- [x] User Approval received (backend pre-existing; FE build ordered directly)
- [x] Backend GetGrantDocument query generated (assembles from existing engine) — pre-existing, verified
- [x] Backend export handlers (Print/PDF via print-CSS = FE; server-PDF + Email = SERVICE_PLACEHOLDER) — pre-existing, verified
- [x] Backend wiring complete (query registered on GrantDocumentQueries endpoint) — pre-existing, verified
- [x] Frontend report page generated
- [x] Frontend wiring complete
- [ ] DB Seed script generated (menu entry only; GridFormSchema SKIP) — sql-scripts-dyanmic/GrantDocument-sqlscripts.sql exists; menu row not independently re-verified this session
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/crm/grant/grantdocument`
- [ ] Grant picker + Document Type render; Generate disabled until a grant is picked
- [ ] Generate triggers query (loading state = faded A4 page skeleton)
- [ ] FINANCIAL document renders matching A4 layout (letterhead / funder block / summary / ledgers / budget-vs-actual / signature / footer)
- [ ] IMPACT document renders matching A4 layout (letterhead / narrative / KPI deliverables / impact stories / beneficiary rollup / footer)
- [ ] Tenant logo + address + colors pulled from Company + OrganizationSetting BRANDING (not hardcoded)
- [ ] All amounts FX-normalized to grant currency; mixed-currency source rows never summed raw
- [ ] ComplianceRate computed + displayed (accepted vs due reports)
- [ ] Print preview matches on-screen render (`@media print` hides app chrome)
- [ ] Download PDF produces the same layout via print-CSS (NOT an html2canvas screenshot)
- [ ] Email to funder triggers handler (SERVICE_PLACEHOLDER toast + GrantCommunication audit row)
- [ ] Role-scoped: only grants in the user's CompanyId (+ branch scope) are pickable; InternalNotes absent from all DTOs
- [ ] DB Seed — menu visible under CRM › Grants at correct parent

---

## ① Screen Identity & Context

Screen: Grant Report Generation (code entity: **GrantDocument**)
Module: Grants (CRM)
Schema: `grant` (reuses #62 Grant tables — reports own NO table)
Group: GrantBusiness

Business: This screen **auto-generates polished, printable per-grant documents** from data already captured by the grant financial engine and the #63 GrantReport narrative lifecycle — it is pure derivation, the user enters nothing. It produces **two document types**: (1) a **Financial Report** — a funder-facing statement of money received, transferred, and spent, budget-vs-actual by line, utilization, and cash-on-hand, all normalized to the grant's currency; and (2) an **Impact Report** — the grant's objectives and narrative (problem, solution, outcomes, sustainability), the latest accepted progress narrative's impact stories, KPI/deliverable progress, and beneficiaries served. It is run by the **grant manager / BUSINESSADMIN** on a reporting cycle (quarterly / at close) or ad-hoc when a funder requests an update; the rendered document is printed, saved as PDF, or emailed to the funder. It exists to close the grant reporting loop with a defensible, branded document instead of hand-assembling numbers in Word — and to surface a **ComplianceRate** (accepted-vs-due reports) that was previously an uncomputed null. Typical scale is **one grant per render** (a single A4 document, 1–3 pages); an optional bulk mode renders N grants with a page break between each. Data sensitivity: funder-facing financial detail is intended for the funder, but **InternalNotes and internal-direction communications are never included** — they are excluded in the BE DTO, not merely hidden. It relates to #62 Grant (its data source + drill-back target), #63 GrantReport (source of period narratives/KPIs), and the grant funder-communication log (email audit).

---

## ② Source Model

**Source Pattern**: `query-only` — the document assembles existing entities at run time. **NO new table, NO DbSet, NO migration.** (A future `report-row-table` to persist issued PDFs is out of scope for V1 — noted in §⑫.)

### Source Entities

| Source Entity | Entity File Path | Fields Consumed | Join Cardinality | Filter |
|---------------|------------------|-----------------|------------------|--------|
| Grant | Base.Domain/Models/GrantModels/Grant.cs | GrantId, GrantCode, GrantTitle, GrantProgram, Funder* block, RequestedAmount, AwardedAmount, CurrencyId, StartDate, EndDate, AgreementSignedDate, StageId, ExecutiveSummary, ProblemStatement, ProposedSolution, ExpectedOutcomes, SustainabilityPlan, ComplianceRate, NextReportDueDate | root | GrantId = arg; CompanyId from HttpContext; branch scope |
| GrantFundReceipt | Base.Domain/Models/GrantModels/GrantFundReceipt.cs | ReceiptCode, Amount, CurrencyId, **GrantCurrencyAmount ?? Amount**, ReceivedDate, PaymentMethod, ReferenceNumber, ReceiptStatusId | 1:N via GrantId | active only (exclude BOUNCED/CANCELLED) |
| GrantExpense | Base.Domain/Models/GrantModels/GrantExpense.cs | ExpenseDate, Amount, Description, Vendor, GrantBudgetLineId, PaymentMode | 1:N via GrantId | — |
| GrantBudgetLine | Base.Domain/Models/GrantModels/GrantBudgetLine.cs | Category, BudgetedAmount, SpentAmount, IsAdminCategory, SortOrder | 1:N via GrantId | budget-vs-actual table |
| ProgramFundingSource | Base.Domain/Models/CaseModels/ProgramFundingSource.cs | ProgramId, AllocatedAmount, ExpectedAnnualAmount, SourceStatusId | 1:N via GrantId (nullable FK) | program allocations |
| ProgramFundingTransaction | Base.Domain/Models/CaseModels/ProgramFundingTransaction.cs | Amount, **GrantCurrencyAmount ?? Amount**, PaymentStatus, TransactionDate | via FundingSource | PaymentStatus="TRANSFERRED" |
| GrantReport | Base.Domain/Models/GrantModels/GrantReport.cs | ReportTitle, ReportingPeriodStart/End, DueDate, SubmittedDate, AcceptedDate, StatusCode, ExecutiveSummary, ChallengesAndRisks, **ImpactStories** | 1:N via GrantId | latest ACCEPTED for Impact narrative; all rows for ComplianceRate |
| GrantReportDeliverable | (child of GrantReport) | DeliverableName, TargetValue, CurrentValue, PreviousValue, ProgressPercent, Narrative, OrderIndex | via latest accepted GrantReport | KPI section |
| GrantStageHistory | Base.Domain/Models/GrantModels/GrantStageHistory.cs | FromStageId, ToStageId, TransitionDate, ActorStaff, AmountReceived, Notes | 1:N via GrantId | timeline (Impact doc, optional) |
| Company | Base.Domain/Models/ApplicationModels/Company.cs | CompanyName, CompanyHeader, CompanyFooter, Address, AddressLine2, City/State/PostalCode, PrimaryEmail, PrimaryPhone, Website, RegistrationNumber, TaxId | 1:1 via CompanyId | letterhead issuer block |
| OrganizationSetting | Base.Domain/Models/SettingModels/OrganizationSetting.cs | BRANDING group: LOGO_URL, PRIMARY_COLOR_HEX, SECONDARY_COLOR_HEX | key/value | letterhead logo + brand colors, via `IOrgSettingsService.GetStringAsync` |

> **Reuse, don't re-implement:** the financial numbers already exist in `GetGrantFinancialSummary` (`GrantFinancialSummaryDto`), `GetGrantUtilization` (`GrantUtilizationDto`), and `GetGrantFundingRequests`. The new `GetGrantDocument` query should **compose these existing computations** (call the handlers or reuse their LINQ) so the document totals reconcile exactly with the Grant detail screen — do NOT write a parallel, divergent aggregation.

### Computed / Derived Columns

| Column Name | Formula | Source | Notes |
|-------------|---------|--------|-------|
| totalReceived | Σ active GrantFundReceipt (`GrantCurrencyAmount ?? Amount`) | aggregated | reuse GetGrantFinancialSummary |
| totalSpent (direct) | Σ GrantExpense.Amount | aggregated | reuse |
| programTransferred | Σ TRANSFERRED ProgramFundingTransaction (`GrantCurrencyAmount ?? Amount`) | aggregated | reuse |
| cashOnHand | totalReceived − totalSpent − Max(totalCommitted, programTransferred) | aggregated | reuse (double-spend-correct) |
| utilizationPct | Round(totalUtilized / awardedAmount × 100, 1) | aggregated | reuse GetGrantUtilization |
| budgetVariance (per line) | BudgetedAmount − SpentAmount | GrantBudgetLine | per budget row; flag over-spend |
| adminPct | Σ BudgetedAmount where IsAdminCategory / Σ BudgetedAmount × 100 | GrantBudgetLine | surface soft >10% advisory in doc |
| **complianceRate** | acceptedReports / dueReports × 100 (dueReports = GrantReport rows with DueDate ≤ today) | GrantReport | **NEW compute** — absorbs the deferred ComplianceRate item. Display in Impact doc header; optional write-back to Grant.ComplianceRate via a mutation (see §⑫). |
| beneficiariesServed | rollup of enrollments/cases under Program(s) linked via ProgramFundingSource.GrantId | derived | Impact doc; see §⑫ — if no direct enrollment count exists, show Program.TargetBeneficiaries as "target" + note actual-count is a follow-up |
| reportingStatus | latest GrantReport StatusCode + next DueDate vs today | GrantReport | "On track / Overdue" chip |

---

## ③ FK Resolution Table

| FK / Filter Source | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type | Used For |
|--------------------|--------------|-------------------|----------------|---------------|-------------------|----------|
| GrantId (recipient picker) | Grant | Base.Domain/Models/GrantModels/Grant.cs | `getGrants` (existing list) / `GetAllGrantList` if present | GrantTitle (+ GrantCode) | Grant list DTO | pick which grant to document |
| FunderContactId (To-block) | Contact | Base.Domain/Models/ContactModels/Contact.cs | (denormalized on Grant — prefer Grant.FunderContact* fields) | FunderContactPersonName | — | letterhead recipient |
| CompanyId (issuer/tenant) | Company | Base.Domain/Models/ApplicationModels/Company.cs | resolved from HttpContext | CompanyName | — | letterhead issuer |
| BRANDING settings | OrganizationSetting | Base.Domain/Models/SettingModels/OrganizationSetting.cs | `IOrgSettingsService.GetStringAsync(paramCode, companyId)` | LOGO_URL / *_COLOR_HEX | string | letterhead logo + colors |

> Confirm the exact grant-list GQL name in `GrantQueries.cs` at build time (agent saw `getGrants`); reuse it for the picker rather than adding a new list query.

---

## ④ Business Rules & Validation

**Required Filters:**
- **Grant** is required — Generate is disabled until a grant is selected.
- **Document Type** is required — `FINANCIAL | IMPACT | BOTH` (default FINANCIAL). `BOTH` renders them as one combined funder packet (page-break between). **`documentType` is an OPEN, extensible enum** — future types (PERIOD_PROGRESS, AWARD_LETTER, COMPLETION_CERTIFICATE, COMPLIANCE_SUMMARY) must slot in as a new layout component + one query branch, NOT a re-architecture. Build the switch so adding a type touches only: the enum, one BE assembly branch, and one FE `<XDocument>` component. See §⑫ for the roadmap.

**Filter Validation:**
- Grant must be in a stage where a document makes sense (APPROVED / ACTIVE / REPORTING / CLOSED). For DRAFT/REJECTED grants show a diagnostic empty-state ("Documents generate once the grant is Approved").
- Optional "As-of date" / reporting-period picker for the Financial doc — defaults to grant's current NextReportDue period or full-to-date; end ≥ start.

**Computed-Column Rules:**
- **All monetary rollups use the FX-normalized column** (`GrantCurrencyAmount ?? Amount`) — never sum raw `Amount` across mixed `CurrencyId`. This is the WI-3 rule; the document MUST match the Grant detail totals.
- Over-spent budget lines (SpentAmount > BudgetedAmount) render with a warning affordance.
- Admin % > 10% renders a soft advisory note in the Financial doc (non-blocking — mirrors WI-6).
- ComplianceRate: dueReports counts GrantReport rows with `DueDate <= today`; acceptedReports counts `StatusCode == "Accepted"`. If dueReports = 0 → show "No reports due yet" rather than 0%.

**Role-Based Data Scoping** (row-level security — BE only):
| Role | Sees | Excluded |
|------|------|----------|
| BUSINESSADMIN | all grants for tenant | none |
| (others per existing grant capability) | per existing Grant read scope (branch) | grants outside scope |

> Scoping mirrors the existing Grant read query — reuse `[CustomAuthorize(DecoratorGrantModules.Grant, Permissions.Read)]` and the same CompanyId/branch filter. FE never trusts client role.

**Sensitive Data Handling:**
| Field | Sensitivity | Display Treatment | Export Treatment |
|-------|-------------|-------------------|------------------|
| Grant.InternalNotes | internal-only | **never rendered** | **absent from DTO** |
| GrantCommunication (Direction=INTERNAL) | internal-only | never rendered | absent from DTO |
| RejectionReason | internal-only | never in funder docs | absent from DTO |

**Max-Row Guard:** N/A for single-document render. Bulk mode caps at a sane N (e.g. 200 grants) — beyond that, require narrower filters.

**Workflow:** None (read-only derivation). Optional future: GENERATED → SENT audit via GrantCommunication (see §⑫).

---

## ⑤ Screen Classification & Pattern Selection

**Screen Type**: REPORT
**Report Sub-type**: `DOCUMENT`
**Source Pattern**: `query-only`
**Pagination Strategy**: single document (no table pagination). Bulk = per-record A4 page break.

**Reason**: The output is a per-grant fixed-layout printable statement (funder-facing Financial + Impact reports), not a filterable table or pivot — the defining DOCUMENT shape. It derives entirely from existing grant entities (query-only, no storage) and reconciles with the Grant detail financial engine.

**Backend Patterns Required (DOCUMENT):**
- [x] `GetGrantDocument` query — returns the assembled data for ONE grant's document (both FINANCIAL + IMPACT payloads, FE renders the selected type)
- [x] Tenant scoping (CompanyId from HttpContext) + reuse Grant read authorization
- [x] Composes existing GetGrantFinancialSummary / GetGrantUtilization / GetGrantFundingRequests computations (reconcile, don't diverge)
- [x] ComplianceRate compute from GrantReport lifecycle
- [ ] PDF generation handler — **print-CSS on FE (real)**; server-side stored-PDF = SERVICE_PLACEHOLDER
- [ ] Email-to-funder handler — SERVICE_PLACEHOLDER toast + optional GrantCommunication audit row (email infra exists but attachment generation does not)
- [ ] Bulk-generate query — optional; returns N document DTOs for per-page render
- [ ] Document-row persistence — NOT in V1 (query-only)

**Frontend Patterns Required (DOCUMENT):**
- [x] Report page shell — recipient (Grant) picker + Document Type toggle + optional period + Generate
- [x] Document component per type — FINANCIAL layout + IMPACT layout (A4 dimensions, header/body/footer)
- [x] Tenant letterhead (logo + address + brand color) from Company + OrganizationSetting
- [x] Print preview view
- [x] Export PDF via print-CSS (`window.print()` / print-to-PDF) — real, no service
- [x] Print view CSS (`@media print` — page-break-after between docs, page-break-inside-avoid on signature/blocks)
- [x] Email button (SERVICE_PLACEHOLDER)
- [x] Bulk per-record paging (optional)

---

## ⑥ UI/UX Blueprint

### 🎨 Visual Treatment Rules
- DOCUMENT area = centered max-width **A4 white card** with tenant brand at top; **no app chrome inside the document**.
- Amounts right-aligned, tabular figures; grant currency shown once in a summary band, not repeated per cell noise.
- Loading skeleton = **faded A4 page outline**, not generic shimmer.
- Export menu grouped: **Stakeholder** (Print, Download PDF, Email) — no analyst/Excel group (this is a document, not a data extract).
- Empty state diagnostic: "Grant is in Draft — documents generate once Approved," or "No accepted progress report yet — Impact narrative will be limited."

**Anti-patterns to refuse:** PDF via html2canvas screenshot (use print-CSS); hardcoded letterhead; summing mixed-currency rows raw; rendering InternalNotes; a bar-chart-heavy dashboard (this is a document, keep it typographic).

---

### 🅲 Block C — DOCUMENT

#### Recipient / Filter Panel

| # | Filter / Picker | Widget | Default | Required | Notes |
|---|-----------------|--------|---------|----------|-------|
| 1 | Grant | ApiSelect (search by GrantCode / GrantTitle / Funder) — single | — | YES | The grant the document is generated for; reuse existing grant list query |
| 2 | Document Type | segmented toggle (FINANCIAL / IMPACT / BOTH) | FINANCIAL | YES | Drives which layout renders |
| 3 | Reporting Period / As-of | date-range or "to-date" | to-date | NO | Financial doc scope; Impact ties to latest accepted GrantReport period |
| 4 | Template/Signatory | dropdown (authorized signatory name/designation) | tenant default | NO | Optional; from Company/settings |

**Bulk Mode** (optional): "Generate for all Active grants due this cycle" → renders N documents with page breaks; SERVICE_PLACEHOLDER if zipped-download requested.

#### Document Layout — FINANCIAL (matches PDF/print exactly)

```
┌─────────────────────────────────────────────────────────────┐  ← A4 (210×297mm)
│ [Tenant Logo]                         GRANT FINANCIAL REPORT │
│ {CompanyName}                         Grant: {GrantCode}     │
│ {Company Address, City, Country}      Period: {start–end}    │
│ Reg#: {RegistrationNumber}  Tax: {TaxId}   Generated: {date} │
├─────────────────────────────────────────────────────────────┤
│ To,  {FunderContactPersonName}                              │
│      {Funder org (GrantProgram / FunderWebsite)}            │
│      Funder Grant #: {FunderGrantNumber}                    │
│                                                             │
│ GRANT: {GrantTitle}    Stage: {stage badge}                 │
│ Awarded: {AwardedAmount CUR}   Currency: {grant currency}   │
├─────────────────────────────────────────────────────────────┤
│ ▸ FUNDING SUMMARY                                           │
│   Awarded ......... Received ....... Outstanding ......      │
│   Direct Spent .... Program Transferred .... Cash on Hand .. │
│   Total Utilized .......... Utilization % .......           │
├─────────────────────────────────────────────────────────────┤
│ ▸ RECEIPTS  (one row per active GrantFundReceipt)           │
│   Date | Receipt# | Method | Amount(orig) | Amount(grant CUR)│
│   ... FX-normalized; footer total = Σ GrantCurrencyAmount    │
├─────────────────────────────────────────────────────────────┤
│ ▸ BUDGET vs ACTUAL  (one row per GrantBudgetLine)           │
│   Category | Budgeted | Spent | Variance | (admin flag)      │
│   footer totals; admin% advisory if >10%                    │
├─────────────────────────────────────────────────────────────┤
│ ▸ PROGRAM ALLOCATIONS & TRANSFERS (from funding requests)   │
│   Program | Allocated | Transferred | Drawn                 │
├─────────────────────────────────────────────────────────────┤
│ Prepared by {signatory} / {designation}      {tenant}       │
│ Page X of Y            Generated: {date}     {CompanyFooter} │
└─────────────────────────────────────────────────────────────┘
```

#### Document Layout — IMPACT

```
┌─────────────────────────────────────────────────────────────┐
│ [Tenant Logo]                            GRANT IMPACT REPORT │
│ {letterhead as above}                    Grant: {GrantCode}  │
├─────────────────────────────────────────────────────────────┤
│ {GrantTitle}   Program: {GrantProgram}                      │
│ Reporting period: {latest accepted GrantReport period}      │
│ Compliance: {complianceRate}%  ({accepted}/{due} reports)   │
├─────────────────────────────────────────────────────────────┤
│ ▸ EXECUTIVE SUMMARY        {Grant.ExecutiveSummary OR        │
│                             latest GrantReport.ExecutiveSummary}│
│ ▸ PROBLEM & SOLUTION       {ProblemStatement / ProposedSolution}│
│ ▸ EXPECTED OUTCOMES        {ExpectedOutcomes}               │
│ ▸ SUSTAINABILITY           {SustainabilityPlan}            │
├─────────────────────────────────────────────────────────────┤
│ ▸ KEY DELIVERABLES (from latest accepted GrantReport)       │
│   Deliverable | Target | Current | Progress% | Narrative    │
│   render ProgressPercent as a bar                           │
├─────────────────────────────────────────────────────────────┤
│ ▸ IMPACT STORIES           {GrantReport.ImpactStories}      │
│ ▸ BENEFICIARIES SERVED     {rollup / target — see §⑫}       │
│ ▸ CHALLENGES & RISKS       {GrantReport.ChallengesAndRisks} │
├─────────────────────────────────────────────────────────────┤
│ ▸ GRANT TIMELINE (optional, from GrantStageHistory)         │
│   {date} → {stage}  {notes}                                 │
├─────────────────────────────────────────────────────────────┤
│ {signature block} {footer as above}                         │
└─────────────────────────────────────────────────────────────┘
```

| Block | Position | Content |
|-------|----------|---------|
| Header | top, full-width | Tenant logo (left) + document title (right) + issuer address + grant code/period + generated date |
| Recipient | top-body | "To," + FunderContactPersonName + funder program/website + FunderGrantNumber |
| Body (Financial) | body | Funding summary band → Receipts ledger → Budget-vs-actual → Program allocations |
| Body (Impact) | body | Narrative sections → Deliverables (KPI bars) → Impact stories → Beneficiaries → Challenges → Timeline |
| Signature | bottom-body | Authorized signatory + designation |
| Footer | bottom, full-width | Page X of Y + generation date + CompanyFooter/tagline |

**Per-Record Paging** (bulk/BOTH): `page-break-after: always` between documents; `page-break-inside: avoid` on summary band + signature.

**Tenant Branding**: logo + primary/secondary color from `OrganizationSetting` BRANDING group; issuer identity from `Company`.

#### Export Actions

| Action | Format | Handler | Notes |
|--------|--------|---------|-------|
| Print | print-CSS | `window.print()` | REAL — always feasible |
| Download PDF | .pdf | print-CSS → browser print-to-PDF | REAL — NOT html2canvas; server-side stored PDF = SERVICE_PLACEHOLDER |
| Email to Funder | email + PDF | reuse grant funder-comm path | SERVICE_PLACEHOLDER (attachment gen missing) + write GrantCommunication audit row (Direction=OUTBOUND_FUNDER) |
| Bulk Download (zip) | .zip | async + storage | SERVICE_PLACEHOLDER |

#### User Interaction Flow (DOCUMENT)
1. User opens screen → Grant picker + Document Type → Generate disabled until a grant is picked.
2. Picks grant + type → clicks Generate → document renders on screen (A4 preview) with letterhead + data.
3. Reviews → clicks Print or Download PDF → print-CSS layout renders → file saved (real).
4. Clicks Email to Funder → confirm dialog → SERVICE_PLACEHOLDER toast + audit row written.
5. (Optional) picks BOTH → both docs render stacked with a page break for print.

### Shared blocks

#### Page Header & Breadcrumbs
| Element | Content |
|---------|---------|
| Breadcrumb | CRM › Grants › Report Generation |
| Page title | Grant Report Generation |
| Subtitle | "Generate funder-facing Financial and Impact reports for a grant." |
| Right actions | (none / Help) |

#### Empty / Loading / Error States
| State | Trigger | UI |
|-------|---------|----|
| Initial | page load | "Pick a grant and document type, then Generate." |
| Loading | after Generate | faded A4 page skeleton |
| Empty | grant not eligible / no data | diagnostic (e.g. "Grant is in Draft — documents generate once Approved") |
| Error | query fails | error card + retry |

#### Print View CSS (`@media print`)
- Hide filter panel + page header actions + nav/sidebar; document expands to full page width.
- `page-break-after: always` between documents; `page-break-inside: avoid` on summary band + signature.

---

## ⑦ Substitution Guide

> **First DOCUMENT REPORT in PSS 2.0 — this sets the canonical convention.** On completion, maintainer replaces this block with a real substitution table and updates `_REPORT.md` header + `_COMMON.md`.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| GrantDocument | GrantDocument | Report class name |
| grantDocument | grantDocument | camelCase var/field |
| grant | grant | DB schema |
| GrantBusiness | GrantBusiness | Backend group |
| CRM_GRANT | CRM_GRANT | Parent menu |
| crm/grant/grantdocument | crm/grant/grantdocument | FE route |

---

## ⑧ File Manifest

### Backend Files — DOCUMENT (query-only)
| # | File | Path |
|---|------|------|
| 1 | Document DTO(s) | Base.Application/Schemas/GrantSchemas/GrantDocumentSchemas.cs (GrantDocumentDto + FinancialSection + ImpactSection + IssuerDto + FunderBlockDto) |
| 2 | Get Document Query (single) | Base.Application/Business/GrantBusiness/GrantDocuments/DocumentQuery/GetGrantDocument.cs |
| 3 | (Optional) Bulk Query | .../GrantDocuments/DocumentQuery/GetGrantDocumentsBulk.cs |
| 4 | Email handler (PLACEHOLDER) | .../GrantDocuments/DocumentExport/EmailGrantDocument.cs (reuses grant comm path; writes GrantCommunication) |
| 5 | (Optional) ComplianceRate write-back mutation | .../GrantDocuments/DocumentCommand/UpdateGrantComplianceRate.cs |
| 6 | Queries endpoint | Base.API/EndPoints/Grant/Queries/GrantDocumentQueries.cs |
| 7 | Mutations endpoint (email/compliance) | Base.API/EndPoints/Grant/Mutations/GrantDocumentMutations.cs |

> **NO** entity / DbSet / Mapping / migration changes — query-only. Reuse GetGrantFinancialSummary/GetGrantUtilization/GetGrantFundingRequests logic; reuse `IOrgSettingsService` for branding.

### Frontend Files — DOCUMENT
| # | File | Path |
|---|------|------|
| 1 | DTO Types | Pss2.0_Frontend/src/domain/entities/grant-service/GrantDocumentDto.ts |
| 2 | GQL Query | Pss2.0_Frontend/src/infrastructure/gql-queries/grant-queries/GrantDocumentQuery.ts |
| 3 | Report Page | .../page-components/crm/grant/grantdocument/report-page.tsx |
| 4 | Recipient/Grant Picker | .../grantdocument/components/document-controls.tsx |
| 5 | Financial Document | .../grantdocument/components/financial-document.tsx |
| 6 | Impact Document | .../grantdocument/components/impact-document.tsx |
| 7 | Letterhead (shared) | .../grantdocument/components/document-letterhead.tsx |
| 8 | Print Styles | .../grantdocument/components/print-styles.module.css |
| 9 | Page Config | Pss2.0_Frontend/src/presentation/pages/crm/grant/grantdocument.tsx |
| 10 | Route Page | Pss2.0_Frontend/src/app/[lang]/crm/grant/grantdocument/page.tsx |

### Frontend Wiring Updates
| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | GRANTDOCUMENT_REPORT operations config |
| 2 | operations-config.ts | import + register |
| 3 | sidebar menu config | menu entry under CRM_GRANT |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: Grant Report Generation
MenuCode: GRANTDOCUMENT
ParentMenu: CRM_GRANT
Module: CRM
MenuUrl: crm/grant/grantdocument
GridType: REPORT

MenuCapabilities: READ, EXPORT, PRINT, EMAIL, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT, PRINT, EMAIL

GridFormSchema: SKIP
GridCode: GRANTDOCUMENT
---CONFIG-END---
```

> DOCUMENT with query-only source → no CREATE/REISSUE (nothing persisted in V1). EMAIL capability present (handler is SERVICE_PLACEHOLDER). GridFormSchema SKIP (custom UI).

---

## ⑩ Expected BE→FE Contract

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getGrantDocument` | GrantDocumentDto | grantId: Int!, documentType: String (FINANCIAL/IMPACT/BOTH), periodStart: DateTime?, periodEnd: DateTime? |
| `getGrantDocumentsBulk` (optional) | [GrantDocumentDto] | filter (stage/dueCycle) |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `emailGrantDocument` | { grantId, documentType, toEmail, subject, bodyHtml } | Boolean (PLACEHOLDER; writes GrantCommunication) |
| `updateGrantComplianceRate` (optional) | { grantId, complianceRate } | Boolean |

**GrantDocumentDto (shape):**
| Field | Type | Notes |
|-------|------|-------|
| grantId | int | |
| grantCode / grantTitle / grantProgram | string | |
| stageName | string | |
| currencyCode | string | grant currency |
| funder | { personName, email, phone, website, funderGrantNumber } | To-block (from Grant denorm fields) |
| issuer | { companyName, address, city, country, regNumber, taxId, logoUrl, primaryColorHex, footer, signatoryName, signatoryDesignation } | letterhead |
| financial | { awardedAmount, totalReceived, outstanding, totalSpent, programTransferred, cashOnHand, totalUtilized, utilizationPct, adminPct, receipts:[{date,receiptCode,method,amount,currencyCode,grantCurrencyAmount}], budgetLines:[{category,budgeted,spent,variance,isAdmin}], programAllocations:[{programName,allocated,transferred,drawn}] } | reuse existing computations |
| impact | { executiveSummary, problemStatement, proposedSolution, expectedOutcomes, sustainabilityPlan, impactStories, challengesAndRisks, reportingPeriodLabel, deliverables:[{name,target,current,previous,progressPercent,narrative}], beneficiariesServed, timeline:[{date,stage,notes}] } | narrative + KPIs |
| compliance | { complianceRate, acceptedReports, dueReports, nextReportDueDate, reportingStatus } | NEW compute |
| generatedAt | DateTime | stamp on server (UTC) |

> `impact` / `financial` may be null when `documentType` excludes it. **InternalNotes / RejectionReason / INTERNAL communications are NOT in this DTO.**

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/crm/grant/grantdocument`

**Functional Verification (DOCUMENT — Full E2E):**
- [ ] Grant picker + Document Type render; Generate disabled until a grant is picked
- [ ] Generate → FINANCIAL document renders matching A4 layout (letterhead / funder / summary / receipts / budget-vs-actual / programs / signature / footer)
- [ ] Generate → IMPACT document renders matching A4 layout (narrative / deliverables KPI bars / impact stories / beneficiaries / challenges / timeline)
- [ ] Tenant logo + address + brand color pulled from Company + OrganizationSetting (not hardcoded)
- [ ] Every amount FX-normalized to grant currency; Financial totals reconcile with Grant detail financial summary
- [ ] ComplianceRate computed + displayed (accepted/due); "No reports due yet" when due=0
- [ ] Over-spent budget lines + admin>10% advisory render
- [ ] Print preview matches on-screen render (no app chrome)
- [ ] Download PDF produces identical layout via print-CSS (NOT a screenshot)
- [ ] Email to Funder → SERVICE_PLACEHOLDER toast + GrantCommunication row (Direction=OUTBOUND_FUNDER) written
- [ ] BOTH type → both docs render with page break
- [ ] Role-scoped: only in-scope grants pickable; InternalNotes/RejectionReason absent from network payload
- [ ] Draft/Rejected grant → diagnostic empty-state, no document

**DB Seed Verification:**
- [ ] Menu appears under CRM › Grants
- [ ] Page renders on freshly-seeded DB

---

## ⑫ Special Notes & Warnings

**Universal:**
- Read-only derivation — no in-place editing, no persisted report row in V1.
- `GridFormSchema: SKIP`; tenant + role scoping in BE; reuse Grant read authorization.
- **Footer/summary totals over the full grant set** (all receipts/expenses), computed server-side via the existing engine — do NOT recompute divergently.

**Design decisions (locked from planning):**
- **query-only, NO migration** — deliberately avoids a new table so this pass needs zero user-owned migration. (A `report-row-table` to persist/version issued PDFs is a clean future enhancement — log as ISSUE if the business wants an issued-document audit.)
- **Reuse the financial engine** — `GetGrantDocument` composes `GetGrantFinancialSummary` / `GetGrantUtilization` / `GetGrantFundingRequests` so the document reconciles exactly with the Grant detail screen. A parallel aggregation that drifts from those numbers is the top failure mode here.
- **FX rule (WI-3)** — all rollups use `GrantCurrencyAmount ?? Amount`; never sum raw mixed-currency `Amount`.
- **ComplianceRate** — computed at query time from GrantReport lifecycle (accepted/due). This absorbs the deferred ComplianceRate item. Optional `updateGrantComplianceRate` mutation persists it back to `Grant.ComplianceRate` (column already exists — no migration); V1 can display-only.
- **UTC** — `generatedAt` and any date math use `DateTime.UtcNow` (Kind=Utc) per `db-utc-only`.
- **Two document types (V1), extensible enum** — FINANCIAL is pure engine derivation; IMPACT depends on a latest **accepted** GrantReport (#63). If none accepted, render grant-level narrative fields + show "No accepted progress report yet." `BOTH` = combined packet. **User decision (planning): FINANCIAL + IMPACT + BOTH are sufficient for V1**; do NOT add more types now, but architect `documentType` as an open enum (one layout component + one query branch per type).
- **Future document-type roadmap (NOT V1 — design for, don't build):**
  - `PERIOD_PROGRESS` — a polished PDF of ONE **accepted** #63 GrantReport (period-scoped: its ExecutiveSummary + FinancialLines + Deliverables + ImpactStories), distinct from our cumulative live-derived docs. Most likely next.
  - `AWARD_LETTER` — issued at Approve (lifecycle artifact; belongs to the approve flow, referenced here only for enum-shape awareness).
  - `COMPLETION_CERTIFICATE` — issued at grant closure.
  - `COMPLIANCE_SUMMARY` — only for `AuditRequired` grants; depends on audit-trail maturity.
- **Doc-audit decision (planning): query-only, NOTHING persisted (LOCKED).** No report-row table, no migration. Email-send still writes a GrantCommunication audit row. If issued-document versioning is later required, that's the `report-row-table` upgrade in DOC-3.
- **Do NOT collide with #63** — `GrantReportQueries.cs`/`GrantReportMutations.cs` already exist for the FLOW screen. Use the **GrantDocument** name for all new files/endpoints.

**Beneficiaries-served (Impact doc) — known gap:**
- No direct Grant→Case/BeneficiaryServiceLog FK. Chain is `Grant ← ProgramFundingSource.GrantId → Program`. `Program` stores `TargetBeneficiaries`/`MaximumCapacity` but no actual-served count. V1: show the target + a "actual served count pending" note, OR roll up enrollments under the linked Program(s) if a count query exists. Confirm at build; if no clean count, ship target-only and log ISSUE.

**Service Dependencies (SERVICE_PLACEHOLDER — full UI built, handler mocked):**
- ⚠ **Download PDF (server-side/stored)** — on-screen + print-CSS + browser print-to-PDF is REAL. A server-generated, stored PDF is placeholder (no PDF service). Do NOT html2canvas.
- ⚠ **Email to Funder** — grant email infra (`SendComposedEmailForCompanyAsync`, GrantCommunication) exists for logging, but generating + attaching the PDF server-side does not. Handler writes the audit row + toasts; attachment is placeholder.
- ⚠ **Bulk zip download** — async job + storage layer missing; UI shows a queue indicator + placeholder toast.

---

## ⑬ Build Log (append-only)

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| DOC-1 | planning | LOW | Impact | Beneficiaries-served has no direct grant FK; V1 may ship target-only (§⑫). | OPEN |
| DOC-2 | planning | LOW | Export | Server-side stored PDF + email attachment are SERVICE_PLACEHOLDER (print-CSS PDF is real). | OPEN |
| DOC-3 | planning | LOW | Audit | No persisted issued-document row in V1 (query-only). Future report-row-table if issued-doc audit needed. | DEFERRED |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-07-10 — BUILD — COMPLETED

- **Scope**: Full build (BE + FE), single `/build-screen #178` session by two agents. Backend was generated first (backend-developer agent): `GetGrantDocument` query (composes GetGrantFinancialSummary/GetGrantUtilization/GetGrantFundingRequests via IMediator), `EmailGrantDocument`/`UpdateGrantComplianceRate` mutations, `GrantDocumentSchemas.cs`, `GrantDocumentQueries.cs`/`GrantDocumentMutations.cs` endpoints, and `sql-scripts-dyanmic/GrantDocument-sqlscripts.sql` (menu-only seed, GridFormSchema SKIP). BE `dotnet build` (Base.API + transitive deps) PASSED, 0 errors. NO entity/DbSet/EF-config/mapping/migration touched — query-only as mandated. Frontend generated second (frontend-developer agent) against the finalized BE GraphQL contract.
- **Files touched**:
  - FE (created): `src/domain/entities/grant-service/GrantDocumentDto.ts`; `src/infrastructure/gql-queries/grant-queries/GrantDocumentQuery.ts`; `src/infrastructure/gql-mutations/grant-mutations/GrantDocumentMutations.ts`; `src/presentation/components/page-components/crm/grant/grantdocument/report-page.tsx`; `.../grantdocument/index.tsx`; `.../grantdocument/components/document-controls.tsx`; `.../grantdocument/components/financial-document.tsx`; `.../grantdocument/components/impact-document.tsx`; `.../grantdocument/components/document-letterhead.tsx`; `.../grantdocument/components/email-document-dialog.tsx`; `.../grantdocument/components/constants.ts`; `.../grantdocument/components/print-styles.module.css`; `src/presentation/pages/crm/grant/grantdocument.tsx`; `src/app/[lang]/crm/grant/grantdocument/page.tsx`
  - FE (modified — barrel wiring): `src/domain/entities/grant-service/index.ts`; `src/infrastructure/gql-queries/grant-queries/index.ts`; `src/infrastructure/gql-mutations/grant-mutations/index.ts`; `src/presentation/pages/crm/grant/index.ts`
  - DB: none this session (pre-existing seed file not modified)
- **Deviations from spec**: (1) Signatory dropdown filter (§⑥ recipient panel #4) not built — `getGrantDocument` takes no signatory override argument; `issuer.signatoryName/Designation` is already the tenant default on the DTO, nothing to wire against. (2) Bulk zip download skipped entirely per spec (optional, SERVICE_PLACEHOLDER not built). (3) `grant-service-entity-operations.ts` deliberately NOT touched — this screen calls `useLazyQuery`/`useMutation` directly (same pattern as `grantreporting/view-page.tsx`), never routes through the `AdvancedDataTable`/`FlowDataTable` operations-registry abstraction, so a `getById`-shaped registration would be dead config.
- **Known issues opened**: None (DOC-1/DOC-2/DOC-3 from planning remain OPEN/DEFERRED as documented — no new issues).
- **Known issues closed**: None.
- **Next step**: (none — COMPLETED). Follow-up suggestion for a future session: confirm the `GRANTDOCUMENT` menu row is present in the seeded DB (sql-scripts-dyanmic file exists but menu-row execution wasn't re-verified against a live DB this session) and run the full E2E checklist in §⑪.
