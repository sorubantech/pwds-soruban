# Online Donation Page (#10) — Config-Model Revision Spec

**Screen:** #10 Online Donation Page · EXTERNAL_PAGE / DONATION_PAGE (template STANDARD → Aurora)
**Scope:** ISSUE-44 (recursive footer tree, HIGH), ISSUE-45a (config audit + two-tone mission title, MED), ISSUE-47b (per-page communication-template association, MED)
**Planned:** Session 61 · 2026-07-17 · via `/plan-screens #10`

## Hard constraints (verbatim from request)
- **No DB schema changes beyond EAV JSON rows.** All three issues are delivered by adding `fund.OnlineDonationPageSettings` rows + DTO/BE-assembler/command + FE editor/renderer code. **No new tables, no new columns, no EF migration is required for any of the three issues.**
- Migrations are user-owned. There is nothing to migrate here (EAV-only); the "build to prove compile" step is a `dotnet build` (BE) + `pnpm build`/`tsc` (FE) after the code lands — **do not** run `dotnet ef` anything.
- Seed rows are author-by-me / apply-by-user (`sql-scripts-dyanmic/*.sql`, idempotent `WHERE NOT EXISTS`).
- ISSUE-44 must **keep legacy flat footer data readable during transition** — live pages that have not been re-saved must still render a footer.

---

## Reference facts (verified in code, do not re-derive)

| Fact | Location |
|------|----------|
| EAV table `fund.OnlineDonationPageSettings` (SectionCode/ParamCode/ParamName/ParamDataType/ParamValue/OrderBy), page-scoped, unique filtered idx `(OnlineDonationPageId, ParamCode) WHERE IsDeleted=FALSE` | schema |
| ParamDataType ∈ `string\|text\|int\|decimal\|bool\|url\|color\|json` | catalog convention |
| BE assembler `AssembleLandingContentDto` + `BuildDefaultRows` + footer constants `SectionFooter="FOOTER"`, `ParamFooterContact/Socials/Links`, `ParamMissionTitle="MISSION_TITLE"`, `ParamMissionBody="MISSION_BODY"` | `DefaultOnlineDonationPageSettings.cs` (172 ln) |
| Landing save = diff-only EAV upsert; soft-deletes dropped ParamCodes **except** `PresentationOnlineDonationPageSettings.ManagedParamCodes`; `BeValidJsonWhenJsonType` allows null/blank json; `[CustomAuthorize(OnlineDonationPage, Modify)]`; CompanyId from HttpContext | `SaveOnlineDonationPageLandingContent.cs` (162 ln) |
| JSON convention: WriteOpts=CamelCase, ReadOpts=case-insensitive | assembler |
| `LandingContentDto` (BE) fields: HeroBenefits, WhyDonateTitle, WhyDonate, ImpactStats, MissionTitle, MissionBody, FooterContact, FooterSocials, FooterLinks | `OnlineDonationPageSchemas.cs:282-352` |
| `LandingContentDto` (FE) mirror + `FooterContactInfo`/`FooterSocialItem`/`FooterLinkItem` | `OnlineDonationPageDto.ts:62-86` |
| Receipt email is **hardcoded HTML** via `SendComposedEmailForCompanyAsync`, best-effort, never blocks confirm | `ConfirmOnlineDonation.cs:134-146` |
| Email template lookup: `notify.EmailTemplates` by `IsActive && EmailTemplateCode==code && ModuleId==<module>`, prefer tenant row over global `CompanyId=3` (`OrderBy(t => t.CompanyId==companyId ? 0 : 1)`) | `EmailTemplateService.RenderTemplateAsync`, `GetGrantEmailDraft` |
| `IEmailTemplateService.SendComposedEmailForCompanyAsync(EmailDto, int companyId)` = ad-hoc compose+send, tenant-provider→global fallback, returns bool, never throws | `IEmailTemplateService.cs`, impl `EmailTemplateService.cs:204-306` |
| `EmailDto`: ToEmail, FromEmail?, FromName?, EmailContent?, AttachmentPath?, AttachmentContentType?, Subject?, CcEmail? | `IEmailTemplateService.cs` |
| `getEmailTemplates` GQL query (paginated, `GridFeatureRequest`) available for the FE picker | `EmailTemplateQueries.cs:17` |
| Editor footer UI (flat) to replace | `landing-content-section.tsx:490-604` |
| Renderer to make recursive | `aurora/RichFooter.tsx` (191 ln) |
| Template audit target | `templates/template-aurora.tsx` (177 ln) |

---

# ISSUE-44 — Recursive footer tree (HIGH)

Replace the 3 flat footer params (`FOOTER_CONTACT` / `FOOTER_SOCIALS` / `FOOTER_LINKS`) with **one recursive JSON param** `FOOTER_TREE`, N levels deep, and render/edit it recursively. Legacy rows stay readable via an assembler transition-map.

### 44.1 Node shape (identical BE + FE)
```
FooterNode {
  label:    string          // required — heading text or link/leaf text
  iconName?: string | null  // @iconify Phosphor name, e.g. "ph:map-pin-fill"; render only if present
  imageUrl?: string | null  // small logo/badge; render only if present
  url?:      string | null  // if present → anchor; if absent → plain text/heading
  children?: FooterNode[]   // recurse; top-level nodes = footer columns
}
```
Render rules (per request): icon and image are **each** optional (show only if present); `url` optional → link if present, else plain text/heading.

### 44.2 EAV catalog change
- **Add** `SectionCode="FOOTER"`, `ParamCode="FOOTER_TREE"`, `ParamName="Footer Tree"`, `ParamDataType="json"`, `ParamValue`= JSON array of `FooterNode`.
- `FOOTER_CONTACT` / `FOOTER_SOCIALS` / `FOOTER_LINKS` become **legacy-read-only**: no longer emitted by the editor, no longer seeded in `BuildDefaultRows`. They remain valid for the assembler's transition-map. Once a page is re-saved through the new editor, the diff-drop sweep soft-deletes them (they are NOT in `ManagedParamCodes`) — expected and correct.

### 44.3 BE — `DefaultOnlineDonationPageSettings.cs`
- Add constant `ParamFooterTree = "FOOTER_TREE"`.
- `BuildDefaultRows`: seed `FOOTER_TREE` with a small sensible default tree (Get in Touch / Useful Information / Follow us columns as heading nodes) **or** an empty `[]` — recommend seeding the same 3-column skeleton the flat defaults produced so new pages look identical.
- **`AssembleLandingContentDto` transition seam (the critical bit):**
  1. If an active `FOOTER_TREE` row exists and parses to a non-empty array → `dto.FooterTree = parsed`.
  2. **Else** synthesize the tree from any legacy rows (keeps live pages rendering):
     - From `FOOTER_CONTACT` → a "Get in Touch" heading node whose children are: address (iconName `ph:map-pin-fill`, no url), phone (iconName `ph:phone-fill`, url `tel:<phone>`), email (iconName `ph:envelope-simple-fill`, url `mailto:<email>`) — only for non-blank fields.
     - From `FOOTER_LINKS` → a "Useful Information" heading node, children = `{label, url, iconName:"ph:caret-right"}`.
     - From `FOOTER_SOCIALS` → a "Follow us" heading node, children = `{label:platform, url, iconName: socialIcon(platform)}` using the existing platform→Phosphor map (port `SOCIAL_ICONS`/`socialIcon` to BE, fallback `ph:link-simple`).
     - Omit any column whose source is empty; if all empty → `dto.FooterTree = []`.
  3. Keep populating the legacy `FooterContact/FooterSocials/FooterLinks` DTO fields from legacy rows too (backward-compat readers) — but the renderer now consumes `FooterTree` only.
- Serialize with WriteOpts (camelCase); parse with ReadOpts (case-insensitive).

### 44.4 BE — `OnlineDonationPageSchemas.cs`
- Add `public class LandingFooterNode { string Label; string? IconName; string? ImageUrl; string? Url; List<LandingFooterNode>? Children; }`.
- Add `public List<LandingFooterNode> FooterTree { get; set; } = new();` to `LandingContentDto`.
- Keep `FooterContact/FooterSocials/FooterLinks` (legacy read).

### 44.5 FE — `OnlineDonationPageDto.ts`
- Add `export interface FooterNode { label: string; iconName?: string | null; imageUrl?: string | null; url?: string | null; children?: FooterNode[]; }`.
- Add `footerTree: FooterNode[];` to `LandingContentDto`. Keep legacy footer fields (mark `@deprecated — read-only transition`).

### 44.6 FE — recursive renderer `aurora/RichFooter.tsx`
- Props switch to `landingContent?: { footerTree?: FooterNode[] } | null` (keep old fields optional for one release).
- `const nodes = landingContent?.footerTree ?? []`. If empty → `return null` (FineFooter below still renders).
- Top-level nodes → the column grid (keep the dark accent band + scrim styling, `md:grid-cols-2 lg:grid-cols-4`, cap/wrap gracefully for >4 columns).
- Recursive `<FooterNodeView node depth accent>`:
  - Render `imageUrl` (`<img>` `referrerPolicy="no-referrer"`, small `h-*`) if present, then `iconName` (`<Icon>` tinted `style={{color:accent}}`) if present, then `label`.
  - If `url` present → wrap label (row) in `<a href target="_blank" rel="noopener noreferrer">` (use `tel:`/`mailto:` verbatim if the stored url already carries the scheme). Else render as plain text; if the node has children, style as the column heading (`text-sm font-semibold uppercase tracking-wide`).
  - If `children?.length` → render them as a `<ul>` recursing `FooterNodeView` at `depth+1` (depth ≥1 = link rows; depth 0 = column heading).
- Delete the hardcoded 4-fixed-column markup; keep `SOCIAL_ICONS` only if still used by any leaf (icons now come from stored `iconName`, so the map can move BE-side per 44.3).

### 44.7 FE — recursive editor `landing-content-section.tsx:490-604`
- Replace the flat "Footer" SubPanel (Contact fields + 2× `LandingRepeater`) with a **recursive tree editor** bound to `footerTree`.
- Each node row: `label` FormInput, optional `iconName` (icon-name text or the existing icon picker), optional `imageUrl` (url FormInput), optional `url` (url FormInput), plus **[+ Add child]**, **[Remove]**, and reorder (↑/↓) controls; render children indented one level, recursing the same node editor. Cap nesting depth at a sane guard (e.g. 4) with a disabled "+ Add child" past the cap.
- On save, emit only `FOOTER_TREE` (json). Do **not** emit `FOOTER_CONTACT/SOCIALS/LINKS` — the diff-drop sweep retires them.

### 44.8 template-aurora.tsx
- No structural change; it already delegates to `<RichFooter … />`. Pass `landingContent` (now carrying `footerTree`) through unchanged.

---

# ISSUE-45a — Config audit + two-tone mission title (MED)

### 45.1 Coded-fallback audit — `template-aurora.tsx`
| # | Field | Source | Current behavior | Decision | Action |
|---|-------|--------|------------------|----------|--------|
| 1 | `missionTitle` | `landingContent.missionTitle` | `FALLBACK_MISSION_TITLE` const | Keep fallback **+ split two-tone** | 45.2 |
| 2 | `missionBody` | `landingContent.missionBody` | omit when blank | Keep omit (org prose — never invent) | none |
| 3 | Hero background | `publicData.heroImageUrl` | accent gradient when absent | Keep fallback (decorative) | none |
| 4 | `pageTitle` (H1) | `publicData.pageTitle` | none — required | Keep required | none |
| 5 | `description` | `publicData.description` | omit when blank | Keep omit | none |
| 6 | CTA label | `publicData.buttonText` | `"Make a Donation"` | Keep fallback (safe generic) | none |
| 7 | **Donate-card heading `<h3>`** | **hardcoded `"Donate Now"`** | not configurable | **Make tenant-authored** w/ fallback | 45.3 |
| 8 | `logoUrl` | `publicData.logoUrl` | omit when absent | Keep omit | none |
| — | `HeroBenefits` / `WhyDonate` | landingContent | coded fallback set | Keep (already tenant-overridable) | none |
| — | `ImpactStats` | landingContent | omits section when empty | Keep (factual — never invent) | none |

Net new config: two-tone mission (45.2) + donate-card heading (45.3). Everything else's fallback is justified and stays.

### 45.2 Two-tone mission title
Author the dark/accent colour split instead of hardcoding it.
- **EAV:** add `SectionCode="MISSION"`, `ParamCode="MISSION_TITLE_ACCENT"`, `ParamDataType="string"`. `MISSION_TITLE` stays the **primary** (dark) segment; `MISSION_TITLE_ACCENT` is the trailing **accent-coloured** segment.
- **DTO:** BE `string? MissionTitleAccent` on `LandingContentDto`; FE `missionTitleAccent: string | null`.
- **Assembler:** parse the new row into `MissionTitleAccent`.
- **Template render:**
  ```
  const primary = landingContent?.missionTitle?.trim() || FALLBACK_MISSION_TITLE;
  const accentSeg = landingContent?.missionTitleAccent?.trim() || "";
  <h2>{primary}{accentSeg && <> <span style={{ color: accent }}>{accentSeg}</span></>}</h2>
  ```
  Accent empty → renders primary only (current look). `FALLBACK_MISSION_TITLE` retained as the primary fallback.
- **Editor:** add a "Mission accent (coloured) segment" FormInput beside the existing mission-title field.

### 45.3 Donate-card heading
- **EAV:** `SectionCode="DONATE"` (or reuse an existing presentation section), `ParamCode="DONATE_CARD_HEADING"`, `ParamDataType="string"`.
- **DTO/assembler/editor:** `donateCardHeading: string | null`; template `{landingContent?.donateCardHeading?.trim() || "Donate Now"}`.
- These are landing-content params → flow through `SaveOnlineDonationPageLandingContent` normally (NOT in ManagedParamCodes).

---

# ISSUE-47b — Per-page communication-template association (MED)

Associate tenant-authored email templates to a donation page (the NEW "Communication Templates" tab from point ④), and upgrade the hardcoded receipt email to use the associated template. **Association is EAV rows — no schema.**

### 47.1 Data model — EAV, NOT FK columns
The established codebase precedent for template-association is fixed-slot `*EmailTemplateId` FK columns on the parent (CrowdFund, P2PCampaignPage). **That is deliberately NOT used here** because it violates the "no schema beyond EAV" constraint. Instead:
- **New EAV section:** `SectionCode="COMM_TEMPLATES"`, one `ParamCode` per email moment, `ParamDataType="string"`, `ParamValue` = the associated `EmailTemplateCode` (upper). Empty/missing = use built-in default behavior.
  - `COMM_RECEIPT` — tax-receipt email sent on confirmed donation (the ISSUE-47 consumer).
  - `COMM_THANKYOU` — optional acknowledgement email.
  - (extensible later: `COMM_ADMIN_NOTIFY`, etc. — add a ParamCode, no schema change.)
- **These rows are managed separately from landing content** → add `COMM_RECEIPT`/`COMM_THANKYOU` to `PresentationOnlineDonationPageSettings.ManagedParamCodes` so the landing-content diff-drop sweep never deletes them.

### 47.2 BE — query + save command (dedicated, mirrors landing-content diff-upsert)
- **Query** `GetOnlineDonationPageCommTemplates(onlineDonationPageId)` → `CommTemplatesDto { receiptTemplateCode: string?; thankYouTemplateCode: string? }` (reads the two EAV rows). `[CustomAuthorize(OnlineDonationPage, Read)]`.
- **Command** `SaveOnlineDonationPageCommTemplates(onlineDonationPageId, receiptTemplateCode?, thankYouTemplateCode?)` → diff-only upsert of the `COMM_TEMPLATES` rows (insert/update/soft-delete-when-cleared), page/tenant ownership enforced server-side, `[CustomAuthorize(OnlineDonationPage, Modify)]`. Reuse the `SaveOnlineDonationPageLandingContent` upsert helper pattern scoped to this section.
- **Template list for the picker:** reuse existing `getEmailTemplates` (paginated), filtered client-side/BE to the Donation module + active. **Confirm the Donation `ModuleCode`/`ModuleId`** before seeding/lookups (Explore flagged this — templates are per-module; Grant uses CRM, Donation must resolve its own module).

### 47.3 BE — consumer upgrade `ConfirmOnlineDonation.cs:134-146`
Replace the hardcoded receipt HTML with template-driven send, **with the hardcoded body kept as the ultimate fallback** (never regress / never block confirm):
1. Read the page's `COMM_RECEIPT` EAV row → `templateCode`.
2. If non-empty: load `notify.EmailTemplates` by `IsActive && EmailTemplateCode==templateCode && ModuleId==<DonationModule>`, prefer tenant row over global (`OrderBy(t => t.CompanyId==staging.CompanyId ? 0 : 1)`). Build placeholder dict (donor first name, amount, currency, receipt number, org/page name, date), render subject+body (reuse `PlaceholderEngine` `{{Token}}` + legacy `#KEY#` path exactly like `EmailTemplateService.RenderTemplateAsync`), attach the receipt PDF (`AttachmentPath` as today), send via `SendComposedEmailForCompanyAsync`.
3. If the row is absent OR the template lookup fails → fall back to the **existing hardcoded HTML** body. Still best-effort; still `SendComposedEmailForCompanyAsync`; still never throws / never blocks confirm.
4. (Optional, same pattern) if `COMM_THANKYOU` is set, send an acknowledgement email — otherwise send nothing extra.

### 47.4 FE — "Communication Templates" tab
- New editor tab (point ④) on the #10 admin screen: per-moment template-picker `Select`s ("Donation receipt email", "Thank-you email"), options from `getEmailTemplates` (Donation module, active). Mirrors the Grant compose-modal **template picker** (`grant-email-compose-modal.tsx`) but association-only — **no compose/send here**; this tab just stores which template each moment uses.
- Load via `GetOnlineDonationPageCommTemplates`; save via `SaveOnlineDonationPageCommTemplates`. GQL query + mutation files under the donation-service folders.

### 47.5 FLAGGED — OPTIONAL, user-owned, NOT built this pass
A per-send **communication LOG** table `fund.OnlineDonationPageCommunications` (mirror `grant.GrantCommunications`: page FK Cascade, ToEmail/Subject/BodyHtml snapshot, TemplateCode, Status SENT/FAILED, SentDate UTC, index on page FK) would give audit history + a "communications" history panel like Grant's. **This is NEW schema → out of scope for the no-schema constraint.** It is explicitly deferred as an optional user-owned migration. The EAV association (47.1) + template-driven send (47.3) ship without it; add the log table later if audit history is wanted.

---

# User-owned migration / seed notes

**No EF migration for any of the three issues** — all changes are EAV rows + code. `dotnet build` / `pnpm build` prove compile; nothing to `dotnet ef`.

Seed additions (author-by-me, apply-by-user; idempotent `WHERE NOT EXISTS`, PostgreSQL, quoted identifiers; place in `sql-scripts-dyanmic/`):

1. **ISSUE-44 footer tree (OPTIONAL backfill):** the assembler synthesizes a tree from legacy rows, so no seed is strictly required. Provide an optional per-page backfill that materializes `FOOTER_TREE` from existing `FOOTER_CONTACT/SOCIALS/LINKS` (then those legacy rows can be retired on next save). Mark OPTIONAL.
2. **ISSUE-45a:** default `DONATE_CARD_HEADING` = `"Donate Now"`; `MISSION_TITLE_ACCENT` = blank (template omits accent) or a sensible split matching the shipped default. Per-page rows in `fund.OnlineDonationPageSettings`.
3. **ISSUE-47b — email templates:** seed global (`CompanyId=3`) `notify.EmailTemplates` rows for the Donation module using the `GrantEmail-sqlscripts.sql` pattern — STEP 1 add an `EMAILCATEGORY` value if needed, STEP 2 insert templates (codes e.g. `DONATION_RECEIPT`, `DONATION_THANKYOU`) with `ModuleId` = **Donation module subquery** (confirm the ModuleCode first), `{{Token}}` HTML bodies (donor name / amount / receipt number / org / date placeholders). Then seed default `COMM_TEMPLATES` EAV rows (`COMM_RECEIPT`→`DONATION_RECEIPT`, `COMM_THANKYOU`→`DONATION_THANKYOU`).

---

# Acceptance criteria
- [ ] A footer authored as an arbitrary N-level tree (icon-only nodes, image nodes, link nodes, plain-text headings, nested children) renders correctly on the public Aurora page; icon/image each render only when present; a node with `url` links (new tab, `rel=noopener`), without `url` is plain text/heading.
- [ ] A live page with only legacy `FOOTER_CONTACT/SOCIALS/LINKS` rows (never re-saved) still renders a correct footer via the assembler transition-map. After one save through the new editor, `FOOTER_TREE` is canonical and legacy rows are retired.
- [ ] Mission title renders `primary` in dark + `accent` segment in the tenant brand colour, both tenant-authored; blank accent → primary only; blank primary → fallback.
- [ ] Donate-card heading is tenant-authored, falls back to "Donate Now".
- [ ] The audit table's "keep" decisions leave no un-reviewed hardcoded string in `template-aurora.tsx`.
- [ ] With `COMM_RECEIPT` set to a valid Donation template, a confirmed donation sends the **rendered template** (placeholders filled, PDF attached); with it unset or the template missing, it sends the existing hardcoded body. Confirm never blocks on email outcome.
- [ ] The Communication-Templates tab lists Donation-module templates and round-trips the association through `Get/SaveOnlineDonationPageCommTemplates`.
- [ ] `dotnet build` (BE) and `pnpm build`/`tsc` (FE) succeed. No `dotnet ef` run. No new table/column created.

# Special notes / gotchas
- **DateTime → UTC:** any new `SentDate`/timestamp must be `DateTimeKind.Utc` (Npgsql throws on Unspecified) — relevant only if the optional log table (47.5) is later built.
- **Donation ModuleId:** must be resolved/confirmed before seeding templates and before the `ConfirmOnlineDonation` lookup — do NOT copy Grant's CRM ModuleId.
- **ManagedParamCodes:** `COMM_RECEIPT`/`COMM_THANKYOU` MUST be added to `PresentationOnlineDonationPageSettings.ManagedParamCodes`; the landing params (`FOOTER_TREE`, `MISSION_TITLE_ACCENT`, `DONATE_CARD_HEADING`) MUST NOT be (they are saved by the landing-content command and rely on its diff sweep).
- **JSON opts:** always WriteOpts (camelCase) on serialize, ReadOpts (case-insensitive) on parse, matching the existing assembler.
- Build directives: BUSINESSADMIN role only; reuse-or-create components; UI tokens (no hex/px) except the public template's intentional inline `accent` colour.
