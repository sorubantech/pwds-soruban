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
- For MASTER_GRID/FLOW: generate the standard 11-file CRUD pipeline + 4 wiring updates
- For DASHBOARD: SKIP entity/CRUD; generate only `{EntityName}DashboardDto.cs` + `Get{EntityName}DashboardData.cs` (composite query handler) + per-widget query handlers if defined + Mapster config + Queries endpoint registration. NO Mutations endpoint (read-only). See `backend-developer.md` § "DASHBOARD Screen Generation".
- For REPORT: standard CRUD if the report backs an entity; aggregate query only if pure projection
- Output the BE→FE contract (GraphQL endpoints, DTO fields, GridCode for non-DASHBOARD)

**Step 5 — Frontend Development**
Spawn the Frontend Developer agent (follow `.claude/agents/frontend-developer.md`):
- Use the BE→FE contract from Step 4
- For MASTER_GRID/FLOW: generate the standard 7-file FE pipeline + 6 wiring updates
- For DASHBOARD: SKIP page-config / view-page / index-page / Zustand store / entity-operations. Generate only `{EntityName}DashboardDto.ts` + `{EntityName}DashboardQuery.ts` + (optional) new widget components in `custom-components/dashboards/widgets/` + register their `widgetCode` in `widget-registry.ts`. STATIC_DASHBOARD reuses the existing module dashboard route; MENU_DASHBOARD reaches the dashboard via the dynamic `[slug]/page.tsx` (built once when the first MENU_DASHBOARD ships). See `frontend-developer.md` § "DASHBOARD Screen Generation".
- For REPORT: standard FE if backed by entity; report-specific page if pure projection

**Step 6 — DB Seed Script (MANDATORY for every new screen)**
Generate the PostgreSQL seed script following `.claude/agents/backend-developer.md` DB Seed section.
Read existing scripts in `Services/Base/sql-scripts-dyanmic/` for exact pattern reference.

**Branch by `screen_type` from prompt frontmatter — different seed shapes per type.**

#### MASTER_GRID seed (default — entity CRUD)

1. auth.Menus — navigation menu entry with ParentMenuCode and ModuleCode subqueries
2. auth.RoleCapabilities — 7 capability rows (CapabilityId 1-7) for RoleId=1 (Admin)
3. sett.Grids — grid registration with GridCode and ModuleId
4. sett.Fields — one row per entity field (FieldCode=UPPERCASE, FieldKey=camelCase, DataType lookup)
5. sett.GridFields — CTE pattern mapping fields to grid (PK hidden, first 3 predefined, ISACTIVE last)
6. sett.Grids GridFormSchema — **GENERATE** (RJSF JSON Schema + uiSchema for modal form)

#### FLOW seed (entity CRUD with full-page view)

1-5. Same as MASTER_GRID
6. sett.Grids GridFormSchema — **SKIP** (full-page view-page handles forms; no modal RJSF needed)

#### DASHBOARD seed (read-only widget grid — NO entity CRUD)

> Read `dashboard_variant` from prompt frontmatter. STATIC_DASHBOARD vs MENU_DASHBOARD diverge in steps 1-2 and 5.

1. **auth.Menus** — **MENU_DASHBOARD ONLY**. Insert one menu row under `{MODULECODE}_DASHBOARDS` parent with `MenuCode={ENTITYUPPER}`, `MenuUrl={module}/dashboards/{kebab-slug}`, `OrderBy={N}`. STATIC_DASHBOARD does NOT seed a new menu — the module's existing `*_DASHBOARDS` parent already covers it.
2. **auth.MenuCapabilities + auth.RoleCapabilities** — **MENU_DASHBOARD ONLY**. Standard READ + EXPORT + ISMENURENDER caps; BUSINESSADMIN role grant. STATIC_DASHBOARD inherits from the parent menu — no new caps.
3. **sett.Widgets** — one row per widget type used by this dashboard (e.g., `KPI_TOTAL_DONATIONS`, `CHART_REVENUE_BY_MONTH`). Idempotent INSERT … WHERE NOT EXISTS by `WidgetCode`. Reuse if a widget type is already seeded for another dashboard.
4. **auth.WidgetRoles** — per role allowed to render each widget. At minimum `BUSINESSADMIN: HasAccess=true` for every widget seeded in step 3.
5. **sett.Dashboards** — the Dashboard row:
   - `DashboardCode={ENTITYUPPER}`, `DashboardName={Display}`, `DashboardIcon={ph:icon}`, `DashboardColor={hex|null}`
   - `ModuleId=(subquery on ModuleCode)`, `IsSystem=true`, `IsActive=true`
   - **STATIC_DASHBOARD**: `MenuId=NULL`, `MenuUrl=NULL`, `IsMenuVisible=false`, `OrderBy=999`
   - **MENU_DASHBOARD**: `MenuId=(subquery on MenuCode from step 1)`, `MenuUrl='{module}/dashboards/{kebab-slug}'`, `IsMenuVisible=true`, `OrderBy={N}`
6. **sett.DashboardLayouts** — one row, `DashboardId=(subquery on DashboardCode)`:
   - `LayoutConfig` = JSON for react-grid-layout breakpoints `{ "lg": [...], "md": [...], "sm": [...], "xs": [...] }`. Each entry: `{ i, x, y, w, h, minW, minH }`.
   - `ConfiguredWidget` = JSON array `[{ instanceId, widgetCode, title, configOverrides, dataSourceArgs }]`. Every `instanceId` must appear in LayoutConfig at every breakpoint used.
7. **GridFormSchema** — SKIP. Dashboards have no RJSF form.
8. **sett.Grids / sett.Fields / sett.GridFields** — SKIP. Dashboards have no entity grid.

**MENU_DASHBOARD first-time setup** — when this is the FIRST MENU_DASHBOARD prompt in the codebase, additionally include the schema/route infrastructure listed in `_DASHBOARD.md` template preamble (4 columns on `sett.Dashboards`, dynamic `[slug]/page.tsx` route, sidebar auto-injection, backfill seed for system dashboards). Subsequent MENU_DASHBOARD prompts skip this.

#### REPORT seed

1-5. Same as MASTER_GRID (filter panel uses Grid + Fields + GridFields for column config)
6. GridFormSchema — typically SKIP unless the report has a saved-filter modal

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
