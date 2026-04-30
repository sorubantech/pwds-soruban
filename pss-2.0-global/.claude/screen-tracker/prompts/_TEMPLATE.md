# Screen Prompt Templates — Router

> **This file is an INDEX**, not a template.
> Pick the right type-specific template based on the screen's `screen_type`.
>
> Splitting per type keeps each template focused and avoids bloating screens with
> irrelevant sections (e.g., FLOW's 3-mode detail blocks showing up in simple MASTER_GRID prompts).

---

## Pick a template by screen type

| Screen Type   | Template File         | When to Use                                                                 |
|---------------|-----------------------|-----------------------------------------------------------------------------|
| MASTER_GRID   | `_MASTER_GRID.md`     | Grid list + **modal popup** RJSF form for add/edit                          |
| FLOW          | `_FLOW.md`            | Grid list + **full-page view** with `?mode=new / edit / read` (2 UI layouts)|
| DASHBOARD     | `_DASHBOARD.md`       | Widget grid with KPIs, charts, drill-downs, no CRUD                         |
| REPORT        | `_REPORT.md`          | Parameterized output — filter panel + result + export. Sub-types: `TABULAR` (sortable/grouped/footer-totals), `PIVOT_CHART` (cross-tab and/or chart-primary), `DOCUMENT` (per-record fixed-layout — statements / receipts / certificates) |
| CONFIG        | `_CONFIG.md`          | System / module configuration — **NOT** a list-of-N. Sub-types: `SETTINGS_PAGE` (single-record multi-section), `DESIGNER_CANVAS` (palette + canvas + properties), `MATRIX_CONFIG` (N×M grid editor) |
| EXTERNAL_PAGE | `_EXTERNAL_PAGE.md`   | Admin setup screen that publishes a **public-facing page** consumed by anonymous visitors. Sub-types: `DONATION_PAGE` (online donate-now), `P2P_FUNDRAISER` (parent campaign + supporter child pages), `CROWDFUND` (goal + tiered rewards + updates) |
| —             | `_COMMON.md`          | Reference doc — shared section conventions across all types                 |

**How to pick**: Look at the mockup. Match the primary UI pattern. Don't pick by entity name — the same module can have all six types (e.g., Donations has a FLOW screen for entry, a DASHBOARD for overview, a REPORT for monthly summary, a CONFIG screen for receipt-numbering setup, and an EXTERNAL_PAGE for the public online-donation page).

**CONFIG vs MASTER_GRID/FLOW**: MASTER_GRID/FLOW manage a **list of N records** with per-row CRUD. CONFIG operates on **a single config record** (singleton), a **schema** (designer), or a **matrix** (axis × axis). If the mockup shows "+Add" producing rows and a list of records — it's MASTER_GRID or FLOW, not CONFIG.

**EXTERNAL_PAGE vs FLOW vs CONFIG**: EXTERNAL_PAGE has TWO surfaces — an admin setup UI AND an anonymous-public page (with shareable URL, OG meta tags, payment hand-off). FLOW transacts on internal records and never publishes a public page. CONFIG configures internal behavior with no public output. If the mockup has a "Publish" button + a public preview pane + a slug/URL field, it's EXTERNAL_PAGE.

---

## Template structure (same across all six)

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

The skill detects `screen_type` from the mockup:

- grid + modal RJSF form → **MASTER_GRID**
- grid + 3-mode view-page (`?mode=new/edit/read`) → **FLOW**
- widget grid (KPIs / charts, no CRUD) → **DASHBOARD**
- filter panel + parameterized result + export → **REPORT**
- single config record (no list-of-N) — multi-section settings page, designer canvas, or N×M matrix → **CONFIG**
- admin setup UI + public anonymous page (slug, OG meta, Publish, payment hand-off) → **EXTERNAL_PAGE**

For REPORT, also stamp `report_subtype: TABULAR | PIVOT_CHART | DOCUMENT` in frontmatter.
For CONFIG, also stamp `config_subtype: SETTINGS_PAGE | DESIGNER_CANVAS | MATRIX_CONFIG` in frontmatter.
For EXTERNAL_PAGE, also stamp `external_page_subtype: DONATION_PAGE | P2P_FUNDRAISER | CROWDFUND` in frontmatter.

**REPORT vs FLOW (common confusion)**: FLOW has a submit/approve/revision lifecycle on a transactional record (e.g. `grantreport` is FLOW — funder progress narratives with submit/accept). REPORT has a parameterized output for analysis or distribution (e.g. monthly donation register, donor statement). If the user transacts on the record, it's FLOW. If they consume the record as output, it's REPORT.

**EXTERNAL_PAGE vs FLOW**: FLOW transacts on an internal record (a donation entry, a grant approval). EXTERNAL_PAGE configures and **publishes a public-facing page** that anonymous visitors visit (with shareable URL, share buttons, payment-gateway hand-off). The strongest tells: a Publish/Unpublish lifecycle, a slug/URL field, a public preview pane in the setup mockup, OG meta-tag fields. If the mockup has those, it's EXTERNAL_PAGE.

See [.claude/skills/plan-screens/SKILL.md](../../skills/plan-screens/SKILL.md).

---

## Why the split

Previously a single `_TEMPLATE.md` (628 lines) contained all patterns with "use one of the below, delete the other" instructions. That:

- Bloated MASTER_GRID prompts with FLOW 3-mode blocks and vice versa.
- Created confusion when the planner had to navigate type conditionals inline.
- Would not scale as DASHBOARD, REPORT, CONFIG, and EXTERNAL_PAGE were added.

Each template is now **standalone and complete** — `/plan-screens` loads exactly one, fills in the values, and outputs the screen's prompt file. Cross-cutting conventions live in `_COMMON.md` so shared parts stay consistent. `_CONFIG.md`, `_REPORT.md`, and `_EXTERNAL_PAGE.md` each contain three sub-type variants inline, because their UI/UX blueprints differ enough to need separate blocks but they share the storage / save / sensitive-field / role-gating / lifecycle conventions.
