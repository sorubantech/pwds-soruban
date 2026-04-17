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
   - All generation tasks checked off
2. Update REGISTRY.md:
   - Change screen status from `PROMPT_READY` to `COMPLETED`
   - Add Notes with date and file count
   - Update Summary counts

**If generation fails or is partial:**

1. Update prompt file:
   - Status: `PARTIALLY_COMPLETED`
   - Check off only completed tasks
   - Add a note about what remains
2. Update REGISTRY.md:
   - Change status to `PARTIALLY_COMPLETED`
   - Add Notes explaining what was completed and what remains

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

### Session Optimization
1. **Load minimal context** — only read: REGISTRY.md + prompt file
2. **Don't re-read HTML mockups** — the prompt already contains all extracted information
3. **Don't re-read all agent files upfront** — the generation pipeline loads them as needed
4. **Target ~30-50K tokens** per screen build — if a screen is complex, split into BE + FE sessions
5. **Use subagents with `model: "sonnet"` for research/analysis tasks** (FK verification, file existence checks). Reserve the primary model for code generation.
