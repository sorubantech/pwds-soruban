# Screen #170 P2PCampaignPage — EAV Settings Port · Migration Spec (USER-OWNED)

> Authored by the agent per `publicpages-EAV-SETTINGS-PORT-SPEC.md` §2 / §2a / §6.
> **The agent did not run and did not author any EF migration file or ModelSnapshot.**
> You author, run, and commit all three steps below, in order, never collapsed.

---

## Order of operations (do not reorder)

| Step | What | Who |
|------|------|-----|
| 1 | **Migration 1** — create `fund."P2PCampaignPageSettings"` + 2 indexes | you |
| 2 | **Backfill seed** — `sql-scripts-dyanmic/p2pcampaignpage-eav-relocation-backfill.sql` | agent wrote it, you apply it |
| 3 | **Deploy** the EAV-reading backend (this session's code) | you |
| 4 | **Migration 2** — drop the 17 relocated columns from `fund."P2PCampaignPages"` | you |

Steps 1→2→3 must all be live before step 4. Between 1 and 4 the backend **dual-writes**
(typed columns *and* EAV rows), so the app is correct at every intermediate point.

---

## Step 1 — Migration 1

```bash
dotnet ef migrations add AddP2PCampaignPageSettings -c ApplicationDbContext
dotnet ef database update
```

The entity + configuration are already in the tree, so the scaffolder will emit this table.
Verify the generated migration matches:

**Table** `fund."P2PCampaignPageSettings"`

| Column | Type | Null | Notes |
|---|---|---|---|
| `P2PCampaignPageSettingId` | `integer` | NN | PK, `GENERATED ALWAYS AS IDENTITY` |
| `P2PCampaignPageId` | `integer` | NN | FK → `fund."P2PCampaignPages"` **ON DELETE CASCADE** |
| `CompanyId` | `integer` | NN | FK → Company, **ON DELETE RESTRICT** |
| `SectionCode` | `varchar(40)` | NN | stored UPPER |
| `ParamCode` | `varchar(60)` | NN | stored UPPER |
| `ParamName` | `varchar(120)` | NULL | |
| `ParamDataType` | `varchar(20)` | NN | `string\|text\|int\|decimal\|bool\|url\|color\|json` |
| `ParamValue` | `text` | NULL | unbounded — holds serialized JSON |
| `OrderBy` | `integer` | NN | |
| `CreatedBy` / `ModifiedBy` | `integer` | NULL | from `Entity` base |
| `CreatedDate` / `ModifiedDate` | `timestamp with time zone` | NULL | from `Entity` base |
| `IsActive` / `IsDeleted` | `boolean` | NN | from `Entity` base |

**Indexes**

```sql
CREATE UNIQUE INDEX "IX_P2PCampaignPageSettings_PageId_ParamCode_Active"
  ON fund."P2PCampaignPageSettings" ("P2PCampaignPageId", "ParamCode")
  WHERE "IsDeleted" = false;

CREATE INDEX "IX_P2PCampaignPageSettings_PageId_SectionCode_OrderBy"
  ON fund."P2PCampaignPageSettings" ("P2PCampaignPageId", "SectionCode", "OrderBy");
```

> The FK to the page is **Cascade** (settings are owned by the page), matching the
> `fund."OnlineDonationPageSettings"` reference table exactly. Spec §2a's "RESTRICT"
> note conflicts with its own "mirror OnlineDonationPageSettings exactly" instruction;
> Cascade was chosen for parity — flag it if you want RESTRICT instead.

---

## Step 2 — Backfill

Apply `sql-scripts-dyanmic/p2pcampaignpage-eav-relocation-backfill.sql`.
It is idempotent (`WHERE NOT EXISTS` on `(PageId, upper(ParamCode))`), wrapped in
`BEGIN; … COMMIT;`, and includes a preview `SELECT` plus a `-- ROLLBACK;` escape.
Run the preview first, confirm the row count = pages × applicable params, then commit.

Expected row count: `7 × N` always-written params + one row per non-blank optional column,
where N = number of non-deleted `fund."P2PCampaignPages"` rows.

---

## Step 4 — Migration 2 (only after steps 1–3 are live in the target environment)

Drop these **17 columns** from `fund."P2PCampaignPages"`:

| # | Column | → ParamCode |
|---|---|---|
| 1 | `PageTheme` | `THEME / PAGE_THEME` |
| 2 | `PrimaryColorHex` | `THEME / PRIMARY_COLOR` |
| 3 | `SecondaryColorHex` | `THEME / SECONDARY_COLOR` |
| 4 | `HeaderStyle` | `THEME / HEADER_STYLE` |
| 5 | `CustomCssOverride` | `THEME / CUSTOM_CSS` |
| 6 | `LogoUrl` | `MEDIA / LOGO_URL` |
| 7 | `ShowOrganizationInfo` | `SECTIONS / SHOW_ORGANIZATION_INFO` |
| 8 | `ShowImpactStats` | `SECTIONS / SHOW_IMPACT_STATS` |
| 9 | `ShowDonorWall` | `SECTIONS / SHOW_DONOR_WALL` |
| 10 | `ShowLeaderboard` | `SECTIONS / SHOW_LEADERBOARD` |
| 11 | `ShowFundraiserCount` | `SECTIONS / SHOW_FUNDRAISER_COUNT` |
| 12 | `AchievementBadgesEnabled` | `SECTIONS / ACHIEVEMENT_BADGES_ENABLED` |
| 13 | `DefaultShareMessage` | `SOCIAL / DEFAULT_SHARE_MESSAGE` |
| 14 | `OgTitle` | `SEO / OG_TITLE` |
| 15 | `OgDescription` | `SEO / OG_DESCRIPTION` |
| 16 | `OgImageUrl` | `SEO / OG_IMAGE_URL` |
| 17 | `RobotsIndexable` | `SEO / ROBOTS_INDEXABLE` |

To scaffold it, first delete the 17 properties from
`Base.Domain/Models/DonationModels/P2PCampaignPage.cs` and their `builder.Property(...)`
lines in `P2PCampaignPageConfiguration.cs`, then remove the dual-write assignments the
agent left in `CreateP2PCampaignPage.cs` / `UpdateP2PCampaignPage.cs` (each is marked
with a `// DUAL-WRITE (remove after Migration 2)` comment), then:

```bash
dotnet ef migrations add DropP2PCampaignPagePresentationColumns -c ApplicationDbContext
dotnet ef database update
```

**Stays typed — do not drop:** `PageTemplateId` (real FK to MasterData; never EAV a FK),
`Slug`, `PageStatus`, dates, and every goal / team / donation / gateway / email-template /
WhatsApp / invitation column.
