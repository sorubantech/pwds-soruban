---
name: build-screen
description: /build-screen — Screen Builder (Executor)
---

# /build-screen — Screen Builder (Executor)

> Takes a cached prompt file (rich analysis from `/plan-screens`) and feeds it into 
> the `/generate-screen` pipeline for actual code generation.
> This is the **executor** — it bridges the planner's analysis to the generation pipeline.
> It also tracks task progress within the prompt file and updates the main registry on completion.

---

## Required Reading (load before starting)

- `.claude/screen-tracker/REGISTRY.md` — Master tracking file
- `.claude/screen-tracker/DEPENDENCY-ORDER.md` — Build sequence (to verify prerequisites)

**Do NOT pre-read these** — `/generate-screen` loads them as needed:
- Agent files (ba-analyst.md, solution-resolver.md, etc.)
- Code reference templates
- Backend/Frontend structure docs

---

## Input

The user invokes `/build-screen` with optional arguments:

```
/build-screen              → Build the next PROMPT_READY screen by dependency order
/build-screen #51          → Build specific screen by registry number
/build-screen "Program"    → Build specific screen by name
/build-screen #49 --scope BE_ONLY    → Generate backend only (for complex screens)
/build-screen #49 --scope FE_ONLY    → Generate frontend only (after BE is done)
```

---

## Execution Flow

### Step 1: Identify Target Screen

1. Read `.claude/screen-tracker/REGISTRY.md`
2. If no argument: find the first screen with status `PROMPT_READY`, ordered by dependency (Wave 1 → 2 → 3 → 4 → 5)
3. If argument given: find the matching screen
4. Also accept `PARTIALLY_COMPLETED` screens (resume interrupted builds)
5. Verify its status is `PROMPT_READY` or `PARTIALLY_COMPLETED` — if not, inform user to run `/plan-screens` first
6. Verify all FK dependencies are met — check that FK target screens are `COMPLETED` or have existing BE entities

### Step 2: Load & Validate Prompt File

1. Read the prompt file from `.claude/screen-tracker/prompts/{entity-lower}.md`
2. Verify the prompt has all required sections:
   - Frontmatter (screen name, registry_id, status, scope)
   - Tasks checklist
   - Screen Prompt section (Screen, Business, Table, Rules, Relationships, Menu)
   - Analysis Notes section
3. If prompt is missing or invalid, inform user to run `/plan-screens #{id}` first
4. If resuming a `PARTIALLY_COMPLETED` build, check the Tasks section to see what's already done

### Step 3: Pre-Build Checks

Before invoking the generation pipeline:

**3a. New Module Check**
If the prompt flags a new module (new DB schema), verify:
- Does `I{Module}DbContext.cs` exist? If not, it needs to be created first
- Flag this to the user or handle as part of generation

**3b. FK Target Verification**
For each FK in the prompt:
- Is the target entity in the codebase? (glob for the entity file)
- If not, abort and inform user which dependency is missing

**3c. Existing Code Conflict Check**
- If scope is `FE_ONLY`: verify BE files still exist before generating FE
- If scope is `FULL` and screen has existing FE stub: verify FE route still exists
- If scope is `ALIGN`: verify existing files haven't been deleted

### Step 4: Feed Prompt to /generate-screen Pipeline

This is the core step. Take the rich prompt from `/plan-screens` and execute the `/generate-screen` pipeline.

**How this works:**

The prompt file IS the input. It contains everything `/generate-screen` expects:
- Screen name + Business description → BA agent input
- Table definition + Business Rules → BA + Solution Resolver input  
- UI/UX Analysis Notes → UX Architect gets a head start
- Scope + Menu → Configuration for DB seed
- Complexity + Dependencies → Solution Resolver context

**Execute the `/generate-screen` flow directly:**

1. **Phase 1: Analysis** — Run BA → Solution Resolver → UX Architect using the prompt as input
   - The "Analysis Notes" section gives these agents pre-analyzed context
   - BA should validate and enrich (not start from scratch)
   - Solution Resolver classifies screen type (the prompt has a recommendation)
   - UX Architect designs layout (the prompt has mockup-derived details)
   - **Update prompt file tasks**: mark BA, Solution Resolution, UX as complete

2. **Phase 2: User Approval** — MANDATORY, never skip
   - Present the implementation plan with the editable CONFIG block
   - Wait for user confirmation/adjustments
   - **Update prompt file tasks**: mark User Approval as complete

3. **Phase 3: Code Generation** — After approval
   - Backend Developer generates all BE files (if scope includes BE)
   - **Update prompt file tasks**: mark Backend code + wiring as complete
   - Frontend Developer generates all FE files (if scope includes FE)
   - **Update prompt file tasks**: mark Frontend code + wiring as complete
   - DB Seed script generated (if scope includes BE)
   - **Update prompt file tasks**: mark DB Seed as complete

4. **Phase 4: Summary** — Present what was generated

**Follow all rules from `/generate-screen` SKILL.md** — this step IS `/generate-screen`, just with a richer input.

### Step 5: Update Prompt File & Registry

**After each major step**, update the prompt file's Tasks section:
- Check off completed tasks: `- [ ]` → `- [x]`
- Update frontmatter status: `PENDING` → `IN_PROGRESS` → `COMPLETED`

**After successful full generation:**

1. Update prompt file:
   - Status: `COMPLETED`
   - `completed_date: {YYYY-MM-DD}`
   - `last_session_date: {YYYY-MM-DD}`
   - All generation tasks checked off
2. **Append Build Log entry** (Section ⑬ — see below)
3. Update REGISTRY.md:
   - Change screen status from `PROMPT_READY` to `COMPLETED`
   - Add Notes with date and file count
   - Update Summary counts

**If generation fails or is partial:**

1. Update prompt file:
   - Status: `PARTIALLY_COMPLETED`
   - `last_session_date: {YYYY-MM-DD}`
   - Check off only completed tasks
   - Add a note about what remains
2. **Append Build Log entry** with outcome `PARTIAL` and a `Next step:` line describing what to resume on
3. Update REGISTRY.md:
   - Change status to `PARTIALLY_COMPLETED`
   - Add Notes explaining what was completed and what remains

### Step 5a: Append Build Log Entry (MANDATORY — every session)

Every `/build-screen` session — whether it ends in `COMPLETED` or `PARTIAL` — MUST append one entry to the prompt file's Section ⑬ Build Log before exiting. This is the portable handoff record that `/continue-screen` reads when a new session resumes work.

**Format** (append under `### § Sessions`, after any existing entries):

```markdown
### Session {N} — {YYYY-MM-DD} — BUILD — {COMPLETED | PARTIAL}

- **Scope**: Initial full build from PROMPT_READY prompt.
- **Files touched**:
  - BE: {list paths created/modified, with (created) or (modified) suffix}
  - FE: {list paths created/modified}
  - DB: {seed sql path (modified)}
- **Deviations from spec**: {anything intentionally built differently from the Spec — or "None"}
- **Known issues opened**: {new bugs/defects visible in the build — or "None"}
- **Known issues closed**: None
- **Next step**: {empty for COMPLETED; for PARTIAL: exact step to resume on — e.g., "Frontend wiring: routes/Routes.tsx + sidebar nav still pending"}
```

**Session number**: start at 1. Read the existing log first — if N prior entries exist, this entry is N+1.

**Known Issues table**: if this session surfaced a real bug (test failure, build break not fixed this session, mockup gap), add a row to the Known Issues table with a stable ID `ISSUE-{N}` and `Status: OPEN`. Never edit prior sessions' entries.

**Placeholder cleanup**: on the first session, delete the `{No sessions recorded yet …}` placeholder line before appending.

### Step 5b: Full-Flow Testing (MANDATORY)

Every screen MUST be tested end-to-end, not just backend compilation:

1. **Backend build**: `dotnet build` — verify no compilation errors
2. **Frontend build**: `pnpm dev` — verify page loads at the correct route
3. **Full CRUD flow**: Create → Read → Update → Toggle → Delete
4. **Grid verification**: Columns render, search/filter works, pagination works
5. **Form verification**: All fields render, validation fires, FK dropdowns load
6. **Summary widgets** (if applicable): Widget cards display with correct values
7. **Service placeholder buttons** (if applicable): Buttons render, clicking shows placeholder toast
8. **DB Seed**: Menu appears in sidebar, grid columns configured correctly

**IMPORTANT**: Avoid `BE_ONLY` scope unless there is a clear, documented justification (e.g., extremely complex screen that genuinely needs to be split across sessions). Every screen should go through complete development and full-flow testing in a single build session when possible.

### Step 6: Present Summary

```markdown
## Build Complete: {ScreenName}

### Files Generated
**Backend ({N} files):** {list}
**Frontend ({N} files):** {list}
**DB Seed:** {sql file}

### Wiring Updates
**Backend ({N}):** {list}
**Frontend ({N}):** {list}

### Task Status (in prompts/{entity-lower}.md)
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized
- [x] User Approval received
- [x] Backend code generated
- [x] Frontend code generated
- [x] DB Seed script generated
- [x] Registry updated

### Registry Updated
- Status: PROMPT_READY → COMPLETED
- Next screen in queue: {next screen name} (#{id})

### Next Steps
1. Run the DB seed SQL script
2. `dotnet build` to verify backend
3. `pnpm dev` to verify frontend
4. Test the CRUD flow
5. Run `/build-screen` for the next screen
```

---

## Rules

1. **Never build without a prompt** — if no prompt file exists, redirect to `/plan-screens`
2. **Never skip user approval** — Phase 2 of the generation pipeline is mandatory
3. **Verify dependencies first** — don't build if FK targets are missing
4. **Update tasks progressively** — mark each task as done when completed, not all at the end
5. **Update registry on completion** — both prompt file AND REGISTRY.md
6. **One screen per build** — keeps sessions focused and token-efficient
7. **Handle new modules explicitly** — if first entity in a new schema, create module infrastructure first
8. **Scope-aware generation** — if prompt says `FE_ONLY`, don't generate backend files
9. **Preserve existing code** — if PARTIAL or ALIGN, don't overwrite what already exists
10. **Prompt is the input** — feed the prompt content directly to the generation pipeline
11. **Don't re-analyze from scratch** — the prompt already contains deep analysis; agents validate and enrich
12. **Resume interrupted builds** — if status is `PARTIALLY_COMPLETED`, continue from where it stopped

---

## Error Recovery

| Scenario | Action |
|----------|--------|
| Prompt file not found | Tell user to run `/plan-screens #{id}` |
| FK dependency missing | List missing dependencies, suggest build order |
| Build fails mid-way | Set status to `PARTIALLY_COMPLETED`, note what completed in tasks |
| User rejects approval | Keep status as `PROMPT_READY`, let user modify prompt |
| New module needed | Create module infrastructure before entity generation |
| Token limit approaching | Save progress, set `PARTIALLY_COMPLETED`, user resumes next session |

---

## Token Optimization & Directives (MANDATORY)

### Model & Permission Rules
- **Role**: Use only `BUSINESSADMIN` for all approval configs and testing scenarios. Do not enumerate all 7 roles.
- **Permissions**: Assume standing read/write access for all files under `Pss2.0_Backend/` and `Pss2.0_Frontend/`. Only prompt for destructive operations (git push, file deletion). Do NOT re-ask permissions during a build session.
- **Builds**: Avoid full `dotnet build` or `pnpm build` unless absolutely necessary. Prefer targeted type-checking of specific projects/files. Full builds waste tokens.

### Form Fidelity Rule (CRITICAL)
**FLOW screens have 3 URL modes and 2 distinct UI layouts — both MUST match the HTML mockup exactly.**

```
URL MODE                              UI LAYOUT
─────────────────────────────────     ──────────────────────────
/entity?mode=new                  →   FORM LAYOUT  (empty form)
/entity?mode=edit&id=243          →   FORM LAYOUT  (pre-filled, editable)
/entity?mode=read&id=243          →   DETAIL LAYOUT (read-only — DIFFERENT UI)
```

The prompt's Section ⑥ describes BOTH layouts:
- **LAYOUT 1: FORM** (for `mode=new` and `mode=edit`) — the add/edit form
- **LAYOUT 2: DETAIL** (for `mode=read`) — the read-only detail page (different from the form)

**FORM LAYOUT must match the mockup exactly:**
- **Form sections**: Match the accordion/card sections from the mockup (number, titles, icons, collapse state)
- **Field groupings**: Match column layout (2-col, 3-col, full-width) per section
- **Card selectors**: If mockup shows card-style selection (e.g., donation mode cards), implement card selectors — NOT dropdown selects
- **Conditional sub-forms**: If mockup shows different fields per mode/type, implement conditional rendering — NOT showing all fields at once
- **Child grids**: If mockup shows inline child rows (e.g., distribution rows), implement repeating row components with add/remove — NOT a separate page
- **Computed fields**: If mockup shows auto-calculated values (e.g., BaseCurrencyAmount = Amount × Rate), implement real-time calculation with readonly display fields

**DETAIL LAYOUT must match the mockup exactly:**
- **Multi-column layout**: If mockup shows 2-column detail (e.g., left 2fr + right 1fr), implement that — NOT just the form in disabled state
- **Info cards**: Each card section (Summary, Amount, Payment, etc.) with correct fields and display formatting
- **Related data panels**: History tables, audit trail timelines, linked records
- **Header actions**: Edit button (→ `?mode=edit`), Print, Send, More dropdown

**Why this matters**: GlobalDonation #1 was marked COMPLETED but its form didn't match the mockup. The prompt had all the detail (6 accordion sections, mode card selector, distribution grid, payment sub-forms) but the FE dev agent produced a generic form. This MUST NOT recur.

### Layout Variant Enforcement (MASTER_GRID + FLOW)

Every prompt Section ⑥ stamps a `Layout Variant`: `grid-only`, `widgets-above-grid`, `side-panel`, or a combination. The FE agent uses this to pick Variant A (`<AdvancedDataTable>`/`<FlowDataTable>` with internal header) vs Variant B (`<ScreenHeader>` + widgets + `<DataTableContainer showHeader={false}>`).

**Orchestrator duties:**

1. **Pre-build brief** — read `Layout Variant` from prompt Section ⑥. Pass it explicitly to the FE Developer agent's prompt: "Layout Variant: `{variant}`. Honor the Layout Variant Decision table in your instructions. If not `grid-only`, use Variant B."

2. **If `Layout Variant` is missing or NONE on a screen whose Section ⑥ lists widgets or a side panel** — STOP and fix the prompt first. Ship Section ⑥ with a correct stamp before spawning FE Developer.

3. **Post-build validation** — before marking COMPLETED, open the generated `*-data-table.tsx` (or `index-page.tsx` for FLOW) and check:
   - If variant ≠ `grid-only` → file MUST import `ScreenHeader` from `@/presentation/components/custom-components/page-header` AND the data-table container MUST receive `showHeader={false}`.
   - If variant = `grid-only` → file renders `<AdvancedDataTable>` / `<FlowDataTable>` directly.
   - Fail mode (both present or both absent) = double header or missing header. Block COMPLETED until fixed.

**Precedent (why this is enforced)**: ContactType #19 had a summary bar above the grid but the FE agent produced Variant A (plain `<AdvancedDataTable>` stacked with `<SummaryBar>` in a card) — no `<ScreenHeader>`, internal grid header still rendered, double-header UI hierarchy. The Variant B pattern was documented in the reference template but never surfaced as a per-screen signal, per-agent directive, or post-build check.

---

### UI Uniformity Check (ALL screens, post-build)

Before marking COMPLETED, sample-scan the generated FE files for design-token compliance. Full spec in `.claude/agents/frontend-developer.md` section "UI Uniformity & Polish".

**Grep checks** (each should return ZERO matches in generated files):

| Anti-pattern | Grep |
|--------------|------|
| Inline hex colors | `style=\{\{[^}]*#[0-9a-fA-F]{3,6}` |
| Inline pixel padding/margins | `style=\{\{[^}]*(padding\|margin):\s*\d+` |
| Bootstrap card mixed with tailwind tokens | `className="card[^"]*"` (in new files) |
| Hand-rolled skeleton div | `background:\s*["']#e[0-9a-f]` (commonly `#e5e7eb`) |
| Raw "Loading..." text | `>Loading\.\.\.</` |

**Visual checks** (FE agent self-reviews or Testing Agent runs):
- All sibling cards in a layout share the same inner padding class.
- Every `useQuery`-backed surface has a `<Skeleton>` placeholder sized to match real content.
- Empty / error / disabled states present with consistent framing.

If any of these fail, the screen is NOT COMPLETED — send back to FE Developer with the specific line(s) flagged.

---

### Component Reuse-or-Create Protocol (MASTER_GRID + FLOW)

The FE Developer agent follows a strict **search → reuse → create-if-simple → escalate-if-complex** discipline. Full spec lives in `.claude/agents/frontend-developer.md` (section "Component Reuse-or-Create Protocol").

**At build time, the orchestrator MUST:**

1. **Pre-build** (before spawning FE Developer): scan the prompt's Section ⑥ + DB seed for cell renderer names (`GridComponentName`) and mockup chips/badges. Include them in the FE agent's brief with an instruction: "Search registries first — reuse if found; create as simple static component if missing; flag to user if complex."

2. **Post-build validation** (before marking COMPLETED): for every `GridComponentName` value emitted by the backend's DB seed, grep `custom-components/data-tables/*/data-table-column-types/component-column.tsx` — every value must resolve in `elementMapping` or a switch case. If any value is missing, the build is NOT complete. Either:
   - Create the missing renderer(s), OR
   - Correct the DB seed to use an existing renderer.

3. **Never accept** a screen where the DB seed references a renderer name that doesn't exist in the FE registry — that's a guaranteed runtime crash ("Element type is invalid").

**Precedent**: ContactType #19 shipped with 7 invented `GridComponentName` values (`badge-code`, `text-bold`, `text-truncate`, `link-count`, `badge-system`, `badge-circle`, `status-badge`) that had no frontend counterpart → runtime crash on page load. This check blocks that class of bug.

### Session Optimization
1. **Load minimal context** — only read: REGISTRY.md + prompt file
2. **Don't re-read HTML mockups** — the prompt already contains all extracted information
3. **Don't re-read all agent files upfront** — the generation pipeline loads them as needed
4. **Target ~30-50K tokens** per screen build — if a screen is complex, split into BE + FE sessions

### Model Selection — Screen-Type-Based Escalation (MANDATORY)

`/build-screen` orchestrates 5 AI agents via `/generate-screen`. Each agent has a default model set in its frontmatter (`.claude/agents/*.md`). Default is Sonnet for every agent. Escalate to Opus **only when the screen type actually needs judgment**.

**Default main session model**: Sonnet. Orchestration is not code generation. If the user's session is on Opus, the subagent defaults from frontmatter still apply — but the orchestrator's own reasoning (selecting files, reading prompt, coordinating) should not use Opus.

**Per-call model override when spawning agents** — pass `model:` explicitly based on `screen_type` read from prompt file frontmatter:

| Agent | MASTER_GRID | FLOW | DASHBOARD | REPORT |
|-------|-------------|------|-----------|--------|
| BA Analyst | sonnet | sonnet | sonnet | sonnet |
| Solution Resolver | sonnet | sonnet | sonnet | sonnet |
| UX Architect | sonnet | **opus** | **opus** | sonnet |
| Backend Developer | sonnet | **opus** if complexity=High, else sonnet | sonnet | sonnet |
| Frontend Developer | sonnet | **opus** | **opus** | sonnet |
| Testing Agent | sonnet | sonnet | sonnet | sonnet |

**Why escalate only for FLOW/DASHBOARD**:
- FLOW: 3-mode view-page with 2 distinct UI layouts (FORM + DETAIL), card selectors, conditional sub-forms, child grids — historic failure point (GlobalDonation). Opus needed for UX Architect + FE Developer judgment.
- DASHBOARD: widget composition + chart choice + drill-down routing — design judgment.
- MASTER_GRID: config-driven grid + RJSF modal form. Sonnet handles correctly.
- REPORT: filter panel + result view — template-driven. Sonnet handles correctly.

**Example invocation for a FLOW screen**:
```
Agent({ subagent_type: "ux-architect", model: "opus", prompt: "..." })
Agent({ subagent_type: "frontend-developer", model: "opus", prompt: "..." })
Agent({ subagent_type: "backend-developer", model: "sonnet", prompt: "..." })  // unless complexity=High
```

**Example invocation for a MASTER_GRID screen**:
```
Agent({ subagent_type: "ux-architect", model: "sonnet", prompt: "..." })
Agent({ subagent_type: "frontend-developer", model: "sonnet", prompt: "..." })
Agent({ subagent_type: "backend-developer", model: "sonnet", prompt: "..." })
```

**Haiku opportunities during build**:
- FK property existence checks in generated code → `Agent({ model: "haiku" })`
- Single-file grep verification → main context or Haiku
- Wiring marker lookups in target files → Haiku

**Do NOT**:
- Escalate BA/Solution Resolver/Testing/PM to Opus — ever.
- Use Opus main session while waiting between agent calls — run orchestration on Sonnet.
- Spawn an agent for trivial lookups that main context can do in one tool call.
