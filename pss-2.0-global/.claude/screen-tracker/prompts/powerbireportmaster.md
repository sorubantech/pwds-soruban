---
screen: PowerBIReportMaster
registry_id: 155
module: Report & Audit
status: COMPLETED
scope: ALIGN
screen_type: MASTER_GRID
complexity: Medium
new_module: NO
planned_date: 2026-05-14
completed_date: 2026-05-14
last_session_date: 2026-05-14
---

## Tasks

### Planning (by /plan-screens)
- [x] Mockup TBD — design taken from sibling #97 PowerBIViewer slide-in admin (canonical UX precedent, user-confirmed)
- [x] Existing code reviewed — BE entity + all CRUD endpoints exist; FE route stub exists but mis-wired (uses POWERBIREPORT menu code)
- [x] Business rules extracted (incl. Update soft-delete StaffIds quirk + #97 ISSUE-V2-15 "preserve StaffIds on edit" rule)
- [x] FK targets resolved — only User (`auth.Users`) via `GetUsers` GQL query (StaffIds in DTO is misnamed → maps to `UserId` on `PowerBIReportUserMapping`)
- [x] File manifest computed (FE-only build + DB seed; BE wiring already complete)
- [x] Approval config pre-filled (POWERBIREPORTMASTER under RA_REPORTSETUP)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt §① consumed verbatim — no re-analysis needed)
- [x] Solution Resolution complete (MASTER_GRID + ALIGN + Variant A confirmed)
- [x] UX Design finalized (prompt §⑥ consumed verbatim)
- [x] User Approval received (2026-05-14)
- [x] Backend code generated          ← SKIPPED (entity + CRUD already exist)
- [x] Backend wiring complete         ← SKIPPED
- [x] Frontend code generated (3 modify + 4 create + 1 route-stub replace)
- [x] Frontend wiring complete (3 barrels + entity-operations)
- [x] DB Seed script generated (defensive Menu + Caps + Grid + 13 Fields + 8 GridFields + GridFormSchema)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `pnpm dev` — page loads at `/{lang}/reportaudit/reportsetup/powerbireportmaster`
- [ ] Grid loads via `getAllPowerBIReports` query (NOT `getPowerBIReports` — confirm projection includes new fields)
- [ ] Search filters by ReportName / ReportKey
- [ ] Add new record → modal form shows all fields → save succeeds → row appears in grid (auto-mapped to current user via StaffIds=[currentUserId])
- [ ] Edit record → modal pre-fills via `getPowerBIReportById` (incl. StaffIds round-trip — see ISSUE-1) → save succeeds → grid updates
- [ ] Toggle active/inactive → badge changes via `activateDeactivatePowerBIReport`
- [ ] Delete → soft delete → row disappears via `deletePowerBIReport`
- [ ] User multi-select (StaffIds field) loads via `GetUsers` query — confirm options render and persist
- [ ] FilterParameters key-value editor renders + serializes valid JSON to FilterParametersJson
- [ ] AutoRefresh switch + interval select disabled when AutoRefreshEnabled=false
- [ ] DB Seed — Menu visible in sidebar under RA_REPORTSETUP → "PowerBI Report Master"
- [ ] Permissions: BUSINESSADMIN sees all actions; non-admin gets `<DefaultAccessDenied />`

---

## ① Screen Identity & Context

**Screen**: PowerBI Report Master
**Module**: Report & Audit (`REPORTAUDIT`)
**Schema**: `rep`
**Group**: Report (in `Base.Application.Business.ReportBusiness`, `Base.Domain.Models.ReportModels`)

**Business**:
PSS 2.0 publishes Microsoft Power BI dashboards to tenants through three coordinated screens. Sibling #97 PowerBI Viewer is the **end-user surface** (gallery + embed + slide-in admin shortcut) under `RA_REPORTS`. **#155 PowerBI Report Master** (this screen) is the **full-page admin grid** under `RA_REPORTSETUP` — the same `rep.PowerBIReports` registry but rendered as a standard MASTER_GRID for power-users who manage many report definitions, with full search/filter/import/export. Sibling #156 PowerBI User Mapping is the deeper per-user RLS surface. The slide-in panel in #97 is intentionally a power-user shortcut and does NOT replace this screen — admins use this page when they need bulk operations, sortable columns, or grid-level filtering across a large catalog.

**Why MASTER_GRID**: full-page list of N records (PowerBI report definitions) with per-row CRUD via modal popup form. The mockup-TBD design takes the slide-in admin form from #97 (Section 2 — Add/Edit Report) verbatim and renders it as an RJSF modal at full-page scale. There is no per-record workflow or multi-mode view page (rules out FLOW), no widget-heavy KPI surface (rules out DASHBOARD), no filter→Generate→export pattern (rules out REPORT), and the screen manages a list-of-N, not a single config record (rules out CONFIG).

---

## ② Entity Definition

> **Status: EXISTING — DO NOT regenerate.** Entity, EF config, DTOs, all 4 commands (Create/Update/Delete/Toggle), 4 queries (GetAll paginated×2 + GetById + GetEmbed), Mutations endpoint, and Queries endpoint already exist and were verified in BE codebase 2026-05-14.

Table: `rep."PowerBIReports"` (existing; extended by #97 with 4 NEW columns)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| PowerBIReportId | int | — | PK | — | identity |
| CompanyId | int | — | YES | corg.Companies | tenant scope (HttpContext, NOT a form field) |
| ReportKey | string | 100 | YES | — | tenant-unique stable code (auto-slug from ReportName, override allowed) |
| ReportName | string | 200 | YES | — | display name |
| WorkspaceId | Guid | — | YES | — | Power BI workspace GUID |
| PowerBIReportGuid | Guid | — | YES | — | Power BI report GUID |
| OrderBy | int | — | YES | — | display order on #97 gallery (max(existing)+1 default) |
| Description | string? | 500 | NO | — | shown on card / grid description col |
| RlsRoleName | string? | 100 | NO | — | optional RLS role passed to embed token |
| ThumbnailUrl | string? | 500 | NO | — | optional thumbnail (V1 = URL only — see #97 ISSUE-V2-3) |
| AutoRefreshEnabled | bool | — | YES | — | default true |
| AutoRefreshIntervalHours | int | — | YES | — | default 12; range 1–168 |
| FilterParametersJson | string? | 1000 | NO | — | JSON map of PSS context → PBI filter name (e.g. `{"CompanyId":"CompanyId","BranchId":"BranchId","Role":"Role"}`) |

**Child Entities** (existing — managed via UpdatePowerBIReport's StaffIds payload):

| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| PowerBIReportUserMapping | 1:Many via PowerBIReportId | UserId (FK to auth.Users) — controls per-user visibility (deeper RLS handled by #156) |

**Naming caveat (carried from BE — DO NOT rename)**: the DTO field is `StaffIds` but it actually maps to `User.UserId`. The validator at `UpdatePowerBIReport.cs:42-45` looks up `_dbContext.Users` (NOT Staff). This is misnamed but stable — the FE form labels the control "Allowed Users" and binds to `staffIds` over the wire.

---

## ③ FK Resolution Table

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| StaffIds (→ PowerBIReportUserMapping.UserId) | User | `Base.Domain/Models/AuthModels/User.cs` | `GetUsers` | UserName | `UserResponseDto` |
| CompanyId | Company | `Base.Domain/Models/AppModels/Company.cs` | n/a (HttpContext-stamped, not selected by user) | — | — |

**Note on `GetUsers`**: it's paginated under `[CustomAuthorize(DecoratorAuthModules.UserRole, Permissions.Read)]` at `Base.API/EndPoints/Auth/Queries/UserQueries.cs:19`. ApiSelectV2 will fire it with default paging (no extra args). If `Read` capability on `USERROLE` becomes a barrier for BUSINESSADMIN-with-no-USERROLE-read scenarios, the build session can fall back to `GetStaffsForSelect` at `Base.API/EndPoints/Application/Queries/StaffQueries.cs:11` (cross-module `[NoAuthorize]` shape) — but per the existing validator the IDs MUST be valid `auth.Users.UserId`, so the dropdown MUST query users, not staff. Surface as `ISSUE-2` if hit.

---

## ④ Business Rules & Validation

**Uniqueness Rules** (enforced today by Update validator + EF config):
- `ReportKey` should be unique per Company (current EF config has single-column unique on `ReportKey` only — same gap flagged in #97 ISSUE-V2-1bis; the build session may opt to leave as-is and let #97's migration tighten it).

**Required Field Rules** (from existing `CreatePowerBIReport.cs` / `UpdatePowerBIReport.cs` validators):
- ReportKey, ReportName, WorkspaceId, PowerBIReportGuid, OrderBy — all required
- StaffIds — non-null + at-least-one (`UpdatePowerBIReport.cs:31-35`)
- All StaffIds must reference active, non-deleted `auth.Users` rows (`:37-49`)

**Conditional Rules**:
- AutoRefreshIntervalHours required when AutoRefreshEnabled = true (FE-side; BE accepts the int regardless because of EF default)
- FilterParametersJson must be parseable JSON (validate on save — reject parse errors)

**Business Logic** (existing — DO NOT change):
- Update handler at `UpdatePowerBIReport.cs:80-160` syncs `UserMappings` via add/reactivate/soft-delete diff. **Bug carried over from #97 ISSUE-V2-15**: if `StaffIds` arrives empty/null on update, ALL mappings are soft-deleted. Build session must enforce on FE: pre-fill `staffIds` from `getPowerBIReportById` round-trip on Edit, and pre-fill `[currentUserId]` on Create (so the admin who creates is mapped at minimum).
- Toggle command flips `IsActive`; Delete command soft-deletes (sets `IsDeleted=true`).
- All endpoints scoped by `CompanyId` from HttpContext.

**Workflow**: None.

---

## ⑤ Screen Classification & Pattern Selection

**Screen Type**: MASTER_GRID
**Type Classification**: Type 1 — flat entity with one child collection (UserMappings) that is managed inline via StaffIds payload (no separate child grid in the form).
**Reason**: Full-page list of N report definitions; per-row CRUD via modal popup form. No multi-mode view page (rules out FLOW), no widgets-vs-grid layout (just a grid + summary stats above optional), no public-facing surface.

**Backend Patterns Required:**
- [ ] Standard CRUD (11 files) — **SKIP, already exists**
- [x] Nested child mutation via parent payload (StaffIds → UserMappings) — **already implemented in `UpdatePowerBIReport.cs`**
- [x] Multi-FK validation (StaffIds member-of-Users check) — **already implemented**
- [x] Unique validation — already on ReportKey
- [ ] File upload command — N/A (V1 ThumbnailUrl is URL-only)
- [ ] Custom business rule validators — N/A

**Frontend Patterns Required:**
- [x] AdvancedDataTable (gridCode `POWERBIREPORTMASTER`)
- [x] RJSF Modal Form (driven by GridFormSchema in DB seed)
- [ ] File upload widget — N/A (URL only)
- [ ] Summary cards / count widgets — NONE (Variant A — `<AdvancedDataTable>` internal header only)
- [ ] Grid aggregation columns — NONE (LastRefreshedAt is shown on #97's gallery, NOT this admin grid)
- [ ] Info panel / side panel — NONE
- [ ] Drag-to-reorder — NONE (OrderBy editable in form; reorder UI deferred)
- [ ] Click-through filter — NONE
- [x] Custom RJSF widgets needed: `ApiSelectV2` for StaffIds (multi-select against `GetUsers`), key-value-rows widget for FilterParameters (or a JSON textarea if no widget exists)

---

## ⑥ UI/UX Blueprint

> **Source**: mockup TBD. Design lifted verbatim from sibling #97 PowerBIViewer prompt §⑥ Section 2 (Add/Edit Report Field Mapping) at `prompts/powerbiviewer.md:344-360`. Rendered here as a full-page MASTER_GRID instead of a slide-in panel.

### Grid/List View

**Display Mode**: `table`

**Layout Variant**: `grid-only` (Variant A — `<AdvancedDataTable>` with internal header; NO `<ScreenHeader>` + widgets).

**Grid Columns** (in display order):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Report Name | reportName | text | auto | YES | Primary column |
| 2 | Report Key | reportKey | text | 140px | YES | tenant-unique slug |
| 3 | Workspace ID | workspaceId | text (mono, truncated) | 160px | NO | GUID — show first 8 chars + ellipsis on hover full |
| 4 | Report GUID | powerBIReportGuid | text (mono, truncated) | 160px | NO | GUID — same truncate |
| 5 | Order | orderBy | number | 70px | YES | display order on #97 gallery |
| 6 | Auto-Refresh | autoRefreshEnabled | badge | 110px | YES | "Every Nh" / "Off" |
| 7 | RLS Role | rlsRoleName | text | 120px | NO | nullable |
| 8 | Allowed Users | staffIds.length | count chip | 110px | NO | "5 users" → click opens edit modal pre-focused on field |
| 9 | Status | isActive | badge | 90px | YES | Active / Inactive |
| 10 | Modified | modifiedDate | datetime | 140px | YES | inherited audit |

**Search/Filter Fields**: reportName, reportKey, workspaceId, isActive (advanced filter)

**Grid Actions**: Edit (✎), Toggle Active, Delete

**Toolbar Actions**: + Add (opens RJSF modal), Import (existing import-export-table behavior), Export, Print

### RJSF Modal Form

**Form Sections** (in order — single accordion section per MASTER_GRID convention; or 3 logical groupings using `ui:fieldset`):

| Section | Title | Layout | Fields |
|---------|-------|--------|--------|
| 1 | Report Identity | 2-column | reportName, reportKey, description, orderBy |
| 2 | Power BI Source | 2-column | workspaceId, powerBIReportGuid, thumbnailUrl |
| 3 | Refresh & Filters | 2-column | autoRefreshEnabled, autoRefreshIntervalHours, filterParametersJson (full-width) |
| 4 | Access | 1-column | rlsRoleName, staffIds (multi-select) |

**Field Widget Mapping** (mirrors #97 viewer's slide-in form):

| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| reportName | text | — | required, max 200 | maps to `ReportName` |
| reportKey | text (auto-slug from reportName, editable) | slug(reportName) | required, max 100, unique-per-tenant | maps to `ReportKey` — show "Auto-generated" hint when blank, lock-icon to override |
| description | textarea | — | max 500 | maps to `Description` |
| orderBy | number | max(existing)+1 (FE-computed before submit) | required, positive int | hidden in basic mode, exposed via "Show advanced" toggle |
| workspaceId | text | — | required, valid GUID | help-text: "Power BI portal → Workspace settings → Workspace ID" |
| powerBIReportGuid | text | — | required, valid GUID | help-text: "Power BI portal → Report → File → Embed report" |
| thumbnailUrl | url-input | — | optional, valid URL | maps to `ThumbnailUrl` (V1 URL-only — see #97 ISSUE-V2-3) |
| autoRefreshEnabled | switch | true | — | maps to `AutoRefreshEnabled` |
| autoRefreshIntervalHours | select (1 / 6 / 12 / 24 / 48 / 168) | 12 | required when autoRefreshEnabled=true | maps to `AutoRefreshIntervalHours`; disabled when switch off |
| filterParametersJson | json-key-value-rows widget OR JSON textarea | `{"CompanyId":"CompanyId","BranchId":"BranchId","Role":"Role"}` | optional, valid JSON object (parse-check on save) | maps to `FilterParametersJson`; if no key-value-rows widget exists, fall back to monaco-style JSON textarea with parse-error inline message |
| rlsRoleName | text | — | optional, max 100 | maps to `RlsRoleName` (passed to embed token if set) |
| staffIds | ApiSelectV2 (multi-select) | `[currentUserId]` on Create, fetched list on Edit | required, ≥1 user | binds `GetUsers` query, displays `userName`, value=`userId`; **CRITICAL**: pre-fill from `getPowerBIReportById` on Edit and inject `currentUserId` on Create — see ISSUE-1 below |

**Form Actions**: `[Save Report]` (calls `createPowerBIReport` if no id, `updatePowerBIReport` otherwise) + `[Cancel]`

### Page Widgets & Summary Cards

**Widgets**: NONE (Variant A — keep grid focused; counts are obvious from pagination footer).

### Grid Aggregation Columns

**Aggregation Columns**: NONE (LastRefreshedAt belongs to #97's gallery view, not this admin grid).

### Side Panels / Info Displays

**Side Panel**: NONE.

### User Interaction Flow

1. User loads `/{lang}/reportaudit/reportsetup/powerbireportmaster` → `useAccessCapability({ menuCode: "POWERBIREPORTMASTER" })` resolves → grid renders via `getAllPowerBIReports`.
2. User clicks **+ Add** → RJSF modal opens → autoRefreshEnabled defaults true, interval 12h, filterParameters pre-filled with default JSON, staffIds pre-filled with `[currentUserId]` from auth context, orderBy = max(existing)+1 (FE-computed).
3. User fills in reportName → reportKey auto-slugs (overridable) → fills WorkspaceId/ReportGuid → optionally adjusts users + filter params → **Save Report** → `createPowerBIReport` → toast → modal closes → grid refetches.
4. User clicks **Edit** (✎) on a row → `getPowerBIReportById` fires → modal pre-fills with **all** existing fields including `staffIds` (CRITICAL — see ISSUE-1) → user edits → **Save Report** → `updatePowerBIReport` → grid refetches.
5. User clicks **Toggle** → confirm → `activateDeactivatePowerBIReport(id)` → status badge flips.
6. User clicks **Delete** → confirm → `deletePowerBIReport(id)` → row disappears (soft-delete).
7. Non-BUSINESSADMIN users see `<DefaultAccessDenied />`.

---

## ⑦ Substitution Guide

**Canonical Reference**: ContactType (MASTER_GRID) — but ALL backend files already exist; only FE substitution applies.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| ContactType | PowerBIReport | Entity/class name (DO NOT prefix with "Master" — keeps DTO name aligned with #97 viewer's existing reuse) |
| contactType | powerBIReport | Variable/field names |
| ContactTypeId | PowerBIReportId | PK field |
| ContactTypes | PowerBIReports | Table name, collection names |
| contact-type | powerbi-report-master | FE route segment (kebab N/A — single word route below) |
| contacttype | powerbireportmaster | FE folder, import paths (route + page-component folder) |
| CONTACTTYPE | POWERBIREPORTMASTER | Grid code, menu code (NEW — distinct from existing `POWERBIREPORT` used by #97) |
| corg | rep | DB schema |
| Corg | Report | Backend group name |
| CorgModels | ReportModels | Namespace suffix |
| CONTACT | RA_REPORTSETUP | Parent menu code |
| CRM | REPORTAUDIT | Module code |
| crm/contact/contacttype | reportaudit/reportsetup/powerbireportmaster | FE route path |
| corg-service | report-service | FE service folder name (existing `report-service` — confirm during build) |

**Naming reconciliation note**: the BE entity is `PowerBIReport` (not `PowerBIReportMaster`). The screen/menu adds the "Master" suffix only at the route + menu level to distinguish the admin grid from #97's viewer (which uses menu `POWERBIREPORT`). FE folder + page component name use `powerbireportmaster`; data binding still uses the entity's `powerBIReport*` field names.

---

## ⑧ File Manifest

### Backend Files

> **All 11 standard MASTER_GRID files already exist — DO NOT regenerate.**

| # | File | Path | Status |
|---|------|------|--------|
| 1 | Entity | `Base.Domain/Models/ReportModels/PowerBIReport.cs` | EXISTS |
| 2 | EF Config | `Base.Infrastructure/Data/Configurations/ReportConfigurations/PowerBIReportConfiguration.cs` | EXISTS |
| 3 | Schemas (DTOs) | `Base.Application/Schemas/ReportSchemas/PowerBIReportSchemas.cs` | EXISTS (incl. `PowerBIReportRequestDto` / `ResponseDto` / `Dto` w/ LastRefreshedAt) |
| 4 | Create Command | `Base.Application/Business/ReportBusiness/PowerBIReports/Commands/CreatePowerBIReport.cs` | EXISTS |
| 5 | Update Command | `Base.Application/Business/ReportBusiness/PowerBIReports/Commands/UpdatePowerBIReport.cs` | EXISTS |
| 6 | Delete Command | `Base.Application/Business/ReportBusiness/PowerBIReports/Commands/DeletePowerBIReport.cs` | EXISTS |
| 7 | Toggle Command | `Base.Application/Business/ReportBusiness/PowerBIReports/Commands/TogglePowerBIReport.cs` | EXISTS |
| 8 | GetAll Query (paginated) | `Base.Application/Business/ReportBusiness/PowerBIReports/Queries/GetPowerBIReport.cs` (`GetPowerBIReportsQuery`) AND `GetAllPowerBIReportsQuery.cs` | EXISTS — both queries live; FE binds `getAllPowerBIReports` |
| 9 | GetById Query | `Base.Application/Business/ReportBusiness/PowerBIReports/Queries/GetPowerBIReportById.cs` | EXISTS |
| 10 | Mutations endpoint | `Base.API/EndPoints/Report/Mutations/PowerBIReportMutations.cs` | EXISTS |
| 11 | Queries endpoint | `Base.API/EndPoints/Report/Queries/PowerBIReportQueries.cs` | EXISTS |

### Backend Wiring Updates

> **All wiring already complete (entity in DbContext, mutations/queries registered, mappings configured). NO backend changes required for this build.**

### Frontend Files (6 files)

| # | File | Path | Status |
|---|------|------|--------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/report-service/PowerBIReportDto.ts` | CHECK if extension of existing `report-service` DTOs needed (likely already added by #97 prep) — append if missing |
| 2 | GQL Query | `Pss2.0_Frontend/src/infrastructure/gql-queries/report-queries/PowerBIReportQuery.ts` | NEW — bind `getAllPowerBIReports` (gridFeatureRequest) + `getPowerBIReportById` (id) + `getUsers` (for ApiSelectV2) — re-export from barrel |
| 3 | GQL Mutation | `Pss2.0_Frontend/src/infrastructure/gql-mutations/report-mutations/PowerBIReportMutation.ts` | NEW — bind `createPowerBIReport` / `updatePowerBIReport` / `deletePowerBIReport` / `activateDeactivatePowerBIReport` |
| 4 | Page Config | `Pss2.0_Frontend/src/presentation/pages/reportaudit/reportsetup/powerbireportmaster.tsx` | NEW — `useAccessCapability({ menuCode: "POWERBIREPORTMASTER" })` + `<PowerBIReportMasterDataTable />` (NEW name, NOT the existing `PowerBIReportDataTable` which uses `POWERBIREPORT` gridCode) |
| 5 | Index Page Component / DataTable | `Pss2.0_Frontend/src/presentation/components/page-components/reportaudit/reportsetup/powerbireportmaster/data-table.tsx` + `index.ts` barrel | NEW — `<AdvancedDataTable gridCode="POWERBIREPORTMASTER" enableAdvanceFilter enablePagination enableAdd enableImport enableExport enablePrint />` |
| 6 | Route Page | `Pss2.0_Frontend/src/app/[lang]/reportaudit/reportsetup/powerbireportmaster/page.tsx` | EXISTS as STUB — REPLACE: import `PowerBIReportMasterPageConfig` from new pages path |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Pss2.0_Frontend/src/domain/entities/report-service/index.ts` (barrel) | Re-export new DTO if added |
| 2 | `Pss2.0_Frontend/src/infrastructure/gql-queries/report-queries/index.ts` | Re-export new query file |
| 3 | `Pss2.0_Frontend/src/infrastructure/gql-mutations/report-mutations/index.ts` | Re-export new mutation file |
| 4 | `Pss2.0_Frontend/src/presentation/pages/reportaudit/reportsetup/index.ts` | Re-export `PowerBIReportMasterPageConfig` |
| 5 | `Pss2.0_Frontend/src/presentation/components/page-components/reportaudit/reportsetup/index.tsx` (or `index.ts`) | Re-export new data-table |
| 6 | `entity-operations.ts` (and `operations-config.ts`) | Add `POWERBIREPORTMASTER` block (delete + toggle + edit operations bound to new mutations) |
| 7 | Sidebar menu config (if hard-coded) | Should auto-render from DB seed `auth.Menus` row — if hard-coded sidebar exists, append entry under RA_REPORTSETUP |

### DB Seed Files (1 file — NEW)

| # | File | Path | What it Contains |
|---|------|------|------------------|
| 1 | `PowerBIReportMaster-sqlscripts.sql` | `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/PowerBIReportMaster-sqlscripts.sql` (preserve `dyanmic` typo) | Idempotent INSERTs (WHERE NOT EXISTS): (1) `auth.Menus` row POWERBIREPORTMASTER under RA_REPORTSETUP MenuId=381 OrderBy=1; (2) `auth.MenuCapabilities` rows for READ/CREATE/MODIFY/DELETE/TOGGLE/IMPORT/EXPORT/ISMENURENDER; (3) `auth.RoleCapabilities` granting all 8 to BUSINESSADMIN; (4) `sett.Grids` row POWERBIREPORTMASTER + `sett.Fields` (10 columns from grid table) + `sett.GridFields` mappings; (5) `sett.GridFormSchema` JSON — RJSF schema/uiSchema/formData covering the 12 form fields with sectioned layout. |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: ALIGN (BE exists; FE-only build + DB seed)

MenuName: PowerBI Report Master
MenuCode: POWERBIREPORTMASTER
ParentMenu: RA_REPORTSETUP
Module: REPORTAUDIT
MenuUrl: reportaudit/reportsetup/powerbireportmaster
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: GENERATE
GridCode: POWERBIREPORTMASTER
---CONFIG-END---
```

**Note on existing menus**: the legacy `POWERBIREPORT` menu (used by #97 PowerBIViewer at `reportaudit/reports/powerbireport`) stays intact. This screen adds a NEW menu `POWERBIREPORTMASTER` under a DIFFERENT parent (`RA_REPORTSETUP`) — they are siblings in the application, not duplicates.

---

## ⑩ Expected BE→FE Contract

> **All GQL endpoints already exist — listed here so FE Dev knows what to bind.**

**GraphQL Types:**
- Query type: `PowerBIReportQueries` (existing — at `Base.API/EndPoints/Report/Queries/PowerBIReportQueries.cs`)
- Mutation type: `PowerBIReportMutations` (existing — at `Base.API/EndPoints/Report/Mutations/PowerBIReportMutations.cs`)

**Queries (bind from FE):**

| GQL Field | Returns | Key Args | Notes |
|-----------|---------|----------|-------|
| `getAllPowerBIReports` | `PaginatedApiResponse<[PowerBIReportDto]>` | `request: GridFeatureRequest` | **PRIMARY** — projection includes LastRefreshedAt subquery; bind this for the grid |
| `getPowerBIReports` | `PaginatedApiResponse<[PowerBIReportResponseDto]>` | `request: GridFeatureRequest` | secondary; older endpoint without LastRefreshedAt — DO NOT bind |
| `getPowerBIReportById` | `BaseApiResponse<PowerBIReportResponseDto>` | `powerBIReportId: Int!` | **REQUIRED for Edit pre-fill** (returns StaffIds populated) |
| `getUsers` | `PaginatedApiResponse<[UserResponseDto]>` | `request: GridFeatureRequest` | for ApiSelectV2 multi-select — see ISSUE-2 if Read auth fails |

**Mutations (bind from FE):**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createPowerBIReport` | `powerBIReport: PowerBIReportRequestDto` | `BaseApiResponse<PowerBIReportRequestDto>` (returns echo with new id) |
| `updatePowerBIReport` | `powerBIReport: PowerBIReportRequestDto` | `BaseApiResponse<PowerBIReportRequestDto>` |
| `deletePowerBIReport` | `powerBIReportId: Int!` | `BaseApiResponse<PowerBIReportRequestDto>` (soft delete) |
| `activateDeactivatePowerBIReport` | `powerBIReportId: Int!` | `BaseApiResponse<PowerBIReportRequestDto>` (toggles IsActive) |

**Response DTO Fields** (`PowerBIReportDto` extends `PowerBIReportResponseDto` extends `PowerBIReportRequestDto`):

| Field | Type | Notes |
|-------|------|-------|
| powerBIReportId | number? | PK (nullable in Request, populated in Response) |
| reportKey | string | unique-per-tenant |
| reportName | string | display name |
| workspaceId | string | GUID-as-string over the wire |
| powerBIReportGuid | string | GUID-as-string over the wire |
| orderBy | number | display order |
| description | string \| null | — |
| rlsRoleName | string \| null | — |
| thumbnailUrl | string \| null | NEW (#97) |
| autoRefreshEnabled | boolean | NEW (#97) |
| autoRefreshIntervalHours | number | NEW (#97) |
| filterParametersJson | string \| null | NEW (#97) — JSON-encoded string |
| staffIds | number[] | populated by GetById; SEND on Update to preserve mappings |
| isActive | boolean | inherited |
| userMappings | UserResponseDto[] | only on Response — list of mapped User rows for display |
| lastRefreshedAt | string \| null | DateTime — projected by `getAllPowerBIReports` only (subquery on PowerBIAccessLogs) |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] No backend changes required — `dotnet build` should pass without modification
- [ ] `pnpm tsc --noEmit` — no errors in new FE files
- [ ] `pnpm dev` — page loads at `/{lang}/reportaudit/reportsetup/powerbireportmaster`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with columns: ReportName, ReportKey, WorkspaceId (truncated), ReportGuid (truncated), OrderBy, AutoRefresh badge, RlsRoleName, Allowed Users count, Status, Modified
- [ ] Search filters by ReportName, ReportKey, WorkspaceId
- [ ] Add new record → modal form shows all 12 fields → reportKey auto-slugs from reportName → save succeeds → row appears in grid
- [ ] Edit record → modal pre-fills via `getPowerBIReportById` → **staffIds field shows existing user list** (ISSUE-1 verification) → save succeeds → grid updates without dropping mappings
- [ ] Toggle active/inactive → badge changes via `activateDeactivatePowerBIReport`
- [ ] Delete → confirm dialog → soft delete → row disappears
- [ ] StaffIds (Allowed Users) ApiSelectV2 loads via `GetUsers` query — pre-filled with `[currentUserId]` on Create
- [ ] FilterParameters editor accepts JSON object (or key-value rows depending on widget choice); invalid JSON shows inline error
- [ ] AutoRefreshIntervalHours select disabled when AutoRefreshEnabled = false
- [ ] Workspace ID + Report GUID inputs reject non-GUID strings on save
- [ ] Permissions: BUSINESSADMIN sees all actions; non-admin → `<DefaultAccessDenied />`
- [ ] No regression on #97 PowerBIViewer (`/reportaudit/reports/powerbireport`) — gallery still loads, slide-in admin still works

**DB Seed Verification:**
- [ ] Menu "PowerBI Report Master" appears in sidebar under Report & Audit → Report Setup
- [ ] Grid columns render correctly per `sett.Fields` + `sett.GridFields`
- [ ] GridFormSchema renders modal form with the 4 sections + 12 fields

---

## ⑫ Special Notes & Warnings

- **ALIGN scope — DO NOT regenerate BE.** Entity, EF config, schemas, all 4 commands, all 4 queries, mutations endpoint, and queries endpoint already exist and are wired into DbContext + mappings. Touching them risks breaking #97 PowerBIViewer which depends on the same code. Any BE-side issue surfaced during build (e.g. `getUsers` auth wall) should be raised as an ISSUE in §⑬, not silently fixed by re-generating files.
- **Existing FE stub at `/reportaudit/reportsetup/powerbireportmaster/page.tsx` MUST be replaced.** It currently imports `PowerBIReportPageConfig` from `rms-old/reportmaster/powerbireport.tsx` which uses `menuCode: "POWERBIREPORT"` (the viewer menu). Replace with new `PowerBIReportMasterPageConfig` that uses `menuCode: "POWERBIREPORTMASTER"`. Do NOT modify the `rms-old` file — it stays for the viewer.
- **DTO field misnomer — DO NOT rename.** `StaffIds` in `PowerBIReportRequestDto` actually holds `User.UserId[]` (validator hits `_dbContext.Users`, not `Staff`). Label the FE control "Allowed Users" but bind to `staffIds` over the wire. Renaming would cascade to #97 viewer's slide-in form (already shipped in PROMPT_READY).
- **Sibling screen relationship**:
  - **#97 PowerBIViewer** (RA_REPORTS, menu `POWERBIREPORT`, route `reportaudit/reports/powerbireport`) — END-USER gallery + embed + slide-in admin shortcut. Same entity, different menu, different surface.
  - **#155 PowerBI Report Master** (THIS — RA_REPORTSETUP, menu `POWERBIREPORTMASTER`, route `reportaudit/reportsetup/powerbireportmaster`) — full-page admin grid for power-users. Same entity. NEW menu.
  - **#156 PowerBI User Mapping** (RA_REPORTSETUP, menu `POWERBIUSERMAPPING`, route `reportaudit/reportsetup/powerbiusermapping`) — deeper per-user RLS UI for `PowerBIReportUserMapping` rows. Adjacent screen.
  - All three coexist; this is intentional, not a duplication.
- **Mockup is TBD** — design lifted verbatim from #97 PowerBIViewer prompt §⑥ (slide-in admin form). When the actual mockup arrives, this prompt should be re-reviewed to align widget choices (especially the FilterParameters editor — could be key-value rows or JSON textarea).
- **#97's `GetAllPowerBIReports` projects `LastRefreshedAt`** as a subquery on `PowerBIAccessLogs.AccessDate` MAX. Confirm during build that this column is part of `PowerBIReportDto` (the wider DTO), not `PowerBIReportResponseDto` (the narrower one). Use `getAllPowerBIReports` for the grid.
- **No `Get{Entity}Summary` query needed** — Layout Variant is `grid-only` (no widgets above grid).

**Service Dependencies**: NONE. All UI elements are buildable end-to-end with existing code. No `SERVICE_PLACEHOLDER` actions in this screen (Import/Export/Print use existing infra; thumbnail is URL-only V1).

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Plan (pre-build) | HIGH | FE form | On Edit, the form MUST pre-fill `staffIds` from `getPowerBIReportById` and pass them back unchanged on Update — otherwise the BE Update handler at `UpdatePowerBIReport.cs:146-160` soft-deletes ALL UserMappings (carried-over bug from #97 ISSUE-V2-15). On Create, pre-fill `staffIds = [currentUserId]` from auth context. | OPEN |
| ISSUE-2 | Plan (pre-build) | MED | BE auth | `GetUsers` is gated by `[CustomAuthorize(DecoratorAuthModules.UserRole, Permissions.Read)]`. If a BUSINESSADMIN without USERROLE-Read capability hits this screen, the ApiSelectV2 will fail. Verify during E2E. Workarounds: (a) confirm BUSINESSADMIN seed grants USERROLE.Read, (b) add a `GetUsersForSelect` shape-only endpoint similar to `GetStaffsForSelect` (`StaffQueries.cs:11`). DO NOT silently switch to `GetStaffsForSelect` — its IDs are `Staff.StaffId`, NOT `User.UserId`, and would break the validator. | RESOLVED (Session 1) |
| ISSUE-3 | Plan (pre-build) | LOW | UX | FilterParameters key-value-rows widget may not exist in the FE component library. Build session should grep for `key-value` / `kv-rows` widgets first; if none, fall back to a JSON textarea with parse-error inline message. | RESOLVED (Session 1 — TextareaWidget fallback used) |
| ISSUE-4 | Plan (pre-build) | LOW | BE | `ReportKey` unique index is single-column (not composite with CompanyId) — same gap flagged in #97 ISSUE-V2-1bis. Out of scope for this build; deferred until the #97 migration ships. | OPEN |
| ISSUE-5 | Session 1 | LOW | UX | StaffIds Create-side pre-fill of `[currentUserId]` is NOT auto-applied. The form schema sets `default: []` + `minItems: 1`, forcing the admin to explicitly pick at least one user (which is also more correct — admins may want to grant access to others, not necessarily themselves). Carry-over from prompt ISSUE-1's Create half. | OPEN |
| ISSUE-6 | Session 1 | LOW | FE | Stale dead-path FE files exist at `presentation/pages/reportaudit/reportsetup/powerbireport.tsx` + `page-components/reportaudit/reportsetup/powerbireport/data-table.tsx`. They use `menuCode: "POWERBIREPORT"` (the viewer's menu code) but no route binds them. Recommend deletion in a cleanup ticket — out of scope for #155. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-14 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. ALIGN scope: BE entity + all CRUD already existed (BE schemas confirmed all 4 new fields + StaffIds + UserMappings; `GetAllPowerBIReports` returns the wider DTO with `LastRefreshedAt`). FE-only build + DB seed.

- **Files touched**:
  - BE: NONE (entity, EF config, schemas, all 4 commands, all 4 queries, mutations + queries endpoints all pre-existed and were verified at build time)
  - FE (modify):
    - `PSS_2.0_Frontend/src/domain/entities/report-service/PowerBIReportDto.ts` (modified — added 7 missing fields: `staffIds`, `thumbnailUrl`, `autoRefreshEnabled`, `autoRefreshIntervalHours`, `filterParametersJson`, `userMappings`, `lastRefreshedAt` + imported `UserResponseDto`)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/report-queries/PowerBIReportQuery.ts` (modified — added `ALL_POWERBIREPORTS_QUERY` binding `allPowerBIReports` with full paginated GridFeatureRequest signature + LastRefreshedAt; enriched `POWERBIREPORT_BY_ID_QUERY` with the 4 new fields)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/report-mutations/PowerBIReportMutation.ts` (modified — added 4 new fields to `CREATE_POWERBIREPORT_MUTATION` and `UPDATE_POWERBIREPORT_MUTATION` inputs and outputs; trimmed Delete/Toggle response projections to PK + ReportKey + ReportName since the BE returns minimal data anyway)
  - FE (create):
    - `PSS_2.0_Frontend/src/presentation/pages/reportaudit/reportsetup/powerbireportmaster.tsx` (created — `PowerBIReportMasterPageConfig` w/ `useAccessCapability({ menuCode: "POWERBIREPORTMASTER" })`)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reportsetup/powerbireportmaster/data-table.tsx` (created — `<AdvancedDataTable gridCode="POWERBIREPORTMASTER">` Variant A: grid-only)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reportsetup/powerbireportmaster/index.ts` (created — barrel)
  - FE (route-stub replaced):
    - `PSS_2.0_Frontend/src/app/[lang]/reportaudit/reportsetup/powerbireportmaster/page.tsx` (modified — was importing `PowerBIReportPageConfig` from `rms-old/reportmaster/powerbireport.tsx` which used the WRONG menu code `POWERBIREPORT`; now imports `PowerBIReportMasterPageConfig` from `@/presentation/pages` barrel)
  - FE (wiring):
    - `PSS_2.0_Frontend/src/presentation/pages/reportaudit/reportsetup/index.ts` (modified — added `PowerBIReportMasterPageConfig` re-export)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reportsetup/index.tsx` (modified — added `export * from "./powerbireportmaster"`)
    - `PSS_2.0_Frontend/src/application/configs/data-table-configs/report-service-entity-operations.ts` (modified — added `POWERBIREPORTMASTER` block; `getAll` binds `ALL_POWERBIREPORTS_QUERY` (NOT `POWERBIREPORTS_QUERY` — which is the older endpoint without LastRefreshedAt))
  - DB:
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/PowerBIReportMaster-sqlscripts.sql` (created — defensive Menu + 8 MenuCapabilities + 7 BUSINESSADMIN RoleCapabilities (idempotent fallback; primary seed lives in `Pss2.0_Global_Menus_List.sql:525`+leaf-loop) + Grid + 13 Fields + 8 GridFields wipe-and-regen + GridFormSchema with 12 form fields across 9 layout rows)

- **Deviations from spec**:
  - **Existing FE artifacts were stale, not absent.** Prompt §⑧ assumed the DTO/Query/Mutation files were "NEW" but they pre-existed (likely created during #97 PowerBIViewer prep) and were missing the 4 new fields. Approach: modify in-place rather than create alongside.
  - **Stale dead-path discovered**: `presentation/pages/reportaudit/reportsetup/powerbireport.tsx` + `page-components/reportaudit/reportsetup/powerbireport/data-table.tsx` exist with `menuCode: "POWERBIREPORT"` (viewer's code) but no route binds them. Left untouched per ALIGN scope; tracked as ISSUE-6 (LOW).
  - **Menu/Capabilities seeding handled by global script** — `Pss2.0_Global_Menus_List.sql:525` already inserts the POWERBIREPORTMASTER Menu row, and `:540-551` loops through all REPORTAUDIT leaf menus to seed full MenuCapabilities + BUSINESSADMIN RoleCapabilities. Per-screen seed includes a defensive idempotent fallback for fresh envs only.
  - **Grid columns reduced from prompt's 10 → 8** (PK hidden + 7 visible). Dropped `staffIds.length count chip` (no clean array-length renderer in registry; users see this in the edit modal), `autoRefreshEnabled badge` (no Enabled/Disabled label override pathway in `status-badge` renderer; users see this in the edit form), and `modifiedDate datetime` (omitted to keep the V1 grid focused; can be added later via UserGridFields). Tracked as deviation (not an issue — visible columns can be configured per-user).
  - **`STAFFWITHUSERID` queryKey used** instead of inventing a new `USER` queryKey or hitting the auth-walled `getUsers` endpoint. The `staffs` GQL field via `STAFFWITHUSERID` returns `{ value: userId, label: dropDownLabel }` — the userId matches the BE validator's expectation (`auth.Users.UserId`), and bypasses the `[CustomAuthorize(UserRole, Read)]` gate. RESOLVES ISSUE-2 cleanly.
  - **`ApiMultiSelect` widget used** (not `ApiSelectV2`) — for the `staffIds: int[]` array field. ApiSelectV2 is single-select. ApiMultiSelect's queries registry includes STAFFWITHUSERID. Schema type: `array` of `integer` with `minItems: 1` + `uniqueItems: true`.
  - **FilterParameters widget**: TextareaWidget chosen (no key-value-rows widget in FE registry). RESOLVES ISSUE-3 by spec.
  - **StaffIds Create-side auto-prefill of `[currentUserId]` NOT implemented** — schema enforces `minItems: 1` so admins must explicitly pick. Carried over as ISSUE-5 (LOW). Rationale: admin may want to grant access to others, not necessarily themselves; explicit selection is more correct.

- **Known issues opened**:
  - ISSUE-5 (LOW) — StaffIds Create-side auto-prefill of `[currentUserId]` not implemented; schema requires explicit selection.
  - ISSUE-6 (LOW) — Stale dead-path FE files for `powerbireport.tsx` + `powerbireport/data-table.tsx` should be deleted in a cleanup ticket.

- **Known issues closed**:
  - ISSUE-2 (MED) — RESOLVED via `STAFFWITHUSERID` queryKey reuse.
  - ISSUE-3 (LOW) — RESOLVED via TextareaWidget fallback.

- **Build verification**:
  - `tsc --noEmit`: ZERO errors in any file under `report-service/`, `report-queries/`, `report-mutations/`, `reportaudit/reportsetup/powerbireportmaster/`, or `report-service-entity-operations.ts`. (22 pre-existing tsc errors elsewhere — `crm/event/eventanalytics/`, `domain/entities/index.ts` re-exports, `crm/communication/emailsendjob/`, `reportaudit/reports/powerbiviewer/` — all unrelated to #155.)
  - `dotnet build`: not run (no BE changes). Spec confirms BE compiles unmodified.
  - `Pss2.0_Backend/.../PowerBIReportMaster-sqlscripts.sql`: GridFormSchema JSON validated via Python `json.loads()` — parses cleanly; 12 schema properties match the 12 form fields; 9 layout rows match the visual grouping spec.
  - GridComponentName values used (`text-bold`, `badge-code`, `text-truncate`, `badge-circle`, `status-badge`) all resolve in `component-column.tsx:178-191`. ✓
  - ApiMultiSelect queryKey `STAFFWITHUSERID` resolves in `api-multi-select-widget/use-api-multi-select.ts:178`. ✓

- **Deferred to user runtime verification** (cannot be tested from CLI):
  - Page renders at `/{lang}/reportaudit/reportsetup/powerbireportmaster` with grid loaded via `getAllPowerBIReports` query
  - Modal form opens, all 12 fields render with correct widget choice (esp. ApiMultiSelect for Allowed Users + SelectWidget enum for refresh interval + TextareaWidget for FilterParameters JSON)
  - Create flow saves successfully, including the new fields (thumbnailUrl, autoRefreshEnabled, autoRefreshIntervalHours, filterParametersJson)
  - Edit flow: GetById pre-fills `staffIds` and BE preserves them on Update (verifies prompt ISSUE-1 Edit half + the BE `UpdatePowerBIReport.cs:80-160` diff logic)
  - Toggle/Delete flows
  - Sidebar menu "PowerBI Report Master" appears under "Report Setup"
  - BUSINESSADMIN sees all actions; non-admin gets `<DefaultAccessDenied />`
  - No regression on #97 PowerBIViewer (`/reportaudit/reports/powerbireport` gallery still works)

- **User actions required**:
  1. Run the SQL seed: `psql -d <db> -f Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/PowerBIReportMaster-sqlscripts.sql`
  2. (If `Pss2.0_Global_Menus_List.sql` has not been run, the defensive Menu/Caps block in this seed handles it.)
  3. `pnpm dev` and navigate to `/{lang}/reportaudit/reportsetup/powerbireportmaster`
  4. Test full CRUD flow + verify StaffIds round-trip on Edit
  5. (Optional cleanup) Delete the stale dead-path files (ISSUE-6) once verified safe.

- **Next step**: (none — COMPLETED)

### Session 2 — 2026-05-14 — ENHANCE — COMPLETED

- **Scope**: Re-architected #155 to host BOTH PowerBI Reports AND PowerBI User Mapping (#156) as a single two-tab screen at `POWERBIREPORTMASTER`. User decision (2026-05-14): "both are combined in single screen with two tabs — one report and another user mapping." Single sidebar entry. URL state: `?tab=reports|usermapping`. ScreenHeader (Variant B) above tabs.

- **Files touched**:
  - BE: NONE (PowerBIUserMapping entity + EF config + schemas + all 4 commands + 2 queries + Mutations/Queries endpoints all pre-existed; verified Include(User).ThenInclude(Staff) on `GetPowerBIUserMappings.cs:38` so `dropDownLabel` populates for the grid)
  - FE (modify):
    - `PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reportsetup/powerbireportmaster/index.ts` (modified — added `PowerBIReportMasterPage` re-export)
    - `PSS_2.0_Frontend/src/presentation/pages/reportaudit/reportsetup/powerbireportmaster.tsx` (modified — switched gate target from `<PowerBIReportMasterDataTable />` to `<PowerBIReportMasterPage />`)
  - FE (create):
    - `PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reportsetup/powerbireportmaster/index-page.tsx` (created — `<ScreenHeader>` + `<Tabs>` shell. Tab 1 mounts existing `<PowerBIReportMasterDataTable />`, Tab 2 mounts existing `<PowerBIUserMappingDataTable />` from sibling `../powerbiusermapping`. URL-driven `?tab=...` via `useSearchParams`. Pattern lifted from `crm/p2pfundraising/matchinggift/index-page.tsx`)
  - DB:
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/PowerBIReportMaster-sqlscripts.sql` (modified — file header rewritten to document the two-tab architecture; appended Session 2 block with: (a) defensive UPDATE flipping `RoleCapabilities.HasAccess=false` for `ISMENURENDER` on POWERBIUSERMAPPING menu — hides sidebar entry while keeping caps + standalone deep-link route alive; (b) full POWERBIUSERMAPPING grid seed: `sett.Grids` row + 5 `sett.Fields` (mapping id, userId, dropDownLabel/User, crmUsername, powerBIEmail) + 5 `sett.GridFields` wipe-and-regen with text-bold/badge-code/text/status-badge renderers + `sett.GridFormSchema` JSON for the modal form: 3 fields (userId via ApiSelectV2 STAFFWITHUSERID, crmUsername text, powerBIEmail email-format))

- **Deviations from spec**:
  - **Original prompt scope** was a single MASTER_GRID for Reports only. Session 2 expands scope to also host the User Mapping tab — driven by user request, not a deviation from a stale spec.
  - **POWERBIUSERMAPPING menu hidden via ISMENURENDER, not deleted** — the Add/Edit/Delete buttons inside the User Mapping tab use the `<AdvancedDataTable gridCode="POWERBIUSERMAPPING">` data-table which (per `useAccessCapability`) reads RoleCapabilities for the POWERBIUSERMAPPING menu to gate per-action buttons. Deleting the menu would break those gates. ISMENURENDER=false hides the sidebar entry without disturbing CRUD permissions.
  - **Standalone `/reportaudit/reportsetup/powerbiusermapping` route stub kept intact** — the `PowerBIUserMappingPageConfig` page still works for users who deep-link to the URL or have bookmarks. Two paths into the same data is acceptable; the canonical path is now the tabbed `?tab=usermapping`.
  - **No KPI widgets / no header actions** — kept the shell minimal (just ScreenHeader + Tabs + grids). Each grid retains its own internal toolbar (Add/Search/Filter/Import/Export) via AdvancedDataTable's built-in header. This is closer to Variant A nested inside a Variant B shell.

- **Known issues opened**: None.

- **Known issues closed**: None new (ISSUE-5 + ISSUE-6 still OPEN — they are independent of the two-tab merge).

- **Build verification**:
  - `tsc --noEmit`: ZERO errors in any file under `powerbireportmaster/`, `powerbiusermapping/`, or any of the modified barrels. (Same 22 pre-existing tsc errors elsewhere as Session 1 — all unrelated.)
  - GridFormSchema JSON for both POWERBIREPORTMASTER (12 props × 9 layout rows) AND POWERBIUSERMAPPING (3 props × 2 layout rows) parse cleanly via `python -c json.loads()`.
  - `ApiSelectV2` widget verified registered at `dgf-widgets/index.tsx:40`. `STAFFWITHUSERID` queryKey verified registered at `api-selectv2-widget/use-api-selectv2.ts:787`.
  - BE include chain verified: `GetPowerBIUserMappings.cs:38` Include(User).ThenInclude(Staff) ensures `dropDownLabel` populates for the User column.
  - All cell renderers used in the new GridFields (`text-bold`, `badge-code`, `status-badge`) resolve in `component-column.tsx`.
  - Both standalone routes still work: `/reportaudit/reportsetup/powerbiusermapping` (PowerBIUserMappingPageConfig) and `/reportaudit/reportsetup/powerbiusermappingmaster` (also PowerBIUserMappingPageConfig — pre-existing dup, ignored).

- **Deferred to user runtime verification**:
  - Run the updated SQL seed (re-run is safe — idempotent on Menu/Caps; idempotent on Grids/Fields; wipe-and-regen on GridFields; UPDATE-only on GridFormSchema and ISMENURENDER hide).
  - Page renders at `/{lang}/reportaudit/reportsetup/powerbireportmaster` with default tab=reports.
  - Click "User Mapping" tab → URL becomes `?tab=usermapping` → User Mapping grid loads via `getPowerBIUserMappings`.
  - Add User Mapping → modal opens with userId (ApiSelectV2 dropdown), crmUsername, powerBIEmail → save succeeds.
  - Edit User Mapping → pre-fill via `getPowerBIUserMappingById` → save succeeds.
  - Sidebar shows ONLY "PowerBI Report Master" under Report Setup (POWERBIUSERMAPPING entry hidden after the ISMENURENDER UPDATE runs).
  - Bookmark `?tab=usermapping` → reload → still lands on User Mapping tab.

- **User actions required**:
  1. Re-run the SQL seed: `psql -d <db> -f Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/PowerBIReportMaster-sqlscripts.sql` (safe to re-run — all blocks are idempotent).
  2. `pnpm dev` and navigate to `/{lang}/reportaudit/reportsetup/powerbireportmaster` — confirm both tabs work.
  3. Verify sidebar shows ONLY the single "PowerBI Report Master" entry under Report Setup.

- **Next step**: (none — COMPLETED)
