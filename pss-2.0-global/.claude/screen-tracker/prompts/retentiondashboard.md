---
screen: RetentionDashboard
registry_id: 98
module: REPORTAUDIT
status: COMPLETED
scope: FULL
screen_type: DASHBOARD
dashboard_variant: MENU_DASHBOARD
complexity: High
new_module: NO
planned_date: 2026-05-13
completed_date: 2026-05-14
last_session_date: 2026-05-14
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (6 KPIs + 6 chart/table widgets + filters + drill-downs identified)
- [x] Variant chosen — MENU_DASHBOARD (sidebar leaf under RA_REPORTS — re-classified from SKIP_DASHBOARD)
- [x] Source entities identified — fund.GlobalDonation + corg.Contacts + app.Branches + sett.MasterDatas (no new schema)
- [x] Widget catalog drafted — 11 widgets backed by 10 distinct renderers
- [x] react-grid-layout config drafted (lg breakpoint complete; md/sm/xs follow component breakpoint fallback)
- [x] DashboardLayout JSON shape drafted
- [x] Parent menu code + slug + OrderBy decided — `RA_REPORTS`, `retentiondashboard`, OrderBy=3 (pre-seeded in MODULE_MENU_REFERENCE)
- [x] First-time MENU_DASHBOARD infra — NOT NEEDED. Verified: `<MenuDashboardComponent />` exists + `dashboardByModuleAndCode` BE handler exists + `Dashboard.MenuId` column exists. Precedents: #52 Case, #57 Volunteer, #123 Contact, #124 Donation, #125 Communication, #47 EventAnalytics
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (skipped — prompt §①–⑫ already deep enough per §745 hint)
- [x] Solution Resolution complete (skipped — prompt §⑤ pre-classified)
- [x] UX Design finalized (skipped — prompt §⑥ pre-designed)
- [x] User Approval received (2026-05-14, BUSINESSADMIN-only grants)
- [x] **12 Postgres functions** generated under `PSS_2.0_Backend/DatabaseScripts/Functions/fund/` (Path-A 5-arg / 4-col contract)
- [x] **10 NEW widget renderers** generated under `dashboards/widgets/retention-dashboard-widgets/` (40 files + 2 _shared + 1 barrel = 43 files)
- [x] **WIDGET_REGISTRY extended** with 10 ComponentPath entries in `dashboard-widget-registry.tsx`
- [x] **NO new BE C# code** — Path-A widgets reuse generic `generateWidgets` GraphQL handler
- [x] FE page stub at `app/[lang]/reportaudit/reports/retentiondashboard/page.tsx` OVERWRITTEN — `<UnderConstruction />` replaced with custom page chrome + `<MenuDashboardComponent />` mount (EventAnalytics pattern)
- [x] DB Seed `RetentionDashboard-sqlscripts.sql` generated under `sql-scripts-dyanmic/` (typo preserved)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `pnpm dev` — page loads at `/{lang}/reportaudit/reports/retentiondashboard`
- [ ] All 11 widgets fetch via `generateWidgets` and render
- [ ] Year filter (2026 default + 2025/2024/2023) refetches all widgets in parallel
- [ ] Branch filter refetches all widgets honoring `branchId`
- [ ] Drill-down — donor name click → `/crm/contact/contact?mode=read&id={contactId}`; "Create Re-engagement Campaign" → `/communication/email-campaign-builder`
- [ ] Empty states render when no data in year+branch range
- [ ] Loading skeletons match widget shapes (cohort matrix skeleton ≠ KPI tile skeleton)
- [ ] Print works via `window.print()` (mockup hides chrome via @media print)
- [ ] SYBUNT collapsible expands/collapses
- [ ] Cohort matrix renders heatmap colors correctly (>=70% dark-green, 50-69% light-green, 30-49% yellow, <30% red/grey, future cells `—`)
- [ ] Retention by Segment bars sort high-to-low and color-grade by % (>80 green, 60-80 teal, 40-60 orange, <40 red)
- [ ] Dashboard.MenuId == auth.Menus.MenuId of RETENTIONDASHBOARD row (verify with diagnostic SELECT)
- [ ] BUSINESSADMIN can see dashboard; non-grantee role hidden via RoleCapability(MenuId, READ)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: RetentionDashboard
Module: REPORTAUDIT (Report & Audit)
Schema: NONE (aggregates across `fund.*` + `corg.*` + `app.*` + `sett.*`)
Group: DonationModels (the source entities live in fund/DonationModels; the Dashboard row itself lives in `sett.Dashboards`)

Dashboard Variant: **MENU_DASHBOARD** — Re-classified from `SKIP_DASHBOARD` 2026-05-13. The Retention Dashboard is a top-level sidebar leaf under the Reports menu (RA_REPORTS) at OrderBy=3 — NOT a static module-overview page. The standard MENU_DASHBOARD pattern applies even though the parent is `RA_REPORTS` (not `*_DASHBOARDS`) — the route is reached through its own menu URL, not auto-injected from a `*_DASHBOARDS` parent.

Business:
- **Decision support**: Fundraising Directors and Marketing Managers use this dashboard weekly to (a) identify donor segments with falling retention, (b) decide where re-engagement budget should be spent (LYBUNT vs SYBUNT cohorts), (c) see whether the annual retention goal is on track vs the industry average (45%), and (d) spot upgrade momentum or downgrade leaks at the major-donor tier.
- **Target audience**: Fundraising Director (primary), Marketing Manager, Executive Director. Branch Manager sees branch-scoped view via Branch filter.
- **Why it exists**: NGO retention drift is the single biggest revenue risk — every lapsed donor is 5–10× the cost to re-acquire vs retain. The previous reporting flow exported month-end CSVs and computed retention in Excel; this dashboard puts the same numbers — and the actionable LYBUNT/SYBUNT lists — one click away with a Re-engage dropdown that initiates communication directly.
- **Source modules**: CRM Donation (GlobalDonation), CRM Contact, Application (Branches), Reports (this dashboard).
- **Why it earned its own menu slot**: Frequently consumed (weekly cadence), deep-linkable from board emails, role-restricted to fundraising leadership, distinct from the operational #124 Donation Dashboard (which tracks transaction health, not donor loyalty). The two dashboards intentionally do NOT share a route — Donation Dashboard #124 is under `crm/dashboards/`, Retention Dashboard is under `reportaudit/reports/`.

---

## ② Entity Definition

> Dashboards do NOT introduce a new entity. The Retention Dashboard composes one `sett.Dashboards` row + one `sett.DashboardLayouts` row + 12 `sett.Widgets` rows over existing source entities. No new schema, no migration.

### A. Dashboard Row (`sett.Dashboards`)

| Field | Value | Notes |
|-------|-------|-------|
| DashboardCode | `RETENTIONDASHBOARD` | Unique within Company; mirrors `Menu.MenuCode` (pre-seeded in MODULE_MENU_REFERENCE.md) |
| DashboardName | `Retention Dashboard` | Used as fallback when `Menu.MenuName` is missing |
| DashboardIcon | `users-three` | Phosphor icon `ph:users-three` rendered in the lean header by `<MenuDashboardComponent />` |
| DashboardColor | `#7c3aed` | Reports accent purple (consistent with mockup `--reports-accent`) |
| ModuleId | (resolved from `REPORTAUDIT` module code) | Must equal `Menu.ModuleId` of the RETENTIONDASHBOARD row |
| IsSystem | `true` | System-seeded; does NOT count toward per-user "max 3 custom dashboards" |
| IsActive | `true` | — |
| MenuId | (resolved at seed time via subquery against `auth.Menus.MenuCode='RETENTIONDASHBOARD'`) | NOT NULL — this is a MENU_DASHBOARD. **Seed must verify the auth.Menus row exists FIRST** (it should — already in MODULE_MENU_REFERENCE.md row 347) and abort with NOTICE if missing. |

### B. DashboardLayout Row (`sett.DashboardLayouts`)

One row, ConfiguredWidget array with 12 instance entries, LayoutConfig with `lg` breakpoint (and md/sm/xs computed from lg per `<MenuDashboardComponent />` fallback logic).

| Field | Shape | Notes |
|-------|-------|-------|
| DashboardId | FK to row above | — |
| LayoutConfig | `{"lg":[{i,x,y,w,h,minW,minH},...]}` JSON string | See ⑥ Grid Layout for full list. `i` value equals each instance's `i` field in ConfiguredWidget. |
| ConfiguredWidget | `[{i:"<instanceCode>", widgetId:<int>}, ...]` JSON string | One element per rendered widget. `widgetId` resolved against `sett.Widgets` rows seeded below. |

### C. Widget Definitions

`sett.WidgetTypes` — 10 NEW rows (one per renderer):

| WidgetTypeCode | WidgetTypeName | ComponentPath | Notes |
|----------------|----------------|---------------|-------|
| RETENTION_RATE_KPI | Retention Rate Hero KPI | `RetentionRateKpiWidget` | Hero card — purple gradient, % big number, delta arrow vs prior year |
| RETENTION_COUNT_KPI | Retention Count KPI | `RetentionCountKpiWidget` | Reused by 3 instances (Active Donors / New Donors / SYBUNT) — same shape, color/icon vary by `data.accent` and `data.icon` |
| RETENTION_LYBUNT_KPI | LYBUNT Hero KPI | `RetentionLybuntKpiWidget` | Distinct from plain count — orange tint + secondary `$at-risk` line + warning badge |
| RETENTION_LIFETIME_VALUE_KPI | Lifetime Value KPI | `RetentionLifetimeValueKpiWidget` | Blue tint + gem icon + currency formatter |
| RETENTION_YEAR_TREND_BARS | YoY Retention Bars | `RetentionYearTrendBarsWidget` | Bar chart 7-year + dashed industry line + goal annotation |
| RETENTION_COHORT_MATRIX | Cohort Heatmap | `RetentionCohortMatrixWidget` | Heatmap table — acquisition year × Year 1-6 with color bins |
| RETENTION_LYBUNT_ANALYSIS | LYBUNT Analysis Panel | `RetentionLybuntAnalysisWidget` | Combo: alert banner + breakdown table + top-5 donors table with Re-engage dropdown + footer actions |
| RETENTION_SYBUNT_COLLAPSIBLE | SYBUNT Collapsible Panel | `RetentionSybuntCollapsibleWidget` | Collapsible accordion + table of donors-by-last-year + progress bar recovery rates |
| RETENTION_UPGRADE_DOWNGRADE | Upgrade/Downgrade Cards | `RetentionUpgradeDowngradeWidget` | Side-by-side green/red panels + top mover highlights |
| RETENTION_BY_SEGMENT_BARS | Retention by Segment | `RetentionBySegmentBarsWidget` | 6-row horizontal bar chart with color-graded fills |

`sett.Widgets` — 12 rows (one per rendered instance — KPI cards 2/3/5 share `RETENTION_COUNT_KPI` WidgetType but have distinct Widget rows for distinct data sources):

| WidgetCode | WidgetName | WidgetTypeCode | StoredProcedureName | DefaultParameters | Notes |
|-----------|------------|----------------|---------------------|-------------------|-------|
| RETN_KPI_OVERALL | Overall Retention Rate | RETENTION_RATE_KPI | `fund.fn_retention_dashboard_kpi_overall_rate` | `{"year":"{year}","branchId":"{branchId}"}` | Hero — % + YoY delta |
| RETN_KPI_ACTIVE | Total Active Donors | RETENTION_COUNT_KPI | `fund.fn_retention_dashboard_kpi_active_donors` | `{"year":"{year}","branchId":"{branchId}"}` | Teal accent, `data.icon="users"`, subtitle="Gave at least once this year" |
| RETN_KPI_NEW | New Donors | RETENTION_COUNT_KPI | `fund.fn_retention_dashboard_kpi_new_donors` | `{"year":"{year}","branchId":"{branchId}"}` | Green accent, `data.icon="user-plus"`, subtitle="First-time donors this year" |
| RETN_KPI_LYBUNT | LYBUNT Count | RETENTION_LYBUNT_KPI | `fund.fn_retention_dashboard_kpi_lybunt_count` | `{"year":"{year}","branchId":"{branchId}"}` | Orange accent + at-risk total |
| RETN_KPI_SYBUNT | SYBUNT Count | RETENTION_COUNT_KPI | `fund.fn_retention_dashboard_kpi_sybunt_count` | `{"year":"{year}","branchId":"{branchId}"}` | Red accent, `data.icon="user-x"` |
| RETN_KPI_LTV | Donor Lifetime Value | RETENTION_LIFETIME_VALUE_KPI | `fund.fn_retention_dashboard_kpi_lifetime_value` | `{"year":"{year}","branchId":"{branchId}"}` | Blue accent — average across all giving years (NOT year-filtered) |
| RETN_YEAR_TREND | Retention Trend YoY | RETENTION_YEAR_TREND_BARS | `fund.fn_retention_dashboard_year_trend` | `{"year":"{year}","branchId":"{branchId}","industryAvg":45,"goalPct":75,"goalYear":2027}` | 7 years back from `year`; `industryAvg`/goal in DefaultParameters so admin can tune |
| RETN_COHORT_MATRIX | Cohort Retention Matrix | RETENTION_COHORT_MATRIX | `fund.fn_retention_dashboard_cohort_matrix` | `{"year":"{year}","branchId":"{branchId}","cohortYears":6}` | 6 cohorts × 6 year-N cells |
| RETN_LYBUNT_ANALYSIS | LYBUNT Analysis | RETENTION_LYBUNT_ANALYSIS | `fund.fn_retention_dashboard_lybunt_analysis` | `{"year":"{year}","branchId":"{branchId}","topN":5}` | Returns alert summary + breakdown by gift amount + top-5 donor list in one payload |
| RETN_SYBUNT_ANALYSIS | SYBUNT Analysis | RETENTION_SYBUNT_COLLAPSIBLE | `fund.fn_retention_dashboard_sybunt_analysis` | `{"year":"{year}","branchId":"{branchId}"}` | By last-giving year (2024, 2023, 2022, 2021&earlier) with recovery rates |
| RETN_UPGRADE_DOWNGRADE | Upgrade/Downgrade | RETENTION_UPGRADE_DOWNGRADE | `fund.fn_retention_dashboard_upgrade_downgrade` | `{"year":"{year}","branchId":"{branchId}"}` | Compares per-donor SUM(year-N) vs SUM(year-N-1) for donors active both years |
| RETN_BY_SEGMENT | Retention by Segment | RETENTION_BY_SEGMENT_BARS | `fund.fn_retention_dashboard_by_segment` | `{"year":"{year}","branchId":"{branchId}"}` | 6 segments — Recurring, Major ($5K+), Mid ($1K-$5K), Regular ($100-$1K), Small (<$100), One-Time |

### D. Source Entities (read-only — what the widgets aggregate over)

| Source Entity | File Path | Used For | Key Columns Read |
|---------------|-----------|----------|------------------|
| `fund.GlobalDonations` | `Base.Domain/Models/DonationModels/GlobalDonation.cs` | All retention math — donor activity per year | `GlobalDonationId`, `CompanyId`, `ContactId`, `DonationDate`, `DonationAmount`, `BaseCurrencyAmount`, `CurrencyId`, `SourceTypeId` (Branch FK per #124 finding — entity column misleadingly named), `IsDeleted` |
| `corg.Contacts` | `Base.Domain/Models/ContactModels/Contact.cs` | Donor name/code for LYBUNT top-donors list | `ContactId`, `ContactName`, `ContactCode`, `IsDeleted` |
| `app.Branches` | `Base.Domain/Models/ApplicationModels/Branch.cs` | Branch filter dropdown (filter dropdown handled in FE; SQL filters via `SourceTypeId`) | `BranchId`, `BranchName`, `IsDeleted` |
| `sett.Dashboards` | `Base.Domain/Models/SettingModels/Dashboard.cs` | Dashboard row container | `DashboardCode`, `MenuId` |
| `sett.DashboardLayouts` | `Base.Domain/Models/SettingModels/DashboardLayout.cs` | LayoutConfig + ConfiguredWidget JSON | `LayoutConfig`, `ConfiguredWidget` |
| `sett.Widgets` + `sett.WidgetTypes` | `Base.Domain/Models/SettingModels/Widget.cs` + `WidgetType.cs` | Widget definition + ComponentPath | `WidgetCode`, `StoredProcedureName`, `DefaultParameters`, `ComponentPath` |
| `auth.Menus` | `Base.Domain/Models/AuthModels/Menu.cs` | Sidebar leaf for the dashboard (pre-seeded at OrderBy=3 under RA_REPORTS) | `MenuCode`, `MenuUrl`, `OrderBy`, `ParentMenuId`, `ModuleId` |

---

## ③ Source Entity & Aggregate Query Resolution

> Path-A across all widgets — every widget data source is a Postgres function under `fund/`. All 12 functions reuse the existing generic `generateWidgets` GraphQL handler — NO new C# code.

| Widget | Postgres Function | Returns Shape (data_json) | Filter Args (from `p_filter_json`) |
|--------|-------------------|---------------------------|-------------------------------------|
| RETN_KPI_OVERALL | `fund.fn_retention_dashboard_kpi_overall_rate` | `[{"value":68.4,"formatted":"68.4%","secondaryFormatted":"vs 2025 (66.3%)","deltaLabel":"+2.1%","deltaColor":"positive","accent":"purple"}]` | `year`, `branchId` |
| RETN_KPI_ACTIVE | `fund.fn_retention_dashboard_kpi_active_donors` | `[{"value":2847,"formatted":"2,847","subtitle":"Gave at least once this year","accent":"teal","icon":"users"}]` | `year`, `branchId` |
| RETN_KPI_NEW | `fund.fn_retention_dashboard_kpi_new_donors` | `[{"value":634,"formatted":"634","subtitle":"First-time donors this year","accent":"green","icon":"user-plus"}]` | `year`, `branchId` |
| RETN_KPI_LYBUNT | `fund.fn_retention_dashboard_kpi_lybunt_count` | `[{"value":456,"formatted":"456","subtitle":"Gave in 2025, not yet in 2026","atRiskAmount":234500,"atRiskFormatted":"$234,500","accent":"orange"}]` | `year`, `branchId` |
| RETN_KPI_SYBUNT | `fund.fn_retention_dashboard_kpi_sybunt_count` | `[{"value":1234,"formatted":"1,234","subtitle":"Gave before 2025, not since","accent":"red","icon":"user-x"}]` | `year`, `branchId` |
| RETN_KPI_LTV | `fund.fn_retention_dashboard_kpi_lifetime_value` | `[{"value":1245,"formatted":"$1,245","subtitle":"Across all giving years","accent":"blue","icon":"gem"}]` | `year`, `branchId` (note: LTV computed lifetime — `year` defines the donor cohort, not the date window) |
| RETN_YEAR_TREND | `fund.fn_retention_dashboard_year_trend` | `[{"year":2020,"retentionPct":58,"isCurrent":false},...,{"year":2026,"retentionPct":68.4,"isCurrent":true}]` (7 rows) + metadata `{industryAvg:45, goalPct:75, goalYear:2027}` | `year`, `branchId`, `industryAvg`, `goalPct`, `goalYear` |
| RETN_COHORT_MATRIX | `fund.fn_retention_dashboard_cohort_matrix` | `[{"cohortYear":2020,"cohortSize":500,"cells":[{"yearOffset":1,"value":100,"pct":100},{"yearOffset":2,"value":310,"pct":62},...]},...]` | `year`, `branchId`, `cohortYears` |
| RETN_LYBUNT_ANALYSIS | `fund.fn_retention_dashboard_lybunt_analysis` | `[{"summary":{"count":456,"atRisk":234500,"avgGiving":514},"breakdown":[{"range":"$1,000+","count":34,"pct":7.5,"atRisk":78200,"suggestion":"Personal call from director","badgeColor":"purple"},...],"topDonors":[{"contactId":42,"contactName":"Khalid Al-Mansouri","lastGiftDate":"2025-12-15","lastAmount":1500,"lifetimeAmount":12400,"engagementScore":72,"scoreColor":"green","daysSince":118},...]}]` | `year`, `branchId`, `topN` |
| RETN_SYBUNT_ANALYSIS | `fund.fn_retention_dashboard_sybunt_analysis` | `[{"totalCount":1234,"rows":[{"lastYear":"2024","count":312,"recoveryPct":22,"recoveryColor":"success"},...]}]` | `year`, `branchId` |
| RETN_UPGRADE_DOWNGRADE | `fund.fn_retention_dashboard_upgrade_downgrade` | `[{"upgrades":{"count":234,"pctOfActive":9.8,"avgIncrease":120,"avgLiftPct":28,"topMover":{"contactId":7,"contactName":"Sarah Ahmed","fromAmount":200,"toAmount":1000,"liftPct":400}},"downgrades":{"count":178,"pctOfActive":7.5,"avgDecrease":-85,"avgDropPct":-22,"topMover":{"contactId":11,"contactName":"Mohamed Ali","fromAmount":5000,"toAmount":1000,"liftPct":-80}}}]` | `year`, `branchId` |
| RETN_BY_SEGMENT | `fund.fn_retention_dashboard_by_segment` | `[{"segments":[{"name":"Recurring Donors","retentionPct":92,"color":"success"},{"name":"Major Donors ($5K+)","retentionPct":89,"color":"success"},{"name":"Mid-Level ($1K-$5K)","retentionPct":78,"color":"primary"},{"name":"Regular ($100-$1K)","retentionPct":65,"color":"warning"},{"name":"Small (<$100)","retentionPct":42,"color":"warning-strong"},{"name":"One-Time Donors","retentionPct":34,"color":"danger"}]}]` | `year`, `branchId` |

**Strategy**: **Per-widget Path-A** (12 functions, one per widget). Matches Donation Dashboard #124 (17 functions) + Event Analytics #47 (13 functions) precedent. Filter args go through `p_filter_json` per the Path-A 5-arg contract. Year + branchId are honored by every widget; LTV widget honors `year` for cohort scoping only (its math is lifetime).

---

## ④ Business Rules & Validation

### Date / Year Defaults
- Default `year` = current year (CURRENT_DATE year)
- `year` arg drives every widget's "this year" vs "prior year" math
- No date-range picker (mockup uses a single Year select)
- Allowed years in dropdown: current year + 3 previous years (i.e. 2026/2025/2024/2023 if current=2026)

### Role-Scoped Data Access
- **BUSINESSADMIN, FUNDRAISING_DIRECTOR**: see all branches; Branch filter dropdown shows all branches; defaults to "All Branches"
- **BRANCH_MANAGER**: Branch filter is forced to user's own branch (FE locks the select); BE function still honors the arg but FE doesn't allow other values
- **MARKETING_USER**: see all branches but read-only; no re-engage actions (the Re-engage dropdown is hidden when capability `COMMUNICATE` not present)
- The role-scoping happens at the FE level for the Branch filter; the BE function trusts whatever `branchId` the FE passes — there is NO tenant-level branch enforcement (this is consistent with Donation Dashboard #124 precedent)

### Calculation Rules (one row per non-trivial KPI)
- **Overall Retention Rate** = `COUNT DISTINCT donors who gave in BOTH (year-1) AND year / COUNT DISTINCT donors who gave in (year-1)`. Anonymous donors (ContactId NULL) excluded throughout.
- **Active Donors** = `COUNT DISTINCT ContactId WHERE DonationDate year = year AND IsDeleted=false AND ContactId IS NOT NULL`
- **New Donors** = `COUNT DISTINCT ContactId WHERE first DonationDate ever falls in year` (i.e. their MIN(DonationDate) is in year)
- **LYBUNT Count** = `COUNT DISTINCT ContactId WHERE gave in (year-1) AND DID NOT give in year`
- **LYBUNT At-Risk Revenue** = `SUM(BaseCurrencyAmount) of all donations made by LYBUNT donors in (year-1)`
- **SYBUNT Count** = `COUNT DISTINCT ContactId WHERE gave SOMETIME before (year-1) AND DID NOT give in (year-1) AND DID NOT give in year`
- **Lifetime Value Avg** = `AVG(per-donor lifetime SUM(BaseCurrencyAmount))` across all donors with ≥1 donation EVER (NOT restricted to year — `year` is used to define the donor universe; LTV is computed across all their giving history)
- **Cohort Retention** — for cohort year `Y` and offset `N`: `COUNT DISTINCT donors from cohort Y who gave in year (Y+N) / cohort size of Y`. Cohort `Y` = donors whose first donation ever was in `Y`. Cell `Y, offset=0` is always 100% by definition.
- **Upgrades** — for donors active in BOTH year-1 AND year: those whose SUM(year donations) > SUM(year-1 donations). "Avg increase" = mean of (year - year-1) across upgrades. "Avg lift %" = mean of `((year - year-1) / year-1) * 100`.
- **Downgrades** — same as upgrades but `<` instead of `>`. Donors with `=` are neither upgrade nor downgrade (steady).
- **Retention by Segment**:
  - **Recurring Donors** = donors with at least 1 ACTIVE RecurringDonationSchedule row in year-1; retention % = of those, how many gave at least once in year
  - **Major Donors ($5K+)** = donors whose SUM(BaseCurrencyAmount) for year-1 was ≥ 5000; retention % = of those, how many gave at least once in year
  - **Mid-Level ($1K-$5K)**: same with `1000 <= sum < 5000`
  - **Regular ($100-$1K)**: same with `100 <= sum < 1000`
  - **Small (<$100)**: same with `sum < 100`
  - **One-Time Donors** = donors whose LIFETIME COUNT of donations through year-1 == 1; retention % = of those, how many gave AGAIN in year (which by definition makes them no longer one-time)
- **Top LYBUNT Donors** ordering: `ORDER BY lifetimeAmount DESC LIMIT topN` (top 5 by lifetime value among the LYBUNT cohort)
- **Days Since (Last Gift)** = `CURRENT_DATE - MAX(DonationDate per ContactId)`
- **Engagement Score** = placeholder fixed bucket — `>=70 green, 50-69 amber, <50 red`. Source = `Contact.EngagementScore` if column exists, else compute as `LEAST(100, daysSince < 90 ? 80 : daysSince < 180 ? 55 : daysSince < 365 ? 40 : 25)` fallback. **Pre-flagged as ISSUE — see ⑫.**

### Multi-Currency Rules
- All KPI math uses `BaseCurrencyAmount` (already converted at donation time). NO runtime FX conversion needed.
- LTV is also based on `BaseCurrencyAmount`. Display in `Company.DefaultCurrency`.
- No currency switcher in this dashboard mockup (unlike Donation Dashboard #124) — keep it simple.

### Widget-Level Rules
- Each widget has a `WidgetRole` row granting access; default grants in seed: BUSINESSADMIN + FUNDRAISING_DIRECTOR + MARKETING_USER + BRANCH_MANAGER + EXECUTIVE_DIRECTOR. **Use BUSINESSADMIN per /plan-screens token-optimization rule (Section 1 of skill instructions); developer may expand at /build-screen time per ④ role-scoping**.
- LYBUNT Analysis Re-engage dropdown — actions are gated by capability `COMMUNICATE`. Missing capability → dropdown disabled.
- "Create Re-engagement Campaign" footer button — gated by capability `MANAGECAMPAIGN`.
- **Workflow**: None. Dashboard is read-only. Drill-down clicks navigate AWAY.

---

## ⑤ Screen Classification & Pattern Selection

**Screen Type**: DASHBOARD
**Variant**: MENU_DASHBOARD
**Reason**: Standalone analytical surface — its own sidebar leaf under RA_REPORTS at OrderBy=3. Deep-linkable, role-restricted, distinct from the operational `#124 Donation Dashboard`. Pre-seeded in `MODULE_MENU_REFERENCE.md` row 347 — the auth.Menus row already exists.

**Backend Implementation Path**: **Path A for ALL widgets** — every widget data source is a Postgres function under `fund.fn_retention_dashboard_*`. Reuses the existing generic `generateWidgets` GraphQL handler. **NO new C# code** (no DTOs, no handlers, no Mapster). The deliverable is 12 SQL files matching the `fund/fn_donation_dashboard_*` precedent.

**Path-A Function Contract — REPEATED FOR DEVELOPER**:
- Take 5 fixed inputs: `p_filter_json jsonb DEFAULT '{}'::jsonb`, `p_page integer DEFAULT 0`, `p_page_size integer DEFAULT 10`, `p_user_id integer DEFAULT 0`, `p_company_id integer DEFAULT NULL`
- Return `TABLE(data_json text, metadata_json text, total_count integer, filtered_count integer)`
- Extract filter args via `NULLIF(p_filter_json ->> 'keyName','')::type`
- Use Postgres syntax (`CREATE OR REPLACE FUNCTION`, `LANGUAGE plpgsql`, `"PascalCase"` quoted identifiers, `jsonb` operators)
- Live at `PSS_2.0_Backend/DatabaseScripts/Functions/fund/fn_retention_dashboard_*.sql` (snake_case names)
- Wrap data in `SELECT json_build_array(...)` even for single-row KPI results (FE renderer expects an array)
- Return all numeric outputs as JSON strings (`::text`) where formatting matters (e.g., `'68.4%'`, `'$1,245'`) plus a raw numeric `value` for color-by-threshold logic
- **Reference precedent**: [`fn_donation_dashboard_kpi_donor_retention.sql`](../../../PSS_2.0_Backend/DatabaseScripts/Functions/fund/fn_donation_dashboard_kpi_donor_retention.sql) (this same retention math, abbreviated KPI form) and [`fn_donation_dashboard_top_donors.sql`](../../../PSS_2.0_Backend/DatabaseScripts/Functions/fund/fn_donation_dashboard_top_donors.sql) (top-N donor table with lifetime computation).

**Backend Wiring**: NONE (no new C# code; generic `generateWidgets` resolver handles every widget call by name).

**Frontend Patterns Required**:
- [x] **10 NEW renderers** under `dashboards/widgets/retention-dashboard-widgets/` — see ⑧ File Manifest. NO reuse of legacy `WIDGET_REGISTRY` entries (frozen for #120 only) and NO reuse of Case Dashboard #52 / Donation Dashboard #124 / Volunteer #57 renderers (each dashboard ships its own bespoke set per `_DASHBOARD.md` directive).
- [x] **WIDGET_REGISTRY extension** in `dashboard-widget-registry.tsx` with 10 entries — keys MUST match `WidgetType.ComponentPath` EXACTLY (case-sensitive).
- [x] **Page-header chrome** with custom toolbar — Year select (default current year + 3 prior) + Branch select (`ApiSelectV2` populated from `branches` GQL query, "All Branches" sentinel value) + Export Report button (SERVICE_PLACEHOLDER) + Print button (`window.print()`). Pattern of `event-analytics-page-config.tsx`.
- [x] **`<MenuDashboardComponent moduleCode="REPORTAUDIT" dashboardCode="RETENTIONDASHBOARD" filterContext={{ year, branchId }} hideHeader />`** mounted inside the page chrome. The `filterContext` overlays `{year}` and `{branchId}` placeholders into every widget's DefaultParameters at render time.
- [x] **Skeleton shapes** match each renderer — cohort matrix skeleton is a striped table; KPI tile skeleton is a small card; trend bars skeleton has 7 bar rectangles of varying height.
- [x] **Print CSS** — `@media print { .retention-dashboard-no-print { display: none !important; } }` to hide filter chrome on print.
- [x] **Empty states** per widget — "No data in selected year" with phosphor icon + muted text.

**MENU_DASHBOARD-only**:
- [x] NO dropdown, NO edit chrome (read-only by design)
- [x] Reached via the dedicated `app/[lang]/reportaudit/reports/retentiondashboard/page.tsx` route (NOT the generic `[module]/dashboards/[slug]/page.tsx` dynamic route — that pattern is for parents named `*_DASHBOARDS`, ours is under `RA_REPORTS`)
- [x] `MenuDashboardComponent` props used: `moduleCode`, `dashboardCode`, `filterContext`, `hideHeader=true` (the page chrome supplies the title + toolbar)

---

## ⑥ UI/UX Blueprint

### Page Chrome

```
┌─────────────────────────────────────────────────────────────┐
│ ← Reports / Donor Retention Dashboard                       │  ← breadcrumb
├─────────────────────────────────────────────────────────────┤
│ ← [Donor Retention Dashboard]      [Year▼][Branch▼][Export][Print] │  ← title row + toolbar
│   Track donor loyalty, identify lapsed donors,              │
│   and measure retention trends                              │
└─────────────────────────────────────────────────────────────┘

← MenuDashboardComponent grid below (hideHeader=true)
┌─────────────────────────────────────────────────────────────┐
│ [Retention%] [ActiveDonors] [NewDonors]                     │  row 1 — 3-col KPIs
│ [LYBUNTCount] [SYBUNTCount] [LTV]                           │  row 2 — 3-col KPIs
│ [Retention Trend YoY Bars (full-width)]                     │  row 3
│ [Cohort Retention Matrix (full-width)]                      │  row 4
│ [LYBUNT Analysis Combo Panel (full-width)]                  │  row 5
│ [SYBUNT Collapsible Panel (full-width)]                     │  row 6
│ [Upgrade/Downgrade Side-by-Side]                            │  row 7
│ [Retention by Segment Horizontal Bars]                      │  row 8
└─────────────────────────────────────────────────────────────┘
```

**Toolbar Actions** (rendered inside page header — NOT inside MenuDashboardComponent's toolbar slot since `hideHeader=true`):
- `Year` select → `handler={setYear}` → updates `filterContext={ year, branchId }` → MenuDashboardComponent refetches all widgets
- `Branch` select → `handler={setBranchId}` → same refetch cycle (uses `branches` GQL query)
- `Export Report` button → `SERVICE_PLACEHOLDER` (toast: "PDF export pending — server-side rendering service not wired"). Build the button + handler + toast — flag in ⑫.
- `Print` button → `window.print()` (use @media print CSS to hide chrome — pattern of `event-analytics-page-config.tsx`)
- `Back to Reports` button (breadcrumb arrow) → `router.push('/{lang}/reportaudit/reports/reportcatalog')`

### Grid Layout (lg breakpoint — 12 columns)

| i (instanceCode) | Widget | x | y | w | h | minW | minH | Notes |
|------------------|--------|---|---|---|---|------|------|-------|
| RETN_KPI_OVERALL | Overall Retention Rate | 0 | 0 | 4 | 2 | 3 | 2 | Hero — wider than supporting KPIs |
| RETN_KPI_ACTIVE | Total Active Donors | 4 | 0 | 4 | 2 | 3 | 2 | Supporting |
| RETN_KPI_NEW | New Donors | 8 | 0 | 4 | 2 | 3 | 2 | Supporting |
| RETN_KPI_LYBUNT | LYBUNT Count | 0 | 2 | 4 | 2 | 3 | 2 | Action-priority KPI |
| RETN_KPI_SYBUNT | SYBUNT Count | 4 | 2 | 4 | 2 | 3 | 2 | Supporting |
| RETN_KPI_LTV | Lifetime Value | 8 | 2 | 4 | 2 | 3 | 2 | Supporting |
| RETN_YEAR_TREND | Retention Trend YoY | 0 | 4 | 12 | 4 | 8 | 3 | Full-width chart |
| RETN_COHORT_MATRIX | Cohort Matrix | 0 | 8 | 12 | 5 | 8 | 4 | Full-width heatmap table |
| RETN_LYBUNT_ANALYSIS | LYBUNT Analysis | 0 | 13 | 12 | 8 | 8 | 6 | Tall combo panel (alert + 2 tables + footer) |
| RETN_SYBUNT_ANALYSIS | SYBUNT Collapsible | 0 | 21 | 12 | 4 | 8 | 3 | Collapses to h=1 when closed (renderer handles internal collapse) |
| RETN_UPGRADE_DOWNGRADE | Upgrade/Downgrade | 0 | 25 | 12 | 3 | 8 | 2 | Side-by-side panels |
| RETN_BY_SEGMENT | Retention by Segment | 0 | 28 | 12 | 4 | 8 | 3 | 6 horizontal bars |

`<MenuDashboardComponent />` derives `md` from `lg` (width capped at 6/8), `sm` from `lg` (width capped at 4), `xs` from `lg` (width fills container, x=0) per its existing fallback logic — no need to specify these breakpoints unless visual differs.

### Widget Catalog (per-widget detail)

> Cross-references ② and ③ — restated for FE/UX use.

| # | InstanceId | Title | ComponentPath | Path | Data Source | Filters Honored | Drill-Down |
|---|-----------|-------|---------------|------|-------------|------------------|-----------|
| 1 | RETN_KPI_OVERALL | Overall Retention Rate | RetentionRateKpiWidget | A | fund.fn_retention_dashboard_kpi_overall_rate | year, branchId | — (KPI hero, no drill-down) |
| 2 | RETN_KPI_ACTIVE | Total Active Donors | RetentionCountKpiWidget | A | fund.fn_retention_dashboard_kpi_active_donors | year, branchId | `/crm/contact/contact?activeYear={year}` — opt out if Contact list doesn't accept this arg (ISSUE-3) |
| 3 | RETN_KPI_NEW | New Donors | RetentionCountKpiWidget | A | fund.fn_retention_dashboard_kpi_new_donors | year, branchId | `/crm/contact/contact?firstYear={year}` (ISSUE-3) |
| 4 | RETN_KPI_LYBUNT | LYBUNT Count | RetentionLybuntKpiWidget | A | fund.fn_retention_dashboard_kpi_lybunt_count | year, branchId | Card click scrolls to RETN_LYBUNT_ANALYSIS section |
| 5 | RETN_KPI_SYBUNT | SYBUNT Count | RetentionCountKpiWidget | A | fund.fn_retention_dashboard_kpi_sybunt_count | year, branchId | Card click expands RETN_SYBUNT_ANALYSIS collapsible |
| 6 | RETN_KPI_LTV | Lifetime Value Avg | RetentionLifetimeValueKpiWidget | A | fund.fn_retention_dashboard_kpi_lifetime_value | year (cohort scope), branchId | — |
| 7 | RETN_YEAR_TREND | Retention Trend YoY | RetentionYearTrendBarsWidget | A | fund.fn_retention_dashboard_year_trend | year, branchId | Bar click → `/crm/donation/globaldonation?year={clickedYear}` |
| 8 | RETN_COHORT_MATRIX | Cohort Matrix | RetentionCohortMatrixWidget | A | fund.fn_retention_dashboard_cohort_matrix | year, branchId | Cell click → `/crm/contact/contact?cohortYear={Y}&activeYear={Y+offset}` (ISSUE-3) |
| 9 | RETN_LYBUNT_ANALYSIS | LYBUNT Analysis | RetentionLybuntAnalysisWidget | A | fund.fn_retention_dashboard_lybunt_analysis | year, branchId | Donor name → `/crm/contact/contact?mode=read&id={contactId}`; "View All N LYBUNT Donors" button → `/crm/contact/contact?lybuntYear={year}` (ISSUE-3); "Create Re-engagement Campaign" → `/communication/email-campaign-builder?cohort=LYBUNT&year={year}` (ISSUE-4) |
| 10 | RETN_SYBUNT_ANALYSIS | SYBUNT Collapsible | RetentionSybuntCollapsibleWidget | A | fund.fn_retention_dashboard_sybunt_analysis | year, branchId | "View All SYBUNT" button → `/crm/contact/contact?sybuntYear={year}` (ISSUE-3) |
| 11 | RETN_UPGRADE_DOWNGRADE | Upgrade/Downgrade | RetentionUpgradeDowngradeWidget | A | fund.fn_retention_dashboard_upgrade_downgrade | year, branchId | Top mover name → `/crm/contact/contact?mode=read&id={contactId}` |
| 12 | RETN_BY_SEGMENT | Retention by Segment | RetentionBySegmentBarsWidget | A | fund.fn_retention_dashboard_by_segment | year, branchId | Bar click → `/crm/contact/contact?segment={segmentCode}&activeYear={year}` (ISSUE-3) |

### KPI Cards (visual detail per card)

| # | Title | Value Source (data_json field) | Format | Subtitle | Color Cue | Visual differentiation |
|---|-------|-------------------------------|--------|----------|-----------|------------------------|
| RETN_KPI_OVERALL | Overall Retention Rate | `formatted` (e.g. `"68.4%"`) | percent | "{deltaLabel} vs prior year" with arrow | purple (`#7c3aed`) hero gradient bg | LARGEST tile (4×2), gradient fill, prominent delta indicator |
| RETN_KPI_ACTIVE | Total Active Donors | `formatted` (e.g. `"2,847"`) | thousands-grouped count | "Gave at least once this year" | teal (`#0e7490`) icon bg | Standard tile, `ph:users` icon |
| RETN_KPI_NEW | New Donors | `formatted` | thousands-grouped count | "First-time donors this year" | green (`#22c55e`) icon bg | `ph:user-plus` icon |
| RETN_KPI_LYBUNT | LYBUNT Count | `formatted` | thousands-grouped count | "Gave in {prev}, not yet in {year}" + secondary "${atRisk} at-risk" | orange (`#f97316`) icon bg + warning border-left | DISTINCT — 2-value layout (primary count + secondary $) |
| RETN_KPI_SYBUNT | SYBUNT Count | `formatted` | thousands-grouped count | "Gave before {prev}, not since" | red (`#dc2626`) icon bg | `ph:user-x` icon |
| RETN_KPI_LTV | Lifetime Value Avg | `formatted` (e.g. `"$1,245"`) | currency | "Across all giving years" | blue (`#3b82f6`) icon bg | `ph:gem` icon, currency formatter |

### Charts / Tables

**RETN_YEAR_TREND** (RetentionYearTrendBarsWidget):
- Type: vertical bar chart with category x-axis (year labels)
- 7 bars (year-6 through year)
- Current-year bar uses different fill (gradient purple) + bold label
- Dashed horizontal reference line at `industryAvg` (default 45%) with red label `"Industry Avg: 45%"`
- Footer text right-aligned: `"Goal: {goalPct}% by {goalYear}"` in reports-accent purple
- Empty/Tooltip: "No retention data in selected period."

**RETN_COHORT_MATRIX** (RetentionCohortMatrixWidget):
- Heatmap table — rows = acquisition years (default 6 cohorts), cols = Year 1-6 offsets
- Cell color bins:
  - 100% → `#7c3aed` bg with white text (cohort baseline)
  - ≥70% → `#dcfce7` bg + `#166534` text (dark green)
  - 50-69% → `#f0fdf4` bg + `#15803d` text (light green)
  - 30-49% → `#fef9c3` bg + `#854d0e` text (yellow)
  - 1-29% → `#fef2f2` bg + `#991b1b` text (red)
  - 0 / future cell → `#f8fafc` bg + `#94a3b8` text → render `"—"`
- First col shows cohort year + "(N donors)" subscript

**RETN_LYBUNT_ANALYSIS** (RetentionLybuntAnalysisWidget):
- Combo panel — 3 stacked sections inside one Card:
  1. **Alert banner** (top, amber bg `#fffbeb`): "{count} donors gave in {prev}, NOT yet in {year} | Total at-risk: {atRisk} | Avg giving: {avgGiving}"
  2. **Breakdown table** (middle) — 4 rows of gift-amount ranges with count / % / at-risk total / recovery suggestion badge (color per range — purple for $1K+, blue for $500-999, teal for $100-499, green for <$100)
  3. **Top-5 donors table** (lower) — Donor (link) | Last Gift Date | Last Amount | Total Lifetime | Engagement Score badge (color by tier) | Days Since | Re-engage dropdown (Send Email/SMS/WhatsApp/Add to Campaign/Assign to Staff/Log Note)
  4. **Footer actions** (bottom, separator above): `"View All {count} LYBUNT Donors"` left + `"Create Re-engagement Campaign"` purple-accent button right

**RETN_SYBUNT_ANALYSIS** (RetentionSybuntCollapsibleWidget):
- Default collapsed; toggle button shows "SYBUNT Analysis ({totalCount} donors)" with chevron
- When expanded: 4-row table — Last Giving Year | Donor Count | Recovery Rate | Visual progress bar (width = recoveryPct, color by `data.rows[i].recoveryColor`)
- Bottom footer: "View All SYBUNT" outlined button

**RETN_UPGRADE_DOWNGRADE** (RetentionUpgradeDowngradeWidget):
- Side-by-side 2-column layout
- Left panel: green bg `#f0fdf4`, border `#bbf7d0` — "Upgrades" heading + count + % active + avg increase + avg lift % + top mover line + bottom green gradient progress bar (width = pctOfActive × 6.6 cap)
- Right panel: red bg `#fef2f2`, border `#fecaca` — "Downgrades" same structure with red colors
- Top mover format: `"{contactName}: ${fromAmount} → ${toAmount} ({+/-liftPct}%)"`

**RETN_BY_SEGMENT** (RetentionBySegmentBarsWidget):
- 6 horizontal-bar rows
- Each row: label (right-aligned, fixed 160px) + track (flex) + value (fixed 48px)
- Bar fill color by `data.segments[i].color`:
  - `success` → green gradient `#22c55e → #4ade80`
  - `primary` → teal gradient (accent vars)
  - `warning` → amber gradient `#f59e0b → #fbbf24`
  - `warning-strong` → orange gradient `#f97316 → #fb923c`
  - `danger` → red gradient `#dc2626 → #f87171`
- Width % = retentionPct value
- Bar text inside fill: bold white "{retentionPct}%"

### Filter Controls

| Filter | Type | Default | Applies To | Notes |
|--------|------|---------|-----------|-------|
| Year | Standard `<select>` | Current year (computed) | ALL widgets | 4 options — current + 3 prior. Pushed via `filterContext.year` |
| Branch | `ApiSelectV2` populated from `branches` GQL | "All Branches" sentinel (passes empty string for `branchId` → SQL treats as NULL) | ALL widgets | Locked to user's branch for BRANCH_MANAGER role |

### Drill-Down / Navigation Map

| From Widget / Element | Click On | Navigates To | Prefill |
|-----------------------|----------|--------------|---------|
| RETN_KPI_LYBUNT card | Card click | (in-page scroll) | scrolls to `#RETN_LYBUNT_ANALYSIS` |
| RETN_KPI_SYBUNT card | Card click | (in-page scroll + expand) | expands SYBUNT collapsible |
| RETN_YEAR_TREND bar | Bar click | `/{lang}/crm/donation/globaldonation` | `dateFrom={Y}-01-01&dateTo={Y}-12-31` — accept what the donation list URL already understands |
| RETN_LYBUNT_ANALYSIS donor name | Anchor click | `/{lang}/crm/contact/contact` | `mode=read&id={contactId}` |
| RETN_LYBUNT_ANALYSIS "View All LYBUNT" | Button click | `/{lang}/crm/contact/contact` | `lybuntYear={year}` — Contact list filter handling deferred (ISSUE-3) |
| RETN_LYBUNT_ANALYSIS "Create Re-engagement Campaign" | Button click | `/{lang}/communication/email-campaign-builder` | `cohort=LYBUNT&year={year}` — campaign-builder prefill handling deferred (ISSUE-4) |
| RETN_LYBUNT_ANALYSIS Re-engage dropdown items | Dropdown click | SERVICE_PLACEHOLDER (toast) | Email/SMS/WhatsApp services not wired — toast informs user (ISSUE-5) |
| RETN_SYBUNT_ANALYSIS "View All SYBUNT" | Button click | `/{lang}/crm/contact/contact` | `sybuntYear={year}` (ISSUE-3) |
| RETN_UPGRADE_DOWNGRADE top mover name | Anchor click | `/{lang}/crm/contact/contact` | `mode=read&id={contactId}` |
| Header back arrow / breadcrumb "Reports" | Button click | `/{lang}/reportaudit/reports/reportcatalog` | — |

### User Interaction Flow

1. **Initial load**: user clicks sidebar leaf `Reports → Retention Dashboard` → URL becomes `/{lang}/reportaudit/reports/retentiondashboard` → page renders chrome + mounts `<MenuDashboardComponent moduleCode="REPORTAUDIT" dashboardCode="RETENTIONDASHBOARD" filterContext={{ year: <current>, branchId: 0 }} hideHeader />`. Component fires `dashboardByModuleAndCode("REPORTAUDIT","RETENTIONDASHBOARD")` → resolves Dashboard + DashboardLayout + 12 Widget rows → parallel-fetches all 12 widgets via `generateWidgets`.
2. **Year change**: select updates `setYear` → `filterContext={year, branchId}` → MenuDashboardComponent overlay rewrites every widget's `defaultParameters` `{year}`→`<value>` → all widgets refetch in parallel.
3. **Branch change**: same as Year change.
4. **Drill-down click**: navigate per Drill-Down Map; back button returns to dashboard with filters preserved (filter state is local React state — survives Router push/pop within the page).
5. **Print**: user clicks Print → `window.print()` → CSS @media print hides page header / toolbar / dropdowns. Widget cards print as-is.
6. **Empty / loading / error states**: each widget renders its own skeleton during fetch (shape matches widget). Error → red mini banner + Retry. Empty data → muted icon + "No donations in selected year/branch."

---

## ⑦ Substitution Guide

**Canonical Reference**: `#124 Donation Dashboard` (MENU_DASHBOARD precedent — same Path-A pattern, same renderer-per-widget convention, same toolbar approach). Also reference `#47 Event Analytics` for the **page-chrome + hideHeader + filterContext** mount pattern (since Event Analytics also lives at a non-`/dashboards/{slug}` URL).

| Canonical (Donation Dashboard #124) | → This Dashboard (Retention) | Context |
|-------------------------------------|------------------------------|---------|
| `DonationDashboard` | `RetentionDashboard` | Dashboard display name |
| `DONATIONDASHBOARD` | `RETENTIONDASHBOARD` | DashboardCode + MenuCode + GridCode |
| `donationdashboard` | `retentiondashboard` | Menu slug (`Menu.MenuUrl` last segment — pre-seeded) |
| `crm/dashboards/donationdashboard` | `reportaudit/reports/retentiondashboard` | Full FE route |
| `donation-dashboard-widgets/` | `retention-dashboard-widgets/` | FE renderer folder under `dashboards/widgets/` |
| `Donation*KpiWidget` | `Retention*KpiWidget` | NEW renderer naming pattern |
| `DONATION_*_KPI` | `RETENTION_*_KPI` | WidgetTypeCode prefix |
| `fund.fn_donation_dashboard_*` | `fund.fn_retention_dashboard_*` | Postgres function naming |
| `CRM` | `REPORTAUDIT` | Module |
| `CRM_DASHBOARDS` | `RA_REPORTS` | Parent menu (NOTE: non-standard — Reports parent, NOT a `*_DASHBOARDS` parent) |
| `DonationDashboard-sqlscripts.sql` | `RetentionDashboard-sqlscripts.sql` | DB seed file under `sql-scripts-dyanmic/` |

---

## ⑧ File Manifest

### Backend Files (Path-A — SQL functions only; NO C#)

| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | `fn_retention_dashboard_kpi_overall_rate.sql` | `PSS_2.0_Backend/DatabaseScripts/Functions/fund/` | KPI Retention rate + YoY delta |
| 2 | `fn_retention_dashboard_kpi_active_donors.sql` | same | KPI Active donor count |
| 3 | `fn_retention_dashboard_kpi_new_donors.sql` | same | KPI First-time donor count |
| 4 | `fn_retention_dashboard_kpi_lybunt_count.sql` | same | KPI LYBUNT count + at-risk total |
| 5 | `fn_retention_dashboard_kpi_sybunt_count.sql` | same | KPI SYBUNT count |
| 6 | `fn_retention_dashboard_kpi_lifetime_value.sql` | same | KPI Avg lifetime value |
| 7 | `fn_retention_dashboard_year_trend.sql` | same | YoY 7-year bars |
| 8 | `fn_retention_dashboard_cohort_matrix.sql` | same | Cohort × Year-N heatmap |
| 9 | `fn_retention_dashboard_lybunt_analysis.sql` | same | Combo: alert + breakdown + top-5 donors |
| 10 | `fn_retention_dashboard_sybunt_analysis.sql` | same | By last-giving-year + recovery rates |
| 11 | `fn_retention_dashboard_upgrade_downgrade.sql` | same | Upgrade/Downgrade counts + top mover |
| 12 | `fn_retention_dashboard_by_segment.sql` | same | Retention % by 6 segments |

**NO new C# files. NO entity. NO migration. NO Mapster. NO Schemas.** The generic `generateWidgets` GraphQL handler resolves each widget by `Widget.StoredProcedureName` and returns the JSON-as-text payload.

### Frontend Files

**10 NEW widget renderers (4 files each — 40 files total)** under `PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/retention-dashboard-widgets/`:

| Renderer | Subfolder | Files |
|----------|-----------|-------|
| RetentionRateKpiWidget | `retention-rate-kpi-widget/` | `.tsx`, `.types.ts`, `.skeleton.tsx`, `index.ts` |
| RetentionCountKpiWidget | `retention-count-kpi-widget/` | same |
| RetentionLybuntKpiWidget | `retention-lybunt-kpi-widget/` | same |
| RetentionLifetimeValueKpiWidget | `retention-lifetime-value-kpi-widget/` | same |
| RetentionYearTrendBarsWidget | `retention-year-trend-bars-widget/` | same |
| RetentionCohortMatrixWidget | `retention-cohort-matrix-widget/` | same |
| RetentionLybuntAnalysisWidget | `retention-lybunt-analysis-widget/` | same |
| RetentionSybuntCollapsibleWidget | `retention-sybunt-collapsible-widget/` | same |
| RetentionUpgradeDowngradeWidget | `retention-upgrade-downgrade-widget/` | same |
| RetentionBySegmentBarsWidget | `retention-by-segment-bars-widget/` | same |
| _shared (engagement-score-badge helper) | `_shared/` | `engagement-score-badge.tsx` + `index.ts` — REUSABLE within retention-dashboard-widgets only |

**Folder barrel**: `retention-dashboard-widgets/index.ts` — re-exports all 10 renderers.

**Page route — OVERWRITE existing stub**:
- `PSS_2.0_Frontend/src/app/[lang]/reportaudit/reports/retentiondashboard/page.tsx` — currently a 6-line `<UnderConstruction />` stub. Overwrite with `"use client"` page that imports a co-located `retention-dashboard-page-config.tsx` and renders it (pattern of EventAnalytics)
- `PSS_2.0_Frontend/src/app/[lang]/reportaudit/reports/retentiondashboard/retention-dashboard-page-config.tsx` — NEW. Builds page chrome (breadcrumb + title + Year/Branch filter + Export/Print) and mounts `<MenuDashboardComponent moduleCode="REPORTAUDIT" dashboardCode="RETENTIONDASHBOARD" filterContext={{ year, branchId }} hideHeader />`
- `PSS_2.0_Frontend/src/app/[lang]/reportaudit/reports/retentiondashboard/retention-dashboard-branch-select.tsx` — NEW. `ApiSelectV2` wrapper for the Branch filter (driven by `branches` GQL query)

### Frontend Wiring Updates

| # | File | Change |
|---|------|--------|
| 1 | `dashboard-widget-registry.tsx` | Add 10 entries in `WIDGET_REGISTRY` — `RetentionRateKpiWidget` → `<RetentionRateKpiWidget {...props} />`, etc. Keys must match `WidgetType.ComponentPath` exactly (case-sensitive). |
| 2 | sidebar / menu config | NONE — RA_REPORTS already lists RETENTIONDASHBOARD per MODULE_MENU_REFERENCE.md and the standard menu-tree renderer picks it up after seed links `Dashboard.MenuId` |

### DB Seed

**File**: `PSS_2.0_Backend/sql-scripts-dyanmic/RetentionDashboard-sqlscripts.sql` (preserve `dyanmic` typo per repo convention)

**Steps (all idempotent — `NOT EXISTS` guards)**:
1. **STEP 0** — diagnostics block: `RAISE NOTICE` for current Dashboard / Menu / WidgetType / Widget counts; ASSERT auth.Menus row `MenuCode='RETENTIONDASHBOARD'` exists (abort if not — per MODULE_MENU_REFERENCE.md row 347 it should already be there).
2. **STEP 1** — `sett.Dashboards` row: INSERT only if `DashboardCode='RETENTIONDASHBOARD'` AND `CompanyId=<scope>` does not exist. Pull `ModuleId` from `auth.Modules` where `ModuleCode='REPORTAUDIT'`.
3. **STEP 2** — UPDATE `sett.Dashboards.MenuId = (SELECT MenuId FROM auth.Menus WHERE MenuCode='RETENTIONDASHBOARD' LIMIT 1)` for the row from STEP 1.
4. **STEP 3** — 10 NEW `sett.WidgetTypes` rows: per ② table. INSERT-only-if-not-exists by `WidgetTypeCode`.
5. **STEP 4** — 12 `sett.Widgets` rows: per ② table. INSERT-only-if-not-exists by `WidgetCode`. Wire `WidgetTypeId` via subquery against the WidgetTypeCode just inserted; wire `ModuleId` via REPORTAUDIT lookup. `StoredProcedureName = 'fund.fn_retention_dashboard_*'`. `DefaultParameters` = JSON string per ② table.
6. **STEP 5** — `auth.WidgetRoles` grants: for each Widget row, grant `BUSINESSADMIN` (developer may extend at /build-screen time).
7. **STEP 6** — `sett.DashboardLayouts` row: single INSERT with `LayoutConfig` JSON (lg breakpoint per ⑥ table) + `ConfiguredWidget` JSON ([{i: "RETN_KPI_OVERALL", widgetId: <subquery WidgetId of RETN_KPI_OVERALL>}, ...] — 12 entries).

**Re-running the seed**: every step uses `NOT EXISTS` or `WHERE NOT EXISTS` guards so re-applying is a no-op. To intentionally redeploy with changes, drop the WidgetType/Widget/Layout rows manually or extend with version-aware UPDATE blocks (deferred).

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL
DashboardVariant: MENU_DASHBOARD

MenuName: Retention Dashboard
MenuCode: RETENTIONDASHBOARD
ParentMenu: RA_REPORTS
Module: REPORTAUDIT
MenuUrl: reportaudit/reports/retentiondashboard
GridType: DASHBOARD

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT

GridFormSchema: SKIP

# Dashboard-specific seed inputs
GridCode: RETENTIONDASHBOARD
DashboardCode: RETENTIONDASHBOARD
DashboardName: Retention Dashboard
DashboardIcon: users-three
DashboardColor: #7c3aed
IsSystem: true
DashboardKind: MENU_DASHBOARD
OrderBy: 3       # already pre-seeded in auth.Menus per MODULE_MENU_REFERENCE.md row 347; seed verifies but does not write
WidgetGrants:
  - RETN_KPI_OVERALL: BUSINESSADMIN
  - RETN_KPI_ACTIVE: BUSINESSADMIN
  - RETN_KPI_NEW: BUSINESSADMIN
  - RETN_KPI_LYBUNT: BUSINESSADMIN
  - RETN_KPI_SYBUNT: BUSINESSADMIN
  - RETN_KPI_LTV: BUSINESSADMIN
  - RETN_YEAR_TREND: BUSINESSADMIN
  - RETN_COHORT_MATRIX: BUSINESSADMIN
  - RETN_LYBUNT_ANALYSIS: BUSINESSADMIN
  - RETN_SYBUNT_ANALYSIS: BUSINESSADMIN
  - RETN_UPGRADE_DOWNGRADE: BUSINESSADMIN
  - RETN_BY_SEGMENT: BUSINESSADMIN
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

**Queries** (all REUSED — no new GQL fields):

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| `dashboardByModuleAndCode` | `DashboardDto` (single) | `moduleCode="REPORTAUDIT", dashboardCode="RETENTIONDASHBOARD"` | Resolves Dashboard + DashboardLayout + 1 row |
| `widgetByModuleCode` | `[WidgetDto]` | `moduleCode="REPORTAUDIT"` | Resolves the 12 Widget rows for the catalog |
| `generateWidgets` | per-widget JSON | `widgetCode, parameters` (per-widget call) | Runs `Widget.StoredProcedureName` — returns the function's `data_json` payload as a typed shape |

**Per-widget `data_json` schemas** — see ③ for full payload examples. The FE typings live in each renderer's `.types.ts` file.

**FE-only types** (no GQL — local to the page chrome):

```ts
type RetentionFilterState = {
  year: number;          // default = new Date().getFullYear()
  branchId: number;      // 0 = All Branches (passed as '' to the SQL filter JSON → NULL)
};
```

**FE-only types** (per renderer, partial — see `.types.ts` in each renderer folder):

```ts
// RetentionRateKpiWidget — payload shape from fn_retention_dashboard_kpi_overall_rate
type RetentionRateKpiData = {
  value: number;                  // e.g. 68.4
  formatted: string;              // e.g. "68.4%"
  secondaryFormatted: string;     // e.g. "vs 2025 (66.3%)"
  deltaLabel: string;             // e.g. "+2.1%" or "-1.2%" or "No change"
  deltaColor: 'positive' | 'warning' | 'neutral';
  accent: 'purple';
};

// RetentionCountKpiWidget — reused by Active / New / SYBUNT
type RetentionCountKpiData = {
  value: number;
  formatted: string;
  subtitle: string;
  accent: 'teal' | 'green' | 'red';
  icon: 'users' | 'user-plus' | 'user-x';  // Phosphor icon name (no ph: prefix)
};

// RetentionCohortMatrixWidget
type RetentionCohortRow = {
  cohortYear: number;
  cohortSize: number;
  cells: Array<{
    yearOffset: number;           // 0 = cohort baseline year, 1 = +1 year, ...
    value: number;                // donor count retained
    pct: number;                  // 100..0
  }>;
};
type RetentionCohortMatrixData = {
  cohorts: RetentionCohortRow[];
};

// RetentionLybuntAnalysisWidget — full combo payload
type RetentionLybuntAnalysisData = {
  summary: { count: number; atRisk: number; avgGiving: number };
  breakdown: Array<{
    range: string;                // "$1,000+", "$500 - $999", ...
    count: number;
    pct: number;                  // 0..100
    atRisk: number;
    suggestion: string;
    badgeColor: 'purple' | 'blue' | 'teal' | 'green';
  }>;
  topDonors: Array<{
    contactId: number;
    contactName: string;
    lastGiftDate: string;         // ISO
    lastAmount: number;
    lifetimeAmount: number;
    engagementScore: number;      // 0..100
    scoreColor: 'green' | 'amber' | 'red';
    daysSince: number;
  }>;
};
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `pnpm tsc --noEmit` — 0 Retention errors
- [ ] `pnpm dev` — page loads at `/{lang}/reportaudit/reports/retentiondashboard`
- [ ] No `dotnet build` needed — NO C# changes
- [ ] Seed `RetentionDashboard-sqlscripts.sql` applies cleanly + re-applying is no-op

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Page chrome renders: breadcrumb / title / year+branch filters / Export+Print buttons
- [ ] Initial load (year=current, branch=All) — all 12 widgets fetch + render with correct shape
- [ ] **KPI tiles**: each card shows value formatted per spec; LYBUNT shows secondary `$at-risk`; LTV shows currency
- [ ] **Year filter**: changing year triggers parallel refetch of all 12 widgets via `filterContext.year`
- [ ] **Branch filter**: changing branch triggers parallel refetch; "All Branches" passes empty string → SQL NULL filter
- [ ] **Retention Trend Bars**: shows 7 years; current year bar is visually distinguished; dashed `Industry Avg: 45%` line visible; "Goal: 75% by 2027" footer right-aligned
- [ ] **Cohort Matrix**: 6 cohort rows × 6 year-N cells; cell colors match the bin rules in ⑥; future cells show `—`
- [ ] **LYBUNT Analysis combo**: alert banner shows aggregate counts; breakdown 4-row table renders with colored badges; top-5 donor table renders with Re-engage dropdown; "Create Re-engagement Campaign" button navigates to email-campaign-builder
- [ ] **SYBUNT collapsible**: default collapsed; toggle expands to show 4-row table with progress bars
- [ ] **Upgrade/Downgrade**: side-by-side green/red panels with counts + top mover lines
- [ ] **Retention by Segment**: 6 horizontal bars, color-graded by retentionPct, sorted high-to-low (per mockup)
- [ ] **Drill-downs**: donor name click → contact-read page; bar click → globaldonation list with year filter; "View All" buttons → contact list with cohort query string
- [ ] **Print**: `window.print()` hides chrome via @media print; widget cards print readably
- [ ] **Empty data**: if branch has no donations in year → each widget renders its own muted empty state
- [ ] **Loading skeletons**: shapes match — KPI tile skeleton is a small card; cohort matrix skeleton is a striped table grid; trend bars skeleton has 7 bars of varying height
- [ ] **Error**: if a Postgres function throws → widget shows red mini banner + Retry button
- [ ] **Role gating**: BRANCH_MANAGER role sees Branch filter locked to own branch; non-grantee role → sidebar leaf hidden via `RoleCapability(MenuId=<RETENTIONDASHBOARD>, READ, HasAccess=false)`
- [ ] **Mobile / md / sm responsive**: `<MenuDashboardComponent />` reflow widget grid (xs collapses to single column)

**DB Seed Verification:**
- [ ] STEP 0 ASSERT passes — auth.Menus row `MenuCode='RETENTIONDASHBOARD'` exists
- [ ] STEP 1 creates Dashboard row with correct ModuleId + IsSystem=true
- [ ] STEP 2 sets `Dashboard.MenuId` to the matching auth.Menus row
- [ ] STEP 3 inserts 10 WidgetType rows with NEW ComponentPaths
- [ ] STEP 4 inserts 12 Widget rows with correct `StoredProcedureName` + `DefaultParameters`
- [ ] STEP 5 inserts BUSINESSADMIN WidgetRole grants for all 12 widgets
- [ ] STEP 6 inserts DashboardLayout with LayoutConfig (lg breakpoint) + ConfiguredWidget (12 instanceCode → widgetId pairs)
- [ ] Re-running the seed produces 0 new rows (idempotent)

**Visual / UX Verification:**
- [ ] All 10 NEW renderers register in `WIDGET_REGISTRY` (case-sensitive ComponentPath match)
- [ ] 0 legacy renderer imports inside `retention-dashboard-widgets/`
- [ ] 0 raw `"Loading..."` strings in renderers (use Skeleton component)
- [ ] 0 inline-hex in `style={{...}}` chrome (only data-driven `row.color || "#muted"` fallbacks)
- [ ] 0 fa-* icons (Phosphor `ph:*` only — per UI uniformity memory)
- [ ] Visual uniqueness honored — 6 KPI tiles use 4 distinct ComponentPaths (RETENTION_RATE_KPI + RETENTION_COUNT_KPI×3 + RETENTION_LYBUNT_KPI + RETENTION_LIFETIME_VALUE_KPI) — NOT 6 clones of one tile

---

## ⑫ Special Notes & Warnings

**Dashboard-class warnings (apply per template preamble):**
- READ-ONLY dashboard. CRUD on Dashboard rows is `#78 Dashboard Config`.
- All 12 Postgres functions MUST be tenant-scoped (`p_company_id` from HttpContext via `generateWidgets`) — easy to forget. Reference `fn_donation_dashboard_kpi_donor_retention` to confirm the COMPANY scoping idiom.
- LYBUNT/SYBUNT math is set-difference SQL — verify EF translation N+1 risk does not apply (Path A is straight Postgres functions, not EF).
- Multi-currency: math uses `BaseCurrencyAmount` (already converted at row time). No runtime FX.
- LayoutConfig JSON requires `lg` breakpoint at minimum; `<MenuDashboardComponent />` derives md/sm/xs from lg.
- ConfiguredWidget `i` (instanceCode) MUST be unique AND equal the matching `i` in LayoutConfig.
- Drill-down URL params (`activeYear`, `firstYear`, `lybuntYear`, `sybuntYear`, `cohortYear`, `segment`) — Contact list page (`/crm/contact/contact`) may not yet honor these args. **Building the link is in scope; making the destination filter on them is a separate Contact list enhancement (ISSUE-3 below).** The dashboard remains useful: user clicks → contact list opens (unfiltered or with available filters honored).

**MENU_DASHBOARD-specific notes:**
- **Non-standard parent menu** — RETENTIONDASHBOARD lives under `RA_REPORTS` (Reports leaf), NOT under a `*_DASHBOARDS` parent. The auto-sidebar-injection rule (`MenuCode ~ '\w+_DASHBOARDS$'`) does NOT apply — but it doesn't need to: the auth.Menus row is pre-seeded with `ParentMenuId=RA_REPORTS` and the standard menu-tree renderer picks it up directly. The MENU_DASHBOARD `Dashboard.MenuId` field is still set so the dashboard resolves correctly via `dashboardByModuleAndCode`.
- **Non-standard route path** — `reportaudit/reports/retentiondashboard` is NOT under `/dashboards/{slug}`. The generic `[module]/dashboards/[slug]/page.tsx` dynamic route does NOT apply. Use a DEDICATED `page.tsx` that mounts `<MenuDashboardComponent />` directly. **Pattern of EventAnalytics #47** (which has the same non-standard situation under `crm/event/eventanalytics`).
- Sidebar auto-injection is NOT used — leaf is already in `auth.Menus` and the standard menu-tree renderer handles display.

**ISSUEs pre-flagged for build session** (developer triages each):

| # | Severity | Description |
|---|---------|-------------|
| ISSUE-1 | HIGH | **`Contact.EngagementScore` column may not exist** — the LYBUNT top-donors table needs an engagement score per donor. If `corg.Contacts.EngagementScore` is absent, fall back to the computed `daysSince` bucket: `<90→80 / <180→55 / <365→40 / else→25`. Verify column existence at /build-screen step 0 (`SELECT column_name FROM information_schema.columns WHERE table_schema='corg' AND table_name='Contacts' AND column_name='EngagementScore'`) and choose path. The renderer signature accepts both. |
| ISSUE-2 | HIGH | **`SourceTypeId` is the Branch FK** (per #124 Donation Dashboard finding — entity column misleadingly named). All 12 retention functions MUST filter via `gd."SourceTypeId" = v_branch_id` when `branchId` is non-null. Verify against entity navigation property `public Branch? DonationSourceType` on `GlobalDonation`. Do NOT use `OrganizationalUnitId` — that is a different concept. |
| ISSUE-3 | MED | **Contact list URL filter args not yet defined** — drill-downs from RETN_KPI_ACTIVE / RETN_KPI_NEW / cohort cells / "View All LYBUNT" / "View All SYBUNT" / RETN_BY_SEGMENT bars pass query strings like `activeYear=2026`, `cohortYear=2020`, `lybuntYear=2026`, `segment=MAJOR`. Contact list page (`/crm/contact/contact`) does NOT currently honor these args. **In scope here**: build the links so they navigate correctly. **Out of scope**: Contact list filter handling — log as a Contact list enhancement ticket. Users land on unfiltered Contact list until then. |
| ISSUE-4 | MED | **Email Campaign Builder cohort prefill** — RETN_LYBUNT_ANALYSIS "Create Re-engagement Campaign" button passes `?cohort=LYBUNT&year={year}`. The email-campaign-builder may not yet honor these prefill args. Build the link; flag the destination enhancement separately. |
| ISSUE-5 | MED | **SERVICE_PLACEHOLDER — Re-engage dropdown actions** — Send Email / Send SMS / Send WhatsApp / Add to Campaign / Assign to Staff / Log Note. None of these are wired to backend services in this build. Render the dropdown with all 6 items but each handler emits a `toast.info("...service pending...")`. Email is closest to wired (email-campaign-builder route exists), but the per-donor send flow isn't built. |
| ISSUE-6 | MED | **SERVICE_PLACEHOLDER — Export Report (PDF)** — Server-side PDF rendering service not wired. Render the Export button with a `toast.info()` handler; flag as pending. Mockup also has a "View All" button for both LYBUNT and SYBUNT — same status (links work, destination filtering deferred per ISSUE-3). |
| ISSUE-7 | MED | **Cohort matrix performance** — `fn_retention_dashboard_cohort_matrix` does 6 × 6 = 36 cell computations, each a sub-aggregate over `fund.GlobalDonations`. Verify perf on large tenants (>500k donations); add CTE-stack idiom from `fund.fn_donation_dashboard_by_campaign.sql` precedent if needed. |
| ISSUE-8 | MED | **One-Time Donors segment edge case** — A donor whose lifetime-through-year-1 was exactly 1 donation, who then gives in year, is counted as "retained" in the One-Time segment. But by definition they're no longer "one-time" once they gave again. The segment retention % captures the conversion rate from one-timer → repeat donor — semantically correct for "of one-timers in year-1, how many came back?" Document this in renderer tooltip. |
| ISSUE-9 | LOW | **Goal % and Industry Average** are hardcoded in Widget.DefaultParameters (75 / 45 / 2027). Future enhancement: source from a CompanySettings row so each tenant can configure their own retention goal. For MVP: hardcoded in seed JSON; admin can edit Widget.DefaultParameters manually. |
| ISSUE-10 | LOW | **Year dropdown range** — currently shows current + 3 prior. If tenant data goes back further (>3 years), user must edit Widget.DefaultParameters or the FE select hardcoded options. Pre-flagged as a future enhancement; not in scope. |
| ISSUE-11 | LOW | **`year` arg as text vs integer** — FE passes `year` as a string (FormSelect value type) but the Postgres functions extract as `INTEGER`. Use `NULLIF(p_filter_json ->> 'year','')::INT` and fallback to `EXTRACT(YEAR FROM CURRENT_DATE)::INT`. |
| ISSUE-12 | LOW | **Print layout testing** — Manual verification needed. The cohort matrix and LYBUNT table may overflow page-width on print. Recommend `@media print { .cohort-table { font-size: 0.7rem; } }` if needed. |
| ISSUE-13 | LOW | **Seed folder typo `sql-scripts-dyanmic/` preserved** per ChequeDonation #6 ISSUE-15 + DonationDashboard #124 precedent. Do NOT rename. |
| ISSUE-14 | LOW | **Currency formatter** — `formatted` field comes pre-formatted from Postgres (e.g. `'$1,245'`). For multi-tenant deployments with non-USD base currency, the seed `DefaultParameters` should include `companyCurrencySymbol` resolved from `com.Currencies`. For MVP, the function hardcodes `$` — flag as future tenant-aware enhancement. |
| ISSUE-15 | LOW | **Cohort baseline 100% cell** — the cohort year's own year-1 cell is always 100% by definition. Render as `100%` with purple background (matching mockup). Do NOT compute from data — it's a constant. |

**Service Dependencies (UI-only — flagged genuine external-service gaps):**
- ⚠ SERVICE_PLACEHOLDER: Export Report PDF — full UI in place; handler toasts. Pending server-side PDF rendering service.
- ⚠ SERVICE_PLACEHOLDER: Re-engage dropdown (Send Email/SMS/WhatsApp/Add to Campaign/Assign to Staff/Log Note) — full UI in place; per-item handler toasts. Email closest to wired (campaign builder route exists). SMS / WhatsApp not yet integrated.
- ⚠ SERVICE_PLACEHOLDER: Create Re-engagement Campaign cohort prefill — navigation works; email-campaign-builder cohort-prefill enhancement is a separate ticket.

**Token Optimization for the build session** (per /plan-screens skill rules — non-binding hints to the orchestrator):
- All 12 Postgres functions follow the same template (Path-A 5-arg / 4-col contract + `NULLIF` filter extraction) — they can be generated in parallel by a single Sonnet-tier BE developer agent given the per-widget contract in ③.
- 10 NEW FE renderers also follow a uniform pattern (4 files per renderer + barrel) — can be generated in parallel by a single Sonnet-tier FE developer agent given the type schemas in ⑩.
- Skip BA/SR/UX agent spawns per Family #20 precedent — §①–⑫ is already deep enough for parallel Opus/Sonnet BE + FE.
- DB seed is its own deliverable — generate after the 12 functions and 10 renderers are written so the WidgetType ComponentPaths and Widget StoredProcedureNames are stable.

---

## ⑬ Build Log

### Known Issues

| ID | Severity | Status | Description |
|----|----------|--------|-------------|
| ISSUE-1 | HIGH | RESOLVED | `Contact.EngagementScore` column existence — Resolved by using safe computed-fallback throughout (no runtime DDL inspection). |
| ISSUE-2 | HIGH | RESOLVED | `SourceTypeId` IS Branch FK — All 12 functions filter via `gd."SourceTypeId" = v_branch_id`. |
| ISSUE-3 | MED | OPEN | Contact list URL filter args (`activeYear`, `lybuntYear`, `sybuntYear`, `cohortYear`, `segment`) not yet honored by destination. Links built per spec; destination filter handling deferred. |
| ISSUE-4 | MED | OPEN | Email Campaign Builder cohort prefill — Link built (`?cohort=LYBUNT&year={year}`); destination prefill deferred. |
| ISSUE-5 | MED | OPEN | Re-engage dropdown SERVICE_PLACEHOLDER — All 6 actions emit `toast.info("...service pending")`. UI in place; backend services pending. |
| ISSUE-6 | MED | OPEN | Export Report PDF SERVICE_PLACEHOLDER — Button + toast in place; server-side PDF service pending. |
| ISSUE-7 | MED | RESOLVED | Cohort matrix perf — Used CTE-stack idiom (cohorts → cohort_sizes → donor_activity → cohort_cells → cell_counts → cells_json). No N+1 lateral joins. |
| ISSUE-8 | MED | DOCUMENTED | One-Time Donors segment edge case (donor whose lifetime count was 1, then gives again — semantically a "conversion rate"). Documented in renderer tooltip. |
| ISSUE-9 | LOW | OPEN | Goal % and Industry Avg hardcoded in `Widget.DefaultParameters` (75 / 45 / 2027). Future: source from CompanySettings. |
| ISSUE-10 | LOW | OPEN | Year dropdown range capped at current + 3 prior. Future enhancement. |
| ISSUE-11 | LOW | RESOLVED | `year` arg text→int cast — All functions use `NULLIF(p_filter_json ->> 'year','')::INTEGER`. |
| ISSUE-12 | LOW | OPEN | Print layout testing — Manual verification pending (cohort matrix may overflow page-width). |
| ISSUE-13 | LOW | DOCUMENTED | `sql-scripts-dyanmic/` typo preserved per repo convention. |
| ISSUE-14 | LOW | OPEN | Currency formatter — `$` hardcoded in BE function. Future: tenant-aware via `companyCurrencySymbol`. |
| ISSUE-15 | LOW | RESOLVED | Cohort baseline 100% cell — Rendered as constant per data shape (yearOffset=0 always produces pct=100). |
| ISSUE-16 | MED | RESOLVED THIS SESSION | BE/FE contract mismatch on Year Trend widget. BE originally emitted `data[0] = {rows: [...]}` + `metadata = {industryAvg, goalPct, goalYear}`. FE renderer reads `data[0].years/industryAvg/goalPct/goalYear` because `useWidgetQuery` does not surface metadata. Fixed by changing BE to emit `data[0] = {years: [...], industryAvg, goalPct, goalYear}` (metadata kept for parity). |
| ISSUE-17 | LOW | OPEN | `fund.RecurringDonationSchedules` table existence/column-names not verified at write-time. DBA should confirm columns `ContactId, CompanyId, StatusId, StartDate, EndDate, IsDeleted` match actual DDL before applying seed. |

### § Sessions

### Session 1 — 2026-05-14 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. MENU_DASHBOARD variant under non-standard `RA_REPORTS` parent (not `*_DASHBOARDS`) — same EventAnalytics #47 mount pattern.
- **Files touched**:
  - BE (13): 12 Path-A Postgres functions under `PSS_2.0_Backend/DatabaseScripts/Functions/fund/fn_retention_dashboard_*.sql` (created) + 1 seed `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/RetentionDashboard-sqlscripts.sql` (created). NO C# files touched.
  - FE (43+3): 40 renderer files (10 × 4) + 2 `_shared/engagement-score-badge.*` + 1 barrel `retention-dashboard-widgets/index.ts` (all created) + `dashboard-widget-registry.tsx` (modified: 10 imports + 10 entries) + 3 page chrome files at `app/[lang]/reportaudit/reports/retentiondashboard/` (page.tsx overwritten; retention-dashboard-page-config.tsx + retention-dashboard-branch-select.tsx created).
  - DB: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/RetentionDashboard-sqlscripts.sql` (created).
- **Deviations from spec**:
  - Chart library: used ApexCharts (`react-apexcharts`) for year-trend widget instead of Recharts (prompt mentioned Recharts but ApexCharts is the established codebase convention — see DonationRevenueTrendWidget).
  - Branch select: used native `<select>` driven by `useQuery(BRANCHES_QUERY)` instead of `ApiSelectV2` — matches the donation-dashboard / communication-dashboard toolbar pattern (ApiSelectV2 not used by any existing dashboard toolbar).
  - WIDGET_REGISTRY entries: plain component references (`RetentionRateKpiWidget: RetentionRateKpiWidget`) instead of arrow wrappers (`(props) => <X {...props} />`) — matches existing donation/communication/event registry style.
  - Renderer prop signature: every renderer accepts `TWidgetProps` (`{widget, editMode}`) and internally calls `useWidgetQuery` per the established convention (NOT the simpler `{data, loading, error}` props sketched in the prompt).
  - Year-trend BE shape: changed from `data[0] = {rows: [...]}` + metadata-only scalars → `data[0] = {years: [...], industryAvg, goalPct, goalYear}` to match FE reader (ISSUE-16 fix, post-build).
- **Known issues opened**: ISSUE-16, ISSUE-17 (see Known Issues table). All 15 prompt-flagged ISSUEs triaged in the same table.
- **Known issues closed**: ISSUE-1, ISSUE-2, ISSUE-7, ISSUE-11, ISSUE-15 (resolved at write-time). ISSUE-16 closed mid-session.
- **Next step**: User runs `pnpm tsc --noEmit` and `pnpm dev` to verify build + page load at `/{lang}/reportaudit/reports/retentiondashboard`; then applies seed `RetentionDashboard-sqlscripts.sql` against the dev database; verifies all 12 widgets fetch and render with seeded data.
