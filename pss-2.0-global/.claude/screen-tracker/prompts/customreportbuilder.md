---
screen: CustomReport
registry_id: 96
module: Report & Audit
status: COMPLETED
scope: FULL
screen_type: CONFIG
config_subtype: DESIGNER_CANVAS
storage_pattern: definition-list
save_model: save-all
complexity: High
new_module: NO
planned_date: 2026-05-13
completed_date: 2026-05-13
last_session_date: 2026-05-13
---

> **⚠ READ THIS FIRST — Type re-classification + scope correction**
>
> 1. **Registry says Type=FLOW, Scope=ALIGN, Status=PARTIAL.** That's stale.
>    - FE existence: only `app/[lang]/reportaudit/reports/customreportbuilder/page.tsx` exists, and it renders the
>      generic `<UnderConstruction />` stub. No `customreportbuilder` page-component folder, no Zustand store,
>      no view-page.
>    - BE existence: zero — no `CustomReport*.cs` entity, schema, command, query, EF config, or mapping.
>      (Verified via Grep/Glob on Base.Domain, Base.Application, Base.Infrastructure, Base.API.)
>    - Effective scope: **FULL** build (BE + FE + DB seed). The registry "ALIGN" label should be updated
>      to "FULL" when the build completes.
>
> 2. **Type is CONFIG / DESIGNER_CANVAS, not FLOW.** The mockup has no grid, no `?mode=new/edit/read`
>    URL pattern, and no list of N CustomReport rows. It is a three-pane builder:
>    *Available Fields palette* → *Selected-Fields + Filters + Group/Aggregate + Sort canvas* → *Live Preview*.
>    Per `_TEMPLATE.md` detection cues, this is `CONFIG / DESIGNER_CANVAS` (palette + canvas + properties + preview).
>    The "list of custom reports" surface is provided externally by Screen #99 Report Catalog (SKIP_DASHBOARD
>    in registry — out of scope for this build).
>
> 3. **Live execution (Preview / Run Full Report / Export) is a SERVICE_PLACEHOLDER**, same constraint as
>    #27 SavedFilter ISSUE-1: "DynamicQueryBuilder service does not yet exist." Build the full UI; the
>    Preview / Run / Export handlers return mocked rows + toast. Persisting the definition is fully real
>    — only the executor is mocked.
>
> 4. **Canonical precedent**: This is the **first DESIGNER_CANVAS screen** in the codebase.
>    `_CONFIG.md §⑦` currently lists "TBD — first builder sets convention." After this build completes,
>    update `_CONFIG.md` to point future designer-canvas screens at `customreportbuilder.md` as canonical.

---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type identified: DESIGNER_CANVAS — palette + canvas + properties + preview)
- [x] Business context read (NGO admin/analyst persona; ad-hoc reporting; persists definitions reusable across runs)
- [x] Storage model identified (definition-list — N CustomReport rows per Company)
- [x] Save model chosen (save-all — explicit "Save Report" + "Save As New" buttons in mockup)
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (analysis pre-baked in prompt §①-④; agents validated structure)
- [x] Solution Resolution complete (CONFIG/DESIGNER_CANVAS confirmed; save-all confirmed; SERVICE_PLACEHOLDER strategy aligned w/ SavedFilter ISSUE-1)
- [x] UX Design finalized (split-pane 40/60, 6 always-visible numbered sections, palette/canvas Section 3, live preview right pane)
- [x] User Approval received (2026-05-13 — "approve build as planned — if possible you can use sonnet modal" → all agents spawned on Sonnet)
- [x] Backend code generated (19 files)
- [x] Backend wiring complete (IReportDbContext, ReportDbContext, DecoratorReportModules, ReportMappings — GlobalUsing already had ReportModels)
- [x] Frontend code generated (25 files across 3 spawns)
- [x] Frontend wiring complete (route page replaced, pages barrel updated, page-config added, page-component index barrel exported)
- [x] DB Seed script generated (CustomReportBuilder-sqlscripts.sql — 652 lines: MenuCapabilities + RoleCapabilities + REPORTCATEGORY/REPORTENTITY/REPORTENTITYRELATED/REPORTAGGFN/REPORTFILTEROP MasterData + sett.Grids + sett.Fields + sett.GridFields + 72 CustomReportFieldMetadata starter rows)
- [x] Registry updated to COMPLETED + status field corrected (PARTIAL→COMPLETED, Type re-classification noted)

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — `/{lang}/reportaudit/reports/customreportbuilder` loads (no UnderConstruction stub)
- [ ] DESIGNER_CANVAS sub-type checks:
  - [ ] Canvas + palette + properties (filters/group/sort) panel + preview pane render
  - [ ] Click on a palette field checkbox → field appears in "Selected Fields" canvas; auto-numbered
  - [ ] Drag-handle reorder in Selected Fields list persists order in saved JSON
  - [ ] Up/Down arrow buttons reorder Selected Fields
  - [ ] × (remove) un-selects field both in canvas and in palette checkbox
  - [ ] Field search in palette filters visible fields by label (case-insensitive)
  - [ ] Primary Entity radio toggle re-loads the field palette (different fields per entity)
  - [ ] Include-Related checkboxes add/remove fields from related-entity groups in palette
  - [ ] Add Filter row appends a {field, operator, value} row; Remove × deletes it
  - [ ] Operator options change based on selected field's data type (date → between/before/after/in-last-N; number → equals/gt/lt/between; string → is/contains/one-of/not)
  - [ ] Group By: None / single-grouping / multi-grouping (Add Grouping button)
  - [ ] Aggregations rows: one row per numeric/date selected field with aggregate function dropdown (Sum/Avg/Count/Min/Max)
  - [ ] Subtotals + Grand Total checkboxes toggle visibility in preview
  - [ ] Sort: multi-column ordered list with direction; reorder; remove
  - [ ] Preview pane toggle (Flat / Grouped) renders correct shape
  - [ ] Refresh button re-fetches preview (debounced 800ms loading spinner)
  - [ ] Save persists full DefinitionJson; reload restores exact state
  - [ ] Save As New duplicates current state under a new CustomReportId
  - [ ] Validation: ReportName required, PrimaryEntityCode required, at least 1 field selected, group-aggregate combos coherent
  - [ ] Export dropdown (Excel/PDF/CSV) triggers SERVICE_PLACEHOLDER toast
  - [ ] Run Full Report button triggers SERVICE_PLACEHOLDER toast (real: would navigate to Generate Report engine)
- [ ] Empty / loading / error states render (no saved report yet, loading preview, executor error)
- [ ] DB Seed:
  - [ ] Menu visible at Report & Audit → Reports → Custom Builder
  - [ ] REPORTCATEGORY MasterData seeded (Fundraising, Contacts, Communication, Organization, Field Collection, Administration)
  - [ ] REPORTENTITY MasterData seeded (GLOBALDONATION, CONTACT, COMMUNICATION, FIELDCOLLECTION, EVENT, CAMPAIGN, PLEDGE, RECURRINGDONATION) — each with EntityCode in DataValue
  - [ ] REPORTAGGFN MasterData seeded (SUM, AVG, COUNT, MIN, MAX)
  - [ ] REPORTFILTEROP MasterData seeded (per data-type — listed in §④)
  - [ ] CustomReportFieldMetadata table seeded with starter rows per entity (Donation Date, Amount, Currency, Payment Mode, Receipt Number, Status, Created Date, Full Name, Email, Phone, City, Country, Tags, Purpose Name, Purpose Category — matches mockup §3 palette)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: CustomReport (Custom Report Builder)
Module: Report & Audit (`REPORTAUDIT`)
Schema: `rep` (existing Reports schema — reuses `rep."Reports"` peers)
Group: `Report` (existing `Base.Application/Business/ReportBusiness/`)

Business: The Custom Report Builder is the **definition-authoring surface** for ad-hoc, user-built reports
in the NGO platform. The persona is the BUSINESSADMIN (typically an analyst or operations lead) who needs
to produce a quarterly board summary, a campaign retrospective, or a city-level donor breakdown without
writing SQL or filing a request to engineering. They land on the page either with an empty canvas
(`?mode=new` default) or with an existing CustomReport loaded for editing (`?id=X`). They:
(1) name the report, optionally categorize it, (2) pick a primary entity from a fixed catalog
(Donations / Contacts / Communications / Field Collections / Events / Campaigns / Pledges / Recurring
Donations), (3) opt in to related-entity field groups (Contact details, Purpose details, Campaign
details, Payment details, Receipt details, Branch details), (4) toggle individual fields into a
selected-fields canvas (drag-reorder, remove), (5) add filter rows (field / operator / value),
(6) configure group-by + aggregations + subtotal/grand-total toggles, (7) configure multi-column sort,
(8) watch a live preview pane update on Refresh. They Save (persist the current canvas state to an
existing CustomReportId), Save As New (clone under a new Id), Run Full Report (handoff to the existing
Generate Report engine — currently SERVICE_PLACEHOLDER toast), or Export (Excel / PDF / CSV — also
SERVICE_PLACEHOLDER until DynamicQueryBuilder lands).

**Edit cadence**: low-to-medium. A typical tenant builds 5-30 custom reports over the platform's lifetime
and re-runs them often, but rarely re-edits the definition once it's working. Build cadence concentrates
in onboarding + each new initiative.

**Risk profile**: a malformed canvas (no fields selected, invalid group/agg combo, filter referencing a
field that isn't in the chosen entity) must be blocked **at save**, not deferred to runtime. A bad
definition that saves but throws at execute is a poor UX and clutters Report Execution Logs.

**Downstream dependencies**: a saved CustomReport is intended to surface in Screen #99 Report Catalog
(SKIP — out of scope), and Run/Export will eventually route through the existing `ReportDataTable` /
`GenerateReportDataTable` engine that Generate Report (#154 COMPLETED) already uses. The current
build does NOT wire that integration — it's covered by the SERVICE_PLACEHOLDER note in §⑫.

**What makes this UX unique**: not a tabbed settings page, not a list-of-N CRUD, not a single-form
config. It's a **palette + canvas + properties** designer with a **second canvas pane** (Live Preview)
that's the closest thing the platform has to a Notion / Airtable / Looker Studio "build a view"
experience. The visual treatment must reflect that — not generic form chrome.

> **Why this section is heavier than other types**: CONFIG screens have no canonical layout — the design
> is derived from the business case. This screen's §⑥ is the development spec.

---

## ② Storage Model

> **Consumer**: BA Agent → Backend Developer

**Storage Pattern**: `definition-list` — N CustomReport rows per Company, one row per saved definition.
Each row holds the full canvas state as JSON (compact, single-blob `DefinitionJson`) plus indexed
top-level fields (ReportName, PrimaryEntityCode, CategoryId) for filtering in the Report Catalog and
search.

### Tables

Primary table: `rep."CustomReports"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CustomReportId | int | — | PK | — | Primary key (identity) |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (FK; NOT a form field — set from HttpContext) |
| ReportName | string | 200 | YES | — | Display name (e.g. "Monthly Board Report") |
| ReportCode | string | 64 | YES | — | UPPER snake-case code — generated from ReportName on Create; user-editable |
| Description | string | 1000 | NO | — | Free-text description (textarea) |
| CategoryId | int? | — | NO | app.MasterData (TypeCode=REPORTCATEGORY) | Category lookup |
| PrimaryEntityCode | string | 64 | YES | — | Hard-coded enum: GLOBALDONATION / CONTACT / COMMUNICATION / FIELDCOLLECTION / EVENT / CAMPAIGN / PLEDGE / RECURRINGDONATION (validated in handler against REPORTENTITY MasterData) |
| IncludeRelatedJson | string (jsonb) | — | NO | — | Array of related-entity codes: `["CONTACT","PURPOSE","CAMPAIGN","PAYMENT","RECEIPT","BRANCH"]` — order doesn't matter |
| DefinitionJson | string (jsonb) | — | YES | — | Full canvas state — see "DefinitionJson Shape" below |
| PreviewRowLimit | int | — | NO (default 25) | — | First-N rows shown in preview pane |
| Visibility | string | 16 | YES (default PRIVATE) | — | `PRIVATE` (only creator) / `SHARED` (all roles with READ on CUSTOMREPORTBUILDER) — mirrors SavedFilter convention |
| IsActive | bool | — | — (inherited) | — | Soft-delete flag |
| LastRunAt | DateTime? | — | NO | — | Last time the definition was executed (Run Full Report) — updated by SERVICE_PLACEHOLDER handler |
| LastRunByUserId | int? | — | NO | auth.Users | Last executor |

> Audit columns (`CreatedBy`, `CreatedDate`, `ModifiedBy`, `ModifiedDate`) inherited from `Entity` base.

**Unique constraint**: `(CompanyId, ReportCode)` — ReportCode is unique within tenant.

**Indices**:
- `(CompanyId, IsActive)` — Report Catalog list filter
- `(CompanyId, CategoryId)` — Report Catalog category filter
- `(CompanyId, PrimaryEntityCode)` — Report Catalog entity filter

**DefinitionJson Shape** (validated by FluentValidation in BE Update/Create handler):

```jsonc
{
  "selectedFields": [
    { "key": "donation.donationDate", "displayOrder": 1, "label": "Donation Date" },
    { "key": "donation.amount",      "displayOrder": 2, "label": "Amount" }
    // ... up to N entries
  ],
  "filters": [
    { "fieldKey": "donation.donationDate", "operator": "between",   "value": "2026-04-01..2026-04-30" },
    { "fieldKey": "donation.amount",       "operator": "gt",        "value": "100" },
    { "fieldKey": "donation.paymentMode",  "operator": "oneOf",     "value": "Cash,Cheque,BankTransfer" }
  ],
  "grouping": {
    "groupBy": [ { "fieldKey": "donation.purposeName", "displayOrder": 1 } ],
    "aggregations": [
      { "fieldKey": "donation.amount", "fn": "SUM" },
      { "fieldKey": "donation.donationDate", "fn": "COUNT" }
    ],
    "showSubtotals":  true,
    "showGrandTotal": true
  },
  "sort": [
    { "fieldKey": "donation.amount",      "direction": "DESC" },
    { "fieldKey": "donation.purposeName", "direction": "ASC"  }
  ]
}
```

**Field Metadata table** (read-only seed — defines what's selectable per entity):

Table: `rep."CustomReportFieldMetadata"`

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| CustomReportFieldMetadataId | int | — | PK | — |
| EntityCode | string | 64 | YES | GLOBALDONATION / CONTACT / etc. — must match REPORTENTITY MasterData |
| FieldGroupCode | string | 64 | YES | `DONATION`, `CONTACT`, `PURPOSE`, `CAMPAIGN`, `PAYMENT`, `RECEIPT`, `BRANCH` (matches Include-Related codes) |
| FieldGroupLabel | string | 100 | YES | "Donation Fields", "Contact Fields", "Purpose Fields" (display in palette accordion) |
| FieldKey | string | 100 | YES | Dotted-path key — `donation.donationDate`, `contact.fullName` (matches DefinitionJson) |
| FieldLabel | string | 100 | YES | "Donation Date", "Full Name" (palette + canvas display) |
| DataType | string | 32 | YES | `date` / `datetime` / `number` / `currency` / `string` / `boolean` / `enum` (drives operator dropdown + aggregate eligibility) |
| IsAggregatable | bool | — | YES | True for number/currency/date → eligible for Sum/Avg/Count/Min/Max selection |
| IsGroupable | bool | — | YES | True for string/enum/date(bucketed) → eligible for Group-By |
| DisplayOrder | int | — | YES | Sort order within field group |
| DefaultSelected | bool | — | NO (default false) | If true, palette pre-checks this field when entity is first chosen |

> No CompanyId — this is **platform-level metadata**, identical across tenants. Seeded once via DB seed script.

**No child tables.** The definition is fully self-contained in `DefinitionJson`.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` and navigation properties) + Frontend Developer (ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| CategoryId | MasterData (TypeCode=REPORTCATEGORY) | `Base.Domain/Models/ApplicationModels/MasterData.cs` | `GetMasterDataByTypeCode(typeCode: "REPORTCATEGORY")` | DataValue (label in `DataValue` column) | `MasterDataResponseDto` |
| CompanyId | Company | `Base.Domain/Models/ApplicationModels/Company.cs` | (not a FE form field — HttpContext-scoped) | — | — |
| LastRunByUserId | User | `Base.Domain/Models/AuthenticationModels/User.cs` | (not a form field — audit only) | — | — |

**Designer-canvas axis sources** (palette/canvas content — read-only lookups):

| Axis | Source | GQL Query | Order Field | Read-only Filter |
|------|--------|-----------|-------------|-------------------|
| Primary entity options | MasterData (TypeCode=REPORTENTITY) | `GetMasterDataByTypeCode(typeCode: "REPORTENTITY")` | DisplayOrder | `IsActive=true` |
| Related-entity option toggles | MasterData (TypeCode=REPORTENTITYRELATED, parent=PrimaryEntityCode) | `GetMasterDataByTypeCode(typeCode: "REPORTENTITYRELATED")` (filter client-side by `Parent=PrimaryEntityCode`) | DisplayOrder | `IsActive=true` |
| Palette fields (per entity) | CustomReportFieldMetadata | `GetCustomReportFieldMetadataByEntity(entityCode: $entityCode)` | `FieldGroupCode, DisplayOrder` | — |
| Aggregate functions | MasterData (TypeCode=REPORTAGGFN) | `GetMasterDataByTypeCode(typeCode: "REPORTAGGFN")` | DisplayOrder | — |
| Filter operators (per data type) | MasterData (TypeCode=REPORTFILTEROP) — variant TypeCode per data-type bucket | `GetMasterDataByTypeCode(typeCode: "REPORTFILTEROP")` (filter client-side by `Parent=dataType`) | DisplayOrder | — |

> **Why MasterData over hard-coded enums**: Category list and Operator list are tenant-customizable in the
> NGO platform pattern (see SavedFilter, GlobalDonation, OrganizationalUnit — all use MasterData FKs for
> small lookup sets). REPORTENTITY is also MasterData even though the C# code switch-cases on the
> EntityCode string — keeping it in MasterData means a new entity can be added by a seed script + handler
> case-branch, not a schema migration.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Cardinality Rules:**
- `(CompanyId, ReportCode)` must be unique. On Create: ReportCode auto-generated from ReportName (UPPER + snake-case + trim) and conflict-resolved with `_2`, `_3`, … suffix. On Update: user-editable but uniqueness re-checked.
- No constraint on number of CustomReport rows per tenant.

**Required Field Rules (Save):**
- `ReportName` required, 3-200 chars, trim whitespace
- `PrimaryEntityCode` required, must be in REPORTENTITY MasterData
- `DefinitionJson.selectedFields` must have ≥ 1 entry (cannot save a report with zero fields)
- `Visibility` defaults to `PRIVATE`

**Conditional Rules:**
- If `DefinitionJson.grouping.groupBy.length > 0` then `DefinitionJson.grouping.aggregations.length` must be ≥ 1 (group without aggregation is malformed)
- If `DefinitionJson.grouping.aggregations[i].fn ∈ {SUM, AVG, MIN, MAX}` then the referenced `fieldKey` must resolve to a `DataType ∈ {number, currency, date, datetime}` in `CustomReportFieldMetadata`
- If `DefinitionJson.grouping.aggregations[i].fn == COUNT` then any data type is allowed
- If `DefinitionJson.grouping.groupBy[i].fieldKey` references a field, that field's `IsGroupable` must be true
- If a filter references a field, the operator must be compatible with the field's data type (`between` only for date/number; `oneOf` for string/enum; etc.)
- Every `fieldKey` in `selectedFields`, `filters`, `grouping`, `sort` must exist in `CustomReportFieldMetadata` for the chosen `PrimaryEntityCode` OR for an entity in `IncludeRelatedJson`
- Removing a related-entity toggle that has fields still referenced in `selectedFields/filters/grouping/sort` must auto-strip those references (with confirm toast: "Removing Contact details will drop 3 selected fields. Continue?")

**Filter Operator Catalog** (seeded in `MasterData` under TypeCode=REPORTFILTEROP, with `Parent=dataType`):

| Data Type | Allowed Operators (DataValue) | Label |
|-----------|------------------------------|-------|
| date / datetime | `between`, `before`, `after`, `inLastNDays`, `is` | "is between", "is before", "is after", "is in last N days", "is on" |
| number / currency | `equals`, `gt`, `lt`, `between`, `notEquals` | "equals", "is greater than", "is less than", "is between", "is not" |
| string | `is`, `contains`, `oneOf`, `notEquals`, `startsWith` | "is", "contains", "is one of", "is not", "starts with" |
| enum | `is`, `oneOf`, `notEquals` | "is", "is one of", "is not" |
| boolean | `is` | "is" |

**Sensitive Fields**: none. CustomReport DefinitionJson is config-data, not credentials.

**Read-only / System-controlled Fields:**
- `ReportCode`: editable on Create, displayed read-only on Update (matches SavedFilter convention)
- `LastRunAt`, `LastRunByUserId`: system-set by Run handler; never editable
- `CompanyId`: HttpContext-scoped; never sent from FE

**Dangerous Actions** (require confirm):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Delete CustomReport | Soft-delete (IsActive=false) | Modal "Delete '{ReportName}'? This will remove it from Report Catalog." | Standard audit-trail entry |
| Reset Definition | Clears all canvas state (selectedFields/filters/grouping/sort) on the open report | Modal "Reset definition? Saved state on the server is not affected until Save." | None — purely client-side until Save |
| Change PrimaryEntity | Wipes all selectedFields/filters/grouping/sort (they reference the old entity's fields) | Modal "Switching primary entity will clear all selected fields and filters. Continue?" | None |

**Role Gating**:
| Role | READ | CREATE | MODIFY | DELETE | RUN/EXPORT |
|------|------|--------|--------|--------|-----------|
| BUSINESSADMIN | ✓ | ✓ | ✓ | ✓ | ✓ |
| (other roles) | gated per Role-Capability matrix; default closed | — | — | — | — |

**Workflow**: None. There is no draft → publish state. Save is immediate persistence. Visibility (`PRIVATE`/`SHARED`) is the only sharing primitive.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: CONFIG
**Config Sub-type**: `DESIGNER_CANVAS`
**Storage Pattern**: `definition-list`
**Save Model**: `save-all`

**Reason**: The mockup shows two explicit save buttons ("Save Report", "Save As New") at the bottom action bar — not autosave-per-keystroke and not save-per-section. Autosave is wrong here because the user iterates (toggle field on / off / on, add/remove filters) and a half-built definition is not meaningful to persist intermediate states. Save-per-section is wrong because all 6 sections are conceptually one canvas — saving Section 3 (Fields) without Section 4 (Filters) is incoherent. Save-all matches the Looker Studio / Power BI / Notion mental model the persona expects.

**Backend Patterns Required** (DESIGNER_CANVAS variant):

- [x] `GetAllCustomReportList` query (paginated list — for Report Catalog #99 to consume later; this screen does not list)
- [x] `GetCustomReportById` query — full canvas state for `?id=X` load
- [x] `CreateCustomReport` mutation — initial Save when `?mode=new`
- [x] `UpdateCustomReport` mutation — subsequent Save
- [x] `DeleteCustomReport` mutation — soft-delete (`IsActive=false`)
- [x] `ToggleCustomReport` mutation — IsActive toggle (standard pattern, may be unused on this screen)
- [x] `SaveAsNewCustomReport` mutation — clone current definition under new Id + new ReportName + new ReportCode
- [x] `PreviewCustomReport` query — returns mocked rows + count (SERVICE_PLACEHOLDER until DynamicQueryBuilder lands)
- [x] `RunCustomReport` mutation — SERVICE_PLACEHOLDER (would invoke DynamicQueryBuilder + write ReportExecutionLog row)
- [x] `ExportCustomReport` query — SERVICE_PLACEHOLDER (returns mocked download URL toast)
- [x] `GetCustomReportFieldMetadataByEntity` query — palette content per entity
- [x] DefinitionJson FluentValidator (enforces all rules in §④)
- [x] Tenant scoping (CompanyId from HttpContext)

**Frontend Patterns Required** (DESIGNER_CANVAS variant):

- [x] Custom split-pane page (NOT RJSF modal, NOT view-page 3-mode; NOT FlowDataTable / AdvancedDataTable)
- [x] Left 40% config panel — 6 vertically-stacked sections (NOT tabs, NOT accordion — sections always visible, scroll within panel)
- [x] Right 60% preview panel — Flat/Grouped toggle + table + Refresh button
- [x] Three-pane semantics within the left config panel:
  - **Palette**: Section 3 "Available Fields" list (search + checkbox tree by field group)
  - **Canvas**: Section 3 "Selected Fields" ordered list (drag-handle + up/down + remove)
  - **Properties**: Sections 4 (Filters), 5 (Group & Aggregate), 6 (Sort)
- [x] Live preview pane — secondary canvas; refreshes via PreviewCustomReport query (debounced 800ms loading)
- [x] Bottom sticky action bar — Cancel / Export dropdown / Run Full Report / Save As New / Save Report
- [x] Zustand store for canvas state (selectedFields, filters, grouping, sort, primaryEntity, includeRelated, previewRows, isDirty, isLoadingPreview)
- [x] Confirm dialog for: change PrimaryEntity, remove related-entity toggle with referenced fields, Delete
- [x] Sticky page header (title + "My Custom Reports" back-link to Report Catalog #99)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: This section is the design spec. Implement EXACTLY this layout — the mockup is the truth.

### 🎨 Visual Uniqueness — this screen vs other CONFIG screens

This is **NOT** a tabbed settings page (like Company Settings #75) and **NOT** a typical save-per-section form. The visual treatment must communicate "designer / build a thing" rather than "configure system behavior":

- **Two-panel split** is the primary visual signature — 40/60 with a vertical divider, both panels independently scrollable
- **Numbered step circles** (1-6) on each section title in the config panel — communicates a progressive build flow even though steps are not strictly sequential
- **Accent color** for the report-builder primary action color is **purple `#7c3aed`** (per mockup `--report-accent`) — distinct from the platform's default accent. Use this for: step circles, primary CTA buttons, selected-field highlights, Refresh button focus state. Do NOT inherit the default `--accent` color across the board.
- **Palette items** look distinct from **selected-field items** — palette is a flat checkbox list inside a bordered scroll-box; selected fields are larger rows with drag-handles and arrow buttons.
- **Preview pane** uses a **white card on slate background** (`background: #f8fafc`) to visually separate "the thing being built" (preview) from the "controls used to build it" (config panel which is white).
- **Bottom action bar** is sticky, white, and visually weighty — multiple buttons including a dropdown — communicates "I can do several things with this report now"

### Page Layout (the master spec)

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ 🔧 Custom Report Builder                                          [← My Custom Reports] │  ← Page Header (sticky)
│    Build and save custom reports with flexible field selection                          │
├──────────────────────────────────┬──────────────────────────────────────────────────────┤
│                                  │                                                      │
│   CONFIG PANEL (40% / min 360px) │   PREVIEW PANEL (60%, slate bg)                     │
│   (white, scroll-y)              │   (scroll-y)                                         │
│                                  │                                                      │
│   ① Report Info                  │   📋 Preview  [first 25 rows]                       │
│      Name / Description / Cat    │      Showing 25 of 342 results                       │
│                                  │      ┌──Flat──Grouped──┐  [↻ Refresh]               │
│   ② Data Source                  │                                                      │
│      Primary Entity (radio)      │   ┌──────────────────────────────────────────────┐ │
│      Include Related (checks)    │   │ <FLAT view OR GROUPED view>                  │ │
│                                  │   │ ... table with optional subtotals/grand-tot. │ │
│   ③ Select Fields                │   └──────────────────────────────────────────────┘ │
│      Search                      │                                                      │
│      Available Fields (palette)  │                                                      │
│      Selected Fields (canvas)    │                                                      │
│                                  │                                                      │
│   ④ Filters                      │                                                      │
│      [field][op][val][×]         │                                                      │
│      [+ Add Filter]              │                                                      │
│                                  │                                                      │
│   ⑤ Group & Aggregate            │                                                      │
│      Group By dropdown(s)        │                                                      │
│      Aggregations (per field)    │                                                      │
│      Subtotals / Grand Total     │                                                      │
│                                  │                                                      │
│   ⑥ Sort                         │                                                      │
│      [field][dir][×]             │                                                      │
│      [+ Add Sort]                │                                                      │
│                                  │                                                      │
├──────────────────────────────────┴──────────────────────────────────────────────────────┤
│  [Cancel]                                    [↓ Export ▾] [▶ Run Full Report]          │  ← Action Bar (sticky bottom)
│                                              [Save As New] [💾 Save Report]            │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

**Responsive (< 992px)**: panels stack vertically, config-panel max-height 50vh, preview max-height 50vh.

### Section Definitions (config panel — left side)

| # | Section Title | Icon (Phosphor / FA from mockup) | Step Badge | Save Mode | Role Gate |
|---|---------------|-----------------------------------|------------|-----------|-----------|
| 1 | Report Info | `fa-info-circle` (purple) | "1" purple circle | save-all (sticky bottom) | BUSINESSADMIN |
| 2 | Data Source | `fa-database` (purple) | "2" purple circle | save-all | BUSINESSADMIN |
| 3 | Select Fields | `fa-list` (purple) | "3" purple circle | save-all | BUSINESSADMIN |
| 4 | Filters | `fa-filter` (purple) | "4" purple circle | save-all | BUSINESSADMIN |
| 5 | Group & Aggregate | `fa-layer-group` (purple) | "5" purple circle | save-all | BUSINESSADMIN |
| 6 | Sort | `fa-sort` (purple) | "6" purple circle | save-all | BUSINESSADMIN |

Sections are always visible (vertical-stack), separated by a 1px border with bottom-padding. Each section title is small (12px, uppercase, letter-spaced) and contains a 20px circular purple step badge.

### Section 1 — Report Info

| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| ReportName | text | "" | required, 3-200 chars, trim | placeholder: "Enter report name" |
| Description | textarea (2 rows, resize-vertical, min 60px) | "" | max 1000 chars | placeholder: "Describe this report..." |
| CategoryId | select (ApiSelect via MasterData TypeCode=REPORTCATEGORY) | "Fundraising" (per mockup) | — | options: Fundraising / Contacts / Communication / Organization / Field Collection / Administration |

### Section 2 — Data Source

| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| PrimaryEntityCode | radio-chip-group (entity-radio-label per mockup) | `GLOBALDONATION` | required | options sourced from MasterData TypeCode=REPORTENTITY. Selected chip: purple background, white text. Hover: purple border. Changing this triggers confirm modal (wipes selectedFields/filters/grouping/sort) |
| IncludeRelatedJson | checkbox list (one row per related-entity) | `["CONTACT","PURPOSE"]` per mockup | — | options sourced from MasterData TypeCode=REPORTENTITYRELATED filtered by Parent=PrimaryEntityCode. Unchecking with referenced fields triggers confirm modal |

Related-entity list per primary entity (seed data — see §② Field Metadata seeding):

| Primary | Allowed Related Toggles |
|---------|-------------------------|
| GLOBALDONATION | Contact, Purpose, Campaign, Payment, Receipt, Branch |
| CONTACT | OrganizationalUnit, Tags, Donations-summary |
| COMMUNICATION | Contact, Template, Campaign |
| FIELDCOLLECTION | Ambassador, Contact, Receipt |
| EVENT | Campaign, Ticketing |
| CAMPAIGN | Donations-summary |
| PLEDGE | Contact, Campaign |
| RECURRINGDONATION | Contact, Purpose |

### Section 3 — Select Fields (the palette + canvas)

**Available Fields (palette)** — sub-block:
- "Available Fields" label (small bold)
- Search input (rounded, `fa-search` left icon optional) — filters visible items by label, case-insensitive, debounced 200ms
- Bordered scroll container (`max-height: 180px`, padding 8px)
- Inside: alternating `field-group-label` (uppercase 11px, slate-secondary, bottom-border separator) and `field-check` rows (checkbox + label, 13px)
- Field groups: dynamically built from `CustomReportFieldMetadata` rows filtered by `EntityCode = PrimaryEntityCode` + `FieldGroupCode IN IncludeRelatedJson + 'self'`
- Field-check state mirrors `selectedFields` array — check adds to canvas, uncheck removes from canvas

**Selected Fields (canvas)** — sub-block (right below palette, NOT a separate section):
- "Selected Fields (drag to reorder)" label (small bold)
- Bordered list container (rounded, overflow-hidden)
- Each `selected-field-item` row:
  - `fa-grip-vertical` drag handle (slate-200, cursor-grab)
  - Auto-numbered position (`1`, `2`, … bold slate-secondary 11px)
  - Field name (flex-1, 13px, medium weight)
  - Action buttons cluster (right-aligned):
    - `fa-arrow-up` — moves item up
    - `fa-arrow-down` — moves item down
    - `fa-times` (red on hover) — remove item + uncheck in palette
  - Hover state: subtle slate background

**Drag behavior**: use react-dnd or native drag-and-drop with a single-axis (vertical) constraint. Drop reorders the array. Persisted on Save (NOT autosaved).

### Section 4 — Filters

Each filter row is a horizontal flex of 3 controls + delete:

```
[field-dropdown 130px] [operator-dropdown 120px] [value-input flex-1] [× remove]
```

- **field-dropdown**: options sourced from currently-selected `selectedFields` plus any pinnable system fields (Status, Created Date). Choosing a field reads its `DataType` from metadata.
- **operator-dropdown**: options sourced from REPORTFILTEROP MasterData filtered by `Parent = field.DataType`. Changes when field changes.
- **value-input**: render varies by operator:
  - `between` → two date pickers OR two number inputs (joined by an em-dash) — in mockup currently rendered as a single text input "Apr 1, 2026 — Apr 30, 2026" for V1 simplicity
  - `inLastNDays` → number input with suffix "days"
  - `oneOf` → text input accepting comma-separated values (V1; eventually multi-chip selector)
  - everything else → single appropriate input (text / number / date / select for enums)
- **× delete**: removes the row from `filters[]`

`[+ Add Filter]` button (dashed-border, purple-hover) appends a blank filter row.

**Initial state (per mockup)**: 3 pre-filled rows on a new "blank" canvas — actually NO, mockup shows 3 filter rows but those are illustrative of a built report. For `?mode=new` the filters list is EMPTY. For `?mode=edit&id=X` the filters are reconstructed from DefinitionJson.filters.

### Section 5 — Group & Aggregate

**Group By** sub-block:
- Single-row primary group dropdown — options sourced from `selectedFields` filtered by `IsGroupable=true`
- `[+ Add Grouping]` button appends another dropdown row (multi-level grouping)
- Default: None (no grouping)

**Aggregations** sub-block:
- One row per `selectedFields` entry where `IsAggregatable=true` — auto-rendered, no manual add
- Each row: `{FieldLabel}:` (12px bold, min-width 120px) + aggregate function dropdown (Sum / Avg / Count / Min / Max — sourced from MasterData TypeCode=REPORTAGGFN)
- If `IsAggregatable=false`, field doesn't appear here

**Display Toggles** sub-block:
- Horizontal flex row with 2 checkboxes:
  - `showSubtotals` (default true if grouping is on, hidden otherwise)
  - `showGrandTotal` (default true)
- Both with purple accent color

### Section 6 — Sort

Each sort row:
```
[field-dropdown 150px] [direction-dropdown 130px] [× remove]
```

- **field-dropdown**: options sourced from `selectedFields` array
- **direction-dropdown**: Ascending / Descending (hard-coded, no MasterData needed)
- **× delete**: removes from `sort[]`
- `[+ Add Sort]` button — appends blank row

**Multi-column sort**: list order = priority. First row = primary sort, second = secondary, etc.

### Preview Panel (right side, 60% / slate background)

**Preview Header** (top of panel):
- Left: `fa-table` purple icon + "Preview" title + small purple-pill badge "first {previewRowLimit} rows" + meta text below ("Showing 25 of 342 results")
- Right: View toggle (Flat / Grouped — purple-bg-active) + Refresh button (white-bordered, purple-hover)

**Refresh behavior**: clicking Refresh fires `PreviewCustomReport` query with current canvas state. Button morphs to `<spinner> Loading...` for 800ms (placeholder) then restores. (Real impl would await query.)

**Flat view** (when toggle = Flat):
- Card-styled bordered table
- Header row: per `selectedFields[i].label` in order
- Body rows: from PreviewCustomReport.rows (each row is a dict keyed by FieldKey)
- Footer (if showGrandTotal AND grouping is off): grand-total row in purple-bg / white text
- "... N more rows" italic centered row at bottom if `rows.length < total`

**Grouped view** (when toggle = Grouped):
- Card-styled bordered table
- Header row: `[GroupByField, …aggregate columns]` — e.g. `[Purpose, Total Amount, Avg Amount, Count, Cities]` per mockup
- Body rows: one row per group bucket, group field as first cell, then aggregate values per Aggregations config
- Subtotal rows (if `showSubtotals` AND nested grouping): slate-bg subtotal row between groups
- Grand Total row (if `showGrandTotal`): purple-bg row at bottom

**Empty state**:
- "No fields selected" — when `selectedFields.length === 0`: large icon + helper text "Select at least one field to preview your report" + cta-link to scroll to Section 3
- "No matching rows" — when query returns 0 rows: icon + "Your filters return no results. Try adjusting them."

**Loading state**:
- Skeleton table matching the shape of the current view (Flat or Grouped) — NOT a generic shimmer rectangle

**Error state**:
- Card with `fa-exclamation-circle` red icon + error message + Retry button

### Page Header

| Element | Content |
|---------|---------|
| Title | `<i class="fas fa-wrench" style="color: purple"></i> Custom Report Builder` (24px, bold) |
| Subtitle | "Build and save custom reports with flexible field selection" (14px, slate-secondary) |
| Right Action | `← My Custom Reports` — outline button linking to Report Catalog (`/reportaudit/reports/reportcatalog`) — note: target route may not exist yet (#99 is SKIP); link still wires there for forward-compat |

### Action Bar (sticky bottom)

| Action | Position | Style | Permission | Confirmation | Handler |
|--------|----------|-------|------------|--------------|---------|
| Cancel | right-aligned | tertiary (white bg, slate border, slate text) | always | if dirty → "Discard unsaved changes?" modal | navigate back to Report Catalog |
| Export ▾ (dropdown) | right-aligned | outline-purple | READ | none — opens dropdown | dropdown items: Excel / PDF / CSV — each triggers `ExportCustomReport` (SERVICE_PLACEHOLDER toast) |
| Run Full Report | right-aligned | outline-purple | READ | none | `RunCustomReport` (SERVICE_PLACEHOLDER toast — eventual nav to Generate Report `/reportaudit/reports/generatereport?customReportId=X`) |
| Save As New | right-aligned | outline-purple | CREATE | none | prompts new ReportName (or auto-suggest `{originalName} (Copy)`) → `SaveAsNewCustomReport` mutation |
| Save Report | right-aligned | primary-purple | MODIFY (if existing id) OR CREATE (if new) | none if valid; show inline validation errors per field if invalid | `Update*` or `Create*` mutation |

**Dirty indicator**: faint "Unsaved changes" pill next to action bar when canvas state diverges from last-loaded definition.

### User Interaction Flow (DESIGNER_CANVAS / this screen)

1. User clicks **Reports → Custom Builder** in sidebar → lands at `/reportaudit/reports/customreportbuilder` (no `?id`).
2. Empty canvas renders: ReportName empty, PrimaryEntity defaults to `GLOBALDONATION`, IncludeRelated defaults to `[CONTACT, PURPOSE]`, palette populated with Donation fields + Contact/Purpose fields, selectedFields empty, no filters, no grouping, no sort. Preview pane shows "No fields selected" empty state.
3. User types name "Monthly Board Report", selects Category "Fundraising".
4. User checks fields in palette → each check appends to selectedFields canvas (auto-numbered). Preview pane auto-refreshes (debounced 800ms).
5. User reorders Selected Fields via drag-handle or up/down arrows.
6. User clicks **+ Add Filter** → blank row appears → picks field, operator, value. Each change debounces preview refresh.
7. User picks **Group By: Purpose Name** → preview pane View toggle defaults to "Grouped"; aggregations rows render for numeric/date selected fields; user picks Sum on Amount, Count on Donation Date.
8. User adds Sort: Amount DESC, Purpose Name ASC.
9. Preview pane updates throughout (debounced 800ms).
10. User clicks **Save Report** → validation runs (BE FluentValidator) → on success: toast "Report saved", URL changes to `?id=X`, dirty pill clears.
11. User clicks **Save As New** → modal asks for new name → clones to new Id → toast "Saved as new report".
12. User clicks **Run Full Report** → SERVICE_PLACEHOLDER toast "Run pending DynamicQueryBuilder integration. Report Id {X} saved successfully and will run when execution engine ships."
13. User clicks **Export → CSV** → SERVICE_PLACEHOLDER toast "Export pending DynamicQueryBuilder integration. Saved definition is available for export when ready."

---

## ⑦ Substitution Guide

> First DESIGNER_CANVAS screen — sets canonical reference. Closest existing precedents:
> - **SavedFilter (#27 COMPLETED)** — most semantically similar (entity-scoped definition with JSON canvas + SERVICE_PLACEHOLDER executor). Use SavedFilter's BE structure as the base pattern for CustomReport's entity / EF config / Schemas / Mutations / Queries. SavedFilter is FLOW-typed but its `GetById` / `Create` / `Update` / `Delete` / JSON-blob-validation can be adapted directly.
> - **GenerateReport (#154 COMPLETED)** — sibling screen; demonstrates how the `rep` schema's Report engine is wired. Custom Report Builder will eventually feed back into `ReportDataTable` (out of scope this build).

| Canonical (SavedFilter) | → This Entity (CustomReport) | Context |
|-------------------------|------------------------------|---------|
| SavedFilter | CustomReport | Entity / class name |
| savedFilter | customReport | Variable / field name (camelCase) |
| SAVEDFILTER | CUSTOMREPORT | Constants / capability keys |
| saved-filter | custom-report | kebab-case (FE folders use `customreportbuilder/`) |
| notify | rep | DB schema (SavedFilter is in `notify`; CustomReport is in `rep`) |
| Notify | Report | Backend group folder name (`NotifyBusiness` → `ReportBusiness`) |
| SavedFilters | CustomReports | Table name (plural) |
| FilterJson | DefinitionJson | Canvas-state JSON column |
| FilterCode | ReportCode | Unique tenant code |
| FilterRecipientTypeId | PrimaryEntityCode | Entity-source-type field (FK in SavedFilter; string-enum here) |
| FilterCategoryId | CategoryId | Category FK (both MasterData) |
| FILTERCATEGORY | REPORTCATEGORY | MasterData TypeCode |
| crm/communication/savedfilter | reportaudit/reports/customreportbuilder | FE route |
| `CRM_COMMUNICATION` | `RA_REPORTS` | Parent menu code |

---

## ⑧ File Manifest

### Backend Files (DESIGNER_CANVAS / definition-list pattern)

| # | File | Path |
|---|------|------|
| 1 | Entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ReportModels/CustomReport.cs` |
| 2 | Field Metadata Entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ReportModels/CustomReportFieldMetadata.cs` |
| 3 | EF Config (CustomReport) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/ReportConfigurations/CustomReportConfiguration.cs` |
| 4 | EF Config (Metadata) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/ReportConfigurations/CustomReportFieldMetadataConfiguration.cs` |
| 5 | Schemas (DTOs) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/ReportSchemas/CustomReportSchemas.cs` |
| 6 | GetAll Query | `PSS_2.0_Backend/.../Business/ReportBusiness/CustomReports/Queries/GetCustomReport.cs` (returns GetAllCustomReportList) |
| 7 | GetById Query | `PSS_2.0_Backend/.../Business/ReportBusiness/CustomReports/Queries/GetCustomReportById.cs` |
| 8 | GetFieldMetadata Query | `PSS_2.0_Backend/.../Business/ReportBusiness/CustomReports/Queries/GetCustomReportFieldMetadataByEntity.cs` |
| 9 | Preview Query | `PSS_2.0_Backend/.../Business/ReportBusiness/CustomReports/Queries/PreviewCustomReport.cs` (SERVICE_PLACEHOLDER) |
| 10 | Create Command | `PSS_2.0_Backend/.../Business/ReportBusiness/CustomReports/Commands/CreateCustomReport.cs` |
| 11 | Update Command | `PSS_2.0_Backend/.../Business/ReportBusiness/CustomReports/Commands/UpdateCustomReport.cs` |
| 12 | Delete Command | `PSS_2.0_Backend/.../Business/ReportBusiness/CustomReports/Commands/DeleteCustomReport.cs` |
| 13 | Toggle Command | `PSS_2.0_Backend/.../Business/ReportBusiness/CustomReports/Commands/ToggleCustomReport.cs` |
| 14 | SaveAsNew Command | `PSS_2.0_Backend/.../Business/ReportBusiness/CustomReports/Commands/SaveAsNewCustomReport.cs` |
| 15 | Run Command | `PSS_2.0_Backend/.../Business/ReportBusiness/CustomReports/Commands/RunCustomReport.cs` (SERVICE_PLACEHOLDER) |
| 16 | Export Query | `PSS_2.0_Backend/.../Business/ReportBusiness/CustomReports/Queries/ExportCustomReport.cs` (SERVICE_PLACEHOLDER) |
| 17 | DefinitionJson Validator | `PSS_2.0_Backend/.../Business/ReportBusiness/CustomReports/Validators/CustomReportDefinitionValidator.cs` (FluentValidation — enforces §④ rules on DefinitionJson) |
| 18 | Mutations endpoint | `PSS_2.0_Backend/.../Base.API/EndPoints/Report/Mutations/CustomReportMutations.cs` |
| 19 | Queries endpoint | `PSS_2.0_Backend/.../Base.API/EndPoints/Report/Queries/CustomReportQueries.cs` |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IReportDbContext.cs` (or `IApplicationDbContext.cs` if Report-DbContext is consolidated) | `DbSet<CustomReport> CustomReports`, `DbSet<CustomReportFieldMetadata> CustomReportFieldMetadata` |
| 2 | `ReportDbContext.cs` (or the equivalent partial) | same DbSet declarations |
| 3 | `DecoratorProperties.cs` → `DecoratorReportModules` | `CustomReport = "CUSTOMREPORTBUILDER"` constant |
| 4 | `ReportMappings.cs` | Mapster mapping for CustomReportRequestDto ↔ CustomReport (+ Response) |
| 5 | `GlobalUsing.cs` (Base.Application, Base.Infrastructure, Base.API as needed) | `using Base.Domain.Models.ReportModels;` already present — verify |
| 6 | EF Migration | `Add-Migration AddCustomReportBuilder_2026MMDD` |

### Frontend Files (DESIGNER_CANVAS variant)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/report-service/CustomReportDto.ts` |
| 2 | GQL Queries | `PSS_2.0_Frontend/src/infrastructure/gql-queries/report-queries/CustomReportQuery.ts` (GetCustomReportById, GetCustomReportFieldMetadataByEntity, PreviewCustomReport, ExportCustomReport) |
| 3 | GQL Mutations | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/report-mutations/CustomReportMutation.ts` (Create, Update, Delete, Toggle, SaveAsNew, Run) |
| 4 | Zustand Store | `PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reports/customreportbuilder/custom-report-store.ts` |
| 5 | Builder Page (root) | `PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reports/customreportbuilder/builder-page.tsx` |
| 6 | Section 1 — Report Info | `…/customreportbuilder/sections/report-info-section.tsx` |
| 7 | Section 2 — Data Source | `…/customreportbuilder/sections/data-source-section.tsx` |
| 8 | Section 3 — Fields (palette + canvas) | `…/customreportbuilder/sections/fields-section.tsx` |
| 9 | Field Palette component | `…/customreportbuilder/components/field-palette.tsx` |
| 10 | Selected Fields List component | `…/customreportbuilder/components/selected-fields-list.tsx` |
| 11 | Section 4 — Filters | `…/customreportbuilder/sections/filters-section.tsx` |
| 12 | Filter Row component | `…/customreportbuilder/components/filter-row.tsx` |
| 13 | Section 5 — Group & Aggregate | `…/customreportbuilder/sections/group-aggregate-section.tsx` |
| 14 | Aggregation Row component | `…/customreportbuilder/components/aggregation-row.tsx` |
| 15 | Section 6 — Sort | `…/customreportbuilder/sections/sort-section.tsx` |
| 16 | Sort Row component | `…/customreportbuilder/components/sort-row.tsx` |
| 17 | Preview Panel | `…/customreportbuilder/components/preview-panel.tsx` |
| 18 | Flat Preview Table | `…/customreportbuilder/components/preview-flat-table.tsx` |
| 19 | Grouped Preview Table | `…/customreportbuilder/components/preview-grouped-table.tsx` |
| 20 | Action Bar | `…/customreportbuilder/components/action-bar.tsx` |
| 21 | Confirm Modals (entity-change, related-toggle, delete) | `…/customreportbuilder/components/confirm-modals.tsx` |
| 22 | Save-As-New Modal | `…/customreportbuilder/components/save-as-new-modal.tsx` |
| 23 | Index barrel | `…/customreportbuilder/index.tsx` |
| 24 | Page Config | `PSS_2.0_Frontend/src/presentation/pages/reportaudit/reports/customreportbuilder.tsx` |
| 25 | Route Page (REPLACE stub) | `PSS_2.0_Frontend/src/app/[lang]/reportaudit/reports/customreportbuilder/page.tsx` |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | Sidebar menu | Already registered (`CUSTOMREPORTBUILDER` under `RA_REPORTS`) — verify capability gating works |
| 2 | `pages/reportaudit/reports/index.ts` | Add `export * from './customreportbuilder';` |
| 3 | `useAccessCapability` gating | Component reads `menuCode: "CUSTOMREPORTBUILDER"` for READ/CREATE/MODIFY/DELETE |

### DB Seed Files

| # | File | Purpose |
|---|------|---------|
| 1 | `sql-scripts-dynamic/CustomReportBuilder-sqlscripts.sql` | Menu (already exists — verify) + Capabilities + Role-Capability + MasterData seeds (REPORTCATEGORY / REPORTENTITY / REPORTENTITYRELATED / REPORTAGGFN / REPORTFILTEROP) + CustomReportFieldMetadata starter rows for each PrimaryEntity (≈80 rows total) |
| 2 | GridFormSchema | **SKIP** — custom UI, not RJSF |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: Custom Builder
MenuCode: CUSTOMREPORTBUILDER
ParentMenu: RA_REPORTS
Module: REPORTAUDIT
MenuUrl: reportaudit/reports/customreportbuilder
GridType: CONFIG

MenuCapabilities: READ, CREATE, MODIFY, DELETE, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, EXPORT

GridFormSchema: SKIP
GridCode: CUSTOMREPORTBUILDER
---CONFIG-END---
```

> **Note**: Capability list includes `EXPORT` (mockup has Export dropdown). `DELETE` is needed even though the builder UI doesn't expose Delete — Report Catalog (#99) will delete CustomReports, and the capability needs to exist server-side. `READ` is the gate for the page; `CREATE` is the gate for new reports; `MODIFY` for edits.

---

## ⑩ Expected BE→FE Contract

**GraphQL Types:**
- Query type: `CustomReportQueries`
- Mutation type: `CustomReportMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getAllCustomReportList` | `[CustomReportResponseDto]` (paginated) | `pageNo: Int, pageSize: Int, search: String, categoryId: Int, primaryEntityCode: String, visibility: String` |
| `getCustomReportById` | `CustomReportResponseDto` | `customReportId: Int!` |
| `getCustomReportFieldMetadataByEntity` | `[CustomReportFieldMetadataResponseDto]` | `entityCode: String!` |
| `previewCustomReport` | `PreviewCustomReportResultDto` | `customReportId: Int (optional — if absent, use definitionJson arg)`, `definitionJson: String, primaryEntityCode: String!, includeRelatedJson: String, previewRowLimit: Int` |
| `exportCustomReport` | `ExportCustomReportResultDto` | `customReportId: Int!, format: String! (EXCEL/PDF/CSV)` — SERVICE_PLACEHOLDER |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createCustomReport` | `CustomReportRequestDto` | `Int` (new CustomReportId) |
| `updateCustomReport` | `CustomReportRequestDto` (with CustomReportId) | `Int` (updated id) |
| `deleteCustomReport` | `customReportId: Int!` | `Int` |
| `toggleCustomReport` | `customReportId: Int!` | `Int` |
| `saveAsNewCustomReport` | `customReportId: Int!, newReportName: String!` | `Int` (new id) |
| `runCustomReport` | `customReportId: Int!` | `RunCustomReportResultDto` — SERVICE_PLACEHOLDER |

**Key DTO Shapes:**

```ts
interface CustomReportRequestDto {
  customReportId?: number | null;          // null/0 ⇒ Create; set ⇒ Update
  reportName: string;
  reportCode?: string | null;              // optional on Create (auto-generated); user-editable on Update
  description?: string | null;
  categoryId?: number | null;
  primaryEntityCode: string;               // "GLOBALDONATION" | "CONTACT" | ...
  includeRelatedJson?: string | null;      // JSON array of related-entity codes
  definitionJson: string;                  // JSON blob — see §② shape
  previewRowLimit?: number | null;         // default 25
  visibility: "PRIVATE" | "SHARED";
}

interface CustomReportResponseDto extends CustomReportRequestDto {
  isActive: boolean;
  categoryName?: string | null;
  primaryEntityLabel?: string | null;
  lastRunAt?: string | null;
  lastRunByUserName?: string | null;
  createdBy?: number;
  createdByName?: string | null;
  createdDate?: string;
  modifiedDate?: string | null;
}

interface CustomReportFieldMetadataResponseDto {
  customReportFieldMetadataId: number;
  entityCode: string;
  fieldGroupCode: string;
  fieldGroupLabel: string;
  fieldKey: string;
  fieldLabel: string;
  dataType: "date" | "datetime" | "number" | "currency" | "string" | "boolean" | "enum";
  isAggregatable: boolean;
  isGroupable: boolean;
  displayOrder: number;
  defaultSelected: boolean;
}

interface PreviewCustomReportResultDto {
  totalRows: number;             // mocked count (SERVICE_PLACEHOLDER)
  rows: Record<string, unknown>[];  // first N rows, keyed by FieldKey
  groupedRows?: Array<{          // when grouping is configured
    groupValues: Record<string, string>;
    aggregates: Record<string, unknown>;
    subRows?: Record<string, unknown>[];   // optional, when subtotals on
  }>;
  grandTotalRow?: Record<string, unknown>;
  message?: string | null;       // SERVICE_PLACEHOLDER text
}

interface RunCustomReportResultDto {
  customReportId: number;
  status: "PENDING" | "QUEUED" | "PLACEHOLDER";
  redirectUrl?: string | null;   // eventually → /reportaudit/reports/generatereport?customReportId=X
  message: string;               // SERVICE_PLACEHOLDER message
}

interface ExportCustomReportResultDto {
  customReportId: number;
  format: "EXCEL" | "PDF" | "CSV";
  status: "PENDING" | "PLACEHOLDER";
  downloadUrl?: string | null;
  message: string;
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/reportaudit/reports/customreportbuilder` (NOT UnderConstruction stub)
- [ ] No new TS errors introduced in this build (delta from baseline = 0)

**DESIGNER_CANVAS Functional Verification (Full E2E — MANDATORY):**

- [ ] Empty `?mode=new` canvas renders with defaults: PrimaryEntity=GLOBALDONATION, IncludeRelated=[CONTACT,PURPOSE], no selected fields, no filters, no grouping, no sort
- [ ] Palette renders Donation/Contact/Purpose field groups (per default IncludeRelated)
- [ ] Switching PrimaryEntity to CONTACT triggers confirm modal → on confirm: palette reloads with Contact fields + OrganizationalUnit/Tags related groups; selected fields wiped
- [ ] Toggling Include-Related "Campaign details" → palette gains Campaign field group; toggling off with referenced fields triggers confirm
- [ ] Palette search "Donation" filters list case-insensitive
- [ ] Click palette field → appears in Selected Fields canvas with auto-number
- [ ] Click palette field again (uncheck) → field disappears from canvas
- [ ] Drag-handle reorder works; up/down arrows reorder
- [ ] × button on canvas item removes + unchecks in palette
- [ ] Add Filter → blank row appears → choose field → operator dropdown updates per data-type → enter value
- [ ] Operator dropdown for a date field shows: is between / is before / is after / is in last N days / is on
- [ ] Operator dropdown for a number field shows: equals / is greater than / is less than / is between / is not
- [ ] Operator dropdown for a string field shows: is / contains / is one of / is not / starts with
- [ ] Remove × on filter row deletes it
- [ ] Group By dropdown populates from selectedFields filtered by IsGroupable
- [ ] Add Grouping appends a second-level group dropdown
- [ ] Aggregations rows auto-render per IsAggregatable selectedField
- [ ] Show Subtotals / Show Grand Total checkboxes toggle in preview
- [ ] Sort: Add Sort → new row → choose field + direction → reorder → remove
- [ ] Preview pane respects Flat / Grouped toggle
- [ ] Refresh button shows 800ms spinner placeholder then renders mocked rows (SERVICE_PLACEHOLDER)
- [ ] Save validates DefinitionJson; invalid (no fields, bad group/agg combo) blocks save with toast + inline error indicator on offending section
- [ ] Valid Save persists DefinitionJson; URL updates to `?id=X`; "Saved" toast fires
- [ ] Save As New: modal asks new name → BE clones definition under new id → toast + URL update to new `?id=Y`
- [ ] Cancel: if dirty → confirm modal → navigates to Report Catalog (or back; verify with sidebar history)
- [ ] Run Full Report: SERVICE_PLACEHOLDER toast with explanatory text
- [ ] Export Excel/PDF/CSV: each SERVICE_PLACEHOLDER toast
- [ ] Role-gated: user with READ but not MODIFY sees Save buttons disabled with tooltip "Read-only access"
- [ ] Role-gated: user without CREATE sees Save As New disabled

**Sub-type-specific UI checks:**
- [ ] Split-pane 40/60 visible on desktop ≥ 992px
- [ ] Below 992px panels stack vertically with 50vh each
- [ ] Purple accent (`#7c3aed`) is used consistently for: step badges, selected radio chip, selected field highlight, primary action button, Refresh focus, preview Refresh button hover
- [ ] Step circles (1-6) render at exactly 20px diameter with 10px font
- [ ] Palette scroll-box has fixed `max-height: 180px`
- [ ] Selected-field rows: drag handle (slate-200), auto-number, label, arrow up/down/×
- [ ] Bottom action bar sticky; visible on scroll
- [ ] Preview cards render with proper purple-bg group headers (when grouped) and purple-bg grand-total row

**DB Seed Verification:**
- [ ] Menu appears in sidebar: Report & Audit → Reports → Custom Builder
- [ ] REPORTCATEGORY MasterData seeded (≥ 6 rows)
- [ ] REPORTENTITY MasterData seeded (≥ 8 rows, one per primary entity option)
- [ ] REPORTENTITYRELATED MasterData seeded with Parent links
- [ ] REPORTAGGFN MasterData seeded (5 rows: SUM, AVG, COUNT, MIN, MAX)
- [ ] REPORTFILTEROP MasterData seeded (≥ 20 rows across 5 data-type buckets)
- [ ] CustomReportFieldMetadata seeded with at least the fields shown in mockup palette:
  - Donation: Donation Date, Amount, Currency, Payment Mode, Receipt Number, Status, Created Date
  - Contact: Full Name, Email, Phone, City, Country, Tags
  - Purpose: Purpose Name, Category
  - (Add equivalent starter rows for other primary entities — minimum 5 fields each)
- [ ] First-load (no `?id`) renders without 404 / null state

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Type / Scope re-classification (this build):**
- Registry says `Type=FLOW, Scope=ALIGN, Status=PARTIAL`. **This is incorrect** — see header note. Treat as `Type=CONFIG / DESIGNER_CANVAS`, `Scope=FULL`. Update registry on build completion (Type can stay as labeled if it serves another purpose, but Scope must move to FULL and Status to COMPLETED).
- The existing `app/[lang]/reportaudit/reports/customreportbuilder/page.tsx` renders `<UnderConstruction />` and must be **replaced**, not merged.

**Universal CONFIG warnings:**
- **CompanyId is NOT a form field** — set from HttpContext in Create/Update handler.
- **GridFormSchema = SKIP** — this is a custom UI, not RJSF.
- **No `view-page.tsx` 3-mode pattern** — this is single-mode designer; don't import FLOW view-page conventions.
- **Default seeding** is essential for `CustomReportFieldMetadata` — palette is empty without it.
- **Role gating happens at the BE** — FE button-disable is UX only.

**DESIGNER_CANVAS-specific gotchas:**
- **DefinitionJson must round-trip exactly** — save then reload must yield identical canvas state. Field order is meaningful; do not silently re-sort on read.
- **Properties pane (Filters/Group/Sort) updates the SAME DefinitionJson** as the canvas selected-fields list — keep one Zustand slice, not separate stores.
- **Allowing dangling references is a runtime trap** — if a selectedField references `donation.receiptNumber` but the user later switches PrimaryEntity to CONTACT, the field is no longer valid. The change-entity confirm modal must wipe selectedFields/filters/grouping/sort wholesale.
- **Don't render Aggregations rows for non-aggregatable fields** — silently skipping them is correct; rendering a disabled Sum dropdown for a string field is confusing.
- **Reorder must persist on Save** — easy to get wrong: array operations must mutate `displayOrder` not just JS array index.
- **Search input debouncing 200ms** — without it, every keystroke re-filters the palette and feels jittery.

**Module / module-instance notes:**
- The `rep` schema already exists (used by `Report`, `ReportExecutionLog`, `ReportRole`, `PowerBIReport`, `PowerBIUserMapping`). No new DbContext / schema-bootstrap work — only new DbSet declarations + EF migration.
- The `ReportBusiness` group already exists under `Base.Application/Business/`. New folders `CustomReports/` (Commands + Queries + Validators) slot in alongside existing `Reports/`, `PowerBIReports/`, `ReportExecutionLogs/`, `Files/`.
- `DecoratorReportModules` exists in `DecoratorProperties.cs` — add `public const string CustomReport = "CUSTOMREPORTBUILDER";` constant.

**Canonical-precedent note:**
- This is the **first DESIGNER_CANVAS screen** in the codebase. After build completion, update `_CONFIG.md §⑦` to point to `customreportbuilder.md` as the canonical reference, and update `_COMMON.md` Substitution Guide if there's a global table.

**Integration-with-existing-engine note:**
- `Run Full Report` is intended to eventually route to `/reportaudit/reports/generatereport?customReportId=X`, where the existing `ReportDataTable` / `GenerateReportDataTable` engine will execute the saved DefinitionJson. **This integration is OUT OF SCOPE for this build** because:
  1. The Generate Report engine currently consumes `rep."Reports"` rows (each bound to a stored procedure), not CustomReport rows (bound to a dynamic query).
  2. Adapting Generate Report to accept dynamic-query CustomReports requires the DynamicQueryBuilder service to exist.
  3. SavedFilter (#27) has the same blocker (ISSUE-1 — "DynamicQueryBuilder SERVICE_PLACEHOLDER blocks real Preview/MatchingCount").
- Document the future integration plan in the build session ISSUE list. Reference: `generatereport.md` (#154) for engine internals + `savedfilter.md` (#27 ISSUE-1) for the same DynamicQueryBuilder dependency.

**Service Dependencies** (UI-only — no backend service implementation):

> All Save / Create / Update / Delete / Toggle / SaveAsNew mutations are REAL — they persist to `rep."CustomReports"`. Only the execution-layer handlers are mocked.

- ⚠ **SERVICE_PLACEHOLDER: `PreviewCustomReport` query** — UI fully implemented (Refresh button, loading state, Flat/Grouped views, empty/error states). Handler returns mocked rows + count. Real impl pending `DynamicQueryBuilder` service.
- ⚠ **SERVICE_PLACEHOLDER: `RunCustomReport` mutation** — UI fully implemented (button + toast). Handler returns `{ status: "PLACEHOLDER", message: "Execution engine pending" }`. Real impl: invoke DynamicQueryBuilder, write `ReportExecutionLog` row, optionally redirect to Generate Report.
- ⚠ **SERVICE_PLACEHOLDER: `ExportCustomReport` query** — UI fully implemented (dropdown + 3 format options). Handler returns mock URL + placeholder toast text. Real impl: invoke DynamicQueryBuilder → render output via Excel/PDF/CSV writer → store in `rep."Files"` table → return download URL.

**SavedFilter cross-reference**: SavedFilter ISSUE-1 (DynamicQueryBuilder placeholder) is the same blocker. When DynamicQueryBuilder is built, both Custom Report Builder Preview/Run/Export and SavedFilter Preview/MatchingCount can be activated in one go.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | INFO | Backend / Service dependency | `PreviewCustomReport`, `RunCustomReport`, `ExportCustomReport` are SERVICE_PLACEHOLDER. Real execution requires the `DynamicQueryBuilder` service (same blocker as SavedFilter #27 ISSUE-1). Mocks return shape-coherent data; UI is fully wired. | OPEN — blocked on DynamicQueryBuilder |
| ISSUE-2 | 1 | INFO | Integration | "Run Full Report" eventually routes to `/reportaudit/reports/generatereport?customReportId=X`. Today returns SERVICE_PLACEHOLDER toast. Generate Report (#154) engine currently consumes `rep."Reports"` rows (stored-proc-bound); adapting it to CustomReports needs DynamicQueryBuilder. | OPEN — blocked on DynamicQueryBuilder |
| ISSUE-3 | 1 | LOW | Migration | EF migration created (`Add_CustomReportBuilder_2026_0513`) but NOT yet applied to a DB. User must run `dotnet ef database update -p Base.Infrastructure -s Base.API` before navigating to the page. | OPEN — user action |
| ISSUE-4 | 1 | LOW | DB Seed | Seed script written but NOT yet executed. User must run `CustomReportBuilder-sqlscripts.sql` against the tenant DB before MasterData lookups + field palette will populate. | OPEN — user action |
| ISSUE-5 | 1 | LOW | E2E test | `pnpm dev` runtime test not executed in this build session (long-running + DB-dependent). Code paths verified via `tsc --noEmit` (0 errors on CustomReport files) and `dotnet build` (0 errors). Full E2E (CRUD flow, palette toggle, drag reorder, filter operators, group/agg, preview Refresh, Save / Save As New, Run/Export placeholder toasts) is deferred to user smoke test. | OPEN — user action |
| ISSUE-6 | 1 | LOW | Future polish | DESIGNER_CANVAS sets the canonical reference. After verification, update `_CONFIG.md §⑦` to point future designer-canvas screens at `customreportbuilder.md` as canonical reference. | OPEN — doc task |
| ISSUE-7 | 1 | LOW | Backend / Navigation | `CustomReport.LastRunByUserId` FK declared without back-collection on `User`. Should EF complain about ambiguous relationship at startup, add explicit `.HasOne(...).WithMany()` on `UserConfiguration` — not currently observed in `dotnet build`. | OPEN — defensive |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-13 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. CONFIG / DESIGNER_CANVAS (first-of-its-kind). All agents spawned on **Sonnet** per user instruction (override of `/build-screen` Opus escalation table — preference now saved as memory `feedback_prefer_sonnet_over_opus`).
- **Files touched**:
  - **BE created (19)**:
    - `Base.Domain/Models/ReportModels/CustomReport.cs` (created)
    - `Base.Domain/Models/ReportModels/CustomReportFieldMetadata.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ReportConfigurations/CustomReportConfiguration.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ReportConfigurations/CustomReportFieldMetadataConfiguration.cs` (created)
    - `Base.Application/Schemas/ReportSchemas/CustomReportSchemas.cs` (created — incl. PreviewCustomReportResultDto / RunCustomReportResultDto / ExportCustomReportResultDto / DefinitionShape POCOs)
    - `Base.Application/Business/ReportBusiness/CustomReports/Queries/GetCustomReport.cs` (created)
    - `Base.Application/Business/ReportBusiness/CustomReports/Queries/GetCustomReportById.cs` (created)
    - `Base.Application/Business/ReportBusiness/CustomReports/Queries/GetCustomReportFieldMetadataByEntity.cs` (created)
    - `Base.Application/Business/ReportBusiness/CustomReports/Queries/PreviewCustomReport.cs` (created — SERVICE_PLACEHOLDER w/ shape-coherent mocked rows)
    - `Base.Application/Business/ReportBusiness/CustomReports/Queries/ExportCustomReport.cs` (created — SERVICE_PLACEHOLDER)
    - `Base.Application/Business/ReportBusiness/CustomReports/Commands/CreateCustomReport.cs` (created)
    - `Base.Application/Business/ReportBusiness/CustomReports/Commands/UpdateCustomReport.cs` (created)
    - `Base.Application/Business/ReportBusiness/CustomReports/Commands/DeleteCustomReport.cs` (created)
    - `Base.Application/Business/ReportBusiness/CustomReports/Commands/ToggleCustomReport.cs` (created)
    - `Base.Application/Business/ReportBusiness/CustomReports/Commands/SaveAsNewCustomReport.cs` (created)
    - `Base.Application/Business/ReportBusiness/CustomReports/Commands/RunCustomReport.cs` (created — SERVICE_PLACEHOLDER, writes LastRunAt/LastRunByUserId for real)
    - `Base.Application/Business/ReportBusiness/CustomReports/Validators/CustomReportDefinitionValidator.cs` (created — FluentValidation cross-checks fieldKey/DataType against DB)
    - `Base.API/EndPoints/Report/Mutations/CustomReportMutations.cs` (created — param renamed `input` → `customReport` to match FE convention)
    - `Base.API/EndPoints/Report/Queries/CustomReportQueries.cs` (created)
  - **BE modified (4)**: `IReportDbContext.cs`, `ReportDbContext.cs`, `DecoratorProperties.cs` (added `CustomReport = "CUSTOMREPORTBUILDER"` constant in `DecoratorReportModules`), `ReportMappings.cs`. GlobalUsing.cs (Application / Infrastructure / API) already had `Base.Domain.Models.ReportModels` — no change.
  - **BE migration**: `Add_CustomReportBuilder_2026_0513` created. NOT applied to DB.
  - **FE created (25)**: see manifest section §⑧ of this prompt. All under `src/presentation/components/page-components/reportaudit/reports/customreportbuilder/` except DTOs (`src/domain/entities/report-service/CustomReportDto.ts`), GQL files (`src/infrastructure/gql-queries/report-queries/CustomReportQuery.ts`, `src/infrastructure/gql-mutations/report-mutations/CustomReportMutation.ts`), and page config (`src/presentation/pages/reportaudit/reports/customreportbuilder.tsx`).
  - **FE modified (4)**:
    - `src/app/[lang]/reportaudit/reports/customreportbuilder/page.tsx` (REPLACED `<UnderConstruction />` stub w/ dynamic import of CustomReportBuilderConfig)
    - `src/presentation/pages/reportaudit/reports/index.ts` (barrel — added export)
    - `src/domain/entities/report-service/index.ts` (barrel — added export)
    - `src/infrastructure/gql-queries/report-queries/index.ts` + `src/infrastructure/gql-mutations/report-mutations/index.ts` (barrels — added exports)
  - **DB Seed (created)**: `sql-scripts-dyanmic/CustomReportBuilder-sqlscripts.sql` (652 lines)
- **Deviations from spec**:
  - **GQL contract shape**: prompt §⑩ said mutations return bare `Int`. Actual project convention (confirmed via SavedFilter) wraps every response in `result: { errorCode/errorDetails/message/status/success/data { ... } }`. FE wires to the wrapper; BE returns `BaseApiResponse<T>`. No functional impact — just envelope shape.
  - **Mutation arg name**: prompt §⑩ used `input: CustomReportRequestDto`. Actual project convention is the camelCase entity name (`customReport: CustomReportRequestDto`). BE renamed `input` → `customReport` in CustomReportMutations.cs after FE spawn 1 confirmed the convention.
  - **Apollo hook imports**: FE spawn 2 used `import { useQuery } from "@apollo/client"` (Apollo v3 path). Apollo v4 (project version 4.1.7) requires `@apollo/client/react`. Patched 5 files post-spawn-2 (data-source-section, fields-section, report-info-section, aggregation-row, filter-row). `gql` and types still imported from `@apollo/client`.
  - **Preview rows serialized as JSON string**: per memory `feedback_external_page_dictionary_binding`, Dictionary<string,object> DTOs break HotChocolate. BE serializes `rows / groupedRows / grandTotalRow` as JSON strings; FE parses via `parsePreviewRows()` etc. No GraphQL types extension needed.
  - **Model selection**: user requested Sonnet for all agents — overriding the `/build-screen` SKILL's Opus escalation for DESIGNER_CANVAS. Captured as memory `feedback_prefer_sonnet_over_opus`. No quality regression observed; FE produced clean code on first pass.
- **Known issues opened**: ISSUE-1 through ISSUE-7 (see table above). All OPEN. ISSUE-1 / ISSUE-2 are environmental (DynamicQueryBuilder); ISSUE-3 / ISSUE-4 / ISSUE-5 are deferred user actions (migration apply + seed run + E2E smoke test); ISSUE-6 is a doc-update; ISSUE-7 is defensive (no current build break).
- **Known issues closed**: None — this is the first session.
- **Verification performed this session**:
  - `dotnet build Base.API.csproj` → **0 errors**, 484 warnings (all pre-existing in unrelated files).
  - `tsc --noEmit` filtered to `customreport|custom-report` → **0 errors** on all 25 CustomReport-related FE files (spawn-2 Apollo path issue patched).
  - Contract trace: BuilderPage reads `data.result.data` matching the FE query wrapping shape. ActionBar reads `result.data.customReportId` from create/update mutations. SaveAsNewModal reads `data.result.data.customReportId` from save-as-new mutation.
  - Migration created (`Add_CustomReportBuilder_2026_0513`); seed file size 652 lines.
- **Next step**: (Session COMPLETED — no next-session work). User actions to unblock runtime: (1) `dotnet ef database update -p Base.Infrastructure -s Base.API` to apply migration; (2) execute `sql-scripts-dyanmic/CustomReportBuilder-sqlscripts.sql` against tenant DB; (3) `pnpm dev` and navigate to `/{lang}/reportaudit/reports/customreportbuilder` for smoke test (see §⑦ Acceptance Criteria). Future: when DynamicQueryBuilder ships, swap Preview/Run/Export SERVICE_PLACEHOLDER handlers for real implementations (closes ISSUE-1 / ISSUE-2). Then update `_CONFIG.md §⑦` to mark this prompt canonical (closes ISSUE-6).
