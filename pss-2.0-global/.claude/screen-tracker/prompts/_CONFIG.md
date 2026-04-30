# Screen Prompt Template — CONFIG (v1)

> For screens that **configure the system** rather than transact through it.
> Covers tenant-level settings, designer/editor canvases, and matrix-style configurations.
> Canonical reference: **TBD** — first CONFIG screen sets the convention per sub-type.
>
> Use this when the mockup is one of:
> - A **single-record settings page** (multi-section form, may have tabs/sidebar/accordion, often save-per-section, may include "test connection" / "regenerate" / "reset to defaults") — `SETTINGS_PAGE`
> - A **designer/editor canvas** (palette/toolbox + canvas + properties panel + preview pane — e.g. custom-field designer, form builder, workflow designer) — `DESIGNER_CANVAS`
> - A **matrix grid** (N×M cells of role × capability, module × tenant, period × rate, etc., bulk-edited inline) — `MATRIX_CONFIG`
>
> Do NOT use for:
> - List-of-N lookup CRUDs (use `_MASTER_GRID.md` — e.g. ContactType, DonationCategory)
> - Transactional 3-mode workflows (use `_FLOW.md` — e.g. EmailTemplate, CompanyEmailProvider when treated as a list of providers)
> - Widget overviews (use `_DASHBOARD.md`)
> - Parameterized reports (use `_REPORT.md`)
>
> ---
>
> ### 🧠 Each CONFIG screen is UNIQUE — the developer owns the design
>
> **The patterns below are scaffolding, not a frozen spec.** Every config screen carries a different
> business case (tax setup ≠ SMTP setup ≠ role matrix ≠ field designer), so:
>
> 1. **Read the business context first** — what entities, workflows, and personas does this
>    config govern? What decisions does it enable? Who edits it, how often, and what breaks
>    if mis-set? The answer shapes the section structure, save model, and gating — not a
>    template.
> 2. **Pick the sub-type that fits** — `SETTINGS_PAGE` / `DESIGNER_CANVAS` / `MATRIX_CONFIG`
>    (or hybrid). Stamp it in §⑤. If none of the three fit cleanly, propose a new sub-type
>    in §⑫ ISSUE entry rather than forcing a poor fit.
> 3. **Design the layout per case** — section grouping reflects ACTUAL settings clusters, not
>    a generic "Basic / Advanced" split. Save model (save-per-section / save-all / autosave)
>    chosen by edit cadence. Sensitive-field treatment, audit trail, and role gating chosen
>    by risk, not boilerplate.
> 4. **Vary the visual treatment** — a tax config (rates table + effective dates) looks
>    different from a notification preferences page (toggle list) which looks different from
>    a custom-field designer (canvas + properties). Reusing identical card chrome across
>    dissimilar configs is wrong.
> 5. **Document deviations** — if the developer departs from the prompt's section list or
>    save model based on business context, log the deviation in §⑫ ISSUE entry with the why.

---

## Template

```markdown
---
screen: {EntityName}
registry_id: {#}
module: {Module Name}
status: PENDING
scope: {FULL | BE_ONLY | FE_ONLY | ALIGN}
screen_type: CONFIG
config_subtype: {SETTINGS_PAGE | DESIGNER_CANVAS | MATRIX_CONFIG}
complexity: {Low | Medium | High}
new_module: {YES — schema name | NO}
planned_date: {YYYY-MM-DD}
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type identified: SETTINGS_PAGE / DESIGNER_CANVAS / MATRIX_CONFIG)
- [x] Business context read (entities governed, edit cadence, personas, risk-of-misconfig)
- [x] Storage model identified (singleton row / definition rows / matrix join table)
- [x] Save model chosen (save-per-section / save-all / autosave)
- [x] Sensitive fields & role gates identified
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated (config purpose + edit personas + risk)
- [ ] Solution Resolution complete (sub-type confirmed, save model confirmed)
- [ ] UX Design finalized (section layout / canvas layout / matrix shape — per sub-type)
- [ ] User Approval received
- [ ] Backend code generated          ← skip if FE_ONLY
- [ ] Backend wiring complete         ← skip if FE_ONLY
- [ ] Frontend code generated         ← skip if BE_ONLY
- [ ] Frontend wiring complete        ← skip if BE_ONLY
- [ ] DB Seed script generated (default config row + GridFormSchema only when applicable)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at correct route
- [ ] **Sub-type-specific checks** (pick the matching block):
  - SETTINGS_PAGE:
    - [ ] All sections render in correct order with correct grouping
    - [ ] Each section's save persists (save-per-section model) OR full-page save persists (save-all)
    - [ ] Validation errors block save and surface inline per field
    - [ ] Sensitive fields masked on display (passwords, API keys); write-only on save
    - [ ] Read-only system fields render as read-only and never POST
    - [ ] Test/verify actions (test connection, send test email) trigger handler (real or SERVICE_PLACEHOLDER)
    - [ ] Dangerous actions (reset, regenerate key) gated behind confirm dialog
    - [ ] Default-config row seeded (so first load doesn't 404)
    - [ ] Role-gated sections hidden / read-only for non-privileged roles
  - DESIGNER_CANVAS:
    - [ ] Canvas + palette + properties panel render
    - [ ] Drag/click adds an item to the canvas; selecting it loads properties
    - [ ] Properties edit updates canvas live
    - [ ] Reorder works (drag handle / up-down arrows)
    - [ ] Delete works with confirm
    - [ ] Preview pane updates from current canvas state
    - [ ] Save persists the full schema; reload restores exact state
    - [ ] Validation: required-children, unique-keys, type-rules enforced before save
  - MATRIX_CONFIG:
    - [ ] Matrix renders all rows × all columns
    - [ ] Cell type renders correctly (checkbox / dropdown / number / chip toggle)
    - [ ] Cell change marks dirty; save persists diff (not full grid)
    - [ ] Row-level "select all" / "clear all" + column-level bulk works
    - [ ] Filter/search narrows visible rows or columns
    - [ ] Read-only cells (e.g. system roles) render disabled and do not POST
- [ ] Empty / loading / error states render
- [ ] DB Seed — menu visible in sidebar at correct parent

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: {EntityName}
Module: {ModuleName}
Schema: {db_schema}
Group: {BackendGroupName}

Business: {Rich description — 5-7 sentences covering:
  - WHAT this configuration governs (tax rates, SMTP credentials, role permissions, custom field definitions, …)
  - WHO edits it (BUSINESSADMIN only? Module admin? Multi-role?) and HOW OFTEN (one-time setup / quarterly / per-fiscal-year / rare-but-critical)
  - WHY it exists in the NGO workflow (what downstream behavior depends on it — e.g. "tax rates feed all donation receipt calculations")
  - WHAT BREAKS if mis-set — risk profile (missing SMTP = no notifications fire; wrong tax rate = legal/audit risk; wrong role matrix = privilege escalation)
  - HOW it relates to other screens in the same module (does it gate a workflow? Does it populate dropdowns elsewhere?)
  - WHAT'S unique about this config's UX vs. a generic settings page (e.g. "Tax config has effective-from/effective-to dates per row — historical rates must be preserved")}

> **Why this section is heavier than other types**: CONFIG screens have no canonical layout —
> the design is derived from the business case. The richer §① is, the better the developer
> can design the right §⑥ blueprint.

---

## ② Storage Model

> **Consumer**: BA Agent → Backend Developer
> CONFIG storage shapes diverge sharply by sub-type. Pick the matching pattern and fill in.

**Storage Pattern** (REQUIRED — stamp one):

| Pattern | Use when | Cardinality | Typical Sub-type |
|---------|----------|-------------|------------------|
| `singleton-per-tenant` | Exactly one config record per Company (e.g. tenant settings, tax setup with current rates only, SMTP credentials) | 1 row × N tenants | SETTINGS_PAGE |
| `keyed-settings-rows` | Many key/value rows per tenant (e.g. notification preferences with one row per channel, feature flags) | N rows × M tenants | SETTINGS_PAGE |
| `definition-list` | Many definitions managed via a designer (e.g. CustomFieldDefinition rows, WorkflowStateDefinition rows) | N definition rows + 1 parent FK | DESIGNER_CANVAS |
| `matrix-join` | Join table representing N×M cells (e.g. RoleCapability with `(RoleId, CapabilityId, IsAllowed)`) | N×M rows in a join | MATRIX_CONFIG |

**Stamp**: `{singleton-per-tenant | keyed-settings-rows | definition-list | matrix-join}`

### Tables

> List every table touched. Audit columns omitted — inherited from `Entity` base.
> CompanyId is **always** present (CONFIG is tenant-scoped) but in the SETTINGS_PAGE singleton
> pattern, the row is fetched **by HttpContext tenant**, not exposed as a form field.

Primary table: `{schema}."{TableName}"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| {EntityName}Id | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (NOT a form field for singleton pattern) |
| {field…} | … | … | … | … | … |

**Singleton constraint** (singleton-per-tenant pattern):
- Unique index on `(CompanyId)` — exactly one row per tenant
- First-load behavior: if no row exists, BE auto-creates a default row with seeded defaults

**Composite key** (matrix-join pattern):
- Composite unique on `({RowId}, {ColumnId})` — one cell per pair
- Cell value column: `{IsAllowed | Value | …}`

**Definition parent** (definition-list pattern):
- FK back to a parent entity (e.g. `FormSchemaId`, `WorkflowId`)
- Order field: `DisplayOrder` (int) — supports reorder

**Child Tables** (if any):
| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| {ChildName} | 1:Many via {EntityName}Id | {field1}, {field2} |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| {FK1}Id | {Target1} | Base.Domain/Models/{Group}Models/{Target1}.cs | GetAll{Target1}List | {Target1}Name | {Target1}ResponseDto |
| ... | ... | ... | ... | ... | ... |

**Matrix sources** (matrix-join only):
| Axis | Source Entity | GQL Query | Order Field | Read-only Filter |
|------|--------------|-----------|-------------|-------------------|
| Rows | {e.g. Role} | GetAllRoleList | RoleName | exclude SYSTEM roles |
| Columns | {e.g. Capability} | GetAllCapabilityList | CapabilityCode | — |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Singleton / Cardinality Rules:**
- {e.g. "Only one settings row per tenant — Update only, no Create/Delete via API"}
- {e.g. "Default row auto-seeded on first GET if missing — values from `{Group}DefaultSettings` constants"}
- {e.g. "Matrix: SYSTEM roles row is read-only — UI hides edit, BE rejects mutation"}

**Required Field Rules:**
- {Critical fields that must always have a value — listed per section}

**Conditional Rules:**
- {e.g. "If `EmailEnabled = true`, then SMTP host + port + auth credentials are required"}
- {e.g. "If `ReceiptNumberingMode = 'Per-Year'`, then `YearResetMonth` must be 1-12"}
- {e.g. "Field of type `dropdown` requires `OptionsJson` to be a non-empty array"}

**Sensitive Fields** (masking, audit, role-gating):
| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| {SmtpPassword} | secret | masked (`••••••••`), never sent in GET response | write-only — empty string ⇒ unchanged | log "credential rotated" event |
| {ApiKey} | secret | last-4 visible (`…XXXX`) on read; full value on regenerate only | regenerate replaces; old value never recoverable | log + email tenant admin |
| {TaxRate} | regulatory | plain | normal | log every change with old→new + actor |

**Read-only / System-controlled Fields:**
- {e.g. "`InstallationId`, `LicensedUntil` — set by system, never editable by admin"}

**Dangerous Actions** (require confirm + audit):
| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Reset to Defaults | Overwrites all editable fields with seeded defaults | Modal with "Type {tenant} to confirm" | log "config reset" |
| Regenerate API Key | Issues new key, invalidates old | Modal with warning | log + email tenant admin |
| Disable Module | Hides module from sidebar for all roles | Modal | log |

**Role Gating** (which sections / fields are visible / editable per role):
| Role | Sections Visible | Sections Editable | Notes |
|------|------------------|-------------------|-------|
| BUSINESSADMIN | all | all | full access |
| {e.g. STAFFADMIN} | {sections 1-3} | {section 1 only} | cannot edit credentials |

**Workflow** (rare for CONFIG — only if config has draft → publish pattern):
- {e.g. "Draft config saved on autosave; admin clicks 'Publish' to apply globally"}
- {States, transitions, side effects — or "Workflow: None"}

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: CONFIG
**Config Sub-type**: `{SETTINGS_PAGE | DESIGNER_CANVAS | MATRIX_CONFIG}`
**Storage Pattern**: `{singleton-per-tenant | keyed-settings-rows | definition-list | matrix-join}`
**Save Model** (REQUIRED — stamp one):

| Save Model | When to pick | UI cue |
|------------|--------------|--------|
| `save-all` | Few sections, edits are usually one-shot, all fields validated together | Single "Save" button at bottom / sticky footer |
| `save-per-section` | Many sections, sections are semantically independent, partial saves are valuable | Each section has its own "Save" button + "Discard" |
| `autosave` | Designer canvases or matrix where every keystroke / cell change should persist | No save button; debounced PATCH on change; subtle "Saved at HH:MM" indicator |

**Reason**: {1-2 sentences — why this sub-type and save model fit the business case from §①}

**Backend Patterns Required:**

For **SETTINGS_PAGE (singleton-per-tenant)**:
- [x] Get{Entity}Settings query — fetches by tenant from HttpContext, auto-seeds default if missing
- [x] Update{Entity}Settings mutation — accepts full or partial payload, validates per-section
- [ ] Update{Section}Settings mutation per section — only when save-per-section
- [ ] ResetTo{Entity}Defaults mutation — overwrites with seeded defaults, audit-logged
- [ ] Test{Capability} mutation (e.g. TestSmtpConnection) — calls external service or SERVICE_PLACEHOLDER
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Sensitive-field handling (mask on read, write-only on update)
- [ ] Audit-trail emission for sensitive / regulatory fields

For **SETTINGS_PAGE (keyed-settings-rows)**:
- [x] GetAll{Entity}Settings query — returns rows for tenant
- [x] BulkUpdate{Entity}Settings mutation — upsert by key
- [x] Default-key seeder on first GET
- [x] Tenant scoping

For **DESIGNER_CANVAS**:
- [x] GetDesignerSchema query — full state of all definitions for parent
- [x] Standard CRUD on definition entity (Create / Update / Delete / Reorder)
- [x] BulkUpdate{Entity}Schema mutation — accepts full diff (added / updated / deleted / reordered)
- [x] Schema-validation business rules (unique keys, valid types, no orphans)
- [ ] Versioning — keep prior schema snapshot when published

For **MATRIX_CONFIG**:
- [x] Get{Matrix} query — returns 2D state (cells + axes metadata)
- [x] BulkUpdate{Matrix} mutation — accepts diff (only changed cells, not full grid)
- [x] Cell-level validation (e.g. "SYSTEM role cells immutable")
- [x] Tenant scoping

**Frontend Patterns Required:**

For **SETTINGS_PAGE**:
- [x] Custom multi-section page (NOT RJSF modal, NOT view-page 3-mode)
- [x] Section container — tabs / sidebar nav / accordion / vertical stack (pick by section count)
- [x] Section component per section (own React component, own form hook, own save handler)
- [x] Sensitive-field input (masked, regenerate button, copy-to-clipboard)
- [x] Read-only system-field display (chip / disabled input)
- [x] Confirm dialog for dangerous actions
- [x] Save indicator (saved-at timestamp / dirty badge / unsaved-changes blocker)

For **DESIGNER_CANVAS**:
- [x] Three-pane layout: palette (left) / canvas (center) / properties (right)
- [x] Drag-and-drop or click-to-add from palette to canvas
- [x] Item selection on canvas → loads into properties pane
- [x] Live preview pane (separate panel or modal)
- [x] Reorder controls (drag handle or up/down arrows)
- [x] Validation summary panel (errors block save)
- [x] Autosave with explicit "Publish" if versioning enabled

For **MATRIX_CONFIG**:
- [x] Matrix table component (sticky header column + sticky header row)
- [x] Cell renderer per cell type (checkbox / chip / number / dropdown)
- [x] Row & column header click for bulk select
- [x] Filter / search to narrow rows or columns
- [x] Dirty-cell indicator + Save All / Discard
- [x] Read-only cells render visually disabled

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: This section is the design spec. Each CONFIG screen has a UNIQUE shape — fill
> in **only the sub-type block that applies** plus the shared blocks at the bottom. Delete the
> blocks that don't apply when generating the actual screen prompt.

### 🎨 Visual Uniqueness Rules (apply to ALL sub-types)

> Same intent as the dashboard rule: avoid uniform-clone layouts. Different settings have
> different visual weight.

1. **Vary section emphasis** — primary settings (e.g. "SMTP Credentials" for an email config)
   get a hero card with stronger heading, distinct accent, and prominent save button.
   Secondary / advanced settings can be collapsed or in a subtle accordion. Don't render
   every section with identical card chrome.
2. **Match section layout to content shape**:
   - 2-3 short fields → single-column compact card
   - Many short fields (10+) → 2-column grid card
   - Long-form fields (URLs, JSON blobs, code) → full-width section
   - Tabular data (rate tables, list with rows) → embedded table inside card
   - On/off preferences (10+ toggles) → switch list, not 10 separate fields
3. **Sensitive fields are visually distinct** — masked input + monospace font + regenerate
   button + copy-to-clipboard. Don't dress them as plain text inputs.
4. **Read-only system fields** render as chips or disabled fields with a subtle "system" badge,
   not as editable inputs that just happen to ignore changes.
5. **Section icons are semantic** — pick @iconify Phosphor icons that communicate the section's
   purpose (key icon for credentials, gauge icon for rates, shield icon for security).
   Don't use a generic gear icon for every section.
6. **Save / status affordances are sized to risk** — autosave shows a quiet "Saved at HH:MM";
   save-all shows a sticky footer with primary button; dangerous actions get a separate
   destructive-styled button visually segregated from normal save.

**Anti-patterns to refuse**:
- 4 unrelated settings cards using identical card chrome with only the title swapped
- All fields rendered the same regardless of sensitivity / read-only status / risk
- Generic "Basic Settings / Advanced Settings" split that doesn't match how the business
  thinks about the config
- Single huge form with no section structure for a 30-field config
- Save button glued to the bottom of a 5-section page that should save per section
- All section icons being a gear

---

### 🅰️ Block A — SETTINGS_PAGE (fill if sub-type = SETTINGS_PAGE)

#### Page Layout

**Container Pattern** (REQUIRED — stamp one): `{tabs | sidebar-nav | accordion | vertical-stack}`

| Container | When to pick | Example |
|-----------|--------------|---------|
| `tabs` | 3-6 sections, each visited independently, save-per-section preferred | Tenant Settings: General / Branding / Notifications / Integrations |
| `sidebar-nav` | 6+ sections, deep hierarchy, scroll-to-section feel | Module Settings with 12+ groups |
| `accordion` | 3-8 sections, partial visibility wanted, save-all OK | Tax Configuration |
| `vertical-stack` | 1-3 sections, all visible, save-all | SMTP Setup |

**Page Header**: page title + subtitle + global actions (Reset to Defaults / Test / Help)

#### Section Definitions

> One row per section. Order matches mockup.

| # | Section Title | Icon (Phosphor) | Container Slot | Save Mode | Role Gate |
|---|---------------|-----------------|----------------|-----------|-----------|
| 1 | {e.g. "SMTP Server"} | `ph:envelope-simple` | tab-1 | save-per-section | BUSINESSADMIN |
| 2 | {e.g. "Authentication"} | `ph:key` | tab-2 | save-per-section | BUSINESSADMIN |
| 3 | {e.g. "Send Behavior"} | `ph:paper-plane-tilt` | tab-3 | save-per-section | BUSINESSADMIN |
| 4 | {e.g. "Test & Diagnostics"} | `ph:test-tube` | tab-4 | (no save — actions only) | BUSINESSADMIN |
| ... | ... | ... | ... | ... | ... |

#### Field Mapping per Section

> One block per section. Repeat. Detail shown for §1 only — replicate.

**Section 1 — {Section Title}**

| Field | Widget | Default | Validation | Sensitivity | Notes |
|-------|--------|---------|------------|-------------|-------|
| {smtpHost} | text | `smtp.{tenant}.com` | required, hostname | normal | — |
| {smtpPort} | number | 587 | required, 1-65535 | normal | — |
| {smtpUseTls} | switch | true | — | normal | — |
| {smtpUsername} | text | — | required if `smtpAuthEnabled` | normal | — |
| {smtpPassword} | password-mask | — | required if `smtpAuthEnabled` | secret | masked, write-only |
| {fromAddress} | email | — | required, email format | normal | — |
| {fromName} | text | `{tenantName} Notifications` | required | normal | — |

**Section 1 Actions** (in addition to Save):
| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Test SMTP | "Send Test Email" | secondary | input modal asking for recipient email | TestSmtpConnection mutation |
| Regenerate API Key | "Regenerate" | destructive | "Existing key will stop working immediately" | RegenerateApiKey mutation |
| Reset Section | "Reset" | tertiary | "Restore section defaults?" | ResetSection mutation |

#### Page-Level Actions

| Action | Position | Style | Permission | Confirmation |
|--------|----------|-------|------------|--------------|
| Reset to Defaults | top-right | destructive | BUSINESSADMIN | type-tenant-name confirm |
| Export Config | top-right | secondary | BUSINESSADMIN | — (download file) |
| Import Config | top-right | secondary | BUSINESSADMIN | preview diff before apply |

#### User Interaction Flow (SETTINGS_PAGE)

1. User opens config screen → page loads → BE auto-seeds defaults if first time → tabs/sections render
2. User edits fields in section 1 → section becomes dirty → "Save" button enables
3. User clicks Save in section 1 → validation runs → on success: PATCH fires → toast "Saved" → section becomes clean
4. User navigates away with dirty section → confirm dialog "Discard unsaved changes?"
5. User clicks "Test SMTP" → modal asks for recipient email → handler fires → toast result
6. User clicks "Reset to Defaults" → confirmation modal → on confirm → all sections revert + audit log entry

---

### 🅱️ Block B — DESIGNER_CANVAS (fill if sub-type = DESIGNER_CANVAS)

#### Page Layout

**Three-pane layout** (typical):

```
┌─────────────────────────────────────────────────────────────┐
│  Designer: {Entity Name}                  [Preview] [Save]  │
├──────────┬──────────────────────────────────┬───────────────┤
│ PALETTE  │ CANVAS                           │ PROPERTIES    │
│          │                                  │               │
│ • Item A │ ┌──────────────────────────────┐│ Selected:     │
│ • Item B │ │ Item 1   [drag handle]   [×] ││  Item 1       │
│ • Item C │ │ Item 2   [drag handle]   [×] ││  Type:  …     │
│ • …      │ │ Item 3   [drag handle]   [×] ││  Label: …     │
│          │ │ + Add item from palette      ││  Required: ☐  │
│          │ └──────────────────────────────┘│  Options: …   │
└──────────┴──────────────────────────────────┴───────────────┘
```

**Variant — Stage / Linear Designer** (e.g. workflow / approval-chain):

```
┌─────────────────────────────────────────────────────────────┐
│ Stage 1 ──→ Stage 2 ──→ Stage 3 ──→ Stage 4   [+ Add Stage] │
│   │           │           │           │                      │
│  [edit]     [edit]      [edit]      [edit]                  │
└─────────────────────────────────────────────────────────────┘
```

#### Palette

| Item | Icon | Description | Accepts Children | Default Properties |
|------|------|-------------|------------------|---------------------|
| {Text Field} | `ph:text-aa` | Plain single-line input | NO | `{ key: '', label: '', required: false }` |
| {Dropdown} | `ph:caret-down` | Select from options | NO | `{ key: '', options: [], defaultOption: '' }` |
| {Section} | `ph:rectangle-dashed` | Group container | YES | `{ title: '', collapsed: false }` |
| {File Upload} | `ph:upload-simple` | File picker | NO | `{ accept: '*/*', maxSizeMb: 10 }` |
| ... | ... | ... | ... | ... |

#### Canvas Item Behavior

- **Add**: drag from palette OR click palette item → append to canvas (or insert above selected)
- **Select**: click item → highlight + load into properties pane
- **Edit**: properties pane fields edit live; canvas re-renders on each property change
- **Reorder**: drag handle or up/down arrows
- **Delete**: × icon → confirm if item has children → remove + un-select
- **Duplicate**: optional — "duplicate" action in row context menu

#### Properties Pane

| When Selected | Properties Shown | Conditional |
|---------------|------------------|-------------|
| Text Field | key, label, placeholder, required, max-length, default-value, help-text | — |
| Dropdown | key, label, options (json editor or row editor), default-option, required, multi-select | options required |
| Section | title, collapsed-by-default, columns (1/2/3) | — |
| ... | ... | ... |

#### Preview

| Trigger | Renders | Notes |
|---------|---------|-------|
| Click "Preview" | Modal showing the schema rendered as the actual end-user form | Uses RJSF or live form renderer |
| Side panel toggle | Permanent right pane showing live preview | Always-visible variant |

#### Validation Rules (block save)

- Every item must have a unique `key` within its parent
- Required fields must have a `label`
- Dropdown items must have at least 1 option
- Sections must have at least 1 child item (or warn, not block)
- Schema JSON must serialize without errors

#### User Interaction Flow (DESIGNER_CANVAS)

1. User opens designer → BE returns existing schema OR empty palette state
2. User drags "Text Field" from palette → appears at end of canvas → auto-selected
3. Properties pane loads → user edits key & label → canvas item updates live
4. User adds another field → reorders via drag handle → groups into a section
5. User clicks Preview → modal shows the schema as a live form
6. User clicks Save → validation runs → schema PATCHes → toast "Schema saved"
7. (If versioned) user clicks Publish → schema becomes the active version; previous version archived

---

### 🅲 Block C — MATRIX_CONFIG (fill if sub-type = MATRIX_CONFIG)

#### Matrix Layout

```
┌──────────────┬───────┬───────┬───────┬───────┬───────┬───────┐
│              │ READ  │ WRITE │ DEL   │ EXPRT │ IMPRT │ APPRV │  ← columns
├──────────────┼───────┼───────┼───────┼───────┼───────┼───────┤
│ BUSINESSADMIN│  ✓    │  ✓    │  ✓    │  ✓    │  ✓    │  ✓    │  ← row (read-only system role)
│ STAFFADMIN   │  ✓    │  ☐    │  ☐    │  ☐    │  ☐    │  ☐    │
│ STAFFENTRY   │  ✓    │  ☐    │  ☐    │  ☐    │  ☐    │  ☐    │
│ FIELDAGENT   │  ✓    │  ☐    │  ☐    │  ☐    │  ☐    │  ☐    │
└──────────────┴───────┴───────┴───────┴───────┴───────┴───────┘
   Bulk:  [Select All]  [Clear All]      Filter:  [Module ▾]
```

#### Axes

| Axis | Source | Display | Order | Read-only Filter |
|------|--------|---------|-------|------------------|
| Rows | Roles (`auth.Roles`) | RoleName | RoleId asc | SYSTEM roles disabled |
| Columns | Capabilities (`auth.Capabilities`) | CapabilityCode | DisplayOrder asc | — |

#### Cell Type

**Stamp one**: `{checkbox | chip-toggle | dropdown | number | mixed}`

| Cell Type | Use when | Persisted As |
|-----------|----------|--------------|
| checkbox | Boolean allow/deny | `IsAllowed: bool` |
| chip-toggle | Multi-state (Allow / Deny / Inherit) | `State: string enum` |
| dropdown | Choose from named scope (None / Self / Team / All) | `Scope: string enum` |
| number | Per-cell value (e.g. tax rate, hour limit) | `Value: decimal` |
| mixed | Different cell types per column | per-column type meta |

#### Bulk Operations

| Operation | Trigger | Behavior |
|-----------|---------|----------|
| Row select-all | Click row header | Toggle all editable cells in row |
| Column select-all | Click column header | Toggle all editable cells in column |
| Filter | Top-right filter | Hide rows / columns by criteria (e.g. "Only DONATION module capabilities") |
| Clear all | Page action | Reset all editable cells to default (with confirm) |

#### Save Model

- Default: `save-all` with sticky footer "Save Changes" + dirty count
- Alternative: `autosave` per-cell — debounced PATCH on each toggle (only when small matrix, low risk)
- Diff payload: send only changed cells, not full grid

#### Read-only Cells

| Condition | Visual | Behavior |
|-----------|--------|----------|
| SYSTEM role row | gray, lock icon, "system" tooltip | clicks ignored, cannot dirty |
| Capability not applicable to row's module | strikethrough or hidden | per business rule |

#### User Interaction Flow (MATRIX_CONFIG)

1. User opens matrix → BE returns rows + columns + cells → matrix renders
2. User clicks cells → cells become dirty → footer shows "{N} unsaved changes"
3. User clicks row header → all cells in row toggle → footer count updates
4. User filters by module → matrix narrows → save still applies to current diff
5. User clicks Save → diff PATCHes → toast "{N} changes saved" → dirty count resets
6. User clicks Discard → all dirty cells revert

---

### Shared blocks (apply to all sub-types)

#### Page Header & Breadcrumbs

| Element | Content |
|---------|---------|
| Breadcrumb | {Module} › Settings › {Entity} |
| Page title | {Entity Name} |
| Subtitle | One-sentence description (e.g. "Configure SMTP server and email send behavior") |
| Right actions | {Reset / Test / Help / Export-Import as applicable} |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading | Initial fetch | Skeleton matching the actual section layout (NOT a generic shimmer rectangle) |
| Empty | (Rare for CONFIG) — first-load before defaults seeded | Full-page hint "Configure {entity} to enable {feature}" with primary CTA |
| Error | GET fails | Error card with retry button + error code |
| Save error | Save fails | Inline error per section (or per-cell for matrix) + toast |

---

## ⑦ Substitution Guide

> **TBD** — first CONFIG screen of each sub-type sets the canonical reference. Until then, copy
> from the closest existing screen and adapt:
>
> - SETTINGS_PAGE → closest existing: `companyemailprovider.md` (FLOW today, but its form
>   structure can model SETTINGS_PAGE) — when first true SETTINGS_PAGE is built, set canonical.
> - DESIGNER_CANVAS → no precedent in the registry yet. First builder sets convention.
> - MATRIX_CONFIG → no precedent. First builder sets convention.
>
> Maintainer: when the first CONFIG of each sub-type completes, replace this block with a real
> substitution table mirroring `_MASTER_GRID.md` §⑦.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| {CanonicalName} | {EntityName} | Entity/class name |
| {canonicalCamel} | {entityCamelCase} | Variable/field names |
| {schema} | {schema} | DB schema |
| {Group} | {Group} | Backend group name |
| ... | ... | ... |

---

## ⑧ File Manifest

> Counts vary by sub-type. Pick the matching block and discard the others when generating the
> actual screen prompt.

### Backend Files — SETTINGS_PAGE (singleton-per-tenant)

| # | File | Path |
|---|------|------|
| 1 | Entity | Pss2.0_Backend/.../Base.Domain/Models/{Group}Models/{EntityName}.cs |
| 2 | EF Config | Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/{Group}Configurations/{EntityName}Configuration.cs |
| 3 | Schemas (DTOs) | Pss2.0_Backend/.../Base.Application/Schemas/{Group}Schemas/{EntityName}Schemas.cs |
| 4 | GetSettings Query | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/GetSettingsQuery/Get{EntityName}Settings.cs |
| 5 | UpdateSettings Command | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/UpdateSettingsCommand/Update{EntityName}Settings.cs |
| 6 | ResetToDefaults Command | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/ResetCommand/Reset{EntityName}.cs |
| 7 | TestConnection Command (if applicable) | Pss2.0_Backend/.../Base.Application/Business/{Group}Business/{PluralName}/TestCommand/Test{EntityName}.cs |
| 8 | Default Seeder | Pss2.0_Backend/.../Base.Infrastructure/Seeders/{EntityName}DefaultSeeder.cs |
| 9 | Mutations endpoint | Pss2.0_Backend/.../Base.API/EndPoints/{Group}/Mutations/{EntityName}Mutations.cs |
| 10 | Queries endpoint | Pss2.0_Backend/.../Base.API/EndPoints/{Group}/Queries/{EntityName}Queries.cs |

> **No Create / Delete commands** for singleton — auto-seeded on first GET, never deleted.

### Backend Files — DESIGNER_CANVAS (definition-list)

| # | File | Path |
|---|------|------|
| 1-9 | Standard CRUD (11-file pattern from MASTER_GRID/FLOW) on the definition entity | (same paths) |
| 10 | GetSchema Query | …/GetSchemaQuery/Get{Entity}Schema.cs |
| 11 | BulkUpdateSchema Command | …/BulkUpdateCommand/BulkUpdate{Entity}Schema.cs |
| 12 | ReorderCommand | …/ReorderCommand/Reorder{Entity}.cs |
| 13 | Schema Validator | …/Validators/{Entity}SchemaValidator.cs |
| 14 | Mutations endpoint | …/EndPoints/{Group}/Mutations/{Entity}Mutations.cs |
| 15 | Queries endpoint | …/EndPoints/{Group}/Queries/{Entity}Queries.cs |

### Backend Files — MATRIX_CONFIG (matrix-join)

| # | File | Path |
|---|------|------|
| 1 | Entity | Pss2.0_Backend/.../Base.Domain/Models/{Group}Models/{Entity}.cs (composite-key entity) |
| 2 | EF Config | …/Configurations/{Group}Configurations/{Entity}Configuration.cs |
| 3 | Schemas | …/Schemas/{Group}Schemas/{Entity}Schemas.cs (Matrix DTO + Cell DTO + Diff DTO) |
| 4 | GetMatrix Query | …/GetMatrixQuery/Get{Matrix}.cs |
| 5 | BulkUpdateMatrix Command | …/BulkUpdateCommand/BulkUpdate{Matrix}.cs |
| 6 | Cell Validator | …/Validators/{Matrix}CellValidator.cs |
| 7 | Mutations endpoint | …/EndPoints/{Group}/Mutations/{Matrix}Mutations.cs |
| 8 | Queries endpoint | …/EndPoints/{Group}/Queries/{Matrix}Queries.cs |

### Backend Wiring Updates (all sub-types)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | DbSet<{EntityName}> property |
| 2 | {Group}DbContext.cs | DbSet<{EntityName}> property |
| 3 | DecoratorProperties.cs | Decorator{Group}Modules entry |
| 4 | {Group}Mappings.cs | Mapster mapping config |
| 5 | (Singleton only) seeder registration | Register {Entity}DefaultSeeder |

### Frontend Files — SETTINGS_PAGE

| # | File | Path |
|---|------|------|
| 1 | DTO Types | Pss2.0_Frontend/src/domain/entities/{group}-service/{EntityName}Dto.ts |
| 2 | GQL Query | Pss2.0_Frontend/src/infrastructure/gql-queries/{group}-queries/{EntityName}Query.ts |
| 3 | GQL Mutation | Pss2.0_Frontend/src/infrastructure/gql-mutations/{group}-mutations/{EntityName}Mutation.ts |
| 4 | Settings Page | Pss2.0_Frontend/src/presentation/components/page-components/{group}/{feFolder}/{entity-lower}/settings-page.tsx |
| 5 | Section component (1 per section) | …/{entity-lower}/sections/{section-name}-section.tsx |
| 6 | Sensitive-field input (if reusable doesn't exist) | …/{entity-lower}/components/secret-input.tsx |
| 7 | Page Config | Pss2.0_Frontend/src/presentation/pages/{group}/{feFolder}/{entity-lower}.tsx |
| 8 | Route Page | Pss2.0_Frontend/src/app/[lang]/(core)/{group}/{feFolder}/{entity-lower}/page.tsx |

### Frontend Files — DESIGNER_CANVAS

| # | File | Path |
|---|------|------|
| 1-3 | DTO + GQL Query + Mutation | (same pattern as SETTINGS_PAGE) |
| 4 | Designer Page | …/{entity-lower}/designer-page.tsx |
| 5 | Palette component | …/{entity-lower}/components/palette.tsx |
| 6 | Canvas component | …/{entity-lower}/components/canvas.tsx |
| 7 | Properties Pane | …/{entity-lower}/components/properties-pane.tsx |
| 8 | Preview component | …/{entity-lower}/components/preview.tsx |
| 9 | Designer Store (Zustand) | …/{entity-lower}/{entity-lower}-store.ts |
| 10 | Page Config | (same) |
| 11 | Route Page | (same) |

### Frontend Files — MATRIX_CONFIG

| # | File | Path |
|---|------|------|
| 1-3 | DTO + GQL Query + Mutation | (same pattern) |
| 4 | Matrix Page | …/{entity-lower}/matrix-page.tsx |
| 5 | Matrix Component | …/{entity-lower}/components/matrix-grid.tsx |
| 6 | Cell Renderer (per cell type) | …/{entity-lower}/components/cells/{cell-type}-cell.tsx |
| 7 | Bulk Operations Toolbar | …/{entity-lower}/components/bulk-toolbar.tsx |
| 8 | Page Config | (same) |
| 9 | Route Page | (same) |

### Frontend Wiring Updates (all sub-types)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | {ENTITY_UPPER} operations config |
| 2 | operations-config.ts | Import + register operations |
| 3 | sidebar menu config | Menu entry under {ParentMenu} (typically "Settings" or "Configuration") |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by `/plan-screens`.

```
---CONFIG-START---
Scope: {FULL | BE_ONLY | FE_ONLY}

MenuName: {Entity Display Name}
MenuCode: {ENTITYUPPER}
ParentMenu: {PARENTMENUCODE — typically a SETTINGS / CONFIG / ADMIN parent}
Module: {MODULECODE}
MenuUrl: {group/feFolder/entitylower}
GridType: CONFIG

MenuCapabilities: READ, MODIFY, ISMENURENDER {+ DELETE for DESIGNER_CANVAS, + EXPORT/IMPORT for SETTINGS_PAGE if applicable}

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY {+ DELETE / EXPORT / IMPORT as applicable}

GridFormSchema: SKIP
GridCode: {ENTITYUPPER}
---CONFIG-END---
```

> Capabilities by sub-type:
> - SETTINGS_PAGE: typically `READ, MODIFY` (no CREATE/DELETE — singleton). Add `EXPORT, IMPORT` only if mockup shows config-export feature.
> - DESIGNER_CANVAS: full `READ, CREATE, MODIFY, DELETE, REORDER` on definitions; matrix-style "publish" if versioned.
> - MATRIX_CONFIG: typically `READ, MODIFY` only (no CREATE/DELETE — cells are pre-determined by the join).
>
> `GridFormSchema: SKIP` for all CONFIG sub-types — these are custom UIs, not RJSF modal forms.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `{EntityName}Queries`
- Mutation type: `{EntityName}Mutations`

### SETTINGS_PAGE (singleton-per-tenant)

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| Get{EntityName}Settings | {EntityName}SettingsDto | — (tenant from HttpContext) |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| Update{EntityName}Settings | {EntityName}UpdateRequestDto | {EntityName}SettingsDto (refreshed) |
| Update{Section}Settings (per section if save-per-section) | {Section}UpdateRequestDto | {Section}Dto |
| Reset{EntityName}ToDefaults | — | {EntityName}SettingsDto |
| Test{Entity}Connection (if applicable) | TestRequestDto | TestResultDto |
| Regenerate{Field} (if applicable) | — | {EntityName}SettingsDto with new value once |

**Settings DTO** — sensitive-field handling:
| Field | GET behavior | POST behavior |
|-------|--------------|---------------|
| smtpPassword | omitted OR `"••••••••"` placeholder | empty string ⇒ unchanged; non-empty ⇒ overwrite |
| apiKey | last 4 chars only (`"…XXXX"`) | regenerate-only (separate mutation) |

### DESIGNER_CANVAS (definition-list)

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| Get{Entity}Schema | {Entity}SchemaDto (full state) | parentId |
| GetAll{Entity}List | [{Entity}ResponseDto] | parentId, pageNo, pageSize |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| BulkUpdate{Entity}Schema | {Entity}SchemaDiffRequestDto (added / updated / deleted / reordered) | {Entity}SchemaDto |
| Create{Entity} | {Entity}RequestDto | int |
| Update{Entity} | {Entity}RequestDto | int |
| Delete{Entity} | {entityCamelCase}Id | int |
| Reorder{Entity} | ReorderRequestDto (id + newOrder list) | int |

### MATRIX_CONFIG (matrix-join)

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| Get{Matrix} | {Matrix}Dto (rows + columns + cells) | scopeArgs (e.g. moduleId) |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| BulkUpdate{Matrix} | {Matrix}DiffRequestDto (changed cells only) | {Matrix}Dto (refreshed) |

**Matrix DTO shape:**
```
{
  rows: [{ id, label, isReadOnly, …meta }],
  columns: [{ id, label, …meta }],
  cells: [{ rowId, columnId, value, isReadOnly }]
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/{group}/{feFolder}/{entitylower}`

**Functional Verification (Full E2E — MANDATORY) — pick the sub-type block:**

### SETTINGS_PAGE
- [ ] First-load auto-seeds default config row (no 404 / null state)
- [ ] All sections render in correct order with correct grouping & icons
- [ ] Save-per-section: each section's Save button persists ONLY that section's fields
- [ ] Save-all: single Save persists all sections; partial validity blocks save
- [ ] Validation errors block save and surface inline per field
- [ ] Sensitive fields masked on display (`••••••••` or `…XXXX`)
- [ ] Sensitive-field empty submit ⇒ unchanged; non-empty ⇒ overwrites
- [ ] Read-only system fields render disabled and never POST
- [ ] Test/verify actions trigger handler (real or SERVICE_PLACEHOLDER toast)
- [ ] "Reset to Defaults" gated by type-tenant-name confirm
- [ ] "Regenerate Key" gated by warning + audit-log entry written
- [ ] Role-gated sections hidden for non-privileged roles
- [ ] Unsaved-changes dialog triggers on dirty navigation
- [ ] Audit trail records every change to regulatory / sensitive fields

### DESIGNER_CANVAS
- [ ] Empty schema renders empty canvas + populated palette
- [ ] Palette → Canvas drag/click adds item; canvas auto-selects new item
- [ ] Properties pane loads selected item; edits update canvas live
- [ ] Reorder via drag handle persists order on save
- [ ] Delete item with children prompts confirm
- [ ] Preview renders schema as actual end-user form
- [ ] Validation: unique keys, required labels, non-empty options
- [ ] Save persists full schema; reload restores exact state
- [ ] (If versioned) Publish makes new version active; old version archived

### MATRIX_CONFIG
- [ ] Matrix renders all rows × all columns from sources
- [ ] Cell type renders correctly (checkbox / chip / number / dropdown)
- [ ] Cell change marks dirty; footer shows accurate dirty count
- [ ] Row/column header click toggles all editable cells in that axis
- [ ] Filter/search narrows rows or columns
- [ ] Save sends ONLY changed cells (diff payload), not full grid
- [ ] Read-only cells (system roles, immutable capabilities) disabled and never POST
- [ ] Discard reverts all dirty cells
- [ ] Bulk "Clear All" gated by confirm + audit log

**DB Seed Verification:**
- [ ] Menu appears in sidebar at `{ParentMenu}` (typically Settings / Configuration / Admin)
- [ ] (Singleton only) Default config row seeded for sample tenant
- [ ] (Matrix only) Default cell rows seeded for sample tenant
- [ ] Page renders without crashing on a freshly-seeded DB

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Universal CONFIG warnings:**

- **CompanyId is NOT a form field** — CONFIG is always tenant-scoped via HttpContext.
- **Singleton sub-type has NO Create/Delete** — `Get…Settings` auto-seeds, `Update…Settings` is the only mutation. Don't generate Create/Delete commands for singleton.
- **GridFormSchema = SKIP** for all CONFIG sub-types — these are custom UIs, not RJSF modal forms.
- **No view-page 3-mode pattern** — CONFIG screens are single-mode. Don't import the FLOW `view-page.tsx` pattern.
- **Sensitive fields**: never serialize raw secrets in GET responses. Mask on read; write-only on save (empty ⇒ unchanged). Audit every change.
- **Dangerous actions** (reset, regenerate, disable module): always require confirm + audit log. Style destructive button distinct from primary save.
- **Role gating happens at the BE** — FE hiding fields is UX only. Never trust the FE for permission enforcement.
- **Default seeding**: singleton + matrix sub-types must seed defaults so first-load doesn't 404. Designer sub-type may legitimately start empty.

**Sub-type-specific gotchas:**

| Sub-type | Easy mistakes |
|----------|---------------|
| SETTINGS_PAGE | Generic "Basic / Advanced" tab split that doesn't match the business; identical card chrome across unrelated settings; sensitive password rendered as plain text input; dangerous "Reset" button next to normal "Save" |
| DESIGNER_CANVAS | Properties pane that doesn't update canvas live; preview that's actually just a JSON dump; reorder that doesn't persist; allowing duplicate keys (silent overwrite at runtime) |
| MATRIX_CONFIG | Sending the full grid every save instead of diff; SYSTEM rows accidentally editable; bulk clear without confirm; matrix wider than viewport with no sticky headers |

**Module / module-instance notes:**
- {e.g. "This is the FIRST entity in the `{schema}` schema — new module infrastructure must be created first"}
- {e.g. "Parent menu `SETTINGS` does not exist yet — register it in seed before this CONFIG screen"}
- {e.g. "For ALIGN scope: only modify existing files, do not regenerate from scratch"}

**Service Dependencies** (UI-only — no backend service implementation):

> Everything shown in the mockup is in scope. List items here ONLY if they require an
> external service or infrastructure that doesn't exist in the codebase yet.

{Only list genuine external-service dependencies — leave empty if none.}
- {e.g. "⚠ SERVICE_PLACEHOLDER: 'Test SMTP Connection' — full UI implemented. Handler returns mocked success/failure because SMTP service layer doesn't exist yet."}
- {e.g. "⚠ SERVICE_PLACEHOLDER: 'Send Test Email' — same reason."}
- {e.g. "⚠ SERVICE_PLACEHOLDER: 'Sync from Active Directory' — depends on AD/LDAP service not yet integrated."}

Full UI must be built (sections, designers, matrix, masked inputs, confirm dialogs, audit log entries). Only the handler for the external service call is mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — no issues raised yet) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}
```

---

## Section Purpose Summary

| # | Section | Who Reads It | What It Answers |
|---|---------|-------------|-----------------|
| ① | Identity & Context | All agents | "What does this configure, who edits it, and what breaks if mis-set?" |
| ② | Storage Model | BA → BE Dev | "Singleton row / definition list / matrix join — and exactly what fields?" |
| ③ | FK Resolution | BE Dev + FE Dev | "WHERE is each FK / matrix axis source?" |
| ④ | Business Rules | BA → BE Dev → FE Dev | "Singleton constraints, sensitive-field handling, dangerous actions, role gating" |
| ⑤ | Classification | Solution Resolver | "Sub-type (SETTINGS_PAGE / DESIGNER_CANVAS / MATRIX_CONFIG), save model, BE+FE patterns" |
| ⑥ | UI/UX Blueprint | UX Architect → FE Dev | "Per sub-type: section layout / canvas layout / matrix layout — plus visual-uniqueness rules" |
| ⑦ | Substitution Guide | BE Dev + FE Dev | "How to map canonical → this entity (TBD until first per sub-type lands)" |
| ⑧ | File Manifest | BE Dev + FE Dev | "Exact files per sub-type (singleton has no Create/Delete; designer has bulk-update; matrix has diff)" |
| ⑨ | Approval Config | User | "Capabilities differ by sub-type; GridFormSchema always SKIP" |
| ⑩ | BE→FE Contract | FE Dev | "Per-sub-type queries + mutations + DTO shapes (incl. sensitive-field handling)" |
| ⑪ | Acceptance Criteria | Verification | "Sub-type-specific E2E checks + sensitive-field + dangerous-action gates" |
| ⑫ | Special Notes | All agents | "Singleton has no Create/Delete; sensitive masking; default seeding; sub-type gotchas" |

---

## Notes for `/plan-screens`

- Detect CONFIG by: mockup is a multi-section settings page (no list-of-N grid), or a designer canvas, or a matrix grid.
- Distinguish from MASTER_GRID/FLOW: those have a list/grid of N rows with per-row CRUD. CONFIG operates on a single config record (singleton), a schema (designer), or a matrix.
- Stamp `config_subtype` in frontmatter — SETTINGS_PAGE / DESIGNER_CANVAS / MATRIX_CONFIG.
- Stamp `storage_pattern` in §② — singleton-per-tenant / keyed-settings-rows / definition-list / matrix-join.
- Stamp `save_model` in §⑤ — save-all / save-per-section / autosave.
- Pre-fill §⑨ Approval Config based on sub-type capability matrix above.
- §⑥: include only the relevant sub-type block; delete the others before writing the screen prompt.
- §⑪ Acceptance: include only the matching sub-type block.

## Notes on canonical references

When the first SETTINGS_PAGE / DESIGNER_CANVAS / MATRIX_CONFIG completes:

1. Replace §⑦ TBD block with a real substitution table modeled on `_MASTER_GRID.md` §⑦.
2. Update `_COMMON.md` § Substitution Guide table with the new canonical per sub-type.
3. Add a one-line note to this file's header listing the canonical reference.
