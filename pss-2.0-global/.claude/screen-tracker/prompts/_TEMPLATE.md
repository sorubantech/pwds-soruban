# Screen Prompt Templates — Router

> **This file is an INDEX**, not a template.
> Pick the right type-specific template based on the screen's `screen_type`.
>
> Splitting per type keeps each template focused and avoids bloating screens with
> irrelevant sections (e.g., FLOW's 3-mode detail blocks showing up in simple MASTER_GRID prompts).

---

## Pick a template by screen type

| Screen Type  | Template File       | When to Use                                                                 |
|--------------|---------------------|-----------------------------------------------------------------------------|
| MASTER_GRID  | `_MASTER_GRID.md`   | Grid list + **modal popup** RJSF form for add/edit                          |
| FLOW         | `_FLOW.md`          | Grid list + **full-page view** with `?mode=new / edit / read` (2 UI layouts)|
| DASHBOARD    | `_DASHBOARD.md`     | Widget grid with KPIs, charts, drill-downs, no CRUD (stub — first build fills in) |
| REPORT       | `_REPORT.md`        | Parameterized query with filter panel + result table/chart + export         |
| —            | `_COMMON.md`        | Reference doc — shared section conventions across all types                 |

**How to pick**: Look at the mockup. Match the primary UI pattern. Don't pick by entity name — the same module can have all four types (e.g., Donations has a FLOW screen for entry, a DASHBOARD for overview, a REPORT for monthly summary).

---

## Template structure (same across all four)

All templates follow the 12-section structure. Sections ①-④ and ⑦-⑫ are **shared conventions** (documented in `_COMMON.md`). Sections ⑤ and ⑥ are **type-specific** — they describe the patterns and UI blueprint unique to that screen type.

| # | Section | Shared / Type-specific |
|---|---------|-----------------------|
| ① | Identity & Context | shared |
| ② | Entity Definition | shared |
| ③ | FK Resolution Table | shared |
| ④ | Business Rules & Validation | shared |
| ⑤ | Classification & Patterns | **type-specific** |
| ⑥ | UI/UX Blueprint | **type-specific** (main differentiator) |
| ⑦ | Substitution Guide | shared (canonical ref differs per type) |
| ⑧ | File Manifest | shared format (file list differs per type) |
| ⑨ | Approval Config | shared |
| ⑩ | BE→FE Contract | shared |
| ⑪ | Acceptance Criteria | shared |
| ⑫ | Special Notes & Warnings | shared |

See [`_COMMON.md`](./_COMMON.md) for shared conventions, then the chosen type-specific template for the full prompt skeleton.

---

## For `/plan-screens`

The skill detects `screen_type` from the mockup (grid+modal → MASTER_GRID, 3-mode view-page → FLOW, widget grid → DASHBOARD, filter+export → REPORT) and loads the matching template. See [.claude/skills/plan-screens/SKILL.md](../../skills/plan-screens/SKILL.md).

---

## Why the split

Previously a single `_TEMPLATE.md` (628 lines) contained all patterns with "use one of the below, delete the other" instructions. That:

- Bloated MASTER_GRID prompts with FLOW 3-mode blocks and vice versa.
- Created confusion when the planner had to navigate type conditionals inline.
- Would not scale when DASHBOARD and REPORT are added.

Each template is now **standalone and complete** — `/plan-screens` loads exactly one, fills in the values, and outputs the screen's prompt file. Cross-cutting conventions live in `_COMMON.md` so shared parts stay consistent.
