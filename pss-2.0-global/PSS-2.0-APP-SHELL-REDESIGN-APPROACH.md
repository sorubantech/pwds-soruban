# PSS 2.0 — App Shell Redesign (ClickUp-style), Module Navigation Removal

**Type:** Approach / planning document. **No code in this document.**
**Date:** 2026-08-07
**Status:** PLANNED — nothing built.

---

## ⓪ What the user asked for

Two asks, in order:

1. **Platform surface gets its own UI**, modelled on `app.clickup.com`. The platform shell is
   **static** — hardcoded in TypeScript, identical for every tenant staff member. Only its *data* is
   dynamic. The tenant shell stays **fully dynamic** — DB-driven menus, as today. Platform routing
   and tenant routing stay in **separate route groups**.

2. **Remove the master dashboard and module navigation on BOTH sides** — platform and tenant —
   because "ux wise too much time consuming". *"Then keep in mind rolecapabilities everything
   working based on module — that is the main part keep in mind."*

Ask 2 changes the shape of ask 1, so this document plans them together.

---

## ① The one constraint that decides everything

`moduleCode` is the hinge of the whole application. Verified in source:

| Consumer | File | What it does with `moduleCode` |
|---|---|---|
| `useMenu()` | [useMenu.ts](PSS_2.0_Frontend/src/presentation/hooks/useInitialRendering/useMenu.ts) | `PARENTCHILD_MENU_QUERY` variables `{ moduleCode }`, `skip: !moduleCode`. No module → **no sidebar at all**. |
| `RoleCapabilityProvider` | [access-provider.tsx](PSS_2.0_Frontend/src/presentation/provider/access-provider.tsx) | reads `moduleCode` from the global store, fetches `ROLECAPABILITIES_BY_USER_QUERY` per module, caches per module. |
| `usePlatformCapabilities` | [usePlatformCapabilities/index.ts](PSS_2.0_Frontend/src/presentation/hooks/usePlatformCapabilities/index.ts) | hardcodes `PLATFORM_MODULE_CODE = "PLATFORM"` and queries the same resolver. |

So: **the module is the RBAC partition key, on the client and on the backend.** It is not merely a
navigation concept.

**Therefore the plan removes module *navigation*, not the module *concept*.**
Nothing in the backend changes. `auth.Modules`, `RoleModules`, `RoleCapabilities`, the menu tree, the
`moduleCode` GraphQL variables — all untouched. What is deleted is the **full-page detour** the user
is forced through to set that variable.

Today `moduleCode` gets set from exactly five places (verified by grep on `setModuleCode`):

| # | Call site | Fate under this plan |
|---|---|---|
| 1 | `useAuth` → `resolvePostLoginLanding` — resolves the owning module from the landing URL by longest `moduleUrl` prefix | **KEEP and promote.** This is the mechanism the whole redesign is built on. |
| 2 | `module-navigator-item.tsx` — the module tile click | **DELETE** (with the module navigator). |
| 3 | `masterdashboard` → `landing-page/content.tsx` — the modules grid click | **DELETE** (with the master dashboard). |
| 4 | sidebar `classic` / `popover` / `mobile-sidebar` — `setModuleCode(null)` "back to launcher" | **DELETE.** There is no launcher to go back to. |
| 5 | `global-search/inline-search-bar.tsx` — jumps straight to a menu and sets its module | **KEEP.** Already proves cross-module jumps work without a launcher. |

Call site 1 is the proof this is safe: **the app already knows how to derive the active module from a
URL** — `landing === moduleUrl || landing.startsWith(moduleUrl + "/")`, longest match wins. Today that
runs once, at login. The redesign runs it on *every* navigation.

---

## ② The target shell (mapped from the ClickUp screenshot)

Both surfaces get the same **three-zone** anatomy. Only the data source differs.

```
┌──────────────────────────────────────────────────────────────────────────┐
│ TOP BAR   [workspace/tenant switcher]   [ search ]   [icons] [avatar]    │
├────┬─────────────────────────┬───────────────────────────────────────────┤
│ R  │  CONTEXT PANEL          │                                           │
│ A  │  (menus of the module    │            PAGE CONTENT                  │
│ I  │   selected in the rail)  │                                           │
│ L  │                          │                                           │
│    │  ── section ──           │                                           │
│ [] │   • menu                 │                                           │
│ [] │   • menu                 │                                           │
│ [] │     ▸ child              │                                           │
│    │                          │                                           │
│ ── │  ── pinned ──            │                                           │
│ [] │   Customize sidebar      │                                           │
└────┴─────────────────────────┴───────────────────────────────────────────┘
```

- **Zone 1 — icon rail (~72px, always visible).** One item per **module**. This *is* the module
  navigator, collapsed from a full page into a permanent 72px strip. Labelled icons, like ClickUp.
  Pinned to the bottom: help, what's-new, user.
- **Zone 2 — context panel (~248–272px, collapsible).** The menus of the module currently selected in
  the rail. Tenant: from `useMenu()`. Platform: from a hardcoded constant.
- **Zone 3 — content.** Unchanged.

**Why this specific shape answers "too much time consuming":** today, switching module costs
`click module tile → full-screen ModuleLoader scrim → route change → menu render → click menu`. Under
the rail it costs `click rail icon → panel swaps in place → click menu`. One page navigation is
removed from every module switch, and the full-screen scrim disappears entirely because nothing
navigates at rail-click time.

### 2.1 Rail click ≠ navigation

This is the central behavioural rule and the reason the plan works:

> **Clicking a rail icon sets `moduleCode` and swaps the context panel. It does NOT call
> `router.push()`.** The content area keeps showing the current page until the user picks a menu.

Consequences, all good:
- No full-screen scrim on module switch (the `ModuleLoader` is deleted — see §④).
- No "module landing page" is needed, so no module needs one.
- Prefetching the next module's menus + capabilities on rail **hover** makes the panel swap feel
  instant.
- The user can peek at another module's menus and come back without losing their place.

*Optional refinement (decide in §⑨ Q4):* remember the last menu visited per module and make the rail
click a one-click jump for power users. Recommendation: **no** for v1 — peek-without-losing-place is
the more valuable behaviour, and "click rail, click menu" is already one click cheaper than today.

---

## ③ Removing the master dashboard

`(master)/masterdashboard` renders `MasterLandingPageConfig` — 18 files under
[pages/master/landing-page/](PSS_2.0_Frontend/src/presentation/pages/master/landing-page/) including
`modules-grid`, `command-palette`, `kpi-snapshot-row`, `mission-control-bg`, `floating-ai-chat`,
`right-rail`, `quick-actions-bar`.

**It is not one thing. Split it before deleting it:**

| Piece | Fate |
|---|---|
| `modules-grid.tsx` + `content.tsx` module-click logic | **DELETE.** Superseded by the rail. |
| `command-palette.tsx` | **KEEP** — promote into the top-bar search on both shells. A palette is the *fast* path the user is asking for; it is the opposite of a landing page. |
| `kpi-snapshot-row`, `mission-progress-strip`, `upcoming-strip`, `right-rail`, `recent-activity`, `tenant-clock` | **RELOCATE** to a real dashboard screen. These are content, not navigation. |
| `mission-control-bg`, `loader`, `footer`, `personalization` | **DELETE** (chrome for a page that will not exist). |
| `ai-assistant-chat`, `floating-ai-chat` | **KEEP** as a shell-level element (ClickUp's "AI Chats"). Not tied to the landing page. |

**Where does `/{lang}/masterdashboard` go?** It must not 404 — it is `MASTER_URL`, the hardcoded
fallback in `useAuth` when `Role.DefaultLandingUrl` is null, and it is likely bookmarked. Plan:
**keep the route as a permanent redirect** to the resolved landing (see §⑤), and remove `MASTER_URL`
as a *fallback* so nothing new points at it.

---

## ④ What dies with module navigation

| Thing | File(s) | Why it goes |
|---|---|---|
| Module navigator | `components/custom-components/module-navigator/` | Replaced by the rail. |
| `ModuleLoader` full-screen scrim | `layout-components/module-loader/` | Nothing navigates on module switch, so nothing needs covering. |
| `isModuleLoading` / `loadingModuleName` / `moduleNavOriginRef` commit-gating | `dashboard-layout-provider.tsx` | Dead with the scrim. **Note:** the file's own comment records the bug this caused — *"a FIXED coded dashboard such as the PLATFORM control plane had nothing to lower it, so the full-screen ModuleLoader stayed up forever."* Removing it closes that class of bug permanently. |
| `setModuleCode(null)` "back to launcher" in three sidebars | `sidebar/classic`, `sidebar/popover`, `sidebar/mobile-sidebar` | `moduleCode` must never be null again once resolved. See §⑥ INV-1. |
| `sidebarType === "module"` theme variant + the four layout branches | `dashboard-layout-provider.tsx` | The new shell has one layout. |

**Kept:** `MenuLoader` (the content-area scrim) and its commit-gated backstop. Menu clicks *do*
navigate, so that scrim and its "don't drop the scrim on a blind timer" logic are still correct and
still needed. Do not touch that logic while doing this work.

---

## ⑤ Route → module resolution (the piece that must be built first)

Without a launcher, every entry into the app must be able to answer *"which module am I in?"* from
the URL alone: hard refresh, deep link, bookmark, browser back, notification click, email link.

**Build `useActiveModule()`** (`src/presentation/hooks/useActiveModule/index.ts`):

1. Read `USER_ROLE_MODULES` (already used by `useAuth`; returns `moduleCode`, `moduleUrl`,
   `moduleId`, `moduleName`, `isActive`, `isAccessible`).
2. Filter to `isActive && isAccessible`.
3. Match the current pathname (locale prefix stripped) against `moduleUrl` — **longest prefix wins**,
   exactly the rule already in `resolvePostLoginLanding:66-71`. Lift that comparator into the hook and
   have `resolvePostLoginLanding` call it, so there is **one** implementation.
4. On a match, set `moduleId/Code/Name/Url` in the global store *only if changed* (a no-op write would
   re-fire `useMenu` and the capability query).
5. On no match (a route owned by no module), **keep the current module** rather than clearing it —
   clearing empties the sidebar.

Mount it once, inside the shell provider, above `useMenu()`.

**Fallback landing when `Role.DefaultLandingUrl` is null.** Today that returns `MASTER_URL` and the
user gets the launcher. New rule: land on the **first accessible module's first visible leaf menu**,
computed client-side from `USER_ROLE_MODULES` + `PARENTCHILD_MENU_QUERY`. If that yields nothing, show
a small "no screens assigned — contact your administrator" state inside the shell, **not** a blank
page and not a launcher.

*Better long-term fix, out of scope here:* seed `Role.DefaultLandingUrl` for every role so the client
never has to guess. Worth doing, but the client fallback must exist regardless.

---

## ⑥ Invariants

- **INV-1 — `moduleCode` is never null after login.** Every entry point resolves it (§⑤) or inherits
  it. A null module means an empty sidebar, which under the new shell looks like a broken app rather
  than a launcher prompt.
- **INV-2 — RBAC is unchanged.** No capability check moves to the client, no module→menu mapping is
  hardcoded on the tenant side, no backend resolver changes signature. The rail changes *how*
  `moduleCode` is set, never *what it means*.
- **INV-3 — the rail is capability-gated, not decorative.** Tenant rail = modules where
  `isActive && isAccessible`. Platform rail = hardcoded items, each declaring a `PLATFORM_*`
  capability code that must be granted for the item to render. A hardcoded rail item the user cannot
  use must not be shown disabled — it must be absent.
- **INV-4 — the platform shell never calls `useMenu()`, `useBranding()`, or reads
  `sidebarType`/`layout`.** It is static by definition and must not regain a DB dependency.
- **INV-5 — the tenant shell keeps its DB-driven menu.** Zero change to `(core)` menu semantics. Only
  the chrome around it changes.
- **INV-6 — one shell component, two nav sources.** Do not fork the shell into two near-identical
  copies; the ops/platform layouts are already byte-for-byte duplicates and that duplication has cost
  us once. One `AppShell`, a `navSource` prop.
- **INV-7 — the platform surface pins `moduleCode = "PLATFORM"`** on mount, so
  `RoleCapabilityProvider` and `usePlatformCapabilities` keep resolving exactly as they do today.

---

## ⑦ Routing groups

Current layout (verified):

```
src/app/[lang]/
  (auth)/  (core)/  (member)/  (public)/  (setup)/
  (master)/                      ← layout.tsx: RouteGuard + CompanySettingsBootstrap only
    masterdashboard/
    ops/       layout.tsx → RoleCapabilityProvider → DashBoardLayoutProvider
    platform/  layout.tsx → RoleCapabilityProvider → DashBoardLayoutProvider
```

`(master)/ops/layout.tsx` and `(master)/platform/layout.tsx` are **byte-for-byte equivalent**, and
their own comments state they exist so *"the PLATFORM module's seeded menus (Tenants / Leads / Plans /
Audit) actually render"* through `useMenu()`. **That is precisely the coupling to sever.**

Target:

```
src/app/[lang]/
  (core)/     → <AppShell navSource="tenant">    tenant, dynamic
  (master)/   → <AppShell navSource="platform">  platform, static
      ops/        (no layout.tsx — inherits)
      platform/   (no layout.tsx — inherits)
      masterdashboard/ → redirect
```

- The shell is **hoisted into `(master)/layout.tsx`** and the two nested layouts are **deleted**. This
  is only possible because `masterdashboard` — the sole reason `(master)` was kept bare — is going
  away.
- **URLs do not change.** `(master)` parentheses never appear in the path, so `/en/platform/...` and
  `/en/ops/...` stay as they are. No redirects, no bookmark breakage, no backend
  `Role.DefaultLandingUrl` reseeding. Recommendation: **do not** consolidate `ops` and `platform` into
  one segment in this phase — it is pure churn with real reseeding cost. Revisit later (§⑨ Q3).
- Groups stay separated exactly as the user asked: `(core)` = tenant, `(master)` = platform.

---

## ⑧ Component plan

**New:**

| Path | What |
|---|---|
| `src/presentation/provider/app-shell-provider.tsx` | The one shell. Props: `navSource: "tenant" \| "platform"`, `trans`. Renders top bar + rail + context panel + content. Keeps `ModalProvider`, `MenuLoader`, `HeaderSearch`, page transitions. Drops `ModuleLoader`, `Sidebar`, the four layout branches, `PlanStatusBanner` on platform. |
| `src/presentation/components/layout-components/app-rail/` | The 72px rail. Renders from `useRailItems()`. |
| `src/presentation/components/layout-components/context-panel/` | Zone 2. Tenant mode reads `useParentChildMenuStore`; platform mode reads the static constant. |
| `src/presentation/hooks/useActiveModule/index.ts` | §⑤ route→module resolver. |
| `src/presentation/hooks/useRailItems/index.ts` | Returns rail items for the active `navSource`, capability-filtered. |
| `src/application/constants/platform-navigation.ts` | **The static platform IA.** Typed constant: rail items → sections → leaves, each with `href`, `icon`, `labelKey`, `requiredCapability`. |
| `src/application/stores/shell-stores/app-shell-store.ts` + `app-shell-istore.ts` | Rail/panel collapse state, per-module last-visited menu, hover-prefetch state. **Verified convention:** `src/application/stores/<domain>-stores/<name>-store.ts` + paired `-istore.ts`. `src/presentation/store/` does not exist. |

**Modified:** `(master)/layout.tsx`, `(core)/layout.tsx`, `useAuth/index.ts` (share the comparator,
drop the `MASTER_URL` fallback), `inline-search-bar.tsx` (drop the module scrim, keep the jump).

**Deleted:** `(master)/ops/layout.tsx`, `(master)/platform/layout.tsx`, `masterdashboard/page.tsx`,
`module-navigator/`, `module-loader/`, `pages/master/landing-page/` (minus the relocations in §③),
and — once `(core)` is migrated — `dashboard-layout-provider.tsx` plus the `sidebar/module` variant.

### 8.1 Static platform IA (draft — confirm in §⑨ Q1)

From the verified route inventory. Rail item → panel sections:

| Rail | Panel |
|---|---|
| **Home** | Platform overview (the relocated KPI strips from §③) |
| **Tenants** | All tenants · Provisioning runs · Tenant access |
| **Growth** | Leads · Deals · Onboarding |
| **Billing** | Plans · Billing · Gateways |
| **Comms** | Communications · Notifications · Webhook logs |
| **Staff** | Platform staff |
| **System** | Audit · Data cleanup |

Every leaf maps 1:1 to an existing route — this is a re-grouping, not new screens.

---

## ⑨ Phasing

**Phase 0 — `useActiveModule()` only.** Ship the resolver behind the *existing* shell, with the
launcher still present. Nothing visible changes; deep links simply stop losing module context. This
de-risks the whole plan, because if route→module resolution is wrong, everything after it is broken
and it is far cheaper to find out now.

**Phase 1 — platform shell.** Build `AppShell` + rail + panel + `platform-navigation.ts`. Mount in
`(master)/layout.tsx`, delete the two nested layouts, redirect `masterdashboard`. **Blast radius:
platform only.** `(core)` still runs `DashBoardLayoutProvider`; the tenant app is untouched and
cannot regress. This alone delivers ask 1 in full.

**Phase 2 — tenant shell.** Point `(core)` at `AppShell navSource="tenant"`. Rail = accessible
modules, panel = `useMenu()`. Delete the module navigator and `ModuleLoader`. Highest-risk phase —
every tenant user's daily path.

**Phase 3 — cleanup.** Delete `dashboard-layout-provider.tsx`, the `sidebar/module` variant, and the
`sidebarType`/`layout` customizer options that no longer have a target. Relocate the surviving master
dashboard widgets (§③) onto a real dashboard screen.

Phases 1 and 2 are independently shippable and independently revertable. Do not merge them.

---

## ⑩ Risks

| Risk | Mitigation |
|---|---|
| A route belongs to no module → sidebar empties on refresh | §⑤ rule 5: keep the current module on no match. Log a warning listing unmapped routes; use it to audit `moduleUrl` coverage before Phase 2. |
| Two modules share a URL prefix and the shorter one wins | Longest-prefix comparator, already written and proven at `resolvePostLoginLanding:66-71`. Reuse it — do not re-derive it. |
| Capability query storms as users hover the rail | `RoleCapabilityProvider` already caches per module (`loadedModules` set). Debounce hover prefetch ~150ms and never refetch a loaded module. |
| Rail runs out of vertical space on a tenant with many modules | Overflow into a "More" rail item (ClickUp does exactly this). Decide the cut at 9 items. |
| `MASTER_URL` referenced in more places than `useAuth` | Grep before Phase 1 and redirect the route rather than deleting it. |
| The theme customizer offers layouts the new shell doesn't implement | Phase 3 removes those options. Until then, ignore `layout`/`sidebarType` in `AppShell` rather than half-honouring them. |
| The relocated dashboard widgets have no home | They stay live on the redirect target until Phase 3 gives them a screen. Do not delete them in Phase 1. |

---

## ⑪ Explicit non-goals

- No backend change. No migration. No seed. No `auth.Modules` / menu / capability data change.
- No URL changes. No `Role.DefaultLandingUrl` reseeding.
- No change to `(auth)`, `(member)`, `(public)`, `(setup)`.
- No change to `MenuLoader`'s commit-gated scrim logic.
- Tenant menu semantics unchanged — only the chrome around them.

---

## ⑫ Open questions

1. **Platform IA (§8.1)** — is the seven-item rail grouping right, or do you want a different
   grouping of the existing `ops`/`platform` routes?
2. **Seeded PLATFORM menu rows** — the platform panel becomes static, so the seeded PLATFORM menus are
   no longer read by `useMenu()`. But `PLATFORM_*` capabilities hang off those menu rows and
   `usePlatformCapabilities` matches on `menu.menuCode`. **Recommendation: leave the rows in place,
   dormant for navigation, live for RBAC.** Retiring them would break platform capability checks.
   Confirm.
3. **`ops` + `platform` segment consolidation** — recommend deferring (§⑦). Confirm you're happy to
   keep both segments.
4. **Rail click = swap panel only, or also jump to last-visited menu?** Recommend swap-only for v1
   (§2.1). Confirm.
5. **Master dashboard widgets** — which screen do the KPI/activity strips land on? A new platform Home
   screen, or fold into an existing dashboard?
6. **Tenant top-bar left slot** — ClickUp puts a workspace switcher there. For a tenant user that
   would be the company/branch. Do you want a branch switcher there, or just the logo?
7. **Phase 2 timing** — ship Phase 1 (platform) alone first and let it soak, or do both before the
   demo?

---

## ⑬ Build log

_(empty — nothing built)_
