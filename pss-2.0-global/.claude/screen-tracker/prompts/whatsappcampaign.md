---
screen: WhatsAppCampaign
registry_id: 32
module: Communication
status: PROMPT_READY
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-20
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (list view + 3-step wizard FORM + Campaign Report DETAIL)
- [x] Existing code reviewed (FE stub only at `crm/whatsapp/whatsappcampaign/page.tsx`; no BE entity)
- [x] Business rules + workflow extracted (Draft → Scheduled → Sending → Sent; Active ↔ Paused for auto campaigns)
- [x] FK targets resolved (WhatsAppTemplate confirmed in NotifyModels; GetAllWhatsAppTemplate → `whatsAppTemplates`)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (3-step wizard FORM + Campaign Report DETAIL layouts)
- [ ] User Approval received
- [ ] Backend code generated
- [ ] Backend wiring complete (INotifyDbContext, NotifyDbContext, NotifyMappings)
- [ ] Frontend code generated (index-page with widgets+table, view-page with 3-step wizard + report, Zustand store)
- [ ] Frontend wiring complete
- [ ] DB Seed script generated (GridFormSchema: SKIP for FLOW)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/{lang}/crm/whatsapp/whatsappcampaign`
- [ ] 4 KPI widgets render above grid (Campaigns Sent, Messages Sent, Read Rate, Reply Rate) — Variant B (ScreenHeader + showHeader={false})
- [ ] Grid loads with 11 columns (Campaign Name, Template, Status, Recipients, Sent, Delivered, Read, Replied, Cost, Date, Actions) with rate-bar renderers for Delivered/Read
- [ ] Status badges render 4 variants: Active (green dot), Sent (green check), Scheduled (blue calendar), Draft (grey file)
- [ ] Row actions are status-driven: Sent → View Report + Duplicate; Scheduled → Edit + Cancel; Draft → Edit + Delete; Active → View Log + Pause; Paused → View Log + Resume
- [ ] `?mode=new` — empty 3-step wizard renders: Step 1 (Setup) → Step 2 (Audience) → Step 3 (Review & Send) with step-progress indicator at top
- [ ] Wizard Step 1 — Campaign Name, Type card-selector (Broadcast/Automated), Template dropdown (ApiSelectV2 — GetAllWhatsAppTemplate), Template Preview bubble, Schedule card-selector (Send Now/Schedule) with conditional date+time+timezone picker
- [ ] Wizard Step 2 — Recipient Source card-selector (5 cards), Audience Preview mini-display (5 rows: Total, With WhatsApp, Opted-in, Already messaged, Net), Exclusions (3 checkboxes with conditional inputs), Cost & Tier info cards (2 cards with live calc)
- [ ] Wizard Step 3 — Campaign Summary table, Pre-send Checklist (6 items), Template Preview, Save Draft + Send Now buttons, Send Confirmation modal
- [ ] Next/Back navigation between steps preserves form state; step indicator updates (active/completed styling)
- [ ] `?mode=edit&id=X` — wizard loads pre-filled with existing data; can navigate between steps
- [ ] `?mode=read&id=X` — Campaign Report DETAIL layout renders (delivery funnel + 2-col breakdown + recipients table — NOT disabled wizard)
- [ ] Delivery funnel shows 4 steps with arrows: Sent → Delivered (%) → Read (%) → Replied (%)
- [ ] Delivery Breakdown card: 3 rows (Read, Delivered not read, Failed) with failure reasons note in red
- [ ] Button Click Stats card: table with Button | Clicks | % of Read
- [ ] Reply Analysis card: 3 colored stat cards (Positive, Questions, Opt-out)
- [ ] Recipients card: table with Contact link, Phone, Status icon, Delivered, Read, Replied badge, Reply Text — "View All Replies" button navigates to WhatsApp Conversations
- [ ] Create flow: +Add → wizard → Send Now → confirm modal → POST create + dispatch send → redirects to `?mode=read&id={newId}` → Report layout (zeroed metrics initially)
- [ ] Save Draft creates campaign with status=Draft and stays on wizard (or exits to list)
- [ ] Cancel (scheduled) and Pause/Resume (automated) mutations work
- [ ] Unsaved-changes dialog triggers on back/navigate with dirty wizard
- [ ] Service placeholder toasts: Send Now dispatch, Pause/Resume, webhook-driven metrics — all show "service not wired yet"
- [ ] DB Seed — WhatsApp Campaigns menu visible under CRM → WhatsApp

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: WhatsAppCampaign
Module: Communication
Schema: notify
Group: NotifyModels (colocated with WhatsAppTemplate #31, SMSTemplate #29, EmailTemplate #24)

Business: The WhatsApp Campaign screen lets Communication Admins create and track one-time broadcasts or automated (event-triggered) WhatsApp message blasts to opted-in contacts. Each campaign selects an approved WhatsApp Template (#31), picks an audience (saved segment, saved filter, tag, imported list, or all opted-in), applies opt-out/rate-limit exclusions, and either sends now or schedules for future. After send, the screen shows real-time delivery metrics (Sent → Delivered → Read → Replied funnel) with per-recipient breakdowns, button-click stats, and reply analysis so admins can gauge campaign performance. It is the **sibling of SMS Campaign (#30)** and the **consumer of WhatsApp Template (#31)**. The "Active (Auto)" rows model system-triggered campaigns (donation receipts, pledge reminders, failed-payment alerts) that link to the Automation Workflow screen (#45). Row click opens a **Campaign Report** — a read-only analytics page that is distinctly different from the create wizard.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Audit columns (CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, CompanyId, IsActive) inherited from Entity base — NOT listed below.
> **CompanyId is NOT a field column** — FLOW screens get tenant from HttpContext.

Table: notify."WhatsAppCampaigns"

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| WhatsAppCampaignId | int | — | PK | — | Primary key |
| CampaignName | string | 200 | YES | — | Display name (unique per Company) |
| CampaignType | string | 20 | YES | — | "Broadcast" \| "Automated" |
| WhatsAppTemplateId | int | — | YES | notify.WhatsAppTemplates | FK — only Approved templates allowed |
| RecipientSourceType | string | 20 | YES | — | "SavedSegment" \| "SavedFilter" \| "Tag" \| "ImportList" \| "AllOptedIn" |
| RecipientSourceRef | string | 500 | NO | — | Stores ID of segment/filter/tag or imported-file reference (nullable for AllOptedIn) |
| ExcludeStopReplied | bool | — | YES | — | Default TRUE — exclude contacts who sent STOP |
| ExcludeRecentlyMessaged | bool | — | YES | — | Default FALSE |
| RecentlyMessagedHours | int | — | NO | — | Required when ExcludeRecentlyMessaged=TRUE |
| ExcludeTagId | int | — | NO | corg.Tags | Optional — exclude contacts with this tag |
| ScheduleType | string | 20 | YES | — | "SendNow" \| "Scheduled" |
| ScheduledDate | DateTime | — | NO | — | Required when ScheduleType=Scheduled |
| ScheduledTimezone | string | 60 | NO | — | IANA timezone string (e.g., "Asia/Dubai") |
| Status | string | 30 | YES | — | "Draft" \| "Scheduled" \| "Sending" \| "Sent" \| "Active" \| "Paused" \| "Cancelled" \| "Failed" |
| RecipientCount | int | — | YES | — | Resolved count at send time (default 0) |
| SentCount | int | — | YES | — | Default 0 |
| DeliveredCount | int | — | YES | — | Default 0 |
| ReadCount | int | — | YES | — | Default 0 |
| RepliedCount | int | — | YES | — | Default 0 |
| FailedCount | int | — | YES | — | Default 0 |
| FailedReasonsJson | string | max | NO | — | JSON dict of failure reason → count (e.g., `{"InvalidNumber":23,"NotOnWhatsApp":18,"RateLimited":14}`) |
| EstimatedCost | decimal(18,2) | — | NO | — | Calculated at step 2 |
| ActualCost | decimal(18,2) | — | NO | — | Populated after send completes |
| CostPerMessage | decimal(18,4) | — | NO | — | Rate snapshot at send time |
| SentDate | DateTime | — | NO | — | When send started |
| CompletedDate | DateTime | — | NO | — | When all recipients processed |
| AutomationWorkflowId | int | — | NO | notify.AutomationWorkflows | FK — set for Automated campaigns (future module; nullable for now) |

**Child Entities** (1:Many via WhatsAppCampaignId):

| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| WhatsAppCampaignRecipient | Per-contact send record | ContactId (FK corg.Contacts), PhoneNumber (snapshot), Status, SentAt, DeliveredAt, ReadAt, RepliedAt, ReplyText, FailureReason |
| WhatsAppCampaignButtonClick | Per-button click event | ContactId, ButtonLabel, ButtonValue, ClickedAt |

**Table: notify."WhatsAppCampaignRecipients"**

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| WhatsAppCampaignRecipientId | int | — | PK | — | — |
| WhatsAppCampaignId | int | — | YES | notify.WhatsAppCampaigns | Parent |
| ContactId | int | — | YES | corg.Contacts | — |
| PhoneNumber | string | 25 | YES | — | Snapshot at send time |
| Status | string | 20 | YES | — | "Queued" \| "Sent" \| "Delivered" \| "Read" \| "Replied" \| "Failed" |
| SentAt | DateTime | — | NO | — | — |
| DeliveredAt | DateTime | — | NO | — | — |
| ReadAt | DateTime | — | NO | — | — |
| RepliedAt | DateTime | — | NO | — | — |
| ReplyText | string | 1000 | NO | — | — |
| ReplySentiment | string | 20 | NO | — | "Positive" \| "Question" \| "OptOut" — server-classified |
| FailureReason | string | 200 | NO | — | — |

**Table: notify."WhatsAppCampaignButtonClicks"**

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| WhatsAppCampaignButtonClickId | int | — | PK | — | — |
| WhatsAppCampaignId | int | — | YES | notify.WhatsAppCampaigns | Parent |
| ContactId | int | — | YES | corg.Contacts | — |
| ButtonLabel | string | 100 | YES | — | — |
| ButtonValue | string | 500 | NO | — | Url/phone/payload |
| ClickedAt | DateTime | — | YES | — | — |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| WhatsAppTemplateId | WhatsAppTemplate | Base.Domain/Models/NotifyModels/WhatsAppTemplate.cs | GetAllWhatsAppTemplate → returns `whatsAppTemplates` | TemplateName | WhatsAppTemplateResponseDto |
| ExcludeTagId | Tag | Base.Domain/Models/CorgModels/Tag.cs | GetAllTag → returns `tags` | TagName | TagResponseDto |
| ContactId (on child) | Contact | Base.Domain/Models/CorgModels/Contact.cs | GetAllContact → returns `contacts` | FirstName + " " + LastName (or ContactName) | ContactResponseDto |
| AutomationWorkflowId | AutomationWorkflow | (not yet built — #45 Wave 4) | N/A | N/A | N/A — nullable; gated behind `CampaignType=Automated` |

**Approved-only filter for WhatsAppTemplate**: the Step-1 template dropdown must filter client-side by `status === "Approved"`. Backend query already returns `status` — no new query needed.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `CampaignName` must be unique per Company (excluding soft-deleted records)

**Required Field Rules:**
- `CampaignName`, `CampaignType`, `WhatsAppTemplateId`, `RecipientSourceType`, `ScheduleType`, `Status` are mandatory
- `ExcludeStopReplied` defaults to TRUE (server-side default if omitted)

**Conditional Rules:**
- If `CampaignType = "Automated"` → `AutomationWorkflowId` required (v2) and `ScheduleType` must be "SendNow"; status auto-set to "Active"
- If `RecipientSourceType ∈ {SavedSegment, SavedFilter, Tag}` → `RecipientSourceRef` required (must be numeric ID)
- If `RecipientSourceType = "ImportList"` → `RecipientSourceRef` required (file reference)
- If `RecipientSourceType = "AllOptedIn"` → `RecipientSourceRef` must be NULL
- If `ScheduleType = "Scheduled"` → `ScheduledDate` + `ScheduledTimezone` required; `ScheduledDate` must be ≥ now + 5 minutes
- If `ExcludeRecentlyMessaged = TRUE` → `RecentlyMessagedHours` required, between 1 and 168 (1 week cap)
- WhatsAppTemplate referenced MUST have `status = "Approved"` — reject on Create/Update

**Business Logic:**
- `RecipientCount`, `EstimatedCost`, `CostPerMessage` populated server-side at Step-2 preview via `GetWhatsAppCampaignAudiencePreview` query
- `ActualCost = CostPerMessage × SentCount` (recomputed when send completes)
- Audit metrics (`SentCount`, `DeliveredCount`, `ReadCount`, `RepliedCount`, `FailedCount`) ONLY mutated by webhook-driven service (SERVICE_PLACEHOLDER — zero'd until service exists)
- On `SendNow`: set `Status=Sending`, persist, enqueue send job (SERVICE_PLACEHOLDER), return campaign ID; admin redirects to Report view
- Duplicate action: clone campaign with `Status=Draft`, null all metrics, append " (copy)" to name
- Draft records may be freely edited; Sent/Sending records are immutable except for internal metrics updates

**Workflow:**
- States: `Draft → (Send Now) → Sending → Sent`
- States: `Draft → (Schedule) → Scheduled → (at scheduled time) → Sending → Sent`
- States: `Scheduled → (Cancel) → Cancelled`
- States (Automated): `Draft → (Activate) → Active ↔ Paused → (Deactivate) → Draft`
- Failed: terminal state when send job errors entirely

| Transition | From | To | Mutation | Notes |
|------------|------|-----|----------|-------|
| Save Draft | any editable | Draft | `CreateWhatsAppCampaign` / `UpdateWhatsAppCampaign` | Wizard Step 3 "Save Draft" button |
| Send Now | Draft | Sending | `SendWhatsAppCampaign(campaignId)` | Triggers SERVICE_PLACEHOLDER job |
| Schedule | Draft | Scheduled | `UpdateWhatsAppCampaign` (scheduleType=Scheduled) | Scheduler picks it up at time |
| Cancel | Scheduled | Cancelled | `CancelWhatsAppCampaign(campaignId)` | Only before send |
| Pause | Active | Paused | `PauseWhatsAppCampaign(campaignId)` | Automated only |
| Resume | Paused | Active | `ResumeWhatsAppCampaign(campaignId)` | Automated only |
| Send Complete | Sending | Sent | internal (webhook) | Populates ActualCost, CompletedDate |

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: Transactional workflow with **multi-step wizard FORM** + **distinct analytics DETAIL** view
**Reason**: "+Add" navigates to a full page (`?mode=new`) with a 3-step wizard (NOT a modal). Row click navigates to `?mode=read&id=X` which shows a read-only Campaign Report — a completely different UI from the wizard (delivery funnel + breakdown cards + recipients table).

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) for WhatsAppCampaign
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Nested child creation — WhatsAppCampaignRecipient (generated at send time, not user-editable)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 3: WhatsAppTemplate, Tag (optional), Contact (on recipients))
- [x] Unique validation — `CampaignName` per Company
- [x] Workflow commands (Send, Cancel, Pause, Resume, Duplicate) — 5 custom mutations
- [ ] File upload command — (Import List source type may need upload; defer as SERVICE_PLACEHOLDER)
- [x] Custom business rule validators — approved-template check, schedule-date future check, recipient-source consistency
- [x] Audience preview query — `GetWhatsAppCampaignAudiencePreview` (returns counts without persisting)
- [x] Summary query — `GetWhatsAppCampaignSummary` (4 widget KPIs)

**Frontend Patterns Required:**
- [x] FlowDataTable (grid with widgets-above-grid → **Variant B**: ScreenHeader + 4 widgets + DataTableContainer flow variant with showHeader={false})
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] **3-step wizard** inside FORM layout (new / edit): step-progress indicator + step-content cards + step state in React Hook Form
- [x] **Different DETAIL UI** (read mode = Campaign Report analytics page)
- [x] React Hook Form (for wizard FORM across 3 steps)
- [x] Zustand store (`whatsappcampaign-store.ts`) — persist wizard step + form values across back/forth
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (with Back, Cancel buttons; action buttons change per mode)
- [x] Card selectors (Step 1: Type + Schedule; Step 2: Recipient Source)
- [x] Conditional sub-forms (ScheduleType=Scheduled → date/time picker; SourceType → source-specific picker; Exclusions checkboxes with inline inputs)
- [x] Inline mini-display (Audience Preview card in Step 2)
- [x] Live cost calculation (Cost Estimate + Messaging Tier cards in Step 2)
- [x] Template preview bubble (WhatsApp chat bubble mock with body text from selected template)
- [x] Checklist (Step 3 pre-send checklist with success/warning icons)
- [x] Confirmation modal (Send Now → modal)
- [x] Workflow status badge (4 variants: Active green, Sent green, Scheduled blue, Draft grey)
- [x] Status-driven row actions (per-row action set depends on Status)
- [x] Grid cell renderer: **rate-bar** (for Delivered and Read columns — track + fill with count or percent)
- [x] Summary cards / count widgets above grid (4 KPI cards)
- [x] DETAIL layout: delivery funnel, breakdown tables, recipients table with navigation to WhatsApp Conversations
- [ ] Grid aggregation columns — N/A (aggregate metrics live on parent row)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.
> **CRITICAL**: FORM layout is a **3-step wizard**, not sections/accordions. DETAIL layout is a **Campaign Report analytics page**, not a disabled form.

### Grid/List View

**Display Mode**: `table` (dense transactional grid — NOT card-grid; 11 columns with rate-bar renderers)

**Grid Layout Variant**: `widgets-above-grid` → FE Dev MUST use **Variant B** (`<ScreenHeader>` + 4 widgets + `<DataTableContainer showHeader={false}>` flow variant)

**Grid Columns** (in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Campaign Name | campaignName | text (semibold, click → read mode) | 220px | YES | Row-click target |
| 2 | Template | templateName | monospace chip | 160px | YES | FK display (templateRef style) |
| 3 | Status | status | badge | 120px | YES | 4 variants: active/sent/scheduled/draft |
| 4 | Recipients | recipientCount | number OR "Auto" | 100px | YES | Show "Auto" when campaignType=Automated |
| 5 | Sent | sentCount | number | 80px | YES | "—" if 0 and status=Draft/Scheduled |
| 6 | Delivered | deliveredCount + deliveredPct | **rate-bar** (track+fill green + count) | 120px | NO | Custom cell renderer |
| 7 | Read | readCount + readPct | **rate-bar** (track+fill green + percentage) | 120px | NO | Custom cell renderer |
| 8 | Replied | repliedCount + repliedPct | text "234 (10.2%)" | 110px | YES | — |
| 9 | Cost | actualCost OR estimatedCost | currency | 100px | YES | Show "Est. $X" with italic prefix when status in Draft/Scheduled |
| 10 | Date | sentDate OR scheduledDate OR "Always" | smart-date | 100px | YES | "Always" for Automated campaigns |
| 11 | Actions | — | action-group | 160px | — | Status-driven set (see below) |

**Status-Driven Row Actions:**
| Status | Actions |
|--------|---------|
| Draft | Edit • Delete |
| Scheduled | Edit • Cancel |
| Sending | View Log (disabled edit) |
| Sent | View Report • Duplicate |
| Active (Auto) | View Log • Pause |
| Paused (Auto) | View Log • Resume |
| Cancelled | View Log • Duplicate |
| Failed | View Log • Duplicate |

**Search/Filter Fields**: campaignName (search), status (filter chip: Draft/Scheduled/Sent/Active/Paused), campaignType (Broadcast/Automated), date range, templateId

**Grid Actions**: View (→ read mode), Edit (→ edit mode with status gating), Delete (only Draft)

**Row Click**: Navigates to `?mode=read&id={id}` (Campaign Report DETAIL layout)

---

### Page Widgets & Summary Cards

**Widgets**: 4 KPI cards above grid (from mockup — extracts `stats-grid`)

| # | Widget Title | Value Source | Display Type | Position | Detail Line |
|---|-------------|-------------|-------------|----------|-------------|
| 1 | Campaigns Sent (Month) | `campaignsSentMonth` | number + WhatsApp icon (green bg) | grid col 1 | "This week: `campaignsSentWeek`" |
| 2 | Messages Sent (Month) | `messagesSentMonth` | number + paper-plane icon (blue bg) | grid col 2 | "Delivered: `deliveredPct`%" (green text) |
| 3 | Read Rate | `readRatePct` | percentage + check-double icon (green bg) | grid col 3 | "vs Email: `emailReadRatePct`% ↑ much higher" |
| 4 | Reply Rate | `replyRatePct` | percentage + reply icon (purple bg) | grid col 4 | "`totalReplies` replies" |

**Summary GQL Query**:
- Query name: `GetWhatsAppCampaignSummary`
- Returns: `WhatsAppCampaignSummaryDto { campaignsSentMonth, campaignsSentWeek, messagesSentMonth, deliveredPct, readRatePct, emailReadRatePct, replyRatePct, totalReplies }`
- Added to `WhatsAppCampaignQueries.cs` alongside `GetAll` and `GetById`

### Grid Aggregation Columns

**Aggregation Columns**: NONE (aggregate metrics live as scalar columns on the parent — no per-row subquery needed)

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

```
URL MODE                                        UI LAYOUT
──────────────────────────────────────────     ────────────────────────────────
/crm/whatsapp/whatsappcampaign?mode=new     →   FORM LAYOUT (empty 3-step wizard)
/crm/whatsapp/whatsappcampaign?mode=edit&id=X → FORM LAYOUT (pre-filled wizard)
/crm/whatsapp/whatsappcampaign?mode=read&id=X → DETAIL LAYOUT (Campaign Report)
```

---

#### LAYOUT 1: FORM (mode=new & mode=edit) — 3-Step Wizard

> **Critical**: This is NOT a single-page form with sections. It is a **3-step wizard** with step progress bar at the top, one step content card visible at a time, and Next/Back buttons in the footer. Form state is preserved across step transitions via React Hook Form + Zustand.

**Page Header**: FlowFormPageHeader with:
- Back button (returns to list, triggers unsaved-changes dialog if dirty)
- Title: "Create WhatsApp Campaign" (mode=new) or "Edit WhatsApp Campaign" (mode=edit)
- Cancel button (right, outlined)

**Step Progress Indicator** (at top of content area, in its own card):
- 3 step items + 2 connectors
- Step item = circled number + label; states: pending (grey border), active (accent bg), completed (green bg)
- Connector = 2px bar; becomes green when step before it is completed
- Labels: "Campaign Setup" | "Select Audience" | "Review & Send"

**Section Container Type**: single-step-card (one step-content-card visible at a time; `step-content-card` class from mockup)

---

##### STEP 1 — Campaign Setup

| Icon | Layout | Fields |
|------|--------|--------|
| fa-megaphone | single-column, max-width 640px | Campaign Name, Campaign Type, Template, Template Preview (visual), Schedule, (conditional) Scheduled Date/Time/Timezone |

| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| CampaignName | text | "e.g., Ramadan Appeal 2026" | required, max 200, unique/company | — |
| CampaignType | **card-selector** (2 cards) | — | required, default "Broadcast" | Broadcast (📢 "One-time bulk send") / Automated (🔄 "Triggered by system event — links to automation workflows") |
| WhatsAppTemplateId | ApiSelectV2 | "Select an approved template..." | required | Query: GetAllWhatsAppTemplate; **client-side filter status === "Approved"**; optionLabel `${templateName} (${category}, ${languageName})`; hint with "Manage Templates" link |
| (Template Preview) | **read-only WhatsApp bubble** | — | — | Renders selected template's `bodyPreview` with merge-tag placeholders replaced by sample values; footer with company name + "Reply STOP to unsubscribe"; rendered in mockup `.wa-preview-compact` / `.wa-bubble-compact` style |
| ScheduleType | **card-selector** (2 cards) | — | required, default "SendNow" | Send Now (🚀 "Campaign will be sent immediately") / Schedule (📅 "Pick a date, time, and timezone") |
| ScheduledDate | datetime-picker | "Pick date & time" | required-if ScheduleType=Scheduled; future +5min | Conditional visibility |
| ScheduledTimezone | select | "Select timezone" | required-if ScheduleType=Scheduled | IANA list; default to company timezone |

**Step 1 Footer**: "Next →" button only (right-aligned, primary-accent). No Back.

---

##### STEP 2 — Select Audience

| Icon | Layout | Fields |
|------|--------|--------|
| fa-users | single-column, max-width 640px | Recipient Source, Source-specific picker (conditional), Audience Preview (inline display), Exclusions (3 conditional checkboxes), Cost & Tier (2 info cards) |

| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| RecipientSourceType | **card-selector** (5 cards) | — | required, default "AllOptedIn" | 5 cards: Saved Segment (📋) • Saved Filter (🔍) • By Tag (🏷️) • Import List (📁) • All Opted-in (👥) |
| RecipientSourceRef | ApiSelectV2 / file-upload | — | required-if source ∈ {Segment, Filter, Tag, ImportList} | Widget varies by source: Segment → SegmentPicker (SERVICE_PLACEHOLDER if no segment module); Filter → GetAllSavedFilter; Tag → GetAllTag; Import → FileUpload (.csv/.xlsx; SERVICE_PLACEHOLDER for ingestion) |
| ExcludeStopReplied | checkbox | — | — | Default CHECKED; label "Exclude contacts who replied STOP" |
| ExcludeRecentlyMessaged | checkbox + inline number | — | number 1-168 if checked | Label: "Exclude recently messaged (within [N] hours)" — inline number input next to label |
| ExcludeTagId | checkbox + inline tag-select | — | required-if checkbox checked | Label: "Exclude tag: [dropdown]" — inline ApiSelectV2 (GetAllTag) |

**Inline Mini Display — Audience Preview** (re-calculated via `GetWhatsAppCampaignAudiencePreview` whenever source/exclusions change):

| Row | Label | Value | Style |
|-----|-------|-------|-------|
| 1 | Total Contacts | `{total}` | — |
| 2 | With WhatsApp number | `{withWhatsApp} ({withWhatsAppPct}%)` | — |
| 3 | Opted-in for WhatsApp | `{optedIn} ({optedInPct}%)` | — |
| 4 | Already messaged today | `{alreadyMessaged}` | warning color when > 0 |
| — (divider) | — | — | border-top, padded |
| 5 | **Net Recipients** | `{netRecipients}` | accent color, 1rem bold |

**Info Cards** (2-col grid below audience preview):

| Card | Style | Value | Subtext |
|------|-------|-------|---------|
| Cost Estimate | green bg (#f0fdf4), green border | `{estimatedCost}` (e.g., $172.80) | "`{netRecipients}` msgs × `{costPerMessage}`" |
| Messaging Tier | blue bg (#eff6ff), blue border | "✓ OK" (green check) OR "⚠ Limit" | "`{netRecipients}` of `{tierLimit}` remaining" |

**Step 2 Footer**: "← Back" (left, secondary) • "Next →" (right, primary-accent).

---

##### STEP 3 — Review & Send

| Icon | Layout | Fields |
|------|--------|--------|
| fa-paper-plane | 2-column (equal), max-width 900px | Left: Campaign Summary table + Pre-send Checklist. Right: Template Preview bubble |

**Left Column — Campaign Summary** (read-only 6-row table, `summary-table` style):
- Campaign → `{campaignName}`
- Type → `{campaignType}`
- Template → `{templateName}` chip (monospace) + "(`{category}`, `{language}`)"
- Recipients → `{netRecipients}` opted-in contacts
- Estimated Cost → `{estimatedCost}` (accent color)
- Schedule → "Send Now" OR `{scheduledDate}` formatted

**Left Column — Pre-send Checklist** (6 items, auto-computed on mount):
| # | Icon | Label | Computed From |
|---|------|-------|---------------|
| 1 | success ✓ / warning ⚠ | Template approved by Meta | selected template `.status === "Approved"` |
| 2 | success ✓ | Recipients selected (`{netRecipients}`) | netRecipients > 0 |
| 3 | success ✓ | All recipients opted-in for WhatsApp | always true once source resolved |
| 4 | success ✓ / warning ⚠ | Within messaging tier limit | netRecipients ≤ tierLimit |
| 5 | success ✓ / warning ⚠ | Budget sufficient (`{budgetRemaining}` remaining) | estimatedCost ≤ companyBudget.remaining (SERVICE_PLACEHOLDER — always shows success for now) |
| 6 | warning ⚠ | `{alreadyMessaged}` contacts messaged in last 24 hours (will still send) | only renders if alreadyMessaged > 0 |

**Right Column — Template Preview**:
- Same WhatsApp bubble as Step 1, re-rendered with final merge values

**Step 3 Footer**:
- "← Back" (left, secondary)
- Right-group: "Save Draft" (outlined-accent, icon fa-save) • "Send Now" (primary-accent, icon fa-paper-plane)

**Send Confirmation Modal** (triggered by Send Now button):
- Icon: fa-whatsapp + title "Confirm Campaign Send"
- Body: "You are about to send **`{netRecipients}`** WhatsApp messages. Estimated cost: **`{estimatedCost}`**. This action cannot be undone."
- Footer: "Cancel" (secondary) • "Confirm & Send" (primary-accent, icon fa-paper-plane)
- Confirm → dispatch `SendWhatsAppCampaign` → toast "Campaign queued" → redirect to `?mode=read&id={newId}`

**Card Selectors Details**:

| Card Group (Step) | Icon | Label | Description | Triggers |
|-------------------|------|-------|-------------|----------|
| Type (Step 1) | 📢 | Broadcast | One-time bulk send to selected audience | — |
| Type (Step 1) | 🔄 | Automated | Triggered by system event (links to automation workflows) | Hides ScheduleType cards; adds AutomationWorkflow selector (SERVICE_PLACEHOLDER — workflow module not built) |
| Schedule (Step 1) | 🚀 | Send Now | Campaign will be sent immediately | Hides ScheduledDate/Timezone |
| Schedule (Step 1) | 📅 | Schedule | Pick a date, time, and timezone | Shows ScheduledDate + Timezone |
| Source (Step 2) | 📋 | Saved Segment | — | Shows Segment picker (SERVICE_PLACEHOLDER) |
| Source (Step 2) | 🔍 | Saved Filter | — | Shows SavedFilter ApiSelectV2 |
| Source (Step 2) | 🏷️ | By Tag | — | Shows Tag ApiSelectV2 |
| Source (Step 2) | 📁 | Import List | — | Shows file-upload (SERVICE_PLACEHOLDER for ingestion) |
| Source (Step 2) | 👥 | All Opted-in | — | No extra picker; sets ref to NULL |

**Special Form Widgets**:

- **Card Selector** (4 groups in wizard as above)
- **Conditional Sub-forms** (3 triggers as above)
- **Inline Mini Display** (Audience Preview card)
- **Live Computed Fields** (Cost Estimate, Messaging Tier, Pre-send Checklist all auto-recompute via debounced GetAudiencePreview call)
- **Read-only Visual Bubble** (Template Preview — styled per mockup's `.wa-preview-compact`)

**Wizard State Management**:
- `currentStep: 1 | 2 | 3` in Zustand store
- React Hook Form holds ALL fields across steps (never unmounted when switching steps — use conditional `display: none` on step-content cards)
- Validation on Next: trigger validation only for fields in the current step; block Next if invalid
- Back: unconditional, no validation
- Unsaved changes: store tracks `isDirty` from RHF; back-button/router navigation triggers confirm dialog

---

#### LAYOUT 2: DETAIL (mode=read) — Campaign Report

> Completely different UI from the wizard. Analytics view with funnel, breakdown cards, and recipients table.

**Page Header**: FlowFormPageHeader (custom layout per mockup `.page-header` report-view):
- Top line: "← Back to Campaigns" link (accent color, small)
- H1: `{campaignName}`
- Subtitle (small, grey): "Template: `{templateName}` chip | Sent: `{sentDate}` formatted | Recipients: `{recipientCount}`"

**Header Actions** (right side):
- Sent status → Duplicate button
- Scheduled status → Edit + Cancel
- Active (Automated) → Pause + View Log
- Paused → Resume + View Log

**Page Layout**: 3 vertical sections, full-width:

##### Section 1 — Delivery Funnel (horizontal funnel card)

Single card, flex row with arrows between 4 funnel steps:

| Step | Value | Label | Pct (conditional, green) |
|------|-------|-------|--------------------------|
| 1 | `{sentCount}` | Sent | — |
| → | (arrow) | — | — |
| 2 | `{deliveredCount}` | Delivered | `{deliveredPct}%` |
| → | (arrow) | — | — |
| 3 | `{readCount}` | Read | `{readPct}%` |
| → | (arrow) | — | — |
| 4 | `{repliedCount}` | Replied | `{repliedPct}%` |

Card: white bg, 1.25rem padding, flex center wrap, gap 0.5rem. Each funnel-step: f8fafc bg, 0.75rem padding, 0.5rem radius, min-width 120px, centered text.

##### Section 2 — 2-Column Breakdown Grid

| Column | Width | Cards |
|--------|-------|-------|
| Left | 1fr | Delivery Breakdown |
| Right | 1fr | Button Click Stats + Reply Analysis |

**Left Card — Delivery Breakdown** (step-content-card style):
- Title: "Delivery Breakdown"
- Table: 3 rows
  - Row 1: `fa-check-double` blue icon + "Read" | `{readCount}` | `{readPct}%` (green)
  - Row 2: `fa-check` grey icon + "Delivered (not read)" | `{deliveredCount - readCount}` | `{(deliveredCount - readCount)/sentCount * 100}%`
  - Row 3: `fa-times-circle` red icon + "Failed" | `{failedCount}` | `{failedPct}%` (red)
- Failure-reasons note (below table): pink bg (#fef2f2), 0.5rem padding, 0.375rem radius, 0.6875rem text, dark red — "Failed reasons: `{failedReasonsJson}`" formatted as "Invalid number (23), Not on WhatsApp (18), Rate limited (14)"

**Right Card — Button Click Stats + Reply Analysis** (step-content-card style):
- Section 1 (title "Button Click Stats"):
  - Table: Button | Clicks | % of Read
  - Rows from `WhatsAppCampaignButtonClicks` aggregate — e.g., `"Donate Now"` | 456 | 23.3%
  - Empty state: "No button clicks yet" (italic grey)
- Section 2 (title "Reply Analysis", 1.5rem top margin):
  - 3 colored stat mini-cards (flex row, gap 0.75rem, flex-wrap):
    - Positive (green bg #f0fdf4, green text) — `{positiveCount}` + "Positive (`{positivePct}`%)"
    - Questions (blue bg #eff6ff, blue text) — `{questionCount}` + "Questions (`{questionPct}`%)"
    - Opt-out (red bg #fef2f2, red text) — `{optOutCount}` + "Opt-out (`{optOutPct}`%)"

##### Section 3 — Recipients Table (list-card)

Header (card top):
- Title: "Recipients"
- Right button: "View All Replies" (outline-accent, icon fa-comments) → navigates to `/crm/whatsapp/whatsappconversation?campaignId={id}`

Table (7 cols, min-width 900px):

| # | Column | Field | Renderer | Notes |
|---|--------|-------|----------|-------|
| 1 | Contact | `contactName` | link (accent) → contact detail | navigate to `/crm/contact/allcontacts?mode=read&id={contactId}` |
| 2 | Phone | `phoneNumber` | monospace grey | — |
| 3 | Status | `status` | icon + label | Read (fa-check-double blue) / Delivered (fa-check grey) / Failed (fa-times-circle red) / Queued / Replied |
| 4 | Delivered | `deliveredAt` | smart-datetime | "Apr 1, 10:01" or "—" |
| 5 | Read | `readAt` | smart-datetime | same |
| 6 | Replied | `repliedAt / status` | badge "Yes"/"No" (or "—") | sent-badge style |
| 7 | Reply Text | `replyText` | italic grey | "JazakAllah Khair" / "—" / "Not on WhatsApp" (red if failed) |

Recipients paginated (50 per page); backend returns paginated recipients via `GetWhatsAppCampaignRecipients(campaignId, pageNo, pageSize)` or embed in GetById.

### User Interaction Flow (FLOW — 3 modes, 2 UI layouts)

1. User lands on `/crm/whatsapp/whatsappcampaign` → sees 4 KPI widgets + FlowDataTable grid
2. User clicks "+Add" → URL: `?mode=new` → **FORM LAYOUT** (empty 3-step wizard, step 1 active)
3. User fills Step 1 → clicks Next → validation runs → Step 2 loads (pre-fetch audience preview)
4. User selects source + exclusions → preview recomputes → cost estimate updates → Next → Step 3
5. User reviews summary + checklist → clicks Save Draft → POST create with Status=Draft → redirect to list (or stay on step 3 with "Saved" toast)
6. OR clicks Send Now → modal confirm → API sends → Status=Sending → redirect to `?mode=read&id={newId}` → **DETAIL LAYOUT** (Campaign Report, zeroed metrics initially)
7. From grid: user clicks campaign name → URL: `?mode=read&id=X` → **DETAIL LAYOUT**
8. From report: user clicks header Duplicate → clones → redirects to `?mode=edit&id={clonedId}` → **FORM LAYOUT** (wizard pre-filled, Step 1 active)
9. From report: user clicks "View All Replies" → navigates to WhatsApp Conversations screen with campaign filter
10. Cancel (Scheduled): confirm dialog → API cancel → refresh list
11. Pause/Resume (Automated): inline action → API mutation → row refresh
12. Unsaved changes: any navigation with dirty wizard → confirm dialog

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity (SavedFilter) to WhatsAppCampaign.

**Canonical Reference**: SavedFilter (FLOW)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | WhatsAppCampaign | Entity/class name |
| savedFilter | whatsAppCampaign | Variable/field names |
| SavedFilterId | WhatsAppCampaignId | PK field |
| SavedFilters | WhatsAppCampaigns | Table name, collection names |
| saved-filter | whatsapp-campaign | kebab-case (component file names) |
| savedfilter | whatsappcampaign | FE folder, import paths |
| SAVEDFILTER | WHATSAPPCAMPAIGN | Grid code, menu code |
| notify | notify | DB schema (unchanged — NotifyModels group houses all messaging entities) |
| Notify | Notify | Backend group name (Models/Schemas/Business/Mappings — all Notify) |
| NotifyModels | NotifyModels | Namespace suffix |
| CRM_COMMUNICATION | CRM_WHATSAPP | Parent menu code |
| CRM | CRM | Module code (unchanged) |
| crm/communication/savedfilter | crm/whatsapp/whatsappcampaign | FE route path |
| notify-service | **whatsapp-service** | FE DTO folder (WhatsApp-specific — see existing `whatsapp-service/WhatsAppTemplateDto.ts`) |
| notify-queries | **whatsapp-queries** | FE GQL query folder (see existing `whatsapp-queries/WhatsAppTemplateQuery.ts`) |
| notify-mutations | **whatsapp-mutations** | FE GQL mutation folder |

> **⚠ Folder-naming trap**: BE uses `Notify` group (all messaging entities share it), FE splits into `whatsapp-*` / `notify-*` / `sms-*` folders per channel. Copy the WhatsAppTemplate #31 precedent: BE under `Notify`, FE DTOs in `whatsapp-service`, GQL in `whatsapp-queries` + `whatsapp-mutations`, page-components under `crm/whatsapp/whatsappcampaign`.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files (15 files — parent + 2 children + 5 workflow mutations)

**Parent — WhatsAppCampaign:**
| # | File | Path |
|---|------|------|
| 1 | Entity | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/NotifyModels/WhatsAppCampaign.cs |
| 2 | EF Config | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/NotifyConfigurations/WhatsAppCampaignConfiguration.cs |
| 3 | Schemas (DTOs) | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/NotifySchemas/WhatsAppCampaignSchemas.cs |
| 4 | Create Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/NotifyBusiness/WhatsAppCampaigns/CreateCommand/CreateWhatsAppCampaign.cs |
| 5 | Update Command | PSS_2.0_Backend/.../WhatsAppCampaigns/UpdateCommand/UpdateWhatsAppCampaign.cs |
| 6 | Delete Command | PSS_2.0_Backend/.../WhatsAppCampaigns/DeleteCommand/DeleteWhatsAppCampaign.cs |
| 7 | Toggle Command | PSS_2.0_Backend/.../WhatsAppCampaigns/ToggleCommand/ToggleWhatsAppCampaign.cs |
| 8 | GetAll Query | PSS_2.0_Backend/.../WhatsAppCampaigns/GetAllQuery/GetAllWhatsAppCampaign.cs |
| 9 | GetById Query | PSS_2.0_Backend/.../WhatsAppCampaigns/GetByIdQuery/GetWhatsAppCampaignById.cs |
| 10 | Summary Query | PSS_2.0_Backend/.../WhatsAppCampaigns/GetSummaryQuery/GetWhatsAppCampaignSummary.cs |
| 11 | Audience Preview Query | PSS_2.0_Backend/.../WhatsAppCampaigns/GetAudiencePreviewQuery/GetWhatsAppCampaignAudiencePreview.cs |
| 12 | Workflow Commands (5 in one file) | PSS_2.0_Backend/.../WhatsAppCampaigns/WorkflowCommand/WhatsAppCampaignWorkflowCommands.cs (Send / Cancel / Pause / Resume / Duplicate) |
| 13 | Mutations endpoint | PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Notify/Mutations/WhatsAppCampaignMutations.cs |
| 14 | Queries endpoint | PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Notify/Queries/WhatsAppCampaignQueries.cs |

**Children — WhatsAppCampaignRecipient + WhatsAppCampaignButtonClick** (persisted via parent Create/GetById; no standalone CRUD mutations — they are server-managed):
| # | File | Path |
|---|------|------|
| 15 | Entity (Recipient) | Base.Domain/Models/NotifyModels/WhatsAppCampaignRecipient.cs |
| 16 | EF Config (Recipient) | .../Configurations/NotifyConfigurations/WhatsAppCampaignRecipientConfiguration.cs |
| 17 | Entity (ButtonClick) | Base.Domain/Models/NotifyModels/WhatsAppCampaignButtonClick.cs |
| 18 | EF Config (ButtonClick) | .../Configurations/NotifyConfigurations/WhatsAppCampaignButtonClickConfiguration.cs |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | `DbSet<WhatsAppCampaign>` + `DbSet<WhatsAppCampaignRecipient>` + `DbSet<WhatsAppCampaignButtonClick>` properties (via INotifyDbContext) |
| 2 | INotifyDbContext.cs | Add 3 DbSet properties |
| 3 | NotifyDbContext.cs | Add 3 DbSet properties + apply configs |
| 4 | DecoratorProperties.cs | Add WhatsAppCampaign + child entries in DecoratorNotifyModules |
| 5 | NotifyMappings.cs | Mapster mappings for WhatsAppCampaign ↔ RequestDto / ResponseDto / SummaryDto; child DTOs; inverse-include recipients in GetById |
| 6 | WhatsAppTemplate.cs | Add `public ICollection<WhatsAppCampaign>? Campaigns { get; set; }` navigation (for back-ref/count queries) |
| 7 | Contact.cs | Add `public ICollection<WhatsAppCampaignRecipient>? WhatsAppCampaignRecipients { get; set; }` navigation |
| 8 | Tag.cs | Add `public ICollection<WhatsAppCampaign>? ExcludedFromCampaigns { get; set; }` navigation |

### Frontend Files (11 files — view-page + Zustand + wizard helpers)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | PSS_2.0_Frontend/src/domain/entities/whatsapp-service/WhatsAppCampaignDto.ts |
| 2 | GQL Query | PSS_2.0_Frontend/src/infrastructure/gql-queries/whatsapp-queries/WhatsAppCampaignQuery.ts |
| 3 | GQL Mutation | PSS_2.0_Frontend/src/infrastructure/gql-mutations/whatsapp-mutations/WhatsAppCampaignMutation.ts |
| 4 | Page Config | PSS_2.0_Frontend/src/presentation/pages/crm/whatsapp/whatsappcampaign.tsx |
| 5 | Index Page entry | PSS_2.0_Frontend/src/presentation/components/page-components/crm/whatsapp/whatsappcampaign/index.tsx |
| 6 | Index Page Component (widgets + grid) | PSS_2.0_Frontend/src/presentation/components/page-components/crm/whatsapp/whatsappcampaign/index-page.tsx |
| 7 | **View Page (3 modes, wizard + report)** | PSS_2.0_Frontend/src/presentation/components/page-components/crm/whatsapp/whatsappcampaign/view-page.tsx |
| 8 | **Zustand Store** | PSS_2.0_Frontend/src/presentation/components/page-components/crm/whatsapp/whatsappcampaign/whatsappcampaign-store.ts |
| 9 | Wizard Step Progress component | .../whatsappcampaign/step-progress.tsx |
| 10 | Campaign Report component | .../whatsappcampaign/campaign-report.tsx |
| 11 | WhatsApp Preview Bubble (REUSE from #31 if exported; else copy) | .../whatsappcampaign/whatsapp-preview.tsx OR import from whatsapptemplate |
| 12 | Recipients Table subcomponent | .../whatsappcampaign/recipients-table.tsx |
| 13 | Rate Bar cell renderer | Pss2.0_Frontend/src/presentation/components/shared/data-table/cell-renderers/rate-bar-cell.tsx (**NEW shared** — check registry first) |
| 14 | Route Page (REWRITE stub) | PSS_2.0_Frontend/src/app/[lang]/crm/whatsapp/whatsappcampaign/page.tsx (currently `<div>Need to Develop</div>`) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | WHATSAPPCAMPAIGN operations config (GetAll, GetById, Create, Update, Delete, Toggle, Send, Cancel, Pause, Resume, Duplicate, GetSummary, GetAudiencePreview) |
| 2 | operations-config.ts | Import + register WhatsAppCampaign operations |
| 3 | sidebar menu config | Menu entry under CRM → WhatsApp (order 2, after Templates) |
| 4 | gql-queries/whatsapp-queries/index.ts | Export WhatsAppCampaignQuery |
| 5 | gql-mutations/whatsapp-mutations/index.ts | Export WhatsAppCampaignMutation |
| 6 | domain/entities/whatsapp-service/index.ts | Export WhatsAppCampaignDto types |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens per MODULE_MENU_REFERENCE.md.

```
---CONFIG-START---
Scope: FULL

MenuName: WhatsApp Campaigns
MenuCode: WHATSAPPCAMPAIGN
ParentMenu: CRM_WHATSAPP
Module: CRM
MenuUrl: crm/whatsapp/whatsappcampaign
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: WHATSAPPCAMPAIGN
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `WhatsAppCampaignQueries`
- Mutation type: `WhatsAppCampaignMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetAllWhatsAppCampaign → `whatsAppCampaigns` | GridFeatureResult<WhatsAppCampaignResponseDto> | searchText, pageNo, pageSize, sortField, sortDir, isActive, status, campaignType, templateId, dateFrom, dateTo |
| GetWhatsAppCampaignById → `whatsAppCampaign` | WhatsAppCampaignResponseDto (with recipients + buttonClicks embedded) | whatsAppCampaignId |
| GetWhatsAppCampaignSummary → `whatsAppCampaignSummary` | WhatsAppCampaignSummaryDto | — |
| GetWhatsAppCampaignAudiencePreview → `whatsAppCampaignAudiencePreview` | WhatsAppCampaignAudiencePreviewDto | recipientSourceType, recipientSourceRef?, excludeStopReplied, excludeRecentlyMessaged, recentlyMessagedHours?, excludeTagId?, whatsAppTemplateId |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| CreateWhatsAppCampaign | WhatsAppCampaignRequestDto | int (new ID) |
| UpdateWhatsAppCampaign | WhatsAppCampaignRequestDto | int |
| DeleteWhatsAppCampaign | whatsAppCampaignId | int |
| ToggleWhatsAppCampaign | whatsAppCampaignId | int |
| SendWhatsAppCampaign | whatsAppCampaignId | int (campaignId; SERVICE_PLACEHOLDER — no real job dispatched) |
| CancelWhatsAppCampaign | whatsAppCampaignId | int |
| PauseWhatsAppCampaign | whatsAppCampaignId | int |
| ResumeWhatsAppCampaign | whatsAppCampaignId | int |
| DuplicateWhatsAppCampaign | whatsAppCampaignId | int (new cloned ID) |

**WhatsAppCampaignResponseDto Fields:**
| Field | Type | Notes |
|-------|------|-------|
| whatsAppCampaignId | number | PK |
| campaignName | string | — |
| campaignType | "Broadcast" \| "Automated" | — |
| whatsAppTemplateId | number | FK |
| templateName | string | FK display (from .Include + Mapster) |
| templateCategory | string | Marketing/Utility/Authentication |
| languageCode | string | — |
| recipientSourceType | string | — |
| recipientSourceRef | string \| null | — |
| recipientSourceLabel | string \| null | Server-resolved label (e.g., tag name, filter name) for display |
| excludeStopReplied | boolean | — |
| excludeRecentlyMessaged | boolean | — |
| recentlyMessagedHours | number \| null | — |
| excludeTagId | number \| null | — |
| excludeTagName | string \| null | FK display |
| scheduleType | "SendNow" \| "Scheduled" | — |
| scheduledDate | string (ISO) \| null | — |
| scheduledTimezone | string \| null | — |
| status | "Draft" \| "Scheduled" \| "Sending" \| "Sent" \| "Active" \| "Paused" \| "Cancelled" \| "Failed" | — |
| recipientCount | number | — |
| sentCount | number | — |
| deliveredCount | number | — |
| readCount | number | — |
| repliedCount | number | — |
| failedCount | number | — |
| failedReasonsJson | string \| null | JSON string; FE parses |
| estimatedCost | number \| null | — |
| actualCost | number \| null | — |
| costPerMessage | number \| null | — |
| deliveredPct | number | Computed server-side |
| readPct | number | Computed server-side |
| repliedPct | number | Computed server-side |
| sentDate | string (ISO) \| null | — |
| completedDate | string (ISO) \| null | — |
| recipients | WhatsAppCampaignRecipientDto[] | Only in GetById (paginated) |
| buttonClicks | WhatsAppCampaignButtonClickAggregateDto[] | Only in GetById — { buttonLabel, clicks, pctOfRead } |
| replyAnalysis | { positive, question, optOut } | Only in GetById — counts |
| isActive | boolean | Inherited |
| createdDate | string | Audit |
| modifiedDate | string | Audit |

**WhatsAppCampaignSummaryDto Fields:**
```ts
{ campaignsSentMonth: number; campaignsSentWeek: number; messagesSentMonth: number; deliveredPct: number; readRatePct: number; emailReadRatePct: number; replyRatePct: number; totalReplies: number; }
```

**WhatsAppCampaignAudiencePreviewDto Fields:**
```ts
{ total: number; withWhatsApp: number; withWhatsAppPct: number; optedIn: number; optedInPct: number; alreadyMessaged: number; netRecipients: number; estimatedCost: number; costPerMessage: number; tierLimit: number; tierRemaining: number; }
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/crm/whatsapp/whatsappcampaign`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] 4 KPI widgets render above grid with correct values (from GetWhatsAppCampaignSummary)
- [ ] Grid has Variant B layout (no duplicate header)
- [ ] Grid loads with 11 columns including rate-bar renderers for Delivered and Read
- [ ] Status badges render all 4 variants (active/sent/scheduled/draft) with correct colors
- [ ] Status-driven row actions appear correctly per row status
- [ ] Search filters by campaignName; status chip filter works; date-range filter works
- [ ] `?mode=new`: 3-step wizard renders with step 1 active; step progress indicator correct
- [ ] Step 1 — card selectors toggle state; template dropdown shows ONLY Approved templates; Template Preview bubble renders with selected template body; Schedule card-selector shows/hides date+timezone inputs
- [ ] Step 1 Next — validates required fields; blocks navigation when invalid
- [ ] Step 2 — all 5 source cards render; selecting Filter/Tag shows respective ApiSelectV2 pickers; Import List shows file-upload (placeholder toast); Audience Preview recomputes with debounce
- [ ] Step 2 — Exclusions checkboxes with inline conditional inputs work; Cost Estimate + Tier cards update live
- [ ] Step 3 — Summary table reflects all wizard state; 6 pre-send checklist items compute correctly; Template Preview matches Step 1
- [ ] Step 3 — Save Draft POSTs create with status=Draft; Send Now opens confirm modal
- [ ] Send Modal — Confirm dispatches Send mutation (placeholder); redirects to `?mode=read&id={newId}`
- [ ] Back/Next between steps preserves form state; invalid step blocks Next; Back skips validation
- [ ] `?mode=edit&id=X`: wizard pre-fills all 3 steps; can edit Draft or Scheduled campaigns; Sent is blocked
- [ ] `?mode=read&id=X`: Campaign Report renders (NOT disabled wizard) — delivery funnel + 2-col breakdown + recipients table
- [ ] Delivery Funnel shows 4 steps with arrows + percentages
- [ ] Delivery Breakdown card: 3 rows + failure reasons note (red)
- [ ] Button Click Stats + Reply Analysis render with correct aggregates
- [ ] Recipients table: 7 cols, contact link, status icons, reply text italic
- [ ] "View All Replies" navigates to `/crm/whatsapp/whatsappconversation?campaignId=X`
- [ ] Duplicate action clones with " (copy)" suffix
- [ ] Cancel (Scheduled), Pause/Resume (Automated) mutations work
- [ ] Unsaved changes dialog triggers on any navigation with dirty wizard
- [ ] FK dropdowns (WhatsAppTemplate Approved-only, Tag, SavedFilter) load via ApiSelectV2
- [ ] Service placeholder toasts fire for: Send Now dispatch, Segment picker, Import List upload, Automation Workflow picker, webhook-driven metrics, budget check
- [ ] Permissions: Edit/Delete/Send respect BUSINESSADMIN capability

**DB Seed Verification:**
- [ ] WhatsApp Campaigns menu visible in sidebar under CRM → WhatsApp (order 2, after Templates)
- [ ] Grid columns render correctly
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT a field** — comes from HttpContext (FLOW pattern)
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it
- **view-page.tsx handles ALL 3 modes** — new/edit share the 3-step wizard FORM layout, read has the Campaign Report DETAIL layout
- **DETAIL layout is a separate UI** (analytics page with funnel + breakdown + recipients) — do NOT wrap the wizard in a fieldset
- **FORM is a 3-step wizard**, not sections/accordions — step state preserved across Next/Back; validation runs only on current-step fields when clicking Next
- **Grid Layout Variant is `widgets-above-grid`** → FE MUST use Variant B (`<ScreenHeader>` + widgets + `<DataTableContainer showHeader={false}>`). NO DOUBLE HEADER — the ContactType #19 precedent
- **Row click opens Campaign Report, not wizard** — status-driven actions determine whether Edit is allowed (Draft/Scheduled only)
- **FE folder is `whatsapp-service` + `whatsapp-queries` + `whatsapp-mutations`**, NOT `notify-service` — copy the WhatsAppTemplate #31 precedent. BE group stays `Notify` (single DbContext covers all messaging)
- **Approved-template filter** for Step-1 dropdown is client-side (no new query — BE returns status field; FE filters `status === "Approved"`)
- **Rate-bar cell renderer is a NEW shared component** — check `src/presentation/components/shared/data-table/cell-renderers/` registry first; if missing, create it (reusable by SMS Campaign #30 and future analytics grids)
- **Tag FK** is at BOTH parent level (ExcludeTagId) AND potentially at source level (RecipientSourceType=Tag → RecipientSourceRef stores TagId as string) — the same FK entity, but modelled as two distinct relationships
- **Child entities are server-managed** — WhatsAppCampaignRecipients rows are populated by the send service (SERVICE_PLACEHOLDER); do NOT expose recipient CRUD in the wizard
- **WhatsApp Preview Bubble** may already be built by WhatsAppTemplate #31 — search `whatsapp-preview.tsx` / `whatsapp-phone-preview.tsx` in `crm/whatsapp/whatsapptemplate/`. If exportable, reuse; else copy styles. **Do NOT redesign** — match the mockup `.wa-preview-compact` look exactly
- **AutomationWorkflowId FK is nullable and gated** — Automated campaigns will need this in v2; for now, mark the widget as SERVICE_PLACEHOLDER with a "Coming soon" disabled state and auto-set AutomationWorkflowId=NULL on save
- **No pre-existing BE entity** — greenfield in NotifyModels; add inverse navigation collections to WhatsAppTemplate, Contact, Tag

**Service Dependencies** (UI-only — no backend service implementation):

- **⚠ SERVICE_PLACEHOLDER: `SendWhatsAppCampaign` dispatch** — Full UI + DB state transition to `Sending` implemented. Handler persists and returns the campaignId; **no actual message queue is dispatched** (Meta WhatsApp Business Cloud API integration not wired yet). FE shows toast "Campaign queued (service placeholder — no real sends)".
- **⚠ SERVICE_PLACEHOLDER: Delivery / Read / Reply webhook metrics** — Full UI renders metrics from DB columns. Webhook endpoint that mutates recipient `deliveredAt` / `readAt` / `repliedAt` / `replyText` / `replySentiment` is NOT built. Metrics will stay at zero until webhook infra is added.
- **⚠ SERVICE_PLACEHOLDER: `GetWhatsAppCampaignAudiencePreview`** — Query structure + return shape implemented with LINQ over existing Contact/Tag/SavedFilter queries. However, **"Opted-in for WhatsApp" and "Already messaged today" counts rely on a Contact.`whatsAppOptIn` flag + a `ContactMessageLog` table that don't exist yet**. Handler returns hard-coded `withWhatsAppPct=93.8`, `optedInPct=88.8`, `alreadyMessaged=0` as fallbacks. Widget still shows, FE toast explains.
- **⚠ SERVICE_PLACEHOLDER: Saved Segment picker** — Segment module does not exist in the registry. Step-2 "Saved Segment" card is selectable but its picker shows "Segment module not yet available — pick another source" inline hint. On submit, validator rejects with clear message.
- **⚠ SERVICE_PLACEHOLDER: Import List file upload** — `<FileUpload />` UI renders; on file drop, toast "File staged — ingestion service not wired yet". `RecipientSourceRef` stored as filename string.
- **⚠ SERVICE_PLACEHOLDER: Automation Workflow picker (Type=Automated)** — `AutomationWorkflowId` dropdown renders disabled with "Workflow module coming in Wave 4" hint. Form validator allows NULL for v1.
- **⚠ SERVICE_PLACEHOLDER: Cost / Messaging Tier calculation** — Step-2 Cost Estimate card renders using a static `costPerMessage=0.05` constant and a static `tierLimit=100000`. Real pricing requires WhatsAppSetup #34 integration (currently PARTIAL — FE stub only).
- **⚠ SERVICE_PLACEHOLDER: Budget check (Step 3 checklist item #5)** — "Budget sufficient" checklist item hardcoded to success. Real budget lookup requires Company.Budget model not in scope for this screen.
- **⚠ SERVICE_PLACEHOLDER: Reply sentiment classification** — `ReplySentiment` field exists on recipient; classification (Positive/Question/OptOut) requires NLP service not in scope. Report Reply Analysis card displays DB-stored sentiments with a "pending classification" fallback (all null → 0/0/0).

Full UI must be built (buttons, forms, modals, panels, interactions). Only the handler for the external service call is mocked.

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

_No sessions recorded yet — filled in after /build-screen completes._