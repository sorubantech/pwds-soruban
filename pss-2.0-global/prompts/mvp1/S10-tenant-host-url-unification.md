# S10 — Tenant host unification: one root domain, tenant-aware sign-in/sign-out, unknown-host refusal

**Scope:** backend (`PSS_2.0_Backend`) + frontend (`PSS_2.0_Frontend`) + one platform seed script.
**No EF migration.** No new column. No menu/module data change.

---

## 0. Working rules for the session executing this

- **Never `git commit`.** Stage only (`git add`) and report. No push, no amend, no tag. Never add a
  `Co-Authored-By` trailer or a "Generated with Claude Code" line anywhere.
- **Do not run `dotnet build`** — the user builds the backend. Make compiling changes and hand off.
- **Do not create EF migrations** and do not edit `ModelSnapshot`. This change needs none; if you
  believe it does, stop and report instead of adding one.
- **Do not edit, stage or revert** `src/application/configs/navigation-configs/BaseUrlConfig.ts` —
  it is user-managed.
- Do not probe ports, processes or API liveness. Do not gate any deliverable on the environment.
- Do not change the NextAuth session strategy, `maxAge`, the credentials-provider shape, or any
  existing JWT-callback field. You may ADD fields to the token/session.
- Never print or paste a secret value. Key *names* only.

**Run order — S9 first.** [S9](S9-tenant-subdomain-cutover.md) §3 contains a hand-run `UPDATE` that
points `PLATFORM_ACTIVATION_URL_TEMPLATE.CurrentValue` at the real wildcard host, and
`dev-localhost-activation-url.sql` may have left a localhost `CurrentValue` behind. S10's script only
rewrites rows still holding the OLD literal pattern, so running it before S9's update leaves a stale
`CurrentValue` shadowing the new `ParamDefaultValue` (`GetPlatformSettingAsync` prefers
`CurrentValue`). **Before writing the S10 script, read the live rows** — `ParamCode`,
`ParamDefaultValue`, `CurrentValue` for the two templates plus `PLATFORM_DEFAULT_LANG` — and make the
script handle whichever of the two values is actually in force. If S9 has already been run, S10's
`UPDATE` must also convert that `CurrentValue` to the `{ROOTDOMAIN}` form.
- `PSS_2.0_Backend` and `PSS_2.0_Frontend` are **nested git repos** — `cd` into each to stage.
  Verify you are in the `pwds-soruban - Copy` worktree, not a sibling.

---

## 1. The problem, precisely

The platform now serves tenants on a wildcard host — `*.<root>.app`. Three things are wrong.

### 1.1 The root domain is a literal, repeated in several places

`app.Companies.Subdomain` stores the **bare label only** (`hope`), which is correct and must stay
that way. The `.app` root is currently spelled out inside individual URL templates:

- `sql-scripts-dyanmic/ops-lead-deal-seed.sql` — `PLATFORM_ACTIVATION_URL_TEMPLATE`
  = `https://{SUBDOMAIN}.peopleserve.app/{LANG}/activate?token={TOKEN}`
- `sql-scripts-dyanmic/platform-login-url-template-seed.sql` — `PLATFORM_LOGIN_URL_TEMPLATE`
  = `https://{SUBDOMAIN}.peopleserve.app/{LANG}/login`
- `sql-scripts-dyanmic/dev-localhost-activation-url.sql` — the dev override of the same

Every new tenant-addressed URL therefore has to remember the root by hand, and one of them is
already wrong or unseeded in the deployed environment. **The root domain must be stated once.**

### 1.2 Post-activation "Go to Sign In" and logout land on the wrong host

The activation flow already has the right shape and must be *repaired, not redesigned*:

- `PSS_2.0_Backend/.../AuthBusiness/AccountActivation/TenantLoginUrlHelper.cs` resolves
  `CustomDomain` → `PLATFORM_LOGIN_URL_TEMPLATE` → `null`.
- `PSS_2.0_Frontend/src/presentation/pages/auth/activate/activate-form.tsx:203` already prefers
  the mutation's `loginUrl` over a relative `/{lang}/login`.

So activation is one seeded value away from correct. **Logout is not wired at all**:
`src/application/stores/common-stores/logout-store.ts` initialises `logoutUrl` from the constant
`LOGIN_URL = "/en/login"` (`src/application/configs/navigation-configs/CommonUrlConfig.ts`) and
`src/presentation/hooks/useAuth/useLogout.ts` redirects there. A user who arrived on the platform
host, or whose session began anywhere other than their own subdomain, is signed out onto the
platform login page. **A tenant user must always be signed out onto their own tenant login URL.**

### 1.3 An unknown host still renders a login page

`PSS_2.0_Backend/.../AuthBusiness/TenantLoginConfig/Queries/GetTenantLoginConfigQuery.cs` treats
`HostKind.Platform` and `HostKind.Unknown` identically: both get `DefaultConfig` and a login form.
`HostTenantResolver.ResolveAsync` (`Base.Infrastructure/Services/Auth/HostTenantResolver.cs`)
already returns `HostKind.Unknown` for a host that matches no `CustomDomain`, no `Subdomain` and no
`Auth:PlatformHosts` entry. The credential gate refuses these hosts, but the *page* still renders —
so any random label on the wildcard (`whatever.<root>.app`) shows a PeopleServe-branded sign-in box
for a tenant that does not exist. **An unknown host must not render a login page at all.**

---

## 2. What to build

### 2.1 One platform setting for the tenant root domain — `PLATFORM_TENANT_ROOT_DOMAIN`

Add a platform-global `sett."OrganizationSettings"` row (`CompanyId IS NULL`, `SettingGroupCode
= 'PLATFORM'`, `CanUserOverride = FALSE`), following `platform-login-url-template-seed.sql` verbatim
as the shape reference (idempotent `WHERE NOT EXISTS`, PostgreSQL, `now()`, double-quoted
identifiers, `TRUE`/`FALSE`).

- `ParamCode` — `PLATFORM_TENANT_ROOT_DOMAIN`
- `ParamDataType` — `STRING`
- `ParamDefaultValue` — the real wildcard root **without** a leading dot and **without** a scheme,
  e.g. `peopleserve.app`. Ask the user for the live value before writing the file; if unavailable,
  seed the existing literal and say so in the handback.
- Description must state: this is the single source of the tenant apex; `{SUBDOMAIN}` is the bare
  label stored in `app.Companies.Subdomain`; a tenant's `CustomDomain` always outranks it.

Then make the two URL templates express the root through a token rather than a literal:

- `PLATFORM_ACTIVATION_URL_TEMPLATE` → `https://{SUBDOMAIN}.{ROOTDOMAIN}/{LANG}/activate?token={TOKEN}`
- `PLATFORM_LOGIN_URL_TEMPLATE` → `https://{SUBDOMAIN}.{ROOTDOMAIN}/{LANG}/login`

Deliver this as **one new idempotent script**, `sql-scripts-dyanmic/platform-tenant-root-domain-seed.sql`,
which (a) inserts `PLATFORM_TENANT_ROOT_DOMAIN` when absent and (b) `UPDATE`s the two template rows
to the `{ROOTDOMAIN}` form **only where they still hold the old literal pattern** — never blindly,
so an environment that was hand-tuned is not clobbered. Include the expected row counts as a comment
so the user can verify the run. Do NOT edit the historical seed files in place.

### 2.2 One backend helper that builds every tenant URL — and every caller uses it

Create `Base.Application/Business/AuthBusiness/AccountActivation/TenantHostResolver.cs` (or place it
beside `TenantLoginUrlHelper` under a name that reads well; keep it in `Base.Application` so both the
activation and auth paths reach it). It owns:

- `Task<string?> GetRootDomainAsync(...)` — reads `PLATFORM_TENANT_ROOT_DOMAIN` via the same
  `LeadHelper.GetPlatformSettingAsync` accessor `TenantLoginUrlHelper` already uses. Trims, lowercases,
  strips a leading `.` and any scheme.
- `Task<string?> ResolveTenantHostAsync(IApplicationDbContext, int? companyId, ct)` — `CustomDomain`
  when set, else `{Subdomain}.{root}`, else `null`. Null when `companyId` is null (platform staff
  sign in on the host they are standing on) and null when the deployment has no root configured.
- `Task<string?> ResolveLoginUrlAsync(...)` — the tenant's absolute login URL.

Then:

- **Rewrite `TenantLoginUrlHelper.ResolveAsync` to delegate** to the new helper. Keep its public
  signature and its contract exactly: null is a normal answer, and it **never throws** — a sign-in
  hint must not be able to fail an activation. Keep the `try/catch`.
- Make the template substitution understand `{ROOTDOMAIN}` **in addition to** `{SUBDOMAIN}`/`{LANG}`,
  case-insensitively, so an environment still holding the old literal template keeps working.
- Find the activation-link builder (`TenantActivationService.BuildActivationUrlAsync` /
  `ProvisionTenantCommandHandler`, reachable from
  `Base.API/EndPoints/Ops/Mutations/TenantProvisioningMutations.cs`) and route its `{ROOTDOMAIN}`
  substitution through the same helper. Its `Frontend:BaseUrl` fallback for single-host deployments
  stays untouched.

**Validation at the provisioning boundary — ALREADY BUILT, verify only.**
`ProvisionTenantCommandValidator` (`.../OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs:106`)
already enforces the DNS-label rule `^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$` (so a dot or a `.app`
suffix is rejected), ≤63 chars, no consecutive hyphens, a reserved-word blocklist
(`www app api admin mail ops billing master portal static cdn status help support`), and
cross-tenant uniqueness via `IgnoreQueryFilters`. **Do not rewrite it.** The only gap worth closing:
the blocklist is a hardcoded set that does not include the deployment's `Auth:PlatformHosts` entries.
Either cross-check those at validation time or leave it — if you leave it, say so in the handback.

### 2.3 Sign-out follows the tenant, not the platform

The tenant login URL must be known to the client without a round trip at logout time.

- Backend: add `TenantLoginUrl` (nullable string) to the token-generation DTO chain already carrying
  `IsPlatformUser` — `Base.Application/Schemas/AuthSchemas/AuthSchemas.cs`
  (`TokenResponseDto`) and the user-details DTO in `UserSchemas.cs`. Populate it in
  `AuthBusiness/Users/Queries/GetUserCredential.cs` (**both** return paths) and recompute it in
  `SwitchCompany.cs`, using `TenantHostResolver`. Platform users get `null`, exactly as
  `TenantLoginUrlHelper` already specifies. These files are already modified and staged-but-unbuilt
  from the `IsPlatformUser` work — extend that same edit, do not fork it.
- Frontend: carry it through `src/infrastructure/lib/configs/auth.ts` (`authorize` → `User` → `jwt`
  → `session`) and `src/domain/types/third-party/extended-types/auth-types/index.d.ts`, mirroring
  how `isPlatformUser` is carried. **Add fields only** — no change to strategy, `maxAge`, or the
  existing callback fields.
- On successful login, set the logout store: `useLogoutStore.getState().setLogoutUrl(tenantLoginUrl
  ?? LOGIN_URL)` at the point `useAuth.login` establishes the session. `useLogout` already redirects
  to `logoutUrl`, so no change is needed there beyond confirming `clearSessionState()` does not wipe
  the value before the redirect reads it — read
  `src/application/utils/clearSessionState.ts` and order the calls so the redirect target survives
  (capture it into a local before clearing).
- **Correct the store default while you are there.** `logout-store.ts` seeds `LOGIN_URL = "/en/login"`,
  a hardcoded `en`. Make the fallback locale-aware (relative `/{lang}/login`) rather than pinned.

Expected behaviour after this: a tenant user signs out and lands on
`https://<their-subdomain>.<root>/{lang}/login` (or their custom domain), never on the platform host.
A platform user signs out onto the relative platform login. No user-type conditional in a component —
the difference is one nullable value the server signed.

### 2.4 An unknown host must not render a login page

The resolver already produces the verdict; the query throws it away.

- `TenantLoginConfigDto` / `GetTenantLoginConfigQuery.cs`: stop collapsing `Platform` and `Unknown`.
  Surface the host verdict on the DTO — either extend `TenantLoginConfigResolvedBy` with an
  `Unknown` member or add an explicit `hostKind` field; pick one and use it consistently. `Platform`
  keeps returning `DefaultConfig` and keeps rendering the PSS login page. `Unknown` returns a DTO
  the frontend can refuse on. Keep the 5-second cache TTL for the non-tenant branch.
- Frontend: `src/application/utils/tenant/getTenantLoginConfig.ts` passes the verdict through.
  The login route (`src/app/[lang]/(auth)/login`) renders, for an unknown host, a plain unbranded
  "This address isn't set up" page — no logo, no tenant name, no login form, no register or
  forgot-password link, and no hint about which tenants exist (a host-probing oracle is exactly what
  we are closing). Return HTTP 404 from the route where Next.js allows it (`notFound()`), so a
  crawler and a monitor both read it correctly.
- Do NOT break: `localhost` / `127.0.0.1` in Development are platform hosts by
  `HostTenantResolver.DevelopmentPlatformHosts`, and `?_tenant=<slug>` still overrides in
  Development only. Both must keep rendering a login page. Verify by reading the resolver — do not
  add a second dev bypass.
- `getDefaultLoginConfig()` stays the fallback for *transport* failure (backend unreachable, HTTP
  error, empty payload). A transport failure is not an unknown host and must NOT produce the refusal
  page — otherwise a backend blip locks every tenant out of their own login screen. Keep the two
  paths distinct and comment why.

---

## 3. Sweep — the `.app` is not handled "in all areas"

The user's report is that the root domain is applied unevenly. Enumerate the tenant-host builders
and route each one through §2.2, or record why it is exempt. Known call sites to check (this list
is a starting point, not a boundary — grep `Subdomain` across `PSS_2.0_Backend/PeopleServe` and
verify each hit):

- `AccountActivation/TenantLoginUrlHelper.cs` — §2.2
- the activation-link builder behind `TenantProvisioningMutations.cs` — §2.2
- `DonationBusiness/OnlineDonationPages/Commands/OnlineDonationPageTenantResolver.cs` — return-URL
  origin allow-list (`request host ∪ CustomDomain ∪ Subdomain`). A bare-label comparison against a
  host's **first label** is correct and must stay; do not "fix" it into a full-host comparison.
- `InitiateOnlineDonation.cs` (~line 544), `InitiateP2PDonation.cs`, `StartP2PFundraiser.cs`,
  `InitiateEventRegistration.cs`, `GetCrowdFundBySlug.cs`, `GetEventRegistrationPageBySlug.cs`,
  `GetOnlineDonationPageBySlug.cs` — all resolve a tenant *from* a hostname (first-label match).
  These are consumers, not builders; they are already root-agnostic. **Confirm and leave alone.**
- Anything that emails or renders an absolute tenant link (invites, receipts, intimations,
  notification deep links) — these are builders and must use §2.2.

Report the exemptions explicitly in the handback. Silence on a call site reads as "handled".

---

## 4. Acceptance

Written as checks the user can run by hand; do not gate delivery on running them.

1. Provision a tenant with subdomain `demo`. The activation email link is
   `https://demo.<root>/{lang}/activate?token=…` — no `.app` typed anywhere but the root-domain row.
2. Set the password on that link. The success panel's **Go to Sign In** points at
   `https://demo.<root>/{lang}/login`, not at a relative path and not at the platform host.
3. Sign in as that tenant user, then sign out. The browser lands on
   `https://demo.<root>/{lang}/login`.
4. Set `CustomDomain` on the same company. Repeat 2 and 3 — the custom domain wins both times.
5. Sign in as a platform user and sign out — relative platform login, no tenant host.
6. Visit `https://nosuchtenant.<root>/{lang}/login` — refusal page, no form, no branding, 404.
7. Visit the platform host's login and `localhost` in Development — both still render normally.
8. Attempt to provision a tenant with subdomain `demo.<root>` or `www` — rejected by the backend
   validator with a readable message, not a 500.
9. `npx tsc --noEmit` in `PSS_2.0_Frontend` is clean.

---

## 5. Handback

Report, in this order: files changed per repo; the SQL script name and the exact rows it touches with
expected counts; every §3 call site with handled/exempt and the reason; anything you could not verify
without running the app; and the confirmation that nothing was committed. State plainly if any part
of §2 was left undone and why — do not narrow the scope silently.
