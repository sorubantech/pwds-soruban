# Feature Specs

> Authoritative build specs for **shared infrastructure** (components, patterns, systems) that multiple screens depend on but aren't owned by any single screen.

---

## Why this folder exists

Screen specs (`.claude/screen-tracker/prompts/{entity}.md`) describe a single page. But some infrastructure is **shared** across many screens: a card-grid rendering system, a widget layout engine, a dashboard grid, a custom form control, etc. Putting that spec inside one screen's prompt file makes it invisible to every other screen that uses it. Losing it to a screen's Build Log makes it un-reviewable.

**Feature specs** solve that: each shared piece of infrastructure gets its own file here, with a full build spec that any screen can reference.

---

## File convention

```
.claude/feature-specs/
  README.md                ← this file
  card-grid.md             ← <CardGrid> + variant registry
  {future-feature}.md      ← one file per shared system
```

Frontmatter on each spec:

```yaml
---
name: {human-readable feature name}
status: NOT_BUILT | BUILT | PARTIAL | DEPRECATED
owner: {which agent owns the build — usually Frontend Developer or Backend Developer}
first_consumer: {which screen will build this first — e.g., "Screen #29 SMS Template"}
related_screens: [list of registry IDs that depend on it]
last_updated: YYYY-MM-DD
---
```

Body sections (suggested, not enforced):
1. Purpose — why this exists
2. Scope — in / out
3. Architecture — folder layout, key types
4. Implementations — component/function code sketches
5. Wiring — how it integrates with existing systems
6. Build order — who builds what, when
7. Responsive / accessibility / performance rules
8. Anti-patterns
9. Acceptance criteria (DoD)
10. Future extensions (parking lot)

---

## How feature specs are consumed

### When planning a screen (`/plan-screens #N`)

The BA / Solution Resolver / UX Architect pipeline checks if the screen's mockup implies a known feature (e.g., card-grid listing). If yes, the screen's prompt file includes a **reference** like:

> **Depends on feature: `card-grid` — see `.claude/feature-specs/card-grid.md`**

### When building a screen (`/build-screen #N`)

The Frontend / Backend Developer agent:
1. Reads the screen spec.
2. For each feature reference, reads the feature spec.
3. Checks the feature spec's `status`:
   - `NOT_BUILT` → this screen is the **first consumer**, so build the infra as part of this session (following the feature spec), then build the screen on top.
   - `PARTIAL` → read the spec to see what's already built, then add whatever variant/extension this screen needs.
   - `BUILT` → import and use the existing infrastructure. Do NOT re-create files that already exist.
4. After the session, update the feature spec's `status` and `last_updated`. Add a "First built by: ..." or "Extended by: Session #N on {date}" line where relevant.

### When continuing work on a screen (`/continue-screen #N`)

Read the feature spec if the fix touches feature-owned files. Do NOT change the feature's contract without discussion — a contract change ripples across every consumer screen.

---

## When to create a feature spec (vs. just building inside a screen)

Create a feature spec when **any two** of these are true:

- More than one screen will consume the same code.
- The infrastructure has a non-trivial surface (3+ files, a registry, or type declarations).
- Extension points exist (e.g., adding a new variant, handler, or mode).
- The wiring touches shared app-level files (`DataTableContainer`, `AppShell`, `routes`).

Do NOT create a feature spec for:

- One-off components owned by a single screen.
- Utilities that are small enough to live next to the screen that uses them (one file, no registry).
- Shadcn primitives or third-party wrappers already in place.

When in doubt: build inside the screen first. Extract to a feature spec the moment a second screen needs it.

---

## Current feature specs

| File | Status | First consumer | Summary |
|------|--------|----------------|---------|
| [card-grid.md](./card-grid.md) | `NOT_BUILT` | Screen #29 SMS Template | `displayMode: card-grid` rendering with variant registry (`details` / `profile` / `iframe`) |

---

## Relationship to other `.claude/` artifacts

| Artifact | What it holds | Example |
|----------|--------------|---------|
| `.claude/screen-tracker/prompts/{entity}.md` | Per-screen spec (one page, one entity) | `smstemplate.md` |
| `.claude/screen-tracker/REGISTRY.md` | All screens, their status, their metadata | — |
| `.claude/screen-tracker/DEPENDENCY-ORDER.md` | Build wave order based on FK deps | — |
| **`.claude/feature-specs/{feature}.md`** | **Per-feature spec (one shared system, many consumers)** | **`card-grid.md`** |
| `.claude/agents/{role}.md` | Role-level conventions the agent always follows | `frontend-developer.md` |
| `.claude/skills/{skill}/SKILL.md` | Workflow: how to run `/plan-screens`, `/build-screen`, etc. | `build-screen/SKILL.md` |

A feature spec is not a skill — you don't "run" it. An agent reads it while executing an existing skill.
