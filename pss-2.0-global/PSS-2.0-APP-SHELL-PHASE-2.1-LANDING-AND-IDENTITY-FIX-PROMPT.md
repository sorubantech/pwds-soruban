# PSS 2.0 — App Shell Phase 2.1: Post-Login Landing, Platform Gate, and User Identity

**Status:** READY TO BUILD
**Depends on:** Phase 1 (`4d3b22c2`, `c0feca4e`), Phase 2 (`e3a1fb1e`, `7f34c63e`)
**Scope:** Frontend only.

---

## ① Why this phase exists

Phase 1 retired `masterdashboard` and repointed the route at the platform control plane.
Despite its name and its home in the `(master)` route group, that page was **not** a platform
page — it was the module launcher, and it was the post-login destination for **every** user in
the system, tenant and platform alike. That is why the backend defaults to it
(`AuthExtensions.cs:110`, `DefaultLandingUrl = user.DefaultLandingUrl ?? "masterdashboard"`)
whenever a role carries no landing URL.

Consequence today: a tenant user — e.g. a BUSINESSADMIN — logs in, the token carries the
string `masterdashboard`, `resolvePostLoginLanding` returns it verbatim, and
`masterdashboard/page.tsx` redirects to `/{lang}/platform/dashboards`. **Tenant users land in
the platform control plane.** Nothing gates the `(master)` route group, so the shell renders.

Module resolution, role capabilities and menu rendering are all **unaffected and working**.
The regression is confined to the landing step. Do not "fix" anything in the menu pipeline.

A second, pre-existing defect surfaced alongside it: the profile popover shows a hardcoded
`admin@gmail.com` / `Admin` for every user.

---

## ② Constraints (hard)

- **Frontend only.** No backend change, no migration, no seed, no SQL, no `auth.Modules` /
  menu / capability data change.
- **No URL changes.** No `Role.DefaultLandingUrl` reseeding. The platform seed already applied
  (`platform-role-default-landing-seed.sql`) is correct — leave it alone.
- `(member)` / `(public)` / `(setup)` / `(auth)` untouched.
- **No change to `MenuLoader`'s commit-gated scrim logic.**
- Seeded PLATFORM menu rows stay in the DB — never deleted, never deactivated.
- Do not invent capability codes and do not write a seed for them.
- Do not delete `(master)/masterdashboard/page.tsx` — the redirect route stays; F-3 makes it safe.
- Nothing in Phase 3's deletion inventory is touched here. The one-line revert path stays intact.

---

## ③ Tasks

### F-1 — Treat `masterdashboard` as the server's null sentinel

**File:** `src/presentation/hooks/useAuth/index.ts`

`resolvePostLoginLanding` currently does:

```ts
const landing = defaultLandingUrl ? defaultLandingUrl.replace(/^\/+/, "") : null;
...
if (landing) { ...; return `/${lang}/${landing}`; }
```

`masterdashboard` is the backend's "unset" marker, not a user intent. Normalise it to `null`
**before** the `if (landing)` branch — trim slashes, compare case-insensitively:

```ts
const SENTINEL_LANDING = "masterdashboard";
const raw = defaultLandingUrl ? defaultLandingUrl.replace(/^\/+|\/+$/g, "") : null;
const landing = raw && raw.toLowerCase() !== SENTINEL_LANDING ? raw : null;
```

Control then falls into the accessible-modules path that **already exists directly below** —
no new branch, no new query. A genuinely seeded landing (platform staff, member portal) is
still returned verbatim and wins, exactly as today.

Keep the `catch` fallback coherent: on query failure with a null landing, go to
`NO_ACCESS_ROUTE`, not to the sentinel.

**Do not** special-case SUPERADMIN here. A user with no accessible modules already falls to
`no-access`; if platform staff need the control plane they get it from their seeded
`DefaultLandingUrl`, which F-1 leaves untouched.

---

### F-2 — Land on the module's own URL, not its first menu leaf

**Files:** `src/presentation/hooks/useAuth/index.ts`,
`src/presentation/hooks/usePanelMenu/index.ts`

Two call sites make the same wrong assumption about where a module's landing lives.

**F-2a — `resolvePostLoginLanding`.** The fallback runs `PARENTCHILD_MENU_QUERY` and returns
`findFirstLeafUrl(...)` — for CRM that is a contact screen, not the dashboard. Prefer the
module's seeded `moduleUrl` and only query the menu when a module has none:

```ts
const moduleLanding = String(firstModule?.moduleUrl ?? "").replace(/^\/+/, "");
if (moduleLanding) return `/${lang}/${moduleLanding}`;
// no moduleUrl on this row — fall back to the first navigable leaf, as today
```

Seeded values (`modules.sql`) are `/crm/dashboards/overview`, `/organization/dashboards/overview`,
`/accesscontrol/dashboards/overview`, `/setting/dashboards/overview`,
`/reportaudit/dashboards/overview`. CRM is `OrderBy = 1`, so a business admin lands on
`/en/crm/dashboards/overview`. Keep `applyModuleContext(firstModule)` — the module context must
still be set before the redirect.

Skipping the menu query on the common path also removes a network round-trip from login.

**F-2b — `usePanelMenu`, the synthetic Dashboard leaf.** Line ~71 builds:

```ts
key: "__module_dashboard",
href: `/${moduleCode.toLowerCase()}/dashboard`,
```

Only `crm/dashboard/page.tsx` exists. `setting`, `accesscontrol`, `organization`, `reportaudit`
and `general` all live at `{module}/dashboards/overview` — **the panel's first link 404s on five
of six modules**, and the commit-gated scrim then hangs until its 4s backstop.

Pass the active `ShellRailItem.moduleUrl` (already carried on the type, already populated by
`useTenantRailItems`) into `usePanelMenu` and use it **verbatim**. **Omit the synthetic leaf
entirely** when the module has no `moduleUrl` — never synthesise a path from `moduleCode`.

---

### F-3 — Gate the `(master)` route group

**Files:** `src/app/[lang]/(master)/layout.tsx`,
`src/presentation/components/layout-components/header/company-switcher-item.tsx`

`RouteGuard` is commented out end to end — it is `return <>{children}</>`. Any authenticated
user reaching a `/platform/*` or `/ops/*` URL renders the control-plane shell. The rail's
capability filter hides *items*; nothing gates *entry*.

Add a real platform gate wrapping `AppShell navSource="platform"`:

- Read granted `PLATFORM_*` codes from `usePlatformCapabilities` — already `cache-first` and
  already shared with the rail, so this costs no extra request.
- **Zero granted codes ⇒ redirect out**, to `/{lang}/no-access`. Do not attempt to compute a
  tenant landing here; that is login's job, and duplicating it invites drift.
- **While loading, render nothing** — never the shell, not even briefly (INV-3: forbidden
  navigation must be absent, never flashed then removed).
- Do **not** modify `route-guard.tsx`. It is dead code owned by Phase 3; leave it for the sweep.

Then repoint `company-switcher-item.tsx:85`, which does `window.location.href = MASTER_URL` on
**every** company switch and funnels tenant users into the control plane regardless of F-1.
Send it to the switched-into company's tenant landing. Reuse the F-2a resolution rather than
hardcoding a route.

---

### F-4 — Populate real user identity at login

**Files:** `src/application/stores/auth-stores/user-store.ts`,
`src/presentation/hooks/useAuth/index.ts`, the logout path

`user-store.ts` seeds `{ userId: 0, userName: "admin@gmail.com", designation: "Admin" }` as its
**initial state**, and the only `setUserInfo` caller in the entire codebase is
`profile-photo-upload-modal.tsx:141` — after a photo upload. Nothing populates the store at
login, and the store is `persist`ed to localStorage, so the placeholder survives reload and
logout.

1. **Empty the seed.** `userId: 0`, `userName: ""`, `profilePathUrl: ""`, `designation: ""`.
   A failure must render blank, never a plausible fake identity.
2. **Set it at login.** In `useAuth.login`, after the session check and before
   `router.push(...)`, call `setUserInfo` with `loginResult.data.result.data` — it is already
   in hand and already shaped as `LoginUserInfo` (`userId`, `userName`, `email`,
   `profilePathUrl`, `designation`, `company`, `staff`, `userRoles`).
3. **Clear it on logout.** Reset to the empty seed and drop the persisted `user-store` key, so
   the next user on that browser cannot inherit the previous user's identity.
4. **Rehydration.** A hard refresh does not re-run `login`; `persist` covers the common case.
   Do not add a new query for this — if the session is authenticated and the store is empty,
   leave it empty rather than inventing a fetch.

**Out of scope, flag only:** `userId: 0` is read by `search-store`, `global-search`,
`report-datatable-fetch` and `data-table-filter-option`, so saved filters and searches have been
keyed to user 0 for everyone. F-4 changes what *new* rows get keyed to; existing rows are
already at 0. Do not migrate or delete them — report the row counts and stop.

---

### F-5 — Modules and menus must render from the signed-in user's access

**Files:** `src/presentation/hooks/usePanelMenu/index.ts`,
`src/application/utils/module-url-match.ts`, `src/presentation/provider/app-shell-provider.tsx`

The tenant rail and panel are **already** driven by the server — `useTenantRailItems` from
`USER_ROLE_MODULES` (filtered on `isActive && isAccessible`), `usePanelMenu` from
`PARENTCHILD_MENU_QUERY` per module. `PLATFORM_NAVIGATION` is hardcoded **by design** and is
the control plane's IA only; it must never render for a tenant user (F-3 enforces that).

So there is no "make it dynamic" work here. What there is: four confirmed defects that make the
panel render **stale or wrong** menus for the right user. Fix all four.

1. **Render-phase ref mutation.** `usePanelMenu` writes `lastGoodRef.current[cacheKey]` during
   render (~lines 149-153). Move it into a `useEffect`. Mutating a ref while rendering is unsafe
   under concurrent rendering and can persist a menu that was never committed.
2. **Wrong "menu has arrived" heuristic.** The same block gates on `sections.length > 1`,
   reasoning that a single section is the synthetic Dashboard alone. That is false for any module
   whose menus are all flat top-level links — those legitimately produce **one** ungrouped
   section, so a real menu is treated as "not arrived" and the user sees the previous module's
   cached menu. Count **leaves**, not sections. (F-2b removes the synthetic leaf, which changes
   this arithmetic — do F-2b first.)
3. **Order-dependent module match.** `matchModuleByUrl` tier 2 resolves by root segment with an
   **unsorted** `.find()`, so which module wins depends on array order from the server. Sort
   deterministically (prefer the shortest / most specific root). A wrong winner here lights the
   wrong rail icon and loads the wrong module's menu.
4. **Preview / route divergence.** Hover-previewing module B and then navigating inside module A
   leaves the rail lit on B. `activeRailKey` must reconcile back to the route's module on
   navigation commit.

Also confirm — do not change, just verify and report:

- A module with `isAccessible === false` is **absent** from the rail, not disabled (INV-3).
- Two users with different roles, same browser, produce different rails and different panels
  (i.e. nothing is cached across identities — `USER_ROLE_MODULES` is `cache-first`, so check the
  Apollo cache is reset on logout).
- Module-less routes (`billing/*`, `no-access`) keep the current module lit rather than clearing
  the rail. This is Phase 2 deviation #2 and is intended — confirm it still holds.

---

## ④ Acceptance (must be exercised on a running dev server)

1. Tenant BUSINESSADMIN (`karthick004soruban@gmail.com`) logs in → lands on
   `/en/crm/dashboards/overview`, tenant shell, tenant rail. **Never** `/platform/*`.
2. That user's rail shows their accessible modules; clicking each swaps the context panel only,
   no `router.push`, `moduleCode` unchanged by the rail click (INV-8).
3. The panel's first link on **every** module resolves to a real page — no 404, no hung scrim.
   Check all six, not just CRM.
4. Platform staff (seeded `DefaultLandingUrl = 'platform/dashboards'`) still land on the control
   plane, unchanged.
5. Typing `/en/platform/dashboards` directly as a tenant user → redirected to `no-access`; the
   platform shell never paints, not even for a frame.
6. `/en/masterdashboard` as a tenant user → does not strand them in the control plane.
7. Company switch as a tenant user → tenant landing, not the control plane.
8. Profile popover shows the real signed-in email and designation. Log out, log in as a
   different user → popover shows the second user, not the first.
9. Two different tenant users with different role/module access, logged in one after the other in
   the same browser: each sees **their own** rail and their own menus. The second user must not
   inherit the first user's modules from the Apollo cache or from localStorage.
10. A module the user cannot access is absent from the rail entirely — not greyed, not disabled.
11. Switching modules on the rail loads that module's menus, and returning to the first module
    still shows the first module's menus (no cross-module bleed from the `lastGoodRef` cache).
12. Re-run the Phase 2 §9 acceptance list — it has still never been exercised on a dev server.

---

## ⑤ Deliverable

Commit per task (`F-1`…`F-4`) so any one can be reverted alone. Run
`rm -rf .next/types && npx tsc --noEmit --incremental false` before handing back; report the
exit code verbatim. Do not run `dotnet build`. Do not create EF migrations.

Append a §⑥ Build Log to this file: what landed, what deviated and why, what remains unverified.
State explicitly whether each acceptance point was exercised on a dev server or only statically.

---

## â‘¥ Build Log

**Status:** BUILT â€” frontend only, typecheck clean, **not exercised on a dev server**.
**Typecheck:** `rm -rf .next/types && npx tsc --noEmit --incremental false` â†’ exit code `0`.
No backend build, no EF migration, no seed, no SQL, no URL change.

### Commits (one per task, each independently revertable)

| Commit | Task | Files |
|---|---|---|
| `fefb60b2` | F-1 + F-2a | `application/utils/post-login-landing.ts` (new), `presentation/hooks/useAuth/index.ts` |
| `5ede0f74` | F-2b | `presentation/hooks/usePanelMenu/index.ts`, `presentation/provider/app-shell-provider.tsx` |
| `1ab91a5d` | F-3 | `presentation/components/auth/platform-gate.tsx` (new), `app/[lang]/(master)/layout.tsx`, `presentation/components/custom-components/company-switcher/company-switcher-item.tsx` |
| `dc4cc06a` | F-4 | `application/stores/auth-stores/user-store.ts`, `user-istore.ts`, `presentation/hooks/useAuth/useLogout.ts` |

`BaseUrlConfig.ts` is modified in the working tree and was deliberately **not** committed â€” it is
user-managed.

### What landed

**F-1** â€” `defaultLandingUrl` is trimmed of leading/trailing slashes and compared
case-insensitively against `masterdashboard`; on a match it normalises to `null` *before* the
`if (landing)` branch, so control falls into the accessible-modules path that already existed. No
new branch, no new query, no SUPERADMIN special case. A genuinely seeded landing (e.g. platform
staff on `platform/dashboards`) still returns verbatim. The `catch` is coherent: a query failure
with a null landing returns `NO_ACCESS_ROUTE`, never the sentinel.

**F-2a** â€” the first accessible module's seeded `moduleUrl` is now preferred over
`findFirstLeafUrl(...)`. `PARENTCHILD_MENU_QUERY` only runs when a module carries no `moduleUrl`,
so the common login path lost a round-trip. `applyModuleContext(firstModule)` still runs in both
branches.

**F-2b** â€” the synthetic Dashboard leaf's href is `ShellRailItem.moduleUrl` used verbatim; a module
with no `moduleUrl` gets **no** leaf. `TenantPanel` passes `active?.moduleUrl` through.

**F-3** â€” new `PlatformGate` (`"use client"`) wraps `<AppShell navSource="platform">` inside
`RoleCapabilityProvider` in `(master)/layout.tsx`. It reads granted codes from
`usePlatformCapabilities({})` (no `menuCode` â‡’ all PLATFORM menus; `cache-first`, shared with the
rail, so no extra request). `loading` renders `null`; `capabilityCodes.size === 0` renders `null`
and `router.replace('/{lang}/no-access')` from an effect â€” the shell is never painted, not even for
a frame. `route-guard.tsx` untouched; `masterdashboard/page.tsx` untouched (it now sits behind the
gate, which is what makes it safe). The company switcher's `window.location.href = MASTER_URL` is
replaced by `resolveLandingRoute(...)` fed the new token's `defaultLandingUrl` â€” the same resolver
login uses. It stays a full document load, not `router.push`: the session was replaced and the
Apollo cache cleared, so every provider above must rebuild.

**F-4** â€” seed emptied to `{ userId: 0, userName: "", profilePathUrl: "", designation: "" }` and
exported as `EMPTY_USER_INFO`; `useAuth.login` calls `setUserInfo(loginResult.data.result.data)`
after the session check and before `router.push`; `useLogout` calls `clearUserInfo()` and removes
the persisted `user-store` key by name. No rehydration query was added â€” `persist` covers the
common case and an authenticated session with an empty store stays empty, by instruction.

### Deviations

1. **The prompt's path for the company switcher is wrong.** Â§â‘¢ F-3 names
   `presentation/components/layout-components/header/company-switcher-item.tsx`; no such file
   exists. The real one is
   `presentation/components/custom-components/company-switcher/company-switcher-item.tsx`
   (`MASTER_URL` at line 85, as described). Edited there.
2. **F-1/F-2a were extracted to a new module rather than edited in place.** F-3 requires the
   company switcher to reuse "the F-2a resolution", and a second copy inside a React hook could not
   be called from the switcher without drift. `resolveLandingRoute` is pure and React-free; its
   `apolloClient` parameter is structurally typed so the module stays Apollo-version-agnostic.
   `useAuth.resolvePostLoginLanding` is now a thin wrapper and remains the only writer of module
   context at login. `NO_ACCESS_ROUTE`, `byOrder` and `findFirstLeafUrl` moved with it.
3. **`usePanelMenu`'s "last good sections" guard was rewritten.** It read
   `if (!error && sections.length > 1)`, justified by "a section list of length 1 is the synthetic
   Dashboard alone". F-2b makes that leaf conditional, so a module with no `moduleUrl` and exactly
   one real ungrouped menu would have been indistinguishable from "nothing has arrived" and its
   menu would never have been cached. The test now asks the source: `(menus?.length ?? 0) > 0`.
   Behaviour is otherwise unchanged â€” this is not a scrim change.
4. **F-1 and F-4 step 2 share `useAuth/index.ts`**, so the `setUserInfo` call at login rides in
   commit `fefb60b2` rather than `dc4cc06a`. Reverting F-1 alone therefore also drops the
   login-time identity write; every other task reverts cleanly in isolation.

### Out of scope â€” flagged, not touched (F-4)

`userId: 0` was written into user-scoped keys for **every** user for as long as the placeholder
seed existed. The real blast radius is wider than Â§â‘¢ listed:

- **Server-side rows** â€” `useDynamicFilter.ts:411`, `:469` and
  `data-tables/advanced/data-table-general-options/data-table-filter-option.tsx:401`, `:427`,
  `:469` all send `userId: userInfo.userId` when saving/updating/deleting a grid filter. Those
  rows are persisted with `UserId = 0`.
- **Browser-local keys** â€” `search-stores/search-store.ts:9`, `global-search/global-search.tsx:58`,
  `global-search/inline-search-bar.tsx:80`, `global-search/hooks/use-search.ts:79` key recent
  searches by `String(userId)`, so a shared browser collapsed every user's history into one bucket.
- **Behavioural side effect, now corrected by F-4** â€”
  `shared-cell-renderers/user-actions-cell.tsx:45` computes `isSelf` from `userInfo.userId`; with
  the placeholder it was effectively never true.

**Row counts were not obtained.** They require a database query, and this phase is frontend-only
with no SQL permitted â€” and no database access was available from this session. Nothing was
migrated or deleted, per instruction. Someone with DB access should count the affected saved-filter
rows before deciding whether to reassign or drop them.

### Acceptance â€” how each point was verified

**No dev server was started. Every point below is static verification only** (code reading plus a
clean `tsc --noEmit`). None of Â§â‘£ 1â€“12 has been exercised at runtime.

| # | Point | Verified |
|---|---|---|
| 1 | Tenant BUSINESSADMIN lands on `/en/crm/dashboards/overview` | Static â€” depends on CRM's seeded `moduleUrl`, which was not read from the DB |
| 2 | Rail click swaps the panel only, `moduleCode` unchanged (INV-8) | Static â€” untouched by this phase |
| 3 | Panel's first link resolves on all six modules | Static â€” correct **iff** every module row carries a valid `moduleUrl`; a null `moduleUrl` now yields no Dashboard leaf rather than a 404, which is the intended degradation |
| 4 | Platform staff still reach the control plane | Static â€” requires their `PLATFORM_*` grants to be non-empty, or F-3 will now redirect them to `no-access`. **Highest-risk item; exercise this first.** |
| 5 | Tenant user typing `/en/platform/dashboards` â†’ `no-access`, shell never paints | Static â€” the gate returns `null` while loading and while denied |
| 6 | `/en/masterdashboard` does not strand a tenant user | Static â€” the route is inside `(master)`, so the gate fires before its redirect |
| 7 | Company switch â†’ tenant landing | Static |
| 8 | Profile popover shows the real identity; a second user does not inherit the first | Static |
| 9â€“12 | Phase 2 Â§9 list re-run | **Not done** â€” still never exercised on a dev server |

