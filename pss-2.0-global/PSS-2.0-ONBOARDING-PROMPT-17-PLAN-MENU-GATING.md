# PROMPT-17 — Plan-based module & menu gating (data-driven)

**Surface:** **BE only + seed SQL.** No file under `PSS_2.0_Frontend/` is touched.
**Depends on:** PROMPT-13 (billing foundation), PROMPT-16 (billing BE gaps) — both built.
**Follows with:** PROMPT-18 (ops CRUD screen for the feature↔menu map) — **not** this session.

**Goal in one sentence:** make "which menus a tenant sees" a *row in a table an ops user edits*,
not a `Dictionary<string,string>` literal in C#, and apply that same filter to **all three**
consumers — the sidebar, tenant provisioning, and the role-capability matrix.

---

## ⚠️ RULES FOR THIS SESSION — ALL HARD

| Rule | Detail |
|---|---|
| **Do not touch the frontend** | No file under `PSS_2.0_Frontend/`. Every change here is invisible to FE code — the GraphQL contracts do not change shape, only the *rows they return*. If you think an FE change is needed, write it into §⑫ and don't make it. |
| **Do not run `dotnet build`** | The user builds. Write code that compiles by inspection; read the surrounding file before you add to it. |
| **Do not author a migration** | This prompt adds two tables. You write the **entity + EF configuration + `IApplicationDbContext` DbSet**, then write the migration *spec* into §⑧. **Never** run `dotnet ef migrations add`, `database update`, or `migrations remove`; never hand-edit a migration file or the model snapshot. The user authors, runs and commits it. |
| **Seed SQL: write, do not apply** | New `.sql` goes in `sql-scripts-dyanmic/`. You never execute it. |
| **Verify every property name** | Never assume a column, DTO property or GraphQL field name. Read the entity or the resolver first. Audit fields are `CreatedDate` / `ModifiedDate` (never `CreatedAt`). |
| **UTC only** | Every Postgres date column is `timestamp with time zone`; Npgsql throws on `Kind = Unspecified`. `DateTime.UtcNow`, never `DateTime.Today` inside an EF predicate. |
| **HotChocolate naming** | `Get` is stripped from every resolver (`GetFeatureMenuMap` → `featureMenuMap`); input types get `Input` appended. A wrong name compiles clean and fails only at runtime. This prompt adds **no new resolver** — if you find yourself adding one, you have gone out of scope. |
| **Backend is gitignored** | The Grep/Glob tools return **zero** `.cs` matches. Use `find -iname` to locate a file, or scope `grep -rn --include=*.cs` to **one project subdirectory** — a repo-wide grep times out. Absolute-path `Read` works fine. |

---

## ⓪ Where the code lives (read all of these before writing anything)

```
Base.Application/Interfaces/
    MenuFeatureMap.cs                                  ← STEP 3 replaces its guts
    BillingCodes.cs                                    ← FeatureCodes / PlanCodes (STEP 4 adds 4 codes)
    IEntitlementService.cs                             ← ResolveAsync / Invalidate / InvalidateAll

Base.Application/Business/AuthBusiness/
    Menus/Queries/GetParentChildMenu.cs                ← consumer 1 (sidebar). STEP 1 fixes line ~101
    Modules/Queries/GetUserRoleModule.cs               ← READ ONLY. Deliberately NOT changed — see §②
    RoleCapabilities/Queries/GetRoleCapabilityMatrix.cs        ← consumer 3 (read).  STEP 5
    RoleCapabilities/Commands/BulkUpdateRoleCapabilityMatrix.cs ← consumer 3 (write). STEP 5
    RoleCapabilities/Commands/GrantCapabilityToAllRoles.cs      ← consumer 3 (write). STEP 5
    RoleCapabilities/Commands/ResetRoleCapabilityMatrix.cs      ← consumer 3 (write). STEP 5

Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/
    ProvisionTenant.cs                                 ← consumer 2. STEP 1 deletes ModuleFeatureMap

Base.Infrastructure/Services/Billing/EntitlementService.cs     ← the cache + fail-closed sentinel
Base.Domain/Models/BillingModels/                              ← STEP 2 adds two entities here
Base.Infrastructure/Data/Configurations/BillingConfigurations/ ← STEP 2 adds two configs here

.claude/screen-tracker/MODULE_MENU_REFERENCE.md        ← the menu topology. Source of truth for §④
sql-scripts-dyanmic/billing-plan-catalog-seed.sql      ← the seeded plan × feature matrix
```

---

## ① The mental model — read this or you will fix the wrong thing

### The gating chain today

```
billing.Plans ──▶ billing.PlanEntitlements (FeatureCode, IsEnabled)
                          │
                          ▼
              IEntitlementService.ResolveAsync(companyId)
                  → TenantEntitlements(Status, Features{code→bool}, Quotas)
                          │
        ┌─────────────────┼──────────────────────────┐
        ▼                 ▼                          ▼
  sidebar filter    provisioning grant       role-capability matrix
  (GetParentChild-  (ProvisionTenant         ◀── DOES NOT EXIST YET.
   Menu.cs)          step 4b)                     This prompt adds it.
```

Everything **left of "feature"** is already ops-editable (`SavePlanEntitlements` writes
`PlanEntitlements` from the ops plan-catalog screen). Everything **right of "feature"** is frozen
in C# literals. That asymmetry is the entire problem: selling a new bundle today requires a code
change and a redeploy.

### `auth.Modules` is NOT a sellable axis — this is the single most important fact here

There are exactly **six** modules: `CRM`, `ORGANIZATION`, `ACCESSCONTROL`, `GENERAL`, `SETTING`,
`REPORTAUDIT`. `CRM` alone holds **21 parent menu groups** — Contacts, Donations, Grants, Events,
Volunteers, Cases, Memberships, Communications and the rest all live *inside* `CRM`.

Therefore **Contacts is not a module.** `CRM_CONTACT` is a *menu group* (a parent menu with
children) inside the `CRM` module. Since even a FREE tenant gets Contacts, **every tenant on every
plan must be granted the `CRM` module.** Module-level gating is all-or-nothing and can only ever be
"grant everything" — which is why STEP 1 deletes it rather than fixing it.

**All real gating happens at the menu-group / menu-leaf level.**

### Naming trap — two different things, one word

* `ORGANIZATION` — a **module** (holds `ORG_COMPANY` etc.).
* `CRM_ORGANIZATION` — a **menu group inside CRM** (holds Campaigns + donation-config screens).

They are unrelated. Do not let one stand in for the other.

### The two independent checks

1. **API authorization.** `CustomAuthorizeService.HasAccessAsync` joins UserRole → Menu(MenuCode)
   → Capability where `HasAccess = true`. It matches on **MenuCode only**.
2. **Sidebar rendering.** `GetParentChildMenuHandler` builds nav from menus the user holds
   **ISMENURENDER** on, then walks parents up from the authorized *leaves*.

**Hiding a menu is COSMETIC ONLY.** The security boundary is the command-side `[RequiresFeature]`
gate, which still returns 403 for a hidden-but-guessed route. Nothing in this prompt changes that,
and nothing in this prompt should be described in a comment as if it were a security control.

### Subtree cascade already works

`IsPlanBlocked` in `GetParentChildMenu.cs` walks ancestors with a 32-deep cycle guard, so blocking
`CRM_GRANT` takes its four leaves with it. The map is matched against **any MenuCode — group or
leaf** — so leaf-level gating needs **no mechanism change**, only a data row.

### Billing must never be gated

`BILLING`, `BILLING_OVERVIEW`, `BILLING_PLANS`, `BILLING_INVOICES` must stay reachable on **every**
plan, including a lapsed one — otherwise a tenant whose subscription expired cannot reach the screen
that lets them pay. Today this is enforced by a comment saying "don't add them." After STEP 2 it is
enforced by **seeding no `FeatureMenuMaps` row for them**, plus the hard guard in §⑥.

---

## ② The five defects this prompt fixes

### D-A — module gating is dead weight and actively harmful

`ProvisionTenant.cs` (~line 164) declares:

```csharp
internal static class ModuleFeatureMap
{
    public static readonly IReadOnlyDictionary<string, string[]> Map = new Dictionary<...>
    {
        ["CRM"]          = new[] { "MODULE:CRM", "MODULE:CONTACTS", "MODULE:DONATIONS" },
        ["ORGANIZATION"] = new[] { "MODULE:ORGANIZATION", "MODULE:EVENTS", "MODULE:CAMPAIGNS" },
        ["REPORTAUDIT"]  = new[] { "MODULE:REPORTS", "MODULE:AUDIT" },
    };
    public static readonly string[] AlwaysOnModuleCodes =
        { "SETTING", "GENERAL", "ACCESSCONTROL", "PSSCORE", "ADMIN" };
}
```

Of the nine feature codes named there, **only `MODULE:CONTACTS` actually exists** in
`FeatureCodes.All`. `MODULE:CRM`, `MODULE:DONATIONS` (plural — the real code is singular
`MODULE:DONATION`), `MODULE:ORGANIZATION`, `MODULE:EVENTS` (plural), `MODULE:CAMPAIGNS`,
`MODULE:REPORTS`, `MODULE:AUDIT` are **all phantoms**.

Consequence, live today: `entitlements.Features.TryGetValue("MODULE:ORGANIZATION", …)` is always
false, so the `ORGANIZATION` and `REPORTAUDIT` modules are granted to **nobody, on any plan**.
`PSSCORE` and `ADMIN` in `AlwaysOnModuleCodes` are likewise not real module codes and match nothing.

**Fix: delete the class.** Do not repair the codes — see §① for why module gating cannot work.

### D-B — module grants are a one-time provisioning snapshot

The only writers of `auth.RoleModules` are `ProvisionTenant.cs` step 4b and the manual
`CreateRoleModule` command. `ConfirmSubscriptionPayment` and `AssignSubscription` change the plan
and **never re-sync module grants**. So a FREE tenant that upgrades to PLAN_100K keeps whatever
modules it was provisioned with, forever.

**This defect dissolves once D-A is fixed** — if every module is always granted, there is nothing to
re-sync. Do not build a re-sync job.

### D-C — the sidebar gate is fail-open, keyed on the wrong thing

`GetParentChildMenu.cs` ~line 101:

```csharp
if (entitlements.Features.Count > 0)   // ← WRONG
```

The intent was "only filter if we know the plan." But `Features.Count` is a property of *seed
completeness*, not of subscription state. A plan whose `PlanEntitlements` rows were never seeded
resolves to an empty dictionary and **renders the entire product to that tenant.**

`EntitlementService` returns the fail-closed sentinel
`TenantEntitlements(companyId, "None", "None", empty, empty)` when there is no live subscription —
so `Status` is the correct discriminator and `Features.Count` is not.

**Fix:** `if (entitlements.Status != SubscriptionStatuses.None)`.

Note this makes the empty-feature case *fail closed*: a `Trial`/`Active` plan with zero seeded
entitlement rows now hides every mapped menu. That is the correct posture — a mis-seeded plan should
look broken to ops, not generous to the tenant. §⑨ acceptance item 3 verifies it deliberately.

### D-D — coverage and configurability

Only **12 of the 21** CRM menu groups appear in `MenuFeatureMap`. Nine render on **every** plan
including FREE: `CRM_DASHBOARDS`, `CRM_MAINTENANCE`, `CRM_CERTIFICATE`, `CRM_NOTIFICATION`,
`CRM_AUTOMATION`, `CRM_PRAYERREQUEST`, `CRM_ORGANIZATION`, `CRM_FIELDCOLLECTION`,
`CRM_INTELLIGENCE`. Two of those are premium surfaces sitting wide open right now —
`CRM_INTELLIGENCE` (AI Draft, Predictive Analytics) and `CRM_FIELDCOLLECTION` (Ambassadors, Receipt
Books).

And the vocabulary itself is frozen: `FeatureCodes.All` is a hardcoded `string[]` that **drives the
ops plan-matrix rows** ("one row per code"). So selling a new feature needs a redeploy even after
the menu map becomes data. **Both** the feature list and the feature→menu map must become tables.

### D-E — the role-capability matrix ignores the plan entirely

`GetRoleCapabilityMatrix.cs:49-50`:

```csharp
var menus = await dbContext.Menus
    .Where(m => m.IsDeleted == false && m.IsActive == true)
```

No `IEntitlementService` dependency, no plan filter. A FREE tenant's admin sees Grant, Case,
Membership and Intelligence rows in the matrix and can grant capabilities on screens the tenant has
not bought. The grants are cosmetically useless (the sidebar hides them, `[RequiresFeature]` 403s
them) but they are confusing, they inflate the `GrantedCount` badge on every role column, and they
mean an upgrade silently switches on access nobody reviewed.

**The same unfiltered predicate appears on the write side** — `BulkUpdateRoleCapabilityMatrix.cs:163`,
`GrantCapabilityToAllRoles.cs:111`, `ResetRoleCapabilityMatrix.cs:116`. Guarding only the query
would leave a stale or hand-crafted payload able to write rows for blocked menus. All four change.

### Explicitly NOT changed

* **`GetUserRoleModule.cs`** — reads `auth.RoleModules` with no plan filter, and that stays. Its
  existing comment ("modules are coarse") is correct. After D-A every tenant holds every module and
  a filter here would have nothing to do.
* **`GetMenuAdminTree.cs`** — the menu-administration tree must show **all** menus regardless of
  plan; it is the screen used to *configure* menus. Filtering it would make unbought menus
  un-administrable. Leave it. Add a one-line comment saying so, so the next reader doesn't "fix" it.

---

## ③ The design — two tables, one migration

```
billing.Features
    FeatureId       int   PK identity
    FeatureCode     varchar(64)   UNIQUE   -- "MODULE:CONTACTS"
    FeatureName     varchar(128)           -- "Contacts"
    Description     varchar(512)  null
    SortOrder       int                    -- drives ops plan-matrix row order
    IsActive        bool
    + standard audit columns (CreatedDate, CreatedBy, ModifiedDate, ModifiedBy, IsDeleted)

billing.FeatureMenuMaps
    FeatureMenuMapId int  PK identity
    FeatureCode      varchar(64)           -- FK by code to Features.FeatureCode
    MenuCode         varchar(64)           -- matches auth.Menus.MenuCode; group OR leaf
    UNIQUE (FeatureCode, MenuCode)
    + standard audit columns
```

**Neither table carries `CompanyId`.** This is platform-level catalog configuration, exactly like
`billing.Plans`. Do not add a tenant scope.

**Why FK by `MenuCode` and not `MenuId`:** menu rows are re-seeded per environment and `MenuId`
values are not stable across databases; `MenuCode` is. The existing `MenuFeatureMap` is already
keyed by code and `HasAccessAsync` already matches on code only. Keep a plain `varchar` with a
non-unique index on `MenuCode` — **no FK constraint to `auth.Menus`**, both because it crosses
schemas and because a map row for a not-yet-seeded menu must be allowed to sit dormant rather than
break the insert.

**`FeatureCodes` survives** as C# constants used by seed scripts, `[RequiresFeature]` attributes and
tests. It stops being the *authority* on which features exist — `billing.Features` is. Update its
doc comment to say so. Do **not** delete it; `[RequiresFeature(FeatureCodes.ModuleGrant)]` call
sites depend on it and those are compile-time by nature.

---

## ④ The menu-group disposition (decided — build exactly this)

Nine groups are currently unmapped. Disposition:

| Menu group | Disposition | Feature code | FREE | 50K | 100K | CUSTOM |
|---|---|---|:--:|:--:|:--:|:--:|
| `CRM_MAINTENANCE` | bundle into existing | `MODULE:CONTACTS` | on | on | on | on |
| `CRM_CERTIFICATE` | bundle into existing | `MODULE:DONATION` | on | on | on | on |
| `CRM_ORGANIZATION` | leave unmapped | — | on | on | on | on |
| `CRM_NOTIFICATION` | leave unmapped (platform infra) | — | on | on | on | on |
| `CRM_DASHBOARDS` | **group** unmapped; map its **leaves** | — | see below | | | |
| `CRM_FIELDCOLLECTION` | **new code** | `MODULE:FIELDCOLLECTION` | off | on | on | on |
| `CRM_AUTOMATION` | **new code** | `MODULE:AUTOMATION` | off | off | on | on |
| `CRM_PRAYERREQUEST` | **new code** | `MODULE:PRAYERREQUEST` | off | off | on | on |
| `CRM_INTELLIGENCE` | **new code** | `MODULE:INTELLIGENCE` | off | off | on | on |

`CRM_DASHBOARDS` must **not** be blocked as a group — a FREE tenant still needs its contact and
donation dashboards. Map the leaves individually instead, which the existing cascade already
supports:

| Dashboard leaf | Feature code |
|---|---|
| `CONTACTDASHBOARD` | *unmapped* — every plan |
| `DONATIONDASHBOARD` | `MODULE:DONATION` |
| `COMMUNICATIONDASHBOARD` | `CHANNEL:EMAIL` |
| `CASEDASHBOARD` | `MODULE:CASE` |
| `VOLUNTEERDASHBOARD` | `MODULE:VOLUNTEER` |
| `AMBASSADORDASHBOARD` | `MODULE:FIELDCOLLECTION` |

Net: vocabulary grows **10 → 14** codes; four new rows per plan in the catalog seed.

**Deliberately out of scope: leaf gating inside `CRM_CONTACT` and `CRM_DONATION`.** Both are parent
groups with many children (`BULKDONATION`, `RECONCILIATION`, `RECURRINGDONOR`, `CONTACTIMPORT`,
`TAGSEGMENTATION` are the obvious upsell candidates). The decision is to **leave both groups fully
open on every plan** and let the already-seeded CONTACTS/DONATIONS **quotas** limit FREE instead of
hiding screens — a FREE tenant hitting a 500-contact ceiling converts better than one who cannot
find the import button. The table-based design added here admits this later as a **pure data edit**
with no code change, which is precisely why it is safe to defer.

---

## ⑤ Build steps

Do them in this order. Steps 1 and 5 are independently shippable; step 4 is inert until the user
applies the migration from step 2.

### STEP 1 — kill module gating, fix the fail-open gate (no schema)

1. `ProvisionTenant.cs`: delete `internal static class ModuleFeatureMap` entirely.
2. In its place define the always-on list with the **six real** module codes:
   ```csharp
   // auth.Modules is coarse — CRM alone holds 21 menu groups including Contacts, which every
   // plan gets. Module grants are therefore all-or-nothing; real plan gating happens at the
   // menu level via billing.FeatureMenuMaps. Grant every module to every tenant.
   private static readonly string[] AllModuleCodes =
       { "CRM", "ORGANIZATION", "ACCESSCONTROL", "GENERAL", "SETTING", "REPORTAUDIT" };
   ```
3. Rewrite step 4b (~line 582-612) to grant all six. The `_entitlementService.ResolveAsync` call in
   that block becomes unused — remove it **only if** nothing else in the method uses it; read the
   whole method before deleting, and leave the `IEntitlementService` ctor injection alone if any
   other step still needs it.
4. `GetParentChildMenu.cs` ~line 101: `entitlements.Features.Count > 0` →
   `entitlements.Status != SubscriptionStatuses.None`. Update the adjacent comment to explain that
   `Features.Count` measures seed completeness, not subscription state.

**Effect after step 1 alone:** `ORGANIZATION` and `REPORTAUDIT` become reachable for the first time,
and a FREE tenant's sidebar starts genuinely differing from a PLAN_50K tenant's.

### STEP 2 — the two tables (entities + config + DbSet + migration spec)

Model the entities on an existing billing entity — read
`Base.Domain/Models/BillingModels/PlanEntitlement.cs` first and match its base class, audit columns
and nullability conventions exactly. Same for the configurations: read
`BillingConfigurations/PlanEntitlementConfiguration.cs` and match `ToTable(..., schema: "billing")`,
index and max-length style.

Register both `DbSet`s on `IApplicationDbContext` **and** the concrete `ApplicationDbContext`.

Then write the migration spec into §⑧ — table DDL, indexes, uniqueness. **Do not generate it.**

### STEP 3 — `MenuFeatureMap` reads the table

Same public surface — `public static string? FeatureFor(string? menuCode)` must keep working, or
convert it to an injected `IMenuFeatureMap` service if that reads better against the call sites
(there is exactly one caller today plus the four added in step 5, so either is fine; prefer the
injected service since step 5 needs DI there anyway).

Requirements:
* Backed by `IMemoryCache`, same TTL discipline as `EntitlementService` (~60s). The map is
  platform-wide, so **one cache entry, not one per company.**
* Unmapped menu ⇒ `null` ⇒ never hidden. Preserve this exactly.
* Cache must be invalidated when `FeatureMenuMaps` is written. There is no such writer in this
  prompt (that is PROMPT-18), so expose an `Invalidate()` method and leave it uncalled — PROMPT-18
  wires it.
* Confirm `IEntitlementService.Invalidate(companyId)` already fires on every plan mutation
  (`SavePlanEntitlements`, `AssignSubscription`, `ConfirmSubscriptionPayment`). If any one of them
  does not, add the call — a plan change that doesn't reach the sidebar for 60s is acceptable; one
  that never reaches it is not. Record what you found in §⑬.

Then seed the **existing 12 rows verbatim** so this step is behaviour-neutral:

```
CRM_CONTACT→MODULE:CONTACTS   CRM_FAMILY→MODULE:CONTACTS
CRM_DONATION→MODULE:DONATION  CRM_P2PFUNDRAISING→MODULE:DONATION
CRM_EVENT→MODULE:EVENT        CRM_VOLUNTEER→MODULE:VOLUNTEER
CRM_MEMBERSHIP→MODULE:MEMBERSHIP  CRM_CASEMANAGEMENT→MODULE:CASE
CRM_GRANT→MODULE:GRANT        CRM_COMMUNICATION→CHANNEL:EMAIL
CRM_SMS→CHANNEL:SMS           CRM_WHATSAPP→CHANNEL:WHATSAPP
```

### STEP 4 — seed the new vocabulary and the nine groups

One idempotent script, `sql-scripts-dyanmic/billing-feature-menu-map-seed.sql`:

* All 14 `billing.Features` rows (10 existing + 4 new from §④), with `SortOrder` grouping
  `MODULE:*` before `CHANNEL:*`.
* All `billing.FeatureMenuMaps` rows: the 12 from step 3, plus `CRM_MAINTENANCE`,
  `CRM_CERTIFICATE`, the four new groups, and the five mapped dashboard leaves.
* Four new `billing.PlanEntitlements` rows per plan for the new codes, per the §④ on/off grid.
* Idempotent throughout — `INSERT … WHERE NOT EXISTS` or `ON CONFLICT DO NOTHING`. The user may run
  it more than once.
* Also add the four new constants to `FeatureCodes` and to `FeatureCodes.All` so the ops plan matrix
  renders their rows before PROMPT-18 makes the list dynamic.

### STEP 5 — the role-capability matrix (the new requirement)

Apply the plan filter to all four handlers. **Extract the logic once**, do not copy it four times —
put a `PlanMenuFilter` helper next to `MenuFeatureMap` exposing something like:

```csharp
// Returns the set of MenuIds blocked for this company, ancestor-cascade included.
Task<HashSet<int>> GetBlockedMenuIdsAsync(int companyId, CancellationToken ct);
```

It must reproduce `GetParentChildMenu`'s semantics exactly: resolve entitlements, skip filtering
when `Status == SubscriptionStatuses.None` is **false**… — precisely, filter **only when**
`Status != None`; walk ancestors with the same 32-deep cycle guard; a cycle returns *not blocked*.
Once it exists, refactor `GetParentChildMenu` to call it so there is one implementation, not two
that can drift.

Then:

* **`GetRoleCapabilityMatrix`** — inject `IEntitlementService` (+ the helper), and drop blocked
  menus from `rows` before cells are built. Because `cells` is built from `rows`, the cells and the
  `GrantedCount`/`TotalCount` badges follow automatically — but **verify** that `GrantedCount` is
  computed from the filtered set, since today it counts `existingCells` directly at line ~111 and
  would otherwise still include blocked menus. Fix that count to use the filtered rows.
* **`BulkUpdateRoleCapabilityMatrix`**, **`GrantCapabilityToAllRoles`**, **`ResetRoleCapabilityMatrix`**
  — filter the `dbContext.Menus` result the same way, so a stale FE payload naming a blocked menu is
  **silently ignored**, not written. Silently, not an error: the FE has no way to know the plan
  changed mid-edit and a hard failure would block an otherwise-valid save.
* Existing `RoleCapability` rows on now-blocked menus stay in the database untouched. **Do not
  delete them.** They are inert while blocked and correct again on upgrade — deleting them would
  destroy configuration on a downgrade that may be temporary.

**Hard guard, applies to every one of the four:** if a filtering bug would blank the matrix, that is
worse than showing too much. Assert that the filter never removes a menu whose `MenuCode` starts
with `BILLING`, `SETTING`, or `ACCESSCONTROL` — those must remain administrable on any plan,
including a lapsed one.

---

## ⑥ Invariants — violate any of these and the build is wrong

1. An **unmapped** MenuCode is **never** hidden. Absence of a row means "always visible."
2. `BILLING*` menus have **no** `FeatureMenuMaps` row, ever. A lapsed tenant must reach the pay screen.
3. Filter **only when** `Status != SubscriptionStatuses.None`. When `Status == None` there is no
   live subscription and `EntitlementService` returns the sentinel with an empty feature dictionary
   — applying the filter to that would hide every mapped menu, including the path to billing. Skip
   it instead. This is the one place the design is deliberately fail-*open*, and it is bounded: a
   tenant with no subscription cannot execute anything, because `[RequiresFeature]` still 403s.
4. Blocking is **cosmetic**. No comment, name or doc in this change may describe it as a security
   control. `[RequiresFeature]` is the boundary.
5. Module grants are unconditional after STEP 1. No code path may make a `RoleModule` insert depend
   on entitlements again.
6. The sidebar and the role-capability matrix must agree — same helper, one implementation.

---

## ⑦ What must NOT be built here

* No ops CRUD screen for `Features` / `FeatureMenuMaps` — that is **PROMPT-18**. This session seeds
  the rows by SQL only.
* No GraphQL resolver, no DTO, no frontend file.
* No re-sync job for `RoleModules` (D-B dissolves — see §②).
* No leaf gating inside `CRM_CONTACT` / `CRM_DONATION` (see §④).
* No change to `GetUserRoleModule` or `GetMenuAdminTree` beyond the explanatory comment.
* No deletion of `FeatureCodes`.

---

## ⑧ Migration spec — for the user to author (fill this in, do not run it)

> **Suggested name:** `Add_BillingFeatureCatalog`

**Status:** entities + EF configurations are written and committed; the migration itself is **not**
authored. Run `dotnet ef migrations add Add_BillingFeatureCatalog` and verify it produces the DDL
below, then `database update`, then apply `sql-scripts-dyanmic/billing-feature-menu-map-seed.sql`.

Two new tables in schema `billing`. No changes to any existing table, no data migration, no drop.

```sql
CREATE TABLE billing."Features" (
    "FeatureId"    integer GENERATED ALWAYS AS IDENTITY NOT NULL,
    "FeatureCode"  character varying(64)  NOT NULL,
    "FeatureName"  character varying(128) NOT NULL,
    "Description"  character varying(512) NULL,
    "SortOrder"    integer                NOT NULL,
    "CreatedBy"    integer                NULL,
    "CreatedDate"  timestamp with time zone NULL,
    "ModifiedBy"   integer                NULL,
    "ModifiedDate" timestamp with time zone NULL,
    "IsActive"     boolean                NULL,
    "IsDeleted"    boolean                NULL,
    CONSTRAINT "PK_Features" PRIMARY KEY ("FeatureId")
);

CREATE UNIQUE INDEX "IX_Features_FeatureCode" ON billing."Features" ("FeatureCode");

CREATE TABLE billing."FeatureMenuMaps" (
    "FeatureMenuMapId" integer GENERATED ALWAYS AS IDENTITY NOT NULL,
    "FeatureCode"      character varying(64) NOT NULL,
    "MenuCode"         character varying(64) NOT NULL,
    "CreatedBy"        integer               NULL,
    "CreatedDate"      timestamp with time zone NULL,
    "ModifiedBy"       integer               NULL,
    "ModifiedDate"     timestamp with time zone NULL,
    "IsActive"         boolean               NULL,
    "IsDeleted"        boolean               NULL,
    CONSTRAINT "PK_FeatureMenuMaps" PRIMARY KEY ("FeatureMenuMapId")
);

CREATE UNIQUE INDEX "IX_FeatureMenuMaps_FeatureCode_MenuCode"
    ON billing."FeatureMenuMaps" ("FeatureCode", "MenuCode");

CREATE INDEX "IX_FeatureMenuMaps_MenuCode"
    ON billing."FeatureMenuMaps" ("MenuCode");
```

Notes the migration must preserve:

- **Neither table carries `CompanyId`.** Both are platform-global catalogue tables, not tenant data.
  Do not add a tenant filter or a global query filter to either.
- **No FK from `FeatureMenuMaps."MenuCode"` to `auth."Menus"."MenuCode"`** — deliberate, per §③.
  The reference crosses schemas, and a map row for a menu that has not been seeded yet must sit
  **dormant** rather than fail the insert. Ops must be able to pre-map a menu that ships next
  release. The `MenuCode` index is therefore plain **non-unique** (one menu can be mapped by more
  than one feature, and unmapped codes are simply inert).
- **No FK from `FeatureMenuMaps."FeatureCode"` to `Features."FeatureCode"` either** — same reason,
  and it keeps ops free to retire a feature row without cascading. The seed's VERIFY block contains
  an orphan query that catches a genuine mistake here.
- **`FeatureCode` is `varchar(64)`**, per §③. Note the pre-existing `billing.PlanEntitlements`
  `"FeatureCode"` column is `varchar(60)` — a 4-char discrepancy, left as-is because changing it is
  an ALTER on a live table outside this prompt's scope. No current code exceeds 24 chars, so the
  mismatch is inert; if a future code ever exceeds 60 it must be widened there first.
- Audit columns come from `Base.Domain.Abstractions.Entity` and are all nullable, matching every
  other billing table.

---

## ⑨ Acceptance — the user runs these after applying the migration and seed

1. FREE tenant sidebar shows Contacts, Families, Maintenance, Donations, Certificates,
   Communications, Organization, Notifications, Contact Dashboard. It does **not** show Events,
   Volunteers, Memberships, Cases, Grants, SMS, WhatsApp, Field Collection, Automation, Prayer
   Requests, Intelligence, P2P.
2. PLAN_50K adds Events, Volunteers, Memberships, Field Collection, Ambassador Dashboard.
   PLAN_100K adds everything.
3. **Fail-closed check:** temporarily delete one plan's `PlanEntitlements` rows → that tenant's
   mapped menus all disappear (billing and settings survive). Restore them.
4. A tenant with **no** subscription row still sees the full sidebar (Status = None ⇒ no filtering)
   and can reach `/billing`.
5. Role-capability matrix on a FREE tenant contains **no** Grant / Case / Membership / Intelligence
   rows, and the `GrantedCount` badge on each role column drops to match.
6. Upgrade that tenant to PLAN_100K, wait ~60s or restart, reload the matrix — the rows reappear and
   any previously-granted capabilities on them are still checked.
7. Post a `bulkUpdateRoleCapabilityMatrix` payload naming a blocked menu (curl / GraphQL playground)
   → the call succeeds and writes **nothing** for that menu.
8. `ORGANIZATION` and `REPORTAUDIT` module menus are reachable for a newly provisioned tenant —
   they were reachable for nobody before this change.
9. Menu admin tree still lists every menu on a FREE tenant.

---

## ⑩ Files expected to change

```
M  Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs
M  Base.Application/Business/AuthBusiness/Menus/Queries/GetParentChildMenu.cs
M  Base.Application/Business/AuthBusiness/Menus/Queries/GetMenuAdminTree.cs          (comment only)
M  Base.Application/Business/AuthBusiness/Modules/Queries/GetUserRoleModule.cs       (comment only)
M  Base.Application/Business/AuthBusiness/RoleCapabilities/Queries/GetRoleCapabilityMatrix.cs
M  Base.Application/Business/AuthBusiness/RoleCapabilities/Commands/BulkUpdateRoleCapabilityMatrix.cs
M  Base.Application/Business/AuthBusiness/RoleCapabilities/Commands/GrantCapabilityToAllRoles.cs
M  Base.Application/Business/AuthBusiness/RoleCapabilities/Commands/ResetRoleCapabilityMatrix.cs
M  Base.Application/Interfaces/MenuFeatureMap.cs
M  Base.Application/Interfaces/BillingCodes.cs                    (+4 codes, doc-comment change)
A  Base.Application/Interfaces/PlanMenuFilter.cs                  (or Services/, match convention)
A  Base.Domain/Models/BillingModels/Feature.cs
A  Base.Domain/Models/BillingModels/FeatureMenuMap.cs
A  Base.Infrastructure/Data/Configurations/BillingConfigurations/FeatureConfiguration.cs
A  Base.Infrastructure/Data/Configurations/BillingConfigurations/FeatureMenuMapConfiguration.cs
M  Base.Application/Data/Persistence/IApplicationDbContext.cs     (+2 DbSets)
M  Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs   (+2 DbSets)
M  Base.Infrastructure/DependencyInjection.cs                     (register the filter service)
A  sql-scripts-dyanmic/billing-feature-menu-map-seed.sql
```

These paths were verified against disk on 2026-08-03 — the two `DbContext` ones sit under
`Data/Persistence/`, **not** `Common/Interfaces/` or `Data/`. `IEntitlementService` is registered at
`Base.Infrastructure/DependencyInjection.cs:101` (`AddScoped`), so the new filter service goes in
that same method, registered the same way. `IMemoryCache` is already added in
`Base.API/DependencyInjection.cs` — do not re-register it.

The `A` (new file) paths are still a prediction — match whatever convention the neighbouring files
in each folder actually use.

---

## ⑪ Open questions for the user (answer inline, don't guess)

*(none blocking — §④ dispositions are decided. Raise anything you find here.)*

---

## ⑫ FE work this creates (write it down, do not build it)

**None.** No file under `PSS_2.0_Frontend/` was touched, and none needs to be. Confirmed by
inspection of every consumer:

- `parentChildMenu`, `roleCapabilityMatrix`, `bulkUpdateRoleCapabilityMatrix`,
  `grantCapabilityToAllRoles`, `resetRoleCapabilityMatrix` — **no** DTO, resolver signature, field
  name or nullability changed. Every one returns the same shape with **fewer rows**. The sidebar and
  matrix already render whatever the server sends, so they degrade correctly with no edit.
- `GrantedCount` / `TotalCount` still arrive on the same `RoleCapabilityMatrixColumnDto`; only their
  denominator changed (visible rows only), so the existing badge renders a correct fraction rather
  than one that could exceed the row count.

Two things a future FE session *may* want, neither required and neither built:

1. **No "this menu is not in your plan" affordance.** Blocked menus vanish silently — the user sees
   a shorter sidebar with no upsell. That is the intended MVP behaviour (blocking is cosmetic and
   must not read as a security wall), but an upgrade prompt is the obvious commercial follow-up.
2. **A stale tab can post a blocked menu.** If the plan changes while the matrix is open, the save
   silently drops those cells and the refreshed matrix in the response no longer contains the rows.
   The FE re-renders from that response, so it self-heals — but the user gets no explanation for
   rows disappearing mid-edit. A toast keyed off a row-count delta would close that gap.

The ops CRUD screen for `billing.Features` / `billing.FeatureMenuMaps` is **PROMPT-18**, not FE work
created by this prompt.

---

## ⑬ Build log & known issues

*(append one entry per session; keep the last 5, git holds the rest)*

### 2026-08-03 — STEP 1-5 built, not compiled

All five steps implemented. Not built (`dotnet build` is forbidden this session); no migration
authored; no SQL applied. Code is written to compile by inspection — every edited file was read
first and property names verified against the entity or resolver.

**What was built**

- **STEP 1** — `ProvisionTenant.cs`: `ModuleFeatureMap` deleted, replaced by a static
  `AllModuleCodes` array (`CRM, ORGANIZATION, ACCESSCONTROL, GENERAL, SETTING, REPORTAUDIT`) granted
  unconditionally in step 4b. `IEntitlementService` **kept** injected — line ~491 still calls
  `Invalidate(companyId)`, so removing it would break the build. `GetParentChildMenu.cs`:
  `Features.Count > 0` → `Status != SubscriptionStatuses.None`.
- **STEP 2** — `Feature` / `FeatureMenuMap` entities + two `IEntityTypeConfiguration` classes +
  DbSets. DDL written into §⑧.
- **STEP 3** — `IMenuFeatureMap` + `MenuFeatureMapService` (one platform-wide `IMemoryCache` entry,
  60s TTL, generation-counter `Invalidate()` left uncalled for PROMPT-18).
- **STEP 4** — 4 new codes in `FeatureCodes` + `FeatureCodes.All`;
  `sql-scripts-dyanmic/billing-feature-menu-map-seed.sql` (14 features, 23 map rows, 16 plan
  entitlement rows), fully idempotent, **not applied**.
- **STEP 5** — `IPlanMenuFilter` / `PlanMenuFilter`, one implementation, consumed by all five
  handlers. Blocked menus are silently skipped everywhere; existing `RoleCapability` rows on blocked
  menus are never deleted (`ResetRoleCapabilityMatrix` skips them in **both** the soft-delete and
  the clone loop, so an upgrade restores the grants exactly). All four matrix handlers now compute
  `GrantedCount`/`TotalCount` over visible rows only.
- Comment-only edits to `GetMenuAdminTree.cs` and `GetUserRoleModule.cs`.

**Invalidate audit (STEP 3 asked for this) — all three already correct, nothing added**

| Handler | Call | Line |
|---|---|---|
| `SavePlanEntitlements` | `entitlementService.InvalidateAll()` | 121 |
| `AssignSubscription` | `entitlementService.Invalidate(command.CompanyId)` | 222 |
| `ConfirmSubscriptionPayment` | `entitlementService.Invalidate(companyId.Value)` | 283 |

`InvalidateAll()` on the catalogue edit is the right choice — a plan edit changes what *every*
tenant on that plan resolves, and `Invalidate` is per-company.

**Deviations from the prompt's predictions (all deliberate, all follow the "match the neighbouring
convention" rule in §⑩)**

1. **DbSets went to `IBillingDbContext.cs` / `BillingDbContext.cs`**, not
   `IApplicationDbContext.cs` / `ApplicationDbContext.cs` as §⑩ predicted. On disk every billing
   DbSet lives in the billing partial; `ApplicationDbContext` is a partial class and
   `IApplicationDbContext : IBillingDbContext`, so `dbContext.FeatureMenuMaps` resolves unchanged.
2. **`PlanMenuFilter` lives in `Base.Infrastructure/Services/Billing/`**, not next to
   `MenuFeatureMap` in `Base.Application/Interfaces/` as §⑤ worded it. Interfaces
   (`IPlanMenuFilter`, `IMenuFeatureMap`) are in `Base.Application/Interfaces/`, implementations in
   `Base.Infrastructure/Services/Billing/` — mirroring `IEntitlementService`/`EntitlementService`
   exactly. The Application layer cannot hold an implementation that touches `IMemoryCache`.
3. **`Base.Application/Interfaces/MenuFeatureMap.cs` was renamed to `IMenuFeatureMap.cs`** — it now
   holds only the interface.
4. **`PlanMenuFilter` walks ancestors over all active menus**, where the old inline sidebar code
   walked only the current module's menus. A superset, behaviourally identical (a menu's parent is
   always in the same module), and it is what lets the *matrix* handlers — which have no module
   scope — share the one implementation, as invariant 6 requires.
5. **`FeatureCode` is `varchar(64)` per §③, while `PlanEntitlements."FeatureCode"` is
   `varchar(60)`.** Kept the §③ width; the mismatch is recorded in §⑧ and is inert (longest live
   code is 24 chars).

**Known issues / carried forward**

- `MenuFeatureMapService.Invalidate()` is implemented but **never called** — by design, PROMPT-18
  wires it to the ops CRUD screen. Until then a map edit takes up to 60s to surface.
- `RETENTIONDASHBOARD` and `DASHBOARDLAYOUT` exist in `auth.Menus` but §④ names neither. Left
  unmapped, which invariant 1 makes safe (always visible). Flag for PROMPT-18 if they should gate.
- No `RoleModules` re-sync job for tenants provisioned *before* STEP 1 — they still hold the
  entitlement-filtered module snapshot and may be missing `ORGANIZATION`/`REPORTAUDIT`. §⑦
  explicitly excludes building it; existing tenants need a one-off backfill.
- Nothing compiled and nothing applied to a database. Acceptance §⑨ is entirely unrun.
