# PSS 2.0 — App Shell Phase 2: Tenant Shell (`(core)` on `AppShell`)

**Read `PSS-2.0-APP-SHELL-PHASE-1-PLATFORM-BUILD-PROMPT.md` first.** Phase 1 built the shell; this
phase points the tenant route group at it. Same three zones, same components, second `navSource`.

**Frontend only. No backend change. No migration. No seed. No SQL. No URL change.**

**Blast radius: `(core)` — every tenant user's daily path. This is the highest-risk phase in the
plan.** It is also the cheapest to revert: `DashBoardLayoutProvider` is *not* deleted here, so
rollback is a one-line change in `(core)/layout.tsx`.

---

## §⓪ Why this exists

Phase 1 severed the platform surface from `DashBoardLayoutProvider` and gave it a static
ClickUp-style shell: 72px icon rail (zone 1) → context panel (zone 2) → content, under a slim top
bar (zone 0). It shipped, `(core)` was untouched, and the tenant app still runs the old
four-branch layout provider with a module-launcher popover in the header.

Phase 2 gives tenant users the same shell, with the one structural difference that defines the
whole phase:

| | Platform (`navSource="platform"`) | Tenant (`navSource="tenant"`) |
|---|---|---|
| What a rail icon **is** | a *section* of the one `PLATFORM` module | **a module** (`crm`, `setting`, `organization`, …) |
| Where rail items come from | hardcoded `PLATFORM_NAVIGATION` | `USER_ROLE_MODULES` (`isActive && isAccessible`) |
| Where panel leaves come from | the same constant | `PARENTCHILD_MENU_QUERY` for that module |
| Who filters for RBAC | the client (`usePlatformCapabilities`) | **the server** — the menu query already returns only renderable menus |
| Rail click | swap panel | swap panel |

The module launcher (`ModuleNavigator`) disappears from the user's mental model: modules stop being
a popover you open and become the always-visible left edge of the app.

---

## §① Read first (grounding)

| File | Why |
|---|---|
| `PSS-2.0-APP-SHELL-REDESIGN-APPROACH.md` §⑤ (line 155), §⑥, §⑧, §⑨ | The parent plan. §⑤ *"Route → module resolution — the piece that must be built first"* is T-1 below. |
| `PSS-2.0-APP-SHELL-PHASE-1-PLATFORM-BUILD-PROMPT.md` §⑬ + §⑭ | What actually landed, including the six recorded deviations. §⑭ has the literal shapes you are extending. |
| `src/presentation/provider/app-shell-provider.tsx` | The shell. You are removing its `navSource === "tenant"` throw and branching it — **not forking it** (INV-6). |
| `src/presentation/provider/dashboard-layout-provider.tsx` | What you are replacing. Read `LayoutWrapper` (line 160+): the scrim logic there is already copied into `AppShell`; the **module** scrim (`isModuleLoading`, line 234+) is not, and §6.5 below explains why that is correct. |
| `src/app/[lang]/(core)/layout.tsx` | The one file whose change flips the phase on. Note `PlanEnforcementProvider` — it stays. |
| `src/presentation/hooks/useInitialRendering/useMenu.ts` | 30 lines. Queries `PARENTCHILD_MENU_QUERY` by `moduleCode` from the global store and writes `useParentChildMenuStore`. |
| `src/presentation/hooks/useAuth/index.ts:47-86` | `resolvePostLoginLanding` — holds the longest-prefix comparator you must lift (§⑤ rule 3) and the `MASTER_URL` fallback you must replace. |
| `src/presentation/components/custom-components/module-navigator/index.tsx` | The launcher being retired. Read it for the `USER_ROLE_MODULES` shape and the accessible/restricted split. |
| `src/presentation/components/layout-components/sidebar/module/index.tsx` | Today's module sidebar. Read lines 24-29 and 155-158 — the "don't blank on a background refetch" behaviour is a bug fix you must not lose. |
| `src/presentation/components/layout-components/helper/menu-mapping.tsx` | `mapMenuToModernFormat` etc. — how the raw menu tree is shaped today, including the synthetic "Dashboard" first item. |

---

## §② Reuse — do not rebuild

- **`AppShell`, `AppRail`, `ContextPanel`, `AppTopbar`, `CommandPalette`** — all four zones exist and
  work. You are widening their inputs, not writing new components.
- **`app-shell-store`** — `activeRailKey` / `panelCollapsed` already persist. Reuse both.
- **The scrim** — `MenuLoader` + the commit-gated backstop already live in `AppShell`, copied verbatim
  from `LayoutWrapper`. Do not touch that logic (parent plan §⑪).
- **The rail overflow, hover-intent, tooltip, skeleton and solid-active styling** in `AppRail` — all
  already built for nine-plus items. A tenant with twelve modules needs no new code there.
- **The menu query** — `PARENTCHILD_MENU_QUERY` and `useMenu()`. Do not write a second menu query, do
  not change its variables, do not change what the server returns.

---

## §③ Data model — NO CHANGE

No table, column, index, enum or DTO changes. `auth.Modules`, `Menus`, `MenuCapabilities`,
`RoleCapabilities` are read exactly as they are read today.

The seeded `PLATFORM` menu rows stay in place — dormant for navigation, live for RBAC (parent plan
§⑫ Q2, confirmed in Phase 1). Unchanged here.

---

## §④ Backend — NO CHANGE

No resolver, no handler, no signature, no `Role.DefaultLandingUrl` reseeding. If you conclude a
backend change is needed, **stop and write it into §⑬ instead of making it** — the user owns backend
builds and migrations.

---

## §⑤ Invariants

Phase 1's invariants carry forward, amended where "platform" was doing the work of "the shell":

- **INV-1 — the *platform* path reads no tenant theme/menu state.** Unchanged and still enforced:
  `navSource="platform"` must not gain `useMenu()` / `useBranding()` / `layout` / `sidebarType`. The
  **tenant** path legitimately reads `useMenu()` and `useBranding()`. Both live in one component, so
  every such read must sit behind an explicit `navSource === "tenant"` branch — never an unconditional
  hook call that the platform path also executes.
- **INV-2 — RBAC is unchanged.** No capability check moves to the client. The tenant panel shows what
  `PARENTCHILD_MENU_QUERY` returns, full stop; there is no client-side filter to write, and adding one
  would be a second, divergent source of truth.
- **INV-3 — a destination the user cannot use is ABSENT, never disabled, never flashed-then-removed.**
  For the tenant rail this means: **modules with `isAccessible === false` do not render.** This is a
  deliberate behaviour change from `ModuleNavigator`, which listed them under a "Restricted" heading.
  Record it in §⑬. While the module list or the menu is loading, render skeletons — never an
  unfiltered list.
- **INV-4 — no URL changes, no route files moved.** `(core)` parentheses never appear in a path.
- **INV-5 — a rail click never navigates.** `router.push` is not called from the rail on either
  `navSource`. It selects which module's menu the panel shows. Navigation happens only on a leaf click.
- **INV-6 — ONE shell component.** Do not fork `app-shell-provider.tsx`, do not fork `AppRail` or
  `ContextPanel` into tenant/platform copies. The two `(master)` child layouts were byte-for-byte
  duplicates once and it cost us a bug; do not recreate that shape one level up.
- **INV-7 — `(master)`, `(auth)`, `(member)`, `(public)`, `(setup)` are untouched.** `(master)` must
  render identically after this phase. Any change to a shared component must be additive and
  `navSource`-guarded.
- **INV-8 (new) — `moduleCode` is derived from the URL, never from a rail click.** See §6.3. This is
  the single most important rule in the phase; getting it wrong produces a rail that fights the router.

---

## §⑥ Frontend

### 6.1 Files

**New**

| Path | What |
|---|---|
| `src/presentation/hooks/useActiveModule/index.ts` | §⑤ of the parent plan: URL → module. The piece that must be built first. |
| `src/presentation/hooks/useTenantRailItems/index.ts` | `USER_ROLE_MODULES` → rail items. |
| `src/presentation/hooks/usePanelMenu/index.ts` | A module code → panel sections/leaves. |
| `src/domain/types/shell-navigation.ts` | `ShellRailItem` / `ShellPanelSection` / `ShellPanelLeaf` — the shape both nav sources produce. |
| `src/application/utils/module-url-match.ts` | The longest-prefix comparator, lifted out of `useAuth` so there is **one** implementation. |

**Modified**

`app-shell-provider.tsx`, `app-rail/index.tsx`, `context-panel/index.tsx`, `app-topbar/index.tsx`,
`useRailItems/index.ts`, `platform-navigation.ts` (type aliases only), `(core)/layout.tsx`,
`useAuth/index.ts`, `global-search/inline-search-bar.tsx`.

**Deleted: nothing.** See §6.5.

### 6.2 The shared shape

Phase 1 typed the IA as `PlatformRailItem` / `PlatformPanelSection` / `PlatformPanelLeaf`. Those
names are now wrong for half their callers.

Create `src/domain/types/shell-navigation.ts` with `ShellRailItem` / `ShellPanelSection` /
`ShellPanelLeaf` — structurally identical to today's platform types, plus on `ShellRailItem`:

```ts
/** Tenant only: the module this rail icon represents. Undefined on the platform rail,
 *  where every item belongs to the one PLATFORM module. */
moduleCode?: string;
/** Tenant only: the module's own base URL, used by the hover prefetch. */
moduleUrl?: string;
```

Then in `platform-navigation.ts` re-export the old names as aliases
(`export type PlatformRailItem = ShellRailItem;` …) so no existing import breaks and the diff stays
small. Do not do a repo-wide rename in this phase.

`requiredCapability` stays on the type and stays **unused on the tenant path** — the server already
filtered. Do not populate it from menu capabilities.

### 6.3 `useActiveModule()` — build and land this first

Parent plan §⑤, verbatim in intent:

1. Query `USER_ROLE_MODULES` (`cache-first` — `useAuth` has usually already warmed it).
2. Filter to `isActive && isAccessible`.
3. Match `usePathname()` with the locale prefix stripped against `moduleUrl`, **longest prefix wins**.
   Lift the comparator now living at `useAuth/index.ts:66-71` into
   `application/utils/module-url-match.ts` and have **both** call it.
4. On a match, write `moduleId/Code/Name/Url` to the global store **only if changed**. An
   unconditional write re-fires `useMenu()` and the capability query on every render.
5. On no match, **keep the current module** — never clear it. Clearing empties the panel.
6. Dev-only: `console.warn` once per unmatched pathname, prefixed `[useActiveModule] unmapped route:`.
   This is the §⑩ audit trail for `moduleUrl` coverage gaps and is how you will find them cheaply.

Mount it **once**, inside `AppShell`, guarded to `navSource === "tenant"`, above everything that reads
`moduleCode`.

**INV-8 restated, because this is where phases go wrong.** Two pieces of state that look like one:

| State | Owner | Means |
|---|---|---|
| `moduleCode` (global store) | `useActiveModule`, from the URL | the module that owns **the screen you are on**. Drives RBAC partitioning and `useMenu()`. |
| `activeRailKey` (shell store) | the rail click, and the URL as a fallback | the module whose menu **the panel is displaying**. |

They are equal almost always. They diverge for exactly as long as a user clicks another module's rail
icon and browses its menu without picking a leaf. If a rail click writes `moduleCode`, then
`useActiveModule` immediately snaps it back to the URL's module, the panel flickers, and the capability
query fires twice per click. **A rail click must write `activeRailKey` only.** When the URL commits to
the new module, `useActiveModule` moves `moduleCode` and the two re-converge.

### 6.4 `usePanelMenu(moduleCode)` — the panel's data

Signature: `usePanelMenu(moduleCode: string | null): { sections: ShellPanelSection[]; loading: boolean }`.

- **When `moduleCode === ` the active module:** read `useParentChildMenuStore` — it is already being
  filled by `useMenu()`. No second query.
- **When it differs** (the user is previewing another module's menu): run `PARENTCHILD_MENU_QUERY`
  with that module code, `fetchPolicy: "cache-first"`. Apollo keys by variables, so the second and
  later previews of the same module are free. **Do not write the store from here** — the store belongs
  to the active module and `global-search` reads it.
- Map the tree to sections/leaves: a top-level menu with children → a section whose label is the
  parent's `menuName` and whose leaves are its children; a top-level menu that is itself a link → a
  one-leaf section (or an ungrouped leaf at the top). Third-level menus flatten into their parent
  section for v1 — the panel is 248px wide and a third indent level does not fit. Record any menu that
  loses depth in §⑬.
- Keep `sidebar/module/index.tsx:24-29`'s behaviour: **while `loading` with data already present,
  keep rendering the old data.** `cache-and-network` flips `loading` on every module switch, and
  blanking on it is precisely the "sidebar reloads" bug that was already fixed once.
- The synthetic "Dashboard" first entry that `mapMenuToModernFormat` prepends: keep it, as the first
  leaf of the first section, pointing at `/{moduleCode.toLowerCase()}/dashboard`. Users rely on it and
  it is not in the menu tree.

### 6.5 `AppShell` — what changes

Remove the `navSource === "tenant"` throw. Everything else is a branch, not a fork:

| Concern | `platform` | `tenant` |
|---|---|---|
| Module context | pin `moduleCode = "PLATFORM"` (existing guarded effect) | `useActiveModule()` |
| Rail items | `useRailItems("platform")` (today's behaviour) | `useRailItems("tenant")` → `useTenantRailItems` |
| Panel items | from the rail item's static sections | `usePanelMenu(activeRailKey)` |
| `PlanStatusBanner` | absent | rendered inside `<main>`, above `{children}`, as `LayoutWrapper` does today |
| Branding | never | `useBranding()` — tenant logo + name in the top bar |
| `layout` / `sidebarType` / `navbarType` | ignored | **ignored** — see the trap in §⑪ |

`ModalProvider`, the scrim, the `motion.div` transition, the `min-w-0` main, the mobile `Sheet`
drawer and the collapsed-panel edge handle are all shared verbatim.

**The module scrim (`isModuleLoading` / `ModuleLoader`) is not carried over, deliberately.** It
existed to cover a full-page module switch initiated from the launcher. Under the new shell a module
switch is a panel swap with no navigation, so there is nothing to cover. Keep the store fields — a
large number of destination screens call `setModuleLoading(false)` and must keep compiling — but the
shell never raises the flag and never mounts the loader.

### 6.6 `AppRail` — what changes

- Props: `railItems: ShellRailItem[]`, plus `navSource`.
- Click: `setActiveRailKey(item.key)`. Unchanged, both sources. **No `router.push`, no
  `setModuleCode`.**
- Hover-intent (150ms, de-duplicated by `prefetchedRef`) currently prefetches the section's first
  leaf route. For tenant, prefetch **the module's menu query** instead — `usePanelMenu`'s cache-first
  query for `item.moduleCode`. That is the wait the user will actually feel. Prefetching a route you
  do not yet know the href of is not possible before the menu resolves.
- Icons: `moduleIcon` from `USER_ROLE_MODULES` is not guaranteed to be an Iconify colon-form name.
  **Verify what the seeded values actually look like before writing the mapper**, and fall back to a
  neutral `ph:squares-four` when the value is empty or unrecognised. (Phase 1 deviation #2: hyphen form
  renders nothing, silently.)
- Order by `orderBy`, then `moduleName`.

### 6.7 `ContextPanel` — what changes

- Props become `sections: ShellPanelSection[]` (+ existing `loading` / `lang` / `embedded` /
  `onNavigate`), so the panel no longer reaches into `items.find(...)` for the active rail item —
  the shell resolves that. Update the platform call site accordingly.
- Header label = the active rail item's label (the module name, on tenant).
- Leaf click is **unchanged**: `setPendingHref` + `setIsMenuRendering(true, label)` + `Link`. The
  scrim handoff already works.
- One addition: when the clicked leaf belongs to a module other than the active one, that is still just
  a `Link` click — `useActiveModule` moves `moduleCode` when the route commits. Do not pre-set it.

### 6.8 `AppTopbar` — what changes

- Props gain `navSource`.
- Brand mark: `platform` keeps `ph:shield-star` + "PSS" + the Platform chip. `tenant` shows the tenant
  logo and name from `useBranding()` — call the hook in `AppShell` and pass values down, so the
  platform path never executes it (INV-1).
- `PlanStatusChip`: rendered on `tenant` only, ahead of the icon cluster, exactly as `header.tsx:31`
  has it.
- `ModuleNavigator`: never rendered on either path. The rail replaced it.
- Command palette groups on `tenant` v1: the **active module's** menu leaves, grouped by section, plus
  a "Switch module" group of the rail items (picking one selects the rail, it does not navigate).
  Loading every module's menu to build a global palette is out of scope — note it in §⑬ as the obvious
  Phase 3 follow-up.
- `HeaderSearch` (the old global-search dialog) is **not** mounted in the new shell; the palette is the
  one search surface. Verify nothing else depends on it being mounted before you drop it.

---

## §⑦ Menu + RBAC — NO CHANGE

`PARENTCHILD_MENU_QUERY` keeps its variables and its meaning. `RoleCapabilityProvider` keeps
partitioning by `moduleCode`. Sidebar visibility stays an `ISMENURENDER` role grant resolved on the
server. Nothing about who-sees-what moves to the client.

---

## §⑧ Tasks

| # | Task | Done when |
|---|---|---|
| T-1 | `application/utils/module-url-match.ts` — lift the longest-prefix comparator; `resolvePostLoginLanding` calls it. | One implementation exists; `useAuth` behaviour unchanged. |
| T-2 | `useActiveModule()` per §6.3, incl. the unmapped-route dev warning. | Hook exists, not yet mounted. |
| T-3 | Null-landing fallback: `resolvePostLoginLanding` returns the first accessible module's first visible leaf instead of `MASTER_URL`; if that yields nothing, land on a small in-shell "no screens assigned — contact your administrator" state. **Keep the `MASTER_URL` constant** — `company-switcher-item.tsx` and `route-guard` still use it legitimately. | A tenant user whose role has no `DefaultLandingUrl` no longer lands on the platform redirect. |
| T-4 | `domain/types/shell-navigation.ts` + aliases in `platform-navigation.ts`. | Typecheck passes with zero call-site edits outside the aliases. |
| T-5 | `useTenantRailItems()` per §6.6. | Returns ordered, accessible-only rail items; `[]` while loading. |
| T-6 | `usePanelMenu()` per §6.4. | Active module reads the store; a previewed module runs its own cache-first query. |
| T-7 | `useRailItems(navSource)` dispatches to the platform or tenant implementation behind one return shape. | Platform output byte-identical to today. |
| T-8 | `AppRail` + `ContextPanel` generalized per §6.6/§6.7; platform call sites updated. | `(master)` renders identically. |
| T-9 | `AppTopbar` per §6.8. | Tenant shows logo + `PlanStatusChip`; platform unchanged. |
| T-10 | `AppShell` per §6.5 — throw removed, branches added, `PlanStatusBanner` back for tenant. | Both `navSource` values render. |
| T-11 | `(core)/layout.tsx` → `<AppShell navSource="tenant" trans={trans}>`, keeping `RouteGuard`, `RoleCapabilityProvider` and `PlanEnforcementProvider` exactly where they are. | The phase is live. |
| T-12 | `inline-search-bar.tsx` — drop the module scrim, keep the jump. | No component raises `isModuleLoading` any more. |
| T-13 | Walk every module's menu on a dev server and collect the unmapped-route warnings from T-2. | The list is in §⑬, whether empty or not. |
| T-14 | `cd PSS_2.0_Frontend && rm -rf .next/types && npx tsc --noEmit --incremental false` → EXIT=0, then a `git status --short` blast-radius review. | Nothing outside `(core)` + the shared shell files changed. |

Land T-1 → T-3 **as their own commit** before anything else. Route→module resolution is the
foundation; if it is wrong, everything after it is broken, and it is far cheaper to find out while
the old shell is still rendering.

---

## §⑨ Acceptance

1. Every accessible module appears as a rail icon, ordered by `orderBy`; inaccessible ones are absent.
2. Clicking a rail icon swaps the panel and **does not change the URL** — verified in the address bar.
3. Clicking a rail icon does not fire the capability query (Network tab) until a leaf is picked.
4. Picking a leaf navigates, raises the scrim, and the scrim drops when the destination is ready — no
   flicker of the previous screen.
5. Hard-refresh on a deep link inside any module lights up that module's rail icon and shows its menu.
6. Browser back/forward keeps rail, panel and content in agreement.
7. A tenant with more than nine modules overflows into the "More" popover without layout breakage.
8. The panel does not blank during a module switch that is served from cache.
9. ⌘K opens the palette; picking a menu entry navigates; picking a "Switch module" entry only swaps the panel.
10. `PlanStatusBanner` and `PlanStatusChip` still appear for tenant users; neither appears on `(master)`.
11. The tenant logo appears on tenant, never on platform; `ph:shield-star` + Platform chip appears on platform, never on tenant.
12. Below `xl` the drawer holds rail + panel and closes on navigation.
13. A wide data grid does not push the rail off-screen (`min-w-0` on `<main>`).
14. `(master)` is visually and behaviourally identical to Phase 1.
15. Reverting `(core)/layout.tsx` to `DashBoardLayoutProvider` restores the old shell with no other change.

Mark each as *verified on a dev server* or *satisfied statically* in §⑬. Do not claim the runtime ones
without running them — Phase 1 left twelve of its own acceptance points unexercised and said so.

---

## §⑩ Out of scope — do NOT build

- Deleting `dashboard-layout-provider.tsx`, `sidebar/`, `header/header.tsx`, `module-navigator/`,
  `module-loader/`. **Phase 3.** See §⑪ trap 1 — deleting them here does not even compile.
- Removing the `layout` / `sidebarType` / `navbarType` options from the theme customizer. Phase 3.
- Relocating the deleted master-dashboard KPI widgets. Phase 3.
- A cross-module command palette that loads every module's menu.
- Consolidating the `ops` and `platform` URL segments. Deferred indefinitely (parent plan §⑦).
- Seeding `Role.DefaultLandingUrl`, or any other backend fix for the null-landing case. The client
  fallback in T-3 is the deliverable here; the seed is a separate, user-owned change.
- Inventing `PLATFORM_*` capability codes or writing a seed for them. Still open from Phase 1, still
  not yours to close.
- Per-module last-visited-menu memory. The confirmed v1 behaviour is swap-only (parent plan §⑫ Q4).

---

## §⑪ Traps

1. **The approach doc's phasing is wrong about deletions, and following it breaks the build.**
   §⑨ of the parent plan says Phase 2 deletes `ModuleNavigator` and `ModuleLoader`. It cannot:
   `ModuleNavigator` is mounted by `header/header.tsx`, which is mounted by
   `DashBoardLayoutProvider`, which survives until Phase 3 precisely so this phase stays revertable.
   **Delete nothing.** Unmount everything. Phase 3 deletes the whole cluster in one pass.
2. **A rail click that writes `moduleCode`.** Read §6.3 again. This is the failure mode that makes the
   rail feel possessed.
3. **Calling `useMenu()` / `useBranding()` unconditionally in `AppShell`.** Hooks cannot be called
   conditionally, so "guard it with an `if`" is not available. Either call them inside a small
   `navSource === "tenant"`-only child component that `AppShell` renders, or give them an internal
   `skip`/enabled flag. An unguarded call re-couples the platform shell to tenant state and silently
   breaks INV-1 with no visible symptom until a platform-only user hits it.
4. **`loading` from `cache-and-network` is not "no data".** Blanking on it is the sidebar-reload bug.
   `sidebar/module/index.tsx:24-29` and `:155-158` already record the fix; carry it, don't re-find it.
5. **Icon form.** `getFullIconName()` returns its input verbatim — `ph-house` renders nothing at all,
   with no error. Colon form only, and fall back when `moduleIcon` is unusable.
6. **Stale `.next/types`.** After route-group work, the first typecheck will report hundreds of
   `TS2307`s inside `.next/types/**` that are not real. `rm -rf .next/types` first, then judge.
7. **Sibling-worktree drift.** This repo has a sibling at `pwds-soruban/` without the `- Copy` suffix,
   and `PSS_2.0_Frontend` is a **nested git repo**. Verify with `git status --short` from inside
   `PSS_2.0_Frontend`, using absolute paths.
8. **`"use client"`.** Every new hook and every component that uses one needs it. A missing directive
   surfaces as an opaque Ecmascript/hook error at the route level, not at the file.
9. **`global-search` still reads `useParentChildMenuStore`.** That is why `usePanelMenu` must not write
   the store for a previewed module — doing so makes search results silently belong to a module the
   user is not in.

---

## §⑫ Hand-off — user-owned, do not perform

- **Backend build.** Not required by this phase; if you believe it is, write the reason in §⑬ instead.
- **EF migrations.** None. Do not create one, do not edit `ModelSnapshot`.
- **Seeds/SQL.** None. The `PLATFORM_*` capability-seed gap stays open and stays flagged.
- **`Role.DefaultLandingUrl` seeding.** Recommended long-term (parent plan §⑤), user-owned, not here.

---

## §⑬ Build log

*Fill in as you go. Status, what landed per task, deviations with reasons, and — separately — which
acceptance points were verified on a running dev server versus satisfied statically.*

**Status:** built. T-1 → T-12 landed, T-14 green (`tsc --noEmit --incremental false` → EXIT=0, blast
radius inside `(core)` + the shared shell files). T-13 was done **statically, not on a dev server** —
see below. Nothing was deleted; the phase still reverts by putting `DashBoardLayoutProvider` back on
one line in `(core)/layout.tsx`.

**What landed, by task**

| # | Landed as |
|---|---|
| T-1 | `application/utils/module-url-match.ts` — `stripLocalePrefix` / `normalizeModulePath` / `matchModuleByUrl`; `resolvePostLoginLanding` imports it. |
| T-2 | `presentation/hooks/useActiveModule/index.ts`, incl. the once-per-path dev warning. |
| T-3 | `resolvePostLoginLanding` falls back to the first accessible module's first visible leaf; `(core)/no-access/page.tsx` is the in-shell empty state. `MASTER_URL` kept. |
| T-4 | `domain/types/shell-navigation.ts`; `platform-navigation.ts` re-exports the old names as aliases. |
| T-5 | `presentation/hooks/useTenantRailItems/index.ts` (`enabled` gate, `resolveModuleIcon`). |
| T-6 | `presentation/hooks/usePanelMenu/index.ts`. |
| T-7 | `useRailItems(navSource)` dispatches; `usePlatformCapabilities` gained an `enabled` param (default `true`). |
| T-8 | `AppRail` (+ `navSource`, tenant hover-prefetch of `PARENTCHILD_MENU_QUERY`), `ContextPanel` (now takes `sections`/`label` instead of finding the active rail item itself). |
| T-9 | `AppTopbar` — `navSource`, tenant brand mark, `PlanStatusChip`, tenant palette + `handlePick`. |
| T-10 | `AppShell` — throw removed; `TenantShellSync`, `PlatformPanel`/`TenantPanel`, guarded effects, tenant `PlanStatusBanner`. |
| T-11 | `(core)/layout.tsx` → `<AppShell navSource="tenant" trans={trans}>`. |
| T-12 | `inline-search-bar.tsx`, `search-menu-results.tsx`, `global-search.tsx` — all three now raise the menu scrim (`setIsMenuRendering` + `setPendingHref`) instead of the module scrim. |

### Deviations and findings

1. **`ModuleUrl` is a landing route, not a module root — T-1's comparator did not work on real URLs.**
   The seeded values are `/crm/dashboards/overview`, `/setting/dashboards/overview`, … so a screen URL
   like `/crm/contact/contact` is **not** under any `moduleUrl` and the longest-prefix match returned
   `undefined` on essentially every navigation. `useActiveModule` would then have kept the stale module
   forever and logged an unmapped-route warning per screen. `matchModuleByUrl` now has a second tier:
   if no `moduleUrl` is a prefix, match on the **first path segment** (`crm`, `setting`, …). Tier 1 is
   untouched, so `useAuth`'s landing behaviour is unchanged.
2. **Route→module coverage (the static form of T-13).** Directories under `(core)`: `crm`, `setting`,
   `accesscontrol`, `organization`, `reportaudit` all resolve via tier 2. `billing/*` and `no-access`
   have **no module row** and will hit the "keep the current module" path — correct behaviour (they are
   cross-module surfaces), but they are the routes that would emit the dev warning. `general/*` resolves
   only if a `GENERAL` module row exists in the target database; the `modules.sql` dump in this repo
   does not contain one.
3. **T-13 was not run on a dev server.** No module walk was performed, so the warning list above is
   derived from the route tree and the seeded `ModuleUrl` values, not observed.
4. **INV-3 differs from `ModuleNavigator`.** Inaccessible modules are simply absent from the rail; the
   old launcher showed them under a "Restricted" heading.
5. **Seeded module icons are `solar:*`, not `ph:*`** (`solar:people-nearby-bold` etc.). `resolveModuleIcon`
   passes a colon-form name straight through, so no mapping was needed — but the rail is visually a
   `solar` set next to the shell's `ph` chrome icons.
6. **Tenant-only work sits in child components, not in `AppShell` branches.** §6.8 says "pass values
   down"; instead `TenantShellSync` (hydration hooks) and `TenantPanel` (the menu query) are *rendered*
   conditionally. Mounting a child is not a hook-order change, which trap 3 explicitly permits, and it
   keeps `AppShell` free of conditional hooks.
7. **Third-level menus flatten into their parent section** (as §14.2 allows for v1).
8. **`PlanStatusBanner` renders inside the page `motion.div`**, above `{children}` — i.e. inside
   `<main>`, not between the topbar and the rail, so it scrolls with the page.
9. **Tenant palette v1 = active module's leaves + a "Switch module" group.** Offering every module's
   leaves would mean running `PARENTCHILD_MENU_QUERY` for every module on mount (§6.8). "Switch module"
   rows use a `__switch-module:` sentinel href and `CommandPalette`'s existing `onPick` escape hatch —
   `CommandPalette` itself was not modified, and platform passes no `onPick`, so its behaviour is
   byte-identical.
10. **T-12's "no component raises `isModuleLoading`" holds for mounted components only.**
    `sidebar/module/menu-item.tsx` and `dashboard-layout-provider.tsx` still call `setModuleLoading(true)`,
    but both belong to the old cluster that this phase unmounts and Phase 3 deletes. The store fields and
    the ~50 `setModuleLoading(false)` call sites across page components are untouched and still compile,
    per §6.5.

### Acceptance — how each point was checked

*Nothing below was exercised on a running dev server; no dev server was started in this phase.*

| # | Point | Status |
|---|---|---|
| 1 | Accessible modules as rail icons, `orderBy`, inaccessible absent | satisfied statically (`useTenantRailItems` filters `isActive && isAccessible`, sorts by `orderBy`) |
| 2 | Rail click swaps panel, no URL change | satisfied statically (`AppRail` calls `setActiveRailKey` only; INV-5) |
| 3 | Rail click fires no capability query | satisfied statically (capabilities are keyed off `moduleCode`, which only `useActiveModule` writes) |
| 4 | Leaf navigates, scrim raises and drops | **not verified** — runtime only |
| 5 | Hard-refresh deep link lights the right rail icon | satisfied statically (URL → `moduleCode` → `activeRailKey` effect), timing unverified |
| 6 | Back/forward keeps rail, panel, content in agreement | satisfied statically (same effect chain), **not verified** |
| 7 | >9 modules overflow into "More" | satisfied statically (`MAX_VISIBLE = 9`), **not verified** |
| 8 | Panel does not blank on a cached module switch | satisfied statically (`loading && sections.length === 0` gates the skeleton; hover prefetch warms the cache), **not verified** |
| 9 | ⌘K palette; "Switch module" only swaps the panel | satisfied statically (`handlePick` sentinel), **not verified** |
| 10 | Plan chip/banner tenant-only | satisfied statically (both behind `isTenant`) |
| 11 | Tenant logo vs platform mark | satisfied statically (the `isTenant` branch in `AppTopbar`) |
| 12 | Below `xl`, drawer holds rail + panel, closes on nav | satisfied statically (`Sheet` renders both; `onNavigate` closes), **not verified** |
| 13 | Wide grid does not push the rail off-screen | satisfied statically (`min-w-0` on `<main>`), **not verified** |
| 14 | `(master)` identical to Phase 1 | satisfied statically — every shared-file change is behind `navSource`/`enabled`, platform paths byte-identical; **not verified visually** |
| 15 | Reverting `(core)/layout.tsx` restores the old shell | satisfied statically (one-line swap; nothing deleted) |

---

## §⑭ Appendix — the two shapes you are joining

### 14.1 `USER_ROLE_MODULES` (rail source, tenant)

```
result: userRoleModules {
  data { moduleId moduleCode moduleName moduleIcon moduleUrl orderBy description isActive isAccessible }
}
```

Filter `isActive && isAccessible`, sort by `orderBy`, map to `ShellRailItem`:
`{ key: moduleCode, label: moduleName, icon: <mapped moduleIcon>, moduleCode, moduleUrl, sections: [] }`
— `sections` are filled by `usePanelMenu`, not by this hook.

### 14.2 `PARENTCHILD_MENU_QUERY` (panel source, tenant)

Returns `ParentChildMenuResponseDto[]` — each node carries `menuName`, `menuCode`, `menuUrl`,
`menuIcon`, `description`, `childMenus[]`. Already RBAC-filtered by the server.

Mapping to `ShellPanelSection[]`: parent → section (`label: menuName`), its `childMenus` → leaves
(`href: menuUrl`, `label: menuName`, `icon: menuIcon`). Grandchildren flatten into the same section
in v1. Prepend the synthetic Dashboard leaf (§6.4).

### 14.3 `(core)/layout.tsx` — exact after

```tsx
return (
  <RouteGuard requireAuth={true}>
    <RoleCapabilityProvider>
      <PlanEnforcementProvider>
        <AppShell navSource="tenant" trans={trans}>{children}</AppShell>
      </PlanEnforcementProvider>
    </RoleCapabilityProvider>
  </RouteGuard>
);
```

Keep the existing comment block explaining why there is no first-login setup gate here — it is still
true and still worth someone's time.

### 14.4 Sizing and tokens

Identical to Phase 1 §14.6: rail 72px, panel 248px (`w-0` collapsed), top bar `h-14` sticky `z-50`,
`<main>` `min-w-0 grow flex flex-col layout-padding p-3 page-min-height`. Active state is a **solid**
`bg-primary` with `text-primary-foreground` — never a tint.
