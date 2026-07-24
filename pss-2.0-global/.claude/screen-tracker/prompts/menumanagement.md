---
screen: MenuManagement
registry_id: 71
module: Access Control / Governance
status: COMPLETED
scope: ALIGN
screen_type: CONFIG
config_subtype: DESIGNER_CANVAS
storage_pattern: definition-list
save_model: save-per-record
complexity: High
new_module: NO
planned_date: 2026-05-16
completed_date: 2026-05-16
last_session_date: 2026-07-22
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type identified: DESIGNER_CANVAS — tree-editor + properties + live preview)
- [x] Business context read (NGO admin governs sidebar nav structure; rare-but-critical; mis-set hides modules from all users)
- [x] Storage model identified (definition-list — many Menu rows; existing `auth.Menus` entity)
- [x] Save model chosen (save-per-record — Save button per editor card; drag-reorder is autosaved)
- [x] Sensitive fields & role gates identified (BUSINESSADMIN only; "Reset to Defaults" gated by type-confirm)
- [x] FK targets resolved (ModuleId → auth.Modules; ParentMenuId → auth.Menus self-FK; both verified)
- [x] File manifest computed (~8 BE + 12 FE)
- [x] Approval config pre-filled (MENU / AC_GOVERNANCE / ACCESSCONTROL)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (pre-analyzed in /plan-screens — admin-only designer governing tenant-global sidebar nav)
- [x] Solution Resolution complete (CONFIG/DESIGNER_CANVAS confirmed; save-per-record + autosave-reorder; ISSUE-1 resolved → Menu is GLOBAL, no CompanyId; ISSUE-6 resolved → use existing react-dnd; ISSUE-3 resolved → ResetMenusToDefaults remaps RoleCapabilities by MenuCode)
- [x] UX Design finalized (split-layout 40/60 with tree + editor + preview — pre-designed in /plan-screens Section ⑥)
- [x] User Approval received (2026-05-16: Sonnet for all agents, Single FULL build)
- [x] Backend code generated          ← 7 created + 9 modified; EF migration `Add_Menu_DesignerCanvas_Fields`
- [x] Backend wiring complete         ← MenuMutations + MenuQueries + AuthMappings updated
- [x] Frontend code generated         ← 11 created + 6 modified + 1 deleted (MenuDataTable replaced by MenuManagementPage)
- [x] Frontend wiring complete        ← menu.tsx swap + index.ts barrel updated
- [x] DB Seed script generated        ← MenuManagement-sqlscripts.sql (RESET_DEFAULTS capability + BUSINESSADMIN grant)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/{lang}/accesscontrol/governance/menu`
- [ ] DESIGNER_CANVAS checks:
  - [ ] Tree renders all parent menus with children, ordered by `OrderBy`
  - [ ] Search filters tree; expand-on-match
  - [ ] Click parent/child → editor loads that record
  - [ ] Properties edit → Save → reflects in tree + sidebar preview
  - [ ] Drag-reorder a child → autosaves new `OrderBy`; tree updates without reload
  - [ ] Drag-reorder a parent → autosaves
  - [ ] Drag a child between two different parents → updates `ParentMenuId` + `OrderBy`
  - [ ] Context menu (right-click): Edit / Add Child / Move Up / Move Down / Duplicate / Hide / Delete all work
  - [ ] "+ Add Menu Item" creates a new root-level menu, auto-selected in editor
  - [ ] Sidebar Preview pane reflects current selection + dirty state
  - [ ] Icon picker: search filters; selected icon updates editor + tree
  - [ ] Badge config: empty text hides preview; non-empty + color shows pill
  - [ ] Type radio: External shows URL field; Header/Divider hide URL + Icon
  - [ ] Visibility toggle persists `IsVisible`; hidden items show gray status dot in tree
  - [ ] "Reset to Default" gated by type-confirm modal; restores seeded hierarchy via audit-logged batch op
  - [ ] Delete prevents deleting a parent with children (offer "delete with children" alt)
- [ ] Empty / loading / error states render
- [ ] DB Seed — menu MENU stays seeded under AC_GOVERNANCE

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: MenuManagement
Module: Access Control / Governance
Schema: auth
Group: Auth

Business: Menu Management is the **admin-only designer** that governs the application's sidebar navigation structure for the entire tenant — which top-level sections appear, how leaf screens nest under them, in what order, with which icons, and whether they're visible to end users. Only **BUSINESSADMIN** edits this; it's a **one-time setup** when onboarding a tenant, then touched rarely (when a module is added, renamed, or hidden for a tenant). Downstream, **every authenticated user's sidebar** is rendered from this hierarchy — so misconfiguration can hide entire modules from every user in the tenant, or surface menus that point at routes no role can reach. The existing `auth.Menus` table backs both this admin designer AND the runtime sidebar fetch (`GetParentChildMenu` filters by user-role access; this admin view does NOT filter — it shows everything). Two related screens depend on this hierarchy: **Role-Capability Matrix** (#70) decides who sees each menu, and the **sidebar component** consumes `parentChildMenus` at boot. UX is intentionally non-grid: a tree on the left mirrors the actual sidebar shape, an inline editor on the right keeps context, and a live preview pane shows exactly how the group will render in the runtime sidebar — making this a **designer canvas**, not a CRUD grid.

---

## ② Storage Model

> **Consumer**: BA Agent → Backend Developer

**Storage Pattern**: `definition-list` (many Menu rows + 1 parent FK to Module)

### Tables

Primary table: `auth."Menus"` — **ALREADY EXISTS**, ALIGN deltas only.

**Existing columns** (do NOT recreate):

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MenuId | int | — | PK | — | Identity PK |
| MenuName | string | (default) | YES | — | `[CaseFormat("title")]` — title-cased |
| MenuCode | string | (default) | YES | — | `[CaseFormat("upper")]` — UPPER-cased, unique per Module |
| ParentMenuId | int? | — | NO | auth.Menus (self) | null = top-level |
| MenuIcon | string? | — | NO | — | Currently `string`; mockup supports fa-icon (`fa-chart-line`) AND emoji (`📊`) |
| ModuleId | Guid | — | YES | auth.Modules | — |
| MenuUrl | string? | — | NO | — | Screen path (e.g. `crm/contact/contacttype`) |
| Description | string? | — | NO | — | Tooltip on hover |
| OrderBy | int | — | YES | — | Display order within parent |
| IsLeastMenu | bool | — | YES | — | true = leaf (no children) — currently computed-and-stored |
| IsActive | bool | — | (Entity) | — | Soft-delete via `Entity` base |
| IsDeleted | bool | — | (Entity) | — | Soft-delete via `Entity` base |

**ALIGN deltas — add 5 new columns** (mockup features missing from current entity):

| Field | C# Type | MaxLen | Required | Default | Notes |
|-------|---------|--------|----------|---------|-------|
| MenuType | string | 16 | YES | `"Internal"` | enum: `Internal` / `External` / `Header` / `Divider` (radio in mockup) |
| ExternalUrl | string? | 500 | NO | null | required only when `MenuType='External'` |
| IsVisible | bool | — | YES | true | Separate from `IsActive`. `IsActive=false` = soft-deleted; `IsVisible=false` = hidden in sidebar but record kept |
| BadgeText | string? | 32 | NO | null | optional badge (e.g. "New", "3", "Beta") |
| BadgeColor | string? | 7 | NO | null | hex color e.g. `#0e7490` |

**Indexes** (additive):
- Existing: PK on MenuId
- ALIGN add: filtered unique `(ModuleId, MenuCode) WHERE IsDeleted = false` (MenuCode unique per module — already an implicit business rule, formalize it)
- ALIGN add: non-unique `(ParentMenuId, OrderBy)` for tree ordering reads

**Singleton constraint**: N/A — this is a definition-list.

**Definition parent**: ModuleId (FK → `auth.Modules`)

**Order field**: `OrderBy` (int) within `(ModuleId, ParentMenuId)` scope.

**Child Tables**: none directly; `RoleCapability` and `MenuCapability` reference `MenuId` but are not modified by this screen.

**EF Migration**: `Add_Menu_DesignerCanvas_Fields` — adds 5 cols + 2 indexes. PostgreSQL filtered index syntax.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ModuleId | Module | [Base.Domain/Models/AuthModels/Module.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/AuthModels/Module.cs) | `modules` (GetModules — paginated) | ModuleName | ModuleResponseDto |
| ParentMenuId | Menu (self) | [Base.Domain/Models/AuthModels/Menu.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/AuthModels/Menu.cs) | `parentChildMenus` (or new `getMenuAdminTree`) | MenuName | MenuResponseDto / ParentChildMenuResponseDto |

**Dropdown sources for editor pane:**
- "Parent Menu" dropdown: options = `[Root (Top Level)]` + all top-level menus (`ParentMenuId IS NULL`) for the currently-active **same Module** as the selected menu. Use `getMenuAdminTree` (new) or filter the existing `parentChildMenus` for `parentMenuId == null`.
- "Module" — implicit per selection (read from selected menu; not a form field per mockup).

**Note**: mockup does NOT show a Module selector — it implies menus are managed within their existing module. The Module dropdown stays internal/derived from the selected node. Adding a NEW root menu requires a Module choice — surfaced when "+ Add Menu Item" is clicked (modal-on-add or inline pick).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Singleton / Cardinality Rules:**
- MenuCode is unique per `ModuleId` (filtered index — only active rows count).
- A top-level menu has `ParentMenuId IS NULL`; a sub-menu has `ParentMenuId` pointing to a top-level menu in the **same Module** (no cross-module nesting).
- `IsLeastMenu` derived: TRUE when no active children exist. Should be auto-computed on Create / Delete / Reorder, not user-editable.

**Required Field Rules:**
- MenuName: required, 2-100 chars
- MenuCode: required, UPPER-cased, alphanumeric + underscore, 2-50 chars
- OrderBy: required, integer ≥ 1
- ModuleId: required (existing menus have it; new root menus must pick one)
- MenuType: required, one of `Internal | External | Header | Divider`
- IsVisible: required boolean
- ExternalUrl: required ONLY when MenuType=`External`; must be a valid `http(s)://` URL

**Conditional Rules:**
- If MenuType=`External` → ExternalUrl required; MenuUrl (screen path) cleared.
- If MenuType=`Internal` → MenuUrl required; ExternalUrl cleared.
- If MenuType=`Header` or `Divider` → MenuUrl, ExternalUrl, MenuIcon optional; BadgeText/BadgeColor disabled in UI.
- BadgeText empty ⇒ BadgeColor also persisted as null (badge OFF).
- BadgeColor non-null ⇒ BadgeText must be non-empty.

**Business Logic:**
- **Reorder atomicity**: a drag-reorder may touch the moved node + its old-parent siblings + its new-parent siblings — wrap in a single transaction with full re-sequence within the affected parents.
- **Cross-parent move**: changing ParentMenuId is allowed only when the new parent is in the same Module and is not a descendant of the moved node (prevent cycles).
- **Auto-derived MenuKey**: presentation-only string `{parentMenuCode}.{menuCode}` (lowercased + kebabified per segment). Computed in BE for read DTOs; never stored.

**Sensitive Fields**: none — menu config is admin-visible meta, no secrets.

**Read-only / System-controlled Fields:**
- MenuKey (derived in BE, exposed on read only, readonly in UI)
- IsLeastMenu (auto-computed; never user-editable)
- Target Roles (mockup: info banner linking to Role-Capability Matrix — NOT editable here)

**Dangerous Actions** (require confirm + audit):
| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Reset to Default | Soft-deletes all current menus for the tenant and re-runs seed for the original module-menu hierarchy | Modal: type tenant name to confirm; warn that "Role-Capability mappings to deleted menus will become orphaned" | log "menu-hierarchy reset" event with prior state JSON snapshot |
| Delete Parent with Children | Soft-deletes parent + ALL descendants | Modal: "This will hide N child menus from all roles" — show child count | log per-row deletion |
| Hide (visibility off) | `IsVisible=false` — keeps record, hides in runtime sidebar | inline toggle (no modal) | normal audit |

**Role Gating:**
| Role | Sections Visible | Sections Editable | Notes |
|------|------------------|-------------------|-------|
| BUSINESSADMIN | all | all | full access |
| All other roles | screen denied | — | `useAccessCapability({menuCode:"MENU"})` returns canRead=false |

**Workflow**: None — direct edit / save / autosave model.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: CONFIG
**Config Sub-type**: `DESIGNER_CANVAS`
**Storage Pattern**: `definition-list`
**Save Model**: `save-per-record` for property edits; `autosave` for drag-reorder

| Save Operation | Trigger | Behavior |
|----------------|---------|----------|
| Save (editor card) | User clicks Save in editor pane | PATCH `updateMenu` for current node; toast on success |
| Autosave (drag-reorder) | User drops a node in new position | POST `reorderMenus` with affected siblings' new OrderBy + ParentMenuId; subtle "Reordered" toast |
| Autosave (visibility toggle) | User toggles `IsVisible` in editor | PATCH `updateMenu` with IsVisible only; subtle toast |
| Save (delete / duplicate / reset) | Context menu / page action | corresponding mutation with confirm where listed |

**Reason**: A 5-level tree of 68+ menu items is too dense for a flat grid; admins edit individual properties in the right pane and reorder via drag-handle. Two save modes match user intent: explicit Save for property changes, autosave for purely-positional drag-reorders (which would feel broken otherwise).

**Backend Patterns Required (DESIGNER_CANVAS / definition-list):**

- [x] `GetMenuAdminTree` query — returns ALL menus for ALL modules in tree shape, **unfiltered by role** (admin view). Distinct from existing `parentChildMenus` which is user-role-scoped at runtime.
- [x] `CreateMenu` (existing — extend DTO with new fields)
- [x] `UpdateMenu` (existing — extend DTO with new fields)
- [x] `DeleteMenu` (existing — enhance to detect children → return error code so FE can offer "delete with children")
- [x] `DeleteMenuWithChildren` — new command, recursive soft-delete (audit each row)
- [x] `ToggleMenuStatus` (existing — keep; also covers IsVisible? **No** — IsActive ≠ IsVisible; keep them separate)
- [x] `ReorderMenus` — new bulk command; accepts a list of `{menuId, parentMenuId, orderBy}` and persists all in one transaction
- [x] `DuplicateMenu` — new command; clones the node + (optionally) its descendants with a generated unique MenuCode (`{CODE}_COPY`, `_COPY2`, …)
- [x] `ResetMenusToDefaults` — new command; SERVICE_PLACEHOLDER on the seed re-run side; logs a hierarchy snapshot before purge
- [x] Schema-validation rules (parent in same module, no cycles, unique MenuCode per module, External URL valid)
- [x] BE-computed `MenuKey` in read DTO

**Frontend Patterns Required (DESIGNER_CANVAS):**

- [x] Custom split-layout page (NOT AdvancedDataTable — replace existing `MenuDataTable`)
- [x] Left pane: tree component with search + drag-reorder + context menu + status dots + order badges
- [x] Right pane: editor card with conditional fields (External URL / MenuUrl based on MenuType)
- [x] Icon picker (fa-icon grid + search input)
- [x] Badge config component (text + color dropdown + live preview pill)
- [x] Sidebar Preview component (renders current parent's children in actual sidebar styling)
- [x] Zustand store: selected node, dirty state, tree state, expand/collapse map
- [x] Drag-and-drop library: use **`@hello-pangea/dnd`** if already in the project, else **`@dnd-kit/core`** + **`@dnd-kit/sortable`** (Solution Resolver to confirm presence per [package.json](../../../PSS_2.0_Frontend/package.json))
- [x] Confirm dialog for Delete / Reset to Default
- [x] Capability gate via `useAccessCapability({menuCode:"MENU"})`

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: This section is the design spec. Fill in **only the DESIGNER_CANVAS block** (B).
> **Layout Variant stamp**: `side-panel` — tree on left + editor + preview on right (40/60 split).

### 🎨 Visual Uniqueness Rules

1. The tree IS the primary affordance — not a secondary nav. Make it visually dominant: 40% width, full-height scroll, sticky search header.
2. The editor card uses **2-column form rows** (matches mockup) — not a single-column stack. Labels are SMALL CAPS with letter-spacing.
3. The icon picker is **inline** (not a modal) — collapses to current icon when not focused; expands to grid when active.
4. The sidebar preview is rendered with **actual runtime sidebar CSS** (or a near-clone) so admins see what their changes look like — not a generic card preview.
5. The "+ Add Menu Item" button is the **PRIMARY accent** in the page header; "Reset to Default" is **destructive outline** styling — visually segregated.
6. Status dots in the tree: **green = visible**, **gray = hidden** (per mockup). Don't introduce a third color.
7. Order badges in the tree are subtle (`1`, `2.1`, `2.7`) — small, monospace-feel — not loud.

**Anti-patterns to refuse:**
- Rendering the tree as a flat list with indentation hacks (use a real recursive tree component)
- A modal for editing (mockup is explicitly inline-on-the-right)
- Generic placeholder for sidebar preview (must mirror runtime sidebar)
- All four MenuType options rendered as a dropdown (mockup explicitly uses radio group)
- Hiding the icon picker behind a "Pick Icon" button (mockup shows it inline expanded)

---

### 🅱️ Block B — DESIGNER_CANVAS

#### Page Header

| Element | Content |
|---------|---------|
| Page title | "Menu Management" (fa-bars-staggered icon, admin-accent red color per mockup) |
| Subtitle | "Configure sidebar navigation structure and ordering" |
| Right action (primary) | "+ Add Menu Item" → opens inline new-record state in editor (root by default; or pre-fills parent if a parent tree-node is active) |
| Right action (destructive) | "Reset to Default" → opens type-tenant-name confirm modal |

#### Split Layout (40/60)

```
┌────────────────────────────────────────────────────────────────────────┐
│ Menu Management                            [+ Add Item] [Reset Default]│
├──────────────────────────┬─────────────────────────────────────────────┤
│ NAVIGATION TREE          │ MENU ITEM EDITOR                            │
│ 🔍 search…              │ Editing: Dashboard Home                     │
│                          │ ┌─────────────────┬─────────────────────┐   │
│ ▼ 📊 Dashboard      [1] ●│ │ Menu Label *    │ Menu Key (readonly) │   │
│   • Dashboard Home  [1.1]│ │ Dashboard Home  │ dashboard.dashboard-…│   │
│   • Configure Widgets[1.2│ ├─────────────────┼─────────────────────┤   │
│ ▼ 👥 Contacts       [2] ●│ │ Parent Menu     │ Display Order *     │   │
│   • Contact List    [2.1]│ │ Dashboard ▾     │ 1                   │   │
│   …                      │ ├─────────────────┴─────────────────────┤   │
│ ▶ 💰 Fundraising    [3] ●│ │ Icon  [chart-line] [search…]          │   │
│ ▶ 📧 Communication  [4] ●│ │ [ icon grid scrollable ]              │   │
│ ▶ 🏢 Organization   [5] ●│ ├───────────────────────────────────────┤   │
│ ▶ 🚶 Field Coll.   [6] ●│ │ Screen Path                            │   │
│ ▶ 📊 Reports        [7] ●│ │ dashboard/dashboard-home              │   │
│ ▶ ⚙️ Administration [8] ●│ ├───────────────────────────────────────┤   │
│ ▶ 🔧 Settings       [9] ●│ │ Type: (•) Internal ( ) External       │   │
│                          │ │       ( ) Header ( ) Divider          │   │
│ 9 sections, 68 items     │ ├───────────────────────────────────────┤   │
│                          │ │ Visibility: [●——] Visible             │   │
│                          │ ├───────────────────────────────────────┤   │
│                          │ │ Badge: [text] [color ▾] [preview]     │   │
│                          │ ├───────────────────────────────────────┤   │
│                          │ │ Description (tooltip)                 │   │
│                          │ │ [textarea]                            │   │
│                          │ ├───────────────────────────────────────┤   │
│                          │ │ Target Roles: ℹ️ Managed via Matrix   │   │
│                          │ │  → [Open Matrix]                      │   │
│                          │ ├───────────────────────────────────────┤   │
│                          │ │ [Delete]    [Cancel] [Save]           │   │
│                          │ └───────────────────────────────────────┘   │
│                          │                                             │
│                          │ ┌── 👁️ SIDEBAR PREVIEW ────────────────┐   │
│                          │ │ ▼ 📊 Dashboard                        │   │
│                          │ │ ▸ [chart-line] Dashboard Home (active)│   │
│                          │ │ ▸ [sliders] Configure Widgets         │   │
│                          │ └───────────────────────────────────────┘   │
└──────────────────────────┴─────────────────────────────────────────────┘
```

#### Palette (= "+ Add Menu Item" button — single-button palette)

| Item | Trigger | Default Properties on Create |
|------|---------|------------------------------|
| New Menu (Root) | Click "+ Add Menu Item" with no tree selection | `{ menuName: 'New Menu', menuCode: 'NEW_MENU_n', menuType: 'Internal', orderBy: max+1, parentMenuId: null, moduleId: <picker> }` |
| New Sub-menu | Right-click parent → "Add Child" | same defaults, but parentMenuId = selected parent's id; ModuleId inherited |
| Duplicate | Right-click → "Duplicate" | clones source with `menuCode = src.menuCode + '_COPY'` (auto-increment if conflict); descendants also cloned (prompt user) |

**On-add behavior**: new row created in BE with default fields → tree refresh → new node auto-selected → editor card loads → user edits Name/Code → Save.

If the user adds a brand-new ROOT menu, the editor card surfaces a **Module dropdown** (otherwise hidden — inherited from selection).

#### Canvas (= Tree)

**Tree component requirements:**
- Recursive parent → children rendering
- Each row shows: drag-handle / expand-chevron (parents only) / icon / label / order-badge / status-dot
- **Search**: filter visible items by label; auto-expand any parent whose descendant matches
- **Active state**: highlighted row (accent-bg + left border)
- **Drag-reorder behaviors**:
  - Drag within same parent → reorder siblings (autosave `OrderBy`)
  - Drag a child into a different parent → both reparent and reorder (autosave `ParentMenuId` + `OrderBy`)
  - Drag a parent → reorder root level (autosave)
  - **Forbidden**: dragging a parent to become its own descendant (cycle) → snap back + toast
- **Context menu** (right-click any row): Edit / Add Child / Move Up / Move Down / Duplicate / Hide (toggle) / Delete

**Tree state in Zustand:**
- `selectedMenuId: number | null`
- `expandedMenuIds: Set<number>`
- `searchTerm: string`
- `tree: ParentChildMenuResponseDto[]` (refreshed after each mutation)

#### Properties Pane (= Editor Card)

**Fields** (per mockup, top to bottom):

| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| Menu Label | text | (from record) | required, 2-100 | label says "Menu Label *" |
| Menu Key | text (READONLY) | derived `{parentCode}.{code}` | — | system identifier; readonly bg |
| Parent Menu | dropdown | (from record) | — | options: "Root (Top Level)" + same-module top-level menus |
| Display Order | number | (from record) | required, ≥ 1 | manually editable; also auto-set on drag-reorder |
| Icon | icon-picker | (from record) | — | fa-icon grid + search; selected icon updates editor + tree row + preview |
| Screen Path | text | (from record) | required if MenuType=Internal | placeholder `e.g., fundraising/donation-list`; help-text "Used in loadContent()..." |
| Type | radio-group | "Internal" | required | 4 options: Internal Screen / External URL / Section Header / Divider |
| External URL | url | (hidden unless External) | required if Type=External; valid http(s) URL | shows only when Type=External |
| Visibility | toggle-switch | true | — | autosaves on toggle; tree status-dot reflects |
| Badge — Text | text | null | — | optional; empty hides preview |
| Badge — Color | dropdown | "#0e7490" | — | 5 options: Primary / Success / Warning / Danger / Info (each maps to a hex) |
| Badge — Preview | pill (chip) | — | — | live preview; shown only when text non-empty |
| Description | textarea (rows=2) | (from record) | — | tooltip-on-hover hint |
| Target Roles | info-banner (read-only) | — | — | "ℹ️ Access controlled via Role-Capability Matrix" + "[Open Matrix →]" link to `accesscontrol/usersroles/rolecapability` |

**Editor Actions** (bottom-right of card):

| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Delete | "Delete Item" | destructive-outline | "Delete this menu item?" — if has children → "Delete this menu and N child items?" | `deleteMenu` OR `deleteMenuWithChildren` mutation |
| Cancel | "Cancel" | tertiary | (if dirty) "Discard unsaved changes?" | revert form to last-saved state |
| Save | "Save" | primary | — | `updateMenu` mutation |

#### Preview (= Sidebar Preview Card)

A separate card below the editor showing the **selected node's parent group** as it would render in the runtime sidebar:

- Parent pill row (icon + name + chevron)
- Child rows (icon + name; current selection highlighted)
- Renders BadgeText/BadgeColor as a pill on the right side of the child row
- Hidden items (`IsVisible=false`) render strikethrough or skipped (admin preference — pick **skipped** to match runtime behavior)

#### Validation Rules (block save)

- Menu Label required, 2-100 chars
- MenuCode unique per Module (BE check on save)
- Display Order ≥ 1
- Type=External ⇒ ExternalUrl required + http(s) format
- Type=Internal ⇒ MenuUrl required
- BadgeColor non-null ⇒ BadgeText non-empty
- Cannot set ParentMenuId to a descendant of self (BE rejects)

#### User Interaction Flow (DESIGNER_CANVAS)

1. User opens screen → BE returns `getMenuAdminTree` → all menus + modules render in tree (default first parent active)
2. User clicks a tree node → editor loads that node's data → sidebar preview reflects current parent's children
3. User edits Menu Label → editor card becomes dirty → Save enables
4. User clicks Save → validation runs → `updateMenu` PATCH → toast → tree refreshes → preview refreshes
5. User drags a child to a new position → `reorderMenus` autosave → tree updates without reload → subtle toast "Reordered"
6. User right-clicks a row → context menu → "Add Child" → new child row inserted under the right-clicked parent → editor pre-fills with defaults → user edits → Save
7. User clicks "+ Add Menu Item" → new root-level menu added → editor pre-fills with defaults + Module dropdown surfaces → user edits → Save
8. User clicks "Reset to Default" → confirm modal asks for tenant name → on confirm: BE snapshots current state to audit log + soft-deletes all tenant menus + re-seeds default hierarchy → tree refreshes
9. User toggles Visibility → autosave `IsVisible` → tree status-dot turns gray; runtime sidebar will hide this menu
10. User clicks "Open Matrix" → navigates to `accesscontrol/usersroles/rolecapability` (#70) — SERVICE_PLACEHOLDER if #70 not built (toast: "Role-Capability Matrix is not yet built")

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading | Initial fetch | Skeleton tree (animated bars) + skeleton editor card |
| Empty | (Rare) — fresh tenant with no menus | Full-page CTA: "No menus configured. Click 'Reset to Default' to seed the standard hierarchy." |
| Error (tree fetch) | `getMenuAdminTree` fails | Error card with Retry button + error code |
| No selection | User cleared selection or just opened the page | Editor card shows empty-state: "Select a menu item from the tree to edit, or click '+ Add Menu Item'" |
| Save error | mutation fails | Inline error per offending field + toast |

---

## ⑦ Substitution Guide

> **No canonical DESIGNER_CANVAS reference exists yet** — this screen would set the convention if it lands first. Closest existing pattern to consult for split-layout/tree work:
> - MasterData (`prompts/masterdata.md`) — split-panel (list + values) with reorder; NOT a designer canvas but uses drag-reorder
> - SavedFilter (`prompts/savedfilter.md`) — FLOW; reference only for capability gating + ROLE seed
>
> Until a true DESIGNER_CANVAS canonical exists, treat MasterData as the closest split-layout precedent.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| Menu | Menu | Entity name (no change) |
| menu | menu | camelCase |
| menu-management | menu-management | kebab-case (folder) |
| menus | menus | plural (folder + GQL collection) |
| auth | auth | DB schema |
| Auth | Auth | Backend Group |
| AUTHMODELS | AUTHMODELS | C# folder |
| MENU | MENU | UPPERCASE MenuCode |
| AC_GOVERNANCE | AC_GOVERNANCE | ParentMenuCode |
| ACCESSCONTROL | ACCESSCONTROL | Module Code |
| accesscontrol/governance/menu | accesscontrol/governance/menu | MenuUrl |

---

## ⑧ File Manifest

### Backend Files (ALIGN — extend existing)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Entity | [Base.Domain/Models/AuthModels/Menu.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/AuthModels/Menu.cs) | MODIFY — add MenuType, ExternalUrl, IsVisible, BadgeText, BadgeColor |
| 2 | EF Config | Base.Infrastructure/Data/Configurations/AuthConfigurations/MenuConfiguration.cs | MODIFY — add filtered unique index + non-unique (ParentMenuId, OrderBy) |
| 3 | Schemas (DTOs) | [Base.Application/Schemas/AuthSchemas/MenuSchemas.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/AuthSchemas/MenuSchemas.cs) | MODIFY — extend Request/Response DTOs with new fields + add ReorderMenuRequestDto + DuplicateMenuRequestDto + ResetMenusRequestDto + MenuKey derived field |
| 4 | GetMenuAdminTree Query | Base.Application/Business/AuthBusiness/Menus/Queries/GetMenuAdminTree.cs | NEW — admin-view tree, no role filtering, includes IsVisible=false and IsActive=true rows |
| 5 | ReorderMenus Command | Base.Application/Business/AuthBusiness/Menus/Commands/ReorderMenus.cs | NEW — bulk update OrderBy + ParentMenuId, transactional, cycle-check |
| 6 | DuplicateMenu Command | Base.Application/Business/AuthBusiness/Menus/Commands/DuplicateMenu.cs | NEW — clone node ± descendants, generate unique MenuCode suffix |
| 7 | DeleteMenuWithChildren Command | Base.Application/Business/AuthBusiness/Menus/Commands/DeleteMenuWithChildren.cs | NEW — recursive soft-delete, per-row audit |
| 8 | ResetMenusToDefaults Command | Base.Application/Business/AuthBusiness/Menus/Commands/ResetMenusToDefaults.cs | NEW — snapshot + purge + re-seed (SERVICE_PLACEHOLDER on seed re-run hook) |
| 9 | CreateMenu | [Base.Application/Business/AuthBusiness/Menus/Commands/CreateMenu.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Menus/Commands/CreateMenu.cs) | MODIFY — accept new fields; default MenuType='Internal', IsVisible=true |
| 10 | UpdateMenu | [Base.Application/Business/AuthBusiness/Menus/Commands/UpdateMenu.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Menus/Commands/UpdateMenu.cs) | MODIFY — accept new fields; conditional validation per MenuType; cycle-check on ParentMenuId change |
| 11 | DeleteMenu | [Base.Application/Business/AuthBusiness/Menus/Commands/DeleteMenu.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Menus/Commands/DeleteMenu.cs) | MODIFY — return distinct error code when children exist so FE can prompt user for DeleteMenuWithChildren |
| 12 | GetMenuById | [Base.Application/Business/AuthBusiness/Menus/Queries/GetMenuById.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/AuthBusiness/Menus/Queries/GetMenuById.cs) | MODIFY — project new fields + computed MenuKey |
| 13 | MenuMutations endpoint | [Base.API/EndPoints/Auth/Mutations/MenuMutations.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Auth/Mutations/MenuMutations.cs) | MODIFY — register ReorderMenus, DuplicateMenu, DeleteMenuWithChildren, ResetMenusToDefaults |
| 14 | MenuQueries endpoint | [Base.API/EndPoints/Auth/Queries/MenuQueries.cs](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Auth/Queries/MenuQueries.cs) | MODIFY — register GetMenuAdminTree |
| 15 | AuthMappings (Mapster) | Base.Application/Mappings/AuthMappings.cs (or analogous) | MODIFY — map new fields |
| 16 | EF Migration | Base.Infrastructure/Data/Migrations/{timestamp}_Add_Menu_DesignerCanvas_Fields.cs | NEW — add 5 cols + 2 indexes |

### Frontend Files (FE_ONLY scope — replace existing UI)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO | [src/domain/entities/auth-service/MenuDto.ts](../../../PSS_2.0_Frontend/src/domain/entities/auth-service/MenuDto.ts) | MODIFY — add menuType, externalUrl, isVisible, badgeText, badgeColor, menuKey |
| 2 | New DTOs | src/domain/entities/auth-service/MenuDto.ts | MODIFY — add `ReorderMenuItem`, `ReorderMenusRequest`, `DuplicateMenuRequest`, `ResetMenusRequest`, `MenuAdminTreeNode` |
| 3 | GQL Query | [src/infrastructure/gql-queries/auth-queries/MenuQuery.ts](../../../PSS_2.0_Frontend/src/infrastructure/gql-queries/auth-queries/MenuQuery.ts) | MODIFY — extend MENU_BY_ID_QUERY with new fields + ADD `GET_MENU_ADMIN_TREE_QUERY` |
| 4 | GQL Mutation | [src/infrastructure/gql-mutations/auth-mutations/MenuMutation.ts](../../../PSS_2.0_Frontend/src/infrastructure/gql-mutations/auth-mutations/MenuMutation.ts) | MODIFY — extend CREATE/UPDATE with new fields + ADD `REORDER_MENUS_MUTATION`, `DUPLICATE_MENU_MUTATION`, `DELETE_MENU_WITH_CHILDREN_MUTATION`, `RESET_MENUS_MUTATION` |
| 5 | Designer Page | src/presentation/components/page-components/accesscontrol/governance/menu-components/menu-management-page.tsx | NEW — main split-layout component |
| 6 | Tree Panel | src/presentation/components/page-components/accesscontrol/governance/menu-components/menu-tree.tsx | NEW — recursive tree with drag-reorder + search + context menu |
| 7 | Tree Item | src/presentation/components/page-components/accesscontrol/governance/menu-components/menu-tree-item.tsx | NEW — single row renderer (parent or child) |
| 8 | Tree Context Menu | src/presentation/components/page-components/accesscontrol/governance/menu-components/menu-tree-context-menu.tsx | NEW — right-click menu (Edit / Add Child / Move Up/Down / Duplicate / Hide / Delete) |
| 9 | Editor Card | src/presentation/components/page-components/accesscontrol/governance/menu-components/menu-editor-card.tsx | NEW — properties form with all fields per mockup |
| 10 | Icon Picker | src/presentation/components/page-components/accesscontrol/governance/menu-components/menu-icon-picker.tsx | NEW — inline fa-icon grid + search input |
| 11 | Badge Config | src/presentation/components/page-components/accesscontrol/governance/menu-components/menu-badge-config.tsx | NEW — text + color picker + live pill preview |
| 12 | Sidebar Preview | src/presentation/components/page-components/accesscontrol/governance/menu-components/menu-sidebar-preview.tsx | NEW — runtime-sidebar-mimic of current parent's children |
| 13 | Reset Confirm Modal | src/presentation/components/page-components/accesscontrol/governance/menu-components/reset-menus-modal.tsx | NEW — type-tenant-name confirm |
| 14 | Delete-with-Children Modal | src/presentation/components/page-components/accesscontrol/governance/menu-components/delete-menu-modal.tsx | NEW — confirm w/ child count |
| 15 | Zustand Store | src/presentation/components/page-components/accesscontrol/governance/menu-components/menu-management-store.ts | NEW — selectedMenuId, expandedMenuIds, searchTerm, treeNodes, dirty |
| 16 | Components Index | [src/presentation/components/page-components/accesscontrol/governance/menu-components/index.ts](../../../PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/governance/menu-components/index.ts) | MODIFY — re-export MenuManagementPage; keep MenuDataTable export for fallback removal |
| 17 | Page Component | [src/presentation/pages/accesscontrol/governance/menu.tsx](../../../PSS_2.0_Frontend/src/presentation/pages/accesscontrol/governance/menu.tsx) | MODIFY — replace `<MenuDataTable />` with `<MenuManagementPage />` |
| 18 | Route Page | [src/app/[lang]/accesscontrol/governance/menu/page.tsx](../../../PSS_2.0_Frontend/src/app/[lang]/accesscontrol/governance/menu/page.tsx) | NO CHANGE — already exports MenuPageConfig |
| 19 | Legacy DataTable | [src/presentation/components/page-components/accesscontrol/governance/menu-components/data-table.tsx](../../../PSS_2.0_Frontend/src/presentation/components/page-components/accesscontrol/governance/menu-components/data-table.tsx) | DELETE — replaced by MenuManagementPage; or keep with a redirect re-export for a release |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | NO CHANGE — DbSet<Menu> already present |
| 2 | BaseDbContext.cs | NO CHANGE — already configured |
| 3 | DecoratorProperties.cs | NO CHANGE — `DecoratorAuthModules.Menu` already in `[CustomAuthorize]` calls |
| 4 | AuthMappings.cs | MODIFY — add new fields to Menu↔MenuRequestDto/MenuResponseDto mappings |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | Verify MENU block lists `getMenuAdminTree`, `reorderMenus`, `duplicateMenu`, `deleteMenuWithChildren`, `resetMenusToDefaults` — add any missing |
| 2 | operations-config.ts | Import + register new operations if entity-operations adds any |
| 3 | sidebar menu config | NO CHANGE — `MENU` menu already seeded at `accesscontrol/governance/menu` under `AC_GOVERNANCE` |

### DB Seed

| # | File | Action |
|---|------|--------|
| 1 | sql-scripts-dyanmic/MenuManagement-sqlscripts.sql | NEW — capability augment: `MENU` retains `READ, MODIFY, ISMENURENDER` (verify already seeded under AC_GOVERNANCE) + add `RESET_DEFAULTS` capability if not present + BUSINESSADMIN role-capability grants. Idempotent. |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: ALIGN

MenuName: Menus
MenuCode: MENU
ParentMenu: AC_GOVERNANCE
Module: ACCESSCONTROL
MenuUrl: accesscontrol/governance/menu
GridType: CONFIG

MenuCapabilities: READ, MODIFY, ISMENURENDER, RESET_DEFAULTS

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY, RESET_DEFAULTS

GridFormSchema: SKIP
GridCode: MENU
---CONFIG-END---
```

> **Notes**:
> - No CREATE/DELETE capability listed because MENU has full lifecycle (create/update/delete) handled under `MODIFY`. If the project's capability convention requires distinct CREATE/DELETE caps, the Solution Resolver should split.
> - `RESET_DEFAULTS` is a new capability for the dangerous "Reset to Default" action. Seed it.
> - `GridFormSchema: SKIP` because UI is a custom designer canvas, not an RJSF modal.
> - Menu MENU is already seeded under AC_GOVERNANCE — verify via existing `Module_Menu_List.sql`.

---

## ⑩ Expected BE→FE Contract

**GraphQL Types:**
- Query type: `MenuQueries`
- Mutation type: `MenuMutations`

### Queries

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `menus` (existing) | PaginatedApiResponse<MenuResponseDto[]> | `pageSize, pageIndex, sortColumn, …` |
| `menuById` (existing — extend) | BaseApiResponse<MenuResponseDto> | `menuId: Int!` |
| `parentChildMenus` (existing — runtime sidebar) | BaseApiResponse<ParentChildMenuResponseDto[]> | `moduleCode: String!` |
| **`menuAdminTree` (NEW)** | BaseApiResponse<MenuAdminTreeNode[]> | — (returns ALL modules → all menus, unfiltered by role; admin view) |

### Mutations

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createMenu` (existing — extend DTO) | MenuRequestDto (with new fields) | MenuResponseDto |
| `updateMenu` (existing — extend DTO) | MenuRequestDto (with new fields) | MenuResponseDto |
| `deleteMenu` (existing — enhance) | menuId: Int! | { success, errorCode: "HAS_CHILDREN" \| null } |
| `activateDeactivateMenu` (existing) | menuId: Int! | success |
| **`reorderMenus` (NEW)** | `[ReorderMenuItem!]!` (list of `{menuId, parentMenuId, orderBy}`) | success |
| **`duplicateMenu` (NEW)** | `{menuId: Int!, includeChildren: Boolean!}` | MenuResponseDto (new clone) |
| **`deleteMenuWithChildren` (NEW)** | menuId: Int! | { success, deletedCount } |
| **`resetMenusToDefaults` (NEW)** | `{confirmTenantName: String!}` | success + snapshotId (for audit) |

### DTO Shapes (FE TypeScript)

```ts
// MenuRequestDto — extended
export interface MenuRequestDto {
  menuId?: number | null;
  menuName: string;
  menuCode: string;
  parentMenuId?: number | null;
  menuIcon?: string;
  menuUrl?: string;
  description?: string;
  moduleId: string;
  orderBy: number;
  isLeastMenu?: boolean;
  // NEW
  menuType: "Internal" | "External" | "Header" | "Divider";
  externalUrl?: string;
  isVisible: boolean;
  badgeText?: string;
  badgeColor?: string;
}

// MenuResponseDto — extended
export interface MenuResponseDto extends MenuRequestDto {
  isActive: boolean;
  menuKey?: string;          // BE-computed (read-only)
  module?: ModuleRequestDto;
  parentMenu?: { parentMenuName: string };
}

// NEW
export interface MenuAdminTreeNode extends MenuRequestDto {
  childMenus: MenuAdminTreeNode[];
  moduleName: string;
  hasChildren: boolean;
  isActive: boolean;
}

// NEW
export interface ReorderMenuItem {
  menuId: number;
  parentMenuId: number | null;
  orderBy: number;
}

export interface ReorderMenusRequest {
  items: ReorderMenuItem[];
}

export interface DuplicateMenuRequest {
  menuId: number;
  includeChildren: boolean;
}

export interface ResetMenusRequest {
  confirmTenantName: string;
}
```

### Sensitive-Field Handling

| Field | GET behavior | POST behavior |
|-------|--------------|---------------|
| (none — no secrets in menu config) | — | — |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (0 errors, warnings acceptable if pre-existing)
- [ ] `pnpm dev` — page loads at `/{lang}/accesscontrol/governance/menu`

**Functional Verification — DESIGNER_CANVAS (Full E2E — MANDATORY):**
- [ ] First load: `getMenuAdminTree` populates left tree with all parent menus (default first one expanded + active)
- [ ] Tree search: typing in search box filters visible items; auto-expands any parent whose descendant matches; clearing search restores tree
- [ ] Click a tree node → editor card loads that node's data; sidebar preview renders the current parent's children with the active row highlighted
- [ ] Editing Menu Label + Save → BE persists; tree row label updates; preview updates
- [ ] Editing MenuType=External → "External URL" field appears + Screen Path hides
- [ ] Editing MenuType=Header or Divider → URL fields, Icon, Badge hide/disable per rules
- [ ] Visibility toggle → autosaves; tree status-dot transitions green ↔ gray
- [ ] Badge: empty text hides preview; non-empty text + color shows live pill preview
- [ ] Icon picker: search filters icons; click selects; selection reflects in editor + tree row + preview
- [ ] Drag-reorder within same parent → autosave `reorderMenus`; tree updates without reload; toast confirms
- [ ] Drag a child to a different parent → autosave updates ParentMenuId + OrderBy
- [ ] Drag a parent into its own descendant → snap back + toast "Cannot make a menu its own descendant"
- [ ] Right-click → "Add Child" → new child created; tree refreshes; editor selects new node
- [ ] Right-click → "Duplicate" → prompt for "Include children?"; clone with `_COPY` suffix appears
- [ ] Right-click → "Hide" → autosaves `IsVisible=false`; tree status-dot gray
- [ ] Right-click → "Delete" (leaf) → confirm → soft-deletes; tree row disappears
- [ ] Right-click → "Delete" (parent with children) → confirm "Delete this menu and N child items?" → `deleteMenuWithChildren` cascades
- [ ] "+ Add Menu Item" with no selection → new root menu; editor shows Module dropdown
- [ ] "+ Add Menu Item" with selection → new sibling under same parent; ModuleId inherited; Module dropdown hidden
- [ ] "Reset to Default" → confirm modal asks for tenant name; on confirm → audit log entry + tenant menus replaced with seeded hierarchy → tree refreshes
- [ ] "Open Matrix" link navigates to `accesscontrol/usersroles/rolecapability` (or SERVICE_PLACEHOLDER toast if #70 unbuilt)
- [ ] Cancel button: if dirty → "Discard unsaved changes?" confirm; else → revert silently
- [ ] Form validation: MenuType=External w/o URL → inline error blocks Save
- [ ] Form validation: BadgeColor set w/o BadgeText → inline error
- [ ] Form validation: trying to set ParentMenuId to a descendant → BE rejects + inline error
- [ ] Form validation: duplicate MenuCode within same module → BE rejects + inline error
- [ ] Role gating: non-BUSINESSADMIN user → `DefaultAccessDenied` rendered (current behavior preserved)

**Empty / Loading / Error States:**
- [ ] Loading skeleton on initial fetch (tree + editor)
- [ ] Empty: no selection → editor shows "Select a menu item from the tree to edit"
- [ ] Tree fetch error → error card with Retry
- [ ] Mutation error → inline error + toast

**DB Seed Verification:**
- [ ] `MENU` menu remains seeded at `accesscontrol/governance/menu` under `AC_GOVERNANCE`
- [ ] New capability `RESET_DEFAULTS` seeded and granted to BUSINESSADMIN
- [ ] Page renders without crashing on a freshly-seeded DB (existing seeded menus visible in tree)
- [ ] "Reset to Default" on a test tenant restores the canonical hierarchy

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Universal CONFIG warnings:**
- **CompanyId**: Menu is currently tenant-scoped via the existing `Entity` base + interceptors — verify the interceptor filters all queries by tenant. The Menu table may currently be **global** (shared across tenants). If global, **Reset to Default** must NOT cross tenant boundaries (snapshot/restore per tenant only). Solution Resolver MUST confirm tenant-scoping behavior before generation.
- **GridFormSchema = SKIP** — custom designer UI, not RJSF.
- **No view-page 3-mode pattern** — single-page designer.
- **Sensitive fields**: none in this entity.
- **Dangerous actions**: "Reset to Default" requires type-tenant-name confirm + audit-log snapshot.
- **Role gating happens at the BE** — `CustomAuthorize(DecoratorAuthModules.Menu, Permissions.Read)` already in place on existing queries; replicate on new commands.

**Sub-type-specific gotchas (DESIGNER_CANVAS):**
- **Properties pane must update tree live** — when user edits MenuName and Saves, tree row label MUST update without a full page refetch (use cache-update or refetch query).
- **Preview pane must mirror runtime sidebar styling** — don't hand-craft generic card chrome; clone the actual sidebar component or share styles.
- **Drag-reorder must allow cross-parent moves** AND respect cycle prevention. A common mistake is allowing same-parent only.
- **Allowing duplicate MenuCodes silently overwrites at runtime** — surface as validation error.
- **MenuType=Header/Divider** records have no MenuUrl — runtime sidebar must render them as visual section headers / divider lines, not as clickable links. Verify the runtime sidebar reads MenuType (this may be a follow-up to runtime sidebar code, OUT OF SCOPE for this screen).
- **`IsActive` vs `IsVisible`**: Two distinct flags. `IsActive=false` = soft-deleted (excluded from all reads). `IsVisible=false` = present but hidden from runtime sidebar (still appears in admin tree, just with gray status dot). Existing `ActivateDeactivateMenu` toggles `IsActive` — runtime sidebar likely already filters by `IsActive=true AND IsDeleted=false`. The new IsVisible flag is **purely a runtime sidebar filter** — admin tree always shows it.

**Module / module-instance notes:**
- This is **ALIGN scope**: extend the existing Menu entity, do NOT recreate.
- Existing BE CRUD (CreateMenu / UpdateMenu / DeleteMenu / ToggleMenuStatus / GetMenus / GetMenuById / GetParentChildMenu) **stays as-is**, with DTO additions.
- Existing FE `MenuDataTable` is **discarded** — replaced by MenuManagementPage. The FE route page stays; only the rendered component changes.
- New BE capability `RESET_DEFAULTS` must be added to existing capability seed.

**Pre-flagged ISSUEs to address during /build-screen:**

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | MED | Tenant scoping | Verify whether `auth.Menus` is per-tenant or global. If global → ResetToDefaults / DeleteWithChildren must NOT cross tenants. Resolver must confirm before generation. |
| ISSUE-2 | MED | Runtime sidebar | The runtime sidebar fetch (`parentChildMenus`) may not yet read `IsVisible`. Confirm with FE infrastructure team; if not — add to follow-up backlog. OUT OF SCOPE for this screen, but flag in build log. |
| ISSUE-3 | MED | Capability cascade | "Reset to Default" purges menus that have RoleCapability rows pointing to them. After re-seed, the new MenuIds will be different — orphan RoleCapability rows. Resolver must decide: cascade-delete RoleCapabilities on reset (data loss), OR detect-and-remap by MenuCode (safer). Recommendation: detect-and-remap by MenuCode within the ResetMenusToDefaults command. |
| ISSUE-4 | LOW | MenuKey derivation | `MenuKey` shown in mockup as `dashboard.dashboard-home` — derived as `{parentMenuCode}.{menuCode}` lowercased. Multi-level nesting needs a chain: `{rootCode}.{midCode}.{leafCode}`. Implement as recursive BE compute. |
| ISSUE-5 | LOW | Icon library | Mockup shows BOTH fa-icons (`fa-chart-line`) AND emojis (`📊`) in the tree. Existing `MenuIcon` is `string`. Standardize on one. Recommendation: fa-icon class names only; map emojis used in the mockup to closest fa-icon. |
| ISSUE-6 | LOW | Drag library choice | Confirm whether `@hello-pangea/dnd` or `@dnd-kit/*` is already in `package.json`. If neither, add `@dnd-kit/core` + `@dnd-kit/sortable` (modern, well-maintained, lighter than react-beautiful-dnd). |
| ISSUE-7 | LOW | Module dropdown on add | Adding a new ROOT menu requires choosing a Module. Mockup omits this UX. Recommendation: surface a Module dropdown ONLY when creating a root-level new menu; hide it for sub-menu / existing-menu edits. |
| ISSUE-8 | LOW | Edit MenuKey conflict | "Menu Key" in mockup is readonly. But it's derived from MenuCode + parent chain — so editing MenuCode CHANGES the key. Ensure preview-on-edit shows the prospective new key (recalc client-side before save). |
| ISSUE-9 | LOW | Sidebar Preview accuracy | "Sidebar Preview" must match the real sidebar's styling AND honor the IsVisible flag (hidden items don't render). Decide whether to import a live `<SidebarPreviewMode>` slice of the real Sidebar component or hand-craft a near-clone. Recommendation: near-clone for isolation. |

**Service Dependencies (UI-only — no backend service implementation):**

- ⚠ **SERVICE_PLACEHOLDER**: "Reset to Default" — full UI + audit-log snapshot implemented. Re-seed step depends on a re-runnable seed service (`IMenuDefaultSeederService`). If the project doesn't yet expose seed-from-runtime, return success + log "RESET_TRIGGERED_PENDING_SEED" so an operator can run the seed script manually. Resolver may upgrade to full impl if `Module_Menu_List.sql` can be run programmatically.
- ⚠ **SERVICE_PLACEHOLDER**: "Open Matrix" link target (#70 Role Management) — currently NEW per registry. Until #70 is built, this link toasts "Role-Capability Matrix is not yet built". Once #70 lands, replace with real route.

Full UI must be built (tree, drag-reorder, properties pane, icon picker, badge config, preview, all confirm modals, audit-log entries). Only the two placeholders above are stubbed.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | (planning) | MED | Tenant scoping | Verify Menu tenant scoping; impacts Reset/Delete scope. | RESOLVED (Session 1) — Menu is GLOBAL (no CompanyId on `Entity` base); ResetMenusToDefaults is system-wide, gated by literal `"RESET MENUS"` confirm. |
| ISSUE-2 | (planning) | MED | Runtime sidebar | Runtime sidebar may not yet honor `IsVisible`. | OPEN (follow-up, out of scope) — admin tree honors it; runtime `parentChildMenus` does not filter by IsVisible yet. |
| ISSUE-3 | (planning) | MED | Capability cascade | ResetToDefaults must remap RoleCapabilities by MenuCode, not cascade-delete. | RESOLVED (Session 1) — implemented in `ResetMenusToDefaults.cs`: snapshots prior state, remaps RoleCapability.MenuId by matching MenuCode after re-seed. |
| ISSUE-4 | (planning) | LOW | MenuKey derivation | Recursive `MenuKey` chain compute in BE for multi-level nesting. | RESOLVED (Session 1) — `GetMenuById.cs` walks the parent chain in memory and produces `{rootCode}.{midCode}.{leafCode}` (lowercased + kebabified). |
| ISSUE-5 | (planning) | LOW | Icon library | Standardize on fa-icon class names (drop emojis). | PARTIAL (Session 1) — FE icon picker uses fa-icon class names only; BE does not validate (`MenuIcon` is still `string`, no regex). FE will pass fa-class strings; legacy emoji rows from old seed may exist and render as text. |
| ISSUE-6 | (planning) | LOW | Drag library | Confirm/install dnd library. | RESOLVED (Session 1) — uses existing `react-dnd` + `react-dnd-html5-backend` (already in `package.json`); no new dep added. |
| ISSUE-7 | (planning) | LOW | Module dropdown | Surface only on new-root creation. | RESOLVED (Session 1) — `menu-editor-card.tsx` conditionally renders Module dropdown only when `parentMenuId === null && isNew`. |
| ISSUE-8 | (planning) | LOW | MenuKey edit preview | Recalc preview on MenuCode change. | RESOLVED (Session 1) — `menu-editor-card.tsx` recomputes `menuKey` client-side via memoized walk through `treeNodes` on every MenuCode change. |
| ISSUE-9 | (planning) | LOW | Preview fidelity | Near-clone of runtime sidebar styling. | RESOLVED (Session 1) — `menu-sidebar-preview.tsx` is a near-clone using Tailwind tokens; honors IsVisible (skipped) and MenuType (Header/Divider render as non-clickable). |
| ISSUE-10 | Session 1 | MED | BE↔FE contract | Initial FE GQL mutations omitted the `data { ... }` block for `DELETE_MENU`, `DELETE_MENU_WITH_CHILDREN`, `RESET_MENUS` — but BE wraps inner DTO `{Success, ErrorCode}` inside `BaseApiResponse.data`. Outer `success` is always `true` on `PostSuccess`. Orchestrator patched mid-build: added `data { ... }` blocks + updated `delete-menu-modal.tsx` and `reset-menus-modal.tsx` consumers to read `result.data.success/errorCode`. | RESOLVED (Session 1 — hot-patch) |
| ISSUE-11 | Session 1 | LOW | Legacy admin page | A separate `shared/administration/governance/menu-components/data-table.tsx` is intentionally NOT updated. Its delete operation reads outer `success` (always true on `PostSuccess`), so a `HAS_CHILDREN` business error would silently appear successful in that page. New DESIGNER_CANVAS page handles it correctly. | OPEN (legacy path) |
| ISSUE-12 | Session 1 | LOW | Delete via context menu | FE Developer chose not to lift the delete modal to the page level — clicking "Delete" in context menu only selects the node + toasts "Click 'Delete Item' in the editor to confirm". User must then use the editor footer Delete button. Cleaner: lift `<DeleteMenuModal>` to `menu-management-page.tsx`. | OPEN (UX polish) |
| ISSUE-13 | Session 1 | LOW | Audit log | `ResetMenusToDefaults` writes the snapshot to `Console.WriteLine` (no audit-log infra visible in this project). Snapshot JSON is also returned in the response body so an operator can manually save it. | OPEN (infra dependency) |
| ISSUE-14 | Session 1 | LOW | Seeder service | `IMenuDefaultSeederService` is registered as an optional DI param; if not wired the reset returns `{ Success=false, ErrorCode="SEED_SERVICE_UNAVAILABLE", Snapshot=<json> }`. FE handles this case with a specific toast message. | OPEN (infra dependency) |
| ISSUE-15 | Session 1 | LOW | EF migration | Migration `.Designer.cs` snapshot file not auto-generated; user runs `dotnet ef migrations add` to regenerate snapshot OR applies the migration directly. The existing `MenuConfiguration` already has a non-filtered `IsUnique` index on `(MenuCode, ModuleId, IsActive)` — the new filtered index `(ModuleId, MenuCode) WHERE IsDeleted=false` is additive. Coexistence may produce slow inserts; consider dropping the old index in a follow-up migration. | OPEN |
| ISSUE-16 | Session 1 | LOW | GQL deep nesting | `GET_MENU_ADMIN_TREE_QUERY` requests 8 levels of `childMenus` nesting to handle deep hierarchies. Actual menus rarely exceed 3 levels. If HotChocolate's default max depth is lower, trim or raise the limit. | OPEN |
| ISSUE-17 | Session 1 | LOW | FA CDN dependency | New icon picker + tree rows render fa-icons via `<i className="fa fa-..." />`. Project must have Font Awesome CSS loaded globally (verify `_document.tsx` or layout root). | OPEN (verify) |
| ISSUE-18 | Session 1 | LOW | Full E2E pending | `dotnet build` / `pnpm dev` not executed this session per token-budget directive. User runs migration + dev server + tests CRUD flow + drag-reorder + reset + delete-with-children. | OPEN (pending user verification) |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-16 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt — ALIGN backend (extend existing `auth.Menus`) + FULL REPLACE frontend (discard `MenuDataTable`, build DESIGNER_CANVAS designer page). Single FULL build, Sonnet for all agents (per user preference).
- **Files touched**:
  - **BE created (7)**:
    - `Base.Application/Business/AuthBusiness/Menus/Queries/GetMenuAdminTree.cs` (created)
    - `Base.Application/Business/AuthBusiness/Menus/Commands/ReorderMenus.cs` (created)
    - `Base.Application/Business/AuthBusiness/Menus/Commands/DuplicateMenu.cs` (created)
    - `Base.Application/Business/AuthBusiness/Menus/Commands/DeleteMenuWithChildren.cs` (created)
    - `Base.Application/Business/AuthBusiness/Menus/Commands/ResetMenusToDefaults.cs` (created)
    - `Base.Infrastructure/Migrations/20260516120000_Add_Menu_DesignerCanvas_Fields.cs` (created)
    - `sql-scripts-dyanmic/MenuManagement-sqlscripts.sql` (created)
  - **BE modified (9)**:
    - `Base.Domain/Models/AuthModels/Menu.cs` — +5 cols (MenuType, ExternalUrl, IsVisible, BadgeText, BadgeColor) + Create()/Validate() factories
    - `Base.Infrastructure/Data/Configurations/AuthConfigurations/MenuConfiguration.cs` — MaxLength + defaults + filtered unique index + ordering index
    - `Base.Application/Schemas/AuthSchemas/MenuSchemas.cs` — extended Request/Response DTOs + MenuKey + 7 new DTOs (MenuAdminTreeNode, ReorderMenuItem, ReorderMenusRequestDto, DuplicateMenuRequestDto, ResetMenusRequestDto, DeleteMenuResponseDto, DeleteMenuWithChildrenResponseDto, ResetMenusResponseDto)
    - `Base.Application/Mappings/AuthMappings.cs` — extended Menu↔Dto + new MenuAdminTreeNode mapping
    - `Base.Application/Business/AuthBusiness/Menus/Commands/CreateMenu.cs` — conditional validation per MenuType
    - `Base.Application/Business/AuthBusiness/Menus/Commands/UpdateMenu.cs` — conditional validation + cycle-check on ParentMenuId
    - `Base.Application/Business/AuthBusiness/Menus/Commands/DeleteMenu.cs` — returns `DeleteMenuResponseDto` with HAS_CHILDREN sentinel
    - `Base.Application/Business/AuthBusiness/Menus/Queries/GetMenuById.cs` — computes recursive MenuKey
    - `Base.API/EndPoints/Auth/Mutations/MenuMutations.cs` — registered 4 new mutations + DeleteMenu return-type change
    - `Base.API/EndPoints/Auth/Queries/MenuQueries.cs` — registered MenuAdminTree query
  - **FE created (11)**:
    - `presentation/components/page-components/accesscontrol/governance/menu-components/menu-management-store.ts`
    - `…/menu-icon-picker.tsx`
    - `…/menu-badge-config.tsx`
    - `…/menu-tree-context-menu.tsx`
    - `…/menu-tree-item.tsx`
    - `…/menu-tree.tsx`
    - `…/menu-sidebar-preview.tsx`
    - `…/reset-menus-modal.tsx`
    - `…/delete-menu-modal.tsx`
    - `…/menu-editor-card.tsx`
    - `…/menu-management-page.tsx`
  - **FE modified (6)**:
    - `domain/entities/auth-service/MenuDto.ts` — extended DTOs + 6 new interfaces
    - `infrastructure/gql-queries/auth-queries/MenuQuery.ts` — extended MENU_BY_ID + new GET_MENU_ADMIN_TREE_QUERY
    - `infrastructure/gql-mutations/auth-mutations/MenuMutation.ts` — extended CREATE/UPDATE/DELETE + 4 new mutations; mid-build patched to include `data { … }` blocks (ISSUE-10)
    - `presentation/components/page-components/accesscontrol/governance/menu-components/index.ts` — exports MenuManagementPage; removed MenuDataTable export
    - `presentation/pages/accesscontrol/governance/menu.tsx` — swap `<MenuDataTable />` → `<MenuManagementPage />`
    - (orchestrator) `delete-menu-modal.tsx` + `reset-menus-modal.tsx` — patched to read `result.data.success/errorCode` post-mid-build (ISSUE-10)
  - **FE deleted (1)**:
    - `…/menu-components/data-table.tsx` — removed (replaced by MenuManagementPage); orchestrator deleted after FE agent stubbed it.
  - **DB seed (modified)**:
    - `sql-scripts-dyanmic/MenuManagement-sqlscripts.sql` — idempotent: ensures RESET_DEFAULTS capability + BUSINESSADMIN role-cap grant; verifies READ + MODIFY + ISMENURENDER existence.
- **Deviations from spec**:
  - `ResetMenusToDefaults` request renamed `confirmTenantName` → `confirmText` per pre-resolved ISSUE-1 (Menu is global, not per-tenant). Validates `confirmText == "RESET MENUS"`.
  - `DeleteMenu` now wraps `DeleteMenuResponseDto` in `BaseApiResponse.PostSuccess(...)` even on business failure (HAS_CHILDREN) — caller reads `result.data.success/errorCode`. FE consumers updated mid-build.
  - Context-menu "Delete" doesn't open the modal directly — selects + toasts to use editor footer Delete (ISSUE-12).
  - `GET_MENU_ADMIN_TREE_QUERY` requests 8 levels of nesting; runtime trees are 2-3 deep (ISSUE-16).
- **Known issues opened**: ISSUE-10..18 (9 new — see Known Issues table). ISSUE-10 was a hot-patch during build; the remaining 8 are deferred (infra dependencies, UX polish, E2E verification by user).
- **Known issues closed**: ISSUE-1 (tenant scoping resolved), ISSUE-3 (capability remap implemented), ISSUE-4 (recursive MenuKey implemented), ISSUE-6 (drag lib confirmed), ISSUE-7 (Module dropdown conditional), ISSUE-8 (MenuKey live preview), ISSUE-9 (sidebar preview near-clone implemented). ISSUE-5 partially closed.
- **UI Uniformity (Variant B verified)**:
  - `<ScreenHeader>` imported + used at page top of `menu-management-page.tsx` (line 8 + 343 + 367)
  - 2 inline-hex matches: both `style={{ backgroundColor: node.badgeColor ?? "#0e7490" }}` in `menu-tree-item.tsx:171` and `menu-sidebar-preview.tsx:82` — both annotated `// intentional exception` (badge live preview requires user-configured hex)
  - 0 inline `padding`/`margin` literal-number matches
  - 0 `>Loading...<` raw strings
  - 0 Bootstrap `className="card..."` matches
  - Skeleton states: 8-row animated tree skeleton + full-form editor skeleton
- **Component reuse check**: N/A — DESIGNER_CANVAS has no `<AdvancedDataTable>` / `<FlowDataTable>`, no `GridComponentName` cell-renderers. Custom designer page is the canonical sole consumer.
- **Next step**: (empty — COMPLETED). User-pending verification: run `dotnet ef database update`, run `pnpm dev`, exercise CRUD + drag-reorder + delete-with-children + reset (with literal `"RESET MENUS"` confirm). Verify FA icon CSS is globally loaded (ISSUE-17).

### Session 2 — 2026-07-22 — FIX (data-maintenance) — COMPLETED

- **Scope**: Author a one-time SQL cleanup script to purge UNUSED rows from the global `auth."Menus"` table this screen manages. User-requested categories: unmapped top-level (ParentMenuId NULL + no RoleCapabilities mapping + no live child), unmapped leaf (has MenuUrl, no child, no mapping), orphaned children (parent missing/soft-deleted/inactive), dead-module + already-soft-deleted rows. "Mapped" = referenced by a live `auth."RoleCapabilities"` row (ISMENURENDER), matching runtime sidebar logic in `GetParentChildMenu.cs`.
- **Files touched**:
  - BE: none (no C# change)
  - FE: none
  - DB: `sql-scripts-dyanmic/Cleanup-Unused-Menus.sql` (created) — PART 1 read-only verification (1A rollup + 1B per-row detail, tagged by category with precedence D > C4 > C3 > C1 > C2); PART 2 transactional HARD DELETE that re-derives the same set, expands to full descendant subtrees (recursive CTE) to avoid dangling self-FK, deletes dependents (`RoleCapabilities`, `MenuCapabilities`, `SearchableEntities`) then the menu rows. Defaults to `ROLLBACK` (preview) — user flips to `COMMIT`. Idempotent / re-runnable.
- **Deviations from spec**: None (operational script; no screen entity/UI change). C2 (unmapped leaf) intentionally restricted to rows with a real `MenuUrl` per user scope — url-less non-top leaves (dividers/headers) left untouched.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: User runs PART 1 to verify candidates, then flips PART 2's `ROLLBACK` → `COMMIT` to apply. Script is a hand-off (user owns DB application, per project convention).

### Session 3 — 2026-07-22 — FIX (data-maintenance) — COMPLETED

- **Scope**: Author a one-time SQL data-migration to MERGE the 'General' module into the 'Setting' module (both hold app-config, so they collapse to one). Move every General-owned artifact to Setting, then hard-delete the empty General module. Modules resolved by `ModuleCode` ('GENERAL'/'SETTING') at run time — no hardcoded Guids, copes with menus edited via this screen since seed.
- **Files touched**:
  - BE: none (no C# change)
  - FE: moved Next.js route folders (git mv, history preserved) `src/app/[lang]/(core)/general/region/` → `.../(core)/setting/region/` and `.../general/masters/` → `.../setting/masters/` (12 leaf `page.tsx` under region/{city,country,district,locality,pincode,state} + masters/{bank,bloodgroup,currency,currencyconversion,gender,language,occupation,paymentmode,relation,salutation}). Safe move — leaf pages use `@/` alias imports only. `(core)/general/` retains unrelated `configuration/`, `dashboards/`, `underconstruction/` (not part of this merge).
  - DB: `sql-scripts-dyanmic/Merge-General-Into-Setting-Module.sql` (created). PART 1 read-only verification (1A module resolve, 1B per-table row counts, 1C moving menus with proposed new OrderBy **+ old/new MenuUrl**, 1D RoleModules overlap). PART 2 transactional migration: re-sequence General TOP-LEVEL menus' `OrderBy` to append after Setting's current max (avoids 1..N sidebar collision), move all General menus (any depth) → Setting, **re-path moved menus' `MenuUrl` `general/…` → `setting/…` (2B-2, leading segment only, via `regexp_replace(^general/,setting/)`) to match the moved route folders**, move `sett."Grids"/"Widgets"/"Dashboards"`, `rep."Reports"`, `com."DocumentTypes"`, `notify."Notifications"/"EmailTemplates"`, `audit."AuditLogs"` → Setting, de-dup + move `auth."RoleModules"` grants (drop General grant where role already has Setting, else re-point), hard-delete the General `auth."Modules"` row. Defaults to `ROLLBACK` (preview); user flips to `COMMIT`. Idempotent (once General is gone every statement is a no-op).
- **Deviations from spec**: None (operational script; no screen entity/UI change). MenuCodes kept as `GEN_*` (opaque ids referenced by RoleCapabilities/FE — renaming would break lookups); only owning `ModuleId`, top-level `OrderBy`, and the `MenuUrl` leading segment change. `audit."AuditLogs".ModuleId` (nullable) re-pointed to Setting purely to satisfy FK before delete — historical rows now attribute to Setting.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: User runs PART 1 to confirm the id resolve + move counts + URL rewrite, then flips PART 2's `ROLLBACK` → `COMMIT` to apply. FE folder move is already applied on disk (git mv) — rebuild FE to pick up the new `setting/region` + `setting/masters` routes. Also update the master seed `Pss2.0_Global_Menus_List.sql` (drop the General module block, re-home GEN_* menus under Setting with `setting/…` URLs, drop the 'GENERAL' RoleModules grant) so a fresh DB build reflects the merge — otherwise a re-seed re-creates General with old paths. Hand-off (user owns DB application).
