# PSS 2.0 — App Shell Phase 3: Retire the Legacy Shell

**Scope:** frontend only (`PSS_2.0_Frontend`). Removal and sweep — **no new UI, no new behaviour.**
**Predecessors:** Phase 1 (platform shell), Phase 2 (tenant mount), Phase 2.1 (landing + identity fixes, commits `fefb60b2` `5ede0f74` `1ab91a5d` `dc4cc06a`).

---

## ① Why this phase exists

Phase 2 mounted the tenant routes on `AppShell` by **unmounting** `DashBoardLayoutProvider`, not by deleting it. That was deliberate — it left a one-line revert path in `(core)/layout.tsx` while the new shell was unproven. That revert path has now been paid for twice over: 2.1 fixed the four defects the mount exposed, and the shell has been driven by a real tenant login.

Phase 3 burns the revert path. After it, `DashBoardLayoutProvider` and its sidebar cluster no longer exist, and the dead `isModuleLoading` plumbing stops being copied into every new screen by pattern-matching.

**Assumption, stated because it was not answered:** Phase 3a runs immediately once 2.1 acceptance passes on a running dev server — no calendar soak. If 2.1 acceptance has **not** been exercised on a dev server yet, run it first (§9 of the Phase 2 prompt + the 12 points of the 2.1 prompt). Do not delete on the strength of a clean `tsc` alone.

**Second assumption:** the §③ platform KPI widgets from the old `pages/master/landing-page/` stay dead. That directory was already removed in Phase 1 and nothing references it. Do not rebuild them here.

---

## ② Constraints (hard)

1. **Frontend only.** No backend change, no migration, no seed, no SQL, no `auth.Modules` / menu / capability data change.
2. **No URL changes.** No route is added, removed, or renamed. `/ops/` and `/platform/` both stay.
3. **No behaviour change.** Every deletion in 3a is of code that is already unreachable at runtime. If removing something changes what the user sees, it is not in scope — stop and report it.
4. **`BaseUrlConfig.ts` is user-managed** (port toggling). Do not touch it, do not revert it, do not include it in any commit.
5. `(member)` / `(public)` / `(setup)` / `(auth)` route groups are untouched.
6. **`MenuLoader` and its commit-gated scrim logic in `AppShell` are not in scope.** `menu-loader/` stays.
7. **`AppLoader` stays** — it is used across ~200 page files. Only its *import path* changes (§3a.5).
8. `route-guard.tsx` is **out of scope** — see §⑤.
9. Delete in the order given. Each step must end at a clean `npx tsc --noEmit`; do not batch all deletions and typecheck once.

---

## ③ Phase 3a — deletion

Every target below was re-verified against the working tree on 2026-08-08. Counts and consumer lists are current; re-run each grep before deleting, because 2.1's uncommitted work may have moved something.

### 3a.1 — `presentation/provider/dashboard-layout-provider.tsx`

**Verified dead.** The only remaining hit for `dashboard-layout-provider|DashboardLayoutProvider` in `src/` is a *comment* in `sidebar/common/use-menu-navigation.ts:26`. `(core)/layout.tsx` renders `AppShell` and no longer imports it.

Delete the file. Then update the stale comment block in `(core)/layout.tsx` (the one that says *"`DashBoardLayoutProvider` and its sidebar cluster are only UNMOUNTED, not deleted (Phase 3 removes them), so this phase reverts by putting that one component back on this line"*) — that sentence is now false and it is the single most misleading comment in the file.

This file is the **root of the whole cascade**: it is the sole consumer of `Header`, `Sidebar`, `MobileSidebar`, `HeaderSearch`, `ModuleLoader`, and `useThemeCustomization`. Delete it first and the rest of 3a becomes provable rather than argued.

### 3a.2 — `presentation/components/layout-components/sidebar/` (33 files)

**Verified dead once 3a.1 lands.** Zero imports of `layout-components/sidebar` exist outside the directory itself. Delete the whole directory, then remove `export * from "./sidebar";` from `layout-components/index.tsx`.

Note `sidebar/common/use-menu-search.ts` — confirm `global-search` / the command palette does not reach into it before deleting. If it does, hoist that one file to `presentation/hooks/` and delete the other 32.

### 3a.3 — `layout-components/module-loader/` (2 files)

**Verified dead.** The only remaining `ModuleLoader` hits after 3a.1 are: the two files themselves, the barrel export, a *comment* in `app-shell-provider.tsx`, and a *comment* in `ops/platform-dashboard/platform-dashboard-page.tsx:91`. No live import.

Delete the directory, drop `export * from "./module-loader";` from the barrel, and fix the two comments so they do not name a component that no longer exists.

### 3a.4 — legacy header/footer chrome (per-file, **not** per-directory)

`layout-components/header/` is **mixed**: it still holds `profile-popover/`, `logout.tsx`, `language.tsx`, `theme-button.tsx`, `full-screen.tsx`, `inbox.tsx` — several of which `app-topbar` reuses. **Do not delete the directory.**

Delete only the files that go dead with 3a.1, each confirmed by its own grep first:

| Candidate | Why |
|---|---|
| `header/header.tsx` | the old branching header; `app-topbar/index.tsx:22` explicitly documents that it replaced it |
| `header/vertical-header.tsx` | imported only by `header/header.tsx` |
| `header/horizontal-header.tsx`, `header/horizontal-menu.tsx` | layout modes the new shell does not have (INV-1: no `layout`/`sidebarType` reads) |
| `header/mobile-menu-handler.tsx` | drove the old mobile sidebar; `AppShell` uses a `Sheet` |
| `layout-components/search/header-search.tsx` | `HeaderSearch` had exactly one consumer — 3a.1 |
| `layout-components/footer/*` | zero live imports of `footer/footer` today; confirm `footer-layout` / `mobile-footer` are likewise unreferenced |

For anything in that table whose grep comes back **non-empty**, leave it and say so in the build log. A file that turns out to still be reachable is a finding, not an obstacle to work around.

Update `layout-components/index.tsx` for each barrel line that now points at nothing.

### 3a.5 — `custom-components/module-navigator/` — **partial**

Three files. The component is dead; the utils are **not**.

- `index.tsx` (`ModuleNavigator`) — sole consumer is `header/header.tsx`, deleted in 3a.4. **Delete.**
- `module-navigator-item.tsx` — imported only by `index.tsx`. **Delete.**
- `utils.tsx` — **KEEP.** Three live consumers: `app-loader/AppLoader.tsx:4`, `role-capabilities-editor/rce-module-listbox.tsx:18`, `staff-wizard/staff-role-access-viewer.tsx:17` (`getModuleIcon`, `getModuleColor`, `colorList`).

Move `utils.tsx` to a neutral home — `presentation/components/custom-components/module-visuals/index.tsx` or `application/utils/module-visuals.tsx` — and repoint those three imports. Leaving a folder called `module-navigator` that contains no navigator is how the next person re-adds one.

### 3a.6 — `MASTER_URL`

`CommonUrlConfig.ts:3` = `"/en/masterdashboard"`. After 2.1's F-3 repointed `company-switcher-item.tsx`, the remaining hits are: the definition, the barrel re-export, and **comments** in `masterdashboard/page.tsx`, `route-guard.tsx`, and `company-switcher-item.tsx:92`.

Since `route-guard.tsx` is out of scope (§⑤) and still *imports* the symbol inside commented-out code, deleting `MASTER_URL` means editing a file this phase is not supposed to own. **Leave `MASTER_URL` in place** and note it in the build log as blocked on the route-guard decision. It is one unused constant; it is not worth widening the blast radius.

**Keep `(master)/masterdashboard/page.tsx`.** It is a live redirect and old bookmarks/tokens still land on it.

---

## ④ Phase 3b — the `setModuleLoading` / `sidebarType` sweep

Different risk profile from 3a, and this is the part to be careful with: **`tsc` will not catch a mistake here.** Removing a `setModuleLoading(false)` call from a screen that still *raises* the scrim leaves a loader that never lowers. The failure is a runtime hang on one screen, discovered by a user.

### 3b.1 — `setModuleLoading` (**56 files**)

The store fields survived Phase 2 precisely so these call sites kept compiling. `AppShell` never raises `isModuleLoading` — there is no launcher left to cover — so every one of these 56 is lowering a scrim that is already down.

Sweep order, and do not deviate:

1. **First** confirm nothing raises it: `grep -rn "setModuleLoading(true"` must return **zero** hits outside the store. If it returns anything, stop — that screen still depends on the old behaviour and the sweep is not safe yet.
2. Remove `setModuleLoading` from each destructure and each `setModuleLoading(false)` call, plus the symbol from the surrounding `useEffect` dependency arrays. `isModuleLoading` / `loadingModuleName` reads go with it.
3. `custom-components/dashboards/index.tsx:130,294,297` is the one non-mechanical case — it *reads* `isModuleLoading` in an effect condition, so deleting the read changes when that effect runs. Do this file by hand and re-read the effect after editing.
4. **Last**, remove `isModuleLoading`, `loadingModuleName`, and `setModuleLoading` from `global-istore.ts` (lines 7, 9, 26) and `global-store.ts` (13, 15, 29). Doing the store last means `tsc` lists every site you missed.

`data-table-fetch-data.tsx` (flow **and** advanced) is the highest-traffic pair — both are shared by nearly every grid screen. Verify a grid screen still lowers its `isMenuRendering` scrim after the edit; `setIsMenuRendering` **stays**.

### 3b.2 — `sidebarType` (**17 files**)

Three tiers, treat them differently:

- **Delete the reads** in files that survive: `app-topbar/index.tsx`, `footer/footer.tsx` (if it survives 3a.4), `useThemeCustomizer/useThemeCutomization.ts`, `app-shell-provider.tsx` (comment only — reword). INV-1 says the shell reads none of these.
- **Deleted by 3a**, so nothing to do: `sidebar/common/logo.tsx`, `sidebar/sidebar.tsx`, `header/header.tsx`, `header/vertical-header.tsx`, `dashboard-layout-provider.tsx`.
- **Leave alone**: `ThemeConfig.ts`, `layout-store.ts`, `sidebar-istore.ts`, `sidebar-store.ts`, `app-shell-istore.ts` and `customizer/*`. The customizer is a user-facing settings panel; stripping its options is a **UX change**, not dead-code removal, and §②.3 forbids it. If the sidebar options in `customizer/sidebar-change.tsx` now control nothing, **report that as a finding** and leave the code — a follow-up decides whether the panel loses a section.

---

## ⑤ Explicitly out of scope

- **`presentation/components/auth/route-guard.tsx`.** It is commented out end to end (`return <>{children}</>`) yet still wraps `(core)`, `(master)`, and `(setup)`. It is dead *logic* inside a live *component*, and it is the last marker that those three route groups have no client-side auth gate at all. Deleting it is a security decision, not a cleanup. Leave it; raise it as a Phase 4 item.
- **The §③ platform KPI widgets.** Already gone since Phase 1, staying gone.
- **`layout-loader/`, `menu-loader/`, `common-loader/`, `AppLoader`.** All live.

---

## ⑥ Carry-over from 2.1 — F-5 was not built

Verified on the working tree: the four 2.1 commits map to F-1, F-2, F-3, F-4. **No commit corresponds to F-5**, and `usePanelMenu/index.ts:167` still mutates `lastGoodRef.current` **during render** — the original defect, untouched. The three uncommitted files (`app-rail`, `context-panel`, `app-shell-provider`) are small styling/behaviour edits, not F-5.

F-5 does not conflict with Phase 3 — it lives in `usePanelMenu` and `module-url-match`, neither of which 3a deletes — so the two can proceed in parallel. But **it must not be dropped.** Re-read §F-5 of `PSS-2.0-APP-SHELL-PHASE-2.1-LANDING-AND-IDENTITY-FIX-PROMPT.md` and land its four defects (render-phase ref mutation → `useEffect`; the `sections.length > 1` heuristic that must count **leaves** not sections; the unsorted tier-2 `.find()` in `matchModuleByUrl`; preview/route reconciliation of `activeRailKey` on commit) either before Phase 3 or alongside it.

**Commit the three dirty shell files, or revert them, before starting 3a** — do not begin deleting files with uncommitted shell work in the tree. `BaseUrlConfig.ts` stays dirty and uncommitted (§②.4).

---

## ⑦ Acceptance

Run on a dev server with a real tenant login **and** a platform login. `tsc` is necessary, not sufficient.

1. `npx tsc --noEmit` clean after **each** of 3a.1 → 3a.5, not just at the end.
2. `npm run build` clean.
3. `grep -rn "dashboard-layout-provider\|DashBoardLayoutProvider\|layout-components/sidebar\|module-loader" src/` returns nothing but intentional prose.
4. `grep -rn "setModuleLoading\|isModuleLoading\|loadingModuleName" src/` returns **zero** hits.
5. Tenant login → lands on a tenant module, rail shows that user's modules, panel shows that module's menu. Unchanged from 2.1.
6. Platform login → rail shows the capability-filtered seven items. Unchanged from Phase 1.
7. **Menu click on a grid screen raises the scrim and the scrim comes down** — flow grid and advanced grid, one each. This is the specific thing 3b.1 can break.
8. Dashboard screen (`custom-components/dashboards`) loads and renders widgets — the one hand-edited file in 3b.1.
9. Module switch via rail click still previews the other module's panel without navigating (INV-8).
10. Mobile (<1280px) drawer opens, rail + panel render inside it, a leaf click navigates and closes it.
11. The theme customizer opens without error, whatever its sidebar options now do.
12. No console error naming a missing module, and no 404 on a chunk.

---

## ⑧ Deliverable

- One commit per numbered step (`3a.1`, `3a.2`, …, `3b.1`, `3b.2`), each independently revertable. A single "Phase 3 cleanup" commit touching 100+ files is not acceptable — if acceptance point 7 fails, the bisect has to be cheap.
- A build log appended to this file: what was deleted, what was **kept** and why (each non-empty grep from 3a.4), the `setModuleLoading` file count actually touched, and any acceptance point not exercised.
- Report `MASTER_URL` and the customizer sidebar options as open findings, not as done work.

---

## ⑨ Build log — 2026-08-08

Executed in `PSS_2.0_Frontend`, branch `module/case`. **Frontend only.** No backend file, migration, seed, SQL, or `auth.Modules` row was touched. No route added, removed, or renamed — `/ops/` and `/platform/` both still resolve. `BaseUrlConfig.ts` left exactly as the user has it.

### 3a — deletions

| Step | Result |
|---|---|
| 3a.1 | `provider/dashboard-layout-provider.tsx` deleted. `(core)/layout.tsx` comment rewritten — it claimed a one-component revert path back to the legacy shell that no longer exists. |
| 3a.2 | `layout-components/sidebar/` deleted whole — **33 files**. `useMenuSearch` and `useMenuNavigation` were grepped first and had zero consumers outside that directory. |
| 3a.3 | `layout-components/module-loader/`, `footer/`, `search/` deleted whole. |
| 3a.4 | `header/` split per-file. See "kept" below. |
| 3a.5 | `custom-components/module-navigator/` deleted; its `utils.tsx` `git mv`'d to `custom-components/module-visuals/index.tsx` (it is the only home of `moduleIconMap` / `getModuleIcon` / `getModuleColor` / `colorList`). Three importers repointed: `AppLoader.tsx`, `staff-role-access-viewer.tsx`, `rce-module-listbox.tsx`. |

`layout-components/index.tsx` was rewritten to drop the re-exports of everything above. `AppLoader` stays (≈200 page files import it) — only its `module-visuals` import path moved.

**Kept, with the grep that justified it (3a.4):**

- `header/profile-popover/`, `header/theme-button.tsx`, `header/full-screen.tsx` — live. Imported by `app-topbar/index.tsx:15-17` and `app-rail/index.tsx:21`. These are the shared right-hand icon cluster; only the branching `header.tsx` wrapper was dead.
- `header/logout.tsx`, `header/language.tsx`, `header/inbox.tsx` — **orphaned but kept.** Zero importers, but they are not in §③'s deletion table and deleting them was not authorised. Reported as a finding below.
- `mapMenuToMainConfig` — its only barrel import was in `horizontal-menu.tsx`, which 3a.4 deleted, so nothing had to be spared.
- `skeleton-preview.tsx`'s `<Footer />` is a **file-local function**, not `layout-components/footer` — checked before 3a.3.

**Deleted beyond the table, as "goes dead with 3a.1":** `header/layout/classic-header.tsx` and `header/profile-info.tsx`. Both were imported only by `header.tsx`.

### 3b.1 — module scrim

Safety gate cleared first, as §④ requires: the two `setModuleLoading(true` raisers were `module-navigator/module-navigator-item.tsx:39` and `sidebar/module/menu-item.tsx:97` — **both inside 3a's deletion set**. After 3a landed, nothing in the tree could raise the scrim, so removing the lowerers could not strand it.

The prompt's count of 56 files was slightly stale: the working tree had **53**, because 3 lived in files 3a had already deleted. **50 were swept mechanically** (a 4-pass regex script: selector form, own-line destructure member, inline destructure/dep-array member, standalone `setModuleLoading(false);` statement) and **1 was hand-edited** — `custom-components/dashboards/index.tsx`, called out by name in §④. There:

- the dead `ModuleLoadingOverlay` component was removed (it carried a shipped debug bug: `Loading {moduleName + "asasasasa" || "Module"}`);
- the `useEffect` whose entire body was `setModuleLoading(false)` was removed;
- the commented-out `if (isModuleLoading) { <ModuleLoadingOverlay/> }` early-return was removed;
- **`dashboardModuleLoading` was NOT touched** — it is an unrelated Apollo `loading` alias whose name merely rhymes, and the `setIsMenuRendering(false)` effect beside it is the live scrim handoff.

The three store members (`isModuleLoading`, `loadingModuleName`, `setModuleLoading`) came out of `global-istore.ts` and `global-store.ts` **last**, so `tsc` would have named any missed call site. It named none. Acceptance point 4 verified: `grep -rn "setModuleLoading\|isModuleLoading\|loadingModuleName" src/` → **zero hits**. `isMenuRendering` / `setIsMenuRendering` untouched throughout.

### 3b.2 — `sidebarType`

Only one real read survived 3a: `useThemeCustomizer/useThemeCutomization.ts` destructured `sidebarType` and returned it. Removed from both; the **write** (`setSidebarType(...)` inside `applySettings`) was left so the org setting still round-trips into the store. The `sidebarType` mentions in `app-topbar/index.tsx:23` and `app-shell-provider.tsx:28` are prose stating the INV-1 invariant ("the shell does not read these") — still accurate, so left as written rather than reworded into something weaker. `ThemeConfig.ts`, `layout-store.ts`, `sidebar-istore.ts`, `sidebar-store.ts`, `app-shell-istore.ts` and all of `customizer/*` untouched, per §③.

### Verification

- `npx tsc --noEmit` — clean after each step and at the end.
- `npm run build` — **clean, exit code 0** (run against the post-3b tree).
- Acceptance 3 and 4 — verified by grep, zero hits.
- **Acceptance 5, 6, 7, 8, 9, 10, 11, 12 were NOT exercised.** They need a running app and a login on both a tenant and the platform. Point 7 (menu click on a flow grid and an advanced grid raises the scrim *and lowers it*) is the specific thing 3b.1 could break and should be the first manual check.

### Anomaly worth recording

Partway through 3a, `tsc` reported syntax errors (TS1109/TS1382/TS1381/TS1005/TS1128/TS1003) in `context-panel/index.tsx` and `app-shell-provider.tsx` that **were not caused by these deletions**. The committed state at merge `9ed813ab` / `a1c82a3e` contained duplicated code blocks — duplicate imports, duplicate `useEffect` bodies, duplicate destructures — and an external process was de-duplicating three files (`app-rail/index.tsx`, `context-panel/index.tsx`, `app-shell-provider.tsx`) concurrently: mtimes were seconds old, `tsc` line numbers shifted between consecutive runs, and the error count fell 6 → 1 → 0 on its own. That repair landed as `cf794ed4`. Separately, an external commit `8fd3ef85` ("feat: remove unwanted files") swept up part of the 3a deletions. Neither commit was made by this session.

### Open findings — not done work

1. **`MASTER_URL`** — still blocked on the `route-guard.tsx` decision, which §⑤ puts out of scope. Phase 4.
2. **Customizer sidebar options are now inert.** `customizer/sidebar-change.tsx` still offers sidebar-layout choices that no rendered component reads. Worse: the whole `layout-components/customizer/*` panel and the `useThemeCustomization` hook have **zero mount points anywhere in `src/`** — the hook's only caller was `dashboard-layout-provider.tsx`. That means the org-configured theme name / radius / direction are not being applied at runtime either, and the chart widgets that read `useThemeStore().theme` fall back to `ThemeConfig` defaults. This predates Phase 3 (the `(core)` layout stopped mounting the legacy provider back in Phase 2) — Phase 3 only made it visible. Deciding whether the customizer gets re-mounted or retired is a UX call, not dead-code removal.
3. **`header/logout.tsx`, `header/language.tsx`, `header/inbox.tsx`** — orphaned, kept because they are outside the authorised deletion table. Candidates for Phase 4.
4. **F-5 from Phase 2.1 was never built.** Specifically: `usePanelMenu/index.ts:167` mutates `lastGoodRef.current` during the render phase; `sections.length > 1` counts sections rather than leaves; `matchModuleByUrl` uses an unsorted tier-2 `.find()`; and `activeRailKey` preview/route reconciliation is unresolved. None of it is Phase 3 scope, but it is still open.

### Deliverable deviation

§⑧ asks for one commit per numbered step. **Nothing was committed by this session** — the instruction was "don't commit", and the standing rule is stage-only. Changes are staged as a single working set; splitting into per-step commits is available on request.

---

## ⑩ Follow-on — shell accent colour (module bar), 2026-08-08

Not part of Phase 3. Requested separately: *"add primary color to module bar — platform side static (logo colour), tenant side from organization settings."*

**One source of truth, two feeds.** `useShellAccent(navSource)` (`presentation/hooks/useShellAccent/index.ts`) resolves:

| Source | Accent |
|---|---|
| Platform | `PLATFORM_ACCENT = #43436F` — the login page's background colour (`getDefaultLoginConfig().primaryColorHex`, the base of the login hero's `--brand-primary → --brand-secondary` gradient), **static by design**. The control plane must look the same whichever tenant an operator is inspecting, so it is deliberately not configurable. |
| Tenant, brand colour set | `useBrandingStore().primaryColorHex` (`PRIMARY_COLOR_HEX`, Branding setting group), validated against `/^#(?:[0-9a-f]{3}\|[0-9a-f]{6})$/i` and expanded from the 3-digit form. |
| Tenant, no brand colour | `hsl(var(--primary))` — i.e. **no visual change from before**. |

It publishes `--shell-accent` / `--shell-accent-foreground` on `documentElement` rather than returning class names, because the same colour has to reach `glass-bar` and the profile-popover trigger, neither of which is on the shell's render path. `globals.scss` seeds both variables with the theme primary inside `:root`, so every consumer is valid before the hook runs and during the frame before branding hydrates.

The foreground is **derived, not assumed**: a tenant may configure a pale brand colour, and white-on-pale is unreadable, so `useShellAccent` computes WCAG relative luminance and picks `#ffffff` or `#111827`. Every rail state is then a `color-mix` of the accent and that foreground — a hardcoded `white/15` hover would vanish on a light accent.

**Painted:**
- `app-rail` — the `<nav>` surface (was `bg-card`), the idle/hover/active item states, the loading skeleton, the "More" trigger, the overflow-popover active row, the bottom divider and the Help link. Active state keeps the house rule (solid, never a tint) read back onto an accent ground: solid foreground-coloured pill, accent-coloured glyph.
- `glass-bar` — `GLASS_TINT` moved from `bg-primary/95` to `color-mix(in srgb, var(--shell-accent) 95%, transparent)`. `color-mix` rather than a `/95` opacity modifier because Tailwind cannot apply one to a `var()` whose colour space it does not know at build time. This is what keeps the rail and the topbar one continuous band instead of going two-tone the moment a tenant's brand colour differs from the theme primary.
- `app-shell-provider` — the rail's outer border now uses the exported `RAIL_EDGE`; a neutral `border-border` hairline against a saturated accent read as a rendering seam.
- `profile-popover` desktop trigger — initials avatar + caret moved off `primary` onto the accent vars.

**Not changed, deliberately:** the topbar's `white/10` · `white/15` · `ring-white/30` overlays. They are already relative-to-surface and behave correctly on any dark accent; on a very pale tenant brand colour they will read faint. Worth revisiting only if a tenant actually configures one.

`npx tsc --noEmit` clean. Frontend only — no backend, migration, seed or route touched. Staged, not committed.
