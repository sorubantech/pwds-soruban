# DEV PROMPT P-03 — Tenant provisioning engine (`ProvisionTenantCommand` + 9 steps)

> Paste everything below the line into a **fresh development session**. It is self-contained.
> When done, report back the outcome to the PM session; do **not** proceed to P-04.

---

## Role & mission

You are a Senior Backend Developer on the PSS 2.0 multi-tenant .NET platform (**target framework `net10.0`**). Your task is **P-03: build the tenant-provisioning engine** — the `ProvisionTenantCommand` MediatR handler that turns an approved deal into a live tenant by running **9 idempotent, resumable steps**, plus its supporting pieces: subdomain validation, a no-password activation token, the `PLATFORM_*` capability/role seed, and the abandon-cleanup path.

This is **backend command logic + seed scripts only — NO new schema column** (see T-A7: `Company.Subdomain` already exists). No GraphQL resolvers, no mutation wiring, no UI (those are P-04). You build the engine and prove it compiles; you also expose it as a plain `ICommand<T>` handler that P-04 will hang a mutation off.

The data model this runs on already exists (P-01: `ops.TenantProvisioningRun` / `…RunStep`, `app.Companies` lifecycle columns, `__TEMPLATE__` company shell), the billing/entitlement layer already exists (P-02: `billing.Plan/PlanEntitlement/PlanQuota/Subscription/…`, `IEntitlementService`), and **multi-currency pricing exists (P-02b: `billing.PlanPrice` price book, `Subscription` currency/amount snapshot columns, `IPlanPricingService`).** **Assume all three are present and compile** — you are wiring on top of them.

> ⚠️ **Depends on P-02b having been run first.** Step 2 (CREATE_SUBSCRIPTION) calls `IPlanPricingService` and writes the subscription's `Currency`/`Amount`/`BillingCycle`/`PaymentGatewayCode` snapshot. If P-02b is not yet in the codebase, stop and run it first — do not re-add the price book here.

## Read first (grounding — do not skip)

1. `PSS-2.0-ONBOARDING-TASK-LIST.md` — tasks **T-A6 (ProvisionTenantCommand + steps 1–9), T-A7 (subdomain), T-A8 (activation token), T-A9 (PLATFORM_* seed), T-A10 (abandon cleanup)** are your scope.
2. `PSS-2.0-GTM-LEAD-ONBOARDING-AND-PRODUCT-ADMIN-APPROACH.md` — **§6.4** (the 9 steps + the five design rules: never one giant transaction · every step idempotent · resumable · visible · reversible-for-cleanup-only), **§6.6** (canonical sequence + the non-negotiable rules, esp. §6.6.3 activation-token discipline: *no password is ever generated, emailed, or displayed*), **§9.2** (template company is the clone source), **§11** (security model + the menu-vs-capability conflation warning).
3. `PSS-2.0-ONBOARDING-DQ7-PLATFORM-ROLES-MAP.md` — **DECIDED.** The exact `PLATFORM_*` role→capability matrix you will seed in step T-A9. 5 roles (Sales/Implementation/Support/Finance/Admin); provisioning trigger = Implementation + Admin.
4. `PSS-2.0-ONBOARDING-DQ4-MODULE-PLAN-MAP.md` — **DECIDED.** The module→plan matrix that step 4 filters capabilities/modules against (via `IEntitlementService`).
5. `PSS-2.0-ONBOARDING-P01-HANDBACK.md` and `PSS-2.0-ONBOARDING-PROMPT-01-DATA-MODEL.md` — how the ops tables + template shell were actually built (column names, the partial-class facet pattern). If a name here disagrees with the P-01 hand-back, **the hand-back wins** — verify against the real entity file before using any property name.
6. `PSS-2.0-ONBOARDING-P02-HANDBACK.md` — the billing layer + the **FeatureCode ↔ auth.Modules mismatch** you must bridge in step 4 (see "The FeatureCode↔Module mapping" below). And `PSS-2.0-ONBOARDING-PROMPT-02B-MULTICURRENCY-PRICING.md` — the price book + `IPlanPricingService` + the subscription snapshot columns you consume in step 2.
7. **The real entities you write into — read them and copy the exact required (NOT-NULL) columns before writing step 1/step 2** (see "Real required columns" below). Do not assume; open the files.

## Hard constraints (violating any of these fails the task)

- 🔒 **Migrations are strictly user-owned.** Do **NOT** run `dotnet ef migrations add`, `database update`, or `remove`, and do **NOT** hand-author a migration or model-snapshot file. Build the solution to prove your handlers compile and map, then produce a **migration spec** (markdown) *only if a schema change is actually needed*. **This prompt adds NO new column** — `Company.Subdomain` already exists (Screen #119, see T-A7). The only possible DDL is a **unique index on `Company.Subdomain` if one does not already exist**; everything else is command logic + data seeds. Confirm the existing index before writing any migration spec.
- 🌱 **Seed files:** you write them (idempotent `INSERT … WHERE NOT EXISTS`, matching the existing style under `sql-scripts-dyanmic/`); the **user applies** them. Do not execute SQL against any database.
- **All PKs/FKs are `int` identity.** `Company.CompanyId`, `Role.RoleId`, `Capability.CapabilityId`, `User.UserId` are all `int`. **The one exception in the whole system is `Module.ModuleId`, which is a `Guid`** — `RoleModule.ModuleId` is therefore a `Guid`. Do not introduce any other Guid keys.
- **UTC only.** Every date column is `timestamp with time zone`. The `Entity` base defaults `CreatedDate = DateTime.Now` — wrong for our DB; any date you write must be `DateTime.UtcNow`, and any boundary must be built with `DateTimeKind.Utc`. Npgsql throws on `Kind=Unspecified`.
- **Verify every property name before you use it.** Never assume a GraphQL field, DTO property, or column name. Read the entity/DTO first. Audit fields are `CreatedDate`/`ModifiedDate` from the `Entity` base (not `createdAt`/`modifiedAt`).
- **🔑 The provisioning handler runs in SuperAdmin / control-plane context.** See "The tenant-filter correctness pivot" below — this is the single most important correctness rule in this prompt. Every cross-tenant read must use `IgnoreQueryFilters()`, and every written row must set `CompanyId` **explicitly** (the filter never stamps writes).
- **🚫 No password is ever generated, emailed, or displayed** (§6.6.3). Step 8 (CREATE_ADMIN) creates the admin user in a *pending, no-usable-password* state and mints a **single-use hashed activation token**; step 9 emails an activation **link** only. Do **not** reuse the existing temp-password invite path as-is — see "Step 8" below for exactly how to adapt it.
- **BUSINESSADMIN** is the standard tenant admin role code seeded into every new tenant. No permission re-prompting.

## The tenant-filter correctness pivot (read this twice)

`ApplicationDbContext` applies a **global tenant query filter** to every entity that has a `CompanyId` (via `ApplyTenantFilters`): a row is visible only when
`(CurrentTenantId == null) || (entity.CompanyId == CurrentTenantId) || (entity.IsSystem == true)`,
where `CurrentTenantId = _tenantContext.GetCurrentTenantId()` (an `int?`, **null for a SuperAdmin/platform caller**). Two consequences you must engineer around:

1. **The filter is READ-ONLY.** It filters what queries return; it does **not** auto-stamp `CompanyId` on inserts. So for *every* row your steps write into the new tenant (roles, role-capabilities, role-modules, master data, settings, fields, the admin user, the user-role, the subscription), you must set **`CompanyId = newCompanyId` explicitly**. Nothing does it for you.
2. **Reading the template + reading a just-created tenant's rows can silently return nothing.** If the handler happens to run with a non-null `CurrentTenantId` that isn't the template's / new tenant's `CompanyId`, those rows are filtered out and your clone copies zero rows — a *silent* data-loss bug, not an error. Defend against it **both** ways:
   - Ensure the handler executes as a platform caller (`CurrentTenantId == null`). Confirm how the platform/ops context is established in this codebase (the `aud=platform` / SuperAdmin path). If you cannot guarantee null tenant context at this layer, then
   - Put **`.IgnoreQueryFilters()`** on every read of the `__TEMPLATE__` company's rows and every read-back of the new tenant's rows. Belt-and-braces: do both.
   - `ops.TenantProvisioningRun` **also** has a `CompanyId` and therefore inherits this filter (noted in the P-01 hand-back). Read/update run + step rows with `IgnoreQueryFilters()` too, or the monitor/resume path loses runs whose `CompanyId` isn't the caller's tenant.

`IsSystem == true` rows are visible to everyone — that is exactly why the `PLATFORM_*` roles/capabilities you seed in T-A9 are **global** (`IsSystem = true`, `CompanyId = null`): they must be readable in the platform context without belonging to any tenant.

## Real required columns (populate every NOT-NULL field — verified against the entities)

The engine writes real rows into real tables. **A step that omits a NOT-NULL column throws at `SaveChanges` — a runtime failure, not a compile error — so the request DTO must carry everything these rows need.** These are read from the actual entity files; verify them yourself, but do not skip any:

**Step 1 — `app.Companies` (`Company.cs`) NOT-NULL columns the request MUST supply or default:**
- `CompanyCode` (string, unique) — from request.
- `CompanyName` (string) — from request.
- **`CompanyHeader` (string, `= default!` → NOT NULL)** — from request, or default to `CompanyName` if the wizard doesn't collect it. **Easy to miss.**
- **`CompanyFooter` (string, NOT NULL)** — from request or a sensible default. **Easy to miss.**
- **`Address` (string, NOT NULL)** — from request. **Easy to miss.**
- **`CountryId` (int, NOT NULL — real FK → `Country`)** — the wizard **must** capture the tenant's country; there is no default. A bad/absent `CountryId` fails the FK. (Do **not** set the `Country` nav to a new instance — set the `CountryId` scalar to an existing country's id.)
- `IsInternal` (bool, NOT NULL) → **`false`** for real tenants.
- `Status` → `'PROVISIONING'`. `OnboardedOn` → `null` (set at go-live, P-06). `Subdomain` → from request (validated, T-A7). `SourceLeadId` → the `LeadId` if present, else null (plain int, no FK).
- All the Screen #75 org-profile fields (`ShortName`, `TaxId`, `RegistrationNumber`, `Website`, `City`, `State`, `PostalCode`, `PrimaryEmail`, `PrimaryPhone`, …) are **nullable** — leave null unless the wizard collects them.

> **Action:** `ProvisionTenantRequestDto` must include at minimum `CompanyName, CompanyCode, Subdomain, CountryId, Address` and *either* `CompanyHeader`/`CompanyFooter` *or* an explicit documented default rule. Add these fields to the DTO — the earlier draft only listed name/code/subdomain.

**Step 2 — `billing.Subscriptions` (`Subscription.cs`) columns:**
- NOT-NULL: `CompanyId` (the new id, set explicitly), `PlanId` (resolved from `PlanCode`), `Status` (`'Trial'` or `'Active'` — pick and document), `StartDate`, `CurrentPeriodStart`, `CurrentPeriodEnd` (all `DateTime`, UTC). `TrialEndsOn`/`CancelledOn` nullable.
- `CommercialTermId` → **null** (no FK; ops.CommercialTerm is P-05).
- **Snapshot columns (from P-02b — you MUST populate these):** `Currency`, `Amount`, `BillingCycle`, `PaymentGatewayCode`. See step 2 below for how `IPlanPricingService` supplies them.
- The **filtered unique index** allows only one row per company with `Status IN ('Trial','Active','PastDue')` — your idempotency guard must not try to insert a second active subscription.

**Steps 1–9 — `ops.TenantProvisioningRun` / `…RunStep` (verify against P-01 hand-back):**
- Run NOT-NULL: `IdempotencyKey` (unique), `Mode`, `Status`, **`RequestPayloadJson` (jsonb-as-string, NOT NULL — serialize the request into it)**. `CompanyId` null until step 1 stamps it. `LeadId`/`CommercialTermId`/`InitiatedByUserId` nullable no-FK.
- RunStep NOT-NULL: `RunId` (FK), `StepNumber` (1..9), `StepCode`, `Status`, `AttemptCount`. `(RunId, StepNumber)` is unique — one row per step per run.

## The FeatureCode ↔ auth.Module mapping (step 4 — carried from the P-02 hand-back)

**This is the single most important carry-forward from P-02.** `PlanEntitlement.FeatureCode` uses **fine-grained** codes (`MODULE:CONTACTS`, `MODULE:DONATION`, `MODULE:CASE`, `MODULE:GRANT`, `MODULE:EVENT`, `MODULE:VOLUNTEER`, `MODULE:MEMBERSHIP`, `CHANNEL:WHATSAPP`, …) with **NO FK**. But the real `auth.Modules` rows are **coarse, Guid-keyed**: **`CRM`, `SETTING`, `ACCESSCONTROL`, `ORGANIZATION`, `REPORTAUDIT`, `GENERAL`** (verify in `Base.Domain/Models/AuthModels/Module.cs` + `html_mockup_screens/Pss2.0_Menus.sql`). **They do not map 1:1** — e.g. `CRM` ⊇ Contacts + Donation; Case/Grant have no coarse-module equivalent.

So step 4 cannot just "grant module X if entitlement X is on." You must add an explicit **`auth ModuleCode → FeatureCode(s)` mapping table** (a `static readonly Dictionary<string, string[]>` in the handler/a small mapping class is fine for MVP — do **not** invent a DB table): for each coarse `RoleModule` the template grants, look up which fine-grained FeatureCode(s) it corresponds to, and grant it **only if `IEntitlementService` says the plan enables at least one** of those FeatureCodes. Where a coarse module has no clean plan gate (e.g. `SETTING`, `GENERAL`, `ACCESSCONTROL` — always-on infra modules), **grant unconditionally** and document that. State your exact mapping in the hand-back so the PM can reconcile it against the D-Q4 matrix.

## Codebase anchors (study these, then follow them)

- **Step-1 anchor — `CreateCompany.cs`** (`…ApplicationBusiness/Companies/Commands/`). The current bare insert: `record CreateCompanyCommand(CompanyRequestDto company) : ICommand<CreateCompanyResult>`, validator uses `ValidateUniqueWhenCreate`, handler does `command.company.Adapt<Company>()` → `dbContext.Companies.Add(company)` → `SaveChangesAsync`, guarded by `[CustomAuthorize(DecoratorApplicationModules.Company, Permissions.Create)]`. **Your step 1 absorbs this pattern** — it creates the `app.Companies` row (unique `CompanyCode` + unique `Subdomain`, `Status='PROVISIONING'`, `IsInternal=false`, `OnboardedOn=null` until go-live) as the first provisioning step. Reuse the uniqueness-validation helper style.
- **CQRS shape** — `ICommand<T>` / `ICommandHandler<TCommand,TResult>` (MediatR). Match a nearby multi-step handler for structure, DI (`IApplicationDbContext`, `IEntitlementService`, the email service, `ITenantContext`), and `SaveChangesAsync` usage.
- **Auth entities** (`Base.Domain/Models/AuthModels/`) — verify each before use:
  - `Role.cs` — `RoleId int`, `RoleName` (`CaseFormat("title")`), `RoleCode` (`CaseFormat("upper")`), `IsSystem bool`, `IsAssignable bool`, `int? CompanyId` (**null = global/system role**), nav `RoleCapabilities`/`RoleModules`; static `Role.Create(...)`.
  - `Capability.cs` — `CapabilityId int`, `CapabilityName`, `CapabilityCode` (`CaseFormat("upper")` — free varchar, so `PLATFORM_TENANT_PROVISION` is a valid code), `IsSpecial bool`; static `Create`.
  - `RoleCapability.cs` — `RoleCapabilityId, RoleId, MenuId, CapabilityId, HasAccess`. **RBAC is menu-scoped: a capability grant is always `(Role, Menu, Capability)`.**
  - `RoleModule.cs` — `RoleModuleId int, RoleId int, ModuleId Guid, HasAccess bool`.
  - `Module.cs` — `[Table("Modules", Schema="auth")]`, `ModuleId Guid`, `ModuleCode` (upper, e.g. `PSSCORE`), `ModuleName`, `ModuleUrl`.
  - `Menu.cs` — inspect it for its real required columns (ModuleId, MenuCode, MenuName, MenuUrl, ParentMenuId, ordering, etc.) before you seed any `(master)` menu rows in T-A9.
- **Enforcement** — `CustomAuthorizeService.HasAccessAsync(int userId, string menuCode, string capabilityCode)` JOINs `RoleCapabilities → UserRoles → Menus (by MenuCode) → Capabilities (by CapabilityCode)` where `HasAccess == true`. `CustomAuthorizeAttribute` ctors: `(menuCode, capabilityCode)`, `(menuCode, params capabilityCodes)`, `(menuCodes[], capabilityCode)`. This is how `[CustomAuthorize("PLATFORM_TENANTS", "PLATFORM_TENANT_PROVISION")]` will gate the command (see T-A9).
- **Step-8 anchor — `SendUserInvite.cs`** (`…AuthBusiness/Users/Commands/`). ⚠️ **Read it, then deliberately diverge from its password behaviour.** It currently sets `user.PasswordHash/PasswordSalt` from `GenerateTempPasswordHelper.Generate()`, `MustChangePassword=true`, `TempPasswordExpiresAt=UtcNow.AddHours(72)`, `IsPendingInvitation=true`, `InvitationSentAt=UtcNow`, resolves the `PSSCORE` module, and calls `emailTemplateService.SendEmailByTemplateKeyAsync(...,"USER_WELCOME_INVITE", module.ModuleId, true)`. **Keep** the pending-state flags (`IsPendingInvitation`, `InvitationSentAt`) and the module-resolution + email-template call pattern. **Remove** the temp-password generation — do not set a usable password, do not email `TEMP_PASSWORD`. Instead mint the activation token below.
- **Activation-token anchor — `PasswordReset.cs`** (`[Table("PasswordResets", Schema="auth")]`; `Id, UserId, TokenHash, ExpiresAt, CreatedAt, IsUsed`, `User` nav). This hashed-single-use-token shape is exactly what step 8 needs. Reuse it (or a `PasswordReset` row minted as the activation token) so the admin clicks a link on their own tenant domain and sets their own password. Verify whether an existing "set password via token" consumer already exists so the activation link lands on a working endpoint; if the consumer is a P-04/UI concern, note that and still mint the token now.
- **Idempotency / raw SQL** — `ApplicationDbContext.ExecuteRawSqlAsync(sql, parameters, ct)` exists if you need set-based idempotent inserts; EF `AnyAsync(... , IgnoreQueryFilters())` guards are equally acceptable. Match whatever the surrounding handlers do.
- **Seed scripts** to match in style: `sql-scripts-dyanmic/*.sql` (e.g. `billing-plan-catalog-seed.sql`, `ops-template-company-seed.sql`).

## Scope — build exactly this

### T-A6 · `ProvisionTenantCommand` + handler + the 9-step engine

**The command.** `record ProvisionTenantCommand(ProvisionTenantRequestDto request) : ICommand<ProvisionTenantResult>`. The request carries the wizard answer set:
- **tenant identity** — `CompanyName`, `CompanyCode`, `Subdomain`, **`CountryId`** (required — real FK), **`Address`** (required), and `CompanyHeader`/`CompanyFooter` (required NOT-NULL on the entity — collect them or apply a documented default such as `CompanyHeader = CompanyName`). See "Real required columns" — these are mandatory, not optional.
- **commercial** — chosen `PlanCode`, **`CurrencyId`** (int FK → `com.Currencies` — the currency the tenant pays in; the catalog is now `CurrencyId`-keyed per P-02b, so the wizard passes an id, not an ISO string), **`BillingCycle`** (`Monthly|Annual`), optional **`PaymentGatewayCode`** (string, e.g. `RAZORPAY`).
- **primary admin** — name, email.
- **context** — `Mode` (`SELF_SERVICE|ASSISTED`), optional `LeadId` / `CommercialTermId` (both nullable — see the deferral note).

Gate it with `[CustomAuthorize("PLATFORM_TENANTS", "PLATFORM_TENANT_PROVISION")]` (the menu/capability you seed in T-A9).

**The engine contract (design §6.4 — implement all five rules):**
- **Never one giant transaction.** Each of the 9 steps runs in **its own transaction** and records **its own `ops.TenantProvisioningRunStep` row** (Status PENDING→RUNNING→SUCCEEDED/FAILED, `AttemptCount++`, `StartedOn`/`CompletedOn` UTC, `ErrorMessage` on failure). The `TenantProvisioningRun` row moves PENDING→RUNNING→(SUCCEEDED | PAUSED_ON_ERROR).
- **Idempotent.** Every step is safe to re-run: guard each insert with an existence check (`INSERT … WHERE NOT EXISTS` / `AnyAsync(IgnoreQueryFilters())`) so a resumed run never double-writes. The run's **idempotency key = `LeadId + CompanyCode`** (fall back to just `CompanyCode` when `LeadId` is null); a second `ProvisionTenantCommand` with the same key **resumes the existing run**, it does not create a second one or a second company.
- **Resumable.** On entry: find-or-create the run by idempotency key; if it exists and is `PAUSED_ON_ERROR`, **resume at the first non-`SUCCEEDED` step** (steps already `SUCCEEDED` are skipped by their idempotency guard anyway, but skip them explicitly to save work). A step that throws sets its row + the run to the paused/failed state and **stops the pipeline** (does not advance).
- **Visible.** All state lives in the `ops` run/step rows so P-04's O-03 monitor can read progress. Write meaningful `StepCode` + `ErrorMessage`. (Remember `IgnoreQueryFilters()` when reading these back — they carry a `CompanyId`.)
- **Reversible for cleanup only.** See T-A10.

**The 9 steps** (StepNumber : StepCode — what it does):

1. **CREATE_COMPANY** — insert the `app.Companies` row **populating every NOT-NULL column** (see "Real required columns": `CompanyCode`, `CompanyName`, `CompanyHeader`, `CompanyFooter`, `Address`, `CountryId`, `IsInternal=false`). Enforce unique `CompanyCode` **and** unique `Subdomain` (T-A7). `Status='PROVISIONING'`, `OnboardedOn=null`. Capture the new `CompanyId` onto the run row (`TenantProvisioningRun.CompanyId`) — every later step needs it. (Absorbs `CreateCompany.cs`.)
2. **CREATE_SUBSCRIPTION** — insert a `billing.Subscription` for the new `CompanyId` from the chosen `PlanCode`. **Read the plan from the request payload** (`PlanCode`), *not* from a `CommercialTerm` FK — `ops.CommercialTerm` does not exist yet (P-05), so `Subscription.CommercialTermId` stays **null** (no FK; P-02 left it FK-less). Set start/period fields in UTC.
   - **Multi-currency (P-02b):** call `IPlanPricingService.ResolveAsync(PlanCode, request.CurrencyId, request.BillingCycle, ct)` (int `CurrencyId`, not an ISO string). If it returns **null**, the requested currency is **not sellable** for that plan → **fail this step with a clear validation error** (`PAUSED_ON_ERROR`, `ErrorMessage = "no price for {PlanCode} in currencyId {CurrencyId}/{BillingCycle}"`) — do **not** silently fall back to the base currency. On success, **snapshot** the result onto the subscription: `Currency = res.CurrencyCode` (the ISO string the service resolved — `Subscription.Currency` is a snapshot VALUE, deliberately an ISO string and **not** a `CurrencyId` FK), `Amount = res.Amount`, `BillingCycle = res.BillingCycle`, `PaymentGatewayCode = request.PaymentGatewayCode`. These are a VALUE snapshot — never an FK to `PlanPrice` or `com.Currencies` (snapshot rule). A later price-book edit must not change this row.
   - Follow P-02/P-02b's `Subscription` entity shape (verify its property names, incl. the new snapshot columns).
3. **SEED_ROLES** — clone the standard tenant role set from the `__TEMPLATE__` company into the new `CompanyId`. Every cloned `Role` gets `CompanyId = newCompanyId`, `IsSystem = false`, a fresh `RoleId`. **BUSINESSADMIN must exist** in the result (it's the primary admin's role in step 8). Build a **template-RoleId → new-RoleId map** in memory — steps 4 needs it. (If the `__TEMPLATE__` company has no roles yet — it's a shell per P-01 until ops configures it — the clone copies zero rows; that is acceptable and must not error. Note it in your hand-back. To make an end-to-end demo work you may *also* provide a minimal fallback that guarantees a BUSINESSADMIN role exists; state clearly if you do.)
4. **SEED_CAPABILITIES** — clone the template's `RoleCapability` **and** `RoleModule` rows into the new tenant, remapping `RoleId` via the step-3 map (and keeping `MenuId`/`ModuleId` as-is — those are global/shared). **Filter by plan entitlements via the mapping layer:** the template grants **coarse** `auth.Modules` (CRM/SETTING/…) but the plan's entitlements are **fine-grained** FeatureCodes — use the `ModuleCode → FeatureCode(s)` mapping described in **"The FeatureCode ↔ auth.Module mapping"** above. For each cloned `RoleModule`, grant it only if `IEntitlementService` reports the plan enables ≥1 mapped FeatureCode (always-on infra modules like SETTING/GENERAL/ACCESSCONTROL are granted unconditionally). Use the entitlement service (P-02) — do not re-implement the plan matrix. Skip (or set `HasAccess=false` per the service's convention) modules the plan excludes.
5. **SEED_MASTERDATA** — clone `MasterDataType` + `MasterData` rows from the template into the new `CompanyId` (verify the real entity/table names for master data before writing this — do not assume). Idempotent per `(CompanyId, code)`.
6. **SEED_SETTINGS** — clone `OrganizationSetting` defaults + any `NumberSequence` definitions from the template into the new `CompanyId`. (Verify the settings entity names; the settings layer is KV `sett.OrganizationSettings` per project memory.)
7. **SEED_FIELDS** — clone per-tenant `Field` / `GridField` config rows from the template into the new `CompanyId` (verify names).
8. **CREATE_ADMIN** — create the primary admin `User` for the new `CompanyId` + a `UserRole` binding them to the new tenant's **BUSINESSADMIN** role. **No password.** Set the pending flags (`IsPendingInvitation=true`, `InvitationSentAt=UtcNow`) but leave the account without a usable credential; mint a **single-use hashed activation token** (`PasswordReset`-style: `TokenHash`, `ExpiresAt` UTC e.g. `+72h`, `IsUsed=false`). Do **not** generate/store/email a temp password (T-A8). Verify `User`'s real column names before use.
9. **SEND_WELCOME** — send the welcome email carrying the **activation link** (token from step 8), via the existing `emailTemplateService.SendEmailByTemplateKeyAsync(...)` path (module = `PSSCORE`, verify the template key — reuse/rename the invite template, but the body must be *activation-link*, never a password). Then stamp the outcome back onto the lead context: if `LeadId` is present, set `Lead.ConvertedCompanyId = newCompanyId` (⚠️ `ops.Lead` **does not exist until P-05** — so guard this: if the lead table/entity isn't present yet, **skip the stamp and note it**; do not add an FK or a hard dependency on `ops.Lead`). Finally flip the run to `SUCCEEDED`. **Company.Status stays `PROVISIONING`** here — the flip to `ACTIVE` + `OnboardedOn` is the go-live step (P-06), not provisioning.

> **Do not** flip `Company.Status` to `ACTIVE` in this prompt. Provisioning ends at `SUCCEEDED` run + `PROVISIONING` company; go-live (P-06) activates.

### T-A7 · Subdomain validation (⚠️ the column ALREADY EXISTS — do NOT add it)

- **`Company.Subdomain` already exists** — `public string? Subdomain { get; set; }` in `Company.cs` (added by **Screen #119 Login** for multi-tenant hostname resolution, alongside `CustomDomain`). **Do NOT add the column, do NOT write a migration to add it.** The earlier draft of this prompt was wrong on this point.
- **Uniqueness:** check whether a **unique index** on `Company.Subdomain` already exists (it may have come with #119). Query the DB/inspect the EF config first. **Only if absent**, add a filtered unique index (`WHERE "Subdomain" IS NOT NULL`, since it's nullable) via `IEntityTypeConfiguration<Company>` and put **that index — and nothing else —** in the migration spec. If it already exists, there is **no schema change and no migration** for P-03 at all; say so in the hand-back.
- **Validation (FluentValidation on the command):** lowercase DNS label rules — `^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$`, length ≤ 63, no leading/trailing/double hyphen; **reserved-word blocklist** (e.g. `www, app, api, admin, mail, ops, billing, master, portal, static, cdn, status, help, support` — put the list in one place). Uniqueness enforced at step 1 (unique index) *and* pre-checked in the validator for a clean error.
- Subdomain is **immutable after the tenant reaches `ACTIVE`** (design rule) — you don't build the guard here (no update path in this prompt), but note it for P-06/the tenant-admin screen.

### T-A8 · Activation token (no password, ever)

Covered inside step 8 above. Deliverable: a single-use hashed token minted at admin-creation, emailed as a link in step 9, with a documented expiry (UTC). No temp password anywhere in the provisioning path. If the token-consuming endpoint ("set your password") doesn't exist yet, mint the token now and flag the endpoint as a P-04 follow-up — but the *engine* must produce a valid, hashed, single-use token.

### T-A9 · `PLATFORM_*` capabilities + role bundles (global seed) 🌱

Seed the control-plane authorization data per the **DECIDED D-Q7 matrix**. These are **global** rows (`IsSystem=true`, `CompanyId=null`) so they're visible in platform context. Because RBAC is **menu-scoped**, a clean seed is: **menus → capabilities → role bundles.** Deliver this as an **idempotent seed script** under `sql-scripts-dyanmic/` (I write, user applies), *plus* verify the entities compile if you add any static `Create` calls.

1. **`(master)` menus** — seed one `auth.Menu` per control-plane area so capabilities have something to scope to: `PLATFORM_LEADS`, `PLATFORM_TENANTS`, `PLATFORM_PLANS`, `PLATFORM_AUDIT`, `PLATFORM_PROVISIONING`. **Inspect `Menu.cs` for required columns first** (ModuleId is a Guid — reuse an existing platform/core module's ModuleId or seed a `PLATFORM` module; MenuUrl/ordering/ParentMenuId as the table requires). These are exactly the menus P-04's control-plane screens will hang off.
2. **Capabilities** — seed the 10 `PLATFORM_*` capability rows (`auth.Capabilities`, `IsSpecial=true`): `PLATFORM_LEAD_VIEW, PLATFORM_LEAD_EDIT, PLATFORM_LEAD_EXPORT, PLATFORM_DEAL_APPROVE, PLATFORM_TENANT_VIEW, PLATFORM_TENANT_PROVISION, PLATFORM_TENANT_SUSPEND, PLATFORM_PLAN_EDIT, PLATFORM_IMPERSONATE, PLATFORM_AUDIT_VIEW`.
3. **Roles** — seed the 5 global roles (`auth.Roles`, `IsSystem=true`, `CompanyId=null`, `IsAssignable=true`): `PLATFORM_SALES, PLATFORM_IMPLEMENTATION, PLATFORM_SUPPORT, PLATFORM_FINANCE, PLATFORM_ADMIN`.
4. **Role bundles** — seed `auth.RoleCapability(RoleId, MenuId, CapabilityId, HasAccess=true)` rows binding each role to its `(menu, capability)` pairs per the D-Q7 matrix. Map each capability to the natural menu (`PLATFORM_TENANT_PROVISION`→`PLATFORM_TENANTS`, `PLATFORM_LEAD_*`→`PLATFORM_LEADS`, `PLATFORM_PLAN_EDIT`→`PLATFORM_PLANS`, `PLATFORM_AUDIT_VIEW`→`PLATFORM_AUDIT`, `PLATFORM_DEAL_APPROVE`→`PLATFORM_LEADS` or a deals menu — pick one and note it). This is what makes `[CustomAuthorize("PLATFORM_TENANTS","PLATFORM_TENANT_PROVISION")]` on the command actually resolve.

> **Recommended path = the one above** (menus + caps + bundles, one authorization model app-wide, zero new enforcement primitive). **If** you find that seeding valid `auth.Menu` rows drags in heavy screen/grid/registry infrastructure you'd rather not touch in a backend-only prompt, the acceptable fallback is: seed **capabilities + roles only**, wire the command's `[CustomAuthorize]` against one `PLATFORM_PROVISIONING` menu, and leave the *remaining* role→capability bundles as a documented TODO for P-04 (where the `(master)` menus get built with the screens). **Whichever path you take, say so explicitly in the hand-back** — the PM session needs to know whether bundling is complete or deferred. Do not silently drop bundling.

### T-A10 · Abandon / cleanup path

A `AbandonProvisioningRunCommand` (or a mode on the engine) that cleans up a **failed run that never reached step 8** (CREATE_ADMIN). Design rule (§6.4): reversible **for cleanup only** — `DELETE`-cascade the half-provisioned tenant rows (company + subscription + seeded roles/caps/masterdata/settings/fields for that `CompanyId`) **only** while the run is `PAUSED_ON_ERROR` and no admin user exists yet. **Once step 8 has created the admin user, abandon is forbidden — the correct action is suspend, never delete** (a real person now has an account). Set the run to `ABANDONED`. Gate with `[CustomAuthorize("PLATFORM_TENANTS","PLATFORM_TENANT_SUSPEND")]` (Admin-only per D-Q7). Guard hard: refuse to run if any `UserRole` exists for that `CompanyId`.

## Out of scope for P-03 (do NOT build)

- **Any GraphQL / mutation / resolver wiring** — the command is a plain `ICommand<T>`; P-04 (T-A11) exposes it via the API. (You *may* add the `[CustomAuthorize]` attribute now since the pipeline already honours it.)
- **The O-03 Run Monitor screen / any UI** — P-04 (T-A12).
- **`ops.Lead` / `ops.CommercialTerm` entities** — P-05. Keep `LeadId`/`CommercialTermId` as nullable ints with **no FK**; guard the step-9 `Lead.ConvertedCompanyId` stamp so it no-ops when the lead table is absent.
- **The token-consuming "set password" endpoint UI** — mint the token; flag the endpoint as a P-04 follow-up if it doesn't already exist.
- **Go-live activation** (Company.Status → ACTIVE, OnboardedOn) — P-06.
- **Impersonation, audit-event emission** — later prompts.

## Definition of done

1. Solution **builds clean** (`dotnet build` real exit 0 — not "only a pre-existing error remained"; if `tsc`/build reports only a known stub error, that means zero files were checked → not clean).
2. `ProvisionTenantCommand` + handler exist, run the **9 steps** each in its own transaction with its own `TenantProvisioningRunStep` row, are **idempotent** (existence-guarded inserts), **resumable** (find-or-resume by idempotency key `LeadId+CompanyCode`), and stop-on-error into `PAUSED_ON_ERROR`. Every cross-tenant read uses `IgnoreQueryFilters()` and every written tenant row sets `CompanyId` explicitly.
3. **Every NOT-NULL column is populated** — step 1 writes `CompanyHeader`/`CompanyFooter`/`Address`/`CountryId`/`IsInternal` (not just name/code/subdomain); step 2 writes the `Currency`/`Amount`/`BillingCycle`/`PaymentGatewayCode` snapshot; run/step rows write `RequestPayloadJson`. No `SaveChanges` NOT-NULL/FK failure at runtime.
4. **Currency handled (P-02b):** step 2 resolves price via `IPlanPricingService`, snapshots the value, and **fails cleanly on an unsellable currency** (no silent base-currency fallback).
5. `Company.Subdomain` **validator** shipped (DNS-label regex + reserved blocklist + uniqueness pre-check). **No column added** (it already exists); a unique index is added **only if one doesn't already exist**.
6. Step 8 creates the admin with **no usable password** + a **single-use hashed activation token**; step 9 emails an **activation link** (no password anywhere).
7. `PLATFORM_*` seed delivered (menus + 10 capabilities + 5 roles + role bundles per D-Q7, all global `IsSystem=true`), idempotent, under `sql-scripts-dyanmic/` — **or** the documented capabilities+roles-only fallback with bundling deferred to P-04 (state which).
8. `AbandonProvisioningRunCommand` cleans up only pre-step-8 runs and is blocked once an admin user exists.
9. A **migration spec** (markdown) **only if** a unique index on `Company.Subdomain` is actually missing — otherwise a one-line note "no schema change; Subdomain + its index already exist." **No column-add migration.**
8. A short **hand-back note**: build clean (Y/N); which PLATFORM_* seed path you took (full bundling vs deferred); whether the `__TEMPLATE__` company had any roles/masterdata/settings to clone (and whether you added a BUSINESSADMIN fallback); how you guaranteed SuperAdmin/null-tenant context (or that you relied on `IgnoreQueryFilters()`); the activation-token entity you used and whether a consuming endpoint exists; and every property/table name that differed from this brief.

## Report back to the PM session

State: build clean (Y/N), the 9-step engine complete + idempotent + resumable (Y/N), subdomain column + validator (Y/N), no-password activation token (Y/N), PLATFORM_* seed path (full bundling / deferred), abandon guard (Y/N), migration spec path, seed script path(s), and any deviations. **Do not start P-04.**
