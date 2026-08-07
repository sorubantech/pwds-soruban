# PSS 2.0 — App Shell Phase 1: Static Platform Shell (ClickUp-style)

**Status:** NOT BUILT
**Scope:** Frontend only. **No backend change, no migration, no seed, no SQL.**
**Blast radius:** `(master)` only. `(core)` / `(member)` / `(public)` / `(setup)` / `(auth)` are untouched.
**Parent plan:** `PSS-2.0-APP-SHELL-REDESIGN-APPROACH.md`
**Model:** Sonnet (this prompt is fully specified).

---

## §⓪ Why this exists

The platform control plane currently borrows the **tenant** shell. Both
`(master)/ops/layout.tsx` and `(master)/platform/layout.tsx` are byte-for-byte identical and both
mount `DashBoardLayoutProvider`, whose comments state they exist so *"the PLATFORM module's seeded
menus (Tenants / Leads / Plans / Audit) actually render"* through `useMenu()`.

That coupling has already cost us a bug, recorded in `dashboard-layout-provider.tsx`'s own comments:
the full-screen `ModuleLoader` scrim had nothing to lower it over the fixed-code platform dashboard,
so it stayed up forever over a page that had rendered fine.

Phase 1 severs it. The platform gets a **static, hardcoded, ClickUp-style shell** — icon rail +
context panel + top bar — that never calls `useMenu()` and never reads tenant theming. Only its data
is dynamic.

**Decisions already made — do not re-open them:**

| Q | Decision |
|---|---|
| Platform IA | The seven-item rail in §⑥.2, exactly as written. |
| Seeded PLATFORM menu rows | **Left in the DB.** Dormant for navigation, live for RBAC. Do not touch them. |
| `/ops/` vs `/platform/` segments | **Both kept.** No URL changes anywhere. |
| Rail click behaviour | **Swaps the context panel only. Never `router.push()`.** |
| Platform Home | The existing `/platform/dashboards`. No new dashboard screen in Phase 1. |
| Tenant shell | **Phase 2. Out of scope here.** |

---

## §① Read first (grounding)

Read these before writing anything. Every fact below was verified on disk.

| File | What to take from it |
|---|---|
| `src/presentation/provider/dashboard-layout-provider.tsx` | The shell being replaced on `(master)`. Copy its `MenuLoader` commit-gated scrim logic and its `motion` page transition **verbatim**; drop everything else. |
| `src/app/[lang]/(master)/layout.tsx` | Currently bare: `RouteGuard requireAuth` + `CompanySettingsBootstrap` + children. This is where the new shell mounts. |
| `src/app/[lang]/(master)/platform/layout.tsx` + `ops/layout.tsx` | The two duplicates being deleted. |
| `src/presentation/provider/access-provider.tsx` | `RoleCapabilityProvider` reads `moduleCode` from `useGlobalStore` and caches capabilities per module. **This is why §⑤ INV-2 exists.** |
| `src/presentation/hooks/usePlatformCapabilities/index.ts` | `PLATFORM_MODULE_CODE = "PLATFORM"`; matches granted codes on `menu.menuCode`. |
| `src/presentation/components/layout-components/glass-bar.ts` | `GLASS_BAR` / `GLASS_SEAM`. Reuse for the top bar. |
| `src/presentation/components/layout-components/header/profile-popover/index.tsx`, `theme-button.tsx`, `full-screen.tsx` | Self-contained top-bar controls to reuse. |
| `src/presentation/components/custom-components/notifications-panel/` | The bell. Reuse. |
| `src/presentation/pages/master/landing-page/command-palette.tsx` | Promoted into the new top bar. |
| `src/application/configs/navigation-configs/CommonUrlConfig.ts` | `MASTER_URL = "/en/masterdashboard"`. Three consumers — see §⑧ T-4. |

**Verified conventions — follow exactly:**
- Zustand stores: `src/application/stores/<domain>-stores/<name>-store.ts` **paired with**
  `<name>-istore.ts` holding the interface. `src/presentation/store/` **does not exist**.
- Providers: `src/presentation/provider/` (singular).
- Icons: `@iconify` Phosphor via `DynamicIcon` (`@/presentation/components/icons/iconify-icon-list`).
- Tokens only — no raw hex, no raw px in classNames. Use the existing spacing/colour tokens.

---

## §② Reuse — do not rebuild

Reuse as-is: `RouteGuard`, `CompanySettingsBootstrap`, `RoleCapabilityProvider`, `ModalProvider`,
`MenuLoader` (+ its commit-gated backstop logic), `HeaderSearch`, `ProfilePopover`, `ThemeButton`,
`FullScreen`, `NotificationsPanel`, `CompanySwitcher`, `DynamicIcon`, `ScrollArea`, the `motion`
page-transition block, `GLASS_BAR` / `GLASS_SEAM`.

Do **not** reuse on `(master)`: `DashBoardLayoutProvider`, `Header` (it renders `ModuleNavigator` and
branches on `layout`/`sidebarType`/`navbarType`), `Sidebar` and all its variants, `ModuleLoader`,
`ModuleNavigator`, `MobileSidebar`, `PlanStatusBanner` / `PlanStatusChip`, `useBranding`,
`useThemeCustomization`'s `layout`/`sidebarType`.

---

## §③ Data model — NO CHANGE

Nothing. No entity, no migration, no seed, no GraphQL schema change, no new query. The only network
calls the shell makes are ones that already exist (`ROLECAPABILITIES_BY_USER_QUERY` via
`RoleCapabilityProvider`).

---

## §④ Backend — NO CHANGE

Nothing.

---

## §⑤ Invariants

- **INV-1 — the platform shell never calls `useMenu()`, `useBranding()`, or reads
  `sidebarType` / `layout` / `navbarType`.** It is static by definition and must not regain a DB
  dependency. If you find yourself needing one, stop and flag it.
- **INV-2 — RBAC is unchanged.** `moduleCode` is the RBAC partition key on the client
  (`RoleCapabilityProvider`) and the backend. The shell must **pin `moduleCode = "PLATFORM"`** on
  `(master)`, so `RoleCapabilityProvider` and `usePlatformCapabilities` resolve exactly as they do
  today. No capability check moves to the client. No hardcoded permission logic.
- **INV-3 — a rail item the user has no capability for is ABSENT, never shown disabled.**
- **INV-4 — no URL changes.** `(master)` parentheses never appear in the path, so `/en/ops/...` and
  `/en/platform/...` stay byte-identical. No route file moves.
- **INV-5 — rail click never navigates.** It sets the selected rail key in the shell store and swaps
  the context panel. The content area keeps rendering the current page.
- **INV-6 — one shell component.** `AppShell` takes `navSource: "tenant" | "platform"`. Phase 1
  implements the `"platform"` branch fully and leaves the `"tenant"` branch as an explicit
  `throw new Error("navSource=tenant lands in Phase 2")` stub. Do **not** fork the file — the two
  layouts being deleted are byte-for-byte duplicates and that duplication already cost us.
- **INV-7 — `(core)` is not touched.** Not one file under `(core)`, not `DashBoardLayoutProvider`,
  not `Sidebar`, not `ModuleNavigator`. They stay alive and in use by the tenant surface.

---

## §⑥ Frontend

### 6.1 Files

**Create:**

| Path | Contents |
|---|---|
| `src/application/constants/platform-navigation.ts` | The static platform IA (§6.2). Typed, exported const + the `PlatformRailItem` / `PlatformPanelSection` / `PlatformPanelLeaf` types. |
| `src/application/stores/shell-stores/app-shell-store.ts` | Zustand: `activeRailKey`, `panelCollapsed`, setters. |
| `src/application/stores/shell-stores/app-shell-istore.ts` | The paired state interface. |
| `src/presentation/provider/app-shell-provider.tsx` | `AppShell`. Client component. |
| `src/presentation/components/layout-components/app-rail/index.tsx` | Zone 1. |
| `src/presentation/components/layout-components/context-panel/index.tsx` | Zone 2. |
| `src/presentation/components/layout-components/app-topbar/index.tsx` | Zone 0. |
| `src/presentation/hooks/useRailItems/index.ts` | Capability-filters `PLATFORM_NAVIGATION` into renderable rail items. |
| `src/app/[lang]/(master)/masterdashboard/page.tsx` | **Replaced** by a redirect (§⑧ T-4). |

**Modify:** `src/app/[lang]/(master)/layout.tsx`, `src/application/stores/index.ts` (export the new
store), `src/presentation/components/layout-components/index.tsx` (export the new components).

**Delete:** `src/app/[lang]/(master)/ops/layout.tsx`, `src/app/[lang]/(master)/platform/layout.tsx`,
`src/presentation/pages/master/landing-page/` **except** `command-palette.tsx` (see §⑧ T-5) —
and only after T-5 has moved it.

### 6.2 `platform-navigation.ts` — the static IA

Seven rail items. **Every leaf below maps to a route file that already exists** (verified):

| Rail key | Label | Icon | Panel section → leaves (href) |
|---|---|---|---|
| `home` | Home | `ph-house` | Overview → `/platform/dashboards` |
| `tenants` | Tenants | `ph-buildings` | Tenants → `/ops/tenants` · Provisioning runs → `/ops/tenants/provisioning-runs` · Tenant access → `/ops/tenant-access` |
| `growth` | Growth | `ph-user-focus` | Pipeline → `/ops/leads` · Deals → `/ops/deals` · Onboarding → `/ops/onboarding/provision` |
| `billing` | Billing | `ph-stack` | Plans → `/ops/plans` · Billing → `/platform/billing` · Gateways → `/platform/gateways` |
| `comms` | Comms | `ph-chat-circle-text` | Communications → `/platform/communications` · Notifications → `/ops/notifications` · Webhook logs → `/platform/webhook-logs` |
| `staff` | Staff | `ph-users-three` | Platform staff → `/platform/staff` |
| `system` | System | `ph-gear-six` | Audit → `/ops/audit` · Data cleanup → `/ops/data-cleanup` |

**⚠ `/ops/onboarding` has no `page.tsx` — only `/ops/onboarding/provision` does.** Use the full path.

Shape — see §⑭ for the literal file.

```
PlatformPanelLeaf   { key, label, href, icon?, requiredCapability?: string }
PlatformPanelSection{ key, label, leaves: PlatformPanelLeaf[] }
PlatformRailItem    { key, label, icon, sections: PlatformPanelSection[], requiredCapability?: string }
```

**`label` is a plain English string, not a dictionary key.** The platform is an internal,
English-only control plane and the dictionaries have no entries for these items. Inventing
`labelKey`s would produce raw keys on screen. Do not thread `trans` into the rail or panel.

`href` values are **locale-less** (`/ops/tenants`). The panel prepends `/${lang}` at render time,
same as the rest of the app.

**The platform rail is intentionally static and must stay that way.** Its seven items are *sections
of one module*, not modules — the platform IS a single module (`PLATFORM`), so there is nothing to
switch between. Do **not** make it read `USER_ROLE_MODULES`. (The **tenant** rail in Phase 2 is the
opposite: one icon per accessible module, fed by that query. Same `AppShell`, different `navSource`.)

**Capability gating — the honest state.** Only these `PLATFORM_*` capabilities are seeded
(`sql-scripts-dyanmic/ops-platform-rbac-seed.sql`), hanging off four menu rows
(`PLATFORM_TENANTS`, `PLATFORM_LEADS`, `PLATFORM_PLANS`, `PLATFORM_AUDIT`):

`PLATFORM_LEAD_VIEW`, `PLATFORM_LEAD_EDIT`, `PLATFORM_LEAD_EXPORT`, `PLATFORM_DEAL_APPROVE`,
`PLATFORM_TENANT_VIEW`, `PLATFORM_TENANT_PROVISION`, `PLATFORM_TENANT_SUSPEND`,
`PLATFORM_PLAN_EDIT`, `PLATFORM_IMPERSONATE`, `PLATFORM_AUDIT_VIEW`.

So set `requiredCapability` **only** where a real seeded capability exists:

- `tenants` rail + its Tenants/Provisioning leaves → `PLATFORM_TENANT_VIEW`
- `growth` rail + Pipeline/Deals leaves → `PLATFORM_LEAD_VIEW`
- Plans leaf → `PLATFORM_PLAN_EDIT`
- Audit leaf → `PLATFORM_AUDIT_VIEW`

Leave `requiredCapability` **undefined** on everything else. Do **not** invent capability codes and do
**not** write a seed for them — reaching `(master)` at all already requires the PLATFORM module.
Adding gating later is then a one-line change per item. Record this gap in the §⑬ build log.

### 6.3 `useRailItems()`

```
useRailItems() → { railItems, loading }
```

- Reads granted `PLATFORM_*` codes once, via `usePlatformCapabilities`-style access to
  `ROLECAPABILITIES_BY_USER_QUERY` with `moduleCode: "PLATFORM"` and `fetchPolicy: "cache-first"`.
  **Collect codes across ALL menus, not one** — `usePlatformCapabilities` filters to a single
  `menuCode`, which is wrong here. Either extend that hook with an optional `menuCode` (omit ⇒ all
  menus) or add a thin sibling. Prefer extending it; do not duplicate the query.
- Filters `PLATFORM_NAVIGATION`: drop a leaf whose `requiredCapability` is absent; drop a section left
  with no leaves; drop a rail item left with no sections.
- While `loading`, render the rail as skeleton pills — **never** render the unfiltered list and then
  remove items (INV-3; a flash of forbidden nav is a leak).

### 6.4 `AppShell` (`app-shell-provider.tsx`)

Client component. Props `{ navSource, trans, children }`.

Structure:

```
<ModalProvider>
  <AppTopbar ... />
  <div flex row, fills remaining height>
    <AppRail />
    <ContextPanel />
    <main class="relative w-full grow flex flex-col layout-padding p-3 page-min-height">
      {MenuLoader scrim — commit-gated, copied verbatim}
      <motion page transition keyed on pathname>{children}</motion>
    </main>
  </div>
</ModalProvider>
```

Behaviour:
- **Pin the module.** `useEffect` on mount: if `moduleCode !== "PLATFORM"`, `setModuleCode("PLATFORM")`
  (+ `setModuleName("Platform")`). Guard the comparison so it writes at most once —
  an unconditional write re-fires `RoleCapabilityProvider`'s query every render.
- **Derive `activeRailKey` from the pathname on mount and on every route change**, by longest-`href`
  prefix match across all leaves (mirrors the comparator at `useAuth/index.ts:66-71`). Deep links,
  hard refresh and browser-back must all select the right rail item. On no match, keep the current
  selection — never clear it.
- Keep the `MenuLoader` scrim exactly as it is today, including the commit-gated backstop: the 4s
  timer only starts once `location !== navOriginRef.current`, with a 20s absolute ceiling.
  **Do not "simplify" this** — a blind timer drops the scrim while the old screen is still mounted.
- Export as `dynamic(() => Promise.resolve(AppShell), { ssr: false })`, matching
  `DashBoardLayoutProvider`.
- `navSource === "tenant"` → `throw new Error("AppShell: navSource='tenant' lands in Phase 2")`.

### 6.5 `AppRail` (zone 1)

- Fixed 72px wide, full height, `sticky top-0`, own scroll if it overflows.
- One button per rail item: `DynamicIcon` above a 10–11px label, ClickUp style. Active item gets a
  solid accent (per house rule: solid `bg-X-600` + `text-white`, never `bg-X-50/100` or `bg-muted`).
- **Click = `setActiveRailKey(key)` only. No `router.push`.** (INV-5)
- **Hover prefetch:** on hover >150ms, `router.prefetch()` the section's first leaf. Debounce; never
  prefetch the same href twice.
- Overflow: if more than 9 items ever exist, collapse the tail into a "More" popover. Seven today, so
  build the guard but it will not fire.
- Bottom-pinned, above the fold divider: Help (`ph-question`) and the user avatar.
- Below `md`: the rail becomes a bottom bar or a drawer trigger — pick the drawer, reusing the
  existing `Sheet` primitive. The panel opens inside it.

### 6.6 `ContextPanel` (zone 2)

- ~248px expanded / 0px collapsed, with a chevron toggle persisted in the shell store.
- Header = the active rail item's label. Then its sections: a small uppercase section label, then
  leaves as `Link`s to `/${lang}${leaf.href}`.
- Active leaf = exact-or-prefix pathname match, solid accent treatment.
- Clicking a leaf **does** navigate and **does** raise the `MenuLoader` scrim, same as today's menu
  clicks.
- Bottom-pinned: nothing in Phase 1 (ClickUp's "Customize Sidebar" has no equivalent for a static IA
  — do not add a dead control).
- Wrap in `ScrollArea`.

### 6.7 `AppTopbar` (zone 0)

Left → right:
- Product mark + a static "Platform" chip. **Not** the tenant logo — the platform is not
  tenant-branded (INV-1).
- Centre: the search field, opening the **promoted `CommandPalette`** (§⑧ T-5) via `⌘K` / `Ctrl+K`
  and on click.
- Right: `ThemeButton`, `FullScreen`, `NotificationsPanel`, `ProfilePopover`.

Use `GLASS_BAR`. Do **not** render `PlanStatusChip` (tenant billing status is meaningless here) or
`ModuleNavigator`.

---

## §⑦ Menu + RBAC — NO CHANGE

The four seeded PLATFORM menu rows stay in `auth.Menus` untouched. They stop driving navigation and
keep driving permissions: `PLATFORM_*` capabilities are attached to those rows and
`usePlatformCapabilities` matches on `menu.menuCode`. **Deleting or deactivating them would break
platform RBAC.** No seed, no SQL, no migration in this prompt.

---

## §⑧ Tasks

| # | Task |
|---|---|
| **T-1** | Create `platform-navigation.ts` with the exact IA in §6.2, including the four `requiredCapability` assignments and no others. |
| **T-2** | Create `app-shell-store.ts` + `app-shell-istore.ts`; export from `src/application/stores/index.ts`. |
| **T-3** | Build `AppTopbar`, `AppRail`, `ContextPanel`, `useRailItems`, `AppShell` per §⑥. |
| **T-4** | Turn `(master)/masterdashboard/page.tsx` into a redirect to `/${lang}/platform/dashboards`. **Do not delete the route** — `MASTER_URL` is the `useAuth` null-landing fallback (`index.ts:49`), the `route-guard` callback, and `company-switcher-item.tsx:85` does `window.location.href = MASTER_URL` after a company switch. Leave `MASTER_URL` itself alone in Phase 1. |
| **T-5** | Move `command-palette.tsx` out of `pages/master/landing-page/` to `src/presentation/components/layout-components/command-palette/`. Strip any dependency it has on module-grid state. Wire it to `AppTopbar` search. |
| **T-6** | Rewrite `(master)/layout.tsx`: `RouteGuard requireAuth` → `CompanySettingsBootstrap` → `RoleCapabilityProvider` → `AppShell navSource="platform" trans={trans}` → children. Keep `getDictionary(lang)`. |
| **T-7** | Delete `(master)/ops/layout.tsx` and `(master)/platform/layout.tsx`. |
| **T-8** | Delete `pages/master/landing-page/` (all 18 files **minus** the one moved in T-5). Grep for every import of that directory first and fix each — `MasterLandingPageConfig` is imported by the old `masterdashboard/page.tsx`, which T-4 rewrites. |
| **T-9** | Typecheck: `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`. **Only exit 0 counts.** No pipe. |

---

## §⑨ Acceptance

1. `/en/platform/dashboards`, `/en/ops/tenants`, `/en/ops/leads`, `/en/platform/staff` all render
   inside the new shell — rail + panel + top bar — with no tenant sidebar anywhere.
2. **Every URL is unchanged.** No route file moved.
3. Clicking a rail icon swaps the panel and does **not** change the URL or raise a full-screen scrim.
4. Clicking a panel leaf navigates and raises the `MenuLoader` scrim, which lowers once the new page
   commits — and does **not** lower early on a slow route.
5. Hard-refreshing on `/en/ops/tenants/provisioning-runs` selects the **Tenants** rail item and
   highlights the **Provisioning runs** leaf.
6. `/en/masterdashboard` redirects to `/en/platform/dashboards`. Switching company still works.
7. A user without `PLATFORM_LEAD_VIEW` sees **no Growth rail item at all** — not a disabled one.
8. No `ModuleNavigator`, no full-screen `ModuleLoader`, no `PlanStatusChip` on any `(master)` route.
9. `(core)` is byte-identical to before: `/en/crm/...` still renders the tenant sidebar, the module
   navigator still works there, module switching still works.
10. `npx tsc --noEmit --incremental false` exits 0.
11. Responsive xs→xl: below `md` the rail collapses to a drawer and the content is usable.
12. Dark mode correct on all three zones.

---

## §⑩ Out of scope — do NOT build

- Anything under `(core)`, `(member)`, `(public)`, `(setup)`, `(auth)`.
- Deleting `DashBoardLayoutProvider`, `Sidebar`, `ModuleNavigator`, `ModuleLoader` — the tenant
  surface still uses them. Phase 2/3.
- `useActiveModule()` — Phase 2 needs it; Phase 1 pins `PLATFORM` and doesn't.
- Relocating the master-dashboard KPI / activity / mission-progress widgets onto a real screen.
  Phase 3. They are deleted with the landing page in T-8; the parent plan records this.
- New PLATFORM capability seeds for the ungated rail items (§6.2). Flag it; do not write it.
- Merging `/ops/` and `/platform/` into one segment.
- Any backend, migration, seed, or SQL.

---

## §⑪ Traps

1. **`useMenu()` must never run on `(master)`.** It lives only in `DashBoardLayoutProvider`, which
   `(master)` no longer mounts. If you find yourself importing it into the shell, you have taken a
   wrong turn.
2. **Pinning `moduleCode = "PLATFORM"` unconditionally re-fires the capability query.** Compare before
   writing.
3. **The pin is global state.** After a company switch, `company-switcher-item.tsx` does a full
   `window.location.href` reload, which resets the store — so there is no stale-module leak today.
   Do not "optimise" that into a client-side `router.push`.
4. **`Header` is not reusable here.** It imports `ModuleNavigator` and branches on `layout` /
   `sidebarType` / `navbarType`. Build `AppTopbar` fresh; reuse only the leaf controls.
5. **`usePlatformCapabilities` filters to one `menuCode`.** The rail needs codes across all menus —
   see §6.3.
6. **`/ops/onboarding` has no page.** Only `/ops/onboarding/provision`.
7. **Do not touch the `MenuLoader` commit-gated backstop logic.** Copy it byte-for-byte.
8. **`MASTER_URL` is `"/en/masterdashboard"` with a hardcoded `en`.** Pre-existing. Do not fix it in
   this prompt; the redirect route makes it harmless.
9. **Solid accents only** on active rail/panel items and any badge: `bg-X-600` + `text-white`. Never
   `bg-X-50/100`, `text-X-700/800`, or `bg-muted` / `text-muted-foreground`.
10. **tsc cannot see GraphQL field names.** The shell adds no new query, but if you extend
    `usePlatformCapabilities`, do not rename anything in the existing document.
11. **Grep before deleting `pages/master/landing-page/`.** Something outside `masterdashboard` may
    import a piece of it.

---

## §⑫ Hand-off — user-owned, do not perform

Nothing. Phase 1 has no migration, no seed, no `dotnet build`. Frontend rebuild only.

---

## §⑬ Build log

_(empty — nothing built)_

---

## §⑭ Appendix — literal shapes

These are the exact starting points. Follow them; do not re-architect.

### 14.1 `src/application/constants/platform-navigation.ts`

```ts
export interface PlatformPanelLeaf {
  key: string;
  label: string;                    // plain English — NOT a dictionary key
  href: string;                     // locale-less, e.g. "/ops/tenants"
  icon?: string;
  requiredCapability?: string;      // omit = always visible (see §6.2)
}

export interface PlatformPanelSection {
  key: string;
  label: string;
  leaves: PlatformPanelLeaf[];
}

export interface PlatformRailItem {
  key: string;
  label: string;
  icon: string;                     // Phosphor name, e.g. "ph-buildings"
  requiredCapability?: string;
  sections: PlatformPanelSection[];
}

export const PLATFORM_NAVIGATION: PlatformRailItem[] = [
  {
    key: "home",
    label: "Home",
    icon: "ph-house",
    sections: [
      { key: "overview", label: "Overview", leaves: [
        { key: "dashboards", label: "Dashboard", href: "/platform/dashboards" },
      ]},
    ],
  },
  {
    key: "tenants",
    label: "Tenants",
    icon: "ph-buildings",
    requiredCapability: "PLATFORM_TENANT_VIEW",
    sections: [
      { key: "tenants", label: "Tenants", leaves: [
        { key: "list",   label: "All tenants",       href: "/ops/tenants",
          requiredCapability: "PLATFORM_TENANT_VIEW" },
        { key: "runs",   label: "Provisioning runs", href: "/ops/tenants/provisioning-runs",
          requiredCapability: "PLATFORM_TENANT_VIEW" },
        { key: "access", label: "Tenant access",     href: "/ops/tenant-access" },
      ]},
    ],
  },
  {
    key: "growth",
    label: "Growth",
    icon: "ph-user-focus",
    requiredCapability: "PLATFORM_LEAD_VIEW",
    sections: [
      { key: "pipeline", label: "Pipeline", leaves: [
        { key: "leads", label: "Leads", href: "/ops/leads",
          requiredCapability: "PLATFORM_LEAD_VIEW" },
        { key: "deals", label: "Deals", href: "/ops/deals",
          requiredCapability: "PLATFORM_LEAD_VIEW" },
        // NOTE: /ops/onboarding has NO page.tsx — only /provision does.
        { key: "onboarding", label: "Onboarding", href: "/ops/onboarding/provision" },
      ]},
    ],
  },
  {
    key: "billing",
    label: "Billing",
    icon: "ph-stack",
    sections: [
      { key: "billing", label: "Billing", leaves: [
        { key: "plans",    label: "Plans",    href: "/ops/plans",
          requiredCapability: "PLATFORM_PLAN_EDIT" },
        { key: "billing",  label: "Billing",  href: "/platform/billing" },
        { key: "gateways", label: "Gateways", href: "/platform/gateways" },
      ]},
    ],
  },
  {
    key: "comms",
    label: "Comms",
    icon: "ph-chat-circle-text",
    sections: [
      { key: "comms", label: "Communications", leaves: [
        { key: "providers",     label: "Providers",     href: "/platform/communications" },
        { key: "notifications", label: "Notifications", href: "/ops/notifications" },
        { key: "webhooks",      label: "Webhook logs",  href: "/platform/webhook-logs" },
      ]},
    ],
  },
  {
    key: "staff",
    label: "Staff",
    icon: "ph-users-three",
    sections: [
      { key: "staff", label: "People", leaves: [
        { key: "staff", label: "Platform staff", href: "/platform/staff" },
      ]},
    ],
  },
  {
    key: "system",
    label: "System",
    icon: "ph-gear-six",
    sections: [
      { key: "system", label: "System", leaves: [
        { key: "audit",   label: "Audit log",    href: "/ops/audit",
          requiredCapability: "PLATFORM_AUDIT_VIEW" },
        { key: "cleanup", label: "Data cleanup", href: "/ops/data-cleanup" },
      ]},
    ],
  },
];

/** Every leaf, flattened — for the pathname → railKey resolver. */
export const PLATFORM_LEAVES = PLATFORM_NAVIGATION.flatMap((rail) =>
  rail.sections.flatMap((section) =>
    section.leaves.map((leaf) => ({ ...leaf, railKey: rail.key })),
  ),
);
```

### 14.2 Pathname → rail key

Longest-`href` prefix wins, mirroring `useAuth/index.ts:66-71`. Strip the `/{lang}` first.

```ts
export function resolveRailKey(pathname: string, currentKey: string): string {
  const path = pathname.replace(/^\/[a-z]{2}(?=\/|$)/, "");   // "/en/ops/tenants" → "/ops/tenants"
  const match = PLATFORM_LEAVES
    .filter((l) => path === l.href || path.startsWith(`${l.href}/`))
    .sort((a, b) => b.href.length - a.href.length)[0];
  return match ? match.railKey : currentKey;   // no match → keep selection, never clear
}
```

The sort is load-bearing: `/ops/tenants/provisioning-runs` matches **both** `/ops/tenants` and
`/ops/tenants/provisioning-runs`. Without it you land on the wrong leaf.

### 14.3 `app-shell-istore.ts` / `app-shell-store.ts`

```ts
// app-shell-istore.ts
export interface IAppShellStore {
  activeRailKey: string;
  panelCollapsed: boolean;
  setActiveRailKey: (key: string) => void;
  setPanelCollapsed: (collapsed: boolean) => void;
  togglePanel: () => void;
}
```

```ts
// app-shell-store.ts
export const useAppShellStore = create<IAppShellStore>()(
  persist(
    (set) => ({
      activeRailKey: "home",
      panelCollapsed: false,
      setActiveRailKey: (key) => set({ activeRailKey: key }),
      setPanelCollapsed: (panelCollapsed) => set({ panelCollapsed }),
      togglePanel: () => set((s) => ({ panelCollapsed: !s.panelCollapsed })),
    }),
    { name: "pss-app-shell", partialize: (s) => ({ panelCollapsed: s.panelCollapsed }) },
  ),
);
```

**Persist `panelCollapsed` only.** `activeRailKey` is derived from the URL on every load — persisting
it would fight the resolver and flash the wrong rail item on refresh.

### 14.4 `(master)/layout.tsx` — exact after

Before (current, verified) is `RouteGuard` → `CompanySettingsBootstrap` + `{children}`, with `trans`
computed and unused. After:

```tsx
import { getDictionary } from "@/presentation/components/app-extensions/dictionaries";
import { RouteGuard } from "@/presentation/components/auth/route-guard";
import { CompanySettingsBootstrap } from "@/presentation/provider/company-settings-bootstrap";
import { RoleCapabilityProvider } from "@/presentation/provider/access-provider";
import AppShell from "@/presentation/provider/app-shell-provider";

const layout = async (props: { children: React.ReactNode; params: Promise<{ lang: any }> }) => {
    const { lang } = await props.params;
    const { children } = props;
    const trans = await getDictionary(lang);
    return (
        <RouteGuard requireAuth={true}>
            <CompanySettingsBootstrap />
            <RoleCapabilityProvider>
                <AppShell navSource="platform" trans={trans}>{children}</AppShell>
            </RoleCapabilityProvider>
        </RouteGuard>
    )
};

export default layout;
```

`RoleCapabilityProvider` moves **up** from the two deleted child layouts — it is not duplicated, and
`RouteGuard`/`CompanySettingsBootstrap` still wrap everything exactly as before.

### 14.5 `masterdashboard/page.tsx` — exact after

```tsx
import { redirect } from "next/navigation";

// The master landing page (module launcher + KPI widgets) is retired — see
// PSS-2.0-APP-SHELL-REDESIGN-APPROACH.md. The ROUTE stays because MASTER_URL still
// points here from three call sites: useAuth's null-landing fallback, route-guard, and
// company-switcher-item's post-switch window.location.href.
export default async function MasterDashboard({ params }: { params: Promise<{ lang: string }> }) {
    const { lang } = await params;
    redirect(`/${lang}/platform/dashboards`);
}
```

Server component, no `"use client"`. `redirect()` from `next/navigation` throws by design — do not
wrap it in try/catch.

### 14.6 Sizing and tokens

| Zone | Spec |
|---|---|
| Top bar | `h-14`, `GLASS_BAR`, `sticky top-0 z-50` |
| Rail | `w-[72px]`, `shrink-0`, `sticky`, own `ScrollArea`; item = icon `size-5` over `text-[10px]` label, `py-2.5` |
| Panel | `w-[248px]` expanded → `w-0` collapsed, `transition-[width] duration-200`, `border-r border-border` |
| Content | `grow min-w-0 p-3` — **`min-w-0` is required**, or wide data grids will push the rail off-screen |

Active rail item and active panel leaf: solid `bg-primary` + `text-primary-foreground`. Never
`bg-primary/10`, `text-primary`, `bg-muted`, or `text-muted-foreground` for the active state.
Hover/inactive may use muted. No raw hex, no raw px outside the four widths above.

### 14.7 Keyboard and a11y — minimum bar

- Rail items are `<button>` with `aria-label={label}` and `aria-current="true"` when active.
- Panel leaves are `next/link` `<Link>` with `aria-current="page"` when active.
- `⌘K` / `Ctrl+K` opens the command palette from anywhere in `(master)`; `Esc` closes it. Register
  the listener once, in `AppTopbar`, and remove it on unmount.
- Panel toggle button carries `aria-expanded`.
- Tooltip on rail hover showing `label` (the 10px caption is not enough on its own).

### 14.8 If a route is missing

Every `href` in §14.1 was verified against a real `page.tsx`. If one 404s during build, **do not
delete the leaf and do not create the page** — leave it, and record it in §⑬. A missing platform
screen is a separate piece of work, not a shell bug.
