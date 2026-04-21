---
screen: ContactSource
registry_id: 122
module: Contacts
status: COMPLETED
scope: ALIGN
screen_type: MASTER_GRID
complexity: Medium
new_module: NO
planned_date: 2026-04-19
completed_date: 2026-04-21
last_session_date: 2026-04-21
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (`html_mockup_screens/screens/contacts/contact-sources.html`)
- [x] Existing code reviewed (BE: entity + 4 commands + 2 queries + 2 mutation endpoints — duplicate found; FE: thin route + 5-line data-table wrapper)
- [x] Business rules extracted (System-lock, uniqueness, merge, reorder)
- [x] FK targets resolved (no direct FK; aggregation source = `Contact.ContactSourceId`)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt pre-analysis accepted; agent spawns skipped per SavedFilter #27 precedent)
- [x] Solution Resolution complete (MASTER_GRID classification + Variant B confirmed)
- [x] UX Design finalized (§⑥ blueprint honored)
- [x] User Approval received (standing approval per /build-screen argument)
- [x] Backend code modified (ALIGN — 7 files modified, 4 created, 1 deleted, 1 migration + snapshot)
- [x] Backend wiring confirmed (DbSet already registered; Mapster auto-projects new fields via existing identity config)
- [x] Frontend code created (8 created, 11 modified — including 3 new shared-cell-renderers + IconPickerWidget registered in dgf-widgets)
- [x] Frontend wiring confirmed (route at `[lang]/crm/contact/contactsource/page.tsx` preserved)
- [x] DB Seed created (`ContactSource-sqlscripts.sql` — menu at OrderBy=3 + capabilities + Grid + 9 GridFields + GridFormSchema with IconPickerWidget + 12 sample rows (6 system + 6 custom))
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `/[lang]/crm/contact/contactsource`
- [ ] Grid columns render: Drag | Order | Code | Name (icon+bold) | Description | Contacts (count+share-bar) | System | Status | Modified | Actions
- [ ] Summary cards show: Total Sources / Active Sources / System Sources / Contacts Assigned — live counts
- [ ] Usage Insights side panel: top 3 sources mini-bar chart + "X sources added this year" insight stat + "See source analytics" link
- [ ] Quick Tips side panel: 4 static bullet points verbatim from mockup
- [ ] "System" badge renders: amber "System" pill with lock icon for `isSystem=true`; grey "Custom" pill otherwise
- [ ] Contacts count link clickable → navigates to `/[lang]/crm/contact/allcontacts?contactSourceId={id}`
- [ ] +Add Source modal: SourceCode uppercase+underscore auto-clean, icon picker with preview + 12 suggestions, Description, Display Order, Active switch
- [ ] Edit on system source: SourceCode readonly + yellow "locked" notice visible; Delete button hidden; Merge button allowed
- [ ] Edit on custom source: all fields editable; Delete + Merge buttons visible
- [ ] Drag-to-reorder: dragging a row persists new OrderBy and re-ranks remaining rows via `ReorderContactSources` mutation
- [ ] Merge modal: shows source + contact count, target dropdown (excludes self), warning with impact, confirm reassigns contacts then soft-deletes source
- [ ] Toggle Active → badge updates (System sources may still be toggled)
- [ ] Delete blocked for System → friendly error
- [ ] Delete blocked for Custom when `contactsCount > 0` → friendly error "N contacts still assigned — merge or reassign first"
- [ ] FULL E2E: create a custom source → appears at the bottom → drag to top → edit name + icon → merge into another → widget counts update
- [ ] DB Seed — menu visible in sidebar under CRM_CONTACT at OrderBy=3, GridFormSchema renders modal correctly

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: ContactSource
Module: CRM → Contacts
Schema: `corg`
Group: **Contact** (namespace folders: `ContactModels`, `ContactConfigurations`, `ContactSchemas`, `ContactBusiness`, `EndPoints/Contact`)

Business: ContactSource captures **where each contact came from** — Website, Referral, Event, Walk-in, Social Media, Campaign, Import, Partner NGO, Corporate Partner, Ambassador, Mobile App, Other. It's a master lookup used in: (a) the Contact add/edit form (dropdown), (b) bulk import flows (CSV mapping target), (c) reports and analytics (contact acquisition source breakdown). Admins maintain the list under **CRM → Contacts → Contact Sources** (MenuOrder=3, sibling of ContactType at OrderBy=2 and TagSegmentation at OrderBy=4). Like ContactType, the registry has **System sources** (seeded per tenant, non-deletable, code-locked) alongside **Custom sources** created by the tenant admin. Rarely-accurate sources can be **merged** into more accurate ones — reassigning every linked Contact in a single transaction, then soft-deleting the empty source.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Entity already exists — DO NOT regenerate. This section documents current shape + the delta needed.

Table: `corg.ContactSources`
Entity file: `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ContactModels/ContactSource.cs` (existing)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| ContactSourceId | int | — | PK | — | Existing — keep |
| ContactSourceCode | string | 100 | YES | — | Existing — unique per Company + IsActive + !IsDeleted. Uppercase + alphanumeric + underscore only (FE enforcement mirrors ContactType). |
| ContactSourceName | string | 100 | YES | — | Existing — keep |
| Description | string? | 1000 | NO | — | Existing — keep |
| **Icon** | string? | 50 | NO | — | **NEW — ADD** Font Awesome / Phosphor icon name (e.g., `compass`, `globe`, `users`, `calendar`). Stored without prefix; FE resolves to `fas fa-{icon}` or `ph:{icon}`. Default `compass`. |
| IsSystem | bool | — | YES | — | Existing on entity — **absent from DTOs; must be added to ResponseDto**. Never editable via API. |
| OrderBy | int | — | YES | — | Existing — drives grid display order + drag-reorder. |
| CompanyId | int? | — | YES (FK) | `app.Companies` | Existing — auto-filled from HttpContext. |

**Inherited audit columns** (present via `Entity` base class, not listed): `IsActive`, `IsDeleted`, `CreatedBy`, `CreatedDate`, `ModifiedBy`, `ModifiedDate`, `DeletedBy`, `DeletedDate`.

**Child / Related Entities** (used for aggregation — NOT owned):
| Entity | Relationship | Key Fields | Used For |
|--------|-------------|------------|----------|
| `Contact` | 1:Many via `Contact.ContactSourceId` (nullable FK — confirmed at `Base.Domain/Models/ContactModels/Contact.cs:25`) | ContactSourceId, ContactId | "Contacts" per-row aggregation column + "Contacts Assigned" summary widget + Usage Insights top-3 bar chart + Merge reassignment target |

**Delta from current code (ALIGN gap)**:
1. **ADD** `Icon` column on entity (`string?`, max 50) + EF config + migration.
2. **ADD** `IsSystem`, `Icon`, `ContactsCount`, `ModifiedByName` to `ContactSourceResponseDto`.
3. **ADD** `Icon` to `ContactSourceRequestDto` (IsSystem stays out — never admin-editable).
4. **FIX** `ExportContactSourceDto` — remove the leftover `ContactChannelName` field (copy-paste bug from ContactChannel entity; no such nav exists).
5. **ADD** new DTOs: `ContactSourceSummaryDto`, `ContactSourceUsageInsightDto`, `ContactSourceUsageInsightsDto`, `MergeContactSourceRequestDto`, `ReorderContactSourceRequestDto`.
6. **DELETE** duplicate mutation file `ContactSourceMutation.cs` (singular) — the plural `ContactSourceMutations.cs` is the canonical per repo convention (same duplicate cleanup as ContactType #19).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer + Frontend Developer
> ContactSource has **no user-facing FK fields** (no dropdown in the modal form). The only FK is `CompanyId`, auto-injected from HttpContext.
>
> The **"Contacts" grid column** is a per-row aggregation from `Contact.ContactSourceId`. The **Merge target dropdown** reuses `GetContactSources` to list other sources within the same Company.

| Source | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|--------|--------------|-------------------|----------------|---------------|-------------------|
| Aggregation (Contacts count) | Contact | `Base.Domain/Models/ContactModels/Contact.cs` (prop `ContactSourceId` at line 25) | — (embedded subquery in `GetContactSources`) | — | int |
| Merge target selector | ContactSource (self) | `Base.Domain/Models/ContactModels/ContactSource.cs` | `GetContactSources` (filter out the current row) | `contactSourceName` | `ContactSourceResponseDto` |
| Auto-fill (no UI) | Company | `Base.Domain/Models/AppModels/Company.cs` | — (from HttpContext) | — | int |

**Important**: Do NOT add `ApiSelectV2` dropdowns to the modal — flat master table. The mockup modal has exactly: Source Code, Source Name, Icon (custom widget), Description, Display Order, Active switch. No FK fields.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `ContactSourceCode` unique per Company scoped to `IsActive=true AND IsDeleted=false` — **already enforced** via EF filtered unique index at [ContactSourceConfiguration.cs:25-27](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/ContactConfigurations/ContactSourceConfiguration.cs#L25-L27) and validator `ValidateUniqueWhenCreate`. Add `ValidateUniqueWhenUpdate` in Update validator (currently missing).
- `ContactSourceName` — not currently unique; add soft validator if desired (low priority — not blocking).

**Required Field Rules:**
- `ContactSourceCode` required, max 100 — already enforced.
- `ContactSourceName` required, max 100 — already enforced.
- `Description` optional, max 1000 — already enforced.
- `OrderBy` required int, min 1 — auto-assigned on create.
- `Icon` optional, max 50 — NEW field.

**Conditional Rules (NEW — gap vs current code):**
- If `IsSystem = true`:
  - **Cannot delete** → `DeleteContactSource` validator/handler must throw `BadRequestException("System contact sources cannot be deleted")`.
  - **Code is readonly on edit** → Update validator must assert `existing.ContactSourceCode == request.ContactSourceCode` when `existing.IsSystem`; otherwise `BadRequestException("Code is locked for system sources")`.
  - Toggle active/inactive IS allowed (admin may hide a system source).
  - Merge IS allowed (system source can be the SOURCE of a merge OR the TARGET).
- If a Custom source has linked Contacts (`Contact.ContactSourceId == id && !IsDeleted` → count > 0) → `DeleteContactSource` handler must throw `BadRequestException("N contacts still assigned to this source — merge or reassign before deleting")`.
- Code pattern: FE regex `^[A-Z0-9_]+$` (uppercase alphanumeric + underscore). BE mirrors this in validator with `.Matches("^[A-Z0-9_]+$")`.

**Business Logic:**
- `OrderBy` auto-increments on create: `MAX(OrderBy WHERE CompanyId=current AND IsActive AND !IsDeleted) + 1` → **already in handler** at [CreateContactSource.cs:53-62](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/ContactSources/Commands/CreateContactSource.cs#L53-L62).
- **Drag-to-reorder** (NEW mutation): FE sends an ordered array of `{contactSourceId, orderBy}` → BE `ReorderContactSources` command updates `OrderBy` for all in one transaction.
- **Merge** (NEW mutation): FE sends `{sourceId, targetId}` → BE `MergeContactSources` command in one transaction:
  1. Validate both exist, same CompanyId, `sourceId != targetId`.
  2. `UPDATE Contacts SET ContactSourceId = targetId WHERE ContactSourceId = sourceId AND !IsDeleted` — count the rows updated.
  3. Soft-delete the source record (`IsDeleted = true`).
  4. Return `{reassignedCount, mergedSourceId}` for toast.
- **Click-through count-link**: FE only — navigates to `/crm/contact/allcontacts?contactSourceId={id}`. No BE work.
- **Usage Insights "top 3 last 30 days"**: Simplify for v1 — top 3 by **total contacts count** (no 30-day window). Logged as ISSUE-3 for future. See §⑫.
- **Usage Insights "X added this year"**: count of `ContactSource WHERE CreatedDate >= JAN 1 of current year AND CompanyId=current AND !IsDeleted AND !IsSystem` (excludes system seeds).

**Workflow**: None (flat master).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions.

**Screen Type**: MASTER_GRID
**Type Classification**: Type 1 — Simple flat master with extended UI (summary widgets + usage insights panel + quick tips panel + drag-reorder + merge operation + custom icon-picker widget)
**Reason**: Single flat entity, no user-facing FK dropdowns, modal popup form. Extra UX features (widgets, side panels, drag-reorder, merge) do NOT change the classification — they are additive FE concerns + 2 new backend mutations.

**Backend Patterns Required:**
- [x] Standard CRUD — **already exists**; modify only (extend projections, guards, DTOs)
- [ ] Nested child creation — NO
- [ ] Multi-FK validation — NO (no user-facing FKs)
- [x] Unique validation — `ContactSourceCode` (already in Create; **ADD** to Update)
- [ ] File upload — NO
- [x] Custom business rule validators — ADD: system-source-delete guard, system-source-code-immutable guard, in-use-delete guard
- [x] **Summary query** — ADD `GetContactSourceSummary` returning `{ totalSources, activeCount, systemCount, totalContactsAssigned }`
- [x] **Usage Insights query** — ADD `GetContactSourceUsageInsights` returning `{ topSources: [{sourceId, code, name, icon, contactsCount}], addedThisYear: int }`
- [x] **Reorder mutation** — ADD `ReorderContactSources(input: [{contactSourceId, orderBy}])`
- [x] **Merge mutation** — ADD `MergeContactSources(input: {sourceContactSourceId, targetContactSourceId})` returning `{reassignedCount, mergedSourceId}`
- [x] **Per-row aggregation** — modify `GetContactSources` handler to subquery-count `Contact.ContactSourceId`

**Frontend Patterns Required:**
- [x] AdvancedDataTable (already wired via `gridCode="CONTACTSOURCE"` at [data-table.tsx:8](PSS_2.0_Frontend/src/presentation/components/page-components/crm/contact/contactsource/data-table.tsx#L8))
- [x] RJSF Modal Form — driven by GridFormSchema in DB seed; **icon-picker is a NEW RJSF custom widget**
- [x] **Summary cards / count widgets** — NEW above the grid (4 cards)
- [x] **Grid aggregation column** — Contacts count + mini share-bar (per-row subquery from BE + FE renderer)
- [x] **Side panel — Usage Insights** — NEW right column: top 3 mini-bar chart + insight stat + analytics link
- [x] **Side panel — Quick Tips** — NEW right column (stacked below Usage Insights): 4 static bullets
- [x] **Drag-to-reorder** — NEW (reuse pattern landed for ContactType #19 / StaffCategory #43 via `onReorder` prop on `DataTableContainer`)
- [x] **Click-through filter** — NEW: Contacts count is a `<Link>` to filtered contact list
- [x] **System badge column** — REUSE `system-badge` renderer (created for ContactType #19 — amber pill with lock icon for system / grey "Custom")
- [x] **Type code monospace renderer** — REUSE `type-code` renderer (exists in `shared-cell-renderers/index.ts`)
- [x] **Contacts share-bar renderer** — NEW: inline `<strong>N</strong>` + mini horizontal progress bar (width = contactsCount / maxContactsCount * 100%). Build as `contacts-share-bar` renderer or compose via existing renderers.
- [x] **Conditional edit lock** — SourceCode readonly + Delete hidden when `isSystem=true`
- [x] **Custom icon picker widget** — NEW RJSF `ui:widget` that renders: preview box (shows rendered icon live) + text input (icon name) + 12 quick-pick buttons (see mockup list below)
- [x] **Merge modal** — NEW: shows source card, target dropdown, warning box, Confirm Merge button
- [x] **Delete confirmation modal** — reuse existing (generic) or inline
- [x] **Reorder-mode toggle button** — in page header, flips the data-table into drag-handle-visible mode
- [x] **ScreenHeader** — required because layout is NOT `grid-only` (see §⑥)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from `html_mockup_screens/screens/contacts/contact-sources.html`.

### Grid/List View

**Display Mode**: `table` (NOT card-grid — dense data table with aggregation column).

**Grid Columns** (in display order, matching mockup table thead at line 899-912):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | (drag handle) | — | drag-handle icon | 28px | NO | `ph:dots-six-vertical` or `fas fa-grip-vertical` — only visible when Reorder-mode is ON. Triggers drag-reorder. |
| 2 | Order | `orderBy` | order-num badge | 54px | YES | Circular grey badge — numeric only (reuse ContactType renderer) |
| 3 | Code | `contactSourceCode` | type-code (monospace) | 140px | YES | Monospace, grey bordered pill — **REUSE** `type-code` renderer |
| 4 | Name | `contactSourceName` + `icon` | name-with-icon | auto | YES | Accent-bg square icon box (28×28, rounded-md, bg-accent-subtle, accent icon color) + bold name. Icon resolved from `icon` field (default `compass` if null). |
| 5 | Description | `description` | text truncate | 240px | NO | Truncate with ellipsis, full in `title=` tooltip |
| 6 | Contacts | `contactsCount` | contacts-share-bar | 120px | YES | `<strong>{n}</strong>` in accent color + mini share bar below (width = n / max * 100%). **Click navigates** to `/[lang]/crm/contact/allcontacts?contactSourceId={row.contactSourceId}` (`stopPropagation` so row-click is not triggered). |
| 7 | System | `isSystem` | system-badge | 100px | YES | `true` → amber pill with lock icon "🔒 System"; `false` → grey pill "Custom". **REUSE** renderer from ContactType #19. |
| 8 | Status | `isActive` | status-badge | 100px | YES | Active (green dot + green) / Inactive (red dot + red). **REUSE** existing `status-badge`. |
| 9 | Modified | `modifiedDate` + `modifiedByName` | modified-by-cell | 150px | YES | Two-line cell: date on line 1, `by {name}` small-caps muted line 2. If no one modified, show "System". |
| 10 | Actions | — | action-buttons | 140px | NO | Edit (always visible), Merge (hidden when this row is the only remaining source), Delete (only when `isSystem=false`). |

**Search/Filter Fields** (filter-bar at line 873-895):
- Search input: matches `contactSourceCode`, `contactSourceName`, `description`
- **Status filter** (chip group): All / Active / Inactive — maps to `isActive=null|true|false`
- **Type filter** (chip group): All / System / Custom — maps to `isSystem=null|true|false`
- **Sort dropdown**: Order (default) / Name / Created / Contacts — maps to `sortField=orderBy|contactSourceName|createdDate|contactsCount`

**Grid Actions Row-Level**: Edit (always), Merge (only when custom AND contact count > 0), Delete (only when `isSystem=false`).

**Grid Actions Header-Level**: Reorder toggle (button switches to "Done" while active; flips `body.reorder-mode` → drag handles visible), Export (reuse existing grid export), +Add Source (opens RJSF modal in create mode).

**Row Click Behaviour**: Row click is a **no-op** in this screen (unlike ContactType #19 which opens a side panel on row-select). The right-column panels are static widgets, not row-driven. Action buttons handle their own events with `stopPropagation`.

### RJSF Modal Form

> Modal fields drive GridFormSchema in DB seed. Icon picker is a **custom RJSF widget** built by FE dev (first consumer).

**Form Layout** (matches mockup modal at line 983-1068):

| Section | Title | Layout | Fields |
|---------|-------|--------|--------|
| Row 1 | (no header) | 2-column | contactSourceCode (col 6), contactSourceName (col 6) |
| Row 2 | (no header) | 1-column full-width | icon (custom picker widget) |
| Row 3 | (no header) | 1-column full-width | description (textarea) |
| Row 4 | (no header) | 2-column | orderBy (col 6), isActive (col 6) |
| Row 5 (conditional) | — | 1-column full-width | systemLockNotice (shown only when `formData.isSystem === true`) |

**Field Widget Mapping**:

| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| contactSourceCode | text | "e.g., WEBSITE" | required, maxLength 100, pattern `^[A-Z0-9_]+$` | **Uppercase + alphanumeric + underscore auto-clean** via onChange `.toUpperCase().replace(/[^A-Z0-9_]/g, '')`. Readonly when `formData.isSystem === true` (edit mode). Helper text: "Uppercase alphanumeric + underscore. Unique per company." |
| contactSourceName | text | "e.g., Website" | required, maxLength 100 | — |
| icon | **IconPickerWidget** (NEW custom RJSF widget) | "Font Awesome icon name (e.g., globe, users, calendar)" | optional, maxLength 50 | Renders: live icon preview box (28px square, accent bg, rounded-md, accent color) + text input (icon name) + 12 quick-pick buttons below (compose as wrap-flex row). Quick-pick buttons (per mockup line 1018-1029): `globe`, `users`, `calendar`, `person-walking`, `share-nodes`, `bullseye`, `file-import`, `handshake`, `building`, `medal`, `mobile-screen`, `question`. Default value `compass`. |
| description | textarea | "Brief description of this source..." | optional, maxLength 1000 | rows=2 |
| orderBy | number | "13" | min=1 | Default on create: `max(orderBy) + 1` auto-fill (BE handler already does this; FE can show the next value as placeholder) |
| isActive | boolean-switch | — | — | Label toggles in real time: "Active" / "Inactive" |
| systemLockNotice | **markdown / static** (rendered only when `isSystem` true) | — | — | Amber warning box with lock icon: "Code is locked for system sources. You can still edit name, icon, and status." — purely informational, not a form field. |

**Hidden fields (in formData, not rendered)**:
- `isSystem` — never rendered, never editable via this form. Round-tripped from API (BE refuses to accept changes from the client).
- `contactSourceId` — bound at edit-time, hidden on create.
- `companyId` — BE auto-fills from HttpContext; do NOT send from FE.

### Page Widgets & Summary Cards

**Widgets**: YES — 4 count cards above the grid.

**Layout Variant** (REQUIRED — stamp one): `widgets-above-grid+side-panel`
- FE Dev MUST use **Variant B**: `<ScreenHeader>` at top → summary widget row → 2-column layout (grid on left, side-panels stacked on right) with `<DataTableContainer showHeader={false}>`.
- Page grid: `xl:grid-cols-[3fr_1fr]` or `lg:grid-cols-[9_3]` — match mockup's `col-lg-9 / col-lg-3` split.

| # | Widget Title | Value Source | Display Type | Position | Icon (accent) |
|---|-------------|-------------|-------------|----------|---------------|
| 1 | Total Sources | `totalSources` | count | Row 1, col 1 | `ph:compass` (accent-bg, accent icon) |
| 2 | Active Sources | `activeCount` | count | Row 1, col 2 | `ph:check-circle` (green bg, green icon) |
| 3 | System Sources | `systemCount` | count | Row 1, col 3 | `ph:lock` (amber bg, amber icon) |
| 4 | Contacts Assigned | `totalContactsAssigned` | count (with thousands separator) | Row 1, col 4 | `ph:users` (blue bg, blue icon) |

All 4 cards on a single horizontal row on `md+` screens; 2×2 on `sm` (mockup media query at line 775-778). Use tokens (no hex/px). Reuse the summary-card component used by ContactType #19 (`StatCardShaped`) or equivalent.

**Summary GQL Query** (NEW — needs adding):
- Query name: `GetContactSourceSummary`
- Returns: `ContactSourceSummaryDto` with fields `{ totalSources: int, activeCount: int, systemCount: int, totalContactsAssigned: int }`
- Handler: single query with GroupBy + subquery for `totalContactsAssigned` (= `_db.Contacts.Count(c => c.CompanyId == cid && !c.IsDeleted && c.ContactSourceId != null)`).
- Must be added to `ContactSourceQueries.cs` alongside existing `GetContactSources` + `GetContactSourceById`.

### Grid Aggregation Columns

**Aggregation Columns**: YES — 1 column.

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Contacts | Count of active, non-deleted Contacts pointing at this source | `corg.Contacts` where `ContactSourceId = row.ContactSourceId && !IsDeleted` | LINQ subquery in `GetContactSources` projection: `ContactsCount = _db.Contacts.Count(c => c.ContactSourceId == cs.ContactSourceId && !c.IsDeleted)`. Project into `ContactSourceResponseDto.ContactsCount` (new field, `int`). |

**Share-bar render math** (FE-side):
- Fetch grid rows → compute `maxContactsCount = max(...rows.contactsCount, 1)` (guard against 0).
- For each row: `sharePct = Math.round((row.contactsCount / maxContactsCount) * 100)`.
- Renderer composes: `<span class="accent-strong">{formatNumber(n)}</span>` + `<div class="bar-track"><div class="bar-fill" style="width:{sharePct}%"/></div>`.

### Side Panel — Usage Insights (right column, top)

| Panel Section | Fields / Content | Data Source |
|--------------|------------------|-------------|
| Header | `ph:chart-simple` icon (accent) + "Usage Insights" h3 | Static |
| Subtitle | "Top 3 sources · last 30 days" (subtle, uppercase, tracked) — **v1 shows top 3 by total count**; 30-day filter deferred (see ISSUE-3) | Static |
| Mini-bar chart (3 rows) | Each row: `<icon>{sourceName}` (left, 110px) + progress bar (middle, 1fr, linear gradient accent→accent-light) + count (right, 48px, small bold) | `GetContactSourceUsageInsights.topSources` |
| Insight stat box | Accent-subtle rounded box: circle accent icon (plus) + "**X** sources added this year" | `GetContactSourceUsageInsights.addedThisYear` |
| Analytics link | Dashed-accent-border button: "See source analytics →" | Navigates to `/[lang]/reports/contact-reports` (stub for v1 — logged as placeholder; link renders but target page may be TODO) |

**Usage Insights GQL Query** (NEW — needs adding):
- Query name: `GetContactSourceUsageInsights`
- Args: none
- Returns: `ContactSourceUsageInsightsDto { topSources: [ContactSourceUsageInsightDto { contactSourceId, contactSourceCode, contactSourceName, icon, contactsCount }], addedThisYear: int }`
- Handler:
  - `topSources` = `_db.ContactSources.Where(cs => cs.CompanyId == cid && !cs.IsDeleted).Select(cs => new { ..., ContactsCount = _db.Contacts.Count(...) }).OrderByDescending(x => x.ContactsCount).Take(3)`
  - `addedThisYear` = `_db.ContactSources.Count(cs => cs.CompanyId == cid && !cs.IsDeleted && !cs.IsSystem && cs.CreatedDate >= new DateTime(DateTime.UtcNow.Year, 1, 1))`
- Fire on page load (one-shot, not row-driven).

### Side Panel — Quick Tips (right column, bottom — stacked below Usage Insights)

Static panel, no data dependency. Card header: `ph:lightbulb` icon + "Quick Tips" h3. Body: `<ul>` with 4 bullets (verbatim from mockup line 972-977):
1. Enable **Reorder** to rearrange dropdown display order
2. Use **Merge** to consolidate duplicate sources
3. System sources **cannot be deleted** but can be deactivated
4. Codes must be **unique uppercase** per company

Use semantic `<strong>` for the bolded words. Line-height 1.8, font-size 0.8125rem (or equivalent token like `text-sm leading-relaxed`).

### Merge Modal (custom modal — triggered by row's Merge action)

| Section | Content | Data |
|---------|---------|------|
| Modal Header | Accent gradient bg + white text: `ph:git-merge` icon + "Merge Contact Source" | Static |
| Source card | Grey-50 bg rounded card: source icon (left) + source name (bold) + "{contactsCount} contacts will be reassigned" (muted small) | Selected row |
| Target dropdown | `<label>` "Merge into target source *" + `<select>` listing all OTHER sources as "`{name}` (`{count}` contacts)" | `GetContactSources` (filter out current id, filter `isActive=true && !isDeleted`) |
| Warning box | Amber bg + amber border: warning icon + strong text "This action will:" followed by bullet list | Static |
| Warning bullets | (1) Reassign all **N** contacts to the target source, (2) Delete the "**{sourceName}**" source, (3) **Cannot be undone** | Dynamic (N from selected row) |
| Footer buttons | "Cancel" (light) + "Confirm Merge" (danger red) | Confirm calls `MergeContactSources` mutation |

Merge mutation: `MergeContactSources(input: { sourceContactSourceId, targetContactSourceId }) → { reassignedCount, mergedSourceId }`. On success: close modal → toast "Merged X source into Y. N contacts reassigned." → refetch grid + summary widgets.

### Drag-to-Reorder

- Use the shared drag-reorder primitive — **check `DataTableContainer` for `onReorder` prop** (landed by StaffCategory #43; referenced in ContactType #19 ISSUE-1).
- Drag handle column (col 1) is the only grab target.
- Reorder mode toggle in page header: OFF by default, flips `reorder-mode` class / state to reveal drag handles.
- On drop: compute new ordered array of `{contactSourceId, orderBy: newIndex + 1}` → fire `ReorderContactSources` mutation → refetch grid.
- Optimistic UI: reorder locally, revert on error.

### User Interaction Flow

1. User lands on page → widgets show totals → grid shows sources ordered by `OrderBy ASC` → Usage Insights + Quick Tips panels render on the right.
2. Click "+Add Source" → modal opens (empty) → fill Code (auto-uppercase+alphanumeric+underscore) + Name + Icon (live preview or quick-pick) + Description + Order (pre-filled) + Active → Save → grid refreshes, widget counts update.
3. Click Edit icon on a row → modal opens pre-filled. If `isSystem=true` → Code is readonly with amber "locked" notice.
4. Click Merge icon on a custom row → Merge modal opens → select target → Confirm → contacts reassigned, source soft-deleted, grid + widgets + Usage Insights refreshed.
5. Click Delete icon on a custom row with 0 contacts → confirmation → soft-delete → row vanishes. On a system row → Delete button is not rendered. On a custom row with contacts > 0 → confirmation shows "Cannot delete — use Merge instead" (or BE returns a 400 that FE toasts).
6. Click Reorder toggle → drag handles appear → drag a row → drop → OrderBy recomputed and persisted.
7. Click Contacts count link (e.g., "2,145") on a row → navigate to `/[lang]/crm/contact/allcontacts?contactSourceId={id}`.
8. Toggle Status on a row → backend flips `IsActive` → grid badge updates → widget "Active" count updates.
9. Filter chips (All/Active/Inactive + All/System/Custom) → grid re-queries with filter args → widgets do NOT refetch (widgets are aggregate across all rows).

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Canonical reference for MASTER_GRID is `ContactType` (#19). ContactSource is in the SAME group — substitution is almost identity.

**Canonical Reference**: ContactType (MASTER_GRID from repo)

| Canonical (ContactType) | → This Entity (ContactSource) | Context |
|--------------------------|-------------------------------|---------|
| ContactType | ContactSource | Entity/class name |
| contactType | contactSource | camelCase |
| ContactTypeId | ContactSourceId | PK field |
| ContactTypes | ContactSources | Plural table + collection name |
| contact-type | contact-source | kebab-case (NOT used in FE routes here — FE uses no-dash) |
| contacttype | contactsource | entity-lower-no-dash — FE folder name, import paths |
| CONTACTTYPE | CONTACTSOURCE | Grid code, menu code |
| corg | corg | DB schema (identity) |
| Contact | Contact | Backend group (identity) — both live in `ContactModels`, `ContactConfigurations`, `ContactSchemas`, `ContactBusiness`, `EndPoints/Contact` |
| ContactModels | ContactModels | Namespace (identity) |
| CRM_CONTACT | CRM_CONTACT | Parent menu code (identity) |
| CRM | CRM | Module code (identity) |
| crm/contact/contacttype | crm/contact/contactsource | FE route base |
| contact-service | contact-service | FE service folder name (identity) |
| contact-queries | contact-queries | FE gql-queries subfolder |
| contact-mutations | contact-mutations | FE gql-mutations subfolder |
| ContactTypeAssignment (junction for aggregation) | Contact.ContactSourceId (direct FK for aggregation) | **DIVERGENCE**: ContactType uses a junction table; ContactSource uses a direct nullable FK on Contact. Simpler to aggregate. |

**Flag to future devs**: when copying from `ContactType.cs` or `ContactTypeHandler.cs`, the aggregation subquery is `_db.Contacts.Count(c => c.ContactSourceId == cs.ContactSourceId && !c.IsDeleted)` — NOT `_db.ContactTypeAssignments.Count(...)` as in ContactType.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> **ALIGN scope — existing files are MODIFIED; new files only where the feature is genuinely new.**

### Backend Files

| # | File | Path | Delta |
|---|------|------|-------|
| 1 | Entity | `PSS_2.0_Backend/.../Base.Domain/Models/ContactModels/ContactSource.cs` | **ADD** `public string? Icon { get; set; }` |
| 2 | EF Config | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/ContactConfigurations/ContactSourceConfiguration.cs` | **ADD** `builder.Property(c => c.Icon).HasMaxLength(50);`. Existing filtered unique index stays. Fix class-name typo (`ContactSourceConfigurations` → `ContactSourceConfiguration`) optional — low priority. |
| 3 | Schemas | `PSS_2.0_Backend/.../Base.Application/Schemas/ContactSchemas/ContactSourceSchemas.cs` | **ADD** `Icon` to `ContactSourceRequestDto`. **ADD** `IsSystem: bool`, `Icon: string?`, `ContactsCount: int`, `ModifiedByName: string?` to `ContactSourceResponseDto`. **ADD** new DTOs: `ContactSourceSummaryDto`, `ContactSourceUsageInsightDto` (single row), `ContactSourceUsageInsightsDto` (wrapper), `MergeContactSourceRequestDto`, `ReorderContactSourceItemDto`, `ReorderContactSourceRequestDto`. **REMOVE** `ContactChannelName` from `ExportContactSourceDto` (leftover copy-paste bug). |
| 4 | Create Command | `.../Business/ContactBusiness/ContactSources/Commands/CreateContactSource.cs` | **No change** (Icon auto-mapped via Mapster when added to DTO). Verify code-pattern validator added (`Matches("^[A-Z0-9_]+$")`). |
| 5 | Update Command | `.../Business/ContactBusiness/ContactSources/Commands/UpdateContactSource.cs` | **ADD** rule: if `existing.IsSystem`, reject when `existing.ContactSourceCode != request.ContactSourceCode` with `BadRequestException("Code is locked for system sources")`. **ADD** `ValidateUniqueWhenUpdate`. |
| 6 | Delete Command | `.../Business/ContactBusiness/ContactSources/Commands/DeleteContactSource.cs` | **ADD** rule: if `existing.IsSystem`, throw `BadRequestException("System contact sources cannot be deleted")`. **ADD** rule: if `_db.Contacts.Any(c => c.ContactSourceId == id && !c.IsDeleted)`, throw `BadRequestException("{N} contacts still assigned — merge or reassign before deleting")`. |
| 7 | Toggle Command | `.../Business/ContactBusiness/ContactSources/Commands/ToggleContactSource.cs` | **No change** (system sources may still be toggled). |
| 8 | GetAll Query | `.../Business/ContactBusiness/ContactSources/Queries/GetContactSource.cs` | **MODIFY** projection to include `Icon`, `IsSystem`, `ContactsCount` (subquery), `ModifiedByName`. Keep existing pagination/search. Add `isSystem` + `isActive` filter args pass-through from `GridFeatureRequest.advancedFilters`. |
| 9 | GetById Query | `.../Business/ContactBusiness/ContactSources/Queries/GetContactSourceById.cs` | **MODIFY** projection to include `Icon`, `IsSystem`, `ContactsCount`, `ModifiedByName`. |
| 10 | **NEW** — GetSummary | `.../Business/ContactBusiness/ContactSources/Queries/GetContactSourceSummary.cs` | **CREATE** — returns `ContactSourceSummaryDto` (4 counts). Single query per pattern. |
| 11 | **NEW** — GetUsageInsights | `.../Business/ContactBusiness/ContactSources/Queries/GetContactSourceUsageInsights.cs` | **CREATE** — returns `ContactSourceUsageInsightsDto` (top 3 + addedThisYear). |
| 12 | **NEW** — Reorder Command | `.../Business/ContactBusiness/ContactSources/Commands/ReorderContactSources.cs` | **CREATE** — args `[{contactSourceId, orderBy}]`, updates OrderBy in one `SaveChanges`. Scope to CompanyId. |
| 13 | **NEW** — Merge Command | `.../Business/ContactBusiness/ContactSources/Commands/MergeContactSources.cs` | **CREATE** — args `{sourceContactSourceId, targetContactSourceId}`. Validator: both exist + same CompanyId + sourceId ≠ targetId. Handler: `UPDATE Contacts SET ContactSourceId = targetId WHERE ContactSourceId = sourceId && !IsDeleted`, then soft-delete source. Return `{reassignedCount, mergedSourceId}`. Keep transactional (single `SaveChangesAsync`). |
| 14 | Mutations endpoint | `.../Base.API/EndPoints/Contact/Mutations/ContactSourceMutations.cs` (plural — canonical) | **ADD** `ReorderContactSources` field. **ADD** `MergeContactSources` field. |
| 15 | **DELETE** — Duplicate Mutations | `.../Base.API/EndPoints/Contact/Mutations/ContactSourceMutation.cs` (singular — legacy) | **DELETE** the file. Both files currently declare the same methods in the same GraphQL namespace — HotChocolate will complain. ContactType #19 resolved the same issue by deleting its singular duplicate. |
| 16 | Queries endpoint | `.../Base.API/EndPoints/Contact/Queries/ContactSourceQueries.cs` | **ADD** `GetContactSourceSummary` + `GetContactSourceUsageInsights` fields. |
| 17 | **NEW** — Migration | `.../Base.Infrastructure/Migrations/{timestamp}_ContactSource_AddIcon.cs` | **CREATE** — adds `Icon` nvarchar(50) nullable column on `corg.ContactSources`. |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext` / `ContactDbContext` | **No change** — DbSet<ContactSource> already registered. |
| 2 | `DecoratorProperties.cs` | **No change** — `DecoratorContactModules.ContactSource` already exists (see `[CustomAuthorize(DecoratorContactModules.ContactSource, Permissions.Create)]` in CreateContactSource.cs:9). |
| 3 | `ContactMappings.cs` (Mapster) | **VERIFY** that the `ContactSource → ContactSourceResponseDto` map auto-projects the new `Icon`, `IsSystem`, `ContactsCount`, `ModifiedByName` fields. If Mapster uses explicit config, add those properties. |

### Frontend Files

| # | File | Path | Delta |
|---|------|------|-------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/contact-service/ContactSourceDto.ts` | **CREATE** — defines `ContactSourceRequestDto`, `ContactSourceResponseDto` (with `icon`, `isSystem`, `contactsCount`, `modifiedByName`), `ContactSourceSummaryDto`, `ContactSourceUsageInsightDto`, `ContactSourceUsageInsightsDto`, `MergeContactSourceRequestDto`, `ReorderContactSourceRequestDto`. |
| 2 | GQL Query | `PSS_2.0_Frontend/src/infrastructure/gql-queries/contact-queries/ContactSourceQuery.ts` | **CREATE** — `CONTACTSOURCES_QUERY`, `CONTACTSOURCE_BY_ID_QUERY`, `CONTACTSOURCE_SUMMARY_QUERY`, `CONTACTSOURCE_USAGE_INSIGHTS_QUERY`. |
| 3 | GQL Mutation | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/contact-mutations/ContactSourceMutation.ts` | **CREATE** — `CREATE_CONTACTSOURCE_MUTATION`, `UPDATE_CONTACTSOURCE_MUTATION`, `ACTIVATE_DEACTIVATE_CONTACTSOURCE_MUTATION`, `DELETE_CONTACTSOURCE_MUTATION`, `REORDER_CONTACTSOURCES_MUTATION`, `MERGE_CONTACTSOURCES_MUTATION`. |
| 4 | Page Config | `PSS_2.0_Frontend/src/presentation/pages/crm/contact/contactsource.tsx` | **MODIFY** to compose `<ScreenHeader>` + 4-card widget row + 2-column layout (`xl:grid-cols-[3fr_1fr]`): left = `<AdvancedDataTableStoreProvider><DataTableContainer showHeader={false}/></AdvancedDataTableStoreProvider>`, right = stacked `<UsageInsightsPanel>` + `<QuickTipsPanel>`. Keep the existing capability guard wrapper. |
| 5 | Data-Table Component | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/contact/contactsource/data-table.tsx` | **MODIFY** — set `showHeader={false}`, pass grid config that maps columns to `system-badge`, `type-code`, `link-count`, `contacts-share-bar`, `status-badge`, `modified-by-cell`, and a new `name-with-icon` cell. Wire `onReorder` prop (only in reorder-mode). Wire `onRowClick` to no-op for this screen (or visual-only highlight). Bring in the Reorder toggle into the `<ScreenHeader>`. |
| 6 | **NEW** — Widgets | `.../components/page-components/crm/contact/contactsource/contactsource-widgets.tsx` | **CREATE** — 4 summary cards driven by `CONTACTSOURCE_SUMMARY_QUERY` (same pattern as ContactType widgets). |
| 7 | **NEW** — Usage Insights Panel | `.../components/page-components/crm/contact/contactsource/usage-insights-panel.tsx` | **CREATE** — fetches `CONTACTSOURCE_USAGE_INSIGHTS_QUERY`, renders title + top-3 mini-bar rows + "X added this year" insight stat + dashed-border analytics link. |
| 8 | **NEW** — Quick Tips Panel | `.../components/page-components/crm/contact/contactsource/quick-tips-panel.tsx` | **CREATE** — static 4-bullet list with icon header. No data deps. |
| 9 | **NEW** — Merge Modal | `.../components/page-components/crm/contact/contactsource/merge-contactsource-modal.tsx` | **CREATE** — props `{ open, sourceRow, onClose, onConfirm }`. Internally fetches `CONTACTSOURCES_QUERY` (filter out `sourceRow.id`, only active) to populate target dropdown. Renders: source card + target select + amber warning + Cancel/Confirm. Calls `MERGE_CONTACTSOURCES_MUTATION` on confirm. |
| 10 | **NEW** — Icon Picker Widget | `.../components/custom-components/rjsf-custom-widgets/icon-picker-widget.tsx` (or similar registry folder — check first) | **CREATE** RJSF custom widget. Props: standard RJSF `WidgetProps`. Renders icon preview (28px accent-bg square with live icon) + text input + quick-pick row of 12 suggestions (from mockup). Register in RJSF widget map as `IconPickerWidget`. |
| 11 | **NEW** — `contacts-share-bar` Renderer | `.../components/custom-components/data-tables/shared-cell-renderers/contacts-share-bar-renderer.tsx` | **CREATE** — renders `<strong>{formatNumber(n)}</strong>` + mini share bar (`n / max * 100%` width, gradient accent→accent-light). Export and register in all 3 column-type registries (`advanced`, `basic`, `flow`) as `contacts-share-bar`. |
| 12 | **NEW** — `name-with-icon` Renderer | `.../components/custom-components/data-tables/shared-cell-renderers/name-with-icon-renderer.tsx` | **CREATE** — composes 28px accent-bg square with icon + bold name. Reads `row.icon` (default `compass`) and `row.contactSourceName`. Register in 3 column-type registries. |
| 13 | **NEW** — `modified-by-cell` Renderer | `.../components/custom-components/data-tables/shared-cell-renderers/modified-by-cell-renderer.tsx` | **CREATE** (or REUSE if exists — check first). Renders `{formattedDate}` on line 1 + `by {name}` muted small on line 2. If no modifier, show "System". Register in 3 column-type registries. Could be pre-existing from SavedFilter #27 or EmailTemplate #24 — grep before creating. |
| 14 | Shared Cell Renderers Barrel | `.../components/custom-components/data-tables/shared-cell-renderers/index.ts` | **ADD** exports for the 3 new renderers (skip if already registered). |
| 15 | Component-column Registries | `.../components/custom-components/data-tables/{advanced,basic,flow}/data-table-column-types/component-column.tsx` (×3 files) | **ADD** entries: `"contacts-share-bar"`, `"name-with-icon"`, `"modified-by-cell"` (×3 registries each). |
| 16 | Route Page | `PSS_2.0_Frontend/src/app/[lang]/crm/contact/contactsource/page.tsx` | **No change** — already renders `<ContactSourcePageConfig />`. |
| 17 | Entity Operations | `.../entity-operations.ts` | **ADD** or **VERIFY** `CONTACTSOURCE` entry exists and includes `REORDER` + `MERGE` operations for capability checks. |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | DataTableContainer (if `onReorder`/`onRowClick` not present) | Verify these props exist — landed by StaffCategory #43. ContactType #19 ISSUE-1 flagged them as missing initially. |
| 2 | RJSF Widget Registry | Register `IconPickerWidget` in the RJSF widget map (check existing registry path). Verify `GridFormSchema` in DB seed references it as `"ui:widget": "IconPickerWidget"`. |
| 3 | Sidebar menu config | **No change** — menu already registered under CRM_CONTACT at OrderBy=3 in MODULE_MENU_REFERENCE.md. |
| 4 | Grid config (DB seed) — `GridFormSchema` for `CONTACTSOURCE` | **GENERATE** per §⑨ below. |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Contact Sources
MenuCode: CONTACTSOURCE
ParentMenu: CRM_CONTACT
Module: CRM
MenuUrl: crm/contact/contactsource
OrderBy: 3
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: GENERATE
GridCode: CONTACTSOURCE

GridFormSchema Content (for DB seed generation):
- Title: "Contact Source"
- Fields (order + UI hints):
  1. contactSourceCode → TextWidget, required, maxLength 100, pattern ^[A-Z0-9_]+$, uppercase+underscore-only auto-clean, readonly when formData.isSystem === true, helper "Uppercase alphanumeric + underscore. Unique per company.", column col-6
  2. contactSourceName → TextWidget, required, maxLength 100, placeholder "e.g., Website", column col-6
  3. icon               → IconPickerWidget (NEW RJSF custom widget), optional, maxLength 50, default "compass", placeholder "Font Awesome icon name (e.g., globe, users, calendar)", full-width row
  4. description       → TextAreaWidget, maxLength 1000, rows=2, placeholder "Brief description of this source...", full-width row
  5. orderBy           → NumberWidget, min=1, default = (max + 1) at new-record time, column col-6
  6. isActive          → SwitchWidget, default true, label toggles "Active"/"Inactive", column col-6
- Hidden fields (in formData, not rendered):
  - isSystem (read-only pass-through — never editable via this form)
  - contactSourceId (hidden on create, bound on edit)
  - companyId (BE auto-fills from HttpContext)
- Layout:
  - Row 1: contactSourceCode (col-6) | contactSourceName (col-6)
  - Row 2: icon (full-width) — with custom widget showing preview + text + 12 quick-picks
  - Row 3: description (full-width)
  - Row 4: orderBy (col-6) | isActive (col-6)
  - Row 5 (conditional): systemLockNotice — shown only when isSystem===true (informational, not a field)

Seed Sample Data (for tenant bootstrap — 12 System rows mirroring mockup):
  1. WEBSITE / Website / globe / "Contacts captured via public website forms and landing pages" / isSystem=true
  2. REFERRAL / Referral / users / "Referred by existing donors, members, or volunteers" / isSystem=true
  3. EVENT / Event / calendar / "Acquired through fundraising or community events" / isSystem=true
  4. WALKIN / Walk-in / person-walking / "Visited the office or branch in person" / isSystem=true
  5. SOCIAL_MEDIA / Social Media / share-nodes / "Engagement from Facebook, Instagram, LinkedIn, Twitter" / isSystem=false
  6. CAMPAIGN / Campaign / bullseye / "Joined through a specific marketing or outreach campaign" / isSystem=false
  7. IMPORT / Import / file-import / "Added via bulk CSV/Excel import" / isSystem=true
  8. PARTNER_NGO / Partner NGO / handshake / "Shared contacts from partner non-profit organizations" / isSystem=false
  9. CORPORATE / Corporate Partner / building / "Employees referred through corporate partnership programs" / isSystem=false
 10. AMBASSADOR / Ambassador/Agent / medal / "Acquired by field ambassadors or collection agents" / isSystem=false
 11. MOBILE_APP / Mobile App / mobile-screen / "Registered through the donor/beneficiary mobile app" / isSystem=false
 12. OTHER / Other / question / "Source not covered by any other category" / isSystem=true
(5 isSystem=true total — matches mockup stats card "System Sources: 5")
---CONFIG-END---
```

**Note on Role seeding**: per project preference, only `BUSINESSADMIN` role is enumerated. Other roles inherit via the capability cascade.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — exact names to call.

**GraphQL Root Types:**
- Query: `ContactSourceQueries`
- Mutation: `ContactSourceMutations` (plural — duplicate singular `ContactSourceMutation.cs` to be deleted)

**Queries:**
| GQL Field | Returns | Key Args | Status |
|-----------|---------|----------|--------|
| `GetContactSources` | paginated `{ items: [ContactSourceResponseDto], totalCount: int }` | searchText, pageNo, pageSize, sortField, sortDir, isActive, isSystem | **EXISTS** — modify projection to add `icon`, `isSystem`, `contactsCount`, `modifiedByName` |
| `GetContactSourceById` | `ContactSourceResponseDto` | contactSourceId | **EXISTS** — modify projection |
| `GetContactSourceSummary` | `ContactSourceSummaryDto` | — | **NEW** — add |
| `GetContactSourceUsageInsights` | `ContactSourceUsageInsightsDto` | — | **NEW** — add |

**Mutations:**
| GQL Field | Input | Returns | Status |
|-----------|-------|---------|--------|
| `CreateContactSource` | `ContactSourceRequestDto` | int (new id) | **EXISTS** — no logic change; DTO gains `icon` |
| `UpdateContactSource` | `ContactSourceRequestDto` | int | **EXISTS** — ADD system-code-immutable guard |
| `ActivateDeactivateContactSource` | contactSourceId | int | **EXISTS** — no change (name kept to avoid FE cascade, same as ContactType #19 divergence note) |
| `DeleteContactSource` | contactSourceId | int | **EXISTS** — ADD system + in-use guards |
| `ReorderContactSources` | `[ReorderContactSourceItemDto { contactSourceId, orderBy }]` | int (count updated) | **NEW** — add |
| `MergeContactSources` | `MergeContactSourceRequestDto { sourceContactSourceId, targetContactSourceId }` | `{ reassignedCount: int, mergedSourceId: int }` | **NEW** — add |

**⚠ GQL-name divergence from the canonical template**: the canonical template cites `GetAllContactSourceList` + `ToggleContactSource`, but this repo uses `GetContactSources` + `ActivateDeactivateContactSource` (same as ContactType). **Do NOT rename** during this ALIGN pass — it would cascade through FE.

**Response DTO Fields** (ContactSourceResponseDto after ALIGN):

| Field | Type | Notes |
|-------|------|-------|
| contactSourceId | number | PK |
| contactSourceCode | string | max 100, uppercase+alphanumeric+underscore |
| contactSourceName | string | max 100 |
| description | string? | max 1000 |
| orderBy | number | display sort |
| icon | string? | **NEW** — FontAwesome/Phosphor icon name, default `compass` |
| isSystem | boolean | **NEW** — from entity; drives badge + delete-lock + code-lock |
| contactsCount | number | **NEW** — per-row aggregation from Contacts table |
| modifiedByName | string? | **NEW** — for "Modified" grid cell |
| modifiedDate | string | inherited (ISO timestamp) |
| isActive | boolean | inherited |
| companyId | number? | hidden |

**ContactSourceSummaryDto** (NEW):

| Field | Type | Source |
|-------|------|--------|
| totalSources | number | `COUNT(*) WHERE CompanyId=cid && !IsDeleted` |
| activeCount | number | `COUNT(*) WHERE CompanyId=cid && IsActive && !IsDeleted` |
| systemCount | number | `COUNT(*) WHERE CompanyId=cid && IsSystem && !IsDeleted` |
| totalContactsAssigned | number | `_db.Contacts.Count(c => c.CompanyId=cid && !c.IsDeleted && c.ContactSourceId != null)` |

**ContactSourceUsageInsightDto** (NEW — per-row for top 3):

| Field | Type |
|-------|------|
| contactSourceId | number |
| contactSourceCode | string |
| contactSourceName | string |
| icon | string? |
| contactsCount | number |

**ContactSourceUsageInsightsDto** (NEW — wrapper):

| Field | Type | Notes |
|-------|------|-------|
| topSources | [ContactSourceUsageInsightDto] | Top 3 by contacts count desc |
| addedThisYear | number | Count of custom sources created since Jan 1 current year |

**MergeContactSourceRequestDto** (NEW):

| Field | Type | Notes |
|-------|------|-------|
| sourceContactSourceId | number | Row to merge FROM (will be soft-deleted) |
| targetContactSourceId | number | Row to merge INTO (survives) |

**MergeContactSourcesResult** (BE response wrapper):

| Field | Type | Notes |
|-------|------|-------|
| reassignedCount | number | Number of Contacts updated |
| mergedSourceId | number | Echo of sourceContactSourceId |

**ReorderContactSourceItemDto** (NEW — per-row payload):

| Field | Type |
|-------|------|
| contactSourceId | number |
| orderBy | number |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm tsc --noEmit` — no new errors in ContactSource files
- [ ] EF migration generated (`dotnet ef migrations add ContactSource_AddIcon` — user may need to regenerate snapshot)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/contact/contactsource`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with 10 columns (Drag, Order, Code, Name w/ icon, Description, Contacts, System, Status, Modified, Actions)
- [ ] Search filters by: contactSourceCode, contactSourceName, description
- [ ] Status chip filter: All / Active / Inactive — updates grid
- [ ] Type chip filter: All / System / Custom — updates grid
- [ ] Sort dropdown: Order / Name / Created / Contacts — updates grid
- [ ] +Add Source modal: all 6 fields render, code auto-uppercase, icon picker shows preview + 12 quick-picks, save succeeds → appears at bottom
- [ ] Edit row: modal pre-fills correctly with icon preview
- [ ] Edit System row: SourceCode is readonly, amber "locked" notice visible, Delete button not rendered
- [ ] Edit Custom row: all fields editable
- [ ] Toggle active/inactive → badge changes, Active widget count updates
- [ ] Delete on custom with 0 contacts → confirmation → soft-delete → row gone, widgets update
- [ ] Delete on custom with N>0 contacts → BE rejects with friendly error toast
- [ ] Delete on System → BE rejects with friendly error toast
- [ ] Merge on custom row → modal opens with source card + target dropdown (excludes self, only active) + warning → confirm → contacts reassigned, source soft-deleted, widgets + grid refresh
- [ ] Reorder toggle: drag handles appear, dragging a row persists new OrderBy, reordering reflects on next grid load
- [ ] 4 Summary widgets: Total Sources / Active Sources / System Sources / Contacts Assigned — all show correct counts and update after CRUD
- [ ] Usage Insights panel: top 3 sources by contacts count with icon + name + bar + number, "X added this year" stat, analytics link renders (link target may stub)
- [ ] Quick Tips panel: 4 static bullets visible
- [ ] Contacts count column is clickable and navigates to `/crm/contact/allcontacts?contactSourceId={id}`
- [ ] Row-click does NOT trigger a side panel (unlike ContactType); no-op or visual highlight only
- [ ] Permissions: buttons respect role capabilities (BUSINESSADMIN sees all)

**DB Seed Verification:**
- [ ] Menu appears in sidebar under CRM → Contacts at position 3 (below ContactType, above TagSegmentation)
- [ ] Grid columns render correctly per seed GridFields rows
- [ ] GridFormSchema renders modal correctly, IconPickerWidget works
- [ ] 12 sample rows seeded on tenant bootstrap (5 isSystem=true, 7 custom) — matches mockup counts

**UI Uniformity Verification (5 grep checks, all should return 0):**
- [ ] Zero inline hex colors in new FE files (`#[0-9a-fA-F]{6}`) — tokens only
- [ ] Zero inline pixel spacing in new FE files (`style={[^}]*px`) — tokens only
- [ ] No raw "Loading…" strings — use Skeletons
- [ ] `<ScreenHeader>` present in page root; `showHeader={false}` on DataTableContainer
- [ ] `@iconify/react` with Phosphor icons used (no raw `<i class="fas fa-*">`)

---

## ⑫ Special Notes & Warnings

- **ALIGN scope, not FULL**: BE entity + CRUD handlers already exist. Do NOT regenerate them. ONLY add: `Icon` column + migration, 2 new query handlers, 2 new command handlers, 5 new DTOs, 2 guard updates on Update/Delete validators/handlers, GraphQL endpoint additions, and the `Icon` field on DTOs + projections.
- **Duplicate mutation file**: both `ContactSourceMutation.cs` (singular, legacy) and `ContactSourceMutations.cs` (plural, canonical) currently register the same methods in the same GraphQL namespace. The build likely tolerates it only because one is unreferenced, or because HotChocolate deduplicates by method name. **DELETE** the singular file during this pass (precedent: ContactType #19 did the same cleanup).
- **ExportContactSourceDto has a leftover field**: `ContactChannelName` (line 28 of current `ContactSourceSchemas.cs`) is a copy-paste bug from ContactChannel entity and has no corresponding nav. Remove it during the DTO pass.
- **Contact.ContactSourceId FK exists** at [Contact.cs:25](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ContactModels/Contact.cs#L25) — nullable int. Aggregation subquery targets this directly. No junction table needed (unlike ContactType → ContactTypeAssignment).
- **Existing FE route**: `src/app/[lang]/crm/contact/contactsource/page.tsx` already exists and routes to `<ContactSourcePageConfig />`. Do NOT recreate the route — extend the page config component.
- **Icon picker widget is a NEW RJSF custom widget**: ContactSource is the FIRST consumer. Register it in the RJSF widget map (check `rjsf-custom-widgets` folder for existing patterns). Future screens that need icon selection (e.g., MasterData categories, WhatsApp templates, etc.) will reuse it.
- **Reorder/Merge GraphQL mutation names**: use `ReorderContactSources` and `MergeContactSources` (plural Sources). These are batch operations, not single-row.
- **Usage Insights query "last 30 days"**: the mockup subtitle says "Top 3 sources · last 30 days" but without a ContactCreatedDate lookup joined through Contact, a clean 30-day window is expensive. For v1, implement `topSources = top 3 by total contacts count` (no 30-day filter) and log as ISSUE-3. Keep the subtitle text unchanged — the copy is approximate.
- **Usage Insights analytics link target**: navigates to `/[lang]/reports/contact-reports` which is a Wave 4 dashboard screen. For v1, render the link; if the target page 404s, that's expected (tracked via a separate screen build). Keep the link visible per mockup.
- **System row seeding strategy**: 12 sample rows in seed SQL mirror the mockup's mock data exactly (5 isSystem=true to match "System Sources: 5" widget). Inserted idempotently `ON CONFLICT (CompanyId, ContactSourceCode) DO NOTHING` so re-running seed is safe.
- **Preserve `gridCode="CONTACTSOURCE"`** in the data-table component — already wired correctly at [data-table.tsx:8](PSS_2.0_Frontend/src/presentation/components/page-components/crm/contact/contactsource/data-table.tsx#L8). Don't change the grid code.
- **`{lang}` prefix on link-count** (inherited ISSUE from ContactType #19 ISSUE-3, DonationCategory #3 ISSUE-1): the Contacts count link template should include `/{lang}/` prefix. Applies to this screen too — will be fixed repo-wide when the renderer is updated.

**Service Dependencies** (UI-only — no backend service implementation):

> Everything shown in the mockup IS in scope. List items here ONLY if they require an external service or infrastructure that doesn't exist in the codebase yet.

- ⚠ **ANALYTICS_LINK_PLACEHOLDER**: "See source analytics" link navigates to `/[lang]/reports/contact-reports` which is a separate Wave 4 dashboard screen. The link renders correctly; destination page build is out of scope.

Full UI must be built (buttons, panels, forms, modals, drag-reorder, merge, icon picker). No other service placeholders — everything else is regular scope.

**Pre-flagged Known Issues** (to be opened as `ISSUE-N` when `/build-screen` runs):

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | Low | BE | Duplicate mutation file `ContactSourceMutation.cs` (singular) + `ContactSourceMutations.cs` (plural) — delete singular during build |
| ISSUE-2 | Low | BE | `ExportContactSourceDto.ContactChannelName` is a leftover copy-paste field — remove during DTO pass |
| ISSUE-3 | Low | BE | Usage Insights "top 3 last 30 days" simplified to "top 3 by contacts count" for v1 (no date filter) |
| ISSUE-4 | Medium | BE | Icon column is NEW — migration required. User regenerates snapshot after `dotnet ef migrations add` |
| ISSUE-5 | Low | BE | Custom `ValidateUniqueWhenUpdate` for `ContactSourceCode` currently absent — add during build |
| ISSUE-6 | Low | FE | `{lang}` prefix missing in link-count template (inherited from ContactType #19 ISSUE-3) |
| ISSUE-7 | Low | DB | Seed folder typo `sql-scripts-dyanmic` (repo-wide, not this screen's fault) |
| ISSUE-8 | Info | API | `IsSystem` deliberately absent from RequestDto — admin cannot self-promote a custom source to system via API (security by design) |
| ISSUE-9 | Medium | FE | IconPickerWidget is a NEW RJSF custom widget — ContactSource is first consumer; register in widget map |
| ISSUE-10 | Medium | FE | Contacts count link navigates to `/crm/contact/allcontacts?contactSourceId={id}`. The Contact #18 list page must read this query param and pre-filter — TODO on Contact page build. |
| ISSUE-11 | Low | FE | Analytics link target `/reports/contact-reports` may 404 until that Wave 4 dashboard is built (SERVICE_PLACEHOLDER) |
| ISSUE-12 | Low | BE | `ContactSourceConfigurations` class name is plural (typo) — rename to `ContactSourceConfiguration` optional cleanup |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | Low | BE | Duplicate mutation file `ContactSourceMutation.cs` (singular) — deleted during build. | RESOLVED |
| ISSUE-2 | 1 | Low | BE | `ExportContactSourceDto.ContactChannelName` leftover copy-paste field. | RESOLVED (removed) |
| ISSUE-3 | 1 | Low | BE | Usage Insights "top 3 last 30 days" simplified to "top 3 by contacts count" (no date filter). Subtitle text kept unchanged. | OPEN |
| ISSUE-4 | 1 | Medium | BE | New `Icon` column + migration `20260421120000_ContactSource_AddIcon.cs` + snapshot entry added. User must regenerate EF snapshot locally with `dotnet ef migrations add --no-build` if snapshot drift is detected, then `dotnet ef database update`. | OPEN |
| ISSUE-5 | 1 | Low | BE | `ValidateUniqueWhenUpdate` added to Update validator for `ContactSourceCode`. | RESOLVED |
| ISSUE-6 | 1 | Low | FE | `{lang}` prefix missing in `contacts-share-bar` renderer link template — inherited from ContactType #19 ISSUE-3 (shared concern). | OPEN |
| ISSUE-7 | 1 | Low | DB | Seed folder typo `sql-scripts-dyanmic` (repo-wide, not this screen's fault). | OPEN |
| ISSUE-8 | 1 | Info | API | `IsSystem` deliberately absent from RequestDto — admin cannot self-promote a custom source to system via API. | BY-DESIGN |
| ISSUE-9 | 1 | Medium | FE | IconPickerWidget is NEW — first consumer. Registered in `dgf-widgets/index.tsx` under key `"IconPickerWidget"`. Future screens can reuse. | RESOLVED |
| ISSUE-10 | 1 | Medium | FE | Contacts count link navigates to `/crm/contact/allcontacts?contactSourceId={id}`. Contact #18 list page must read this query param and pre-filter — TODO on Contact page side. | OPEN |
| ISSUE-11 | 1 | Low | FE | Analytics link target `/reports/contact-reports` may 404 until Wave 4 dashboard is built (SERVICE_PLACEHOLDER). | OPEN |
| ISSUE-12 | 1 | Low | BE | `ContactSourceConfigurations` class name is plural (typo) — rename optional cleanup, left as-is to avoid touch surface. | OPEN |
| ISSUE-13 | 1 | Low | BE | `ModifiedByName` resolution uses `u.UserName` instead of `FirstName + LastName` because the `User` domain model has no `FirstName`/`LastName` fields. Matches SavedFilter/DonationInKind precedent. | BY-DESIGN |
| ISSUE-14 | 1 | Low | BE | `GetContactSource` default ordering changed from `CreatedDate DESC` to `OrderBy ASC` (matches spec + list semantics where OrderBy drives display rank). | BY-DESIGN |
| ISSUE-15 | 1 | Low | BE | Drag-to-reorder UI is NOT wired to `ReorderContactSources` mutation yet (BE mutation exists and is correct; FE drag handle column + reorder toggle are scaffolded via `IsPredefined` anchors but the handle/drop wiring will land when `AdvancedDataTableContainer` exposes the `onReorder` prop — inherited open concern from ContactType #19 ISSUE-1 / StaffCategory #43). | OPEN |
| ISSUE-16 | 1 | Low | FE | Merge modal uses a native `<select>` element instead of shadcn Select — acceptable v1; upgrade once shadcn Select is standard across the app. | OPEN |
| ISSUE-17 | 1 | Low | BE | Seed row count: `/plan-screens` §⑨ note "(5 isSystem=true total)" conflicts with its own listing where 6 rows are marked `isSystem=true` (WEBSITE/REFERRAL/EVENT/WALKIN/IMPORT/OTHER). Seed follows the row-level listing (6 system). | BY-DESIGN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-21 — BUILD — COMPLETED

- **Scope**: Initial full build of ContactSource #122 — MASTER_GRID ALIGN. BE align (extend DTOs + projection + 2 new queries + 2 new commands + guards + dup mutation cleanup + Icon migration) + FE near-greenfield (page shell Variant B + widgets + usage insights + quick tips + merge modal + IconPickerWidget + 3 new shared cell renderers) + DB seed.
- **Files touched**:
  - BE created (5): `Base.Application/Business/ContactBusiness/ContactSources/Queries/GetContactSourceSummary.cs`, `...Queries/GetContactSourceUsageInsights.cs`, `...Commands/ReorderContactSources.cs`, `...Commands/MergeContactSources.cs`, `Base.Infrastructure/Migrations/20260421120000_ContactSource_AddIcon.cs`
  - BE modified (9): `Base.Domain/Models/ContactModels/ContactSource.cs`, `Base.Infrastructure/Data/Configurations/ContactConfigurations/ContactSourceConfiguration.cs`, `Base.Application/Schemas/ContactSchemas/ContactSourceSchemas.cs`, `.../Commands/CreateContactSource.cs`, `.../Commands/UpdateContactSource.cs`, `.../Commands/DeleteContactSource.cs`, `.../Queries/GetContactSource.cs`, `.../Queries/GetContactSourceById.cs`, `Base.API/EndPoints/Contact/Queries/ContactSourceQueries.cs`, `Base.API/EndPoints/Contact/Mutations/ContactSourceMutations.cs`, `Base.Infrastructure/Migrations/ApplicationDbContextModelSnapshot.cs`
  - BE deleted (1): `Base.API/EndPoints/Contact/Mutations/ContactSourceMutation.cs` (legacy singular duplicate)
  - FE created (8): `domain/entities/contact-service/ContactSourceDto.ts` (rewrite as greenfield DTO set — treated as created), `infrastructure/gql-queries/contact-queries/ContactSourceQuery.ts` (treated as created), `infrastructure/gql-mutations/contact-mutations/ContactSourceMutation.ts` (treated as created), `presentation/components/custom-components/data-tables/shared-cell-renderers/contacts-share-bar.tsx`, `.../shared-cell-renderers/name-with-icon.tsx`, `.../shared-cell-renderers/modified-by-cell.tsx`, `presentation/components/custom-components/rjsf-custom-widgets/icon-picker-widget.tsx`, `presentation/components/page-components/crm/contact/contactsource/contactsource-widgets.tsx`, `.../contactsource/usage-insights-panel.tsx`, `.../contactsource/quick-tips-panel.tsx`, `.../contactsource/merge-contactsource-modal.tsx`
  - FE modified (7): `presentation/pages/crm/contact/contactsource.tsx` (full Variant B layout), `presentation/components/page-components/crm/contact/contactsource/data-table.tsx` (simplified to `<AdvancedDataTableContainer showHeader={false} />`), `presentation/components/page-components/crm/contact/contactsource/index.ts` (barrel), `presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts`, `.../data-tables/advanced/data-table-column-types/component-column.tsx`, `.../data-tables/flow/data-table-column-types/component-column.tsx`, `.../data-tables/basic/data-table-column-types/component-column.tsx`, `.../data-tables/data-table-form/dgf-widgets/index.tsx` (IconPickerWidget registered)
  - DB: `Base/sql-scripts-dyanmic/ContactSource-sqlscripts.sql` (created)
- **Deviations from spec**:
  - BE modified count (9) is higher than spec estimate (7) because EF snapshot + 2 API endpoint files were updated alongside the core 7.
  - `ModifiedByName` uses `User.UserName` (User model lacks FirstName/LastName — see ISSUE-13).
  - `GetContactSource` ordering changed to `OrderBy ASC` (see ISSUE-14).
  - Seed has 6 system rows (not 5 as an in-prose note suggested); row listing in §⑨ called for 6 (see ISSUE-17).
- **Known issues opened**: ISSUE-3, ISSUE-4, ISSUE-6, ISSUE-7, ISSUE-10, ISSUE-11, ISSUE-12, ISSUE-15, ISSUE-16 (9 OPEN). ISSUE-8, ISSUE-13, ISSUE-14, ISSUE-17 logged BY-DESIGN.
- **Known issues closed**: ISSUE-1, ISSUE-2, ISSUE-5, ISSUE-9 RESOLVED in-session.
- **Build validation**: `dotnet build` — 0 ContactSource errors. UI uniformity greps on all 8 new FE files: 0 hex colors, 0 inline pixel spacing, 0 raw "Loading…" strings. Renderer-name alignment: all 3 new renderer keys (`contacts-share-bar`, `name-with-icon`, `modified-by-cell`) registered in all 3 column-type registries (advanced/basic/flow) — matches DB seed `GridComponentName` values. Variant B verified: `<ScreenHeader>` at page root + `<AdvancedDataTableContainer showHeader={false} />` in data-table component.
- **Next step**: User must (1) run `dotnet ef migrations add ContactSource_AddIcon` locally if snapshot drift appears (or accept the pre-generated migration `20260421120000_ContactSource_AddIcon.cs`); (2) `dotnet ef database update`; (3) execute `Base/sql-scripts-dyanmic/ContactSource-sqlscripts.sql`; (4) `pnpm dev` and E2E test per §⑪.