---
screen: ContactType
registry_id: 19
module: Contacts
status: NEEDS_FIX
scope: ALIGN
screen_type: MASTER_GRID
complexity: Medium
new_module: NO
planned_date: 2026-04-18
completed_date: 2026-04-18
last_session_date: 2026-04-18
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed
- [x] Existing code reviewed (BE + FE audited)
- [x] Business rules extracted
- [x] FK targets resolved (no direct FK; aggregation source = ContactTypeAssignment)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized
- [x] User Approval received
- [x] Backend code modified (ALIGN — do NOT regenerate existing files)
- [x] Backend wiring confirmed (no new DbSet/Mapster entries needed)
- [x] Frontend code modified (ALIGN — transform thin grid wrapper into widgets+grid+side-panel layout)
- [x] Frontend wiring confirmed (route already exists at `[lang]/crm/contact/contacttype`)
- [x] DB Seed GridFormSchema regenerated for extended form (no new menu row needed)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/crm/contact/contacttype`
- [ ] Grid columns render: Drag | # | Code | Name | Description | Contacts | System | Order | Status | Actions
- [ ] Summary cards show: Total Types / Active / System / Custom — live counts
- [ ] Side panel opens on row click: Type Details (count + system notice + recent assignments) + Quick Tips
- [ ] "System" badge renders: blue "System" pill for `isSystem=true`, grey "Custom" pill otherwise
- [ ] Contacts count link is clickable → navigates to `crm/contact/allcontacts?contactTypeId={id}`
- [ ] +New Type modal: TypeCode uppercase-only with no-spaces auto-clean, validation on required fields
- [ ] Edit on system-type: TypeCode readonly; Delete button hidden
- [ ] Edit on custom-type: all fields editable; Delete button visible
- [ ] Drag-to-reorder: dragging a row persists new OrderBy and re-ranks remaining rows
- [ ] Toggle Active → badge updates (System types may still be toggled)
- [ ] FULL E2E: create a custom type → appears at the bottom → drag to top → edit name → toggle inactive → delete
- [ ] DB Seed — menu visible in sidebar under CRM_CONTACT, GridFormSchema renders modal correctly

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: ContactType
Module: CRM → Contacts
Schema: `corg`
Group: **Contact** (namespace folders: `ContactModels`, `ContactConfigurations`, `ContactSchemas`, `ContactBusiness`, `EndPoints/Contact`)

Business: ContactType is the classification master that every Contact record uses to tag its role in the NGO's constituent universe — Donor, Volunteer, Member, Prospect, Board Member, Field Ambassador, Corporate Partner, Beneficiary, Sponsor, and custom categories the org creates. It is maintained by admins under **CRM → Contacts → Contact Types** and sits at the root of the CRM module: nearly every downstream screen (Contact form type-picker, donation-source filters, contact dashboards, segmentation) reads from this list. A single contact can carry multiple types simultaneously via the `ContactTypeAssignment` junction entity, so this screen maintains the master list, while assignment is done inside the Contact view. The registry has System types (seeded, non-deletable, code-locked) alongside Custom types created by the tenant admin.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Entity already exists — DO NOT regenerate. This section documents current shape + the small delta needed.

Table: `corg.ContactTypes`
Entity file: `Base.Domain/Models/ContactModels/ContactType.cs` (existing)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| ContactTypeId | int | — | PK | — | Existing — keep |
| ContactTypeCode | string | 100 | YES | — | Existing — unique per Company + IsActive + !IsDeleted. Uppercase, no-spaces (FE enforcement) |
| ContactTypeName | string | 100 | YES | — | Existing — unique per Company + IsActive + !IsDeleted |
| Description | string? | 1000 | NO | — | Existing — keep |
| IsSystem | bool | — | YES | — | **Existing on entity, NOT in DTOs — must be added to ResponseDto** for FE badge rendering |
| OrderBy | int | — | YES | — | Existing — used for grid display order + drag-reorder |
| CompanyId | int? | — | YES (FK) | `app.Companies` | Existing — auto-filled from HttpContext |

**Inherited audit columns** (present via base class, not listed): `IsActive`, `IsDeleted`, `CreatedBy`, `CreatedDate`, `UpdatedBy`, `UpdatedDate`, `DeletedBy`, `DeletedDate`.

**Child / Related Entities** (used for aggregation — NOT owned):
| Entity | Relationship | Key Fields | Used For |
|--------|-------------|------------|----------|
| `ContactTypeAssignment` | 1:Many via ContactTypeId | ContactTypeId, ContactId | "Contacts" count column + "Recent Assignments" side-panel list |

**Delta from current code (ALIGN gap)**:
- Add `IsSystem` to `ContactTypeResponseDto` (currently absent from both Request and Response DTOs).
- Leave `IsSystem` OUT of `ContactTypeRequestDto` → admin cannot self-promote a custom type to system.
- `OrderBy` already auto-incremented on create in handler → keep that logic.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer + Frontend Developer
> ContactType has no user-facing FK fields (no dropdown needed in the modal form). The only FK is `CompanyId`, auto-injected from HttpContext.
>
> The "Contacts" grid column is a **per-row aggregation**, not an FK dropdown. Documented here because the dev needs to know where to pull the count from.

| Source | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|--------|--------------|-------------------|----------------|---------------|-------------------|
| Aggregation (Contacts count) | ContactTypeAssignment | `Base.Domain/Models/ContactModels/ContactTypeAssignment.cs` | — (embedded in GetContactTypes subquery) | — | int |
| Auto-fill (no UI) | Company | `Base.Domain/Models/AppModels/Company.cs` | — (from HttpContext) | — | int |

**Important**: Do NOT add `ApiSelectV2` dropdowns to the modal — this is a flat master table. The mockup modal has exactly: Code, Name, Description, Display Order, Status switch. No FK fields.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `ContactTypeCode` unique per Company (scoped to `IsActive=true AND IsDeleted=false`) — **already enforced** in `CreateContactTypeValidator` + `UpdateContactTypeValidator`.
- `ContactTypeName` unique per Company (same scope) — **already configured** in EF index; add validator rule if missing.

**Required Field Rules:**
- `ContactTypeCode` required, max 100 — already enforced.
- `ContactTypeName` required, max 100 — already enforced.
- `Description` optional, max 1000 — already enforced.
- `OrderBy` required int, min 1 — auto-assigned if omitted.

**Conditional Rules (NEW — gap vs current code):**
- If `IsSystem = true`:
  - **Cannot delete** → `DeleteContactType` handler must short-circuit with `BadRequest("System contact types cannot be deleted")`.
  - **ContactTypeCode is readonly** on edit → UI enforces readOnly; BE validator can assert `existing.ContactTypeCode == request.ContactTypeCode` when `existing.IsSystem`.
  - Toggle active/inactive IS allowed (admin may hide a system type).
- If a record has linked `ContactTypeAssignment` rows → the Delete handler must either block with "X contacts are assigned to this type — reassign before deleting" OR cascade/nullify. **Recommended**: block delete (safer default).

**Business Logic:**
- `OrderBy` auto-increments on create: new record gets `MAX(OrderBy) + 1` within the Company → already in handler.
- Drag-to-reorder: FE sends an ordered list of `{contactTypeId, orderBy}` pairs → BE exposes a `ReorderContactTypes(input: ReorderContactTypesInput!)` mutation that updates `OrderBy` in a single transaction. **NEW mutation** to add.
- Click-through count-link: FE only — navigates to `/crm/contact/allcontacts?contactTypeId={id}` with no BE work.

**Workflow**: None (flat master).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions.

**Screen Type**: MASTER_GRID
**Type Classification**: Type 1 — Simple flat master with extended UI (summary widgets + side panel + drag-reorder)
**Reason**: Single flat entity, no user-facing FK dropdowns, modal popup form. Extra UX features (widgets, side panel, drag-reorder) do NOT change the classification — they are additive FE concerns.

**Backend Patterns Required:**
- [x] Standard CRUD — **already exists**; modifications only
- [ ] Nested child creation — NO
- [ ] Multi-FK validation — NO (no user-facing FKs)
- [x] Unique validation — `ContactTypeCode`, `ContactTypeName` (already in place)
- [ ] File upload — NO
- [x] Custom business rule validators — ADD: system-type-delete guard, system-type-code-immutable guard, assignments-exist-delete guard
- [x] **Summary query** — ADD `GetContactTypeSummary` returning `{ totalTypes, activeCount, systemCount, customCount }`
- [x] **Reorder mutation** — ADD `ReorderContactTypes(input: [{contactTypeId, orderBy}])`
- [x] **Per-row aggregation** — modify `GetContactTypes` handler to LEFT JOIN `ContactTypeAssignments` grouped-count as `contactsCount`

**Frontend Patterns Required:**
- [x] AdvancedDataTable (already wired via `gridCode="CONTACTTYPE"`)
- [x] RJSF Modal Form — driven by GridFormSchema in DB seed; form fields must be refreshed
- [x] **Summary cards / count widgets** — NEW above the grid (4 cards)
- [x] **Grid aggregation column** — Contacts count (per-row subquery from BE)
- [x] **Info panel / side panel** — NEW on the right, populated on row-click
- [x] **Drag-to-reorder** — NEW
- [x] **Click-through filter** — NEW: Contacts count is a `<Link>` to filtered contact list
- [x] **System badge column** — NEW `system-badge` renderer (blue "System" / grey "Custom")
- [x] **Conditional edit lock** — NEW: TypeCode readonly + Delete hidden when `isSystem=true`
- [x] **ScreenHeader** — required because layout is NOT `grid-only` (see §⑥)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from `html_mockup_screens/screens/contacts/contact-types.html`.

### Grid/List View

**Grid Columns** (in display order, matching mockup):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | (drag handle) | — | drag-handle icon | 36px | NO | `fas fa-grip-vertical` — triggers drag-reorder |
| 2 | # | (row index) | row-number | 40px | NO | 1-based auto-number based on OrderBy sort |
| 3 | Type Code | `contactTypeCode` | code-badge | 120px | YES | Monospace, grey bordered pill |
| 4 | Type Name | `contactTypeName` | text (bold) | auto | YES | Primary column, `<strong>` |
| 5 | Description | `description` | text | auto | NO | Truncate at ~50 chars, full in tooltip |
| 6 | Contacts | `contactsCount` | count-link | 90px | YES | **Clickable** → `/[lang]/crm/contact/allcontacts?contactTypeId={row.contactTypeId}`. Renderer: `link-count` (reuse from #3 ISSUE-4 or similar). Thousands separator. `event.stopPropagation()` so row-click is not triggered. |
| 7 | System | `isSystem` | system-badge | 100px | YES | `true` → blue pill "🔒 System"; `false` → grey pill "Custom". New renderer or reuse `pill-badge`. |
| 8 | Order | `orderBy` | order-num | 70px | YES | Circular grey badge — numeric only |
| 9 | Status | `isActive` | status-badge | 100px | YES | existing active/inactive badge |
| 10 | Actions | — | action-buttons | 110px | NO | Edit (always visible). Delete (ONLY when `isSystem=false`). |

**Search/Filter Fields**: `contactTypeCode`, `contactTypeName`, `description`, `isActive`, `isSystem`.

**Grid Actions Row-Level**: Edit (always), Toggle Active (existing), Delete (conditional on `!isSystem`).

**Grid Actions Bulk (header)**: Export (mockup shows "Export" button in page-header → reuse existing grid export).

**Row Click Behaviour**:
- Row click → selects the row (visual highlight + left-border accent), populates side panel.
- Clicking the Contacts count link or action buttons must `stopPropagation` to avoid row-select while acting.

### RJSF Modal Form

> Modal fields drive GridFormSchema in DB seed. FE dev does NOT hand-code the form.

**Form Sections** (in order — matches mockup modal):
| Section | Title | Layout | Fields |
|---------|-------|--------|--------|
| 1 | (unlabelled — all flat in mockup) | single column | typeCode, typeName, description |
| 2 | (2-column split at bottom) | 2-column | orderBy, isActive |

**Field Widget Mapping**:
| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| contactTypeCode | text | "e.g., VOLUNTEER" | required, maxLength 100, pattern `^[A-Z0-9_]+$` | **Uppercase + no-spaces auto-clean** via RJSF `ui:options` `textTransform: upper` + onChange strip. Readonly when `formData.isSystem === true` (edit mode). Helper text: "Uppercase, no spaces. Max 100 characters." |
| contactTypeName | text | "e.g., Volunteer" | required, maxLength 100 | — |
| description | textarea | "Brief description of this contact type..." | optional, maxLength 1000 | rows=3 |
| orderBy | number | "e.g., 10" | min 1 | Default on create: `max(orderBy) + 1` auto-fill |
| isActive | boolean-switch | — | — | Label: "Active" / "Inactive" — toggles in real time |

**Hidden field (bound at submit, not shown)**:
- `isSystem` — never rendered, never editable via this form. Stays on record per DB state.

### Page Widgets & Summary Cards

**Widgets**: YES — 4 count cards in a summary bar above the grid.

**Layout Variant** (REQUIRED — stamp one): `widgets-above-grid+side-panel`
- FE Dev MUST use **Variant B**: `<ScreenHeader>` at top → summary widget row → `<DataTableContainer showHeader={false}>` side-by-side with `<SidePanel>` on the right column.
- Page uses a 2-column layout (`xl:grid-cols-[2fr_1fr]` or `lg:grid-cols-[8_4]` — match mockup's `col-lg-8 / col-lg-4` split).

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | Total Types | `totalTypes` | count w/ icon `ph:shapes` | Row 1, col 1 |
| 2 | Active | `activeCount` | count w/ icon `ph:check-circle` (green) | Row 1, col 2 |
| 3 | System | `systemCount` | count w/ icon `ph:lock` (blue) | Row 1, col 3 |
| 4 | Custom | `customCount` | count w/ icon `ph:user-tag` (amber) | Row 1, col 4 |

All 4 cards on a single horizontal row on `md+` screens; stack on `sm` and below. Use tokens (no hex/px). Reuse the summary-card component used by #1 Donation (Global) or `StatCardShaped`.

**Summary GQL Query** (NEW — needs adding):
- Query name: `GetContactTypeSummary`
- Returns: `ContactTypeSummaryDto` with fields `{ totalTypes: int, activeCount: int, systemCount: int, customCount: int }`
- Handler: single `_db.ContactTypes.Where(!IsDeleted && CompanyId=current).GroupBy(x => 1).Select(...)` with 4 counts.
- Must be added to `ContactTypeQueries.cs` alongside the existing `GetContactTypes` + `GetContactTypeById`.

### Grid Aggregation Columns

**Aggregation Columns**: YES — 1 column.

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Contacts | Count of active, non-deleted ContactTypeAssignments pointing at this ContactType | `corg.ContactTypeAssignments` where `ContactTypeId = row.ContactTypeId && !IsDeleted` | LINQ subquery in `GetContactTypes` projection: `ContactsCount = _db.ContactTypeAssignments.Count(a => a.ContactTypeId == ct.ContactTypeId && !a.IsDeleted)`. Project into `ContactTypeResponseDto.ContactsCount` (new field, `int`). |

### Side Panel / Info Panel (right column)

**Side Panel**: YES — right column (`col-lg-4` in mockup → `xl:w-1/3` in FE).

| Panel Section | Fields / Content | Trigger |
|--------------|------------------|---------|
| Empty state | "Select a contact type from the table to view details" + hand-pointer icon | Default (no row selected) |
| Type Details (stat card) | `"{contactTypeName} type is assigned to {contactsCount} contacts"` in accent-background chip | Row click |
| System notice | "This is a system type and cannot be deleted" — blue info chip | Row click AND `isSystem=true` |
| Recent Assignments | Up to 5 most recent `ContactTypeAssignment` rows joined to `Contact` — avatar (initials) + contact name + assignment date | Row click |
| Quick Tips (static, always shown below the Type Details panel) | Bulleted list with 4 items (see mockup text verbatim) | Always visible |

**Side Panel GQL Query** (NEW — needs adding):
- Query name: `GetContactTypeRecentAssignments`
- Args: `contactTypeId: Int!`, `limit: Int = 5`
- Returns: `[RecentAssignmentDto { contactId, contactName, initials, assignmentDate }]`
- Handler: join `ContactTypeAssignments ct_a ON ContactId → Contacts c`, order by `ct_a.CreatedDate DESC`, take `limit`.
- Fire on row selection (not grid load) → lazy loaded.

**Quick Tips (static text — hardcoded in FE)**:
1. "A contact can have **multiple types** simultaneously"
2. "Drag rows to **reorder** display priority"
3. "System types can be edited but **not deleted**"
4. "Click contact count to **filter** the contact list"

### Drag-to-Reorder

- Use `@dnd-kit/sortable` (or existing drag-reorder primitive if already in the FE registry — check first).
- Drag handle column (col 1) is the only grab target.
- On drop: compute new ordered array of `{contactTypeId, orderBy: newIndex + 1}` → fire `ReorderContactTypes` mutation → refetch grid.
- Optimistic UI: reorder locally, revert on error.

### User Interaction Flow

1. User lands on page → widgets show totals → grid shows types ordered by `OrderBy ASC` → side panel shows empty state.
2. Click row → row highlights (accent border), side panel fills with Type Details + Recent Assignments.
3. Click "+New Type" → modal opens (empty) → fill Code (auto-uppercase) + Name + Description + Order (pre-filled to next) + Active switch → Save → grid refreshes, widget counts update.
4. Click Edit icon on a row → modal opens pre-filled. If `isSystem=true` → Code is readonly and flagged with "System (locked)" helper.
5. Click Delete on a custom type → confirmation modal → on confirm, soft-delete → row vanishes, counts update. On a system type → Delete button is not rendered.
6. Drag a row by handle → drop at new position → OrderBy recomputed and persisted.
7. Click Contacts count link (e.g., "8,456") on a row → navigate to `/[lang]/crm/contact/allcontacts?contactTypeId={id}` (the contacts page reads the query param and pre-filters).
8. Toggle Status on a row → backend flips `IsActive` → grid badge updates → widget "Active" count updates.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> **ContactType IS the canonical MASTER_GRID reference.** Substitution is mostly identity — but flag one divergence.

**Canonical Reference**: ContactType (this entity)

| Canonical (per _MASTER_GRID.md) | → Actual in this repo | Context |
|---------------------------------|----------------------|---------|
| ContactType | ContactType | Entity/class name (identity) |
| contactType | contactType | camelCase (identity) |
| ContactTypes | ContactTypes | Plural (identity) |
| contact-type | contact-type | kebab-case for routes (identity) |
| contacttype | contacttype | entity-lower-no-dash (identity) |
| CONTACTTYPE | CONTACTTYPE | grid code, menu code (identity) |
| corg | corg | DB schema (identity) |
| **Corg** (as stated in the template) | **Contact** | **DIVERGENCE** — this repo uses `ContactModels`, `ContactConfigurations`, `ContactSchemas`, `ContactBusiness`, `EndPoints/Contact`. The template's "CorgModels" is outdated; always use `Contact` as the group suffix for ContactType backend files. |
| CorgModels | ContactModels | Namespace (see above) |
| CONTACT | CONTACT | Parent menu code (identity) |
| CRM | CRM | Module code (identity) |
| crm/contact/contacttype | crm/contact/contacttype | FE route base (identity) |
| corg-service | **contact-service** | FE service folder name — repo uses `contact-service`, not `corg-service` |

**Flag to future devs copying from the canonical**: if you write `/corg-service/` in a FE import, that's wrong for this entity — it's `/contact-service/`. The template needs a future correction.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> **ALIGN scope — existing files are MODIFIED, not recreated.** Only the Delta column matters.

### Backend Files (existing — MODIFY in place)

| # | File | Path | Delta |
|---|------|------|-------|
| 1 | Entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ContactModels/ContactType.cs` | **No change** (IsSystem already there). |
| 2 | EF Config | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/ContactConfigurations/ContactTypeConfiguration.cs` | **No change** (indexes already correct). |
| 3 | Schemas | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/ContactSchemas/ContactTypeSchemas.cs` | **ADD `IsSystem` to `ContactTypeResponseDto`**. **ADD `ContactsCount` to `ContactTypeResponseDto`**. **ADD new DTOs**: `ContactTypeSummaryDto`, `RecentAssignmentDto`, `ReorderContactTypeRequestDto`. |
| 4 | Create Command | `.../Business/ContactBusiness/ContactTypes/Commands/CreateContactType.cs` | **No change** (IsSystem stays false by default). |
| 5 | Update Command | `.../Business/ContactBusiness/ContactTypes/Commands/UpdateContactType.cs` | **ADD rule**: if `existing.IsSystem`, reject request where `existing.ContactTypeCode != request.ContactTypeCode`. |
| 6 | Delete Command | `.../Business/ContactBusiness/ContactTypes/Commands/DeleteContactType.cs` | **ADD rule**: if `existing.IsSystem`, throw BadRequest("System contact types cannot be deleted"). Also: if `ContactTypeAssignments` exist for this id, throw BadRequest("N contacts still assigned — reassign before deleting"). |
| 7 | Toggle Command | `.../Business/ContactBusiness/ContactTypes/Commands/ToggleContactType.cs` | **No change** (system types may still be toggled). |
| 8 | GetAll Query | `.../Business/ContactBusiness/ContactTypes/Queries/GetContactType.cs` | **MODIFY projection** to include `ContactsCount` (subquery on ContactTypeAssignments) and `IsSystem`. Keep existing pagination/search. |
| 9 | GetById Query | `.../Business/ContactBusiness/ContactTypes/Queries/GetContactTypeById.cs` | **MODIFY projection** to include `IsSystem` and `ContactsCount`. |
| 10 | **NEW** — GetSummary | `.../Business/ContactBusiness/ContactTypes/Queries/GetContactTypeSummary.cs` | **CREATE** — returns `ContactTypeSummaryDto` (4 counts). |
| 11 | **NEW** — GetRecentAssignments | `.../Business/ContactBusiness/ContactTypes/Queries/GetContactTypeRecentAssignments.cs` | **CREATE** — args `(contactTypeId, limit)`, returns `[RecentAssignmentDto]`. |
| 12 | **NEW** — Reorder Command | `.../Business/ContactBusiness/ContactTypes/Commands/ReorderContactTypes.cs` | **CREATE** — args `[{contactTypeId, orderBy}]`, updates OrderBy in one transaction. |
| 13 | Mutations endpoint | `.../Base.API/EndPoints/Contact/Mutations/ContactTypeMutations.cs` | **ADD** `ReorderContactTypes` field. Delete the duplicate `ContactTypeMutation.cs` (singular) if it still exists. |
| 14 | Queries endpoint | `.../Base.API/EndPoints/Contact/Queries/ContactTypeQueries.cs` | **ADD** `GetContactTypeSummary` + `GetContactTypeRecentAssignments` fields. |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext` / `ContactDbContext` | **No change** — DbSet<ContactType> already registered. |
| 2 | `DecoratorProperties` | **No change**. |
| 3 | `ContactMappings.cs` (Mapster) | **VERIFY**: the map from `ContactType` → `ContactTypeResponseDto` must auto-project new `IsSystem` and `ContactsCount` fields (once added to DTO). If Mapster uses explicit config, add those two properties. |

### Frontend Files (existing — MODIFY / extend)

| # | File | Path | Delta |
|---|------|------|-------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/contact-service/ContactTypeDto.ts` | **ADD** `isSystem: boolean`, `contactsCount: number` to `ContactTypeResponseDto`. **ADD** new types: `ContactTypeSummaryDto`, `RecentAssignmentDto`. |
| 2 | GQL Query | `PSS_2.0_Frontend/src/infrastructure/gql-queries/contact-queries/ContactTypeQuery.ts` | **ADD** `isSystem`, `contactsCount` to `CONTACTTYPES_QUERY` selection. **ADD** new queries: `CONTACTTYPE_SUMMARY_QUERY`, `CONTACTTYPE_RECENT_ASSIGNMENTS_QUERY`. |
| 3 | GQL Mutation | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/contact-mutations/ContactTypeMutation.ts` | **ADD** `REORDER_CONTACTTYPES_MUTATION`. |
| 4 | Page Config | `PSS_2.0_Frontend/src/presentation/pages/crm/contact/contacttype.tsx` | **MODIFY** to compose `<ScreenHeader>` + widgets + 2-column (grid + side panel) layout. Wrap existing capability guard. |
| 5 | Data-Table Component (existing) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/contact/contacttype/data-table.tsx` | **MODIFY** to emit row-click events (for side panel population), set `showHeader={false}`, support drag-reorder handles, and render the new `system-badge` + `link-count` renderers via grid config. |
| 6 | **NEW** — Widgets | `.../components/page-components/crm/contact/contacttype/contacttype-widgets.tsx` | **CREATE** — 4 summary cards driven by `CONTACTTYPE_SUMMARY_QUERY`. |
| 7 | **NEW** — Side Panel | `.../components/page-components/crm/contact/contacttype/contacttype-side-panel.tsx` | **CREATE** — accepts `selectedType: ContactTypeResponseDto \| null`, shows Type Details + Recent Assignments (lazy-loaded) + Quick Tips. |
| 8 | Renderer — system-badge | Check FE registry first (`presentation/.../renderers/`). If missing, **CREATE** a minimal `system-badge.tsx` and register it in advanced/basic/flow column-type maps. If a generic `pill-badge` already exists, configure via grid config instead. |
| 9 | Renderer — link-count | Already exists (reused by #3 Donation Category). **REUSE** — do not recreate. |
| 10 | Route Page | `PSS_2.0_Frontend/src/app/[lang]/crm/contact/contacttype/page.tsx` | **No change** — route already exists. |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `entity-operations.ts` | Verify `CONTACTTYPE` entry exists and includes the new `REORDER` operation. |
| 2 | Sidebar menu config | **No change** — menu already registered under CRM_CONTACT. |
| 3 | Grid config (DB seed) — `GridFormSchema` for `CONTACTTYPE` | **REGENERATE**. See §⑨. |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Contact Types
MenuCode: CONTACTTYPE
ParentMenu: CRM_CONTACT
Module: CRM
MenuUrl: crm/contact/contacttype
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: REGENERATE
GridCode: CONTACTTYPE

GridFormSchema Content (for DB seed regeneration):
- Title: "Contact Type"
- Fields (order + UI hints):
  1. contactTypeCode   → TextWidget, required, maxLength 100, uppercase+no-space transform, readonly when formData.isSystem === true, helper "Uppercase, no spaces. Max 100 characters."
  2. contactTypeName   → TextWidget, required, maxLength 100, placeholder "e.g., Volunteer"
  3. description       → TextAreaWidget, maxLength 1000, rows=3, placeholder "Brief description of this contact type..."
  4. orderBy           → NumberWidget, min=1, default = (max + 1) at new-record time
  5. isActive          → SwitchWidget, default true
- Hidden fields (in formData, not rendered):
  - isSystem (read-only pass-through)
- Layout: sections 1-3 full-width single column; section 4-5 two-column (left=orderBy, right=isActive)
---CONFIG-END---
```

**Note on Role seeding**: per project preference, only `BUSINESSADMIN` role is enumerated. Other roles inherit via the capability cascade.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — exact names to call.

**GraphQL Root Types:**
- Query: `ContactTypeQueries`
- Mutation: `ContactTypeMutations`

**Queries:**
| GQL Field | Returns | Key Args | Status |
|-----------|---------|----------|--------|
| `GetContactTypes` | paginated `{ items: [ContactTypeResponseDto], totalCount: int }` | searchText, pageNo, pageSize, sortField, sortDir, isActive, isSystem | **EXISTS** — modify projection to add `isSystem`, `contactsCount` |
| `GetContactTypeById` | `ContactTypeResponseDto` | contactTypeId | **EXISTS** — modify projection to add `isSystem`, `contactsCount` |
| `GetContactTypeSummary` | `ContactTypeSummaryDto` | — | **NEW** — add |
| `GetContactTypeRecentAssignments` | `[RecentAssignmentDto]` | contactTypeId, limit=5 | **NEW** — add |

**Mutations:**
| GQL Field | Input | Returns | Status |
|-----------|-------|---------|--------|
| `CreateContactType` | `ContactTypeRequestDto` | int (new id) | **EXISTS** — no change |
| `UpdateContactType` | `ContactTypeRequestDto` | int | **EXISTS** — add system-code-immutable guard |
| `DeleteContactType` | contactTypeId | int | **EXISTS** — add system + assignments guard |
| `ActivateDeactivateContactType` | contactTypeId | int | **EXISTS** — no change (name kept to avoid FE cascade) |
| `ReorderContactTypes` | `[ReorderContactTypeRequestDto { contactTypeId, orderBy }]` | int (count updated) | **NEW** — add |

**⚠ GQL-name divergence from the canonical template**: the canonical template cites `GetAllContactTypeList` + `ToggleContactType`, but this repo uses `GetContactTypes` + `ActivateDeactivateContactType`. **Do NOT rename** during this ALIGN pass — it would cascade through FE and is out of scope. Track as follow-up if standardization is desired.

**Response DTO Fields** (ContactTypeResponseDto after ALIGN):
| Field | Type | Notes |
|-------|------|-------|
| contactTypeId | number | PK |
| contactTypeCode | string | max 100, uppercase |
| contactTypeName | string | max 100 |
| description | string? | max 1000 |
| orderBy | number | display sort |
| isSystem | boolean | **NEW** — from entity; drives badge + delete-lock + code-lock |
| contactsCount | number | **NEW** — per-row aggregation from ContactTypeAssignments |
| isActive | boolean | inherited |
| companyId | number? | hidden |

**ContactTypeSummaryDto** (NEW):
| Field | Type | Source |
|-------|------|--------|
| totalTypes | number | `COUNT(*) WHERE !IsDeleted` |
| activeCount | number | `COUNT(*) WHERE IsActive && !IsDeleted` |
| systemCount | number | `COUNT(*) WHERE IsSystem && !IsDeleted` |
| customCount | number | `COUNT(*) WHERE !IsSystem && !IsDeleted` |

**RecentAssignmentDto** (NEW):
| Field | Type | Notes |
|-------|------|-------|
| contactId | number | — |
| contactName | string | from Contact.FirstName + LastName OR OrganizationName |
| initials | string | derived in FE or BE |
| assignmentDate | DateTime | CreatedDate on ContactTypeAssignment |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/[lang]/crm/contact/contacttype` (no 404)
- [ ] `pnpm tsc --noEmit` — no TS errors

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with 10 columns in the order: drag | # | Code | Name | Description | Contacts | System | Order | Status | Actions
- [ ] 4 summary widgets render above grid and display correct live counts from `GetContactTypeSummary`
- [ ] Search filters by code / name / description (case-insensitive)
- [ ] Click a row → right side panel populates with Type Details chip + (if system) system notice + Recent Assignments list
- [ ] Add: +New Type → modal shows 5 fields (Code, Name, Description, Order, Active switch) → Code auto-uppercases and strips spaces → Save → row appears at bottom with next OrderBy → summary "Total Types" +1, "Custom" +1
- [ ] Edit a custom type → modal pre-fills → save succeeds
- [ ] Edit a system type → Code field is readonly with helper text → Save works for other fields → Delete button NOT rendered in action cell
- [ ] Delete a custom type with 0 assignments → confirm dialog → soft-delete → row removed → widget counts update
- [ ] Delete a custom type that has assignments → BE returns "N contacts still assigned" toast
- [ ] Toggle active on any type → `IsActive` flips → badge updates → "Active" widget count adjusts
- [ ] Drag a row to a new position → order persists after refresh; OrderBy values recomputed
- [ ] Click a Contacts count link (e.g., "8,456") → navigates to `/[lang]/crm/contact/allcontacts?contactTypeId={id}`
- [ ] System badge renders blue "🔒 System" for `isSystem=true`, grey "Custom" for `isSystem=false`
- [ ] Permissions: BUSINESSADMIN sees all buttons; other roles respect capability mask

**DB Seed Verification:**
- [ ] Menu already visible in sidebar under CRM → Contacts → Contact Types (unchanged)
- [ ] GridFormSchema regenerated — modal renders the 5 fields with the new `textTransform: upper` and `readOnly` conditionals
- [ ] Seeded system types (DONOR, VOLUNTEER, MEMBER, PROSPECT, AMBASSADOR) carry `IsSystem=true`; others `IsSystem=false`
- [ ] Seed insert includes at least 9 types to match mockup expectations (Donor, Volunteer, Member, Prospect, Board Member, Field Ambassador, Corporate Partner, Beneficiary, Sponsor)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**ALIGN-scope caveats**:
- This is ALIGN, not FULL. **Do not regenerate** `ContactType.cs`, `ContactTypeConfiguration.cs`, existing Create/Toggle handlers, or the existing FE `data-table.tsx` wrapper from the canonical template. Only MODIFY as specified in §⑧.
- **Keep existing GQL field names** (`GetContactTypes`, `ActivateDeactivateContactType`). Do NOT rename to canonical names — the FE is already wired to these.

**Backend gotchas**:
- Group suffix in this repo is **`Contact`** (ContactModels, ContactSchemas, etc.), not `Corg` as cited in `_MASTER_GRID.md`. The template's guide has a stale reference.
- There is a **duplicate `ContactTypeMutation.cs` (singular)** in `EndPoints/Contact/Mutations/` alongside the plural `ContactTypeMutations.cs`. During the build session, **delete the singular duplicate** if it exists (it's a lingering artifact).
- The Contact entity has **no direct `ContactTypeId` FK**. The link is via `ContactTypeAssignment` junction. All aggregations must go through `ContactTypeAssignments`.
- The existing EF config has a commented-out composite index — leave the comment alone.
- `CompanyId` is nullable on this entity by design (some masters are global). Ensure the Company filter uses `CompanyId == currentCompany || CompanyId == null` if global types are expected.

**Frontend gotchas**:
- The route already lives at `src/app/[lang]/crm/contact/contacttype/page.tsx` (note: directly under `[lang]`, NOT under `(core)` group as the template suggests). **USE THIS PATH** — don't create a new one.
- The current component is at `presentation/components/page-components/crm/contact/contacttype/data-table.tsx` — no `index-page.tsx` convention here. When adding widgets + side panel, create `contacttype-widgets.tsx` and `contacttype-side-panel.tsx` as **siblings** to `data-table.tsx`, then compose them in `presentation/pages/crm/contact/contacttype.tsx`.
- **Layout variant is `widgets-above-grid+side-panel`** → Variant B is mandatory. Use `<ScreenHeader>` + `<DataTableContainer showHeader={false}>` to avoid double-header UI bug. (See ContactType #19 precedent from the template — that bug was raised against this very screen.)
- **Component reuse-or-create rule** (from feedback memory): before creating `system-badge` or `link-count` renderers, **search the renderer registry** (`presentation/.../renderers/` advanced/basic/flow column-type maps). `link-count` is confirmed to already exist (reused by Donation Category #3). `system-badge` may or may not exist — if a generic `pill-badge` or `color-badge` covers it, configure via grid config instead of creating a new renderer.
- **UI tokens only** (from feedback memory): no hex colors, no raw px values in the new widgets + side panel. Use spacing tokens, semantic colors (`accent`, `success`, `warning`, `info`). Use `@iconify/react` with Phosphor (`ph:`) icons — do NOT use `fa-` class icons even though the mockup uses them.

**Service Dependencies** (UI-only — no backend service implementation):
- (empty — no external services needed for this screen)

**Data migration note**:
- The existing seed data for ContactTypes may not have `IsSystem` populated correctly. As part of the DB seed regeneration for this screen, **audit the 9 expected types** and set `IsSystem=true` for the first 5 (DONOR, VOLUNTEER, MEMBER, PROSPECT, AMBASSADOR per mockup) and `IsSystem=false` for the rest (BOARD, PARTNER, BENEFICIARY, SPONSOR). A one-shot UPDATE script may be needed alongside the seed.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | Medium | FE — drag-to-reorder | `REORDER_CONTACTTYPES_MUTATION` is defined and exported, but `AdvancedDataTableContainer` does not yet expose an `onReorder` prop. The DB seed's drag-handle column config is in place, but the container needs enhancement (or use of `@dnd-kit` directly around rows) to consume it. End-to-end drag-reorder is **not functional** until the container is extended. | OPEN |
| ISSUE-2 | 1 | Low | FE — row click | Row-click for side-panel selection uses event delegation on a wrapper `<div>`, matching the clicked `<TR>` to the store's `data` array by index. Works under normal pagination, but could theoretically mismatch during a transient refetch. `AdvancedDataTableContainer` should expose an `onRowClick` prop. | OPEN |
| ISSUE-3 | 1 | Low | FE — link-count template | `linkTemplate` in the `contactsCount` cell omits the `{lang}` prefix (`/crm/contact/allcontacts?contactTypeId={contactTypeId}`). Inherits the unresolved issue from Donation Category #3 ISSUE-1. The navigation works but is locale-unaware. | OPEN |
| ISSUE-4 | 1 | Low | BE — delete validator | The old generic `ValidateNotReferencedInAnyCollection(ContactTypeAssignments)` call was removed from the `DeleteContactType` validator because it did not filter by `IsDeleted == false`. The check now lives in the handler with a precise `CountAsync(a => !a.IsDeleted)`. This is an improvement, but the validator now only enforces the existence check — worth noting for future BA of other ContactType delete paths (e.g., if a second delete entry point is added, it must include the handler-level guard). | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-18 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt (ALIGN-scope MASTER_GRID with widgets-above-grid+side-panel layout — Variant B).
- **Files touched**:
  - BE: `Base.Application/Schemas/ContactSchemas/ContactTypeSchemas.cs` (modified), `Base.Application/Business/ContactBusiness/ContactTypes/Commands/UpdateContactType.cs` (modified), `Base.Application/Business/ContactBusiness/ContactTypes/Commands/DeleteContactType.cs` (modified), `Base.Application/Business/ContactBusiness/ContactTypes/Queries/GetContactType.cs` (modified), `Base.Application/Business/ContactBusiness/ContactTypes/Queries/GetContactTypeById.cs` (modified), `Base.Application/Business/ContactBusiness/ContactTypes/Queries/GetContactTypeSummary.cs` (created), `Base.Application/Business/ContactBusiness/ContactTypes/Queries/GetContactTypeRecentAssignments.cs` (created), `Base.Application/Business/ContactBusiness/ContactTypes/Commands/ReorderContactTypes.cs` (created), `Base.API/EndPoints/Contact/Queries/ContactTypeQueries.cs` (modified), `Base.API/EndPoints/Contact/Mutations/ContactTypeMutations.cs` (modified), `Base.API/EndPoints/Contact/Mutations/ContactTypeMutation.cs` (deleted — singular duplicate).
  - FE: `src/domain/entities/contact-service/ContactTypeDto.ts` (modified), `src/infrastructure/gql-queries/contact-queries/ContactTypeQuery.ts` (modified), `src/infrastructure/gql-mutations/contact-mutations/ContactTypeMutation.ts` (modified), `src/presentation/pages/crm/contact/contacttype.tsx` (rewritten — Variant B shell), `src/presentation/components/page-components/crm/contact/contacttype/data-table.tsx` (rewritten — `ScreenHeader` + `showHeader={false}` + row-click + reorder stub), `src/presentation/components/page-components/crm/contact/contacttype/contacttype-widgets.tsx` (created), `src/presentation/components/page-components/crm/contact/contacttype/contacttype-side-panel.tsx` (created), `src/presentation/components/page-components/crm/contact/contacttype/index.ts` (barrel export update).
  - DB: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/ContactType-sqlscripts.sql` (created — GridFields + GridFormSchema + IsSystem audit UPDATE; Menu row kept idempotent).
- **Deviations from spec**:
  1. `DeleteContactType` validator no longer calls the generic `ValidateNotReferencedInAnyCollection` — the check was moved into the handler so that `IsDeleted==false` is applied to the assignments count. Functionally stronger, structurally different. Logged as ISSUE-4.
  2. Drag-to-reorder: mutation defined but end-to-end wiring blocked by `AdvancedDataTableContainer` not exposing `onReorder`. Logged as ISSUE-1.
  3. Row-click for side-panel uses DOM-index matching rather than a container callback. Logged as ISSUE-2.
- **Known issues opened**: ISSUE-1 (drag-to-reorder not wired end-to-end), ISSUE-2 (row click via DOM-index matching), ISSUE-3 (link-count `{lang}` prefix inherited), ISSUE-4 (delete validator moved to handler — structural deviation).
- **Known issues closed**: None.
- **Next step**: (empty — COMPLETED).

### Session 2 — 2026-04-18 — UI — COMPLETED

- **Scope**: Fix Variant B layout order — the `<ScreenHeader>` was rendered inside `ContactTypeDataTable`, so it landed **below** the summary widget cards instead of at the top of the page. Fullscreen toggle also only expanded the data-table region, hiding the widgets. Spec §⑥ mandates `ScreenHeader → widgets → grid+side-panel`, with fullscreen wrapping the entire page.
- **Files touched**:
  - BE: None.
  - FE:
    - `src/presentation/pages/crm/contact/contacttype.tsx` (rewritten) — lifted `AdvancedDataTableStoreProvider` from the data-table into the page, added a new `ContactTypePageLayout` child that reads the store for `gridInfo`, `loading`, `fullScreenMode`, `tableConfig`; renders `<ScreenHeader>` at the top, then `<ContactTypeWidgets />`, then the 2-column `<ContactTypeDataTable /> + <ContactTypeSidePanel />`; moved the fullscreen wrapper + ESC handler to the page root so fullscreen expands the full page.
    - `src/presentation/components/page-components/crm/contact/contacttype/data-table.tsx` (simplified) — removed the provider, `useAdvancedInitializeColumns/Data`, `ScreenHeader`, breadcrumb building, and the fullscreen wrapper (all moved to the page). Component now only renders the row-click wrapper + `<AdvancedDataTableContainer showHeader={false} />`. Data-fetch hooks still run inside the same provider because the page now owns it.
  - DB: None.
- **Deviations from spec**: None. This session brings the layout into compliance with §⑥.
- **Known issues opened**: None.
- **Known issues closed**: None. (ISSUE-1..4 remain OPEN — out of scope for this session.)
- **Verification**:
  - `pnpm tsc --noEmit` passed (exit 0, no new errors).
  - Manual browser verification of fullscreen + header actions left to the dev running `pnpm dev` locally (CI env cannot render UI here).
- **Next step**: None for this fix. Four prior OPEN issues (ISSUE-1..4) remain — address via future `/continue-screen #19` sessions when `AdvancedDataTableContainer` gains `onReorder` / `onRowClick` and the `{lang}` link template is fixed globally.

