# Tenant Domains & Coolify Hosting Guide

> **Written:** 2026-08-05 · **Applies to:** MVP-1 and MVP-2
> **Bottom line up front:** giving each charity its own web address needs **no new code**. It is DNS + one Coolify setting + one database column.

---

## 1. Why there's nothing to build

The application already decides "which charity is this?" from the web address the browser asked for.

`Base.Infrastructure/Services/Auth/HostTenantResolver.cs` — the single host→meaning resolver:

| Step | What it does | Line |
|---|---|---|
| Normalise | strips the port, lowercases, strips a leading `www.` | `Normalize()` |
| Is it the **platform**? | matches the `Auth:PlatformHosts` config list | `IsPlatformHost` |
| Is it a **custom domain**? | `Companies.CustomDomain == host`, active, not deleted | `MatchCustomDomainAsync` |
| Is it a **subdomain**? | first label of the host vs `Companies.Subdomain` | `MatchSubdomainAsync` |
| Nobody's? | `HostKind.Unknown` — **fails closed**, login page renders with default branding but refuses everyone | end of `ResolveAsync` |

So there are exactly **two database columns** behind the whole feature:

```
app."Companies"."Subdomain"      →  hope     →  hope.app.yourdomain.com
app."Companies"."CustomDomain"   →  give.hopecharity.org
```

Set the column, point the DNS, and the tenant has their address. That's it.

> ⚠️ **One config value is mandatory and is currently empty.** `Auth:PlatformHosts` — when it is unset, `IsPlatformHost` returns `false` for **every** host. On `localhost` you don't notice (there's a Development-only bypass for loopback names). In Production, an empty list means `admin.yourdomain.com` resolves to `Unknown` and **nobody can log in to the control plane.** See §3.

---

## 2. Three different "domains" — do not mix these up

This is where every SaaS team ties itself in knots. They are three unrelated things.

| # | Thing | Example | Who owns the DNS | Needed for MVP-1? |
|---|---|---|---|---|
| **1** | **Tenant app address** — where the charity's staff log in | `hope.app.yourdomain.com` | **You** | ✅ Yes |
| **2** | **Tenant custom domain** — the charity's own branded public donation page | `give.hopecharity.org` | **The charity** | ⚠️ Nice-to-have |
| **3** | **Email sending domain** — so mail is not marked spam | SPF/DKIM/DMARC at SendGrid | The charity (BYO) or you | ✅ Yes, separately |

**#3 has nothing to do with web hosting.** It is DNS records at the *email provider*. Do not let it enter the Coolify conversation.

**Do #1 for MVP-1. Defer #2.** Reason in §6.

---

## 3. The three platform addresses

From the MVP-1 scope doc §5 — three addresses, one system:

| Address | Purpose | Coolify resource |
|---|---|---|
| `www.yourdomain.com` | Marketing website, enquiry form | Frontend app (or separate) |
| `app.yourdomain.com` + `*.app.yourdomain.com` | Tenant application | Frontend app |
| `admin.yourdomain.com` | Platform control plane | **Same** frontend app |
| `api.yourdomain.com` | Backend API | Backend app |

### Set this now — appsettings

```jsonc
{
  "Auth": {
    "PlatformHosts": [
      "admin.yourdomain.com",
      "www.yourdomain.com"
    ]
  }
}
```

Notes:
- Written **without** `www.` stripping in mind? No — `Normalize()` strips a leading `www.`, so `www.yourdomain.com` arrives as `yourdomain.com`. **List the bare `yourdomain.com` too** if you want the apex treated as platform.
- Do **not** put `app.yourdomain.com` in this list. That host must fall through to tenant resolution.
- In Coolify set it as an environment variable: `Auth__PlatformHosts__0=admin.yourdomain.com` (double underscore, zero-indexed) — that is how .NET maps env vars to config arrays.

---

## 4. DNS records to create

At your DNS provider (Cloudflare recommended — §7 explains why):

| Type | Name | Value | Proxy | Purpose |
|---|---|---|---|---|
| A | `@` | server IP | on | apex |
| A | `www` | server IP | on | marketing |
| A | `app` | server IP | on | tenant app root |
| **A** | **`*.app`** | **server IP** | **on** | **★ every tenant subdomain, one record** |
| A | `admin` | server IP | on | control plane |
| A | `api` | server IP | on | backend |

**The wildcard `*.app` is the whole trick.** Create it once and every future tenant — `hope.app`, `trust.app`, `foundation.app` — resolves immediately. No DNS change per customer, ever.

---

## 5. Coolify — exactly what to enable

### 5.1 Server level (Server → Settings)

| Setting | Value | Why |
|---|---|---|
| **Wildcard Domain** | `yourdomain.com` | Coolify auto-suggests hostnames for new resources |
| **Proxy** | Traefik (default) | Handles routing + certificates |
| Instance timezone | your timezone | Scheduled jobs, backups |

### 5.2 Proxy level (Server → Proxy → Configuration)

| Setting | Value | Why |
|---|---|---|
| **Let's Encrypt email** | a real monitored address | Expiry warnings land here |
| **Redirect HTTP → HTTPS** | on | Certificates only matter if traffic uses them |

### 5.3 Frontend resource (the Next.js app)

**Domains field** — Coolify accepts multiple, comma-separated:

```
https://app.yourdomain.com,https://admin.yourdomain.com,https://www.yourdomain.com
```

| Setting | Value | Why |
|---|---|---|
| Domains | as above | Traefik routes all three to this container |
| **Force HTTPS** | ✅ on | |
| **Health check path** | `/api/health` or `/` | ⚠️ **Set this.** Without it Coolify may cut traffic to the old container before the new one serves — a 502 mid-demo |
| Health check interval | 10s, 3 retries | |
| **Preview deployments** | ❌ off in production | Each preview burns a certificate against the Let's Encrypt weekly limit |
| Auto-deploy on push | ❌ off before a demo | Freeze means freeze |
| Build pack | Dockerfile / Nixpacks | |

### 5.4 The wildcard `*.app.yourdomain.com` — the one real decision

Coolify's Domains field routes **named** hosts. For a wildcard you need Traefik to accept `HostRegexp`, and — more importantly — **a wildcard TLS certificate**, which Let's Encrypt will only issue over **DNS-01**, never HTTP-01.

| | HTTP-01 (Coolify default) | DNS-01 |
|---|---|---|
| How it proves ownership | Serves a file over port 80 | Writes a TXT record |
| Wildcard certs? | ❌ **No** | ✅ **Yes** |
| Needs | Nothing | A DNS-provider **API token** |

**Two ways forward. Pick one:**

#### Option A — one certificate per tenant (fine up to ~20 tenants)

Add each tenant's hostname to the frontend's Domains field as you onboard them:

```
https://app.yourdomain.com,https://admin.yourdomain.com,https://hope.app.yourdomain.com,...
```

- ✅ Zero extra infrastructure, works today
- ❌ Manual edit + proxy reload per customer — **not automatable from the app**
- ❌ Runs into Let's Encrypt limits (§5.5) around 50 tenants

**This is the MVP-1 answer.** You will not have 20 tenants before MVP-2.

#### Option B — one wildcard certificate (the real answer, MVP-2)

Configure Traefik with a DNS-01 resolver, using a Cloudflare API token scoped to *Zone → DNS → Edit* on this zone only:

```yaml
# Coolify → Server → Proxy → Configuration (dynamic Traefik config)
certificatesResolvers:
  letsencrypt:
    acme:
      email: ops@yourdomain.com
      storage: /traefik/acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers: ["1.1.1.1:53"]
```

with `CF_DNS_API_TOKEN` set as an environment variable on the proxy, and a router rule:

```yaml
rule: "HostRegexp(`{sub:[a-z0-9-]+}.app.yourdomain.com`)"
tls:
  certResolver: letsencrypt
  domains:
    - main: "app.yourdomain.com"
      sans: ["*.app.yourdomain.com"]
```

- ✅ **One certificate covers every tenant, forever.** New tenant = a database row, nothing else
- ✅ Fully automatable — provisioning already writes `Companies.Subdomain`
- ❌ Hand-edited Traefik config that Coolify does not manage for you

> **Recommendation:** ship MVP-1 on **Option A**. Move to **Option B** before the tenant count passes 15. It is a half-day of work and it removes per-customer manual steps permanently.

### 5.5 Let's Encrypt limits — know these before they bite

| Limit | Value | What it means |
|---|---|---|
| Certificates per registered domain | **50 per week** | Option A hits this at ~50 tenants |
| Duplicate certificate | **5 per week** | Editing the Domains field repeatedly re-issues — **3 failed attempts and you are locked out for a week** |
| Failed validations | 5 per account/hostname/hour | |

> ⚠️ **Do not fiddle with the Domains field the day before a demo.** Five edits and TLS stops issuing until next week. Test certificate changes against Let's Encrypt **staging** first if you must.

### 5.6 Data safety

| Setting | Value |
|---|---|
| Postgres → **Scheduled backups** | ✅ on, daily, off-server (S3) |
| Persistent volumes | ✅ for Postgres, uploads, Traefik `acme.json` |
| **Take a manual backup before the demo** | ✅ |

Losing `acme.json` means re-issuing every certificate — straight into the §5.5 limits.

---

## 5A. Step-by-step runbook

> **Where each step happens.** Two different systems — do not look for the first two in Coolify:
>
> | Step | System | Code changes? |
> |---|---|---|
> | A — DNS records | **Cloudflare** (your DNS provider) | none |
> | B — API token | **Cloudflare** | none |
> | C — wildcard TLS | **Coolify** (Traefik config) | none |
>
> All three are infrastructure. **Zero application code.** `Companies.Subdomain` and the host-matching
> middleware already exist — see §1.

### Step A — create the DNS records (Cloudflare)

1. Cloudflare dashboard → select the zone (`yourdomain.com`).
2. Left menu → **DNS → Records**.
3. **Add record** once per row below. Type **A**, TTL **Auto**, Proxy status **Proxied** (orange cloud):

   | Name | IPv4 address |
   |---|---|
   | `@` | server IP |
   | `www` | server IP |
   | `app` | server IP |
   | `*.app` | server IP |
   | `admin` | server IP |
   | `api` | server IP |

   Cloudflare's Name box wants the **label only** — type `*.app`, not `*.app.yourdomain.com`.
   It renders as `*.app.yourdomain.com` after saving.

4. Verify from any machine (records are live in seconds, not hours):

   ```bash
   nslookup app.yourdomain.com
   nslookup anythingatall.app.yourdomain.com   # must return the SAME IP — proves the wildcard works
   ```

> ⚠️ **Wildcards match exactly one label.** A bare `*` covers `hope.yourdomain.com` but **not**
> `hope.app.yourdomain.com`. Create `*.app` — the layout our provisioning generates.

> **Cloudflare proxy + wildcards, free plan:** proxied wildcard records are a paid feature on some
> plans. If the orange cloud is refused on `*.app`, set that one record to **DNS only** (grey cloud).
> Everything still works — Traefik terminates TLS itself. You just lose Cloudflare's CDN/WAF in front
> of tenant subdomains.

### Step B — create the DNS API token (Cloudflare)

Needed only for Option B (the wildcard certificate). Nothing to do in Coolify yet.

1. Cloudflare → profile icon (top right) → **My Profile → API Tokens**.
2. **Create Token → Create Custom Token** (do **not** use the Global API Key — it is
   account-wide and cannot be scoped).
3. Fill in:

   | Field | Value |
   |---|---|
   | Token name | `traefik-dns01-pss` |
   | Permissions | **Zone · DNS · Edit** |
   | *(add a second permission)* | **Zone · Zone · Read** |
   | Zone Resources | **Include · Specific zone · yourdomain.com** |
   | TTL | leave unset, or set an expiry you will actually track |

4. **Continue to summary → Create Token.**
5. **Copy the token now.** Cloudflare shows it exactly once.
6. Store it in the team password manager, then paste it into Coolify (Step C).

> `Zone · Zone · Read` is easy to miss and the failure is confusing: Traefik authenticates fine and
> then reports it cannot find the zone.

### Step C — wildcard certificate in Coolify (Traefik DNS-01)

Do this **after** Step A resolves. Doing it first burns failed-validation attempts (§5.5).

1. **Coolify → Servers → your server → Proxy.** Confirm the proxy is **Traefik**.
2. Open the proxy's **Environment variables** and add:

   ```
   CF_DNS_API_TOKEN=<the token from Step B>
   ```

3. Open **Proxy → Configuration** (the Traefik static config) and add the resolver:

   ```yaml
   certificatesResolvers:
     letsencrypt:
       acme:
         email: ops@yourdomain.com
         storage: /traefik/acme.json
         dnsChallenge:
           provider: cloudflare
           resolvers: ["1.1.1.1:53"]
   ```

4. Add the wildcard router to the **dynamic** config, pointing at the frontend service:

   ```yaml
   http:
     routers:
       tenant-wildcard:
         rule: "HostRegexp(`{sub:[a-z0-9-]+}.app.yourdomain.com`)"
         entryPoints: ["https"]
         service: "<your-frontend-service-name>"
         tls:
           certResolver: letsencrypt
           domains:
             - main: "app.yourdomain.com"
               sans: ["*.app.yourdomain.com"]
   ```

   Take `<your-frontend-service-name>` from the frontend resource's existing generated Traefik labels —
   do not invent it.

5. **Restart the proxy** (Coolify → Proxy → Restart). Issuance takes 30–90 seconds.
6. Confirm the certificate covers the wildcard:

   ```bash
   echo | openssl s_client -connect anytenant.app.yourdomain.com:443 \
     -servername anytenant.app.yourdomain.com 2>/dev/null \
     | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
   ```

   You want `*.app.yourdomain.com` in the SAN list.

7. Then, once only, confirm end-to-end: provision a tenant with subdomain `demo`, open
   `https://demo.app.yourdomain.com`, and check the padlock. **No further step per tenant, ever.**

> **Test against staging first.** Add `caServer: https://acme-staging-v02.api.letsencrypt.org/directory`
> under `acme:` while you get the config right. Staging certificates are untrusted (browser warning)
> but have generous limits. Remove the line and delete `acme.json` to switch to production.
>
> Getting this wrong against production three or four times **locks certificate issuance for a week**
> (§5.5). That is not a risk worth taking on demo day.

### Fallback if Step C is not ready — Option A, one tenant

Coolify → frontend resource → **Domains**, append the single demo hostname:

```
https://app.yourdomain.com,https://admin.yourdomain.com,https://demo.app.yourdomain.com
```

Save → redeploy. That tenant gets its own certificate via HTTP-01, no token needed. Repeat per tenant
(manual), and move to Step C before ~15 tenants.

---

## 6. Tenant custom domains (`give.hopecharity.org`) — defer this

The charity wants their donation page on **their own** domain. Three problems:

1. **Their DNS, not yours.** They must create a CNAME. That is a support conversation per customer.
2. **A certificate per customer domain.** Option B's wildcard does not cover other people's domains.
3. **Coolify cannot do this from the app.** Every new domain is a manual Domains-field edit + proxy reload. It does not scale and it cannot be triggered by your provisioning code.

`Companies.CustomDomain` and `MatchCustomDomainAsync` already work — the *application* is ready. It is the *infrastructure* that isn't.

**When you do it (MVP-2), the two real answers:**

| Approach | How | Cost |
|---|---|---|
| **Caddy `on_demand_tls`** | Replace/front Traefik with Caddy. On the first request to an unknown host, Caddy calls your `ask` endpoint — `GET /internal/tls-check?domain=give.hopecharity.org` — which returns 200 only if that host exists in `Companies.CustomDomain`. Caddy then issues the certificate automatically | Free, self-hosted, one endpoint to write |
| **Cloudflare for SaaS** | Cloudflare terminates TLS for customer domains and forwards to you. API-driven: your provisioning code registers the hostname | **100 custom hostnames free**, then per-hostname |

> The `ask` endpoint is the safety valve — without it, anyone pointing DNS at your server makes you request certificates on their behalf, and you hit the rate limits in hours.

**Onboarding steps to give a charity (MVP-2):**

| # | Who | Action |
|---|---|---|
| 1 | Tenant admin | Enters `give.hopecharity.org` in Settings |
| 2 | System | Shows: create a CNAME `give` → `custom.yourdomain.com` |
| 3 | Charity's IT | Creates the record |
| 4 | System | Verifies the CNAME, then writes `Companies.CustomDomain` |
| 5 | Proxy | Issues the certificate on first request |

Steps 4 and 5 are the only new code — a verification job and a `tls-check` endpoint.

---

## 7. Recommended stack

| Layer | Choice | Why |
|---|---|---|
| DNS | **Cloudflare** | Free, wildcard-friendly, the API token DNS-01 needs, and the path to Cloudflare for SaaS later |
| Proxy | Traefik (Coolify default) → **Caddy** if you go per-tenant custom domains | Traefik is fine until §6 |
| Certificates | Let's Encrypt, **DNS-01** | Only route to wildcards |
| Tenant app addresses | `*.app.yourdomain.com` | One DNS record, one certificate, infinite tenants |
| Tenant custom domains | Deferred to MVP-2 | §6 |

---

## 8. Checklist before the demo

| # | Task | Done |
|---|---|---|
| 1 | DNS: `@`, `www`, `app`, `*.app`, `admin`, `api` all resolve | ☐ |
| 2 | Coolify server **Wildcard Domain** = `yourdomain.com` | ☐ |
| 3 | Traefik Let's Encrypt email set to a monitored address | ☐ |
| 4 | Frontend Domains: `app.` + `admin.` + `www.` | ☐ |
| 5 | Backend Domain: `api.` | ☐ |
| 6 | **Force HTTPS** on | ☐ |
| 7 | **Health check path** set on both apps | ☐ |
| 8 | Preview deployments **off** | ☐ |
| 9 | Auto-deploy on push **off** until after the demo | ☐ |
| 10 | ★ `Auth__PlatformHosts__0=admin.yourdomain.com` set — **without this nobody logs in** | ☐ |
| 11 | Demo tenant's `Companies.Subdomain` set, and `<sub>.app.yourdomain.com` added to Domains (Option A) | ☐ |
| 12 | Postgres scheduled backups on + a manual backup taken | ☐ |
| 13 | Every hostname loads over HTTPS with a valid certificate | ☐ |

---

## 9. If management asks

> **"Can each charity have their own web address?"**
>
> Yes. Every charity gets their own address the moment we create them — `hope.app.ourproduct.com`. It's automatic, no setup per customer.
>
> If a charity wants their donation page on **their own** domain — `give.hopecharity.org` — the software already supports it. What we'd add is the certificate automation, which is about half a day of work. We've scheduled that for the next release because it needs the charity's own IT to make a DNS change, and that's a conversation better handled once we have onboarding running smoothly.

---

## 10. Change log

| Date | By | Change |
|---|---|---|
| 2026-08-06 | agent | Added §5A — click-by-click runbook for the three infrastructure steps (A: Cloudflare DNS records, B: Cloudflare scoped API token, C: Traefik DNS-01 wildcard in Coolify), plus the Option A single-tenant fallback for demo day. Records where each step happens: A and B are Cloudflare, only C is Coolify; none are code. |
| 2026-08-05 | agent | Written. Anchored on verified `HostTenantResolver.cs` behaviour — host→tenant resolution is fully built, so per-tenant domains are DNS + Coolify + `Companies.Subdomain`/`CustomDomain`, with no new code. Option A (per-tenant cert) recommended for MVP-1, Option B (wildcard via DNS-01) before 15 tenants, custom domains (Caddy `on_demand_tls` / Cloudflare for SaaS) deferred to MVP-2. |
