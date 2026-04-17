# Screen Prompt — Shared Conventions

> Reference doc describing sections that are **common across all screen types**
> (MASTER_GRID, FLOW, DASHBOARD, REPORT). The four type-specific templates
> (`_MASTER_GRID.md`, `_FLOW.md`, `_DASHBOARD.md`, `_REPORT.md`) follow these
> conventions — this file is the single source of truth for the shared parts.
>
> **Not loaded by `/plan-screens` directly** — it's a reference for humans and
> for keeping the type-specific templates consistent.

---

## Which template to pick

| If the screen is… | Use |
|-------------------|-----|
| Grid list + **modal popup form** for add/edit | `_MASTER_GRID.md` |
| Grid list + **full-page view** with `?mode=new / edit / read` | `_FLOW.md` |
| **Widget grid** with KPIs, charts, drill-downs, no CRUD | `_DASHBOARD.md` |
| **Parameterized query** with filter panel + result view + export | `_REPORT.md` |

Pick by what the mockup **shows**, not by the entity name. Some modules mix types — a single "Donations" module can have a FLOW screen (GlobalDonation), a DASHBOARD (Donation Overview), and a REPORT (Monthly Donation Report).

---

## Section structure (same across all templates)

All four type-specific templates follow the 12-section structure:

| # | Section | Shared / Type-specific |
|---|---------|-----------------------|
| ① | Screen Identity & Context | **Shared** format |
| ② | Entity Definition | **Shared** format (Dashboards/Reports often "no entity") |
| ③ | FK Resolution Table | **Shared** format |
| ④ | Business Rules & Validation | **Shared** format |
| ⑤ | Screen Classification & Pattern Selection | **Type-specific** (CRUD vs widgets vs report) |
| ⑥ | UI/UX Blueprint | **Type-specific** (the main differentiator) |
| ⑦ | Substitution Guide | **Shared** format — canonical ref differs per type |
| ⑧ | File Manifest | **Shared** format — file list differs per type |
| ⑨ | Pre-Filled Approval Config | **Shared** format |
| ⑩ | Expected BE→FE Contract | **Shared** format |
| ⑪ | Acceptance Criteria | **Shared** format — verification steps differ per type |
| ⑫ | Special Notes & Warnings | **Shared** format |

---

## Conventions for shared sections

### § Frontmatter

Every prompt file starts with:

```yaml
---
screen: {EntityName}
registry_id: {#}
module: {Module Name}
status: PENDING
scope: {FULL | BE_ONLY | FE_ONLY | ALIGN}
screen_type: {MASTER_GRID | FLOW | DASHBOARD | REPORT}
complexity: {Low | Medium | High}
new_module: {YES — schema name | NO}
planned_date: {YYYY-MM-DD}
completed_date:
---
```

### § Tasks checklist

Three groups: Planning (all `[x]` when file is generated), Generation (all `[ ]`), Verification (all `[ ]` — full E2E required).

### § Section ① — Identity

3-5 sentences of business context. What / who / why / how-it-relates.

### § Section ② — Entity

Standard table format. Skip audit columns (CreatedBy/CreatedDate/etc. are inherited). For FLOW screens, **CompanyId is NOT a field** — it comes from HttpContext.

### § Section ③ — FK Resolution

Every FK must have: target entity name, entity file path, GQL query name, display field, response DTO type. Resolved by glob + grep — not guessed.

### § Section ④ — Business Rules

Four buckets: Uniqueness / Required / Conditional / Business Logic. Plus Workflow if state machine exists.

### § Section ⑦ — Substitution Guide

Maps the canonical reference entity to the new entity across name casings, schema, group, menu codes, FE routes. Canonical per type:

- MASTER_GRID → `ContactType`
- FLOW → `SavedFilter`
- DASHBOARD → TBD (first dashboard sets the convention)
- REPORT → TBD (first report sets the convention)

### § Section ⑧ — File Manifest

File counts differ per type:

| Type | Backend | Frontend | Notes |
|------|---------|----------|-------|
| MASTER_GRID | 11 CRUD files | 6 FE files | No view-page, no Zustand store |
| FLOW | 11 CRUD files + workflow | 9 FE files | view-page (3 modes) + Zustand store |
| DASHBOARD | 2-3 (DTO + aggregate query) | 4-5 (dashboard page + widget components) | No CRUD |
| REPORT | 2-4 (DTO + query + exporters) | 4-6 (filter panel + result view) | No CRUD |

### § Section ⑨ — Approval Config

Pre-filled CONFIG block. Use BUSINESSADMIN role only (see feedback memory). GridType matches `screen_type`.

| screen_type | GridType | GridFormSchema |
|-------------|----------|----------------|
| MASTER_GRID | MASTER_GRID | GENERATE |
| FLOW | FLOW | SKIP |
| DASHBOARD | DASHBOARD | SKIP |
| REPORT | REPORT | SKIP |

### § Section ⑩ — BE→FE Contract

Pre-defines GQL query/mutation names, argument shapes, response DTO fields. Shared naming: `GetAll{Entity}List`, `Get{Entity}ById`, `Create/Update/Delete/Toggle{Entity}`. Optional extras per type:

- `Get{Entity}Summary` (MASTER_GRID / FLOW with widgets)
- `Get{Entity}Dashboard` (DASHBOARD)
- `Get{Entity}Report`, `Export{Entity}Report` (REPORT)

### § Section ⑪ — Acceptance Criteria

Full E2E — always. Build verification + functional verification + DB seed verification. Each template has type-specific checks (modal form vs 3 URL modes vs widgets vs filter/export).

### § Section ⑫ — Special Notes & Warnings

- Module-level gotchas (new schema, existing FE routes, FK group mismatches)
- ALIGN-scope caveats
- Service Dependencies: only list items that need an external service missing from the codebase. Everything else in the mockup is in scope.

---

## Golden rules (applies to all templates)

1. **Build everything in the mockup** — every UI element is in scope. Mark `SERVICE_PLACEHOLDER` only when a specific backend service/infrastructure is genuinely missing.
2. **FK targets must be resolved** — glob + grep for entity path and GQL query name.
3. **File manifest must be exact** — no guessing paths.
4. **Approval config pre-filled** — user reviews, not fills from scratch.
5. **Every section actionable** — if a sub-session reads it, they should be able to code immediately.

---

## Adding a new screen type

When a new screen type emerges (e.g., `WIZARD`, `KANBAN`):

1. Copy `_MASTER_GRID.md` as starting point.
2. Adjust §5 (classification) and §6 (UI/UX blueprint) for the new pattern.
3. Adjust §8 file manifest (what files the new pattern needs).
4. Adjust §11 verification steps.
5. Add the new type to this file's "Which template to pick" table.
6. Update `/plan-screens` detection logic to recognize the new type.
