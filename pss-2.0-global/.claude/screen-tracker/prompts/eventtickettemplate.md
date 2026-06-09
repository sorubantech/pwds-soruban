---
screen: EventTicketTemplate
registry_id: 176
module: CRM (Event)
status: IN_PROGRESS
scope: FULL
screen_type: FLOW
display_mode: card-grid
card_variant: iframe
complexity: Medium
new_module: NO — uses existing `app` schema / ApplicationModels group (DbContext=ContactDbContext, sibling to Event Ticketing #46)
planned_date: 2026-06-08
---

## Tasks

### Planning (by /plan-screens)
- [x] Reference screen analyzed (mirror Email Template #24 FLOW: card-grid list + editor; reuse the TipTap editor)
- [x] Existing code reviewed (NEW table; reuse `EmailTemplateEditor` + `PlaceholderDefinition` + `placeholderDefinitions` GQL query; no mockup — pattern-cloned from #24)
- [x] Business rules + status lifecycle extracted (Draft/Active/Inactive via StatusId FK)
- [x] FK targets resolved (MasterData EVENTTEMPLATESTATUS, PlaceholderDefinition EntityType='EventTicket')
- [x] File manifest computed (FULL new stack in `app`/ApplicationModels, FE under contact-service)
- [x] Approval config pre-filled (CRM_EVENT, OrderBy 5)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt §①–⑫ authoritative; sibling refs verified in codebase)
- [x] Solution Resolution complete (FLOW + card-grid iframe + reuse editor stamped §⑤)
- [x] UX Design finalized (2-pane editor: form+editor LEFT / live preview RIGHT)
- [x] User Approval received (2026-06-09 — Sonnet agents, CONFIG as-is)
- [ ] Backend code generated (new entity + CQRS + schemas + validators + endpoints) — **USER-OWNED (user is building BE)**
- [ ] Backend wiring (IContactDbContext / ContactDbContext / DecoratorProperties / ApplicationMappings) — **USER-OWNED**
- [x] Frontend code generated (page-config + index-page card-grid + view-page editor + DTO + GQL)
- [x] Frontend wiring (entity-operations, route, pages barrel)
- [ ] DB Seed script generated (menu + EVENTTEMPLATESTATUS MasterData + EventTicket placeholder rows + GridFormSchema SKIP) — **USER-OWNED (BE-side seed)**
- [ ] EF migration created (DEFERRED to user per house rule)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/crm/event/eventtickettemplate`
- [ ] Card grid renders with iframe HTML thumbnails (reuses BUILT iframe variant from #24)
- [ ] Each card: iframe preview, template name, status badge (Draft/Active/Inactive), modified date, 3-dot menu
- [ ] Search + status filter work above the grid
- [ ] "+New Template" → `?mode=new` → empty editor (Name empty, Status=Draft)
- [ ] Card click → `?mode=read&id={id}` → editor in read mode (disabled fields, preview live)
- [ ] `?mode=edit&id=X` → pre-filled editor
- [ ] LEFT pane: Name, Subject, Status segmented toggle, Description, `EmailTemplateEditor` (HtmlContent)
- [ ] Placeholder panel shows ONLY EventTicket tokens (`defaultEntityType="EventTicket"`)
- [ ] Placeholder chip click inserts `{{token}}` at cursor in the editor
- [ ] RIGHT pane: live preview iframe (Desktop/Mobile toggle), re-renders on edit (debounced)
- [ ] Save (new) → `createEventTicketTemplate` → redirect `?mode=read&id={newId}`
- [ ] Save (edit) → `updateEventTicketTemplate`
- [ ] Status toggle persists DRAFT/ACTIVE/INACTIVE (StatusId FK)
- [ ] Delete (card menu) → soft delete → returns to grid
- [ ] Unsaved-changes dialog on dirty navigate
- [ ] DB Seed — menu "Ticket Templates" visible under CRM → Events → OrderBy 5
- [ ] DB Seed — MasterData typeCode EVENTTEMPLATESTATUS present (DRAFT/ACTIVE/INACTIVE)
- [ ] DB Seed — PlaceholderDefinition rows EntityType='EventTicket' present

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **EventTicketTemplate** (a.k.a. Ticket Templates)
Module: **CRM → Event** (Menu parent: CRM_EVENT)
Schema: **`app`** (existing — Event Ticketing #46 lives here)
Group: **`ApplicationModels`** (same namespace as Event/EventTicket; DbContext = **ContactDbContext**, per the Event #40 / EventTicketing #46 precedent)

Business: Event Ticket Templates is where event organizers author the **ticket / receipt artifact** that a registered donor receives after they buy a ticket. Each template is a reusable, company-scoped HTML document with merge-field placeholders (`{{EventName}}`, `{{TicketName}}`, `{{TicketPrice}}`, `{{RegistrantName}}`, `{{QRCode}}`, …) that are resolved at send-time. The screen deliberately **reuses the existing Email Template authoring experience**: the same TipTap `EmailTemplateEditor` component, the same `PlaceholderDefinition` catalog (scoped to a new `EntityType='EventTicket'`), and the same `IEmailTemplateService` render path — it is NOT a new parallel editor. The LIST view is a scannable **card grid** with live HTML thumbnails (reusing the `iframe` card variant first built for Email Template #24). The EDIT view is a 2-pane editor: form fields + rich editor on the LEFT, live preview iframe on the RIGHT.

**Relationship to Event Ticketing #46**: this is the master list a ticket points at. In a **separate** `/plan-screens #46` revision, `app.EventTickets` gains a nullable FK `EventTemplateId → EventTicketTemplate`, selected per ticket type in #46's Ticket Form card. That FK + selector is **NOT part of this build** — this prompt only creates the template screen.

**Out of scope (explicit)**: actual delivery (payment-success → email the receipt+ticket) is handled elsewhere and is NOT built here. This screen is template **creation + management** only.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> ONE new table in the existing `app` schema. Audit columns (CreatedBy/CreatedDate/ModifiedBy/ModifiedDate/IsActive/IsDeleted) inherited from `Entity` base — NOT listed.

### Table — `app.EventTicketTemplates` (NEW)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| EventTicketTemplateId | int | — | PK | — | Primary key |
| EventTicketTemplateCode | string | 50 | YES | — | Auto-gen `EVT-TMPL-{NNNN}` per Company if empty; unique per CompanyId |
| EventTicketTemplateName | string | 150 | YES | — | Display name, e.g. "Gala VIP Ticket" |
| CompanyId | int | — | YES | auth/Company | Tenant scoping (template is company-level, NOT per-event) |
| Subject | string | 250 | YES | — | Ticket-email subject line; may contain placeholders |
| HtmlContent | string (text) | — | YES | — | Rich HTML body authored in `EmailTemplateEditor`; used for iframe thumbnail + live preview |
| Description | string | 500 | NO | — | Internal notes about the template |
| StatusId | int | — | YES | com.MasterDatas (typeCode=`EVENTTEMPLATESTATUS`) | DRAFT / ACTIVE / INACTIVE — mirror #46's StatusId-FK convention |

> **Note**: NO `EventId` column — a template is reusable across events and chosen per ticket type. The event linkage happens on the consuming side (`EventTickets.EventTemplateId`).
> **Note**: `CompanyId` IS on this entity (unlike #46's per-event tables) because templates are company-scoped, like `notify.EmailTemplates`.
> **Decision (Solution Resolver)**: a derived `statusName` (joined `MasterData.dataName`) and `statusBadge` string are projected in the response DTO so the card renders one badge without FE recomputation. Mirror EmailTemplate #24's `emailContentTypeName`/`statusBadge` projection approach.

**Child entities**: NONE (placeholders are NOT per-template junction rows here — the editor reads the shared `PlaceholderDefinition` catalog by `EntityType`. Do NOT create an `EventTicketTemplatePlaceholder` junction).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (.Include() / nav props) + Frontend Developer (ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query | Display Field | Response Type |
|----------|--------------|-------------------|-----------|---------------|---------------|
| StatusId | MasterData (typeCode=`EVENTTEMPLATESTATUS` — NEW type seed) | PSS_2.0_Backend/.../Base.Domain/Models/SettingModels/MasterData.cs | `masterDatas` (filter typeCode=`EVENTTEMPLATESTATUS`) | dataName | MasterDataResponseDto |
| CompanyId | Company | PSS_2.0_Backend/.../Base.Domain/Models/AuthModels/Company.cs | (scoped via HttpContext — not a user-facing select) | — | — |

**Placeholder source** (editor sidebar — NOT an FK; the query the editor fires):
| Purpose | GQL Query | File | Filter |
|---------|-----------|------|--------|
| Fetch EventTicket placeholders for the editor panel | `placeholderDefinitions` | PSS_2.0_Frontend/src/infrastructure/gql-queries/notify-queries/PlaceholderDefinitionQuery.ts (existing) | `EntityType = 'EventTicket'` (via `defaultEntityType` prop) |

> **IMPORTANT — mirror the sibling, do not guess the MasterData schema/handler.** Per `[[feedback_masterdata_lookup_mirror_sibling]]`: grep an existing #46 status lookup (e.g. EVENTTICKETSTATUS handler/seed) and copy its exact `DataValue` shape, schema reference (`com` vs `setting`), and `IsDeleted` filtering. Do NOT invent the schema or filter `IsDeleted == false` (it's `bool?` and hides seeded NULL rows).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness:**
- `EventTicketTemplateCode` unique per `CompanyId` (auto-generated `EVT-TMPL-{NNNN}` if blank — mirror #46's `EVT-TKT-{NNNN}` generation).

**Required:**
- `EventTicketTemplateName`, `Subject`, `HtmlContent`, `StatusId` mandatory.
- `Description` nullable.

**Status lifecycle (StatusId FK → MasterData EVENTTEMPLATESTATUS):**
- New template defaults to **DRAFT**.
- DRAFT → ACTIVE (publish), ACTIVE ↔ INACTIVE (enable/disable). No hard state machine beyond these.
- Only **ACTIVE** templates should be selectable in #46's Ticket-Form template dropdown (the #46 revision filters by StatusId=ACTIVE — note for the downstream prompt, not enforced here).

**Content:**
- `HtmlContent` stores raw HTML from the editor.
- `Subject` and `HtmlContent` may contain `{{Placeholder}}` tokens — NO server-side validation that placeholders exist (resolved at send-time by `IEmailTemplateService`).

**Workflow**: None beyond the 3-state status.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — PRE-ANSWERED.

**Screen Type**: FLOW (view-page with 3 URL modes: `?mode=new` / `?mode=edit&id=X` / `?mode=read&id=X`)
**Display Mode**: `card-grid`, **Card Variant**: `iframe` (REUSE the variant built for Email Template #24 — do NOT rebuild it)
**Reason**: Templates are recognized by what they look like (HTML preview), and "+New" opens a full editor with a live-preview pane — too rich for a modal. Direct clone of the Email Template #24 FLOW pattern, simplified (no Design/Settings tabs).

**Backend Patterns Required (FULL — new stack):**
- [x] Standard CRUD (Create, Update, Delete soft, ToggleStatus/Activate-Deactivate)
- [x] Tenant scoping via CompanyId (HttpContext filter — mirror EmailTemplate)
- [x] Auto-code generation (`EVT-TMPL-{NNNN}` per Company)
- [x] Unique validation — Code per Company
- [x] Single FK validation (StatusId)
- [x] Paginated list query with derived `statusName`/`statusBadge` projection
- [ ] NO child-entity management (no junction table)
- [ ] NO file upload
- [ ] NO summary widgets (mockup/pattern has no count cards)

**Frontend Patterns Required (FULL):**
- [x] index-page in `card-grid` mode + `cardVariant: iframe` (reuse `iframe-card.tsx`)
- [x] view-page.tsx with 3 URL modes
- [x] 2-pane editor: LEFT form+editor / RIGHT live preview
- [x] **REUSE `EmailTemplateEditor`** with `defaultEntityType="EventTicket"` — do NOT fork
- [x] Placeholder panel fed by `placeholderDefinitions` filtered to EntityType='EventTicket'
- [x] Status segmented toggle (Draft/Active/Inactive) — reuse `StatusSegmentedToggle` if present (created in #24), else a simple 3-segment control
- [x] Live preview iframe (Desktop/Mobile toggle) — reuse `LivePreviewPane` from #24 if compatible, else a minimal iframe `srcDoc` renderer
- [x] React Hook Form + Zustand store
- [x] Unsaved-changes dialog

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> No HTML mockup — this screen is pattern-cloned from Email Template #24. Match #24's shape, minus the Design and Settings tabs.

### Grid/List View

**Display Mode** (stamped): `card-grid` · **Card Variant** (stamped): `iframe`

**Card Config:**
```yaml
cardConfig:
  variant: "iframe"
  htmlField: "htmlContent"                # rich HTML in sandboxed iframe thumbnail
  headerField: "eventTicketTemplateName"  # template title overlay
  metaFields: ["statusBadge"]             # Draft/Active/Inactive chip
  fallbackSnippetField: "description"      # plain-text fallback if HTML empty/oversized
  maxHtmlBytes: 100000
```

- **REUSE** `card-grid/variants/iframe-card.tsx` (already real, built for #24). Do NOT touch the `<CardGrid>` shell or the variant file — just supply the config.
- `statusBadge` is a derived response field (`"Draft" | "Active" | "Inactive"` from StatusId/MasterData) — projected server-side.

**Grid Layout Variant** (REQUIRED): `grid-only` → FE Dev uses **Variant A** (`<AdvancedDataTable>` internal header, NO `ScreenHeader`).

**Toolbar / Filter Bar** (standard AdvancedDataTable toolbar):

| Control | Type | Behaviour |
|---------|------|-----------|
| Search input | text | name / subject / description |
| Status filter | select | Draft / Active / Inactive / All (from masterDatas EVENTTEMPLATESTATUS) |
| "+New Template" | button | → `?mode=new` |

**Card Row Actions** (3-dot `RowActionMenu`):
- Edit → `?mode=edit&id={id}`
- Preview → full-size iframe modal (reuse preview pane)
- Delete → `deleteEventTicketTemplate` (soft)

**Responsive**: 1 col (xs) → 2 (sm) → 3 (lg) → 4 (xl). Card body click → `?mode=read&id={id}`.
**Widgets / Summary Cards**: NONE. **Grid Aggregation Columns**: NONE.

For card rendering the list DTO must include: `eventTicketTemplateId`, `eventTicketTemplateName`, `eventTicketTemplateCode`, `htmlContent`, `description`, `statusBadge`, `modifiedOn`, `createdOn`.

---

### FLOW View-Page — 3 URL Modes & UI Layouts

> ONE editor UI (2-pane). READ mode reuses the SAME layout with fields disabled — the live preview is the point of read mode (same exception as #24).

#### LAYOUT 1: FORM (mode=new & mode=edit) — and ALSO mode=read (fields disabled)

**Page Header (editor-header):**

Left cluster:
- Back button (← → grid list, no params)
- **Editable title input** (`EventTicketTemplateName`) — large bold inline-edit
- **Status segmented toggle** (3-segment): Draft (amber) / Active (green) / Inactive (slate)

Right cluster:
- **Save** (primary → `createEventTicketTemplate` / `updateEventTicketTemplate`)
- **Preview** (outline → full-size preview modal)

In READ mode: controls disabled, Save hidden, "Edit" button shown → `?mode=edit&id=X`.

**Section Container**: split pane (flex row) — LEFT 60% (form + editor), RIGHT 40% (live preview).

**LEFT pane — fields (top-to-bottom, single column, NO tabs):**

| Field | Widget | Validation | Notes |
|-------|--------|------------|-------|
| Subject | text input (`FormInput`) | required | "Ticket email subject…"; placeholders allowed |
| Description | textarea 3 rows (`FormInput`/`FormTextarea`) | max 500 | "Internal notes…" |
| HtmlContent | **`EmailTemplateEditor`** (TipTap) | required | `value={htmlContent}` `onChange` `defaultEntityType="EventTicket"` `placeholders={eventTicketPlaceholders}` — REUSE, do not fork |

> Use the canonical form-field components (`FormInput`/`FormSelect`/`FormTextarea`) per `[[feedback_reuse_canonical_form_fields]]`. Do NOT hand-roll inputs.

**Placeholder Insertion Panel** (rendered by / alongside `EmailTemplateEditor`):
- Tokens come from `placeholderDefinitions` filtered to `EntityType='EventTicket'`.
- Seeded EventTicket tokens (see §⑧ seed): `{{EventName}}`, `{{EventDate}}`, `{{EventVenue}}`, `{{TicketName}}`, `{{TicketPrice}}`, `{{TicketCode}}`, `{{RegistrantName}}`, `{{RegistrantEmail}}`, `{{QRCode}}`, `{{OrgName}}`, `{{OrgLogo}}`.
- Chip click inserts the token at the cursor (handled by the editor).

**RIGHT pane — Live Preview:**
- Header: "Live Preview" + Device toggle (Desktop 600px / Mobile 375px).
- Body: iframe `srcDoc` = current `htmlContent` with sample placeholder values substituted.
- Sandbox: `sandbox="allow-same-origin"` (no scripts). Re-render debounced 300ms on content change.
- REUSE `LivePreviewPane` from #24 if its props fit; otherwise a minimal local iframe renderer.

**Special Form Widgets**: Card Selector — N/A. Conditional Sub-forms — N/A. Inline Mini Display — N/A. Child Grids — N/A.

#### LAYOUT 2: DETAIL (mode=read)
**Status**: "No separate detail layout — use editor layout with fields disabled (`<fieldset disabled>`)." Right-pane preview stays live. Save hidden; Edit button → `?mode=edit&id=X`.

### User Interaction Flow
1. Land on `/crm/event/eventtickettemplate` → card grid, iframe thumbnails lazy-load.
2. Filter Status="Active" / search "VIP" → results refresh.
3. "+New Template" → `?mode=new` → empty editor (Title="New Template", Status=Draft).
4. Fill Subject, type HTML body, insert `{{RegistrantName}}` from placeholder panel → preview updates live.
5. Save → `createEventTicketTemplate` → redirect `?mode=read&id={newId}`.
6. Edit → `?mode=edit&id={id}` re-enables. Back with dirty form → unsaved-changes dialog.
7. From grid, click a card → `?mode=read&id={id}`.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Canonical FLOW reference: **EmailTemplate #24** (closest pattern — card-grid iframe + editor) and **EventTicket #46** (same schema/group/context).

| Canonical (EmailTemplate) | → EventTicketTemplate | Context |
|---------------------------|----------------------|---------|
| EmailTemplate | EventTicketTemplate | Entity/class name |
| emailTemplate | eventTicketTemplate | Variable/field names |
| EmailTemplateId | EventTicketTemplateId | PK |
| EmailTemplates | EventTicketTemplates | Table / collection |
| emailtemplate | eventtickettemplate | FE folder, route, import paths (NO dash — match #24/#46 convention) |
| EMAILTEMPLATE | EVENTTICKETTEMPLATE | Grid code, menu code |
| notify | **app** | DB schema (DIFFERENT — sits with Event, not Notify) |
| Notify / NotifyModels | **ApplicationModels** | Backend group / namespace |
| NotifyDbContext | **ContactDbContext** | DbContext (per #46/#40 precedent) |
| CRM_COMMUNICATION | **CRM_EVENT** | Parent menu code |
| notify-service | **contact-service** | FE service folder (per #46) |
| crm/communication/emailtemplate | crm/event/eventtickettemplate | FE route path |

---

## ⑧ File Manifest

> **Consumer**: Backend + Frontend Developer. FULL new stack. Follow the EmailTemplate #24 / EventTicketing #46 file layout exactly for paths.

### Backend Files — CREATE
| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | Entity | Base.Domain/Models/ApplicationModels/EventTicketTemplate.cs | New entity + `Create()` factory |
| 2 | EF Config | Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventTicketTemplateConfiguration.cs | Table `app.EventTicketTemplates`; MaxLen 50/150/250/500; HtmlContent as text; StatusId FK `.OnDelete(Restrict)`; CompanyId index; unique (CompanyId, EventTicketTemplateCode) |
| 3 | Schemas (DTOs) | Base.Application/Schemas/ApplicationSchemas/EventTicketTemplateSchemas.cs | RequestDto + ResponseDto (+ derived `statusName`, `statusBadge`) |
| 4 | Create | Base.Application/Business/ApplicationBusiness/EventTicketTemplates/CreateEventTicketTemplate.cs | Map, auto-code, default StatusId=DRAFT, CompanyId from HttpContext |
| 5 | Update | .../EventTicketTemplates/UpdateEventTicketTemplate.cs | Map, status change |
| 6 | Delete | .../EventTicketTemplates/DeleteEventTicketTemplate.cs | Soft delete |
| 7 | ActivateDeactivate | .../EventTicketTemplates/ActivateDeactivateEventTicketTemplate.cs | Toggle StatusId ACTIVE↔INACTIVE |
| 8 | GetEventTicketTemplates | .../EventTicketTemplates/GetEventTicketTemplates.cs | Paginated; project HtmlContent, statusName, statusBadge; tenant filter |
| 9 | GetEventTicketTemplateById | .../EventTicketTemplates/GetEventTicketTemplateById.cs | Single projection |
| 10 | Validators | co-located or Base.Application/Validators/... | Required + unique-code validation (mirror #46) |
| 11 | Queries endpoint | Base.API/EndPoints/Application/Queries/EventTicketTemplateQueries.cs | `eventTicketTemplates`, `eventTicketTemplateById` |
| 12 | Mutations endpoint | Base.API/EndPoints/Application/Mutations/EventTicketTemplateMutation.cs | create/update/delete/activateDeactivate |

> Verify exact folder names against the #46 EventTicket build (ApplicationBusiness / ApplicationSchemas / EndPoints/Application paths) — mirror them precisely; the names above are the expected convention.

### Backend Wiring Updates
| # | File | What to Add |
|---|------|-------------|
| 1 | IContactDbContext.cs | `DbSet<EventTicketTemplate> EventTicketTemplates` |
| 2 | ContactDbContext.cs | DbSet + `ApplyConfiguration(new EventTicketTemplateConfiguration())` |
| 3 | DecoratorProperties.cs | Register EventTicketTemplate if #46 entities are registered there |
| 4 | ApplicationMappings.cs | Mapster rules (request↔entity, statusName join) |

### Backend Files — DEFER
| # | File | Note |
|---|------|------|
| 1 | EF Migration | **DO NOT create.** Per `[[feedback_user_creates_migrations]]` the user runs `dotnet ef migrations add` manually. Make only compiling entity/config changes. |

### Frontend Files — CREATE
| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | DTO | src/domain/entities/contact-service/EventTicketTemplateDto.ts | Request/Response DTOs (+ statusBadge) |
| 2 | GQL Query | src/infrastructure/gql-queries/contact-queries/EventTicketTemplateQuery.ts | list + byId (list selects htmlContent, statusBadge, description, modifiedOn) |
| 3 | GQL Mutation | src/infrastructure/gql-mutations/contact-mutations/EventTicketTemplateMutation.ts | create/update/delete/activateDeactivate |
| 4 | Page Config | src/presentation/pages/crm/event/eventtickettemplate.tsx | Access guard; pass displayMode=card-grid, cardVariant=iframe, cardConfig |
| 5 | Index Page | src/presentation/components/page-components/crm/event/eventtickettemplate/index-page.tsx | AdvancedDataTable card-grid (Variant A); status filter + search; onCardClick → `?mode=read&id`; row actions |
| 6 | View Page | .../crm/event/eventtickettemplate/view-page.tsx | 2-pane editor: LEFT form (`FormInput` Subject/Description) + `EmailTemplateEditor`; RIGHT live preview; status toggle; header Save/Preview; unsaved-changes dialog |
| 7 | Page shell (router) | .../crm/event/eventtickettemplate/event-ticket-template-page.tsx | Mode router (mirror #24's email-template-page shell) |
| 8 | Zustand store | src/application/stores/event-ticket-template-stores/event-ticket-template-store.ts | currentTemplate, previewDevice, statusMode, dirty |
| 9 | Route Page | src/app/[lang]/crm/event/eventtickettemplate/page.tsx | Next route entry |

### Frontend Files — REUSE (do NOT recreate)
| File | Why |
|------|-----|
| EmailTemplateEditor.tsx | The TipTap editor — pass `defaultEntityType="EventTicket"`. Do NOT fork. |
| card-grid/variants/iframe-card.tsx | Built in #24 — supply config only. |
| LivePreviewPane.tsx (#24) | Reuse if props fit; else minimal local iframe. |
| StatusSegmentedToggle.tsx (#24) | Reuse the 3-segment status control. |
| placeholderDefinitions query | Existing — filter EntityType='EventTicket'. |
| FlowDataTable / AdvancedDataTable | Per `[[feedback_reuse_existing_grids]]` — never fork the grid. |

### Frontend Wiring Updates
| # | File | What to Add |
|---|------|-------------|
| 1 | entity-operations.ts | EVENTTICKETTEMPLATE operation config (mirror EMAILTEMPLATE) |
| 2 | operations-config.ts | Register if required |
| 3 | pages barrel / route registry | Add eventtickettemplate page-config export |
| 4 | sidebar nav | Menu seeded via DB (no FE nav edit if menu-driven) |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase.

```
---CONFIG-START---
Scope: FULL

MenuName: Ticket Templates
MenuCode: EVENTTICKETTEMPLATE
ParentMenu: CRM_EVENT
Module: CRM
MenuUrl: crm/event/eventtickettemplate
OrderBy: 5
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: EVENTTICKETTEMPLATE
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer. Follow `[[feedback_hc_naming_conventions]]` (HC strips `Get`; C# param name = GQL arg name; `request` param for paginated list).

**GraphQL Types**: Query `EventTicketTemplateQueries`, Mutation `EventTicketTemplateMutation`.

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| eventTicketTemplates | Paginated `[EventTicketTemplateResponseDto]` | `request: { searchText, pageNo/pageIndex, pageSize, sortField, sortDir, statusId }` — match #46's `GridFeatureRequest` wrapper shape per `[[feedback_gridfeature_asparameters_wrapper]]` |
| eventTicketTemplateById | EventTicketTemplateResponseDto | eventTicketTemplateId |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| createEventTicketTemplate | EventTicketTemplateRequestDtoInput | Int! (new id — bare `data`, no subfields per `[[feedback_baseapiresponse_int_scalar_data]]`) |
| updateEventTicketTemplate | EventTicketTemplateRequestDtoInput | Int! |
| deleteEventTicketTemplate | eventTicketTemplateId | Int! |
| activateDeactivateEventTicketTemplate | eventTicketTemplateId | Int! |

**Response DTO Fields:**
| Field | Type | Notes |
|-------|------|-------|
| eventTicketTemplateId | number | PK |
| eventTicketTemplateName | string | title |
| eventTicketTemplateCode | string | unique per company |
| subject | string | placeholders allowed |
| htmlContent | string | HTML — iframe + preview |
| description | string? | — |
| statusId | number | FK MasterData |
| statusName | string | joined MasterData.dataName |
| statusBadge | string | derived `"Draft" \| "Active" \| "Inactive"` |
| isActive | boolean | inherited |
| createdOn | string (ISO) | inherited |
| modifiedOn | string (ISO) | inherited |

> Round-trip hygiene: `toRequest()` must strip `__typename` recursively (`[[feedback_apollo_typename_strip_on_round_trip]]`) and discard response-only display fields (`statusName`, `statusBadge`) per `[[feedback_response_only_fields_leak_into_request]]`.

---

## ⑪ Acceptance Criteria

**Build:**
- [ ] `dotnet build` — no errors (migration created by USER, not agent)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/event/eventtickettemplate`

**Functional (E2E):**
- [ ] Card grid renders at all breakpoints with iframe thumbnails
- [ ] Search + Status filter work
- [ ] Card shows iframe preview, name, status badge, modified date, 3-dot menu (Edit/Preview/Delete)
- [ ] `?mode=new` → empty editor, Status=Draft, Title="New Template"
- [ ] 2-pane: LEFT form+editor / RIGHT live preview
- [ ] `EmailTemplateEditor` renders; placeholder panel shows ONLY EventTicket tokens
- [ ] Placeholder chip inserts `{{token}}` at cursor
- [ ] Live preview re-renders on content change (debounced); Desktop/Mobile toggle changes width
- [ ] Status segmented toggle persists DRAFT/ACTIVE/INACTIVE
- [ ] Save (new) → `?mode=read&id={newId}`; Save (edit) → updates
- [ ] Read mode: inputs disabled, preview live, Edit replaces Save
- [ ] Delete (card menu) → soft delete → returns to grid
- [ ] Unsaved-changes dialog on dirty navigate
- [ ] Permissions: BUSINESSADMIN sees all actions

**DB Seed:**
- [ ] Menu "Ticket Templates" under CRM → Events, OrderBy 5
- [ ] MasterData typeCode `EVENTTEMPLATESTATUS` seeded: DRAFT, ACTIVE, INACTIVE
- [ ] PlaceholderDefinition rows EntityType='EventTicket' seeded (11 tokens listed §⑥)
- [ ] GridFormSchema = SKIP (FLOW — no form schema row)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — easy-to-get-wrong items.

**Reuse, do NOT fork (the whole point of this screen):**
- **`EmailTemplateEditor` is reused as-is** with `defaultEntityType="EventTicket"`. Do NOT copy/fork the editor, its toolbar, or its hooks. If a prop is missing for the EventTicket case, extend the shared component minimally — don't clone it.
- **`iframe-card.tsx`, `LivePreviewPane`, `StatusSegmentedToggle`** were built for Email Template #24 — reuse, supply config only. Do NOT touch the `<CardGrid>` shell.
- **PlaceholderDefinition catalog is shared** (`notify.PlaceholderDefinitions`). EventTicket tokens are NEW rows with `EntityType='EventTicket'` — a DATA seed, NOT a schema change and NOT a per-template junction.

**Schema / context placement:**
- Entity lives in **`app` schema / ApplicationModels group / ContactDbContext** — NOT in `notify`. This is required so the downstream `EventTickets.EventTemplateId` FK (the #46 revision) is intra-context. Mirror EventTicket #46's exact namespaces/paths.
- Watch `[[feedback_nested_git_repos]]` and `[[feedback_agent_sibling_worktree_drift]]`: verify changes land in `pwds-soruban - Copy/` and `cd` into PSS_2.0_Backend / PSS_2.0_Frontend to confirm git status.

**MasterData lookup:**
- `[[feedback_masterdata_lookup_mirror_sibling]]` — grep an existing #46 status handler before writing the EVENTTEMPLATESTATUS lookup; copy the exact schema (`com`/`setting`), DataValue strings, and avoid the `IsDeleted == false` NULL trap.

**Migration:**
- `[[feedback_user_creates_migrations]]` — make compiling entity/config changes only; the USER runs `dotnet ef migrations add` and updates the snapshot. Do NOT edit `ApplicationDbContextModelSnapshot.cs`.

**PostgreSQL:**
- `[[project_postgresql_db]]` — seed SQL uses `now()`, double-quoted identifiers, `TRUE/FALSE`, `WHERE NOT EXISTS`, `LIMIT 1`.

**Downstream (NOT in this build):**
- The `app.EventTickets.EventTemplateId` FK + the Ticket-Form template selector are a **separate `/plan-screens #46` revision**. Do not add that FK here. See `[[project_event_ticket_template_screen]]`.
- Delivery (payment-success → email receipt+ticket) is OUT of scope.

**Menu home decision:**
- Placed under **CRM → Event** (next to Event Ticketing #46) rather than CRM → Communication (where Email/SMS/WhatsApp templates live), because ticket templates are event-domain and consumed per ticket type in #46. If the team prefers grouping all templates under Communication, this is the one knob to flip (MenuCode/ParentMenu/MenuUrl in §⑨).

---

## ⑬ Build Log

### § Known Issues

| ID | Severity | Description | Status |
|----|----------|-------------|--------|
| (none) | — | — | — |

### § Sessions

### Session 1 — 2026-06-09 — BUILD — PARTIAL (FE-only; BE user-owned)

- **Scope**: Frontend-only build. User elected to build the Backend + DB seed themselves; orchestrator generated the full FE stack against the §⑩ contract. UX/Solution analysis taken from prompt §⑤/§⑥ (validated against codebase — sibling refs confirmed present). Sonnet FE Developer, single spawn, no stall.
- **Files touched**:
  - FE (created): `src/domain/entities/contact-service/EventTicketTemplateDto.ts`; `src/infrastructure/gql-queries/contact-queries/EventTicketTemplateQuery.ts`; `src/infrastructure/gql-mutations/contact-mutations/EventTicketTemplateMutation.ts`; `src/application/stores/event-ticket-template-stores/event-ticket-template-store.ts` (+ `index.ts`); `src/presentation/components/page-components/crm/event/eventtickettemplate/{index-page,view-page,event-ticket-template-page,index}.tsx`; `src/presentation/pages/crm/event/eventtickettemplate.tsx`; `src/app/[lang]/crm/event/eventtickettemplate/page.tsx`
  - FE (modified/wiring): `domain/entities/contact-service/index.ts`; `gql-queries/contact-queries/index.ts`; `gql-mutations/contact-mutations/index.ts`; `presentation/pages/crm/event/index.ts`; `application/configs/data-table-configs/contact-service-entity-operations.ts` (EVENTTICKETTEMPLATE block)
  - BE: NONE this session (user-owned).
  - DB: NONE this session (seed is BE-side, user-owned).
- **Verification**: `npx tsc --noEmit` ZERO new errors. UI-uniformity grep ZERO matches (no inline hex/px, no raw "Loading...", no bootstrap card). Layout Variant `grid-only` → Variant A confirmed: `index-page.tsx` uses `FlowDataTable` (shared grid) card-grid+iframe, NO `ScreenHeader`. iframe-card / EmailTemplateEditor / LivePreviewPane / StatusSegmentedToggle all REUSED (not forked).
- **Reused components** (no fork): `EmailTemplateEditor` (`defaultEntityType="EventTicket"`), `card-grid/variants/iframe-card.tsx`, `email/LivePreviewPane.tsx`, `form/StatusSegmentedToggle.tsx`, `placeholderDefinitions` query, `FlowDataTable`, `FormInput`/`FormTextarea`.
- **⚠️ BE→FE CONTRACT THE USER'S BE MUST MATCH** (FE is already wired to these — BE must conform or runtime 400/500s):
  - List query: `eventTicketTemplates(request: { pageSize, pageIndex, sortDescending, sortColumn, searchTerm, advancedFilter })` — the **standard GridFeatureRequest wrapper** (same as EmailTemplate `emailTemplates`), NOT EventTicket's `allEventTicketList` multi-arg shape.
  - ById: `eventTicketTemplateById(eventTicketTemplateId: Int!)`.
  - Mutations: `createEventTicketTemplate` / `updateEventTicketTemplate` take input arg named **`eventtickettemplate`** (HC-lowercased C# param) of type `EventTicketTemplateRequestDtoInput`; `deleteEventTicketTemplate` / `activateDeactivateEventTicketTemplate` take `eventTicketTemplateId`. ALL return **bare `data` (Int!)** — no subfields (BaseApiResponse<int>). → BE create/update C# param should be named `eventTicketTemplate`; delete/toggle param `eventTicketTemplateId`.
  - Response DTO fields selected by FE: `eventTicketTemplateId, eventTicketTemplateCode, eventTicketTemplateName, subject, htmlContent, description, statusId, statusName, statusBadge, isActive, createdOn, modifiedOn`. List query selects `htmlContent` (iframe thumb) + `statusBadge`/`statusName`.
- **Deviations from spec**: None material. `LivePreviewPane` reused as-is (no `preheader`/`design` config — those are email-specific); pane renders with its defaults. List uses the standard `request:` wrapper (matches §⑩ "mirror the wrapper shape").
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: USER to build Backend (entity `app.EventTicketTemplates` + CQRS + endpoints, mirroring EmailTemplate #24 shape in `app`/ApplicationModels/ContactDbContext per §⑦/§⑫) conforming to the contract above; create DB seed `eventtickettemplate-sqlscripts.sql` (§⑪ — menu/caps/roles + EVENTTEMPLATESTATUS MasterData + 11 EventTicket PlaceholderDefinition rows + GridFormSchema SKIP); run `dotnet ef migrations add` + `database update` + execute seed. Then full E2E per §⑪ and flip registry to COMPLETED.

### Session 2 — 2026-06-09 — FIX — PARTIAL (FE align to user-built BE + ticket UX)

- **Scope**: User built the BE themselves and ran the seed. This session aligned the FE to the actual BE DTO, reworked placeholders to real columns, and made the preview ticket-shaped (not page-shaped).
- **Files touched**:
  - FE (modified): `gql-queries/contact-queries/EventTicketTemplateQuery.ts` (list + byId now select `createdDate`/`modifiedDate`); `domain/entities/contact-service/EventTicketTemplateDto.ts` (response fields + `toRequest()` discard list `createdDate`/`modifiedDate`); `custom-components/email/LivePreviewPane.tsx` (NEW optional `variant="email"|"ticket"` prop + ticket sample values; ticket variant renders raw HTML, NO header/body/footer chrome — shared comp, default unchanged so EmailTemplate #24 unaffected); `page-components/crm/event/eventtickettemplate/view-page.tsx` (both `LivePreviewPane` usages pass `variant="ticket"`).
  - DB (modified): `sql-scripts-dyanmic/EventTicketTemplate-sqlscripts.sql` — placeholder block reworked to **Event + EventRegistration columns ONLY** (8 EventReg + 9 Event = 17 tokens; EntityType kept `'EventTicket'` so the editor filter still surfaces them); obsolete EventTicket/Company-derived tokens (TicketName/Price/Code, OrgName/Logo, QRCode/EventDate/EventVenue/EventName old codes) DEACTIVATED via UPDATE. **User re-runs this seed.**
  - DOC (created): `.claude/screen-tracker/docs/event-ticket-template-samples.html` — 2 ready-to-paste ticket designs using only the new tokens.
- **Root causes fixed**:
  - GQL error "field `createdOn`/`modifiedOn` does not exist on EventTicketTemplateResponseDto" → BE DTO exposes `CreatedDate`/`ModifiedDate` (→ `createdDate`/`modifiedDate`). Read from `EventTicketTemplateSchemas.cs`, not assumed.
- **Deviations**: Earlier in session I assumption-edited the seed's placeholder MasterData lookups to `app."MasterData"`/`DataCode`/`FORMATTYPE`; user flagged the original `sett."MasterDatas"`/`DataValue`/`PLACEHOLDERFORMAT`/`CONTACT` lookups as the valid already-executed ones — REVERTED. Lookups left as user's executed version.
- **Known issues opened**: None. **Known issues closed**: None.
- **Next step**: User re-runs `EventTicketTemplate-sqlscripts.sql` (placeholder deactivation + 17 new tokens are idempotent). Verify editor panel shows only Event/EventRegistration tokens; verify ticket preview has no email page chrome. Then full E2E per §⑪ and flip registry to COMPLETED.
