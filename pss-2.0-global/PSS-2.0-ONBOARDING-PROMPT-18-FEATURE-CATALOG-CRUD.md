# PROMPT 18 — Feature catalogue & feature→menu map (ops CRUD)

**Surface:** BE (CRUD + catalogue flip) + FE (new panel on `/ops/plans`)
**Depends on:** PROMPT-17 **built, migrated and seeded** — `billing.Features` and
`billing.FeatureMenuMaps` must exist with `billing-feature-menu-map-seed.sql` applied. Do not start
otherwise; you would be writing CRUD against tables that aren't there.
**Related:** `PSS-2.0-ONBOARDING-PROMPT-17-PLAN-MENU-GATING.md` — read §③, §④, §⑫ and the §⑬ build log.

---

## ⚠️ Rules

| Rule | Detail |
|---|---|
| **No `dotnet build`** | User builds. Compile by inspection. |
| **Migrations are user-owned** | Never `dotnet ef migrations add / database update / remove`; never hand-author a migration or snapshot. **This pass needs no schema change** — PROMPT-17 already created both tables. If you reach for a column, stop and write it into §⑨. |
| **Seed SQL: write, never run** | `sql-scripts-dyanmic/`. User applies. |
| **Backend is gitignored** | Grep/Glob return **zero** `.cs` hits. Use `find -iname`, or scope `grep -rn --include=*.cs` to **one** project dir — a repo-wide backend grep times out at 120s. Absolute-path `Read` works. Frontend is likewise gitignored. |
| **Typecheck** | `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, **no pipe**. Only exit 0 counts as clean. |
| **HotChocolate naming** | `Get` is **stripped** from every resolver (`GetFeatureCatalog` → `featureCatalog`); `Input` is **appended** to input types (`FeatureUpsertDto` → `FeatureUpsertDtoInput`). tsc cannot see gql field names — a wrong name compiles clean and fails only at runtime. Read the endpoint file before writing the FE query. |
| **UTC only** | `timestamp with time zone` everywhere; `DateTime.UtcNow`, never `DateTime.Today` in an EF predicate. |
| **Verify properties** | Read the entity first. Audit columns are `CreatedDate` / `ModifiedDate`, and on these two entities they come from the `Entity` base — **not re-declared**. |
| **Registry** | `grep` `REGISTRY.md`, never `Read` it (~700KB). |

---

## ⓪ Where the code lives (verified on disk 2026-08-03)

**Backend** (`PSS_2.0_Backend/PeopleServe/Services/Base/`)
```
Base.Domain/Models/BillingModels/Feature.cs                       PROMPT-17, read the XML doc
Base.Domain/Models/BillingModels/FeatureMenuMap.cs                PROMPT-17, read the XML doc
Base.Application/Interfaces/BillingCodes.cs                       static class FeatureCodes (line ~15)
Base.Application/Interfaces/IMenuFeatureMap.cs
Base.Infrastructure/Services/Billing/MenuFeatureMapService.cs     Invalidate() implemented, NEVER CALLED
Base.Infrastructure/Services/Billing/PlanMenuFilter.cs
Base.Application/Business/BillingBusiness/PlanCatalog/Queries/GetPlanCatalog.cs:115
    → returns `FeatureCodes.All` — the hardcoded vocabulary this pass replaces
```

**Frontend**
```
src/app/[lang]/(master)/ops/plans/page.tsx                        renders <PlanMatrixPage />
src/presentation/components/page-components/ops/plans/
    plan-matrix-page.tsx            the Pricing / Features / Limits matrix
    platform-pricing-policy-panel.tsx      ← the panel pattern to copy
    platform-gateway-environment-panel.tsx ← ditto
    index.ts                        barrel — add your export here
src/infrastructure/gql-queries/ops-queries/{PlanQuery,BillingQuery}.ts
src/domain/entities/ops-service/{PlanDto,BillingDto}.ts
```

`allFeatureCodes` has **six** consumer sites — both DTO files, both gql queries, `plan-matrix-page.tsx`
(lines 95, 262, 757, 765) and `ops/tenants/tenant-subscription-panel.tsx:409`. §③.3 changes its shape;
all six must move together.

---

## ① The one idea

PROMPT-17 moved two things out of C# and into tables: the **feature vocabulary** (`billing.Features`)
and the **feature→menu map** (`billing.FeatureMenuMaps`). It seeded both and taught the runtime to
read the map. What it did **not** do is give anyone a way to edit either, or teach the plan matrix to
read the vocabulary — `GetPlanCatalog.cs:115` still returns the hardcoded `FeatureCodes.All`.

So today the tables are authoritative for *gating* but not for *configuring*, and the vocabulary is
still frozen in a deploy. This pass closes both halves.

**Plan → feature assignment already exists** and is not touched: the Features band of
`plan-matrix-page.tsx` writes `billing.PlanEntitlements` through its own diff-only mutation. This
prompt adds the layer *underneath* it — which features exist at all, and which menus each one unlocks.

---

## ② Placement — no new menu, no new capability

Build it as a **new panel on `/ops/plans`**, below the existing matrix, alongside
`PlatformPricingPolicyPanel` and `PlatformGatewayEnvironmentPanel`. Copy their structure.

That reuses the seeded `PLATFORM_PLANS` menu and the `PLATFORM_PLAN_VIEW` / `PLATFORM_PLAN_EDIT`
capabilities, so **this pass ships no seed change at all**. Do not create a menu row, do not invent a
capability code. Read on `PLATFORM_PLAN_VIEW`, mutate on `PLATFORM_PLAN_EDIT` — and note the trap
already documented in `plan-matrix-page.tsx`: the access hook's `canView` shortcut is hardwired to
`PLATFORM_TENANT_VIEW`, so this screen must use `has(code)` explicitly.

The panel is one card with two halves:

- **Feature catalogue** — the rows of `billing.Features`: code, name, description, sort order, active.
- **Menu map** — for the selected feature, the `MenuCode`s it unlocks.

Select a feature on the left, edit its menu list on the right. That coupling is the point: a feature
with no menus mapped gates nothing, and it should be visible at a glance which ones are inert.

---

## ③ Design

### 3.1 Feature catalogue CRUD

```
Query    GetFeatureCatalog()  → rows ordered by SortOrder, then FeatureCode
                                include EntitlementCount + MappedMenuCount per row
Mutation SaveFeature(FeatureUpsertDto)      create or update
Mutation SetFeatureActive(featureId, bool)  deactivate / reactivate
```

Rules that must be enforced **server-side**, not merely in the form:

1. **`FeatureCode` is immutable after creation.** `PlanEntitlements.FeatureCode` and
   `FeatureMenuMaps.FeatureCode` join to it **by value, not by FK** — a rename silently orphans every
   row in both tables and the gate quietly stops working. On update, ignore any incoming code change
   and reject with a clear message rather than accepting it silently.
2. **Format:** uppercase, `MODULE:` or `CHANNEL:` prefix, `[A-Z0-9_]` after the colon, ≤ 64 chars.
3. **No hard delete.** Deactivate only, and refuse to deactivate a feature that any *active* plan
   still entitles — return the offending plan names. A feature silently vanishing from under a paying
   plan is the one failure mode here that reaches a customer.
4. **`SortOrder`** drives the matrix row order; `MODULE:*` sorts before `CHANNEL:*`.

### 3.2 Feature→menu map CRUD

```
Query    GetFeatureMenuMap(featureCode)  → mapped MenuCodes
Mutation SaveFeatureMenuMap(featureCode, menuCodes[])  diff-only, mirrors the matrix bands
```

- **Diff-only**, exactly like the existing band saves: the client posts the full desired set for one
  feature and the server works out inserts and removals against the unique key `(FeatureCode, MenuCode)`.
- The menu picker sources its options from **`GetMenuAdminTree`** — PROMPT-17 deliberately left that
  query unfiltered precisely so administration screens can still see every menu.
- **Hard-block mapping any `BILLING*` menu code.** `FeatureMenuMap`'s own XML doc says it: a lapsed
  tenant must always be able to reach the pay screen. Enforce it in the handler with an explicit
  error, not just by omitting them from the picker — the picker is a convenience, the handler is the rule.
- A `MenuCode` with **no** row is never hidden. Absence means "always visible", not "blocked". Make
  the UI say this in one line, because the inverse is the natural assumption and it is wrong.
- Unmapped menu codes may be mapped to more than one feature; that is legal (any one of them unlocks it).

### 3.3 Flip the catalogue to the table — a breaking DTO change

`GetPlanCatalog.cs:115` returns `FeatureCodes.All`. Replace it with a read of `billing.Features`
(active rows, ordered by `SortOrder`), and widen the payload from bare strings to real rows:

```
- AllFeatureCodes : IReadOnlyList<string>
+ AllFeatures     : IReadOnlyList<FeatureRowDto>   // FeatureCode, FeatureName, Description, SortOrder
```

This is worth the churn: the matrix currently renders the raw code as its row label
(`plan-matrix-page.tsx:765`), so operators read `MODULE:CONTACTS` where they should read "Contacts".
Update all six consumer sites listed in §⓪ together — tsc will find them once the DTO type changes.

**Do not delete `FeatureCodes`.** Its per-code constants are referenced by `[RequiresFeature]`
attributes across the command side and remain the compile-time vocabulary. Only `FeatureCodes.All`
becomes dead. Mark it `[Obsolete]` with a comment pointing at `billing.Features`, and leave removal to
a later cleanup — deleting it in the same pass that flips the catalogue makes a compile failure hard
to attribute.

`AllMeterCodes` stays exactly as it is. Quota meters are a different vocabulary with no table and no
menu map; do not fold them in.

### 3.4 Cache invalidation — the reason the panel would otherwise look broken

Two caches go stale on every mutation here, and neither is currently invalidated:

| After | Call | Why |
|---|---|---|
| any `FeatureMenuMap` mutation | `IMenuFeatureMap.Invalidate()` | implemented in `MenuFeatureMapService`, **never called** — this is the wiring PROMPT-17 deferred. Without it a map edit takes up to 60s to surface and the operator concludes the save failed. |
| feature deactivate / reactivate | `IEntitlementService.InvalidateAll()` | it changes what *every* tenant resolves, and `Invalidate` is per-company. Same reasoning as `SavePlanEntitlements`, which already calls `InvalidateAll()`. |

---

## ④ Build steps

1. **Read first.** PROMPT-17 §③/§④/§⑬; `Feature.cs` and `FeatureMenuMap.cs` XML docs (they encode
   several of the rules above); `GetPlanCatalog.cs`; `MenuFeatureMapService.cs`;
   `platform-pricing-policy-panel.tsx` for the panel pattern; `plan-matrix-page.tsx` lines 90-110 and
   250-270 for the diff-save shape to mirror.
2. **BE — feature CRUD** (§3.1) under `Base.Application/Business/BillingBusiness/FeatureCatalog/`.
3. **BE — map CRUD** (§3.2), same folder.
4. **BE — flip `GetPlanCatalog`** (§3.3) and `[Obsolete]` `FeatureCodes.All`.
5. **BE — invalidation** (§3.4). Register resolvers; **record every resolved GraphQL field name in
   §⑩** so the FE query can't drift.
6. **FE — DTOs + gql**, all six `allFeatureCodes` sites.
7. **FE — the panel**, exported from `index.ts` and mounted in `plan-matrix-page.tsx` next to the
   other two panels.
8. **Typecheck.** `npx tsc --noEmit --incremental false`, no pipe, exit 0.

---

## ⑤ UI notes

- Solid `bg-X-600` + `text-white` for every icon container, badge and chip — never `bg-X-50/100`,
  `text-X-700/800`, `bg-muted` or `text-muted-foreground` for those.
- Tokens only, no raw hex or px. Shaped `Skeleton`s. Explicit empty and error states.
- Save buttons gate on RHF `formState.isValid` + dirtiness — **never** on a capability. The
  capability decides whether the control renders at all.
- Show `EntitlementCount` and `MappedMenuCount` per feature row. A feature with 0 mapped menus is
  inert; badge it so that reads as a state rather than an oversight.
- Responsive xs→xl; `@iconify` Phosphor icons.

---

## ⑥ Invariants

1. **No schema change, no migration, no seed.** Both tables and the menu/capability rows already exist.
2. `FeatureCode` never changes after creation.
3. No hard delete of a feature, ever; and no deactivation while an active plan entitles it.
4. `BILLING*` menu codes are never mappable — enforced in the handler.
5. An unmapped menu is visible. Absence ≠ blocked.
6. Every map mutation calls `IMenuFeatureMap.Invalidate()`; every feature activation change calls
   `IEntitlementService.InvalidateAll()`.
7. Hiding a menu stays cosmetic. `[RequiresFeature]` remains the security boundary — nothing in this
   pass may be described or built as an access control.
8. The Features **band** of the matrix (plan→feature assignment) is untouched apart from its row
   source and labels.

---

## ⑦ What must NOT be built here

Quota-meter CRUD · plan CRUD (exists) · plan→feature assignment (exists) · any change to
`PlanMenuFilter` or `GetParentChildMenu` · an upsell/"not in your plan" affordance on the tenant
sidebar (PROMPT-17 §⑫ item 1, still deliberately deferred) · a `RoleModules` backfill for
pre-PROMPT-17 tenants (PROMPT-17 §⑬, user-owned one-off).

---

## ⑧ Acceptance

- [ ] `/ops/plans` shows the new panel below the matrix; a `PLATFORM_PLAN_VIEW`-only user sees it read-only.
- [ ] Creating a feature makes it appear as a **row in the matrix Features band** without a deploy.
- [ ] Matrix rows render **names** ("Contacts"), not raw codes.
- [ ] Editing a feature cannot change its `FeatureCode`.
- [ ] Deactivating a feature an active plan entitles is refused, naming the plans.
- [ ] Mapping a `BILLING*` menu is refused by the **API**, tested directly, not just absent from the picker.
- [ ] Adding a menu to a feature hides it for a tenant without that feature **within one refresh**, not 60s.
- [ ] Removing the last map row for a feature makes its menus visible again to everyone.
- [ ] A feature with 0 mapped menus is visibly badged as inert.
- [ ] `npx tsc --noEmit --incremental false` exits 0.

---

## ⑨ Open questions

**Q1 — `RETENTIONDASHBOARD` and `DASHBOARDLAYOUT`.** PROMPT-17 §⑬ left both unmapped and flagged
them here. Once this panel exists they are a pure data edit, so **do not hardcode a mapping** — surface
them in the picker and let ops decide.

**Q2 — leaf-level gating inside `CRM_CONTACT` / `CRM_DONATION`.** PROMPT-17 deliberately excluded it
(quotas limit FREE instead of hiding screens) and designed the table to admit it later as data. This
panel makes that possible; it does not make it decided. No build action.

Neither blocks the build.

---

## ⑩ Build log

*(append per session: resolved GraphQL field names, deviations, decisions taken)*

### Session 1 — 2026-08-03 — BUILT (FE typecheck exit 0, BE compile-by-inspection)

**Resolved GraphQL field names** (HotChocolate strips `Get`, appends `Input`):

| C# member | GraphQL field |
| --- | --- |
| `FeatureCatalogQueries.GetFeatureCatalog` | `featureCatalog` |
| `FeatureCatalogQueries.GetFeatureMenuMap(featureCode)` | `featureMenuMap(featureCode: String!)` |
| `FeatureCatalogMutations.SaveFeature(feature)` | `saveFeature(feature: FeatureUpsertDtoInput!)` |
| `FeatureCatalogMutations.SetFeatureActive(featureId, isActive)` | `setFeatureActive(featureId: Int!, isActive: Boolean!)` |
| `FeatureCatalogMutations.SaveFeatureMenuMap(featureCode, menuCodes)` | `saveFeatureMenuMap(featureCode: String!, menuCodes: [String!]!)` |

`GetPlanCatalogResult.AllFeatures` resolves as `planCatalog.data.allFeatures { featureCode featureName description sortOrder }`.

**Files touched**

- BE new: `BillingBusiness/FeatureCatalog/FeatureCodeRules.cs`, `Queries/GetFeatureCatalog.cs`,
  `Queries/GetFeatureMenuMap.cs`, `Commands/SaveFeature.cs`, `Commands/SetFeatureActive.cs`,
  `Commands/SaveFeatureMenuMap.cs`; `Base.API/EndPoints/Billing/{Queries/FeatureCatalogQueries.cs,
  Mutations/FeatureCatalogMutations.cs}` (resolvers auto-register by assembly scan — no wiring edit).
- BE edited: `Schemas/BillingSchemas/PlanSchemas.cs` (+`FeatureUpsertDto`), `PlanCatalog/Queries/GetPlanCatalog.cs`
  (flipped to `AllFeatures : IReadOnlyList<FeatureRowDto>`), `Interfaces/BillingCodes.cs` (`[Obsolete]` on
  `FeatureCodes.All` only), `PlanCatalog/Commands/SavePlanEntitlements.cs` and
  `Subscriptions/Commands/SetSubscriptionOverride.cs` (feature-code existence moved from the static list
  to `billing.Features`; `MeterCodes.All` untouched).
- FE edited: `PlanDto.ts`, `PlanQuery.ts`, `PlanMutation.ts`, `plan-matrix-page.tsx`, `tenant-subscription-panel.tsx`.
- FE new: `ops/plans/feature-catalog-panel.tsx` (catalogue list + menu-map editor + create/edit dialog),
  exported from `ops/plans/index.ts`, mounted after `</FormProvider>` and before `<PlanFormDialog />`.
- No schema change, no migration, no seed. §⑦ scope respected in full.

**Decisions**

1. `FeatureCodes` class kept; only `.All` marked `[Obsolete]` per §③.3. Verified **no `TreatWarningsAsErrors`**
   in any csproj/props, so the three remaining readers warn without breaking the build.
2. Panel calls `has("PLATFORM_PLAN_VIEW")` / `has("PLATFORM_PLAN_EDIT")` explicitly — the hook's `canView`
   shortcut is hardwired to `PLATFORM_TENANT_VIEW` and would have silently hidden the panel.
3. Menu picker sources `GET_MENU_ADMIN_TREE_QUERY` (§③.2), flattened with depth indent; `BILLING*` filtered
   client-side **in addition to** the handler block, so the operator cannot compose an edit that cannot land.
4. Map-editor Save gates on dirtiness alone (there is no field to validate); the feature dialog gates on RHF
   `formState.isValid` + dirtiness. Neither gates on a capability.
5. Feature catalogue query returns inactive rows deliberately — it is the only revive path.

**Deviations**

- §④ step 6 says "six `allFeatureCodes` consumer sites". Only **four** are driven by `GetPlanCatalogResult`.
  `BillingDto.ts:144` / `BillingQuery.ts:121` belong to `mySellablePlans` (fed by `GetMySellablePlans.cs`,
  which §⑦ does not put in scope) and were deliberately left alone.
- §③.3 implies one `FeatureCodes.All` reader. There are **seven**: `GetMyEntitlements.cs:128`,
  `SavePlanEntitlements.cs:40` (fixed), `GetPlanCatalog.cs:115` (flipped), `SetSubscriptionOverride.cs:42`
  (fixed), `GetSubscriptionForCompany.cs:111`, `GetMySellablePlans.cs:91` and `:186`. The last three still
  read the static list — flipping them is outside §⑦'s fence and belongs in a follow-up.

**Known issues (not fixed — §⑦ forbids the touch)**

- `MenuFeatureMapService` resolves **one** feature per menu (`map.TryAdd(row.MenuCode, row.FeatureCode)`,
  ordered by `FeatureCode`), so a menu mapped to two features is gated by the alphabetically-first one only.
  §③.2 assumes many-to-many. Fixing it means editing the map service, which §⑦ fences off.
- `GetMenuAdminTree` is gated on `DecoratorAuthModules.Menu` + `Permissions.Read` with **no SUPERADMIN
  bypass**. A platform ops user holding only `PLATFORM_PLAN_VIEW`/`PLATFORM_PLAN_EDIT` will get
  `UnauthorizedAccessException` when the picker loads — the editor's error state renders instead of the tree.
  User-owned permission seed, not a code fix.
- Verified on disk that migration `20260803070336_Add_FeatureConfiguration_FeatureMenuMap.cs` exists, so the
  PROMPT-17 schema gate is satisfied. Whether `sql-scripts-dyanmic/billing-feature-menu-map-seed.sql` has been
  **applied** could not be verified from the repo — if it has not, the catalogue renders empty on first load.

### Session 2 — 2026-08-03 — LAYOUT MERGE (FE only, typecheck exit 0)

**Deviation from §②.** §② specified "a new panel on `/ops/plans`, below the matrix". Built that way in
Session 1; the user rejected it on sight, and the objection was right:

> "which plan based the menu configured — because one plan have two menus and other plan have three
> menus … I think this two section combine and display 'Features - Feature catalogue'"

A menu-map box sitting under the plan COLUMNS reads as a third, per-plan axis. It isn't one — the map is
global to the feature, and a plan's menu count is the union over the features it has ticked. The layout
was posing a question the model has no answer to.

**What changed (no BE change, no schema change, no new query or mutation):**

| Before | After |
|---|---|
| `feature-catalog-panel.tsx` — standalone card below the matrix | **deleted** |
| — | `feature-catalog-dialogs.tsx` — `FeatureFormDialog` (lifted as-is) + `FeatureMenuMapDialog` (the map editor re-housed in a Dialog) |
| Features band titled "Features", rows from `planCatalog.allFeatures` | Band titled **"Features · Feature catalogue"**, rows from `FEATURE_CATALOG_QUERY` (adds retired rows + counts), falling back to `planCatalog.allFeatures` when it hasn't resolved or the operator lacks the read |
| Menu map reached from a list on the panel | Menu map reached from a **button on the feature's own row**, badged with `mappedMenuCount` (emerald >0, amber at 0 = inert) |
| Feature create/edit/retire on the panel | `+ New feature` in the band header; pencil + retire `Switch` in each row's `RowHead` action slot |
| — | "Show N retired" toggle; retired rows render dimmed with `retired` in place of a checkbox (they are absent from `planCatalog.allFeatures`, so the form has no cell for them) |

`BandHeader` gained a `saveLabel` prop — its button label was `Save {title.toLowerCase()}`, so retitling
the band would have produced "Save features · feature catalogue". Button still reads **Save features**.

`plan-form-schemas.ts`, `buildDefaults`, `saveFeatures` and the entitlement mutation are untouched: they
are driven by `planCatalog.allFeatures` (active features only), which is exactly the set that renders a
checkbox.

**Known issues from Session 1 all still stand** (seed application unverified, `GetMenuAdminTree` auth
gate, `MenuFeatureMapService` one-feature-per-menu, `FeatureCodes.All` obsolete warnings).

### Session 3 — 2026-08-03 — COLLAPSIBLE BANDS (FE only, typecheck exit 0)

User: *"add collapse option for three section pricebook, feature, limits"*. The matrix is one `<table>` with
three banded row groups, so collapse is per-band, not per-card.

- `collapsedBands: Record<BandName, boolean>` + `toggleBand` in `plan-matrix-page.tsx`. All three bands
  start **open** — a comparison matrix that opens folded hides its own purpose. State is deliberately
  **not persisted**: it's a reading aid for one sitting, not a preference.
- `BandHeader` now renders its title cluster inside a `<button aria-expanded>` with a `ph:caret-right` /
  `ph:caret-down`, takes a required `rowCount`, and shows `{rowCount} rows hidden` when folded.
- A folded band **keeps its Save button** and gains an amber `Unsaved` badge when its section is dirty, so
  collapsing can never bury pending edits. Its `description` and band-specific header controls
  (`+ New feature`, `Show N retired`, `+ Add price row`) hide while folded — they act on rows that aren't
  on screen.
- Each band's rows are wrapped in `{!collapsedBands.<band> && (<>…</>)}` inside the shared `<tbody>`.
  Row state is preserved across a fold/unfold (RHF fields are unmounted but the form values are not
  registered per-row from scratch — `buildDefaults` still owns them).
