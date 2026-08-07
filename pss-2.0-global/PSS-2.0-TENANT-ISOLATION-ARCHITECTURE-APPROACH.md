# PSS 2.0 — Tenant Isolation Architecture

**Status:** Decision document — response to the "one database per tenant" proposal
**Date:** 2026-08-07
**Scope:** Grounded in the PSS 2.0 codebase as it stands on `master`. Every claim below cites a real file.
**Companion docs:** `PSS-2.0-PLANS-AND-ENTITLEMENTS-APPROACH.md`, `PSS-2.0-GTM-LEAD-ONBOARDING-AND-PRODUCT-ADMIN-APPROACH.md`, `PSS_2.0_Backend/PeopleServe/MULTI_TENANCY_GUIDE.md`, `docs/AI-Platform-Architecture.md`

---

## 1. Executive Summary

### 1.1 The proposal, and the answer

Management proposes **one database per tenant**, on the reasoning that a bug in application code, an API query, an AI retrieval, a background job, or a reporting query must not expose another tenant's data.

**The concern is correct. The proposed remedy does not address most of it.**

Here is the uncomfortable finding from the code audit. PSS 2.0's tenant boundary today is a single EF Core global query filter, built by reflection in `ApplicationDbContext.ApplyTenantFilters`. Its very first clause is:

```csharp
Expression tenantIdIsNull = Expression.Equal(currentTenantIdProperty, Expression.Constant(null, typeof(int?)));
...
filter = Expression.OrElse(tenantIdIsNull, companyIdEqualsTenantId);
```
— `Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs:104-117`

Read that literally: **when the system does not know which tenant it is serving, it shows all of them.** And the function that supplies that value is:

```csharp
public int? GetCurrentTenantId()
{
    try { ... }
    catch { return null; }
}
```
— `Base.Application/Services/TenantContext/TenantContext.cs`

Any exception, anywhere in tenant resolution, silently converts to "see everything." That is a **fail-open** boundary. It is the single most important finding in this document, and moving to one database per tenant would not have changed it — it would have changed the *question* from "which rows do I return?" to "which database do I connect to?", and a fail-open answer to *that* question leaks a whole tenant instead of one query's worth.

### 1.2 What database-per-tenant actually buys, and what it does not

Management listed six leak vectors. Here is which ones a physical database split genuinely fixes:

| Leak vector management named | Where the failure actually happens | Does DB-per-tenant fix it? |
|---|---|---|
| Developer forgets a tenant filter in a query | EF/LINQ layer, above the DB | **Yes** — the connection carries tenancy, so there is nothing to forget |
| Raw SQL / stored procedure bypasses the filter | Same connection, filter never applied | **Yes** — same reason |
| Background job runs with no user context | Job picks the *wrong connection* instead of the *wrong filter* | **Partially** — still needs an explicit tenant loop; the mistake becomes louder, not impossible |
| API query returns another tenant's row | Authorization + resolution layer, above the DB | **No** — a wrong `companyId` in a request maps to a wrong connection just as easily |
| AI retrieval pulls the wrong corpus | Vector store / retrieval layer, usually outside the RDBMS entirely | **No** — unless the vector store is *also* split, which is a separate decision |
| Reporting query joins across tenants | Reporting store, often a warehouse that re-merges everything | **No** — usually makes cross-tenant reporting *harder*, not safer |

**Three of six. And the three it fixes are exactly the three that a much cheaper control also fixes: PostgreSQL Row-Level Security.** RLS sits *inside* the database, below EF, below raw SQL, below stored procedures, below Dapper, below anything an application developer can forget. That is the property management is actually asking for.

### 1.3 Recommendation in one line

> **Adopt Option 2 (shared database + PostgreSQL Row-Level Security) as the default for all tenants, with Option 4 (dedicated database, same codebase) available as a paid enterprise tier. Do not adopt Option 3 as the standard model.**

The reason is not cost, though DB-per-tenant is materially more expensive. The reason is that **PSS 2.0 currently has one physical `ApplicationDbContext`, one connection string, and one migration history table**, spanning both tenant schemas (`app`, `sett`, `notify`, `integ`, `finance`, `ai`, `audit`) *and* platform-global schemas (`ops`, `billing`, `auth`). Splitting per tenant means physically decomposing that context and deciding where identity lives — a multi-month structural project. Spending those months on RLS instead closes strictly more leak vectors, sooner.

### 1.4 The honest counter-argument

There is one finding in this audit that argues **for** management, and it deserves to be stated plainly rather than buried:

`Base.API/Program.cs` registers eight Hangfire recurring jobs plus `AuditQueueDrainer` and `OpenExchangeRatesSyncJob`. Background jobs have no `HttpContext`. And `TenantAccessBehavior` documents the consequence in its own comment:

```csharp
// Background jobs (Hangfire, hosted services) have no HTTP context.
// GetCurrentTenantId() returns null for them, same as SuperAdmin.
// ... let the handler + EF filter operate with null tenant (sees all data).
```
— `Base.Application/Behaviors/TenantAccessBehavior.cs:26-31`

**Every background job in PSS 2.0 currently runs unfiltered across all tenants, by design, and the design is written down.** That is precisely management's stated fear, in production, today. It is the strongest argument they have. RLS with a fail-closed session variable fixes it more completely than DB-per-tenant would (a per-tenant job loop can still be written against the wrong connection; an RLS session with no tenant set returns zero rows and the job visibly does nothing).

### 1.5 Priority order

The audit found that the boundary problems are ranked roughly the inverse of how much they cost to fix:

1. **Fail-open tenant resolution** — a `catch { return null; }` and a `CurrentTenantId == null ||` clause. Days of work. Highest severity.
2. **Background jobs unfiltered** — an explicit tenant loop plus fail-closed context. Weeks. High severity.
3. **Raw SQL and `IgnoreQueryFilters()` bypasses** — 439 filter-disable sites plus ~12 raw-SQL paths. Months of review, or one RLS policy set. High severity, cheap fix *if* done at the DB layer.
4. **Anonymous surface** — six controllers without `[Authorize]`, `MapGraphQL()` without `.RequireAuthorization()`, `AddAuthorization()` without a fallback policy. Days. Medium-high.
5. **Database-per-tenant** — months of structural work. Fixes items 1–3 *only if* items 1–3 are also fixed, because a fail-open tenant resolution feeding a connection-string factory is still fail-open.

Item 5 does not belong before items 1–4. That is the core of this recommendation.

---

## 2. Architecture Comparison

### 2.1 The four options, scored against PSS 2.0's actual position

| Dimension | **Opt 1** Shared DB, discriminator (**current**) | **Opt 2** Shared DB + RLS (**recommended**) | **Opt 3** DB per tenant | **Opt 4** Hybrid (2 + dedicated for enterprise) |
|---|---|---|---|---|
| **Isolation strength** | Weak — enforced in app code, fail-open (`ApplicationDbContext.cs:104`) | Strong — enforced by Postgres below all app code | Strongest — physical | Strong default, physical where paid for |
| **Blast radius of a code bug** | All tenants | Zero (policy holds regardless of the bug) | One tenant | Zero / one tenant |
| **Blast radius of a *config* bug** | All tenants | All tenants (one bad `SET` = 0 rows, fails closed) | **All tenants** (a connection-factory bug routes anywhere) | Same |
| **Protects raw SQL / sprocs** | No — 12 raw paths bypass the filter | **Yes** | Yes | Yes |
| **Protects background jobs** | No — documented as unfiltered | Yes, if session var is mandatory | Partially — still needs a correct per-tenant loop | Yes |
| **Protects AI retrieval** | N/A (not built) | Only if vector store is in Postgres with RLS | Only if vector store is also split | Same |
| **Protects cross-tenant reporting** | No | Yes, by default; opt-out is explicit and auditable | Makes it *hard* (needs federation/ETL) | Yes |
| **Migration effort from today** | — | **Low-medium**: SQL policies + one session-var interceptor. No context split. | **Very high**: split `ApplicationDbContext`, relocate `auth`/`ops`/`billing`, connection routing, N migration histories | Medium (Opt 2 first, Opt 4 later) |
| **Schema migration at 1,000 tenants** | 1 run | 1 run | **1,000 runs**, partial-failure states, version skew | 1 run + N enterprise runs |
| **Connection pool pressure** | 1 pool | 1 pool | **N pools** — the hard scaling wall (see §12) | 1 pool + N |
| **Per-tenant cost** | Lowest | Lowest | High — each DB carries fixed overhead | Low default, priced for enterprise |
| **Noisy-neighbour control** | None | None (needs quotas/partitioning) | Good | Good where it is paid for |
| **Per-tenant backup / PITR** | Hard (row-level extract) | Hard (row-level extract) | **Trivial** | Trivial where it matters |
| **Per-tenant encryption key** | No | No | Yes | Yes for enterprise |
| **Tenant offboarding / export** | Query + scrub | Query + scrub | **Drop the database** | Both |
| **"Your data is in its own database"** sales claim | No | No | Yes | **Yes, for those who pay for it** |
| **Compliance posture (SOC 2 / HIPAA-adjacent)** | Weak | **Strong** — RLS is a recognised control | Strong | Strong |
| **Cross-tenant platform reporting (`ops`, `billing`)** | Trivial today | Trivial (explicit `BYPASSRLS` role) | **Hard** — requires an aggregation pipeline | Trivial for the shared pool |

### 2.2 Reading the table

Three observations decide this.

**First: rows 3 and 4 of the "blast radius" block.** DB-per-tenant converts *code* bugs into non-events but leaves *configuration* bugs catastrophic — a connection-factory that resolves the wrong tenant hands over an entire database. RLS converts both into non-events: a wrong or missing session variable returns zero rows. Fail-closed beats fail-open at every layer, and that is a property of the *design*, not the *topology*.

**Second: the "migration effort from today" row.** This is where PSS 2.0's specific shape matters. `Base.Infrastructure/DependencyInjection.cs:32` reads exactly one connection string:

```csharp
var connectionString = configuration.GetConnectionString("Database");
```

and registers exactly one context, with `ISettingDbContext` deliberately mapped to *the same scoped instance* (line 65). The persistence folder contains 18 files, but they are `public partial class ApplicationDbContext` slices — `AuthDbContext.cs`, `OpsDbContext.cs`, `BillingDbContext.cs`, `AidaDbContext.cs`, and the rest all compile into **one** class with **one** migration history table (`Migrations:HistoryTableName`, mandatory, `DependencyInjection.cs:34-39`). Option 3 requires taking that apart. Option 2 requires adding SQL policies and one interceptor.

**Third: the platform schemas.** `ops` and `billing` are platform-global by house rule — every read already uses `IgnoreQueryFilters()`. `auth` holds `Users`, `Roles`, `UserRoles`, `Modules`, `PasswordResets`. Under Option 3, none of these can follow a tenant into a per-tenant database; they must stay central. So Option 3 does not give you "one database per tenant" — it gives you "one database per tenant, *plus* a central identity and control-plane database, *plus* cross-database joins wherever a tenant row references a platform row." That is a distributed-systems problem the current codebase has no machinery for.

### 2.3 Where Option 3 remains genuinely correct

This is not a rejection of Option 3 in all cases. It is right when:

- A specific customer contractually requires physical separation or their own encryption key.
- A customer's data residency obligation puts them in a different region.
- A customer is large enough that noisy-neighbour isolation has real value.
- A customer needs independent PITR to a timestamp of their choosing.

All four are **enterprise-tier characteristics**, not defaults. That is Option 4.

---

## 3. Recommended Architecture

### 3.1 The model

**Shared PostgreSQL database, schema-partitioned, with Row-Level Security as the enforcing boundary, plus a dedicated-database path for enterprise tenants running the identical codebase.**

Concretely, four layers, each of which must fail closed:

```
┌──────────────────────────────────────────────────────────────────────┐
│ L1  EDGE — host/subdomain → tenant, JWT → tenant, act-as → tenant     │
│     HostTenantResolver + JWT claims. Must resolve to exactly one      │
│     tenant or reject. Today: resolves, but null is permitted.         │
├──────────────────────────────────────────────────────────────────────┤
│ L2  PIPELINE — MediatR behaviors. TenantIsolation → TenantAccess →    │
│     Authorization. Must reject when tenant is unknown.                │
│     Today: TenantAccessBehavior explicitly permits null (background). │
├──────────────────────────────────────────────────────────────────────┤
│ L3  ORM — EF global query filter + TenantSaveChangesInterceptor.      │
│     Convenience layer. Keep it. Stop treating it as the boundary.     │
│     Today: this IS the boundary, and it is fail-open.                 │
├──────────────────────────────────────────────────────────────────────┤
│ L4  DATABASE — RLS policies keyed on a session GUC. THE boundary.     │
│     Unset GUC ⇒ zero rows. No application code can bypass it.         │
│     Today: does not exist.                                            │
└──────────────────────────────────────────────────────────────────────┘
```

The change in posture is L4. Today the boundary is L3 — a layer that any of 439 `IgnoreQueryFilters()` calls, 12 raw-SQL paths, or one swallowed exception can switch off. Moving the boundary to L4 makes all of those harmless.

### 3.2 Why not just fix L3?

Because L3 cannot be made complete. Three structural reasons, all verified in code:

**(a) The filter only exists where a `CompanyId` property exists.**
```csharp
var tenantEntityTypes = builder.Model.GetEntityTypes()
    .Where(e => e.ClrType.GetProperty("CompanyId") != null)
```
— `ApplicationDbContext.cs:79-81`

An entity added without `CompanyId` gets **no filter and no warning**. There is no build-time check, no test, no startup assertion. The failure mode is silent.

**(b) `SetQueryFilter` replaces; it does not compose.** `ApplyTenantFilters` runs at line 48 of `OnModelCreating`, *after* `ApplyConfigurationsFromAssembly` at line 45. Any per-entity `HasQueryFilter` written in an `IEntityTypeConfiguration` is silently overwritten. Today the count of `HasQueryFilter` in `Base.Infrastructure` is zero, so nothing is broken — but the first developer who adds a soft-delete filter will have it discarded with no error.

**(c) Raw SQL is outside EF entirely.** `LookupService` opens an ADO.NET connection off the shared context and executes a Postgres function directly:
```csharp
var connection = _dbContext.Set<MasterData>()
    .GetService<ICurrentDbContext>().Context.Database.GetDbConnection();
...
command.CommandText = "SELECT * FROM import.fn_get_grid_lookup_values(@p_grid_id)";
```
— `Base.Infrastructure/Services/Import/LookupService.cs:29-40`

No `CompanyId` is passed. Isolation depends entirely on what that SQL function does internally. `TemplateGeneratorService.cs:79` does the same with `import.fn_get_import_sample_data`. `ApplicationDbContext.ExecuteRawSqlAsync` (line 135) is a general escape hatch with eight callers in `Base.Application`. **RLS covers every one of these without touching them.** No amount of EF hardening does.

### 3.3 The dedicated-database path (Option 4), stated precisely

An enterprise tenant gets its own database. **The codebase does not fork.** The mechanism:

- A tenant record carries an optional `DatabaseKey`. Null ⇒ shared pool.
- A connection-string resolver maps `DatabaseKey` → connection string, sourced from Key Vault, never from a tenant-supplied value.
- The dedicated database contains **only tenant schemas**. `auth`, `ops`, and `billing` remain in the shared control-plane database, always.
- RLS is enabled in the dedicated database too, with the same policies. Belt and braces: the connection identifies the tenant, and the policy re-asserts it. If the resolver is ever wrong, the policy still returns zero rows rather than the wrong tenant's data.

That last point is the design principle worth carrying: **physical separation is defence in depth, not a replacement for the logical boundary.** A dedicated database with RLS disabled is *less* safe than a shared database with RLS enabled, because the shared one fails closed and the dedicated one trusts a connection string.

---

## 4. Tenant Isolation Strategy

### 4.1 Database layer

**Target.** Every tenant table carries `CompanyId NOT NULL`. Each gets:

```sql
ALTER TABLE <schema>.<table> ENABLE ROW LEVEL SECURITY;
ALTER TABLE <schema>.<table> FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON <schema>.<table>
  USING      (CompanyId = current_setting('app.current_company_id', true)::int)
  WITH CHECK (CompanyId = current_setting('app.current_company_id', true)::int);
```

`current_setting(..., true)` returns NULL when unset; `CompanyId = NULL` is NULL, which is not TRUE, so **zero rows**. That is the fail-closed property, and it is achieved by the absence of a value rather than the presence of a check — which is why it cannot be forgotten.

`FORCE ROW LEVEL SECURITY` matters: without it, the table owner bypasses the policy, and the application role is frequently also the owner.

**Roles.** Three, not one:

| Role | RLS | Used by |
|---|---|---|
| `pss_app` | Subject to policies | All request-scoped application traffic |
| `pss_platform` | `BYPASSRLS` | Control-plane reads of `ops` / `billing`, and only those |
| `pss_migrator` | Owner, DDL | Migrations only, never at runtime |

Today the application uses a single connection string (`DependencyInjection.cs:32`) and therefore a single role. Splitting the role is a prerequisite, and it is also what converts the 356 legitimate `IgnoreQueryFilters()` calls in `OpsBusiness`/`BillingBusiness` from "trust the developer" into "the connection literally cannot see tenant rows unless it is the platform role."

**Setting the GUC.** One EF connection interceptor, on `ConnectionOpenedAsync`, issues `SET LOCAL app.current_company_id = @id` from `ITenantContext`. `SET LOCAL` is transaction-scoped, which matters because the Npgsql pool reuses physical connections — a session-scoped `SET` would leak a tenant id to the next borrower of that connection. **This is the single highest-risk implementation detail in the whole plan.** It must be `SET LOCAL` inside an explicit transaction, or `DISCARD ALL` on return to pool, and it needs a dedicated test.

**Interim, before RLS lands.** Two one-line changes that remove the worst of the fail-open behaviour immediately:

1. `TenantContext.GetCurrentTenantId()` — replace `catch { return null; }` with a log-and-throw. A tenant resolution failure must be a 500, not a data disclosure.
2. `ApplyTenantFilters` — introduce an explicit sentinel. Today `null` means both "SuperAdmin, show everything" and "I have no idea who this is." Those must stop being the same value. `TenantContext` should return a discriminated result: `Tenant(id)` / `PlatformWide` / `Unknown`, and only `PlatformWide` disables the filter.

That second change is small in code and large in meaning. It is the difference between fail-open and fail-closed, and it does not require RLS, a schema change, or a migration.

### 4.2 API layer

**Current gaps, verified:**

- `Base.API/DependencyInjection.cs` calls `services.AddAuthorization()` with **no `FallbackPolicy`**. An endpoint with no `[Authorize]` attribute is anonymous.
- `app.MapGraphQL()` carries **no `.RequireAuthorization()`**. The entire GraphQL surface's protection depends on per-handler attributes.
- Six controllers carry no class-level `[Authorize]`: `MediaController`, `ReceiptDownloadController`, `ExportController`, `ReportExportController`, `ImportController`, `CertificateController`.
- Three are deliberately `[AllowAnonymous]` and correctly so: `PaymentWebhookController`, `PlatformBillingWebhookController`, `RazorpayWebhookController`.

The chain that matters: **anonymous request → no principal → `GetCurrentTenantId()` returns null → the `CurrentTenantId == null` branch of the query filter short-circuits → every tenant's rows are returned.** Four independent components each behaving reasonably in isolation, composing into a full disclosure path. This is why the fix belongs at L4: no single one of those four is obviously wrong on its own.

**In fairness to the current design**, RBAC coverage at the handler level is broad — `CustomAuthorize` appears in 1,827 files under `Base.Application/Business`. The gap is not "authorization is missing"; it is that authorization is **opt-in**:

```csharp
// If the attribute is not found, skip authorization
if (authorizeAttribute == null)
{
    return await next();
}
```
— `Base.Application/Security/AuthorizationBehavior.cs`

With ~1,800 files opted in, the risk is the next handler someone writes, not the ones that exist.

**Target:**
- `AddAuthorization(o => o.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build())`.
- `.RequireAuthorization()` on `MapGraphQL()`, with public operations explicitly `[AllowAnonymous]`.
- `[Authorize]` at class level on the six controllers, with per-action `[AllowAnonymous]` where a public route genuinely exists.
- `AuthorizationBehavior` inverts: no attribute ⇒ **deny**, with an explicit `[NoAuthorizationRequired]` marker for the deliberate exceptions. This is the only change in this section likely to surface latent breakage; it should ship behind a config flag that logs-instead-of-denies for one release.

**Act-as / impersonation.** `TenantContext.GetActAsCompanyId()` reads the `X-Act-As-Company` header and parses it with no validation at that point; `TenantAccessBehavior` performs the access check (`ValidateCrossCompanyScope`). That split is workable but fragile — the header value is available to anything holding `ITenantContext`, whether or not the behavior ran. Under RLS this becomes safe by construction, because the GUC is set from the *validated* effective company, not from the header.

### 4.3 Caching

`IMemoryCache` is in-process and shared across all tenants in the instance. Audit result:

| Service | Key | Verdict |
|---|---|---|
| `EntitlementService` | `CacheKey(int companyId)` | **Correct** — tenant-scoped, ~60s TTL |
| `MenuFeatureMapService` | `$"menufeaturemap:g{_generation}"` — no company | **Correct** — `billing.FeatureMenuMaps` is a hand-curated platform-global vocabulary (see `feedback_features_are_curated_not_derived`) |
| `LookupService` | Takes `IMemoryCache` in the constructor and **never assigns or uses it** (`LookupService.cs:14-20`) | **Dead parameter** — no caching bug, but it signals caching was intended and abandoned. The real problem in this file is the raw connection (§3.2c). |
| `GetTenantLoginConfigHandler` | Normalized host | **Correct** — host *is* the tenant discriminator here |

**Rule to enforce going forward:** every cache key holds either an explicit `CompanyId` or an explicit, commented `PLATFORM_GLOBAL` marker. A key with neither is a bug. This should be a code-review checklist item, because it is not statically detectable.

**At scale**, `IMemoryCache` becomes a correctness problem for a different reason: N instances hold N divergent copies, so invalidation (`EntitlementService.Invalidate(companyId)`) only clears one. That is a staleness bug, not a leak, and it argues for Redis at the point where the app runs more than one instance — with the same key rule, plus a per-tenant key prefix so a `SCAN`-based flush can target one tenant.

### 4.4 File and blob storage

`AzureBlobFileStorageService` takes its container name from configuration and builds:
```csharp
string blobPath = Path.Combine(request.Directory, newFileName).Replace("\\", "/");
```
`request.Directory` is caller-supplied. `DeleteFileAsync(string filePath, ...)` accepts an arbitrary path.

**There is no enforced tenant segment in either the container or the path.** Isolation depends on every caller choosing a correct directory, and on nothing ever passing `../`. This is a genuine gap and it is unaffected by any database decision.

**Target:** the storage service derives the prefix itself from `ITenantContext` — `tenant/{companyId}/{category}/{file}` — and rejects any caller-supplied path that does not resolve under the current tenant's prefix after normalisation. Callers lose the ability to specify the tenant segment at all. Containers stay shared (per-tenant containers hit Azure account limits around 10k tenants and complicate lifecycle policies); enterprise tenants on Option 4 get a dedicated container or storage account.

Signed-URL TTLs should be short (minutes) and the URL should never be the only authorization — `ReceiptDownloadController` and `CertificateController` currently have no `[Authorize]`, which makes any predictable blob path directly reachable.

### 4.5 Search

`services.AddSearchEngine(connectionString!)` — `Base.Infrastructure/DependencyInjection.cs:149` — passes the *same* connection string. So search is Postgres-backed, which is good news: RLS covers it automatically, provided the search path goes through the RLS-subject role and does not use its own privileged connection. That needs verification during implementation, and it is a reason to prefer keeping search in Postgres rather than moving to a separate engine.

If search ever moves to Elasticsearch/OpenSearch, the tenant filter must be a **mandatory filter clause injected by the client wrapper**, not a caller-supplied term — same principle as blob paths. Per-tenant indices do not scale past a few thousand tenants (shard overhead), so filtered aliases are the right pattern.

### 4.6 AI and vector isolation

**Current state, verified from `Services/Base/AIDA-MODULE-README.md` and `docs/AI-Platform-Architecture.md`:** there is **no vector store, no embedding pipeline, and no RAG** in PSS 2.0 today. The `ai` schema holds `Provider`, `ModelClassMap`, `TenantConfig`, `TenantProviderPreference`, `TenantProviderKey` (KMS-wrapped, via an implemented `AzureKeyVaultTenantKeyProvider`), `AiAuditLog`, `UsageDaily`, `Skill`, `TenantSkill`, `Prompt`, `ChatSession`, `ChatMessage`. Anthropic/OpenAI adapters and `RoutingPolicyEngine` are skeletons.

**This is the most valuable finding in the whole audit, and it is good news.** The AI isolation rules can be written *before* the code exists. That is the cheapest moment such rules are ever available, and it never comes back.

The rules, to be treated as non-negotiable in the AIDA implementation plan:

1. **Embeddings live in Postgres (`pgvector`), in the `ai` schema, with `CompanyId NOT NULL` and the same RLS policy as every other tenant table.** Do not adopt an external vector database. An external store is a second isolation system with a second failure mode, second set of credentials, and no relationship to the RLS boundary. `pgvector` inherits the boundary for free. If scale eventually forces a dedicated store, that is a deliberate later decision with its own design.
2. **Retrieval is never given a caller-supplied tenant scope.** The retrieval service derives `CompanyId` from `ITenantContext` and injects it. A caller cannot request a corpus.
3. **A retrieval that resolves to no tenant returns zero documents and raises an alert.** Never "all documents."
4. **Prompt assembly logs the document IDs retrieved** into `ai.AiAuditLog`, so a cross-tenant retrieval is *detectable after the fact*. Without this, an AI leak is invisible — there is no query log to inspect.
5. **Tenant content never enters a model provider's training or fine-tuning path.** Zero-retention API tiers only; contractually confirmed per provider.
6. **Per-tenant provider keys stay KMS-wrapped** — `AzureKeyVaultTenantKeyProvider` already does this. Do not weaken it for convenience. A shared platform key means one tenant's prompt injection can exhaust another's quota and appear in another's provider-side logs.
7. **Model responses are treated as untrusted input.** If an AI-generated value ever reaches a query, it is a parameter, never SQL, and never a `CompanyId`.

Rule 7 is worth dwelling on. `ApplicationDbContext.ExecuteRawSqlAsync(string sql, object[] parameters, ...)` exists and has eight callers. The day an AI feature composes any part of that `sql` string, the tenant boundary is gone regardless of topology. That is an argument for RLS specifically: with RLS, a prompt-injected query still cannot cross tenants.

### 4.7 Background jobs

The gap is documented in the code itself (`TenantAccessBehavior.cs:26-31`, quoted in §1.4). Eight recurring Hangfire jobs are registered in `Program.cs` — import-schedule recovery, online-donation map recovery, PayU recurring charge, staging sweep, subscription renewal, event communication dispatch, notification retention, email retry sweep — plus `AuditQueueDrainer` and `OpenExchangeRatesSyncJob` as hosted services. All run with a null tenant.

**Target pattern — the tenant loop:**

```csharp
foreach (var companyId in await activeCompanyIds)
{
    using var scope = serviceProvider.CreateScope();
    scope.ServiceProvider.GetRequiredService<ITenantContext>()
         .EnterBackgroundTenantScope(companyId);   // sets the RLS GUC on this scope's connection
    await scope.ServiceProvider.GetRequiredService<IJobStep>().RunAsync(ct);
}
```

Properties that matter:
- One DI scope per tenant per iteration — so one tenant's `DbContext` change tracker never carries into the next.
- The tenant id is set *explicitly*, so there is no "ambient null" to fall back on.
- Under RLS, a job that forgets `EnterBackgroundTenantScope` reads zero rows and does visibly nothing — a loud failure, which is exactly what you want. Under DB-per-tenant, a job that forgets to switch connections keeps using the last one and silently writes tenant A's data into tenant B. **RLS fails safer here than physical separation does.**
- A genuinely platform-wide job (`OpenExchangeRatesSyncJob` writes global FX rates; `AuditQueueDrainer` drains a mixed queue) declares itself platform-scoped and runs on the `pss_platform` role. Explicit, greppable, reviewable.

`AuditQueueDrainer` deserves specific attention: it is a **singleton hosted service** draining a bounded `Channel<AuditLog>` fed by all tenants concurrently. Each row already carries its `CompanyId` from `AuditLogWriter`, so the drain is a platform-scoped bulk insert and that is correct — but it must never *read* audit rows, only write them.

### 4.8 Messaging and notifications

`TenantSaveChangesInterceptor` contains the one place in the codebase where this was already thought through properly, and it is worth quoting as the model for everything else:

```csharp
// PLATFORM-scoped rows are company-less BY DESIGN ... The stamp is a convenience;
// the address space is a security boundary, so the address space wins.
var scopeProperty = entityType.GetProperty("Scope");
if (scopeProperty?.PropertyType == typeof(string)
    && string.Equals(scopeProperty.GetValue(entry.Entity) as string, "PLATFORM", ...))
{ continue; }
```
— `Base.Infrastructure/Data/Interceptors/TenantSaveChangesInterceptor.cs:69-81`

"The stamp is a convenience; the address space is a security boundary" is precisely the argument this document makes about the query filter versus RLS, applied to writes. The write path already understands the distinction. The read path does not yet.

Note also the deliberate relaxation at lines 111-119: reassignment (`value → other value`) stays blocked, but first assignment (`null → value`) is allowed, because blocking it broke provisioning Step 1. That is a correct and well-documented trade-off — but it means a row can acquire a `CompanyId` post-insert, so any RLS `WITH CHECK` policy must tolerate that specific transition or provisioning breaks again in the same way.

For outbound channels — email, SMS, WhatsApp — the isolation risk is a **recipient list built from an unfiltered query**. Under RLS this is closed automatically. `PlatformCommunicationProviderResolver` correctly separates the platform's own sender config (`ops.PlatformCommunicationProviders`, no `CompanyId`) from tenant sender config (`notify.WhatsAppSettings`, per-company). Keep that separation absolute: a tenant must never be able to resolve the platform provider.

---

## 5. Database Architecture

### 5.1 Current schema map (verified)

| Schema | Contents | Scope |
|---|---|---|
| `auth` | `Users`, `Roles`, `UserRoles`, `Modules`, `PasswordResets` | **Platform** (users are cross-tenant addressable) |
| `app` | `Companies` and core tenant entities | Mixed — `Companies` is the tenant registry |
| `ops` | Provisioning runs/steps, `Lead`, `PlatformAuditLog`, `PlatformCommunicationProviders` | **Platform** |
| `billing` | `Plans`, `Features`, `FeatureMenuMaps`, `PlanEntitlements`, `PlanRoleBaselines`, subscriptions | **Platform** |
| `sett` | KV `OrganizationSettings`, `TenantSetupTasks`, number sequences | Tenant |
| `finance` | Donations, payments, receipts | Tenant |
| `notify` | Templates, jobs, WhatsApp settings | Tenant + `Scope='PLATFORM'` rows |
| `integ` | Integration config | Tenant |
| `audit` | `AuditLog` | Tenant |
| `ai` | AIDA config, keys, chat, usage | Tenant + platform provider catalog |
| `import` | Staging tables, `fn_get_grid_lookup_values`, `fn_get_import_sample_data` | Tenant (via SQL functions — **unverified isolation**) |

### 5.2 Target: three logical databases

Not eleven schemas across one boundary, but three databases with clear ownership. Under Option 2 these can start as three schemas-groups in one physical database and split later; the important thing is that the *boundary* is drawn now.

**(a) Control-plane database** — `ops`, `billing`, and the tenant registry.
Never subject to RLS. Accessed only by the `pss_platform` role. This is where the 356 legitimate `IgnoreQueryFilters()` calls in `OpsBusiness`/`BillingBusiness` stop being a matter of developer discipline: those tables are simply not visible to `pss_app`.

**(b) Identity database** — `auth`.
The awkward one, and the reason Option 3 is harder than it looks. A user can belong to multiple companies (`AccessibleCompanyIds` in the JWT), so `auth.Users` cannot live inside a per-tenant database. Under Option 2 it is central and RLS-exempt for the row itself, with membership (`UserRoles`) tenant-scoped. Under Option 3 it *must* stay central, which means every per-tenant database has a dangling reference to a user id it cannot join to — a real cost that DB-per-tenant proposals routinely underestimate.

**(c) Tenant database(s)** — everything else.
RLS on every table. Shared by default; dedicated for enterprise (Option 4).

### 5.3 Reporting

Cross-tenant reporting is a **platform** capability, not a tenant one. It runs on `pss_platform` against a read replica, and every such query is logged to `ops.PlatformAuditLog` (the writer already exists: `IPlatformAuditWriter`, registered at `DependencyInjection.cs:131`, and its registration comment already explains why it is separate from `IAuditLogWriter` — the tenant-scoped writer "stamps the CALLER's company and so cannot record an action taken by a platform operator who belongs to no tenant").

Tenant-facing reports run as the tenant, under RLS, with no exception. `ReportExportController` currently has no `[Authorize]` — that is the first thing to fix here.

Note this is a place where Option 3 is actively worse: cross-tenant platform reporting against 1,000 databases requires an ETL pipeline into a warehouse, which re-merges all tenant data into one place — reintroducing the exact shared-store risk the split was meant to eliminate, but now in a system with weaker access controls than the OLTP database.

### 5.4 Indexing

Under RLS every query gains an implicit `CompanyId = ?` predicate. Every index on a tenant table should therefore lead with `CompanyId`. This is not merely a performance note — a missing leading `CompanyId` on a large table turns an indexed lookup into a filtered scan, and at 1,000 tenants that is the difference between a working system and a stalled one. Index review is a mandatory part of the RLS rollout, not a follow-up.

---

## 6. Tenant Provisioning Architecture

### 6.1 Current state — better than expected

This is the strongest part of the existing codebase. `ProvisionTenant.cs` implements a **9-step idempotent, resumable provisioning engine**:

| Step | Action |
|---|---|
| 1 | `CREATE_COMPANY` — adopts-or-creates by `CompanyCode` |
| 2 | Create subscription |
| 3 | Seed roles (from a template company) |
| 4 | Seed capabilities (via `IPlanBaselineApplier` from `billing.PlanRoleBaselines`) |
| 5 | Seed master data from template |
| 6 | Seed settings from template |
| 7 | Seed fields from template |
| 8 | Create admin user |
| 9 | Finalize |

With: one transaction per step via the connection-resiliency execution strategy; run state `PENDING → RUNNING → (SUCCEEDED | PAUSED_ON_ERROR)` in `ops.TenantProvisioningRun` / `...RunStep`; step matching by `StepNumber` so in-flight runs survive a rename; and an integrity self-heal that detects `run.CompanyId == null` alongside `SUCCEEDED` steps and re-runs the plan from Step 1.

The comments record a real production bug and its fix in detail (`ProvisionTenant.cs:100-119`, quoted in §4.8) — the `TenantSaveChangesInterceptor` modification guard was silently dropping Step 1's `run.CompanyId` write, the engine read the null back as "company deleted", and reset all nine steps on every resume, forever. "The run in the monitor showed 9/9 SUCCEEDED with no Company ID and five attempts on step 1." That is exactly the class of bug an idempotent engine is supposed to survive, and it did.

### 6.2 What changes under the recommended architecture

**Under Option 2 (shared + RLS): almost nothing.** Add one step:

- **Step 0 — `SET app.current_company_id`** for steps 2-9. Step 1 necessarily runs platform-scoped (it creates the company). Everything after it should run *as the tenant*, which incidentally means the seeding steps get RLS-verified for free: if Step 5 tries to seed data with the wrong `CompanyId`, the `WITH CHECK` policy rejects it rather than silently mis-filing it.

Template-company reads (steps 5-7 read from `templateCompanyId`) need an explicit platform-scoped read, since the tenant cannot see the template. That is a real change and should be a named helper, not an ad-hoc `IgnoreQueryFilters()`.

**Under Option 4 (dedicated database for an enterprise tenant): two more steps**, inserted before Step 2:

- **Step 1a — `CREATE_DATABASE`** — provision from a template database, record the `DatabaseKey`, store the connection string in Key Vault. Must be idempotent (adopt-if-exists) to match the rest of the engine.
- **Step 1b — `RUN_MIGRATIONS`** — bring the new database to the current schema version and record that version on the tenant row.

The engine's existing idempotency and resume machinery handles the failure modes; this is genuinely an incremental change, which is a point in favour of Option 4 being reachable later without rework. **This is the main reason Option 4 is credible as a future step rather than a rewrite.**

**Under Option 3 as the default**, every tenant pays steps 1a and 1b, every provisioning becomes a DDL operation, and provisioning latency goes from seconds to minutes. Fine at 50 tenants. A serious operational burden at 1,000, where self-service signup is the goal.

### 6.3 One gap worth naming

Step 9 does **not** send the welcome email — the comment at `ProvisionTenant.cs:270-273` records that the invitation moved behind an operator review gate and the step was renamed from `SEND_WELCOME` so it "does not promise an email that provisioning does not send." That is honest and correct. But it means tenant activation depends on a manual operator action, which is the bottleneck to fix before self-service signup at scale. It is a GTM issue rather than an isolation issue, and it is tracked in `PSS-2.0-GTM-...`; noted here only because §12's scaling numbers assume it gets automated.

---

## 7. Migration Strategy

### 7.1 Schema migrations

| Model | 1,000 tenants | Failure mode | Rollback |
|---|---|---|---|
| **Shared + RLS** | 1 migration run | All-or-nothing, single transaction where possible | 1 rollback |
| **DB per tenant** | 1,000 runs | **Partial** — e.g. 400 migrated, 600 not, app must support both schema versions simultaneously | 1,000 rollbacks, some of which fail |

The middle column is the argument. Once tenants can be on different schema versions, **every deployment must be backward-compatible with the previous schema for as long as any tenant lags** — expand/contract on every change, feature flags per schema version, and a migration orchestrator with retry, quarantine, and version tracking that PSS 2.0 does not have and would need to build. That machinery is the real cost of Option 3, and it is recurring, not one-time.

PSS 2.0 has exactly one migration history table today (`Migrations:HistoryTableName`, mandatory at `DependencyInjection.cs:34-39`). Option 3 turns that one into N and requires an orchestrator around it.

### 7.2 Migrating to RLS — the sequence

Per house rules, **migrations are user-owned**: this section is a spec, not something to execute. Every step below is either a hand-written `.sql` under `sql-scripts-dyanmic/` or an EF migration for the author to write and apply.

**Phase A — Prove the data is clean (no schema change).**
`.sql` script: for every tenant table, count rows where `CompanyId IS NULL` or `CompanyId = 0`. RLS cannot be enabled on a table with orphan rows — those rows become invisible to everyone, including whatever process depends on them. Expect surprises. Fix before proceeding.

**Phase B — Fail-closed in application code (no schema change).**
- `TenantContext.GetCurrentTenantId()`: remove the blanket `catch`.
- Introduce the `Tenant / PlatformWide / Unknown` discriminated result so `null` stops meaning two things.
- `AddAuthorization` fallback policy; `[Authorize]` on the six controllers; `.RequireAuthorization()` on `MapGraphQL()`.
- Re-enable `ValidateScopes` / `ValidateOnBuild` in `Program.cs` (see §7.4).

**This phase alone closes the highest-severity findings and requires no database change at all.** If nothing else in this document is adopted, adopt Phase B.

**Phase C — Roles and the session variable.**
- Create `pss_app`, `pss_platform`, `pss_migrator`.
- Add the connection interceptor issuing `SET LOCAL app.current_company_id`.
- Ship it with **no policies enabled**. Nothing changes behaviourally; the plumbing gets proven and the `SET LOCAL`/pooling interaction gets load-tested. This de-risks the single most dangerous implementation detail before it can do harm.

**Phase D — Policies, one schema at a time, lowest-traffic first.**
Suggested order: `sett` → `integ` → `notify` → `audit` → `ai` → `finance` → `app`. After each schema, run the full regression suite and watch for "zero rows returned" errors — those are the RLS policy catching a code path that was relying on the fail-open behaviour. **Each one found is a pre-existing cross-tenant read that nobody knew about.** That discovery is a large part of the value.

**Phase E — Audit the bypasses.**
Once RLS holds the line, walk the 439 `IgnoreQueryFilters()` sites. Distribution:

| Area | Count | Assessment |
|---|---|---|
| `OpsBusiness` + `BillingBusiness` | 356 (81%) | Legitimate per house rules — these move to the `pss_platform` role and the call becomes unnecessary |
| `Notify` | 23 | Review — likely the `Scope='PLATFORM'` notification case |
| `Contact` | 19 | **Review carefully** — tenant-scoped domain |
| `Auth` | 12 | Likely legitimate (cross-tenant user lookup) |
| `Setting` | 3 | Review |
| `Shared` | 2 | Review |
| `Donation` | 2 | **Review carefully** — financial data |
| `Application` (root) | 2 | Review |
| `Case` | 1 | **Review carefully** |
| `Infrastructure` | 18 | Review |
| `API/EndPoints` | 1 | Review |

Since there is **no global soft-delete filter** in the codebase (`HasQueryFilter` count in `Base.Infrastructure` is zero), all 439 are genuine *tenant*-filter disables — none are incidentally disabling something else. The ~83 outside `ops`/`billing` are the ones that need eyes. That is a reviewable number.

**Phase F — Raw SQL.**
The 12 raw paths (§3.2c) are automatically covered by RLS once Phase D lands, because they run on the same connection with the same GUC. But `import.fn_get_grid_lookup_values` and `import.fn_get_import_sample_data` should still be inspected: if either is `SECURITY DEFINER`, it runs as its owner and **bypasses RLS**. That is the one way a Postgres function can defeat the boundary, and it must be checked explicitly.

### 7.3 Migrating a tenant from shared to dedicated (Option 4 promotion)

Needed the first time a customer pays for it:
1. Provision the dedicated database, migrate to the tenant's current schema version.
2. Replicate that tenant's rows (logical replication with a row filter, or `pg_dump` with `WHERE CompanyId = N` per table).
3. Set the tenant read-only via a maintenance flag.
4. Final delta sync; verify row counts per table.
5. Flip `DatabaseKey`; invalidate the tenant's cached entitlements and connection resolution.
6. Verify, then soft-delete the source rows after a retention window — never hard-delete on the same day.

Expect hours of downtime for a large tenant on the first attempt. Rehearse against a restored copy before doing it live.

### 7.4 A DI hazard that must be fixed first

```csharp
builder.Host.UseDefaultServiceProvider((context, options) =>
{
    options.ValidateScopes = false;
    options.ValidateOnBuild = false;
});
```
— `Base.API/Program.cs`

The comment blames Carter registering FluentValidation validators as singletons. Whatever the cause, the effect is that **the only automated guard against a singleton capturing a scoped `ITenantContext` or `ApplicationDbContext` is switched off.** A captive dependency here means one tenant's context is served to another, indefinitely, with no error and no log line.

This is not hypothetical: `ITenantContext` is scoped (`Base.Application/DependencyInjection.cs:53`), `IAuditQueue` is a singleton, `OpenExchangeRatesSyncJob` is a singleton, and `AuditQueueDrainer` is a hosted service (effectively singleton). Any one of them acquiring `ITenantContext` by constructor injection would be a permanent cross-tenant leak that scope validation would have caught at startup.

**Fix the validator registration; re-enable both flags.** This is a small, high-value change and it belongs in Phase B.

### 7.5 A latent trap in the query filter

```csharp
var dbContextInstance = Expression.Constant(this);
var currentTenantIdProperty = Expression.Property(dbContextInstance, nameof(CurrentTenantId));
```
— `ApplicationDbContext.cs:97-99`

This bakes a *specific `DbContext` instance* into the compiled model. No `IModelCacheKeyFactory` is registered anywhere, so EF caches that model — including the captured instance — for the process lifetime.

It works today for one reason only: `TenantContext` resolves live from a singleton `IHttpContextAccessor` (AsyncLocal) on every property read, so the captured instance always yields the current request's tenant. But `TenantContext` already holds mutable per-request state (`private int? _effectiveCompanyId`). **The day anyone caches the tenant id in a field on `TenantContext` as an optimisation, this becomes a cross-request tenant leak with no compile error and no test failure.** Add a comment at the capture site saying so, and a test that asserts two concurrent requests with different tenants see different filters.

Under RLS this stops mattering, which is another reason to move the boundary down.

### 7.6 Two more clauses worth flagging

**`|| IsSystem == true`.** The filter appends a third branch for any entity with a boolean `IsSystem` property (`ApplicationDbContext.cs:120-126`), making **any `IsSystem = true` row visible to every tenant**. That is intentional for reference data — `ProvisionTenant.cs:251` relies on it for a shared system role. But if `IsSystem` is ever writable through an API, a tenant can publish its own rows to every other tenant with a single flag flip. Confirm `IsSystem` is not settable through any DTO, mutation, or import mapping, and if it is, remove it from the writable surface.

**No `CompanyId IS NULL` concept.** The filter has no notion of "platform-owned row." That absence is *why* developers reach for `IgnoreQueryFilters()` — the comments in `NotifyBusiness` say so directly. RLS policies should model it explicitly (`CompanyId = current_setting(...) OR (CompanyId IS NULL AND <is platform-readable>)`) so the escape hatch stops being needed.

---

## 8. Backup and Disaster Recovery

| Capability | Shared + RLS | DB per tenant |
|---|---|---|
| Full backup | One `pg_dump` / snapshot | N backups to orchestrate and verify |
| PITR (whole platform) | Native | Native, N times |
| **Restore one tenant to a point in time** | **Hard** — restore to a scratch instance, extract `WHERE CompanyId = N`, reconcile FKs | **Trivial** |
| Cross-tenant consistency | Guaranteed | Not guaranteed across databases |
| Backup verification | 1 restore test | Sampling; you will never test all N |
| Storage cost | Low | High (fixed overhead × N) |

**The single-tenant restore row is the only one where Option 3 clearly wins**, and it wins decisively. It is also the scenario that actually happens: a customer bulk-deletes their own data and wants it back as of Tuesday.

**Recommended answer without splitting databases:** solve it with **tenant-scoped logical backups**, not physical ones. A nightly per-tenant logical export (`WHERE CompanyId = N` across the tenant tables, into per-tenant object storage with its own retention) gives per-tenant restore *and* per-tenant export *and* the offboarding artefact, for a fraction of the cost of N databases. It is slower than a database restore and it needs an FK-ordered import — but it is a bounded engineering task, whereas 1,000 databases is a permanent operational commitment.

Enterprise tenants on Option 4 get true per-database PITR as part of what they pay for. That is a clean tier boundary and an easy thing to sell.

**Targets to set explicitly** (currently undefined): platform RPO/RTO, per-tenant restore RTO, and — the one people forget — the retention period for a *deleted* tenant's data, which is a contractual and GDPR-adjacent commitment, not an ops preference.

---

## 9. Admin and Support Access

### 9.1 Current state

`TenantContext` grants SuperAdmin unrestricted reach:

```csharp
var isSuperAdminClaim = httpContext?.User.Claims.FirstOrDefault(c => c.Type == "IsSuperAdmin")?.Value;
if (isSuperAdminClaim?.Equals("true", StringComparison.OrdinalIgnoreCase) == true)
    return null; // SuperAdmin sees all companies
```

Returning `null` reuses the *same* value as "unknown tenant." Support access and total failure of tenant resolution are therefore indistinguishable at the point where the decision is made, and both produce unfiltered queries. Separating those two meanings (§4.1) is worth doing for this reason alone.

On the positive side, `IPlatformAuditWriter` → `ops.PlatformAuditLog` already exists specifically to record platform-operator actions, and its registration comment shows the distinction was understood. `X-Act-As-Company` impersonation is validated by `TenantAccessBehavior.ValidateCrossCompanyScope`.

### 9.2 Target — break-glass, not standing access

Four properties, in order of importance:

1. **No standing cross-tenant access.** A support engineer's normal token carries no tenant reach. Access is requested, scoped to one tenant, and time-boxed (hours, not days).
2. **Every access is logged before it is granted** — who, which tenant, which ticket, when it expires — to `ops.PlatformAuditLog`, which is append-only and not deletable by the operator.
3. **The tenant can see it.** A support-access log visible in the tenant's own admin UI is the single most effective control here, because it makes misuse discoverable by the party who cares most. It is also a strong trust signal in sales conversations — often a better answer to "is our data safe?" than a database topology.
4. **Read-only by default.** Write access to tenant data is a separate, rarer, more heavily logged grant.

Under RLS this is enforceable rather than aspirational: break-glass sets the GUC to the specific tenant granted. The operator's session is *technically* incapable of touching a tenant outside the grant, rather than merely policy-bound not to. Note that this is a property Option 3 does **not** give you — a platform operator with the connection-string vault has every tenant's database.

### 9.3 On the anonymous surface

`ReceiptDownloadController`, `CertificateController`, `ExportController`, `ReportExportController`, `MediaController`, and `ImportController` have no `[Authorize]`. Combined with blob paths that have no enforced tenant prefix (§4.4), a guessable identifier on any of these is a cross-tenant read that requires no authentication at all. **This should be fixed in the current sprint, independent of every other recommendation in this document.**

---

## 10. Billing and Usage Architecture

`billing` is platform-global and the entitlement layer already exists: `IEntitlementService` (company-keyed cache, ~60s TTL), `IPlanBaselineApplier`, `IPlanMenuFilter` / `IPlanMenuScope`, `IPlanPricingService`, `UsageMeterService`. Design detail lives in `PSS-2.0-PLANS-AND-ENTITLEMENTS-APPROACH.md`.

**Isolation requirements specific to billing:**

- Usage counters carry `CompanyId` and are written on the tenant's connection, so RLS applies. A tenant must never be able to read or influence another's usage — usage is a billing input, and a tampered counter is a financial event.
- `UsageMeterService` uses `ExecuteRawSqlAsync` in three places (lines 32, 49, 84) — presumably atomic counter increments, which is the right technique. Under RLS these need the `WITH CHECK` policy verified for `UPDATE`, since a raw `UPDATE ... SET count = count + 1 WHERE CompanyId = @id` must not be able to name another tenant's id. RLS closes this; today only the parameter value does.
- Plan and feature *definitions* are platform-global and read via `IgnoreQueryFilters()` today. Under RLS they move to the `pss_platform` role or become RLS-exempt reference tables. Note the house rule: `billing.Features` / `FeatureMenuMaps` are **hand-curated**, never generated — the isolation model must not tempt anyone into deriving them from tenant data.
- Under Option 4, dedicated infrastructure is a **billable plan attribute**, which is the clean way to make the enterprise tier real: it appears in `billing.Plans`, provisioning reads it, and Step 1a fires only when it is set.

**One caution.** `MenuFeatureMapService` caches the platform-global map under a single key with a `_generation` counter for invalidation. That is correct today for a single instance. Across N instances, generation counters diverge and tenants see inconsistent menus until TTL expiry. Not a leak — but it becomes a support burden at the same moment horizontal scaling arrives, so it should move to Redis in the same change (§4.3).

---

## 11. AI Security Architecture

The seven rules in §4.6 are the substance. Additional architectural points:

**11.1 Provider isolation.** Per-tenant provider keys are KMS-wrapped via `AzureKeyVaultTenantKeyProvider` (implemented) with `ai.TenantProviderKey` and `ai.TenantProviderPreference`. This is already ahead of most of the codebase and should not be traded away for a shared platform key — a shared key means one tenant's runaway usage exhausts another's rate limit, and one tenant's prompts sit in the same provider-side log as another's.

**11.2 Prompt injection is a tenant-boundary threat, not just a content threat.** A tenant's own uploaded document can contain instructions. If AI output can influence a query, a filter, or a `CompanyId`, that document becomes a cross-tenant attack. The mitigations: model output is never SQL, never a tenant identifier, and never a filter predicate; retrieval scope is derived server-side and cannot be named by the caller or the model; and RLS holds even if all of that fails. Note that **DB-per-tenant does not defend against this** — an injected instruction that makes the application connect elsewhere is exactly as effective as one that changes a `WHERE` clause.

**11.3 Audit.** `ai.AiAuditLog` must record, per call: tenant, user, model, prompt hash, **retrieved document ids**, token counts, and cost. The retrieved-document-ids field is the one that makes cross-tenant retrieval detectable. Without it, an AI leak leaves no trace anywhere — there is no SQL log to inspect, because the leak happened in a vector similarity search.

**11.4 Sequencing.** AIDA is at skeleton stage (`RoutingPolicyEngine`, `AskGridCommandHandler`, and the provider adapters are all skeletons). **Land the RLS boundary before AIDA's retrieval layer is built**, so `pgvector` tables inherit the policy from birth rather than being retrofitted. If the sequence goes the other way, the AI corpus becomes the one part of the system outside the boundary — and it is the part holding the most concentrated, least structured tenant data.

---

## 12. Scaling Strategy

| Tenants | Shared + RLS | DB per tenant |
|---|---|---|
| **100** | One instance, one DB, one pool. Comfortable. | Workable. 100 DBs, 100 migration runs. Manageable but already tedious. |
| **1,000** | Read replicas; Redis instead of `IMemoryCache`; partition the largest tables by `CompanyId`. Standard work. | **The wall.** 1,000 connection pools against one Postgres cluster is not feasible without a proxy layer (PgBouncer/RDS Proxy). Migrations become a distributed job with partial-failure states. Multiple clusters with tenant→cluster routing. |
| **10,000** | Shard by `CompanyId` across a small number of clusters — say 10 clusters × 1,000 tenants. Routing is a lookup; the tenant boundary is still RLS. | Effectively unworkable as a uniform model. Requires tenant→cluster→database routing, thousands of DBs per cluster, and a full migration orchestration platform. |
| **100,000** | Sharded cell architecture. Each cell is a complete stack; tenants are assigned to cells. Well-trodden path. | Not a serious proposal at this size. |

**The connection pool is the binding constraint, and it arrives early.** PSS 2.0 today has one `AddDbContext` with one Npgsql pool (`DependencyInjection.cs:47-59`). Under Option 3, N tenants require N pools, each with a minimum size, each holding idle connections. Postgres `max_connections` is typically in the hundreds. At a few hundred active tenants you need a connection proxy; at a thousand you need several clusters — which means Option 3 does not remove the need for sharding, it just adds per-tenant databases *on top of* sharding.

**The honest scaling summary:** Option 2 scales by sharding tenants across clusters, which is the same thing Option 3 eventually needs, minus the per-tenant database overhead and minus the migration orchestration platform.

**PSS 2.0's actual near-term numbers matter here.** The GTM plan targets self-service signup. If the realistic 24-month horizon is 100-500 tenants, both options work and the decision should be made on engineering cost and time-to-compliance — where Option 2 wins clearly. If the horizon is 5,000+, Option 3 is affirmatively the wrong architecture.

---

## 13. MVP Recommendation

### 13.1 Must have before production

Ordered by severity. Everything here is achievable without a topology change, and items 1-5 are the difference between a fail-open and a fail-closed system.

| # | Item | Files | Effort |
|---|---|---|---|
| 1 | **Remove `catch { return null; }`** from tenant resolution | `TenantContext.cs` | Hours |
| 2 | **Separate "unknown tenant" from "platform-wide"** — a discriminated result, not a shared `null` | `TenantContext.cs`, `ApplicationDbContext.cs` | Days |
| 3 | **`[Authorize]` on the six unprotected controllers**; `.RequireAuthorization()` on `MapGraphQL()`; `FallbackPolicy` on `AddAuthorization()` | `Base.API/DependencyInjection.cs`, 6 controllers | Days |
| 4 | **Re-enable `ValidateScopes` / `ValidateOnBuild`** — fix the Carter/FluentValidation registration that forced them off | `Program.cs` | Days |
| 5 | **Explicit tenant loop for all background jobs**; a job with no tenant scope must fail loudly | `Program.cs` job registrations, `TenantAccessBehavior.cs` | Weeks |
| 6 | **Enforced tenant prefix in blob storage**; reject caller-supplied paths outside it | `AzureBlobFileStorageService.cs` | Days |
| 7 | **RLS on the highest-value schemas** — `finance`, `app`, `sett` at minimum | SQL scripts (user-authored) + one connection interceptor | Weeks |
| 8 | **Confirm `IsSystem` is not writable** through any DTO, mutation, or import mapping | Audit | Days |
| 9 | **Verify the two `import.fn_*` functions are not `SECURITY DEFINER`** | Audit | Hours |
| 10 | **Break-glass support access** — time-boxed, logged to `ops.PlatformAuditLog`, tenant-visible | New | Weeks |

**Items 1-4 alone remove the documented fail-open behaviour and cost roughly two weeks.** They are the highest return on effort available anywhere in this document, and none of them require a decision about database topology. They should not wait for that decision.

### 13.2 Should have

| Item | Rationale |
|---|---|
| RLS on all remaining tenant schemas | Completes the boundary |
| Three-role split (`pss_app` / `pss_platform` / `pss_migrator`) | Makes the 356 `ops`/`billing` bypasses structurally safe rather than conventionally safe |
| Audit the ~83 non-`ops` `IgnoreQueryFilters()` sites | Each is a hand-audited trust boundary today, and nobody has audited them |
| Per-tenant logical backup + restore path | The single-tenant restore capability, without N databases (§8) |
| Redis in place of `IMemoryCache` | Prerequisite for more than one app instance; fixes entitlement/menu invalidation |
| `IModelCacheKeyFactory`, or a comment + test at the `Expression.Constant(this)` capture | Prevents §7.5 from becoming a live leak |
| Startup assertion: every `ITenantEntity` has an RLS policy | Converts the silent-omission failure mode into a startup crash |
| Cross-tenant integration tests in CI | Two tenants, every endpoint, assert zero leakage. The only durable regression guard. |
| Tenant-visible support-access log | Strongest trust signal available, and cheaper than a database split |

The startup assertion deserves emphasis. The current filter's worst property is that omission is **silent** — a new entity without `CompanyId` gets no filter and no warning (§3.2a). An assertion that crashes the application on startup when a tenant table lacks a policy converts the entire class of "someone forgot" from a data breach into a failed deployment. That is a very good trade.

### 13.3 Future enterprise enhancements

| Item | Trigger |
|---|---|
| **Option 4 dedicated database** (`DatabaseKey` + connection resolver + provisioning steps 1a/1b) | First customer contractually requires it, or first regulated vertical |
| Per-tenant encryption keys (CMK) | Same trigger |
| Regional data residency | First EU/UK customer with a residency clause |
| Tenant→cluster sharding | ~1,000 tenants |
| Cell-based architecture | ~10,000 tenants |
| Dedicated compute per enterprise tenant | Noisy-neighbour complaints from a large customer |
| `pgvector` retrieval with per-tenant partitioning | When AIDA retrieval ships at scale |

### 13.4 What to tell management

Four sentences.

> The isolation concern is legitimate and the audit found real gaps — including background jobs that currently read across all tenants and a tenant-resolution path that shows all data when it fails. Database-per-tenant would fix about half of those gaps, cost several months of structural work because we have one shared `ApplicationDbContext` and one migration history, and would leave the other half — authorization, AI retrieval, caching, file storage — untouched. PostgreSQL Row-Level Security closes more of them, in weeks rather than months, and enforces the boundary *below* every line of application code, where no developer can bypass it. We will build the dedicated-database path as a paid enterprise tier so that customers who require physical separation get it, and we will get the compliance and sales story without making all 1,000 tenants pay the operational cost of it.

### 13.5 The principle underneath

The brief asked not to sacrifice fundamental data isolation for development convenience, and not to over-engineer. Those pull in opposite directions only if the boundary is in the wrong place.

Today PSS 2.0's boundary is in application code, where it is both weak *and* inconvenient — 439 explicit bypasses, 12 raw-SQL paths around it, and a `catch` block that disables it entirely. Moving the boundary into the database makes it simultaneously stronger and less intrusive: developers stop thinking about tenancy because the database will not let them get it wrong.

Physical separation is a legitimate product feature for customers who require it. It is a poor substitute for a boundary that fails closed.

---

## Appendix A — Evidence index

| Finding | File | Detail |
|---|---|---|
| Fail-open query filter | `Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs:104-117` | `CurrentTenantId == null \|\| CompanyId == CurrentTenantId` |
| Filter only where `CompanyId` exists | same, `:79-81` | Reflection; silent omission |
| `SetQueryFilter` replaces | same, `:48` after `:45` | Config-level filters overwritten |
| `IsSystem` global visibility | same, `:120-126` | Third `OrElse` branch |
| Instance captured in cached model | same, `:97-99` | `Expression.Constant(this)`, no `IModelCacheKeyFactory` |
| Raw-SQL escape hatch | same, `:135` | `ExecuteRawSqlAsync`, 8 callers in `Base.Application` |
| Exception ⇒ null tenant | `Base.Application/Services/TenantContext/TenantContext.cs` | `catch { return null; }` |
| SuperAdmin ⇒ null tenant | same | Same value as "unknown" |
| Act-as header unvalidated at read | same | `GetActAsCompanyId()` |
| Background jobs unfiltered | `Base.Application/Behaviors/TenantAccessBehavior.cs:26-37` | Documented in the code |
| Authorization opt-in | `Base.Application/Security/AuthorizationBehavior.cs` | No attribute ⇒ `next()` |
| RBAC coverage is broad | `Base.Application/Business` | `CustomAuthorize` in 1,827 files |
| No fallback auth policy | `Base.API/DependencyInjection.cs` | Bare `AddAuthorization()` |
| GraphQL unauthenticated by default | same | `MapGraphQL()` with no `.RequireAuthorization()` |
| Six controllers without `[Authorize]` | `Base.API/Controller/` | Media, ReceiptDownload, Export, ReportExport, Import, Certificate |
| Scope validation disabled | `Base.API/Program.cs` | `ValidateScopes = false`, `ValidateOnBuild = false` |
| Eight recurring jobs, no HTTP context | same | Import recovery, PayU, staging sweep, renewal, event comms, retention, email retry |
| One connection string, one context | `Base.Infrastructure/DependencyInjection.cs:32,47-65` | `ISettingDbContext` → same scoped instance |
| One migration history table | same, `:34-39` | Mandatory `Migrations:HistoryTableName` |
| Search shares the connection | same, `:149` | `AddSearchEngine(connectionString!)` |
| Write-side platform-scope guard | `Base.Infrastructure/Data/Interceptors/TenantSaveChangesInterceptor.cs:69-81` | The model to follow |
| `CompanyId` first-assignment allowed | same, `:97-119` | Required by provisioning Step 1 |
| Raw connection, no tenant predicate | `Base.Infrastructure/Services/Import/LookupService.cs:29-40` | `import.fn_get_grid_lookup_values` |
| Same pattern | `Base.Infrastructure/Services/Import/TemplateGeneratorService.cs:72-79` | `import.fn_get_import_sample_data` |
| Unused cache dependency | `LookupService.cs:14-20` | `IMemoryCache` injected, never assigned |
| Raw SQL in staging | `Base.Infrastructure/Services/Import/StagingTableService.cs:112,137,163` | String-built INSERT, binary COPY |
| No tenant prefix in blob path | `.../FileStorageServices/AzureBlobFileStorageService.cs` | `Path.Combine(request.Directory, newFileName)` |
| Correct cache scoping | `Base.Infrastructure/Services/Billing/EntitlementService.cs` | `CacheKey(int companyId)` |
| Correct global cache | `Base.Infrastructure/Services/Billing/MenuFeatureMapService.cs` | Platform-global by design |
| 9-step idempotent provisioning | `Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs` | Resume, self-heal, per-step transaction |
| Provisioning sends no email | same, `:270-273` | Renamed from `SEND_WELCOME` |
| Platform audit writer exists | `Base.Infrastructure/DependencyInjection.cs:127-131` | `ops.PlatformAuditLog` |
| Host→tenant resolution | `Base.Infrastructure/Services/Auth/HostTenantResolver.cs` | Deliberately uncached |
| AI is greenfield | `Services/Base/AIDA-MODULE-README.md`, `docs/AI-Platform-Architecture.md` | No vector store, no RAG, adapters are skeletons |
| `IgnoreQueryFilters()` distribution | `Base.Application/Business` (420), `Base.Infrastructure` (18), `Base.API/EndPoints` (1) | 439 total; 356 in `ops`/`billing` |
| No global soft-delete filter | `Base.Infrastructure` | `HasQueryFilter` count = 0 — all 439 are tenant-filter disables |
| Documented claim under review | `PSS_2.0_Backend/PeopleServe/MULTI_TENANCY_GUIDE.md` | "Complete data isolation … secure by default" — contradicted by the above |

## Appendix B — Open items requiring verification

1. Are `import.fn_get_grid_lookup_values` and `import.fn_get_import_sample_data` `SECURITY DEFINER`? If so they bypass RLS and are the one Postgres-level hole in the plan.
2. Does `AddSearchEngine` open its own connection, or use the shared one? Determines whether RLS covers search automatically.
3. Is `IsSystem` writable through any DTO, GraphQL mutation, or import column mapping?
4. Do any singletons construct-inject `ITenantContext` or `IApplicationDbContext` today? (Re-enabling `ValidateScopes` answers this in one run.)
5. How many rows across tenant tables have `CompanyId IS NULL` or `= 0`? Blocks RLS until zero or explicitly policy-handled.
6. What is the realistic 24-month tenant count? Below ~500, Option 2 is clearly right; above ~5,000, the sharding plan in §12 becomes the near-term priority rather than a future item.
