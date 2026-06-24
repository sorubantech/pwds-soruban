---
feature: RoleDefaultLandingPage
registry_id: (feature — extends #70 Role Management + auth login flow)
module: Access Control (Role admin) + Auth (login redirect)
status: FE_BUILT_BE_PENDING   # FE shipped 2026-06-15 (frontend-developer/Sonnet); BE §④ being built by USER manually
scope: ENHANCEMENT   # not a greenfield screen — edits existing Role admin + auth files
screen_type: ENHANCEMENT (no mockup; cross-cutting auth/RBAC change)
planned_date: 2026-06-15
prereq_for: Member Portal #61 re-architecture (ISSUE-19) — a MEMBERSHIP role's default landing = member portal dashboard
---

## ① Identity & Context

**What**: After login, redirect each user to a **default landing page resolved from their role(s)**, configured in DB per tenant — replacing today's hardcoded redirect to `/en/masterdashboard` for everyone.

**Why**: Different role populations need different home pages. Majority of staff → `masterdashboard`. A `MEMBERSHIP` role → member portal dashboard. A future `VOLUNTEER` role → hours-tracking page. Today every authenticated user is pushed to the same place; the landing page must be a per-tenant, per-role config row, not code.

**Today's behavior (confirmed)**:
- FE: [useAuth/index.ts:94](../../../PSS_2.0_Frontend/src/presentation/hooks/useAuth/index.ts) does `router.push(MASTER_URL)` (`MASTER_URL = "/en/masterdashboard"`) for ALL users after `signIn`.
- BE: `Login` → `GetUserCredential` builds `UserDetailsToTokenGenerateDto` (UserId, UserName, CurrentCompanyId, CurrentCompanyRoles, AccessibleCompanyIds/Roles, IsSuperAdmin). It does **NOT** load `PrimaryRoleId` or any landing field. `AuthExtensions.CreateToken` returns `TokenResponseDto { AccessToken, RefreshToken, ExpiresIn }` — its `RoleKey`/`BranchCode` slots are unused.
- `Role` has NO landing field. `User.PrimaryRoleId` (int?, FK Role) and `User.DefaultDashboardCode` (string?, a **dashboard-variant** code like `"STANDARD"` — NOT a route) both exist.

**Scope note**: #70 Role Management shows `NEW` in REGISTRY.md but the Role admin tab UI is already built (`rolemanagement/` files below). This feature EDITS those existing files — it does not regenerate the screen.

---

## ② Data Model Change

**Add to `auth.Roles`** (entity [Role.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/AuthModels/Role.cs)):
| Field | C# Type | MaxLen | Notes |
|-------|---------|--------|-------|
| `DefaultLandingUrl` | `string?` | 200 | Nullable. The **relative route** the user lands on after login, e.g. `masterdashboard`, `crm/membership/memberportal`, `crm/volunteer/volunteerhourlog`. Stored WITHOUT the `/${lang}/` prefix and without a leading slash. |

> **Store a URL string, NOT a Menu FK** (decision 2026-06-15): the landing targets (master dashboard, member portal, volunteer hours) are **standalone routes that have no sidebar `auth.Menus` row**, so an FK to Menus can't represent them. Plain relative-URL string instead. No menu join needed at login.

> **Role-only by design**: landing is a property of the **Role**, not the User. No per-user override column. Multi-role resolved from `User.PrimaryRoleId` + `Role.OrderBy` (§③). `User.DefaultDashboardCode` is left untouched (dashboard-variant code, not a route — do NOT repurpose it).

**Migration**: entity + EF config changes only — **user runs `dotnet ef migrations add` manually** (house rule [[feedback_user_creates_migrations]]). Name suggestion: `Add_DefaultLandingMenuId_To_Role_And_User`.

---

## ③ Landing Resolution Logic (server-side, at login)

Resolve ONE `DefaultLandingUrl` (string, a relative route like `crm/membership/memberportal` or `masterdashboard`) in the **current company context**, in this precedence:

1. **Primary role** — `User.PrimaryRoleId` (a column on `auth.Users`, NOT a flag on `UserRoles`) → that role's `DefaultLandingUrl` (if set). *(Primary role wins — user decision 2026-06-15.)*
2. **Highest-priority role** — if no primary-role landing, among the user's active `UserRoles` for the current company, the role with the **lowest `Role.OrderBy`** that has a non-null `DefaultLandingUrl`.
3. **System default** — `masterdashboard`.

Notes:
- SuperAdmin → always `masterdashboard` (step 4); skip role resolution.
- Multi-company: resolve using `CurrentCompanyId`'s roles only (roles are tenant-scoped via `Role.CompanyId`).
- Return the **relative** url (no `/en/` prefix, no leading slash) — FE prepends `/${lang}/`. The FE's `MASTER_URL` is `/en/masterdashboard`; emit `masterdashboard` and let FE build the localized path.

---

## ④ Backend File Manifest

| # | File | Change |
|---|------|--------|
| 1 | `Base.Domain/Models/AuthModels/Role.cs` | Add `string? DefaultLandingUrl`. |
| 2 | `Base.Infrastructure/.../AuthConfigurations/RoleConfiguration.cs` | `HasMaxLength(200)` on `DefaultLandingUrl` (no FK). |
| 3 | `Base.Application/Schemas/AuthSchemas/RoleSchemas.cs` | Add `string? DefaultLandingUrl` to `RoleRequestDto` (inherited by Response). |
| 4 | `Base.Application/.../Roles/Commands/CreateRole.cs` + `UpdateRole.cs` | Persist `DefaultLandingUrl` (validate max 200). Respect existing system-role edit guards (SUPERADMIN: Description only; system roles: Description+ColorHex — **extend the editable set to include `DefaultLandingUrl` for non-SUPERADMIN system roles** so a tenant can set a landing page on a seeded role). |
| 5 | `Base.Application/Schemas/AuthSchemas/AuthSchemas.cs` | Add `string? DefaultLandingUrl` to `TokenResponseDto`. |
| 6 | `Base.Application/.../Users/Queries/GetUserCredential.cs` | Load `User.PrimaryRoleId` and the user's roles (current company) WITH each role's `DefaultLandingUrl` + `Role.OrderBy`. Resolve the single `DefaultLandingUrl` per §③ here and add it to `UserDetailsToTokenGenerateDto` as `DefaultLandingUrl (string?)` (also add `PrimaryRoleId (int?)` if useful). No menu join. |
| 7 | `Base.Application/Extensions/AuthExtensions.cs` | In `CreateToken`, set `TokenResponseDto.DefaultLandingUrl = user.DefaultLandingUrl ?? "masterdashboard"`. (Optionally also add a `"DefaultLandingUrl"` JWT claim — not required if returned in the response body.) |

**Seed**: (a) seed the MasterData `LANDINGPAGE` type rows (Master Dashboard → `masterdashboard`, Member Portal → `crm/membership/memberportal`); (b) set `DefaultLandingUrl = 'masterdashboard'` on the canonical staff role(s) so existing tenants behave unchanged. Use the `sql-scripts-dyanmic/` folder (preserve typo, [[project_postgresql_db]] conventions: `now()`, double-quoted identifiers, `WHERE NOT EXISTS`).

---

## ⑤ Frontend File Manifest

| # | File | Change |
|---|------|--------|
| 1 | `gql-queries/auth-queries/RoleQuery.ts` | Add `defaultLandingUrl` to `ROLE_BY_ID_QUERY` and `ROLES_QUERY`. |
| 2 | `gql-mutations/auth-mutations/RoleMutation.ts` | Add `$defaultLandingUrl: String` to `CREATE_ROLE_MUTATION` + `UPDATE_ROLE_MUTATION` variables + input + response. |
| 3 | `accesscontrol/usersroles/rolemanagement/tabs/roles/role-modal.tsx` | Add `defaultLandingUrl: string \| null` to `FormValues`; load it in `ROLE_BY_ID` effect; send it in `buildVariables()`. |
| 4 | `accesscontrol/usersroles/rolemanagement/tabs/roles/sections/role-info-section.tsx` | **Add a "Default Landing Page" select** bound to `defaultLandingUrl` — options = curated landing-page list (see source note below). Reuse canonical `FormSelect` ([[feedback_reuse_canonical_form_fields]]). |
| 5 | `presentation/hooks/useAuth/index.ts` | Replace `router.push(MASTER_URL)` with `router.push(\`/${lang}/${resp.defaultLandingUrl || "masterdashboard"}\`)`, reading `defaultLandingUrl` from the login mutation result (`loginResult.data.result.data`). Keep `MASTER_URL` fallback. |
| 6 | `domain/entities/auth-service/*` (Token/Login DTO) + login GQL | Add `defaultLandingUrl` to the login response selection + TS type so it's available to step 5. |

**Landing-page options source** (DECIDED 2026-06-15 — MasterData dropdown): the landing targets are a small fixed set of static routes (no menus). Use a **MasterData lookup type `LANDINGPAGE`** (`DataText` = label e.g. "Master Dashboard", `DataValue` = **relative url** e.g. `masterdashboard`), seeded with Master Dashboard + Member Portal (+ Volunteer Hours later). The "Default Landing Page" `FormSelect` reads options via the standard MasterData lookup pattern ([[feedback_masterdata_lookup_mirror_sibling]]) — `Role.DefaultLandingUrl` stores the selected `DataValue` (the relative url). Adding a new landing option later = one seed row, no code change. Grep an existing MasterData handler for the exact lookup query/codes — don't guess DataValue strings.

---

## ⑥ BE→FE Contract

- **Login response** gains: `defaultLandingUrl: String` (relative route, e.g. `"masterdashboard"`, `"crm/membership/memberportal"`).
- **Role mutations/query** gain: `defaultLandingUrl: String` (request + response). Nullable → `String` not `String!`; FE variable types must match BE nullability ([[feedback_fe_query_nullability_must_match_be]]).
- HC naming: BE param/method conventions per [[feedback_hc_naming_conventions]].

---

## ⑦ Acceptance Criteria

1. Role admin → edit a role → "Default Landing Page" select lists the curated landing routes; save persists `DefaultLandingUrl`; reopening shows the saved value.
2. A tenant can set the `MEMBERSHIP` role's landing = member portal dashboard; staff role's landing = `masterdashboard`.
3. Login as a single-role user → lands on that role's configured page (not hardcoded masterdashboard).
4. Login as a staff+membership user (`User.PrimaryRoleId` = staff) → lands on the **staff** page (primary role wins).
5. Primary role has no landing configured → falls back to lowest-`OrderBy` role's landing, else `masterdashboard`.
6. SuperAdmin → `masterdashboard`.
7. Existing tenants (seed sets staff role landing = masterdashboard) behave exactly as before — no regression.
8. `dotnet build` passes; FE typecheck passes; login redirect verified for ≥2 role configs.

---

## ⑧ Special Notes & Warnings

- **Migration is user-run** ([[feedback_user_creates_migrations]]) — make only compiling entity/config changes.
- **Store a URL string, not a Menu FK.** Landing targets (master dashboard, member portal, volunteer hours) have NO `auth.Menus` row — they're standalone static routes. `Role.DefaultLandingUrl` is a relative-route string.
- **Role-only — no per-user override.** Multi-role resolved via `User.PrimaryRoleId` (column on Users; there is NO `IsPrimaryRole` flag on `UserRoles`) then `Role.OrderBy`. `User.DefaultDashboardCode` is left untouched.
- **System-role edit guard**: `UpdateRole` currently restricts system roles to Description (+ColorHex). The landing page MUST be settable on seeded roles (staff, membership) — extend the non-SUPERADMIN system-role editable set to include `DefaultLandingUrl`.
- **Tenant scope**: resolve landing using `CurrentCompanyId` roles only; `Role.CompanyId` is the tenant key.
- **Relative vs localized URL**: BE returns relative (`masterdashboard`); FE prepends `/${lang}/`. Don't double-prefix.
- **Reuse canonical form field** for the select ([[feedback_reuse_canonical_form_fields]]); strip `__typename` on round-trip ([[feedback_apollo_typename_strip_on_round_trip]]).
- **Prereq for #61**: once this lands, re-plan Member Portal #61 so the `MEMBERSHIP` role's landing = member portal dashboard (ISSUE-19, memory `project_member_portal_rearchitecture_role_based`). Future `VOLUNTEER` role reuses the identical mechanism.

---

## ⑬ Build Log

### Session 1 — 2026-06-15 — FE — COMPLETED (BE handed to user)
- **Scope**: Frontend half of the role-based default landing page (§⑤). BE half (§④) is being implemented by the USER manually.
- **Files touched (FE, `- Copy` worktree, tsc clean)**:
  - `infrastructure/gql-queries/auth-queries/RoleQuery.ts` — `defaultLandingUrl` added to ROLES_QUERY + ROLE_BY_ID_QUERY
  - `infrastructure/gql-mutations/auth-mutations/RoleMutation.ts` — `$defaultLandingUrl: String` (nullable) on CREATE + UPDATE
  - `infrastructure/gql-mutations/auth-mutations/LoginMutation.ts` — `defaultLandingUrl` in login response selection
  - `domain/entities/auth-service/UserDto.ts` — `defaultLandingUrl?: string | null` on LoginResponseDto
  - `domain/entities/auth-service/RoleDto.ts` — `defaultLandingUrl?: string | null` on RoleRequestDto
  - `accesscontrol/usersroles/rolemanagement/tabs/roles/role-modal.tsx` — FormValues + load + buildVariables + section prop
  - `accesscontrol/usersroles/rolemanagement/tabs/roles/sections/role-info-section.tsx` — "Default Landing Page" FormSelect; inline `useMasterDataByTypeCode("LANDINGPAGE")` mirrored from `schedule-modal.tsx` (`masterDatasByTypeCode(typeCode:)`, label=dataName, value=dataValue)
  - `presentation/hooks/useAuth/index.ts` — redirect now `router.push(`/en/${defaultLandingUrl || "masterdashboard"}`)` reading login result; MASTER_URL kept as fallback
- **Deviations from spec**: `useAuth` hardcodes `/en/` (no `useLocale` in that hook; consistent with existing `MASTER_URL = "/en/masterdashboard"`). MASTER_URL constant left in place (other importers).
- **BE pending (USER building, §④)**: Role.cs `DefaultLandingUrl` + RoleConfiguration maxlen + RoleSchemas + Create/UpdateRole persist (extend non-SUPERADMIN system-role editable set) + AuthSchemas TokenResponseDto + GetUserCredential resolution (§③) + AuthExtensions CreateToken default. Plus seed: MasterData `LANDINGPAGE` rows + staff-role `DefaultLandingUrl='masterdashboard'`. NOT functional end-to-end until BE returns `defaultLandingUrl` on login + persists it on Role.
- **Next step**: USER finishes BE §④ + seed; then verify login redirect for ≥2 role configs; then `/plan-screens #61` re-architecture.
