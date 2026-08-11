# S9 — Tenant subdomain cutover runbook

**This is configuration, not code.** Nothing here needs compiling and nothing here goes to the build
session. Every application-side link in the chain is already merged (P-19 Phase 2); what remains is
four settings and a restart.

**Substitute your real apex everywhere below.** This document writes `yourdomain.com`; the seeded
default writes `peopleserve.app`. Pick one and be consistent — a mismatch between the CORS entry and
the activation template is exactly the failure this runbook exists to prevent.

---

## 0. What is already true — do not rebuild any of this

| Link | Where | Behaviour |
|---|---|---|
| Subdomain stored per tenant | [ProvisionTenant.cs:736](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs#L736) | Validated as a DNS label (`^[a-z0-9-]+$`, no leading/trailing/double hyphen, ≤63 chars), checked against a reserved list, uniqueness pre-checked across **all** companies with `IgnoreQueryFilters` |
| Host → tenant | [HostTenantResolver.cs:84-90](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Services/Auth/HostTenantResolver.cs#L84-L90) | `CustomDomain` exact match first, then **first DNS label** vs `Subdomain`; active + not-deleted only; `www.` stripped; port stripped |
| Login page branding | [GetTenantLoginConfigQuery.cs:102-113](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/TenantLoginConfig/Queries/GetTenantLoginConfigQuery.cs#L102-L113) | Deliberately permissive — an unrecognised host still renders a login form, with default PSS branding |
| Credential gate | [GetUserCredential.cs:240-245](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Users/Queries/GetUserCredential.cs#L240-L245) | Fails closed. Unknown host → nobody authenticates. Tenant host → the user must hold an active role **in that company**. Platform host → platform role required. Both → refused (`HOST_MIXED_PLATFORM_TENANT_ROLES`) |
| Browser host reaches the API | [auth.ts:185](../../PSS_2.0_Frontend/src/infrastructure/lib/configs/auth.ts#L185) | `x-forwarded-host ?? host`, forwarded on the login mutation. `trustHost: true` (:330). **No custom cookie `domain`** ⇒ host-only session cookies ⇒ each subdomain is its own session. That isolation is correct; do not add a shared cookie domain |

**The application never talks to Cloudflare.** There is no DNS client in the backend. You do not
create a record per client — the single wildcard `*.app` record covers every tenant that will ever
exist. Provisioning a client = ops types the subdomain into the provisioning wizard.

**The Cloudflare API token is not read by the application either.** It exists solely for Traefik's
DNS-01 challenge when issuing the wildcard certificate (hosting guide, Step B/C).

---

## 1. `Cors:AllowedOrigins` — the silent killer

**Symptom if wrong:** the tenant login page renders perfectly, correct logo, correct colours — and
the login POST dies in the browser with a CORS error. Everything *looks* right, which is what makes
this the one to check first.

The policy is a fail-closed allowlist
([DependencyInjection.cs:57-70](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/DependencyInjection.cs#L57-L70)).
An empty or non-matching list allows **no** origin at all. The wildcard form works only because the
policy calls `SetIsOriginAllowedToAllowWildcardSubdomains()`, and that matches **exactly one label** —
`https://*.app.yourdomain.com` matches `hope.app.yourdomain.com` but **not** `a.b.app.yourdomain.com`.

```
Cors__AllowedOrigins__0=https://app.yourdomain.com
Cors__AllowedOrigins__1=https://*.app.yourdomain.com
Cors__AllowedOrigins__2=https://admin.yourdomain.com
```

Rules that bite:
- **No trailing slash.** The code trims one defensively, but do not rely on it.
- **Scheme must match exactly.** `https://` ≠ `http://`; they are different origins.
- **Include the apex `app.yourdomain.com` separately** — the wildcard does not cover the bare host.
- **The policy is built once at startup.** `reloadOnChange` does not rebuild it. **Restart the API.**

---

## 2. `Auth:PlatformHosts` — or platform staff are locked out

Empty ⇒ *no* host is a platform host outside Development
([HostTenantResolver.cs:111-116](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Services/Auth/HostTenantResolver.cs#L111-L116)).
Development silently allowlists `localhost` / `127.0.0.1` / `[::1]` (:35), which is precisely why
this passes every local test and then fails on the real domain.

```
Auth__PlatformHosts__0=admin.yourdomain.com
```

Matched after `Normalize()` — lowercase, port stripped, `www.` stripped. One entry per host.

---

## 3. `PLATFORM_ACTIVATION_URL_TEMPLATE` — or the new admin can never reach their own subdomain

[TenantActivationService.cs:96-111](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/OpsBusiness/TenantProvisioning/Services/TenantActivationService.cs#L96-L111):
if this platform-global row is absent **or still carries the localhost dev value**, the service falls
back to the single-host `Frontend:BaseUrl` and **every tenant's activation email points at the same
wrong host**. The tenant admin then has no way to set a password on their own subdomain.

`GetPlatformSettingAsync` resolves `CurrentValue` first, then `ParamDefaultValue`. `dev-localhost-activation-url.sql`
sets `CurrentValue`; on the deployed environment that override must be cleared or replaced.

```sql
-- Point the activation template at the real tenant wildcard host.
UPDATE sett."OrganizationSettings"
SET "CurrentValue" = 'https://{SUBDOMAIN}.app.yourdomain.com/{LANG}/activate?token={TOKEN}',
    "ModifiedBy"   = 2,
    "ModifiedDate" = now()
WHERE "CompanyId" IS NULL
  AND "ParamCode"  = 'PLATFORM_ACTIVATION_URL_TEMPLATE'
  AND "IsDeleted"  = FALSE;

-- Verify: expect three rows, none pointing at localhost.
SELECT "ParamCode", "ParamDefaultValue", "CurrentValue"
FROM sett."OrganizationSettings"
WHERE "CompanyId" IS NULL
  AND "ParamCode" IN ('PLATFORM_ACTIVATION_URL_TEMPLATE',
                      'PLATFORM_DEFAULT_LANG',
                      'PLATFORM_ADMIN_SUBDOMAIN')
  AND "IsDeleted" = FALSE
ORDER BY "ParamCode";
```

No row at all ⇒ `ops-lead-deal-seed.sql` was never applied on this environment. Apply it, then re-run
the update. `/{LANG}/activate?token=` is the real Next.js route (`src/app/[lang]/(auth)/activate`) —
do not invent a different path.

`PLATFORM_ADMIN_SUBDOMAIN` feeds `{SUBDOMAIN}` for **platform-staff** invitations
([PlatformStaffHelper.cs:215](../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/OpsBusiness/PlatformStaff/PlatformStaffHelper.cs#L215)) —
set it to `admin`, matching §2.

---

## 4. Routing and TLS — the Coolify half

Per `PSS-2.0-TENANT-DOMAIN-AND-COOLIFY-HOSTING-GUIDE.md`:

- DNS `A` record `*.app` → server IP. **One record, forever** (§4, line 95). If the free plan refuses
  the orange cloud on a wildcard, set that record to **DNS only** (§Step A note).
- Traefik must accept the wildcard host (`HostRegexp`) — Coolify's Domains field routes named hosts
  only (§5.4).
- Wildcard TLS via **DNS-01** — Let's Encrypt will not issue a wildcard over HTTP-01. This is what
  the Cloudflare API token is for. The guide recommends Option A (one named domain per tenant) for
  MVP-1 and Option B (wildcard cert) before tenant #15.
- `AllowedHosts` stays `"*"` (`appsettings.Example.json:97`) or Kestrel rejects the tenant `Host`
  header before any of §1–§3 ever runs.

---

## 5. Verify, in this order

1. `nslookup anythingatall.app.yourdomain.com` → the server IP. Proves the wildcard record.
2. Browse `https://<subdomain>.app.yourdomain.com` → tenant login page with **that tenant's** logo and
   colours. If it shows default PSS branding, `Company.Subdomain` does not match the first label —
   the resolver is permissive here by design, so this is a branding symptom of a data problem.
3. Log in as a user of that tenant → succeeds. If it fails **in the browser network tab with a CORS
   error**, go back to §1 and confirm the API was restarted.
4. Log in as a user of a *different* tenant on that same host → must be refused with the ordinary
   wrong-password message. This is the isolation test; do not skip it.
5. Log in as platform staff on `admin.yourdomain.com` → succeeds. On a tenant subdomain → refused.
6. Launch a tenant from the ops screen, open the activation email, confirm the link's host is the
   tenant's own subdomain and not `Frontend:BaseUrl`.

---

## 6. Known gap, not a blocker tonight

`Frontend:BaseUrl` is a single scalar. The activation link is the only outbound URL that is
tenant-aware (via §3's template); everything else built from `Frontend:BaseUrl` points at one fixed
host regardless of which tenant it concerns. That is a real per-tenant-links gap for MVP-2 — the fix
is the same shape as §3 (a token pattern, or resolving the host from `Company.Subdomain` at send
time), and it is deliberately out of scope here.
