# DEV PROMPT P-01 — Onboarding provisioning data model

> Paste everything below the line into a **fresh development session**. It is self-contained.
> When done, report back the outcome to the PM session; do **not** proceed to P-02.

---

## Role & mission

You are a Senior Backend Developer on the PSS 2.0 multi-tenant .NET 8 platform. Your task is **P-01: stand up the data model for the tenant-provisioning engine.** This is the foundation the `ProvisionTenantCommand` (a later prompt) will run on. You are building **schema + entities + EF configuration + one seed script only** — no command logic, no API, no UI in this prompt.

## Read first (grounding — do not skip)

1. `PSS-2.0-ONBOARDING-TASK-LIST.md` — tasks **T-A1, T-A2, T-A3** are your scope.
2. `PSS-2.0-GTM-LEAD-ONBOARDING-AND-PRODUCT-ADMIN-APPROACH.md` §7.1 (exact `ops.TenantProvisioningRun` / `…RunStep` columns), §7.3 (the `app.Companies` additions), §9.2 (why a **template company** is the clone source).

## Hard constraints (violating any of these fails the task)

- 🔒 **Migrations are strictly user-owned.** Do **NOT** run `dotnet ef migrations add`, `database update`, or `remove`, and do **NOT** hand-author a migration or model-snapshot file. Build the solution to prove your entities compile and map, then produce a **migration spec** (a markdown description of the tables/columns/indexes/FKs) for the user to author, run, and commit.
- 🌱 **Seed files:** you write them (idempotent `INSERT … WHERE NOT EXISTS`, matching the existing style under `sql-scripts-dyanmic/`); the **user applies** them. Do not execute SQL against any database.
- **All PKs/FKs are `int` identity.** `Company.CompanyId` is `int`. Do not introduce any `Guid` keys.
- **UTC only.** Every date column is `timestamp with time zone`. The `Entity` base class (`Base.Domain/Abstractions/Entity.cs`) defaults `CreatedDate = DateTime.Now` — that default is wrong for our DB; any code path that writes a date must set `DateTime.UtcNow` explicitly and build boundaries with `DateTimeKind.Utc`. Npgsql throws on `Kind=Unspecified`.
- **Audit fields** come from the `Entity` base (`CreatedDate`/`ModifiedDate` etc.) — do not re-declare them.
- Do not modify any tenant/business code. Only additive changes.

## Codebase anchors (study these patterns, then follow them)

There is **ONE real EF context: `ApplicationDbContext`** (`Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs`). Each module is *not* a standalone context — it is a **partial class of `ApplicationDbContext`** plus a per-module interface. Follow this exactly; do **not** create a separate `OpsDbContext : DbContext` or register a new context in DI. Mapping responsibilities are **split** between a data annotation (table + schema) and a config class (everything else).

- **Entity base:** `Base.Domain/Abstractions/Entity.cs` — inherit `Entity`.
- **Table + schema = data annotation only.** e.g. `Company.cs` → `[Table("Companies", Schema = "app")]`. Your new entities get `[Table("TenantProvisioningRuns", Schema = "ops")]` etc. That annotation is the *only* thing that sets table/schema — keys, columns, FKs, indexes are **not** done here.
- **Everything else = an `IEntityTypeConfiguration<T>` class.** Study `Base.Infrastructure/Data/Configurations/GrantConfigurations/GrantFundReceiptConfiguration.cs` — it shows the exact idiom: `builder.HasKey(...)`, `builder.Property(x).UseIdentityAlwaysColumn().ValueGeneratedOnAdd()`, `.HasMaxLength(...)`, `builder.HasOne(...).WithMany(...).HasForeignKey(...).OnDelete(...)`, `builder.HasIndex(...)`. Put your two config classes in a **new `Configurations/OpsConfigurations/` folder** (mirror `GrantConfigurations/`).
  - These configs are **auto-discovered** — `ApplicationDbContext.OnModelCreating` calls `builder.ApplyConfigurationsFromAssembly(Assembly.GetExecutingAssembly())` (line ~45). So **no manual `ApplyConfiguration` call and no DI change is needed** for the configs; just drop the classes in the assembly.
  - **jsonb:** map a **`string`** property with `.HasColumnType("jsonb").IsRequired()` — see `ReportConfigurations/CustomReportConfiguration.cs` (`DefinitionJson`) and `ImportConfigurations/ImportExecutionResultConfiguration.cs`. The codebase stores jsonb as a serialized string (handlers serialize/deserialize), **not** `JsonDocument`. Name the property `RequestPayloadJson`.
- **The module context facet (partial class).** Study the pair:
  - `Base.Application/Data/Persistence/IGrantDbContext.cs` — the interface, one `DbSet<T>` per entity, ending with a `//IGrantDbContextLines` marker.
  - `Base.Infrastructure/Data/Persistence/GrantDbContext.cs` — note it is literally `public partial class ApplicationDbContext : IGrantDbContext` exposing `public DbSet<Grant> Grants => Set<Grant>();`. It is a **partial-class facet of `ApplicationDbContext`**, has **no** `OnModelCreating` and **no** DI registration of its own.
  - `Base.Application/Data/Persistence/IApplicationDbContext.cs` — the aggregate interface that inherits every module interface (`… , IGrantDbContext`). You must **add `IOpsDbContext` to that inheritance list** so the ops DbSets are visible on the shared context abstraction.
- **Entity models** live under `Base.Domain/Models/…`. Place the new `ops` models in a parallel `Base.Domain/Models/OpsModels/` folder (match how `GrantModels`/`ApplicationModels` are organised).
- **Seed scripts** to match in style: `sql-scripts-dyanmic/*.sql`.

## Scope — build exactly this

### 1. `ops` context surface (new — partial-class facet, NOT a standalone context)
Follow the Grant-module pattern exactly (see Codebase anchors):
1. **`IOpsDbContext`** interface in `Base.Application/Data/Persistence/` — exposes the two DbSets below.
2. **`public partial class ApplicationDbContext : IOpsDbContext`** in `Base.Infrastructure/Data/Persistence/OpsDbContext.cs` — implements the DbSets via `Set<T>()` (e.g. `public DbSet<TenantProvisioningRun> TenantProvisioningRuns => Set<TenantProvisioningRun>();`). No `OnModelCreating`, no DI registration here.
3. **Add `IOpsDbContext`** to the inheritance list of `IApplicationDbContext`.
Do **not** create a separate `DbContext` subclass, do **not** touch DI/service registration for the context, and do **not** add an `ApplyConfiguration` call — mapping comes from the `OpsConfigurations/` classes (§2–§3), auto-discovered by the existing `ApplyConfigurationsFromAssembly`.

### 2. `ops.TenantProvisioningRun` entity (T-A1)
Columns exactly per §7.1:
- `RunId` int PK identity
- `IdempotencyKey` varchar(100) **UNIQUE NOT NULL** (derived later from LeadId+CompanyCode; just the column + unique index here)
- `LeadId` int **NULL** — *plain nullable int, NO DB FK yet* (the `ops.Lead` table is a later prompt; add the FK constraint in that later migration). Do not add a navigation property that forces the relationship.
- `CommercialTermId` int **NULL** — same treatment (no FK yet; `ops.CommercialTerm` is a later prompt).
- `CompanyId` int **NULL** — **this FK DOES exist now** → `app.Companies`. Wire it (populated by step 1 at runtime).
- `Mode` varchar(20) — `SELF_SERVICE|ASSISTED`
- `Status` varchar(20) — `PENDING|RUNNING|PAUSED_ON_ERROR|SUCCEEDED|ABANDONED`
- `RequestPayloadJson` jsonb NOT NULL — the wizard answer set. Declare the property as **`string`** and map it `.HasColumnType("jsonb").IsRequired()` in the config class (matches the codebase's text-as-jsonb convention; handlers serialize/deserialize). Do **not** use `JsonDocument`.
- `StartedOn`, `CompletedOn` timestamptz NULL
- `InitiatedByUserId` int NULL
- Indexes: `(Status)`, `(CompanyId)`
- Nav: `ICollection<TenantProvisioningRunStep> Steps`

### 3. `ops.TenantProvisioningRunStep` entity (T-A1)
- `RunStepId` int PK identity
- `RunId` int FK → `ops.TenantProvisioningRun` (NOT NULL)
- `StepNumber` int (1..9)
- `StepCode` varchar(50) — `CREATE_COMPANY|CREATE_SUBSCRIPTION|SEED_ROLES|SEED_CAPABILITIES|SEED_MASTERDATA|SEED_SETTINGS|SEED_FIELDS|CREATE_ADMIN|SEND_WELCOME`
- `Status` varchar(20) — `PENDING|RUNNING|SUCCEEDED|FAILED|SKIPPED`
- `AttemptCount` int NOT NULL DEFAULT 0
- `ErrorMessage` varchar(4000) NULL
- `StartedOn`, `CompletedOn` timestamptz NULL
- **UNIQUE (RunId, StepNumber)**

### 4. `app.Companies` additive columns (T-A2 / §7.3)
Add to the existing `Company` entity + its mapping (additive, nullable/defaulted so existing rows are valid):
- `Status` varchar(20) NULL — values `PROVISIONING|ACTIVE|SUSPENDED|CHURNED` (leave existing rows NULL or default to `ACTIVE` — state this choice in your hand-back)
- `IsInternal` bool NOT NULL **DEFAULT false**
- `OnboardedOn` timestamptz NULL
- `SourceLeadId` int NULL — plain nullable int, **no FK yet** (points at `ops.Lead`, a later prompt)

### 5. Template-company seed shell (T-A3) 🌱
Write **one** idempotent seed script under `sql-scripts-dyanmic/` that inserts a single `app.Companies` row acting as the provisioning **clone source**: `CompanyCode='__TEMPLATE__'`, `IsInternal=true`, `Status='PROVISIONING'` (or a clearly non-ACTIVE marker), a recognisable `CompanyName` (e.g. `"[TEMPLATE] Do Not Delete"`), and whatever NOT-NULL columns `app.Companies` requires (inspect the table). Guard it with `WHERE NOT EXISTS (… CompanyCode='__TEMPLATE__')` so re-running is a no-op.
> **Note in your hand-back:** this seed creates only the *shell*. The template's roles / master data / settings / fields get populated later by configuring this company through the normal app UI (per design §9.2 option A) — that population is an operational step, not part of this prompt.

## Out of scope for P-01 (do NOT build)
- `ProvisionTenantCommand` and any step logic (P-03).
- `ops.OnboardingInvite`, `ops.PlatformAuditEvent`, `ops.Lead`, `ops.CommercialTerm` (later prompts).
- `billing` schema / plans (P-02).
- Any GraphQL, API, or UI.

## Definition of done
1. Solution **builds clean** (`dotnet build`) with the new entities, `ops` context facet, config classes, and `Company` additions — real exit 0, not "only a pre-existing error remained".
2. The `ops` surface follows the partial-class pattern: `IOpsDbContext` interface exists, `public partial class ApplicationDbContext : IOpsDbContext` exposes the DbSets via `Set<T>()`, `IOpsDbContext` is added to `IApplicationDbContext`, and the two `IEntityTypeConfiguration<T>` classes live in `Configurations/OpsConfigurations/`. **No new `DbContext` subclass and no DI/service-registration change** were introduced.
3. A **migration spec** exists (markdown): every new table, column, type, nullability, default, index, and the single `CompanyId → app.Companies` FK — enough for the user to author the migration by hand. Explicitly list which columns get NO FK yet and why.
4. The **template-company seed script** exists under `sql-scripts-dyanmic/`, idempotent.
5. A short **hand-back note**: what you built, the `Company.Status` default choice you made, the jsonb mapping approach you used, and anything you had to verify in the codebase that differed from this brief.

## Report back to the PM session
State: build clean (Y/N), migration spec delivered (Y/N), seed script path, and any deviations. **Do not start P-02.**
