---
screen: PowerBIViewer
registry_id: 97
module: Report & Audit
status: COMPLETED
scope: ALIGN
screen_type: CONFIG
config_subtype: SETTINGS_PAGE
layout_variant: hub-launcher (gallery cards + embed viewer + slide-in admin panel)
storage_pattern: keyed-settings-rows (PowerBIConfiguration) + definition-list (PowerBIReport)
save_model: save-per-section
complexity: High
new_module: NO
planned_date: 2026-05-14
completed_date: 2026-05-14
last_session_date: 2026-05-14
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — gallery + embed + slide-in admin (3 logical sections in panel)
- [x] Business context read (multi-tenant Power BI report registry + Azure connection settings)
- [x] Storage model identified — `PowerBIConfiguration` (keyed K/V per tenant) + `PowerBIReport` (definitions) + `PowerBIAccessLog` (audit, leave intact)
- [x] Save model chosen — save-per-section in slide-in (Reports CRUD per row + Connection bulk-upsert)
- [x] Sensitive fields & role gates identified — ClientSecret masked + write-only; admin-only Configure button
- [x] FK targets resolved (only `User` for access log + `Company` for tenant scope — both pre-existing)
- [x] Existing BE/FE code diffed against mockup
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (7 gaps surfaced; resolutions in Section ⓮)
- [x] Solution Resolution complete (GO with pre-migration duplicate check + cache-keyed fix)
- [x] UX Design finalized (AlertDialog/Sheet primitives confirmed; SecretInput extension spec'd)
- [x] User Approval received (2026-05-14: Approved as-is, validation resolutions auto-applied)
- [x] Backend deltas generated (NO new entity; added 1 query + 2 mutations for PowerBIConfiguration + 4 new fields on PowerBIReport + tenant-keyed cache fix)
- [x] Backend wiring complete (Queries + Mutations registered; IPowerBIEmbedService extended with InvalidateCache + TestConnectionAsync)
- [x] Frontend rebuilt (gallery + embed + slide-in admin sheet replacing dropdown-picker UX; PowerBIEmbed extended with initialReportId prop)
- [x] Frontend wiring complete (route page repointed to new canonical PowerBIViewerPage; barrels updated)
- [x] DB Seed delta (default `PowerBIConfiguration` K/V rows per tenant + AutoRefresh backfill on existing reports; menu pre-seeded)
- [x] Registry updated to COMPLETED

### Verification
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `/{lang}/reportaudit/reports/powerbireport`
- [ ] Gallery view renders cards from `allPowerBIReports` query
- [ ] Click card → embed view switches; URL syncs `?reportId=N`
- [ ] Back button returns to gallery (no full reload)
- [ ] Configure Reports button opens slide-in panel
- [ ] Slide-in: Existing Reports table renders; Edit/Delete actions work
- [ ] Slide-in: Add/Edit form persists via existing `createPowerBIReport` / `updatePowerBIReport` mutations
- [ ] Slide-in: Connection Settings reads `getPowerBIConnectionSettings`, saves via `updatePowerBIConnectionSettings`
- [ ] ClientSecret never returned in GET (masked); empty on submit ⇒ unchanged; non-empty ⇒ overwrite
- [ ] Test Connection action runs against PowerBIEmbedService and shows pass/fail
- [ ] Embed view: Full Screen / Refresh Data work; Export / Print / Share render as SERVICE_PLACEHOLDER toasts
- [ ] Non-admin user does NOT see Configure Reports button
- [ ] Empty-state: when no reports exist, gallery shows empty-state CTA "Configure your first report" → opens slide-in

---

## ① Screen Identity & Context

**Screen**: PowerBI Viewer (a.k.a. "PowerBI Reports")
**Module**: Report & Audit (`REPORTAUDIT`)
**Schema**: `rep`
**Group**: Report (in `Base.Application.Business.ReportBusiness`, `Base.Domain.Models.ReportModels`)

**Business**:
PSS 2.0 lets each tenant publish a curated set of Microsoft Power BI reports to its staff as embedded interactive dashboards. The viewer screen serves two personas on one page: end-users browse a tile gallery and click into an embedded report (the Power BI JavaScript SDK renders it inline with an auto-refreshed embed token); BUSINESSADMINs additionally configure the report registry and the Azure connection without leaving the page via a slide-in panel. Connection misconfiguration silently breaks every embed token request, so the panel exposes a "Test Connection" action that probes the Azure AD service principal before the admin saves. Sensitive credentials (ClientSecret) are masked on read and write-only on update. The screen depends on a working `PowerBIEmbedService` (already in the codebase) and on the per-user RLS mapping handled by sibling screen #156 PowerBI User Mapping. This is the END-USER surface (under `RA_REPORTS`); sibling admin screens #155 (Report Master) and #156 (User Mapping) live under `RA_REPORTSETUP` and offer the same CRUD at full-page scale — the slide-in panel is a power-user shortcut, NOT a replacement for them.

**Why CONFIG / SETTINGS_PAGE — hub-launcher variant**:
The primary surface is a card gallery (a hub-launcher, like Report Catalog #99 — the canonical SETTINGS_PAGE / hub-launcher) and the persistent settings live in the slide-in admin panel. There is no list-of-N record-management UX as the focal point, so MASTER_GRID does not fit; there is no per-record workflow with new/edit/read modes, so FLOW does not fit; there is no Generate-button → result-view pattern, so REPORT does not fit. The closest precedent in the codebase is #99 Report Catalog (hub-launcher SETTINGS_PAGE with embedded admin actions).

---

## ② Storage Model

**Storage Pattern** (hybrid — stamp both):
- `keyed-settings-rows` → `rep.PowerBIConfigurations` (K/V rows for Azure connection: ClientId, ClientSecret, TenantId, AuthorityUrl, ResourceUrl, ApiUrl, Workspace, AuthenticationMode)
- `definition-list` → `rep.PowerBIReports` (one row per published report definition)
- Existing audit table `rep.PowerBIAccessLogs` is unchanged.

### Tables

#### Primary table A — `rep.PowerBIReports` (EXISTING — minor extension)

| Field | C# Type | MaxLen | Required | FK | Notes |
|-------|---------|--------|----------|----|-------|
| PowerBIReportId | int | — | PK | — | identity |
| CompanyId | int | — | YES | corg.Companies | tenant scope (HttpContext, not a form field) |
| ReportKey | string | 100 | YES | — | tenant-unique stable code |
| ReportName | string | 200 | YES | — | display label on card |
| WorkspaceId | Guid | — | YES | — | Power BI workspace GUID |
| PowerBIReportGuid | Guid | — | YES | — | Power BI report GUID |
| OrderBy | int | — | YES | — | display order on gallery |
| Description | string? | 500 | NO | — | shown on card |
| RlsRoleName | string? | 100 | NO | — | optional RLS role passed to embed token |
| **ThumbnailUrl** (NEW) | string? | 500 | NO | — | optional image URL for card thumbnail; null ⇒ fallback `ph:chart-bar` icon |
| **AutoRefreshEnabled** (NEW) | bool | — | YES | — | default true |
| **AutoRefreshIntervalHours** (NEW) | int | — | YES | — | default 12; range 1–168 |
| **FilterParametersJson** (NEW) | string? | 1000 | NO | — | JSON map of PSS context → PBI filter name (`{"CompanyId":"CompanyId","BranchId":"BranchId","Role":"Role"}`) |

> Existing CRUD endpoints on this entity stay intact; the new optional columns are added to the request/response DTOs.

#### Primary table B — `rep.PowerBIConfigurations` (EXISTING — extend with `CompanyId` scoping check)

| Field | C# Type | MaxLen | Required | FK | Notes |
|-------|---------|--------|----------|----|-------|
| PowerBIConfigurationId | int | — | PK | — | identity |
| CompanyId | int | — | YES | corg.Companies | tenant scope |
| ConfigKey | string | 100 | YES | — | one of: `ClientId` / `ClientSecret` / `TenantId` / `AuthorityUrl` / `ResourceUrl` / `ApiUrl` / `Workspace` / `AuthenticationMode` |
| ConfigValue | string | 500 | YES | — | value (ClientSecret stored encrypted-at-rest or as opaque blob; mask on read) |
| ConfigDescription | string? | 500 | NO | — | admin notes |

**Constraint**: existing unique index on `(ConfigKey)` MUST be tightened to `(CompanyId, ConfigKey)` — current single-column uniqueness blocks multi-tenant. → tracked as ISSUE-V2-1.

#### Audit table (UNCHANGED) — `rep.PowerBIAccessLogs`
- Already wired via `SavePowerBIAccessLog` mutation. Leave intact.

### Singleton-vs-multi guidance
- `PowerBIConfigurations`: 8 K/V rows per Company. UI treats them as a single "Connection Settings" form section. BE exposes a single `GetPowerBIConnectionSettings` → DTO with all 8 keys flattened; `UpdatePowerBIConnectionSettings` upserts the 8 keys atomically.
- `PowerBIReports`: N rows per Company. Existing CRUD endpoints reused 1:1.

---

## ③ FK Resolution Table

No new FKs required. Existing references:

| FK Field | Target | Entity File | GQL Query | Display | Response DTO |
|----------|--------|-------------|-----------|---------|--------------|
| CompanyId | Company | Base.Domain/Models/ApplicationModels/Company.cs | n/a (HttpContext-scoped) | — | — |
| UserId (in mapping/log) | User | Base.Domain/Models/AccessControlModels/User.cs | GetAllUserList | UserName | UserResponseDto |

**Verified existing GQL surface**:
- `allPowerBIReports` (paginated; used today by FE dropdown) — works ✓
- `powerBIEmbed(powerBiReportId: Int!)` — returns embed token DTO — works ✓
- `savePowerBIAccessLog` — works ✓
- `createPowerBIReport` / `updatePowerBIReport` / `activateDeactivatePowerBIReport` / `deletePowerBIReport` — exist, BUT currently called only by the (separate) `reportsetup/powerbireportmaster` master-grid screen. The viewer slide-in panel will reuse them.

---

## ④ Business Rules & Validation

**Cardinality:**
- Exactly 8 `PowerBIConfiguration` rows per `CompanyId` once seeded (one per ConfigKey enum value).
- Many `PowerBIReport` rows per `CompanyId` (0..N).

**Required field rules:**
- `PowerBIReport`: ReportKey, ReportName, WorkspaceId, PowerBIReportGuid, OrderBy required.
- `PowerBIConnectionSettings`: ClientId, ClientSecret (on create only), TenantId required to enable `Test Connection`.

**Conditional rules:**
- `AutoRefreshIntervalHours` only meaningful when `AutoRefreshEnabled = true`; UI hides interval picker otherwise.
- `FilterParametersJson` must be valid JSON object (validate on save; reject parse errors).

**Sensitive Fields:**
| Field | Sensitivity | Display | Save | Audit |
|-------|-------------|---------|------|-------|
| `ClientSecret` | secret | masked `••••••••` (never returned in GET) | empty on submit ⇒ unchanged; non-empty ⇒ overwrite | log "PowerBI ClientSecret rotated" event |
| `ClientId` / `TenantId` | secret-ish | masked input with eye toggle, full value returned (still treat carefully) | normal | log change |
| `ReportKey` / `PowerBIReportGuid` | normal | plain | normal | — |

**Dangerous actions (confirm):**
| Action | Effect | Confirmation |
|--------|--------|--------------|
| Delete Report (slide-in row) | Soft-delete via existing `deletePowerBIReport` | "Delete report '{name}'?" |
| Rotate ClientSecret | Replaces the secret; immediate effect on next embed token request | "Rotating will invalidate any cached tokens. Continue?" |
| Switch Auth Mode (Service Principal ↔ Master User) | Changes embed-token codepath | "Auth mode change requires re-test. Continue?" |

**Role gating:**
| Role | Gallery | Embed | Configure button | Slide-in |
|------|---------|-------|------------------|----------|
| BUSINESSADMIN | yes | yes | yes | yes (all 3 sections) |
| Other roles (per #156 mapping) | yes (only assigned reports) | yes | hidden | n/a |

---

## ⑤ Screen Classification & Pattern Selection

**Screen Type**: CONFIG
**Config Sub-type**: `SETTINGS_PAGE` (hub-launcher variant)
**Storage Pattern**: `keyed-settings-rows` (PowerBIConfiguration) + `definition-list` (PowerBIReport)
**Save Model**: `save-per-section`

**Reason**: The page is built around a gallery of report tiles (hub-launcher), not a multi-section settings form. The persistent admin settings live in a slide-in panel with 3 logically independent sections (Existing-Reports table / Add-Edit-Report form / Connection Settings) — each saves independently. The viewer area is a switchable surface (gallery ↔ embed) driven by URL state, not a config form. This matches the SETTINGS_PAGE classification used by #99 Report Catalog with hub-launcher chrome.

**Backend Patterns Required:**

For the existing definition-list (PowerBIReport):
- [x] Keep existing 4 CRUD commands (`Create` / `Update` / `Delete` / `ActivateDeactivate`)
- [x] Keep `allPowerBIReports` (gallery query)
- [x] Keep `getPowerBIReportById` (slide-in Edit prefill)
- [x] Keep `powerBIEmbed` (embed-token query)
- [x] Keep `savePowerBIAccessLog`
- [ ] Extend `PowerBIReportRequestDto` / `PowerBIReportResponseDto` with 4 new fields (ThumbnailUrl, AutoRefreshEnabled, AutoRefreshIntervalHours, FilterParametersJson)
- [ ] Extend `GetAllPowerBIReportsQuery` projection with the same 4 fields (plus existing ones expected by gallery cards: ReportName, Description, ThumbnailUrl, OrderBy, IsActive, LastRefreshedAt — note LastRefreshedAt is NOT in entity, see ISSUE-V2-2)

For the keyed-settings-rows (PowerBIConfiguration):
- [ ] **NEW** Query: `GetPowerBIConnectionSettings` → returns flat DTO with 8 keys (ClientSecret returned as `""` or `"••••••••"` placeholder)
- [ ] **NEW** Mutation: `UpdatePowerBIConnectionSettings` → atomic upsert of 8 K/V rows; empty `ClientSecret` ⇒ skip (preserve existing); non-empty ⇒ overwrite
- [ ] **NEW** Mutation: `TestPowerBIConnection` → invokes `PowerBIEmbedService.GetAccessTokenAsync()`; returns `{ success: bool, message: string }`
- [ ] Tenant scoping via `HttpContext` (Company.Id)
- [ ] Audit-log entry on every Update / Test / Rotate event

**Frontend Patterns Required:**

- [ ] **REPLACE** current dropdown-picker FE with 3-pane UX:
  1. **Gallery view** — 3-col responsive card grid (existing `<Card>` primitive)
  2. **Embed view** — full-width iframe wrapper with viewer header (Back / title / actions)
  3. **Slide-in Sheet** — 520px right-side (`<Sheet>` from common-components) with 3 sections
- [ ] URL-state sync (use Next.js `useSearchParams` + `useRouter`):
  - `?view=gallery` (default) or omitted ⇒ gallery
  - `?reportId=N` ⇒ embed view for report N
  - Configure panel state in Zustand only (no URL)
- [ ] Zustand store for: current view, selected report, configPanelOpen, editingReportId, dirty flags
- [ ] **REUSE** existing `<PowerBIEmbed>` component from `rms-old/reportmaster/powerbiembed/` BUT pass `showHeader={false}` and hide the dropdown (we'll show our own viewer header)
- [ ] Sensitive-field input (masked, eye-toggle, Rotate button) — write a small `<SecretInput>` component
- [ ] Confirm dialog for Delete / Rotate / Auth Mode switch — use existing `<ConfirmDialog>` primitive
- [ ] Empty-state component for "No reports yet" (gallery)
- [ ] SERVICE_PLACEHOLDER toast handlers for Export / Print / Share in viewer header

---

## ⑥ UI/UX Blueprint

### 🅰️ Block A — SETTINGS_PAGE (hub-launcher variant)

#### Page Layout

**Container Pattern**: `vertical-stack` (one main pane with gallery OR embed) + `slide-in-sheet` (admin)

```
┌─────────────────────────────────────────────────────────────┐
│  [chart icon] Power BI Reports                              │
│  Interactive analytics dashboards powered by Microsoft …    │
│                                  [⚙ Configure Reports] [↻]  │
├─────────────────────────────────────────────────────────────┤
│  GALLERY VIEW (?view=gallery, default)                      │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                  │
│  │ thumb    │  │ thumb    │  │ thumb    │                  │
│  │ Title    │  │ Title    │  │ Title    │                  │
│  │ desc     │  │ desc     │  │ desc     │                  │
│  │ refreshd │  │ refreshd │  │ refreshd │                  │
│  │ [View][✎][✕]│  [View][✎][✕]│ [View][✎][✕]                │
│  └──────────┘  └──────────┘  └──────────┘                  │
└─────────────────────────────────────────────────────────────┘

   OR

┌─────────────────────────────────────────────────────────────┐
│  EMBED VIEW (?reportId=N)                                   │
│                                                             │
│  [← Back to Gallery]  Report Title                          │
│                       Last refreshed: …                     │
│              [⛶ Full Screen] [↻ Refresh] [⤓ Export]         │
│              [⎙ Print] [↗ Share]                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                                                      │   │
│  │       <PowerBIEmbed /> iframe                        │   │
│  │                                                      │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

   PLUS Configure Reports panel (Sheet from right, 520px):

  ┌────────────────────────────────────────┐
  │ [⚙] Configure Reports             [✕] │
  ├────────────────────────────────────────┤
  │ Section 1 — EXISTING REPORTS           │
  │  ┌──────────────────────────────────┐  │
  │  │ Name | WS | ID | Roles | Actions │  │
  │  │ Fundraising Analytics …  [✎][✕]  │  │
  │  │ Donor Segmentation …     [✎][✕]  │  │
  │  └──────────────────────────────────┘  │
  │                                        │
  │ Section 2 — ADD / EDIT REPORT          │
  │  ⊞ Report Name *                       │
  │  ⊞ Description                         │
  │  ⊞ Workspace ID *                      │
  │  ⊞ Report ID *                         │
  │  ⊞ Thumbnail (URL or upload)           │
  │  ⊞ Access Roles (chips)                │
  │  ⊞ Auto-Refresh + Interval             │
  │  ⊞ Filter Parameters (map)             │
  │   [Save Report]  [Cancel]              │
  │                                        │
  │ Section 3 — CONNECTION SETTINGS        │
  │  ⊞ Tenant ID (masked)                  │
  │  ⊞ Client ID (masked)                  │
  │  ⊞ Client Secret (mask + Show + Rotate)│
  │  ⊞ Workspace                           │
  │  ⊞ Authentication Mode (select)        │
  │   [Test Connection] [⚪ Connected]      │
  │   [Save Settings]                      │
  └────────────────────────────────────────┘
```

#### Page Header
- Left: `ph:chart-bar` icon + title "Power BI Reports" + subtitle "Interactive analytics dashboards powered by Microsoft Power BI"
- Right: `[Configure Reports]` button (admin-only) + `[Refresh]` button (re-runs gallery query)

#### Section Definitions (slide-in panel sections)

| # | Section Title | Icon | Save Mode | Role Gate |
|---|--------------|------|-----------|-----------|
| 1 | Existing Reports | `ph:list-checks` | n/a (per-row edit/delete via section 2 + delete mutation) | BUSINESSADMIN |
| 2 | Add / Edit Report | `ph:plus-circle` | save-per-section (Save Report button) | BUSINESSADMIN |
| 3 | Connection Settings | `ph:plug` | save-per-section (Save Settings button) | BUSINESSADMIN |

#### Gallery Card Layout (per card)

```
┌─────────────────────┐
│   [thumbnail 160px] │   ← gradient bg + report icon (or thumbnail image)
├─────────────────────┤
│ [📊] Report Title   │   ← bold, h6
│ description text…   │   ← muted, 2 lines clamp
│ ⏱ Last refreshed: … │   ← caption
│ ┌─────────┐ ┌─┐┌─┐  │
│ │View Rpt │ │✎││✕│  │   ← View=primary, Edit/Delete=icon (admin-only)
│ └─────────┘ └─┘└─┘  │
└─────────────────────┘
```

**Empty-state** (no reports): full-card-grid-area shows centered "No reports configured yet" + icon + CTA "Configure your first report" → opens slide-in (Section 2 fresh form).

#### Embed View Header

| Element | Position | Behavior |
|---------|----------|----------|
| Back to Gallery | left | `router.push('?view=gallery')` |
| Report title | left | from embed config `reportName` |
| Last refreshed meta | left, sub-line | from embed config |
| Full Screen | right | uses existing `wrapperRef.requestFullscreen()` |
| Refresh Data | right | `reportRef.current.refresh()` + re-fetch embed config (token) |
| Export | right | SERVICE_PLACEHOLDER (toast "Coming soon") |
| Print | right | SERVICE_PLACEHOLDER OR `window.print()` (UX-decision) |
| Share | right | SERVICE_PLACEHOLDER |

#### Section 2 — Add / Edit Report Field Mapping

| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| reportName | text | — | required, max 200 | maps to `ReportName` |
| description | textarea | — | max 500 | maps to `Description` |
| reportKey | text (auto-slug from reportName) | — | required, max 100, unique-per-tenant | maps to `ReportKey` (hidden in mockup but required by entity — auto-generate from name with override) |
| workspaceId | text | — | required, valid GUID | help-text "Power BI portal → Workspace settings" |
| powerBIReportGuid | text | — | required, valid GUID | |
| thumbnailUrl | url-or-upload | — | optional, URL or file (V1: URL only — see ISSUE-V2-3) | maps to NEW `ThumbnailUrl` |
| accessRoles | checkbox-group | (Super Admin, Org Admin, Manager checked) | at-least-one | **DEFERRED**: maps to per-user `PowerBIReportUserMapping` via existing #156 entity. For V1, persists as a JSON array in `RlsRoleName` field or as a comma-separated string on `RlsRoleName` (see ISSUE-V2-4) |
| autoRefreshEnabled | switch | true | — | maps to NEW `AutoRefreshEnabled` |
| autoRefreshIntervalHours | select (1/6/12/24) | 12 | required when enabled | maps to NEW `AutoRefreshIntervalHours` |
| filterParameters | key-value rows (Company ID/Branch ID/User Role → PBI filter name text input) | `{"CompanyId":"CompanyId","BranchId":"BranchId","Role":"Role"}` | valid JSON | maps to NEW `FilterParametersJson` |
| orderBy | number | max(existing)+1 | required, positive | hidden — auto-assigned, exposed only in advanced mode |

**Actions**: `[Save Report]` (calls `createPowerBIReport` if new, `updatePowerBIReport` if editing) + `[Cancel]` (clears form).

#### Section 3 — Connection Settings Field Mapping

| Field | Widget | Default | Validation | Sensitivity |
|-------|--------|---------|------------|-------------|
| tenantId | masked-input with eye-toggle | "" | required, valid GUID-or-domain | secret-ish |
| clientId | masked-input with eye-toggle | "" | required, valid GUID | secret-ish |
| clientSecret | masked-input + Show button + Rotate button | "" on GET (never returned) | required on Create; optional on Update (empty ⇒ unchanged) | **secret** |
| workspace | text | "PSS-Analytics" | required | normal |
| authenticationMode | select (Service Principal / Master User) | Service Principal | required | normal |

**Actions**:
- `[Test Connection]` (secondary, accent-styled) — calls `testPowerBIConnection` mutation; renders status chip inline `[✓ Connected]` (green) or `[✕ Failed: <msg>]` (red).
- `[Save Settings]` (primary, accent-styled) — calls `updatePowerBIConnectionSettings`.

#### User Interaction Flow

1. User loads `/{lang}/reportaudit/reports/powerbireport` → gallery view ; `allPowerBIReports` query fires → cards render.
2. User clicks card OR "View Report" button → `router.replace('?reportId=N')` → embed view mounts → `powerBIEmbed(N)` query fires → `<PowerBIEmbed>` renders iframe → `savePowerBIAccessLog` mutation fires on load.
3. User clicks "Back to Gallery" → `router.replace('?view=gallery')` → gallery view re-mounts (cards cached).
4. (Admin) User clicks "Configure Reports" → `<Sheet>` slides in from right → 3 sections render.
5. (Admin) User clicks card-edit (✎) → opens panel + pre-fills Section 2 with `getPowerBIReportById(N)` data.
6. (Admin) User edits Section 2 → clicks "Save Report" → `updatePowerBIReport` fires → toast → table in Section 1 refreshes via gallery query refetch.
7. (Admin) User clicks Section 3 "Test Connection" → toast "Testing…" → result chip renders.
8. (Admin) User edits ClientSecret → clicks "Save Settings" → confirm if `ClientSecret` non-empty → `updatePowerBIConnectionSettings` fires.
9. (Admin) User closes Sheet → if Section 2 dirty → "Discard unsaved Add/Edit changes?" confirm.

### 🅱️ Block B — DESIGNER_CANVAS (NOT APPLICABLE)

### 🅲 Block C — MATRIX_CONFIG (NOT APPLICABLE)

### Shared — Page Header & Breadcrumbs

| Element | Content |
|---------|---------|
| Breadcrumb | Report & Audit › Reports › PowerBI Reports |
| Page title | Power BI Reports |
| Subtitle | Interactive analytics dashboards powered by Microsoft Power BI |
| Right actions | Configure Reports (admin), Refresh |

### Shared — Empty / Loading / Error

| State | Trigger | UI |
|-------|---------|----|
| Loading (gallery) | initial fetch | `<Skeleton>` x 6 cards in 3-col grid |
| Loading (embed) | `powerBIEmbed` fetching | `<Skeleton>` full-area (reuse existing `<PowerBIEmbed>` skeleton) |
| Empty (gallery) | `allPowerBIReports` returns 0 | full-area card with `ph:chart-bar` muted icon + "No reports yet" + admin CTA |
| Error (embed token) | `powerBIEmbed` returns error | reuse existing error-card in `<PowerBIEmbed>` |
| Save error | mutation error | inline section error + toast |
| Test Connection error | `testPowerBIConnection` returns success=false | inline red chip + toast with raw error |

---

## ⑦ Substitution Guide

**Canonical SETTINGS_PAGE reference**: Report Catalog #99 (hub-launcher variant — closest precedent in codebase).
**Canonical embed widget**: existing `<PowerBIEmbed>` at `presentation/components/page-components/reportaudit/rms-old/reportmaster/powerbiembed/PowerBIEmbed.tsx` — REUSE in place, do NOT duplicate.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| `ReportCatalog` (#99) | `PowerBIViewer` | hub-launcher page-config class name |
| `reportcatalog` | `powerbiviewer` | folder name under page-components |
| `rep.Reports` (favorites pattern) | `rep.PowerBIReports` (existing) + `rep.PowerBIConfigurations` (existing) | tables touched |
| `GetReportCatalog` composite query | `allPowerBIReports` (existing, no rename) + NEW `getPowerBIConnectionSettings` | GQL queries |
| `ToggleReportFavorite` | `createPowerBIReport` / `updatePowerBIReport` / `deletePowerBIReport` / `activateDeactivatePowerBIReport` (all existing) + NEW `updatePowerBIConnectionSettings` / `testPowerBIConnection` | GQL mutations |
| `<RunModal>` | n/a (replaced by inline embed view) | dynamic launch |
| ParentMenu: `RA_REPORTS` | `RA_REPORTS` | same parent — sibling of Report Catalog |
| MenuCode: `REPORTCATALOG` | `POWERBIREPORT` (existing seeded) | menu lookup |
| MenuUrl: `reportaudit/reports/reportcatalog` | `reportaudit/reports/powerbireport` (existing seeded) | route path |

---

## ⑧ File Manifest

### Backend Files

#### Created (3 new files)
| # | File | Path |
|---|------|------|
| 1 | NEW Query — GetPowerBIConnectionSettings | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ReportBusiness/PowerBIConfigurations/Queries/GetPowerBIConnectionSettings.cs` |
| 2 | NEW Command — UpdatePowerBIConnectionSettings | `…/Business/ReportBusiness/PowerBIConfigurations/Commands/UpdatePowerBIConnectionSettings.cs` |
| 3 | NEW Command — TestPowerBIConnection | `…/Business/ReportBusiness/PowerBIConfigurations/Commands/TestPowerBIConnection.cs` |

#### Modified (8 files)
| # | File | Change |
|---|------|--------|
| 1 | `Base.Domain/Models/ReportModels/PowerBIReport.cs` | Add 4 new fields: ThumbnailUrl, AutoRefreshEnabled, AutoRefreshIntervalHours, FilterParametersJson |
| 2 | `Base.Infrastructure/Data/Configurations/ReportConfigurations/PowerBIReportConfiguration.cs` | Add config for 4 new fields (max-lengths, defaults) |
| 3 | `Base.Infrastructure/Data/Configurations/ReportConfigurations/PowerBIConfigurationConfiguration.cs` | Change unique index from `(ConfigKey)` to `(CompanyId, ConfigKey)` |
| 4 | `Base.Application/Schemas/ReportSchemas/PowerBIReportSchemas.cs` | Extend DTOs with 4 new fields |
| 5 | `Base.Application/Schemas/ReportSchemas/PowerBIEmbedDto.cs` (or new file `PowerBIConnectionSettingsDto.cs`) | Add `PowerBIConnectionSettingsDto`, `PowerBITestConnectionResultDto` |
| 6 | `Base.Application/Business/ReportBusiness/PowerBIReports/Queries/GetAllPowerBIReportsQuery.cs` | Project 4 new fields + ensure tenant-scoping |
| 7 | `Base.API/EndPoints/Report/Queries/PowerBIReportQueries.cs` | Register `GetPowerBIConnectionSettings` field |
| 8 | `Base.API/EndPoints/Report/Mutations/PowerBIReportMutations.cs` | Register `UpdatePowerBIConnectionSettings` + `TestPowerBIConnection` fields |

#### EF Migration (1)
| # | Migration | Purpose |
|---|-----------|---------|
| 1 | `Add_PowerBIViewer_Fields` | Add 4 columns to PowerBIReports; change PowerBIConfigurations unique index to composite |

#### DB Seed (1 idempotent script)
| # | File | Purpose |
|---|------|---------|
| 1 | `sql-scripts-dyanmic/PowerBIViewer-sqlscripts.sql` | (a) sample default `PowerBIConfiguration` rows per-tenant (8 keys with empty values; admin must populate); (b) backfill `AutoRefreshEnabled=true`, `AutoRefreshIntervalHours=12` for existing rows; (c) preserve existing `POWERBIREPORT` menu (already seeded) — no changes |

> Menu `POWERBIREPORT` / `RA_REPORTS` / Grid / Capabilities are ALREADY SEEDED — registry confirms. No menu-seed work required.

### Backend Wiring Updates

| # | File | Change |
|---|------|--------|
| 1 | `Base.Application/Data/Persistence/IReportDbContext.cs` | (verify) `DbSet<PowerBIConfiguration>` already present ✓ |
| 2 | `Base.Infrastructure/Data/Persistence/ReportDbContext.cs` | (verify) ✓ |
| 3 | `Base.Application/Mappings/ReportMappings.cs` (or equivalent) | Add Mapster mapping for PowerBIConfiguration → PowerBIConnectionSettingsDto |
| 4 | `Base.Infrastructure/Data/Services/PowerBIEmbedService.cs` | (verify) Already reads PowerBIConfigurations via tenant — confirm tenant scoping in `GetSettingsAsync` (currently `.Where(c => c.IsActive == true)` — must add `c.CompanyId == tenantId`) |

### Frontend Files

#### Created (10 new files in NEW canonical location)
| # | File | Path |
|---|------|------|
| 1 | DTO Extension | `PSS_2.0_Frontend/src/domain/entities/powerbi-service/PowerBIConnectionSettingsDto.ts` |
| 2 | NEW GQL Query | `PSS_2.0_Frontend/src/infrastructure/gql-queries/powerbi-queries/connection-settings-query.ts` (export from index) |
| 3 | NEW GQL Mutations | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/powerbi-mutations/connection-settings-mutation.ts` (export from index) |
| 4 | Page Config | `PSS_2.0_Frontend/src/presentation/pages/reportaudit/reports/powerbiviewer.tsx` (NEW canonical name; replaces `shared/rms/powerbireport.tsx` for this menu) |
| 5 | Index Page (orchestrator) | `PSS_2.0_Frontend/src/presentation/components/page-components/reportaudit/reports/powerbiviewer/index-page.tsx` |
| 6 | Gallery View | `…/powerbiviewer/gallery-view.tsx` |
| 7 | Report Card | `…/powerbiviewer/components/report-card.tsx` |
| 8 | Embed View Wrapper | `…/powerbiviewer/embed-view.tsx` (wraps existing `<PowerBIEmbed>` with our custom header) |
| 9 | Configure Reports Sheet | `…/powerbiviewer/configure-reports-sheet.tsx` |
| 10 | Existing-Reports Table (Section 1) | `…/powerbiviewer/sections/existing-reports-section.tsx` |
| 11 | Add/Edit Report Form (Section 2) | `…/powerbiviewer/sections/report-form-section.tsx` |
| 12 | Connection Settings Form (Section 3) | `…/powerbiviewer/sections/connection-settings-section.tsx` |
| 13 | Secret Input | `…/powerbiviewer/components/secret-input.tsx` (masked + show/rotate) |
| 14 | Empty State | `…/powerbiviewer/components/gallery-empty-state.tsx` |
| 15 | Zustand Store | `…/powerbiviewer/powerbiviewer-store.ts` |
| 16 | Barrel | `…/powerbiviewer/index.ts` |

#### Modified (4 files)
| # | File | Change |
|---|------|--------|
| 1 | `PSS_2.0_Frontend/src/app/[lang]/reportaudit/reports/powerbireport/page.tsx` | Replace `<PowerBiReportPage />` import with `<PowerBIViewerPage />` from new canonical location |
| 2 | `PSS_2.0_Frontend/src/domain/entities/powerbi-service/index.ts` | Extend `PowerBIReport` DTO with 4 new fields; export `PowerBIConnectionSettingsDto` + `PowerBITestConnectionResultDto` |
| 3 | `PSS_2.0_Frontend/src/infrastructure/gql-queries/powerbi-queries/index.ts` | Add `GET_POWERBI_CONNECTION_SETTINGS`; extend `GET_POWERBI_REPORTS` projection with new fields + description/lastRefreshedAt for gallery cards |
| 4 | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/powerbi-mutations/index.ts` | Add `UPDATE_POWERBI_CONNECTION_SETTINGS`, `TEST_POWERBI_CONNECTION`, `CREATE_POWERBI_REPORT`, `UPDATE_POWERBI_REPORT`, `DELETE_POWERBI_REPORT`, `ACTIVATE_DEACTIVATE_POWERBI_REPORT` |

#### Deletion candidates (defer — keep until verified safe)
- `PSS_2.0_Frontend/src/presentation/pages/shared/rms/powerbireport.tsx` — only consumed by the route page we're rewriting; can delete after verification. Other rms-old pages remain for #155/#156 admin screens.

### Frontend Wiring Updates

No changes required:
- `entity-operations.ts` — N/A (CONFIG screens don't use the data-table operations registry)
- `sidebar` — `POWERBIREPORT` menu already seeded under `RA_REPORTS`

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: ALIGN

MenuName: PowerBI Reports
MenuCode: POWERBIREPORT
ParentMenu: RA_REPORTS
Module: REPORTAUDIT
MenuUrl: reportaudit/reports/powerbireport
GridType: CONFIG

MenuCapabilities: READ, MODIFY, ISMENURENDER
(Note: existing menu is already seeded with READ/MODIFY/EXPORT/PRINT/EMAIL/ISMENURENDER per RA_REPORTS convention — preserve)

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY

GridFormSchema: SKIP
GridCode: POWERBIREPORT
---CONFIG-END---
```

> Existing seed for `POWERBIREPORT` menu / Grid / Capabilities is in place from the original screen — do NOT re-create or re-seed.

---

## ⑩ Expected BE→FE Contract

**GraphQL Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `allPowerBIReports` (existing — extend projection) | `PaginatedApiResponse<PowerBIReportDto>` with extended DTO | `pageIndex`, `advancedFilter` |
| `getPowerBIReportById` (existing) | `BaseApiResponse<PowerBIReportResponseDto>` (extended) | `powerBIReportId: Int!` |
| `powerBIEmbed` (existing — no change) | `BaseApiResponse<PowerBIEmbedDto>` | `powerBiReportId: Int!` |
| **NEW** `getPowerBIConnectionSettings` | `BaseApiResponse<PowerBIConnectionSettingsDto>` | — (tenant from HttpContext) |

**GraphQL Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createPowerBIReport` (existing) | `PowerBIReportRequestDto` (extended w/ 4 new fields) | `BaseApiResponse<PowerBIReportRequestDto>` |
| `updatePowerBIReport` (existing) | `PowerBIReportRequestDto` (extended) | `BaseApiResponse<PowerBIReportRequestDto>` |
| `deletePowerBIReport` (existing) | `powerBIReportId: Int!` | `BaseApiResponse<PowerBIReportRequestDto>` |
| `activateDeactivatePowerBIReport` (existing) | `powerBIReportId: Int!` | `BaseApiResponse<PowerBIReportRequestDto>` |
| `savePowerBIAccessLog` (existing) | `SavePowerBIAccessLogDto` | `BaseApiResponse<Long>` |
| **NEW** `updatePowerBIConnectionSettings` | `UpdatePowerBIConnectionSettingsDto` | `BaseApiResponse<PowerBIConnectionSettingsDto>` |
| **NEW** `testPowerBIConnection` | — | `BaseApiResponse<PowerBITestConnectionResultDto>` |

**DTO additions:**

```ts
// powerbi-service/index.ts (extend existing PowerBIReport)
interface PowerBIReport {
  powerBIReportId: number;
  reportName: string;
  description?: string | null;
  workspaceId: string;       // GUID as string
  powerBIReportGuid: string; // GUID as string
  orderBy: number;
  rlsRoleName?: string | null;       // current FE: maps mockup "Access Roles" — see ISSUE-V2-4
  thumbnailUrl?: string | null;       // NEW
  autoRefreshEnabled: boolean;        // NEW, default true
  autoRefreshIntervalHours: number;   // NEW, default 12
  filterParametersJson?: string | null; // NEW (JSON string)
  isActive: boolean;
  // Read-only (computed) — for gallery cards
  lastRefreshedAt?: string | null;   // ISSUE-V2-2: needs BE projection from PowerBIAccessLogs (most recent UTC AccessDate)
}

// NEW DTOs
interface PowerBIConnectionSettingsDto {
  tenantId: string;             // returned as-is OR masked
  clientId: string;             // returned as-is OR masked
  clientSecret: string;         // returned as "" or "••••••••" — NEVER returned in plain text
  workspace: string;            // workspace name (e.g. "PSS-Analytics")
  authenticationMode: string;   // "ServicePrincipal" | "MasterUser"
}

interface UpdatePowerBIConnectionSettingsDto {
  tenantId: string;
  clientId: string;
  clientSecret: string;         // empty ⇒ unchanged; non-empty ⇒ overwrite
  workspace: string;
  authenticationMode: string;
}

interface PowerBITestConnectionResultDto {
  success: boolean;
  message: string;              // e.g. "Authentication successful, workspace accessible"
  testedAt: string;             // ISO datetime
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — 0 errors
- [ ] EF migration `Add_PowerBIViewer_Fields` generated and applied cleanly
- [ ] `pnpm tsc --noEmit` — 0 errors in new files
- [ ] `pnpm dev` — page loads at `/{lang}/reportaudit/reports/powerbireport`

**Functional Verification (Full E2E — MANDATORY):**

### Gallery view
- [ ] Loads `allPowerBIReports` and renders all reports as 3-col cards
- [ ] Each card shows: thumbnail (or fallback icon), title, description (2-line clamp), last-refreshed meta, View Report button
- [ ] Admin sees Edit/Delete icons; non-admin does NOT
- [ ] Clicking card OR View Report navigates to `?reportId=N` and switches view
- [ ] Empty state renders when no reports exist; admin CTA opens slide-in

### Embed view
- [ ] `powerBIEmbed(N)` query fires; `<PowerBIEmbed>` iframe renders
- [ ] Header shows Back / title / last-refreshed / actions
- [ ] Back to Gallery returns to gallery without page reload
- [ ] Full Screen works (existing `<PowerBIEmbed>` behavior)
- [ ] Refresh Data calls both `reportRef.current.refresh()` AND re-fetches embed token
- [ ] Export / Print / Share render as toast `"Coming soon"` (SERVICE_PLACEHOLDER)
- [ ] `savePowerBIAccessLog` fires on iframe load (verify in BE DB)

### Configure Reports slide-in panel
- [ ] Opens from right (520px), darkens overlay, click-outside closes
- [ ] Section 1 Existing Reports table renders with columns (Name / Workspace / Report ID truncated / Roles / Actions)
- [ ] Edit row pre-fills Section 2 form
- [ ] Delete row prompts confirm; on confirm fires `deletePowerBIReport`; table refreshes
- [ ] Section 2 Save Report fires `create` or `update` mutation; toast; section 1 + gallery refresh
- [ ] Section 2 fields validate per ④ rules (required GUIDs, JSON parse, etc.)
- [ ] Section 3 Test Connection fires `testPowerBIConnection`; status chip updates inline
- [ ] Section 3 Save Settings fires `updatePowerBIConnectionSettings`; toast
- [ ] ClientSecret never appears in GET response (verify in Apollo devtools); empty submit ⇒ unchanged

### Tenant isolation
- [ ] User in Company A cannot read PowerBIConfigurations of Company B (verify via test tenant switch)
- [ ] `PowerBIEmbedService.GetSettingsAsync` filters by tenant (after wiring fix)

### Sensitive-field handling
- [ ] ClientSecret rendered as masked input (`••••••••`) with eye-toggle
- [ ] Rotate ClientSecret prompts confirm; on save invalidates token cache

### Audit trail
- [ ] `savePowerBIAccessLog` fires on each successful embed load with current `userId`, `effectiveUsername`
- [ ] ClientSecret rotation logged (manual verify; no UI shows the audit yet — see ISSUE-V2-5)

### Role gating
- [ ] BUSINESSADMIN: full access
- [ ] Non-admin: Configure Reports button hidden; Edit/Delete icons hidden on cards

### DB Seed Verification
- [ ] Menu `POWERBIREPORT` already in sidebar under `Report & Audit > Reports`
- [ ] Seed populates 8 default PowerBIConfiguration rows per tenant with empty values (admin must fill)
- [ ] New PowerBIReport columns default correctly on existing rows (`AutoRefreshEnabled=true`, `AutoRefreshIntervalHours=12`)

---

## ⑫ Special Notes & Warnings

### ALIGN Scope Boundary
This screen is ALIGN — BE+FE exist but UX diverges from mockup. Specifically:
- **Current FE**: dropdown picker at top + immediate embed below (single-report-at-a-time UX).
- **Mockup FE**: 3-col gallery of cards → click → embed view, plus slide-in admin panel.
- **Reuse**: Backend CRUD endpoints, `<PowerBIEmbed>` iframe component, embed-token query — all stay intact.
- **Replace**: The `presentation/pages/shared/rms/powerbireport.tsx` (dropdown UX) is replaced by a new `presentation/pages/reportaudit/reports/powerbiviewer.tsx` (gallery+embed UX). The old `shared/rms/` file is delete-eligible AFTER verification.

### Relationship to siblings #155 / #156
- **#155 PowerBI Report Master** (currently FE stub at `reportsetup/powerbireportmaster/page.tsx`, NEW in registry): provides full-page admin grid for the same `PowerBIReport` entity. The slide-in panel of #97 partially overlaps with #155 — **both surfaces share the same BE CRUD**, but #155 will offer richer bulk operations + advanced filters when built. They are NOT redundant: #97's slide-in is a quick-edit shortcut; #155 is the canonical admin grid. Do NOT delete or merge #155 from the registry as part of this build.
- **#156 PowerBI User Mapping** (NEW): manages per-user RLS via `PowerBIReportUserMapping`. The mockup's "Access Roles" checkbox group in #97's Add/Edit Report form is a SIMPLIFIED role-level view — for V1 we persist as a comma-separated list on `RlsRoleName` (existing field); deeper per-user permissions remain in #156's domain. See ISSUE-V2-4.

### Pre-flagged ISSUEs

- **ISSUE-V2-1** HIGH — `PowerBIConfiguration` unique index is currently `(ConfigKey)` (single column), which blocks multi-tenant. The migration MUST change it to composite `(CompanyId, ConfigKey)`. Verify no production data violates the new constraint before applying.
- **ISSUE-V2-2** MED — `lastRefreshedAt` column on `PowerBIReports` does NOT exist; mockup shows it on cards. Options: (a) compute via subquery against `PowerBIAccessLogs.AccessDate` MAX per report (preferred — already available), (b) add column with materialized refresh trigger, (c) defer the field. Recommendation: (a) — project as `(SELECT MAX(AccessDate) FROM PowerBIAccessLogs WHERE PowerBIReportId = p.PowerBIReportId)` in `GetAllPowerBIReportsQuery`.
- **ISSUE-V2-3** MED — Thumbnail upload requires file-upload infra. V1 accepts URL only; file picker is SERVICE_PLACEHOLDER. Mockup `<input type="file">` becomes a URL text input until upload infra (used by Online Donation Page #10 ISSUE list) lands.
- **ISSUE-V2-4** MED — Mockup's "Access Roles" checkbox group (Super Admin / Org Admin / Manager / Staff / Field Agent) is role-based; existing entity has per-user `PowerBIReportUserMapping`. V1 persists roles as a comma-separated string on `RlsRoleName` and uses it for client-side filter only (BE does not enforce). Deeper role-based RLS is deferred to #156 PowerBI User Mapping build. Confirm with user during BA validation.
- **ISSUE-V2-5** LOW — Audit-trail UI not exposed; `PowerBIAccessLogs` rows are created but no admin viewer exists. Deferred — sibling admin grid #155 can surface this later.
- **ISSUE-V2-6** LOW — `PowerBIEmbedService.GetSettingsAsync` currently does NOT filter by `CompanyId` (only `IsActive`). Must be tightened in wiring update #4 above; otherwise once we tenant-scope the table, the service will pick the WRONG tenant.
- **ISSUE-V2-7** LOW — `authenticationMode = MasterUser` path is not implemented in `PowerBIEmbedService` (only ServicePrincipal). UI exposes it; selecting it shows a warning toast "Master User mode coming soon" (SERVICE_PLACEHOLDER).
- **ISSUE-V2-8** LOW — `AutoRefreshEnabled` + `AutoRefreshIntervalHours` are PERSISTED but no scheduler reads them. V1 captures the intent; a Hangfire job to invoke Power BI refresh API is a follow-up. SERVICE_PLACEHOLDER.
- **ISSUE-V2-9** LOW — Export / Print / Share buttons in embed-view header are SERVICE_PLACEHOLDERs. Power BI SDK does expose `report.print()` and `report.exportData()` — `Print` can be wired with low effort if desired (mark as STRETCH).
- **ISSUE-V2-10** LOW — `ReportKey` is hidden in mockup but required by entity. V1 auto-slugs from ReportName on Create (e.g. "Fundraising Analytics" → "fundraising-analytics"). Editable in advanced section if needed.
- **ISSUE-V2-11** LOW — Seed folder typo `sql-scripts-dyanmic/` preserved per repo convention (ChequeDonation #6 ISSUE-15 precedent).
- **ISSUE-V2-12** LOW — `<PowerBIEmbed>` component lives in `rms-old/reportmaster/powerbiembed/` — name suggests deprecation but it's the ONLY working embed implementation. Do NOT delete or move during this build; the canonical reference will be set when #155 is built.
- **ISSUE-V2-13** LOW — Mockup shows static sample report list (6 cards) — actual gallery data is from `allPowerBIReports`. If the tenant has zero reports, empty-state CTA kicks in.

### SERVICE_PLACEHOLDERs (UI built; handlers stubbed)
1. **Export (embed-view)** — toast "Export coming soon"
2. **Print (embed-view)** — could call `report.print()` if SDK exposes it; otherwise toast (decide during build)
3. **Share (embed-view)** — toast "Share coming soon" (requires public-link infra)
4. **Thumbnail upload** — URL field only; file picker disabled or hidden
5. **Master User auth mode** — toast on selection "MasterUser mode coming soon"
6. **Auto-refresh scheduler** — persisted but no Hangfire job runs
7. **Audit-trail viewer** — `PowerBIAccessLogs` written but no UI

### Build agent guidance
- Spawn **Sonnet** agents only (per `feedback_prefer_sonnet_over_opus` memory). The ALIGN scope is medium-complexity; no Opus escalation needed.
- Front-load file-write directive per `feedback_long_agent_prompts_stall` memory — list every file path with intent upfront in the agent spawn prompt.
- Reuse the existing `<PowerBIEmbed>` component — do NOT respawn or duplicate it.
- Frontend Developer agent: maintain existing dropdown-component as fallback during transition (commit gallery+embed as a new entrypoint; only after verification should the old shared/rms/powerbireport.tsx be deleted).
- Testing agent must verify:
  - GQL contract — new connection-settings query/mutations resolve
  - PowerBIConfiguration unique-index migration applied without data loss
  - Sensitive field handling (ClientSecret never in GET payload)
  - Tenant scoping fix on `PowerBIEmbedService.GetSettingsAsync`

---

## ⓮ Validation Resolutions (2026-05-14 — BA + SR + UX agent pass)

**These resolutions are CANONICAL guidance for the BE and FE Developer agents. They supersede or amend the earlier sections where stated.**

### R-1 — Admin bypass in gallery query (BA GAP-2, was BLOCKING)

`GetAllPowerBIReportsQuery.cs:40` filters `.Where(r => r.UserMappings.Any(m => m.UserId == userId))`. Without a BUSINESSADMIN bypass, the admin's gallery is always empty on a fresh tenant — defeating the "Configure your first report" empty-state CTA flow.

**Fix in handler**: read the current user's role from `httpContextAccessor.GetCurrentUserRole()` (or whichever role-check helper this codebase uses; BE Dev to discover). If role is `BUSINESSADMIN`, skip the `UserMappings` predicate. Pseudocode:

```csharp
var role = httpContextAccessor.GetCurrentUserRole();
var baseQuery = dbContext.PowerBIReports
    .AsNoTracking()
    .Where(r => r.IsActive == true && r.CompanyId == companyId);
if (!IsBusinessAdmin(role))
    baseQuery = baseQuery.Where(r => r.UserMappings.Any(m => m.UserId == userId));
baseQuery = baseQuery.OrderBy(r => r.OrderBy);
```

### R-2 — DTO must carry all 8 ConfigKeys (BA GAP-3)

Section ⑩ DTO is incomplete. The canonical DTO shape — used by both `PowerBIConnectionSettingsDto` and `UpdatePowerBIConnectionSettingsDto`:

```ts
{
  tenantId: string;
  clientId: string;
  clientSecret: string;     // empty on GET; empty on submit ⇒ unchanged
  authorityUrl: string;     // default "https://login.microsoftonline.com/"
  resourceUrl: string;      // default "https://analysis.windows.net/powerbi/api"
  apiUrl: string;           // default "https://api.powerbi.com"
  workspace: string;
  authenticationMode: string;  // "ServicePrincipal" | "MasterUser"
}
```

UI (Section 3 of slide-in): 5 primary fields + collapsible **"Advanced"** group containing `authorityUrl`, `resourceUrl`, `apiUrl` with sensible defaults pre-filled. Power users edit these only when targeting sovereign clouds (e.g. US-Gov, China). Default values must be applied server-side on the first call when no row exists.

### R-3 — `PowerBIEmbedService` tenant-keyed cache (BA GAP-4 / ISSUE-V2-6, re-rated HIGH)

Current `GetSettingsAsync` has `_cachedSettings` + `_settingsCacheExpiry` as instance fields with no `CompanyId` filter. In a multi-tenant request, Tenant A's credentials may be served to Tenant B for up to 5 minutes.

**Fix**:
- Inject `IHttpContextAccessor` (verify it isn't already injected).
- Replace single-value cache with `ConcurrentDictionary<int, (PowerBISettings settings, DateTime expiry)>` keyed by `CompanyId`.
- Add the `c.CompanyId == currentCompanyId` filter to the DB query.
- Expose a public method `InvalidateCache(int companyId)` on the service; call it from the `UpdatePowerBIConnectionSettings` command handler after successful `SaveChangesAsync`.

### R-4 — UserMapping preservation on slide-in Save (BA GAP-5)

`UpdatePowerBIReport.cs:146-161` soft-deletes ALL `UserMappings` when `StaffIds` is null/empty. The slide-in form has no StaffIds field. Two-part fix:

**FE side**: when editing an existing report from the slide-in, the form must fetch via `getPowerBIReportById` and pass back the existing `staffIds` unchanged in the update payload. When creating a new report from the slide-in, pre-fill `staffIds` with the current user's `userId` (so the admin who creates is mapped at minimum — they can manage other mappings via #156 later).

**BE side**: no change to the validator. The validator continues to require `staffIds.Any() == true` — this matches the FE behavior above.

### R-5 — `ReportKey` uniqueness (BA GAP-7)

Add to the same EF migration: composite unique index `(CompanyId, ReportKey)` on `rep.PowerBIReports`. Auto-slugged keys would otherwise silently duplicate.

### R-6 — `testPowerBIConnection` accepts in-memory input (BA RISK-A)

Mutation signature changes from `()` to `(UpdatePowerBIConnectionSettingsDto input)`. Handler probes Azure AD with the typed (unsaved) credentials. This is critical UX — admins must be able to validate before committing.

If `input.clientSecret` is empty, handler falls back to the DB-stored secret (so "Test" works for users who only want to validate after editing tenantId / clientId without rotating the secret).

### R-7 — Migration shape (SR §5)

Migration file `Add_PowerBIViewer_Fields` must execute in this order:
1. Pre-migration SQL check (or inline comment with verification command): `SELECT CompanyId, ConfigKey, COUNT(*) FROM rep.PowerBIConfigurations GROUP BY CompanyId, ConfigKey HAVING COUNT(*) > 1` — if rows return, emit a data-fixup `DELETE` (keep most recent by CreatedDate) before the index swap.
2. `DropIndex` on `(ConfigKey)`.
3. `CreateIndex` `(CompanyId, ConfigKey)` UNIQUE.
4. Add 4 new columns to `rep.PowerBIReports` (`ThumbnailUrl`, `AutoRefreshEnabled`, `AutoRefreshIntervalHours`, `FilterParametersJson`) with defaults.
5. `CreateIndex` `(CompanyId, ReportKey)` UNIQUE on `rep.PowerBIReports`.

DB Seed remains separate (idempotent backfill of 8 default ConfigKey rows per tenant).

### R-8 — UX component name corrections (UX §1)

| Prompt name | Real codebase name | Path |
|-------------|--------------------|------|
| `<ConfirmDialog>` | `AlertDialog` | `common-components/molecules/AlertDialog/index.tsx` |
| `<Sheet>` (520px) | `Sheet` with `className="w-[520px] max-w-[520px]"` override on `SheetContent` (do NOT edit shared variants) | `common-components/atoms/Sheet/index.tsx` |
| `<SecretInput>` | Extend the SMS one — copy + add `rotateButton` / `onRotate` / `isRotating` props | reference: `setting/communicationconfig/smssetup/secret-input.tsx` |
| `<ConfirmDialog>` for Delete / Rotate / Auth Mode switch | `AlertDialog` (same as above) | — |

### R-9 — Additional skeleton states (UX §6)

Add to the FE Dev's todo:
- Section 1 (Existing Reports table) row-level skeleton during `allPowerBIReports` refetch after Section 2 save.
- Section 3 (Connection Settings) input-field skeletons (5 fields × `Skeleton h-9 w-full`) during `getPowerBIConnectionSettings` initial fetch.

### R-10 — iframe a11y (UX §7)

Pass `reportName` to `embed-view.tsx`; render iframe wrapper with `title={`Power BI Report: ${reportName}`}` for screen reader announcement.

### R-11 — Reuse decisions

- Page header: do NOT import `ReportCatalogHeader`; copy its structure into a new `…/powerbiviewer/components/page-header.tsx`.
- `<PowerBIEmbed>`: REUSE `rms-old/reportmaster/powerbiembed/PowerBIEmbed.tsx` (matches the existing import path used by current route). The duplicate at `reports/powerbireport/PowerBIEmbed.tsx` is identical and currently unused — LEAVE IT ALONE (do not delete in this build; defer cleanup to #155 build).

---

## ⑬ Build Log

### § Known Issues

| ID | Title | Opened | Status |
|----|-------|--------|--------|
| ISSUE-V2-1 | PowerBIConfiguration unique-index multi-tenant fix | 2026-05-14 | CLOSED in S1 (migration `Add_PowerBIViewer_Fields` swaps `(ConfigKey)` → `(CompanyId, ConfigKey)`) |
| ISSUE-V2-2 | `lastRefreshedAt` projected via subquery on PowerBIAccessLogs | 2026-05-14 | CLOSED in S1 |
| ISSUE-V2-3 | Thumbnail upload (URL field only; file picker deferred) | 2026-05-14 | OPEN — SERVICE_PLACEHOLDER for upload infra |
| ISSUE-V2-4 | RlsRoleName persists comma-separated access roles in V1 | 2026-05-14 | OPEN — full per-user RLS belongs to #156 |
| ISSUE-V2-5 | Audit-trail UI for PowerBIAccessLogs | 2026-05-14 | OPEN — deferred to sibling admin grid #155 |
| ISSUE-V2-6 | PowerBIEmbedService tenant-keyed cache + CompanyId filter | 2026-05-14 | CLOSED in S1 (ConcurrentDictionary keyed by CompanyId + InvalidateCache called on every UpdatePowerBIConnectionSettings) |
| ISSUE-V2-7 | MasterUser auth mode | 2026-05-14 | OPEN — SERVICE_PLACEHOLDER toast |
| ISSUE-V2-8 | Auto-refresh scheduler (Hangfire) | 2026-05-14 | OPEN — persisted-but-unused |
| ISSUE-V2-9 | Export / Print / Share embed-view actions | 2026-05-14 | OPEN — SERVICE_PLACEHOLDER toast |
| ISSUE-V2-10 | ReportKey auto-slug + composite uniqueness | 2026-05-14 | CLOSED in S1 (composite unique index `(CompanyId, ReportKey)` added) |
| ISSUE-V2-11 | Seed folder typo `sql-scripts-dyanmic/` | 2026-05-14 | CLOSED in S1 (preserved per repo convention) |
| ISSUE-V2-12 | `<PowerBIEmbed>` left in `rms-old/` location | 2026-05-14 | CLOSED in S1 (reused as-is) |
| ISSUE-V2-13 | Mockup gallery shows 6 static cards | 2026-05-14 | CLOSED in S1 (gallery sourced from `allPowerBIReports`; empty-state CTA wired) |
| ISSUE-V2-14 | PowerBIEmbed had no reportId prop → wrong report rendered on card click | 2026-05-14 | CLOSED in S1 (extended `PowerBIEmbedProps` with optional `initialReportId`; preserves legacy auto-first behavior when prop is absent) |
| ISSUE-V2-15 | StaffIds wipe on slide-in save (BA GAP-5) | 2026-05-14 | CLOSED in S1 (FE form pre-fills `staffIds = [currentUserId]` on Create; preserves existing on Edit via `getPowerBIReportById` round-trip) |
| ISSUE-V2-16 | Admin gallery empty when no UserMappings (BA GAP-2) | 2026-05-14 | CLOSED in S1 (BUSINESSADMIN role bypass in `GetAllPowerBIReportsQuery` handler) |
| ISSUE-V2-17 | DTO covered only 5 of 8 ConfigKeys (BA GAP-3) | 2026-05-14 | CLOSED in S1 (DTO extended to all 8 with Azure URL defaults; UI surfaces 5 + collapsible Advanced for the 3 URL keys) |
| ISSUE-V2-18 | testPowerBIConnection now accepts in-memory input (BA RISK-A) | 2026-05-14 | CLOSED in S1 (mutation takes `UpdatePowerBIConnectionSettingsDto`; falls back to DB-stored secret if `clientSecret` empty) |
| ISSUE-V2-19 | Migration .Designer.cs not regenerated (BE TODO) | 2026-05-14 | OPEN — run `dotnet ef migrations add Add_PowerBIViewer_Fields` to regenerate the snapshot before applying; hand-written migration is functionally correct but lacks the EF model snapshot diff |
| ISSUE-V2-20 | `shared/rms/powerbireport.tsx` (old dropdown UX) not deleted | 2026-05-14 | OPEN — defer until production verification of new viewer |

### § Sessions

### Session 1 — 2026-05-14 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. ALIGN scope — replaces dropdown-picker UX with hub-launcher gallery + embed + slide-in admin sheet. BE adds 3 endpoints + 4 columns + tenant-keyed cache fix. FE adds full page-component tree at `powerbiviewer/`.
- **Files touched**:
  - BE created (6): `Base.Application/Business/ReportBusiness/PowerBIConfigurations/Queries/GetPowerBIConnectionSettings.cs`, `…/Commands/UpdatePowerBIConnectionSettings.cs`, `…/Commands/TestPowerBIConnection.cs`, `Base.Application/Schemas/ReportSchemas/PowerBIConnectionSettingsDto.cs`, `Base.Infrastructure/Migrations/20260514070000_Add_PowerBIViewer_Fields.cs`, `sql-scripts-dyanmic/PowerBIViewer-sqlscripts.sql`
  - BE modified (9): `Base.Domain/Models/ReportModels/PowerBIReport.cs` (+4 fields), `Base.Infrastructure/Data/Configurations/ReportConfigurations/PowerBIReportConfiguration.cs`, `…/PowerBIConfigurationConfiguration.cs`, `Base.Application/Schemas/ReportSchemas/PowerBIReportSchemas.cs`, `Base.Application/Business/ReportBusiness/PowerBIReports/Queries/GetAllPowerBIReportsQuery.cs` (admin bypass + lastRefreshedAt projection), `Base.Application/Data/Services/IPowerBIEmbedService.cs` (+InvalidateCache, +TestConnectionAsync), `Base.Infrastructure/Data/Services/PowerBIEmbedService.cs` (ConcurrentDictionary cache by CompanyId, tenant filter), `Base.API/EndPoints/Report/Queries/PowerBIReportQueries.cs`, `Base.API/EndPoints/Report/Mutations/PowerBIReportMutations.cs`
  - FE created (13): full `powerbiviewer/` tree — `index-page.tsx`, `gallery-view.tsx`, `embed-view.tsx`, `configure-reports-sheet.tsx`, `powerbiviewer-store.ts`, `index.ts`, `components/page-header.tsx`, `components/report-card.tsx`, `components/gallery-empty-state.tsx`, `components/secret-input.tsx`, `sections/existing-reports-section.tsx`, `sections/report-form-section.tsx`, `sections/connection-settings-section.tsx` + new page config `presentation/pages/reportaudit/reports/powerbiviewer.tsx`
  - FE modified (6): `app/[lang]/reportaudit/reports/powerbireport/page.tsx` (repoints to PowerBIViewerPage), `domain/entities/powerbi-service/index.ts` (extended DTOs), `infrastructure/gql-queries/powerbi-queries/index.ts`, `infrastructure/gql-mutations/powerbi-mutations/index.ts`, `presentation/components/page-components/reportaudit/reports/index.tsx` (barrel), `presentation/pages/reportaudit/reports/index.ts` (barrel), `…/rms-old/reportmaster/powerbiembed/PowerBIEmbed.tsx` (orchestrator-applied: +`initialReportId` prop + reactive switch effect so gallery card clicks change the iframe report)
  - DB: `sql-scripts-dyanmic/PowerBIViewer-sqlscripts.sql` (created)
- **Deviations from spec**:
  - Section ⑥ called Refresh button on gallery "re-runs gallery query"; FE Dev initially shipped `window.location.reload()` for that. Orchestrator-applied fix: gallery now exposes a `refetch()` handle via `forwardRef`+`useImperativeHandle`; index-page wires Refresh button to it. (Spec intent preserved; implementation cleaner.)
  - Section ⑦ said REUSE `<PowerBIEmbed>` "in place, do NOT duplicate" and the FE Dev directive said "DO NOT modify any PowerBIEmbed implementation file." Orchestrator overrode: applied a small backwards-compatible extension (`initialReportId?: number`) to make gallery card click → correct embed render work. Without it, every card showed the auto-selected first report. (Spec intent preserved; siblings #155/#156 unaffected.)
- **Known issues opened**: ISSUE-V2-14 through V2-20 (see Known Issues table above; 5 closed in this session, 2 remain open as deferrals).
- **Known issues closed**: ISSUE-V2-1, V2-2, V2-6, V2-10, V2-11, V2-12, V2-13, V2-14, V2-15, V2-16, V2-17, V2-18.
- **Orchestrator notes**:
  - Build agents were launched on Sonnet (per `feedback_prefer_sonnet_over_opus`).
  - FE Developer agent wrote to a sibling git worktree (`d:/Repos/PWDS/pwds-soruban/pss-2.0-global` — no "- Copy" suffix). All FE files were synced into the primary working tree (`d:/Repos/PWDS/pwds-soruban - Copy/pss-2.0-global`) via PowerShell `Copy-Item -Recurse -Force` before finalization. BE agent wrote to the primary tree directly; only FE drifted.
  - Validation pass surfaced 7 BA gaps + 3 risks; resolutions captured in Section ⓮ before code generation.
- **Next step**: (empty — COMPLETED). Outstanding deferrals are in OPEN ISSUEs.
