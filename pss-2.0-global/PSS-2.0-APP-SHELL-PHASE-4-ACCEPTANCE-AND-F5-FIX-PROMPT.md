# PSS 2.0 — App Shell Phase 4: Runtime Acceptance + F-5 Correctness Fixes

**Status:** PART B COMPLETE (2026-08-08, staged not committed, `tsc --noEmit` exit 0) — PART A NOT RUN
**Predecessors:** Phase 1 (platform shell), Phase 2 (tenant shell), Phase 2.1 (landing/identity), Phase 3 (dead-code removal — COMPLETE, `tsc --noEmit` clean).
**Shape:** **Part B (code) runs FIRST and is the deliverable of this session.** Part A (runtime
acceptance) is a *deferred* pass the user triggers when their environment is up — it is NOT a
prerequisite and must not block a single line of Part B.

> **Ordering was inverted on 2026-08-08 by explicit user direction.** The three F-5 defects are
> static code changes verifiable by `tsc` and by reading the code; they need no API, no dev server,
> and no login. Do them now. Do not probe ports, processes, or API liveness, and do not gate any
> deliverable on environment readiness — the user starts the API and will report failures directly.

---

## §⓪ Why this exists

Phases 1 through 3 rewrote the entire application shell — rail, context panel, topbar, module
resolution, post-login landing — and deleted the old one (33 sidebar files, the module loader, the
module navigator, the layout provider, legacy header/footer/search). Every one of those changes was
verified by `tsc --noEmit` and by grep.

**Not one of them has been run in a browser.** Phase 1 handed back with twelve acceptance points
unexercised and said so. Phase 2 added fifteen more and said so. Phase 2.1 added twelve and said so.
That is 27 live points (Phase 2's 15 + Phase 2.1's 12; Phase 2.1 §4.12 is "re-run Phase 2's list",
so they are one combined set) standing behind a green typecheck.

The compiler cannot see any of the failure modes that actually matter here:

- a scrim raised on navigation that nothing ever lowers → the app looks hung;
- a rail click that calls `router.push()` when it must only swap the panel (INV-8);
- a tenant user who reaches the control plane, or a platform user who does not;
- a second user in the same browser inheriting the first user's modules from the Apollo cache;
- a panel leaf pointing at a route that 404s.

Each of those typechecks perfectly. So Part A is not paperwork — it is the only instrument that can
read this build, and it stays in this file, unchanged, waiting for an environment.

But two of those failure modes are *already diagnosed*: F-5.1 and F-5.3 below are the cache and
reconciliation bugs behind "the panel showed the wrong module for a frame" and "the rail stayed lit
on the wrong module". They were found by reading the code, not by running it, and they can be fixed
the same way. Waiting for a browser to re-confirm what the code already states costs time this phase
does not have.

**So: Part B first.** Fix the three defects, typecheck, stage, hand back. Part A runs later, and
when it does it will be verifying a *corrected* shell rather than cataloguing known bugs.

---

## §① Read first (grounding)

Read these before touching anything. Do not skim — the invariants below are the whole design.

| File | Why |
|---|---|
| `PSS-2.0-APP-SHELL-REDESIGN-APPROACH.md` | The parent plan. §⑥.2 (rail IA), §⑦ (URL segments), §⑫ (open questions). |
| `PSS-2.0-APP-SHELL-PHASE-2-TENANT-BUILD-PROMPT.md` | §⑤ invariants, §⑨ acceptance (15 pts), §⑪ traps. |
| `PSS-2.0-APP-SHELL-PHASE-2.1-LANDING-AND-IDENTITY-FIX-PROMPT.md` | §③ F-1…F-5, §④ acceptance (12 pts). |
| `PSS-2.0-APP-SHELL-PHASE-3-DEAD-CODE-REMOVAL-PROMPT.md` | §⑥ carries F-5 forward unbuilt. |
| `src/presentation/provider/app-shell-provider.tsx` | The shell. Rail/panel/scrim orchestration. |
| `src/presentation/hooks/usePanelMenu/index.ts` | Part B target 1. |
| `src/application/utils/module-url-match.ts` | Part B target 2. |

**Invariants that must survive this phase:**

- **INV-1** — the shell reads no `layout` / `sidebarType` / `navbarType` from tenant theme stores.
  Layout is fixed: rail, panel, main.
- **INV-3** — forbidden navigation is **absent**, never rendered-then-removed. A platform link a
  tenant user must not see is not in the DOM at all, not hidden with CSS.
- **INV-6** — one `AppShell` branching on `navSource`. No forks.
- **INV-8** — `moduleCode` (global store) is owned by the URL via `useActiveModule`.
  `activeRailKey` (shell store) is owned by the rail click. **A rail click never writes
  `moduleCode` and never calls `router.push()`.**

---

## §② Constraints (hard)

1. **Frontend only.** No backend change. No EF migration. No seed. No SQL. No change to
   `auth.Modules`, menu rows, or capability rows.
2. **No URL changes.** No `Role.DefaultLandingUrl` reseeding. Both `/ops/` and `/platform/`
   segments stay.
3. **No UX changes.** Do not remove the theme customizer's `layout` / `sidebarType` / `navbarType`
   options — they are still consumed by `customizer/theme-customizer.tsx` and stripping them is a
   product decision, not cleanup.
4. **The seeded PLATFORM menu rows stay in the database** — dormant for navigation, live for RBAC.
   Never delete or deactivate them.
5. **Do not invent capability codes and do not write a seed for them.** Still open from Phase 1,
   still not yours to close.
6. **`route-guard.tsx` is out of scope.** Its body is commented out end to end and three layouts
   still render it. Restoring or deleting it is a security decision and needs an explicit call —
   see §⑤.
7. **`BaseUrlConfig.ts` is user-managed.** Never edit it, never stage it, never revert it.
8. **Never `git commit`.** Stage with `git add` and stop. The user owns every commit. Never push,
   amend, or tag. **Never add a `Co-Authored-By: Claude` trailer or a "Generated with Claude Code"
   line** to any commit message, suggested message, or PR body.
9. **Do not run `dotnet build`.** Do not run `ef migrations add`. Do not edit `ModelSnapshot`.

---

## §③ Part A — Runtime acceptance (**DEFERRED — do not run in this session; go to §④**)

> **Execution order for this session: §④ Part B only.** Do not start Part A, do not start a dev
> server for it, do not check whether the API is up, and do not ask for logins. The user runs Part A
> themselves once their environment is confirmed, in a later session, against the fixed shell. This
> section is preserved verbatim so that session has a complete, unedited checklist.
>
> If — and only if — the user says in this session that the environment is already up and asks you
> to run it, do Part A *after* Part B is staged, and record the results in §⑦.

### A.0 Setup (for whoever runs Part A later)

1. API and frontend dev server running. `BaseUrlConfig.ts` must already point at the running API —
   it is **user-managed**; never edit it and never advise editing it.
2. Open DevTools. Keep **Console** and **Network** visible for the whole run — several points below
   are decided by what does *not* appear there.
3. Have two tenant users with **different** module access ready, plus one platform-staff user.
   The known tenant BUSINESSADMIN is `karthick004soruban@gmail.com`.
4. **Run Part A by hand, in a browser.** There *is* Playwright infrastructure at `tests/e2e/`
   (`playwright.config.ts`, `shared/auth.setup.ts` with a saved `storageState.json`), but it was
   written against the shell Phase 3 deleted and will go green for the wrong reasons. Specifically,
   in `tests/e2e/shared/nav-helpers.ts`:
   - `seedModuleCode()` (line 82) injects `moduleCode` into `localStorage` before boot, because the
     old `useMenu()` skipped its query on an empty `moduleCode`. Under **INV-8** `moduleCode` is now
     owned by the URL via `useActiveModule` — this pre-seed is redundant at best, and at worst it
     masks precisely the stale-module bleed that **A20** exists to catch.
   - `waitForModuleReady()` (line 117) waits on `a[href*="/{module}/"]`, and its comment claims
     "there is no `<nav>` ancestor". That is now false — `ContextPanel` renders a real
     `<nav aria-label>`. The selector passes by accident.
   - The TODO at line 107 (`data-testid="sidebar-menu-ready"` on the shell) is now the correct fix
     and is cheap to add to `ContextPanel` — but it is **not** part of this phase.

   Do **not** repair the harness first. Debugging the harness and the shell at the same time leaves
   you no ground truth for either. Run manually, get the 27 verdicts, and only then decide which
   points are worth a durable spec. If you do run any existing spec, treat a pass as unconfirmed
   until the three items above are accounted for.

### A.1 The checklist

Record every point as **PASS**, **FAIL**, or **BLOCKED** (with the reason). A point you could not
reach is BLOCKED — never PASS. **Do not fix anything mid-run**: log it and keep going, so the
result is a complete picture rather than a trail that stops at the first defect.

**Group 1 — Rail behaviour (Phase 2 §9.1-3, 7; Phase 2.1 §4.2, 4.10)**

| # | Check | Method |
|---|---|---|
| A1 | Every accessible module appears as a rail icon, ordered by `orderBy` | Compare rail against `USER_ROLE_MODULES` response in Network |
| A2 | Inaccessible modules are **absent** — not greyed, not disabled | Inspect DOM; INV-3 |
| A3 | Clicking a rail icon swaps the panel and **does not change the URL** | Watch the address bar; it must not flicker |
| A4 | A rail click fires **no** capability query until a leaf is picked | Network tab, filter on the capability request |
| A5 | A rail click leaves `moduleCode` unchanged | React DevTools on the global store; INV-8 |
| A6 | A tenant with >9 modules overflows into "More" without layout breakage | Use the widest-access user; narrow the window |

**Group 2 — Panel and navigation (Phase 2 §9.4, 5, 6, 8; Phase 2.1 §4.3, 4.11)**

| # | Check | Method |
|---|---|---|
| A7 | Picking a leaf navigates, raises the scrim, and the scrim **drops** when ready | No flicker of the previous screen; no hang |
| A8 | The panel's first link on **every** module resolves to a real page | Walk all six modules — not just CRM. No 404, no hung scrim |
| A9 | Hard-refresh on a deep link lights the right rail icon and shows its menu | F5 inside each module |
| A10 | Back/forward keeps rail, panel and content in agreement | Navigate 4-5 deep, then walk back |
| A11 | The panel does not blank during a cache-served module switch | Switch A→B→A; watch for a flash of empty |
| A12 | Module B's menu does not bleed into module A on return | A→B→A; A must show A's menus (this is the `lastGoodRef` cache — see F-5.1) |

**Group 3 — Identity and the platform gate (Phase 2.1 §4.1, 4.4-4.9)**

| # | Check | Method |
|---|---|---|
| A13 | Tenant BUSINESSADMIN lands on `/en/crm/dashboards/overview`, tenant shell | Fresh login. **Never** `/platform/*` |
| A14 | Platform staff still land on the control plane, unchanged | Fresh login as platform staff |
| A15 | `/en/platform/dashboards` typed directly as a tenant user → `no-access` | The platform shell must not paint, **not even for one frame** |
| A16 | `/en/masterdashboard` as a tenant user does not strand them | Type it directly |
| A17 | Company switch as a tenant user → tenant landing, not control plane | Use the company switcher |
| A18 | Profile popover shows the **real** signed-in email and designation | Compare against the login used |
| A19 | Log out, log in as a **different** tenant user → popover shows user 2 | Same browser, no cache clear |
| A20 | User 2 sees **their own** rail and menus, not user 1's | Same browser. This is the Apollo-cache / localStorage bleed test — the highest-value point on this list |

**Group 4 — Chrome and layout (Phase 2 §9.9-15)**

| # | Check | Method |
|---|---|---|
| A21 | ⌘K opens the palette; a menu entry navigates | Keyboard |
| A22 | A palette "Switch module" entry **only** swaps the panel | URL must not change |
| A23 | `PlanStatusBanner` / `PlanStatusChip` appear for tenant, never on `(master)` | Both shells |
| A24 | Tenant logo on tenant only; `ph:shield-star` + Platform chip on platform only | Both shells |
| A25 | Below `xl` the drawer holds rail + panel and closes on navigation | Resize under 1280px |
| A26 | A wide data grid does not push the rail off-screen | Open the widest grid you have; `min-w-0` on `<main>` |
| A27 | `(master)` is visually and behaviourally identical to Phase 1 | Walk the platform rail end to end |

### A.2 Recording

Whoever runs Part A appends a **§⑦ Part A Results** section to this file: the 27 rows with verdicts,
and for every FAIL a short repro (steps, expected, actual, and the console/network evidence).

---

## §④ Part B — F-5 correctness fixes (**START HERE — not gated on anything**)

Three defects, carried unbuilt since Phase 2.1 §F-5. **One commit-sized change per defect**, each
independently revertable — but **staged only, never committed** (§②.8).

**This part needs no running API, no dev server, and no login.** Its verification is
`rm -rf .next/types && npx tsc --noEmit --incremental false` plus the static reasoning recorded in
§⑧. Each defect below names the acceptance points that will confirm it later; write those point
numbers into §⑧ as *pending runtime confirmation* rather than running them now.

**A concurrent-session hazard, so you do not chase a ghost:** another session may be editing this
tree. A `tsc --noEmit` run against it can emit phantom `TS6053 File not found ... matched by include
pattern` errors that have nothing to do with your change. One run is not authoritative — re-run
before you believe a failure, and if it persists, check whether the named file is one you touched.

> **Note on scope drift from earlier notes:** F-5 was previously described as four defects. The
> `sections.length > 1` heuristic is **already fixed** — `usePanelMenu` now asks the source
> (`hasRealMenu = menus.length > 0`, lines 164-166), which is correct, because F-2b made the
> synthetic Dashboard leaf conditional and a section count can no longer tell an empty menu from a
> real one. Leave it alone. Three remain.

### F-5.1 — Render-phase ref mutation in `usePanelMenu`

**File:** `src/presentation/hooks/usePanelMenu/index.ts:161-169`

```ts
const lastGoodRef = useRef<Record<string, ShellPanelSection[]>>({});
const cacheKey = moduleCode ?? "";
const hasRealMenu = (menus?.length ?? 0) > 0;
if (!error && hasRealMenu) lastGoodRef.current[cacheKey] = sections;   // ← mutation during render
const resolved = hasRealMenu ? sections : (lastGoodRef.current[cacheKey] ?? sections);
```

**Defect:** line 167 writes a ref during the render phase. React may render a component twice
(StrictMode, concurrent rendering) or discard a render entirely; a render-phase side effect makes
the cache contents depend on renders that were never committed. Under React 18 concurrent features
this is precisely the pattern that produces "the panel showed the wrong module's menu for one
frame".

**Fix:** move the write into a `useEffect` keyed on `[cacheKey, sections, error, hasRealMenu]`.
The *read* on line 169 stays in render — reading a ref during render is fine; only the write is not.

**Do not** "simplify" the fallback away. The comment on lines 157-160 is load-bearing: `useMenu()`
queries with `cache-and-network`, so `loading` flips true on every module switch even when the cache
already holds the menu. Blanking on it is the "sidebar reloads" bug that was already fixed once in
the now-deleted `sidebar/module/index.tsx`. Keep the behaviour, fix the mechanism.

**Verify (deferred):** **A11** and **A12**. A12 is the direct test of this cache. Record both in §⑧
as pending runtime confirmation.

### F-5.2 — Tier-2 route match ignores specificity

**File:** `src/application/utils/module-url-match.ts:68-70`

```ts
const targetRoot = moduleRoot(target);
if (!targetRoot) return undefined;
return modules.find((module) => moduleRoot(module?.moduleUrl) === targetRoot);
```

**Defect:** tier 1 correctly sorts by `moduleUrl` length so the longest prefix wins (the comment on
lines 40-42 explains exactly why). Tier 2 then throws that away: it compares **only the first path
segment** and takes the first `.find()` hit in query order.

With modules seeded at `crm/dashboards/overview` (CRM) and `crm/membership/plans` (Membership),
the real screen URL `crm/membership/plan-list` is under neither `moduleUrl`, so tier 1 misses. Tier 2
reduces both to root `crm` and returns whichever row `USER_ROLE_MODULES` happened to order first.
The user browsing Membership can light up the CRM rail icon and get CRM's menu.

**Fix:** insert a tier between the two — match on the **longest common leading path-segment prefix**
between `target` and each `moduleUrl`, and take the maximum. Segment-wise, not string-wise
(`crm/member` must not be treated as a prefix of `crm/membership`). Tier 3 stays as the root-segment
fallback for the genuinely one-segment case.

**Do not** change the two exported helpers' signatures — `useAuth` and `useActiveModule` both import
this comparator and the whole point of the file (lines 4-7) is that there is exactly one
implementation.

**Verify (partly now):** this one is unit-testable by inspection — in §⑧, walk the fix by hand
against at least these three inputs and show the result: `crm/membership/plan-list` with modules
seeded at `crm/dashboards/overview` + `crm/membership/plans` (must resolve to **Membership**);
`crm/contacts` with the same two (must resolve to **CRM** via the root fallback); and a
`crm/member/...` path (must **not** match `crm/membership`, proving the match is segment-wise).
**Deferred:** **A9** on the deepest module, plus **A1** for ordering.

### F-5.3 — `activeRailKey` is not reconciled on route commit

**File:** `src/presentation/provider/app-shell-provider.tsx:154-169`

```ts
useEffect(() => {
  if (!isTenant || !moduleCode) return;
  setActiveRailKey(moduleCode);
}, [isTenant, moduleCode, setActiveRailKey]);
```

**Defect:** the tenant rail follows `moduleCode`, and that dependency is deliberate — a rail click
previews module B without navigating, so `moduleCode` stays A and the effect does not snap the rail
back. Correct, and INV-8 depends on it.

But it means the rail is only ever reconciled when `moduleCode` **changes**. Sequence: user is in
module A → clicks rail item B (preview; `activeRailKey = B`, `moduleCode = A`) → then navigates
*within module A* by breadcrumb, browser Back, or a command-palette jump. `moduleCode` is still A,
so the effect does not re-fire, and the rail stays lit on B while the content is A. The preview
outlives the interaction that justified it.

**Fix:** reconcile on **route commit**. The shell already tracks commit — `navOriginRef` and the
scrim handoff at lines 171+ know when a navigation has landed. On commit, set `activeRailKey` to the
URL's module (`moduleCode`) unconditionally, not just when `moduleCode` changed. A preview survives
until the next committed navigation, then yields to the URL.

**Guard against the obvious regression:** this must not fire on the preview click itself, or a rail
click would snap straight back and the preview would be unusable. The distinguishing signal is a
committed pathname change — not a store write.

**Verify (deferred):** **A3**, **A5**, **A10**, then the specific repro: module A → preview B →
browser Back → the rail must show A. Since you cannot run these now, §⑧ must instead trace the
effect's dependency array and firing conditions in prose and state plainly why a preview click
cannot trigger it.

---

## §⑤ Out of scope — flagged, do not build

- **`route-guard.tsx`.** Body commented out end to end (`return <>{children}</>`), still imported and
  rendered by three layouts, still holding the `MASTER_URL` import at line 3. Restoring it and
  deleting it have opposite security consequences, and the decision is the user's. It also gates the
  last `MASTER_URL` removal (Phase 3 §3a.6 deliberately left it). **Raise it; do not resolve it.**
- Removing `layout` / `sidebarType` / `navbarType` from the theme customizer (§②.3).
- `useThemeCustomizer` — **not** orphaned; still consumed by `customizer/theme-customizer.tsx:57`
  and the hooks barrel. Leave it.
- Consolidating the `ops` and `platform` URL segments. Deferred indefinitely.
- Per-module last-visited-menu memory. Confirmed v1 behaviour is swap-only.
- A cross-module command palette that loads every module's menu.
- Seeding `Role.DefaultLandingUrl` or any backend fix for the null-landing case.

---

## §⑥ Deliverable

**This session delivers Part B only.**

1. Three separate, independently revertable changes — one per defect (F-5.1, F-5.2, F-5.3).
2. Run `rm -rf .next/types && npx tsc --noEmit --incremental false` and report the exit code
   **verbatim**. Re-run once before believing any failure (concurrent-session `TS6053` phantoms).
3. Append **§⑧ Part B Build Log**: what landed, what deviated and why, the F-5.2 hand-trace against
   the three inputs named above, and the F-5.3 dependency-array trace.
4. `git add` the changed files and report what is staged. **Do not commit.** Do not stage
   `BaseUrlConfig.ts`.

**Part A stays open.** In §⑧, list the acceptance points each fix still needs (A11/A12, A9/A1,
A3/A5/A10) as **pending runtime confirmation** — do not mark them PASS, and do not mark them FAIL.

State explicitly, for every claim, whether it was **exercised on a dev server** or only
**satisfied statically**. In this session almost everything will be the latter — say so plainly.
Claiming a runtime verdict you did not run is the one failure this whole phase exists to prevent.

**Do not** start a dev server, probe a port, check whether the API is listening, or ask the user to
confirm the environment. If something you genuinely need is missing, say what it is in one line and
carry on with the rest.

Finally: `git add` the changed files and report what is staged. **Do not commit.**
Do not stage `BaseUrlConfig.ts`.

---

## §⑦ Part A Results

_(DEFERRED — filled by a later session once the environment is up. Not this session's deliverable.)_

---

## §⑧ Part B Build Log — 2026-08-08

**Part B only.** §③ Part A was not run: no dev server was started, no port probed, no API reachability
checked, no login attempted. Frontend only — no backend file, EF migration, seed, SQL, `auth.Modules`
row, menu row or capability row was touched. No route added, removed or renamed (`/ops/` and
`/platform/` both still resolve). No `Role.DefaultLandingUrl` reseed. The theme customizer's
`layout` / `sidebarType` / `navbarType` options are untouched. `route-guard.tsx` untouched (raised
below, not resolved). `BaseUrlConfig.ts` neither edited nor staged. Nothing was committed.

**Standard of proof, stated once:** everything in this log is **satisfied statically** — read of the
source, hand-trace, and a clean typecheck. **Nothing was exercised on a dev server.** Every runtime
claim is listed as pending, not as PASS.

### What landed — three independent changes

| Fix | File | Change |
|---|---|---|
| F-5.1 | `src/presentation/hooks/usePanelMenu/index.ts` | `lastGoodRef` write moved out of the render phase into a `useEffect` keyed on `[cacheKey, sections, error, hasRealMenu]`. `useEffect` added to the React import. |
| F-5.2 | `src/application/utils/module-url-match.ts` | New tier 2: deepest shared **leading path-segment** prefix (minimum two segments). Two private helpers added (`segmentsOf`, `commonSegmentDepth`). Tier 1 and tier 3 unchanged. |
| F-5.3 | `src/presentation/provider/app-shell-provider.tsx` | The tenant rail-reconcile effect now also depends on `location`, so it fires on a committed pathname change as well as on a `moduleCode` change. |

The three edits touch three different files and share no symbol, so each reverts independently
(`git checkout -- <file>` on any one leaves the other two intact). Staged, not committed.

### F-5.1 — detail

The read stays in render and the fallback stays. The load-bearing comment at lines 157-160 ("Do not
'simplify' this to `if (loading)`") is preserved verbatim; the `hasRealMenu = menus.length > 0`
source-side heuristic — the fourth 2.1 defect, already fixed — was left exactly as it was.

Why the write had to move: mutating a ref during render is unsafe under React 18 concurrent
rendering. A render that is begun and then discarded (a transition interrupted by a higher-priority
update, or StrictMode's double invoke) would still have written its `sections` into the cache, so a
module could retain the sections of a render that was never painted. The effect only runs after a
committed render, so only painted sections are cached.

Behaviour on the ordinary path is unchanged: within a single commit the effect writes after render,
and the render that *reads* the fallback is the one where `hasRealMenu` is false — which never
writes anyway. The one narrowed case is a synchronous read-back inside the same render as a fresh
write, which the previous code allowed and this does not; `resolved` returns `sections` directly in
that case (`hasRealMenu` true), so nothing observable changes.

**Deviation:** none.

### F-5.2 — the fix, and the hand-trace

Tier 2 requires a shared depth of **at least two** segments. That is deliberate, so the tiers do not
overlap: depth 1 is exactly the question tier 3 answers, so tier 2 decides *between* modules that
share a root, tier 3 decides *which* root — and tier 3 stays live rather than becoming unreachable
dead code. Ties inside tier 2 keep the earlier row (strict `>`), matching tier 1's stable-sort
behaviour. Neither exported helper's signature changed, so the single-implementation guarantee for
`useAuth` and `useActiveModule` (lines 4-7 of the file) holds.

Modules for all three traces: **CRM** = `crm/dashboards/overview` → segments `[crm, dashboards,
overview]`; **Membership** = `crm/membership/plans` → `[crm, membership, plans]`. Query order is CRM
first, which is the order that produced the old bug.

**Input 1 — `crm/membership/plan-list` → must resolve to Membership.**
Target segments `[crm, membership, plan-list]`.
Tier 1: target is not equal to, and does not start with, `crm/dashboards/overview/` or
`crm/membership/plans/` → no hit.
Tier 2: vs CRM, segment 0 `crm`=`crm`, segment 1 `membership`≠`dashboards` → depth **1**. vs
Membership, `crm`=`crm`, `membership`=`membership`, `plan-list`≠`plans` → depth **2**. Max is 2,
which clears the minimum → returns **Membership**. ✔ (The old code reached tier 3 here and returned
CRM, the first row with root `crm` — the defect.)

**Input 2 — `crm/contacts` → must resolve to CRM via the root fallback.**
Target segments `[crm, contacts]`.
Tier 1: no `moduleUrl` is a prefix → no hit.
Tier 2: vs CRM `contacts`≠`dashboards` → depth 1. vs Membership `contacts`≠`membership` → depth 1.
Max is 1, below the minimum of 2 → tier 2 declines, `deepest` stays `undefined`.
Tier 3: `moduleRoot("crm/contacts")` = `crm`; first module whose root is `crm` = **CRM**. ✔

**Input 3 — `crm/member/plan-list` → must NOT match Membership, proving segment-wise matching.**
Target segments `[crm, member, plan-list]`.
Tier 1: no hit.
Tier 2: vs Membership, segment 1 is `member` vs `membership` — compared as whole segments with `===`,
so they are unequal and the walk stops → depth **1**, not 2. (A string-wise `startsWith` would have
said `"crm/membership".startsWith("crm/member")` and awarded the match — this is exactly the case
the segment-wise comparison exists to reject.) vs CRM → depth 1. Max 1 → tier 2 declines.
Tier 3: root `crm` → **CRM**. ✔ Membership is not returned.

**Deviation:** the prompt says "insert a tier between the two … take the maximum." It does not
specify a minimum depth. I imposed the ≥2 minimum for the reason above — without it tier 2 subsumes
tier 3 (a root match *is* a depth-1 common prefix) and tier 3 becomes unreachable, which would
silently change the tier-3 tie-break from "first row in query order" to "first row at max depth" and
leave dead code behind. The three traced inputs give the required answers either way.

### F-5.3 — dependency-array trace

Final effect:

```ts
useEffect(() => {
  if (!isTenant || !moduleCode) return;
  setActiveRailKey(moduleCode);
}, [isTenant, location, moduleCode, setActiveRailKey]);
```

Four dependencies, and what each one means:

- `isTenant` — derived from the `navSource` prop; constant for the life of a mounted shell. Never a
  trigger in practice; present because the body reads it.
- `location` — `usePathname()`. **The new dependency and the whole fix.** In the App Router this
  value flips only when a navigation has *committed*: the old segment stays mounted while the new one
  resolves, and `location` changes at the moment the new route is live. That is the same commit
  signal the scrim's `navOriginRef` bookkeeping (lines 185-191) and the commit-gated 4s backstop
  (lines 200-206) already rely on — `committed = navOriginRef.current !== null && location !==
  navOriginRef.current`. So "route commit" here is not a new concept invented for this fix; it is
  the shell's existing definition, read from the same source.
- `moduleCode` — the URL-derived module, written by `useActiveModule`. Retained, so a cross-module
  navigation still reconciles even if the pathname and the module update on different ticks.
- `setActiveRailKey` — the zustand setter, referentially stable.

**Why a preview click cannot trigger it.** A rail click, per INV-8, writes `activeRailKey` and
nothing else: it does not write `moduleCode` and it does not call `router.push()`. So after a preview
click `location` is byte-identical, `moduleCode` is unchanged, `isTenant` is unchanged and
`setActiveRailKey` is the same function reference — no dependency has moved, React does not re-run
the effect, and the preview stands. `activeRailKey` itself is **deliberately absent** from the array;
including it would make the effect react to its own output and snap every preview back within a tick.
That omission is the guard, and it is the reason the fix is a dependency addition rather than a ref-
or flag-based commit detector: adding state to detect commit would have introduced a second source of
truth for something `location` already says.

**Repro the fix targets** (pending runtime confirmation): module A → preview B (`activeRailKey` = B,
`moduleCode` = A) → browser Back, a breadcrumb, or a command-palette jump *within A*. `moduleCode`
stays A, so the old effect never re-fired and the rail stayed lit on B. Now `location` changes on
that commit, the effect re-runs, and `setActiveRailKey("A")` puts the rail back on the module the
content actually belongs to.

**Known transient, stated rather than hidden:** on a *cross-module* commit, if `location` flips one
render before `useActiveModule` publishes the new `moduleCode`, the effect runs once with the
outgoing `moduleCode` and then again when `moduleCode` lands. If the user had previewed the
destination module first, the rail can show one frame of the outgoing module before settling on the
destination. It is self-correcting because `moduleCode` is still a dependency, and it is a frame
long. Whether it is visible at all needs a dev server — see A5 below.

**Deviation:** the prompt suggested reconciling via the existing `navOriginRef` commit machinery.
`navOriginRef` only tracks commits *while the scrim is up* (`isMenuRendering`) — it is `null`
whenever the scrim is down, so a browser Back with no scrim, which is precisely the repro in §F-5.3,
would not register as a commit through it. `location` changing **is** the commit signal
`navOriginRef` is derived from, so depending on it directly is both correct in more cases and
smaller. No new state was added.

### Verification

`rm -rf .next/types && npx tsc --noEmit --incremental false`, run from `PSS_2.0_Frontend`.
**Exit code, verbatim: `0`.** No errors, no output. Because it passed on the first run, the
"re-run before believing a failure" step for concurrent-session `TS6053` phantoms was not needed.

`npm run build` was **not** run. No test suite was run — there is none covering
`module-url-match.ts`; the three F-5.2 traces above are hand-executed against the final source, not
machine-executed.

### Pending runtime confirmation — not PASS, not FAIL

None of these was exercised. They are the acceptance points each fix still owes:

- **F-5.1 → A11, A12.** A12 is the direct test of the `lastGood` cache (module switch must not blank
  the panel through a `cache-and-network` refetch). A11 alongside it.
- **F-5.2 → A9, A1.** A9 on the deepest seeded module — the one whose `moduleUrl` shares a root with
  a shallower module; A1 for ordering, since the old defect only showed itself under a particular
  `USER_ROLE_MODULES` row order.
- **F-5.3 → A3, A5, A10**, plus the specific repro: module A → preview B → browser Back → the rail
  must show A.

### Open item — raised, not resolved

**`route-guard.tsx`** (§⑤). Body commented out end to end (`return <>{children}</>`), still imported
and rendered by the `(core)`, `(master)` and `(setup)` layouts, still holding the `MASTER_URL` import
at line 3 — which is what still blocks the `MASTER_URL` removal Phase 3 §3a.6 deliberately left open.
Restoring the guard and deleting it have opposite security consequences, so it is the user's call.
Untouched by this session.

### Staged

From inside the nested repo `PSS_2.0_Frontend` (it owns its own `.git/`), staged with `git add`:

- `src/application/utils/module-url-match.ts` (F-5.2)
- `src/presentation/hooks/usePanelMenu/index.ts` (F-5.1)
- `src/presentation/provider/app-shell-provider.tsx` (F-5.3)

`src/application/configs/navigation-configs/BaseUrlConfig.ts` is dirty in the working tree and was
**left unstaged**, as required. Four other files were already staged before this session by the §⑩
shell-accent work (`app-rail/index.tsx`, `glass-bar.ts`, `useShellAccent/index.ts`, `globals.scss`);
they are not part of Part B and were not modified here. **Nothing was committed.**

---

## §⑨ Guide-session review of Part B — 2026-08-08

Diffs read directly (`git diff --cached` on the nested `PSS_2.0_Frontend` repo), not accepted from
the build report. All three fixes are **accepted**, both deviations are **accepted**, and staging is
as described: exactly the three F-5 files plus the four pre-existing shell-accent files, with
`BaseUrlConfig.ts` dirty and unstaged, nothing committed.

Two residual items, neither a defect in Part B, both to be watched when Part A runs:

1. **Tier 3 is still query-order dependent, and F-5.2 does not claim otherwise.** For a
   single-segment-distinct path such as `crm/contacts`, every `crm`-rooted module ties at depth 1,
   tier 2 correctly declines, and tier 3 returns whichever row `USER_ROLE_MODULES` ordered first.
   F-5.2 fixes the *deep* collision (`crm/membership/plan-list`) and deliberately leaves the shallow
   one, because at depth 1 the data genuinely does not say who owns the route. **This is a seeding
   question, not a comparator question** — if a root-level screen resolves to the wrong module during
   **A9**, the fix is the module's `ModuleUrl`, not this file. Do not "fix" it by lowering the ≥2
   minimum; that removes tier 3 rather than disambiguating it.

2. **The cross-module transient the build log declares under F-5.3 is real, and A5 is the point that
   sees it.** On a commit into a *previously previewed* module, `location` can flip one render before
   `useActiveModule` publishes the new `moduleCode`, so the effect runs once with the outgoing code.
   It self-corrects on the next render. **It is very likely invisible in practice** — a panel leaf
   click raises the scrim (`ContextPanel` calls `setIsMenuRendering(true)` before navigating), and
   the scrim covers exactly the frames in question. If **A3/A5/A10** show no flicker, record it as
   PASS and leave the code alone; a guard here would cost more than the frame it saves.

Nothing in Part B needs rework before Part A.
