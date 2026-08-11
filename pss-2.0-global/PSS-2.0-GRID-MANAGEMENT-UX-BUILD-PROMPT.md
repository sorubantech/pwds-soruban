# PSS 2.0 — Grid Management (Grid Config) UI/UX Rebuild — BUILD PROMPT

> **Screen:** `(core)/setting/gridmanagement/grid` (Screen #77 — Grid Config)
> **Route folder:** `PSS_2.0_Frontend/src/app/[lang]/(core)/setting/gridmanagement/`
> **Component folder:** `PSS_2.0_Frontend/src/presentation/components/page-components/setting/gridmanagement/`
> **Status:** NOT STARTED
> **Scope:** Frontend only. No DTO changes, no GraphQL contract changes, no entity/migration work.
> **Model:** Sonnet (this document carries the full spec; §①–⑫ leaves nothing to infer).

---

## ① Why this exists — what is wrong today

Every row below was read at code level. Line numbers are from the files as they stand.

| # | Defect | Evidence |
|---|---|---|
| 1 | **The GraphQL field name is probably wrong and the tab may never load a configuration.** `GetGridListGrouped` is queried as `gridListGrouped` (Get stripped — correct). `GetGridConfigurationByGridId` is queried as `getGridConfigurationByGridId` (Get **not** stripped). Two sibling resolvers in one file, one rule, two spellings. Neither resolver carries `[GraphQLName]`. | `infrastructure/gql-queries/setting-queries/GridConfigurationQuery.ts`; `Base.API/EndPoints/Setting/Queries/GridQueries.cs:104` and `:122` |
| 2 | **Finding your grid is the actual job, and it is unsolved.** The picker is a raw native `<select>` with `<optgroup>` per module: no search, no filter, no recency, and no signal for which grids are already customised vs untouched. | `grid-config/tabs/grid-tab/grid-selector.tsx:40-60` |
| 3 | **Promised behaviour never implemented.** Comment reads *"Pre-select first grid alphabetically on initial load"*; `sorted` is computed and used only inside `onChange`. Nothing is pre-selected. | `grid-selector.tsx:22` |
| 4 | **"Reset to Default" is a lie.** `handleResetToDefault` restores the local `serverSnapshot` — i.e. *discard my unsaved edits*. The `RESET_GRID_CONFIGURATION_TO_DEFAULTS` mutation is declared and **never invoked**; only its `loading` flag is consumed. Two distinct actions collapsed into one button that performs the safer one while promising the destructive one. | `grid-tab.tsx:187-193`; mutation declared `grid-tab.tsx:140` |
| 5 | **The preview previews almost nothing.** Mock rows guessed by substring of `fieldKey`, capped at 8 columns × 4 rows, and it ignores `freezeColumns`, `showSummaryRow`, `rowsPerPage`, `enableRowSelection`, the default sort and the default filters — every setting the user just changed. Ships an apology banner: *"Preview uses mock data. Live preview coming in V2."* | `preview-grid-modal.tsx:12-30, 60-100` |
| 6 | **You can turn filtering on but never choose how it filters.** `isFilterable` is a Switch; `filterOperator` next to it is a read-only badge. | `column-config-table.tsx:120-140` |
| 7 | **Default filter values are always free text.** The value input is `type="text"` placeholder `"Value"` for every data type — a date filter is typed by hand, a boolean too — and `between` renders one input, not two. | `default-filters-card.tsx:95-120` |
| 8 | **Saved filters silently orphan.** `filterableFields = fields.filter(f => f.isVisible && f.isFilterable)`. Hide or un-filterable a column and its saved default filter vanishes from the list while still being posted on save. Nothing warns. | `default-filters-card.tsx:40-48` |
| 9 | **No error branch, no refetch.** The config query destructures `data, loading, refetch` and never `error`; `refetch` is never called. A failed load renders an empty editor indistinguishable from a virgin grid. | `grid-tab.tsx:70-78` |
| 10 | **No unsaved-changes guard.** `isDirty` is tracked, but switching grid, switching tab, or leaving the page discards silently. No `beforeunload`, no confirm. | `grid-tab.tsx` (whole file) |
| 11 | **Validation lands below the fold and only when dirty.** The `string[]` error list renders under every card, gated on `isDirty`. The Save button disables with no visible reason above the fold. | `grid-tab.tsx:109-118`, error block near bottom |
| 12 | **Fake affordance.** `onClick={() => toast.info("CSV import coming soon")}` on the Custom Fields *Import Fields* button. | `customfield-tab/customfield-data-table.tsx:30-38` |
| 13 | **Dead prop.** `onResetAllRequest` is declared in `GridTabProps` and passed from the page; the component never uses it. | `grid-tab.tsx` props vs body |
| 14 | **Dead code, duplicated.** `GridPageConfig` exists at `pages/setting/gridmanagement/grid.tsx` **and** `pages/shared/configuration/settingmanagement/grid.tsx`, is exported from both `index.ts` files, and is routed from nowhere. | grep: no route imports either |
| 15 | **The `field` route redirects *and* renders.** `field/page.tsx` fires `router.replace(...?tab=field)` in an effect and also returns `<GridConfigPageConfig />`, so the page mounts twice and flashes. | `app/[lang]/(core)/setting/gridmanagement/field/page.tsx` |
| 16 | **Reorder is mouse-only.** Native HTML5 drag-and-drop with `dragIndexRef`; a code comment notes *"react-dnd is available"* and it is not used. No keyboard path, no move-up/down buttons — the column order is unreachable without a pointer. | `column-config-table.tsx:30-70` |
| 17 | **Width has no live bound.** Raw `<input type="number" min={40} max={600}>`; typing `9999` is accepted into state and only surfaces in the global error list at save time. | `column-config-table.tsx:150-160` |
| 18 | **Responsive is absent.** Across all 14 `.tsx` files in the folder: `md:` = **0**, `xl:` = **0**; 12 of 14 files have zero responsive prefixes of any kind. The column table is 8 columns wide in an `overflow-x-auto` and is unusable below ~1000px. | folder-wide scan |
| 19 | **21 token-violating lines**, worst being the five-colour pastel filter-type map: `bg-blue-50 text-blue-700 border-blue-200`, `bg-purple-50 …`, `bg-amber-50 …`, `bg-green-50 …`, `bg-pink-50 …`. Plus `bg-muted/50`, `bg-muted/30`, `bg-muted/20`, `text-muted-foreground/40`, `border-destructive/30 bg-destructive/5` used as status. | `column-config-table.tsx:80-95` and siblings |
| 20 | **Zero brand adoption.** `brand-surface` / `--shell-accent` usage across the folder: **0**. Primary surfaces paint `text-primary` / `accent-primary`, which resolve to the platform violet on a tenant page. | folder-wide scan |
| 21 | **Raw radios instead of the molecule.** Export Columns is two `<input type="radio" className="h-4 w-4 accent-primary">` rather than `RadioGroup`. | `grid-behavior-card.tsx:110-130` |
| 22 | **Field Master and Custom Fields are unexplained.** Both tabs are a bare `AdvancedDataTable` with no header, no description, and no statement of how they relate to Grid Config — the user cannot tell why hiding a column here differs from deleting a field there. | `field-tab/field-data-table.tsx` (32 lines), `customfield-tab/customfield-data-table.tsx` (49 lines) |

---

## ② Rules this build must not break

1. **`isPredefined` columns can be hidden, never removed.** `isSystem` columns keep their lock affordance. `isPrimary` must stay visible — it may not be toggled off.
2. **At least one column must remain visible.** Save is blocked otherwise.
3. **Bounds are fixed:** width `40–600`; `rowsPerPage ∈ {10, 25, 50, 100}`; `freezeColumns` `0–5`; `MAX_FILTERS = 5`; default sort max 2 levels.
4. **`orderBy` is recomputed as `i + 1` over the visible-ordered array at save time.** Never post the stale server `orderBy`.
5. **No DTO changes, no GraphQL document changes** other than the one field-name correction in §⑮ step 1 (and only if step 1 proves the current name wrong).
6. **Field Master and Custom Fields keep their `gridCode`-driven `AdvancedDataTable` pipeline** (`FIELD_SETTING`, `CUSTOMFIELDS`). Do not hand-roll those tables.
7. **`companyId` is backend-derived.** It is never a form field and never sent from this screen.
8. **Reset All to Defaults stays destructive and stays confirmed.** It keeps its typed/explicit confirm and its existing `d?.result?.data === false` → *"No defaults available to reset"* branch.
9. **No new capability codes.** The screen stays gated by `useAccessCapability({ menuCode: "GRID" })`.

---

## ③ The mental model to adopt

> **These three tabs are not siblings. Grid Config is the screen; Field Master and Custom Fields are its reference data.**

A tab strip promises three equal views of one thing. What actually sits behind it is one bespoke editor with local dirty state and a Save button, plus two generic CRUD tables with their own toolbars and their own per-row save semantics. Switching "tab" from a half-edited config silently throws the edits away — because the thing you left was not a view, it was a form.

**The replacement:** Grid Config **is** the page. Field Master and Custom Fields become a two-item *reference rail* in the header — a segmented control styled deliberately unlike a tab strip (outline chips with a `ph:database` / `ph:puzzle-piece` icon, labelled **Reference data**), each opening its table in a full-height `Sheet` over the page. The config below never unmounts, its dirty state survives, and the visual grammar stops claiming a peer relationship that does not exist.

`?tab=field` and `?tab=customfield` keep working: they open the corresponding Sheet on mount. `?tab=grid` and no param both land on the config.

---

## ④ Page shell

```
┌───────────────────────────────────────────────────────────────────────────┐
│ ScreenHeader  "Grid Management"  ph:table-columns                         │
│   description: "Choose a grid, then decide which columns your team sees,  │
│                 how it sorts, filters and pages."                         │
│   right: [Field Master] [Custom Fields]   ·   [Reset all grids ▾]         │
├───────────────────────────────────────────────────────────────────────────┤
│ GRID PICKER BAR  (sticky top-0 z-20, backdrop-blur)                        │
│   [ 🔍 Search 240 grids across 18 modules … ]   ▸ Donations › Receipts     │
│   chips:  ● 12 customised   ○ 228 default   ↺ Recently edited              │
├───────────────────────────────────────────────────────────────────────────┤
│ (no grid chosen) → ZERO STATE: illustration + "Pick a grid to begin",      │
│                    plus 6 recently-edited quick cards                      │
├───────────────────────────────────────────────────────────────────────────┤
│ (grid chosen)                                                             │
│   ┌ CONTEXT STRIP ────────────────────────────────────────────────────┐   │
│   │ Receipts  ·  RECEIPT_GRID  ·  Donations  ·  Customised · 14 cols  │   │
│   │                                    [Preview]  [Form layout]        │   │
│   └────────────────────────────────────────────────────────────────────┘   │
│                                                                           │
│   xl:  ┌─ Columns (2fr) ─────────────┐ ┌─ Behaviour · Sort · Filters ─┐   │
│        │ column config table          │ │ stacked cards (1fr)          │   │
│        └──────────────────────────────┘ └──────────────────────────────┘   │
│   ≤lg: single column, Columns first                                        │
├───────────────────────────────────────────────────────────────────────────┤
│ STICKY ACTION BAR (bottom-0, only when a grid is chosen)                   │
│   left: dirty/validity summary   right: [Discard changes] [Restore         │
│                                          system defaults] [Save]           │
└───────────────────────────────────────────────────────────────────────────┘
```

Page container: `mx-auto max-w-[1600px] px-4 pb-24 pt-2 sm:px-6 lg:px-8`. The `max-w-7xl` cap is removed — this is a data-dense editor and it must use an xl screen.

---

## ⑤ The grid picker — the highest-value change

Replace `grid-selector.tsx` entirely.

**New file:** `grid-config/tabs/grid-tab/grid-picker.tsx`

- Trigger: a `Button variant="outline"` the full width of the bar, showing either the placeholder or `{moduleName} › {gridName}` with a trailing `ph:caret-up-down`.
- Body: `Popover` + `Command` (both exist in `common-components/atoms`). `CommandInput` placeholder `Search grids by name, code or module…`. Matching is case-insensitive over `gridName`, `gridCode` **and** `moduleName`.
- `CommandGroup` per module, heading `{moduleName} · {grids.length}`.
- Each `CommandItem` renders: grid name (medium), `gridCode` in `text-xs text-muted-foreground font-mono`, and on the right a **customised dot** — a `h-2 w-2 rounded-full` painted `style={brandSolid}` when that grid has a tenant configuration, absent otherwise. Tooltip: `Customised for your organisation`.
- A pinned first group **Recently edited** (max 5), sourced from `localStorage` key `pss.grid-config.recent` (array of `gridId`, most-recent-first, capped at 5, written on every successful save). Skip the group when the list is empty.
- Filter chips above the list: `All` / `Customised` / `Default`. Chip active state uses `brandSolid`; inactive is `variant="outline"`.
- **Implement the pre-selection that was only ever a comment:** on first load, if the URL carries `?gridId=` use it; else select the first entry of *Recently edited*; else select nothing and show the zero state. Never auto-select alphabetically — landing the user in an arbitrary grid's editor is worse than an honest empty state.
- Selecting a grid writes `?gridId={id}` via `router.replace` so the editor is linkable and survives refresh.
- **Guard:** if `isDirty`, selecting a different grid opens the discard confirm (§⑨) first.

"Customised" is derived from data already in hand — a grid is customised when its configuration returns any field row carrying a non-null `companyId`. Compute it lazily: the grouped list does not carry the flag, so mark only grids present in `pss.grid-config.recent` plus the currently-loaded one, and label the chip counts from what is known. Do **not** invent a new query for it.

---

## ⑥ Column configuration

Rewrite `column-config-table.tsx`.

**Reorder — keyboard reachable.** Keep the pointer drag, and add to each row a two-button vertical stepper (`ph:caret-up` / `ph:caret-down`, `size="icon"`, `h-6 w-6`, `variant="ghost"`), disabled at the ends, each with `aria-label={"Move " + fieldName + " up|down"}`. The drag handle gets `tabIndex={0}` and `aria-roledescription="sortable"`.

**Filter type becomes editable.** Where `isFilterable` is on, `filterOperator` renders as a `Select` — not a badge — over the operator set for that column's `dataTypeName`, using the same `getOperatorsForDataType` mapping that `default-filters-card.tsx` already owns. Move that function to a shared `grid-config/tabs/grid-tab/filter-operators.ts` and import it in both places; add `operatorLabel(op)` there too so `starts_with` renders as `Starts with` (capitalised, not the current bare `replace(/_/g, " ")`). When `isFilterable` is off the Select is disabled and shows `—`.

**Width gets live bounds.** Clamp on change to `[40, 600]`; on blur, snap out-of-range values to the nearest bound and flash the input border with `border-amber-600` for one second rather than waiting for save-time validation. Empty means "auto" — post `undefined`, not `0`.

**Colour.** Delete the pastel `cls` map. Filter-type chips become `variant="outline"` neutral chips with a leading icon per type (`ph:text-aa`, `ph:list`, `ph:calendar-blank`, `ph:hash`, `ph:toggle-left`). The only saturated colour in this table is the **Visible** state and the `brandSolid` drag indicator.

**Locks are enforced, not decorative.** `isPrimary` → Visible switch `disabled` with tooltip `The primary column cannot be hidden.` `isSystem` → keep the `ph:lock` icon, tooltip `System column — order and width are yours; it cannot be removed.` `isPredefined` → outline chip `Predefined`, tooltip unchanged.

**Responsive.** Below `lg`, the table collapses to a card list: one card per column, name + code on the first line, Visible switch top-right, and Width / Filterable / Filter type on a `grid-cols-2 gap-3` beneath. At `lg`+ the current 8-column table returns, wrapped in `overflow-x-auto` with the name column `sticky left-0 bg-background`.

**Header controls.** Above the table: a search input filtering rows by name/code, a `Visible only` toggle, and a right-aligned live counter `{visibleCount} of {total} columns visible` — `tabular-nums`.

---

## ⑦ Behaviour, sort and filters

**`grid-behavior-card.tsx`** — replace both native `<select>`s with the `Select` atom, and the two raw radios with `RadioGroup`. Each of the four Switch rows gains a one-line helper in `text-xs text-muted-foreground` (e.g. *"Lets users drag column edges. Widths reset on reload."*). Keep `sm:grid-cols-2`, add `xl:grid-cols-3`. Rows-per-page and freeze-columns get inline consequence text: `Freeze 2 → the first 2 columns stay put while scrolling sideways.`

**`default-sort-card.tsx`** — native selects → `Select` atoms. Direction becomes a two-option `ToggleGroup` (`ph:sort-ascending` / `ph:sort-descending`) rather than a dropdown. Add a plain-English echo under the pair: *"Newest Receipt Date first, then Donor Name A→Z."* Keep the 2-level cap; add a disabled third row reading `Two levels is the maximum` only if a third would otherwise be offered — otherwise omit it entirely.

**`default-filters-card.tsx`** — the value input becomes data-type aware:

| `dataTypeName` contains | Control |
|---|---|
| `date` / `datetime` | `DatePicker`; `between` → two `DatePicker`s; `preset` → `Select` of the existing presets |
| `int` / `decimal` / `number` | `Input type="number"`; `between` → two, with a `to` separator |
| `bool` | `Select` of `Yes` / `No` |
| anything else | `Input type="text"` |

Serialise `between` as `"{a}|{b}"` into the single `value` string — the DTO carries one `value` and §② forbids changing it. Parse the same way on load.

**Orphan warning.** When a saved filter's `fieldKey` is no longer in `filterableFields`, keep the row rendered, mark it with an amber `ph:warning-circle` and the text `"{fieldName}" is hidden or not filterable — this filter will not apply.` with a `Remove` button. Do not delete it silently, and do not drop it from the save payload unless the user removes it.

Operator labels come from the shared `operatorLabel` in §⑥.

---

## ⑧ Preview — honest, or gone

The current modal shows fabricated data and apologises for it. Two acceptable outcomes; take the first.

**Make it a layout preview, and say so.** Retitle to **Layout preview**, drop the amber apology banner, and replace it with a neutral one-line caption under the title: `Sample values — this shows your column order, widths and paging, not live records.` Then make it actually honour what it claims:

- Respect `freezeColumns` (`sticky left-0` on the first N, cumulative offsets).
- Respect `showSummaryRow` (render a footer row with `—` under non-numeric columns).
- Respect `enableRowSelection` (leading checkbox column).
- Render `rowsPerPage` in a footer as `Showing 1–{n} of 248` rather than ignoring it.
- Sort the mock rows by the configured primary sort so the arrow in the header means something.
- Show the default filters as a read-only chip row above the table: `Status = Active`, `Date after 01 Jan 2026`.
- Lift the column cap from 8 to **all visible columns** inside `overflow-x-auto`; keep 5 rows.

Rename the file to `layout-preview-modal.tsx` and the component to `LayoutPreviewModal`. Delete `MOCK_VALUES`'s substring guessing in favour of a small per-`dataTypeName` generator (`text` → `Sample text 1…`, `date` → three fixed ISO dates, `decimal` → three fixed amounts, `bool` → `Yes`/`No`).

---

## ⑨ The two reset actions, separated

The single misleading button becomes two, and the mutation finally gets called.

| Button | Meaning | Enabled when | Action |
|---|---|---|---|
| **Discard changes** | Throw away my unsaved edits, return to what is stored | `isDirty` | `loadFromConfig(serverSnapshot); setIsDirty(false)` — the current `handleResetToDefault` body, renamed `handleDiscardChanges` |
| **Restore system defaults** | Delete this grid's tenant configuration and fall back to the system layout | `!!selectedGridId` | Confirm dialog, then **call `resetToDefaults({ variables: { gridId } })`**, then `refetch()` on success, toast, `setIsDirty(false)` |

`Restore system defaults` is `variant="outline"` with `text-destructive` and a `ph:arrow-counter-clockwise` icon; its confirm dialog states plainly: *"Everyone in your organisation goes back to the system layout for **{gridName}**. Your saved column order, widths, sort and filters for this grid are deleted. This cannot be undone."* Confirm button `variant="destructive"`, label `Restore defaults`.

Update `reset-confirm-modals.tsx` to export both dialogs with distinct copy. **Reset All to Defaults** (page-level) keeps its existing behaviour, its confirm, and its `"No defaults available to reset"` branch — but its copy must now say *all grids*, and it stays in the header (§④), reachable regardless of which grid is selected.

**Dirty guard.** Add `useUnsavedChangesGuard(isDirty)` local to the grid tab: a `beforeunload` listener plus a confirm dialog intercepting grid switch and Sheet open. Copy: *"You have unsaved changes to {gridName}. Leave and lose them?"* → `[Keep editing] [Discard]`.

---

## ⑩ Save bar, validation and error states

**Sticky action bar** — `sticky bottom-0 z-20 -mx-4 border-t bg-background/95 px-4 py-3 backdrop-blur sm:-mx-6 sm:px-6`. Rendered only when a grid is selected.

Left side, one line, in priority order:
1. `validationErrors.length > 0` → `ph:warning-circle` + `{n} issue{s} to fix` in `text-destructive`, clickable, scrolling to the first offending card.
2. `isDirty` → `ph:circle-dashed` + `Unsaved changes`.
3. otherwise → `ph:check-circle` + `All changes saved` in `text-muted-foreground`.

Right side: `[Discard changes] [Restore system defaults] [Save configuration]`. Save is `style={brandSolid}`, disabled on `!canSave`, and when disabled its wrapper carries a Tooltip naming the reason (`Nothing to save` / `Fix {n} issue{s} first` / `Choose a grid first`) — never a silently dead button.

**Validation moves up.** The `string[]` list renders in an `Alert variant="destructive"` directly beneath the context strip — above the fold, above the cards — and it renders whenever `validationErrors.length > 0`, **not** gated on `isDirty`. Each message stays as written but gains the offending column name where it has one.

**Query error branch.** Destructure `error` from the config `useQuery`. On error render, in place of the editor: an `Alert variant="destructive"` with `error.message`, a `Retry` button calling `refetch()`, and the picker still usable above it. Loading renders shaped Skeletons — a 6-row table skeleton for the columns card and three `h-32` card skeletons on the right — never a spinner.

---

## ⑪ Reference data — Field Master and Custom Fields

Delete `tabs/field-tab.tsx`, `tabs/customfield-tab.tsx` and the `Tabs` shell in `grid-config-page.tsx`. Keep `field-tab/field-data-table.tsx` and `customfield-tab/customfield-data-table.tsx` — they are the correct `AdvancedDataTable` wrappers — and move them under `reference/`.

**New file:** `grid-config/reference/reference-sheet.tsx` — a `Sheet` with `side="right"` and `className="w-full sm:max-w-3xl lg:max-w-5xl"`, taking `kind: "field" | "customfield"`.

Each Sheet leads with a short explanation, because today there is none (defect 22):

- **Field Master** — *"The catalogue of every field the system knows about. Grids draw their columns from here. Renaming a field here changes it everywhere it appears."*
- **Custom Fields** — *"Extra fields your organisation added on top of the system ones. They become available as columns in the grids they belong to."*

The header triggers are outline chips with icons, grouped under a small `text-xs uppercase tracking-wide text-muted-foreground` label **Reference data** — visually distinct from a tab strip on purpose (§③).

**Delete the fake button.** `toast.info("CSV import coming soon")` goes; remove the *Import Fields* button entirely. A button that does nothing is worse than an absent one.

URL contract: `?tab=field` / `?tab=customfield` open the matching Sheet on mount and are cleared from the URL when it closes. Any other value, or none, lands on the config.

---

## ⑫ Explicitly out of scope

1. Backend changes of any kind — no resolver, handler, DTO or entity edits. (§⑮ step 1 may correct the **frontend** query document only.)
2. Migrations and seeds.
3. Live-data preview against real rows.
4. CSV import/export of custom fields.
5. Per-user (as opposed to per-tenant) grid layouts.
6. Changing `AdvancedDataTable` itself, or any `dgf-widget`.
7. `FormLayoutBuilder` internals — it keeps its current props (`isOpen`, `setIsOpen`, `gridId`, `gridName`) and is simply launched from the context strip.
8. Adding a third sort level or raising `MAX_FILTERS`.

---

## ⑬ Files touched

**New**
- `grid-config/tabs/grid-tab/grid-picker.tsx`
- `grid-config/tabs/grid-tab/filter-operators.ts`
- `grid-config/reference/reference-sheet.tsx`
- `grid-config/tabs/grid-tab/use-unsaved-changes-guard.ts`

**Modified**
- `grid-config/grid-config-page.tsx` (tabs shell → single page + reference rail)
- `grid-config/tabs/grid-tab.tsx` (error branch, guard, two resets, sticky bar, validation position)
- `grid-config/tabs/grid-tab/column-config-table.tsx`
- `grid-config/tabs/grid-tab/grid-behavior-card.tsx`
- `grid-config/tabs/grid-tab/default-sort-card.tsx`
- `grid-config/tabs/grid-tab/default-filters-card.tsx`
- `grid-config/tabs/grid-tab/reset-confirm-modals.tsx`
- `grid-config/tabs/grid-tab/preview-grid-modal.tsx` → renamed `layout-preview-modal.tsx`
- `app/[lang]/(core)/setting/gridmanagement/field/page.tsx` (redirect only — remove the double render)
- `infrastructure/gql-queries/setting-queries/GridConfigurationQuery.ts` (only if §⑮ step 1 confirms the field name is wrong)

**Deleted**
- `grid-config/tabs/grid-tab/grid-selector.tsx`
- `grid-config/tabs/field-tab.tsx`, `grid-config/tabs/customfield-tab.tsx`
- `presentation/pages/setting/gridmanagement/grid.tsx` + its `index.ts` export
- `presentation/pages/shared/configuration/settingmanagement/grid.tsx` + its `index.ts` export

**Moved**
- `tabs/field-tab/field-data-table.tsx` → `reference/field-data-table.tsx`
- `tabs/customfield-tab/customfield-data-table.tsx` → `reference/customfield-data-table.tsx`

---

## ⑭ Acceptance criteria

Each is greppable or observable.

1. `grep -rn "getGridConfigurationByGridId" PSS_2.0_Frontend/src` returns **0** hits if step 1 proved the name wrong; otherwise a code comment on the query records *why* the `Get` survives here.
2. `grep -rn "<select" PSS_2.0_Frontend/src/presentation/components/page-components/setting/gridmanagement` returns **0**.
3. `grep -rn "resetToDefaults(" .../grid-tab.tsx` shows the mutation being **invoked**, not just declared.
4. `grep -rn "Reset to Default" .../gridmanagement` returns **0**; `Discard changes` and `Restore system defaults` both appear.
5. `grep -rn "coming soon" .../gridmanagement` returns **0**.
6. `grep -rn "bg-blue-50\|bg-purple-50\|bg-amber-50\|bg-green-50\|bg-pink-50\|text-blue-700\|text-purple-700" .../gridmanagement` returns **0**.
7. `grep -rn "bg-muted/\|text-muted-foreground/\|destructive/5\|destructive/30" .../gridmanagement` returns **0**.
8. `grep -rn "brandSolid\|shell-accent" .../gridmanagement` returns **≥ 4** hits.
9. `grep -rn "md:" .../gridmanagement | wc -l` ≥ **12**; `xl:` ≥ **6**.
10. `grep -rn "<Tabs" .../gridmanagement` returns **0**.
11. `grep -rn "error" .../grid-tab.tsx` shows `error` destructured from the config `useQuery` and a rendered error branch.
12. `grep -rn "beforeunload" .../gridmanagement` returns **≥ 1**.
13. `grep -rn "onResetAllRequest" .../gridmanagement` — either used in the body or the prop is gone.
14. `grep -rn "GridPageConfig" PSS_2.0_Frontend/src` returns **0**.
15. `field/page.tsx` contains no `<GridConfigPageConfig />`.
16. `grep -rn "Command\b" .../grid-picker.tsx` confirms the searchable picker; typing a module name filters the list.
17. `grep -rn "aria-label" .../column-config-table.tsx` returns **≥ 2** (move up / move down).
18. `grep -rn "MOCK_VALUES" .../gridmanagement` returns **0**; `layout-preview-modal.tsx` references `freezeColumns`, `showSummaryRow`, `rowsPerPage` and `enableRowSelection`.
19. Manual: at 375 / 640 / 768 / 1024 / 1280 / 1440 px the page never scrolls horizontally at the body level; the column editor is a card list below `lg` and a table at `lg`+.
20. Manual: selecting a different grid with unsaved edits raises the discard confirm; closing the browser tab raises the native prompt.
21. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` exits **0**.

---

## ⑮ Build agent + work order

**Model:** Sonnet.

1. **Verify the field name first.** `GetGridConfigurationByGridId` in `GridQueries.cs:122` carries no `[GraphQLName]`, and its sibling `GetGridListGrouped` is queried as `gridListGrouped`. Confirm against the running schema (or the HotChocolate naming convention registration in `Program.cs` / the schema builder) whether the field is `gridConfigurationByGridId`. If it is, fix the FE query document — **this alone may be why the editor never loads**. `tsc` cannot catch this; do not skip it.
2. Delete the dead `GridPageConfig` pair and both `index.ts` exports; fix `field/page.tsx` to redirect only.
3. Build `filter-operators.ts` (operator sets + `operatorLabel`) and repoint `default-filters-card.tsx` at it.
4. Build `grid-picker.tsx` (Command + Popover, module groups, recent list, customised dot, chips, `?gridId=` sync) and delete `grid-selector.tsx`.
5. Reshape `grid-config-page.tsx`: drop `Tabs`, add the reference rail, keep `Reset all grids` in the header, keep `?tab=` → Sheet.
6. Build `reference-sheet.tsx`, move the two data tables under `reference/`, add the explanatory copy, delete the fake Import button and the two tab wrappers.
7. `grid-tab.tsx`: `error` branch + `refetch`, `use-unsaved-changes-guard.ts`, split the two resets (wire `resetToDefaults`), move validation above the fold and ungate it from `isDirty`, sticky action bar with the disabled-reason tooltip, remove or use `onResetAllRequest`.
8. Rewrite `column-config-table.tsx`: keyboard reorder, editable filter-type `Select`, clamped width, neutral chips, enforced locks, responsive card list below `lg`, header search + visible-only + counter.
9. Update `grid-behavior-card.tsx`, `default-sort-card.tsx`, `default-filters-card.tsx` per §⑦ (atoms, helper copy, typed filter values, orphan warning).
10. Rename and rebuild the preview per §⑧.
11. Sweep colour and responsive across all remaining files in the folder until criteria 6–9 pass.
12. Run `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` and iterate to exit 0.

---

## ⑬ Build Log

_(append-only, newest first, last 5 sessions retained — git holds the rest)_

**2026-08-11 — build complete (§⑮ steps 1–12).** Frontend only; no DTO, entity, resolver or migration touched.

- **Step 1** — confirmed `GetGridConfigurationByGridId` in `GridQueries.cs` carries no `[GraphQLName]` and no convention override exists, so the schema field is `gridConfigurationByGridId`. The FE document said `getGridConfigurationByGridId` — corrected. This was almost certainly why the editor never loaded.
- **Step 2** — deleted the duplicated dead `GridPageConfig` pair; `field/page.tsx` is now redirect-only (`?tab=field`), no longer rendering the config screen a second time.
- **Steps 3–6** — new `filter-operators.ts` (single operator vocabulary shared by the column table and the filters card, plus `getValueKind` / `encodeRange` / `decodeRange` / `dataTypeIcon`); new `grid-picker.tsx` (`Popover` + `Command`, searchable across name/code/module, per-module groups, "Recently edited" from `localStorage` key `pss.grid-config.recent`, All/Customised/Default chips) replacing `grid-selector.tsx`; `grid-config-page.tsx` reshaped — Tabs shell gone, Field Master and Custom Fields moved into a right-side `Sheet` (`reference-sheet.tsx`) reachable from header chips and `?tab=field` / `?tab=customfield`.
- **Steps 7–9** — `grid-tab.tsx` rewritten: sticky picker bar, zero state, query `error` destructured and rendered with a `Retry` calling `refetch()`, shaped skeletons, validation `Alert` ungated from `isDirty` and carrying the offending column names, `xl:` two-column split, sticky save bar with three-priority status and a tooltip naming why Save is disabled. `useUnsavedChangesGuard` parks grid switches and Sheet opens behind a confirm dialog and arms `beforeunload`. Column table rebuilt with keyboard reorder steppers, an operator `Select`, width clamped to 40–600 with a snap flash, neutral type chips (pastel map deleted), card list below `lg` / sticky-name table at `lg`+. All three cards rewritten — every native `<select>` is now a `Select`, export radios are a `RadioGroup`, sort direction is a `ToggleGroup` with a plain-English echo line, filters get type-aware value controls (`DatePicker`, number, Yes/No, `between` serialised as `"{a}|{b}"`) and an amber orphan-warning row instead of silently vanishing.
- **Step 9 (resets)** — the two resets are now distinct: *Discard changes* restores the local server snapshot; *Restore system defaults* actually invokes `resetToDefaults({ variables: { gridId } })` then `refetch()`. Reset all grids keeps its typed-tenant-name confirm and its `d?.result?.data === false` → "No defaults available to reset" branch.
- **Step 10** — `preview-grid-modal.tsx` → `layout-preview-modal.tsx`. Apology banner replaced by the neutral caption; all visible columns shown (8-column cap lifted); honours `freezeColumns` via cumulative sticky offsets, `enableRowSelection`, `showSummaryRow`, `rowsPerPage` (`Showing 1–n of 248`), primary sort and default filters as read-only chips. `MOCK_VALUES` substring guessing replaced by a per-`dataTypeName` generator.
- **Step 12** — `npx tsc --noEmit --incremental false` exits **0**.

Two API corrections found during the typecheck, worth recording: this `Alert` atom takes `color="destructive" variant="soft"` — `variant` only accepts `outline | soft`; and the non-required single-mode `DatePicker` types its value as `Date | null` (not `undefined`), so the `onValueChange` signature is `(value: Date | null) => void`.

Acceptance greps over `page-components/setting/gridmanagement/`: 0 hits for `getGridConfigurationByGridId`, `<select`, `Reset to Default`, `coming soon`, `bg-muted/`, `<Tabs`, `MOCK_VALUES`, `GridPageConfig` and the pastel palette; 5 × `brandSolid|shell-accent`; 17 × `md:`; 8 × `xl:`; `resetToDefaults(` invoked; `beforeunload` present; 10 × `aria-label` in the column table. Not done: the manual responsive walk at 375/640/768/1024/1280/1440 needs a browser.

**2026-08-11 — prompt authored.** Full discovery pass over the 14 `.tsx` files in `page-components/setting/gridmanagement/`, both app routes, the DTO, query and mutation documents, and the backend `GridQueries.cs` / `GridMutations.cs` resolvers. 22 defects catalogued. Headline findings: a probable GraphQL field-name mismatch on `getGridConfigurationByGridId`, a "Reset to Default" button that never calls its mutation, a native `<select>` where the screen's central task lives, and a tab shell that models three unrelated things as siblings. No code changed.
