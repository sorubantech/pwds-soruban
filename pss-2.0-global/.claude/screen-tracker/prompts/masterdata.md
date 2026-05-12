---
screen: MasterData
registry_id: 76
combines_registry_ids: [76, 162]
module: Settings
status: PROMPT_READY
scope: ALIGN
screen_type: MASTER_GRID
complexity: High
new_module: NO
planned_date: 2026-05-10
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (`html_mockup_screens/screens/settings/master-data.html`)
- [x] Existing code reviewed (BE entities + DTOs + Queries + Mutations + 4 FE components inspected)
- [x] Business rules extracted
- [x] FK targets resolved (MasterDataType FK from MasterData)
- [x] File manifest computed (BE: 10 modify + 3 new + 1 migration + 1 seed; FE: 4 delete + 8 modify + 7 new)
- [x] Approval config pre-filled (single combined menu, two source menus must redirect)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized
- [ ] User Approval received
- [ ] Backend code modified (ALIGN — modify in place, do NOT regenerate the entity)
- [ ] Backend wiring confirmed (DbSet already in `SettingDbContext`; only mappings + endpoint fields added)
- [ ] Frontend code consolidated (delete 4 duplicate page/data-table files; create combined split-panel page)
- [ ] Frontend wiring confirmed (existing routes redirect to combined page)
- [ ] DB Seed script generated (GridFormSchema for two distinct forms: Type form + Value form)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/setting/dataconfig/masterdata`
- [ ] `setting/dataconfig/masterdatatype` redirects to `setting/dataconfig/masterdata`
- [ ] Left panel: type list renders with name + value count + System/Custom badge
- [ ] Search box filters left panel by type name (client-side)
- [ ] Click left-panel row → right panel populates with that type's values + header (TypeName + TypeCode + System badge)
- [ ] +New Data Type → modal opens → Type Name, Code (UPPER + underscore), Description, Allow Multiple Selection, Allow User Input → Save → appears in left list, becomes selected
- [ ] Edit Type (right-panel header) → modal pre-fills → Code is readonly when `isSystem=true`
- [ ] Delete Type (only when `isSystem=false`) → confirm → soft-delete → left list updates → right panel returns to empty state
- [ ] +Add Value (right-panel header) → modal: Code, Display Value, Abbreviation, Description, Active switch, Sort Order, Translations panel (Hindi+Arabic) → Save → row appears at next SortOrder
- [ ] Edit Value (row pen icon OR row dropdown) → modal pre-fills → Save persists
- [ ] Toggle Value (row dropdown Activate/Deactivate) → IsActive flips → row dims + status badge changes
- [ ] Move Up / Move Down (row dropdown) → SortOrder swaps with adjacent row → grid re-renders
- [ ] Drag-handle reorder → SortOrder persists across multi-row reorder
- [ ] Delete Value (row dropdown) → confirm → soft-delete → row vanishes → left-panel value count decrements
- [ ] DB Seed — single MASTERDATA menu visible under SET_DATACONFIG; MASTERDATATYPE menu HIDDEN (IsLeastMenu=false) but still seeded for capability cascade
- [ ] At least 12 system types seeded (Salutation, Contact Type, Payment Mode, Donation Category, Communication Channel, Event Type, Document Category, Relationship Type) + 4 custom types per mockup
- [ ] System types cannot be deleted; custom types fully editable

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **Master Data** (combines `MasterData` + `MasterDataType`)
Module: **Setting → Data Config**
Schema: `sett`
Group: **Setting** (namespace folders: `SettingModels`, `SettingConfigurations`, `SettingSchemas`, `SettingBusiness`, `EndPoints/Setting`)

Business: Master Data is the centralized lookup-value hub powering every dropdown, badge, classification, and reference list across the PSS 2.0 platform. It manages two layered concepts: **Master Data Types** (the categories — e.g., Salutation, Payment Mode, Donation Category) and **Master Data Values** (the rows under each category — e.g., Mr./Mrs./Dr. under Salutation). Maintained by tenant admins under **Settings → Data Config**, the screen replaces what was historically two disjoint pages (`masterdata` and `masterdatatype`) with a single split-panel UI: left = list of types with value-counts, right = grid of values for the currently selected type. System-seeded types and values cannot be deleted (only deactivated) but custom org-specific entries are fully editable. Many other screens — Contact form, Donation form, Volunteer Skills, Communication channels — read from this registry, so changes here ripple platform-wide.

**Why it's combined (#76 + #162)**: The platform sidebar registers two menu codes (`MASTERDATA` and `MASTERDATATYPE`) under `SET_DATACONFIG`, but UX intent has always been a single hub. The mockup confirms one screen with both lists visible side-by-side. Both menu URLs must resolve to the same page to preserve permissions and avoid orphan navigation.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Both entities already exist — DO NOT regenerate. This section documents current shape + the delta needed.

### Entity 1 — MasterDataType (left panel)

Table: `sett.MasterDataTypes`
Entity file: `Base.Domain/Models/SettingModels/MasterDataType.cs` (existing)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MasterDataTypeId | int | — | PK | — | Existing — keep |
| TypeCode | string | 100 | YES | — | Existing — unique per Company. UPPERCASE_WITH_UNDERSCORES (e.g., `SALUTATION`, `PAYMENT_MODE`). Helper: regex `^[A-Z][A-Z0-9_]*$` |
| TypeName | string | 100 | YES | — | Existing — display name (e.g., "Salutation", "Payment Mode") |
| Description | string? | 500 | NO | — | Existing — keep |
| IsSystem | bool | — | YES | — | Existing — drives delete-lock + System badge |
| **AllowMultipleSelection** | bool | — | YES | — | **NEW — ADD**. Default false. When true, fields using this type allow multi-select |
| **AllowUserInput** | bool | — | YES | — | **NEW — ADD**. Default false. When true, users can add new values inline from forms that consume this type |
| CompanyId | int? | — | YES (FK) | `app.Companies` | Existing — auto-filled from HttpContext, nullable for global system types |

**Inherited audit columns** (present via base class, not listed): `IsActive`, `IsDeleted`, `CreatedBy`, `CreatedDate`, `UpdatedBy`, `UpdatedDate`, `DeletedBy`, `DeletedDate`.

**Delta from current code (ALIGN gap)**:
- Add **`AllowMultipleSelection`** (bool, NOT NULL DEFAULT false) — entity + EF config + RequestDto + ResponseDto + Migration.
- Add **`AllowUserInput`** (bool, NOT NULL DEFAULT false) — entity + EF config + RequestDto + ResponseDto + Migration.
- Add **unique index** on `(TypeCode, CompanyId, IsActive, !IsDeleted)` if not already present (prevents duplicate type codes per tenant).

### Entity 2 — MasterData (right panel — values within a selected type)

Table: `sett.MasterDatas`
Entity file: `Base.Domain/Models/SettingModels/MasterData.cs` (existing)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MasterDataId | int | — | PK | — | Existing — keep |
| MasterDataTypeId | int | — | YES (FK) | `sett.MasterDataTypes` | Existing — drives the right-panel filter |
| DataValue | string | 100 | YES | — | Existing — **renders as "Code" in mockup**. Uppercase + underscore convention (e.g., `MR`, `MRS`, `SHEIKH`). Unique per `MasterDataTypeId + Company + IsActive + !IsDeleted` |
| DataName | string | 200 | YES | — | Existing — **renders as "Display Value" in mockup** (e.g., "Mr.", "Mrs.", "Sheikh") |
| **Abbreviation** | string? | 50 | NO | — | **NEW — ADD**. Optional short form (e.g., "Mr", "Sh", "Hj"). Mockup shows this as a dedicated column |
| Description | string? | 500 | NO | — | Existing — keep (mockup labels it "Description") |
| OrderBy | int | — | YES | — | Existing — **renders as "Sort Order" in mockup**. Drives display order + drag-reorder. Auto-assigned to `MAX+1` per type on create |
| ParentMasterDataId | int? | — | NO (self-FK) | `sett.MasterDatas` | Existing — keep but NOT exposed in this UI (not in mockup; reserved for future hierarchical lookups like Country→State) |
| DataSetting | string? | 500 | NO | — | Existing — JSON blob for arbitrary config (icon, color, alias). Reused for **translations** (see Special Notes ⑫ ISSUE-1) — store `{"translations":{"hi":"…","ar":"…"}}` |
| IsSystem | bool | — | YES | — | Existing — drives delete-lock for seeded values |
| CompanyId | int? | — | YES (FK) | `app.Companies` | Existing — auto-filled from HttpContext |

**Inherited audit columns**: same as MasterDataType.

**Delta from current code (ALIGN gap)**:
- Add **`Abbreviation`** (string?, max 50, NULL) — entity + EF config + RequestDto + ResponseDto + Migration.
- **No rename of OrderBy → SortOrder** at the column level (would cascade through ALL existing FE/BE code that reads OrderBy across the platform). Instead: **DTO uses `sortOrder` alias** that maps to `OrderBy` via Mapster. UI label is "Sort Order".
- **No rename of DataValue → Code or DataName → DisplayValue** at the column level (same cascade risk). UI labels are "Code" and "Display Value"; DTOs preserve the existing field names. Document this clearly in §⑦ Substitution Guide.
- Translations: stored in `DataSetting` JSON blob (see ISSUE-1). FE writes/reads via helper. **No new column, no new child table**.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| MasterDataTypeId (on MasterData) | MasterDataType | `Base.Domain/Models/SettingModels/MasterDataType.cs` | `getMasterDataTypes` (existing) — also new `getMasterDataTypeSummary` for left-panel counts | `typeName` | `MasterDataTypeResponseDto` |
| ParentMasterDataId (self-FK on MasterData) | MasterData | `Base.Domain/Models/SettingModels/MasterData.cs` | — (NOT used in this UI) | — | — |
| Auto-fill (no UI) | Company | `Base.Domain/Models/AppModels/Company.cs` | — (from HttpContext) | — | — |

**Important**:
- The right panel does NOT use an `ApiSelectV2` to pick MasterDataType — the type is selected by clicking a row in the left panel and held in component state. The selected `masterDataTypeId` is passed as a query argument to `GetMasterDatasByTypeId` (NEW — see §⑤).
- The Add-Value modal injects the `masterDataTypeId` from the currently selected type — the user does NOT see or change it.
- The Add/Edit-Type modal has NO FK fields (Code, TypeName, Description, AllowMultipleSelection, AllowUserInput, IsActive only).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

### Uniqueness Rules

- **MasterDataType.TypeCode** must be unique per Company (scoped to `IsActive=true AND IsDeleted=false`). Already enforced — verify and extend the validator if missing.
- **MasterData.DataValue** must be unique per `(MasterDataTypeId, Company)` (scoped to `IsActive=true AND IsDeleted=false`). Already enforced via composite EF index on `(MasterDataTypeId, ParentMasterDataId, IsActive)` — extend to include `DataValue` if not already covered.

### Required Field Rules

**MasterDataType:**
- `TypeName`, `TypeCode` required (max 100 each).
- `Description` optional (max 500).
- `AllowMultipleSelection`, `AllowUserInput` default false.

**MasterData:**
- `MasterDataTypeId`, `DataValue`, `DataName` required.
- `Abbreviation`, `Description` optional.
- `OrderBy` required int — auto-assigned to `MAX(OrderBy WHERE MasterDataTypeId = X) + 1` if omitted on create.

### Conditional Rules (NEW — gap vs current code)

**MasterDataType:**
- If `IsSystem = true`:
  - **Cannot delete** → `DeleteMasterDataType` handler must short-circuit with `BadRequestException("System data types cannot be deleted")`.
  - **TypeCode is readonly on edit** → UI enforces readOnly; BE validator asserts `existing.TypeCode == request.TypeCode` when `existing.IsSystem`.
  - Toggle active/inactive IS allowed.
- If a `MasterDataType` has any active `MasterData` rows linked to it → Delete handler must block with `BadRequestException("N values still exist under this type — delete or deactivate values first")`.

**MasterData:**
- If `IsSystem = true`:
  - **Cannot delete** → `DeleteMasterData` handler short-circuits with `BadRequestException("System values cannot be deleted")`.
  - **DataValue (Code) is readonly on edit** → UI enforces readOnly; BE validator asserts `existing.DataValue == request.DataValue` when `existing.IsSystem`.
  - Toggle active/inactive IS allowed.
- Cross-type protection: when ANY value is referenced from a downstream entity (e.g., a `Contact.SalutationId` exists), **deletion should still proceed soft-delete** because consumers FK to `MasterDataId` (not value); but a future enhancement could check usage. Out of scope for this ALIGN — see ISSUE-2.

### Business Logic

- **OrderBy auto-increment per type**: new `MasterData` row gets `MAX(OrderBy WHERE MasterDataTypeId = X) + 1` within the company. Already in handler — verify and add if absent.
- **Drag-to-reorder**: FE sends an ordered list of `{masterDataId, orderBy}` pairs scoped to one MasterDataTypeId → BE exposes a `ReorderMasterDatas(input: ReorderMasterDataInput)` mutation that updates `OrderBy` in a single transaction. **NEW mutation** to add.
- **Move Up / Move Down** (row dropdown): FE-only — calls the same `ReorderMasterDatas` mutation with the adjacent two rows swapped.
- **Translations** (Hindi/Arabic in modal): stored as JSON in `DataSetting` column. FE serializes `{"translations":{"hi":"…","ar":"…"}}` on save and parses on edit. NO new column, NO new child table. See ISSUE-1.

### Workflow

None (flat masters, no state machine).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: MASTER_GRID
**Type Classification**: **Type 5 — Combined dual-entity master** (non-canonical extension of Type 1 Simple flat master)
**Reason**: Two flat master entities rendered as a coordinated split-panel UI with TWO separate modals (one per entity). Each entity has its own CRUD endpoints; the UI binds them together via a "selected type" client-state. Modal forms keep the architecture squarely MASTER_GRID — no view-page, no Zustand store complexity, no multi-mode URL routing.

**Backend Patterns Required**:
- [x] Standard CRUD (× 2 entities — both already exist)
- [ ] Nested child creation — NO (each modal saves one entity at a time)
- [ ] Multi-FK validation — NO (single FK on MasterData, no user-facing FK pickers)
- [x] Unique validation — `TypeCode` per company; `DataValue` per `(typeId + company)` (already in place)
- [ ] File upload — NO
- [x] **Custom business rule validators** — ADD: system-row-delete guards (× 2), system-code-immutable guards (× 2), values-exist-delete guard (on type), drag-reorder transactional guard
- [x] **Filtered query** — ADD `GetMasterDatasByTypeId(masterDataTypeId, searchText, sortField, sortDir, isActive)` returning paginated `MasterDataResponseDto[]`. The existing `GetMasterDatas` is unfiltered and unsuitable for the right panel.
- [x] **Type list with counts** — ADD `GetMasterDataTypeSummary` returning `[MasterDataTypeWithCountDto { masterDataTypeId, typeName, typeCode, isSystem, isActive, valuesCount }]` — feeds the LEFT panel and the search box.
- [x] **Reorder mutation** — ADD `ReorderMasterDatas(input: [{masterDataId, orderBy}])` — single transaction.
- [x] **DTO field additions** — `IsSystem` on both ResponseDtos (already exists on entity, missing from FE-facing DTOs in current code), `AllowMultipleSelection` + `AllowUserInput` on MasterDataType DTOs, `Abbreviation` on MasterData DTOs, `valuesCount` derived for MasterDataType.

**Frontend Patterns Required**:
- [x] AdvancedDataTable — used inside the right panel (filtered to selected type)
- [x] RJSF Modal Form × 2 — Type form + Value form (both driven by GridFormSchema on the seeded grids)
- [x] **Split-panel layout** — 30%/70% custom layout, NOT the canonical Variant A or B
- [x] **Client-side type selection state** — selectedTypeId held in local React state (no Zustand needed for a single page-local value)
- [x] **Search box on left panel** — client-side filter on type list (typeName, typeCode `includes()`)
- [x] **Drag-to-reorder + Move Up/Move Down** — for MasterData rows in right panel
- [x] **Conditional edit lock** — DataValue readonly + Delete hidden when `isSystem=true` (× 2 modals)
- [x] **System badge** — in left panel meta + right panel header. Reuse `system-badge` renderer if it exists from ContactType #19, else create.
- [x] **Translations sub-form** — Hindi + Arabic inputs inside Value modal (write to DataSetting JSON)
- [ ] Summary widgets above grid — NO (mockup has no count cards above the split layout)
- [ ] Side panel (canonical sense) — NO (the split-panel IS the layout; no extra info panel)
- [x] **Service Placeholder buttons**: "Import" + "Export All" + per-type "Export" — UI buttons render with toast (no IFileImport/IFileExport service exists)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from `html_mockup_screens/screens/settings/master-data.html`.

### Page Header (top of viewport)

| Element | Text / Icon | Behaviour |
|---------|-------------|-----------|
| Title | `<i fa-database/>` "Master Data" | Static |
| Subtitle | "Manage lookup values, categories, and reference data" | Static |
| Action | `[+ New Data Type]` (accent button) | Opens **Create-Type modal** |
| Action | `[Import]` (outline button, fa-file-import) | **SERVICE_PLACEHOLDER** — toast "Import flow coming soon" |
| Action | `[Export All]` (outline button, fa-file-export) | **SERVICE_PLACEHOLDER** — toast "Export flow coming soon" |

### Layout Variant

**Layout Variant** (REQUIRED — stamp one): `widgets-above-grid` — **but with a custom split-panel inner layout.**

Specifically:
- Page-level wrapper uses `<ScreenHeader>` (title + subtitle + 3 header actions). **Variant B selected.**
- Below the header: a flex/grid `min-h-[calc(100vh-130px)]` with TWO panels side by side:
  - **Left panel** = 30% width (`min-width: 280px`), white background, rounded card.
  - **Right panel** = 70% (flex-1), white background, rounded card.
- On `<lg` breakpoint: stack vertically (left panel above right, max-height 300px on left).

This is NOT canonical Variant A/B. **The split-panel IS the layout** — there is no `<AdvancedDataTable showHeader>` at page-root. The right panel embeds its OWN data table.

### Left Panel — Data Type List

**Sections:**
1. **Panel Header** (sticky, 1rem padding):
   - Title: "Data Types" (bold)
   - Right-aligned count: `"{N} types"` (e.g., "12 types") — derived from `GetMasterDataTypeSummary` length.
2. **Search Box** (sticky below header):
   - Single text input with magnifier icon, placeholder "Search data types…"
   - Client-side filter on `typeName` + `typeCode` (case-insensitive `includes()`).
3. **Type List** (scrollable):
   - One row per `MasterDataType`. Row layout:
     - 32×32 left icon tile (rounded, grey bg, fa-clipboard-list inside) — when row is active, tile bg becomes accent and icon white.
     - Right info block:
       - Line 1: TypeName (semi-bold, 0.8125rem). Single-line ellipsis if too long.
       - Line 2: meta — `"{valuesCount} values"` + System/Custom badge.
   - **Active row** (currently selected type): light accent bg + 3px left-border accent.
   - **Hover**: bg `#f8fafc`.
   - Border-bottom 1px between rows.

**Type List GQL Source**:
- New query `GetMasterDataTypeSummary(searchText: String, isActive: Boolean): [MasterDataTypeWithCountDto]`.
- Returns rows with embedded `valuesCount = COUNT(MasterDatas WHERE MasterDataTypeId = X AND !IsDeleted AND IsActive)`.
- Sorted by `TypeName ASC` (or `IsSystem DESC, TypeName ASC` to show System types first per mockup ordering).

**Badge Tokens** (mockup):
- System: `bg #fff7ed text #f97316` (amber-50/500). Use UI token `warning` or `info` per design system. Icon `fa-lock` (use Phosphor `ph:lock` per token rules).
- Custom: `bg #f0fdf4 text #22c55e` (green-50/500). Use `success` token. No icon.

**Default selected**: first row in the list (by display order). When selectedTypeId is null, right panel shows empty state.

### Right Panel — Values Grid (filtered by selected type)

**Right Panel Header** (sticky):

Top row (flex space-between):
- **Left**:
  - Type Title: `{selectedType.typeName}` (1.125rem bold). Empty when no type selected.
  - Type Description: `{selectedType.description}` (0.8125rem grey).
  - Badges row:
    - `code-badge` showing `{selectedType.typeCode}` (monospace pill, grey).
    - **If `selectedType.isSystem`**: `system-lock-badge` — "🔒 System type" (amber pill).
- **Right** (action group):
  - `[+ Add Value]` (accent sm button). Opens **Add/Edit-Value modal**.
  - `[Edit Type]` (outline sm button). Opens **Add/Edit-Type modal** pre-filled with selected type. Disabled visually OR uses readonly fields when `isSystem=true` (DataValue+TypeCode field both readonly).
  - `[Export]` (outline sm button) — **SERVICE_PLACEHOLDER** for per-type export.

**Empty state (no type selected)**: "Select a data type from the left panel to view its values" + hand-pointer icon. Hide all header actions and the values table.

**Values Table** (right-panel body, scrollable):

Columns (in display order, matching mockup):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | (drag handle) | — | drag-handle icon | 36px | NO | `fa-grip-vertical` (Phosphor `ph:dots-six-vertical`) — triggers drag-reorder within the type |
| 2 | # | (row index) | row-number | 40px | NO | 1-based auto-number based on OrderBy sort |
| 3 | Code | `dataValue` | code-badge | 120px | YES | Monospace pill (e.g., "MR", "MRS") |
| 4 | Display Value | `dataName` | text (bold) | auto | YES | Primary column, `<strong>` |
| 5 | Abbreviation | `abbreviation` | text | 120px | YES | NEW — short form (e.g., "Mr", "Sh") |
| 6 | Active | `isActive` | status-badge | 100px | YES | Existing active/inactive renderer |
| 7 | Sort Order | `sortOrder` (=`orderBy`) | order-num | 80px | YES | Numeric — show sequential 1,2,3 |
| 8 | Actions | — | action-buttons | 100px | NO | Pen (Edit) + Ellipsis (More) dropdown |

**Inactive row visual cue**: 50% opacity (`tbody tr.inactive { opacity: 0.5; }` per mockup).

**Action cell — primary button**:
- Pen icon → opens **Add/Edit-Value modal** in edit mode.

**Action cell — More dropdown menu** (mockup has the 5-item dropdown):
- Edit
- Activate (when `!isActive`) / Deactivate (when `isActive`)
- Move Up (disabled on first row)
- Move Down (disabled on last row)
- Delete (RED, ONLY when `!isSystem`)

Dropdown uses `<DropdownMenu>` from existing primitive (Radix or shadcn — check FE registry first).

**Search/Filter Fields** (right panel): `dataValue`, `dataName`, `abbreviation`, `description`, `isActive` (passed as args to `GetMasterDatasByTypeId`).

**Right Panel GQL Source**:
- New query `GetMasterDatasByTypeId(masterDataTypeId: Int!, searchText, pageNo, pageSize, sortField, sortDir, isActive): { items: [MasterDataResponseDto], totalCount }`.
- Triggered when `selectedTypeId` changes; refetched after any mutation (CRUD/toggle/reorder).

### Modal 1 — Create / Edit Data Type

**Trigger**:
- `+ New Data Type` (page header) → modal in CREATE mode.
- `Edit Type` (right-panel header) → modal in EDIT mode, pre-filled with `selectedType`.

**Fields** (in order, matching mockup):

| Field | Widget | Placeholder / Helper | Validation | Notes |
|-------|--------|----------------------|------------|-------|
| typeName | text | "e.g., Volunteer Skill" | required, max 100 | — |
| typeCode | text | "e.g., VOLUNTEER_SKILL" | required, max 100, regex `^[A-Z][A-Z0-9_]*$` | **Auto-uppercase + space-to-underscore** transform on input. Helper: "UPPERCASE with underscores. Max 100 characters." Readonly when `isSystem=true` (edit mode). |
| description | text | "Skills that volunteers can be tagged with" | optional, max 500 | Single-line text per mockup (NOT textarea) |
| allowMultipleSelection | switch | label "Fields using this type allow multi-select" | — | Default false |
| allowUserInput | switch | label "Users can add new values inline" | — | Default false |

**Hidden fields** (in formData, not rendered):
- `isSystem` — read-only pass-through. Never editable.
- `isActive` — defaults true on create; in edit mode, toggling is via the value's row dropdown only (not in modal). Optional: include `isActive` switch on the Type modal so admins can deactivate a whole type — confirm with user. Out of scope for v1: omit from modal.

**Buttons**:
- Cancel (outline)
- `[✓ Create Type]` / `[✓ Save]` (accent)

**Save flow**:
- Create: invokes `CreateMasterDataType` → on success, append to left list, **set as selectedTypeId**, close modal.
- Edit: invokes `UpdateMasterDataType` → on success, refetch left list, keep selection, close modal.

### Modal 2 — Add / Edit Data Value

**Trigger**:
- `+ Add Value` (right-panel header) → modal in CREATE mode (with `masterDataTypeId = selectedTypeId` injected).
- Pen icon (row action) → modal in EDIT mode, pre-filled.
- Edit (row dropdown) → same as pen.

**Fields** (in order, matching mockup):

| Field | Widget | Placeholder / Helper | Validation | Notes |
|-------|--------|----------------------|------------|-------|
| dataValue | text | "e.g., SHEIKH" | required, max 100, regex `^[A-Z][A-Z0-9_]*$` | **Auto-uppercase + no-space transform**. Readonly when `isSystem=true` (edit). Helper: "UPPERCASE, no spaces." |
| dataName | text | "e.g., Sheikh" | required, max 200 | — |
| abbreviation | text | "e.g., Sh" | optional, max 50 | NEW field |
| description | text | "Optional description" | optional, max 500 | — |
| isActive | switch | "Enabled" | — | Default true |
| sortOrder (=orderBy) | number, width 100px | "e.g., 9" | min 1 | Default = `MAX(OrderBy WHERE typeId = selected) + 1` (auto-fill on create) |
| **Translations section** (collapsible/static) | — | "Translations" group label with `fa-language` icon | optional | TWO inputs: |
| translations.hi | text | (Hindi placeholder) | optional, max 200 | Label "Hindi" |
| translations.ar | text | (Arabic placeholder, RTL) | optional, max 200 | Label "Arabic". Render input with `dir="rtl"` |

**Hidden fields**: `masterDataTypeId` (from selectedTypeId), `isSystem` (read-only pass-through), `companyId` (auto from BE).

**Translations storage** (BE-side): on save, FE sends `dataSetting: JSON.stringify({translations: {hi, ar}})` and BE persists into `DataSetting` column. On edit, FE parses `dataSetting` JSON and pre-fills the two inputs. See ISSUE-1.

**Buttons**: Cancel + `[✓ Save]`.

**Save flow**:
- Create: `CreateMasterData` → refetch right panel + refetch left panel (valuesCount may change) → close modal.
- Edit: `UpdateMasterData` → refetch right panel only → close modal.

### Drag-to-Reorder + Move Up / Move Down

- Use `@dnd-kit/sortable` (or existing drag-reorder primitive — **check first** in `presentation/.../primitives` and renderer registry).
- Drag handle column (col 1) is the only grab target.
- Reorder is scoped to the **selected type only** — cross-type drag is forbidden.
- On drop: compute new ordered array of `{masterDataId, orderBy: newIndex + 1}` → fire `ReorderMasterDatas` mutation → refetch right panel.
- Move Up / Move Down: client-side compute swap of two adjacent rows → same mutation.
- Optimistic UI: reorder locally, revert on error.

### User Interaction Flow

1. User lands on `/setting/dataconfig/masterdata` → left panel loads (12 types, sorted) → first row auto-selected → right panel loads its values.
2. User types in left search → list filters live.
3. User clicks a different type in left list → right panel header + grid re-render with new type's data.
4. User clicks `+ New Data Type` (page header) → Type modal opens empty → fills 5 fields → Save → new type appears in left, becomes selected.
5. User clicks `Edit Type` (right header) → Type modal opens pre-filled. If `isSystem=true`, TypeCode is readonly; Save still works for other fields.
6. User clicks `+ Add Value` (right header) → Value modal opens with masterDataTypeId locked to selected → fills fields + optional translations → Save → row appears at next sortOrder.
7. User clicks pen icon on a row → Value modal opens pre-filled; if value `isSystem=true`, DataValue (Code) is readonly.
8. User clicks ⋮ on a row → dropdown shows context-aware actions (Activate vs Deactivate, Move Up disabled on first, Delete hidden when isSystem=true).
9. User drags a row by handle → drops at new position → SortOrder recomputed and persisted.
10. User clicks Delete (custom rows only) → confirm dialog → soft-delete → row vanishes → left-panel valuesCount decrements.
11. Page-header `Import` / `Export All` → toast (SERVICE_PLACEHOLDER).

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> This screen has TWO entities. Use the canonical MASTER_GRID reference (ContactType) for each, but flag divergences.

**Canonical Reference**: ContactType (MASTER_GRID, prompts/contacttype.md)

### MasterDataType substitution

| Canonical (per _MASTER_GRID.md) | → MasterDataType in this repo | Context |
|---------------------------------|------------------------------|---------|
| ContactType | MasterDataType | Entity/class name |
| contactType | masterDataType | camelCase |
| ContactTypeId | MasterDataTypeId | PK |
| ContactTypeCode | TypeCode (NOT MasterDataTypeCode) | **DIVERGENCE — preserve existing column name** |
| ContactTypeName | TypeName (NOT MasterDataTypeName) | **DIVERGENCE — preserve existing column name** |
| ContactTypes | MasterDataTypes | Plural / table name |
| contact-type | master-data-type (URL) / masterdatatype (folder) | kebab-case / lower no-dash |
| CONTACTTYPE | MASTERDATATYPE | grid code, menu code |
| corg | sett | DB schema |
| **Corg** (template) | **Setting** | Group suffix in repo: `SettingModels`, `SettingConfigurations`, `SettingSchemas`, `SettingBusiness`, `EndPoints/Setting` |
| CorgModels | SettingModels | Namespace |
| CONTACT (parent menu) | SET_DATACONFIG (parent menu) | Different parent |
| CRM | SETTING | Module code |
| crm/contact/contacttype | setting/dataconfig/masterdatatype (existing route — see Special Notes) | FE route base — note the combined screen REPLACES this with `setting/dataconfig/masterdata` |
| corg-service | setting-service | FE service folder name |

### MasterData substitution

| Canonical | → MasterData in this repo | Context |
|-----------|--------------------------|---------|
| ContactType | MasterData | Entity/class name |
| contactType | masterData | camelCase |
| ContactTypeId | MasterDataId | PK |
| ContactTypeCode | DataValue (NOT MasterDataCode) | **DIVERGENCE — preserve existing column name; UI labels it "Code"** |
| ContactTypeName | DataName (NOT MasterDataName) | **DIVERGENCE — preserve existing column name; UI labels it "Display Value"** |
| OrderBy | OrderBy (alias as `sortOrder` in DTO/UI) | **DIVERGENCE — DTO exposes camelCase `sortOrder` mapped from entity `OrderBy` via Mapster** |
| ContactTypes (plural table) | MasterDatas | Plural — note the unusual pluralization (`MasterDatas`) is the existing table name |
| CONTACTTYPE | MASTERDATA | grid code, menu code |
| corg / Corg / CorgModels | sett / Setting / SettingModels | Same as MasterDataType |
| crm/contact/contacttype | setting/dataconfig/masterdata | FE route — THIS is the combined screen route |

**Flag for devs copying from the canonical**:
- The repo's existing column names (`TypeCode`, `TypeName`, `DataValue`, `DataName`) DO NOT follow the `{Entity}Code/{Entity}Name` template. **Do NOT rename**. The cascade across consuming entities (Contact, Donation, Volunteer, etc., dozens of `MasterData` references) would break the entire platform.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> **ALIGN scope — existing files are MODIFIED, not recreated.** Only the Delta column matters.

### Backend Files (MODIFY in place, except where flagged NEW or DELETE)

| # | File | Path | Delta |
|---|------|------|-------|
| 1 | Entity — MasterDataType | `Base.Domain/Models/SettingModels/MasterDataType.cs` | **ADD** `AllowMultipleSelection` (bool, default false), `AllowUserInput` (bool, default false). |
| 2 | Entity — MasterData | `Base.Domain/Models/SettingModels/MasterData.cs` | **ADD** `Abbreviation` (string?, max 50). |
| 3 | EF Config — MasterDataType | `Base.Infrastructure/Data/Configurations/SettingConfigurations/MasterDataTypeConfigurations.cs` | **ADD** unique filtered index on `(TypeCode, CompanyId, IsActive)` if not present. **ADD** column configurations for the 2 new columns (defaults). |
| 4 | EF Config — MasterData | `Base.Infrastructure/Data/Configurations/SettingConfigurations/MasterDataConfigurations.cs` | **ADD** column config for `Abbreviation` (HasMaxLength 50, IsNullable). Verify `(MasterDataTypeId, DataValue, CompanyId, IsActive)` unique filtered index — add if missing. |
| 5 | Schemas — MasterDataType | `Base.Application/Schemas/SettingSchemas/MasterDataTypeSchemas.cs` | **ADD** `AllowMultipleSelection`, `AllowUserInput` to RequestDto + ResponseDto. **ADD** `IsSystem` to ResponseDto. **ADD** new DTO `MasterDataTypeWithCountDto` (extends ResponseDto with `valuesCount: int`). **ADD** new DTO `MasterDataTypeSummaryRequestDto` if needed for filter args. |
| 6 | Schemas — MasterData | `Base.Application/Schemas/SettingSchemas/MasterDataSchemas.cs` | **ADD** `Abbreviation` to RequestDto + ResponseDto. **ADD** `IsSystem` to ResponseDto. **ADD** alias `SortOrder` mapped from `OrderBy` (Mapster config). **ADD** new DTO `ReorderMasterDataRequestDto { masterDataId, orderBy }` (used as input array on `ReorderMasterDatas`). |
| 7 | GetAll Query — MasterDataType | `Base.Application/Business/SettingBusiness/MasterDataTypes/Queries/GetMasterDataType.cs` | **MODIFY** projection to include `IsSystem`, `AllowMultipleSelection`, `AllowUserInput`. Keep existing pagination/search. |
| 8 | GetById Query — MasterDataType | `.../GetMasterDataTypeById.cs` | Same projection delta. |
| 9 | **NEW** — GetMasterDataTypeSummary | `.../MasterDataTypes/Queries/GetMasterDataTypeSummary.cs` | **CREATE** — args `(searchText: string?, isActive: bool?)`, returns `[MasterDataTypeWithCountDto]` with embedded `valuesCount = COUNT(MasterDatas WHERE MasterDataTypeId = X AND !IsDeleted AND IsActive)`. Used by left panel. |
| 10 | Update Command — MasterDataType | `.../MasterDataTypes/Commands/UpdateMasterDataType.cs` | **ADD** rule: if `existing.IsSystem`, reject when `existing.TypeCode != request.TypeCode`. |
| 11 | Delete Command — MasterDataType | `.../MasterDataTypes/Commands/DeleteMasterDataType.cs` | **ADD** rule 1: if `existing.IsSystem` → BadRequest. **ADD** rule 2: if `MasterDatas.Any(WHERE !IsDeleted AND MasterDataTypeId = X)` → BadRequest "N values still exist under this type". |
| 12 | GetAll Query — MasterData | `.../MasterDatas/Queries/GetMasterData.cs` | **MODIFY** projection to include `IsSystem`, `Abbreviation`, and Mapster alias `SortOrder ← OrderBy`. |
| 13 | GetById Query — MasterData | `.../MasterDatas/Queries/GetMasterDataById.cs` | Same projection delta. |
| 14 | **NEW** — GetMasterDatasByTypeId | `.../MasterDatas/Queries/GetMasterDatasByTypeId.cs` | **CREATE** — args `(masterDataTypeId: int, searchText, pageNo, pageSize, sortField, sortDir, isActive)`, returns paginated `MasterDataResponseDto[]`. **Default sort: OrderBy ASC**. Used by right panel. |
| 15 | Update Command — MasterData | `.../MasterDatas/Commands/UpdateMasterData.cs` | **ADD** rule: if `existing.IsSystem`, reject when `existing.DataValue != request.DataValue`. |
| 16 | Delete Command — MasterData | `.../MasterDatas/Commands/DeleteMasterData.cs` | **ADD** rule: if `existing.IsSystem` → BadRequest. |
| 17 | **NEW** — Reorder Command | `.../MasterDatas/Commands/ReorderMasterDatas.cs` | **CREATE** — args `[{masterDataId, orderBy}]`, updates OrderBy in one transaction. Verify all rows belong to the same MasterDataTypeId + same Company before commit. |
| 18 | Mutations endpoint — MasterDataType | `Base.API/EndPoints/Setting/Mutations/MasterDataTypeMutations.cs` | **No new fields** (existing 4 mutations cover Type CRUD). |
| 19 | Mutations endpoint — MasterData | `Base.API/EndPoints/Setting/Mutations/MasterDataMutations.cs` | **ADD** `ReorderMasterDatas` field. |
| 20 | Queries endpoint — MasterDataType | `Base.API/EndPoints/Setting/Queries/MasterDataTypeQueries.cs` | **ADD** `GetMasterDataTypeSummary` field. |
| 21 | Queries endpoint — MasterData | `Base.API/EndPoints/Setting/Queries/MasterDataQueries.cs` | **ADD** `GetMasterDatasByTypeId` field. |
| 22 | Mappings | `Base.Application/Mappings/SettingMappings.cs` | **ADD** Mapster config: `MasterData → MasterDataResponseDto` map `OrderBy → SortOrder`. **ADD** map for `MasterDataTypeWithCountDto`. **ADD** maps for new DTOs. |
| 23 | **NEW** — Migration | `Base.Infrastructure/Migrations/{timestamp}_AddMasterDataAlignmentColumns.cs` | **CREATE** EF migration adding `MasterDataType.AllowMultipleSelection`, `MasterDataType.AllowUserInput`, `MasterData.Abbreviation`, plus the 2 unique filtered indexes. |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext` / `ISettingDbContext` / `SettingDbContext` | **No change** — DbSet<MasterData> + DbSet<MasterDataType> already registered. |
| 2 | `DecoratorProperties.cs` | **No change** — `DecoratorSettingModules.MasterData = "MASTERDATA"` and `MasterDataType = "MASTERDATATYPE"` already exist (lines 94-95). |
| 3 | `SettingMappings.cs` | Covered in row 22 above. |

### Frontend Files (CONSOLIDATE — delete duplicates, modify primary, create combined page)

**Files to DELETE** (duplicate / orphan after consolidation):

| # | File | Path | Reason |
|---|------|------|--------|
| 1 | Shared duplicate page config | `presentation/pages/shared/configuration/mastersetup/masterdata.tsx` | Duplicate of setting-route — orphan after combining |
| 2 | Shared duplicate page config | `presentation/pages/shared/configuration/mastersetup/masterdatatype.tsx` | Duplicate — orphan |
| 3 | Shared duplicate component | `presentation/components/page-components/shared/configuration/mastersetup/masterdata-components/data-table.tsx` | Duplicate |
| 4 | Shared duplicate component | `presentation/components/page-components/shared/configuration/mastersetup/masterdatatype-components/data-table.tsx` | Duplicate |

> If sandbox blocks physical delete, neutralize file content to `export {};` and flag for `git rm` post-merge (ContactDashboard #123 ISSUE-15 precedent).

**Files to MODIFY**:

| # | File | Path | Delta |
|---|------|------|-------|
| 1 | DTO — MasterData | `domain/entities/setting-service/MasterDataDto.ts` | **RENAME** `dataDescription` → `description` (FE typo — backend uses `description`). **ADD** `isSystem: boolean`, `abbreviation: string \| null`, `sortOrder: number` (alias of orderBy from BE). **REMOVE** `dataDescription`. |
| 2 | DTO — MasterDataType | `domain/entities/setting-service/MasterDataTypeDto.ts` | **RENAME** `isSystemType` → `isSystem` (align with BE). **ADD** `allowMultipleSelection: boolean`, `allowUserInput: boolean`. **ADD** new type `MasterDataTypeWithCountDto extends MasterDataTypeResponseDto { valuesCount: number }`. |
| 3 | GQL Query — MasterData | `infrastructure/gql-queries/setting-queries/MasterDataQuery.ts` | **MODIFY** `MASTERDATAS_QUERY` selection set to include `isSystem`, `abbreviation`, `sortOrder`. **ADD** `MASTERDATAS_BY_TYPE_QUERY` calling `getMasterDatasByTypeId(masterDataTypeId: $id, ...)`. |
| 4 | GQL Query — MasterDataType | `infrastructure/gql-queries/setting-queries/MasterDataTypeQuery.ts` | **MODIFY** existing query to use `isSystem` (drop `isSystemType`). **ADD** new fields `allowMultipleSelection`, `allowUserInput`. **ADD** `MASTERDATATYPE_SUMMARY_QUERY` calling `getMasterDataTypeSummary` and selecting `valuesCount` alongside the rest. |
| 5 | GQL Mutation — MasterData | `infrastructure/gql-mutations/setting-mutations/MasterDataMutation.ts` | **ADD** `REORDER_MASTERDATAS_MUTATION` calling `reorderMasterDatas(input: [...])`. **MODIFY** existing CREATE/UPDATE mutations to send `abbreviation`, `sortOrder` (mapped to orderBy on BE), `dataSetting` (used for translations payload). |
| 6 | GQL Mutation — MasterDataType | `infrastructure/gql-mutations/setting-mutations/MasterDataTypeMutation.ts` | **MODIFY** CREATE/UPDATE mutations to send `allowMultipleSelection`, `allowUserInput`. Drop `isSystemType` (use `isSystem`). |
| 7 | Page Config — primary | `presentation/pages/setting/dataconfig/masterdata.tsx` | **REWRITE** to render the combined `<MasterDataCombinedPage />` (split-panel). Capability menuCode stays `MASTERDATA`. |
| 8 | Page Config — secondary | `presentation/pages/setting/dataconfig/masterdatatype.tsx` | **REWRITE** to render the same `<MasterDataCombinedPage />` — both routes resolve to the same UI. Capability menuCode stays `MASTERDATATYPE` so existing role grants still apply. |

**Files to CREATE** (new):

| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | Combined page component | `presentation/components/page-components/setting/dataconfig/masterdata/index-page.tsx` | Top-level orchestrator — `<ScreenHeader>` + split-panel layout, holds `selectedTypeId` state |
| 2 | Type list (left panel) | `presentation/components/page-components/setting/dataconfig/masterdata/type-list-panel.tsx` | Search + scrollable list of MasterDataType rows with valuesCount + System/Custom badges, click handler sets selectedTypeId |
| 3 | Values panel (right panel) | `presentation/components/page-components/setting/dataconfig/masterdata/values-panel.tsx` | Right-panel header (selected type + 3 actions) + values data table (uses `<DataTableContainer>` with `gridCode="MASTERDATA"` and `extraQueryArgs={{ masterDataTypeId: selectedTypeId }}`) |
| 4 | Type modal | `presentation/components/page-components/setting/dataconfig/masterdata/type-modal.tsx` | Create/Edit-Type RJSF modal driven by `MASTERDATATYPE` GridFormSchema |
| 5 | Value modal | `presentation/components/page-components/setting/dataconfig/masterdata/value-modal.tsx` | Add/Edit-Value RJSF modal driven by `MASTERDATA` GridFormSchema, with translations sub-form (Hindi+Arabic) writing to dataSetting JSON |
| 6 | Translation widget (RJSF custom widget) | `presentation/widgets/dgf-widgets/translations-widget.tsx` | RJSF widget rendering Hindi+Arabic inputs, persists to `dataSetting` JSON. Register in `dgf-widgets/index.ts` as `TranslationsWidget`. **Check first** — if a generic `JsonObjectWidget` covers it, configure via grid schema instead. |
| 7 | Renderer — system-badge | `presentation/components/shared-cell-renderers/system-badge.tsx` (if not already created by ContactType #19) | System/Custom pill renderer. **REUSE** if `system-badge` was already created by ContactType #19; otherwise create + register in advanced/basic/flow column-type registries. |
| 8 | Empty-state component | `presentation/components/page-components/setting/dataconfig/masterdata/empty-state.tsx` | "Select a data type from the left panel to view its values" placeholder for right panel when no type is selected |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `infrastructure/services/.../setting-service-entity-operations.ts` | Verify `MASTERDATA` and `MASTERDATATYPE` entries exist; add `REORDER` operation under MASTERDATA. |
| 2 | Component-column registries (advanced / basic / flow) | If `system-badge` is new, register it in all 3 (`presentation/components/data-tables/.../component-column.tsx` × 3 — verify path). |
| 3 | Shared-cell-renderers barrel | `presentation/components/shared-cell-renderers/index.ts` — export the new renderer. |
| 4 | dgf-widgets index | `presentation/widgets/dgf-widgets/index.ts` — register `TranslationsWidget` (if created). |
| 5 | Sidebar menu config | **No change** — both menus already registered under `SET_DATACONFIG`. The DB seed will mark `MASTERDATATYPE` as a hidden/redirect menu (see ⑨). |
| 6 | Page-component barrel | `presentation/components/page-components/setting/dataconfig/index.ts` (or local `masterdata/index.ts`) — export `MasterDataCombinedPage`. |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: ALIGN

# Single combined screen visible in sidebar
MenuName: Master Data
MenuCode: MASTERDATA
ParentMenu: SET_DATACONFIG
Module: SETTING
MenuUrl: setting/dataconfig/masterdata
GridType: MASTER_GRID
IsLeastMenu: true
OrderBy: 1

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: REGENERATE
GridCode: MASTERDATA

GridFormSchema Content (MasterData / Value modal — used inside the combined page):
- Title: "Data Value"
- Fields (order + UI hints):
  1. dataValue                    → TextWidget, required, maxLength 100, regex ^[A-Z][A-Z0-9_]*$, uppercase+no-space transform, readonly when formData.isSystem === true, helper "UPPERCASE, no spaces."
  2. dataName                     → TextWidget, required, maxLength 200, placeholder "e.g., Sheikh"
  3. abbreviation                 → TextWidget, maxLength 50, placeholder "e.g., Sh"
  4. description                  → TextWidget (single-line), maxLength 500, placeholder "Optional description"
  5. isActive                     → SwitchWidget, default true, label "Enabled"
  6. sortOrder                    → NumberWidget, min 1, default = (max + 1) at new-record time per type
  7. translations (object)        → TranslationsWidget — sub-fields: hi (string), ar (string). Writes to dataSetting JSON on save, parses on edit.
- Hidden fields (in formData, not rendered):
  - masterDataTypeId (injected from selectedTypeId)
  - isSystem (read-only pass-through)
  - companyId (auto-filled by BE)
- Layout: single column. fields 1-4 full width; field 5 (switch) inline; field 6 narrow (100px); field 7 collapsible group "Translations".

# Hidden / redirect menu — kept seeded for capability cascade and legacy URL support
MenuName: Master Data Type
MenuCode: MASTERDATATYPE
ParentMenu: SET_DATACONFIG
Module: SETTING
MenuUrl: setting/dataconfig/masterdatatype
GridType: MASTER_GRID
IsLeastMenu: false   # HIDDEN from sidebar — points to combined screen via FE redirect or render-same-component
OrderBy: 2

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE

GridFormSchema: REGENERATE
GridCode: MASTERDATATYPE

GridFormSchema Content (MasterDataType / Type modal):
- Title: "Data Type"
- Fields (order):
  1. typeName                     → TextWidget, required, maxLength 100, placeholder "e.g., Volunteer Skill"
  2. typeCode                     → TextWidget, required, maxLength 100, regex ^[A-Z][A-Z0-9_]*$, uppercase+space-to-underscore transform, readonly when formData.isSystem === true, helper "UPPERCASE with underscores."
  3. description                  → TextWidget (single-line), maxLength 500
  4. allowMultipleSelection       → SwitchWidget, default false, label "Fields using this type allow multi-select"
  5. allowUserInput               → SwitchWidget, default false, label "Users can add new values inline"
- Hidden fields:
  - isSystem (read-only pass-through)
  - companyId (auto-filled by BE)
- Layout: single column.
---CONFIG-END---
```

**Note on dual menu seeding**:
- The `MASTERDATA` menu is the visible sidebar entry pointing to the combined screen.
- The `MASTERDATATYPE` menu is **kept seeded** (with `IsLeastMenu=false` to hide from sidebar) so existing role-capability grants continue to function and the legacy URL `setting/dataconfig/masterdatatype` still resolves (FE renders the same combined component).

**Note on Role seeding**: per project preference, only `BUSINESSADMIN` role is enumerated. Other roles inherit via the capability cascade.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — exact names to call.

### GraphQL Root Types

- Query: `MasterDataQueries`, `MasterDataTypeQueries` (existing — extend)
- Mutation: `MasterDataMutations`, `MasterDataTypeMutations` (existing — extend)

### Queries

| GQL Field | Returns | Key Args | Status |
|-----------|---------|----------|--------|
| `getMasterDataTypes` | paginated `{ items: [MasterDataTypeResponseDto], totalCount }` | searchText, pageNo, pageSize, sortField, sortDir, isActive | **EXISTS** — modify projection to add `isSystem`, `allowMultipleSelection`, `allowUserInput` |
| `getMasterDataTypeById` | `MasterDataTypeResponseDto` | masterDataTypeId | **EXISTS** — same projection delta |
| `getMasterDataTypeSummary` | `[MasterDataTypeWithCountDto]` | searchText, isActive | **NEW** — feeds left panel with `valuesCount` per type |
| `getMasterDatas` | paginated `{ items: [MasterDataResponseDto], totalCount }` | searchText, pageNo, pageSize, sortField, sortDir, isActive | **EXISTS** — modify projection to add `isSystem`, `abbreviation`, `sortOrder` |
| `getMasterDataById` | `MasterDataResponseDto` | masterDataId | **EXISTS** — same projection delta |
| `getMasterDatasByTypeId` | paginated `{ items: [MasterDataResponseDto], totalCount }` | masterDataTypeId, searchText, pageNo, pageSize, sortField, sortDir, isActive | **NEW** — feeds right panel |

### Mutations

| GQL Field | Input | Returns | Status |
|-----------|-------|---------|--------|
| `createMasterDataType` | `MasterDataTypeRequestDto` | int | **EXISTS** — accepts new `allowMultipleSelection`, `allowUserInput` |
| `updateMasterDataType` | `MasterDataTypeRequestDto` | int | **EXISTS** — add system-code-immutable guard |
| `deleteMasterDataType` | masterDataTypeId | int | **EXISTS** — add system + values-exist guards |
| `activateDeactivateMasterDataType` | masterDataTypeId | int | **EXISTS** — keep existing name |
| `createMasterData` | `MasterDataRequestDto` | int | **EXISTS** — accepts new `abbreviation`, `dataSetting` (translations JSON) |
| `updateMasterData` | `MasterDataRequestDto` | int | **EXISTS** — add system-code-immutable guard |
| `deleteMasterData` | masterDataId | int | **EXISTS** — add system guard |
| `activateDeactivateMasterData` | masterDataId | int | **EXISTS** — keep existing name |
| `reorderMasterDatas` | `[ReorderMasterDataRequestDto { masterDataId, orderBy }]` | int (count updated) | **NEW** |

**⚠ GQL-name preservation**: keep existing field names — do NOT rename `getMasterDatas` to `getAllMasterDataList` or `activateDeactivateMasterData` to `toggleMasterData`. The existing FE is wired to these names and the canonical naming guide is just a guide, not a hard requirement (ContactType #19 ISSUE precedent).

### Response DTO Fields

**MasterDataTypeResponseDto** (after ALIGN):

| Field | Type | Notes |
|-------|------|-------|
| masterDataTypeId | number | PK |
| typeCode | string | UPPER_UNDERSCORE |
| typeName | string | display name |
| description | string \| null | — |
| isSystem | boolean | **NEW** — drives badge + delete-lock |
| allowMultipleSelection | boolean | **NEW** |
| allowUserInput | boolean | **NEW** |
| isActive | boolean | inherited |
| companyId | number \| null | hidden |

**MasterDataTypeWithCountDto** (NEW — extends ResponseDto):

| Field | Type | Source |
|-------|------|--------|
| (all ResponseDto fields) | … | inherits |
| valuesCount | number | `COUNT(MasterDatas WHERE MasterDataTypeId = X AND !IsDeleted AND IsActive)` |

**MasterDataResponseDto** (after ALIGN):

| Field | Type | Notes |
|-------|------|-------|
| masterDataId | number | PK |
| masterDataTypeId | number | FK |
| dataValue | string | UI labels "Code" |
| dataName | string | UI labels "Display Value" |
| abbreviation | string \| null | **NEW** |
| description | string \| null | (renamed from `dataDescription` on FE — was a typo) |
| sortOrder | number | **alias of `OrderBy` via Mapster** |
| dataSetting | string \| null | JSON blob; FE parses for translations |
| parentMasterDataId | number \| null | not exposed in this UI |
| isSystem | boolean | **NEW** |
| isActive | boolean | inherited |
| companyId | number \| null | hidden |

**ReorderMasterDataRequestDto** (NEW input):

| Field | Type | Notes |
|-------|------|-------|
| masterDataId | number | — |
| orderBy | number | new sort position |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] EF migration created and applies cleanly (`dotnet ef database update`)
- [ ] `pnpm dev` — page loads at `/[lang]/setting/dataconfig/masterdata`
- [ ] `setting/dataconfig/masterdatatype` URL also renders the combined page (FE wiring resolves both routes)
- [ ] `pnpm tsc --noEmit` — no TS errors in masterdata files

**Functional Verification (Full E2E — MANDATORY):**

*Layout & navigation:*
- [ ] ScreenHeader displays "Master Data" with subtitle + 3 actions (+ New Data Type / Import / Export All)
- [ ] Page below header is a 30%/70% split panel; on `<lg` it stacks vertically
- [ ] Left panel header shows "Data Types" + count "{N} types"
- [ ] Search input filters left list client-side by typeName/typeCode

*Left panel (MasterDataType):*
- [ ] Type rows render with icon tile + name + meta `"{N} values"` + System/Custom badge
- [ ] First row auto-selected on page load → right panel populates
- [ ] Click any row → row becomes active (accent bg + left border) → right panel re-fetches and renders
- [ ] System types display amber "🔒 System" badge; custom types display green "Custom" badge

*Right panel header:*
- [ ] Selected type's name + description render
- [ ] Code badge + (if system) "🔒 System type" pill render
- [ ] [+ Add Value] / [Edit Type] / [Export] buttons render
- [ ] Empty state shows when no type is selected

*Right panel grid (MasterData):*
- [ ] 7 columns render: drag | # | Code | Display Value | Abbreviation | Active | Sort Order | Actions
- [ ] Inactive rows display at 50% opacity
- [ ] Drag handle column reorders rows; SortOrder persists across all rows in the type
- [ ] Pen icon opens Value modal in edit mode
- [ ] Ellipsis dropdown shows context-aware actions: Edit / Activate-or-Deactivate / Move Up / Move Down / Delete (only when !isSystem)

*Type modal (Create + Edit):*
- [ ] Fields: typeName, typeCode (uppercase+underscore auto-clean), description, allowMultipleSelection switch, allowUserInput switch
- [ ] Create: Save → new type appears in left list → becomes selected → right panel shows empty state (0 values)
- [ ] Edit on system type: typeCode is readonly with helper text; other fields editable; Save works
- [ ] Edit on custom type: all fields editable; Delete option present in modal footer (or right-panel kebab — design TBD)
- [ ] Delete a custom type with 0 values: confirm → soft-delete → row vanishes from left list
- [ ] Delete a custom type with values: BE returns "N values still exist" toast

*Value modal (Add + Edit):*
- [ ] Fields: dataValue (UPPER+nospaces), dataName, abbreviation, description, isActive switch, sortOrder, translations (Hindi + Arabic with RTL on Arabic)
- [ ] Add: Save → row appears at bottom of right panel with next sortOrder → left-panel valuesCount increments
- [ ] Edit on system value: dataValue (Code) is readonly; other fields editable; Save works
- [ ] Edit on custom value: all fields editable
- [ ] Toggle Activate/Deactivate from row dropdown: isActive flips; row dims; status badge updates
- [ ] Delete a custom value: confirm → soft-delete → row vanishes; valuesCount decrements
- [ ] Delete a system value: option not present in dropdown
- [ ] Move Up / Move Down: SortOrder swaps with adjacent row; grid re-renders
- [ ] Translations: type Hindi text → save → reopen modal → Hindi text persists. Same for Arabic. Stored in `dataSetting` JSON.

*Permissions:*
- [ ] BUSINESSADMIN sees all buttons; other roles respect capability mask via existing `useUserCapabilityCheck` hook
- [ ] Both menu codes (`MASTERDATA` + `MASTERDATATYPE`) gate this page (compound capability check)

*Service placeholders:*
- [ ] `Import` button → toast "Import flow coming soon"
- [ ] `Export All` button → toast "Export flow coming soon"
- [ ] Per-type `Export` button → toast "Type-specific export coming soon"

**DB Seed Verification:**
- [ ] Single visible menu: "Master Data" under Settings → Data Config (MASTERDATA, OrderBy 1)
- [ ] Hidden menu: MASTERDATATYPE seeded (IsLeastMenu=false) so role grants cascade and legacy URL works
- [ ] Both grids seeded: `MASTERDATA` (Form 1 — Value modal) and `MASTERDATATYPE` (Form 2 — Type modal)
- [ ] GridFormSchema renders both modals correctly
- [ ] System types seeded: Salutation, Contact Type, Payment Mode, Donation Category, Communication Channel, Event Type, Document Category, Relationship Type (all `IsSystem=true`)
- [ ] Per-type sample values seeded for at least Salutation (Mr/Mrs/Ms/Dr/Prof/Rev/Sheikh/Haji = 8 rows, IsSystem=true)
- [ ] Custom-type sample seeded: Volunteer Skill, Fundraiser Source, Cancellation Reason, Decline Reason (all `IsSystem=false`)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

### ALIGN-scope caveats

- **Do NOT regenerate** `MasterData.cs`, `MasterDataType.cs`, the EF configurations, or the existing CRUD handlers from a canonical template. Modify in place per §⑧.
- **Do NOT rename existing column names** (`TypeCode`, `TypeName`, `DataValue`, `DataName`, `OrderBy`) — they are referenced by ~30 navigation collections in `MasterData.cs` (every consuming entity FK's into MasterData). A rename would cascade across the entire platform.
- **Keep existing GQL field names** (`getMasterDatas`, `getMasterDataTypes`, `activateDeactivateMasterData`, etc.). The existing FE is already wired to these.

### Backend gotchas

- The repo's group suffix is **`Setting`**, not `Sett`. Namespaces: `SettingModels`, `SettingConfigurations`, `SettingSchemas`, `SettingBusiness`, `EndPoints/Setting`.
- **`MasterData.IsSystem`** column exists on the entity but **is missing from `MasterDataRequestDto`** in current code per the existing schemas file — verify and add if absent (or keep absent for security so admins cannot self-promote).
- **`MasterData.DataSetting`** column is a JSON-shaped string used for icon/color hints elsewhere (e.g., #6 ContactSource Color). Keep its existing shape: store an object with multiple keys. For translations, use `{"translations":{"hi":"…","ar":"…"}}` so existing keys (icon, color, alias) are not clobbered. Translation parser must `JSON.parse` defensively (try/catch) and merge with existing keys on save.
- **Migration write order**: add the 3 new columns, then create the 2 unique indexes, then update existing snapshot. EF migration must regenerate the snapshot file.
- The `MasterData.MasterDataTypeId` FK delete behavior is currently `Restrict` per `MasterDataConfigurations.cs` — **keep this**. Combined with the new "values-exist-delete-block" guard on `DeleteMasterDataType`, the system enforces no orphan values.

### Frontend gotchas

- **TWO routes resolve to ONE component**:
  - `[lang]/setting/dataconfig/masterdata/page.tsx` → `<MasterDataPageConfig />` → `<MasterDataCombinedPage />`
  - `[lang]/setting/dataconfig/masterdatatype/page.tsx` → `<MasterDataTypePageConfig />` → `<MasterDataCombinedPage />`
  - Both page configs share the same combined component but pass DIFFERENT `menuCode` for capability gating. The combined component must render identically regardless of which route loaded it. Pre-select first type either way.
- **No Zustand store**: `selectedTypeId` is local React state in `<MasterDataCombinedPage />`. The split-panel screen does not need cross-route state. Existing `setting-service` Zustand store (if any) should not be expanded for this screen.
- **Layout variant is `widgets-above-grid` semantically** but the inner grid is custom split-panel — NOT canonical Variant A or B. Use `<ScreenHeader>` at page top (Variant B convention) but the body is two flex children, not a single `<DataTableContainer>`.
- **Component reuse-or-create rule** (from feedback memory): before creating `system-badge`, search the existing renderer registries — ContactType #19 may have already created it. If it exists, register the new component imports instead of duplicating. Same for any drag-reorder primitive (`@dnd-kit/sortable` may already be wired by ContactType #19's drag-reorder feature).
- **UI tokens only** (from feedback memory): no hex colors (mockup `#0e7490`, `#6366f1`, `#f97316` are illustrative), no raw px values. Use design-system tokens (`accent`, `success`, `warning`, `info`, spacing tokens). Use `@iconify/react` Phosphor (`ph:`) icons — replace `fa-clipboard-list`, `fa-database`, `fa-lock`, `fa-grip-vertical`, `fa-plus`, `fa-language` with their Phosphor equivalents.
- **Translations RTL**: the Arabic input must be `dir="rtl"` and use a font with Arabic glyph support. Verify the existing input primitive supports `dir` prop.
- **Cleanup orphan duplicates**: 4 `shared/configuration/mastersetup/*` files are old versions of the same screens. Delete (or neutralize to `export {}` if sandbox blocks delete) and flag for `git rm` post-merge.

### Service Dependencies (UI-only — no backend service implementation)

- **⚠ SERVICE_PLACEHOLDER**: `Import` button (page header) — full UI button rendered. Handler shows toast "Import flow coming soon" because no `IFileImportService` exists in the codebase yet.
- **⚠ SERVICE_PLACEHOLDER**: `Export All` button (page header) — full UI button rendered. Handler shows toast because no `IFileExportService` for Master Data exists yet (existing `Export*Query.cs` handlers in MasterDataTypes/MasterDatas folders return empty/stub).
- **⚠ SERVICE_PLACEHOLDER**: per-type `Export` button (right header) — same situation.

Full UI must be built (buttons, modals, interactions). Only the file-IO handler is mocked.

### Data migration / seed audit

- The existing `MasterData` and `MasterDataType` rows in the prod DB likely have `IsSystem` set (from initial seeds), but the new columns (`AllowMultipleSelection`, `AllowUserInput`, `Abbreviation`) will be NULL/false on existing rows after migration. The seed script must:
  1. Run the EF migration first.
  2. Backfill `Abbreviation` for system rows where appropriate (e.g., Salutation: MR=Mr, MRS=Mrs, etc. — use the existing display patterns).
  3. Backfill `AllowMultipleSelection`/`AllowUserInput` to FALSE for all existing rows.
- Idempotent UPDATE statements with `WHERE Abbreviation IS NULL` guards.

### Pre-flagged Known Issues (`ISSUE-1` … `ISSUE-N`) — to track in §⑬

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | MED | Data model | Translations stored in `DataSetting` JSON instead of a dedicated child table or columns. Pros: zero schema cost, no Language master dependency. Cons: cannot index, search, or query Hindi/Arabic values without a JSON path operator. **Mitigation**: defer to a future "i18n Master Data" feature when the platform adds first-class internationalization. |
| ISSUE-2 | LOW | Cross-entity guard | Deleting a MasterData row with downstream references (e.g., a Contact's `SalutationId`) is not blocked. Soft-delete preserves historical references via FK, but the value disappears from dropdowns. **Mitigation**: out of scope for ALIGN; future enhancement could add a `usage-count` projection per row and block delete when count > 0. |
| ISSUE-3 | MED | Sandbox | If sandbox blocks deletion of the 4 duplicate `shared/configuration/mastersetup/*` files, neutralize content to `export {}` and flag for `git rm` post-merge (ContactDashboard #123 ISSUE-15 precedent). |
| ISSUE-4 | LOW | Mockup omission | The mockup does NOT show how to deactivate a whole MasterDataType (toggle on the type itself). The right-panel header has Edit/Export buttons but no Toggle. Recommendation: add toggle to type-modal as an `isActive` switch — confirm with user during UX review. |
| ISSUE-5 | MED | FE field-rename cascade | Renaming `isSystemType` → `isSystem` and `dataDescription` → `description` on the FE side may break other consumers if those types are imported elsewhere. **Mitigation**: grep the codebase for both field names before merging. If consumers exist, schedule a follow-up rename pass. |
| ISSUE-6 | LOW | Mapster alias | The `OrderBy → SortOrder` Mapster alias must be configured carefully — Mapster bidirectional maps may need explicit `.Map(dst => dst.OrderBy, src => src.SortOrder)` on the request side. Verify round-trip Create/Update flow preserves the field. |
| ISSUE-7 | MED | Default selection on empty list | If a tenant has zero MasterDataTypes (fresh install before seed), the left panel is empty and the right panel must gracefully show empty state. Verify the seed runs before first access OR FE handles `selectedTypeId === null` case. |
| ISSUE-8 | LOW | Drag-reorder primitive | If `@dnd-kit/sortable` is not already wired by ContactType #19 or another screen, this build session must add it as a dependency. Check `package.json` first. |
| ISSUE-9 | LOW | TranslationsWidget RJSF binding | RJSF's default object widget renders a generic accordion. Custom `TranslationsWidget` must intercept the `dataSetting` field shape (string JSON ↔ object) at submit/load time. Pattern: create a `widgets/dgf-widgets/translations-widget.tsx` and register in `dgf-widgets/index.ts`. ContactSource #122's `IconPickerWidget` is the precedent. |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Plan 2026-05-10 | MED | Data model | Translations stored in `DataSetting` JSON instead of dedicated structure | OPEN |
| ISSUE-2 | Plan 2026-05-10 | LOW | Cross-entity guard | Delete does not block on downstream-entity references | OPEN |
| ISSUE-3 | Plan 2026-05-10 | MED | Sandbox | Sandbox may block delete of 4 duplicate shared files | OPEN |
| ISSUE-4 | Plan 2026-05-10 | LOW | Mockup gap | No toggle for whole MasterDataType in mockup | OPEN |
| ISSUE-5 | Plan 2026-05-10 | MED | FE rename cascade | `isSystemType`→`isSystem`, `dataDescription`→`description` may break consumers | OPEN |
| ISSUE-6 | Plan 2026-05-10 | LOW | Mapster alias | `OrderBy ↔ SortOrder` round-trip needs explicit bidirectional config | OPEN |
| ISSUE-7 | Plan 2026-05-10 | MED | Empty state | Fresh tenant with 0 types — verify seed runs first AND FE handles null case | OPEN |
| ISSUE-8 | Plan 2026-05-10 | LOW | DnD dependency | `@dnd-kit/sortable` may need to be added if not already in package.json | OPEN |
| ISSUE-9 | Plan 2026-05-10 | LOW | RJSF widget | TranslationsWidget needs JSON ↔ object bridging | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No build sessions recorded yet — filled in after /build-screen completes.}
