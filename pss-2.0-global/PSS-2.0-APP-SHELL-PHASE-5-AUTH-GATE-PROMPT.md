# PSS 2.0 — App Shell Phase 5: Auth gate correctness + RouteGuard retirement

**Status:** CODE PASS COMPLETE (2026-08-08, staged not committed, `tsc --noEmit` exit 0, guide-reviewed §⑨) — §⑤ ACCEPTANCE NOT RUN
**Scope:** Frontend only. No backend, no migration, no seed, no SQL, no menu/capability data change.
**Shape:** One code pass (§④), then a short manual acceptance pass (§⑤) the user runs when convenient. The code pass is **not** gated on the acceptance pass and needs no API, no dev server and no login to write.

> Phase 4 closed the shell's three F-5 correctness bugs. This phase closes the *auth boundary* around it. It is deliberately small: one config list, three layout edits, two file deletions.

---

## ⓪ Why this phase exists

Phase 3 §3a.6 left `MASTER_URL` alive for exactly one reason — `route-guard.tsx` still imported it. Phase 4 §⑤ raised `route-guard.tsx` as an open decision and explicitly refused to resolve it, because restoring vs. deleting a security component is a call that needs evidence, not a guess.

The evidence now exists, and it inverts the assumption everyone was carrying:

**`middleware.ts` at the frontend root already gates every route.** It is not under `src/`, which is why it is easy to miss. It exports `default auth((req) => { ... })` — the NextAuth v5 `auth()` middleware wrapper — which invokes the `authorized({ auth, request })` callback in `src/infrastructure/lib/configs/auth.ts` **before** the locale-redirect handler body runs. When `authorized` returns `false`, NextAuth redirects to `pages.signIn` (`LOGIN_URL`, `/en/login`).

Two consequences follow, and they point in opposite directions:

1. **`RouteGuard` is redundant, not missing.** The unauthenticated deep link it was supposed to catch is already caught upstream, at the edge, before the page renders. A commented-out client guard behind a live server guard is dead weight — and it is the only thing still holding `MASTER_URL`.

2. **The live gate is over-broad, and that is a real production bug.** `publicRoutes` in `authorized` lists six entries. The `(public)` route group has ten-plus page routes and **none of them are on the list**. Every one falls through to `return !!auth`. An anonymous donor opening a crowdfunding page, a P2P fundraiser link, an event registration page or an embed widget is redirected to `/en/login`.

Failure mode 2 is invisible in normal development because a developer always has a session. It only appears to a logged-out visitor — which is the entire audience for those pages.

---

## ① Grounding — read before writing

| File | Why |
| --- | --- |
| `PSS_2.0_Frontend/middleware.ts` | The live gate. Note it is at the **repo root**, not under `src/`. |
| `PSS_2.0_Frontend/src/infrastructure/lib/configs/auth.ts` | `publicRoutes` (L12-19) and `authorized()` (L80-105). The whole of F-6.1 lives here. |
| `PSS_2.0_Frontend/src/presentation/components/auth/route-guard.tsx` | 47 lines, body commented out end to end, `return <>{children}</>` at L45. |
| `PSS_2.0_Frontend/src/application/configs/navigation-configs/CommonUrlConfig.ts` | `LOGIN_URL` (keep) and `MASTER_URL` (target of F-6.3). |
| `PSS_2.0_Frontend/src/app/[lang]/(core)/layout.tsx` | Renders `<RouteGuard requireAuth>` at L29. |
| `PSS_2.0_Frontend/src/app/[lang]/(master)/layout.tsx` | Renders it at L16. Its own comment at L19-22 already calls `RouteGuard` dead code and names `PlatformGate` as the real control-plane gate. |
| `PSS_2.0_Frontend/src/app/[lang]/(setup)/layout.tsx` | Renders it at L20. |

**Invariant for this phase — INV-9:** *there is exactly one authentication boundary, and it is the middleware.* Anything else that redirects on session state is either a **capability** gate (`PlatformGate`, `RoleCapabilityProvider`) or a **plan** gate (`PlanEnforcementProvider`), not an auth gate. Do not add a second auth gate at any layer.

---

## ② Hard constraints

1. **Frontend only.** No backend change, no migration, no seed, no SQL, no `auth.Modules` / menu / capability data change.
2. **No URL changes.** No route moves, no renames, no `Role.DefaultLandingUrl` reseeding.
3. **Do not touch `PlatformGate`.** It is the Phase 2.1 F-3 control-plane gate and is correct. This phase does not weaken, widen or relocate it.
4. **Do not touch `MenuLoader`'s commit-gated scrim logic** in `app-shell-provider.tsx`.
5. **Do not change the session strategy, `maxAge`, the JWT callbacks, or the credentials provider.** F-6.1 edits the `publicRoutes` array and the matching logic inside `authorized` — nothing else in `auth.ts`.
6. **`BaseUrlConfig.ts` is user-managed.** Never edit it, never stage it, never revert it. It will be dirty; leave it dirty.
7. **Never `git commit`.** Stage only (`git add`) and report what was staged. Never `git push`, amend, or tag. Never add a `Co-Authored-By: Claude` trailer or a "Generated with Claude Code" line to any commit message, suggested message, or PR body.
8. **Never run `dotnet build`** and never run `ef migrations add` or edit `ModelSnapshot` — the user owns backend builds and migrations.
9. **Do not probe ports, processes, or API liveness**, and do not gate any deliverable on environment readiness. The user starts the API and will report failures directly.
10. Remember `PSS_2.0_Frontend` is a **nested git repo** — stage from inside it, not from `pss-2.0-global`.

---

## ③ Fix list

### F-6.1 — `publicRoutes` does not cover the `(public)` route group *(the actual bug)*

**Symptom:** a logged-out visitor opening any anonymous-donor page is redirected to `/en/login`.

**Cause:** `authorized()` allows a path only if it is in `publicRoutes`, starts with `/_next`, `/assets`, `/docs`, or contains a dot. Everything else returns `!!auth`. The `(public)` route group is a *route group* — the parentheses do not appear in the URL — so those pages present as ordinary top-level paths (`/en/crowdfund/abc`) and match nothing on the list.

**Required first step — enumerate, do not copy this list.** Glob `PSS_2.0_Frontend/src/app/[lang]/(public)/**/page.tsx` and `PSS_2.0_Frontend/src/app/[lang]/(auth)/**/page.tsx` and derive the URL prefixes yourself. At the time of writing the `(public)` set was:

`/event` · `/pray` · `/volunteer` · `/templates/preview` · `/p2p` · `/crowdfund` · `/embed` · `/p` · `/preview` · `/peopleserve`

(`/peopleserve` sits under a nested `(marketing)` group — also parenthesised, also absent from the URL. `/p` and `/embed` are single-segment prefixes; be precise about prefix matching so `/p` does not accidentally admit `/portal`-adjacent or `/platform` paths.)

Also confirm the `(auth)` group's real paths line up with the existing `/login`, `/register`, `/forgot-password` entries — Phase 2.1 established that `(auth)` is a route group and the real login path is `/en/login`, **not** `/en/auth/login`. If a route on disk has no matching entry, add it.

**Implementation notes:**
- Keep the existing locale-aware matching shape (`/{locale}{route}` and `/{locale}{route}/…`). Do not regress it to a bare `startsWith`.
- Prefix matching must be **segment-aware**: `/p` must match `/en/p/abc` and `/en/p` but must not match `/en/platform` or `/en/portal-x`. The current code already does this correctly via the `route/` suffix check — preserve that property for every new entry.
- Consider extracting the public prefixes to a single exported const so the list has one home. Keep it in `auth.ts`; do not create a new config file for ten strings.
- Leave a comment stating **why** each group is public, and that adding a route under `(public)` requires adding it here — the route group alone does not make a route public.

**Verify (static):** hand-trace `authorized` for six inputs and write the trace into the build log —
`/en/crowdfund/save-the-well` (anonymous → must be allowed), `/en/p2p/ride-2026/asha` (anonymous → allowed), `/en/embed/x` (anonymous → allowed), `/en/crm/contacts` (anonymous → **must be denied**), `/en/platform/dashboards` (anonymous → **denied**), `/en/portal/dashboard` (anonymous → allowed, `/portal` is already listed and stays listed).

---

### F-6.2 — Retire `RouteGuard`

`RouteGuard` returns its children untouched. The middleware performs the redirect it was written to perform. Keeping a neutered security component in the tree is worse than not having it: it reads as protection that is not there.

1. Remove `<RouteGuard requireAuth={true}>` from `(core)/layout.tsx`, `(master)/layout.tsx` and `(setup)/layout.tsx`, keeping every child provider and its nesting order **exactly** as-is. In `(master)`, `CompanySettingsBootstrap` must stay a sibling of `RoleCapabilityProvider` in the same position, and `PlatformGate` must keep wrapping `AppShell`.
2. Remove the now-unused `RouteGuard` import from each of those three files.
3. `(auth)/layout.tsx` L8 has it commented out — delete that dead line too.
4. Delete `src/presentation/components/auth/route-guard.tsx`.
5. Before deleting, `Grep` the whole of `src` for `RouteGuard` and confirm there are no other consumers. **Do not rely on a single `Grep` returning empty** — this frontend has nested repos and large trees, and a scoped `Grep` has produced false negatives here before. Cross-check with a `Glob` for the filename and a `Select-String` sweep from PowerShell.

In each of the three layouts, replace the removed wrapper with a short comment recording that the auth boundary is the middleware (INV-9) and pointing at `middleware.ts` + `authorized()` in `auth.ts`. The next person to read `(core)/layout.tsx` should not have to rediscover this.

---

### F-6.3 — Remove `MASTER_URL`

Once F-6.2 lands, `MASTER_URL` has no live consumer. Confirm with a fresh sweep; at the time of writing the only remaining references were two explanatory comments (`(master)/masterdashboard/page.tsx` and `company-switcher-item.tsx`) and the declaration + re-export themselves.

1. Delete `MASTER_URL` from `CommonUrlConfig.ts`.
2. Delete it from the `navigation-configs/index.ts` re-export.
3. Leave the two comments in place but reword them so they do not name a constant that no longer exists.
4. **Do not delete the `/en/masterdashboard` route.** The URL still exists and still redirects; only the unused constant goes. This completes what Phase 3 §3a.6 deliberately deferred.

If the sweep turns up a live consumer this document did not anticipate, **stop and report it** rather than rewriting that consumer — it would mean the redirect is load-bearing somewhere and that is a separate decision.

---

## ④ Verification (static, no environment)

```
cd PSS_2.0_Frontend
rm -rf .next/types
npx tsc --noEmit --incremental false
```

Report the exit code **verbatim**. Deleting a component and an exported constant is exactly the change a stale incremental cache hides, so the `.next/types` wipe is not optional.

> **Concurrent-session hazard:** another session may be editing this tree. If you see `TS6053 File not found … matched by include pattern`, that is a phantom from a file that moved mid-run, not your error. Re-run once. One run is not authoritative; two clean runs are.

Do not start a dev server, probe a port, check whether the API is listening, or ask the user to confirm the environment.

---

## ⑤ Manual acceptance (deferred — the user runs this)

Short, and every point needs only a browser. **In a private/incognito window with no session:**

| # | Step | Expected |
| --- | --- | --- |
| A1 | Open a `(public)` donation page, e.g. `/en/crowdfund/<any-live-slug>` | Page renders. **No** redirect to `/en/login`. |
| A2 | Open a P2P fundraiser `/en/p2p/<campaign>/<fundraiser>` | Renders anonymously. |
| A3 | Open an event page `/en/event/<slug>` | Renders anonymously. |
| A4 | Open `/en/crm/contacts` | Redirected to `/en/login`. |
| A5 | Open `/en/platform/dashboards` | Redirected to `/en/login`. |
| A6 | Open `/en/portal/dashboard` | Reaches the member surface (its own `MemberAuthGuard` decides from there — not this phase's concern). |

**Then, signed in as a tenant user:**

| # | Step | Expected |
| --- | --- | --- |
| A7 | Navigate across two modules in the tenant shell | Shell chrome stays mounted; rail highlight follows the URL. No regression from Phase 4. |
| A8 | Load `/en/platform/dashboards` as a non-platform user | `PlatformGate` still blocks it. F-6.2 must not have weakened the control-plane gate. |
| A9 | Complete a login from a cold browser | Lands on the role's default landing URL, unchanged. |
| A10 | Browser Back across a module boundary | Rail highlight correct (Phase 4 F-5.3 still holds). |

A1-A3 are the ones that matter. If any of them still redirect, F-6.1 is incomplete — re-run the enumeration rather than special-casing the failing slug.

---

## ⑥ Deliverable

1. `auth.ts` — `publicRoutes` covering the enumerated `(public)` and `(auth)` routes, matching logic intact and segment-aware.
2. Three layouts with `RouteGuard` removed and an INV-9 comment in its place; the dead `(auth)/layout.tsx` line deleted.
3. `route-guard.tsx` deleted.
4. `MASTER_URL` removed from `CommonUrlConfig.ts` and the `navigation-configs` re-export; the `/en/masterdashboard` route untouched.
5. A **§⑧ Build Log** appended to this file: the six F-6.1 hand-traces, the enumerated route list you actually derived (not the one copied from §③), the `RouteGuard` and `MASTER_URL` sweep results with the tool used for each, the verbatim `tsc` exit code, any deviation with its reason, and anything left pending runtime confirmation.
6. `git add` **only**, from inside `PSS_2.0_Frontend`. Never commit. Never stage `BaseUrlConfig.ts`.

---

## ⑦ Known open items — raise, do not resolve

- **`sonner` in the edge bundle.** `auth.ts` imports `toast` from `sonner` for `events.signOut`, and `middleware.ts` imports `auth.ts`, so a UI toast library is pulled into the edge runtime. It evidently builds today. Do not fix it in this phase; note it in the build log.
- **`src/app/[lang]/crm/organization/donationgroup`** exists *outside* the `(core)` route group, so it renders with no shell, no `RoleCapabilityProvider` and no `PlanEnforcementProvider`. Whether that is deliberate or a stray leftover is a separate question. Note it; do not move it.
- **`/portal` and `MemberAuthGuard`.** `auth.ts` L8-11 already flags that the member surface has no real NextAuth provider and defers it to ISSUE-2. Out of scope here.

---

## ⑧ Build Log

**Session:** 2026-08-08 · **Status:** CODE PASS COMPLETE · **Acceptance (§⑤):** pending user run

---

### Route enumeration (derived, not copied)

`Glob` on `src/app/[lang]/(public)/**/page.tsx` returned **no files** — `[lang]` is a literal directory name but `[…]` is a glob character class, so the pattern never matched. Enumeration was redone with `Get-ChildItem -LiteralPath … -Recurse -Filter page.tsx` (and a second pass for `route.ts`, which the doc's page-only instruction would have missed).

**`(public)` — `page.tsx`:**

| On disk | URL prefix |
| --- | --- |
| `(public)/(marketing)/peopleserve` | `/peopleserve` |
| `(public)/crowdfund/[slug]` | `/crowdfund` |
| `(public)/embed/[slug]` | `/embed` |
| `(public)/event/[slug]` | `/event` |
| `(public)/p/[slug]` | `/p` |
| `(public)/p2p/[campaignSlug]`, `…/start`, `…/[fundraiserSlug]` | `/p2p` |
| `(public)/pray/[slug]` | `/pray` |
| `(public)/preview/onlinedonationpage/[id]` | `/preview` |
| `(public)/templates/preview/[code]` | `/templates/preview` |
| `(public)/volunteer/[slug]` | `/volunteer` |

**`(public)` — `route.ts` (NOT in the §③ list; found by the second sweep):**

| On disk | URL prefix |
| --- | --- |
| `(public)/payu/return/route.ts` | `/payu` |
| `(public)/event-payu/return/route.ts` | `/event-payu` |

These are payment-gateway return hops. The gateway POSTs the browser back to them with no session guarantee, and the middleware `matcher` excludes only `/api`, not these — so before this change a PayU return could have been bounced to `/en/login`, losing the transaction hand-off. Both are now listed. `/event` does **not** admit `/en/event-payu/return` (segment-aware), so both entries are required.

**`(auth)` — reconciled against the existing list:**

| On disk | Was listed? |
| --- | --- |
| `(auth)/login` → `/login` | yes |
| `(auth)/activate` → `/activate` | **no — added** |
| `(auth)/forgot` → `/forgot` | **no — added** |
| — | `/register` listed, no route on disk |
| — | `/forgot-password` listed, no route on disk |

Confirms Phase 2.1: `(auth)` is a route group, the real login path is `/en/login`, not `/en/auth/login`. `/register` and `/forgot-password` were **kept** (see Deviations).

**`(member)` — unchanged:** `/member-login`, `/portal` (5 pages under `portal/`), both already listed.

Final `PUBLIC_ROUTES` (exported const, `auth.ts`, 20 entries): `/login` `/activate` `/forgot` `/register` `/forgot-password` `/api/auth` `/member-login` `/portal` `/crowdfund` `/p2p` `/event` `/pray` `/volunteer` `/p` `/embed` `/preview` `/templates/preview` `/peopleserve` `/payu` `/event-payu`.

Matching logic **unchanged** — still `pathname === \`/${locale}${route}\`` or `pathname.startsWith(\`/${locale}${route}/\`)`, with the no-locale fallback intact. Only the array was edited, per constraint 5.

---

### F-6.1 hand-traces (`authorized`, anonymous unless noted)

| # | Input | locale | Matching entry | `isPublicRoute` | Return | Expected |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `/en/crowdfund/save-the-well` | `en` | `/crowdfund` — `startsWith("/en/crowdfund/")` ✔ | true | **true (allowed)** | allowed ✅ |
| 2 | `/en/p2p/ride-2026/asha` | `en` | `/p2p` — `startsWith("/en/p2p/")` ✔ | true | **true (allowed)** | allowed ✅ |
| 3 | `/en/embed/x` | `en` | `/embed` — `startsWith("/en/embed/")` ✔ | true | **true (allowed)** | allowed ✅ |
| 4 | `/en/crm/contacts` | `en` | none | false | falls through: not `/_next`, not `/assets`, not `/docs`, no `.` → `!!auth` = **false (denied → LOGIN_URL)** | denied ✅ |
| 5 | `/en/platform/dashboards` | `en` | none | false | `!!auth` = **false (denied → LOGIN_URL)** | denied ✅ |
| 6 | `/en/portal/dashboard` | `en` | `/portal` — `startsWith("/en/portal/")` ✔ | true | **true (allowed)** | allowed ✅ |

**Segment-awareness spot-checks inside trace 5** (`/en/platform/dashboards`): `/p` → `=== "/en/p"` false, `startsWith("/en/p/")` false (the string is `/en/pl…`); `/portal` → `startsWith("/en/portal/")` false; `/payu`, `/preview`, `/peopleserve` → all false. `/p` also does not admit `/en/p2p/…` or `/en/payu/return`; it admits exactly `/en/p` and `/en/p/…`, as required. `/templates/preview` admits `/en/templates/preview/CODE` but bare `/templates` is deliberately **not** listed, so a future authenticated `/en/templates/*` screen stays gated.

---

### F-6.2 — RouteGuard sweep and retirement

Three independent tools, per §③'s "do not rely on a single Grep":

| Tool | Scope | Result |
| --- | --- | --- |
| `Grep` | `PSS_2.0_Frontend/src` | 5 files with live refs (3 layouts + `(auth)` commented line + the component), 4 comment-only mentions |
| `Glob` `**/route-guard*` | `PSS_2.0_Frontend` | exactly 1 file — `src/presentation/components/auth/route-guard.tsx` |
| PowerShell `Select-String` | whole `PSS_2.0_Frontend`, 5476 files, excluding `node_modules` / `.next` / `.git` / `playwright-report` / `test-results` | same set. Extra hits only in `tsconfig.tsbuildinfo` and `.vs/` (IDE index / build artifacts, not source) |

*(The first PowerShell attempt exited 1 and flooded output because `tsconfig.tsbuildinfo` is a single multi-MB line; the include list was narrowed and re-run. No source file was missed.)*

**No live consumer outside the three layouts.** Applied:

1. `(core)/layout.tsx` — wrapper + import removed. `RoleCapabilityProvider → PlanEnforcementProvider → AppShell` nesting order **unchanged**; the block was re-indented one level only.
2. `(master)/layout.tsx` — wrapper + import removed, replaced by a `<>…</>` fragment because `CompanySettingsBootstrap` and `RoleCapabilityProvider` are siblings and the layout would otherwise return two roots. `CompanySettingsBootstrap` stays first, `PlatformGate` still wraps `AppShell`.
3. `(setup)/layout.tsx` — wrapper + import removed; the `min-h-screen` div is now the root.
4. `(auth)/layout.tsx` L7-8 — dead commented line deleted.
5. `src/presentation/components/auth/route-guard.tsx` — **deleted**.

An INV-9 comment naming `middleware.ts` + `authorized()` in `auth.ts` was added in place of the removed wrapper in all three layouts, plus one in `(auth)/layout.tsx`.

---

### F-6.3 — MASTER_URL removal

Fresh sweep (`Grep` on `src` + PowerShell `Select-String` on the whole repo) found exactly 6 references: the declaration, the `index.ts` re-export, two inside `route-guard.tsx` (deleted by F-6.2), and the two explanatory comments §③ predicted. **No unanticipated live consumer.**

- Deleted from `CommonUrlConfig.ts` (replaced by a note that the route survives, the constant does not).
- Deleted from the `navigation-configs/index.ts` re-export.
- `(master)/masterdashboard/page.tsx` comment reworded — it claimed three live call sites (useAuth null-landing fallback, route-guard, company-switcher-item); **all three were already stale** (Phase 2.1 F-3 repointed the first and third at `resolveLandingRoute`; grep confirms neither `useAuth` nor `company-switcher-item` referenced the constant). Now records the route as a bookmark redirect.
- `company-switcher-item.tsx` L92 comment reworded to name the literal path, not the constant.
- **`/en/masterdashboard` route untouched** — `page.tsx` still `redirect()`s to `/{lang}/platform/dashboards`.

Post-change sweep: **0 live references** to `RouteGuard` or `MASTER_URL`. The 7 remaining string hits are all deliberate historical-note comments written by this pass.

---

### Verification (§④)

```
cd PSS_2.0_Frontend
rm -rf .next/types
npx tsc --noEmit --incremental false
```

Run 1 — **`EXIT_CODE=0`**
Run 2 — **`EXIT_CODE=0`**

Both runs wiped `.next/types` first. Two clean runs, no `TS6053` phantom, no concurrent-session interference. No dev server started, no port probed, no API liveness checked.

---

### Deviations (4)

1. **`/register` and `/forgot-password` kept in `PUBLIC_ROUTES` despite having no route on disk.** §③ said "if a route on disk has no matching entry, add it" — it did not ask for the reverse. A public entry for a non-existent route is inert (the route 404s either way), whereas removing it would silently gate a signup/reset page the moment someone adds one. Both are commented as such. Flagging in case the intent is to prune them.
2. **Two `route.ts` routes added beyond the enumeration §③ scoped.** §③ said to glob `page.tsx`; `(public)/payu/return` and `(public)/event-payu/return` are `route.ts` handlers that are just as anonymous and just as gated. Reasoned above.
3. **Four comment-only edits outside the §⑥ deliverable list** — `platform-gate.tsx`, `company-settings-bootstrap.tsx`, `(master)/ops/notifications/page.tsx`, `(public)/preview/onlinedonationpage/[id]/page.tsx` each described `RouteGuard` as a live (if inert) part of the tree. Leaving comments that name a deleted file is the exact rediscovery cost F-6.2 set out to remove. No behaviour touched; `PlatformGate` itself is unmodified (constraint 3).
4. **`(master)/layout.tsx` gained a `<>` fragment root.** Structural necessity of removing a wrapper around two siblings, not a design change.

---

### Known open items (§⑦ — raised, not resolved)

- **`sonner` in the edge bundle.** Confirmed still present: `auth.ts` L4 imports `toast` for `events.signOut`, and `middleware.ts` L1 imports `auth.ts`, pulling a UI toast library into the edge runtime. Untouched — it builds today. Worth a follow-up: `events.signOut` firing a client toast from an edge callback is likely a no-op anyway.
- **`src/app/[lang]/crm/organization/donationgroup`** confirmed present *outside* `(core)` — `crm` is a real top-level directory alongside the five route groups. It renders with no shell, no `RoleCapabilityProvider`, no `PlanEnforcementProvider`. Not moved. Note: it is also not in `PUBLIC_ROUTES`, so it is still auth-gated — this is a chrome/provider question, not a security one.
- **`/portal` and `MemberAuthGuard`** — still ISSUE-2. `/portal` stays public at the middleware layer; the client-side member gate is unchanged.

### Pending runtime confirmation

Everything in §⑤. The code pass is static-verified only — no environment was touched. A1-A3 (anonymous crowdfund / p2p / event) are the ones that prove F-6.1; A8 (`PlatformGate` still blocks a non-platform user) is the one that proves F-6.2 did not weaken the control plane.

### Staged

`git add` from inside `PSS_2.0_Frontend` — 13 modified + 1 deleted. **`BaseUrlConfig.ts` deliberately NOT staged** (user-managed, left dirty). **Not committed.**

---

## ⑨ Guide-session review of the code pass — 2026-08-08

Verified against the tree, not against the report. Re-ran the enumeration, the collision analysis, the reference sweep and the typecheck independently.

**Accepted — all three fixes and all four deviations.**

### What was re-verified

| Claim | How checked | Result |
| --- | --- | --- |
| `(auth)` = `login`, `activate`, `forgot` | directory listing | matches; `/activate` and `/forgot` were genuinely missing before |
| `(public)` = 12 segments incl. `payu`, `event-payu`, `templates` | directory listing | matches exactly; nothing over- or under-listed |
| Matching logic untouched (constraint 5) | `git diff --cached` on `auth.ts` | confirmed — only the array and the identifier changed |
| `PlatformGate` logic untouched (constraint 3) | `git diff --cached` | comment-only; the `useEffect` and redirect are byte-identical |
| Provider nesting preserved in all three layouts | `git diff --cached` | confirmed, including `CompanySettingsBootstrap` staying ahead of `RoleCapabilityProvider` |
| 0 live `RouteGuard` / `MASTER_URL` refs | PowerShell `Select-String` over `src` + `middleware.ts` | 6 hits, **all comments** |
| Typecheck | `rm -rf .next/types && npx tsc --noEmit --incremental false` | **exit 0** (independent third run) |

### The collision check §③ asked for, done from the other direction

The build log proves no public prefix admits the *example* authenticated paths. I checked the complete set instead — every top-level segment behind the gate:

`accesscontrol` · `billing` · `crm` · `general` · `no-access` · `organization` · `reportaudit` · `setting` · `masterdashboard` · `ops` · `platform` · `setup`

Under segment-aware matching, **none** is admitted by any of the 20 `PUBLIC_ROUTES` entries. The only near-miss is `/p` vs `platform`, which the trailing-slash form rejects (`/en/platform` is neither `/en/p` nor prefixed by `/en/p/`). The gate is tight.

### Two residuals — neither blocks acceptance

1. **`/preview` and `/templates/preview` are admin tools, not donor surfaces.** They are the only two entries in `PUBLIC_ROUTES` whose audience is *not* anonymous. Both are correctly placed — each page's own header comment explains it lives under `(public)` to inherit donor chrome rather than admin chrome — and both rely on the **server** to reject an unauthenticated GraphQL read, which is the right place for that check. Net effect of this phase on them: an anonymous visitor now reaches an empty/error page instead of a login redirect. That is a cosmetic downgrade, not a data exposure. **Do not "fix" it by removing them from the list** — that would re-gate the admin preview flow the pages were deliberately moved to avoid. If it matters, the fix is an empty-state on the page, not a routing change.

2. **The dot-bypass predates this phase.** `authorized()` returns `true` for any path containing `.`, and the middleware `matcher` excludes `.*\..*` outright. A path like `/en/crm/x.y` therefore skips the auth check — it 404s, so there is nothing to reach, but the rule is broader than it needs to be. Untouched here and correctly so; it is a pre-existing shape, not a Phase 5 regression. Worth narrowing to a real file-extension pattern in a later pass.

### On the two `route.ts` additions (deviation 2)

This is the most valuable thing the build session found, and it was outside what §③ scoped. `(public)/payu/return` and `(public)/event-payu/return` are the browser-side hops a payment gateway POSTs the donor back through. They carry no session guarantee, the middleware `matcher` does not exclude them, and before this change they resolved to `!!auth` — meaning a real donation could have been bounced to `/en/login` at the moment of return, after the money moved. Correctly added. `/event` does not admit `/en/event-payu/return`, so the separate entry is required, as stated.

### On deviation 1

Keeping `/register` and `/forgot-password` is the right call. An entry for a route that does not exist is inert; removing it creates a trap for whoever adds the page later. Leave both.

**Nothing needs rework. The code pass is complete and correct as far as static analysis can establish it.** What remains is §⑤ — and within §⑤, A1-A3 are the points that actually prove the fix, and A8 is the one that proves the control plane did not weaken.
