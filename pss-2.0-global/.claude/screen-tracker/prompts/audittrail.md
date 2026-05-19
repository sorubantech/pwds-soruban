---
screen: AuditTrail
registry_id: 74
module: Report & Audit
status: COMPLETED
scope: FULL
screen_type: REPORT
report_subtype: TABULAR
source_pattern: report-row-table
pagination_strategy: server-paginate
complexity: High
new_module: NO — module REPORTAUDIT exists; new Group folder ReportAuditBusiness + new Schema folder ReportAuditSchemas
planned_date: 2026-05-10
completed_date: 2026-05-16
last_session_date: 2026-05-20
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
- [x] BA Analysis validated (audience, frequency, decisions, data sensitivity, retention policy — embedded in §①–④, no re-analysis needed)
- [x] Solution Resolution complete (TABULAR sub-type confirmed; capture-mechanism strategy confirmed: interceptor + IAuditLogWriter + MediatR pipeline behavior — DEVIATES from prompt §⑫ literal per user-approved scope)
- [x] UX Design finalized (filter panel + summary cards + table view + timeline view + detail panel + export menu — all 13 components built)
- [x] User Approval received (scope adjustments: pipeline behavior replaces 50+ per-handler edits; ACCOUNT_LOCKED deferred; Excel/PDF as SERVICE_PLACEHOLDER)
- [x] Backend AuditLog entity + EF config (NEW group folder `ReportAuditModels` + `ReportAuditConfigurations`)
- [x] Backend audit-capture infrastructure (`IAuditLogWriter` + `AuditLogWriter` separate-scope writer + `AuditLogInterceptor` post-save diff + `AuditEventPipelineBehavior` for Export*/Approve*/Reject*/Submit* + 5 explicit auth-event hooks in `AuthendicationMutations.cs`)
- [x] Backend report query (`GetAuditTrailReport` paginated w/ role-scoped WHERE + max-row guard + `GetAuditTrailSummary` 4-card aggregate + `GetAuditTrailById` detail + `GetAuditTrailByCorrelation` security timeline)
- [x] Backend export handlers (Excel SERVICE_PLACEHOLDER, CSV REAL via StringBuilder/base64, PDF SERVICE_PLACEHOLDER — all emit self-audit EXPORT row)
- [x] Backend wiring complete (`IApplicationDbContext` + `ApplicationDbContext` + `Base.Infrastructure/DependencyInjection.cs` + `Base.Application/DependencyInjection.cs` + `ReportAuditMappings.cs` Mapster + 4 GlobalUsing files + `AuthendicationMutations.cs` injection)
- [x] Frontend report page (replaced `<UnderConstruction />` stub at `[lang]/reportaudit/audit/audittrail/page.tsx` — now renders `<AuditTrailPageConfig />` → `<AuditTrailReportPage />`)
- [x] Frontend wiring complete (`reportaudit-service-entity-operations.ts` + spread into `data-table-configs/index.ts` + page config in `pages/reportaudit/audit/audittrail.tsx`)
- [x] DB Seed script (`AuditTrail-sqlscripts.sql` — Module + Menu + MenuCapabilities + RoleCapabilities + Grid AUDITTRAILREPORT + 9 Fields + 8 GridFields + 3 MasterDataTypes (AUDIT_ACTION_TYPE / AUDIT_STATUS / AUDIT_SEVERITY) + 23 MasterData rows)
- [x] Registry updated to COMPLETED (#74)

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
| ISSUE-1 | 1 | MED | BE / Auth | Account-lockout 5-attempt chain (ACCOUNT_LOCKED rows) deferred. `User` entity has no `FailedAttemptCount`/`LockedUntil` cols. `LOGIN_FAILED` rows emit with `AttemptNumber=null` and `CorrelationId=null`. Once lockout feature ships, fill these and add an `ACCOUNT_LOCKED` emit at 5th-failure threshold. | OPEN |
| ISSUE-2 | 1 | LOW | BE / Auth | `RefreshToken` mutation in `AuthendicationMutations.cs` has NO audit hook (mechanical, high frequency — would be noisy). If compliance later requires it, add `WriteAuthEvent(action="TOKEN_REFRESH",status="SUCCESS")` inside the `RefreshToken` success path. | OPEN |
| ISSUE-3 | 1 | MED | BE / Role-scoping | `GetAuditTrailReport` STAFFADMIN branch-scoping is simplified — looks up the current user's own `BranchUsers` assignments rather than the full set of users assigned to the admin's branches. Full row-security needs a separate sub-query joining `BranchUsers` across all users in the same branches. | OPEN |
| ISSUE-4 | 1 | LOW | BE / AuditNo | `AuditLogWriter.GenerateAuditNo` opens a second scoped DbContext to compute the day's max ID. Under high concurrency, two writes in the same second could compute the same `AuditNo`. The `AuditNo` UNIQUE index will reject the duplicate (writer logs+swallows; never throws to caller per immutability contract). Future improvement: PostgreSQL `SEQUENCE` or UUID-based AuditNo. | **CLOSED (Session 3)** — replaced with Postgres `app.audit_no_seq` + `HasDefaultValueSql` on `AuditLog.AuditNo`. C# writer no longer sets the value; the DB computes `'AUD-' \|\| YYYYMMDD \|\| '-' \|\| nextval(seq):D6` atomically at INSERT. `GenerateAuditNo` method deleted. Migration script: `sql-scripts-dyanmic/AuditTrail-v2-async-sequence.sql`. |
| ISSUE-5 | 1 | LOW | BE / DI | `Base.Infrastructure/DependencyInjection.cs(10,7)` — duplicate `using Base.Infrastructure.Services` directive (CS0105 warning). Trivial cleanup. | OPEN |
| ISSUE-6 | 1 | INFO | FE / Convention | Mutations file lives at `gql-queries/reportaudit-queries/AuditTrailMutations.ts` rather than under a separate `gql-mutations/` folder (no such folder exists in project — queries+mutations colocated under `gql-queries/`). No functional impact; matches some existing convention in the project. | OPEN |
| ISSUE-7 | 1 | LOW | FE / TS-types | `entity-operations.ts` typing requires all 6 CRUD+toggle slots (`getAll/getById/create/update/delete/toggle`); audit-trail is READ+EXPORT only. CSV mutation used as safe `_noop` placeholder for the 4 unused slots — never invoked because page bypasses `<AdvancedDataTable>`. Consider extending `TDataTableOperationConfigs` to allow optional CRUD slots for read-only entities. | OPEN |
| ISSUE-8 | 1 | INFO | FE / GQL typing | TS errors fixed by inline-annotating `useQuery`/`useLazyQuery`/`useMutation` with `TApiSingleResponse<T>` / `TApiCollectionResponse<T>` from `@/domain/types/common-types/TApiResponse`. Project uses untyped `gql` tags (no codegen) — this means *every* Apollo hook must be hand-annotated. Many existing files in the codebase have the same `Property 'result' does not exist on type '{}'` error; fixing them is out of scope for this build. | OPEN |
| ISSUE-9 | 2 | HIGH | BE / Audit perf | Audit writes are synchronous on the request path — every `SaveChangesAsync` in business code awaits `AuditLogWriter.WriteEntityChange → PersistAsync`, which opens a fresh scope and commits an INSERT before returning. Adds ~5–20ms per request, more when multiple entities change. Documented design (`docs/architecture-review/08-AUDIT-LOGGING-SYSTEM.md` §5) drains to a `Channel<>` + Hangfire background worker. **Cheaper fix (no Hangfire)**: in-memory `Channel<AuditLog>` + `IHostedService` drainer that batches inserts every 500ms or 50 rows, whichever first. Combine with ISSUE-10 for true batched writes. | **CLOSED (Session 3)** — `IAuditQueue` (bounded `Channel<AuditLog>`, cap 10 000, `DropOldest`) + `AuditQueueDrainer : BackgroundService` (batch=50, maxWait=500ms). Writer's `Task` methods now build the row and `_queue.TryEnqueue(row); return Task.CompletedTask` — zero I/O on the request path. Drainer flushes the buffer on shutdown with a 5s budget. |
| ISSUE-10 | 2 | HIGH | BE / Audit perf | No batching. When N entities change in one `SaveChangesAsync`, `AuditLogInterceptor.EmitAuditRowsAsync` makes N separate writer calls — each opens its own scope + connection + commits one row. Collect into a `List<AuditLog>` then `AddRange` once at the end of the interceptor. Will be folded into ISSUE-9 channel drain when that lands. | **CLOSED (Session 3)** — folded into ISSUE-9 channel drain. Drainer's `PersistBatchAsync` does a single `db.AuditLogs.AddRange(batch); SaveChangesAsync()` per batch — N audit rows = 1 DB roundtrip (up to batch size 50). |
| ISSUE-11 | 2 | HIGH | BE / Double-audit risk | `AuditEventPipelineBehavior` fires for every `Approve*`/`Reject*`/`Submit*`/`Export*` MediatR request by name-prefix. If any handler also calls `IAuditLogWriter.WriteWorkflowEvent` or `WriteExportEvent` explicitly, you get TWO audit rows for the same logical action. Today no handler does so (auth events use `WriteAuthEvent` only; no workflow handlers exist yet), but the first one that lands will double-write silently. Decide a single source-of-truth convention: (a) keep pipeline behavior + forbid explicit calls in matching handlers, OR (b) remove pipeline behavior + require explicit calls in handlers. Document the choice in `_REPORT.md`. | OPEN |
| ISSUE-12 | 2 | MED | BE / Pipeline behavior correctness | `AuditEventPipelineBehavior.Handle` emits the audit row AFTER `next()` returns, but does NOT inspect the response. A handler that returns a failure-shaped DTO (without throwing) will still record a successful `APPROVE`/`REJECT`/`EXPORT`. Today most handlers throw on failure so this is mostly benign, but if any handler returns a `BaseApiResponse { IsSuccess=false }` instead of throwing, the audit row will misreport. Fix: inspect response for `IsSuccess`/`Success` shape via reflection, OR adopt convention "handlers must throw on failure" and document in `feedback-build-directives`. | OPEN |
| ISSUE-13 | 2 | MED | BE / Pipeline behavior shallow context | `AuditEventPipelineBehavior` writes `recordCount=0`, `format="Unknown"`, `entityId=0` because it cannot reflect into request properties at the generic-pipeline level. Result: pipeline-emitted audit rows for `Export*`/`Approve*` are forensically thinner than explicit handler emits (which carry real IDs + counts). Fix paths: (a) remove the behavior and require explicit per-handler emits (loses ISSUE-11's "fewer edits" benefit), OR (b) enrich the behavior with reflection over a known `Request.EntityId`/`Request.RecordCount` convention, OR (c) accept the gap and treat pipeline rows as "something happened" markers backed by handler-emit detail rows. | OPEN |
| ISSUE-14 | 2 | MED | BE / Schema | `AuditLog.EntityId` is `int?`. Project has entities with `Guid` PKs (`Module.ModuleId`) and may add composite-key entities. Today auditing any non-int-PK entity silently writes `EntityId = 0` (see `AuditLogInterceptor.GetEntityId` fallback). Documented design uses `EntityId VARCHAR(100)` to support both. Migrate column to `string EntityId` (length 64, denormalized like `EntityDisplayKey`). Requires EF migration + writer + interceptor + report-query + DTO + FE column update. | OPEN |
| ISSUE-15 | 2 | LOW | BE / Retention scaling | No partitioning. Spec retention is 7 years × 200–2000 rows/day per tenant — single `app."AuditLogs"` table will grow to multi-million rows. Documented design `08-AUDIT-LOGGING-SYSTEM.md` §8.2 partitions by month with auto-rollover function. Adopt when total row count crosses 5M or P95 query latency on the report degrades past acceptable. Track row count via a scheduled job. | OPEN |
| ISSUE-16 | 2 | LOW | BE / Audit config | No DB-driven audit-configuration table. Entity skip list (`AuditLog`, `RefreshToken`) and sensitive-field redaction keys (`password|token|secret|hash|salt`) are hardcoded in `AuditLogInterceptor` + `AuditLogWriter`. Adding/removing an entity from the audit scope, or changing a redaction key, requires a code change + redeploy. Documented design `audit.AuditConfigurations` table with `IMemoryCache(5min)`. Adopt when ops need runtime toggles. | OPEN |
| ISSUE-17 | 2 | LOW | BE / Dedup | No `AuditEventId` Guid + UNIQUE for dedup. Today an at-most-once write — if the synchronous `PersistAsync` succeeds the row lands once; if it fails the row is dropped (logged only). Once ISSUE-9 channel drain lands (and especially if Hangfire is adopted later), at-least-once delivery becomes possible and dedup becomes necessary. Documented design `08-AUDIT-LOGGING-SYSTEM.md` §3.1 column `"AuditEventId" UUID NOT NULL UNIQUE`. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-16 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. First REPORT/TABULAR in registry; sets canonical §⑦ for the report sub-type and the `ReportAuditBusiness` group folder convention. Includes cross-cutting audit-capture infrastructure (interceptor + writer + MediatR pipeline behavior + 5 explicit auth-event hooks).
- **User-approved scope deviations from prompt §⑫**:
  1. Per-handler `Export*`/`Approve*`/`Reject*`/`Submit*` injection REPLACED by single `AuditEventPipelineBehavior` MediatR pipeline behavior matching request-class-name prefix → ~65 file edits avoided.
  2. Auth-event hooks all land in single file `AuthendicationMutations.cs` (no separate `LoginCommand` exists in this codebase).
  3. Account-lockout 5-attempt chain DEFERRED (see ISSUE-1).
  4. Excel + PDF exports kept as SERVICE_PLACEHOLDER (no ClosedXML / EPPlus / PDF generator NuGet in repo).
- **Files touched**:
  - **BE NEW (18)**:
    - `Base.Domain/Models/ReportAuditModels/AuditLog.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ReportAuditConfigurations/AuditLogConfiguration.cs` (created)
    - `Base.Application/Schemas/ReportAuditSchemas/AuditTrailSchemas.cs` (created)
    - `Base.Application/Common/Interfaces/IAuditLogWriter.cs` (created)
    - `Base.Application/Business/ReportAuditBusiness/AuditLogs/Queries/GetAuditTrailReport.cs` (created)
    - `Base.Application/Business/ReportAuditBusiness/AuditLogs/Queries/GetAuditTrailSummary.cs` (created)
    - `Base.Application/Business/ReportAuditBusiness/AuditLogs/Queries/GetAuditTrailById.cs` (created)
    - `Base.Application/Business/ReportAuditBusiness/AuditLogs/Queries/GetAuditTrailByCorrelation.cs` (created)
    - `Base.Application/Business/ReportAuditBusiness/AuditLogs/ReportExport/ExportAuditTrailExcel.cs` (created — SERVICE_PLACEHOLDER)
    - `Base.Application/Business/ReportAuditBusiness/AuditLogs/ReportExport/ExportAuditTrailCsv.cs` (created — REAL)
    - `Base.Application/Business/ReportAuditBusiness/AuditLogs/ReportExport/ExportAuditTrailPdf.cs` (created — SERVICE_PLACEHOLDER)
    - `Base.Application/Common/Behaviors/AuditEventPipelineBehavior.cs` (created — replaces ~65 per-handler edits)
    - `Base.Application/Mappings/ReportAuditMappings.cs` (created)
    - `Base.Infrastructure/Services/AuditLogWriter.cs` (created — separate-scope DbContext write so audit persists on caller transaction rollback; SHA-256 SessionId hash; redacts `password|token|secret` keys; catch-never-throw)
    - `Base.Infrastructure/Data/Interceptors/AuditLogInterceptor.cs` (created — post-`SavedChangesAsync` ChangeTracker scan; skips `AuditLog`+`RefreshToken`+password fields)
    - `Base.API/EndPoints/ReportAudit/Queries/AuditTrailQueries.cs` (created — 4 GQL queries)
    - `Base.API/EndPoints/ReportAudit/Mutations/AuditTrailMutations.cs` (created — 3 export mutations)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/AuditTrail-sqlscripts.sql` (created — Module/Menu/MenuCapabilities/RoleCapabilities for BUSINESSADMIN+SUPERADMIN/Grid AUDITTRAILREPORT/9 Fields/8 GridFields/3 MasterDataTypes/23 MasterData rows)
  - **BE MODIFIED (9)**:
    - `Base.Domain/GlobalUsing.cs` (modified — added ReportAuditModels)
    - `Base.Application/GlobalUsing.cs` (modified — added ReportAuditModels + ReportAuditSchemas)
    - `Base.Infrastructure/GlobalUsing.cs` (modified — added ReportAuditModels + Common.Interfaces)
    - `Base.API/GlobalUsing.cs` (modified — added ReportAuditSchemas + ReportAuditBusiness query/export namespaces)
    - `Base.Application/Data/Persistence/IApplicationDbContext.cs` (modified — added `DbSet<AuditLog> AuditLogs { get; }`)
    - `Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs` (modified — added `DbSet<AuditLog>`)
    - `Base.Infrastructure/DependencyInjection.cs` (modified — registered `ISaveChangesInterceptor → AuditLogInterceptor` (transient) + `IAuditLogWriter → AuditLogWriter` (scoped))
    - `Base.Application/DependencyInjection.cs` (modified — registered `AuditEventPipelineBehavior<,>` in MediatR + `ReportAuditMappings.ConfigureMappings()`)
    - `Base.API/EndPoints/Auth/Mutations/AuthendicationMutations.cs` (modified — injected `IAuditLogWriter`; hooked `Login` (LOGIN/SUCCESS + LOGIN_FAILED/WARNING), `RevokeRefreshToken` (LOGOUT/SUCCESS), `ForgotPasswords` (FORGOT_PASSWORD/SUCCESS), `ResetPasswords` (PASSWORD_RESET/HIGH))
  - **FE NEW (17)**:
    - `domain/entities/reportaudit-service/AuditTrailDto.ts` (created — all TS interfaces + `BaseApiResponse` shape)
    - `domain/entities/reportaudit-service/index.ts` (created — barrel)
    - `infrastructure/gql-queries/reportaudit-queries/AuditTrailQueries.ts` (created — 4 query exports)
    - `infrastructure/gql-queries/reportaudit-queries/AuditTrailMutations.ts` (created — 3 mutation exports)
    - `infrastructure/gql-queries/reportaudit-queries/index.ts` (created — barrel)
    - `presentation/pages/reportaudit/audit/audittrail.tsx` (created — page config gated by `useAccessCapability({ menuCode: "AUDITTRAIL" })`)
    - `presentation/components/page-components/reportaudit/audit/audittrail/index.ts` (created — barrel)
    - `presentation/components/page-components/reportaudit/audit/audittrail/report-page.tsx` (created — Variant B layout, 2 useLazyQuery, view-toggle pure FE state)
    - `presentation/components/page-components/reportaudit/audit/audittrail/components/summary-cards.tsx` (created — 4 KPI cards w/ solid bg-X-600 + text-white per `feedback-widget-icon-badge-styling`)
    - `presentation/components/page-components/reportaudit/audit/audittrail/components/filter-panel.tsx` (created — 7 controls, 5 quick-date chips, Save Filter SERVICE_PLACEHOLDER)
    - `presentation/components/page-components/reportaudit/audit/audittrail/components/view-toggle-bar.tsx` (created)
    - `presentation/components/page-components/reportaudit/audit/audittrail/components/result-table.tsx` (created — 8 cols, action-pill + status-badge + entity-link + row-severity coloring + server-side pagination 50)
    - `presentation/components/page-components/reportaudit/audit/audittrail/components/result-timeline.tsx` (created — date-grouped, NO refetch on toggle)
    - `presentation/components/page-components/reportaudit/audit/audittrail/components/detail-panel.tsx` (created — 480px Sheet slide-in, 6 conditional sections, security timeline sub-query)
    - `presentation/components/page-components/reportaudit/audit/audittrail/components/action-pill.tsx` (created — semantic palette in `style={{}}` per prompt-mandated exception)
    - `presentation/components/page-components/reportaudit/audit/audittrail/components/status-badge.tsx` (created — solid bg-X-600 + text-white)
    - `presentation/components/page-components/reportaudit/audit/audittrail/components/entity-link.tsx` (created — entity→route map fallback when BE doesn't supply route)
    - `presentation/components/page-components/reportaudit/audit/audittrail/components/export-menu.tsx` (created — Excel/PDF placeholder toasts, CSV base64 → blob → download)
    - `presentation/components/page-components/reportaudit/audit/audittrail/components/print-styles.module.css` (created — `@media print` hides filter+toggle+cards, repeats thead, exact color print)
  - **FE MODIFIED (4)**:
    - `app/[lang]/reportaudit/audit/audittrail/page.tsx` (modified — replaced `<UnderConstruction />` with `<AuditTrailPageConfig />`)
    - `application/configs/data-table-configs/reportaudit-service-entity-operations.ts` (created/modified — AUDITTRAIL operations w/ `_noop` placeholder per ISSUE-7)
    - `application/configs/data-table-configs/index.ts` (modified — spread `ReportAuditServiceEntityOperations`)
    - `presentation/pages/reportaudit/audit/index.ts` (modified — added `export * from "./audittrail"`)
- **TS-error fixes (post-build)**: Annotated `useQuery`/`useLazyQuery`/`useMutation` with `TApiSingleResponse<T>` / `TApiCollectionResponse<T>` in `report-page.tsx` + `detail-panel.tsx` + `export-menu.tsx`; added `id` field to breadcrumb items in `report-page.tsx` to satisfy `IBreadcrumbItem` interface.
- **Build verification**: 
  - `dotnet build PSS_2.0_Backend/PeopleServe/PeopleServe.sln` → **0 errors, 540 warnings** (all warnings pre-existing in unrelated files; 1 trivial new — see ISSUE-5).
  - `pnpm exec tsc --noEmit` → **0 errors in `presentation/components/page-components/reportaudit/audit/audittrail/**`** (other pre-existing TS errors in unrelated files in the project remain).
- **Deviations from spec**: Account-lockout (ACCOUNT_LOCKED) DEFERRED → ISSUE-1. Excel+PDF kept SERVICE_PLACEHOLDER → no NuGet additions. Per-handler `Export*`/`Approve*`/`Reject*` injection REPLACED by single MediatR pipeline behavior (user-approved). RefreshToken mutation has no audit hook (deliberate noise reduction → ISSUE-2).
- **Known issues opened**: ISSUE-1 through ISSUE-8 (see Known Issues table).
- **Known issues closed**: None (first session).
- **Next step**: User must run (1) `dotnet ef migrations add Add_AuditLog --project Base.Infrastructure --startup-project Base.API` (from `PSS_2.0_Backend/PeopleServe/Services/Base`), (2) `dotnet ef database update`, (3) execute `sql-scripts-dyanmic/AuditTrail-sqlscripts.sql`, (4) `pnpm dev` and visit `/{lang}/reportaudit/audit/audittrail` to verify the screen loads (BUSINESSADMIN role required).

### Session 2 — 2026-05-18 — REVIEW — COMPLETED

- **Scope**: Architecture review only. User surfaced a pre-existing design document `PSS_2.0_Backend/docs/architecture-review/08-AUDIT-LOGGING-SYSTEM.md` that had been authored *before* Session 1 but was not shared during implementation. Compared the shipped implementation against the documented design to determine which audit-capture approach is stronger. **No code changes** — issue-filing only.
- **Files touched**: None (code-wise). This prompt file is the only touched artifact:
  - `prompts/audittrail.md` (modified — added ISSUE-9 through ISSUE-17; updated `last_session_date`; appended this session entry).
- **Side-by-side findings**:
  - **Documented design wins**: non-blocking write path (Hangfire-backed channel), batched DB writes, automatic retry on transient failure, separate `audit.` schema + dedicated DbContext, multi-year partitioning, DB-driven `AuditConfigurations` opt-out, `AuditEventId` dedup, composite-key support (`EntityId VARCHAR(100)`), Prometheus metrics.
  - **Implementation wins**: covers Auth events (LOGIN / LOGIN_FAILED / PASSWORD_RESET / etc.) and Export + Workflow events that the documented EF-interceptor-only design entirely misses; survives caller transaction rollback via `IServiceScopeFactory.CreateAsyncScope()`; `AuditNo` display number; denormalized user fields (rename/delete-proof); `MediatR AuditEventPipelineBehavior` replaces ~65 per-handler edits; zero new infra dependency.
  - **Verdict**: The implementation is materially **better in coverage** today (auth + export + workflow capture), the documented design is **better at scale** (latency, throughput, retention, isolation). Recommended path: **keep the implementation, treat the documented design as a roadmap, fix the gaps in priority order**.
- **Recommendation for next /continue-screen session** (when audit-perf becomes a priority):
  1. Close ISSUE-9 + ISSUE-10 together: introduce `IAuditQueue` (in-memory `Channel<AuditLog>`) + `AuditQueueDrainer : IHostedService` that batches inserts every 500ms or 50 rows. No new infra (no Hangfire required) — uses standard .NET hosted services + the existing `ApplicationDbContext`. Estimated effort: 1 session.
  2. Close ISSUE-4 (AuditNo race) by adopting a Postgres `SEQUENCE` (e.g. `app.audit_no_seq`) instead of `MaxAsync + 1`, OR derive `AuditNo` from `AuditLogId` post-insert (single UPDATE after INSERT). Estimated effort: 0.5 session.
  3. Close ISSUE-11 (double-audit risk) by documenting in `_REPORT.md` that `Approve*`/`Reject*`/`Submit*`/`Export*` MediatR handlers MUST NOT call `IAuditLogWriter` explicitly — the pipeline behavior is the single source of truth. Estimated effort: 0.25 session (doc + grep audit).
  4. Close ISSUE-14 (EntityId int → string) when the first non-int-PK entity gets audited. Today `Module` writes `0` silently. Estimated effort: 0.5 session + EF migration.
  5. Defer ISSUE-15 (partitioning), ISSUE-16 (config table), ISSUE-17 (dedup) until scale demands them.
- **Deviations from spec**: None — this session did not generate code.
- **Known issues opened**: ISSUE-9 (HIGH, audit-perf synchronous writes), ISSUE-10 (HIGH, no batching), ISSUE-11 (HIGH, double-audit risk), ISSUE-12 (MED, pipeline correctness on failure responses), ISSUE-13 (MED, pipeline shallow context), ISSUE-14 (MED, EntityId schema), ISSUE-15 (LOW, partitioning), ISSUE-16 (LOW, config table), ISSUE-17 (LOW, dedup).
- **Known issues closed**: None.
- **Next step**: User to decide which gap to close first. Recommended order ISSUE-9 → ISSUE-10 → ISSUE-4 → ISSUE-11 → ISSUE-14, deferring ISSUE-15/16/17 until needed.

### Session 3 — 2026-05-19 — FIX — COMPLETED

- **Scope**: Close ISSUE-9 (synchronous audit writes), ISSUE-10 (no batching), and ISSUE-4 (AuditNo race) in a single pass. These three are tightly coupled — the channel drainer is the natural place to batch, and the DB sequence default removes any need for the writer to generate AuditNo. No FE changes, no business-logic changes. Behavior of the screen and of every audit-emitting handler is unchanged.
- **Architecture change**:
  - **Before**: `AuditLogInterceptor` → `IAuditLogWriter.WriteEntityChange` → `PersistAsync` (fresh scope per row, sync INSERT, also a `MaxAsync` SELECT for AuditNo). N changed entities = 2N DB roundtrips on the request thread.
  - **After**: `AuditLogInterceptor` → `IAuditLogWriter.WriteEntityChange` (builds row, enqueues, returns `Task.CompletedTask`). `AuditQueueDrainer` background service batches up to 50 rows / 500ms and runs ONE `AddRange + SaveChangesAsync` per batch. AuditNo populated atomically by the DB sequence `app.audit_no_seq` via `HasDefaultValueSql`. N changed entities = 0 DB roundtrips on the request thread, ~1 batched roundtrip on the background thread.
- **Files touched**:
  - **BE NEW (3)**:
    - `Base.Application/Common/Interfaces/IAuditQueue.cs` (created — `TryEnqueue` / `DrainBatchAsync` / `CurrentDepth`)
    - `Base.Infrastructure/Services/AuditQueue.cs` (created — `Channel<AuditLog>` bounded at 10 000 with `FullMode = DropOldest`; SingleReader, multi-writer; warning logged every 100 drops)
    - `Base.Infrastructure/HostedServices/AuditQueueDrainer.cs` (created — `BackgroundService`, batch=50, maxWait=500ms; per-batch DI scope so `ApplicationDbContext` is fresh; final-drain pass with 5 s budget on shutdown; catch-and-log so transient DB blips don't crash the host)
  - **BE MODIFIED (4)**:
    - `Base.Domain/Models/ReportAuditModels/AuditLog.cs` (modified — `AuditNo` made `string?` so EF skips it on INSERT and lets the DB default fire; comment notes DB column remains NOT NULL)
    - `Base.Infrastructure/Data/Configurations/ReportAuditConfigurations/AuditLogConfiguration.cs` (modified — `AuditNo.HasDefaultValueSql(...)` + `ValueGeneratedOnAdd`; `IsRequired()` preserved)
    - `Base.Infrastructure/Services/AuditLogWriter.cs` (modified — DI dep `IServiceScopeFactory` → `IAuditQueue`; 4 writer methods changed from `async Task` to `Task` returning `Task.CompletedTask` after `_queue.TryEnqueue(row)`; removed `PersistAsync` + `GenerateAuditNo` private methods; AuditNo line removed from all 4 row builders)
    - `Base.Infrastructure/DependencyInjection.cs` (modified — registered `IAuditQueue → AuditQueue` as **Singleton** + `AuditQueueDrainer` as `IHostedService`; preserved scoped `IAuditLogWriter`)
  - **DB MIGRATION NEW (1)**:
    - `sql-scripts-dyanmic/AuditTrail-v2-async-sequence.sql` (created — `CREATE SEQUENCE app.audit_no_seq` + `ALTER COLUMN AuditNo SET DEFAULT 'AUD-' || YYYYMMDD || '-' || LPAD(nextval(...), 6, '0')` + back-fill `setval(...)` past existing rows; idempotent; includes verification queries at the bottom)
- **Build verification**:
  - `dotnet build PSS_2.0_Backend/PeopleServe/PeopleServe.sln` → **0 errors, 576 warnings** (delta +36 vs Session 1's 540 — all pre-existing in unrelated files; **no warnings emitted from any audit file**, verified via grep of audit-related filenames against build output).
- **Deviations from Session 2 plan**:
  - Combined ISSUE-9 + ISSUE-10 + ISSUE-4 into one session (Session 2 plan estimated 1 session for ISSUE-9/10 + 0.5 for ISSUE-4). Tight coupling made it cheaper to land together — the writer was being rewritten anyway, and the drainer is where batching naturally lives. The DB sequence removed the need for the drainer to compute AuditNo.
  - **NOT done in this session** (deferred): ISSUE-11 (double-audit convention — needs `_REPORT.md` doc edit + grep audit), ISSUE-12, ISSUE-13, ISSUE-14, ISSUE-15, ISSUE-16, ISSUE-17.
- **Trade-offs taken (worth flagging)**:
  - **At-most-once delivery** — if the host crashes between `TryEnqueue` and the drainer's next `SaveChangesAsync`, buffered audit rows are lost. This is acceptable for the audit use case (best-effort, never block the caller), but if at-least-once is later required, close ISSUE-17 (`AuditEventId` UUID + UNIQUE dedup) and persist the channel to a `audit.AuditQueue` table.
  - **Bounded channel drops oldest on overflow** — under sustained 10K+ row burst, old rows are silently dropped (with warning log every 100). Alternative `FullMode = Wait` would push back-pressure to the writer (and ultimately to the caller's `SaveChanges`); chose `DropOldest` to honor the "never block the caller" contract.
  - **No retry on failed batch** — drainer logs and drops. For transient DB failures during a deploy, this means a small audit hole. Hangfire-style retry is the documented design's answer; not adopted here per the "no new infra" constraint.
- **Known issues opened**: None.
- **Known issues closed**: **ISSUE-4** (AuditNo race — replaced by `app.audit_no_seq`), **ISSUE-9** (synchronous writes — replaced by `IAuditQueue` + `AuditQueueDrainer`), **ISSUE-10** (no batching — folded into drainer's `AddRange`).
- **Next step**: User must run `sql-scripts-dyanmic/AuditTrail-v2-async-sequence.sql` against every environment BEFORE deploying the new build (the sequence must exist before EF inserts AuditLog rows with AuditNo omitted). Script is idempotent + back-fills the sequence past any existing rows. After deploy, verify by emitting any auditable action (e.g., LOGIN), waiting ~1 second, and querying `SELECT "AuditLogId", "AuditNo" FROM app."AuditLogs" ORDER BY "AuditLogId" DESC LIMIT 5` — every row should have an auto-generated AuditNo of the form `AUD-20260519-NNNNNN`.

### Session 4 — 2026-05-20 — FIX — COMPLETED

- **Scope**: Move AuditLog table from `app` schema to dedicated `audit` schema (matches documented design `08-AUDIT-LOGGING-SYSTEM.md` §3 schema isolation). Fix the migration error from Session 3 — the `Change_AuditNo_As_Nullable_In_AuditLog` migration failed with `relation "app.audit_no_seq" does not exist` because the V2 SQL script was a separate manual step the user didn't run before applying the migration. User had a fresh/dev DB, so we collapsed both changes into a single clean migration and deleted the broken one.
- **Root-cause analysis of the migration error**:
  - Session 3 introduced two coupled changes: (a) make AuditNo nullable + add DB default referencing `app.audit_no_seq`, (b) require the V2 SQL script to be run manually to create the sequence.
  - User generated EF migration but had not yet run the V2 SQL script, so `nextval('app.audit_no_seq')` referenced a non-existent relation → 42P01 error.
  - The fix shifts sequence-creation from a manual SQL script into the EF migration itself via `modelBuilder.HasSequence<long>("audit_no_seq", schema: "audit")` in `ApplicationDbContext.OnModelCreating`. EF now emits `CreateSequence` automatically in the migration BEFORE the column-default AlterColumn that depends on it. No separate manual SQL step.
- **Files touched**:
  - **BE MODIFIED (3)**:
    - `Base.Domain/Models/ReportAuditModels/AuditLog.cs` (modified — `[Table("AuditLogs", Schema = "app")]` → `[Table("AuditLogs", Schema = "audit")]`)
    - `Base.Infrastructure/Data/Configurations/ReportAuditConfigurations/AuditLogConfiguration.cs` (modified — `HasDefaultValueSql` now references `audit.audit_no_seq` instead of `app.audit_no_seq`; comment updated)
    - `Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs` (modified — `OnModelCreating` now declares `builder.HasSequence<long>("audit_no_seq", schema: "audit").StartsAt(1).IncrementsBy(1)` so EF emits `CreateSequence` in the migration)
  - **BE NEW (1)**:
    - `Base.Infrastructure/Migrations/20260518100019_MoveAuditLogsToAuditSchema.cs` (created — `EnsureSchema(audit)` → `RenameTable(app.AuditLogs → audit.AuditLogs)` → `CreateSequence(audit.audit_no_seq)` → `AlterColumn(AuditNo SET DEFAULT)`. PG `ALTER TABLE ... SET SCHEMA` moves indexes implicitly. Down reverses the four operations in opposite order. Manually edited to remove misleading `oldDefaultValueSql` references — the previous failed migration was never applied so the DB has no prior default.)
  - **BE DELETED (3)**:
    - `Base.Infrastructure/Migrations/20260518094849_Change_AuditNo_As_Nullable_In_AuditLog.cs` (deleted — failed migration, never applied to any DB; fresh dev install per user)
    - `Base.Infrastructure/Migrations/20260518094849_Change_AuditNo_As_Nullable_In_AuditLog.Designer.cs` (deleted)
    - `sql-scripts-dyanmic/AuditTrail-v2-async-sequence.sql` (deleted — sequence + default now live in the EF migration model; redundant)
- **Build verification**:
  - `dotnet build PSS_2.0_Backend/PeopleServe/PeopleServe.sln` → **0 errors**.
  - `dotnet ef migrations add MoveAuditLogsToAuditSchema --no-build` → emitted with operations in correct order (CreateSequence before AlterColumn).
- **Deviations from Session 3 plan**: Session 3 closed ISSUE-4 via the V2 SQL script as a separate deploy step. Session 4 superseded that approach — EF model + migration now own the sequence, so there is one less manual step. The ISSUE-4 close remains valid (same outcome: sequence-driven AuditNo, no race).
- **Known issues opened**: None.
- **Known issues closed**: None (Session 3 closes still stand — ISSUE-4, ISSUE-9, ISSUE-10).
- **Next step for the user**:
  1. `dotnet ef database update --project Base.Infrastructure --startup-project Base.API` (from `PSS_2.0_Backend/PeopleServe/Services/Base`). This applies `MoveAuditLogsToAuditSchema` — creates the `audit` schema, moves `app.AuditLogs` → `audit.AuditLogs` with all indexes/FKs intact, creates `audit.audit_no_seq`, and sets the AuditNo column default.
  2. Verify with: `SELECT n.nspname, c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relname='AuditLogs';` — should report `audit | AuditLogs`.
  3. Trigger an auditable action (e.g., LOGIN), wait ~1 second for the drainer, then `SELECT "AuditLogId", "AuditNo" FROM audit."AuditLogs" ORDER BY "AuditLogId" DESC LIMIT 5;` — every row should have `AUD-YYYYMMDD-NNNNNN`.
