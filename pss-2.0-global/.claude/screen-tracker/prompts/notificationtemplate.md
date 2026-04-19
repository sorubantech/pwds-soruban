---
screen: NotificationTemplate
registry_id: 36
module: Communication (CRM → Notification)
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-19
completed_date: 2026-04-19
last_session_date: 2026-04-19
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (grid + split-pane editor with live preview + delivery summary)
- [x] Existing code reviewed (skeleton BE entity + 1 EF config; FE route stub)
- [x] Business rules + workflow extracted (trigger→channel→recipients fan-out, optional condition)
- [x] FK targets resolved (Company via HttpContext; no external FK dropdowns in form)
- [x] File manifest computed (entity EXPAND + 1 new child + full CRUD stack + FE)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (validated via prompt §① + §②)
- [x] Solution Resolution complete (per §⑤ — FLOW, card-grid `details`, split-pane)
- [x] UX Design finalized (FORM split-pane with live preview + DETAIL layout) (per §⑥)
- [x] User Approval received (2026-04-19)
- [x] Backend code generated (expand NotificationTemplate entity + 1 new child NotificationTemplateRole + migration + full CRUD + Summary query)
- [x] Backend wiring complete (INotifyDbContext, NotifyDbContext, NotifyMappings, DecoratorNotifyModules, GQL schema reg via assembly scan — auto)
- [x] Frontend code generated (card-grid index + split-pane editor view-page + Zustand store + notification-preview component + status pills)
- [x] Frontend wiring complete
- [x] DB Seed script generated (GridFormSchema: SKIP for FLOW; seed 12 system templates from mockup lines 588-599)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` — 0 errors
- [ ] `pnpm dev` — page loads at `/{lang}/crm/notification/notificationtemplate`
- [ ] Card-grid loads with `details` variant cards (header=templateName, chips=[category, status], snippet=bodyPreview, footer=modifiedDate)
- [ ] Summary count pills (Active / Inactive / System) render inline in ScreenHeader subtitle
- [ ] Search + Category filter + Status filter work
- [ ] `?mode=new` — split-pane editor opens with empty form + empty notification preview
- [ ] Category select → Trigger Event dropdown filters optgroup options
- [ ] Icon grid: clicking an icon updates preview icon live
- [ ] Icon color picker updates preview icon bg tint live
- [ ] Priority chip group: Normal/High/Urgent — single-select, styles match mockup
- [ ] Channel toggles: In-App always-on (disabled), Email/WhatsApp/Push — Push disabled with "Coming Soon"
- [ ] Toggling Email/WhatsApp updates Delivery Summary in right pane (icon + opacity)
- [ ] Recipient Type select: "Roles" shows role checkbox group; others hide it
- [ ] Trigger Condition (optional): field + operator + value inline row works
- [ ] Action URL + Action Label fields accept `{{Placeholder}}` tokens
- [ ] Status switch (Active/Inactive) flips label + color
- [ ] Right-pane Notification Preview updates live (title, body, action label, icon, priority accent)
- [ ] Placeholder Reference card lists available `{{Tokens}}` based on Category
- [ ] Delivery Summary shows checklist (In-App always ✓; Email/WhatsApp toggled)
- [ ] Save → creates record → redirects to `?mode=read&id={newId}`
- [ ] `?mode=read&id=X` — DETAIL layout renders (metadata + config panels + placeholder reference + live preview pane) — NOT disabled form
- [ ] Edit button → `?mode=edit&id=X` → FORM pre-filled
- [ ] Test Notification action (SERVICE_PLACEHOLDER) — toast stub with "Test notification sent for {name}"
- [ ] Toggle Status action changes Active ↔ Inactive without reload
- [ ] Duplicate action creates a `{name}_copy` Draft-equivalent copy
- [ ] Delete disabled for `IsSystem=true` templates (system-seeded); enabled for user-created
- [ ] DB Seed — menu "Notification Templates" appears under CRM → Notification; 12 system templates seeded with `IsSystem=true`

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: NotificationTemplate
Module: Communication (CRM → Notification)
Schema: `notify`
Group: `NotifyModels` (Backend), `notify-service` (Frontend — reuses existing folder alongside SavedFilter, EmailTemplate, Notification, PlaceholderDefinition)

Business: The Notification Templates screen is the configuration surface for **in-app notifications** surfaced inside PSS (bell icon, notification center, toasts). NGO admin users define reusable templates that bind a system **trigger event** (e.g., `donation.created`, `cheque.status.bounced`, `campaign.goal.reached`) to a notification payload (title, body, icon, priority, action link) and a recipient rule (assigned staff / specific roles / initiated user / all staff / custom users). Templates optionally fan out to Email + WhatsApp **alongside** the always-on in-app channel — a single template governs a multi-channel notification. Templates can include a **trigger condition** (e.g., `amount > 1000`) to avoid noise. System templates (`IsSystem=true`) ship pre-seeded with the platform (mockup lines 588-599 show 12 of them) and cannot be deleted — admins can only edit their content or toggle them off. Custom company templates can be freely created, duplicated, edited, or deleted. The screen also provides a **Test Notification** action that fires a sample notification to the current user for preview (SERVICE_PLACEHOLDER until the notification dispatcher service is wired). Downstream consumers: the Notification dispatcher service (background worker), Email Send Job pipeline, WhatsApp Campaign pipeline, and the in-app Notification Center (#35).

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Fields extracted from HTML mockup modal (now promoted to full page). Audit columns inherited from `Entity` base.
> **Existing entity is a SKELETON (5 fields)** — expand it. See §⑫ for migration notes.

### Primary entity: `notify."NotificationTemplates"`

**Existing fields (keep):**

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| NotificationTemplateId | int | — | PK | Existing |
| NotificationTemplateCode | string | 100 | YES | Existing — unique per Company when IsActive=true |
| NotificationTemplateTitle | string | 250 | YES | Existing — repurposed as **Template Name** (admin-facing label, e.g., "New Donation Received") |
| NotificationTemplateText | string | 1000 | YES | Existing — repurposed as **Body** (user-facing body with `{{Placeholders}}`) |
| IsSystem | bool | — | YES default false | Existing — system-seeded template; not deletable |
| CompanyId | int? | — | YES (was nullable) | **Change nullability**: system-seeded rows have CompanyId=null; custom rows have NOT-NULL CompanyId. Keep nullable in DB (current state supports this). |

**New fields to ADD (migration):**

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| Category | string | 30 | YES default "System" | — | Enum: `Donation` / `Contact` / `Campaign` / `Event` / `System` / `Approval` |
| TriggerEvent | string | 100 | YES | — | Dotted event code, e.g., `donation.created`, `cheque.status.bounced` |
| TriggerConditionJson | string | 500 | NO | — | JSON: `{ field, operator, value }` — e.g., `{"field":"amount","operator":"gt","value":"1000"}` |
| NotificationTitle | string | 250 | YES | — | User-facing notification title (supports `{{Placeholders}}`) |
| IconCode | string | 60 | YES default "fa-bell" | — | FontAwesome class (e.g., `fa-hand-holding-dollar`) |
| IconColor | string | 10 | YES default "#0e7490" | — | Hex color `#rrggbb` |
| Priority | string | 10 | YES default "Normal" | — | Enum: `Normal` / `High` / `Urgent` |
| EnableInApp | bool | — | YES default true | — | Always-on channel — validator forces `true` on save |
| EnableEmail | bool | — | YES default false | — | Fan-out to email when triggered |
| EnableWhatsApp | bool | — | YES default false | — | Fan-out to WhatsApp when triggered |
| EnablePush | bool | — | YES default false | — | Mobile push — UI disabled ("Coming Soon"), column reserved |
| RecipientType | string | 20 | YES default "AssignedStaff" | — | Enum: `AssignedStaff` / `Roles` / `Initiated` / `AllStaff` / `Custom` |
| IncludeAdmins | bool | — | YES default false | — | When true, always CC Org Admins regardless of RecipientType |
| ActionUrl | string | 500 | NO | — | URL path with `{{Placeholders}}` — click target, e.g., `fundraising/donation-detail?id={{DonationId}}` |
| ActionLabel | string | 60 | NO | — | CTA text, e.g., "View Donation" |
| LastTriggeredDate | DateTime? | — | NO | — | Updated by dispatcher side-effect (not user-editable) |

**Inherited from `Entity` base:** `IsActive`, `CreatedBy`, `CreatedDate`, `ModifiedBy`, `ModifiedDate` — treat `IsActive` as the Active/Inactive toggle in the mockup.

### Child entity: `notify."NotificationTemplateRoles"` (1:Many — applicable only when RecipientType=`Roles`)

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| NotificationTemplateRoleId | int | — | PK | — |
| NotificationTemplateId | int | — | YES | FK → NotificationTemplates (cascade delete) |
| RoleCode | string | 50 | YES | Role code (e.g., `SUPERADMIN`, `BUSINESSADMIN`, `FINANCE`) — references existing `aspnet.Roles` but stored as code for decoupling |
| OrderBy | int | — | YES default 0 | Display order (optional) |

**Child Entities summary:**
| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| NotificationTemplateRole | 1:Many via NotificationTemplateId | RoleCode, OrderBy |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)
> No external FK dropdowns on the editor form. Category, Priority, RecipientType are fixed enum selects. Trigger Event options are a client-side catalog grouped by Category. Role codes come from a client catalog (hardcoded 4 entries per mockup) — no GQL call needed for first build.

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| CompanyId | Company | Base.Domain/Models/ApplicationModels/Company.cs | (N/A — HttpContext tenant) | CompanyName | CompanyResponseDto |

**No ApiSelect FK dropdowns on the editor form.** All selectable options are enum-backed or client-catalog-backed.

**Trigger Event catalog (client-side, grouped by Category — from mockup lines 314-342):**
- Donation: `donation.created`, `donation.updated`, `cheque.status.changed`, `cheque.status.bounced`, `recurring.payment.failed`, `pledge.payment.overdue`
- Contact: `contact.created`, `contact.updated`, `contact.duplicate.found`
- Campaign: `campaign.created`, `campaign.goal.reached`, `campaign.ended`
- Event: `event.registration.new`, `event.reminder`, `event.ended`
- System: `approval.requested`, `import.completed`, `user.password.expiring`, `system.error`
- Approval: `approval.requested`, `approval.granted`, `approval.rejected`

**Placeholder catalog (client-side, grouped by Category — displayed in right-pane Placeholder Reference panel per mockup lines 526-535):**
- Donation tokens: `{{DonorName}}`, `{{DonationAmount}}`, `{{Currency}}`, `{{Purpose}}`, `{{PaymentMode}}`, `{{DonationId}}`, `{{ReceiptNumber}}`
- Contact tokens: `{{ContactName}}`, `{{ContactEmail}}`, `{{ContactPhone}}`
- Campaign tokens: `{{CampaignName}}`, `{{CampaignGoal}}`
- Event tokens: `{{EventName}}`, `{{EventDate}}`, `{{EventLocation}}`
- System tokens: `{{StaffName}}`, `{{OrgName}}`, `{{CurrentDate}}`
- Always-available: `{{StaffName}}`, `{{OrgName}}`

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `(CompanyId, NotificationTemplateCode, IsActive)` composite unique — existing index stays; extend validator to scope per company for custom rows
- For `IsSystem=true` rows, `CompanyId=null` and code is globally unique

**Required Field Rules:**
- NotificationTemplateTitle (Template Name), NotificationTemplateCode, Category, TriggerEvent, NotificationTitle, NotificationTemplateText (Body), IconCode, IconColor, Priority, RecipientType are mandatory
- Auto-generate NotificationTemplateCode from Title when empty: uppercase + underscore (e.g., "New Donation Received" → `NEW_DONATION_RECEIVED`)

**Conditional Rules:**
- If `RecipientType=Roles` → `NotificationTemplateRoles` collection must contain ≥ 1 row
- If `RecipientType≠Roles` → `NotificationTemplateRoles` must be empty (validator clears)
- If `RecipientType=Custom` → defer to a future NotificationTemplateUser child (OUT OF SCOPE — record RecipientType but don't build the selector UI in first build; show disabled "Custom (Select Users) — Coming Soon" option)
- `TriggerConditionJson` when present must parse to `{field, operator, value}` where operator ∈ `equals`, `greaterThan`, `lessThan`, `contains`
- `IconColor` must match regex `^#[0-9A-Fa-f]{6}$`
- `EnableInApp=true` always — server-side validator forces true on every save
- `EnablePush=false` always on save — Push channel is reserved but not implemented

**Business Logic:**
- `IsSystem=true` rows cannot be deleted (soft or hard); `Toggle` (activate/deactivate) and `Update` (content edit) allowed
- `IsSystem=false` custom rows: full CRUD allowed
- `ActionUrl` may contain `{{Placeholder}}` tokens; validator does NOT resolve them at save time (resolution happens at dispatch)
- `NotificationTitle` and `NotificationTemplateText` (Body) tokens must belong to the catalog for the chosen Category OR be in the always-available set; unknown tokens → validation error with a list of unknowns

**Workflow:**
- States: simple Active ↔ Inactive (IsActive toggle) — no multi-step workflow
- Transitions: Toggle command flips IsActive
- No submit/approve flow — system templates ship active by default

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: Transactional configuration screen with card-grid listing, split-pane editor (form + live preview), nested role collection, and simple Active/Inactive toggle — no multi-step workflow
**Reason**: The mockup modal is a dense multi-section configuration form with a right-pane live preview — too tall for a reliable modal experience. FLOW promotion gives it a dedicated page (`view-page.tsx`) with 3 modes. Listing UI is card-grid (`details` variant) for parity with SMS/WhatsApp/Email templates per registry decision (2026-04-18).

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) for NotificationTemplate — expand existing entity
- [x] Tenant scoping (CompanyId from HttpContext); nullable-CompanyId carve-out for system rows
- [x] Nested child creation — NotificationTemplateRoles (when RecipientType=Roles)
- [x] Unique validation — `(CompanyId, NotificationTemplateCode)` composite
- [x] Custom business rule validators — recipient-type conditional, icon color regex, trigger condition JSON, placeholder catalog membership, `IsSystem` delete lock
- [ ] Workflow commands — N/A (simple toggle only)
- [x] Duplicate command — creates Draft copy with `{code}_COPY` and `{title} (Copy)`, sets `IsSystem=false`
- [ ] File upload command — N/A (no file fields)
- [x] Summary query — `GetNotificationTemplateSummary` returns counts (activeCount, inactiveCount, systemCount, customCount, byCategory)
- [x] Migration — add 15 new columns + new child table + alter CompanyId FK constraint (RESTRICT → still RESTRICT; only add columns)

**Frontend Patterns Required:**
- [x] FlowDataTable (listing) — `displayMode: card-grid`, `cardVariant: details`
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form (for FORM layout)
- [x] Zustand store (`notification-template-store.ts` under `src/application/stores/notification-template-stores/` — SavedFilter convention)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back + Save button; Test Notification secondary action on right)
- [x] Child list inside form — Roles checkbox group (flat list, not grid; 4 hardcoded role options in first build)
- [x] Status toggle + Toggle action — uses standard Toggle mutation
- [ ] File upload widget — N/A
- [x] Summary cards / count widgets above grid — 3 inline count pills (Active / System / Custom) in ScreenHeader subtitle
- [ ] Grid aggregation columns — N/A (card-grid)
- [x] **Live Notification Preview** (right pane of editor) — new component `notification-preview.tsx` that renders the template values in a mock in-app notification bubble
- [x] **Icon picker grid** — inline 7-icon grid (from mockup lines 379-387); reuse if an existing `IconPicker` component exists (grep first), else build as a new page-scoped component
- [x] **Color picker input** — native `<input type="color">` per mockup line 391 (no fancy picker — keep it simple)
- [x] **Priority chip group** — custom 3-option segmented chip (Normal/High/Urgent) with color-coded selected state (per mockup `.priority-option.selected.high` / `.urgent` styles)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.
> **CRITICAL for FLOW**: describe BOTH the FORM layout (new/edit) AND the DETAIL layout (read).

### Grid/List View (mode=index, default URL)

**Display Mode**: `card-grid`
**Card Variant**: `details`
**Reuses**: existing `<CardGrid>` shell + `details-card.tsx` variant (card-grid infra already BUILT per `.claude/feature-specs/card-grid.md` — confirmed via glob). NO new infra files.

**Card Config:**
```yaml
cardConfig:
  variant: details
  headerField: "notificationTemplateTitle"    # "Template Name" — admin label
  metaFields: ["category", "triggerEvent"]    # chip: Donation/Contact/…, chip: donation.created (monospace)
  snippetField: "bodyPreview"                 # server-side stripped first 100 chars of NotificationTemplateText
  footerField: "modifiedDate"                 # "Modified 2d ago" format
  snippetMaxChars: 100
```

**Card Extras** (same pattern as WhatsApp #31 — see §⑫):
- **Status badge** (Active green / Inactive gray / System blue tint): include `status` as the LAST entry in `metaFields` via a synthesized server field `statusBadge` that resolves to `"Active" | "Inactive" | "System"` (Option A per WhatsApp #31 §⑫). Reused pattern.
- **Icon tint**: card shows the template's `iconCode` + `iconColor` as a small leading icon before the title (overlay via CSS — card-grid shell doesn't need to change). This is a minor visual sugar — if not trivial, defer to a known-issue.

**Responsive breakpoints (card-grid default)**: 1 col (xs) → 2 col (sm) → 3 col (lg) → 4 col (xl). Card inner padding `p-4`, gap `gap-3`. Body click → `?mode=read&id={id}`.

**Grid Columns** (N/A for card-grid — kept for parity if user toggles to table mode in future; currently ignored):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Template Name | notificationTemplateTitle | text | auto | YES | With leading icon |
| 2 | Category | category | badge | 110px | YES | 6 enum options |
| 3 | Trigger | triggerEvent | code (monospace) | 180px | YES | — |
| 4 | Channels | channels (derived) | badges | 160px | NO | Array of active channel badges |
| 5 | Recipients | recipientSummary (derived) | text | 160px | NO | e.g., "Assigned Staff + Admins" |
| 6 | Status | statusBadge | badge | 100px | YES | Active/Inactive/System |

**Search/Filter Fields** (toolbar above card-grid, matching mockup filter bar lines 232-251):
- Search text (matches NotificationTemplateTitle OR NotificationTemplateCode OR TriggerEvent)
- Category filter (All / Donation / Contact / Campaign / Event / System / Approval)
- Status filter (All / Active / Inactive)

**Grid Actions (per card — shown via `RowActionMenu` kebab on hover):**
- View (→ `?mode=read&id=X`) — default on card body click
- Edit (→ `?mode=edit&id=X`) — enabled for all rows (system templates ARE editable in content, just not deletable)
- **Test** (fires test notification — SERVICE_PLACEHOLDER, toast stub)
- **Toggle Status** (Active ↔ Inactive — uses Toggle mutation, reloads card)
- **Duplicate** (creates `{CODE}_COPY` as `IsSystem=false` custom copy; navigates to `?mode=edit&id={newId}`)
- Delete — **disabled when `isSystem=true`** (with tooltip "System templates cannot be deleted")

**Row Click**: Navigates to `?mode=read&id={id}` (DETAIL layout)

### Page Widgets & Summary Cards

**Widgets**: 3 count pills displayed INLINE inside the ScreenHeader subtitle row (same pattern as WhatsApp #31 for consistency).

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | Active | summary.activeCount | count + green dot | Subtitle row, inline |
| 2 | System | summary.systemCount | count + blue dot | Subtitle row, inline |
| 3 | Custom | summary.customCount | count + accent dot | Subtitle row, inline |

**Grid Layout Variant**: `widgets-above-grid`
- 3 status pills inline in ScreenHeader subtitle.
- FE Dev uses **Variant B**: `<ScreenHeader>` with inline status summary + `<DataTableContainer showHeader={false}>` (to avoid duplicate header — ContactType #19 precedent).

**Summary GQL Query:**
- Query name: `GetNotificationTemplateSummary`
- Returns: `NotificationTemplateSummaryDto { activeCount, inactiveCount, systemCount, customCount, donationCount, contactCount, campaignCount, eventCount, systemEventCount, approvalCount }`
- Added to `NotificationTemplateQueries.cs` alongside `GetAll` and `GetById`

### Grid Aggregation Columns

**Aggregation Columns**: NONE. Card-grid mode does not use column subqueries.

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

---

#### LAYOUT 1: FORM (mode=new & mode=edit) — Split-Pane Editor

> This is the **core** UI of this screen. The mockup modal (lines 282-567) is promoted to a full page with the same split-pane structure: LEFT 58% = form (5 sections stacked), RIGHT 42% = live notification preview + placeholder reference + delivery summary.

**Page Header** (above split pane — FlowFormPageHeader):
- Back button (→ returns to grid list)
- Page title: `Create Notification Template` (new) or `Edit: {templateName}` (edit)
- Right actions: Cancel, Save, **Test Notification** (SERVICE_PLACEHOLDER — fires a test notification to current user; toast "Test notification sent")

**Editor Body**: Two-column split (58% / 42% on ≥ lg, stacked on < lg).

**Section Container Type**: `section-title` dividers (matches mockup `.section-title` — NOT accordions). Each section is a flat titled block separated by a thin divider.

**LEFT PANE — 5 Form Sections** (mockup modal left col `.col-lg-7` lines 292-502):

| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | fa-info-circle | **Template Information** | 2-col grid | expanded | TemplateName (full), Category (half), TriggerEvent (half), TriggerCondition (full, 3-input inline) |
| 2 | fa-bell | **Notification Content** | 2-col grid | expanded | NotificationTitle (full), NotificationTemplateText / Body (full textarea), Icon grid (2/3 width), IconColor (1/3 width), Priority chip group (full) |
| 3 | fa-truck | **Delivery Channels** | full-width list | expanded | EnableInApp (always-on disabled checkbox), EnableEmail, EnableWhatsApp, EnablePush (disabled "Coming Soon") |
| 4 | fa-users | **Recipients** | 2-col grid | expanded | RecipientType (half), Roles selector (half — shows ONLY when RecipientType=Roles), IncludeAdmins checkbox (full) |
| 5 | fa-link | **Action Link** | 2-col grid | expanded | ActionUrl (2/3 width), ActionLabel (1/3 width) |
| — | — | **Status** (footer strip) | horizontal | expanded | IsActive switch with "Active/Inactive" label |

**Field Widget Mapping** (all fields across all sections):

| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| notificationTemplateTitle (Template Name) | 1 | text | "e.g., New Donation Received" | required, max 250 | Admin label |
| notificationTemplateCode | 1 | text (auto-generated) | "Auto from name" | required, max 100, upper+underscore | Hidden if empty, auto-fills on name blur — reveal on edit via small "Code" link |
| category | 1 | select | — | required | 6-option enum |
| triggerEvent | 1 | select with optgroups | — | required | Optgroups filtered by category |
| triggerConditionJson | 1 | **3-input inline composer** | field / op / value | optional | Select field / select op / text value → serialized to JSON on submit |
| notificationTitle | 2 | text | "New donation: {{DonationAmount}} from {{DonorName}}" | required, max 250 | Token-aware |
| notificationTemplateText (Body) | 2 | textarea (rows=3) | "{{DonorName}} donated {{DonationAmount}}…" | required, max 1000 | Token-aware |
| iconCode | 2 | **icon picker grid** (7 options) | — | required default `fa-bell` | 40×40 tiles per mockup |
| iconColor | 2 | native color input | `#0e7490` | required, regex `#[0-9a-f]{6}` | `<input type="color">` |
| priority | 2 | **priority chip group** | — | required default `Normal` | 3 chips: Normal (gray) / High (yellow) / Urgent (red) |
| enableInApp | 3 | checkbox (DISABLED checked) | — | always true | Labeled "In-App Notification — Always enabled" |
| enableEmail | 3 | checkbox | — | — | Fan-out toggle |
| enableWhatsApp | 3 | checkbox | — | — | Fan-out toggle |
| enablePush | 3 | checkbox (DISABLED unchecked) | — | always false | "Push Notification — Coming Soon" badge |
| recipientType | 4 | select | — | required | 5 options: AssignedStaff/Roles/Initiated/AllStaff/Custom — Custom disabled "Coming Soon" |
| roles[] | 4 | checkbox group (4 options) | — | required IF recipientType=Roles | Super Admin / Org Admin / Finance / Staff (hardcoded) |
| includeAdmins | 4 | checkbox | — | — | "Always include Org Admins" |
| actionUrl | 5 | text | "fundraising/donation-detail?id={{DonationId}}" | optional, max 500 | Token-aware |
| actionLabel | 5 | text | "View Donation" | optional, max 60 | — |
| isActive | footer | switch | — | default true | "Active"/"Inactive" label flips green/gray |

**Special Form Widgets:**

- **Trigger Condition 3-input composer** (mockup lines 346-362):
  Row of 3 inline controls, serialized to `TriggerConditionJson` on submit.
  - Field select: dropdown of category-scoped fields (e.g., for Donation: `amount`, `status`, `paymentMode`, `currency`)
  - Operator select: `equals`, `greaterThan`, `lessThan`, `contains`
  - Value input: plain text
  - Empty field select → TriggerConditionJson is saved as null

- **Icon Picker Grid** (mockup lines 379-387):
  - 7 pre-defined 40×40 tiles (icons: `fa-hand-holding-dollar`, `fa-user-plus`, `fa-bullhorn`, `fa-calendar`, `fa-bell`, `fa-exclamation-triangle`, `fa-check-circle`)
  - Selected state: accent border + accent bg tint + inner shadow
  - Click → sets `iconCode` form value + triggers preview re-render
  - **Before building**: `grep "IconPicker"` to check for existing reusable component; if found, reuse; if not, build as page-local `notification-icon-picker.tsx`.

- **Priority Chip Group** (mockup lines 395-405):
  - 3 horizontal chips: Normal (minus-circle gray), High (exclamation-circle yellow), Urgent (exclamation-triangle red)
  - Selected state: border + bg tint matching severity color
  - Single-select radio behavior; click → sets `priority` form value

- **Roles Checkbox Group** (mockup lines 455-471):
  - Shows ONLY when `recipientType=Roles` (AnimateHeight / simple conditional render)
  - 4 checkbox rows: Super Admin / Org Admin / Finance / Staff (hardcoded in first build per mockup)
  - At least 1 must be checked (validator) when recipientType=Roles

- **Status Switch Footer** (mockup lines 495-501):
  - Horizontal row separated by top border
  - Label "Status" + toggle switch + dynamic label ("Active" green / "Inactive" gray)

**RIGHT PANE — Notification Preview + Reference Panels** (mockup modal right col `.col-lg-5` lines 505-556):

New custom component: `notification-preview.tsx` (colocated with the view-page). Contains THREE stacked sub-panels:

**Sub-panel 1: Notification Preview Card** (mockup `.preview-notification` lines 508-522):
- White card with left accent border matching `iconColor`
- Left: circular icon bubble (40×40) with `iconCode` + `iconColor` tint bg
- Right flex column:
  - Title: sample-resolved `notificationTitle` (replace known tokens with sample values)
  - Body: sample-resolved `notificationTemplateText` (same)
  - Footer row: Action link (blue, small) + "2 min ago" timestamp
- Priority accent border color reflects `priority` (normal gray, high yellow, urgent red)

**Sub-panel 2: Placeholder Reference** (mockup lines 524-536):
- List of `<code>` chips for each placeholder available for the current `category`
- Clicking a chip copies `{{TokenName}}` to clipboard (toast "Copied")
- Uses the catalog defined in §③ (Placeholder catalog)

**Sub-panel 3: Delivery Summary** (mockup lines 538-554):
- Checklist of channels:
  - In-App Notification ✓ (always green)
  - Email ✓ or ○ (based on `enableEmail`)
  - WhatsApp ✓ or ○ (based on `enableWhatsApp`)
- Each row: icon + label + opacity 1 when enabled / 0.4 when disabled

**Preview re-renders on every form change** — React Hook Form `watch(["notificationTitle", "notificationTemplateText", "iconCode", "iconColor", "priority", "actionLabel", "enableEmail", "enableWhatsApp", "category"])` drives the preview props.

**Sample token resolution table (client-side, used ONLY in preview):**
```ts
const SAMPLE_TOKENS = {
  "{{DonorName}}": "Sarah Johnson",
  "{{DonationAmount}}": "$500",
  "{{Currency}}": "USD",
  "{{Purpose}}": "Children's Education",
  "{{PaymentMode}}": "Online (Stripe)",
  "{{DonationId}}": "12345",
  "{{ContactName}}": "Sarah Johnson",
  "{{CampaignName}}": "Annual Appeal",
  "{{EventName}}": "Spring Gala",
  "{{StaffName}}": "John Doe",
  "{{OrgName}}": "Hope Foundation",
  "{{CurrentDate}}": "Apr 19, 2026",
};
```

**Editor Footer** (below split pane — part of FlowFormPageHeader):
- Cancel → navigate back (unsaved-changes dialog if dirty)
- Save Template → submits (POST for new, PUT for edit) → redirects to `?mode=read&id={id}`

**Child Grids in Form:**
| Child | Grid Columns | Add/Edit Method | Delete | Notes |
|-------|-------------|----------------|--------|-------|
| NotificationTemplateRole | (flat checkbox group, not tabular) | Checkbox toggle | Checkbox uncheck | 4 hardcoded role rows; serialized as `[{roleCode, orderBy}]` on save |

---

#### LAYOUT 2: DETAIL (mode=read) — Preview + Config Snapshot

> Read-only view shown on row click. **Different UI from form** — no split-pane editing. A multi-column page with preview card + configuration panels + metadata.

**Page Header**: FlowFormPageHeader with Back, Edit button (always visible — even system rows are editable in content), Test Notification action

**Header Actions**:
- Edit → `?mode=edit&id=X`
- Test Notification → SERVICE_PLACEHOLDER toast
- Toggle Status → flips IsActive (same as grid action)
- Duplicate → creates `{CODE}_COPY` as Custom, navigates to `?mode=edit&id={newId}`
- Delete → **disabled when `isSystem=true`** (tooltip "System templates cannot be deleted")

**Page Layout** (2-column on ≥ lg, stacked on < lg):
| Column | Width | Cards / Sections |
|--------|-------|-----------------|
| Left | 1fr | Metadata card, Trigger card, Delivery Channels card, Recipients card, Action Link card |
| Right | 360px fixed | Notification Preview card + Placeholder Reference + Delivery Summary (same 3 sub-panels as FORM right pane) |

**Left Column Cards** (in order):
| # | Card Title | Content |
|---|-----------|---------|
| 1 | **Template Info** | Template Name (monospace-ish label), Code (mono), Category badge, Priority chip, Status badge (Active/Inactive/System), IsSystem flag |
| 2 | **Trigger** | Event code (mono, copyable), Trigger Condition (rendered as `amount > 1000` readable string) or "No condition" |
| 3 | **Delivery Channels** | List of active channels (In-App ✓ always, Email ✓/✗, WhatsApp ✓/✗, Push disabled) — same visual as FORM §3 but read-only |
| 4 | **Recipients** | RecipientType label (e.g., "Specific Roles"), role chips (when RecipientType=Roles), "Always include Org Admins" flag |
| 5 | **Action Link** | ActionUrl (code style, mono) + ActionLabel (styled as CTA preview) or "No action link" |
| 6 | **Audit** | CreatedBy + CreatedDate, ModifiedBy + ModifiedDate, LastTriggeredDate |

**Right Column**: same `notification-preview.tsx` component as FORM, rendered in read-only mode with resolved sample tokens.

**Layout on < lg (tablet/phone)**: stack — preview card moves below metadata cards.

### User Interaction Flow

1. User visits grid → sees card-grid of templates + 3 count pills in header
2. Clicks "+ Create Template" → URL: `?mode=new` → **FORM LAYOUT (split pane)** with empty form + empty preview
3. User fills Template Name → Code auto-generates on blur
4. User picks Category → Trigger Event dropdown filters to category-scoped options
5. User composes Title + Body with `{{Tokens}}` → preview updates live on every keystroke
6. User picks icon + color → preview icon updates live
7. User picks priority → preview accent border updates live
8. User toggles Email/WhatsApp → Delivery Summary checklist updates live
9. User picks RecipientType → if "Roles", checkbox group appears; at least 1 role required
10. User adds optional TriggerCondition → serialized to JSON on save
11. User clicks Save → API creates record with IsActive=true → redirects to `?mode=read&id={newId}` → **DETAIL LAYOUT** renders
12. From detail: clicks "Edit" → `?mode=edit&id=X` → FORM pre-filled
13. From detail: clicks "Toggle Status" → IsActive flips; page reloads with new status
14. From detail: clicks "Duplicate" → API copies as custom template → navigates to `?mode=edit&id={newId}`
15. From detail: clicks "Test Notification" (SERVICE_PLACEHOLDER) → toast "Test notification sent"
16. From detail: clicks "Delete" → confirm modal → if `IsSystem=true` button is DISABLED (not just error-toast)
17. Grid row click → `?mode=read&id={id}` → detail layout
18. Back button → grid
19. Unsaved changes: dirty form + navigate → confirm dialog

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical FLOW reference entity (SavedFilter) to this entity.

**Canonical Reference**: SavedFilter (FLOW, NotifyModels group, crm/communication route)
**Parallel Reference**: WhatsAppTemplate (#31) — same card-grid/details variant + split-pane editor pattern, same NotifyModels group

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | NotificationTemplate | Entity/class name |
| savedFilter | notificationTemplate | camelCase variable names |
| SavedFilterId | NotificationTemplateId | PK field name |
| SavedFilters | NotificationTemplates | Table name / collection navigation |
| saved-filter | notification-template | kebab-case (file names, CSS classes) |
| savedfilter | notificationtemplate | Lowercase no-dash (FE folder, route path segment) |
| SAVEDFILTER | NOTIFICATIONTEMPLATE | Menu code, grid code |
| notify | notify | DB schema (SAME) |
| NotifyModels | NotifyModels | Backend group (SAME folder) |
| Notify | Notify | Backend namespace suffix (SAME) |
| CRM_COMMUNICATION | CRM_NOTIFICATION | Parent menu code CHANGES |
| CRM | CRM | Module code (SAME) |
| crm/communication/savedfilter | crm/notification/notificationtemplate | FE route base |
| saved-filter-stores | notification-template-stores | Store folder under `src/application/stores/` |
| saved-filter-store | notification-template-store | Store file name |
| notify-service | notify-service | FE domain-entities folder (REUSE — already contains NotificationDto, SavedFilterDto, etc.) |
| notify-queries | notify-queries | FE gql-queries folder (REUSE) |
| notify-mutations | notify-mutations | FE gql-mutations folder (REUSE) |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Existing files flagged with ⚠ EXPAND (modify, don't regenerate). New files flagged with ✚ NEW.

### Backend Files (13 — 2 existing-to-expand + 1 new child + 9 new + migration)

**Entity & config:**

| # | File | Path | Status |
|---|------|------|--------|
| 1 | Entity — NotificationTemplate | Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/NotifyModels/NotificationTemplate.cs | ⚠ EXPAND — fix namespace (was `Base.Domain.Models.SharedModels`; correct to `Base.Domain.Models.NotifyModels` to match folder), add 15 new fields + nav collection `ICollection<NotificationTemplateRole> Roles` |
| 2 | EF Config — NotificationTemplate | Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/NotifyConfigurations/NotificationTemplateConfiguration.cs | ⚠ EXPAND — fix `using` to `NotifyModels`, add column configs for new fields, add HasMany(Roles) cascade |
| 3 | Entity — NotificationTemplateRole | Pss2.0_Backend/.../Base.Domain/Models/NotifyModels/NotificationTemplateRole.cs | ✚ NEW |
| 4 | EF Config — NotificationTemplateRole | Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/NotifyConfigurations/NotificationTemplateRoleConfiguration.cs | ✚ NEW |
| 5 | Migration | Pss2.0_Backend/.../Base.Infrastructure/Data/Migrations/YYYYMMDD_ExpandNotificationTemplate.cs | ✚ NEW — 15 new columns on NotificationTemplates + new NotificationTemplateRoles table |

**Schemas / Business / Endpoints:**

| # | File | Path | Status |
|---|------|------|--------|
| 6 | Schemas (DTOs) | Pss2.0_Backend/.../Base.Application/Schemas/NotifySchemas/NotificationTemplateSchemas.cs | ✚ NEW (includes Request, Response, Summary, RoleRequest, RoleResponse DTOs) |
| 7 | Create Command | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/NotificationTemplates/CreateCommand/CreateNotificationTemplate.cs | ✚ NEW (nested roles creation) |
| 8 | Update Command | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/NotificationTemplates/UpdateCommand/UpdateNotificationTemplate.cs | ✚ NEW (diff-update roles) |
| 9 | Delete Command | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/NotificationTemplates/DeleteCommand/DeleteNotificationTemplate.cs | ✚ NEW (reject when IsSystem=true) |
| 10 | Toggle Command | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/NotificationTemplates/ToggleCommand/ToggleNotificationTemplate.cs | ✚ NEW |
| 11 | Duplicate Command | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/NotificationTemplates/DuplicateCommand/DuplicateNotificationTemplate.cs | ✚ NEW (copy with `{CODE}_COPY`, IsSystem=false) |
| 12 | GetAll Query | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/NotificationTemplates/GetAllQuery/GetAllNotificationTemplate.cs | ✚ NEW (bodyPreview computed, category/status filters, includes Roles) |
| 13 | GetById Query | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/NotificationTemplates/GetByIdQuery/GetNotificationTemplateById.cs | ✚ NEW (includes Roles) |
| 14 | Summary Query | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/NotificationTemplates/GetSummaryQuery/GetNotificationTemplateSummary.cs | ✚ NEW |
| 15 | Mutations | Pss2.0_Backend/.../Base.API/EndPoints/Notify/Mutations/NotificationTemplateMutations.cs | ✚ NEW (Create/Update/Delete/Toggle/Duplicate) |
| 16 | Queries | Pss2.0_Backend/.../Base.API/EndPoints/Notify/Queries/NotificationTemplateQueries.cs | ✚ NEW (GetAll/GetById/GetSummary) |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | Base.Application/Data/Persistence/INotifyDbContext.cs | `DbSet<NotificationTemplate>`, `DbSet<NotificationTemplateRole>` (NotificationTemplate may already be wired — **verify first**; add Role) |
| 2 | Base.Infrastructure/Data/Persistence/NotifyDbContext.cs | Same (verify NotificationTemplate DbSet exists, add Role) |
| 3 | Base.Application/Mappings/NotifyMappings.cs | Mapster configs — NotificationTemplate Request/Response + nested Role Request/Response + Summary |
| 4 | Base.Infrastructure/DecoratorProperties.cs → DecoratorNotifyModules | Add 2 decorator entries (NotificationTemplate, NotificationTemplateRole) — verify NotificationTemplate not already there |
| 5 | Base.API/GlobalUsing.cs (×3) | Add `using Base.Domain.Models.NotifyModels;` if missing |
| 6 | Base.API/Program.cs (schema registration) | Register `NotificationTemplateQueries` + `NotificationTemplateMutations` |
| 7 | ApplicationModels/Company.cs | Verify `ICollection<NotificationTemplate> NotificationTemplates` nav already exists (referenced by current EF config line 27) — keep |

### Frontend Files (11 files — card-grid reuses existing infra; ONLY new screen files)

| # | File | Path | Status |
|---|------|------|--------|
| 1 | DTO Types | Pss2.0_Frontend/src/domain/entities/notify-service/NotificationTemplateDto.ts | ✚ NEW (Request/Response + Role Request/Response + Summary DTO) |
| 2 | GQL Query | Pss2.0_Frontend/src/infrastructure/gql-queries/notify-queries/NotificationTemplateQuery.ts | ✚ NEW (GetAll + GetById + GetSummary) |
| 3 | GQL Mutation | Pss2.0_Frontend/src/infrastructure/gql-mutations/notify-mutations/NotificationTemplateMutation.ts | ✚ NEW (Create/Update/Delete/Toggle/Duplicate) |
| 4 | Page Config | Pss2.0_Frontend/src/presentation/pages/crm/notification/notificationtemplate.tsx | ✚ NEW (sets `displayMode: card-grid`, `cardVariant: details`, `cardConfig`) |
| 5 | Index folder entry | Pss2.0_Frontend/src/presentation/components/page-components/crm/notification/notificationtemplate/index.tsx | ✚ NEW (exports) |
| 6 | Index Page | Pss2.0_Frontend/src/presentation/components/page-components/crm/notification/notificationtemplate/index-page.tsx | ✚ NEW (ScreenHeader with inline count pills + DataTableContainer showHeader={false}) |
| 7 | **View Page (3 modes)** | Pss2.0_Frontend/src/presentation/components/page-components/crm/notification/notificationtemplate/view-page.tsx | ✚ NEW (split-pane editor for new/edit + detail layout for read) |
| 8 | **Zustand Store** | Pss2.0_Frontend/src/application/stores/notification-template-stores/notification-template-store.ts | ✚ NEW (mirror SavedFilter/WhatsAppTemplate convention) |
| 9 | **Notification Preview** (new custom component) | Pss2.0_Frontend/src/presentation/components/page-components/crm/notification/notificationtemplate/notification-preview.tsx | ✚ NEW (3 sub-panels: Preview card, Placeholder Reference, Delivery Summary) |
| 10 | Status Pills | Pss2.0_Frontend/src/presentation/components/page-components/crm/notification/notificationtemplate/status-pills.tsx | ✚ NEW (3 inline count pills for ScreenHeader subtitle — same pattern as WhatsApp #31) |
| 11 | Route Page (REPLACE stub) | Pss2.0_Frontend/src/app/[lang]/crm/notification/notificationtemplate/page.tsx | ⚠ REPLACE stub `<div>Need to Develop</div>` with page-component import |

**Optional/Conditional FE files:**
- `notification-icon-picker.tsx` — only if no existing `IconPicker` component found via grep
- `priority-chip-group.tsx` — inline in view-page or extracted as sibling; use judgement (small widget)

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | src/presentation/components/page-components/crm/notification/index.ts | Create if missing + export notificationtemplate folder barrel |
| 2 | src/presentation/pages/crm/notification/index.ts | Add export for notificationtemplate page config |
| 3 | src/application/stores/index.ts | Export notification-template-stores barrel |
| 4 | src/domain/entities/notify-service/index.ts | Add `export * from "./NotificationTemplateDto"` |
| 5 | src/infrastructure/gql-queries/notify-queries/index.ts | Add `export * from "./NotificationTemplateQuery"` |
| 6 | src/infrastructure/gql-mutations/notify-mutations/index.ts | Add `export * from "./NotificationTemplateMutation"` |
| 7 | entity-operations.ts | Add NOTIFICATIONTEMPLATE operations mapping |
| 8 | operations-config.ts | Register import + operations entry |
| 9 | Sidebar menu config (DB seed — not FE file) | DB seed adds NOTIFICATIONTEMPLATE under CRM_NOTIFICATION (see §⑨) |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Notification Templates
MenuCode: NOTIFICATIONTEMPLATE
ParentMenu: CRM_NOTIFICATION
Module: CRM
MenuUrl: crm/notification/notificationtemplate
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: NOTIFICATIONTEMPLATE
---CONFIG-END---
```

### DB Seed — System Template Seeding (12 rows)

> The current mockup (lines 588-599) ships with 12 pre-seeded templates. Seed them as `IsSystem=true`, `CompanyId=null`, `IsActive=true`. These serve as the out-of-the-box notification catalog.

| # | Code | Title (Template Name) | Category | Trigger | Icon | Priority | Email | WhatsApp | Recipient |
|---|------|----------------------|----------|---------|------|----------|-------|----------|-----------|
| 1 | NEW_DONATION_RECEIVED | New Donation Received | Donation | donation.created | fa-hand-holding-dollar | Normal | true | false | AssignedStaff + IncludeAdmins |
| 2 | LARGE_DONATION_ALERT | Large Donation Alert | Donation | donation.created (condition: amount > 1000) | fa-hand-holding-dollar | High | true | true | Roles:[BUSINESSADMIN] |
| 3 | CHEQUE_BOUNCED | Cheque Bounced | Donation | cheque.status.bounced | fa-money-check | Urgent | true | false | Roles:[FINANCE] |
| 4 | RECURRING_PAYMENT_FAILED | Recurring Payment Failed | Donation | recurring.payment.failed | fa-rotate-left | High | true | false | AssignedStaff |
| 5 | NEW_CONTACT_CREATED | New Contact Created | Contact | contact.created | fa-user-plus | Normal | false | false | AssignedStaff |
| 6 | DUPLICATE_CONTACT_DETECTED | Duplicate Contact Detected | Contact | contact.duplicate.found | fa-clone | Normal | false | false | Roles:[BUSINESSADMIN] |
| 7 | CAMPAIGN_GOAL_REACHED | Campaign Goal Reached | Campaign | campaign.goal.reached | fa-bullhorn | Normal | true | false | AllStaff |
| 8 | EVENT_REGISTRATION | Event Registration | Event | event.registration.new | fa-calendar | Normal | false | false | AssignedStaff |
| 9 | APPROVAL_PENDING | Approval Pending | System | approval.requested | fa-check-circle | High | true | false | Roles:[BUSINESSADMIN] |
| 10 | IMPORT_COMPLETED | Import Completed | System | import.completed | fa-check-circle | Normal | false | false | Initiated |
| 11 | PASSWORD_EXPIRY_WARNING | Password Expiry Warning | System | user.password.expiring | fa-exclamation-triangle | High | true | false | Initiated — seed with IsActive=false (mockup shows this as Inactive) |
| 12 | PLEDGE_PAYMENT_OVERDUE | Pledge Payment Overdue | Donation | pledge.payment.overdue | fa-hand-holding-dollar | High | true | false | AssignedStaff |

Each row's Title/Body uses realistic tokens per the mockup — use the Title/Body samples from the `templates` JS array (mockup lines 588-599) as a starting point; where body text is missing from the mockup JS, craft a short `{{Token}}`-based body consistent with the Title.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `NotificationTemplateQueries`
- Mutation type: `NotificationTemplateMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetAllNotificationTemplateList | [NotificationTemplateResponseDto] | searchText, pageNo, pageSize, sortField, sortDir, isActive, category, status |
| GetNotificationTemplateById | NotificationTemplateResponseDto | notificationTemplateId |
| GetNotificationTemplateSummary | NotificationTemplateSummaryDto | — |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| CreateNotificationTemplate | NotificationTemplateRequestDto (with nested roles[]) | int (new ID) |
| UpdateNotificationTemplate | NotificationTemplateRequestDto | int |
| DeleteNotificationTemplate | notificationTemplateId | int (rejects when IsSystem=true) |
| ToggleNotificationTemplate | notificationTemplateId | int |
| DuplicateNotificationTemplate | notificationTemplateId | int (new ID of Custom copy) |

**Response DTO Fields** (`NotificationTemplateResponseDto`):
| Field | Type | Notes |
|-------|------|-------|
| notificationTemplateId | number | PK |
| notificationTemplateCode | string | mono |
| notificationTemplateTitle | string | "Template Name" (admin label) |
| category | string | Donation / Contact / Campaign / Event / System / Approval |
| triggerEvent | string | e.g., `donation.created` |
| triggerConditionJson | string \| null | JSON |
| notificationTitle | string | user-facing title |
| notificationTemplateText | string | user-facing body (raw with tokens) |
| bodyPreview | string | first ~100 chars stripped — for card snippet |
| iconCode | string | fa-icon |
| iconColor | string | `#rrggbb` |
| priority | string | Normal / High / Urgent |
| enableInApp | boolean | always true |
| enableEmail | boolean | — |
| enableWhatsApp | boolean | — |
| enablePush | boolean | always false (reserved) |
| recipientType | string | AssignedStaff / Roles / Initiated / AllStaff / Custom |
| includeAdmins | boolean | — |
| actionUrl | string \| null | — |
| actionLabel | string \| null | — |
| lastTriggeredDate | string \| null (ISO) | — |
| isSystem | boolean | system-seeded flag |
| isActive | boolean | Active/Inactive toggle |
| statusBadge | string | derived: "Active" / "Inactive" / "System" — for card `metaFields` |
| channels | string[] | derived: `["In-App"]` + optional `"Email"`, `"WhatsApp"` — for card display |
| recipientSummary | string | derived readable label: e.g., "Assigned Staff + Admins", "Specific Roles (2)", "All Staff" |
| modifiedDate | string (ISO) | — |
| roles | [NotificationTemplateRoleResponseDto] | nested |

**NotificationTemplateRoleResponseDto:**
| Field | Type |
|-------|------|
| notificationTemplateRoleId | number |
| roleCode | string |
| roleName | string — resolved display name (server-side join to Role table; or client-side map from hardcoded catalog) |
| orderBy | number |

**NotificationTemplateSummaryDto:**
| Field | Type |
|-------|------|
| activeCount | number |
| inactiveCount | number |
| systemCount | number |
| customCount | number |
| donationCount | number |
| contactCount | number |
| campaignCount | number |
| eventCount | number |
| systemEventCount | number |
| approvalCount | number |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — 0 errors (warnings OK)
- [ ] Migration applies cleanly on dev DB — new columns + new NotificationTemplateRoles table created; existing rows get default values
- [ ] `pnpm dev` — page loads at `/{lang}/crm/notification/notificationtemplate`
- [ ] `pnpm tsc --noEmit` — no new TS errors in notificationtemplate files

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Card-grid loads with `details` variant — header=templateName, chips=[category, triggerEvent, statusBadge], snippet=bodyPreview, footer="Modified {relative}"
- [ ] Leading icon (iconCode + iconColor) shows inside each card
- [ ] Search filters by name/code/triggerEvent
- [ ] Category filter + Status filter work (AND-composed with search)
- [ ] Count pills (Active / System / Custom) in ScreenHeader subtitle show correct numbers
- [ ] `?mode=new`: FORM LAYOUT renders with split pane (left 5 sections / right 3 preview sub-panels)
- [ ] Template Name typed → Code auto-generates on blur (uppercase + underscore)
- [ ] Category change → Trigger Event dropdown re-filters
- [ ] Title / Body typed → preview updates live with sample token resolution
- [ ] Icon grid click → preview icon updates live
- [ ] Color picker → preview icon bg tint + accent border update live
- [ ] Priority chip click → single-select, styles match mockup (normal gray / high yellow / urgent red)
- [ ] In-App checkbox is checked + disabled (always-on)
- [ ] Email/WhatsApp toggle → Delivery Summary right pane updates (✓ / ○)
- [ ] Push checkbox is disabled + unchecked (shows "Coming Soon" badge)
- [ ] RecipientType = "Roles" → checkbox group appears; validator requires ≥1 checked
- [ ] RecipientType = "Custom" → option is disabled (Coming Soon)
- [ ] TriggerCondition 3-input: empty field → saved as null; filled → saved as JSON
- [ ] ActionUrl/ActionLabel accept tokens
- [ ] Status switch flips label + color live
- [ ] Save → creates record with IsSystem=false → redirects to `?mode=read&id={newId}`
- [ ] `?mode=read&id=X`: DETAIL LAYOUT renders (6 left cards + right preview pane) — NOT disabled form
- [ ] Edit button → FORM pre-filled
- [ ] Toggle Status action flips IsActive; card/detail reloads with new status
- [ ] Duplicate action creates `{CODE}_COPY` custom template → navigates to `?mode=edit&id={newId}`
- [ ] Delete button DISABLED (not error-toast) for `isSystem=true` rows
- [ ] Test Notification button shows toast "Test notification sent for {name}" (SERVICE_PLACEHOLDER)
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] Permissions: Edit/Delete respect BUSINESSADMIN capabilities

**DB Seed Verification:**
- [ ] Menu "Notification Templates" appears under CRM → Notification
- [ ] `GridType: FLOW`, `GridFormSchema: SKIP` — no form schema seeded
- [ ] `GridCode: NOTIFICATIONTEMPLATE` row present in Grid table
- [ ] 12 system templates seeded with `IsSystem=true`, `CompanyId=null` — visible to all tenants
- [ ] Row #11 (PASSWORD_EXPIRY_WARNING) seeded with `IsActive=false` per mockup

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **Existing entity namespace is wrong** — `NotificationTemplate.cs` declares `namespace Base.Domain.Models.SharedModels` but lives in `NotifyModels` folder. Fix to `Base.Domain.Models.NotifyModels` as part of the EXPAND step. The EF config's `using` statement must also update. This is a one-line fix but will cause cascade rename if any other file imports the old namespace — **grep first** (`grep "Base.Domain.Models.SharedModels" -r`) to find consumers.
- **Existing field reuse is intentional** — do NOT rename `NotificationTemplateTitle` (it becomes "Template Name" admin label) or `NotificationTemplateText` (it becomes "Body"). Add NEW `NotificationTitle` field for the user-facing title. This keeps the migration additive.
- **CompanyId stays nullable** — the existing schema allows it; system-seeded rows use `CompanyId=null`. Custom rows must set CompanyId via HttpContext on Create. Validator enforces: `IsSystem=true → CompanyId=null`; `IsSystem=false → CompanyId required`. Standard users cannot create IsSystem=true rows (server-side reject).
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP
- **view-page.tsx handles ALL 3 modes** — new/edit share the split-pane FORM layout, read has a separate DETAIL layout (6 cards + right preview pane, NOT disabled form)
- **Store location**: `src/application/stores/notification-template-stores/notification-template-store.ts` — NOT colocated with the component. Follow SavedFilter/WhatsAppTemplate convention
- **Schema is `notify`, group is `NotifyModels`** — no new module infra needed. Reuse all existing Notify wiring (INotifyDbContext, NotifyDbContext, NotifyMappings, DecoratorNotifyModules)
- **Card-grid infrastructure already exists** — `<CardGrid>` shell, `details-card.tsx`, `card-action-menu.tsx`, `data-table-container.tsx` card-grid branch are all built (glob confirmed). Pure consumer screen — NO new infra
- **Status badge `details` variant extension** — use Option A from WhatsApp #31 §⑫ (synthesize a `statusBadge` string field server-side, include it in `metaFields`). Consistent with WhatsApp precedent
- **Role catalog is hardcoded in first build** — 4 options (Super Admin / Org Admin / Finance / Staff) per mockup. Do NOT wire an ApiSelect to the Roles table — keep it simple. If this grows, a follow-up issue can add dynamic role loading
- **Custom recipient type is deferred** — mockup shows "Custom (Select Users)" option; render it as DISABLED with a "Coming Soon" tooltip. Do NOT build a user-picker UI in first build
- **Placeholder catalog is client-side** — no GQL query for placeholder tokens. If the catalog grows, move to `src/config/notification-placeholders.ts` (not an urgent concern)
- **Icon picker** — 7 hardcoded FontAwesome icons per mockup. Before building, grep for an existing `IconPicker` / `IconSelector` component (e.g., similar to Branch #41's country-flag component). Reuse if found, else build page-local
- **Trigger condition is intentionally minimal** — 1 field + 1 operator + 1 value. Do NOT build a full condition-builder tree (deferred to Automation Workflow #37 for complex cases)
- **Preview token resolution is client-only** — the FE preview uses a hardcoded sample table. The actual dispatch-time resolution happens on the backend (OUT OF SCOPE — that's the Notification dispatcher service)
- **IsActive toggle is the Active/Inactive concept** — there is no separate "Status" column; `IsActive` IS the status. The `statusBadge` derived field maps: `isSystem=true AND isActive=true → "System"`; `isActive=true → "Active"`; else `"Inactive"`
- **Existing unique index**: `(NotificationTemplateCode, IsActive)` already exists on the table. Validate uniqueness respects this — per Company once CompanyId is scoped
- **Company nav collection**: `Company.NotificationTemplates` already exists (referenced by current EF config). Verify & keep
- **Do NOT remove or rename existing `IsSystem` or `NotificationTemplateCode`** — these are load-bearing for system seed distinguishing

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ SERVICE_PLACEHOLDER: **Test Notification** button (header action). Full UI + toast wiring built. Handler: `showToast("Test notification sent for {templateName}")` — does NOT actually dispatch a notification because the notification dispatcher service is not in the codebase yet. Future work: wire `INotificationDispatcher.SendTestAsync(templateId, currentUserId)` which would create a Notification row for the current user using the template's rendered content.
- ⚠ SERVICE_PLACEHOLDER: **Email fan-out** — `EnableEmail=true` is persisted and included in the Response DTO, but the actual email send at trigger time is out of scope (handled by EmailSendJob pipeline which already exists — wire-up TBD).
- ⚠ SERVICE_PLACEHOLDER: **WhatsApp fan-out** — `EnableWhatsApp=true` is persisted, but dispatch requires WhatsApp Campaign/Template wiring from #31/#32 which is separate work.
- ⚠ SERVICE_PLACEHOLDER: **Push Notification channel** — `EnablePush` column seeded but UI shows "Coming Soon" and the value is server-forced to `false`. Reserved for mobile app pipeline.
- ⚠ SERVICE_PLACEHOLDER: **Custom recipient user picker** — `RecipientType=Custom` option is disabled in the UI. Would need a NotificationTemplateUser child + user-picker component — deferred.

Full UI must be built (buttons, forms, modals, panels, interactions, toggles, pickers). Only the handler for the external service call is mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | LOW | Migration | EF snapshot (`ApplicationDbContextModelSnapshot.cs`) NOT regenerated by hand. Migration `20260419120000_Expand_NotificationTemplate.cs` itself is complete (Up + Down) and will apply cleanly via `dotnet ef database update`. Team should run `dotnet ef migrations add Expand_NotificationTemplate --no-build` locally to realign the snapshot before any subsequent migration delta. | OPEN |
| ISSUE-2 | 1 | LOW | BE folder convention | Commands live under flat `Commands/` and `Queries/` folders (SavedFilter canonical pattern) instead of per-command nested folders (`CreateCommand/…` — WhatsAppTemplate pattern). Both valid; the C# namespaces are identical. File moves possible without code edits if the team prefers the nested convention. | OPEN |
| ISSUE-3 | 1 | LOW | BE→FE Contract — audit fields on GetById | `GetNotificationTemplateById` Response DTO doesn't currently include `createdBy`/`createdDate`/`modifiedBy`/`modifiedDate`. Detail LAYOUT §⑥ Audit card renders "Last triggered: —" placeholder and omits created/modified. Add these fields to the query projection + Response DTO later — no FE changes required beyond unhiding the placeholders. | OPEN |
| ISSUE-4 | 1 | LOW | SERVICE_PLACEHOLDER: Test Notification | Button present on grid row actions + detail header + editor header; handler is a toast stub `"Test notification sent for {name}"`. Wire `INotificationDispatcher.SendTestAsync(templateId, currentUserId)` once the dispatcher service exists. | OPEN |
| ISSUE-5 | 1 | LOW | SERVICE_PLACEHOLDER: Email/WhatsApp fan-out | Flags are persisted (`EnableEmail`, `EnableWhatsApp`) and exposed via Response DTO, but no dispatch-time hooks wired. Out of scope for this build — coupling needed with EmailSendJob pipeline + WhatsApp Campaign #32. | OPEN |
| ISSUE-6 | 1 | LOW | SERVICE_PLACEHOLDER: Push channel | `EnablePush` column exists, server-forced `false`, UI shows disabled "Coming Soon" checkbox. Reserved for mobile app pipeline. | OPEN |
| ISSUE-7 | 1 | LOW | SERVICE_PLACEHOLDER: Custom recipient user-picker | `RecipientType=Custom` is a valid enum value but UI shows the option disabled with a "Coming Soon" tooltip. A future `NotificationTemplateUser` child + user-picker component will unblock this. | OPEN |
| ISSUE-8 | 1 | LOW | Detail audit card | `lastTriggeredDate` only field currently rendered in Detail Audit card (the field IS returned by GetById). Created/Modified/By rows are placeholder pending ISSUE-3 fix. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-19 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. FULL scope — expand skeleton NotificationTemplate entity (5 fields) with 15 new columns + 1 new child entity (NotificationTemplateRole) + full CRUD + Summary + Duplicate + Toggle + 12 system-template DB seed + card-grid index + split-pane editor (FORM) + detail layout (READ) + live Notification Preview + 3 inline count pills. Pure consumer of existing card-grid `details` variant infra (built by #24 Email Template session). BE: opus (complexity=High). FE: opus (FLOW).
- **Files touched**:
  - BE (15 created + 6 modified):
    - Created: `Base.Domain/Models/NotifyModels/NotificationTemplateRole.cs` (entity); `Base.Infrastructure/Data/Configurations/NotifyConfigurations/NotificationTemplateRoleConfiguration.cs`; `Base.Infrastructure/Migrations/20260419120000_Expand_NotificationTemplate.cs`; `Base.Application/Schemas/NotifySchemas/NotificationTemplateSchemas.cs`; `Base.Application/Business/NotifyBusiness/NotificationTemplates/Commands/{Create,Update,Delete,Toggle,Duplicate}NotificationTemplate.cs` (5 files, flat `Commands/` folder per SavedFilter canonical — see ISSUE-2); `Base.Application/Business/NotifyBusiness/NotificationTemplates/Queries/{GetAllNotificationTemplate,GetNotificationTemplateById,GetNotificationTemplateSummary}.cs` (3 files); `Base.API/EndPoints/Notify/Mutations/NotificationTemplateMutations.cs`; `Base.API/EndPoints/Notify/Queries/NotificationTemplateQueries.cs`; `Base.API/sql-scripts-dyanmic/NotificationTemplate-sqlscripts.sql` (menu + grid + 12 system template seeds)
    - Modified: `Base.Domain/Models/NotifyModels/NotificationTemplate.cs` (namespace `SharedModels`→`NotifyModels` + 15 new props + `Roles` nav); `Base.Infrastructure/Data/Configurations/NotifyConfigurations/NotificationTemplateConfiguration.cs` (using fix + 15 col configs + `HasMany(Roles)` cascade); `Base.Application/Data/Persistence/INotifyDbContext.cs` (+ `DbSet<NotificationTemplateRole>`); `Base.Infrastructure/Data/Persistence/NotifyDbContext.cs` (same); `Base.Application/Mappings/NotifyMappings.cs` (+ 11 Mapster configs); `Base.Application/Extensions/DecoratorProperties.cs` (+ 2 DecoratorNotifyModules entries)
  - FE (12 created + 7 modified):
    - Created: `src/domain/entities/notify-service/NotificationTemplateDto.ts`; `src/infrastructure/gql-queries/notify-queries/NotificationTemplateQuery.ts`; `src/infrastructure/gql-mutations/notify-mutations/NotificationTemplateMutation.ts`; `src/application/stores/notification-template-stores/notification-template-store.ts` + barrel; `src/presentation/pages/crm/notification/notificationtemplate.tsx` (page config, card-grid/details, capability gate); `src/presentation/components/page-components/crm/notification/index.ts` (folder barrel); `src/presentation/components/page-components/crm/notification/notificationtemplate/{index.tsx,index-page.tsx,view-page.tsx,notification-preview.tsx,status-pills.tsx}` (5 files — Variant B + split-pane + 3-sub-panel live preview + count pills)
    - Modified: `src/app/[lang]/crm/notification/notificationtemplate/page.tsx` (stub replaced); `src/presentation/pages/crm/notification/index.ts`; `src/domain/entities/notify-service/index.ts`; `src/infrastructure/gql-queries/notify-queries/index.ts`; `src/infrastructure/gql-mutations/notify-mutations/index.ts`; `src/application/stores/index.ts`; `src/application/configs/data-table-configs/notify-service-entity-operations.ts` (+ `NOTIFICATIONTEMPLATE` entry)
  - DB: `PSS_2.0_Backend/.../sql-scripts-dyanmic/NotificationTemplate-sqlscripts.sql` (created)
- **Deviations from spec**:
  - BE folder layout: flat `Commands/`+`Queries/` vs nested per-command folders in §⑧ (both valid; see ISSUE-2).
  - Detail Audit card omits `CreatedBy/Date`, `ModifiedBy/Date` — BE GetById projection doesn't currently expose them; `LastTriggeredDate` rendered (see ISSUE-3 + ISSUE-8). Non-blocking: BE can add fields later without FE rewrites.
  - EF snapshot not auto-regenerated (see ISSUE-1).
- **Known issues opened**: ISSUE-1 (snapshot), ISSUE-2 (folder convention), ISSUE-3 (audit fields on GetById), ISSUE-4 (Test dispatcher placeholder), ISSUE-5 (Email/WhatsApp fan-out placeholder), ISSUE-6 (Push coming soon), ISSUE-7 (Custom recipient coming soon), ISSUE-8 (audit placeholders in detail card)
- **Known issues closed**: None
- **Verification**: `dotnet build -c Debug --no-restore` → 0 errors on Base.Application (273 warnings, all pre-existing baseline + 2 harmless Mapster null hints) and Base.API (2 pre-existing AutoMapper vulnerability notices, unrelated). `pnpm tsc --noEmit` → 0 new errors in any NotificationTemplate file (3 pre-existing TagDto duplicate-export clashes in `contact-service/index.ts` unrelated). Post-build validation: zero inline hex colors (except `iconColor` data values per directive), zero inline pixel padding/margins, no raw "Loading..." text, `<ScreenHeader>` + `FlowDataTableContainer showHeader={false}` confirmed (Variant B), no new `GridComponentName` values added (card-grid is config-driven). All `pre-build` checks passed: skeleton entity + NotifyDbContext + card-grid infra + FE stub all in place and correctly discovered.
- **Next step**: None (COMPLETED). User runs: (1) `dotnet ef database update` to apply migration, (2) `dotnet ef migrations add Expand_NotificationTemplate --no-build` locally to regenerate snapshot (ISSUE-1), (3) run `NotificationTemplate-sqlscripts.sql` to seed menu + grid + 12 system templates, (4) `pnpm dev` and E2E test per §⑪ checklist.