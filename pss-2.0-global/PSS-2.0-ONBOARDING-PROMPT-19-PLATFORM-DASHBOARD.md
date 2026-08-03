# PROMPT 19 — Platform Control-Plane Dashboard (split from the tenant master dashboard)

**Surface:** BE (new aggregator query) + FE (new dashboard page + landing routing)
**Depends on:** `ops-platform-rbac-seed.sql` applied (PLATFORM module + 5 global roles + 10 capabilities)
**Related:** `.claude/screen-tracker/prompts/masterdashboard.md` (#174, the tenant surface — read §4b, §⑤, ISSUE-9)

---

## ⚠️ Rules

| Rule | Detail |
|---|---|
| **No `dotnet build`** | User builds. Compile by inspection. |
| **Migrations are user-owned** | Never `dotnet ef migrations add / database update / remove`. Never hand-author a migration or snapshot. **This pass should need no schema change at all** — every metric below is derivable from existing tables. If you believe one is required, stop and write it into §⑪ instead of building it. |
| **Seed SQL: write, never run** | `sql-scripts-dyanmic/`. User applies. |
| **Backend is gitignored** | Grep/Glob return **zero** `.cs` hits. Use `find -iname`, or scope `grep -rn --include=*.cs` to **one** project dir — a repo-wide backend grep times out at 120s. Absolute-path `Read` works fine. Frontend is likewise gitignored. |
| **Typecheck** | `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` with **no pipe**. Only exit 0 counts as clean. |
| **HotChocolate naming** | `Get` is **stripped** from every resolver (`GetPlatformSnapshot` → `platformSnapshot`); `Input` is **appended** to input types. tsc cannot see gql field names — a wrong name compiles clean and fails only at runtime. Verify the resolver name against the endpoint file before writing the FE query. |
| **UTC only** | Every Postgres date column is `timestamp with time zone`; Npgsql throws on `Kind=Unspecified`. Use `DateTime.UtcNow`; build range boundaries with `DateTimeKind.Utc`; never `DateTime.Today` inside an EF predicate. |
| **Verify properties** | Never assume a column, DTO property, or GraphQL field name. Read the entity first. Audit columns are `CreatedDate` / `ModifiedDate`. |
| **Registry** | `grep` `REGISTRY.md`, never `Read` it (~700KB). |

---

## ⓪ Where the code lives (verified on disk 2026-08-03)

**Frontend**
```
src/app/[lang]/(master)/layout.tsx                      bare shell: RouteGuard + CompanySettingsBootstrap
src/app/[lang]/(master)/masterdashboard/page.tsx        tenant launcher (#174)
src/app/[lang]/(master)/platform/layout.tsx             adds Header + Sidebar (DashBoardLayoutProvider)
src/app/[lang]/(master)/platform/dashboards/page.tsx    ← THE PLACEHOLDER YOU REPLACE
src/app/[lang]/(master)/ops/layout.tsx                  same shell, mirrors platform/layout.tsx
src/app/[lang]/(master)/ops/{tenants,leads,deals,plans,audit,onboarding}/…
src/presentation/pages/master/landing-page/{index,header,content,footer}.tsx
src/infrastructure/gql-queries/auth-queries/ModuleQuery.ts   USER_ROLE_MODULES
src/application/hooks/useAuth/index.ts:94                post-login redirect — HARDCODED to MASTER_URL
```

**Backend** (`PSS_2.0_Backend/PeopleServe/Services/Base/`)
```
Base.Application/Business/OpsBusiness/Tenants/Queries/GetTenants.cs
Base.Application/Business/OpsBusiness/TenantProvisioning/Queries/GetProvisioningRuns.cs
Base.Application/Business/OpsBusiness/LeadManagement/Queries/{GetLeads,GetCommercialTerms}.cs
Base.Application/Business/BillingBusiness/PlanCatalog/Queries/GetPlanCatalog.cs
Base.Application/Business/BillingBusiness/PlatformPolicy/Queries/GetPlatformWebhookLogs.cs
Base.API/EndPoints/…                                    resolver registration
```

---

## ① The mental model — the split already exists, the content does not

The user's ask is "make the master dashboard two parts: platform and tenant". **Structurally that is already
true.** Both surfaces live in the `(master)` route group:

| | Tenant | Platform |
|---|---|---|
| Route | `/{lang}/masterdashboard` | `/{lang}/platform/dashboards` |
| Chrome | bare `(master)` layout; the launcher paints its own header/footer, **no sidebar** | `(master)/platform/layout.tsx` nests inside `(master)` and adds Header + Sidebar so the PLATFORM menus render |
| Shape | **module launcher** — tiles that navigate; explicitly *not* a metrics dashboard | **metrics dashboard** — this is the difference |
| Today | built | **placeholder**: renders "No dashboard configured yet" + four quick links |

A platform user is not marked by a flag. `ops-platform-rbac-seed.sql` seeds five **global roles with
`CompanyId IS NULL`** — `PLATFORM_SALES`, `PLATFORM_IMPLEMENTATION`, `PLATFORM_SUPPORT`,
`PLATFORM_FINANCE`, `PLATFORM_ADMIN` (and copies the same grants onto `SUPERADMIN`) — holding
`PLATFORM_*` capabilities on the four PLATFORM menus. That is what makes the `PLATFORM` module
("Control Plane", `ModuleUrl = '/platform/dashboards'`, `OrderBy 900`) appear in the user's
`USER_ROLE_MODULES` result.

So the live flow for a platform staffer is: login → hardcoded `/masterdashboard` → a **tenant-branded**
hero ("{TenantName} — manage your day from one place") with tenant module tiles plus a Control Plane
tile → click → placeholder.

---

## ② Defects

- **D-A — the platform dashboard has no content.** `platform/dashboards/page.tsx` is a deliberate
  stub. This is the deliverable.
- **D-B — no aggregator exists.** Ops and billing ship only **list** queries (`GetTenants`,
  `GetLeads`, `GetProvisioningRuns`, `GetPlatformWebhookLogs`, `GetPlanCatalog`,
  `GetSubscriptionForCompany`). Nothing rolls up across tenants. A dashboard built on the list
  queries would over-fetch entire tables to count them client-side — do not do that.
- **D-C — platform staff land on a tenant-branded launcher.** Post-login is hardcoded to
  `MASTER_URL` at `useAuth/index.ts:94`. For a user whose only module is PLATFORM, the launcher is a
  pointless hop wearing the wrong brand.
- **D-D — the placeholder's own comment points the wrong way.** It suggests swapping in
  `<MenuDashboardComponent moduleCode="PLATFORM" …/>`. That component drives the **tenant-configurable
  designer dashboards** owned by the Setting module (`sett` dashboard/layout/role tables). The control
  plane is not tenant-configurable and has no per-tenant layout to resolve — it must be a **fixed coded
  dashboard**. Delete that comment along with the stub.

---

## ③ Design

### 3.1 One new BE query — `GetPlatformSnapshot`

A single cross-tenant aggregator, **capability-gated per section**, returning one object. One
round-trip; each section is `null` when the caller lacks the capability, so the FE renders exactly
what the caller may see without a second permission model.

```
Query:   GetPlatformSnapshotQuery()                     — no args in v1
Result:  GetPlatformSnapshotResult
           TenantsSection?      requires PLATFORM_TENANT_VIEW
           ProvisioningSection? requires PLATFORM_TENANT_VIEW
           PipelineSection?     requires PLATFORM_LEAD_VIEW
           RevenueSection?      requires PLATFORM_PLAN_VIEW   (see §⑪ Q1)
           HealthSection?       requires PLATFORM_AUDIT_VIEW
```

Sections and their sources — **verify every column name against the entity before use**:

| Section | Metrics | Source |
|---|---|---|
| **Tenants** | total, active, trialing, suspended, new-this-month, plan mix (tenants per plan code) | `app.Companies` + `billing.Subscriptions` |
| **Provisioning** | runs in progress, **runs paused/failed needing attention**, completed last 7d | `ops.ProvisioningRuns` |
| **Pipeline** | leads by stage, deals awaiting discount approval, won-this-month | `ops.Leads` + `ops.CommercialTerms` |
| **Revenue** | MRR by plan, subscriptions by status, past-due / failed-payment count | `billing.Subscriptions` + `billing.Invoices` |
| **Health** | webhook errors last 24h, last successful webhook timestamp | `billing.PlatformWebhookLogs` |

The **paused/failed provisioning runs** tile is the highest operational value on the page — those runs
are resumable and every one sitting idle is a customer not onboarded. Make it visually prominent and
link each row to `/ops/tenants/provisioning-runs/{runId}`.

**Query hygiene:** every metric is a `COUNT`/`SUM` projected in SQL. Never materialise a list to
`.Count()` it in memory. `IApplicationDbContext` is **not thread-safe** — run the section queries
**sequentially**; `Task.WhenAll` over one context throws.

**Cross-tenant by design.** These handlers deliberately read across all companies, so they must
**not** go through the tenant filter. Confirm how existing ops handlers (`GetTenants.cs`) bypass
`ITenantContext` and follow that exact pattern — do not invent a second mechanism.

### 3.2 The platform dashboard page

Replace the stub at `(master)/platform/dashboards/page.tsx`. Keep the existing route, the existing
`ModuleUrl` seed value, and the surrounding `platform/layout.tsx` shell — **no seed change, no route
change**.

- Screen type **`DASHBOARD`** (fixed/coded sub-type), *not* `MASTER_LANDING`. Unlike #174 this
  surface genuinely is metrics-shaped.
- Widgets live under `presentation/components/dashboards/widgets/platform-widgets/`. Per the
  standing rule: **new renderers, no legacy reuse**, and each widget **visually distinct** — do not
  ship five identical KPI tiles in a row. Mix: a counter strip, a stacked plan-mix bar, an
  attention-list (paused runs), a pipeline funnel, a compact health strip.
- Icon containers, badges and chips: **solid `bg-X-600` + `text-white`**. Never `bg-X-50/100`,
  `text-X-700/800`, `bg-muted`, or `text-muted-foreground` for those. Visualisation fills may keep
  mid-saturation.
- Tokens only — no raw hex, no raw px. Shaped `Skeleton`s while loading; explicit empty and error
  states per widget. Responsive xs→xl. `@iconify` Phosphor icons.
- A section whose DTO comes back `null` **renders nothing at all** — no "you don't have access" card.
- Keep the four quick links from the stub, demoted to a footer strip; they are still the fastest path
  into the operational screens.

### 3.3 Landing routing

Read the module list once post-auth and branch:

- module list contains **`PLATFORM` and nothing else** → redirect straight to `/{lang}/platform/dashboards`
- **anything else** (including a `SUPERADMIN` holding both tenant and platform modules) → the tenant
  launcher, unchanged

A hard "any PLATFORM capability ⇒ platform dashboard" redirect would strand SUPERADMIN away from the
tenant modules, which is why the rule is *only*, not *any*.

Implement this at the redirect site, not by mutating the launcher. Do **not** build
`Role.DefaultLandingUrl` here — that is a separate designed-but-unbuilt feature (memberportal.md
ISSUE-19) and pulling it in doubles this pass's scope. Leave a comment at `useAuth/index.ts:94`
noting that this branch is the interim mechanism and `DefaultLandingUrl` supersedes it when built.

### 3.4 The tenant launcher — leave it alone

`/masterdashboard` keeps its shape: module launcher, tenant name in the hero, PWDS in the footer
(ISSUE-10), no sidebar, no Menu row. Two things **not** in this pass:

- ISSUE-9's `getMasterDashboardSnapshot` (tenant KPI aggregator) stays open. It is a natural sibling
  of `GetPlatformSnapshot` and may reuse its section-DTO shape, but it is tenant-scoped, differently
  gated, and belongs to its own pass.
- Do **not** move `masterdashboard` into `(app)`, and do **not** create a Menu row for it.

---

## ④ Build steps

1. **Read first.** `masterdashboard.md` §4b/§⑤/ISSUE-9; `ops-platform-rbac-seed.sql`;
   `platform/dashboards/page.tsx`; `platform/layout.tsx`; `GetTenants.cs` and
   `GetProvisioningRuns.cs` (for the cross-tenant read pattern and the real column names).
2. **BE — `GetPlatformSnapshot`.** Query + handler + result DTOs under
   `Base.Application/Business/OpsBusiness/PlatformDashboard/Queries/`. Sections computed
   sequentially, each guarded by its capability. Register the resolver; **record its resolved
   GraphQL field name in §⑬** so the FE query cannot drift.
3. **FE — gql + DTO.** Add the query to the ops gql-queries folder alongside the existing platform
   queries. Mirror the section DTOs as optional TypeScript fields.
4. **FE — widgets.** New `platform-widgets/` renderers per §3.2.
5. **FE — page.** Replace the stub. Delete the `MenuDashboardComponent` suggestion comment.
6. **FE — landing branch.** §3.3.
7. **Typecheck.** `npx tsc --noEmit --incremental false`, no pipe, exit 0.

---

## ⑤ Invariants

1. **No schema change and no migration.** Every metric is derivable from existing tables.
2. **No seed change.** The PLATFORM module, its `ModuleUrl`, its menus and capabilities are already
   correct. If a metric needs a capability that isn't in the seeded ten, write it into §⑪ — don't
   invent a capability code.
3. **Aggregate in SQL.** No `.ToListAsync()` followed by `.Count()`.
4. **Sequential section queries.** One `IApplicationDbContext`, one query at a time.
5. **Capability gating is server-side.** The FE hides sections that come back `null`; it never
   decides visibility itself. Hiding is cosmetic — the server is the boundary.
6. The tenant launcher's behaviour, chrome and footer are untouched except for the redirect branch.

---

## ⑥ Out of scope

Tenant KPI aggregator (ISSUE-9) · `Role.DefaultLandingUrl` · designer-configurable platform
dashboards · impersonation UX · cross-tenant `/ops/usage` (explicitly not chosen) · any change to the
ops list screens · date-range or tenant filters on the snapshot (v1 is "now").

---

## ⑦ Acceptance

- [ ] `/{lang}/platform/dashboards` renders real numbers; the "No dashboard configured yet" card is gone.
- [ ] A `PLATFORM_SALES` user sees the pipeline section and **no** revenue or health section.
- [ ] A `PLATFORM_ADMIN` user sees every section.
- [ ] A user whose only module is PLATFORM lands on `/platform/dashboards` directly after login.
- [ ] A `SUPERADMIN` still lands on `/masterdashboard` and still sees both tenant modules and the Control Plane tile.
- [ ] A paused provisioning run appears in the attention widget and links to its run detail page.
- [ ] Sidebar + header render on the platform dashboard (it is inside `platform/layout.tsx`).
- [ ] `/masterdashboard` unchanged: tenant hero, PWDS footer, no sidebar.
- [ ] Each widget has a loading skeleton, an empty state and an error state.
- [ ] `npx tsc --noEmit --incremental false` exits 0.

---

## ⑧ Files

### Backend (`PSS_2.0_Backend/`)

| File | Action |
|---|---|
| `Base.Application/Schemas/OpsSchemas/PlatformDashboardSchemas.cs` | **new** — `PlatformSnapshotDto` + 5 section DTOs + 4 row DTOs |
| `Base.Application/Business/OpsBusiness/PlatformDashboard/Queries/GetPlatformSnapshot.cs` | **new** — query, validator, handler (sequential, per-section capability gating) |
| `Base.API/EndPoints/Ops/Queries/PlatformDashboardQueries.cs` | **new** — resolver, auto-registered by the `IQueries` assembly scan |

No migration. No schema change. No seed change.

### Frontend (`PSS_2.0_Frontend/src/`)

| File | Action |
|---|---|
| `domain/entities/ops-service/PlatformDashboardDto.ts` | **new** — TS mirror; all five sections optional |
| `domain/entities/ops-service/index.ts` | edit — barrel export |
| `infrastructure/gql-queries/ops-queries/PlatformDashboardQuery.ts` | **new** — `PLATFORM_SNAPSHOT_QUERY` |
| `infrastructure/gql-queries/ops-queries/index.ts` | edit — barrel export |
| `presentation/components/custom-components/dashboards/widgets/platform-widgets/PlatformWidgetShell.tsx` | **new** — shared frame, error/empty rails, formatters |
| `…/platform-widgets/PlatformTenantCounterStrip.tsx` | **new** — 5-counter hairline strip |
| `…/platform-widgets/PlatformPlanMixBar.tsx` | **new** — stacked 100 % bar + legend |
| `…/platform-widgets/PlatformAttentionRunsWidget.tsx` | **new** — solid alert band, rows link to run detail |
| `…/platform-widgets/PlatformPipelineFunnel.tsx` | **new** — tapering rails |
| `…/platform-widgets/PlatformRevenuePanel.tsx` | **new** — hero MRR + per-plan ledger |
| `…/platform-widgets/PlatformHealthStrip.tsx` | **new** — compact heartbeat row |
| `…/platform-widgets/index.ts` | **new** — barrel |
| `presentation/components/page-components/ops/platform-dashboard/platform-dashboard-page.tsx` | **new** — the dashboard body |
| `app/[lang]/(master)/platform/dashboards/page.tsx` | **rewritten** — stub → thin wrapper (route + ModuleUrl unchanged) |
| `presentation/hooks/useAuth/index.ts` | edit — post-login landing branch |

`platform/layout.tsx` untouched. `/masterdashboard` and the launcher untouched.

---

## ⑨ Open questions

**Q1 — which capability gates the revenue section?** The seeded ten include `PLATFORM_PLAN_VIEW` /
`PLATFORM_PLAN_EDIT` but no billing-specific one, while `PLATFORM_BILLING_VIEW` /
`PLATFORM_BILLING_MANAGE` appear in the *billing* seeds. Confirm which is actually seeded and granted
before wiring; if neither cleanly fits, gate on `PLATFORM_PLAN_VIEW` and record the choice in §⑬
rather than seeding a new capability in this pass.

**Q2 — MRR definition.** Monthly-normalised subscription value (annual ÷ 12) vs raw current-period
amount. Pick monthly-normalised, label the tile "MRR (normalised)", and note it — a wrong-but-labelled
number is recoverable, an unlabelled one is not.

Neither blocks the build.

---

## ⑩ Build log

*(append per session: resolved GraphQL field name, deviations, §⑨ decisions taken)*

### 2026-08-03 — full build (steps 1–7)

**Resolved GraphQL field name: `platformSnapshot`.** Resolver method is `GetPlatformSnapshot`;
HotChocolate strips the `Get` prefix. No arguments in v1, so no input type. Recorded in the resolver
file's header comment as well.

**§⑨ decisions taken**

- **Q1 — RESOLVED, no new seed.** `PLATFORM_PLAN_VIEW` is already seeded
  (`sql-scripts-dyanmic/ops-platform-plan-view-capability-seed.sql`), so the revenue section gates on
  `PLATFORM_PLAN_VIEW` **OR** `PLATFORM_PLAN_EDIT` (the `List<string>` overload of
  `HasAccessAsync` is OR semantics). `PLATFORM_BILLING_*` was not used. The grant matrix satisfies §⑦
  on its own: SALES holds neither `PLATFORM_PLAN_VIEW` nor `PLATFORM_AUDIT_VIEW` → no revenue, no
  health; ADMIN holds all five gating capabilities → every section.
- **Q2 — monthly-normalised.** Annual subscriptions contribute `amount ÷ 12`. Tile is labelled
  **"MRR (normalised)"** with the sub-line "Annual plans counted at amount ÷ 12". Amounts are summed
  as stored, with **no FX conversion** — noted in both the handler and the widget doc-comments.

**Deviations from the prompt (all path corrections, no design changes)**

| Prompt said | Actually on disk |
|---|---|
| `presentation/components/dashboards/widgets/platform-widgets/` | `presentation/components/custom-components/dashboards/widgets/platform-widgets/` |
| `src/application/hooks/useAuth/index.ts` | `src/presentation/hooks/useAuth/index.ts` |
| `Data/IApplicationDbContext.cs` | `Data/Persistence/IApplicationDbContext.cs` |

Further notes:

- **Widget file layout.** Existing widget folders are one directory per widget because they are
  designer-driven (`TWidgetProps` / `useWidgetQuery`). P-19's widgets are fixed and prop-fed, so they
  are flat files in a single folder. Reason recorded in the barrel's header comment.
- **Page body split out.** The route file is a thin wrapper over
  `page-components/ops/platform-dashboard/platform-dashboard-page.tsx`, matching the other `(master)`
  ops routes. Route, `ModuleUrl` seed value and `platform/layout.tsx` are unchanged.
- **No `[CustomAuthorize]` on the query.** `AuthorizationBehavior` skips authorization entirely when
  the attribute is absent, which is exactly what per-section gating needs. The handler resolves the
  `"UserId"` claim itself via `IHttpContextAccessor` (there is no `ICurrentUser` abstraction) and
  returns an all-null snapshot to an unauthenticated caller.
- **EF translation fix.** `Distinct()` inside a `GroupBy` aggregate does not translate; plan mix is
  computed as `.Select(new { PlanId, CompanyId }).Distinct().GroupBy(x => x.PlanId)`. Plan labels come
  from one `LoadPlanLabelsAsync` lookup rather than a reverse re-label.
- **Sections run sequentially** over the single `IApplicationDbContext` (it is not thread-safe); every
  metric is a `COUNT`/`SUM` projected in SQL; the cross-tenant bypass copies `GetTenants.cs`'s
  `IgnoreQueryFilters()` + explicit `IsDeleted != true` pattern verbatim.
- **Landing branch** implemented at the redirect site (`router.push` inside `login`), not by mutating
  the launcher: it resolves `userRoleModules`, and only when the accessible list is exactly
  `[PLATFORM]` sets the active module in the global store and pushes `/{lang}/platform/dashboards`.
  Anything else — including SUPERADMIN holding both — falls through to `MASTER_URL` unchanged, as does
  any failure resolving modules. A comment at the site records that this is interim and
  `Role.DefaultLandingUrl` supersedes it.
- **D-D closed:** the `<MenuDashboardComponent moduleCode="PLATFORM" …/>` comment and the
  "No dashboard configured yet" card are both gone; the four quick links survive as a footer strip.

**Typecheck:** `npx tsc --noEmit --incremental false` → **exit 0, no output.**
**Not run (user-owned):** `dotnet build`, any migration command. No migration is needed — this pass
changed no schema and added no seed.

---
---

# PHASE 2 — Host-bound login (added 2026-08-03, after Phase 1 shipped)

**Status:** BUILT 2026-08-03 (steps 0–6). Seeds written, not applied; `Auth:PlatformHosts` still empty
pending Q3. See §⑯ files and §⑰ build log.
**Surface:** BE (login gate) + FE (send the host) + seed SQL (user-applied).
**Trigger:** post-build question — *"how do we render the platform dashboard? We don't know whether the user is platform staff or tenant staff."*

---

## ⑪ The question, and why Phase 1's answer is at the wrong layer

Phase 1 decided the landing at the **redirect site**, after authentication: resolve the user's module list and, if it is exactly `[PLATFORM]`, push `/platform/dashboards`. That works, and it can stay in place until this phase lands. But it answers a smaller question than the one actually being asked.

The real question is not *"which dashboard does this user see"*. It is **"is this user allowed to authenticate on this hostname at all"** — and once that is answered, the dashboard follows for free.

### 11.1 The defect (verified on disk, live today)

`Base.Application/Business/AuthBusiness/Users/Queries/GetUserCredential.cs`:

```csharp
var userQuery = dbContext.Users.IgnoreQueryFilters()   // tenant filter deliberately off
    .Include(x => x.UserRoles...).ThenInclude(x => x.Role)
    .AsNoTracking();

var userCredential = await userQuery.FirstOrDefaultAsync(
    o => o.UserName == query.username && o.IsActive == true && o.IsDeleted == false, ct);
```

The query takes **a username and nothing else**. `GetUserCredentialQuery(string username)` has no hostname parameter, and `AuthendicationMutations.Login` does not pass one. Consequently:

- A tenant-A staff member can authenticate at **tenant B's** subdomain and receive a valid token. Their `CurrentCompanyId` comes from `User.CompanyId`, so they then see *their own* data under B's branding — no cross-tenant data leak, but B's login page is a working oracle for "does this username exist anywhere on the platform", and the session is issued on the wrong host.
- Platform staff can authenticate on any tenant host, and tenant staff on the platform host.

This is the exact concern raised, and it is not hypothetical. Treat it as a **security defect**, not as landing-page polish. It is the reason this phase exists.

### 11.2 The resolver already exists

`Base.Application/Business/AuthBusiness/TenantLoginConfig/Queries/GetTenantLoginConfigQuery.cs` already turns a hostname into a tenant, for branding:

```
1. app.Companies.CustomDomain exact match      -> ResolvedBy = CustomDomain
2. first label matched to Companies.Subdomain  -> ResolvedBy = Subdomain
3. no match                                    -> ResolvedBy = Default  (PSS default branding)
```

It strips port, lowercases, strips `www.`, caches 60 s (5 s for Default), and honours a `?_tenant=` override in Development only.

`ResolvedBy = Default` **is** the platform host. The classification this phase needs is already computed on every login-page render — it is simply never consulted when the password is checked.

### 11.3 Correction to §3.3

§3.3 states that `Role.DefaultLandingUrl` is "designed-but-unbuilt" and tells the builder not to touch it. **That is wrong.** `Role.DefaultLandingUrl` exists at `Base.Domain/Models/AuthModels/Role.cs:39`, and `GetUserCredentialHandler` already resolves it into the token with a documented precedence (primary role → lowest `Role.OrderBy` with a non-null value → `null`, which `CreateToken` defaults to `masterdashboard`). Note the SUPERADMIN branch returns early with `DefaultLandingUrl = null` **by design**, so a superadmin still lands on the tenant launcher.

The column being live changes the plan: the interim module-sniffing branch is replaced by **a seed row**, not by more FE logic.

Two corrections to the seed value itself: the doc comment on `Role.cs:39` says `DefaultLandingUrl` is
stored **without the `/${lang}/` prefix and without a leading slash** (`"masterdashboard"`,
`"crm/membership/memberportal"`). So the value to seed is `platform/dashboards`, **not**
`/platform/dashboards`.

### 11.4 Identity model — where does a platform staff member live? **DECIDED: no new table**

The question was whether platform staff get their own table or sit in the existing staff table.
**Neither.** A platform staff member is an `auth.Users` row with `CompanyId = NULL` holding at least
one `UserRole` whose `Role.CompanyId IS NULL`. That is already the shape the RBAC seed builds, and it
is the right one. The reasoning matters more than the verdict, because both alternatives are tempting:

**Why not a separate identity table (`ops.PlatformStaffs` with its own login).** `auth.Users` is the
single identity table and is *already* company-nullable — the schema anticipated this. A second
identity table is a second password hash, a second lockout counter, a second reset/activation flow, a
second 2FA path, a second `LoginHistory`, and a login endpoint that must probe two tables and merge
the results. Every future auth change then has to be made twice, and the day the two implementations
drift is the day one of them is the weaker one an attacker uses. Two identity stores is a security
regression sold as a modelling convenience.

**Why not `app.Staffs`.** `Staff` is a *tenant HR and operations* record, not a person record. It
carries `StaffCategoryId`, `BranchId`, `OrganizationalUnitId`, `ReportingToStaffId`, and it is the
collector / depositor / issuer FK target on `GlobalReceiptDonation`, `ChequeDonation` and
`GlobalDonation`. Its uniqueness is `(CompanyId, StaffEmpId)`, `(CompanyId, StaffEmail)`,
`(CompanyId, StaffMobileNumber)` — every index assumes a tenant. Putting a platform employee there
forces either a fake `CompanyId` or a NULL that defeats those indexes, and it makes platform staff
show up in tenant HR screens and in donation-collector pickers. Wrong table, and a data-leak surface.

**So the discriminator is a role, not a table:**

```sql
EXISTS (SELECT 1 FROM auth."UserRoles" ur
        JOIN auth."Roles" r ON r."RoleId" = ur."RoleId"
        WHERE ur."UserId" = u."UserId" AND r."CompanyId" IS NULL AND ur."IsActive")
```

Do **not** use `User.CompanyId IS NULL` alone as the test — it is a convenience column, and a
mis-seeded row would silently promote a tenant user to platform staff. Roles are the authority; the
`Include` in `GetUserCredential` already loads them, so the check costs nothing.

**Invariant to enforce** (§12.8): a user holds either platform roles or tenant roles, never both.

**On point 3 of the question — "if we create platform staff we know them easily."** True, and we
already do: the predicate above is exact, indexed, and available at the moment of login. Creating a
table would not make identification easier; it would make authentication harder. What is genuinely
missing is not a table but a **creation path** — there is no screen or seed that mints a platform user
today, only the five roles they would be given. That gap is step 0 below.

**If platform HR attributes are ever needed** (department, hire date, manager), add a thin
`ops.PlatformStaffProfiles` keyed 1:1 on `UserId` — a *profile* hanging off the identity, never a
second identity. Not MVP; do not build it in this phase.

---

## ⑫ Design — classify the host, then gate on it

### 12.1 Host context

Extract the CustomDomain → Subdomain → Default resolution from `GetTenantLoginConfigHandler` into a reusable `IHostTenantResolver` (`Base.Infrastructure/Services/Auth/`) returning:

```csharp
public sealed record HostContext(HostKind Kind, int? CompanyId, string NormalizedHost);
public enum HostKind { Platform, Tenant, Unknown }
```

`Platform` is **not** simply the old `ResolvedBy.Default` — it requires a hit on the configured
platform-host allow-list. Anything that matches neither a tenant nor the allow-list is `Unknown`,
which renders but never authenticates (§⑮ Q3).

`GetTenantLoginConfigHandler` then calls the resolver instead of owning the logic, so branding and authorization can never disagree about what host you are on. Keep its cache; do not add a second one.

### 12.2 The gate

`GetUserCredentialQuery(string username)` → `GetUserCredentialQuery(string username, string hostname)`. After the user row is found and **before** the credential result is returned:

| Host | Who may authenticate |
|---|---|
| **Platform** (`Kind = Platform`) | users holding at least one active role with `Role.CompanyId IS NULL` — the five seeded `PLATFORM_*` roles, plus `SUPERADMIN` |
| **Tenant** (`Kind = Tenant`, `CompanyId = N`) | users with at least one active `UserRole` whose `CompanyId = N` — **and nobody else, including platform staff and superadmin** (§12.3) |
| **Unknown** (`Kind = Unknown`) | nobody. Renders, never authenticates. |

Membership is decided on **`UserRole` rows, not `User.CompanyId`**. `User.CompanyId` is a single nullable column and a user may legitimately hold roles in more than one company; the roles are the authority. Those rows are already loaded by the existing `Include` — no extra query.

### 12.3 SUPERADMIN — narrow, not exempt

An earlier draft of this section exempted `SUPERADMIN` from the gate entirely, on the grounds that
support needs to reproduce tenant problems on the tenant's own host. **That justification is void:**
the RBAC seed already ships a `PLATFORM_IMPERSONATE` capability ("Impersonate a tenant user for
support"). Support impersonates *from the platform host*; it never needs to authenticate on a tenant
host. Given the instruction that a user logs in on their own domain and nowhere else, the exemption
buys nothing and punches the one hole big enough to matter.

So: **`SUPERADMIN` is a platform identity and logs in on the platform host only.** It gets no tenant-host
carve-out. The `GetUserCredential` SUPERADMIN branch returns early before company context is computed,
which is consistent with this — a superadmin *is* platform staff.

The one residual risk is impersonation not working when you need it. Mitigate with an
**explicit configured break-glass list** (`Auth:BreakGlassUsernames`, empty by default) rather than a
blanket role exemption: a named account, deliberately added, every mismatched login logged as a
warning. Empty list in normal operation. If you would rather keep the blanket SUPERADMIN exemption,
say so and I will restore it — but impersonation is the better path and it is already built.

### 12.4 Failure must be indistinguishable from a bad password

A rejected host returns **the same generic "Invalid username or password"** as a wrong password, with the same response shape and no distinguishing field. Anything else turns every tenant login page into a membership oracle: "wrong tenant" tells an attacker the account exists *and* names the tenant it belongs to. This is the single most important rule in this phase.

Still record a `LoginHistory` row for the rejected attempt, with a reason code that is stored but **never returned to the client**. Do **not** increment `FailedLoginCount` or trip the 5-attempt `IsLocked` path for a host rejection — otherwise anyone can lock any account they can name simply by hammering the wrong subdomain.

### 12.5 Development carve-out — read this before building

On `localhost` nothing matches `Subdomain` or `CustomDomain`, so every local login resolves to
`Unknown` and **every developer is locked out of everything**. Confirmed requirement: *the restriction
is off in development and on once published.*

**Rule: when `IHostEnvironment.IsDevelopment()`, the host gate is advisory — it computes the verdict,
logs what it would have done, and allows the login regardless.** All three host kinds, including
`Unknown`. Any environment that is not Development enforces, no exceptions.

Two constraints on how that bypass is written, because a dev-only bypass is exactly the kind of code
that escapes into production:

1. Gate it on `IHostEnvironment.IsDevelopment()` **only** — never on an `appsettings` boolean, a
   `#if DEBUG`, or an env var. A config flag is one bad merge or one copied `appsettings.json` away
   from disabling the gate on the live system, and it would do so silently.
2. Log every bypass at **Warning** with the verdict it suppressed (`"host gate bypassed
   (Development): user X would be rejected on host Y"`). A silent bypass means the gate is never
   actually exercised until launch day, which is the worst time to discover it is wrong.

Also honour the existing `?_tenant=` override so a developer can *positively* exercise the gate
locally — the FE must forward it in the hostname argument exactly as the branding query already does.
That override is how you verify the rules work before publishing, since the bypass otherwise hides
every failure. It is Development-only in the existing handler; keep it that way.

**Staging must run with enforcement on** (i.e. not `ASPNETCORE_ENVIRONMENT=Development`) against real
subdomains. This gate cannot be meaningfully tested for the first time in production — the failure
mode is "nobody can log in", and it fails closed.

### 12.6 Landing, now free

With the gate in place, seed `Role.DefaultLandingUrl = 'platform/dashboards'` on the five `PLATFORM_*` roles (no leading slash, no lang prefix — see §11.3). A platform user then lands on the platform dashboard because their role says so, and a tenant user lands on `masterdashboard` because theirs is null — no module sniffing, no FE branch. Retire the Phase-1 branch in `useAuth` and its interim comment in the same commit that applies the seed, not before.

### 12.7 Also fix: `CurrentCompanyId` should follow the host

For a user holding roles in two tenants, `CurrentCompanyId` is `User.CompanyId` regardless of which host they logged in on — so logging in at tenant B yields tenant A's context. Once the host is known, set `CurrentCompanyId` to the **host's** CompanyId when `Kind = Tenant`, and scope `currentCompanyActiveRoles` to it. This is a small change with a wide blast radius (every downstream `CurrentTenantId` consumer), so it is **last, and separately verifiable** — the gate is correct and shippable without it.

### 12.8 The platform/tenant invariant

Enforce in `CreateUser` / `UpdateUser` / role assignment, and assert it in the login gate:

- A user with `CompanyId IS NULL` may hold **only** roles with `Role.CompanyId IS NULL`.
- A user with `CompanyId = N` may hold **only** roles with `Role.CompanyId = N` or `IS NULL`-scoped
  system roles that are explicitly tenant-assignable — **not** the five `PLATFORM_*` roles.
- Reject a mixed assignment with a clear validation message. Do not silently drop the offending role.

If a mixed user somehow exists in data (mis-seeded), the login gate must **fail closed**: log it and
reject on both host kinds rather than guessing which surface the user belongs to. Add a one-off
detection query to the acceptance run.

---

## ⑬ Build steps (Phase 2)

0. **A way to create a platform user** — today nothing mints one; the RBAC seed creates the five roles
   and stops. Minimum viable: an idempotent `sql-scripts-dyanmic/ops-platform-user-seed.sql` that
   creates one `PLATFORM_ADMIN` user with `CompanyId = NULL` and `MustChangePassword = true`, written
   by me and applied by you. A proper platform-user admin screen is a later prompt, not this one —
   but without step 0 there is nobody who can pass the gate on the platform host, so it is first.
1. **`IHostTenantResolver`** (§12.1); refactor `GetTenantLoginConfigHandler` onto it — unchanged behaviour, unchanged cache.
2. **Widen `GetUserCredentialQuery`** with `hostname` and implement the gate (§12.2–12.5). `AuthendicationMutations.Login` reads the host from `IHttpContextAccessor` — but that is the **API** host, which is not necessarily the browser host. If FE and API sit on different hostnames, the browser host must ride in on `LoginRequestDto` or a header; **verify which before writing the gate** and record the answer in §⑮. Getting this wrong fails closed and locks everyone out.
3. **FE** — send the host from the credentials provider (`src/infrastructure/lib/configs/auth.ts`), including the `?_tenant=` dev override.
4. **Seed SQL** — `sql-scripts-dyanmic/platform-role-default-landing-seed.sql`: idempotent `UPDATE auth."Roles" SET "DefaultLandingUrl" = '/platform/dashboards'` for the five `PLATFORM_*` codes where `CompanyId IS NULL`. Write it; **do not run it**.
5. **Retire the Phase-1 landing branch** in `useAuth` (§12.6) — same commit as step 4.
6. **`CurrentCompanyId` follows the host** (§12.7) — optional, last.

---

## ⑭ Acceptance (Phase 2)

- [ ] Tenant-A staff on **tenant B's** host → generic invalid-credentials; no token; a `LoginHistory` row exists; `FailedLoginCount` **unchanged**.
- [ ] Tenant staff on the platform host → same generic rejection.
- [ ] Platform staff on a tenant host → same generic rejection.
- [ ] Platform staff on the platform host → token issued, lands on `/platform/dashboards`.
- [ ] Tenant staff on their own host → unchanged behaviour, lands on `masterdashboard`.
- [ ] SUPERADMIN authenticates on the platform host and is **rejected** on a tenant host; the rejected
      attempt is logged. Tenant support is reachable via `PLATFORM_IMPERSONATE` instead.
- [ ] An unregistered hostname renders the login page but rejects **every** credential, including
      SUPERADMIN's.
- [ ] A user holding both a `PLATFORM_*` role and a tenant role is rejected on both host kinds and the
      condition is logged (§12.8); the detection query returns zero rows in clean data.
- [ ] The rejection response is **byte-identical** to a wrong-password response.
- [ ] **Development:** `localhost` with no `?_tenant=` logs *any* user in — tenant, platform, mismatched
      — each with a Warning naming the verdict that was suppressed. Nothing is blocked locally.
- [ ] **Development:** `?_tenant=` positively exercises the gate, so the rules above can be verified
      before publishing.
- [ ] **Non-Development:** every rejection row in this list actually rejects. Verify on staging with
      real subdomains, not in production.
- [ ] A custom domain (`Companies.CustomDomain`) behaves exactly like the subdomain.
- [ ] `npx tsc --noEmit --incremental false` exits 0.

---

## ⑮ Open questions (Phase 2)

**Q3 — DECIDED: explicit allow-list, unmatched host is a hard reject.** The instruction is that a user
logs in on their own domain and nowhere else, so "no tenant matched ⇒ platform host" is too permissive:
any unregistered hostname pointed at the app would become a platform login page. `HostKind` therefore
gains a third value:

```csharp
public enum HostKind { Platform, Tenant, Unknown }
```

`Unknown` renders the login page (branding falls back to PSS default, unchanged) but **no credential
is ever accepted on it** — same generic rejection as §12.4. `Platform` is only returned for a hostname
on the configured allow-list `Auth:PlatformHosts` (plus `localhost`/`127.0.0.1` when
`IsDevelopment()`). **I still need the production platform hostname(s) from you to fill that config —
this is the one input that blocks step 2.**

**Q6 — NEW, raised by the build: the hostname is client-supplied.** Step 2 concluded (below) that the
API cannot read the browser host from its own request, so the FE sends it on `LoginRequestDto`. That
means a non-browser client — curl, Postman, a script — can claim any host and defeat the gate. It is
not a regression (today there is no gate at all) and it does not weaken the browser path, but it caps
what the gate is worth: it stops cross-tenant login through the UI, not a determined attacker with a
valid password. The trust model was **not** silently changed during the build, because preferring
`Origin`/`Referer` server-side would lock out a single-origin deployment and no such deployment shape
was confirmed. Follow-up, needing a decision: either (a) validate `Origin`/`Referer` against the
claimed host server-side, rejecting a mismatch, or (b) have the edge/reverse proxy stamp a signed host
header the API trusts and the client cannot forge. (b) is the sound one.

**Q4 — does the marketing/apex domain serve login at all?** Relevant to the product-landing-page work now in flight. Cleanest split: apex = marketing + lead form only, `admin.*` = platform login, `{tenant}.*` = tenant login. If the apex must also host the platform login, it joins the Q3 allow-list.

**Q5 — is `Companies.Subdomain` unique and immutable?** The gate assumes one host resolves to at most one company. Confirm a unique index exists, and that changing a live subdomain is an ops action rather than a self-service settings field.
**Partially answered by the build: uniqueness YES**, via filtered unique indexes on `Companies.Subdomain`
and `Companies.CustomDomain` (nulls excluded), so one host can never resolve to two companies.
**Immutability is still unconfirmed** — nothing prevents a live subdomain being edited today, which
would silently lock a tenant's users out until the DNS/config catches up. Still yours to decide.

---

## ⑯ Files (Phase 2)

### Backend (`PSS_2.0_Backend/PeopleServe/Services/Base/`)

| File | Action |
|---|---|
| `Base.Application/Interfaces/IHostTenantResolver.cs` | **new** — `HostKind`, `HostContext`, `ResolveAsync` |
| `Base.Infrastructure/Services/Auth/HostTenantResolver.cs` | **new** — dev `?_tenant=` → platform allow-list → `CustomDomain` → subdomain → `Unknown` |
| `Base.Infrastructure/DependencyInjection.cs` | edit — `AddScoped<IHostTenantResolver, HostTenantResolver>()` |
| `Base.Application/Business/AuthBusiness/Users/Queries/GetUserCredential.cs` | edit — `hostname` param, the gate, break-glass, `LoginHistory` row, §12.7 `CurrentCompanyId` |
| `Base.Application/Schemas/AuthSchemas/AuthSchemas.cs` | edit — `LoginRequestDto.Hostname` |
| `Base.API/EndPoints/Auth/Mutations/AuthendicationMutations.cs` | edit — forward `loginRequest.Hostname` |
| `Base.Application/Helpers/PlatformTenantInvariantHelper.cs` | **new** — §12.8 write-time guard |
| `Base.Application/Business/AuthBusiness/UserRoles/Commands/AssignUserRoles.cs` | edit — guard (the path `CreateUser` delegates to) |
| `Base.Application/Business/AuthBusiness/UserRoles/Commands/CreateUserRole.cs` | edit — guard |
| `Base.Application/Business/AuthBusiness/UserRoles/Commands/UpdateUserRole.cs` | edit — guard |
| `Base.Application/Business/AuthBusiness/Users/Commands/BulkAssignRole.cs` | edit — guard, whole batch pre-validated |
| `Base.API/appsettings.json` | edit — new `Auth` section: `PlatformHosts`, `BreakGlassUsernames` |

No migration. No schema change.

### Frontend (`PSS_2.0_Frontend/src/`)

| File | Action |
|---|---|
| `application/utils/tenant/getLoginHostname.ts` | **new** — browser host + non-production `?_tenant=` override |
| `infrastructure/gql-mutations/auth-mutations/LoginMutation.ts` | edit — `$hostname` argument, request `defaultLandingUrl` |
| `presentation/hooks/useAuth/index.ts` | edit — send the host; Phase-1 branch replaced by the token's landing |

### Seed SQL (`sql-scripts-dyanmic/`, written not run)

| File | Action |
|---|---|
| `ops-platform-user-seed.sql` | **new** (step 0) — one `PLATFORM_ADMIN`, `CompanyId = NULL` |
| `platform-role-default-landing-seed.sql` | **new** (step 4) — five `PLATFORM_*` roles → `platform/dashboards` |
| `platform-tenant-mixed-user-detect.sql` | **new** — §12.8 detection query for the acceptance run |

---

## ⑰ Build log (Phase 2)

### 2026-08-03 — steps 0–6, all built

**Step 2's blocking verification (the one §⑬ said to do first): the API CANNOT read the browser
host.** FE and API are separate origins (`Frontend:BaseUrl` is `dev-psscorefe.peopleserve.app`, the API
is elsewhere), so `IHttpContextAccessor` in the login mutation reports the API's own host, which says
nothing about which tenant's login page the user was standing on. The host therefore rides in on
`LoginRequestDto.Hostname` and `GetUserCredentialQuery` takes it as a parameter. Consequence recorded
as **Q6** above — it is client-supplied, hence spoofable by a non-browser client.

**§12.4 achieved without throwing.** `Login` wraps its body in `try/catch (Exception ex) { Error(ex.Message) }`,
so an exception would have leaked a distinguishing message. The gate returns `user = null` instead,
which falls into the pre-existing `if (result.user == null || !VerifyPassword(...))` branch — identical
message, identical shape. Because the failed-attempt counter block is nested inside `if (result.user != null)`,
`FailedLoginCount` is **not** incremented and the 5-attempt lockout is **not** tripped, exactly as
required: nobody can lock a named account by hammering the wrong subdomain.

**Deviations from §⑬ (paths and one literal, no design changes)**

| Prompt said | Actually built |
|---|---|
| step 3 FE site `src/infrastructure/lib/configs/auth.ts` | `src/presentation/hooks/useAuth/index.ts` — the NextAuth credentials provider only re-wraps `userData` and never calls the BE; the login mutation is fired from `useAuth` |
| step 4 seeds `'/platform/dashboards'` | `'platform/dashboards'` — no leading slash. The literal in §⑬ contradicts §11.3 and `Role.DefaultLandingUrl`'s own doc comment; a leading slash yields `/en//platform/dashboards` |
| `Base.Infrastructure/Services/Auth/` | did not exist; created |

**Other notes**

- **`IsBreakGlass` reads config with `GetSection(...).GetChildren()`, not `.Get<string[]>()`.**
  `Base.Application.csproj` has no `FrameworkReference Microsoft.AspNetCore.App` and the solution has no
  `Configuration.Binder` package, so the binder extension is unavailable there. `HostTenantResolver`
  keeps `.Get<string[]>()` — `Base.Infrastructure.csproj` does carry the framework reference.
- **`Auth:PlatformHosts` ships EMPTY**, pending the production hostname (Q3). Outside Development that
  means no host is the control plane and platform staff cannot log in anywhere — fail-closed by design,
  and the one thing that must be filled before deploying.
- **Step 5 was not a plain deletion.** Removing the Phase-1 branch outright would have sent platform
  staff to `masterdashboard`: the BE already populated `TokenResponseDto.DefaultLandingUrl`, but the FE
  never requested or read it. The replacement consumes the token value, and primes the module store by
  **longest matching `moduleUrl` prefix** (so `crm/membership` beats `crm`) instead of the old
  "PLATFORM and nothing else" inference. It also builds `/{lang}/…`, fixing `MASTER_URL`'s hardcoded `/en/`.
  **Ordering:** `platform-role-default-landing-seed.sql` must be applied **before or with** deploying
  this FE change — the interim branch is gone, so until the seed lands, platform staff get the launcher.
- **§12.8 is enforced at every write path**, not just `CreateUser`/`UpdateUser`: `CreateUser` delegates
  role assignment to `AssignUserRolesCommand`, so the guard sits there plus in `BulkAssignRole`,
  `CreateUserRole` and `UpdateUserRole`. It **rejects** (`BadRequestException`) rather than silently
  dropping the offending role; `BulkAssignRole` pre-validates the whole batch before mutating anything
  and names the offending `UserId`. `UpdateUser` itself touches no roles.
- **Step 6 (§12.7) built.** `CurrentCompanyId` follows the host when the host is a known tenant *and*
  the user actually holds a role there — the membership re-check matters because the gate is advisory
  in Development, and without it a dev bypass would hand out a company context the user has no roles in.

**Typecheck:** `npx tsc --noEmit --incremental false` → **exit 0, no output.**
**Not run (user-owned):** `dotnet build`, all three seed scripts, any migration command. No migration is
needed — this pass changed no schema.
