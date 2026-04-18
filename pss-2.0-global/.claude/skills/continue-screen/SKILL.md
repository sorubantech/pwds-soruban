---
name: continue-screen
description: /continue-screen — Resume work on a previously-built screen for bug fixes, UI changes, or enhancements. Reads the screen's Build Log to rehydrate context in a fresh session (including a new dev on a different machine after git-pulling the .claude/ folder). Use when a screen is already COMPLETED (or NEEDS_FIX) and the user wants to continue without running a full /build-screen over again.
---

# /continue-screen — Resume Screen Work (Post-Build)

> The portable handoff skill. A screen was built on one system; the `.jsonl` conversation transcript doesn't travel across machines — but the **prompt file + Build Log** (Section ⑬) does, because `.claude/` is git-tracked. This skill reads that log to rehydrate context in any session, on any machine, then runs a focused fix/enhance pass.

---

## When to use

| Situation | Use |
|-----------|-----|
| Screen is fully built (`status: COMPLETED`) but bug/UI/enhancement surfaced | `/continue-screen` |
| Screen build was interrupted mid-way (`status: PARTIALLY_COMPLETED`) | `/build-screen` (has its own resume path) |
| Screen prompt exists but nothing built yet (`status: PROMPT_READY`) | `/build-screen` (first-time build) |
| Screen not in registry yet | `/plan-screens` first |

---

## Input

```
/continue-screen              → Pick up the screen with status NEEDS_FIX (highest priority), else ask
/continue-screen #51          → Resume specific screen by registry number
/continue-screen "ContactType"→ Resume specific screen by name
/continue-screen #51 "<issue>"→ Resume specific screen with an inline issue description
```

---

## Execution Flow

### Step 1: Locate the target screen

1. Read `.claude/screen-tracker/REGISTRY.md`
2. If argument given → find that screen.
   If no argument → prefer any screen with status `NEEDS_FIX`; if none, ask the user which COMPLETED screen to resume.
3. Verify the prompt file exists at `.claude/screen-tracker/prompts/{entity-lower}.md`.
4. Verify status is one of: `COMPLETED`, `NEEDS_FIX`. If it's `PROMPT_READY` or `PENDING` → refuse with:
   > "This screen hasn't been built yet. Run `/build-screen #{id}` first."
   If it's `PARTIALLY_COMPLETED` → refuse with:
   > "This screen's initial build was interrupted. Run `/build-screen #{id}` to resume the build before opening a fix session."

### Step 2: Rehydrate context from the prompt file

Read the prompt file and extract, in order:

1. **Frontmatter** — `status`, `completed_date`, `last_session_date`, `scope`, `screen_type`.
2. **Section ① — Identity & Context** — what this screen is, for orientation.
3. **Section ⑥ — UI/UX Blueprint** — the authoritative layout spec (so fixes don't deviate from the original contract).
4. **Section ⑧ — File Manifest** — the canonical file paths the screen owns.
5. **Section ⑫ — Special Notes & Warnings** — gotchas that apply to any edit.
6. **Section ⑬ — Build Log** — full contents:
   - Known Issues table (all rows, OPEN and CLOSED).
   - All prior Session entries (in order) — pay attention to `Files touched` and `Deviations from spec`.

Summarize back to the user in ≤ 8 lines:
- Screen, registry ID, current status, last session date.
- Number of prior sessions, number of OPEN known issues.
- The most recently touched files (from the latest session entry).

### Step 3: Determine the work item

If the user provided an inline issue description, use that.

Otherwise, ask the user one structured question (use `AskUserQuestion` when available):

> "What would you like to do on this screen?"
>  - Fix a specific OPEN known issue (list IDs from the table)
>  - Report and fix a NEW bug (user describes it)
>  - Make a UI/UX change (user describes it)
>  - Add a small enhancement (user describes it)

If the user picks an OPEN issue, pull the full row from the Known Issues table. If NEW, ask them to describe:
- What they see (actual behavior)
- What they expect (expected behavior)
- Where — which file or UI area, if known

### Step 4: Classify the work

| Kind | Examples | Guardrail |
|------|----------|-----------|
| `FIX` | Runtime crash, broken CRUD, validation gap, wrong FK, skeleton missing | Must not introduce new dependencies. No schema changes. |
| `UI` | Spacing / token / skeleton / empty-state / layout tweak | Must follow `.claude/agents/frontend-developer.md` "UI Uniformity & Polish". |
| `ENHANCE` | Small feature addition consistent with the Spec | If it contradicts the Spec, stop and ask the user whether to update the Spec (Section ⑥) first. |

If the request is large enough that it changes the Spec (new field, new screen type, new FK, new workflow mode) → **stop** and tell the user:
> "This request changes the original Spec. Run `/plan-screens #{id}` to revise the blueprint, then re-build. `/continue-screen` handles in-scope fixes/tweaks only."

### Step 5: Set status to IN_PROGRESS

Update frontmatter:
- `status: NEEDS_FIX` → `status: IN_PROGRESS`
- `last_session_date: {today}`

(If starting from `COMPLETED` and the user hasn't already raised an issue, transition through `NEEDS_FIX` → `IN_PROGRESS` in one edit.)

### Step 6: Execute the work

Use the relevant specialized agent based on the area:
- BE-only fix → `backend-developer`
- FE-only fix → `frontend-developer`
- Cross-cutting → run both in sequence, BE first.

Keep the change surface **minimal** — only touch files needed for this work item. Do NOT refactor adjacent code, do NOT regenerate existing files. If the fix is a one-line change, make it a one-line change.

**Constraint — shared wiring files**: if this fix must edit a shared wiring file (`AppDbContext.cs`, `Query.cs`, `Mutation.cs`, `routes/Routes.tsx`, seed SQL files, DI registrations, sidebar nav), warn the user first — other parallel sessions may be touching the same files. Offer to defer the wiring edit to a queued-wiring pass if the user confirms conflicts are possible.

### Step 7: Verify

Run only the verification steps relevant to what changed:
- If FE file changed → `pnpm dev`, manually exercise the specific flow.
- If BE file changed → `dotnet build`, exercise the specific CRUD path.
- If DB seed changed → re-run the seed, verify the affected row.

Do **not** re-run the full `/build-screen` E2E checklist — that's for initial builds.

### Step 8: Append Build Log entry + resolve status

Append one entry to Section ⑬ `§ Sessions`:

```markdown
### Session {N} — {YYYY-MM-DD} — {FIX | UI | ENHANCE} — {COMPLETED | PARTIAL | BLOCKED}

- **Scope**: {one-sentence description of the work item}
- **Files touched**:
  - BE: {paths}
  - FE: {paths}
  - DB: {paths}
- **Deviations from spec**: {or "None"}
- **Known issues opened**: {new issues discovered but not fixed here — or "None"}
- **Known issues closed**: {IDs closed this session — or "None"}
- **Next step**: {empty if COMPLETED; otherwise what to resume on}
```

If any `Known issues closed` in this session → update the Known Issues table: change those rows' `Status` from `OPEN` to `CLOSED (session {N})`. Do not delete the rows — leave them for audit.

Update frontmatter:
- `status: IN_PROGRESS` → `COMPLETED` (if all work done + all OPEN issues addressed or intentionally deferred)
  OR → `NEEDS_FIX` (if work completed but other OPEN issues remain)
- `last_session_date: {today}`

Update `REGISTRY.md` only if the registry's shown status would change.

### Step 9: Summarize to the user

Short summary (≤ 10 lines):
- What was changed (1 sentence).
- Files touched (bulleted).
- Known Issues: closed {IDs} / still open {count}.
- Status transition (`NEEDS_FIX → COMPLETED` etc.).
- Suggested next step only if OPEN issues remain.

---

## Parallel-session safety

Because this skill can be invoked on multiple screens in different sessions:

1. **Screen-owned files are safe to edit in parallel** — page.tsx, config.tsx, entity.cs, CQRS handlers for a given screen.
2. **Shared wiring files require serialization** — if two sessions both need to edit `AppDbContext.cs` or `Routes.tsx`, pause and surface it to the user. A future `/apply-wiring` pass will batch these.
3. **The Build Log is per-screen** — two parallel sessions on two different screens never touch the same log.

---

## Failure modes & recovery

| Symptom | Handling |
|---------|----------|
| Prompt file has no Section ⑬ (legacy, pre-Build-Log) | Create Section ⑬ at the end of the file with an empty Known Issues table + a synthesized "Session 0 — BUILD — COMPLETED" retro-entry using the frontmatter `completed_date` and a `Files touched: (retroactive — not recorded)` note. Then proceed. |
| Build Log exists but last entry is `PARTIAL` with no matching IN_PROGRESS status | Trust the log, warn the user, and ask whether this session should resume the PARTIAL work or start a fresh FIX. |
| User's fix conflicts with a "Deviation from spec" noted in a prior session | Surface the prior deviation note and ask whether to keep the deviation or overwrite it. Never silently overwrite. |
| Verification fails after the fix | Append the Build Log entry with outcome `BLOCKED`, set status to `NEEDS_FIX`, and describe the blocker in `Next step:`. |

---

## Why this exists

Claude Code sessions don't transfer between machines — the `.jsonl` transcript is local. Teams share work via **git-tracked `.claude/`**. The Build Log is the portable handoff: any dev can pull the repo, run `/continue-screen #N`, and pick up with full context. No dependence on prior conversation memory, no assumption that the original developer is the one fixing it.

Corresponding writer: `/build-screen` Step 5a (appends the first Build Log entry on initial build completion).
