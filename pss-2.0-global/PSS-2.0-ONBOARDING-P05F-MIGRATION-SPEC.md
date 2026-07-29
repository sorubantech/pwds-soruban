# PSS 2.0 — P-05f migration spec (USER-OWNED — not run by the dev session)

**Name:** `Rescope_Role_Unique_Indexes_Per_Company`
**Source of the diff:** `Base.Infrastructure/Data/Configurations/AuthConfigurations/RoleConfiguration.cs` — 3 unique indexes now lead with `CompanyId`.

## Commands you run

```
dotnet ef migrations add Rescope_Role_Unique_Indexes_Per_Company \
  --project  PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure \
  --startup-project PSS_2.0_Backend/PeopleServe/Services/Base/Base.API \
  --context ApplicationDbContext

dotnet ef database update \
  --project  PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure \
  --startup-project PSS_2.0_Backend/PeopleServe/Services/Base/Base.API \
  --context ApplicationDbContext
```

## Expected diff — `DropIndex` × 3 + `CreateIndex` × 3, nothing else

| Dropped (old, global) | Created (new, per-company, `unique`) |
|---|---|
| `IX_Roles_RoleName_IsActive` | `IX_Roles_CompanyId_RoleName_IsActive` |
| `IX_Roles_RoleCode_IsActive` | `IX_Roles_CompanyId_RoleCode_IsActive` |
| `IX_Roles_OrderBy_IsActive`  | `IX_Roles_CompanyId_OrderBy_IsActive` |

All on `auth.Roles`. **No column added/dropped/altered, no data movement, no other table.**
If `migrations add` generates anything beyond these six operations, stop and report it — that means
an unrelated model drift is riding along and should be separated out.

## Safety

- Existing rows cannot violate the new indexes: the old **global** indexes already forbade even
  cross-company duplicates, so no intra-company duplicate can exist today. The new indexes are
  strictly *more permissive across companies* and *identical within a company*.
- `Role.CompanyId` is `int?`. Postgres treats NULLs as distinct in a unique index, so any
  platform-global role (`CompanyId IS NULL`) is unaffected.
- The failed `leadId = 2` tenant has **zero** roles (Step 3 rolled its own transaction back), so
  there is nothing to reconcile before applying.

## After applying

Re-submit the provisioning wizard for `leadId = 2` — no manual SQL. See §⑥ of
`PSS-2.0-ONBOARDING-PROMPT-05-FOLLOWUP-COMBINED-RUN.md`.
