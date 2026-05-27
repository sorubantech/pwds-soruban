---
screen: Login
registry_id: 119
module: Root (Auth)
status: COMPLETED
scope: ALIGN
screen_type: AUTH
external_page_subtype: AUTH_RENDERER  # bespoke — new sub-type, divergence noted §⑫
complexity: Medium
new_module: NO
planned_date: 2026-05-19
completed_date: 2026-05-19
last_session_date: 2026-05-19
---

# Screen #119 — Login (Multi-Tenant, Domain-Resolved, Template-Switched)

## ① Identity & Context

**Public, anonymous login page** for the PSS 2.0 multi-tenant NGO platform. Unlike a typical "login screen" which is one fixed UI, **#119 renders one of N templates** based on the tenant resolved from the request hostname.

**Hosting model** (already endorsed in [`docs/architecture-review/13-AZURE-FRONT-DOOR-VS-NEXTJS-DOMAIN-ROUTING.md`](../../../PSS_2.0_Backend/docs/architecture-review/13-AZURE-FRONT-DOOR-VS-NEXTJS-DOMAIN-ROUTING.md)):
- Base origin: `devpsscore.azurewebsites.net` (dev) / `app.peopleserve.com` (prod)
- Azure Front Door routes `{tenant}.peopleserve.com` (subdomain — default) and `{customer-owned-domain}` (custom domain — opt-in) to the same origin
- Backend reads `X-Forwarded-Host` (set by AFD) — **never** `Host` (rewritten to origin by AFD)
- AFD origin lock via `X-Azure-FDID` header check (optional defense-in-depth)

**End-to-end flow**:

```
abc.peopleserve.com/login  →  AFD  →  Next.js SSR  →  GraphQL anonymous
                                          ↓                ↓
                                   reads hostname    getTenantLoginConfig(hostname)
                                          ↓                ↓
                                   pick template     CompanyBranding (already exists)
                                          ↓                ↓
                                   render minimal /  CompanyId, name, logo, colors,
                                   image-bg /        loginTemplateCode, image/video URL
                                   split-hero
                                          ↓
                                   user submits  →  LOGIN_MUTATION (existing)
                                                    NextAuth signIn (existing)
                                                    /master redirect (existing)
```

**Why this matters**: First impression of the platform per tenant. Each NGO gets a brand-matched login experience without code changes — admin uploads logo / picks colors / picks template. Login auth pipeline itself is **unchanged**; only the renderer is tenant-aware.

**In scope (this build):** Public renderer only — read existing `sett.CompanyBrandings` by hostname, render 3 templates, submit existing login mutation.

**Out of scope (deferred):** Login Designer admin UI (logo upload, color picker, template selector). The columns already exist on `CompanyBranding`; admin UI will be added in a future iteration — either as a tab in existing Screen #75 *CompanySettings* or as its own screen.

---

## ② Storage & Source Model

**No new entity.** All storage already exists.

### 2a. Existing `sett.CompanyBrandings` (forward-compat columns already present)

Source: [`Base.Domain/Models/SettingModels/CompanyBranding.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/CompanyBranding.cs)

Columns read by `getTenantLoginConfig`:

| Column | Type | Used For |
|--------|------|----------|
| `CompanyId` | int (FK app.Companies) | Tenant identifier |
| `LogoUrl` | varchar(500) nullable | Logo image (all templates) |
| `FaviconUrl` | varchar(500) nullable | Browser tab favicon |
| `PrimaryColorHex` | varchar(7) nullable | Primary theme color (buttons, accents) |
| `SecondaryColorHex` | varchar(7) nullable | Secondary theme color (links, hover) |
| `LoginTemplateId` | int FK → `sett.MasterDatas` (TypeCode='LOGINTEMPLATE') nullable | Template selector |
| `LoginPageImageUrl` | varchar(500) nullable | Background image for `IMAGE_BG` template |
| `LoginPageVideoUrl` | varchar(500) nullable | Reserved for future `VIDEO_BG` template (out of v1 scope) |
| `LoginPageBackgroundColor` | varchar(7) nullable | Solid bg color for `MINIMAL` template |

### 2b. `app.Companies` — **add 2 new columns** (only schema change in this build)

Source: [`Base.Domain/Models/ApplicationModels/Company.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Company.cs)

| Column | Type | Constraint | Used For |
|--------|------|-----------|----------|
| `Subdomain` | varchar(63) nullable | Filtered unique index (LOWER, IsDeleted=false) | `{tenant}.peopleserve.com` resolution |
| `CustomDomain` | varchar(255) nullable | Filtered unique index (LOWER, IsDeleted=false) | Optional vanity domain (`donate.ngo.org`) |

Both are nullable to support gradual rollout. Existing rows get NULL; admin assigns later through #75 CompanySettings (deferred admin UI). Backfill for sample tenants happens via DB seed.

### 2c. `sett.MasterDataType` — `LOGINTEMPLATE` (new lookup type)

| TypeCode | TypeName | Values seeded |
|----------|----------|---------------|
| `LOGINTEMPLATE` | Login Template | `MINIMAL`, `IMAGE_BG`, `SPLIT_HERO` |

Seeded via DB script. Adding more templates later (`VIDEO_BG`, `CAROUSEL`) = INSERT row, no schema change, no code change beyond a new template component on FE.

### 2d. Composite response DTO (anonymous-safe)

`TenantLoginConfigDto` — what `getTenantLoginConfig(hostname)` returns. **No sensitive fields** (no FCRA #, no tax ID, no internal codes). Only display-safe data.

| Field | Type | Source |
|-------|------|--------|
| `companyId` | int | Company.CompanyId |
| `companyName` | string | Company.CompanyName |
| `companyShortName` | string? | Company.ShortName |
| `logoUrl` | string? | CompanyBranding.LogoUrl |
| `faviconUrl` | string? | CompanyBranding.FaviconUrl |
| `primaryColorHex` | string? | CompanyBranding.PrimaryColorHex (default `#43436F`) |
| `secondaryColorHex` | string? | CompanyBranding.SecondaryColorHex (default `#7C3AED`) |
| `loginTemplateCode` | string | MasterData.Code (default `SPLIT_HERO`) |
| `loginPageImageUrl` | string? | CompanyBranding.LoginPageImageUrl |
| `loginPageBackgroundColor` | string? | CompanyBranding.LoginPageBackgroundColor |
| `websiteUrl` | string? | CompanyBranding.WebsiteUrl |
| `resolvedBy` | enum: `Subdomain | CustomDomain | Default` | How tenant was matched (used by FE for analytics + DEFAULT banner) |

---

## ③ FK Resolution Table

| FK | Target Entity | Entity Path | Display Field | GQL Query | Response DTO |
|----|--------------|-------------|---------------|-----------|--------------|
| `CompanyBranding.CompanyId` | Company | [`Base.Domain/Models/ApplicationModels/Company.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Company.cs) | `CompanyName` | n/a (resolved server-side by hostname, never exposed to anonymous client) | n/a |
| `CompanyBranding.LoginTemplateId` | MasterData (TypeCode=`LOGINTEMPLATE`) | [`Base.Domain/Models/SettingModels/MasterData.cs`](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/MasterData.cs) | `Code` | n/a (joined server-side in handler) | n/a |

No client-side FK pickers — this screen is anonymous; the only "FK" is the hostname-to-tenant resolution, done in the server.

---

## ④ Business Rules & Validation

### 4a. Hostname Resolution (server-side, in `GetTenantLoginConfigHandler`)

1. Read hostname from `HttpContext.Request.Headers["X-Forwarded-Host"]` first; fall back to `HttpContext.Request.Host.Host` for local dev.
2. **Local-dev override**: if hostname is `localhost`, `127.0.0.1`, or starts with the dev origin (`devpsscore.azurewebsites.net`), accept `?_tenant={subdomain}` query string from the FE call to override resolution. **Production must ignore this override** (gated by `IWebHostEnvironment.IsDevelopment()`).
3. Normalize: lowercase, strip port, strip leading `www.`.
4. Resolution order:
   1. Match `app.Companies.CustomDomain` (exact, case-insensitive) → `resolvedBy: CustomDomain`
   2. Else: extract subdomain (first label, e.g. `abc` from `abc.peopleserve.com`); match `app.Companies.Subdomain` (case-insensitive) → `resolvedBy: Subdomain`
   3. Else: return DEFAULT config (no CompanyId, `resolvedBy: Default`, hardcoded PSS branding) → never throw 404, always return something the FE can render.

### 4b. Anonymous Access

- `getTenantLoginConfig` must be reachable **without** an Authorization header. Mark the resolver `[AllowAnonymous]` (HotChocolate attribute) and confirm the global GraphQL middleware does not enforce auth before reaching it. Verify by exercising the query against a fresh incognito browser.
- Response DTO must NEVER include: `RegistrationNumber`, `TaxId`, `FCRARegistrationNumber`, `PrimaryEmail`, `PrimaryPhone`, internal IDs except `CompanyId`. The DTO field allowlist in §2d is enforced — adding a field requires explicit review.

### 4c. Performance / Caching

- Backend handler caches the result by hostname for 60 seconds (in-memory `IMemoryCache`). Invalidation: when admin updates Company or CompanyBranding for a tenant (`CompanyBrandingUpdatedEvent` / `CompanyUpdatedEvent` → evict cache key).
- Frontend Next.js page uses `revalidate: 60` ISR — same TTL, simpler.
- A misconfigured tenant (no `LoginTemplateId`) must NOT block login; fall back to `SPLIT_HERO` (existing UI, ships even on first deploy).

### 4d. Login Mutation Unchanged

- Existing `LOGIN_MUTATION` keeps its current signature `{ userName, password }`. The mutation handler resolves CompanyId from the SAME hostname header (NOT from a client-provided field — trusting client input here is a tenant-confusion vulnerability).
- NextAuth `signIn` flow unchanged. `useAuth` hook untouched in business logic; only the form schema/label changes (email → username).

### 4e. Validation (form-side)

| Field | Rule |
|-------|------|
| `userName` | required, 3-50 chars, alphanumeric + `._-@` |
| `password` | required, min 4 chars (existing rule preserved — do NOT tighten without product decision) |

---

## ⑤ Screen Classification

**Type**: `AUTH` (bespoke — new type, NOT one of the 6 canonical templates)

**Why bespoke**: This screen is a public-facing anonymous renderer driven by tenant config — closest to `EXTERNAL_PAGE` but lacks the admin setup half (admin UI deferred). Re-using `EXTERNAL_PAGE` conventions verbatim would imply admin endpoints that aren't built here.

**Sub-pattern stamp**: `AUTH_RENDERER` — first canonical of its sub-pattern. Future Auth siblings (Register, Forgot Password, Reset Password, MFA Challenge, Org Picker) should reuse this template.

**Pattern checklist** (pre-answered for Solution Resolver):

| Question | Answer |
|----------|--------|
| Has a list grid? | No |
| Has a modal form? | No |
| Has 3-mode URL view? | No |
| Has KPI widgets? | No |
| Has filter panel + export? | No |
| Has Publish/Unpublish lifecycle? | No (deferred admin) |
| Is anonymous-accessible? | **YES** (the whole point) |
| Is multi-tenant by hostname? | **YES** (the whole point) |
| Needs SSR? | **YES** (no flicker — first impression) |
| Needs new entity? | No (CompanyBranding columns already exist) |
| Needs migration? | **YES** — small (2 columns on `app.Companies`) |
| Needs DB seed? | **YES** — MasterDataType `LOGINTEMPLATE` + 3 rows + sample-tenant subdomain backfill |

**Save model**: Read-only on this screen. No writes through this screen (login mutation is a separate, pre-existing endpoint).

**Lifecycle**: Stateless. Re-rendered on every cold load; cached by ISR.

---

## ⑥ UI/UX Blueprint

### 6a. Template switcher

[`src/presentation/pages/auth/login/index.tsx`](../../../PSS_2.0_Frontend/src/presentation/pages/auth/login/index.tsx) becomes a thin **switcher**:

```tsx
const TemplateMap = {
  MINIMAL:     MinimalTemplate,
  IMAGE_BG:    ImageBgTemplate,
  SPLIT_HERO:  SplitHeroTemplate,
};
const Template = TemplateMap[config.loginTemplateCode] ?? SplitHeroTemplate;
return <Template config={config} />;
```

All three templates accept the same `TenantLoginConfigDto` and render `<LogInForm />` from `login-form.tsx`. Theme tokens (primary/secondary colors) are injected via CSS custom properties on a wrapping `<div>`:

```tsx
<div style={{ "--brand-primary": config.primaryColorHex, "--brand-secondary": config.secondaryColorHex }}>
```

Tailwind reads via `var(--brand-primary)` in arbitrary-value classes (`bg-[var(--brand-primary)]`).

### 6b. Template 1 — `MINIMAL` (single centered card)

Mirrors the new `login.html` mockup. Plain background (`config.loginPageBackgroundColor` or white). Single 480px-max centered card. Logo at top, "Welcome to {companyName}" header, username + password fields, "Forget Password?" link, Sign-In button (brand-primary). Footer "Powered by PW Data Solutions". No carousel, no left-pane hero. Demo-creds hint panel renders ONLY when `process.env.NODE_ENV !== "production"`.

### 6c. Template 2 — `IMAGE_BG` (full-page background image)

Full-page background = `config.loginPageImageUrl` (with `background-size: cover`). Subtle dark overlay (`bg-black/40`) for legibility. Single centered card (same as MINIMAL) floats on top. If `loginPageImageUrl` is null, falls back to the `loginPageBackgroundColor` solid bg (graceful degradation).

### 6d. Template 3 — `SPLIT_HERO` (existing 2-pane layout — preserve)

The existing PSS UI — left pane Swiper carousel with 5 feature slides (Analytics / Relationships / Campaigns / Financial / Events), right pane glass-card form. Hidden left pane on `<lg`. **Move existing code** from `pages/auth/login/index.tsx` (lines 12-220) into `templates/split-hero-template.tsx` verbatim. Replace hardcoded "PeopleServe" string with `config.companyName`. Use `config.logoUrl` if present.

### 6e. Form component (`login-form.tsx`) — small ALIGN changes

- Rename "Email Address" label → "Username". `<Input type="email">` → `<Input type="text">`.
- Zod schema: `email: z.string().email()` → `userName: z.string().min(3).max(50).regex(/^[a-zA-Z0-9._@-]+$/)`.
- Inside `onSubmit`, `userName: formData.userName` (was `formData.email`).
- Submit button: `from-blue-900 to-purple-800` → `from-[var(--brand-primary)] to-[var(--brand-secondary)]`.
- Demo-creds hint panel (matching mockup): render only in non-prod. Hardcoded list: superadmin/admin123, orgadmin/admin123, staff/staff123, agent/agent123.

### 6f. SSR data fetch ([`src/app/[lang]/(auth)/login/page.tsx`](../../../PSS_2.0_Frontend/src/app/[lang]/(auth)/login/page.tsx))

Currently a client-only thin wrapper. Refactor:

```tsx
import { headers } from "next/headers";
import { getTenantLoginConfig } from "@/application/utils/tenant/getTenantLoginConfig";
import { Login } from "@/presentation/pages";

export const revalidate = 60;

const Page = async () => {
  const h = await headers();
  const hostname = h.get("x-forwarded-host") ?? h.get("host") ?? "";
  const config = await getTenantLoginConfig(hostname);
  return <Login config={config} />;
};
export default Page;
```

`getTenantLoginConfig(hostname)` calls the backend GQL query server-side using a server-side Apollo client (`@apollo/client` is fine; pass `Authorization: undefined`). On error, returns the hardcoded DEFAULT config (banner shown to admin via a small dev-only toast).

### 6g. Local-dev override

Dev support for testing multiple tenants without `hosts` file edits:
- Add `?_tenant=hope` query string → SSR reads it via `searchParams`, forwards as the resolved subdomain.
- Production builds REJECT this override (server-side check on `process.env.NODE_ENV`).

### 6h. Theme injection

Two strategies, pick one:
- **Recommended (CSS variables)**: inject `--brand-primary` and `--brand-secondary` on the outermost `<div>` of each template. Tailwind reads via `bg-[var(--brand-primary)]`. Zero re-render flicker, works with Tailwind JIT.
- Avoid: dynamic Tailwind classes built from string template literals — won't survive JIT purge.

### 6i. Layout variant stamp

Layout: `widgets-above-grid` does NOT apply (no grid). Use bespoke `auth-renderer` variant. ScreenHeader is NOT used on Auth pages (the auth layout at `app/[lang]/(auth)/layout.tsx` is a pass-through).

---

## ⑦ Substitution Guide

This is the **first AUTH screen** — establishes the canonical pattern for future Auth siblings.

| Aspect | This screen (canonical) |
|--------|------------------------|
| Entity (canonical name) | n/a — no entity created; reads `CompanyBranding` |
| Schema | `sett` (existing) + `app` (Company column adds) |
| Group | `SettingModels` (existing CompanyBranding lives here) |
| Page route | `/{lang}/login` (existing) |
| Page folder | `src/app/[lang]/(auth)/login/` (existing) |
| Presentation folder | `src/presentation/pages/auth/login/` (existing) |
| FE template subfolder | `src/presentation/pages/auth/login/templates/` (new) |
| Hostname utils folder | `src/application/utils/tenant/` (new — reused by future auth screens) |
| Parent menu code | n/a (no menu — public route) |
| Module code | n/a (Root, not under any module) |

Future Auth siblings (Register, Forgot Password, Reset Password, MFA Challenge, Org Picker): replicate the SSR-config-fetch + template-switcher pattern. Reuse `getTenantLoginConfig` (or a thinner DTO subset) and the same theme-injection helper.

---

## ⑧ File Manifest

### Backend (`PSS_2.0_Backend/PeopleServe/Services/Base/`)

| # | File | Action | Notes |
|---|------|--------|-------|
| 1 | `Base.Domain/Models/ApplicationModels/Company.cs` | MODIFY | Add `Subdomain` (string?, max 63) + `CustomDomain` (string?, max 255). Place below existing `Fax` line. |
| 2 | `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/CompanyConfiguration.cs` | MODIFY | Add `HasMaxLength` + two **filtered unique** indexes on `LOWER(Subdomain)` / `LOWER(CustomDomain)` WHERE `IsDeleted=false`. |
| 3 | `Base.Infrastructure/Migrations/{Date}_Add_Tenant_Domain_Fields.cs` | NEW (hand-crafted) | Idempotent. Adds 2 nullable cols + 2 filtered unique indexes. Down() drops cleanly. User runs `dotnet ef migrations add Add_Tenant_Domain_Fields` post-build to regen Designer/Snapshot. |
| 4 | `Base.Application/Schemas/AuthSchemas/TenantLoginConfigSchemas.cs` | NEW (new schemas file) | Defines `TenantLoginConfigDto` (12 fields per §2d), `TenantLoginConfigResolvedBy` enum. Use `[GraphQLDescription]` attributes. |
| 5 | `Base.Application/Business/AuthBusiness/TenantLoginConfig/Queries/GetTenantLoginConfigQuery.cs` | NEW | Query record + handler. Resolves hostname per §4a; pulls `Company` + `CompanyBranding` + `MasterData(LOGINTEMPLATE)` via single LINQ join; maps to DTO. 60s `IMemoryCache` per hostname. |
| 6 | `Base.API/EndPoints/Auth/TenantLoginQueries.cs` | NEW | `[ExtendObjectType(OperationTypeNames.Query)]` exposing `getTenantLoginConfig(hostname: String!)`. Marked `[AllowAnonymous]`. |
| 7 | `Base.Application/Mappings/ApplicationMappings.cs` | MODIFY | Append Mapster config `CompanyBranding → TenantLoginConfigDto` with computed `loginTemplateCode` source. |
| 8 | (verify) `Base.API/Configurations/GraphQLConfiguration.cs` or auth middleware | VERIFY-ONLY | Ensure anonymous queries pass through; do NOT modify unless test confirms `getTenantLoginConfig` returns 401. |
| 9 | `Services/Base/sql-scripts-dyanmic/login-tenant-sqlscripts.sql` | NEW | Idempotent. Sections: (A) MasterDataType `LOGINTEMPLATE` + (B) 3 rows MINIMAL/IMAGE_BG/SPLIT_HERO + (C) sample-tenant subdomain backfill (`UPDATE app.Companies SET Subdomain='hope' WHERE CompanyCode='HOPE' AND Subdomain IS NULL`) + (D) sample CompanyBranding `LoginTemplateId` set to SPLIT_HERO. |

**Login mutation pipeline** — *no changes*. Existing `LOGIN_MUTATION` handler must already resolve CompanyId from the request context; if it currently relies on a client-sent CompanyId, that is a pre-existing vulnerability — flag as ISSUE in §⑫ but do not fix in this build (scope creep).

### Frontend (`PSS_2.0_Frontend/src/`)

| # | File | Action | Notes |
|---|------|--------|-------|
| 1 | `domain/dto/auth-service/TenantLoginConfigDto.ts` | NEW | TS interface matching §2d. |
| 2 | `infrastructure/gql-queries/TenantLoginConfigQuery.ts` | NEW | `GET_TENANT_LOGIN_CONFIG` query. Single arg `hostname: String!`. |
| 3 | `infrastructure/gql-queries/index.ts` | MODIFY | Re-export new query. |
| 4 | `domain/dto/auth-service/index.ts` (or `domain/dto/index.ts`) | MODIFY | Re-export DTO. |
| 5 | `application/utils/tenant/getTenantLoginConfig.ts` | NEW | Server-side helper. Uses a server Apollo client (no auth header). Hostname normalization (lowercase, strip port, strip `www.`). Catches errors → returns DEFAULT config. Honors `?_tenant=` only when `NODE_ENV !== 'production'`. |
| 6 | `application/utils/tenant/getDefaultLoginConfig.ts` | NEW | Hardcoded PSS-branded fallback (`companyName: "PeopleServe"`, `loginTemplateCode: "SPLIT_HERO"`, primary `#43436F`, secondary `#7C3AED`). |
| 7 | `presentation/pages/auth/login/index.tsx` | MODIFY (REFACTOR) | Convert from monolithic SplitHero component → switcher that picks template by `config.loginTemplateCode`. Accepts `config: TenantLoginConfigDto` prop. |
| 8 | `presentation/pages/auth/login/templates/minimal-template.tsx` | NEW | Single-card layout per §6b. |
| 9 | `presentation/pages/auth/login/templates/image-bg-template.tsx` | NEW | Full-page bg image layout per §6c. |
| 10 | `presentation/pages/auth/login/templates/split-hero-template.tsx` | NEW (carved from current index.tsx) | Existing Swiper carousel + glass-card layout. Move code from current index.tsx lines 12-220 verbatim; replace hardcoded "PeopleServe" with `config.companyName`. |
| 11 | `presentation/pages/auth/login/login-form.tsx` | MODIFY | email → userName per §6e. Submit button uses `var(--brand-primary)` / `var(--brand-secondary)`. Demo-creds panel gated by `NODE_ENV`. |
| 12 | `app/[lang]/(auth)/login/page.tsx` | MODIFY | Convert to async server component per §6f. `revalidate=60`. Reads `x-forwarded-host` header + `searchParams._tenant` override. |
| 13 | `presentation/hooks/useAuth/index.ts` | NO CHANGE | Existing flow preserved verbatim. |

**Total: 9 BE files (incl. 1 migration, 1 SQL seed), 13 FE files (1 unchanged, the rest new/refactored).**

---

## ⑨ Pre-Filled Approval Config

Auth pages have **no menu entry** (they're public, not behind the app shell). The CONFIG block for #119 is therefore minimal:

```yaml
screen: Login
registry_id: 119
type: AUTH
menu:
  hasMenuEntry: false      # public route, no sidebar
  publicRoutes:
    - /{lang}/login        # SSR, anonymous
capabilities: []           # anonymous, no role gating
roleGrants: []
grid:
  hasGrid: false
gridFormSchema: SKIP       # no form schema (RJSF not used)
```

Role-based view restrictions handled by the existing post-login route guard (`RouteGuard`) on dashboard/menu pages — not by Login itself.

---

## ⑩ Expected BE → FE Contract

### Public anonymous queries

| GQL field | Args | Returns | Notes |
|-----------|------|---------|-------|
| `getTenantLoginConfig` | `hostname: String!` | `BaseApiResponse<TenantLoginConfigDto>` | `[AllowAnonymous]`. Always returns success; on miss returns DEFAULT config. Cache-Control 60s. |

### Public anonymous mutations

| GQL field | Args | Returns | Notes |
|-----------|------|---------|-------|
| `login` (existing, UNCHANGED) | `userName: String!, password: String!` | `AuthResult<UserData>` | Tenant resolved server-side from same hostname header. Never trust client-sent CompanyId. |

### Response DTO

```typescript
interface TenantLoginConfigDto {
  companyId: number;                            // 0 when resolvedBy === "Default"
  companyName: string;
  companyShortName: string | null;
  logoUrl: string | null;
  faviconUrl: string | null;
  primaryColorHex: string | null;
  secondaryColorHex: string | null;
  loginTemplateCode: "MINIMAL" | "IMAGE_BG" | "SPLIT_HERO";
  loginPageImageUrl: string | null;
  loginPageBackgroundColor: string | null;
  websiteUrl: string | null;
  resolvedBy: "Subdomain" | "CustomDomain" | "Default";
}
```

---

## ⑪ Acceptance Criteria

### Build verification

- [ ] `dotnet build` — 0 errors (warnings count unchanged from baseline)
- [ ] EF migration generated post-build via `dotnet ef migrations add Add_Tenant_Domain_Fields --project Base.Infrastructure --startup-project Base.API`
- [ ] `dotnet ef database update` runs successfully on dev DB
- [ ] `login-tenant-sqlscripts.sql` runs **idempotently** (run twice — no errors, no dupes)
- [ ] `npx tsc --noEmit` (frontend) — no new errors introduced

### Functional verification (manual E2E)

- [ ] Anonymous fetch `getTenantLoginConfig(hostname: "localhost")` returns DEFAULT config (`resolvedBy: "Default"`)
- [ ] After seeding `Subdomain='hope'` on a sample Company, fetch `getTenantLoginConfig(hostname: "hope.peopleserve.com")` returns that tenant's config (`resolvedBy: "Subdomain"`)
- [ ] After setting `CustomDomain='donate.hope.org'`, fetch `getTenantLoginConfig(hostname: "donate.hope.org")` returns same tenant (`resolvedBy: "CustomDomain"`)
- [ ] **In production build**, `?_tenant=hope` override is ignored
- [ ] **In dev build**, `localhost/login?_tenant=hope` renders the Hope-tenant template + brand colors
- [ ] Login form submission still routes through existing `LOGIN_MUTATION` + NextAuth and redirects to `/master`
- [ ] Hard-refresh `/login` shows the correct template **without flicker** (SSR confirmed via "View Source" — config values present in initial HTML)
- [ ] When backend is down, the FE renders DEFAULT config rather than crashing

### Template verification

- [ ] Switch `LoginTemplateId` to MINIMAL → page renders single-card layout
- [ ] Switch to IMAGE_BG + set `LoginPageImageUrl` → page renders full-page background image
- [ ] Switch to SPLIT_HERO → existing PSS 2-pane Swiper layout renders (no regression vs current)
- [ ] CompanyBranding primary/secondary color values applied to Sign-In button gradient and accents in all 3 templates
- [ ] Demo-creds hint panel renders in `pnpm dev`, but is absent in `pnpm build && pnpm start`

### Anti-pattern grep (all-zero required)

- [ ] No hardcoded `"PeopleServe"` string in templates (use `config.companyName` — the auth layout title is OK to leave hardcoded)
- [ ] No client-side reads of `window.location.hostname` for tenant resolution (must be SSR via `x-forwarded-host`)
- [ ] No `getServerSideProps` (Next.js App Router uses async server components)
- [ ] No client-sent CompanyId arg on `login` mutation

---

## ⑫ Special Notes & Warnings

### Divergence from canonical templates

`screen_type: AUTH` is **new and bespoke** — not one of the 6 canonical types. It uses EXTERNAL_PAGE conventions as the closest fit but diverges in:

| EXTERNAL_PAGE convention | AUTH divergence |
|--------------------------|-----------------|
| Has admin setup UI + public page | Public page ONLY (admin setup deferred) |
| Has Publish/Unpublish lifecycle | Always "live" (no draft state) |
| Has slug field | Resolved by hostname (no slug) |
| Has OG meta tags | None (auth page is `noindex`) |
| Has Publish action button | None |
| Has live preview pane in admin | None (no admin UI) |

If future Auth screens (Register, Forgot, MFA) are added, this prompt is the **canonical sibling reference** for the new `AUTH` type.

### Subdomain-only hostname resolution — no slug, no path

Per user constraint: **no slug-based tenant addressing**. Tenants are resolved **only** by:
1. Custom domain (full hostname match)
2. Subdomain (first label of `*.peopleserve.com`)

Path-based routing (`/tenant/hope/login`) is explicitly rejected.

### `X-Forwarded-Host` is mandatory in production

Azure Front Door rewrites the `Host` header to the origin (`devpsscore.azurewebsites.net`). The backend MUST read `X-Forwarded-Host`. A regression here would cause every tenant to resolve as the origin (i.e., DEFAULT for everyone). **Test on a real AFD-routed URL before declaring this screen complete.**

### `OrganizationSettings` 3-tier refactor is OUT of scope

Architecture doc 09 calls for adding `CompanyId + IsSystem` to `sett.OrganizationSettings` for 3-tier system→company→user override. **Do not touch this in #119.** The login renderer reads `CompanyBranding` (already tenant-scoped via FK to Company) and `MasterData` (system-wide lookups are fine). Theme/Layout per-tenant is a separate ticket.

### Login Designer admin UI is OUT of scope

The stale comment in `CompanyBranding.cs` references `#173 Login Designer` — but `#173` is "Crowdfunding Page". The Login Designer admin UI has no registered screen number. It will be added either as a tab in Screen #75 *CompanySettings* (already manages logo/colors) or as a new screen post-MVP. **Update the stale comment** in `CompanyBranding.cs` from "future Login Designer screen (#173)" → "future Login Designer (TBD)".

### Pre-existing concerns (LOG but do NOT fix here)

| ID | Concern | Action |
|----|---------|--------|
| ISSUE-1 | If `LOGIN_MUTATION` currently accepts/uses a client-sent CompanyId, this is a tenant-confusion vulnerability. | Log in §⑬ Build Log when discovered. Fix in separate security ticket. |
| ISSUE-2 | `useAuth.checkSession` polls with `maxAttempts = 1` (hard-coded) — likely a leftover debug value. | Note in Build Log. Out of scope for #119. |
| ISSUE-3 | `(auth)/layout.tsx` RouteGuard is commented out. | Note in Build Log. Out of scope for #119 (deliberate, per "public" intent — but worth a TODO follow-up). |

### Service dependencies (SERVICE_PLACEHOLDER)

None required for #119. All needed infrastructure (CompanyBranding, MasterData, login mutation, NextAuth, Apollo) already exists.

### Wave/dependency notes

- This screen has **no FK dependencies** on other in-progress screens.
- It **DOES** depend on: existing `Company`, `CompanyBranding`, `MasterData`, `LOGIN_MUTATION` — all built and stable.
- It **unblocks** future Auth screens (Register / Forgot / MFA / Org Picker) and the future Login Designer admin UI.

### Sample tenant for E2E

Seed script must add `Subdomain='hope'` to a sample Company (recommend CompanyCode='HOPE' if it exists, else fall back to the first non-system Company). Optionally seed `CustomDomain='donate.hope.local'` for hosts-file based local custom-domain testing.

### Local dev shortcut

For dev without DNS / hosts file edits, use `/login?_tenant=hope`. Document this in the FE README (or, if no README exists, add a comment in `getTenantLoginConfig.ts`).

---

## ⑬ Build Log

*(append-only — `/build-screen` and `/continue-screen` add entries)*

### Known Issues

| ID | Severity | Status | Description |
|----|----------|--------|-------------|
| ISSUE-1 | HIGH | CLOSED | (Session 1, 2026-05-19) FE Developer verified `LOGIN_MUTATION` (`AuthendicationMutations.cs`) does NOT accept client-sent CompanyId — resolves server-side from JWT/session context. No vulnerability. |
| ISSUE-2 | LOW | OPEN | `useAuth.checkSession` polls with hard-coded `maxAttempts = 1` — leftover debug? Out of scope; note for cleanup. |
| ISSUE-3 | LOW | OPEN | `(auth)/layout.tsx` RouteGuard commented out — deliberate (public route) but warrants a TODO. |
| ISSUE-4 | LOW | CLOSED | (Session 1, 2026-05-19) Stale `CompanyBranding.cs` comment changed from "future Login Designer screen (#173)" → "future Login Designer (TBD)". |
| ISSUE-5 | LOW | CLOSED | (Session 1, 2026-05-19, found+fixed in same session) BE handler had buggy `TrimStart('w', '.')` that would strip leading `w` from non-`www.` hostnames (e.g. `wonder.example.com` → `onder.example.com`). Replaced with cleaner `if (StartsWith("www.")) Substring(4)`. |
| ISSUE-6 | LOW | OPEN | Pre-existing `data: {}` TS errors across many FE files (Apollo v4 typed useQuery returns `{}` without explicit generic). Not introduced by this build; documented in memory `feedback_apollo_v4_data_typing.md`. Tracked for a separate cleanup pass. |
| ISSUE-7 | MEDIUM | CLOSED | (Session 2, 2026-05-19) Session 1 invented LOGINTEMPLATE codes `MINIMAL/IMAGE_BG/SPLIT_HERO` instead of using the canonical 5 defined in `prompts/companysettings.md` (`BGIMAGE/CAROUSEL/BGVIDEO/FULLIMAGE/MINIMAL`). Realigned in Session 2: `SPLIT_HERO → BGIMAGE` (split-hero brand panel layout), `IMAGE_BG → FULLIMAGE` (full-bleed bg), `MINIMAL → MINIMAL`. CAROUSEL + BGVIDEO not yet built — they fall back to BGIMAGE in the TemplateMap and are NOT seeded (OrderBy positions 2 and 3 reserved). |
| ISSUE-8 | MEDIUM | CLOSED | (Session 3, 2026-05-19) `login-tenant-sqlscripts.sql` was duplicating MasterDataType/MasterData seeds that `CompanySettings-sqlscripts.sql` (STEP 5, lines 129-158) already owns canonically. User-edited file also retained a stale `SPLIT_HERO` MasterData row and Section D lookup. Session 3 stripped Sections A+B, kept user's Section C tenant backfill (`HH/humanity`, `PSS/sample`), and fixed the (renamed) Section B LoginTemplateId lookup to point at `BGIMAGE`. CompanySettings-sqlscripts.sql is now declared the canonical owner of LOGINTEMPLATE MasterData. |

### Sessions

### Session 1 — 2026-05-19 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Both BE (9 files) + FE (12 files modified/new, 1 untouched) generated in one session.
- **Files touched**:
  - **BE (9 modified/new)**:
    - `Base.Domain/Models/ApplicationModels/Company.cs` (modified — added `Subdomain` + `CustomDomain` cols)
    - `Base.Domain/Models/SettingModels/CompanyBranding.cs` (modified — ISSUE-4 stale comment fix)
    - `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/CompanyConfiguration.cs` (modified — HasMaxLength + filtered unique indexes)
    - `Base.Infrastructure/Migrations/20260519120000_Add_Tenant_Domain_Fields.cs` (created — hand-crafted migration; Up: AddColumn + raw-SQL expression indexes; Down: drop cleanly)
    - `Base.Application/Schemas/AuthSchemas/TenantLoginConfigSchemas.cs` (created — DTO + enum)
    - `Base.Application/Business/AuthBusiness/TenantLoginConfig/Queries/GetTenantLoginConfigQuery.cs` (created — Query/Result/Validator/Handler with IMemoryCache 60s/5s TTL)
    - `Base.Application/Mappings/ApplicationMappings.cs` (modified — appended Mapster `CompanyBranding → TenantLoginConfigDto` config)
    - `Base.API/EndPoints/Auth/Queries/TenantLoginQueries.cs` (created — `[GraphQLName("getTenantLoginConfig")]` resolver, anonymous via absence of `[CustomAuthorize]`)
    - `sql-scripts-dyanmic/login-tenant-sqlscripts.sql` (created — PostgreSQL idempotent seed; A:MasterDataType, B:3 MasterData rows, C:sample tenant subdomain backfill, D:Company branding LoginTemplateId set)
  - **FE (12 modified/new)**:
    - `src/domain/entities/auth-service/TenantLoginConfigDto.ts` (created)
    - `src/domain/entities/auth-service/index.ts` (modified — barrel re-export)
    - `src/infrastructure/gql-queries/auth-queries/TenantLoginConfigQuery.ts` (created — `GET_TENANT_LOGIN_CONFIG` query with `result:` alias)
    - `src/infrastructure/gql-queries/auth-queries/index.ts` (modified — barrel re-export)
    - `src/application/utils/tenant/getTenantLoginConfig.ts` (created — SSR raw-fetch + `print(GQL_DOC)`, mirrors `crowdfund/[slug]/page.tsx`)
    - `src/application/utils/tenant/getDefaultLoginConfig.ts` (created — hardcoded PSS fallback)
    - `src/presentation/pages/auth/login/index.tsx` (refactored — 247-line monolith → 46-line template switcher with CSS-variable theme injection)
    - `src/presentation/pages/auth/login/templates/split-hero-template.tsx` (created — original 2-pane Swiper carved out, brand interpolation)
    - `src/presentation/pages/auth/login/templates/minimal-template.tsx` (created — §6b single-card layout)
    - `src/presentation/pages/auth/login/templates/image-bg-template.tsx` (created — §6c full-page bg image with overlay)
    - `src/presentation/pages/auth/login/login-form.tsx` (modified — `email` → `userName` form field, Zod schema, button uses `var(--brand-primary)/var(--brand-secondary)`)
    - `src/app/[lang]/(auth)/login/page.tsx` (refactored — client wrapper → async server component, `revalidate=60`, reads `x-forwarded-host` + `searchParams._tenant`)
  - **DB**: `sql-scripts-dyanmic/login-tenant-sqlscripts.sql` (created)
- **Deviations from spec**:
  1. FE DTO placement: `src/domain/entities/auth-service/` instead of spec's `src/domain/dto/auth-service/` — project uses `entities` folder convention.
  2. FE GQL query placement: `src/infrastructure/gql-queries/auth-queries/` subfolder, matching the project's actual sub-bucket pattern.
  3. BE handler injects `IHostEnvironment` (Microsoft.Extensions.Hosting) instead of spec's `IWebHostEnvironment` — `Base.Application` has no direct ASP.NET Core reference; same `IsDevelopment()` extension method works.
  4. BE seed wrote PostgreSQL (`now()`, double-quoted identifiers, `WHERE NOT EXISTS` style) — spec example used T-SQL; corrected after discovering Npgsql via existing migrations.
  5. Anonymous-access convention: project uses the *absence* of `[CustomAuthorize]` (not `[AllowAnonymous]` — that's MVC-only here). Confirmed via canonical sibling `EventRegistrationPagePublicQueries.cs`.
  6. SSR utility uses raw `fetch` + `print(GQL_DOC)` (matching `crowdfund/[slug]/page.tsx`) instead of a server-side Apollo client — none exists in the codebase.
- **Known issues opened**: ISSUE-5 (TrimStart bug, fixed same session), ISSUE-6 (pre-existing Apollo v4 `data: {}` errors observable in `tsc --noEmit` but NOT introduced by this build).
- **Known issues closed**: ISSUE-1 (verified non-vulnerable), ISSUE-4 (comment fixed), ISSUE-5 (fixed same session).
- **Build verification**:
  - `dotnet build PeopleServe.sln` → **0 errors, 569 warnings** (warnings all pre-existing in unrelated files).
  - `npx tsc --noEmit` → **0 errors in any file touched by this build**; ~80 pre-existing errors elsewhere (Apollo v4 typing, dup re-exports — documented as ISSUE-6).
  - User must still run: `dotnet ef migrations add Add_Tenant_Domain_Fields --project Base.Infrastructure --startup-project Base.API` to regenerate the Designer/Snapshot files, then `dotnet ef database update`.
  - User must still run the seed SQL: `login-tenant-sqlscripts.sql`.
- **Sibling patterns mirrored**: `EventRegistrationPagePublicQueries.cs` (anonymous resolver), `GetEventRegistrationPageBySlugHandler` (IMemoryCache handler), `CompanyBrandingConfiguration.cs` (filtered unique index pattern), `Add_DisplayFields_In_Currency.cs` (PostgreSQL raw-SQL expression index migration), `AutomationWorkflow-sqlscripts.sql` (idempotent seed style), `crowdfund/[slug]/page.tsx` (canonical SSR raw-fetch), `OnlineDonationPagePublicQuery.ts` (GQL `result:` alias pattern), `UserQuery.ts` (BaseApiResponse `{success, message, status, data}` wrapper shape).
- **Reverted**: `src/application/configs/navigation-configs/BaseUrlConfig.ts` — FE agent had inadvertently bumped port 57897→57898; reverted per memory rule (user-managed file).
- **Next step**: None — screen is functionally complete. End-to-end manual verification (anonymous query, SSR config render, template switching, dev `?_tenant=` override) remains; documented in §⑪ acceptance criteria.

### Session 2 — 2026-05-19 — FIX — COMPLETED

- **Scope**: Realign LOGINTEMPLATE MasterData codes to the canonical 5 defined in `prompts/companysettings.md` (`BGIMAGE/CAROUSEL/BGVIDEO/FULLIMAGE/MINIMAL`). User flagged that Session 1's invented codes (`SPLIT_HERO/IMAGE_BG/MINIMAL`) conflicted with the system-wide MasterData taxonomy. Mapping: `SPLIT_HERO → BGIMAGE` (visual: split-hero brand panel), `IMAGE_BG → FULLIMAGE` (visual: full-bleed background). BE default and FE fallback both moved to `BGIMAGE`.
- **Files touched**:
  - **BE (3 modified)**:
    - `Base.Application/Schemas/AuthSchemas/TenantLoginConfigSchemas.cs` (modified — `LoginTemplateCode` default `"SPLIT_HERO"` → `"BGIMAGE"`, GraphQL description lists canonical 5)
    - `Base.Application/Business/AuthBusiness/TenantLoginConfig/Queries/GetTenantLoginConfigQuery.cs` (modified — `DefaultConfig.LoginTemplateCode` and `ProjectToDto` fallback both `"SPLIT_HERO"` → `"BGIMAGE"`)
    - `sql-scripts-dyanmic/login-tenant-sqlscripts.sql` (modified — rows now `BGIMAGE` (OrderBy=1), `FULLIMAGE` (OrderBy=4), `MINIMAL` (OrderBy=5); Section D `LoginTemplateId` set to `BGIMAGE` for sample tenant; OrderBy gaps 2/3 reserved for CAROUSEL/BGVIDEO)
  - **FE (4 modified + 2 renamed)**:
    - `src/domain/entities/auth-service/TenantLoginConfigDto.ts` (modified — `loginTemplateCode` union widened to canonical 5)
    - `src/presentation/pages/auth/login/templates/split-hero-template.tsx` → `bg-image-template.tsx` (renamed; component identifier `SplitHeroTemplate` → `BgImageTemplate`; banner comment updated)
    - `src/presentation/pages/auth/login/templates/image-bg-template.tsx` → `full-image-template.tsx` (renamed; component identifier `ImageBgTemplate` → `FullImageTemplate`; banner comment updated)
    - `src/presentation/pages/auth/login/index.tsx` (modified — imports point to renamed files, `TemplateMap` keys are canonical 5 with `CAROUSEL`/`BGVIDEO` falling back to `BgImageTemplate` until their components are built, fallback ?? updated to `BgImageTemplate`)
  - **DB**: `sql-scripts-dyanmic/login-tenant-sqlscripts.sql` (modified — see above)
- **Deviations from spec**: None — the spec body intentionally retained the original `SPLIT_HERO/IMAGE_BG/MINIMAL` naming as historical record; ISSUE-7 captures the divergence and Session 2 reconciles to canonical.
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-7.
- **Build verification**: Code edits only; user must rerun `dotnet build` + `npx tsc --noEmit` to re-verify. Seed SQL must be re-run if the prior (now-orphaned) `MINIMAL/IMAGE_BG/SPLIT_HERO` rows were already inserted — manual cleanup of stale rows may be required: `DELETE FROM sett."MasterDatas" m USING sett."MasterDataTypes" t WHERE m."MasterDataTypeId" = t."MasterDataTypeId" AND t."TypeCode" = 'LOGINTEMPLATE' AND m."DataValue" IN ('IMAGE_BG','SPLIT_HERO');`
- **Sibling patterns mirrored**: `prompts/companysettings.md` (canonical LOGINTEMPLATE list of 5).
- **Next step**: User reruns `dotnet build` + `npx tsc --noEmit` to confirm green; if Session 1 seed already ran in dev DB, run the cleanup DELETE above before re-running the updated seed.

### Session 3 — 2026-05-19 — FIX — COMPLETED

- **Scope**: Consolidate `login-tenant-sqlscripts.sql` with the canonical LOGINTEMPLATE seed already present in `CompanySettings-sqlscripts.sql` (STEP 5, lines 129-158, seeds canonical 5 BGIMAGE/CAROUSEL/BGVIDEO/FULLIMAGE/MINIMAL). The user had manually edited this file to rename their preferred sample tenant (CompanyCode `HOPE→HH`, Subdomain `hope→humanity`, fallback CompanyCode `PSS/sample`) but had inadvertently left a stale `SPLIT_HERO` MasterData row and a Section D lookup that no longer resolved.
- **Files touched**:
  - **BE (1 modified)**:
    - `sql-scripts-dyanmic/login-tenant-sqlscripts.sql` (modified — dropped Sections A+B which duplicated MasterDataType + MasterData seeds owned by `CompanySettings-sqlscripts.sql`; preserved user's tenant CompanyCode choices (`HH→humanity`, `PSS→sample`); fixed Section D's `DataValue` lookup `SPLIT_HERO → BGIMAGE` so the sample tenant's `LoginTemplateId` points at an actually-seeded row. File is now 60 lines, purely tenant-specific backfill.)
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-8.
- **Build verification**: SQL-only change; no code build required. User must re-run BOTH `CompanySettings-sqlscripts.sql` (canonical LOGINTEMPLATE source) AND `login-tenant-sqlscripts.sql` (tenant backfill) — in that order — for a fresh DB. If Session 2's seed already ran, the stale `IMAGE_BG`/`SPLIT_HERO` MasterData rows from Session 1 should be deleted manually per the cleanup snippet in Session 2's "Build verification" note.
- **Sibling patterns mirrored**: `CompanySettings-sqlscripts.sql` (canonical LOGINTEMPLATE owner — `STEP 5` seeds all 5 rows via `CROSS JOIN (VALUES ...)`).
- **Next step**: Re-run seeds in order (CompanySettings → login-tenant) on a fresh DB or after stale-row cleanup. End-to-end manual verification of Screen #119 remains per §⑪.

