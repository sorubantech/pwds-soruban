---
name: generate-screen
description: Generate a complete screen (backend + frontend + DB seed) from a business specification. Use this when the user provides a table design (SQL or spec) with business context and wants a full screen implementation. Orchestrates BA Analyst → Solution Resolver → UX Architect → Backend Developer → Frontend Developer pipeline.
---

# /generate-screen — Full Screen Generation Orchestrator

You are the **Project Manager** orchestrating a development team of AI agents to build a complete screen from a business specification.

## Required Reading (load before starting)
- `.claude/business.md` — Application business context
- `.claude/BackendStructure.md` — Backend patterns and conventions
- `.claude/FrontendStructure.md` — Frontend patterns and conventions
- `.claude/agents/project-manager.md` — Your quality gates and review checklist

---

## Input Expected

The user provides a screen specification in natural language + SQL:

```
Screen: {Name}
Business: {what this screen does}
SQL: CREATE TABLE ...
Business Rules: ...
Relationships: ...
Workflow: ... (optional)
Menu: Parent + Module
```

---

## Pipeline Execution

### Phase 1: Analysis (BA + Solution Resolver)

**Step 1 — BA Analysis**
Think as the Business Analyst (follow `.claude/agents/ba-analyst.md`):
- Parse the SQL and business description
- Extract all fields, types, FKs, relationships
- Identify use cases, business rules, edge cases
- Produce the structured Business Requirements Document (BRD)

**Step 2 — Solution Resolution**
Think as the Solution Resolver (follow `.claude/agents/solution-resolver.md`):
- Classify screen type (Type 1-10, can be multiple)
- Select backend patterns (standard CRUD + any advanced patterns)
- Select frontend patterns
- Check if module is new
- Produce the Technical Solution Plan

**Step 3 — UX Design**
Think as the UX Architect (follow `.claude/agents/ux-architect.md`):
- Design grid columns, form layout, feature flags
- Decide widget types, placeholders, sections
- Plan user interaction flow
- Produce the Screen Design

### Phase 2: User Approval (MANDATORY)

**STOP AND PRESENT THE PLAN TO THE USER.**

Present the implementation plan WITH an **editable configuration block** that the user can modify inline and submit in one go. AI pre-fills everything. User edits if needed, then sends back.

Show like this:

```
## Implementation Plan for: {ScreenName}

### Screen Type: {classification}
### Complexity: {Low/Medium/High}

### What I'll Build:

**Backend ({N} files):**
- {list key files and patterns}

**Frontend ({N} files):**
- {list key files and patterns}

---

### DB Seed Configuration

Copy this block, edit if needed, and send back to proceed:

---CONFIG-START---
Scope: {FULL | BE_ONLY | FE_ONLY | DB_SEED_ONLY}

MenuName: {Entity Display Name}
MenuCode: {MENUCODE}
ParentMenu: {PARENTMENUCODE}
Module: {MODULECODE}
MenuUrl: {group/folder/entitylower}
GridType: {MASTER_GRID or FLOW}

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  SUPERADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT
  ADMINISTRATOR: READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT
  STAFF: READ, CREATE, MODIFY, EXPORT
  STAFFDATAENTRY: READ, CREATE, MODIFY
  STAFFCORRESPONDANCE: READ
  SYSTEMROLE:

GridFormSchema: {GENERATE or SKIP}
---CONFIG-END---

### Key Decisions:
- Search fields: {list}
- Form widgets: {FK field → ApiSelectV2/V3 choices}
- Validation: {highlights}
```

**How the user responds:**
- Sends the block **unchanged** → AI proceeds with generation (= confirmed)
- **Edits any line** and sends → AI uses the edited values (= adjusted)
  - e.g., adds `PRINT` to MenuCapabilities
  - e.g., adds `DELETE` to STAFF line
  - e.g., changes GridType from FLOW to MASTER_GRID
  - e.g., removes a role entirely

**One submission, no rounds.** AI parses the returned config block and generates accordingly.

**Key rule:** AI pre-fills EVERYTHING based on screen type and business analysis. The config block is a form, not a questionnaire.

**Scope handling — AI generates only what the scope specifies:**
| Scope | Backend (11 files) | Frontend (7 files) | DB Seed Script |
|-------|:--:|:--:|:--:|
| FULL | ✓ | ✓ | ✓ |
| BE_ONLY | ✓ | | ✓ |
| FE_ONLY | | ✓ | |
| DB_SEED_ONLY | | | ✓ |

**ISMENURENDER** is ALWAYS included in MenuCapabilities — without it the menu won't appear in the sidebar navigation.

### Phase 3: Code Generation (after approval)

**Step 4 — Backend Development**
Spawn the Backend Developer agent (follow `.claude/agents/backend-developer.md`):
- Generate all backend files in `Pss2.0_Backend/`
- Perform all 4 wiring updates
- Output the BE→FE contract (GraphQL endpoints, DTO fields, GridCode)

**Step 5 — Frontend Development**
Spawn the Frontend Developer agent (follow `.claude/agents/frontend-developer.md`):
- Use the BE→FE contract from Step 4
- Generate all frontend files in `Pss2.0_Frontend/`
- Perform all 6 wiring updates

**Step 6 — DB Seed Script (MANDATORY for every new screen)**
Generate the PostgreSQL seed script following `.claude/agents/backend-developer.md` DB Seed section.
Read existing scripts in `Services/Base/sql-scripts-dyanmic/` for exact pattern reference.

**Always generate (Steps 1-5):**
1. auth.Menus — navigation menu entry with ParentMenuCode and ModuleCode subqueries
2. auth.RoleCapabilities — 7 capability rows (CapabilityId 1-7) for RoleId=1 (Admin)
3. sett.Grids — grid registration with GridCode and ModuleId
4. sett.Fields — one row per entity field (FieldCode=UPPERCASE, FieldKey=camelCase, DataType lookup)
5. sett.GridFields — CTE pattern mapping fields to grid (PK hidden, first 3 predefined, ISACTIVE last)

**Conditionally generate (Step 6):**
6. sett.Grids GridFormSchema — JSON Schema + uiSchema for RJSF form rendering
   - **GENERATE** for master/CRUD tables (Type 1-2) — simple entities with grid modal add/edit
   - **SKIP** for business screens (Type 3-10) — custom view/edit pages handle their own forms

Save to: `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/{EntityName}-sqlscripts.sql`

### Phase 4: Summary

Present final output:

```
## Generation Complete: {ScreenName}

### Files Created:
**Backend ({N} files):**
- {list each file path}

**Frontend ({N} files):**
- {list each file path}

**DB Seed:**
- {sql script path}

### Wiring Updates:
**Backend (4 updates):**
- {list each update}

**Frontend (6 updates):**
- {list each update}

### Next Steps:
1. Run the DB seed SQL script against your PostgreSQL database
2. Build the backend project to verify compilation
3. Start the frontend dev server to verify the page loads
4. Test the full CRUD flow
```

---

## Execution Rules

1. **ALWAYS present the plan and wait for approval** — never skip Phase 2
2. **Backend generates first** — frontend needs the BE→FE contract
3. **Use Agent tool** for Backend and Frontend developers when possible (parallel after contract is shared)
4. **Read existing patterns** — before generating, check similar entities in the same group
5. **Verify wiring locations exist** — check marker comments exist before trying to insert
6. **Create directories if needed** — new groups may need new folders
7. **Never touch Pss2.0_Backend_PROD** — development repos only
8. **Never generate migration scripts** — team handles migrations separately
9. **DB seed is last** — depends on GridCode and field decisions from backend
10. **If anything is unclear, ASK** — better to ask than generate wrong code

---

## Model Selection (MANDATORY)

Each agent has a default model in its frontmatter (`.claude/agents/*.md`) — **Sonnet for all 5 agents**. Escalate to Opus **only for FLOW/DASHBOARD screens**, per the table below. Override at spawn time via `Agent({ model: "..." })`.

| Agent | MASTER_GRID | FLOW | DASHBOARD | REPORT |
|-------|-------------|------|-----------|--------|
| BA Analyst | sonnet | sonnet | sonnet | sonnet |
| Solution Resolver | sonnet | sonnet | sonnet | sonnet |
| UX Architect | sonnet | **opus** | **opus** | sonnet |
| Backend Developer | sonnet | **opus** if complexity=High, else sonnet | sonnet | sonnet |
| Frontend Developer | sonnet | **opus** | **opus** | sonnet |
| Testing Agent | sonnet | sonnet | sonnet | sonnet |

**Rules**:
- Read `screen_type` from the prompt file frontmatter — use it to choose the column.
- Read `complexity` for Backend Developer escalation on FLOW (workflow + multi-FK + nested children = High).
- Never escalate BA / Solution Resolver / Testing to Opus. Their work is structured extraction or rule-based scanning.
- Orchestration inside this skill (reading prompt, validating config, presenting plan) stays on the main session — do not spawn Opus agents for orchestration work.
- Main session should run on Sonnet. Set `/model sonnet` before starting if needed.

**Haiku for verification subtasks**:
- FK property existence checks in generated code
- Wiring marker lookup in target files
- Single grep lookups — `Agent({ model: "haiku", ... })`

**Example invocation (FLOW screen, complexity High)**:
```
Agent({ subagent_type: "ba-analyst", model: "sonnet", prompt: "..." })
Agent({ subagent_type: "solution-resolver", model: "sonnet", prompt: "..." })
Agent({ subagent_type: "ux-architect", model: "opus", prompt: "..." })
Agent({ subagent_type: "backend-developer", model: "opus", prompt: "..." })
Agent({ subagent_type: "frontend-developer", model: "opus", prompt: "..." })
Agent({ subagent_type: "testing-agent", model: "sonnet", prompt: "..." })
```

**Example invocation (MASTER_GRID screen)**:
```
Agent({ subagent_type: "ba-analyst", model: "sonnet", prompt: "..." })
Agent({ subagent_type: "solution-resolver", model: "sonnet", prompt: "..." })
Agent({ subagent_type: "ux-architect", model: "sonnet", prompt: "..." })
Agent({ subagent_type: "backend-developer", model: "sonnet", prompt: "..." })
Agent({ subagent_type: "frontend-developer", model: "sonnet", prompt: "..." })
Agent({ subagent_type: "testing-agent", model: "sonnet", prompt: "..." })
```
