# PSS 2.0 — Screen Development Pipeline

> This document explains how screens are developed in PSS 2.0 using an AI-assisted pipeline.
> Written for anyone — developers, managers, or new team members — to understand the full process.

---

## What Are We Building?

PSS 2.0 (PeopleServe) is a multi-tenant SaaS platform for NGOs. It has **~77 screens** to build
across **6 modules**: CRM, Organization, Access Control, General, Setting, and Report & Audit.

Each screen is a complete feature — a page where users can view, search, create, edit,
and manage data (contacts, donations, memberships, volunteers, grants, etc.).

**Every screen produces:**
- Backend code (.NET 8 — entity, database config, business logic, GraphQL API)
- Frontend code (Next.js/React — page, grid, form, state management)
- Database seed (menu entry, grid columns, form schema, role permissions)

---

## The Pipeline — 3 Skills Working Together

```
 SKILL 1                  SKILL 2                  SKILL 3
 (You run this)           (You run this)           (Called automatically)
                                                    
┌──────────────┐ prompt  ┌──────────────┐ feeds   ┌──────────────────┐  code   ┌──────────┐
│  /plan-      │ ──────► │  /build-     │ ──────► │  /generate-      │ ──────► │  SCREEN  │
│  screens     │  file   │  screen      │  into   │  screen          │  files  │ COMPLETE │
│              │         │              │         │                  │         │    ✓     │
│  THE BRAIN   │         │ THE EXECUTOR │         │  THE DEV TEAM    │         └──────────┘
│  Analyzes    │         │ Reads prompt │         │  5 AI Agents     │
│  mockups &   │         │ validates    │         │  that write code │
│  prepares    │         │ dependencies │         │                  │
│  instructions│         │ then calls   │         │  BA Analyst      │
│              │         │ /generate-   │         │  Solution Resolver│
│              │         │ screen       │         │  UX Architect    │
│              │         │              │         │  Backend Dev     │
│              │         │              │         │  Frontend Dev    │
└──────────────┘         └──────────────┘         └──────────────────┘
   Session 1                Session 2               (runs inside Session 2)
   (analyze)                (generate)
```

**You only run 2 commands.** `/build-screen` calls `/generate-screen` internally.

```
  /plan-screens   →  Creates the prompt file (the WHAT)
  /build-screen   →  Reads prompt → calls /generate-screen → produces code (the HOW)
  /generate-screen →  The actual code generation engine (5 AI agents)
                      You never call this directly — /build-screen does it for you
```

---

## Step 1: PLAN — Analyze & Prepare (`/plan-screens`)

**What it does:** Reads the HTML mockup for a screen, studies the existing codebase,
and produces a detailed instruction document (prompt file) that tells the AI exactly
what code to generate.

**Run in a Claude session:**
```
/plan-screens          → Plans the next 5 screens (by dependency order)
/plan-screens 3        → Plans next 3 screens
/plan-screens #51      → Plans one specific screen
/plan-screens wave 1   → Plans all screens in Wave 1
```

**What happens inside:**

```
┌─────────────────────────────────────────────────────┐
│                   /plan-screens                      │
│                                                      │
│  1. Check Progress                                   │
│     └─ Review registry: what's done, what's next     │
│                                                      │
│  2. Pick Next Screen(s)                              │
│     └─ Follow dependency order (Wave 1 → 2 → 3 → 4) │
│     └─ Ensure prerequisite screens are built first   │
│                                                      │
│  3. Deep Analysis (per screen)                       │
│     ├─ Read HTML mockup                              │
│     │  └─ Extract: fields, columns, buttons,         │
│     │     widgets, dropdowns, layout sections         │
│     ├─ Read existing code (if any)                   │
│     │  └─ Identify what exists vs what's missing     │
│     ├─ Resolve foreign keys                          │
│     │  └─ Find exact file paths & GraphQL queries    │
│     ├─ Compute file paths                            │
│     │  └─ Pre-calculate every file to create         │
│     ├─ Look up menu structure                        │
│     │  └─ Get real menu codes, module, route         │
│     └─ Identify special needs                        │
│        └─ Widgets, aggregation columns,              │
│           service placeholders, new modules           │
│                                                      │
│  4. Generate Prompt File                             │
│     └─ 12-section structured document                │
│        (see "Prompt File Structure" below)            │
│                                                      │
│  5. Update Registry                                  │
│     └─ Screen status → PROMPT_READY                  │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Output:** A prompt file saved to `.claude/screen-tracker/prompts/{entity-name}.md`

---

## Step 2: BUILD — Execute & Generate Code (`/build-screen` → `/generate-screen`)

**`/build-screen`** is the executor. It reads the prompt file, validates dependencies,
and then hands everything over to **`/generate-screen`** — the actual development engine
with 5 AI agents that write all the code.

**You only run `/build-screen`.** It calls `/generate-screen` automatically.

**Run in a NEW Claude session (separate from planning):**
```
/build-screen          → Builds the next PROMPT_READY screen
/build-screen #51      → Builds a specific screen
/build-screen "Grant"  → Builds by screen name
```

**What happens inside:**

```
┌──────────────────────────────────────────────────────────────────┐
│                                                                   │
│  /build-screen  (THE EXECUTOR)                                    │
│                                                                   │
│  1. Find next PROMPT_READY screen from Registry                   │
│  2. Read the prompt file from prompts/{entity}.md                 │
│  3. Verify FK dependencies exist in codebase                      │
│  4. Check for new module needs                                    │
│                                                                   │
│  All checks passed? ──────────────────────────────────────────►  │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                                                             │  │
│  │  /generate-screen  (THE DEV TEAM — 5 AI Agents)            │  │
│  │                                                             │  │
│  │  PHASE 1: ANALYSIS  (3 agents — automated)                 │  │
│  │  ┌───────────────────────────────────────────────────┐     │  │
│  │  │                                                    │     │  │
│  │  │  Agent 1: BA Analyst                               │     │  │
│  │  │  └─ Validates business rules, fields, constraints  │     │  │
│  │  │           │                                        │     │  │
│  │  │           ▼                                        │     │  │
│  │  │  Agent 2: Solution Resolver                        │     │  │
│  │  │  └─ Classifies screen type, picks patterns         │     │  │
│  │  │           │                                        │     │  │
│  │  │           ▼                                        │     │  │
│  │  │  Agent 3: UX Architect                             │     │  │
│  │  │  └─ Designs layout, components, interactions       │     │  │
│  │  │                                                    │     │  │
│  │  └───────────────────────────────────────────────────┘     │  │
│  │           │                                                 │  │
│  │           ▼                                                 │  │
│  │  PHASE 2: YOUR APPROVAL  (human review — mandatory)        │  │
│  │  ┌───────────────────────────────────────────────────┐     │  │
│  │  │                                                    │     │  │
│  │  │  You see the implementation plan:                  │     │  │
│  │  │  • Menu name, code, module, route                  │     │  │
│  │  │  • Grid type (Master Grid or Flow)                 │     │  │
│  │  │  • Role permissions                                │     │  │
│  │  │  • Form schema settings                            │     │  │
│  │  │                                                    │     │  │
│  │  │  → Review it                                       │     │  │
│  │  │  → Adjust if needed                                │     │  │
│  │  │  → Approve to continue                             │     │  │
│  │  │                                                    │     │  │
│  │  └───────────────────────────────────────────────────┘     │  │
│  │           │                                                 │  │
│  │           ▼                                                 │  │
│  │  PHASE 3: CODE GENERATION  (2 agents + seed)               │  │
│  │  ┌───────────────────────────────────────────────────┐     │  │
│  │  │                                                    │     │  │
│  │  │  Agent 4: Backend Developer                        │     │  │
│  │  │  └─ Generates ~11 .NET files + 4 wiring updates    │     │  │
│  │  │           │                                        │     │  │
│  │  │           ▼                                        │     │  │
│  │  │  Agent 5: Frontend Developer                       │     │  │
│  │  │  └─ Generates ~9 React/TS files + 4 wiring updates │     │  │
│  │  │           │                                        │     │  │
│  │  │           ▼                                        │     │  │
│  │  │  DB Seed Script Generator                          │     │  │
│  │  │  └─ Menu, grid columns, form schema, permissions   │     │  │
│  │  │                                                    │     │  │
│  │  └───────────────────────────────────────────────────┘     │  │
│  │                                                             │  │
│  └────────────────────────────────────────────────────────────┘  │
│           │                                                       │
│           ▼                                                       │
│  PHASE 4: FULL TESTING  (end-to-end — mandatory)                 │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                                                             │  │
│  │  ✓ dotnet build — backend compiles                          │  │
│  │  ✓ pnpm dev — frontend page loads                           │  │
│  │  ✓ Create a record → appears in grid                        │  │
│  │  ✓ Edit a record → saves correctly                          │  │
│  │  ✓ Toggle active/inactive → badge changes                   │  │
│  │  ✓ Delete → removes from grid                               │  │
│  │  ✓ Search & filter → works                                  │  │
│  │  ✓ FK dropdowns → load data                                 │  │
│  │  ✓ Widgets → show values (if applicable)                    │  │
│  │  ✓ Menu → visible in sidebar                                │  │
│  │                                                             │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  PHASE 5: UPDATE TRACKING                                        │
│  └─ Update prompt file tasks → all checked                       │
│  └─ Update Registry → COMPLETED                                  │
│  └─ Present summary to user                                      │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### How the 3 skills relate:

```
  /plan-screens          /build-screen              /generate-screen
  ─────────────          ─────────────              ────────────────
  THE BRAIN              THE EXECUTOR               THE DEV TEAM
                                                    
  Reads mockups          Reads prompt file          Has 5 AI agents:
  Reads existing code    Checks dependencies         • BA Analyst
  Resolves FKs           Validates prerequisites     • Solution Resolver
  Computes file paths    Calls /generate-screen      • UX Architect
  Builds 12-section      Updates task progress       • Backend Developer
  prompt file            Updates registry            • Frontend Developer
                                                    
  OUTPUT:                INPUT:                     INPUT:
  Prompt file            Prompt file                Screen spec from
  (.md in prompts/)      from /plan-screens         /build-screen
                                                    
  YOU RUN THIS           YOU RUN THIS               AUTO-CALLED
  in Session 1           in Session 2               by /build-screen
```

---

## What Each Screen Produces

```
 BACKEND (11 files)               FRONTEND (9 files)            DB SEED (1 file)
 ─────────────────                ──────────────────            ────────────────
 Entity model (.cs)               DTO types (.ts)               Menu entry
 EF Configuration (.cs)           GraphQL queries (.ts)         Grid column config
 DTOs / Schemas (.cs)             GraphQL mutations (.ts)       Form schema (RJSF)
 Create command (.cs)             Page config (.tsx)             Role permissions
 Update command (.cs)             Index page (.tsx)
 Delete command (.cs)             Index component (.tsx)
 Toggle command (.cs)             View page (.tsx)        ← Flow screens only
 GetAll query (.cs)               Zustand store (.ts)     ← Flow screens only
 GetById query (.cs)              Route page (.tsx)
 GraphQL Mutations (.cs)
 GraphQL Queries (.cs)

 + Summary query (.cs)            + Widget cards (.tsx)    ← If screen has count cards
 + Aggregation columns            + Computed columns       ← If grid has per-row totals
                                  + Placeholder buttons    ← If screen has service actions
                                                              (SMS, WhatsApp, etc. — UI only)
```

**Per screen total:** ~20 new files + ~8 wiring updates + 1 SQL seed script

---

## Build Order (Waves)

Screens are built in dependency order — you can't build a screen that references
another screen's data until that other screen exists.

```
  WAVE 1 — Setup & Foundation          (screens with no dependencies)
  ──────────────────────────
  Region, Country, State, Masters, Document Types, basic settings
  These are simple reference data screens that everything else depends on.


  WAVE 2 — Core Entities                (depend on Wave 1)
  ────────────────────
  Contact, Family, Staff, Company, Branch, Users, Roles
  The main people and organization screens.


  WAVE 3 — Business Operations          (depend on Wave 1 + 2)
  ────────────────────────
  Donation, Membership, Volunteer, Events, Communication
  The day-to-day operational screens for NGO activities.


  WAVE 4 — Advanced Features            (depend on Wave 1 + 2 + 3)
  ──────────────────────
  Grant Management, Case Management, Campaigns, Reports
  Complex screens with workflows, multiple FKs, and child entities.


  WAVE 5 — Alignment                    (existing screens needing updates)
  ──────────────────
  Screens that have some code but need alignment with HTML mockups.
  Gap analysis: what exists vs. what the mockup shows.
```

---

## Screen Types — Two Patterns

Every screen follows one of two patterns:

### Master Grid (Simple CRUD)
```
┌──────────────────────────────────────────┐
│  [+ Add]  [Search: ________]  [Filter ▼] │
├──────────────────────────────────────────┤
│  Code  │  Name  │  Status │  Actions     │
│  T001  │  Type1 │ Active  │  ✏️ 🔄 🗑️    │
│  T002  │  Type2 │ Inactive│  ✏️ 🔄 🗑️    │
├──────────────────────────────────────────┤
│  Page 1 of 5                             │
└──────────────────────────────────────────┘

  Click "+Add" or "Edit" → Modal popup with form → Save → Grid refreshes
```
Best for: Settings, reference data, simple entities (e.g., Contact Type, Region)

### Flow Grid (Complex CRUD with View Page)
```
┌──────────────────────────────────────────┐
│  [+ Add]  [Search: ________]  [Filter ▼] │
├──────────────────────────────────────────┤
│  Code │  Name    │  Amount  │  Status    │
│  G001 │  Grant 1 │  $5,000  │  Draft     │
│  G002 │  Grant 2 │  $12,000 │  Approved  │
└──────────────────────────────────────────┘

  Click "+Add" → Navigates to a full view/edit page:

┌──────────────────────────────────────────┐
│  ← Back to List       [Edit] [Save]      │
├──────────────────────────────────────────┤
│  Basic Info            Details            │
│  ┌──────────────┐    ┌──────────────┐   │
│  │ Code: G003   │    │ Amount: ___  │   │
│  │ Name: ____   │    │ Status: ___  │   │
│  │ Contact: [▼] │    │ Start: 📅   │   │
│  └──────────────┘    └──────────────┘   │
│                                          │
│  Child Records                           │
│  ┌──────────────────────────────────┐   │
│  │  Item 1  │  $500   │  Edit  Del  │   │
│  │  Item 2  │  $1,000 │  Edit  Del  │   │
│  └──────────────────────────────────┘   │
└──────────────────────────────────────────┘
```
Best for: Complex entities with child records, workflows, multiple sections
(e.g., Grant Application, Case, Donation, Membership)

---

## Special Screen Elements

### Summary Cards / Count Widgets
Some screens show stat cards above the grid:
```
┌───────────┐  ┌───────────┐  ┌───────────┐
│ Total: 156 │  │ Active: 98│  │ Pending: 12│
└───────────┘  └───────────┘  └───────────┘
┌──────────────────────────────────────────┐
│  Grid data below...                      │
```
These are fully implemented — including the backend summary query.

### Aggregation Columns
Some grid columns show per-row computed values:
```
│  Contact  │  Total Donations │  Member Since │  Last Activity │
│  John     │  $12,500         │  2 years      │  2024-03-15    │
│  Jane     │  $8,200          │  5 years      │  2024-03-10    │
```
"Total Donations" is calculated from the Donations table for each contact row.
Implemented via database queries (LINQ or PostgreSQL functions).

### Service Placeholder Buttons
Some screens have action buttons for services not yet built (SMS, WhatsApp, etc.):
```
│  Campaign  │  Status  │  Actions                        │
│  Camp 1    │  Draft   │  ✏️  📱 Send SMS  💬 WhatsApp   │
```
The buttons are fully implemented in the UI, but clicking them shows a
"Feature coming soon" message. Backend service integration happens in a later phase.

---

## Tracking & Status

All progress is tracked in `.claude/screen-tracker/REGISTRY.md`:

```
Status Flow:

  NEW / PARTIAL                Where every screen starts
       │
       ▼
  PROMPT_READY                 /plan-screens analyzed it, prompt file ready
       │
       ▼
  IN_PROGRESS                  /build-screen is generating code
       │
       ├──► COMPLETED          All code generated, tested, working
       │
       └──► PARTIALLY_COMPLETED   Interrupted — can resume with /build-screen
```

Each screen also has a task checklist inside its prompt file that tracks
exactly which steps are done.

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Backend | .NET 8, C# | Server-side logic |
| Architecture | Clean Architecture, CQRS, MediatR | Code organization |
| API | GraphQL (HotChocolate) | Data exchange |
| Database | PostgreSQL, EF Core | Data storage |
| Frontend | Next.js 14, React 18, TypeScript | User interface |
| State | Apollo Client, Zustand | Data & UI state |
| UI Components | Shadcn/Radix UI, TanStack Table | Grids, forms, buttons |
| Forms | RJSF (Master Grid), React Hook Form (Flow) | Form rendering |

---

## Key Numbers

| Metric | Value |
|--------|-------|
| Total screens | ~77 actionable |
| Modules | 6 |
| Files per screen | ~20 new + ~8 wiring updates |
| Build time per screen | ~20-40 minutes (AI-assisted) |
| Screens per day (estimate) | 5-10 depending on complexity |
| AI agents in pipeline | 5 (BA, Solution Resolver, UX, Backend Dev, Frontend Dev) |
