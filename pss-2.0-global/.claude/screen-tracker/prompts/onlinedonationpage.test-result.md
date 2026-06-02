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
screen_id: 10
screen_name: Online Donation Page
screen_type: EXTERNAL_PAGE
external_page_subtype: DONATION_PAGE
spec_file: PSS_2.0_Frontend/tests/e2e/screens/onlinedonationpage.spec.ts
last_run_date: 2026-05-25
last_run_status: INFRA_ERROR
total_runs: 1
passed_last_run: 1
failed_last_run: 5
skipped_last_run: 26
last_run_duration_seconds: 16
---

## Current State

- Status: INFRA_ERROR (E2E auth credentials not configured — see Run 1)
- The spec file is sound; the failures all trace back to a single missing prerequisite (`storageState.json` was never written because `auth.setup.ts` could not run without `E2E_USERNAME` / `E2E_PASSWORD`).
- Open failures: 0 attributable to the screen. 5 attributable to environment setup.
- Skipped (intentional): 26 — all map to a `(future)` external-page template, missing helpers, OPEN issues in §⑬, or SERVICE_PLACEHOLDERs in §⑫.

## Test Runs (newest first)

---

### Run 1 — 2026-05-25 — GENERATE + RUN — INFRA_ERROR

- Tests: 32 total | **1 passed** | **5 failed** | 26 skipped (intentional)
- Duration: 15.6 s
- Spec: `PSS_2.0_Frontend/tests/e2e/screens/onlinedonationpage.spec.ts` (288 lines) — newly generated this run (first ever test artifact for #10).
- Spec deltas from template: there is no `templates/external-page.template.ts` yet (the skill marks it `(future)`), so this spec was hand-authored as a smoke-only file:
  - 6 real surface checks (admin list mount, admin list rows-or-empty-state, editor route `?id=` no-crash, public NAV `/p/give` reachable, public IFRAME `/embed/give` reachable, `/widget.js` served as JS).
  - 26 `test.skip()` blocks each labeled with one of: pending external-page template + helpers, ISSUE-N OPEN §⑬, or SERVICE_PLACEHOLDER §⑫. Labels are stable so `/test-fix` can map them when they get unskipped.

#### Failures

All 5 failures share one root cause: the chromium project's `storageState` (`PSS_2.0_Frontend/tests/e2e/shared/.auth/storageState.json`) does not exist, so every test that uses `page.goto(relativeUrl)` errors with `Protocol error (Page.navigate): Cannot navigate to invalid URL`. The 1 passing test (`widget.js`) used `request.get(absoluteUrl)` and bypassed the context init.

- `admin surface › admin list page mounts with h1 + New Page button`
  - Expected: page renders with the "Online Donation Pages" h1 + "New Page" button visible.
  - Actual: `page.goto: Protocol error (Page.navigate): Cannot navigate to invalid URL` at the first `navigateToScreen()` call.
  - Stack: `tests/e2e/shared/nav-helpers.ts:64` (page.goto) ← `tests/e2e/screens/onlinedonationpage.spec.ts:53` (beforeEach).
  - Screenshot: `test-results/artifacts/tests-e2e-screens-onlinedo-...-h1-new-page-button/test-failed-1.png`
  - Diagnosis hint: INFRA — `auth.setup.ts` did not run because `$env:E2E_USERNAME` and `$env:E2E_PASSWORD` are unset in this PowerShell session. With no `storageState.json` written, the chromium project fails to initialize its browser context → `page.goto` rejects relative URLs.

- `admin surface › admin list either shows a row or the create-first empty state`
  - Same root cause; same hint.

- `admin surface › editor route (?id=) does not crash on missing id`
  - Same root cause; same hint.

- `public NAV surface › /p/{seeded-slug} responds (200 = seed applied; 404 = seed missing — surface for diagnosis)`
  - Same root cause; same hint.
  - Pre-test diagnostic (curl probe BEFORE running the suite): `curl http://localhost:3000/en/p/give` returned **HTTP 404**. So even once the auth infra is fixed, expect this test to surface a real screen failure pointing at one of: (a) seed `online-donation-page-sqlscripts.sql` not yet applied to the DB this dev server points at, OR (b) ISSUE-1 OPEN §⑬ (tenant resolution failed to map the request domain → `CompanyId = 3`). The test is written to throw a labeled error explaining both branches so the next Run pinpoints which.

- `public IFRAME surface › /embed/{seeded-slug} renders widget or unavailable state`
  - Same root cause; same hint. The route is CSR — even when the slug is unknown the FE returns 200 + an "unavailable" card, so once auth infra is fixed this test will likely pass regardless of seed state. The earlier curl probe (during prep) did not exercise `/en/embed/give`.

#### Passing

- `widget.js loader asset › /widget.js is served as JavaScript` — HTTP 200, content-type matches `/javascript/i`, body contains `"PeopleServe"`. Confirms the Next.js static-asset pipeline serves `/public/widget.js`. This is genuine signal that the screen's JS-widget loader artifact ships correctly.

#### Skipped (intentional — 26)

Grouped by reason. All emitted with stable test names so `/test-fix` can resolve them once the underlying blocker clears.

| Reason | Count | Examples |
|--------|------:|----------|
| Pending external-page template + helpers | 14 | editor autosave, ImplementationType switcher, Branding NAV/IFRAME swap, live preview 4 variants, validate-for-publish modal, lifecycle Publish, Status Bar aggregates, etc. |
| SERVICE_PLACEHOLDER §⑫ + OPEN ISSUE §⑬ | 7 | end-to-end donation submission (ISSUE-2 gateway), receipt email (ISSUE-3), reCAPTCHA (ISSUE-9), conversion-rate stat (ISSUE-4), multi-currency FX (ISSUE-12), image upload (ISSUE-6 carousel), IFRAME CSP frame-ancestors (ISSUE-8). |
| Pending public-route helper | 3 | CSRF/honeypot/rate-limit, Closed/Archived edge states, anonymous-render assertions. |
| Pending state-injection helper | 1 | empty/loading/error states on both surfaces. |
| Pending menu-presence helper | 1 | admin menu visibility at `SET_PUBLICPAGES > ONLINEDONATIONPAGE`. |

#### Next step

1. **(REQUIRED) Set E2E credentials in the shell that will run the next `pnpm exec playwright test` invocation**:
   ```pwsh
   $env:E2E_USERNAME = 'admin@<your-tenant>.com'
   $env:E2E_PASSWORD = '<password>'
   $env:E2E_TENANT   = '<tenant-subdomain>'   # optional; for localhost tenant override
   ```
   These are read by `tests/e2e/shared/auth.setup.ts` and produce `tests/e2e/shared/.auth/storageState.json` that every other spec depends on.

2. **(REQUIRED, before next NAV expectation can pass) Apply the seed AND verify tenant resolution**:
   - Run `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/online-donation-page-sqlscripts.sql` against the DB the dev server points at (idempotent — safe to re-run).
   - Confirm the dev-server tenant maps to `CompanyId = 3` (the seed hard-codes that). If not, either re-seed for the dev tenant's CompanyId or close ISSUE-1 first.

3. **Then rerun**:
   ```pwsh
   pnpm exec playwright test --grep "@screen-10" --reporter=list
   ```
   Expected on rerun: 6 passed / 0 failed / 26 skipped (smoke GREEN). If `/p/give` still 404s, see Run 1 diagnosis above — the test is now actionable rather than blocked.

4. **Longer-term to unskip the 26 deferred tests**: stand up `.claude/skills/test-screen/templates/external-page.template.ts` + a `tests/e2e/shared/public-route-helpers.ts` (anonymous fixture, CSP probe, embed-iframe locator, autosave-debounce wait). Reusable for any future EXTERNAL_PAGE (Event Registration, Crowdfund). See discussion in `/test-screen` invocation 2026-05-25.