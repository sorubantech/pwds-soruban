# OnlineDonationPage (#10) — USER-OWNED Migration / Backfill SPEC (ISSUE-5 · 21 · 23 · 40)

> **Status:** READY FOR USER — migrations are strictly user-owned. This is a SPEC only.
> **No `dotnet ef migrations add/database update/remove` was run; no migration or ModelSnapshot was hand-authored by the agent.**
> **Date:** 2026-07-17 (Session 66)
> **Owner action required:** author + run each step below in the stated order, then commit the migration + snapshot.

These four items are independent of the ISSUE-41/42 column-relocation migration
(`onlinedonationpage-COMBINED-MIGRATION-SPEC.md`). If you are batching all pending
`fund.OnlineDonationPages`-touching migrations, fold ISSUE-5 + ISSUE-23 into the **same**
`dotnet ef migrations add` as the ISSUE-41/42 drop so the live table is altered exactly once —
see §5.

---

## ISSUE-5 — `GlobalDonations.OnlineDonationPageId` nullable FK

**Goal:** attribute a donation row back to the public page that produced it, without breaking the
millions of existing rows that predate the feature.

**Delta (additive only):** one nullable column + one filtered FK on `fund."GlobalDonations"`.

```csharp
// Up()
migrationBuilder.AddColumn<int>(
    name: "OnlineDonationPageId",
    schema: "fund",
    table: "GlobalDonations",
    nullable: true);                       // legacy rows stay NULL — backfill is a deliberate no-op

migrationBuilder.CreateIndex(
    name: "IX_GlobalDonations_OnlineDonationPageId",
    schema: "fund",
    table: "GlobalDonations",
    column: "OnlineDonationPageId",
    filter: "\"OnlineDonationPageId\" IS NOT NULL");   // partial index — only page-sourced rows

migrationBuilder.AddForeignKey(
    name: "FK_GlobalDonations_OnlineDonationPages_OnlineDonationPageId",
    schema: "fund",
    table: "GlobalDonations",
    column: "OnlineDonationPageId",
    principalSchema: "fund",
    principalTable: "OnlineDonationPages",
    principalColumn: "OnlineDonationPageId",
    onDelete: ReferentialAction.Restrict);  // never cascade-delete donation history when a page is removed
```

```csharp
// Down()
migrationBuilder.DropForeignKey("FK_GlobalDonations_OnlineDonationPages_OnlineDonationPageId", schema: "fund", table: "GlobalDonations");
migrationBuilder.DropIndex("IX_GlobalDonations_OnlineDonationPageId", schema: "fund", table: "GlobalDonations");
migrationBuilder.DropColumn("OnlineDonationPageId", schema: "fund", table: "GlobalDonations");
```

**Backfill:** none. Existing rows have no reliable page linkage, so they legitimately stay
`NULL`. New donations set the FK at Confirm time (from `staging.OnlineDonationPageId`).

**Entity change (developer-owned, already builds):** add `public int? OnlineDonationPageId { get; set; }`
+ `public OnlineDonationPage? OnlineDonationPage { get; set; }` nav to `GlobalDonation`, and an EF
config mapping matching the FK above (`OnDelete Restrict`, filtered index). Confirm these are
present before authoring the migration so the snapshot the tool generates matches the intended DDL.

**EF migration name suggestion:** `Add_OnlineDonationPage_And_FK_On_GlobalDonations`.

---

## ISSUE-23 — reconcile the `Slug` filtered-index drift (do BEFORE the next auto-generated migration)

**Symptom:** the EF fluent config declares the unique Slug index with
`HasFilter("\"IsDeleted\" = false")`, but the original hand-authored migration created a raw-SQL
**`LOWER(Slug)`** filtered index. The two are not identical, so the next `dotnet ef migrations add`
will emit a spurious `DropIndex` + `CreateIndex` to "fix" the drift — and in doing so **drop the
`LOWER()` case-insensitivity**, silently weakening slug-uniqueness to case-sensitive.

**Decision required (pick ONE, then make code + DB agree):**

- **Option A — keep case-insensitive uniqueness (recommended).** Case-insensitive is the correct
  business rule (`/p/MyPage` and `/p/mypage` must not both exist). EF fluent indexes cannot express
  `LOWER(col)`, so keep the index **raw-SQL** and tell EF to ignore it:
  - In the entity config, remove the `HasIndex(x => x.Slug).HasFilter(...)` fluent declaration (or
    mark it `.HasDatabaseName(...)` matching the raw index name so EF treats it as already-present —
    but the `LOWER()` expression still won't round-trip; safest is to drop the fluent index and
    manage it purely in raw SQL).
  - Keep the raw-SQL index from the original migration:
    ```sql
    CREATE UNIQUE INDEX "UX_OnlineDonationPages_CompanyId_LowerSlug"
      ON fund."OnlineDonationPages" ("CompanyId", LOWER("Slug"))
      WHERE "IsDeleted" = false;
    ```
  - Verify the next `migrations add` produces **no** index delta for Slug.

- **Option B — accept EF-managed case-sensitive index.** Only if product accepts case-sensitive
  slugs. Let EF own it via fluent `HasIndex(x => new { x.CompanyId, x.Slug }).IsUnique().HasFilter("\"IsDeleted\" = false")`,
  and in the same migration `DROP INDEX` the old `LOWER(Slug)` one. **Also lower-case-normalize the
  slug at write time** (BE `OnlineDonationPageSlugValidator` already lowercases input, so uniqueness
  is preserved in practice) — otherwise this weakens the guarantee.

Whichever is chosen, resolve it **before** the ISSUE-5 / ISSUE-41 migration so that migration
doesn't smuggle in an unintended Slug-index change.

---

## ISSUE-21 — ModelSnapshot sync

**Symptom:** earlier migrations were hand-authored (valid DDL) but the `ModelSnapshot` was not
regenerated, so it does not contain the newer entities/columns. Left alone, the next
`migrations add` will emit corrective churn.

**Fix (runs itself off the model — no hand-editing the snapshot):**
1. Ensure the entity + EF config for every new model (`OnlineDonationPage`, `OnlineDonationPageSetting`,
   `OnlineDonationStaging`, `RecurringDonationSchedule`, and the ISSUE-5 `GlobalDonations` FK) match
   the live DB.
2. Run once, before any new feature migration:
   ```
   dotnet ef migrations add Sync_Snapshot --no-build
   ```
   Review the generated `Up()/Down()` — they should be **empty** (or contain only the
   already-applied DDL if the DB is ahead). If non-empty with unexpected DDL, the model still
   disagrees with the DB — reconcile ISSUE-23 first, then regenerate.
3. Apply/commit so the snapshot is the source of truth going forward.

> After this sync, the ISSUE-5 and ISSUE-41/42 migrations generate clean, minimal diffs.

---

## ISSUE-40 — optional backfill of default settings rows for legacy pages

**Context:** pages created **before** ISSUE-39 (the EAV settings table) have **no**
`fund.OnlineDonationPageSettings` rows. This is already safe — the Aurora renderer and the
`Presentation…Assemble` reader fall back to coded defaults when a row is absent (the ISSUE-40
guarantee: *the renderer must never assume a row exists*). This backfill is **optional**, only for
tenants who want the default values to appear as **editable** rows in the admin editor immediately.

**This is a SEED, not a migration.** Write it as an idempotent SQL file under
`sql-scripts-dyanmic/` (e.g. `online-donation-page-issue40-legacy-settings-backfill.sql`):

- For each existing `fund."OnlineDonationPages"` row, `INSERT` the default settings rows for the
  managed `ParamCode`s **only where none exists**:
  ```sql
  INSERT INTO fund."OnlineDonationPageSettings"
      ("OnlineDonationPageId","ParamCode","ParamValue","SectionCode","OrderBy",
       "CreatedBy","CreatedDate","IsActive","IsDeleted")
  SELECT p."OnlineDonationPageId", d.param_code, d.default_value, d.section_code, d.order_by,
         2, now() AT TIME ZONE 'UTC', true, false
  FROM fund."OnlineDonationPages" p
  CROSS JOIN (VALUES
      -- (param_code, default_value, section_code, order_by) — pull the authoritative default set
      -- from Helpers/DefaultOnlineDonationPageSettings.cs so seed == code defaults
      ('PRIMARY_COLOR','#…','THEME',1)
      -- …one row per managed default…
  ) AS d(param_code, default_value, section_code, order_by)
  WHERE NOT EXISTS (
      SELECT 1 FROM fund."OnlineDonationPageSettings" s
      WHERE s."OnlineDonationPageId" = p."OnlineDonationPageId"
        AND s."ParamCode" = d.param_code
        AND s."IsDeleted" = false);
  ```
- **Authority for the default set = `Helpers/DefaultOnlineDonationPageSettings.cs`** — copy the
  ParamCode/value/section/order tuples verbatim so a backfilled legacy page is byte-identical to a
  freshly-created one. Do **not** hand-invent defaults here.
- Idempotent (`NOT EXISTS` per active `(OnlineDonationPageId, ParamCode)`), wrapped in a transaction,
  ends with a VERIFY count. Safe to re-run.
- **Timestamps must be UTC** (`now() AT TIME ZONE 'UTC'`) — the columns are `timestamptz` and Npgsql
  rejects unspecified-kind values on the app side.

**Do NOT** include the ISSUE-35 `ENABLED_CURRENCY_CODES` row in this legacy backfill — multi-currency
is opt-in per page (only written when the admin enables it), so legacy pages correctly have no such
row and default to single-currency.

---

## §5. Recommended combined run order (all pending #10 DB work)

1. **ISSUE-21** `Sync_Snapshot` first (empty diff) — establishes a clean baseline.
2. **ISSUE-23** reconcile the Slug index in code (Option A) so step 4 emits no Slug delta.
3. **STEP 1 of the COMBINED spec** — ISSUE-41/42 backfill SQL (data move) + its §4 verification gate.
4. **ONE migration** folding: ISSUE-41/42 column drops **+** ISSUE-5 `GlobalDonations` FK add.
   → `dotnet ef migrations add OnlineDonationPage_DropRelocatedCols_And_GlobalDonationsFK` → review → `database update`.
5. **ISSUE-40** legacy-settings backfill SQL (optional, any time after step 3).
6. Commit migration + snapshot together.

> Folding ISSUE-5 into the ISSUE-41/42 migration keeps `fund.OnlineDonations`/`OnlineDonationPages`
> altered once. If you prefer smaller migrations, ISSUE-5 can stand alone — it is additive and
> order-independent relative to the column drops.
