# P-01 Hand-back — Onboarding provisioning data model

## What I built (schema + entities + EF config + one seed only)

**New `ops` control-plane entities** (`Base.Domain/Models/OpsModels/`):
- `TenantProvisioningRun.cs` — `[Table("TenantProvisioningRuns", Schema = "ops")]`, inherits `Entity`.
- `TenantProvisioningRunStep.cs` — `[Table("TenantProvisioningRunSteps", Schema = "ops")]`, inherits `Entity`.

**EF configs** (`Base.Infrastructure/Data/Configurations/OpsConfigurations/` — new folder, auto-discovered by `ApplyConfigurationsFromAssembly`):
- `TenantProvisioningRunConfiguration.cs` — keys, lengths, jsonb, the one wired FK, parent→Steps cascade, 3 indexes (unique `IdempotencyKey`, `Status`, `CompanyId`).
- `TenantProvisioningRunStepConfiguration.cs` — keys, lengths, `AttemptCount` default 0, unique `(RunId, StepNumber)`.

**Context facet (partial-class pattern, NO new DbContext, NO DI change):**
- `Base.Application/Data/Persistence/IOpsDbContext.cs` — interface exposing the two DbSets + `//IOpsDbContextLines` marker.
- `Base.Infrastructure/Data/Persistence/OpsDbContext.cs` — `public partial class ApplicationDbContext : IOpsDbContext` exposing DbSets via `Set<T>()`.
- Added `IOpsDbContext` to the `IApplicationDbContext` inheritance list.
- Added `global using Base.Domain.Models.OpsModels;` to `Base.Infrastructure/GlobalUsing.cs` so the config classes resolve the entity types (matches how every other module namespace is globally imported).

**`app.Companies` additive columns** (`Company.cs` + `CompanyConfigurations`): `Status varchar(20) NULL`, `IsInternal bool NOT NULL DEFAULT false`, `OnboardedOn timestamptz NULL`, `SourceLeadId int NULL` (no FK).

**Seed:** `sql-scripts-dyanmic/ops-template-company-seed.sql` — idempotent `INSERT … WHERE NOT EXISTS` for the `__TEMPLATE__` shell row.

**Migration spec:** `PSS-2.0-ONBOARDING-P01-MIGRATION-SPEC.md` (for the user to author the migration by hand).

## `Company.Status` default choice
Existing rows → **`ACTIVE`** (they are live tenants). The migration spec includes the
`UPDATE … WHERE "Status" IS NULL` backfill. New provisioning runs write `PROVISIONING` then flip
to `ACTIVE` on success. The column itself stays **nullable** (additive-safe); the value is set by
backfill, not a DB default, so the domain keeps `PROVISIONING|ACTIVE|SUSPENDED|CHURNED` as the
only app-written values.

## jsonb mapping approach
`RequestPayloadJson` is a plain **`string`** property mapped `.HasColumnType("jsonb").IsRequired()`
— the codebase's text-as-jsonb convention (handlers serialize/deserialize). **Not** `JsonDocument`.

## Things I verified in the codebase that differed from / weren't in the brief
1. **Target framework is `net10.0`**, not `.NET 8` as the prompt header states. No action — the
   partial-class/config pattern is identical; flagging the discrepancy only.
2. **Global usings live in per-project `GlobalUsing.cs` files** (not `GlobalUsings.cs`, not
   `Directory.Build.props`). Config classes carry no `using` statements and rely entirely on
   `Base.Infrastructure/GlobalUsing.cs` — hence the one-line addition there.
3. **`Country` is `com."Countries"`** (not `app`), PK `CountryId`. The seed resolves `CountryId`
   via `SELECT MIN("CountryId") FROM com."Countries"` so the required FK is valid on any env.
4. **`Company` non-null columns** the seed must supply: `CompanyCode`, `CompanyName`,
   `CompanyHeader`, `CompanyFooter`, `Address`, `CountryId`, `IsInternal` (the C# `string = default!`
   props map NOT NULL by convention even where the config omits `.IsRequired()`).
5. **Tenant query-filter auto-application:** `ApplicationDbContext.ApplyTenantFilters` attaches a
   tenant filter to any entity with a `CompanyId` property (excludes `Company` itself).
   `TenantProvisioningRun` has a nullable `CompanyId`, so it will receive that filter. Harmless for
   a control-plane table read by SuperAdmin (CurrentTenantId = null ⇒ unfiltered); noted so the
   P-03 command author knows to run these queries in a SuperAdmin/ops context.

## Note for P-03 (not built here — flagged for the command author)
The step table (`TenantProvisioningRunSteps`) currently tracks **execution/progress metadata
only**: `Status`, `AttemptCount`, `StartedOn`/`CompletedOn`, and `ErrorMessage` (the only
free-form field). The **business payload** lives once on the run (`RequestPayloadJson`); steps do
not carry per-step *result* data (e.g. "CREATE_COMPANY → CompanyId 42", "CREATE_ADMIN → UserId 7").
If P-03 needs to persist per-step outputs for resume/audit (rather than re-deriving them), consider
adding a nullable `ResultJson jsonb` column to `TenantProvisioningRunSteps` in that prompt's
migration. Out of scope for P-01; noted so it's a deliberate P-03 decision, not an oversight.

## Constraints honored
- No `dotnet ef migrations add/update/remove`; no hand-authored migration or snapshot file.
- No SQL executed against any DB (seed written only).
- All keys `int` identity (`UseIdentityAlwaysColumn().ValueGeneratedOnAdd()`); no `Guid`.
- No new `DbContext` subclass, no DI/service-registration change, no manual `ApplyConfiguration`.
- Additive only — no tenant/business code modified.
