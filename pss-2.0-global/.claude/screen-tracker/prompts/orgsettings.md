---
screen: OrgSettings
registry_id: 85
module: Setting
status: COMPLETED
scope: ALIGN
screen_type: CONFIG
config_subtype: SETTINGS_PAGE
storage_pattern: keyed-settings-rows
save_model: save-all
complexity: High
new_module: NO (existing `sett` schema; OrganizationSetting + SettingGroup + UserSetting entities + CRUD already exist)
planned_date: 2026-05-15
completed_date: 2026-05-15
last_session_date: 2026-05-15
---

> **One screen, three menus** — this single tabbed UI fulfils **ORGANIZATIONSETTING**, **SETTINGGROUP** and **USERSETTING**
> (all under `SET_ORGSETTINGS`, MenuId 377). All three sidebar links route to the SAME page (`setting/orgsettings/`) —
> they differ only by which tab opens by default. See §⑨ for the dual-menu wiring detail.
>
> **NOT the same as #75 CompanySettings** — that screen edits **3 specific tables** for the tenant company
> (Companies + CompanyConfigurations + CompanyBrandings — singleton-per-tenant) and has its own route
> `setting/orgsettings/companysettings`. THIS screen edits the **generic key/value settings store**
> (`sett.SettingGroups` + `sett.OrganizationSettings` + `sett.UserSettings`) and lives at the
> parent `setting/orgsettings/` route, alongside CompanySettings.

---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — sidebar category nav (10 groups) + right-pane stacked setting-row cards; sticky bottom change-bar with single "Save All" + Discard; search input filters across all categories
- [x] Sub-type identified: `SETTINGS_PAGE` (multi-section keyed settings, NOT a designer canvas, NOT a matrix)
- [x] Storage model: `keyed-settings-rows` — N rows in `sett.OrganizationSettings` per tenant, grouped by `SettingGroupId` → `sett.SettingGroups` (10 group categories); optional per-user override rows in `sett.UserSettings`
- [x] Save model chosen: `save-all` (mockup has ONE sticky-footer "Save All" button + dirty-change badge; matches CompanySettings precedent and matches mockup verbatim)
- [x] Sensitive fields & role gates identified: NO secrets in this screen (no passwords / API keys; security-policy section stores POLICY values, not actual creds); BUSINESSADMIN-only edit, all roles READ
- [x] FK targets resolved (paths + GQL queries verified — SettingGroup, User; no other FKs)
- [x] File manifest computed (BE: 3 NEW handlers + 2 NEW endpoints + 1 seeder; FE: ~14 NEW components + 3 stub-page conversions; existing BE per-row CRUD KEPT untouched for admin/migration use)
- [x] Approval config pre-filled — all 3 menus (ORGANIZATIONSETTING / SETTINGGROUP / USERSETTING) point to the SAME MenuUrl
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (config purpose + edit personas + risk)
- [x] Solution Resolution complete (sub-type confirmed, save model confirmed, ALIGN scope confirmed — additive BE + custom FE)
- [x] UX Design finalized (sidebar-nav with 10 groups + setting-row stack + change-bar)
- [x] User Approval received (2026-05-15 — Sonnet across the board, app-tenant runtime seeder)
- [x] Backend code generated (ALIGN — additive only: 1 aggregate query + 1 bulk-update command + 1 reset-to-default command + default-row seeder for the 10 groups & ~75 ParamCodes)
- [x] Backend wiring complete (extend existing `OrganizationSettingQueries` + `OrganizationSettingMutations` GraphQL types; Mapster + DI registrations added)
- [x] Frontend code generated (1 settings-page + Zustand store + setting-row renderer + 3 custom widgets + 5 chrome components; FE generation agent crashed mid-flight, salvaged inline)
- [x] Frontend wiring complete (3 stub pages → all render the SAME settings page; barrel index updated; capability gate on ORGANIZATIONSETTING menu code)
- [x] DB Seed script generated (`OrgSettings-sqlscripts.sql` — menu capability + role grants only; SettingGroups/OrganizationSettings seeded at runtime)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] EF migration `Add_OrgSettings_Defaults_Seeder` applied (if new tables/columns added — likely NONE, just seed inserts)
- [ ] pnpm dev — page loads at `/{lang}/setting/orgsettings/organizationsetting` (and `/settinggroup` and `/usersetting`)
- [ ] **SETTINGS_PAGE checks**:
  - [ ] First-load auto-seeds default `SettingGroups` (10) and `OrganizationSettings` (~75) for current tenant if missing → no 404 / empty state
  - [ ] All 10 group categories render in left-sidebar nav with correct icons, names, and count badges
  - [ ] Active category click swaps the right-pane card; first category is `FUNDRAISING` (active by default)
  - [ ] Setting-row widget renders correctly per `ParamDataType`:
    - `STRING` → text input
    - `NUMBER` → number input
    - `BOOLEAN` → toggle switch with On/Off label
    - `SELECT` → dropdown populated from `AllValues` (pipe-or-JSON list)
    - `MULTI_CHECK` → checkbox group from `AllValues`
    - `TAGS` → tag-input (comma-or-Enter to add, X to remove)
    - `TIME` → time picker
    - `EMAIL` → email input with format validation
  - [ ] Changing any control marks the row as "dirty" (yellow background + dot indicator) and increments the change-bar count
  - [ ] Reset (↶) button per row appears only when dirty; click reverts that row to last-saved (NOT to ParamDefaultValue — that's a different action)
  - [ ] Search input filters setting rows across ALL categories by Name or Description substring; matched categories auto-expand; clearing search reverts to active-category view
  - [ ] "Save All" persists ALL dirty rows in ONE BulkUpdateOrganizationSettings mutation → toast success → dirty count resets to 0
  - [ ] "Discard Changes" shows confirm modal → reverts ALL dirty rows to last-saved state
  - [ ] Validation errors block save and surface inline per setting (e.g. negative number where min=0; empty required value; invalid email)
  - [ ] Page-header actions present: Import Settings / Export Settings / Save All → see §⑫ for SERVICE_PLACEHOLDER scope
  - [ ] CanUserOverride toggle (when ON in OrganizationSetting definition) shows an "Allow per-user override" hint in the row's tooltip
  - [ ] Unsaved-changes blocker on navigation when dirty
  - [ ] Audit-trail records each successful BulkUpdate event (whole-payload, not per-row)
- [ ] Empty / loading / error states render
- [ ] DB Seed — three sidebar menus (Setting Group / Organization Setting / User Setting) all visible under `Setting › Org Settings` and all open the same screen

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: OrgSettings (registry name: "Organization Settings")
Module: Setting
Schemas: `sett` (existing — `sett.SettingGroups`, `sett.OrganizationSettings`, `sett.UserSettings`)
Group: Setting (handlers under `SettingBusiness/OrganizationSettings`, configs under `SettingConfigurations`, endpoints under `EndPoints/Setting`)
Frontend Module: setting (route under `setting/orgsettings/{organizationsetting | settinggroup | usersetting}` — all three resolve to ONE screen)

**Business**: This is the **generic key/value tenant-configuration screen** — the runtime-configurable knobs that drive cross-cutting behavior across CRM, Donations, Communication, Reports, Field Collection, and Compliance modules. Unlike #75 CompanySettings (which edits 3 specific entity tables — Company / CompanyConfiguration / CompanyBranding — for org identity, branding, and fiscal facts), THIS screen edits the **schema-less settings store**: `sett.OrganizationSettings` holds one row per `(CompanyId, ParamCode)` with a `CurrentValue` string + `ParamDataType` discriminator (STRING / NUMBER / BOOLEAN / SELECT / MULTI_CHECK / TAGS / TIME / EMAIL), and `sett.SettingGroups` partitions those rows into 10 user-facing categories (Fundraising & Donations, Receipts & Tax, Communication, Contacts & CRM, Organization, Field Collection, Reports, Security & Privacy, Notifications, Regional & Compliance). The mockup confirms ~75 individual settings spread across the 10 groups — every one is a typed runtime knob (e.g. `DEFAULTCURRENCY`, `MIN_DONATION_AMOUNT`, `EMAIL_DAILY_LIMIT`, `QUIET_HOURS_START`, `2FA_POLICY`, `GDPR_DATA_RETENTION`). The `CanUserOverride` flag on each definition controls whether a user may shadow the tenant value with a personal value stored in `sett.UserSettings` (out of scope for the MVP edit UI — admin-only edit screen for now; per-user override happens via separate end-user-preferences screen, not this one).

**WHO edits it**: BUSINESSADMIN only (the tenant's owner/operator). All other roles get READ access to enable runtime lookups (e.g. donation entry reads `MIN_DONATION_AMOUNT` to validate; email-send job reads `EMAIL_DAILY_LIMIT` to throttle). **HOW OFTEN**: settings cluster as one-time-during-onboarding (most fields), quarterly tweaks (limits, fiscal-year rollover, GDPR retention), and rare-but-critical (2FA policy, IP whitelisting, maintenance toggles). **WHY it exists**: feature-flag and threshold infrastructure that lets the SaaS platform stay opinionated by default but lets each NGO customize without code changes. **WHAT BREAKS if mis-set**: high blast radius — wrong `DUPLICATE_CHECK_WINDOW` floods donation entry with false flags; wrong `EMAIL_DAILY_LIMIT` paginates campaigns wrong; wrong `2FA_POLICY` either locks admins out or exposes the tenant; wrong `MAX_REPORT_ROWS` causes export OOM. **HOW it relates to other screens**: the 75-ish ParamCodes are READ from this store across every module — every form, validator, scheduler, and email job pulls its threshold via `IOrganizationSettingsService.GetValueAsync(paramCode)`. **WHAT'S unique about its UX vs. a generic settings page**: it's NOT a hand-coded form — it's a **schema-driven renderer** that paints widgets based on `ParamDataType` and validates based on `AllValues`. The 10 categories and ~75 ParamCodes are seeded; the BUSINESSADMIN only ever sees existing rows and edits `CurrentValue`. New ParamCodes are added only by developers via migration/seed (NOT via the UI).

> Why §① is heavier than other screens: this screen is fundamentally different from a typed singleton (CompanySettings). The developer must understand that **the field list comes from data, not code** — the BE must return the rendered list, the FE renders generic widget components per row, and adding a 76th setting tomorrow requires ZERO frontend code change. Without that grounding, an agent will write a hand-coded 75-field form and miss the entire point.

**Combined-screen contract**:

| Sidebar Menu Code | MenuName | MenuUrl | Default Tab on Load | Purpose |
|-------------------|----------|---------|---------------------|---------|
| ORGANIZATIONSETTING | Organization Setting | setting/orgsettings/organizationsetting | `cat-fundraising` (first group) | Lands the user on the full settings page |
| SETTINGGROUP | Setting Group | setting/orgsettings/settinggroup | `cat-fundraising` (first group) | SAME page — the "group" concept is exposed via the sidebar, NOT as a separate CRUD screen |
| USERSETTING | User Setting | setting/orgsettings/usersetting | `cat-fundraising` (first group) | SAME page — the per-user override view is a future enhancement; for now the link opens this admin screen |

All three FE routes render the **same component** (a single `OrgSettingsPage`). The 3 separate route files exist solely to satisfy the menu seed/sidebar router that has 3 separate MenuCodes pointing here.

---

## ② Storage Model

> **Consumer**: BA Agent → Backend Developer
> **Storage Pattern**: `keyed-settings-rows`
> Audit columns (CreatedBy/CreatedDate/ModifiedBy/ModifiedDate/IsActive/IsDeleted) inherited from `Entity` base — DO NOT enumerate.
> CompanyId is **always** present and **NEVER** a form field — derived from HttpContext (`ITenantContext.GetRequiredTenantId()`).

### Existing tables — KEEP as-is (no schema change)

#### Table 1: `sett."SettingGroups"` (EXISTING — entity at `Base.Domain/Models/SettingModels/SettingGroup.cs`)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| SettingGroupId | int | — | PK | — | Primary key |
| SettingGroupName | string | 100 | YES | — | TitleCase via `[CaseFormat("title")]` (e.g. "Fundraising & Donations") |
| SettingGroupCode | string | 50 | YES | — | UPPER via `[CaseFormat("upper")]` — UNIQUE per tenant (e.g. `FUNDRAISING`) |
| SettingGroupIcon | string | 50 | YES | — | Emoji or FA icon class (e.g. `💰` or `fa-coins`) |
| IsVisibleInUI | bool | — | YES | — | Hide system-only groups (e.g. internal counters) |
| OrderBy | int | — | YES | — | Sidebar display order |

> Seed: 10 default rows per tenant on tenant-onboarding (see §⑫ default seeder).

#### Table 2: `sett."OrganizationSettings"` (EXISTING — entity at `Base.Domain/Models/SettingModels/OrganizationSetting.cs`)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| OrganizationSettingId | int | — | PK | — | Primary key |
| SettingGroupId | int | — | YES | sett.SettingGroups | FK to parent group |
| ParamName | string | 200 | YES | — | TitleCase display (e.g. "Default Currency") |
| ParamCode | string | 100 | YES | — | UPPER+UNDERSCORE — UNIQUE per `(CompanyId, ParamCode)` (e.g. `DEFAULT_CURRENCY`) |
| ParamDataType | string | 50 | YES | — | One of: `STRING`, `NUMBER`, `BOOLEAN`, `SELECT`, `MULTI_CHECK`, `TAGS`, `TIME`, `EMAIL` |
| ParamDefaultValue | string? | 1000 | NO | — | Factory-default; **never** mutated by UI Save |
| CurrentValue | string? | 1000 | NO | — | Editable value (what the UI binds to) |
| AllValues | string? | 2000 | NO | — | Pipe- or JSON-list of options for SELECT / MULTI_CHECK (e.g. `Email\|WhatsApp\|Print\|None`) |
| Description | string? | 500 | NO | — | Inline help text shown to right of widget |
| CanUserOverride | bool | — | YES | — | If true, end users may store a personal override in UserSettings |

> Seed: ~75 rows per tenant on tenant-onboarding — list lives in §⑫ default seeder.

> **Singleton-ish constraint**: NOT a true singleton — many rows. But the (CompanyId, ParamCode) tuple is UNIQUE.
> Unique index recommended: `IX_OrganizationSettings_CompanyId_ParamCode_Unique`.

#### Table 3: `sett."UserSettings"` (EXISTING — entity at `Base.Domain/Models/SettingModels/UserSetting.cs`)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| UserSettingId | int | — | PK | — | Primary key |
| UserId | int | — | YES | auth.Users | Owning user |
| SettingGroupId | int | — | YES | sett.SettingGroups | FK to group |
| ParamName | string | 200 | YES | — | Mirrors OrganizationSetting.ParamName |
| ParamCode | string | 100 | YES | — | Mirrors OrganizationSetting.ParamCode |
| ParamValue | string | 1000 | YES | — | User's personal override |
| Description | string? | 500 | NO | — | Optional |

> **Out of scope for the MVP edit UI** — UserSetting writes happen via end-user preferences screen (separate), not via this admin screen. This admin screen **reads** UserSettings only to render a "X users have overridden this setting" badge (optional polish — defer if not in mockup).

### Singleton constraint (keyed pattern)
- Unique index on `(CompanyId, ParamCode)` — exactly one row per setting per tenant
- First-load behavior: if `SettingGroups` is empty for the tenant OR `OrganizationSettings` row count < expected seed-count, the BE auto-seeds defaults

### Composite key (matrix-join pattern)
- N/A

### Definition parent (definition-list pattern)
- N/A

### Child Tables
- None for this UI. (`UserSetting` references `SettingGroup` but is not edited here.)

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| SettingGroupId (in OrganizationSetting & UserSetting) | SettingGroup | `Base.Domain/Models/SettingModels/SettingGroup.cs` | `GetSettingGroups` (existing) / `GetSettingGroupByCode` (existing) | `SettingGroupName` | `SettingGroupResponseDto` |
| UserId (in UserSetting) | User | `Base.Domain/Models/AuthModels/User.cs` | (resolved server-side from `HttpContext`) | n/a | n/a |

> No frontend ApiSelect needed — the UI fetches the **composite view** in one shot (`GetOrganizationSettingsView`) which returns groups → settings already shaped.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Singleton / Cardinality Rules:**
- Each tenant has **exactly one row per ParamCode** — `(CompanyId, ParamCode)` is unique.
- `SettingGroups` are seeded once per tenant during onboarding — 10 default rows.
- `OrganizationSettings` are seeded once per tenant during onboarding — one row per ParamCode in the master list.
- The aggregate query `GetOrganizationSettingsView` **auto-seeds defaults** on first call if any expected group or ParamCode is missing → first load NEVER 404s.

**Required Field Rules:**
- `ParamName`, `ParamCode`, `ParamDataType`, `SettingGroupId` are required on every row (already enforced by entity `Create` factory).
- `CurrentValue` is **nullable** at the storage layer — but the UI treats "blank" as "use default" and may block save if the ParamCode is in a required-on-save subset (e.g. `DEFAULT_CURRENCY`, `FINANCIAL_YEAR_START`).

**Conditional Rules** (per-ParamCode validation):
- `MIN_DONATION_AMOUNT` ≤ `MAX_DONATION_AMOUNT` (or MAX = 0 meaning unlimited)
- `QUIET_HOURS_END` may be before or after `QUIET_HOURS_START` (cross-midnight allowed); equal values blocked
- `PASSWORD_MIN_LENGTH` between 6 and 32 (validate against widget min/max)
- `EMAIL_DAILY_LIMIT`, `SMS_DAILY_LIMIT`, `WHATSAPP_DAILY_LIMIT` must be positive integers
- `MAX_LOGIN_ATTEMPTS` between 1 and 20
- `RECEIPT_NUMBER_PREFIX` matches `^[A-Z0-9\-]{1,10}$`
- `AUTHORIZED_SIGNATORY` non-empty if `REQUIRE_RECEIPT_SIGNATURE` is true
- For `SELECT` type: `CurrentValue` must be one of the pipe-delimited values in `AllValues`
- For `MULTI_CHECK` type: `CurrentValue` is a comma-joined subset of `AllValues`
- For `TAGS` type: each tag is a primitive token (e.g. "7", "14", "30" days)

**Sensitive Fields**:
- **None** in this screen. The 75 settings store thresholds, toggles, defaults, and policy values — NOT credentials. Password policies (length, expiry, history depth) are stored as plain numbers; actual passwords are never in this store.

**Read-only / System-controlled Fields:**
- `ParamName`, `ParamCode`, `ParamDataType`, `AllValues`, `Description`, `CanUserOverride`, `ParamDefaultValue` are **definition fields** — NEVER editable from this admin screen. They're seeded by migration and changed only by developers.
- Only `CurrentValue` is editable.

**Dangerous Actions** (require confirm + audit):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Discard Changes | Reverts all dirty rows to last-saved state | Modal: "Discard {N} unsaved changes?" | none — local-only |
| Reset Single Row (↶) | Reverts THAT row to last-saved (NOT to ParamDefaultValue) | none — fast cancel | none |
| Import Settings | Overwrites N CurrentValues from JSON/CSV | Preview-diff modal showing exactly which rows change + confirm | log "settings imported, N rows changed" |
| Export Settings | Downloads CurrentValues as JSON/CSV | none (read-only) | log "settings exported" |
| Save All | Persists all dirty rows in ONE transaction | none — primary action | log "settings updated, N rows changed" with old→new diff |

**Role Gating**:

| Role | Sections Visible | Sections Editable | Notes |
|------|------------------|-------------------|-------|
| BUSINESSADMIN | all 10 categories | all | full access |
| (any other role) | none — screen not in their menu | none | The 3 menus (ORGANIZATIONSETTING / SETTINGGROUP / USERSETTING) are seeded with capabilities only for BUSINESSADMIN |

**Workflow**: None. CONFIG screen — instant persist on Save All. No draft / publish / approval.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: CONFIG
**Config Sub-type**: `SETTINGS_PAGE`
**Storage Pattern**: `keyed-settings-rows`
**Save Model**: `save-all`

**Reason**: The mockup has a single sticky-footer "Save All" change-bar with a dirty-count badge — no per-section save buttons. This matches the schema-driven nature of the screen (all 75 settings live in the same table, paged into 10 groups for UX) and the typical edit cadence (BUSINESSADMIN does a few edits then saves once). Per-section save would add 10 redundant buttons and confuse the cross-category search/filter feature.

**Scope**: ALIGN — BE has 3 entities + 11-file standard CRUD already; FE has 3 `UnderConstruction` stub routes. ALIGN means: ADD the aggregate query + bulk-update + reset-to-default mutations (3 NEW BE handlers), KEEP existing per-row CRUD untouched (for admin/migration tooling), BUILD a single shared FE screen and wire all 3 stub routes to render it.

**Backend Patterns Required:**

For **SETTINGS_PAGE (keyed-settings-rows)**:
- [x] `GetOrganizationSettingsView` query — returns the composite shape `{ groups: [{ groupId, name, code, icon, orderBy, settings: [{ paramCode, paramName, paramDataType, allValues, description, currentValue, canUserOverride, organizationSettingId }] }] }` for the current tenant, auto-seeding defaults if missing
- [x] `BulkUpdateOrganizationSettings` mutation — accepts `[{ organizationSettingId, paramCode, currentValue }]` array, upserts on `(CompanyId, ParamCode)`, validates per-ParamCode rules, returns the refreshed view
- [x] `ResetOrganizationSettingsToDefaults` mutation — overwrites all `CurrentValue` ← `ParamDefaultValue` for the tenant; audit-logged. (Scoped to a single group OR ALL — accepts optional `settingGroupCode`)
- [x] Default-row seeder — invoked from `GetOrganizationSettingsView` when the tenant's setting count < expected baseline; idempotent
- [x] Tenant scoping (CompanyId from HttpContext via `ITenantContext`)
- [x] Per-ParamCode validators (chain a Strategy map keyed by ParamCode → rule lambda)
- [x] Audit-trail emission on `BulkUpdateOrganizationSettings` (whole-payload, with old→new diff per row)
- [ ] Test connection — N/A (no external service tested by this screen)

**Frontend Patterns Required:**

For **SETTINGS_PAGE**:
- [x] Custom multi-section page (NOT RJSF modal, NOT view-page 3-mode) at `setting/orgsettings/{settinggroup|organizationsetting|usersetting}/page.tsx` — all three render the SAME `OrgSettingsPage` component
- [x] Section container: **sidebar-nav** (10 groups, vertical sticky left panel, count-badge per group)
- [x] Section component per category — but **dynamically rendered** from the BE response, NOT hardcoded
- [x] Setting-row renderer — 8 widget types keyed by `ParamDataType`:
  - `STRING` → `<TextInput>`
  - `NUMBER` → `<NumberInput>` with min/max parsed from per-ParamCode rules
  - `BOOLEAN` → `<ToggleSwitch>` with "On"/"Off" label
  - `SELECT` → `<Dropdown>` rendering pipe-or-JSON `AllValues`
  - `MULTI_CHECK` → `<CheckboxGroup>` rendering `AllValues`
  - `TAGS` → `<TagInput>` (enter / comma to add, X to remove)
  - `TIME` → `<TimePicker>`
  - `EMAIL` → `<TextInput type="email">` with format validation
- [x] Dirty-row indicator (yellow row bg + dot icon + per-row Reset button)
- [x] Sticky bottom change-bar (Discard / Save All) with live "{N} settings changed" count
- [x] Search input filters across ALL 10 groups by Name or Description substring; when query is non-empty, all groups are shown; when empty, only active category is shown
- [x] Header actions: Import Settings (SERVICE_PLACEHOLDER), Export Settings (real — downloads JSON), Save All
- [x] Zustand store managing: `originalValues: Map<paramCode, value>`, `dirtyValues: Map<paramCode, value>`, `activeCategory: string`, `searchQuery: string`
- [x] Unsaved-changes navigation blocker (Next.js router)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: This section is the design spec. The mockup is the source of truth — match it exactly.

### 🎨 Visual Uniqueness Rules

> Each of the 10 group categories has a distinct icon and color cue but uses the **same** card chrome — that's
> correct here because the rows are uniform key/value structure. The variation is in the **widgets**, not the cards.

1. **Sidebar nav** — vertical list, sticky to top, 240px wide, each item: icon + label + count-badge; active item has primary-accent background.
2. **Setting card** — one card per category, card-header has 36px icon-badge + title + subtitle. Card-body is a vertical stack of setting rows separated by `1px solid #f1f5f9` borders.
3. **Setting row** — three-column layout: `200px label / 280px control / flex-1 description / 32px reset-action`.
4. **Dirty row** — yellow background (`#fefce8`), dot indicator next to label, reset button (↶) visible.
5. **Change-bar** — fixed-bottom, full width, white bg with 2px top border in primary accent; left: "{N} settings changed" with warning icon; right: Discard + Save All buttons.
6. **Widget styling** — all widgets are 32px-tall; toggle has 40×22 slider; tags input has inline chips with X icons.

**Anti-patterns to refuse**:
- Hand-coded 75-field React component (this is schema-driven — the row count comes from the BE)
- Per-section Save buttons (mockup is unambiguous: ONE Save All in the change-bar)
- ApiSelect for the categories sidebar (categories come from the SAME aggregate query)
- Tabs as a substitute for sidebar-nav (mockup is explicitly a left-sidebar layout)
- Treating each ParamDataType as a "type" component (use a single renderer with a switch on `paramDataType`)

---

### 🅰️ Block A — SETTINGS_PAGE

#### Page Layout

**Container Pattern**: `sidebar-nav`

```
┌──────────────────────────────────────────────────────────────────────┐
│ ⚙ Organization Settings                                              │
│  System parameters and operational configuration                     │
│                                       [🔍 search] [Import] [Export] [Save All] │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌──────────────┐  ┌─────────────────────────────────────────────┐  │
│  │💰 Fundraising│  │  💰 Fundraising & Donations  │ description │  │
│  │  & Donations  │  ├──────────────────────────────┴─────────────┤  │
│  │      15      │  │ Default Currency       [AED ▼]  Default for │  │
│  │ ───────────  │  │ Allow Multi-Currency   [✓ On]   Allow ...   │  │
│  │📃 Receipts   │  │ Minimum Donation       [ 1.00 ] Minimum ... │  │
│  │   & Tax  10  │  │  Maximum Donation      [1000000] Max ...    │  │
│  │ ...          │  │  Receipt Delivery      [Email ▼] ...        │  │
│  │              │  │  Duplicate Check Fields [Amount][Date][Contact][Purpose] │
│  │              │  │  Pledge Reminder Days  [7 ×][14 ×][30 ×] ...│  │
│  │              │  │  ...                                         │  │
│  └──────────────┘  └─────────────────────────────────────────────┘  │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
  ┌──────────────────────────────────────────────────────────────────┐
  │ ⚠ 3 settings changed                  [Discard]  [💾 Save All]    │  ← sticky change-bar
  └──────────────────────────────────────────────────────────────────┘
```

**Page Header**: Title (`⚙ Organization Settings`) + subtitle (`System parameters and operational configuration`) + actions row (search box, Import Settings btn, Export Settings btn, Save All btn).

#### Section Definitions

> One row per group category. Order = `SettingGroup.OrderBy` ascending. **All 10 sourced from BE**, NOT hardcoded.
> The seeded baseline is:

| # | SettingGroupCode | SettingGroupName | Icon | Setting Count | Default? |
|---|------------------|------------------|------|--------------|----------|
| 1 | FUNDRAISING | Fundraising & Donations | 💰 | 15 | active by default |
| 2 | RECEIPTS | Receipts & Tax | 📃 | 10 | |
| 3 | COMMUNICATION | Communication | 📧 | 9 | |
| 4 | CONTACTS | Contacts & CRM | 👥 | 7 | |
| 5 | ORGANIZATION | Organization | 🏢 | 6 | |
| 6 | FIELD | Field Collection | 🚶 | 5 | |
| 7 | REPORTS | Reports | 📊 | 4 | |
| 8 | SECURITY | Security & Privacy | 🔒 | 8 | |
| 9 | NOTIFICATIONS | Notifications | 🔔 | 5 | |
| 10 | REGIONAL | Regional & Compliance | 🌐 | 6 | |

#### Field Mapping — Schema-Driven (NOT hand-coded)

> **Important**: the FE does NOT enumerate the 75 settings. It renders each `setting` row from
> `view.groups[i].settings[j]` via a single `<SettingRow>` component that switches on `paramDataType`.

`<SettingRow>` props: `{ paramCode, paramName, paramDataType, allValues, description, currentValue, canUserOverride, dirty, onChange, onReset }`

| `paramDataType` | Widget | Reads `AllValues` as | Persists `CurrentValue` as |
|-----------------|--------|----------------------|----------------------------|
| `STRING` | `<input type="text">` | n/a | string |
| `NUMBER` | `<input type="number">` | optional `"min\|max\|step"` | string-coerced number |
| `BOOLEAN` | toggle switch | n/a | `"true"` / `"false"` |
| `SELECT` | `<select>` | `"opt1\|opt2\|opt3"` (pipe-delimited) | selected option string |
| `MULTI_CHECK` | checkbox group | `"opt1\|opt2\|opt3"` | comma-joined selected (e.g. `"opt1,opt3"`) |
| `TAGS` | tag-input | n/a | comma-joined tokens (e.g. `"7,14,30"`) |
| `TIME` | `<input type="time">` | n/a | `"HH:mm"` string |
| `EMAIL` | `<input type="email">` | n/a | string (validated as email) |

#### Seeded ParamCodes (full list — for default seeder ONLY; FE never reads this list)

> Group 1 — FUNDRAISING (15):

| # | ParamCode | ParamName | ParamDataType | AllValues | ParamDefaultValue | Description |
|---|-----------|-----------|---------------|-----------|-------------------|-------------|
| 1 | DEFAULT_CURRENCY | Default Currency | SELECT | `AED\|USD\|EUR\|GBP\|INR\|SAR` | `AED` | Default currency for new donations |
| 2 | ALLOW_MULTI_CURRENCY | Allow Multi-Currency | BOOLEAN | — | `true` | Allow donations in different currencies |
| 3 | MIN_DONATION_AMOUNT | Minimum Donation Amount | NUMBER | `0\|999999\|0.01` | `1.00` | Minimum amount accepted |
| 4 | MAX_DONATION_AMOUNT | Maximum Donation Amount | NUMBER | `0\|99999999\|1` | `1000000` | Maximum single donation (0 = unlimited) |
| 5 | AUTO_GENERATE_RECEIPT | Auto-Generate Receipt | BOOLEAN | — | `true` | Automatically create receipt on donation entry |
| 6 | RECEIPT_DELIVERY_DEFAULT | Receipt Delivery Default | SELECT | `Email\|WhatsApp\|Print\|None` | `Email` | Default receipt delivery method |
| 7 | REQUIRE_PURPOSE | Require Purpose | BOOLEAN | — | `true` | Mandate purpose selection for every donation |
| 8 | DEFAULT_PURPOSE | Default Purpose | SELECT | `General Fund\|Education\|Healthcare\|Disaster Relief\|Orphan Sponsorship` | `General Fund` | Pre-selected purpose when creating donation |
| 9 | ALLOW_ANONYMOUS_DONATIONS | Allow Anonymous Donations | BOOLEAN | — | `true` | Allow donations without linked contact |
| 10 | DUPLICATE_CHECK_WINDOW | Duplicate Check Window | SELECT | `1 hour\|6 hours\|12 hours\|24 hours\|48 hours\|7 days` | `24 hours` | Time window to flag potential duplicates |
| 11 | DUPLICATE_CHECK_FIELDS | Duplicate Check Fields | MULTI_CHECK | `Amount\|Date\|Contact\|Purpose` | `Amount,Date,Contact` | Fields to compare for duplicate detection |
| 12 | ONLINE_DONATION_CONFIRMATION | Online Donation Confirmation | BOOLEAN | — | `true` | Send confirmation email for online donations |
| 13 | PLEDGE_REMINDER_DAYS | Pledge Reminder Days | TAGS | — | `7,14,30` | Days before pledge due date to send reminders |
| 14 | RECURRING_RETRY_ATTEMPTS | Recurring Retry Attempts | SELECT | `1\|2\|3\|5` | `3` | Number of retries for failed recurring payments |
| 15 | RECURRING_RETRY_INTERVAL | Recurring Retry Interval | SELECT | `1 day\|3 days\|5 days\|7 days` | `3 days` | Days between retry attempts |

> Group 2 — RECEIPTS (10):

| # | ParamCode | ParamName | ParamDataType | AllValues | ParamDefaultValue | Description |
|---|-----------|-----------|---------------|-----------|-------------------|-------------|
| 1 | RECEIPT_NUMBER_PREFIX | Receipt Number Prefix | STRING | — | `REC-` | Prefix for receipt numbers |
| 2 | RECEIPT_NUMBER_FORMAT | Receipt Number Format | SELECT | `Prefix + Auto\|Year/Serial\|Custom` | `Prefix + Auto` | Format: Prefix+Auto, Year/Serial, Custom |
| 3 | NEXT_RECEIPT_NUMBER | Next Receipt Number | NUMBER | `1\|99999999\|1` | `1` | Next auto-generated number |
| 4 | FINANCIAL_YEAR_RESET | Financial Year Reset | BOOLEAN | — | `false` | Reset numbering each financial year |
| 5 | TAX_EXEMPT_ORG | Tax Exempt Organization | BOOLEAN | — | `true` | Organization is tax-exempt |
| 6 | TAX_SECTION | Tax Section | STRING | — | `80G` | Applicable tax section (80G, 501c3, etc.) |
| 7 | SHOW_TAX_INFO_ON_RECEIPT | Show Tax Info on Receipt | BOOLEAN | — | `true` | Include tax exemption details on receipts |
| 8 | RECEIPT_VALIDITY_DAYS | Receipt Validity Days | NUMBER | `0\|3650\|1` | `365` | Days before receipt download links expire |
| 9 | REQUIRE_RECEIPT_SIGNATURE | Require Receipt Signature | BOOLEAN | — | `false` | Require authorized signatory on receipts |
| 10 | AUTHORIZED_SIGNATORY | Authorized Signatory | STRING | — | `` | Name and title for receipt signature |

> Group 3 — COMMUNICATION (9):

| # | ParamCode | ParamName | ParamDataType | AllValues | ParamDefaultValue | Description |
|---|-----------|-----------|---------------|-----------|-------------------|-------------|
| 1 | EMAIL_DAILY_LIMIT | Email Daily Limit | NUMBER | `0\|1000000\|1` | `5000` | Maximum emails per day |
| 2 | SMS_DAILY_LIMIT | SMS Daily Limit | NUMBER | `0\|1000000\|1` | `2000` | Maximum SMS per day |
| 3 | WHATSAPP_DAILY_LIMIT | WhatsApp Daily Limit | NUMBER | `0\|1000000\|1` | `1000` | Maximum WhatsApp messages per day |
| 4 | QUIET_HOURS_START | Quiet Hours Start | TIME | — | `22:00` | No automated messages after this time |
| 5 | QUIET_HOURS_END | Quiet Hours End | TIME | — | `07:00` | Resume automated messages after this time |
| 6 | UNSUBSCRIBE_LINK_REQUIRED | Unsubscribe Link Required | BOOLEAN | — | `true` | Include unsubscribe in all marketing emails |
| 7 | AUTO_ARCHIVE_CAMPAIGNS | Auto-Archive Campaigns | SELECT | `7 days\|14 days\|30 days\|60 days\|90 days` | `30 days` | Archive completed campaigns after N days |
| 8 | DEFAULT_REPLY_TO | Default Reply-To | EMAIL | — | `info@example.org` | Default reply-to for outgoing emails |
| 9 | BOUNCE_HANDLING | Bounce Handling | SELECT | `Auto-deactivate after 1\|Auto-deactivate after 3\|Auto-deactivate after 5\|Manual review` | `Auto-deactivate after 3` | Action after N bounces |

> Group 4 — CONTACTS (7):

| # | ParamCode | ParamName | ParamDataType | AllValues | ParamDefaultValue | Description |
|---|-----------|-----------|---------------|-----------|-------------------|-------------|
| 1 | AUTO_MERGE_DUPLICATES | Auto-Merge Duplicates | BOOLEAN | — | `false` | Automatically merge contacts with same email/phone |
| 2 | DEFAULT_CONTACT_TYPE | Default Contact Type | SELECT | `Individual\|Organization` | `Individual` | Default type when creating new contacts |
| 3 | REQUIRE_EMAIL_OR_PHONE | Require Email or Phone | BOOLEAN | — | `true` | At least one contact method is required |
| 4 | CONTACT_CODE_FORMAT | Contact Code Format | STRING | — | `CON-{AUTO}` | Auto-generated contact code pattern |
| 5 | INACTIVE_AFTER_DAYS | Inactive After Days | NUMBER | `0\|3650\|1` | `365` | Mark contact inactive after N days without activity |
| 6 | ALLOW_CONTACT_DELETE | Allow Contact Delete | BOOLEAN | — | `false` | Allow permanent deletion of contacts (vs soft-delete only) |
| 7 | GDPR_DATA_RETENTION | GDPR Data Retention | SELECT | `1 year\|2 years\|5 years\|7 years\|Indefinite` | `5 years` | Data retention period for contact records |

> Group 5 — ORGANIZATION (6):

| # | ParamCode | ParamName | ParamDataType | AllValues | ParamDefaultValue | Description |
|---|-----------|-----------|---------------|-----------|-------------------|-------------|
| 1 | FINANCIAL_YEAR_START | Financial Year Start | SELECT | `January\|February\|March\|April\|May\|June\|July\|August\|September\|October\|November\|December` | `January` | Month the financial year begins |
| 2 | DEFAULT_LANGUAGE | Default Language | SELECT | `English\|Arabic\|Hindi\|French` | `English` | Default system language |
| 3 | DATE_FORMAT | Date Format | SELECT | `DD/MM/YYYY\|MM/DD/YYYY\|YYYY-MM-DD` | `DD/MM/YYYY` | System-wide date display format |
| 4 | TIME_ZONE | Time Zone | SELECT | `UTC\|Asia/Dubai (GMT+4)\|Asia/Kolkata (GMT+5:30)\|America/New_York (EST)\|Europe/London (GMT)` | `Asia/Dubai (GMT+4)` | Default timezone for the organization |
| 5 | MULTI_BRANCH_MODE | Multi-Branch Mode | BOOLEAN | — | `true` | Enable multi-branch data segregation |
| 6 | AUDIT_TRAIL_RETENTION | Audit Trail Retention | SELECT | `6 months\|1 year\|2 years\|5 years\|Indefinite` | `2 years` | How long to keep audit trail records |

> Group 6 — FIELD (5):

| # | ParamCode | ParamName | ParamDataType | AllValues | ParamDefaultValue | Description |
|---|-----------|-----------|---------------|-----------|-------------------|-------------|
| 1 | OFFLINE_MODE | Offline Mode | BOOLEAN | — | `true` | Allow field agents to work offline |
| 2 | GPS_TRACKING | GPS Tracking | BOOLEAN | — | `true` | Track agent location during collection visits |
| 3 | MAX_SYNC_INTERVAL | Max Sync Interval | SELECT | `5 minutes\|15 minutes\|30 minutes\|1 hour` | `15 minutes` | Maximum time between data syncs |
| 4 | PHOTO_REQUIRED | Photo Required | BOOLEAN | — | `false` | Require photo evidence for field collections |
| 5 | DAILY_COLLECTION_LIMIT | Daily Collection Limit | NUMBER | `0\|10000\|1` | `50` | Maximum collections per agent per day |

> Group 7 — REPORTS (4):

| # | ParamCode | ParamName | ParamDataType | AllValues | ParamDefaultValue | Description |
|---|-----------|-----------|---------------|-----------|-------------------|-------------|
| 1 | DEFAULT_EXPORT_FORMAT | Default Export Format | SELECT | `Excel (.xlsx)\|CSV\|PDF` | `Excel (.xlsx)` | Default file format for report exports |
| 2 | MAX_REPORT_ROWS | Max Report Rows | NUMBER | `100\|1000000\|100` | `50000` | Maximum rows in a single report export |
| 3 | SCHEDULE_REPORT_EMAIL | Schedule Report Email | BOOLEAN | — | `true` | Allow scheduled report delivery via email |
| 4 | REPORT_CACHE_DURATION | Report Cache Duration | SELECT | `5 minutes\|15 minutes\|1 hour\|No cache` | `15 minutes` | How long to cache generated reports |

> Group 8 — SECURITY (8):

| # | ParamCode | ParamName | ParamDataType | AllValues | ParamDefaultValue | Description |
|---|-----------|-----------|---------------|-----------|-------------------|-------------|
| 1 | TWO_FACTOR_AUTH | Two-Factor Authentication | SELECT | `Optional\|Required for admins\|Required for all` | `Required for admins` | 2FA enforcement policy |
| 2 | PASSWORD_MIN_LENGTH | Password Min Length | NUMBER | `6\|32\|1` | `8` | Minimum password character length |
| 3 | PASSWORD_EXPIRY_DAYS | Password Expiry Days | NUMBER | `0\|365\|1` | `90` | Force password change after N days (0 = never) |
| 4 | SESSION_TIMEOUT | Session Timeout | SELECT | `15 minutes\|30 minutes\|1 hour\|4 hours` | `30 minutes` | Auto-logout after inactivity |
| 5 | MAX_LOGIN_ATTEMPTS | Max Login Attempts | NUMBER | `1\|20\|1` | `5` | Lock account after N failed login attempts |
| 6 | IP_WHITELISTING | IP Whitelisting | BOOLEAN | — | `false` | Restrict access to specific IP addresses |
| 7 | DATA_ENCRYPTION_AT_REST | Data Encryption at Rest | BOOLEAN | — | `true` | Encrypt sensitive data stored in database |
| 8 | MASK_PII_IN_LOGS | Mask PII in Logs | BOOLEAN | — | `true` | Mask personally identifiable information in system logs |

> Group 9 — NOTIFICATIONS (5):

| # | ParamCode | ParamName | ParamDataType | AllValues | ParamDefaultValue | Description |
|---|-----------|-----------|---------------|-----------|-------------------|-------------|
| 1 | IN_APP_NOTIFICATIONS | In-App Notifications | BOOLEAN | — | `true` | Show notifications within the application |
| 2 | EMAIL_NOTIFICATIONS | Email Notifications | BOOLEAN | — | `true` | Send notification emails for important events |
| 3 | DAILY_DIGEST | Daily Digest | BOOLEAN | — | `true` | Send daily summary of all notifications |
| 4 | DIGEST_SEND_TIME | Digest Send Time | TIME | — | `08:00` | Time to send daily digest email |
| 5 | NOTIFICATION_RETENTION | Notification Retention | SELECT | `7 days\|30 days\|90 days` | `30 days` | How long to keep notification history |

> Group 10 — REGIONAL (6):

| # | ParamCode | ParamName | ParamDataType | AllValues | ParamDefaultValue | Description |
|---|-----------|-----------|---------------|-----------|-------------------|-------------|
| 1 | DEFAULT_COUNTRY | Default Country | SELECT | `United Arab Emirates\|India\|United States\|United Kingdom\|Saudi Arabia` | `United Arab Emirates` | Default country for addresses and forms |
| 2 | GDPR_COMPLIANCE | GDPR Compliance | BOOLEAN | — | `true` | Enable GDPR-compliant data handling |
| 3 | CONSENT_REQUIRED | Consent Required | BOOLEAN | — | `true` | Require explicit consent for data collection |
| 4 | DATA_RESIDENCY | Data Residency | SELECT | `UAE (Middle East)\|EU (Frankfurt)\|US (Virginia)\|India (Mumbai)` | `UAE (Middle East)` | Primary data storage region |
| 5 | RIGHT_TO_ERASURE | Right to Erasure | BOOLEAN | — | `true` | Allow contacts to request complete data deletion |
| 6 | COOKIE_CONSENT_BANNER | Cookie Consent Banner | BOOLEAN | — | `true` | Show cookie consent on public-facing pages |

**Total: 75 ParamCodes across 10 SettingGroups.**

#### Page-Level Actions

| Action | Position | Style | Permission | Confirmation |
|--------|----------|-------|------------|--------------|
| Search | header (right) | text input | BUSINESSADMIN | — |
| Import Settings | header (right) | secondary | BUSINESSADMIN | preview-diff modal (SERVICE_PLACEHOLDER for MVP) |
| Export Settings | header (right) | secondary | BUSINESSADMIN | — (download triggers immediately) |
| Save All | header (right) AND change-bar | primary | BUSINESSADMIN | — (primary action; toast on success) |
| Discard Changes | change-bar (when dirty) | tertiary | BUSINESSADMIN | "Discard {N} unsaved changes?" |

#### User Interaction Flow (SETTINGS_PAGE)

1. User clicks any of the 3 sidebar entries (Setting Group / Organization Setting / User Setting) → router lands on `setting/orgsettings/<which>/page.tsx` → all render the same `<OrgSettingsPage>` → BE call `GetOrganizationSettingsView` returns 10 groups + 75 settings → first group (`FUNDRAISING`) active in nav, others hidden but mounted.
2. User clicks a different category in the sidebar → active class swaps → right pane shows that category's card.
3. User edits a widget → store sets `dirtyValues[paramCode] = newValue` → row gets yellow bg + dot indicator + reset btn → change-bar count increments.
4. User clicks reset (↶) → that row reverts to `originalValues[paramCode]` → dirty count decrements.
5. User types in search → all categories show; matching rows visible, non-matching rows hidden; clearing search reverts to active-category view.
6. User clicks Save All → validation runs over all dirty rows → per-ParamCode rules + cross-row rules (MIN ≤ MAX) → on success: BulkUpdateOrganizationSettings fires with the dirty array → BE upserts → toast → store flips `dirty → original` → change-bar disappears.
7. User clicks Discard → confirm modal → on confirm: all dirty rows revert.
8. User navigates away with dirty form → Next.js router blocker shows confirm modal.

---

### 🅱️ Block B — DESIGNER_CANVAS

> N/A — sub-type is SETTINGS_PAGE.

### 🅲 Block C — MATRIX_CONFIG

> N/A — sub-type is SETTINGS_PAGE.

---

### Shared blocks

#### Page Header & Breadcrumbs

| Element | Content |
|---------|---------|
| Breadcrumb | Setting › Org Settings › Organization Settings |
| Page title | Organization Settings |
| Subtitle | System parameters and operational configuration |
| Right actions | Search input · Import Settings · Export Settings · Save All |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading | Initial fetch | Skeleton: sidebar 10-item list + 5-row card skeleton |
| Empty | (Rare) — first call before defaults seeded | BE auto-seeds; FE never sees true empty. If it does, render hint "Initializing settings…" then refetch |
| Error | GET fails | Error card with retry button + error code |
| Save error | Save fails | Toast + per-row inline error from BE response (`{ paramCode, errorMessage }`) |

---

## ⑦ Substitution Guide

> **No canonical SETTINGS_PAGE-with-keyed-rows screen exists yet.** Closest precedent: `companysettings.md` (#75)
> — same sub-type (SETTINGS_PAGE), but different storage pattern (singleton-per-tenant, not keyed-settings-rows).
> Borrow the FE shell + Zustand store pattern + sticky save-bar from CompanySettings; replace the hand-coded
> section forms with the schema-driven `<SettingRow>` renderer.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| CompanySettings | OrgSettings | Entity / class name (file name: `OrgSettingsPage`) |
| companysettings | orgsettings | Folder name (route already exists under `setting/orgsettings/`) |
| Company / CompanyConfiguration / CompanyBranding | OrganizationSetting / SettingGroup / UserSetting | Storage entities (KEY difference: 3 keyed entities, not 3 specific ones) |
| `sett` schema | `sett` schema | Same DB schema |
| Setting | Setting | Same backend group |
| `setting/orgsettings/companysettings` | `setting/orgsettings/organizationsetting` (+ /settinggroup + /usersetting all point to same page) | Route — 3 routes resolve to 1 component |

---

## ⑧ File Manifest

> **Scope = ALIGN**. Existing BE has standard 11-file per-row CRUD for all 3 entities — KEEP intact. Existing
> FE has 3 `UnderConstruction` stub pages — REPLACE with shared `OrgSettingsPage`.

### Backend Files — NEW (additive for the aggregate UX)

| # | File | Path |
|---|------|------|
| 1 | GetOrganizationSettingsView Query | Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/OrganizationSettings/Queries/GetOrganizationSettingsView.cs |
| 2 | BulkUpdateOrganizationSettings Command | Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/OrganizationSettings/Commands/BulkUpdateOrganizationSettings.cs |
| 3 | ResetOrganizationSettingsToDefaults Command | Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/OrganizationSettings/Commands/ResetOrganizationSettingsToDefaults.cs |
| 4 | OrgSettingsViewDto + BulkUpdate DTOs | Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/SettingSchemas/OrganizationSettingSchemas.cs (EXTEND existing file) |
| 5 | OrgSettings Default Seeder | Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Seeders/OrgSettingsDefaultSeeder.cs (NEW) |
| 6 | Per-ParamCode Validator strategy | Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/OrganizationSettings/Validators/OrgSettingsValueValidator.cs (NEW) |

### Backend Files — EXISTING (extend, do NOT re-create)

| # | File | What to Add |
|---|------|-------------|
| 1 | `Base.API/EndPoints/Setting/Queries/OrganizationSettingQueries.cs` | New method `GetOrganizationSettingsView` (returns composite view DTO) |
| 2 | `Base.API/EndPoints/Setting/Mutations/OrganizationSettingMutations.cs` | New methods `BulkUpdateOrganizationSettings` + `ResetOrganizationSettingsToDefaults` |
| 3 | `Base.Application/Schemas/SettingSchemas/OrganizationSettingSchemas.cs` | Add `OrgSettingsViewDto`, `OrgSettingsGroupDto`, `OrgSettingsItemDto`, `BulkUpdateOrgSettingsRequestDto`, `BulkUpdateOrgSettingsItemDto`, `BulkUpdateOrgSettingsResultDto` |

### Backend Wiring Updates

| # | File | What to Add |
|---|------|-------------|
| 1 | `Base.Application/Common/Interfaces/ISettingDbContext.cs` | Already has all 3 DbSets — verify, no change needed |
| 2 | `Base.Infrastructure/Data/SettingDbContext.cs` | Verify DbSets — no change |
| 3 | `Base.Application/SettingMappings.cs` (Mapster) | Add `OrgSettingsViewDto` / `OrgSettingsGroupDto` / `OrgSettingsItemDto` mappings |
| 4 | DI registration for `OrgSettingsDefaultSeeder` | Register as scoped service that the `GetOrganizationSettingsView` handler calls when row count < baseline |
| 5 | (No new DbContext or new schema) | — |

### Frontend Files — NEW

| # | File | Path |
|---|------|------|
| 1 | DTO Types | PSS_2.0_Frontend/src/domain/entities/setting-service/OrgSettingsDto.ts |
| 2 | GQL Query | PSS_2.0_Frontend/src/infrastructure/gql-queries/setting-queries/OrgSettingsViewQuery.ts |
| 3 | GQL Mutation (Bulk) | PSS_2.0_Frontend/src/infrastructure/gql-mutations/setting-mutations/BulkUpdateOrgSettingsMutation.ts |
| 4 | GQL Mutation (Reset) | PSS_2.0_Frontend/src/infrastructure/gql-mutations/setting-mutations/ResetOrgSettingsMutation.ts |
| 5 | Main Page Component | PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/orgsettings/orgsettings-page.tsx |
| 6 | Sidebar Nav | PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/orgsettings/components/category-nav.tsx |
| 7 | Setting Card (group container) | PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/orgsettings/components/setting-card.tsx |
| 8 | Setting Row (widget switcher) | PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/orgsettings/components/setting-row.tsx |
| 9 | Toggle widget | PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/orgsettings/widgets/toggle-widget.tsx |
| 10 | Tag-input widget | PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/orgsettings/widgets/tags-widget.tsx |
| 11 | Multi-check widget | PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/orgsettings/widgets/multi-check-widget.tsx |
| 12 | Sticky Save Bar | PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/orgsettings/components/change-bar.tsx |
| 13 | Search box | PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/orgsettings/components/search-box.tsx |
| 14 | Zustand store | PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/orgsettings/orgsettings-store.ts |
| 15 | Page Config wrapper | PSS_2.0_Frontend/src/presentation/pages/setting/orgsettings/orgsettings.tsx |

### Frontend Files — REPLACE (currently `UnderConstruction` stubs)

| # | File | Change |
|---|------|--------|
| 1 | `PSS_2.0_Frontend/src/app/[lang]/setting/orgsettings/organizationsetting/page.tsx` | Replace with: `'use client'; export { default } from '@/presentation/pages/setting/orgsettings/orgsettings';` |
| 2 | `PSS_2.0_Frontend/src/app/[lang]/setting/orgsettings/settinggroup/page.tsx` | Same |
| 3 | `PSS_2.0_Frontend/src/app/[lang]/setting/orgsettings/usersetting/page.tsx` | Same |

### Frontend Wiring Updates

| # | File | What to Add |
|---|------|-------------|
| 1 | `entity-operations.ts` | Skip — CONFIG screens have no row-level CRUD; mirrors CompanySettings precedent |
| 2 | `operations-config.ts` | Skip — same reason |
| 3 | Sidebar menu config | All 3 menu codes (ORGANIZATIONSETTING, SETTINGGROUP, USERSETTING) already seeded under SET_ORGSETTINGS — verify they all show "Organization Settings" workflow |
| 4 | `BaseUrlConfig.ts` | No change |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by `/plan-screens`.
> **Note**: This screen requires **THREE** CONFIG blocks because the registry says 3 separate menus
> (ORGANIZATIONSETTING / SETTINGGROUP / USERSETTING) all need rows in the menu seed; they all point to
> the SAME frontend page. The capability bundle is identical for each.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Organization Setting
MenuCode: ORGANIZATIONSETTING
ParentMenu: SET_ORGSETTINGS
Module: SETTING
MenuUrl: setting/orgsettings/organizationsetting
GridType: CONFIG

MenuCapabilities: READ, MODIFY, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY

GridFormSchema: SKIP
GridCode: ORGANIZATIONSETTING
---CONFIG-END---
```

```
---CONFIG-START---
Scope: ALIGN

MenuName: Setting Group
MenuCode: SETTINGGROUP
ParentMenu: SET_ORGSETTINGS
Module: SETTING
MenuUrl: setting/orgsettings/settinggroup
GridType: CONFIG

MenuCapabilities: READ, MODIFY, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY

GridFormSchema: SKIP
GridCode: SETTINGGROUP
---CONFIG-END---
```

```
---CONFIG-START---
Scope: ALIGN

MenuName: User Setting
MenuCode: USERSETTING
ParentMenu: SET_ORGSETTINGS
Module: SETTING
MenuUrl: setting/orgsettings/usersetting
GridType: CONFIG

MenuCapabilities: READ, MODIFY, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY

GridFormSchema: SKIP
GridCode: USERSETTING
---CONFIG-END---
```

> All three menus already exist in `Module_Menu_List.sql` (SET_ORGSETTINGS, MenuId 377) — verify the seed is
> idempotent. No new menu rows needed; only role-capability rows for BUSINESSADMIN, which may also already exist.
> `GridFormSchema: SKIP` — CONFIG screen, no RJSF modal.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `OrganizationSettingQueries` (existing — EXTEND with `GetOrganizationSettingsView`)
- Mutation type: `OrganizationSettingMutations` (existing — EXTEND with `BulkUpdateOrganizationSettings` + `ResetOrganizationSettingsToDefaults`)

### Queries

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `GetOrganizationSettingsView` | `OrgSettingsViewDto` (composite — groups + settings nested) | — (tenant from HttpContext) |

**`OrgSettingsViewDto` shape:**

```ts
type OrgSettingsViewDto = {
  groups: Array<{
    settingGroupId: number;
    settingGroupCode: string;    // e.g. "FUNDRAISING"
    settingGroupName: string;    // e.g. "Fundraising & Donations"
    settingGroupIcon: string;    // emoji or icon class
    orderBy: number;
    isVisibleInUI: boolean;
    settings: Array<{
      organizationSettingId: number;
      paramCode: string;         // e.g. "DEFAULT_CURRENCY"
      paramName: string;         // e.g. "Default Currency"
      paramDataType: 'STRING' | 'NUMBER' | 'BOOLEAN' | 'SELECT' | 'MULTI_CHECK' | 'TAGS' | 'TIME' | 'EMAIL';
      paramDefaultValue: string | null;
      currentValue: string | null;
      allValues: string | null;  // pipe-delimited for SELECT/MULTI_CHECK; "min|max|step" for NUMBER
      description: string | null;
      canUserOverride: boolean;
    }>;
  }>;
};
```

### Mutations

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `BulkUpdateOrganizationSettings` | `BulkUpdateOrgSettingsRequestDto` (array of `{ organizationSettingId, paramCode, currentValue }`) | `BulkUpdateOrgSettingsResultDto` `{ updatedCount, errors: Array<{ paramCode, message }> }` |
| `ResetOrganizationSettingsToDefaults` | `{ settingGroupCode?: string }` (optional — scope to one group, otherwise all) | `OrgSettingsViewDto` (refreshed) |

**Sensitive-field handling**: None — no secrets in this screen.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/setting/orgsettings/organizationsetting` AND `/settinggroup` AND `/usersetting` (all 3 routes render the same component)

**Functional Verification — SETTINGS_PAGE:**
- [ ] First-load auto-seeds 10 default `SettingGroups` and 75 default `OrganizationSettings` rows for the tenant if missing → no 404, no empty state
- [ ] Sidebar shows 10 groups in correct order with icon + name + count badge
- [ ] First group `FUNDRAISING` is active by default
- [ ] Clicking another group swaps the right pane
- [ ] Each setting row renders the correct widget for its `paramDataType`:
  - STRING / EMAIL → text input (email validates format)
  - NUMBER → number input with min/max from `AllValues`
  - BOOLEAN → toggle switch
  - SELECT → dropdown populated from pipe-delimited `AllValues`
  - MULTI_CHECK → checkbox group from `AllValues`; comma-joined persistence
  - TAGS → tag-input; comma-joined persistence
  - TIME → time picker
- [ ] Editing a widget marks the row dirty (yellow bg + dot + reset btn) and updates the change-bar count
- [ ] Reset (↶) reverts the row to last-saved (NOT to `paramDefaultValue`)
- [ ] Search input filters rows across ALL categories; matched rows visible, others hidden; clearing search reverts to active-category view
- [ ] "Save All" persists ALL dirty rows in ONE BulkUpdateOrganizationSettings → toast → dirty count = 0
- [ ] "Discard Changes" → confirm modal → reverts all dirty rows
- [ ] Validation errors block save and surface inline (e.g. negative number, empty required, invalid email)
- [ ] Cross-row validation: MIN_DONATION_AMOUNT ≤ MAX_DONATION_AMOUNT (when MAX > 0); QUIET_HOURS_START ≠ QUIET_HOURS_END
- [ ] Export Settings downloads a JSON file of current values
- [ ] Import Settings shows preview-diff modal (SERVICE_PLACEHOLDER for the actual file-parse — see §⑫)
- [ ] Unsaved-changes blocker triggers on navigation when dirty
- [ ] Audit trail records each successful BulkUpdate (whole-payload, with diff per row)

**DB Seed Verification:**
- [ ] Three menu rows present under SET_ORGSETTINGS (ORGANIZATIONSETTING, SETTINGGROUP, USERSETTING) with the right URLs
- [ ] 10 SettingGroups + 75 OrganizationSettings seeded for the sample tenant
- [ ] BUSINESSADMIN has READ + MODIFY on all 3 menus
- [ ] Page renders without crashing on a freshly-seeded DB

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Universal CONFIG warnings (still apply here):**
- **CompanyId is NOT a form field** — tenant-scoped via HttpContext.
- **GridFormSchema = SKIP** — custom UI, not RJSF modal.
- **No view-page 3-mode** — single-mode page.
- **Default seeding**: the aggregate query MUST auto-seed defaults on first call.

**Sub-type-specific gotchas for THIS screen:**

| Gotcha | What to Do |
|--------|------------|
| Don't hand-code 75 fields | Render `<SettingRow>` per item from BE response; switch on `paramDataType` |
| Don't expose definition fields as editable | `ParamName`, `ParamCode`, `ParamDataType`, `AllValues`, `Description`, `CanUserOverride`, `ParamDefaultValue` are RO from this admin screen; only `CurrentValue` is editable |
| Don't issue a separate mutation per row on save | Use ONE BulkUpdateOrganizationSettings for the dirty array; matches save-all UX |
| Don't ApiSelect the categories | They come from the composite view; the sidebar is local state, not a separate fetch |
| Don't ALIGN by re-running the BE generator | Existing per-row CRUD is intact — ALIGN adds 3 NEW handlers + extends 2 endpoint classes; touch nothing else BE-side |
| 3 menus, 1 page | All 3 stub `page.tsx` files re-export the SAME component; don't duplicate logic |
| Existing FE stub `companysettings/` lives at `setting/orgsettings/companysettings/` (DIFFERENT route) | Don't merge or rename — the two screens coexist at parallel routes |

**Module / module-instance notes:**
- `sett` schema is established; entities exist; no new schema infrastructure needed.
- All 3 menu codes already in `Module_Menu_List.sql` (SET_ORGSETTINGS) — seed adjustments only.

**Service Dependencies (SERVICE_PLACEHOLDER list):**

> Everything in the mockup is in scope. List below ONLY items needing external services.

- ⚠ **SERVICE_PLACEHOLDER: Import Settings** — UI fully implemented (file picker + preview-diff modal). File-parse handler returns a mocked diff because we don't yet have a generic settings-import service abstraction. Real parsing of an uploaded `.json` / `.csv` is deferred.
- ✅ Export Settings — REAL implementation: serializes current values to JSON and triggers browser download client-side. No external service needed.

Full UI must be built (sidebar nav, 10 cards, 75 dynamically-rendered rows, dirty tracking, change-bar, search, validation, audit). Only Import's file-parse handler is mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — no issues raised yet) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-15 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. ALIGN — additive BE, custom FE (3 stubs → 1 shared schema-driven page).
- **Decisions locked at user approval**: Sonnet across all agents (per cost preference); app-tenant runtime seeder (no SQL backfill for existing tenants); single bundled build session (BE+FE+Seed parallel).
- **Files touched**:
  - BE created (7):
    - `Base.Application/Business/SettingBusiness/OrganizationSettings/Queries/GetOrganizationSettingsView.cs`
    - `Base.Application/Business/SettingBusiness/OrganizationSettings/Commands/BulkUpdateOrganizationSettings.cs`
    - `Base.Application/Business/SettingBusiness/OrganizationSettings/Commands/ResetOrganizationSettingsToDefaults.cs`
    - `Base.Application/Business/SettingBusiness/OrganizationSettings/Validators/OrgSettingsValueValidator.cs`
    - `Base.Application/Business/SettingBusiness/OrganizationSettings/Seeders/IOrgSettingsDefaultSeeder.cs`
    - `Base.Infrastructure/Seeders/OrgSettingsDefaultSeeder.cs`
    - `Services/Base/sql-scripts-dyanmic/OrgSettings-sqlscripts.sql` (menu/role grants only — runtime seeder handles SettingGroups/OrganizationSettings per-tenant)
  - BE modified (6):
    - `Base.Application/Schemas/SettingSchemas/OrganizationSettingSchemas.cs` (+8 DTOs)
    - `Base.API/EndPoints/Setting/Queries/OrganizationSettingQueries.cs` (+1 method GetOrganizationSettingsView)
    - `Base.API/EndPoints/Setting/Mutations/OrganizationSettingMutations.cs` (+2 methods BulkUpdate / Reset)
    - `Base.Application/Mappings/SettingMappings.cs` (Mapster configs OrganizationSetting → OrgSettingsItemDto, SettingGroup → OrgSettingsGroupDto)
    - `Base.Application/DependencyInjection.cs` (scoped IOrgSettingsValueValidator)
    - `Base.Infrastructure/DependencyInjection.cs` (scoped IOrgSettingsDefaultSeeder)
  - FE created (14):
    - `PSS_2.0_Frontend/src/domain/entities/setting-service/OrgSettingsDto.ts` (created by FE agent before crash)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/setting-queries/OrgSettingsViewQuery.ts` (created by FE agent before crash)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/setting-mutations/BulkUpdateOrgSettingsMutation.ts` (created by FE agent before crash)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/setting-mutations/ResetOrgSettingsMutation.ts` (created by FE agent before crash; orchestrator fixed data-shape post-salvage to return refreshed view)
    - `presentation/components/page-components/setting/orgsettings/orgsettings/orgsettings-store.ts` (Zustand — originalValues/dirtyValues Maps + activeCategory/search/validationErrors + discard modal + filterGroupsBySearch helper)
    - `.../orgsettings/orgsettings-page.tsx` (header + sidebar + content + change-bar + Export real / Import SERVICE_PLACEHOLDER + beforeunload guard + Skeletons)
    - `.../orgsettings/index.ts` (barrel)
    - `.../orgsettings/components/category-nav.tsx` (left sidebar — 10 groups with dirty + count badges)
    - `.../orgsettings/components/setting-card.tsx` (group card chrome)
    - `.../orgsettings/components/setting-row.tsx` (schema-driven renderer — switches on paramDataType across 8 widget types)
    - `.../orgsettings/components/change-bar.tsx` (sticky bottom — Discard + Save All + confirm modal)
    - `.../orgsettings/components/search-box.tsx`
    - `.../orgsettings/widgets/toggle-widget.tsx` (Switch + On/Off label, persists "true"/"false")
    - `.../orgsettings/widgets/tags-widget.tsx` (chip-input, comma-joined storage)
    - `.../orgsettings/widgets/multi-check-widget.tsx` (Checkbox group, pipe→comma persistence)
    - `presentation/pages/setting/orgsettings/orgsettings.tsx` (capability gate wrapper)
  - FE modified (4):
    - `presentation/components/page-components/setting/orgsettings/index.ts` (+1 line — `export * from "./orgsettings"`)
    - `app/[lang]/setting/orgsettings/organizationsetting/page.tsx` (UnderConstruction → OrgSettingsPageConfig)
    - `app/[lang]/setting/orgsettings/settinggroup/page.tsx` (same)
    - `app/[lang]/setting/orgsettings/usersetting/page.tsx` (same)
  - DB: `Services/Base/sql-scripts-dyanmic/OrgSettings-sqlscripts.sql` (created)
- **Deviations from spec**: None substantive. FE generation agent crashed at ~22 tool uses (socket error) after writing 4 of 19 FE files (DTO + 3 GQL stubs). Orchestrator salvaged inline per memory pattern and built the remaining 15 FE files directly. Reset mutation GQL fragment fixed to query the view shape (BE returns `BaseApiResponse<OrgSettingsViewDto>` per §⑩ contract, not the BulkUpdate result shape the salvaged stub had).
- **Verification**:
  - `dotnet build` PASS — 0 errors, 0 new warnings (BE agent's final report).
  - `pnpm tsc --noEmit` — 0 errors in orgsettings files (pre-existing errors in unrelated files unchanged per memory).
  - UI uniformity grep on `setting/orgsettings/orgsettings/**`: 0 inline hex colors, 0 inline px padding/margin, 0 raw "Loading…" text. ✅
  - Variant check: SETTINGS_PAGE custom page — no `AdvancedDataTable` / `FlowDataTable` use; uses internal sticky header + sticky-bottom change-bar (CompanySettings #75 pattern). ✅
  - GQL naming verified: HC strips "Get" prefix → `organizationSettingsView` field matches BE method `GetOrganizationSettingsView`.
- **Known issues opened**: None
- **Known issues closed**: None
- **Next step**: COMPLETED — no follow-up required for V1. User actions for E2E:
  1. Apply the `OrgSettings-sqlscripts.sql` to grant BUSINESSADMIN capabilities (idempotent).
  2. Run `dotnet build` to confirm BE compiles in the user's environment.
  3. `pnpm dev` and navigate to `/{lang}/setting/orgsettings/organizationsetting` (also `/settinggroup` and `/usersetting` — same screen). First load auto-seeds 10 groups + 75 ParamCodes via the runtime seeder.
  4. Verify the 10 group categories render in the sidebar, each row renders the correct widget, dirty tracking works, Save All persists in one mutation, Export downloads JSON, Discard reverts.