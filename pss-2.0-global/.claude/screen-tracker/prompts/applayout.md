---
screen: AppLayout
registry_id: 121
module: Layout (root)
status: PARTIALLY_COMPLETED
scope: ALIGN
screen_type: CONFIG
config_subtype: SETTINGS_PAGE
complexity: High
new_module: NO
planned_date: 2026-05-19
completed_date:
last_session_date: 2026-05-19
---

# AppLayout — Application Shell Alignment (#121)

> **Special non-CRUD screen.** No entity, no backend storage, no CRUD. The "configuration" being aligned is the FE shell itself — header chrome, sidebar chrome, and content viewport — wrapping every authenticated screen in the platform. Treated as `CONFIG / SETTINGS_PAGE` because that template best matches a "single-record, multi-section, visual" alignment pattern. See §⑫ for divergence notes.
>
> Mockup: [`html_mockup_screens/app-layout.html`](../../../html_mockup_screens/app-layout.html)
> Current chrome: [`src/presentation/provider/dashboard-layout-provider.tsx`](../../../PSS_2.0_Frontend/src/presentation/provider/dashboard-layout-provider.tsx) + [`layout-components/header`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/header) + [`layout-components/sidebar`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/sidebar)

---

## ① Identity & Context

**App Layout** is the authenticated shell that wraps every page inside PSS 2.0 — header (60 px top bar) + sidebar (280 px left rail) + main content viewport. It is rendered by [`DashBoardLayoutProvider`](../../../PSS_2.0_Frontend/src/presentation/provider/dashboard-layout-provider.tsx) which is mounted from every module's `layout.tsx` ([crm](../../../PSS_2.0_Frontend/src/app/[lang]/crm/layout.tsx), [setting](../../../PSS_2.0_Frontend/src/app/[lang]/setting/layout.tsx), [organization](../../../PSS_2.0_Frontend/src/app/[lang]/organization/layout.tsx), [accesscontrol](../../../PSS_2.0_Frontend/src/app/[lang]/accesscontrol/layout.tsx), [general](../../../PSS_2.0_Frontend/src/app/[lang]/general/layout.tsx), [reportaudit](../../../PSS_2.0_Frontend/src/app/[lang]/reportaudit/layout.tsx)). The shell exists today (inherited DashCode template) but ships THREE layout variants (`vertical | horizontal | semibox`) and THREE sidebar types (`classic | module | popover`) — the mockup specifies a single canonical chrome and a single sidebar pattern. This alignment trims the variants and restyles header + sidebar to match the mockup.

**Why this matters:** the shell is the first thing every user sees and is the only chrome rendered around all 130 actionable screens. Visual inconsistency between mockup-driven feature screens and the inherited template chrome breaks the brand. This is an ALIGN task — keep the existing menu data pipeline (BE-driven via `parentChildMenus` GQL query) intact, keep all existing routes intact, and restyle / restructure only the visual chrome to match `app-layout.html`.

---

## ② Storage Model (no entity)

This screen has **no entity, no DB row, no Zustand-persisted user setting backed by BE**. The "shell configuration" lives in:

| Source | Where | Purpose |
|--------|-------|---------|
| FE static config | [`src/application/configs/common-configs/ThemeConfig.ts`](../../../PSS_2.0_Frontend/src/application/configs/common-configs/ThemeConfig.ts) → `Config` object | Default `layout`, `sidebarType`, `navbarType`, `theme`, `sidebarBg` |
| Zustand (localStorage-persisted) | [`useSidebar`](../../../PSS_2.0_Frontend/src/application/stores/common-stores/sidebar-store.ts) | `collapsed`, `sidebarType`, `subMenu`, `mobileMenu` |
| Zustand (localStorage-persisted) | [`useThemeStore`](../../../PSS_2.0_Frontend/src/application/stores/theme-stores/theme-store.ts) | `layout`, `theme`, `radius`, `navbarType`, `isRtl` |
| Zustand (in-memory) | [`useParentChildMenuStore`](../../../PSS_2.0_Frontend/src/application/stores/auth-stores/menu-store.ts) | Sidebar menu tree fetched from BE |
| Zustand (in-memory) | [`useUserStore`](../../../PSS_2.0_Frontend/src/application/stores/auth-stores/user-store.ts) | Logged-in user info for avatar + name + role |
| Zustand (in-memory) | [`useGlobalStore`](../../../PSS_2.0_Frontend/src/application/stores/common-stores) | `moduleCode`, `moduleId`, loading flags |

**Implication:** the build session writes **no entity, no EF config, no DTO, no GQL query/mutation**. All work is FE TSX + CSS + Zustand store default tweaks. Backend stays untouched.

---

## ③ FK Resolution Table — N/A

No FKs. The shell consumes existing GQL queries already wired:

| Consumer | GQL query | Source file |
|----------|-----------|-------------|
| Sidebar menu | `parentChildMenus(moduleCode: $moduleCode)` | [`gql-queries/parentchild-menu`](../../../PSS_2.0_Frontend/src/infrastructure/gql-queries) |
| User info (avatar/name/role) | existing user query (loaded by `AuthProvider` via [`useUserStore`](../../../PSS_2.0_Frontend/src/application/stores/auth-stores/user-store.ts)) | already wired |
| Notification count badge | **NOT WIRED** today — header shows static "23" in mockup; flag as SERVICE_PLACEHOLDER unless `unreadNotificationCount` query is wired in [`gql-queries/notification`](../../../PSS_2.0_Frontend/src/infrastructure/gql-queries) | TBD on build |

Build session should run **one grep** to confirm whether an unread-notification-count GQL query exists. If yes → wire it. If no → render badge as `0` and hide when zero; do NOT block the build on this.

---

## ④ Business Rules & Validation

**No business rules** (no form, no save, no validation). The "rules" are visual + behavioural invariants:

- **Persistence**: sidebar collapsed state must persist across reloads (already handled by `persist()` middleware in `sidebar-store.ts`).
- **Responsive breakpoint**: at `< 992 px` the sidebar must hide off-canvas and reveal via the hamburger toggle with a dark backdrop overlay (mockup CSS `@media (max-width: 992px)`). At `>= 992 px` the sidebar must be permanently visible alongside content.
- **Mobile sidebar close on navigation**: clicking any menu item below the breakpoint must close the sidebar overlay automatically (mockup `loadContent()` calls `closeSidebar()`).
- **Active item highlighting**: the menu item matching the current pathname must show the accent left-border + tinted background (existing `isLocationMatch` logic — verify it still works after restyling).
- **Section collapse**: clicking a section header toggles its menu items (mockup `toggleSection()`). Section open/closed state does not need to persist across reloads.
- **Logo click**: top-left logo navigates to `/dashboard` (already wired in current code).
- **Logout**: bottom-of-sidebar Logout link triggers existing logout flow (clears auth + session + redirects to `/login`).
- **Role badge**: top-bar shows the user's role text (e.g., "Super Admin", "Business Admin", "Staff") — comes from `useUserStore().userInfo.role` or equivalent.
- **Notification bell badge**: shown only when count > 0; click navigates to `communication/notification-center` (route may not exist yet — keep button but disable or route to existing notifications page if available).

**No workflow / state machine.**

---

## ⑤ Classification & Patterns

- **screen_type**: `CONFIG` (closest of the six standard types — non-list, multi-section, single "record" being aligned). Real category is **LAYOUT** — see §⑫ for divergence.
- **config_subtype**: `SETTINGS_PAGE` (the chrome is a multi-section visual settings page, not a designer canvas or matrix).
- **Singleton**: yes (one shell per app — no concept of "+Add").
- **Save model**: N/A — no save. State changes (collapse, mobile toggle) are immediate, client-only, and partly localStorage-persisted via Zustand.
- **Sensitive fields**: none.
- **Lifecycle**: none.
- **Role gating**: chrome is rendered for all authenticated users. Role badge text changes per user. No capability-based hide/show on chrome elements themselves (per-menu-item visibility is handled by existing menu BE query).

**Patterns checklist (pre-answered for Solution Resolver):**

| Pattern | Decision | Reason |
|---------|----------|--------|
| Tabs | NO | Chrome is a fixed shell |
| Accordion | YES (sidebar sections) | Mockup uses chevron-down toggles per section |
| Modal | NO | No editing dialogs in the shell |
| Form (RJSF) | NO | No form |
| Grid | NO | No data table in the shell |
| Widgets / KPIs | NO | No metrics |
| Workflow buttons | NO | No state machine |
| Sticky header | YES | Mockup header is `position: fixed` 60 px |
| Sticky sidebar | YES | Mockup sidebar is `position: fixed` left, scrollable internally |
| Mobile drawer | YES | Off-canvas at `< 992 px` with backdrop overlay |

---

## ⑥ UI/UX Blueprint (the primary deliverable)

The mockup has THREE regions: **header**, **sidebar**, **content viewport**. Each is described below with mockup-pixel-precise specs and a diff against the current implementation. The build agent must apply these changes to the existing files, not write new ones from scratch.

### ⑥.A — Header (`app-header`)

**Mockup spec:**

| Property | Value | Source in mockup |
|----------|-------|------------------|
| Position | `fixed; top: 0; left: 0; right: 0` | line 42-56 |
| Height | `60 px` (`--header-height`) | line 16 |
| Background | `linear-gradient(135deg, #0e7490, #06b6d4)` (teal → cyan) | line 48 |
| Text color | white | line 49 |
| z-index | `1050` | line 54 |
| Box-shadow | `0 2px 10px rgba(0,0,0,0.15)` | line 55 |
| Layout | flex, space-between, `0 1.25rem` padding | line 50-53 |

**Header — left cluster** (left-to-right):

1. **Sidebar toggle (hamburger)** — `fas fa-bars`, white, 1.25 rem, transparent bg, hover bg `rgba(255,255,255,0.15)`, padding `0.375 rem`, rounded `0.375 rem`. Calls `toggleSidebar()`.
2. **Logo block** — `fas fa-hand-holding-heart` icon (1.375 rem) + two stacked lines: "PeopleServe 2.0" (weight 700, 1.125 rem) over "NGO Management Platform" (weight 400, 0.625 rem, opacity 0.85).
3. **Role badge** — pill (`background: rgba(255,255,255,0.2); border-radius: 9999px; padding: 0.25rem 0.75rem; font-size: 0.6875rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em`). Text = current user's role label (e.g. `Super Admin`).

**Header — right cluster** (left-to-right):

1. **Notification icon button** — circle 36×36 `rgba(255,255,255,0.15)` bg, white icon `fas fa-bell` (0.9375 rem). Hover bg `rgba(255,255,255,0.25)`. **Red badge** in top-right (`#f43f5e`, white text, 18×18, weight 700, 0.5625 rem font, 2 px solid teal border) showing unread count. On click → navigate to `/communication/notification-center` (use existing route or whichever notification list route exists; verify via grep). Badge hidden when count === 0.
2. **User avatar** — circle 36×36, `rgba(255,255,255,0.25)` bg, 2 px `rgba(255,255,255,0.4)` border, white-text initials (font-weight 700, 0.8125 rem), cursor pointer. Opens existing [`ProfilePopover`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/header/profile-popover/index.tsx) (reuse, do not rebuild).
3. **User info block** (visible only at `>= 992 px`) — two stacked lines: user name (weight 600, 0.8125 rem) over role text (0.6875 rem, opacity 0.85), line-height 1.2.

**Current state (gap analysis):**

- [`Header`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/header/header.tsx) wraps [`VerticalHeader`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/header/vertical-header.tsx) in [`ClassicHeader`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/header/layout) — bg is `bg-card/90 backdrop-blur-lg` (white/glass) with a bottom border. **Replace** with the teal gradient.
- [`VerticalHeader`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/header/vertical-header.tsx) currently renders: `MenuBar` (3-stripe hamburger animation), an unused `MainLogo` link, and `InlineSearchBar` (for non-PeopleServe users). **Replace** with: hamburger button + brand logo block + role badge. Keep the existing `InlineSearchBar` only if `currentUserFrom !== PEOPLESERVE` (don't break the multi-app case) but move it OUT of the primary header chrome — or simply hide it when on PEOPLESERVE app.
- `NavTools` (right side, in `header.tsx`) currently renders `ThemeButton`, `FullScreen`, `ModuleNavigator`, `ProfilePopover`. **Slim down for the PEOPLESERVE app** to: notification button + ProfilePopover trigger (avatar + user-info block). Keep `ThemeButton` and `FullScreen` but tuck them inside the ProfilePopover dropdown (already partially supported — see [`ProfilePopover`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/header/profile-popover/index.tsx) menu items list). When `currentUserFrom !== PEOPLESERVE`, keep the existing `ModuleNavigator` etc.
- [`ProfilePopover`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/header/profile-popover/index.tsx) trigger today shows just a fallback avatar. **Update trigger** to render: avatar (initials, white text on translucent bg) + user-info block (name + role), matching mockup.
- Multi-layout branches (`if layout === "horizontal"`, `if layout === "semibox"`, `if navbarType === "floating"`) in `header.tsx` are dead paths once we lock to vertical/classic — keep the code but ensure the default branch produces the mockup-aligned header.

### ⑥.B — Sidebar (`app-sidebar`)

**Mockup spec:**

| Property | Value |
|----------|-------|
| Position | `fixed; top: 60px; left: 0; bottom: 0` |
| Width | `280 px` (`--sidebar-width`) |
| Background | `#ffffff` |
| Border | `1px solid #e2e8f0` right |
| Overflow-y | auto |
| z-index | 1040 |
| Transition | `transform 0.3s ease, width 0.3s ease` |
| Layout | flex column (nav grows, footer pinned) |
| Collapsed (desktop) | `transform: translateX(-100%)` (fully hidden, content fills width) |
| Mobile drawer | `transform: translateX(0)` when `.mobile-open`, with `box-shadow: 4px 0 15px rgba(0,0,0,0.1)` |

**Sidebar nav structure:**

```
<aside .app-sidebar>
  <nav .sidebar-nav>                                ← flex:1, padding 0.75rem 0
    ┌─ Section "Main"                              ← .sidebar-section-title
    │   └─ Dashboard                               ← .sidebar-item (active)
    ├─ Section "CRM & Contacts"                    ← chevron-down toggle
    │   ├─ All Contacts
    │   ├─ Families
    │   ├─ Tags & Segments
    │   ├─ Duplicate Detection
    │   ├─ Import Contacts
    │   ├─ Contact Types
    │   └─ Contact Sources
    ├─ Section "Fundraising"                       ← 16 items
    ├─ Section "Communication"                     ← 15 items
    ├─ Section "Case Management"                   ← 5 items
    ├─ Section "Organization"                      ← 8 items
    ├─ Section "Field Collection"                  ← 6 items
    ├─ Section "Volunteer"                         ← 6 items
    ├─ Section "Membership"                        ← 5 items
    ├─ Section "Grants"                            ← 4 items
    ├─ Section "AI & Intelligence"                 ← 6 items
    ├─ Section "Reports"                           ← 7 items
    ├─ Section "Administration"                    ← 6 items
    ├─ Section "Settings"                          ← 14 items
    └─ Section "📱 Mobile App Previews" [Preview]   ← 2 items (badge "Preview")
  <div .sidebar-footer>
    └─ Logout link                                 ← fas fa-arrow-right-from-bracket
```

**Section header styling (`.sidebar-section-title`):**

- Padding `0.75rem 1.25rem 0.375rem`
- Font size `0.625 rem`, weight 700, uppercase, letter-spacing 0.1em
- Color `#64748b` (text-secondary), hover `#1e293b` (text-primary)
- Layout flex space-between (label on left, chevron-down on right)
- Chevron rotates `-90deg` when section is collapsed (`.collapsed-section`)
- Section items wrapper transitions `max-height 0.25s ease`; `.hidden` sets `max-height: 0`

**Menu item styling (`.sidebar-item`):**

- Padding `0.5625rem 1.25rem`, gap `0.75rem` between icon and label
- Color `#64748b` (text-secondary), font 0.8125 rem, weight 500
- Left border 3 px solid transparent
- Hover: bg `#f0fdfa` (`--hover-bg`), color `#1e293b`
- **Active** (`.active`): bg gradient `linear-gradient(90deg, rgba(14,116,144,0.08), transparent)`, color `#0e7490` (`--accent`), border-left-color `#0e7490`, weight 600
- Icon `<i>` width 20 px, centered, font 0.9375 rem (FontAwesome icons used in mockup; map to existing iconify icons where needed)

**Sidebar footer (`.sidebar-footer`):**

- Padding `1rem 1.25rem`, border-top 1 px `#e2e8f0`
- Logout link: flex, gap 0.5 rem, font 0.8125 rem, weight 500
- Hover color `#dc2626` (danger)
- Triggers existing logout via [`LogoutComponent`](../../../PSS_2.0_Frontend/src/presentation/components/custom-components) or current `Logout` component

**Mobile overlay (`.sidebar-overlay`):**

- `position: fixed; inset: 0; top: 60px; background: rgba(0,0,0,0.3); z-index: 1035`
- Shown when sidebar is `.mobile-open`; click closes the sidebar

**Current state (gap analysis):**

The existing sidebar is a multi-pattern engine:

- [`Sidebar`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/sidebar/sidebar.tsx) dispatches to one of `ClassicSidebar`, `ModuleSidebar`, `PopoverSidebar`, or `MobileSidebar` based on Zustand `sidebarType`.
- Default `sidebarType: "popover"` (from `Config.sidebarType` in `ThemeConfig.ts`). On desktop popover behaves like a hover-expanding mini sidebar.
- [`ModuleSidebar`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/sidebar/module/index.tsx) renders a **two-rail layout** (72 px icon rail + 228 px sub-menu rail) — totally different from the mockup's single-rail 280 px.
- [`ClassicSidebar`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/sidebar/classic/index.tsx) renders a **single-rail 248 px** sidebar with `<MenuLabel>` section headers, `<SingleMenuItem>` items, and `<SubMenuHandler>` for parent-with-children expansion via `activeSubmenu` state. **This is the closest match** to the mockup pattern. The mockup's section toggles map to ClassicSidebar's section labels + child menu expansion.

**Decisions for ALIGN session:**

1. **Lock default to `sidebarType: "classic"`** in `ThemeConfig.ts` (`Config.sidebarType = "classic"`). Override in Zustand store init if needed. This makes ClassicSidebar the canonical sidebar for PeopleServe.
2. **Lock default to `layout: "vertical"`** in `ThemeConfig.ts` (already the default).
3. **Restyle [`ClassicSidebar`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/sidebar/classic/index.tsx) + [`SingleMenuItem`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/sidebar/classic/single-menu-item.tsx) + [`SubMenuHandler`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/sidebar/classic/sub-menu-handler.tsx) + [`MenuLabel`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/sidebar/common/menu-label.tsx)** to match mockup tokens (280 px width, white bg, the section-title + menu-item styles described above, accent left-border on active).
4. **Update default `Config.sidebarBg = "none"`** is already correct — confirm no background image renders. Mockup has plain white.
5. **Update `DashBoardLayoutProvider`** content-wrapper margins to use `280px` (not `300px` / `248px` / `272px` / `72px` branches). Collapse the four-branch IIFE block down to: "if collapsed → ml-0 + content full width; else → ml-[280px] + content w-[calc(100%-280px)]".
6. **Mobile drawer**: when `< 992 px`, sidebar transforms off-canvas. Today this is handled inside [`ClassicSidebar`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/sidebar/classic/index.tsx) (or via [`MobileSidebar`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/sidebar/mobile-sidebar/index.tsx) when `!isDesktop`). Verify the off-canvas behaviour matches: slide-in from left, dark backdrop overlay, close-on-item-click.
7. **Bottom Logout** in sidebar — today [`ClassicSidebar`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/sidebar/classic/index.tsx) shows `<CopyrightItem>` at the bottom. **Add a `<SidebarLogout>` row above the copyright** (or replace copyright with logout for PEOPLESERVE app) using `LogoutComponent` to fire the existing logout action.
8. **Section grouping** — the mockup groups menus by parent (`Main`, `CRM & Contacts`, `Fundraising`, `Communication`, …). The existing `parentChildMenus(moduleCode)` query is keyed by `moduleCode` and returns ONE module's tree at a time. **The mockup shows ALL modules' menus flattened into one sidebar.** This is the biggest data-shape gap:
   - Either: change the query to return **all** modules + all child menus for the logged-in user (likely need a new query: `myMenuTree` or `userAccessibleMenus` — check `gql-queries` first; if missing → SERVICE_PLACEHOLDER + flag for backend).
   - Or: keep per-module fetching and have the sidebar pre-fetch all 6 modules in parallel (one query per module → flatten client-side).
   - **Recommendation**: prefer one new BE query that returns the full user menu tree in one shot. Verify with grep before the FE build session.

### ⑥.C — Content viewport (`app-content`)

**Mockup spec:**

| Property | Value |
|----------|-------|
| Position | `fixed; top: 60px; left: 280px; right: 0; bottom: 0` |
| Background | `#f1f5f9` |
| Transition | `left 0.3s ease` |
| Collapsed state | `left: 0` (when sidebar hidden) |
| Mobile | `left: 0` always (sidebar overlays content) |

The mockup uses an `<iframe>` for content — irrelevant; the real app renders the Next.js route page directly.

**Current state:** `DashBoardLayoutProvider` already provides a wrapping `<div class="content-wrapper">` with appropriate `ml-[Xpx]` and `w-[calc(100%-Xpx)]` classes. Simplify the px values to `280` / `0` (replacing today's `300/248/272/72/200` branches) and remove the `semibox` / `horizontal` branches once unused (or leave them dormant for non-PEOPLESERVE apps but **set defaults so PEOPLESERVE always renders vertical/classic**).

The mockup's `#f1f5f9` background is light slate — the existing tailwind base bg is fine; verify via the `body` class manager that it does not bleed gradient or anything inconsistent.

### ⑥.D — Interactions & state

- **Sidebar toggle** — hamburger in header. Desktop: collapses sidebar (transforms off-canvas, content fills width). Mobile: opens drawer + backdrop. Uses `useSidebar().collapsed` + `useSidebar().mobileMenu` (or equivalent — verify).
- **Section toggle** — click section-title. Animates max-height of children. State NOT persisted across reloads.
- **Item click** — Next.js `<Link>` navigation; closes mobile drawer when triggered below breakpoint.
- **Logo click** — `/dashboard` (already wired).
- **Notification bell** — navigates to `/communication/notification-center` (verify route exists — if not, hide button or route to closest existing notifications screen).
- **Avatar click** — opens [`ProfilePopover`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/header/profile-popover/index.tsx) (popover at `>= 768 px`, bottom sheet below — existing logic).

### ⑥.E — Brand tokens

Add the mockup's CSS tokens to `tailwind.config.ts` (or globals.css `:root`) so other screens can reuse:

```css
--accent: #0e7490;       /* teal-700  */
--accent-end: #06b6d4;   /* cyan-500  */
--accent-light: #ecfeff; /* cyan-50   */
--sidebar-width: 280px;
--header-height: 60px;
--sidebar-bg: #ffffff;
--border-color: #e2e8f0; /* slate-200 */
--text-primary: #1e293b; /* slate-800 */
--text-secondary: #64748b; /* slate-500 */
--hover-bg: #f0fdfa;     /* teal-50   */
```

These tokens are already mostly representable by Tailwind classes (`text-slate-800`, `border-slate-200`, etc.). Verify the **brand teal** (#0e7490) maps to the existing `primary` colour token or update the `primary` token in [`ThemeConfig.ts`](../../../PSS_2.0_Frontend/src/application/configs/common-configs/ThemeConfig.ts) `themes` array. The mockup default theme corresponds to a "teal" not the current "blue".

---

## ⑦ Substitution Guide

There is no canonical reference layout in `.claude/screen-tracker/prompts/` — this is the FIRST layout-alignment prompt. After this completes, future shell-alignment work (e.g., a re-skinning project for a different tenant) should follow this file's structure.

Canonical files touched (treat these as the reference points, not a substitution mapping):

| Canonical | Path |
|-----------|------|
| Layout provider | `src/presentation/provider/dashboard-layout-provider.tsx` |
| Header wrapper | `src/presentation/components/layout-components/header/header.tsx` |
| Vertical header content | `src/presentation/components/layout-components/header/vertical-header.tsx` |
| Profile popover | `src/presentation/components/layout-components/header/profile-popover/index.tsx` |
| Notification button | NEW — `src/presentation/components/layout-components/header/notification-bell.tsx` (extract or add) |
| Sidebar wrapper | `src/presentation/components/layout-components/sidebar/sidebar.tsx` |
| Classic sidebar | `src/presentation/components/layout-components/sidebar/classic/index.tsx` |
| Mobile sidebar | `src/presentation/components/layout-components/sidebar/mobile-sidebar/index.tsx` |
| Sidebar logo | `src/presentation/components/layout-components/sidebar/common/logo.tsx` |
| Sidebar menu label | `src/presentation/components/layout-components/sidebar/common/menu-label.tsx` |
| Theme/sidebar defaults | `src/application/configs/common-configs/ThemeConfig.ts` |
| Sidebar store | `src/application/stores/common-stores/sidebar-store.ts` |
| Theme store | `src/application/stores/theme-stores/theme-store.ts` |
| Module layout wrapper | `src/app/[lang]/{crm|setting|organization|accesscontrol|general|reportaudit}/layout.tsx` (read-only — confirm they all mount `DashBoardLayoutProvider` indirectly) |

---

## ⑧ File Manifest

**Backend**: **none** — no entity, no GQL, no migrations, no seed.

**Frontend (modify only — no new pages):**

| File | Action | What changes |
|------|--------|--------------|
| `src/application/configs/common-configs/ThemeConfig.ts` | MODIFY | `Config.layout = "vertical"` (confirm), `Config.sidebarType = "classic"` (changed from `"popover"`). Verify or add brand teal theme to `themes[]`. |
| `src/application/stores/common-stores/sidebar-store.ts` | MODIFY | Default `sidebarType: "classic"` (currently derived from `Config.sidebarType`). Verify no stale `"popover"` persisted in user localStorage causes a stuck state — add a one-shot migration (`version: 2`) or a `useEffect` to force `"classic"` on first load post-deploy. |
| `src/presentation/provider/dashboard-layout-provider.tsx` | MODIFY | Replace four-branch content-wrapper margin block with a single `vertical+classic` branch using `ml-[280px]` / `ml-0`. Keep `horizontal` / `semibox` branches dormant only if multi-tenant whitelabeling needs them; otherwise delete. |
| `src/presentation/components/layout-components/header/header.tsx` | MODIFY | Replace `bg-card/90 backdrop-blur-lg` with brand-teal gradient. Simplify into a single default branch when `currentUserFrom === PEOPLESERVE`. |
| `src/presentation/components/layout-components/header/vertical-header.tsx` | MODIFY | Replace `MenuBar` animated hamburger + `MainLogo` + `InlineSearchBar` with: hamburger (`fas fa-bars`), logo block (heart icon + "PeopleServe 2.0" + subtitle), role badge. Keep PEOPLESERVE branch and non-PEOPLESERVE branch distinct. |
| `src/presentation/components/layout-components/header/notification-bell.tsx` | NEW | Extracted notification icon button with badge — props: `count`, `onClick`. Renders the circle 36×36 + bell icon + badge pill. Default `onClick` navigates to `/communication/notification-center`. |
| `src/presentation/components/layout-components/header/profile-popover/index.tsx` | MODIFY | Update trigger to render: avatar (initials, translucent-white on teal) + stacked name/role (hidden below 992 px). Popover content can stay unchanged. |
| `src/presentation/components/layout-components/sidebar/classic/index.tsx` | MODIFY | Width 280 px (not 248/72). Remove hover-expand-on-collapsed pattern (mockup hides sidebar fully when collapsed). Replace top logo block with section list — logo moves to header. Pin Logout to bottom (replacing or above `CopyrightItem`). |
| `src/presentation/components/layout-components/sidebar/classic/single-menu-item.tsx` | MODIFY | Style: padding 0.5625rem 1.25rem, left-border 3 px accent, hover bg `--hover-bg`, active gradient + accent text + border. |
| `src/presentation/components/layout-components/sidebar/classic/sub-menu-handler.tsx` | MODIFY | Style section header: uppercase 0.625 rem 700 letter-spacing 0.1em, chevron-down rotates -90deg when collapsed. Animate child collapse via max-height transition. |
| `src/presentation/components/layout-components/sidebar/common/menu-label.tsx` | MODIFY | Match the section-title styling (uppercase, secondary text colour). Used for `isHeader` rows. |
| `src/presentation/components/layout-components/sidebar/common/logo.tsx` | MODIFY OR DELETE | If logo moves to header (per mockup), strip the sidebar-top logo block or set it to render only when sidebarType !== "classic". |
| `src/presentation/components/layout-components/sidebar/mobile-sidebar/index.tsx` | MODIFY | Visual sync with the new classic sidebar styles (same widths, colours, footer Logout). |
| `src/presentation/components/layout-components/sidebar/classic/sidebar-logout.tsx` | NEW (or inline in `classic/index.tsx`) | Footer Logout link — `fas fa-arrow-right-from-bracket`, secondary text, hover danger red, triggers `LogoutComponent` action. |
| `src/styles/globals.css` (or `tailwind.config.ts`) | MODIFY | Add CSS custom properties listed in §⑥.E. |

**Wiring file checks (read-only — confirm no breakage):**

- Each module's [`layout.tsx`](../../../PSS_2.0_Frontend/src/app/[lang]) (`crm`, `setting`, `organization`, `accesscontrol`, `general`, `reportaudit`, `(master)`, `(member)`) — verify all mount the shell via `DashBoardLayoutProvider` (directly or via parent). Don't change these.
- [`AuthProvider`](../../../PSS_2.0_Frontend/src/presentation/provider/auth-provider.tsx) — ensure `useUserStore` is populated before header renders (avatar + name + role read from it). No change needed.
- `useMenu()` hook — verify it still drives `parentChildMenus` and feeds `useParentChildMenuStore`. Don't break the data pipeline.

**Estimated file count**: ~12 modify + 2 new (~1.5–2 hours dev, ~2 hours test).

---

## ⑨ Approval Config

Layout is a chrome — it has no menu entry, no menu code, no `MenuUrl`. There is NOTHING to insert into the menu seed for this work. Skip the approval-config seed block entirely.

If, for tracking, a row is desired in [`Pss2.0_Menus.sql`](../../../html_mockup_screens/Pss2.0_Menus.sql) so the registry stays auditable, add as:

```sql
-- Layout shell — not user-navigable, no MenuUrl
-- Optional record kept for /plan-screens parity
{
  MenuCode: "_APP_SHELL",
  MenuName: "App Shell (Chrome)",
  ParentMenuCode: NULL,
  ModuleCode: NULL,
  MenuUrl: NULL,
  GridType: NULL,
  GridFormSchema: NULL,
  IsVisible: false,
  Notes: "Internal — chrome layout for all authenticated screens. Not a navigable menu."
}
```

Default: **skip the SQL insert entirely**. Confirm with the user at build time if they want a placeholder row.

---

## ⑩ BE → FE Contract

No new BE queries.

**Existing queries consumed by the shell:**

| GQL | Source | Used by |
|-----|--------|---------|
| `parentChildMenus(moduleCode: String)` | [`gql-queries/parentchild-menu`](../../../PSS_2.0_Frontend/src/infrastructure/gql-queries) | `useMenu()` → `useParentChildMenuStore` → sidebar |
| user/session query (auth bootstrap) | wired by `AuthProvider` | `useUserStore` → header avatar/name/role |

**Potential new query (TBD)**: `myMenuTree` / `userAccessibleMenus` — returns the full menu tree for the logged-in user across ALL modules (replacing N per-module fetches). **Action for build session**: grep the `gql-queries/` and `Pss2.0_Backend/EndPoints/` folders before writing FE; if missing, defer to a follow-up backend ticket and keep the N-module-fetch fallback (one query per module on initial load — parallelized via `Promise.all`).

---

## ⑪ Acceptance Criteria

Functional:

- [ ] Header is fixed top, 60 px tall, teal gradient bg, white text.
- [ ] Header hamburger toggles sidebar; desktop collapses off-canvas, mobile opens drawer + backdrop.
- [ ] Header logo: heart icon + "PeopleServe 2.0" + "NGO Management Platform" subtitle visible at `>= 992 px`.
- [ ] Header role badge shows current user's role text in uppercase pill.
- [ ] Header notification button shows bell icon + red badge with unread count; clicking navigates to the notification screen (or hides badge when count is 0).
- [ ] Header user cluster: avatar (initials) + user name + role text (text hidden below 992 px). Click opens `ProfilePopover`.
- [ ] Sidebar is fixed left, 280 px wide, white bg, scrolls internally.
- [ ] Sidebar shows ALL section groups (Main, CRM & Contacts, Fundraising, …, Settings, Mobile App Previews) — each as a collapsible section.
- [ ] Section toggle chevron rotates -90° when collapsed; children animate max-height.
- [ ] Active menu item has accent teal left-border + tinted bg + accent text + weight 600.
- [ ] Inactive menu item hover: light-teal bg + primary text colour.
- [ ] Sidebar footer Logout link fires the existing logout flow.
- [ ] At `< 992 px`: sidebar hidden by default, hamburger opens drawer with dark backdrop, clicking a menu item closes drawer.
- [ ] Sidebar collapsed state persists across reloads.
- [ ] Content viewport reflows when sidebar collapses (desktop) and overlays under sidebar (mobile).
- [ ] Theme tokens (`--accent`, `--header-height`, `--sidebar-width`, etc.) exist as CSS custom properties or Tailwind tokens.
- [ ] No `layout: "horizontal"` or `layout: "semibox"` rendering when `currentUserFrom === PEOPLESERVE`.
- [ ] No `sidebarType: "popover"` or `"module"` rendering when `currentUserFrom === PEOPLESERVE`.
- [ ] Existing user-localStorage with stale `sidebarType: "popover"` does NOT cause a stuck/broken state on first load post-deploy (migration or runtime override).

Build:

- [ ] `pnpm tsc --noEmit` passes.
- [ ] `pnpm build` succeeds with no new warnings.
- [ ] Manual smoke: navigate from `/dashboard` → `/setting/contacttype` → `/crm/donation` and confirm chrome stays consistent (only content area changes).
- [ ] Inspect Lighthouse/DevTools at 1440, 992 (breakpoint boundary), 768, 480: chrome reflows correctly at each.
- [ ] Confirm dark-mode (if app supports it) still renders sensibly — header gradient + sidebar white may need a dark-variant pass.

---

## ⑫ Special Notes & Warnings

### Divergence from the 6 standard screen types

This is registered as `screen_type: CONFIG / config_subtype: SETTINGS_PAGE` because the six-type taxonomy does not include "LAYOUT / CHROME". The CONFIG/SETTINGS_PAGE template gives the closest skeleton (multi-section, no list-of-N, no CRUD). However:

- **No entity / EF / DTO / GQL** — unlike a real CONFIG, this screen persists nothing in the backend.
- **No save button** — unlike a real CONFIG, state mutations are immediate and partially `localStorage`-persisted via Zustand.
- **No "Reset to defaults" mutation** — no defaults to reset to (defaults live in `ThemeConfig.ts`).
- **No "Test connection" / "Regenerate" actions** — none of the CONFIG-template add-on actions apply.

**Treat the BE Developer agent's role as N/A.** This is a pure FE alignment task. Skip the Backend Developer / Solution Resolver agent spawns if `/build-screen` would otherwise spawn them — go straight to UX Architect (light) + Frontend Developer.

### Sidebar data shape mismatch — the BIG decision

The mockup flattens the menus of ALL modules into a single sidebar with grouped sections. The current `useMenu()` hook + `parentChildMenus(moduleCode)` query returns ONE module's tree at a time. **This is the riskiest part of the build.**

Two viable approaches:

1. **New BE query** — `userAccessibleMenuTree` returning the full nested menu tree for the user across all modules. Requires backend work. Cleaner.
2. **Client-side aggregation** — at app boot, fetch all 6 module trees in parallel and merge into the menu store. No backend work but more network requests.

**Recommendation**: do (2) for the FE-only ALIGN session (zero BE coupling). Open a follow-up ticket for (1) as an optimisation.

### Multi-app rendering (PEOPLESERVE vs. others)

The codebase already supports multiple "applications" via `ApplicationsEnum.PEOPLESERVE` (see [`vertical-header.tsx`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/header/vertical-header.tsx) line 21 and [`header.tsx`](../../../PSS_2.0_Frontend/src/presentation/components/layout-components/header/header.tsx)). The mockup applies specifically to PEOPLESERVE. **Do NOT delete the non-PEOPLESERVE branches**. Gate the new chrome behind `currentUserFrom === PEOPLESERVE` so the inherited DashCode template still renders for other applications.

### Notification badge service

The mockup hard-codes "23" unread notifications. The codebase does not appear to ship a `unreadNotificationCount` GQL query (verify with one grep at build time). If missing → flag as **SERVICE_PLACEHOLDER**: render the bell button without a badge, or fetch from the existing notification list query and count locally. Do not block the build on a missing backend.

### Persisted Zustand state — migration concern

`useSidebar` is `persist()`-wrapped — users have a stale `sidebarType: "popover"` (or whatever the previous default was) in their localStorage. After this change, that stale value may cause `sidebar.tsx` to dispatch to `PopoverSidebar` instead of `ClassicSidebar`. Two options:

- Bump the persist `version` and add a `migrate()` that forces `sidebarType: "classic"` for everyone (one-shot wipe).
- Add a `useEffect` in [`DashBoardLayoutProvider`](../../../PSS_2.0_Frontend/src/presentation/provider/dashboard-layout-provider.tsx) that overrides `sidebarType` to `"classic"` if `currentUserFrom === PEOPLESERVE` regardless of persisted value.

**Recommendation**: bump version + migrate (single source of truth).

### Mobile App Previews section

The mockup shows a "📱 Mobile App Previews" sidebar section with a "Preview" badge. The two mobile preview entries (Donor App Flow, Staff/Ambassador App Flow) are not in scope for PSS 2.0 (per `SKIP_MOBILE` status legend in REGISTRY.md). Either:

- Hide this section in production (and only render in a dev/staging environment).
- Render the section but mark items as `disabled` with a tooltip "Coming soon".

Confirm with the user during build session.

### Out-of-scope items

The following appear in the existing layout provider but are NOT in the mockup — leave them alone, do not delete:

- Page-transition animation (motion.div with `pageInitial / pageAnimate / pageExit`) in `LayoutWrapper`.
- `HeaderSearch` (Ctrl+K command palette) — keep wired; mockup doesn't show but it's a useful prod feature.
- `ModuleLoader` / `MenuLoader` overlay components.
- `ThemeButton` / `FullScreen` icon buttons — tuck them into the ProfilePopover dropdown (the mockup doesn't show them in the chrome but they're production-value features).

### Build session model recommendation

Per the FleetView memory policy: prefer **Sonnet** over Opus for FE-Developer spawns on this task. The work is mostly Tailwind class rewrites and a few component refactors — Opus is overkill.

---

## Tasks

### Planning
- [x] Read mockup
- [x] Diff against existing chrome (header / sidebar / content)
- [x] Identify the multi-layout / multi-sidebar variants to lock down
- [x] Identify menu data-shape mismatch (per-module vs. all-modules)
- [x] Compute file manifest
- [x] Document service-placeholder for notification count

### Generation — Session 1 (Settings hydration + per-user override) — DONE
- [x] Write idempotent seed SQL for SettingGroup + 9 OrganizationSettings with CanUserOverride=true
- [x] BE: extend `GetSettingGroupByCodeHandler` to filter `UserSettings` by current user
- [x] FE: add CREATE / UPDATE / DELETE `UserSettingMutation`
- [x] FE: add `useUpsertUserSetting` hook
- [x] FE: extend `IThemeCustomizerSTORE` with per-user `userSettings` map + setters
- [x] FE: update `useThemeCustomization` to apply 3-tier resolution (user > org current > org default)
- [x] FE: rewire `ThemeCustomize` save → UserSettings; reset → DELETE user rows

### Generation — Session 2 (Visual restyle) — PENDING
- [ ] Lock `Config.sidebarType = "classic"` + add Zustand migration
- [ ] Apply CSS custom-property tokens (header height, sidebar width, accent, etc.)
- [ ] Restyle Header → teal gradient + logo + role badge + notification + avatar+user-info
- [ ] Extract NotificationBell component (new file)
- [ ] Update ProfilePopover trigger to render avatar + name + role
- [ ] Restyle ClassicSidebar → 280 px white + accordion sections + accent left-border + footer logout
- [ ] Aggregate menus across all 6 modules in `useMenu()` (Promise.all fan-out) or wire a new full-tree query if present
- [ ] Update DashBoardLayoutProvider content-wrapper to single 280/0 branch
- [ ] Restyle MobileSidebar to match
- [ ] Hide / disable "Mobile App Previews" section per user preference

### Verification
- [ ] `pnpm tsc --noEmit`
- [ ] `pnpm build`
- [ ] Manual smoke at 1440 / 992 / 768 / 480 widths
- [ ] Verify stale localStorage `sidebarType` is migrated
- [ ] Verify Logout, navigation, active state, section toggle all work
- [ ] Verify notification badge hides when count is 0
- [ ] Verify dark mode (if supported) still renders sensibly
- [ ] Confirm `currentUserFrom !== PEOPLESERVE` branches still work for non-PSS apps

---

## Known Issues

| Issue ID | Status | Description |
|----------|--------|-------------|
| ISSUE-1 | OPEN | Visual restyle from §⑥ deferred — header gradient, 280 px classic sidebar, accordion sections, footer logout, cross-module menu aggregation NOT yet applied. Existing chrome (DashCode template) still renders. |
| ISSUE-2 | OPEN | DB seed `app-layout-themecustomizer.sql` written but NOT yet applied to live database. Must be run manually before per-user override flow can be tested. |
| ISSUE-3 | OPEN | BUSINESSADMIN role capability for `USERSETTING` menu (CREATE/MODIFY/DELETE) not verified. If missing, ThemeCustomizer save will 401. Confirm via `auth.RoleCapability` rows for MenuId=440 before testing. |

---

## Build Log

### § Sessions

### Session 1 — 2026-05-19 — BUILD — PARTIAL

- **Scope**: Initial settings hydration + per-user override wiring (Phase A of two-phase plan). Visual restyle from §⑥ deferred to Session 2.
- **User directive override**: prompt was registered as ALIGN / no-entity, but user supplied `settings-records.sql` + directive "render based on these settings, user can overwrite". Scope expanded to seed-the-settings + wire per-user override layer, while keeping `[[feedback-align-no-entity-changes]]` honored (no new tables/columns, only seed data + one handler tweak + FE wiring).
- **Files touched**:
  - BE: `Pss2.0_Backend/.../SettingBusiness/SettingGroups/Queries/GetSettingGroupByCode.cs` (modified — inject `IHttpContextAccessor`, filter `UserSettings` by current user).
  - FE: `src/infrastructure/gql-mutations/setting-mutations/UserSettingMutation.ts` (created — CREATE/UPDATE/DELETE).
  - FE: `src/infrastructure/gql-mutations/setting-mutations/index.ts` (modified — export new mutations).
  - FE: `src/presentation/hooks/useThemeCustomizer/useUpsertUserSetting.ts` (created — upsert+delete hook).
  - FE: `src/presentation/hooks/useThemeCustomizer/index.ts` (modified — export new hook).
  - FE: `src/presentation/hooks/useThemeCustomizer/useThemeCutomization.ts` (modified — 3-tier resolution: user > org current > org default).
  - FE: `src/application/stores/theme-stores/themecustomizer-istore.ts` (modified — add `userSettings` map + setters).
  - FE: `src/application/stores/theme-stores/themecustomizer-store.ts` (modified — store impl).
  - FE: `src/presentation/components/layout-components/customizer/theme-customizer.tsx` (modified — save → UserSettings; reset → DELETE).
  - FE: `src/domain/entities/setting-service/UserSettingDto.ts` (modified — `userId` made optional; server resolves from JWT).
  - DB: `.claude/screen-tracker/seed-scripts/app-layout-themecustomizer.sql` (created — idempotent seed, NOT yet applied to live DB).
- **Deviations from spec**:
  - Original prompt §② said "no entity / no save / no GQL / no migration". Session 1 still adds NO entity / NO migration, but DOES seed existing tables (`sett.SettingGroups`, `sett.OrganizationSettings`) and DOES persist user overrides via the existing `sett.UserSettings` table + existing `createUserSetting`/`updateUserSetting`/`deleteUserSetting` mutations. Existing FE customizer was already partially wired to OrgSettings; this session retargets save path to UserSettings.
  - Original prompt §⑥ visual restyle (teal gradient header, 280 px classic sidebar, accordion sections, footer logout, cross-module menu aggregation) is NOT in this session — intentionally deferred per user scope decision.
- **Known issues opened**: ISSUE-1, ISSUE-2, ISSUE-3 (see Known Issues table above).
- **Known issues closed**: None.
- **Verification**:
  - `dotnet build` Base.Application — 0 errors (513 unrelated warnings, pre-existing).
  - `pnpm tsc --noEmit` — 0 errors in any changed file (filtered grep confirms). Pre-existing project errors elsewhere not introduced by this session.
  - End-to-end manual smoke deferred until seed is applied to live DB.
- **Next step**: Apply `.claude/screen-tracker/seed-scripts/app-layout-themecustomizer.sql` to the live DB; verify ThemeCustomizer renders + saves a per-user override; then resume Session 2 for visual restyle from §⑥.
