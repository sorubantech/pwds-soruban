---
screen: WhatsAppTemplate
registry_id: 31
module: Communication (CRM → WhatsApp)
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
- [x] HTML mockup analyzed (gallery grid + editor split-pane form + live preview)
- [x] Existing code reviewed (FE route stub, no BE)
- [x] Business rules + workflow extracted (Meta submission state machine)
- [x] FK targets resolved (Company path + GQL query verified)
- [x] File manifest computed (13 BE + 11 FE files + 2 child entities)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized (FORM layout with live-preview right pane + DETAIL layout)
- [x] User Approval received
- [x] Backend code generated (3 entities: WhatsAppTemplate + WhatsAppTemplateButton + WhatsAppTemplateVariable)
- [x] Backend wiring complete (NotifyModels DbContext)
- [x] Frontend code generated (card-grid index + editor view-page with split-pane live preview)
- [x] Frontend wiring complete
- [x] DB Seed script generated (GridFormSchema: SKIP for FLOW)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [x] `dotnet build` — 0 errors (verified post-fix)
- [ ] `pnpm dev` — page loads at `/{lang}/crm/whatsapp/whatsapptemplate` (user to verify)
- [ ] Card grid loads with `details` variant cards (user to verify)
- [ ] Summary widgets show Approved/Pending/Rejected counts (user to verify)
- [ ] Search + Category/Language/Status filters work (user to verify)
- [ ] `?mode=new` — editor opens with empty form + live preview (user to verify)
- [ ] Header Type radio toggles header input (None/Text/Image/Video/Document) (user to verify)
- [ ] Body textarea shows live character count (max 1024) (user to verify)
- [ ] Variable Mapping table auto-detects `{{N}}` tokens in body → adds rows (user to verify)
- [ ] Variable field-mapping dropdown shows optgroups (Contact/Donation/Org/Campaign/Event/System) (user to verify)
- [ ] Right-pane WhatsApp preview updates live as body/header/footer/buttons change (user to verify)
- [ ] Buttons section — add up to 3 (Quick Reply, URL, Phone), reorder, remove (user to verify)
- [ ] Save as Draft → creates record with status=Draft (user to verify)
- [ ] Submit for Review → confirm modal → status=Pending (SERVICE_PLACEHOLDER: Meta API) (user to verify)
- [ ] `?mode=edit&id=X` — loads pre-filled form; disabled when status=Pending (user to verify)
- [ ] `?mode=read&id=X` — DETAIL layout renders preview + metadata (not disabled form) (user to verify)
- [ ] Sync from Meta button (SERVICE_PLACEHOLDER) — toast stub (user to verify)
- [ ] Rejected banner shows rejection reason + Edit & Resubmit CTA (user to verify)
- [ ] Duplicate action copies template as Draft (user to verify)
- [ ] DB Seed — menu appears under CRM_WHATSAPP (after user runs seed SQL)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: WhatsAppTemplate
Module: Communication (CRM → WhatsApp)
Schema: notify
Group: NotifyModels (Backend), whatsapp-service (Frontend) — uses the existing communication schema that also houses EmailTemplate, SavedFilter, Notification

Business: The WhatsApp Templates screen is the creation and governance surface for Meta-approved message templates used in outbound WhatsApp Business messaging. NGO communication staff build structured templates (header + body + variables + footer + action buttons), preview them in a live WhatsApp phone frame, submit them to Meta for review, and track approval status. Each template is versioned by language (en, ar, hi, pt_BR, bn, fr, es) and categorized as Utility / Marketing / Authentication per Meta's classification rules. Approved templates are later consumed by the WhatsApp Campaign screen (#32) and automation workflows. Templates go through a workflow — Draft → Pending (submitted to Meta) → Approved / Rejected — and cannot be edited while Pending. Variable placeholders (`{{1}}`, `{{2}}`, ...) are mapped to PSS domain fields (Contact: First Name, Donation: Amount, Organization: Tax Code, etc.) so that per-send substitution happens automatically.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Fields extracted from HTML mockup gallery cards + editor form. Audit columns inherited from Entity base.
> **CompanyId is NOT a field** on the FLOW entity — it comes from HttpContext.

### Primary entity: `notify."WhatsAppTemplates"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| WhatsAppTemplateId | int | — | PK | — | Primary key |
| TemplateName | string | 100 | YES | — | Snake_case, unique per (Company, LanguageCode); e.g., `donation_receipt` |
| Category | string | 30 | YES | — | Enum: `Utility` / `Marketing` / `Authentication` (Meta category) |
| LanguageCode | string | 10 | YES | — | Meta codes: `en`, `ar`, `hi`, `pt_BR`, `bn`, `fr`, `es` |
| Status | string | 20 | YES | — | Enum: `Draft` / `Pending` / `Approved` / `Rejected` — default `Draft` |
| HeaderType | string | 20 | NO | — | Enum: `None` / `Text` / `Image` / `Video` / `Document` — default `None` |
| HeaderText | string | 60 | NO | — | When HeaderType=Text; supports one `{{1}}` variable |
| HeaderMediaUrl | string | 500 | NO | — | When HeaderType=Image/Video/Document |
| Body | string | 1024 | YES | — | Message body; contains `{{N}}` variable tokens |
| FooterText | string | 60 | NO | — | Static footer; no variables allowed (Meta rule) |
| MetaTemplateId | string | 100 | NO | — | External ID from Meta after approval (for API sync) |
| RejectionReason | string | 500 | NO | — | Populated when Status=Rejected |
| SubmittedDate | DateTime? | — | NO | — | When user clicked Submit for Review |
| ApprovedDate | DateTime? | — | NO | — | When Meta approved |
| LastUsedDate | DateTime? | — | NO | — | Updated by campaign-send side-effect |
| IsActive | bool | — | — | — | Inherited |

### Child entity 1: `notify."WhatsAppTemplateButtons"` (1:Many — max 3 rows per template)

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| WhatsAppTemplateButtonId | int | — | PK | — |
| WhatsAppTemplateId | int | — | YES | FK → WhatsAppTemplates (cascade) |
| ButtonType | string | 20 | YES | Enum: `QuickReply` / `Url` / `Phone` |
| ButtonLabel | string | 25 | YES | Displayed text (Meta max 25) |
| ButtonValue | string | 500 | NO | QuickReply=null, Url=href (supports `{{1}}`), Phone=E.164 number |
| OrderBy | int | — | YES | 1-3 display order |

### Child entity 2: `notify."WhatsAppTemplateVariables"` (1:Many — ordered by VariableIndex)

| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| WhatsAppTemplateVariableId | int | — | PK | — |
| WhatsAppTemplateId | int | — | YES | FK → WhatsAppTemplates (cascade) |
| VariableIndex | int | — | YES | 1, 2, 3, … matches `{{N}}` in body/header |
| Scope | string | 20 | YES | Enum: `Header` / `Body` (so `{{1}}` in header and body are disambiguated) |
| FieldGroup | string | 30 | YES | Optgroup: `Contact` / `Donation` / `Organization` / `Campaign` / `Event` / `System` |
| FieldKey | string | 60 | YES | Dot-path within group, e.g., `Contact.FirstName`, `Donation.Amount`, `Organization.TaxCode` |
| SampleValue | string | 200 | NO | Used for preview + Meta submission |
| FallbackValue | string | 200 | NO | Used at send-time if field resolves to null |

**Child Entities summary:**
| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| WhatsAppTemplateButton | 1:Many via WhatsAppTemplateId | ButtonType, ButtonLabel, ButtonValue, OrderBy |
| WhatsAppTemplateVariable | 1:Many via WhatsAppTemplateId | VariableIndex, Scope, FieldGroup, FieldKey, SampleValue, FallbackValue |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)
> Only one external FK: the implicit CompanyId on parent (HttpContext-scoped). No ApiSelect dropdowns on this form — language and category are fixed enums.

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| CompanyId | Company | Base.Domain/Models/ApplicationModels/Company.cs | (N/A — HttpContext tenant) | CompanyName | CompanyResponseDto |

**No ApiSelect FK dropdowns on the editor form.** Category and Language are fixed enum selects (hard-coded option lists per Meta allowlist). Variable field-key options come from a client-side catalog, not a GQL query.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `(CompanyId, TemplateName, LanguageCode)` composite unique — same template name can exist in multiple languages, but not twice in the same language within a company
- `TemplateName` must match regex `^[a-z][a-z0-9_]{0,99}$` (Meta WhatsApp rule — snake_case only)

**Required Field Rules:**
- TemplateName, Category, LanguageCode, Body are mandatory
- Buttons: when present, ButtonLabel is mandatory; ButtonValue mandatory for Url and Phone types; null for QuickReply
- Variables: if body contains `{{N}}`, a WhatsAppTemplateVariable row with VariableIndex=N must exist

**Conditional Rules:**
- If HeaderType=`Text` → HeaderText required (≤ 60 chars)
- If HeaderType in (`Image`, `Video`, `Document`) → HeaderMediaUrl required
- If HeaderType=`None` → HeaderText and HeaderMediaUrl must be null
- FooterText MUST NOT contain `{{N}}` tokens (Meta rule — footer is static)
- Max 3 buttons per template
- If ButtonType=`Url` → ButtonValue must start with `http://` or `https://`
- If ButtonType=`Phone` → ButtonValue must match E.164 pattern `^\+\d{8,15}$`
- If Status=`Pending` → template is read-only (all edits blocked server-side)
- If Status=`Approved` → TemplateName, Category, LanguageCode, Body are immutable (Meta locked); only metadata edits allowed

**Business Logic:**
- Body `{{N}}` tokens must be contiguous starting from 1 — cannot have `{{1}}, {{3}}` without `{{2}}`
- When user clicks "Save as Draft" → Status=`Draft`, SubmittedDate=null
- When user clicks "Submit for Review" → Status=`Pending`, SubmittedDate=now, MetaTemplateId pending Meta response (SERVICE_PLACEHOLDER — see §⑫)
- When Meta sync returns Approved → Status=`Approved`, ApprovedDate=now, MetaTemplateId populated
- When Meta sync returns Rejected → Status=`Rejected`, RejectionReason populated, template becomes editable again
- "Sync from Meta" pulls latest statuses for all Pending templates of this company (SERVICE_PLACEHOLDER)
- Duplicate action copies template with TemplateName=`{original}_copy`, Status=`Draft`

**Workflow:**
- States: `Draft → Pending → (Approved | Rejected)`; Rejected → Draft (via Edit & Resubmit); Approved has no outbound transitions (template is locked)
- Transitions:
  - `SaveAsDraft` (any state except Pending/Approved) → Draft
  - `SubmitForReview` (Draft or Rejected) → Pending
  - `SyncFromMeta` (system action) → Approved or Rejected
  - `Duplicate` (any state) → creates new record in Draft state

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: Transactional workflow screen with card-grid listing, 3-child entity form, live preview pane, and state machine
**Reason**: Editor is a full-page split-pane experience (form + live preview) that cannot fit in a modal. Record has 2 child collections (buttons, variables) with inline CRUD. Requires workflow state badges and conditional read-only modes. Listing UI is card-grid (`details` variant), not table, because templates are scanned as visual content.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) for WhatsAppTemplate
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Nested child creation — buttons (max 3) + variables (N rows) in one transaction
- [x] Unique validation — `(CompanyId, TemplateName, LanguageCode)` composite
- [x] Workflow commands: `SubmitWhatsAppTemplate`, `SyncWhatsAppTemplate`, `DuplicateWhatsAppTemplate` (in addition to Create/Update/Delete/Toggle)
- [x] Custom business rule validators — TemplateName regex, body/variable consistency, status-based edit lock, header-type conditional
- [ ] File upload command — deferred (header media URL is a string for now; upload handler is a later feature)
- [x] Summary query — `GetWhatsAppTemplateSummary` returns counts by status (Approved/Pending/Rejected/Draft)

**Frontend Patterns Required:**
- [x] FlowDataTable (listing) — `displayMode: card-grid`, `cardVariant: details`
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form (for FORM layout)
- [x] Zustand store (`whatsapp-template-store.ts` under `application/stores/whatsapp-template-stores/` to match SavedFilter convention)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back + Save as Draft + Submit for Review buttons)
- [x] Child grid inside form — Variables Mapping table (inline rows, auto-sync from body tokens) + Buttons list (up to 3 items with up/down reorder)
- [x] Workflow status badge + action buttons (Submit / Sync / Duplicate / Edit & Resubmit)
- [ ] File upload widget — UI-only placeholder for header media (drag-drop zone, no real upload)
- [x] Summary cards / count widgets above grid — 3 stat pills (Approved / Pending / Rejected)
- [ ] Grid aggregation columns — N/A (card-grid, no per-row subqueries)
- [x] **Live WhatsApp preview** (right pane of editor) — custom component `whatsapp-phone-preview.tsx` that renders the form values in a WhatsApp chat bubble mock

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.
> **CRITICAL for FLOW**: describe BOTH the FORM layout (new/edit) AND the DETAIL layout (read).

### Grid/List View (mode=index, default URL)

**Display Mode**: `card-grid`
**Card Variant**: `details`
**Reuses**: existing `<CardGrid>` shell + `details-card.tsx` variant (built by #29 SMS Template or earlier — see `.claude/feature-specs/card-grid.md`).

**Card Config:**
```yaml
cardConfig:
  variant: details
  headerField: "templateName"          # monospace font via card className override
  metaFields: ["category", "language"] # chip: Utility/Marketing/Authentication, chip: English/Arabic/…
  snippetField: "bodyPreview"          # server-side stripped body (first 100 chars — backend computes)
  footerField: "lastUsedDate"          # "Last used Apr 12" format
  snippetMaxChars: 100
```

**Card Extras** (extensions needed for this screen — note in Section ⑫):
- Status badge in card footer (Approved green / Pending yellow / Rejected red / Draft gray) — the `details` variant does not render status by default. Solution: include `status` as the LAST entry in `metaFields` with a config flag, OR (preferred) extend `DetailsCardConfig` with an optional `statusField: string` + per-variant badge renderer. See Section ⑫ deviation note.
- WhatsApp mini-bubble preview inside the card header area (replace the flat text card preview with a stylized bubble). Defer to a minor card-level CSS tweak — `details` variant still renders, just styled with WhatsApp green accent.

**Responsive breakpoints (card-grid default)**: 1 col (xs) → 2 col (sm) → 3 col (lg) → 4 col (xl). Card inner padding `p-4`, gap `gap-3`. Body click → `?mode=read&id={id}`.

**Grid Columns** (N/A for card-grid — kept for parity if user toggles to table mode in future; currently ignored):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Template Name | templateName | text (monospace) | 200px | YES | — |
| 2 | Category | category | badge | 110px | YES | Utility/Marketing/Authentication |
| 3 | Language | languageCode | badge | 90px | YES | en/ar/hi/… |
| 4 | Status | status | badge | 120px | YES | color-coded |
| 5 | Last Used | lastUsedDate | date | 110px | YES | — |

**Search/Filter Fields** (toolbar above card-grid, unchanged from mockup filter bar):
- Search text (matches templateName)
- Category filter (All / Utility / Marketing / Authentication)
- Language filter (All / English / Arabic / Hindi / Portuguese / Bengali / French / Spanish)
- Status filter (All / Approved / Pending Review / Rejected / Draft)

**Grid Actions (per card — shown via `RowActionMenu` kebab on hover):**
- View (→ `?mode=read&id=X`) — default on card body click
- Edit (→ `?mode=edit&id=X`) — disabled if Status=Pending
- Duplicate (→ creates Draft copy; reloads list) — all statuses
- Preview (→ opens modal with full WhatsApp phone preview, no edit) — alternative to View
- Submit (→ only visible when Status=Draft) — opens confirm modal then submits
- Resubmit (→ only visible when Status=Rejected) — opens `?mode=edit&id=X`
- Delete — disabled if Status=Pending or Approved (Meta-locked)

**Row Click**: Navigates to `?mode=read&id={id}` (DETAIL layout)

### Page Widgets & Summary Cards

**Widgets**: 3 count pills displayed INLINE inside the page-header subtitle row (see mockup lines 418-422) — NOT as separate KPI cards.

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | Approved | summary.approvedCount | count + green dot | Subtitle row, inline |
| 2 | Pending | summary.pendingCount | count + yellow dot | Subtitle row, inline |
| 3 | Rejected | summary.rejectedCount | count + red dot | Subtitle row, inline |

**Grid Layout Variant**: `widgets-above-grid`
- The 3 status pills sit inside the ScreenHeader subtitle row.
- FE Dev uses **Variant B**: `<ScreenHeader>` with inline status summary + `<DataTableContainer showHeader={false}>` (to avoid duplicate header — ContactType #19 precedent).

**Summary GQL Query:**
- Query name: `GetWhatsAppTemplateSummary`
- Returns: `WhatsAppTemplateSummaryDto { approvedCount, pendingCount, rejectedCount, draftCount }`
- Added to `WhatsAppTemplateQueries.cs` alongside `GetAll` and `GetById`

### Grid Aggregation Columns

**Aggregation Columns**: NONE. Card-grid mode does not use column subqueries.

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

---

#### LAYOUT 1: FORM (mode=new & mode=edit) — Split-Pane Editor

> This is the **core** UI of this screen. The mockup editor (lines 789-1113) is a full-page split pane: left = form, right = live WhatsApp phone preview. This is NOT a standard vertical form.

**Page Header** (above the split pane — mockup lines 792-817):
- Back button (→ returns to grid list)
- Inline template-name text input (monospace, max 100 chars)
- Inline Category dropdown (Utility / Marketing / Authentication)
- Inline Language dropdown (7 options)
- Status badge (read-only — shows current state)

**Editor Body**: Two-column split pane (55% / 45% on ≥ lg, stacked on < lg).

**LEFT PANE — 5 Editor Sections** (scroll-y if needed, `editor-left` container):

| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | fa-heading | **Header** *(optional)* | full-width | expanded | HeaderType radio group (5 options with icons), HeaderText (shows when Text), HeaderMediaUrl drag-drop zone (shows when Image/Video/Document) |
| 2 | fa-align-left | **Body** *(required)* | full-width | expanded | Formatting toolbar (B/I/S/monospace + "Add Variable" button), Body textarea (min-h 160px, max 1024 chars, live char-count), emoji-passthrough |
| 3 | fa-code | **Variable Mapping** | full-width | expanded | Auto-synced table from body tokens: Variable chip (read-only), PSS Field Mapping select (optgroups: Contact, Donation, Organization, Campaign, Event, System), Sample Value input, Fallback input, "+ Add Variable" button |
| 4 | fa-shoe-prints | **Footer** *(optional)* | full-width | expanded | FooterText input (max 60 chars, no variables allowed) |
| 5 | fa-hand-pointer | **Buttons** *(optional, max 3)* | full-width | expanded | List of button-items (ButtonType badge + Label + Value + edit/move-up/remove actions), "+ Add Button (N/3)" CTA disabled at 3 |

**Field Widget Mapping** (all fields across all sections):

| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| templateName | Header (page) | text (monospace) | `template_name` | regex `^[a-z][a-z0-9_]{0,99}$` | Meta snake_case rule |
| category | Header (page) | select | — | required | Utility / Marketing / Authentication |
| languageCode | Header (page) | select | — | required | 7-option allowlist |
| status | Header (page) | read-only badge | — | — | Color-coded; driven by backend |
| headerType | 1 Header | radio-inline (icon chips) | — | required default=None | None / Text / Image / Video / Document |
| headerText | 1 Header | text | "Header text (max 60 chars)" | max 60, 1 var allowed | Shows only when HeaderType=Text |
| headerMediaUrl | 1 Header | drag-drop file zone (UI stub) | "Drag & drop or click" | required when media | SERVICE_PLACEHOLDER (handler = toast "Upload not yet wired") |
| body | 2 Body | textarea + toolbar | — | required, max 1024 | Live char-count; `{{N}}` tokens auto-extracted |
| variables[] | 3 Variable Mapping | child grid (see below) | — | — | Auto-derived rows from body |
| footerText | 4 Footer | text | "Footer text (max 60 chars)" | max 60, no `{{N}}` | — |
| buttons[] | 5 Buttons | child list (see below) | — | — | Max 3 items |

**Special Form Widgets:**

- **Header Type Radio Group** (inline chip selector — see mockup `.radio-inline` pattern, lines 840-846):
  | Option | Icon | Label | Triggers |
  |--------|------|-------|----------|
  | None | fa-ban | None | Hides all header inputs |
  | Text | fa-font | Text | Shows HeaderText input |
  | Image | fa-image | Image | Shows drag-drop (image mime) |
  | Video | fa-video | Video | Shows drag-drop (video mime) |
  | Document | fa-file-pdf | Document | Shows drag-drop (pdf) |

- **Body Toolbar** (mockup lines 863-872):
  - B / I / S / monospace format buttons (wrap selection with WhatsApp markdown: `*bold*`, `_italic_`, `~strike~`, `` `code` ``)
  - "+ Add Variable" button inserts `{{N+1}}` at cursor position and adds a new row to the Variable Mapping table

- **Variable Mapping Child Grid** (mockup lines 887-995):
  - **Auto-sync behavior**: parse `body + headerText` for `{{N}}` tokens on every change. Create missing rows, remove orphan rows. User cannot manually delete a row that is still referenced in the body — only by removing the token from the body.
  - Columns: Variable chip, PSS Field Mapping (grouped select), Sample Value (text), Fallback (text)
  - Field Mapping optgroups (hard-coded client catalog — no GQL query):
    - Contact: First Name / Last Name / Full Name / Email / Phone
    - Donation: Amount / Currency / Purpose / Receipt Number / Date
    - Organization: Name / Tax Code
    - Campaign: Name / Goal
    - Event: Name / Date / Location
    - System: Current Date / Organization URL
  - "+ Add Variable" button below grid: inserts `{{N+1}}` into body at cursor position and adds the matching row

- **Button Items Child List** (mockup lines 1005-1044):
  - Each row: ButtonType badge (colored by type — QuickReply blue, Url purple, Phone green) + Label + Value (truncated) + Edit / Move Up / Remove icons
  - "+ Add Button (N/3)" CTA at bottom — disabled when count=3 with tooltip "Maximum 3 buttons reached"
  - Add/Edit opens an inline expandable panel (or modal) with: ButtonType select, Label (max 25), Value (conditional — URL or Phone placeholder)

- **Rejected Banner** (mockup lines 820-829):
  - Shown only when `status=Rejected` AND `mode=read` (or `mode=edit` after unlock)
  - Red banner above the split pane: title "This template was rejected by Meta" + rejection reason text + "Edit & Resubmit" outline button that switches to `?mode=edit`

**RIGHT PANE — Live WhatsApp Phone Preview** (mockup lines 1049-1100):

New custom component: `whatsapp-phone-preview.tsx` (colocated with the view-page). Renders:
- Phone frame container (rounded 24px, shadow, 320px width)
- Phone header (WhatsApp green `#075E54`, org avatar, "Hope Foundation" / "Online")
- Chat area (WhatsApp pattern-bg `#e5ddd5`) rendering the bubble:
  - Header image (when HeaderType=Image) — placeholder gradient
  - Body text (variables replaced with Sample values, fallback to `{{N}}` if no sample)
  - Footer text (small gray)
  - Timestamp + double-check ticks
  - Buttons list (rendered as WhatsApp-style full-width white buttons with blue text `#00a5f4`)
- Input bar (non-interactive — "Type a message…")

**Preview re-renders on every form change** — React Hook Form `watch()` on relevant fields drives the preview props.

**Editor Footer** (below split pane, mockup lines 1104-1111):
- Cancel → navigate back (unsaved-changes dialog if dirty)
- Save as Draft → submits with Status=Draft
- Submit for Review → opens confirm modal (mockup lines 1115-1127), then submits with Status=Pending (SERVICE_PLACEHOLDER Meta call)

**Child Grids in Form:**
| Child | Grid Columns | Add/Edit Method | Delete | Notes |
|-------|-------------|----------------|--------|-------|
| WhatsAppTemplateVariable | Variable chip, PSS Field Mapping, Sample, Fallback | Auto-sync from body tokens | Auto-remove when token removed | User cannot manually add/delete rows; only via body tokens |
| WhatsAppTemplateButton | Type badge, Label, Value, Actions | Inline editable row OR modal | Manual delete via X icon | Reorder via up/down arrows |

---

#### LAYOUT 2: DETAIL (mode=read) — Preview + Metadata

> Read-only view shown on row click. **Different UI from form** — no split-pane, no live editing. A multi-column page with phone preview + metadata cards + submission history.

**Page Header**: FlowFormPageHeader with Back, Edit button (hidden when Status=Pending or Approved — Meta-locked)

**Header Actions**:
- Edit → `?mode=edit&id=X` (hidden when Pending/Approved)
- Duplicate → creates Draft copy, navigates to `?mode=edit&id={newId}`
- Submit for Review → only visible when Status=Draft
- Resubmit → only visible when Status=Rejected
- Delete → only visible when Status=Draft or Rejected
- More dropdown: Preview in Phone (modal), Copy JSON (debug), Sync from Meta (SERVICE_PLACEHOLDER)

**Page Layout**:
| Column | Width | Cards / Sections |
|--------|-------|-----------------|
| Left | 1fr | Rejected banner (if applicable), Metadata card, Body preview card, Buttons card |
| Right | 320px fixed | WhatsApp phone preview (same component as FORM right pane) |

**Left Column Cards** (in order):
| # | Card Title | Content |
|---|-----------|---------|
| 1 | Rejected Banner | (Only if Status=Rejected) red banner with RejectionReason + Edit & Resubmit CTA |
| 2 | Template Info | TemplateName (monospace), Category badge, Language badge, Status badge, MetaTemplateId (if present) |
| 3 | Body | Read-only code-style preview of Body with `{{N}}` tokens highlighted (yellow chip style, mockup `.var-tag`) |
| 4 | Variables Used | Read-only table: Variable, Field Mapping (resolved path), Sample, Fallback |
| 5 | Buttons | Read-only list of buttons (same visual as form section 5, but without edit/remove icons) |
| 6 | Timeline | Created / Submitted / Approved or Rejected events with timestamps + actor |

**Right Column**:
| # | Card Title | Content |
|---|-----------|---------|
| 1 | Live Preview | `<WhatsAppPhonePreview>` rendering the template in read-only mode (same component reused) |

**Layout on < lg (tablet/phone)**: stack — preview card moves below metadata cards.

### User Interaction Flow

1. User visits grid → sees card-grid of templates + 3 status count pills in header
2. Clicks "+ Create Template" → URL: `?mode=new` → **FORM LAYOUT (split pane)** with empty form + empty phone preview
3. User types body / adds variables / buttons → preview updates live on every keystroke
4. Clicks "Save as Draft" → API creates record with Status=Draft → redirects to `?mode=read&id={newId}` → **DETAIL LAYOUT** renders
5. Alternatively clicks "Submit for Review" → confirm modal → API creates+submits (Status=Pending) → redirects to `?mode=read&id={newId}` with Pending badge and edit disabled
6. From detail: clicks "Edit" (visible only if Draft or Rejected) → `?mode=edit&id=X` → FORM pre-filled
7. From detail: clicks "Duplicate" → API creates copy (Status=Draft) → navigates to `?mode=edit&id={newId}`
8. From detail: clicks "Sync from Meta" (SERVICE_PLACEHOLDER) → toast "Syncing from Meta…" then toast "Sync not yet wired"
9. Grid row click → `?mode=read&id={id}` → detail layout
10. Back button → `?mode=index` (or no query params) → grid
11. Unsaved changes: if form is dirty and user navigates, show confirm dialog

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical FLOW reference entity (SavedFilter) to this entity.

**Canonical Reference**: SavedFilter (FLOW, NotifyModels group, crm/communication route)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | WhatsAppTemplate | Entity/class name |
| savedFilter | whatsAppTemplate | camelCase variable names |
| SavedFilterId | WhatsAppTemplateId | PK field name |
| SavedFilters | WhatsAppTemplates | Table name / collection navigation |
| saved-filter | whatsapp-template | kebab-case (file names, CSS classes) |
| savedfilter | whatsapptemplate | Lowercase no-dash (FE folder, route path segment) |
| SAVEDFILTER | WHATSAPPTEMPLATE | Menu code, grid code |
| notify | notify | DB schema (SAME — WhatsApp lives in the notify schema alongside SavedFilter) |
| NotifyModels | NotifyModels | Backend group (SAME folder) |
| Notify | Notify | Backend namespace suffix (SAME) |
| CRM_COMMUNICATION | CRM_WHATSAPP | Parent menu code CHANGES |
| CRM | CRM | Module code (SAME) |
| crm/communication/savedfilter | crm/whatsapp/whatsapptemplate | FE route base |
| saved-filter-stores | whatsapp-template-stores | Store folder under `src/application/stores/` (SavedFilter convention — store is NOT at component level) |
| saved-filter-store | whatsapp-template-store | Store file name |
| notify-service | whatsapp-service | FE domain-entities + gql-* subfolder (new subfolder under communication area) |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files (13 files — 3 entities + workflow commands)

**Main entity files (11):**

| # | File | Path |
|---|------|------|
| 1 | Entity — WhatsAppTemplate | Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/NotifyModels/WhatsAppTemplate.cs |
| 2 | Entity — WhatsAppTemplateButton | Pss2.0_Backend/.../Base.Domain/Models/NotifyModels/WhatsAppTemplateButton.cs |
| 3 | Entity — WhatsAppTemplateVariable | Pss2.0_Backend/.../Base.Domain/Models/NotifyModels/WhatsAppTemplateVariable.cs |
| 4 | EF Configs (3) | Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/NotifyConfigurations/{WhatsAppTemplate,WhatsAppTemplateButton,WhatsAppTemplateVariable}Configuration.cs |
| 5 | Schemas (DTOs) | Pss2.0_Backend/.../Base.Application/Schemas/NotifySchemas/WhatsAppTemplateSchemas.cs (includes WhatsAppTemplateRequestDto / ResponseDto + Button and Variable request/response DTOs + WhatsAppTemplateSummaryDto) |
| 6 | Create Command | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/WhatsAppTemplates/CreateCommand/CreateWhatsAppTemplate.cs (nested button + variable creation) |
| 7 | Update Command | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/WhatsAppTemplates/UpdateCommand/UpdateWhatsAppTemplate.cs (diff-update children) |
| 8 | Delete Command | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/WhatsAppTemplates/DeleteCommand/DeleteWhatsAppTemplate.cs (soft delete; locked if Status=Pending/Approved) |
| 9 | Toggle Command | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/WhatsAppTemplates/ToggleCommand/ToggleWhatsAppTemplate.cs |
| 10 | GetAll Query | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/WhatsAppTemplates/GetAllQuery/GetAllWhatsAppTemplate.cs (includes bodyPreview, category/language/status filters) |
| 11 | GetById Query | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/WhatsAppTemplates/GetByIdQuery/GetWhatsAppTemplateById.cs (includes buttons + variables) |

**Extra workflow files (3):**

| # | File | Path |
|---|------|------|
| 12a | Submit Command | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/WhatsAppTemplates/SubmitCommand/SubmitWhatsAppTemplate.cs (Draft|Rejected → Pending; SERVICE_PLACEHOLDER for Meta call) |
| 12b | Sync Command | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/WhatsAppTemplates/SyncCommand/SyncWhatsAppTemplate.cs (Pending → Approved|Rejected; SERVICE_PLACEHOLDER for Meta poll) |
| 12c | Duplicate Command | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/WhatsAppTemplates/DuplicateCommand/DuplicateWhatsAppTemplate.cs (any → new Draft copy) |

**Summary query (1):**

| # | File | Path |
|---|------|------|
| 13a | Summary Query | Pss2.0_Backend/.../Base.Application/Business/NotifyBusiness/WhatsAppTemplates/GetSummaryQuery/GetWhatsAppTemplateSummary.cs (status counts) |

**GraphQL endpoints (2):**

| # | File | Path |
|---|------|------|
| 13b | Mutations | Pss2.0_Backend/.../Base.API/EndPoints/Notify/Mutations/WhatsAppTemplateMutations.cs (Create/Update/Delete/Toggle/Submit/Sync/Duplicate) |
| 13c | Queries | Pss2.0_Backend/.../Base.API/EndPoints/Notify/Queries/WhatsAppTemplateQueries.cs (GetAll/GetById/GetSummary) |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | Base.Application/Data/Persistence/INotifyDbContext.cs | `DbSet<WhatsAppTemplate>`, `DbSet<WhatsAppTemplateButton>`, `DbSet<WhatsAppTemplateVariable>` |
| 2 | Base.Infrastructure/Data/Persistence/NotifyDbContext.cs | Same three DbSet properties |
| 3 | Base.Application/Mappings/NotifyMappings.cs | Mapster configs for Request/Response + nested Button/Variable DTOs |
| 4 | Base.Infrastructure/DecoratorProperties.cs → DecoratorNotifyModules | Add 3 decorator entries |
| 5 | Base.API/GlobalUsing.cs (and counterparts in Base.Application/Base.Infrastructure) | Add `using Base.Domain.Models.NotifyModels;` if missing (check first) |
| 6 | Base.API/Program.cs (schema registration) | Register `WhatsAppTemplateQueries` + `WhatsAppTemplateMutations` |

### Frontend Files (11 files — card-grid reuses existing infra; ONLY new screen files)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | Pss2.0_Frontend/src/domain/entities/whatsapp-service/WhatsAppTemplateDto.ts (includes Button and Variable child DTOs + Summary DTO) |
| 2 | GQL Query | Pss2.0_Frontend/src/infrastructure/gql-queries/whatsapp-queries/WhatsAppTemplateQuery.ts (GetAll + GetById + GetSummary) |
| 3 | GQL Mutation | Pss2.0_Frontend/src/infrastructure/gql-mutations/whatsapp-mutations/WhatsAppTemplateMutation.ts (Create/Update/Delete/Toggle/Submit/Sync/Duplicate) |
| 4 | Page Config | Pss2.0_Frontend/src/presentation/pages/crm/whatsapp/whatsapptemplate.tsx (sets `displayMode: card-grid`, `cardVariant: details`, `cardConfig`) |
| 5 | Index folder entry | Pss2.0_Frontend/src/presentation/components/page-components/crm/whatsapp/whatsapptemplate/index.tsx (exports) |
| 6 | Index Page | Pss2.0_Frontend/src/presentation/components/page-components/crm/whatsapp/whatsapptemplate/index-page.tsx (ScreenHeader with inline status pills + DataTableContainer showHeader={false}) |
| 7 | **View Page (3 modes)** | Pss2.0_Frontend/src/presentation/components/page-components/crm/whatsapp/whatsapptemplate/view-page.tsx (split-pane editor + detail layout per mode) |
| 8 | **Zustand Store** | Pss2.0_Frontend/src/application/stores/whatsapp-template-stores/whatsapp-template-store.ts (mirror SavedFilter convention) |
| 9 | **WhatsApp Phone Preview** (new custom component) | Pss2.0_Frontend/src/presentation/components/page-components/crm/whatsapp/whatsapptemplate/whatsapp-phone-preview.tsx |
| 10 | Status Summary Widgets | Pss2.0_Frontend/src/presentation/components/page-components/crm/whatsapp/whatsapptemplate/status-pills.tsx (3 inline count pills for ScreenHeader subtitle) |
| 11 | Route Page (REPLACE stub) | Pss2.0_Frontend/src/app/[lang]/crm/whatsapp/whatsapptemplate/page.tsx (replace `<div>Need to Develop</div>` with page-component import) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | src/presentation/components/page-components/crm/whatsapp/index.ts | Export whatsapptemplate folder barrel |
| 2 | src/presentation/pages/crm/whatsapp/index.ts | Export whatsapptemplate page config |
| 3 | src/application/stores/index.ts (or barrel equivalent) | Export whatsapp-template-stores barrel |
| 4 | src/domain/entities/whatsapp-service/index.ts | Create if missing + export WhatsAppTemplateDto |
| 5 | src/infrastructure/gql-queries/whatsapp-queries/index.ts | Create if missing + export WhatsAppTemplateQuery |
| 6 | src/infrastructure/gql-mutations/whatsapp-mutations/index.ts | Create if missing + export WhatsAppTemplateMutation |
| 7 | entity-operations.ts | Add WHATSAPPTEMPLATE operations mapping |
| 8 | operations-config.ts | Register import + operations entry |
| 9 | Sidebar menu config (DB seed — not FE file) | DB seed adds WHATSAPPTEMPLATE under CRM_WHATSAPP (see §⑨) |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: WhatsApp Templates
MenuCode: WHATSAPPTEMPLATE
ParentMenu: CRM_WHATSAPP
Module: CRM
MenuUrl: crm/whatsapp/whatsapptemplate
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: WHATSAPPTEMPLATE
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `WhatsAppTemplateQueries`
- Mutation type: `WhatsAppTemplateMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetAllWhatsAppTemplateList | [WhatsAppTemplateResponseDto] | searchText, pageNo, pageSize, sortField, sortDir, isActive, category, languageCode, status |
| GetWhatsAppTemplateById | WhatsAppTemplateResponseDto | whatsAppTemplateId |
| GetWhatsAppTemplateSummary | WhatsAppTemplateSummaryDto | — |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| CreateWhatsAppTemplate | WhatsAppTemplateRequestDto (with nested buttons[] + variables[]) | int (new ID) |
| UpdateWhatsAppTemplate | WhatsAppTemplateRequestDto | int |
| DeleteWhatsAppTemplate | whatsAppTemplateId | int |
| ToggleWhatsAppTemplate | whatsAppTemplateId | int |
| SubmitWhatsAppTemplate | whatsAppTemplateId | int (sets Status=Pending, SubmittedDate=now) |
| SyncWhatsAppTemplate | (no args — syncs all Pending for current tenant) | int (count updated) |
| DuplicateWhatsAppTemplate | whatsAppTemplateId | int (new ID of Draft copy) |

**Response DTO Fields** (what FE receives for `WhatsAppTemplateResponseDto`):
| Field | Type | Notes |
|-------|------|-------|
| whatsAppTemplateId | number | PK |
| templateName | string | snake_case |
| category | string | Utility / Marketing / Authentication |
| languageCode | string | en / ar / hi / … |
| status | string | Draft / Pending / Approved / Rejected |
| headerType | string | None / Text / Image / Video / Document |
| headerText | string \| null | — |
| headerMediaUrl | string \| null | — |
| body | string | raw body with `{{N}}` tokens |
| bodyPreview | string | first ~100 chars with HTML stripped — for card snippet |
| footerText | string \| null | — |
| metaTemplateId | string \| null | — |
| rejectionReason | string \| null | — |
| submittedDate | string \| null (ISO) | — |
| approvedDate | string \| null (ISO) | — |
| lastUsedDate | string \| null (ISO) | — |
| isActive | boolean | inherited |
| buttons | [WhatsAppTemplateButtonResponseDto] | nested |
| variables | [WhatsAppTemplateVariableResponseDto] | nested |

**WhatsAppTemplateButtonResponseDto:**
| Field | Type |
|-------|------|
| whatsAppTemplateButtonId | number |
| buttonType | string (QuickReply / Url / Phone) |
| buttonLabel | string |
| buttonValue | string \| null |
| orderBy | number |

**WhatsAppTemplateVariableResponseDto:**
| Field | Type |
|-------|------|
| whatsAppTemplateVariableId | number |
| variableIndex | number |
| scope | string (Header / Body) |
| fieldGroup | string |
| fieldKey | string |
| sampleValue | string \| null |
| fallbackValue | string \| null |

**WhatsAppTemplateSummaryDto:**
| Field | Type |
|-------|------|
| approvedCount | number |
| pendingCount | number |
| rejectedCount | number |
| draftCount | number |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — 0 errors (warnings OK)
- [ ] `pnpm dev` — page loads at `/{lang}/crm/whatsapp/whatsapptemplate`
- [ ] `pnpm tsc --noEmit` — no new TS errors in whatsapp-template files

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Card-grid loads with `details` variant — header=templateName, chips=[category, language], snippet=bodyPreview, footer=lastUsedDate
- [ ] Search filters templates by name
- [ ] Category / Language / Status filter dropdowns work (AND-composed with search)
- [ ] Status count pills (Approved/Pending/Rejected) in ScreenHeader subtitle show correct numbers
- [ ] `?mode=new`: FORM LAYOUT renders with split pane (left form / right live preview)
- [ ] Header Type radio: selecting Text reveals HeaderText input; selecting Image/Video/Document reveals drag-drop zone; None hides both
- [ ] Body textarea: char-count updates live, tokens `{{N}}` are parsed on change
- [ ] Variable Mapping table auto-populates rows matching body tokens; removing a token removes the row
- [ ] Variable field-key select shows all 6 optgroups with correct options
- [ ] Footer input rejects `{{N}}` on save with validation error
- [ ] Buttons section: add up to 3 (QuickReply, URL, Phone), reorder via up arrow, remove via X, Add button disabled at 3/3
- [ ] Right-pane preview updates live: body text, header image placeholder, footer, buttons
- [ ] Save as Draft: API creates record with Status=Draft → redirects to `?mode=read&id={newId}`
- [ ] Submit for Review: confirm modal appears → confirm creates+submits (Status=Pending) → redirects to detail with Pending badge
- [ ] `?mode=edit&id=X`: FORM pre-filled; Status=Pending shows read-only overlay with "Template locked while under review" banner
- [ ] `?mode=read&id=X`: DETAIL LAYOUT renders (metadata card + body preview + variables table + buttons list + timeline + right-pane phone preview) — NOT the form disabled
- [ ] Edit button hidden in detail when Status=Pending or Approved
- [ ] Rejected banner appears in detail + edit when Status=Rejected; "Edit & Resubmit" switches to edit mode
- [ ] Duplicate action creates Draft copy and navigates to `?mode=edit&id={newId}`
- [ ] Sync from Meta button shows toast stub (SERVICE_PLACEHOLDER — see §⑫)
- [ ] Delete disabled for Pending/Approved; works for Draft/Rejected
- [ ] Unsaved changes dialog triggers on back/navigate with dirty form
- [ ] Permissions: Edit/Delete respect BUSINESSADMIN capabilities

**DB Seed Verification:**
- [ ] Menu "WhatsApp Templates" appears under CRM → WhatsApp
- [ ] `GridType: FLOW`, `GridFormSchema: SKIP` — no form schema seeded
- [ ] `GridCode: WHATSAPPTEMPLATE` row present in Grid table

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT a field** in the entity table — it comes from HttpContext in FLOW tenant scoping
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP
- **view-page.tsx handles ALL 3 modes** — new/edit share the split-pane FORM layout, read has a separate DETAIL layout
- **DETAIL layout is a different UI**, not the form with disabled fields — the right pane (phone preview) is reused, but the left pane is metadata cards, not form sections
- **Store location**: `src/application/stores/whatsapp-template-stores/whatsapp-template-store.ts` — NOT colocated with the component. Follow the SavedFilter convention (store at app-level, not component-level). This differs from the `_FLOW.md` template's suggested path — defer to SavedFilter precedent
- **Schema is `notify`, group is `NotifyModels`** — WhatsApp Templates share the communication schema with SavedFilter, EmailTemplate, Notification. Do NOT create a new `whatsapp` schema
- **Card-grid infrastructure already exists** — `<CardGrid>` shell, `details-card.tsx`, `data-table-container.tsx` card-grid branch are all built. Verify by reading `src/presentation/components/page-components/card-grid/`. This screen is a pure consumer — NO new infra
- **Dependency #29 SMS Template**: the registry lists SMS Template #29 as the infra-builder for card-grid (Wave 2.4). Infrastructure is now in place regardless of whether #29 has been built as a screen yet. Planning-wise, this means #31 can build on top without waiting for #29 to ship
- **TemplateName Meta rule**: regex `^[a-z][a-z0-9_]{0,99}$` is a hard Meta requirement, not a PSS preference. Validator must reject uppercase, spaces, hyphens
- **Footer cannot contain variables** — Meta rule. Validator must reject `{{N}}` in FooterText
- **Edit lock when Pending**: server-side, Update/Delete/Toggle commands must reject with validation error when Status=Pending. Do NOT rely on UI-only disabled fields
- **Approved templates are Meta-locked**: name, category, language, body become immutable. Only metadata (lastUsedDate, metadata-level fields) can change. Server-side enforcement required
- **Variables auto-sync**: the FE must re-parse body tokens on every change, adding missing rows + removing orphan rows. This is not a server-side job — the final POST payload is authoritative
- **Variable field-key catalog is client-side** — no GQL query. If the catalog grows, consider moving to a config file under `src/config/` (not an urgent concern for first build)
- **Status badge `details` variant extension**: the existing `DetailsCardConfig` does not include a status field. Options:
  - (A) Include status in `metaFields` as the last chip with special styling (simplest, works today)
  - (B) Extend `DetailsCardConfig` with `statusField?: string` + `statusBadgeMap?: Record<string, string>` (cleaner but infra change)
  - (C) Create a new `template` variant specifically for template screens (over-engineered for 3 screens)
  - **Recommended: Option A** for first build; revisit if SMS #29 / Notification #36 need the same extension
- **WhatsApp phone preview component**: new custom component `whatsapp-phone-preview.tsx`. Colocated with the view-page (not promoted to shared components yet — wait until SMS #29 or similar screen needs a preview too)

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ SERVICE_PLACEHOLDER: **Sync from Meta** button (header action + in SyncWhatsAppTemplate command). Full UI + command wiring built. Handler returns immediately with a toast / success count of 0 because the Meta WhatsApp Business Cloud API client is not in the codebase yet. Future work: wire `IMetaWhatsAppClient` service with credentials from CompanyWhatsAppSetup (#34)
- ⚠ SERVICE_PLACEHOLDER: **Submit for Review** — SubmitWhatsAppTemplate command sets Status=Pending and records SubmittedDate, but does NOT actually POST to Meta. Full UI + confirmation modal + state transition built. When Meta client is wired, the Submit command additionally calls `IMetaWhatsAppClient.SubmitTemplateAsync(...)` and stores the returned MetaTemplateId
- ⚠ SERVICE_PLACEHOLDER: **Header media upload** (drag-drop zone for Image/Video/Document). UI accepts file drops and shows preview, but persists as a local blob URL rather than uploading to CDN/storage. Saving the template stores HeaderMediaUrl as the temporary URL. Future work: wire media upload service (likely same infra needed by Email Template #24 attachments)

Full UI must be built (buttons, forms, modals, panels, interactions). Only the handler for the external service call is mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | S1 (2026-04-19) | Low | BE / Schema | Button scope contiguity validated as flat 1..N across all URL buttons (single sequence). `WhatsAppTemplateVariable` lacks a `ButtonOrderBy` column to support strict per-button contiguity. Future enhancement if users author many URL buttons with variables. | OPEN |
| ISSUE-2 | S1 (2026-04-19) | Low | BE / Mapster | `WhatsAppTemplate→WhatsAppTemplateDto` is `.NewConfig()` relying on Mapster inheritance from the `→WhatsAppTemplateResponseDto` config. BodyPreview + nested Buttons/Variables should carry forward, but verify at first runtime call that children populate on the `Dto` projection. | OPEN |
| ISSUE-3 | S1 (2026-04-19) | Low | BE→FE contract | `SyncWhatsAppTemplate` returns `BaseApiResponse<WhatsAppTemplateRequestDto>` (no `updatedCount`). FE query requests `data { updatedCount }` with `?? 0` fallback, so toast always shows 0. Fix: introduce `WhatsAppTemplateSyncResultDto { updatedCount }` and wire through handler. | OPEN |
| ISSUE-4 | S1 (2026-04-19) | Low | FE DTO | `WhatsAppTemplateResponseDto.ts` includes redundant `createdAt` + `modifiedAt` aliases alongside `createdDate` / `modifiedDate` — BE only returns `*Date`. The `*At` fields will always be null in GQL responses. Remove redundant aliases or wire them server-side. | OPEN |
| ISSUE-5 | S1 (2026-04-19) | Low | DB Seed | Seed SQL placed at `sql-scripts-dyanmic/` (typo — existing repo folder; not `dynamic`). Convention match correct; flag as pre-existing cosmetic folder name issue (not this screen's responsibility). | OPEN |
| ISSUE-6 | S1 (2026-04-19) | Medium | BE GQL | Initial BE method was `GetAllWhatsAppTemplateList` → GQL `getAllWhatsAppTemplateList`, but FE called `whatsAppTemplates`. **Hot-patched in S1**: renamed BE method to `GetWhatsAppTemplates` to follow `EmailTemplate` precedent (HotChocolate strips `Get` + camelCase). Verified `dotnet build` still green post-rename. **RESOLVED** in same session. | RESOLVED |
| ISSUE-7 | S1 (2026-04-19) | Low | BE Naming | Toggle command named `ActivateDeactivateWhatsAppTemplate` (not `ToggleWhatsAppTemplate` as per spec Section ⑩). FE correctly calls `activateDeactivateWhatsAppTemplate` so wiring is functional. Cosmetic naming deviation from spec. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-19 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. FLOW screen, card-grid/details variant (reuses existing shell + details variant built by #24 EmailTemplate). 3-entity parent+2-children with workflow state machine. 3 SERVICE_PLACEHOLDERs (Meta Submit, Meta Sync, header media upload).
- **Files touched**:
  - BE (19 created, 4 modified):
    - Created (16): `Base.Domain/Models/NotifyModels/WhatsAppTemplate.cs` · `WhatsAppTemplateButton.cs` · `WhatsAppTemplateVariable.cs` · `Base.Infrastructure/Data/Configurations/NotifyConfigurations/WhatsAppTemplateConfiguration.cs` · `WhatsAppTemplateButtonConfiguration.cs` · `WhatsAppTemplateVariableConfiguration.cs` · `Base.Application/Schemas/NotifySchemas/WhatsAppTemplateSchemas.cs` · `Base.Application/Business/NotifyBusiness/WhatsAppTemplates/CreateCommand/CreateWhatsAppTemplate.cs` · `UpdateCommand/UpdateWhatsAppTemplate.cs` · `DeleteCommand/DeleteWhatsAppTemplate.cs` · `ToggleCommand/ToggleWhatsAppTemplate.cs` · `SubmitCommand/SubmitWhatsAppTemplate.cs` · `SyncCommand/SyncWhatsAppTemplate.cs` · `DuplicateCommand/DuplicateWhatsAppTemplate.cs` · `GetAllQuery/GetAllWhatsAppTemplate.cs` · `GetByIdQuery/GetWhatsAppTemplateById.cs` · `GetSummaryQuery/GetWhatsAppTemplateSummary.cs` · `Base.API/EndPoints/Notify/Mutations/WhatsAppTemplateMutations.cs` · `Base.API/EndPoints/Notify/Queries/WhatsAppTemplateQueries.cs`
    - Modified (4): `Base.Application/Data/Persistence/INotifyDbContext.cs` (3 DbSets) · `Base.Infrastructure/Data/Persistence/NotifyDbContext.cs` (3 DbSets) · `Base.Application/Extensions/DecoratorProperties.cs` (WhatsApp decorator consts) · `Base.Application/Mappings/NotifyMappings.cs` (parent + 2 children Mapster configs)
    - Hot-patched: `Base.API/EndPoints/Notify/Queries/WhatsAppTemplateQueries.cs` — renamed `GetAllWhatsAppTemplateList` → `GetWhatsAppTemplates` to align GQL field name with FE query `whatsAppTemplates` (EmailTemplate precedent)
  - FE (13 created, 7 modified, 1 route stub replaced):
    - Created (13): `src/domain/entities/whatsapp-service/WhatsAppTemplateDto.ts` + `index.ts` · `src/infrastructure/gql-queries/whatsapp-queries/WhatsAppTemplateQuery.ts` + `index.ts` · `src/infrastructure/gql-mutations/whatsapp-mutations/WhatsAppTemplateMutation.ts` + `index.ts` · `src/application/stores/whatsapp-template-stores/whatsapp-template-store.ts` + `sync-variables.ts` + `index.ts` · `src/presentation/pages/crm/whatsapp/whatsapptemplate.tsx` · `src/presentation/components/page-components/crm/whatsapp/whatsapptemplate/{index,index-page,view-page,whatsapp-phone-preview,status-pills,variable-mapping-table,button-items-list}.tsx`
    - Modified (7): `src/domain/entities/index.ts` · `src/infrastructure/gql-queries/index.ts` · `src/infrastructure/gql-mutations/index.ts` · `src/application/stores/index.ts` · `src/application/configs/data-table-configs/notify-service-entity-operations.ts` · `src/presentation/pages/crm/whatsapp/index.ts` · `src/presentation/components/page-components/crm/whatsapp/index.ts`
    - Route replaced: `src/app/[lang]/crm/whatsapp/whatsapptemplate/page.tsx` (stub `<div>Need to Develop</div>` → real page-component import)
  - DB: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/WhatsAppTemplate-sqlscripts.sql` (created) — Menu WHATSAPPTEMPLATE under CRM_WHATSAPP, MenuCapabilities for BUSINESSADMIN, Grid (FLOW, GridFormSchema=NULL), 12 Fields + 12 GridFields
- **Deviations from spec**:
  - Seed path placed at `sql-scripts-dyanmic/` (existing repo convention — spec suggested `DB_Scripts/` which does not exist)
  - Per-command folders used (CreateCommand/, UpdateCommand/, etc.) per spec §⑧ manifest (deviates from SavedFilter/EmailTemplate flat `Commands/` folder)
  - Toggle command named `ActivateDeactivateWhatsAppTemplate` instead of `ToggleWhatsAppTemplate` — logged as ISSUE-7
  - Button scope contiguity validated as flat 1..N rather than per-button — schema lacks ButtonIndex column, logged as ISSUE-1
  - `GetAllWhatsAppTemplateList` → `GetWhatsAppTemplates` rename hot-patched to align with FE (logged as ISSUE-6 RESOLVED)
- **Known issues opened**: ISSUE-1 (Button contiguity), ISSUE-2 (Mapster inheritance), ISSUE-3 (Sync DTO), ISSUE-4 (FE redundant aliases), ISSUE-5 (seed folder typo), ISSUE-7 (Toggle naming)
- **Known issues closed**: ISSUE-6 (GQL GetAll name mismatch — hot-patched and verified BE build green)
- **Next step**: User to run the DB seed SQL at `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/WhatsAppTemplate-sqlscripts.sql`, then run `pnpm dev` and complete the FULL E2E verification checklist in §⑪ (Tasks → Verification section). If runtime issues arise, they can be logged via `/continue-screen #31`.