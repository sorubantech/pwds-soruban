# DEV PROMPT P-07 — Tenant List (`/ops/tenants`) + read-only Tenant Detail

> Paste everything below the line into a **fresh development session**. It is self-contained.
> When done, report back the outcome to the PM session. This is a standalone control-plane screen; it does **not** start any later prompt.

---

## Role & mission

You are a Senior Full-Stack Developer on the PSS 2.0 multi-tenant .NET + Next.js platform (**backend target framework `net10.0`**). Your task is **P-07: build the tenant hub — `/ops/tenants` — the operational list of provisioned tenant companies**, and a **read-only tenant detail** view.

Today the seeded `PLATFORM_TENANTS` menu points at `/ops/tenants`, but no screen exists there — a temporary FE **redirect** page currently forwards to `/ops/tenants/provisioning-runs` (the P-04 run monitor). This prompt **replaces that redirect with the real tenant list**, and wires navigation *from* the list *to* the monitor. After this, the "Tenants" menu resolves natively — no DB / seed change is needed at all.

Concretely, one task:

1. **T-A13 — Tenant List + Detail (control-plane, read-only MVP).**
   - **BE:** a paginated `GetTenants` query (list of provisioned companies) + a `GetTenantById` query (single company profile + its current subscription/plan). Both control-plane, gated `PLATFORM_TENANT_VIEW`.
   - **FE:** the `/ops/tenants` list screen (replacing the redirect page), a read-only `/ops/tenants/[companyId]` detail screen, and a header action that opens the existing **Provisioning Runs** monitor.

The `ops`/`billing` schemas, the `Company` entity, the `Subscription`/`Plan` billing layer, the `PLATFORM_*` RBAC seed, the `(master)` control-plane shell, and the P-04 run monitor **already exist and compile**. You are adding a read-only query + two screens on top of them.

> ⚠️ **Read-only MVP by design.** Suspend / reactivate, plan changes, entitlement editing, and impersonation are explicitly **out of scope** (see *Out of scope* below). Do not add lifecycle mutations or new capabilities.

## Read first (grounding — do not skip)

1. `PSS-2.0-ONBOARDING-P04-HANDBACK.md` — the P-04 monitor is the screen you mirror and navigate to. Note especially **§2 item 5** (the seeded `PLATFORM_TENANTS` menu URL is `/ops/tenants`, and the tenant list "is not implemented — later-prompt scope" — **that scope is this prompt**), and **§2 item 3** (`GridFeatureRequest` has no server-side status predicate — so per-tenant run filtering is *not* available; your row→runs deep-link is deferred, see *Out of scope*).
2. `PSS-2.0-GTM-LEAD-ONBOARDING-AND-PRODUCT-ADMIN-APPROACH.md` — **§11** (control-plane security model; menu-vs-capability warning). `/ops/tenants` is a **control-plane** screen on the `(master)` surface, gated by `PLATFORM_*`, **not** a tenant screen.
3. `PSS-2.0-ONBOARDING-DQ7-PLATFORM-ROLES-MAP.md` — which `PLATFORM_*` roles may **view** tenants (`PLATFORM_TENANT_VIEW`). The seed already created the menu/capability/roles — you **consume** them, you do not re-seed.
4. **The real files you mirror — read each before writing (paths + why below).** Do not assume any property name; open the file. Audit fields are `CreatedDate`/`ModifiedDate` (from the `Entity` base), never `createdAt`/`modifiedAt`.

## Hard constraints (violating any of these fails the task)

- 🔒 **Migrations are strictly user-owned.** Do **NOT** run `dotnet ef migrations add`, `database update`, or `remove`, and do **NOT** hand-author a migration or model-snapshot file. **This prompt needs no schema change** — it is a read-only query + two screens over tables that already exist. If you believe a column is missing, **stop and produce a migration spec (markdown) for the user** instead of adding it.
- **All PKs/FKs are `int` identity.** `Company.CompanyId`, `Subscription.SubscriptionId`, `Plan.PlanId` are all `int`. The one system-wide exception is `Module.ModuleId` (Guid). Introduce no new Guid keys.
- **🔑 Control-plane / null-tenant context.** The caller is a platform user whose `CurrentTenantId == null`, so the **global tenant query filter would silently return zero `Company` rows**. Every read here **MUST use `.IgnoreQueryFilters()` + an explicit `IsDeleted != true` guard**, exactly as the P-04 `GetProvisioningRuns` handler does. This applies to `Company`, `Subscription`, and `Plan` reads alike.
- **🧭 Exclude the platform's own / template company.** `Company.IsInternal == true` marks the internal / template company (the provisioning template + the platform operator's own row). The tenant list shows **real provisioned tenants only** → filter `Where(c => c.IsInternal != true && c.IsDeleted != true)`. Confirm the flag's meaning by reading `Company.cs` before relying on it.
- **📐 `advancedFilter` GraphQL variable type — do NOT get this wrong.** In the FE query document, the grid filter variable **must** be declared `$advancedFilter: QueryBuilderModelInput` (an input object), **never** `String`. P-04's provisioning query shipped it as `String` and HotChocolate rejected the whole query at validation time (`variable 'advancedFilter' is not compatible ... QueryBuilderModelInput`). Copy the variable block from a *working* grid query (e.g. `application-queries/OrganizationBankAccountQuery.ts` or `BranchQuery.ts`), not from the provisioning query.
- **🖼️ The `(master)/ops` shell already renders the sidebar.** `src/app/[lang]/(master)/ops/layout.tsx` mounts `RoleCapabilityProvider` + `DashBoardLayoutProvider` (Header + Sidebar). Your route pages render **body content only** — do **not** add another shell/sidebar, and do **not** wrap the page in `min-h-screen` full-bleed that fights the shell's content area.
- **UTC only.** Every date column is `timestamp with time zone`; any date you construct is `DateTime.UtcNow` / `DateTimeKind.Utc`. Npgsql throws on `Kind=Unspecified`. (This screen is read-only, so this mainly affects any date-range filter you add.)
- **Verify every property name before you use it.** Read the entity/DTO first. Confirm the `IApplicationDbContext` DbSet names (`Companies`? `Subscriptions`?) and the `Plan` display field (`Name`? `PlanName`?) by opening the files — do not guess.
- **BUSINESSADMIN** role only for tenant context; on the control-plane screen, gate purely on `PLATFORM_TENANT_VIEW` — no extra permission re-prompting.

## Codebase anchors (study these, then follow them)

### BE — query pattern (mirror P-04's tenant-provisioning read side)
- **`Base.Application/Business/OpsBusiness/TenantProvisioning/Queries/GetProvisioningRuns.cs`** — the canonical control-plane list handler. Copy its shape exactly:
  - `[CustomAuthorize("PLATFORM_TENANTS","PLATFORM_TENANT_VIEW")]` on the query **record**.
  - `record GetTenantsQuery(GridFeatureRequest gridFilterRequest) : IQuery<GetTenantsResult>`.
  - Validator extends `BaseQueryFluentValidator<…>`, `ValidSortColumns = PropertyNameHelper.GetPropertyNames<TenantResponseDto>()`, `ValidateGridFeatures(x => x.gridFilterRequest, ValidSortColumns)`.
  - Handler: `dbContext.Companies.IgnoreQueryFilters().AsNoTracking().Where(c => c.IsInternal != true && c.IsDeleted != true)`, `.Include(c => c.Country)`, order newest-first (`OrderByDescending(c => c.OnboardedOn ?? c.CreatedDate)`), then `CommonExtension.ApplyGridFeatures<Company, TenantResponseDto>(baseQuery, filteredQuery, request, ct)`.
  - **Search term** over `CompanyName` / `CompanyCode` / `Subdomain` (mirror the `searchTerm?.ToLower()` block).
  - **Plan enrichment (bounded, per-page):** after `ApplyGridFeatures`, take the page's `CompanyId`s and do **one** lookup into `Subscriptions` (`IgnoreQueryFilters()`, `IsDeleted != true`) `.Include(s => s.Plan)` to resolve each tenant's **current** plan name + subscription status, then stamp the DTO rows — exactly as `GetProvisioningRuns` enriches `StepsSucceeded`/`CompanyName`. Pick the current subscription deterministically (e.g. latest `StartDate`, or `Status == "ACTIVE"`); document the rule you chose.
- **`Base.API/EndPoints/Ops/Queries/TenantProvisioningQueries.cs`** — the endpoint shape. Add a sibling **`Base.API/EndPoints/Ops/Queries/TenantQueries.cs`** (`[ExtendObjectType(OperationTypeNames.Query)] public class TenantQueries : IQueries`):
  - **List** — `Task<PaginatedApiResponse<IEnumerable<TenantResponseDto>>> GetTenants([Service] IMediator mediator, [AsParameters] GridFeatureRequest request, CancellationToken ct)` → `ApiResponseHelper.ReturnPaginatedApiResponse(...)` / `…Error<TenantResponseDto>()`.
  - **By-id** — `Task<BaseApiResponse<TenantDetailResponseDto>> GetTenantById([Service] IMediator mediator, int companyId, CancellationToken ct)` → `ApiResponseHelper.ReturnObjectApiResponse(...)`.
- Put the new handlers under **`Base.Application/Business/OpsBusiness/Tenants/Queries/`** (`GetTenants.cs`, `GetTenantById.cs`).

### The entities you read (verified — use these exact fields; still open each file)
- **`Base.Domain/Models/ApplicationModels/Company.cs`** — `CompanyId int`, `CompanyCode string`, `CompanyName string`, `ShortName string?`, `Subdomain string?`, `CustomDomain string?`, `Status string?`, `IsInternal bool`, `OnboardedOn DateTime?`, `SourceLeadId int?`, `CountryId int` + `Country` nav, `PrimaryEmail string?`, `PrimaryPhone string?`, `RegistrationNumber string?`, plus `Entity` base (`CreatedDate`, `ModifiedDate`, `IsDeleted`). **`CompanyId`/`SubscriptionId`/`PlanId` are `int`.**
- **`Base.Domain/Models/BillingModels/Subscription.cs`** — `SubscriptionId int`, `CompanyId int`, `PlanId int`, `Status string`, `StartDate`, `CurrentPeriodStart/End`, `Amount decimal?`, `BillingCycle string?`, `CurrencyId int?` + `Currency` nav, `Plan` nav. Use for the detail's "current plan / billing" panel and the list's plan column.
- **`Base.Domain/Models/BillingModels/Plan.cs`** — open it to confirm the plan **display field name** (do not assume `Name`).

### FE — the control-plane screen files you mirror (all built in P-04)
- **DTO:** `src/domain/entities/ops-service/TenantProvisioningDto.ts` → add/create `src/domain/entities/ops-service/TenantDto.ts` (`TenantListItemDto`, `TenantDetailDto`).
- **Query:** `src/infrastructure/gql-queries/ops-queries/TenantProvisioningQuery.ts` → create `src/infrastructure/gql-queries/ops-queries/TenantQuery.ts` — **but type `$advancedFilter: QueryBuilderModelInput`** (see the hard constraint; the provisioning query is the *bad* example for this one line).
- **Capability hook:** `src/presentation/hooks/usePlatformCapabilities/index.ts` — reuse it to read `PLATFORM_TENANT_VIEW`. Do **not** route `PLATFORM_*` through `useCapablities`/`useAccessCapability` (P-04 §2 item 4: they only serve the closed business-capability allow-list).
- **Components:** `src/presentation/components/page-components/ops/provisioningruns/` (`provisioning-run-list-page.tsx`, `run-status-chip.tsx`) → mirror into `src/presentation/components/page-components/ops/tenants/` (`tenant-list-page.tsx`, `tenant-detail-page.tsx`, `tenant-status-chip.tsx`).
- **Routes:**
  - **Replace** `src/app/[lang]/(master)/ops/tenants/page.tsx` (currently the redirect) with the tenant **list**.
  - **Add** `src/app/[lang]/(master)/ops/tenants/[companyId]/page.tsx` for the read-only **detail**. (Next.js resolves the static `provisioning-runs/` segment before the dynamic `[companyId]/` at the same level, so they coexist safely — verify the folder layout.)

## Scope — build exactly this

### T-A13 · BE — Tenant queries (read-only, control-plane)

1. **`GetTenantsQuery`** — paginated list of provisioned tenants. `TenantResponseDto` carries: `CompanyId`, `CompanyCode`, `CompanyName`, `Subdomain`, `CustomDomain`, `Status` (company status), `CountryName` (via `Country` nav), `OnboardedOn`, `CreatedDate`, and the enriched `PlanName` + `SubscriptionStatus` (nullable — a tenant may have no subscription yet → show as "—"/"No plan" on the FE). Gate `PLATFORM_TENANT_VIEW`. Newest-first. Search over name/code/subdomain.
2. **`GetTenantByIdQuery(int companyId)`** — single tenant profile for the detail screen. `TenantDetailResponseDto` carries the company profile fields (name, code, short name, subdomain, custom domain, status, country, primary email/phone, registration number, onboarded-on, source lead id) **plus** a nested current-subscription block (plan name, subscription status, billing cycle, amount, currency, current period start/end). `IgnoreQueryFilters()` + `IsDeleted != true`; 404 (empty `BaseApiResponse`) if not found or `IsInternal`.

No mutations. No new command. No new entity/column/capability/menu.

### T-A13 · FE — Tenant list + detail screens

- **List (`/ops/tenants`)** — a control-plane data grid (mirror the provisioning-run list): columns **Tenant** (name + code), **Subdomain**, **Plan** (`PlanName` or "—"), **Status** (tenant status chip), **Onboarded** (date). Search box; pagination via `GridFeatureRequest`. Row click → `/{lang}/ops/tenants/{companyId}`.
  - **Header action: "Provisioning Runs"** → navigates to `/{lang}/ops/tenants/provisioning-runs` (the existing P-04 monitor). This is the required list→monitor navigation.
  - Empty state ("No tenants provisioned yet") and error state; shaped skeletons while loading; gate the whole screen on `PLATFORM_TENANT_VIEW` (access-denied panel otherwise, mirroring the monitor).
- **Detail (`/ops/tenants/[companyId]`)** — **read-only** profile: an identity panel (name, code, subdomain, custom domain, status, country, contact, registration no., onboarded date) and a **Subscription** panel (plan, subscription status, billing cycle, amount + currency, current period). A back link to the list, and a **"View provisioning runs"** link to `/{lang}/ops/tenants/provisioning-runs`. No edit/save/suspend controls.
- **UI-uniformity rules:** design tokens only (no hex/px); @iconify Phosphor (`ph:`) icons; status chips/badges use **solid `bg-X-600` + `text-white`**; right-align the amount; xs→xl responsive; render body content only (the `(master)/ops` shell supplies Header + Sidebar).
- **FE reuse-or-create:** search the component/screen registries first; reuse the P-04 status-chip / grid / detail-panel patterns; create if missing-and-static; escalate only if missing-and-complex.
- **Delete the redirect** page's redirect logic when you replace `(master)/ops/tenants/page.tsx` with the list (don't leave a dead redirect behind).

## Out of scope (do NOT build — fast-follow prompts)

- **Tenant lifecycle mutations** — suspend / reactivate (`PLATFORM_TENANT_SUSPEND`), plan change (`PLATFORM_PLAN_EDIT`), entitlement editing, impersonation (`PLATFORM_IMPERSONATE`). Read-only MVP only.
- **Per-tenant provisioning-runs filter** — the row→"this tenant's runs" deep-link. `GridFeatureRequest` has no server-side company predicate yet (P-04 §2 item 3); the list links to the **global** monitor for now. Flag it for a later pass.
- **Any schema change / migration / new capability / menu re-seed.**

## Deliverables & hand-back

1. **BE build:** `dotnet build` → **0 Errors** (report warning count). *(The user builds the BE — you prove it compiles; do not run migrations.)*
2. **FE typecheck:** `npx tsc --noEmit --incremental false` → **EXIT 0** (a run that only reports a pre-existing config/stub error checked nothing — only exit 0 counts). Confirm the new files appear in `--listFiles`.
3. **Hand-back doc** `PSS-2.0-ONBOARDING-P07-HANDBACK.md` listing: every file created/edited; the DbSet + `Plan` display-field names you verified; the "current subscription" selection rule you chose; the exact `advancedFilter` type you shipped; confirmation the redirect page was replaced; and any decision/gap the PM must action.
4. **No SQL executed against any DB. No migration authored or run. No entity/column added.** If any of those seem necessary, stop and write a spec instead.
