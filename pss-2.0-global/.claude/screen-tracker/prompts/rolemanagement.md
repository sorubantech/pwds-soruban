---
screen: RoleManagement
registry_id: 70
module: Access Control
status: COMPLETED
scope: FULL
screen_type: CONFIG
config_subtype: SETTINGS_PAGE
hybrid_subtypes: [SETTINGS_PAGE (tab container), MASTER_GRID (Tab 1 Role card-grid, Tab 2 Capability list), MATRIX_CONFIG (Tab 3 Role×Capability), READ_ONLY_REPORT (Tab 4 Comparison)]
storage_pattern: multi-entity (auth.Roles + auth.Capabilities + auth.RoleCapabilities)
complexity: High
new_module: NO
absorbs_registry_ids: [73 Role-Capability Matrix, 127 Capabilities]
planned_date: 2026-05-16
completed_date: 2026-05-18
last_session_date: 2026-05-18
last_fix_date: 2026-05-18 (Session 3)
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — administration/role-management.html (canonical) + administration/role-capability-matrix.html (Tab 3 source)
- [x] Business context read (RBAC + tenant-level access governance + system-vs-custom role distinction)
- [x] Storage model identified (3 existing entities composed under one tabbed UI — Role/Capability/RoleCapability)
- [x] Save model chosen (per-row modal saves on Tabs 1+2; bulk-diff save-all on Tab 3 matrix)
- [x] Sensitive fields & role gates identified (IsSystem-flagged roles read-only; Super Admin Role row immutable)
- [x] FK targets resolved (Role/Capability/Menu paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (4-tab CONFIG + system-role guard + matrix-diff persistence — prompt was pre-analyzed; no separate agent spawn)
- [x] Solution Resolution complete (hybrid container w/ MATRIX_CONFIG Tab 3 confirmed; existing entities preserved)
- [x] UX Design finalized (card-grid Tab 1 + list-grid Tab 2 + matrix Tab 3 + comparison Tab 4 — modal Section 2 swapped to deep-link card per user-approved scope reduction)
- [x] User Approval received (2026-05-18 — approved with V1 scope reductions: drop modal Section 2 Module Access table, drop GetRoleSummary, defer matrix virtualization)
- [x] Backend code generated (Role entity field extension + 8 new composite handlers + Capability + RoleCapability extensions)
- [x] Backend wiring complete (Mutations/Queries endpoint method registration + Mapster extensions; EF migration NOT scaffolded — user runs `dotnet ef migrations add Add_Role_RBAC_Extensions` per team rule)
- [x] Frontend code generated (workspace shell + 4 tab modules + Role modal w/ 3 form-sections + Module-Access deep-link card + Matrix grid w/ sticky save bar + Comparison table)
- [x] Frontend wiring complete (page config + barrel exports + forwarder routes for /role, /capability, /rolecapability → /rolemanagement?tab=)
- [x] DB Seed script generated (1 visible parent ROLEMANAGEMENT menu + 3 hidden child menus ROLE/CAPABILITY/ROLECAPABILITY + capabilities + BUSINESSADMIN role grants + re-parent existing ROLE/CAPABILITY)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [x] dotnet build passes (Base.Application + Base.API — 0 errors, only pre-existing warnings)
- [ ] User runs `dotnet ef migrations add Add_Role_RBAC_Extensions` + `dotnet ef database update` (deferred per team-handles-migrations rule)
- [ ] User runs `RoleManagement-sqlscripts.sql` after migration applies (creates ROLEMANAGEMENT menu + grants)
- [ ] pnpm dev — page loads at `/{lang}/accesscontrol/usersroles/rolemanagement`
- [ ] **Hybrid CONFIG checks** (covering all 4 tabs):
  - Tab 1 (Roles — card grid):
    - [ ] Card grid renders all roles with system/custom badge + color indicator + module-tag chips + user-count
    - [ ] System roles (IsSystem=true) show "Cannot be modified/deleted" footer note and disabled edit/delete actions
    - [ ] Custom roles show Edit + Delete actions in card footer
    - [ ] "+ New Role" button opens modal in create mode
    - [ ] Modal: Section 1 (Role Information) — name + access level + role type + description + color picker
    - [ ] Modal: Section 2 (Module Access) — table renders 9 modules × 5 perm slots; cascading hierarchy (uncheck View → uncheck all in row); per-module Select-All / None buttons
    - [ ] Modal: Section 3 (Data Scope) — branch access dropdown + 4 data-visibility checkboxes + 3 record-ownership radios
    - [ ] Modal: Section 4 (Restrictions) — IP toggle + IP textarea (conditional); Time toggle + time range (conditional); Session limit dropdown; Idle timeout dropdown
    - [ ] "Save Role" persists & closes; "Save & Configure Capabilities" persists then switches to Tab 3 with role pre-selected/highlighted
    - [ ] Delete role triggers full-screen confirm modal w/ warning copy
  - Tab 2 (Capabilities — list grid):
    - [ ] Standard data-table renders capability rows: code, name, description, isSpecial chip, orderBy
    - [ ] "+ Add Capability" opens modal (RJSF or custom — name/code/description/isSpecial/orderBy)
    - [ ] Edit + Delete per-row actions
    - [ ] Capabilities with linked RoleCapability rows cannot be deleted (FK guard)
  - Tab 3 (Role × Capability Matrix):
    - [ ] Matrix renders: rows grouped by Menu sections (collapsible), sub-rows are Capabilities, columns are Roles
    - [ ] Section toggle collapses/expands menu groups
    - [ ] Search box filters capability rows by name
    - [ ] Filter badges (All / Granted Only / Denied Only / Changed) narrow visible rows
    - [ ] Copy Role dropdown clones permissions from source role to target role (all cells in target column updated)
    - [ ] Right-click on role header column → context menu (Select All / Deselect All / Edit Role)
    - [ ] Right-click on capability row → context menu (Grant to All Roles / Revoke from All Roles)
    - [ ] Cell change marks `.changed`, cell background turns yellow, dirty count updates in sticky save bar
    - [ ] Sticky save bar appears when N>0 changes pending; shows "{N} changes pending" with Save / Discard / Reset-to-Defaults buttons
    - [ ] System-role columns (Super Admin) render checkboxes as `disabled` and ignore clicks
    - [ ] Save sends ONLY changed cells (diff payload) — verify GraphQL operation network tab
    - [ ] Reset to Defaults gates behind type-tenant-name confirm
  - Tab 4 (Role Comparison — view-only):
    - [ ] 3 role-selector dropdowns (3rd one optional with "(None)")
    - [ ] Comparison table renders capability rows × selected roles
    - [ ] Rows where roles differ highlight with yellow background (`diff` class)
    - [ ] Check-yes / check-no icons render per cell
- [ ] Empty / loading / error states render on each tab
- [ ] DB Seed — ROLEMANAGEMENT menu visible in sidebar under AC_USERSROLES (and old ROLE/CAPABILITY/ROLECAPABILITY menus hidden)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: RoleManagement
Module: ACCESSCONTROL
Schema: auth
Group: Auth (entity namespace `Base.Domain.Models.AuthModels`)

**Business**:

Role Management is the **central RBAC control center** for a tenant — the single page where a BUSINESSADMIN defines who can do what across the entire PSS 2.0 platform. PSS 2.0 ships with **6 system roles** (Super Admin, Org Admin, Manager, Staff, Field Agent, Auditor) plus an unbounded set of **custom roles** (e.g. Campaign Manager, Data Entry, API Access) — each role is a bundle of capabilities scoped to a tenant's organization hierarchy. The page combines three previously-separate screens (registry #70 Roles + #127 Capabilities + #73 Role-Capability Matrix) into one tabbed workspace because in practice an admin moves between them in a single sitting: create a role → define what menus/features that role can touch → verify by comparing two roles side-by-side.

**Who edits it**: only `BUSINESSADMIN` (with `MODIFY` capability on `ROLEMANAGEMENT`). The `Auditor` and `Manager` roles may have READ access for visibility but cannot mutate. **How often**: rare-but-critical — initial tenant setup (one-time), org expansion (quarterly when new departments form), and incident response (urgent — e.g. revoke a compromised role within minutes). **Why it exists**: every other screen in the platform consults the resulting `RoleCapability` matrix at load-time via the `useCapability` hook to decide which menus appear in the sidebar and which row-actions render in grids. **What breaks if mis-set**: granting `DELETE` on `GLOBALDONATION` to a Data Entry role would let a junior staff member wipe production donation records — wrong matrix = audit/compliance disaster + irreversible data loss. Conversely, forgetting to grant `READ` on a new menu after creating it leaves business users staring at empty screens. **How it relates to other screens**: directly upstream of #69 User Management (UserRole junction picks from this Role list) and indirectly upstream of every grid in the system (via `MenuCapability` join). The matrix on Tab 3 is the literal source of truth for `useCapability()` decisions across the entire FE. **What's unique about this config's UX**: it is a **hybrid** — Tab 1 is a card-grid (not a flat data table — because roles are few and visual), Tab 2 is a flat list-grid (because capabilities are many and tabular), Tab 3 is a 2D matrix with N×M cells (because RoleCapability is the only place where the intersection is editable), Tab 4 is a 3-column comparison report (because admins must verify diffs before saving high-stakes matrix changes). Generic "settings page" chrome would fail this screen — each tab needs a distinct layout matched to its underlying entity shape.

> **Why this section is heavier than other types**: CONFIG screens have no canonical layout —
> the design is derived from the business case. The richer §① is, the better the developer
> can design the right §⑥ blueprint.

---

## ② Storage Model

> **Consumer**: BA Agent → Backend Developer
> This is a **hybrid CONFIG** — three existing entities composed under one UI. Each tab maps to one entity. NO new tables are created. The Role entity gains additional columns to support the modal's new sections (color/access level/data scope/restrictions). The matrix tab uses the existing 3-axis join `(RoleId, MenuId, CapabilityId) → HasAccess`.

**Storage Pattern**: `multi-entity` (combination of standard CRUD on Roles/Capabilities + matrix-join on RoleCapability)

### Tables

> All three tables already exist under schema `auth`. CompanyId on Role is tenant-scoped; Capability is global (no CompanyId); RoleCapability scoping is inherited transitively via Role.

#### Primary table 1: `auth."Roles"` (existing — extend with new columns)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| RoleId | int | — | PK | — | Primary key (existing) |
| RoleName | string | 100 | YES | — | Existing — `[CaseFormat("title")]` |
| RoleCode | string | 50 | YES | — | Existing — `[CaseFormat("upper")]`, must be unique per tenant |
| Description | string? | 500 | — | — | Existing |
| IsSystem | bool | — | YES | — | Existing — true = uneditable system role |
| IsAssignable | bool | — | YES | — | Existing |
| OrderBy | int | — | YES | — | Existing |
| CompanyId | int? | — | — | corg.Companies | Existing — null = global system role |
| **ColorHex** | **string?** | **9** | **—** | **—** | **NEW — hex color e.g. `#3b82f6` for card indicator** |
| **AccessLevel** | **string?** | **20** | **—** | **—** | **NEW — enum: `Branch` \| `Organization` \| `System`** |
| **BranchAccess** | **string?** | **20** | **—** | **—** | **NEW — enum: `Assigned` \| `SubUnits` \| `Region` \| `All`** |
| **CanViewOwnData** | **bool** | **—** | **YES** | **—** | **NEW — default true** |
| **CanViewBranchData** | **bool** | **—** | **YES** | **—** | **NEW — default true** |
| **CanViewOrgData** | **bool** | **—** | **YES** | **—** | **NEW — default false** |
| **CanViewCrossBranchData** | **bool** | **—** | **YES** | **—** | **NEW — default false** |
| **RecordOwnership** | **string?** | **20** | **—** | **—** | **NEW — enum: `Own` \| `Branch` \| `All`; default `Branch`** |
| **IpRestrictionEnabled** | **bool** | **—** | **YES** | **—** | **NEW — default false** |
| **AllowedIps** | **string?** | **2000** | **—** | **—** | **NEW — newline-delimited CIDR/IP list; nullable when IpRestrictionEnabled=false** |
| **TimeRestrictionEnabled** | **bool** | **—** | **YES** | **—** | **NEW — default false** |
| **WorkingHoursStart** | **TimeOnly?** | **—** | **—** | **—** | **NEW — required when TimeRestrictionEnabled=true** |
| **WorkingHoursEnd** | **TimeOnly?** | **—** | **—** | **—** | **NEW — required when TimeRestrictionEnabled=true** |
| **SessionLimit** | **int?** | **—** | **—** | **—** | **NEW — null = unlimited; default 3** |
| **IdleTimeoutMinutes** | **int?** | **—** | **—** | **—** | **NEW — null = no timeout; default 30** |

**Singleton constraint**: Composite unique index on `(CompanyId, RoleCode) WHERE IsActive=true` (existing — preserve).

**System-role guard**: IsSystem=true rows can only be partially updated (description, color, restrictions) — never RoleName / RoleCode / IsSystem flag itself. Enforced in `UpdateRole` validator.

#### Primary table 2: `auth."Capabilities"` (existing — no schema change)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CapabilityId | int | — | PK | — | Existing |
| CapabilityName | string | 100 | YES | — | Existing — `[CaseFormat("title")]` |
| CapabilityCode | string | 50 | YES | — | Existing — `[CaseFormat("upper")]`, must be unique globally |
| Description | string? | 500 | — | — | Existing |
| IsSpecial | bool | — | YES | — | Existing — distinguishes module-special capabilities (EXPORT, IMPORT, APPROVE) |
| OrderBy | int | — | YES | — | Existing |

> **No CompanyId** — capabilities are global (every tenant uses the same vocabulary: READ, MODIFY, DELETE, EXPORT, IMPORT, APPROVE, ISMENURENDER, etc.).

#### Primary table 3: `auth."RoleCapabilities"` (existing — no schema change)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| RoleCapabilityId | int | — | PK | — | Existing |
| RoleId | int | — | YES | auth.Roles | Existing |
| MenuId | int | — | YES | auth.Menus | Existing |
| CapabilityId | int | — | YES | auth.Capabilities | Existing |
| HasAccess | bool | — | YES | — | Existing — the matrix cell value |

**Composite logical key**: `(RoleId, MenuId, CapabilityId)` — exactly one cell per (Role, Menu, Capability) triple. Verify the existing EF config enforces this unique index; if not, add one in the migration.

**Matrix shape note**: the matrix is **3D collapsed to 2D for the UI** — Menu is the row-section grouper, Capability is the sub-row, Role is the column. The same Capability code (e.g. `READ`) may appear under many Menu sections (one `READ` cell per (Menu × Role) pair).

**Child Tables** (touched read-only — for context):
| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| auth.Menus | Menu has many RoleCapability rows | MenuId, MenuCode, MenuName, ParentMenuId, ModuleId |
| auth.UserRoles | Role has many UserRole rows | for the "N users" count chip on Tab 1 cards |
| auth.MenuCapabilities | constrains which (Menu, Capability) pairs are valid | drives the matrix's available cells |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for ApiSelect queries)

### Role / Capability / RoleCapability cross-references

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| Role.CompanyId | Company | Base.Domain/Models/CorgModels/Company.cs | (tenant-resolved from HttpContext — no FE dropdown) | CompanyName | CompanyResponseDto |
| RoleCapability.RoleId | Role | Base.Domain/Models/AuthModels/Role.cs | **GetRoles** | RoleName | RoleResponseDto |
| RoleCapability.CapabilityId | Capability | Base.Domain/Models/AuthModels/Capability.cs | **GetCapabilities** | CapabilityName | CapabilityResponseDto |
| RoleCapability.MenuId | Menu | Base.Domain/Models/AuthModels/Menu.cs | **GetAllMenuList** (verify) | MenuName | MenuResponseDto |

> **Existing GQL field name conventions** (per discovery):
> - Role: `GetRoles` (paginated), `GetRoleById`, `CreateRole`, `UpdateRole`, `ActivateDeactivateRole`, `DeleteRole`
> - Capability: `GetCapabilities`, `GetCapabilityById`, `CreateCapability`, `UpdateCapability`, `ActivateDeactivateCapability`, `DeleteCapability`
> - RoleCapability: `GetRoleCapabilities`, `GetRoleCapabilityById`, `GetRoleCapabilityByUser`, `CreateRoleCapability`, `UpdateRoleCapability`, `ActivateDeactivateRoleCapability`, `DeleteRoleCapability`, `UpdateRoleCapabilityAccess`, `CreateRoleCapabilityList`

### Matrix sources (Tab 3 axes)

| Axis | Source Entity | GQL Query | Order Field | Read-only Filter |
|------|--------------|-----------|-------------|-------------------|
| Rows (sections) | Menu | GetAllMenuList (verify name) | ModuleId, OrderBy | exclude orphaned/hidden menus |
| Rows (sub-rows within section) | Capability | GetCapabilities | OrderBy | — |
| Columns | Role | GetRoles | OrderBy | exclude `RoleCode='SUPERADMIN'` for non-platform tenants; render disabled & checked for SUPERADMIN column always |

### Comparison sources (Tab 4)

Two-or-three role columns are picked from the same `GetRoles` list. The "permission" rows on Tab 4 are derived from the matrix view: pivot `RoleCapability` rows by `(MenuId, CapabilityId)` for the selected RoleIds and render a `HasAccess` truth column per selected role.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Singleton / Cardinality Rules:**
- Roles are tenant-scoped (`CompanyId` from HttpContext) **except** system roles where `IsSystem=true` and `CompanyId IS NULL` (global seeded rows). System roles are visible to all tenants; their `RoleCapability` matrix rows for new menus are also seeded globally.
- Capabilities are **global** (no CompanyId) — admin cannot create a tenant-specific capability vocabulary; capabilities are platform-defined and `CreateCapability` is BUSINESSADMIN-on-platform-tenant only (consider gating in V2 — for V1 allow all BUSINESSADMINs to add custom capability codes).
- `RoleCapability` rows are uniquely keyed on `(RoleId, MenuId, CapabilityId)` — Tab 3 BulkUpdate UPSERTs and never duplicates.

**Required Field Rules** (Role modal):
- Section 1: `RoleName` required, `Description` required (mockup marks both with `*`)
- Section 1: `AccessLevel` defaults to `Branch`; valid values `Branch` / `Organization` / `System`
- Section 1: `ColorHex` defaults to `#3b82f6`; must match regex `^#[0-9a-fA-F]{6}$`
- Section 3: `BranchAccess` defaults to `SubUnits`; `RecordOwnership` defaults to `Branch`
- Section 3: At least one of `CanViewOwnData` / `CanViewBranchData` must be true (refuse zero-visibility role)
- Section 4: `SessionLimit` defaults to 3; `IdleTimeoutMinutes` defaults to 30; both optional

**Conditional Rules:**
- If `IpRestrictionEnabled = true` → `AllowedIps` required (non-empty, each line parseable as IP or CIDR)
- If `TimeRestrictionEnabled = true` → `WorkingHoursStart` AND `WorkingHoursEnd` required; `Start < End`
- If `IsSystem = true` → `Update` mutation may modify ONLY: `Description`, `ColorHex`, `AccessLevel`-related fields, all restriction fields. May NOT modify: `RoleName`, `RoleCode`, `IsSystem`, `IsAssignable`. Validator rejects diff with `error: SYSTEM_ROLE_LOCKED`.
- If `RoleCode = 'SUPERADMIN'` → `Delete` rejected with `error: SUPERADMIN_IMMUTABLE`; `Update` further restricted (only `Description` mutable).
- Tab 2 Capability `Delete` → reject when `RoleCapability` rows reference the CapabilityId (FK guard with friendly error: "X roles use this capability — revoke first").
- Tab 3 Matrix cell change on `(RoleId where IsSystem=true AND RoleCode='SUPERADMIN', *)` → rejected; FE renders disabled checkbox.
- Tab 3 Matrix cell change on any system-role column other than SUPERADMIN → ALLOWED (admins can tune Manager/Staff defaults per tenant); record an audit-log entry.

**Sensitive Fields** (masking, audit, role-gating):

| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| AllowedIps | mild (network surface) | plain text | plain | log every change with old→new + actor |
| RoleCapabilities (matrix cells) | regulatory (privilege grants) | plain checkbox | diff payload | log per cell change with `(RoleId, MenuId, CapabilityId, oldHasAccess→newHasAccess, actorUserId)` |

> No passwords / API keys on this screen.

**Read-only / System-controlled Fields:**
- `RoleId`, `CapabilityId`, `RoleCapabilityId` — auto-generated, never editable
- `IsSystem` — set at seed time; never editable by admin
- `RoleCode` on system roles — disabled in edit modal
- "X users" count chip on Tab 1 cards — computed (`UserRoles.Count(...)`)

**Dangerous Actions** (require confirm + audit):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Delete Role (custom only) | Removes role + cascades to RoleCapability rows; orphans any UserRole rows (refuse if UserRole.Count > 0) | Full-screen modal "Type the role name to confirm" | log "role.deleted" with full role snapshot |
| Reset Matrix to Defaults | Overwrites ALL RoleCapability rows for tenant from system-seeded baseline | Type-tenant-name modal | log "matrix.reset" |
| Reset Single Role Defaults (sticky bar button on Tab 3) | Overwrites RoleCapability rows for the highlighted role only | "Reset {roleName} permissions to system defaults?" | log "role.matrix.reset" |
| Copy Role Permissions (Tab 3) | Replaces target role's cells with source role's cells | Modal preview "{X} cells will change" | log "role.matrix.copied" |
| Revoke from All Roles (Tab 3 context menu) | Sets HasAccess=false for ALL roles on the right-clicked capability row | Confirm modal | log "capability.revoked.all" |
| Grant to All Roles (Tab 3 context menu) | Sets HasAccess=true for ALL roles on the right-clicked capability row (except SUPERADMIN — which is already true) | Confirm modal | log "capability.granted.all" |

**Role Gating** (which sections / fields are visible / editable per role):

| Role | Sections Visible | Sections Editable | Notes |
|------|------------------|-------------------|-------|
| BUSINESSADMIN | all 4 tabs | all (subject to System-role guard above) | full access |
| Auditor / Manager (with READ-only on ROLEMANAGEMENT) | all 4 tabs (read-only) | none | save buttons hidden; matrix cells disabled |
| Other roles | hidden (menu not rendered) | — | sidebar gate via `useCapability('ROLEMANAGEMENT.READ')` |

**Workflow**: None — direct edits (no draft/publish).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: CONFIG
**Config Sub-type**: `SETTINGS_PAGE` (tabbed container — outermost shape)
**Hybrid embedded sub-types**:
- Tab 1 (All Roles) — card-grid pattern (custom variant of MASTER_GRID — visual card layout instead of flat table) with **modal** RJSF-like create/edit form (4-section custom modal, NOT RJSF — too much conditional logic for RJSF)
- Tab 2 (Capabilities) — standard MASTER_GRID-style list grid with simple modal create/edit (RJSF or compact custom modal — fewer than 6 fields)
- Tab 3 (Role × Capability Matrix) — `MATRIX_CONFIG` with 3D-collapsed-to-2D matrix (Menu sections × Capability rows × Role columns), sticky save bar, bulk-diff persistence
- Tab 4 (Role Comparison) — read-only comparison view (no save) — closest analogue is a small REPORT/PIVOT_CHART view inline

**Storage Pattern**: `multi-entity` (3 existing entities — see §②)
**Save Model** (per tab):

| Tab | Save Model | UI cue |
|-----|------------|--------|
| Tab 1 (Roles) | `save-per-row` (modal Save button on Create/Edit) | Modal footer "Save Role" + "Save & Configure Capabilities" |
| Tab 2 (Capabilities) | `save-per-row` (modal Save button) | Modal footer Save |
| Tab 3 (Matrix) | `save-all` with diff payload | Sticky bottom bar w/ "{N} changes pending" + Save / Discard / Reset |
| Tab 4 (Comparison) | none (read-only) | — |

**Reason**: Roles are few and high-value — per-row modal saves let the admin focus on one role at a time and aborts on cancel. The matrix is many cells changing as a batch — sticky-save-with-diff prevents the admin from losing the change context across scroll. Capability CRUD is rare maintenance work — simple modal.

**Backend Patterns Required:**

For Tab 1 (Role — extend existing entity & handlers):
- [x] Extend `Role` entity with 14 new columns (see §②) — EF migration scaffold
- [x] Extend `RoleRequestDto` + `RoleResponseDto` + `RoleDto` with new fields
- [x] Extend `CreateRole` validator — new required-when-true conditional rules
- [x] Extend `UpdateRole` validator — system-role guard + conditional rules
- [x] Extend `GetRoles` projection to include new fields + add `UserCount` (computed `UserRoles.Count(x => x.IsActive)`)
- [x] Extend `GetRoleById` similarly
- [ ] (Optional V2) Add `GetRoleSummary` query — global tenant summary (total roles, system vs custom counts, active users per role)

For Tab 2 (Capability — complete existing entity):
- [x] Existing CRUD already complete — only FE work needed
- [x] Add FK-guard to `DeleteCapability`: reject when `RoleCapabilities.Any(rc => rc.CapabilityId == capabilityId && rc.HasAccess && rc.IsActive)` with descriptive error

For Tab 3 (Matrix — NEW composite handlers on RoleCapability):
- [x] **NEW** `GetRoleCapabilityMatrix` query — returns `{ rows: [{ menuId, menuName, capabilities: [{ capabilityId, capabilityCode, capabilityName }] }], columns: [{ roleId, roleName, roleCode, isSystem, colorHex, grantedCount, totalCount }], cells: [{ roleId, menuId, capabilityId, hasAccess, isReadOnly }] }`
- [x] **NEW** `BulkUpdateRoleCapabilityMatrix` mutation — accepts `[{ roleId, menuId, capabilityId, hasAccess }[]]` diff payload; UPSERTs only changed rows; validates each cell against system-role guard; emits audit log entries per cell
- [x] **NEW** `ResetRoleCapabilityMatrix` mutation — overwrites tenant's RoleCapability rows from baseline (seed values from RoleCapabilityDefaults table OR static C# constant table)
- [x] **NEW** `ResetRoleCapabilityMatrixForRole` mutation — same but scoped to one RoleId
- [x] **NEW** `CopyRoleCapabilities` mutation — `{ sourceRoleId, targetRoleId }` — replaces target's cells with source's
- [x] **NEW** `GrantCapabilityToAllRoles` / `RevokeCapabilityFromAllRoles` mutations — `{ capabilityId, menuId }` — sets HasAccess for the (Capability, Menu) cell across all non-system roles
- [x] Tenant scoping on every matrix mutation (CompanyId from HttpContext used to filter RoleId in WHERE clauses — RoleCapability inherits via Role)

For Tab 4 (Comparison — NEW composite query):
- [x] **NEW** `GetRoleComparison` query — `{ roleIds: int[] (1-3) }` → returns `[{ menuId, menuName, capabilityId, capabilityCode, capabilityName, accessByRole: [{ roleId, hasAccess }] }]` flat row list for FE to render

**Frontend Patterns Required:**

Outer shell:
- [x] Tabbed container — Variant B (ScreenHeader at workspace level; child grids/matrix use `showHeader={false}`)
- [x] URL-synced tab parameter `?tab=roles|capabilities|matrix|comparison` for deep-linking
- [x] Zustand store for cross-tab state (selectedRoleId — used by "Save & Configure Capabilities" hand-off)

Tab 1 (Roles):
- [x] Card-grid component — 3-col responsive (3 → 2 → 1)
- [x] Role card subcomponent — color indicator + system/custom badge + access-level chip + description + module-tag chips + user-count + system-note OR Edit/Delete actions
- [x] "New Role" + "View Capability Matrix" buttons in header
- [x] Modal — large (max-width 900px), 4 form sections inside `modal-body-custom`
  - Section 1: Role Information (name + access level + role type + description + color picker)
  - Section 2: Module Access (custom table component, hierarchical cascading checkboxes, NOT a real grid)
  - Section 3: Data Scope (branch access dropdown + 4 checkboxes + 3 radios)
  - Section 4: Restrictions (3 toggle-style items: IP, Time, Session/Idle)
- [x] Modal footer: Cancel + "Save & Configure Capabilities" + "Save Role"
- [x] Delete confirm overlay (full-screen, type-role-name)
- [x] Color picker integration (HTML `<input type="color">` + live hex label)
- [x] Per-tab toggle: "All Roles" / "Role Comparison" sub-tabs inside Tab 1 (per mockup, the Comparison is a 2nd top-level tab) — OR promote Comparison to Tab 4 (recommended — see hybrid layout above)

Tab 2 (Capabilities):
- [x] Standard `FlowDataTableContainer` with `showHeader={false}` (or `AdvancedDataTable` if filters needed) — capability list grid
- [x] Modal create/edit (small — 5 fields: name, code, description, isSpecial switch, orderBy)
- [x] FK-guard error display on Delete

Tab 3 (Matrix):
- [x] Sticky-header matrix component (left column sticky = capability names; top row sticky = role columns)
- [x] Section rows (collapsible by menu) — chevron toggle + section icon (use existing Menu.MenuIcon or fallback)
- [x] Capability rows under each section
- [x] Cell renderer: checkbox; on change set `dirty` flag + cell yellow background + dirty-count update
- [x] Top toolbar: search box (filter capability names) + filter badges (All / Granted Only / Denied Only / Changed) + "Copy Role" dropdown
- [x] Role header context menu: Select All / Deselect All / Edit Role (right-click)
- [x] Capability row context menu: Grant to All / Revoke from All (right-click)
- [x] Sticky save bar (bottom, visible when dirty>0): "{N} changes pending" + Reset / Discard / Save buttons
- [x] System-role columns rendered with `disabled` checkboxes (SUPERADMIN always checked + disabled; other system roles editable but with system-badge tooltip)
- [x] Diff-payload save: collect cells with `.dirty` class, build `[{ roleId, menuId, capabilityId, hasAccess }]`, POST to BulkUpdate

Tab 4 (Comparison):
- [x] 3 role-selector dropdowns (3rd optional with "(None)")
- [x] Comparison table — capability rows × selected role columns
- [x] Diff highlighting (row gets `bg-yellow-50` class when not all selected roles have identical access)
- [x] Check-yes / check-no icons

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: This is a hybrid CONFIG. Each tab uses a DIFFERENT layout pattern — do NOT clone the same card-chrome across tabs.

### 🎨 Visual Uniqueness Rules

1. **Tab 1 cards have visual personality** — each role card shows its color indicator dot (12×12 circle), bold name, system-vs-custom badge (red `System` / cyan `Custom`), access-level chip, prose description, module-tag chips, user-count with people icon, and either a "Cannot be modified" italic system note OR Edit/Delete icon buttons. Cards lift on hover (translateY -2px + stronger shadow).
2. **Tab 2 grid is a flat list** — no visual flourish. Sortable columns, search bar, paginated. Match existing capability flow (e.g. like the existing Currency or DonationCategory grids).
3. **Tab 3 matrix is dense and information-rich** — left column sticks during horizontal scroll; top row sticks during vertical scroll. Yellow `changed-cell` background on dirty cells. Granted/denied/changed legend at bottom. Sticky save bar slides up when dirty>0 with shadow.
4. **Tab 4 comparison is a printable report** — yellow-highlighted row backgrounds for "diff" rows; large check-circle icons (success green for yes, slate-300 for no). Three side-by-side role dropdowns above the table.
5. **Header icons are semantic** — `fa-shield-halved` (red) for the page header. `fa-id-badge` for All Roles tab. `fa-list-check` (proposed) for Capabilities tab. `fa-table-cells-large` for Matrix tab. `fa-code-compare` for Comparison tab.
6. **Save affordances differ by tab** — Tab 1+2 use modal-footer Save buttons. Tab 3 uses sticky bottom save bar with dirty count. Tab 4 has no save (read-only).

**Anti-patterns to refuse**:
- Rendering Tab 1 as a flat data-table (mockup is explicit card-grid)
- Putting Matrix Save button at top instead of sticky-bottom (loses save context on scroll)
- Allowing SUPERADMIN column cells to be unchecked (existential privilege risk)
- Showing Edit/Delete buttons on system role cards (mockup shows "Cannot be modified")
- Using the same modal for Capability as for Role (Role modal is 4-section / 900px; Capability modal is 5-field / 600px)

---

### 🅰️ Block A — SETTINGS_PAGE Container (workspace shell)

#### Page Layout

**Container Pattern**: `tabs` (4 tabs)

**Page Header**:
- Title: "Role Management" with red `fa-shield-halved` icon (16px right margin)
- Subtitle: "Define and manage user roles for access control"
- Header right-actions:
  - "+ New Role" (primary accent) — opens Tab 1 modal (auto-switches tab if elsewhere)
  - "View Capability Matrix" (outline accent) — switches to Tab 3

**Tabs** (URL-synced via `?tab=`):
1. `?tab=roles` — All Roles (default)
2. `?tab=capabilities` — Capabilities
3. `?tab=matrix` — Role × Capability Matrix
4. `?tab=comparison` — Role Comparison

#### Section Definitions (the 4 tabs)

| # | Tab Title | Icon (Phosphor / FA) | Container Slot | Save Mode | Role Gate |
|---|-----------|-----------------------|----------------|-----------|-----------|
| 1 | All Roles | `fa-id-badge` (or `ph:identification-badge`) | tab-roles | save-per-row (modal) | BUSINESSADMIN.MODIFY |
| 2 | Capabilities | `fa-list-check` (or `ph:list-checks`) | tab-capabilities | save-per-row (modal) | BUSINESSADMIN.MODIFY |
| 3 | Role × Capability Matrix | `fa-table-cells-large` (or `ph:grid-four`) | tab-matrix | save-all (diff) | BUSINESSADMIN.MODIFY |
| 4 | Role Comparison | `fa-code-compare` (or `ph:git-diff`) | tab-comparison | (no save — read-only) | BUSINESSADMIN.READ |

---

### 🅱️ Block B — Tab 1: All Roles (card-grid + modal)

#### Card Grid Layout

```
┌────────────────────────────────────────────────────────────┐
│  [3-column responsive grid, 1rem gap]                       │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐              │
│  │ ● Super Admin [System]    │  (one card per role row)    │
│  │ [System-level]            │                              │
│  │ Full access across...     │                              │
│  │ [All Modules] [All Tenants]│                              │
│  │ 👥 2 users  Cannot be modified                            │
│  └────────────┘                                              │
└────────────────────────────────────────────────────────────┘
```

#### Card Anatomy

| Element | Source field | Style |
|---------|--------------|-------|
| Color dot | `role.colorHex` | 12×12 circle, inline `background: {hex}` |
| Role Name | `role.roleName` | bold 0.9375rem |
| System/Custom badge | `role.isSystem` | red bg if system; cyan bg if custom |
| Access-level chip | `role.accessLevel` | gray bg, "System-level" / "Organization-level" / "Branch-level" |
| Description | `role.description` | 0.8125rem, secondary color |
| Module tag chips | derived from `role.roleCapabilities` grouped by `menu.module` | gray bg, small |
| User count | computed `role.userCount` | "👥 N users" with cyan icon |
| Footer note | `role.isSystem ? "Cannot be modified/deleted" : <actions>` | italic 0.6875rem OR Edit/Delete icon buttons |

#### Modal (Create / Edit Role)

Size: `max-width: 900px`, `max-height: 70vh` body scroll

##### Modal Header

`[Icon] Create New Role` OR `[Icon] Edit Role: {roleName}` + close button (X)

##### Section 1 — Role Information (icon: `fa-circle-info`)

Layout: bootstrap row with 3 columns (md-6, md-3, md-3) for first row; (md-8, md-4) for second row

| Field | Widget | Default | Validation | Disabled when |
|-------|--------|---------|------------|---------------|
| Role Name * | text | — | required, max 100 | `isSystem=true` (display only) |
| Access Level | select [Branch / Organization / System] | `Branch` | — | — |
| Role Type | text disabled | `Custom` (or `System` when isSystem=true) | — | always disabled |
| Description * | textarea | — | required, max 500 | — |
| Role Color | `<input type="color">` + label showing hex | `#3b82f6` | regex `^#[0-9a-fA-F]{6}$` | — |

##### Section 2 — Module Access (icon: `fa-cubes`)

Custom table with 9 rows (modules) × 5 perm-checkbox slots + per-row "All/None" buttons.

| Module | Permissions (variable count, max 5) |
|--------|-------------------------------------|
| Dashboard | View, Configure |
| Contacts | View, Edit, Delete, Import/Export |
| Fundraising | View, Edit, Delete, Refund, Reconciliation |
| Communication | View, Send, Configure Templates, Automation |
| Organization | View, Edit, Configure, Targets |
| Field Collection | View, Edit, Approve, Receipt Books |
| Reports | View, Run, Custom Builder, Schedule |
| Administration | View, Users, Roles, Audit |
| Settings | View, Configure |

**Behavior**:
- Cascading: unchecking "View" (index 0) auto-unchecks all other perms in that row.
- Checking any non-View perm auto-checks "View" for that row.
- "All" / "None" buttons on the right toggle the entire row.
- A note below the table: *"For detailed capability assignment, use the [Role-Capability Matrix](link → switches tab)"*

**Persistence**: this UI is a **shortcut over RoleCapability** — saving the modal must call `BulkUpdateRoleCapabilityMatrix` with computed cell payload. Module-level "View" check maps to setting `HasAccess=true` for that Capability against ALL menus within that Module. Document this mapping table in §⑫ for future maintainers.

> **Implementation hint**: V1 can persist module-access checkboxes as a JSON snapshot inside Role itself (e.g. `ModuleAccessJson` column) AND project the underlying RoleCapability cells on Save — OR drop the modal table entirely and force admins to use Tab 3 for detail. Recommended V1 approach: **persist as JSON snapshot AND fire matrix-update** (so quick admins use the modal, power users use Tab 3 matrix). Flag the eventual cell-projection logic as a Solution Resolver decision point.

##### Section 3 — Data Scope (icon: `fa-database`)

| Field | Widget | Default | Validation |
|-------|--------|---------|------------|
| Branch Access | select [Assigned Branch Only / Branch + Sub-units / Region / All Branches] | `SubUnits` | — |
| Data Visibility | 4 checkboxes (own / branch / org / cross-branch) | own + branch | at least 1 checked |
| Record Ownership | 3 radios (Own / Branch / All) | `Branch` | — |

##### Section 4 — Restrictions (icon: `fa-lock`)

3 toggle-style items in a vertical list:

| Item | Toggle | Conditional fields |
|------|--------|--------------------|
| IP Restriction | toggle switch + label + sub-label | textarea (newline-separated IPs/CIDR) — visible only when toggle on |
| Time Restriction | toggle switch + label + sub-label | 2 `<input type="time">` (start, end) + "(Local timezone)" hint — visible only when toggle on |
| Session Limit + Idle Timeout | (no toggle — always visible, in a 2-column row) | session select [1/2/3/Unlimited], idle select [15/30/60/240/None] |

##### Modal Footer

- Left-aligned: `[Cancel]` (text button)
- Right-aligned: `[Save & Configure Capabilities]` (outline) — saves role + switches to Tab 3 with this role highlighted/scrolled-into-view
- Right-aligned (primary): `[Save Role]` — saves and closes modal

##### Delete Confirm Overlay

- Full-screen overlay (z-index 1100)
- Centered 420px-wide box
- Red triangle-warning icon in 56×56 light-red circle
- "Delete Role" heading
- "Are you sure you want to delete **{roleName}**? This action cannot be undone. Users assigned to this role will lose their permissions."
- Actions: `[Cancel]` outline + `[Delete Role]` danger
- Pre-check: if `userCount > 0`, replace primary button with disabled "Reassign users first" + a link to Tab 1 of User Management filtered by role

#### User Interaction Flow (Tab 1)

1. Tab loads → `GetRoles` fetches all roles (with userCount projection) → card grid renders
2. Click "+ New Role" → modal opens in create mode → modal sections 1-4 empty/default
3. Click a custom-role card OR Edit icon → modal opens in edit mode → fields pre-filled from `GetRoleById`
4. Click a system-role card → modal opens in **read-only mode** (all fields disabled, no Save buttons — only "Configure Capabilities" link to Tab 3)
5. User fills/edits → clicks "Save Role" → mutation fires → toast → modal closes → card grid refetches
6. User clicks "Save & Configure Capabilities" → save fires → on success → close modal → set URL `?tab=matrix&highlightRole={id}` → matrix scrolls/highlights the column
7. User clicks Delete on custom role → confirm overlay → on confirm → DELETE mutation → toast → refetch

---

### 🅱️ Block B-bis — Tab 2: Capabilities (list grid + small modal)

#### Page Layout

Standard data-table — model after an existing simple master grid (e.g. Currency or Gender from GEN_MASTERS).

| Column | Field | Renderer |
|--------|-------|----------|
| Code | `capabilityCode` | `text-bold` |
| Name | `capabilityName` | `text-truncate` |
| Description | `description` | `text-truncate` |
| Special | `isSpecial` | `status-badge` (Yes/No) |
| Order | `orderBy` | numeric |
| Linked Roles | computed `roleCapabilityCount` | `link-count` (clicking opens Tab 3 filtered to this capability) |
| Status | `isActive` | activate/deactivate toggle |
| Actions | — | Edit / Delete (Delete disabled when `roleCapabilityCount > 0`) |

#### Modal (Create / Edit Capability)

Size: `max-width: 600px` (compact)

| Field | Widget | Default | Validation |
|-------|--------|---------|------------|
| Capability Name * | text | — | required, max 100 |
| Capability Code * | text (uppercase auto) | — | required, max 50, unique global, regex `^[A-Z_]+$` |
| Description | textarea | — | optional, max 500 |
| Is Special | switch | false | — |
| Order By | number | 0 | optional |

Footer: `[Cancel]` + `[Save]`

---

### 🅲 Block C — Tab 3: Role × Capability Matrix (MATRIX_CONFIG)

#### Matrix Layout (mockup-faithful)

```
┌─ Toolbar ──────────────────────────────────────────────────────────────┐
│ [🔍 Search capabilities...]  [All] [Granted Only] [Denied Only] [Changed] │
│                                          [Copy Role ▾] (popover)        │
├─ Matrix (scrollable horizontally) ──────────────────────────────────────┤
│              ┃ SuperAdmin OrgAdmin Manager Staff FieldA Auditor Custom1 Custom2 [+Add] │
│ ▼ 📊 Dashboard                                                          │
│   ├ View Dashboard   [✓ disabled] [✓]  [✓]  [✓]   [✓]   [✓]   [✓]   [✓] │
│   ├ Configure Widget [✓ disabled] [✓]  [☐]  [☐]   [☐]   [☐]   [☐]   [☐] │
│   └ View All Br Data [✓ disabled] [✓]  [☐]  [☐]   [☐]   [✓]   [☐]   [☐] │
│ ▼ 👥 Contacts                                                            │
│   ├ View Contacts    [✓ disabled] [✓]  [✓]  [✓]   [✓*]  [✓]   [✓]   [✓] │
│   ├ Create Contact   ...                                                 │
│   ...                                                                    │
│ ▼ 💵 Fundraising                                                         │
│   ...                                                                    │
│ ▼ (other sections: Communication, Organization, Field Collection,        │
│    Reports, Administration, Settings)                                    │
├─ Legend ────────────────────────────────────────────────────────────────┤
│ ✓ Granted   ☐ Denied   ▮ Changed (unsaved)   * Limited scope            │
└─────────────────────────────────────────────────────────────────────────┘
┌─ Sticky Save Bar (visible only when dirty>0) ──────────────────────────┐
│ ● 3 changes pending     [⚠ Reset Role to Default] [✗ Discard] [💾 Save] │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Axes

| Axis | Source | Display | Order | Read-only Filter |
|------|--------|---------|-------|------------------|
| Rows — section groupers | Menu | MenuName w/ icon | ModuleId asc, then Menu.OrderBy | hide menus with `IsActive=false` |
| Rows — sub-rows within section | Capability | CapabilityName | Capability.OrderBy | only Capabilities with at least 1 MenuCapability link to this Menu |
| Columns | Role | RoleName + grantedCount/totalCount sub-label | OrderBy | SUPERADMIN column always disabled; other system roles editable but warn on save |
| Cells | RoleCapability.HasAccess | checkbox | — | SUPERADMIN cells always `checked + disabled` |

#### Cell Type

**Stamp**: `checkbox` (boolean grant/deny)

Persisted as `HasAccess: bool` on `RoleCapability`. NULL/missing row = `HasAccess=false` (denied).

#### Bulk Operations

| Operation | Trigger | Behavior |
|-----------|---------|----------|
| Right-click role header | context menu (Select All / Deselect All / Edit Role) | Toggles all cells in the role column except disabled |
| Right-click capability row | context menu (Grant to All / Revoke from All) | Toggles all cells in the row except disabled |
| Search box | top-left toolbar | Filters capability rows by name (case-insensitive `.includes`) |
| Filter badges (All / Granted Only / Denied Only / Changed) | top-toolbar | Hides rows by predicate |
| Copy Role | top-right popover | `{ from, to }` selects — clones source column's HasAccess values to target column for all cells |
| Reset Role to Default | sticky-bar (when role context active) | Confirm modal → server-side reset for one role |
| Reset to Defaults (top-right header) | resets entire matrix | Type-tenant-name confirm |
| Add Role | last column header button | Opens Tab 1 modal in create mode + on save reloads matrix w/ new column |

#### Save Model

- `save-all` with diff payload
- Diff payload shape: `[{ roleId, menuId, capabilityId, hasAccess }]` — ONLY cells whose `dirty` class is set
- Server validates each cell (SUPERADMIN reject, deleted capability reject, non-existent menu reject) and returns either success or per-cell errors
- On success: clear all `dirty` classes, update `data-original` attributes, dirty count → 0, sticky bar hides

#### Read-only Cells

| Condition | Visual | Behavior |
|-----------|--------|----------|
| Column is SUPERADMIN role | gray checkbox, `disabled`, tooltip "Super Admin always has access" | clicks ignored, cannot dirty |
| Row capability not linked to row's menu via MenuCapability | empty cell (no checkbox rendered) | n/a |
| User lacks MODIFY capability on ROLEMANAGEMENT | all checkboxes `disabled` | read-only view |

#### User Interaction Flow (Tab 3)

1. Tab loads → `GetRoleCapabilityMatrix` returns rows/columns/cells → matrix renders, all dirty counts at 0
2. User clicks cell → cell becomes dirty (yellow bg + `data-changed=true`) → footer shows "{N} unsaved changes" → sticky bar slides up
3. User right-clicks role header → context menu → Select All → all editable cells in column become dirty + checked → footer count updates
4. User uses Copy Role popover → bulk apply source → target → cells dirty
5. User filters by "Changed" badge → only modified rows remain visible (save still operates on full diff)
6. User clicks Save → POST `BulkUpdateRoleCapabilityMatrix` with diff array → toast "Saved {N} changes" → dirty classes cleared → bar hides
7. User clicks Discard → all dirty cells revert to `data-original` value → bar hides
8. User clicks Reset to Defaults → modal "Type {tenantName} to confirm" → on confirm → server-side reset → matrix refetch

---

### 🅳 Block D — Tab 4: Role Comparison (read-only report)

#### Layout

```
┌─ Header ────────────────────────────────────────────────────────────┐
│ Role Comparison                                                      │
│ [Role 1 ▾] [Role 2 ▾] [Role 3 ▾ (None)]                              │
├─ Table ─────────────────────────────────────────────────────────────┤
│ Permission              │ Manager │ Staff │ Field Agent │           │
│ Dashboard - View        │  ✓ (g)  │ ✓ (g) │   ✓ (g)     │ ← all same │
│ Dashboard - Configure   │  ✓ (g)  │ ✗ (r) │   ✗ (r)     │ ← DIFF (yellow row) │
│ Contacts - View         │  ✓      │ ✓     │   ✓         │           │
│ ...                                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

#### Behavior

- 3 selectors (Role 1, Role 2, Role 3) populated from `GetRoles`. Role 3 has "(None)" option (omits 3rd column).
- On change → re-query `GetRoleComparison(roleIds)` → re-render table
- Row gets `bg-yellow-50` class when `accessByRole` values are not all identical
- Check icons: `fa-circle-check` green for granted; `fa-circle-xmark` slate-300 for denied
- No edit affordances; no save

---

### Shared blocks (apply to all sub-types)

#### Page Header & Breadcrumbs

| Element | Content |
|---------|---------|
| Breadcrumb | Access Control › Users & Roles › Role Management |
| Page title | Role Management |
| Subtitle | "Define and manage user roles for access control" |
| Right actions | `[+ New Role]` `[View Capability Matrix]` (deep-links to Tab 3) |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading Tab 1 | Initial fetch of GetRoles | Skeleton row of 6 grey card outlines |
| Loading Tab 3 | Initial fetch of GetRoleCapabilityMatrix | Skeleton matrix (5 menu sections × 3 cap rows × 8 cols, grey) |
| Empty Tab 1 | (impossible — seeds guarantee ≥6 system roles) | n/a |
| Empty Tab 2 | If no custom capabilities seeded | Empty-state card "No capabilities defined. Click + Add Capability to start." |
| Error | Any GET fails | Error card with retry button + error code |
| Save error Tab 1/2 | Validation or server error | Inline error per field + toast |
| Save error Tab 3 | Per-cell errors returned by BulkUpdate | Cells with errors get red border + tooltip; failed cells remain dirty |

---

## ⑦ Substitution Guide

> No canonical CONFIG reference exists yet — this is the FIRST hybrid CONFIG / FIRST MATRIX_CONFIG. The closest precedents:
> - **Tabbed workspace shell**: model after **#136 Prayer Request workspace** (`prayerrequests-workspace.tsx`) — tab dispatch + URL-sync + cross-tab Zustand store
> - **Composite tabbed CONFIG with hidden child menus**: model after **#11 MatchingGift** (1 visible parent ROLEMANAGEMENT + 3 hidden child menus ROLE/CAPABILITY/ROLECAPABILITY for capability gating)
> - **Card grid Tab 1**: model after **#10 Online Donation Page** list view (split-pane card variant) OR build fresh — there's no existing card-grid master entity in the registry
> - **Matrix Tab 3**: NO precedent — sets the canonical for future MATRIX_CONFIG screens
> - **Modal CRUD on Tab 2**: model after **ContactType #19** (canonical MASTER_GRID with RJSF modal)
> - **Comparison Tab 4**: NO precedent — small bespoke read-only report

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| PrayerRequestsWorkspace | RoleManagementWorkspace | Tabbed shell pattern |
| MatchingGift (composite CONFIG) | RoleManagement | 1 visible parent + N hidden child menus for capability gating |
| ContactType (RJSF modal master grid) | Capability | Tab 2 modal CRUD |
| (none) | RoleCapability matrix | FIRST MATRIX_CONFIG — sets convention |
| auth | auth | DB schema (no change) |
| Auth | Auth | Backend group (`Base.Domain.Models.AuthModels` namespace) |
| AccessControl | AccessControl | Module folder (`accesscontrol`) |
| usersroles | usersroles | FE folder |
| rolemanagement | rolemanagement | URL path component |
| ROLEMANAGEMENT | ROLEMANAGEMENT | MenuCode |

---

## ⑧ File Manifest

> Multi-tab hybrid — file counts are larger than a single-sub-type CONFIG. Backend has 4 NEW composite handlers + 1 entity extension; FE has 4 tab modules + 1 shell + 1 modal subsystem.

### Backend Files — NEW

| # | File | Path |
|---|------|------|
| 1 | GetRoleCapabilityMatrix Query (composite) | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/RoleCapabilities/GetMatrixQuery/GetRoleCapabilityMatrix.cs |
| 2 | BulkUpdateRoleCapabilityMatrix Command | …/AuthBusiness/RoleCapabilities/BulkUpdateMatrixCommand/BulkUpdateRoleCapabilityMatrix.cs |
| 3 | ResetRoleCapabilityMatrix Command | …/AuthBusiness/RoleCapabilities/ResetMatrixCommand/ResetRoleCapabilityMatrix.cs |
| 4 | ResetRoleCapabilityMatrixForRole Command | …/AuthBusiness/RoleCapabilities/ResetForRoleCommand/ResetRoleCapabilityMatrixForRole.cs |
| 5 | CopyRoleCapabilities Command | …/AuthBusiness/RoleCapabilities/CopyCommand/CopyRoleCapabilities.cs |
| 6 | GrantCapabilityToAllRoles Command | …/AuthBusiness/RoleCapabilities/GrantAllCommand/GrantCapabilityToAllRoles.cs |
| 7 | RevokeCapabilityFromAllRoles Command | …/AuthBusiness/RoleCapabilities/RevokeAllCommand/RevokeCapabilityFromAllRoles.cs |
| 8 | GetRoleComparison Query | …/AuthBusiness/RoleCapabilities/ComparisonQuery/GetRoleComparison.cs |
| 9 | GetRoleSummary Query (optional) | …/AuthBusiness/Roles/SummaryQuery/GetRoleSummary.cs |
| 10 | EF Migration scaffold | (user-run) `dotnet ef migrations add Add_Role_RBAC_Extensions` |

### Backend Files — MODIFIED

| # | File to Modify | Edit |
|---|---------------|------|
| 1 | Base.Domain/Models/AuthModels/Role.cs | Append 14 new property declarations (ColorHex, AccessLevel, BranchAccess, CanView*, RecordOwnership, IpRestriction*, AllowedIps, TimeRestriction*, WorkingHours*, SessionLimit, IdleTimeoutMinutes) + extend `Create()` factory signature OR add `UpdateRBACProfile()` helper |
| 2 | Base.Infrastructure/Data/Configurations/AuthConfigurations/RoleConfiguration.cs | Configure HasMaxLength on new string columns + default values for booleans + nullability |
| 3 | Base.Application/Schemas/AuthSchemas/RoleSchemas.cs | Extend RoleRequestDto + RoleResponseDto + RoleDto with new fields + add `UserCount` to ResponseDto |
| 4 | Base.Application/Schemas/AuthSchemas/CapabilitySchemas.cs | Add `RoleCapabilityCount` to ResponseDto (computed) |
| 5 | Base.Application/Schemas/AuthSchemas/RoleCapabilitySchemas.cs | Add `RoleCapabilityMatrixDto`, `RoleCapabilityMatrixRowDto`, `RoleCapabilityMatrixColumnDto`, `RoleCapabilityMatrixCellDto`, `RoleCapabilityMatrixDiffDto`, `RoleCapabilityCopyDto`, `RoleCapabilityGrantAllDto`, `RoleCapabilityRevokeAllDto`, `RoleComparisonRequestDto`, `RoleComparisonRowDto`, `RoleComparisonAccessDto` |
| 6 | Base.Application/Business/AuthBusiness/Roles/CreateCommand/CreateRole.cs | Validate new conditional rules (IP/Time when toggle on); persist new fields |
| 7 | Base.Application/Business/AuthBusiness/Roles/UpdateCommand/UpdateRole.cs | System-role guard (reject changes to RoleName/RoleCode/IsSystem when IsSystem=true); persist new fields |
| 8 | Base.Application/Business/AuthBusiness/Roles/DeleteCommand/DeleteRole.cs | Add FK guard: reject if `UserRoles.Any(ur => ur.IsActive)` with friendly error |
| 9 | Base.Application/Business/AuthBusiness/Roles/GetAllQuery/GetRoles.cs | Extend projection with new fields + UserCount subquery |
| 10 | Base.Application/Business/AuthBusiness/Roles/GetByIdQuery/GetRoleById.cs | Same extension |
| 11 | Base.Application/Business/AuthBusiness/Capabilities/DeleteCommand/DeleteCapability.cs | Add FK guard against RoleCapabilities |
| 12 | Base.Application/Business/AuthBusiness/Capabilities/GetAllQuery/GetCapabilities.cs | Add RoleCapabilityCount projection |
| 13 | Base.API/EndPoints/Auth/Mutations/RoleMutations.cs | (no new — existing 4 mutations cover Tab 1) |
| 14 | Base.API/EndPoints/Auth/Mutations/CapabilityMutations.cs | (no new — existing 4 mutations cover Tab 2) |
| 15 | Base.API/EndPoints/Auth/Mutations/RoleCapabilityMutations.cs | Register 6 new mutations (BulkUpdateMatrix, ResetMatrix, ResetForRole, Copy, GrantAll, RevokeAll) |
| 16 | Base.API/EndPoints/Auth/Queries/RoleCapabilityQueries.cs | Register 2 new queries (GetRoleCapabilityMatrix, GetRoleComparison) |
| 17 | Base.API/EndPoints/Auth/Queries/RoleQueries.cs | (Optional) Register GetRoleSummary |
| 18 | Base.Application/Mappings/AuthMappings.cs (or per-entity) | Mapster mappings for new DTOs |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | DecoratorProperties.cs | (verify Auth decorator already exists; no change needed) |
| 2 | (no DbContext edit — entities already registered) | — |

### Frontend Files — NEW

| # | File | Path |
|---|------|------|
| 1 | RoleMatrix DTO | PSS_2.0_Frontend/src/domain/entities/auth-service/RoleCapabilityMatrixDto.ts |
| 2 | RoleComparison DTO | …/auth-service/RoleComparisonDto.ts |
| 3 | RoleManagement composite Query (Matrix + Summary) | PSS_2.0_Frontend/src/infrastructure/gql-queries/auth-queries/RoleCapabilityMatrixQuery.ts |
| 4 | RoleComparison Query | …/auth-queries/RoleComparisonQuery.ts |
| 5 | Capability Query | …/auth-queries/CapabilityQuery.ts |
| 6 | Capability Mutation | PSS_2.0_Frontend/src/infrastructure/gql-mutations/auth-mutations/CapabilityMutation.ts |
| 7 | RoleCapabilityMatrix Mutation | …/auth-mutations/RoleCapabilityMatrixMutation.ts |
| 8 | Workspace shell | PSS_2.0_Frontend/src/presentation/components/page-components/auth/usersroles/rolemanagement/rolemanagement-workspace.tsx |
| 9 | Workspace Zustand store | …/rolemanagement/rolemanagement-store.ts |
| 10 | Tab 1 — Roles tab content | …/rolemanagement/tabs/roles/index.tsx |
| 11 | Tab 1 — Role card-grid | …/rolemanagement/tabs/roles/role-card-grid.tsx |
| 12 | Tab 1 — Role card | …/rolemanagement/tabs/roles/role-card.tsx |
| 13 | Tab 1 — Role modal shell | …/rolemanagement/tabs/roles/role-modal.tsx |
| 14 | Tab 1 — Role modal section 1 (info) | …/rolemanagement/tabs/roles/sections/role-info-section.tsx |
| 15 | Tab 1 — Role modal section 2 (module access) | …/rolemanagement/tabs/roles/sections/role-module-access-section.tsx |
| 16 | Tab 1 — Role modal section 3 (data scope) | …/rolemanagement/tabs/roles/sections/role-data-scope-section.tsx |
| 17 | Tab 1 — Role modal section 4 (restrictions) | …/rolemanagement/tabs/roles/sections/role-restrictions-section.tsx |
| 18 | Tab 1 — Delete confirm modal | …/rolemanagement/tabs/roles/role-delete-confirm.tsx |
| 19 | Tab 2 — Capabilities tab content | …/rolemanagement/tabs/capabilities/index.tsx |
| 20 | Tab 2 — Capability modal | …/rolemanagement/tabs/capabilities/capability-modal.tsx |
| 21 | Tab 3 — Matrix tab content | …/rolemanagement/tabs/matrix/index.tsx |
| 22 | Tab 3 — Matrix grid component | …/rolemanagement/tabs/matrix/matrix-grid.tsx |
| 23 | Tab 3 — Matrix toolbar (search + filter badges + copy-role) | …/rolemanagement/tabs/matrix/matrix-toolbar.tsx |
| 24 | Tab 3 — Matrix sticky save bar | …/rolemanagement/tabs/matrix/matrix-save-bar.tsx |
| 25 | Tab 3 — Matrix context menus (role / capability) | …/rolemanagement/tabs/matrix/matrix-context-menus.tsx |
| 26 | Tab 4 — Comparison tab content | …/rolemanagement/tabs/comparison/index.tsx |
| 27 | Tab 4 — Comparison table component | …/rolemanagement/tabs/comparison/comparison-table.tsx |
| 28 | Page Config | PSS_2.0_Frontend/src/presentation/pages/auth/usersroles/rolemanagement.tsx |
| 29 | Route Page | PSS_2.0_Frontend/src/app/[lang]/accesscontrol/usersroles/rolemanagement/page.tsx |
| 30 | Role-badge renderer (if not reusable) | PSS_2.0_Frontend/src/presentation/components/shared-cell-renderers/role-system-badge.tsx |

### Frontend Files — MODIFIED

| # | File to Modify | Edit |
|---|---------------|------|
| 1 | PSS_2.0_Frontend/src/domain/entities/auth-service/RoleDto.ts | Append 14 new fields + userCount |
| 2 | PSS_2.0_Frontend/src/domain/entities/auth-service/CapabilityDto.ts | Append roleCapabilityCount |
| 3 | PSS_2.0_Frontend/src/domain/entities/auth-service/RoleCapabilityDto.ts | (verify — may already cover matrix shape; add if not) |
| 4 | PSS_2.0_Frontend/src/domain/entities/auth-service/index.ts (barrel) | Export new DTOs |
| 5 | PSS_2.0_Frontend/src/infrastructure/gql-queries/auth-queries/RoleQuery.ts | Extend ROLES_QUERY + ROLE_BY_ID_QUERY response fragments with new fields + userCount |
| 6 | PSS_2.0_Frontend/src/infrastructure/gql-mutations/auth-mutations/RoleMutation.ts | Extend CREATE/UPDATE input fragment with new fields |
| 7 | PSS_2.0_Frontend/src/infrastructure/gql-queries/auth-queries/index.ts (barrel) | Export new query files |
| 8 | PSS_2.0_Frontend/src/infrastructure/gql-mutations/auth-mutations/index.ts (barrel) | Export new mutation files |
| 9 | PSS_2.0_Frontend/src/.../auth-service-entity-operations.ts | Add `ROLEMANAGEMENT` block + extend `ROLE` block (gridCode update if needed) + add `CAPABILITY` block + add `ROLECAPABILITY` block (hidden) |
| 10 | PSS_2.0_Frontend/src/.../operations-config.ts | Register ROLEMANAGEMENT operations |
| 11 | PSS_2.0_Frontend/src/.../useCapability.ts | (Verify) flags `canManageRoles` exposed for sidebar gate |
| 12 | PSS_2.0_Frontend/src/app/[lang]/accesscontrol/usersroles/role/page.tsx | Replace with `<RoleManagementPage defaultTab="roles" />` OR delete + 301-redirect (recommended: leave as deep-link forwarder) |
| 13 | PSS_2.0_Frontend/src/app/[lang]/accesscontrol/usersroles/capability/page.tsx | Replace under-construction stub with forwarder |
| 14 | PSS_2.0_Frontend/src/app/[lang]/accesscontrol/usersroles/rolecapability/page.tsx | Create as forwarder (route currently does not exist) |
| 15 | Sidebar menu config (per discovery — actual file TBD) | Show ROLEMANAGEMENT visible; hide ROLE / CAPABILITY / ROLECAPABILITY child menus (set MenuRender=false in seed) |
| 16 | shared-cell-renderers barrel | Register `role-system-badge` if new renderer added |
| 17 | column-type registries (advanced/basic/flow — 3 files) | Register `role-system-badge` |

### Frontend Files — DELETED (after wiring forwarders)

- (None initially — keep `accesscontrol/usersroles/role/data-table.tsx`-style file until consolidation verified; mark for deletion in next maintenance pass)

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: Role Management
MenuCode: ROLEMANAGEMENT
ParentMenu: AC_USERSROLES
Module: ACCESSCONTROL
MenuUrl: accesscontrol/usersroles/rolemanagement
GridType: CONFIG

MenuCapabilities: READ, CREATE, MODIFY, DELETE, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, EXPORT

GridFormSchema: SKIP
GridCode: ROLEMANAGEMENT

# Hidden child menus (composite pattern — for capability gating only)
HiddenChildMenus:
  - MenuCode: ROLE
    MenuName: Roles
    MenuUrl: accesscontrol/usersroles/role
    Caps: READ, CREATE, MODIFY, DELETE
    Render: false
  - MenuCode: CAPABILITY
    MenuName: Capabilities
    MenuUrl: accesscontrol/usersroles/capability
    Caps: READ, CREATE, MODIFY, DELETE
    Render: false
  - MenuCode: ROLECAPABILITY
    MenuName: Role Capability Matrix
    MenuUrl: accesscontrol/usersroles/rolecapability
    Caps: READ, MODIFY, EXPORT
    Render: false
---CONFIG-END---
```

> **Capability rationale**:
> - `CREATE` — admin can add custom roles (Tab 1) and capabilities (Tab 2)
> - `MODIFY` — admin can edit custom roles, edit any role's matrix cells (Tab 3)
> - `DELETE` — admin can delete custom roles + capabilities (system roles always rejected by validator)
> - `EXPORT` — admin can export the matrix as CSV (per mockup top-right "Export Matrix")
> - `ISMENURENDER` — controls sidebar visibility
>
> `GridFormSchema: SKIP` — entire screen is custom UI; no RJSF modal generation.
>
> **Hidden child menus** preserve existing capability checks across the codebase (any feature gating on `useCapability('ROLE.MODIFY')` continues to work via the hidden child). The 3 old top-level menus get `MenuRender=false` in seed so they disappear from sidebar but their capability records persist.

---

## ⑩ Expected BE→FE Contract

**GraphQL Types:**
- Query types: `RoleQueries`, `CapabilityQueries`, `RoleCapabilityQueries` (existing — extended)
- Mutation types: `RoleMutations`, `CapabilityMutations`, `RoleCapabilityMutations` (existing — extended)

### Tab 1 — Roles

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getRoles` (extended) | `Paginated<RoleResponseDto>` | pagination args |
| `getRoleById` (extended) | `RoleResponseDto` | roleId |
| `getRoleSummary` (NEW, optional) | `RoleSummaryDto` | — |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createRole` (extended) | `RoleRequestDto` (extended) | int |
| `updateRole` (extended) | `RoleRequestDto` (extended) | int |
| `activateDeactivateRole` (existing) | roleId, isActive | int |
| `deleteRole` (existing — guard added) | roleId | int |

**RoleResponseDto fields** (extended):
```
roleId, roleName, roleCode, description, isSystem, isAssignable, orderBy, companyId, isActive,
colorHex, accessLevel, branchAccess,
canViewOwnData, canViewBranchData, canViewOrgData, canViewCrossBranchData,
recordOwnership,
ipRestrictionEnabled, allowedIps,
timeRestrictionEnabled, workingHoursStart, workingHoursEnd,
sessionLimit, idleTimeoutMinutes,
userCount  ← computed
```

### Tab 2 — Capabilities

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getCapabilities` (extended) | `Paginated<CapabilityResponseDto>` | pagination args |
| `getCapabilityById` (existing) | `CapabilityResponseDto` | capabilityId |

**Mutations:** existing 4 (createCapability, updateCapability, activateDeactivateCapability, deleteCapability — guard added)

**CapabilityResponseDto fields** (extended):
```
capabilityId, capabilityName, capabilityCode, description, isSpecial, orderBy, isActive,
roleCapabilityCount  ← computed
```

### Tab 3 — Matrix

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getRoleCapabilityMatrix` (NEW) | `RoleCapabilityMatrixDto` | — (tenant from HttpContext) |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `bulkUpdateRoleCapabilityMatrix` (NEW) | `RoleCapabilityMatrixDiffDto { cells: [{ roleId, menuId, capabilityId, hasAccess }] }` | `RoleCapabilityMatrixDto` (refreshed) |
| `resetRoleCapabilityMatrix` (NEW) | — | `RoleCapabilityMatrixDto` |
| `resetRoleCapabilityMatrixForRole` (NEW) | `{ roleId }` | `RoleCapabilityMatrixDto` |
| `copyRoleCapabilities` (NEW) | `{ sourceRoleId, targetRoleId }` | `RoleCapabilityMatrixDto` |
| `grantCapabilityToAllRoles` (NEW) | `{ menuId, capabilityId }` | `RoleCapabilityMatrixDto` |
| `revokeCapabilityFromAllRoles` (NEW) | `{ menuId, capabilityId }` | `RoleCapabilityMatrixDto` |

**RoleCapabilityMatrixDto shape:**
```
{
  rows: [
    {
      menuId: int, menuName: string, menuIcon: string?, orderBy: int,
      capabilities: [
        { capabilityId: int, capabilityCode: string, capabilityName: string }
      ]
    }
  ],
  columns: [
    {
      roleId: int, roleName: string, roleCode: string, isSystem: bool, colorHex: string?,
      grantedCount: int, totalCount: int
    }
  ],
  cells: [
    { roleId: int, menuId: int, capabilityId: int, hasAccess: bool, isReadOnly: bool }
  ]
}
```

### Tab 4 — Comparison

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getRoleComparison` (NEW) | `[RoleComparisonRowDto]` | `{ roleIds: [int] }` (1-3 ids) |

**RoleComparisonRowDto shape:**
```
{
  menuId: int, menuName: string,
  capabilityId: int, capabilityCode: string, capabilityName: string,
  accessByRole: [{ roleId: int, hasAccess: bool }]
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (Add_Role_RBAC_Extensions migration must be scaffolded but user-applied)
- [ ] `pnpm dev` — page loads at `/{lang}/accesscontrol/usersroles/rolemanagement`
- [ ] Existing routes `/role`, `/capability`, `/rolecapability` continue to load (as forwarders to `?tab=`)

**Functional Verification (Full E2E — MANDATORY):**

### Tab 1 — Roles
- [ ] Card grid renders all roles (6 seeded system + N custom) on initial load
- [ ] System roles show "Cannot be modified/deleted" footer note; Edit/Delete actions hidden
- [ ] Custom roles show Edit + Delete actions
- [ ] "+ New Role" opens modal in create mode with defaults
- [ ] Clicking a card opens modal in edit (or read-only for system) mode pre-filled
- [ ] All 4 modal sections render with mockup-matching layout (Info / Module Access / Data Scope / Restrictions)
- [ ] Section 1: Role Type field disabled, color picker updates label live
- [ ] Section 2: Cascading hierarchy works (uncheck View → all unchecked); Select All / None work per row
- [ ] Section 3: Branch access dropdown + 4 checkboxes + 3 radios persist & validate (at least 1 visibility required)
- [ ] Section 4: IP toggle reveals textarea; Time toggle reveals time inputs; Session + Idle dropdowns persist
- [ ] "Save Role" validates → POSTs → toast → modal closes → card grid refetches
- [ ] "Save & Configure Capabilities" saves then switches to Tab 3 with role highlighted/scrolled-into-view
- [ ] System-role guard: try to PUT updateRole with new RoleName on IsSystem=true → server returns error
- [ ] Delete custom role → confirm overlay → on confirm → role removed
- [ ] Delete custom role with active UserRoles → primary button disabled w/ "Reassign users first" message + link
- [ ] Color picker invalid hex → form validation blocks save

### Tab 2 — Capabilities
- [ ] List grid renders all capabilities sorted by orderBy
- [ ] "+ Add Capability" opens compact modal
- [ ] Save creates new capability; UPPER case auto-applied to code
- [ ] Edit modal pre-fills + saves
- [ ] Delete on capability with linked RoleCapability rows → server rejects with friendly error toast
- [ ] Activate/Deactivate toggle persists

### Tab 3 — Matrix
- [ ] Matrix renders: section rows (menus) collapsible, sub-rows (capabilities) within
- [ ] All Roles render as columns; SUPERADMIN column always disabled+checked
- [ ] Cell click marks dirty (yellow bg + .changed class); dirty count updates in sticky bar
- [ ] Sticky save bar appears with N>0 changes; hidden when N=0
- [ ] Save sends ONLY changed cells (verify in network tab — payload size linear in change count, not full grid)
- [ ] On save success: cells un-dirty, bar hides, toast "Saved N changes"
- [ ] Discard reverts all dirty cells
- [ ] Reset to Defaults gates behind type-tenant-name confirm; on confirm calls server reset → matrix refetches
- [ ] Reset Role to Default gates behind confirm; resets one role only
- [ ] Search box filters capability rows; section headers hide when all sub-rows hidden
- [ ] Filter badges (All / Granted / Denied / Changed) narrow visible rows
- [ ] Copy Role popover clones source → target cells correctly (cells become dirty)
- [ ] Right-click role header → context menu (Select All / Deselect All / Edit Role)
- [ ] Right-click capability row → context menu (Grant All / Revoke All)
- [ ] Grant All to SUPERADMIN-row capability changes only non-SUPERADMIN roles
- [ ] Try to flip SUPERADMIN cell via direct mutation (curl) → server rejects
- [ ] Audit log: verify N matrix changes produced N audit-log entries with old→new values

### Tab 4 — Comparison
- [ ] 3 role-selector dropdowns; 3rd has "(None)" option
- [ ] Comparison table renders rows × selected roles
- [ ] Rows where roles differ get yellow bg
- [ ] Changing a selector triggers refetch
- [ ] Check-yes / check-no icons render correctly

**DB Seed Verification:**
- [ ] `ROLEMANAGEMENT` menu visible in sidebar under AC_USERSROLES
- [ ] `ROLE`, `CAPABILITY`, `ROLECAPABILITY` hidden in sidebar (MenuRender=false)
- [ ] 6 system roles seeded (Super Admin, Org Admin, Manager, Staff, Field Agent, Auditor) with appropriate IsSystem=true + ColorHex defaults
- [ ] ~30+ capabilities seeded (READ, CREATE, MODIFY, DELETE, EXPORT, IMPORT, APPROVE, ISMENURENDER, REPLY_DRAFT, REPLY_APPROVE, …)
- [ ] RoleCapability baseline rows seeded for the 6 system roles × every menu × every applicable capability (so Tab 3 matrix has dense cells on first open)
- [ ] BUSINESSADMIN grants on ROLEMANAGEMENT + the 3 hidden children (so Tab 1/2/3 mutations succeed)
- [ ] Page renders without crashing on a freshly-seeded DB; no 404s

---

## ⑫ Special Notes & Warnings

**Combined-screen origin:**
- This screen ABSORBS registry #73 (Role-Capability Matrix) and #127 (Capabilities). Those two registry rows can be closed-as-merged once this is `COMPLETED`.
- The existing `/role`, `/capability`, `/rolecapability` routes must continue to load — implement as **forwarders** that redirect to `/rolemanagement?tab=...`. Do not delete the routes (existing bookmarks / deep-links).

**Composite tabbed CONFIG (hybrid):**
- This is the FIRST hybrid CONFIG (mix of SETTINGS_PAGE container + MATRIX_CONFIG + 2 MASTER_GRID-style tabs). When the build completes, update `_CONFIG.md` §⑦ Substitution Guide with this canonical reference for future hybrid screens.
- The 1-visible-parent + N-hidden-child-menus pattern is borrowed from #11 MatchingGift / #136 PrayerRequests Workspace. Re-verify those seeds before writing this one.

**FIRST MATRIX_CONFIG:**
- This is the FIRST MATRIX_CONFIG in the registry. The matrix grid component (`matrix-grid.tsx`) is **net-new infrastructure** — design it as **reusable** (e.g. accept `rows`, `columns`, `cells`, `cellRenderer`, `onCellChange` props) so future MATRIX_CONFIG screens can reuse it.
- Sticky-header CSS is fragile across browsers (especially on Safari + frozen first column + frozen first row simultaneously). Verify against Chrome / Edge / Firefox / Safari before declaring complete.

**System-role guard is multi-layered:**
- FE: hide Edit/Delete actions on system-role cards; disable cells in SUPERADMIN column on matrix
- BE: validator-level rejection on UpdateRole / DeleteRole / matrix UPSERTs targeting SUPERADMIN
- DB: consider a CHECK constraint preventing INSERT/UPDATE on RoleCapability cells where RoleId references SUPERADMIN with HasAccess=false (V2 enhancement)

**EF migration:**
- Per "team-handles-migrations" rule, this prompt scaffolds the migration but does NOT apply it. User must run:
  ```
  dotnet ef migrations add Add_Role_RBAC_Extensions --project Base.Infrastructure --startup-project Base.API
  dotnet ef database update --project Base.Infrastructure --startup-project Base.API
  ```
- Document in Build Log §13 with a `MIGRATION.PLAN.md` file if the column additions need a non-trivial backfill (e.g. existing role rows need a `ColorHex` default that isn't NULL).

**Capability MasterData seed:**
- The DB seed must seed every capability code referenced by `useCapability(...)` calls in the FE. Grep `useCapability\(['"](\w+)['"]` to enumerate, ensure each row exists in `auth.Capabilities`, and ensure baseline `RoleCapability` rows for BUSINESSADMIN are present.

**Performance — matrix size:**
- A tenant with 100 menus × 8 capabilities × 12 roles = 9,600 cells. The grid must virtualize (e.g. react-window or tanstack-virtual) — DO NOT render 9,600 DOM checkboxes synchronously. If V1 ships without virtualization, flag as a HIGH known issue.
- The `GetRoleCapabilityMatrix` query must NOT N+1 over menus — use a single projection with `Include(m => m.Capabilities).Include(rc => rc.RoleCapabilities)` OR a flat join into a `MatrixRowProjectionDto` and pivot client-side.

**Hierarchical "Module Access" UI on Tab 1 modal (Section 2):**
- This is a **shortcut UI** — checking "View" on Contacts means setting `HasAccess=true` for the `READ` capability on every menu under the Contacts module. The translation logic is non-trivial:
  - Read MenuCapability links to know which (Menu × Capability) pairs are valid
  - On Save, compute the set of `RoleCapability` cells to UPSERT
- **V1 recommendation**: persist as JSON snapshot in Role (`ModuleAccessJson` column — NOT in §② schema yet; ADD if implementing) AND fire `bulkUpdateRoleCapabilityMatrix` with computed cells. Power users always have Tab 3 for fine-grained control.
- **V1 alternative**: drop Section 2 from the modal and force admins to use Tab 3 for capability detail. Decide during Solution Resolver phase.

**Service Dependencies** (UI-only — no backend service implementation):

> Everything shown in the mockup is in scope. List items here ONLY if they require an
> external service or infrastructure that doesn't exist in the codebase yet.

- ⚠ SERVICE_PLACEHOLDER: "Export Matrix" CSV (matrix top-right button per role-capability-matrix.html line 540) — handler returns a placeholder CSV download. CSV export infrastructure (Papa Parse or server-side `text/csv`) is not yet present.
- ⚠ SERVICE_PLACEHOLDER: Audit log emission — verify whether an audit-log infrastructure already exists in `Base.Application/Audit/` or `Common/AuditLog/`. If yes, wire all dangerous-action handlers to it. If not, mark as placeholder with TODO + minimal in-memory log table (`auth.RoleAuditLog`) for V1.
- ⚠ SERVICE_PLACEHOLDER: IP-restriction enforcement at login — the Section 4 fields persist but actual middleware enforcement (e.g. on auth controller) is not in scope for THIS screen. Document the enforcement gap in §13 known issues.
- ⚠ SERVICE_PLACEHOLDER: Working-hours enforcement at login — same as above.
- ⚠ SERVICE_PLACEHOLDER: Session-limit enforcement — depends on session-tracking infrastructure that may not exist.

Full UI must be built (cards, modal sections, matrix grid, sticky save bar, comparison table, confirm dialogs). Only the handlers for absent service layers are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-PLAN-1 | planning | HIGH | BE / Module-Access shortcut | Tab 1 modal Section 2 (Module Access) is a shortcut UI over the RoleCapability matrix. Translation logic (module check → many RoleCapability cells) must be implemented; alternative is to drop Section 2 and force matrix-only edits. Solution Resolver to confirm. | OPEN |
| ISSUE-PLAN-2 | planning | HIGH | Matrix perf | A 100-menu × 8-cap × 12-role tenant = 9,600 cells. V1 ships without DOM virtualization → flag as risk; mitigate via initial section-collapse default. | OPEN |
| ISSUE-PLAN-3 | planning | MED | BE migration | EF migration deferred to user per team-handles-migrations rule. ColorHex/AccessLevel/restriction columns added to Roles table — existing rows need defaults (recommend SQL update in migration `Up()`). | OPEN |
| ISSUE-PLAN-4 | planning | MED | BE audit log | Audit-log infrastructure existence unverified. May need a minimal `auth.RoleAuditLog` table for V1 if Common/AuditLog doesn't exist. | OPEN |
| ISSUE-PLAN-5 | planning | MED | Service placeholders | IP/Time/Session restriction fields persist but enforcement middleware is not in scope — only stored. Document in user-facing release notes. | OPEN |
| ISSUE-PLAN-6 | planning | LOW | Capability mockup absent | No dedicated mockup exists for Tab 2 (Capabilities list) — design derived from registry note + standard MASTER_GRID convention. Verify with user before build. | OPEN |
| ISSUE-PLAN-7 | planning | LOW | Sub-tab Comparison promoted to Tab 4 | Original `role-management.html` mockup had Comparison as a Tab 2-style switcher next to "All Roles". This prompt promotes it to a 4th top-level tab to keep the 3 RBAC entities (Role / Capability / Matrix) as Tabs 1-3 per registry note. Easy to revert. | OPEN |
| ISSUE-PLAN-8 | planning | LOW | Existing routes | `accesscontrol/usersroles/role` page is currently active (full grid). Replacing it with a forwarder will break existing capability checks tied to `ROLE.READ`. Verify the hidden-child-menu seeds preserve the capability records. | OPEN |
| ISSUE-PLAN-9 | planning | LOW | First MATRIX_CONFIG | This is the FIRST MATRIX_CONFIG — `_CONFIG.md` §⑦ canonical reference is currently TBD. On completion, update `_CONFIG.md` and `_COMMON.md` § Substitution Guide. | OPEN |
| ISSUE-1 | 1 (2026-05-18) | LOW | BE perf | `GetRoles` / `GetCapabilities` perform 2 extra async sub-queries post-grid-feature (UserCount + ModuleTags / RoleCapabilityCount). Acceptable for V1 but should be converted to projected SQL subqueries in V2. | OPEN |
| ISSUE-2 | 1 (2026-05-18) | LOW | BE matrix-reset baseline | `ResetRoleCapabilityMatrix` clones BUSINESSADMIN as the baseline; if platform tenant's BUSINESSADMIN row was customised the reset inherits those customisations rather than true factory defaults. Introduce a static `SystemRoleDefaults` dictionary in V2. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-18 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. User-approved V1 scope reductions: dropped Role-modal Section 2 (Module Access table) → replaced with deep-link to Tab 3 Matrix; dropped optional `GetRoleSummary` query; deferred matrix DOM virtualization. Reuse decision: existing `RoleCapabilitiesEditor` (3-listbox per-role drill-down) wired into Tab 3 role-header context menu's "Edit Role Capabilities" action.
- **Files touched**:
  - BE (created):
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/RoleCapabilities/Queries/GetRoleCapabilityMatrix.cs`
    - `.../RoleCapabilities/Queries/GetRoleComparison.cs`
    - `.../RoleCapabilities/Commands/BulkUpdateRoleCapabilityMatrix.cs`
    - `.../RoleCapabilities/Commands/ResetRoleCapabilityMatrix.cs`
    - `.../RoleCapabilities/Commands/ResetRoleCapabilityMatrixForRole.cs`
    - `.../RoleCapabilities/Commands/CopyRoleCapabilities.cs`
    - `.../RoleCapabilities/Commands/GrantCapabilityToAllRoles.cs`
    - `.../RoleCapabilities/Commands/RevokeCapabilityFromAllRoles.cs`
  - BE (modified):
    - `Base.Domain/Models/AuthModels/Role.cs` (+14 RBAC columns + UpdateRBACProfile helper)
    - `Base.Infrastructure/Data/Configurations/AuthConfigurations/RoleConfiguration.cs`
    - `Base.Application/Schemas/AuthSchemas/RoleSchemas.cs`
    - `Base.Application/Schemas/AuthSchemas/CapabilitySchemas.cs`
    - `Base.Application/Schemas/AuthSchemas/RoleCapabilitySchemas.cs` (+14 matrix/comparison projection DTOs)
    - `Base.Application/Business/AuthBusiness/Roles/Commands/{CreateRole,UpdateRole,DeleteRole}.cs` (system-role guard + FK guards + conditional validators)
    - `Base.Application/Business/AuthBusiness/Roles/Queries/{GetRoles,GetRoleById}.cs` (UserCount + ModuleTags)
    - `Base.Application/Business/AuthBusiness/Capabilities/Commands/DeleteCapability.cs` (FK guard)
    - `Base.Application/Business/AuthBusiness/Capabilities/Queries/GetCapabilities.cs` (RoleCapabilityCount)
    - `Base.API/EndPoints/Auth/Mutations/RoleCapabilityMutations.cs` (+6 mutations)
    - `Base.API/EndPoints/Auth/Queries/RoleCapabilityQueries.cs` (+2 queries)
    - `Base.Application/Mappings/AuthMappings.cs`
    - `Base.Application/Extensions/DecoratorProperties.cs` (+`RoleManagement = "ROLEMANAGEMENT"`)
  - FE (created — 27 files):
    - `src/domain/entities/auth-service/RoleCapabilityMatrixDto.ts`
    - `src/domain/entities/auth-service/RoleComparisonDto.ts`
    - `src/infrastructure/gql-queries/auth-queries/{CapabilityQuery,RoleCapabilityMatrixQuery,RoleComparisonQuery}.ts`
    - `src/infrastructure/gql-mutations/auth-mutations/RoleCapabilityMatrixMutation.ts`
    - `src/presentation/components/page-components/accesscontrol/usersroles/rolemanagement/{index-page.tsx, index.ts, rolemanagement-store.ts}`
    - `.../rolemanagement/tabs/roles/` — `tab-roles.tsx`, `role-card-grid.tsx`, `role-card.tsx`, `role-modal.tsx`, `role-delete-confirm.tsx`, `sections/{role-info-section,role-module-access-deeplink,role-data-scope-section,role-restrictions-section}.tsx`
    - `.../rolemanagement/tabs/capabilities/{tab-capabilities.tsx,capability-modal.tsx}`
    - `.../rolemanagement/tabs/matrix/{tab-matrix.tsx,matrix-grid.tsx,matrix-toolbar.tsx,matrix-save-bar.tsx,matrix-context-menus.tsx,matrix-confirm-dialogs.tsx,matrix-utils.ts}`
    - `.../rolemanagement/tabs/comparison/{tab-comparison.tsx,comparison-table.tsx}`
    - `src/presentation/pages/accesscontrol/usersroles/rolemanagement.tsx`
    - `src/app/[lang]/accesscontrol/usersroles/rolemanagement/page.tsx`
    - `src/app/[lang]/accesscontrol/usersroles/rolecapability/page.tsx` (new forwarder route)
  - FE (modified):
    - `src/domain/entities/auth-service/{RoleDto,CapabilityDto,index}.ts`
    - `src/infrastructure/gql-queries/auth-queries/{RoleQuery,index}.ts`
    - `src/infrastructure/gql-mutations/auth-mutations/{RoleMutation,index}.ts`
    - `src/app/[lang]/accesscontrol/usersroles/role/page.tsx` (replaced with redirect)
    - `src/app/[lang]/accesscontrol/usersroles/capability/page.tsx` (replaced with redirect)
    - `src/presentation/components/page-components/accesscontrol/usersroles/index.tsx`
    - `src/presentation/pages/accesscontrol/usersroles/index.ts`
  - DB: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/RoleManagement-sqlscripts.sql` (created)
- **Deviations from spec**:
  - Role-modal trimmed from 4 to 3 functional sections (Info / Data Scope / Restrictions) + 1 deep-link card (replaces Module Access shortcut table) — per user approval.
  - `GetRoleSummary` query dropped — was optional in §⑤.
  - Matrix DOM virtualization deferred — known issue ISSUE-PLAN-2 stays OPEN; sections auto-collapse when >5 menus to mitigate.
  - 6 matrix command handlers each contain a duplicated private `BuildMatrix` projection method instead of extracting a shared service — flagged for V2 refactor.
  - `Menu.ModuleId` is `Guid` not `int` — matrix row-section ordering uses `OrderBy(m => m.ModuleId)` which compiles but may not match expected business sort; can add `ThenBy(m.Module.OrderBy)` later.
  - Apollo Client 4.x removed `onCompleted` from `useQuery`; converted to `useEffect`-on-data pattern in `role-modal.tsx` and `capability-modal.tsx` during validation sweep.
- **Known issues opened**:
  - ISSUE-1: `GetRoles`/`GetCapabilities` perform 2 extra async sub-queries post-grid-feature; convert to projected SQL subqueries in V2 (LOW).
  - ISSUE-2: `ResetRoleCapabilityMatrix` clones BUSINESSADMIN as the baseline; if the platform tenant's BUSINESSADMIN row has been customised, reset will inherit those customisations rather than true factory defaults. Static `SystemRoleDefaults` dictionary needed in V2 (LOW).
- **Known issues closed**: None
- **Next step**: (empty — COMPLETED)
- **User actions before testing**:
  1. Run EF migration: `dotnet ef migrations add Add_Role_RBAC_Extensions --project Base.Infrastructure --startup-project Base.API` then `dotnet ef database update`.
  2. Run `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/RoleManagement-sqlscripts.sql` against the tenant DB.
  3. `pnpm dev` and navigate to `/{lang}/accesscontrol/usersroles/rolemanagement`.
  4. Verify all 4 tabs render, role CRUD works, matrix Tab 3 loads with sticky-bottom save bar, comparison Tab 4 supports 2-3 role compare.

### Session 2 — 2026-05-18 — FIX — COMPLETED

- **Scope**: User requested removal of duplicate data-scope gating columns on the Role entity. Per user: "we already have capability and rolecapability entity — this table store role-based access capabilities currently … so no need 'accesslevel, canviewowndata, this related fields'". Confirmed scope = data-scope group only (kept ColorHex, IP / Time / Session restrictions which are session policies, not capability checks). Removed 7 columns from Role + cascaded the removal through EF config, DTOs, validators, system-role guard, GraphQL queries/mutations, FE DTOs, and FE form. Deleted the `RoleDataScopeSection` component and its accordion section from the role modal. The `Data Scope` axis is now expressed solely via `Capability` + `RoleCapability`, consistent with the rest of the platform.
- **Files touched**:
  - BE (modified):
    - `Base.Domain/Models/AuthModels/Role.cs` — removed 7 props (AccessLevel, BranchAccess, CanViewOwnData, CanViewBranchData, CanViewOrgData, CanViewCrossBranchData, RecordOwnership); slimmed Create() defaults and UpdateRBACProfile() signature accordingly.
    - `Base.Infrastructure/Data/Configurations/AuthConfigurations/RoleConfiguration.cs` — removed 7 column configs.
    - `Base.Application/Schemas/AuthSchemas/RoleSchemas.cs` — removed 7 fields from `RoleRequestDto`.
    - `Base.Application/Business/AuthBusiness/Roles/Commands/CreateRole.cs` — removed 3 ValidateStringLength + the at-least-one-CanView rule.
    - `Base.Application/Business/AuthBusiness/Roles/Commands/UpdateRole.cs` — same validator cleanup + slimmed the system-role guard's partial-update block (no longer writes the 7 dropped fields).
  - BE (sql):
    - `sql-scripts-dyanmic/RoleManagement-sqlscripts.sql` — header NOTES updated (14 → 7 columns) and added an explicit "data-scope handled by Capability+RoleCapability" callout. No DDL changes (entity columns are EF-driven).
  - FE (modified):
    - `src/domain/entities/auth-service/RoleDto.ts` — removed 7 fields.
    - `src/infrastructure/gql-queries/auth-queries/RoleQuery.ts` — removed 7 fields from `ROLES_QUERY` + `ROLE_BY_ID_QUERY` selection sets.
    - `src/infrastructure/gql-mutations/auth-mutations/RoleMutation.ts` — removed 7 variables + 7 input mappings from `CREATE_ROLE_MUTATION` and `UPDATE_ROLE_MUTATION`.
    - `.../rolemanagement/tabs/roles/role-modal.tsx` — removed 7 form values, defaults, mapping, the `Data Scope` accordion section, and the `accessLevel` `<Select>` from the Info section.
    - `.../rolemanagement/tabs/roles/role-card.tsx` — removed the access-level chip + `accessLevelLabel` helper.
    - `.../rolemanagement/tabs/roles/sections/role-info-section.tsx` — removed the `accessLevel` `<Select>`; grid collapsed from 3-col to 2-col (RoleName + RoleType only).
  - FE (deleted):
    - `.../rolemanagement/tabs/roles/sections/role-data-scope-section.tsx` — file removed.
- **Deviations from spec**: None — this is an explicit scope reduction per user feedback. Prompt §② Storage Model still lists the 7 dropped columns (kept for historical record); future replans should treat the data-scope axis as Capability-only.
- **Known issues opened**: None
- **Known issues closed**: None (the dropped columns were V1 scope, not a known issue).
- **Next step**: (empty — COMPLETED)
- **User actions before testing**:
  1. Re-scaffold the EF migration if `Add_Role_RBAC_Extensions` was not yet applied: it should now produce only 7 added columns. If a previous migration was already generated with 14 columns, replace it before running `dotnet ef database update`.
  2. Re-run the updated `RoleManagement-sqlscripts.sql`.
  3. `pnpm dev` → re-test role create / edit flow; the modal now has 3 accordion sections (Role Info / Module & Menu Access / Restrictions) — no Data Scope section.

### Session 3 — 2026-05-18 — FIX — COMPLETED

- **Scope**: User requested removal of all remaining newly-added restriction columns on `Role` — IP allow-list, working-hours window, and session/idle timeouts. User reasoning verbatim: "AllowedIps buddy - so remove, then working start hrs and end hrs also will come later - remove all the newly created columns in role - later we can implement - now its not needed … because retiction ips also multiple will come and allowed ip also multiple will come. then time out also country based we can possible to configure - so evrything come as transaction table". Per follow-up clarification, **ColorHex stays** (visual metadata only, not a transaction concern, wired into role cards + color picker). Dropped 7 columns: `IpRestrictionEnabled`, `AllowedIps`, `TimeRestrictionEnabled`, `WorkingHoursStart`, `WorkingHoursEnd`, `SessionLimit`, `IdleTimeoutMinutes`. Restrictions tab/section + `UpdateRBACProfile()` method removed entirely.
- **Files touched**:
  - BE (modified):
    - `Base.Domain/Models/AuthModels/Role.cs` — removed 7 props; deleted `UpdateRBACProfile()` static method (now unused); slimmed `Create()` default block to ColorHex only.
    - `Base.Infrastructure/Data/Configurations/AuthConfigurations/RoleConfiguration.cs` — removed 7 column configs (ColorHex stays).
    - `Base.Application/Schemas/AuthSchemas/RoleSchemas.cs` — removed 7 fields from `RoleRequestDto`.
    - `Base.Application/Business/AuthBusiness/Roles/Commands/CreateRole.cs` — removed `ValidateStringLength(...AllowedIps, 2000)` + the `When(IpRestrictionEnabled)` + `When(TimeRestrictionEnabled)` rule blocks.
    - `Base.Application/Business/AuthBusiness/Roles/Commands/UpdateRole.cs` — same validator cleanup + slimmed system-role partial-update block to write only Description + ColorHex.
  - BE (sql):
    - `sql-scripts-dyanmic/RoleManagement-sqlscripts.sql` — NOTES header now reads "1 new column (ColorHex)" and explains that session-level restrictions are deferred to transaction tables. Migration name updated `Add_Role_RBAC_Extensions` → `Add_Role_ColorHex`.
  - FE (modified):
    - `src/domain/entities/auth-service/RoleDto.ts` — removed 7 fields.
    - `src/infrastructure/gql-queries/auth-queries/RoleQuery.ts` — removed 7 fields from both query selection sets.
    - `src/infrastructure/gql-mutations/auth-mutations/RoleMutation.ts` — removed 7 GraphQL variables + 7 input mappings from `CREATE_ROLE_MUTATION` + `UPDATE_ROLE_MUTATION`.
    - `.../rolemanagement/tabs/roles/role-modal.tsx` — `FormValues` now only `{ roleName, description, colorHex }`; removed restrictions accordion section, related state, useEffect loading, and `buildVariables()` mappings; Accordion `defaultValue` now `["info", "module"]` (was `["info", "restrictions"]`). Modal collapsed from 3 sections to 2.
  - FE (deleted):
    - `.../rolemanagement/tabs/roles/sections/role-restrictions-section.tsx` — file removed.
- **Deviations from spec**: None — explicit user scope reduction. Prompt §② Storage Model still lists the dropped columns as part of the original V1 vision (kept for historical record). When restrictions get re-introduced as transaction tables (multi-IP allow-list, country-aware time windows, per-tenant idle policy), they will model separate entities, not Role columns.
- **Known issues opened**: None
- **Known issues closed**: None
- **Next step**: (empty — COMPLETED)
- **User actions before testing**:
  1. If the `Add_Role_RBAC_Extensions` EF migration was generated against the post-Session-2 entity (7 added columns including ColorHex + 6 restriction cols), re-scaffold it as `Add_Role_ColorHex` so it produces only the single ColorHex column. If neither migration has been applied yet, just generate `Add_Role_ColorHex` fresh.
  2. Re-run the updated `RoleManagement-sqlscripts.sql` (no DDL changes, just header notes).
  3. `pnpm dev` → re-test role create / edit; modal now has **2 accordion sections** (Role Info / Module & Menu Access) — no Data Scope, no Restrictions.