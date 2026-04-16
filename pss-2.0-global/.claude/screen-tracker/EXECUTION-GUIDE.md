# Execution Guide — How to Run the Screen Development Pipeline

> Step-by-step guide for developers. Follow this to plan and build screens.
> No prior knowledge of the pipeline required.

---

## Prerequisites

Before you start, make sure:

1. **Claude Code** is installed and running (CLI, VS Code extension, or desktop app)
2. You're in the project directory: `d:\Repos\PWDS\pwds-soruban\pss-2.0-global`
3. Backend and Frontend are set up:
   - `dotnet build` works in `Pss2.0_Backend/`
   - `pnpm dev` works in `Pss2.0_Frontend/`
4. The `.claude/screen-tracker/` folder exists with:
   - `REGISTRY.md` — master tracking file
   - `DEPENDENCY-ORDER.md` — build sequence
   - `MODULE_MENU_REFERENCE.md` — menu/module lookup
   - `prompts/` — folder for prompt files

---

## Daily Workflow

Your typical day looks like this:

```
Morning:
  1. Open Claude → /plan-screens      → Prepares 3-5 screen prompts
  2. Review the generated prompt files → Quick sanity check

Then repeat:
  3. Open NEW Claude session → /build-screen → Builds one screen
  4. Review the approval plan when asked → Approve
  5. Wait for generation + testing to complete
  6. Verify the screen works in browser
  7. Repeat step 3 for next screen
```

---

## The 3 Skills

The pipeline uses 3 skills. You only run 2 of them — the third is called automatically.

| Skill | Role | You Run It? | What It Does |
|-------|------|-------------|-------------|
| `/plan-screens` | The Brain | YES | Analyzes mockups, creates prompt files |
| `/build-screen` | The Executor | YES | Reads prompt, validates, calls /generate-screen |
| `/generate-screen` | The Dev Team | NO (auto) | 5 AI agents that write all the code |

```
  You type:              Behind the scenes:
  ──────────             ──────────────────
  /plan-screens    →     Analyzes → creates prompt file
  /build-screen    →     Reads prompt → calls /generate-screen → 5 agents write code → tests
```

---

## Command Reference

### `/plan-screens` — Analyze & Prepare Prompts

| Command | What it does |
|---------|-------------|
| `/plan-screens` | Plans the next 5 screens (by dependency order) |
| `/plan-screens 3` | Plans next 3 screens only |
| `/plan-screens #51` | Plans one specific screen (by registry number) |
| `/plan-screens "Grant"` | Plans one specific screen (by name) |
| `/plan-screens wave 1` | Plans all screens in Wave 1 |
| `/plan-screens review 5` | Plans 5 existing-code screens for alignment |

**When to use:** When you need fresh prompt files. Always do this before building.

**Output:** Prompt files saved to `.claude/screen-tracker/prompts/{entity-name}.md`

---

### `/build-screen` — Execute Code Generation

| Command | What it does |
|---------|-------------|
| `/build-screen` | Builds the next PROMPT_READY screen |
| `/build-screen #51` | Builds a specific screen |
| `/build-screen "Grant"` | Builds a specific screen by name |

**When to use:** After `/plan-screens` has created prompt files.

**Important:** Always run this in a **NEW Claude session** — don't continue
from the planning session. Fresh context = better code generation.

**What it does internally:**
1. Reads the prompt file
2. Validates dependencies (FK targets exist in codebase)
3. Calls `/generate-screen` with the prompt content
4. Tracks progress in the prompt file (task checkboxes)
5. Updates registry on completion

---

### `/generate-screen` — The Dev Team Engine (called automatically)

**You never run this directly.** `/build-screen` calls it for you.

This is the actual code generation engine with 5 AI agents:

| Agent | What It Does |
|-------|-------------|
| BA Analyst | Validates business rules, fields, constraints |
| Solution Resolver | Classifies screen type, picks code patterns |
| UX Architect | Designs layout, component structure, interactions |
| Backend Developer | Writes all .NET files (~11 files + 4 wiring updates) |
| Frontend Developer | Writes all React/TS files (~9 files + 4 wiring updates) |

Plus: DB Seed Script generation (menu, grid columns, form schema, permissions)

**The flow inside /generate-screen:**
```
  Agent 1 (BA) → Agent 2 (Solution) → Agent 3 (UX)
                                           │
                                    YOUR APPROVAL ← you review & confirm here
                                           │
                                Agent 4 (Backend) → Agent 5 (Frontend) → DB Seed
```

---

## Step-by-Step: Planning Screens

### 1. Start a Claude session

Open Claude Code in your terminal or IDE.

### 2. Run the command

```
/plan-screens
```

### 3. Review the progress summary

The tool will first show you current progress:
```
## Current Progress
- Last completed: #12 ContactType (completed on 2026-04-15)
- In progress: None
- Queued (PROMPT_READY): 2 screens
- Remaining to plan: 72 screens
```

### 4. Let it analyze

The tool reads HTML mockups, existing code, and foreign key references.
This takes a few minutes per screen. You don't need to do anything.

### 5. Review the output

You'll see a summary like:
```
## Planned 5 Screens

| # | Screen          | Module | Type        | Complexity |
|---|-----------------|--------|-------------|------------|
| 15| MembershipTier  | CRM    | MASTER_GRID | Low        |
| 16| VolunteerType   | CRM    | MASTER_GRID | Low        |
| 17| GrantCategory   | CRM    | MASTER_GRID | Medium     |
| 18| DonationType    | CRM    | MASTER_GRID | Low        |
| 19| CaseCategory    | CRM    | MASTER_GRID | Low        |
```

### 6. (Optional) Review prompt files

Open any prompt file to check the details:
```
.claude/screen-tracker/prompts/membership-tier.md
```

Each file has 12 sections covering everything the build step needs.
If something looks wrong, you can edit it manually before building.

### 7. Done — ready for building

The registry is updated. You can now run `/build-screen`.

---

## Step-by-Step: Building a Screen

### 1. Start a NEW Claude session

Close the planning session. Open a fresh Claude Code session.
This is important — fresh context gives better results.

### 2. Run the command

```
/build-screen
```

Or for a specific screen:
```
/build-screen #15
```

### 3. Wait for Phase 1 (Analysis)

Three AI agents analyze the prompt:
- BA Analyst checks business rules
- Solution Resolver picks the right patterns
- UX Architect designs the layout

This takes 2-5 minutes. You don't need to do anything.

### 4. Phase 2: Review & Approve (YOUR ACTION NEEDED)

You'll see an implementation plan like this:

```
---CONFIG-START---
Scope: FULL

MenuName: Membership Tier
MenuCode: MEMBERSHIPTIER
ParentMenu: CRM_MEMBERSHIP
Module: CRM
MenuUrl: crm/membership/membershiptier
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT
RoleCapabilities:
  SUPERADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT
  ...

GridFormSchema: GENERATE
GridCode: MEMBERSHIPTIER
---CONFIG-END---
```

**What to check:**
- Is the MenuName correct?
- Is the MenuCode correct? (should match MODULE_MENU_REFERENCE.md)
- Is the GridType right? (MASTER_GRID vs FLOW)
- Are the role permissions appropriate?

**If everything looks good:** Type "approve" or "yes" or "looks good"

**If something needs changing:** Tell Claude what to adjust:
> "Change the MenuCode to MEMBTIER" or "Add IMPORT capability for STAFF role"

### 5. Wait for Phase 3 (Code Generation)

Two AI agents generate all the code:
- Backend Developer creates ~11 .NET files + wiring
- Frontend Developer creates ~9 React/TS files + wiring
- DB Seed script is generated

This takes 10-20 minutes depending on complexity.

### 6. Phase 4: Testing Results

You'll see test results:
```
✓ dotnet build — passed
✓ pnpm dev — page loads at /en/crm/membership/membershiptier
✓ CRUD flow — create, edit, toggle, delete all work
✓ Grid columns render correctly
✓ DB Seed — menu visible in sidebar
```

### 7. Verify in your browser

Open the app and navigate to the screen. Check:
- Does the page load?
- Can you add a new record?
- Does the form have all the right fields?
- Does the grid show the right columns?
- Do dropdowns load their data?

### 8. Done — screen is complete

The registry is updated to COMPLETED. Move to the next screen.

---

## Handling Issues

### Screen build fails mid-way

The tool saves progress automatically. The screen status becomes `PARTIALLY_COMPLETED`.
Just run `/build-screen #XX` again — it resumes from where it stopped.

### Want to re-plan a screen

Edit the prompt file manually at `prompts/{entity-name}.md`, or run `/plan-screens #XX`
again to regenerate it from scratch.

### Dependencies are missing

If screen B needs screen A's data (foreign key), screen A must be built first.
The tool checks this automatically and will tell you what's missing.

### New module needed

Some screens are the first in a new database schema (e.g., `grant`, `vol`, `case`, `mem`).
The tool flags this and creates the module infrastructure first.

---

## File Locations

| File / Folder | Purpose |
|--------------|---------|
| `.claude/screen-tracker/REGISTRY.md` | Master list of all screens + status |
| `.claude/screen-tracker/DEPENDENCY-ORDER.md` | Build sequence (Wave 1→2→3→4→5) |
| `.claude/screen-tracker/MODULE_MENU_REFERENCE.md` | Real menu codes from database |
| `.claude/screen-tracker/PIPELINE-FLOW.md` | Pipeline overview (this companion doc) |
| `.claude/screen-tracker/prompts/` | All screen prompt files |
| `.claude/screen-tracker/prompts/_TEMPLATE.md` | Template used to generate prompts |
| `.claude/skills/plan-screens/` | Skill definition for /plan-screens |
| `.claude/skills/build-screen/` | Skill definition for /build-screen |
| `.claude/skills/generate-screen/` | Skill definition for /generate-screen |
| `html_mockup_screens/` | HTML mockups (source of truth for UI) |

---

## Rules to Follow

### Always
- Run `/plan-screens` before `/build-screen` — never build without a prompt
- Use a NEW session for each `/build-screen` — keeps AI focused
- Review the approval plan in Phase 2 — never auto-approve blindly
- Test the screen in the browser after generation
- Build screens in dependency order (Wave 1 first)

### Never
- Skip the approval step
- Run multiple `/build-screen` in the same session
- Build a screen before its dependencies are ready
- Manually create files that the pipeline should generate
- Mark a screen as complete without full E2E testing

### About Scope
- **FULL** is the default — generates backend + frontend + seed
- **BE_ONLY or FE_ONLY** should be avoided unless the screen is genuinely too complex
  for a single session. Every screen should go through complete development
  and full-flow testing.

### About Service Buttons
Some screens have buttons like "Send SMS", "Send WhatsApp", "Generate Certificate".
These are implemented as **UI only** — the button exists and is properly placed,
but it shows a placeholder message when clicked. Backend services are built later.

---

## Quick Reference Card

```
┌───────────────────────────────────────────────────────┐
│              SCREEN DEVELOPMENT CHEAT SHEET            │
│                                                        │
│  PLAN:   /plan-screens                                 │
│          /plan-screens 3                               │
│          /plan-screens #51                              │
│                                                        │
│  BUILD:  /build-screen          (new session!)         │
│          /build-screen #51                              │
│                                                        │
│  CHECK:  Read REGISTRY.md for overall progress         │
│          Read prompts/{name}.md for screen details     │
│                                                        │
│  ORDER:  Wave 1 → 2 → 3 → 4 → 5                      │
│                                                        │
│  RULE:   Plan first. Build second. Test always.        │
│                                                        │
│  IF STUCK: Check DEPENDENCY-ORDER.md for prereqs       │
│            Check MODULE_MENU_REFERENCE.md for codes    │
│            Re-run /plan-screens #XX to regenerate      │
└───────────────────────────────────────────────────────┘
```
