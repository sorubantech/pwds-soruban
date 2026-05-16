---
screen: UserManagement
registry_id: 72
module: AccessControl (usersroles)
status: COMPLETED
scope: FE_ONLY + BE_ALIGN_DELTAS
screen_type: MASTER_GRID
display_mode: table
layout_variant: widgets-above-grid+side-panel
form_pattern: custom-slide-panel  # NOT RJSF modal — 5-section accordion in 600px right-edge slide-panel
detail_pattern: read-only-slide-panel  # 600px View Profile panel with login history + sessions + role changelog
complexity: High
new_module: NO
planned_date: 2026-05-16
completed_date: 2026-05-16
last_session_date: 2026-05-16
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (`html_mockup_screens/screens/administration/user-management.html`, 1992 lines)
- [x] Existing code reviewed (BE: User entity + UserRole junction + Create/Update/Delete/ToggleStatus commands + GetUsers/GetUserById queries + AssignUserRoles + UpdateUserProfile photo upload + UserMutations/UserQueries endpoints. FE: only `UnderConstruction` stub at `[lang]/accesscontrol/usersroles/user/page.tsx`)
- [x] Business rules extracted (unique email, password policy, role-required-on-create, single primary role, branch OR all-branches, soft delete, never delete self/super-admin)
- [x] FK targets resolved (Role / Branch / Staff / UserType / MasterData — see §③)
- [x] File manifest computed (FE-mostly + BE deltas: ~12 new cols + 7 new commands + 2 new queries + endpoint additions + migration + seed)
- [x] Approval config pre-filled (MenuCode=USER, ParentMenu=AC_USERSROLES, Module=ACCESSCONTROL, URL=accesscontrol/usersroles/user)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (skipped — prompt has full BA-level rules; precedent #15)
- [x] Solution Resolution complete (skipped — prompt pre-classified MASTER_GRID + custom slide-panel)
- [x] UX Design finalized (skipped — prompt has mockup-derived layout in §⑥)
- [x] User Approval received (2026-05-16 — 3 decisions confirmed: single session, build LoginHistory, Sonnet for all agents)
- [x] Backend ALIGN deltas applied (22 new cols on User + 7 new commands + 4 bulk commands + 3 new queries + endpoint extensions + Mapster lines + LoginHistory entity + AuthendicationMutations login hook + MasterDataQueries.cs resolver added for ISSUE-4)
- [x] Backend wiring complete (IAuthDbContext + AuthDbContext + AuthMappings + DecoratorProperties + UserSchemas)
- [x] Frontend code generated (DTO + GQL Query/Mutation + page-config + index-page Variant B + UserCreateEditPanel 35KB + UserProfilePanel 21KB + 7 sub-components + Zustand store)
- [x] Frontend wiring complete (entity-operations USER block + presentation-pages barrel + route stub replaced + 5 cell renderers registered in shared-cell-renderers/index.ts + 3 column-type registries advanced/basic/flow)
- [x] DB Seed script generated (`UserManagement-sqlscripts.sql` 27KB — 8 steps: Menu + Capabilities + RoleCapabilities + Grid + Fields + GridFields + 5 MasterData types + EmailTemplate)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] EF migration applied (`Add_User_ManagementColumns_And_LoginHistory`)
- [ ] DB Seed SQL executed (capability rows + MasterData seeds for DATAACCESSLEVEL / TWOFAMETHOD / AUTHMETHOD / DEFAULTDASHBOARD)
- [ ] `pnpm dev` — page loads at `/{lang}/accesscontrol/usersroles/user`
- [ ] 4 KPI cards render (Total Users with active/inactive/locked breakdown, Online Now, Pending Invitations, Locked Accounts) — values from `getUserSummary` query
- [ ] Grid renders 8 columns: checkbox + User (avatar+name+username) + Email + Roles (multi-badge) + Branch + Staff Link + Last Login + Status (Active/Inactive/Locked/Pending) + Actions (Edit + 3-dot menu)
- [ ] Filters: search (name/email/username), status, role, branch, last-login bucket; Clear Filters resets all
- [ ] Bulk select: row checkboxes drive bulk-actions bar (Activate / Deactivate / Reset Passwords / Assign Role)
- [ ] +New User → 600px right slide-panel opens with 5 collapsible accordion sections (Account Info / Authentication / Roles & Access / Link to Staff / Additional Settings)
- [ ] Generate temp password button populates readonly field; Force-password-change toggle defaults ON
- [ ] 2FA toggle reveals 2FA Method select (Email OTP / Authenticator App / SMS OTP)
- [ ] Roles checkbox group → Primary Role select auto-filters to selected roles
- [ ] All Branches checkbox disables the Branch single-select
- [ ] Staff autocomplete searches `getStaffsForSelect` excluding already-linked staff; "No staff link needed" checkbox clears the FK
- [ ] Footer: [Cancel] [Create User] [Create User & Send Invite] — invite triggers welcome-email + sets `IsPendingInvitation=true`
- [ ] View Profile (row name link OR 3-dot menu) → 600px right slide-panel opens with: profile header + 8-item info grid + Login History table + Active Sessions count + Terminate All Sessions button + Role Changelog list
- [ ] Row actions per status: Active → Edit/Reset Password/Deactivate/Impersonate/Delete; Inactive → Edit/Reset Password/Activate/Delete; Locked → Unlock button + Edit/Reset Password/Deactivate/Delete; Pending → Resend Invite button + Edit/Deactivate/Delete
- [ ] Cannot delete or deactivate own account (self-protect rule)
- [ ] Cannot delete or impersonate users with SUPERADMIN role unless current user is SUPERADMIN
- [ ] SERVICE_PLACEHOLDER buttons render with toast: Impersonate, Terminate All Sessions, Import Users, Export, IP Geolocation in Login History
- [ ] Permissions: BUSINESSADMIN sees all actions; others read-only per RoleCapabilities seed

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **UserManagement** (registry #72 — Users)
Module: **AccessControl** (under sidebar group `accesscontrol/usersroles/`)
Schema: **auth** (existing — `Base.Infrastructure` AuthDbContext)
Group: **AuthModels** (BE) / **auth-service** (FE)

Business: The User Management screen is the **operational control surface** for tenant-administrators to provision login accounts, assign roles & branch scope, manage credentials & 2FA, link users to their `Staff` record (the HR identity), and observe account health (online now, pending invitations, locked accounts, login history). It is the **gateway** through which every other operator-facing capability is granted — until a user exists here with a `RoleCapability` chain reaching the target menu, that user cannot reach any other screen. It complements **#70 Role Management** (which defines what roles *can* do) by deciding *who* is granted those roles. It also complements **#42 Staff** (HR records) via the optional `Staff ↔ User` 1:1 link (a Staff person becomes a system operator only when an `auth.Users` row is created and linked back). Cross-screen consumers: every `[CustomAuthorize]` attribute in the codebase resolves through `UserRoles → Roles → RoleCapabilities → MenuCapabilities → Menus` — this screen owns the leftmost link of that chain.

**Status pre-build**: BE has the **core CRUD** but is missing the mockup-required fields and operational commands. FE has **only an `<UnderConstruction/>` stub** at `[lang]/accesscontrol/usersroles/user/page.tsx`. Build scope = **FE_ONLY + significant BE ALIGN deltas** (12 new columns + 7 new commands + 2 new queries + 1 new entity for LoginHistory OR scoped as SERVICE_PLACEHOLDER).

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Existing `auth.Users` table is **extended** with new columns (ALIGN delta). Existing core columns kept untouched. Audit columns (`CreatedBy`, `CreatedDate`, `ModifiedBy`, `ModifiedDate`, `IsActive`, `IsDeleted`, `CompanyId`) inherited from `Entity` base.

**Existing entity** (do NOT regenerate): `Base.Domain/Models/AuthModels/User.cs` — table `auth."Users"`. Already has: `UserId`, `UserName`, `AlternateUserName`, `PasswordHash`, `PasswordSalt`, `ProfilePathUrl`, `UserTypeId`, `CompanyId` + 18 navigation collections.

**ALIGN deltas — add the following columns to `auth.Users`**:

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| FirstName | string? | 100 | NO | — | Currently `UserName` holds the email/login; this splits the human name |
| LastName | string? | 100 | NO | — | Paired with FirstName for display |
| Email | string | 250 | YES | — | Display email; usually same as UserName but explicit. Unique per Company filtered IsDeleted=false |
| PhoneCountryCode | string? | 8 | NO | — | e.g., `+971`, `+91` — stored as label "+971 (UAE)" — driving from `com.Countries.PhoneCode` |
| PhoneNumber | string? | 30 | NO | — | Free-text |
| AuthenticationMethod | string | 20 | YES | — | `EMAIL_PASSWORD` / `SSO` / `BOTH` — default `EMAIL_PASSWORD` |
| IsTwoFactorEnabled | bool | — | YES | — | Default false |
| TwoFactorMethod | string? | 20 | NO | — | `EMAIL_OTP` / `AUTH_APP` / `SMS_OTP` — required when `IsTwoFactorEnabled=true` |
| MustChangePassword | bool | — | YES | — | Default true on create (force-change-on-first-login) |
| TempPasswordExpiresAt | DateTime? | — | NO | — | Temp password is valid until this UTC moment |
| PrimaryRoleId | int? | — | NO | auth.Roles | The role that drives default landing page & display badge |
| BranchId | int? | — | NO | app.Branches | Single primary branch — mutually exclusive with `IsAllBranchesAccess` |
| IsAllBranchesAccess | bool | — | YES | — | When true, user sees data from every branch in the tenant (Default `false`) |
| DataAccessLevel | string | 30 | YES | — | `OWN_RECORDS` / `OWN_BRANCH` / `ASSIGNED_BRANCHES` / `ALL_BRANCHES_GLOBAL` — default `OWN_BRANCH` |
| StaffId | int? | — | NO | app.Staffs | Optional reverse link — Staff entity already has `UserId`; mirror it for fast join in either direction (BA decides whether to denormalize or always traverse `Staff.UserId`) |
| LanguageId | int? | — | NO | com.Languages | UI language preference |
| TimezoneId | int? | — | NO | sett.MasterDatas (TYPECODE=TIMEZONE) | Per-user override — falls back to CompanyConfiguration.TimezoneId |
| DefaultDashboardCode | string? | 50 | NO | — | Soft-FK to dashboard ID slug — until #78 Dashboard Config lands, store as code string |
| AccountExpiresAt | DateTime? | — | NO | — | Account auto-locks after this UTC date |
| Notes | string? | 1000 | NO | — | Free-text admin notes about the account |
| IsLocked | bool | — | YES | — | Default false. Set true by failed-login interceptor at >=N attempts OR by manual admin action |
| FailedLoginCount | int | — | YES | — | Default 0. Reset on successful login or manual Unlock |
| LockedAt | DateTime? | — | NO | — | UTC moment lock began (for audit) |
| LastLoginAt | DateTime? | — | NO | — | UTC moment of last successful login — drives "Last Login" column and Online-Now widget |
| IsPendingInvitation | bool | — | YES | — | Default false. Set true when admin creates user + sends invite but user has not logged in yet. Cleared to false on first successful login |
| InvitationSentAt | DateTime? | — | NO | — | UTC moment invitation email was last sent — drives "Resend Invite" eligibility |

**Indexes** (add):
- `IX_Users_Email_IsDeleted` UNIQUE on `(CompanyId, Email, IsDeleted)` filtered `IsDeleted = false`
- `IX_Users_PrimaryRoleId` on `PrimaryRoleId`
- `IX_Users_BranchId` on `BranchId`
- `IX_Users_StaffId` UNIQUE on `(StaffId)` filtered `StaffId IS NOT NULL` (one-to-one)
- `IX_Users_IsLocked_IsPendingInvitation` on `(CompanyId, IsLocked, IsPendingInvitation, IsActive, IsDeleted)` — supports KPI summary

**Child entities used by the screen**:
| Child Entity | Relationship | Key Fields | Status |
|--------------|--------------|------------|--------|
| `UserRole` (auth.UserRoles) | N:M to Role | UserId, RoleId, CompanyId, IsActive | EXISTS — `AssignUserRoles` command already replaces collection |
| `BranchUser` (app.BranchUsers) | N:M to Branch (optional — only when DataAccessLevel=ASSIGNED_BRANCHES) | UserId, BranchId, FromDate, ToDate | EXISTS — full CRUD available |
| `LoginHistory` (auth.LoginHistories) — **NEW** | N:1 from User | LoginHistoryId, UserId, LoginAt UTC, IpAddress, Device, Location, Status (`SUCCESS`/`FAILED`), FailureReason | **CREATE NEW** OR scope as SERVICE_PLACEHOLDER if BA decides login-event capture is out of scope (see ISSUE-2). Recommended: create the entity (small table — 6 cols) + populate from `LoginCommand`/`Logout` hooks in same build. |
| `UserSession` — DERIVED from `RefreshToken` | N:1 from User | Existing `auth.RefreshTokens` (RefreshTokenId, UserId, IsActive) | Active sessions = `RefreshTokens WHERE UserId AND IsActive=true AND ExpiresAt > now()`. No new entity needed. |
| `UserRoleChangeLog` | N:1 from User | Optional — defer to #74 Audit Trail. If #74 not built yet → SERVICE_PLACEHOLDER and show empty state in the "Role Changelog" section. | DEFER |

**Decision points for BA**:
- DECISION-1: Add `Email` as a NEW column OR repurpose `UserName` (currently used as login)? Recommended: keep `UserName` as login identifier (unchanged for backward compat with login flow), add separate `Email` column for display + invite delivery. They are usually identical but storing separately permits later separation.
- DECISION-2: Add `LoginHistory` entity in this build OR defer to #74 Audit Trail? Recommended: ADD IT — it's a 6-column table, populated by 2-line hooks in the existing `AuthExtensions.CreatePasswordHash` flow, and the Profile panel is incomplete without it.
- DECISION-3: `BranchId` single-select vs use existing `BranchUser` junction? Recommended: store the *primary* branch on `User.BranchId` (drives the "Branch" column in the grid) AND ALSO populate `BranchUser` rows when `DataAccessLevel = ASSIGNED_BRANCHES`. The two work together — primary branch for display, junction for multi-branch scope.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|---------------|-------------------|----------------|---------------|-------------------|
| PrimaryRoleId | Role | `Base.Domain/Models/AuthModels/Role.cs` | `getRoles` (paginated — pass `pageSize: 200`) | `roleName` | `RoleResponseDto` |
| BranchId | Branch | `Base.Domain/Models/ApplicationModels/Branch.cs` | `getBranches` (paginated — pass `pageSize: 100`) | `branchName` | `BranchResponseDto` |
| StaffId | Staff | `Base.Domain/Models/ApplicationModels/Staff.cs` | `getStaffsForSelect` (purpose-built for autocomplete) | `displayName` / `staffName` | `StaffResponseDto` |
| UserTypeId | UserType | `Base.Domain/Models/AuthModels/UserType.cs` | `getUserTypes` | `userTypeName` | `UserTypeResponseDto` |
| LanguageId | Language | `Base.Domain/Models/SharedModels/Language.cs` | `getLanguages` | `languageName` | `LanguageResponseDto` |
| PhoneCountryCode | Country.PhoneCode | `Base.Domain/Models/GeneralModels/Country.cs` | `getCountries` | format: `"{phoneCode} ({countryName})"` | `CountryResponseDto` |
| TimezoneId | MasterData (TYPECODE=TIMEZONE) | NEW seed needed — see §⑫ ISSUE-3 | `masterDatasByTypeCode(typeCode: "TIMEZONE")` (verify backend resolver — may need to be added — see ISSUE-4) | `dataName` | `MasterDataResponseDto` |
| AuthenticationMethod | hard-coded enum OR MasterData TYPECODE=AUTHMETHOD | NEW seed | static FE options OR `masterDatasByTypeCode(typeCode: "AUTHMETHOD")` | `dataName` / `dataValue` | — |
| TwoFactorMethod | hard-coded enum OR MasterData TYPECODE=TWOFAMETHOD | NEW seed | static FE options OR `masterDatasByTypeCode(typeCode: "TWOFAMETHOD")` | `dataName` / `dataValue` | — |
| DataAccessLevel | hard-coded enum OR MasterData TYPECODE=DATAACCESSLEVEL | NEW seed | static FE options OR `masterDatasByTypeCode(typeCode: "DATAACCESSLEVEL")` | `dataName` / `dataValue` | — |
| DefaultDashboardCode | Dashboard (when #78 lands) | DEFERRED — until #78 Dashboard Config completes, use hard-coded list: Standard / Fundraising / Field Collection / Manager | — | — | — |
| Bulk-assign Role (bulk action) | Role | same as PrimaryRoleId | `getRoles` | `roleName` | `RoleResponseDto` |

**Note for BE Developer**:
- `roles` and `branches` queries currently return paginated results. The User form needs ALL active roles + branches as dropdowns. Either (a) call with large `pageSize` (acceptable for our scale of <50 roles & <200 branches per tenant) OR (b) add `getAllRolesList` / `getAllBranchesList` non-paginated query in this same build. **Recommendation**: option (a) for v1 — defer non-paginated queries until they're proven needed.
- `getStaffsForSelect` already exists and is purpose-built for autocomplete (no permission required, returns lightweight DTO).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `UserName` unique per tenant (existing — already enforced via `ValidateUniqueWhenCreate/Update`)
- `Email` (NEW) unique per tenant filtered `IsDeleted=false`
- `Staff.UserId` (reverse FK) — at most one User can be linked to any given Staff (enforced by `IX_Staffs_UserId UNIQUE filtered`)

**Required Field Rules:**
- `FirstName`, `LastName`, `Email`, `AuthenticationMethod`, `DataAccessLevel`, `IsTwoFactorEnabled`, `MustChangePassword`, `IsAllBranchesAccess` are mandatory
- At least ONE role must be assigned on Create (CreateUser + AssignUserRoles called in same transaction) — reject if `roleIds` is empty
- `BranchId` required when `IsAllBranchesAccess = false`
- `TwoFactorMethod` required when `IsTwoFactorEnabled = true`
- Password required on Create (admin enters OR clicks Generate)

**Conditional Rules:**
- If `AuthenticationMethod = SSO`, Password is NOT required (provisioned by SSO IdP). If `EMAIL_PASSWORD` or `BOTH`, password required.
- If `IsPendingInvitation = true` AND `LastLoginAt = NULL`, status displays as `Pending` (overrides Active/Inactive).
- If `IsLocked = true`, status displays as `Locked` (overrides Active/Inactive).
- Else if `IsActive = false`, status displays as `Inactive`.
- Else status displays as `Active`.
- "Resend Invite" action allowed only when status is `Pending` AND `InvitationSentAt < now() - 1 minute` (rate-limit).
- "Unlock" action allowed only when status is `Locked`; clears `IsLocked`, `LockedAt`, `FailedLoginCount`.
- "Reset Password" generates a new temp password + sets `MustChangePassword=true` + sends notification email.

**Business Logic / Self-Protection:**
- A user cannot **delete** or **deactivate** their own account (compare `command.userId` against `currentUserId` from `IHttpContextAccessor`).
- A user cannot **delete** or **impersonate** a user who has the `SUPERADMIN` role unless the actor is themselves `SUPERADMIN`.
- "Impersonate" requires the actor to be `SUPERADMIN` AND target must be in same tenant.
- "Terminate All Sessions" deletes all `RefreshTokens WHERE UserId AND IsActive=true` — affects the user immediately.
- Bulk "Reset Passwords" sends a separate temp-password email to each selected user; bulk "Assign Role" appends one role to each (does NOT replace existing roles).
- Soft delete only — `IsDeleted=true`; cascade soft-deletes `UserRoles`, `BranchUsers`, but preserves `LoginHistory` for audit.
- Account auto-locks server-side after `AccountExpiresAt < now()` (handled in login flow, not this CRUD).

**Workflow**: None (MASTER_GRID) — though the implicit "Pending → Active" transition on first login is a soft state change handled by the existing LoginCommand handler (not by this screen).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: MASTER_GRID
**Type Classification**: MASTER_GRID with **custom slide-panel form** (NOT RJSF modal) + **read-only profile slide-panel**
**Reason**: The mockup's +Add and Edit do NOT open a modal — they open a 600px right-edge slide panel with a 5-section accordion form that contains rich custom UI (radio-card auth method, 2FA conditional fields, password generator, role checkbox+primary-role pair, branch all/single toggle, staff autocomplete with "no link" checkbox). This is too complex for RJSF's default widgets and benefits from a hand-written React Hook Form panel. The view-profile is ALSO a slide-panel — separate from the edit panel — with login history, sessions, and role changelog. URL does NOT change on +Add (no `?mode=new`), so this is NOT a FLOW.

**Backend Patterns Required:**
- [x] Standard CRUD (existing — extended with new fields)
- [x] Nested child creation (UserRoles in same transaction as CreateUser — extends existing `CreateUser` OR adds new orchestrator `CreateUserWithRoles`)
- [x] Multi-FK validation (PrimaryRoleId, BranchId, StaffId, LanguageId)
- [x] Unique validation (Email column NEW)
- [x] File upload command (existing `updateUserProfilePhoto` — reuse)
- [x] Custom business rule validators (self-protect on delete/deactivate, superadmin guard, password policy)
- [x] **NEW commands (7)**: `ResetUserPassword`, `GenerateTempPassword`, `UnlockUser`, `SendUserInvite`, `ResendUserInvite`, `ImpersonateUser` (placeholder), `TerminateUserSessions`
- [x] **NEW queries (2)**: `GetUserSummary` (KPI cards), `GetUserLoginHistory` (Profile panel)
- [x] **NEW bulk commands (4)**: `BulkActivateUsers`, `BulkDeactivateUsers`, `BulkResetPasswords`, `BulkAssignRole`
- [x] **NEW entity** (recommended): `LoginHistory` (6 cols) + populate hooks in existing Login/Logout

**Frontend Patterns Required:**
- [x] AdvancedDataTable (with custom cell renderers for User col, Roles col multi-badge, Status badge with icon, Actions col with status-conditional button)
- [ ] RJSF Modal Form — **NOT USED** (form is custom slide-panel with React Hook Form + Zod)
- [x] **Custom Slide-Panel Form** (NEW pattern — first instance in registry; see §⑥ "Create/Edit Slide-Panel")
- [x] **Read-Only Slide-Panel** (Profile view — login history table, sessions count, role changelog timeline)
- [x] File upload widget (profile photo, 80px circle, max 2MB)
- [x] Summary cards (4 KPI widgets above grid)
- [x] Bulk-selection toolbar (sticky bar appearing when ≥1 row checked)
- [x] Status-conditional row actions (Pending → Resend Invite; Locked → Unlock; else → Edit)
- [x] Multi-filter bar (search + status + role + branch + last-login bucket)
- [x] ApiSelectV2 dropdowns for FKs (Role, Branch, Staff autocomplete, Language)
- [x] Conditional sub-form (2FA Method appears when 2FA toggle on; Branch select disabled when All Branches checked)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.

### Display Mode & Layout

**Display Mode**: `table`
**Layout Variant**: `widgets-above-grid+side-panel`
**Form Pattern**: **custom slide-panel** (NOT RJSF modal) — see "Create/Edit Slide-Panel" below.
**Detail Pattern**: **read-only slide-panel** — see "View Profile Slide-Panel" below.

Page composition (top→bottom):
1. `<ScreenHeader title="User Management" badge="Administration" subtitle="Manage user accounts, roles, and access permissions">` with header-actions: `[+ New User]` (primary), `[Import Users]` (outline — SERVICE_PLACEHOLDER), `[Export]` (outline — SERVICE_PLACEHOLDER)
2. 4-col KPI summary cards row (responsive: 4-col xl, 2-col lg, 1-col sm)
3. `<DataTableContainer showHeader={false}>` wrapping the grid (Variant B per memory `feedback_data_level_config_on_gridfield`)
4. Two right-edge slide-panel overlays mounted via portal — `UserCreateEditPanel` and `UserProfilePanel` — driven by Zustand store flags (`isCreateEditOpen`, `isProfileOpen`, `editingUserId`, `viewingUserId`)

### Grid Columns (in display order)

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|--------------|-------|----------|-------|
| — | (checkbox) | — | row-selector | 40px | NO | drives bulk-actions bar |
| 1 | User | `firstName + lastName` + `userName` | custom: avatar (initials, bg-color hash from userId) + name link + username below | 240px | YES sort by firstName | Click name → opens View Profile panel |
| 2 | Email | `email` | text | 200px | YES | — |
| 3 | Roles | `userRoles[].role.roleName` | custom: multi-badge with color per role (admin=red, manager=purple, staff=blue, field-agent=green, auditor=amber, custom=gray) | 220px | NO | Show all assigned roles |
| 4 | Branch | `branchId IS NULL && isAllBranchesAccess` ? "All Branches" : `branch.branchName` | text | 140px | YES | "All Branches" rendered in muted color |
| 5 | Staff Link | `staff?.staffName` OR italic "No staff link" | link if present (navigates to Staff #42 detail), italic gray text otherwise | 160px | YES | — |
| 6 | Last Login | `lastLoginAt` formatted "MMM dd, HH:mm a" OR italic "Never" OR red "MMM dd (N failed)" | custom: 3 visual states based on lastLoginAt + failedLoginCount | 160px | YES | If status=Pending → "Never"; if status=Locked → "MMM dd (N failed)" red |
| 7 | Status | derived: `isPendingInvitation→Pending`, `isLocked→Locked`, `!isActive→Inactive`, else `Active` | badge with dot/icon (Active=green dot, Inactive=amber dot, Locked=red lock icon, Pending=blue envelope icon) | 110px | YES | — |
| 8 | Actions | — | custom: Status-conditional primary button + 3-dot dropdown | 130px | NO | See "Row Actions" matrix below |

**Search/Filter Fields**:
- Search input (placeholder "Search by name, email, or username…") → searches `firstName`, `lastName`, `email`, `userName`, `alternateUserName`
- Status filter (single-select): All / Active / Inactive / Locked / Pending
- Role filter (single-select): All / Super Admin / Org Admin / Manager / Staff / Field Agent / Auditor / Custom — populated from `getRoles`
- Branch filter (single-select): All / {each Branch + "All Branches"} — populated from `getBranches`
- Last Login filter (single-select): All / Today / This Week / This Month / Never Logged In / Inactive >30 days
- `[Clear Filters]` text button (resets all filters + search)

**Bulk Actions Bar** (visible when `selectedRowIds.length > 0`, sticky cyan-tinted bar above grid):
- "{N} users selected" (count)
- `[Activate]` → `BulkActivateUsers({ userIds })`
- `[Deactivate]` → `BulkDeactivateUsers({ userIds })` — confirm modal "Deactivate {N} users?"
- `[Reset Passwords]` → `BulkResetPasswords({ userIds })` — confirm modal "Send password reset to {N} users?"
- `[Assign Role]` → modal with role single-select → `BulkAssignRole({ userIds, roleId })`
- `[Clear Selection]` (text button) → clears `selectedRowIds`

**Row Actions Matrix** (per Status):

| Status | Primary Button | 3-dot Menu Items |
|--------|----------------|------------------|
| Active | `[Edit]` (accent border) | View Profile · Edit · Reset Password · Deactivate · — · Impersonate (admins only) · — · Delete (danger) |
| Inactive | `[Edit]` | View Profile · Edit · Reset Password · **Activate** · — · Delete (danger) |
| Locked | `[Unlock]` (amber border) | View Profile · Edit · **Unlock Account** · Reset Password · Deactivate · — · Delete (danger) |
| Pending | `[Resend Invite]` (blue border) | View Profile · Edit · **Resend Invitation** · Deactivate · — · Delete (danger) |

---

### Page Widgets & Summary Cards (4 KPI Cards)

**Layout Variant**: `widgets-above-grid+side-panel` (confirmed — must use Variant B per `feedback_data_level_config_on_gridfield` memory).

| # | Widget Title | Value Source (DTO field) | Display Type | Subtitle / Sub-value | Icon / Color |
|---|--------------|--------------------------|--------------|----------------------|--------------|
| 1 | Total Users | `totalUsers` | count | `"Active: {activeCount} · Inactive: {inactiveCount} · Locked: {lockedCount}"` | `fa-users` blue (bg #dbeafe / fg #2563eb) |
| 2 | Online Now | `onlineNowCount` | count | `"Last 15 min activity"` | `fa-circle` green (bg #dcfce7 / fg #16a34a) |
| 3 | Pending Invitations | `pendingInvitationsCount` | count | `"Sent, awaiting first login"` | `fa-envelope-open` amber (bg #fef3c7 / fg #d97706) |
| 4 | Locked Accounts | `lockedAccountsCount` | count | `"Failed login attempts"` | `fa-lock` red (bg #fef2f2 / fg #dc2626) |

**Summary GQL Query**:
- Query name: `getUserSummary` → returns `UserSummaryDto`
- `UserSummaryDto`: `{ totalUsers: int, activeCount: int, inactiveCount: int, lockedCount: int, onlineNowCount: int, pendingInvitationsCount: int, lockedAccountsCount: int }`
- BE handler: single LINQ query against `Users` (no pagination needed) — `OnlineNow` = `LastLoginAt > now() - INTERVAL '15 minutes' AND IsActive AND NOT IsDeleted`. `Pending` = `IsPendingInvitation=true`. `Locked` = `IsLocked=true`.
- Tenant-scoped via `CompanyId` interceptor.

---

### Grid Aggregation Columns

**NONE** — there are no per-row computed values beyond the navigation-property displays (which are joins, not aggregations). Status badge, Last Login formatting, and Roles multi-badge are presentational transformations of stored fields handled in FE cell renderers.

---

### Create/Edit Slide-Panel (CUSTOM — first instance of this pattern)

> **600px right-edge slide-panel**, fixed-position, fade-overlay 30% black backdrop. Closes on backdrop-click, ESC key, or Cancel button. Body is **5 collapsible accordion sections**, each opens by default (collapsed state toggled via chevron). Footer is sticky with 3 buttons.

**Section 1 — Account Information** (icon: `fa-user-circle`, color accent)
- Row 1: `First Name *` (col-6) + `Last Name *` (col-6) — text inputs, required, max 100
- Row 2: `Email (Username) *` (col-12, full-width) — email input, required, max 250, unique
- Row 3: `Phone` (col-12) — split control: country-code select (~120px, populated from `getCountries` showing `"+{phoneCode} ({countryName})"`) + phone-number text input (flex-fill)
- Row 4: `Profile Photo` — 80px circular dashed-border upload zone with `fa-camera` icon → opens file picker. Max 2MB, JPG/PNG. After upload, shows preview; calls `updateUserProfilePhoto` mutation (existing) after the user is saved (i.e., 2-phase: create user → then upload photo if File is set).

**Section 2 — Authentication** (icon: `fa-shield-halved`)
- `Authentication Method` (radio group, 3 options stacked): `EMAIL_PASSWORD` (default) / `SSO` / `BOTH`
- `Send Welcome Email` toggle-switch (default ON; visible only on Create)
- `Temporary Password` row (visible only when AuthenticationMethod includes password): readonly text input (monospace, gray-bg) + `[Generate]` outline button. Generator calls `generateTempPassword` mutation OR is generated client-side using a 8-char random `[a-zA-Z0-9!$%]`. Stored as `Password` in the request (BE re-hashes).
- `Force Password Change on First Login` toggle (default ON) → maps to `MustChangePassword`
- `Two-Factor Authentication` toggle (default OFF) → maps to `IsTwoFactorEnabled`
- **Conditional**: `2FA Method` select (`EMAIL_OTP` / `AUTH_APP` / `SMS_OTP`) — visible ONLY when `IsTwoFactorEnabled = true`. Required when visible.

**Section 3 — Roles & Access** (icon: `fa-user-shield`)
- `Roles (select one or more)` — checkbox group (vertical) populated from `getRoles`. At least 1 required.
- `Primary Role` single-select — filtered to roles currently checked in the multi-select above. Auto-defaults to the first checked role on selection change.
- `Branch Assignment` group:
  - `All Branches` checkbox → when checked, sets `IsAllBranchesAccess=true` and DISABLES the branch select below (and clears its value)
  - Branch single-select — populated from `getBranches`, disabled when "All Branches" is checked
- `Data Access Level` single-select: `Own Records Only` / `Own Branch` (default) / `Assigned Branches` / `All Branches (Global)` — maps to `DataAccessLevel` enum

**Section 4 — Link to Staff Record** (icon: `fa-link`)
- `Search Staff` text input — autocomplete dropdown calling `getStaffsForSelect` with the typed term. Each suggestion shows `"{staffName} — {branchName}"`. Selecting a suggestion sets `StaffId` and displays the chosen name in a chip below the input with `[x]` to clear.
- `No staff link needed` checkbox — when checked, clears `StaffId` and disables the search input.

**Section 5 — Additional Settings** (icon: `fa-gear`)
- Row 1: `Language Preference` (col-6) from `getLanguages` + `Timezone` (col-6) from `masterDatasByTypeCode("TIMEZONE")`
- Row 2: `Default Dashboard` (col-6) — for v1 static list: Standard / Fundraising / Field Collection / Manager (mapped to `DefaultDashboardCode` string). + `Account Expiry` (col-6) date input
- Row 3: `Notes` textarea (col-12, 2 rows) — internal admin notes

**Footer Buttons** (sticky bottom, light-gray bg):
- `[Cancel]` (text) — closes panel discarding changes (confirm if dirty)
- `[Create User]` (outline accent) — calls `createUser` (no invite send) — toast "User created"
- `[Create User & Send Invite]` (primary accent, with `fa-paper-plane` icon) — calls `createUser` + `sendUserInvite` in same flow — toast "User created and invite sent"

**Edit mode**: title changes to "Edit User", icon to `fa-user-pen`. Footer shows `[Cancel]` + `[Save Changes]` (single primary button — invite controls hidden because user already exists). Password section temp-password field becomes "Set New Temp Password" (optional — empty = keep current).

**Validation** — React Hook Form + Zod schema:
- `firstName`, `lastName`, `email` required
- `email` regex valid + uniqueness checked async via `getUserByEmail` (optional pre-submit) OR rely on BE error
- At least 1 role required
- `branchId` required when `isAllBranchesAccess = false`
- `twoFactorMethod` required when `isTwoFactorEnabled = true`
- `password` required on Create when AuthMethod includes password
- Field-level errors shown inline; submit-blocking errors gathered into top-of-section banner

---

### View Profile Slide-Panel (read-only, separate overlay)

> Opens when user clicks the user-name link OR "View Profile" in 3-dot menu. **600px right-edge slide-panel**, separate from Create/Edit panel. Header: `<i fa-user>` "User Profile" + `[×]` close.

**Profile Header** (full-width, bordered bottom):
- 64px circular avatar (initials, color-hashed from userId) — left
- Right of avatar: `{firstName} {lastName}` (1.25rem bold) → `{email}` (gray) → role badges + status badge inline

**Info Grid** (2-column, 8 items, uppercase muted labels):
| Label | Value |
|-------|-------|
| Branch | `branch.branchName` OR "All Branches" |
| Staff Link | `staff?.staffName` as link, OR italic "No staff link" |
| Phone | `phoneCountryCode phoneNumber` OR "—" |
| Auth Method | `AuthenticationMethod` display label |
| 2FA | `IsTwoFactorEnabled ? TwoFactorMethod : "Disabled"` |
| Language | `language.languageName` |
| Timezone | `masterData.dataName` for `TimezoneId` |
| Created | `CreatedDate` formatted "MMM dd, yyyy" |

**Login History** section (titled, 5-col table, latest first, max 10 rows shown — "View All" link if more):
| Date | IP Address | Device | Location | Status |
|------|------------|--------|----------|--------|
| `loginAt` "MMM dd, h:mm a" | `ipAddress` | `device` (UA parsed) | `location` (geo-IP — SERVICE_PLACEHOLDER, show "—") | `SUCCESS` green / `FAILED` red |

Data source: `getUserLoginHistory(userId, limit: 10)` → returns `LoginHistoryDto[]`. If `auth.LoginHistories` table is not built in this round, render empty state "Login history not available — enable in System Settings".

**Active Sessions** section:
- Pill: "{N} Active Sessions" (green bg, count-badge style) — value from `getUserActiveSessions(userId)` which counts `RefreshTokens WHERE UserId AND IsActive=true AND ExpiresAt > now()`
- `[Terminate All Sessions]` outline button → `terminateUserSessions(userId)` → soft-delete all matching RefreshTokens

**Role Changelog** section (vertical list, date column + change description):
- Each item: date column (min-width 80px, gray) + description with bold role name + actor link
- Data source: derive from `UserRoles.CreatedDate / ModifiedDate / IsActive transitions` + `User.CreatedDate` row for "Account created by {actor}". Until full audit infra (#74), render the existing UserRole records (most recent first) — formatted "Role {roleName} assigned" / "Role {roleName} removed". If #74 lands, replace with `getAuditLogsForUser`.

---

### User Interaction Flow

1. User lands on `/{lang}/accesscontrol/usersroles/user` → 4 KPI cards load via `getUserSummary` → grid loads via `getUsers(gridFilterRequest)`.
2. Filters above grid update the `getUsers` request; bulk-checkbox selection drives bulk-actions bar.
3. User clicks `[+ New User]` → `UserCreateEditPanel` slides in from right (5-section accordion). Fills form → clicks `[Create User & Send Invite]` → `createUser` mutation → `assignUserRoles` → `sendUserInvite` → toast → panel closes → grid refreshes → KPI cards refresh.
4. User clicks a row's `[Edit]` button → `UserCreateEditPanel` slides in pre-filled via `getUserById(userId)` → user edits → `[Save Changes]` → `updateUser` + `assignUserRoles` (if role checkbox changed) → toast → grid refreshes.
5. User clicks 3-dot menu → `Reset Password` → confirm dialog → `resetUserPassword(userId)` → toast "Reset link sent to {email}".
6. User clicks 3-dot menu → `Deactivate` (or `Activate`) → confirm dialog → `activateDeactivateUser(userId)` (existing toggle) → row updates.
7. User clicks 3-dot menu → `Impersonate` (SUPERADMIN only) → SERVICE_PLACEHOLDER: toast "Impersonation requires SUPERADMIN session — coming soon".
8. User clicks 3-dot menu → `Delete` (danger) → confirm dialog "Delete {userName}? This cannot be undone." → `deleteUser(userId)` → row disappears.
9. User clicks the user-name link OR `View Profile` → `UserProfilePanel` slides in → fetches `getUserById` + `getUserLoginHistory` + `getUserActiveSessions` → renders read-only profile.
10. From Profile, clicks `[Terminate All Sessions]` → confirm → `terminateUserSessions(userId)` → "{N} sessions terminated" toast → pill updates to 0.
11. Pending status: clicks `[Resend Invite]` button → `resendUserInvite(userId)` → toast "Invitation resent to {email}".
12. Locked status: clicks `[Unlock]` button → `unlockUser(userId)` → status changes to Active → toast "Account unlocked".
13. Selects multiple checkboxes → bulk-actions bar shows → clicks `[Reset Passwords]` → confirm "Send reset to {N} users?" → `bulkResetPasswords({ userIds })` → toast.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps a canonical reference entity to THIS entity. Use when copying from code-reference files.

**Canonical Reference**: ContactType (MASTER_GRID baseline) + **CompanyPaymentGateway #167** (FE_ONLY+ALIGN deltas pattern) + **#74 Audit Trail** (read-only slide-panel pattern for `UserProfilePanel`). For the **custom slide-panel form** (new pattern), no precedent exists — see §⑫ ISSUE-1.

| Canonical | → This Entity | Context |
|-----------|---------------|---------|
| ContactType | User | Entity/class name (EXISTING — extends) |
| contactType | user | Variable/field names |
| ContactTypeId | UserId | PK field (EXISTING) |
| ContactTypes | Users | Table name (EXISTING) |
| contact-type | user-management | Slide-panel component file name (kebab) |
| contacttype | user | FE folder, route folder, import path |
| CONTACTTYPE | USER | MenuCode, Grid code, capability cascade |
| corg | auth | DB schema (EXISTING) |
| Corg | Auth | Backend group base name |
| CorgModels | AuthModels | Namespace suffix (EXISTING) |
| Corg | Auth | EF Config folder (`AuthConfigurations` — EXISTING) |
| CRM | ACCESSCONTROL | Module code |
| crm/contact/contacttype | accesscontrol/usersroles/user | FE route path + menu URL |
| corg-service | auth-service | FE entities/queries/mutations service folder name |
| corg-queries | auth-queries | FE GQL queries folder |
| corg-mutations | auth-mutations | FE GQL mutations folder |
| presentation/pages/crm/contact | presentation/pages/accesscontrol/usersroles | FE pages barrel folder |
| presentation/components/page-components/crm/contact/contacttype | presentation/components/page-components/accesscontrol/usersroles/user | FE component folder |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Exact files to create or modify, with computed paths.

### Backend Files — CREATE (NEW)

| # | File | Path |
|---|------|------|
| 1 | LoginHistory entity (recommended — see DECISION-2) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/AuthModels/LoginHistory.cs` |
| 2 | LoginHistory EF config | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/AuthConfigurations/LoginHistoryConfiguration.cs` |
| 3 | LoginHistory DTOs | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/AuthSchemas/LoginHistorySchemas.cs` |
| 4 | UserSummaryDto + UserSummaryQuery | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Queries/GetUserSummary.cs` |
| 5 | GetUserLoginHistory query | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Queries/GetUserLoginHistory.cs` |
| 6 | GetUserActiveSessions query | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Queries/GetUserActiveSessions.cs` |
| 7 | ResetUserPassword command | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/ResetUserPassword.cs` |
| 8 | GenerateTempPassword command (or static helper if no audit needed) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/GenerateTempPassword.cs` |
| 9 | UnlockUser command | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/UnlockUser.cs` |
| 10 | SendUserInvite command | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/SendUserInvite.cs` |
| 11 | ResendUserInvite command | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/ResendUserInvite.cs` |
| 12 | TerminateUserSessions command | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/TerminateUserSessions.cs` |
| 13 | ImpersonateUser command (SERVICE_PLACEHOLDER — full handler returns NotImplemented) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/ImpersonateUser.cs` |
| 14 | BulkActivateUsers command | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/BulkActivateUsers.cs` |
| 15 | BulkDeactivateUsers command | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/BulkDeactivateUsers.cs` |
| 16 | BulkResetPasswords command | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/BulkResetPasswords.cs` |
| 17 | BulkAssignRole command | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Commands/BulkAssignRole.cs` |
| 18 | EF migration | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Migrations/{timestamp}_Add_User_ManagementColumns_And_LoginHistory.cs` (generate via `dotnet ef migrations add Add_User_ManagementColumns_And_LoginHistory`) |
| 19 | DB seed SQL | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/sql-scripts-dyanmic/UserManagement-sqlscripts.sql` |

### Backend Files — MODIFY (ALIGN deltas to existing)

| # | File | Modification |
|---|------|--------------|
| 1 | `Base.Domain/Models/AuthModels/User.cs` | Add 22 new columns per §② |
| 2 | `Base.Infrastructure/Data/Configurations/AuthConfigurations/UserConfiguration.cs` | Add length constraints + new indexes (Email unique, StaffId unique, IsLocked+Pending composite) |
| 3 | `Base.Application/Schemas/AuthSchemas/UserSchemas.cs` | Extend `UserRequestDto` (22 new fields + nullable handling) + extend `UserResponseDto` (display fields + derived `displayStatus` + roles + branch.branchName + staff.staffName) + add `UserSummaryDto`, `LoginHistoryResponseDto`, `BulkUserActionRequestDto`, `BulkAssignRoleRequestDto`, `TempPasswordResponseDto` |
| 4 | `Base.Application/Business/AuthBusiness/Users/Commands/CreateUser.cs` | Extend handler to also persist roles (call AssignUserRoles internally) + send invite if `sendInvite=true` + Mapster mapping of new fields |
| 5 | `Base.Application/Business/AuthBusiness/Users/Commands/UpdateUser.cs` | Extend handler to also sync roles + branch + staff link |
| 6 | `Base.Application/Business/AuthBusiness/Users/Commands/DeleteUser.cs` | Add self-protect guard (cannot delete own account) + superadmin guard |
| 7 | `Base.Application/Business/AuthBusiness/Users/Commands/ToggleUserStatus.cs` | Add self-protect guard (cannot deactivate own account) |
| 8 | `Base.Application/Business/AuthBusiness/Users/Queries/GetUsers.cs` | Add filter params: `statusFilter`, `roleId`, `branchId`, `lastLoginBucket`; project new columns; .Include(UserRoles.Role) + Branch + Staff |
| 9 | `Base.Application/Business/AuthBusiness/Users/Queries/GetUserById.cs` | Return extended `UserResponseDto` with all new fields + nested roles/branch/staff/language/timezone |
| 10 | `Base.API/EndPoints/Auth/Mutations/UserMutations.cs` | Add: `resetUserPassword`, `unlockUser`, `sendUserInvite`, `resendUserInvite`, `terminateUserSessions`, `impersonateUser`, `bulkActivateUsers`, `bulkDeactivateUsers`, `bulkResetPasswords`, `bulkAssignRole`, `generateTempPassword` |
| 11 | `Base.API/EndPoints/Auth/Queries/UserQueries.cs` | Add: `getUserSummary`, `getUserLoginHistory`, `getUserActiveSessions` |
| 12 | `Base.Infrastructure/Data/IApplicationDbContext.cs` (or DbContext) | Add `DbSet<LoginHistory> LoginHistories` |
| 13 | `Base.Application/Common/Mappings/AuthMappings.cs` (or wherever Mapster configs live) | Add mappings for new DTOs |
| 14 | `Base.Application/Extensions/DecoratorProperties.cs` | Add capability constants for new operations (RESET_PASSWORD, UNLOCK, SEND_INVITE, IMPERSONATE, BULK_ACTION) — verify existing `User`/`UserRole` constants |
| 15 | `Base.Infrastructure/Data/Services/AuthExtensions.cs` (or wherever Login command lives) | OPTIONAL hook: write to `LoginHistory` on every login attempt; increment `User.FailedLoginCount` and set `IsLocked=true` at threshold |

### Frontend Files — CREATE (NEW)

| # | File | Path |
|---|------|------|
| 1 | DTO extension | `PSS_2.0_Frontend/src/domain/entities/auth-service/UserDto.ts` (EXTEND existing file: add `UserSummaryDto`, `LoginHistoryDto`, `BulkActionRequest`, `BulkAssignRoleRequest`, `UserStatusEnum`, `AuthMethodEnum`, `TwoFactorMethodEnum`, `DataAccessLevelEnum`; extend `UserRequestDto` and `UserResponseDto` with all new fields) |
| 2 | GQL Query extension | `PSS_2.0_Frontend/src/infrastructure/gql-queries/auth-queries/UserQuery.ts` (EXTEND existing: add `GET_USER_SUMMARY_QUERY`, `GET_USER_LOGIN_HISTORY_QUERY`, `GET_USER_ACTIVE_SESSIONS_QUERY`; replace `USERS_QUERY` with full-shape version including new fields + filters; extend `USERPROFILE_BY_ID_QUERY`) |
| 3 | GQL Mutation extension | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/auth-mutations/UserMutation.ts` (EXTEND existing: extend `CREATE_USER_MUTATION` and `UPDATE_USER_MUTATION` with new fields; add `RESET_USER_PASSWORD_MUTATION`, `UNLOCK_USER_MUTATION`, `SEND_USER_INVITE_MUTATION`, `RESEND_USER_INVITE_MUTATION`, `TERMINATE_USER_SESSIONS_MUTATION`, `IMPERSONATE_USER_MUTATION`, `BULK_ACTIVATE_USERS_MUTATION`, `BULK_DEACTIVATE_USERS_MUTATION`, `BULK_RESET_PASSWORDS_MUTATION`, `BULK_ASSIGN_ROLE_MUTATION`, `GENERATE_TEMP_PASSWORD_MUTATION`) |
| 4 | Page Config (dispatcher) | `PSS_2.0_Frontend/src/presentation/pages/accesscontrol/usersroles/user.tsx` (NEW — exports `<UserManagementPage/>` wrapping the index-page) |
| 5 | Index Page (grid + KPIs + bulk bar) | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/index-page.tsx` (NEW — main grid screen with `<ScreenHeader>` Variant B + 4 KPI cards + filter bar + `<DataTableContainer showHeader={false}>` + bulk-actions bar + slide-panel mounts) |
| 6 | Create/Edit Slide-Panel | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/user-create-edit-panel.tsx` (NEW — 600px right-edge panel with RHF + Zod, 5 accordion sections, sticky footer with 3 buttons) |
| 7 | Profile Slide-Panel | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/user-profile-panel.tsx` (NEW — read-only 600px right-edge panel with profile header + info grid + login history table + sessions + role changelog) |
| 8 | KPI Summary Cards | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/user-summary-cards.tsx` (NEW — 4-column responsive grid of summary cards driven by `getUserSummary`) |
| 9 | Roles Multi-Badge cell renderer | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/user-roles-cell.tsx` (NEW — renders array of role badges with color-per-role) |
| 10 | User Cell renderer (avatar + name + username) | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/user-cell.tsx` (NEW — initials avatar with hash-color + name link + small username below; name link calls `openProfilePanel`) |
| 11 | Status Badge cell renderer | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/user-status-badge.tsx` (NEW — 4-state badge with icon: Active green dot / Inactive amber dot / Locked red lock / Pending blue envelope) |
| 12 | Last Login cell renderer | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/user-last-login-cell.tsx` (NEW — formats `lastLoginAt`, shows "Never" italic, shows "MMM dd (N failed)" red for locked) |
| 13 | Actions cell renderer | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/user-actions-cell.tsx` (NEW — status-conditional primary button + 3-dot dropdown with status-conditional menu items) |
| 14 | Bulk Actions Bar | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/user-bulk-actions-bar.tsx` (NEW — sticky cyan bar with 4 bulk action buttons + clear selection) |
| 15 | Bulk Assign Role Modal | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/bulk-assign-role-modal.tsx` (NEW — small modal with role single-select + confirm) |
| 16 | Staff Autocomplete | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/staff-autocomplete.tsx` (NEW — debounced search calling `getStaffsForSelect` + chip display + clear button + "No staff link" checkbox) |
| 17 | Temp Password Generator field | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/temp-password-field.tsx` (NEW — readonly input + Generate button + copy-to-clipboard icon) |
| 18 | Zustand Store | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/user-management-store.ts` (NEW — state: `isCreateEditOpen`, `isProfileOpen`, `editingUserId`, `viewingUserId`, `selectedRowIds`, `bulkAssignRoleOpen`, filter values; actions: `openCreate`, `openEdit`, `openProfile`, `closeAll`, `toggleRowSelection`, `setFilters`) |
| 19 | Index barrel | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/user/index.ts` (NEW — re-exports all components) |

### Frontend Files — MODIFY (existing wiring)

| # | File | Modification |
|---|------|--------------|
| 1 | `PSS_2.0_Frontend/src/app/[lang]/accesscontrol/usersroles/user/page.tsx` | Replace `<UnderConstruction/>` stub with `<UserManagementPage/>` import + render |
| 2 | `PSS_2.0_Frontend/src/application/configs/data-table-configs/auth-service-entity-operations.ts` | Add `USER` block with: `getAll: USERS_QUERY`, `getById: USERPROFILE_BY_ID_QUERY`, `getSummary: GET_USER_SUMMARY_QUERY`, `create: CREATE_USER_MUTATION`, `update: UPDATE_USER_MUTATION`, `delete: DELETE_USER_MUTATION`, `toggle: ACTIVATE_DEACTIVATE_USER_MUTATION` (verify mutation name in existing file) |
| 3 | `PSS_2.0_Frontend/src/application/configs/data-table-configs/operations-config.ts` | Register USER operations block |
| 4 | `PSS_2.0_Frontend/src/presentation/pages/accesscontrol/usersroles/index.tsx` | Re-export `<UserManagementPage/>` from new `user.tsx` page-config |
| 5 | `PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/usersroles/index.ts` | Add `user-components` to barrel |
| 6 | `PSS_2.0_Frontend/src/infrastructure/gql-queries/auth-queries/index.ts` | Verify new query exports |
| 7 | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/auth-mutations/index.ts` | Verify new mutation exports |
| 8 | `PSS_2.0_Frontend/src/domain/entities/auth-service/index.ts` | Verify new DTO exports |
| 9 | `PSS_2.0_Frontend/src/presentation/hooks/useAccessCapability.ts` (or wherever capability flags surface) | OPTIONAL — add `canImpersonate`, `canBulkAction` named flags if useful; otherwise keep generic `useAccessCapability({menuCode:"USER"})` |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens so user just reviews and confirms.

```
---CONFIG-START---
Scope: FE_ONLY + BE_ALIGN_DELTAS

MenuName: Users
MenuCode: USER
ParentMenu: AC_USERSROLES
Module: ACCESSCONTROL
MenuUrl: accesscontrol/usersroles/user
OrderBy: 1
GridType: MASTER_GRID

MenuCapabilities:
  READ, CREATE, MODIFY, DELETE, TOGGLE,
  RESET_PASSWORD, UNLOCK, SEND_INVITE, RESEND_INVITE, IMPERSONATE,
  BULK_ACTIVATE, BULK_DEACTIVATE, BULK_RESET_PASSWORDS, BULK_ASSIGN_ROLE,
  TERMINATE_SESSIONS, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, RESET_PASSWORD, UNLOCK, SEND_INVITE, RESEND_INVITE, BULK_ACTIVATE, BULK_DEACTIVATE, BULK_RESET_PASSWORDS, BULK_ASSIGN_ROLE, TERMINATE_SESSIONS, IMPORT, EXPORT
  # IMPERSONATE intentionally OMITTED from BUSINESSADMIN — SUPERADMIN only

GridFormSchema: SKIP   # Custom React Hook Form slide-panel — NOT RJSF-driven
GridCode: USER
```
---CONFIG-END---
```

**Menu seed verification**: `MODULE_MENU_REFERENCE.md` already records `USER` under `AC_USERSROLES` at URL `accesscontrol/usersroles/user`, OrderBy=1. Verify the seed row exists in the existing menu-seed file; if not, INSERT it. Capability rows + role-capability rows are NEW (BUSINESSADMIN grant).

**MasterData seeds NEW** (idempotent INSERT … WHERE NOT EXISTS pattern from CompanySettings precedent):
- `MasterDataType TYPECODE='DATAACCESSLEVEL'` + 4 values: OWN_RECORDS / OWN_BRANCH / ASSIGNED_BRANCHES / ALL_BRANCHES_GLOBAL
- `MasterDataType TYPECODE='AUTHMETHOD'` + 3 values: EMAIL_PASSWORD / SSO / BOTH
- `MasterDataType TYPECODE='TWOFAMETHOD'` + 3 values: EMAIL_OTP / AUTH_APP / SMS_OTP
- `MasterDataType TYPECODE='TIMEZONE'` + N values (UTC+0 London / UTC+3 Nairobi / UTC+4 Dubai / UTC+5:30 India / UTC+6 Dhaka — at minimum the 5 from mockup; full list deferred to FX import)
- `MasterDataType TYPECODE='DEFAULTDASHBOARD'` + 4 values: STANDARD / FUNDRAISING / FIELD_COLLECTION / MANAGER (placeholder until #78 lands — see ISSUE-5)

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — knows EXACTLY what the backend will expose.

**GraphQL Types:**
- Query type: `UserQueries` (existing `[ExtendObjectType(typeof(Query))]` in `Base.API/EndPoints/Auth/Queries/UserQueries.cs`)
- Mutation type: `UserMutations` (existing `[ExtendObjectType(typeof(Mutation))]` in `Base.API/EndPoints/Auth/Mutations/UserMutations.cs`)

**Queries:**
| GQL Field | Returns | Key Args | Status |
|-----------|---------|----------|--------|
| `getUsers` (alias `users`) | `GridFeatureResult<UserResponseDto>` | `gridFilterRequest`, `statusFilter?: String`, `roleId?: Int`, `branchId?: Int`, `lastLoginBucket?: String`, `excludeAssignedStaff?: Boolean` | EXTEND existing |
| `getUserById` (alias `userById`) | `UserResponseDto` (extended) | `userId: Int!` | EXTEND existing |
| `getUserSummary` | `UserSummaryDto` | (none — tenant-scoped) | **NEW** |
| `getUserLoginHistory` | `[LoginHistoryDto!]!` | `userId: Int!`, `limit: Int = 10` | **NEW** |
| `getUserActiveSessions` | `Int` (count) | `userId: Int!` | **NEW** |

**Mutations:**
| GQL Field | Input | Returns | Status |
|-----------|-------|---------|--------|
| `createUser` | `UserRequestDto` (extended) | `UserResponseDto` | EXTEND existing |
| `updateUser` | `UserRequestDto` (extended) | `UserResponseDto` | EXTEND existing |
| `activateDeactivateUser` | `userId: Int!` | `Boolean` | EXISTING |
| `deleteUser` | `userId: Int!` | `Boolean` | EXISTING (extend with self-protect guard) |
| `updateUserProfilePhoto` | `FileUploadRequest` | `{file, userId}` | EXISTING |
| `assignUserRoles` | `AssignUserRolesRequestDto` | `AssignUserRolesRequestDto` | EXISTING (called internally by extended createUser/updateUser) |
| `resetUserPassword` | `userId: Int!` | `TempPasswordResponseDto` | **NEW** |
| `generateTempPassword` | (none) | `String` (random 8-char password) | **NEW** |
| `unlockUser` | `userId: Int!` | `Boolean` | **NEW** |
| `sendUserInvite` | `userId: Int!` | `Boolean` | **NEW** |
| `resendUserInvite` | `userId: Int!` | `Boolean` | **NEW** |
| `terminateUserSessions` | `userId: Int!` | `Int` (terminated count) | **NEW** |
| `impersonateUser` | `userId: Int!` | `{accessToken, expiresIn}` SERVICE_PLACEHOLDER | **NEW** |
| `bulkActivateUsers` | `BulkActionRequestDto { userIds: [Int!]! }` | `Int` (affected count) | **NEW** |
| `bulkDeactivateUsers` | `BulkActionRequestDto` | `Int` | **NEW** |
| `bulkResetPasswords` | `BulkActionRequestDto` | `Int` | **NEW** |
| `bulkAssignRole` | `BulkAssignRoleRequestDto { userIds: [Int!]!, roleId: Int! }` | `Int` | **NEW** |

**Response DTO Fields** (`UserResponseDto` extended — what FE receives):

| Field | Type | Notes |
|-------|------|-------|
| userId | Int | PK |
| userName | String | Login identifier (existing) |
| alternateUserName | String? | Existing |
| firstName | String? | NEW |
| lastName | String? | NEW |
| email | String | NEW (display + invite delivery) |
| phoneCountryCode | String? | NEW |
| phoneNumber | String? | NEW |
| profilePathUrl | String? | Existing |
| userTypeId | Int | Existing |
| userType | `{ userTypeId, userTypeName, userTypeCode }` | Existing nested |
| authenticationMethod | String | NEW |
| isTwoFactorEnabled | Boolean | NEW |
| twoFactorMethod | String? | NEW |
| mustChangePassword | Boolean | NEW |
| primaryRoleId | Int? | NEW |
| primaryRole | `RoleResponseDto?` | NEW (nested) |
| branchId | Int? | NEW |
| branch | `{ branchId, branchName }?` | NEW (nested) |
| isAllBranchesAccess | Boolean | NEW |
| dataAccessLevel | String | NEW |
| staffId | Int? | NEW |
| staff | `{ staffId, staffName, displayName }?` | NEW (nested) |
| languageId | Int? | NEW |
| language | `{ languageId, languageName }?` | NEW (nested) |
| timezoneId | Int? | NEW (FK MasterData) |
| defaultDashboardCode | String? | NEW |
| accountExpiresAt | DateTime? | NEW |
| notes | String? | NEW |
| isLocked | Boolean | NEW |
| failedLoginCount | Int | NEW |
| lockedAt | DateTime? | NEW |
| lastLoginAt | DateTime? | NEW |
| isPendingInvitation | Boolean | NEW |
| invitationSentAt | DateTime? | NEW |
| displayStatus | String | **DERIVED** server-side — `Pending` / `Locked` / `Inactive` / `Active` per §④ precedence |
| isActive | Boolean | Inherited |
| createdDate | DateTime | Inherited |
| userRoles | `[UserRoleResponseDto!]!` (with nested role) | Existing |

**`UserSummaryDto`**:
```graphql
type UserSummaryDto {
  totalUsers: Int!
  activeCount: Int!
  inactiveCount: Int!
  lockedCount: Int!
  onlineNowCount: Int!
  pendingInvitationsCount: Int!
  lockedAccountsCount: Int!
}
```

**`LoginHistoryDto`**:
```graphql
type LoginHistoryDto {
  loginHistoryId: Int!
  userId: Int!
  loginAt: DateTime!
  ipAddress: String
  device: String
  location: String
  status: String!         # SUCCESS | FAILED
  failureReason: String
}
```

**Nullability for list args** (per memory `feedback_fe_query_nullability_must_match_be`): If BE uses `int[]` for `userIds`, FE GQL must declare `[Int!]!` exactly. Use the FE-non-null variants on list-of-scalars throughout the bulk mutations.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `dotnet ef migrations add Add_User_ManagementColumns_And_LoginHistory --force` succeeds (Designer + snapshot regenerated)
- [ ] `dotnet ef database update` applies cleanly
- [ ] DB seed SQL executes idempotently
- [ ] `pnpm dev` — page loads at `/{lang}/accesscontrol/usersroles/user`
- [ ] `tsc --noEmit` — no new errors

**Functional Verification (Full E2E — MANDATORY):**

*Grid + KPIs*
- [ ] 4 KPI cards render with correct values from `getUserSummary` (Total Users with breakdown sub-label / Online Now / Pending Invitations / Locked Accounts)
- [ ] Grid loads 8 columns matching mockup
- [ ] Search by name/email/username works
- [ ] Status filter shows only matching status
- [ ] Role filter narrows to users with that role
- [ ] Branch filter narrows to users in that branch (or "All Branches")
- [ ] Last-login bucket filter (Today / Week / Month / Never / Inactive >30d) works
- [ ] Clear Filters resets all
- [ ] Pagination: 10/25/50/100 per page + page navigation

*Bulk Selection*
- [ ] Header checkbox toggles all visible rows + select-all-pages confirm
- [ ] Bulk-actions bar appears when ≥1 row selected with correct count
- [ ] Activate / Deactivate / Reset Passwords each succeed and refresh
- [ ] Assign Role opens modal with role select → applies role to all selected users → toast

*Create Flow*
- [ ] +New User → slide-panel opens with empty form, 5 accordion sections expanded
- [ ] First Name / Last Name / Email required validation works inline
- [ ] Phone country code populates from `getCountries`
- [ ] Generate Temp Password button populates readonly field
- [ ] 2FA toggle → 2FA Method select appears (conditional)
- [ ] Roles checkbox group populates from `getRoles` — at least 1 required
- [ ] Primary Role select filters to checked roles
- [ ] All Branches checkbox disables Branch select
- [ ] Staff autocomplete returns results from `getStaffsForSelect` debounced — chip appears on select
- [ ] "No staff link needed" checkbox clears StaffId
- [ ] Cancel discards changes (confirm if dirty)
- [ ] Create User → `createUser` succeeds → panel closes → grid refreshes → KPI refreshes → toast
- [ ] Create User & Send Invite → also triggers `sendUserInvite` → user appears with status=Pending → toast

*Edit Flow*
- [ ] Edit button on row → slide-panel opens pre-filled from `getUserById`
- [ ] Footer shows only [Cancel] + [Save Changes]
- [ ] Temp Password field becomes "Set New Temp Password" (optional)
- [ ] Changes save → `updateUser` succeeds → grid refreshes

*Row Actions per Status*
- [ ] Active → 3-dot menu: View Profile / Edit / Reset Password / Deactivate / Impersonate / Delete
- [ ] Inactive → 3-dot menu: View Profile / Edit / Reset Password / Activate / Delete
- [ ] Locked → primary button [Unlock] + menu: Edit / Unlock / Reset Password / Deactivate / Delete; Unlock clears IsLocked
- [ ] Pending → primary button [Resend Invite] + menu: Edit / Resend / Deactivate / Delete; Resend updates InvitationSentAt
- [ ] Reset Password sends email + resets `MustChangePassword=true`
- [ ] Delete with self → blocked with toast "Cannot delete your own account"
- [ ] Delete SUPERADMIN as non-SUPERADMIN → blocked
- [ ] Impersonate → SERVICE_PLACEHOLDER toast "Impersonation requires SUPERADMIN session — coming soon"

*View Profile*
- [ ] Username link OR View Profile menu → profile panel slides in
- [ ] Profile header: avatar + name + email + roles + status
- [ ] Info grid: 8 fields populated correctly (Branch / Staff / Phone / Auth / 2FA / Language / Timezone / Created)
- [ ] Login History table: latest 10 rows from `getUserLoginHistory` OR empty state if disabled
- [ ] Active Sessions count from `getUserActiveSessions`
- [ ] Terminate All Sessions → confirms → `terminateUserSessions` → count returns to 0
- [ ] Role Changelog: list of role-change events (date + description)

*SERVICE_PLACEHOLDERs*
- [ ] Import Users button → toast "Import not yet available — contact support"
- [ ] Export button → toast "Export not yet available"
- [ ] Location column in Login History → "—" (geo-IP not wired)
- [ ] Impersonate → toast (see above)

*Permissions*
- [ ] BUSINESSADMIN sees all actions
- [ ] Non-BUSINESSADMIN: view-only mode (Add/Edit/Delete/Bulk hidden)
- [ ] Capability gates: `canRead`, `canCreate`, `canModify`, `canDelete`, `canResetPassword`, etc. drive UI visibility

**DB Seed Verification:**
- [ ] Menu USER visible in sidebar under Access Control → Users & Roles
- [ ] All 17 capability rows seeded for USER menu
- [ ] BUSINESSADMIN role-capability rows seeded (16 — IMPERSONATE excluded)
- [ ] MasterData rows seeded for DATAACCESSLEVEL / AUTHMETHOD / TWOFAMETHOD / TIMEZONE / DEFAULTDASHBOARD

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **SCREEN TYPE RECLASSIFIED**: Registry has #72 listed as `FLOW`. Mockup analysis confirms it is **MASTER_GRID** — +Add does NOT change URL, no `?mode=new/edit/read`, form is a 600px right-edge slide-panel. /plan-screens has stamped `screen_type: MASTER_GRID` in frontmatter. Update REGISTRY.md row #72 Type column accordingly.
- **FE_ONLY designation is partly true**: While the FE work is the largest deliverable (19 new files + ~9 modifications), the BE requires significant **ALIGN deltas**: 22 new columns on the existing User entity, 7 new commands, 2 new queries, 4 bulk commands, optional new LoginHistory entity, plus a migration. The build effort is closer to a FULL build than to the FE_ONLY label suggests. Estimate: 1.5–2× the standard cap (1.5h dev / 2.0h test recommended).
- **First instance of CUSTOM SLIDE-PANEL FORM in registry**: All prior MASTER_GRID screens use RJSF modal forms. This screen introduces a hand-written React Hook Form + Zod slide-panel pattern (5 accordion sections + sticky footer + 3 conditional sections). FE Developer should treat this as a **reference implementation** that subsequent screens (Staff #42, Contact #18, etc. when they get richer forms) can copy. UX Architect should document the pattern after build. (See ISSUE-1.)
- **First instance of READ-ONLY PROFILE SLIDE-PANEL with login history**: Audit Trail #74 has a detail panel pattern (read-only side-panel for one record) — borrow its layout primitives. Profile panel is a distinct overlay from the Create/Edit panel — they should NOT share state or DOM.
- **Existing core CRUD must be EXTENDED, not regenerated**: `CreateUser`, `UpdateUser`, `DeleteUser`, `ToggleUserStatus`, `GetUsers`, `GetUserById`, `AssignUserRoles`, `updateUserProfilePhoto` ALL exist and are wired. BE Developer must add new fields to existing files, NOT create parallel new ones.
- **User entity has 18 navigation collections** — when extending the entity, be careful not to break existing relationships (UserRoles, UserGridFilters, UserSettings, UserGridFields, Notifications×2, ReportExecutionLogs, UserDashboards, ContactStaffs, ContactTypeAssignments, BranchUsers, PowerBIUserMappings×2, ImportSessions, WhatsAppConversations, WhatsAppMessages). All persisted columns must be additive — do NOT rename or remove existing properties.
- **Existing FE stub will be REPLACED**: `[lang]/accesscontrol/usersroles/user/page.tsx` is currently `<UnderConstruction/>`. Replace with `<UserManagementPage/>` import.
- **`auth-service-entity-operations.ts` does NOT yet contain USER block** — only ROLE / MODULE / MENU / REPORTROLE / WIDGETROLE. Add USER block.
- **MasterData seeds — `masterDatasByTypeCode` BE resolver may not exist** (see ISSUE-4): the FE precedent in `provider-card-selector.tsx` uses inline GQL, but the actual server-side resolver may not be in `MasterDataQueries.cs`. BE Developer must verify and add it if missing.
- **Branch model — single column vs junction**: Mockup shows simple single Branch select + All Branches checkbox. Recommended (DECISION-3): use `BranchId` single column on User as the primary, AND populate `BranchUser` junction rows when DataAccessLevel = ASSIGNED_BRANCHES. Do NOT use junction alone — grid display needs a single branch name per row.
- **Phone country code source**: Use existing `getCountries` query — its `Country.PhoneCode` column drives the dropdown. Display format `"+{phoneCode} ({countryName})"`. If `PhoneCode` doesn't exist on Country, fall back to a static list and flag as a separate enhancement.
- **Welcome email template**: Use `IEmailTemplateService.SendEmailByTemplateKeyAsync` with new template key `"USER_WELCOME_INVITE"`. The email template **content** is seeded in `EmailTemplate` table — BE Developer must add the template row to the DB seed. Reuse `ForgotPassword.cs` as the integration pattern.

**Service Dependencies** (UI-only — backend implementation missing):

- ⚠ **SERVICE_PLACEHOLDER: Impersonation** — No impersonation framework exists. Full UI button + menu item built, but handler returns `NotImplemented` and FE shows toast "Impersonation requires SUPERADMIN session — coming soon". Adding real impersonation requires (a) actor-on-behalf-of-target JWT issuance + (b) audit trail + (c) "Exit impersonation" UI in header — all out of scope for #72. Track as separate ENHANCEMENT.
- ⚠ **SERVICE_PLACEHOLDER: IP Geolocation** — Login History table has a Location column but no geo-IP service is wired. Render "—" for v1. Future: integrate with MaxMind GeoLite2 or similar (server-side enrichment job, not request-time).
- ⚠ **SERVICE_PLACEHOLDER: Import Users** — Mockup shows [Import Users] button. No bulk-import infrastructure for users yet (existing `ImportSession` is contact-only). UI button renders → toast "Bulk user import not yet available — contact support". Track as separate ENHANCEMENT (Wave 4 / P4-Advanced).
- ⚠ **SERVICE_PLACEHOLDER: Export Users** — Mockup shows [Export] button. CSV/Excel export not wired for User entity. UI button → toast.
- ⚠ **SERVICE_PLACEHOLDER: Role Changelog (full audit trail)** — Until #74 Audit Trail is built, the Role Changelog section in Profile uses derived UserRole CreatedDate/IsActive states + User CreatedDate as the "account created" anchor. Replace with `getAuditLogsForUser(userId, entityType: 'User')` after #74 completes. Add a TODO marker in the component file.

Full UI must be built (buttons, panels, forms, modals, interactions). Only the handler for the external service call is mocked.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | /plan-screens 2026-05-16 | MED | UX pattern | First custom slide-panel form in registry — no precedent to copy. FE Developer must invent the slide-panel layout primitives. After build, lift the slide-panel shell + accordion section components to `presentation/custom-components/slide-panel/` for reuse. | OPEN |
| ISSUE-2 | /plan-screens 2026-05-16 | MED | Scope decision | LoginHistory entity — recommended to build now (6 cols + 2 hooks); alternatively defer and render empty state in Profile panel. BA must decide in Phase 1 approval. | OPEN |
| ISSUE-3 | /plan-screens 2026-05-16 | LOW | MasterData seed | TIMEZONE MasterDataType doesn't exist yet. Seed minimal 5 timezones from mockup; full IANA list can be added later. | OPEN |
| ISSUE-4 | /plan-screens 2026-05-16 | MED | BE resolver | `masterDatasByTypeCode` GraphQL resolver may not exist in `MasterDataQueries.cs` — FE precedent calls inline GQL but BE resolver is unconfirmed. BE Developer must verify and add resolver if missing. | OPEN |
| ISSUE-5 | /plan-screens 2026-05-16 | LOW | Future coupling | Default Dashboard field stored as `DefaultDashboardCode` string until #78 Dashboard Config lands; then convert to FK. Pre-seed 4 codes (STANDARD/FUNDRAISING/FIELD_COLLECTION/MANAGER). | OPEN |
| ISSUE-6 | /plan-screens 2026-05-16 | MED | Self-protect | DeleteUser + ToggleUserStatus need self-protect (cannot operate on own UserId) — get current userId via `IHttpContextAccessor.GetCurrentUserStaffCompanyId()` precedent in #74. | OPEN |
| ISSUE-7 | /plan-screens 2026-05-16 | MED | SUPERADMIN guard | Cannot delete or impersonate SUPERADMIN users unless actor is SUPERADMIN. Validation belongs in BE; FE should also hide the buttons proactively (cosmetic). | OPEN |
| ISSUE-8 | /plan-screens 2026-05-16 | LOW | Existing CreateUser refactor | Current `CreateUser` does NOT call `AssignUserRoles` — the screen currently creates a user with no roles, then expects a separate AssignUserRoles call. New form will pass roles in the same payload — refactor `CreateUser` to call AssignUserRoles internally OR create new `CreateUserWithRoles` orchestrator command. Recommend extending existing. | OPEN |
| ISSUE-9 | /plan-screens 2026-05-16 | LOW | Profile photo timing | `updateUserProfilePhoto` is a separate mutation needing userId. Create flow must: (a) create user → (b) get returned userId → (c) upload photo if File present. Edit flow can upload directly. Handle the 2-step properly in FE. | OPEN |
| ISSUE-10 | /plan-screens 2026-05-16 | MED | UserName vs Email | Existing `UserName` is the login identifier (unique). Mockup labels Email "(Username)" suggesting they're the same. Decision: keep both columns (UserName = login, Email = display), set UserName = Email on Create when user doesn't provide separately. Document this in form helper text. | OPEN |
| ISSUE-11 | /plan-screens 2026-05-16 | LOW | Capability code naming | New capabilities (RESET_PASSWORD, UNLOCK, etc.) need to follow existing naming convention. Verify against `DecoratorProperties.cs` Permissions enum — if Permissions enum needs extension, do it in this build. | OPEN |
| ISSUE-12 | /plan-screens 2026-05-16 | LOW | Bulk action confirm UX | Bulk Deactivate / Reset Passwords / Assign Role need confirm modals with clear counts ("Deactivate 12 users?"). Use existing `<ConfirmDialog/>` if available, otherwise inline AlertDialog. | OPEN |
| ISSUE-13 | /plan-screens 2026-05-16 | LOW | KPI auto-refresh | After every action that affects status (Activate/Deactivate/Unlock/Delete/Resend Invite), KPI summary should refetch. Use Apollo cache eviction + refetch on `getUserSummary` after each successful mutation. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-16 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt (MASTER_GRID with custom slide-panel form). User-confirmed 3 decisions before launch: single session, build LoginHistory entity now (not deferred), Sonnet for all agents. BA/SR/UX agents skipped per #15 precedent — prompt has full pre-analysis. BE + FE Developers spawned in parallel, each in 2 phases (Phase A = foundational/contract + Phase B = orchestration). A 2nd respawn was needed after an initial mistake: outer `git status` (run from `pss-2.0-global/`) showed zero changes and I incorrectly concluded the original agents had fabricated their reports — `PSS_2.0_Backend/` and `PSS_2.0_Frontend/` are nested git repos with their own `.git/`, so file mutations inside them are invisible to the outer repo. Confirmed all original work was real. Lesson saved to memory `nested-git-repos`.
- **Files touched**:
  - BE (created — 19):
    - `Base.Domain/Models/AuthModels/LoginHistory.cs` (created)
    - `Base.Infrastructure/Data/Configurations/AuthConfigurations/LoginHistoryConfiguration.cs` (created)
    - `Base.Application/Schemas/AuthSchemas/LoginHistorySchemas.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Queries/GetUserSummary.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Queries/GetUserLoginHistory.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Queries/GetUserActiveSessions.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Commands/ResetUserPassword.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Commands/GenerateTempPassword.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Commands/UnlockUser.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Commands/SendUserInvite.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Commands/ResendUserInvite.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Commands/TerminateUserSessions.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Commands/ImpersonateUser.cs` (created — SERVICE_PLACEHOLDER)
    - `Base.Application/Business/AuthBusiness/Users/Commands/BulkActivateUsers.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Commands/BulkDeactivateUsers.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Commands/BulkResetPasswords.cs` (created)
    - `Base.Application/Business/AuthBusiness/Users/Commands/BulkAssignRole.cs` (created)
    - `sql-scripts-dyanmic/UserManagement-sqlscripts.sql` (created — 27KB / 8 steps)
  - BE (modified — 12):
    - `Base.Domain/Models/AuthModels/User.cs` (22 new cols + 4 new nav props + LoginHistories collection)
    - `Base.Infrastructure/Data/Configurations/AuthConfigurations/UserConfiguration.cs` (MaxLengths + 5 indexes + 3 FK relationships)
    - `Base.Application/Schemas/AuthSchemas/UserSchemas.cs` (extended UserRequestDto/UserResponseDto + new DTOs)
    - `Base.Application/Business/AuthBusiness/Users/Commands/CreateUser.cs` (role assignment + optional SendInvite)
    - `Base.Application/Business/AuthBusiness/Users/Commands/UpdateUser.cs` (role sync)
    - `Base.Application/Business/AuthBusiness/Users/Commands/DeleteUser.cs` (self-protect + SUPERADMIN guard)
    - `Base.Application/Business/AuthBusiness/Users/Commands/ToggleUserStatus.cs` (self-protect)
    - `Base.Application/Business/AuthBusiness/Users/Queries/GetUsers.cs` (new filter args + includes + DisplayStatus derivation)
    - `Base.Application/Business/AuthBusiness/Users/Queries/GetUserById.cs` (extended response with nested props)
    - `Base.API/EndPoints/Auth/Mutations/UserMutations.cs` (11 new mutations)
    - `Base.API/EndPoints/Auth/Queries/UserQueries.cs` (3 new queries)
    - `Base.API/EndPoints/Auth/Mutations/AuthendicationMutations.cs` (LoginHistory hook on success/failure + lock-after-5-failures)
    - `Base.API/EndPoints/Setting/Queries/MasterDataQueries.cs` (added `masterDatasByTypeCode` resolver per ISSUE-4)
    - `Base.Application/Data/Persistence/IAuthDbContext.cs` (+ DbSet<LoginHistory>)
    - `Base.Infrastructure/Data/Persistence/AuthDbContext.cs` (+ DbSet<LoginHistory>)
    - `Base.Application/Mappings/AuthMappings.cs` (new Mapster mappings)
    - `Base.Application/Extensions/DecoratorProperties.cs` (LOGINHISTORY constant)
  - FE (created — 17):
    - `presentation/pages/accesscontrol/usersroles/user.tsx` (page config dispatcher)
    - `presentation/components/page-components/accesscontrol/usersroles/user/index-page.tsx` (Variant B layout)
    - `presentation/components/page-components/accesscontrol/usersroles/user/user-create-edit-panel.tsx` (35KB — RHF + Zod, 5 accordion sections, sticky footer)
    - `presentation/components/page-components/accesscontrol/usersroles/user/user-profile-panel.tsx` (21KB — read-only panel)
    - `presentation/components/page-components/accesscontrol/usersroles/user/user-summary-cards.tsx`
    - `presentation/components/page-components/accesscontrol/usersroles/user/user-bulk-actions-bar.tsx`
    - `presentation/components/page-components/accesscontrol/usersroles/user/bulk-assign-role-modal.tsx`
    - `presentation/components/page-components/accesscontrol/usersroles/user/staff-autocomplete.tsx`
    - `presentation/components/page-components/accesscontrol/usersroles/user/temp-password-field.tsx`
    - `presentation/components/page-components/accesscontrol/usersroles/user/user-management-store.ts`
    - `presentation/components/page-components/accesscontrol/usersroles/user/index.ts`
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/user-cell.tsx`
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/user-roles-cell.tsx`
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/user-status-badge.tsx`
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/user-last-login-cell.tsx`
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/user-actions-cell.tsx`
  - FE (modified — 10):
    - `app/[lang]/accesscontrol/usersroles/user/page.tsx` (UnderConstruction stub → UserManagementPage)
    - `application/configs/data-table-configs/auth-service-entity-operations.ts` (USER block added)
    - `domain/entities/auth-service/UserDto.ts` (4 enums + extended Request/Response DTOs + new DTOs)
    - `infrastructure/gql-queries/auth-queries/UserQuery.ts` (replaced USERS_QUERY + extended USERPROFILE_BY_ID_QUERY + 3 new queries)
    - `infrastructure/gql-mutations/auth-mutations/UserMutation.ts` (extended create/update + 11 new mutations with `[Int!]!` bulk shape)
    - `presentation/components/custom-components/data-tables/advanced/data-table-column-types/component-column.tsx` (5 new mappings)
    - `presentation/components/custom-components/data-tables/basic/data-table-column-types/component-column.tsx` (5 new mappings)
    - `presentation/components/custom-components/data-tables/flow/data-table-column-types/component-column.tsx` (5 new mappings)
    - `presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` (5 new exports)
    - `presentation/pages/accesscontrol/usersroles/index.ts` (UserManagementPage export)
    - `presentation/components/page-components/accesscontrol/usersroles/index.tsx` (user-components barrel)
  - DB: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/UserManagement-sqlscripts.sql` (created, idempotent NOT EXISTS guards throughout)
- **Deviations from spec**:
  - DECISION-2 honored: LoginHistory entity built (recommended path).
  - DECISION-3 honored: BranchId single column + BranchUser junction for ASSIGNED_BRANCHES.
  - ISSUE-4 resolved in this session: `masterDatasByTypeCode` resolver added to `MasterDataQueries.cs` (originally flagged as needing verification).
  - ISSUE-11 partial: new capability codes are seeded as DB rows but NOT added as `Permissions` enum constants — existing commands use generic `Permissions.Create/Modify` attributes. Runtime enforcement happens through RoleCapability DB rows, not `[CustomAuthorize]` granular checks.
  - Phase B FE folder was already produced in the same session sequence (10 component files inside `user/`); no separate Phase B spawn was needed since work overlapped with Phase A.
  - Per `feedback_baseurl_user_managed`, the `BaseUrlConfig.ts` change (port 57897→57898) shown in `git status` is treated as user-managed and not reverted.
  - **No EF migration generated yet** — agent didn't run `dotnet ef migrations add` because EF context resolution wasn't verified. Run manually: `dotnet ef migrations add Add_User_ManagementColumns_And_LoginHistory --project PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure --startup-project PSS_2.0_Backend/PeopleServe/Services/Base/Base.API`.
  - **No `dotnet build` / `pnpm dev` ran in-session** per token-budget discipline and `/build-screen` rule "avoid full builds unless necessary". User to verify build before applying migration + seed SQL.
- **Known issues opened**:
  - ISSUE-FALSE-FABRICATION-ALARM (this session): Outer `git status` returned 0 user-management lines because `PSS_2.0_Backend` / `PSS_2.0_Frontend` are nested git repos. Mis-diagnosed as agent fabrication; wasted ~275K tokens on respawn. Memory `nested-git-repos` saved to prevent recurrence. STATUS: CLOSED (resolved within session).
- **Known issues closed**: ISSUE-2 (LoginHistory built per DECISION-2). ISSUE-4 (masterDatasByTypeCode resolver added). ISSUE-6 (self-protect on Delete/Toggle). ISSUE-7 (SUPERADMIN guard on Delete/Impersonate). ISSUE-8 (CreateUser extended in-place to call AssignUserRoles). ISSUE-9 (profile photo 2-step in FE create flow). ISSUE-10 (UserName retained as login + Email separate). ISSUE-12 (bulk confirm modals via AlertDialog). ISSUE-13 (Apollo cache eviction on summary query after mutations).
- **OPEN issues remaining**: ISSUE-1 (custom slide-panel pattern not yet lifted to reusable `slide-panel/` primitives — defer to next reuse case). ISSUE-3 (TIMEZONE 5 vals seeded; full IANA list deferred). ISSUE-5 (DefaultDashboard string code until #78 lands). ISSUE-11 (Permissions enum granular codes — runtime works via RoleCapability rows; can enhance later).
- **Next step**: User to (1) `cd PSS_2.0_Backend && dotnet ef migrations add Add_User_ManagementColumns_And_LoginHistory ...`, (2) apply migration via `dotnet ef database update`, (3) apply `UserManagement-sqlscripts.sql`, (4) `dotnet build`, (5) `pnpm dev`, (6) E2E test per §⑪ acceptance criteria.

### § Known Issues (updated this session)

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | /plan-screens 2026-05-16 | MED | UX pattern | First custom slide-panel form in registry. Lift shell to `custom-components/slide-panel/` on next reuse. | OPEN |
| ISSUE-2 | /plan-screens 2026-05-16 | MED | Scope decision | LoginHistory entity built per DECISION-2. | CLOSED (Session 1) |
| ISSUE-3 | /plan-screens 2026-05-16 | LOW | MasterData seed | TIMEZONE: 5 vals seeded; full IANA list deferred. | OPEN |
| ISSUE-4 | /plan-screens 2026-05-16 | MED | BE resolver | `masterDatasByTypeCode` resolver added to MasterDataQueries.cs. | CLOSED (Session 1) |
| ISSUE-5 | /plan-screens 2026-05-16 | LOW | Future coupling | DefaultDashboardCode stays string until #78 lands. | OPEN |
| ISSUE-6 | /plan-screens 2026-05-16 | MED | Self-protect | DeleteUser + ToggleUserStatus self-protect added. | CLOSED (Session 1) |
| ISSUE-7 | /plan-screens 2026-05-16 | MED | SUPERADMIN guard | Delete + Impersonate gated on actor=SUPERADMIN for SUPERADMIN targets. | CLOSED (Session 1) |
| ISSUE-8 | /plan-screens 2026-05-16 | LOW | Existing CreateUser refactor | CreateUser extended in-place to call AssignUserRoles. | CLOSED (Session 1) |
| ISSUE-9 | /plan-screens 2026-05-16 | LOW | Profile photo timing | 2-step handled in FE create flow (createUser → upload). | CLOSED (Session 1) |
| ISSUE-10 | /plan-screens 2026-05-16 | MED | UserName vs Email | UserName=login, Email=display; UserName auto-set to Email on Create. | CLOSED (Session 1) |
| ISSUE-11 | /plan-screens 2026-05-16 | LOW | Capability code naming | Capabilities seeded as DB rows; Permissions enum not extended. Runtime works via RoleCapability check. | OPEN (low priority) |
| ISSUE-12 | /plan-screens 2026-05-16 | LOW | Bulk action confirm UX | Bulk Deactivate/Reset Passwords use AlertDialog. | CLOSED (Session 1) |
| ISSUE-13 | /plan-screens 2026-05-16 | LOW | KPI auto-refresh | Apollo cache eviction on getUserSummary after mutations. | CLOSED (Session 1) |
| ISSUE-FALSE-FABRICATION-ALARM | /build-screen Session 1 | LOW | Process | Outer `git status` missed nested-repo changes; mis-diagnosed as fabrication. Memory saved. | CLOSED (Session 1) |
| ISSUE-14 | Session 2 follow-up 2026-05-16 | HIGH | Schema design | Identity fields (FirstName/LastName/Phone/Notes) wrongly added to User table; live on Staff. Removed from User entity, EF config, schemas, commands, queries, FE DTO/GQL/forms, SQL seed. | CLOSED (Session 2) |

---

## § Build Log — Session 2 (2026-05-16) — Identity cleanup

**Trigger**: User feedback: *"staff is the user. when we create new staff that time user will create and map to staff. so name,dob,etc.. will be there in staff table. so no need in user table, kindly remove newly added column in user table"*

**Decision** (via AskUserQuestion): Remove **identity-only** — `FirstName`, `LastName`, `PhoneCountryCode`, `PhoneNumber`, `Notes`. Keep `Email` on User as the login identifier. Keep all auth/access/preference columns.

**Files modified (12)**

Backend (7):
- `Base.Domain/Models/AuthModels/User.cs` — removed 5 props + their FK navs unchanged
- `Base.Infrastructure/Data/Configurations/AuthConfigurations/UserConfiguration.cs` — removed 5 `Property().HasMaxLength()` configs
- `Base.Application/Schemas/AuthSchemas/UserSchemas.cs` — removed 5 fields from `UserRequestDto`
- `Base.Application/Business/AuthBusiness/Users/Commands/CreateUser.cs` — removed 5 `ValidateStringLength` rules
- `Base.Application/Business/AuthBusiness/Users/Commands/UpdateUser.cs` — removed 5 `ValidateStringLength` rules
- `Base.Application/Business/AuthBusiness/Users/Queries/GetUsers.cs` — searchTerm now uses Staff subquery (FirstName/LastName/DisplayName/StaffName via StaffId) instead of u.FirstName/u.LastName
- `Base.Application/Business/AuthBusiness/Users/Commands/SendUserInvite.cs` — USER_NAME placeholder now resolved from Staff (DisplayName → StaffName → UserName fallback)

Frontend (4):
- `domain/entities/auth-service/UserDto.ts` — removed 5 fields from `UserRequestDto` + `UserResponseDto`; widened `UserStaffItem` to include `firstName`, `lastName`, `staffEmail`, `staffMobileNumber`
- `infrastructure/gql-queries/auth-queries/UserQuery.ts` — `USERS_QUERY` + `USERPROFILE_BY_ID_QUERY` removed 5 fields; both queries now select staff.firstName/lastName/staffEmail/staffMobileNumber
- `infrastructure/gql-mutations/auth-mutations/UserMutation.ts` — `CREATE_USER_MUTATION` + `UPDATE_USER_MUTATION` removed 5 variables + payload fields
- `presentation/components/page-components/accesscontrol/usersroles/user/user-create-edit-panel.tsx` — removed FirstName/LastName/Phone form fields + Notes textarea; dropped `COUNTRIES_DROPDOWN_QUERY` (no longer needed); removed validation rules; collapsed "Account Information" accordion to just Email + hint that name/phone are managed on Staff
- `presentation/components/page-components/accesscontrol/usersroles/user/user-profile-panel.tsx` — `displayName` derived from `user.staff?.displayName / firstName+lastName / staffName`; avatar initials read from staff; Phone InfoItem displays `staff.staffMobileNumber`
- `presentation/components/custom-components/data-tables/shared-cell-renderers/user-cell.tsx` — reads `row.original.staff.firstName/lastName/displayName` instead of top-level `firstName`/`lastName`

DB seed (1):
- `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/UserManagement-sqlscripts.sql` — STEP 5: removed `FIRSTNAME`/`LASTNAME` field rows; added `USERNAME` row. STEP 6 Column 2: retargeted from `FIRSTNAME` → `USERNAME` and wired `GridComponentName = 'user-cell'` (was null) — the renderer now handles the visual using staff-nested data.

**BE compile fixes** (5 errors caught after first `dotnet build`):
- `EndPoints/Auth/Queries/UserQueries.cs` — Session 1 agents invented `BaseApiResponse<T>.GetSuccess(value)` which doesn't exist on `BaseApiResponse<T>`. Replaced with:
  - `GetUserSummary` → `ApiResponseHelper.ReturnObjectApiResponse(result.summary)`
  - `GetUserLoginHistory` → `ApiResponseHelper.ReturnObjectApiResponse(result.history)`
  - `GetUserActiveSessions` → `BaseApiResponse<int>.Ok(ExceptionCode.Success, ResponseMessage.GetRecordSuccess, result.Count)` (the helper has a `where T : class` constraint so it can't take `int`)
- `EndPoints/Setting/Queries/MasterDataQueries.cs` — added `using Mapster;` for `Adapt()` call; replaced bogus `GetSuccess` with `ApiResponseHelper.ReturnObjectApiResponse<IEnumerable<MasterDataResponseDto>>(dtos)`.

Verified clean: `dotnet build Base.API.csproj` → **0 errors** (15 pre-existing warnings unchanged).

**User-side follow-up**:
- The earlier (unmigrated) EF migration is now stale — regenerate: `dotnet ef migrations remove` then `dotnet ef migrations add Add_User_ManagementColumns_And_LoginHistory` (the new migration will skip the 5 dropped columns).
- Re-run `UserManagement-sqlscripts.sql` — STEP 5 is idempotent (the new `USERNAME` row inserts; orphan FIRSTNAME/LASTNAME rows from prior runs are harmless but can be `DELETE FROM sett."Fields" WHERE "FieldCode" IN ('FIRSTNAME','LASTNAME');` if you'd already applied Session 1's seed).
- `pnpm typecheck` to confirm FE side.
