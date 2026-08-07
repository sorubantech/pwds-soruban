# PSS 2.0 — Product Tour / Guided Walkthrough — Approach

**Status:** design only. Nothing built. No migration, no seed, no code.
**Companion:** `PSS-2.0-PRODUCT-TOUR-GUIDED-WALKTHROUGH-PLANNING-PROMPT.md` (the brief).
**Related:** `PSS-2.0-TENANT-FIRST-LOGIN-SETUP-WIZARD-REMAINING-BUILD-PROMPT.md` — different system, see §⓪.

---

## ⓪ Scope — and the line against the setup wizard

| | Setup Wizard | Product Tour |
|---|---|---|
| Purpose | collect **configuration** | teach the **product** |
| Blocks the app? | yes — login gate, `/setup` | no — runs on top of the real app |
| Runs when | tenant is not configured | tenant is configured, user is new to a surface |
| Data written | real domain data (settings, providers, staff) | only "this user saw this tour" |
| Fires how often | once per tenant | once per **user**, per **tour**, per **tour version** |

**Ordering is fixed: setup wizard → dashboard → tour.** A tour must never fire while `Companies.SetupWizardCompletedDate IS NULL`. That is a hard suppression rule (§④), not a preference.

The two systems share **nothing** — no table, no store, no component. The only touch point is that one-line check.

---

## ① The tour categories

This is the part that has to be right up front, because it decides the data model, the trigger engine, and the eligibility rules. Seven scopes, one enum column, `ops.ProductTours.Scope`.

| Scope | Surface | Audience | Anchored to | Fires when |
|---|---|---|---|---|
| `PLATFORM` | `(master)` | platform staff | platform nav + ops screens | first visit to the master dashboard |
| `TENANT_HOME` | `(core)` landing | tenant staff | tenant dashboard + main sidebar | first dashboard visit **after** setup completes |
| `MODULE` | `(core)/<module>` | staff with that module's menu visible | module landing screen | first visit to that module |
| `SCREEN` | one route | staff with that screen's capability | a single screen's controls | first visit to that route |
| `FEATURE` | any | anyone who can see the target | one element, wherever it appears (AI assistant, global search, notification bell) | first time the target renders and no higher-priority tour is queued |
| `MEMBER` | `(member)` | member-portal users | member portal nav | first member login |
| `WHATS_NEW` | any | everyone on a version | release highlights | after the app version they last saw is bumped |

**Precedence** when more than one is eligible on the same render:

```
PLATFORM / MEMBER   (surface-exclusive — nothing else can run on those surfaces)
TENANT_HOME  >  MODULE  >  SCREEN  >  FEATURE  >  WHATS_NEW
```

Ties broken by `Priority` then `SortOrder`. **Exactly one tour runs at a time; at most one auto-starts per session.** Everything else stays queued and gets its turn on a later visit. A user who opens five modules on day one should not be ambushed five times.

`ScopeKey` on the tour row is what makes `MODULE` / `SCREEN` / `MEMBER` addressable — module code for `MODULE`, route path for `SCREEN`, `NULL` for `PLATFORM` / `TENANT_HOME` / `FEATURE` / `WHATS_NEW`.

---

## ② Data model

Two homes, deliberately split:

- **Content lives in `ops`** — tours are authored by us, identical for every tenant. Platform-global, so per house rule every read needs `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true` guard.
- **Progress lives in `sett`** — per user, per tenant, so the global `CompanyId` query filter applies naturally and nothing extra is needed.

### ②.1 `ops.ProductTours`

| Column | Type | Notes |
|---|---|---|
| `ProductTourId` | int identity PK | |
| `TourCode` | varchar(60) | **unique**, e.g. `TOUR_TENANT_HOME`, `TOUR_CRM_DONATIONS` |
| `Scope` | varchar(20) | CHECK against the seven values in §① |
| `ScopeKey` | varchar(120) NULL | module code / route path; NULL where §① says NULL |
| `Title` | varchar(160) | internal/admin label, not user-facing copy |
| `TourVersion` | int, default 1 | bump to re-prompt (§⑪) |
| `Priority` | int, default 100 | lower runs first |
| `SortOrder` | int, default 0 | |
| `AutoStart` | bool, default true | false = replay-only, reachable from the Help menu |
| `RepromptOnVersionChange` | bool, default false | |
| `IsMandatory` | bool, default false | hides Skip. Use almost never — see §⑭ Q2 |
| audit + `IsActive` + `IsDeleted` | | standard base columns |

### ②.2 `ops.ProductTourSteps`

| Column | Type | Notes |
|---|---|---|
| `ProductTourStepId` | int identity PK | |
| `ProductTourId` | int FK → `ops.ProductTours`, Restrict | |
| `StepOrder` | int | **unique with `ProductTourId`** |
| `TargetKey` | varchar(120) NULL | the `data-tour` value (§⑥). NULL = un-anchored centred card, used for the welcome/closing step |
| `TitleKey` / `BodyKey` | varchar(160) | i18n keys, not copy (§⑦) |
| `Placement` | varchar(20) | `top` / `bottom` / `left` / `right` / `auto` |
| `RoutePath` | varchar(200) NULL | step lives on another route — the engine navigates, then waits |
| `InteractionMode` | varchar(20) | `PASSIVE` (everything blocked) or `INTERACTIVE` (the target itself is clickable and advances the step) |
| `IsSkippableIfMissing` | bool, default true | target absent → skip the step silently rather than dead-end |
| `MediaUrl` | varchar(400) NULL | optional image/gif in the popover |

### ②.3 `ops.ProductTourAudiences`

One row per rule. **OR within an `AudienceType`, AND across types.** No rows = everyone on that surface.

| Column | Notes |
|---|---|
| `ProductTourId` | FK |
| `AudienceType` | `ROLE` \| `CAPABILITY` \| `FEATURE` \| `PLAN` \| `MENU` |
| `AudienceValue` | role code / capability code / `FEATURE:*` or `CHANNEL:*` code / plan code / menu code |

So "the WhatsApp tour" is `FEATURE = CHANNEL:WHATSAPP` **and** `MENU = SET_WHATSAPP` — it cannot fire for a plan without the channel or a role that can't see the menu.

### ②.4 `sett.UserTourProgress`

| Column | Notes |
|---|---|
| `UserTourProgressId` | int identity PK |
| `CompanyId` | int FK → `app.Companies`, Restrict |
| `UserId` | int |
| `TourCode` | varchar(60) — **string, not an FK to `ops`** (see below) |
| `TourVersion` | int — the version the user actually saw |
| `Status` | varchar(20) CHECK `NOT_STARTED, IN_PROGRESS, COMPLETED, SKIPPED, DISMISSED` |
| `LastStepOrder` | int, default 0 — resume point |
| `StartedDate` / `CompletedDate` | timestamptz nullable |
| unique index | `(CompanyId, UserId, TourCode)` |
| index | `(CompanyId, UserId, Status)` |

**Why `TourCode` and not a FK:** tenant progress rows must not pin platform content rows. Retiring a tour should be a soft delete in `ops`, not a FK violation across schemas. The join is by code at query time.

`SKIPPED` = the user pressed Skip on this run. `DISMISSED` = "don't show me tours here again", a stronger opt-out that survives a version bump.

### ②.5 `sett.UserTourStepEvents` — **Phase 2**

`CompanyId, UserId, TourCode, TourVersion, StepOrder, EventType, OccurredDate`, where `EventType ∈ VIEWED | NEXT | BACK | SKIPPED | COMPLETED | TARGET_MISSING`. Append-only. This is the table that answers "which step do people quit on" and "which tour targets have rotted" — the only real reason to instrument at all. Not needed to ship Phase 1.

**All migrations are user-authored.** This document produces a spec; you write and apply the migration. Seeds go to `sql-scripts-dyanmic/` as executable scripts.

---

## ③ Eligibility — the intersection

A tour is eligible for a user only when **every** one of these passes:

1. **Surface** matches (`PLATFORM` tours only on `(master)`, etc.).
2. **Route** matches `ScopeKey` for `MODULE` / `SCREEN`.
3. **RBAC** — every `CAPABILITY` audience row is held by the user.
4. **Menu visibility** — every `MENU` audience row resolves to a menu the user can actually see. Reuse the existing menu store; do not re-derive.
5. **Entitlement** — every `FEATURE` audience row passes `IEntitlementService.HasFeatureAsync`. Fail-closed, cached, already the right dependency. Never query `billing.PlanEntitlements` directly.
6. **Progress** — no `COMPLETED` / `SKIPPED` / `DISMISSED` row for this `(TourCode, TourVersion)`, unless `RepromptOnVersionChange` and the version moved.
7. **Tour is `IsActive`, not `IsDeleted`.**

Rules 3–5 are not optional polish. **Spotlighting a menu item the user's role cannot see is the single most embarrassing failure mode of this feature** — the overlay dims the screen, the popover points at empty space, and the user is trapped in a tour about something they don't have.

Eligibility is computed **server-side**, once, and returned as a list. The client never assembles it from three stores and hopes.

---

## ④ Triggering, queueing, suppression

**One query at session start.** `eligibleTours` returns every eligible tour with its steps and the user's progress. Cached in the tour store. No per-route network call — route changes are matched against the cached list in memory.

Auto-start is attempted on route settle. It is **suppressed** — silently, no queue jump — while any of these hold:

| Suppression | Why |
|---|---|
| `SetupWizardCompletedDate IS NULL` | configuration comes first (§⓪) |
| any Dialog / Sheet / Drawer is open | you cannot dim a screen that already has a modal on it |
| a form is dirty | a tour that eats the next click loses their work |
| the page is still loading (datatable, widgets) | measuring a target mid-skeleton spotlights the wrong rectangle |
| another tour is running | one at a time, always |
| one tour already auto-started this session | no ambush chains |
| viewport `< md` | Phase 1 decision, §⑭ Q3 |
| the user has a `DISMISSED` row | they opted out; respect it |

When suppressed, the tour stays eligible and gets its turn next time. Nothing is marked skipped.

`prefers-reduced-motion` does **not** suppress — it drops the animations and keeps the tour.

---

## ⑤ The engine

### ⑤.1 Layering

```
z-index 1002   popover   — Back / Next / Skip. The only clickable things in PASSIVE mode.
z-index 1001   spotlight — pointer-events: none. Purely visual.
z-index 1000   overlay   — pointer-events: auto. Swallows every click before the app sees it.
```

Spotlight is one absolutely-positioned box matching the target's `getBoundingClientRect()`, with `box-shadow: 0 0 0 9999px rgba(0,0,0,.6)` — the shadow darkens the whole viewport and the box itself stays bright. One div, no canvas, no SVG mask needed unless we later want non-rectangular holes.

`INTERACTIVE` steps cut the overlay into four rects around the target instead, leaving the target genuinely clickable, and advance on its click.

### ⑤.2 Blocking

- Overlay eats all pointer events (`PASSIVE`).
- **Focus trap** inside the popover; `inert` on the app root so `Tab` and screen readers cannot escape into blocked content.
- `Escape` = Skip. Confirm first if the tour is more than 3 steps in.
- Body scroll locked except the engine's own `scrollIntoView({ block: 'center' })`.

### ⑤.3 Measuring and following

- `waitForElement(targetKey, timeoutMs)` using `MutationObserver`. On timeout: if `IsSkippableIfMissing` → skip the step, emit `TARGET_MISSING`, continue. If not skippable → end the tour cleanly and log. **Never** leave a dimmed screen pointing at nothing.
- Reposition on scroll and resize (`autoUpdate` from Floating UI, or the library's equivalent). A spotlight that drifts off its button is worse than no spotlight.
- Popover placement via Floating UI middleware: `offset` → `flip` → `shift` → `arrow`. Don't hand-roll edge collision.

### ⑤.4 Files and conventions

Store convention in this codebase is `src/application/stores/<domain>-stores/<name>-store.ts` with a paired `<name>-istore.ts` interface — verified on disk, ~126 stores follow it. So:

```
src/application/stores/tour-stores/tour-store.ts
src/application/stores/tour-stores/tour-istore.ts
src/presentation/components/custom-components/product-tour/   — engine + overlay + popover
src/presentation/providers/TourProvider.tsx                    — verify the real providers folder before creating
```

`TourProvider` mounts **once per surface** in `(core)/layout.tsx`, `(master)/layout.tsx`, `(member)/layout.tsx`. Never in `(setup)` or `(auth)`.

### ⑤.5 Library

**Recommendation: `driver.js`, wrapped in our own `ProductTour` component.** Tiny, zero dependencies, framework-agnostic (no fight with the app router), and it does exactly the overlay + spotlight + popover job. We own the step machine, eligibility, persistence and analytics regardless — the library is only the rendering primitive, so wrapping it keeps the swap cheap.

Alternatives considered: `react-joyride` (more React-idiomatic, but brings its own state model that duplicates ours), `shepherd.js` (fine, heavier), `intro.js` (**commercial licence required for commercial use — check before anyone imports it**).

Buying instead (Pendo / WalkMe / Appcues / Userpilot) is a real option and is §⑭ Q7. It moves tour authoring to non-developers, which is its whole value — but it is a third-party script running on every page of a multi-tenant donor-data application, so it is a privacy decision before it is a product one.

---

## ⑥ The `data-tour` contract

Steps target a **stable attribute**, never a CSS class, never a DOM path.

```tsx
<button data-tour="crm.donations.create">+ New Donation</button>
```

Naming: `<module>.<screen>.<element>`, lower-kebab within segments. `PLATFORM` keys prefix `platform.`; shell-level keys prefix `shell.` (`shell.sidebar.crm`, `shell.header.search`, `shell.header.notifications`).

Three rules that keep this from rotting:

1. **A registry file** — `src/application/constants/tour-targets.ts` — is the single list of valid keys. Components import from it; nobody types a raw string.
2. **Deleting or renaming a `data-tour` attribute is a breaking change.** It requires updating the tour steps in the same change.
3. **A build-time check** fails if a seeded step references a key not in the registry. Cheap to write, and it is the only thing standing between us and silently broken tours after a refactor.

---

## ⑦ Content and localisation

The DB stores **i18n keys**; the copy lives in the existing frontend translation files, alongside every other string in the product.

- Reuses the translation pipeline we already have — no new table, no second place to look for user-facing text, and translators work in one system.
- Cost: copy changes ship with a frontend release, so product cannot edit a tooltip without a deploy.

That trade is right while we are the authors. If tours are ever handed to a non-developer, this flips to a `ProductTourStepTranslations` table — §⑭ Q1 decides it. **Verify the exact translation mechanism (`trans` / dictionary loader) before the build prompt names a file.**

Copy rules, non-negotiable:
- **Max 5 steps per tour.** Drop-off past 5 is brutal.
- Each step answers: what it is, what it does for *you*, what to do next. Three short lines.
- No feature that the user cannot reach right now.

---

## ⑧ Backend surface

HotChocolate strips `Get` and appends `Input` — so `GetEligibleTours` → `eligibleTours`, `TourProgressDto` → `TourProgressDtoInput`. **tsc cannot see GraphQL field names**, so a wrong name compiles clean and fails at runtime only. Verify against the resolver, not against memory.

| Operation | Shape | Notes |
|---|---|---|
| query `eligibleTours` | → `[TourDto]` with nested steps + this user's progress | one call per session; §③ does all the filtering server-side |
| mutation `recordTourProgress` | `TourProgressDtoInput { tourCode, tourVersion, status, lastStepOrder }` | idempotent upsert on `(CompanyId, UserId, TourCode)` |
| mutation `recordTourStepEvents` | batched array | **Phase 2** |

**On write frequency — and why this is not the setup wizard.** The wizard is deliberately one submit at the end. The tour is the opposite and that is correct: progress is written on **start**, on **each step change** (fire-and-forget, never blocking the UI), and on **complete / skip / dismiss**. Resume is the whole point — a user who closes the tab at step 3 should return to step 3. Do not "consolidate" these into one call.

Scoping is `GetCurrentUserStaffCompanyId()`. `ops` reads need `IgnoreQueryFilters()` + explicit `IsDeleted != true`.

---

## ⑨ Analytics — Phase 2

Three questions worth answering, and nothing else:

1. **Where do people quit?** Step-level drop-off per tour. If 60% leave at step 3, step 3 is wrong.
2. **Which targets have rotted?** `TARGET_MISSING` count per `TargetKey`. This is a bug report, not a metric — a non-zero count means a refactor broke a tour.
3. **Completion rate per scope.** Tells us whether module tours are worth authoring more of.

---

## ⑩ Accessibility and responsive

- Focus trap + `inert` on the app root (§⑤.2). Without these, keyboard and screen-reader users tab straight into content the tour has visually disabled — the worst kind of half-implementation.
- `role="dialog"` + `aria-modal="true"` on the popover; step changes announced via `aria-live="polite"` ("Step 2 of 5, AI Assistant").
- Full keyboard: `Enter`/`→` Next, `←` Back, `Esc` Skip.
- `prefers-reduced-motion` → no transitions, tour still runs.
- Focus returns to the element that started the tour when it ends.
- **Below `md`**: Phase 1 does not auto-start. A spotlight on a collapsed hamburger menu teaches nothing. Phase 2 can add a bottom-sheet variant with the nav pre-opened. §⑭ Q3.

---

## ⑪ Lifecycle — versioning and replay

- **Bumping `TourVersion`** re-prompts only users whose `RepromptOnVersionChange` tour says so, and only those with `Status = COMPLETED`. `DISMISSED` is never re-prompted — that is what makes it different from `SKIPPED`.
- **Replay** — a "Product tours" entry in the Help menu lists every tour eligible on the current surface, run-again on click. This is what makes tours safe to keep short: nobody has to cram, because it is always retrievable. `AutoStart = false` tours are replay-only and live here.
- **Retiring** a tour is a soft delete in `ops` (`IsDeleted = true, IsActive = false`), never a `DELETE`. Progress rows keep their history.

---

## ⑫ Phasing

| Phase | Contents | Why this cut |
|---|---|---|
| **1 — engine + two tours** | tables ②.1–②.4, `eligibleTours` + `recordTourProgress`, the engine (§⑤), the `data-tour` registry + build check, `TENANT_HOME` and `PLATFORM` tours (5 steps each), Help-menu replay | proves the whole chain end-to-end on the two surfaces that matter most, with the smallest content surface to maintain |
| **2 — modules + instrumentation** | `MODULE` and `SCREEN` scopes, `sett.UserTourStepEvents`, drop-off report, mobile bottom-sheet variant | content scales only after the engine is proven; analytics only once there is something to measure |
| **3 — reach + authoring** | `FEATURE` and `WHATS_NEW` scopes, `MEMBER` portal tours, an authoring UI under `(master)`, translations table if §⑭ Q1 flips | the authoring UI is the expensive part and is worthless before the model is stable |

---

## ⑬ Risks

| Risk | Mitigation |
|---|---|
| **DOM coupling** — refactor silently breaks tours | `data-tour` registry + build-time check + `TARGET_MISSING` telemetry (§⑥, §⑨) |
| **Tour points at something the user can't access** | eligibility intersects RBAC ∩ menu ∩ entitlement, server-side (§③) |
| **Tour fires at the wrong moment** — over a modal, mid-form, mid-skeleton | the suppression table (§④) |
| **Tour fatigue** — five tours on day one | one auto-start per session, precedence order, max 5 steps (§①, §⑦) |
| **Tenant-customised dashboards** — widget targets may not exist | `IsSkippableIfMissing = true` by default; anchor `TENANT_HOME` steps to the shell (sidebar, header), not to configurable widgets |
| **Third-party tool leaks donor data** | §⑭ Q7 is a privacy review, not a tooling preference |

---

## ⑭ Open questions — decisions needed before the build prompt

1. **Who authors tour copy — you, or a non-developer?** Decides §⑦: i18n keys in FE files (developer-authored, ships with release) vs a translations table + authoring UI (anyone edits, more build).
2. **Is `IsMandatory` allowed at all?** A tour that cannot be skipped is a support ticket generator. My recommendation is to ship the column but never set it true. Confirm.
3. **Mobile:** suppress below `md` for Phase 1, or is a mobile tour required from day one?
4. **`PLATFORM` scope audience** — which platform-staff roles get the ops tour? Everyone on `(master)`, or specific role codes?
5. **Is `(member)` in scope at all?** Phase 3 above assumes yes-eventually. If the member portal is not a priority, I drop the scope and the enum value.
6. **Do the `FEATURE` targets exist yet** — AI assistant, global search, quick actions, notification centre? The brief names them; I have not verified them on disk. If some are not built, they leave the Phase 1 content set.
7. **Buy or build?** Pendo / WalkMe / Appcues move authoring to product people and give analytics free, at the cost of a third-party script on every page of a multi-tenant donor database. Build keeps everything in-house at the cost of an authoring UI we write ourselves. My recommendation: **build**, because the eligibility rules (§③) are deeply tied to our RBAC + entitlement model and no off-the-shelf tool can express them.
8. **Can a tenant customise or disable tours for their own users?** Recommendation: no in Phase 1 — a per-tenant "disable product tours" org setting in Phase 2 if anyone asks.

---

## ⑮ Build log

_(empty — nothing built)_
