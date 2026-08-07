# Screen #173 CrowdFundingPage — Public-Page EAV Settings Port, Part 1

**Status**: Code complete, build GREEN. Migrations are user-owned — this document is the handoff spec for the user to author/run the 2 EF migrations around the provided backfill script.

Mirrors the OnlineDonationPage (#10) ISSUE-41/ISSUE-42 "thin-core relocation" pattern. Governing spec: `.claude/screen-tracker/bug-reports/publicpages-EAV-SETTINGS-PORT-SPEC.md`.

## Scope

18 cosmetic/presentational columns relocated off `fund."CrowdFunds"` into a new EAV table `fund."CrowdFundSettings"` (mirrors `fund."OnlineDonationPageSettings"` / `fund."CrowdFundSettings"` sibling shape). GraphQL DTO contract is byte-identical — only persistence location changes. No FE change required.

| Section | Old Column | ParamCode | Type | Blank handling |
|---|---|---|---|---|
| THEME | PrimaryColorHex | PRIMARY_COLOR | color | always emit |
| THEME | AccentColorHex | ACCENT_COLOR | color | always emit |
| THEME | BackgroundColorHex | BACKGROUND_COLOR | color | always emit |
| THEME | FontFamily | FONT_FAMILY | string | always emit |
| MEDIA | LogoUrl | LOGO_URL | url | skip if blank |
| MEDIA | HeroImageUrl | HERO_IMAGE_URL | url | skip if blank |
| MEDIA | HeroVideoUrl | HERO_VIDEO_URL | url | skip if blank |
| SECTIONS | EnabledSectionsJson | ENABLED_SECTIONS | json | always emit |
| SECTIONS | ShowGoalThermometer | SHOW_GOAL_THERMOMETER | bool | always emit |
| SECTIONS | ShowDonorCount | SHOW_DONOR_COUNT | bool | always emit |
| SECTIONS | ShowDonorWall | SHOW_DONOR_WALL | bool | always emit |
| CONTENT | Headline | HEADLINE | string | skip if blank |
| CONTENT | StoryRichText | STORY_RICH_TEXT | text | skip if blank |
| SOCIAL | DefaultShareMessage | DEFAULT_SHARE_MESSAGE | text | skip if blank |
| SEO | OgTitle | OG_TITLE | string | skip if blank |
| SEO | OgDescription | OG_DESCRIPTION | string | skip if blank |
| SEO | OgImageUrl | OG_IMAGE_URL | url | skip if blank |
| SEO | RobotsIndexable | ROBOTS_INDEXABLE | bool | always emit (default true) |

**Deferred (NOT part of this port — relocate last, untouched here)**: `ImpactBreakdownJson`, `FaqJson`, `BeneficiariesJson`, `MilestonesJson`, `UpdatesJson`.

**Stays typed on `CrowdFund`, never moves**: `PageTemplateId`, `CampaignName`, `Slug`, `PageStatus`, `Currency`, `GoalAmount`, `StretchGoalAmount`, `GoalExceededBehavior`, dates, `DonationPurposeId`, `CampaignCategory`, `OrganizationalUnitId`, donation/gateway/email/WhatsApp/invitation columns.

## 3-step rollout order (STRICT — do not reorder)

### Step 1 — Migration 1: create `fund."CrowdFundSettings"`
Run:
```
dotnet ef migrations add AddCrowdFundSettingsTable --project Base.Infrastructure --startup-project Base.API
dotnet ef database update --project Base.Infrastructure --startup-project Base.API
```
This creates the table per `Base.Domain/Models/DonationModels/CrowdFundSetting.cs` and `Base.Infrastructure/Data/Configurations/DonationConfigurations/CrowdFundSettingConfiguration.cs` (already committed in this session): PK `CrowdFundSettingId`, FK `CrowdFundId` → `fund.CrowdFunds` (Cascade), FK `CompanyId` → Company (Restrict), `SectionCode`/`ParamCode` (upper-cased via `[CaseFormat("upper")]`), `ParamName`, `ParamDataType`, `ParamValue`, `OrderBy`, standard audit columns.

At this point the OLD 18 columns still exist on `fund."CrowdFunds"` — the live DB schema has NOT changed for them yet, even though the C# `CrowdFund` entity in this codebase no longer maps them (EF ignores columns it isn't told about; they simply sit unused in the table).

### Step 2 — Seed/backfill script
Run `sql-scripts-dyanmic/crowdfundingpage-eav-relocation-backfill.sql` against the target environment. It reads the still-live OLD typed columns on `fund."CrowdFunds"` and INSERTs one row per non-blank/relocatable value into `fund."CrowdFundSettings"`, per the section/ParamCode table above. Idempotent (`NOT EXISTS` guard on `CrowdFundId` + `upper(ParamCode)`), wrapped in `BEGIN;...COMMIT;` with a `-- ROLLBACK;` escape at the bottom. Review the preview `SELECT` before committing in production.

**This step MUST run after Step 1 (table must exist) and BEFORE Step 3 (source columns must still exist to read from).**

### BE deploy
Deploy the code in this session (already build-verified GREEN) between Step 2 and Step 3. From this point, reads/writes go through `Helpers.PresentationCrowdFundSettings` against the new EAV table; the old columns become dead weight on the table, no longer touched by the app.

### Step 3 — Migration 2: drop the 18 old columns off `fund."CrowdFunds"`
Once the backfill is verified and the BE is deployed and confirmed healthy, run a second migration that drops: `PrimaryColorHex`, `AccentColorHex`, `BackgroundColorHex`, `FontFamily`, `LogoUrl`, `HeroImageUrl`, `HeroVideoUrl`, `EnabledSectionsJson`, `ShowGoalThermometer`, `ShowDonorCount`, `ShowDonorWall`, `Headline`, `StoryRichText`, `DefaultShareMessage`, `OgTitle`, `OgDescription`, `OgImageUrl`, `RobotsIndexable` from `fund."CrowdFunds"`. This corresponds to the entity-property removals already made to `Base.Domain/Models/DonationModels/CrowdFund.cs` and the config removals in `CrowdFundConfiguration.cs` in this session — the EF model snapshot will already reflect "no columns," so `dotnet ef migrations add DropCrowdFundLegacyEavColumns` should generate a clean `DropColumn` migration.

## Files changed this session (backend, all build-verified)

- `Base.Domain/Models/DonationModels/CrowdFund.cs` — 18 properties removed, replaced with NOTE comments.
- `Base.Domain/Models/DonationModels/CrowdFundSetting.cs` — NEW entity (EAV row).
- `Base.Infrastructure/Data/Configurations/DonationConfigurations/CrowdFundConfiguration.cs` — removed Fluent config for the 18 relocated properties (2 edits); FK/index/deferred-JSON config untouched.
- `Base.Infrastructure/Data/Configurations/DonationConfigurations/CrowdFundSettingConfiguration.cs` — NEW EF configuration for the EAV table (cascade FK to CrowdFund, restrict FK to Company).
- `Base.Application/Business/DonationBusiness/CrowdFunds/Helpers/PresentationCrowdFundSettings.cs` — NEW helper: `BuildRowsFromEntity`, `BuildRowsPartial`, `Assemble`, `UpsertAsync` (diff-only, presence-aware).
- `IDonationDbContext.cs`, `DonationDbContext.cs` — added `DbSet<CrowdFundSetting>`.
- `CrowdFundEntityHelper.cs`, `CreateCrowdFund.cs`, `UpdateCrowdFundPage.cs`, `DuplicateCrowdFund.cs`, `GetCrowdFundById.cs`, `GetCrowdFundBySlug.cs`, `ValidateCrowdFundForPublish.cs` — rewired to read/write through the EAV helper instead of typed columns.
- `Base.Application/Business/DonationBusiness/CrowdFunds/InvitationCommands/SendCrowdFundInvitationTest.cs` — removed dead `campaign.OgTitle` fallback reference (build-breaking without this fix).
- `Base.Application/Services/CrowdFundCommunications/CrowdFundEmailService.cs` — same dead `campaign.OgTitle` fallback fix (newly discovered via sanity sweep, not in original file-generation-order plan).
- `Base.Application/Mappings/DonationMappings.cs` — `CrowdFundPublicDto.OrgLogoUrl` mapping changed from `.Map(dest.OrgLogoUrl, src.LogoUrl)` to `.Ignore(dest.OrgLogoUrl)` since `CrowdFund.LogoUrl` no longer exists (newly discovered via sanity sweep); the DTO field is still populated — the handler builds it manually from `presentation.LogoUrl`.
- `sql-scripts-dyanmic/crowdfundingpage-eav-relocation-backfill.sql` — NEW, this document's Step 2.

## Build verification

```
dotnet build Base.Application/Base.Application.csproj -v q
```
Result: **0 Error(s)**, 575 Warning(s) (all pre-existing/unrelated; includes 2 new benign CS8603 nullable-return warnings from the `.Ignore()` fix in `DonationMappings.cs`, not blocking). Build time 00:01:21.50.

## Deviations from original plan

Two build-breaking references were discovered via a proactive whole-solution sanity Grep for all 18 relocated property names, beyond the file list originally scoped:
1. `DonationMappings.cs` — `CrowdFundPublicDto` Mapster config referenced removed `CrowdFund.LogoUrl`.
2. `CrowdFundEmailService.cs` — referenced removed `CrowdFund.OgTitle` in a fallback expression.

Both fixed using the same reasoning already applied to `SendCrowdFundInvitationTest.cs`. No other deviations.

## Known Issues / Deferred

- The 5 deferred JSON columns (`ImpactBreakdownJson`, `FaqJson`, `BeneficiariesJson`, `MilestonesJson`, `UpdatesJson`) are intentionally untouched — out of scope for Part 1, to be relocated in a future part per the governing spec.
- No FE changes were made or required (DTO contract unchanged).
- Migrations 1 and 2, and running the backfill script, are all user-owned actions — not executed by this session per the "migrations strictly user-owned" constraint. This document is the handoff.
- No prior similar backfill script (e.g., ODP's ISSUE-41 backfill) was located this session to use as a direct style template; the script was authored directly from the governing spec's textual format requirement (§6, line ~303) and the `CrowdFundSetting.cs` entity schema. Recommend a quick diff-review against the ODP script before running in production, if the user wants to cross-check conventions.
