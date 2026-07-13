---
name: test-screen
description: /test-screen — Generate, run, and report Playwright E2E tests for a COMPLETED screen. Reads the screen's prompt file (§⑥ UI Blueprint + §⑪ Acceptance Criteria + §⑫ Service Placeholders) and either authors a fresh spec or runs an existing one. Honors known issues from §⑬ Build Log (won't fail on intentional placeholders). Writes results to a sibling file `{screen}.test-result.md`; appends only a one-line pointer to §⑬ of the spec.
---

# /test-screen — Automated E2E Test Runner (Playwright)

> The verification skill. A screen is `COMPLETED` per its Build Log, but § ⑪ Acceptance
> Criteria checkboxes are unchecked. This skill translates § ⑥ UI Blueprint + § ⑪ Acceptance
> Criteria + § ⑫ Special Notes + § ⑬ Build Log Known Issues into a Playwright spec, runs it,
> writes the full result into a **sibling file** `{screen}.test-result.md`, and posts a
> **one-line pointer** into § ⑬ of the spec.
>
> Companion skills: `/test-fix` (auto-fix failures via BE/FE agents) · `/test-batch` (run a wave).
> See [WORKING_FLOW.md](WORKING_FLOW.md) for the management-presentable end-to-end overview.

---

## When to use

| Situation | Use |
|-----------|-----|
| Screen is `COMPLETED` but has no test results yet | `/test-screen` |
| Screen is `NEEDS_FIX` — verify the fix didn't regress CRUD | `/test-screen #41 --rerun` |
| Tests exist, just re-run them (no code regen) | `/test-screen #41 --rerun` |
| Spec changed and the existing test file is stale | `/test-screen #41 --regenerate` |
| Author the spec but don't execute | `/test-screen #41 --generate-only` |
| Bulk verification — every wave-1 screen | use `/test-batch wave 1` instead |
| Screen is `PROMPT_READY` / `IN_PROGRESS` | refuse — must build first |
| Screen is `SKIP_*` | refuse — out of pipeline |

For groups of screens, use [[test-batch]]. For fixing failures, use [[test-fix]].

---

## Input

```
/test-screen                  → Pick next COMPLETED screen with no test-result file (or stalest)
/test-screen #41              → Specific screen by registry number
/test-screen "Branch"         → Specific screen by name
/test-screen --rerun          → Re-run existing spec without regenerating it
/test-screen --rerun #41      → Re-run a specific screen's spec
/test-screen --regenerate #41 → Force a fresh spec, overwriting tests/e2e/screens/branch.spec.ts
/test-screen --generate-only  → Emit the spec file but don't execute it
/test-screen --bg #41         → Run Playwright in background (Claude releases the turn; user keeps chatting)
/test-screen --failed         → Pick the oldest screen currently NEEDS_FIX (one-screen variant of /test-batch --failed)
/test-screen --new            → Pick the oldest COMPLETED screen with no `{screen}.test-result.md` file
```

**Flag semantics**
- `--rerun` and `--regenerate` are mutually exclusive (rerun keeps spec as-is; regenerate overwrites it).
- `--bg` returns immediately and prints the bg-task ID. Claude is paged on completion.
- `--failed` / `--new` are selectors only — they pick the screen, then run the default flow.

---

## Required Reading (load before starting)

- `.claude/screen-tracker/REGISTRY.md` — resolve registry ID → entity + status
- The target prompt file at `.claude/screen-tracker/prompts/{entity-lower}.md`
- The sibling result file if it exists: `.claude/screen-tracker/prompts/{entity-lower}.test-result.md`
- `.claude/skills/test-screen/templates/{screen_type}.template.ts` — pattern template
- `PSS_2.0_Frontend/tests/e2e/playwright.config.ts` — base Playwright config

**Do NOT pre-read** unless they appear relevant during execution:
- Backend code — tests assert behavior, not implementation
- Other screens' specs (only read the sibling whose template you're reusing)
- The spec's §②-§⑤ §⑧-§⑩ unless a failure trace points there (saves tokens — see [WORKING_FLOW.md](WORKING_FLOW.md) §6)

---

## Execution Flow

### Step 1: Locate the target screen

1. **Never `Read` the whole `REGISTRY.md`** (~175K tokens) — `grep` the single row: `grep -nE "^\| *#?<id> " .claude/screen-tracker/REGISTRY.md` (by ID) or `grep -niE "<name>" .claude/screen-tracker/REGISTRY.md`.
2. Verify `status ∈ {COMPLETED, NEEDS_FIX}`. Otherwise refuse with:
   > "Screen #N is `{status}`. Run `/build-screen #N` first."
3. Read the prompt file frontmatter — extract `screen_type` (`MASTER_GRID` / `FLOW` / `CONFIG` / `DASHBOARD` / `EXTERNAL_PAGE` / `AUTH`).
4. Resolve route from § ⑨ Approval Config (`MenuUrl`) — this is the URL Playwright will navigate to.

### Step 2: Rehydrate test-relevant context

Read these sections from the prompt file (do NOT load others — keep context tight):

| Section | What you extract |
|---------|-----------------|
| Frontmatter | `screen_type`, `scope`, `status`, route base |
| § ⑥ UI/UX Blueprint | Grid columns (field keys + display types), Form sections + fields + widgets + validation, FK lookups for ApiSelect, Side panel triggers, View modes (FLOW only) |
| § ⑨ Approval Config | `ModuleCode` (parent module SHOUT_CASE — REQUIRED, see Navigation note), `MenuUrl`, `GridCode`, `MenuCapabilities` (drives role-based test variants) |
| § ⑩ BE→FE Contract | DTO field names + types (used to generate test payloads) |
| § ⑪ Acceptance Criteria | The literal test checklist — every unchecked `- [ ]` becomes one Playwright `test('...')` |
| § ⑫ Special Notes & Warnings | **SERVICE_PLACEHOLDER** entries → mark those tests `.skip()` with a clear reason |
| § ⑬ Build Log Known Issues | Every `OPEN` row → mark the corresponding test `.skip()` with `// SKIPPED — ISSUE-N OPEN` |

> **Navigation constraint (architectural — easy to miss):**
> Tests MUST visit the module's **Dashboard Overview** page first so the app
> hydrates menus + role capabilities into client state, and **then** navigate
> to the screen's menu URL. Direct navigation to the menu URL yields an empty
> menu/capability state → `GridCode` lookup fails, +Add button is hidden, the
> data-table renders blank.
>
> Canonical module landing URL pattern: `/{lang}/{moduleCode-lowercase}/dashboards/overview`
>
> | Module | ModuleCode | Module landing URL |
> |---|---|---|
> | Setting | `SETTING` | `/en/setting/dashboards/overview` |
> | Report & Audit | `REPORTAUDIT` | `/en/reportaudit/dashboards/overview` |
> | Access Control | `ACCESSCONTROL` | `/en/accesscontrol/dashboards/overview` |
> | Organization | `ORGANIZATION` | `/en/organization/dashboards/overview` |
> | CRM | `CRM` | `/en/crm/dashboards/overview` |
> | General | `GENERAL` | `/en/general/dashboards/overview` |
>
> Every generated spec must use `navigateToScreen(page, moduleCode, menuUrl)` from
> `tests/e2e/shared/nav-helpers.ts` in its `beforeEach` — never raw `page.goto(menuUrl)`.
> The helper expands `moduleCode` → `/{lower}/dashboards/overview` internally.
>
> `ModuleCode` comes from § ⑨ Approval Config. If § ⑨ doesn't expose it explicitly,
> the first path segment of `MenuUrl` SHOUT_CASE'd is the fallback (e.g.,
> `MenuUrl = "organization/branch"` → `ModuleCode = "ORGANIZATION"`). When in
> doubt, ask the user — guessing wrong here breaks every test silently.

Also read the sibling `{entity-lower}.test-result.md` if it exists — only the **most recent Run entry** (the file is newest-first), to see what last failed.

### Step 3: Decide test action

```
spec exists?   --regenerate?   --rerun?   →  action
─────────────  ──────────────  ─────────     ──────
no             —               —             GENERATE + RUN
yes            no              no            ASK user: rerun / regenerate / abort
yes            no              yes           RUN ONLY
yes            yes             —             OVERWRITE spec + RUN
```

Spec lives at `PSS_2.0_Frontend/tests/e2e/screens/{entity-lower}.spec.ts`.

### Step 4: Generate the spec (when needed)

Pick the template that matches `screen_type`:

| screen_type | Template | What it covers |
|---|---|---|
| `MASTER_GRID` | `templates/master-grid.template.ts` | Grid load, search, filter, +Add modal, Edit, Toggle, Delete, FK dropdowns, validation, side panel (if blueprint has one), summary widgets (if blueprint has them) |
| `FLOW` | `templates/flow.template.ts` *(future)* | Grid load, `?mode=new` full-page form, sections expand/collapse, child grids add/remove, save → grid refresh, row click → `?mode=read&id=N` detail layout, Edit button → `?mode=edit&id=N` |
| `CONFIG` | `templates/config.template.ts` *(future)* | Tab navigation between sub-screens; per-tab CRUD as Master-Grid-lite |
| `DASHBOARD` | `templates/dashboard.template.ts` *(future)* | Widget grid loads, filter bar applies, every widget resolves data (not "no data" stub), responsive breakpoints (xs/sm/md/lg) all have layout entries |
| `EXTERNAL_PAGE` | `templates/external-page.template.ts` *(future)* | Anonymous access (no login), SSR by subdomain, branded by OrgSettings, form submission round-trip |
| `AUTH` | `templates/auth.template.ts` *(future)* | Login form, MFA, forgot-password, branding loads per subdomain |

For each template, the generator performs **substitution from § ⑦** (canonical → this entity) on:
- Route base (`MenuUrl`)
- `GridCode` (data-testid hooks the data-table already exposes)
- Field keys (form `name=` selectors)
- FK queryKeys (ApiSelect dropdown options)

**Test data convention** (built into every template):
- Code/name prefix `_TEST_{run-id}_` so seeded production-style data is never overwritten
- `afterAll` hook hard-deletes all `_TEST_{run-id}_` rows via the existing Delete mutation (not direct DB)
- Auth: reuse `storageState` from `tests/e2e/shared/auth.setup.ts` — one login per worker, not per test

**Tagging convention** (required — drives `--grep` filtering for batch runs):

```ts
test.describe('Screen #{N} — {EntityName}', { tag: ['@screen-{N}', '@wave-{W}', '@{screen_type_lower}'] }, () => { … });
```

Emit the spec to `PSS_2.0_Frontend/tests/e2e/screens/{entity-lower}.spec.ts`.

### Step 5: Run the spec

```pwsh
# Foreground (default — Claude waits)
pnpm exec playwright test --grep "@screen-{N}" --reporter=list,json

# Background (--bg flag — Claude returns the turn)
# Tool: Bash run_in_background:true
pnpm exec playwright test --grep "@screen-{N}" --reporter=json
```

Output destinations (set in `playwright.config.ts`):
- `test-results/results.json` — machine-readable, parsed by Claude
- `playwright-report/` — HTML report for humans
- `test-results/artifacts/` — screenshots / videos / traces per failed test

If `--generate-only`, skip this step entirely.

### Step 6: Classify the result

| Outcome | Meaning | Status update |
|---|---|---|
| All non-skipped tests pass | Screen verified | Prompt § ⑪ checkboxes → all ticked. Registry status stays `COMPLETED` |
| Skipped tests = only SERVICE_PLACEHOLDER / OPEN issues | Expected | Same as above; report skip count in summary |
| Any genuine FAIL | Regression or unfinished work | Spec frontmatter `status` → `NEEDS_FIX`. Don't open a §⑬ Known Issue row from this skill — `/test-fix` is responsible for that |
| Test infra error (browser crash, network) | Not a screen bug | Don't change status; report and ask whether to retry |

### Step 7: Write the test-result file

The result lives in `.claude/screen-tracker/prompts/{entity-lower}.test-result.md` — a **sibling** to the spec, not part of it. Newest run first.

If the file doesn't exist, create it with frontmatter. If it exists, **prepend** the new run entry above the existing ones (keep the file newest-first so `/test-fix` can read just the first ~80 lines).

Schema (full template lives at `.claude/skills/test-screen/test-result.template.md`):

```markdown
---
screen_id: {N}
screen_name: {EntityName}
last_run_date: {YYYY-MM-DD}
last_run_status: {GREEN | NEEDS_FIX | MIXED | INFRA_ERROR}
total_runs: {N}
passed_last_run: {n}
failed_last_run: {n}
skipped_last_run: {n}
---

## Current State
- Status: {GREEN | NEEDS_FIX}
- Open failures: {count} (see Run {N})

## Test Runs (newest first)

### Run {N} — {YYYY-MM-DD HH:MM} — {GENERATE+RUN | RERUN | REGENERATE+RUN} — {GREEN | NEEDS_FIX | MIXED}
- Tests: {total} total | {pass} passed | {fail} failed | {skip} skipped
- Duration: {Xm Ys}
- Spec: `PSS_2.0_Frontend/tests/e2e/screens/{entity-lower}.spec.ts` ({lines} lines)
- Spec deltas from template: {e.g. "added performance-bar color assertion" or "None"}

#### Failures
- `{test name}`
  - Expected: {expected}
  - Actual: {actual}
  - Stack: {file:line}
  - Screenshot: `test-results/artifacts/.../screenshot.png`
  - Trace: `test-results/artifacts/.../trace.zip`
  - Diagnosis hint: {1-line; references spec section if applicable, e.g. "form schema mismatch — Spec § ⑥ has BranchCode auto-generated, FE treats it as required"}

#### Skipped (intentional)
- `{test name}` — {SERVICE_PLACEHOLDER §⑫ | ISSUE-N OPEN §⑬}

#### Next step
{empty if GREEN; else: "Run `/test-fix #N` to dispatch BE/FE agents on these failures"}
```

### Step 8: Append one-line pointer to § ⑬ of the spec

Append (do **not** modify prior entries) to the `§ Sessions` table at the bottom of § ⑬:

```markdown
- Session {N} — {YYYY-MM-DD} — TEST — {GREEN | NEEDS_FIX} — see [{entity-lower}.test-result.md] — {n} failures
```

**Do NOT** write a multi-line `### Session N — TEST` block into the spec. The full detail lives in the sibling test-result file. This keeps the spec from bloating across many test cycles (see [WORKING_FLOW.md](WORKING_FLOW.md) §3 — file split rationale).

### Step 9: Update prompt file Acceptance Criteria checkboxes

For every passing test that maps to a § ⑪ `- [ ]` line, change to `- [x]`. For SKIPPED ones, change to `- [~]` and add a parenthetical: `(SKIPPED — ISSUE-N / SERVICE_PLACEHOLDER)`. For FAILED, leave unchecked and add `(FAILED — see Run N in test-result.md)`.

### Step 10: Update spec frontmatter status

| Result | Frontmatter status |
|--------|-------------------|
| GREEN | unchanged (stays `COMPLETED`) |
| NEEDS_FIX | `COMPLETED` → `NEEDS_FIX` |
| MIXED (some skipped due to OPEN issues but no NEW failures) | unchanged (the OPEN issues already drive that status) |
| INFRA_ERROR | unchanged; surface to user |

Also update `last_session_date: {today}` in frontmatter.

### Step 11: Summarize to the user (≤ 10 lines)

```
Screen #41 Branch (MASTER_GRID) — Run 3 — NEEDS_FIX
✗ 3 failed · ✓ 7 passed · ⊘ 2 skipped (12 total · 1m 24s)
Failures:
  • add new branch — happy path        (form schema mismatch)
  • toggle Active                       (badge text)
  • delete row → confirm               (modal not opening)
Skipped (intentional):
  • Map View (SERVICE_PLACEHOLDER)
  • Recent Activity (ISSUE-2 OPEN)
Full report: .claude/screen-tracker/prompts/branch.test-result.md (Run 3)
Next: /test-fix #41 --until-green
```

If GREEN, drop the failure lines and end with `Next: pick another screen with /test-screen --new`.

---

## Test Templates — what each template knows

Templates live in `.claude/skills/test-screen/templates/` and are TypeScript files that
import shared helpers from `PSS_2.0_Frontend/tests/e2e/shared/`. They are NOT pre-generated
specs — they're parameterized factories that the skill substitutes per screen.

**Shared helpers** (`PSS_2.0_Frontend/tests/e2e/shared/`):
- `auth.setup.ts` — logs in once, saves `storageState.json` per role
- `fixtures.ts` — `test.extend()` with a `gridPage` fixture (waits for grid hydration)
- `grid-helpers.ts` — `searchGrid`, `clickRowAction`, `expectRowExists`, `expectColumnValue`
- `form-helpers.ts` — `fillRjsfForm`, `submitForm`, `expectValidationError`
- `test-data.ts` — `uniqueCode()`, `cleanupTestRows()`, `seedFK()`

**Template anatomy** (master-grid example, abbreviated):

```ts
// templates/master-grid.template.ts (illustrative shape — actual template uses substitution markers)
import { test, expect } from '../shared/fixtures';
import { fillRjsfForm, submitForm } from '../shared/form-helpers';
import { uniqueCode, cleanupTestRows } from '../shared/test-data';

test.describe('Screen #{{N}} — {{EntityName}}', { tag: ['@screen-{{N}}', '@wave-{{W}}', '@master-grid'] }, () => {
  const route = `/{lang}/{{MenuUrl}}`;
  const testCode = uniqueCode('{{ENTITYUPPER}}');

  test.afterAll(async () => cleanupTestRows('{{ENTITYUPPER}}', testCode));

  test('grid loads with seeded rows', async ({ page, gridPage }) => {
    await page.goto(route);
    await expect(gridPage.toolbar.addButton).toBeVisible();
    await expect(gridPage.rows.first()).toBeVisible();
  });

  test('search filters rows', async ({ page, gridPage }) => { /* ... */ });
  test('+Add → modal → fill → save → row appears', async ({ page, gridPage }) => { /* ... */ });
  test('Edit → modal pre-filled → change → save', async ({ page, gridPage }) => { /* ... */ });
  test('Toggle Active → badge changes', async ({ page, gridPage }) => { /* ... */ });
  test('Delete → confirm → row removed', async ({ page, gridPage }) => { /* ... */ });
  test('FK dropdowns populate', async ({ page }) => { /* ... */ });
  test('required-field validation fires', async ({ page }) => { /* ... */ });

  // Conditional blocks the skill emits based on §⑥:
  //   if has summary widgets   → test('widgets show non-zero values')
  //   if has side panel        → test('row click → side panel opens')
  //   if has aggregation cols  → test('aggregation column shows computed value')
  //   if has SERVICE_PLACEHOLDER button → test.skip('...')
});
```

The skill's job is to (a) pick the template, (b) substitute `{{...}}` tokens from prompt sections, (c) emit conditional blocks based on which § ⑥ features the screen actually has.

---

## What this skill does NOT do

| Out of scope | Use instead |
|---|---|
| Auto-fix failures | [[test-fix]] |
| Run a wave of screens | [[test-batch]] |
| Backend unit tests (CQRS handlers, validators) | dotnet `xUnit` suite (not yet wired) |
| GraphQL contract tests (DTO shape, query field set) | A future API-only `/test-api` skill |
| Performance / load | k6, separate from this pipeline |
| Visual regression for every pixel | Optional flag `--snapshot` (uses Playwright's built-in) |
| Cross-screen workflows (e.g., create Grant → approve → notify) | Manual scenario specs in `tests/e2e/scenarios/` (out of `/test-screen` scope) |
| Mobile app screens | `SKIP_MOBILE` — separate pipeline |
| Starting / killing the FE dev server | Manual — user manages `BaseUrlConfig.ts` and `pnpm dev` |

---

## Parallel-session safety

1. **Per-screen specs are independent** — `tests/e2e/screens/branch.spec.ts` ≠ `tests/e2e/screens/contact-type.spec.ts`. Two `/test-screen` invocations on different screens never collide.
2. **Test data is run-id-prefixed** — `_TEST_{ts}_{random}` makes parallel runs on the same screen safe too.
3. **Shared helpers are read-only** during a run — they're authored by the skill only when first set up.
4. **Auth storageState is per-worker** — Playwright handles isolation; the setup script logs in once per role per worker.
5. **Test-result files are per-screen** — two parallel runs on two different screens never touch the same `.test-result.md`.

---

## Failure modes & recovery

| Symptom | Handling |
|---------|----------|
| Prompt file has no § ⑥ (legacy screen) | Refuse and ask to update the prompt — can't generate tests without UI blueprint |
| Spec generates but `pnpm exec playwright test` errors with "browser not installed" | Surface install command (`pnpm exec playwright install chromium`); do NOT auto-install — user permission |
| FE dev server not responding (curl probe fails) | Stop. Ask user to run `pnpm dev` in `PSS_2.0_Frontend/`. Do NOT auto-start (per auto-memory `feedback_baseurl_user_managed`) |
| BASE_URL mismatch in `BaseUrlConfig.ts` | Surface the mismatch to user — DO NOT auto-edit (see `feedback_baseurl_user_managed`) |
| Auth setup fails (login form changed) | Stop the run, ask the user to re-record `auth.setup.ts`. Don't try to "fix" login flow blindly |
| Test data cleanup fails | Log loudly in the test-result file Run entry; don't silently leak rows. Provide cleanup SQL as a fallback |
| `tests/e2e/` doesn't exist yet (first ever run) | Scaffold: `playwright.config.ts`, `shared/`, `screens/`. One-time setup — ask user to confirm before scaffolding |
| Background run (`--bg`) never returns | After a hard 10-minute fallback, surface the bg-task ID to user with `Monitor` / `TaskOutput` instructions; do not auto-kill |

---

## Relationship to other skills

```
  /plan-screens   /build-screen     /continue-screen     /test-screen      /test-fix          /test-batch
  ─────────────   ─────────────     ────────────────     ─────────────     ─────────          ───────────
  THE BRAIN       THE EXECUTOR      THE FIXER            THE VERIFIER      THE AUTO-FIXER     THE FLEET RUNNER
                                                                            
  Writes:         Writes:           Appends:             Writes:           Writes:            Aggregates:
  prompt file     § ⑬ Sessions      § ⑬ Sessions         {x}.test-result   {x}.test-result    per-screen results
  (§①-§⑫)        frontmatter:      frontmatter:         + one-line §⑬     + one-line §⑬      summary only
                  PROMPT_READY →    COMPLETED →          pointer            pointer
                  COMPLETED         NEEDS_FIX →                              dispatches
                                    COMPLETED            Ticks §⑪          BE / FE agents
                                                         checkboxes         May loop back to
                                                                            /test-screen
                                                                            (--until-green,
                                                                            max 3 cycles)
```

`/test-screen` is the **only skill that ticks § ⑪ Acceptance Criteria** — they're auto-ticked only by passing tests, never by humans. `/test-fix` reads `{x}.test-result.md` (not the full spec) to minimise re-read cost (see [WORKING_FLOW.md](WORKING_FLOW.md) §6).

---

## Why this exists

Section ⑪ Acceptance Criteria is already a literal test checklist — it was just being checked
manually (or not at all). Section ⑥ UI Blueprint already specifies every column, field, widget,
FK, and interaction. Section ⑫ already calls out what's an intentional placeholder. The
information needed to generate Playwright specs has been sitting in the prompt files since day
one. `/test-screen` is the translator. Same source-of-truth that built the screen now verifies it.
