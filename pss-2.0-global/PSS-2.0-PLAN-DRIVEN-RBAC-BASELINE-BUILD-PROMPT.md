# Plan-driven RBAC baseline — generate the baseline from the plan's feature→menu configuration

> **Status:** NOT BUILT (written 2026-08-06)
> **Order:** independent of the email/purge prompts. §④.1–④.3 unblock provisioning step 3, so run those first if the demo needs it.
> **Migration:** NONE. Every table this prompt needs already exists. See §③.
> **Prerequisite:** §⓪ answered.

---

## ⚠️ Standing rules (non-negotiable)

1. **Do NOT run `dotnet build`.** The user builds the backend.
2. **Migrations are strictly user-owned.** Never run `dotnet ef migrations add/remove` or `database update`. Never hand-author a migration or a snapshot. This prompt should need none — if you conclude it does, **stop and say so**; do not create one.
3. **No raw SQL.** No `ExecuteSqlRawAsync`, no `FromSqlRaw`, no string-built SQL. `ExecuteDeleteAsync` / `ExecuteUpdateAsync` over a LINQ `IQueryable` are EF and are allowed.
4. Seeds go to `sql-scripts-dyanmic/`. The user applies them.
5. Frontend typecheck: `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, **no pipe**. Only exit 0 counts.
6. `PSS_2.0_Backend/` and `PSS_2.0_Frontend/` are gitignored — Grep/Glob return nothing. Use `find -iname`, or scope `grep -rn --include=*.cs` to **one** project subdirectory. A repo-wide backend grep times out at 120 s. Absolute-path `Read` works.
7. HotChocolate strips `Get` from resolver names and appends `Input` to input types. tsc cannot see gql field names — a wrong name builds clean and fails only at runtime.
8. Every Postgres date column is `timestamp with time zone`. `DateTime.UtcNow` only; never `DateTime.Today` in an EF predicate.
9. `ops` / `billing` are platform-global: every read needs `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true` guard.
10. Never assume a GraphQL field, DTO property, or column name — read the source first.
11. SUPERADMIN is never baselined, never generated, never revoked.
12. **`billing.PlanRoleBaselines` unticks are HARD deletes, by design.** The unique index `(PlanId, RoleCode, MenuId, CapabilityId)` omits `IsDeleted`, so a soft-deleted row permanently blocks re-ticking that cell. This contradicts the usual RBAC soft-delete house rule and it is deliberate — **do not "fix" it**. See the class remarks on `PlanRoleBaseline.cs`.
13. Widget/KPI icon containers and status badges: solid `bg-X-600` + `text-white`. Never `bg-X-50/100`, `text-X-700/800`, or `bg-muted`.

---

## §⓪ Blocking questions — answer before writing code

### Q1 — how many menus are unmapped today?

```sql
SELECT count(*) FILTER (WHERE fm."MenuCode" IS NULL) AS unmapped,
       count(*)                                       AS total_active_menus
FROM auth."Menus" m
LEFT JOIN billing."FeatureMenuMaps" fm
       ON upper(fm."MenuCode") = upper(m."MenuCode") AND fm."IsDeleted" IS DISTINCT FROM true
WHERE m."IsActive" = true AND m."IsDeleted" IS DISTINCT FROM true;
```

| Result | Consequence |
|---|---|
| `unmapped` is 0 or only `BILLING*` / `SETTING*` / `ACCESSCONTROL*` codes | Strict mode (§④.2) is safe to switch on immediately. |
| `unmapped` is large | Strict mode would generate a nearly empty baseline. Build §④.2 but **default it off**, ship the banner in §⑤.3 first, and let the user map the menus before flipping it. **This is the likely case — treat it as such until the query says otherwise.** |

### Q2 — which role codes should a plan be born with, besides BUSINESSADMIN?

Today `Step3_SeedRolesAsync` derives the tenant's **role set** from `SELECT DISTINCT "RoleCode" FROM billing."PlanRoleBaselines" WHERE "PlanId" = …`. So a role with no baseline cells does not exist for that plan at all.

```sql
SELECT p."PlanCode", b."RoleCode", count(*) AS cells
FROM billing."PlanRoleBaselines" b
JOIN billing."Plans" p ON p."PlanId" = b."PlanId"
WHERE b."IsDeleted" IS DISTINCT FROM true AND b."HasAccess" = true
GROUP BY 1, 2 ORDER BY 1, 2;
```

The generator in §④.1 only produces BUSINESSADMIN. If the user wants FINANCE / FUNDRAISER etc. on a plan, those stay hand-curated in tab 3 — and §④.1 must never delete them.

---

## §① The problem

The chain the business wants:

```
billing.FeatureMenuMaps  +  billing.PlanEntitlements
        │  (feature → menus)      (plan buys feature)
        ▼
   plan menu set        ── IPlanMenuScope
        │  × auth.MenuCapabilities (menu → capability)
        ▼
   billing.PlanRoleBaselines   (plan, roleCode, menu, capability)
        │  provisioning step 3 + 4a, joined on RoleCode
        ▼
   auth.RoleCapabilities       (roleId, menu, capability, HasAccess)
        │  ∩ IPlanMenuFilter(companyId)
        ▼
   the menu tree the tenant's BUSINESSADMIN sees
```

Every link exists **except the first arrow into `PlanRoleBaselines`**. Today those rows are hand-seeded by `sql-scripts-dyanmic/plan-role-baseline-bootstrap-seed.sql`. `IPlanMenuScope` only *caps* the matrix at read time; nothing ever *produces* it.

Three consequences, all live today:

| # | Symptom | Cause |
|---|---|---|
| 1 | `Plan 'X' has no RBAC baseline configured` — provisioning steps 3 and 4a both throw `NotFoundException` | The seed was never applied for that plan. A new plan created on `/ops/plans` is born unprovisionable and nothing on that screen says so. |
| 2 | Silent drift | Tick a new feature on PLAN_50K, or add a menu to a feature in `FeatureMenuMaps`, and every existing baseline row is now short. No error. The next tenant is simply born missing menus. |
| 3 | Two sources of truth | The plan screen says what the plan sells; the seed says what the tenant gets. Nothing reconciles them. |

There is also no UI at all: `GetPlanRoleBaseline`, `BulkUpdatePlanRoleBaseline`, `GetPlanBaselineSummary`, `GetBaselinePushPreview` and `ExecuteBaselinePush` are built, the gql documents are written in `PlatformRbacQuery.ts` / `PlatformRbacMutation.ts` — and **`grep -rln "PlatformRbacQuery|PlatformRbacMutation" ./presentation ./app` returns zero.** Nothing consumes them.

---

## §② The design

### ②.1 Generate the baseline, don't author it — but **materialise** it

For **BUSINESSADMIN there is no decision to make.** BUSINESSADMIN is the tenant owner; they get everything their plan sells. So the baseline for that role is a formula, not data:

```
BUSINESSADMIN cells(plan) =
    IPlanMenuScope.GetAllowedMenuIdsForPlanAsync(planId)     -- the menus the plan sells
  ⋈ auth.MenuCapabilities                                    -- the capability columns each menu has
  − control-plane menus                                      -- a tenant is never born with these
```

**It must be written to `billing.PlanRoleBaselines`, not computed at read time.** This is the single most important instruction in this prompt. Four existing consumers read that table directly and a computed-only baseline breaks all of them:

| Consumer | Reads |
|---|---|
| `ProvisionTenant.Step3_SeedRolesAsync` | `DISTINCT RoleCode` — **the tenant's whole role set** |
| `ProvisionTenant.Step4…` → `IPlanBaselineApplier.ApplyAsync` | the cells |
| `GetPlanBaselineSummary` | `IsEmpty`, cell counts, last-editor |
| `GetBaselinePushPreview` / `ExecuteBaselinePush` | the cells |

Generating into the table leaves every one of them untouched. **Do not modify any of the four.**

### ②.2 Ownership: generated vs curated, split by role code

| Role code | Owner | Editable in tab 3 |
|---|---|---|
| `BUSINESSADMIN` | The generator | **No — read-only**, with a "Regenerate" button and a "generated from plan features" note |
| Any other tenant role code | A human | Yes, exactly as `BulkUpdatePlanRoleBaseline` already allows |
| `SUPERADMIN`, any `IsPlatform` role | Nobody | Rejected by the existing guards |

No new column is needed to record this. Ownership is decided by `RoleCode == "BUSINESSADMIN"`, in one shared constant. A generator run **only ever touches BUSINESSADMIN rows** for the target plan — it must never see, count, or delete a curated role's row.

### ②.3 Fail-open is wrong for a generator

`PlanMenuScope` today is deliberately **fail-open**, and its own doc comment says so: an unmapped menu is ALLOWED, and an empty `FeatureMenuMaps` table allows *everything*. That is the correct direction for an editor — it can offer a cell the plan doesn't cover, but never hides one it does.

It is the wrong direction for a generator. Fail-open means a FREE tenant is generated holding every menu nobody remembered to map.

So §④.2 adds a **strict** mode: unmapped ⇒ **excluded**. Existing callers keep today's behaviour, unchanged and untouched — `PlanMenuFilter` (the runtime sidebar) is not in scope and must not be edited.

Strict mode is only honest if the holes are visible, so §④.5 reports the unmapped menu count and §⑤.3 puts it on `/ops/plans`.

### ②.4 Drift is a first-class, visible state

A plan whose stored baseline no longer equals what the generator would produce is **stale**. That is computed on demand — no column, no timestamp, no migration:

```
missing  = generated cells − stored cells   (plan grew; new tenants are short)
extra    = stored cells − generated cells   (plan shrank, or a menu left the plan)
stale    = missing ≠ ∅ or extra ≠ ∅
```

Tab 3 shows it as a banner with a **Regenerate** button. `/ops/plans` shows a chip per plan.

### ②.5 What regenerating does and does not do

| | |
|---|---|
| **Does** | Reconcile `billing.PlanRoleBaselines` for `(planId, BUSINESSADMIN)` — insert missing, hard-delete extra. Write one `ops.PlatformAuditLog` row. |
| **Does not** | Touch a single live tenant. Existing tenants move only through **Tenants & Push** (tab 4), which is additive-only and never revokes. |

Say this on the screen in one sentence. The operator otherwise assumes Regenerate fixed their tenants, and it did not.

---

## §③ Migration spec

**None.** Every table already exists: `billing.FeatureMenuMaps`, `billing.PlanEntitlements`, `billing.PlanRoleBaselines`, `auth.MenuCapabilities`, `auth.RoleCapabilities`, `ops.PlatformAuditLog`.

Drift is computed, ownership is decided by `RoleCode`, and strict mode is a parameter. If you find yourself wanting a column, re-read §②.4 — you almost certainly want a computed value instead. If you still conclude a migration is genuinely required, **stop and write the spec into §⑨ instead of building it.**

---

## §④ Backend

Files live under
`PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/OpsBusiness/PlatformRbac/`
unless stated otherwise. **Read `PlanBaselineMatrixBuilder.cs` and `BulkUpdatePlanRoleBaseline.cs` before writing anything** — the guards, the scoping rules and the hard-delete reconcile are already solved there and must be reused, not reinvented.

### ④.1 `PlanBaselineGenerator` — the new core

New file `PlatformRbac/PlanBaselineGenerator.cs`, `internal static`, no interface (it has one caller shape and lives beside its consumers, like `PlanBaselineMatrixBuilder`).

```csharp
internal record GeneratedBaseline(
    IReadOnlyList<(int MenuId, int CapabilityId)> Cells,
    int MenuCount,
    int UnmappedMenuCount);   // menus with no FeatureMenuMap row — the §②.3 holes

internal static class PlanBaselineGenerator
{
    public const string OwnedRoleCode = "BUSINESSADMIN";

    public static Task<GeneratedBaseline> GenerateAsync(
        IApplicationDbContext dbContext,
        IPlanMenuScope planMenuScope,
        IMenuFeatureMap menuFeatureMap,
        int planId,
        bool strict,
        CancellationToken cancellationToken);
}
```

Algorithm, in order:

1. `allowedMenuIds = planMenuScope.GetAllowedMenuIdsForPlanAsync(planId, ct)` — or the strict overload from §④.2 when `strict`.
2. `platformMenuIds = PlatformRoleMatrixBuilder.PlatformMenuIdsAsync(dbContext, ct)` — **exclude every one**. Reuse this helper; do not re-derive control-plane menus.
3. Load active, non-deleted `auth.Menus` with `.Include(m => m.MenuCapabilities)`, same shape as `PlanBaselineMatrixBuilder`.
4. For each menu in `allowedMenuIds`, not in `platformMenuIds`: emit one cell per **distinct, non-deleted** `MenuCapability`. A menu with zero capabilities contributes nothing and is **not** counted as hidden — mirror `PlanBaselineMatrixBuilder`'s exact `.Where(mc => mc.IsDeleted == false && mc.Capability != null).GroupBy(mc => mc.CapabilityId)` de-duplication; the table has known duplicate rows.
5. `UnmappedMenuCount` = active non-platform menus whose `MenuCode` has no entry in `menuFeatureMap.GetMapAsync()` and is not `MenuScopeCascade.IsNeverBlocked`.

No writes. This is a pure function of the database.

### ④.2 `IPlanMenuScope` — additive strict overload

`Base.Application/Interfaces/IPlanMenuScope.cs` and `Base.Infrastructure/Services/Billing/PlanMenuScope.cs`.

Add **one** member. Do not change the existing signature, its behaviour, or any caller:

```csharp
/// <summary>Strict scope for the BASELINE GENERATOR: an unmapped menu is EXCLUDED, not allowed.
/// The default overload is fail-open (see remarks) — correct for an editor, wrong for a generator,
/// which would otherwise write every unmapped menu into every plan including FREE.</summary>
Task<HashSet<int>> GetAllowedMenuIdsForPlanAsync(int planId, bool strict, CancellationToken cancellationToken);
```

The existing method becomes `=> GetAllowedMenuIdsForPlanAsync(planId, strict: false, ct)`. In the strict path:

- An empty `FeatureMenuMaps` map returns **empty**, not everything.
- A menu with no map entry becomes a cascade seed (out of scope, and its sub-tree with it) — **unless** `MenuScopeCascade.IsNeverBlocked(menuCode)`, which still wins. `BILLING*` / `SETTING*` / `ACCESSCONTROL*` must stay reachable on every plan or a tenant cannot reach its own settings.
- The cascade walk is otherwise byte-for-byte the existing one. Extract the shared body rather than copying it.

Update the interface doc comment to state both directions and why they differ. The current comment asserts fail-open as the only behaviour; leaving it is a lie the next reader will trust.

### ④.3 `RegeneratePlanBaselineCommand`

New file `PlatformRbac/Commands/RegeneratePlanBaseline.cs`.

```csharp
[CustomAuthorize("PLATFORM_STAFF", "PLATFORM_RBAC_TEMPLATE_EDIT")]
public record RegeneratePlanBaselineCommand(int planId, bool strict = true)
    : ICommand<RegeneratePlanBaselineResult>;

public record RegeneratePlanBaselineResult(
    int PlanId, string PlanCode, string RoleCode,
    int AddedCellCount, int RemovedCellCount, int UnchangedCellCount,
    int MenuCount, int UnmappedMenuCount, int LiveTenantCount);
```

Handler:

1. Resolve the plan (`IgnoreQueryFilters`, `IsDeleted != true`) → `NotFoundException` if absent.
2. `PlanBaselineGenerator.GenerateAsync(...)`.
3. Load stored cells `WHERE PlanId = planId AND RoleCode = OwnedRoleCode AND IsDeleted != true`. **Scope to that role code — never to the plan alone.** A plan-wide reconcile would silently wipe every curated FINANCE / FUNDRAISER row.
4. Reconcile: insert the set difference; **hard-`Remove`** the extras (⚠ Rule 12). Chunk `SaveChangesAsync` at 200 rows, matching `PlanBaselineApplier`.
5. Guard: if `generated.Cells.Count == 0` **and** stored cells exist, throw
   `BadRequestException("BASELINE_WOULD_BE_EMPTIED: plan '<code>' resolves to zero menus …")`.
   A regenerate must never silently empty a working baseline because a feature was untick or the map is missing. Force the operator to fix the plan first.
6. One `IPlatformAuditWriter` row: `ActionType = "platform.rbac.baseline.regenerated"`, `EntityType = "Plan"`, `EntityId = planId`, added/removed/unchanged in `ChangesJson`.
7. Return the counts. `LiveTenantCount` uses the same `SubscriptionStatuses.Live` distinct-company count as `GetPlanRoleBaseline`.

### ④.4 `GetPlanBaselineDriftQuery`

New file `PlatformRbac/Queries/GetPlanBaselineDrift.cs`. Read-only preview of ④.3 — same generate + compare, **zero writes**.

```csharp
[CustomAuthorize("PLATFORM_STAFF", "PLATFORM_STAFF_VIEW")]
public record GetPlanBaselineDriftQuery(int? planId = null, bool strict = true)
    : IQuery<PlanBaselineDriftResult>;

public record PlanBaselineDriftResult(IReadOnlyList<PlanBaselineDriftRowDto> rows);
```

`PlanBaselineDriftRowDto`: `PlanId`, `PlanCode`, `PlanName`, `IsStale`, `MissingCellCount`, `ExtraCellCount`, `StoredCellCount`, `GeneratedCellCount`, `MenuCount`, `UnmappedMenuCount`, `LiveTenantCount`, `HasAnyBaseline`.

`planId == null` ⇒ every non-deleted plan, so `/ops/plans` can chip the whole list in one call. **Sequential awaits only — `DbContext` is not thread-safe.** Load menus and the feature map **once** outside the plan loop; only `GetAllowedMenuIdsForPlanAsync` is per plan.

`HasAnyBaseline = false` is the important one: that plan's next provisioning run **fails**, and it must read that way in the UI, not as "not configured yet".

### ④.5 GraphQL surface

Wire alongside the existing PlatformRbac resolvers. ⚠ Rule 7 — the field names the client must use:

| C# | GraphQL field |
|---|---|
| `GetPlanBaselineDriftQuery` | `planBaselineDrift` |
| `RegeneratePlanBaselineCommand` | `regeneratePlanBaseline` |

Follow the file the existing baseline resolvers live in; do not invent a new endpoint class.

---

## §⑤ Frontend

Route group `(core)`, under `/ops`. The gql documents in `infrastructure/gql-queries/ops-queries/PlatformRbacQuery.ts` and `.../gql-mutations/ops-mutations/PlatformRbacMutation.ts` **already exist** — read them, reuse them, add only the two new documents from §④.5. Add the matching DTOs to `domain/entities/ops-service/PlatformRbacDto.ts`.

### ⑤.1 O-24 tab 3 — Plan Baselines

Two-pane, master/detail.

**Left — plan list** (`PLAN_BASELINE_SUMMARY_QUERY` + `planBaselineDrift`): plan name, cell count, live-tenant count, and one status chip:

| State | Chip |
|---|---|
| `HasAnyBaseline == false` | `bg-red-600 text-white` — **"Not configured — provisioning will fail"** |
| `IsStale` | `bg-amber-600 text-white` — "Stale — N missing, M extra" |
| otherwise | `bg-emerald-600 text-white` — "In sync" |

**Right — the matrix** (`PLAN_ROLE_BASELINE_QUERY`), role selector from `PLAN_BASELINE_ROLE_OPTIONS_QUERY`.

- Role = **BUSINESSADMIN** → matrix is **read-only**. Header note: *"Generated from this plan's features and menus. Edit the plan's feature list to change it."* Primary action is **Regenerate** (`regeneratePlanBaseline`), not Save. Show the drift banner above the grid when stale, with the missing/extra counts.
- Role = anything else → today's editable grid, saved with `BULK_UPDATE_PLAN_ROLE_BASELINE_MUTATION`. Unchanged behaviour.
- Footer, always: *"Saving or regenerating changes what the **next** tenant on this plan is born with. Existing tenants are updated from the Tenants & Push tab."*
- The `hiddenMenuCount` from the query renders as a muted footer line: *"N menus are not included in this plan."*

Reuse screen #70's matrix grid component — `PlanBaselineMatrixBuilder` deliberately returns the same `RoleCapabilityMatrixDto` so that it can. Do not build a second grid.

### ⑤.2 O-24 tab 4 — Tenants & Push

Consumes the already-built `TENANT_BASELINE_DRIFT_QUERY`, `BASELINE_PUSH_PREVIEW_QUERY`, `EXECUTE_BASELINE_PUSH_MUTATION`, `ROLLOUT_HISTORY_QUERY`, `ROLLOUT_RUN_DETAIL_QUERY`.

- Tenant list per plan with each tenant's missing-cell count.
- **Preview before push, always.** The preview is the confirmation dialog's body.
- The dialog must state, in plain words: **"This grants missing permissions. It never removes any."** `ExecuteBaselinePush` is additive-only; an operator who expects a downgrade to strip access will otherwise believe it did.
- Push result → refetch the drift list and the history table.

### ⑤.3 `/ops/plans` — the unmapped-menu banner

On `plan-matrix-page.tsx`, in the **"Features · Feature catalogue"** section, when `unmappedMenuCount > 0`:

> **N menus are not mapped to any feature.** They are excluded from every generated baseline. Map them to a feature, or tenants will never receive them.

Plus the same per-plan drift chip from ⑤.1 next to each plan, so the operator sees the consequence on the screen where they caused it.

The existing tooltip at [plan-matrix-page.tsx:1031](PSS_2.0_Frontend/src/presentation/components/page-components/ops/plans/plan-matrix-page.tsx#L1031) reads *"Menus this feature unlocks — global, not per plan"*. That stays true and stays put — the mapping is global; what a **plan** buys is the entitlement tick.

---

## §⑥ Known limits to state in the UI

1. Regenerate does not touch live tenants. Tab 4 does that.
2. A downgrade never revokes anything. Menus vanish from the sidebar via `IPlanMenuFilter`; the grants stay so a re-upgrade restores them.
3. Only BUSINESSADMIN is generated. Every other role stays hand-curated.
4. Strict mode changes the generated output. Flipping it off and regenerating will *add* cells; flipping it on will *remove* them.
5. Drift is computed per request. Two operators regenerating the same plan at once is last-writer-wins; the reconcile is idempotent, so the outcome is still correct.

---

## §⑦ Not in scope

- No change to `PlanMenuFilter` or to runtime sidebar filtering.
- No change to `ProvisionTenant`, `PlanBaselineApplier`, `ExecuteBaselinePush`, `RolloutResolver`, or `GetPlanBaselineSummary`.
- No auto-regenerate hook on plan save. It is tempting and it is wrong for now: a mis-click on the plan screen would silently rewrite a baseline. Regenerate stays a deliberate, audited, operator-initiated act. Revisit once the drift chip has been lived with.
- No `IsGenerated` column, no generation timestamp, no new table.
- No scheduled drift job or notification.
- No tenant-side UI.
- No back-fill of tenants that were provisioned short. That is tab 4's push, run by hand.

---

## §⑧ Acceptance

Numbered so the build log can tick them.

1. `PlanBaselineGenerator.GenerateAsync` exists and performs **zero writes**.
2. Generated cells for a plan equal exactly: plan-scoped menus × their `MenuCapabilities`, minus control-plane menus.
3. Duplicate `MenuCapabilities` rows produce exactly one cell each — same `GroupBy(mc => mc.CapabilityId)` de-duplication as `PlanBaselineMatrixBuilder`.
4. `IPlanMenuScope` has a `strict` overload; the existing method's behaviour and signature are **unchanged**; `PlanMenuFilter.cs` is **not modified** — prove it with `git diff --stat`.
5. Strict mode excludes unmapped menus **and their sub-trees**, but never a `MenuScopeCascade.IsNeverBlocked` code.
6. Strict mode with an empty `FeatureMenuMaps` returns an **empty** set, not everything.
7. `RegeneratePlanBaselineCommand` only ever reads, inserts or deletes rows where `RoleCode = "BUSINESSADMIN"`.
8. Regenerating a plan that also has curated FINANCE rows leaves every FINANCE row byte-identical.
9. Extra cells are **hard-deleted** (`Remove`), not soft-deleted.
10. Regenerate is idempotent: the second run reports `Added = 0, Removed = 0`.
11. `BASELINE_WOULD_BE_EMPTIED` throws when generation yields zero cells and stored cells exist.
12. Every regenerate writes one `ops.PlatformAuditLog` row with the added/removed counts in `ChangesJson`.
13. `GetPlanBaselineDriftQuery` with `planId = null` returns one row per plan and performs **zero writes**.
14. Drift for an in-sync plan reports `IsStale = false, Missing = 0, Extra = 0`.
15. A plan with no baseline at all reports `HasAnyBaseline = false` and the UI shows the red *"provisioning will fail"* chip.
16. Menus and the feature map are loaded **once** for the all-plans drift query, not once per plan.
17. Every `ops` / `billing` read carries `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true` guard.
18. All awaits in every handler are sequential — no `Task.WhenAll` over one `DbContext`.
19. **No `ExecuteSqlRawAsync` / `FromSqlRaw` / string-built SQL anywhere in the diff** — grep the diff to prove it.
20. **No migration file and no snapshot change in the diff** — `git status` proves it.
21. `ProvisionTenant.cs`, `PlanBaselineApplier.cs`, `ExecuteBaselinePush.cs` are **not modified**.
22. GraphQL fields resolve as `planBaselineDrift` and `regeneratePlanBaseline` — verified against a live schema/introspection, not assumed (⚠ Rule 7).
23. O-24 tab 3 renders; BUSINESSADMIN is read-only with a Regenerate button; other roles remain editable and save through the existing mutation.
24. Tab 3's stale banner shows the missing and extra counts and disappears after a successful regenerate.
25. Tab 4 renders and shows the preview inside the confirmation dialog before any push.
26. The push dialog states in plain words that it grants and never removes.
27. `/ops/plans` shows the unmapped-menu banner when the count is > 0, and a drift chip per plan.
28. Every status chip uses solid `bg-X-600` + `text-white` (⚠ Rule 13).
29. Frontend typecheck exits **0** under `npx tsc --noEmit --incremental false`, no pipe.
30. After regenerating a plan, `Step3_SeedRolesAsync` finds a non-empty role set for it — i.e. `SELECT DISTINCT "RoleCode"` returns at least BUSINESSADMIN.

---

## §⑨ Open questions

| # | Question | Blocks |
|---|---|---|
| Q1 | §⓪ Q1 — how many menus are unmapped? | Whether strict mode defaults on or off |
| Q2 | §⓪ Q2 — which role codes besides BUSINESSADMIN should a plan carry? | Whether tab 3's curated path is needed for the demo |
| Q3 | Should BUSINESSADMIN really get **every** capability on an in-plan menu, including DELETE and EXPORT? Assumed yes — they are the tenant owner. If any capability must be withheld even from them, it needs an exclusion list and §④.1 changes. | §④.1 |
| Q4 | Once the drift chip has been used for a while, should plan-entitlement save auto-regenerate? Deliberately out of scope now (§⑦). | Nothing today |
| Q5 | Is `plan-role-baseline-bootstrap-seed.sql` still needed after §④.3 ships, or does Regenerate replace it? Assumption: **replaced** for BUSINESSADMIN; still needed for any curated role from Q2. | Whether the seed stays in the provisioning runbook |

---

## §⑩ Build log

_(append one entry per session: date, what was built, what deviated, what is left)_

### 2026-08-06 — full build (§④ backend, §⑤ frontend)

**Open questions answered (§⓪ / §⑨)**

- **Q1 — 196 of 210 active menus are unmapped.** `billing.FeatureMenuMaps` holds 23 rows. Strict mode is therefore **built but defaults OFF** on all six surfaces (command, query, both resolvers, both gql documents). See deviation 1.
- **Q2 — only `BUSINESSADMIN` has baseline cells today**: CUSTOM 1366, FREE 971, PLAN_100K 1366, PLAN_50K 1169. No curated FINANCE/FUNDRAISER rows exist, so tab 3's curated-role path is not demo-blocking. The generator stays role-scoped regardless, so it can never wipe them later.
- Q3 assumed **yes** (BUSINESSADMIN gets every capability on an in-plan menu) — unchanged, no exclusion list built.
- Q4 out of scope, as written. Q5: the bootstrap seed is **replaced** for BUSINESSADMIN by Regenerate; still needed for any curated role.

**Built**

- §④.1 `PlanBaselineGenerator.cs` — `internal static`, zero writes; `GeneratedBaseline(Cells, MenuCount, UnmappedMenuCount)`; `OwnedRoleCode = "BUSINESSADMIN"`; `NeverBlockedPrefixes = BILLING / SETTING / ACCESSCONTROL` mirrored from `MenuScopeCascade` because `Base.Application` cannot reference `Base.Infrastructure`.
- §④.2 `IPlanMenuScope` strict overload + `PlanMenuScope` implementation. Existing one-arg method delegates with `strict:false` — signature and behaviour untouched.
- §④.3 `RegeneratePlanBaselineCommand` — BUSINESSADMIN-scoped, hard-deletes extras, chunked saves (200), refuses `BASELINE_WOULD_BE_EMPTIED`, one `platform.rbac.baseline.regenerated` audit row.
- §④.4 `GetPlanBaselineDriftQuery` + `PlanBaselineDriftRowDto` — universe loaded **once** for the all-plans case, one grouped stored-cell read, one grouped tenant-count read, sequential per-plan scope resolution.
- §④.5 both resolvers; §⑤ FE DTOs, gql documents, tab 3 (`plan-baseline-tab.tsx`), tab 4 (`tenant-push-tab.tsx`), `/ops/plans` banner + per-plan chip, shell wiring, barrel.

**Deviations**

1. **`strict` defaults to `false`, not `true`.** §④.3/§④.4 write `bool strict = true`; with 196 unmapped menus that default would generate near-empty baselines and break provisioning. Flip it once the §⑤.3 banner has been acted on.
2. **Route is `(master)/platform/staff`, not `(core)/ops`.** §⑤ names `(core)`; the O-24 shell already lives at `src/app/[lang]/(master)/platform/staff/page.tsx`. Tabs 3 and 4 went into that existing shell rather than a second one.
3. **Strict + an empty `FeatureMenuMaps` returns the never-blocked menus, not a literally empty set** (acceptance 6). That is exactly what the strict seed-walk produces when every menu is unmapped, and returning nothing would lock an operator out of BILLING / SETTING / ACCESSCONTROL. `IPlanMenuScope`'s XML doc was corrected to say so.

**Acceptance**

- Ticked by construction/inspection: 1–18, 23–28.
- 19 — grep over `PlatformRbac/` and `Services/Billing/` for `ExecuteSqlRaw|FromSqlRaw|*Interpolated`: no hits.
- 20 — no migration or snapshot file dated 2026-08-06; newest is `20260805112547_…`, pre-existing.
- 21 — `PlanMenuFilter.cs` (08-04 14:47), `PlanBaselineApplier.cs` (08-04 14:55), `ExecuteBaselinePush.cs` (08-04 15:44) untouched. `ProvisionTenant.cs` carries a same-day mtime from earlier unrelated work and contains **no** reference to `PlanBaselineGenerator` / `Regenerate` / `strict:` — not modified by this build.
- 29 — `npx tsc --noEmit --incremental false` exits **0**, 9 `platformstaff` files in `--listFiles` (a real check, not a zero-file pass).

**Left for the user**

- **22** — live introspection of `planBaselineDrift` / `regeneratePlanBaseline` could not be run: the API was not listening on `https://localhost:57898/graphql/`. Names follow the Get-stripping convention and match the resolver methods, but they are unverified against a running schema.
- **30** — `SELECT DISTINCT "RoleCode"` after a regenerate, once the backend is built and running.
- `dotnet build` (never run here, by standing rule). No migration is needed — §③ said "None." and none was authored.
