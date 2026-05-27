<!--
  TEMPLATE — copy of this file lives next to each spec at:
    .claude/screen-tracker/prompts/{entity-lower}.test-result.md

  Written by:  /test-screen  (initial run + reruns + regenerate-runs)
  Updated by:  /test-fix     (FIX-cycle runs, --until-green sub-runs)
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
last_run_date: 2026-05-21
last_run_status: NEEDS_FIX            # GREEN | NEEDS_FIX | MIXED | INFRA_ERROR
total_runs: 3
passed_last_run: 7
failed_last_run: 3
skipped_last_run: 2
last_run_duration_seconds: 84
---

## Current State

- Status: **NEEDS_FIX**
- Open failures: 3 (see Run 3 below)
- Suggested next step: `/test-fix #41 --until-green`

## Test Runs (newest first)

---

### Run 3 — 2026-05-21 14:32 — RERUN — NEEDS_FIX

- Tests: 12 total | 7 passed | 3 failed | 2 skipped
- Duration: 1m 24s
- Trigger: `/test-screen #41 --rerun` (manual)
- Spec: `PSS_2.0_Frontend/tests/e2e/screens/branch.spec.ts` (240 lines, unchanged from Run 2)
- Spec deltas from template: None

#### Failures

- `add new branch — happy path`
  - **Expected**: success toast "Branch created"
  - **Actual**: validation error "BranchCode required"
  - **Stack**: `tests/e2e/screens/branch.spec.ts:45:12`
  - **Screenshot**: `test-results/artifacts/branch-add-happy/screenshot.png`
  - **Trace**: `test-results/artifacts/branch-add-happy/trace.zip`
  - **Diagnosis hint**: form schema mismatch — Spec §⑥ has BranchCode as auto-generated; FE form treats it as required (FE issue, branchFormSchema.ts)

- `toggle Active → badge changes`
  - **Expected**: badge text "Inactive"
  - **Actual**: badge text still "Active"
  - **Stack**: `tests/e2e/screens/branch.spec.ts:118:8`
  - **Screenshot**: `test-results/artifacts/branch-toggle-active/screenshot.png`
  - **Diagnosis hint**: toggle mutation succeeds (network 200) but grid refresh missing — FE issue, branch/page.tsx, missing `refetch()` after toggle handler

- `delete row → confirm → row removed`
  - **Expected**: row count decreases by 1
  - **Actual**: confirm dialog never opens
  - **Stack**: `tests/e2e/screens/branch.spec.ts:155:6`
  - **Screenshot**: `test-results/artifacts/branch-delete-row/screenshot.png`
  - **Diagnosis hint**: row-action-delete data-testid present, click event not propagating — FE issue, AdvancedDataTable row action wiring OR row dropdown z-index hiding the option

#### Skipped (intentional — not failures)

- `staff count column shows value` — `ISSUE-2 OPEN §⑬ — Staff.BranchId service missing`
- `recent activity widget loads` — `ISSUE-3 OPEN §⑬ — activity-stream service not yet wired`

#### Next step

Run `/test-fix #41 --until-green`. All 3 failures are FE-only — single `frontend-developer` agent dispatch should resolve them.

---

### Run 2 — 2026-05-21 11:08 — RERUN — NEEDS_FIX

- Tests: 12 total | 6 passed | 4 failed | 2 skipped
- Duration: 1m 31s
- Trigger: `/test-screen #41 --rerun` (after manual fix attempt)
- Spec: unchanged from Run 1
- Spec deltas from template: None

#### Failures

- (same 3 as Run 3, plus:)
- `search filters rows` — was a flake; passes in Run 3. **TEST** issue not code — adjusted selector wait in spec.ts:38.

#### Skipped (intentional)

- (same 2 as Run 3)

#### Next step

Re-run after spec selector tweak.

---

### Run 1 — 2026-05-21 10:14 — GENERATE+RUN — NEEDS_FIX

- Tests: 12 total | 5 passed | 5 failed | 2 skipped
- Duration: 1m 47s
- Trigger: `/test-screen #41` (first ever run for this screen)
- Spec: `PSS_2.0_Frontend/tests/e2e/screens/branch.spec.ts` (240 lines, fresh from `master-grid.template.ts`)
- Spec deltas from template: added performance-bar column color assertion (custom renderer in §⑥)

#### Failures

- (initial 5 failures — 2 turned out to be flaky selectors fixed by Run 2 spec tweak; 3 are real and persist into Run 3)

#### Skipped (intentional)

- (same 2 as Run 3 — recognized from §⑬ Build Log on first read)

#### Next step

Investigate the 5 failures; 2 look like selector flakes worth a spec rerun first.

---

<!--
  ARCHIVE BOUNDARY
  Runs older than the most recent 5 may be pruned by hand to keep the file small.
  Never delete the latest 3 — /test-fix needs at least 2 prior runs to detect "no progress" loops.
-->
