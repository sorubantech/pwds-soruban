# Migration SPEC — ISSUE-39 `fund.OnlineDonationPageSettings` (Screen #10 Online Donation Page)

> **Status:** SPEC ONLY. This document describes the schema change so **you** author, run, and
> commit the EF migration. Claude did **not** run `dotnet ef migrations add` / `database update`
> and did **not** hand-author any migration or `ModelSnapshot` file (per project policy — migrations
> are strictly user-owned).

## What changed (EF model)

One new entity `OnlineDonationPageSetting` mapped to a new table **`fund.OnlineDonationPageSettings`**.
A generic per-page EAV settings table (modeled on `sett.OrganizationSettings`) that holds the
STANDARD (Aurora) template's landing content — hero benefit cards, "Why Your Donation Matters" grid,
impact stats, mission copy, and rich footer — **without** adding columns to `OnlineDonationPages` and
**without** per-section tables.

- New entity: `Base.Domain/Models/DonationModels/OnlineDonationPageSetting.cs`
- New EF config: `Base.Infrastructure/Data/Configurations/DonationConfigurations/OnlineDonationPageSettingConfiguration.cs`
- New `DbSet`: `ApplicationDbContext.OnlineDonationPageSettings` (interface `IDonationDbContext` + `DonationDbContext` partial)

No existing table/column is modified. This is purely **additive** (one `CREATE TABLE` + indexes + FKs).

## Suggested migration name

```
AddOnlineDonationPageSettings
```

Run from the folder that owns the `ApplicationDbContext` migrations (same folder/startup project you
use for every other Base migration):

```
dotnet ef migrations add AddOnlineDonationPageSettings
# review the generated Up()/Down() + ModelSnapshot delta, then:
dotnet ef database update
```

## Expected table shape (verify the generated migration matches)

Table: **`fund."OnlineDonationPageSettings"`**

| Column                        | Type            | Null | Notes |
|-------------------------------|-----------------|------|-------|
| `OnlineDonationPageSettingId` | `integer`       | NO   | PK, identity-always (`UseIdentityAlwaysColumn`) |
| `OnlineDonationPageId`        | `integer`       | NO   | FK → `fund."OnlineDonationPages"` (**ON DELETE CASCADE**) |
| `CompanyId`                   | `integer`       | NO   | FK → Company table (**ON DELETE RESTRICT**) |
| `SectionCode`                 | `varchar(40)`   | NO   | e.g. `HERO_BENEFITS`, `WHY_DONATE`, `IMPACT_STATS`, `MISSION`, `FOOTER` |
| `ParamCode`                   | `varchar(60)`   | NO   | e.g. `BENEFIT_CARDS`, `MISSION_BODY` |
| `ParamName`                   | `varchar(120)`  | YES  | admin editor label |
| `ParamDataType`               | `varchar(20)`   | NO   | `string`\|`text`\|`int`\|`decimal`\|`bool`\|`url`\|`color`\|`json` |
| `ParamValue`                  | `text`          | YES  | serialized JSON for `json` types; NULL = renderer fallback |
| `OrderBy`                     | `integer`       | NO   | display order within section |
| `CreatedBy`                   | `integer`       | —    | audit (from `Entity` base) |
| `CreatedDate`                 | `timestamptz`   | —    | audit |
| `ModifiedBy`                  | `integer`       | YES  | audit |
| `ModifiedDate`                | `timestamptz`   | YES  | audit |
| `IsActive`                    | `boolean`       | YES  | from `Entity` base |
| `IsDeleted`                   | `boolean`       | YES  | soft-delete flag from `Entity` base |

## Expected indexes

1. **Filtered unique** — one active row per `(OnlineDonationPageId, ParamCode)`:
   - Name: `IX_OnlineDonationPageSettings_PageId_ParamCode_Active`
   - Columns: `(OnlineDonationPageId, ParamCode)`
   - `UNIQUE`, filter: `"IsDeleted" = false`
2. **Non-unique lookup** — ordered read within a section:
   - Name: `IX_OnlineDonationPageSettings_PageId_SectionCode_OrderBy`
   - Columns: `(OnlineDonationPageId, SectionCode, OrderBy)`

## Foreign keys

- `OnlineDonationPageId` → `fund."OnlineDonationPages"."OnlineDonationPageId"` — **ON DELETE CASCADE**
  (page delete removes its settings).
- `CompanyId` → Company PK — **ON DELETE RESTRICT**.

## Data / backfill notes

- **No backfill required.** Default landing-content rows are seeded **in application code** on page
  Create (`CreateOnlineDonationPageHandler` → `DefaultOnlineDonationPageSettings.BuildDefaultRows`,
  idempotent NOT-EXISTS per `ParamCode`).
- Pages created **before** this migration will have **zero** setting rows. Two supported options
  (developer's choice — not required for the migration to be valid):
  1. Do nothing — `GetById` / `GetBySlug` return an empty `LandingContentDto` and the FE renderer
     falls back to its coded defaults (ISSUE-40 guarantees the renderer never assumes a row exists).
  2. Optional one-time seed for pre-existing STANDARD pages (run after migrating): insert the 9
     default rows per existing page id via the same catalog. A `sql-scripts-dyanmic` seed can be
     added later if the team wants existing pages pre-populated; it is **not** needed for correctness.

## Down() expectation

`Down()` should simply `DROP TABLE fund."OnlineDonationPageSettings"` (and its indexes/FKs). No other
object is touched.
