# Custom fields — per-tenant name uniqueness and a tenant-scoped definition count

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`. State the migration; the user creates it.
- Do NOT execute SQL against any database. Idempotent scripts, handed off.
- `PSS_2.0_Backend` / `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server.
- Enterprise-level app. No shortcuts. Backend enforcement, never frontend-only.

**Collision warning — read first.** A separate session is actively building
`import_custom_fields_prompt.md` and owns everything under `Base.Infrastructure/Services/Import/**`
(notably `ImportCustomFieldResolver.cs`), `Base.Application/Schemas/ImportSchemas/**`, the import SQL
functions, and `ImportGridDefinition`. **Do not edit those.** You will need to *read*
`ImportCustomFieldResolver.cs` — its tenancy predicate is the reference implementation for § C — but do
not change it. If you believe it needs a change, stop and report it.

---

## The decision that drives this task

The user has decided:

> **System fields keep a single global name. Custom fields are unique per company.**

`Field.IsSystem` is the discriminator and `Field.CompanyId` is the scope. Both already exist on the
entity — this task does not add them.

Today `CreateCustomFieldValidator` enforces `FieldName` uniqueness **globally across `sett."Fields"`**
(`CreateCustomField.cs:26`, `ValidateUniqueWhenCreate(x => x.field.FieldName, _dbContext.Fields, c =>
c.FieldName)`), with no `IsSystem` and no `CompanyId` predicate. So tenant A creating "Region" blocks
tenant B from ever creating one. That is the bug.

---

## A. Establish the facts before you write anything

Three things must be verified in the code, not assumed. Report each with the file and line you read it
from.

1. **`Field.CompanyId` is auto-stamped, not handler-set.** `CreateCustomFieldHandler` never assigns it;
   `TenantSaveChangesInterceptor` stamps `CompanyId` on new entities from `GetEffectiveCompanyId()` ??
   `GetCurrentTenantId()`. Read that interceptor and confirm the exact precedence, and confirm `Field`
   is not on any exclusion list it maintains.

2. **What happens when neither is available.** The interceptor leaves `CompanyId` null for a SuperAdmin
   with no `EffectiveCompanyId`. A null-`CompanyId` custom field is treated by
   `ImportCustomFieldResolver` and `CustomFieldRegistry.GetFilterableKeysAsync` as **a platform-wide
   declaration every tenant inherits**. Confirm that reading. This is the single most important fact in
   the task: it means a custom field created from a SuperAdmin context silently becomes visible to
   every tenant. State whether that is reachable through the current `CreateCustomField` authorization
   path, and if it is, say what you did about it (see § D).

3. **There are no EF global query filters.** Zero `HasQueryFilter` calls exist in the solution. Verify
   this yourself with PowerShell `Select-String` across both nested repos and show the command — Grep
   has silently missed nested-repo files in this codebase before. Everything below depends on it.

## B. Fix the uniqueness rule

Replace the global `FieldName` uniqueness check with the decided rule:

- `IsSystem = true` → `FieldName` unique **globally**. A tenant must not be able to create a custom
  field whose name collides with a system field, because the two share `FieldKey`/`FieldCode` space and
  a collision would make the custom field indistinguishable from a platform one downstream.
- `IsSystem = false` → `FieldName` unique **per `CompanyId`**.

Requirements:

- **Enforce in both places.** The validator gives the user a clean message; a **unique index** in the
  database is what actually guarantees it under concurrency. A validator-only check loses to two
  simultaneous requests. State the index and let the user create the migration.
- The index must handle `NULL` `CompanyId` correctly. In PostgreSQL a plain unique index treats NULLs
  as distinct, so `(CompanyId, FieldName)` would enforce nothing at all for platform-scoped rows. Decide
  and justify: `NULLS NOT DISTINCT` (PG15+ — confirm the server version before relying on it), a
  `COALESCE(CompanyId, 0)` expression index, or two partial indexes split on `IsSystem`. Say which and
  why, and state the PostgreSQL version requirement of your choice.
- Compare case-insensitively if the existing check is case-insensitive, and match how `FieldName` is
  stored — it carries `[CaseFormat("title")]`, so it is normalised to title case on save. Read what
  that attribute actually does before deciding whether a case-insensitive index is needed or redundant.
- `FieldCode` and `FieldKey` are derived from `FieldName` (`CreateCustomField.cs:125-140`). If two
  tenants may now both hold "Region", they both derive `FieldCode = 'REGION'` and `FieldKey = 'region'`.
  **State explicitly whether anything in the codebase assumes `FieldCode` or `FieldKey` is globally
  unique** — grep for lookups by those columns that do not also filter by company or grid. If any
  exists, that is a defect this change would expose; report it and fix it if it is small, or report it
  precisely if it is not.

**Pre-existing duplicates.** Deliver an idempotent audit query under `sql-scripts-dyanmic/` listing any
existing rows that would violate the new index, grouped so the user can see which are system-vs-system,
custom-vs-custom within a company, and custom-vs-system. The index cannot be created while duplicates
exist, so this must be run first. Do **not** write a script that renames or deletes anything — report
the rows and let the user decide.

## C. Fix the definition count — it is currently global

`CreateCustomFieldHandler` counts:

```csharp
var existingCustomFields = await dbContext.Fields
    .CountAsync(f => f.FieldSource == "Custom" && f.IsDeleted == false, cancellationToken);
```

with the comment *"The count is not filtered by CompanyId here: dbContext already applies the tenant
query filter"*. **That premise is false — there is no query filter (§ A.3).** So the count is global
across all tenants: one tenant's definitions consume everyone else's ceiling, and the ceiling gets
tighter for every tenant as the platform grows.

Scope it to the tenant. Match the tenancy predicate `ImportCustomFieldResolver` uses — read it and
follow it rather than inventing a second one, so the ceiling and the import plan agree about who owns
a field. Note that a null-`CompanyId` field is inherited by every tenant, so decide and justify whether
it counts against the tenant's ceiling.

Then **correct the comment**. The surrounding block is otherwise good reasoning and should be kept —
the explanation of why the per-entity cap belongs in `AddCustomFieldGridSchema` rather than here is
correct and worth preserving. Only the tenancy claim is wrong. Do not delete the block wholesale.

While you are there, confirm the per-entity ceiling in `AddCustomFieldGridSchema` is itself
tenant-scoped, on the same reasoning. If it is not, fix it and report it.

## D. The SuperAdmin null-CompanyId path

If § A.2 shows a custom field can be created with a null `CompanyId` through the normal command path,
that is a cross-tenant leak, not a theoretical one — the field appears in every tenant's import
template, filterable-key set and form schema.

Decide and argue one of:

- **Reject.** `CreateCustomFieldHandler` requires a resolvable tenant and throws a clear error
  otherwise. Platform-wide fields, if they are ever wanted, get a separate deliberate path.
- **Allow, but explicitly.** A platform-wide field must be an intentional flag on the request, never
  the accidental result of a missing tenant context.

Reject is almost certainly right — a leak that happens by *omission* is the worst shape. Argue whichever
you choose. Do not leave the current behaviour, where the outcome depends on whether a context happened
to be present.

## E. Frontend

Minimal. If the uniqueness error message is surfaced to the user, it must now say the name is already in
use **in this organisation** rather than implying a global namespace. Find where that message renders
and update it. No other frontend change.

---

## Explicitly out of scope

- Anything under `Base.Infrastructure/Services/Import/**` or the import SQL functions — different
  session, see the collision warning.
- The `CustomFieldIndexPlanner` DDL-emission gap — separate task.
- Any change to `CustomFieldPolicy` / `ICustomFieldPolicy` / `CustomFieldPolicyOptions` /
  `CustomFieldMeterCodes` / `MeterCodes`.
- Introducing EF global query filters. The absence of them is a codebase-wide architectural fact and
  adding one here would change behaviour far beyond custom fields. Report if you think it should exist;
  do not add it.

## Output

Stage everything (`git add` in each affected repo). Report:

1. The three § A facts, each with the file and line you verified it from, and the `Select-String`
   command you ran for A.3.
2. The uniqueness rule as implemented, in both the validator and the index.
3. The NULL-handling approach for the unique index, why, and its PostgreSQL version requirement.
4. Whether anything assumes `FieldCode` / `FieldKey` is globally unique, and what you did.
5. The exact migration the user must create — index name, columns, expression, partial predicate,
   nullability — and the audit script filename that must run before it.
6. The tenant-scoping predicate you applied to the definition count, and whether null-`CompanyId`
   fields count against a tenant's ceiling, with reasoning.
7. Whether `AddCustomFieldGridSchema`'s per-entity ceiling was already tenant-scoped.
8. Your decision on the SuperAdmin null-`CompanyId` path and the argument for it.
9. Confirmation you edited nothing the import session owns.
10. Anything you could not complete and why.
