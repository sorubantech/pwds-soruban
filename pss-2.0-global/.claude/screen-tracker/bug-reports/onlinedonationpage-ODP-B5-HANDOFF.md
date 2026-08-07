# ODP-B5 "Captured ≠ Recorded" — Build Handoff

**Screen #10 Online Donation Page (EXTERNAL_PAGE / DONATION_PAGE)**
**Spec:** `onlinedonationpage-ODP-B5-SPEC.md` · **Date:** 2026-07-14

Backend changes are complete and self-contained. **Nothing committed.** You own: migration,
dedup SQL, index script, commit. Prove compile with `dotnet build` before applying the migration.

---

## 1. Migration SPEC (you author — do NOT run `dotnet ef migrations add`)

**Single schema change.** One new partial-unique index. No new columns, no dropped columns,
no altered types. The three staging columns this feature reads (`PromotedGlobalDonationId`,
`ResolvedContactId`, `IsAnonymous`) already exist — verified on
`Base.Domain/Models/DonationModels/OnlineDonationStaging.cs` (lines 97, 129, 132).

**What the migration must emit (`Up`):**

```csharp
migrationBuilder.CreateIndex(
    name: "UX_GlobalOnlineDonations_Company_GatewayTxn",
    table: "GlobalOnlineDonations",
    columns: new[] { "CompanyId", "GatewayTransactionId" },
    unique: true,
    filter: "\"GatewayTransactionId\" IS NOT NULL AND \"IsDeleted\" = false");
```

**`Down`:**

```csharp
migrationBuilder.DropIndex(
    name: "UX_GlobalOnlineDonations_Company_GatewayTxn",
    table: "GlobalOnlineDonations");
```

Source of truth: `GlobalOnlineDonationConfigurations.Configure` §⑦ (already in the model, so
`migrations add` will scaffold exactly this — but you author it manually per the constraint).

> ⚠️ **Run the dedup SQL in §2 BEFORE creating a UNIQUE index.** If any tenant already has two
> rows sharing `(CompanyId, GatewayTransactionId)` with a non-null txn id, the `CREATE UNIQUE
> INDEX` will fail. §2 finds and neutralises them first.

---

## 2. Dedup detection + one-off cleanup SQL (apply before the index)

### 2a. Detect existing duplicate captured charges

```sql
-- Any (CompanyId, GatewayTransactionId) group with >1 live row blocks the unique index.
SELECT "CompanyId", "GatewayTransactionId", COUNT(*) AS dup_count,
       array_agg("GlobalOnlineDonationId" ORDER BY "GlobalOnlineDonationId") AS ids
FROM   "GlobalOnlineDonations"
WHERE  "GatewayTransactionId" IS NOT NULL
  AND  "IsDeleted" = false
GROUP  BY "CompanyId", "GatewayTransactionId"
HAVING COUNT(*) > 1
ORDER  BY dup_count DESC;
```

If this returns **zero rows**, skip to §3 — no cleanup needed.

### 2b. Neutralise duplicates (keep lowest id, soft-delete the rest)

Review the §2a output first. Only run this once you're satisfied the survivors are correct.
Keeps the earliest `GlobalOnlineDonationId` per group; soft-deletes later duplicates so the
partial index (which excludes `IsDeleted = true`) will build.

```sql
WITH ranked AS (
    SELECT "GlobalOnlineDonationId",
           ROW_NUMBER() OVER (
               PARTITION BY "CompanyId", "GatewayTransactionId"
               ORDER BY "GlobalOnlineDonationId"
           ) AS rn
    FROM   "GlobalOnlineDonations"
    WHERE  "GatewayTransactionId" IS NOT NULL
      AND  "IsDeleted" = false
)
UPDATE "GlobalOnlineDonations" g
SET    "IsDeleted"    = true,
       "ModifiedDate" = (now() AT TIME ZONE 'utc')
FROM   ranked r
WHERE  g."GlobalOnlineDonationId" = r."GlobalOnlineDonationId"
  AND  r.rn > 1;
```

> Note: this only soft-deletes the duplicate `GlobalOnlineDonation` header rows. If any survived
> duplicate had its own `GlobalDonation`/distributions, verify totals after — but in practice
> these arise from webhook re-delivery where the ledger row is shared, so header dedup is enough.

---

## 3. Partial-unique-index creation script (if you apply by SQL instead of migration)

The migration in §1 emits the same DDL. If you prefer to apply the index directly:

```sql
CREATE UNIQUE INDEX "UX_GlobalOnlineDonations_Company_GatewayTxn"
    ON "GlobalOnlineDonations" ("CompanyId", "GatewayTransactionId")
    WHERE "GatewayTransactionId" IS NOT NULL AND "IsDeleted" = false;
```

(Optionally `CREATE UNIQUE INDEX CONCURRENTLY` outside a txn on a busy prod table.)

---

## 4. Per-repo change list (backend only — you commit)

All under `PSS_2.0_Backend/PeopleServe/Services/Base/`.

### Base.Infrastructure
| File | Change |
|------|--------|
| `Data/Configurations/DonationConfigurations/GlobalOnlineDonationConfiguration.cs` | **§⑦** Added partial-unique index `UX_GlobalOnlineDonations_Company_GatewayTxn` on `(CompanyId, GatewayTransactionId)`, filtered `GatewayTransactionId IS NOT NULL AND IsDeleted = false`. DB backstop for app-level idempotency. |

### Base.Application
| File | Change |
|------|--------|
| `Business/DonationBusiness/OnlineDonations/Commands/PromoteRecurringCycle.cs` | **NEW** (prior session). Per-cycle promotion for recurring webhook cycles. Idempotent by `(CompanyId, GatewayTransactionId)`. |
| `Business/DonationBusiness/OnlineDonationInbox/Commands/ResolveOnlineDonationStaging.cs` | Two-state idempotency. (1) Guard now throws only when `ResolvedContactId` set (not on promotion). (2) New CONTACT-ONLY re-resolve branch: when already-promoted, `ExecuteUpdateAsync` back-fills `ContactId`/`IsIndividualDonation` on the existing `GlobalDonation` + distributions instead of minting. (3) Extracted recurring Process-3 into `TryEnsureRecurringScheduleAsync(...)`, shared by full-mint + contact-only paths. |
| `Business/DonationBusiness/RecurringDonationSchedules/Commands/CreateRecurringDonationSchedule.cs` | Get-or-create by `(GatewaySubscriptionId, CompanyId)` at handler top — returns existing schedule instead of inserting a duplicate. Validator: removed the hard-reject `GatewaySubscriptionId` uniqueness rule (replaced by handler lookup). |
| `Business/DonationBusiness/OnlineDonationInbox/Queries/GetOnlineDonationStagingList.cs` | **§⑧** `AWAITING` → `ResolvedContactId == null && IsAnonymous == false`; `RESOLVED` → `ResolvedContactId != null \|\| IsAnonymous == true`. Contact-resolution semantics, not ledger-promotion. |
| `Services/OnlineDonationMapJobs/OnlineDonationMapJobRunner.cs` | **§⑧** `EligiblePredicate` now `ResolvedContactId == null && IsAnonymous == false` (was `!IsResolved && PromotedGlobalDonationId == null`). Already-promoted-but-contact-unresolved rows stay eligible for auto-map; anonymous rows excluded. |
| `Business/DonationBusiness/OnlineDonationInbox/Queries/GetOnlineDonationInboxSummary.cs` | **§⑧** `UnresolvedCount` → `ResolvedContactId == null && IsAnonymous == false`; projection now selects `ResolvedContactId` + `IsAnonymous`. |
| `Business/DonationBusiness/OnlineDonationPages/PublicMutations/ConfirmOnlineDonation.cs` | (Prior session — no edit this session.) Public confirm creates schedule via direct `Add` + auto-promotes captured charge. |

### Constraints honoured
- No `dotnet ef migrations add/update/remove` run — migration is yours (§1).
- Nothing committed.
- DB is UTC `timestamptz` — all new `DateTime` writes use `DateTime.UtcNow` (Kind=Utc); dedup SQL uses `now() AT TIME ZONE 'utc'`.
- CompanyId sourced from the loaded ROW on anonymous/webhook paths, never HttpContext.

---

## 5. Apply order

1. `dotnet build` — prove compile.
2. Run §2a detect. If dups, review then run §2b.
3. Author migration (§1) **or** run §3 SQL. Apply.
4. Commit (backend only).
