---
name: test-fix
description: /test-fix — Auto-fix failing Playwright tests for a screen. Reads ONLY the latest Run entry of `{screen}.test-result.md` (newest-first file, ~80 lines, not the full spec) plus targeted spec sections referenced by the failures' diagnosis hints. Dispatches backend-developer / frontend-developer agents (Sonnet by default — user is cost-conscious). With `--until-green`, re-invokes `/test-screen` after each fix, capped at 3 cycles. Refuses if the fix requires a spec change (sends user to `/plan-screens`). Use AFTER `/test-screen` has produced a `NEEDS_FIX` result.
---

# /test-fix — Auto-Fix Failing Tests (BE/FE Agent Dispatch)

> The auto-fixer. Pairs with [[test-screen]] (the verifier). Reads the most recent test
> Run entry from `{screen}.test-result.md`, classifies each failure as BE / FE / cross-cutting,
> dispatches the matching specialized agent with **only the failure context + the spec section
> the failure points at** (not the full 600-line spec — see [WORKING_FLOW.md](../test-screen/WORKING_FLOW.md) §6).
> With `--until-green`, loops back to `/test-screen` after the fix; max 3 cycles, then escalates.

---

## When to use

| Situation | Use |
|-----------|-----|
| `/test-screen` returned `NEEDS_FIX` with real (non-skipped) failures | `/test-fix #N` |
| Want one-shot auto-loop until tests pass (or 3 cycles burn out) | `/test-fix #N --until-green` |
| Failures are all skipped (SERVICE_PLACEHOLDER / OPEN issues) | nothing to fix — leave it; use `/continue-screen` if you want to close the OPEN issues |
| Spec needs to change to make the fix possible (new field, new FK, new mode) | **refuse** — send user to `/plan-screens #N` |
| Screen has never been tested (no `.test-result.md` file) | run `/test-screen #N` first |

---

## Input

```
/test-fix #41                       → Read latest Run from branch.test-result.md, fix, stop
/test-fix #41 --until-green         → Fix → re-run /test-screen → repeat until GREEN or 3 cycles
/test-fix #41 --dry-run             → Print the agent dispatch plan but spawn nothing
/test-fix --failed                  → Pick the oldest screen currently NEEDS_FIX
```

`--until-green` is the most common variant. Without it, the skill exits after the fix, and the user must run `/test-screen #N` themselves to verify.

**Model policy (non-overridable):** All agents this skill spawns run on **Sonnet**. There is no Opus escalation flag — the testing pipeline is hardcoded to Sonnet for cost control (see auto-memory `feedback_test_pipeline_sonnet_only`). If a failure genuinely needs deeper reasoning than Sonnet can deliver, escalate it to a human, not to Opus.

---

## Required Reading (load before starting)

1. `.claude/screen-tracker/REGISTRY.md` — resolve registry ID → entity + status.
2. `.claude/screen-tracker/prompts/{entity-lower}.test-result.md` — **ONLY the first Run entry** (the file is newest-first; the latest run is at the top, typically ~50-80 lines).
3. The prompt file `.claude/screen-tracker/prompts/{entity-lower}.md` — read **only** the sections referenced by failure diagnosis hints (e.g., if a failure says "form schema mismatch — Spec §⑥", read §⑥ only; do not load §②-§⑤ §⑧-§⑩ unless a failure points there).
4. `PSS_2.0_Frontend/tests/e2e/screens/{entity-lower}.spec.ts` — to confirm the assertion that failed (so the agent fix targets the right behavior, not a misread of the test).

**Do NOT pre-read**:
- The full prompt file — wastes tokens that fix agents will then re-pay (the user is cost-conscious — see auto-memory `feedback_prefer_sonnet_over_opus`).
- Older Run entries in the test-result file — only the latest matters; older are historical.
- Backend / Frontend code unless a failure points at a specific file.

---

## Execution Flow

### Step 1: Locate the screen + verify state

1. **Never `Read` the whole `REGISTRY.md`** (~175K tokens) — `grep` the single row: `grep -nE "^\| *#?<id> " .claude/screen-tracker/REGISTRY.md`. Resolve `#N` → entity and verify status is `NEEDS_FIX` (the expected starting point after `/test-screen`).
2. If status is `COMPLETED` and the user is invoking `/test-fix` anyway → ask "Tests are already green. Did you mean `/continue-screen #N` for a human-reported issue?" and abort unless user overrides.
3. If no `{entity-lower}.test-result.md` exists → "No test run yet. Run `/test-screen #N` first." Abort.

### Step 2: Read the latest Run entry

Read `{entity-lower}.test-result.md` with `limit: 80` (the newest run is at the top, full failures + diagnosis hints fit). Extract:

- Run number, timestamp, status
- Each failure: name, expected/actual, stack, screenshot/trace path, diagnosis hint
- Skipped tests (so the fixer does NOT try to "fix" intentional skips)
- Pass count (for context, not action)

### Step 3: Classify each failure

For each non-skipped failure, classify into one of:

| Class | Signal | Agent |
|-------|--------|-------|
| `BE` | Diagnosis hint mentions DTO / GraphQL / EF / CQRS / validator / migration / seed | `backend-developer` |
| `FE` | Diagnosis hint mentions form schema / page component / route / Apollo / Server Component | `frontend-developer` |
| `CROSS` | Failure spans both (e.g., FE sends field X, BE rejects it) | run `backend-developer` first, then `frontend-developer` (BE-first per [[continue-screen]] convention) |
| `TEST` | Diagnosis hint flags a flaky selector, race condition, or wrong assertion | edit the spec file directly, no agent — record as a `TEST` fix in the result entry |
| `INFRA` | Browser crash / network 5xx / dev-server-not-up | refuse to dispatch; surface to user |

Build the dispatch plan as a flat list. Show it to user before spawning (unless `--until-green` — that auto-confirms).

### Step 4: Read targeted spec context per failure

For each failure, read **only** the section the diagnosis hint points at:

```
diagnosis hint mentions § ⑥ → Read prompt file with section-targeted offset for § ⑥ only
diagnosis hint mentions § ⑦ → Read § ⑦ only
diagnosis hint mentions § ⑩ → Read § ⑩ only
no diagnosis hint           → Read § ⑥ + § ⑪ as fallback (the minimum needed to act)
```

Cap targeted reads at 200 lines total across all failures. If you'd need more, batch failures into agent groups so each agent gets a focused brief.

### Step 5: Dispatch fix agents

Use the Agent tool. **Model: `sonnet` — always, no exceptions.** Hardcoded for the testing pipeline (see auto-memory `feedback_test_pipeline_sonnet_only`). Do not pass a `model:` override; do not interpret any user phrase as permission to use Opus. If you believe Sonnet is insufficient for a specific failure, escalate to the human with the failure detail — don't silently upgrade the model.

Per-agent prompt structure (self-contained — agents see no conversation history):

```
You are fixing a regression on Screen #{N} {EntityName} ({screen_type}).

The Playwright spec at PSS_2.0_Frontend/tests/e2e/screens/{entity}.spec.ts ran and
the following tests failed:

{paste 1-N failure blocks verbatim from the Run entry}

The relevant spec section is:
{paste the targeted spec section}

Constraint: This is a fix pass, not a refactor. Touch only files needed to make these tests pass.
Do NOT change the spec — if the fix requires a spec change, STOP and report which §⑥/§⑦ line
needs to change. Do NOT run tests yourself — the parent skill re-runs them.

Files you are likely to touch:
- {paste relevant §⑧ File Manifest entries here}

When done, report:
1. Files touched (full paths)
2. One-sentence description per file
3. Whether you believe the fix is complete or partial
```

Spawn agents **in parallel** when failures are independent (e.g., 1 BE-only failure + 1 FE-only failure). Spawn sequentially for CROSS (BE first, then FE — FE may need the BE change to compile).

### Step 6: Verify the build (do NOT run Playwright yet)

```pwsh
# Backend (only if BE agent ran)
cd PSS_2.0_Backend
dotnet build PSS_2.0_Backend.sln

# Frontend (only if FE agent ran)
cd PSS_2.0_Frontend
pnpm build
```

If build fails → record the build error in the test-result file (`#### Cycle N Build Errors`), set screen status to `NEEDS_FIX`, abort the loop. Do NOT proceed to re-test a broken build.

### Step 7: Re-run tests (only if `--until-green`)

If `--until-green` was passed AND build succeeded, re-invoke [[test-screen]]:

```
Skill: test-screen
Args: #{N} --rerun
```

(Use `--rerun`, not `--regenerate` — the spec is fine; we're testing the code fix.)

When `/test-screen` returns:
- GREEN → Stage 8 (write final result, exit success).
- NEEDS_FIX → go back to Stage 2 with cycle counter incremented.
- INFRA_ERROR → stop, escalate.

### Step 8: Append FIX entry to `{entity-lower}.test-result.md`

Prepend a new Run entry above the existing ones — same schema as `/test-screen` writes, with a couple of extra fields:

```markdown
### Run {N+1} — {YYYY-MM-DD HH:MM} — FIX (cycle {C}/3) — {GREEN | NEEDS_FIX}
- Tests: {total} | {pass} passed | {fail} failed | {skip} skipped
- Duration: {Xm Ys}
- Trigger: /test-fix #{N}{ --until-green if set}
- Cycle: {C} of 3 (max)

#### Agents dispatched (cycle {C})
- backend-developer (sonnet) — touched: {paths}, summary: {1 line}
- frontend-developer (sonnet) — touched: {paths}, summary: {1 line}

#### Failures fixed in this cycle
- ✓ `{test name}` — was: {diagnosis hint}, fix: {1-line agent summary}

#### Failures NEW in this cycle (regression)
- ✗ `{test name}` — {diagnosis hint}

#### Still failing (carrying into next cycle)
- ✗ `{test name}` — {diagnosis hint}

#### Build outcome
- BE: PASS / FAIL ({error if FAIL})
- FE: PASS / FAIL ({error if FAIL})

#### Next step
{GREEN: "Screen verified — status: COMPLETED."}
{NEEDS_FIX cycle < 3: "Auto-continuing to cycle {C+1}…"}
{NEEDS_FIX cycle = 3: "Loop exhausted (3 cycles). Surfacing to human."}
```

### Step 9: Append one-line pointer to spec §⑬

```markdown
- Session {N} — {YYYY-MM-DD} — FIX (cycle {C}/3) — {GREEN | NEEDS_FIX} — see [{entity-lower}.test-result.md] — agents: {be|fe|both}
```

### Step 10: Update spec frontmatter

| Final result | Status |
|--------------|--------|
| GREEN | `NEEDS_FIX` → `COMPLETED`, update `last_session_date` |
| NEEDS_FIX after cycle 3 | stays `NEEDS_FIX`, update `last_session_date` |
| INFRA_ERROR | unchanged, update `last_session_date` |

(Note: per auto-memory `feedback_continue_screen_no_status_churn`, do NOT toggle `COMPLETED → IN_PROGRESS → COMPLETED` on these fix sessions — go straight to the final state.)

### Step 11: Summarize to user (≤ 12 lines)

```
Screen #41 Branch — /test-fix --until-green — exited after cycle 2/3 — GREEN
Cycle 1: BE+FE agents fixed 3/3, but 1 new regression appeared
Cycle 2: FE agent fixed the regression, all 12 tests pass

Final: ✓ 9 passed · ⊘ 3 skipped (intentional) · ✗ 0 failed
Files touched across cycles:
  BE: PSS_2.0_Backend/.../BranchCommandHandler.cs
  FE: PSS_2.0_Frontend/.../branch/page.tsx, .../branchFormSchema.ts
Status: NEEDS_FIX → COMPLETED
Full report: .claude/screen-tracker/prompts/branch.test-result.md (Runs 4 + 5)
```

If exhausted (3 cycles, still red):

```
Screen #41 Branch — /test-fix --until-green — EXHAUSTED after 3 cycles — still NEEDS_FIX
Pattern observed: cycle 1 fixed A, cycle 2 broke B fixing A, cycle 3 broke A fixing B.
Surfacing to human. Likely root cause: {1-line guess}.
Suggested human action: {e.g., "review §⑥ Form Section 2 — fields seem to contradict §⑩ DTO"}.
Full report: .claude/screen-tracker/prompts/branch.test-result.md (Runs 4–6).
```

---

## The `--until-green` loop (max 3 cycles)

```
            ┌──────────────────┐
            │  /test-fix #41   │
            │   --until-green  │
            └────────┬─────────┘
                     │
       ┌─────────────▼─────────────┐
       │  Cycle 1: read latest run │
       │  → spawn BE/FE agent      │
       │  → dotnet build / pnpm build
       │  → /test-screen --rerun   │
       └─────────────┬─────────────┘
                     │
              ┌──────▼──────┐
              │   green?    │── yes ──▶ status: COMPLETED, exit
              └──────┬──────┘
                     │ no
       ┌─────────────▼─────────────┐
       │  Cycle 2 (same loop)      │
       └─────────────┬─────────────┘
                     │
              ┌──────▼──────┐
              │   green?    │── yes ──▶ status: COMPLETED, exit
              └──────┬──────┘
                     │ no
       ┌─────────────▼─────────────┐
       │  Cycle 3 (same loop)      │
       └─────────────┬─────────────┘
                     │
              ┌──────▼──────┐
              │   green?    │── yes ──▶ status: COMPLETED, exit
              └──────┬──────┘
                     │ no
                     ▼
       Stop. status: NEEDS_FIX. Surface to user with diff summary
       of what was tried across 3 cycles so a human can intervene.
```

**Why 3?** Empirically two cycles catches transient races and typo-level mistakes; three cycles is the point at which the agent is most likely going in circles. Cheaper to escalate to a human than burn a 4th cycle of agent tokens. See [WORKING_FLOW.md](../test-screen/WORKING_FLOW.md) §6 for the cost rationale.

---

## What this skill REFUSES to do

| Refusal | Reason |
|---------|--------|
| Fix a test by changing the spec | Spec is source-of-truth. Send user to `/plan-screens #N` instead. |
| Edit `BaseUrlConfig.ts` | User-managed (per auto-memory `feedback_baseurl_user_managed`). |
| Fix failures attributed to OPEN known issues (§⑬) | Those tests should be skipped, not failed — fix the spec markers, not the code. |
| Fix `INFRA` failures (browser crash, dev-server-down) | Not a code issue. Surface to user. |
| Run more than 3 `--until-green` cycles | Cost cap. Surface to human. |
| Spawn an Opus agent — under ANY circumstance, with ANY flag | Testing pipeline is hardcoded to Sonnet (auto-memory `feedback_test_pipeline_sonnet_only`). Escalate hard failures to human, not Opus. |

---

## Parallel-session safety

1. **Per-screen state** — `{x}.test-result.md` and `{x}.md` are screen-owned. Two `/test-fix` runs on two screens don't collide.
2. **Shared wiring files** — if an agent needs to edit `AppDbContext.cs`, `Mutation.cs`, `Query.cs`, `Routes.tsx`, or DI registrations, the agent already warns and serializes (see [[continue-screen]] Step 6 — same constraint).
3. **Background test runs** — `--until-green` should NOT use `--bg` for the re-invoked `/test-screen`; the loop needs to wait for results. The skill enforces foreground.

---

## Failure modes & recovery

| Symptom | Handling |
|---------|----------|
| `dotnet build` fails after BE agent edit | Record error in test-result `Build Errors` section, abort loop, set status `NEEDS_FIX`. Do not re-test a broken build. |
| `pnpm build` fails after FE agent edit | Same as above. |
| Agent says "this fix requires a spec change" | Don't continue the loop. Surface to user with the agent's note and suggest `/plan-screens #N`. |
| Same failure persists across all 3 cycles unchanged | Stop early — the loop isn't making progress. Surface immediately, don't burn cycle 3. |
| New failure appears in cycle 2 that wasn't in cycle 1 | Continue (this is the loop's purpose), but flag the regression in the summary. |
| Sibling worktree drift (agent wrote to `pwds-soruban/` not `pwds-soruban - Copy/`) | After each cycle, verify via absolute-path Globs (per auto-memory `feedback_agent_sibling_worktree_drift`). If drift detected, abort loop and surface. |

---

## Relationship to other skills

See [test-screen/SKILL.md § Relationship to other skills](../test-screen/SKILL.md#relationship-to-other-skills) for the full pipeline diagram.

Position: **AFTER** `/test-screen` (which produces failures), **BEFORE** the next `/test-screen --rerun` (which verifies the fix). With `--until-green`, this skill **drives** the rerun loop instead of leaving it to the user.

---

## Why this exists

After `/test-screen` flags 3 failures on a screen, the manual workflow was: human reads the test output, opens the spec, opens the code, hand-prompts an agent. That's an hour of context-loading per screen × 121 screens. `/test-fix` automates exactly that hand-off — reads the **same** test-result file the human would read, dispatches the **same** specialized agents `/continue-screen` would dispatch, with the **same** spec-as-source-of-truth guardrail.

What's new here vs. `/continue-screen`: the trigger is **automated test output**, not a human bug report; the fix targets a **specific assertion failure**, not a fuzzy "this looks broken"; and `--until-green` closes the verify-fix-verify loop without the human in it.
