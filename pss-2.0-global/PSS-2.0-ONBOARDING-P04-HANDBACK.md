# PSS-2.0 · P-04 — Provisioning API & Run Monitor · HAND-BACK

**Status:** ✅ Complete.
**Backend build:** `dotnet build` → **0 Errors**, 18 Warnings (pre-existing). **EXIT=0**.
**Frontend typecheck:** `npx tsc --noEmit --incremental false` → **no diagnostics, EXIT=0** (4,907 project files checked; all new files confirmed in `--listFiles`).

No migration authored or run. No SQL executed against any DB. No entity/column added — P-04 is a resolver + UI layer over P-03's existing tables. **P-05 not started.**

---

## 1. Deliverables

### T-A11 — Provisioning GraphQL API (BE)

| Artifact | Notes |
|---|---|
| `Base.API/EndPoints/Ops/Mutations/TenantProvisioningMutations.cs` | `provisionTenant`, `resumeProvisioningRun`, `abandonProvisioningRun`. Holds `IHttpContextAccessor`; `TryGetActingUserId` resolves the acting platform user from the JWT **`UserId`** claim and returns `UnAuthorized` if absent/unparseable. Authorization itself stays on the command records — **no gate duplicated at the endpoint**. |
| `ProvisionTenantInputDto` (same file) | Wizard input type, mirrors `ProvisionTenantRequestDto` field-for-field. GraphQL input name: **`ProvisionTenantInputDtoInput`**. `CurrencyId` is an **int FK** → `com.Currencies`, not an ISO string (P-03 deviation #1). |
| `ProvisionTenant.cs` (P-03 handler) | **The one permitted edit:** `InitiatedByUserId` is now stamped on the run header from the acting user, closing P-03 deviation #3 (`ICurrentUserService` does not exist). Nothing else in the handler was touched. |

### T-A12 — O-03 Provisioning Run Monitor

**Backend queries** — `Base.API/EndPoints/Ops/Queries/TenantProvisioningQueries.cs`, both gated `[CustomAuthorize("PLATFORM_TENANTS","PLATFORM_TENANT_VIEW")]`:
- `getProvisioningRuns(request: GridFeatureRequest)` → paginated run headers (+ `stepsSucceeded` / `totalSteps` roll-up, `companyName` join).
- `getProvisioningRunById(runId: Int!)` → header + `leadId`, `commercialTermId`, `requestPayloadJson`, and the ordered `steps[]`.

**Frontend** (all greenfield — `(master)` previously held only `masterdashboard/`):

| Layer | File |
|---|---|
| DTOs | `src/domain/entities/ops-service/TenantProvisioningDto.ts` |
| Queries | `src/infrastructure/gql-queries/ops-queries/TenantProvisioningQuery.ts` |
| Mutations | `src/infrastructure/gql-mutations/ops-mutations/TenantProvisioningMutation.ts` |
| Capability hook | `src/presentation/hooks/usePlatformCapabilities/index.ts` |
| Components | `src/presentation/components/page-components/ops/provisioningruns/` — `provisioning-run-list-page.tsx`, `provisioning-run-detail-page.tsx`, `step-timeline.tsx`, `run-status-chip.tsx`, `abandon-run-dialog.tsx` |
| Routes | `src/app/[lang]/(master)/ops/tenants/provisioning-runs/page.tsx` and `.../[runId]/page.tsx` |

Behaviour as specified: status chips + `n/9` progress on the list; a 9-step vertical timeline on the detail (step number, code, status chip, `AttemptCount` badge when > 1, start/complete stamps) with the failed step's `ErrorMessage` in a destructive-bordered block; **Resume** only when `Status == PAUSED_ON_ERROR` and only with `PLATFORM_TENANT_PROVISION`; **Abandon** (confirm dialog + optional reason) only before `SUCCEEDED`/`ABANDONED` and only with `PLATFORM_TENANT_SUSPEND`; both refetch on success.

### Account activation (deferred from P-03)

| Artifact | Notes |
|---|---|
| `Base.Application/.../AuthBusiness/AccountActivation/Commands/ActivateAccount.cs` | Command + handler + validator. Consumes the single-use token, sets the user's own password, clears `MustChangePassword` / `IsPendingInvitation`, sets `IsActive`. |
| `.../Queries/ActivateAccountTokenValidation.cs` | Pre-flight: `isValid`, `isUsed`, `message`, `userEmail`, `expiresAt`. |
| `Base.API/EndPoints/Auth/{Mutations,Queries}/AccountActivation*.cs` | **Anonymous by design** — each in its own class so no class-level `[CustomAuthorize]` can ever be inherited onto it. |
| FE | `src/presentation/pages/auth/activate/` (+ `(auth)/activate/page.tsx`), `AccountActivationDto.ts`, `AccountActivationQuery.ts`, `AccountActivationMutation.ts`. |

**No password is generated, emailed, or displayed anywhere.** The token is the only credential and is burned on use. The FE mirrors `ActivateAccountCommandValidator` exactly (min 8, upper + lower + digit, one special char, confirmation must match) and shows a live rule checklist; expired / already-used / missing-token links each get their own explicit panel before any typing.

---

## 2. ⚠️ Decisions & gaps the PM must action

1. **The welcome email does not carry an activation link — the invited admin cannot currently reach `/activate`.** This is the blocking finding.
   - P-03 step 8 (`ProvisionTenant.cs` ~786-810) mints a 72h single-use `PasswordReset` row (`TokenHash = encryptedToken`).
   - P-03 step 9 (`Step9_SendWelcomeAsync`, ~813-836) sends template `USER_WELCOME_INVITE` with placeholders **only** `AdminName` and `CompanyName` — **the token is never passed**.
   - The seeded `USER_WELCOME_INVITE` body (`sql-scripts-dyanmic/UserManagement-sqlscripts.sql:455-488`) expects `{{USER_NAME}}`, `{{TEMP_PASSWORD}}`, `{{EXPIRY_DATE}}`, `{{INVITE_LINK}}`, `{{CURRENT_YEAR}}` — so neither the names nor the link match. `SendUserInvite.cs:66` already passes `INVITE_LINK = ""` with the comment *"placeholder — FE base URL unknown at BE level"*.
   - **Not fixed here on purpose:** P-04 permits exactly one edit to the P-03 handler (`InitiatedByUserId`).
   - **Recommendation:** a dedicated `TENANT_ADMIN_ACTIVATION` template whose `{{ACTIVATION_LINK}}` is `{configured FE base URL}/{lang}/activate?token={encrypted token}`, plus a config key for that base URL. The FE page is built and waiting on exactly that query-string contract. Note the seeded template also implies a temp password — that contradicts the no-password rule and should be dropped from the tenant-admin path.

2. **No reset-password public page exists to clone.** The prompt said "reuse the existing reset-password public page *if one exists*". `(auth)/forgot` is a **mock** (`setTimeout`, no mutation). The activation page was therefore built fresh, styled consistently with `(auth)/forgot` (same card, logo, gradient CTA). `(auth)/layout.tsx` is a bare passthrough with its RouteGuard commented out, so it is genuinely the unauthenticated surface — correct home for `/activate`.

3. **The list-page status filter is client-side over the current page.** `GridFeatureRequest` exposes no status predicate today, so filtering to e.g. `PAUSED_ON_ERROR` only narrows the 25 rows already fetched. Coded with an inline comment. Fix = a server-side status filter on `getProvisioningRuns` (or use `advancedFilter`) — worth doing before there are many runs.

4. **`useCapablities` / `useAccessCapability` cannot serve `PLATFORM_*`.** Both project onto a closed allow-list of business capabilities, and the `@client` resolver `capabilitiesByMenuCode` returns `[]` unless **both** `menuCode` and `moduleCode` are supplied (`ROLECAPABILITIES_BY_MENU_CODE_QUERY` passes only `menuCode`). A dedicated `usePlatformCapabilities` hook was added rather than widening the shared one. Consider unifying later.

5. **Route vs. seeded menu URL.** The T-A9 seed gives `PLATFORM_TENANTS` the URL `/ops/tenants`, but the monitor lives at `/ops/tenants/provisioning-runs`. `/ops/tenants` itself (the tenant list) is **not implemented** — later-prompt scope. Either point the seeded menu at the monitor for now, or land the tenant list next.

6. **`checkSubdomain` was not built.** The task list's T-A11 row mentions it; the P-04 prompt's T-A11 section does not. Treated the prompt as authoritative. It is needed by the O-01 wizard (T-B4) for live availability — flag it for that prompt.

7. **`provisionTenant` FE mutation document is written but unexercised.** The wizard that calls it is T-B4 scope; the document is in place with the verified `ProvisionTenantInputDtoInput` type name.

8. **Environment note (unrelated to the code):** the claude.ai MCP connectors (Gmail, Google Calendar, Google Drive, Microsoft 365, html-to-figma) are unauthorized in this session and cannot be OAuth'd non-interactively — authorize them in claude.ai connector settings if a later prompt needs them.

---

## 3. Suggested next steps

1. Decide on item 2.1 (activation link + template) — it blocks the end-to-end onboarding walkthrough.
2. Apply `sql-scripts-dyanmic/ops-platform-rbac-seed.sql` (user-owned) and bind at least one internal user to a `PLATFORM_*` role, or the monitor renders its access-denied panel for everyone.
3. Then P-05.
