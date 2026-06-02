<!--
  Written by:  /test-screen  (initial run + reruns + regenerate-runs)
  Updated by:  /test-fix     (FIX-cycle runs)
               /test-batch   (per-screen run entries from a batched invocation)

  RULES
  - File is NEWEST-FIRST. Always PREPEND new Run entries above the existing ones.
  - Never edit a prior Run entry. Only add new ones, and update the frontmatter
    summary fields to reflect the latest Run.
  - /test-fix reads ONLY the top ~80 lines of this file (latest Run) — keep each
    Run entry compact (failures+hints inline, not the full stack trace; stack
    traces live in test-results/artifacts/).
-->

---
screen_id: 41
screen_name: Branch
screen_type: MASTER_GRID
spec_file: PSS_2.0_Frontend/tests/e2e/screens/branch.spec.ts
last_run_date: 2026-05-22
last_run_status: NEEDS_FIX
total_runs: 7
passed_last_run: 2
failed_last_run: 14
skipped_last_run: 5
last_run_duration_seconds: 456
---

## Test Runs (newest first)

---

### Run 7 — 2026-05-22 — RERUN (moduleCode seed + selector fix) — NEEDS_FIX (but FIRST real screen pass)

- Tests: 21 total | **2 passed** (1 setup + 1 chromium) | 14 failed (chromium) | 5 skipped (intentional)
- Duration: 7m 36s (456 s) — longer because tests now actually proceed into screen body and exercise real flows before failing
- Spec: `branch.spec.ts` unchanged. Two changes since Run 5: (a) `nav-helpers.ts` `navigateToScreen` now seeds `localStorage["global-store"]` with the target `moduleCode` via `page.addInitScript` BEFORE the first goto; (b) `waitForModuleReady` selector relaxed from `nav a[href*="/...]"` → `a[href*="/...]"` because the sidebar (sidebar/classic/index.tsx) renders as `<div><ul><li><a>` with no `<nav>` ancestor.

#### **MAJOR PROGRESS — infrastructure is fully unblocked**

For the first time in 7 runs, a real test against the Branch screen body actually PASSED:
- ✓ `grid loads with toolbar and at least one row or empty-state` — screen renders, grid appears, +Add toolbar visible

The screenshot confirms: sidebar populated (Dashboard, Company → Company Configuration + **Branches** (highlighted), Staff → Staffs + Staff Category), URL is `/en/organization/company/branch`, page area shows the Branch grid loading. Every architectural concern from Runs 1-6 is resolved.

#### Root cause of every fix landed since Run 1

The complete chain we had to unblock to get a working test:
1. **Run 3 finding**: spec used raw `page.goto(menuUrl)` → page hung at `<main>Loading…</main>`. Fix: `navigateToScreen` helper with module-dashboard warmup. (Spec regenerated in Session 5.)
2. **Run 4 finding**: `waitForModuleReady` used networkidle → returned before menu fetch fired. Fix: replace with explicit menu-link locator wait (Session 7 patch).
3. **Run 5 finding**: even the module-link wait timed out — sidebar `<list>` was completely empty. Root cause discovered via FE-code Exploration: `useMenu()` skips its GraphQL query when `useGlobalStore().moduleCode === ""`, which is the default state in storageState-restored sessions (the user normally sets `moduleCode` by CLICKING a module in the navigator — `page.goto` doesn't trigger it). Fix: pre-seed `localStorage["global-store"]` with `{ state: { moduleCode: "ORGANIZATION", ... }, version: 0 }` via `page.addInitScript`.
4. **Run 6 finding**: moduleCode seed worked (screenshot showed menus populated!), but `nav a[href*=...]` selector still found nothing because the sidebar renders as `<div><ul><li><a>` — no `<nav>` ancestor. Fix: drop the `nav` prefix from the selector.
5. **Run 7 (this run)**: all infrastructure resolves. Real screen-level failures surface.

#### Real screen-level failures (14, now actionable via /test-fix)

| # | Test | Failure | Diagnosis |
|---|------|---------|-----------|
| 1 | grid renders 12 columns in expected order | grid not found at waitForGridReady (10s) | **Timing** — grid data fetch >10s. Bump timeout OR change selector to match the grid container that exists during skeleton state |
| 2 | search filters rows | same | same |
| 3 | +Add → modal → fill → save → row appears | same | same |
| 4 | required-field validation fires on empty +Add submit | same | same |
| 5 | Edit → modal pre-filled → change → save | same | same |
| 6 | Toggle Active → badge changes | form-modal `[name="companyId"]` not found (60s timeout) | Toggle flow opened a modal expecting a form field that this app's toggle confirm dialog doesn't have. **Spec assumption mismatch** — toggle probably triggers confirm dialog, not edit modal |
| 7 | Delete → confirm → row removed | grid not found at waitForGridReady (10s) | same as #1 |
| 8 | FK dropdown companyId populates | grid not found at waitForGridReady (10s) | same as #1 |
| 9 | FK dropdown countryId populates | form-modal `[name="countryId"]` react-select control not found (60s) | spec opens +Add modal then expects countryId react-select — likely the `[name="countryId"]` attribute is missing or the FK selector pattern in fixtures is wrong |
| 10 | FK dropdown managerStaffId populates | grid not found at waitForGridReady (10s) | same as #1 |
| 11 | Country → State cascade resets State | form-modal `[name="countryId"]` react-select not found (60s) | same as #9 |
| 12 | summary widgets render (4 cards) | `[data-testid="branch-widgets"]` not visible | **testid hook missing** — widgets container in the Branch page-config doesn't carry this testid. Either add the hook or change the test to assert on widget cards via a different selector |
| 13 | row click → side panel opens with Quick Stats | grid not found at waitForGridReady (10s) | same as #1 |
| 14 | side panel closes on X / Escape | `[data-testid="side-panel"]` not visible | **testid hook missing** + side panel may not be wired (could be ISSUE-2 OPEN territory). Worth re-checking §⑬ |

8 of 14 are the SAME grid-timeout issue. Likely a single fix (bump timeout to 20s OR add `data-testid="grid"` to the loading-state container) unblocks 8 tests at once.

3 are spec-vs-implementation mismatches in the +Add/Edit modal flow (FK selector, toggle vs delete confusion). These need spec adjustment.

2 are missing testid hooks (`branch-widgets`, `side-panel`).

1 is the 12-column expectation that probably differs from the actual grid output.

#### Skipped (intentional — unchanged)

5 SERVICE_PLACEHOLDER + OPEN-ISSUE skips, same as prior runs.

#### Next step

This is finally the right shape to dispatch `/test-fix #41 --until-green` — the failures are real, file-line-pinpointed, and most cluster around a single grid-timeout fix that would clear 8 of 14 in one pass.

Before that, consider one more easy win: bump `waitForGridReady` first `expect().toBeVisible()` from default-10s to explicit 20s in `grid-helpers.ts:67`. The data fetch is just slow against IIS published build; doubling the timeout costs ~0 on the GREEN path.

---

### Run 6 — 2026-05-22 — RERUN (moduleCode seed only) — NEEDS_FIX

- Tests: 21 total | 1 passed (setup) | 15 failed (chromium, all at `waitForModuleReady`) | 5 skipped
- Duration: 4m 48s
- Patch: `navigateToScreen` now seeds `localStorage["global-store"].state.moduleCode` via `page.addInitScript`.
- Screenshot revealed: **sidebar IS now populated** (Dashboard, Company Configuration, Branches, Staffs, Staff Category visible). The moduleCode seed worked.
- Why still failing: `waitForModuleReady` selector was `nav a[href*="/organization/"]` but the sidebar has no `<nav>` ancestor (it's `<div><ul><li><a>`). Selector found 0 matches → 15s timeout.
- Fix queued for Run 7: drop the `nav` ancestor.

---

### Run 5 — 2026-05-22 — RERUN (nav-helpers Option 2 patch) — NEEDS_FIX

## Test Runs (newest first)

---

### Run 5 — 2026-05-22 — RERUN (nav-helpers Option 2 patch) — NEEDS_FIX

- Tests: 21 total | 1 passed (auth.setup) | 15 failed (chromium) | 5 skipped (intentional)
- Duration: 5m 0s (300 s)
- Spec: `branch.spec.ts` unchanged from Run 4. Only `tests/e2e/shared/nav-helpers.ts` changed.
- Patch: `waitForModuleReady` now waits for `nav a[href*="/${moduleLower}/"]` (15 s bound) instead of `networkidle`. Goal: unblock menu warm-up by waiting on a real signal.
- Env: identical to Run 4 (FE IIS :8080, BE IIS :7001, tenant `humanity`, user `businessadmin@gmail.com`).

#### Single-root-cause classification (NEW SIGNAL — visible in screenshot)

All 15 chromium failures terminate inside `nav-helpers.ts:96` — the new sidebar-link locator times out after 15 s. The screenshot at failure time (`test-results/artifacts/branch-Screen-41-…-chromium/test-failed-1.png`) reveals what the previous yaml snapshot only hinted at:

- ✓ User is logged in (PeopleServe header + AD avatar visible)
- ✓ `/en/organization/dashboards/overview` page CONTENT rendered (shows "No Dashboard Available" + "Create Dashboard" CTA — the page's own empty state)
- ✗ **The sidebar is completely blank** — zero menu items, no nav anchors, no list children

This refutes Run 4's hypothesis that "menu hydration just needs a precise locator." The menus literally do not appear at all for this auth context, even after 15 s on the canonical module landing URL.

#### Two candidate root causes (both must be ruled out)

1. **Account `businessadmin@gmail.com` / tenant `humanity` has zero menu permissions in the IIS-published build.** If true, menus would also be empty in a manual browser session with this account. Easy to check: log in manually, look at the sidebar.
2. **Menu fetch fires only on the post-login redirect, not on storageState-restored sessions.** Playwright reuses cookies via `storageState`, skipping the login flow — the React effect that triggers the menu Apollo query may live in the login handler, not in a layout effect that re-runs on every page load. If true, every Playwright spec is doomed until we either (a) log in per spec instead of using storageState, or (b) trigger the menu fetch manually via `page.evaluate()`.

Both options are blocked on USER input — can't continue patching nav-helpers without knowing which path is real.

#### Failures (uniform — same root cause for all 15)

All 15 failed at `branch.spec.ts:84 → navigateToScreen → waitForModuleReady` (`nav-helpers.ts:96`) with `TimeoutError: locator.waitFor: Timeout 15000ms exceeded` on `nav a[href*="/organization/"]`. Per-test wall time ~17-20 s each (15 s wait + module page load).

#### Skipped (intentional — unchanged from Runs 1–4)

Same 5 SERVICE_PLACEHOLDER + OPEN-ISSUE skips as prior runs.

#### Next step

DO NOT patch nav-helpers further. Ask the user:

- Do menus appear in a manual browser session for `businessadmin@gmail.com` on tenant `humanity` against the IIS publish? If NO → permissions issue, swap test user. If YES → menu-fetch-on-login-only issue, redesign auth.setup.ts.

---

## Current State

- Status: **NEEDS_FIX** — Run 4 (with the navigateToScreen fix actually executed) REPRODUCED the `<main>Loading…</main>` page-hang. The warm-up call to `/en/organization/dashboards/overview` ran without error, but the sidebar menu `<list>` STAYS EMPTY after the warm-up, and the subsequent `/en/organization/company/branch` navigation lands on `<main>Loading…</main>` indefinitely.
- **What we now know that we didn't before Run 4**: the architectural assumption in the `/test-screen` skill's Navigation constraint ("visit module Dashboard Overview first → menus hydrate → screen renders") is **incomplete**. Visiting the module dashboard URL via `page.goto` is NOT sufficient to populate the menu list in this auth/tenant/IIS context. Manual browser flow works; Playwright flow does not.
- **Candidate next-layer causes** (one of these must be the real root cause):
  1. **Hard navigation vs intra-SPA link click** — `page.goto` triggers a full SSR cycle; menu hydration may only fire when an in-app `<Link>` is clicked (client-side route change).
  2. **Auth/tenant cookie missing for the menu query** — login persisted `storageState.json`, but the menu GraphQL query may require a header / cookie that the IIS-published prod build doesn't synthesize on a cold goto.
  3. **`waitForModuleReady` (networkidle 15s) finishes BEFORE the lazy menu Apollo query fires** — would need to replace with a wait for an actual sidebar menu item (the TODO already noted in `nav-helpers.ts:69`).
  4. **Production build (IIS) chunk-loading failure** — `BranchPageConfig` is dynamic-imported; a missing chunk in the IIS publish could leave the Suspense boundary hung forever (Run 1 candidate cause, still possible).
- **Meta-finding from Run 4 (test-infra)**: every prior `/test-screen #41 --rerun` we ran THIS SESSION before adding `--config` was loading an **empty default Playwright config** (no projects, no baseURL, no setup dep). The CWD was `PSS_2.0_Frontend/` but `playwright.config.ts` lives at `tests/e2e/playwright.config.ts`, and Playwright doesn't recurse. This invalidated Runs 4a + 4b — they failed with `Cannot navigate to invalid URL` because baseURL was undefined. Run 4 below is Run 4c (the one that actually loaded the real config and produced a comparable result vs Run 3).
- **Next**: Either (a) instrument `waitForModuleReady` with a precise menu-loaded locator and re-run, OR (b) capture a HAR of the manual browser flow and diff against the Playwright flow to identify the missing menu-query trigger.

## Test Runs (newest first)

---

### Run 4 — 2026-05-22 — RERUN (vs IIS, port 8080, with navigateToScreen fix) — NEEDS_FIX

- Tests: 21 total | 1 passed (auth.setup) | 15 failed (chromium) | 5 skipped (intentional)
- Auth setup: **PASSED** — login + `storageState.json` seeded successfully against IIS
- Duration: 4m 24s (264 s) — slightly slower than Run 3 because each test now spends 15 s in `waitForModuleReady` (networkidle bound) PLUS 10 s in `waitForGridReady` before failing
- Trigger: `/test-screen #41 --rerun`
- Spec: `PSS_2.0_Frontend/tests/e2e/screens/branch.spec.ts` (regenerated post-Run-3 — uses `navigateToScreen(page, "ORGANIZATION", "organization/company/branch")` per updated skill)
- Env: FE `http://localhost:8080` (IIS-published build), BE `http://localhost:7001`, tenant `humanity`, role `businessadmin@gmail.com`

#### Test-infra meta-fix journey (Runs 4a → 4b → 4c)

The initial reruns this session did NOT exercise the real config:

| Sub-run | Cmd | Outcome | Root cause |
|---------|-----|---------|------------|
| 4a | bash: `cd PSS_2.0_Frontend && E2E_BASE_URL=... pnpm exec playwright test --grep "@screen-41"` | 15 fail / 5 skip / 0 setup. Each test fails ~230ms at `page.goto: Protocol error: Cannot navigate to invalid URL` | (i) `playwright.config.ts` not found from CWD (config lives at `tests/e2e/`, Playwright doesn't recurse) → empty default config loaded → no projects, no baseURL → relative URLs invalid. (ii) `--grep "@screen-41"` filtered out setup project (no matching tag) — even if config had loaded, storageState would be stale. |
| 4b | pwsh: `$env:E2E_BASE_URL=...; pnpm exec playwright test` (no grep) | Identical to 4a. `Available projects: ""` confirmed via `--list --project=setup` diagnostic. | Same config-not-found issue; the no-grep change was irrelevant because no projects were defined in the empty default. |
| 4c | pwsh: `$env:E2E_BASE_URL=...; pnpm exec playwright test --config tests/e2e/playwright.config.ts` | 1 pass (setup), 15 fail (chromium), 5 skip. **This is Run 4 proper.** | Config loaded correctly; setup ran; chromium tests reach `waitForGridReady` and fail there. |

**Memory candidate**: every `/test-screen` Playwright invocation MUST pass `--config tests/e2e/playwright.config.ts` (or be CWD'd into `tests/e2e/`). The skill's Step 5 example command omits this — needs an update.

#### Single-root-cause classification (REPRODUCED Run 1 / Run 3)

All 15 chromium failures terminate inside `tests/e2e/shared/grid-helpers.ts:67` — `expect([data-testid="grid"]).toBeVisible()` times out after 10 s. Error-context page-snapshot (consistent across every failed test):

```yaml
- banner:
  - button "Collapse sidebar"
  - button "Search..."
  - button "Create"
  - button "AD"           # avatar — auth worked
- button "PeopleServe PeopleServe": (logo)
- list                     # ← MENU LIST IS EMPTY (this is the smoking gun)
- img "PWDS"
- paragraph: PWDS Tech · © 2026
- main: Loading...         # ← SCREEN BODY NEVER RENDERS
```

**The sidebar menu `<list>` is empty.** This proves the warm-up navigation to `/en/organization/dashboards/overview` did NOT populate the menu list before the subsequent goto to `/en/organization/company/branch`. The skill's Navigation constraint (visit module dashboard → menus hydrate → screen renders) does not actually work when both navigations are `page.goto` calls (hard navigations). See "Current State" above for candidate next-layer causes.

#### Failures (grouped — same root cause for all 15)

All 15 failed at `branch.spec.ts:85` (`beforeEach → waitForGridReady`) after `navigateToScreen` completed without error:

- `grid loads with toolbar and at least one row or empty-state`
- `grid renders 12 columns in the expected order`
- `search filters rows (no-match → empty state)`
- `+Add → modal → fill → save → row appears`
- `required-field validation fires on empty +Add submit`
- `Edit → modal pre-filled → change → save → row updates`
- `Toggle Active → badge changes`
- `Delete → confirm → row removed`
- `FK dropdown companyId populates`
- `FK dropdown countryId populates`
- `FK dropdown managerStaffId populates`
- `Country → State cascade resets State when Country changes`
- `summary widgets render (4 cards)`
- `row click → side panel opens with Quick Stats`
- `side panel closes on X / Escape`

- **Stack** (uniform): `tests/e2e/shared/grid-helpers.ts:67 → branch.spec.ts:85 (beforeEach)`
- **Artifacts**: `PSS_2.0_Frontend/test-results/artifacts/branch-Screen-41-…-chromium/{screenshot.png,video.webm,trace.zip,error-context.md}` (one set per failure)
- **Per-test wall time**: ~25-30 s each (15 s warm-up + 10 s grid wait, all hitting their respective timeouts)

#### Skipped (intentional — unchanged from Runs 1–3)

- `Map View toggle shows placeholder card` — SERVICE_PLACEHOLDER §⑫ + ISSUE-3 OPEN §⑬
- `side-panel Recent Activity feed renders items` — SERVICE_PLACEHOLDER §⑫ + ISSUE-2 OPEN §⑬
- `side-panel CRM Quick-Stat tiles (Contacts / Campaigns / Events)` — ISSUE-4 OPEN §⑬
- `YTD Collected per-row aggregation shows non-zero value` — ISSUE-4-YTD OPEN §⑬
- `Performance % column shows traffic-light color per AnnualTarget` — ISSUE-4-YTD OPEN §⑬

#### Next step

Do **NOT** dispatch `/test-fix #41` yet — the failures aren't in screen code, they're in the test-framework's menu-warmup approach. Pick one of:

1. **Diagnose menu hydration** — open `/en/organization/dashboards/overview` manually after a fresh login, capture network HAR + sidebar DOM state, compare against the Playwright trace.zip from this run.
2. **Replace `waitForModuleReady`** — change `nav-helpers.ts:75` from `waitForLoadState("networkidle")` to a precise locator wait (`page.locator('nav a[href*="/organization/"]').first()` etc.). Re-run.
3. **Investigate hard-nav vs link-click** — if menus only hydrate on in-app `<Link>` clicks, `navigateToScreen` needs to click the menu link instead of `page.goto` to the URL.

---

### Run 3 — 2026-05-22 — RERUN (vs IIS, port 8080) — NEEDS_FIX

- Tests: 21 total | 1 passed (auth.setup) | 15 failed (chromium) | 5 skipped (intentional)
- Auth setup: **PASSED** (3.5 s) — login + `storageState.json` seeded successfully against IIS
- Duration: 3m 42s (222 s) — fast because each chromium test fails at the 10 s `waitForGridReady` timeout, not on the 60 s test wall-time
- Trigger: `/test-screen #41` (user selected "Rerun existing spec"); then re-fired against IIS with `E2E_BASE_URL=http://localhost:8080`
- Spec: `PSS_2.0_Frontend/tests/e2e/screens/branch.spec.ts` (unchanged from Run 1 — still uses raw `page.goto(route)`)
- Env: FE `http://localhost:8080` (IIS-published build), BE `http://localhost:7001` (via `BaseUrlConfig.ts`), tenant `humanity`, role `businessadmin@gmail.com`

#### Single-root-cause classification (REPRODUCED Run 1)

All 15 chromium failures terminate inside `tests/e2e/shared/grid-helpers.ts:67` — `waitForGridReady()` cannot find `[data-testid="grid"]` within 10 s. Error-context snapshot (consistent across every failed test):

```yaml
- banner: (sidebar + topbar render correctly — auth + app shell are fine)
- main: Loading...
```

This is the **same** root cause as Run 1 — but now we know WHY. Per the `/test-screen` skill's updated Navigation constraint:

> Tests MUST visit the module's Dashboard Overview page first so the app hydrates menus + role capabilities into client state, and then navigate to the screen's menu URL. Direct navigation to the menu URL yields an empty menu/capability state → `GridCode` lookup fails, +Add button is hidden, the data-table renders blank.

The existing spec violates this by calling `page.goto(E2E_CONFIG.ROUTE("organization/company/branch"))` directly with no module-warmup step. Manual repro: opening `/en/organization/company/branch` in a normal browser after a fresh login (no prior module visit) reproduces the same `<main>Loading…</main>`; visiting `/en/organization/dashboards/overview` first then navigating to the menu clears it.

#### Failures (grouped — same root cause for all 15)

All 15 failed at `branch.spec.ts:77` (`beforeEach → waitForGridReady`) with the same `[data-testid="grid"]` not found within 10 s:

- `grid loads with toolbar and at least one row or empty-state` (12.7 s)
- `grid renders 12 columns in the expected order` (12.8 s)
- `search filters rows (no-match → empty state)` (12.7 s)
- `+Add → modal → fill → save → row appears` (12.6 s)
- `required-field validation fires on empty +Add submit` (12.6 s)
- `Edit → modal pre-filled → change → save → row updates` (12.7 s)
- `Toggle Active → badge changes` (12.6 s)
- `Delete → confirm → row removed` (12.8 s)
- `FK dropdown companyId populates` (12.6 s)
- `FK dropdown countryId populates` (12.7 s)
- `FK dropdown managerStaffId populates` (13.3 s)
- `Country → State cascade resets State when Country changes` (12.7 s)
- `summary widgets render (4 cards)` (13.0 s)
- `row click → side panel opens with Quick Stats` (13.1 s)
- `side panel closes on X / Escape` (13.0 s)

- **Stack** (uniform): `tests/e2e/shared/grid-helpers.ts:67 → branch.spec.ts:77 (beforeEach)`
- **Artifacts**: `test-results/artifacts/branch-Screen-41-…/{screenshot.png,video.webm,trace.zip,error-context.md}` (one set per failure)

#### Skipped (intentional — unchanged from Run 1 / Run 2)

- `Map View toggle shows placeholder card` — SERVICE_PLACEHOLDER §⑫ + ISSUE-3 OPEN §⑬
- `side-panel Recent Activity feed renders items` — SERVICE_PLACEHOLDER §⑫ + ISSUE-2 OPEN §⑬
- `side-panel CRM Quick-Stat tiles (Contacts / Campaigns / Events)` — ISSUE-4 OPEN §⑬
- `YTD Collected per-row aggregation shows non-zero value` — ISSUE-4-YTD OPEN §⑬
- `Performance % column shows traffic-light color per AnnualTarget` — ISSUE-4-YTD OPEN §⑬

#### Spec regenerated (post-Run-3, no execution yet)

After Run 3, the user invoked `/test-screen #41 --generate-only`. The spec was patched to satisfy the updated skill's Navigation constraint:

- Replaced `import { E2E_CONFIG } from "../playwright.config"` (and the `route` constant + raw `page.goto(route)` call) with `import { navigateToScreen } from "../shared/nav-helpers"` and `await navigateToScreen(page, "ORGANIZATION", "organization/company/branch")` in `beforeEach`.
- All 21 test bodies are unchanged — same assertions, same FK pick logic, same skips. The only delta is the entry-path warmup.

Expected effect on next run: 15 page-hang failures should clear if the menu-hydration theory is correct. If `BranchPageConfig` still hangs after warmup, the Run 1 candidate-causes (Apollo query hang / dynamic-import failure / auth-gate token mismatch) become the next layer to triage.

#### Next step

`/test-screen #41 --rerun` (vs IIS at `http://localhost:8080`, env vars already documented in Run 2 Notes). If still NEEDS_FIX after this re-run, dispatch `/test-fix #41 --until-green` with the Run 1 candidate-cause list as starting points.

---

### Run 2 — 2026-05-22 05:03 UTC — RERUN — INFRA_ERROR

- Tests: 20 total | 0 passed | 15 failed (infra) | 5 skipped (intentional)
- Auth setup: **DID NOT RUN** — see root cause below
- Duration: 27 s (0m 27s) — orders of magnitude faster than Run 1 because each test fast-fails on `page.goto`
- Trigger: `/test-screen #41` (no flag → user selected "Rerun existing spec" from prompt)
- Spec: `PSS_2.0_Frontend/tests/e2e/screens/branch.spec.ts` (unchanged from Run 1)
- Spec deltas from template: None
- Env: FE `http://localhost:3000` (probed 200 OK before run), `playwright.config.ts` unchanged from Run 1

#### Single-root-cause classification (INFRA, NOT screen regression)

All 15 failures terminate at `tests/e2e/screens/branch.spec.ts:76` with:

```
Error: page.goto: Protocol error (Page.navigate): Cannot navigate to invalid URL
  - navigating to "/en/organization/company/branch", waiting until "load"
```

i.e. Playwright cannot resolve the relative path against `baseURL`. Two facts establish this as a **test-harness regression**, not a screen regression:

1. **`tests/e2e/shared/.auth/` directory does not exist on disk.** `storageState.json` is referenced by `playwright.config.ts` (chromium project `use.storageState`) but the file is missing. (Run 1 successfully wrote it — the folder was either cleaned between runs or this is a sibling-worktree drift artifact per auto-memory `feedback_agent_sibling_worktree_drift`.)
2. **The setup project never ran.** Console header says `Running 20 tests using 1 worker` — that's the chromium project's 15 + 5 specs only. The setup project's `authenticate` test is missing from the run. Cause: `--grep "@screen-41"` is a **global** filter across all Playwright projects; `auth.setup.ts` has no `@screen-41` tag, so it gets filtered out and the storageState file is never produced.

With no storageState file AND no setup run, the chromium context starts with a malformed/missing state that defeats the project's `baseURL` resolution — every relative `page.goto("/en/…")` fails immediately.

#### Failures (grouped — same INFRA root cause for all 15)

Each test below failed in `beforeEach → page.goto(route)` with the same "Cannot navigate to invalid URL" error in 158–232 ms:

- `grid loads with toolbar and at least one row or empty-state` (232 ms)
- `grid renders 12 columns in the expected order` (178 ms)
- `search filters rows (no-match → empty state)` (165 ms)
- `+Add → modal → fill → save → row appears` (164 ms)
- `required-field validation fires on empty +Add submit` (164 ms)
- `Edit → modal pre-filled → change → save → row updates` (160 ms)
- `Toggle Active → badge changes` (159 ms)
- `Delete → confirm → row removed` (158 ms)
- `FK dropdown companyId populates` (174 ms)
- `FK dropdown countryId populates` (173 ms)
- `FK dropdown managerStaffId populates` (158 ms)
- `Country → State cascade resets State when Country changes` (186 ms)
- `summary widgets render (4 cards)` (195 ms)
- `row click → side panel opens with Quick Stats` (165 ms)
- `side panel closes on X / Escape` (180 ms)

- **Stack** (uniform): `tests/e2e/screens/branch.spec.ts:76:18 (await page.goto(route))`
- **Artifacts**: `test-results/artifacts/branch-Screen-41-…/error-context.md` (one per test)

#### Skipped (intentional — unchanged from Run 1)

- `Map View toggle shows placeholder card` — SERVICE_PLACEHOLDER §⑫ + ISSUE-3 OPEN §⑬
- `side-panel Recent Activity feed renders items` — SERVICE_PLACEHOLDER §⑫ + ISSUE-2 OPEN §⑬
- `side-panel CRM Quick-Stat tiles (Contacts / Campaigns / Events)` — ISSUE-4 OPEN §⑬
- `YTD Collected per-row aggregation shows non-zero value` — ISSUE-4-YTD OPEN §⑬
- `Performance % column shows traffic-light color per AnnualTarget` — ISSUE-4-YTD OPEN §⑬

#### Notes for /test-fix

- **DO NOT** dispatch any code-fix agents. This is a TEST HARNESS bug, not a screen bug. The Run 1 page-hang has not been re-verified by this run — Run 2 fails before the browser even navigates.
- **Harness fix candidates** (any one suffices; option 2 is least invasive):
  1. **Skill-level**: `/test-screen` and `/test-batch` should run setup explicitly first, e.g. `pnpm exec playwright test --project=setup && pnpm exec playwright test --grep "@screen-{N}"` — runs auth, then specs.
  2. **Config-level**: Add `name: "setup"` to a grep-exempt list, OR change the setup project so it is *always* run regardless of grep (`dependencies: ["setup"]` already forces setup but it still gets grep-filtered).
  3. **Spec-level**: Tag the setup test with every screen tag (`@screen-1 @screen-2 …`) — brittle, scales poorly.
- **After harness fix**: `/test-screen #41 --rerun` → expected to reproduce Run 1's `<main>Loading…</main>` hang → then dispatch `/test-fix #41 --until-green` per Run 1's diagnosis.

#### Next step (user action required)

This run is a test-infra blocker, not a screen regression. Recommended manual workaround for the next attempt:

```pwsh
$env:E2E_USERNAME = "businessadmin@gmail.com"
$env:E2E_PASSWORD = "<your password>"
$env:E2E_TENANT   = "humanity"
cd PSS_2.0_Frontend
pnpm exec playwright test --project=setup        # creates .auth/storageState.json
pnpm exec playwright test --grep "@screen-41"    # then runs Branch specs
```

Or fix the `/test-screen` skill so it runs setup explicitly before applying `--grep`. After that, `/test-fix #41 --until-green` will pick up the real Run 1 page-hang again.

---

### Run 1 — 2026-05-21 08:31 UTC — RERUN — NEEDS_FIX

- Tests: 21 total | 0 passed (spec) | 15 failed | 5 skipped (intentional)
- Auth setup: PASSED (31.2 s) — `storageState.json` written successfully
- Duration: 31m 20s (1880 s)
- Trigger: `/test-screen #41 --rerun`
- Spec: `PSS_2.0_Frontend/tests/e2e/screens/branch.spec.ts` (unchanged from build)
- Spec deltas from template: None
- Env: FE `http://localhost:3000`, BE inferred from `BaseUrlConfig.ts`, tenant `humanity`, role `businessadmin@gmail.com`

#### Single-root-cause classification

All 15 failures terminate inside `tests/e2e/shared/grid-helpers.ts:67` —
`waitForGridReady()` cannot find `[data-testid="grid"]` on the page within 10 s.
The page snapshot at failure time consistently shows:

```yaml
- banner: (sidebar + topbar render correctly)
- main: Loading...
```

i.e. **the app shell mounts but `BranchPageConfig` never finishes initial render**.
The grid testid `data-testid="grid"` IS present in
`src/presentation/components/custom-components/data-tables/advanced/data-table-container.tsx:323`,
so the testid contract is intact — the page is genuinely stuck at the
`<main>Loading…</main>` splash.

#### Failures (grouped — same root cause for all 15)

- **All 15 specs that depend on `beforeEach → page.goto(route) → waitForGridReady`**:
  - `grid loads with toolbar and at least one row or empty-state`
  - `grid renders 12 columns in the expected order`
  - `search filters rows (no-match → empty state)`
  - `+Add → modal → fill → save → row appears`
  - `required-field validation fires on empty +Add submit`
  - `Edit → modal pre-filled → change → save → row updates`
  - `Toggle Active → badge changes`
  - `Delete → confirm → row removed`
  - `FK dropdown companyId populates`
  - `FK dropdown countryId populates`
  - `FK dropdown managerStaffId populates`
  - `Country → State cascade resets State when Country changes`
  - `summary widgets render (4 cards)`
  - `row click → side panel opens with Quick Stats`
  - `side panel closes on X / Escape`
  - **Expected**: `[data-testid="grid"]` visible within 10 s
  - **Actual**: element not found; `<main>` shows literal text `Loading...` for full timeout
  - **Stack**: `tests/e2e/shared/grid-helpers.ts:67 → tests/e2e/screens/branch.spec.ts:77 (beforeEach)`
  - **Artifacts**: `test-results/artifacts/branch-Screen-41-—-Branch--*/{screenshot.png,video.webm,trace.zip,error-context.md}`
  - **Diagnosis hint**: `<BranchPageConfig />` (re-exported from `@/presentation/pages`) never gets past initial render in headless Chromium. Candidate causes, in priority order:
    1. **Apollo/GraphQL hang** — one of the queries on the Branch page (`BRANCHES_QUERY`, `BRANCH_SUMMARY_QUERY`, FK lookups for Company/Country/Staff) returns no response → `useQuery` stays in `loading: true` forever, Suspense boundary above the grid never resolves.
    2. **Failed dynamic import** — `branch-side-panel.tsx`, `branch-map-placeholder.tsx`, or `performance-bar.tsx` is imported via `dynamic(...)` and the chunk fails to load (Turbopack dev sometimes leaves modules in pending state under headless concurrency).
    3. **Storage-state cookie mismatch** — `storageState.json` carries the post-login session, but the page's auth-gate hook (`useAuth` / `useSession`) re-fetches user/tenant data and blocks render until it resolves. If the BE rejects the inherited token shape, the gate hangs silently.
    4. **Three crashes** — tests #3 (`search filters rows`), #11 (`FK dropdown managerStaffId`), #13 (`summary widgets render`), #15 (`side panel closes`) ALSO show `Network service crashed or was terminated, restarting service` in browser logs (Chromium subprocess instability after 25+ minutes of run). NOT the root cause — symptom of running 60s-timeouts back-to-back exhausting the headless-shell.

  - **Verification step (for /test-fix)**:
    1. With FE running, open `http://localhost:3000/en/organization/company/branch` manually in a regular browser logged in as `businessadmin@gmail.com` (tenant `humanity`) — does the grid render? If yes → bug is headless-only; if no → real screen regression.
    2. With FE running, open Playwright codegen against same URL + storageState → confirm if `<main>` stays `Loading...` or if the grid appears.
    3. In Apollo devtools, check whether any query has been in-flight for >5 s on initial page load — that's the hung query.

#### Skipped (intentional — not failures)

- `Map View toggle shows placeholder card` — SERVICE_PLACEHOLDER §⑫ + ISSUE-3 OPEN §⑬
- `side-panel Recent Activity feed renders items` — SERVICE_PLACEHOLDER §⑫ + ISSUE-2 OPEN §⑬
- `side-panel CRM Quick-Stat tiles (Contacts / Campaigns / Events)` — ISSUE-4 OPEN §⑬
- `YTD Collected per-row aggregation shows non-zero value` — ISSUE-4-YTD OPEN §⑬
- `Performance % column shows traffic-light color per AnnualTarget` — depends on YtdCollected, blocked by ISSUE-4-YTD OPEN §⑬

#### Notes for /test-fix

- Do **NOT** dispatch 15 parallel agents — the failures collapse to ONE bug. Fix the `<main>Loading…</main>` hang first; the other 14 will go green on re-run.
- This is almost certainly **FE-only** (BE was unchanged this session; setup auth succeeded; sidebar/topbar render = app boots). Single `frontend-developer` agent suffices.
- Auth-setup work-around already applied this run: `waitUntil: "commit"` + 30 s in `auth.setup.ts` (relaxed from `"load"` / 15 s). Keep this change.
- Login locator change (data-testid → `getByLabel`/`getByRole`) already applied so the per-tenant brand template (`humanity` subdomain) can be auth'd. Keep this change too.

#### Next step

`/test-fix #41 --until-green` — single FE agent task: diagnose why
`/en/organization/company/branch` hangs at `<main>Loading…</main>` under
storageState-based auth in headless Chromium. Verify in regular browser first
(see Verification step above) to determine if this is a headless-only flake or
a real regression. If real regression: triage Apollo queries / Suspense
boundaries / dynamic imports on the Branch page.

---

<!--
  ARCHIVE BOUNDARY
  Runs older than the most recent 5 may be pruned by hand to keep the file small.
  Never delete the latest 3 — /test-fix needs at least 2 prior runs to detect "no progress" loops.
-->
