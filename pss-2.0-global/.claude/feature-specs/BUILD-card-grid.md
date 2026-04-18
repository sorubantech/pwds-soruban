# BUILD PROMPT — CardGrid Feature

> **How to use this file:** open a **new Claude Code session** in the project root and paste the contents of the "Prompt to paste" section below as your first message. The agent will read the feature spec and build the infrastructure. Do not run `/plan-screens` or `/build-screen` — this is a **feature build**, not a screen build.

---

## Prompt to paste

```
Build the CardGrid feature end-to-end per the spec at `.claude/feature-specs/card-grid.md`.

This is an INFRASTRUCTURE-ONLY session. You are building reusable frontend components and wiring them into the existing data-table container. You are NOT building any screen (no page.tsx, no GraphQL, no backend work).

Use the frontend-developer subagent. Follow every rule in `.claude/agents/frontend-developer.md` — specifically the "UI Uniformity & Polish" section (tokens only, no hex/px, responsive xs→xl, @iconify Phosphor icons) and the "Display Mode: card-grid Rendering Contract" section.

## Required reading (read before any edit)

1. `.claude/feature-specs/card-grid.md` — authoritative build spec. Read it fully. This is the source of truth for file layout, types, component implementations, wiring, and acceptance criteria.
2. `.claude/agents/frontend-developer.md` — the "Display Mode: card-grid Rendering Contract" and "UI Uniformity & Polish" sections.
3. `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/advanced/data-table-container.tsx` (637 lines — read the render path and the context hooks).
4. `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/advanced/index.tsx` + `datatable-context.tsx` (to understand how `tableConfig` flows in).
5. Grep for the existing `PageConfig` / `TDataTableProps` / `RowAction` / `RowActionMenu` types before creating new ones — reuse, don't reinvent.

## Scope (build exactly this)

Per the feature spec's Section ③ (Folder layout), create:

```
PSS_2.0_Frontend/src/presentation/components/page-components/card-grid/
  card-grid.tsx                    — responsive shell
  card-variant-registry.ts         — variant → { Card, Skeleton } map
  types.ts                         — CardVariant, CardConfig discriminated union, CardProps, CardGridProps
  index.ts                         — barrel exports
  variants/
    details-card.tsx               — FULL IMPLEMENTATION (Section ⑤.3 of spec)
    profile-card.tsx               — STUB ONLY (one-line "not yet implemented" placeholder)
    iframe-card.tsx                — STUB ONLY
  skeletons/
    details-card-skeleton.tsx      — FULL IMPLEMENTATION (Section ⑤.6 of spec)
    profile-card-skeleton.tsx      — STUB ONLY
    iframe-card-skeleton.tsx       — STUB ONLY
  helpers/
    strip-html.ts                  — FULL IMPLEMENTATION (Section ⑥ of spec)
    format-modified-ago.ts         — grep for existing date util first; if found, thin wrapper or reuse directly
```

Then WIRE into the existing container:

- Edit `data-table-container.tsx`: add a branch at the row-rendering site so that when `displayMode === "card-grid"` and `cardVariant` is set, `<CardGrid>` renders instead of the table body. Filter chip bar, search, pagination, and toolbar stay in place — reuse the same state and handlers.
- Update the `PageConfig` / `TDataTableProps` type (wherever it lives — grep) to include `displayMode`, `cardVariant`, `cardConfig`.
- At runtime: if `displayMode: "card-grid"` but `cardVariant` or `cardConfig` is missing, console.warn in dev and fall back to `table` mode. No crash.

## What you must NOT do

- Do NOT build any screen (no SMS/WhatsApp/Notification/Email Template pages).
- Do NOT implement the real `ProfileCard` or `IframeCard`. Stub them — they're coming in later sessions. Stubs must render `<div className="p-4 text-sm text-destructive">Variant not yet implemented — see .claude/feature-specs/card-grid.md</div>`.
- Do NOT change any existing screen's behavior. Verify the existing `table` mode still renders identically.
- Do NOT add new npm dependencies. If a date util doesn't exist, implement `format-modified-ago.ts` inline (see spec Section ⑥).
- Do NOT touch backend code, GraphQL schemas, DB seeds, or anything under `PSS_2.0_Backend/`.
- Do NOT skip the UI Uniformity rules (tokens only, shaped skeletons, phosphor icons). Hex colors or inline pixel padding = instant reject.
- Do NOT use `dangerouslySetInnerHTML` anywhere. The `iframe` variant (when built later) uses `<iframe srcDoc>` with `sandbox="allow-same-origin"` — no script execution.

## Acceptance criteria (before reporting DONE)

Verify every checkbox in the spec's Section ⑬ (Acceptance criteria — DoD for the first build):

Infrastructure:
- [ ] All files from Section ③ exist at the paths shown.
- [ ] `types.ts` compiles in strict mode (run `pnpm tsc --noEmit` and confirm no new errors introduced).
- [ ] `card-variant-registry.ts` lists all three variants — `details` real, `profile` and `iframe` as stubs.
- [ ] `<CardGrid>` renders: loading skeletons (8 by default), empty state, real cards.
- [ ] Unknown variant renders the dev-time error box (temporarily test by passing `variant: "foo"`).

Wiring:
- [ ] `DataTableContainer` reads `displayMode` / `cardVariant` / `cardConfig` and branches correctly.
- [ ] `PageConfig` / `TDataTableProps` type updated (no `any`).
- [ ] Filter chip bar, search, pagination, toolbar all work in card-grid mode.
- [ ] Existing table-mode screens still render identically — no regression.

DetailsCard + Skeleton:
- [ ] Renders at 1/2/3/4 column breakpoints (manually test at 375 / 768 / 1280 widths).
- [ ] Snippet HTML is stripped (test with body containing `<b>bold</b>` — must render "bold", not "<b>bold</b>").
- [ ] Empty snippet shows italic "No preview" without layout shift.
- [ ] Card click fires `onCardClick(row)`; action menu click does NOT fire card click (stopPropagation works).
- [ ] Skeleton shape visually matches DetailsCard shape.

Build:
- [ ] `pnpm tsc --noEmit` passes with no new errors.
- [ ] `pnpm lint` passes with no new errors (if the project runs lint).
- [ ] `pnpm dev` starts without runtime errors.

## Verification steps (run these — don't skip)

1. `pnpm tsc --noEmit` — no new errors.
2. `pnpm dev` — server starts cleanly.
3. Manual smoke test: since no consumer screen exists yet, create a TEMPORARY dev-only test harness at `src/app/[lang]/dev/card-grid-test/page.tsx` that renders `<CardGrid>` with 5 mock rows using the `details` variant. Verify visual output at three breakpoints. Delete the harness before finishing.
4. Open one existing screen (any working MASTER_GRID or FLOW page) and confirm it still renders as a table — no regression.

## Reporting back

When done, reply with:

1. File manifest — every file created, every file modified.
2. Any deviations from the spec (with reason).
3. Any issues discovered in the spec itself (type mismatches, unclear sections) — propose edits to `.claude/feature-specs/card-grid.md`.
4. TypeScript / lint output summary.
5. After success: update `.claude/feature-specs/card-grid.md` frontmatter — flip `status: NOT_BUILT` to `status: BUILT — details variant only (profile + iframe stubbed)` and update `last_updated`.
6. Confirm: the next session can run `/build-screen #29` and expect `<CardGrid>`, `details` variant, and the `DataTableContainer` wiring to be in place.

Begin with required reading, then plan the edits, then execute. Use TodoWrite to track the sub-steps.
```

---

## Notes for the person running this prompt

- **One session, infra only.** Don't bundle it with a screen build. The whole point is the SMS Template session starts with the infra already done.
- **Expected output:** ~10 new files + 2–3 modified files (`data-table-container.tsx` + the `PageConfig` type file + possibly the barrel `index.ts`). TypeScript-green.
- **If the agent gets stuck on `PageConfig` typing** (the type name might differ — could be `TDataTableProps`, `PageConfigT`, etc.): that's fine, let it adapt. The spec points at the concept, not a specific name.
- **If the agent proposes building a real `ProfileCard` or `IframeCard`:** redirect — those are later. Stubs only in this session.
- **If acceptance step 3 (dev test harness) gets skipped:** ask for it. Without it there's no visual proof the components work.
- **When it's done:** the feature spec's `status` should be flipped. If that update is missing, remind the agent.
- **Next actions after this session completes:**
  1. `/plan-screens #29` — regenerates SMS Template spec with `displayMode: card-grid` + `cardVariant: details` + `cardConfig` pre-populated.
  2. `/build-screen #29` — builds the actual SMS Template screen, reusing the now-existing `<CardGrid>` + `details` variant.
  3. Then `/build-screen #31` and `/build-screen #36` — reuse everything, only differ in `cardConfig`.
  4. Later when you reach `#24` Email Template in Wave 5, a small session swaps the `iframe-card.tsx` stub for the real implementation.
