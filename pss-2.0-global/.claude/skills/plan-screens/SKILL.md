# /plan-screens — Deep Screen Analyst & Prompt Builder

> Reads HTML mockups, analyzes existing code, and produces **rich, execution-ready screen prompts** 
> that can be directly fed into `/generate-screen` (via `/build-screen`).
> This is the **brain** — it does ALL the analysis work so the generation pipeline gets quality input.

---

## Required Reading (load before starting)

- `.claude/screen-tracker/REGISTRY.md` — Master tracking file
- `.claude/screen-tracker/DEPENDENCY-ORDER.md` — Build sequence (wave order, FK deps)
- `.claude/screen-tracker/MODULE_MENU_REFERENCE.md` — Real module/menu codes and FE routes
- `.claude/screen-tracker/prompts/_TEMPLATE.md` — **Output format** (12-section structure)
- `.claude/business.md` — Application business context (NGO SaaS platform)

---

## Input

```
/plan-screens                    → Plan next 5 screens by dependency order
/plan-screens 3                  → Plan next 3 screens
/plan-screens #51                → Plan specific screen by registry number
/plan-screens "Membership Tier"  → Plan specific screen by name
/plan-screens wave 1             → Plan all screens in Wave 1
/plan-screens review 5           → Plan next 5 existing-code screens for alignment
```

---

## Execution Flow

### Step 0: Review Last Completed Work (ALWAYS do this first)

Before planning new screens, check the current state:

1. Read `.claude/screen-tracker/REGISTRY.md`
2. Scan for screens with status `COMPLETED` — note the last completed screen
3. Scan for screens with status `IN_PROGRESS` or `PARTIALLY_COMPLETED` — these need attention first
4. Scan for screens with status `PROMPT_READY` — these are already planned, ready for `/build-screen`
5. Present a brief status summary:
   ```
   ## Current Progress
   - Last completed: #{id} {ScreenName} (completed on {date})
   - In progress: #{id} {ScreenName} (tasks: {X}/{Y} done)
   - Queued (PROMPT_READY): {N} screens
   - Remaining to plan: {N} screens
   ```
6. If there are `IN_PROGRESS` or `PARTIALLY_COMPLETED` screens, warn the user — these should be finished via `/build-screen` before planning more
7. If there are already `PROMPT_READY` screens waiting, ask if user wants to plan more or build existing ones first

---

### Step 1: Identify Next Screens to Plan

1. Read `.claude/screen-tracker/DEPENDENCY-ORDER.md`
2. Read `.claude/screen-tracker/MODULE_MENU_REFERENCE.md` — for correct menu codes and FE routes
3. Identify eligible screens by status: `PARTIAL`, `NEW`
4. Filter by requested scope (next N, specific screen, wave, or "review")
5. Verify dependency order — FK targets must exist first (check COMPLETED or has existing BE entity)
6. If no eligible screens, inform user and stop

**Priority order** (default): P1 → P2 → P3 → P4 → P5 (existing-code alignment last unless explicitly requested)

---

### Step 2: Deep Analysis (per screen)

This is the core work. For each screen, gather everything needed to fill all 12 sections of the prompt template.

#### 2a. Read HTML Mockup (MANDATORY)

Read mockup file(s) from `html_mockup_screens/` (path from REGISTRY.md).

**Extract:**
- Screen title, all form fields (name, type, required, placeholder)
- Field groupings/sections, dropdown fields (FK refs)
- Grid columns with display order
- Action buttons, tabs, status badges, workflow indicators
- Search/filter fields, child grids, file uploads, conditional visibility
- **Summary cards / count widgets** above the grid (titles, value types, positions)
- **Grid aggregation columns** (per-row computed values like totals, counts, last-activity)
- **Service action buttons** (Send SMS, Send WhatsApp, Generate PDF, etc.) — capture the UI element but flag as SERVICE_PLACEHOLDER

#### 2b. Read Existing Code (by sub-type in Notes column)

**PARTIAL (FE_STUB)**: Read FE route page.tsx → note routing path
**PARTIAL (BE_ONLY)**: Read entity, schemas, mutations, queries → note exact field names, GQL types
**PARTIAL (CODE_EXISTS)**: Read BOTH BE entity + FE component → diff against mockup → identify gaps
**NEW**: Skip — nothing to read

#### 2c. Resolve FK Targets (CRITICAL — don't skip)

For EVERY FK relationship found in the mockup:
1. **Glob** for the FK entity file: `Base.Domain/Models/*/{FKEntity}.cs`
2. Note the exact file path, group name, namespace
3. **Grep** for the GQL query name: `GetAll{FKEntity}List` in API/EndPoints
4. Note the display field (usually `{FKEntity}Name`)
5. Note the response DTO type name

This fills **Section ③ (FK Resolution Table)** — the most commonly missing information.

#### 2d. Compute File Manifest

Based on screen type (MASTER_GRID or FLOW) and scope, pre-compute:
1. All backend file paths using the group/schema naming
2. All frontend file paths using the feFolder/entityLower naming
3. All wiring files that need modification
4. Which code reference template to follow (SavedFilter for FLOW, ContactType for MASTER_GRID)

This fills **Section ⑧ (File Manifest)**.

#### 2e. Build Substitution Table

Map the canonical reference entity to this entity:
- Entity name variations (PascalCase, camelCase, kebab-case, UPPER_CASE)
- Schema, group, module names
- Parent menu code, module code
- FE route path

This fills **Section ⑦ (Substitution Guide)**.

#### 2f. Pre-fill Approval Config (use MODULE_MENU_REFERENCE.md)

Look up the screen in `MODULE_MENU_REFERENCE.md` to get the **exact** values:
- MenuCode (e.g., `GRANTLIST`, `MEMBERSHIPTIER`)
- ParentMenuCode (e.g., `CRM_GRANT`, `CRM_MEMBERSHIP`)
- ModuleCode (e.g., `CRM`, `SETTING`, `ORGANIZATION`)
- MenuUrl (e.g., `crm/grant/grantlist`, `setting/document/documenttype`)
- Default capabilities per role
- GridType, GridFormSchema (GENERATE for MASTER_GRID, SKIP for FLOW)

**CRITICAL**: Use the REAL menu codes from the SQL reference, not guessed values.

This fills **Section ⑨ (Approval Config)**.

#### 2g. Define BE→FE Contract

Pre-define:
- GraphQL query/mutation type names
- GQL field names (GetAll, GetById, Create, Update, Delete, Toggle)
- **Summary query** (Get{Entity}Summary) — if mockup has count widgets / summary cards
- Response DTO field list with TypeScript types
- Summary DTO field list (if widgets exist)

This fills **Section ⑩ (BE→FE Contract)**.

#### 2h. Identify Service Placeholders

For screens that have action buttons tied to external services (Send SMS, Send WhatsApp, Generate PDF, etc.):
- Capture the UI element (button name, position, trigger context)
- Flag as `SERVICE_PLACEHOLDER` — UI must be implemented, but handler should use a placeholder/mock
- DO NOT plan backend service implementation — that's a separate phase
- List all placeholders in **Section ⑫ (Special Notes)**

---

### Step 3: Generate Prompt File (12-section structure)

For each screen, generate the prompt file following `_TEMPLATE.md` exactly:

| Section | What /plan-screens fills in |
|---------|---------------------------|
| ① Identity & Context | From mockup title + business.md context |
| ② Entity Definition | From mockup fields + existing entity (if BE exists) |
| ③ FK Resolution | From Step 2c — glob/grep results for each FK |
| ④ Business Rules | From mockup analysis + field constraints |
| ⑤ Classification | Screen type + pattern checklist (pre-answered for Solution Resolver) |
| ⑥ UI/UX Blueprint | From mockup — grid columns, form layout, widget mappings, summary cards, grid aggregations |
| ⑦ Substitution Guide | From Step 2e — canonical → this entity |
| ⑧ File Manifest | From Step 2d — exact paths |
| ⑨ Approval Config | From Step 2f — pre-filled CONFIG block |
| ⑩ BE→FE Contract | From Step 2g — GQL types and DTO fields |
| ⑪ Acceptance Criteria | Generated from field list + business rules |
| ⑫ Special Notes | New module warnings, ALIGN notes, gotchas |

Save to: `.claude/screen-tracker/prompts/{entity-lower}.md`

---

### Step 4: Update Registry

1. Update REGISTRY.md: Status → `PROMPT_READY`, Prompt → `prompts/{entity-lower}.md`
2. Update Summary counts

---

### Step 5: Present Summary

```markdown
## Planned {N} Screens

| # | Screen | Module | Type | Scope | Complexity | Prompt File |
|---|--------|--------|------|-------|------------|-------------|
| {id} | {name} | {module} | {type} | {scope} | {complexity} | prompts/{file}.md |

### Key Findings
- {Notable business rules or complexity}
- {New modules needed}
- {Dependency warnings}
- {For CODE_EXISTS screens: gaps found}

### Next Steps
- Review prompt files → adjust if needed
- Run `/build-screen` to build the first PROMPT_READY screen
- Run `/build-screen #{id}` for a specific screen
- Run `/plan-screens` for the next batch
```

---

## Rules

1. **Always read the HTML mockup** — never guess fields or layout
2. **Always resolve FK targets** — glob/grep for each FK entity path and GQL query name
3. **Always compute file manifest** — no guessing paths
4. **Always pre-fill approval config** — user should review, not fill from scratch
5. **For PARTIAL/REVIEW screens, read existing code** — understand current state
6. **Never plan if FK dependencies don't exist** — check DEPENDENCY-ORDER.md
7. **One prompt file per screen** — even if multiple HTML files map to it
8. **Max 10 screens per plan session** — default 5
9. **Mockup fields are UX truth** — if mockup shows fields not in existing code, they're new
10. **Skip audit columns** — CreatedBy, CreatedDate, etc. are inherited
11. **CODE_EXISTS screens = gap analysis** — describe changes needed, not full regeneration
12. **Every section must be actionable** — if a sub-session reads it, they should be able to code immediately

---

## Deep Read Strategy by Status

### PARTIAL (FE_STUB — FE route exists, no BE)
```
Read: src/app/[lang]/{route}/page.tsx → note routing path
Skip: No BE to read
Scope: FULL
Special Note: "Existing FE route at {path} — FE dev must use this path"
```

### PARTIAL (BE_ONLY — BE entity exists, no FE)
```
Read: Entity, Schemas, Mutations, Queries → get exact fields, GQL types
Skip: No FE to read
Scope: FE_ONLY
Special Note: "BE→FE Contract is from REAL code, not estimated"
```

### PARTIAL (CODE_EXISTS — both exist, needs mockup alignment)
```
Read: HTML mockup → target state
Read: BE entity + DTOs → current BE fields
Read: FE component → current FE implementation
Diff: mockup vs reality
Scope: ALIGN
Special Note: "Only modify what's different — don't regenerate"
Section ⑫: List specific changes (add field X, change layout Y, add feature Z)
```

### NEW (nothing exists)
```
Read: HTML mockup only
Scope: FULL
Special Note: "No existing code — generate everything from scratch"
```
