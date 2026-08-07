# App Shell Redesign — Session Hand-off

**Date:** 2026-08-07
**Status:** Planning COMPLETE. Nothing built. Phase 1 is ready to run.

---

## Paste this to start the next session

> Read `PSS-2.0-APP-SHELL-SESSION-HANDOFF.md` and
> `PSS-2.0-APP-SHELL-PHASE-1-PLATFORM-BUILD-PROMPT.md` at repo root, then build Phase 1.
>
> Planning is done and the decisions in those files are settled — do not re-open them, do not
> re-plan, do not re-explore the shell. Start at §⑧ T-1 and work through T-9 in order.
>
> Frontend only. No backend, no migration, no seed, no SQL. Do not touch `(core)`.

---

## What we decided (settled — do not re-litigate)

**The ask.** Convert the app to a ClickUp-style shell: top bar + narrow icon rail + context panel +
content. Remove the master dashboard and the module navigator from **both** platform and tenant.
Platform UI is **static** (hardcoded TS, only data dynamic); tenant UI stays **fully dynamic**
(DB-driven menus). Routing groups stay separated.

**The hinge finding.** `moduleCode` is the **RBAC partition key**, not a navigation concept. Three
consumers depend on it: `useMenu()` (menu query variable), `RoleCapabilityProvider` (per-module
capability cache), `usePlatformCapabilities` (pins `"PLATFORM"`). So we remove module
**navigation**, never the module **concept**. **Zero backend change.**

**How the module gets set without a launcher:**

| Surface | Mechanism |
|---|---|
| Platform (Phase 1) | Pinned to `"PLATFORM"`. Single-module surface — nothing to switch. |
| Tenant (Phase 2) | Derived from the URL by longest `moduleUrl` prefix — the comparator that already runs at `useAuth/index.ts:66-71`, just on every route change instead of once at login. |

**Rail semantics differ by surface, deliberately:**

| | Platform rail | Tenant rail |
|---|---|---|
| Each icon is | A **section** of one module | A **module** |
| Source | Hardcoded `platform-navigation.ts` | `USER_ROLE_MODULES` |
| On click | `moduleCode` unchanged | `moduleCode` changes |

Both use **one** `AppShell` component with a `navSource: "tenant" \| "platform"` prop. Do not fork it
— the two layouts being deleted are byte-for-byte duplicates and that duplication already cost us a bug.

**Rail click never navigates.** It sets the rail key and swaps the panel; the current screen stays
open behind. Only a panel-leaf click navigates. This is the whole UX win — today a module switch
costs a `router.push` plus a full-screen `ModuleLoader` scrim just to look at a menu list.

**The seven open questions, all resolved:**

| Q | Decision | Why |
|---|---|---|
| Platform IA | 7 rail items: Home · Tenants · Growth · Billing · Comms · Staff · System | Every leaf maps to a `page.tsx` that already exists |
| Seeded PLATFORM menu rows | Leave in DB, dormant for nav | `usePlatformCapabilities` matches on `menu.menuCode` — deleting them breaks platform RBAC |
| `/ops/` + `/platform/` segments | Keep both | Zero URL change, zero `Role.DefaultLandingUrl` reseeding |
| Rail click | Swap panel only | See above |
| Platform Home | Existing `/platform/dashboards` | Already the PLATFORM `ModuleUrl` with a real coded dashboard |
| Tenant top bar | Phase 2 | — |
| Sequencing | Platform alone first | Cannot regress the tenant app |

---

## Phasing

| Phase | Scope | State |
|---|---|---|
| **1** | **Platform shell — `(master)` only** | **READY TO BUILD** |
| 2 | Tenant shell — `(core)`; needs `useActiveModule()` | Not planned in detail |
| 3 | Cleanup: delete `DashBoardLayoutProvider`, `Sidebar`, `ModuleNavigator`, `ModuleLoader`; relocate the master-dashboard KPI widgets | Not started |

`useActiveModule()` was originally Phase 0. It moved to Phase 2 — Phase 1 pins `PLATFORM` and does
not need a route→module resolver.

---

## Files

| File | State |
|---|---|
| `PSS-2.0-APP-SHELL-REDESIGN-APPROACH.md` | The approach doc, §⓪–⑬. Background. |
| `PSS-2.0-APP-SHELL-PHASE-1-PLATFORM-BUILD-PROMPT.md` | **The build prompt.** §⑭ appendix has literal code for every new file. |
| This file | Hand-off. |

Nothing in `PSS_2.0_Frontend/` has been modified. Working tree carries only the unrelated changes
listed in git status.

---

## Start here

`PSS-2.0-APP-SHELL-PHASE-1-PLATFORM-BUILD-PROMPT.md` §⑧, tasks T-1 → T-9 in order:

1. **T-1** `platform-navigation.ts` — copy §14.1 verbatim
2. **T-2** `app-shell-store.ts` + `app-shell-istore.ts` — §14.3
3. **T-3** `AppTopbar`, `AppRail`, `ContextPanel`, `useRailItems`, `AppShell` — §⑥
4. **T-4** `masterdashboard/page.tsx` → redirect — §14.5
5. **T-5** move `command-palette.tsx` into `layout-components/`
6. **T-6** rewrite `(master)/layout.tsx` — §14.4
7. **T-7** delete `(master)/ops/layout.tsx` + `(master)/platform/layout.tsx`
8. **T-8** delete `pages/master/landing-page/` (17 files) — **grep for imports first; if anything
   outside `masterdashboard` imports it, stop and report rather than guess**
9. **T-9** `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` — **only exit 0 counts**

Then verify against §⑨ acceptance (12 items). The two that matter most: **#3** rail click must not
change the URL, and **#9** `(core)` must be byte-identical — `/en/crm/...` still renders the tenant
sidebar with a working module navigator.

---

## Traps that will bite (full list in §⑪)

1. Unconditional `setModuleCode("PLATFORM")` re-fires `RoleCapabilityProvider`'s query every render —
   compare before writing.
2. `Header` is **not** reusable — it imports `ModuleNavigator` and branches on
   `layout`/`sidebarType`/`navbarType`. Build `AppTopbar` fresh; reuse only `ProfilePopover`,
   `ThemeButton`, `FullScreen`, `NotificationsPanel`.
3. `usePlatformCapabilities` filters to **one** `menuCode`. The rail needs codes across all menus —
   extend that hook with an optional `menuCode`; do not duplicate the query.
4. `/ops/onboarding` has **no** `page.tsx`. Only `/ops/onboarding/provision`.
5. Do **not** touch `MenuLoader`'s commit-gated scrim. Copy it byte-for-byte. A blind timer drops the
   scrim while the old screen is still mounted.
6. `MASTER_URL = "/en/masterdashboard"` — hardcoded `en`, pre-existing, **leave it**. The redirect
   route makes it harmless. Three consumers: `useAuth` null-landing fallback, `route-guard`, and
   `company-switcher-item.tsx:85` (`window.location.href`).
7. Only 4 platform menus are seeded, carrying 10 `PLATFORM_*` capabilities. **11 of ~19 routes have
   no capability gate.** `requiredCapability` is therefore optional. Do **not** invent codes, do
   **not** write a seed — record the gap in §⑬.
8. Content area needs `min-w-0` or wide data grids push the rail off-screen.

---

## Standing constraints (unchanged, still binding)

- No raw SQL execution in application code (`ExecuteSqlRawAsync` / `FromSqlRaw`). Hand-written `.sql`
  under `sql-scripts-dyanmic/` that the user applies is the permitted channel.
- Do **not** run `dotnet build` — the user builds the backend.
- Migrations are strictly user-owned: never run `dotnet ef migrations add/remove` or
  `database update`, never hand-author a migration or snapshot.
- Do not call the Agent tool, workflows, or deep-research unless asked.
- `PSS_2.0_Backend/` and `PSS_2.0_Frontend/` are gitignored → the Grep **tool** returns zero for
  backend `.cs`. Repo-wide Bash greps time out at 120s — **use the Grep tool for frontend paths.**
- Frontend typecheck: `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, no pipe. Only
  exit 0 counts. >10 min → background.
- Solid accents on active nav items and badges: `bg-primary` + `text-primary-foreground`. Never
  `bg-X-50/100`, `text-X-700/800`, `bg-muted`, or `text-muted-foreground` for an active state.
- Tokens only — no raw hex, no raw px (the four zone widths in §14.6 are the sole exception).
- HotChocolate strips `Get` from every resolver and appends `Input` to input types. **tsc cannot see
  GraphQL field names** — a wrong name compiles clean and fails at runtime only.

---

## Unrelated work still parked (do not start unprompted)

- `PSS-2.0-ONBOARDING-PROMPT-09-PLATFORM-COMMS-CRUD.md` (T-A15) — unblocked, buildable, but it would
  land on whatever shell Phase 1 produces. **Run it after Phase 1.**
- User-owed prerequisites unchanged: the tenant-setup backfill script, the email-provider migration +
  its §⑨ Q2 (platform sending domain — hard blocker), and the 7-step menu/baseline seed chain.
