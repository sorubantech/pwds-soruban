# PROMPT-24 — Migration Spec (user-owned)

**Suggested name:** `Add_PlatformStaffRbacAdmin`
**Scope:** 1 new column on `auth.Roles` · 1 new table in `billing` · 3 new tables in `ops`.
**Applies to:** `PSS-2.0-ONBOARDING-PROMPT-24-PLATFORM-STAFF-AND-RBAC-ADMIN.md`
**Written:** 2026-08-04 · **Revised 2026-08-04 (v2)** — adds `billing.PlanRoleBaselines` and reshapes the two rollout tables for the plan-baseline model (PROMPT-24 §① / D6).

> I do not run `dotnet ef migrations add` / `database update` and I do not hand-author migration or snapshot files. This document is the specification. You generate, review, and apply the migration.

---

## 1. Run it

```bash
cd PSS_2.0_Backend
dotnet ef migrations add Add_PlatformStaffRbacAdmin -p Base.Infrastructure -s Base.API
# review the generated Up()/Down() against §3-§4 below
dotnet ef database update -p Base.Infrastructure -s Base.API
```

Order relative to other pending migrations: **after** `20260729062510_Add_PlatformCommunicationProvider` and PROMPT-22's notification migration. It touches nothing they touch, so ordering is a convenience, not a dependency.

---

## 2. Entity changes the migration must pick up

Before generating, confirm these are in the tree and compile:

| File | Change |
|---|---|
| `Base.Domain/Models/AuthModels/Role.cs` | `public bool IsPlatform { get; set; }` |
| `Base.Infrastructure/Data/Configurations/AuthConfigurations/RoleConfiguration.cs` | `builder.Property(x => x.IsPlatform).IsRequired().HasDefaultValue(false);` |
| `Base.Domain/Models/BillingModels/PlanRoleBaseline.cs` | new |
| `Base.Infrastructure/Data/Configurations/BillingConfigurations/PlanRoleBaselineConfiguration.cs` | new |
| `Base.Domain/Models/OpsModels/RbacRolloutRun.cs` | new |
| `Base.Domain/Models/OpsModels/RbacRolloutTarget.cs` | new |
| `Base.Domain/Models/OpsModels/PlatformAuditLog.cs` | new |
| `Base.Infrastructure/Data/Configurations/OpsConfigurations/` | one configuration per new entity |
| `Base.Application/Common/Interfaces/IApplicationDbContext.cs` + `ApplicationDbContext.cs` | `DbSet<PlanRoleBaseline>`, `DbSet<RbacRolloutRun>`, `DbSet<RbacRolloutTarget>`, `DbSet<PlatformAuditLog>` |

All four entities inherit `Entity` (so they carry `IsActive`, `IsDeleted`, `CreatedBy`, `CreatedDate`, `ModifiedBy`, `ModifiedDate`), and **none of them carries `CompanyId` as a tenant discriminator** — they are platform-global, like `Lead` and `TenantProvisioningRun`. `TargetCompanyId` / `CompanyId` on the child tables are *data*, not tenancy. Make sure the global tenant query filter is **not** applied to these four entity types, or every platform read will silently return zero rows. `billing.PlanRoleBaselines` in particular is keyed on **plan**, not company — a stray tenant filter there makes the whole baseline screen render empty for everyone.

---

## 3. Column: `auth.Roles.IsPlatform`

```sql
ALTER TABLE auth."Roles"
    ADD COLUMN "IsPlatform" boolean NOT NULL DEFAULT false;
```

**Why a new column instead of reusing `IsSystem`:** `SYSTEMROLE` and `SUPERADMIN` are also `IsSystem = true` and must remain visible to tenant surfaces. `IsSystem` therefore cannot distinguish "platform-owned role" from "product-owned role". Without `IsPlatform`, the five `PLATFORM_*` roles keep leaking into every tenant's role-capability matrix and role pickers (defects D1 / D2 in the prompt).

**The migration must not backfill.** `DEFAULT false` is correct for every existing row; the five platform roles are flipped to `true` by `sql-scripts-dyanmic/platform-staff-rbac-seed.sql`, which is applied separately and is guarded/idempotent.

No index. The predicate is always combined with `CompanyId` / `IsDeleted`, and the table is small.

---

## 4. Tables

Nullability below is exact — please check the generated migration matches, particularly the nullable FK columns.

### 4.0 `billing.PlanRoleBaselines` ★ new in v2

The heart of the revised prompt: **one row per (plan, role code, menu, capability)**. This replaces the `__TEMPLATE__` company's `RoleCapability` rows as the source provisioning copies from. Flat by design — there is no header/parent table, because "which cells does plan X grant role Y" is fully expressed by the rows themselves, and a header would only add a second thing to keep in step.

| Column | Type | Null | Notes |
|---|---|---|---|
| `PlanRoleBaselineId` | `integer` | no | PK, identity |
| `PlanId` | `integer` | no | FK → `billing."Plans"`, `Restrict` |
| `RoleCode` | `varchar(50)` | no | e.g. `BUSINESSADMIN`. **Code, not `RoleId`** — see below |
| `MenuId` | `integer` | no | FK → `auth."Menus"`, `Restrict` |
| `CapabilityId` | `integer` | no | FK → `auth."Capabilities"`, `Restrict` |
| `HasAccess` | `boolean` | no | default `true` |
| *(Entity base columns)* | | | `IsActive`, `IsDeleted`, `CreatedBy`, `CreatedDate`, `ModifiedBy`, `ModifiedDate`. `ModifiedDate`/`ModifiedBy` are what the screen shows as "last edited" |

Indexes:
- `UX_PlanRoleBaselines_Plan_Role_Menu_Capability` — **UNIQUE** on `("PlanId", "RoleCode", "MenuId", "CapabilityId")`. This is what makes the bootstrap seed and every push idempotent.
- `IX_PlanRoleBaselines_PlanId_RoleCode` on `("PlanId", "RoleCode")` — the screen's read path.

**Why `RoleCode` and not `RoleId`:** every tenant has its *own* `BUSINESSADMIN` row with its own `RoleId` (20 tenants = 20 `RoleId`s for one concept). A baseline is about the concept, not any one tenant's row, so the only stable key is the code — exactly as `ProvisionTenant` Step 4a already matches template roles to new roles by `RoleCode`. There is deliberately **no** FK on this column.

**The unique index and soft delete:** because `IsDeleted` is not part of the key, a "deleted" baseline row blocks re-inserting the same cell. Treat baseline edits as **hard deletes** in the save handler (remove the row when a cell is unticked) rather than soft — a baseline is configuration, not a business record, and it has no audit obligation of its own (`ops.PlatformAuditLog` carries that). If you prefer soft delete, the unique index must include `"IsDeleted"`; pick one and tell me which, because the seed's `NOT EXISTS` guard has to match.

### 4.1 `ops.RbacRolloutRuns`

One row per executed push — either a whole-baseline push or a single-capability rollout. **Revised in v2:** `RunKind` + `PlanId` added; `MenuId` / `CapabilityId` become nullable because a baseline push targets neither one menu nor one capability.

| Column | Type | Null | Notes |
|---|---|---|---|
| `RbacRolloutRunId` | `integer` | no | PK, identity |
| `RunKind` | `varchar(20)` | no | ★ v2. `BASELINE_PUSH` \| `SINGLE_CAPABILITY` |
| `PlanId` | `integer` | **yes** | ★ v2. FK → `billing."Plans"`, `Restrict`. Set for `BASELINE_PUSH`, null for `SINGLE_CAPABILITY` |
| `MenuId` | `integer` | **yes** | ⚠ was NOT NULL in v1. FK → `auth."Menus"`, **no cascade** (`Restrict`). Set only for `SINGLE_CAPABILITY` |
| `CapabilityId` | `integer` | **yes** | ⚠ was NOT NULL in v1. FK → `auth."Capabilities"`, `Restrict`. Set only for `SINGLE_CAPABILITY` |
| `RoleCodesCsv` | `varchar(500)` | no | target role codes, comma-separated, as chosen at run time |
| `TargetScope` | `varchar(20)` | no | `ALL` \| `SELECTED` |
| `TenantCount` | `integer` | no | |
| `GrantedCount` | `integer` | no | |
| `SkippedCount` | `integer` | no | |
| `Note` | `varchar(500)` | yes | operator's free text |
| `ExecutedByUserId` | `integer` | yes | FK → `auth."Users"`, `Restrict`. Nullable so a deactivated staff row can still be soft-handled |
| `ExecutedByUserName` | `varchar(150)` | no | denormalised — the run record must survive the user row |
| `ExecutedAt` | `timestamp with time zone` | no | |
| *(Entity base columns)* | | | `IsActive`, `IsDeleted`, `CreatedBy`, `CreatedDate`, `ModifiedBy`, `ModifiedDate` |

Indexes: `IX_RbacRolloutRuns_ExecutedAt` on `("ExecutedAt" DESC)`; `IX_RbacRolloutRuns_PlanId` on `("PlanId")`.

`RoleCodesCsv` is deliberately denormalised. The run is a historical record; if a role code is later renamed, the record must still show what was targeted at the time.

**Nullability change is free.** The v1 spec was never generated or applied, so `MenuId` / `CapabilityId` go straight in as nullable — there is no existing data and no `ALTER COLUMN … DROP NOT NULL` step. If you *did* already apply a v1 migration, tell me and I will spec the alter instead.

Application-layer rule the schema cannot express: `RunKind = 'BASELINE_PUSH'` ⟹ `PlanId` not null and `MenuId`/`CapabilityId` null; `RunKind = 'SINGLE_CAPABILITY'` ⟹ the reverse. A `CHECK` constraint would encode it, but EF will not generate one and hand-adding it to a generated migration is exactly the hand-authoring I don't do — enforce it in the handler and leave the schema permissive.

### 4.2 `ops.RbacRolloutTargets`

One row per (run × tenant × role), **including skips**. A rollout that cannot be reconstructed row by row is worse than no rollout.

**Not one row per cell.** A baseline push across 200 tenants touches tens of thousands of (menu, capability) cells; writing one audit row each would make the history table larger than the data it describes. `GrantedCellCount` carries the volume instead.

| Column | Type | Null | Notes |
|---|---|---|---|
| `RbacRolloutTargetId` | `integer` | no | PK, identity |
| `RbacRolloutRunId` | `integer` | no | FK → `ops."RbacRolloutRuns"`, **`Cascade`** |
| `CompanyId` | `integer` | no | FK → `app."Companies"`, `Restrict`. Data, not tenancy |
| `CompanyName` | `varchar(200)` | no | denormalised, same reason as above |
| `RoleId` | `integer` | yes | null when `Outcome = ROLE_MISSING`. FK → `auth."Roles"`, `Restrict` |
| `RoleCode` | `varchar(50)` | no | |
| `Outcome` | `varchar(30)` | no | `GRANTED` \| `ALREADY_HAS` \| `BLOCKED_BY_PLAN` \| `ROLE_MISSING` \| `FAILED` |
| `GrantedCellCount` | `integer` | no | ★ v2. How many `RoleCapability` rows this tenant/role actually received. `0` for every non-`GRANTED` outcome. Always `0` or `1` for a `SINGLE_CAPABILITY` run |
| `Reason` | `varchar(500)` | yes | populated for `BLOCKED_BY_PLAN` / `FAILED` |
| *(Entity base columns)* | | | as above |

Index: `IX_RbacRolloutTargets_RbacRolloutRunId` on `("RbacRolloutRunId")`.

Cascade is intentional here and **only** here — a target row is meaningless without its run. Nothing in the application deletes runs; the cascade exists so a manual cleanup cannot orphan rows.

### 4.3 `ops.PlatformAuditLog`

Platform-scope audit. `audit.AuditLogs` cannot serve: its `CompanyId` is non-nullable and auto-stamped by `TenantSaveChangesInterceptor`, and platform actions have no tenant.

| Column | Type | Null | Notes |
|---|---|---|---|
| `PlatformAuditLogId` | `bigint` | no | PK, identity. `bigint` — this table is append-only and never pruned |
| `ActionType` | `varchar(60)` | no | e.g. `PLATFORM_STAFF_INVITED`, `PLATFORM_ROLE_MATRIX_UPDATED`, `TENANT_TEMPLATE_UPDATED`, `RBAC_ROLLOUT_EXECUTED`, `TENANT_RBAC_OVERRIDDEN` |
| `EntityType` | `varchar(60)` | no | e.g. `User`, `Role`, `RoleCapability`, `RbacRolloutRun` |
| `EntityId` | `integer` | yes | |
| `TargetCompanyId` | `integer` | yes | set only when the action touched one specific tenant. FK → `app."Companies"`, `Restrict` |
| `Description` | `varchar(1000)` | no | human-readable one-liner |
| `ChangesJson` | `text` | yes | before/after payload; `jsonb` is acceptable if you prefer — nothing queries inside it today |
| `Reason` | `varchar(500)` | yes | mandatory at the application layer for break-glass overrides (≥10 chars), nullable in the schema because most actions have none |
| `ActorUserId` | `integer` | yes | FK → `auth."Users"`, `Restrict` |
| `ActorUserName` | `varchar(150)` | no | denormalised |
| `IpAddress` | `varchar(64)` | yes | v6-safe width |
| `Timestamp` | `timestamp with time zone` | no | |
| *(Entity base columns)* | | | as above |

Indexes:
- `IX_PlatformAuditLog_Timestamp` on `("Timestamp" DESC)`
- `IX_PlatformAuditLog_TargetCompanyId_Timestamp` on `("TargetCompanyId", "Timestamp" DESC)`
- `IX_PlatformAuditLog_ActionType` on `("ActionType")`

This table is what the already-seeded but empty `PLATFORM_AUDIT` menu (`/ops/audit`) will eventually read. PROMPT-24 writes the rows; the reading screen is a later prompt.

---

## 5. Down()

Straight reversal — drop the four tables (targets before runs, because of the FK; `billing."PlanRoleBaselines"` is independent and can go in any order), then drop `auth."Roles"."IsPlatform"`. Nothing else in the schema references any of them.

⚠ **Rolling back after the new provisioning code has shipped breaks tenant creation.** Once `ProvisionTenant` Step 4 reads `billing.PlanRoleBaselines` (PROMPT-24 §④ step 9), dropping that table makes every provisioning run fail at step 4. Roll the application back first, then the migration.

Note that `Down()` **will not** restore `IsAssignable = true` on the five platform roles, because seed step 2 of `platform-staff-rbac-seed.sql` sets it to `false` outside the migration. If you ever roll this back, re-run that `UPDATE` in reverse manually — otherwise the platform roles stay hidden from `GetRoles`, which is harmless but surprising.

---

## 6. After applying

1. Apply `sql-scripts-dyanmic/platform-staff-rbac-seed.sql` (menu + 5 capabilities + grants + the `IsPlatform` / `IsAssignable` flips). Without it, `IsPlatform` is `false` everywhere, D1 and D2 remain live, and the new screen has no menu entry.
2. Apply `sql-scripts-dyanmic/plan-role-baseline-bootstrap-seed.sql`. **This one is not optional.** Until it runs, every plan's baseline is empty, and with the new Step 4 in place that means *provisioning a tenant fails* (PROMPT-24 INV-13). Apply it before the next tenant is created, and read its per-plan row counts — a plan reporting `0` will still fail.
3. Restart the API (capability and menu caches).
4. Run the D5 verification query from PROMPT-24 §⑨ Q3 and tell me the result — it decides whether step 5 of the seed needs adjusting:
   ```sql
   SELECT "RoleId","RoleCode","CompanyId","IsSystem","IsAssignable"
   FROM auth."Roles" WHERE "RoleCode" = 'SUPERADMIN' AND COALESCE("IsDeleted",false) = false;
   ```
5. Sanity check the leak fix:
   ```sql
   -- expect exactly 5 rows, all with CompanyId NULL
   SELECT "RoleCode","CompanyId","IsPlatform","IsAssignable"
   FROM auth."Roles" WHERE "IsPlatform" = true;
   ```
6. Sanity check the baselines — **every active plan must have a non-zero count**, or provisioning on that plan will fail:
   ```sql
   SELECT p."PlanCode", b."RoleCode", COUNT(*) AS baseline_cells
   FROM billing."Plans" p
   LEFT JOIN billing."PlanRoleBaselines" b
          ON b."PlanId" = p."PlanId" AND COALESCE(b."IsDeleted",false) = false
   WHERE COALESCE(p."IsDeleted",false) = false AND p."IsActive" = true
   GROUP BY p."PlanCode", b."RoleCode"
   ORDER BY p."PlanCode", b."RoleCode";
   ```
