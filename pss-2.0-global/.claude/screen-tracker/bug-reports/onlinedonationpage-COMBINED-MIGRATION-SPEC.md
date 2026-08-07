# OnlineDonationPage (#10) — COMBINED Migration SPEC (ISSUE-41 + ISSUE-42)

> **Status:** READY FOR USER (migrations are user-owned — this is a SPEC only; no `dotnet ef` was run).
> **Supersedes:** `onlinedonationpage-ISSUE41-MIGRATION-SPEC.md` (that spec's DROP is **NOT** run alone).
> **Date:** 2026-07-16
> **Owner action required:** author + run the two steps below, then commit.

---

## 1. Why ONE migration

ISSUE-41 relocated **15 cosmetic/presentational** columns into the generic EAV table
`fund.OnlineDonationPageSettings`. ISSUE-42 relocated **3 MEDIA** columns
(`LogoUrl`, `HeroImageUrl`, `CarouselSlidesJson`) into the same EAV table.

Both relocations are **storage-only, wire-stable** (Option A): the entity's typed props are
removed, but the wire DTOs re-assemble those fields on read via
[`PresentationOnlineDonationPageSettings.Assemble`](../../..). FE, templates, dispatcher, and
GraphQL contracts are **untouched**.

To avoid altering the live `fund.OnlineDonationPages` table twice (once for ISSUE-41's drop,
once for ISSUE-42's), **both drops are folded into a single migration.** The backfill seed
(STEP 1) moves all 18 columns' data into settings rows; the migration (STEP 2) drops all 18
columns together. **The live table is altered exactly once.**

The BE source already reads all 18 fields from the assembled `pres.*` — the typed columns are
already dead code paths. This migration only reclaims the dead columns.

---

## 2. The 18 columns (mapping table)

BE authority = `Helpers/PresentationOnlineDonationPageSettings.cs` (`ManagedParamCodes`).
Backfill authority = `sql-scripts-dyanmic/online-donation-page-issue41-backfill-sqlscripts.sql`.

### 2a. THEME + IFRAME + THANKYOU + SOCIAL (ISSUE-41 — 11 rows)

| # | Dropped column | Section | ParamCode | Type | Order |
|---|----------------|---------|-----------|------|-------|
| 1 | `PrimaryColorHex` | THEME | `PRIMARY_COLOR` | color | 1 |
| 2 | `ButtonText` | THEME | `DONATE_BUTTON_TEXT` | string | 2 |
| 3 | `PageLayout` | THEME | `PAGE_LAYOUT` | string | 3 |
| 4 | `CustomCssOverride` | THEME | `CUSTOM_CSS` | text | 4 |
| 5 | `IframeShowHeader` | IFRAME | `IFRAME_SHOW_HEADER` | bool | 1 |
| 6 | `IframeShowFooter` | IFRAME | `IFRAME_SHOW_FOOTER` | bool | 2 |
| 7 | `ThankYouMessage` | THANKYOU | `THANKYOU_MESSAGE` | text | 1 |
| 8 | `ThankYouRedirectUrl` | THANKYOU | `THANKYOU_REDIRECT_URL` | url | 2 |
| 9 | `ShowDonorCount` | SOCIAL | `SHOW_DONOR_COUNT` | bool | 1 |
| 10 | `ShowSocialShare` | SOCIAL | `SHOW_SOCIAL_SHARE` | bool | 2 |
| 11 | `TaxReceiptNote` | THANKYOU | `TAX_RECEIPT_NOTE` | text | 3 |

### 2b. SEO (ISSUE-41 — 4 rows) — **verify these read correctly LAST** (§4)

| # | Dropped column | Section | ParamCode | Type | Order |
|---|----------------|---------|-----------|------|-------|
| 12 | `OgTitle` | SEO | `OG_TITLE` | text | 1 |
| 13 | `OgDescription` | SEO | `OG_DESCRIPTION` | text | 2 |
| 14 | `OgImageUrl` | SEO | `OG_IMAGE_URL` | url | 3 |
| 15 | `RobotsIndexable` | SEO | `ROBOTS_INDEXABLE` | bool | 4 |

### 2c. MEDIA (ISSUE-42 — 3 rows)

| # | Dropped column | Section | ParamCode | Type | Order |
|---|----------------|---------|-----------|------|-------|
| 16 | `LogoUrl` | MEDIA | `LOGO_URL` | url | 1 |
| 17 | `HeroImageUrl` | MEDIA | `HERO_IMAGE_URL` | url | 2 |
| 18 | `CarouselSlidesJson` (jsonb) | MEDIA | `CAROUSEL_SLIDES` | json | 3 |

> **Note on `CarouselSlidesJson`:** stored as `jsonb`; the backfill copies it `::text` verbatim.
> The assembler deserializes back to `List<CarouselSlide>` and **truncates to the first 5 by
> Order** on read — legacy rows with >5 slides are safe (no pre-truncation needed).

---

## 3. STEP 1 — Additive backfill (data move) — **run FIRST, on the live DB**

**File:** `sql-scripts-dyanmic/online-donation-page-issue41-backfill-sqlscripts.sql` (already
committed; covers all 18 params 1–18, MEDIA block appended).

- Idempotent: each INSERT is guarded by `NOT EXISTS (… ParamCode = X AND IsDeleted = false)`.
- Nullable-source columns SKIP when NULL/blank (`NULLIF(btrim(...),'') IS NOT NULL`).
- Non-nullable bools (`ROBOTS_INDEXABLE`, `SHOW_*`, `IFRAME_*`) always insert `'true'`/`'false'`.
- Wrapped in a single transaction; ends `COMMIT;` with a VERIFY query.

**Run this and confirm the VERIFY query returns one row per managed ParamCode per page that
had a non-blank value — BEFORE authoring STEP 2.**

---

## 4. Verification gate — **between STEP 1 and STEP 2** (do not skip)

Because the DROP is irreversible in practice (Down re-adds empty columns), verify reads work
off the EAV rows while the typed columns still exist as a safety net:

1. **Typed reads (GetById / GetAllList / GetBySlug):** open an existing page in the admin
   editor — confirm Primary Color, Button Text, Layout, Custom CSS, Thank-You message,
   Logo, Hero, Carousel slides all render from `pres.*` (they already do in source; this
   confirms the backfill rows are present and correctly typed).
2. **Reset Branding:** run Reset — confirm THEME + MEDIA rows null out (not the typed cols).
3. **Publish validation:** a NAV page with only a Logo (now an EAV row) still passes the
   hero-asset guard (`ValidateOnlineDonationPageForPublish` reads `pres.LogoUrl/HeroImageUrl/
   CarouselSlides`).
4. **SSR `<head>` / OG — verify LAST, most fragile:** load the **public** page
   (`GetOnlineDonationPageBySlug`) and view source. Confirm `<title>`, `og:title`,
   `og:description`, `og:image` render from the SEO EAV rows, and the OG-image fallback chain
   `pres.OgImageUrl ?? pres.HeroImageUrl ?? pres.LogoUrl ?? tenantLogoUrl` resolves. The SEO
   section is validated **after** THEME/MEDIA because a broken `<head>` degrades link previews
   silently (no runtime error) — it's the one failure that won't surface in the admin UI.

Only when all four pass → author STEP 2.

---

## 5. STEP 2 — EF migration (drop 18 columns together) — **user authors + runs**

Migration name suggestion: `OnlineDonationPage_DropRelocatedCosmeticAndMediaColumns`.

`Up()` — drop all 18 in one migration:

```csharp
migrationBuilder.DropColumn("PrimaryColorHex",      schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("ButtonText",           schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("PageLayout",           schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("CustomCssOverride",    schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("IframeShowHeader",     schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("IframeShowFooter",     schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("ThankYouMessage",      schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("ThankYouRedirectUrl",  schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("ShowDonorCount",       schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("ShowSocialShare",      schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("TaxReceiptNote",       schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("OgTitle",              schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("OgDescription",        schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("OgImageUrl",           schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("RobotsIndexable",      schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("LogoUrl",              schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("HeroImageUrl",         schema: "fund", table: "OnlineDonationPages");
migrationBuilder.DropColumn("CarouselSlidesJson",   schema: "fund", table: "OnlineDonationPages");
```

`Down()` — re-add all 18 (empty; data is NOT restored — it lives in EAV). Match original
column types/nullability from the prior snapshot:

```csharp
migrationBuilder.AddColumn<string>("PrimaryColorHex",     schema: "fund", table: "OnlineDonationPages", nullable: true);
migrationBuilder.AddColumn<string>("ButtonText",          schema: "fund", table: "OnlineDonationPages", nullable: true);
migrationBuilder.AddColumn<string>("PageLayout",          schema: "fund", table: "OnlineDonationPages", nullable: true);
migrationBuilder.AddColumn<string>("CustomCssOverride",   schema: "fund", table: "OnlineDonationPages", nullable: true);
migrationBuilder.AddColumn<bool>  ("IframeShowHeader",    schema: "fund", table: "OnlineDonationPages", nullable: false, defaultValue: true);
migrationBuilder.AddColumn<bool>  ("IframeShowFooter",    schema: "fund", table: "OnlineDonationPages", nullable: false, defaultValue: true);
migrationBuilder.AddColumn<string>("ThankYouMessage",     schema: "fund", table: "OnlineDonationPages", nullable: true);
migrationBuilder.AddColumn<string>("ThankYouRedirectUrl", schema: "fund", table: "OnlineDonationPages", nullable: true);
migrationBuilder.AddColumn<bool>  ("ShowDonorCount",      schema: "fund", table: "OnlineDonationPages", nullable: false, defaultValue: false);
migrationBuilder.AddColumn<bool>  ("ShowSocialShare",     schema: "fund", table: "OnlineDonationPages", nullable: false, defaultValue: false);
migrationBuilder.AddColumn<string>("TaxReceiptNote",      schema: "fund", table: "OnlineDonationPages", nullable: true);
migrationBuilder.AddColumn<string>("OgTitle",             schema: "fund", table: "OnlineDonationPages", nullable: true);
migrationBuilder.AddColumn<string>("OgDescription",       schema: "fund", table: "OnlineDonationPages", nullable: true);
migrationBuilder.AddColumn<string>("OgImageUrl",          schema: "fund", table: "OnlineDonationPages", nullable: true);
migrationBuilder.AddColumn<bool>  ("RobotsIndexable",     schema: "fund", table: "OnlineDonationPages", nullable: false, defaultValue: true);
migrationBuilder.AddColumn<string>("LogoUrl",             schema: "fund", table: "OnlineDonationPages", nullable: true);
migrationBuilder.AddColumn<string>("HeroImageUrl",        schema: "fund", table: "OnlineDonationPages", nullable: true);
migrationBuilder.AddColumn<string>("CarouselSlidesJson",  schema: "fund", table: "OnlineDonationPages", type: "jsonb", nullable: true);
```

> **Confirm the exact original types/defaults from the current model snapshot before running**
> `dotnet ef migrations add` — the values above mirror the entity as it stood pre-relocation,
> but the authoritative source is the last applied snapshot in `Migrations/`.

---

## 6. Deploy order (summary)

1. Deploy the BE build (entity has no typed cols; reads go through `pres.*`). **← already built, 0 errors.**
2. Run STEP 1 backfill SQL on the target DB.
3. Run the §4 verification gate (SEO/OG last).
4. `dotnet ef migrations add OnlineDonationPage_DropRelocatedCosmeticAndMediaColumns` → review → `database update`.
5. Commit migration + snapshot.

Rollback within the window: `database update <prev>` re-adds empty columns; data remains safe
in `fund.OnlineDonationPageSettings` (backfill is never deleted). To fully revert reads you'd
also revert the BE build — but the EAV rows stay valid, so forward re-deploy is clean.
