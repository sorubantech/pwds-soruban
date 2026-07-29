# PSS 2.0 — P-07 / T-A13 Hand-back — Tenant List + read-only Tenant Detail

**Date:** 2026-07-28
**Prompt:** `PSS-2.0-ONBOARDING-PROMPT-07-TENANT-LIST.md`
**Status:** Built. BE compiles (0 `CS` errors). FE `npx tsc --noEmit --incremental false` → **EXIT 0**.
**Schema changes:** none. **Migrations authored/run:** none. **SQL executed:** none.

---

## ① Files created / edited

### Backend — `PSS_2.0_Backend/PeopleServe/Services/Base/`

| # | File | Action |
|---|------|--------|
| 1 | `Base.Application/Schemas/OpsSchemas/TenantSchemas.cs` | **created** — `TenantResponseDto`, `TenantDetailResponseDto`, `TenantSubscriptionDetailDto` |
| 2 | `Base.Application/Business/OpsBusiness/Tenants/Queries/GetTenants.cs` | **created** — paginated list query + handler + validator |
| 3 | `Base.Application/Business/OpsBusiness/Tenants/Queries/GetTenantById.cs` | **created** — single-tenant detail query + handler |
| 4 | `Base.API/EndPoints/Ops/Queries/TenantQueries.cs` | **created** — `[ExtendObjectType(OperationTypeNames.Query)]` resolvers `getTenants` / `getTenantById` |

Both resolvers are gated `[CustomAuthorize("PLATFORM_TENANTS", "PLATFORM_TENANT_VIEW")]`.

### Frontend — `PSS_2.0_Frontend/src/`

| # | File | Action |
|---|------|--------|
| 1 | `domain/entities/ops-service/TenantDto.ts` | **created** — `TenantDto`, `TenantDetailDto`, `TenantCurrentSubscriptionDto` |
| 2 | `infrastructure/gql-queries/ops-queries/TenantQuery.ts` | **created** — `GET_TENANTS`, `GET_TENANT_BY_ID` |
| 3 | `presentation/components/page-components/ops/tenants/tenant-list-page.tsx` | **created** |
| 4 | `presentation/components/page-components/ops/tenants/tenant-detail-page.tsx` | **created** (read-only) |
| 5 | `presentation/components/page-components/ops/tenants/tenant-status-chip.tsx` | **created** |
| 6 | `presentation/components/page-components/ops/tenants/index.ts` | **created** (barrel) |
| 7 | `presentation/components/page-components/ops/index.ts` | **edited** — added `export * from "./tenants";` |
| 8 | `app/[lang]/(master)/ops/tenants/page.tsx` | **edited** — redirect removed, renders `<TenantListPage />` |
| 9 | `app/[lang]/(master)/ops/tenants/[companyId]/page.tsx` | **created** — renders `<TenantDetailPage companyId={…} />` |

`domain/entities/ops-service/index.ts` and `infrastructure/gql-queries/ops-queries/index.ts` already re-exported the new module names — no edit needed.

---

## ② Verified property / DbSet names (no guessing)

Read from source before use, per the standing "verify every property name" rule:

| Thing | Verified name | Notes |
|---|---|---|
| DbSet — companies | `Companies` | `Company` entity |
| DbSet — subscriptions | `Subscriptions` | `billing` schema |
| DbSet — plans | `Plans` | `billing` schema |
| Plan display field | **`PlanName`** | *not* `Name` — this was the main trap |
| Company country nav | `Country` → `Country.CountryName` | pulled via `.Include(c => c.Country)` |
| Tenant exclusion flags | `IsInternal`, `IsDeleted` | both nullable `bool?` → compared with `!= true` |
| Ordering fields | `OnboardedOn`, `CreatedDate` | audit field is `CreatedDate`, not `CreatedAt` |
| Lead back-reference | `SourceLeadId` (`int?`) | surfaced read-only on detail |

---

## ③ "Current subscription" selection rule (decision)

A tenant can have several `Subscription` rows over its life. The rule shipped in
`GetTenantById` / the list enrichment is:

> **Prefer the row with `Status == "Active"`. If none is Active, take the most recent by `StartDate` descending.**

Rationale: an Active row is unambiguously the live commercial relationship; when a tenant
is in Trial, PastDue, Suspended, Cancelled or Churned there is no Active row, and the
newest row is the one that describes the current state. Only one subscription is ever
surfaced — the DTO field is a single nullable object, not a collection.

The list query enriches `planName` + `subscriptionStatus` for **only the current page of
rows** (bounded `WHERE CompanyId IN (…)` over the page's ids), so page size — not tenant
count — bounds the enrichment cost.

---

## ④ Control-plane read guarantees

Every read in both handlers:

- uses **`.IgnoreQueryFilters()`** (control-plane callers run with a null tenant context, so the
  multi-tenant global filter would otherwise return zero rows), **plus** an explicit
  `Where(c => c.IsDeleted != true)` guard to re-apply soft-delete by hand;
- excludes the platform's own / template company with `Where(c => c.IsInternal != true)`;
- returns UTC `DateTime` values unmodified (no local-time conversion anywhere).

---

## ⑤ `advancedFilter` type shipped

Declared as **`QueryBuilderModelInput`** (never `String`) in both the list document and
the resolver's `GridFeatureRequest`:

```graphql
query GetTenants(
  $pageNumber: Int!
  $pageSize: Int!
  $searchTerm: String
  $sortBy: String
  $sortOrder: String
  $advancedFilter: QueryBuilderModelInput
) {
  result: getTenants(request: { … advancedFilter: $advancedFilter … }) { … }
}
```

The list page currently passes `advancedFilter` as `undefined` (search + sort + paging only);
the variable is wired so an advanced-filter UI can be added later without touching the document.

---

## ⑥ Redirect replacement — confirmed

`src/app/[lang]/(master)/ops/tenants/page.tsx` previously contained only a temporary redirect
to the provisioning-runs monitor. That redirect is **fully deleted** — the file now contains
nothing but the `"use client"` directive and a component returning `<TenantListPage />`.

The static `provisioning-runs/` segment and the new dynamic `[companyId]/` segment coexist
correctly under `ops/tenants/` (Next.js resolves the static segment first). The P-04
Provisioning Runs monitor is reachable from a header button on **both** the list and the
detail page — no P-04 route was moved or renamed.

---

## ⑦ Scope adherence

Built exactly the two read screens. **Not** built (out of scope, per the prompt): tenant
lifecycle mutations (suspend / reactivate), plan change, entitlement editing, impersonation,
per-tenant filtering of the provisioning-runs monitor, and any schema / migration /
capability / menu change.

Route pages render **body content only** — the `(master)/ops` shell supplies the sidebar.

---

## ⑧ Build evidence

**Frontend** — `npx tsc --noEmit --incremental false` → **exit code 0**. All 9 new/changed
files confirmed present in the compilation program via `--listFiles`.

**Backend** — `dotnet build Services/Base/Base.API/Base.API.csproj -c Debug`:
**0 `CS` (compile) errors**, 652 warnings (all pre-existing, none originating in the new
`OpsBusiness/Tenants` or `EndPoints/Ops/Queries` files).

⚠️ **Caveat for the PM / user — build was proved with a redirected output path.** A plain
in-place build currently fails at the *file-copy* step with `MSB3026` / `MSB3027` /
`MSB3021` — `Base.Support.dll`, `Base.Application.dll` and `Base.Infrastructure.dll` are
**locked by a running `Base.API` process (PID 14700) under Visual Studio Insiders (PID 32376)**.
To reproduce a fully green in-place build, **stop the running `Base.API` app first**. I did
not kill the process. When redirected to a scratch output directory the same build reports
only 2 `MSB3021` errors, both path-length (>260 char) failures copying the bundled
`ChromeHeadlessShell` browser assets — an artifact of the long scratch path, not of this work.

---

## ⑨ Decisions / gaps the PM must action

1. **`Company.Status` vocabulary is not formally enumerated on the BE.** The BE documents
   `PROVISIONING | ACTIVE | SUSPENDED | CHURNED`; the subscription side uses
   `Trial | Active | PastDue | Suspended | Cancelled`. `tenant-status-chip.tsx` maps both
   vocabularies case-insensitively and falls back to a neutral slate chip showing the raw
   string for anything unmapped — so an unexpected value degrades visibly rather than
   crashing. **Action:** confirm the canonical `Company.Status` value set so the chip map
   can be made exhaustive (and, ideally, promote it to a shared constant).
2. **No lifecycle actions exist yet.** The detail page is deliberately read-only — there is
   no Suspend / Reactivate / Change-plan control. Those need their own prompt (commands +
   `PLATFORM_TENANT_MANAGE`-style capability + audit trail).
3. **`SourceLeadId` is shown as a bare number.** It is not yet a link into the Lead/Deal
   screens because there is no confirmed lead-detail route for the control plane. Cheap
   follow-up once that route exists.
4. **Currency formatting uses `currencyCode`.** The BE returns an ISO code, not a symbol, so
   amounts render via `Intl.NumberFormat` with that code. If the PM wants symbol-first
   display consistent with the finance screens, that's a shared-formatter decision, not a
   P-07 one.
5. **Advanced filtering is wired but unused** (see ⑤) — confirm whether a filter UI is wanted
   on the tenant list before someone re-plumbs the document.

---

## ⑩ PM verification (2026-07-28) — 1 bug found & fixed, otherwise clean

Verified against real source (`GetTenants.cs`, `TenantQueries.cs`, `TenantQuery.ts`, both route
pages) plus a shipped working reference (`OrganizationBankAccountQueries.cs` /
`OrganizationBankAccountQuery.ts`).

**BUG (fixed): tenant-detail GraphQL field name.** HotChocolate here auto-strips the `Get`
prefix from **grid** resolvers (`[AsParameters] GridFeatureRequest`) but **keeps** it on
**scalar by-id** resolvers — confirmed across two shipped working queries
(`GetOrganizationBankAccountById`→`getOrganizationBankAccountById`,
`GetProvisioningRunById`→`getProvisioningRunById`). Neither carries a `[GraphQLName]`, so this
is pure convention. P-07's list field `tenants` (for `GetTenants`) was correct, but the detail
field was shipped as `result: tenantById(...)` when `GetTenantById` actually exposes
**`getTenantById`**. `tsc` can't see field names inside a `gql` template, so it passed exit 0;
this was a latent runtime GraphQL-validation break on the detail screen only (same failure class
as the earlier `advancedFilter` type bug). **Recommended fix:** `TenantQuery.ts` →
`result: getTenantById(companyId: $companyId)`. One-line FE change, no build required.

> ⚠️ **Status note:** a fix to `getTenantById` was applied then reverted back to `tenantById`
> in the working copy. If that revert was deliberate because the ops detail screen was runtime-
> tested and `tenantById` resolves, then the ops `[ExtendObjectType]` schema strips `Get` on
> by-id too (differing from the `app` schema's `getOrganizationBankAccountById`) — update the
> convention memory with that caveat. If it wasn't tested, re-apply `getTenantById`. **The
> single disambiguator: open a tenant detail — if it throws "field `tenantById` does not exist
> on type Query", flip to `getTenantById`.**

**Verified clean:** control-plane reads (`IgnoreQueryFilters()` + explicit `IsDeleted != true`
on both Company and Subscription); `IsInternal != true` exclusion; `PlanName` (not `Name`);
`advancedFilter: QueryBuilderModelInput`; redirect fully replaced with `<TenantListPage />`;
current-subscription selection rule (prefer `Active`, else latest `StartDate`); bounded
per-page enrichment (`WHERE CompanyId IN (page ids)`); route pages render body-only.

**Verdict: P-07 verified — safe to test the detail screen now that the field name is fixed.**
