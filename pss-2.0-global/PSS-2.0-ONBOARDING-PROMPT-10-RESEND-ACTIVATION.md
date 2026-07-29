# PSS 2.0 — ONBOARDING PROMPT 10 — Resend Tenant Activation Link

**Task ID:** T-A16 (fast-follow to T-A13 tenant detail + T-A14 platform comms)
**Surface:** BE (command + shared service extraction + GraphQL) · FE (`(master)` tenant detail action)
**Model:** Sonnet (scope is well-bounded; reuses existing code paths verbatim)
**Depends on:** T-A8 (Step 8 token), T-B6 (`TENANT_ADMIN_ACTIVATION` template), T-A13 (tenant detail screen), T-A14 (platform EMAIL provider resolution — mail must actually deliver)

---

## ① Why this exists

Provisioning creates the primary-admin user with **no password** + a single-use 72h activation token, then emails a passwordless activation link (Step 9). The admin clicks it, sets a password on the public `/[lang]/activate?token=…` screen, and **that activation flips the tenant `PROVISIONING → ACTIVE`** (go-live, `ActivateAccount` Step 6b).

**The gap:** if the welcome mail never arrives (the no-mail root cause fixed in P-08, or a bounce, or a 72h expiry), the admin has **no link** and there is **no way in the UI to re-send it**. The tenant is stranded at `PROVISIONING` forever. A platform operator must be able to resend the activation link from the tenant hub.

**This is NOT auto-activation.** The operator only re-sends the link; the tenant admin still sets their own password. No password is ever generated, emailed, or displayed — same invariant as everywhere in this flow.

---

## ② Reuse-first — extract, do not duplicate

The token-minting, activation-URL building, and template send already live as **private methods inside `ProvisionTenant.cs`** (`Step8_CreateAdminAsync` token block ~L847-871, `BuildActivationUrlAsync` ~L996, module resolution + `SendEmailByTemplateKeyAsync` ~L909-939, const `ActivationTemplateCode = "TENANT_ADMIN_ACTIVATION"` L978).

**Extract these into one reusable service** so Step 9 and Resend share a single code path and can never drift:

```
Base.Application/Business/OpsBusiness/TenantProvisioning/Services/
    ITenantActivationService.cs
    TenantActivationService.cs        (registered in DI alongside the other ops services)
```

Suggested surface (adapt names to match local conventions):

```csharp
public interface ITenantActivationService
{
    /// Reuse a live (unused, unexpired) token for the user, or mint a fresh 72h one. Returns the token hash.
    Task<string> EnsureLiveActivationTokenAsync(int userId, string userEmail, CancellationToken ct);

    /// Build /{lang}/activate?token=… — platform PLATFORM_ACTIVATION_URL_TEMPLATE wins, else Frontend:BaseUrl.
    Task<string> BuildActivationUrlAsync(string subdomain, string tokenHash, CancellationToken ct);

    /// Resolve module from the TENANT_ADMIN_ACTIVATION template (PSSCORE fallback) and send via
    /// SendEmailByTemplateKeyAsync. Returns the true send bool (never throws on a mail failure).
    Task<bool> SendActivationEmailAsync(
        string toEmail, string userName, string companyName, string subdomain,
        string activationUrl, DateTime tokenExpiresAt, CancellationToken ct);
}
```

Then **refactor `Step8`/`Step9` to call this service** (behaviour-preserving — same token reuse rule, same template, same URL logic, same non-fatal-on-mail-failure semantics). Verify the provisioning flow still compiles and behaves identically. If extraction proves too invasive to do safely in this pass, fall back to a **private duplicate inside the resend handler** and leave a `// TODO: unify with ProvisionTenant Step8/9` — but extraction is strongly preferred.

---

## ③ Backend — the command

**Location:** `…/OpsBusiness/TenantProvisioning/Commands/ResendTenantActivation.cs`

```csharp
[CustomAuthorize("PLATFORM_TENANTS", "PLATFORM_TENANT_PROVISION")]   // same gate as ResumeProvisioning
public record ResendTenantActivationCommand(int CompanyId) : ICommand<ResendTenantActivationResult>;

public record ResendTenantActivationResult(
    bool IsSuccess,
    bool EmailSent,          // false when the tenant/admin is valid but the mail provider failed — non-fatal
    string Message,
    string? MaskedEmail,     // e.g. "j•••@acme.org" — NEVER return the raw admin email to the client
    DateTime? TokenExpiresAt // UTC
);
```

**Handler logic (all reads `IgnoreQueryFilters()` — control-plane crosses the tenant filter; `IsDeleted != true`):**

1. **Load company** by `CompanyId`. Not found → `IsSuccess=false`, message "Tenant not found." Exclude `IsInternal == true`.
2. **Guard on status — resend is only for a not-yet-live tenant:**
   - `Status == "PROVISIONING"` → proceed.
   - `Status == "ACTIVE"` → reject: `"This tenant is already activated. The administrator should use Forgot Password to reset their credentials."` (Do **not** resend — an active admin has a password; resending an activation link to a live account is wrong.)
   - `Status == "SUSPENDED"` (or anything else) → reject: `"Activation cannot be resent for a {status} tenant."`
3. **Find the primary admin user:** `CompanyId == company.CompanyId && IsPendingInvitation == true && IsDeleted != true`, prefer the `BUSINESSADMIN` (`PrimaryRoleId → Role.RoleCode == "BUSINESSADMIN"`), newest first. None found → reject `"No pending administrator to invite for this tenant."` (An admin who already activated is `IsPendingInvitation == false`, so this correctly finds nobody once live — belt-and-suspenders with the status guard.)
4. **Ensure token:** `EnsureLiveActivationTokenAsync(user.UserId, user.Email!, ct)` — reuses a live token, mints a fresh 72h one if none.
5. **Build URL:** `BuildActivationUrlAsync(company.Subdomain, tokenHash, ct)`.
6. **Send:** `SendActivationEmailAsync(...)` → capture the real `bool`.
7. **Stamp** `user.InvitationSentAt = DateTime.UtcNow` (UTC) and `SaveChangesAsync`.
8. **Audit** (`IAuditLogWriter`): action `"TENANT_ACTIVATION_RESENT"`, severity `"HIGH"`, include `CompanyId` and the target user id.
9. **Return:** `IsSuccess=true` regardless of mail outcome (the token exists and is valid); `EmailSent=<bool>`; mask the email; return `TokenExpiresAt`. When `EmailSent==false`, message = `"Activation link regenerated, but the email could not be delivered — check the platform email provider (P-08)."` — mirrors Step 9's non-fatal-but-observable stance.

**UTC:** every `DateTime` is `DateTimeKind.Utc` (`DateTime.UtcNow`). **No secret hardcoded. No password generated.**

---

## ④ Backend — GraphQL

Add to `Base.API/EndPoints/Ops/Mutations/TenantProvisioningMutations.cs` (auth lives on the command record — no gate duplicated in the endpoint, matching the sibling mutations):

```csharp
/// Resends the passwordless activation link to a still-provisioning tenant's primary admin.
/// Gated by PLATFORM_TENANTS + PLATFORM_TENANT_PROVISION on the command.
public async Task<BaseApiResponse<ResendTenantActivationResult>> ResendTenantActivation(
    int companyId, [Service] IMediator mediator, CancellationToken cancellationToken)
{
    try
    {
        var result = await mediator.Send(new ResendTenantActivationCommand(companyId), cancellationToken);
        return BaseApiResponse<ResendTenantActivationResult>.PostSuccess(result);
    }
    catch (Exception ex)
    {
        return BaseApiResponse<ResendTenantActivationResult>.Error(ex.Message);
    }
}
```

> **GraphQL field name:** HotChocolate strips no prefix here (this is a mutation method, not a `Get*` resolver) → the field is `resendTenantActivation`. Confirm the emitted name and use it verbatim in the FE mutation — tsc cannot catch a wrong gql field name.

---

## ⑤ Frontend — the button on the tenant hub

**File:** `src/presentation/components/page-components/ops/tenants/tenant-detail-page.tsx` (the read-only P-07 hub). Add the mutation + a header action button next to **Refresh** / **View provisioning runs** (L132-151).

- **Mutation:** new `RESEND_TENANT_ACTIVATION_MUTATION` in `src/infrastructure/gql-mutations/ops-mutations/` (mirror the existing ops mutation files); variable `companyId: Int!`; select `result { data { isSuccess emailSent message maskedEmail tokenExpiresAt } message }`.
- **Visibility:** render the button **only when `tenant.status === "PROVISIONING"`** (an active tenant needs Forgot Password, not resend). Also gate on the manage capability — reuse `usePlatformCapabilities({ menuCode: "PLATFORM_TENANTS" })` and require the provision/manage capability (align with how the page already reads caps; view-only operators see the page but not this button).
- **Button:** `size="sm"`, `variant="outline"`, icon `ph:paper-plane-tilt-duotone`, label **"Resend activation link"**. Disabled + spinner (`ph:circle-notch animate-spin`) while the mutation is in flight.
- **Result feedback (toast — reuse the app's toast/sonner util already used on other `(master)` screens):**
  - `isSuccess && emailSent` → success toast: `"Activation link sent to {maskedEmail}."`
  - `isSuccess && !emailSent` → warning toast with the returned `message` (regenerated but not delivered → check the email provider).
  - `!isSuccess` → error toast with `message`.
- After a successful call, `refetch()` the tenant (so `InvitationSentAt`/status reflect any change). **No password, no raw email, no token is ever shown in the UI.**

**UI tokens:** solid icon containers / status styling per house rules; no hex/px; xs→xl responsive; keep it on the same header row as the other two actions.

---

## ⑥ Acceptance

1. A tenant stuck at `PROVISIONING` (welcome mail never delivered) → operator opens `/ops/tenants/[id]`, clicks **Resend activation link**, receives the email, sets a password, tenant flips to `ACTIVE`. End-to-end, no SQL.
2. If the prior token expired (>72h), resend **mints a fresh 72h token**; the old link stays dead.
3. If a live token still exists (<72h, unused), resend **reuses it** (no orphan tokens piling up).
4. Clicking resend on an **`ACTIVE`** tenant is impossible (button hidden) and the command **rejects** it server-side even if called directly.
5. Mail-provider down → command returns `IsSuccess=true, EmailSent=false` with the warning message; the token is still valid; nothing throws.
6. A `PLATFORM_TENANT_VIEW`-only operator (no provision capability) does **not** see the button, and the command rejects their direct call.
7. `resendTenantActivation` appears in the schema; the FE mutation uses the exact emitted field name.
8. `Step8`/`Step9` provisioning still behaves identically after the service extraction (welcome mail on a fresh provision is unchanged).

---

## ⑦ Out of scope (do not build)

- Suspend / reactivate / plan-change / impersonation on the tenant hub (separate fast-follow).
- Any change to the public `/activate` screen, `ActivateAccount`, or the go-live flip (already done).
- Platform comms CRUD screen (T-A15 / PROMPT-09).
- SMS/WhatsApp activation (email only).
- No schema change. No migration. No seed (the `TENANT_ADMIN_ACTIVATION` template + platform provider already exist from T-B6 / T-A14).

---

## ⑬ Build Log

_(append per session — keep last 5; git holds the rest)_

- **PENDING** — generated by PM/prompt-engineer 2026-07-29. Not yet built.
- **BUILT** — 2026-07-29. BE `dotnet build` 0 errors (652 pre-existing warnings); FE `tsc --noEmit --incremental false` exit 0, zero diagnostics.
  - **② Extraction taken (not the fallback duplicate).** New `TenantProvisioning/Services/ITenantActivationService.cs` + `TenantActivationService.cs`, registered scoped in `Base.Application/DependencyInjection.cs`. `ProvisionTenant.cs` Step 8's token block, Step 9's token-read + module-resolution + placeholder + send block, the 3 private consts and the private `BuildActivationUrlAsync` are all gone; the handler ctor dropped `IEncryptionService` / `IEmailTemplateService` / `IConfiguration` and took `ITenantActivationService`.
  - **Two deliberate deltas from §②'s suggested surface:**
    1. `EnsureLiveActivationTokenAsync` returns `TenantActivationToken(TokenHash, ExpiresAt)`, not a bare `string` — the expiry is needed by both Step 9's `{EXPIRY_DATE}` placeholder and the resend's `TokenExpiresAt`, and returning it from the same call is what stops callers re-querying `auth.PasswordResets` (the exact drift this extraction removes).
    2. Step 9 behaviour change, intentional: a resumed run whose step-8 token had aged past 72h used to `throw NotFoundException("No live activation token found…")` and strand the run. It now mints a fresh link. Fresh-provision behaviour (acceptance 8) is unchanged — the step-8 token is minutes old, so `EnsureLive…` reuses it.
  - **③** `ResendTenantActivation.cs` built to spec. `IAuditLogWriter` has no generic writer, so the `TENANT_ACTIVATION_RESENT` / `HIGH` audit goes through `WriteAuthEvent` (the `ActivateAccount` precedent, and the only writer carrying `severity`) with the tenant id in `correlationId: "COMPANY:{id}"` so the row names both subjects. `status` is `SUCCESS` / `EMAIL_NOT_SENT`.
  - **④** Emitted field confirmed `resendTenantActivation`; no acting-user claim required (the command has no `InitiatedByUserId`), unlike its siblings.
  - **⑤** Button gated on `canProvision && status === "PROVISIONING"`, on the same header row as Refresh. `usePlatformCapabilities` is a directory, and it exposes `canProvision` — same flag `provisioning-run-detail-page.tsx` uses for Resume.
  - **Not verified by build, needs a runtime pass:** acceptance 1–6 are all runtime paths (real send, 72h expiry reuse/mint, ACTIVE rejection, provider-down, view-only operator). No schema change, no migration, no seed — as scoped.
