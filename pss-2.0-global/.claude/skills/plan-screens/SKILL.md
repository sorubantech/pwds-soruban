---
name: plan-screens
description: /plan-screens — Deep Screen Analyst & Prompt Builder
---

# /plan-screens — Deep Screen Analyst & Prompt Builder

> Reads HTML mockups, analyzes existing code, and produces **rich, execution-ready screen prompts** 
> that can be directly fed into `/generate-screen` (via `/build-screen`).
> This is the **brain** — it does ALL the analysis work so the generation pipeline gets quality input.

---

## Required Reading (load before starting)

- `.claude/screen-tracker/REGISTRY.md` — Master tracking file
- `.claude/screen-tracker/DEPENDENCY-ORDER.md` — Build sequence (wave order, FK deps)
- `.claude/screen-tracker/MODULE_MENU_REFERENCE.md` — Real module/menu codes and FE routes
- `.claude/screen-tracker/prompts/_TEMPLATE.md` — Router / index explaining template selection
- `.claude/screen-tracker/prompts/_COMMON.md` — Shared section conventions (for consistency)
- **Type-specific template** (load ONE based on detected `screen_type`):
  - `_MASTER_GRID.md` — grid + modal RJSF form
  - `_FLOW.md` — grid + 3-mode view-page (new/edit/read) with 2 UI layouts
  - `_DASHBOARD.md` — widget grid + KPI cards + charts (stub)
  - `_REPORT.md` — filter panel + result view + export (stub)
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
- **Layout Variant** — stamp in Section ⑥ as `grid-only` | `widgets-above-grid` | `side-panel` | `widgets-above-grid+side-panel`. If the mockup shows any widget/card/panel ABOVE or BESIDE the grid, it is NOT `grid-only`. This drives FE Dev's Variant A vs Variant B decision (ScreenHeader + showHeader=false). Missing stamp → double-header UI bug (ContactType #19 precedent).
- **Grid aggregation columns** (per-row computed values like totals, counts, last-activity)
- **Service action buttons** (Send SMS, Send WhatsApp, Generate PDF, etc.) — capture the UI element but flag as SERVICE_PLACEHOLDER

**CRITICAL for FLOW screens — Extract the FULL form design:**
FLOW screens open a form page when "+Add" is clicked (URL → `?mode=new`).
This form is NOT a simple modal — it's a full page (`view-page.tsx`) that must match the mockup exactly.
Extract ALL of these from the HTML mockup:
- Section container type (cards, accordion, tabs) and their order
- Section icons (fa-icons), titles, column layouts (2-col, 3-col, full-width)
- Collapsed vs expanded default state for each section
- **Card selectors** (visual card options like payment modes)
- **Conditional sub-forms** (fields that appear based on a selection — e.g., payment mode → different fields)
- **Inline mini displays** (e.g., donor card that appears when a contact is selected)
- **Child grids within the form** (e.g., distribution rows with add/remove)
- **Computed/readonly fields** (e.g., net amount = amount - fee)
- **Detail/View page layout** (if mockup has a separate read-only 2-column view)
- **Header actions** in read mode (Edit, Print, Send, More dropdown)

**FLOW screens have 2 different UI layouts — extract BOTH from mockup:**
- **FORM LAYOUT** (`?mode=new` and `?mode=edit&id=X`) — the add/edit form with sections, accordions, cards
- **DETAIL LAYOUT** (`?mode=read&id=X`) — the read-only view, often a multi-column page with info cards, history, audit trail — this is a DIFFERENT UI from the form, not just the form disabled

Both go into Section ⑥ as "LAYOUT 1: FORM" and "LAYOUT 2: DETAIL".
If the mockup doesn't have a separate detail view, note: "No separate detail layout — use form with disabled fields."

If this extraction is vague, the FE developer agent WILL generate a generic flat form.
This is the #1 cause of FLOW screen failures — the form not matching the mockup.

#### 2a-bis. Detect Screen Type & Select Template

Based on what the mockup shows, classify the screen and load the matching template file. Each template is standalone and complete — load only the one you need.

| Mockup Pattern | `screen_type` | Template to Load |
|----------------|---------------|------------------|
| Grid list + **modal popup form** for add/edit | `MASTER_GRID` | `.claude/screen-tracker/prompts/_MASTER_GRID.md` |
| Grid list + **full-page view** with `?mode=new/edit/read` (URL changes on +Add) | `FLOW` | `.claude/screen-tracker/prompts/_FLOW.md` |
| **Widget grid** with KPI cards, charts, drill-downs, no CRUD | `DASHBOARD` | `.claude/screen-tracker/prompts/_DASHBOARD.md` |
| **Filter panel** + result table/chart + **export** actions | `REPORT` | `.claude/screen-tracker/prompts/_REPORT.md` |

**Detection cues:**
- If "+Add" opens a modal/dialog in the mockup → `MASTER_GRID`
- If "+Add" navigates to a new page or URL changes to `?mode=new` → `FLOW`
- If the primary UI is KPI cards + charts (no dominant grid) → `DASHBOARD`
- If the primary UI is a filter panel with a "Generate" button and export → `REPORT`
- When in doubt between MASTER_GRID and FLOW: workflow/transactional entities (Donations, Grants, Cases) → FLOW; setup/config entities (ContactType, Branch, Role) → MASTER_GRID.

Load only the selected template. Do NOT load the other three — this is the primary token optimization of the split template design.

If you detect a pattern that doesn't fit the four types, use `_COMMON.md` as reference and write the prompt with the closest-fit template, noting the divergence in Section ⑫.

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

#### 2h. Scope Discipline — Build Everything in the Mockup

**GOLDEN RULE**: Every UI element shown in the HTML mockup is in scope. Build it.

For each interactive element, reason about what its implementation needs:

- If it only needs **UI components + database reads/writes + client-side navigation** → it's regular scope. Build the full feature (UI + backend query/mutation + wiring).
- If it needs an **external service or integration that isn't already in the codebase** (check before deciding — don't assume) → mark as `SERVICE_PLACEHOLDER`. Build the full UI, but wire the handler to a mock/toast. Note the missing service in **Section ⑫**.

How to decide if something is a SERVICE_PLACEHOLDER:
1. Identify what the action actually does at the backend boundary (send a message? generate a file? call a third-party API? persist a record? fetch related data?).
2. Check whether the required service/infrastructure already exists in the codebase.
3. If yes → build it end-to-end. If no → UI-only with placeholder handler.

Default stance: **assume it's buildable**. Only mark as placeholder when you can name the specific missing service layer.

**ALIGN scope**: ALIGN means "match the mockup." If the mockup shows a feature the existing code lacks, it's in scope. ALIGN only avoids recreating files that already exist correctly — it does NOT mean deferring features.

List only genuine service-dependency items in **Section ⑫**. Everything else in the mockup goes into Sections ⑥ and ⑧.

---

### Step 3: Generate Prompt File (12-section structure)

For each screen, generate the prompt file by filling in the **type-specific template** selected in Step 2a-bis (`_MASTER_GRID.md`, `_FLOW.md`, `_DASHBOARD.md`, or `_REPORT.md`). All four templates share the same 12-section skeleton — sections ⑤ and ⑥ differ per type.

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
13. **Build everything in the mockup (GOLDEN RULE)** — Info panels, side panels, click-through navigation, drag-reorder UI, tabs, accordions, related-data panels are ALL in scope. The ONLY exception is SERVICE_PLACEHOLDER for external services (SMS/WhatsApp/PDF/payment gateway). Never mark legitimate UI as "out of scope for this phase."
14. **ALIGN ≠ do less** — ALIGN means "match the mockup." If the mockup shows something the existing code doesn't have, that goes into the build scope. ALIGN only skips recreating files that already exist correctly.

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

---

## Token Optimization Directives (MANDATORY)

### Model selection — 3 tiers per task class

`/plan-screens` is research-heavy, not code-generation. Use the lightest model that does the job:

| Subagent task | Model | `Agent({ model: "..." })` |
|--------------|-------|---------------------------|
| FK target lookup (glob + single grep per FK) | **Haiku** | `"haiku"` |
| File-existence / path-resolution checks | **Haiku** | `"haiku"` |
| HTML mockup analysis / field extraction | **Sonnet** | `"sonnet"` |
| Existing-code reading for ALIGN screens (diff mockup vs code) | **Sonnet** | `"sonnet"` |
| Module/menu code lookup in MODULE_MENU_REFERENCE.md | **Haiku** | `"haiku"` |
| Multi-source research combining 3+ files | **Sonnet** | `"sonnet"` |

**Main session**: run on **Sonnet** for planning. Before starting a `/plan-screens` session, the user (or Claude Code) should set `/model sonnet`. Opus is overkill for reading mockups, filling template values, and computing file manifests.

**Rule**: never spawn an Opus-tier subagent inside `/plan-screens`. If a task feels like it needs Opus judgment, that work belongs in `/build-screen`, not here.

**Anti-waste tactics**:
- Don't spawn a subagent for a single grep — main context can do it faster and cheaper.
- Batch related file reads in ONE Explore agent call, not N separate Agent calls.
- Pass only the section the subagent needs, not the entire prompt file.

### Other directives

1. **Role**: Use only `BUSINESSADMIN` in all approval config blocks. Do not enumerate all 7 roles.

2. **Permissions**: Assume standing read/write access. Do NOT prompt the user for permissions when reading project files.

3. **Avoid full builds**: Do not run `dotnet build` or `pnpm build` during planning. Planning is analysis-only.

4. **FLOW form detail is critical** — Section ⑥ (Form Layout) must describe the mockup form with enough detail that the FE developer agent can implement it without re-reading the HTML mockup. Include: section titles, icons, column layouts, field types, conditional sub-forms, child grids, card selectors, computed fields. This section is the PRIMARY input for form generation — if it's vague, the form won't match the mockup.
