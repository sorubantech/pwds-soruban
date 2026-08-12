# PSS 2.0 — AI Module (promote Intelligence out of CRM)

> **Status:** NOT STARTED
> **Origin:** demo 2026-08-11 — `crm/intelligence` shipped 6 menu entries, all rendering
> `UnderConstruction`. Decision: promote it to a **top-level `AI` module** and widen it with the
> menus a modern AI workspace carries (ClickUp AI reference).
> **Delivery model:** dummy-first per `PSS-2.0-PRODUCT-SHELL-FEATURE-EXPLORATION.md` §⑥.

---

## ① Why this exists

| # | Defect | Evidence |
|---|--------|----------|
| **D-1** | **All six Intelligence screens are hard-hat pages.** A prospect who clicks "AI Reporting" in the nav gets a construction graphic. | `app/[lang]/(core)/crm/intelligence/{actionboard,aidraft,aireporting,churnprediction,engagementscoring,predictiveanalytics}/page.tsx` — every one is 7 lines importing `@/presentation/error-page/Construction/page` |
| **D-2** | **The page-config layer was never started.** | `presentation/pages/crm/intelligence/index.ts` contains exactly one line: `//EntityPageConfigExport` |
| **D-3** | **AI is buried as a CRM sub-group**, so it reads as a CRM add-on rather than a capability of the product. It sits beside "Prayer requests" and "Certificates". | `menu-activate-mvp-feature-areas.sql:69-76` groups all 7 codes under feature area `'Intelligence'`, parented to `CRM_INTELLIGENCE` inside the CRM module |
| **D-4** | **Menu-code drift between two billing seeds.** The reporting screen is `AIREPORTING` in one file and `NLREPORTING` in another. One of those map rows points at a menu that does not exist, so its entitlement silently never applies. | `menu-activate-mvp-feature-areas.sql:74` = `AIREPORTING`; `billing-feature-menu-map-leaf-level-seed.sql:227` = `NLREPORTING`. Route folder on disk is `aireporting` |
| **D-5** | **No assistant surface at all.** The module has six *analytics* screens and zero *conversational* screen — the one thing every buyer now means by "AI". | No chat, thread, prompt-library or agent route anywhere under `src/app` |
| **D-6** | **No AI governance surface.** Nothing tells a tenant admin what data the AI can see, who used it, or how much of their allowance is left. | No `connections` / usage / AI-settings route exists |

**The upside buried in D-1/D-2:** because nothing was ever built, this move costs almost nothing on
the frontend. There is no component to port, no query to re-point, no state to migrate. The entire
cost is menu/RBAC seed work plus new dummy screens.

---

## ② Rules this build must not break

1. **Menu codes are NOT renamed.** `auth."RoleCapabilities"` joins Role → Menu(**MenuCode**) →
   Capability. Renaming `ACTIONBOARD` → `AI_ACTIONBOARD` silently revokes every existing grant.
   The seven existing codes keep their spelling forever; only `ModuleId`, `ParentMenuId`,
   `MenuName`, `MenuUrl` and `OrderBy` change. **`CRM_INTELLIGENCE` will therefore end up as a
   menu code beginning `CRM_` that lives in the AI module. That is deliberate — leave it.**
2. **`billing.Features` / `FeatureMenuMaps` are hand-curated.** New AI menus get map rows written by
   hand into the curated seed. Never generated from `auth.Modules` or the menu tree.
3. **Two separate checks, both required** (per `platform-intimations-menu-capability-seed.sql:19-26`):
   API authorization reads `auth."RoleCapabilities"`; sidebar rendering needs an `ISMENURENDER`
   grant. A menu with a capability but no `ISMENURENDER` is URL-callable and invisible.
   `ISMENURENDER` already exists — never insert it.
4. **Schemas:** `auth."Modules"/"Menus"/"Capabilities"/"MenuCapabilities"/"RoleCapabilities"`,
   `billing."Features"/"FeatureMenuMaps"`, `sett."Grids"`. Do **not** qualify these with `app`.
5. **RBAC seeds soft-delete** (`IsDeleted=true, IsActive=false`), never `DELETE`. Never revoke a
   grant until its replacement is written in the same transaction. `SUPERADMIN` is never touched.
6. **I do not run migrations or SQL.** This prompt produces `.sql` under `sql-scripts-dyanmic/`;
   the user applies it. One script per file, no diagnostics/preview/A-B blocks.
7. **No entity-level changes, no EF migration.** This is a nav + FE-screen build. If a screen
   appears to need a table, it stays dummy.
8. **Dummy rules** from the exploration doc §⑥: visible `Preview` chip, designed screen with
   plausible typed canned data in one file per screen, nothing that writes claims it saved,
   no `UnderConstruction` pages survive.
9. **House UI rules:** tokens not hex/px; solid `bg-X-600` + `text-white` for icon containers,
   status badges and chips (never `bg-X-50/100`, `text-X-700/800`, `bg-muted` as status); shaped
   Skeletons; @iconify Phosphor icons; `tabular-nums` + `text-right` on numbers in data contexts;
   xs→xl responsive; Save gated on RHF `isValid`, never on `canCreate`.
10. **Tenant accent only.** Paint via `brand-surface.ts` (`brandSolid`/`brandGradient`/`brandSoft`).
    Never `bg-primary-600` — that renders the static platform violet on a tenant's page.

---

## ③ The mental model

> **AI is not a CRM report — it is a second way to operate the whole product.** So it gets a module,
> not a folder; a conversation, not just charts; and a governance page, because a tenant admin who
> cannot see what the AI reads will not switch it on.

---

## ④ Module and menu tree

**Module:** `ModuleCode = 'AI'`, name `AI`, icon `ph-sparkle`, ordered immediately after `CRM`.
**Route group:** `src/app/[lang]/(core)/ai/`.

| Group | Menu | MenuCode | Route | State |
|---|---|---|---|---|
| **Assistant** `AI_ASSISTANT` | Ask AI | `AI_ASK` | `/ai/ask` | **new** |
| | Skills | `AI_SKILLS` | `/ai/skills` | **new** |
| | Agents | `AI_AGENTS` | `/ai/agents` | **new** |
| | Draft Studio | `AIDRAFT` *(kept)* | `/ai/draft` | move + build |
| **Insights** `CRM_INTELLIGENCE` *(kept, renamed to "Insights")* | Action Board | `ACTIONBOARD` | `/ai/actionboard` | move + build |
| | Engagement Scoring | `ENGAGEMENTSCORING` | `/ai/engagementscoring` | move + build |
| | Lapse Prediction | `CHURNPREDICTION` | `/ai/churnprediction` | move + build |
| | Predictive Analytics | `PREDICTIVEANALYTICS` | `/ai/predictiveanalytics` | move + build |
| | AI Reporting | `AIREPORTING` | `/ai/reporting` | move + build |
| **Governance** `AI_GOVERNANCE` | Connections | `AI_CONNECTIONS` | `/ai/connections` | **new** |
| | Usage & Analytics | `AI_ANALYTICS` | `/ai/analytics` | **new** |
| | AI Settings | `AI_SETTINGS` | `/ai/settings` | **new** |

Six new leaves, six moved, three group headers (one reused). "Churn" is renamed **Lapse Prediction**
in the UI — nonprofits talk about lapsed donors, not churned customers. The code stays
`CHURNPREDICTION` per rule ②-1.

---

## ⑤ Screen designs (all dummy-first)

**Shared:** every AI screen carries a `Preview` chip in the page header (`brandSoft` background,
`ph-sparkle` icon). The AI module sidebar carries a **credits meter** pinned at its foot —
`"{used} AI actions · {remaining} credits left"` with a thin progress bar — reading from the plan
entitlement layer if a quota key exists, otherwise from canned data.

| Screen | Layout |
|---|---|
| **Ask AI** `/ai/ask` | Two-pane. Left: `Recent chats` list + `New chat`. Right: message thread, composer pinned bottom, suggested-prompt chips on an empty thread ("Which donors lapsed this quarter?", "Summarise grant GR-1042", "Draft a thank-you for a ₹50,000 gift"). Scripted responses keyed to the prompt chips; streaming-style character reveal; source chips under each answer naming the module it "read". Anything unmatched → *"I can't answer that one yet."* |
| **Skills** `/ai/skills` | Top row of starter cards (`Thank-you Letter`, `Grant Report Summary`, `Donor Brief`, `Appeal Copy`, `Draft Like Me`) each with a `+ Create skill` action. Below: tabs `All / Enabled / Created by me`, table+grid view toggle, search. Empty state: *"Skills teach the assistant how you work."* Create opens a Dialog — name, description, prompt body, scope (Personal / Workspace) — which **previews only, does not save**. |
| **Agents** `/ai/agents` | Tabs `All agents / My agents`. Card per agent: name, trigger sentence, last-run chip, on/off Switch. Canned set: `Lapsed Donor Watcher`, `Grant Deadline Chaser`, `Receipt Gap Auditor`, `Weekly Giving Digest`. `+ Create agent` → Dialog with trigger (when…) / action (then…) / channel. Preview only. |
| **Draft Studio** `/ai/draft` | Left: purpose picker (Thank-you / Appeal / Grant report / Volunteer recruit) + tone + length + recipient picker (real contact search if cheap, else canned). Right: generated draft in an editable textarea with `Regenerate` / `Copy` / `Send to Email Campaign` (last one disabled with a "coming soon" tooltip). |
| **Action Board** `/ai/actionboard` | Kanban-ish columns `Today / This week / Watch`. Cards = next-best-action: *"Call Ramesh K — ₹1L donor, 94 days silent"* with a confidence chip and `Snooze` / `Done` (local state + undo toast). |
| **Engagement Scoring** `/ai/engagementscoring` | Score distribution histogram + a scored donor table (score, trend arrow, last gift, last touch). Row click → drawer showing the score's contributing factors as labelled bars. |
| **Lapse Prediction** `/ai/churnprediction` | Risk-banded list (High / Medium / Low) with counts as KPI tiles, a risk-over-time line, and a table of at-risk donors with `Predicted lapse` date and `Add to campaign`. |
| **Predictive Analytics** `/ai/predictiveanalytics` | Forecast chart — actual vs projected giving, 12 months forward, confidence band. Scenario selector (Conservative / Expected / Optimistic). Below: three KPI tiles (projected total, projected donor count, projected average gift). |
| **AI Reporting** `/ai/reporting` | Natural-language question box at the top with example chips. Answer renders as a chart **and** the equivalent table, with a `Show the filters I used` disclosure that lists the interpreted filter set — that disclosure is what makes the feature trustworthy, keep it. `Save as report` disabled with tooltip. |
| **Connections** `/ai/connections` | One row per module (Donations, Contacts, Grants, Events, Cases, Volunteers, Membership…) with: what the assistant may read, a Switch, last-indexed timestamp, record count. A prominent, non-dismissible note stating no data leaves the tenant. Switches are local state. |
| **Usage & Analytics** `/ai/analytics` | KPI tiles (actions this month, credits remaining, active users, top skill), usage-over-time area chart, per-user table, per-feature breakdown bar. |
| **AI Settings** `/ai/settings` | Sectioned form: default tone, default language, assistant display name, per-module enable matrix, data-retention choice, `Disable AI for this tenant` destructive-styled switch. Real RHF form, `isValid`-gated Save, **saves to nothing yet** — Save shows "Preview — not yet saved". |

---

## ⑥ Menu-move SQL (user-owned)

One file: **`sql-scripts-dyanmic/ai-module-promotion-seed.sql`**. Idempotent, re-runnable,
`BEGIN;`/`COMMIT;`, no DDL. Order:

1. **Module** — insert `AI` into `auth."Modules"` if absent; repair `IsActive/IsDeleted/OrderBy` if present.
2. **Group headers** — insert `AI_ASSISTANT`, `AI_GOVERNANCE` (`IsLeastMenu=false`, `ModuleId`=AI).
3. **Re-point `CRM_INTELLIGENCE`** — `UPDATE` its `ModuleId` to AI, `MenuName` to `'Insights'`,
   `ParentMenuId` to `NULL`, `OrderBy` to sit between the two new groups. Guarded on the wrong
   values so it is a no-op once correct.
4. **Re-point the six leaves** — `UPDATE auth."Menus" SET "ModuleId"=<AI>, "MenuUrl"='/ai/…'`
   for `ACTIONBOARD`, `AIDRAFT`, `AIREPORTING`, `CHURNPREDICTION`, `ENGAGEMENTSCORING`,
   `PREDICTIVEANALYTICS`. `AIDRAFT` additionally re-parents to `AI_ASSISTANT`.
   `MenuUrl` carries a **leading slash** and must be unique — it is how the nav builder and the
   sidebar active-state matcher identify a row.
5. **Insert the six new leaves** with `ModuleId`=AI and correct parents.
6. **Capabilities + MenuCapabilities** for the six new menus, following the existing naming and
   `OrderBy` run. No new `ISMENURENDER` row.
7. **RoleCapabilities** — grant the new menus (view + `ISMENURENDER`) to the same roles that
   already hold `ACTIONBOARD`, derived by a subquery, not a hardcoded role list.
8. **Fix D-4** — soft-delete the `('FEATURE:INTELLIGENCE','NLREPORTING')` map row and confirm the
   `AIREPORTING` row exists.
9. **`billing."FeatureMenuMaps"`** — hand-written rows mapping the six new menu codes to
   `FEATURE:INTELLIGENCE`. Curated by hand per rule ②-2.
10. **Verify block** — closing `SELECT`s: menu tree under module `AI` ordered by `OrderBy`; count
    of AI menus still pointing at a `/crm/` URL (**must be 0**); count of AI menus with no
    `ISMENURENDER` grant (**must be 0**).

**Open decision for the user:** `FEATURE:INTELLIGENCE` is currently `false` on FREE and `PLAN_50K`,
`true` on `PLAN_100K` and `CUSTOM`. If the AI module is meant to be *seen* by everyone as an upgrade
lever, the entitlement should stay off but the menu should render in a locked state — that is a
different mechanism from hiding it, and it is not in this build. Say which you want.

---

## ⑦ Explicitly out of scope

- Any real LLM call, API key, model config or streaming backend.
- Any new table, column, EF migration, GraphQL resolver or DTO.
- Deleting the `crm/intelligence` **menu codes** (they move; they do not die).
- The tenant-wide AI copilot sidebar (T-1 in the exploration doc) — that is shell-level and belongs
  in its own build, not inside this module.
- Wiring the credits meter to a real quota counter.

---

## ⑧ Files touched

**New — routes (12):** `app/[lang]/(core)/ai/{ask,skills,agents,draft,actionboard,engagementscoring,churnprediction,predictiveanalytics,reporting,connections,analytics,settings}/page.tsx`
**New — page configs:** `presentation/pages/ai/` (one folder per screen + `index.ts` barrel)
**New — components:** `presentation/components/page-components/ai/` — `ai-preview-chip.tsx`,
`ai-credits-meter.tsx`, `ask/{chat-thread,chat-composer,recent-chats,prompt-chips}.tsx`,
`skills/{skill-card,skill-dialog}.tsx`, `agents/{agent-card,agent-dialog}.tsx`, plus one per insight screen.
**New — canned data:** `presentation/components/page-components/ai/_data/*.ts`, one typed file per screen.
**New — SQL:** `sql-scripts-dyanmic/ai-module-promotion-seed.sql`
**Deleted:** the six `crm/intelligence/*` route folders and `presentation/pages/crm/intelligence/`
(the latter is the one-line stub).
**Modified:** `presentation/pages/crm/index.ts` (drop the intelligence export if present);
`billing-feature-menu-map-leaf-level-seed.sql` comment only if the `NLREPORTING` row is corrected at source.

---

## ⑨ Acceptance criteria

1. `grep -rn "error-page/Construction" "src/app/[lang]/(core)/ai"` → **0 matches**.
2. `find "src/app/[lang]/(core)/crm/intelligence" -type d` → **does not exist**.
3. `find "src/app/[lang]/(core)/ai" -name page.tsx | wc -l` → **12**.
4. `grep -rn "bg-primary-600\|bg-primary\b" src/presentation/components/page-components/ai` → **0 matches**.
5. `grep -rn "bg-\(red\|amber\|emerald\|blue\|violet\)-\(50\|100\)\|text-\(red\|amber\|emerald\|blue\|violet\)-\(700\|800\)" src/presentation/components/page-components/ai` → **0 matches**.
6. `grep -rln "brand-surface" src/presentation/components/page-components/ai | wc -l` → **≥ 8**.
7. `grep -rn "Preview" src/presentation/components/page-components/ai/ai-preview-chip.tsx` → present, and every one of the 12 page configs imports it.
8. `grep -c "MenuCode" sql-scripts-dyanmic/ai-module-promotion-seed.sql` → the file references all 13 codes (7 existing + 6 new) at least once.
9. `grep -rn "AI_ACTIONBOARD\|AI_CHURN\|AI_ENGAGEMENT\|AI_PREDICTIVE\|AI_AIDRAFT\|AI_AIREPORTING" sql-scripts-dyanmic/ai-module-promotion-seed.sql` → **0 matches** (rule ②-1: no renames).
10. `grep -n "/crm/intelligence" sql-scripts-dyanmic/ai-module-promotion-seed.sql` → appears **only** inside `WHERE` guards, never in a `SET`.
11. `grep -n "DELETE FROM auth" sql-scripts-dyanmic/ai-module-promotion-seed.sql` → **0 matches**.
12. `grep -n "ISMENURENDER" sql-scripts-dyanmic/ai-module-promotion-seed.sql` → appears in `SELECT`/`WHERE` lookups only, never in an `INSERT INTO auth."Capabilities"`.
13. Every canned-data file exports a named `const` with an explicit TS type — `grep -c ": *I\?[A-Z]" ` on each `_data/*.ts` > 0.
14. Every screen renders at 375 / 768 / 1280 px with no horizontal body scroll (manual).
15. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` → **exit 0**.

---

## ⑩ Build agent + work order

**Model:** Sonnet. **Scope:** frontend + one `.sql` file. No backend, no migration, no `dotnet` command.

1. Read `PSS-2.0-PRODUCT-SHELL-FEATURE-EXPLORATION.md` §⑥ (dummy rules) and
   `sql-scripts-dyanmic/platform-intimations-menu-capability-seed.sql` (the menu-seed house style).
2. **Confirm the `AI` module code is free** — if `auth."Modules"` already has an `AI` or `AIML` row
   in the seed history, **stop and report**; do not invent a second code.
3. Scaffold `presentation/pages/ai/` + the 12 route files as designed screens. `ask`, `skills`,
   `agents` first — those are the three the demo turns on.
4. Build shared bits: `ai-preview-chip.tsx`, `ai-credits-meter.tsx`, `_data/` typed canned sets.
5. Build the six moved insight screens.
6. Build the three governance screens.
7. Delete `crm/intelligence` routes and the `presentation/pages/crm/intelligence` stub; fix the
   `crm` barrel.
8. Write `ai-module-promotion-seed.sql` per §⑥. Verify block last. **Do not run it.**
9. `npx tsc --noEmit --incremental false` → must exit 0. Then walk §⑨ 1-13 and paste the outputs.
10. Report: the D-4 decision taken, and the §⑥ entitlement question restated for the user.

---

## ⑪ Build Log

*(newest first, keep the last 5 sessions)*

### 2026-08-11 — AI module promotion, full build

**Delivered.** All twelve screens, twelve page configs, twelve routes, both barrel
registrations, the shell credits-meter wiring, the deletion of `crm/intelligence`, and
`sql-scripts-dyanmic/ai-module-promotion-seed.sql`. `npx tsc --noEmit --incremental false`
→ **exit 0**.

**Acceptance (§⑨).** 1 ✓ (0) · 2 ✓ (both dirs gone) · 3 ✓ (12) · 4 ✓ (0) · 5 ✓ (0) ·
6 ✓ (22 files) · 7 ✓ (`ai-preview-chip.tsx`, imported by all 12) · 8 ✓ (all 15 codes
present) · 9 ✓ (0) · 10 ✓ (`/crm/` appears only in a comment and the 10b `WHERE` guard,
never a `SET`) · 11 ✓ (0) · 12 ✓ (`ISMENURENDER` in SELECT/WHERE only; 0 inserts into
`auth."Capabilities"`) · 13 ✓ after fix · 14 manual · 15 ✓ (exit 0).

**Findings / decisions taken during the build:**

* **Module `OrderBy` is UNIQUE on `(OrderBy, IsActive)`.** "Immediately after CRM" is not
  assignable — ORGANIZATION already holds CRM+1. §1 of the seed takes the smallest FREE
  active OrderBy greater than CRM's via `generate_series`, so AI lands as close after CRM
  as the numbering allows without renumbering any live module row.
* **D-4 resolved in favour of `AIREPORTING`.** `menu-activate-mvp-feature-areas.sql`
  activates `AIREPORTING`; `NLREPORTING` has no menu row at all. §8 soft-deletes the
  phantom map row and §9 re-asserts `AIREPORTING` in the same transaction.
* **Group headers needed grants too.** The prompt covered the six new leaves; without
  `ISMENURENDER` on `AI_ASSISTANT` / `AI_GOVERNANCE` the leaves would have had no section
  to render under. Added, same derived audience.
* **`MenuUrl` written WITH a leading slash** per §⑥. Existing seeds omit it, but
  `usePanelMenu.normalizeHref` collapses `^/+` and re-prefixes exactly one — both forms
  normalise identically, so the §⑥ form is safe.
* **Barrel collisions.** `SettingsPage` / `AnalyticsPage` / `ReportingPage` already exist
  in other modules, so every AI screen is re-exported under an `Ai…` alias before joining
  the global `page-components` barrel.
* **`.next/types` had to be cleared** after the `crm/intelligence` route deletion — the
  stale generated route types still imported the removed modules and produced 18 `TS2307`
  errors in generated files only. `rm -rf .next/types`; Next regenerates on next build.

**Still open (user's call):** `FEATURE:INTELLIGENCE` is `false` on FREE and `PLAN_50K`,
`true` on `PLAN_100K` and `CUSTOM`. Should the AI module render locked-but-visible on the
lower plans as an upgrade lever, or stay hidden? §9 maps all fifteen AI menu codes to that
one feature, so the answer is a single behaviour switch, not a re-map.

**Not run:** the seed. `sql-scripts-dyanmic/ai-module-promotion-seed.sql` is user-applied.
