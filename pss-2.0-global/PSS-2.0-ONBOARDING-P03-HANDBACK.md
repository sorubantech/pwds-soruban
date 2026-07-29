# PSS-2.0 · P-03 — Tenant Provisioning Engine · HAND-BACK

**Status:** ✅ Complete. Backend command logic + seed scripts only (as scoped). Build proven: `dotnet build Base.Application/Base.Application.csproj` → **0 Errors** (575 warnings, all pre-existing). No GraphQL/mutation/resolver/UI (that is P-04). No migration authored/run. No SQL executed against any DB.

---

## 1. Deliverables

| Task | Artifact | Notes |
|------|----------|-------|
| **T-A6** | `Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs` | `ProvisionTenantCommand : ICommand<ProvisionTenantResult>` + handler + 9-step idempotent/resumable engine. Gated `[CustomAuthorize("PLATFORM_TENANTS","PLATFORM_TENANT_PROVISION")]`. |
| **T-A7** | (same file) `ProvisionTenantCommandValidator` | Subdomain FluentValidation only. **No column added** — `Company.Subdomain` already exists. |
| **T-A8** | (same file) Step 8 | No-password single-use hashed activation token minted inside the CREATE_ADMIN step. |
| **T-A9** | `sql-scripts-dyanmic/ops-platform-rbac-seed.sql` | Idempotent PLATFORM_* module / menus / capabilities / roles / role-capability bundles. |
| **T-A10** | `Base.Application/.../Commands/AbandonProvisioningRun.cs` | `AbandonProvisioningRunCommand : ICommand<AbandonProvisioningRunResult>`. Pre-step-8 cleanup only; hard-blocks once a UserRole exists. Gated `[CustomAuthorize("PLATFORM_TENANTS","PLATFORM_TENANT_SUSPEND")]`. |

Both commands are exposed as plain `ICommand<T>` — **P-04 owns the mutation/resolver layer** that will call them and supply HTTP/user context.

---

## 2. The 9-step engine

Each step runs in **its own transaction** via `Database.CreateExecutionStrategy()` + `BeginTransactionAsync`, records its own `ops.TenantProvisioningRunStep`, and is **skipped on resume if already SUCCEEDED**. The run row moves `PENDING → RUNNING → (SUCCEEDED | PAUSED_ON_ERROR)`.

| # | Code | Action |
|---|------|--------|
| 1 | CREATE_COMPANY | Insert `app.Company` (Status = `PROVISIONING`, never flipped to ACTIVE here — that's P-06). |
| 2 | CREATE_SUBSCRIPTION | `IPlanPricingService.ResolveAsync(PlanCode, CurrencyId, BillingCycle, ct)` → **snapshot** CurrencyId + Amount + BillingCycle + PaymentGatewayCode onto the Subscription. **Fail-closed** (see §4). |
| 3 | SEED_ROLES | Clone template roles; fallback creates `BUSINESSADMIN`. |
| 4 | SEED_CAPABILITIES | Clone template RoleCapabilities (RoleCode remap) + entitlement-gated RoleModule grants. |
| 5 | SEED_MASTERDATA | Clone MasterDataType then MasterData (roots first, remap type+parent). |
| 6 | SEED_SETTINGS | Clone OrganizationSetting + NumberSequenceConfig (LastSequence = 0). |
| 7 | SEED_FIELDS | Clone Field then GridField (remap FieldId). |
| 8 | CREATE_ADMIN | Create User (no password, `Array.Empty<byte>()`), UserRole, + mint activation token. |
| 9 | SEND_WELCOME | `IEmailTemplateService.SendEmailByTemplateKeyAsync(..., "USER_WELCOME_INVITE", ...)`. Lead-stamp is a documented no-op. |

**Idempotency key:** `LEAD:{LeadId}|CODE:{CompanyCode}` (or `CODE:{CompanyCode}` when LeadId is null). Cloned from the `__TEMPLATE__` company (a zero-row shell — cloning zero rows is a safe no-op).

---

## 3. Design deviations & decisions (READ BEFORE P-04)

1. **Subscription snapshots `CurrencyId` (int FK), not a `Currency` ISO string.** The real `Subscription` entity carries `int? CurrencyId` + `Currency` nav + `Amount` / `BillingCycle` / `PaymentGatewayCode`. This matches `IPlanPricingService.PriceResolution(Amount, CurrencyId, CurrencyCode, BillingCycle, Source)`. The DTO takes **`CurrencyId` (int)**, not an ISO code.

2. **Currency fail-closed.** If `ResolveAsync` returns `null`, step 2 throws → run goes `PAUSED_ON_ERROR` with `ErrorMessage = "no price for {PlanCode} in currencyId {CurrencyId}/{BillingCycle}"`. **No silent base-currency fallback.**

3. **`ICurrentUserService` does not exist in the codebase.** `InitiatedByUserId` is set to `null`; the P-04 mutation layer captures the acting user from HTTP context and should populate it.

4. **`CustomAuthorizeService.HasAccessAsync` checks only `RoleCapability`** (join UserRole → Menu → Capability, `HasAccess = true`) — it does **not** consult `MenuCapability`. So the T-A9 seed only creates RoleCapability rows; no MenuCapability rows are needed for the auth check.

5. **PLATFORM_* is fully bundled** in the T-A9 seed (module + 5 menus + 10 capabilities + 5 roles + 20 grants). Binding real internal users to these roles (`auth.UserRoles`) is deliberately **not** seeded — it's an operational step for P-04 / A-14.

6. **Template zero-row clone + BUSINESSADMIN fallback.** All clone steps tolerate a zero-row `__TEMPLATE__`. Step 3 creates a `BUSINESSADMIN` role if the template has none; steps 4/8 resolve the admin role as BUSINESSADMIN-preferred, else first role.

7. **Only the `ADMIN` module is seeded in a fresh DB.** Step 4's RoleModule grant loop queries `auth.Modules` and skips unknown ModuleCodes (no-op-safe). Until more modules are seeded, only ADMIN-mapped grants land.

8. **`IgnoreQueryFilters()` everywhere for platform/null-tenant context.** Platform callers have `CurrentTenantId == null`; the global filter is read-only. Every cross-tenant read uses `.IgnoreQueryFilters()` + an explicit `IsDeleted != true` guard; every written tenant row sets `CompanyId` explicitly.

9. **`PasswordReset` PK is `Id`** (not `PasswordResetId`) and it does **not** extend `Entity` (no `IsDeleted`). Token existence checks have no soft-delete guard — correct as written.

10. **`Company` lives in the `app` schema** (`app."Companies"`); Modules/Menus/Capabilities/Roles/RoleCapabilities are `auth`; provisioning-run tables are `ops`; Countries are `com`. Watch schema prefixes when writing SQL.

11. **Activation token is minted, but no endpoint consumes it yet.** The password-set / activation endpoint is **P-04**. No password is ever generated, emailed, or displayed.

---

## 4. Schema / migration note

**No schema change is required by P-03.** `Company.Subdomain` already exists. The only DDL that *might* be warranted is a **UNIQUE index on `Company.Subdomain`** to back the validator's uniqueness rule — but the validator enforces uniqueness at the application layer regardless, and if the column/index already exists this is a no-op.

Per the standing constraint, **migrations are user-owned**: I have not run `dotnet ef migrations add`/`database update`/`remove`, and have not hand-authored a migration or model-snapshot. If you (the user) decide the DB-level unique index is wanted as a hard guarantee, add a migration for a single unique index on `app."Companies"("Subdomain")` (filtered on `IsDeleted = false` if partial-index support is desired). Otherwise no migration is needed.

---

## 5. To apply the seed

`sql-scripts-dyanmic/ops-platform-rbac-seed.sql` is idempotent (`BEGIN/COMMIT`, every `INSERT` guarded by `NOT EXISTS` on the natural code key). **The user applies it** — I do not execute SQL. Verify block is included at the bottom of the script (expect 1 module / 5 menus / 10 capabilities / 5 roles / 20 grants; provision-capable roles = `PLATFORM_IMPLEMENTATION`, `PLATFORM_ADMIN`).

---

## 6. Explicitly NOT done (out of scope — later prompts)

GraphQL/mutation/resolver/UI (P-04) · `ops.Lead` / `ops.CommercialTerm` entities (LeadId/CommercialTermId kept as nullable ints, no FK) · flipping `Company.Status` to ACTIVE / go-live (P-06) · impersonation logic · audit-event emission · suspend/offboard · binding internal users to PLATFORM_* roles.
