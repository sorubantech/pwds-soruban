# P-05 Migration Spec — `ops.Leads` + `ops.CommercialTerms`

> **Author/run policy:** migrations are strictly user-owned. This session did **not** run
> `dotnet ef migrations add` / `database update` / `remove` and did **not** hand-author a migration
> or model-snapshot file. The two entities, their EF configurations and the `AppDbContext` DbSets
> compile and map (`dotnet build` exit 0) — author the migration from this spec, run it, commit it.
>
> **Suggested name:** `Add_Ops_Leads_And_CommercialTerms`
>
> **Scope:** two new tables in the existing `ops` schema. **No existing table or column changes.**
> The four "deferred FK" columns that already exist (`ops.TenantProvisioningRuns.LeadId` /
> `.CommercialTermId`, `app.Companies.SourceLeadId`, `billing.Subscriptions.CommercialTermId`) are
> **left as plain nullable ints** — see §4 for the optional integrity hardening.
>
> **Prerequisites:** `com."Countries"` and `com."Currencies"` must exist (they do — both are shipped
> tenant-shared lookups). The `ops` schema already exists (created by the P-03/P-04 provisioning
> migration).
>
> **Seed order after migrating:** run `sql-scripts-dyanmic/ops-platform-rbac-seed.sql` first (it owns
> the `PLATFORM` module, menus, capabilities, roles and grants), then
> `sql-scripts-dyanmic/ops-lead-deal-seed.sql` (platform settings + welcome-email template + the
> COUNTRY/CURRENCY lookup grants). Both are idempotent `INSERT … WHERE NOT EXISTS`.

Both tables carry the `Entity` base audit columns — omitted from the tables below for brevity:

| Column | Type | Null |
|---|---|---|
| `CreatedBy` | `integer` | NULL |
| `CreatedDate` | `timestamp with time zone` | NULL |
| `ModifiedBy` | `integer` | NULL |
| `ModifiedDate` | `timestamp with time zone` | NULL |
| `IsActive` | `boolean` | NULL |
| `IsDeleted` | `boolean` | NULL |

Neither table has a `CompanyId` — both are **platform-global** control-plane records, so the global
tenant query filter does not apply to them. Every read in the application layer still uses
`.IgnoreQueryFilters()` plus an explicit `IsDeleted != true` guard, because platform callers run with
`CurrentTenantId == null`.

---

## 1. New table — `ops."Leads"`

Front-of-funnel sales record. Deliberately thin (no activities, tasks, threads or pipeline stages).
Deletion is **soft only**.

| Column | Type | Null | Notes |
|---|---|---|---|
| `LeadId` | `integer` | NOT NULL | PK, **identity always** |
| `CompanyName` | `character varying(200)` | NOT NULL | |
| `ContactName` | `character varying(150)` | NOT NULL | |
| `ContactEmail` | `character varying(150)` | NOT NULL | |
| `ContactPhone` | `character varying(30)` | NULL | |
| `CountryId` | `integer` | NOT NULL | **FK → com."Countries"(CountryId)** |
| `Source` | `character varying(20)` | NOT NULL | `INBOUND` \| `OUTBOUND` \| `REFERRAL` \| `EVENT` \| `OTHER` |
| `Status` | `character varying(20)` | NOT NULL | `NEW` \| `QUALIFIED` \| `WON` \| `LOST` — only `WON` is provisionable |
| `OwnerUserId` | `integer` | NULL | platform sales owner — **no DB FK** (see §3) |
| `EstimatedPlanCode` | `character varying(50)` | NULL | non-binding; the plan is chosen on the commercial term |
| `Notes` | `character varying(2000)` | NULL | |
| `LostReason` | `character varying(500)` | NULL | required in code when `Status = LOST` |
| `ConvertedCompanyId` | `integer` | NULL | **FK → app."Companies"(CompanyId)**; stamped by the provisioning engine |

**Foreign keys**

| Name | Column → target | On delete |
|---|---|---|
| `FK_Leads_Countries_CountryId` | `CountryId` → `com."Countries"(CountryId)` | **RESTRICT** |
| `FK_Leads_Companies_ConvertedCompanyId` | `ConvertedCompanyId` → `app."Companies"(CompanyId)` | **RESTRICT** |

**Indexes**

| Name | Columns |
|---|---|
| `IX_Leads_Status` | `Status` |
| `IX_Leads_OwnerUserId` | `OwnerUserId` |
| `IX_Leads_ContactEmail` | `ContactEmail` |
| `IX_Leads_CountryId` | `CountryId` (EF adds this automatically for the FK) |
| `IX_Leads_ConvertedCompanyId` | `ConvertedCompanyId` (EF adds this automatically for the FK) |

> There is deliberately **no unique constraint** on `ContactEmail` or `CompanyName` — the same
> organisation may legitimately be worked as more than one lead over time. Duplicate detection is a
> UI/reporting concern, not a database one.

---

## 2. New table — `ops."CommercialTerms"`

The negotiated deal for a lead, carrying the discount-approval workflow
`DRAFT → (discount ≤ threshold ? APPROVED : PENDING_APPROVAL) → APPROVED | REJECTED`.

| Column | Type | Null | Notes |
|---|---|---|---|
| `CommercialTermId` | `integer` | NOT NULL | PK, **identity always** |
| `LeadId` | `integer` | NOT NULL | **FK → ops."Leads"(LeadId)** |
| `PlanCode` | `character varying(50)` | NOT NULL | matches `billing."Plans"."PlanCode"`; plain string (mirrors the `ProvisionTenant` contract) |
| `CurrencyId` | `integer` | NOT NULL | **FK → com."Currencies"(CurrencyId)** — an int FK, never an ISO string |
| `BillingCycle` | `character varying(20)` | NOT NULL | `Monthly` \| `Annual` |
| `ListAmount` | `numeric(18,2)` | NOT NULL | **snapshot VALUE** resolved server-side from `IPlanPricingService`, never an FK to a mutable price row |
| `DiscountPercent` | `numeric(5,2)` | NOT NULL | 0–100 — the only price input the client supplies |
| `DiscountAmount` | `numeric(18,2)` | NOT NULL | server-computed |
| `NetAmount` | `numeric(18,2)` | NOT NULL | server-computed |
| `TermMonths` | `integer` | NULL | open-ended deals are legal |
| `PaymentGatewayCode` | `character varying(50)` | NULL | e.g. `RAZORPAY`, `STRIPE` — **no FK** (gateway config deferred), mirrors `Subscriptions."PaymentGatewayCode"` |
| `ApprovalStatus` | `character varying(20)` | NOT NULL | `DRAFT` \| `PENDING_APPROVAL` \| `APPROVED` \| `REJECTED` |
| `ApprovedByUserId` | `integer` | NULL | stamped from the JWT `UserId` claim — **no DB FK** (see §3); stays NULL on auto-approval |
| `ApprovedOn` | `timestamp with time zone` | NULL | **UTC**; set on both the auto-approve and the manual approve/reject transition |
| `RejectionReason` | `character varying(500)` | NULL | required in code when `ApprovalStatus = REJECTED` |

**Foreign keys**

| Name | Column → target | On delete |
|---|---|---|
| `FK_CommercialTerms_Leads_LeadId` | `LeadId` → `ops."Leads"(LeadId)` | **RESTRICT** — a lead with quoted deals is soft-deleted, never removed |
| `FK_CommercialTerms_Currencies_CurrencyId` | `CurrencyId` → `com."Currencies"(CurrencyId)` | **RESTRICT** |

**Indexes**

| Name | Columns |
|---|---|
| `IX_CommercialTerms_LeadId` | `LeadId` |
| `IX_CommercialTerms_ApprovalStatus` | `ApprovalStatus` |
| `IX_CommercialTerms_CurrencyId` | `CurrencyId` (EF adds this automatically for the FK) |

---

## 3. Columns intentionally **without** a database FK

| Column | Would target | Why not |
|---|---|---|
| `ops."Leads"."OwnerUserId"` | `auth."Users"` | `auth.Users` is **tenant-scoped**; platform users are resolved from the JWT claim. A hard constraint here fights the tenant query filter and would couple the control plane to a tenant table. Guarded in application code. |
| `ops."CommercialTerms"."ApprovedByUserId"` | `auth."Users"` | Same reasoning. |
| `ops."CommercialTerms"."PaymentGatewayCode"` | — | No gateway-config table exists yet (payment-gateway integration is explicitly out of scope). Mirrors the existing `billing."Subscriptions"."PaymentGatewayCode"` decision. |

---

## 4. Optional — activate the four deferred FK columns (**not** modelled in EF)

These columns already exist from P-02/P-03/P-04 and are currently plain nullable ints with the
comment "no FK yet — ops.Lead / ops.CommercialTerm are later prompts". Their targets now exist.

**This session did not add EF navigations for them**, because doing so means editing the P-03/P-04
configuration files, which the P-05 brief puts out of scope. If you want the constraints enforced at
the database level, add them as **raw SQL** in the migration's `Up` (EF will not know about them,
which is harmless — it will neither drop nor duplicate them):

```sql
ALTER TABLE ops."TenantProvisioningRuns"
  ADD CONSTRAINT "FK_TenantProvisioningRuns_Leads_LeadId"
  FOREIGN KEY ("LeadId") REFERENCES ops."Leads" ("LeadId") ON DELETE RESTRICT;

ALTER TABLE ops."TenantProvisioningRuns"
  ADD CONSTRAINT "FK_TenantProvisioningRuns_CommercialTerms_CommercialTermId"
  FOREIGN KEY ("CommercialTermId") REFERENCES ops."CommercialTerms" ("CommercialTermId") ON DELETE RESTRICT;

ALTER TABLE app."Companies"
  ADD CONSTRAINT "FK_Companies_Leads_SourceLeadId"
  FOREIGN KEY ("SourceLeadId") REFERENCES ops."Leads" ("LeadId") ON DELETE RESTRICT;

ALTER TABLE billing."Subscriptions"
  ADD CONSTRAINT "FK_Subscriptions_CommercialTerms_CommercialTermId"
  FOREIGN KEY ("CommercialTermId") REFERENCES ops."CommercialTerms" ("CommercialTermId") ON DELETE RESTRICT;
```

with the matching `DROP CONSTRAINT` statements in `Down`.

⚠ **Only apply these on a database with no orphaned values.** Any existing
`TenantProvisioningRuns` / `Companies` / `Subscriptions` row that already carries a `LeadId`,
`SourceLeadId` or `CommercialTermId` pointing at a lead/term that was never created (e.g. from
P-04 smoke tests) will make the `ALTER TABLE` fail. Check first:

```sql
SELECT 'runs.LeadId' AS col, COUNT(*) FROM ops."TenantProvisioningRuns" r
  WHERE r."LeadId" IS NOT NULL AND NOT EXISTS (SELECT 1 FROM ops."Leads" l WHERE l."LeadId" = r."LeadId")
UNION ALL
SELECT 'runs.CommercialTermId', COUNT(*) FROM ops."TenantProvisioningRuns" r
  WHERE r."CommercialTermId" IS NOT NULL AND NOT EXISTS (SELECT 1 FROM ops."CommercialTerms" t WHERE t."CommercialTermId" = r."CommercialTermId")
UNION ALL
SELECT 'companies.SourceLeadId', COUNT(*) FROM app."Companies" c
  WHERE c."SourceLeadId" IS NOT NULL AND NOT EXISTS (SELECT 1 FROM ops."Leads" l WHERE l."LeadId" = c."SourceLeadId")
UNION ALL
SELECT 'subs.CommercialTermId', COUNT(*) FROM billing."Subscriptions" s
  WHERE s."CommercialTermId" IS NOT NULL AND NOT EXISTS (SELECT 1 FROM ops."CommercialTerms" t WHERE t."CommercialTermId" = s."CommercialTermId");
```

All four counts must be `0`.

---

## 5. Rollback (`Down`)

Drop in this order (child first):

1. the four optional constraints from §4, if added;
2. `ops."CommercialTerms"`;
3. `ops."Leads"`.

The `ops` schema itself is owned by the earlier provisioning migration — do **not** drop it here.
