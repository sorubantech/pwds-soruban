# PSS 2.0 — Command Bar (⌘K) Build Prompt

**Exploration ref:** `PSS-2.0-PRODUCT-SHELL-FEATURE-EXPLORATION.md` → **T-11**
**Status:** READY TO RUN
**Model:** Sonnet (§①–⑫ below are detailed; no historic-failure pattern here)
**Surface:** frontend only. No EF migration. No new GraphQL query. No backend C# change.

---

## ① Why this exists

This is not a "build a command palette" job. **Almost all of it is already built and none of it is
switched on.** Every row below is on-disk evidence, verified against the working tree.

| # | Defect | Evidence |
|---|---|---|
| **D-1** | **Two complete search UIs exist and neither is mounted.** `global-search.tsx` (482 LOC), `inline-search-bar.tsx` (622 LOC) and `create-button.tsx` (183 LOC) are near-duplicates of each other. Together with their five child components they are **~1,780 LOC that no route, layout or component renders.** | The only occurrence of the string `global-search` anywhere in `src/` outside the folder itself is a **code comment** — `presentation/provider/app-shell-provider.tsx:56`. `grep -rn "InlineSearchBar\|GlobalSearch" src/presentation/app` → 0. |
| **D-2** | **The palette that *is* mounted can only reach the active module's menus.** It offers no records, no recent searches, no actions. Switching module is a two-hop detour by design. | `app-topbar/index.tsx:85–111` builds `groups` from `usePanelMenu(activeRailKey)` only, plus a `__switch-module` group. |
| **D-3** | **A permission-scoped record-search backend is live and unused.** `globalSearch` resolver → `GlobalSearchHandler` → `SearchService` → Postgres `corg.global_search(...)`. It already filters by `CompanyId`, by the caller's RBAC-derived entity list, by schema and by entity type, and returns `title / subtitle / icon / url / rank / highlightedTitle / moduleCode / moduleName` — everything a result row needs. | `Base.Application/Business/SearchBusiness/Queries/GlobalSearch/GlobalSearchHandler.cs`; `Base.Support/SearchEngine/Services/SearchService.cs`; `Base.Support/SearchEngine/Infrastructure/SearchRepository.cs:36–57`; `DatabaseScripts/Functions/corg/global_search.sql`. |
| **D-4** | **Record search will return zero rows, silently, until `auth.SearchableEntities` is seeded.** The handler passes the caller's allowed list straight through. An unseeded tenant yields an **empty array**, and the SQL guard is `p_allowed_entity_types IS NULL OR 'CONTACT' = ANY(p_allowed_entity_types)` — an empty array is *not* NULL, so the guard is false and the result set is empty. No error, no message. There is **no seed for this table anywhere in the repo.** | `GlobalSearchHandler.cs:35`; `global_search.sql:76`; `grep -rl "SearchableEntit" sql-scripts-dyanmic DatabaseScripts/Seed` → 0 files. |
| **D-5** | **The index covers exactly one entity — contacts.** The frontend's `ENTITY_TYPE_CONFIG` advertises six (contact, donation, campaign, event, company, staff). Five of them can never return a row. | `global_search.sql` has a single `search_results` CTE over `corg."Contacts"`; `global-search/constants.ts:3–46`. |
| **D-6** | **A result title is rendered as raw HTML.** `highlightedTitle` comes from `ts_headline(...)` with `StartSel=<mark>` and is injected with `dangerouslySetInnerHTML`. The source is a database column derived from user-entered contact names. | `search-result-item.tsx:22–32`. |
| **D-7** | **Consequence.** A user who knows a donor's name has no way to reach that donor except by navigating to Contacts, waiting for a grid, and filtering it. This is a large part of what "the UI is just simple" meant at the demo. | — |

**So the build is: one front door, assembled from parts we already own, plus the seed that makes
the parts light up.**

---

## ② Rules this build must not break

1. **One search surface. Not two, not three.** At the end of this build exactly one component
   answers ⌘K. The duplicates go.
2. **Prove orphanhood before deleting.** For every file you delete, run the grep first and paste
   the result (`0 matches`) into the build log. If anything imports it, **stop and report** — do
   not "fix" the importer.
3. **Platform users get no record section.** `GlobalSearchHandler` calls
   `GetCurrentUserStaffCompanyId()` and returns `SearchResponse.Error("User is not associated with
   a company")` when it is `<= 0`. A platform operator on `(master)` has no company. If you run the
   query for them, every ⌘K keystroke produces an error. Gate on the existing
   `usePlatformUser().isPlatformUser` — **do not** call the query at all for platform users.
4. **Record search degrades, it never blocks.** If `globalSearch` errors, times out, or returns
   `errorMessage`, the Records section shows one quiet inline line and the **menu, action and recent
   sections keep working**. No toast. No thrown error. No empty palette. The palette's core job —
   jump to a screen — must survive a dead search backend, because on an unseeded tenant the search
   backend *is* effectively dead (D-4).
5. **No `dangerouslySetInnerHTML` in this build.** Render the highlight by splitting the string on
   the literal `<mark>` / `</mark>` markers and emitting React nodes. If the markers are absent or
   unbalanced, fall back to `result.title` verbatim. This is a hard rule: the payload is
   database-sourced user input and `ts_headline` is not an HTML sanitiser.
6. **Minimum 2 characters, debounce 300 ms.** The SQL function `RETURN`s empty below 2 characters
   anyway (`global_search.sql:13`), so firing earlier is pure round-trip waste. Reuse the existing
   `hooks/use-debounce.ts` and the existing `SEARCH_CONFIG` in `constants.ts:69–74` — the fields are
   `minSearchLength: 2`, `debounceMs: 300`, `resultsPerGroup: 5`, `maxRecentSearches: 10`. Do not
   invent new constant names and do not change these values.
7. **Harden the shortcut — one gap only.** `preventDefault()` is **already there**
   (`app-topbar/index.tsx:138`); do not "add" it and do not report it as a fix. What is missing is
   the focus guard: ignore the shortcut while focus is inside an `input`, `textarea` or
   `[contenteditable]` — except when the palette itself is already open, where it must still close.
   The listener stays exactly where it is (one owner, `AppTopbar`, per the §14.7 comment at
   `app-topbar/index.tsx:132–134`).
8. **Do not widen the SQL function and do not add a `search_vector` column to any table.** Making
   donations/events/cases searchable is real work with real migrations and it is **out of scope** —
   it is written up as a handover spec in §⑨. Building it here would drag an EF migration into a
   frontend build.
9. **Two-surface colour.** Use `useShellAccent` / `brand-surface.ts` helpers (`brandSolid`,
   `brandText`, `brandRing`). **Never `bg-primary-600`** inside anything the tenant shell renders —
   it paints the platform violet. The existing `constants.ts` uses `bg-blue-50 dark:bg-blue-950/50`
   style tints for entity chips; those violate the house rule (see rule 10) and must be replaced,
   not copied.
10. **House UI rules.** Icon containers, entity chips and status pills are solid `bg-X-600` +
    `text-white`. Never `bg-X-50/100`, never `text-X-700/800`, never `bg-muted` /
    `text-muted-foreground` as a status colour, never `/10` tints. Tokens, not hex or px. Shaped
    skeletons while loading. `@iconify` Phosphor icons. `tabular-nums` for counts.
11. **Never offer a destination the rail would have hidden.** The topbar already documents this as
    INV-3 (`app-topbar/index.tsx:45–47`) and already receives capability-filtered `railItems`. Menu
    results must come from the same capability-filtered source. Record results are filtered
    server-side by `GetUserSearchableEntitiesQuery` — do not add a second client-side filter that
    could disagree with it.
12. **Recents are per user and per device.** The existing `useSearchStore` already stamps entries
    with `userId` and the existing code already filters by the current user
    (`global-search.tsx:56–61`). Keep that. Recents are search *terms*, not results.
13. **Do not touch the record-collaboration surface.** A build is running against CRM detail
    screens, `custom-components/collaboration/`, `(core)/crm/mentions` and the
    `application-queries` / `application-mutations` barrels. This build touches none of them.
14. **No new GraphQL query, no backend C# file, no `.graphql` change.** `GLOBAL_SEARCH_QUERY` in
    `infrastructure/gql-queries/search-queries/search-queries.ts` is correct and already matches the
    resolver. The gql field is `globalSearch` — HotChocolate stripped `Get` from `GlobalSearchQuery`
    exactly as expected. `tsc` cannot verify gql field names, so do not rename anything here.
15. **The result `url` is locale-less and server-built.** `global_search.sql:63` produces
    `CONCAT(m."MenuUrl", '?mode=read&id=', <id>)` from `auth."Menus"`. Prefix `/${lang}` on
    navigate, exactly as `global-search.tsx:283–286` already does, and raise the same
    `setPendingHref` / `setIsMenuRendering` scrim a panel-leaf click raises.

---

## ③ The mental model

> **⌘K is the product's front door: one box that answers "where is X" — whether X is a screen, a
> record, or something you want to do.**

Everything else follows. If a section can't answer that question for the current user, it is not
rendered; it is never rendered as a broken promise.

---

## ④ What the command bar contains

One controlled dialog. Four sections, in this fixed order, each hidden when empty:

| Order | Section | Source | Shown to |
|---|---|---|---|
| 1 | **Actions** | A small static list defined in the palette: *Create contact*, *Create donation*, *Go to dashboard*, plus any that map to a rail item the user actually has. Filtered by the same capability-filtered `railItems` (rule 11). | everyone |
| 2 | **Records** | `GLOBAL_SEARCH_QUERY`, grouped by `entityType`, ordered by server `rank`. | tenant users only (rule 3) |
| 3 | **Menus** | The **whole** capability-filtered menu tree from `useParentChildMenuStore` — not just the active module (fixes D-2). Reuse `mapMenuToClassicConfig` from `layout-components/helper`, which the orphaned components already use. | everyone |
| 4 | **Recent** | `useSearchStore`, filtered to the current `userId`, most recent 10. Shown **only when the query box is empty.** | everyone |

**Behaviour**

- Opens on `⌘K` / `Ctrl+K` from anywhere in the shell (the listener stays where it is today — once,
  in `AppTopbar`), on click of the centre "Jump to…" button, and on the `md:hidden` magnifier.
- Query empty → Actions + Recent. Query ≥ 2 chars → Actions (filtered) + Records + Menus.
- One flat keyboard index across all visible sections: `↑`/`↓` move, `Enter` picks, `Esc` closes,
  and the active row scrolls into view. Section headers are not selectable.
- The active row is marked with `aria-selected`; the input carries `role="combobox"` and
  `aria-expanded`; the list carries `role="listbox"`. This is a keyboard-first surface — treat the
  a11y wiring as part of the feature, not as polish.
- **Loading:** Records section shows 3 shaped skeleton rows (avatar circle + two bars). Never a
  spinner that replaces the whole list — Menus results are already there and must stay visible.
- **Empty:** one line, `No records match "<term>"`, and the Menus section still renders.
- **Error / `errorMessage` set:** one quiet inline line in the Records section only —
  *"Record search is unavailable right now."* Nothing else changes (rule 4).
- Picking a **record** → `/${lang}${result.url}`. Picking a **menu** → the existing `handlePick`
  path. Picking **switch module** → `setActiveRailKey`, palette stays open and re-renders onto that
  module's leaves (the sentinel already exists: `SENTINEL_SWITCH_MODULE`).
- Every pick with a non-empty query calls `addRecentSearch`.

---

## ⑤ Files touched

> **Frontend paths are relative to `PSS_2.0_Frontend/src/`.**
> There is no backend work in this build. Backend paths appear only in §⑨, and are relative to
> `PSS_2.0_Backend/PeopleServe/Services/Base/` — the projects are **not** at
> `PSS_2.0_Backend/Base.Application/`, that directory does not exist.

**Rewritten**

| File | Change |
|---|---|
| `presentation/components/layout-components/command-palette/index.tsx` | Becomes the single command bar. Keeps its controlled `open`/`onOpenChange` contract and its `groups` prop (menus + switch-module still arrive from the topbar). Gains: the record section, the actions section, recents, the flat keyboard index, and the a11y roles. |
| `presentation/components/layout-components/app-topbar/index.tsx` | Menu groups now come from the **whole** tree, not `usePanelMenu(activeRailKey)` alone. Passes `isPlatformUser` down so the palette knows whether to run the record query. Shortcut handler gains `preventDefault()` and the input-focus guard. |

**Moved in, kept**

Move these out of `global-search/` and into `command-palette/`, keeping their logic and fixing only
what rules 5 and 10 require:

- `search-result-item.tsx` → **rule 5 applies**: replace `dangerouslySetInnerHTML` with node splitting.
- `search-result-group.tsx`, `search-menu-results.tsx`, `search-business-results.tsx`,
  `search-empty-state.tsx`, `search-tabs.tsx` (only if you keep tabs — see §⑦), `constants.ts`
  (**rule 10 applies**: the `bgColor` tints become solid `bg-X-600` + `text-white`), `hooks/use-debounce.ts`.
- **`hooks/use-search.ts` (252 LOC) — this is the load-bearing one. Move it, do not rewrite it.**
  It already owns the entire orchestration: `useLazyQuery(GLOBAL_SEARCH_QUERY)` at line 88, the
  debounce, the menu mapping via `mapMenuToClassicConfig`, and the grouping. Adapt it — add the
  `isPlatformUser` gate (rule 3) and the `errorMessage` branch (rule 4) if they are absent — but
  **starting from scratch here would be re-deriving code that already works.** Read it in full
  before touching the palette. Move `hooks/index.ts` with it.

**Deleted — after proving orphanhood (rule 2)**

- `global-search/global-search.tsx`
- `global-search/inline-search-bar.tsx`
- `global-search/create-button.tsx`
- `global-search/index.ts` (and the folder, once emptied)

**Unchanged, do not edit**

- `infrastructure/gql-queries/search-queries/*` — the query is correct.
- `domain/types/search-types/*` — the types match the resolver.
- `application/stores/search-stores/*` — the recents store is correct.
- `presentation/components/layout-components/index.tsx` — it exports `./command-palette` already
  and never exported `./global-search`, so the barrel needs no change. Confirm this rather than
  assuming it.

---

## ⑥ The record query — call it exactly like this

> **First read `hooks/use-search.ts`.** It already calls the query correctly (line 88). The block
> below is the contract that call must satisfy, not an instruction to write a new one. If the
> existing hook already does all of this, your job is the `isPlatformUser` gate and the
> `errorMessage` branch — nothing more.

```ts
const [executeSearch, { data, error, loading }] =
  useLazyQuery<IGlobalSearchResponse>(GLOBAL_SEARCH_QUERY, { fetchPolicy: "network-only" });

// tenant users only — a platform operator has no CompanyId and the handler errors (rule 3)
useEffect(() => {
  if (isPlatformUser) return;
  if (debouncedTerm.trim().length < SEARCH_CONFIG.minSearchLength) return;
  executeSearch({
    variables: {
      searchTerm: debouncedTerm.trim(),
      entityTypes: null,   // null = every entity the caller is allowed to see
      pageSize: 20,        // server clamps to [1,100]
      pageIndex: 0,
    },
  });
}, [debouncedTerm, isPlatformUser, executeSearch]);
```

Four things that will bite if ignored:

- **`entityTypes: null` means "all", not "none".** The server intersects it with the caller's
  allowed list; passing `[]` would return nothing.
- **`data.globalSearch.errorMessage` can be set on an HTTP 200.** `SearchResponse.Error(...)` is a
  normal payload, not a GraphQL error. Check the field, not just `error`.
- **Group client-side.** The resolver returns a flat `results` array; `ISearchResultGroup` is a
  frontend shape. Group by `entityType`, preserve server `rank` order inside each group.
- **`fetchPolicy: "network-only"` stays.** Search results go stale the moment a record is edited,
  and a cached hit on a stale title is worse than a round-trip.

---

## ⑦ Explicitly out of scope

- Widening `corg.global_search` past contacts. Spec is §⑨; it is the user's to schedule.
- Adding a `search_vector` column, index or trigger to any table.
- Any EF migration. Any backend `.cs` change. Any new resolver.
- Server-side "recent records" / "recently viewed". Recents here are **search terms**, local only.
- File/attachment search, comment search, audit search.
- The `SearchTabs` entity filter. **Recommended: drop it in this build.** With exactly one
  searchable entity, a tab strip that always reads "All | Contacts" is a promise the data cannot
  keep. Reinstate it when §⑨ lands. If you keep the file, keep it unrendered and say so in the log.
- The `CreateButton` inline-create menu. It belongs to the deleted duplicate; the Actions section
  covers the same ground with less surface.
- Search on list pages (LEVEL 2 in `PSS_2.0_Frontend/docs/SEARCH_ENGINE_BACKEND.md`). Grids have
  their own filtering.

---

## ⑧ Seed spec — user-owned SQL, written by this build, applied by the user

Without this, the Records section is permanently empty on every tenant and nobody will be able to
tell whether the build works (D-4). **Write one file, do not run it:**

`sql-scripts-dyanmic/search-searchable-entity-seed.sql`

It must, idempotently and in one transaction:

1. **`public."EntityTypes"`** — ensure a row: `EntityTypeCode = 'CONTACT'`,
   `EntityTypeName = 'Contact'`, `SchemaName = 'corg'`, `TableName = 'Contacts'`.
   Guard on `EntityTypeCode`.
2. **`auth."Menus"`** — ensure the decorator menu `MenuCode = 'SEARCHABLEENTITY'` exists.
   The authorize attribute on the query is `[CustomAuthorize(DecoratorAuthModules.SearchableEntity,
   Permissions.Read)]` and `DecoratorProperties.cs:73` resolves that to the literal
   `"SEARCHABLEENTITY"`. **Without this menu and a READ grant, global search 403s for every user,
   including SUPERADMIN.** This is the single most likely reason a correct build appears broken —
   verify it in Step 0 before writing a line of UI.
3. **`auth."RoleCapabilities"`** — grant READ on `SEARCHABLEENTITY` to every active, non-deleted
   role. Soft-delete semantics only (`IsDeleted = true, IsActive = false`) — never `DELETE`. Never
   revoke a grant unless its replacement is written in the same transaction. **SUPERADMIN is never
   revoked or overwritten**, matched by `RoleCode` alone.
   `auth."Capabilities"` has a UNIQUE index on `(CapabilityName, IsActive)` — match on
   `CapabilityName`, not `CapabilityCode`, when resolving the capability row.
4. **`auth."SearchableEntities"`** — one row linking the `CONTACT` entity type to the `CONTACT`
   menu, `IsActive = true`. The unique index is `(EntityTypeId, MenuId, IsActive)`; guard on that
   triple. `CapabilityId` stays NULL (the column is nullable and the handler does not read it).
5. A closing `SELECT` reporting: entity types present, the searchable-entity row count, and the
   number of roles now holding READ on `SEARCHABLEENTITY`.

One script per file. No diagnostic blocks, no A/B variants, no preview section. The file *is* the
thing to execute.

**Note the menu dependency in `global_search.sql:70`:** the result `url` is built by joining
`auth."Menus"` on `'CONTACT' = m."MenuCode"` with `IsActive = true`. If that menu is inactive in a
tenant, contacts simply stop appearing in search. Mention this in the build log as a known
operational coupling.

---

## ⑨ Handover spec — widening search beyond contacts (NOT built here)

Recorded so the decision is written down, not rediscovered. Each additional entity needs, per table:

1. A `search_vector tsvector` column plus a GIN index. → **EF migration, user-owned.**
2. A refresh function and trigger, following the three that already exist for contacts:
   `DatabaseScripts/Functions/corg/contacts_search_vector_update.sql`,
   `contact_child_refresh_parent_search.sql`, and the triggers under
   `DatabaseScripts/Triggers/corg/`. Child-table edits (phones, emails) must refresh the parent's
   vector — that pattern is already solved, copy it.
3. A backfill `UPDATE` for existing rows (the trigger only covers writes from that point on).
4. A new `search_results` CTE branch in `DatabaseScripts/Functions/corg/global_search.sql`,
   `UNION ALL`-ed with the contact branch, carrying its own `p_allowed_entity_types` /
   `p_entity_types` / `p_schema` guards and its own `auth."Menus"` join for the URL.
5. A `public."EntityTypes"` row and an `auth."SearchableEntities"` row mapping it to the menu that
   grants access, so RBAC scoping picks it up automatically.
6. Frontend: an `ENTITY_TYPE_CONFIG` entry. Nothing else — the UI is entity-agnostic once the
   config row exists.

`PSS_2.0_Frontend/docs/SEARCH_ENGINE_BACKEND.md` §13 "Adding New Entities" already documents this
flow; keep it as the canonical reference and update it if step 4's shape changes.

Suggested order by demo value: **donation → case → event → campaign → grant.**

---

## ⑩ Acceptance criteria

Each is greppable or observable. Run them and paste results into §⑫.

1. `grep -rn "InlineSearchBar\|create-button\|global-search/global-search" PSS_2.0_Frontend/src` → **0 matches**.
2. The directory `layout-components/global-search/` no longer exists.
3. `grep -rn "dangerouslySetInnerHTML" PSS_2.0_Frontend/src/presentation/components/layout-components` → **0 matches**.
4. `grep -rn "bg-primary-600" PSS_2.0_Frontend/src/presentation/components/layout-components/command-palette` → **0 matches**.
5. `grep -n "bg-blue-50\|bg-emerald-50\|dark:bg-.*-950/50" command-palette/constants.ts` → **0 matches** (rule 10).
6. The ⌘K handler in `app-topbar/index.tsx` ignores keystrokes originating in `input` / `textarea` /
   `[contenteditable]` while the palette is closed. (`preventDefault()` was already present — its
   presence proves nothing.)
7. `grep -n "isPlatformUser" command-palette/index.tsx` → **≥ 1 match**, guarding the query call.
8. `grep -n "GLOBAL_SEARCH_QUERY" command-palette/` → **≥ 1 match**; and
   `grep -rn "gql\`" command-palette/` → **0 matches** (no query was redefined inline).
9. `grep -n "errorMessage" command-palette/index.tsx` → **≥ 1 match** (rule 4, the 200-with-error case).
10. `grep -n "usePanelMenu(activeRailKey)" app-topbar/index.tsx` → the menu groups no longer come
    from the active module alone; if the call survives for another purpose, say which in the log.
11. `role="listbox"` and `aria-selected` both present in `command-palette/index.tsx`.
12. No file under `page-components/crm/`, `custom-components/collaboration/`, or `(master)/ops/` is
    modified — `git status --porcelain` proves it (rule 13).
13. `sql-scripts-dyanmic/search-searchable-entity-seed.sql` exists, is a single transaction, and was
    **not executed**.
14. Manual: ⌘K from a tenant screen → palette opens, menus from **every** module are reachable in
    one hop, typing 2+ chars of a known contact's name or code returns that contact, Enter navigates
    to it, and the term appears under Recent on the next open.
15. Manual: ⌘K as a platform user on `(master)` → palette opens, Records section is **absent**
    (not empty-with-error), menus and actions work.
16. Manual: with the seed **not yet applied**, the palette still opens, still navigates menus, and
    the Records section shows the quiet unavailable/empty line — never a crash, never a toast.
17. Manual responsive check at 375 / 768 / 1280 px.
18. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` → **exit 0**.
    A run that reports only a "pre-existing" `TS2688` stub-types error **checked zero files** and is
    not a pass. Only exit 0 counts. If it runs past 10 minutes, background it and collect the result.

---

## ⑪ Work order

**Step 0 — probe before building.** Three facts decide whether the Records section can work at all.
Report all three in the log before writing UI code:

- `SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='corg' AND proname='global_search';`
- `SELECT COUNT(*) FROM auth."SearchableEntities" WHERE "IsActive"=true AND "IsDeleted"=false;`
- `SELECT m."MenuCode" FROM auth."Menus" m WHERE m."MenuCode" IN ('SEARCHABLEENTITY','CONTACT');`

If you cannot reach a database, say so plainly and proceed — rule 4 means the build must be correct
either way. Do **not** invent results.

1. Prove orphanhood of the three duplicate files (rule 2). Paste the greps.
2. Move the keepers into `command-palette/`, applying the rule-5 and rule-10 fixes as you go.
3. Rewrite `command-palette/index.tsx`: sections, flat keyboard index, a11y roles, states.
4. Rewrite the topbar's group construction to cover the whole menu tree; pass `isPlatformUser`;
   harden the shortcut.
5. Delete the duplicates and the emptied folder.
6. Write `sql-scripts-dyanmic/search-searchable-entity-seed.sql`. **Do not run it.**
7. Run §⑩ 1–13 and 18. Fix and re-run until clean.
8. Fill in §⑫: what was deleted (with LOC), what moved, the Step 0 answers, anything you had to
   decide that this prompt did not settle, and the exact command the user runs to apply the seed.

---

## ⑫ Build Log

*(append-only, newest first — most recent 5 sessions kept, git holds the rest)*

### Session 1 — 2026-08-12 — Claude Opus 5

- **Status: BUILT — code complete, automated acceptance green, seed written and NOT applied.**
  Manual criteria 14–17 are untested (they need a running app and two logins) and the Records
  section returns nothing until the seed in §⑧ is applied. Nothing else is outstanding.

- **Step 0 probe results: NOT RUN — no database client is reachable from this machine.**
  `which psql` → nothing on PATH. The three probes (does `corg.global_search` exist; how many active
  rows in `auth."SearchableEntities"`; do the `SEARCHABLEENTITY` and `CONTACT` menus exist) could not
  be executed and **no results have been invented**. The build proceeded per §⑪, and the seed was
  written to be idempotent precisely so it is safe whatever those three answers turn out to be. Run
  the probes yourself before applying if you want the before/after picture.

- **Deleted:** the entire `presentation/components/layout-components/global-search/` folder — 11
  components + `index.ts` + `hooks/` (≈1,780 LOC with children). Orphanhood was proved first, as
  rule 2 demands: `InlineSearchBar|create-button|global-search/global-search` across
  `PSS_2.0_Frontend/src` returned matches **only from inside the folder itself** (`inline-search-bar.tsx`
  and `index.ts`). One match survives outside it and is not an import — `page-components/reportaudit/
  reports/scheduledreport/schedule-modal.tsx:10`, where `create-button` is a substring of the memory
  link `[[feedback-form-create-button-enablement]]` in a comment. That file was not touched.

- **Moved (kept):** `constants.ts` (rule-10 fix: all six entity chips now solid `bg-X-600` +
  `text-white`; `SEARCH_CONFIG` values untouched), `search-result-item.tsx` (rule-5 fix: the
  `<mark>` headline is split into React nodes, with a verbatim-title fallback on absent or unbalanced
  markers), `search-result-group.tsx`, `search-business-results.tsx`, `hooks/use-debounce.ts`, and
  `hooks/use-search.ts` — **moved, not rewritten**, exactly two additions: the `isPlatformUser` gate
  and the `errorMessage` branch.
  **Not moved, deleted with the folder:** `search-menu-results.tsx` (renders `next/link` rows that
  cannot join one flat keyboard index — the palette renders menu rows itself), `search-empty-state.tsx`
  (spinner + `from-primary/10` gradient; replaced by shaped skeletons and inline empty/error lines
  that live *inside* the index), and `search-tabs.tsx` (§⑦ recommends dropping it).

- **Decisions taken that this prompt did not settle:**
  1. **D-2 is fixed by mounting one `ModuleMenuSource` per rail item, only while the palette is open.**
     `usePanelMenu` already serves non-active modules `cache-first` and deliberately does not write
     `useParentChildMenuStore`, so this costs one cached query per module on first open and nothing on
     re-open. `usePanelMenu(activeRailKey)` is gone from the topbar; the hook is still imported, called
     once per rail inside `ModuleMenuSource`. Collected sections live in `AppTopbar` state.
  2. **`onPick` now returns `boolean | void`**; `handlePick` returns `true` for `SENTINEL_SWITCH_MODULE`,
     which is how "switch module without closing the palette" is expressed. Record picks route through
     the same `navigate`, so they raise the topbar's `setPendingHref` scrim like any panel leaf.
  3. **The palette calls `setActiveMode("all")` on open.** `useSearchStore`'s `INITIAL_STATE.activeMode`
     is `"menus"`, which short-circuits to local menu filtering and would never issue the query. This is
     a trap, not a preference — do not remove that line.
  4. **Actions are derived, never invented**: each of the three resolves against the capability-filtered
     leaves already in `groups` (contacts leaf + `?mode=new`, donation leaf + `?mode=new`, the active
     module's `__module_dashboard`) and is simply absent when the user cannot reach the destination.
  5. **Per-group "View all" was removed.** It linked to `/${lang}/${entityType}`, which is not a route.
  6. Menu group labels are module-qualified (`Fundraising · Donations`) because the palette now spans
     every module and bare section names collide across them.

- **§⑩ results:**
  1. ✅ 0 importing matches (the one comment substring above is not an import).
  2. ✅ `layout-components/global-search/` no longer exists.
  3. ✅ 0 matches for `dangerouslySetInnerHTML` under `layout-components`.
  4. ✅ 0 matches for `bg-primary-600` under `command-palette`.
  5. ✅ 0 matches for the tint pattern in `command-palette/constants.ts`.
  6. ✅ `app-topbar/index.tsx:194–199` — the handler returns early for `input` / `textarea` /
     `isContentEditable` **while the palette is closed**, and still closes it when open. The
     pre-existing `preventDefault()` was preserved, not added.
  7. ✅ `isPlatformUser` guards the query in both `command-palette/index.tsx` (`showRecords`) and
     `hooks/use-search.ts` (early return before `executeSearch`).
  8. ✅ `GLOBAL_SEARCH_QUERY` imported in `hooks/use-search.ts`; 0 inline `` gql` `` in the folder.
  9. ✅ `errorMessage` read in `index.tsx` (lines 118, 197, 199, 465) and set from both the payload
     field and `onError` in the hook.
  10. ✅ Menu groups no longer come from the active module alone. `usePanelMenu` survives in the file
      for one purpose: `ModuleMenuSource` calls it once per rail item to collect that module's sections.
  11. ✅ `role="listbox"` (`index.tsx:413`) and `aria-selected` (`index.tsx:334`, `search-result-item.tsx:94`).
  12. ⚠️ **Cannot be proved the way this criterion asks.** `PSS_2.0_Frontend/` is gitignored
      (`.gitignore:12`), so `git status --porcelain` lists no frontend file at all — a clean status
      proves nothing here. What is true: the only files written this session are the seven under
      `layout-components/command-palette/`, `layout-components/app-topbar/index.tsx`, the deleted
      `global-search/` folder, `sql-scripts-dyanmic/search-searchable-entity-seed.sql` and this prompt.
      Nothing under `page-components/crm/`, `custom-components/collaboration/` or `(master)/ops/` was
      opened for writing.
  13. ✅ `sql-scripts-dyanmic/search-searchable-entity-seed.sql` exists, one `BEGIN … COMMIT`, **not executed**.
  14–17. ⬜ Manual, not run — no app instance and no second login available here.
  18. ✅ `npx tsc --noEmit --incremental false` → **exit 0, zero diagnostics** (a real pass, not a
      TS2688-only run).

- **Handover to the user:**
  1. Apply the seed — this is the step that switches record search on:
     `psql "$CONNECTION_STRING" -f sql-scripts-dyanmic/search-searchable-entity-seed.sql`
     Read the closing report row. `searchable_entities = 0` means the tenant has no `CONTACT` menu
     and section 4 inserted nothing; fix that menu before anything else. `roles_with_search_read`
     should equal the number of live roles.
  2. Then walk 14–17: ⌘K from a tenant screen (every module's menus in one hop, 2+ chars finds a
     contact, Enter navigates, the term shows under Recent); ⌘K as a platform user on `(master)`
     (there must be **no** Records section at all); and confirm that *before* the seed the palette
     still opens and navigates with only a quiet unavailable line.
  3. The claude.ai MCP connectors (Gmail, Google Calendar, Google Drive, Microsoft 365, html-to-figma)
     are unauthorized in this session and were not used; authorize them in claude.ai connector
     settings if a future session needs them.

### Known Issues

- **Search covers contacts only.** Five of the six entity types in `ENTITY_TYPE_CONFIG` can never
  return a row until §⑨ is built. Do not "fix" this by removing the config entries — they are the
  target state, and the UI is entity-agnostic by design.
- **`SearchTabs` was deleted, not parked** (§⑦ recommended dropping it, and it cannot join the flat
  keyboard index as written). When §⑨ lands and search spans several entity types, rebuild the
  filter as chips inside the palette rather than restoring the old tab strip from git.
- **Contacts vanish from search if the `CONTACT` menu is deactivated in a tenant** — the URL join in
  `global_search.sql:70` is an inner join on an active menu row. Operational coupling, not a bug.
