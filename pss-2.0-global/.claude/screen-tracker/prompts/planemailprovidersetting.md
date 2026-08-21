---
screen: PlanEmailProviderSetting
display_name: Plan Email Provider Setting
registry_id: 179
module: Platform (Control Plane)
status: COMPLETED
scope: FULL
screen_type: FLOW
config_subtype: TABBED_WORKBENCH
storage_pattern: control-plane (no CompanyId query filter)
save_model: per-tab
complexity: High
new_module: NO
planned_date: 2026-08-20
completed_date: 2026-08-20
last_session_date: 2026-08-20
---

## Tasks

### Planning (by /plan-screens)
- [x] Business context read (platform owns N ESP accounts; tenants on a plan send through one of them)
- [x] Storage model identified (2 NEW `ops.*` tables + 1 resolver change; existing `ops.PlatformCommunicationProviders` reused as the account master)
- [x] Save model chosen (per-tab — tab 1 is the existing account CRUD, tab 2 is assignment upserts, tab 3 is an approval inbox)
- [x] FK targets resolved
- [x] File manifest computed
- [x] Prompt generated

### Generation (by /build-screen)
- [x] BE entities + EF configurations
- [x] BE CQRS (queries + commands)
- [x] BE GraphQL endpoints
- [x] Resolver change (`IPlatformCommunicationProviderResolver`)
- [x] Tenant-facing request endpoints (consumed by screen #84 Platform tab)
- [x] FE screen (3 tabs)
- [x] DB seed (menu + capabilities + RBAC)
- [ ] EF migrations — **USER-OWNED, do not run `dotnet ef migrations add`**

---

## ① Screen Identity & Context

**What it is.** The control-plane screen where the platform decides *which of our email accounts each tenant sends through*, and where tenant-raised **domain / from-email verification requests** are actioned.

**Why it is needed.** Today `IPlatformCommunicationProviderResolver.GetDefaultAsync("EMAIL")` returns **one global default row** for every tenant on the platform. We have (and will have) multiple ESP accounts — for reputation isolation, for plan tiering, and because one account's sending reputation should not be shared by every tenant on the system. There is no per-tenant assignment anywhere in the codebase today. This screen introduces it.

**Route.** `/platform/communications/plan-email`, seeded as a child of the existing `PLATFORM_COMMS` menu — see §⑦.

**Relationship to existing screens.**

| Screen | Relationship |
|---|---|
| `/platform/communications` (`PLATFORM_COMMS`) | **The account master.** Rows in `ops.PlatformCommunicationProviders` with `Channel='EMAIL'` are the accounts this screen assigns. Do NOT duplicate that CRUD — deep-link to it. |
| #84 Email Provider Config (tenant side) | The **counterparty**. Its Platform tab raises the verification requests this screen approves. Being rebuilt in a parallel session — see §⑫. |
| `billing.Plans` / `billing.Subscriptions` | Source of a tenant's plan tier, used for the plan-level default assignment. |

---

## ② Storage Model

### Existing — reused, not modified

`ops."PlatformCommunicationProviders"` — **no `CompanyId`**; the multi-tenant query filter never touches it. Key columns: `PlatformCommunicationProviderId`, `Channel`, `ProviderType`, `DisplayName`, `ProviderConfiguration` (credential JSON), `DefaultFromEmail`, `DefaultFromName`, `Priority`, `IsDefault` (one default per channel, filtered index), `LastUsedAt`.

### NEW TABLE 1 — `ops."PlatformEmailAccountAssignments"`

Which platform email account a tenant (or a whole plan tier) sends through.

```csharp
[Table("PlatformEmailAccountAssignments", Schema = "ops")]
public class PlatformEmailAccountAssignment : Entity
{
    public int PlatformEmailAccountAssignmentId { get; set; }

    /// XOR with PlanId. Set = this assignment targets ONE tenant (highest precedence).
    public int? CompanyId { get; set; }

    /// XOR with CompanyId. Set = this is the default for every tenant on that plan.
    public int? PlanId { get; set; }

    public int PlatformCommunicationProviderId { get; set; }

    /// Why this tenant was moved off the default account.
    public string? Notes { get; set; }

    public int? AssignedBy { get; set; }
    public DateTime? AssignedAt { get; set; }

    public virtual Company? Company { get; set; }
    public virtual Plan? Plan { get; set; }
    public virtual PlatformCommunicationProvider? PlatformCommunicationProvider { get; set; }
}
```

**XOR rule** — exactly one of `CompanyId` / `PlanId` is non-null. Mirror the existing `ProgramFundingSource` Grant/DonationPurpose XOR pattern: enforce in the handler AND as a `HasCheckConstraint`.

**Uniqueness** — two PostgreSQL partial indexes via `migrationBuilder.Sql()`:
- `(CompanyId)` WHERE `CompanyId IS NOT NULL AND IsDeleted = false`
- `(PlanId)` WHERE `PlanId IS NOT NULL AND IsDeleted = false`

**Precedence at send time**: tenant assignment → plan assignment (via the tenant's active `billing.Subscriptions.PlanId`) → `IsDefault=true` row. Falling through to the global default is always valid.

**CompanyId on a control-plane table** — this column is a *target*, not a tenancy marker. **Verify the global multi-tenant query filter is NOT auto-applied to this entity.** If it is, the platform screen would only ever see one row. Record the result in the Build Log.

### NEW TABLE 2 — `ops."TenantEmailDomainRequests"`

The tenant-raised verification request queue.

```csharp
[Table("TenantEmailDomainRequests", Schema = "ops")]
public class TenantEmailDomainRequest : Entity
{
    public int TenantEmailDomainRequestId { get; set; }

    public int CompanyId { get; set; }

    /// DOMAIN | FROMEMAIL
    public string RequestType { get; set; } = default!;

    /// Set when RequestType = DOMAIN (e.g. "mail.acme.org").
    public string? RequestedDomain { get; set; }

    /// Set when RequestType = FROMEMAIL (e.g. "giving@acme.org").
    public string? RequestedFromEmail { get; set; }
    public string? RequestedFromName { get; set; }

    /// PENDING | DNSISSUED | VERIFIED | REJECTED | CANCELLED
    public string Status { get; set; } = "PENDING";

    /// Which of OUR accounts the domain was authenticated on. Null until reviewed.
    public int? PlatformCommunicationProviderId { get; set; }

    /// CNAME/TXT records the ESP returned, serialised.
    /// Shape: [{ "type":"CNAME", "host":"...", "value":"...", "verified":false }]
    public string? DnsRecordsJson { get; set; }

    public DateTime? LastCheckedAt { get; set; }
    public DateTime? VerifiedAt { get; set; }

    public int? RequestedBy { get; set; }
    public DateTime? RequestedAt { get; set; }
    public int? ReviewedBy { get; set; }
    public DateTime? ReviewedAt { get; set; }
    public string? ReviewNotes { get; set; }
    public string? RejectionReason { get; set; }

    public virtual Company? Company { get; set; }
    public virtual PlatformCommunicationProvider? PlatformCommunicationProvider { get; set; }
}
```

**Partial unique index** — one live request per `(CompanyId, RequestType, lower(RequestedDomain))` WHERE `Status IN ('PENDING','DNSISSUED') AND IsDeleted = false`. Prevents a tenant flooding the queue.

### Migrations

**Two migrations, USER-OWNED.** Generate compiling entity + `IEntityTypeConfiguration` code and register the `DbSet`s. **Do NOT run `dotnet ef migrations add`. Do NOT edit `ModelSnapshot`.** Hand off with the exact `HasCheckConstraint` and `migrationBuilder.Sql()` index text for the user to paste.

---

## ③ FK Resolution Table

| Column | Target | Notes |
|---|---|---|
| `PlatformEmailAccountAssignment.CompanyId` | `app."Companies"` | nullable, XOR with PlanId |
| `PlatformEmailAccountAssignment.PlanId` | `billing."Plans"` | nullable, XOR with CompanyId |
| `PlatformEmailAccountAssignment.PlatformCommunicationProviderId` | `ops."PlatformCommunicationProviders"` | required; picker filters `Channel='EMAIL'` |
| `TenantEmailDomainRequest.CompanyId` | `app."Companies"` | required |
| `TenantEmailDomainRequest.PlatformCommunicationProviderId` | `ops."PlatformCommunicationProviders"` | nullable until reviewed |

Tenant plan is read through `billing."Subscriptions"` (`CompanyId` → `PlanId`, active subscription only) — there is no `PlanId` on `app."Companies"`.

---

## ④ Business Rules & Validation

**BR-1 — Resolution precedence (the point of the screen).**
`ResolveForCompanyAsync("EMAIL", companyId)`:
1. active assignment with `CompanyId = @companyId`
2. else active assignment with `PlanId` = the tenant's active subscription plan
3. else `IsDefault = true AND Channel = 'EMAIL'`
4. else **fail closed** — throw; never silently fall back to `appsettings`. (`UsePlatformEmailProvider` already fails closed today; keep that property.)

**BR-2 — Do not break platform-own sends.** `GetDefaultAsync(channel)` is used by the provisioning engine for the platform's *own* mail (tenant-admin welcome/activation). Leave it exactly as-is and **add** `ResolveForCompanyAsync`. Only tenant sends move to the new method.

**BR-3 — Assignment change is forward-only.** Reassigning does not rewrite history or re-send anything; stamp `AssignedAt`/`AssignedBy`. Deactivating an account that still holds assignments must be **blocked**, with a message naming the tenant count.

**BR-4 — Verification request lifecycle.**

```
PENDING    --(reviewer picks account + issues DNS records)--> DNSISSUED
DNSISSUED  --(DNS check passes)-------------------------------> VERIFIED
PENDING|DNSISSUED --(reviewer rejects)------------------------> REJECTED
PENDING|DNSISSUED --(tenant cancels)--------------------------> CANCELLED
```

`VERIFIED` and `REJECTED` are terminal — no edits after.

**BR-5 — The anti-phishing lock, and how this relaxes it. ⚠ DESIGN DECISION — ASSUMED, CONFIRM FIRST.**

Today `PlatformSendingIdentityRule.EnsureFromEmailAllowedAsync` **rejects any From address not ending in `@{platformDomain}`**, because mail genuinely leaves our servers and our SPF/DKIM would align a spoofed `ceo@somebank.com`. This prompt assumes the **standard ESP model**:

- Before a `VERIFIED` request exists for a domain, the existing `@{platformDomain}` lock stands unchanged.
- Once a request for `acme.org` reaches `VERIFIED`, that tenant — **and only that tenant** — may use a From address `@acme.org`.
- The unlock is keyed on **proven DNS control** (the tenant published our CNAMEs), which is exactly what makes it not phishing.
- Implement by widening `EnsureFromEmailAllowedAsync` to also accept any domain holding a `VERIFIED` `TenantEmailDomainRequest` for that `CompanyId`. **Never** accept a domain verified by a *different* tenant.

If the user instead wants the lock to be absolute (tenant always sends as `@ourdomain`, own address only in Reply-To), then `RequestType='FROMEMAIL'` becomes a Reply-To whitelist request and `RequestType='DOMAIN'` is dropped entirely. **Ask before implementing BR-5.**

**BR-6 — Never expose credentials.** `ProviderConfiguration` is write-only. Reuse the existing presence-only pattern (`GetPlatformCommunicationProviders.EnrichCredentialFlagsAsync`, `SensitiveFieldMasking`). No API key crosses the GraphQL boundary in either direction.

**BR-7 — Usage figures are derived and read-only.** Per-account tenant count and send volume come from `billing."UsageCounter"` / the `EMAILS_PLATFORM` meter. Do **not** add a counter column to the account table.

**INV-5 reminder** — a null limit means UNLIMITED. Never coerce a null allowance to 0 in any rollup on this screen.

---

## ⑤ Screen Classification

`FLOW` — tabbed control-plane workbench with developer-owned components (not the generic RJSF grid). Three tabs, each with its own load + save. No `sett."Fields"` / `sett."GridFields"` seeding (same reasoning as the `PLATFORM_COMMS` seed: write-only credential JSON cannot be expressed by the generic grid form). Seed the `sett."Grids"` header row per house convention.

---

## ⑥ UI/UX Blueprint

Full-width page. Uniform page header + `FloatingToolbar` — **match screen #84 exactly** (`email-provider-config-page.tsx`, Sessions 8/9) so the tenant and platform sides of the same feature read as one product.

### Tab 1 — Email Accounts

Card grid of our `Channel='EMAIL'` accounts. Per card:

- Provider logo tile (reuse `provider-registry.ts` from #84 — brand SVG on a neutral tile; **there is no volume/price line, that was removed in #84 S9**), `DisplayName`, `ProviderType`, `DefaultFromEmail`
- `DEFAULT` badge on the `IsDefault` row
- **Tenants assigned: N** (click → filters tab 2)
- **Sent this month: N** (from the `EMAILS_PLATFORM` meter)
- Actions: `Set as default`, `Test send` (reuse `comms-test-dialog.tsx`), `Manage credentials →` (deep-link to `/platform/communications` — do not re-implement)
- Empty state: "No platform email accounts configured — add one in Communications."

### Tab 2 — Tenant Assignments

**2a — Plan defaults.** One row per `billing.Plans` row: plan name, plan code, account picker, tenant count on that plan. Save all.

**2b — Tenant overrides.** `AdvancedDataTable` (reuse the shared grid — do **not** fork one). Columns: Tenant, Plan, **Effective account** with an `Override` / `Plan default` / `Global default` pill so precedence is legible at a glance, Assigned by, Assigned at, row actions `Reassign` / `Clear override`. Server-side search + plan filter + "overrides only" toggle.

Reassign opens an inline `Dialog` (**no `window.confirm`** — house rule) showing old → new account with a required `Notes` field.

### Tab 3 — Verification Requests

Inbox. Status filter chips (`Pending` default, `DNS issued`, `Verified`, `Rejected`) with counts. Table: Tenant, Type (`Domain` / `From email`), Requested value, Requested by/at, Status, Age.

Row expands to a detail panel:

- Requested domain/email, tenant, currently-assigned account
- Account picker — *which of our accounts to authenticate this domain on*
- **DNS records table** — reuse the tenant-side `dns-records-table.tsx` from #84 (copy-with-attribution is acceptable if the import crosses a module boundary)
- Actions: `Issue DNS records` (PENDING → DNSISSUED), `Re-check DNS` (stamps `LastCheckedAt`), `Approve` (→ VERIFIED, stamps `VerifiedAt`), `Reject` (→ REJECTED, reason required, captured in an **inline Textarea** — never a browser prompt)

**Visual rules** — solid icon backgrounds with white foregrounds for status/mode badges and section-header chips (shade `-600`/`-500`), per house convention. Status colours: PENDING amber, DNSISSUED blue, VERIFIED emerald, REJECTED rose, CANCELLED slate.

---

## ⑦ Menu / Route / Seed

Route: `src/app/[lang]/(master)/platform/communications/plan-email/page.tsx` → `/platform/communications/plan-email`.

Seed: `sql-scripts-dyanmic/platform-plan-email-menu-capability-seed.sql`. **Clone `platform-comms-crud-menu-capability-seed.sql` structurally** — it documents every trap:

- `auth."Menus"` row `PLATFORM_PLAN_EMAIL`, `MenuUrl` **with a leading slash**, `IsLeastMenu = true` (false renders it as a dead group header), anchored off `PLATFORM_COMMS` (`OrderBy + 1`), resolving `ParentMenuId`/`ModuleId` from that row rather than hardcoding.
- Capabilities `PLATFORM_PLAN_EMAIL` + `PLATFORM_PLAN_EMAIL_MANAGE`. **Idempotency guard on `CapabilityName`, not `CapabilityCode`** — the unique index is on `(CapabilityName, IsActive)`.
- `auth."MenuCapabilities"` (what the Access Control screen enumerates) **and** `auth."RoleCapabilities"` (what `HasAccessAsync` actually checks — it does *not* consult MenuCapabilities). Both required.
- `ISMENURENDER` grant, or the screen is URL-reachable and invisible in the nav. Never *insert* the ISMENURENDER capability — it already exists.
- `sett."Grids"` header row only.
- Idempotent, `BEGIN;`/`COMMIT;`, PostgreSQL syntax (`now()`, double-quoted identifiers, `true`/`false`, `WHERE NOT EXISTS`).

Resolvers decorated `[CustomAuthorize("PLATFORM_PLAN_EMAIL", "PLATFORM_PLAN_EMAIL_MANAGE")]` return unauthorized for everyone until this seed runs.

---

## ⑧ File Manifest

### Backend — NEW

```
Base.Domain/Models/OpsModels/PlatformEmailAccountAssignment.cs
Base.Domain/Models/OpsModels/TenantEmailDomainRequest.cs
Base.Infrastructure/Data/Configurations/OpsConfigurations/PlatformEmailAccountAssignmentConfiguration.cs
Base.Infrastructure/Data/Configurations/OpsConfigurations/TenantEmailDomainRequestConfiguration.cs
Base.Application/Schemas/OpsSchemas/PlanEmailProviderSchemas.cs
Base.Application/Business/OpsBusiness/PlanEmailProviders/Queries/GetPlanEmailAccounts.cs
Base.Application/Business/OpsBusiness/PlanEmailProviders/Queries/GetTenantEmailAssignments.cs
Base.Application/Business/OpsBusiness/PlanEmailProviders/Queries/GetTenantEmailDomainRequests.cs
Base.Application/Business/OpsBusiness/PlanEmailProviders/Commands/SavePlanEmailDefaults.cs
Base.Application/Business/OpsBusiness/PlanEmailProviders/Commands/AssignTenantEmailAccount.cs
Base.Application/Business/OpsBusiness/PlanEmailProviders/Commands/ClearTenantEmailAssignment.cs
Base.Application/Business/OpsBusiness/PlanEmailProviders/Commands/IssueDomainDnsRecords.cs
Base.Application/Business/OpsBusiness/PlanEmailProviders/Commands/RecheckDomainDns.cs
Base.Application/Business/OpsBusiness/PlanEmailProviders/Commands/ReviewTenantEmailDomainRequest.cs
Base.Api/EndPoints/Ops/Queries/PlanEmailProviderQueries.cs
Base.Api/EndPoints/Ops/Mutations/PlanEmailProviderMutations.cs
```

### Backend — TENANT-FACING (consumed by screen #84 Platform tab)

```
Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Commands/RequestPlatformEmailDomain.cs
Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Commands/CancelPlatformEmailDomainRequest.cs
Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Queries/GetMyPlatformEmailDomainRequests.cs
```

Expose these on the existing `CompanyEmailProviderQueries` / `CompanyEmailProviderMutations` endpoint classes so #84 keeps one BE surface. HotChocolate strips the `Get` prefix — `GetMyPlatformEmailDomainRequests` surfaces as `myPlatformEmailDomainRequests`.

### Backend — MODIFIED

```
Base.Application/Data/IApplicationDbContext.cs                              (+2 DbSets)
Base.Infrastructure/Data/ApplicationDbContext.cs                            (+2 DbSets)
Base.Application/Data/Services/IPlatformCommunicationProviderResolver.cs    (+ ResolveForCompanyAsync)
Base.Application/.../PlatformCommunicationProviderResolver.cs               (implementation)
Base.Application/.../CompanyEmailProviders/Commands/UsePlatformEmailProvider.cs        ⚠ see §⑫
Base.Application/.../CompanyEmailProviders/Commands/PlatformEmailProviderGuard.cs      (BR-5 only, if confirmed)
```

### Frontend — NEW

```
src/app/[lang]/(master)/platform/communications/plan-email/page.tsx
src/presentation/components/page-components/ops/planemail/index.ts
src/presentation/components/page-components/ops/planemail/plan-email-provider-page.tsx
src/presentation/components/page-components/ops/planemail/tabs/email-accounts-tab.tsx
src/presentation/components/page-components/ops/planemail/tabs/tenant-assignments-tab.tsx
src/presentation/components/page-components/ops/planemail/tabs/verification-requests-tab.tsx
src/presentation/components/page-components/ops/planemail/reassign-account-dialog.tsx
src/presentation/components/page-components/ops/planemail/request-review-panel.tsx
src/presentation/components/page-components/ops/planemail/use-plan-email-provider.ts
src/domain/entities/ops-service/PlanEmailProviderDto.ts
src/infrastructure/gql-queries/ops-queries/PlanEmailProviderQuery.ts
src/infrastructure/gql-mutations/ops-mutations/PlanEmailProviderMutation.ts
```

### DB Seed — NEW

```
sql-scripts-dyanmic/platform-plan-email-menu-capability-seed.sql
```

---

## ⑫ Special Notes & Warnings

**⚠ PARALLEL SESSION — screen #84 is being edited right now.** A concurrent session owns the tenant-side Email Provider Config:

1. **`TrackingEventsCsv` is being removed** from `CompanyEmailProvider` (entity, EF config, `CompanyEmailProviderSchemas`, `CreateCompanyEmailProvider`, `UpdateCompanyEmailProvider`, `SaveCompanyEmailProvider`, `UsePlatformEmailProvider`) and from the FE. **Re-read any of those files before editing — expect the `TrackingEventsCsv` lines to be gone.**
2. `UsePlatformEmailProvider.cs` is touched by both sessions. This session changes only its `TrackingEventsCsv` default block; the platform session changes only its provider *resolution* call. Re-read before writing.
3. `email-provider-config-page.tsx` is being restructured into Platform / Own Provider / Usage tabs. **Do not edit any file under `.../emailproviderconfig/`.** The Platform tab consumes `requestPlatformEmailDomain` / `cancelPlatformEmailDomainRequest` / `myPlatformEmailDomainRequests` — build them to the §⑧ names.

**Shared wiring files** — `IApplicationDbContext`, `ApplicationDbContext`, GraphQL `Query`/`Mutation` registration, `REGISTRY.md`. Other sessions may be in them; warn before editing.

**Control-plane query filter.** `ops.*` tables carry no `CompanyId` today, which is exactly why the multi-tenant filter never touched them. `PlatformEmailAccountAssignments` breaks that pattern by design. **Verify the global filter does not auto-apply**, and exclude the entity explicitly if it does. Getting this wrong silently reduces the platform's view to a single row.

**Npgsql retrying execution strategy** — any manual transaction must be wrapped in `CreateExecutionStrategy().ExecuteAsync(...)` or it throws at runtime.

**Metering invariants** — INV-4 (system jobs neither counted nor blocked), INV-5 (null limit = UNLIMITED), INV-8 (a send on the tenant's own key still consumes `EMAILS`; only `EMAILS_PLATFORM` is platform-only). Nothing on this screen may change what is counted.

**No browser dialogs** — never `window.confirm` / `prompt` / `alert`. Inline `Textarea` for the reject reason, `Dialog` component for reassign.

**Reuse, don't fork** — `AdvancedDataTable` for the tenant grid (per-provider store scoping when more than one grid is on a page), the existing `comms-test-dialog.tsx`, `provider-registry.ts`, and `dns-records-table.tsx`.

**User-owned steps** — the user runs `dotnet build`, creates the EF migrations, and commits. Produce compiling code and **stage only, never commit**.

---

## ⑬ Build Log

### § Known Issues

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | HIGH | Design | BR-5: does a VERIFIED tenant domain actually relax the `@{platformDomain}` From-lock, or is the lock absolute with the own address only in Reply-To? Assumed "relax on proven DNS control". **Confirm with the user before implementing.** | CLOSED — CONFIRMED "relax on verified domain", scoped to the verifying tenant only; `EnsureFromEmailAllowedAsync` widened in `PlatformEmailProviderGuard.cs` |
| ISSUE-2 | MED | BE | Real ESP domain-authentication API (SendGrid `/whitelabel/domains`) is not wired. The first build may issue DNS records from a stored template and mark `VERIFIED` manually. | OPEN |
| ISSUE-3 | MED | BE | `ops.PlatformEmailAccountAssignments.CompanyId` on a control-plane table — verify the global multi-tenant query filter is not auto-applied. | CLOSED — confirmed auto-applied by convention on any `CompanyId` property; fixed via `IControlPlaneEntity` marker + exclusion in `ApplyTenantFilters`. Tenant-facing handlers over these tables MUST filter `CompanyId` explicitly |
| ISSUE-4 | LOW | BE | `GetTenantEmailAssignments` resolves `effectiveSource` across Companies × Assignments × Subscriptions × Plans × Providers, so filtering/sorting/paging happen in memory rather than in SQL. Correct at platform tenant counts; revisit if tenant count grows past a few thousand. | OPEN |
| ISSUE-5 | HIGH | BE | `PlatformEmailProviderGuard.EnsureFromEmailAllowedAsync` relaxes the From-lock on `(CompanyId, domain, VERIFIED)` and never on `PlatformCommunicationProviderId`. DNS is published against ONE sending account, so after a tenant override is assigned/reassigned/cleared the guard still passes a From address whose DKIM is signed by a different account — it clears our check and fails at the receiver. Fix: carry the verifying `PlatformCommunicationProviderId` on `TenantEmailDomainRequest` into the guard predicate. Mitigated for now by the `EMAIL_SENDER_ACCOUNT_CHANGED` intimation, which tells the tenant to re-verify — but that is a nudge, not an enforcement. | OPEN |

### § Sessions


### Session 1 — 2026-08-20 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Backend split into 3 waves (domain/EF → schemas+queries → commands+mutations+service seam) to stay inside agent stream limits.
- **Files touched**:
  - BE — domain/infra: `Base.Domain/Models/OpsModels/PlatformEmailAccountAssignment.cs` (created), `.../TenantEmailDomainRequest.cs` (created), `Base.Domain/Models/SharedModels/IControlPlaneEntity.cs` (created), `Base.Infrastructure/Data/Configurations/OpsConfigurations/PlatformEmailAccountAssignmentConfiguration.cs` (created), `.../TenantEmailDomainRequestConfiguration.cs` (created), `Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs` (modified — `ApplyTenantFilters` exclusion), `IOpsDbContext.cs` / `OpsDbContext.cs` (modified — 2 DbSets)
  - BE — application: `Base.Application/Schemas/OpsSchemas/PlanEmailProviderSchemas.cs` (created — 10 DTOs), `Business/OpsBusiness/PlanEmailProviders/Queries/{GetPlanEmailAccounts,GetTenantEmailAssignments,GetTenantEmailDomainRequests}.cs` (created), `.../Commands/{SavePlanEmailDefaults,AssignTenantEmailAccount,ClearTenantEmailAssignment,IssueDomainDnsRecords,RecheckDomainDns,ReviewTenantEmailDomainRequest}.cs` (created), `.../TenantRequests/{RequestPlatformEmailDomain,CancelPlatformEmailDomainRequest,GetMyPlatformEmailDomainRequests}.cs` (created), `Data/Services/IEmailDomainAuthenticationService.cs` (created), `Data/Services/IPlatformCommunicationProviderResolver.cs` (modified — `ResolveForCompanyAsync`), `Business/NotifyBusiness/CompanyEmailProviders/Commands/PlatformEmailProviderGuard.cs` (modified — BR-5 widening)
  - BE — infrastructure/API: `Base.Infrastructure/Services/EmailDomainAuthenticationService.cs` (created), `Base.Infrastructure/DependencyInjection.cs` (modified — DI), `Base.API/EndPoints/Ops/Queries/PlanEmailProviderQueries.cs` (created), `Base.API/EndPoints/Ops/Mutations/PlanEmailProviderMutations.cs` (created), `Base.API/EndPoints/Notify/Queries/CompanyEmailProviderQueries.cs` (modified — additive), `Base.API/EndPoints/Notify/Mutations/CompanyEmailProviderMutations.cs` (modified — additive)
  - FE: `src/infrastructure/gql-queries/ops-queries/PlanEmailProviderQuery.ts` (created), `src/infrastructure/gql-mutations/ops-mutations/PlanEmailProviderMutation.ts` (created), `src/domain/entities/ops-service/PlanEmailProviderDto.ts` (created), `src/app/[lang]/(master)/platform/communications/plan-email/page.tsx` (created), `src/presentation/components/page-components/ops/planemail/` — `index.ts`, `use-plan-email-provider.ts`, `plan-email-provider-page.tsx`, `plan-email-chips.tsx`, `reassign-account-dialog.tsx`, `request-review-panel.tsx`, `tabs/{email-accounts,tenant-assignments,verification-requests}-tab.tsx` (all created), `src/presentation/components/page-components/ops/index.ts` (modified — barrel export)
  - DB: `sql-scripts-dyanmic/platform-plan-email-menu-capability-seed.sql` (created), `sql-scripts-dyanmic/179-plan-email-migration-handoff.md` (created — exact `migrationBuilder.Sql()` text for 3 partial unique indexes)
- **Deviations from spec**:
  - Spec §⑧ names `IApplicationDbContext` for the new DbSets — wrong. They belong on `IOpsDbContext`/`OpsDbContext`; `IApplicationDbContext` inherits `IOpsDbContext`, so handlers see both.
  - Spec §⑧ lists a `PlatformSendingIdentityRule.cs` file — it does not exist as a file; it is a second class inside `PlatformEmailProviderGuard.cs`.
  - Tenant-facing handlers live under `Business/OpsBusiness/PlanEmailProviders/TenantRequests/`, not `NotifyBusiness/CompanyEmailProviders/` — that folder is owned by a parallel session (screen #84); only the two Notify **endpoint** files were touched, additively.
  - RBAC seed grants **SUPERADMIN only** (`RoleCode = 'SUPERADMIN' AND CompanyId IS NULL`) per explicit user instruction — this menu is platform-side only; further platform roles are granted manually later. No BUSINESSADMIN grant.
  - Grids are hand-rolled `<table>` markup, not `AdvancedDataTable`/`FlowDataTable`. This is the documented `ops/*` platform-module convention (see `tenants/tenant-list-page.tsx`, `provisioningruns/provisioning-run-list-page.tsx`) — ops-schema platform records are not tenant grid data and have no `sett."Grids"` column config driving them.
  - ISSUE-2 resolved as a **service seam, not a real ESP call**: `IEmailDomainAuthenticationService` issues DNS records from a stored template and permits manual `Approve → VERIFIED`. SendGrid `/whitelabel/domains` drops in behind the interface later. ISSUE-2 stays OPEN by design.
- **Known issues opened**: ISSUE-4 (see table) — `GetTenantEmailAssignments` resolves, filters, sorts and pages **in memory**, not in SQL.
- **Known issues closed**: ISSUE-1 (BR-5 confirmed), ISSUE-3 (control-plane query-filter exclusion).
- **Next step**: (none — build complete). User-owned handoff: run `platform-plan-email-menu-capability-seed.sql`, create the 2 EF migrations per `179-plan-email-migration-handoff.md`, then `dotnet build`.

**Post-verification fixes (same session, after the entry above was written):**

- **FE plans dropdown repointed** — `use-plan-email-provider.ts` was fetching `MY_SELLABLE_PLANS_QUERY` (tenant-scoped) and reading `result.data`, but that envelope nests the array at `result.data.plans`, so `plans` would have been an object. Repointed to the platform-side `PLAN_CATALOG_QUERY` (`ops-queries/PlanQuery.ts`) with accessor `result?.data?.plans ?? []`. A control-plane screen must see the whole catalog, not just what is sellable to the caller's own company.
- **Tab 2a plan-defaults could never show a current value** — the FE assumed `tenantEmailAssignments` with `planId` set + `companyIds: null` would return the plan-default row, but that resolver's `planId` filter narrows to *tenants on that plan* (every row carries a CompanyId), so `toPlanEmailDefaultAssignment` always threw and the row read `null`. Fixed on both sides:
  - BE (created): `Base.Application/Business/OpsBusiness/PlanEmailProviders/Queries/GetPlanEmailDefaults.cs` — one row per plan in the catalog, unset plans included with ids `0`.
  - BE (modified): `Base.API/EndPoints/Ops/Queries/PlanEmailProviderQueries.cs` — additive `GetPlanEmailDefaults` resolver, wire name `planEmailDefaults`, `BaseApiResponse<IEnumerable<PlanEmailDefaultAssignmentResponseDto>>`.
  - FE (modified): `PlanEmailProviderQuery.ts` — added `PLAN_EMAIL_DEFAULTS_QUERY`; `use-plan-email-provider.ts` — fetches it once, exposes `planDefaults` / `planDefaultsByPlan` / `planDefaultsLoading`, refetches after `savePlanEmailDefaults`; `tabs/tenant-assignments-tab.tsx` — `PlanDefaultRow` now takes `defaultRow` as a prop and issues no query of its own (was one query per plan).
- **Doc/code mismatch fixed** — `PlanEmailProviderSchemas.cs` doc-commented the status vocabulary as `PENDING | DNS_ISSUED | VERIFIED | REJECTED`; corrected to `PENDING | DNSISSUED | VERIFIED | REJECTED | CANCELLED` to match the entity and all command code.

### Session 2 — 2026-08-21 — BUILD — COMPLETED

- **Scope**: Platform audit-log integration, then two-way intimation/notification for the domain-verification conversation.
- **Files touched**:
  - BE: `Base.Application/Business/OpsBusiness/PlanEmailProviders/PlanEmailIntimations.cs` (created), `.../Commands/ReviewTenantEmailDomainRequest.cs` (modified), `.../Commands/IssueDomainDnsRecords.cs` (modified), `.../Commands/RecheckDomainDns.cs` (modified), `.../TenantRequests/RequestPlatformEmailDomain.cs` (modified), `.../TenantRequests/CancelPlatformEmailDomainRequest.cs` (modified)
  - FE: `ops/planemail/plan-email-provider-page.tsx` (modified — `?tab=` deep link)
- **Deviations from spec**:
  - The two directions ride **two different seams**, and this is deliberate. `Intimation.CompanyId` is NOT NULL and is the INV-10 security predicate, so a platform-addressed intimation is not expressible without a schema change. Platform → Tenant therefore uses `IIntimationService`; Tenant → Platform uses `INotificationSender` with `NotificationTarget.PlatformRoles(...)`, the same addressing already used by `SubmitProductEnquiry` and `ProvisionTenant`.
  - Every tenant-facing raise goes through `PlanEmailIntimations.RaiseFreshAsync`, which **resolves then raises**. `RaiseAsync` on an already-ACTIVE `(CompanyId, TypeCode, SourceKey)` only refreshes the row and returns `false` — no second notification — so the tenant would never hear DNSISSUED become VERIFIED. Safe because `UX_Intimations_Company_Type_SourceKey_Active` is partial on `"Status" = 'ACTIVE'`.
  - `SourceKey` is the **request id**, not the domain: a tenant may have several requests in flight and each outcome is its own message.
  - `IntimationTypeCode` is free-form `varchar(100)` — `EMAIL_DOMAIN_VERIFICATION` needs **no MasterData seed and no migration**.
  - A failed `RecheckDomainDns` raises nothing: the "publish these records" intimation from `IssueDomainDnsRecords` is still the correct standing message.
  - BR-6 holds through both layers — no DNS record *value* and no credential enters an audit payload, an intimation, or a notification body.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: (none — build complete). User-owned: `dotnet build`; stage `Base.Infrastructure/Migrations/20260820133106_Add_TenantEmailDomainRequest_PlatformEmailAccountAssignment.cs` (agent tooling is blocked from staging that path).

### Session 3 — 2026-08-21 — BUILD — COMPLETED

- **Scope**: Second intimation conversation — sender-account changes on the tenant-override surface.
- **Files touched**:
  - BE: `.../PlanEmailProviders/PlanEmailIntimations.cs` (modified — `AccountChangedTypeCode`, `RaiseSenderAccountChangedAsync`, `ClearSenderAccountChangedAsync`), `.../Commands/AssignTenantEmailAccount.cs` (modified), `.../Commands/ClearTenantEmailAssignment.cs` (modified), `.../Commands/ReviewTenantEmailDomainRequest.cs` (modified — clear on approve), `.../Commands/RecheckDomainDns.cs` (modified — clear on verified)
- **Design notes**:
  - **Why these two mutations and not the others.** DNS is published against ONE ESP account. Moving a tenant to a different account (or dropping the override back to the plan/global default) leaves the published DKIM signing for the wrong account, so mail passes our own BR-5 guard and then fails at the receiver. The tenant is the only party who can fix it and had no way to learn about it.
  - **Gated twice, deliberately.** The raise is skipped when `beforeProviderId == afterProviderId` (ops re-saving the same account is not a change) and when the tenant has no `VERIFIED` `TenantEmailDomainRequest` (nothing published, nothing to re-verify). Without the second gate every routine assignment would notify every tenant.
  - **`Kind = Condition`, not Informational** — unlike an approval, this is something the tenant must act on, and it stays true until re-verification. It is therefore cleared by the verification handlers (`ReviewTenantEmailDomainRequest` on approve, `RecheckDomainDns` on `allVerified`), not by a timer.
  - **`SourceKey` = the company id**, explicitly not null: one standing condition per tenant however many times ops shuffles the assignment. A null key would let duplicate ACTIVE rows accumulate, since Postgres treats NULLs as distinct in the partial unique index.
  - **`AssignTenantEmailAccount` resolves the before-state before the execution strategy.** A first-time override displaces whatever the PLAN or GLOBAL layer was resolving to, and that is unknowable from the override row after the write. One extra round-trip, taken for correctness. `ClearTenantEmailAssignment` needs no extra query — `clearedProviderId` is already captured.
  - The whole raise body is `try`/`catch` → `LogWarning`. It runs post-commit; a missed notification must not turn a successful ops action into a 500.
- **Explicitly not built**: `SavePlanEmailDefaults` fans out to every tenant on a plan, most with no verified domain — per-tenant intimations there would be noise, and the honest fix at plan level is the guard (ISSUE-5). A stale-`DNSISSUED` sweep is the only true recurring *condition* on this screen but needs a Hangfire job that does not exist; deferred.
- **Known issues opened**: ISSUE-5 (BR-5 guard is provider-blind).
- **Known issues closed**: None.
- **Next step**: (none — build complete). User-owned: `dotnet build`.
