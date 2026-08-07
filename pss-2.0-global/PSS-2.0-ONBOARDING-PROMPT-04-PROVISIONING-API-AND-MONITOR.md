# DEV PROMPT P-04 — Provisioning GraphQL API + O-03 Run Monitor + account-activation endpoint

> Paste everything below the line into a **fresh development session**. It is self-contained.
> When done, report back the outcome to the PM session; do **not** proceed to P-05.

---

## Role & mission

You are a Senior Full-Stack Developer on the PSS 2.0 multi-tenant .NET + Next.js platform (**backend target framework `net10.0`**). Your task is **P-04: expose the provisioning engine over the API and give operators eyes on it**. Concretely, three things:

1. **T-A11 — Provisioning GraphQL API.** Wrap the already-built `ProvisionTenantCommand` and `AbandonProvisioningRunCommand` (P-03) in HotChocolate mutations, add a thin **Resume** mutation, and — critically — **populate `TenantProvisioningRun.InitiatedByUserId` from the HTTP caller** (P-03 deliberately left it `null` because there is no `ICurrentUserService`; the mutation layer is where the acting user is known).
2. **T-A12 — O-03 Run Monitor screen.** Query side (`GetProvisioningRuns` list + `GetProvisioningRunById` detail-with-steps) exposed via GraphQL, plus the control-plane FE screen: a list of provisioning runs with status, and a detail view showing the 9-step timeline, with **Resume** / **Abandon** actions.
3. **The account-activation endpoint** (deferred from P-03). P-03 step 8 **mints** a single-use `PasswordReset` activation token but nothing **consumes** it. Build the token-consuming *set-your-password / activate account* endpoint so the welcome-email link actually works. **No password is ever generated, emailed, or displayed — the invitee sets their own.**

The provisioning engine, the abandon command, the `ops` run/step tables, the billing/pricing layer, and the `PLATFORM_*` RBAC seed **already exist and compile** (P-01/P-02/P-02b/P-03). You are wiring an API + UI + one auth endpoint on top of them — **you are not changing the engine's step logic.**

> ⚠️ **Depends on P-03 having been run first.** If `ProvisionTenantCommand` / `AbandonProvisioningRunCommand` / `ops.TenantProvisioningRun` are not in the codebase, stop and run P-03 first.

## Read first (grounding — do not skip)

1. `PSS-2.0-ONBOARDING-TASK-LIST.md` — tasks **T-A11 (provisioning GraphQL API), T-A12 (O-03 Run Monitor)** are your scope, plus the **activation endpoint** carried over from T-A8/P-03.
2. `PSS-2.0-ONBOARDING-P03-HANDBACK.md` — **the authoritative record of what P-03 actually built.** Note especially: deviation **#1** (Subscription snapshots `CurrencyId` int FK — the wizard DTO passes `CurrencyId int`, **not** an ISO string), **#3** (`ICurrentUserService` does not exist → `InitiatedByUserId` is `null`; **you fix that here**), **#9** (`PasswordReset` PK is `Id`, does **not** extend `Entity`, has no `IsDeleted`), and **#11** (activation token is minted but **no consuming endpoint yet** — that's this prompt).
3. `PSS-2.0-GTM-LEAD-ONBOARDING-AND-PRODUCT-ADMIN-APPROACH.md` — **§6.6** (provisioning sequence + the non-negotiable rules, esp. **§6.6.3 activation-token discipline: *no password is ever generated, emailed, or displayed***), **§11** (control-plane security model + the menu-vs-capability warning). The O-03 monitor is a **control-plane** screen — it lives on the `(master)` / ops surface, gated by `PLATFORM_*` capabilities, **not** a tenant screen.
4. `PSS-2.0-ONBOARDING-DQ7-PLATFORM-ROLES-MAP.md` — **DECIDED.** Which `PLATFORM_*` roles may **view** runs (`PLATFORM_TENANT_VIEW`), **provision/resume** (`PLATFORM_TENANT_PROVISION`), and **abandon** (`PLATFORM_TENANT_SUSPEND`). The T-A9 seed (P-03) already created these menus/capabilities/roles — you consume them, you do not re-seed them.
5. **The real files you wrap/mirror — read each before writing (paths + why below).** Do not assume any property name; open the file. Audit fields are `CreatedDate`/`ModifiedDate` (from `Entity` base), never `createdAt`/`modifiedAt`.

## Hard constraints (violating any of these fails the task)

- 🔒 **Migrations are strictly user-owned.** Do **NOT** run `dotnet ef migrations add`, `database update`, or `remove`, and do **NOT** hand-author a migration or model-snapshot file. **This prompt needs no schema change** — it adds mutations, queries, DTOs, one command/query pair, and a screen; it writes into tables that already exist. If you believe a column is missing, **stop and produce a migration spec (markdown) for the user** instead of adding it.
- **All PKs/FKs are `int` identity.** `Company.CompanyId`, `User.UserId`, `Role.RoleId`, `TenantProvisioningRun.RunId`, `…RunStep.RunStepId` are all `int`. The one system-wide exception is `Module.ModuleId` (Guid). Introduce no new Guid keys.
- **UTC only.** Every date column is `timestamp with time zone`. Any date you write must be `DateTime.UtcNow`; any boundary must be built with `DateTimeKind.Utc`. Npgsql throws on `Kind=Unspecified`.
- **🔑 Control-plane / null-tenant context.** The provisioning runs carry a `CompanyId`, so the **global tenant query filter applies to `ops.TenantProvisioningRun` / `…RunStep`**. The monitor queries and the resume/abandon commands run in platform (SuperAdmin, `CurrentTenantId == null`) context — **every read of run/step rows MUST use `.IgnoreQueryFilters()` + an explicit `IsDeleted != true` guard**, exactly as the P-03 `AbandonProvisioningRunCommand` handler does. A run whose `CompanyId` isn't the caller's tenant silently disappears otherwise.
- **🚫 No password is ever generated, emailed, or displayed.** The activation endpoint takes a token + the user's chosen new password and sets it. It never mints, returns, or logs a password. The token is single-use — mark it used on success.
- **Verify every property name before you use it.** Read the entity/DTO first.
- **BUSINESSADMIN** role only for tenant context; no permission re-prompting on the control-plane screen beyond the `PLATFORM_*` gates.

## Codebase anchors (study these, then follow them)

### Mutation pattern — wrap-a-command + resolve the acting user
- **`Base.API/EndPoints/Auth/Mutations/AuthendicationMutations.cs`** (note the misspelling). This is the canonical `[ExtendObjectType(OperationTypeNames.Mutation)] public class … : IMutations` shape. Copy from it:
  - **DI via constructor** — `IHttpContextAccessor _httpContextAccessor`, `IApplicationDbContext _dbContext`, `IAuditLogWriter _auditLogWriter`, `IConfiguration` as needed. `IMediator` comes in **per-method** as `[Service] IMediator mediator`.
  - **Return type** — `Task<BaseApiResponse<T>>`; success via `BaseApiResponse<T>.PostSuccess(...)` / `.Ok(ExceptionCode.Success, msg, data)`, failure via `.Error(...)`.
  - **🔑 Acting-user resolution (this is how you populate `InitiatedByUserId`)** — see `SwitchCompany` at **line ~279**:
    ```csharp
    var userIdClaim = _httpContextAccessor.HttpContext?.User.FindFirst("UserId")?.Value;
    if (string.IsNullOrEmpty(userIdClaim) || !int.TryParse(userIdClaim, out var userId))
        return BaseApiResponse<…>.Error(ExceptionCode.UnAuthorized, "Invalid or missing UserId claim.");
    ```
    That `userId` is the value you pass into `ProvisionTenantCommand` so the handler can stamp `run.InitiatedByUserId`.
  - **Audit** — the file's `WriteAuthEvent` calls show the `IAuditLogWriter` shape; emit a provisioning audit event on provision/resume/abandon (action e.g. `TENANT_PROVISION` / `TENANT_PROVISION_RESUME` / `TENANT_PROVISION_ABANDON`, severity HIGH/MEDIUM) if the writer supports non-auth events — otherwise note it as a TODO, don't force it.
- **`Base.API/EndPoints/Application/Mutations/*.cs`** (e.g. `CompanyMutations.cs`) — a second example of the same `IMutations` wrap-a-command pattern in the **Application** area, if the provisioning mutations feel more at home there than under Auth. Put the new `TenantProvisioningMutations` wherever the ops/control-plane endpoints will live (a new `EndPoints/Ops/Mutations/TenantProvisioningMutations.cs` is cleanest — match the folder convention the codebase already uses for a schema-scoped area).

### Query pattern — expose the runs
- **`Base.API/EndPoints/Application/Queries/OrganizationBankAccountQueries.cs`** — the canonical `[ExtendObjectType(OperationTypeNames.Query)] public class … : IQueries` shape:
  - **List** — `Task<PaginatedApiResponse<IEnumerable<TDto>>> Get…([Service] IMediator mediator, [AsParameters] GridFeatureRequest request, CancellationToken ct)`, `mediator.Send(new GetQuery(request))`, return via `ApiResponseHelper.ReturnPaginatedApiResponse(result)` / `…Error<TDto>()`.
  - **By-id** — scalar `int` param, `mediator.Send(new GetByIdQuery(id))`, `ApiResponseHelper.ReturnObjectApiResponse(...)`.
- Mirror this for `GetProvisioningRuns` (paginated list) + `GetProvisioningRunById` (single run **with its 9 steps eager-loaded**).

### The entities you read (verified — use these exact fields)
- **`Base.Domain/Models/OpsModels/TenantProvisioningRun.cs`** — `RunId int`, `IdempotencyKey string`, `LeadId int?`, `CommercialTermId int?`, `CompanyId int?`, `Mode string` (`SELF_SERVICE|ASSISTED`), `Status string` (`PENDING|RUNNING|PAUSED_ON_ERROR|SUCCEEDED|ABANDONED`), `RequestPayloadJson string` (jsonb-as-string), `StartedOn DateTime?`, `CompletedOn DateTime?`, `InitiatedByUserId int?`, `Company` nav, `Steps` collection. Plus the `Entity` base audit fields (`CreatedDate`, `ModifiedDate`, `IsDeleted`).
- **`Base.Domain/Models/OpsModels/TenantProvisioningRunStep.cs`** — `RunStepId int`, `RunId int`, `StepNumber int` (1..9), `StepCode string` (`CREATE_COMPANY|CREATE_SUBSCRIPTION|SEED_ROLES|SEED_CAPABILITIES|SEED_MASTERDATA|SEED_SETTINGS|SEED_FIELDS|CREATE_ADMIN|SEND_WELCOME`), `Status string` (`PENDING|RUNNING|SUCCEEDED|FAILED|SKIPPED`), `AttemptCount int`, `ErrorMessage string?`, `StartedOn DateTime?`, `CompletedOn DateTime?`, `Run` nav.

### The commands you wrap (already built — P-03)
- **`Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs`** — `ProvisionTenantCommand(ProvisionTenantRequestDto Request) : ICommand<ProvisionTenantResult>`, gated `[CustomAuthorize("PLATFORM_TENANTS","PLATFORM_TENANT_PROVISION")]`. **Read `ProvisionTenantRequestDto`'s real fields** (`CompanyName, CompanyCode, Subdomain, CountryId, Address, PlanCode, CurrencyId (int), BillingCycle, PaymentGatewayCode?, LeadId?, CommercialTermId?, Mode`, + admin name/email) — the FE wizard DTO must match them **exactly**, and **`CurrencyId` is an int** (deviation #1), not an ISO string.
- **`Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/AbandonProvisioningRun.cs`** — `AbandonProvisioningRunCommand(int RunId, string? Reason = null) : ICommand<AbandonProvisioningRunResult>`, gated `[CustomAuthorize("PLATFORM_TENANTS","PLATFORM_TENANT_SUSPEND")]`. Already hard-blocks post-step-8. You just expose it.

### The activation flow you mirror (existing password-reset consume path)
- **`Base.Application/Business/AuthBusiness/ResetPasswords/Commands/ResetPasswords.cs`** — the **consume** shape to mirror: decrypt token via `IEncryptionService.ValidateAndDecryptToken(token)` → check `tokenData.ExpiryDate <= DateTime.UtcNow` → find `User` by `UserName == tokenData.UserEmail` → `AuthExtensions.CreatePasswordHash(newPwd, out salt, out hash)` → set `user.PasswordHash/PasswordSalt` → find `PasswordResets.FirstOrDefaultAsync(p => p.TokenHash == request.Token)` → set `IsUsed = true` → `SaveChangesAsync`.
- **`Base.Application/Business/AuthBusiness/ResetPasswords/Queries/ResetTokenValidations.cs`** — the **pre-check** query (`ResetTokenvalidationsQuery(string token)`). ⚠️ **It has a latent null-ref** (line ~47 dereferences `passwordReset.IsUsed` without null-guarding when `FirstOrDefaultAsync` returns null) and a **48-hour token-age cap** (line ~129) that would **reject a valid activation token** — P-03 mints the activation token with **72h** expiry. **Do not reuse this query as-is for activation.**
- **`Base.API/EndPoints/Auth/Mutations/AuthendicationMutations.cs` → `ResetPasswords` method (line ~433)** — the anonymous mutation shape for a token-consume endpoint (no `[CustomAuthorize]` — the caller has no session yet).

## Scope — build exactly this

### T-A11 · Provisioning GraphQL API (mutations)

Create `TenantProvisioningMutations : IMutations` (`[ExtendObjectType(OperationTypeNames.Mutation)]`), constructor-injecting `IHttpContextAccessor` (+ `IAuditLogWriter` if you emit audit). Expose **three** mutations:

1. **`ProvisionTenant`** — takes the wizard payload (a request DTO whose fields **exactly match `ProvisionTenantRequestDto`**, `CurrencyId` as `int`), resolves the acting `userId` from the `UserId` claim (pattern above), and sends `ProvisionTenantCommand`. **Populate `InitiatedByUserId`:** since P-03 set it to `null`, thread the resolved `userId` into the command so the handler stamps `run.InitiatedByUserId`. Preferred wiring:
   - Add an optional `int? InitiatedByUserId` to `ProvisionTenantCommand` (record param) **or** to `ProvisionTenantRequestDto`, and in `ProvisionTenant.cs` **step where the run header is created/loaded**, set `run.InitiatedByUserId ??= command.InitiatedByUserId` (only on first create, don't overwrite on resume). This is the *one* small edit to the P-03 handler you are permitted — a wiring change, not a step-logic change. State it in the hand-back.
   - The mutation must **reject** a missing/invalid `UserId` claim with `UnAuthorized` (provisioning is never anonymous). The `[CustomAuthorize("PLATFORM_TENANTS","PLATFORM_TENANT_PROVISION")]` on the command still enforces capability; the claim check gives a clean error + the id to stamp.
   - Return the `ProvisionTenantResult` (RunId + Status + per-step outcome) wrapped in `BaseApiResponse<T>` so the FE can route to the monitor.

2. **`ResumeProvisioningRun`** — takes `int runId`. Build a thin **`ResumeProvisioningRunCommand(int RunId, int? InitiatedByUserId = null) : ICommand<ProvisionTenantResult>`** (new, in the same `TenantProvisioning/Commands/` folder, gated `[CustomAuthorize("PLATFORM_TENANTS","PLATFORM_TENANT_PROVISION")]`). Its handler:
   - loads the run via `_dbContext.TenantProvisioningRuns.IgnoreQueryFilters().FirstOrDefault(r => r.RunId == runId && r.IsDeleted != true)` — 404 if missing;
   - refuses if `Status` is `SUCCEEDED` (nothing to resume) or `ABANDONED` (dead) — `BadRequestException` with a clear message; only `PAUSED_ON_ERROR` (and defensively `RUNNING`/`PENDING`) may resume;
   - deserializes `RequestPayloadJson` back into `ProvisionTenantRequestDto` and **re-invokes the engine by sending `ProvisionTenantCommand(dto)` via `IMediator`** — the P-03 engine finds the existing run by idempotency key and **resumes at the first non-`SUCCEEDED` step** (steps already `SUCCEEDED` are skipped). Do **not** reimplement step logic here; delegate.
   - The mutation resolves the acting user and passes it through (so a resume can stamp `InitiatedByUserId` if it was null).

3. **`AbandonProvisioningRun`** — takes `int runId, string? reason`, resolves the acting user (for audit), sends the existing `AbandonProvisioningRunCommand(runId, reason)`. Surface its `BadRequestException` (post-step-8 block / already-succeeded) as a clean `BaseApiResponse` error.

### T-A12 · O-03 Run Monitor — query side + screen

**Query side** — a `TenantProvisioningQueries : IQueries` (`[ExtendObjectType(OperationTypeNames.Query)]`) with:
- **`GetProvisioningRuns`** — paginated list (`[AsParameters] GridFeatureRequest`). Handler `GetProvisioningRunsQuery` reads `TenantProvisioningRuns.IgnoreQueryFilters().Where(r => r.IsDeleted != true)`, projects to a `ProvisioningRunResponseDto` (RunId, IdempotencyKey, CompanyId, CompanyName via `Company` nav, Mode, Status, StartedOn, CompletedOn, InitiatedByUserId, a computed `StepsSucceeded/9` progress, CreatedDate), newest-first. Gate the query/menu with `PLATFORM_TENANT_VIEW`.
- **`GetProvisioningRunById`** — scalar `int runId`. Handler eager-loads `.Include(r => r.Steps)` (`IgnoreQueryFilters()`), projects to a detail DTO carrying the run header **plus the ordered 9 steps** (StepNumber, StepCode, Status, AttemptCount, ErrorMessage, StartedOn, CompletedOn). Order steps by `StepNumber`.

**Screen (control-plane / `(master)` surface):** the **O-03 Run Monitor** — this is a **DASHBOARD/monitor-style control-plane screen**, not a tenant CRUD grid. Follow the project's control-plane/ops screen conventions and the UI-uniformity rules (design tokens only — no hex/px; @iconify Phosphor icons; solid `bg-X-600 + text-white` status chips/badges; shaped skeletons; empty/error states):
- **List view** — provisioning runs with a **status chip** per row (`PENDING` / `RUNNING` / `PAUSED_ON_ERROR` (amber) / `SUCCEEDED` (green) / `ABANDONED` (grey)), company name/code, mode, initiated-by, started/completed, and a **progress indicator** (steps succeeded / 9). Filter by status.
- **Detail view** — a **9-step vertical timeline** for the selected run: each step shows StepNumber + StepCode, its status chip, `AttemptCount` (if >1), timestamps, and — for a failed/paused step — the `ErrorMessage` prominently. Make the paused step visually obvious (that's what the operator is here to fix).
- **Actions** (each gated on the matching capability, and enabled only for the valid state):
  - **Resume** → `ResumeProvisioningRun(runId)` — visible/enabled only when `Status == PAUSED_ON_ERROR`; gated `PLATFORM_TENANT_PROVISION`.
  - **Abandon** → `AbandonProvisioningRun(runId, reason)` — a confirm dialog capturing an optional reason; visible only pre-`SUCCEEDED` and disabled if the BE would block it (post-step-8); gated `PLATFORM_TENANT_SUSPEND`. Surface the BE block message if the user tries anyway.
  - After Resume/Abandon, refetch the run so the timeline reflects the new state.
- **FE reuse-or-create:** search the component/screen registries first; reuse an existing status-chip / timeline / detail-drawer component if one fits, create if missing-and-static, escalate only if missing-and-complex.

### The account-activation endpoint (deferred from P-03)

Build the endpoint that **consumes** the P-03 activation token so the welcome-email link works. **Recommended: a dedicated activation command/query pair + anonymous mutation** (do **not** reuse `ResetPasswords`/`ResetTokenValidations` — the 48h age cap rejects the 72h token, the reset path doesn't clear the invitation flags, and the validation query has a null-ref bug).

1. **`ActivateAccountCommand(string Token, string NewPassword, string ConfirmPassword) : ICommand<ActivateAccountResult>`** (`Base.Application/Business/AuthBusiness/AccountActivation/Commands/`). Handler mirrors `ResetPasswords` **plus** activation semantics:
   - `IEncryptionService.ValidateAndDecryptToken(token)` → null ⇒ invalid-token result;
   - expiry check `tokenData.ExpiryDate <= DateTime.UtcNow` (**72h window — no extra 48h age cap**);
   - load the `PasswordReset` row by `TokenHash == token`, **null-guard it**, and reject if `IsUsed == true` (single-use);
   - find `User` by `UserName == tokenData.UserEmail`; reject if missing / `IsDeleted`;
   - `AuthExtensions.CreatePasswordHash(newPassword, out salt, out hash)`; set `PasswordHash/PasswordSalt`;
   - **clear the pending/invite state:** `MustChangePassword = false`, `IsPendingInvitation = false`, `IsActive = true` (verify these column names on `User`);
   - mark the `PasswordReset` row `IsUsed = true`; `SaveChangesAsync`;
   - **never** generate/return/log a password. Add a `FluentValidation` validator mirroring `ResetPasswordsCommandValidator`'s password-strength rules.
2. **`ActivateAccountTokenValidationQuery(string token) : IQuery<…>`** — the pre-check the activation page calls on load (valid? expired? already used? user email for display). Mirror `ResetTokenValidations` but **null-guard the `PasswordReset` lookup** and use the **72h** window. Returns validity + user email + expiry — never the token internals beyond that.
3. **Anonymous mutation** — expose `ActivateAccount` on an `AccountActivationMutations : IMutations` (or extend `AuthendicationMutations`) **without `[CustomAuthorize]`** (the invitee has no session). Same `BaseApiResponse<T>` + audit pattern as `ResetPasswords`; emit an `ACCOUNT_ACTIVATED` audit event.
4. **FE activation page (public, on the tenant host):** the welcome link lands here. **Reuse the existing reset-password public page** if one exists — clone it to an `/activate` (or equivalent) route that calls `ActivateAccountTokenValidationQuery` on load and `ActivateAccount` on submit, showing a "set your password" form. Keep it minimal; if a reset page already exists, this is a small clone, not a new design. Verify the link/route P-03's step-9 email template points to and match it (or note the mismatch for the PM).

## Out of scope for P-04 (do NOT build)

- **Any change to the 9-step engine logic.** The only permitted edit to `ProvisionTenant.cs` is threading `InitiatedByUserId` onto the run header. Do not touch step behaviour, ordering, or the pricing/entitlement calls.
- **`ops.Lead` / `ops.CommercialTerm` entities + the S-01/S-02/O-01 wizard UI** — P-05. `LeadId`/`CommercialTermId` stay nullable no-FK ints.
- **Go-live / `Company.Status → ACTIVE` / `OnboardedOn`** — P-06.
- **Impersonation, suspend/offboard of a live tenant, tenant-admin editing of Subdomain** — later prompts.
- **Re-seeding `PLATFORM_*` menus/capabilities/roles** — P-03's T-A9 seed already did it; you consume the gates. (If a needed menu/capability is genuinely missing, flag it — don't silently add one.)

## Definition of done

1. Solution **builds clean** (`dotnet build` real exit 0 — not "only a pre-existing error remained"; a build that reports only a known stub error checked zero files → not clean). **Do not run the BE build if the PM/user has said they'll build it — in that case, prove correctness by reading, and say the build was left to the user.**
2. **T-A11:** `ProvisionTenant`, `ResumeProvisioningRun`, `AbandonProvisioningRun` mutations exist, are gated by the right `PLATFORM_*` capabilities (via the commands), resolve the acting user from the `UserId` claim, and **`TenantProvisioningRun.InitiatedByUserId` is now populated** (no longer null) — with only the single documented wiring edit to the P-03 handler.
3. `ResumeProvisioningRunCommand` loads the run with `IgnoreQueryFilters()`, refuses `SUCCEEDED`/`ABANDONED`, and **delegates to `ProvisionTenantCommand`** (does not reimplement steps); resume correctly skips already-`SUCCEEDED` steps.
4. **T-A12:** `GetProvisioningRuns` (paginated) + `GetProvisioningRunById` (steps eager-loaded, ordered) queries exist, both `IgnoreQueryFilters()` + `IsDeleted != true`, gated `PLATFORM_TENANT_VIEW`. The O-03 screen lists runs with status + progress, shows the 9-step timeline with the failed step's `ErrorMessage`, and offers state-correct, capability-gated **Resume**/**Abandon** actions that refetch on success.
5. **Activation endpoint:** a dedicated `ActivateAccountCommand` + validation query + **anonymous** mutation consume the P-03 token, enforce **single-use** + **72h** expiry (no 48h cap), **null-guard** the `PasswordReset` lookup, clear `IsPendingInvitation`/`MustChangePassword` + set `IsActive`, and **never** produce a password. The public activation page consumes it and matches the welcome-email link.
6. **No schema change / no migration authored or run.** If you find a column genuinely missing, a **migration spec (markdown)** is produced for the user instead — nothing is added directly.
7. UI honours the uniformity rules (tokens only, Phosphor icons, solid status chips, skeleton/empty/error states) and the control-plane surface conventions; FE components reused-or-created per the registry-first rule.
8. A short **hand-back note** (see below).

## Report back to the PM session

State: build clean (Y/N, or "left to user"); the three mutations wired + `InitiatedByUserId` now populated (Y/N) and the exact one-line edit made to `ProvisionTenant.cs`; resume delegates-not-reimplements (Y/N); the two monitor queries + O-03 screen done (Y/N); the activation command/query/mutation + public page done (Y/N) and whether you reused an existing reset page; whether you added `InitiatedByUserId` to the command or the DTO; the welcome-email link/route you matched (or the mismatch you found); and **every property/table/route name that differed from this brief**. **Do not start P-05.**
