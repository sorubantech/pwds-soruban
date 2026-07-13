---
name: test-batch
description: /test-batch — Run Playwright tests across many screens in a single invocation (e.g. all wave-1 screens, all NEEDS_FIX screens, all screens missing test-results). Drives one Playwright process with --grep filters so we pay browser cold-start ONCE per batch. Writes per-screen results into each screen's `{screen}.test-result.md`; prints only an aggregated dashboard to the user (no per-screen detail in chat). Sister to `/test-screen` (single-screen) and `/test-fix` (auto-fix). Does NOT auto-fix — for that, run `/test-fix --failed` after a batch finishes.
---

# /test-batch — Run Tests Across Many Screens

> The fleet runner. `/test-screen` is one screen. `/test-batch` is N screens with one Playwright
> process, one cold-start, one `results.json` parse, one aggregated summary in chat. Per-screen
> detail lands in each screen's `{screen}.test-result.md` — chat stays tight. Pairs with [[test-fix]]
> for follow-up auto-healing.

---

## When to use

| Situation | Use |
|-----------|-----|
| Verify every wave-1 screen at once | `/test-batch wave 1` |
| Re-run only the screens currently `NEEDS_FIX` | `/test-batch --failed` |
| First-time test pass on every screen that's never been tested | `/test-batch --new` |
| Full regression — every `COMPLETED` screen | `/test-batch all` |
| One specific screen | use [[test-screen]] instead |
| Auto-fix after a batch | follow up with `/test-fix --failed` (separate skill, separate run) |

---

## Input

```
/test-batch wave 1                  → Every COMPLETED screen with wave=1 in REGISTRY
/test-batch wave 1,2                → Multiple waves
/test-batch --failed                → Every screen currently NEEDS_FIX (oldest first)
/test-batch --new                   → Every COMPLETED screen with no .test-result.md file
/test-batch all                     → Every COMPLETED screen (heaviest — use sparingly)
/test-batch --tag @master-grid      → Every screen of a given type
/test-batch wave 1 --regenerate     → Force regenerate every spec before running
/test-batch wave 1 --bg             → Run in background (Claude releases turn)
/test-batch wave 1 --workers 2      → Override Playwright parallelism (default: 1 to keep DB sane)
/test-batch wave 1 --dry-run        → Print the screen list + estimated test count, run nothing
```

---

## Required Reading (load before starting)

1. `.claude/screen-tracker/REGISTRY.md` — **do NOT `Read` the whole file** (~175K tokens). `grep` only the rows the filter needs, e.g. `grep -nE "COMPLETED|NEEDS_FIX" .claude/screen-tracker/REGISTRY.md`, to resolve wave / --failed / --new filters to a list of screen IDs.
2. Each target screen's frontmatter only (NOT the full spec) — to discover `screen_type` and `MenuUrl` for spec generation.
3. `PSS_2.0_Frontend/tests/e2e/playwright.config.ts` — base config.

**Do NOT pre-read**:
- Full prompt files for each screen (60-screen batch × 600 lines = ~36k tokens wasted) — defer to per-screen authoring inside the loop.
- Each screen's `.test-result.md` — only needed by `/test-fix` follow-up, not by this skill.

---

## Execution Flow

### Step 1: Resolve the screen list

| Filter | Source | Result |
|--------|--------|--------|
| `wave N` / `wave N,M` | `REGISTRY.md` rows where wave matches AND status = `COMPLETED` or `NEEDS_FIX` | sorted list of screen IDs |
| `--failed` | `REGISTRY.md` rows where status = `NEEDS_FIX` | sorted oldest first |
| `--new` | `REGISTRY.md` rows where status = `COMPLETED` AND no `{entity}.test-result.md` exists (Glob check) | sorted by registry order |
| `all` | `REGISTRY.md` rows where status ∈ `{COMPLETED, NEEDS_FIX}` | sorted by registry order |
| `--tag @X` | Loop each candidate's frontmatter `screen_type` | filter to matching type |

Print the resolved list to user (count + first 5 IDs + last 5 IDs). If `--dry-run`, stop here.

### Step 2: Author missing specs (one pass)

For each screen in the list:

```
spec exists at tests/e2e/screens/{entity}.spec.ts ?
  no                       → invoke the same generator [[test-screen]] uses, --generate-only
  yes, --regenerate flag   → invoke generator, overwrite
  yes, no flag             → skip generation
```

Use the `test-screen` generation logic (do NOT spawn the skill — call its internal author function via the template substitution path described in [test-screen/SKILL.md § Test Templates](../test-screen/SKILL.md#test-templates--what-each-template-knows)).

**Cost note**: this is the one heavy step. Each spec generation reads §⑥ §⑨ §⑩ §⑪ §⑫ §⑬ of one prompt file. For a 50-screen batch this is ~25k input tokens. Acceptable trade-off vs. running these one-at-a-time (which would re-pay the per-skill startup cost ×50).

### Step 3: Single Playwright invocation with `--grep`

```pwsh
# Build the grep pattern: "@screen-41|@screen-42|@screen-43|..."
pnpm exec playwright test --grep "@screen-41|@screen-42|@screen-43" --reporter=list,json
```

For a wave-based batch you can use the wave tag directly:

```pwsh
pnpm exec playwright test --grep "@wave-1" --reporter=list,json
```

Why one process: browser cold-start is the dominant cost (3-8s × N screens otherwise). One process amortizes it.

Default `--workers=1` (DB-bound — most screens write to shared seed tables). Override with `--workers 2` if user passes the flag; never default to >1 because of test-data race risk.

If `--bg` was passed, use `Bash run_in_background:true` and return the task ID immediately. Print:

> Batch started in background. Task ID: {id}. You'll be paged when it completes (~{est} min).

### Step 4: Parse `results.json` ONCE

Read `test-results/results.json`. Walk every test entry; group by screen tag (`@screen-N`).

For each screen, classify outcome:
- All non-skipped pass → GREEN
- Any non-skipped fail → NEEDS_FIX
- Only skips (all `.skip()` rules fired) → SKIPPED_ONLY (rare; treat as GREEN)
- All tests errored before running → INFRA_ERROR

### Step 5: Per-screen file writes (parallel-safe, one file per screen)

For each screen in the batch, in a single loop:

1. **Prepend** new Run entry to `{entity}.test-result.md` — same schema as [[test-screen]] writes. If the file doesn't exist, create it with frontmatter.
2. **Append** one-line pointer to spec § ⑬:
   ```markdown
   - Session N — {YYYY-MM-DD} — TEST (batch) — {GREEN | NEEDS_FIX} — see [{entity}.test-result.md] — {n} failures
   ```
3. **Tick** § ⑪ Acceptance Criteria checkboxes per pass/skip/fail rules.
4. **Update** frontmatter status if needed (COMPLETED ↔ NEEDS_FIX), update `last_session_date`.

These writes are independent (per-screen files); batch as many parallel `Edit` calls as makes sense. There is no shared file to serialize on at this stage.

### Step 6: Update REGISTRY.md (single edit)

For screens whose status changed, update `REGISTRY.md` with **scripted in-place edits** (Bash `sed -i` / PowerShell), never `Read`+`Edit` (reading it loads ~175K tokens). Run one `sed` per changed row, or a single `sed -i` with multiple `-e` expressions.

### Step 7: Aggregated summary (only output to chat)

```
/test-batch wave 1 — 18 screens — 4m 32s total

│ ID │ Screen                  │ Type         │ Result    │ Failed/Total │ Skipped │
├────┼─────────────────────────┼──────────────┼───────────┼──────────────┼─────────┤
│ 41 │ Branch                  │ MASTER_GRID  │ NEEDS_FIX │ 3 / 12       │ 2       │
│ 42 │ ContactType             │ MASTER_GRID  │ GREEN     │ 0 / 8        │ 1       │
│ 43 │ Department              │ MASTER_GRID  │ GREEN     │ 0 / 8        │ 0       │
│ 44 │ DonorOnboarding         │ FLOW         │ NEEDS_FIX │ 5 / 22       │ 4       │
│ 45 │ GrantApproval           │ FLOW         │ GREEN     │ 0 / 22       │ 6       │
│ ...│                         │              │           │              │         │
├────┼─────────────────────────┼──────────────┼───────────┼──────────────┼─────────┤
│    │  AGGREGATE              │              │           │ 14 / 187     │ 23      │

GREEN: 14 screens  ·  NEEDS_FIX: 4 screens  ·  INFRA_ERROR: 0
Per-screen detail: each in .claude/screen-tracker/prompts/{screen}.test-result.md
Suggested next step: /test-fix --failed  (auto-fix the 4 NEEDS_FIX screens, Sonnet, --until-green)
```

**Do NOT** print per-screen failure detail in chat — that's what the per-screen test-result files are for. Keep the chat output a single screen of text.

---

## Background runs (`--bg`)

When `--bg` is set:

1. Step 1 + Step 2 (author specs) run foreground — they're cheap.
2. Step 3 (Playwright) launches with `Bash run_in_background:true`.
3. Skill returns the bg-task ID + estimated duration and exits.
4. Steps 4-7 run when Claude is paged on bg completion — same logic, same outputs.

If the user invokes the skill again during the bg run, refuse with:
> "A batch is already running in the background (task ID: {id}). Use `Monitor` / `TaskOutput` to check, or wait for it to complete."

---

## What this skill does NOT do

| Out of scope | Use instead |
|---|---|
| Auto-fix any failures | `/test-fix --failed` (separate run, separate budget) |
| Re-run one screen | [[test-screen]] |
| Generate new test categories | [[test-screen]] templates |
| Print per-screen detail in chat | Read the per-screen `.test-result.md` files (linked in summary) |
| Touch `BaseUrlConfig.ts` | User-managed (auto-memory `feedback_baseurl_user_managed`) |
| Auto-start the dev server | Manual — curl probe before launch, refuse if down |
| Run mobile / `SKIP_*` screens | Filtered out at Step 1 |

---

## Parallel-session safety

1. **Don't run two batches simultaneously** — shared `results.json` output collides. Skill checks for an in-flight bg-task before starting.
2. **Don't run a batch and a `/test-screen` simultaneously** — same reason. Skill refuses if another `playwright test` process is detected (probe via `tasklist | findstr playwright`).
3. **Per-screen file writes are independent** — within one batch's post-processing, parallel writes are safe.

---

## Failure modes & recovery

| Symptom | Handling |
|---------|----------|
| Dev server not responding (curl probe fails) | Stop. Ask user to run `pnpm dev` in `PSS_2.0_Frontend/`. |
| `tests/e2e/screens/` missing for some screens in the batch | Step 2 generates them — no abort. |
| Playwright crashes mid-batch | Read partial `results.json`; mark un-tested screens as `INFRA_ERROR`; surface to user with retry suggestion. |
| `results.json` malformed | Stop. Surface raw stderr to user. Do NOT silently mark screens. |
| Sibling worktree drift (specs written to `pwds-soruban/` not `pwds-soruban - Copy/`) | After Step 2, Glob both paths; if drift detected, abort before Step 3 (per auto-memory `feedback_agent_sibling_worktree_drift`). |
| User Ctrl-C's during foreground run | Playwright exits; results.json may be partial. Skill detects, marks completed screens, leaves rest unchanged. |

---

## Relationship to other skills

See [test-screen/SKILL.md § Relationship to other skills](../test-screen/SKILL.md#relationship-to-other-skills) for the full pipeline diagram.

Typical fleet workflow:

```
/test-batch --new          → first-time pass on every untested screen
                             ↓
/test-batch --failed       → re-run anything that flagged red (optional sanity)
                             ↓
/test-fix --failed         → auto-fix every NEEDS_FIX with --until-green per screen
                             ↓
/test-batch --failed       → verify the fixer didn't regress anything
```

---

## Why this exists

Running `/test-screen` 60 times pays browser cold-start 60 times (3-8s × 60 = 3-8 minutes wasted) AND posts 60 long summaries to chat (~6k tokens of redundant output the user will skim once). `/test-batch` pays cold-start once, parses `results.json` once, and gives one summary table — the per-screen detail goes to disk where `/test-fix` can pick it up cheaply.
