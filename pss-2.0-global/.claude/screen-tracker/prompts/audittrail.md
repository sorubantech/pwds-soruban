---
screen: AuditTrail
registry_id: 74
module: Report & Audit
status: PROMPT_READY
scope: FULL
screen_type: REPORT
report_subtype: TABULAR
source_pattern: report-row-table
pagination_strategy: server-paginate
complexity: High
new_module: NO — module REPORTAUDIT exists; new Group folder ReportAuditBusiness + new Schema folder ReportAuditSchemas
planned_date: 2026-05-10
completed_date:
last_session_date:
---

> **Type override note**: REGISTRY.md classified this screen as `FLOW` ("TrackingData concept").
> The mockup contradicts FLOW classification: NO add/edit/submit lifecycle, info banner explicitly
> states *"Audit records are immutable and cannot be modified or deleted"*, header actions are
> Export Log + Print only, and the screen is a filter-panel + result-view + drill-down detail-panel
> + export shape — textbook REPORT/TABULAR. Reclassified per `_REPORT.md` detection rules.
> See `_REPORT.md` "When in doubt between FLOW and REPORT" — audit records are *consumed as
> output*, not transacted on. This is the inaugural REPORT/TABULAR screen and sets the canonical
> convention for §⑦.

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type: TABULAR with Timeline-view toggle)
- [x] Source data identified (NEW AuditLog entity — `report-row-table` source pattern)
- [x] Filter panel inventoried (Date Range, User, Action, Module, Status, Severity, Search + 4 quick-date chips)
- [x] Result shape inventoried (8 columns + 4 summary cards + Timeline view + slide-in detail panel)
- [x] Scale estimated (≈300 rows/day per typical tenant; ≈100k/year retention; max-row guard at 30k for on-screen, streamed Excel beyond)
- [x] Pagination strategy chosen (`server-paginate`, page size 50)
- [x] Export formats confirmed (Excel, CSV, PDF, Print — Excel/PDF flagged SERVICE_PLACEHOLDER if generators missing)
- [x] Role-scoping rules captured (BUSINESSADMIN sees all; STAFFADMIN scoped to own branch; non-admin sees only own actions)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated (audience, frequency, decisions, data sensitivity, retention policy)
- [ ] Solution Resolution complete (sub-type confirmed, capture-mechanism strategy confirmed)
- [ ] UX Design finalized (filter panel + summary cards + table view + timeline view + detail panel + export menu)
- [ ] User Approval received
- [ ] Backend AuditLog entity + EF config + migration
- [ ] Backend audit-capture infrastructure (AuditLogWriter service + interceptor extension OR explicit handler emits)
- [ ] Backend report query (paginated + summary aggregate)
- [ ] Backend export handlers (Excel / CSV / PDF — placeholders OK)
- [ ] Backend wiring complete
- [ ] Frontend report page (replace `<UnderConstruction />` stub at existing route)
- [ ] Frontend wiring complete
- [ ] DB Seed script (menu entry + MasterData seeds for AUDIT_ACTION_TYPE / AUDIT_STATUS / AUDIT_SEVERITY)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] EF migration runs cleanly on fresh DB
- [ ] pnpm dev — page loads at `/[lang]/reportaudit/audit/audittrail` (replaces existing stub)
- [ ] 4 summary cards render with live counts (Today's Actions / Active Users / Data Modifications / Security Events)
- [ ] Filter panel renders all 7 filter controls with defaults
- [ ] Quick-date chips (Today / Yesterday / This Week / This Month / Custom) update Date Range
- [ ] Apply / Clear / Save Filter buttons functional
- [ ] Generate triggers fetch; loading skeleton matches table+summary shape
- [ ] Result table renders 8 columns with correct alignment + row colorization (warning/critical bg)
- [ ] Action pills render with semantic colors (Create=green, Update=blue, Delete=red, Login=purple, Export=amber, Send=teal, Approve=emerald)
- [ ] Status badges render with correct semantic
- [ ] Sort + server-pagination work (default: Timestamp desc)
- [ ] View toggle Table ↔ Timeline switches result region with no re-fetch
- [ ] Timeline view groups by date with timeline-dots colored per status
- [ ] Detail panel slides in from right with full audit record (Record / User / Session / Changes / Related)
- [ ] Detail panel renders Changes table for Update actions (before / after)
- [ ] Detail panel renders Security Timeline for Login events (correlated failed-attempt history)
- [ ] Entity-link drill-down navigates to source record (e.g. `/crm/donation/globaldonation?mode=read&id=X`)
- [ ] Export Excel triggers handler (real or SERVICE_PLACEHOLDER toast)
- [ ] Export CSV produces plain rows
- [ ] Print triggers print-CSS layout (filter panel + view-toggle hidden, table fits page width, header repeats)
- [ ] Empty state diagnostic ("No audit records match …")
- [ ] Max-row guard banner kicks in when filter set exceeds 30,000 rows
- [ ] Role-scoped data: STAFFADMIN sees only own-branch user actions; FIELDAGENT sees only own actions
- [ ] No mutation / delete UI exposed anywhere (audit records immutable per info banner)
- [ ] DB Seed — menu visible in sidebar at `Report & Audit › Audit › Audit Trail`

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

**Screen**: Audit Trail
**Module**: Report & Audit (existing `REPORTAUDIT` module)
**Schema**: `app` (shared application schema; AuditLog table lives here for cross-module visibility)
**Group**: `ReportAuditBusiness` (NEW folder — first screen in this group; convention follows `{Feature}Business`)

**Business**:

The Audit Trail is the tenant's complete, immutable activity log — every data write, every authentication event, every export, every approval, every system-generated record-creation lands here as one row. It is the primary forensic surface for compliance reviews, security incident investigations, and dispute resolution ("who changed this donation amount and when?"). The screen is run mostly by the BUSINESSADMIN and SECURITY_ADMIN roles ad-hoc when something looks off, and by external auditors during compliance audits (SOC2, FCRA quarterly review, donor-trust transparency reports). It is not a daily-driver screen — frequency is low but the cost of missing data is very high.

**Why it exists**: NGOs handling donor money are routinely asked to prove who-did-what-when. Internal control SOPs require an immutable trail of role changes, capability grants, and large-amount donation modifications. Donors and grant funders increasingly request a "data integrity report" showing nothing was edited after issuance. Failed-login geographic patterns are a leading indicator of credential-stuffing attacks; surfacing them here lets the admin lock accounts before damage. The mockup info banner — *"Audit records are immutable and cannot be modified or deleted"* — is a compliance contract, not a UI suggestion.

**Scale**:
- Typical tenant: ≈200–500 rows/day across all activity (login events dominate, then donation CRUD, then exports). Annualized: 70k–180k rows.
- Heavy tenant (campaign launch + bulk import + fundraiser onboarding): up to 2,000 rows/day.
- Retention: 7 years (financial records standard); roll-up after year 2 to a quarterly summary table is a future optimization (out of scope for this screen).
- Concurrency: low — at most 2-3 admins viewing simultaneously, but every write across the whole app emits one audit row, so the table grows continuously.

**Data sensitivity**: HIGH. Audit rows can contain field-level before/after values for sensitive fields (donor PII, donation amounts, account passwords flagged "redacted"). Role-scoped data filtering in the BE is mandatory — non-admins must NOT see other users' actions, only their own. Sensitive change values like password-reset flags are stored as `[redacted]` strings, not the actual value.

**Recipient format**: Most consumers want the on-screen interactive view (filter, drill-down, find the row, look at Changes table). Compliance auditors export to Excel for archival ("here's all role-capability changes in Q1 2026"). The Print button feeds the rare board-meeting "audit summary" packet.

**Relation to other screens**:
- Drill-downs: row's Entity link navigates to the source record's detail view (Donation #DON-4523 → `/crm/donation/globaldonation?mode=read&id=…`).
- Source: every other screen's create/update/delete handler must emit an AuditLog row — this is the *consumer-of-all-writes* screen.
- Login event source: authentication middleware must emit Login/Logout/Failed-Login/Account-Lock rows — currently NO such hook exists (see §⑫ Audit Infra Build-out).

> **Why this section is heavy**: This is the *first* REPORT/TABULAR in the registry and the *first* screen that requires a cross-cutting capture mechanism. The BA needs the full picture to validate the AuditLog entity shape and the capture-strategy decision below.

---

## ② Source Model

> **Consumer**: BA Agent → Backend Developer

**Source Pattern**: `report-row-table` — Audit records are persisted at write-time into a dedicated `AuditLog` table; the screen *queries* but never *generates* this table on demand. Two reasons it cannot be `query-only`:
1. Cross-entity capture (donations + contacts + roles + login events + exports) — no single source query can produce these uniformly.
2. Authentication events have NO source row anywhere else (a failed login produces no Donation/Contact/etc. record).

### Source Entities

> AuditLog is the single source of truth. Entities below are referenced for FK resolution / drill-down only.

| Source Entity | Entity File Path | Fields Consumed | Join Cardinality | Filter |
|---------------|------------------|-----------------|------------------|--------|
| AuditLog (NEW) | `Base.Domain/Models/ReportAuditModels/AuditLog.cs` | all | self | IsActive=true (no IsDeleted — never deleted), CompanyId from HttpContext |
| User | `Base.Domain/Models/AuthModels/User.cs` | UserName, Email | optional (UserId may be null for System/Unknown) | filter dropdown source |
| Module | `Base.Domain/Models/AuthModels/Module.cs` | ModuleName | optional | filter dropdown source |
| Branch | `Base.Domain/Models/ApplicationModels/Branch.cs` | BranchName | optional (role-scoping) | role data filter |
| MasterData | `Base.Domain/Models/SettingModels/MasterData.cs` | DataName, DataCode | required for ActionType / Status / Severity | filter dropdowns |

### Storage Table — AuditLog (NEW)

| Field | C# Type | MaxLen | Notes |
|-------|---------|--------|-------|
| AuditLogId | int | — | PK identity |
| AuditNo | string | 32 | Display number `AUD-{yyyyMMdd}-{seq6}` (e.g., `AUD-20260412-001847`); unique, generated server-side |
| CompanyId | int | — | tenant scope (FK Company); auto-stamped by `TenantSaveChangesInterceptor` |
| Timestamp | DateTime (UTC) | — | when the action occurred (NOT CreatedDate — that's stamped by interceptor too, but Timestamp is the *event* time) |
| UserId | int? | — | FK User; NULL when System / Unknown / unauthenticated event |
| UserDisplayName | string | 100 | denormalized — captured at write so renames / deletes don't break history |
| UserEmail | string | 200 | denormalized |
| UserRoleName | string | 100 | denormalized — e.g., "Fundraising Manager" |
| ActionType | string | 32 | one of: `CREATE`, `UPDATE`, `DELETE`, `LOGIN`, `LOGOUT`, `LOGIN_FAILED`, `ACCOUNT_LOCKED`, `EXPORT`, `IMPORT`, `SEND`, `APPROVE`, `REJECT`, `ROLE_CHANGE`, `PASSWORD_RESET` (string code; FK to MasterData type `AUDIT_ACTION_TYPE` for label/color resolution) |
| EntityType | string | 64 | logical entity name e.g. `Donation`, `Contact`, `Role`, `User`, `EmailCampaign`, `FieldCollection`, `Receipt` |
| EntityId | int? | — | the record ID being acted on (NULL for Login/Logout — no entity) |
| EntityDisplayKey | string | 64 | denormalized human-readable key — `DON-4523` / `CON-1892` / `Role: Staff` |
| ModuleId | int? | — | FK Module; NULL for cross-module events |
| Description | string | 500 | human-readable narrative — "Updated amount from $200 to $500" / "Account locked after 5 failed attempts" |
| Status | string | 16 | `SUCCESS` / `WARNING` / `CRITICAL` / `FAILED` / `DENIED` (string code; FK to MasterData type `AUDIT_STATUS`) |
| Severity | string | 16 | `LOW` / `MEDIUM` / `HIGH` / `CRITICAL` (string code; FK to MasterData type `AUDIT_SEVERITY`) |
| IpAddress | string | 45 | IPv4 or IPv6 — captured from `HttpContext.Connection.RemoteIpAddress`; "—" represented as NULL |
| DeviceInfo | string | 200 | parsed UA → "Chrome 124 / Windows 11"; nullable (null for System events) |
| UserAgent | string | 500 | raw User-Agent header (kept for forensic review even though parsed DeviceInfo is shown) |
| SessionId | string | 64 | session token hash (NOT the raw token); nullable for unauthenticated events |
| GeoLocation | string | 100 | nullable "Lagos, Nigeria (estimated)" — populated by IP-geolocation service (SERVICE_PLACEHOLDER — store NULL until lookup wired) |
| ChangesJson | string (jsonb) | — | for UPDATE actions: array `[{field, before, after}]`; nullable; max 64KB enforced server-side |
| RelatedRecordsJson | string (jsonb) | — | for cross-entity events: list of `[{entityType, entityId, displayKey}]`; nullable |
| FailureReason | string | 200 | for WARNING/CRITICAL/FAILED: "Incorrect password" / "Account locked" / "Capability denied" |
| AttemptNumber | int? | — | for failed-login series: 1..5; null otherwise |
| CorrelationId | string (Guid) | 36 | groups related events — 5 failed logins + 1 account-lock share one CorrelationId so the detail-panel Security Timeline can render the chain |
| IsActive | bool | — | inherited from `IEntity` — always `true`, never set to false (audit immutability — soft-delete blocked at the application service layer) |
| IsDeleted | bool | — | inherited — always `false`; never set true |
| CreatedBy / CreatedDate | int? / DateTime? | — | inherited; CreatedDate ≈ Timestamp (within milliseconds); CreatedBy = UserId for authenticated, NULL for System |
| ModifiedBy / ModifiedDate | int? / DateTime? | — | inherited but should remain NULL — updates are blocked at the application layer |

**Indexing strategy** (for backend dev):
- Primary: `(CompanyId, Timestamp DESC)` — covers default date-range filter
- `(CompanyId, UserId, Timestamp DESC)` — User filter
- `(CompanyId, ActionType, Timestamp DESC)` — Action filter
- `(CompanyId, EntityType, EntityId)` — drill-down "show all events for DON-4523"
- `(CorrelationId)` — detail-panel security timeline
- `AuditNo` UNIQUE

### Computed / Derived Columns (server-side, in query)

| Column | Formula | Notes |
|--------|---------|-------|
| ActionLabel | MasterData lookup of ActionType → DataName | for display ("Update" / "Account Locked"); join in query |
| ActionColor | MasterData attribute lookup | mapped to action-pill CSS class |
| StatusLabel | MasterData lookup of Status | for badge text |
| RowSeverityClass | derived: `WARNING` → `row-warning`, `CRITICAL` → `row-critical`, else null | drives row background color |

### Summary Card Aggregates (separate query — `GetAuditTrailSummary`)

| Card | Source | Default Period |
|------|--------|----------------|
| Today's Actions | `COUNT(*) WHERE date(Timestamp) = today` + peak-hour subquery | today |
| Active Users Today | `COUNT(DISTINCT UserId) WHERE date(Timestamp) = today` + total registered users | today |
| Data Modifications | `COUNT(*) WHERE ActionType IN ('CREATE','UPDATE','DELETE')` split by each action | today (matches header date) |
| Security Events | `COUNT(*) WHERE ActionType IN ('LOGIN_FAILED','PASSWORD_RESET','ROLE_CHANGE','ACCOUNT_LOCKED')` split | today |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (joins) + Frontend Developer (filter dropdowns)

| FK / Filter Source | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type | Used For |
|--------------------|--------------|-------------------|----------------|---------------|-------------------|----------|
| UserId | User | `Base.Domain/Models/AuthModels/User.cs` | `GetUsers` | `UserName` | `UserResponseDto` | "User" filter dropdown + result column |
| ModuleId | Module | `Base.Domain/Models/AuthModels/Module.cs` | `GetModules` | `ModuleName` | `ModuleResponseDto` | "Entity / Module" filter dropdown |
| BranchId (data scope) | Branch | `Base.Domain/Models/ApplicationModels/Branch.cs` | `GetBranches` | `BranchName` | `BranchResponseDto` | role-scoped data filter (STAFFADMIN sees own branch only) |
| ActionType | MasterData (type=AUDIT_ACTION_TYPE) | `Base.Domain/Models/SettingModels/MasterData.cs` | `GetMasterDatas` | `DataName` (filter by `MasterDataType.DataTypeCode = 'AUDIT_ACTION_TYPE'`) | `MasterDataResponseDto` | "Action Type" filter dropdown + action-pill color resolution |
| Status | MasterData (type=AUDIT_STATUS) | `Base.Domain/Models/SettingModels/MasterData.cs` | `GetMasterDatas` | `DataName` (filter by `DataTypeCode = 'AUDIT_STATUS'`) | `MasterDataResponseDto` | "Status" filter dropdown + status-badge resolution |
| Severity | MasterData (type=AUDIT_SEVERITY) | `Base.Domain/Models/SettingModels/MasterData.cs` | `GetMasterDatas` | `DataName` (filter by `DataTypeCode = 'AUDIT_SEVERITY'`) | `MasterDataResponseDto` | "Severity" filter dropdown |
| CompanyId (implicit) | Company | `Base.Domain/Models/ApplicationModels/Company.cs` | — | — | — | tenant scope from HttpContext via `TenantSaveChangesInterceptor` (write) and `httpContextAccessor.GetCurrentUserStaffCompanyId()` (read) |

> **No FK to "Entity"** — `EntityType` is a free string (logical name); `EntityId` is the source record's PK. Drill-down is constructed client-side using a `entityType → route` map (e.g. `Donation → /crm/donation/globaldonation`).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (filter validation)

### Immutability Contract (CORE INVARIANT)

- **No UPDATE allowed** — application service layer blocks any `UpdateAuditLog` or `DeleteAuditLog` call; if attempted, throw `InvalidOperationException("AuditLog records are immutable")`.
- **No soft-delete** — `IsDeleted` and `IsActive` are honored only at write (always `false`/`true`); never flipped after.
- **No CRUD endpoints exposed** — only `GetAuditTrailReport`, `GetAuditTrailById` (for detail panel), `GetAuditTrailSummary`, and `Export*` are registered. The conventional `Create/Update/Delete{Entity}` mutations do NOT exist for AuditLog.
- **The internal AuditLogWriter service** is the *only* code path that inserts AuditLog rows; it is called by the audit-capture interceptor and by explicit handler emits — never from user-triggered mutations.

### Required Filters

- **Date Range** is required — defaults to *Today* on first load. Quick-date chips (Today / Yesterday / This Week / This Month / Custom) update both date inputs.
- All other filters are optional.
- **At least one of** {Date Range, User, EntityType, EntityId} must be set when an admin tries to fetch beyond 30,000 rows (max-row guard prompts to narrow filters or use Excel export).

### Filter Validation

- Date range max 90 days for on-screen viewing — show inline error "Please narrow to 90 days or less" (longer ranges still allowed for Excel export).
- Date end must be ≥ Date start.
- User multi-select max 20 selections (perf ceiling; widget should show "+ N more" if exceeded).
- Search text max 200 chars; min 2 chars to trigger query (avoid 1-char broad searches).

### Row-Coloring Rules (FE)

- `Status = WARNING` → row background `#fffbeb`
- `Status = CRITICAL` or `FAILED` → row background `#fef2f2`
- `Status = SUCCESS` / `DENIED` → no background tint
- Apply on both Table view rows and Timeline-content border-left

### Role-Based Data Scoping (row-level security — BE)

| Role | Sees | Excluded |
|------|------|----------|
| BUSINESSADMIN | all rows for tenant | none |
| STAFFADMIN | rows where `UserId.BranchId IN (currentUser.AssignedBranches)` OR `EntityType.BranchId IN (currentUser.AssignedBranches)` | other branches' actions |
| FIELDAGENT / STAFFENTRY | rows where `UserId == currentUser.UserId` (only own actions) | everyone else's |
| (donor self-serve, etc.) | NOT applicable — audit trail is admin-only screen | full screen hidden |

> Implementation: scope filter applied in the BE query's `WHERE` based on `httpContextAccessor.GetCurrentUserId()` + role lookup. Never trust the client.

### Sensitive Data Handling

| Field | Sensitivity | Display Treatment | Export Treatment |
|-------|-------------|-------------------|------------------|
| ChangesJson (password-reset events) | secret | render `[redacted]` for any field key matching `password|token|secret` | excluded from CSV; admin-only PDF |
| IpAddress | PII (geolocatable) | full to BUSINESSADMIN; masked last-octet (`192.168.1.***`) for STAFFADMIN | full only in admin export |
| UserAgent / DeviceInfo | low PII | full to all roles | full to all roles |
| SessionId | secret | only show last 8 chars `…f2c91d` everywhere | never exported in raw form |

### Max-Row Guard

- On-screen render limit: 30,000 rows after filter applied → result region shows banner *"Result exceeds 30,000 rows — narrow filters or use Excel export"* with the Export Excel button highlighted.
- Excel export limit: 250,000 rows per file → beyond, queue async and email link (SERVICE_PLACEHOLDER if email service missing — see §⑫).

### Workflow

None. AuditLog has no lifecycle states. Each row is born `SUCCESS|WARNING|CRITICAL|FAILED|DENIED` and stays that way.

### Retention Policy (informational — not enforced by this screen)

- Hot retention: 2 years on the `AuditLog` table.
- Cold archival: years 3-7 in `AuditLogArchive` (out of scope for this screen — future job).
- Hard-delete: never (compliance contract).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions.

**Screen Type**: `REPORT`
**Report Sub-type**: `TABULAR` — primary view is a paginated transaction table; Timeline view is a *secondary visualization* of the same query (toggle, no re-fetch). Pivot/document patterns do not fit.
**Source Pattern**: `report-row-table` — AuditLog table persists every event; queries read from it.
**Pagination Strategy**: `server-paginate` — page size 50; estimated millions of rows over years means client-paginate is unsafe even at small filter scopes.

**Reason**: Audit data is high-volume, append-only, and queried across many filter axes. A `query-only` pattern would require synthesizing rows from N source tables at every read — impossible for events that have no source row (failed logins). A `report-row-table` with append-only writes via a capture layer is the only viable shape.

### Backend Patterns Required (TABULAR)

- [x] `GetAuditTrailReport` query — accepts filter args + pageNo/pageSize/sortField/sortDir; returns `{rows, totalCount, footerTotals}`.
- [x] `GetAuditTrailSummary` query — separate aggregate query for the 4 summary cards (count by date + by ActionType + by security categories).
- [x] `GetAuditTrailById` query — for the detail-panel slide-in (full record incl. ChangesJson, RelatedRecordsJson, CorrelationId-matched security timeline).
- [x] **AuditLogWriter service** — internal-only; the *only* code path that inserts rows. Methods: `WriteEntityChange(entityType, entityId, action, before, after, …)`, `WriteAuthEvent(userId, action, status, ip, ua, sessionId, …)`, `WriteExportEvent(userId, entityType, recordCount, …)`, `WriteWorkflowEvent(userId, entityType, entityId, transition, …)`.
- [x] **Audit capture mechanism** (cross-cutting) — extend `AuditableEntityInterceptor` (or add a sibling `AuditLogInterceptor`) that, post-`SaveChanges`, computes diff for Modified entities and emits an `AuditLog` row via `AuditLogWriter`. ALSO: explicit `AuditLogWriter.WriteAuthEvent` call sites in the auth handler (login success/failure/lock).
- [x] Tenant scoping (CompanyId from HttpContext on every query)
- [x] Role-based data filtering applied in WHERE clauses (per §④ Role table)
- [x] Footer totals computation — total actions in filtered set (row count footer)
- [ ] Excel export handler — **SERVICE_PLACEHOLDER unless ClosedXML/EPPlus is already in the codebase** (verify in build session; flag in §⑫)
- [ ] PDF export handler — **SERVICE_PLACEHOLDER** (no PDF service confirmed in repo)
- [x] CSV export handler — feasible without external service (server-side `StreamWriter`)
- [ ] Materialized-view refresh — N/A (source pattern is append-only table, not view)

### Frontend Patterns Required (TABULAR)

- [x] Report page shell (header + summary cards + filter panel + view-toggle bar + result region + detail panel + export menu)
- [x] **4 summary cards** above filter panel (Today's Actions / Active Users / Data Modifications / Security Events) — fed by `GetAuditTrailSummary`
- [x] **Info banner** under page header — "Audit records are immutable and cannot be modified or deleted" — static, persistent, accent-bg style
- [x] Filter panel — collapsible top, 7 controls (date range + 5 dropdowns + search), Apply / Clear / Save Filter buttons, quick-date chips
- [x] **View toggle** — Table View / Timeline View — same data, no re-fetch on switch
- [x] Result table component (`<AdvancedDataTable>` extension or custom — column set per mockup, action-pill cell renderer, status-badge cell renderer, row-color-class derived from Severity/Status)
- [x] **Timeline view component** — date-grouped, dot-colored-by-status, content cards with header (user + action-pill + status-badge) + description + meta line
- [x] **Detail slide-in panel** — width 480px, slides from right; sections: Record Information / User Information / Session Details / Changes (table) / Related Records / Security Timeline (for login events with CorrelationId-matched series)
- [x] Pagination (server-side, page-size 50)
- [x] Export menu (Excel / CSV / PDF / Print)
- [x] Print view CSS (`@media print` hides filters + view-toggle + summary cards; expands table to full page width; repeats header)
- [x] Empty state (filter-aware, e.g. "No audit records match Today + User=Ahmed + Action=Delete")
- [x] Max-row guard banner
- [x] Saved Filters (mockup shows "Save Filter" button — leverage existing SavedFilter entity if registry-#26 SavedFilter is COMPLETED; otherwise stub the button as SERVICE_PLACEHOLDER)
- [x] **Entity-link drill-down** — render `EntityType + EntityDisplayKey` as link mapped via `entityType → route` config

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Audit Trail is TABULAR — fill Block A only.

### 🎨 Visual Treatment Highlights

- **Layout Variant**: `widgets-above-grid` — 4 summary cards row + filter panel + result table. FE Dev should set `showHeader=false` on the AdvancedDataTable when using Variant B with ScreenHeader (avoid double-header — see ContactType #19 precedent).
- **Filter panel** is collapsible (mockup: chevron toggle in header). Default state on page load: **expanded**.
- **Action pills** carry semantic color (NOT random rainbow) — palette is fixed in mockup CSS:

  | Action | Pill BG | Pill FG |
  |--------|---------|---------|
  | Create | `#dcfce7` | `#166534` |
  | Update | `#dbeafe` | `#1e40af` |
  | Delete | `#fee2e2` | `#991b1b` |
  | Login | `#f3e8ff` | `#6b21a8` |
  | Export | `#fef3c7` | `#92400e` |
  | Send | `#ccfbf1` | `#115e59` |
  | Approve | `#d1fae5` | `#065f46` |

- **Status badges** match — Success green, Warning amber, Critical/Failed red, Denied slate.
- **Row coloring**: WARNING rows have `#fffbeb` background; CRITICAL/FAILED have `#fef2f2`. Apply on `<tr>` only when full row should be tinted.
- **Timeline dots** colored per status — success green border, warning amber, critical red.
- **System / Unknown users** displayed in italic secondary color (mockup convention) — System rendered in accent color, Unknown rendered in slate italic.
- **Empty state** is filter-aware: "No audit records match {filter summary}. Try widening Date Range or clearing {Status}."

**Anti-patterns to refuse:**
- Action pill colors that don't match the mockup palette (semantic mismatch)
- Detail panel as a modal (mockup is a slide-in side panel)
- Timeline view that re-queries the BE (it must reuse the table query result)
- Allowing any UI action that mutates an audit row (Edit / Delete / Bulk-edit) — even hidden behind a permission gate
- Drill-down that loses filter state on back-navigation (use Next.js router with shallow routing OR open in new tab)

---

### 🅰️ Block A — TABULAR (selected)

#### Page Header

| Element | Content |
|---------|---------|
| Breadcrumb | `Report & Audit › Audit › Audit Trail` |
| Page title | `Audit Trail` + `Admin` red badge (per mockup `.admin-badge`) |
| Subtitle | "Complete activity log of all system actions" |
| Right actions | `Export Log` (primary, `btn-accent`) + `Print` (outline) |

#### Info Banner (persistent, below header)

- Background `#ecfeff`, border `#a5f3fc`, accent text color
- Icon `fa-circle-info` + text *"Audit records are immutable and cannot be modified or deleted"*

#### Summary Cards (4 cards in a row)

| # | Card Title | Icon | Color | Metric | Subtitle |
|---|------------|------|-------|--------|----------|
| 1 | Today's Actions | `fa-clock` | accent | total count today | "Peak hour: {HH AM/PM} ({N} actions)" — derived from hourly histogram aggregate |
| 2 | Active Users Today | `fa-user-check` | accent | distinct users today / total registered | "{pct}% of registered users" |
| 3 | Data Modifications | `fa-pen` | accent | count of CREATE+UPDATE+DELETE today | "Creates: {C} · Updates: {U} · Deletes: {D}" |
| 4 | Security Events | `fa-shield` | danger (red) | count of LOGIN_FAILED+PASSWORD_RESET+ROLE_CHANGE+ACCOUNT_LOCKED today | "{X} failed logins, {Y} password resets, {Z} role changes" — value rendered in danger color when > 0 |

> Cards are **read-only** display widgets. Clicking a card does NOT filter the table (different scope decision from Communication Dashboard #125 — these counts are advisory, not interactive). If the build session disagrees, log it as ISSUE-X in §⑬.

#### Filter Panel (collapsible)

**Position**: `top-collapsible` — header bar with chevron toggle; default `expanded`.

| # | Filter | Widget | Default | Required | Group | Options Source | Validation |
|---|--------|--------|---------|----------|-------|----------------|------------|
| 1 | Date Range | dual date input + 5-chip quick-select (Today / Yesterday / This Week / This Month / Custom) | Today | YES | Date | — | start ≤ end, ≤ 90 days for on-screen |
| 2 | User | ApiSelectV2 (single) | All Users | NO | User | `GetUsers` (display: UserName; pre-pend "System" + "Unknown" virtual options) | — |
| 3 | Action Type | dropdown (multi) | All Actions | NO | Action | `GetMasterDatas` filtered by `DataTypeCode='AUDIT_ACTION_TYPE'` | — |
| 4 | Entity / Module | dropdown (single) | All Modules | NO | Entity | `GetModules` (or distinct `EntityType` enum from AuditLog) | — |
| 5 | Status | dropdown (single) | All Statuses | NO | Status | `GetMasterDatas` filtered by `DataTypeCode='AUDIT_STATUS'` | — |
| 6 | Severity | dropdown (single) | All Severities | NO | Severity | `GetMasterDatas` filtered by `DataTypeCode='AUDIT_SEVERITY'` | — |
| 7 | Search | text input | "" | NO | Search | — | min 2 chars; max 200 |

**Filter actions** (separated by top border at the bottom of the body):
- `Apply` (primary) — refetches both summary + table queries
- `Clear` (outline) — resets to defaults
- `Save Filter` (outline) — opens "name + share-with-team" dialog → POST to existing `SavedFilter` entity (registry #26)

#### View Toggle Bar (between filter panel and result region)

- Left: segmented button group `Table View` / `Timeline View` — default `Table`
- Right: contextual hint `"Showing results for {dateRangeSummary}"` (auto-updates when Apply runs)

> Toggle does NOT re-fetch — both views render from the same paginated result set held in component state.

#### Result Table (Table View)

**Display Type**: tabular, paginated
**Page Size**: 50 (no per-page-size selector in mockup — fixed)
**Default Sort**: `Timestamp DESC`

| # | Header | Field Key | Display Type | Width | Align | Sortable | Notes |
|---|--------|-----------|--------------|-------|-------|----------|-------|
| 1 | Timestamp | timestamp | "MMM dd, h:mm:ss A" (local TZ) | 130px | left | YES | secondary text color |
| 2 | User | userDisplayName | text | 140px | left | YES | bold; "System" rendered in accent color; "Unknown" rendered slate italic |
| 3 | Action | actionType | action-pill | 100px | left | YES | semantic color per palette above |
| 4 | Entity | entityDisplayKey | entity-link OR plain text | auto | left | NO | link when `entityType` is mapped to a route; plain otherwise (e.g., "User: test@ghf.org") |
| 5 | Description | description | text (ellipsis on overflow, max 280px) | auto | left | NO | tooltip on hover for truncated text |
| 6 | IP Address | ipAddress | monospace | 120px | left | NO | "—" rendered for null |
| 7 | Status | status | status-badge | 100px | left | YES | semantic color |
| 8 | Details | — | "View" button | 90px | center | NO | opens detail slide-in panel |

**Footer Totals**: `Showing 1–50 of {totalCount} entries` — left side; pagination buttons right side.

**Drill-down (per row)**:
- Click on `entityDisplayKey` (when link) → navigate to source record's detail view in new tab. Map (extend in build):
  - `Donation → /[lang]/crm/donation/globaldonation?mode=read&id={entityId}`
  - `Contact → /[lang]/crm/contact/allcontacts?mode=read&id={entityId}`
  - `Receipt → /[lang]/crm/donation/{path}?mode=read&id={entityId}` (TBD path)
  - `FieldCollection → /[lang]/crm/fieldcollection/collectionlist?mode=read&id={entityId}`
  - `Role → /[lang]/accesscontrol/usersroles/role?mode=read&id={entityId}` (when CRUD exists)
  - `User → /[lang]/accesscontrol/usersroles/user?mode=read&id={entityId}` (when CRUD exists)
- Click on `View` button → opens detail slide-in panel

#### Result Timeline (Timeline View)

- Day header (e.g. "April 12, 2026") with calendar icon, top-border 2px
- Time-ordered items, each with:
  - Time column (right-aligned, 70px, `h:mm AM/PM`)
  - Connector dot (12px, color = success/warning/critical per status; vertical connector line between items)
  - Content card with:
    - Header row: user name + action-pill + status-badge
    - Description line (with embedded entity-links)
    - Meta line: IP/`fa-globe` for human users, `fa-robot` "Automated" for System events, `fa-triangle-exclamation Security Alert` for critical
  - Card border-left 3px solid in warning/critical colors
- No pagination control — Timeline shows the same page (50 rows) the table is currently displaying. User must paginate via Table view to see older.

#### Detail Slide-In Panel (480px, right edge)

Sections (in order):

1. **Record Information**
   - Audit ID (monospace) — `AUD-{yyyyMMdd}-{seq6}`
   - Action — action-pill
   - Entity — entity-link or text
   - Status — status-badge
   - Attempt (`{N} of 5`) — only when ActionType is LOGIN_FAILED / ACCOUNT_LOCKED, colored per severity

2. **User Information** (skip when UserId is null / System)
   - User (UserDisplayName)
   - Email (UserEmail)
   - Role (UserRoleName)

3. **Session Details / Connection Details**
   - Timestamp (with TZ — UTC offset)
   - IP Address (monospace)
   - Geolocation (if non-null)
   - Device (DeviceInfo)
   - User Agent (small font, full UA string)
   - Session ID (last 8 chars only, monospace)
   - Failure Reason (only when status WARNING/CRITICAL/FAILED, colored per severity)

4. **Changes** (only when ActionType=UPDATE and ChangesJson is present)
   - 3-column table: Field / Before / After
   - Before cells: red-tinted bg `#fef2f2`, fg `#991b1b`
   - After cells: green-tinted bg `#dcfce7`, fg `#166534`
   - Render `[redacted]` for password / token / secret field keys

5. **Related Records** (only when RelatedRecordsJson present — for CREATE/UPDATE/DELETE)
   - Each related record is a clickable row: icon + display name + sub-line (donor / campaign / period)
   - Click navigates to the related entity's detail page (uses same entityType→route map)

6. **Security Timeline** (only for LOGIN-family events when CorrelationId is set)
   - Server query: pull all AuditLog rows with same CorrelationId, ordered by Timestamp ASC
   - Render as vertical timeline with colored dots per severity (info / warning / critical)
   - Each event: bold time + reason + IP

**Critical alert banner** (top of body, when status=CRITICAL): red-tinted card "Account has been automatically locked due to excessive failed login attempts" + `fa-lock` icon.

**Close**: `Esc` key, click overlay, or X button.

#### Export Actions

| Action | Format | Handler | Notes |
|--------|--------|---------|-------|
| Export Log (header button) | opens menu: Excel / CSV / PDF | — | menu |
| Excel | .xlsx (formatted: bold header, frozen first row, monospace IP, color-coded status cells) | `ExportAuditTrailExcel` | SERVICE_PLACEHOLDER until ClosedXML availability is verified |
| CSV | .csv (plain rows, all columns, no formatting) | `ExportAuditTrailCsv` | feasible — pure StreamWriter |
| PDF | .pdf (multi-page table with repeated header + page footer) | `ExportAuditTrailPdf` | SERVICE_PLACEHOLDER (no PDF service confirmed) |
| Print (header button) | print-CSS rendered | browser print | feasible — pure CSS |

**Export-event self-audit**: Every successful Export call MUST itself emit an AuditLog row with `ActionType=EXPORT`, `EntityType='AuditLog'`, `Description="Exported {N} audit records as {format} ({filterSummary})"`. This is the recursive "audit who exported the audit" rule (compliance contract).

#### User Interaction Flow

1. User opens the screen → page loads with Today's data + 4 summary cards already rendered (concurrent fetches — table query + summary query)
2. User reviews summary cards, expands filter panel, picks "This Week" + User="Ahmed Salim" → clicks Apply → both queries refetch
3. User toggles to Timeline View → no fetch, same 50 rows render as time-grouped cards
4. User clicks `View` on a row → detail slide-in panel opens with full record + (if applicable) Changes table + Security Timeline
5. User clicks an entity-link → opens source record in new tab (filter state preserved on this screen)
6. User clicks "Save Filter" → dialog → name + share-with-team toggle → saves to SavedFilter
7. User clicks Export Log → menu → Excel → handler runs → file downloads + a self-audit row is written
8. User clicks Print → print-preview matches on-screen layout sans filter / view-toggle / summary cards

---

### Shared blocks

#### Empty / Loading / Error / Max-Row States

| State | Trigger | UI |
|-------|---------|----|
| Initial | First load (Today filter default) | Skeleton matching summary cards (4 boxes) + table-shape skeleton (10 rows × 8 cols) |
| Loading | Apply clicked | Skeleton swap; existing rows fade |
| Empty | Zero rows | Card with "No audit records match {filterSummary}. Try widening Date Range or clearing {Status}." |
| Error | Query fails | Error card with retry + error code (compliance: never silent fail) |
| Max-row exceeded | totalCount > 30,000 | Banner above result region: "Result exceeds 30,000 rows — narrow filters or use Excel export" + Export Excel highlighted |

#### Print View CSS

- Hide: page-header right actions, info banner (already too small to print), filter panel, view-toggle bar, summary cards section, detail panel, sidebar/nav
- Result region expands full width
- Table: `thead { display: table-header-group }` (header repeats per page)
- Action pills + status badges keep colors via `-webkit-print-color-adjust: exact`
- Add print-only `<div>` at bottom: "Generated: {now}, Filters: {summary}, Page {n}"

#### Schedule

Not in mockup — **out of scope** for this build. (If raised post-build, add as ENHANCE session in §⑬.)

---

## ⑦ Substitution Guide

> **First TABULAR REPORT** — this entry sets the canonical reference. After this screen
> COMPLETED, replace TBD entries in `_REPORT.md` §⑦ and `_COMMON.md` substitution table.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| AuditLog | AuditLog | Entity name (PascalCase) |
| auditLog | auditLog | camelCase / variable / GQL field root |
| audit-log | audit-log | kebab-case URL fragment (NOT used here — route uses `audittrail`) |
| AuditTrail | AuditTrail | Display / report name |
| audittrail | audittrail | lowercase route segment |
| AUDITTRAIL | AUDITTRAIL | UPPER_CASE menu code |
| ReportAudit | ReportAudit | Group folder name root |
| `app` | `app` | DB schema (shared application schema) |
| ReportAuditBusiness | ReportAuditBusiness | Backend group folder (`Base.Application/Business/{Group}`) |
| ReportAuditModels | ReportAuditModels | Backend domain models folder (`Base.Domain/Models/{Group}`) |
| ReportAuditSchemas | ReportAuditSchemas | Backend application schemas folder (`Base.Application/Schemas/{Group}`) |
| ReportAuditConfigurations | ReportAuditConfigurations | Backend EF config folder |
| ReportAudit | ReportAudit | Endpoint folder (`Base.API/EndPoints/{Group}`) |
| RA_AUDIT | RA_AUDIT | Parent menu code |
| REPORTAUDIT | REPORTAUDIT | Module code |
| `reportaudit/audit/audittrail` | `reportaudit/audit/audittrail` | FE route path |
| reportaudit | reportaudit | FE module folder (`src/app/[lang]/reportaudit/`) |
| audit | audit | FE feature folder under module |

> **Note**: The first TABULAR REPORT establishes that REPORT-style screens follow the `{Module}{Feature}Business` group convention (`ReportAuditBusiness`), distinct from the standalone `{Feature}Business` convention used by MASTER_GRID/FLOW screens (e.g., `ContactBusiness`). Subsequent REPORT screens in other modules (e.g., a CRM `DonationSummaryReport`) should follow `ReportCrmBusiness` or join existing `ReportBusiness` — to be decided when the second TABULAR REPORT lands.

---

## ⑧ File Manifest

### Backend Files (NEW — first ReportAuditBusiness folder)

| # | File | Path |
|---|------|------|
| 1 | AuditLog Entity | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ReportAuditModels/AuditLog.cs` |
| 2 | AuditLog EF Config | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/ReportAuditConfigurations/AuditLogConfiguration.cs` |
| 3 | EF Migration | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Migrations/{N}_Add_AuditLog.cs` (auto-generated by `dotnet ef migrations add`) |
| 4 | Audit Trail Schemas (DTO + Filter + Row + Summary) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/ReportAuditSchemas/AuditTrailSchemas.cs` |
| 5 | Get Report Query | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ReportAuditBusiness/AuditLogs/Queries/GetAuditTrailReport.cs` |
| 6 | Get Summary Query | `…/ReportAuditBusiness/AuditLogs/Queries/GetAuditTrailSummary.cs` |
| 7 | Get By ID Query (detail panel) | `…/ReportAuditBusiness/AuditLogs/Queries/GetAuditTrailById.cs` |
| 8 | Get Correlation Series Query (detail-panel security timeline) | `…/ReportAuditBusiness/AuditLogs/Queries/GetAuditTrailByCorrelation.cs` |
| 9 | Excel Export Handler | `…/ReportAuditBusiness/AuditLogs/ReportExport/ExportAuditTrailExcel.cs` |
| 10 | CSV Export Handler | `…/ReportAuditBusiness/AuditLogs/ReportExport/ExportAuditTrailCsv.cs` |
| 11 | PDF Export Handler (PLACEHOLDER) | `…/ReportAuditBusiness/AuditLogs/ReportExport/ExportAuditTrailPdf.cs` |
| 12 | **AuditLogWriter Service Interface** | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Common/Interfaces/IAuditLogWriter.cs` |
| 13 | **AuditLogWriter Service Implementation** | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Services/AuditLogWriter.cs` |
| 14 | **AuditLogInterceptor** (extends AuditableEntityInterceptor pattern; emits AuditLog rows on SaveChanges for tracked entity types) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Interceptors/AuditLogInterceptor.cs` |
| 15 | Queries Endpoint | `Pss2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/ReportAudit/Queries/AuditTrailQueries.cs` |
| 16 | Mutations Endpoint (export commands) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/ReportAudit/Mutations/AuditTrailMutations.cs` |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Base.Domain/Common/IApplicationDbContext.cs` | `DbSet<AuditLog> AuditLogs { get; }` |
| 2 | `Base.Infrastructure/Data/ApplicationDbContext.cs` | DbSet entry + register `AuditLogConfiguration` |
| 3 | `Base.Infrastructure/DependencyInjection.cs` | Register `IAuditLogWriter` → `AuditLogWriter` (scoped) + register `AuditLogInterceptor` in DbContextOptions |
| 4 | `Base.Application/Common/Mappings/MappingConfig.cs` (or `ReportAuditMappings`) | Mapster mapping `AuditLog ↔ AuditTrailRowDto`, `AuditLog ↔ AuditTrailDetailDto` |
| 5 | Auth handler(s) — `LoginCommand.cs`, `RefreshTokenCommand.cs`, lockout handler | Inject `IAuditLogWriter` + emit `WriteAuthEvent` calls (Login success, Login failed, Account locked, Password reset) |
| 6 | `Base.API/Program.cs` (or `Startup`) | Register `AuditTrailQueries` + `AuditTrailMutations` in GraphQL endpoint |

### Frontend Files

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/reportaudit-service/AuditTrailDto.ts` |
| 2 | GQL Queries | `Pss2.0_Frontend/src/infrastructure/gql-queries/reportaudit-queries/AuditTrailQueries.ts` |
| 3 | GQL Mutations (Export) | `Pss2.0_Frontend/src/infrastructure/gql-queries/reportaudit-queries/AuditTrailMutations.ts` |
| 4 | Page Config | `Pss2.0_Frontend/src/presentation/pages/reportaudit/audit/audittrail.tsx` |
| 5 | Report Page Component | `Pss2.0_Frontend/src/presentation/page-components/reportaudit/audit/audittrail/report-page.tsx` |
| 6 | Summary Cards | `…/audittrail/components/summary-cards.tsx` |
| 7 | Filter Panel | `…/audittrail/components/filter-panel.tsx` |
| 8 | View Toggle Bar | `…/audittrail/components/view-toggle-bar.tsx` |
| 9 | Result Table | `…/audittrail/components/result-table.tsx` |
| 10 | Result Timeline | `…/audittrail/components/result-timeline.tsx` |
| 11 | Detail Slide-In Panel | `…/audittrail/components/detail-panel.tsx` |
| 12 | Action Pill | `…/audittrail/components/action-pill.tsx` |
| 13 | Status Badge | `…/audittrail/components/status-badge.tsx` |
| 14 | Entity Link Renderer (with route map) | `…/audittrail/components/entity-link.tsx` |
| 15 | Export Menu | `…/audittrail/components/export-menu.tsx` |
| 16 | Print Styles | `…/audittrail/components/print-styles.module.css` |
| 17 | Route Page (REPLACE existing stub) | `Pss2.0_Frontend/src/app/[lang]/reportaudit/audit/audittrail/page.tsx` |

> **Existing FE route**: `[lang]/reportaudit/audit/audittrail/page.tsx` currently contains `<UnderConstruction />`. Replace, don't add a sibling.

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Pss2.0_Frontend/src/presentation/configs/entity-operations.ts` | `AUDITTRAIL_REPORT` operations config (READ + EXPORT only — no CRUD operations) |
| 2 | `Pss2.0_Frontend/src/presentation/configs/operations-config.ts` | Import + register `AUDITTRAIL_REPORT` |
| 3 | Sidebar / nav menu config (if not driven by DB Menu seed) | Menu entry: `Report & Audit › Audit › Audit Trail` |

### DB Seed Files

| # | File | Path |
|---|------|------|
| 1 | Menu + module + capabilities + role-capabilities seed | `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/AuditTrail-sqlscripts.sql` |
| 2 | MasterDataType + MasterData seeds (3 types: AUDIT_ACTION_TYPE, AUDIT_STATUS, AUDIT_SEVERITY) | bundled in same file |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: Audit Trail
MenuCode: AUDITTRAIL
ParentMenu: RA_AUDIT
Module: REPORTAUDIT
MenuUrl: reportaudit/audit/audittrail
GridType: REPORT

MenuCapabilities: READ, EXPORT, PRINT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, EXPORT, PRINT

GridFormSchema: SKIP
GridCode: AUDITTRAILREPORT
---CONFIG-END---
```

> **Capabilities reasoning**:
> - `READ` — view the report
> - `EXPORT` — Excel / CSV / PDF download (gated; non-admins denied)
> - `PRINT` — separate from EXPORT to allow some roles to print without exporting
> - **NO** CREATE / MODIFY / DELETE — audit records are immutable per the info banner
> - Other roles (STAFFADMIN, FIELDAGENT, …) have no access by default — audit trail is admin-only. If a future role needs scoped read, add it via `/continue-screen`.

> **MasterData seeds** (bundled in same SQL):
> - `AUDIT_ACTION_TYPE` — 14 rows: CREATE / UPDATE / DELETE / LOGIN / LOGOUT / LOGIN_FAILED / ACCOUNT_LOCKED / EXPORT / IMPORT / SEND / APPROVE / REJECT / ROLE_CHANGE / PASSWORD_RESET
> - `AUDIT_STATUS` — 5 rows: SUCCESS / WARNING / CRITICAL / FAILED / DENIED
> - `AUDIT_SEVERITY` — 4 rows: LOW / MEDIUM / HIGH / CRITICAL

---

## ⑩ Expected BE→FE Contract

### Queries

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getAuditTrailReport` | `AuditTrailReportDto` | `dateFrom`, `dateTo`, `userId?`, `actionTypes?: [string]`, `entityType?`, `moduleId?`, `status?`, `severity?`, `searchText?`, `pageNo`, `pageSize`, `sortField?`, `sortDir?` |
| `getAuditTrailSummary` | `AuditTrailSummaryDto` | `dateFrom`, `dateTo` (same date filters as report; other filters do NOT apply to summary cards — they always reflect the date scope) |
| `getAuditTrailById` | `AuditTrailDetailDto` | `auditLogId` |
| `getAuditTrailByCorrelation` | `[AuditTrailRowDto]` | `correlationId` (for detail-panel security timeline) |
| `getUsers` | `[UserResponseDto]` | (existing — for user filter dropdown) |
| `getModules` | `[ModuleResponseDto]` | (existing — for module filter dropdown) |
| `getMasterDatas` | `[MasterDataResponseDto]` | `dataTypeCode` (existing — used 3× for ActionType/Status/Severity) |

### Mutations

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `exportAuditTrailExcel` | `AuditTrailExportInput` (same filter shape as report) | `string` (file URL or base64) — **SERVICE_PLACEHOLDER until generator confirmed** |
| `exportAuditTrailCsv` | `AuditTrailExportInput` | `string` (file URL or base64) |
| `exportAuditTrailPdf` | `AuditTrailExportInput` | `string` — **SERVICE_PLACEHOLDER** |

### DTO: `AuditTrailReportDto`

| Field | Type | Notes |
|-------|------|-------|
| rows | `[AuditTrailRowDto]` | result rows |
| totalCount | int | for pagination |
| filterSummary | string | human-readable applied filters (used for export header + empty-state message) |
| maxRowExceeded | bool | true when totalCount > 30,000 |

### DTO: `AuditTrailRowDto`

| Field | Type | Notes |
|-------|------|-------|
| auditLogId | int | PK (used as React key + detail panel arg) |
| auditNo | string | display number |
| timestamp | string (ISO 8601 UTC) | FE converts to local TZ for display |
| userId | int? | null for System/Unknown |
| userDisplayName | string | denormalized |
| userKind | string | enum `USER` / `SYSTEM` / `UNKNOWN` (drives FE color + italic) |
| actionType | string | one of the AUDIT_ACTION_TYPE codes |
| actionLabel | string | resolved from MasterData |
| actionColorKey | string | `create` / `update` / … (matches CSS class fragment) |
| entityType | string | logical name |
| entityId | int? | nullable |
| entityDisplayKey | string | denormalized human key |
| entityRoute | string? | resolved entity-link route (server-side via map; null when no route exists) |
| description | string | human narrative |
| ipAddress | string? | nullable |
| status | string | code |
| statusLabel | string | resolved label |
| statusColorKey | string | `success` / `warning` / … |
| severity | string | code |
| rowSeverityClass | string? | `row-warning` / `row-critical` / null |

### DTO: `AuditTrailDetailDto` (extends RowDto)

Includes everything in RowDto plus:

| Field | Type | Notes |
|-------|------|-------|
| userEmail | string? | — |
| userRoleName | string? | — |
| deviceInfo | string? | — |
| userAgent | string? | — |
| sessionIdMasked | string? | last 8 chars only (BE applies the mask) |
| geoLocation | string? | — |
| changes | `[FieldChangeDto]` | `{field, before, after}` — empty array when no ChangesJson |
| relatedRecords | `[RelatedRecordDto]` | `{entityType, entityId, displayKey, subtitle, route?}` |
| failureReason | string? | — |
| attemptNumber | int? | — |
| correlationId | string? | guid — used by FE to fetch security timeline |
| isAccountLocked | bool | derived: status=CRITICAL AND actionType=ACCOUNT_LOCKED |

### DTO: `AuditTrailSummaryDto`

| Field | Type | Notes |
|-------|------|-------|
| dateRangeLabel | string | "Today" / "Yesterday" / "This Week" / formatted custom |
| todayActions | `{count: int, peakHourLabel: string, peakHourCount: int}` | card 1 |
| activeUsers | `{distinctActive: int, totalRegistered: int, percentage: number}` | card 2 |
| dataModifications | `{total: int, creates: int, updates: int, deletes: int}` | card 3 |
| securityEvents | `{total: int, failedLogins: int, passwordResets: int, roleChanges: int, accountLocks: int}` | card 4 |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] EF migration `{N}_Add_AuditLog` applies cleanly to a fresh DB
- [ ] `pnpm dev` — page loads at `/[lang]/reportaudit/audit/audittrail` and replaces existing stub
- [ ] No GraphQL schema errors at startup; queries + mutations registered

**Functional Verification (Full E2E — MANDATORY):**

### TABULAR
- [ ] 4 summary cards render with live counts (verify with seeded test data: at least 1 of each ActionType from yesterday + today)
- [ ] Info banner persistent under header
- [ ] Filter panel renders all 7 filters with defaults; quick-date chips work; collapse-toggle works
- [ ] Apply triggers concurrent fetch of report + summary; loading skeleton matches table+cards shape
- [ ] Result table renders 8 columns with correct widths + alignments
- [ ] Action pills render with semantic colors per palette table
- [ ] Status badges render with semantic colors
- [ ] Row colorization: WARNING rows tinted amber, CRITICAL/FAILED rows tinted red; SUCCESS/DENIED rows uncolored
- [ ] System users render in accent color; Unknown users render slate-italic
- [ ] Sort by Timestamp / User / Action / Status — server-side fetch refreshes
- [ ] Pagination: 50 per page; page navigation triggers fetch with state preserved
- [ ] **View toggle Table ↔ Timeline switches in <50ms with NO re-fetch**
- [ ] Timeline view groups by date with header divider; dots colored per status
- [ ] Detail panel slides in 300ms from right (480px); Esc / X / overlay-click closes
- [ ] Detail panel renders all 6 sections conditionally based on event type
- [ ] Update events: Changes table renders before/after with red/green tinting; password fields rendered `[redacted]`
- [ ] Login events with CorrelationId: Security Timeline section renders correlated series
- [ ] Account-Lock events: red alert banner at top of detail body
- [ ] Entity-link drill-down navigates to source record in new tab; mapped routes work
- [ ] Print: filter panel + view-toggle + summary cards hidden; table fits page width; thead repeats; action pills + status badges keep colors via `-webkit-print-color-adjust`
- [ ] Empty state diagnostic (e.g. `"No audit records match Today + User=Ahmed + Action=Delete"`)
- [ ] Max-row guard kicks in at 30,000 rows + offers Excel export
- [ ] Excel export — verify file generated OR SERVICE_PLACEHOLDER toast appears
- [ ] CSV export produces plain rows; opens in Excel without warnings
- [ ] PDF export — verify SERVICE_PLACEHOLDER toast (or real file if generator wired)
- [ ] **Self-audit check**: After exporting, refresh the screen — a new EXPORT row exists for the export action just performed
- [ ] Role-scoped data: BUSINESSADMIN sees all rows; STAFFADMIN sees only own-branch rows; FIELDAGENT sees only own actions
- [ ] **Immutability check**: No UI exposes Edit / Delete on any row; backend `UpdateAuditLog`/`DeleteAuditLog` mutations do NOT exist (verify in GraphQL schema explorer)
- [ ] Sensitive fields masked correctly: SessionId shows last 8 chars only; password change-events show `[redacted]`; STAFFADMIN sees masked-last-octet IPs

### Audit Capture Infrastructure (NEW — verify in build session)
- [ ] **Login success** → 1 AuditLog row with ActionType=LOGIN, Status=SUCCESS
- [ ] **3 failed logins** → 3 AuditLog rows with ActionType=LOGIN_FAILED, Status=WARNING, AttemptNumber=1/2/3, all sharing one CorrelationId
- [ ] **5th failed login** → 1 LOGIN_FAILED row with AttemptNumber=5 + 1 ACCOUNT_LOCKED row with Status=CRITICAL, both sharing the same CorrelationId
- [ ] **Donation amount update** → 1 AuditLog row with ActionType=UPDATE, EntityType=Donation, EntityId set, ChangesJson populated with `{field: "Amount", before, after}`
- [ ] **Contact create** → 1 AuditLog row with ActionType=CREATE
- [ ] **Donation delete** → 1 AuditLog row with ActionType=DELETE
- [ ] **Role capability change** → 1 AuditLog row with ActionType=ROLE_CHANGE, Severity=HIGH
- [ ] **Email campaign send** → 1 AuditLog row with ActionType=SEND, EntityType=EmailCampaign
- [ ] **Field collection approve** → 1 AuditLog row with ActionType=APPROVE

**DB Seed Verification:**
- [ ] Menu visible in sidebar at `Report & Audit › Audit › Audit Trail` (BUSINESSADMIN only)
- [ ] MasterData seeds present: AUDIT_ACTION_TYPE (14 rows), AUDIT_STATUS (5 rows), AUDIT_SEVERITY (4 rows)
- [ ] Page renders without crashing on a freshly-seeded DB (empty AuditLog table → all summary cards show 0; empty-state on table)

---

## ⑫ Special Notes & Warnings

### CRITICAL: Audit Capture Infrastructure Build-out

This screen is the *first* in the registry to require a **cross-cutting capture mechanism**. Building the Audit Trail screen alone (entity + query + UI) is incomplete — without the capture layer there is no data to display. Build session MUST include:

1. **`IAuditLogWriter` service** — single insert path; methods:
   - `WriteEntityChange(string entityType, int entityId, string action, object? before, object? after, string? description = null)`
   - `WriteAuthEvent(int? userId, string action, string status, string ip, string ua, string? sessionId, string? correlationId = null, int? attemptNumber = null, string? failureReason = null)`
   - `WriteExportEvent(int userId, string entityType, int recordCount, string format, string filterSummary)`
   - `WriteWorkflowEvent(int userId, string entityType, int entityId, string transition, string? description = null)`
   Implementation: open a separate scoped DbContext write (do NOT enlist in caller's transaction — audit must persist even if the caller's transaction rolls back).

2. **`AuditLogInterceptor`** — extends the existing `AuditableEntityInterceptor` pattern. Hooks `SaveChangesAsync` *post-save*, scans the `ChangeTracker.Entries()` for tracked entity types (configured via attribute `[Auditable]` or a registered list), computes diff for Modified entities, calls `_auditLogWriter.WriteEntityChange(...)`. Skip auditing of: AuditLog itself (avoid recursion), MasterData reads, password-hash columns (substitute `[redacted]`).

3. **Auth event hooks** — explicit `_auditLogWriter.WriteAuthEvent` calls in:
   - `LoginCommand.Handle` (success path → ActionType=LOGIN, Status=SUCCESS)
   - `LoginCommand.Handle` (failure path → ActionType=LOGIN_FAILED, Status=WARNING; if attempt ≥ 5 also ACCOUNT_LOCKED with Status=CRITICAL; share CorrelationId across the chain)
   - Logout / refresh-token-revoke handler
   - Password-reset handler

4. **Export event hook** — every `Export*` mutation handler ends with `_auditLogWriter.WriteExportEvent(...)`.

5. **Workflow event hook** — Approve/Reject/Submit handlers call `_auditLogWriter.WriteWorkflowEvent(...)`.

> **DO NOT defer this**. A "screen built but no data source" is worse than no screen — it ships broken.

### Universal REPORT Warnings

- `screen_type: REPORT` and `GridFormSchema: SKIP` — no RJSF, custom UI.
- Tenant scoping in BE on every query.
- Footer total = total filtered rows (separate aggregate query OR `totalCount`), not just current page.
- Drill-down preserves filter state via Next.js shallow routing or open-in-new-tab.

### Service Dependencies (UI built in full; backend service layer mocked where noted)

- ⚠ **SERVICE_PLACEHOLDER**: **Excel export** — verify in build session whether `ClosedXML` / `EPPlus` is in the backend csproj. If absent, handler returns a mocked URL + FE shows a toast `"Excel export coming soon — service not yet wired"`. Full UI (Export button, menu, file naming) implemented.
- ⚠ **SERVICE_PLACEHOLDER**: **PDF export** — no PDF generation service confirmed in repo. Handler returns mocked URL + toast.
- ⚠ **SERVICE_PLACEHOLDER**: **IP geolocation** — `GeoLocation` field nullable; populated only when an IP-geo service is wired (e.g., MaxMind, IPInfo). Build session inserts `null` for now; future enhancement adds the lookup.
- ⚠ **SERVICE_PLACEHOLDER**: **Async export beyond 250k rows** — emits "Export queued — link will be emailed when ready" toast; no actual async job. Implement when job runner exists.
- ⚠ **SERVICE_PLACEHOLDER (CONDITIONAL)**: **Save Filter** — depends on registry-#26 SavedFilter status. If COMPLETED, wire to existing entity. If not, render the button + dialog but do not POST; toast `"Saving filters available once Saved Filters feature ships"`.

### Sub-type-specific Gotchas

- **Action pill colors** must match the mockup palette exactly (semantic — wrong colors break the visual contract that admins rely on for skim-reading).
- **Timeline view re-fetch is wrong** — toggle is pure FE state; both views render the same `rows` array.
- **Detail panel as modal is wrong** — must be a slide-in side panel (480px, right edge, 300ms transition).
- **System / Unknown user rendering** — System in accent color, Unknown in slate-italic; both bypass the regular `GetUsers` resolution (UserId = null).
- **Recursive audit emission** — every export mutation emits an EXPORT row. Beware infinite recursion: do NOT audit the AuditLog read query, do NOT audit the AuditLog write itself.
- **CorrelationId for security timelines** — failed-login series MUST share one CorrelationId; without it, the detail-panel Security Timeline section can't render the chain.

### Module / Wiring Notes

- **Group is NEW**: `ReportAuditBusiness` is the first business folder under this group. Create folders `ReportAuditBusiness/AuditLogs/{Queries,ReportExport}` and `ReportAuditModels`, `ReportAuditSchemas`, `ReportAuditConfigurations`, `Base.API/EndPoints/ReportAudit/{Queries,Mutations}`. No existing convention to mimic — first builder establishes structure.
- **Existing FE route** `[lang]/reportaudit/audit/audittrail/page.tsx` is a `<UnderConstruction />` stub — REPLACE the file content; do NOT add a sibling.
- **Module REPORTAUDIT** already exists in `Module_Menu_List.sql`; menu entry `AUDITTRAIL` under `RA_AUDIT` (MenuId 382) is also defined. Build session only needs to add the row — it doesn't need to register a new module.
- **Existing audit infra reused**: `Entity` base class, `AuditableEntityInterceptor` (CreatedBy/ModifiedBy stamping), `TenantSaveChangesInterceptor` (CompanyId stamping), `IHttpContextAccessor.GetCurrentUserStaffCompanyId()` extension.
- **DateTime UTC normalization**: existing `AuditableEntityInterceptor` already normalizes DateTimes to UTC — AuditLog inherits this behavior. FE converts UTC to local TZ for display.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — no issues raised yet) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}
