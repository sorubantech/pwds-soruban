---
screen: MasterDashboard
registry_id: 174
module: Root (Post-Auth Landing)
status: COMPLETED
scope: FE_ONLY
screen_type: MASTER_LANDING
landing_subtype: MODULE_LAUNCHER   # bespoke — new sub-type, divergence noted §⑫
complexity: Medium
new_module: NO
planned_date: 2026-05-20
completed_date: 2026-05-20
last_session_date: 2026-05-20
---

# Screen #174 — Master Dashboard (Post-Auth Module Launcher)

## ① Identity & Context

**Authenticated post-login landing surface** for the PSS 2.0 multi-tenant NGO platform. After login completes (#119), every user lands here at `/{lang}/masterdashboard` before navigating into a specific module. Unlike a CRUD dashboard, this screen has **no aggregated metrics** — it is the **module launcher** + **help/support entry point** for the application shell.

**Where it sits in the app**:
- Route: [`PSS_2.0_Frontend/src/app/[lang]/(master)/masterdashboard/page.tsx`](../../../PSS_2.0_Frontend/src/app/[lang]/(master)/masterdashboard/page.tsx)
- Layout group: `(master)` — separate from the main `(app)` shell. The `(master)` layout strips the sidebar and main-app chrome so the user sees a clean module-picker.
- Component tree: [`presentation/pages/master/landing-page/index.tsx`](../../../PSS_2.0_Frontend/src/presentation/pages/master/landing-page/index.tsx) → renders `<LandingHeader />` + `<LandingContent />` + `<LandingFooter />`
- Layout wraps `RouteGuard requireAuth={true}` + `CompanySettingsBootstrap` (already in `(master)/layout.tsx`)

**End-to-end flow today** (Wave 0 — already shipping):

```
user logs in (#119)  →  NextAuth session  →  router.push("/{lang}/masterdashboard")
                                                       ↓
                                              (master)/layout.tsx
                                                       ↓
                                  RouteGuard + CompanySettingsBootstrap
                                                       ↓
                                  page.tsx → <MasterLandingPageConfig />
                                                       ↓
                                  fetches USER_ROLE_MODULES (GQL) →
                                  renders Modules list + Help & Support tabs
                                                       ↓
                       user clicks "Open Module" → setModuleId/Code/Name/Url +
                       loadCapabilitiesForModule → router.push("/{lang}/{moduleUrl}")
```

**Why this screen matters**: First **branded** impression after login. The tenant's NGO name, logo, and accent colors should feel native — not a generic "PSS Donor Management System" string. It also serves as the always-available entry point for in-product support and AI Q&A (replacing the "Coming Soon" placeholder).

**In scope (this build, all FE-only)**:
1. **AI Assistant tab** — replace the "Coming Soon" placeholder with a functional chat UI. Wire the send handler as a `SERVICE_PLACEHOLDER` until the dedicated AIDA chat mutation lands (AIDA infrastructure exists in BE — `OpenAIAdapter` / `AnthropicAdapter` / `IModelClient` — but only `askGrid` is exposed today, not a generic landing-page chat surface).
2. **Personal greeting + recent activity** — replace hardcoded hero with "Good {morning/afternoon/evening}, {firstName}" + last-5-visited modules chip row, all sourced from existing session + `localStorage`.
3. **Tenant branding (hero copy + accent)** — replace hardcoded `"Donor Management System"` hero title with `companySettings.companyName` from `useCompanySettingsSession`; keep platform branding ("PeopleServe") in the footer.
4. **Clean up template leftovers** — delete orphan `contact.tsx`, orphan `header/nav-menu.tsx`, and the entire `data.ts` (`demoMenus` + `menus` from the DashTail starter template — never referenced anywhere user-facing). Strip the mobile hamburger that renders those stale links.

**Out of scope (deferred)**:
- New BE entity / mutation. AI Assistant wiring is a placeholder this build; BE chat mutation is a separate ticket.
- A new `OrganizationSettings` BRANDING paramcode for "hero tagline" — defer until product needs per-tenant hero copy.
- The bespoke "What you can do" section is not part of this surface (already exists inline in module-detail panel as "Capabilities").
- Persisting recent-activity across devices (FE uses `localStorage` only this build; BE persistence is a future ticket — see ISSUE entries §⑫).
- Mobile-specific redesign — the existing responsive layout is preserved as-is.

---

## ② Storage & Source Model

**No new entity. No BE changes in this build.** Everything is sourced from existing entities and client-side state.

### 2a. Data sources read by this screen

| Source | Type | Read via | Used for |
|--------|------|----------|----------|
| `USER_ROLE_MODULES` query | Apollo GQL (existing) | [`infrastructure/gql-queries/auth-queries/ModuleQuery.ts`](../../../PSS_2.0_Frontend/src/infrastructure/gql-queries/auth-queries/ModuleQuery.ts) | Module list (left panel) — what modules the user can launch |
| `useCompanySettingsSession` | Zustand session store (existing) | [`application/stores/global-stores/company-settings-session-store.ts`](../../../PSS_2.0_Frontend/src/application/stores/global-stores/company-settings-session-store.ts) | `companyName` for hero, `dateFormat` / `timeFormat` for greeting timestamp |
| `useUserStore` | Zustand persisted store (existing) | [`application/stores/auth-stores/user-store.ts`](../../../PSS_2.0_Frontend/src/application/stores/auth-stores/user-store.ts) | `userInfo.userName` / `userInfo.designation` for personal greeting |
| `useSession` | NextAuth (existing) | `getSession()` / `useSession()` | Auth token for `sendSupportQueryEmail` mutation; user's email |
| `recent-activity.ts` | New FE util — `localStorage` | NEW `presentation/pages/master/landing-page/recent-activity.ts` | Last-5-visited modules (chip row + ordering hint) |
| `sendSupportQueryEmail` mutation | Apollo GQL (existing) | Wired inline in `content.tsx`'s `SupportQueryTab` — unchanged | Technical Support tab (already functional) |

### 2b. New FE-only state (no BE)

| Name | Storage | Shape | Lifecycle |
|------|---------|-------|-----------|
| `pss:recent-modules` | `localStorage` (per-browser) | `Array<{ moduleCode: string; moduleName: string; moduleIcon: string; moduleUrl: string; visitedAt: number }>` (max length 5, FIFO eviction by `visitedAt`) | Written by `handleModule` callback when user clicks "Open Module"; read on landing-page mount. Cleared on signout (`reset()` chained into the existing logout flow). |

### 2c. No new GQL schema, no migration, no seed

This is the FE-only delivery surface. The Build Log should explicitly verify no new BE files were touched.

---

## ③ FK Resolution Table

This screen has **no FK pickers**, **no entity form**, **no grid filter**. The only "FK" is the user → module relationship, already resolved server-side in `USER_ROLE_MODULES`. Table is intentionally empty.

| FK | Target | Notes |
|----|--------|-------|
| n/a | n/a | No client-side FK lookups. Module list comes pre-joined from `USER_ROLE_MODULES`. |

---

## ④ Business Rules & Validation

### 4a. Personal greeting

| Rule | Detail |
|------|--------|
| Time-of-day bucketing | `< 12:00` → "Good morning". `12:00 – 16:59` → "Good afternoon". `17:00 – 23:59` → "Good evening". Computed in the user's local browser timezone — **not** in tenant `defaultTimezone`. (Greeting is about *now in this browser*, not tenant-locale.) |
| Name source priority | (1) `userStore.userInfo.firstName` if non-empty → (2) first token of `userStore.userInfo.userName` before `@` (e.g., `john.doe@ngo.org` → `john.doe` → display `John Doe` via title-case + dot-split) → (3) `"there"` as last resort. |
| Re-render on tab refocus | The greeting must re-evaluate `time-of-day` when the tab refocuses (event: `visibilitychange`) — long-running tab from morning into afternoon must update the greeting label. |
| Empty session | If session is loading / null, render greeting skeleton (one-line shimmer 200px wide). Never render the literal string `"Good morning, undefined"`. |

### 4b. Tenant-branded hero

| Rule | Detail |
|------|--------|
| Source field | `useCompanySettingsSession().settings?.companyName`. |
| Fallback | If `settings` is `null` (bootstrap still hydrating) → render shimmer skeleton (same 240px-wide treatment as the greeting line). If `settings.companyName` is empty → fallback to `"your organization"`. **Never** render the literal "undefined" or fall back to "PeopleServe" (PeopleServe is the platform brand, kept in footer only). |
| Footer brand | `"© {currentYear} PeopleServe. All rights reserved."` — **stays hardcoded**. PeopleServe is the SaaS provider, not the tenant. |
| Logo source | Already handled by `<SidebarLogo />` (reads tenant logo via existing bootstrap path). No change here. |

### 4c. Recent activity (localStorage-backed)

| Rule | Detail |
|------|--------|
| Write moment | `handleModule(module)` (existing callback in `content.tsx`) — push the module entry **before** `router.push(...)`. Use a try/catch so a failed `localStorage.setItem` (quota / private-mode) never blocks navigation. |
| Read moment | On `LandingContent` mount, read once into local component state. Never read in render. |
| Capacity | 5 entries max. New entries upsert (move to top if `moduleCode` already exists). FIFO evict the oldest (smallest `visitedAt`). |
| Cleared on signout | `useUserStore` reset must also call the new `clearRecentModules()` util. Sign-out path is in the existing `<Logout />` component — modify it (or add a subscriber) to chain the clear. |
| Cross-account safety | Key is `pss:recent-modules` (NOT scoped by user). Acceptable for a single-user dev/staging laptop; documented as ISSUE in §⑫ for multi-account browsers (future BE-backed implementation). |
| Storage key namespace | Prefix `pss:` to match the existing `pss:company-settings-session` convention. |

### 4d. AI Assistant chat (SERVICE_PLACEHOLDER)

| Rule | Detail |
|------|--------|
| Send handler | Wired to a local `Promise.resolve()` + 600ms simulated latency that appends an assistant message: `"AI Assistant is wired but waiting for the AIDA chat mutation to land — track ISSUE-1 / future #ASKAIDA. Your question was: \"{userText}\""`. **Do not** call any real GQL mutation in this build. |
| Toast on first send | First send of the session shows a toast: `"AI Assistant is in preview — your messages are not sent to a backend yet."` (Suppress on subsequent sends in the same session — use a ref to gate.) |
| Local message history | Hold messages in component-local `useState<Message[]>`. **No** localStorage persistence (gets cleared on remount / signout). |
| Empty state | First render with no messages: show the existing "Coming Soon" iconography but with the input field already enabled. Replace the literal "Coming Soon" badge with a smaller `Preview` chip. |

### 4e. Cleanup deletions are real, not commented-out

| File | Why it's safe to delete |
|------|------------------------|
| `contact.tsx` | Grep confirmed: not imported anywhere in the project (only path-listed in this folder). Uses `<Card>` + dummy `freshdesk` link — DashTail template residue. |
| `header/nav-menu.tsx` | Imported only by `header/index.tsx` (mobile branch currently uses `menus` from `data.ts`, NOT `<NavMenu>`). Verify with grep before delete. |
| `data.ts` | Exports `demoMenus` + `menus`. Grep first — if anything imports `menus` (other than the mobile hamburger we're also stripping), surface in the Build Log before deleting. `demoMenus` is the DashTail screenshot-gallery navigation — absolutely no business value. |

> **CRITICAL**: Build the Build Log entry with `git ls-files` + grep evidence that each deletion has zero remaining references before committing. If a stray reference exists, leave the file alone and log an ISSUE — don't try to "fix" the stray.

---

## ⑤ Screen Classification

**Type**: `MASTER_LANDING` (bespoke — NEW, not one of the 7 canonical types: MASTER_GRID / FLOW / DASHBOARD / REPORT / CONFIG / EXTERNAL_PAGE / AUTH).

**Why bespoke**: This screen has no list-of-N records (not MASTER_GRID/FLOW), no aggregated KPI grid (not DASHBOARD — there are no metrics), no filter+export (not REPORT), no single-config-record (not CONFIG — `USER_ROLE_MODULES` returns a per-user view but is not a tenant-config record), no anonymous public surface (not EXTERNAL_PAGE — it's behind `RouteGuard`), and not an auth screen (not AUTH — login is already completed). Shoehorning it into DASHBOARD would mislead future agents because the `_DASHBOARD.md` template prescribes widget grids + KPI cards + chart drill-downs that this screen explicitly does NOT have.

**Sub-pattern stamp**: `MODULE_LAUNCHER` — first canonical of this sub-pattern. Future post-auth landings in different shells (e.g., a "Volunteer Portal" landing or a "Donor Portal" landing) should reuse this template.

**Pattern checklist** (pre-answered for Solution Resolver):

| Question | Answer |
|----------|--------|
| Has a list grid? | No |
| Has a modal form? | No |
| Has 3-mode URL view? | No |
| Has KPI widgets? | No |
| Has filter panel + export? | No |
| Has Publish/Unpublish lifecycle? | No |
| Is anonymous-accessible? | **No** (RouteGuard required) |
| Is multi-tenant by hostname? | No (post-auth — tenant resolved from session) |
| Needs SSR? | No (post-auth, client-only is fine; the existing `"use client"` page is correct) |
| Needs new entity? | No |
| Needs migration? | No |
| Needs DB seed? | No |
| Needs new GQL query/mutation? | No (reuses `USER_ROLE_MODULES` + `sendSupportQueryEmail` + reads `useCompanySettingsSession` + `useUserStore`) |

**Save model**: Read-only with respect to BE. Writes are local: (a) `localStorage` recent-modules push on navigation, (b) `useState` AI Assistant messages — neither persists to BE.

**Lifecycle**: Stateless per visit. Re-rendered on every navigation back to `/masterdashboard`. ISR not applicable (client component).

---

## ⑥ UI/UX Blueprint

> This screen exists as a working FE today. The blueprint below is a **delta description** — what changes from the current implementation. Open the current code while reading: [`content.tsx`](../../../PSS_2.0_Frontend/src/presentation/pages/master/landing-page/content.tsx), [`header/index.tsx`](../../../PSS_2.0_Frontend/src/presentation/pages/master/landing-page/header/index.tsx).

### 6a. Layout topology (UNCHANGED structure, deltas inside)

```
┌─ <LandingHeader />  (fixed top, h-14)                           ┐
│  desktop: SidebarLogo · spacer · ThemeButton · Logout            │
│  mobile:  SidebarLogo · ThemeButton · Logout                     │  ← strip hamburger menu
└──────────────────────────────────────────────────────────────────┘
┌─ HERO SECTION  (full-width, px-5)                                ┐
│  "Good {bucket}, {firstName}"            ← NEW: personalized      │
│  "{tenantName} — manage your day from one place."  ← NEW: branded │
│                                                                    │
│  Recently visited:  [Donations] [Members] [Events]  ← NEW chip row│
└──────────────────────────────────────────────────────────────────┘
┌─ CONTAINER (mx-auto px-4 sm:px-8 w-[95%])                        ┐
│  ┌─ LEFT 7/12 (Modules) ─────────┐  ┌─ RIGHT 5/12 (Help) ─────┐  │
│  │  SectionLabel "Modules"      │  │ SectionLabel "Help & ..."│  │
│  │  ┌─ list 40% ┐ ┌─ detail 60% │  │ Tabs:                    │  │
│  │  │ Active    │ │ Header      │  │ ┌ AI Assistant ┐         │  │
│  │  │ Module 1  │ │ Description │  │ │ chat UI      │  ← NEW  │  │
│  │  │ Module 2  │ │ Highlights  │  │ │ msg list +   │         │  │
│  │  │ Module 3  │ │ Capabilities│  │ │ input + send │         │  │
│  │  │ ...       │ │ Open Module │  │ └──────────────┘         │  │
│  │  └───────────┘ └─────────────┘  │ ┌ Technical Support ─┐   │  │
│  │                                  │ │ existing form      │   │  │
│  │                                  │ └────────────────────┘   │  │
│  └────────────────────────────────┘ └──────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
┌─ <LandingFooter />  (border-t, gradient bg)                      ┐
│  "© {year} PeopleServe. All rights reserved." · Privacy · v2.0   │
└──────────────────────────────────────────────────────────────────┘
```

**Mobile** stacks LEFT 7/12 above RIGHT 5/12. Hamburger menu is REMOVED (no more `<NavMenu>` / `menus`).

### 6b. Delta — Hero section (replaces current "Donor Management System" block)

Current code: [`content.tsx:798-836`](../../../PSS_2.0_Frontend/src/presentation/pages/master/landing-page/content.tsx#L798-L836) renders a static `<h3>Donor Management System</h3>` + `<p>` tagline.

**Replace** with a new client-only sub-component `<PersonalizedHero />` placed at the same location:

```tsx
function PersonalizedHero() {
  const { userInfo } = useUserStore();
  const settings = useCompanySettingsSession((s) => s.settings);
  const recent = useRecentModules();  // hook from new recent-activity.ts

  const greeting = useTimeOfDayGreeting();  // returns "Good morning"/"afternoon"/"evening"
  const firstName = deriveFirstName(userInfo); // §4a fallback chain

  return (
    <section className="px-5">
      <h1 className="text-xl sm:text-2xl font-bold text-foreground tracking-tight">
        {firstName ? `${greeting}, ${firstName}` : <SkeletonLine width="240px" />}
      </h1>
      <p className="text-[13px] text-muted-foreground mt-1">
        {settings?.companyName
          ? `${settings.companyName} — manage your day from one place.`
          : <SkeletonLine width="320px" />}
      </p>
      {recent.length > 0 && (
        <div className="mt-3 flex items-center gap-2 flex-wrap">
          <span className="text-[11px] text-muted-foreground uppercase tracking-wider">
            Recently visited
          </span>
          {recent.map((m) => (
            <RecentChip key={m.moduleCode} module={m} />
          ))}
        </div>
      )}
    </section>
  );
}
```

`<RecentChip>` renders the module icon + name in a small pill that, on click, calls `handleModule(m)` from the parent — same flow as clicking the module in the left list. Border style: `border border-border rounded-full px-2.5 py-1`, icon-left, hover bg-muted.

Animation: the hero block can keep the existing motion.section wrapper (initial-fade-down) — wrap `<PersonalizedHero />` inside it.

### 6c. Delta — `AiAssistantTab` becomes `<AiAssistantChat />`

Current code: [`content.tsx:357-377`](../../../PSS_2.0_Frontend/src/presentation/pages/master/landing-page/content.tsx#L357-L377) renders the static "Coming Soon" card.

**Replace** the function body entirely with a new chat UI (still inside the same `<TabsContent value="ai-assistant">`):

```
┌─ Tab content (h-full) ──────────────────────────────────────┐
│ messages list  (flex-1 overflow-y-auto, vertical-stack)     │
│   ┌─ assistant message (left-align, muted bg, rounded-lg) ┐ │
│   ┌─ user message (right-align, primary bg, rounded-lg)   ┐ │
│   ...                                                       │
│ ───────────────────────────────────────────────────────────  │
│ ┌─ input row (border-t, p-3) ─────────────────────────────┐ │
│ │  <Textarea rows=2> placeholder "Ask anything..." │ Send │ │
│ └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

**Message shape** (TS type):
```ts
type Message = {
  id: string;          // crypto.randomUUID()
  role: "user" | "assistant";
  content: string;
  timestamp: number;
};
```

**Send handler** (SERVICE_PLACEHOLDER):
```ts
async function handleSend() {
  if (!input.trim()) return;
  const userMsg: Message = { id: randomUUID(), role: "user", content: input, timestamp: Date.now() };
  setMessages(prev => [...prev, userMsg]);
  setInput("");
  if (!firstSendShownRef.current) {
    toast.info("AI Assistant is in preview — your messages are not sent to a backend yet.");
    firstSendShownRef.current = true;
  }
  setIsThinking(true);
  await new Promise(r => setTimeout(r, 600));
  const reply: Message = {
    id: randomUUID(),
    role: "assistant",
    content: `AI Assistant is wired but waiting for the AIDA chat mutation to land — track ISSUE-1. Your question was: "${userMsg.content}"`,
    timestamp: Date.now(),
  };
  setMessages(prev => [...prev, reply]);
  setIsThinking(false);
}
```

**Thinking indicator**: while `isThinking`, render an assistant-aligned typing-dots bubble (3 dots, css animation `keyframes pulse`). Reuse `DynamicIcon icon="solar:spinner-bold-duotone"` if a quick fallback is needed.

**Auto-scroll**: on new message, scroll the messages container to bottom (`ref.current.scrollTop = ref.current.scrollHeight`).

**Empty state**: when `messages.length === 0`, render a smaller, less screaming version of the current "Coming Soon" card:
- Icon: `solar:chat-round-dots-bold-duotone` (unchanged)
- Badge: replace `Coming Soon` chip with `Preview` chip (amber → blue)
- Headline: "AI Assistant" (unchanged)
- Body: "Ask anything about your data — receipts, donors, campaigns. Currently in preview; responses are placeholders until the AIDA chat mutation lands."
- The input field is **enabled** in the empty state (current placeholder isn't — that's the key UX delta).

**Keyboard shortcut**: `Enter` sends; `Shift+Enter` inserts newline. Match the existing Technical Support `<Textarea>` behavior so the two tabs feel consistent.

### 6d. Delta — Header mobile branch loses hamburger

Current code: [`header/index.tsx:27-138`](../../../PSS_2.0_Frontend/src/presentation/pages/master/landing-page/header/index.tsx#L27-L138) — the mobile `if (!isDesktop)` branch renders a hamburger button + dropdown with `menus` items (`Elements`, `Why Dash Tail`, `Pricing`, `More` — DashTail starter residue).

**Replace** the mobile branch with the same chrome as the desktop branch (just logo + theme + logout). The mobile-specific hamburger and its dropdown are deleted. After this change, both branches converge on a single render path:

```tsx
return (
  <div className="fixed top-0 left-0 w-full h-14 z-50 flex items-center bg-gradient-to-r from-primary/10 via-primary/5 to-blue-500/10 dark:from-primary/15 dark:via-primary/8 dark:to-blue-500/15 backdrop-blur-md border-b border-primary/15 dark:border-primary/20 transition-all duration-300 {scroll && 'shadow-sm'}">
    <nav className="mx-auto w-full px-4 sm:px-8 flex justify-between items-center">
      <SidebarLogo />
      <div className="flex items-center gap-2">
        <ThemeButton />
        <Logout />
      </div>
    </nav>
  </div>
);
```

`useMediaQuery` import + the entire mobile branch + `menus` import + `useState<open|show>` go away. `useEffect` for scroll listener stays.

### 6e. Delta — Cleanup deletions

| File | Action |
|------|--------|
| `presentation/pages/master/landing-page/contact.tsx` | DELETE |
| `presentation/pages/master/landing-page/header/nav-menu.tsx` | DELETE |
| `presentation/pages/master/landing-page/data.ts` | DELETE |

Pre-flight grep before each delete (mandatory):

```bash
# Run from PSS_2.0_Frontend/
rg -t tsx -t ts "from .*landing-page/contact"
rg -t tsx -t ts "from .*header/nav-menu"
rg -t tsx -t ts "from .*landing-page/data"
```

All three MUST return zero matches outside the files being deleted (and inside `header/index.tsx`, which we are concurrently modifying to drop the `menus` import). If any external file imports them, **stop**, surface in the Build Log, and adjust — do not silently leave dead code.

### 6f. New file — `recent-activity.ts`

Path: `presentation/pages/master/landing-page/recent-activity.ts`

```ts
import { useEffect, useState } from "react";

const KEY = "pss:recent-modules";
const MAX = 5;

export interface RecentModule {
  moduleCode: string;
  moduleName: string;
  moduleIcon: string;
  moduleUrl: string;
  visitedAt: number;
}

function read(): RecentModule[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.slice(0, MAX) : [];
  } catch { return []; }
}

function write(list: RecentModule[]) {
  if (typeof window === "undefined") return;
  try { window.localStorage.setItem(KEY, JSON.stringify(list.slice(0, MAX))); } catch {}
}

export function pushRecentModule(m: Omit<RecentModule, "visitedAt">) {
  const list = read().filter(x => x.moduleCode !== m.moduleCode);
  list.unshift({ ...m, visitedAt: Date.now() });
  write(list);
}

export function clearRecentModules() {
  if (typeof window === "undefined") return;
  try { window.localStorage.removeItem(KEY); } catch {}
}

export function useRecentModules(): RecentModule[] {
  const [items, setItems] = useState<RecentModule[]>([]);
  useEffect(() => {
    setItems(read());
    const onStorage = (e: StorageEvent) => { if (e.key === KEY) setItems(read()); };
    window.addEventListener("storage", onStorage);
    return () => window.removeEventListener("storage", onStorage);
  }, []);
  return items;
}
```

`handleModule` in `content.tsx` calls `pushRecentModule({ moduleCode, moduleName, moduleIcon, moduleUrl })` right before `router.push(...)`.

Signout integration: the existing `<Logout />` component (in `presentation/components/layout-components/header/logout`) — call `clearRecentModules()` in its click handler, alongside the existing session/store resets. If the component is shared across many surfaces and modifying it feels risky, expose the clear as part of the existing `useUserStore.setUserInfo({})` reset path; add a comment linking to this prompt.

### 6g. New file — `ai-assistant-chat.tsx`

Path: `presentation/pages/master/landing-page/ai-assistant-chat.tsx`

Self-contained component implementing §6c. Exports default `<AiAssistantChat />`. Imports: `Button`, `Textarea` from `common-components`; `DynamicIcon`; `toast` from `sonner`; `cn` from `presentation/utils`. **No GQL imports** (SERVICE_PLACEHOLDER).

Replace the inline `<AiAssistantTab />` usage in `content.tsx` line ~927 with `<AiAssistantChat />`. The current `AiAssistantTab` function definition (lines 357-377) is then deleted.

### 6h. Theme & spacing notes

- Reuse all existing Tailwind tokens. **No new design tokens, no new colors.**
- The AI Assistant chat input must keep the same height as the Technical Support form's `<Input>` (`h-9`, `text-[13px]`) so the two tabs feel symmetrical.
- The hero personalization fits in the existing motion.section's padding — no layout shift expected.
- Recent-visited chips use `px-2.5 py-1 text-[11px] rounded-full border border-border` to match the existing module-card "Active / Locked" pill weight.

### 6i. Layout variant stamp

Layout: `widgets-above-grid` does NOT apply (no grid). Use bespoke `module-launcher` variant. `<ScreenHeader />` is NOT used on master dashboard (the `(master)/layout.tsx` is pass-through; no app shell sidebar; LandingHeader is its own chrome).

---

## ⑦ Substitution Guide

This is the **first MASTER_LANDING screen** — establishes the canonical pattern for future Landing siblings.

| Aspect | This screen (canonical) |
|--------|------------------------|
| Entity (canonical name) | n/a — no entity. Reads existing `Module` (USER_ROLE_MODULES) + `CompanySettings` + `User`. |
| Schema | n/a |
| Group | n/a |
| Page route | `/{lang}/masterdashboard` (existing) |
| Page folder | `src/app/[lang]/(master)/masterdashboard/` (existing) |
| Presentation folder | `src/presentation/pages/master/landing-page/` (existing) |
| Helper utils folder | `src/presentation/pages/master/landing-page/` for `recent-activity.ts` — co-located, intentionally not promoted to `application/utils/` until a second consumer appears (YAGNI) |
| Parent menu code | n/a (no menu — post-login route, lives outside the standard sidebar) |
| Module code | n/a (Root, not under any module) |
| Layout group | `(master)` — distinct from `(app)` and `(auth)` and `(public)`. Future portal landings (donor portal, volunteer portal) may use their own layout group with a similar shape. |

Future Landing siblings (e.g., Donor Portal landing, Volunteer Portal landing, Staff Portal landing if added):
- Replicate the personalized-hero + recent-chip-row pattern.
- Reuse `useTimeOfDayGreeting` and `deriveFirstName` (consider promoting them to `application/utils/personalization/` when the second consumer appears).
- Tenant branding via `useCompanySettingsSession.settings.companyName` is the canonical pattern.
- AI Assistant chat with SERVICE_PLACEHOLDER until #ASKAIDA lands (see ISSUE-1).

---

## ⑧ File Manifest

### Backend (`PSS_2.0_Backend/PeopleServe/Services/Base/`)

| # | File | Action | Notes |
|---|------|--------|-------|
| — | — | — | **No BE changes in this build.** Verify with `git status` against `PSS_2.0_Backend/` after build — should show zero modified files. |

### Frontend (`PSS_2.0_Frontend/src/`)

| # | File | Action | Notes |
|---|------|--------|-------|
| 1 | `presentation/pages/master/landing-page/content.tsx` | MODIFY | Big edit: replace hardcoded hero with `<PersonalizedHero />`; swap `<AiAssistantTab />` for `<AiAssistantChat />`; remove the inline `AiAssistantTab` function definition (lines ~357-377); inside `handleModule`, call `pushRecentModule(...)` right before `router.push`; import `useCompanySettingsSession`, `pushRecentModule`, `useRecentModules`, `useTimeOfDayGreeting`, `deriveFirstName`, `<AiAssistantChat />`. SupportQueryTab function is UNCHANGED. |
| 2 | `presentation/pages/master/landing-page/recent-activity.ts` | NEW | Per §6f — read/write/push/clear + `useRecentModules` hook. |
| 3 | `presentation/pages/master/landing-page/ai-assistant-chat.tsx` | NEW | Per §6c, §6g — full chat UI with placeholder handler. Local message state only. |
| 4 | `presentation/pages/master/landing-page/personalization.ts` | NEW | Pure utils: `useTimeOfDayGreeting()` (returns `"Good morning"/"afternoon"/"evening"`, listens to `visibilitychange`) + `deriveFirstName(userInfo)` (§4a fallback chain). Co-located here for now per §⑦. |
| 5 | `presentation/pages/master/landing-page/header/index.tsx` | MODIFY | Collapse mobile + desktop branches into single render path; drop `useMediaQuery`, `useState<open/show>`, `menus` import; remove the entire mobile hamburger dropdown. Keep the scroll listener. |
| 6 | `presentation/pages/master/landing-page/contact.tsx` | DELETE | Orphan — pre-flight grep required. |
| 7 | `presentation/pages/master/landing-page/header/nav-menu.tsx` | DELETE | Orphan — pre-flight grep required. |
| 8 | `presentation/pages/master/landing-page/data.ts` | DELETE | Orphan — pre-flight grep required. |
| 9 | `presentation/components/layout-components/header/logout/*` (path TBD by grep) | MODIFY (small) | In the logout click handler, call `clearRecentModules()` from `recent-activity.ts`. If the component is shared across many surfaces, prefer chaining the clear via `useUserStore`'s reset (set a side-effect callback). Document the choice in the Build Log. |
| 10 | `presentation/pages/master/landing-page/index.tsx` | NO CHANGE | The wrapper that calls `useMounted` + renders header/content/footer is fine as-is. |
| 11 | `presentation/pages/master/landing-page/loader.tsx` | NO CHANGE | Loader unchanged. |
| 12 | `presentation/pages/master/landing-page/footer.tsx` | NO CHANGE | Footer "PeopleServe" string is intentional (platform brand, not tenant). |
| 13 | `app/[lang]/(master)/masterdashboard/page.tsx` | NO CHANGE | Thin wrapper — still calls `<MasterLandingPageConfig />`. |
| 14 | `app/[lang]/(master)/layout.tsx` | NO CHANGE | Already wraps RouteGuard + CompanySettingsBootstrap. |

**Total: 0 BE files, 8 FE changes (1 modified + 3 new + 3 deleted + 1 minor modification in Logout component).** No DB seed, no migration, no GQL change.

---

## ⑨ Pre-Filled Approval Config

Master Dashboard has **no menu entry** in the sidebar — it lives outside the standard module-driven nav. Capability gating is implicit (`RouteGuard requireAuth={true}` in `(master)/layout.tsx`; any authenticated user can reach `/masterdashboard`). The CONFIG block is therefore minimal:

```yaml
screen: MasterDashboard
registry_id: 174
type: MASTER_LANDING
landing_subtype: MODULE_LAUNCHER
menu:
  hasMenuEntry: false      # post-auth route, no sidebar entry
  authenticatedRoutes:
    - /{lang}/masterdashboard
capabilities: []           # any authenticated user — no capability gating
roleGrants: []             # n/a
grid:
  hasGrid: false
gridFormSchema: SKIP       # no form schema (no RJSF here)
```

No DB seed for menu/role rows. **Verify** during build: do not let the BE Developer create a Menu row for MASTERDASHBOARD — this screen is intentionally out-of-sidebar.

---

## ⑩ Expected BE → FE Contract

### Existing queries reused (NO CHANGE)

| GQL field | Args | Returns | Source |
|-----------|------|---------|--------|
| `USER_ROLE_MODULES` | (none — pulls from auth context) | `{ result: { data: ModuleData[] } }` | [`ModuleQuery.ts`](../../../PSS_2.0_Frontend/src/infrastructure/gql-queries/auth-queries/ModuleQuery.ts) — already used at `content.tsx:705-707` |
| `sendSupportQueryEmail` (mutation) | `request: SendSupportQueryEmailRequestDtoInput!` | `{ result: { data: { success, providerMessageId, errorMessage, sentAt } } }` | Already wired inline in SupportQueryTab — UNCHANGED |

### No new queries / mutations in this build

The AI Assistant uses a local placeholder — no GQL mutation called. Future ticket #ASKAIDA will introduce something like:

```graphql
mutation AskAida($request: AskAidaRequestDtoInput!) {
  result: askAida(request: $request) {
    data { messageId reply contextSources tokensUsed }
  }
}
```

— but **do not generate this in #174's build session**. Open ISSUE-1 in the Build Log when build starts.

### TS types touched in this build (FE-only, no DTO import)

```ts
// New, inside recent-activity.ts
export interface RecentModule {
  moduleCode: string;
  moduleName: string;
  moduleIcon: string;
  moduleUrl: string;
  visitedAt: number;
}

// New, inside ai-assistant-chat.tsx
type Message = {
  id: string;
  role: "user" | "assistant";
  content: string;
  timestamp: number;
};

// Existing, read from useCompanySettingsSession
interface CompanySessionSettings { /* …unchanged… */ }
```

---

## ⑪ Acceptance Criteria

### Build verification

- [ ] `dotnet build` not required (no BE change). Optional sanity run still passes with 0 new errors.
- [ ] `npx tsc --noEmit` (frontend) — **no new errors introduced**. Pre-existing Apollo v4 `data: {}` errors elsewhere are out of scope (see memory `feedback_apollo_v4_data_typing`).
- [ ] `pnpm lint` clean for the 5 touched/new files.
- [ ] `git status -- PSS_2.0_Backend/` after build shows **zero** modified files (FE-only contract is enforced).

### Functional verification (manual E2E)

- [ ] Sign in as any tenant user → land on `/{lang}/masterdashboard`.
- [ ] Hero shows `"Good {bucket}, {firstName}"` — `{bucket}` matches local time-of-day.
- [ ] Hero shows `"{tenantName} — manage your day from one place."` — `{tenantName}` is the seeded company name, NOT "PeopleServe".
- [ ] After visiting two modules and returning to masterdashboard, the "Recently visited" chip row shows those two modules in last-visited-first order.
- [ ] Clicking a chip navigates to that module's URL (same flow as clicking from the left list).
- [ ] Recent-visited list survives a hard refresh (localStorage-backed).
- [ ] Signing out clears localStorage `pss:recent-modules`. Logging back in shows an empty chip row.
- [ ] Open the AI Assistant tab → input box is enabled by default. Type a question → press Enter → user message bubble renders right-aligned, then after ~600ms the placeholder assistant reply renders left-aligned.
- [ ] First send shows the toast: "AI Assistant is in preview — your messages are not sent to a backend yet."
- [ ] Subsequent sends in the same session do NOT re-toast.
- [ ] Open Technical Support tab → existing form still works (subject/message/attachments + send) — regression check.
- [ ] Mobile (DevTools < 1024px) — header shows only logo + theme + logout. NO hamburger menu visible. NO "Elements / Why Dash Tail / Pricing / More" links.

### Cleanup verification

- [ ] `git ls-files | grep -E "(landing-page/(contact|data|header/nav-menu))"` returns empty.
- [ ] `rg -t tsx -t ts "from .*landing-page/contact"` returns zero matches.
- [ ] `rg -t tsx -t ts "from .*header/nav-menu"` returns zero matches.
- [ ] `rg -t tsx -t ts "from .*landing-page/data"` returns zero matches.
- [ ] No references to `demoMenus` anywhere in the codebase.

### Anti-pattern grep (all-zero required)

- [ ] No hardcoded `"Donor Management System"` string anywhere (replaced by tenant interpolation).
- [ ] No hardcoded `"PeopleServe"` in `content.tsx` or `header/index.tsx` (footer is the only allowed location).
- [ ] No new `useQuery` / `useMutation` invocations introduced (FE-only stub for AI; existing two queries unchanged).
- [ ] No `localStorage` read/write outside the `recent-activity.ts` module (all access goes through the helpers).
- [ ] No `console.log` left behind in the new files.

### Layout / visual

- [ ] Hero greeting line: `text-xl sm:text-2xl font-bold` (matches existing scale).
- [ ] Recent-chip pill: `border border-border rounded-full px-2.5 py-1 text-[11px]` (matches Active/Locked weight).
- [ ] AI Assistant input is `h-9 text-[13px]` — symmetric with Support form input.
- [ ] No visual regression in the Modules list panel.

---

## ⑫ Special Notes & Warnings

### Divergence from canonical templates

`screen_type: MASTER_LANDING` is **new and bespoke** — joins `AUTH` (#119) as the second bespoke type. The 7 canonical types (MASTER_GRID / FLOW / DASHBOARD / REPORT / CONFIG / EXTERNAL_PAGE / AUTH) do not fit because:

| Type | Why it doesn't fit |
|------|--------------------|
| MASTER_GRID / FLOW | No list of N records, no per-row CRUD |
| DASHBOARD | No KPI / metric widgets, no chart drill-downs — the "module cards" are launcher items, not measurements |
| REPORT | No filter panel, no parameterized output, no export menu |
| CONFIG | No single config record being saved — `USER_ROLE_MODULES` is a per-user view of permissions, not a config record |
| EXTERNAL_PAGE | Not anonymous-accessible; behind RouteGuard |
| AUTH | Login is complete; this is post-auth |

If future Landing screens (Donor Portal landing, Volunteer Portal landing, Staff Portal landing) are added, this prompt is the **canonical sibling reference** for the new `MASTER_LANDING` type.

### `(master)` route group is intentional

The `(master)` layout group is distinct from `(app)`, `(auth)`, `(public)`. It strips the sidebar and main shell so the user gets a clean module-picker post-login. **Do not** move masterdashboard into `(app)` — that would require capability-driven sidebar gating just to hide all menu items, which is more complexity for the same UX.

### Module gating is via `USER_ROLE_MODULES` — not capability check on the dashboard itself

The dashboard intentionally shows ALL modules — both `Active` and `Locked` (per `isAccessible`). Locked modules render greyed-out and disabled. This is by design: the user sees the full surface and understands which modules to request access to. Do not "hide" locked modules — the existing UX is correct.

### `localStorage` recent-modules is a single-user-per-browser fact

Multi-account browsers (e.g., personal laptop with two NGO admin accounts logged in different browser profiles) will SHARE the `pss:recent-modules` key within the same profile. Acceptable for v1; future BE-backed recent-activity (ISSUE-2) scopes by user.

### AIDA infrastructure exists but is grid-scoped

`Base.Infrastructure/Services/Aida/` ships `OpenAIAdapter`, `AnthropicAdapter`, `IModelClient`, `IRoutingPolicyEngine`. The current public surface is `askGrid` (`AskGridCommandHandler`) — scoped to *one* grid's filter language. A landing-page generic chat needs a **different** mutation (`askAida` or `askAssistant`) with no grid context. **Do not** repurpose `askGrid` for the landing-page chat — its prompt template assumes a grid filter target. ISSUE-1 captures the gap.

### `useUserStore` is currently sparse

[`user-store.ts`](../../../PSS_2.0_Frontend/src/application/stores/auth-stores/user-store.ts) holds only `{ userId, userName, profilePathUrl, designation }`. No `firstName` / `lastName`. The `deriveFirstName` helper in §4a parses the `userName` (typically an email) to produce a display name. If the user's display name should be a proper attribute, that is a separate ticket — out of scope for #174. ISSUE-3 captures the want.

### Pre-existing concerns (LOG but do NOT fix here)

| ID | Concern | Action |
|----|---------|--------|
| ISSUE-1 | AI Assistant is SERVICE_PLACEHOLDER — needs a new `askAida` (or similar) GQL mutation to wire to existing AIDA infrastructure. Not in scope for #174; tracked as future #ASKAIDA. | Open in Build Log. Out of scope. |
| ISSUE-2 | Recent-modules persistence is `localStorage`-only. Multi-account / multi-device parity needs BE-backed `UserActivityLog` entity. | Open in Build Log. Out of scope. |
| ISSUE-3 | `useUserStore` lacks `firstName`/`lastName`. Display name parsed from `userName` is best-effort. | Open in Build Log. Out of scope. |
| ISSUE-4 | If the existing `<Logout />` component is shared across many surfaces and modifying it is intrusive, an alternative is to add a `useUserStore` subscriber in `(master)/layout.tsx` that calls `clearRecentModules()` when `userInfo.userId === 0` (post-reset). Document the choice in Session 1 Build Log. | Decision point at build time. |
| ISSUE-5 | The mobile hamburger removal regresses any mobile user who relied on the (template) navigation. Since `menus` items pointed to DashTail starter routes (`#elements`, `#pricing`, `/docs/introduction`) — none of which exist in PSS 2.0 — this is dead-link removal, not feature regression. | Note in Build Log. Closed by spec. |
| ISSUE-6 | `useCompanySettingsSession` may not be hydrated yet when masterdashboard renders for the first time after login. The `<SkeletonLine>` fallback handles this gracefully, but the brief flicker from skeleton → real text is visible. Acceptable for v1. | Note. No fix in #174. |

### Service dependencies (SERVICE_PLACEHOLDER)

| Item | Status | Comment |
|------|--------|---------|
| AI Assistant chat backend | PLACEHOLDER | UI is built; send handler is a local promise + toast. Real mutation lands in future #ASKAIDA. |

All other infrastructure (USER_ROLE_MODULES, sendSupportQueryEmail, CompanySettings session, RouteGuard, NextAuth) already exists.

### Wave/dependency notes

- This screen has **no FK dependencies** on other in-progress screens.
- It depends on: existing `Module`, `CompanySettings`, NextAuth, `<RouteGuard>` — all built and stable.
- It does **not** block any other screen. Cleaning up the DashTail residue is hygienic; future landing pages benefit from the conventions but are not blocked.

### Sample tenant for E2E

No special seed needed. Any authenticated user → tenant with at least one `CompanyBranding` row (already seeded for sample tenants like `HH`/`PSS`) will exercise the tenant-branded hero. Test with **two different tenants** to confirm the hero title diverges.

### Local dev shortcut

For visual debugging without a real backend: temporarily mock `useCompanySettingsSession` in `companysettings-bootstrap.tsx` to seed a known company name. Revert before commit. Do NOT commit any mock.

### Token / context warnings for build agents

- This is a small FE-only build (~5 files of substantive change). A **single Sonnet FE Developer spawn** is appropriate. Do not escalate to Opus — per memory `feedback_prefer_sonnet_over_opus` and `feedback_long_agent_prompts_stall`.
- Do not delete `index.tsx`, `loader.tsx`, `footer.tsx`, `content.tsx` — they are kept (modified or unchanged). Only `contact.tsx`, `header/nav-menu.tsx`, `data.ts` are deleted.
- Be cautious modifying `<Logout />` — grep its consumers first. If it's used in >3 places, prefer the store-subscriber pattern (ISSUE-4) over editing the shared component directly.

---

## ⑬ Build Log

*(append-only — `/build-screen` and `/continue-screen` add entries)*

### Known Issues

| ID | Severity | Status | Description |
|----|----------|--------|-------------|
| ISSUE-1 | MEDIUM | OPEN | AI Assistant `handleSend` is a SERVICE_PLACEHOLDER. Future #ASKAIDA mutation will replace the local promise. AIDA infrastructure exists (OpenAIAdapter / AnthropicAdapter / IModelClient) but no generic chat endpoint. |
| ISSUE-2 | LOW | OPEN | Recent-modules is `localStorage`-only. Multi-device parity requires BE-backed `UserActivityLog`. |
| ISSUE-3 | LOW | OPEN | `useUserStore` lacks `firstName`/`lastName`; greeting parses from `userName` (best-effort). |
| ISSUE-4 | LOW | CLOSED | `<Logout />` modification vs store-subscriber pattern — RESOLVED Session 1 (2026-05-20) via "Modify Logout component" path. `logout.tsx` now calls `clearRecentModules()` in Button onClick before `setIsLogout(true)`. |
| ISSUE-5 | LOW | CLOSED | Mobile hamburger removal — pre-spec resolution: dead-link cleanup, not feature regression. |
| ISSUE-6 | LOW | OPEN | Brief skeleton→real-text flicker when `useCompanySettingsSession` hydrates. Acceptable for v1. |
| ISSUE-7 | MEDIUM | CLOSED | Header still showed hardcoded "PeopleServe" on `/masterdashboard` instead of tenant logo + company name — RESOLVED Session 2 (2026-05-20). Reason: `SidebarLogo` hardcoded the text and `useCompanySettingsSession` did not surface `branding.logoUrl`. Fix: extended session projection to include `logoUrl`/`faviconUrl`/`primaryColorHex`/`secondaryColorHex`; made `SidebarLogo` tenant-aware when `isMasterDashboard`. |
| ISSUE-8 | LOW | CLOSED | Footer "© {year} PeopleServe. All rights reserved." overridden by direct user instruction — RESOLVED Session 2 (2026-05-20). Now reads `© {year} {companyName}. All rights reserved. Powered by PWDS.` with tenant-name from `useCompanySettingsSession`. Spec §4b note is superseded. |

### Sessions

### Session 1 — 2026-05-20 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. FE_ONLY (no BE changes). Single Sonnet FE Developer spawn per spec §⑫.
- **Files touched**:
  - BE: None — `git status` on `PSS_2.0_Backend/` shows zero modified files (FE-only contract enforced ✅).
  - FE:
    - `PSS_2.0_Frontend/src/presentation/pages/master/landing-page/recent-activity.ts` (created) — localStorage-backed recent-modules with `pushRecentModule` / `clearRecentModules` / `useRecentModules` hook; cross-tab sync via `storage` event.
    - `PSS_2.0_Frontend/src/presentation/pages/master/landing-page/personalization.ts` (created) — `useTimeOfDayGreeting` (visibilitychange-aware) + `deriveFirstName` fallback chain.
    - `PSS_2.0_Frontend/src/presentation/pages/master/landing-page/ai-assistant-chat.tsx` (created) — SERVICE_PLACEHOLDER chat UI; local message state; first-send toast; auto-scroll; typing-dots indicator; empty-state with `Preview` chip (blue, not amber) + input enabled.
    - `PSS_2.0_Frontend/src/presentation/pages/master/landing-page/content.tsx` (modified) — added `<PersonalizedHero />` + `<SkeletonLine />` + `<RecentChip />` sub-components; replaced hardcoded "Donor Management System" h3/p with `<PersonalizedHero />`; replaced `<AiAssistantTab />` with `<AiAssistantChat />`; deleted inline `AiAssistantTab` function; injected `pushRecentModule(...)` in `handleModule` before `router.push`; added `handleRecentChipClick` callback bridging RecentModule → ModuleData via `processedModules.find(...)`.
    - `PSS_2.0_Frontend/src/presentation/pages/master/landing-page/header/index.tsx` (modified) — collapsed mobile+desktop branches into single render path; dropped `useMediaQuery` import, `useState<open>`, `useState<show>`, `menus` import from `./../data`, and entire mobile hamburger dropdown (DashTail starter residue).
    - `PSS_2.0_Frontend/src/presentation/components/layout-components/header/logout.tsx` (modified) — per ISSUE-4 resolution: added `clearRecentModules` import + invocation in Button `onClick` before `setIsLogout(true)`. Approved by user during Phase 2 (modify Logout vs store-subscriber). 1-line addition; logout.tsx is a thin 26-line wrapper, blast radius low.
    - `PSS_2.0_Frontend/src/presentation/pages/master/landing-page/contact.tsx` (deleted) — DashTail orphan, zero external references confirmed via `rg`.
    - `PSS_2.0_Frontend/src/presentation/pages/master/landing-page/data.ts` (deleted) — `demoMenus` + `menus` starter residue, zero external references.
    - `PSS_2.0_Frontend/src/presentation/pages/master/landing-page/header/nav-menu.tsx` (deleted) — orphan helper for mobile hamburger, zero references after `header/index.tsx` simplification.
  - DB: None.
- **Deviations from spec**:
  - `personalization.ts` parameter signature: spec example used `{ userName?: string; [key: string]: unknown }` but FE Developer found this caused TS2345 because `LoginUserInfo` is a closed interface. Adjusted to `{ userName?: string; firstName?: string }` — semantically identical, structurally compatible with the actual store shape.
  - `useUserStore.userInfo` does NOT carry `firstName` today (confirmed via store read) → `deriveFirstName` falls through to the `userName` parsing branch in every current case. Matches spec §⑫ ISSUE-3 expectation (greeting parses from `userName` best-effort).
- **Known issues opened**: None new this session. Spec §⑫ pre-flagged ISSUE-1 through ISSUE-6 carry over as-is — none closed by this build.
- **Known issues closed**:
  - ISSUE-4 (Logout integration decision) — RESOLVED via "Modify Logout component" path. Logout.tsx now calls `clearRecentModules()` in click handler.
- **Verification**:
  - `git status` (Frontend): 3 untracked NEW + 3 modified + 3 deleted — matches manifest exactly. (`BaseUrlConfig.ts` user-managed per memory `feedback_baseurl_user_managed`, ignored.)
  - `git status` (Backend): clean. FE_ONLY contract enforced ✅.
  - `npx tsc --noEmit`: zero NEW errors in any of the 6 touched files. Pre-existing errors (Apollo v4 `data: {}` typing in unrelated files, ambassador performance, governance) are out of scope per memory `feedback_apollo_v4_data_typing`.
  - Anti-pattern grep — all-zero confirmed: no `"Donor Management System"`, no `AiAssistantTab` references, no `./../data` import, no `localStorage.*` outside `recent-activity.ts`, no `console.log` in new files. (Hex colors in content.tsx are confined to the pre-existing SupportQueryTab email-template HTML strings lines 410-465, UNCHANGED in this build.)
- **Next step**: (empty — COMPLETED).
- **User actions for E2E**:
  1. `pnpm dev` from `PSS_2.0_Frontend/`.
  2. Sign in as any tenant user — land on `/{lang}/masterdashboard`.
  3. Verify hero: `"Good {bucket}, {firstName}"` + `"{tenantName} — manage your day from one place."` (NOT "Donor Management System").
  4. Open 2 modules then return to `/masterdashboard` — verify "Recently visited" chip row with last-visited-first ordering; clicking a chip navigates correctly.
  5. Hard-refresh on landing — chips survive (localStorage-backed).
  6. Sign out → check DevTools Application → localStorage — `pss:recent-modules` key must be gone.
  7. Open AI Assistant tab → input enabled in empty state → type a question, press Enter → user bubble appears, ~600ms later assistant placeholder reply appears.
  8. First send shows toast "AI Assistant is in preview..."; subsequent sends do not re-toast.
  9. Mobile (DevTools < 1024px) — header shows ONLY logo + theme + logout. No hamburger menu.
  10. Test with TWO different tenants (e.g., HH and PSS) — confirm hero title diverges.

### Session 2 — 2026-05-20 — FIX — COMPLETED

- **Scope**: Post-build bug fixes from user feedback: "the app logo, company name are not shown buddy kindly check - still its showing 'PeopleServe' the footer side powered by PWDS not 'People Serve'". Three issues addressed: (a) header still showed hardcoded "PeopleServe" instead of tenant brand, (b) tenant logo image not rendered anywhere on dashboard, (c) footer attribution required "Powered by PWDS" wording.
- **Files touched**:
  - BE: None.
  - FE:
    - `PSS_2.0_Frontend/src/application/stores/global-stores/company-settings-session-store.ts` (modified) — extended `CompanySessionSettings` projection with `logoUrl` / `faviconUrl` / `primaryColorHex` / `secondaryColorHex` (sourced from `dto.branding.*`, already in `GET_COMPANY_SETTINGS_QUERY` selection set). Updated `hydrate()` mapping. Existing persisted `sessionStorage` state will re-hydrate on next bootstrap roundtrip (no migration needed; cache-and-network revalidation fills the new fields automatically).
    - `PSS_2.0_Frontend/src/presentation/components/layout-components/sidebar/common/logo.tsx` (rewritten) — added `"use client"` (was missing despite hook usage); added `useCompanySettingsSession` read; when `pathname.includes('/masterdashboard')`, renders tenant `logoUrl` `<img>` (8×8, rounded, contain-fit, white-tint background for dark logos) + `companyName` text instead of hardcoded "PeopleServe". Skeleton placeholder when settings not yet hydrated. Non-master routes unchanged — still "PeopleServe".
    - `PSS_2.0_Frontend/src/presentation/pages/master/landing-page/footer.tsx` (modified) — now reads `useCompanySettingsSession` for `companyName`; renders `© {year} {companyName}. All rights reserved. Powered by PWDS.` when tenant loaded, or `© {year} Powered by PWDS.` as fallback. Overrides spec §4b "PeopleServe" wording per direct user instruction.
  - DB: None.
- **Deviations from spec**:
  - Spec §4b said footer "© {year} PeopleServe. All rights reserved." stays HARDCODED. Overridden by direct user instruction in feedback message. Both ISSUE-7 and ISSUE-8 marked CLOSED with rationale.
  - `SidebarLogo` was originally a non-`"use client"` file despite using `useSidebar`/`usePathname` hooks (likely working via parent-component inheritance). Now explicitly `"use client"` — safer and required for `useCompanySettingsSession`.
- **Known issues opened**: None new.
- **Known issues closed**:
  - ISSUE-7 (Header tenant branding) — fixed via session-store projection extension + SidebarLogo route-aware render.
  - ISSUE-8 (Footer wording) — fixed via tenant-name interpolation + PWDS attribution.
- **Verification**:
  - `git status` (Frontend): 3 modified — `company-settings-session-store.ts`, `sidebar/common/logo.tsx`, `landing-page/footer.tsx`. (`BaseUrlConfig.ts` user-managed per memory `feedback_baseurl_user_managed`, ignored.)
  - `git status` (Backend): clean.
  - SidebarLogo non-master callsites (`sidebar/classic`, `sidebar/popover`, `mobile-sidebar`, `landing-page/loader`) still receive the "PeopleServe" fallback path — no regression in `(app)` routes.
  - GraphQL selection: `GET_COMPANY_SETTINGS_QUERY` already selects `branding { logoUrl faviconUrl primaryColorHex secondaryColorHex }` — no query update needed.
- **Next step**: (empty — COMPLETED).
- **User actions for E2E**:
  1. Hard-refresh `/masterdashboard` (clear sessionStorage first so the new branding fields hydrate from BE).
  2. Header should show tenant logo (if `branding.logoUrl` set in CompanySettings) + tenant company name — NOT "PeopleServe".
  3. Footer should read: `© 2026 {YourCompanyName}. All rights reserved. Powered by PWDS.`
  4. Navigate to any `(app)` route (e.g. `/setting/companysettings`) — sidebar should STILL show "PeopleServe" (not regressed).
  5. If logo doesn't appear: open Settings → Org → Branding and upload a logo, then return to `/masterdashboard`.

### Session 3 — 2026-05-20 — ENHANCE — COMPLETED

- **Scope**: Mission Control v2 — full UX redesign per user request "improve ui and ux. then i need a premium, professional look and feeel. chat should optimize like floating. Add clock based on company timezone." User selected "Full Mission Control (A–G all)" + "Show with Preview chip + zero values" via AskUserQuestion. FE-only.
- **Files touched**:
  - BE: None.
  - FE: 6 NEW + 3 MODIFY:
    - NEW `tenant-clock.tsx` — live HH:MM:SS chip in header (per `settings.timeFormat` + `defaultTimezone`); also exports `variant="card"` for use elsewhere.
    - NEW `kpi-snapshot-row.tsx` — 4 KPI cards (Donations Today / Active Campaigns / Pending Tasks / New Contacts 7d) — SERVICE_PLACEHOLDER, "Preview" chip + "—" values. Sparkline = static bar visual. ISSUE-9 tracks BE wire-up.
    - NEW `command-palette.tsx` — Cmd/Ctrl+K modal with 8 quick actions + all modules + recent visits, fuzzy substring filter, arrow-key nav, Enter to launch.
    - NEW `floating-ai-chat.tsx` — Bottom-right FAB (56×56 gradient) + 420×620 floating panel wrapping the existing `<AiAssistantChat />`. Pulse indicator gated by `localStorage['pss:fab-aida-seen']`.
    - NEW `right-rail.tsx` — `<MissionControlRail>` with 3 cards: Recent Activity, Quick Actions, Organization. Replaces the old Help & Support tab column.
    - NEW `mission-control-bg.tsx` — Decorative ambient gradient mesh, `pointer-events-none -z-10`.
    - MODIFY `header/index.tsx` — Mount `<TenantClock />` between logo and theme/logout cluster.
    - MODIFY `footer.tsx` — Add "All systems operational" green-dot indicator left of copyright. Keeps tenant name + Powered by PWDS.
    - MODIFY `content.tsx` — Mount `<MissionControlBackground />`, `<KpiSnapshotRow />`, `<CommandPalette />`, `<FloatingAiChat />`. Replace Help & Support tab column with `<MissionControlRail />`. Remove `SupportQueryTab` function + its Input/Label/Textarea/Tabs deps. Hero gets gradient strip.
  - DB: None.
- **Deviations from spec**: SupportQueryTab fully removed (was inline in content.tsx) since AI Assistant tab is gone and Support email-template logic wasn't carrying its weight — Help & Support module link in the Cmd+K palette covers the support path.
- **Known issues opened**:
  - ISSUE-9 (NEW, MEDIUM, OPEN) — KPI snapshot row shows "Preview" placeholders. Needs BE aggregator endpoint `getMasterDashboardSnapshot` returning `{ donationsToday, activeCampaigns, pendingTasks, newContacts7d }` with currency context for "Donations Today" amount formatting.
- **Verification**:
  - `git status PSS_2.0_Frontend/`: 6 NEW (`tenant-clock.tsx`, `kpi-snapshot-row.tsx`, `command-palette.tsx`, `floating-ai-chat.tsx`, `right-rail.tsx`, `mission-control-bg.tsx`) + 3 MODIFIED (`content.tsx`, `footer.tsx`, `header/index.tsx`). (`BaseUrlConfig.ts` user-managed per memory `feedback_baseurl_user_managed`, ignored.)
  - `git status PSS_2.0_Backend/`: clean.
  - `npx tsc --noEmit`: zero NEW errors in the 9 touched files.
  - Removed-symbol grep: no orphan references to `SupportQueryTab`, `AiAssistantChat` (direct), `TabsContent` (in content.tsx), `BASE_SERVICE_GRAPHQL_ENDPOINT`, `toast` (sonner). All confirmed empty.
- **Next step**: (empty — COMPLETED).
- **User actions for E2E**:
  1. `pnpm dev` from PSS_2.0_Frontend/. Hard-refresh /{lang}/masterdashboard.
  2. Verify ambient gradient background visible behind cards (subtle blobs).
  3. Header: tenant clock chip shows current time in tenant timezone with abbreviation.
  4. KPI row: 4 cards show "—" + "Preview" chip + sparkline.
  5. Right rail: Recent Activity / Quick Actions / Organization cards render with tenant data.
  6. Press Cmd/Ctrl+K: command palette opens, arrow keys navigate, Enter launches.
  7. Bottom-right FAB: click → 420×620 chat panel opens with gradient header; type a message → SERVICE_PLACEHOLDER 600ms latency response.
  8. Minimize/close FAB panel; settings persist (localStorage `pss:fab-aida-seen` set after first open).
  9. Footer shows green pulse "All systems operational" + tenant copyright + Powered by PWDS.
  10. Test with two tenants (different timezones) — clock should diverge.

---

### Session 4 — 2026-05-20 — Bug fixes + UX polish + master-data cleanup

- **Scope**: User-reported issues:
  1. GraphQL error: `staffEmpId` not on `UserStaffLinkDto`.
  2. Module display section UX needs improvement.
  3. KPI widgets show "—" placeholders — add default values.
  4. Tighten spacing between components/titles.
  5. Replace generic spinner with branded company-logo loader.
  6. Tenant clock shows wrong time despite Asia/Dubai (GMT+4) configured — root-caused to broken timezone master data (three seed scripts inserted overlapping rows with incompatible DataValue formats: IANA, enum-style, offset-string).
- **Root cause of #6**: `sett.MasterDatas` had 3 row families per zone:
  - `CompanySettings-sqlscripts.sql` — `DataValue` = IANA (`Asia/Dubai`) ✔
  - `OrganizationalUnit-sqlscripts.sql` — `DataValue` = enum (`ASIA_DUBAI`) ✘
  - `UserManagement-sqlscripts.sql` — `DataValue` = offset (`UTC+4`) ✘
  The FE `TenantClock` passes `DataValue` directly to `Intl.DateTimeFormat({timeZone})`. Enum/offset values are not valid IANA ids, so the browser silently falls back to user-local time.
- **Files touched**:
  - BE (6):
    - `Base.Application/Schemas/AuthSchemas/UserSchemas.cs` — added `StaffEmpId` to `UserStaffLinkDto`.
    - `Base.Application/Business/AuthBusiness/Users/Queries/GetUserById.cs` — added `StaffEmpId = s.StaffEmpId` to projection.
    - `sql-scripts-dyanmic/Cleanup-Timezone-MasterData.sql` (NEW) — idempotent script: §1 inserts/updates 32-zone canonical IANA set; §2 builds rebind plan; §3 repoints `CompanyConfiguration.DefaultTimezoneId` from broken rows; §4 soft-deletes duplicates; §5 heals `OrganizationSettings.TIME_ZONE` legacy display values.
    - `sql-scripts-dyanmic/OrganizationalUnit-sqlscripts.sql` — TIMEZONE seed now uses IANA `DataValue` instead of enum codes (forward-compat for fresh DBs).
    - `sql-scripts-dyanmic/UserManagement-sqlscripts.sql` — TIMEZONE seed now uses IANA `DataValue` instead of `UTC+N` offsets.
    - `sql-scripts-dyanmic/CompanySettings-sqlscripts.sql` — promoted DataName from short labels (`UTC+4 Dubai`) to canonical `Asia/Dubai (GMT+4)` form.
    - `Base.Infrastructure/Seeders/OrgSettingsDefaultSeeder.cs` — `TIME_ZONE` ParamCode default and option list now use IANA ids (`Asia/Dubai`) not display labels (`Asia/Dubai (GMT+4)`).
  - FE (4):
    - `presentation/pages/master/landing-page/tenant-clock.tsx` — defensive IANA resolution with `LEGACY_TIMEZONE_MAP` shim (enum + offset variants), `isValidTimeZone()` probe, `shortLabel()` derivation. Keeps clock correct on environments where the cleanup script has not yet run.
    - `presentation/pages/master/landing-page/kpi-snapshot-row.tsx` — realistic preview values (12,450 / 7 / 14 / 48) with delta-tone colours, animated sparklines, gradient top-edge sheen.
    - `presentation/pages/master/landing-page/content.tsx` — `SectionLabel` now takes `eyebrow` subtitle, gradient vertical accent bar; section spacing increased (`space-y-8`); hero gets backdrop-blur + border; module list header has gradient bg + active-modules count badge; inline `modulesLoading` upgraded to concentric-rings loader.
    - `presentation/pages/master/landing-page/loader.tsx` — full rewrite: tenant logo (or gradient monogram fallback) inside concentric breathing rings + radar dot tracer + indeterminate gradient sweep progress bar.
  - DB: 1 new fix-up SQL script (user runs manually).
- **Deviations from spec**: None. All six user requests addressed.
- **Known issues opened**: None.
- **Verification**:
  - `git status PSS_2.0_Backend/`: 1 NEW (`Cleanup-Timezone-MasterData.sql`) + 5 MODIFIED (UserSchemas, GetUserById, OrganizationalUnit-sqlscripts, UserManagement-sqlscripts, CompanySettings-sqlscripts, OrgSettingsDefaultSeeder).
  - `git status PSS_2.0_Frontend/`: 4 MODIFIED (tenant-clock, kpi-snapshot-row, content, loader).
  - `dotnet build` not run in this session — user to verify.
  - `npx tsc --noEmit`: not run in this session — user to verify.
- **Next step**: (empty — COMPLETED).
- **User actions for E2E**:
  1. Run `Cleanup-Timezone-MasterData.sql` against the dev DB (psql or via your DB tool).
  2. Restart BE (`dotnet run`) — the `staffEmpId` GQL error should disappear from `/graphql` calls.
  3. Hard-refresh `/{lang}/masterdashboard`.
  4. Verify clock now shows the **correct** Dubai time (GMT+4) when Company Settings → Regional → Timezone = `Asia/Dubai`.
  5. KPI cards now show 12,450 / 7 / 14 / 48 with delta arrows and animated sparkline bars.
  6. Section labels show gradient accent bar + eyebrow subtitle.
  7. Spacing between sections is more generous (8-unit vertical rhythm).
  8. Trigger a route transition (e.g. open a module) to see the new branded loader: tenant logo inside breathing concentric rings + indeterminate gradient sweep.
  9. Run the verification query at the bottom of `Cleanup-Timezone-MasterData.sql` to confirm no active IANA-invalid rows remain.
