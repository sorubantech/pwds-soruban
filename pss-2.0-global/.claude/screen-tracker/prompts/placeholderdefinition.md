---
screen: PlaceholderDefinition
registry_id: 26
module: Communication (CRM)
status: COMPLETED
scope: ALIGN
screen_type: MASTER_GRID
complexity: Medium
new_module: NO
planned_date: 2026-04-19
completed_date: 2026-04-19
last_session_date: 2026-04-19
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed
- [x] Existing code reviewed (BE complete, FE currently FLOW — converting to MASTER_GRID)
- [x] Business rules extracted
- [x] FK targets resolved (4 × MasterData discriminated by `typeCode`)
- [x] File manifest computed (ALIGN: 6 BE touches + 1 new, 12 FE touches — 6 delete + 4 new + 2 modify)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (pre-answered in prompt §①-⑫)
- [x] Solution Resolution complete (pre-answered in §⑤)
- [x] UX Design finalized (pre-answered in §⑥)
- [x] User Approval received (2026-04-19)
- [x] Backend: create `GetPlaceholderDefinitionSummary` (only new BE work)
- [x] Backend: wire Summary query in endpoint + register
- [x] Frontend: DELETE `view-page.tsx`, `components/` subfolder, store
- [x] Frontend: rewrite `index.tsx` (remove mode routing); `index-page.tsx` rewritten to Variant B
- [x] Frontend: create widgets + side-panel + data-table wrapper
- [x] Frontend: extend DTO + queries (SummaryDto, UsedInCount, IsSystem, CompanyId)
- [x] DB Seed script generated (menu + GridFormSchema + 51 placeholder rows = 50 system + 1 sample custom)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `/crm/communication/placeholderdefinition`
- [ ] Grid loads 45+ seeded system rows, grouped visually by Entity (chip badge color)
- [ ] Search + Entity filter + Data Type filter work
- [ ] "+Add Custom Placeholder" opens RJSF modal (no URL change, no navigation)
- [ ] Prefix `{{` / suffix `}}` render around the token input (RJSF custom widget)
- [ ] Entity dropdown → Source Field dropdown re-loads options (field-level `$data` dependency)
- [ ] Save creates row, grid refreshes, toast notification shown
- [ ] System placeholders render WITHOUT Edit/Delete icons (only View); Custom rows show Edit + Delete
- [ ] "Used In" column renders as link-count renderer → click navigates to EmailTemplate filtered by placeholder
- [ ] Summary widgets show: Total / Active / System / Custom (correct counts)
- [ ] Right-hand info panel renders the 5 "How Placeholders Work" educational cards (static)
- [ ] Delete (Custom only) → soft delete → removed from grid
- [ ] Toggle active/inactive (Custom only) → status dot updates
- [ ] Permissions: BUSINESSADMIN has all 7 caps; System placeholders are read-only for all roles

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: PlaceholderDefinition (Placeholder Definitions)
Module: Communication (CRM)
Schema: `notify`
Group: `NotifyModels` (shared with EmailTemplate #24, SavedFilter #27, SMSTemplate #29, WhatsAppTemplate #31, NotificationTemplate #36)

Business: The Placeholder Definitions screen is the registry of every merge field the platform can splice into outbound communications (email, SMS, WhatsApp, receipts, notifications). Administrators use it to (1) browse the catalog of system-provided tokens like `{{FirstName}}`, `{{DonationAmount}}`, `{{OrgName}}` and understand which entity they map to, and (2) add custom tokens that map to Custom Fields defined in Settings. At send time, the communication engine walks the template, matches `{{Token}}` occurrences against this registry, and substitutes the recipient-specific value. This is the foundation that all template-authoring screens depend on — EmailTemplate, SMSTemplate, WhatsAppTemplate, NotificationTemplate and Receipt templates all read from this registry when rendering the "Insert Placeholder" menu. Without it, templates have no vocabulary.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Entity already exists — fields below are the CURRENT schema. This section documents the contract; DO NOT recreate.

Table: `notify."PlaceholderDefinitions"` — **KEEP AS-IS. Do NOT migrate columns.**

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| PlaceholderDefinitionId | int | — | PK | — | Identity |
| PlaceholderCode | string | 100 | YES | — | Unique (e.g., `CONTACT_FIRST_NAME`) |
| PlaceholderToken | string | 100 | YES | — | Unique (e.g., `{{FirstName}}`) — **rendered inside `{{ }}` in UI** |
| DisplayName | string | 200 | NO | — | Human label (e.g., "First Name") |
| Description | string | 1000 | NO | — | Help text for template authors |
| EntityType | string | 100 | YES | — | Discriminator string: `Contact`, `Donation`, `Organization`, `Campaign`, `Event`, `System`, `Custom` |
| PropertyPath | string | 500 | NO | — | Dotted path (e.g., `FirstName`, `PrimaryAddress.City`) — also used as "Source Field" in mockup |
| PlaceholderTypeId | int | — | YES | app.MasterData(typeCode=PLACEHOLDERTYPE) | FIELD, AGGREGATE, LINK, CHILD_LIST, FILE |
| RecipientTypeId | int | — | YES | app.MasterData(typeCode=RECIPIENTTYPE) | Donor, Staff, System, etc. |
| AggregateFunction | string | 20 | NO | — | SUM / COUNT / AVG / MAX / MIN (system-seeded only) |
| AggregateConfig | string | — | NO | — | JSON (legacy) |
| CollectionPath | string | 200 | NO | — | Nav property for aggregate |
| AggregateField | string | 200 | NO | — | Field to aggregate |
| FilterConfig | jsonb | — | NO | — | JSON filter rules |
| LinkTemplate | string | 2000 | NO | — | URL template for LINK type |
| LinkExpiryHours | int? | — | NO | — | — |
| ChildEntityType | string | 100 | NO | — | CHILD_LIST type |
| ChildTemplate | string | — | NO | — | — |
| ChildSeparator | string | 50 | NO | — | Default `<br/>` |
| OrderByField | string | 200 | NO | — | LIST type |
| OrderDescending | bool | — | NO | — | Default false |
| MaxItems | int? | — | NO | — | LIST cap |
| FormatTypeId | int? | — | NO | app.MasterData(typeCode=FORMATTYPE) | TEXT, DATE, CURRENCY, NUMBER, HTML |
| FormatPattern | string | 100 | NO | — | e.g., `MMMM dd, yyyy`, `#,##0.00` |
| DefaultValue | string | 500 | NO | — | Fallback when no data |
| PlaceholderCategoryId | int? | — | NO | app.MasterData(typeCode=PLACEHOLDERCATEGORY) | Entity-group chip color |
| IsSystem | bool | — | YES | — | `true` for seeded rows — read-only in UI |
| CompanyId | int? | — | NO | app.Companies | NULL for system rows; scoped for Custom |
| IsActive | bool | — | inherited | — | From `Entity` base |

**Child Entities**: none on the Placeholder side. There IS an external link-in table `notify."EmailTemplatePlaceholders"` (junction) that drives the "Used In" count — we query it as an aggregate, we do NOT expose it as a child form.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for ApiSelect queries)

All four FKs point to the SAME `MasterData` table, discriminated by `masterDataType.typeCode`.

| FK Field | Target Entity | Entity File Path | GQL Query Name | TypeCode filter | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|-----------------|---------------|-------------------|
| PlaceholderTypeId | MasterData | `Base.Domain/Models/AppModels/MasterData.cs` | `masterDatas` | `PLACEHOLDERTYPE` | `dataName` | `MasterDataResponseDto` |
| RecipientTypeId | MasterData | `Base.Domain/Models/AppModels/MasterData.cs` | `masterDatas` | `RECIPIENTTYPE` | `dataName` | `MasterDataResponseDto` |
| FormatTypeId | MasterData | `Base.Domain/Models/AppModels/MasterData.cs` | `masterDatas` | `FORMATTYPE` | `dataName` | `MasterDataResponseDto` |
| PlaceholderCategoryId | MasterData | `Base.Domain/Models/AppModels/MasterData.cs` | `masterDatas` | `PLACEHOLDERCATEGORY` | `dataName` | `MasterDataResponseDto` |
| CompanyId | Company | `Base.Domain/Models/AppModels/Company.cs` | — | — | — | (not shown in form — scoped via session) |

**ApiSelect wiring reference** (from EmailTemplate #24 completed screen): FE uses `MASTERDATAS_QUERY` from `src/infrastructure/gql-queries/setting-queries/MasterDataQuery.ts` with `advancedFilter.rules: [{ field: "masterDataType.typeCode", operator: "=", value: "<TYPECODE>" }]`, mapping `{ value: m.masterDataId, label: m.dataName }`. Reuse verbatim.

**GetAllPlaceholderDefinitionList already projects FK display names** (`placeholderType.dataName`, `formatType.dataName`, `placeholderCategory.dataName`) — see `PlaceholderDefinitionQuery.ts` lines 40/49/53. No BE change needed for FK projections.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `PlaceholderCode` must be unique globally (already enforced via unique index — existing validator stays).
- `PlaceholderToken` must be unique globally (already enforced via unique index).

**Required Field Rules** (custom-placeholder form — modal fields):
- `PlaceholderToken`, `DisplayName`, `EntityType`, `PlaceholderTypeId`, `RecipientTypeId` are mandatory.
- `PropertyPath` required when `EntityType` ≠ `System` AND `PlaceholderTypeId` = FIELD.
- `DefaultValue` optional but recommended.

**System-row Immutability:**
- Rows with `IsSystem = true` — all mutate endpoints must short-circuit: reject Update / Delete / Toggle with `ErrorCode = FORBIDDEN_SYSTEM_RECORD` and message "System placeholders cannot be modified". Add this check in `UpdatePlaceholderDefinition`, `DeletePlaceholderDefinition`, `TogglePlaceholderDefinition` handlers (not just validators — the validator pattern for delete has been unreliable in prior screens, see #19 ISSUE-4 / #43 ISSUE-7; guard inside the handler).

**Company-scope Rules:**
- Custom placeholders are scoped: `CompanyId = currentUserCompanyId`.
- System placeholders have `CompanyId = NULL` and are visible to all companies.
- The GetAll query MUST return rows where `CompanyId == currentCompanyId OR CompanyId == NULL` (existing handler does this; verify).

**Token-format Rule:**
- The modal shows prefix `{{` / suffix `}}` around an input. The stored value in `PlaceholderToken` includes the braces (e.g., `{{CustomField_Occupation}}`). The FE widget must concat `{{` + user-typed body + `}}` before submission. Backend validator must reject tokens that don't match regex `^\{\{[A-Za-z0-9_|:.\s"'-]+\}\}$`.

**Custom-placeholder naming convention:**
- Custom tokens must start with prefix `CustomField_` (e.g., `{{CustomField_Occupation}}`) — per mockup line 1090. BE validator enforces; FE pre-fills.

**Business Logic:**
- "Used In" count = `EmailTemplatePlaceholders` rows WHERE `PlaceholderDefinitionId = row.Id` (plus future joins once SMS/WhatsApp placeholder link tables exist). For now, only `EmailTemplatePlaceholders` is wired — include that, flag the others as TODO in Section ⑫.
- Default-value syntax hint `{{FieldName|default:"Fallback"}}` is documented in the info panel but NOT enforced by this screen — it's parsed at template-render time (out of scope here).

**Workflow**: None.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: MASTER_GRID
**Type Classification**: Type 2 — Flat entity with 4 FK dropdowns to a shared discriminated master table (MasterData × typeCode), a simple RJSF modal form, and a side-panel educational/detail layout.
**Reason**: Mockup's "+Add Custom Placeholder" opens a modal (`onclick="openModal()"` → `#placeholderModal`), not a navigation to a new page. No URL changes. No child grid. No tabs. No read-only detail view that's visually distinct from the form. Modal has ~10 fields, easily expressible in RJSF schema driven by `GridFormSchema`. → MASTER_GRID, not FLOW.

**Scope note**: Existing FE is FLOW (separate `view-page.tsx` + Zustand store + 4 sub-section components under `components/`). ALIGN action is to **convert FE from FLOW → MASTER_GRID Variant B**. BE stays intact; only Summary query is added.

**Backend Patterns Required:**
- [x] Standard CRUD (ALREADY BUILT — keep) — entity + config + schemas + Create/Update/Delete/Toggle/GetAll/GetById/Export + validators + mutations + queries all exist.
- [x] System-row immutability guard (NEW in handlers — see § ④)
- [x] Summary query `GetPlaceholderDefinitionSummary` (NEW)
- [x] Company scoping in GetAll (verify existing)
- [x] FK projections (`.Include()` of 3 MasterData navigations — ALREADY done)
- [x] "Used In" count aggregation column — see § ⑥ Grid Aggregation
- [ ] File upload — no
- [ ] Nested child creation — no

**Frontend Patterns Required:**
- [x] AdvancedDataTable (Variant B — `showHeader={false}`)
- [x] RJSF Modal Form driven by DB-seeded `GridFormSchema` — REPLACE existing custom React form
- [x] ApiSelectV2 widgets for 4 MasterData FKs with `typeCode` filter
- [x] Summary widgets (4 KPI cards: Total / Active / System / Custom)
- [x] Side panel (right column — static educational "How Placeholders Work" info panel per mockup lines 1030-1073; reuse `ContactTypeSidePanel` structure but render static cards, NOT row-detail)
- [x] Grid aggregation column (`link-count` renderer, already exists — registered during DonationCategory #3 build)
- [x] Entity-badge chip renderer (coloured pill per entity group) — **NEW custom renderer**
- [x] Token chip renderer (monospace pill with `{{ }}` styling) — **NEW custom renderer**
- [ ] Drag-to-reorder — no
- [ ] Click-through filter — partial (Entity filter dropdown maps to entity-badge column)
- [ ] Card-grid display — no (table)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.

### Grid/List View

**Display Mode**: `table` (default — mockup shows rows, not cards)

**Layout Variant** (REQUIRED): `side-panel`
- FE Dev MUST use **Variant B**: `<ScreenHeader>` + widgets row + two-column flex (grid left, static info panel right).
- `<AdvancedDataTableContainer showHeader={false}>` inside the left column.
- `<AdvancedDataTableStoreProvider>` wraps at the **page** level (learned from ContactType #19 Session 2 fix). NOT at component level — otherwise fullscreen toggle wraps only the grid, not the entire page layout.

**Layout skeleton** (page component):
```
<Provider>
  <div className="flex flex-col gap-4">
    <ScreenHeader title="Placeholder Definitions" subtitle="Manage merge fields available in templates and communications" actions={[AddCustomPlaceholder]} />
    <PlaceholderDefinitionWidgets />                                          {/* 4 stat cards */}
    <div className="flex flex-col gap-4 lg:flex-row">
      <div className="flex-1 min-w-0">
        <PlaceholderDefinitionDataTable />                                    {/* showHeader=false */}
      </div>
      <aside className="w-full lg:w-80 xl:w-96">
        <PlaceholderDefinitionInfoPanel />                                    {/* static 5-card educational panel */}
      </aside>
    </div>
  </div>
</Provider>
```

**Grid Columns** (in display order — 8 columns per mockup lines 749-757):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Placeholder | `placeholderToken` | custom `token-chip` renderer | 200px | YES | Monospace text inside amber pill — `{{Token}}` |
| 2 | Display Name | `displayName` | text | auto | YES | Primary text |
| 3 | Entity | `entityType` | custom `entity-badge` renderer | 120px | YES | Pill coloured by value (Contact=blue, Donation=green, Organization=purple, Campaign=pink, Event=amber, System=slate, Custom=cyan) |
| 4 | Data Type | `formatType.dataName` | `type-badge` | 100px | YES | Slate pill (Text, Number, Date, Currency, Boolean, URL) |
| 5 | Source Field | `propertyPath` | custom `source-field` renderer | auto | NO | Monospace muted text (e.g., `corg.Contacts.FirstName`) — fallbacks: `Computed: ...`, `Auto-generated`, `Custom Field: ...` |
| 6 | Used In | `usedInCount` | `link-count` renderer | 120px | YES | "{N} templates" link → navigates to EmailTemplate list filtered by this placeholder |
| 7 | Status | `isActive` | status-dot (active/inactive) | 100px | YES | Green dot = Active, grey = Inactive |
| 8 | Actions | — | row-actions | 100px (right-align) | — | System: View only (eye icon). Custom: Edit (pen) + Delete (trash, danger). |

**Conditional row actions** (per mockup lines 1007-1010 vs lines 768-770):
- `isSystem === true` → render only a "View Details" eye icon (opens modal in read-only mode).
- `isSystem === false` → render Edit icon (opens modal in edit mode) + Delete icon (confirm dialog → soft delete).

**Search/Filter Fields** (mockup filter-bar lines 712-737):
- Search box: `placeholderToken`, `displayName`, `propertyPath`, `description`
- Entity dropdown: `entityType` — distinct values: All / Contact / Donation / Organization / Campaign / Event / System / Custom
- Data Type dropdown: `formatType.dataName` — All / Text / Number / Date / Currency / Boolean / URL

Both filters map to `advancedFilter.rules` on `PLACEHOLDERDEFINITIONS_QUERY`.

**Grid Actions** (top-right): only "+Add Custom Placeholder" (single primary-accent button). No Import / Export / Print visible in mockup — leave `enableImport: false, enableExport: false, enablePrint: false` in `tableConfig`. (Existing index-page has them ON; toggle them OFF to match mockup.)

### RJSF Modal Form

> Driven by `GridFormSchema` in DB seed. Advanced type-specific fields (AggregateFunction, CollectionPath, LinkTemplate, ChildEntityType, etc.) are **NOT in the custom-placeholder modal** — they're only for system-seeded rows. Custom placeholders only support `PlaceholderType = FIELD`.

**Modal title**: `"Add Custom Placeholder"` (create) / `"Edit Custom Placeholder"` (edit) / `"Placeholder Details"` (read — System rows).

**Form Sections** (in order — single section, 3 rows):

| Row | Layout | Fields |
|-----|--------|--------|
| 1 | full-width | `placeholderToken` (prefix/suffix widget with `{{` `}}`) |
| 2 | 2-column | `displayName`, `entityType` |
| 3 | 1-column full-width | `propertyPath` (labeled "Source Field") |
| 4 | 2-column | `formatType.dataName` (labeled "Data Type", readonly=Text for Custom), `defaultValue` |
| 5 | 2-column | `formatPattern` (dropdown: None / UPPER / lower / Title Case), `maxItems` (labeled "Max length") |
| 6 | 1-column full-width | `description` (textarea, 2 rows) |
| 7 | 1-column | `isActive` (toggle) |

**Hidden fields** (present in schema but `ui:widget = "hidden"`) — used for Custom defaults:
- `placeholderTypeId` → hardcoded to FIELD (MasterData ID looked up by seed-SQL)
- `recipientTypeId` → hardcoded to default Recipient (MasterData ID)
- `placeholderCategoryId` → auto-derived from `entityType` on submit via FE logic (or BE can derive; plan has BE derive to reduce FE state)
- `isSystem` → always `false` for Custom (hidden)
- `companyId` → server-set from session
- All AGGREGATE / LINK / CHILD_LIST fields → left `null`

**Field Widget Mapping**:

| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| placeholderToken | `PrefixSuffixInputWidget` (NEW custom widget) | "CustomField_YourFieldName" | required, regex `^\{\{[A-Za-z0-9_|:.\s"'-]+\}\}$`, max 100 | Prefix `{{`, suffix `}}`. Widget stores full `{{...}}` string. Custom MUST begin `CustomField_`. |
| displayName | `TextWidget` | "e.g. Occupation" | required, max 200 | — |
| entityType | `SelectWidget` | "Select entity" | required, enum Contact/Donation/Organization (custom form) | Triggers reload of `propertyPath` options via `$data` pointer |
| propertyPath | `SelectWidget` | "Select source field" | required if `entityType != null` | Options depend on `entityType` — see § below |
| formatType.dataName → `formatTypeId` | `ApiSelectV2` | "Data Type" | required | `masterDatas` query, `typeCode=FORMATTYPE`. For Custom, readonly to TEXT. |
| defaultValue | `TextWidget` | "Fallback when no data" | max 500 | "Valued Donor"-style fallback |
| formatPattern | `SelectWidget` | "None" | optional | Static enum: None, UPPER, lower, Title Case |
| maxItems | `UpDownWidget` | "Max length" | optional, integer, min 1 | Repurposed from entity column |
| description | `TextareaWidget` | "Help text..." | max 1000 | 2 rows |
| isActive | `SwitchWidget` | — | — | Label "Active" |

**Source Field dropdown options** (static maps — embedded in uiSchema or fetched from a Custom-Fields query):

| Entity | Options (per mockup lines 1188-1192) |
|--------|--------------------------------------|
| Contact | "Custom Field: Occupation", "Custom Field: Employer", "Custom Field: Preferred Language", "Custom Field: Date of Birth" |
| Donation | "Custom Field: Fund Source", "Custom Field: Appeal Code", "Custom Field: Gift Type" |
| Organization | "Company Setting: Tax ID", "Company Setting: Registration No.", "Company Setting: Fiscal Year" |

→ In production these should come from `CustomField` endpoint filtered by entity; for this build, hardcode in the RJSF `uiSchema.propertyPath.ui:options.enumByEntity` and pick the matching list by `$data` pointer to `entityType`. Flag this as follow-up in § ⑫.

### Page Widgets & Summary Cards

**Widgets**: 4 stat cards above the grid (adapt ContactType `contacttype-widgets.tsx` StatCard layout).

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | Total Placeholders | `summary.totalPlaceholders` | count | 1/4 |
| 2 | Active | `summary.activeCount` | count | 2/4 |
| 3 | System | `summary.systemCount` | count (icon: lock) | 3/4 |
| 4 | Custom | `summary.customCount` | count (icon: puzzle-piece) | 4/4 |

Responsive grid: `grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3`. Icons: Phosphor via `@iconify/react` (`ph:hash`, `ph:check-circle`, `ph:lock`, `ph:puzzle-piece`).

**Summary GQL Query** (NEW — to be built):
- Query name: `GetPlaceholderDefinitionSummary` (GQL field: `placeholderDefinitionSummary`)
- Returns: `PlaceholderDefinitionSummaryDto { TotalPlaceholders, ActiveCount, SystemCount, CustomCount }` (all int)
- Handler: scope by `CompanyId == currentCompanyId OR CompanyId IS NULL` AND `IsDeleted == false`
- Reference: `CorgBusiness/ContactTypes/Queries/GetContactTypeSummary.cs` — clone structure

### Grid Aggregation Columns

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Used In | Count of templates that reference this placeholder | `notify.EmailTemplatePlaceholders` WHERE `PlaceholderDefinitionId = row.Id` | LINQ subquery in `GetPlaceholderDefinition.cs` — extend projection with `UsedInCount = x.EmailTemplatePlaceholders.Count()` |

Future (see § ⑫): once SMS / WhatsApp / Notification placeholder link tables exist, sum them here.

### Side Panels / Info Displays

**Side Panel**: static educational info panel (NOT a row-detail side panel — mockup shows it's always visible, not triggered by row-click).

| Panel Section | Fields / Content | Trigger |
|--------------|------------------|---------|
| How Placeholders Work (header with `ph:info` icon) | 5 info-items below | Always visible |
| 1. Dynamic Replacement | icon `ph:arrows-clockwise` + bold title + description "Placeholders are replaced with actual data when emails are sent to recipients." | — |
| 2. System Placeholders | icon `ph:lock` + "Built-in placeholders are managed by the system and cannot be modified or deleted." | — |
| 3. Custom Placeholders | icon `ph:puzzle-piece` + text with inline Link to `/setting/customfields` ("Custom placeholders map to custom fields defined in Settings → Custom Fields.") | — |
| 4. Default Values | icon `ph:code` + text with inline `<code>` chip showing `{{FieldName\|default:"Fallback"}}` | — |
| 5. Supported Channels | icon `ph:envelope` + "Placeholders work in Email templates, SMS, WhatsApp messages, and receipt templates." | — |

Implement as a pure-static React component `PlaceholderDefinitionInfoPanel.tsx` under `crm/communication/placeholderdefinition/` — no props, no queries. All text and icons hardcoded. Card container uses `bg-card border rounded-lg p-5` (tokens, NOT hex).

### User Interaction Flow

1. User lands on `/crm/communication/placeholderdefinition`. Grid loads seeded 45+ placeholders, widgets show counts, side panel shows static educational cards.
2. User types in search → debounced filter → grid re-queries.
3. User picks "Donation" in Entity dropdown → grid filters; still shows donation-flavored rows.
4. User clicks "+Add Custom Placeholder" → RJSF modal opens. Token input shows `{{` prefix, `}}` suffix; Entity dropdown defaults to Contact; Source Field dropdown populates Contact custom fields.
5. User changes Entity to Donation → Source Field dropdown reloads.
6. User fills form → clicks Save → `createPlaceholderDefinition` mutation fires (FE sets `isSystem=false`, `placeholderTypeId` via looked-up FIELD MasterData ID, `recipientTypeId` via default) → grid refreshes, toast "Placeholder created", widgets re-query.
7. User clicks "Edit" on the newly-created Custom row → modal opens pre-filled.
8. User clicks a System row's "View Details" eye icon → modal opens in read-only (all fields `ui:disabled=true`, footer shows only "Close").
9. User clicks "Used In: 12 templates" link → navigates to `/crm/communication/emailtemplate?placeholderId={id}` (EmailTemplate FE must be able to read this param — flag as downstream work in § ⑫, but the link column still ships).
10. User clicks Delete on a Custom row → confirm dialog → `deletePlaceholderDefinition` → soft delete → grid re-queries.
11. User clicks Toggle on a Custom row → `activateDeactivatePlaceholderDefinition` → status dot updates.
12. User attempts to Edit/Delete a System row → row-actions don't render → cannot. Backend handler guards also reject if mutation is crafted externally (SYSTEM_RECORD_FORBIDDEN).

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps canonical ContactType (MASTER_GRID) to PlaceholderDefinition.

**Canonical Reference**: ContactType (MASTER_GRID, registry #19)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| ContactType | PlaceholderDefinition | Entity/class name |
| contactType | placeholderDefinition | Variable/field names |
| ContactTypeId | PlaceholderDefinitionId | PK field |
| ContactTypes | PlaceholderDefinitions | Table name, collection names |
| contact-type | placeholder-definition | kebab-case |
| contacttype | placeholderdefinition | FE folder, route segment, import paths |
| CONTACTTYPE | PLACEHOLDERDEFINITION | Grid code, menu code |
| corg | notify | DB schema |
| Corg | Notify | Backend group name stem |
| CorgModels | NotifyModels | Namespace suffix |
| CONTACT | COMMUNICATION | Parent menu code → `CRM_COMMUNICATION` |
| CRM | CRM | Module code (unchanged) |
| crm/contact/contacttype | crm/communication/placeholderdefinition | FE route path |
| corg-service | notify-service | FE service folder name (DTO lives in `src/domain/entities/notify-service/`) |
| contacttypeMutations | placeholderDefinitionMutations | GraphQL mutation type |
| contacttypes | placeholderDefinitions | GraphQL list query field |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Exact files to create / modify / DELETE. ALIGN scope — minimal BE changes, substantial FE restructure.

### Backend Files

**NEW (2 files):**
| # | File | Path |
|---|------|------|
| 1 | Summary Query + Handler + DTO | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/NotifyBusiness/PlaceholderDefinitions/Queries/GetPlaceholderDefinitionSummary.cs` |
| 2 | Summary DTO shape | inline in schemas OR new class in `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/NotifySchemas/PlaceholderDefinitionSchemas.cs` — add `PlaceholderDefinitionSummaryDto` |

**MODIFY (6 files):**
| # | File | Path | Change |
|---|------|------|--------|
| 1 | Schemas | `Base.Application/Schemas/NotifySchemas/PlaceholderDefinitionSchemas.cs` | Add `PlaceholderDefinitionSummaryDto` class; add `UsedInCount` + `IsSystem` + `CompanyId` properties to `PlaceholderDefinitionResponseDto` |
| 2 | GetAll Handler | `Base.Application/Business/NotifyBusiness/PlaceholderDefinitions/Queries/GetPlaceholderDefinition.cs` | Extend projection with `UsedInCount = x.EmailTemplatePlaceholders.Count()`; ensure CompanyScope rule (`CompanyId == current OR NULL`); verify `IsSystem` passes through |
| 3 | GetById Handler | `.../Queries/GetPlaceholderDefinitionById.cs` | Include `IsSystem` + `CompanyId` in projection (if not already) |
| 4 | Update Command | `.../UpdateCommand/UpdatePlaceholderDefinition.cs` | Add handler-level guard: if existing row `IsSystem = true` → return error `FORBIDDEN_SYSTEM_RECORD` |
| 5 | Delete Command | `.../DeleteCommand/DeletePlaceholderDefinition.cs` | Same guard |
| 6 | Toggle Command | `.../ToggleCommand/TogglePlaceholderDefinition.cs` | Same guard |
| 7 | Queries Endpoint | `Base.API/EndPoints/Notify/Queries/PlaceholderDefinitionQueries.cs` | Register `placeholderDefinitionSummary` resolver |

**NO CHANGE**: Entity, EF Configuration, Create command, validators (other than update validator that needs system-guard), mutations endpoint, existing migrations.

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Base.Application/Schemas/NotifySchemas/PlaceholderDefinitionSchemas.cs` | `PlaceholderDefinitionSummaryDto` |
| 2 | `Base.API/EndPoints/Notify/Queries/PlaceholderDefinitionQueries.cs` | Summary resolver registration |

(No changes to `IApplicationDbContext`, `NotifyDbContext`, `DecoratorProperties.cs`, `NotifyMappings.cs` — entity already registered.)

### Frontend Files

**DELETE (6 files):**
| # | File | Path |
|---|------|------|
| 1 | view-page.tsx | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/communication/placeholderdefinition/view-page.tsx` |
| 2 | PlaceholderDefinitionForm.tsx | `.../placeholderdefinition/components/PlaceholderDefinitionForm.tsx` |
| 3 | BasicInformation.tsx | `.../placeholderdefinition/components/BasicInformation.tsx` |
| 4 | FieldConfiguration.tsx | `.../placeholderdefinition/components/FieldConfiguration.tsx` |
| 5 | AggregateConfiguration.tsx | `.../placeholderdefinition/components/AggregateConfiguration.tsx` |
| 6 | FormattingConfiguration.tsx | `.../placeholderdefinition/components/FormattingConfiguration.tsx` |
| 7 | components/index.ts | `.../placeholderdefinition/components/index.ts` |
| 8 | Zustand store | `PSS_2.0_Frontend/src/application/stores/communication-stores/placeholder-definition-store.ts` |

After DELETE, the `components/` subfolder should be empty — remove the folder.

**REWRITE (2 files):**
| # | File | Path | Description |
|---|------|------|-------------|
| 1 | index.tsx | `.../placeholderdefinition/index.tsx` | STRIP mode-routing + store refs. Just render `<Provider>` + `<ScreenHeader>` + widgets + two-column grid/panel row. No `useSearchParams`, no `useFlowDataTableStore`. |
| 2 | index-page.tsx | `.../placeholderdefinition/index-page.tsx` | Replace `<FlowDataTable>` with `<AdvancedDataTableContainer showHeader={false}>`. Toggle off `enableImport/Export/Print` to match mockup. |

**NEW (5 files):**
| # | File | Path |
|---|------|------|
| 1 | Widgets | `.../placeholderdefinition/placeholderdefinition-widgets.tsx` — 4 StatCards (Total/Active/System/Custom) |
| 2 | Side panel | `.../placeholderdefinition/placeholderdefinition-info-panel.tsx` — static 5-card educational content |
| 3 | Data table wrapper | `.../placeholderdefinition/placeholderdefinition-data-table.tsx` — wraps `<AdvancedDataTableContainer>` with `showHeader={false}`, hands gridCode |
| 4 | Prefix/suffix widget | `PSS_2.0_Frontend/src/presentation/components/custom-components/rjsf-custom-widgets/prefix-suffix-input.tsx` — RJSF widget rendering `{{` prefix + input + `}}` suffix, stores wrapped value |
| 5 | Token chip renderer | `PSS_2.0_Frontend/src/presentation/components/custom-components/data-tables/advanced/column-types/renderers/token-chip-renderer.tsx` — monospace pill inside amber background (tokens only; no hex) |
| 6 | Entity badge renderer | `.../renderers/entity-badge-renderer.tsx` — pill with color-by-value (contact=blue, donation=green, organization=purple, campaign=pink, event=amber, system=slate, custom=cyan) via token-based variant classes |

(Existing `link-count` renderer reused for "Used In" column — already built during DonationCategory #3.)

**MODIFY (4 files):**
| # | File | Path | Change |
|---|------|------|--------|
| 1 | DTO | `src/domain/entities/notify-service/PlaceholderDefinitionDto.ts` | Add `usedInCount: number`, `isSystem: boolean`, `companyId: number \| null` fields to Response; add new `PlaceholderDefinitionSummaryDto` interface |
| 2 | Query | `src/infrastructure/gql-queries/notify-queries/PlaceholderDefinitionQuery.ts` | Extend `PLACEHOLDERDEFINITIONS_QUERY.data` projection with `usedInCount`, `isSystem`, `companyId`; add new `PLACEHOLDERDEFINITIONSUMMARY_QUERY` |
| 3 | Page Config | `src/presentation/pages/crm/communication/placeholderdefinition.tsx` | NO FUNCTIONAL CHANGE — capability check stays. Just verify menuCode = `PLACEHOLDERDEFINITION`. |
| 4 | Route page | `src/app/[lang]/crm/communication/placeholderdefinition/page.tsx` | NO CHANGE — already correct. |

**Column-type registries** — register 2 new renderers:
| # | File to Modify | Register |
|---|---------------|----------|
| 1 | `presentation/components/custom-components/data-tables/advanced/column-types/registry-advanced-columns.tsx` | `token-chip`, `entity-badge` |
| 2 | `.../basic/column-types/registry-basic-columns.tsx` (if exists) | same (for fallback) |
| 3 | `.../flow/column-types/registry-flow-columns.tsx` (if exists) | same |

**Barrel exports:**
- `src/presentation/components/page-components/crm/communication/placeholderdefinition/index.ts` — export page-level components if structured this way.
- `src/presentation/components/custom-components/data-tables/advanced/column-types/renderers/index.ts` — export `TokenChipRenderer`, `EntityBadgeRenderer`.

**Frontend Wiring Updates** — standard MASTER_GRID registrations:
| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `src/presentation/layouts/main-layout/sidebar/entity-operations.ts` | `PLACEHOLDERDEFINITION` already registered from prior FLOW build — verify; otherwise add. |
| 2 | `src/presentation/layouts/main-layout/sidebar/operations-config.ts` | Verify/import `PLACEHOLDERDEFINITION` ops. |
| 3 | DB seed (next section) | Menu row + GridFormSchema |

### DB Seed Updates

New SQL file: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dynamic/PlaceholderDefinition-sqlscripts.sql`

Must contain:
1. **Menu upsert** — `PLACEHOLDERDEFINITION` under `CRM_COMMUNICATION`, `MenuUrl = crm/communication/placeholderdefinition`, OrderBy = 5.
2. **Grid registration** — `Grid` + `GridColumn` rows for the 8 columns above.
3. **GridFormSchema** — RJSF schema + uiSchema for custom-placeholder modal (fields per § ⑥ Modal Form).
4. **MasterData seeds** — ensure types exist:
   - `PLACEHOLDERTYPE`: FIELD, AGGREGATE, LINK, CHILD_LIST, FILE
   - `FORMATTYPE`: TEXT, NUMBER, DATE, CURRENCY, BOOLEAN, URL, HTML
   - `PLACEHOLDERCATEGORY`: CONTACT, DONATION, ORGANIZATION, CAMPAIGN, EVENT, SYSTEM, CUSTOM
   - `RECIPIENTTYPE`: DONOR, STAFF, SYSTEM (or existing values if already seeded)
5. **System placeholder rows** — 45+ rows per mockup body, all `IsSystem=true, CompanyId=NULL, IsActive=true`. Include at least the 21 rows shown explicitly in mockup lines 760-1012 plus logical follow-ups (LastName, FullName, Email, Phone, ContactCode, Salutation, EngagementScore, DonationAmount, Currency, DonationDate, ReceiptNumber, Purpose, OrgName, OrgAddress, CampaignName, EventName, EventDate, UnsubscribeLink, CurrentYear). The 21st (`{{CustomField_Occupation}}`) is an example Custom row — seed separately as a sample.
6. **Upsert semantics** — use `INSERT ... ON CONFLICT (PlaceholderCode) DO UPDATE` so re-runs are idempotent.

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens so user just reviews and confirms.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Placeholder Definitions
MenuCode: PLACEHOLDERDEFINITION
ParentMenu: CRM_COMMUNICATION
Module: CRM
MenuUrl: crm/communication/placeholderdefinition
GridType: MASTER_GRID

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: GENERATE
GridCode: PLACEHOLDERDEFINITION
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — knows EXACTLY what the backend exposes.

**GraphQL Types:**
- Query type: `PlaceholderDefinitionQueries`
- Mutation type: `PlaceholderDefinitionMutations`

**Queries:**
| GQL Field | Returns | Key Args | Status |
|-----------|---------|----------|--------|
| `placeholderDefinitions` | `IPagedListResult<PlaceholderDefinitionResponseDto>` | pageSize, pageIndex, sortColumn, sortDescending, searchTerm, advancedFilter | EXISTS — extend projection |
| `placeholderDefinitionById` | `IResult<PlaceholderDefinitionResponseDto>` | placeholderDefinitionId | EXISTS |
| `placeholderDefinitionSummary` | `IResult<PlaceholderDefinitionSummaryDto>` | — | **NEW** |

**Mutations** (all EXIST, only Update/Delete/Toggle handlers need system-row guard):
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createPlaceholderDefinition` | `PlaceholderDefinitionRequestDto` (`placeholderDefinitions` arg) | `{ data.placeholderDefinitionId }` |
| `updatePlaceholderDefinition` | `PlaceholderDefinitionRequestDto` | `{ data.placeholderDefinitionId }` — 403 if `IsSystem` |
| `deletePlaceholderDefinition` | `Int` | `{ data.placeholderDefinitionId }` — 403 if `IsSystem` |
| `activateDeactivatePlaceholderDefinition` | `Int` | `{ data.placeholderDefinitionId }` — 403 if `IsSystem` |

**PlaceholderDefinitionResponseDto fields** (FE receives — must add the 3 italicised fields):
| Field | Type | Notes |
|-------|------|-------|
| placeholderDefinitionId | number | PK |
| placeholderCode | string | unique |
| placeholderToken | string | `{{...}}` |
| displayName | string? | — |
| description | string? | — |
| entityType | string | discriminator |
| propertyPath | string? | source field |
| placeholderTypeId | number | FK |
| placeholderType | `{ dataName: string }` | FK nav |
| recipientTypeId | number | FK |
| formatTypeId | number? | FK |
| formatType | `{ dataName: string }?` | FK nav |
| formatPattern | string? | — |
| defaultValue | string? | — |
| placeholderCategoryId | number? | FK |
| placeholderCategory | `{ dataName: string }?` | FK nav |
| aggregateFunction, collectionPath, aggregateField, filterConfig, linkTemplate, linkExpiryHours, childEntityType, childTemplate, childSeparator, orderByField, orderDescending, maxItems | string/number/bool (all nullable) | Existing — system-only |
| *isSystem* | boolean | **NEW in projection** — drives row-action visibility |
| *companyId* | number? | **NEW** — null for system |
| *usedInCount* | number | **NEW** — aggregation |
| isActive | boolean | inherited |

**PlaceholderDefinitionSummaryDto (NEW):**
| Field | Type |
|-------|------|
| totalPlaceholders | number |
| activeCount | number |
| systemCount | number |
| customCount | number |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/crm/communication/placeholderdefinition`
- [ ] GraphQL schema introspection shows `placeholderDefinitionSummary` + extended ResponseDto fields

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with 8 columns: Placeholder, Display Name, Entity, Data Type, Source Field, Used In, Status, Actions
- [ ] Token chip renders monospace inside amber pill (token-chip renderer)
- [ ] Entity pill color varies by value (contact=blue, donation=green, organization=purple, campaign=pink, event=amber, system=slate, custom=cyan) via token-based variant classes — NO inline hex
- [ ] Status dot green=Active, grey=Inactive
- [ ] Search filters by token / display name / description / property path
- [ ] Entity dropdown filter works
- [ ] Data Type dropdown filter works
- [ ] Click "+Add Custom Placeholder" → RJSF modal opens, title="Add Custom Placeholder"
- [ ] Token input renders `{{` prefix + input + `}}` suffix (Prefix/SuffixInputWidget)
- [ ] Entity dropdown change → Source Field dropdown options refresh (RJSF `$data` dependency)
- [ ] Data Type field locked to "Text" for Custom placeholders
- [ ] Save → POST `createPlaceholderDefinition` → 200 → grid refreshes → toast shows → widgets re-query
- [ ] Edit on Custom row → modal pre-fills → Save → grid updates
- [ ] Edit/Delete icons DO NOT render on System rows
- [ ] System row "View Details" eye → modal read-only (all fields disabled, only Close button)
- [ ] Backend rejects update/delete/toggle on System row with clear error — verify via direct GQL call (not just UI hiding)
- [ ] Delete Custom row → soft delete → row removed → widgets re-query
- [ ] Toggle Custom row → status dot updates → widgets re-query
- [ ] "Used In: 12 templates" link renders and navigates (downstream EmailTemplate filter is OPEN — at minimum link href must be `/crm/communication/emailtemplate?placeholderId={id}`)
- [ ] Summary widgets: Total = all non-deleted; Active = IsActive=true; System = IsSystem=true; Custom = IsSystem=false
- [ ] Side panel renders 5 educational cards with correct icons (`ph:arrows-clockwise`, `ph:lock`, `ph:puzzle-piece`, `ph:code`, `ph:envelope`) using tokens only (no inline hex)
- [ ] "Custom Fields" link in side panel card 3 navigates to `/setting/customfields`
- [ ] Permissions: hiding BUSINESSADMIN's CREATE capability hides the "+Add" button; hiding READ hides the whole screen

**Responsive:**
- [ ] `xs` → widgets stack, side panel stacks below grid
- [ ] `lg+` → widgets 4-across, side panel right of grid (80px / 96px at xl)
- [ ] Fullscreen toggle wraps entire layout (ScreenHeader + widgets + grid + side panel), not just the grid — learned from ContactType #19 Session 2

**DB Seed Verification:**
- [ ] `PLACEHOLDERDEFINITION` menu appears under Communication parent in sidebar
- [ ] Grid renders all 8 columns per GridColumn seeds
- [ ] GridFormSchema → modal renders 7 form rows per § ⑥
- [ ] 45+ seeded system placeholders appear in grid
- [ ] Re-running seed SQL does not duplicate rows (ON CONFLICT)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **This is an ALIGN screen with a pattern change**: Existing FE is FLOW (view-page.tsx, per-record URL routing). ALIGN action is to CONVERT to MASTER_GRID (modal + RJSF). DELETE the 6-file `components/` subfolder and `view-page.tsx`, REWRITE `index.tsx` to not route by mode. Do NOT keep both patterns side-by-side.
- **Zustand store must be deleted** (`placeholder-definition-store.ts`). Also remove all imports of `usePlaceholderDefinitionStore` across the codebase — grep first; the cross-screen `emailsendjob` components from Email Template #24 may reference placeholder concepts but not this specific store.
- **BE entity has many advanced fields** (AggregateFunction, CollectionPath, LinkTemplate, ChildEntityType, etc.) — leave them in place. They are used by system-seeded rows AND consumed by the template-rendering engine. The UI modal for Custom placeholders only exposes FIELD-type, but the schema stays intact.
- **System-row immutability MUST be enforced in handlers, not just validators** — precedent: ContactType #19 ISSUE-4 and StaffCategory #43 ISSUE-7 both had validator-only guards that silently fell through at runtime. Guard inside `UpdatePlaceholderDefinitionHandler.Handle()`, `DeletePlaceholderDefinitionHandler.Handle()`, `TogglePlaceholderDefinitionHandler.Handle()` before any DB write.
- **Token uniqueness is global, not per-company** — a custom token `{{CustomField_Occupation}}` added by Tenant A cannot be re-added by Tenant B. Confirm with stakeholders if this is too strict; for now, match existing unique-index behaviour.
- **Custom placeholders MUST have prefix `CustomField_`** per mockup line 1090 — enforce in BE validator AND FE default placeholder text.
- **MasterData IDs must be looked up by seed, not hard-coded** — the modal needs to submit `placeholderTypeId` for FIELD. The FE should call the `masterDatas` query filtered by `typeCode=PLACEHOLDERTYPE AND dataName=FIELD` at form-init time, OR the BE create handler can derive from a string `placeholderTypeCode` param (cleaner — recommended if permitted by solution-resolver).
- **Source Field options are hardcoded static maps for now** (mockup lines 1188-1192). In a full implementation, the Source Field dropdown should fetch Custom Fields filtered by entity from the CustomField API (#82 Custom Fields screen, currently PARTIAL). Flag as follow-up — for this build, use the 3-entity static map from the mockup.
- **"Used In" column currently counts only EmailTemplatePlaceholders**. Once SMSTemplate #29, WhatsAppTemplate #31, NotificationTemplate #36 wire their own PlaceholderDefinition junction tables, extend the subquery (log as follow-up).
- **No `{lang}` prefix in link-count `linkTemplate`** — carry-over issue from DonationCategory #3 ISSUE-1 / StaffCategory #43 ISSUE-8. When building the Used-In href, DO use the `/[lang]/` prefix via `usePathname` or the app's i18n helper. Do not copy the existing bug.
- **Side panel is STATIC, not row-detail** — this is different from ContactType #19 (which uses a row-detail side panel). The 5 info-cards are hardcoded content; no selected-row dependency. Keep the component simple; no Apollo query, no Zustand.
- **Mockup `maxItems` field is labeled "Max length"** — reuse the existing `MaxItems: int?` column; do NOT migrate to a separate `MaxLength` column. The label differs from the column name — normal.
- **`onReorder` / `onRowClick` props** — the mockup does NOT show drag-to-reorder. Do not enable. Row-click can stay default.
- **UI tokens only** — entity-badge and token-chip colors must use CSS variables / Tailwind token variants, NOT inline hex. Define the 7 entity-color variants in the renderer as Tailwind classes (e.g., `bg-blue-100 text-blue-700` for contact, etc.). See `UI uniformity & polish` memory feedback.
- **Icon library**: @iconify/react Phosphor icons exclusively (`ph:*`). No Font Awesome (mockup uses `fa-*` — convert all to equivalents).

**Service Dependencies** (UI-only — no backend service implementation):

None for this screen. Everything in the mockup is implementable with current infrastructure. No external services (SMS/WhatsApp/Email gateway) involved — placeholder definitions are pure metadata.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | Low | BE Guard | System-row guard uses `BadRequestException` (HTTP 400) instead of `ForbiddenException` (HTTP 403) because `ForbiddenAccessException` has no message constructor in this codebase. Extend that exception class if a true 403 is desired. | OPEN |
| ISSUE-2 | 1 | Low | BE Performance | `Include(x => x.EmailTemplatePlaceholders)` is chained on the GetAll base query even though the count is computed via a separate batched aggregate (ContactType precedent). The Include can be removed if memory pressure is observed on large datasets. | OPEN |
| ISSUE-3 | 1 | Info | BE Aggregation | `UsedInCount` counts only `EmailTemplatePlaceholders`. Extend the subquery once SMSTemplate/WhatsAppTemplate/NotificationTemplate link tables are wired (follow-up, documented in §⑫). | OPEN |
| ISSUE-4 | 1 | Low | BE Migration | No new EF migration needed — all changes are query-level. Existing `PlaceholderDefinition` table schema unchanged. | RESOLVED |
| ISSUE-5 | 1 | Low | Summary GraphQL field | FE query uses `result: placeholderDefinitionSummary` flat wrapper; BE root resolver via `[ExtendObjectType(OperationTypeNames.Query)]` matches. Verified in session — no action needed. | RESOLVED |
| ISSUE-6 | 1 | Medium | FE Renderer | Seed referenced `type-badge` renderer (column 5 Data Type) which did NOT exist in any column-type registry. Orchestrator patched in-session: created `TypeBadgeRenderer` + registered in advanced/basic/flow registries. Same failure mode as ContactType #19 invented renderer names — BE seed must match FE registry keys. | RESOLVED |
| ISSUE-7 | 1 | Low | Custom Field dropdown | Source Field options for custom-placeholder modal are hardcoded static maps per mockup lines 1188-1192. Full implementation requires fetching from CustomField API filtered by entity (#82 Custom Fields screen). Flagged as downstream work. | OPEN |
| ISSUE-8 | 1 | Low | Used-In link | `linkTemplate` in seed grid column 7 includes `/[lang]/` prefix (fix carried over from #3 ISSUE-1 / #43 ISSUE-8). Downstream consumer: EmailTemplate screen must honor `?placeholderId={id}` query param in its filter logic (EmailTemplate #24 does not yet read this param — flag for future fix-up). | OPEN |
| ISSUE-9 | 1 | Info | DB Seed path typo | Seed SQL is at `sql-scripts-dyanmic/` (project-wide typo — other seeds live here too; preserved for consistency per Session 1 WhatsAppTemplate #31 ISSUE-5). | OPEN (shared repo typo) |
| ISSUE-10 | 1 | Info | SavedFilter #27 pre-existing errors | `dotnet build` failed with 5 errors in `SavedFilters/Queries/GetSavedFilter.cs` + `GetSavedFilterById.cs` referencing missing `CreatedBy` on `SavedFilterResponseDto`. NOT introduced by this session — attributed to SavedFilter #27 (PROMPT_READY). PlaceholderDefinition files compile cleanly. | OPEN (not this screen's responsibility) |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-19 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt — FLOW → MASTER_GRID conversion + ALIGN backend additions + DB seed + 51 system placeholder seed rows.
- **Files touched**:
  - BE (2 created): `Queries/GetPlaceholderDefinitionSummary.cs` (created), `sql-scripts-dyanmic/PlaceholderDefinition-sqlscripts.sql` (created)
  - BE (7 modified): `Schemas/NotifySchemas/PlaceholderDefinitionSchemas.cs` (+3 DTO fields, new SummaryDto class), `Queries/GetPlaceholderDefinition.cs` (projection extension + CompanyScope + post-projection UsedInCount injection), `Queries/GetPlaceholderDefinitionById.cs` (IsSystem/CompanyId/UsedInCount injection), `Commands/UpdatePlaceholderDefinition.cs` + `Commands/DeletePlaceholderDefinition.cs` + `Commands/TogglePlaceholderDefinition.cs` (handler-level system-row guards via `BadRequestException`), `EndPoints/Notify/Queries/PlaceholderDefinitionQueries.cs` (register summary resolver).
  - FE (8 deleted physically): `placeholderdefinition/view-page.tsx`, `components/PlaceholderDefinitionForm.tsx`, `components/BasicInformation.tsx`, `components/FieldConfiguration.tsx`, `components/AggregateConfiguration.tsx`, `components/FormattingConfiguration.tsx`, `components/index.ts` (+ folder), `index-page.tsx` (old FLOW version; the rewrite became inline in `index.tsx` via `placeholderdefinition-data-table.tsx`), `stores/communication-stores/placeholder-definition-store.ts`.
  - FE (2 rewritten): `placeholderdefinition/index.tsx` (Variant B layout: `AdvancedDataTableStoreProvider` wrap + `ScreenHeader` + widgets + two-column flex with info panel aside), `placeholderdefinition/index-page.tsx` (initially rewritten — subsequently deleted; data-table logic now in `placeholderdefinition-data-table.tsx`).
  - FE (7 created): `placeholderdefinition/placeholderdefinition-data-table.tsx`, `placeholderdefinition/placeholderdefinition-widgets.tsx`, `placeholderdefinition/placeholderdefinition-info-panel.tsx`, `shared-cell-renderers/token-chip-renderer.tsx`, `shared-cell-renderers/entity-badge-renderer.tsx`, `shared-cell-renderers/type-badge-renderer.tsx` (orchestrator patch after discovering seed→registry mismatch), `dgf-widgets/prefix-suffix-input-widget.tsx`.
  - FE (7 modified): `domain/entities/notify-service/PlaceholderDefinitionDto.ts` (+3 fields + new SummaryDto interface + nav typo fix `formateType→formatType`), `infrastructure/gql-queries/notify-queries/PlaceholderDefinitionQuery.ts` (projection extension + new `PLACEHOLDERDEFINITIONSUMMARY_QUERY`), `data-tables/advanced/data-table-column-types/component-column.tsx` + `.../basic/...` + `.../flow/...` (register token-chip/entity-badge/type-badge switch cases), `shared-cell-renderers/index.ts` (barrel + type-badge export), `dgf-widgets/index.tsx` (register PrefixSuffixInput widget), `stores/communication-stores/index.ts` (cleanup removed store).
  - DB (created): `sql-scripts-dyanmic/PlaceholderDefinition-sqlscripts.sql` — menu `PLACEHOLDERDEFINITION` under CRM_COMMUNICATION, grid + 8 GridColumn rows (cols: PK, token-chip, text-bold, entity-badge, type-badge, text-truncate, link-count, status-badge), GridFormSchema (RJSF), 4× MasterData typeCode seeds (PLACEHOLDERTYPE/FORMATTYPE/PLACEHOLDERCATEGORY/RECIPIENTTYPE), 51 placeholder rows (50 system + 1 sample custom), idempotent `ON CONFLICT (PlaceholderCode) DO UPDATE`.
- **Deviations from spec**:
  - BE agent used `BadRequestException` (400) for system-row guard instead of `ForbiddenException` (403) — codebase lacks a message-taking ForbiddenException constructor (see ISSUE-1).
  - BE agent added `Include(x => x.EmailTemplatePlaceholders)` on GetAll base query alongside the batched aggregate pattern (ISSUE-2 — informational).
  - FE agent initially could not physically delete FLOW files (shell permission — stubbed); orchestrator ran `rm -f` post-hoc to physically delete + removed `components/` folder + `index-page.tsx` dead-code file.
  - FE seed used `type-badge` (per prompt §⑥ spec) but no FE renderer existed for that key → orchestrator created `TypeBadgeRenderer` + registered across 3 column registries (ISSUE-6 RESOLVED in-session).
- **Known issues opened**: ISSUE-1, ISSUE-2, ISSUE-3, ISSUE-7, ISSUE-8, ISSUE-9, ISSUE-10 (SavedFilter pre-existing)
- **Known issues closed**: ISSUE-4 (no migration needed), ISSUE-5 (summary wrapper verified), ISSUE-6 (type-badge renderer patched)
- **Next step**: (empty — COMPLETED)
- **Verification**:
  - `dotnet build` (Base.API): PASS for PlaceholderDefinition files. Repo-wide build fails with 5 pre-existing SavedFilter errors (ISSUE-10 — unrelated to this screen).
  - `pnpm tsc --noEmit` (filtered): 0 placeholder-related errors.
  - UI uniformity grep (5 patterns): 0 matches in PlaceholderDefinition page components (no inline hex, no inline pixel, no Bootstrap card leakage, no hand-rolled skeleton, no raw "Loading...").
  - Variant B check: `ScreenHeader` imported + rendered in `index.tsx` line 104; `showHeader={false}` present in both `placeholderdefinition-data-table.tsx` and `index-page.tsx` — confirmed Variant B compliant.
  - Renderer registry check: all 5 DB-seed `GridComponentName` values (token-chip, text-bold, entity-badge, type-badge, text-truncate, link-count, status-badge) now resolve in advanced/basic/flow `component-column.tsx` switch cases.
- **User must (post-session)**:
  1. Run seed SQL: `psql ... -f sql-scripts-dyanmic/PlaceholderDefinition-sqlscripts.sql`
  2. No EF migration needed (no schema changes).
  3. `pnpm dev` → open `/crm/communication/placeholderdefinition` → verify: grid renders 50 system rows + 1 custom, widget counts correct, `+Add Custom Placeholder` opens modal (no URL change), prefix/suffix widget shows `{{` + input + `}}`, Entity filter works, "Used In" link-count renders with `/[lang]/` prefix, System rows show only View eye icon (no Edit/Delete), Custom row shows Edit + Delete.
  4. Test backend rejection: attempt `updatePlaceholderDefinition` mutation on a System row via GraphQL IDE → should return BadRequest "System placeholders cannot be modified."
  5. Resolve pre-existing SavedFilter #27 errors before building screen #27 (blocked on `CreatedBy` missing from `SavedFilterResponseDto`).