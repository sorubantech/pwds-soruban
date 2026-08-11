# Fix: clicking a PLATFORM module menu re-renders the entire chrome

## Symptom

Clicking a menu in any other module (CRM, OPS, Member) transitions smoothly — only the page body
swaps. Clicking **any menu in the PLATFORM module** visibly repaints the whole shell: rail, sidebar
and header all blank and rebuild. It reads to the user as a full page reload.

Functionally the destination screen renders correctly. This is a UX defect, not a broken screen.

## What is already ruled out — do not re-investigate these

Each was checked by reading the source, not by guessing:

1. **Not a layout / route-group boundary.** `masterdashboard`, `ops` and `platform` all sit under
   `src/app/[lang]/(master)/` and share ONE layout (`(master)/layout.tsx`). The former
   `ops/layout.tsx` and `platform/layout.tsx` were deleted and `RoleCapabilityProvider` was hoisted
   into the shared parent. OPS and PLATFORM are structurally symmetric, so the App Router cannot be
   producing a boundary crossing for one and not the other.
2. **Not a stray hard navigation.** No `window.location.*` / `router.refresh()` exists in the rail,
   sidebar, or menu components. The 27 `window.location` hits in the codebase are all in logout,
   company-switch, public donation pages and template editors — none on the platform nav path.
3. **Not a 404 → hard navigation.** All five seeded platform URLs (`/platform/billing`,
   `/platform/communications`, `/platform/dashboards`, `/platform/staff`,
   `/platform/webhook-logs`) have a matching `page.tsx`.
4. **Not the middleware locale redirect.** `middleware.ts` (repo ROOT, not `src/`) only redirects
   when the locale segment is missing. CRM and OPS menu URLs are seeded locale-less exactly like the
   platform ones, so the middleware treats every module identically.
5. **Not capability-refetch blanking inside `usePlatformCapabilities`.** Line 72 already returns
   `loading: loading && !envelope`, so a background `cache-and-network` refetch does not re-report
   loading once codes are in hand.

## How module resolution works — and why only PLATFORM trips it

`useActiveModule` (`src/presentation/hooks/useActiveModule/index.ts`) owns `moduleCode` in the
global store and derives it **from the URL** on every navigation. It resolves in two passes:

**Pass 1 — synchronous**, `matchModuleByUrl` (`src/application/utils/module-url-match.ts`),
comparing the path against each module's single seeded `moduleUrl`, in three tiers:
- tier 1: longest `moduleUrl` that is a path prefix
- tier 2: deepest shared leading-segment prefix, minimum depth 2
- tier 3: first path segment equals the module's `moduleUrl` root

**Pass 2 — asynchronous**, `resolveModuleCodeByMenuUrl` (`src/application/utils/menu-route-index.ts`),
only reached when pass 1 returns `undefined`. It builds a reverse index of the user's granted menu
URLs, one `PARENTCHILD_MENU_QUERY` per accessible module.

**The asymmetry, stated verbatim in `menu-route-index.ts` lines 10-13:**

> "PLATFORM is the live example — `moduleUrl` is `/platform/dashboards`, but half its menus are
> seeded under `/ops/*`."

Every other module's screens live under its own `moduleUrl` root, so tier 1 or tier 3 answers
immediately and `moduleCode` never changes value across navigations within that module — and
because `apply()` writes only when the value actually differs, no store write occurs, so nothing
downstream re-fires. That is why CRM and OPS feel smooth.

PLATFORM has two distinct failure shapes, and the fixing session must determine which one is
firing before changing anything:

**Shape A — module-code thrash (most likely).** A platform menu seeded under `/ops/...` resolves via
tier 3 to the **OPS** module, not PLATFORM. So navigating between two platform menus flips
`moduleCode` PLATFORM → OPS → PLATFORM. `apply()` then genuinely writes on every click, which
re-fires `useMenu()` and the capability query — the exact cost the comment at
`useActiveModule/index.ts:82-83` warns about ("An unconditional write re-fires `useMenu()` and the
capability query on every single render"). The sidebar rebuilds from a different module's menu tree,
so the chrome blanks and repaints.

**Shape B — async late-write.** If the OPS module is not in the user's granted set, tier 3 also
misses, pass 1 returns `undefined`, and the async `resolveModuleCodeByMenuUrl` runs. `moduleCode` is
then written a tick AFTER paint, producing the same re-fire but one frame late.

Both funnel into the same downstream cost. Shape A is the more damaging one because it also leaves
the rail highlight on the wrong module.

## Required first step — confirm the shape, do not skip this

1. DevTools → Network → filter **Doc**. Click a platform menu.
   - **A new document request appears** (tab spinner, console cleared) → this is a REAL browser
     reload and the analysis above does NOT apply. Stop and re-diagnose from scratch.
   - **No document request; console survives** → client-side remount. Continue.
2. Log or watch the global store's `moduleCode` across two consecutive platform menu clicks.
   - Value flips (e.g. `PLATFORM` → `OPS`) → **Shape A**.
   - Value stays but is written late / arrives after the first paint → **Shape B**.
3. Query the seeded data to see exactly which PLATFORM menus live under `/ops/*`:

```sql
SELECT m."MenuCode", m."MenuName", m."MenuUrl", mo."ModuleCode", mo."ModuleUrl"
FROM auth."Menus" m
JOIN auth."Modules" mo ON mo."ModuleId" = m."ModuleId"
WHERE mo."ModuleCode" IN ('PLATFORM', 'OPS')
  AND m."IsDeleted" = FALSE
ORDER BY mo."ModuleCode", m."MenuUrl";
```

## Constraints on the fix

- **No `auth.Modules` / `auth.Menus` DATA change.** Re-seeding PLATFORM's menus under `/platform/*`
  would fix the symptom but breaks existing deep links, bookmarks and any `Role.DefaultLandingUrl`
  already pointing at `/ops/*`. The fix must be in the resolution layer.
- **No special-casing on a module code.** `menu-route-index.ts` was written specifically to avoid a
  hardcoded route→module table ("The fix is not a route→module table and not a special case for any
  module code"). Any solution that hardcodes `PLATFORM` or `/ops/tenants` is a regression of that
  design and must be rejected.
- **Do not clear `moduleCode` on a miss.** `useActiveModule` deliberately KEEPS the previous module
  when nothing maps: "Clearing it empties the panel and de-partitions RBAC, which is far worse than
  a briefly wrong highlight."
- **Do not change `activeRailKey` ownership.** INV-8: `moduleCode` is owned by this hook from the
  URL; `activeRailKey` is owned by the rail click. A rail click must never write `moduleCode`.
- The `matchModuleByUrl` tier ordering and the segment-wise comparison are load-bearing. Tier 2's
  minimum depth of 2 exists so it does not overlap tier 3; the segment-wise compare exists so
  `crm/member` does not claim `crm/membership`. Preserve both properties.

## Direction of the fix (evaluate, do not assume)

The likely correct shape is to make the menu-derived ownership authoritative and **synchronous** for
the current session, so the URL→module answer is stable and identical on every navigation:

- Build the menu route index eagerly (it is already memoised per grant set and is `cache-first`, so
  the active module's copy is usually already in the Apollo cache), and consult it BEFORE falling
  back to the coarse tier-3 root match — because tier 3's "first segment wins" is precisely what
  hands a PLATFORM menu to OPS.
- Alternatively, keep the ordering but have tier 3 refuse to answer when the menu index disagrees.

Whichever is chosen, the invariant to hit is: **navigating between two menus of the same module must
not change `moduleCode`**, so `apply()` performs no store write and nothing downstream re-fires.

## Verification

1. `moduleCode` is unchanged across consecutive platform menu clicks (the primary assertion).
2. No `useMenu()` / capability network request fires on a same-module platform navigation.
3. The rail highlights PLATFORM — not OPS — while on a platform screen seeded under `/ops/*`.
4. CRM, OPS and Member navigation is unchanged (no new requests, no regressions).
5. Deep-linking directly to a platform screen seeded under `/ops/*` still resolves to PLATFORM.
6. Logout / company switch still resets the index (`resetMenuRouteIndex`) so the next user's grants
   are not answered from the previous user's menus.

## Files in scope

- `PSS_2.0_Frontend/src/presentation/hooks/useActiveModule/index.ts`
- `PSS_2.0_Frontend/src/application/utils/module-url-match.ts`
- `PSS_2.0_Frontend/src/application/utils/menu-route-index.ts`

## Working rules

- Stage only (`git add`). Never commit, never push. No `Co-Authored-By` trailer.
- `PSS_2.0_Frontend` is a nested git repo — `cd` into it to stage.
- `BaseUrlConfig.ts` is user-managed — never edit, stage or revert it.
- Do not run `dotnet build`, do not create EF migrations.
- Enterprise application: no shortcuts, no frontend-only reasoning where the data model is the real
  cause. If the honest conclusion is that the menu seed data is wrong and the resolution layer is
  right, say so plainly rather than papering over it in the comparator.
