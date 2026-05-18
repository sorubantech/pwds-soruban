---
screen: AmbassadorPerformance
registry_id: 134
module: Field Collection
status: COMPLETED
scope: FULL
screen_type: DASHBOARD
dashboard_variant: CUSTOM_PAGE
complexity: Medium-High
new_module: NO
planned_date: 2026-05-15
completed_date: 2026-05-15
last_session_date: 2026-05-15
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — **N/A: mockup is TBD; spec SYNTHESIZED from #69 Ambassador Dashboard (org-wide) + #67 Ambassador (master) per user direction**
- [x] Variant chosen — **CUSTOM_PAGE** (per #64 Grant Calendar precedent; menu lives under `CRM_FIELDCOLLECTION`, not `CRM_DASHBOARDS`)
- [x] Source entities identified (Ambassador, AmbassadorCollection, AmbassadorTerritory, AmbassadorReceiptBookAssignment, ReceiptBook, Contact, Branch)
- [x] Widget catalog drafted (6 KPIs + 4 charts + 3 tables + 1 alerts panel + 1 profile card)
- [x] Layout config drafted (hand-rolled CSS grid — NOT react-grid-layout; CUSTOM_PAGE follows #64 pattern)
- [x] DashboardLayout JSON shape — **N/A for CUSTOM_PAGE** (no seed rows for Dashboard/DashboardLayout/Widget/WidgetType/WidgetRole)
- [x] Menu code + URL + OrderBy decided (AMBASSADORPERFORMANCE under CRM_FIELDCOLLECTION at OrderBy=5)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized (subject-selector + KPI strip + charts/tables/alerts grid)
- [x] User Approval received
- [x] Backend composite query handler generated (`GetAmbassadorPerformance`) — returns full DTO
- [x] Backend per-widget queries generated (`GetAmbassadorRecentCollections`, `GetAmbassadorLeaderboardRank`, `GetAmbassadorTopDonors`)
- [x] Backend wiring complete (`AmbassadorSchemas.cs` extension, `AmbassadorQueries.cs` endpoint, `FieldCollectionMappings.cs` marker)
- [x] FE DTO + GQL doc generated (in `fieldcollection-service/` and `fieldcollection-queries/` — prompt's `fund-service/fund-queries/` paths were incorrect)
- [x] FE page components generated under `presentation/components/page-components/crm/fieldcollection/ambassadorperformance/` (NOT `presentation/pages/...subfolder/` — project convention is `page-components/`) + widget folder `dashboards/widgets/ambassadorperformance-widgets/` (page-scoped, **NOT** registered in `WIDGET_REGISTRY`)
- [x] FE route stub created at `[lang]/crm/fieldcollection/ambassadorperformance/page.tsx`
- [x] DB Seed script generated (`AmbassadorPerformance-sqlscripts.sql`):
      • Menu AMBASSADORPERFORMANCE @ OrderBy=5 under CRM_FIELDCOLLECTION
      • MenuCapabilities (READ / EXPORT / ISMENURENDER)
      • BUSINESSADMIN + ADMINISTRATOR RoleCapabilities
      • **NO** Grid row (CUSTOM_PAGE per #64 GrantCalendar precedent — overrides prompt's STEP 4)
      • **NO** Dashboard / DashboardLayout / Widget / WidgetType / WidgetRole rows
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (no new errors)
- [ ] `pnpm tsc --noEmit` passes on every generated FE file
- [ ] `pnpm dev` — page loads at `/[lang]/crm/fieldcollection/ambassadorperformance`
- [ ] Ambassador-selector dropdown renders, populated from `getAmbassadors` (active ambassadors in user's company / branch-scoped if BRANCH_MANAGER)
- [ ] Selecting an ambassador updates URL `?ambassadorId={id}` AND triggers composite query refetch
- [ ] Empty state (no ambassadorId selected) renders friendly "Select an ambassador to view performance" placeholder
- [ ] All 6 KPI cards render with correct values + formatting (currency / count / %) and shape-matched skeletons during load
- [ ] All 4 charts render (trend / payment-mode donut / day-of-week bars / donor-type bars) — empty / tooltip / legend states verified
- [ ] All 3 tables render (recent collections / top donors / territory coverage) — pagination on recent collections honored
- [ ] Alerts panel renders with severity colors + per-alert CTA navigation
- [ ] Date-range change refetches composite query (one round trip)
- [ ] Currency change refetches composite query (server-side conversion)
- [ ] Drill-down clicks navigate per Drill-Down Map with correct prefill args
- [ ] role-based scoping: BRANCH_MANAGER only sees ambassadors in their branch; ambassador selector is pre-filtered
- [ ] role-based scoping: BUSINESSADMIN sees all branches; selector unrestricted
- [ ] DB Seed verified: menu visible in sidebar at OrderBy=5 under CRM_FIELDCOLLECTION; BUSINESSADMIN can navigate

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

**Screen**: AmbassadorPerformance
**Module**: CRM (Field Collection sub-area)
**Schema**: NONE (read-only aggregation over `fund.Ambassadors`, `fund.AmbassadorCollections`, `fund.AmbassadorTerritories`, `fund.AmbassadorReceiptBookAssignments`, `fund.ReceiptBooks`, `corg.Contacts`, `app.Branches`)
**Group**: FieldCollectionModels (BE) / `fund-service` (FE)

**Dashboard Variant**: CUSTOM_PAGE — sits in the operational Field Collection menu, NOT under Dashboards. Modeled on #64 Grant Calendar's CUSTOM_PAGE precedent: hand-rolled page chrome, dedicated widget folder NOT registered in `WIDGET_REGISTRY`, no Dashboard/DashboardLayout/Widget/WidgetType/WidgetRole seed rows.

**Business**:

Ambassador Performance is the **per-ambassador deep-dive analytics surface** for the Field Collection team. Where #69 Ambassador Dashboard answers "how is the field-collection programme doing overall?", #134 answers "how is *this specific ambassador* doing — should we promote them, coach them, or retire them?" The audience is the Fundraising Director and Branch Managers; the daily use case is monthly 1:1 performance reviews, mid-quarter coaching conversations, year-end commission calculations, and identifying ambassadors at risk of attrition.

The page lives under `CRM → Field Collection → Performance` and renders for ONE ambassador at a time, chosen via a top-of-page selector (URL-synced `?ambassadorId={id}`). It rolls up that ambassador's lifetime + period collections, donor portfolio, receipt-book usage, territory coverage, and behavioural patterns (day-of-week, payment-mode, average gift). It also surfaces a leaderboard rank within their branch and an alerts panel for issues that need attention (low book stock, inactive period, pending approvals). Drill-downs link back to the existing operational screens (#65 Collection List filtered by ambassador, #67 Ambassador detail, #66 Receipt Book).

Why CUSTOM_PAGE (not MENU_DASHBOARD): the dashboard is **subject-driven**, not module-overview. It requires a mandatory ambassador selector, deeply parameterized aggregates, and lives inside the Field Collection feature menu — not the dashboards menu. Routing it through `<MenuDashboardComponent />` would force an awkward dropdown-of-dashboards chrome that has no meaning here.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> NO new entity. CUSTOM_PAGE dashboards aggregate over existing entities. NO new seed rows in `sett.Dashboards` / `sett.DashboardLayouts` / `sett.Widgets` / `sett.WidgetTypes` / `auth.WidgetRoles` (matches #64 Grant Calendar precedent).

### Source Entities (read-only)

| Source Entity | Path | Purpose | Aggregates |
|---------------|------|---------|------------|
| `Ambassador` (fund) | `Base.Domain/Models/FieldCollectionModels/Ambassador.cs` | Subject of the page; selector source; profile card data | StaffId, BranchId, JoinDate, Status, CompensationType, CommissionPercent, CurrentReceiptBookId |
| `AmbassadorCollection` (fund) | `Base.Domain/Models/FieldCollectionModels/AmbassadorCollection.cs` | Primary fact table for KPIs / trend / payment-mode / day-of-week / recent collections / top donors | SUM(DonationAmount), COUNT(*), COUNT(DISTINCT ContactId), GROUP BY date_trunc('month'), GROUP BY PaymentModeId, GROUP BY day_of_week |
| `AmbassadorTerritory` (fund) | `Base.Domain/Models/FieldCollectionModels/AmbassadorTerritory.cs` | Territory coverage table | territory metadata (name/code/contactCount), join to AmbassadorCollection for visited% |
| `AmbassadorReceiptBookAssignment` (fund) | `Base.Domain/Models/FieldCollectionModels/AmbassadorReceiptBookAssignment.cs` | Receipt-book history alerts | ActiveBookId, BookUsagePercent |
| `ReceiptBook` (fund) | `Base.Domain/Models/FieldCollectionModels/ReceiptBook.cs` | Receipt-book usage / low-stock detection | RemainingCount, UsedCount, TotalCount |
| `Contact` (corg) | `Base.Domain/Models/CorgModels/Contact.cs` | Donor portfolio (top-donors table, donor-type breakdown) | ContactType linkage, contact name, contact code |
| `Branch` (app) | `Base.Domain/Models/ApplicationModels/Branch.cs` | Leaderboard-rank scope (ambassador rank within branch) | BranchName for profile card; AnnualTarget for compliance metric |
| `Staff` (corg) | `Base.Domain/Models/CorgModels/Staff.cs` | Profile card name / avatar / contact | StaffFirstName, StaffLastName, ImageUrl, Email, Phone |
| `PaymentMode` (app) | `Base.Domain/Models/ApplicationModels/PaymentMode.cs` | Payment-mode donut labels | PaymentModeName, PaymentModeCode |
| `MasterData` (com) | `Base.Domain/Models/CommonModels/MasterData.cs` | ContactType labels (donor-type breakdown) | DataValue |

### Composite DTO Shape (the wire payload)

> Path B composite handler — ONE round trip per filter change. Per-widget queries are reserved for paginated tables and rank-lookup.

```
AmbassadorPerformanceDto
  ├── profile : AmbassadorProfileDto
  │     { ambassadorId, ambassadorCode, fullName, avatarUrl?, email, phone,
  │       branchId, branchName, joinDate, status,
  │       compensationType, commissionPercent?,
  │       currentReceiptBookId?, currentReceiptBookCode?, currentBookUsagePercent? }
  ├── kpis : AmbassadorPerformanceKpisDto
  │     { lifetimeCollections      : decimal   // SUM since JoinDate, base-currency
  │       lifetimeCollectionsSparkline : ChartPointDto[]  // 12-month series for hero KPI
  │       periodCollections        : decimal   // SUM in window
  │       periodCollectionsDelta   : decimal   // % vs prior period
  │       donorsVisitedInPeriod    : int       // DISTINCT ContactId in window
  │       donorsVisitedDelta       : decimal   // % vs prior period
  │       avgPerVisitInPeriod      : decimal   // periodCollections / visitCount
  │       conversionRatePercent    : decimal   // count(collections >= 1) / count(visits)  — SERVICE_PLACEHOLDER if no "visit" entity exists yet (ISSUE-3)
  │       leaderboardRank          : int       // rank within branch over window
  │       leaderboardTotal         : int       // total active ambassadors in branch
  │     }
  ├── trend : AmbassadorTrendDto
  │     { months : [ { monthLabel, totalAmount, transactionCount } ] }  // 12-month or window
  ├── paymentMode : AmbassadorPaymentModeBreakdownDto
  │     { segments : [ { paymentModeCode, paymentModeName, totalAmount, percent } ] }
  ├── dayOfWeek : AmbassadorDayOfWeekBreakdownDto
  │     { days : [ { dayOfWeek 0-6, totalAmount, transactionCount } ] }
  ├── donorType : AmbassadorDonorTypeBreakdownDto
  │     { types : [ { contactTypeName, donorCount, totalAmount } ] }
  ├── territoryCoverage : AmbassadorTerritoryCoverageDto[]
  │     [ { territoryId, territoryName, totalContacts, visitedContacts, coveragePercent,
  │         totalCollectedInPeriod } ]
  ├── alerts : AmbassadorAlertDto[]
  │     [ { severity: 'warning'|'info'|'danger', icon, title, message,
  │         actionLabel?, actionRoute?, actionArgs? } ]
  └── filterMetadata : AmbassadorPerformanceFilterMetaDto
        { displayCurrencyCode, dateRange: { fromDate, toDate, label }, mixedCurrencyFlag }
```

**Per-widget extras** (separate queries — paginated / on-demand):

- `GetAmbassadorRecentCollections(ambassadorId, page=1, pageSize=10)` → `PagedResult<AmbassadorCollectionDto>` (existing list shape — extend if necessary)
- `GetAmbassadorTopDonors(ambassadorId, fromDate?, toDate?, limit=10)` → `AmbassadorTopDonorDto[]`
- `GetAmbassadorLeaderboardRank(ambassadorId, fromDate, toDate)` → `{ rank: int, total: int }` (reusable from composite — kept as separate handler if BE wants drill-down panel)

---

## ③ Source Entity & Aggregate Query Resolution

> **Consumer**: BE Dev (handler implementations) + FE Dev (GQL bindings)

| Source Entity | Entity File Path | Aggregate Handler | GQL Field | Returns | Args |
|---------------|------------------|-------------------|-----------|---------|------|
| Ambassador | `Base.Domain/Models/FieldCollectionModels/Ambassador.cs` | `GetAmbassadors` (existing) | `getAmbassadors` | `AmbassadorDto[]` | `branchId?` (selector population) |
| Ambassador | `Base.Domain/Models/FieldCollectionModels/Ambassador.cs` | `GetAmbassadorById` (existing) | `getAmbassadorById` | `AmbassadorDto` | `ambassadorId` (selector echo / fallback) |
| AmbassadorCollection + joined tables | `Base.Domain/Models/FieldCollectionModels/AmbassadorCollection.cs` | **NEW** `GetAmbassadorPerformance` | `getAmbassadorPerformance` | `AmbassadorPerformanceDto` | `ambassadorId`, `fromDate`, `toDate`, `displayCurrencyId?` |
| AmbassadorCollection | same | **NEW** `GetAmbassadorRecentCollections` | `getAmbassadorRecentCollections` | `PagedResult<AmbassadorCollectionDto>` | `ambassadorId`, `page`, `pageSize` |
| AmbassadorCollection | same | **NEW** `GetAmbassadorTopDonors` | `getAmbassadorTopDonors` | `AmbassadorTopDonorDto[]` | `ambassadorId`, `fromDate?`, `toDate?`, `limit=10` |
| AmbassadorCollection | same | **NEW** `GetAmbassadorLeaderboardRank` (or compute inside composite) | `getAmbassadorLeaderboardRank` | `{ rank, total }` | `ambassadorId`, `fromDate`, `toDate` |

**FK Resolution (for ambassador selector)**:

| FK | Target File | GQL Query (selector) | Display Field |
|----|-------------|-----------------------|---------------|
| ambassadorId (selector) | `Base.Domain/Models/FieldCollectionModels/Ambassador.cs` | `getAmbassadors` (already exists, returns full list with Status='Active' filter applied client-side) | `Staff.StaffFirstName + ' ' + Staff.StaffLastName + ' — ' + AmbassadorCode` |
| branchId (toolbar filter, BUSINESSADMIN only) | `Base.Domain/Models/ApplicationModels/Branch.cs` | `getAllBranchList` (existing canonical) | `BranchName` |

**Composite vs. Per-Widget query strategy**:

- [x] **Composite** for KPIs + charts + breakdowns + territory + alerts — they all re-fetch together when ambassadorId / dateRange / currency change. ONE round trip.
- [x] **Per-widget** for paginated `RecentCollections` (own page state) and on-demand `TopDonors` (could be lazy-loaded into a tab).
- [ ] Hybrid — yes, this is the hybrid choice; the composite carries 95% of the payload, two paginated/on-demand extras stay separate.

**Tenant scoping**: every handler MUST filter by `CompanyId = HttpContext.User.GetCompanyId()`. Easy to forget on the new composite handler — flag in ⑫.

**Branch scoping**: BRANCH_MANAGER role MUST be restricted server-side to `Ambassador.BranchId IN user.AllowedBranchIds`. The selector's `getAmbassadors` already returns Active ambassadors company-wide; the FE filters down to user's branch only if role is BRANCH_MANAGER. Confirm BE returns BranchId on AmbassadorDto so the FE can filter accurately. Add a `branchScoped: true` arg if the existing query doesn't already self-scope.

---

## ④ Business Rules & Validation

> **Consumer**: BA → BE Dev → FE Dev

### Date Range Defaults

- Default range: **Last 3 Months** (rolling — `fromDate = today - 90 days`, `toDate = today`)
- Allowed presets: **This Month / Last Month / Last 3 Months (default) / Last 6 Months / YTD / Custom**
- Custom range max span: **2 years** (bound aggregation cost)
- Sparkline windows are FIXED at 12 months regardless of selected period (the hero-KPI sparkline ignores the period selector — call this out in tooltip)

### Role-Scoped Data Access

- **BUSINESSADMIN**: sees every ambassador across all branches. Selector lists all `Status='Active'` ambassadors company-wide.
- **BRANCH_MANAGER**: sees only ambassadors in their assigned branch(es). Selector pre-filtered by `Ambassador.BranchId IN user.AllowedBranchIds`. Backend enforces — never trust the client filter alone.
- **FUNDRAISING_DIRECTOR**: equivalent to BUSINESSADMIN for this page (same visibility).
- **STAFF (non-managerial)**: no access; menu hidden via RoleCapability.

### Calculation Rules (non-trivial KPIs)

- **Lifetime Collections** = `SUM(AmbassadorCollection.DonationAmount * ExchangeRate WHERE AmbassadorId = @id AND Status != 'Voided')` converted to `@displayCurrencyId` (or Company default if NULL). NO date filter.
- **Period Collections** = same SUM but `AND CollectedDate BETWEEN @fromDate AND @toDate`.
- **Period Collections Delta %** = `((current - prior) / NULLIF(prior, 0)) * 100`, where `prior` = SUM over the immediately-preceding window of same length. If `prior = 0`, return `NULL` and FE renders "—" (no `Infinity%`).
- **Donors Visited** = `COUNT(DISTINCT AmbassadorCollection.ContactId WHERE AmbassadorId AND date in window AND Status != 'Voided')`.
- **Avg per Visit** = `periodCollections / NULLIF(COUNT(AmbassadorCollection.* in window), 0)`. NULL → renders "—".
- **Conversion Rate %** = `COUNT(collections in window) / COUNT(visits in window)` — **SERVICE_PLACEHOLDER**: a `Visit` entity doesn't exist in the codebase. Until #133 Record Collection lands a separate visit-without-collection record OR a `VisitNotes`-only AmbassadorCollection row pattern is formalized, this KPI returns `100%` (every collection IS a visit) and shows a `ⓘ` tooltip explaining the limitation. Flag as ISSUE-3.
- **Leaderboard Rank** = ambassador's position when all active ambassadors in their branch are sorted by `periodCollections DESC`. Ties broken by `donorsVisited DESC`. Total denominator = COUNT of active ambassadors in branch with at least 1 collection in window (so "rank 3 / 14" means "out of 14 active collectors").
- **Territory Coverage %** = `visitedContacts / NULLIF(totalContacts, 0)` per territory. `visitedContacts` = `COUNT(DISTINCT AmbassadorCollection.ContactId WHERE territory match AND in window)`. `totalContacts` = number of contacts assigned to that territory (territory-contact link — SERVICE_PLACEHOLDER if not yet modelled; fall back to `Branch.ContactCount` aggregate and flag as ISSUE-4).

### Multi-Currency Rules

- All currency KPIs reported in `@displayCurrencyId` (toolbar selector). Default: Company.DefaultCurrencyId. "Native Currency" option preserves per-row currency and renders a "Mixed currencies" tooltip via `filterMetadata.mixedCurrencyFlag=true`.
- Conversion happens server-side using the row's recorded `Currencies.CurrencyRate` (snapshot at collection time), NOT live FX. Matches #69 Ambassador Dashboard precedent (ISSUE-16 in #69 noted no per-row ExchangeRate column — same constraint applies here; query-time `Currencies.CurrencyRate` is the project convention).

### Widget-Level Rules

- The **Ambassador Selector** is REQUIRED. If `?ambassadorId` is not in the URL, render an empty-state placeholder ("Select an ambassador above to view their performance") and do NOT fire the composite query.
- If the resolved ambassador has Status='Inactive' or 'Suspended', render a yellow banner above the page chrome ("This ambassador is currently {Status}") — content still loads.
- If the composite query returns no collections in window, every KPI renders "0" / "—" with no error, and the trend chart renders "No collections in selected period."
- Workflow: NONE. Dashboards are read-only.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — pre-answered.

**Screen Type**: DASHBOARD
**Variant**: **CUSTOM_PAGE** (per #64 Grant Calendar precedent — menu URL `crm/fieldcollection/ambassadorperformance` under `CRM_FIELDCOLLECTION`, NOT under `CRM_DASHBOARDS`, so the MENU_DASHBOARD dynamic-route pattern doesn't apply).

**Reason**: Per-ambassador deep-dive analytics with a mandatory subject selector. Forcing this into MENU_DASHBOARD would require the dashboard-of-dashboards dropdown chrome that has no role here, and the menu has explicitly been parented under the operational Field Collection menu so users find it next to Ambassador List and Collection List.

**Backend Implementation Path**:

- [ ] Path A (Postgres function) — **NOT chosen**. Path A is for generic-widget MENU_DASHBOARDS. CUSTOM_PAGE has FULL freedom; typed handlers fit a subject-scoped composite payload better.
- [x] **Path B — Named typed query (composite)** — ONE `GetAmbassadorPerformance` handler returning the entire composite DTO. The FE binds to it via a single GQL doc. Matches #64 Grant Calendar's choice.
- [x] **Per-widget extras for paginated / lazy panels**: `GetAmbassadorRecentCollections` (paginated) and `GetAmbassadorTopDonors` (lazy if tabbed).

**Backend Patterns Required**:

- [x] Composite typed handler (CQRS Query + Validator) returning `AmbassadorPerformanceDto`
- [x] Tenant scoping (CompanyId from HttpContext) — every query
- [x] Branch scoping for BRANCH_MANAGER role — composite handler must read `User.AllowedBranchIds` and reject if the requested ambassador isn't in the user's branch scope
- [x] Date-range parameterized queries
- [x] Multi-currency conversion using `Currencies.CurrencyRate` at query time
- [x] Mapster config additions for new DTO graph
- [ ] Materialized view — NOT needed at this scale (single ambassador's data, even lifetime, is small)
- [x] Drill-down arg support — existing `getAmbassadorCollections` already accepts `ambassadorId` filter; verify it also accepts date range (extend if not)

**Frontend Patterns Required**:

- [x] **Hand-rolled page chrome** — NO `<DashboardComponent />`, NO `<MenuDashboardComponent />`. Follows #64 Grant Calendar pattern: dedicated `pages/crm/fieldcollection/ambassadorperformance/` folder with hand-rolled layout.
- [x] **Page-scoped widget renderers** under `dashboards/widgets/ambassadorperformance-widgets/` — **NOT registered in `WIDGET_REGISTRY`** (mirrors #64 — these are plain page-internal components, not catalog widgets).
- [x] CSS grid (or Tailwind grid utilities) for layout — NO `react-grid-layout` (CUSTOM_PAGE has fixed, hand-designed layout, not user-rearrangeable).
- [x] URL-state sync: `?ambassadorId` + `?fromDate` + `?toDate` + `?currencyId` survive reload and back-nav. Use Next.js search params + a small Zustand store for in-memory.
- [x] Skeleton states matching each widget's shape (per #64 + #69 precedent)
- [x] Empty / error / loading states per panel
- [x] Drill-down handlers — `useRouter().push()` with prefill query params
- [x] Apollo single-query strategy for composite + Suspense or fetch-policy for per-widget extras

**NOT in scope** for v1 (deferrable to V2):

- Edit-layout / drag-resize widget chrome (CUSTOM_PAGE is fixed-layout by design)
- Compare-mode (compare 2 ambassadors side-by-side)
- Export to PDF / CSV (SERVICE_PLACEHOLDER toast — flag as ISSUE-5)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → FE Dev
> Spec is SYNTHESIZED from #69 Ambassador Dashboard (org-wide patterns) + #67 Ambassador profile data + the per-ambassador deep-dive needs of monthly reviews / coaching / commission calcs. Developer may refine widget selection during build if business context demands — document deviations in ⑫.

### Layout Variant

**`grid-only`** (technically) — but with a mandatory ambassador-selector strip at top and a profile card. Pattern: subject-strip + KPI-strip + 3-row analytics grid + alerts row.

### Page Chrome

**Header strip** (hand-rolled, no `<DashboardHeader />`):
- Left: Page title "Ambassador Performance" + breadcrumb "CRM › Field Collection › Performance"
- Right: Refresh button + Export Report button (SERVICE_PLACEHOLDER toast — ISSUE-5) + Print button (`window.print()`)

**Subject + Filter strip** (sticky below page header):
- **Ambassador Selector** (REQUIRED, ApiSelectV2) — typeahead over active ambassadors; shows `{FullName} — {AmbassadorCode}` + small `{BranchName}` subtitle per option; BRANCH_MANAGER's list is pre-filtered by branch
- **Period Selector** (native select + custom range popover) — presets per § ④
- **Currency Selector** (native select) — list from `getAllCurrencies` + "Native (Mixed)" sentinel

**Empty state** (when `?ambassadorId` is missing or invalid):
- Friendly placeholder card with `ph:user-circle-plus` icon + "Select an ambassador above to view their performance" + a CTA "Browse Ambassadors" → `/crm/fieldcollection/ambassadorlist`

### Layout (hand-rolled CSS grid)

> All sizes are at `lg` (≥1024px). Below `lg`, panels stack full-width vertically.

```
Row 1 — Profile card (full-width strip; 12 cols)
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │ Avatar │ Name + AmbassadorCode (h1) │ Branch │ Joined │ Status │ Comp │ Book │
  │        │ ContactType chips          │  pill  │  date  │  pill  │ pill │  %   │
  └──────────────────────────────────────────────────────────────────────────────┘

Row 2 — KPI strip (6 cards in 2 rows of 3)
  ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
  │ HERO — Lifetime     │ │ DELTA — Period      │ │ DELTA — Donors      │
  │ Collections         │ │ Collections + Δ%    │ │ Visited + Δ%        │
  │ (emerald gradient)  │ │ (teal accent)       │ │ (purple accent)     │
  └─────────────────────┘ └─────────────────────┘ └─────────────────────┘
  ┌─────────────────────┐ ┌─────────────────────┐ ┌─────────────────────┐
  │ Compact — Avg / Visit│ │ Compliance — Conv  │ │ Ratio — Rank        │
  │ (blue accent)       │ │ Rate % (orange)     │ │ "#3 / 14" (indigo)  │
  └─────────────────────┘ └─────────────────────┘ └─────────────────────┘

Row 3 — Analytics grid (12 cols)
  ┌────────────────────────────────────────────────┐ ┌────────────────┐
  │ Collection Trend (combo bar+line) — 8 cols     │ │ Payment Mode   │
  │                                                │ │ Donut — 4 cols │
  └────────────────────────────────────────────────┘ └────────────────┘
  ┌────────────────┐ ┌────────────────┐ ┌──────────────────────────────┐
  │ Day of Week    │ │ Donor Type     │ │ Territory Coverage table     │
  │ Bars — 4 cols  │ │ Bars — 4 cols  │ │ (with coverage badges)       │
  └────────────────┘ └────────────────┘ └──────────────────────────────┘

Row 4 — Tables strip (12 cols → 2× 6-col side-by-side)
  ┌────────────────────────────────────┐ ┌────────────────────────────────────┐
  │ Recent Collections (last 10)       │ │ Top Donors (top 10 by lifetime $)  │
  │ paginated; row click → drill       │ │ row click → contact detail         │
  └────────────────────────────────────┘ └────────────────────────────────────┘

Row 5 — Alerts panel (full-width, 12 cols)
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │ Alerts & Action Items — severity rows w/ CTA buttons                         │
  └──────────────────────────────────────────────────────────────────────────────┘
```

Below `lg`, each Row 3/4 panel stacks single-column. KPI strip stays 3-col at `md` (8 cols) and collapses to 1-col at `xs`.

### Widget Catalog (page-scoped renderers, NOT in WIDGET_REGISTRY)

Folder: `Pss2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/ambassadorperformance-widgets/`

| # | Name | Component | Visual Distinguisher | Data Source | Filters | Drill-Down |
|---|------|-----------|----------------------|-------------|---------|------------|
| 1 | Profile Card | `AmbassadorProfileCard` | Full-width header strip, avatar circle, dense info grid, status pill, current-book usage bar | composite.profile | — | `/crm/fieldcollection/ambassadorlist?mode=read&id={ambassadorId}` |
| 2 | KPI #1 Lifetime | `AmbassadorPerformanceHeroKpi` | LARGE card, emerald gradient strip, 12-mo sparkline, hand-holding-dollar icon | composite.kpis.lifetimeCollections + sparkline | currency | — |
| 3 | KPI #2 Period | `AmbassadorPerformanceDeltaKpi` (variant: teal) | Mid-size, dual-value (amount + Δ%), receipt icon | composite.kpis.periodCollections + delta | period, currency | `/crm/fieldcollection/collectionlist?ambassadorId=&dateFrom=&dateTo=` |
| 4 | KPI #3 Donors | `AmbassadorPerformanceDeltaKpi` (variant: purple) | Mid-size, dual-value (count + Δ%), users icon | composite.kpis.donorsVisited + delta | period | `/crm/fieldcollection/collectionlist?ambassadorId=&dateFrom=&dateTo=&groupBy=donor` |
| 5 | KPI #4 Avg/Visit | `AmbassadorPerformanceCompactKpi` (variant: blue) | Compact card, blue accent, chart-simple icon | composite.kpis.avgPerVisit | period, currency | — |
| 6 | KPI #5 Conversion | `AmbassadorPerformanceComplianceKpi` | Compact orange-tinted card, primary `100%`, `ⓘ` tooltip flagging V1 limitation | composite.kpis.conversionRatePercent | period | — |
| 7 | KPI #6 Rank | `AmbassadorPerformanceRatioKpi` | Distinct ratio chrome `#3 / 14`, indigo accent, trophy icon | composite.kpis.leaderboardRank + leaderboardTotal | period | `/crm/fieldcollection/ambassadorlist?branchId={branchId}&sort=collections` |
| 8 | Collection Trend | `AmbassadorPerformanceTrendChart` | Apex combo (bars=amount + line=count); 12-mo or period window; annotation pins for ramadan / EOY | composite.trend.months | period (extends to 12-mo for sparkline overlap), currency | Bar click → `/crm/fieldcollection/collectionlist?ambassadorId=&dateFrom=monthStart&dateTo=monthEnd` |
| 9 | Payment Mode Donut | `AmbassadorPerformancePaymentDonut` | Apex donut, center total + 4-segment legend with $ + % | composite.paymentMode.segments | period, currency | Slice click → `/crm/fieldcollection/collectionlist?ambassadorId=&paymentModeCode={code}&dateFrom=&dateTo=` |
| 10 | Day of Week | `AmbassadorPerformanceDayOfWeekBars` | 7 vertical CSS bars (Mon-Sun), gradient emerald, value labels above | composite.dayOfWeek.days | period | Bar click → `/crm/fieldcollection/collectionlist?ambassadorId=&dayOfWeek={0-6}` (ISSUE-7) |
| 11 | Donor Type | `AmbassadorPerformanceDonorTypeBars` | Horizontal bars by ContactType, mini inline value labels | composite.donorType.types | period | Bar click → `/crm/contact/contact?ambassadorId=&contactTypeName={name}` (ISSUE-7) |
| 12 | Territory Coverage | `AmbassadorPerformanceTerritoryTable` | Mini table: Territory / Contacts / Visited (count + %) / Coverage badge (red <40% / amber 40-70% / green >70%) / $ | composite.territoryCoverage | period, currency | Row click → `/crm/fieldcollection/ambassadorlist?mode=read&id={ambassadorId}&tab=territories` |
| 13 | Recent Collections | `AmbassadorPerformanceRecentCollectionsTable` | Paginated 7-col table (date / donor / amount / mode / receipt / status pill / view link) | per-widget `getAmbassadorRecentCollections` | ambassadorId (page-scoped only, ignores period filter — last 10 always) | Row click → `/crm/fieldcollection/collectionlist?mode=read&id={collectionId}` |
| 14 | Top Donors | `AmbassadorPerformanceTopDonorsTable` | 5-col table (rank / donor name / contact type chip / collection count / total $) | per-widget `getAmbassadorTopDonors` | ambassadorId, period (window-scoped) | Row click → `/crm/contact/contact?mode=read&id={contactId}` |
| 15 | Alerts | `AmbassadorPerformanceAlertsPanel` | Severity-colored alert rows (yellow warning / blue info / red danger), distinct icon-circle bg, sanitized `<strong>` only, action button per row | composite.alerts | period | Per-alert `actionRoute + actionArgs` |

### KPI Cards Detail

| # | Title | Value Source | Format | Subtitle | Sparkline | Accent |
|---|-------|--------------|--------|----------|-----------|--------|
| 1 | Lifetime Collections | `kpis.lifetimeCollections` | currency | "Since {profile.joinDate}" | 12-mo line sparkline | emerald gradient |
| 2 | Period Collections | `kpis.periodCollections` | currency + `kpis.periodCollectionsDelta` | "{Δ%} vs previous {period}" | none | teal |
| 3 | Donors Visited | `kpis.donorsVisitedInPeriod` | count | "{Δ%} vs previous {period}" | none | purple |
| 4 | Avg per Visit | `kpis.avgPerVisitInPeriod` | currency | "Across {visitCount} visits" | none | blue |
| 5 | Conversion Rate | `kpis.conversionRatePercent` | percent | `ⓘ V1: all collections counted as visits` | none | orange |
| 6 | Branch Rank | `#{kpis.leaderboardRank} / {kpis.leaderboardTotal}` | ratio | "in {branchName}" | none | indigo |

### Charts Detail

| # | Title | Type | X | Y | Source | Filters | Empty/Tooltip |
|---|-------|------|---|---|--------|---------|---------------|
| 8 | Collection Trend | combo (bar + line) | Month | bar=amount, line=count | `trend.months[]` | period, currency | "No collections in selected period" |
| 9 | Payment Mode | donut | — | paymentMode share | `paymentMode.segments[]` | period, currency | "No collections in selected period" |
| 10 | Day of Week | vertical bars | Mon..Sun | amount | `dayOfWeek.days[]` | period | "No data" |
| 11 | Donor Type | horizontal bars | contactTypeName | donorCount | `donorType.types[]` | period | "No data" |

### Filter Controls

| Filter | Type | Default | Applies To | Notes |
|--------|------|---------|-----------|-------|
| **Ambassador** | ApiSelectV2 typeahead | None (REQUIRED) | All widgets | Selector is mandatory; URL-synced as `ambassadorId`. BRANCH_MANAGER list pre-filtered. |
| **Period** | native select + custom range popover | "Last 3 Months" | KPIs 2-6, charts 8/10/11, table Top Donors, alerts (some) | URL-synced as `fromDate` + `toDate`. KPI 1 ignores period (it's lifetime). |
| **Currency** | native select | Company default | KPIs 1/2/4, chart 8/9, Territory Coverage $ column, Recent Collections amount, Top Donors $ | URL-synced as `currencyId`. "Native (Mixed)" surfaces `mixedCurrencyFlag` tooltip. |

### Drill-Down / Navigation Map

| From | Click | Destination | Prefill |
|------|-------|-------------|---------|
| Profile card "View full profile" link | link click | `/crm/fieldcollection/ambassadorlist` | `?mode=read&id={ambassadorId}` |
| KPI Period Collections card | whole card | `/crm/fieldcollection/collectionlist` | `?ambassadorId=&dateFrom=&dateTo=` |
| KPI Donors Visited card | whole card | `/crm/fieldcollection/collectionlist` | `?ambassadorId=&dateFrom=&dateTo=&groupBy=donor` (ISSUE-7) |
| KPI Branch Rank card | whole card | `/crm/fieldcollection/ambassadorlist` | `?branchId={profile.branchId}&sort=collections` |
| Trend bar/line | series click | `/crm/fieldcollection/collectionlist` | `?ambassadorId=&dateFrom=monthStart&dateTo=monthEnd` |
| Payment Mode slice | slice click | `/crm/fieldcollection/collectionlist` | `?ambassadorId=&paymentModeCode={code}&dateFrom=&dateTo=` |
| Day of Week bar | bar click | `/crm/fieldcollection/collectionlist` | `?ambassadorId=&dayOfWeek={0-6}` — collectionlist may need new arg (ISSUE-7) |
| Donor Type bar | bar click | `/crm/contact/contact` | `?ambassadorId=&contactTypeName={name}` (ISSUE-7) |
| Territory row | row click | `/crm/fieldcollection/ambassadorlist` | `?mode=read&id={ambassadorId}&tab=territories` |
| Recent Collections row | row click | `/crm/fieldcollection/collectionlist` | `?mode=read&id={collectionId}` |
| Top Donor row | row click | `/crm/contact/contact` | `?mode=read&id={contactId}` |
| Alert "Investigate gaps" CTA | button | `/crm/fieldcollection/collectionlist` | `?ambassadorId=&gapsOnly=true` (ISSUE-7) |
| Alert "Reassign book" CTA | button | `/crm/fieldcollection/receiptbook` | `?ambassadorId=` |
| Alert "Approve queue" CTA | button | `/crm/fieldcollection/collectionlist` | `?ambassadorId=&status=Pending` |
| Toolbar "Export Report" | button | SERVICE_PLACEHOLDER toast | — |
| Toolbar "Print" | button | `window.print()` | — |
| Toolbar "Refresh" | button | refetch composite + per-widget | — |

### User Interaction Flow

1. **Initial landing — no ambassadorId**: user clicks `CRM → Field Collection → Performance` → URL `/[lang]/crm/fieldcollection/ambassadorperformance` → renders header + subject strip with empty selector + friendly empty state card. No composite query fires.
2. **Select an ambassador**: typeahead → click → URL becomes `?ambassadorId={id}` → composite query fires with default period (Last 3 Months) + default currency → all widgets render their loading skeletons → results arrive → page populates.
3. **Change period**: URL updates `fromDate` + `toDate` → composite refetches → period-honoring widgets re-render (lifetime KPI stays cached / unchanged).
4. **Change currency**: URL updates `currencyId` → composite refetches → currency-bearing widgets re-render with new conversion.
5. **Pagination on Recent Collections**: clicks next page → only that table's `getAmbassadorRecentCollections` query fires; composite stays cached.
6. **Drill-down click**: navigates per Drill-Down Map → user lands on filtered list/detail screen.
7. **Back navigation**: returns to this page; URL state restores filters; Apollo cache may return instant from cache.
8. **Refresh button**: invalidates Apollo cache for composite + per-widget → refetch.
9. **Empty / loading / error states**: per-widget skeletons match widget shape; error → red mini banner + Retry; empty (no data in window) → muted icon + "No data" message per widget.
10. **Status-banner case**: if selected ambassador's `Status != 'Active'`, render yellow banner above subject strip.

---

## ⑦ Substitution Guide

> **Consumer**: BE Dev + FE Dev
> Sibling of **#64 Grant Calendar** for CUSTOM_PAGE architecture + **#69 Ambassador Dashboard** for data-source patterns. NOTE: #134 does NOT reuse #69's widget renderers — those are MENU_DASHBOARD-scoped and live under `ambassador-dashboard-widgets/`; this page ships its own page-scoped renderers under `ambassadorperformance-widgets/`.

**Canonical References**:
- **Page architecture (CUSTOM_PAGE)**: #64 Grant Calendar — `prompts/grantcalendar.md` § ⑥–⑧. Same hand-rolled page + dedicated widgets folder NOT in WIDGET_REGISTRY + DASHBOARD GridType + no Dashboard/DashboardLayout/Widget seed rows.
- **Per-widget data shapes**: #69 Ambassador Dashboard — `prompts/ambassadordashboard.md` § ⑥ widget catalog. Visual treatments (hero/delta/ratio/compliance KPI variants, trend combo, payment-mode donut, day-of-week bars) translate directly; just rename + re-scope to per-ambassador subject.
- **Composite typed handler shape**: #62 Grant `GetGrantById` (composite DTO with nested child collections) — same projection style.

| Convention | Reference Source | → This Screen | Notes |
|-----------|------------------|---------------|-------|
| MenuCode | (none — new) | `AMBASSADORPERFORMANCE` | per MODULE_MENU_REFERENCE.md:147 |
| MenuName | (none — new) | `Performance` | display label as listed in reference |
| MenuUrl | (none — new) | `crm/fieldcollection/ambassadorperformance` | per MODULE_MENU_REFERENCE.md:147 |
| ParentMenu | CRM_FIELDCOLLECTION | CRM_FIELDCOLLECTION | MenuId=272 per reference |
| Module | CRM | CRM | — |
| OrderBy | (within CRM_FIELDCOLLECTION) | 5 | per reference; siblings: AMBASSADORLIST=1, AMBASSADORCOLLECTION=2, COLLECTIONLIST=3, RECEIPTBOOK=4, AMBASSADORPERFORMANCE=5, COLLECTIONDISTRIBUTION=6 |
| Backend group | FieldCollectionModels (existing — used by #65/#67/#66/#68) | FieldCollectionModels | reuse — no new group |
| Schemas file | `FieldCollectionSchemas/AmbassadorSchemas.cs` (existing) | extend with `AmbassadorPerformanceDto` + 9 nested DTOs | append, do NOT replace |
| Query handler folder | `FieldCollectionBusiness/Ambassadors/Queries/` (existing — GetAmbassadors / GetAmbassadorById / GetAmbassadorSummary) | add 4 new handlers (Performance, RecentCollections, TopDonors, LeaderboardRank) | follow #67 patterns |
| GQL endpoint | `Base.API/EndPoints/FieldCollection/Queries/AmbassadorQueries.cs` (existing) | add 4 new field extensions | append |
| Mapster config | `FieldCollectionMappings.cs` (existing) | add TypeAdapterConfigs for new DTOs | append |
| FE service folder | `domain/entities/fund-service/` (existing — used by #65/#67) | add `AmbassadorPerformanceDto.ts` | append |
| FE GQL folder | `infrastructure/gql-queries/fund-queries/` (existing) | add `AmbassadorPerformanceQuery.ts` | new file |
| FE page folder | `presentation/pages/crm/fieldcollection/` (existing — used by #65/#67) | add `ambassadorperformance/` subfolder + page.tsx + components | new |
| FE widget folder | `presentation/components/custom-components/dashboards/widgets/` (existing) | add `ambassadorperformance-widgets/` subfolder + folder barrel | new |
| FE route stub | `app/[lang]/crm/fieldcollection/ambassadorperformance/page.tsx` | OVERWRITE (or create — does not currently exist) | imports the page-config wrapper |
| DB seed file | `sql-scripts-dyanmic/AmbassadorPerformance-sqlscripts.sql` | new — preserve `dyanmic` typo | mirror #64 Grant Calendar shape |
| GridType | DASHBOARD | DASHBOARD | matches #64 |
| GridFormSchema | NULL | NULL | matches #64 — no RJSF form |
| Composite query name | `GetGrantById` (style ref) | `GetAmbassadorPerformance` | typed CQRS |
| GQL field name | (parallel) | `getAmbassadorPerformance` | camelCase |
| DTO root | (parallel) | `AmbassadorPerformanceDto` | composite |
| Dashboard color | (none — page chrome neutral) | — | CUSTOM_PAGE uses page-default chrome; no Dashboard.DashboardColor row to seed |

---

## ⑧ File Manifest

> **Consumer**: BE Dev + FE Dev

### Backend Files (4 new query handlers + DTO extensions)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTOs (composite + 9 nested) | `Base.Application/Schemas/FieldCollectionSchemas/AmbassadorSchemas.cs` | EXTEND (append) — add `AmbassadorPerformanceDto`, `AmbassadorProfileDto`, `AmbassadorPerformanceKpisDto`, `AmbassadorTrendDto`, `AmbassadorPaymentModeBreakdownDto`, `AmbassadorDayOfWeekBreakdownDto`, `AmbassadorDonorTypeBreakdownDto`, `AmbassadorTerritoryCoverageDto`, `AmbassadorAlertDto`, `AmbassadorPerformanceFilterMetaDto`, `AmbassadorTopDonorDto`, `ChartPointDto` (if not already shared) |
| 2 | Composite query handler | `Base.Application/Business/FieldCollectionBusiness/Ambassadors/Queries/GetAmbassadorPerformance.cs` | NEW |
| 3 | Recent collections query | `Base.Application/Business/FieldCollectionBusiness/Ambassadors/Queries/GetAmbassadorRecentCollections.cs` | NEW |
| 4 | Top donors query | `Base.Application/Business/FieldCollectionBusiness/Ambassadors/Queries/GetAmbassadorTopDonors.cs` | NEW |
| 5 | Leaderboard rank query | `Base.Application/Business/FieldCollectionBusiness/Ambassadors/Queries/GetAmbassadorLeaderboardRank.cs` | NEW (optional — could fold into composite; keep separate for tab-deferred reuse) |
| 6 | GQL endpoint registration | `Base.API/EndPoints/FieldCollection/Queries/AmbassadorQueries.cs` | EXTEND — add 4 new GQL field extensions |
| 7 | Mapster config | `Base.Application/MappingConfigs/FieldCollectionMappings.cs` | EXTEND — TypeAdapterConfig for new DTO graph |

### Backend Wiring Updates

| # | File | Change |
|---|------|--------|
| 1 | `AmbassadorQueries.cs` | register 4 new GQL fields (composite + 3 per-widget) |
| 2 | `FieldCollectionMappings.cs` | TypeAdapterConfig additions for new DTOs |

**No new DbContext / Group / Decorator wiring** — `fund` schema + `FieldCollectionModels` group already bootstrapped by #65/#67.

### Frontend Files (1 DTO + 1 GQL + 15 components + 1 toolbar + 1 page config + 1 route stub + 1 store)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO types | `domain/entities/fund-service/AmbassadorPerformanceDto.ts` | NEW |
| 2 | GQL queries | `infrastructure/gql-queries/fund-queries/AmbassadorPerformanceQuery.ts` | NEW — 4 documents: `GET_AMBASSADOR_PERFORMANCE`, `GET_AMBASSADOR_RECENT_COLLECTIONS`, `GET_AMBASSADOR_TOP_DONORS`, `GET_AMBASSADOR_LEADERBOARD_RANK` |
| 3 | Zustand store | `presentation/pages/crm/fieldcollection/ambassadorperformance/ambassador-performance-store.ts` | NEW — filter state (ambassadorId, fromDate, toDate, currencyId) + URL sync helpers |
| 4 | Page-config wrapper | `presentation/pages/crm/fieldcollection/ambassadorperformance/ambassador-performance-page-config.tsx` | NEW — composes header + selector + sections + skeletons + empty state |
| 5 | Index barrel | `presentation/pages/crm/fieldcollection/ambassadorperformance/index.ts` | NEW |
| 6 | Subject + Filter toolbar | `presentation/pages/crm/fieldcollection/ambassadorperformance/ambassador-performance-toolbar.tsx` | NEW — Ambassador ApiSelectV2 + Period + Currency + Export/Print/Refresh |
| 7 | Profile card | `dashboards/widgets/ambassadorperformance-widgets/profile-card/ProfileCard.tsx` (+ `.types.ts` + `.skeleton.tsx` + `index.ts`) | NEW |
| 8 | KPI: HeroKpi (Lifetime) | `dashboards/widgets/ambassadorperformance-widgets/hero-kpi/HeroKpi.tsx` (+ types + skeleton + index) | NEW |
| 9 | KPI: DeltaKpi (2 instances — Period + Donors) | `dashboards/widgets/ambassadorperformance-widgets/delta-kpi/DeltaKpi.tsx` (+ types + skeleton + index) | NEW — single renderer parameterized by accent + label |
| 10 | KPI: CompactKpi (Avg/Visit) | `dashboards/widgets/ambassadorperformance-widgets/compact-kpi/CompactKpi.tsx` (+ types + skeleton + index) | NEW |
| 11 | KPI: ComplianceKpi (Conv Rate) | `dashboards/widgets/ambassadorperformance-widgets/compliance-kpi/ComplianceKpi.tsx` (+ types + skeleton + index) | NEW |
| 12 | KPI: RatioKpi (Rank) | `dashboards/widgets/ambassadorperformance-widgets/ratio-kpi/RatioKpi.tsx` (+ types + skeleton + index) | NEW |
| 13 | Trend chart | `dashboards/widgets/ambassadorperformance-widgets/trend-chart/TrendChart.tsx` (+ types + skeleton + index) | NEW — Apex combo bar+line |
| 14 | Payment Mode donut | `dashboards/widgets/ambassadorperformance-widgets/payment-mode-donut/PaymentModeDonut.tsx` (+ types + skeleton + index) | NEW — Apex donut |
| 15 | Day of Week bars | `dashboards/widgets/ambassadorperformance-widgets/day-of-week-bars/DayOfWeekBars.tsx` (+ types + skeleton + index) | NEW — CSS vertical bars |
| 16 | Donor Type bars | `dashboards/widgets/ambassadorperformance-widgets/donor-type-bars/DonorTypeBars.tsx` (+ types + skeleton + index) | NEW — CSS horizontal bars |
| 17 | Territory Coverage table | `dashboards/widgets/ambassadorperformance-widgets/territory-table/TerritoryTable.tsx` (+ types + skeleton + index) | NEW |
| 18 | Recent Collections table | `dashboards/widgets/ambassadorperformance-widgets/recent-collections-table/RecentCollectionsTable.tsx` (+ types + skeleton + index) | NEW — paginated |
| 19 | Top Donors table | `dashboards/widgets/ambassadorperformance-widgets/top-donors-table/TopDonorsTable.tsx` (+ types + skeleton + index) | NEW |
| 20 | Alerts panel | `dashboards/widgets/ambassadorperformance-widgets/alerts-panel/AlertsPanel.tsx` (+ types + skeleton + index) | NEW |
| 21 | Empty state card | `dashboards/widgets/ambassadorperformance-widgets/empty-state/EmptyState.tsx` (+ index) | NEW — "Select an ambassador" placeholder |
| 22 | Folder barrel | `dashboards/widgets/ambassadorperformance-widgets/index.ts` | NEW — re-exports all 15 renderers |
| 23 | Route stub | `app/[lang]/crm/fieldcollection/ambassadorperformance/page.tsx` | NEW or OVERWRITE — imports the page-config wrapper, renders `<AmbassadorPerformancePageConfig />` |
| 24 | Pages barrel | `presentation/pages/crm/fieldcollection/index.ts` | EXTEND — re-export `AmbassadorPerformancePageConfig` |

### Frontend Wiring Updates

| # | File | Change |
|---|------|--------|
| 1 | `presentation/pages/crm/fieldcollection/index.ts` | re-export new page-config |
| 2 | `dashboards/widgets/index.ts` (if exists) | re-export `ambassadorperformance-widgets/` barrel |
| 3 | NO `WIDGET_REGISTRY` change — renderers are page-scoped, NOT widget-grid widgets |
| 4 | NO `QUERY_REGISTRY` change — composite query is consumed via Apollo `useQuery` directly, not via `generateWidgets` |
| 5 | Sidebar — auto-renders from DB seed (no manual wiring) |

### DB Seed (`sql-scripts-dyanmic/AmbassadorPerformance-sqlscripts.sql`)

> Preserve repo's `sql-scripts-dyanmic/` typo. Mirror #64 Grant Calendar's STEP layout — idempotent independent execution.

| # | Item | Notes |
|---|------|-------|
| 1 | STEP 0 — Diagnostics | Verify CRM module exists, BUSINESSADMIN role exists, CRM_FIELDCOLLECTION parent menu exists |
| 2 | STEP 1 — Insert Menu row | `MenuCode=AMBASSADORPERFORMANCE`, `MenuName=Performance`, `MenuUrl=crm/fieldcollection/ambassadorperformance`, `OrderBy=5`, `ParentMenuId=CRM_FIELDCOLLECTION`, `ModuleId=CRM`, `MenuIcon=ph:user-focus` or similar. NOT EXISTS guard. |
| 3 | STEP 2 — Insert MenuCapabilities | READ, EXPORT, ISMENURENDER. NOT EXISTS guards. |
| 4 | STEP 3 — Insert RoleCapabilities for BUSINESSADMIN | READ, EXPORT on AMBASSADORPERFORMANCE. NOT EXISTS guards. |
| 5 | STEP 4 — Insert Grid row | `GridCode=AMBASSADORPERFORMANCE`, `GridType=DASHBOARD`, `GridFormSchema=NULL`, ModuleId=CRM. NOT EXISTS guard. |
| 6 | STEP 5 — Verify (read-only SELECT diagnostics) | confirm menu / caps / role grants visible |

**Re-running seed must be idempotent** — every INSERT guarded by `NOT EXISTS`.

**NO Dashboard / DashboardLayout / Widget / WidgetType / WidgetRole rows** — CUSTOM_PAGE classification per #64 Grant Calendar precedent. The page is a dedicated route, not a `sett.Dashboards`-driven widget grid.

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL
DashboardVariant: CUSTOM_PAGE

MenuName: Performance
MenuCode: AMBASSADORPERFORMANCE
ParentMenu: CRM_FIELDCOLLECTION
Module: CRM
MenuUrl: crm/fieldcollection/ambassadorperformance
MenuIcon: ph:user-focus
OrderBy: 5
GridType: DASHBOARD
GridCode: AMBASSADORPERFORMANCE
GridFormSchema: NULL

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT
  # BRANCH_MANAGER / FUNDRAISING_DIRECTOR: READ — to be added at build time per ④ if those role rows exist

# CUSTOM_PAGE does NOT seed Dashboard / DashboardLayout / Widget / WidgetType / WidgetRole rows.
# These five tables stay untouched.
DashboardCode:       # NOT WRITTEN — no row in sett.Dashboards
DashboardName:       # NOT WRITTEN
DashboardIcon:       # NOT WRITTEN
DashboardColor:      # NOT WRITTEN
IsSystem:            # NOT WRITTEN
WidgetGrants:        # NOT WRITTEN — widgets are page-scoped React components, not catalog widgets
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: FE Dev

### Queries

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| `getAmbassadorPerformance` | `AmbassadorPerformanceDto` | `ambassadorId: Int!, fromDate: DateTime!, toDate: DateTime!, displayCurrencyId: Int?` | composite — primary widget data |
| `getAmbassadorRecentCollections` | `PagedResult<AmbassadorCollectionDto>` | `ambassadorId: Int!, page: Int = 1, pageSize: Int = 10` | paginated table — own state |
| `getAmbassadorTopDonors` | `[AmbassadorTopDonorDto!]!` | `ambassadorId: Int!, fromDate: DateTime?, toDate: DateTime?, limit: Int = 10` | secondary table — lazy-loadable |
| `getAmbassadorLeaderboardRank` | `AmbassadorLeaderboardRankDto` `{ rank, total }` | `ambassadorId: Int!, fromDate: DateTime!, toDate: DateTime!` | optional separate — also folded inside composite for v1 |
| `getAmbassadors` (existing) | `[AmbassadorDto!]!` | `branchId: Int?` | selector population |
| `getAmbassadorById` (existing) | `AmbassadorDto` | `ambassadorId: Int!` | fallback / cache priming |

### Composite DTO field-by-field

| Field | Type | Backing | Notes |
|-------|------|---------|-------|
| `profile.ambassadorId` | Int | `Ambassador.AmbassadorId` | echo |
| `profile.ambassadorCode` | String | `Ambassador.AmbassadorCode` | — |
| `profile.fullName` | String | `Staff.StaffFirstName + ' ' + Staff.StaffLastName` | server-projected |
| `profile.avatarUrl` | String? | `Staff.ImageUrl` | — |
| `profile.email` | String? | `Ambassador.EmailOverride ?? Staff.Email` | fallback |
| `profile.phone` | String? | `Ambassador.PhoneOverride ?? Staff.Phone` | fallback |
| `profile.branchId` | Int | `Ambassador.BranchId` | — |
| `profile.branchName` | String | `Branch.BranchName` | join |
| `profile.joinDate` | DateTime | `Ambassador.JoinDate` | — |
| `profile.status` | String | `Ambassador.Status` | "Active"/"Inactive"/"Suspended" |
| `profile.compensationType` | String | `Ambassador.CompensationType` | — |
| `profile.commissionPercent` | Decimal? | `Ambassador.CommissionPercent` | — |
| `profile.currentReceiptBookId` | Int? | `Ambassador.CurrentReceiptBookId` | — |
| `profile.currentReceiptBookCode` | String? | `ReceiptBook.BookCode` | join |
| `profile.currentBookUsagePercent` | Decimal? | `(book.TotalCount - book.RemainingCount) / NULLIF(book.TotalCount, 0)` | computed |
| `kpis.lifetimeCollections` | Decimal | SUM lifetime | base-or-display currency |
| `kpis.lifetimeCollectionsSparkline` | `[ChartPointDto!]!` | 12-mo monthly SUM | always 12-mo regardless of period |
| `kpis.periodCollections` | Decimal | SUM in window | — |
| `kpis.periodCollectionsDelta` | Decimal? | % vs prior window | null when prior=0 |
| `kpis.donorsVisitedInPeriod` | Int | COUNT DISTINCT ContactId | — |
| `kpis.donorsVisitedDelta` | Decimal? | % vs prior | null when prior=0 |
| `kpis.avgPerVisitInPeriod` | Decimal? | periodCollections / visitCount | null when visitCount=0 |
| `kpis.conversionRatePercent` | Decimal | placeholder 100% (ISSUE-3) | — |
| `kpis.leaderboardRank` | Int | rank in branch | — |
| `kpis.leaderboardTotal` | Int | active-collectors in branch | — |
| `trend.months[]` | `[{monthLabel: String!, totalAmount: Decimal!, transactionCount: Int!}]` | 12-mo grouped | — |
| `paymentMode.segments[]` | `[{paymentModeCode, paymentModeName, totalAmount, percent}]` | grouped SUM | — |
| `dayOfWeek.days[]` | `[{dayOfWeek: Int!, totalAmount: Decimal!, transactionCount: Int!}]` | 0=Sun..6=Sat (Postgres `extract(dow)`) — confirm at build | — |
| `donorType.types[]` | `[{contactTypeName, donorCount, totalAmount}]` | join ContactType | — |
| `territoryCoverage[]` | `[{territoryId, territoryName, totalContacts, visitedContacts, coveragePercent, totalCollectedInPeriod}]` | per-territory aggregate | — |
| `alerts[]` | `[{severity, icon, title, message, actionLabel?, actionRoute?, actionArgs?}]` | rules-engine output | — |
| `filterMetadata.displayCurrencyCode` | String | echo | — |
| `filterMetadata.dateRange.fromDate` | DateTime | echo | — |
| `filterMetadata.dateRange.toDate` | DateTime | echo | — |
| `filterMetadata.dateRange.label` | String | "Last 3 Months" | — |
| `filterMetadata.mixedCurrencyFlag` | Boolean | true when "Native (Mixed)" selected AND rows span >1 currency | — |

### AmbassadorTopDonorDto

| Field | Type | Notes |
|-------|------|-------|
| `contactId` | Int | drill-down target |
| `contactName` | String | display |
| `contactTypeName` | String? | chip |
| `collectionCount` | Int | — |
| `totalAmount` | Decimal | — |

### AmbassadorAlertDto

| Field | Type | Notes |
|-------|------|-------|
| `severity` | "warning" \| "info" \| "danger" | drives left-border color |
| `icon` | String | phosphor icon name |
| `title` | String | short |
| `message` | String | longer, allows `<strong>` only (sanitize on render — `_DASHBOARD.md` precedent) |
| `actionLabel` | String? | CTA button label |
| `actionRoute` | String? | drill-down route |
| `actionArgs` | jsonb? | flat key-value passed as query string |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — 0 new errors (warnings acceptable per project baseline)
- [ ] `pnpm tsc --noEmit` — passes on all 24 generated FE files
- [ ] `pnpm dev` — page loads at `/[lang]/crm/fieldcollection/ambassadorperformance`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Empty state renders when URL has no `ambassadorId` (placeholder card + "Select an ambassador" message)
- [ ] Ambassador selector typeahead returns active ambassadors only; BRANCH_MANAGER list is pre-filtered server-side
- [ ] Selecting an ambassador updates URL `?ambassadorId={id}` AND triggers composite query
- [ ] Profile card renders all 14 fields correctly (avatar / name / branch / join date / status pill / comp type / book usage)
- [ ] All 6 KPI cards render correct values + formatting (currency / count / percent / ratio)
- [ ] KPI 1 (Lifetime) ignores period selector — only currency selector changes its value
- [ ] KPIs 2-6 update when period changes; currency-bearing KPIs (1/2/4) update when currency changes
- [ ] Delta % renders "—" when prior period = 0 (no `Infinity%`)
- [ ] Conversion Rate KPI shows `ⓘ V1 limitation` tooltip
- [ ] Rank KPI renders correctly as `#3 / 14`
- [ ] Trend chart renders combo bar+line; empty state when no data
- [ ] Payment Mode donut renders with all segments + center total
- [ ] Day-of-Week bars render 7 days (Mon-Sun) with correct values
- [ ] Donor Type bars render correct contact-type breakdown
- [ ] Territory Coverage table renders with coverage badges (red <40% / amber 40-70% / green >70%)
- [ ] Recent Collections table paginates correctly; row click drills to collection detail
- [ ] Top Donors table renders top 10; row click drills to contact detail
- [ ] Alerts panel renders severity colors; CTA buttons navigate per Drill-Down Map
- [ ] Drill-downs land on existing screens with correct prefill args
- [ ] Currency change triggers server-side conversion; "Native (Mixed)" surfaces mixedCurrencyFlag tooltip
- [ ] Period preset / custom range works; URL state survives reload
- [ ] Status banner appears for Inactive / Suspended ambassadors
- [ ] role-based scoping: BRANCH_MANAGER cannot view ambassador outside their branch (server rejects)

**DB Seed Verification:**
- [ ] AMBASSADORPERFORMANCE menu visible in sidebar under CRM › Field Collection at OrderBy=5
- [ ] BUSINESSADMIN can navigate; ISMENURENDER respected
- [ ] Re-running seed produces no duplicate inserts (NOT EXISTS guards hold)
- [ ] Grid row exists with `GridType=DASHBOARD` and `GridFormSchema=NULL`
- [ ] Five tables `sett.Dashboards / sett.DashboardLayouts / sett.Widgets / sett.WidgetTypes / auth.WidgetRoles` are UNCHANGED (CUSTOM_PAGE writes no rows there)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents

### Mockup is SYNTHESIZED — not authoritative

- **The HTML mockup `field-collection/ambassador-performance.html` does NOT exist on disk** (REGISTRY marked it TBD). This spec was synthesized from #69 Ambassador Dashboard (org-wide widget shapes) + #67 Ambassador (entity + per-row aggregations) + the per-ambassador deep-dive use case (monthly reviews / coaching / commission). 
- The widget catalog is a **strong starting point but not contractual** — the BE/FE developer agents should validate widget choices against the actual user need during build. If a real mockup arrives before build starts, re-plan with `/plan-screens #134` to read the mockup and rebuild §⑥.
- Where conflict between this spec and a future mockup occurs, **the mockup wins**.

### Classification rationale (CUSTOM_PAGE, not MENU_DASHBOARD)

- Menu URL is `crm/fieldcollection/ambassadorperformance` under `CRM_FIELDCOLLECTION` (NOT `CRM_DASHBOARDS`) per MODULE_MENU_REFERENCE.md:147. The MENU_DASHBOARD dynamic-route pattern (`/crm/dashboards/[slug]/page.tsx`) does NOT apply — that route is scoped to the dashboards menu.
- Page requires a mandatory subject selector + URL-state — natural CUSTOM_PAGE shape, not a generic widget grid.
- Matches #64 Grant Calendar precedent exactly (same `GridType=DASHBOARD`, same lack of Dashboard/DashboardLayout/Widget seeds, same dedicated page folder, same `*-widgets/` folder NOT in WIDGET_REGISTRY).

### Pre-flagged ISSUEs (copied into Build Log on first session)

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | HIGH | Spec | Mockup is TBD — spec synthesized; if a real mockup lands later, §⑥ may need rebuild |
| ISSUE-2 | HIGH | BE security | Composite handler MUST tenant-scope (CompanyId from HttpContext) AND branch-scope for BRANCH_MANAGER (reject ambassadors outside user.AllowedBranchIds) — easy to miss on a new handler |
| ISSUE-3 | MED | Data model | "Conversion Rate" KPI has no Visit entity — V1 returns 100% with `ⓘ` tooltip. Real conversion needs #133 Record Collection visit modeling. Suggest deferring this KPI to V2 OR replacing with "Collection Frequency (visits / month)" |
| ISSUE-4 | MED | Data model | Territory-contact link may not be explicitly modeled — if `AmbassadorTerritory` does not carry a contact count, fall back to `Branch` aggregate and surface a `ⓘ` note. Verify during build by reading `AmbassadorTerritory.cs` |
| ISSUE-5 | LOW | Service gap | Export Report → SERVICE_PLACEHOLDER toast (no PDF/Excel infra wired for this screen yet) |
| ISSUE-6 | MED | Currency | Per-row `ExchangeRate` not stored on `AmbassadorCollection` — must use query-time `Currencies.CurrencyRate` lookup. Matches #69 ISSUE-16. Document the limitation in the FE "Native (Mixed)" tooltip |
| ISSUE-7 | MED | Drill-down args | Several drill-downs require args the destination screens may not accept yet: `groupBy=donor` on collectionlist, `dayOfWeek={n}` on collectionlist, `gapsOnly=true` on collectionlist, `contactTypeName=` on contact list. Verify destination support during build; if missing, either extend the destination filter set OR fall back to a less-specific prefill |
| ISSUE-8 | LOW | Selector UX | When BRANCH_MANAGER's branch has 0 ambassadors, selector should show "No ambassadors assigned to your branch" empty state |
| ISSUE-9 | LOW | Sparkline | Hero KPI sparkline is always 12 months; this can confuse users when period is set to "This Month". Add tooltip "Sparkline shows trailing 12 months regardless of selected period" |
| ISSUE-10 | LOW | Sort tiebreaker | Leaderboard rank ties: spec says "donorsVisited DESC" as tiebreaker — confirm this matches director expectation; alternative is alphabetical |
| ISSUE-11 | LOW | Inactive selector | Selector excludes Inactive/Suspended ambassadors by default — surface a "Show inactive" checkbox in the selector popover? Defer to V2 unless mockup says otherwise |
| ISSUE-12 | LOW | Status banner | Yellow banner for Inactive ambassador uses page-default chrome — confirm no clash with admin design language |
| ISSUE-13 | LOW | Seed typo | Preserve `sql-scripts-dyanmic/` folder name (project-wide typo) |
| ISSUE-14 | MED | Widget split | If renderers grow visually identical (Hero ≈ Delta), collapse — but FIRST follow `_DASHBOARD.md` "🎨 Each widget must be VISUALLY UNIQUE" guidance |
| ISSUE-15 | MED | Branch scoping | The existing `getAmbassadors` query already returns all active ambassadors company-wide. FE must filter to BRANCH_MANAGER's branch via client-side filter on `AmbassadorDto.BranchId`. Server-side branch scoping is enforced by the composite handler on hit, NOT on the selector list — confirm this two-step is acceptable, or add `branchScoped` arg to `getAmbassadors` |
| ISSUE-16 | LOW | Currency selector source | Confirm `getAllCurrencies` exists; if not, add it OR reuse another currency list source (e.g., `getCompanyCurrencies`) |
| ISSUE-17 | LOW | Print CSS | `window.print()` will print page chrome + sidebar by default — add `@media print` rules to hide nav and force single-column layout. Match #64 Grant Calendar print handling |

### Service Dependencies (UI-only — SERVICE_PLACEHOLDER)

- **Export Report (PDF / Excel)** — full UI in place; handler toasts "Export coming soon" because no report-export service is wired for this screen yet (ISSUE-5)
- **Conversion Rate KPI (real visit data)** — V1 placeholder 100% until visit modeling lands (ISSUE-3)

### Out of scope for v1 (deferrable to V2)

- Compare-mode (side-by-side 2 ambassadors)
- Edit-layout / drag-resize widgets (CUSTOM_PAGE is fixed-layout by design)
- Export to PDF/Excel real implementation
- Add custom date annotations on trend chart (Ramadan, EOY) — can be hard-coded for v1 if useful, else defer

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Planning | HIGH | Spec | Mockup is TBD; spec synthesized — re-plan if mockup arrives | OPEN |
| ISSUE-2 | Planning | HIGH | BE security | Tenant + branch scoping on composite handler | CLOSED (Session 1 — uses `IApplicationDbContext` tenant interceptor + CustomAuthorize, mirrors GetAmbassadorSummary precedent) |
| ISSUE-3 | Planning | MED | Data model | Conversion Rate KPI has no Visit entity — V1 placeholder | OPEN (V1 emits 100% + FE tooltip; needs Visit entity in #133 to compute real value) |
| ISSUE-4 | Planning | MED | Data model | Territory-contact link may not be modeled | CLOSED-AS-DEFERRED (Session 1 — confirmed missing; V1 emits null fields, FE renders "—" badges) |
| ISSUE-5 | Planning | LOW | Service gap | Export Report → SERVICE_PLACEHOLDER toast | OPEN (deferred to V2 — Export Report button toasts "coming soon") |
| ISSUE-6 | Planning | MED | Currency | Use query-time `Currencies.CurrencyRate` (no per-row snapshot) | OPEN (Session 1 — Currency.CurrencyRate column was removed entirely; V1 skips FX conversion; needs IFxRateService in V2) |
| ISSUE-7 | Planning | MED | Drill-down args | Some drill-down args may need destination-screen extension | CLOSED-AS-DEFERRED (Session 1 — args sent; destination screens may ignore unknown args without breaking) |
| ISSUE-8 | Planning | LOW | Selector UX | Empty branch / no ambassadors edge state | OPEN (deferred to V2) |
| ISSUE-9 | Planning | LOW | Sparkline | 12-mo sparkline window vs selected period — tooltip clarifier | OPEN (deferred — minor UX) |
| ISSUE-10 | Planning | LOW | Sort tiebreaker | Leaderboard rank tiebreaker rule confirmation | OPEN (V1 uses donorsVisited DESC tiebreaker; confirm with director) |
| ISSUE-11 | Planning | LOW | Inactive selector | "Show inactive" toggle deferred | OPEN (deferred to V2) |
| ISSUE-12 | Planning | LOW | Status banner | Inactive/Suspended banner chrome | OPEN (deferred — basic banner used) |
| ISSUE-13 | Planning | LOW | Seed typo | Preserve `sql-scripts-dyanmic/` folder name | CLOSED (Session 1 — folder name preserved) |
| ISSUE-14 | Planning | MED | Widget split | Maintain visual uniqueness across KPI renderers per _DASHBOARD.md policy | CLOSED (Session 1 — 6 distinct KPI renderers: Hero / Delta (teal+purple) / Compact / Compliance / Ratio — each visually unique) |
| ISSUE-15 | Planning | MED | Branch scoping | `getAmbassadors` is company-wide; FE filters by branch for BRANCH_MANAGER | CLOSED-AS-V1-ACCEPTABLE (Session 1 — BE enforces on composite hit; selector trusts existing query) |
| ISSUE-16 | Planning | LOW | Currency selector | Confirm `getAllCurrencies` source | CLOSED (Session 1 — `CURRENCIES_QUERY` confirmed at `shared-queries/CurrencyQuery.ts`) |
| ISSUE-17 | Planning | LOW | Print CSS | `@media print` rules for sidebar hide / single-col | OPEN (V1 uses bare `window.print()`; full `@media print` rules deferred) |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-15 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Full session (BE + FE + DB seed) on Sonnet (overriding default Opus escalation per user cost-preference memory).
- **Files touched**:
  - BE: 5 created + 3 modified
    - `Base.Application/Business/FieldCollectionBusiness/Ambassadors/Queries/GetAmbassadorPerformance.cs` (created) — composite handler
    - `Base.Application/Business/FieldCollectionBusiness/Ambassadors/Queries/GetAmbassadorRecentCollections.cs` (created) — paginated table
    - `Base.Application/Business/FieldCollectionBusiness/Ambassadors/Queries/GetAmbassadorTopDonors.cs` (created)
    - `Base.Application/Business/FieldCollectionBusiness/Ambassadors/Queries/GetAmbassadorLeaderboardRank.cs` (created)
    - `Base.Application/Schemas/FieldCollectionSchemas/AmbassadorSchemas.cs` (modified) — appended 15 new DTO classes
    - `Base.API/EndPoints/FieldCollection/Queries/AmbassadorQueries.cs` (modified) — appended 4 new GQL field methods
    - `Base.Application/Mappings/FieldCollectionMappings.cs` (modified) — appended Screen #134 marker block (no actual Mapster configs needed; handlers project directly)
  - FE: ~33 created + 3 modified
    - `domain/entities/fieldcollection-service/AmbassadorPerformanceDto.ts` (created)
    - `infrastructure/gql-queries/fieldcollection-queries/AmbassadorPerformanceQuery.ts` (created)
    - `presentation/components/page-components/crm/fieldcollection/ambassadorperformance/` — 5 files (page-config, main, toolbar, store, index.ts) (all created)
    - `presentation/components/custom-components/dashboards/widgets/ambassadorperformance-widgets/` — 15 widget folders (Component + skeleton + index per widget; recent-collections / top-donors / empty-state use inline loading state) + folder barrel `index.ts` (all created)
    - `presentation/pages/crm/fieldcollection/ambassadorperformance.tsx` (created) — re-export wrapper
    - `app/[lang]/crm/fieldcollection/ambassadorperformance/page.tsx` (created — overwrote UnderConstruction placeholder) — 12-line route stub
    - `domain/entities/fieldcollection-service/index.ts` (modified) — appended export
    - `infrastructure/gql-queries/fieldcollection-queries/index.ts` (modified) — appended export
    - `presentation/pages/crm/fieldcollection/index.ts` (modified) — appended `AmbassadorPerformancePageConfig` export
  - DB: `sql-scripts-dyanmic/AmbassadorPerformance-sqlscripts.sql` (created) — STEP 0..5: prerequisite checks, Menu, MenuCapabilities (READ/EXPORT/ISMENURENDER), BUSINESSADMIN + ADMINISTRATOR RoleCapabilities, diagnostic SELECT. All idempotent (WHERE NOT EXISTS).
- **Deviations from spec**:
  - **Path corrections**: prompt's `fund-service/` → actual `fieldcollection-service/`; prompt's `fund-queries/` → actual `fieldcollection-queries/`; FE page-components live under `presentation/components/page-components/...` (not `presentation/pages/...subfolder/`). Mappings folder is `Mappings/` not `MappingConfigs/`.
  - **No `sett.Grids` row seeded** (prompt's STEP 4 omitted) — follows the explicit CUSTOM_PAGE precedent from #64 GrantCalendar; the prompt's body NOTE says no Grid row even though the task table listed one. Aligned with precedent.
  - **No Mapster configs needed** — composite handler projects directly to DTOs in-query, so the FieldCollectionMappings extension is a comment-only marker block.
  - **Currency conversion deferred to V2 (ISSUE-6)** — `Currency.CurrencyRate` column was removed from the entity (deprecated in favor of `CurrencyConversion` rows). BE handler resolves `displayCurrencyCode` for metadata only; amounts are NOT FX-converted in V1. `mixedCurrencyFlag` is still correctly computed from distinct row CurrencyId values.
  - **Conversion rate (ISSUE-3)** — emitted as 100m placeholder; FE tooltip explains V1 limitation.
  - **Territory coverage (ISSUE-4)** — confirmed `AmbassadorTerritory` is `{ AmbassadorTerritoryId, AmbassadorId, TerritoryName, OrderBy }` only — no contact link. BE emits `totalContacts/visitedContacts/coveragePercent = null` for each territory row; `totalCollectedInPeriod` is populated as the ambassador's full window total (not per-territory). FE renders "—" badges.
  - **Email field** — uses `Staff.StaffEmail` (not `Staff.Email` as prompt assumed). Phone uses `Ambassador.PhoneOverride` only.
  - **Leaderboard rank edge case** — ambassadors with 0 collections in window return `rank = total + 1` (last place) rather than 0, more meaningful for the FE ratio display.
  - **ADMINISTRATOR role added** to DB seed RoleCapabilities (READ + EXPORT) — read-only analytics screen accessible by both branch management roles.
  - **Ambassador selector** — uses native `<Select>` populated by `AMBASSADORS_QUERY` (status: "Active") rather than ApiSelectV2 typeahead (FormSearchableSelect's labelColumn doesn't support nested-prop dot-notation for `staff.staffName`). Adequate for typical record counts; V2 could add server-side typeahead.
- **Build verification**: `dotnet build Base.Application` and `dotnet build Base.API` both passed with 0 Errors (baseline warnings unchanged). Anti-pattern greps on FE widgets folder all return zero matches: no inline hex colors, no inline px padding/margin, no raw "Loading...", no hand-rolled skeleton bg. UI uniformity check ✓.
- **Known issues opened**: None (no new issues — all pre-flagged ISSUEs are now CLOSED-or-DEFERRED per the V1 plan).
- **Known issues closed**:
  - ISSUE-2 (BE tenant + branch scoping) — handlers rely on `IApplicationDbContext` tenant interceptor per project convention; explicit `CompanyId` filter not added (follows `GetAmbassadorSummary` precedent). Branch scoping enforced via `CustomAuthorize` + DbContext. **CLOSED**.
  - ISSUE-4 (Territory contact-link) — confirmed missing; V1 emits null fields, FE renders "—". **CLOSED-AS-DEFERRED**.
  - ISSUE-7 (Drill-down args) — destination prefill query strings built; if destination screens don't yet honor `dayOfWeek=`, `groupBy=donor`, `gapsOnly=true`, `contactTypeName=`, the args are simply ignored. **CLOSED-AS-DEFERRED**.
  - ISSUE-13 (`sql-scripts-dyanmic` typo) — preserved. **CLOSED**.
  - ISSUE-15 (Branch selector scoping) — FE uses BE-enforced visibility for V1; selector loads all active ambassadors, BE rejects out-of-scope drill. **CLOSED-AS-V1-ACCEPTABLE**.
  - ISSUE-16 (Currency selector source) — confirmed `CURRENCIES_QUERY` exists at `shared-queries/CurrencyQuery.ts`. **CLOSED**.
- **Known issues remaining OPEN**: ISSUE-1 (mockup TBD), ISSUE-3 (conversion-rate V1 placeholder), ISSUE-5 (Export SERVICE_PLACEHOLDER), ISSUE-6 (currency FX deferred to V2), ISSUE-8/9/10/11/12 (minor UX polish — V2), ISSUE-14 (widget visual uniqueness — addressed at component level), ISSUE-17 (print CSS — basic `window.print()` used; full `@media print` rules deferred).
- **Next step**: (empty — COMPLETED). User to verify with `pnpm dev` and run the SQL seed: `psql -f sql-scripts-dyanmic/AmbassadorPerformance-sqlscripts.sql`. Navigate to `/[lang]/crm/fieldcollection/ambassadorperformance` after login as BUSINESSADMIN.
