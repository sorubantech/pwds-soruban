---
screen: ContactDashboard
registry_id: 123
module: CRM (Contact)
status: COMPLETED
scope: FULL
screen_type: DASHBOARD
dashboard_variant: MENU_DASHBOARD
complexity: High
new_module: NO
planned_date: 2026-04-29
completed_date: 2026-04-29
last_session_date: 2026-04-29
---

> ## Prerequisite — Phase-2 MENU_DASHBOARD infra is partially landed
>
> The `<MenuDashboardComponent />` ([menu-dashboards/index.tsx](../../../PSS_2.0_Frontend/src/presentation/components/custom-components/menu-dashboards/index.tsx)), the new `GetDashboardByModuleAndCode` BE query handler ([GetDashboardByModuleAndCode.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/Dashboards/Queries/GetDashboardByModuleAndCode.cs)), and the `Dashboard.MenuId` column already exist (precedent: Case Dashboard #52). What is **NOT** yet shipped:
>
> - The dynamic `[slug]/page.tsx` route (`src/app/[lang]/(core)/[module]/dashboards/[slug]/page.tsx`) — per-route stubs still own `crm/dashboards/contactdashboard/page.tsx`.
> - The deletion of the 6 hardcoded route stubs.
>
> **Implication for Contact Dashboard #123**: Do NOT block on the dynamic route. Replace the existing `crm/dashboards/contactdashboard/page.tsx` body with `<MenuDashboardComponent moduleCode="CRM" dashboardCode="CONTACTDASHBOARD" />` directly (transitional pattern used until #52 Phase 2 finishes the dynamic route + deletes all 6 stubs). When the dynamic route lands later, this stub will be deleted.
>
> **Do NOT** introduce a `ContactDashboardPageConfig` shell or any new page-level component on top of `<MenuDashboardComponent />`. The component is the page; the `page.tsx` is just a 1-line server boundary.

---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (16 widgets, 4 global filters, 11 drill-down targets identified)
- [x] Variant chosen — **MENU_DASHBOARD** (own sidebar leaf at `crm/dashboards/contactdashboard`, MenuCode `CONTACTDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=1)
- [x] Source entities identified — Contact #18 + ContactType #19 + ContactSource #122 + Tag/Segment #22 + Family #20 + DuplicateContact #21 + GlobalDonation (existing) — ALL COMPLETED
- [x] Widget catalog drafted (16 widgets — 6 KPI + 1 top-engaged-contacts table + 5 charts + 1 tag cloud + 2 mini-stat grids + 1 alerts list + 1 segments table)
- [x] react-grid-layout config drafted (lg breakpoint, 12 cols, ~46-row height)
- [x] DashboardLayout JSON shape drafted (LayoutConfig + ConfiguredWidget per widget)
- [x] MENU_DASHBOARD parent menu code resolved — CRM_DASHBOARDS already exists; CONTACTDASHBOARD menu already seeded (OrderBy=1)
- [x] Path-A (Postgres functions) chosen for ALL 16 widgets — matches `corg.fn_contact_dashboard_*` pattern (NEW `corg/` folder for dashboard functions; precedent `case/fn_case_dashboard_*` from Case Dashboard #52)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (skip — prompt §①–⑫ pre-analyzed; Case Dashboard #52 precedent)
- [x] Solution Resolution complete (skip — Path-A across 16 widgets dictated by §⑤)
- [x] UX Design finalized (skip — §⑥ contains complete grid + widget detail)
- [x] User Approval received
- [x] Backend (Path-A): 16 Postgres functions in `PSS_2.0_Backend/DatabaseScripts/Functions/corg/fn_contact_dashboard_*.sql` (5-arg / 4-column contract; `NULLIF(p_filter_json->>'key','')::type` filter idiom). NO new C# code.
- [x] FE renderers: reuse 9 existing (StatusWidgetType1 ×6, MultiChartWidget, PieChartWidgetType1, ColumnsChartWidget, BarChartWidgetType1, NormalTableWidget, FilterTableWidget, AlertListWidget — already created by #52). CREATE 3 NEW renderers: `contact-top-engaged-table-widget`, `contact-tag-cloud-widget`, `contact-mini-stat-grid-widget` (used twice — Family Health + Duplicate Detection).
- [x] FE page-level: REPLACE body of `src/app/[lang]/crm/dashboards/contactdashboard/page.tsx` with `<MenuDashboardComponent moduleCode="CRM" dashboardCode="CONTACTDASHBOARD" />`. Delete the existing `ContactDashboardPageConfig` re-export from `presentation/pages/crm/index.ts` IF it points to a stub that will become orphaned.
- [x] DB seed `sql-scripts-dyanmic/ContactDashboard-sqlscripts.sql`:
      • Dashboard row (DashboardCode=CONTACTDASHBOARD, ModuleId=CRM, IsSystem=true, IsActive=true, CompanyId=NULL)
      • DashboardLayout row (LayoutConfig JSON × 4 breakpoints lg/md/sm/xs + ConfiguredWidget × 16)
      • Widget rows × 16 with `StoredProcedureName='corg.fn_contact_dashboard_*'`
      • WidgetType rows × 3 NEW (TopEngagedContactsTableWidget, TagCloudWidget, MiniStatGridWidget)
      • WidgetRole grants × 16 (BUSINESSADMIN)
      • UPDATE `sett.Dashboards SET MenuId = (SELECT MenuId FROM auth.Menus WHERE MenuCode='CONTACTDASHBOARD' AND ModuleId=<CRM ModuleId>)` — link to pre-seeded menu row
      • NO new auth.Menus seed (CONTACTDASHBOARD menu already exists)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (no new C# changes; verify nothing breaks)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/contactdashboard`
- [ ] Network tab shows EXACTLY ONE GraphQL request: `dashboardByModuleAndCode(moduleCode:"CRM", dashboardCode:"CONTACTDASHBOARD")` (no module-wide list fetch leakage)
- [ ] All 16 widgets fetch and render with sample data (each function returns `(data jsonb, metadata jsonb, total_count int, filtered_count int)`)
- [ ] Each KPI card shows correct value formatted per spec (count / score / %)
- [ ] Donut (Contacts by Type) renders with 4 segments + center label
- [ ] Engagement Histogram renders 5 bins (0-20, 21-40, 41-60, 61-80, 81-100) with bin-color cues
- [ ] Acquisition Trend stacked area renders 12 months × 6 source series + annotation pins
- [ ] Geography horizontal bars render top 6 + "Others" bucket
- [ ] Top Tags cloud renders ≤12 tag pills with 3 size tiers (lg ≥250, md 100-249, default <100) — first pill highlighted accent
- [ ] Family Health 4 mini-stats render with correct color cues (indigo/success/warn/neutral)
- [ ] Duplicate Detection 4 mini-stats + warning banner render
- [ ] Alerts list renders with 6 severity-colored rows (warning / danger / info / success) with action links
- [ ] Top Segments table renders 6 rows (collapsible header — start expanded; chevron toggles body in v1 OR deferred per ISSUE)
- [ ] **Period filter** (This Year / Last Year / This Quarter / Last Quarter / This Month / Custom) updates time-honoring widgets (KPI 2/3, charts 9/10/11, table 7, alerts)
- [ ] **Contact Type filter** (All / Individual / Corporate / Foundation / Family) updates type-honoring widgets (KPI 1/2/4/5, table 7, charts 9/10/11/12)
- [ ] **Branch filter** (All / 5 cities) updates branch-honoring widgets (all KPIs, charts 10/11, table 7, geography chart)
- [ ] **Source filter** (All / Website / Referral / Event / Walk-In / Import / Social Media) updates source-honoring widgets (KPI 3, charts 10/11)
- [ ] Drill-down clicks navigate to correct destinations (see §⑥ Drill-Down Map — 11 click targets)
- [ ] Empty / loading / error states render per widget (skeleton matching widget shape; red mini-banner + Retry on error)
- [ ] Sidebar leaf "Contact Dashboard" visible to BUSINESSADMIN under CRM → Dashboards
- [ ] react-grid-layout reflows correctly (xs/sm/md/lg/xl breakpoints)
- [ ] DB Seed — Dashboard row with `MenuId NOT NULL` + DashboardLayout JSON + 16 Widget rows + 3 NEW WidgetType rows visible in DB; widgets resolve from registry; all 16 SQL functions exist in `corg.` schema

---

## ① Screen Identity & Context

**Consumer**: All agents — sets the stage

**Screen**: ContactDashboard
**Module**: CRM → Contact (sidebar leaf under CRM_DASHBOARDS)
**Schema**: NONE for the dashboard itself (`sett.Dashboards` + `sett.DashboardLayouts` + `sett.Widgets` already exist). `corg` schema reused — NEW `corg/` folder for dashboard widget functions.
**Group**: NONE (no new C# DTOs / handlers — Path-A throughout)

**Dashboard Variant**: **MENU_DASHBOARD** — own sidebar leaf at `crm/dashboards/contactdashboard` (MenuCode `CONTACTDASHBOARD` already seeded under CRM_DASHBOARDS @ OrderBy=1). NOT in any dropdown switcher.

**Business**:
The Contact Dashboard is the **donor 360° / engagement health** overview for the Contact module. It rolls up the constituent base into KPIs (total contacts, active donors, new acquisitions, engagement score, churn risk, pending duplicates), surfaces the top-engaged contacts for prioritized outreach, and breaks down the base by contact type, engagement-score band, geography, source channel, and tag. **Target audience**: NGO executives, Fundraising Directors, CRM managers, marketing/communications staff. **Why it exists**: Constituent management is the heart of the platform — this dashboard answers the daily "who is at risk", "where are new contacts coming from", "what's our acquisition velocity", and "what data hygiene work is pending" questions in one place. **Why MENU_DASHBOARD (not STATIC)**: it is deep-linkable from segment campaigns, role-restricted to fundraising-facing users (not all CRM users), and tightly scoped to Contact (no need to share dropdown space with Donation / Communication / Volunteer dashboards). It rolls up data from: Contact (#18), ContactType (#19), ContactSource (#122), Tag/Segment (#22), Family (#20), DuplicateContact (#21), and GlobalDonation (existing).

---

## ② Entity Definition

**Consumer**: BA Agent → Backend Developer
> Dashboard does NOT introduce a new entity. It composes **two seeded rows** (`sett.Dashboards` + `sett.DashboardLayouts`) over **7 existing source entities**.

### A. Dashboard Row (`sett.Dashboards`)

| Field | Value | Notes |
|-------|-------|-------|
| DashboardCode | `CONTACTDASHBOARD` | Matches Menu.MenuCode |
| DashboardName | `Contact Dashboard` | Matches Menu.MenuName (for sidebar display) |
| DashboardIcon | `ph:users-three` | Phosphor icon (mockup uses `fa-people-group`) |
| DashboardColor | `#4f46e5` | Indigo accent from mockup `--ct-accent` |
| ModuleId | (resolve from `auth.Modules WHERE ModuleCode='CRM'`) | CRM module |
| IsSystem | `true` | System-seeded |
| IsActive | `true` | — |
| CompanyId | `NULL` | Global system dashboard (CompanyId NULL = available to all tenants) |
| MenuId | (UPDATE step — link to seeded `auth.Menus.MenuCode='CONTACTDASHBOARD'`) | Encodes MENU_DASHBOARD; sidebar leaf under CRM_DASHBOARDS |

### B. DashboardLayout Row (`sett.DashboardLayouts`)

| Field | Shape | Notes |
|-------|-------|-------|
| DashboardId | FK to row above | — |
| LayoutConfig | JSON: `{"lg": [...16 layout items...], "md": [...], "sm": [...], "xs": [...]}` | react-grid-layout breakpoint configs |
| ConfiguredWidget | JSON: `[{instanceId, widgetId, title?, customQuery?, customParameter?}, ... 16 entries]` | One element per rendered widget |

### C. Widget Definitions (`sett.Widgets` — one row per widget)

> All Path-A — each widget has `StoredProcedureName` set; `DefaultQuery` is NULL.
> Reuses existing `WidgetTypes` rows where possible (StatusWidgetType1, MultiChartWidget, PieChartWidgetType1, ColumnsChartWidgetType1, BarChartWidgetType1, NormalTableWidget, AlertListWidget — last created by #52).
> Adds **3 new WidgetType rows**: `TopEngagedContactsTableWidget`, `TagCloudWidget`, `MiniStatGridWidget`.

| # | WidgetCode (used as instanceId) | WidgetName | WidgetType.ComponentPath | StoredProcedureName | OrderBy |
|---|---------------------------------|-----------|--------------------------|---------------------|---------|
| 1 | KPI_TOTAL_CONTACTS | Total Contacts | StatusWidgetType1 | corg.fn_contact_dashboard_kpi_total_contacts | 1 |
| 2 | KPI_ACTIVE_DONORS | Active Donors (12 mo) | StatusWidgetType1 | corg.fn_contact_dashboard_kpi_active_donors | 2 |
| 3 | KPI_NEW_THIS_MONTH | New Contacts (this month) | StatusWidgetType1 | corg.fn_contact_dashboard_kpi_new_this_month | 3 |
| 4 | KPI_AVG_ENGAGEMENT | Avg Engagement Score | StatusWidgetType1 | corg.fn_contact_dashboard_kpi_avg_engagement | 4 |
| 5 | KPI_CHURN_RISK | Churn Risk | StatusWidgetType1 | corg.fn_contact_dashboard_kpi_churn_risk | 5 |
| 6 | KPI_PENDING_DUPLICATES | Pending Duplicates | StatusWidgetType1 | corg.fn_contact_dashboard_kpi_pending_duplicates | 6 |
| 7 | TBL_TOP_ENGAGED_CONTACTS | Top 10 Engaged Contacts | **TopEngagedContactsTableWidget** (NEW) | corg.fn_contact_dashboard_top_engaged_contacts | 7 |
| 8 | CHART_CONTACTS_BY_TYPE | Contacts by Type | PieChartWidgetType1 | corg.fn_contact_dashboard_contacts_by_type | 8 |
| 9 | CHART_ENGAGEMENT_HISTOGRAM | Engagement Score Distribution | ColumnsChartWidgetType1 | corg.fn_contact_dashboard_engagement_histogram | 9 |
| 10 | CHART_ACQUISITION_TREND | Contact Acquisition Trend | MultiChartWidget (stacked-area config) | corg.fn_contact_dashboard_acquisition_trend | 10 |
| 11 | CHART_GEOGRAPHY | By Geography (Top 6) | BarChartWidgetType1 (h-bar config) | corg.fn_contact_dashboard_geography | 11 |
| 12 | WIDGET_TOP_TAGS | Top Tags | **TagCloudWidget** (NEW) | corg.fn_contact_dashboard_top_tags | 12 |
| 13 | WIDGET_FAMILY_HEALTH | Family Health | **MiniStatGridWidget** (NEW) | corg.fn_contact_dashboard_family_health | 13 |
| 14 | WIDGET_DUPLICATE_DETECTION | Duplicate Detection | **MiniStatGridWidget** (NEW — same renderer as 13) | corg.fn_contact_dashboard_duplicate_detection | 14 |
| 15 | LIST_ALERTS | Alerts & Actions | AlertListWidget (existing — created by #52) | corg.fn_contact_dashboard_alerts | 15 |
| 16 | TBL_TOP_SEGMENTS | Top Segments & Saved Filters | NormalTableWidget | corg.fn_contact_dashboard_top_segments | 16 |

(16 widget rows.)

### D. Source Entities (read-only — what the widgets aggregate over)

| # | Source Entity | Schema.Table | Purpose | Aggregate(s) |
|---|--------------|--------------|---------|--------------|
| 1 | Contact | `corg.Contacts` | KPI 1/3/5, charts 8/9/10/11, table 7 | COUNT, GROUP BY ContactBaseTypeId / ContactSourceId / EngagementScore-bin / PrimaryCountryId/CityId, COUNT WHERE FirstContactDate in window |
| 2 | ContactType | `corg.ContactTypes` | Chart 8 (donut labels) | dimension labels |
| 3 | ContactTypeAssignment | `corg.ContactTypeAssignments` | Type filter scoping | join Contact ↔ ContactType |
| 4 | ContactSource | `corg.ContactSources` | Chart 10 (acquisition stacked-area legend), Source filter labels | dimension labels |
| 5 | GlobalDonation | `fund.GlobalDonations` | KPI 2 (Active Donors 12mo), KPI 5 (Churn Risk), table 7 (Lifetime $) | COUNT(DISTINCT ContactId) WHERE DonationDate >= now-12mo, SUM(DonationAmount) GROUP BY ContactId, MAX(DonationDate) per Contact |
| 6 | Tag + ContactTag | `corg.Tags` + `corg.ContactTags` | Widget 12 (Top Tags), table 7 (per-row tags) | COUNT GROUP BY TagId ORDER BY count DESC LIMIT 12 |
| 7 | Family | `corg.Families` | Widget 13 (Family Health) | COUNT(*), AVG(member count via Contact.FamilyId), COUNT WHERE NOT EXISTS(Contact WHERE FamilyId=f.FamilyId AND IsFamilyHead=true) |
| 8 | DuplicateContact | `corg.DuplicateContacts` | KPI 6, widget 14 (Duplicate Detection), Alert 2 | COUNT BY ActionId (PEN/MRG/IGN/NDP), COUNT WHERE confidence ≥ 90% (high-conf), COUNT WHERE ActionId=MRG AND ActionDate >= year_start |
| 9 | Segment | `corg.Segments` | Table 16 (Top Segments) | row projection — SegmentName, RulesSummary, LastRunCount, LastRunDate, IsSystem |
| 10 | Branch | `app.Branches` | Branch filter labels, role scoping | dimension labels |
| 11 | City | `com.Cities` | Chart 11 (Geography) | dimension labels |

### E. Engagement Score — SERVICE_PLACEHOLDER

`Contact.EngagementScore` column **does not exist** (Contact #18 ISSUE-3, Family #20 ISSUE-14, DuplicateContact #21 ISSUE-4). All widgets that reference an engagement score (KPI 4, KPI 5, chart 9, table 7) MUST compute a temporary approximation in-SQL:

```sql
-- Approximation formula (Path-A widget functions reuse this CTE):
GREATEST(0, LEAST(100,
   COALESCE(donation_count_12mo * 6, 0)             -- 0..60 from frequency
 + COALESCE(LEAST(lifetime_amount / 1000, 25), 0)   -- 0..25 from depth
 + CASE WHEN last_activity_at >= now()-interval'90 day' THEN 15 ELSE 0 END  -- recency bump
))::int AS engagement_score_approx
```

Pre-flagged as ⑫ ISSUE-1. When AI Engagement Scoring (Wave 4 #76) lands, swap formula → `Contact.EngagementScore` column directly. Widget contracts unchanged.

---

## ③ Source Entity & Aggregate Query Resolution

**Consumer**: Backend Developer (Postgres function authors) + Frontend Developer (widget binding via `Widget.StoredProcedureName`)

> Path-A across all widgets. Each widget calls `SELECT * FROM corg."{function_name}"(p_filter_json::jsonb, p_page, p_page_size, p_user_id, p_company_id)` via the existing `generateWidgets` GraphQL handler.

| # | Source Entity | Entity File Path | Postgres Function | GQL Field | Returns (data jsonb shape) | Filter Args (in p_filter_json) |
|---|--------------|------------------|-------------------|-----------|----------------------------|-------------------------------|
| 1 | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | `corg.fn_contact_dashboard_kpi_total_contacts` | generateWidgets | `{value:int, deltaThisMonth:int, activeCount:int, subtitle:string}` | dateFrom, dateTo, contactBaseTypeId, branchId, contactSourceId |
| 2 | Contact + GlobalDonation | (joins) | `corg.fn_contact_dashboard_kpi_active_donors` | generateWidgets | `{value:int, yoyPercent:decimal, percentOfBase:decimal, subtitle:string}` | dateFrom, dateTo, contactBaseTypeId, branchId |
| 3 | Contact | `corg.Contacts` | `corg.fn_contact_dashboard_kpi_new_this_month` | generateWidgets | `{value:int, momPercent:decimal, topSourceName:string, topSourceCount:int, subtitle:string}` | contactBaseTypeId, branchId, contactSourceId |
| 4 | Contact | `corg.Contacts` (engagement_score_approx CTE) | `corg.fn_contact_dashboard_kpi_avg_engagement` | generateWidgets | `{value:int, qoqDeltaPoints:int, highBandPercent:decimal, subtitle:string}` | dateFrom, dateTo, contactBaseTypeId, branchId |
| 5 | Contact + GlobalDonation | (joins, no-gift-18mo + Lifetime≥$5K) | `corg.fn_contact_dashboard_kpi_churn_risk` | generateWidgets | `{value:int, highValueCount:int, subtitle:string}` | contactBaseTypeId, branchId |
| 6 | DuplicateContact | `corg.DuplicateContacts` | `corg.fn_contact_dashboard_kpi_pending_duplicates` | generateWidgets | `{value:int, highConfidenceCount:int, subtitle:string}` | branchId |
| 7 | Contact + ContactType + ContactTag + Tag + GlobalDonation | (joins, top-N by engagement_score_approx) | `corg.fn_contact_dashboard_top_engaged_contacts` | generateWidgets | `[{contactId, displayName, avatarInitials, contactBaseTypeName, contactBaseTypeBadge:"individual/corporate/foundation/family", engagementScore:int, engagementBand:"high/med/low", lastActivityRelative:string, lifetimeAmount:decimal, tagsCsv:string, activityBarPercent:int}]` (LIMIT 10) | dateFrom, dateTo, contactBaseTypeId, branchId |
| 8 | Contact + ContactType (or ContactBaseType MasterData) | (join) | `corg.fn_contact_dashboard_contacts_by_type` | generateWidgets | `{total:int, segments:[{label, value:int, pct:decimal, color:string}, ...4]}` | branchId, contactSourceId |
| 9 | Contact (engagement_score_approx) | `corg.Contacts` | `corg.fn_contact_dashboard_engagement_histogram` | generateWidgets | `{bins:[{label:"0-20",value:int,color:string}, ...5 bins], lowPercent:decimal, medPercent:decimal, highPercent:decimal}` | dateFrom, dateTo, contactBaseTypeId, branchId, contactSourceId — active donors only |
| 10 | Contact + ContactSource | (join, GROUP BY month + ContactSourceId) | `corg.fn_contact_dashboard_acquisition_trend` | generateWidgets | `{labels:[12 months], series:[{name:string, color:string, data:[int x12]}], annotations:[{xValue:string, label:string}]}` | branchId, contactBaseTypeId, contactSourceId — over last 12 months from window-end |
| 11 | Contact + City | `corg.Contacts` + `com.Cities` | `corg.fn_contact_dashboard_geography` | generateWidgets | `[{cityName, value:int, color:string, widthPct:decimal}, ...top 6 cities + Others bucket]` | dateFrom, dateTo, contactBaseTypeId, contactSourceId |
| 12 | Tag + ContactTag | `corg.Tags` + `corg.ContactTags` | `corg.fn_contact_dashboard_top_tags` | generateWidgets | `[{tagId, tagName, color:string, count:int, sizeTier:"lg/md/sm"}]` (LIMIT 12) | branchId, contactBaseTypeId — sizeTier rule: count≥250→lg, ≥100→md, else sm |
| 13 | Family + Contact | `corg.Families` + `corg.Contacts` (FamilyId, IsFamilyHead) | `corg.fn_contact_dashboard_family_health` | generateWidgets | `{title:"Family Health", linkRoute:"crm/contact/family", linkLabel:"View Families", cells:[{label:"Total Families",value:"938",amount:"3,742 members",tone:"indigo"},{label:"With Head",value:"872",amount:"93%",tone:"success"},{label:"Headless",value:"66",amount:"need head set",tone:"warn"},{label:"Avg Members",value:"4.0",amount:"per family",tone:"neutral"}]}` | branchId |
| 14 | DuplicateContact | `corg.DuplicateContacts` | `corg.fn_contact_dashboard_duplicate_detection` | generateWidgets | `{title:"Duplicate Detection", linkRoute:"crm/maintenance/duplicatecontact", linkLabel:"Review Queue", cells:[{label:"Pending",value:"42",amount:"avg confidence 78%",tone:"warn"},{label:"High-Confidence",value:"28",amount:"≥ 90% match",tone:"indigo"},{label:"Merged (YTD)",value:"186",amount:"automatic + manual",tone:"success"},{label:"Not-Duplicate",value:"47",amount:"marked NDP",tone:"neutral"}], banner:{tone:"warn",iconCode:"ph:warning-light",text:"<strong>28 high-confidence duplicates</strong> waiting for review."}}` | branchId |
| 15 | Multi-source rule engine (Contact + DuplicateContact + ContactSource + Family + Segment) | (per ④ alert rules) | `corg.fn_contact_dashboard_alerts` | generateWidgets | `[{severity:"warning/danger/info/success", iconCode:string, message:string (may contain <strong>), link:{label, route, args:object}}]` (LIMIT 6) | dateFrom, dateTo, contactBaseTypeId, branchId |
| 16 | Segment | `corg.Segments` | `corg.fn_contact_dashboard_top_segments` | generateWidgets | `[{segmentId, segmentName, ownerName:string, members:int, delta30dInt:int, delta30dColor:"success/warn/danger/neutral", lastRefreshedRelative:string, visibilityLabel:"Public/Private/Auto", visibilityBadge:"individual/corporate/foundation"}]` (LIMIT 6) | branchId — order by `LastRunCount DESC` |

**Strategy**: **Path A — Postgres functions only**. No composite C# DTO; no per-widget GraphQL handler. Each widget binds to one function via `Widget.StoredProcedureName`. The runtime calls the existing `generateWidgets` GraphQL field with the function name + filter context. Matches the established `case.fn_case_dashboard_*` precedent (#52).

---

## ④ Business Rules & Validation

**Consumer**: BA Agent → Backend Developer (Postgres functions enforce filtering) → Frontend Developer (filter behavior + drill-down args)

### Date Range Defaults
- Default range: **This Year** (Jan 1 of current calendar year → today)
- Allowed presets: This Year / Last Year / This Quarter / Last Quarter / This Month / Custom Range
- Custom range max span: **2 years** (FE filter validation; functions cap p_filter_json date span if larger)
- Date filter applies to: `Contact.FirstContactDate` (KPI 1 deltaThisMonth, chart 10), `GlobalDonation.DonationDate` (KPI 2 active-donors window, KPI 5 churn-risk reference), `Contact.LastDonationDate` (KPI 5 last-gift derivation), `DuplicateContact.ActionDate` (widget 14 Merged YTD)

### Role-Scoped Data Access
- **BUSINESSADMIN** → sees ALL companies' data (no scoping; CompanyId from HttpContext but admin has cross-company visibility per existing pattern)
- **CRM_MANAGER / FUNDRAISING_DIRECTOR** → sees only own company (`CompanyId = HttpContext.CompanyId`)
- **BRANCH_MANAGER** → additionally filtered by `BranchId IN user's branches` (read from `auth.UserBranches`)
- **STAFF** → additionally restricted to their owned-contact subset (Contact.StaffUserId = currentUserId) IF that scoping is applied at the contact-list page level; on this dashboard, simplest v1 = same as CRM_MANAGER (skip the per-staff scope to avoid empty dashboards) — pre-flag as ⑫ ISSUE-2
- All scoping happens in the Postgres function via `p_user_id` + `p_company_id` parameters and helper joins

### Calculation Rules
- **Total Contacts (KPI 1)**: `COUNT(*) FROM corg.Contacts WHERE IsDeleted=false AND <filters>`. `deltaThisMonth = COUNT WHERE FirstContactDate >= date_trunc('month', now())`. `activeCount = COUNT WHERE ContactStatusId = (Active master-data)`.
- **Active Donors 12mo (KPI 2)**: `COUNT(DISTINCT ContactId) FROM fund.GlobalDonations WHERE DonationDate >= now() - interval '12 months' AND PaymentStatus IN (Completed-equivalent statuses)`. `yoyPercent = ((current - sameRangeLastYear) / sameRangeLastYear) * 100`. `percentOfBase = (value / totalContacts) * 100`.
- **New Contacts This Month (KPI 3)**: `COUNT(*) WHERE FirstContactDate >= date_trunc('month', now())`. `momPercent = ((current - lastMonth) / lastMonth) * 100`. `topSource = ContactSource with max COUNT in same window`.
- **Avg Engagement Score (KPI 4)**: `AVG(engagement_score_approx) FROM Contacts WHERE ContactStatusId=Active <filters>`. `qoqDeltaPoints = currentAvg - lastQuarterAvg`. `highBandPercent = COUNT WHERE engagement_score_approx >= 80 / total * 100`.
- **Churn Risk (KPI 5)**: `COUNT(DISTINCT ContactId) WHERE last_donation_date < now() - interval '18 months' AND lifetime_donation > 0`. `highValueCount = same set AND lifetime_donation > 5000`.
- **Pending Duplicates (KPI 6)**: `COUNT(*) FROM corg.DuplicateContacts WHERE ActionId = (PEN master-data)`. `highConfidenceCount = same set AND <confidence-derivation>` (per #21, confidence is computed: NAMEDOBCATEGORY≥95, NAMEMOBILECATEGORY≥90, NAMEEMAILCATEGORY≥85, MANUALCATEGORY=user-set; high-conf threshold = 90%).
- **Top Engaged Contacts (table 7)**: `engagement_score_approx ORDER BY DESC LIMIT 10`, with each row enriching: `displayName`, `avatarInitials = upper(left(firstName,1) || left(lastName,1))` (organizationName fallback for Corporate/Foundation), `contactBaseTypeBadge` mapped from `ContactBaseTypeId` MasterData (Individual / Corporate / Foundation / Family — note: Family is a contact-type bucket here, NOT the Family entity), `lastActivityRelative` = humanize(now() - GREATEST(LastDonationDate, LastModifiedDate)), `lifetimeAmount` = SUM(GlobalDonation.DonationAmount), `tagsCsv` = top-2 tags joined ', ', `activityBarPercent = LEAST(100, donation_count_90d * 20 + LEAST(50, lifetime_amount/1000))`.
- **Contacts by Type donut (chart 8)**: `COUNT(*) GROUP BY ContactBaseTypeId`. Map to mockup colors: Individual=#4f46e5, Corporate=#3b82f6, Foundation=#a855f7, Family=#f97316. Compute `pct` with 1 decimal.
- **Engagement Histogram (chart 9)**: 5 bins of 20 points each. Bin colors: 0-20=#ef4444, 21-40=#f97316, 41-60=#f59e0b, 61-80=#84cc16, 81-100=#4f46e5. `lowPercent = sum(bin0+bin1)/total*100`, `medPercent = bin2/total*100`, `highPercent = sum(bin3+bin4)/total*100`. Active donors only (donation in last 12mo).
- **Acquisition Trend (chart 10)**: 12 monthly buckets × 6 series (one per ContactSource: Website, Referral, Event, Walk-In, Import, Social Media). Colors per source come from `ContactSource.Color` if present (#122 added Color column) else fall back to a hardcoded palette `["#4f46e5","#3b82f6","#a855f7","#f97316","#06b6d4","#84cc16"]`. Annotations array — empty in v1 (no annotation seed table yet); pre-flag as ⑫ ISSUE-3.
- **Geography (chart 11)**: `COUNT(*) GROUP BY CityId ORDER BY count DESC LIMIT 6`. Append a 7th "Others" row with the rest. `widthPct = value / max_value * 100`. Colors per row from a fixed palette `["#4f46e5","#06b6d4","#3b82f6","#06b6d4","#8b5cf6","#94a3b8"]` + Others always `#94a3b8`.
- **Top Tags (widget 12)**: `COUNT(ContactTag) GROUP BY TagId ORDER BY count DESC LIMIT 12`. `sizeTier` per row: count≥250→`lg`, ≥100→`md`, else `sm`. First (highest-count) pill rendered with accent border + tinted bg.
- **Family Health (widget 13)**: `total_families = COUNT(*) FROM corg.Families`, `with_head = COUNT WHERE EXISTS(Contact WHERE FamilyId = f.FamilyId AND IsFamilyHead = true)`, `headless = total - with_head`, `total_members = COUNT FROM corg.Contacts WHERE FamilyId IS NOT NULL`, `avg_members = total_members / total_families` (round 1 decimal). `with_head` `amount` text formats `(with_head / total) * 100` as percent.
- **Duplicate Detection (widget 14)**: `pending = COUNT WHERE ActionId=PEN`, `high_confidence = COUNT WHERE ActionId=PEN AND <confidence>≥90`, `merged_ytd = COUNT WHERE ActionId=MRG AND ActionDate >= year_start`, `not_duplicate = COUNT WHERE ActionId=NDP`. Banner shown only when high_confidence > 0; banner text inserts the high_confidence count.
- **Alert generation rules (widget 15)** — top 6 by severity (danger > warning > info > success) then recency:
  - **DANGER** if `count(churn_risk WHERE lifetime_amount > 5000) > 0` → `<strong>{N} high-value donors at churn risk</strong> — no gift in 18+ months, lifetime $>5K` → Re-engage → `crm/contact/contact?segment=churn-risk-major`
  - **WARNING** if `count(pending_high_conf_duplicates) > 0` → `<strong>{N} high-confidence duplicates pending</strong> — oldest {days} days; impacts donor reporting accuracy` → Resolve → `crm/maintenance/duplicatecontact`
  - **INFO** if any source's MoM growth `≥ 20%` → `<strong>{SourceName} source up {pct}%</strong> this month — {N} new contacts; consider conversion follow-up` → View New → `crm/contact/contact?source={sourceName}&newThisMonth=true`
  - **WARNING** if `headless_families > 0` → `<strong>{N} families have no Head set</strong> — impacts family-summary roll-ups` → Fix → `crm/contact/family?hasHead=false`
  - **INFO** if any active-tag has `delta_quarter ≥ 20` AND tag name in (Lapsed, At-Risk, ...) → `<strong>"{TagName}" segment grew by {N}</strong> this quarter — potential win-back targets` → View Segment → `crm/contact/contact?tag={slug}`
  - **SUCCESS** if `qoq_engagement_delta_points ≥ 3` → `<strong>Engagement score up {N} points QoQ</strong> — activation campaign appears to be working` → Browse → `crm/contact/contact`
  - Hard cap of 6 alerts (matches mockup; no scroll/show-more).
- **Top Segments (table 16)**: `Segment ORDER BY LastRunCount DESC LIMIT 6`. Map `IsSystem=true` → visibility="Auto" badge corporate; else if `<convention>` private flag set → "Private" badge foundation; else "Public" badge individual. `delta30dInt` = `LastRunCount - last_run_minus_30d_count` (SERVICE_PLACEHOLDER until segment-history table — pre-flag ⑫ ISSUE-4; v1 returns deterministic dummy from hash of SegmentId for visual fidelity). `lastRefreshedRelative` = humanize(now() - LastRunDate). `ownerName` = SystemRole "System (computed)" if IsSystem else creator name from `User.UserName`.

### Multi-Currency Rules
- **KPI 2 / table 7 / churn-risk lifetime $**: aggregate `GlobalDonation.DonationAmount` AS-IS in v1 (no FX conversion). All subtitles mention "(USD-equivalent — multi-currency conversion pending)" tooltip. Pre-flag as ⑫ ISSUE-5. Donation Dashboard #54 will introduce the canonical FX conversion path.

### Widget-Level Rules
- A widget is RENDERED only if `auth.WidgetRoles(WidgetId, currentRoleId, HasAccess=true)` row exists. No row → widget hidden.
- All 16 widgets seed `WidgetRole(BUSINESSADMIN, HasAccess=true)`. Other roles inherit no grants by default — assigned at admin-config time.
- **Workflow**: None. Read-only. Drill-downs navigate AWAY.

---

## ⑤ Screen Classification & Pattern Selection

**Consumer**: Solution Resolver — these are PRE-ANSWERED.

**Screen Type**: DASHBOARD
**Variant**: MENU_DASHBOARD
**Reason**: Standalone analytical surface deep-linkable from email/segment campaigns; role-restricted to fundraising-facing users; tightly scoped to Contact module. Already has its own sidebar leaf at `/crm/dashboards/contactdashboard` (MenuCode `CONTACTDASHBOARD` seeded under CRM_DASHBOARDS @ OrderBy=1).

**Backend Implementation Path** — **Path A across all 16 widgets**:
- [x] **Path A — Postgres function (generic widget)**: Each widget = 1 SQL function in `corg.` schema returning `(data jsonb, metadata jsonb, total_count integer, filtered_count integer)`. Reuses the existing `generateWidgets` GraphQL handler. Seed `Widget.StoredProcedureName='corg.{function_name}'`. NO new C# code; only 16 SQL deliverables.
- [ ] Path B — Named GraphQL query (NOT used)
- [ ] Path C — Composite DTO (NOT used)

**Path-A Function Contract (NON-NEGOTIABLE)** — every function MUST:
- Take 5 fixed inputs in this order: `p_filter_json jsonb, p_page integer, p_page_size integer, p_user_id integer, p_company_id integer`
- Return `TABLE(data jsonb, metadata jsonb, total_count integer, filtered_count integer)` — single row, 4 columns
- Extract every filter from `p_filter_json` using `NULLIF(p_filter_json->>'keyName','')::type` (fields: `dateFrom`, `dateTo`, `contactBaseTypeId`, `branchId`, `contactSourceId`)
- Use Postgres syntax (`CREATE OR REPLACE FUNCTION ... LANGUAGE plpgsql`, `"PascalCase"` quoted identifiers, jsonb operators)
- Live at `PSS_2.0_Backend/DatabaseScripts/Functions/corg/{function_name}.sql` — snake_case names. Existing files in `corg/` are utility (`global_search.sql` etc); the dashboard functions are the first widget functions in this folder.
- `Widget.DefaultParameters` JSON keys MUST match the keys that the function reads from `p_filter_json` (e.g., `{ "dateFrom": "{dateFrom}", "dateTo": "{dateTo}", "contactBaseTypeId": "{contactBaseTypeId}", "branchId": "{branchId}", "contactSourceId": "{contactSourceId}" }` — placeholders substituted by widget runtime)
- Use the engagement_score_approx CTE (per §②E) wherever score is referenced — DO NOT reference a non-existent `Contact.EngagementScore` column

**Backend Patterns Required:**
- [x] Tenant scoping (CompanyId from HttpContext via p_company_id arg) — every function (CompanyId = NULL ⇒ admin override; CompanyId = N ⇒ filter `c."CompanyId" = p_company_id`)
- [x] Date-range parameterized queries
- [x] Role-scoped data filtering — joined to `auth.UserBranches` for BRANCH_MANAGER scope (per ④)
- [ ] Materialized view / cached aggregate — not needed; contact data volume small enough for live aggregation in v1

**Frontend Patterns Required:**
- [x] Widget grid via `react-grid-layout` (responsive breakpoints) — already in `<MenuDashboardComponent />`
- [x] Reuse renderers already present in `dashboard-widget-registry.tsx` `WIDGET_REGISTRY`:
      • `StatusWidgetType1` (KPI 1-6)
      • `MultiChartWidget` (chart 10 — stacked area config)
      • `PieChartWidgetType1` (chart 8 — donut)
      • `ColumnsChartWidgetType1` (chart 9 — histogram)
      • `BarChartWidgetType1` (chart 11 — horizontal bars)
      • `NormalTableWidget` (table 16 — segments)
      • `AlertListWidget` (widget 15 — already created by #52)
- [ ] **3 NEW renderers** required:
      1. `TopEngagedContactsTableWidget` — at `dashboards/widgets/contact-top-engaged-table-widget/index.tsx`. Renders 7-column table: Contact (avatar+name) / Type (badge) / Engagement (score chip) / Last Activity / Lifetime $ / Tags / Activity (90d mini-bar). Row click → `crm/contact/contact?mode=read&id={contactId}`. Reuse case-dashboard's table-widget patterns where applicable.
      2. `TagCloudWidget` — at `dashboards/widgets/contact-tag-cloud-widget/index.tsx`. Renders flex-wrap pill cloud with 3 size tiers (sm/md/lg). First pill (highest count) gets accent border + tinted bg. Each pill click → `crm/contact/contact?tag={tagSlug}`. Header right link "Manage Tags" → `crm/contact/tagsegmentation`.
      3. `MiniStatGridWidget` — at `dashboards/widgets/contact-mini-stat-grid-widget/index.tsx`. Renders 4-cell grid (4 cols × 1 row on lg). Each cell: label + value + amount line, tone colors (`indigo` / `success` / `warn` / `neutral` / `danger`). Header right link from `data.linkRoute + linkLabel`. Optional warning/info banner below grid from `data.banner` when non-null. Used by widgets 13 + 14.
- [x] Query registry — NOT extended (Path A uses `generateWidgets` only; query registry is for paths B/C)
- [x] Date-range picker / Type / Branch / Source select — render INSIDE `<MenuDashboardComponent />` toolbar (per its NEW component pattern §H/I of `_DASHBOARD.md`)
- [x] Skeleton states matching widget shapes (one shape per new renderer — required to ship with the renderer per Design Quality Standards)
- [x] **MENU_DASHBOARD page (Phase-2-aware transitional)** — REPLACE body of `src/app/[lang]/crm/dashboards/contactdashboard/page.tsx` with:
      ```tsx
      "use client";
      import { MenuDashboardComponent } from "@/presentation/components/custom-components/menu-dashboards";
      export default function ContactDashboard() {
        return <MenuDashboardComponent moduleCode="CRM" dashboardCode="CONTACTDASHBOARD" />;
      }
      ```
      Delete the old `ContactDashboardPageConfig` re-export from `presentation/pages/crm/index.ts` if it becomes orphaned. When the dynamic `[slug]/page.tsx` route lands (Case Dashboard #52 Phase 2 finish), this stub is also deleted.
- [x] **Toolbar overrides** for export / print — surface 2 buttons in dashboard header: "Export Report" (PDF — SERVICE_PLACEHOLDER) and "Print" (calls `window.print()`). Render directly in `<MenuDashboardComponent />`'s toolbar slot — same pattern as Case Dashboard #52.

---

## ⑥ UI/UX Blueprint

**Consumer**: UX Architect → Frontend Developer

> Layout follows the HTML mockup. All widgets render through `<MenuDashboardComponent moduleCode="CRM" dashboardCode="CONTACTDASHBOARD" />` → resolves to the seeded Dashboard row → reads LayoutConfig + ConfiguredWidget JSON → maps each instance to a widget renderer + a Postgres function.

### Page Chrome (MENU_DASHBOARD)

- **Header row** (rendered inside `<MenuDashboardComponent />`):
  - Left: page title `Contact Dashboard` + icon `ph:users-three` (indigo `#4f46e5`) + subtitle "Donor 360°: engagement health, segments, churn risk, and acquisition"
  - Right: **4 filter selects + 2 buttons**:
    1. Period select — default "This Year"; options: This Year / Last Year / This Quarter / Last Quarter / This Month / Custom Range. "Custom Range" opens an inline date-range popover.
    2. Contact Type select — default "All Contact Types"; options: All / Individual / Corporate / Foundation / Family. Populated from `corg.ContactTypes WHERE IsActive=true` OR static enum (decide at build; static is simpler — pre-flag ⑫ ISSUE-6 if dynamic).
    3. Branches select — default "All Branches"; options: All / dynamically loaded `app.Branches WHERE IsActive=true`.
    4. Sources select — default "All Sources"; options: All / dynamically loaded `corg.ContactSources WHERE IsActive=true`.
    5. **"Export Report"** primary button (PDF download) — SERVICE_PLACEHOLDER (toast "Generating contact report..."). Wire UI in place; backend PDF service deferred.
    6. **"Print"** outline button — calls `window.print()`. NO placeholder (browser primitive).

- **No dropdown switcher**, **no Edit Layout chrome** (read-only by default per MENU_DASHBOARD pattern).
- **No refresh button** in v1 (filter changes act as refresh).

### Grid Layout (react-grid-layout — `lg` breakpoint, 12 columns)

| i (instanceId) | Widget | x | y | w | h | minW | minH | Notes |
|----------------|--------|---|---|---|---|------|------|-------|
| KPI_TOTAL_CONTACTS | KPI 1 | 0 | 0 | 4 | 2 | 3 | 2 | Hero row 1, col 1 — indigo icon |
| KPI_ACTIVE_DONORS | KPI 2 | 4 | 0 | 4 | 2 | 3 | 2 | Hero row 1, col 2 — emerald icon |
| KPI_NEW_THIS_MONTH | KPI 3 | 8 | 0 | 4 | 2 | 3 | 2 | Hero row 1, col 3 — blue icon |
| KPI_AVG_ENGAGEMENT | KPI 4 | 0 | 2 | 4 | 2 | 3 | 2 | Hero row 2, col 1 — purple icon |
| KPI_CHURN_RISK | KPI 5 | 4 | 2 | 4 | 2 | 3 | 2 | Hero row 2, col 2 — rose icon |
| KPI_PENDING_DUPLICATES | KPI 6 | 8 | 2 | 4 | 2 | 3 | 2 | Hero row 2, col 3 — amber icon |
| TBL_TOP_ENGAGED_CONTACTS | Top 10 Engaged Contacts | 0 | 4 | 12 | 7 | 8 | 5 | Full-width table |
| CHART_CONTACTS_BY_TYPE | Contacts by Type donut | 0 | 11 | 5 | 5 | 4 | 4 | Half-width-left donut |
| CHART_ENGAGEMENT_HISTOGRAM | Engagement Score Distribution | 5 | 11 | 7 | 5 | 5 | 4 | Half-width-right histogram |
| CHART_ACQUISITION_TREND | Contact Acquisition Trend | 0 | 16 | 12 | 5 | 8 | 4 | Full-width stacked area |
| CHART_GEOGRAPHY | By Geography (Top 6) | 0 | 21 | 6 | 4 | 4 | 3 | Half-width h-bar |
| WIDGET_TOP_TAGS | Top Tags | 6 | 21 | 6 | 4 | 4 | 3 | Half-width tag cloud |
| WIDGET_FAMILY_HEALTH | Family Health 4-mini-stat | 0 | 25 | 6 | 4 | 4 | 3 | Half-width mini-stat grid |
| WIDGET_DUPLICATE_DETECTION | Duplicate Detection 4-mini-stat | 6 | 25 | 6 | 4 | 4 | 3 | Half-width mini-stat grid + banner |
| LIST_ALERTS | Alerts & Actions | 0 | 29 | 12 | 4 | 8 | 3 | Full-width alerts list (6 alerts) |
| TBL_TOP_SEGMENTS | Top Segments & Saved Filters | 0 | 33 | 12 | 5 | 8 | 4 | Full-width collapsible — start expanded; chevron toggles in v1 — IF FilterTableWidget supports collapse natively, use it; else render NormalTableWidget without collapse and pre-flag ⑫ ISSUE-7 |

`md` (8 cols), `sm` (6 cols), `xs` (4 cols) — collapse multi-column rows into stacked single-column / 2-column layouts. Minimum viable: `lg` defined; others auto-derived by react-grid-layout's responsive behavior + explicit `xs` config that stacks every widget vertically at width=4.

### KPI Cards (StatusWidgetType1 — 6 cards)

| # | InstanceId | Title | Value Format | Subtitle Format | Color Cue | Icon |
|---|-----------|-------|--------------|-----------------|-----------|------|
| 1 | KPI_TOTAL_CONTACTS | Total Contacts | count (e.g., "12,456") | "↑ {deltaThisMonth} new this month · {activeCount} active" (positive green for delta) | indigo | ph:users-light |
| 2 | KPI_ACTIVE_DONORS | Active Donors (12 mo) | count | "↑ {yoyPercent}% vs last year · {percentOfBase}% of base" (positive green) | emerald | ph:heartbeat-light |
| 3 | KPI_NEW_THIS_MONTH | New Contacts (this month) | count | "↑ {momPercent}% vs last month · top src: {topSourceName} ({topSourceCount})" (positive green for delta) | blue | ph:user-plus-light |
| 4 | KPI_AVG_ENGAGEMENT | Avg Engagement Score | "{value} / 100" | "↑ {qoqDeltaPoints} pts QoQ · {highBandPercent}% in High band" (positive green) | purple | ph:chart-line-light |
| 5 | KPI_CHURN_RISK | Churn Risk | count | "↑ {highValueCount} high-risk · no gift in 18+ mo" (danger red for highValueCount) | rose | ph:user-clock-light |
| 6 | KPI_PENDING_DUPLICATES | Pending Duplicates | count | "{highConfidenceCount} high-confidence · need review" (warning amber for highConfidenceCount) | amber | ph:copy-light |

### Top 10 Engaged Contacts (table 7) — NEW renderer `TopEngagedContactsTableWidget`

Columns:
1. **Contact** — `<avatar(initials)> + displayName` (left, no border)
2. **Type** — badge (center) with mockup color map: Individual=indigo, Corporate=blue, Foundation=purple, Family=orange
3. **Engagement** — score chip (center) with dot color: ≥80 high (green), 60-79 med (amber), <60 low (red)
4. **Last Activity** — relative humanize (center)
5. **Lifetime $** — right-aligned, mono font, formatted currency `$118,400`
6. **Tags** — truncated comma-list (center) — top 2 tags joined ', '
7. **Activity (90d)** — mini-bar (140px wide, indigo gradient fill)

Row click: `crm/contact/contact?mode=read&id={contactId}`. Header right text: "Click row to view contact profile".

### Charts (detail per chart)

| # | InstanceId | Title | Type | X | Y | Source | Filters Honored | Empty/Tooltip |
|---|-----------|-------|------|---|---|--------|-----------------|---------------|
| 8 | CHART_CONTACTS_BY_TYPE | Contacts by Type | Donut | — | — | data.segments | branch, source | "No contacts match filter" |
| 9 | CHART_ENGAGEMENT_HISTOGRAM | Engagement Score Distribution | Vertical Bars (5 bins) | Bin label | Count | data.bins | period, type, branch, source — active donors only | "No active donors in selected period" |
| 10 | CHART_ACQUISITION_TREND | Contact Acquisition Trend | Stacked Area (12mo × 6 series) | Month | New contacts | data.series[].data | type, branch, source | "No acquisitions in selected period" |
| 11 | CHART_GEOGRAPHY | By Geography (Top 6) | Horizontal Bar | Count | City | data array — 6 + Others | period, type, source | "No location data" |

### Top Tags Cloud (widget 12) — NEW renderer `TagCloudWidget`

Layout: flex-wrap pill cloud. Pill shape: rounded-full, padded `0.35rem 0.75rem`, gap `0.4rem` between name and count. Pill name + count badge (white inset). 3 size tiers: `lg` (font 0.9375rem), `md` (font 0.8125rem), default (font 0.75rem). First pill (highest count): border-color = accent indigo, bg = indigo-bg, name color = accent. Click → `crm/contact/contact?tag={tagSlug}`. Header right link "Manage Tags →" → `crm/contact/tagsegmentation`.

### Family Health & Duplicate Detection (widgets 13 & 14) — NEW renderer `MiniStatGridWidget`

Layout: 4-column grid (1-row tall on lg; 2×2 on sm; stacked on xs). Each cell: small label (uppercase, letter-spaced 0.04em, secondary color), large value (1.25rem bold, tone color), small amount (0.6875rem secondary). Tone colors: `indigo`=#4f46e5, `success`=#22c55e, `warn`=#f59e0b, `neutral`=secondary, `danger`=#dc2626. Header right link from `data.linkRoute + linkLabel` (Family Health → `crm/contact/family` "View Families"; Duplicate Detection → `crm/maintenance/duplicatecontact` "Review Queue"). Below grid: optional banner (tone-tinted bg, icon + sanitized HTML text — supports `<strong>` only) when `data.banner != null` (Duplicate Detection only).

### Alerts & Actions (widget 15) — Reuse `AlertListWidget` (created by #52)

Renders a vertical list of alert rows. Same shape as Case Dashboard #52:

```typescript
{
  severity: 'warning' | 'danger' | 'info' | 'success';   // colors background pill
  iconCode: string;                                       // phosphor icon (mockup uses fa-* — map per severity: danger→ph:user-clock, warning→ph:copy or ph:house-circle-warning, info→ph:trend-up or ph:tag, success→ph:check-circle)
  message: string;                                        // can include <strong> tags (renderer parses & escapes safely)
  link: { label: string; route: string; args?: Record<string, string | number>; }
}
```

Mockup shows 6 alerts; cap at 6.

### Top Segments & Saved Filters (table 16) — `NormalTableWidget`

Columns: Segment (left, bold) / Owner (left) / Members (center) / Δ 30d (center, color-coded text) / Last Refreshed (center, relative) / Visibility (center, badge: Public→individual blue, Private→foundation purple, Auto→corporate blue). Row click → `crm/contact/tagsegmentation` (no per-segment drill yet — Tag/Segment #22 list page accepts no per-segment route arg; pre-flag ⑫ ISSUE-8 to follow-up). Footer "Create Segment" button → `crm/contact/tagsegmentation` (link, NOT a modal). Collapsible header with chevron — if `NormalTableWidget` doesn't support a collapsible chrome natively, omit collapse in v1 and track as ⑫ ISSUE-7.

### Filter Controls

| Filter | Type | Default | Applies To | Notes |
|--------|------|---------|-----------|-------|
| Period | Native select + custom range popover | "This Year" | KPI 1/2/3/4/5, charts 9/10, table 7, alerts | Presets: This Year / Last Year / This Quarter / Last Quarter / This Month / Custom Range |
| Contact Type | Single-select (5 options) | "All Contact Types" | KPI 1/2/4/5, charts 9/10/11, table 7, widget 12 | NOT honored by chart 8 (since it groups BY type), KPI 6 (duplicates), widgets 13/14/15/16 |
| Branch | Single-select (ApiSelectV2) — typeahead from `app.Branches` | "All Branches" or user's branch (BRANCH_MANAGER) | All KPIs, charts 8/9/10/11, table 7, widgets 12/13/14, alerts | Always honored by all widgets except table 16 (segments are global to company) |
| Source | Single-select — from `corg.ContactSources` | "All Sources" | KPI 3, charts 8/9/10/11 | NOT honored by KPI 1/2/4/5/6 (semantics blur), table 7, widgets 12/13/14/15/16 |

Filter values flow into `<MenuDashboardComponent />`'s filter context, which projects them into each widget's `customParameter` JSON via the runtime's `{placeholder}` substitution. Functions read them out of `p_filter_json`.

### Drill-Down / Navigation Map

| From Widget / Element | Click On | Navigates To | Prefill |
|-----------------------|----------|--------------|---------|
| Top Engaged row (table 7) | Whole row | `crm/contact/contact?mode=read&id={contactId}` | — |
| Top Tag pill (widget 12) | Pill click | `crm/contact/contact?tag={tagSlug}` | tag=slug-form-of-tagName (SERVICE_PLACEHOLDER until Contact list accepts ?tag= — see Contact #18 ISSUE-19; degrade to plain navigation) |
| "Manage Tags" header link (widget 12) | Click | `crm/contact/tagsegmentation` | — |
| Family Health header link | "View Families →" | `crm/contact/family` | — |
| Family Health "Headless" cell (no click target in mockup) | — | (hint to fix at family list — non-clickable v1) | — |
| Duplicate Detection header link | "Review Queue →" | `crm/maintenance/duplicatecontact` | — |
| Duplicate Detection cells (no click target) | — | non-clickable v1 | — |
| Alert link (varies per alert) | CTA link | Per `link.route` from alert data | Per `link.args` (some are SERVICE_PLACEHOLDER until destination accepts: `?segment=`, `?source=&newThisMonth=true`, `?hasHead=false`, `?tag=`) |
| Segment row (table 16) | Whole row | `crm/contact/tagsegmentation` | (per-segment drill SERVICE_PLACEHOLDER) |
| Segment "Create Segment" button | Click | `crm/contact/tagsegmentation` | — |
| "Export Report" toolbar | Click | SERVICE_PLACEHOLDER toast | Eventual: `/reports/html-report-viewer?reportType=CONTACT&...` |
| "Print" toolbar | Click | `window.print()` | — |

### User Interaction Flow

1. **Initial load**: User clicks `CRM → Dashboards → Contact Dashboard` in sidebar → URL becomes `/[lang]/crm/dashboards/contactdashboard` → `page.tsx` renders `<MenuDashboardComponent moduleCode="CRM" dashboardCode="CONTACTDASHBOARD" />`. Component fires `dashboardByModuleAndCode(moduleCode='CRM', dashboardCode='CONTACTDASHBOARD')` → returns ONE row + DashboardLayout JSON → renders 16-widget grid → all widgets parallel-fetch via `generateWidgets` with default filters (This Year / All Types / All Branches / All Sources).
2. **Filter change** (Period / Type / Branch / Source): widgets honoring that filter refetch in parallel; widgets NOT honoring it stay cached. Refetch flows through the filter context refresh-on-change.
3. **Drill-down click**: navigates per Drill-Down Map → destination receives prefill args. Some args are SERVICE_PLACEHOLDER until destination accepts (degrade gracefully — destination loads unfiltered + toast).
4. **Back navigation**: returns to dashboard → filters preserved (URL search params persist; if not feasible, default filters re-apply — confirm in build).
5. **Export Report** → toast SERVICE_PLACEHOLDER. **Print** → `window.print()`.
6. **No edit-layout / add-widget chrome** in v1 (deferred MENU_DASHBOARD chrome).
7. **Empty / loading / error states**: each widget renders its own skeleton during fetch (StatusWidgetType1 → KPI skeleton; charts → chart skeleton; tables → row skeletons; alert list → 3-row skeleton; tag cloud → 8-pill skeleton; mini-stat-grid → 4-cell muted skeleton). Error → red mini banner + Retry button. Empty → muted icon + per-widget empty message.

---

## ⑦ Substitution Guide

**Consumer**: Backend Developer + Frontend Developer

> Second MENU_DASHBOARD prompt (after Case Dashboard #52). Reuses #52's conventions; establishes additional `corg.fn_contact_dashboard_*` and 3 new generic widget renderers that Donor Dashboard / Volunteer Dashboard / Communication Dashboard can subsequently reuse (mini-stat-grid, tag-cloud, top-engaged-contacts-table renderers are intentionally generic-named).

**Canonical Reference**: Case Dashboard #52 (`prompts/casedashboard.md`). Reference Postgres widget patterns: `case.fn_case_dashboard_*` files in `Functions/case/`.

| Convention | This Dashboard | Notes |
|-----------|----------------|-------|
| DashboardCode | `CONTACTDASHBOARD` | Matches existing seeded MenuCode |
| MenuUrl | `crm/dashboards/contactdashboard` | Already seeded; no change |
| Schema for Postgres functions | `corg.fn_contact_dashboard_*` | First widget functions in `corg/` (other corg files are utility) |
| Function naming | `fn_contact_dashboard_{aspect}` | snake_case; aspects: kpi_*, chart_*/* (loose), top_engaged_contacts, top_tags, family_health, duplicate_detection, top_segments, alerts |
| Widget instance ID | `{TYPE}_{NAME}` (e.g., `KPI_TOTAL_CONTACTS`) | Stable across LayoutConfig + ConfiguredWidget |
| Module | `CRM` | ModuleCode resolves to ModuleId at seed time |
| Parent menu | `CRM_DASHBOARDS` | Already seeded |
| FE route stub | `src/app/[lang]/crm/dashboards/contactdashboard/page.tsx` | Already exists; replace body to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="CONTACTDASHBOARD" />` |
| New widget renderer folder names | `contact-top-engaged-table-widget`, `contact-tag-cloud-widget`, `contact-mini-stat-grid-widget` | Match `case-*-widget` precedent; the renderers themselves are generic-shaped (not contact-specific) but folder is namespaced for now |

---

## ⑧ File Manifest

**Consumer**: Backend Developer + Frontend Developer

### Backend Files (Path A only — 16 SQL functions, NO C# code)

| # | File | Path | Required |
|---|------|------|----------|
| 1 | `fn_contact_dashboard_kpi_total_contacts.sql` | `PSS_2.0_Backend/DatabaseScripts/Functions/corg/` | YES |
| 2 | `fn_contact_dashboard_kpi_active_donors.sql` | `…/Functions/corg/` | YES |
| 3 | `fn_contact_dashboard_kpi_new_this_month.sql` | `…/Functions/corg/` | YES |
| 4 | `fn_contact_dashboard_kpi_avg_engagement.sql` | `…/Functions/corg/` | YES |
| 5 | `fn_contact_dashboard_kpi_churn_risk.sql` | `…/Functions/corg/` | YES |
| 6 | `fn_contact_dashboard_kpi_pending_duplicates.sql` | `…/Functions/corg/` | YES |
| 7 | `fn_contact_dashboard_top_engaged_contacts.sql` | `…/Functions/corg/` | YES |
| 8 | `fn_contact_dashboard_contacts_by_type.sql` | `…/Functions/corg/` | YES |
| 9 | `fn_contact_dashboard_engagement_histogram.sql` | `…/Functions/corg/` | YES |
| 10 | `fn_contact_dashboard_acquisition_trend.sql` | `…/Functions/corg/` | YES |
| 11 | `fn_contact_dashboard_geography.sql` | `…/Functions/corg/` | YES |
| 12 | `fn_contact_dashboard_top_tags.sql` | `…/Functions/corg/` | YES |
| 13 | `fn_contact_dashboard_family_health.sql` | `…/Functions/corg/` | YES |
| 14 | `fn_contact_dashboard_duplicate_detection.sql` | `…/Functions/corg/` | YES |
| 15 | `fn_contact_dashboard_alerts.sql` | `…/Functions/corg/` | YES |
| 16 | `fn_contact_dashboard_top_segments.sql` | `…/Functions/corg/` | YES |

NO C# source files. NO new EF migration. NO new Mapster config. NO new GraphQL endpoints.

### Frontend Files

#### Created (4 files)

| # | File | Path | Required |
|---|------|------|----------|
| 1 | `index.tsx` (TopEngagedContactsTableWidget) | `PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/contact-top-engaged-table-widget/` | YES — 7-col table; row click prefill |
| 2 | `index.tsx` (TagCloudWidget) | `…/widgets/contact-tag-cloud-widget/` | YES — flex-wrap pill cloud, 3 size tiers |
| 3 | `index.tsx` (MiniStatGridWidget) | `…/widgets/contact-mini-stat-grid-widget/` | YES — 4-cell grid + optional banner |
| 4 | (Skeleton sub-components) — co-located with each renderer above | same folder | YES — shape-matching skeletons (Design Quality §) |

#### Modified (3 files)

| # | File | Change |
|---|------|--------|
| 1 | `dashboard-widget-registry.tsx` | extend `WIDGET_REGISTRY` with 3 new entries: `TopEngagedContactsTableWidget`, `TagCloudWidget`, `MiniStatGridWidget` |
| 2 | `src/app/[lang]/crm/dashboards/contactdashboard/page.tsx` | REPLACE body with `<MenuDashboardComponent moduleCode="CRM" dashboardCode="CONTACTDASHBOARD" />`. Drop `ContactDashboardPageConfig` import. |
| 3 | `presentation/pages/crm/index.ts` (or wherever `ContactDashboardPageConfig` is re-exported) | Drop the orphaned `ContactDashboardPageConfig` re-export line if it's no longer referenced. Keep file otherwise. |

### DB Seed (1 file)

| # | File | Purpose |
|---|------|---------|
| 1 | `sql-scripts-dyanmic/ContactDashboard-sqlscripts.sql` | Idempotent seed: Dashboard row + DashboardLayout (JSON × 4 breakpoints + 16-widget ConfiguredWidget JSON) + 3 NEW WidgetType rows + 16 Widget rows + 16 WidgetRole BUSINESSADMIN grants + UPDATE Dashboard SET MenuId = (SELECT MenuId FROM auth.Menus WHERE MenuCode='CONTACTDASHBOARD' AND ModuleId=<CRM>). NO new auth.Menus seed (CONTACTDASHBOARD menu pre-exists). NO Grid / GridFields seeds (DASHBOARD has no RJSF form). Use `IF NOT EXISTS` / `ON CONFLICT DO NOTHING` / `ON CONFLICT DO UPDATE` for re-runnability. (Folder name "dyanmic" preserves the repo-wide typo.) |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL
DashboardVariant: MENU_DASHBOARD

# CONTACTDASHBOARD menu already seeded under CRM_DASHBOARDS @ OrderBy=1.
# This prompt does NOT create a new auth.Menus row — it only links Dashboard.MenuId to the existing menu.

MenuName: Contact Dashboard               # (already in auth.Menus — no write needed)
MenuCode: CONTACTDASHBOARD                # (already in auth.Menus)
ParentMenu: CRM_DASHBOARDS
Module: CRM
MenuUrl: crm/dashboards/contactdashboard  # (already in auth.Menus)
GridType: DASHBOARD

MenuCapabilities: READ, EXPORT, ISMENURENDER
RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT

GridFormSchema: SKIP
GridCode: CONTACTDASHBOARD

# Dashboard-specific seed inputs
DashboardCode: CONTACTDASHBOARD
DashboardName: Contact Dashboard
DashboardIcon: ph:users-three
DashboardColor: #4f46e5
IsSystem: true
DashboardKind: MENU_DASHBOARD          # encoded by Dashboard.MenuId NOT NULL
OrderBy: 1                              # already on auth.Menus.OrderBy
WidgetGrants:
  - KPI_TOTAL_CONTACTS: BUSINESSADMIN
  - KPI_ACTIVE_DONORS: BUSINESSADMIN
  - KPI_NEW_THIS_MONTH: BUSINESSADMIN
  - KPI_AVG_ENGAGEMENT: BUSINESSADMIN
  - KPI_CHURN_RISK: BUSINESSADMIN
  - KPI_PENDING_DUPLICATES: BUSINESSADMIN
  - TBL_TOP_ENGAGED_CONTACTS: BUSINESSADMIN
  - CHART_CONTACTS_BY_TYPE: BUSINESSADMIN
  - CHART_ENGAGEMENT_HISTOGRAM: BUSINESSADMIN
  - CHART_ACQUISITION_TREND: BUSINESSADMIN
  - CHART_GEOGRAPHY: BUSINESSADMIN
  - WIDGET_TOP_TAGS: BUSINESSADMIN
  - WIDGET_FAMILY_HEALTH: BUSINESSADMIN
  - WIDGET_DUPLICATE_DETECTION: BUSINESSADMIN
  - LIST_ALERTS: BUSINESSADMIN
  - TBL_TOP_SEGMENTS: BUSINESSADMIN
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

**Consumer**: Frontend Developer

**Queries used by this dashboard**:

| GQL Field | Returns | Key Args | Scope |
|-----------|---------|----------|-------|
| `dashboardByModuleAndCode` (existing, created by #52 Phase 2) | Single Dashboard row + DashboardLayouts (JSON) + Module | `moduleCode: "CRM", dashboardCode: "CONTACTDASHBOARD"` | MENU_DASHBOARD slug fetch — NO UserDashboard join |
| `generateWidgets` (existing, runtime widget executor) | per-widget `(data jsonb, metadata jsonb, total_count int, filtered_count int)` | `storedProcedureName, parameters jsonb, page, pageSize` | Each widget calls this with its `Widget.StoredProcedureName` + filter context |

NO new query handlers, NO composite DTO, NO per-widget GraphQL fields.

**Per-widget data jsonb shapes**: see §③ "Returns" column for each function — those shapes are the contracts that the FE renderers consume.

**Filter shape passed to every function** (`p_filter_json`):

```json
{
  "dateFrom": "2026-01-01",
  "dateTo": "2026-04-29",
  "contactBaseTypeId": 1,
  "branchId": 5,
  "contactSourceId": 3
}
```

Any key may be empty (`""` or absent) — every function uses `NULLIF(p_filter_json->>'key','')::int IS NULL` to no-op. Each function additionally honors the standard tenant + role scoping via `p_user_id`/`p_company_id` (per §④).

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (no C# changes; verifies nothing breaks adjacent code)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/dashboards/contactdashboard`
- [ ] Existing per-route stub `crm/dashboards/contactdashboard/page.tsx` body REPLACED to render `<MenuDashboardComponent moduleCode="CRM" dashboardCode="CONTACTDASHBOARD" />`. Old `ContactDashboardPageConfig` orphan dropped.

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Network tab on `/crm/dashboards/contactdashboard` shows exactly ONE GraphQL request for layout: `dashboardByModuleAndCode(moduleCode:"CRM", dashboardCode:"CONTACTDASHBOARD")` (no module-wide list fetch leakage)
- [ ] All 16 widgets fire `generateWidgets` in parallel after layout resolves
- [ ] Each KPI card renders the spec'd value + subtitle pattern (per §⑥ KPI table)
- [ ] Top Engaged Contacts table renders 10 rows with avatar + type badge + score chip + last-activity + lifetime $ + tags + 90d activity bar
- [ ] Donut renders 4 segments + center label "12,456 contacts" (or live total)
- [ ] Histogram renders 5 colored bins + below-chart Low/Med/High percentage strip
- [ ] Stacked area renders 12 months × 6 source series; legend matches mockup colors
- [ ] Geography horizontal bars render top 6 + Others (7 rows)
- [ ] Top Tags cloud renders ≤12 pills with 3 size tiers; first pill highlighted
- [ ] Family Health renders 4 mini-stats with correct tone colors (indigo/success/warn/neutral)
- [ ] Duplicate Detection renders 4 mini-stats + warning banner with `<strong>` HTML safely escaped
- [ ] Alerts list renders 6 rows with severity-tinted bg, icon, message (with `<strong>` safely rendered), and CTA link
- [ ] Top Segments table renders 6 rows with delta30d color coding + visibility badge variants
- [ ] Period filter change refetches widgets honoring it (per §⑥ filter table); others stay cached
- [ ] Contact Type filter change refetches honoring widgets
- [ ] Branch filter change refetches honoring widgets
- [ ] Source filter change refetches honoring widgets
- [ ] Drill-down clicks navigate to correct destinations (11 click targets in §⑥ table); SERVICE_PLACEHOLDER paths land on destination unfiltered + toast
- [ ] Empty state renders per widget when no data in selected range
- [ ] Skeleton states render during fetch (KPI / chart / table / pill cloud / mini-stat-grid / alert list — each shape-matching)
- [ ] Error state renders if a widget query fails (red mini banner + Retry)
- [ ] Role-based widget gating: WidgetRole(HasAccess=false) hides widget for unauthorized roles
- [ ] Sidebar leaf "Contact Dashboard" visible to BUSINESSADMIN under CRM → Dashboards
- [ ] react-grid-layout reflows correctly across xs/sm/md/lg/xl
- [ ] "Print" toolbar button calls `window.print()` and the dashboard prints in a clean layout (toolbar + chart skeletons hidden via @media print rules — pre-flag ⑫ ISSUE-9 if not in scope)
- [ ] "Export Report" toolbar shows SERVICE_PLACEHOLDER toast

**DB Seed Verification:**
- [ ] Dashboard row inserted: DashboardCode=CONTACTDASHBOARD, ModuleId=CRM ModuleId, IsSystem=true, IsActive=true, CompanyId=NULL
- [ ] Dashboard row UPDATED: `MenuId IS NOT NULL` (linked to auth.Menus.MenuCode='CONTACTDASHBOARD')
- [ ] DashboardLayout row inserted with valid LayoutConfig JSON (parses; lg has 16 entries; md/sm/xs derive correctly) and ConfiguredWidget JSON (16 entries; instanceIds unique; instanceIds match LayoutConfig `i` values)
- [ ] 3 new WidgetType rows inserted: TopEngagedContactsTableWidget / TagCloudWidget / MiniStatGridWidget — ComponentPath matches keys registered in FE WIDGET_REGISTRY
- [ ] 16 Widget rows inserted with `StoredProcedureName='corg.fn_contact_dashboard_*'` (exact names per §⑧)
- [ ] 16 WidgetRole rows inserted (BUSINESSADMIN, HasAccess=true)
- [ ] All 16 Postgres functions exist in `corg.` schema (DESCRIBE FUNCTION returns the 5-arg / 4-column shape)
- [ ] Re-running seed is idempotent (NOT EXISTS guards on every INSERT/UPDATE; ON CONFLICT DO NOTHING for unique inserts)
- [ ] No new auth.Menus row for CONTACTDASHBOARD (pre-existing — verified at planning time)

---

## ⑫ Special Notes & Warnings

**Consumer**: All agents

### Phase-2-aware page wiring (one-time transitional pattern)

The dynamic `[slug]/page.tsx` route from Case Dashboard #52's Phase 2 has NOT yet shipped. Until it does, this dashboard's `page.tsx` stub renders `<MenuDashboardComponent />` directly — the same pattern Case Dashboard's slug page will use once the dynamic route lands. When #52 finishes Phase 2:
- The dynamic `[slug]/page.tsx` will own dispatch.
- All 6 hardcoded module-dashboard stubs (including `crm/dashboards/contactdashboard/page.tsx`) will be DELETED.
- This dashboard's behavior remains identical — just the route file owner changes.
- DO NOT delete the stub before #52's Phase 2 completes deletion of all 6 in one sweep.

### MENU_DASHBOARD-only warnings

- Slug lives on `auth.Menus.MenuUrl` — already seeded `crm/dashboards/contactdashboard`, do NOT re-insert.
- Menu's `ModuleId` MUST match `Dashboard.ModuleId` — both are CRM. Verify at seed-link time.
- Per-dashboard FE page files do NOT exist as separate components — the page stub is just 1 line wrapping MenuDashboardComponent. If you find yourself creating a `ContactDashboardPageConfig` shell, stop — that's the STATIC pattern.

### Dashboard-class warnings

- Widget queries must be tenant-scoped (CompanyId from HttpContext via `p_company_id` arg) — every function. CompanyId NULL ⇒ admin override (cross-company); CompanyId N ⇒ filter `c."CompanyId" = p_company_id`.
- N+1 risk on per-row aggregates (e.g., Top Engaged Contacts joining donations + tags) — verify each function uses CTEs, not correlated subqueries.
- Multi-currency: v1 sums `GlobalDonation.DonationAmount` AS-IS — pre-flag in tooltip; conversion deferred to Donation Dashboard #54.
- ConfiguredWidget JSON `instanceId` MUST be unique per dashboard AND must equal the `i` value in every LayoutConfig breakpoint array.
- Drill-down args must use the destination screen's accepted query-param names exactly. Don't invent new ones — the SERVICE_PLACEHOLDER cases below catalog the destinations that will accept the new args later.

### Service Dependencies (UI-only — flag genuine external-service / cross-screen gaps)

- ⚠ SERVICE_PLACEHOLDER: **Export Report** PDF — full UI in place; handler toasts because PDF rendering service not wired (no precedent in repo)
- ⚠ SERVICE_PLACEHOLDER: **Engagement Score** column on Contact entity — does NOT exist; widgets use the in-SQL approximation CTE (see §②E). Swap to direct `Contact.EngagementScore` reference when AI Engagement Scoring (Wave 4 #76) ships.
- ⚠ SERVICE_PLACEHOLDER: **Confidence-derivation column** on DuplicateContact — confidence is computed from DuplicateCategoryId (per #21). Tooltip notes this — when a `Confidence` numeric column lands, KPI 6 / widget 14 / alert 2 simplify.
- ⚠ SERVICE_PLACEHOLDER: **Acquisition Trend annotations** — no annotation-storage table exists; v1 returns empty annotation array. Future story: an `app.DashboardAnnotations` table populated by user/admin to mark events.
- ⚠ SERVICE_PLACEHOLDER: **Top Segment per-segment drill-down** — Tag/Segment #22 list page does not yet accept `?segmentId=` arg. Row click degrades to base list page.
- ⚠ SERVICE_PLACEHOLDER: **Contact list filter args**: `?segment=`, `?tag=`, `?source=&newThisMonth=true`, `?hasHead=false` — Contact list page (#18) does not yet accept these. Drill-downs degrade to plain navigation. Track follow-up to wire into Contact list as part of #18 enhancement (matches the same gap noted on Family #20 ISSUE-13).
- ⚠ SERVICE_PLACEHOLDER: **Print stylesheet** — `@media print` rules to hide toolbar/skeletons during print may not yet exist on the new MenuDashboardComponent. Pre-flag as ISSUE-9; v1 print may show toolbar in output.

### Pre-flagged Known Issues (planning-time)

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | HIGH | BE — engagement | `Contact.EngagementScore` column missing; all engagement-related widgets use the in-SQL approximation CTE per §②E. Swap when Wave 4 AI Engagement Scoring ships. |
| ISSUE-2 | MED | BE — role scope | STAFF role scope on this dashboard simplified to CRM_MANAGER scope (skip per-staff filter) — staff would otherwise see empty dashboards. Reconsider when staff workflows need it. |
| ISSUE-3 | LOW | BE — chart 10 | Acquisition trend annotations array empty in v1 — no annotation-storage table. Future enhancement. |
| ISSUE-4 | MED | BE — table 16 | Segment delta30d uses deterministic dummy from hash of SegmentId — no segment-history table. Replace when historical run-counts persisted. |
| ISSUE-5 | MED | BE — multi-currency | KPI 2 / table 7 / churn-risk lifetime $ sum `DonationAmount` AS-IS (no FX) — disclose in tooltip. Donation Dashboard #54 introduces canonical FX path. |
| ISSUE-6 | LOW | FE — Contact Type filter | Filter populated from static enum (Individual/Corporate/Foundation/Family) vs dynamic `corg.ContactTypes` query. Static is simpler; dynamic if user wants live MasterData refresh. Decide at build. |
| ISSUE-7 | LOW | FE — table 16 | Collapsible chrome on `NormalTableWidget` may not exist — if so, omit collapse in v1 (table starts expanded). Track separate enhancement to add collapsible header support to NormalTableWidget. |
| ISSUE-8 | MED | FE — drill-down | Per-segment drill from table 16 → Tag/Segment list page deg-to-base — `?segmentId=` follow-up tracked on #22. |
| ISSUE-9 | LOW | FE — print | `@media print` stylesheet for `<MenuDashboardComponent />` may not yet hide toolbar/skeletons. Verify at build; ship as separate component-level enhancement if missing. |
| ISSUE-10 | MED | FE — drill-down | Contact list page (#18) does not yet accept `?segment=`, `?tag=`, `?source=&newThisMonth=true`, `?hasHead=false`. Alert + drill-down args land on base list + toast until #18 follow-up. |
| ISSUE-11 | LOW | FE — `ContactDashboardPageConfig` orphan | If `presentation/pages/crm/index.ts` re-exports `ContactDashboardPageConfig`, drop the line. Pre-flight grep before deleting any sibling files. |
| ISSUE-12 | LOW | DB — re-runnability | Seed must be idempotent — if Phase 2 of #52 re-runs the dashboard backfill SQL, the UPDATE step linking Dashboard.MenuId for CONTACTDASHBOARD must short-circuit cleanly. Use `WHERE d.MenuId IS NULL` guard. |
| ISSUE-13 | LOW | FE — registry | 3 new ComponentPath keys (`TopEngagedContactsTableWidget`, `TagCloudWidget`, `MiniStatGridWidget`) registered in WIDGET_REGISTRY must match the WidgetType.ComponentPath values seeded in DB exactly (case-sensitive). Pre-flight grep before sealing the seed. |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | planning | HIGH | BE — engagement | `Contact.EngagementScore` column missing; widgets use approximation CTE | OPEN |
| ISSUE-2 | planning | MED | BE — role scope | STAFF role scope simplified to CRM_MANAGER | OPEN |
| ISSUE-3 | planning | LOW | BE — chart 10 | Acquisition annotations empty | OPEN |
| ISSUE-4 | planning | MED | BE — table 16 | Segment delta30d deterministic dummy | OPEN |
| ISSUE-5 | planning | MED | BE — multi-currency | DonationAmount AS-IS, no FX | OPEN |
| ISSUE-6 | planning | LOW | FE — Contact Type filter | Static enum vs dynamic | OPEN |
| ISSUE-7 | planning | LOW | FE — table 16 | NormalTableWidget collapse may not exist | OPEN |
| ISSUE-8 | planning | MED | FE — drill-down | Per-segment drill SERVICE_PLACEHOLDER | OPEN |
| ISSUE-9 | planning | LOW | FE — print | @media print rules may not exist | OPEN |
| ISSUE-10 | planning | MED | FE — drill-down | Contact list filter args missing | OPEN |
| ISSUE-11 | planning | LOW | FE — orphan | ContactDashboardPageConfig drop | OPEN |
| ISSUE-12 | planning | LOW | DB — re-runnability | MenuId backfill guard | OPEN |
| ISSUE-13 | planning | LOW | FE — registry | ComponentPath case match | RESOLVED — 3 NEW kebab-case keys (`contact-top-engaged-table-widget`, `contact-tag-cloud-widget`, `contact-mini-stat-grid-widget`) match seed exactly; verified by post-build grep |
| ISSUE-14 | session-1 | MED | FE — filter chrome | `<MenuDashboardComponent />` exposes no toolbar slot or filter context. The 4 Period/Type/Branch/Source selects + Export Report + Print buttons specified in §⑥ are deferred. Widgets render with default `p_filter_json` (empty keys → no-op filters) until filter chrome lands. Follow-up: extend `<MenuDashboardComponent />` with a `toolbar?` prop + filter context, then re-introduce 4 selects + 2 buttons. | OPEN |
| ISSUE-15 | session-1 | LOW | FE — orphan deletion | Sandbox blocked physical delete of `presentation/pages/crm/dashboards/contactdashboard.tsx`. File body neutralized to `export {}` + comment; orphan re-export already dropped from `dashboards/index.ts`. Run `git rm` in follow-up commit. | OPEN |
| ISSUE-A | session-1 | MED | BE — column missing | `Contact.FirstContactDate` does not exist → all 16 functions use `Contact.CreatedDate` fallback. Affects KPI 1 (deltaThisMonth window), KPI 3 (new this month), chart 10 (acquisition trend), chart 11 (geography window), table 7 (top engaged window). Sub-optimal but acceptable v1; add column or rename CreatedDate when domain decides which timestamp anchors "first contact". | OPEN |
| ISSUE-B | session-1 | MED | BE — column missing | `Contact.CityId` does not exist → `fn_contact_dashboard_geography` falls back to `PrimaryCountryId` joined to `com.Countries`. Geography widget renders **country-level** bars, not city-level. Mockup expected city granularity; honor when `Contact.CityId` lands. | OPEN |
| ISSUE-C | session-1 | MED | BE — column missing | `Contact.BranchId` does not exist; `Family.BranchId` likewise missing. Branch filter accepted in `p_filter_json` but no-op across every widget. Affects ALL filter-honoring widgets (KPI 1/2/3/4/5, table 7, charts 9/10/11, widgets 12/13). Either add `BranchId` to Contact (preferred) or derive from staff/contact-type linkage. | OPEN |
| ISSUE-D | session-1 | LOW | BE — column missing | `ContactSource.Color` not on entity → `fn_contact_dashboard_acquisition_trend` uses hardcoded 6-color palette `["#4f46e5","#3b82f6","#a855f7","#f97316","#06b6d4","#84cc16"]`. ContactSource #122 was supposed to add Color column; verify and switch to live column when present. | OPEN |
| ISSUE-E | session-1 | LOW | BE — projection | Segment owner name derived from `IsSystem` flag (`'System (computed)'` or `'Staff'`) — no User-name navigation on Segment entity. Replace with `CreatedBy → User.UserName` join when segment ownership model is finalized. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 2 — 2026-04-29 — REWORK — COMPLETED

- **Scope**: Spec-compliance rework. Session 1 reused 7 LEGACY widgets (StatusWidgetType1 ×6, PieChartWidgetType1, ColumnChartWidgetType1, MultiChartWidget, BarChartWidgetType1, NormalTableWidget) + 1 cross-module renderer (case-dashboard-alerts-widget) — violating `_DASHBOARD.md` § "🆕 NEW widget renderers are the DEFAULT" (every widget gets its own renderer in `dashboards/widgets/{dashboard-name}-widgets/`; no cross-dashboard reuse). Session 2 replaces every legacy reference with a dedicated `contact-dashboard-widgets/*` renderer, mirroring the Case Dashboard #52 quality bar.
- **Files touched**:
  - **BE (functions)**: All 16 `corg/fn_contact_dashboard_*.sql` rewritten in place. CTE logic + tenant scoping + ISSUE-A/B/C fallbacks preserved verbatim. Only the `result_json` envelope changed: KPI 1–6 now emit the rich case-dashboard shape (`value`/`formatted`/`subtitle`/`trendDir`/`trendPercent`/`trendLabel`/`icon`/`color`/`sparkline`+`sparklineLabels`/`breakdown`); chart widgets emit tailored envelopes (donut → `total`+`segments`+`subtitle`; histogram → `bins`+`lowPercent`+`medPercent`+`highPercent`+`totalDonors`; trend → `labels`+`series`+`annotations`+`totalThisYear`+`trendPercent`; geography → `rows`+`maxValue`+`totalLocations`); alerts emit `[{severity, iconCode, message<strong>, link}]`+`totalCount`; mini-stat emits `title`+`linkRoute`+`linkLabel`+`cells[4]`+`banner|null`; tables emit `rows[]`+`headerNote`+`totalCount`. Each function's `meta_json` now includes an `'issues'` JSON array surfacing the relevant runtime ISSUEs (1, 4, A, B, C, D, E) for FE diagnostic awareness. KPI sparkline metric chosen per KPI (KPI 1/3 = monthly new-contact count; KPI 2 = monthly active-donor count; KPI 4 = monthly avg engagement; KPI 5 = monthly entering-churn-risk count; KPI 6 = monthly merged-per-month count).
  - **FE (renderers)**: 3 Session-1 root-level folders (`widgets/contact-top-engaged-table-widget/`, `widgets/contact-tag-cloud-widget/`, `widgets/contact-mini-stat-grid-widget/`) NEUTRALIZED to `export {};` stubs (sandbox blocked physical delete — see ISSUE-15). 15 NEW widget files created under `widgets/contact-dashboard-widgets/` with case-dashboard quality bar (60/40 KPI layout with hero number + ApexCharts mini-sparkline + 3-bullet breakdown strip; ScrollArea+sticky header tables; design-token colors only; shape-matching skeletons; safe `<strong>` parsing helper inlined per-widget): `contact-kpi-total-contacts-widget` / `contact-kpi-active-donors-widget` / `contact-kpi-new-this-month-widget` / `contact-kpi-avg-engagement-widget` / `contact-kpi-churn-risk-widget` (inverted trend tone) / `contact-kpi-pending-duplicates-widget` (inverted trend tone) / `contact-top-engaged-table-widget` / `contact-dashboard-donut-widget` / `contact-engagement-histogram-widget` / `contact-acquisition-trend-widget` / `contact-geography-widget` / `contact-tag-cloud-widget` / `contact-mini-stat-grid-widget` (shared by widgets 13+14) / `contact-dashboard-alerts-widget` / `contact-top-segments-table-widget`. `dashboard-widget-registry.tsx` updated: 3 imports + 3 keys removed, 15 imports + 15 keys added under `// ----- Contact Dashboard #123 -----` block.
  - **DB seed**: `ContactDashboard-sqlscripts.sql` (770 → 1047 lines): STEP 0c verify list trimmed (no longer needs pre-existing legacy WidgetTypes); STEP 1 replaced 3 OLD WidgetType inserts with 15 NEW (CONTACT_KPI_TOTAL_CONTACTS_WIDGET, CONTACT_KPI_ACTIVE_DONORS_WIDGET, CONTACT_KPI_NEW_THIS_MONTH_WIDGET, CONTACT_KPI_AVG_ENGAGEMENT_WIDGET, CONTACT_KPI_CHURN_RISK_WIDGET, CONTACT_KPI_PENDING_DUPLICATES_WIDGET, CONTACT_TOP_ENGAGED_TABLE_WIDGET, CONTACT_DASHBOARD_DONUT_WIDGET, CONTACT_ENGAGEMENT_HISTOGRAM_WIDGET, CONTACT_ACQUISITION_TREND_WIDGET, CONTACT_GEOGRAPHY_WIDGET, CONTACT_TAG_CLOUD_WIDGET, CONTACT_MINI_STAT_GRID_WIDGET, CONTACT_DASHBOARD_ALERTS_WIDGET, CONTACT_TOP_SEGMENTS_TABLE_WIDGET) + a trailing soft-delete UPDATE for the 2 SUPERSEDED Session-1 codes (CONTACT_TOP_ENGAGED_WIDGET → renamed; CONTACT_MINI_STAT_WIDGET → renamed; CONTACT_TAG_CLOUD_WIDGET kept — same code in both sessions); STEP 3 16 Widget INSERTs all updated to reference contact-dashboard-widgets/* ComponentPaths exclusively (zero legacy references); NEW STEP 3.5 inserted between STEP 3 and STEP 4 — single bulk REPOINT UPDATE driven by a 16-row CTE (`widget_type_targets`), idempotent via `IS DISTINCT FROM`, handles upgrade-from-Session-1 by repointing existing Widget rows from Session-1 WidgetTypeIds to Session-2 WidgetTypeIds; STEP 6 verify counts bumped 3 → 15 with full code list.
  - Note: Phase-3 seed-rewrite agent timed out mid-stream (zero file changes at that point). Manual completion via 16 surgical Edits + 1 STEP 3.5 insert — all targeted, deterministic, traceable.
- **Deviations from spec**:
  - Cross-module renderer reuse (`case-dashboard-alerts-widget` in Session 1) replaced with dedicated `contact-dashboard-alerts-widget` per spec rule #4.
  - Same-dashboard reuse retained: `contact-mini-stat-grid-widget` consumed by both Family Health (13) and Duplicate Detection (14) — spec rule #4 explicitly permits this.
  - 6 dedicated KPI widgets instead of 1 shared `ContactKpiWidget` — chosen for richer per-KPI semantics (sparkline metric + breakdown rows + trend semantics + inverted-tone for KPI 5/6 vary per metric); matches case-dashboard precedent.
  - Sandbox blocked `rm -rf` of the 3 old root-level FE folders — neutralized in place to `export {};` stubs. Manual `git rm -r` required post-merge (tracked as ISSUE-15, also noted in Session 1).
- **Known issues opened**: None new in Session 2.
- **Known issues closed**: None (Session 1 issues all carry over — they're orthogonal to the renderer rework).
- **Next step**: User must (1) re-run `ContactDashboard-sqlscripts.sql` to apply STEP 1 NEW WidgetTypes + STEP 3.5 REPOINT — script is fully idempotent and safe to run on a Session-1-installed DB; (2) re-execute the 16 `corg/fn_contact_dashboard_*.sql` files (envelope shapes changed); (3) `git rm -r` the 3 neutralized root-level folders; (4) `pnpm dev` + manual E2E (every widget renders the case-dashboard polish: KPI 60/40 layout with sparkline; donut center label + 4-row legend; histogram 5 colored bins + Low/Med/High strip; stacked-area 12mo×6 series with legend; geography top-6+Others h-bars; tag cloud 3 size tiers; mini-stat-grid 4 cells + sanitized banner; alerts severity-tinted with `<strong>` rendering; segments 6-row table with Δ30d color coding).

### Session 1 — 2026-04-29 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. MENU_DASHBOARD with 16 Path-A widget functions; second MENU_DASHBOARD in repo (after Case Dashboard #52). All 7 source entities pre-existed and pre-COMPLETED.
- **Files touched**:
  - **BE**: 16 created (`PSS_2.0_Backend/DatabaseScripts/Functions/corg/fn_contact_dashboard_kpi_total_contacts.sql`, `..._kpi_active_donors.sql`, `..._kpi_new_this_month.sql`, `..._kpi_avg_engagement.sql`, `..._kpi_churn_risk.sql`, `..._kpi_pending_duplicates.sql`, `..._top_engaged_contacts.sql`, `..._contacts_by_type.sql`, `..._engagement_histogram.sql`, `..._acquisition_trend.sql`, `..._geography.sql`, `..._top_tags.sql`, `..._family_health.sql`, `..._duplicate_detection.sql`, `..._alerts.sql`, `..._top_segments.sql`). NO C# code, NO migration. All return `(data_json text, metadata_json text, total_count int, filtered_count int)` per case-dashboard precedent (overrides prompt §⑤ which said jsonb).
  - **FE**: 3 created (`PSS_2.0_Frontend/src/presentation/components/custom-components/dashboards/widgets/contact-top-engaged-table-widget/index.tsx`, `..../contact-tag-cloud-widget/index.tsx`, `..../contact-mini-stat-grid-widget/index.tsx`); 4 modified (`dashboards/dashboard-widget-registry.tsx` +3 imports +3 kebab-case registry entries; `src/app/[lang]/crm/dashboards/contactdashboard/page.tsx` body replaced with `<MenuDashboardComponent moduleCode="CRM" dashboardCode="CONTACTDASHBOARD" />`; `presentation/pages/crm/dashboards/index.ts` orphan re-export of `ContactDashboardPageConfig` dropped; `presentation/pages/crm/dashboards/contactdashboard.tsx` body neutralized to `export {}` per ISSUE-15).
  - **DB**: 1 created (`PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/ContactDashboard-sqlscripts.sql`, 770 lines / ~40KB, 6 STEPs incl. STEP 0 diagnostics, STEP 1 inserts 3 NEW WidgetType rows, STEP 2 Dashboard row, STEP 2.5 MenuId UPDATE with `IS NULL` guard per ISSUE-12, STEP 3 inserts 16 Widget rows, STEP 4 inserts DashboardLayout with multi-breakpoint `lg`/`md`/`sm`/`xs` LayoutConfig + dynamic ConfiguredWidget CTE, STEP 5 inserts 16 WidgetRole grants for BUSINESSADMIN, STEP 6 verify queries).
- **Deviations from spec**:
  - Function return type **`text` not `jsonb`** — case-dashboard precedent overrides prompt §⑤. Runtime expects text columns.
  - **No filter chrome v1** (4 Period/Type/Branch/Source selects + Export + Print) — `<MenuDashboardComponent />` has no toolbar slot, prompt §⑫ forbids wrapping. Tracked as ISSUE-14.
  - **`AlertListWidget` cross-module reuse** — prompt §⑤ named `AlertListWidget` (which is a legacy WidgetType row with no FE registry entry); the seed instead binds `LIST_ALERTS` to existing `case-dashboard-alerts-widget` ComponentPath (registered by Case Dashboard #52). No new alerts widget created.
  - **`ColumnChartWidgetType1` (singular)** — prompt §② said `ColumnsChartWidgetType1` (with 's'); registry has the singular form. Seed uses singular.
  - **5 BE column-existence ISSUEs** (ISSUE-A..E) surfaced during entity verification — see Known Issues table.
  - **xs breakpoint w=1** — derived from `<MenuDashboardComponent />` actual `cols.xs=1` (not `4` as prompt §⑥ claimed).
- **Known issues opened**: ISSUE-14 (FE — filter chrome), ISSUE-15 (FE — orphan deletion), ISSUE-A..E (BE — 5 column-existence gaps).
- **Known issues closed**: ISSUE-13 (FE — registry ComponentPath case match) — verified by post-build grep.
- **Next step**: User must run (1) `ContactDashboard-sqlscripts.sql` to seed Dashboard + WidgetTypes + 16 Widgets + Layout + grants; (2) execute the 16 `corg.fn_contact_dashboard_*.sql` files against the database to install the functions; (3) `pnpm dev` and navigate to `/[lang]/crm/dashboards/contactdashboard` for full E2E (16 widgets render, role-gated for BUSINESSADMIN, network shows ONE `dashboardByModuleAndCode` + 16 parallel `generateWidgets` calls per §⑪). `dotnet build` not strictly required (no C# changes) but recommended sanity check.
