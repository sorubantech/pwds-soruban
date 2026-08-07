# Migration SPEC — ODP-B7 GDPR consent columns (Screen #10 Online Donation Page)

> **Status:** SPEC ONLY. This document describes the schema change so **you** author, run, and
> commit the EF migration. Claude did **not** run `dotnet ef migrations add` / `database update`
> / `remove`, and did **not** hand-author any migration or `ModelSnapshot` file (per project
> policy — migrations are strictly user-owned). No seed is needed for this change (defaults come
> from `BuildDefaultRows`; historic rows stay NULL).

## What changed (EF model)

Four **nullable** columns are added to `fund."OnlineDonationStagings"` to persist a durable,
per-donor GDPR consent audit trail captured at public-form submit time. All are nullable because
historic staging rows carry no consent. The C# properties are already added to the entity
`Base.Domain/Models/DonationModels/OnlineDonationStaging.cs` (this build) — this migration makes
the DB catch up.

**No other table changes. No dropped/altered columns. No index.** Consent is captured on the
staging row only — it is **NOT** copied onto `fund."GlobalDonations"` (the staging row is the
pre-promotion capture point and the durable audit record; B5 promotion is unchanged).

## The 4 new columns on `fund."OnlineDonationStagings"`

| # | Column | Postgres type | Null? | Set by | Meaning |
|---|--------|---------------|-------|--------|---------|
| 1 | `ConsentGivenAt`      | `timestamp with time zone` | YES | InitiateOnlineDonation | `DateTime.UtcNow` (Kind=Utc) when the donor ticked the consent checkbox; NULL = not captured. |
| 2 | `ConsentTextSnapshot` | `text`                     | YES | InitiateOnlineDonation | Immutable copy of the exact consent statement (`CONSENT_TEXT`) shown at submit. |
| 3 | `ConsentTextVersion`  | `character varying` (`varchar`) | YES | InitiateOnlineDonation | Optional version tag echoed from the page config (e.g. the CONSENT EAV row's `ModifiedDate` stamp). |
| 4 | `MarketingOptIn`      | `boolean`                  | YES | InitiateOnlineDonation | Separate optional marketing-consent checkbox state; NULL = checkbox not shown. |

> `timestamptz` is mandatory — every Postgres date column in this DB is `timestamp with time zone`
> and Npgsql throws on `Kind=Unspecified`; the app writes `Kind=Utc` only.

---

## Deploy ordering — ONE step (additive, non-destructive)

Unlike ISSUE-41, this is purely additive: the new build reads/writes these columns, and the columns
must exist before consent-persistence code runs against the DB. EF Core tolerates the entity mapping
columns that don't exist only for *unmapped* columns — since these ARE mapped, run the migration
before (or together with) deploying the new build.

Author this as an EF migration (user-owned):

```
dotnet ef migrations add AddConsentColumnsToOnlineDonationStaging
# review the generated Up()/Down() + ModelSnapshot delta — Up() should ADD exactly these 4
# columns to fund."OnlineDonationStagings" and touch nothing else — then:
dotnet ef database update
```

Expected `Up()` (raw-SQL equivalent shown for reference — the generated `migrationBuilder.AddColumn`
calls must match one-for-one, all nullable):

```sql
ALTER TABLE fund."OnlineDonationStagings"
  ADD COLUMN "ConsentGivenAt"      timestamp with time zone NULL,
  ADD COLUMN "ConsentTextSnapshot" text NULL,
  ADD COLUMN "ConsentTextVersion"  character varying NULL,
  ADD COLUMN "MarketingOptIn"      boolean NULL;
```

Expected `Down()` = 4 `DropColumn` calls (reverse order is fine):

```sql
ALTER TABLE fund."OnlineDonationStagings"
  DROP COLUMN "MarketingOptIn",
  DROP COLUMN "ConsentTextVersion",
  DROP COLUMN "ConsentTextSnapshot",
  DROP COLUMN "ConsentGivenAt";
```

## Rollback note

All four columns are nullable and additive — rolling back the app build alone is safe (the columns
sit unused). Dropping the columns (`Down()`) discards captured consent audit data, so only do that if
you are certain no consent has been captured yet.

## Files (BE, this build)

- `…/Models/DonationModels/OnlineDonationStaging.cs` — 4 nullable consent properties added (this SPEC's target).
- `…/Helpers/PresentationOnlineDonationPageSettings.cs` — new `CONSENT` section (5 ParamCodes) added to
  `Assemble` + `BuildDefaultRows`-equivalent defaults + `ManagedParamCodes` (sweep-exclusion).
- `…/PublicMutations/InitiateOnlineDonation.cs` — persists consent on staging-create + server-enforces
  `CONSENT_REQUIRED` + propagates `MarketingOptIn` → `Contact.EmailOptInDate` on resolution.
- `…/Schemas/DonationSchemas/OnlineDonationPageSchemas.cs` — consent fields on the initiate request DTO
  and consent config on the page/public DTOs.
