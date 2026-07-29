# PSS 2.0 — P-05f / T-B11 — Provisioning: per-tenant Role unique indexes + resume-safe validator

**Type:** Critical fix to P-03/P-04 (tenant provisioning engine + its validator). **Not** a new screen.
**Schema change:** YES — re-scope 3 unique indexes on `auth.Roles` (index-only, no columns, no data).
**Migration:** YES — **user-owned** (dev session edits config + proves compile; the USER runs `migrations add` + `database update`).
**New capability / mutation / query / seed:** NONE.
**Backend area:** `Base.Infrastructure/.../AuthConfigurations/RoleConfiguration.cs` (1 file, 3 index edits) +
`Base.Application/.../TenantProvisioning/Commands/ProvisionTenant.cs` (validator + a tiny shared key helper).
**Frontend area:** none.

---

## ① The bug (two stacked defects — root causes verified in source)

A real provisioning run (leadId = 2) **failed in Step 3 `SEED_ROLES`** with a `roles_isactive`
unique-index violation, and a retry then failed validation with *"This subdomain is already taken.,
A company with this code already exists."* The engine is **already designed to be idempotent &
resumable** (`Step1_CreateCompanyAsync` reuses an existing company by code; every step has an
existence guard; a `PAUSED_ON_ERROR` run re-runs from the first non-SUCCEEDED step). Two defects
defeat that:

### Defect A — Role unique indexes are GLOBAL, not per-tenant (root cause of the Step 3 crash)

`RoleConfiguration.cs` currently declares:

```csharp
builder.HasIndex(o => new { o.RoleName, o.IsActive }).IsUnique();   // line 17
builder.HasIndex(o => new { o.RoleCode, o.IsActive }).IsUnique();   // line 23
builder.HasIndex(o => new { o.OrderBy,  o.IsActive }).IsUnique();   // line 42
```

None include `CompanyId`. Step 3 (`Step3_SeedRolesAsync`) inserts, for the new tenant, a role with
`RoleCode = "BUSINESSADMIN"`, `OrderBy = 1`, `IsActive = true`. The **template** company (and any
already-provisioned tenant) already owns a role with those exact values, so the insert violates
`IX_Roles_RoleCode_IsActive` (and `IX_Roles_OrderBy_IsActive`). **Result: no second tenant can ever
be provisioned** — a fundamental multi-tenant schema defect, independent of the wizard input.

**Fix:** prepend `CompanyId` to each of the three unique indexes so uniqueness is scoped *per tenant*
(exactly the platform convention already used by the sibling configs — `RoleModuleConfiguration`
uses `(RoleId, ModuleId, IsActive)`, `UserRoleConfiguration` uses `(UserId, RoleId, CompanyId,
IsActive)`). Within a company the constraint is unchanged; across companies it no longer collides.

### Defect B — the validator blocks the resumable retry (root cause of the retry failure)

`ProvisionTenantCommandValidator` runs **before** the handler and hard-rejects when the subdomain /
company-code already exist (lines 96-106). But after Defect A crashed Step 3, Step 1's company row is
(correctly) still there for the resume — so the validator now rejects the very retry the engine is
built to accept. The pre-check must **exclude the company (or subdomain) that belongs to THIS same
provisioning run** (same idempotency key, any non-`ABANDONED` status) — that is a resume, not a
conflict. A genuinely different tenant on the same subdomain still fails, as it should.

> **Why fix-forward, not "add rollback":** the engine is deliberately resume-based — Step 9 sends a
> live email and stamps the lead; those cannot be transactionally rolled back. The right behaviour is
> the one already designed: a failed step pauses the run, the operator fixes the cause, and the run
> **resumes** reusing the half-built rows. Do **not** add a "delete the company on failure" path.

---

## ② Scope — do exactly this, nothing more

**In scope:**
1. `RoleConfiguration.cs` — re-scope the 3 unique indexes to include `CompanyId` (index-only change).
2. `ProvisionTenant.cs` — make the validator's subdomain + company-code uniqueness pre-checks
   resume-aware (exclude companies owned by this run's own idempotency key); extract the idempotency
   key formula into one shared helper so validator and handler cannot drift.
3. Prove the BE compiles. Then the **USER** authors + runs the migration (see §⑤).

**Out of scope (do NOT touch):**
- The `Role` entity, the `IsActive` semantics, or any other config/index.
- Any provisioning step body (Steps 1–9), the step runner, the run/step state machine, the DTO,
  the GraphQL mutation/input, or the FE wizard.
- Any new column, capability, mutation, query, seed, or FE change.
- Adding a rollback / compensating-delete path (the engine is resume-based by design).

---

## ③ Backend change 1 — `RoleConfiguration.cs` (re-scope 3 unique indexes)

Replace the three global unique indexes with per-company ones. **Prepend `CompanyId`; keep
`IsActive` last** (preserves the existing soft-delete-aware uniqueness intent, matches sibling
configs). Nothing else in the file changes.

```csharp
// Unique per COMPANY (multi-tenant): a role name/code/order is unique within a tenant, not globally.
builder.HasIndex(o => new { o.CompanyId, o.RoleName, o.IsActive }).IsUnique();
// ...
builder.HasIndex(o => new { o.CompanyId, o.RoleCode, o.IsActive }).IsUnique();
// ...
builder.HasIndex(o => new { o.CompanyId, o.OrderBy, o.IsActive }).IsUnique();
```

Notes for the dev session:
- `CompanyId` is `int?` (nullable). Postgres treats NULLs as distinct in a unique index, so
  platform-global roles (`CompanyId IS NULL`, if any exist) are unaffected; every provisioned tenant
  role carries a real `CompanyId`, so this is exactly the scoping we want.
- This change is strictly *more permissive across companies* and *identical within a company*, so no
  existing single-tenant behaviour breaks.
- **Verify-before-assume:** confirm no code relies on RoleCode being globally unique across tenants
  (a bare `Roles.FirstOrDefault(r => r.RoleCode == "…")` with no `CompanyId`/tenant-filter). The
  tenant query filter normally scopes this already; flag anything that doesn't in the hand-back.

---

## ④ Backend change 2 — `ProvisionTenant.cs` (resume-safe validator + shared key helper)

### ④.1 Extract the idempotency-key formula into one place

The handler currently inlines the key (lines 189-191). Add a tiny internal helper next to the DTO so
the validator uses the **same** formula:

```csharp
/// <summary>Single source of truth for a run's idempotency key so the validator's resume check and
/// the handler's run lookup can never drift.</summary>
internal static class ProvisionIdempotency
{
    public static string KeyFor(ProvisionTenantRequestDto req) =>
        req.LeadId is int leadId ? $"LEAD:{leadId}|CODE:{req.CompanyCode}" : $"CODE:{req.CompanyCode}";
}
```

Then in `Handle`, replace the inline computation with:

```csharp
var idempotencyKey = ProvisionIdempotency.KeyFor(req);
```

(Do not change the key's shape — it must stay byte-identical to today so existing PAUSED runs keep
their key.)

### ④.2 Make the two uniqueness pre-checks resume-aware

The validator has `IApplicationDbContext dbContext`. Use FluentValidation's root-object `MustAsync`
overload (`(command, value, ctx, ct) => …`) so the request's idempotency key is available. A company
is only a **conflict** if it is NOT owned by a non-abandoned run for this same request.

Replace the **Subdomain** uniqueness rule (currently lines 96-99) with:

```csharp
.MustAsync(async (command, sub, ctx, ct) =>
{
    if (string.IsNullOrEmpty(sub)) return true;
    var key = ProvisionIdempotency.KeyFor(command.Request);
    // Company ids already owned by THIS run (resume / idempotent re-submit) — never a conflict.
    var ownCompanyIds = await dbContext.TenantProvisioningRuns
        .IgnoreQueryFilters()
        .Where(r => r.IdempotencyKey == key && r.IsDeleted != true
                    && r.Status != "ABANDONED" && r.CompanyId != null)
        .Select(r => r.CompanyId!.Value)
        .ToListAsync(ct);
    return !await dbContext.Companies
        .IgnoreQueryFilters()
        .AnyAsync(c => c.Subdomain == sub && c.IsDeleted != true
                       && !ownCompanyIds.Contains(c.CompanyId), ct);
})
.WithMessage("This subdomain is already taken.");
```

Replace the **CompanyCode** uniqueness rule (currently lines 103-106) with the same shape:

```csharp
.MustAsync(async (command, code, ctx, ct) =>
{
    if (string.IsNullOrEmpty(code)) return true;
    var key = ProvisionIdempotency.KeyFor(command.Request);
    var ownCompanyIds = await dbContext.TenantProvisioningRuns
        .IgnoreQueryFilters()
        .Where(r => r.IdempotencyKey == key && r.IsDeleted != true
                    && r.Status != "ABANDONED" && r.CompanyId != null)
        .Select(r => r.CompanyId!.Value)
        .ToListAsync(ct);
    return !await dbContext.Companies
        .IgnoreQueryFilters()
        .AnyAsync(c => c.CompanyCode == code && c.IsDeleted != true
                       && !ownCompanyIds.Contains(c.CompanyId), ct);
})
.WithMessage("A company with this code already exists.");
```

Keep the DNS-label / reserved-word / length rules on Subdomain and the `NotEmpty` on CompanyCode
exactly as they are — only the `MustAsync` uniqueness clauses change. All other rules in the
validator (CompanyName, Address, CountryId, PlanCode, CurrencyId, BillingCycle, AdminName,
AdminEmail, Mode) stay untouched.

> Two tiny `ToListAsync` reads inside a validator are acceptable here (provisioning is a rare,
> operator-driven action). Do **not** try to nest one DbSet `.Any()` inside another DbSet's EF
> predicate — the two-step form above is deliberately kept translatable.

---

## ⑤ Migration — USER-OWNED (do NOT run it in the dev session)

The dev session makes the config edit and **proves the solution compiles only** — it must NOT run
`dotnet ef migrations add`, `database update`, or `migrations remove`, and must NOT hand-author a
migration or snapshot. Hand the user this spec:

- **Name:** `Rescope_Role_Unique_Indexes_Per_Company`
- **Effect:** EF auto-generates `DropIndex` × 3 (the old global `IX_Roles_RoleName_IsActive`,
  `IX_Roles_RoleCode_IsActive`, `IX_Roles_OrderBy_IsActive`) + `CreateIndex` × 3 (the new
  `IX_Roles_CompanyId_RoleName_IsActive`, `IX_Roles_CompanyId_RoleCode_IsActive`,
  `IX_Roles_CompanyId_OrderBy_IsActive`, all `unique`). **Index-only — no column, no data change.**
- **Safety:** existing rows cannot violate the stricter-per-company indexes (the old global indexes
  already forbade even cross-company duplicates, so no intra-company duplicates exist). The failed
  leadId = 2 tenant has **zero** roles (Step 3 rolled back its own transaction on failure), so nothing
  to reconcile.
- **User runs:** `dotnet ef migrations add Rescope_Role_Unique_Indexes_Per_Company …` then
  `dotnet ef database update …`, then commits.

---

## ⑥ After the fix — how the stuck leadId = 2 run recovers (NO manual SQL needed)

Once §③ + §④ are built and the migration is applied, simply **re-submit the provisioning wizard for
leadId = 2** (same code/subdomain):

1. The validator computes key `LEAD:2|CODE:<code>`, finds the PAUSED run owns that company → **allows**.
2. `Handle` loads the existing `PAUSED_ON_ERROR` run, sets it `RUNNING`, **skips** Steps 1 & 2
   (already `SUCCEEDED`), and re-runs Step 3 — which now inserts the tenant's roles cleanly under the
   per-company index — then Steps 4–9 → `SUCCEEDED`. The welcome/activation email fires at Step 9.

The half-built company + subscription are **reused, not duplicated**. No cleanup required.

*(Optional — only if the operator wants to abandon leadId = 2 and start that tenant completely fresh
with a different code/subdomain: soft-delete the orphan run + company + subscription by hand in the
DB. This is a one-off operator action, not part of this prompt, and is unnecessary for the recover-
by-resume path above.)*

---

## ⑦ Hard constraints

1. **Index-only schema change** — prepend `CompanyId` to 3 Role unique indexes; touch no columns/data.
2. **Migration is user-owned** — dev session proves compile only; never run EF migration commands or
   author a migration/snapshot by hand.
3. **Resume, not rollback** — do not add any compensating-delete/rollback path; the engine is
   idempotent-resumable by design.
4. **Key formula stays byte-identical** — the shared helper must produce the exact same string as the
   current inline code so existing PAUSED runs keep their idempotency key.
5. **Validator: only the two `MustAsync` uniqueness clauses change** — every other rule is untouched.
6. **UTC only** if any timestamp is touched (none new here).

---

## ⑧ Build evidence to return in the hand-back

- **BE:** `dotnet build …/Base.API/Base.API.csproj -c Debug` → **0 CS errors** (stop any running
  `Base.API` first to avoid the DLL copy lock; say if you used a redirected-output build). Do **not**
  run the migration — report it as "spec handed to user, migration NOT run."
- Confirm the three new index definitions read `{ o.CompanyId, o.RoleName, o.IsActive }` /
  `{ o.CompanyId, o.RoleCode, o.IsActive }` / `{ o.CompanyId, o.OrderBy, o.IsActive }`.
- Confirm the shared `ProvisionIdempotency.KeyFor` is used in **both** the handler and both validator
  clauses, and that the key string is unchanged from the previous inline formula.
- Flag any code found relying on global (cross-tenant) Role code/name uniqueness (§③ verify note).
