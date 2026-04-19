---
screen: Family
registry_id: 20
module: Contacts
status: COMPLETED
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-19
completed_date: 2026-04-19
last_session_date: 2026-04-19
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (card-grid list + full-page FORM + DETAIL layout pattern)
- [x] Existing code reviewed (BE Family + FE stub both present)
- [x] Business rules + member-roster workflow extracted
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt Sections ①–⑥ already deep)
- [x] Solution Resolution complete (FLOW + Variant B + card-grid `family` variant locked in prompt)
- [x] UX Design finalized (FORM + DETAIL layouts specified in Section ⑥)
- [x] User Approval received (pre-filled CONFIG block Section ⑨; user granted full-upfront permissions for this build)
- [x] Backend code generated (14 modified + 2 created; `SetFamilyMembers` + `GetFamilySummary`)
- [x] Backend wiring complete (Mutations + Queries endpoints, ContactMappings, DecoratorProperties verified)
- [x] Frontend code generated (15 created + 11 modified; FLOW router, index-page Variant B, view-page, DETAIL, Zustand store, NEW `family` card variant, engagement-score-badge renderer)
- [x] Frontend wiring complete (3 column-type registries + shared-cell-renderers barrel + card-variant registry + card-grid barrel)
- [x] DB Seed script generated (`Family-sqlscripts.sql` — menu upsert + capabilities + BUSINESSADMIN/SUPERADMIN/ADMINISTRATOR grants + Grid FLOW + 11 Fields + 12 GridFields + 5 sample families incl. FAM-0004 headless + FAM-0005 single-member; GridFormSchema SKIP)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `crm/family/family`
- [ ] Grid loads in card-grid mode with `family` variant cards (head avatar / name / address / member list / giving)
- [ ] `?mode=new` — empty FORM layout (full page, NOT modal) renders all sections
- [ ] `?mode=edit&id=X` — FORM layout pre-filled with existing data + member roster
- [ ] `?mode=read&id=X` — DETAIL layout renders (multi-column cards, NOT a disabled form)
- [ ] Create flow: +Add → fill FORM → Save → redirects to `?mode=read&id={newId}` with DETAIL layout
- [ ] Edit flow: DETAIL → Edit button → FORM pre-filled → Save → back to DETAIL
- [ ] FK dropdowns (Country → State → District → City → Pincode) load via ApiSelectV2 and cascade correctly
- [ ] Member-picker inside FORM searches Contacts, adds rows, head-radio designates one, remove clears
- [ ] Save persists roster via `setFamilyMembers` batch mutation
- [ ] Grid card "View" → navigates to `?mode=read&id={id}` (DETAIL page), NOT to Contact detail
- [ ] Grid card "Edit" → navigates to `?mode=edit&id={id}`
- [ ] Member name link inside card → navigates to Contact detail (that Contact, not the family)
- [ ] 4 summary widgets display (Total / With Head / Without Head / Single-Member)
- [ ] Filter chips (All / With Head / Without Head / Single / 3+) switch result set
- [ ] Grid aggregation — `totalFamilyGiving` per card matches DB sum
- [ ] Engagement score badges colour correctly (high ≥ 80 / medium 40-79 / low < 40 / neutral null)
- [ ] Unsaved-changes dialog triggers on back-nav with dirty FORM
- [ ] Toggle active / Delete work (Delete nullifies Contact.FamilyId + IsFamilyHead for all ex-members)
- [ ] DB Seed — menu visible under CRM → Family → Family Management; card-grid metadata applied

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: Family
Module: Contacts (CRM)
Schema: `corg`
Group: ContactModels (namespace: `Base.Domain.Models.ContactModels`)

Business: Family Management groups individual Contacts into a household unit so fundraising, communication, and receipting can be family-aware (single receipt for joint giving, one address for mailings, one designated "family head" for primary correspondence). Each Family has a shared postal address (country → state → district → city → pincode) and an associated roster of Contact records linked by `Contact.FamilyId`. Exactly one member can be marked as Family Head (`Contact.IsFamilyHead = true`). NGO staff use this screen to create new households during contact import/intake, to split/merge families, and to review household-level metrics (total family giving, engagement mix, member composition). The read-mode DETAIL view serves as a household profile page that rolls up donations, engagement, and audit history across all members. It is the companion surface to [Contact #18] and feeds into Donation grouping, Certificate printing, and Campaign outreach.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> ALIGN scope — entity EXISTS. Table below shows CURRENT state + annotated deltas required.
> **CompanyId is NOT a field in the FORM** — FLOW screens get tenant from HttpContext (though the existing column stays).

Table: `corg."Families"` — EXISTS

| Field | C# Type | MaxLen | Required | FK Target | Current / Delta |
|-------|---------|--------|----------|-----------|-----------------|
| FamilyId | int | — | PK | — | CURRENT |
| FamilyCode | string | 100 | YES | — | CURRENT — unique per (CompanyId, IsActive) via filtered index |
| Addresse | string | 100 | YES | — | **RENAME DELTA (optional)**: typo `Addresse` → `AddresseeName` (mockup "Addressee Name"). If migration risk too high, leave column, only alias in DTO + FE label. See ISSUE-1. |
| Address1 | string | 1000 | YES | — | CURRENT |
| Address2 | string? | 1000 | NO | — | CURRENT |
| Address3 | string? | 1000 | NO | — | CURRENT — **NOT in mockup form** — keep, do not render |
| Address4 | string? | 1000 | NO | — | CURRENT — **NOT in mockup form** — keep, do not render |
| CountryId | int | — | YES | corg.Countries | CURRENT |
| StateId | int? | — | NO | corg.States | CURRENT |
| DistrictId | int? | — | NO | corg.Districts | CURRENT |
| CityId | int? | — | NO | corg.Cities | CURRENT |
| PincodeId | int? | — | NO | corg.Pincodes | CURRENT |
| LocalityId | int? | — | NO | corg.Localities | CURRENT — **NOT in mockup form** — keep, do not render |

**Related Contact columns** (already on `corg.Contacts`):

| Field | Type | Role |
|-------|------|------|
| FamilyId | int? | FK to Families — set when Contact joins a Family |
| IsFamilyHead | bool | TRUE for exactly one Contact per Family |

> **Member roster is modelled as `Contact.FamilyId` + `Contact.IsFamilyHead`, NOT via a junction table.** Do NOT introduce a `FamilyMember` join entity — the one-to-many shape on Contact is canonical and the EF nav already exists (`Family.Contacts`).

**Relation label** (shown in mockup as "(Head)", "(Spouse)", "(Son)", "(Daughter)"):
- Contact entity has `RelationId` FK → `Relation` master (general schema or SharedModels).
- Members projected in GetAllFamilyList + GetFamilyById MUST include `relationName` from `Contact.Relation.RelationName`.
- If `Contact.IsFamilyHead == true`, frontend overrides display to "(Head)" regardless of RelationId.

**Child Entities** (for BE projection purposes only — not a separate table):

| Child | Relationship | Key Fields |
|-------|-------------|------------|
| Contact (member) | 1:Many via `Contact.FamilyId` | ContactId, DisplayName, RelationId, IsFamilyHead, EngagementScore |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` + nav) + Frontend Developer (for ApiSelect queries)
> NOTE: codebase uses paginated `XXXs` query fields (NOT `GetAllXxxList`). Columns below carry the **actual** HotChocolate field names.

| FK Field | Target Entity | Entity File Path | GQL Query Field | Display Field | GQL Response Type |
|----------|--------------|-------------------|-----------------|---------------|-------------------|
| CountryId | Country | `Base.Domain/Models/SharedModels/Country.cs` | `countries(request)` | `countryName` | `CountryResponseDto` |
| StateId | State | `Base.Domain/Models/SharedModels/State.cs` | `states(request)` | `stateName` | `StateResponseDto` |
| DistrictId | District | `Base.Domain/Models/SharedModels/District.cs` | `districts(request)` | `districtName` | `DistrictResponseDto` |
| CityId | City | `Base.Domain/Models/SharedModels/City.cs` | `cities(request)` | `cityName` | `CityResponseDto` |
| PincodeId | Pincode | `Base.Domain/Models/SharedModels/Pincode.cs` | `pincodes(request)` | **`code`** (NOT `pincodeName`) | `PincodeResponseDto` |
| — member search — | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | `contacts(request)` | `displayName` | `ContactResponseDto` |
| — relation display — | Relation | `Base.Domain/Models/SharedModels/Relation.cs` | `relations(request)` | `relationName` | `RelationResponseDto` |

**Form FK cascade** (Country → State → District → City → Pincode):
- Country change → reset + refetch States filtered by `countryId`
- State change → reset + refetch Districts filtered by `stateId`
- District change → reset + refetch Cities filtered by `districtId`
- City change → reset + refetch Pincodes filtered by `cityId`
- Reuse Contact-form #18 cascade utility if available; otherwise wire parent-key arg on each `ApiSelectV2` (existing queries accept filter args).

---

## ④ Business Rules & Validation

**Uniqueness Rules:**
- `FamilyCode` unique per `CompanyId` (auto-generated via sequence if blank on create — pattern `FAM-{NNNN}`).
- At most ONE `Contact.IsFamilyHead = true` per `FamilyId` — enforced at mutation layer in `SetFamilyMembers` / `SetFamilyHead` handler (NOT via DB index).

**Required Field Rules:**
- `FamilyCode`, `AddresseeName` (currently `Addresse`), `Address1`, `CountryId` are mandatory.
- All other fields optional.

**Conditional Rules:**
- Family can exist with ZERO members (mockup shows "No Head Assigned" warning state — FAM-0004).
- If `StateId` is set, `State.CountryId` MUST equal the family's `CountryId` (cascade integrity — document as FUTURE enforcement if validator absent).
- A Contact belongs to AT MOST ONE Family (single `Contact.FamilyId` column guarantees this).

**Business Logic:**
- **Auto-generate FamilyCode**: `CreateFamily` handler fills `FamilyCode` via next-sequence if empty.
- **SetFamilyMembers** (batch handler — NEW): accepts `familyId` + `members[{ contactId, isFamilyHead }]`; diffs current vs desired; for each diff: set/clear `Contact.FamilyId`; flips `IsFamilyHead` so exactly one member is head (or none if caller passes all-false). All in ONE EF transaction.
- **RemoveFamilyMember** (inline or separate): sets `Contact.FamilyId = NULL` and `Contact.IsFamilyHead = false`. If removed Contact was head, family has NO head afterwards (no auto-reassignment).
- **DeleteFamily side effect**: nullify `Contact.FamilyId` + `Contact.IsFamilyHead = false` for all members before soft-deleting the Family row.
- **Total Family Giving** (projected per card + on DETAIL page): `SUM(GlobalDonation.Amount)` where `GlobalDonation.ContactId IN (SELECT ContactId FROM Contacts WHERE FamilyId = row.FamilyId AND IsActive = true)`. Projected via LINQ subquery in `GetAllFamilyList` and `GetFamilyById`.
- **Engagement score** (per member): read from `Contact.EngagementScore` (populated by AI Intelligence screen #90 — likely null pre-launch). Threshold: `≥ 80` high (green), `40–79` medium (amber), `< 40` low (red), `null/0` neutral grey.

**Workflow**: None. FLOW pattern is used here for its full-page FORM + DETAIL split, NOT for a state machine. Family has no states beyond IsActive.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — pre-answered decisions.

**Screen Type**: FLOW
**Type Classification**: FLOW with `displayMode: card-grid` on the index grid + full-page view-page for new/edit/read. One route, URL mode carries the context.
**Reason**: User-authoritative classification. Household records warrant a dedicated DETAIL page (multi-column profile with member table, giving rollups, address card, audit trail) and a full-page FORM (the mockup modal content scales naturally to a page — members, address sections, and future fields don't fit comfortably in a fixed-width modal over time). The index grid retains the mockup's card-grid card layout for scan-friendly listing.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — ALREADY EXIST. MODIFY only (ALIGN).
- [x] Tenant scoping via HttpContext (CompanyId) — already in place
- [x] Multi-FK validation (Country/State/District/City/Pincode) — already in place
- [x] Unique validation on `FamilyCode` — already in place
- [x] **Nested child projection** — members[] from `Family.Contacts` in GetAll + GetById
- [x] **Member management command (NEW)** — batch `SetFamilyMembers` (replaces 3 separate Add/Remove/SetHead for simplicity)
- [x] **Summary query (NEW)** — `GetFamilySummary` → 4 widget counts
- [ ] Workflow commands — N/A
- [ ] File upload — N/A
- [x] Custom validator — single-head-per-family invariant in `SetFamilyMembers` handler

**Frontend Patterns Required:**
- [x] FlowDataTable / DataTableContainer (index grid host — Variant B with `showHeader={false}`)
- [x] **`displayMode: card-grid` + NEW `family` card variant** — card-grid infra exists (`.claude/feature-specs/card-grid.md`), but `family` variant is NEW. Leave `profile` stub in place for Contact #18 / Staff #42.
- [x] `view-page.tsx` with 3 URL modes (new / edit / read)
- [x] React Hook Form (FORM layout)
- [x] Zustand store (`family-store.ts`)
- [x] Unsaved-changes dialog (FlowFormPageHeader built-in)
- [x] FlowFormPageHeader (Back + Save/Edit buttons)
- [x] **Custom child UI in FORM** — member-picker panel (search Contacts + list + head-radio + remove)
- [x] **Filter chips above grid** — 5 quick-filter chips (All / With Head / Without Head / Single / 3+)
- [x] Summary cards / count widgets above grid (4 widgets)
- [x] Grid aggregation — `totalFamilyGiving` per card
- [x] Engagement-score badge (reusable renderer — first built here)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from `html_mockup_screens/screens/contacts/family-management.html`.
> **Two UI layouts** — FORM (new/edit) and DETAIL (read) — both full-page.

### Grid/List View

**Display Mode**: `card-grid`

**Card Variant**: `family` (NEW — introduce in card-grid infra).

> Standard `profile` variant supports avatar + name + subtitle + meta + contact-actions. Insufficient for Family (member list + giving footer + "No Head" warning). Introducing a localised `family` variant keeps `profile` clean for Contact/Staff/Volunteer. Profile stub at `variants/profile-card.tsx` remains as error placeholder for its first real consumer.

**Card Config** (add to `card-grid/types.ts`):

```yaml
cardConfig:
  variant: "family"
  codeField: "familyCode"             # FAM-0001 label in header
  memberCountField: "membersCount"    # badge — "3 members"
  headAvatarField: null               # null → render initials from headDisplayName
  headNameField: "headDisplayName"    # nullable — null triggers "No Head Assigned" warning
  addressField: "addressSingleLine"   # BE-projected combined string
  membersField: "members"             # list of FamilyMemberDto
  givingField: "totalFamilyGiving"    # currency — "Total Family Giving  $8,450"
  primaryAction: "VIEW"               # navigates to ?mode=read&id=... (DETAIL page)
  secondaryActions: ["EDIT", "ADD_MEMBER"]  # EDIT → ?mode=edit&id=... ; ADD_MEMBER → ?mode=edit&id=&focus=members
```

**Card layout** (responsive grid, 1 → 2 → 3 cols across xs → sm → lg; `gap-3`, card `p-4`, `rounded-lg`, `border border-border bg-card`):

```
┌─────────────────────────────────────────┐
│ FAM-0001                  [3 members]  │   code (xs uppercase muted) + members pill (primary-tint)
├─────────────────────────────────────────┤
│  [SJ]  Sarah Johnson  👑               │   head avatar + head name + crown icon
│        Family Head                      │     OR warning avatar + "⚠ No Head Assigned"
├─────────────────────────────────────────┤
│  📍 456 Oak Avenue, Springfield, IL...  │   single-line address (truncate)
├─────────────────────────────────────────┤
│  MEMBERS                                │   bg-muted/40 rounded-md p-2 panel
│  Sarah Johnson  (Head)        [92]     │   member name = link to Contact detail
│  Michael Johnson  (Spouse)    [78]     │
│  Emma Johnson  (Daughter)     [45]     │
├─────────────────────────────────────────┤
│  TOTAL FAMILY GIVING    $8,450         │   border-t + primary-coloured bold amount
├─────────────────────────────────────────┤
│  [View] [Edit] [+ Add Member]           │   primary / outline / outline
└─────────────────────────────────────────┘
```

**Engagement badge** (circular 24×24, white text):
- `≥ 80` → `bg-success`
- `40–79` → `bg-warning`
- `< 40` → `bg-destructive`
- `null/0` → `bg-muted text-muted-foreground`

**Warning state (no head)** — when `headDisplayName === null`:
- Head avatar block uses `bg-warning` + exclamation icon (`ph:warning`).
- Head-name line renders warning-coloured "⚠ No Head Assigned".
- Card body otherwise unchanged.

**Responsive breakpoints**: 1 col (`xs`) → 2 col (`sm`) → 3 col (`lg`) → 3 col (`xl`). 3-col cap preserves card density.

**Build dependency**: add to `card-grid/` infrastructure —
- `types.ts` → `CardVariant` union + `FamilyCardConfig` interface
- `card-variant-registry.ts` → `family: { Card: FamilyCard, Skeleton: FamilyCardSkeleton }`
- `variants/family-card.tsx` — full implementation
- `skeletons/family-card-skeleton.tsx` — matching shimmer

**Grid Columns** (when falling back to table mode / for export — keep minimal):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Family Code | familyCode | text | 120px | YES | — |
| 2 | Addressee | addresseName | text | 200px | YES | alias of `addresse` |
| 3 | Head | headDisplayName | text | 180px | YES | "—" when null |
| 4 | Members | membersCount | number | 90px | YES | Right-aligned |
| 5 | Country | countryName | text | 120px | YES | — |
| 6 | City | cityName | text | 140px | YES | Nullable |
| 7 | Total Giving | totalFamilyGiving | currency | 130px | YES | Right-aligned |
| 8 | Status | isActive | badge | 100px | YES | Active / Inactive |

**Search/Filter Fields**: `familyCode`, member `displayName` (projected), `address1`, `addresse`.

**Quick Filter Chips** (above grid — wired into DataTable filter state + GQL args):

| Chip | BE args |
|------|---------|
| All | _none_ |
| With Head | `hasHead: true` |
| Without Head | `hasHead: false` |
| Single Member | `memberCountMin: 1, memberCountMax: 1` |
| 3+ Members | `memberCountMin: 3` |

Extend `GetAllFamilyList` with `hasHead: bool?`, `memberCountMin: int?`, `memberCountMax: int?`.

**Grid Actions (on-card)**:
- **View** (primary): navigate to `?mode=read&id={familyId}` (DETAIL page).
- **Edit** (outline): navigate to `?mode=edit&id={familyId}` (FORM page).
- **Add Member** (outline): navigate to `?mode=edit&id={familyId}&focus=members` (FORM page, scroll/focus member panel).

**Row Click**: whole-card click (outside buttons) also navigates to `?mode=read&id={familyId}`.

**Member-name link inside card**: navigates to `/{lang}/crm/contact/allcontacts?id={contactId}` (Contact detail, NOT Family detail).

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

```
URL MODE                              UI LAYOUT
─────────────────────────────────     ──────────────────────────
/crm/family/family?mode=new       →   FORM LAYOUT  (empty form)
/crm/family/family?mode=edit&id=X →   FORM LAYOUT  (pre-filled)
/crm/family/family?mode=read&id=X →   DETAIL LAYOUT (household profile — different UI)
```

---

#### LAYOUT 1: FORM (mode=new & mode=edit)

> Full-page form (NOT a modal). Mockup's Bootstrap modal content expanded to a page with FlowFormPageHeader.
> Built with React Hook Form. Must match mockup section structure.

**Page Header**: `FlowFormPageHeader` — Back button, title ("New Family" | "Edit Family — FAM-XXXX"), Save button, unsaved-changes dialog.

**Section Container Type**: cards (each section is a `<Card>` with title and optional divider).

**Form Sections** (in display order):

| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | `ph:identification-card` | Family Details | 2-column | expanded | `familyCode`, `addresseeName` |
| 2 | `ph:map-pin` | Shared Address | mixed | expanded | `address1` (full row), `address2` (full row), `countryId` + `stateId` (2-col), `districtId` + `cityId` + `pincodeId` (3-col) |
| 3 | `ph:users-three` | Family Members | 1-col full-width | expanded | **custom `family-members-picker` component** |

**Field Widget Mapping**:

| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| familyCode | 1 | text | "Auto-generated" | optional on create; max 100 | BE fills via sequence if blank |
| addresseeName | 1 | text | "e.g., The Johnson Family" | required; max 100 | Maps to `Addresse` (or renamed column if ISSUE-1 resolved) |
| address1 | 2 | text | "Street address" | required; max 1000 | — |
| address2 | 2 | text | "Apartment, suite, etc." | optional; max 1000 | — |
| countryId | 2 | ApiSelectV2 | "Select country…" | required | Query: `countries` |
| stateId | 2 | ApiSelectV2 | "Select state…" | optional | Query: `states` filtered by `countryId` |
| districtId | 2 | ApiSelectV2 | "Select…" | optional | Query: `districts` filtered by `stateId` |
| cityId | 2 | ApiSelectV2 | "Select…" | optional | Query: `cities` filtered by `districtId` |
| pincodeId | 2 | ApiSelectV2 | "Postal code" | optional | Query: `pincodes` filtered by `cityId`; display `code` |
| members | 3 | **custom `family-members-picker`** | — | optional | See Special Widgets below |

**Special Form Widgets:**

- **family-members-picker** (dedicated React component, NOT an RJSF widget since FORM is React Hook Form):
  - Top: list of currently-added members as horizontal rows. Each row: mini-avatar (initials), display name, relation label (from `contact.relation.relationName`), `<input type="radio" name="familyHead">` to designate head, remove (×) button.
  - Bottom: "Search & Add Member" dashed-border button → clicking expands an inline ApiSelectV2 (query: `contacts` with `searchTerm`, excludes already-added Contacts + Contacts already in another Family). User picks → appends to `members` field in form state.
  - Form state shape (`members` field):
    ```ts
    members: Array<{
      contactId: number;
      displayName: string;
      initials: string;
      relationName?: string;
      engagementScore?: number;
      isFamilyHead: boolean;
    }>
    ```
  - Head radio: selecting "Head" on one row flips `isFamilyHead` to true on that row and false on all others.
  - Remove (×): splices row out of `members[]`. If removed row was head, no auto-reassignment (family is now headless).
  - `?focus=members` query param → component scrolls to + opens the "Search & Add Member" input on mount.

- **Conditional Sub-forms**: N/A
- **Card Selectors**: N/A
- **Inline Mini Display**: N/A

**Child Grids in Form**: The family-members-picker IS the child roster. Not a grid per se — a row list with actions.

**On Save:**
- On `mode=new`: FE calls `createFamily` mutation → receives new `familyId` → calls `setFamilyMembers(familyId, members)` batch → on success navigates to `?mode=read&id={newId}`.
- On `mode=edit`: FE calls `updateFamily` mutation → calls `setFamilyMembers(familyId, members)` batch → on success navigates to `?mode=read&id={id}`.
- Two sequential mutations are acceptable here (members batch is idempotent). Alternative: add a single `saveFamilyWithMembers` command — not required for v1.

---

#### LAYOUT 2: DETAIL (mode=read) — different UI from the FORM

> Full-page household profile. Mockup does NOT show an explicit detail page — this is derived from the card + natural extension per FLOW-screen convention. Must NOT be the FORM disabled-in-place.
> Build as a multi-column page with cards + member table + audit.

**Page Header**: `FlowFormPageHeader` — Back button, title ("Family — FAM-XXXX"), action buttons: Edit (→ `?mode=edit&id=X`), More dropdown: Duplicate (SERVICE_PLACEHOLDER), Delete.

**Page Layout**: 2-column (`lg:grid-cols-3`, gap-6) — main content 2fr, side column 1fr. Stacks single-column on `< lg`.

**Left Column Cards** (in order):

| # | Card Title | Content |
|---|-----------|---------|
| 1 | Family Profile | Family code (xs uppercase), addressee name (h3), members-count badge, active/inactive badge |
| 2 | Shared Address | Country flag/name, full address lines (Address1 / Address2), city, state, pincode, district (2-col grid of labelled values) |
| 3 | Members ({count}) | Table: Avatar / Name (link to Contact detail) / Relation / Engagement score badge / Head badge / Last Giving Date. Column widths match mockup member-list but with more columns. "Add Member" button opens a modal OR navigates to `?mode=edit&id=X&focus=members`. |
| 4 | Recent Donations (last 10 across all members) | Table: Date / Member / Amount / Purpose / Mode. Data: `GlobalDonations` where `ContactId IN members` ordered desc. |

**Right Column Cards** (in order):

| # | Card Title | Content |
|---|-----------|---------|
| 1 | Household Stats | 4 mini-stats: Total Giving (currency, primary colour), Avg Engagement Score (number), Members Count, Years Active (now - createdDate) |
| 2 | Head of Family | If head exists: Avatar / Name / "View Profile" link. If not: warning block + "Assign Head" CTA → navigates to `?mode=edit&id=X&focus=members` |
| 3 | Audit Trail | Timeline: Created (date + user), Last Modified (date + user). Future: status-change log. |

**If the mockup ever adds a dedicated detail view**, re-align; for now, the above is the contracted DETAIL layout. Document in Section ⑫ ISSUE-11.

---

### Page Widgets & Summary Cards

**Widgets**: 4 summary widgets above the index grid.

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | Total Families | `familySummary.totalFamilies` | count | Row 1 col 1 |
| 2 | With Head | `familySummary.familiesWithHead` | count | Row 1 col 2 |
| 3 | Without Head | `familySummary.familiesWithoutHead` | count (warning colour) | Row 1 col 3 |
| 4 | Single-Member | `familySummary.singleMemberFamilies` | count | Row 1 col 4 |

**Grid Layout Variant**: `widgets-above-grid` (Variant B). FE Dev uses `<ScreenHeader>` + widget row + `<DataTableContainer showHeader={false}>`.

**Summary GQL Query** — NEW:
- Query field: `familySummary` → returns `FamilySummaryDto { totalFamilies, familiesWithHead, familiesWithoutHead, singleMemberFamilies, multiMemberFamilies }`
- Scoped to `CompanyId` via HttpContext.
- Added to `FamilyQueries.cs` alongside `families` + `familyById`.

### Grid Aggregation Columns

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Members | Active members count | `Family.Contacts.Count(c => c.IsActive)` | Project `membersCount` in GetAllFamilyList |
| Has Head | Any member is head | `Family.Contacts.Any(c => c.IsFamilyHead)` | Project `hasHead` |
| Head Display | Head name + contactId | `Family.Contacts.FirstOrDefault(c => c.IsFamilyHead)` | Project `headContactId` + `headDisplayName` |
| Total Giving | Sum donations by members | LINQ subquery over `GlobalDonations` | Project `totalFamilyGiving` |

### User Interaction Flow (FLOW — 3 modes, 2 UI layouts)

1. User lands on grid → 4 widgets + filter chips + search + card-grid render.
2. User clicks "+New Family" → URL: `?mode=new` → FORM layout loads (empty).
3. User fills address + adds members + sets head → clicks Save → BE creates Family → FE fires `setFamilyMembers` → URL redirects to `?mode=read&id={newId}` → DETAIL layout loads.
4. User clicks Edit (header or card) → URL: `?mode=edit&id={id}` → FORM layout pre-filled with current state + member roster.
5. User edits → Save → BE updates + syncs members → redirects back to `?mode=read&id={id}` → DETAIL layout.
6. From grid: user clicks a card (or View button) → URL: `?mode=read&id={id}` → DETAIL layout.
7. User clicks member name inside a card OR inside the DETAIL members table → navigates OUT to `/{lang}/crm/contact/allcontacts?id={contactId}` (Contact detail — NOT Family detail).
8. User clicks "+ Add Member" on a card → URL: `?mode=edit&id={id}&focus=members` → FORM loads + scrolls/focuses the member-picker.
9. Back button: → URL: `/crm/family/family` (no params) → returns to grid.
10. Unsaved changes: if FORM is dirty and user navigates, confirm dialog fires.

---

## ⑦ Substitution Guide

**Canonical Reference**: SavedFilter (FLOW) for view-page + Zustand store plumbing. SMS Template #29 / Email Template #24 for card-grid + DataTableContainer wiring.

| Canonical (SavedFilter) | → This Entity (Family) | Context |
|-------------------------|------------------------|---------|
| SavedFilter | Family | Entity/class name |
| savedFilter | family | Variable/field names |
| SavedFilterId | FamilyId | PK field |
| SavedFilters | Families | Table / collection |
| saved-filter | family | kebab-case (single word — no dash) |
| savedfilter | family | FE folder / import path |
| SAVEDFILTER | FAMILY | Grid code / menu code |
| notify | corg | DB schema |
| Notify | Contact | Backend group name |
| NotifyModels | ContactModels | Namespace suffix |
| COMMUNICATION | CRM_FAMILY | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/family/family | FE route path |
| notify-service | contact-service | FE service folder (Family lives in same service as Contact/ContactType) |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> ALIGN scope — most BE files EXIST. FE is near-greenfield. Manifest marks each as `MODIFY`, `CREATE`, or `DELETE`.

### Backend Files

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Entity | `Base.Domain/Models/ContactModels/Family.cs` | MODIFY (optional rename `Addresse` → `AddresseeName` per ISSUE-1) |
| 2 | EF Config | `Base.Infrastructure/Data/Configurations/ContactConfigurations/FamilyConfiguration.cs` | MODIFY (update HasColumnName if rename; clean stale `FamilyStatueId` comment) |
| 3 | Schemas (DTOs) | `Base.Application/Schemas/ContactSchemas/FamilySchemas.cs` | MODIFY — add `FamilyMemberDto`; extend `FamilyResponseDto` with `members`, `membersCount`, `hasHead`, `headContactId`, `headDisplayName`, `totalFamilyGiving`, `addressSingleLine`; add `FamilySummaryDto`; add `SetFamilyMembersRequestDto`; DELETE unused `CreateFamilyMemberRequestDto` + `CreateFamilyMemberResponseDto` |
| 4 | Create Command | `Base.Application/Business/ContactBusiness/Families/CreateFamily.cs` | MODIFY — verify auto-code gen; no behaviour change |
| 5 | Update Command | `…/Families/UpdateFamily.cs` | MODIFY — no behaviour change |
| 6 | Delete Command | `…/Families/DeleteFamily.cs` | MODIFY — on delete, nullify `Contact.FamilyId` + `IsFamilyHead = false` for all members in same transaction |
| 7 | Toggle Command | `…/Families/ToggleFamily.cs` | MODIFY — no behaviour change |
| 8 | GetAll Query | `…/Families/GetFamily.cs` | MODIFY — add projection for members[], membersCount, hasHead, headContactId, headDisplayName, totalFamilyGiving (LINQ subquery), addressSingleLine; add filter args `hasHead`, `memberCountMin`, `memberCountMax` |
| 9 | GetById Query | `…/Families/GetFamilyById.cs` | MODIFY — `.Include(Contacts).ThenInclude(Relation)` + project members[] with relationName; return nested FK display names for FORM pre-fill |
| 10 | Export Query | `…/Families/ExportFamily.cs` | MODIFY — add membersCount, hasHead, headDisplayName, totalFamilyGiving to export columns |
| 11 | SetFamilyMembers Command | `…/Families/SetFamilyMembersCommand/SetFamilyMembers.cs` | **CREATE** — batch handler (diff + apply + enforce single-head invariant) |
| 12 | GetFamilySummary Query | `…/Families/GetFamilySummaryQuery/GetFamilySummary.cs` | **CREATE** — returns `FamilySummaryDto` |
| 13 | Mutations endpoint | `Base.API/EndPoints/Contact/Mutations/FamilyMutations.cs` | MODIFY — register `setFamilyMembers`; **fix mutation arg nullability BUG** (optional FKs currently declared as non-nullable) |
| 14 | Queries endpoint | `Base.API/EndPoints/Contact/Queries/FamilyQueries.cs` | MODIFY — add `familySummary` field |

### Backend Wiring Updates

| # | File | Action |
|---|------|--------|
| 1 | `IContactDbContext.cs` | No change (DbSet already present) |
| 2 | `ContactDbContext.cs` | No change |
| 3 | `DecoratorProperties.cs` → `DecoratorContactModules` | Verify `Family` entry; add if missing |
| 4 | `ContactMappings.cs` (Mapster) | MODIFY — register explicit maps for `FamilyMemberDto`, `FamilySummaryDto`; ensure new projected fields round-trip |
| 5 | Migration | **CREATE** only if ISSUE-1 column rename approved; otherwise none |

### Frontend Files

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO Types | `src/domain/entities/contact-service/FamilyDto.ts` | MODIFY — add `FamilyMemberDto`, `FamilySummaryDto`, `SetFamilyMembersRequestDto`; extend `FamilyResponseDto` |
| 2 | GQL Query | `src/infrastructure/gql-queries/contact-queries/FamilyQuery.ts` | MODIFY — extend `FAMILIES_QUERY` (new fields + filter args); extend `FAMILY_BY_ID_QUERY` (nested relations + members[]); add `FAMILY_SUMMARY_QUERY` |
| 3 | GQL Mutation | `src/infrastructure/gql-mutations/contact-mutations/FamilyMutation.ts` | MODIFY — **fix optional-field nullability BUG**; add `SET_FAMILY_MEMBERS_MUTATION` |
| 4 | Page Config | `src/presentation/pages/crm/family/family.tsx` | MODIFY — switch to FLOW router pattern (SavedFilter precedent): renders `FamilyRouter` that splits on `?mode` param; includes `displayMode: "card-grid"` + `cardVariant: "family"` + `cardConfig` for the index grid |
| 5 | Router | `src/presentation/components/page-components/crm/family/family/index.tsx` | **CREATE** — `FamilyRouter` reads `useSearchParams()`: if no `mode` → render `IndexPage`; else → render `ViewPage` with mode prop (matches SavedFilter/Global-Donation pattern) |
| 6 | Index Page | `src/presentation/components/page-components/crm/family/family/index-page.tsx` | **CREATE** — Variant B: `<ScreenHeader>` + 4 `<Widget>` cards + filter-chip row + `<FlowDataTableContainer showHeader={false}>` hosting the CardGrid |
| 7 | **View Page (3 modes)** | `src/presentation/components/page-components/crm/family/family/view-page.tsx` | **CREATE** — renders FORM (new/edit) OR DETAIL (read) based on mode prop |
| 8 | **Zustand Store** | `src/presentation/components/page-components/crm/family/family/family-store.ts` | **CREATE** — FORM dirty state, pending members roster, focus-members flag |
| 9 | Family Card variant | `src/presentation/components/page-components/card-grid/variants/family-card.tsx` | **CREATE** — per Section ⑥ layout |
| 10 | Family Card skeleton | `src/presentation/components/page-components/card-grid/skeletons/family-card-skeleton.tsx` | **CREATE** |
| 11 | Card types | `src/presentation/components/page-components/card-grid/types.ts` | MODIFY — add `"family"` to `CardVariant` + `FamilyCardConfig` interface |
| 12 | Card variant registry | `src/presentation/components/page-components/card-grid/card-variant-registry.ts` | MODIFY — register `family` entry |
| 13 | Family Widgets | `src/presentation/components/page-components/crm/family/family/family-widgets.tsx` | **CREATE** — 4 count widgets from `FAMILY_SUMMARY_QUERY` |
| 14 | Family Members Picker | `src/presentation/components/page-components/crm/family/family/family-members-picker.tsx` | **CREATE** — FORM child: search + list + head-radio + remove |
| 15 | Family Filter Chips | `src/presentation/components/page-components/crm/family/family/family-filter-chips.tsx` | **CREATE** — 5 chips bound to DataTable filter state |
| 16 | Family Detail | `src/presentation/components/page-components/crm/family/family/family-detail.tsx` | **CREATE** — DETAIL layout (2-col profile page, rendered by view-page in `read` mode) |
| 17 | Engagement badge renderer | `src/presentation/components/custom-components/shared-cell-renderers/engagement-score-badge.tsx` | **CREATE** — reusable (Contact #18 will reuse) |
| 18 | Data Table | `src/presentation/components/page-components/crm/family/family/data-table.tsx` | MODIFY — keep existing, but retarget as `<FlowDataTable>` host with card-grid mode; wire filter chip state |
| 19 | Index barrel | `src/presentation/components/page-components/crm/family/family/index.ts` | MODIFY — export Router + IndexPage + ViewPage + FamilyDataTable |
| 20 | Route page | `src/app/[lang]/crm/family/family/page.tsx` | NO CHANGE (already renders `FamilyPageConfig`) |

### Frontend Wiring Updates

| # | File | Action |
|---|------|--------|
| 1 | `entity-operations.ts` | VERIFY `FAMILY` operations config |
| 2 | `operations-config.ts` | No change expected |
| 3 | Sidebar menu config | VERIFY `FAMILY` under `CRM_FAMILY` parent |
| 4 | Column-type registries (advanced/basic/flow × 3) | REGISTER `engagement-score-badge` renderer |
| 5 | `shared-cell-renderers/index.ts` barrel | EXPORT `EngagementScoreBadge` |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: ALIGN

MenuName: Family Management
MenuCode: FAMILY
ParentMenu: CRM_FAMILY
Module: CRM
MenuUrl: crm/family/family
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP

GridCode: FAMILY

DisplayMode: card-grid
CardVariant: family
---CONFIG-END---
```

> **Note**: FLOW screens skip GridFormSchema (no RJSF modal — FORM is built in code as React Hook Form). `DisplayMode` + `CardVariant` grid metadata still flow through the same seed mechanism used by SMS Template #29 / Email Template #24.

---

## ⑩ Expected BE→FE Contract

**GraphQL Types:**
- Query type: `FamilyQueries`
- Mutation type: `FamilyMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `families(request)` | paginated `FamilyResponseDto` | searchText, pageNo, pageSize, sortField, sortDir, isActive, `hasHead: Boolean`, `memberCountMin: Int`, `memberCountMax: Int` |
| `familyById(familyId)` | `FamilyResponseDto` | familyId |
| `familySummary` | `FamilySummaryDto` | — |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createFamily(family)` | `FamilyRequestDto` | `BaseApiResponse<FamilyRequestDto>` |
| `updateFamily(family)` | `FamilyRequestDto` | `BaseApiResponse<FamilyRequestDto>` |
| `deleteFamily(familyId)` | `Int!` | int |
| `activateDeactivateFamily(familyId)` | `Int!` | int |
| `setFamilyMembers(request)` | `SetFamilyMembersRequestDto` | int (rowsAffected) |

**`FamilyResponseDto` fields** (what FE receives):

| Field | Type | Notes |
|-------|------|-------|
| familyId | number | PK |
| familyCode | string | — |
| addresse / addresseeName | string | Current = `addresse`; post-rename = `addresseeName` |
| address1 | string | — |
| address2 | string? | — |
| address3 | string? | Returned but not rendered |
| address4 | string? | Returned but not rendered |
| countryId | number | — |
| country | `{ countryId, countryName }` | Nested nav |
| stateId | number? | — |
| state | `{ stateId, stateName }?` | Nested |
| districtId | number? | — |
| district | `{ districtId, districtName }?` | — |
| cityId | number? | — |
| city | `{ cityId, cityName }?` | — |
| pincodeId | number? | — |
| pincode | `{ pincodeId, code }?` | Display field is `code` |
| localityId | number? | Returned but not rendered |
| isActive | boolean | — |
| **addressSingleLine** | string | BE-computed combined string for card display |
| **members** | `FamilyMemberDto[]` | `Family.Contacts.Where(c => c.IsActive)` |
| **membersCount** | number | Count |
| **hasHead** | boolean | `members.Any(m => m.isFamilyHead)` |
| **headContactId** | number? | null when no head |
| **headDisplayName** | string? | null when no head |
| **totalFamilyGiving** | number | LINQ subquery over GlobalDonations |

**`FamilyMemberDto`**:
| Field | Type | Notes |
|-------|------|-------|
| contactId | number | — |
| displayName | string | — |
| initials | string | BE-computed from displayName (2 chars) |
| relationName | string? | from `Contact.Relation.RelationName` |
| engagementScore | number? | from `Contact.EngagementScore` |
| isFamilyHead | boolean | — |

**`FamilySummaryDto`**:
| Field | Type |
|-------|------|
| totalFamilies | number |
| familiesWithHead | number |
| familiesWithoutHead | number |
| singleMemberFamilies | number |
| multiMemberFamilies | number |

**`SetFamilyMembersRequestDto`**:
| Field | Type |
|-------|------|
| familyId | number |
| members | `[{ contactId: number, isFamilyHead: boolean }]` |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — 0 errors on `Base.Domain`, `Base.Infrastructure`, `Base.Application`, `Base.API`
- [ ] `pnpm tsc --noEmit` — 0 new errors in `family/`, `card-grid/`, `contact-service/`
- [ ] `pnpm dev` — page loads at `/{lang}/crm/family/family`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid index: 4 widgets render with correct counts (5 total, 4 with head, 1 without, 1 single-member, 4 multi-member in seed).
- [ ] Search by `FAM-0001` → FAM-0001 card only.
- [ ] Search by member name "Sarah" → FAM-0001 card.
- [ ] Search by address "Oak" → FAM-0001 card.
- [ ] Filter chip "Without Head" → FAM-0004 only.
- [ ] Filter chip "Single Member" → FAM-0005 only.
- [ ] Filter chip "3+ Members" → FAM-0001 + FAM-0002 + FAM-0004.
- [ ] Each card renders all 8 elements per §⑥ layout; warning state renders for FAM-0004.
- [ ] Engagement badge colour banding correct.
- [ ] Member name links inside cards navigate to `/crm/contact/allcontacts?id={contactId}`.
- [ ] "+New Family" → URL `?mode=new` → empty FORM page loads with 3 sections.
- [ ] Country → State → District → City → Pincode cascade works.
- [ ] Member-picker adds / removes Contacts; head radio designates one; remove blanks head if was head.
- [ ] Save on new → BE creates → BE sets members → URL redirects to `?mode=read&id={newId}` → DETAIL loads.
- [ ] Click Edit on DETAIL → URL `?mode=edit&id=X` → FORM pre-filled including member roster + relation labels + engagement scores + head selection.
- [ ] Save on edit → BE updates → members sync → URL → `?mode=read&id=X` → DETAIL layout.
- [ ] Grid card View button → URL `?mode=read&id=X` → DETAIL loads.
- [ ] Grid card Edit button → URL `?mode=edit&id=X` → FORM pre-filled.
- [ ] Grid card +Add Member button → URL `?mode=edit&id=X&focus=members` → FORM pre-filled, member-picker focused.
- [ ] DETAIL page Profile/Address/Members/Recent Donations + Household Stats/Head/Audit cards render correctly.
- [ ] DETAIL "Add Member" CTA navigates to `?mode=edit&id=X&focus=members`.
- [ ] DETAIL "View Profile" link (head card) navigates to Contact detail.
- [ ] Unsaved changes dialog fires on dirty FORM nav.
- [ ] Toggle active flips isActive; Delete nullifies Contact.FamilyId for all members then soft-deletes.
- [ ] Total Family Giving matches `SUM(GlobalDonations.Amount)` over family's members in DB.
- [ ] Permissions: BUSINESSADMIN sees all actions; lower roles respect capabilities.

**DB Seed Verification:**
- [ ] Menu "Family Management" appears under CRM → Family.
- [ ] Grid config includes `DisplayMode: card-grid` + `CardVariant: family`.
- [ ] GridFormSchema is SKIP (FLOW — FORM is React Hook Form in view-page.tsx).
- [ ] 5–6 sample Family rows exist for E2E testing (include headless FAM-0004 + single-member FAM-0005).

---

## ⑫ Special Notes & Warnings

- **SCREEN TYPE**: FLOW (user-authoritative). Use `_FLOW.md` template — view-page with 3 URL modes + Zustand store + full-page FORM + dedicated DETAIL layout. Index grid uses `displayMode: card-grid` with NEW `family` variant.
- **Group name**: `ContactModels` (not `CorgModels`) — namespace is `Base.Domain.Models.ContactModels`. Schema is `corg`.
- **GQL field naming**: HotChocolate uses paginated `families`, `contacts`, `countries`, etc. — NOT `GetAll*List` pattern.
- **Member roster IS on Contact, NOT a junction entity** — DO NOT introduce a `FamilyMember` join table. DELETE the unused `CreateFamilyMemberRequestDto` / `CreateFamilyMemberResponseDto` stubs from `FamilySchemas.cs` in this pass.
- **ProfileCard stub stays stubbed** — Family introduces a SEPARATE `"family"` variant. Leave `variants/profile-card.tsx` as the error-placeholder stub for Contact #18 / Staff #42 to promote later.
- **Mutation nullability BUG** (must fix): `FamilyMutation.ts` currently declares optional FKs (`stateId`, `districtId`, `cityId`, `pincodeId`, `localityId`, `address2/3/4`) as `Int!` / `String!`. Any Save with blanks → GraphQL validation error.
- **Address3 / Address4 / LocalityId** are preserved in the entity but rendered nowhere — simply omit from FORM sections + card + DETAIL layout.
- **FE folder is near-greenfield** — only `data-table.tsx` + `index.ts` exist today (both FLOW-stub style). Treat as greenfield for the FLOW build under the `family/family/` page-components folder.
- **DETAIL layout is NOT in the mockup** — derived from standard FLOW convention (SavedFilter / GlobalDonation DETAIL page precedent). Document as ISSUE-11 so reviewers know it's inferred, not mockup-authoritative.
- **ALIGN discipline**: prefer MODIFY over CREATE on BE files. CREATE list is `SetFamilyMembersCommand`, `GetFamilySummaryQuery`, all FE files except `data-table.tsx` + `index.ts` + route page.
- **Canonical for card-grid plumbing**: SMS Template #29 (details variant) + Email Template #24 (iframe variant) — copy their `index-page.tsx` + page-config + seed-script patterns, substituting `family` variant + config shape.
- **Migration caution**: ISSUE-1 (Addresse → AddresseeName rename) is gated — recommend DTO-alias-only (cosmetic) unless the handler confirms migration risk is acceptable.

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ **SERVICE_PLACEHOLDER: Engagement Score colour** — `Contact.EngagementScore` populated by #90 Engagement Scoring (P4-Advanced). Pre-launch most badges render neutral grey; UI is complete.
- ⚠ **SERVICE_PLACEHOLDER: Relation labels** — depend on Contacts having `RelationId` populated. Fallback display "(Member)" when missing.
- ⚠ **SERVICE_PLACEHOLDER: Duplicate Family (DETAIL more-menu)** — no duplicate-family service exists. Button shows toast.
- ⚠ **SERVICE_PLACEHOLDER: Household Stats "Years Active"** — uses `createdDate` - now(); fine as is, documented for clarity.

Full UI must be built (card grid, FORM page, DETAIL page, member picker, filter chips, widgets). Only the upstream data populations (engagement / relation) are dependent on upstream screens.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Planning (2026-04-19) | LOW | BE | Typo column `Addresse` on `corg.Families` should be `AddresseeName`. Rename needs migration + Mapster + FE label. Handler decides: rename vs DTO-alias-only (recommended cosmetic alias). | OPEN |
| ISSUE-2 | Planning (2026-04-19) | HIGH | BE→FE | `FamilyMutation.ts` declares optional FKs (`stateId/districtId/cityId/pincodeId/localityId/address2/3/4`) as non-nullable (`Int!` / `String!`). Save with blanks → GraphQL parse error. MUST fix. | OPEN |
| ISSUE-3 | Planning (2026-04-19) | MED | BE | `GetFamiliesQuery` does not project Contacts / members list / giving totals. Card grid cannot render without extension. | OPEN |
| ISSUE-4 | Planning (2026-04-19) | MED | BE | Unused `CreateFamilyMemberRequestDto` / `CreateFamilyMemberResponseDto` in `FamilySchemas.cs` — PSS 1.0 carry-over. DELETE in this pass. | OPEN |
| ISSUE-5 | Planning (2026-04-19) | MED | BE | No member-management commands. Proposed single batch `SetFamilyMembers` (diff+apply+single-head invariant). | OPEN |
| ISSUE-6 | Planning (2026-04-19) | MED | FE | `FamilyPageConfig` + `data-table.tsx` currently FLOW-stub with no router / view-page / store. Needs SavedFilter-style router + view-page + store. | OPEN |
| ISSUE-7 | Planning (2026-04-19) | LOW | FE | Leave `profile` card variant stubbed (its first consumer is Contact #18 / Staff #42). Family introduces NEW `family` variant. | OPEN |
| ISSUE-8 | Planning (2026-04-19) | LOW | FE | `FAMILY_BY_ID_QUERY` returns scalar FK IDs only. FORM pre-fill will show blank FK dropdowns until extended with nested nav names + members. | OPEN |
| ISSUE-9 | Planning (2026-04-19) | LOW | FE | `FamilyDto.ts` lacks `members[]`, summary fields, etc. Extend before running TS type-check. | OPEN |
| ISSUE-10 | Planning (2026-04-19) | LOW | BE | `FamilyConfiguration.cs` contains stale comment referencing `FamilyStatueId`. Clean up. | OPEN |
| ISSUE-11 | Planning (2026-04-19) | MED | UX | Mockup does NOT show a separate DETAIL view — derived from FLOW convention. DETAIL layout (Family profile page) is inferred per SavedFilter/GlobalDonation precedent. Reviewers must validate against business intent; if rejected, fall back to "form disabled in read mode". | OPEN |
| ISSUE-12 | Planning (2026-04-19) | LOW | Data | `Contact.EngagementScore` likely null pre-#90. Widget colouring neutral-grey by default — not a bug. | OPEN |
| ISSUE-13 | Build S1 (2026-04-19) | MED | BE↔FE | Quick-filter chip args path mismatch: BE added top-level `hasHead` / `memberCountMin` / `memberCountMax` args on `families(...)`; FE index-page pushes them as `advancedFilter` rules via `FlowDataTableStore.setQuickFilter`. GQL query document declares top-level vars but `FlowDataTableStore`'s generic request builder does not populate them. Follow-up: either extend `FlowDataTableStore` to accept per-grid variable overrides, or add a thin FE wrapper query that reads `familyQuickFilterArgs(activeChip)` + passes them as top-level vars. | OPEN |
| ISSUE-14 | Build S1 (2026-04-19) | LOW | BE | `Contact.RelationId` and `Contact.EngagementScore` do NOT exist on the Contact entity in this repo (spec assumed them). `FamilyMemberDto.relationName` + `engagementScore` are projected as NULL pre-Contact #18 / #90 landing a proper relation-lookup + engagement model. | OPEN |
| ISSUE-15 | Build S1 (2026-04-19) | LOW | BE | `FAMILY_BY_ID_QUERY` selects `createdByName` / `modifiedByName` for the DETAIL Audit Trail card, but `GetFamilyById` does NOT project those fields (no by-name lookup in handler). Audit card will silently render "—" until BE projects both. | OPEN |
| ISSUE-16 | Build S1 (2026-04-19) | LOW | BE | `FamilyMembersPicker` search excludes Contacts already in another family via `operator: "null"` on `familyId`. BE query-builder must support null/not-null operators on nullable FK scalars; if it currently does not, the exclusion silently returns all Contacts. | OPEN |
| ISSUE-17 | Build S1 (2026-04-19) | LOW | BE | ISSUE-4 reversed during build: `CreateFamilyMemberRequestDto` / `CreateFamilyMemberResponseDto` are NOT unused — they drive live `ContactMutations.createFamilyMember` (PostgreSQL function flow `corg.fn_create_family_member`). DTOs retained with a code comment. Proper cleanup is a Contact #18 follow-up (retire handler + mutation together). | OPEN |
| ISSUE-18 | Build S1 (2026-04-19) | LOW | FE | `FamilyDetail` "Recent Donations" card renders a placeholder — cross-entity donation-join query not wired into the FAMILY BE contract. Follow-up: add a `familyRecentDonations(familyId, limit)` GQL field or reuse `GlobalDonations` with a `family.familyId` filter. | OPEN |
| ISSUE-4 | Planning (2026-04-19) | MED | BE | — | RESOLVED (REVERSED) — see ISSUE-17. DTOs retained because a live `createFamilyMember` mutation depends on them. |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-19 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Orchestrator skipped BA / Solution-Resolver / UX agent spawns because the planning prompt already contained deep Sections ①–⑥ analysis (SavedFilter #27 precedent). BE + FE developers spawned in parallel (both Opus — screen_type=FLOW complexity=High per model-selection table). DB seed + Build Log + Registry owned by orchestrator main session.
- **Files touched**:
  - BE:
    - `Base.Application/Schemas/ContactSchemas/FamilySchemas.cs` (modified) — added `FamilyMemberDto`, `FamilySummaryDto`, `SetFamilyMembersRequestDto`, `FamilyMemberAssignmentDto`; extended `FamilyResponseDto` with `members`, `membersCount`, `hasHead`, `headContactId`, `headDisplayName`, `totalFamilyGiving`, `addressSingleLine`, `addresseeName` alias; extended `ExportFamilyDto`.
    - `Base.Infrastructure/Data/Configurations/ContactConfigurations/FamilyConfiguration.cs` (modified) — cleaned stale `FamilyStatueId` comment (ISSUE-10).
    - `Base.Domain/Models/ContactModels/Family.cs` (unchanged — no column rename per ISSUE-1 DTO-alias resolution).
    - `Base.Application/Business/ContactBusiness/Families/Commands/CreateFamily.cs` (modified) — FamilyCode auto-gen `FAM-{NNNN}` + Addresse/AddresseeName two-way sync.
    - `…/Families/Commands/UpdateFamily.cs` (modified) — Addresse/AddresseeName two-way sync.
    - `…/Families/Commands/DeleteFamily.cs` (modified) — nullify `Contact.FamilyId` + `IsFamilyHead = false` for all active members before soft-delete (single SaveChanges).
    - `…/Families/Commands/ToggleFamily.cs` (verified unchanged).
    - `…/Families/Queries/GetFamily.cs` (modified) — Members[] / MembersCount / HasHead / HeadContactId / HeadDisplayName / AddressSingleLine / TotalFamilyGiving projections; top-level filter args `hasHead` / `memberCountMin` / `memberCountMax`; member-name search support.
    - `…/Families/Queries/GetFamilyById.cs` (modified) — same projection set + nested FK nav for FORM pre-fill.
    - `…/Families/Queries/ExportFamily.cs` (reflection-driven — no code change needed; rollup fields flow automatically).
    - `…/Families/Commands/SetFamilyMembers.cs` (created) — diff+apply batch handler with single-head invariant (`BadRequestException` on >1 head). Returns rowsAffected.
    - `…/Families/Queries/GetFamilySummary.cs` (created) — returns `FamilySummaryDto { totalFamilies, familiesWithHead, familiesWithoutHead, singleMemberFamilies, multiMemberFamilies }` scoped by CompanyId/SuperAdmin.
    - `Base.API/EndPoints/Contact/Queries/FamilyQueries.cs` (modified) — registered `familySummary`; added 3 chip-filter args on `families(...)`.
    - `Base.API/EndPoints/Contact/Mutations/FamilyMutations.cs` (modified) — registered `setFamilyMembers`. BE DTO types were already nullable-correct; mutation-nullability BUG (ISSUE-2) lives in the FE GQL document and was fixed there.
    - `Base.Application/Mappings/ContactMappings.cs` (modified) — Mapster Addresse↔AddresseeName bidirectional + `FamilyMemberDto` + summary + request no-op maps.
    - `DecoratorProperties.cs` (verified) — `Family = "FAMILY"` already present.
  - FE:
    - `src/domain/entities/contact-service/FamilyDto.ts` (modified) — new DTOs + extended response.
    - `src/infrastructure/gql-queries/contact-queries/FamilyQuery.ts` (modified) — extended `FAMILIES_QUERY` + `FAMILY_BY_ID_QUERY` + new `FAMILY_SUMMARY_QUERY`. Selects `pincode { pincodeId, code }` per spec.
    - `src/infrastructure/gql-mutations/contact-mutations/FamilyMutation.ts` (modified) — FIX BUG: optional FKs + address2/3/4 now nullable; added `SET_FAMILY_MEMBERS_MUTATION`.
    - `src/presentation/pages/crm/family/family.tsx` (modified) — switched `FamilyPageConfig` to render `FamilyRouter`.
    - `src/presentation/components/page-components/crm/family/family/index-router.tsx` (created) — `useSearchParams`-based `?mode` dispatcher.
    - `…/crm/family/family/index-page.tsx` (created) — Variant B: `FlowDataTableStoreProvider` + `ScreenHeader` + `FamilyWidgets` + `FamilyFilterChips` + `<FlowDataTableContainer showHeader={false}>`.
    - `…/crm/family/family/view-page.tsx` (created) — 3-mode dispatcher (FORM via RHF / DETAIL via `<FamilyDetail>`); handles cascade resets, save, delete, toggle, unsaved-changes dialog, `?focus=members` autofocus.
    - `…/crm/family/family/family-store.ts` (created) — Zustand: `isFormDirty`, `pendingMembers`, `focusMembers` + actions.
    - `…/crm/family/family/family-widgets.tsx` (created) — 4 summary widgets bound to `FAMILY_SUMMARY_QUERY`.
    - `…/crm/family/family/family-members-picker.tsx` (created) — roster + search-to-add with exclude-filter (`familyId` null + not-current-family).
    - `…/crm/family/family/family-filter-chips.tsx` (created) — 5 chips + `familyQuickFilterArgs(key)` helper.
    - `…/crm/family/family/family-detail.tsx` (created) — 2-col DETAIL layout: Profile / Address / Members / Recent-Donations placeholder + Stats / Head / Audit.
    - `…/crm/family/family/data-table.tsx` (modified) — retargeted as FlowDataTable card-grid host.
    - `…/crm/family/family/index.ts` (modified) — barrel exports.
    - `src/presentation/components/page-components/card-grid/types.ts` (modified) — `"family"` variant + `FamilyCardConfig` interface.
    - `src/presentation/components/page-components/card-grid/card-variant-registry.ts` (modified) — registered `family: { Card: FamilyCard, Skeleton: FamilyCardSkeleton }`.
    - `src/presentation/components/page-components/card-grid/index.ts` (modified) — barrel adds family exports.
    - `src/presentation/components/page-components/card-grid/variants/family-card.tsx` (created) — full card layout per Section ⑥ (code + members pill + head block with warning state + address + members list + giving footer + 3 action buttons).
    - `src/presentation/components/page-components/card-grid/skeletons/family-card-skeleton.tsx` (created) — shaped shimmer.
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/engagement-score-badge.tsx` (created) — reusable 24×24 circular badge (≥80 success / 40-79 warning / <40 destructive / null muted).
    - `…/data-tables/shared-cell-renderers/index.ts` (modified) — exported `EngagementScoreBadge`.
    - `…/data-tables/{advanced,basic,flow}/data-table-column-types/component-column.tsx` (3 modified) — registered `engagement-score-badge`.
    - `…/page-components/card-grid/variants/profile-card.tsx` (UNCHANGED) — stub preserved for Contact #18 / Staff #42 as planned.
  - DB: `Base/sql-scripts-dyanmic/Family-sqlscripts.sql` (created) — menu upsert + capabilities + role grants + Grid FLOW + 11 Fields + 12 GridFields + 5 sample families (FAM-0001..FAM-0005 incl. headless FAM-0004 + single-member FAM-0005). GridFormSchema = null (FLOW). No member auto-seed (clean hand-off to Contact #18).
- **Deviations from spec**:
  - ISSUE-1 resolved via DTO-alias only (`AddresseeName` alias for `Addresse`) — no column rename, no migration.
  - ISSUE-4 REVERSED — see ISSUE-17.
  - FamilyCode generation uses a client-side parse of existing `FAM-####` codes per CompanyId (provider-independent, avoids a PostgreSQL-specific sequence).
  - Giving subquery uses `GlobalDonation.DonationAmount` (actual column) not `GlobalDonation.Amount` (spec shorthand); joins through `Contact.FamilyId` navigation (no `GlobalDonation.FamilyId` column exists).
  - FE quick-filter chips pushed via `advancedFilter` rules instead of top-level GQL args — BE added the top-level args as specified, but wiring mismatch. See ISSUE-13.
  - `Contact.RelationId` / `Contact.EngagementScore` columns do not exist in the current Contact entity; `FamilyMemberDto.relationName` + `engagementScore` are null SERVICE_PLACEHOLDERs (ISSUE-14).
  - DETAIL "Recent Donations" card is a placeholder (ISSUE-18).
  - `createdByName` / `modifiedByName` not BE-projected (ISSUE-15).
- **Known issues opened**: ISSUE-13, ISSUE-14, ISSUE-15, ISSUE-16, ISSUE-17, ISSUE-18 (6 new).
- **Known issues closed**: ISSUE-4 (RESOLVED-REVERSED — now lives as ISSUE-17).
- **Next step**: User to (1) regenerate EF snapshot (`dotnet ef migrations add …` if any tooling checks require), (2) apply `Family-sqlscripts.sql` on the target tenant, (3) `dotnet build` + `pnpm dev`, (4) E2E full-flow per §⑪ acceptance criteria — card-grid renders with `family` variant, FAM-0004 shows warning state, FAM-0005 matches "Single Member" chip, create/edit/read/delete flow across 3 URL modes. Follow-up ISSUE-13 must be closed before quick-filter chips work E2E.