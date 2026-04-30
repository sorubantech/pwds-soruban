# Screen Prompt — Shared Conventions

> Reference doc describing sections that are **common across all screen types**
> (MASTER_GRID, FLOW, DASHBOARD, REPORT, CONFIG, EXTERNAL_PAGE). The six type-specific templates
> (`_MASTER_GRID.md`, `_FLOW.md`, `_DASHBOARD.md`, `_REPORT.md`, `_CONFIG.md`, `_EXTERNAL_PAGE.md`)
> follow these conventions — this file is the single source of truth for the shared parts.
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
| **Single config record** (no list-of-N) — multi-section settings page, designer canvas, or N×M matrix | `_CONFIG.md` |
| Admin **setup screen that publishes a public-facing page** consumed by anonymous visitors (donation page, P2P fundraiser, crowdfunding) | `_EXTERNAL_PAGE.md` |

Pick by what the mockup **shows**, not by the entity name. Some modules mix types — a single "Donations" module can have a FLOW screen (GlobalDonation), a DASHBOARD (Donation Overview), a REPORT (Monthly Donation Report), a CONFIG (Receipt Numbering Setup), and an EXTERNAL_PAGE (Online Donation Page).

**CONFIG vs MASTER_GRID/FLOW (common confusion)**: MASTER_GRID and FLOW manage **lists of N records** with per-row CRUD. CONFIG operates on **a single config record** (singleton-per-tenant), a **schema** (designer), or a **matrix** (axis × axis). If the mockup has "+Add" producing rows of a list, it's MASTER_GRID or FLOW — not CONFIG.

**EXTERNAL_PAGE vs FLOW vs CONFIG**: EXTERNAL_PAGE has TWO surfaces — admin setup AND a public anonymous page. FLOW transacts on internal records (no public face). CONFIG configures internal behavior (no public face). The strongest tells for EXTERNAL_PAGE: a Publish/Unpublish action, a slug/URL field, a public preview pane, and OG meta-tag fields in the setup mockup.

---

## Section structure (same across all templates)

All six type-specific templates follow the 12-section structure:

| # | Section | Shared / Type-specific |
|---|---------|-----------------------|
| ① | Screen Identity & Context | **Shared** format (CONFIG and EXTERNAL_PAGE §① are intentionally heavier — drives developer-led design) |
| ② | Entity Definition | **Shared** format (Dashboards/Reports often "no entity"; CONFIG calls it "Storage Model" with 4 patterns; EXTERNAL_PAGE calls it "Storage & Source Model" with single-page or parent-with-children) |
| ③ | FK Resolution Table | **Shared** format (CONFIG also lists matrix axis sources; EXTERNAL_PAGE lists aggregation sources for public rollups) |
| ④ | Business Rules & Validation | **Shared** format (CONFIG adds singleton/sensitive/dangerous-action gates; EXTERNAL_PAGE adds slug rules, lifecycle states, public-route hardening, anonymous-route concerns) |
| ⑤ | Screen Classification & Pattern Selection | **Type-specific** (CRUD vs widgets vs report vs config sub-type vs external-page sub-type + lifecycle + slug strategy + save-model) |
| ⑥ | UI/UX Blueprint | **Type-specific** (the main differentiator — CONFIG has 3 sub-type blocks; EXTERNAL_PAGE has 3 sub-type blocks AND each block describes BOTH admin setup + public page surfaces) |
| ⑦ | Substitution Guide | **Shared** format — canonical ref differs per type |
| ⑧ | File Manifest | **Shared** format — file list differs per type (CONFIG diverges by sub-type; EXTERNAL_PAGE always has admin setup + public route files for both BE and FE) |
| ⑨ | Pre-Filled Approval Config | **Shared** format (CONFIG / EXTERNAL_PAGE capabilities differ by sub-type; GridFormSchema always SKIP) |
| ⑩ | Expected BE→FE Contract | **Shared** format (EXTERNAL_PAGE splits Admin queries/mutations from Public queries/mutations with strict DTO privacy) |
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
screen_type: {MASTER_GRID | FLOW | DASHBOARD | REPORT | CONFIG | EXTERNAL_PAGE}
report_subtype: {TABULAR | PIVOT_CHART | DOCUMENT}                          # only when screen_type == REPORT
config_subtype: {SETTINGS_PAGE | DESIGNER_CANVAS | MATRIX_CONFIG}           # only when screen_type == CONFIG
external_page_subtype: {DONATION_PAGE | P2P_FUNDRAISER | CROWDFUND}         # only when screen_type == EXTERNAL_PAGE
complexity: {Low | Medium | High}
new_module: {YES — schema name | NO}
planned_date: {YYYY-MM-DD}
completed_date:
last_session_date:
---
```

**Status lifecycle**:

| Status | Meaning | Set by |
|--------|---------|--------|
| `PENDING` | Screen registered but prompt not generated yet | registry init |
| `PROMPT_READY` | Prompt file generated — ready for `/build-screen` | `/plan-screens` |
| `IN_PROGRESS` | `/build-screen` currently running | `/build-screen` |
| `PARTIALLY_COMPLETED` | Build interrupted mid-way (context limit, error) — resume with `/build-screen` | `/build-screen` |
| `COMPLETED` | Build finished, all verification checks passed | `/build-screen` |
| `NEEDS_FIX` | Build completed previously but bug/UI/enhancement raised — resume with `/continue-screen` | `/continue-screen` (user-triggered) |

Transitions: `PENDING → PROMPT_READY → IN_PROGRESS → (COMPLETED | PARTIALLY_COMPLETED)`. After `COMPLETED`, a new fix session may transition to `NEEDS_FIX` and back to `COMPLETED` when resolved.

### § Tasks checklist

Three groups: Planning (all `[x]` when file is generated), Generation (all `[ ]`), Verification (all `[ ]` — full E2E required).

### § Section ⑬ — Build Log (appended by `/build-screen` and `/continue-screen`)

An **append-only** history of sessions that worked on this screen. Lives at the bottom of every prompt file. The **Spec** (sections ① — ⑫) is the immutable input; the **Build Log** is the mutable running history. Each session appends one entry.

Entry format:

```markdown
### Session {N} — {YYYY-MM-DD} — {kind: BUILD | FIX | ENHANCE} — {outcome: COMPLETED | PARTIAL | BLOCKED}

- **Scope**: {what this session set out to do — 1 sentence}
- **Files touched**:
  - BE: `path/to/file.cs` (created | modified)
  - FE: `path/to/file.tsx` (created | modified)
  - DB: `path/to/seed.sql` (modified)
- **Deviations from spec**: {anything intentionally built differently from the Spec — or "None"}
- **Known issues opened**: {new bugs discovered but not fixed this session — or "None"}
- **Known issues closed**: {which bug IDs from previous sessions were resolved — or "None"}
- **Next step**: {empty if COMPLETED; what to resume on if PARTIAL/BLOCKED}
```

Above the entries, each prompt file also maintains a running **Known Issues** list — a short table of open bugs with stable IDs (`ISSUE-1`, `ISSUE-2`, …). When a fix session closes one, mark it `[x]` in place but leave the row for audit.

**Why this exists**: Claude Code sessions don't transfer between systems. The Build Log is the portable, human-readable "where did we leave off" record. Any dev can clone `.claude/` and know exactly what's built, what's broken, and what was intentionally deviated. `/continue-screen` reads it on resume.

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
- REPORT → TBD per sub-type — first TABULAR / PIVOT_CHART / DOCUMENT sets the convention for its sub-type
- CONFIG → TBD per sub-type — first SETTINGS_PAGE / DESIGNER_CANVAS / MATRIX_CONFIG sets the convention for its sub-type
- EXTERNAL_PAGE → TBD per sub-type — first DONATION_PAGE / P2P_FUNDRAISER / CROWDFUND sets the convention for its sub-type

### § Section ⑧ — File Manifest

File counts differ per type:

| Type | Backend | Frontend | Notes |
|------|---------|----------|-------|
| MASTER_GRID | 11 CRUD files | 6 FE files | No view-page, no Zustand store |
| FLOW | 11 CRUD files + workflow | 9 FE files | view-page (3 modes) + Zustand store |
| DASHBOARD | 2-3 (DTO + aggregate query) | 4-5 (dashboard page + widget components) | No CRUD |
| REPORT (TABULAR) | 4-7 (Report DTO + Report Query + Excel/PDF/CSV exporters + endpoint) | 7-9 (filter panel + result table + export menu + print-CSS + report page + page config + route) | No CRUD; max-row guard required |
| REPORT (PIVOT_CHART) | 4-6 (Pivot DTO + Pivot Query + Drill-down query + chart query + Excel pivot exporter + endpoint) | 6-9 (filter panel + pivot table + N chart components + export menu + report page) | No CRUD; cell drill-down required |
| REPORT (DOCUMENT) | 7-11 (Document DTO + Get/Bulk queries + optional report-row entity + PDF generator + email handler + reissue command + endpoints) | 6-8 (recipient picker + document component + print styles + bulk progress + report page) | One PDF per recipient; tenant branding from settings |
| CONFIG (SETTINGS_PAGE) | 8-10 (entity + EF + DTOs + Get/Update settings + Reset + Test + default seeder + endpoints) | 6-8 (DTOs + GQL + settings-page + 1 component per section) | No Create/Delete (singleton) |
| CONFIG (DESIGNER_CANVAS) | 13-15 (CRUD + GetSchema + BulkUpdate + Reorder + SchemaValidator + endpoints) | 9-11 (designer-page + palette + canvas + properties + preview + Zustand store) | Designer adds palette/canvas/properties |
| CONFIG (MATRIX_CONFIG) | 6-8 (matrix entity with composite key + GetMatrix + BulkUpdate diff + cell validator + endpoints) | 7-9 (matrix-page + matrix-grid + cell renderers + bulk toolbar) | Diff-update only (no full grid POST) |
| EXTERNAL_PAGE (DONATION_PAGE) | 12-14 (entity + EF + DTOs + admin queries + GetBySlug + GetStats + ValidateForPublish + lifecycle commands + slug validator + admin + public endpoints) | 13-14 (DTOs + admin GQL + public GQL + setup list + setup editor + section components + live preview + public donation page + donation form + thank-you + admin route + public route) | Admin setup + anonymous public route in `(public)` group; rate-limit + CSRF on public POST |
| EXTERNAL_PAGE (P2P_FUNDRAISER) | 18-22 (parent + fundraiser child entity/EF/DTOs + leaderboard query + approve/reject + public StartFundraiser + communication template handlers) | 13-15 (parent setup tabs + active fundraiser grid + approval queue + public parent + public child + Start-Fundraiser wizard + leaderboard + 2 public routes) | Parent + child page records; child slug nested route |
| EXTERNAL_PAGE (CROWDFUND) | 16-22 (campaign + reward tier entity/CRUD + update post entity/CRUD + atomic BackRewardTier + GetBackers + admin + public endpoints) | 14-15 (setup tabs + reward tier editor + update composer + public campaign + reward tier list + Back modal + updates feed + backers list) | Atomic inventory decrement on Back; sold-out tier disabled but rendered |

### § Section ⑨ — Approval Config

Pre-filled CONFIG block. Use BUSINESSADMIN role only (see feedback memory). GridType matches `screen_type`.

| screen_type | GridType | GridFormSchema |
|-------------|----------|----------------|
| MASTER_GRID | MASTER_GRID | GENERATE |
| FLOW | FLOW | SKIP |
| DASHBOARD | DASHBOARD | SKIP |
| REPORT | REPORT | SKIP |
| CONFIG | CONFIG | SKIP (custom UI, not RJSF — for all 3 sub-types) |
| EXTERNAL_PAGE | EXTERNAL_PAGE | SKIP (custom UI, not RJSF — for all 3 sub-types) |

### § Section ⑩ — BE→FE Contract

Pre-defines GQL query/mutation names, argument shapes, response DTO fields. Shared naming: `GetAll{Entity}List`, `Get{Entity}ById`, `Create/Update/Delete/Toggle{Entity}`. Optional extras per type:

- `Get{Entity}Summary` (MASTER_GRID / FLOW with widgets)
- `Get{Entity}Dashboard` (DASHBOARD)
- `Get{Entity}Report`, `Export{Entity}Report` (REPORT)
- `Get{Entity}Settings`, `Update{Entity}Settings`, `Reset{Entity}ToDefaults`, `Test{Entity}…`, `Regenerate{Field}` (CONFIG / SETTINGS_PAGE)
- `Get{Entity}Schema`, `BulkUpdate{Entity}Schema`, `Reorder{Entity}` (CONFIG / DESIGNER_CANVAS)
- `Get{Matrix}`, `BulkUpdate{Matrix}` (diff-only payload) (CONFIG / MATRIX_CONFIG)
- `Get{Entity}BySlug` (public, anonymous), `Get{Entity}Stats`, `Validate{Entity}ForPublish`, `Publish{Entity}`, `Unpublish{Entity}`, `Close{Entity}`, `Archive{Entity}` (EXTERNAL_PAGE — all sub-types)
- `InitiateDonation`, `ConfirmDonation` (EXTERNAL_PAGE / DONATION_PAGE — public, anonymous, rate-limited, csrf-protected)
- `GetAllFundraisersBy{Entity}`, `Get{Entity}Leaderboard`, `ApproveFundraiser`, `RejectFundraiser`, `StartFundraiser` (public) (EXTERNAL_PAGE / P2P_FUNDRAISER)
- `GetAllRewardTiersBy{Entity}`, `GetAllUpdatesBy{Entity}`, `Get{Entity}Backers`, `Reorder{Entity}RewardTiers`, `BackCampaign` (public, atomic inventory decrement) (EXTERNAL_PAGE / CROWDFUND)

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
