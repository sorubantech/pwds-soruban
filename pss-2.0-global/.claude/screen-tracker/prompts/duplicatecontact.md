---
screen: DuplicateContact
registry_id: 21
module: CRM / Contacts — Maintenance
status: COMPLETED
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-19
completed_date: 2026-04-21
last_session_date: 2026-04-21
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (`html_mockup_screens/screens/contacts/duplicate-merge.html`, 1284 lines)
- [x] Existing code reviewed (BE entity + 6 handlers + 2 queries + 3 GQL mutations; FE index-page + view-page + DTO + queries)
- [x] Business rules + workflow extracted (4-state action workflow: Pending → Merged | NotDuplicate | Ignored)
- [x] FK targets resolved (paths + GQL queries verified — see §③)
- [x] File manifest computed (§⑧ — ALIGN scope, modify-not-regenerate)
- [x] Approval config pre-filled (menu pre-seeded as `DUPLICATECONTACT` under `CRM_MAINTENANCE`)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (skipped — prompt has deep Sections ①–⑫, Family #20 precedent)
- [x] Solution Resolution complete (skipped — deep prompt pattern)
- [x] UX Design finalized (skipped — deep prompt pattern)
- [x] User Approval received (pre-authorized via /build-screen bulk permission grant)
- [x] Backend code generated (2 created: NotDuplicateContact, GetDuplicateContactSummary; 5 modified incl. .Include(Action) CRITICAL fix + post-projection pipeline)
- [x] Backend wiring complete (Queries.cs + Mutations.cs + ContactMappings.cs updated)
- [x] Frontend code generated (8 created: Zustand store, widgets, filter-bar, field-match-row, pending-pair-card, resolved-pair-card, merge-modal, index-page rewrite; 4 modified: DTO, GQL Q/M, view-page)
- [x] Frontend wiring complete (router left unchanged — already dispatches correctly; MergeModal global via index-page root)
- [x] DB Seed script updated (DUPLICATECATEGORY type+4 values added idempotent, CONTACTSTATUS PEN/MRG/IGN+NDP idempotent)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `crm/maintenance/duplicatecontact`
- [ ] 4 KPI widgets show correct counts (TotalDetected / PendingReview / MergedThisMonth / NotDuplicate)
- [ ] Filter chip bar works: All / Pending Review / Merged / Not Duplicate / Ignored
- [ ] Category dropdown filters pairs by DuplicateCategory (Name / Email / Phone / Multi)
- [ ] Sort dropdown sorts by Confidence ↓/↑ and DetectedDate ↓/↑
- [ ] Pair card renders side-by-side comparison with field-match highlights (exact/similar/missing)
- [ ] Row click on pair card → navigates to `?mode=read&id=X` → view-page DETAIL
- [ ] Merge → button on pair card opens Merge Modal inline (primary+secondary boxes, 5-field radio table, transfer summary, warning)
- [ ] Merge Modal Confirm fires `mergeContacts` mutation → refreshes list → pair shows as "Merged" resolved card
- [ ] Not Duplicate button fires `notDuplicateContact` mutation → pair shows as resolved card
- [ ] Ignore button fires `ignoreDuplicateContact` mutation → pair disappears from Pending chip
- [ ] `?mode=manual` — manual merge FORM layout loads with 2 contact-code search inputs
- [ ] `?mode=read&id=X` — DETAIL layout loads existing view-page comparison UI
- [ ] Run Detection header button fires `detectDuplicateContacts` → toast → reload
- [ ] Resolved-card shows for Merged/NotDuplicate/Ignored with correct badge and reason
- [ ] Unsaved changes dialog triggers on manual-mode dirty form
- [ ] DB Seed — menu still visible under CRM → Maintenance (no regression)

---

## ① Screen Identity & Context

**Screen**: DuplicateContact (Duplicate Detection)
**Module**: CRM / Contacts — Maintenance
**Schema**: `corg`
**Group**: ContactModels / ContactSchemas / ContactBusiness

**Business**:
NGO CRMs inevitably collect duplicate contact records — imports from multiple sources, volunteers re-entering donor info, form submissions with typos, etc. Duplicate Detection surfaces likely-duplicate pairs and lets data stewards (ADMIN / BUSINESSADMIN / MANAGER) decide the resolution: **Merge** (keep one record, transfer donations/emails/phones/relationships to it, deactivate the other), **Not Duplicate** (confirm they're actually different people), or **Ignore** (hide from queue without confirming). Detection is triggered manually via "Run Detection" which calls the PostgreSQL function `corg.fn_detect_duplicate_contacts` to scan all active contacts and populate the `DuplicateContacts` queue. Each pair is categorized (Name+DOB, Name+Mobile, Name+Email, Manual) and displayed with a computed confidence level (High / Medium / Low) based on how many identifying fields match. The merge itself runs through `corg.fn_merge_contacts` which atomically re-points FK references and marks the secondary contact inactive. The read-mode detail view provides a deeper side-by-side comparison (child collection counts — donations, addresses, phones, emails, relationships) so the data steward can see the full downstream impact before confirming a merge. The screen is mounted under `CRM → Maintenance` because it's a housekeeping tool, not a day-to-day operational screen.

---

## ② Entity Definition

**ALIGN scope**: Entity already exists in `Base.Domain/Models/ContactModels/DuplicateContact.cs`. DO NOT regenerate. Existing schema below for reference — only DTO extensions are in scope (§⑩).

**Table**: `corg."DuplicateContacts"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| DuplicateContactId | int | — | PK | — | Primary key |
| ContactFromId | int | — | YES | corg.Contacts | The "left" contact in the pair |
| ContactToId | int | — | YES | corg.Contacts | The "right" contact in the pair |
| DuplicateCategoryId | int | — | YES | sett.MasterDatas (TypeCode=`DUPLICATECATEGORY`) | Name+DOB / Name+Mobile / Name+Email / Manual |
| ActionId | int | — | YES | sett.MasterDatas (TypeCode=`CONTACTSTATUS`) | PEN / MRG / NDP / IGN |
| ValidContactId | int? | — | NO | corg.Contacts | Set on Merge — the kept (primary) contact |
| MergedContactId | int? | — | NO | corg.Contacts | Set on Merge — the deactivated (secondary) contact |
| ActionByUserId | int? | — | NO | sett.Users | User who resolved the pair |
| ActionDate | DateTime? | — | NO | — | When action was taken |
| DetectedDate | DateTime | — | YES | — | When pair was created (default UtcNow) |
| CompanyId | int | — | YES | sett.Companies | Tenant — NOT a form field |

**Child Entity**:

| Child | Relationship | Key Fields |
|-------|--------------|-----------|
| DuplicateContactLog | 1:Many via DuplicateContactId | EntityTypeId (MasterData TypeCode=`ENTITYTYPE`), ReferenceId — audit trail of what was transferred during merge. Already defined in `DuplicateContactSchemas.cs` but no GQL endpoint. Out of scope for this ALIGN pass — detection has not started writing logs yet. Keep as-is. |

---

## ③ FK Resolution Table

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|---------------|------------------|----------------|---------------|-------------------|
| ContactFromId / ContactToId / ValidContactId / MergedContactId | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | `getContacts` (paginated) + `getContactByCode` (single — used by manual merge) | `displayName` (+`contactCode` identifier) | `ContactResponseDto` (defined in `ContactSchemas.cs` line 138) |
| DuplicateCategoryId | MasterData | `Base.Domain/Models/SettingModels/MasterData.cs` | `getMasterDatas` (paginated; filter client-side by `MasterDataType.TypeCode="DUPLICATECATEGORY"`) | `dataName` (+`dataValue` identifier) | `MasterDataRequestDto` |
| ActionId | MasterData | same | `getMasterDatas` (filter `TypeCode="CONTACTSTATUS"`, values PEN/MRG/NDP/IGN) | `dataName` | `MasterDataRequestDto` |
| ActionByUserId | User | `Base.Domain/Models/SettingModels/User.cs` | `getUsers` (paginated) | `userName` | `UserRequestDto` |
| CompanyId | Company | `Base.Domain/Models/SettingModels/Company.cs` | — (HttpContext) | — | — |

**ContactResponseDto display surface** used for comparison in mockup:
- Identifiers: `contactCode`, `displayName` (combined from `firstName` + `middleName` + `lastName`)
- Contact info: primary email (from `contactEmailAddresses[isPrimary=true]`), primary phone (from `contactPhoneNumbers[isPrimary=true]`), primary address (from `contactAddresses[isPrimary=true].addressLine1 + city`)
- Classification: `contactType` (Donor / Member / Volunteer / Partner — via `contactTypeAssignments[isPrimary=true].contactType.contactTypeName`)
- Engagement: `engagementScore` (numeric 0–100 — uses existing stub from Contact #18)
- Giving: `donationCount`, `totalDonationAmount` (aggregate from `globalDonations` or precomputed — see §⑫ ISSUE-5)
- Audit: `createdDate` (for "Created: Jan 2024" display)

---

## ④ Business Rules & Validation

**Uniqueness Rules**:
- A pair `(ContactFromId, ContactToId)` must be unique among `ActionId=PEN` (no duplicate pending pairs for the same two contacts). Existing `CreateDuplicateContact` handler enforces this.
- Order-independent: `(A,B)` and `(B,A)` are the same pair. Existing handler already checks both orderings.

**Required Field Rules**:
- `ContactFromId`, `ContactToId`, `DuplicateCategoryId`, `ActionId` are mandatory on create.
- `ContactFromId != ContactToId` (no self-merge) — existing guard in `CreateDuplicateContact`.
- `ValidContactId` required only when `ActionId = MRG`.
- `MergedContactId` required only when `ActionId = MRG` and must differ from `ValidContactId`.

**Conditional Rules**:
- On Merge: `ValidContactId` must be one of `{ContactFromId, ContactToId}` — the kept contact. `MergedContactId` is the other one.
- On Merge: the `MergedContact` (secondary) `IsActive` flips to `false` via `fn_merge_contacts`.
- On NotDuplicate / Ignore: `ValidContactId` and `MergedContactId` must stay null.
- `ActionDate` auto-set to UtcNow when action transitions from PEN to any terminal state.
- `ActionByUserId` auto-set to current user (from HttpContext) on any terminal action.

**Business Logic**:

*Confidence Level computation* (server-side, in `GetDuplicateContactsHandler`):
- **High**: `DuplicateCategory.DataValue` in `{NAMEEMAILCATEGORY, NAMEMOBILECATEGORY}` AND contactFrom primary email == contactTo primary email (or same phone) — i.e., an identifier truly matches.
- **Medium**: `DuplicateCategory.DataValue = NAMEEMAILCATEGORY` but emails differ in casing/domain only; OR `NAMEMOBILECATEGORY` with phone match only; OR `NAMEDOBCATEGORY`.
- **Low**: `DuplicateCategory.DataValue = MANUALCATEGORY` OR name-match with nothing else corroborating.

*Match Type label* (server-side, derived from which fields actually match):
- Compute per-pair: `matchedFields: string[]` containing any of `{"name","email","phone","address","dob"}` where both contacts have that field and values match (exact or similar).
- Label = join with " + " and append " Match": e.g., `"Name + Email Match"`, `"Email Match"`, `"Name Match only"`.

*Matched field highlighting* (FE-side):
- FE receives `matchedFields: string[]` plus raw field values per side. Applies green highlight if field key is in `matchedFields` with exact match, yellow if similar (fuzzy/case-insensitive match), gray italic "— (missing)" if either side has empty value.

**Workflow** (state machine on `ActionId`):

```
          Run Detection (fn_detect_duplicate_contacts)
                  │
                  ▼
              ┌───────┐
              │ PEN   │ ──Merge──▶ MRG (set ValidContactId, MergedContactId, deactivate secondary)
              │ ──────┘ ──NotDup─▶ NDP
              │         ──Ignore─▶ IGN
              └───────┘
```

Once in MRG / NDP / IGN the pair is resolved — no transitions back (no un-merge in scope).

**Side effects on Merge** (already implemented in `fn_merge_contacts`): re-points ContactId on GlobalDonations, ContactEmailAddresses, ContactPhoneNumbers, ContactAddresses, ContactTagAssignments, ContactTypeAssignments, ContactRelationships, and marks the secondary `Contact.IsActive = false`.

---

## ⑤ Screen Classification & Pattern Selection

**Screen Type**: FLOW (preserves existing `?mode=new/edit/read/manual` routing in `index.tsx` router)
**Type Classification**: FLOW with **custom index layout** (pair-card list instead of table) + **Variant B** grid-page chrome (ScreenHeader + KPI widgets above content) + **inline Merge Modal** (mockup's design) + **existing view-page preserved** for manual merge and deep read.

**Reason**:
- Mockup's inline pair list + Merge Modal pattern ≠ standard table row pattern. A custom index-page component is required; `FlowDataTable` is NOT the right surface for side-by-side comparison cards.
- Workflow-driven (4-state action + terminal resolution) → FLOW, not MASTER_GRID.
- Existing `view-page.tsx` is a richer implementation than mockup's modal — keep it as the deep-dive path. Mockup's simple modal is the FAST path for clear-cut cases.

**Backend Patterns Required**:
- [x] Standard CRUD — **MODIFY ONLY** (entity + commands + queries exist)
- [x] Tenant scoping (CompanyId from HttpContext) — already in place
- [ ] Nested child creation — N/A (DuplicateContactLog not surfaced)
- [x] Multi-FK validation (ContactFromId, ContactToId, DuplicateCategoryId, ActionId) — already in place
- [ ] Unique validation — already in place in `CreateDuplicateContact`
- [x] Workflow commands — `MergeContacts`, `IgnoreDuplicateContact` exist; **ADD `NotDuplicateContact`** (new, symmetric to Ignore)
- [x] Summary query — **ADD `GetDuplicateContactSummary`** (4 KPI widgets)
- [ ] File upload — N/A

**Frontend Patterns Required**:
- [x] Variant B layout (`<ScreenHeader>` + widgets + list card)
- [x] **Custom pair-card list** (NOT `FlowDataTable`) — renders `DuplicateContactResponseDto[]` as stacked cards with side-by-side comparison
- [x] view-page.tsx with 3 URL modes (`manual`, `read`, and `edit` — the last is a fallback) — **KEEP existing implementation**
- [x] React Hook Form (manual mode only — existing)
- [x] **Zustand store** (`duplicatecontact-store.ts`) — NEW, currently not present (view-page uses local `useState`). Store holds: active filter chip, active category, sort option, paged result, and is-merge-modal-open/active-pair
- [x] **Merge Modal component** — NEW inline modal, matches mockup §"Merge Preview Modal"
- [x] FlowFormPageHeader (only on manual / read pages — existing)
- [x] Summary cards / count widgets above grid — 4 KPI widgets
- [x] Filter chip bar — 5 chips (All / Pending / Merged / NotDuplicate / Ignored)
- [x] Category dropdown + Sort dropdown in filter bar
- [ ] Grid aggregation columns — N/A (not a grid)

---

## ⑥ UI/UX Blueprint

### Grid/List View — pair-card list (custom, NOT FlowDataTable)

**Display Mode**: `custom` — rolling our own. Reason: mockup's layout is too specific to be a FlowDataTable card variant.

**Grid Layout Variant**: `widgets-above-grid` → **Variant B** (`<ScreenHeader>` + widgets + content card wrapper). MANDATORY.

**Page Structure (top to bottom)**:

```
┌──────────────────────────────────────────────────────────────────────┐
│  <ScreenHeader>                                                      │
│    icon: ph:files-duplicate (or equivalent)                          │
│    title: "Duplicate Detection"                                      │
│    subtitle: "{totalDetected} potential duplicate pairs found"       │
│    actions:  [Run Detection] (primary)   [Settings] (outline)        │
│                                                                      │
│  <KpiWidgetsRow> (4 cards, responsive grid minmax 180px)             │
│    [🔵 Total Detected: {n}]  [🟡 Pending Review: {n}]                 │
│    [🟢 Merged This Month: {n}]  [⚫ Not Duplicate: {n}]                │
│                                                                      │
│  <ListCard> (white card wrapper)                                     │
│    <FilterBar>                                                       │
│      [Category ▾] [All] [Pending] [Merged] [Not Duplicate] [Ignored] │
│                                                  [Sort: Confidence ▾]│
│    </FilterBar>                                                      │
│                                                                      │
│    <PendingPairCard>   × N   (for ActionId=PEN)                      │
│    <ResolvedPairCard>  × M   (for ActionId=MRG/NDP/IGN)              │
│                                                                      │
│    <Pagination />                                                    │
│  </ListCard>                                                         │
│                                                                      │
│  <MergeModal /> (portaled, hidden by default)                        │
└──────────────────────────────────────────────────────────────────────┘
```

**ScreenHeader**:
- Icon: `ph:files-duplicate` (Phosphor via @iconify) — primary/accent color
- Title: `"Duplicate Detection"`
- Subtitle: `"{totalDetected} potential duplicate pairs found"` — binds to summary query
- Right-side action buttons:
  - **Run Detection** (primary filled, icon `ph:magnifying-glass`) — fires `detectDuplicateContacts` mutation → toast → re-fetch list + summary
  - **Settings** (outline, icon `ph:gear`) — SERVICE_PLACEHOLDER: opens toast "Detection settings coming soon" (route stub at `crm/maintenance/duplicatecontact/settings` not yet built)
  - **Manual Merge** (ghost icon button, `ph:git-merge`) — navigates to `?mode=manual` — keep functionality, move out of floating absolute position

**KpiWidgetsRow** — 4 cards, horizontal responsive grid:

| # | Title | Value Source | Icon | IconBg | Display |
|---|-------|-------------|------|--------|---------|
| 1 | Total Detected | `summary.totalDetected` | `ph:files-duplicate` | blue-100/blue-600 | integer |
| 2 | Pending Review | `summary.pendingReview` | `ph:clock` | amber-100/amber-600 | integer |
| 3 | Merged This Month | `summary.mergedThisMonth` | `ph:git-merge` | green-100/green-600 | integer |
| 4 | Not Duplicate | `summary.notDuplicate` | `ph:x` | slate-100/slate-600 | integer |

Use existing dashboard widget pattern from ContactType #19 / Branch #41 (`<KpiCard>` in `dgf-widgets`). Do NOT introduce inline hex colors — use token classes `bg-blue-100 text-blue-600` etc. (Tailwind tokens).

**FilterBar**:
- Category select (left): options `All Categories | Name + DOB | Name + Mobile | Name + Email | Manual`. Value = `DuplicateCategoryId` or null (All).
- Filter chips row (middle): `All | Pending Review | Merged | Not Duplicate | Ignored`. Active chip has primary background, inactive has white/border. Chip maps to `ActionId` filter (null | PEN | MRG | NDP | IGN).
- Sort select (right, `ml-auto`): options `Confidence: High → Low` (default), `Confidence: Low → High`, `Date Detected: Newest`, `Date Detected: Oldest`.

Filter state lives in Zustand store. Any change → re-fires `duplicateContacts` query with new args → list re-renders.

**PendingPairCard** — for pairs where `action.dataValue = "PEN"`:

```
┌──────────────────────────────────────────────────────────────────┐
│ [HIGH CONFIDENCE] Name + Email Match   ·  Pending  · Apr 10, 2026│
│                                                                  │
│ ┌─── Contact A ───────────┬─── Contact B ──────────────────┐    │
│ │ Code     CON-0009 (lnk) │ Code     CON-0156 (lnk)        │    │
│ │ Name     David Miller   │ Name     David A. Miller       │    │
│ │ Email    ✓ exact (grn)  │ Email    ✓ exact (grn)         │    │
│ │ Phone    ✓ exact (grn)  │ Phone    ✓ exact (grn)         │    │
│ │ Address  similar (yel)  │ Address  similar (yel)         │    │
│ │ Type     Donor          │ Type     Donor                 │    │
│ │ Score    34             │ Score    28                    │    │
│ │ Donations 5 ($1,200)    │ Donations 2 ($150)             │    │
│ │ Created   Jan 2024      │ Created   Nov 2025             │    │
│ └─────────────────────────┴────────────────────────────────┘    │
│                                                                  │
│ [Merge →] [← Merge] [Not Duplicate] [Ignore]                     │
└──────────────────────────────────────────────────────────────────┘
```

Layout: header row (confidence badge + match type + status + date), body = 2-column comparison grid (9 fields), action row.

Confidence badge colors (tokens):
- `high` → `bg-red-100 text-red-700`
- `medium` → `bg-orange-100 text-orange-700`
- `low` → `bg-yellow-100 text-yellow-700`

Field-match highlight (token-based, NOT inline hex):
- exact → wrap value in `bg-green-100 px-1.5 rounded` + green check icon
- similar → wrap value in `bg-yellow-100 px-1.5 rounded`
- missing → render `"— (missing)"` in `text-slate-400 italic`

Field-label column: `text-xs font-semibold uppercase tracking-wide text-slate-500` fixed width `w-20`.

Action buttons (bottom of card):
- **Merge →** — primary filled, icon `ph:arrow-right`, opens Merge Modal with `primary=ContactA`, `secondary=ContactB`
- **← Merge** — primary filled, icon `ph:arrow-left`, opens Merge Modal with `primary=ContactB`, `secondary=ContactA`
- **Not Duplicate** — outline, icon `ph:not-equals`, fires `notDuplicateContact` mutation after confirm dialog
- **Ignore** — outline, icon `ph:eye-slash`, fires `ignoreDuplicateContact` mutation after confirm dialog

Contact-code links (CON-XXXX) navigate to `crm/contact/contact?mode=read&id={contactId}` — existing contact detail route. Use Next.js `<Link>`.

Row click (elsewhere on card) → navigates to `?mode=read&id={duplicateContactId}` → opens the existing rich view-page for deep inspection.

**ResolvedPairCard** — for pairs where `action.dataValue ∈ {MRG, NDP, IGN}`:

```
┌──────────────────────────────────────────────────────────────────┐
│ [Merged] CON-0201 (James Okonkwo) → CON-0005 (James Okonkwo)     │
│                                       Merged: Apr 5 by John Smith│
│   "Same person, imported from two different sources"             │
└──────────────────────────────────────────────────────────────────┘
```

Compact 1-2 line layout. Status badge + summary row (primary→secondary with arrow for MRG, ampersand for NDP, plain list for IGN) + small meta (action date + actionByUser.userName) + optional italic reason (future — no DB field yet, hide if null). Background `bg-slate-50`.

Status badge colors:
- `merged` → `bg-green-100 text-green-700` with `ph:check` icon
- `not-dup` → `bg-slate-100 text-slate-600` with `ph:x` icon
- `ignored` → `bg-slate-100 text-slate-500` with `ph:eye-slash` icon

### MergeModal (NEW component — matches mockup §"Merge Preview Modal")

Triggered by clicking Merge → or ← Merge on a PendingPairCard. Dialog (portaled backdrop + centered modal, `max-w-2xl`).

**Sections (top to bottom)**:

1. **Header**: icon `ph:git-merge` (primary color) + title "Merge Contact Preview" + close X button.

2. **Merge Direction** (row with 3 items, centered, on `bg-slate-50 rounded-lg p-4`):
   - Left box (border-primary, bg-primary/5): label "KEPT (PRIMARY)", large name, smaller code
   - Center: large left-arrow icon `ph:arrow-left` (primary color) — indicates data flows from secondary INTO primary
   - Right box (border-danger, bg-danger/5): label "MERGED (SECONDARY)", large name, smaller code

3. **Field Selection Table**: 4-column (Field | Primary Value | Secondary Value | Keep radio):
   - Rows: Name, Email, Phone, Address, Type (5 fields from ContactResponseDto primary values)
   - Rows where primary ≠ secondary get `bg-yellow-50` highlight on the diff cells
   - Radio per row: "Primary" (default checked) or "Secondary"
   - NOTE: The radio selection is **captured but not sent to BE in this iteration** — current `mergeContacts(duplicateContactId, validContactId, mergedContactId)` only takes IDs, not field-level choices. Post-merge the kept contact retains its current values. Log as ISSUE-4 (§⑫) — future enhancement to pass field-level overrides to `fn_merge_contacts`.

4. **Transfer Summary** (`bg-cyan-50 border border-cyan-200 rounded p-3`):
   - Title: "WHAT WILL TRANSFER" (small caps)
   - Body: `"{donationCount} donations, {emailCount} email records, {phoneCount} phone records, {addressCount} addresses, {relationshipCount} relationships"` — binds to the 10 child-count fields already in DTO.

5. **Warning** (`bg-red-50 border border-red-200 rounded p-3` with warning icon):
   - "**This action cannot be undone.** The secondary contact will be deactivated. All donations, communications, and relationships will be transferred to the primary contact."

6. **Footer**: `[Cancel]` (outline) + `[Confirm Merge]` (danger filled, icon `ph:git-merge`) — fires `mergeContacts` mutation.

### View-Page — existing, KEEP

**Page Header**: FlowFormPageHeader with Back button — existing.

**Modes handled**:
- `?mode=manual` — FORM LAYOUT: two contact-code search inputs side by side + side-by-side comparison once both loaded + Confirm/Ignore buttons. Existing implementation.
- `?mode=read&id=X` — DETAIL LAYOUT: loads DuplicateContact by ID + fetches both contacts by ID → renders `ContactCompareView` (similarity bar + "Keep This" selection + field diff table + child collection diffs). Existing implementation.
- `?mode=edit&id=X` — treat as read (existing behavior).

**ALIGN delta for view-page**:
- Fix mutation call sites to refresh the index-page list + summary after merge/ignore/notDuplicate (add cache eviction or refetch on router back).
- Wire new `notDuplicateContact` mutation so view-page's "Not a Duplicate" action (if present) transitions properly. If currently treats NotDuplicate as Ignore, separate them.
- No UI redesign for view-page — existing is richer than mockup's modal.

### Page Widgets & Summary Cards

**Summary GQL Query**: `GetDuplicateContactSummary` — NEW
- Returns `DuplicateContactSummaryDto` with: `totalDetected`, `pendingReview`, `mergedThisMonth`, `notDuplicate`, `ignored`
- Tenant-scoped (CompanyId from HttpContext)
- `mergedThisMonth` = count where `ActionId=MRG` AND `ActionDate >= first-of-current-month`
- Added to `DuplicateContactQueries.cs` alongside `GetDuplicateContacts` and `GetDuplicateContactById`

### Grid Aggregation Columns

N/A — custom card layout.

### User Interaction Flow (ALIGN — mixed pattern)

1. User lands on `/crm/maintenance/duplicatecontact` → index-page loads → 4 widgets + list of pair cards (default: All chip + Confidence H→L sort).
2. Filter: user clicks "Pending Review" chip → list re-filters (only PEN). Click "Merged" → only MRG. Etc.
3. Category filter: user picks "Name + Email" → list filters by `DuplicateCategoryId`.
4. Sort: user picks "Date Detected: Newest" → list re-sorts.
5. **Quick Merge** path: user clicks "Merge →" on a pair card → MergeModal opens with chosen direction → user adjusts radios (optional) → clicks "Confirm Merge" → `mergeContacts` fires → modal closes → list re-fetches → pair now shows as ResolvedPairCard with "Merged" badge.
6. **Deep Review** path: user clicks on pair card body (not action buttons) → navigates to `?mode=read&id=X` → view-page loads with full child comparison → user clicks "Merge" (primary button on view-page) → merges → navigates back to index.
7. Not Duplicate / Ignore: user clicks button → confirm dialog → mutation fires → card updates.
8. Run Detection: user clicks header button → `detectDuplicateContacts` mutation → spinner during run → success toast → list + summary refetch.
9. Manual Merge (preserved from existing): click header icon button or route to `?mode=manual` → two contact-code inputs → both loaded → compare + merge.
10. Settings: click header button → SERVICE_PLACEHOLDER toast "Detection settings coming soon".

---

## ⑦ Substitution Guide

**Canonical Reference**: SavedFilter (FLOW) — for view-page scaffolding. For index-page (custom), reference the 4-widget Variant B pattern from **ContactType #19** and **Branch #41** KPI rows.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | DuplicateContact | Entity/class name |
| savedFilter | duplicateContact | Variable/field names |
| SavedFilterId | DuplicateContactId | PK field |
| SavedFilters | DuplicateContacts | Table name, collection names |
| saved-filter | duplicate-contact | kebab-case (file names) |
| savedfilter | duplicatecontact | FE folder, import paths |
| SAVEDFILTER | DUPLICATECONTACT | Grid code, menu code (existing menu) |
| notify | corg | DB schema |
| Notify | Contact | Backend group name (Models/Schemas/Business) — existing |
| NotifyModels | ContactModels | Namespace suffix — existing |
| NOTIFICATIONSETUP | CRM_MAINTENANCE | Parent menu code — existing |
| NOTIFICATION | CRM | Module code — existing |
| crm/communication/savedfilter | crm/maintenance/duplicatecontact | FE route path — existing |
| notify-service | contact-service | FE service folder name — existing |

---

## ⑧ File Manifest

**Scope**: ALIGN. Most files EXIST. Below marks `MODIFY` vs `CREATE`. Do NOT regenerate existing files from scratch.

### Backend Files

| # | File | Action | Path |
|---|------|--------|------|
| 1 | Entity | KEEP | `Base.Domain/Models/ContactModels/DuplicateContact.cs` — no changes |
| 2 | Entity (child) | KEEP | `Base.Domain/Models/ContactModels/DuplicateContactLog.cs` — no changes |
| 3 | EF Config | KEEP | `Base.Infrastructure/Data/Configurations/ContactConfigurations/DuplicateContactConfiguration.cs` (verify exists — if not, `.Include()`/`HasForeignKey()` already work via convention) |
| 4 | Schemas (DTOs) | **MODIFY** | `Base.Application/Schemas/ContactSchemas/DuplicateContactSchemas.cs` — add fields (see §⑩). Add new `DuplicateContactSummaryDto`. |
| 5 | Create Command | KEEP | `.../ContactBusiness/DuplicateContacts/Commands/CreateDuplicateContact.cs` |
| 6 | Update Command | N/A | Update is not used in this workflow |
| 7 | Delete Command | KEEP | Soft-delete via BaseCommand inheritance |
| 8 | Toggle Command | N/A | No toggle for this entity |
| 9 | GetAll Query | **MODIFY** | `.../Queries/GetDuplicateContacts.cs` — add `.Include(d => d.Action)` (currently missing!); add post-projection `ConfidenceLevel`, `MatchType`, `MatchedFields`, and flattened comparison fields; add filter args for ActionDataValue, CategoryDataValue, and sort-by-confidence |
| 10 | GetById Query | KEEP | `.../Queries/GetDuplicateContactById.cs` — may also need `.Include(d => d.Action)` parity check |
| 11 | **Summary Query** | **CREATE** | `.../Queries/GetDuplicateContactSummary.cs` — new query + handler + DTO (counts by ActionDataValue, merged-this-month) |
| 12 | Detect Command | KEEP | `.../Commands/DetectDuplicateContacts.cs` |
| 13 | Merge Command | KEEP | `.../Commands/MergeContacts.cs` |
| 14 | Ignore Command | KEEP | `.../Commands/IgnoreDuplicateContact.cs` |
| 15 | **NotDuplicate Command** | **CREATE** | `.../Commands/NotDuplicateContact.cs` — new handler; symmetric to `IgnoreDuplicateContact` but sets `ActionId` to MasterData value `NDP` |
| 16 | Mutations endpoint | **MODIFY** | `Base.API/EndPoints/Contact/Mutations/DuplicateContactMutations.cs` — register `notDuplicateContact` mutation |
| 17 | Queries endpoint | **MODIFY** | `Base.API/EndPoints/Contact/Queries/DuplicateContactQueries.cs` — register `duplicateContactSummary` query + extend `duplicateContacts` args |
| 18 | Mapster mappings | **MODIFY** | `Base.Application/Common/Mappings/ContactMappings.cs` — add Mapster config for new `DuplicateContactSummaryDto` if non-convention |

### Backend Wiring Updates

| # | File | What to Add |
|---|------|-------------|
| 1 | `IContactDbContext.cs` | DbSet<DuplicateContact> — already there (line 24-25 per research) |
| 2 | `ContactDbContext.cs` | DbSet<DuplicateContact> — already there |
| 3 | `DecoratorProperties.cs` | `DecoratorContactModules.DuplicateContact` — already referenced in `CustomAuthorize` attrs, verify entry exists |
| 4 | `ContactMappings.cs` | Mapster config for new summary DTO (see #18 above) |
| 5 | Seed SQL | `sql-scripts-dyanmic/DuplicateContact-sqlscripts.sql` — uncomment `DUPLICATECATEGORY` + add `NDP` (`Not Duplicate`) MasterData value under `CONTACTSTATUS` TypeCode |

### Frontend Files

| # | File | Action | Path |
|---|------|--------|------|
| 1 | DTO Types | **MODIFY** | `src/domain/entities/contact-service/DuplicateContactDto.ts` — add `confidenceLevel`, `matchType`, `matchedFields[]`, flattened comparison fields (contactFromPrimaryEmail, contactFromPrimaryPhone, etc.), new `DuplicateContactSummaryDto` |
| 2 | GQL Query | **MODIFY** | `src/infrastructure/gql-queries/contact-queries/DuplicateContactQuery.ts` — extend `DUPLICATE_CONTACTS_QUERY` with new fields + new args; add `DUPLICATE_CONTACT_SUMMARY_QUERY` |
| 3 | GQL Mutation | **MODIFY** | `src/infrastructure/gql-mutations/contact-mutations/DuplicateContactMutation.ts` — add `NOT_DUPLICATE_CONTACT_MUTATION` |
| 4 | Page Config | KEEP | `src/presentation/pages/crm/index.ts` (or wherever `DuplicateContactPageConfig` is exported) — verify still exports the top-level component |
| 5 | Route controller (index.tsx) | **MODIFY** | `src/presentation/components/page-components/crm/maintenance/duplicatecontact/index.tsx` — keep mode routing, drop `FlowDataTable` wrapping on default mode, hand off to new `DuplicateContactIndexPage` |
| 6 | **Index Page Component** | **REWRITE** | `.../duplicatecontact/index-page.tsx` — custom pair-card list + KPI widgets + filter bar + Variant B layout. Replace existing simple FlowDataTable version. |
| 7 | View Page (3 modes) | KEEP + minor | `.../duplicatecontact/view-page.tsx` — KEEP existing 600+ line implementation; add `notDuplicateContact` wiring; add cache-evict/refetch on merge/ignore success |
| 8 | **Zustand Store** | **CREATE** | `.../duplicatecontact/duplicatecontact-store.ts` — holds: `activeStatus ∈ {all,PEN,MRG,NDP,IGN}`, `activeCategoryId?`, `sortBy ∈ {confidence-desc,confidence-asc,date-desc,date-asc}`, `page`, `pageSize`, `isMergeModalOpen`, `activeMergePair?`, `mergeDirection ∈ {left,right}`, setters |
| 9 | **Pair Card** | **CREATE** | `.../duplicatecontact/components/pending-pair-card.tsx` — side-by-side comparison card with actions |
| 10 | **Resolved Card** | **CREATE** | `.../duplicatecontact/components/resolved-pair-card.tsx` — compact row for MRG/NDP/IGN |
| 11 | **Merge Modal** | **CREATE** | `.../duplicatecontact/components/merge-modal.tsx` — inline modal per mockup |
| 12 | **KPI Widgets Row** | **CREATE** | `.../duplicatecontact/components/duplicatecontact-widgets.tsx` — 4 KpiCards, binds to summary query |
| 13 | **Filter Bar** | **CREATE** | `.../duplicatecontact/components/duplicatecontact-filter-bar.tsx` — category select + chips + sort select |
| 14 | **Field Match Row** | **CREATE** | `.../duplicatecontact/components/field-match-row.tsx` — reusable "label + value with highlight" row used in pair card |
| 15 | Route Page | KEEP | `src/app/[lang]/crm/maintenance/duplicatecontact/page.tsx` — no changes |

### Frontend Wiring Updates

| # | File | What to Add |
|---|------|-------------|
| 1 | `contact-service-entity-operations.ts` | Verify `DUPLICATECONTACT` entry; add `notDuplicate` mutation reference if data-table config still has it |
| 2 | `contact-service.ts` (queries/mutations barrel) | Export new `DUPLICATE_CONTACT_SUMMARY_QUERY` + `NOT_DUPLICATE_CONTACT_MUTATION` |
| 3 | `contact-service` DTO barrel | Export `DuplicateContactSummaryDto` |
| 4 | Sidebar menu config | Menu entry under `CRM_MAINTENANCE` — already in place |
| 5 | `dgf-widgets/index.ts` (if using shared KpiCard) | No change — reuse existing `KpiCard` component from ContactType / Branch |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: ALIGN

MenuName: Duplicate Detection
MenuCode: DUPLICATECONTACT
ParentMenu: CRM_MAINTENANCE
Module: CRM
MenuUrl: crm/maintenance/duplicatecontact
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: DUPLICATECONTACT
---CONFIG-END---
```

**NOTE**: Menu already seeded (per MODULE_MENU_REFERENCE.md line 51). The seed task is to **verify** menu + add MasterData seeds:
- Uncomment `DUPLICATECATEGORY` MasterDataType + 4 values (NAMEDOBCATEGORY, NAMEMOBILECATEGORY, NAMEEMAILCATEGORY, MANUALCATEGORY) in existing `DuplicateContact-sqlscripts.sql`
- Add `NDP` (DataName="Not Duplicate", DataValue="NDP", OrderBy=4) row under existing `CONTACTSTATUS` MasterDataType. Existing values: PEN=Pending, MRG=Merged, IGN=Ignored.

---

## ⑩ Expected BE→FE Contract

### GraphQL Field Names

**Queries** (on `DuplicateContactQueries` endpoint class):

| GQL Field | C# Method | Returns | Key Args |
|-----------|-----------|---------|----------|
| `duplicateContacts` | `GetDuplicateContacts` | `GridFeatureResult<DuplicateContactResponseDto>` | `request: GridFeatureRequest` (extend filter args to accept `ActionDataValue: string?`, `CategoryDataValue: string?`, `SortBy: string?`) |
| `duplicateContactById` | `GetDuplicateContactById` | `DuplicateContactResponseDto` | `duplicateContactId: Int` |
| `contactByCode` | `GetContactByCode` | `ContactResponseDto` | `contactCode: String` (existing) |
| **`duplicateContactSummary`** | `GetDuplicateContactSummary` (**NEW**) | `DuplicateContactSummaryDto` | — (tenant from HttpContext) |

**Mutations** (on `DuplicateContactMutations` endpoint class):

| GQL Field | C# Method | Returns | Args |
|-----------|-----------|---------|------|
| `createDuplicateContact` | `CreateDuplicateContact` | `int` | contactFromId, contactToId, duplicateCategoryId |
| `mergeContacts` | `MergeContacts` | `MergeContactsResult` | duplicateContactId, validContactId, mergedContactId |
| `ignoreDuplicateContact` | `IgnoreDuplicateContact` | `IgnoreDuplicateContactResult` | duplicateContactId |
| **`notDuplicateContact`** | `NotDuplicateContact` (**NEW**) | `IgnoreDuplicateContactResult` (same shape) | duplicateContactId |
| `detectDuplicateContacts` | `DetectDuplicateContacts` | `DetectDuplicateContactsResult` | (none) |

### DTO Field Additions (DuplicateContactResponseDto)

**Keep existing**:
- 11 scalar FK/action fields, 10 navigation objects, 10 child-count ints

**ADD** (server-projected in `GetDuplicateContactsHandler`):

| Field | Type | Notes |
|-------|------|-------|
| `confidenceLevel` | string | `"high" \| "medium" \| "low"` — server-computed per §④ |
| `matchType` | string | Human label: `"Name + Email Match"`, `"Email Match"`, etc. |
| `matchedFields` | `List<string>` | `["name","email","phone","address","dob"]` subset |
| `contactFromPrimaryEmail` | string? | Flattened from `ContactEmailAddresses[isPrimary=true]` — so FE list doesn't need nested arrays |
| `contactFromPrimaryPhone` | string? | Flattened similarly |
| `contactFromPrimaryAddress` | string? | Single-line display |
| `contactFromContactType` | string? | `ContactTypeAssignments[isPrimary=true].ContactType.ContactTypeName` |
| `contactFromEngagementScore` | int? | 0-100 stub (Contact #18) |
| `contactFromTotalDonations` | decimal? | Sum of GlobalDonations.Amount — NOT contactFromDonationCount's sum of nothing |
| `contactFromCreatedDate` | DateTime? | For "Created: Jan 2024" display |
| `contactToPrimaryEmail` | string? | (×7 mirror for ContactTo side) |
| `contactToPrimaryPhone` | string? | |
| `contactToPrimaryAddress` | string? | |
| `contactToContactType` | string? | |
| `contactToEngagementScore` | int? | |
| `contactToTotalDonations` | decimal? | |
| `contactToCreatedDate` | DateTime? | |

**New DTO** (separate file or appended to DuplicateContactSchemas.cs):

```csharp
public class DuplicateContactSummaryDto
{
    public int TotalDetected { get; set; }
    public int PendingReview { get; set; }
    public int MergedThisMonth { get; set; }
    public int NotDuplicate { get; set; }
    public int Ignored { get; set; }
}
```

### Request Filter Extensions (GetDuplicateContactsQuery)

The existing `GridFeatureRequest` carries generic search/page/sort. ADD extended args (either via extra params on the endpoint method OR by sending them inside `AdvancedFilters`):

| Arg | Type | Purpose |
|-----|------|---------|
| `actionDataValue` | string? | Filter by CONTACTSTATUS DataValue (`PEN`, `MRG`, `NDP`, `IGN`) — drives chip filter |
| `duplicateCategoryId` | int? | Filter by DuplicateCategory id — drives category dropdown |
| `sortBy` | string? | `confidence-desc` (default), `confidence-asc`, `date-desc`, `date-asc` |

**Recommendation**: pass via `AdvancedFilters` JSON (no endpoint signature change) — existing `FlowDataTable` pattern. Handler post-processes the parsed filter payload before applying grid features.

---

## ⑪ Acceptance Criteria

**Build Verification**:
- [ ] `dotnet build` — 0 errors
- [ ] `pnpm tsc --noEmit` — 0 errors in any `duplicatecontact` file

**Functional Verification (FULL E2E — MANDATORY)**:

*Initial load*:
- [ ] Page loads at `/en/crm/maintenance/duplicatecontact`
- [ ] ScreenHeader shows title + dynamic subtitle with totalDetected count
- [ ] 4 KPI widgets render with non-zero values (after seed data applied)
- [ ] Filter bar shows category select, 5 chips, sort select
- [ ] Default state: "All" chip active, Confidence H→L sort, no category filter
- [ ] Pair cards render in order (highest confidence first)

*Pair card rendering*:
- [ ] Confidence badge colors map correctly (red=high, orange=medium, yellow=low)
- [ ] Match type label shows (e.g., "Name + Email Match")
- [ ] 2-column comparison grid renders 9 fields per side
- [ ] Fields in `matchedFields` exact case show green highlight + check icon
- [ ] Fields in `matchedFields` similar case show yellow highlight
- [ ] Missing fields on one side show "— (missing)" in italic slate
- [ ] Contact codes are clickable links to contact detail

*Filter interactions*:
- [ ] Click "Pending Review" chip → only PEN pairs show
- [ ] Click "Merged" chip → only MRG resolved cards show
- [ ] Click "Not Duplicate" chip → only NDP resolved cards show
- [ ] Click "Ignored" chip → only IGN resolved cards show
- [ ] Category "Name + Email" → only pairs with DuplicateCategory=NAMEEMAILCATEGORY show
- [ ] Sort "Date Newest" → pairs reorder by DetectedDate desc
- [ ] Filter state persists in URL or Zustand (verify behavior on back navigation)

*Merge flow (QUICK path)*:
- [ ] Click "Merge →" on pair card → MergeModal opens with A as primary, B as secondary
- [ ] Click "← Merge" on pair card → MergeModal opens with B as primary, A as secondary
- [ ] Direction boxes show correct names + codes
- [ ] Field selection table shows 5 rows with primary/secondary values
- [ ] Diff rows highlighted yellow
- [ ] Transfer summary shows non-zero counts (bound to child-count fields)
- [ ] Warning banner visible
- [ ] Click "Confirm Merge" → mergeContacts mutation fires
- [ ] On success: modal closes, toast "Contacts merged successfully", list refetches, summary refetches
- [ ] Pair now appears as ResolvedPairCard under "Merged" chip

*Not Duplicate flow*:
- [ ] Click "Not Duplicate" on pair card → confirm dialog
- [ ] Confirm → notDuplicateContact mutation fires
- [ ] On success: pair re-categorized to NDP resolved card
- [ ] "Not Duplicate" chip count increments

*Ignore flow*:
- [ ] Click "Ignore" on pair card → confirm dialog
- [ ] Confirm → ignoreDuplicateContact mutation fires
- [ ] On success: pair disappears from Pending, appears under Ignored chip

*Deep review path*:
- [ ] Click on pair card body (not action buttons) → navigates to `?mode=read&id=X`
- [ ] view-page DETAIL layout loads (existing richer UI)
- [ ] view-page merge/ignore/notDuplicate actions still work, return to index

*Manual merge (existing, preserve)*:
- [ ] Click Manual Merge icon in header → navigates to `?mode=manual`
- [ ] Two contact-code inputs render
- [ ] Enter code A → loads contact A
- [ ] Enter code B → loads contact B
- [ ] Comparison view renders
- [ ] Merge button works

*Run Detection*:
- [ ] Click header "Run Detection" → button shows spinner
- [ ] detectDuplicateContacts mutation fires
- [ ] Success toast shows result message
- [ ] List + summary refetch (no full page reload — prefer refetch over `window.location.reload()`)

*Settings*:
- [ ] Click header "Settings" → toast "Detection settings coming soon" (SERVICE_PLACEHOLDER)

*Permissions*:
- [ ] BUSINESSADMIN sees all buttons
- [ ] READ-only role hides Merge / NotDuplicate / Ignore / Run Detection buttons

*DB Seed*:
- [ ] Menu visible under CRM → Maintenance → Duplicate Detection (already in place)
- [ ] MasterData DUPLICATECATEGORY has 4 rows
- [ ] MasterData CONTACTSTATUS has NDP value added (no duplicate insert)

---

## ⑫ Special Notes & Warnings

**ALIGN scope — DO NOT regenerate**:
- Entity (`DuplicateContact.cs`), all existing commands except new `NotDuplicateContact`, `GetDuplicateContactById` query, `CreateDuplicateContact`, `MergeContacts`, `IgnoreDuplicateContact`, `DetectDuplicateContacts` — **keep as-is**.
- `view-page.tsx` (600+ lines) — **keep**. Minor edits only (add NotDuplicate wiring + refetch-on-success).
- Route controller `index.tsx` — minor edits only.
- Existing GQL files — extend, don't rewrite.

**Critical gaps from research**:
- **ISSUE-BE-CRITICAL**: `GetDuplicateContactsHandler` does NOT `.Include(d => d.Action)`. The current grid's Status column returns null. **Fix in this pass.**
- **ISSUE-BE**: `ActionId` reuses MasterDataType `CONTACTSTATUS`, not a dedicated type. Not worth migrating — just seed NDP and document.
- **ISSUE-FE**: existing `index-page.tsx` uses absolute-positioned floating icon buttons (`absolute right-12 top-2`) overlapping FlowDataTable header — this UX hack is removed in the rebuild (buttons move into ScreenHeader).
- **ISSUE-FE**: `window.location.reload()` after Run Detection — replace with Apollo cache evict + refetch for SPA-friendly UX.
- **ISSUE-SEED**: `DUPLICATECATEGORY` seed rows are commented out in existing SQL. Uncomment.

**Service Dependencies** (SERVICE_PLACEHOLDER — UI only):
- **"Settings" header button** → Detection settings config page not yet built. Wire to toast "Detection settings coming soon." Route stub `crm/maintenance/duplicatecontact/settings` not in scope here.
- **Mockup resolved-card "reason" field** (e.g., "Same person, imported from two different sources") → No BE field exists for a free-form reason. Hide the reason line if null. Add as ISSUE-3 (future: add `ActionReason string?` column or nest in DuplicateContactLog).
- **Mockup field-level merge overrides** (radio "Keep Primary/Secondary" per field) → `fn_merge_contacts` currently does a wholesale pointer swap — doesn't accept field-level preferences. Captured in UI but discarded before mutation call. ISSUE-4.

**Expected field-match computation gotchas**:
- "Similar" detection (e.g., "890 Sunset Blvd, LA" vs "890 Sunset Boulevard, Los Angeles") requires fuzzy comparison. For this pass, implement simple case-insensitive prefix match + Levenshtein distance ≤ 3 for address, or skip similar detection entirely and only highlight exact matches. Flag as ISSUE-6.
- Missing-field detection: treat empty string / null as missing.

**Pre-flagged ISSUEs** (to be tracked in §⑬ Build Log):
- **ISSUE-1**: Merged-this-month uses DetectedDate or ActionDate? Use ActionDate (when status flipped to MRG) — not DetectedDate. Confirm at implementation.
- **ISSUE-2**: `notDuplicateContact` mutation needs backend NDP MasterData seed to exist before handler can resolve action id. Seed dependency.
- **ISSUE-3**: No `ActionReason` field on DuplicateContact. Mockup's resolved-card reason quote is purely display — hide if null.
- **ISSUE-4**: `mergeContacts` mutation doesn't accept field-level overrides. MergeModal radio choices are captured but discarded. Future enhancement.
- **ISSUE-5**: `contactFromTotalDonations` aggregation — use GlobalDonation.Amount SUM grouped by ContactId. Verify GlobalDonation table has ContactId FK; if via ContactRecurring only, adjust. Similar to In-Kind Donation #7 ISSUE-1.
- **ISSUE-6**: "Similar" field highlighting requires fuzzy matching. Implement basic case-insensitive prefix match or skip; document as a future enhancement.
- **ISSUE-7**: `DUPLICATECATEGORY` rows commented in existing SQL — handler crashes if these don't exist (DetectDuplicateContacts needs them). Must uncomment in the seed update.
- **ISSUE-8**: `DuplicateContactLog` entity exists but no GQL endpoint and no handler wires entries. Out of scope here — the audit trail will remain empty until a future log-on-merge enhancement.
- **ISSUE-9**: Existing view-page refetch — after merge/ignore, user navigates back to index but the list may show stale cached data. Add `refetchQueries: [DUPLICATE_CONTACTS_QUERY, DUPLICATE_CONTACT_SUMMARY_QUERY]` on mutations.
- **ISSUE-10**: Inherits Contact #18 ISSUE-3 — engagement score is a stub (returns placeholder). Display the number but understand it's not yet real.
- **ISSUE-11**: Custom card layout does NOT use `FlowDataTable` — the standard `GridCode=DUPLICATECONTACT` seed's 10 column definitions are irrelevant at runtime for the index view. Keep them in seed (for any fallback/export) but document that the live UI doesn't render them.
- **ISSUE-12**: Filter state in URL vs Zustand. Recommend URL sync via Next.js `useSearchParams` for shareable links. Optional — Zustand alone is fine for v1.
- **ISSUE-13**: The mockup's "Settings" button has no implementation. Deliberate SERVICE_PLACEHOLDER.
- **ISSUE-14**: Inherits Contact #18 read-mode detail structure but this screen's view-page predates it. No change in scope — view-page is a sibling implementation, not a dependent.

---

## ⑬ Build Log (append-only)

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | S1 (2026-04-21) | HIGH | BE query | Confidence sort (`confidence-desc`/`confidence-asc`) is applied **in-memory after the page is fetched** — ConfidenceLevel is not a DB column. Per-page confidence ordering is correct; cross-page ordering uses DetectedDate DESC as DB pre-order. Full accuracy would require a materialized column or fetch-all-then-sort. | OPEN |
| ISSUE-2 | S1 (2026-04-21) | MED | BE DTO | `ContactAddress` has no `IsPrimary` flag (schema gap). Spec asked for primary-address from `ContactAddresses.Where(a => a.IsPrimary)`. Implemented fallback: first non-deleted address per contact. If "primary" is a real business concept, a column is needed. | OPEN |
| ISSUE-3 | S1 (2026-04-21) | MED | BE DTO | `ContactTypeAssignment` has no `IsPrimary` flag. Spec asked for primary-type from `ContactTypeAssignments.Where(t => t.IsPrimary)`. Fallback: most recently assigned (`max(AssignedDate)`). | OPEN |
| ISSUE-4 | S1 (2026-04-21) | LOW | BE DTO | `Contact.EngagementScore` column does not exist. `ContactFromEngagementScore` / `ContactToEngagementScore` projected as `null`. Inherits Contact #18 ISSUE-3 stub until real column added. | OPEN |
| ISSUE-5 | S1 (2026-04-21) | LOW | BE API contract | No `AdvancedFilters` JSON convention in codebase — spec recommended passing filter extensions inside an AdvancedFilters payload. Implemented using Family #20-style typed optional query-record params (`actionDataValue`, `duplicateCategoryId`, `sortBy`). Strongly-typed, no JSON parsing. FE gets 3 optional GQL args on `duplicateContacts` field. No break. | OPEN |
| ISSUE-6 | S1 (2026-04-21) | LOW | BE matching | "Similar" field-match detection (fuzzy) NOT implemented. `MatchedFields` only contains EXACT matches (case-insensitive name/email, digit-equal phone, trim-lower address). FE's yellow "similar" highlight will never fire from BE data — FE can still apply client-side fuzzy logic if desired. Same treatment as §⑫ ISSUE-6 in prompt. | OPEN |
| ISSUE-7 | S1 (2026-04-21) | LOW | BE seed dep | `NotDuplicateContact` handler depends on `CONTACTSTATUS.DataValue='NDP'` row — throws `InternalServerException` with clear message if seed missing. Seed IS updated in this session (idempotent). | CLOSED-IN-SESSION |
| ISSUE-8 | S1 (2026-04-21) | LOW | BE column | `ContactAddress.City` is a FK nav to a `City` entity (not a string column). Address composite uses `AddressLine1 + ", " + City.CityName`. Null-safe. | OPEN (info only) |
| ISSUE-9 | S1 (2026-04-21) | LOW | BE column | `ContactEmailAddress.EmailAddress` property does not exist; actual property name is `Email`. Used `Email` in projection. | CLOSED-IN-SESSION |
| ISSUE-10 | S1 (2026-04-21) | LOW | FE hook | `useGenericMutation` doesn't expose `refetchQueries` as a constructor option; view-page passes it via `execute()` call variables spread. Works but less ergonomic. Consider extending the hook to accept a `mutationOptions` pass-through. | OPEN |
| ISSUE-11 | S1 (2026-04-21) | LOW | FE view-page | view-page's new `handleNotDuplicate` is wired but existing view-page UI only exposes Merge/Ignore buttons; `void handleNotDuplicate;` added to prevent unused-var lint. Follow-up UI pass should expose a dedicated "Not Duplicate" button. | OPEN |
| ISSUE-12 | S1 (2026-04-21) | LOW | FE UX | `pending-pair-card` uses simple `isConfirmX` double-click confirm instead of an AlertDialog for NotDuplicate/Ignore — kept card lightweight. A proper AlertDialog confirm would be consistent with view-page's pattern. Future polish. | OPEN |
| ISSUE-13 | S1 (2026-04-21) | MED | FE filter | The mockup uses an `AdvancedFilters` JSON pass-through to BE; BE actually accepts 3 typed optional args. FE serializes filters as top-level GQL variables (correct for the chosen BE contract), NOT into AdvancedFilters. Matches Family #20's quick-filter chip contract. Documented for future cross-screen consistency. | OPEN |
| ISSUE-14 | S1 (2026-04-21) | LOW | Seed | Legacy menu/grid/field/gridfield STEPs remain commented-out in `DuplicateContact-sqlscripts.sql` — intentionally dormant since menu + caps are pre-seeded centrally via `MODULE_MENU_REFERENCE.md`. Script now contains MasterData seeds only (idempotent). | OPEN (info only) |
| ISSUE-15 | S1 (2026-04-21) | INFO | Prompt §⑫ legacy | Pre-flagged §⑫ ISSUE-BE-CRITICAL (`.Include(d => d.Action)` missing in GetDuplicateContactsHandler) — **FIXED** this session. Status column now renders correctly. | CLOSED-IN-SESSION |
| ISSUE-16 | S1 (2026-04-21) | INFO | Prompt §⑫ legacy | Pre-flagged §⑫ ISSUE-FE (`window.location.reload()` after Run Detection) — **FIXED** this session via Apollo `refetchQueries` on DETECT_DUPLICATE_CONTACTS_MUTATION. | CLOSED-IN-SESSION |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-21 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. ALIGN scope. Skipped BA/SR/UX agent spawns (prompt had deep Sections ①–⑫ — Family #20 precedent). Parallel Opus BE + Opus FE developer agents spawned.
- **Files touched**:
  - BE:
    - `Base.Application/Business/ContactBusiness/DuplicateContacts/Commands/NotDuplicateContact.cs` (created)
    - `Base.Application/Business/ContactBusiness/DuplicateContacts/Queries/GetDuplicateContactSummary.cs` (created)
    - `Base.Application/Schemas/ContactSchemas/DuplicateContactSchemas.cs` (modified — added confidence/matchType/matchedFields + 16 flattened from/to projection fields + new `DuplicateContactSummaryDto` class)
    - `Base.Application/Business/ContactBusiness/DuplicateContacts/Queries/GetDuplicateContacts.cs` (modified — added `.Include(d => d.Action)` CRITICAL fix + 3 filter args + post-projection pipeline + in-memory confidence sort)
    - `Base.Application/Business/ContactBusiness/DuplicateContacts/Queries/GetDuplicateContactById.cs` (modified — `.Include(d => d.Action)` parity)
    - `Base.API/EndPoints/Contact/Mutations/DuplicateContactMutations.cs` (modified — `notDuplicateContact` mutation registered)
    - `Base.API/EndPoints/Contact/Queries/DuplicateContactQueries.cs` (modified — `duplicateContactSummary` field registered + `duplicateContacts` extended with 3 optional args)
    - `Base.Application/Mappings/ContactMappings.cs` (modified — noop `TypeAdapterConfig<DuplicateContactSummaryDto, DuplicateContactSummaryDto>.NewConfig()` for consistency)
  - FE:
    - `src/presentation/components/page-components/crm/maintenance/duplicatecontact/duplicatecontact-store.ts` (created — Zustand store: activeStatus/activeCategoryId/sortBy/page/pageSize/merge modal state)
    - `.../duplicatecontact/components/duplicatecontact-widgets.tsx` (created — 4 KPI cards, inline card pattern matching FamilyWidgets; Phosphor icons; Tailwind tokens)
    - `.../duplicatecontact/components/duplicatecontact-filter-bar.tsx` (created — category select + 5 chips + sort select; wired to Zustand)
    - `.../duplicatecontact/components/field-match-row.tsx` (created — reusable label+value+matchState row)
    - `.../duplicatecontact/components/pending-pair-card.tsx` (created — side-by-side comparison card with 4 actions)
    - `.../duplicatecontact/components/resolved-pair-card.tsx` (created — compact row for MRG/NDP/IGN)
    - `.../duplicatecontact/components/merge-modal.tsx` (created — Dialog with direction cells + 5-row field table + transfer summary + warning + confirm button firing MERGE_CONTACTS_MUTATION)
    - `.../duplicatecontact/index-page.tsx` (REWRITE — replaced 3-line FlowDataTable wrapper with Variant B ScreenHeader + widgets + list card + custom card list + MergeModal at page root)
    - `src/domain/entities/contact-service/DuplicateContactDto.ts` (modified — added confidenceLevel/matchType/matchedFields + 16 flattened fields + new `DuplicateContactSummaryDto`)
    - `src/infrastructure/gql-queries/contact-queries/DuplicateContactQuery.ts` (modified — extended `DUPLICATE_CONTACTS_QUERY` + added `DUPLICATE_CONTACT_SUMMARY_QUERY`)
    - `src/infrastructure/gql-mutations/contact-mutations/DuplicateContactMutation.ts` (modified — added `NOT_DUPLICATE_CONTACT_MUTATION`)
    - `.../duplicatecontact/view-page.tsx` (modified — imported new mutation + queries; added `refetchOnResolve` spread on executeMerge/executeIgnore + new handleNotDuplicate; existing 600+ line UI preserved)
  - DB: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/DuplicateContact-sqlscripts.sql` (rewritten — removed commented-out menu/grid/field blocks; added idempotent DUPLICATECATEGORY type + 4 values + CONTACTSTATUS PEN/MRG/IGN + new NDP row)
- **Deviations from spec**:
  - Filter-args contract: prompt §⑩ recommended `AdvancedFilters` JSON pass-through; instead implemented as Family #20-style typed optional args on `duplicateContacts` field (`actionDataValue`, `duplicateCategoryId`, `sortBy`) — no `AdvancedFilters` JSON convention exists in codebase. ISSUE-5/ISSUE-13.
  - `Contact.EngagementScore` column does not exist → projected as `null` stub. ISSUE-4.
  - `ContactAddress.IsPrimary` + `ContactTypeAssignment.IsPrimary` columns do not exist → fallback strategies (first-address-per-contact / max-AssignedDate-type). ISSUE-2/3.
  - No KpiCard primitive exists in the repo → widgets inlined to mirror FamilyWidgets tone-class pattern (primary/success/warning/muted).
  - `pending-pair-card` uses double-click-to-confirm rather than AlertDialog for lightweight UX. ISSUE-12.
- **Known issues opened**: ISSUE-1..6, ISSUE-8, ISSUE-10..14 (see Known Issues table)
- **Known issues closed**: Prompt §⑫ ISSUE-BE-CRITICAL (`.Include(d => d.Action)`) → FIXED. Prompt §⑫ ISSUE-FE (`window.location.reload()`) → FIXED via Apollo refetchQueries. ISSUE-7 (NDP seed dep) → CLOSED-IN-SESSION. ISSUE-9 (`EmailAddress` vs `Email` property) → CLOSED-IN-SESSION. ISSUE-15 + ISSUE-16 → CLOSED-IN-SESSION.
- **Build verification**: `dotnet build` on `Base.API.csproj` — **0 Errors**, 301 warnings (all pre-existing legacy nullability, none reference DuplicateContact). 22.78s compile. UI uniformity grep suite — 5/5 pass (no inline hex, no inline px padding/margin, no bootstrap `.card`, no hand-rolled skeleton hex, no raw "Loading..." text). Variant B confirmed: `ScreenHeader` imported from `@/presentation/components/custom-components/page-header` and rendered at page-root level in `index-page.tsx`.
- **Next step**: (empty — COMPLETED). User to: (1) run `DuplicateContact-sqlscripts.sql` against DB to seed DUPLICATECATEGORY + NDP; (2) run `pnpm dev` and verify page loads at `/en/crm/maintenance/duplicatecontact`; (3) execute full E2E test per §⑪ acceptance criteria (ScreenHeader + 4 widgets + filter bar + pair cards rendered; filter chips wire correctly; Merge→/←Merge open MergeModal with direction; NotDuplicate/Ignore fire respective mutations; Run Detection refetches list+summary; Manual Merge route works).