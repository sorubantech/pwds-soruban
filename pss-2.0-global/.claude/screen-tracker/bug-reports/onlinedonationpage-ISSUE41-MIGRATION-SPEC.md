# Migration SPEC — ISSUE-41 thin-core column relocation (Screen #10 Online Donation Page)

> **Status:** SPEC ONLY. This document describes the schema change so **you** author, run, and
> commit the EF migration. Claude did **not** run `dotnet ef migrations add` / `database update`
> / `remove`, and did **not** hand-author any migration or `ModelSnapshot` file (per project
> policy — migrations are strictly user-owned). Claude wrote the backfill SQL seed
> (`sql-scripts-dyanmic/online-donation-page-issue41-backfill-sqlscripts.sql`); **you** apply it.

## What changed (EF model)

The **15 cosmetic/presentational typed columns** that used to live directly on
`fund."OnlineDonationPages"` are **removed from the EF entity** and now persist as EAV rows in the
existing generic table `fund."OnlineDonationPageSettings"` (built earlier for ISSUE-39). This is a
**storage-only relocation (Option A "storage-only, wire stable")**:

- The wire DTOs (`OnlineDonationPageRequestDto`, `…ResponseDto`, public DTO) are **UNCHANGED** — the
  15 typed fields stay on the DTOs. **FE cards + GraphQL are UNTOUCHED.** BE-only change.
- Create / Update **UPSERT** these 15 values as setting rows.
- GetById / GetBySlug **RE-ASSEMBLE** them back into the same typed DTO fields; public SSR OG-meta
  reads the assembled fields.
- New helper: `Base.Application/…/OnlineDonationPages/Helpers/PresentationOnlineDonationPageSettings.cs`
  (writer `BuildRows` + assembler `Assemble` + `ManagedParamCodes`).

**No new table, no new column, no new index.** The only schema delta is **dropping 15 columns** from
`fund."OnlineDonationPages"`. `fund."OnlineDonationPageSettings"` already exists (ISSUE-39 migration).

## The 15 relocated columns → settings mapping

| # | Old column on `fund."OnlineDonationPages"` | Type (old) | Null? | SectionCode | ParamCode | ParamDataType | Order |
|---|--------------------------------------------|-----------|-------|-------------|-----------|---------------|-------|
| 1 | `PrimaryColorHex`      | varchar(7)    | YES | `THEME`    | `PRIMARY_COLOR`         | `color`  | 1 |
| 2 | `ButtonText`           | varchar(50)   | YES | `THEME`    | `DONATE_BUTTON_TEXT`    | `string` | 2 |
| 3 | `PageLayout`           | varchar(30)   | YES | `THEME`    | `PAGE_LAYOUT`           | `string` | 3 |
| 4 | `CustomCssOverride`    | varchar(8000)/text | YES | `THEME`    | `CUSTOM_CSS`            | `text`   | 4 |
| 5 | `IframeShowHeader`     | boolean       | YES | `EMBED`    | `IFRAME_SHOW_HEADER`    | `bool`   | 1 |
| 6 | `IframeShowFooter`     | boolean       | YES | `EMBED`    | `IFRAME_SHOW_FOOTER`    | `bool`   | 2 |
| 7 | `ThankYouMessage`      | varchar(1000) | YES | `THANKYOU` | `THANKYOU_MESSAGE`      | `text`   | 1 |
| 8 | `ThankYouRedirectUrl`  | varchar(500)  | YES | `THANKYOU` | `THANKYOU_REDIRECT_URL` | `url`    | 2 |
| 9 | `ShowDonorCount`       | boolean       | **NO** | `SOCIAL` | `SHOW_DONOR_COUNT`      | `bool`   | 1 |
| 10| `ShowSocialShare`      | boolean       | **NO** | `SOCIAL` | `SHOW_SOCIAL_SHARE`     | `bool`   | 2 |
| 11| `TaxReceiptNote`       | varchar(500)  | YES | `RECEIPT`  | `TAX_RECEIPT_NOTE`      | `text`   | 1 |
| 12| `OgTitle`              | varchar(200)  | YES | `SEO`      | `OG_TITLE`              | `string` | 1 |
| 13| `OgDescription`        | varchar(500)  | YES | `SEO`      | `OG_DESCRIPTION`        | `text`   | 2 |
| 14| `OgImageUrl`           | varchar(500)  | YES | `SEO`      | `OG_IMAGE_URL`          | `url`    | 3 |
| 15| `RobotsIndexable`      | boolean       | **NO** | `SEO`    | `ROBOTS_INDEXABLE`      | `bool`   | 4 |

**Bool serialization:** stored as lowercase `'true'` / `'false'` text in `ParamValue`.
**NULL-source rule:** nullable columns that are NULL/blank → **no row** written (assembler falls back
to coded default on read). The 3 non-nullable bools (#9, #10, #15) **always** get a row.

---

## Deploy ordering — TWO steps, in this exact order

> The whole point of two steps is: **populate settings while the columns still exist**, deploy the
> new code that reads settings, **verify**, and only THEN drop the columns. EF Core ignores unmapped
> columns, so the new build runs fine against the old (wider) table between the two steps.

### STEP 1 — additive backfill (non-destructive) — RUN FIRST

1. Deploy the new application build (entity no longer maps the 15 columns; helper + upsert/assemble
   are in place). The extra DB columns are harmless — EF ignores them.
2. Apply the backfill seed:
   `sql-scripts-dyanmic/online-donation-page-issue41-backfill-sqlscripts.sql`
   - Idempotent (`NOT EXISTS` per `(OnlineDonationPageId, ParamCode)` active row) — safe to re-run.
   - Copies each existing column value into a settings row per the mapping above; NULL-skips
     nullables; always writes the 3 non-nullable bools as lowercase `'true'`/`'false'`.
   - Backfills **every** page (including soft-deleted) so nothing is lost before the drop.
3. **VERIFY before Step 2:**
   - Run the verification `SELECT` at the bottom of the seed file — confirm each pre-existing page
     that had values now has the corresponding setting rows.
   - Open an existing page in the admin editor (`GetById`) — confirm all 15 fields re-hydrate.
   - Load the public page `/p/{slug}` (SSR) and **View Source** — confirm the `<head>` still renders
     `og:title` / `og:description` / `og:image` and the `robots` directive from the assembled
     `SEO` section. **This SEO/OG check is the gate for Step 2** — assemble + verify the `SEO`
     section LAST and confirm SSR `<head>` before dropping.

### STEP 2 — destructive DROP COLUMN ×15 — RUN ONLY AFTER STEP 1 VERIFIED

Author this as an EF migration (user-owned). Expected `Up()` = drop the 15 columns from
`fund."OnlineDonationPages"`:

```
dotnet ef migrations add DropRelocatedPresentationColumnsFromOnlineDonationPage
# review the generated Up()/Down() + ModelSnapshot delta — Up() should DROP exactly these 15
# columns and touch nothing else — then:
dotnet ef database update
```

`Up()` should drop (raw-SQL equivalent shown for reference — the generated `migrationBuilder.DropColumn`
calls must match one-for-one):

```sql
ALTER TABLE fund."OnlineDonationPages"
  DROP COLUMN "PrimaryColorHex",
  DROP COLUMN "ButtonText",
  DROP COLUMN "PageLayout",
  DROP COLUMN "CustomCssOverride",
  DROP COLUMN "IframeShowHeader",
  DROP COLUMN "IframeShowFooter",
  DROP COLUMN "ThankYouMessage",
  DROP COLUMN "ThankYouRedirectUrl",
  DROP COLUMN "ShowDonorCount",
  DROP COLUMN "ShowSocialShare",
  DROP COLUMN "TaxReceiptNote",
  DROP COLUMN "OgTitle",
  DROP COLUMN "OgDescription",
  DROP COLUMN "OgImageUrl",
  DROP COLUMN "RobotsIndexable";
```

**`Down()` expectation:** re-add the 15 columns with their original types/nullability/max-lengths
(see the mapping table). `Down()` alone does **not** restore the data — the backfilled settings rows
remain the source of truth; a rollback would additionally need the reverse copy (settings → columns),
which is out of scope for this SPEC (roll back the app build too if you must revert).

## Rollback note

If you must revert **before** Step 2: just redeploy the previous app build — the columns still exist
and still hold the original values (backfill only ADDED settings rows, never modified the columns).
After Step 2 the columns are gone; revert means restoring them from backup or re-deriving from the
settings rows.

## Files (BE, already written + compiling — `dotnet build` = 0 errors)

- `…/Helpers/PresentationOnlineDonationPageSettings.cs` — NEW writer/assembler (15-code catalog).
- `…/Models/DonationModels/OnlineDonationPage.cs` — 15 columns removed (relocation comment).
- `…/Data/Configurations/DonationConfigurations/OnlineDonationPageConfiguration.cs` — `HasMaxLength`
  for relocated columns removed.
- `…/Commands/OnlineDonationPageEntityHelper.cs` — 15 field assignments removed; `StripScriptTags`
  moved into the new helper.
- `…/Commands/CreateOnlineDonationPage.cs` — seeds presentation rows after entity insert.
- `…/Commands/UpdateOnlineDonationPage.cs` — diff-only upsert of the 15 rows (cleared nullable →
  `ParamValue = null`, not soft-deleted).
- `…/Queries/GetOnlineDonationPageById.cs` — re-assembles 15 fields from the already-loaded rows.
- `…/PublicQueries/GetOnlineDonationPageBySlug.cs` — assembles 15 fields; OG fallback chain preserved.
- `…/Commands/SaveOnlineDonationPageLandingContent.cs` — soft-delete sweep now excludes the 15
  managed presentation ParamCodes (collision guard).
