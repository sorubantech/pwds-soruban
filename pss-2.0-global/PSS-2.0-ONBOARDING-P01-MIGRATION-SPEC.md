# P-01 Migration Spec — Onboarding provisioning data model

> **Author/run policy:** migrations are strictly user-owned. This is the hand-authoring spec.
> The developer (this session) did **not** run `dotnet ef migrations add` / `database update` /
> `remove` and did **not** hand-author a migration or model-snapshot file. The entities + EF
> configs compile and map; author the migration from this spec, run it, and commit it.
>
> Suggested migration name: `Add_Ops_TenantProvisioning_And_Company_Onboarding_Columns`.

---

## 1. New schema

- `ops` — control-plane schema. If the migration runner does not create it implicitly from the
  `[Table(Schema="ops")]` annotations, add `migrationBuilder.EnsureSchema("ops")` first.

---

## 2. New table — `ops."TenantProvisioningRuns"` (T-A1)

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `RunId` | `integer` | NOT NULL | identity (always) | PK |
| `IdempotencyKey` | `varchar(100)` | NOT NULL | — | UNIQUE (see indexes) |
| `LeadId` | `integer` | NULL | — | **NO FK yet** (ops.Lead is a later prompt) |
| `CommercialTermId` | `integer` | NULL | — | **NO FK yet** (ops.CommercialTerm is a later prompt) |
| `CompanyId` | `integer` | NULL | — | **FK → app."Companies"(CompanyId)** — the only wired FK |
| `Mode` | `varchar(20)` | NOT NULL | — | `SELF_SERVICE\|ASSISTED` |
| `Status` | `varchar(20)` | NOT NULL | — | `PENDING\|RUNNING\|PAUSED_ON_ERROR\|SUCCEEDED\|ABANDONED` |
| `RequestPayloadJson` | `jsonb` | NOT NULL | — | serialized wizard answer set (text-as-jsonb convention) |
| `StartedOn` | `timestamp with time zone` | NULL | — | UTC |
| `CompletedOn` | `timestamp with time zone` | NULL | — | UTC |
| `InitiatedByUserId` | `integer` | NULL | — | no FK |
| `CreatedBy` | `integer` | NULL | — | Entity base |
| `CreatedDate` | `timestamp with time zone` | NULL | — | Entity base (write `DateTime.UtcNow`) |
| `ModifiedBy` | `integer` | NULL | — | Entity base |
| `ModifiedDate` | `timestamp with time zone` | NULL | — | Entity base |
| `IsActive` | `boolean` | NULL | — | Entity base |
| `IsDeleted` | `boolean` | NULL | — | Entity base |

**FK**
- `FK_TenantProvisioningRuns_Companies_CompanyId`: `CompanyId → app."Companies"(CompanyId)`,
  `ON DELETE RESTRICT`.

**Indexes**
- `IX_TenantProvisioningRuns_IdempotencyKey` — **UNIQUE** on (`IdempotencyKey`).
- `IX_TenantProvisioningRuns_Status` on (`Status`).
- `IX_TenantProvisioningRuns_CompanyId` on (`CompanyId`).

> **Tenant query filter note:** because this entity has a `CompanyId` property, the global
> `ApplyTenantFilters` in `ApplicationDbContext` will auto-apply a tenant filter to it. That is
> fine for a control-plane table read by SuperAdmin (CurrentTenantId = null ⇒ no filtering). No
> schema impact; flagged for awareness only.

---

## 3. New table — `ops."TenantProvisioningRunSteps"` (T-A1)

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `RunStepId` | `integer` | NOT NULL | identity (always) | PK |
| `RunId` | `integer` | NOT NULL | — | **FK → ops."TenantProvisioningRuns"(RunId)** |
| `StepNumber` | `integer` | NOT NULL | — | 1..9 |
| `StepCode` | `varchar(50)` | NOT NULL | — | `CREATE_COMPANY\|CREATE_SUBSCRIPTION\|SEED_ROLES\|SEED_CAPABILITIES\|SEED_MASTERDATA\|SEED_SETTINGS\|SEED_FIELDS\|CREATE_ADMIN\|SEND_WELCOME` |
| `Status` | `varchar(20)` | NOT NULL | — | `PENDING\|RUNNING\|SUCCEEDED\|FAILED\|SKIPPED` |
| `AttemptCount` | `integer` | NOT NULL | `0` | |
| `ErrorMessage` | `varchar(4000)` | NULL | — | |
| `StartedOn` | `timestamp with time zone` | NULL | — | UTC |
| `CompletedOn` | `timestamp with time zone` | NULL | — | UTC |
| `CreatedBy` / `CreatedDate` / `ModifiedBy` / `ModifiedDate` / `IsActive` / `IsDeleted` | Entity base | NULL | — | as above |

**FK**
- `FK_TenantProvisioningRunSteps_TenantProvisioningRuns_RunId`:
  `RunId → ops."TenantProvisioningRuns"(RunId)`, `ON DELETE CASCADE` (deleting a run removes its steps).

**Indexes**
- `IX_TenantProvisioningRunSteps_RunId_StepNumber` — **UNIQUE** on (`RunId`, `StepNumber`).

---

## 4. Alter table — `app."Companies"` additive columns (T-A2 / §7.3)

All additive and existing-row-safe:

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `Status` | `varchar(20)` | NULL | — | `PROVISIONING\|ACTIVE\|SUSPENDED\|CHURNED` |
| `IsInternal` | `boolean` | NOT NULL | `false` | |
| `OnboardedOn` | `timestamp with time zone` | NULL | — | UTC |
| `SourceLeadId` | `integer` | NULL | — | **NO FK yet** (points at ops.Lead, a later prompt) |

**Backfill for existing rows (developer's chosen default):** set existing companies to
`Status = 'ACTIVE'` in the same migration (they are live tenants). New provisioning runs set
`PROVISIONING` then flip to `ACTIVE` on success. Suggested:

```sql
UPDATE app."Companies" SET "Status" = 'ACTIVE' WHERE "Status" IS NULL;
```

`IsInternal` defaults `false` for all existing rows via the column default — correct (only the
`__TEMPLATE__` shell and future platform-internal companies are `true`).

---

## 5. Columns that get NO foreign key yet (and why)

| Column | Target (future) | Why deferred |
|---|---|---|
| `TenantProvisioningRuns.LeadId` | `ops.Lead` | `ops.Lead` table is a later prompt — add FK in that migration |
| `TenantProvisioningRuns.CommercialTermId` | `ops.CommercialTerm` | `ops.CommercialTerm` table is a later prompt |
| `TenantProvisioningRuns.InitiatedByUserId` | `auth` user | left as a plain int per brief (no FK requested) |
| `Companies.SourceLeadId` | `ops.Lead` | `ops.Lead` table is a later prompt |

The **only** FK created now is `TenantProvisioningRuns.CompanyId → app."Companies"` (that table exists).
