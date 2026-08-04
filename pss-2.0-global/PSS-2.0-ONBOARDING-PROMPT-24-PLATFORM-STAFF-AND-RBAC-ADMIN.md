# PROMPT-24 — Platform Staff & Plan-Based RBAC Administration

**Status:** NOT BUILT.
**Surface:** BE (7 new queries · 9 new commands · 1 new column on `auth.Roles` · 1 new `billing` table · 3 new `ops` tables · 1 new service · 5 existing-handler fixes · **`ProvisionTenant` Step 4 rewrite**) · FE (1 new screen, 4 tabs, under `(master)/platform/staff`) · **migration required** (see `PSS-2.0-ONBOARDING-PROMPT-24-MIGRATION-SPEC.md`) · **seed SQL required** (2 files).
**Depends on:** P-19 Phase 2 (platform host gate + `ops-platform-rbac-seed.sql`), P-02 (`IEntitlementService`), P-17 (`IPlanMenuFilter` / `IMenuFeatureMap` / `billing.FeatureMenuMaps`), screen #70 (role-capability matrix), `ProvisionTenant` Steps 3/4.
**Trigger:** *"ok next i need a new screen for platform staff management screen … then each role capability matrix also need for this super admin … but currently we creating BUSINESSADMIN role for each tenant so if we create 20 tenant means 20 BUSINESSADMIN will create and that 20 business admin role based menus capability we need to handle right?"*
**Revised 2026-08-04 (v2):** *"we need to configure based on plan feature menus — that menus access only we need to give this new tenant business admin role."* The single `__TEMPLATE__` capability matrix is replaced by a **per-plan BUSINESSADMIN baseline**. See §① and D6.

---

## ⚠️ Rules

1. **Migrations are user-owned.** Do not run `dotnet ef migrations add` / `database update` / `remove`. Do not hand-author a migration file or a snapshot. Build to prove it compiles, then hand over the migration spec.
2. **Do not run `dotnet build`.** The user builds the backend.
3. `ops` is platform-global. Every read needs `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true` guard. Every `auth` / `billing` read that crosses tenants needs the same.
4. **Configuration is per PLAN, never per tenant.** The number of matrices a human maintains equals the number of plans. Any design that requires opening a tenant to configure it — other than break-glass — is wrong.
5. **A tenant's live RBAC belongs to the tenant.** The platform edits *baselines*; it pushes to live tenants *additively*; it *never* silently revokes. Any write into a live tenant's matrix is audited against that tenant.
6. **Platform staff or tenant staff, never both** (P-19 §12.8). A user holding both a `CompanyId IS NULL` role and a `CompanyId IS NOT NULL` role is rejected by the host gate on *every* host — i.e. locked out entirely. Enforce at save, on both sides.
7. **`SUPERADMIN` is immutable.** Never revoke, never overwrite, never include as a push target. Existing `SUPERADMIN_IMMUTABLE` guards stay exactly as they are.
8. **Never write a password hash by hand.** Logins are PBKDF2 (`Rfc2898DeriveBytes` + SHA512, per-user salt). Platform staff are created with `IsPendingInvitation = true` / `MustChangePassword = true` and reach a credential through the existing activation/reset flow.
9. HotChocolate strips `Get` from every resolver name and appends `Input` to input types. `tsc` cannot see gql field names — a wrong name compiles clean and fails only at runtime. Verify each field name against the schema type.
10. DB is UTC-only. Every `DateTime` written must be `Kind = Utc`.

---

## ⓪ Verified on disk — 2026-08-04

| What | Where | State |
|---|---|---|
| Platform module / menus / capabilities / 5 roles | `sql-scripts-dyanmic/ops-platform-rbac-seed.sql` | applied. 1 module `PLATFORM`, root menu `PLATFORMCONTROLPLANE` + 4 leaves, 10 `PLATFORM_*` capabilities, 5 roles |
| Platform roles' shape | same seed, §4 | `IsSystem = true`, **`IsAssignable = true`**, `CompanyId = NULL` |
| Platform staff creation | `sql-scripts-dyanmic/ops-platform-user-seed.sql` | **hand-run SQL only.** Header: *"Nothing in the product mints a platform user today"* |
| Platform staff identity model | same seed, §"IDENTITY MODEL" | `auth.Users.CompanyId IS NULL` + ≥1 `UserRoles` → `Roles.CompanyId IS NULL`. **The role link is the discriminator.** |
| Provisioning step list | `ProvisionTenant.cs:181-189` | 1 CREATE_COMPANY · 2 CREATE_SUBSCRIPTION · 3 SEED_ROLES · 4 SEED_CAPABILITIES · 5 SEED_MASTERDATA · 6 SEED_SETTINGS · 7 SEED_FIELDS · 8 CREATE_ADMIN · 9 SEND_WELCOME. **Step 2 runs before step 4, so the plan is known when capabilities are seeded.** |
| Per-tenant role cloning | `ProvisionTenant.cs:610-646` (Step 3) | clones every `__TEMPLATE__` role → new `RoleId`, `CompanyId` = new tenant. **20 tenants = 20 `BUSINESSADMIN` rows.** Throws if the template is absent |
| Per-tenant capability cloning | `ProvisionTenant.cs:648-720` (Step 4a) | clones template `RoleCapability` rows by `RoleCode` match. **No plan variable anywhere in the method** |
| Step 4b module grant | `ProvisionTenant.cs:697-701` | comment: *"modules are too coarse to sell … Plan differences are expressed by billing.FeatureMenuMaps at the menu level instead"* |
| Template company code | `ProvisionTenant.cs:160` | `private const string TemplateCompanyCode = "__TEMPLATE__";` |
| Template company shell seed | `sql-scripts-dyanmic/ops-template-company-seed.sql` | 54 lines, idempotent, **status unknown — may be unapplied**. Header: *"only the SHELL: its roles / master data / settings / fields are populated LATER … through the normal app UI"* |
| Plan → menu filter | `Base.Infrastructure/Services/Billing/PlanMenuFilter.cs` | keyed on **companyId**, resolves via `IEntitlementService.ResolveAsync`. **Fails OPEN**: unmapped menu never blocked; `Status == None` → nothing blocked. Never blocks `BILLING*` / `SETTING*` / `ACCESSCONTROL*`. Ancestor cascade, `MaxDepth = 32`, cycle-guarded |
| Menu → feature map | `IMenuFeatureMap` / `billing.FeatureMenuMaps` | platform-wide (no `CompanyId`), cached, **deliberately partial** |
| Entitlement resolve | `IEntitlementService.ResolveAsync(companyId)` | company-keyed only — **no plan-keyed overload exists** |
| Tenant matrix query | `GetRoleCapabilityMatrix.cs:47` | `r.CompanyId == tenantId \|\| r.IsSystem == true` |
| Tenant matrix plan filter | `GetRoleCapabilityMatrix.cs:66-91,118-124` | plan-blocked menus dropped as **rows**; underlying `RoleCapability` rows left in place; role tallies counted over visible rows only |
| Grant-to-all-roles | `GrantCapabilityToAllRoles.cs:57` | `r.RoleCode != "SUPERADMIN" && (r.CompanyId == tenantId \|\| r.IsSystem == true)`; tenant-scoped |
| Role list filter | `GetRoles.cs:30-35` | `IsDeleted == false && IsActive == true`; `IsAssignable == true` only when not SuperAdmin. **No `CompanyId` predicate at all** |
| `SUPERADMIN` immutability | `BulkUpdateRoleCapabilityMatrix.cs:63-71` + 4 sibling handlers | throws `SUPERADMIN_IMMUTABLE` on any revoke |
| Platform-scope audit table | `Base.Domain/Models/OpsModels/` | **does not exist.** `audit.AuditLogs` has non-nullable `CompanyId`, auto-stamped by `TenantSaveChangesInterceptor` |
| Existing platform routes | `PSS_2.0_Frontend/src/app/[lang]/(master)/platform/` | `billing`, `communications`, `dashboards`, `gateways`, `webhook-logs`, `layout.tsx`. **No `staff`.** |

### Defects this prompt fixes

**D1 — Platform roles leak into every tenant's capability matrix.**
`GetRoleCapabilityMatrix.cs:47` admits any role where `IsSystem == true`, regardless of `CompanyId`. The five `PLATFORM_*` roles are exactly that. So **every tenant admin opening screen #70 sees `Platform Sales`, `Platform Admin`, … as editable columns** — and `BulkUpdateRoleCapabilityMatrix` will persist their edits, because the only guard is on `SUPERADMIN`. A tenant can currently modify the platform's own access control.
`GrantCapabilityToAllRoles.cs:57` has the identical predicate, so a tenant admin clicking *"Grant to All Roles"* grants that capability to `PLATFORM_ADMIN` too.

**D2 — Platform roles are assignable to tenant users.**
`GetRoles.cs` filters on `IsAssignable == true` and applies **no** `CompanyId` predicate. Platform roles are seeded `IsAssignable = true`. They therefore appear in the tenant's role picker. Assigning one produces a mixed user, which the P-19 host gate rejects on *both* host kinds — the tenant admin locks their own colleague out of the product with no error message anywhere.
(Contrast `SYSTEMROLE`, which is deliberately `IsAssignable = false` *precisely* so `GetRoles` hides it.)

**D3 — Nothing propagates a new capability to existing tenants.**
Steps 3/4 clone **once, at provisioning time**. When a release adds a menu or capability, future tenants can be fixed but the already-provisioned `BUSINESSADMIN` roles never receive it. `GrantCapabilityToAllRoles` reads `tenantContext.GetCurrentTenantId()` and cannot leave the current tenant.

**D4 — Platform staff can only be minted by hand-run SQL, with a borrowed password hash.**
`ops-platform-user-seed.sql` copies `PasswordHash`/`PasswordSalt` from a named existing account because PBKDF2-SHA512 is not reproducible in plain SQL. Two platform accounts created this way share a working credential until both are reset.

**D5 — (verify only, no fix) `SUPERADMIN` platform grants may be silently absent.**
`ops-platform-rbac-seed.sql` §5 joins `auth."Roles" r ON r."RoleCode" = v.role_code AND r."CompanyId" IS NULL`. The 20 `SUPERADMIN` rows in that VALUES list insert **nothing** unless the `SUPERADMIN` role row itself has `CompanyId IS NULL`. Ship a verification query; do not "fix" the seed until the user confirms the actual row.

**D6 — (new in v2, the reason this prompt was revised) Capability provisioning is plan-blind, and the compensating filter fails OPEN.**
Step 4a copies the template's *entire* capability set into every tenant regardless of plan. The only thing standing between a 50K tenant and a 100K-only menu is `PlanMenuFilter`, which its own XML doc describes as **"deliberately fail-OPEN: an unmapped menu is never blocked"** and **"COSMETIC ONLY … not the security boundary"**. So a menu that nobody remembered to add to `billing.FeatureMenuMaps` is granted, rendered, and reachable on every plan — and the `[RequiresFeature]` command gate only helps on commands that carry the attribute.
**Fix:** grant only what the plan includes, so there is no row to leak. Provisioning becomes fail-CLOSED at the data layer, with the cosmetic filter as a second line rather than the only one.

---

## ① The one idea

> **Configure one baseline per plan. Never twenty tenants.**

Four plans and thirty tenants must be four pieces of configuration, not thirty. A tenant's `BUSINESSADMIN` is **born from its plan's baseline**, capped by that plan's feature menus. Upgrades top the baseline up. Downgrades leave rows alone (the plan already hides them, and deleting would destroy the tenant's own decisions). After birth the matrix is the tenant's to edit; the platform only ever *adds*, deliberately, with a preview and an audit row.

```
                 billing.PlanRoleBaselines
                 (PlanId × RoleCode × Menu × Capability)
                              │
        ┌─────────────────────┼─────────────────────┐
        │ provisioning        │ plan upgrade        │ manual push
        ▼                     ▼                     ▼
   new tenant's         missing rows          live tenants on
   RoleCapabilities     topped up             that plan (additive)
```

The `__TEMPLATE__` company keeps supplying the **role set** (step 3), master data, settings and fields. It stops supplying capability rows. Baselines own those.

---

## ② Design

One screen, four tabs, at `(master)/platform/staff`. Every tab is gated by a distinct capability so `PLATFORM_SUPPORT` can be given the read-only tabs without the push button.

### Tab 1 — Platform Staff (`PLATFORM_STAFF_VIEW` / `PLATFORM_STAFF_MANAGE`)

List, invite, edit, deactivate platform users. Replaces `ops-platform-user-seed.sql` (D4).

```
GetPlatformStaffQuery(GridFilterRequest filter)
  → PlatformStaffListResult(GridResult<PlatformStaffRowDto>)
PlatformStaffRowDto(int UserId, string UserName, string Email, string? DisplayName,
                    IReadOnlyList<string> RoleCodes, int? PrimaryRoleId,
                    bool IsActive, bool IsLocked, bool IsPendingInvitation,
                    DateTime? LastLoginDate, DateTime CreatedDate)

InvitePlatformStaffCommand(PlatformStaffInviteDto request)
  → PlatformStaffInviteResult(int UserId, bool InvitationSent)
PlatformStaffInviteDto(string UserName, string Email, string? DisplayName,
                       IReadOnlyList<int> RoleIds, int PrimaryRoleId)

UpdatePlatformStaffCommand(PlatformStaffUpdateDto request)   // email, display name, roles, primary role
SetPlatformStaffActiveCommand(int UserId, bool IsActive)      // deactivate / reactivate
UnlockPlatformStaffCommand(int UserId)                        // clears IsLocked + FailedLoginCount
ResendPlatformStaffInviteCommand(int UserId)
```

Rules baked into the handlers:
- **Creation writes no hash.** `PasswordHash`/`PasswordSalt` stay null, `IsPendingInvitation = true`, `MustChangePassword = true`, `CompanyId = NULL`. Credential arrives via the existing activation-token path (`ITenantActivationService` mints tenant-admin tokens today; reuse the same token + email mechanism with a `PLATFORM_STAFF_INVITATION` template, or the standard forgot-password flow if that is cheaper — pick one and record it in §⑬).
- **`RoleIds` must all be platform roles** (`CompanyId IS NULL && IsPlatform == true`). Anything else → `BadRequestException("PLATFORM_ROLE_REQUIRED: …")`. This is the never-both invariant (Rule 6) enforced on the platform side.
- **`SUPERADMIN` is not offered and not accepted** as a `RoleId` here. It is a break-glass tenant identity, not platform staff.
- **Self-protection**: a user may not deactivate themselves, and the last active `PLATFORM_ADMIN` may not be deactivated or stripped of that role → `BadRequestException("LAST_PLATFORM_ADMIN: …")`.
- Deactivate is `IsActive = false`, **never** a hard delete — audit history references the row.

### Tab 2 — Platform Roles (`PLATFORM_STAFF_VIEW` / `PLATFORM_RBAC_TEMPLATE_EDIT`)

The 5 `PLATFORM_*` roles × platform menus × the 10 `PLATFORM_*` capabilities.

```
GetPlatformRoleMatrixQuery()
  → PlatformRoleMatrixResult(RoleCapabilityMatrixDto matrix)

BulkUpdatePlatformRoleMatrixCommand(RoleCapabilityMatrixSaveDto request)
  → PlatformRoleMatrixResult
```

A **separate handler**, not a parameter on `GetRoleCapabilityMatrixQuery`. Reason: that query is `[CustomAuthorize(DecoratorAuthModules.RoleCapability, Permissions.Read)]` — a *tenant* capability. Reusing it would mean a tenant capability can read platform RBAC. Reuse the DTO shapes (`RoleCapabilityMatrixDto` / `…RowDto` / `…SaveDto`) so the FE matrix component is shared; do not reuse the handler.

Scope: roles where `CompanyId IS NULL && IsPlatform == true`; menus under `Modules.ModuleCode = 'PLATFORM'`. `SUPERADMIN` renders as a read-only column (`IsReadOnly = true`) exactly as on screen #70.

### Tab 3 — Plan Baselines (`PLATFORM_RBAC_TEMPLATE_EDIT`) ★ replaces v1's "Tenant Role Template"

**The main working surface.** Pick a plan and a role code; edit the matrix that every tenant on that plan is born with.

```
 Plan: [ 50K ▾ ]        Role: [ BUSINESSADMIN ▾ ]
 ───────────────────────────────────────────────────
 Menu            View  Create  Edit  Delete  Approve
 Donations         ✓     ✓      ✓      ✓       ✓
 Donors            ✓     ✓      ✓      ✓       —
 (Grants not shown — not included in the 50K plan)
 ───────────────────────────────────────────────────
 [ Save baseline ]         [ Push to 12 live tenants ]
```

```
GetPlanRoleBaselineQuery(int PlanId, string RoleCode)
  → PlanRoleBaselineResult(int PlanId, string PlanCode, string PlanName, string RoleCode,
                           int AllowedMenuCount, int GrantedCellCount,
                           int LiveTenantCount,
                           RoleCapabilityMatrixDto matrix)   // single-column matrix: the role

BulkUpdatePlanRoleBaselineCommand(PlanRoleBaselineSaveDto request)
  → PlanRoleBaselineResult
PlanRoleBaselineSaveDto(int PlanId, string RoleCode,
                        IReadOnlyList<RoleCapabilityCellDto> Cells)   // MenuId, CapabilityId, HasAccess

GetPlanBaselineSummaryQuery()
  → PlanBaselineSummaryResult(IReadOnlyList<PlanBaselineSummaryRowDto> Rows)
PlanBaselineSummaryRowDto(int PlanId, string PlanCode, string PlanName, bool IsActive,
                          int RoleCodeCount, int GrantedCellCount, int LiveTenantCount,
                          DateTime? LastModifiedDate, string? LastModifiedBy,
                          bool IsEmpty)   // true → provisioning on this plan will fail
```

Semantics, non-negotiable:
- **The matrix is capped by the plan.** Rows are only the menus that plan's features allow. A cell outside that set cannot be rendered and is **rejected at save** with `MENU_NOT_IN_PLAN` — the screen is not the guard, the handler is.
- The cap is computed by the new `IPlanMenuScope` service (§③), **not** by `IPlanMenuFilter` — that one is keyed on `companyId` and a baseline has no company.
- **Save ≠ push.** `Save` writes `billing.PlanRoleBaselines` and affects *future* tenants only. `Push` (tab 4) is the separate, explicit act that reaches live tenants. Two buttons, on purpose: a save must never silently rewrite twelve customers.
- The tab header must carry that sentence verbatim: *"Saving changes what new tenants on this plan are born with. Existing tenants are unaffected — use Tenants & Push."*
- **Role codes offered** = distinct `RoleCode` from the `__TEMPLATE__` company's roles (that is the set step 3 clones), minus `SUPERADMIN` and minus any `IsPlatform` role. `BUSINESSADMIN` is the default selection.
- `IsEmpty` on the summary is a **warning banner**, not a silent state: a plan with no baseline rows will provision an administrator who can do nothing.

### Tab 4 — Tenants & Push (`PLATFORM_RBAC_ROLLOUT`) ★ replaces v1's "Capability Rollout"

Two things in one tab: *who is out of line*, and *fix it*.

**4.1 Drift table** — every live tenant on the selected plan, compared against the baseline.

```
GetTenantBaselineDriftQuery(int PlanId, string RoleCode)
  → TenantBaselineDriftResult(int PlanId, string RoleCode, int TenantCount,
                              int InSyncCount, int MissingSomeCount,
                              IReadOnlyList<TenantDriftRowDto> Rows)
TenantDriftRowDto(int CompanyId, string CompanyName, string SubscriptionStatus,
                  bool RoleExists, int MissingCellCount, int ExtraCellCount,
                  string Status)   // IN_SYNC | MISSING | ROLE_MISSING
```

- **Missing** = in the baseline, not on the tenant. This is what push fixes.
- **Extra** = on the tenant, not in the baseline. Reported, **never removed** — it is almost always the tenant's own deliberate grant.
- `ROLE_MISSING` = tenant has no role with that code. Reported, not an error.

**4.2 Push** — apply a plan's baseline to live tenants. Additive only.

```
GetBaselinePushPreviewQuery(int PlanId, string RoleCode, IReadOnlyList<int>? CompanyIds)
  → BaselinePushPreviewResult(string PlanCode, string RoleCode,
                              int TenantCount, int WouldGrantCellCount,
                              int AlreadyInSyncCount, int RoleMissingCount,
                              IReadOnlyList<BaselinePushPreviewRowDto> Rows)
BaselinePushPreviewRowDto(int CompanyId, string CompanyName, int WouldGrantCellCount,
                          string Outcome)   // WOULD_GRANT | ALREADY_HAS | ROLE_MISSING

ExecuteBaselinePushCommand(BaselinePushDto request)
  → BaselinePushResult(int RunId, int TenantCount, int GrantedCellCount, int SkippedCount)
BaselinePushDto(int PlanId, string RoleCode, IReadOnlyList<int>? CompanyIds, string? Note)
```

**4.3 Single-capability rollout** — kept as a secondary tool for "we shipped one new menu and it belongs on several plans at once".

```
GetRolloutPreviewQuery(int MenuId, int CapabilityId, IReadOnlyList<string> RoleCodes,
                       IReadOnlyList<int>? CompanyIds)
  → RolloutPreviewResult(string MenuName, string CapabilityName,
                         int TenantCount, int WouldGrantCount, int AlreadyHasCount,
                         int BlockedByPlanCount, IReadOnlyList<RolloutPreviewRowDto> Rows)
RolloutPreviewRowDto(int CompanyId, string CompanyName, string RoleCode,
                     string Outcome)   // WOULD_GRANT | ALREADY_HAS | BLOCKED_BY_PLAN | ROLE_MISSING

ExecuteCapabilityRolloutCommand(CapabilityRolloutDto request)
  → CapabilityRolloutResult(int RunId, int GrantedCount, int SkippedCount, int TenantCount)
CapabilityRolloutDto(int MenuId, int CapabilityId, IReadOnlyList<string> RoleCodes,
                     IReadOnlyList<int>? CompanyIds, string? Note)
```

Semantics shared by 4.2 and 4.3, non-negotiable:
- **Additive only.** Insert `RoleCapability` rows with `HasAccess = true` where none exists. Never set `HasAccess = false`, never update an existing row, never delete. A tenant who deliberately turned something off keeps it off.
- **Preview before execute.** The execute button stays disabled until a preview has been fetched for the *current* selection; changing any input invalidates it. Preview and execute share one internal resolver so the numbers cannot drift.
- **`CompanyIds = null` means every active tenant in scope**, and the FE requires a typed confirmation (the tenant count), not a checkbox.
- **Plan gating is respected in 4.3.** Per tenant, a menu the plan excludes is `BLOCKED_BY_PLAN` — skipped, counted, reported; never granted, never fatal. 4.2 needs no such check: a baseline is already plan-capped by construction.
- **`SUPERADMIN` and `IsPlatform` roles are never targets.**
- Every run writes one `ops.RbacRolloutRuns` header and one `ops.RbacRolloutTargets` row per (tenant, role), **including skips**. A push you cannot reconstruct is worse than no push.
- Chunk writes at 200 rows per `SaveChangesAsync`. A baseline push over 200 tenants is thousands of cells.

**4.4 Push history** — the run list, newest first, expandable to its target rows. Read-only.

```
GetRolloutHistoryQuery(GridFilterRequest filter)
  → RolloutHistoryResult(GridResult<RolloutRunRowDto>)
GetRolloutRunDetailQuery(int RunId)
  → RolloutRunDetailResult(RolloutRunRowDto Run, IReadOnlyList<RolloutTargetRowDto> Targets)
```

### Tab 4b — Tenant matrix inspector (break-glass) (`PLATFORM_TENANT_VIEW` / `PLATFORM_TENANT_RBAC_OVERRIDE`)

Reached from a drift row or from the tenant list. Read-only by default.

```
GetTenantRoleMatrixQuery(int CompanyId)
  → TenantRoleMatrixResult(string CompanyName, RoleCapabilityMatrixDto matrix)

OverrideTenantRoleCapabilityCommand(int CompanyId, int RoleId, int MenuId,
                                    int CapabilityId, bool HasAccess, string Reason)
  → TenantRoleMatrixResult
```

- The override command requires a **non-empty `Reason` of ≥ 10 characters**. No reason, no write.
- It writes an `audit.AuditLogs` row **stamped with the target tenant's `CompanyId`** — the tenant's own audit trail shows that the platform changed their access, with the actor's name and the reason. It also writes an `ops.PlatformAuditLog` row on the platform side. Both, not either.
- Because `TenantSaveChangesInterceptor` auto-stamps `CompanyId` from the ambient tenant context, the audit row must be written with the target company explicitly set — verify the interceptor does not overwrite it; if it does, write that row via an explicit post-interceptor assignment or raw SQL. **Record which approach was used in §⑬.**
- **Granting a menu the tenant's plan excludes is refused here too** → `MENU_NOT_IN_PLAN`. Break-glass exists to fix permissions, not to give away unsold features. Selling a feature is a plan change, not an RBAC override.
- This is the one place the platform may revoke inside a live tenant, and it is one cell at a time, with a reason, in two audit logs.

---

## ③ Data

### Migration (user-owned — full DDL in `PSS-2.0-ONBOARDING-PROMPT-24-MIGRATION-SPEC.md`)

**One column:**
- `auth.Roles.IsPlatform` — `boolean NOT NULL DEFAULT false`. The discriminator that fixes D1 and D2. `IsSystem` cannot serve: `SYSTEMROLE` and `SUPERADMIN` are also `IsSystem` and must stay visible to tenants. Flipped `true` for the five `PLATFORM_*` roles by the seed, not by the migration.

**One table in `billing`:**

| Table | Purpose |
|---|---|
| `billing.PlanRoleBaselines` | **the new heart of this prompt.** One row per (`PlanId`, `RoleCode`, `MenuId`, `CapabilityId`, `HasAccess`). Unique on the first four. Flat — no header table; `ModifiedDate`/`ModifiedBy` from the `Entity` base carry "last edited" |

**Three tables in `ops`** (all platform-global — no tenant discriminator):

| Table | Purpose |
|---|---|
| `ops.RbacRolloutRuns` | one row per push: `RunKind` (`BASELINE_PUSH` \| `SINGLE_CAPABILITY`), `PlanId?`, `RoleCodesCsv`, `MenuId?`, `CapabilityId?`, `TargetScope` (`ALL` \| `SELECTED`), `TenantCount`, `GrantedCount`, `SkippedCount`, `Note`, `ExecutedByUserId?`, `ExecutedByUserName`, `ExecutedAt` |
| `ops.RbacRolloutTargets` | one row per (run, tenant, role): `RunId` (FK, cascade), `CompanyId`, `CompanyName`, `RoleId?`, `RoleCode`, `Outcome`, `GrantedCellCount`, `Reason?`. **Per (tenant, role), not per cell** — a 200-tenant baseline push must not write 100 000 audit rows |
| `ops.PlatformAuditLog` | platform-scope audit: `ActionType`, `EntityType`, `EntityId?`, `TargetCompanyId?`, `Description`, `ChangesJson?`, `Reason?`, `ActorUserId?`, `ActorUserName`, `IpAddress?`, `Timestamp` |

`ops.PlatformAuditLog` is written by every command in this prompt. It also gives the already-seeded but empty `PLATFORM_AUDIT` menu something to render — **that screen is out of scope here**; this prompt writes the rows, a later prompt reads them.

### New service — `IPlanMenuScope`

`IPlanMenuFilter` answers *"which menus are blocked for this **company**"*. A baseline has no company. So:

```csharp
public interface IPlanMenuScope
{
    /// Menu ids a PLAN includes, resolved from billing.PlanEntitlements + billing.FeatureMenuMaps,
    /// with the same ancestor cascade and the same NeverBlockedPrefixes as PlanMenuFilter.
    Task<HashSet<int>> GetAllowedMenuIdsForPlanAsync(int planId, CancellationToken ct);
}
```

- Extract the ancestor-walk + `NeverBlockedPrefixes` + `MaxDepth` cycle guard out of `PlanMenuFilter` into a shared internal helper and have **both** services call it. Two copies of that walk will drift, and a baseline that disagrees with the sidebar is exactly the bug class this prompt exists to close.
- Reads the plan's entitlement rows directly — do **not** go through `IEntitlementService.ResolveAsync`, which is company-keyed and applies subscription overrides that belong to one tenant, not to a plan.
- **Fail-CLOSED direction is inverted from `PlanMenuFilter` on purpose.** `PlanMenuFilter` returns *blocked* and defaults to "not blocked". `IPlanMenuScope` returns *allowed*; an unmapped menu is **allowed** (same partial-map semantics — absence still means "not plan-gated"), but a menu mapped to a feature the plan does not enable is **excluded**. Document that sentence in the interface XML doc; the asymmetry is a trap for the next reader.

### Seeds (I write, user applies)

**1. `sql-scripts-dyanmic/platform-staff-rbac-seed.sql`** *(already written — one addition)*
1. `UPDATE auth."Roles" SET "IsPlatform" = true WHERE "CompanyId" IS NULL AND "RoleCode" IN (…5 codes…)` — guarded, raises if any is missing.
2. `UPDATE auth."Roles" SET "IsAssignable" = false WHERE "IsPlatform" = true;` — belt-and-braces for D2.
3. One new menu `PLATFORM_STAFF` → `/platform/staff`, under `PLATFORMCONTROLPLANE`, `OrderBy` 950.
4. Five new capabilities, `IsSpecial = true`, names prefixed `"Platform "` (UNIQUE index on `(CapabilityName, IsActive)` — bare names collide): `PLATFORM_STAFF_VIEW`, `PLATFORM_STAFF_MANAGE`, `PLATFORM_RBAC_TEMPLATE_EDIT`, `PLATFORM_RBAC_ROLLOUT`, `PLATFORM_TENANT_RBAC_OVERRIDE`.
   *(`PLATFORM_RBAC_TEMPLATE_EDIT` now governs **plan baselines**. Code kept to avoid churn across four files; the capability's description text is updated to say so.)*
5. Grants: all five → `PLATFORM_ADMIN`. `PLATFORM_STAFF_VIEW` → `PLATFORM_SUPPORT` + `PLATFORM_IMPLEMENTATION`. `PLATFORM_TENANT_RBAC_OVERRIDE` → `PLATFORM_ADMIN` only. `SUPERADMIN` gets the superset — *conditional on D5*.
6. The D5 verification query, commented, at the foot.

**2. `sql-scripts-dyanmic/plan-role-baseline-bootstrap-seed.sql`** *(new — I write with the build)*
Bootstraps `billing.PlanRoleBaselines` so the platform does not start from an empty screen for every plan:
- For each active plan × `BUSINESSADMIN`, insert one row per (menu, capability) where the menu is in that plan's scope (`billing.PlanEntitlements` ⋈ `billing.FeatureMenuMaps`, ancestor cascade, never-blocked prefixes) **and** the pair exists in `auth.MenuCapabilities`.
- Source of the ticks: the `__TEMPLATE__` company's `BUSINESSADMIN` `RoleCapability` rows where present, else `HasAccess = true`.
- **Idempotent** — guarded by `NOT EXISTS` on the unique key. Re-running adds only what is missing, never overwrites a curated baseline.
- Prints a per-plan row count so an empty plan is visible immediately.

---

## ④ Build steps

**Backend — schema & shared**

1. `bool IsPlatform` on `Base.Domain/Models/AuthModels/Role.cs`; map in `RoleConfiguration.cs` with `.HasDefaultValue(false)`. Do **not** add it to `Role.Create` — seed-owned, never set by application code.
2. `PlanRoleBaseline` entity + configuration under `billing`; unique index on `(PlanId, RoleCode, MenuId, CapabilityId)`.
3. The three `ops` entities + configurations + `DbSet`s on `IApplicationDbContext` and `ApplicationDbContext`. Confirm the global tenant filter is **not** applied to any of the four new entities, or every platform read silently returns zero rows.
4. `IPlanMenuScope` + implementation. Extract the shared ancestor-walk helper out of `PlanMenuFilter`; both services call it. Register in DI next to `PlanMenuFilter`.

**Backend — defect fixes**

5. **D1** — `GetRoleCapabilityMatrix.cs:47`: `(r.CompanyId == tenantId || r.IsSystem == true) && r.IsPlatform == false`.
6. **D1** — `GrantCapabilityToAllRoles.cs:57`: add `&& r.IsPlatform == false`.
7. **D2** — `GetRoles.cs`: add `.Where(x => x.IsPlatform == false)` for tenant callers. Platform tabs use their own queries and never call `GetRoles`. Same guard on `GetNotificationRecipientOptions.cs:172` — a platform role must never be a tenant notification recipient.
8. **D2 (save side)** — wherever tenant `UserRoles` are written, reject a `RoleId` whose role is `IsPlatform` → `BadRequestException("PLATFORM_ROLE_NOT_ASSIGNABLE: …")`. One place, not scattered.

**Backend — D6: provisioning reads the baseline**

9. **Rewrite `ProvisionTenant.Step4_SeedCapabilitiesAsync` §4a.** Replace the `__TEMPLATE__` `RoleCapability` clone with a read of `billing.PlanRoleBaselines` for the tenant's plan:
   - Resolve the tenant's `PlanId` from the `Subscription` written by step 2. **If there is no subscription row, throw** — step 2 precedes step 4, so its absence is a broken run, not a state to paper over.
   - For each role of the new tenant whose `RoleCode` appears in the baseline, insert `RoleCapability` rows from the baseline. Keep the existing `grantedSet` idempotency guard so a resumed run cannot double-insert.
   - **If the plan has zero baseline rows, throw `NotFoundException`** naming the plan, in the same style as the missing-template throw at line 623. Silent success here reproduces the exact "Aram" failure this codebase already paid for: run SUCCEEDED, `capability_grants = 0`, admin lands on an empty page.
   - §4b (module grants) is unchanged — modules stay unconditional, per its existing comment.
   - Step 3 (roles) still clones from `__TEMPLATE__`. Only capabilities move.
   - Update the method's XML/comment block to say where capabilities now come from. The old comment describing the template clone must not survive.
10. **Upgrade top-up.** One service, `IPlanBaselineApplier`:
    ```csharp
    Task<BaselineApplyResult> ApplyAsync(int companyId, int planId, string? roleCode, CancellationToken ct);
    ```
    Additive only; returns granted/skipped counts. Called from **three** places: step 4 (§9), the plan-change path, and `ExecuteBaselinePushCommand`. One implementation — three copies of "apply a baseline" is how upgrade and push drift apart.
    Locate the command that changes a tenant's plan (search `Subscription` + `PlanId` writers; `_entitlementService.Invalidate(companyId)` is a reliable marker) and call `ApplyAsync` after the plan is persisted and the cache invalidated. **If no such command exists yet, do not invent one** — record that in §⑬ and note that upgrades must be topped up manually from tab 4 until a plan-change command exists.
    **Downgrade does nothing.** No delete, no `HasAccess = false`. The plan filter already hides those menus, and removing rows would destroy the tenant's own permission decisions and make a re-upgrade lossy.

**Backend — screens**

11. Tab 1 — `GetPlatformStaffQuery` + the five staff commands. Every read: `IgnoreQueryFilters()` + `IsDeleted != true`.
12. Tab 2 — `GetPlatformRoleMatrixQuery` + `BulkUpdatePlatformRoleMatrixCommand`. Reuse the matrix DTOs; new handlers.
13. Tab 3 — `GetPlanBaselineSummaryQuery`, `GetPlanRoleBaselineQuery`, `BulkUpdatePlanRoleBaselineCommand`. The save handler validates every cell against `IPlanMenuScope` → `MENU_NOT_IN_PLAN`, and against `auth.MenuCapabilities` → `CAPABILITY_NOT_ON_MENU`.
14. Tab 4 — `GetTenantBaselineDriftQuery`, `GetBaselinePushPreviewQuery`, `ExecuteBaselinePushCommand`, `GetRolloutPreviewQuery`, `ExecuteCapabilityRolloutCommand`, `GetRolloutHistoryQuery`, `GetRolloutRunDetailQuery`. Preview and execute share one internal resolver. Chunked writes. Run + target rows always written, including skips; a preview persists nothing.
15. Tab 4b — `GetTenantRoleMatrixQuery(int CompanyId)` + `OverrideTenantRoleCapabilityCommand`. Dual audit write.
16. One `IPlatformAuditWriter`; every command in steps 11–15 calls it. Do not inline audit construction in a dozen handlers.
17. GraphQL wiring: `PlatformStaffQueries`/`Mutations` + `PlatformRbacQueries`/`Mutations` under `Base.API/EndPoints/Ops/`. Register in the schema builder. Remember `Get` is stripped and `Input` is appended.

**Frontend**

18. Route `src/app/[lang]/(master)/platform/staff/page.tsx` — tabbed shell, tab visibility driven by capability; no client-side capability *enforcement* (BE is the gate).
19. Tab 1: data table + invite drawer (react-hook-form + zodResolver). Role multi-select fed by the platform-roles query, **not** `GetRoles`.
20. Tab 3: plan selector + role selector + the matrix component from screen #70. If that component is coupled to the tenant query, extract the presentational part; do not fork it. Plan summary strip above the matrix (cells granted, live tenants, last edited, empty-baseline warning).
21. Tabs 2 / 4b: same matrix component.
22. Tab 4: drift table → select tenants → preview → execute, with the history list below. Execute disabled until a preview exists for the current selection.
23. GraphQL documents + generated types. Verify every field name against the running schema — `tsc` cannot see them.
24. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, no pipe. Only exit 0 counts.

---

## ⑤ UI notes

- **Tab 3 banner, verbatim:** *"Saving changes what new tenants on this plan are born with. Existing tenants are unaffected — use Tenants & Push."* Without it the user will edit a baseline expecting twelve live tenants to change, and nothing will happen.
- **Tab 3 must show why a menu is absent.** A collapsed footer row — *"18 menus hidden: not included in the 50K plan"* — expandable to the list. Otherwise "where did Grants go?" becomes a support ticket about our own admin screen.
- **Empty baseline is loud.** A plan with zero rows renders a destructive-toned banner: *"No baseline configured. Provisioning a tenant on this plan will fail."* That is literally true after step 9.
- **Tab 4's preview is the product.** Four tiles before the table — *Tenants*, *Will grant*, *Already in sync*, *Role missing*. Solid `bg-X-600` + `text-white` icon containers per the standing widget rule.
- Drift status as a solid badge: `In sync` (green) / `Missing N` (amber) / `Role missing` (red).
- "All tenants on this plan" requires typing the tenant count to confirm — not a checkbox.
- Tab 4b renders the matrix visibly **read-only** — dimmed toggles, lock icon, an explicit *"Enable override"* switch that reveals the reason field. Never let a stray click write into a customer's RBAC.
- Staff rows show status as a solid badge: `Active` / `Invited` / `Locked` / `Inactive`.
- Empty states everywhere: no baselines, no platform staff beyond yourself, no push history, no tenants on a plan.
- xs→xl responsive; `@iconify` Phosphor icons; tokens only, no hex, no px.

---

## ⑥ Invariants

- **INV-1** A user never holds both a `CompanyId IS NULL` role and a `CompanyId IS NOT NULL` role.
- **INV-2** `SUPERADMIN` is never revoked, never a push target, never an invitable platform role.
- **INV-3** A push only ever inserts `HasAccess = true` rows. No update, no delete, no `false`.
- **INV-4** Every write this screen performs into a live tenant produces an `audit.AuditLogs` row stamped with **that tenant's** `CompanyId`.
- **INV-5** Every command in this prompt produces exactly one `ops.PlatformAuditLog` row, success or failure.
- **INV-6** No platform role is visible in, or writable from, any tenant surface.
- **INV-7** Editing a baseline never mutates a live tenant. Editing a live tenant never mutates a baseline.
- **INV-8** **No `RoleCapability` row is ever created for a menu outside the tenant's plan scope** — not by provisioning, not by baseline save, not by push, not by break-glass override. This is D6's fix and the reason the prompt was revised.
- **INV-9** A plan downgrade deletes nothing.
- **INV-10** A plan upgrade leaves no newly-entitled menu without its baseline grants.
- **INV-11** No handler in this prompt writes a password hash.
- **INV-12** At least one active `PLATFORM_ADMIN` exists at all times.
- **INV-13** Provisioning a tenant on a plan with an empty baseline **fails loudly**. It never reports SUCCEEDED with zero capability grants.

---

## ⑦ Out of scope

- The `PLATFORM_AUDIT` **screen** (`/ops/audit`). This prompt writes `ops.PlatformAuditLog`; reading it is a later prompt.
- Impersonation. `PLATFORM_IMPERSONATE` is seeded and unimplemented; unchanged here.
- Baselines for roles other than the tenant role set cloned from `__TEMPLATE__`. The screen is general (any role code), but no new role concept is introduced.
- Migrating `__TEMPLATE__`'s role/masterdata/settings/fields responsibilities anywhere else. It keeps all three; only capability rows move to baselines.
- Tenant-side user management (screen #70 and the tenant user screens are untouched apart from the D1/D2 guards).
- SSO / MFA for platform staff.
- **Bulk cross-tenant revoke — deliberately rejected.** A revoke that crosses tenants cannot distinguish "the platform never granted this" from "the tenant deliberately granted this", so it will eventually remove access a customer chose. Break-glass, one cell, with a reason, is the supported path.
- Backfilling `RoleModules` for pre-STEP-1 tenants (tracked on PROMPT-17).
- **Backfilling existing tenants' matrices down to their plan.** Existing over-granted rows stay; the plan filter hides them and INV-3 forbids the revoke. If the user wants them cleaned, that is a separate, explicitly-authorised script.

---

## ⑧ Acceptance

1. A tenant admin opening screen #70 sees **no** `PLATFORM_*` column.
2. A tenant admin's *"Grant to All Roles"* creates no `RoleCapability` row against any `IsPlatform` role.
3. `PLATFORM_*` roles do not appear in the tenant role list or any tenant role picker.
4. Assigning a platform role to a tenant user is rejected with `PLATFORM_ROLE_NOT_ASSIGNABLE`.
5. Tab 1 lists every `CompanyId IS NULL` user with their platform roles.
6. Inviting platform staff creates the user with null hash, `IsPendingInvitation = true`, and sends an invitation.
7. The invited account can set a password through the invitation link and log in on the platform host.
8. Inviting with a tenant role in `RoleIds` is rejected; `SUPERADMIN` is not offered.
9. Deactivating the last active `PLATFORM_ADMIN`, or yourself, is rejected.
10. Tab 2 shows the 5 platform roles × platform menus; `SUPERADMIN` is read-only; a save persists and survives a reload.
11. Tab 2's query rejects a caller holding only tenant capabilities.
12. Tab 3 lists every active plan with its baseline cell count and live-tenant count.
13. Selecting the 50K plan shows **only** menus the 50K plan includes; a 100K-only menu is absent and the hidden-menu footer explains why.
14. Saving a baseline cell for a menu outside the plan is rejected with `MENU_NOT_IN_PLAN` **when posted directly to the API**, not merely hidden in the UI.
15. A plan with no baseline rows renders the empty-baseline warning.
16. **Provisioning a tenant on the 50K plan grants its `BUSINESSADMIN` exactly the 50K baseline — no 100K menu has a `RoleCapability` row.**
17. **Provisioning a tenant on a plan with an empty baseline fails at step 4 with a named error, and the run is not SUCCEEDED.**
18. Two tenants on the same plan receive identical capability rows.
19. Two tenants on different plans receive **different** capability rows.
20. Upgrading a tenant 50K → 100K creates the newly-entitled baseline rows; the new menus render with working permissions, not blank.
21. Downgrading a tenant deletes no `RoleCapability` row.
22. Tab 4's drift table flags a tenant missing baseline cells as `Missing N`, and a tenant with extra cells as `In sync` with the extras reported, not removed.
23. Push preview counts reconcile exactly with the execute result.
24. Re-running an identical push grants zero and reports every tenant `ALREADY_HAS`.
25. A tenant lacking the target role code is reported `ROLE_MISSING` and the run completes.
26. A push never sets any existing `HasAccess` to `false`.
27. `ops.RbacRolloutRuns` + `ops.RbacRolloutTargets` reconstruct a run completely, skips included.
28. Single-capability rollout (4.3) reports `BLOCKED_BY_PLAN` for a tenant whose plan excludes the menu, and grants it no row.
29. Tab 4b is read-only until override is explicitly enabled; an override without a ≥10-character reason is rejected.
30. An override writes one `audit.AuditLogs` row against **the target tenant** and one `ops.PlatformAuditLog` row.
31. A break-glass override granting a menu outside the tenant's plan is rejected with `MENU_NOT_IN_PLAN`.
32. Every command in §④ steps 11–15 writes exactly one `ops.PlatformAuditLog` row.
33. FE `npx tsc --noEmit --incremental false` exits 0.

---

## ⑨ Open questions

- **Q1 — invitation mechanism.** Reuse `ITenantActivationService`'s token + a new `PLATFORM_STAFF_INVITATION` email template, or route platform staff through the ordinary forgot-password flow? The former is a better first-run experience; the latter is near-zero build. **Default if unanswered: the activation-token path.**
- **Q2 — does a plan-change command exist?** §④ step 10 needs somewhere to hang the upgrade top-up. If nothing in the codebase changes a live tenant's `Subscription.PlanId` today, the top-up has no automatic trigger and every upgrade must be pushed by hand from tab 4 — acceptable short-term, but it must be *known*, not discovered by a customer. **Blocks the auto-top-up half of step 10; the rest of the prompt builds without it.**
- **Q3 — D5.** Does the `SUPERADMIN` role row have `CompanyId IS NULL`? If not, the 20 `SUPERADMIN` grants in `ops-platform-rbac-seed.sql` §5 inserted nothing and `SUPERADMIN` has no platform capabilities at all. **Blocks step 5 of the staff seed.**
  ```sql
  SELECT "RoleId","RoleCode","CompanyId","IsSystem","IsAssignable"
  FROM auth."Roles" WHERE "RoleCode" = 'SUPERADMIN' AND COALESCE("IsDeleted",false) = false;
  ```
- **Q4 — baseline scope beyond `BUSINESSADMIN`.** Tab 3 offers every template role code. Should provisioning *require* a baseline for every cloned role, or only for `BUSINESSADMIN` (other roles simply get nothing until someone configures them)? **Default if unanswered: require a baseline for `BUSINESSADMIN` only; other roles provision with whatever baseline rows exist, zero being legal for them.**
- **Q5 — the CUSTOM plan.** A per-tenant custom plan means a per-tenant baseline, which is exactly the thirty-matrices problem Rule 4 exists to prevent. Is CUSTOM one shared plan row, or one plan row per customer? If the latter, tab 3's plan list needs a filter and the "configure per plan" promise weakens. **Needs an answer before tab 3's plan selector is designed.**
- **Q6 — tenant-visible notice.** When the platform overrides a cell in a live tenant, should that tenant's admin see an in-app notification (PROMPT-22 machinery is built)? Transparent, but noisy during support calls. **Default if unanswered: no notification, audit row only.**
- **Q7 — `IsAssignable = false` on platform roles.** Seed step 2 flips it. Confirm nothing platform-side reads `IsAssignable` to populate the *platform* role picker — tab 1 must query by `IsPlatform`, or the picker comes back empty.

---

## ⑬ Deviations

Everything below is a place where the built code differs from §②–§⑤ as written. Where the prompt
was wrong about what is on disk it is marked **[prompt inaccurate]**; where a decision was taken
it is marked **[decision]**.

### Schema & entities

1. **[prompt inaccurate] `IApplicationDbContext` does not own the new `DbSet`s.** §④ step 3 says to add
   the three `ops` entities to `IApplicationDbContext`/`ApplicationDbContext`. The codebase splits the
   context by schema — the `ops` sets went on `IOpsDbContext` and the `billing` set on
   `IBillingDbContext`. The migration spec's §2 carries the same inaccuracy; the spec's DDL is correct,
   only its "where the DbSet goes" sentence is not.
2. **`User.PasswordHash` / `PasswordSalt` are non-nullable `byte[]`.** An invited operator has no
   credential yet, so the invite writes **empty arrays**, not nulls. `IsPendingInvitation = true` +
   `MustChangePassword = true` remain the real "cannot log in" gate. No hash is ever hand-written
   (Rule 8 holds).
3. **`LastLoginAt`, not `LastLoginDate`** — the prompt's column name for the staff list does not exist.
4. **`RbacRolloutTarget.CompanyId` is a plain `int` with no navigation**, following the existing
   `PlatformWebhookLog` precedent, because `ops` rows must not acquire an FK into a tenant-filtered table.
5. **[decision] `PlanRoleBaseline` edits are HARD deletes.** A baseline is configuration, not a record of
   anything that happened; a soft-deleted baseline row would silently re-appear in the unique-index
   guard and make "untick" un-doable. The audit trail lives in `ops.PlatformAuditLog`, not in tombstones.
6. **[prompt inaccurate] `GridFilterRequest` / `GridResult<T>` do not exist.** The paged reads use the
   codebase's actual request/response shapes. Likewise the `OpsSchemas` row DTOs are plain classes with
   setters, not records — matching every other DTO in that folder.

### D1 leak surface was wider than the prompt knew

7. **Four EXTRA D1 leak sites** beyond `GetRoleCapabilityMatrix` / `GrantCapabilityToAllRoles` /
   `GetRoles` / `GetNotificationRecipientOptions` were found and guarded with `IsPlatform == false`.
8. **`allowPlatformRoles` opt-in flag** added to the shared role read so the platform's own tabs can see
   platform roles through the same query the tenant surfaces use — one code path, one guard, default
   closed.
9. **The "is this a tenant caller" heuristic was corrected** to test the *role's* `CompanyId IS NULL`
   rather than the caller's, which is what actually distinguishes a platform role row.

### Baselines (tab 3)

10. **Baseline cells carry a synthetic `RoleId = 0`.** A baseline is keyed by `RoleCode`, not `RoleId` —
    it must survive across tenants that each have their own row for the same role. The matrix component
    speaks in `RoleId`, so the DTO carries 0 and the handler keys off `RoleCode`.
11. **`PlanRoleBaselineSaveDto` is a whole-set save** reusing `RoleCapabilityMatrixCellInputDto` rather
    than the per-cell shape the prompt sketched — the tab already holds the full matrix, and a whole-set
    save makes "untick" expressible without a delete verb.
12. **`HiddenMenuCount` added** to the baseline result beyond the prompt's stated shape, so an operator
    can see *"14 menus are not in this plan"* rather than silently editing a truncated matrix.
13. **A separate `GetPlanBaselineRoleOptions` query was added** — the role list for a baseline comes from
    the `__TEMPLATE__` role set, which is not any of the existing role queries' scope.
14. **The baseline reconcile is scoped to plan-visible menus**, so a menu outside the plan can never be
    written into a baseline even by a stale client payload.

### Rollout & push (tab 4)

15. **`auth.RoleCapabilities` has NO unique index.** Consequence, and it is deliberate: the rollout
    resolver treats **any** existing row as `ALREADY_HAS` — including `HasAccess = false` and
    soft-deleted rows. Inserting alongside them would create a duplicate that no query can disambiguate.
    A tenant who deliberately revoked a capability therefore does **not** get it back by a push, which is
    the correct reading of Rule 5.
16. **Tab 4b's *display* read excludes soft-deleted rows** whereas the rollout resolver counts them as
    occupancy. The asymmetry is intentional and is commented at both sites.
17. **Drift and preview results carry extra fields** (`BaselineCellCount`, `RoleMissingCount`) so the four
    summary tiles are server-computed rather than inferred client-side.
18. **§4.3's plan gate sits ABOVE the already-has test** — a menu not in the plan is rejected before we
    ask whether the tenant already holds it, so the error is `MENU_NOT_IN_PLAN` and not a silent skip.
19. **Tenant scope is driven by live `billing.Subscriptions`**, not by `Company.Status` — a suspended
    subscription is not a push target.
20. **Three new guards not in the prompt:** `BASELINE_EMPTY` (`ExecuteBaselinePush` refuses to run a push
    from a plan with no baseline rows — otherwise it reports "0 granted" and looks like success),
    `NO_TARGET_ROLES` (`ExecuteCapabilityRollout` refuses a role list that resolves to `SUPERADMIN` only,
    per INV-2), and `PLATFORM_MENU_NOT_ROLLABLE` (a control-plane menu can never be rolled into tenant
    roles — that would be D1 in reverse).
21. **`GetRolloutPreviewResult.TenantCount` counts DISTINCT companies** (a tenant with two matching roles
    is one tenant), and gained `RoleMissingCount`.
22. **Rollout-history sort keys are an explicit entity-backed whitelist**, not a passthrough string.
23. **[decision] Tab 4.3 targets ALL live tenants on the plan (`companyIds: null`).** Per-tenant selection
    is offered on the baseline-push half only, where the drift table makes the choice meaningful; for a
    brand-new capability there is no drift to select against.
24. **The typed-count confirm is applied to the capability rollout too**, not just the baseline push.

### Tenant override (tab 4b)

25. **Tab 4b's reads use `PLATFORM_STAFF_VIEW`, not `PLATFORM_TENANT_VIEW`** — the latter is not granted on
    the `PLATFORM_STAFF` menu, and a capability is menu-scoped.
26. **`TenantRoleMatrixResult` carries `PlanId` / `PlanCode` / `HiddenMenuCount`** so the support view shows
    *which* plan is constraining what the operator is looking at.
27. **Two refusals added:** `NO_LIVE_SUBSCRIPTION` (a tenant with no live subscription has no plan, so
    there is nothing to validate a grant against) and `ROLE_NOT_IN_TENANT`.
28. **`MENU_NOT_IN_PLAN` is enforced on grant only.** Revoking a capability the plan no longer covers must
    stay possible — that is exactly the cleanup a downgrade leaves behind.
29. **[decision] The override tab passes an always-empty dirty map into `PlatformMatrixPanel` and intercepts
    `onDirtyChange`** to open the reason dialog. `overrideTenantRoleCapability` is a **one-cell** mutation
    (one write, one audit row, INV-4); letting edits accumulate in the matrix would invite a bulk write
    into a customer's live RBAC, which is the thing this surface exists to prevent.
30. **The override reason has a client-side minimum of 5 characters** on top of the server validator.
31. **The tenant picker reuses `TENANTS_QUERY` with a flat `pageSize: 200`** rather than adding a lookup
    query; there is no server-side search on that picker.

### Wiring, seeds, components

32. **§④ step 17 ("register in the schema builder") is a no-op** — HotChocolate registers `IQueries` /
    `IMutations` by assembly scan.
33. **`MatrixToolbar` was deliberately NOT reused**; `PlatformMatrixToolbar` was written instead. Its
    tenant-shaped affordances (company switcher, tenant save semantics) have no meaning here.
34. **`MatrixGrid` gained two optional, default-off props** (`readOnly`, `hideContextMenus`) rather than
    being forked. Both default to the existing behaviour, so no tenant caller changes.
35. **`RolloutHistoryPanel` exposes an imperative `refresh()` handle** (`forwardRef` +
    `useImperativeHandle`) so an execute in either half of tab 4 refreshes history without the two panels
    sharing a query cache.
36. **`DisplayName` was dropped from `PlatformStaffUpdateDto`** — the underlying column is set at creation
    and not editable through this path, so the edit form hides the field rather than showing a control
    that silently does nothing.
37. **Two new seeded artefacts not named in §③:** the `PLATFORM_ADMIN_SUBDOMAIN` platform-global setting
    and the `PLATFORM_STAFF_INVITATION` email template (both in
    `sql-scripts-dyanmic/platform-staff-invitation-seed.sql`). The invite does **not** reuse
    `USER_WELCOME_INVITE` because that template mails a temporary password and `PlaceholderEngine` has no
    `{{#if}}` support, so the password paragraph cannot be suppressed per caller.

### Surface split — platform staff vs one tenant (session 3)

38. **[decision] The tenant override matrix left `/platform/staff`.** §② put it there as a fifth tab. It is
    now the **Access** tab of `/ops/tenants/{companyId}`. Rationale, from the user: mixing "who runs the
    platform" with "one customer's permissions" in a single screen is the confusion, and everything the
    platform knows about one customer belongs on that customer's page. `/platform/staff` is now four tabs
    (staff · platform role access · plan baselines · tenants & push) and contains nothing tenant-specific.
39. **[decision] A new menu, `PLATFORM_TENANT_ACCESS`, rather than reusing `PLATFORM_STAFF`.** The tab now
    lives under a different parent screen, so continuing to gate it on the staff menu would have meant
    "holds Staff & Access" implying "can rewrite any tenant's live RBAC". The new menu is seeded
    `IsVisible = false` — it is a capability container, not a sidebar entry — and carries two capabilities:
    the new `PLATFORM_TENANT_ACCESS_VIEW` (read the matrix) and the existing `PLATFORM_TENANT_RBAC_OVERRIDE`
    (write one cell), which was **re-parented** off `PLATFORM_STAFF`. Both server gates were changed to
    match. **Until `platform-tenant-access-menu-seed.sql` is applied, both operations refuse every caller,
    PLATFORM_ADMIN included** — this is a hard prerequisite, not a nicety.
40. **[decision] The tenant matrix now excludes platform roles, `SUPERADMIN` and `IsSystem` roles.** The
    columns are the tenant's OWN roles and nothing else: `r.CompanyId == tenant.CompanyId && !r.IsPlatform
    && r.IsSystem != true`. The write guard split accordingly into `SYSTEM_ROLE_NOT_OVERRIDABLE` and
    `ROLE_NOT_IN_TENANT`; `PLATFORM_ROLE_NOT_TENANT` and `SUPERADMIN_IMMUTABLE` are untouched (Rule 7).
41. **The tenant page became seven tabs** — Overview · Features · Usage · Payments · Provisioning · Audit ·
    Access. Two of them are pre-existing components that finally have a home: `TenantSubscriptionPanel`
    (Features) and `TenantUsagePanel` (Usage) moved off the flat scroll, and `tenant-gateway-activity.tsx`
    (Payments) was **built in an earlier session but never rendered anywhere** — it is now the Payments tab.
    Each panel keeps its own capability self-gate; the page only decides whether the tab is worth showing,
    so a partially-capable operator sees fewer tabs rather than empty ones.
42. **`provisioningRuns` gained an optional `companyId` argument.** It narrows **`baseQuery`**, before
    `filteredQuery` is derived, so the scoped `TotalCount` is honest and the tab's pager is correct. A real
    query argument, deliberately not an `advancedFilter`, for exactly that reason. The estate-wide monitor
    at `/ops/tenants/provisioning-runs` omits the variable and is unaffected (nullable `Int`).
43. **New read: `GetTenantAuditTrail` → gql `tenantAuditTrail`.** Not in §②. It answers "what did the vendor
    do to this account". `ops.PlatformAuditLog` has no `CompanyId` property — the column is
    `TargetCompanyId`, ordinary data — so the convention tenant filter never attaches and the handler
    guards explicitly: `IgnoreQueryFilters().Where(a => a.IsDeleted != true && a.TargetCompanyId == companyId)`.
    Rows with a NULL `TargetCompanyId` are platform-only actions and are correctly absent. `ChangesJson` is
    rendered verbatim behind a disclosure, which is safe only because the writer's contract forbids secrets
    in it.
44. **SUPERADMIN backfill across every platform menu (§5c of the tenant-access seed).** Two silent defects
    left SUPERADMIN without platform menu access, and neither is visible from the app. (a) Every SUPERADMIN
    grant in `ops-platform-rbac-seed.sql` §5 is joined `AND r."CompanyId" IS NULL`; if the SUPERADMIN row is
    not `CompanyId`-null (§⑨ Q3, still open) all ten inserted zero rows and the script still reported
    success — including `PLATFORM_TENANT_VIEW`, without which `/ops/tenants` does not open at all. (b) That
    block predates `PLATFORM_PLAN_VIEW`, the whole `PLATFORM_BILLING` menu, comms, webhooks and
    `PLATFORM_STAFF`; nothing ever granted SUPERADMIN any of them regardless of `CompanyId`. On the new
    tabbed tenant page that costs it Features / Usage / Payments. §5c grants SUPERADMIN the UNION of what
    every `PLATFORM_*` role holds plus every capability wired to a `PLATFORM`-module menu — derived from the
    data, not from a hand-kept list, so it stays correct as menus are added. Matched by `RoleCode` **alone**,
    additive and `NOT EXISTS`-guarded. ⚠ Rule 7 is untouched: it forbids taking authority away from
    SUPERADMIN, not restoring it.
45. **`PLATFORM_TENANT_ACCESS.MenuUrl` = `/ops/tenant-access`, not `/ops/tenants`.** First cut reused the
    tenant list's path on the reasoning that a hidden container owns no route. That was wrong: `MenuUrl` is
    the identity the nav builder and the sidebar active-state matcher key on, so two menus sharing one path
    are indistinguishable — the wrong item highlights and any url→menu lookup resolves to whichever row it
    reads first. It now has its own namespace. No Next.js route answers it and none is needed while
    `IsVisible = false`; the real surface is the `/ops/tenants/{companyId}` → Access tab. If the menu is ever
    made visible, the route must be added first. §1 of the seed carries a narrowly-scoped `UPDATE` to repair
    a database where the earlier version was already applied — the `INSERT` is `NOT EXISTS`-guarded on
    `MenuCode` and would not have corrected it.

---

## ⑭ Build log

### Session 1 — 2026-08-04 — §④ steps 1–24 COMPLETE (backend + frontend), NOT YET COMPILED

**Backend (steps 1–17).** `IsPlatform` on `Role` + configuration; `PlanRoleBaseline` under `billing` with
the 4-column unique index; the three `ops` entities (`PlanRoleBaseline` audit targets, rollout run +
target rows) with no tenant filter; `IPlanMenuScope` with the ancestor-walk helper extracted out of
`PlanMenuFilter` so both services share one walk. D1/D2 leak sites guarded (four more than the prompt
listed). `ProvisionTenant.Step4_SeedCapabilitiesAsync` §4a rewritten to read `billing.PlanRoleBaselines`
for the tenant's plan and to **throw** when the plan has no baseline (INV-13 — deliberately loud).
Commands: invite / update / deactivate platform staff, save plan baseline, execute baseline push, execute
capability rollout, override a tenant cell. Queries: staff list, platform role matrix, plan baseline
matrix, baseline role options, tenant drift, rollout preview, rollout history, tenant role matrix. Every
command writes exactly one `ops.PlatformAuditLog` row on both paths (INV-5), after its own
`SaveChangesAsync`, with no secret in `ChangesJson`; the tenant override additionally writes an
`audit.AuditLogs` row stamped with **that tenant's** `CompanyId` by explicit assignment on a new entity
(INV-4) — not raw SQL.

**Frontend (steps 18–23).** `src/app/[lang]/(master)/platform/staff/page.tsx` delegating to
`PlatformStaffPage`; five capability-filtered tabs under
`presentation/components/page-components/ops/platformstaff/` — staff, platform roles, plan baselines,
tenants & push (drift → select → preview → execute, order enforced; capability rollout + history beneath),
and the locked break-glass tenant override.

**Step 24 — typecheck: `npx tsc --noEmit --incremental false` → EXIT 0.** Clean, zero errors.

**NOT done, by rule:** no `dotnet build`, no `dotnet ef migrations add`. The backend has not been compiled;
the migration spec is handed to the user in
`PSS-2.0-ONBOARDING-PROMPT-24-MIGRATION-SPEC.md`.

**Seeds written, awaiting the user:**
- `sql-scripts-dyanmic/platform-staff-rbac-seed.sql` — menu, five capabilities, grants, `IsPlatform` /
  `IsAssignable` flips, D5 verification query at the foot.
- `sql-scripts-dyanmic/plan-role-baseline-bootstrap-seed.sql` — per-plan `BUSINESSADMIN` baseline bootstrap.
- `sql-scripts-dyanmic/platform-staff-invitation-seed.sql` — `PLATFORM_ADMIN_SUBDOMAIN` setting +
  `PLATFORM_STAFF_INVITATION` template.

**Apply order:** migration → `platform-staff-rbac-seed` → `platform-staff-invitation-seed` →
`plan-role-baseline-bootstrap-seed` (last: it needs the migration's `billing.PlanRoleBaselines` table and
reads plan entitlements).

**Open questions still unanswered — Q3 (D5) and Q5.** Q3 blocks step 5 of the staff seed: if
`SUPERADMIN`'s row is not `CompanyId IS NULL`, its 20 platform grants inserted nothing and it has no
platform capabilities at all. Q1 / Q4 / Q6 / Q7 were built on their recorded defaults.

**Known issues:** none observed; nothing has been run.

### Session 2 — 2026-08-04 — two reported defects fixed

**1. The module loader never cleared after navigating to PLATFORM.** The full-screen `<ModuleLoader>`
(`isModuleLoading`) is raised by the *navigator* — `module-navigator-item.tsx handleNavigate` and
`menu-item.tsx` — and lowered by the *destination*. Only three things ever lower it: the generic dashboard
component (`dashboards/index.tsx:289`), the generic advanced/flow data-tables, or a hand-written effect in a
page component. A grep of `page-components/ops/` for `setModuleLoading|setIsMenuRendering` returned **zero**
hits, and `(master)/platform/dashboards/page.tsx` is by design a FIXED coded dashboard using none of the
three — so the scrim sat on top of a page that had already rendered correctly. Fixed in two layers:

- `platform-dashboard-page.tsx` clears both scrims once the `platformSnapshot` query has **settled**,
  success or failure (an error state is finished content too; leaving the scrim up would hide the message).
- `dashboard-layout-provider.tsx` gained a **commit-gated 4 s backstop + 20 s absolute ceiling** for
  `isModuleLoading`, mirroring what `isMenuRendering` already had. Commit-gated because in dev the
  destination segment must compile first (*"Compiling /[lang]/platform/dashboards"*) and a naive timer
  would drop the scrim mid-compile. Destination-clears-it stays the primary path; this only rescues
  custom-coded screens that emit no ready signal — which covers the sibling `(master)/platform/*` screens
  (staff, billing, gateways, communications, webhook-logs) reached from the sidebar.

Re-verified: `npx tsc --noEmit --incremental false` in `PSS_2.0_Frontend` → **EXIT 0**.

**2. `SUPERADMIN` had no `PLATFORM_STAFF` access.** Correct — it must. `platform-staff-rbac-seed.sql` §6
now grants `SUPERADMIN` all five new capabilities on the `PLATFORM_STAFF` menu, as a **separate** insert
from §5 that joins on `RoleCode = 'SUPERADMIN'` **alone** (plus `COALESCE(IsDeleted,false) = false`) with
no `CompanyId IS NULL` predicate — so it lands whether or not D5 turns out to be true, instead of blocking
on Q3. Additive and `NOT EXISTS`-guarded; nothing is revoked, so Rule 7 (`SUPERADMIN` is immutable) holds —
that rule forbids revoking, not granting.

Q3 is still worth answering, for a different reason now: if `SUPERADMIN` is **not** `CompanyId`-null then
the 20 grants in the older `ops-platform-rbac-seed.sql` §5 silently inserted zero rows and `SUPERADMIN`
holds no *other* platform capability either. Verification queries 5 and 5b at the foot of the staff seed
answer both halves.

### Session 3 — 2026-08-04 — surface split: platform staff vs the tenant hub

**Why.** The user: *"staff & access menu only [for] whole platform staff and their access only, tenant
level access should [be] in the tenant view"* … *"don't combine platform staff and tenant staff — it
creates the confusion"*. So platform-side surfaces stay on `/platform/staff`, and everything about one
customer moves onto `/ops/tenants/{companyId}`, which is now tabbed.

**Backend (unbuilt — no `dotnet build`, no migration; none is needed, this change is seed-only).**
- `GetTenantRoleMatrix` — regated `[CustomAuthorize("PLATFORM_TENANT_ACCESS", "PLATFORM_TENANT_ACCESS_VIEW")]`;
  role filter narrowed to the tenant's own non-platform, non-system roles. `ResolveTenantAsync` / `BuildAsync`
  made `internal static` and shared with the override command so both agree on what a "tenant role" is.
- `OverrideTenantRoleCapability` — regated `("PLATFORM_TENANT_ACCESS", "PLATFORM_TENANT_RBAC_OVERRIDE")`;
  guards split into `SYSTEM_ROLE_NOT_OVERRIDABLE` / `ROLE_NOT_IN_TENANT`.
- `GetProvisioningRuns` — `int? companyId = null` on the query record and the endpoint; narrows `baseQuery`.
- **New** `Schemas/OpsSchemas/PlatformAuditSchemas.cs` (`TenantAuditRowDto`),
  `PlatformAudit/Queries/GetTenantAuditTrail.cs`, and `EndPoints/Ops/Queries/PlatformAuditQueries.cs`
  (picked up by the `IQueries` assembly scan; gql field `tenantAuditTrail`, `Get` stripped).

**Frontend.**
- `platform-staff-page.tsx` — the "Tenant override" tab is gone, `"Platform roles"` renamed
  **"Platform role access"**; four tabs remain. `tenant-override-tab.tsx` **deleted** (its only external
  reference was the folder barrel).
- **New** `ops/tenants/tenant-access-tab.tsx` — the relocated matrix, minus the tenant picker (companyId is
  a prop), gated on `PLATFORM_TENANT_ACCESS`, still read-only behind the "Enable override" switch and still
  one cell + one reason + one audit row per write.
- **New** `ops/tenants/tenant-provisioning-tab.tsx` — this tenant's runs, reusing the monitor's own
  `RunStatusChip` / `RunProgress` / `formatStamp` so a run reads identically from either door.
- **New** `ops/tenants/tenant-audit-tab.tsx` + `PlatformAuditDto.ts` + `PlatformAuditQuery.ts` — read-only,
  newest-first, searchable, `changesJson` behind a disclosure.
- `tenant-detail-page.tsx` — flat scroll → seven tabs; `ops/tenants/index.ts` exports the three new panels.

**Typecheck: `npx tsc --noEmit --incremental false` → EXIT 0.**

**Seed written, awaiting the user — `sql-scripts-dyanmic/platform-tenant-access-menu-seed.sql`:** the
invisible `PLATFORM_TENANT_ACCESS` menu (parent `PLATFORMCONTROLPLANE`, OrderBy 955, `MenuUrl`
`/ops/tenant-access` — see deviation 45), the new
`PLATFORM_TENANT_ACCESS_VIEW` capability (OrderBy 104), `MenuCapabilities` for both capabilities, a backfill
of the four `PLATFORM_STAFF` `MenuCapabilities` rows that were missing, grants to ADMIN / SUPPORT /
IMPLEMENTATION, `SUPERADMIN` by `RoleCode` alone (same Q3-proof shape as session 2), and an `EXISTS`-guarded
soft-delete of the now-stale `PLATFORM_STAFF × PLATFORM_TENANT_RBAC_OVERRIDE` grant — nobody is retired off
the old gate without already holding the new one. **Apply it before testing:** until then both regated
operations refuse every caller.

**No migration for this session.** No entity, column or index changed.

**Follow-up the same day — §5c, SUPERADMIN's platform menu access.** The user: *"super admin role missed in
that script for menu access"*. §5b of the new seed did already cover SUPERADMIN for the two capabilities
this script introduces, so the report pointed at something older and wider. There is no `RoleMenus` table —
menu access **is** `auth."RoleCapabilities"`, so a missing grant is a missing menu. Reading
`ops-platform-rbac-seed.sql` §5 found SUPERADMIN's block malformed: duplicated copy-paste tuples, only
`PLATFORM_LEADS` / `PLATFORM_TENANTS` / `PLATFORM_PLANS` (`PLATFORM_PLAN_EDIT` but **not**
`PLATFORM_PLAN_VIEW`) / `PLATFORM_AUDIT`, **no `PLATFORM_BILLING_MANAGE` at all**, and the whole insert
joined `AND r."CompanyId" IS NULL` — so if Q3 resolves "not null", even those landed nowhere and SUPERADMIN
cannot open `/ops/tenants`. §5c backfills the union of every `PLATFORM_*` role's grants plus every
`PLATFORM`-module `MenuCapabilities` pair, matching SUPERADMIN by `RoleCode` alone. VERIFY queries 6 and 7
added; 7 must return zero rows after the run. See §⑬ deviation 44. `Roles.IsPlatform` is deliberately not
used as the source — that column's migration is still unapplied.

**Open questions still unanswered — Q3 (D5) and Q5.**
