# P-02 Migration Spec — Billing schema (plans, subscriptions, usage)

> **Author/run policy:** migrations are strictly user-owned. This is the hand-authoring spec.
> The developer (this session) did **not** run `dotnet ef migrations add` / `database update` /
> `remove` and did **not** hand-author a migration or model-snapshot file. The six entities +
> EF configs compile and map; author the migration from this spec, run it, and commit it.
>
> Suggested migration name: `Add_Billing_Plans_Subscriptions_Usage`.
>
> **Seed order after migrating:** (1) `sql-scripts-dyanmic/billing-plan-catalog-seed.sql`,
> then (2) `sql-scripts-dyanmic/billing-backfill-subscriptions.sql` (needs the CUSTOM plan).

---

## 1. New schema

- `billing` — commercial/billing schema. If the migration runner does not create it implicitly
  from the `[Table(Schema="billing")]` annotations, add `migrationBuilder.EnsureSchema("billing")`
  first (mirrors how P-01 handled `ops`).

All six tables use `integer` identity-always PKs (`UseIdentityAlwaysColumn`) and carry the Entity
base audit columns: `CreatedBy` int NULL, `CreatedDate` timestamptz NULL, `ModifiedBy` int NULL,
`ModifiedDate` timestamptz NULL, `IsActive` boolean NULL, `IsDeleted` boolean NULL. These are
omitted from the per-table column lists below for brevity (identical everywhere).

---

## 2. New table — `billing."Plans"`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `PlanId` | `integer` | NOT NULL | identity (always) | PK |
| `PlanCode` | `varchar(30)` | NOT NULL | — | `FREE\|PLAN_50K\|PLAN_100K\|CUSTOM`. UNIQUE (see indexes). Stored uppercase (`CaseFormat`) |
| `PlanName` | `varchar(120)` | NOT NULL | — | |
| `Description` | `varchar(500)` | NULL | — | |
| `Price` | `numeric(18,2)` | NOT NULL | — | 0 for FREE |
| `Currency` | `varchar(10)` | NOT NULL | — | ISO code, e.g. INR |
| `BillingCycle` | `varchar(20)` | NOT NULL | — | `Monthly\|Annual` |
| `IsCustom` | `boolean` | NOT NULL | — | true only for CUSTOM |
| `SortOrder` | `integer` | NOT NULL | — | |

**Indexes**
- `IX_Plans_PlanCode` — **UNIQUE** on (`PlanCode`).

> Note: `IsActive` (plan on/off) reuses the Entity base column — it is **not** re-declared on
> the entity, so there is no duplicate/shadow column.

---

## 3. New table — `billing."PlanEntitlements"`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `PlanEntitlementId` | `integer` | NOT NULL | identity (always) | PK |
| `PlanId` | `integer` | NOT NULL | — | **FK → billing."Plans"(PlanId)** |
| `FeatureCode` | `varchar(60)` | NOT NULL | — | `MODULE:*` / `CHANNEL:*`. **No FK** (free string; see note §8) |
| `IsEnabled` | `boolean` | NOT NULL | — | |

**FK**
- `FK_PlanEntitlements_Plans_PlanId`: `PlanId → billing."Plans"(PlanId)`, `ON DELETE CASCADE`.

**Indexes**
- `IX_PlanEntitlements_PlanId_FeatureCode` — **UNIQUE** on (`PlanId`, `FeatureCode`).

---

## 4. New table — `billing."PlanQuotas"`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `PlanQuotaId` | `integer` | NOT NULL | identity (always) | PK |
| `PlanId` | `integer` | NOT NULL | — | **FK → billing."Plans"(PlanId)** |
| `MeterCode` | `varchar(30)` | NOT NULL | — | e.g. `CONTACTS\|DONATIONS\|EMAILS\|USERS` |
| `MeterType` | `varchar(10)` | NOT NULL | — | `STOCK\|FLOW` |
| `LimitValue` | `bigint` | NULL | — | **NULL = unlimited** |
| `Period` | `varchar(10)` | NULL | — | `MONTH` for FLOW; NULL for STOCK |

**FK**
- `FK_PlanQuotas_Plans_PlanId`: `PlanId → billing."Plans"(PlanId)`, `ON DELETE CASCADE`.

**Indexes**
- `IX_PlanQuotas_PlanId_MeterCode` — **UNIQUE** on (`PlanId`, `MeterCode`).

---

## 5. New table — `billing."Subscriptions"`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `SubscriptionId` | `integer` | NOT NULL | identity (always) | PK |
| `CompanyId` | `integer` | NOT NULL | — | **FK → app."Companies"(CompanyId)** |
| `PlanId` | `integer` | NOT NULL | — | **FK → billing."Plans"(PlanId)** |
| `CommercialTermId` | `integer` | NULL | — | **NO FK yet** (ops.CommercialTerm is a later prompt) |
| `Status` | `varchar(20)` | NOT NULL | — | `Trial\|Active\|PastDue\|Suspended\|Cancelled` |
| `StartDate` | `timestamp with time zone` | NOT NULL | — | UTC |
| `CurrentPeriodStart` | `timestamp with time zone` | NOT NULL | — | UTC |
| `CurrentPeriodEnd` | `timestamp with time zone` | NOT NULL | — | UTC |
| `TrialEndsOn` | `timestamp with time zone` | NULL | — | UTC |
| `CancelledOn` | `timestamp with time zone` | NULL | — | UTC |

**FK**
- `FK_Subscriptions_Companies_CompanyId`: `CompanyId → app."Companies"(CompanyId)`, `ON DELETE RESTRICT`.
- `FK_Subscriptions_Plans_PlanId`: `PlanId → billing."Plans"(PlanId)`, `ON DELETE RESTRICT`.

**Indexes**
- `IX_Subscriptions_CompanyId` — **UNIQUE, PARTIAL** on (`CompanyId`) — at most one *active*
  subscription per company. The EF config emits a filtered index; the raw DDL is:

  ```sql
  CREATE UNIQUE INDEX "IX_Subscriptions_CompanyId"
    ON billing."Subscriptions" ("CompanyId")
    WHERE "Status" IN ('Trial','Active','PastDue');
  ```

> **Tenant query filter note:** `Subscriptions` has a `CompanyId` property ⇒ the global
> `ApplyTenantFilters` in `ApplicationDbContext` auto-applies a tenant filter to it. The
> `EntitlementService` reads it with `IgnoreQueryFilters()` (by explicit companyId) so resolution
> is deterministic in background / provisioning / cross-tenant SuperAdmin contexts. No schema
> impact; flagged for awareness.

---

## 6. New table — `billing."SubscriptionOverrides"`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `SubscriptionOverrideId` | `integer` | NOT NULL | identity (always) | PK |
| `SubscriptionId` | `integer` | NOT NULL | — | **FK → billing."Subscriptions"(SubscriptionId)** |
| `FeatureCode` | `varchar(60)` | NULL | — | set for a feature override |
| `MeterCode` | `varchar(30)` | NULL | — | set for a meter override |
| `OverrideValue` | `bigint` | NULL | — | feature: 0/1 boolean · meter: numeric limit (NULL = unlimited) |
| `Note` | `varchar(500)` | NULL | — | |

**FK**
- `FK_SubscriptionOverrides_Subscriptions_SubscriptionId`:
  `SubscriptionId → billing."Subscriptions"(SubscriptionId)`, `ON DELETE CASCADE`.

**Check constraint** (exactly one of feature / meter is set — the EF config emits it via
`ToTable(HasCheckConstraint)`):

```sql
ALTER TABLE billing."SubscriptionOverrides"
  ADD CONSTRAINT "CK_SubscriptionOverride_FeatureXorMeter"
  CHECK (("FeatureCode" IS NOT NULL) <> ("MeterCode" IS NOT NULL));
```

---

## 7. New table — `billing."UsageCounters"`

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `UsageCounterId` | `integer` | NOT NULL | identity (always) | PK |
| `CompanyId` | `integer` | NOT NULL | — | **FK → app."Companies"(CompanyId)** |
| `MeterCode` | `varchar(30)` | NOT NULL | — | |
| `PeriodStart` | `timestamp with time zone` | NOT NULL | — | UTC. STOCK = fixed epoch; FLOW = period boundary |
| `CurrentValue` | `bigint` | NOT NULL | — | P-02 defines shape only; increment is a later prompt |

**FK**
- `FK_UsageCounters_Companies_CompanyId`: `CompanyId → app."Companies"(CompanyId)`, `ON DELETE RESTRICT`.

**Indexes**
- `IX_UsageCounters_CompanyId_MeterCode_PeriodStart` — **UNIQUE** on (`CompanyId`, `MeterCode`, `PeriodStart`).

> Same tenant-filter note as Subscriptions applies (`UsageCounters` has a `CompanyId`).

---

## 8. Columns / codes that get NO foreign key yet (and why)

| Column / value | Target (future) | Why deferred |
|---|---|---|
| `Subscriptions.CommercialTermId` | `ops.CommercialTerm` | that table is a later prompt — add FK in its migration |
| `PlanEntitlements.FeatureCode` | (conceptually) `auth.Modules` | auth modules are **coarse** (`CRM`,`SETTING`,… with Guid keys); this is the finer DQ4 `MODULE:*`/`CHANNEL:*` vocabulary. Kept as a free string; P-03 step-4 (capability ∩ entitlement) needs an auth ModuleCode → FeatureCode mapping layer. See hand-back note. |

The FKs created now: `Subscriptions.CompanyId`, `Subscriptions.PlanId`, `UsageCounters.CompanyId`
(→ app.Companies / billing.Plans, all existing after this migration), plus the three intra-schema
cascades (`PlanEntitlements`, `PlanQuotas`, `SubscriptionOverrides`).
