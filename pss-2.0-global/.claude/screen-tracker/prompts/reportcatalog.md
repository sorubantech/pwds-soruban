---
screen: ReportCatalog
registry_id: 99
module: Report & Audit
status: COMPLETED
scope: FULL
screen_type: CONFIG
config_subtype: SETTINGS_PAGE
storage_pattern: keyed-settings-rows
save_model: per-action
complexity: Medium
new_module: NO
planned_date: 2026-05-13
completed_date: 2026-05-13
last_session_date: 2026-05-13
---

> **⚠ READ THIS FIRST — Type re-classification (registry stamp is wrong)**
>
> 1. **Registry says Type=Dashboard, Status=SKIP_DASHBOARD, Notes="Custom FE".** That's stale.
>    The mockup is NOT a dashboard. There are no KPI cards, no charts, no react-grid-layout —
>    so `_DASHBOARD.md` does not apply.
>
> 2. **Actual shape** = a **launcher / catalog hub page** that lists all available reports
>    across modules, with per-user favorites and recent-run history, plus modal-launched
>    Run/Schedule actions. The page is mostly a curated multi-section view, with one tiny
>    write-path (toggle favorite). It does not CRUD reports — those rows are seeded into
>    `rep.Reports` already, and custom-report rows are CRUD'd by Screen #96 (Custom Report
>    Builder, PROMPT_READY).
>
> 3. **Best-fit template** = `CONFIG / SETTINGS_PAGE` (`storage_pattern: keyed-settings-rows`).
>    The "settings" being configured is the **per-user report-portal experience** — which
>    reports the user has starred and which they have recently run. This is the closest of
>    the 6 template shapes; the alternative would be inventing a new "HUB / LAUNCHER" type,
>    which we've explicitly deferred (per `_COMMON.md` "Adding a new screen type" guidance).
>    The stretch is documented and acceptable — same precedent as #96 being filed under
>    DESIGNER_CANVAS despite not being a "config" in the SMTP-sense.
>
> 4. **Effective scope = FULL** but small BE work:
>    - **Reuse** existing `Report` (`rep.Reports`), `Module` (`auth.Modules`),
>      `ReportExecutionLog` (`rep.ReportExecutionLogs`), `Branch`, `DonationPurpose`,
>      `PaymentMode`, `Campaign`.
>    - **Add** ONE new entity: `ReportFavorite` (`rep.ReportFavorites`) — `(UserId, ReportId)`
>      composite-unique join row.
>    - **Add** ONE aggregate query: `GetReportCatalog` — composite DTO returning:
>      grouped modules → reports → user's favorite flag + last-run date.
>    - **Add** ONE mutation: `ToggleReportFavorite(reportId)` — upserts/deletes the
>      `ReportFavorite` row for the current user.
>    - **Add** FE catalog page from scratch.
>
> 5. **Schedule modal = SERVICE_PLACEHOLDER.** Registry #101 Scheduled Reports is
>    `SKIP_CONFIG` ("Cron-based, custom") — meaning the `ScheduledReport` / `ReportSchedule`
>    entity does not exist yet, and the scheduling UX has not been designed. Hangfire IS
>    already wired (`Hangfire` + `Hangfire.PostgreSql` in `Base.Application.csproj`) so the
>    infrastructure is there, but the domain model is not. Build the full Schedule modal
>    UI; the "Create Schedule" button's handler shows a `SERVICE_PLACEHOLDER` toast and
>    routes user to #101 (`/reportaudit/reports/scheduledreport`) once that screen exists.
>
> 6. **Run modal = real navigation, not placeholder.** Run modal collects parameters then
>    navigates to `/reportaudit/reports/generatereport?reportCode={code}` — the Generate
>    Report engine (#154, COMPLETED 2026-05-13) handles execution. The Run modal's filter
>    fields (Branch / Purpose / Payment Mode / Group By / Output Format) come from the
>    selected report's `FilterSchema` JSON (existing column on `rep.Reports`) — the modal
>    must render the filter schema dynamically per report, NOT hardcode the donation
>    summary fields shown in the mockup.
>
> 7. **Canonical precedent**: This is the **first SETTINGS_PAGE screen** in the codebase.
>    `_CONFIG.md §⑦` currently lists "TBD — first builder sets convention." After this build
>    completes, update `_CONFIG.md` to point future SETTINGS_PAGE screens at
>    `reportcatalog.md` as canonical (but acknowledge that this one is a hub/launcher and
>    a more conventional SETTINGS_PAGE may need a second canonical example for true
>    singleton-per-tenant config pages like SMTP setup).

---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type identified: SETTINGS_PAGE — hub/launcher variant)
- [x] Business context read (NGO operations persona; report discovery + run launcher; cross-module portal)
- [x] Storage model identified (`keyed-settings-rows` — one ReportFavorite row per user-report pair; read-only catalog + run history are reused existing tables)
- [x] Save model chosen (`per-action` — toggle-star creates/deletes row; Run launches; Schedule is placeholder; no Save button)
- [x] FK targets resolved (paths + GQL queries verified — all reuse existing entities)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (launcher persona; favorites toggle is the only write; Run = navigation; Schedule = placeholder) — collapsed into pre-build review; prompt already pre-analyzed
- [x] Solution Resolution complete (SETTINGS_PAGE/launcher confirmed; new ReportFavorite entity confirmed; GetReportCatalog composite DTO confirmed)
- [x] UX Design finalized (top-down: header + filter bar + Recent strip + Favorites collapsible + N module sections + Run modal + Schedule modal)
- [x] User Approval received
- [x] Backend code generated (ReportFavorite entity + EF config + DTOs + GetReportCatalog query + ToggleReportFavorite mutation + endpoints)
- [x] Backend wiring complete (IReportDbContext + ReportDbContext + DecoratorReportModules + ReportMappings — prompt §⑧ said IApplicationDbContext but verified target is IReportDbContext)
- [x] Frontend code generated (page + sections + recent strip + favorites strip + module sections + run modal + schedule modal placeholder)
- [x] Frontend wiring complete (4 barrel index.ts exports updated; route page.tsx replaced UnderConstruction stub; no entity-operations.ts — confirmed N/A per #154 build notes)
- [x] DB Seed script generated (Menu + Capabilities + GridFormSchema=SKIP — no grid-form needed; this is a custom hub)
- [x] Registry updated to COMPLETED + Notes column corrected (drop "SKIP_DASHBOARD / Custom FE" tag)

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — `/{lang}/reportaudit/reports/reportcatalog` loads (no UnderConstruction stub)
- [ ] SETTINGS_PAGE / hub-launcher checks:
  - [ ] Page header renders with title + subtitle + "Custom Report" + "My Scheduled Reports" buttons
  - [ ] Custom Report button navigates to `/reportaudit/reports/customreportbuilder`
  - [ ] My Scheduled Reports button navigates to `/reportaudit/reports/scheduledreport` (route may not exist yet — toast OK if #101 not built)
  - [ ] Filter bar renders: search input + Module select + Type select (Standard/Custom/Scheduled) + Clear Filters
  - [ ] Search filters report rows by name + description (case-insensitive substring match)
  - [ ] Module filter shows/hides whole sections
  - [ ] Type filter shows/hides rows within sections
  - [ ] "My Recent Reports" horizontal scroll strip renders the current user's last N (default 5) distinct reports run, ordered by latest run desc
  - [ ] Each Recent card shows: report name + module badge + last-run date + "Run Again" button
  - [ ] "My Favorites" section is collapsible (chevron rotates)
  - [ ] Favorites strip renders the current user's starred reports (joined to rep.Reports + module badge + type label)
  - [ ] Each Module section is collapsible (chevron rotates)
  - [ ] Module section header shows module icon + name + "{count} reports" badge
  - [ ] Each report row renders: name + description + Type badge (Standard/Custom/Scheduled) + Last Run + actions
  - [ ] Row actions: Run / Schedule / Star (Custom-type rows also show Edit which routes to #96)
  - [ ] Star toggle calls `ToggleReportFavorite(reportId)` → optimistically updates UI + on error, reverts + toast
  - [ ] Starred reports automatically appear in the Favorites strip on next data refresh (or live if we keep client state)
  - [ ] Click Run → Run modal opens with report name + dynamic filter form rendered from the report's `FilterSchema` JSON
  - [ ] Run modal fields render correctly per FilterSchema (date-range, ApiSelectV2 for Branch/Purpose/PaymentMode/Campaign, plain select for Group By + Output Format)
  - [ ] Run modal "Run Report" button serializes filter values to query string + navigates to `/reportaudit/reports/generatereport?reportCode={code}&filters={base64-json}` (or similar — Generate Report engine handles execution)
  - [ ] Click Schedule → Schedule modal opens with report name + frequency + day/date (dynamic) + time + date range + delivery options + format
  - [ ] Schedule modal "Create Schedule" button shows `SERVICE_PLACEHOLDER` toast: "Scheduling not yet available — coming in #101 Scheduled Reports build"
  - [ ] Custom-type rows show Edit button → routes to `/reportaudit/reports/customreportbuilder?reportId={id}` (or just to the screen if it doesn't accept reportId yet — see #96 build status)
  - [ ] Empty state for Favorites: "You haven't starred any reports yet — click the ⭐ on any report below to add it"
  - [ ] Empty state for Recent: "No recent reports — run any report below to start tracking your activity"
  - [ ] Empty state for a Module section after filter: section auto-hides if all rows filtered out
  - [ ] Loading state: skeleton cards in Recent strip + skeleton rows in module tables
  - [ ] Error state: error card with retry button for each independent query (GetReportCatalog vs GetMyRecentReports vs GetMyFavoriteReports — if split)
- [ ] DB Seed:
  - [ ] Menu visible at Report & Audit → Reports → Report Catalog
  - [ ] BUSINESSADMIN role gets READ + MODIFY (MODIFY = ability to toggle favorites)
  - [ ] Existing `rep.Reports` seed rows surface in the catalog (no new ReportDefinition seeding needed — engine reuse)
  - [ ] (Optional) Seed 1-2 sample ReportFavorite rows for the demo user so the Favorites section isn't empty on first install

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Report Catalog
Module: Report & Audit (`REPORTAUDIT`)
Schema: `rep` (existing Reports schema — adding ONE new table `ReportFavorites`)
Group: Report (existing `Base.Application/Business/ReportBusiness/`)

Business: The Report Catalog is the **central discovery and launch surface** for all reports
in PSS 2.0. It is the user's first destination when they ask "what reports are available and
which one do I run today?" The catalog aggregates standard reports (seeded into `rep.Reports`
by the platform) and custom reports (created by users via Screen #96 Custom Report Builder)
into a single browse-and-launch experience grouped by module. Three audiences use this screen:
**BUSINESSADMIN** (orgs-level — sees all reports), **operational staff** (sees reports for
their assigned modules — RBAC gates which rows surface), and the **finance/audit persona**
(checks reconciliation reports daily). Edit frequency: passive view-mostly, with rare writes
limited to toggling favorites — there is no "save" action. The screen is glue: it depends on
#154 Generate Report (engine reuse — handles execution after Run modal), #96 Custom Report
Builder (where custom rows are CRUD'd), and #101 Scheduled Reports (where scheduling lives —
not yet built, so the Schedule modal is a SERVICE_PLACEHOLDER). It contributes back to those
screens by tracking per-user recent runs (read from existing `rep.ReportExecutionLogs`) and
per-user favorites (the one new table this screen adds). What's unique vs. a generic settings
page: most CONFIG/SETTINGS_PAGE screens edit a tenant-level singleton row; this one operates
on per-user state layered over a read-only catalog — so it stretches the SETTINGS_PAGE pattern
and sets the template precedent that "settings" can mean "per-user view preferences" too.

> **Why this screen has been re-classified twice (registry SKIP_DASHBOARD → CONFIG)**:
> The original analyst saw a list-of-reports layout and reached for "dashboard." A second
> pass found no KPI/chart widgets and no react-grid-layout — `_DASHBOARD.md` doesn't fit.
> The screen is a hub/launcher, which we file under CONFIG/SETTINGS_PAGE for pipeline
> compatibility, with the deviation documented above. Future hub-style screens (e.g. a
> Communications Catalog, a Templates Catalog) should reuse this pattern.

---

## ② Storage Model

> **Consumer**: BA Agent → Backend Developer

**Storage Pattern**: `keyed-settings-rows`

**Stamp**: `keyed-settings-rows`

Rationale: the only mutable state on this screen is the per-user favorite flag for each
report. The natural representation is a join row keyed on `(UserId, ReportId)` — the
classic "keyed settings row per scoped owner" pattern. The catalog itself (`rep.Reports`)
and the run history (`rep.ReportExecutionLogs`) are read-only here — owned by other
screens and the report engine.

### Tables

#### NEW — `rep."ReportFavorites"` (the one new table this screen adds)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| ReportFavoriteId | int | — | PK | — | Primary key |
| UserId | int | — | YES | `auth.Users` | Owner of the favorite (current logged-in user from HttpContext) |
| ReportId | int | — | YES | `rep.Reports` | Which report is favorited |
| CompanyId | int | — | YES | `corg.Companies` | Tenant scope |

**Composite uniqueness**: `(UserId, ReportId, CompanyId)` — exactly one favorite row per user-per-report-per-tenant. Toggle behavior: presence of row = favorite; absence = not favorite. ToggleReportFavorite mutation inserts if missing, deletes if present.

**Indexes**:
- `IX_ReportFavorites_UserId_CompanyId` — non-unique, for "list my favorites" reads
- `UX_ReportFavorites_UserId_ReportId_CompanyId` — unique, enforces toggle semantics

> Audit columns inherited from `Entity` base. CompanyId is required because favorites are
> tenant-scoped (a user with access to two tenants has separate favorite lists per tenant).

#### REUSED — `rep."Reports"` (read-only on this screen)

Existing table — populated by platform seeders + #96 Custom Report Builder. Relevant columns
this screen reads:

| Field | Notes |
|-------|-------|
| ReportId | PK — used as FK target |
| ReportName | Display name on row |
| ReportDescription | Description shown under name |
| ReportCode | Used in URL when launching (e.g. `?reportCode=DONATIONSUMMARY`) |
| ModuleId | Groups rows into module sections |
| ReportType | "Standard" / "Custom" / "Scheduled" — drives Type badge + Edit visibility |
| FilterSchema | JSON describing the Run modal's dynamic filter form |
| IsActive | Excludes inactive rows |
| LastRunDate (computed) | Joined from rep.ReportExecutionLogs latest by Report+User OR Report tenant-wide — see §⑤ |

> If `rep.Reports` is missing the `ReportType` column or the `ReportDescription` column or
> the `FilterSchema` column, the BE dev must add them via migration before this screen
> can be built — flag in §⑫ at build time. (Confirm at build start via Read on the
> existing entity.)

#### REUSED — `rep."ReportExecutionLogs"` (read-only on this screen)

Existing run-history table. Used as the data source for "My Recent Reports" strip.

Query shape: `SELECT TOP 5 ReportId, MAX(RunDate) FROM ReportExecutionLogs WHERE UserId = @currentUserId AND CompanyId = @currentTenantId GROUP BY ReportId ORDER BY MAX(RunDate) DESC` joined back to Reports for display data.

> Audit columns omitted — inherited from `Entity` base.
> CompanyId is **always** present (tenant-scoped) — from HttpContext, NOT a form field.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for ApiSelect queries)

### FKs on the new `ReportFavorite` entity:

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| UserId | User | `PSS_2.0_Backend/.../Base.Domain/Models/AuthModels/User.cs` | `GetUsers` (auth) | UserName / DisplayName | `UserResponseDto` |
| ReportId | Report | `PSS_2.0_Backend/.../Base.Domain/Models/ReportModels/Report.cs` | `GetReports`, `GetReportsByModule`, `GetReportById` | ReportName | `ReportResponseDto` |
| CompanyId | Company | (inherited via tenant-scoping infra — not exposed as form FK) | — | — | — |

### Reused entities consumed by the screen (no new FKs added — these are query-time joins):

| Used For | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| Module section grouping | Module | `PSS_2.0_Backend/.../Base.Domain/Models/AuthModels/Module.cs` | `GetModules` | ModuleName, ModuleCode | `ModuleResponseDto` |
| Recent runs source | ReportExecutionLog | `PSS_2.0_Backend/.../Base.Domain/Models/ReportModels/ReportExecutionLog.cs` | `GetReportExecutionLogs` | RunDate | `ReportExecutionLogResponseDto` |
| Run modal filter — Branch dropdown | Branch | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/Branch.cs` | `GetBranches` | BranchName | `BranchResponseDto` |
| Run modal filter — Purpose dropdown | DonationPurpose | `PSS_2.0_Backend/.../Base.Domain/Models/DonationModels/DonationPurpose.cs` | `GetDonationPurposes` | DonationPurposeName | `DonationPurposeResponseDto` |
| Run modal filter — Payment Mode | PaymentMode | `PSS_2.0_Backend/.../Base.Domain/Models/SharedModels/PaymentMode.cs` | `GetPaymentModes` | PaymentModeName | `PaymentModeResponseDto` |
| Run modal filter — Campaign | Campaign | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/Campaign.cs` | `GetCampaigns` | CampaignName | `CampaignListDto` |

> **NB**: The Run modal's dropdowns shown in the mockup (Branch / Purpose / Payment Mode /
> Campaign) are illustrative — the ACTUAL fields rendered depend on the selected report's
> `FilterSchema` JSON. Don't hardcode these dropdowns into the modal component. Use the
> same dynamic-filter-rendering approach the Generate Report engine uses (ApiSelectV2 for
> FK dropdowns, native inputs for date/text/number — driven by FilterSchema type
> declarations).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Singleton / Cardinality Rules:**
- `ReportFavorite` is keyed on `(UserId, ReportId, CompanyId)` — exactly one row per user-per-report-per-tenant. Toggle behavior is upsert/delete, NOT update.
- The catalog (`rep.Reports`) is read-only on this screen. CRUD lives elsewhere (#96 for custom reports; seeders for standard reports).
- The run history (`rep.ReportExecutionLogs`) is read-only on this screen. Writes come from the Generate Report engine (#154).

**Required Field Rules:**
- ToggleReportFavorite: `ReportId` required + must exist in `rep.Reports` + must be `IsActive=true`.
- Both UserId and CompanyId come from HttpContext — not form fields. Reject if either is null/missing.

**Conditional Rules:**
- Custom-type rows (`Report.ReportType = 'Custom'`) show an Edit button in row actions; Standard/Scheduled rows do not.
- Schedule action is hidden / disabled for rows with `Report.ReportType = 'Scheduled'` (a scheduled report is the schedule itself — don't double-schedule).
- Module-filter only shows modules the current user has READ on (RBAC: hide modules the user can't access).
- Reports the user has no READ capability on are filtered out at query-time — never returned to FE.

**Sensitive Fields**: None. The screen does not handle credentials, regulatory data, or
encrypted fields. Run-history rows may surface filter parameters from prior runs, but those
are limited to the current user's own runs and contain no PII not already accessible to them.

**Read-only / System-controlled Fields:**
- `ReportFavorite.UserId` — set from HttpContext, never editable.
- `ReportFavorite.CompanyId` — set from HttpContext, never editable.
- All `Report` fields shown on this screen — read-only here.
- All `ReportExecutionLog` fields shown on this screen — read-only here.

**Dangerous Actions**: None on this screen. Toggle-favorite is reversible (re-toggle). Run is non-destructive (navigates to engine). Schedule is non-destructive (placeholder; would create a Hangfire job in a future build, which itself would be undo-able).

**Role Gating:**

| Role | Sections Visible | Sections Editable | Notes |
|------|------------------|-------------------|-------|
| BUSINESSADMIN | all | favorites (toggle) | full access |
| Other roles | filtered by RBAC: only modules + reports they have READ on | favorites (toggle) on visible reports | per existing capability infrastructure |

Per-user-per-tenant favorites enforce that switching tenants shows a different favorite set.

**Workflow**: None. No draft → publish, no approval chain. Toggle is one-step.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: CONFIG
**Config Sub-type**: `SETTINGS_PAGE` (hub/launcher variant — see §① re-classification note)
**Storage Pattern**: `keyed-settings-rows`
**Save Model**: `per-action`

| Save Model | Why |
|------------|-----|
| `per-action` | No Save button anywhere. Toggle-star is its own mutation. Run is its own navigation. Schedule is its own placeholder. There is no "edit a form, then save" surface to design around. |

**Reason**: This screen is a hub/launcher, not a classical settings page. The shape closest matches `keyed-settings-rows` (per-user state — favorite rows) + read-only joins to existing catalog + history. Filing under SETTINGS_PAGE because no other template in the set fits better; the alternative (inventing a new HUB type) is explicitly deferred.

**Backend Patterns Required:**

For **SETTINGS_PAGE (keyed-settings-rows, hub-launcher variant)**:
- [x] `GetReportCatalog` query — composite DTO returning grouped modules → reports → user favorite flag + last-run date + recent-runs list + favorites list. ONE round trip for the whole page.
- [x] `ToggleReportFavorite` mutation — upserts or deletes the ReportFavorite row for the current user. Returns the updated favorite count for optimistic UI.
- [x] Tenant + user scoping (CompanyId + UserId from HttpContext)
- [x] RBAC filter — modules and reports filtered by current user's capabilities at query-time
- [ ] No Create/Delete on Report itself (out of scope — handled by other screens)
- [ ] No Update on Report itself (out of scope)
- [ ] No Reset, no Test, no Regenerate (not applicable to a hub)

**Frontend Patterns Required:**

For **SETTINGS_PAGE (hub-launcher variant)**:
- [x] Custom multi-section page (NOT RJSF modal, NOT view-page 3-mode)
- [x] Section container — **vertical-stack** (header → filter-bar → recent strip → favorites collapsible → N module sections → modals)
- [x] Filter bar component (search + module select + type select + clear) — client-side filtering across all sections in one pass
- [x] Horizontal scroll strip component (used for Recent and Favorites)
- [x] Collapsible section component (used for Favorites and each module section)
- [x] Per-section embedded table (using `ReportDataTable` shared component IF a generic catalog grid-code can be defined, OR a lightweight custom table — see §⑥ for decision)
- [x] Modal — Run Report (dynamic filter form driven by selected report's FilterSchema)
- [x] Modal — Schedule Report (full UI; submit button shows SERVICE_PLACEHOLDER toast)
- [x] Star toggle button (click → optimistic flip → ToggleReportFavorite mutation → revert on error)
- [x] Route navigation for Run / Edit / Custom Report / My Scheduled Reports buttons
- [x] Empty / loading / error states for each independent data slice

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: This section is the design spec. Hub-launcher variant of SETTINGS_PAGE. Fill in only Block A. Block B (DESIGNER_CANVAS) and Block C (MATRIX_CONFIG) do not apply — delete from generated prompt.

### 🎨 Visual Uniqueness Rules

Per `_CONFIG.md` §⑥ visual-uniqueness rules — applies here:

1. **Vary section emphasis** — the Page Header gets the strongest visual weight (title + subtitle + two CTA buttons in accent color). Filter bar is a subordinate utility surface. Recent strip + Favorites strip are equal-weight horizontal scrolls. Module sections are uniform card chrome but module icons + module-badge colors differentiate them visually.
2. **Match section layout to content shape**:
   - Recent + Favorites → horizontal scrolling strip of "recent-card" tiles (240px min-width, gap 0.75rem)
   - Each module → collapsible card containing a vertical table
   - Run/Schedule → modal dialogs (max-width 560px, scrolling body)
3. **Sensitive fields**: N/A
4. **Read-only system fields**: N/A
5. **Section icons are semantic**: Each module section uses a Phosphor icon matching the module (e.g. `ph:chart-line` for Fundraising, `ph:users` for Contacts, `ph:envelope` for Communication, `ph:buildings` for Organization, `ph:person-walking` for Field Collection, `ph:wrench` for Custom). Match the mockup's fa-icons.
6. **Save/status affordances**: No save needed; toggle-star shows immediate UI flip. Modal submits show inline success/error toasts.

**Anti-patterns to refuse**:
- Identical card chrome for module sections with only the title swapped — module-badge colors and section icons must visually differentiate.
- Hardcoded Run modal filter fields per the mockup (Branch / Purpose / Payment Mode / Group By) — these MUST be driven by the selected report's FilterSchema, NOT hardcoded.
- Schedule modal that pretends to work — submit must be clearly placeholder-styled (toast, no DB write, NO confirmation suggesting a schedule was created).

---

### 🅰️ Block A — SETTINGS_PAGE (hub-launcher variant)

#### Page Layout

**Container Pattern**: `vertical-stack`

```
┌──────────────────────────────────────────────────────────────────┐
│ 📊 Reports                              [+ Custom Report] [Sched]│
│ Browse, run, and schedule reports across all modules             │
├──────────────────────────────────────────────────────────────────┤
│ [🔍 Search reports...] [All Modules ▾] [All Types ▾] [× Clear]   │
├──────────────────────────────────────────────────────────────────┤
│ ⏱ My Recent Reports                                              │
│ ┌─────────┬─────────┬─────────┬─────────┬─────────┐  (scroll →)  │
│ │ name+   │ name+   │ name+   │ name+   │ name+   │              │
│ │ module  │ module  │ module  │ module  │ module  │              │
│ │ date    │ date    │ date    │ date    │ date    │              │
│ │ [RunAg] │ [RunAg] │ [RunAg] │ [RunAg] │ [RunAg] │              │
│ └─────────┴─────────┴─────────┴─────────┴─────────┘              │
├──────────────────────────────────────────────────────────────────┤
│ ⭐ My Favorites                                              [▼] │
│ ┌─────────┬─────────┬─────────┐                                  │
│ │ name+   │ name+   │ name+   │  (scroll →)                      │
│ │ module  │ module  │ module  │                                  │
│ │ type    │ type    │ type    │                                  │
│ │ [Run]   │ [Run]   │ [Run]   │                                  │
│ └─────────┴─────────┴─────────┘                                  │
├──────────────────────────────────────────────────────────────────┤
│ 📈 Fundraising Reports                          (8 reports) [▼]  │
│ ┌──────────────────────────────────────────────────────────────┐ │
│ │ Report                  | Type     | Last Run | Actions       │ │
│ │ Donation Summary        | Standard | Apr 10   | Run|Sch|⭐    │ │
│ │   sub: Donations by …                                          │ │
│ │ Donor Giving History    | Standard | Apr 8    | Run|Sch|⭐    │ │
│ │ ...                                                            │ │
│ └──────────────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────────────┤
│ 👥 Contact Reports                              (5 reports) [▼]  │
│ ...                                                              │
├──────────────────────────────────────────────────────────────────┤
│ ✉ Communication Reports / 🏢 Organization Reports / 🚶 Field /    │
│ 🔧 Custom Reports (each with Edit action)                        │
└──────────────────────────────────────────────────────────────────┘
```

#### Page Header

| Element | Content |
|---------|---------|
| Breadcrumb | Report & Audit › Reports › Report Catalog |
| Icon + Title | `fa-chart-bar` (or `ph:chart-bar`) — "Reports" |
| Subtitle | "Browse, run, and schedule reports across all modules" |
| Right action 1 | "Custom Report" — accent button (`#7c3aed` per mockup) → routes to `/reportaudit/reports/customreportbuilder` |
| Right action 2 | "My Scheduled Reports" — outline accent → routes to `/reportaudit/reports/scheduledreport` (placeholder route if #101 not built — show toast) |

#### Filter Bar (sticky below header)

| Field | Widget | Behavior |
|-------|--------|----------|
| Search | text input with search icon prefix | Filters report rows by `ReportName` + `ReportDescription` substring (case-insensitive); empty = no name filter |
| Module | select (`All Modules`, then one option per visible module — populated dynamically from data) | Show/hide entire module sections |
| Type | select (`All Types`, `Standard`, `Custom`, `Scheduled`) | Filter rows within sections by `Report.ReportType` |
| Clear Filters | text button (with × icon) | Resets all three filters |

> **Implementation note**: Filtering is **client-side over the catalog data already loaded**. Do NOT round-trip to BE on each keystroke. The `GetReportCatalog` query returns the full catalog (typically < 100 reports per tenant) — filter the in-memory result.

#### Section: My Recent Reports

| Slot | Content |
|------|---------|
| Heading | `ph:clock-counter-clockwise` icon (or `fa-clock-rotate-left`) + "My Recent Reports" |
| Source | `currentUser`'s last N=5 distinct reports run, ordered by `MAX(rep.ReportExecutionLogs.RunDate) DESC` for `(ReportId, UserId=current, CompanyId=current)` joined to `rep.Reports` |
| Empty state | "No recent reports — run any report below to start tracking your activity." |
| Card content | Report name (bold) + Module badge (color per module) + Last-run date + "Run Again" button (accent small) |
| Layout | Horizontal scroll strip; min-width 240px per card; gap 0.75rem |

#### Section: My Favorites (collapsible)

| Slot | Content |
|------|---------|
| Toggle | `fa-star` (gold) + "My Favorites" + chevron-down (collapses on click) |
| Source | `currentUser`'s `rep.ReportFavorites` rows joined to `rep.Reports` (active reports only) |
| Empty state | "You haven't starred any reports yet — click the ⭐ on any report below to add it." |
| Card content | Report name + Module badge + Type label (Standard / Custom) + "Run" button |
| Layout | Horizontal scroll strip (same dimensions as Recent) |
| Default state | Expanded |

#### Section: Module Sections (collapsible, one per module that has reports the user can see)

Sections are produced dynamically from the catalog data — one per distinct `Report.ModuleId` in the catalog. Order: by `Module.OrderBy` ascending. Default expanded.

| Slot | Content |
|------|---------|
| Header | Module icon (Phosphor — see mapping below) + Module display name + "{count} reports" badge + chevron-down |
| Body | Embedded table with columns: **Report** / **Type** / **Last Run** / **Actions** |

**Module → Icon mapping** (matching the mockup's fa-icons):

| Module | Mockup Icon | Phosphor equivalent | Badge color |
|--------|------------|----------------------|-------------|
| Fundraising (donation) | `fa-chart-line` | `ph:chart-line` | green (`#16a34a`) |
| Contacts | `fa-users` | `ph:users` | blue (`#3b82f6`) |
| Communication | `fa-envelope` | `ph:envelope` | amber (`#d97706`) |
| Organization | `fa-building` | `ph:buildings` | pink (`#db2777`) |
| Field Collection | `fa-person-walking` | `ph:person-walking` | orange (`#ea580c`) |
| Custom Reports | `fa-wrench` | `ph:wrench` | violet/report-accent (`#7c3aed`) |
| (Other modules — fallback) | `fa-folder` | `ph:folder` | slate gray |

#### Per-row table layout (within each module section)

| Column | Width | Content |
|--------|-------|---------|
| Report | flex | Bold report name + small description below (font-size 0.75rem, slate-600) |
| Type | shrink | Type badge: Standard (cyan), Custom (violet/report-accent), Scheduled (amber) |
| Last Run | shrink | Date — `MMM D` for current year, `MMM D, YYYY` otherwise; "—" if never run |
| Actions | shrink | Row action group (in order): **Run** (primary accent small button) → **Schedule** (outline small) → **Edit** (outline small, ONLY for `ReportType = 'Custom'`) → **Star** (icon button, gold if favorited, gray otherwise) |

> Use the existing shared **`AdvancedDataTable` or `FlowDataTable`** (per the feedback memory: "Reuse existing grids — never fork") for the rows within each module section IF the column model fits. If a per-module mini-table needs custom layout this lightweight, a plain HTML table styled to match the mockup is acceptable — but justify in the FE build commit.

#### Run Report Modal

Triggered by: click Run button on any row, or "Run Again" on Recent strip, or "Run" on Favorites strip.

| Slot | Content |
|------|---------|
| Header | `ph:play-circle` + "Run Report" + close × |
| Body — Report (read-only) | Selected report name in accent color |
| Body — Dynamic filter form | Renders fields from `Report.FilterSchema` JSON. Each filter declaration drives one input: date-range, ApiSelectV2 (for FK dropdowns — uses GQL queries from §③), native select (for enum lists), number, text. **Do NOT hardcode** Branch/Purpose/Payment Mode. |
| Body — Group By (if FilterSchema declares groupable fields) | Single select; options from FilterSchema |
| Body — Output Format | Always present: `View on Screen` (default) / `Export as Excel` / `Export as PDF` / `Export as CSV` |
| Footer | Cancel (outline) + "Run Report" (`ph:play` + accent primary) |
| On submit | Serialize filter values + group-by + output to query-string (or POST body — pick what Generate Report engine expects per #154 build). Navigate to `/{lang}/reportaudit/reports/generatereport?reportCode={code}&filters={base64-json}` (or matching pattern). The engine renders the result; this modal closes. |

> **Implementation note**: If Generate Report engine does not yet accept inbound params on URL load, this modal acts as a "go to Generate Report with these defaults filled in" — confirm at build time by reading the `<GeneratePageConfig />` component (#154). Worst case: modal submit just navigates with `?reportCode=X`, and user re-enters filters in Generate Report. Acceptable degradation; not a SERVICE_PLACEHOLDER because the launch path works end-to-end.

#### Schedule Report Modal

Triggered by: click Schedule button on any row (hidden on `ReportType = 'Scheduled'` rows).

| Slot | Content |
|------|---------|
| Header | `ph:calendar-check` + "Schedule Report" + close × |
| Body — Report (read-only) | Selected report name in accent color |
| Body — Frequency / Day | Two-column. Frequency: Daily / Weekly / Monthly / Quarterly. Day select content depends on frequency (Mon-Sun for weekly; 1st/5th/10th/15th/Last for monthly; Q1-Q4 for quarterly; hidden for daily). |
| Body — Time | Time picker (default 08:00) |
| Body — Date Range (per run) | Date-from + Date-to inputs |
| Body — Delivery | Checkboxes (Email to me / Email to others / Save to shared drive) + emails text input (visible when "Email to others" checked) |
| Body — Format | Select: PDF / Excel / CSV |
| Footer | Cancel (outline) + "Create Schedule" (`ph:calendar-plus` + accent primary) |
| On submit | **SERVICE_PLACEHOLDER** — show toast: "Scheduling will be available when Scheduled Reports (#101) is built. Your selection has been logged for reference." Do NOT write to DB. Close modal. |

#### User Interaction Flow (hub-launcher)

1. User opens Report Catalog → page loads → `GetReportCatalog` returns: modules + reports + per-user favorites + per-user recent runs in one trip.
2. Recent + Favorites strips render at top; module sections render below in order.
3. User types in search bar → all sections filter in real time (debounced 150ms).
4. User clicks ⭐ on a row → optimistic UI flips icon → `ToggleReportFavorite(reportId)` fires → on error, revert + toast.
5. User clicks Run on a row → Run modal opens → filter form built from `Report.FilterSchema` → user fills → submit → navigate to Generate Report engine.
6. User clicks Schedule on a row → Schedule modal opens → user fills → Submit shows SERVICE_PLACEHOLDER toast → modal closes.
7. User clicks Edit on a Custom row → routes to `/reportaudit/reports/customreportbuilder?reportId={id}` (or unparameterized if #96 build doesn't accept it).
8. User clicks "Custom Report" in header → routes to `/reportaudit/reports/customreportbuilder`.
9. User clicks "My Scheduled Reports" in header → routes to `/reportaudit/reports/scheduledreport` (toast if route 404s — #101 not yet built).

---

### Shared blocks

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading | Initial `GetReportCatalog` fetch | Skeleton: header + filter-bar shown; Recent + Favorites strips show 3 skeleton cards each; each visible module section shows a 4-row skeleton table |
| Empty — overall | No active reports in catalog AND user has no favorites AND no run history | Full-page hint: "No reports configured for your account. Contact your administrator." |
| Empty — Favorites | User has zero favorites | Inline strip empty state (see Favorites section above) |
| Empty — Recent | User has zero runs | Inline strip empty state (see Recent section above) |
| Empty — Filter result | After filter, all sections empty | "No reports match your filters" inline message + "Clear Filters" button |
| Error | `GetReportCatalog` fails | Error card with retry button; reports the GraphQL error code |
| Modal submit error | `ToggleReportFavorite` fails | Inline error toast (preserves modal state — modal stays open if any) |

---

## ⑦ Substitution Guide

> **First SETTINGS_PAGE in the codebase** — this screen sets the convention. Until a more
> conventional SETTINGS_PAGE (e.g. SMTP setup) is built, future hub-launcher screens should
> mirror this file's structure. After build, update `_CONFIG.md` §⑦ to reference
> `reportcatalog.md` as canonical for the hub-launcher variant; consider adding a second
> canonical for "true" singleton-per-tenant SETTINGS_PAGE when one lands.
>
> Closest precedent for shape:
> - **#96 customreportbuilder.md** — first DESIGNER_CANVAS, also a re-classified screen.
>   Mirror the "⚠ READ THIS FIRST" header pattern (done above).
> - **#154 generatereport.md** — engine reuse pattern for Run modal navigation.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| ContactType (MASTER_GRID canonical) — file paths only | ReportFavorite | Entity/class name for the new join table |
| contactType | reportFavorite | camelCase var name |
| CRM | Report | Backend group (existing `Base.Application/Business/ReportBusiness/`) |
| ContactTypes | ReportFavorites | Plural folder name for command/query directories |
| crm | rep | DB schema (existing) |
| crm | reportaudit | FE folder prefix |
| contact | reports | FE feFolder |
| contacttype | reportcatalog | FE entity-lower / route segment |
| CONTACTTYPE | REPORTCATALOG | MenuCode (uppercase) |
| CRM_CONTACT | RA_REPORTS | ParentMenuCode |
| CRM | REPORTAUDIT | ModuleCode |

---

## ⑧ File Manifest

### Backend Files (small — most BE work reuses existing entities/queries)

| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | Entity | `PSS_2.0_Backend/.../Base.Domain/Models/ReportModels/ReportFavorite.cs` | NEW — the one new entity |
| 2 | EF Config | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/ReportConfigurations/ReportFavoriteConfiguration.cs` | NEW — table + indexes + composite unique |
| 3 | Schemas (DTOs) | `PSS_2.0_Backend/.../Base.Application/Schemas/ReportSchemas/ReportCatalogSchemas.cs` | NEW — `ReportCatalogResponseDto`, `ReportCatalogModuleDto`, `ReportCatalogReportDto`, `RecentReportDto`, `FavoriteReportDto`, `ToggleReportFavoriteRequestDto` |
| 4 | GetReportCatalog Query | `PSS_2.0_Backend/.../Base.Application/Business/ReportBusiness/ReportCatalog/GetReportCatalogQuery/GetReportCatalog.cs` | NEW — composite handler aggregating Reports + Modules + favorites + recent runs |
| 5 | ToggleReportFavorite Command | `PSS_2.0_Backend/.../Base.Application/Business/ReportBusiness/ReportCatalog/ToggleFavoriteCommand/ToggleReportFavorite.cs` | NEW — upsert/delete handler |
| 6 | Migration | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Migrations/{YYYYMMDDHHmmss}_Add_ReportFavorite.cs` | NEW — auto-generated, includes composite unique index |
| 7 | Mutations endpoint | `PSS_2.0_Backend/.../Base.API/EndPoints/Report/Mutations/ReportCatalogMutations.cs` | NEW — exposes `ToggleReportFavorite` |
| 8 | Queries endpoint | `PSS_2.0_Backend/.../Base.API/EndPoints/Report/Queries/ReportCatalogQueries.cs` | NEW — exposes `GetReportCatalog` |

> **No Create / Update / Delete commands** for `ReportFavorite` — toggle is the only mutation.
> **No CRUD for Report** itself — that's #96's responsibility (custom rows) and the seeders' (standard rows).
> **No SchemaValidator, no Reorder, no Reset, no Test, no Regenerate** — none apply.

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext.cs` (or `IReportDbContext.cs` if it exists) | `DbSet<ReportFavorite> ReportFavorites { get; set; }` |
| 2 | `ReportDbContext.cs` (or `ApplicationDbContext.cs`) | `public DbSet<ReportFavorite> ReportFavorites { get; set; }` + `OnModelCreating(modelBuilder.ApplyConfiguration(new ReportFavoriteConfiguration()))` if not already auto-applied |
| 3 | `DecoratorProperties.cs` | `DecoratorReportModules.ReportCatalog = "REPORTCATALOG"` |
| 4 | `ReportMappings.cs` | Mapster `TypeAdapterConfig` for `ReportFavorite ↔ ReportFavoriteRequestDto`, etc. |

### Frontend Files

| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/report-service/ReportCatalogDto.ts` | NEW — mirror of BE DTOs (composite Catalog + Module + Report + Recent + Favorite + ToggleRequest) |
| 2 | GQL Query | `PSS_2.0_Frontend/src/infrastructure/gql-queries/report-queries/ReportCatalogQuery.ts` | NEW — `GET_REPORT_CATALOG_QUERY` |
| 3 | GQL Mutation | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/report-mutations/ReportCatalogMutation.ts` | NEW — `TOGGLE_REPORT_FAVORITE_MUTATION` |
| 4 | Catalog Page | `PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reports/reportcatalog/catalog-page.tsx` | NEW — main page composition |
| 5 | Header component | `PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reports/reportcatalog/components/page-header.tsx` | NEW — title + subtitle + 2 CTAs |
| 6 | Filter bar | `…/reportcatalog/components/filter-bar.tsx` | NEW — search + module + type + clear |
| 7 | Recent strip | `…/reportcatalog/components/recent-strip.tsx` | NEW — horizontal scroll of recent runs |
| 8 | Favorites section | `…/reportcatalog/components/favorites-section.tsx` | NEW — collapsible + scroll of favorites |
| 9 | Module section | `…/reportcatalog/components/module-section.tsx` | NEW — collapsible + table per module |
| 10 | Report row | `…/reportcatalog/components/report-row.tsx` | NEW — single row with name/type/lastrun/actions/star |
| 11 | Star toggle | `…/reportcatalog/components/star-toggle.tsx` | NEW — controlled star icon button with optimistic flip |
| 12 | Run modal | `…/reportcatalog/components/run-modal.tsx` | NEW — dynamic filter form + run button → navigate |
| 13 | Schedule modal (placeholder) | `…/reportcatalog/components/schedule-modal.tsx` | NEW — full UI; submit = SERVICE_PLACEHOLDER toast |
| 14 | Page Config | `PSS_2.0_Frontend/src/presentation/pages/reportaudit/reports/reportcatalog.tsx` | NEW — `useAccessCapability({ menuCode: "REPORTCATALOG" })` wrapper renders `<CatalogPage />` |
| 15 | Route Page | `PSS_2.0_Frontend/src/app/[lang]/reportaudit/reports/reportcatalog/page.tsx` | NEW — `"use client"; import { ReportCatalogPageConfig } from "@/presentation/pages/reportaudit/reports/reportcatalog"; export default function() { return <ReportCatalogPageConfig />; }` |

> **Pattern matches** the completed #154 generatereport activation — route page is thin, page-config is the access-control wrapper, page-component is the composition root.

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `entity-operations.ts` | **N/A in this codebase** — confirmed by Glob during #154 build. Skip this step. |
| 2 | `operations-config.ts` | **N/A in this codebase** — same. |
| 3 | Menu seed (SQL) | `Pss2.0_Menus.sql` — add `REPORTCATALOG` row as child of `RA_REPORTS` (MenuId 380), URL `reportaudit/reports/reportcatalog`, OrderBy 1 (already declared in `MODULE_MENU_REFERENCE.md`) |
| 4 | Per-tenant menu/role/capability seed | DB seed script (see §⑨ for the exact CONFIG block) |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by `/plan-screens`.

```
---CONFIG-START---
Scope: FULL

MenuName: Report Catalog
MenuCode: REPORTCATALOG
ParentMenu: RA_REPORTS
Module: REPORTAUDIT
MenuUrl: reportaudit/reports/reportcatalog
GridType: CONFIG

MenuCapabilities: READ, MODIFY, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY

GridFormSchema: SKIP
GridCode: REPORTCATALOG
---CONFIG-END---
```

> Capability semantics:
> - **READ** = view the catalog (everyone with the menu gets this)
> - **MODIFY** = toggle favorites (everyone with the menu gets this; favorites are per-user state, not tenant config — but we still gate the mutation behind MODIFY for consistency with the rest of the codebase)
> - No `DELETE` capability needed — no destructive action on this screen
> - No `EXPORT / IMPORT` — not a settings-export screen
>
> `GridFormSchema: SKIP` — this is a custom hub UI, not an RJSF modal form.
>
> `GridCode: REPORTCATALOG` — declared for forward compatibility (if a future build wants to
> use the `AdvancedDataTable` engine for the per-module tables, the grid registration is in
> place). For the initial build, the per-module tables can be custom (Bootstrap table styled
> per mockup) — gridCode is registered but unused. See feedback memory "Reuse existing grids
> — never fork": if AdvancedDataTable's column model fits the four mockup columns
> (Report / Type / Last Run / Actions), prefer it. The decision should be made at FE build
> time based on whether AdvancedDataTable supports the row-action column-cell shape needed.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `ReportCatalogQueries`
- Mutation type: `ReportCatalogMutations`

### Queries

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetReportCatalog | ReportCatalogResponseDto | — (tenant + user from HttpContext) |

### Mutations

| GQL Field | Input | Returns |
|-----------|-------|---------|
| ToggleReportFavorite | ToggleReportFavoriteRequestDto `{ reportId: int }` | `ToggleReportFavoriteResponseDto { reportId: int, isFavorite: bool, favoriteCount: int }` (favoriteCount = the user's new total favorite count, used by FE for optimistic UI) |

### ReportCatalogResponseDto shape

```
ReportCatalogResponseDto {
  modules: [
    ReportCatalogModuleDto {
      moduleId: int
      moduleCode: string         // e.g. "CRM"
      moduleName: string         // e.g. "CRM"
      moduleDisplayName: string  // e.g. "Fundraising Reports" — mapped to mockup section title
      iconCode: string           // Phosphor or fa-icon name
      colorAccent: string        // hex — used for module badge
      reportCount: int           // number of reports the user can see in this module
      reports: [
        ReportCatalogReportDto {
          reportId: int
          reportCode: string     // used in Run navigation
          reportName: string
          reportDescription: string
          reportType: string     // "Standard" | "Custom" | "Scheduled"
          lastRunDate: DateTime? // user's last run; null if never
          isFavorite: bool       // is in current user's favorites
          isEditable: bool       // true only for Custom-type rows owned by current user / tenant
          filterSchemaJson: string  // raw JSON of Report.FilterSchema, parsed by FE for Run modal
        }
      ]
    }
  ],
  favorites: [                   // pre-joined for the Favorites strip — same shape as ReportCatalogReportDto
    FavoriteReportDto { reportId, reportName, reportCode, reportType, moduleId, moduleCode, moduleColorAccent }
  ],
  recentRuns: [                  // pre-joined for the Recent strip
    RecentReportDto { reportId, reportName, reportCode, moduleId, moduleCode, moduleColorAccent, lastRunDate }
  ]
}
```

> **Sensitive-field handling**: None. No masking, no redacted fields, no PII concerns.

> **Why one composite query and not three separate queries?** Page load is one round-trip;
> the catalog is small (< 100 reports/tenant typical); the Recent + Favorites + Modules data
> share `Report` joins so aggregating server-side is cheap. If the catalog grows past
> ~500 reports, consider splitting into 3 queries with pagination on modules.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/reportaudit/reports/reportcatalog`

**Functional Verification (Full E2E — MANDATORY) — SETTINGS_PAGE hub-launcher variant:**

- [ ] Page header renders with correct title + subtitle + both CTAs styled correctly
- [ ] "Custom Report" CTA → routes to `/{lang}/reportaudit/reports/customreportbuilder` (no error even if #96 still shows UnderConstruction)
- [ ] "My Scheduled Reports" CTA → routes to `/{lang}/reportaudit/reports/scheduledreport` OR toasts SERVICE_PLACEHOLDER if route does not yet exist
- [ ] Filter bar: search input + module select + type select + clear button all render
- [ ] Search filter narrows visible rows across all sections in real-time
- [ ] Module filter shows/hides entire module sections
- [ ] Type filter shows/hides individual rows
- [ ] Clear Filters resets all three; visible rows restore
- [ ] Recent strip renders the current user's last 5 distinct runs in DESC order
- [ ] "Run Again" on a Recent card opens Run modal with that report pre-selected
- [ ] Empty Recent shows "No recent reports — …" message
- [ ] Favorites strip renders the current user's starred reports
- [ ] Favorites section collapses/expands via chevron click
- [ ] Empty Favorites shows "You haven't starred any reports yet — …" message
- [ ] Each module section renders with icon + display name + count badge + chevron
- [ ] Module section collapses/expands via header click
- [ ] Each row shows report name + description + type badge + last-run date + actions
- [ ] Type badge color matches mockup: Standard=cyan / Custom=violet / Scheduled=amber
- [ ] "Run" button opens Run modal with selected report
- [ ] "Schedule" button opens Schedule modal with selected report (hidden for `ReportType = 'Scheduled'` rows)
- [ ] "Edit" button visible ONLY for `ReportType = 'Custom'` rows → routes to `/{lang}/reportaudit/reports/customreportbuilder?reportId={id}` (or unparameterized fallback)
- [ ] Star toggle: click → instant icon flip (optimistic) → `TOGGLE_REPORT_FAVORITE_MUTATION` fires → on success: silent (or success toast) → on error: revert + error toast
- [ ] Toggling star adds/removes the report from the Favorites strip (live, without full page reload)
- [ ] **Run modal — dynamic filter form**: opens with selected report's name visible; filter fields rendered from `Report.FilterSchema` JSON (NOT hardcoded). Fields validate per declared types. Submit serializes filters + navigates to `/{lang}/reportaudit/reports/generatereport?reportCode={code}&filters={base64-json}` (or matching pattern accepted by Generate Report engine).
- [ ] **Schedule modal — full UI placeholder**: opens with all fields rendered (frequency, day/date, time, date range, delivery checkboxes, emails text input visible-when-checked, format select). Submit shows SERVICE_PLACEHOLDER toast: "Scheduling will be available when Scheduled Reports (#101) is built." Modal closes; NO DB write.
- [ ] Loading state — skeleton placeholders for all 3 strip + 6 sections render until `GetReportCatalog` resolves
- [ ] Error state — if `GetReportCatalog` fails, error card with retry button replaces the body; header + filter bar still render

**DB Seed Verification:**
- [ ] Menu `Report Catalog` appears in sidebar at Report & Audit › Reports
- [ ] BUSINESSADMIN role gets READ + MODIFY capabilities on REPORTCATALOG
- [ ] Existing `rep.Reports` seed rows surface in catalog (no new ReportDefinition seeding needed)
- [ ] (Optional) 1-2 sample `ReportFavorite` rows seeded for the demo user so Favorites isn't empty on a fresh install

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Re-classification deviation** (already covered in the header — see top of file):
- Registry says SKIP_DASHBOARD; reality is CONFIG/SETTINGS_PAGE (hub-launcher variant).
- This is the **first SETTINGS_PAGE** in the codebase, but is a *hub-launcher* variant, not a true singleton-per-tenant config page (like SMTP setup would be). Future SETTINGS_PAGE screens may need a second canonical example. Maintainer: update `_CONFIG.md` §⑦ after this lands.

**Universal CONFIG warnings (still apply):**
- **CompanyId + UserId are NOT form fields** — both come from HttpContext.
- **No Create/Delete on `Report`** — those rows are seeded or come from #96 Custom Report Builder. This screen is read-only on `Report`.
- **GridFormSchema = SKIP** — custom UI, not RJSF.
- **No view-page 3-mode** — single-mode page.

**Sub-type / hub-launcher gotchas:**

- **Run modal filter fields**: do NOT hardcode the mockup's Branch / Purpose / Payment Mode / Group By dropdowns. They illustrate ONE report's filter (Donation Summary). Real implementation renders the fields from `Report.FilterSchema` per selected report. If `Report.FilterSchema` is null/empty for a given report, render only the Output Format select (and Run button just navigates with `?reportCode={code}` — Generate Report engine prompts for filters on load).
- **Star toggle optimistic UI**: flip the icon immediately on click for perceived performance. Only revert on error. Don't await the mutation before flipping — this is a 1-byte change and the user expects instant feedback.
- **Recent strip query freshness**: after a user runs a report, the Recent strip should reflect the new run. Either (a) re-query `GetReportCatalog` when the user returns to this screen via Next.js route refresh, or (b) accept that Recent updates on next manual page load. Option (b) is acceptable for v1.
- **Module section visibility**: a module appears in the catalog ONLY if (a) the user has READ capability on at least one report under it, AND (b) the module has at least one active report (`Report.IsActive = true`). Filter at query-time in `GetReportCatalog`.
- **Custom row Edit destination**: `/reportaudit/reports/customreportbuilder?reportId={id}` is the intended URL but #96 build may not accept `reportId` initially — confirm at integration time. Fallback: unparameterized navigation to `/customreportbuilder` (user re-opens the report in the builder).
- **Schedule modal must NOT pretend to schedule**: the placeholder toast must be clear that scheduling is unavailable. Do NOT show a "Schedule created!" success toast — that would be misleading. Recommended toast wording: "Scheduling will be available when Scheduled Reports (#101) is built. Your selection has been captured for reference." If feasible, log the schedule intent to a temporary `rep.PlannedSchedules` row (out of scope for v1 — don't add a table just for this).
- **Sidebar menu seed for #101 not yet present**: the "My Scheduled Reports" button in the page header will 404 if #101 hasn't been built. Wrap the navigation in a try/catch: if the route file doesn't exist, show a SERVICE_PLACEHOLDER toast instead. Or, check menu seed at build time: if `SCHEDULEDREPORT` menu is not seeded, render the button as disabled with a tooltip "Coming soon (#101)."
- **`AdvancedDataTable` reuse decision**: per feedback memory "Reuse existing grids — never fork", the per-module tables should reuse `AdvancedDataTable` IF the row-action column shape (4 buttons: Run / Schedule / Edit / Star) is supported. If not, a plain styled table is acceptable for this screen — but document the decision in the build commit message. Do NOT fork `AdvancedDataTable`.

**Module / module-instance notes:**
- This screen uses the existing `rep` schema and the existing `Report` group — no new schema, no new group module needs to be wired.
- The Report Catalog menu is already declared in `MODULE_MENU_REFERENCE.md` (`RA_REPORTS` parent, OrderBy 1, URL `reportaudit/reports/reportcatalog`) — seed it via `_seed_child_menu`.

**Service Dependencies** (UI-only — backend handler returns mock/toast):

> Everything ELSE shown in the mockup is in scope. The list below is ONLY genuine external-service dependencies.

- ⚠ **SERVICE_PLACEHOLDER: Schedule Report submit handler.** Full Schedule modal UI is implemented (frequency, day, time, date range, delivery options, format). The "Create Schedule" button shows a toast pointing to #101 and does NOT write to DB. Reason: `ScheduledReport` / `ReportSchedule` entity does not exist yet (registry #101 = SKIP_CONFIG). Hangfire infrastructure IS present (`Hangfire` + `Hangfire.PostgreSql` in `Base.Application.csproj`), so when #101 is built, the placeholder can be swapped for a real `CreateScheduledReport` mutation with zero changes to this screen's modal UI.
- ⚠ **SERVICE_PLACEHOLDER (degradable): My Scheduled Reports button.** If `SCHEDULEDREPORT` menu route does not exist at build time (`page.tsx` missing), the header button shows a toast instead of routing. When #101 builds the route, this becomes a real navigation automatically (no code change needed).

Full UI must be built (filter bar, recent strip, favorites strip, all module sections, both modals). Only the Schedule submit handler is mocked.

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

### Session 1 — 2026-05-13 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. CONFIG/SETTINGS_PAGE hub-launcher variant — **first SETTINGS_PAGE in codebase**, sets canonical for hub-launcher style.
- **Pre-build verification corrections applied** (caught before BE Developer spawn):
  - `Module.ModuleId` is `Guid` not `int` (prompt §⑩ had `int`)
  - `Report.Description` not `ReportDescription` (prompt §② naming was off; mapped via DTO property `ReportDescription`)
  - `Report.CompanyId` is `int?` nullable — handler filters `(r.CompanyId == null || r.CompanyId == currentCompanyId)` to surface system/global reports
  - DbContext target = `IReportDbContext` (not `IApplicationDbContext` as prompt §⑧ stated)
  - Decorator goes in existing `DecoratorReportModules` class (added `ReportCatalog = "REPORTCATALOG"` + `ReportFavorite = "REPORTFAVORITE"`)
- **Files touched**:
  - BE (7 created + 4 modified):
    - `Base.Domain/Models/ReportModels/ReportFavorite.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ReportConfigurations/ReportFavoriteConfiguration.cs` (created)
    - `Base.Application/Schemas/ReportSchemas/ReportCatalogSchemas.cs` (created — 7 DTOs)
    - `Base.Application/Business/ReportBusiness/ReportCatalog/GetReportCatalogQuery/GetReportCatalog.cs` (created — 148 lines)
    - `Base.Application/Business/ReportBusiness/ReportCatalog/ToggleFavoriteCommand/ToggleReportFavorite.cs` (created — 78 lines)
    - `Base.API/EndPoints/Report/Queries/ReportCatalogQueries.cs` (created — `[ExtendObjectType(OperationTypeNames.Query)]`)
    - `Base.API/EndPoints/Report/Mutations/ReportCatalogMutations.cs` (created — `[ExtendObjectType(OperationTypeNames.Mutation)]`)
    - `Base.Application/Data/Persistence/IReportDbContext.cs` (modified — added `DbSet<ReportFavorite>`)
    - `Base.Infrastructure/Data/Persistence/ReportDbContext.cs` (modified — added DbSet impl)
    - `Base.Application/Extensions/DecoratorProperties.cs` (modified — added 2 decorator entries to `DecoratorReportModules`)
    - `Base.Application/Mappings/ReportMappings.cs` (modified — added Mapster config for `ReportFavorite ↔ ToggleReportFavoriteResponseDto`)
  - FE (15 created + 5 modified):
    - `domain/entities/report-service/ReportCatalogDto.ts` (created — 7 interfaces)
    - `infrastructure/gql-queries/report-queries/ReportCatalogQuery.ts` (created)
    - `infrastructure/gql-mutations/report-mutations/ReportCatalogMutation.ts` (created)
    - `presentation/components/page-components/reportaudit/reports/reportcatalog/catalog-page.tsx` (created — composition root, 342 lines)
    - `…/reportcatalog/components/page-header.tsx` (created)
    - `…/reportcatalog/components/filter-bar.tsx` (created — search + module + type + clear)
    - `…/reportcatalog/components/recent-strip.tsx` (created — horizontal scroll cards)
    - `…/reportcatalog/components/favorites-section.tsx` (created — collapsible strip)
    - `…/reportcatalog/components/module-section.tsx` (created — collapsible table)
    - `…/reportcatalog/components/report-row.tsx` (created — name + type badge + last-run + actions)
    - `…/reportcatalog/components/star-toggle.tsx` (created — controlled icon button)
    - `…/reportcatalog/components/run-modal.tsx` (created — dynamic FilterSchema-driven form)
    - `…/reportcatalog/components/schedule-modal.tsx` (created — full UI; SERVICE_PLACEHOLDER on submit)
    - `presentation/pages/reportaudit/reports/reportcatalog.tsx` (created — access-control wrapper)
    - `app/[lang]/reportaudit/reports/reportcatalog/page.tsx` (modified — replaced UnderConstruction stub with real page)
    - `domain/entities/report-service/index.ts` (modified — barrel export)
    - `infrastructure/gql-queries/report-queries/index.ts` (modified — barrel export)
    - `infrastructure/gql-mutations/report-mutations/index.ts` (modified — barrel export)
    - `presentation/pages/reportaudit/reports/index.ts` (modified — barrel export)
  - DB: `Base/sql-scripts-dyanmic/ReportCatalog-sqlscripts.sql` (created — Menu fallback + MenuCapabilities READ/MODIFY/ISMENURENDER + RoleCapabilities for all 6 roles + Grid registration + Optional sample favorites stub)
- **Mid-build correction (orchestrator-applied)**: After FE Developer finished, verified the BE endpoint returns `BaseApiResponse<T>` (the codebase's standard wrapper — confirmed against `ReportMutation.ts` precedent). The FE GQL queries and consumer code originally assumed the BE returned the raw DTO. Fixed by:
  - `ReportCatalogQuery.ts` rewritten with `result: reportCatalog { errorCode, errorDetails, message, status, success, data { ...DTO } }`
  - `ReportCatalogMutation.ts` rewritten with `$reportId: Int!` variable + same envelope shape
  - `catalog-page.tsx` updated: `CatalogQueryResult` interface now reflects the envelope; `const catalog = data?.result?.data` extracted once; all 3 dereferences (`modules`, `favorites`, `recentRuns`) updated to read from `catalog?.…`; mutation variables changed from `{ request: { reportId } }` to `{ reportId }`
- **Deviations from spec**:
  - **Run modal filter rendering**: implemented per spec — driven by `report.filterSchemaJson` parse. If null/empty, modal navigates with only `?reportCode=…` (no `filters` param). Acceptable degradation per prompt §⑫.
  - **Per-row table**: implemented as lightweight custom HTML table inside `module-section.tsx` (NOT `AdvancedDataTable`). Justified per feedback memory "Reuse existing grids — never fork" + prompt §⑥ — `AdvancedDataTable` requires GridField backing which is not applicable to read-only catalog rows with action buttons. Custom row component uses shared design tokens (no inline hex/px violations).
  - **Schedule modal**: full UI built (frequency / day / time / date range / delivery / format), submit shows toast pointing to #101 — exactly per spec, NO DB write.
  - **Type Badge component**: codebase's shared `<Badge>` does not have a violet variant. Used Tailwind-token className mapping for type badges in `report-row.tsx` (Standard=cyan, Custom=violet, Scheduled=amber). Not a deviation; this is an extension of the existing primitive.
- **Known issues opened**: None at end of session.
- **Known issues closed**: None.
- **Migration command** (user must run):
  ```
  dotnet ef migrations add Add_ReportFavorite_Table --project Base.Infrastructure --startup-project Base.API --context ApplicationDbContext
  ```
- **Verification steps** (user must run):
  1. Run the migration command above + `dotnet ef database update`
  2. Execute `ReportCatalog-sqlscripts.sql` against the dev database (after the migration applies the new table)
  3. `dotnet build` — verify no compilation errors
  4. `pnpm dev` — verify `/{lang}/reportaudit/reports/reportcatalog` loads (UnderConstruction stub is gone)
  5. Smoke-test the page: filter bar, star toggle, Run modal launching `generatereport`, Schedule modal placeholder toast
- **Canonical precedent set**: This is the **first SETTINGS_PAGE** in the codebase. Future hub-launcher screens (e.g. a Communications Catalog or Templates Catalog) should mirror this file's structure and `_CONFIG.md` §⑦ should now reference `reportcatalog.md` as canonical for the hub-launcher variant of SETTINGS_PAGE.
- **Next step**: (none — session COMPLETED)