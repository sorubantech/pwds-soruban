---
screen: EmailSendJob
registry_id: 25
module: Communication
status: PROMPT_READY
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-21
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (list + 4-step builder wizard)
- [x] Existing BE + FE code reviewed (ALIGN gap analysis complete)
- [x] Business rules + workflow extracted (7-state machine, Hangfire scheduling)
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated (ALIGN — focus on gap delta, not full regen)
- [ ] Solution Resolution complete
- [ ] UX Design finalized (4-step wizard + report-style DETAIL)
- [ ] User Approval received
- [ ] Backend code aligned (8 new columns + 2 new workflow commands + 1 summary query)
- [ ] Backend wiring complete (EF config, DbContext, Mappings — only deltas)
- [ ] Frontend restructured (flat accordion → 4-step wizard; new DETAIL layout)
- [ ] Frontend wiring complete
- [ ] DB Seed script (incremental — menu code rename + 4 MasterData TypeCodes + grid field changes)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/{lang}/crm/communication/emailcampaign`
- [ ] Grid loads with 4 KPI widgets + table rows
- [ ] Filter chips (All / Draft / Scheduled / Sending / Sent / Failed) filter correctly
- [ ] Type dropdown + From/To date filters apply
- [ ] `?mode=new` — Step 1 Setup renders; stepper progresses only when step valid
- [ ] `?mode=edit&id=X` — all 4 steps pre-filled from existing data
- [ ] `?mode=read&id=X` — DETAIL layout (report dashboard — NOT disabled wizard)
- [ ] Step 1 Campaign Type card-selector (3 cards: Campaign / Automated / Newsletter)
- [ ] Step 1 Subject + Preheader + From Name + From Email dropdown + Reply-To persist
- [ ] Step 2 5-card Recipient Source picker (Segment / Filter / Tag / Import / All)
- [ ] Step 2 Audience Preview shows live 5-count stats + Preview Recipients toggle mini-table
- [ ] Step 2 Exclusions panel persists (3 fields)
- [ ] Step 3 5 fixed starter template tiles + custom HTML editor with toolbar
- [ ] Step 3 Inline Send Test Email (input + button — NOT a modal)
- [ ] Step 3 Persistent right-column Live Preview with Desktop/Mobile toggle
- [ ] Step 4 Campaign Summary card (7 readonly rows)
- [ ] Step 4 Schedule option cards (Send Now / Schedule for Later / Recurring)
- [ ] Step 4 Pre-send Checklist (6 items, 5 pass + 1 warn)
- [ ] Save Draft → creates with JobStatus=DRAFT, stays on step
- [ ] Schedule Campaign → confirm dialog → creates Hangfire job → redirect to `?mode=read&id={id}`
- [ ] Send Now → confirm dialog → enqueues Hangfire send → redirect to `?mode=read&id={id}`
- [ ] Pause / Resume / Cancel / Duplicate row actions work per status
- [ ] View Report row action navigates to `?mode=read&id={id}` (DETAIL)
- [ ] DB Seed — menu code `EMAILCAMPAIGN` visible under CRM_COMMUNICATION (order 2)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: EmailSendJob (UI label: "Email Campaign")
Module: Communication
Schema: notify
Group: NotifyModels

Business: Email Campaigns are the primary outbound messaging workflow for the NGO — staff use them to send newsletters, fundraising appeals, donor thank-yous, event invitations, and automated drip sequences to segmented contact audiences. Users build a campaign through a 4-step wizard (Setup → Audience → Content → Review & Schedule) that captures sender identity, recipient targeting (saved segment/filter, tag, uploaded CSV list, or all opted-in), rich HTML content from a starter template, and a delivery schedule (send now, schedule for later with timezone, or recurring cron). The backend ingests each campaign as an `EmailSendJob` and hands it to Hangfire for queued dispatch; delivery/open/click telemetry flows back via webhook child tables (`EmailSendQueue`, `EmailClickTracking`, `EmailWebhookEventLog`, `EmailJobAnalytics`). The grid and per-campaign DETAIL view are the operational dashboards staff use to track send progress, view post-send analytics, retry failed sends, pause automations, and duplicate winning campaigns. This screen sits alongside Email Template (#24) and Saved Filter (#27) — it's the consumer of both — and is the email equivalent of SMS Campaign (#30) and WhatsApp Campaign (#32), which share the same wizard/report pattern.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> `EmailSendJob` already exists in BE. This section lists the TARGET state (current columns PLUS ALIGN-required new columns). New columns are marked `NEW`.
> Audit columns (CreatedBy/CreatedDate/ModifiedBy/ModifiedDate/IsActive) inherited from `Entity`.
> **CompanyId** is NOT a form field — comes from HttpContext.

Table: `notify."EmailSendJobs"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| EmailSendJobId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | app.Companies | Tenant scope (HttpContext) |
| JobCode | string | 100 | YES | — | Auto-generated if empty (`CAMP-{yymm}-{seq}`); unique per Company |
| JobName | string | 100 | YES | — | Campaign Name (display) — unique per Company |
| **SubjectLine** `NEW` | string | 255 | YES | — | Email subject with `{{placeholder}}` support |
| **PreheaderText** `NEW` | string | 200 | NO | — | Inbox preview snippet (50–100 chars recommended) |
| **FromName** `NEW` | string | 100 | YES | — | Sender display name |
| **FromEmail** `NEW` | string | 200 | YES | — | Verified sender address (chosen from CompanyEmailConfiguration) |
| **ReplyToEmail** `NEW` | string | 200 | NO | — | Defaults to FromEmail if empty |
| **CampaignTypeId** `NEW` | int | — | YES | setting.MasterData | MasterData TypeCode=`EMAILCAMPAIGNTYPE` (Campaign / Automated / Newsletter) |
| OrganizationalUnitId | int? | — | NO | app.OrganizationalUnits | Owning program/unit |
| SendJobTypeId | int | — | YES | setting.MasterData | TypeCode=`EMAILSENDJOBTYPE` (SENDNOW / SCHEDULE / RECURRING) — Step 4 schedule mode |
| SavedFilterId | int? | — | NO | notify.SavedFilters | Used when RecipientSourceId=SAVEDFILTER |
| SavedFilterSnapshot | string | 4000 | NO | — | Locked JSON snapshot at send-time (immutable audience) |
| **RecipientSourceId** `NEW` | int | — | YES | setting.MasterData | TypeCode=`EMAILRECIPIENTSOURCE` (SAVEDSEGMENT / SAVEDFILTER / BYTAG / IMPORTLIST / ALLCONTACTS) |
| **SavedSegmentId** `NEW` | int? | — | NO | corg.Segments | Used when RecipientSourceId=SAVEDSEGMENT |
| **RecipientTagIds** `NEW` | string | 500 | NO | — | Comma-separated Tag IDs; used when RecipientSourceId=BYTAG |
| **ImportListFileUrl** `NEW` | string | 500 | NO | — | CSV file key from object storage; used when RecipientSourceId=IMPORTLIST |
| RecipientTypeId | int? | — | NO | setting.MasterData | TypeCode=`EMAILRECIPIENTTYPE` (CONTACT / STAFF / DONOR / BENEFICIARY) |
| **ExcludeTagIds** `NEW` | string | 500 | NO | — | Comma-separated Tag IDs to exclude |
| **ExcludeSegmentId** `NEW` | int? | — | NO | corg.Segments | Exclusion segment |
| **ExcludeRecentDays** `NEW` | int? | — | NO | — | Exclude contacts emailed within last N days (0–90) |
| EmailConfigurationId | int? | — | NO | notify.CompanyEmailConfigurations | Provider (SMTP/Sendgrid/SES) |
| EmailTemplateId | int? | — | NO | notify.EmailTemplates | Starter template reference (nullable if `InlineEmailBodyHtml` used) |
| **InlineEmailBodyHtml** `NEW` | string | MAX | NO | — | Per-campaign rich HTML body (Step 3 custom content override) |
| **StarterTemplateKey** `NEW` | string | 40 | NO | — | One of `CAMPAIGN_APPEAL` / `THANK_YOU` / `MONTHLY_NEWSLETTER` / `EVENT_INVITATION` / `BLANK` — identifies which starter tile was seeded |
| ScheduleStartDatetime | DateTime? | — | NO | — | Send-at instant (required when SendJobType=SCHEDULE) |
| **ScheduleTimezone** `NEW` | string | 50 | NO | — | IANA TZ id (e.g., `Asia/Kolkata`); used for RECURRING/SCHEDULE display |
| RecurringCronExpression | string | 100 | NO | — | Cron for RECURRING mode |
| RecurringEndDate | DateTime? | — | NO | — | Recurring stop date |
| JobStatusId | int | — | YES | setting.MasterData | TypeCode=`EMAILJOBSTATUS` (DRAFT / SCHEDULED / SENDING / SENT / PAUSED / FAILED / CANCELLED — 7 states) |
| HangfireJobId | string | 100 | NO | — | One-shot Hangfire job id |
| HangfireRecurringJobId | string | 100 | NO | — | Recurring Hangfire job id |
| PreviewTotalRecordsMatched | int? | — | NO | — | Cached audience size (computed on audience query) |
| PreviewExecuteAt | DateTime? | — | NO | — | Last audience preview timestamp |
| TotalEmailsQueued | int? | — | NO | — | Dispatch metric |
| TotalEmailsSend | int? | — | NO | — | Dispatch metric (successfully handed to provider) |
| TotalEmailsFailed | int? | — | NO | — | Dispatch metric |
| LastExecutionStartedAt | DateTime? | — | NO | — | Last send run start |
| LastExecutionEndedAt | DateTime? | — | NO | — | Last send run end |
| NextExecutionAt | DateTime? | — | NO | — | Next scheduled run |

**Child Entities** (existing — reused, NO new child tables needed):
| Child Entity | Relationship | Key Fields | Purpose |
|--------------|--------------|-----------|---------|
| EmailSendQueue | 1:Many via EmailSendJobId | RecipientEmail, Status, DeliveredAt, OpenedAt | Per-recipient send ledger |
| EmailClickTracking | 1:Many via EmailSendJobId | RecipientEmail, LinkUrl, ClickedAt | Click telemetry |
| EmailExecutionLog | 1:Many via EmailSendJobId | StartedAt, EndedAt, Outcome | Execution history |
| EmailWebhookEventLog | 1:Many via EmailSendJobId | EventType, Payload | Provider webhooks |
| EmailJobAnalytics | 1:Many via EmailSendJobId | OpensTotal, ClicksTotal, UniqueOpens | Aggregated metrics per day |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()`) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|---------------|------------------|----------------|---------------|-------------------|
| OrganizationalUnitId | OrganizationalUnit | `Base.Domain/Models/ApplicationModels/OrganizationalUnit.cs` | `GetOrganizationalUnits` (field: `organizationalUnits`) | organizationalUnitName | OrganizationalUnitResponseDto |
| SavedFilterId | SavedFilter | `Base.Domain/Models/NotifyModels/SavedFilter.cs` | `GetSavedFilters` (field: `savedFilters`) | filterName | SavedFilterResponseDto |
| SavedSegmentId | Segment | `Base.Domain/Models/ContactModels/Segment.cs` | `GetSegments` (field: `segments`) — verify SegmentQueries.cs | segmentName | SegmentResponseDto |
| RecipientTagIds (each) | Tag | `Base.Domain/Models/ContactModels/Tag.cs` | `GetTags` (field: `tags`) — verify TagQueries.cs (HotChocolate reserved-name alias may apply as in SMSCampaign #30) | tagName | TagResponseDto |
| ExcludeTagIds (each) | Tag | same as RecipientTagIds | same | same | same |
| ExcludeSegmentId | Segment | same as SavedSegmentId | same | same | same |
| EmailConfigurationId | CompanyEmailConfiguration | `Base.Domain/Models/NotifyModels/CompanyEmailConfiguration.cs` | `GetCompanyEmailConfigurations` (field: `companyEmailConfigurations`) | fromEmail / senderName | CompanyEmailConfigurationResponseDto |
| EmailTemplateId | EmailTemplate | `Base.Domain/Models/NotifyModels/EmailTemplate.cs` | `GetEmailTemplates` (field: `emailTemplates`) | templateName | EmailTemplateResponseDto |
| CampaignTypeId | MasterData (`EMAILCAMPAIGNTYPE`) | `Base.Domain/Models/SettingModels/MasterData.cs` | `GetMasterDatas` filtered by typeCode | displayName | MasterDataResponseDto |
| SendJobTypeId | MasterData (`EMAILSENDJOBTYPE`) | same | `GetMasterDatas` filtered by typeCode | displayName | MasterDataResponseDto |
| RecipientSourceId | MasterData (`EMAILRECIPIENTSOURCE`) | same | `GetMasterDatas` filtered by typeCode | displayName | MasterDataResponseDto |
| RecipientTypeId | MasterData (`EMAILRECIPIENTTYPE`) | same | `GetMasterDatas` filtered by typeCode | displayName | MasterDataResponseDto |
| JobStatusId | MasterData (`EMAILJOBSTATUS`) | same | `GetMasterDatas` filtered by typeCode | displayName (with ColorHex extra attribute) | MasterDataResponseDto |

**If Tag / Segment GQL queries don't exist yet**: mark as SERVICE_PLACEHOLDER in §⑫ — FE should use a multi-select with hardcoded empty list and a TODO; BE should still carry the FK columns.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `JobCode` unique per CompanyId (filtered index, case-insensitive)
- `JobName` unique per CompanyId — warn on create, allow duplicate in edit if user confirms

**Required Field Rules:**
- `JobName`, `SubjectLine`, `FromName`, `FromEmail`, `CampaignTypeId`, `SendJobTypeId`, `RecipientSourceId`, `JobStatusId` always required
- `EmailTemplateId` OR `InlineEmailBodyHtml` (XOR) must be populated before sending (DRAFT allowed with neither)

**Conditional Rules:**
- If `RecipientSourceId = SAVEDSEGMENT` → `SavedSegmentId` required
- If `RecipientSourceId = SAVEDFILTER` → `SavedFilterId` required
- If `RecipientSourceId = BYTAG` → `RecipientTagIds` must have ≥ 1 tag
- If `RecipientSourceId = IMPORTLIST` → `ImportListFileUrl` required
- If `SendJobTypeId = SCHEDULE` → `ScheduleStartDatetime` required AND > now
- If `SendJobTypeId = RECURRING` → `RecurringCronExpression` required (valid cron)
- If `CampaignTypeId = Automated` → force `SendJobTypeId = SENDNOW` or `RECURRING` on trigger (no one-off SCHEDULE)
- If transitioning status to `SENT` or `SCHEDULED` → Pre-send Checklist items 1–5 must all PASS (subject set, from configured, recipients > 0, template content ready, unsubscribe link present in body)

**Business Logic:**
- `PreviewTotalRecordsMatched` computed via recipient-source resolver (SERVICE_PLACEHOLDER until DynamicQueryBuilder exists — see #27 ISSUE-1)
- `SavedFilterSnapshot` captured at schedule/send moment — subsequent SavedFilter edits do NOT change the locked audience
- On `DELETE` — also delete associated Hangfire job (existing behavior)
- On `UPDATE` when SendJobType or ScheduleStartDatetime changes — re-schedule Hangfire (existing behavior)
- Email body must contain `{{UnsubscribeLink}}` placeholder before SCHEDULED/SENT allowed (Checklist item 5)

**Workflow** — 7-state machine:

| Current | Action | Next | Trigger | Side effect |
|---------|--------|------|---------|-------------|
| — | SaveDraft | DRAFT | User clicks Save Draft | Persist only; no Hangfire |
| DRAFT | ScheduleCampaign (SendLater) | SCHEDULED | User clicks Schedule Campaign in Step 4 | `BackgroundJob.Schedule` Hangfire |
| DRAFT | SendNow | SENDING | User picks Send Now + confirms | `BackgroundJob.Enqueue` Hangfire |
| DRAFT | Activate (Automated) | ACTIVE | User activates automated type | `RecurringJob.AddOrUpdate` |
| SCHEDULED | Cancel | CANCELLED | Row action / header | `BackgroundJob.Delete` |
| SCHEDULED | Edit | DRAFT | User modifies in edit mode | Unschedule then re-schedule on save |
| SENDING | — | SENT | Hangfire job completion | Update metrics |
| SENDING | — | FAILED | Hangfire job error | Log error, metrics |
| ACTIVE | Pause | PAUSED | Row action | `RecurringJob.Remove` (preserve config) |
| PAUSED | Resume | ACTIVE | Row action | `RecurringJob.AddOrUpdate` |
| FAILED | Retry | SENDING | Row action | Re-enqueue Hangfire |
| SENT | Duplicate | (new DRAFT) | Row action | Clone entity except IDs/metrics |

Status badges (seed in MasterData with color):
- DRAFT → grey
- SCHEDULED → blue
- SENDING → amber (pulsing)
- SENT → green
- PAUSED → amber
- FAILED → red
- CANCELLED → slate

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — decisions pre-answered.

**Screen Type**: FLOW
**Type Classification**: Transactional workflow with multi-step wizard + state machine + analytics report DETAIL
**Reason**: Add/Edit is a full-page 4-step wizard (URL → `?mode=new|edit`); Read is a completely different UI (campaign analytics report dashboard with funnels, recipient table, click map). Matches FLOW canonical pattern.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files — ALREADY EXIST, modify)
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 8)
- [x] Unique validation — JobCode, JobName (per Company)
- [x] Workflow commands (SendNow, Schedule, Cancel, Pause, Resume, Retry, Duplicate) — **PARTIAL: some exist, some new**
- [ ] Nested child creation — N/A (child tables populate via send process)
- [x] File upload command — ImportListFileUrl (reuse existing file-upload service)
- [x] Custom business rule validators — Cron syntax, datetime-in-future, unsubscribe-link-check, email-format
- [x] Summary aggregation query — `GetEmailSendJobSummary` (4 KPIs for Variant B header)
- [x] Grid aggregation columns — per-row OpenRate, ClickRate via child aggregate (LINQ subquery)

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) — Variant B (4 KPI widgets above grid)
- [x] ScreenHeader (Variant B mandatory) + DataTableContainer `showHeader={false}`
- [x] view-page.tsx with 3 URL modes (new, edit, read) — **RESTRUCTURE from accordion to wizard**
- [x] React Hook Form (for FORM — 4-step wizard)
- [x] Zustand store (`email-send-job-store.ts` — ALREADY EXISTS, extend with new fields)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back + Save Draft + step-specific Next/Prev)
- [x] Step progression component (wizard header) — **NEW — reuse SMSCampaign #30 StepProgress pattern**
- [x] Workflow status badge + action buttons (status-driven row actions)
- [ ] Child grid inside form — N/A
- [x] Card selectors (Step 1 Campaign Type × 3, Step 2 Recipient Source × 5, Step 4 Schedule × 3)
- [x] Inline mini-display (Audience Preview panel with 5 count stats)
- [x] Template tile picker (Step 3 — 5 fixed starter tiles)
- [x] Rich HTML editor with toolbar (reuse `email-template-editor` from #24)
- [x] Inline Send Test Email (input + button — NOT modal; refactor existing SendTestEmailDialog)
- [x] Persistent Live Preview pane with Desktop/Mobile toggle (reuse `DeviceTypeSelector` from #24, make sticky/persistent)
- [x] Pre-send Checklist component (6 computed items)
- [x] Summary cards / count widgets above grid (4 widgets)
- [x] Grid aggregation columns (OpenRate, ClickRate via rate-bar renderer from SMSCampaign #30 / WhatsAppCampaign #32)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted from `html_mockup_screens/screens/communication/email-campaign-list.html` and `email-campaign-builder.html`.

### Grid/List View (index-page)

**Display Mode**: `table` (default — transactional listing, not a gallery)

**Grid Layout Variant**: `widgets-above-grid` → **Variant B mandatory**: `<ScreenHeader>` + 4 widget components + `<DataTableContainer showHeader={false}>`. Failure to use Variant B = double-header UI bug (ContactType #19 precedent).

**Page Widgets & Summary Cards** (above grid):

| # | Widget Title | Value Source | Display Type | Position | Detail line |
|---|--------------|--------------|--------------|----------|-------------|
| 1 | Total Campaigns | `totalCampaigns` | count | Top-left (teal icon `fa-envelope`) | "This month: {thisMonthCount}" |
| 2 | Emails Sent (Month) | `emailsSentMonth` | count (thousands-format) | Top (blue icon `fa-paper-plane`) | "+{pct}% vs last month" (positive/negative) |
| 3 | Avg Open Rate | `avgOpenRatePct` | percent | Top (green icon `fa-envelope-open`) | "Industry avg: 25%" + check if > 25 |
| 4 | Avg Click Rate | `avgClickRatePct` | percent | Top-right (purple icon `fa-mouse-pointer`) | "Industry avg: 3%" + check if > 3 |

**Summary GQL Query**: `GetEmailSendJobSummary` → `EmailSendJobSummaryDto` with the 4 fields above + `thisMonthCount` + `lastMonthEmailsSent` + `previousOpenRate` + `previousClickRate` for detail-line computation. New query to add.

**Grid Columns** (10 columns in display order from mockup):

| # | Column Header | Field Key | Display Type | Width | Sortable | Renderer | Notes |
|---|---------------|-----------|--------------|-------|----------|----------|-------|
| 1 | (checkbox) | — | selection | 36px | — | row-select | Bulk actions trigger |
| 2 | Campaign Name | jobName | text-link | auto | YES | `campaign-name-link` | Click → `?mode=read&id={id}` (if SENT) or `?mode=edit&id={id}` (if DRAFT) |
| 3 | Type | campaignTypeName | type-badge | 100px | YES | `type-badge` (reuse from Placeholder #26; add 3 variants: campaign/automated/newsletter) | Color: Campaign=teal, Automated=purple, Newsletter=orange |
| 4 | Status | jobStatusName | status-badge | 110px | YES | `status-badge` (reuse, Colored via MasterData.DataSetting) | Icon+text: Scheduled=calendar/blue, Sent=check/green, Active=dot/green, Paused=pause/amber, Failed=times/red, Draft=pencil/slate |
| 5 | Recipients | previewTotalRecordsMatched | number or "Auto" | 90px | YES | `recipients-cell` | If Automated → show "Auto", else thousands-format |
| 6 | Sent | totalEmailsSend | number | 80px | YES | text | Dash `—` if null/draft |
| 7 | Open Rate | openRatePct | rate-bar | 140px | YES | `rate-bar` (reuse from SMSCampaign #30 / WhatsAppCampaign #32) | Mini bar + %; green/yellow/red thresholds |
| 8 | Click Rate | clickRatePct | rate-bar | 140px | YES | `rate-bar` | Mini bar + %; green/yellow/red thresholds |
| 9 | Date | scheduleStartDatetime OR sentAt | date-short | 140px | YES | `date-short` | Show "Apr 15, 10:00 AM" for Scheduled; "Apr 10, 2026" for Sent; "Always" for Active; "Paused" for Paused; `—` for Draft |
| 10 | Actions | — | inline-icon-buttons | 140px | — | `email-campaign-row-actions` | Status-driven (see below) |

**Status-driven row actions** (icon buttons, match mockup):
- DRAFT → `fa-edit` Edit, `fa-trash` Delete (danger)
- SCHEDULED → `fa-edit` Edit, `fa-ban` Cancel, `fa-copy` Duplicate
- SENT → `fa-chart-bar` ViewReport (primary — → read mode), `fa-copy` Duplicate
- ACTIVE (automated) → `fa-edit` Edit, `fa-pause` Pause, `fa-chart-bar` ViewReport
- PAUSED → `fa-edit` Edit, `fa-play` Resume (success color), `fa-chart-bar` ViewReport
- FAILED → `fa-exclamation-triangle` ViewError (warning color, opens alert with error), `fa-redo` Retry, `fa-trash` Delete

**Bulk actions** (appear in cyan banner when rows selected):
- Delete Selected (danger)
- Duplicate Selected
- Export Report (download CSV of selected campaigns' analytics)

**Filter chips** (6): All | Draft | Scheduled | Sending | Sent | Failed (click toggles `jobStatusId` filter)

**Secondary filter row** (below chips):
- Type dropdown: All Types / Campaign / Automated / Newsletter (`campaignTypeId` filter)
- From date input (`dateFrom`)
- To date input (`dateTo`)

**Search**: Top-of-grid search input — filters by `jobName` + `subjectLine`

**Pagination**: standard FlowDataTable pagination; "Showing X-Y of Z campaigns"

**Row Click**: On campaign name click → if Draft/Scheduled → `?mode=edit&id={id}`; if Sent/Active/Paused/Failed → `?mode=read&id={id}`

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

> `/emailcampaign?mode=new` → **LAYOUT 1: WIZARD** (empty, 4 steps)
> `/emailcampaign?mode=edit&id=X` → **LAYOUT 1: WIZARD** (pre-filled)
> `/emailcampaign?mode=read&id=X` → **LAYOUT 2: REPORT DASHBOARD** (completely different UI — analytics + recipients table)

---

#### LAYOUT 1: FORM (mode=new & mode=edit) — 4-STEP WIZARD

> **ALIGN NOTE**: existing view-page.tsx is a vertical accordion with sequential section unlock (`useSectionProgression`). This must be RESTRUCTURED into a true 4-step wizard with horizontal step header. The existing accordion sub-components can be mostly reused but regrouped into step panels.

**Page Header**: FlowFormPageHeader with Back button + **Save Draft** outline button + **Cancel** ghost button (no step-global Save; step-specific Next/Back at bottom of each panel)

**Wizard Step Header** (horizontal, always visible, clickable once step valid):
```
┌──────────────────────────────────────────────────────┐
│  [1] Setup ──── [2] Audience ──── [3] Content ──── [4] Review │
└──────────────────────────────────────────────────────┘
```
- Active step: accent blue filled circle + bold label
- Completed step: green check circle + regular label
- Future step: grey outline circle + dimmed label (not clickable until prior valid)
- Use existing `useSectionProgression` hook but reframe steps as named (`setup / audience / content / review`) instead of accordion rows

**Section Container Type**: single active step panel (only one rendered at a time); panels fade/slide on step change

---

**STEP 1: Campaign Setup**

Icon: `fa-cog` | Title: "Campaign Setup" | Description: "Configure the basic details of your email campaign"

Layout: single-column form; optional 2-col for From Name/From Email/Reply-To row

| Field | Widget | Width | Placeholder / Default | Validation | Notes |
|-------|--------|-------|----------------------|------------|-------|
| JobCode | readonly text | 2-col | "Auto-generated" | max 100 | Disabled; shows generated code after save |
| JobName (Campaign Name) | text | 8-col | "e.g., Spring Appeal 2026" | required, max 100 | Primary identifier |
| CampaignTypeId | **card-selector (3 cards)** | full-row | — | required | See Card Selector table below |
| SubjectLine | text | 8-col | "e.g., {{FirstName}}, your support changes lives!" | required, max 255 | Below: **PlaceholderChipBar** — clickable chips for `{{FirstName}}` `{{LastName}}` `{{OrgName}}` (inserts token at cursor) |
| PreheaderText | text | full-row | "Brief text shown after subject in inbox" | optional, max 200 | Helper text: "50–100 characters recommended" |
| FromName | text | 4-col | "Hope Foundation" | required, max 100 | — |
| FromEmail | **ApiSelectV2** | 4-col | "Select verified sender..." | required, max 200 | Query: `GetCompanyEmailConfigurations`; displays `fromEmail` / `senderName` of verified senders only |
| ReplyToEmail | text/email | 4-col | "Same as From Email" | optional, valid email | Blank defaults to FromEmail |

**Card Selector — Campaign Type** (3 cards, radio-style):

| Card key | Icon (emoji or fa) | Label | Description | MasterData DataCode |
|----------|-------------------|-------|-------------|---------------------|
| CAMPAIGN | 📢 / `fa-bullhorn` | Campaign Email | One-time blast to selected audience | `CAMPAIGN` |
| AUTOMATED | 🔄 / `fa-robot` | Automated Email | Triggered by event (donation received, contact created, etc.) | `AUTOMATED` |
| NEWSLETTER | 📰 / `fa-newspaper` | Newsletter | Periodic scheduled delivery | `NEWSLETTER` |

Default selected: CAMPAIGN

**Step 1 footer**: Right-aligned `Next →` button (enabled when required fields valid)

---

**STEP 2: Select Audience**

Icon: `fa-users` | Title: "Select Audience" | Description: "Choose who will receive this campaign"

Layout: **2-column** (7-col left: source picker + exclusions | 5-col right: audience preview panel)

**LEFT COLUMN — Recipient Source Picker (5 stacked radio cards)**:

| Card key | Icon | Title | Description | Sub-form when selected |
|----------|------|-------|-------------|------------------------|
| SAVEDSEGMENT | 📋 / `fa-list` | Saved Segment | Use a pre-defined contact segment | ApiSelect dropdown `GetSegments` — shows `segmentName` + contact count |
| SAVEDFILTER | 🔍 / `fa-filter` | Saved Filter | Use a saved search filter | ApiSelect dropdown `GetSavedFilters` — shows `filterName` + `previewRecordsMatched` (from #27) |
| BYTAG | 🏷️ / `fa-tag` | By Tag | Select contacts by tag | Multi-select (height 100px) from `GetTags` — hint: "Hold Ctrl/Cmd to select multiple tags" |
| IMPORTLIST | 📁 / `fa-upload` | Import List | Upload a CSV file of email addresses | Drag-drop file upload zone — accepts `.csv`; on drop, uploads to file store and sets `ImportListFileUrl` |
| ALLCONTACTS | 👥 / `fa-users-rectangle` | All Contacts | Send to entire opted-in contact base | Warning banner: "⚠ This will send to {totalOptedInContacts} contacts" — no further input |

Default selected: SAVEDFILTER

**LEFT COLUMN — Exclusions Panel** (always visible below source cards; red-tinted card with `fa-ban` header):

| Field | Widget | Options/Validation |
|-------|--------|---------------------|
| ExcludeTagIds | multi-select | Height 60px; from `GetTags` filtered (suggested labels: Unsubscribed, Do Not Email, Inactive, Bounced) |
| ExcludeSegmentId | ApiSelect | From `GetSegments`; optional; placeholder "None" |
| ExcludeRecentDays | number input | Width 100px; min 0, max 90; default 3; labeled "Exclude contacts emailed within last N days" |

**RIGHT COLUMN — Audience Preview Panel** (sticky, header: `fa-users` "Audience Preview"):

Live-computed from selected source + exclusions (fires `ResolveAudiencePreview` query on source/exclusion change with 400ms debounce):

| Row | Label | Value | Color/Style |
|-----|-------|-------|-------------|
| 1 | Total Recipients | {totalMatched} | default |
| 2 | With Email | {withEmail} ({pctWithEmail}%) | green/success |
| 3 | Without Email | {withoutEmail} (will be skipped) | amber/warning |
| 4 | Unsubscribed | {unsubscribedCount} (will be excluded) | red/danger |
| 5 (bold, accent, top-border) | **Net Recipients** | {netRecipients} | accent blue |

Below: `fa-eye` "Preview Recipients" toggle button (full-width outline) → expands **Preview Recipients mini-table** (10 sample rows):
- Columns: Name / Email / Tags (badge list)
- Source: first 10 rows from `ResolveAudiencePreview` query

**Step 2 footer**: `← Back` + `Next →`

---

**STEP 3: Design Content**

Icon: `fa-palette` | Title: "Design Content" | Description: "Choose a template and customize your email content"

Layout: **2-column** (7-col left: template + editor + test | 5-col right: live preview persistent pane)

**LEFT COLUMN — Starter Template Picker** (grid of 5 fixed tiles, auto-fill min 180px):

| # | Tile Icon | Template Name | Category | StarterTemplateKey | Seed Content |
|---|-----------|---------------|----------|---------------------|--------------|
| 1 | `fa-bullhorn` (accent/teal) | Campaign Appeal | Fundraising | `CAMPAIGN_APPEAL` | HTML: donation appeal with {{FirstName}} salutation + donation levels + CTA |
| 2 | `fa-heart` (green) | Thank You | Donor Care | `THANK_YOU` | HTML: thank-you body + tax receipt link |
| 3 | `fa-newspaper` (amber) | Monthly Newsletter | Newsletter | `MONTHLY_NEWSLETTER` | HTML: multi-section newsletter layout |
| 4 | `fa-calendar-check` (purple) | Event Invitation | Events | `EVENT_INVITATION` | HTML: event hero + date/venue + RSVP CTA |
| 5 | `fa-file` (slate) | Blank Template | Start from scratch | `BLANK` | Empty body |

- Selecting a tile sets `StarterTemplateKey` and seeds `InlineEmailBodyHtml` with starter content (ONLY on first select; switching tiles prompts confirm "Replace current content?")
- Seed starters via DB migration — content stored in a new MasterData TypeCode=`EMAILSTARTERTEMPLATE` OR in a JSON static file `src/resources/email-starter-templates.json` (Plan: use JSON file for faster iteration, avoid migration round-trips). Flag in §⑫ for Solution Resolver decision.

**LEFT COLUMN — Content Editor** (below tile picker):

Label: "Content Customization" (h6)

**Toolbar** (9 buttons): `fa-bold` Bold | `fa-italic` Italic | `fa-underline` Underline | `fa-link` Link | `fa-image` Image | `fa-align-left` AlignLeft | `fa-align-center` AlignCenter | `fa-list-ul` BulletList | `fa-code` **Insert Placeholder** (blue-styled, opens dropdown of available `{{tokens}}`)

**Editor body**: Reuse existing `email-template-editor` component from EmailTemplate #24 (contenteditable + sanitizer). Bound to `InlineEmailBodyHtml`. Min-height 300px.

**LEFT COLUMN — Inline Send Test Email** (below editor — NOT a modal):

```
[ email input: "test@email.com" ]  [ 📨 Send Test Email ]
```

- `<Input type="email" />` (max-width 250px) + `<Button variant="outline">` Send Test Email
- On click: calls existing `SendTestEmail` mutation with current form state (serialize template + subject + from + preheader + a single sample contact)
- **ALIGN CHANGE**: existing `SendTestEmailDialog.tsx` (modal) must be REFACTORED into an inline `<SendTestEmailInline>` component; the dialog wrapper and `testEmailDialogOpen` state must be removed.

**RIGHT COLUMN — Live Preview Pane** (sticky, persistent — NOT collapsible):

Header bar: "Preview" + `<DeviceTypeSelector>` (Desktop/Mobile toggle — reuse from EmailTemplate #24)

Body: iframe rendering the email with:
- Subject line displayed at top (from Step 1)
- From address band (accent color)
- Rendered `InlineEmailBodyHtml` with `{{FirstName}}` → "Sarah" (static sample) and other tokens resolved
- Footer: static org address + "Unsubscribe | Manage Preferences" links
- Mobile toggle shrinks max-width 500→320px via `.mobile` class

**ALIGN CHANGE**: existing preview in `TemplateConfiguration.tsx` is a collapsible panel toggled by `templateSectionExpanded`. It must become a **persistent sticky right-column pane** that updates on content/subject/from change (debounce 300ms).

**Step 3 footer**: `← Back` + `Next →` (Next enabled when content non-empty)

---

**STEP 4: Review & Schedule**

Icon: `fa-check-circle` | Title: "Review & Schedule" | Description: "Review your campaign details and choose when to send"

Layout: **2-column** (7-col left: summary + schedule options | 5-col right: pre-send checklist)

**LEFT COLUMN — Campaign Summary Card** (readonly, 7 rows, header `fa-clipboard-check` "Campaign Summary"):

| Label | Value | Source |
|-------|-------|--------|
| Campaign | {jobName} | Step 1 |
| Type | {campaignTypeName} | Step 1 |
| Subject | {subjectLine} (with {{tokens}} resolved using sample data) | Step 1 |
| From | {fromName} \<{fromEmail}\> | Step 1 |
| Recipients | {netRecipients} contacts | Step 2 (accent-colored) |
| Template | {starterTemplateName} ({starterTemplateKey}) | Step 3 |
| Est. Send Time | ~{estimatedMinutes} minutes | Computed: ceil(netRecipients / 300) |

**LEFT COLUMN — Schedule Options** (3 radio-cards, one selected at a time, maps to `SendJobTypeId`):

| # | Icon | Title | Description | MasterData DataCode | Sub-form |
|---|------|-------|-------------|---------------------|----------|
| 1 | 🚀 / `fa-rocket` | Send Now | Begin delivering immediately | `SENDNOW` | None |
| 2 | 📅 / `fa-calendar` | Schedule for Later | Choose the best date and time | `SCHEDULE` | Date + Time + Timezone + Suggested Best Times chips (see below) |
| 3 | 🔄 / `fa-sync` | Recurring | Set up periodic delivery (for newsletters) | `RECURRING` | Frequency + Day + Time (see below) |

Default: SCHEDULE

**Sub-form: Schedule for Later**:
- Date: date input → persists `ScheduleStartDatetime` (date portion)
- Time: time input → persists `ScheduleStartDatetime` (time portion)
- Timezone: dropdown with 6 zones (UTC+00:00 GMT / UTC+05:30 IST / UTC-05:00 EST / UTC-08:00 PST / UTC+01:00 CET / UTC+08:00 SGT); persists `ScheduleTimezone` as IANA id
- Suggested Best Times chips (readonly, clickable pill buttons, auto-fill Date+Time when clicked): "Tue 10:00 AM (highest open rate)" `fa-star` + "Thu 2:00 PM (second best)" — labels from a static const until AI suggestion service exists (SERVICE_PLACEHOLDER)

**Sub-form: Recurring**:
- Frequency: dropdown (Weekly / Bi-weekly / Monthly — default Monthly) → persists as cron building-block
- Day: dropdown (Mon–Fri) → cron building-block
- Time: time input → cron building-block
- Persist `RecurringCronExpression` as computed cron (`0 {time.mm} {time.hh} * * {day}` for weekly, etc.); show computed cron below as readonly helper text: "Cron: 0 0 10 * * TUE"
- `RecurringEndDate` — optional date input below (label: "Stop after")

**RIGHT COLUMN — Pre-send Checklist** (6 items, computed, header `fa-shield-check` green "Pre-send Checklist"):

| # | Status | Text | Logic |
|---|--------|------|-------|
| 1 | PASS/FAIL | Subject line set | `subjectLine.length > 0` |
| 2 | PASS/FAIL | From address configured | `fromEmail` verified in CompanyEmailConfiguration |
| 3 | PASS/FAIL | Recipients selected **({netRecipients})** | `netRecipients > 0` |
| 4 | PASS/FAIL | Template content ready | `inlineEmailBodyHtml.length > 0 || emailTemplateId != null` |
| 5 | PASS/FAIL | Unsubscribe link present | Body contains `{{UnsubscribeLink}}` OR literal `/unsubscribe` URL |
| 6 | PASS/WARN | No test email sent *(recommended, not required)* | `testEmailSentCount > 0` → PASS; else WARN (not blocking) |

- PASS icon: `fa-check` green circle
- FAIL icon: `fa-times` red circle + blocks Schedule/Send
- WARN icon: `fa-exclamation` amber circle + allows Schedule/Send

**Step 4 footer**:
- `← Back`
- `💾 Save Draft` (outline accent) — always enabled, writes with `JobStatusId=DRAFT`
- `📅 Schedule Campaign` (primary green) — enabled only when items 1–5 PASS; opens confirm dialog ("Are you sure you want to schedule this campaign for {date} at {time} {tz}? This will send to {netRecipients} recipients.")

---

#### LAYOUT 2: DETAIL (mode=read) — REPORT DASHBOARD (completely different UI)

> The read-only analytics view when user clicks a SENT/ACTIVE/PAUSED row. **NOT the wizard disabled** — a dedicated campaign-report page.
> Mirror the SMSCampaign #30 / WhatsAppCampaign #32 report pattern (delivery funnel + breakdown + recipients table).

**Page Header**: FlowFormPageHeader with Back + **Edit** (→ `?mode=edit&id=X` — disabled if SENT) + More dropdown (Duplicate, Delete)

**Header Actions** (status-driven):
- SENT / ACTIVE / PAUSED: Edit (disabled if SENT), Duplicate (enabled always), Export Report (CSV)
- SCHEDULED: Edit, Cancel (danger), Duplicate
- FAILED: View Error Details (modal), Retry (re-enqueues), Delete (danger)

**Page Layout**:

| Column | Width | Cards / Sections |
|--------|-------|------------------|
| Top | full | **Campaign Meta Strip**: Campaign Name (h2) + Type badge + Status badge + Sent/Scheduled timestamp + From address |
| Full-width | 12-col | **Delivery Funnel** (5-step horizontal funnel) |
| Left | 7-col | **Recipients Table** (paginated — per-recipient send ledger with Open/Click badges) |
| Right | 5-col | **Delivery Breakdown card** + **Engagement card** + **Error Summary card** (if FAILED) |

**Delivery Funnel** (5 steps, mirrors SMSCampaign #30 funnel but with email stages):
```
Queued {N} → Sent {N} ({pct}%) → Delivered {N} ({pct}%) → Opened {N} ({pct}%) → Clicked {N} ({pct}%)
```
- Each step is a horizontal bar with count + percentage
- Stepped colors: light → dark accent blue

**Delivery Breakdown card** (right):
- Delivered / Bounced (Soft) / Bounced (Hard) / Spam-Reported / Unsubscribed — with counts + mini-bars
- Data from `EmailSendQueue` child aggregation

**Engagement card** (right):
- Unique Opens / Total Opens / Unique Clicks / Total Clicks / Avg Time to Open
- Top-5 most-clicked links (from `EmailClickTracking`)
- Data from `EmailJobAnalytics` child aggregation

**Error Summary card** (right, only if JobStatus=FAILED):
- Error message from last `EmailExecutionLog` row
- Retry button + full execution log link

**Recipients Table** (left, paginated):
- Columns: Name | Email | Sent At | Status (badge: Delivered/Bounced/Opened/Clicked) | Opens | Clicks | Last Activity
- Search + filter by status
- Click row → contact profile (future link)

**If mockup does NOT have DETAIL**: mockup DOES NOT show an analytics page — report design is inferred from SMSCampaign #30 precedent + EmailJobAnalytics child tables. State in §⑫ that DETAIL design is derived.

---

### Grid Aggregation Columns

| Column Header | Value Description | Source | Implementation |
|---------------|-------------------|--------|----------------|
| Open Rate | `uniqueOpens / totalEmailsSend * 100` | Aggregate from `EmailSendQueue` WHERE OpenedAt IS NOT NULL | LINQ subquery in GetEmailSendJobsQuery |
| Click Rate | `uniqueClicks / totalEmailsSend * 100` | Aggregate from `EmailClickTracking` | LINQ subquery |
| Recipients | COALESCE(PreviewTotalRecordsMatched, EmailSendQueue count) | Cached value or live count | Projection via LINQ |

### User Interaction Flow

1. Grid → "+ New Campaign" → `?mode=new` → **Step 1 Setup** (empty wizard)
2. User fills Step 1 → **Next →** → Step 2 Audience → **Next →** → Step 3 Content → **Next →** → Step 4 Review
3. At Step 4:
   - **Save Draft** → POST CreateEmailSendJob with `JobStatusId=DRAFT` → stay on Step 4, show toast "Draft saved"
   - **Schedule Campaign** → confirm dialog → POST CreateEmailSendJob + POST ScheduleEmailCampaign → redirect to `?mode=read&id={newId}` → **LAYOUT 2 DETAIL**
   - **Send Now** (when SendJobType=SENDNOW) → confirm dialog → POST + Enqueue → redirect to DETAIL
4. From grid → row action ViewReport (🟦 `fa-chart-bar`) → `?mode=read&id=X` → DETAIL layout
5. From grid → row click on SCHEDULED/DRAFT → `?mode=edit&id=X` → wizard pre-filled
6. From DETAIL → Edit (non-SENT) → `?mode=edit&id=X`
7. From DETAIL → Duplicate → clones entity as new DRAFT → `?mode=edit&id={clonedId}`
8. Back button on any mode → `/emailcampaign` grid
9. Unsaved changes: dirty form → back/nav → confirm dialog

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer

**Canonical Reference**: SavedFilter (FLOW — same `notify` schema, same `NotifyModels` group); plus SMSCampaign (#30) / WhatsAppCampaign (#32) for wizard-step + report patterns.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | EmailSendJob | Entity/class name |
| savedFilter | emailSendJob | Variable/field names |
| SavedFilterId | EmailSendJobId | PK field |
| SavedFilters | EmailSendJobs | Table name, collection names |
| saved-filter | email-send-job | FE kebab-case (file names) |
| savedfilter | emailsendjob | FE folder (page-components) |
| SAVEDFILTER | EMAILCAMPAIGN | Grid code, menu code (note: UI uses "Campaign" not "SendJob") |
| notify | notify | DB schema (unchanged) |
| Notify | Notify | Backend group name (Models/Schemas/Business) |
| NotifyModels | NotifyModels | Namespace suffix |
| CRM_COMMUNICATION | CRM_COMMUNICATION | Parent menu code |
| CRM | CRM | Module code |
| crm/communication/savedfilter | crm/communication/emailcampaign | FE route path |
| notify-service | notify-service | FE service folder (unchanged) |

**Cross-reference** (for wizard/report mechanics):
- Wizard step progression + `StepProgress` component → **SMSCampaign #30**
- Rate-bar grid renderer → **WhatsAppCampaign #32** (rename if needed)
- HTML editor + `DeviceTypeSelector` persistent preview → **EmailTemplate #24**
- Placeholder chip bar → **PlaceholderDefinition #26**

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> **ALIGN scope**: most files already exist. List below marks `CREATE` (new) vs `MODIFY` (align to new fields/UI) vs `REFACTOR` (structural rework).

### Backend Files

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Entity | `Base.Domain/Models/NotifyModels/EmailSendJob.cs` | MODIFY (+13 new columns) |
| 2 | EF Config | `Base.Infrastructure/Data/Configurations/NotifyConfigurations/EmailSendJobConfiguration.cs` | MODIFY (+8 new FK configs, 2 unique filtered indexes on JobCode + JobName per Company) |
| 3 | Schemas (DTOs) | `Base.Application/Schemas/NotifySchemas/EmailSendJobSchemas.cs` | MODIFY (+13 Request fields + 13 Response fields + new `EmailSendJobSummaryDto` + new `ResolveAudiencePreviewDto`) |
| 4 | Create Command | `.../Business/NotifyBusiness/EmailSendJobs/Commands/CreateEmailSendJob.cs` | MODIFY (new validators: subject+from+campaignType+recipientSource+inline body XOR template; starter template key) |
| 5 | Update Command | `.../Commands/UpdateEmailSendJob.cs` | MODIFY (same validators + status-transition guard) |
| 6 | Delete Command | `.../Commands/DeleteEmailSendJob.cs` | MODIFY (only — guard: block delete when JobStatus=SENDING/SENT) |
| 7 | Toggle Command | `.../Commands/ToggleEmailSendJob.cs` | MODIFY (align to IsActive only) |
| 8 | **ScheduleEmailCampaign** (NEW) | `.../Commands/ScheduleEmailCampaignCommand.cs` | CREATE — transitions DRAFT→SCHEDULED, schedules Hangfire |
| 9 | **SendEmailCampaignNow** (NEW) | `.../Commands/SendEmailCampaignNowCommand.cs` | CREATE — transitions DRAFT→SENDING, enqueues Hangfire |
| 10 | **PauseEmailCampaign** (NEW) | `.../Commands/PauseEmailCampaignCommand.cs` | CREATE — ACTIVE→PAUSED, removes recurring Hangfire |
| 11 | **ResumeEmailCampaign** (NEW) | `.../Commands/ResumeEmailCampaignCommand.cs` | CREATE — PAUSED→ACTIVE, re-adds recurring Hangfire |
| 12 | **CancelEmailCampaign** (NEW) | `.../Commands/CancelEmailCampaignCommand.cs` | CREATE — SCHEDULED→CANCELLED, deletes Hangfire |
| 13 | **RetryEmailCampaign** (NEW) | `.../Commands/RetryEmailCampaignCommand.cs` | CREATE — FAILED→SENDING, re-enqueues |
| 14 | **DuplicateEmailCampaign** (NEW) | `.../Commands/DuplicateEmailCampaignCommand.cs` | CREATE — clone entity as new DRAFT, skip metrics |
| 15 | **ResolveAudiencePreview** (NEW) | `.../Queries/ResolveAudiencePreview.cs` | CREATE — resolves source+exclusions to {total, withEmail, without, unsub, net} + 10 sample rows; **SERVICE_PLACEHOLDER** until DynamicQueryBuilder lands |
| 16 | GetEmailSendJob (GetAll) | `.../Queries/GetEmailSendJob.cs` | MODIFY (+LINQ subqueries for openRatePct, clickRatePct; +filter by jobStatusId, campaignTypeId, dateFrom/dateTo; +search jobName/subjectLine) |
| 17 | GetEmailSendJobById | `.../Queries/GetEmailSendJobById.cs` | MODIFY (+Include for all 8 FKs; +child aggregates for DETAIL layout analytics cards) |
| 18 | **GetEmailSendJobSummary** (NEW) | `.../Queries/GetEmailSendJobSummary.cs` | CREATE — 4 KPI aggregates for Variant B widgets |
| 19 | **GetEmailCampaignReport** (NEW) | `.../Queries/GetEmailCampaignReport.cs` | CREATE — full analytics payload for DETAIL (funnel counts + breakdown + engagement + recipients) |
| 20 | ExportEmailSendJob | `.../Queries/ExportEmailSendJob.cs` | MODIFY (export filter + columns alignment) |
| 21 | SendTestEmail | `.../Commands/SendTestEmail.cs` | MODIFY (accept current wizard state — don't require existing EmailTemplateId) |
| 22 | Mutations | `Base.API/EndPoints/Notify/Mutations/EmailSendJobMutations.cs` | MODIFY (+7 new mutations: Schedule/SendNow/Pause/Resume/Cancel/Retry/Duplicate) |
| 23 | Queries | `Base.API/EndPoints/Notify/Queries/EmailSendJobQueries.cs` | MODIFY (+Summary + ResolveAudiencePreview + CampaignReport endpoints) |
| 24 | Migration | `Base.Infrastructure/Data/Migrations/{timestamp}_EmailSendJobAlign.cs` | CREATE (+13 new columns + FK constraints + unique filtered indexes) |
| 25 | DB Seed SQL | `sql-scripts-dyanmic/EmailCampaign-sqlscripts.sql` | CREATE (menu rename EMAILCAMPAIGN + 4 new MasterData TypeCodes + grid column update + 5 EMAILSTARTERTEMPLATE MasterData rows) |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `INotifyDbContext.cs` | (no change — DbSet already exists) |
| 2 | `NotifyDbContext.cs` | (no change) |
| 3 | `NotifyMappings.cs` | Add explicit Mapster for new Request→Entity + Entity→Response (new fields + new DTOs) |
| 4 | `DecoratorProperties.cs` | (no change — DecoratorNotifyModules already has entry) |
| 5 | Inverse nav props on: `Segment.cs`, `Tag.cs` (if tag entity exists) | Add `ICollection<EmailSendJob>` where applicable (for FK) |

### Frontend Files

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO Types | `src/domain/entities/notify-service/EmailSendJobDto.ts` | MODIFY (+13 new fields + new SummaryDto + new ResolveAudiencePreviewDto + 5 new starter-template + 7 workflow states) |
| 2 | GQL Query | `src/infrastructure/gql-queries/notify-queries/EmailSendJobQuery.ts` | MODIFY (+Summary + ResolveAudiencePreview + CampaignReport queries; +new fields on existing) |
| 3 | GQL Mutation | `src/infrastructure/gql-mutations/notify-mutations/EmailSendJobMutation.ts` | MODIFY (+7 workflow mutations) |
| 4 | Zustand Store | `src/application/stores/email-send-job-stores/email-send-job-store.ts` | MODIFY (+13 new form fields + audience preview state + wizard step state) |
| 5 | Page Config | `src/presentation/pages/crm/communication/emailsendjob.tsx` | MODIFY (align to Variant B — ScreenHeader + widgets + DataTableContainer `showHeader={false}`) |
| 6 | Index Container | `src/presentation/components/page-components/crm/communication/emailsendjob/index.tsx` | MODIFY (inject 4 KPI widget components + widgets row) |
| 7 | Index Page | `.../emailsendjob/index-page.tsx` | MODIFY (6 filter chips + Type dropdown + From/To date filters + widget wiring) |
| 8 | Data Table | `.../emailsendjob/data-table.tsx` | MODIFY (new columns incl. rate-bar Open/Click renderers + status-driven row actions + bulk actions drawer) |
| 9 | **view-page.tsx** | `.../emailsendjob/view-page.tsx` | **REFACTOR** from flat accordion to 4-step wizard router (detect mode + current step from URL query) |
| 10 | **WizardStepHeader** (NEW) | `.../emailsendjob/components/WizardStepHeader.tsx` | CREATE (reuse SMSCampaign #30 StepProgress pattern) |
| 11 | **Step1Setup** (NEW) | `.../emailsendjob/components/steps/Step1Setup.tsx` | CREATE — wraps new Step 1 fields + Campaign Type card selector |
| 12 | BasicInformation | `.../emailsendjob/components/BasicInformation.tsx` | MODIFY (keep Campaign Name + OrgUnit; move to Step 1; add Subject, Preheader, FromName, FromEmail, ReplyTo) |
| 13 | JobTypeSelection | `.../emailsendjob/components/JobTypeSelection.tsx` | **DELETE** — semantic replaced by Campaign Type in Step 1 + Schedule Options in Step 4 |
| 14 | **CampaignTypeSelector** (NEW) | `.../emailsendjob/components/CampaignTypeSelector.tsx` | CREATE — 3-card selector for Step 1 |
| 15 | **PlaceholderChipBar** (NEW) | `.../emailsendjob/components/PlaceholderChipBar.tsx` | CREATE — clickable `{{token}}` chips that insert at cursor (used in Step 1 + Step 3) |
| 16 | **Step2Audience** (NEW) | `.../emailsendjob/components/steps/Step2Audience.tsx` | CREATE — 2-col layout container |
| 17 | **RecipientSourcePicker** (NEW) | `.../emailsendjob/components/RecipientSourcePicker.tsx` | CREATE — 5-card radio with conditional sub-forms (Segment/Filter/Tag/Import/All) |
| 18 | **ExclusionsPanel** (NEW) | `.../emailsendjob/components/ExclusionsPanel.tsx` | CREATE — 3 exclusion fields |
| 19 | **AudiencePreviewPanel** (NEW) | `.../emailsendjob/components/AudiencePreviewPanel.tsx` | CREATE — 5 count stats + Preview toggle + mini-table (replaces `ContactPreviewList.tsx`) |
| 20 | ContactPreviewList | `.../emailsendjob/components/ContactPreviewList.tsx` | **DELETE** (folded into AudiencePreviewPanel) |
| 21 | FilterConfiguration + sub-folder `email-job-filter/` | `.../emailsendjob/components/FilterConfiguration.tsx` + 4 files | **DELETE or ABSORB**: if DynamicQueryBuilder is retired in favor of SavedFilter references, delete; else keep but only expose from within "Saved Filter" sub-form + "By Tag" builder flag in §⑫ |
| 22 | **Step3Content** (NEW) | `.../emailsendjob/components/steps/Step3Content.tsx` | CREATE — 2-col layout; left: StarterTemplatePicker + HTMLEditor + SendTestInline; right: LivePreviewPane sticky |
| 23 | **StarterTemplatePicker** (NEW) | `.../emailsendjob/components/StarterTemplatePicker.tsx` | CREATE — 5 fixed tiles |
| 24 | **SendTestEmailInline** (NEW) | `.../emailsendjob/components/SendTestEmailInline.tsx` | CREATE — inline input+button |
| 25 | SendTestEmailDialog | `.../emailsendjob/components/SendTestEmailDialog.tsx` | **DELETE** (replaced by inline) |
| 26 | **LivePreviewPane** (NEW) | `.../emailsendjob/components/LivePreviewPane.tsx` | CREATE — sticky right-col iframe with Desktop/Mobile toggle |
| 27 | TemplateConfiguration | `.../emailsendjob/components/TemplateConfiguration.tsx` | **DELETE** (split into StarterTemplatePicker + HTMLEditor + LivePreviewPane — absorb anything still needed) |
| 28 | EmailConfiguration + modal | `.../emailsendjob/components/EmailConfiguration*.tsx` | **DELETE or REPURPOSE** — provider selection should be automatic (company-default CompanyEmailConfiguration); keep modal for "add new sender" deep-link |
| 29 | **Step4Review** (NEW) | `.../emailsendjob/components/steps/Step4Review.tsx` | CREATE — 2-col; left: CampaignSummary + ScheduleOptionsPicker; right: PreSendChecklist |
| 30 | **CampaignSummaryCard** (NEW) | `.../emailsendjob/components/CampaignSummaryCard.tsx` | CREATE — 7-row readonly |
| 31 | **ScheduleOptionsPicker** (NEW) | `.../emailsendjob/components/ScheduleOptionsPicker.tsx` | CREATE — 3-card radio with sub-forms; absorbs existing ScheduleFields + RecurringFields |
| 32 | ScheduleFields | `.../emailsendjob/components/ScheduleFields.tsx` | MODIFY — absorb into sub-form of ScheduleOptionsPicker (add Timezone + Suggested Times chips) |
| 33 | RecurringFields | `.../emailsendjob/components/RecurringFields.tsx` | MODIFY — absorb into sub-form (simplify to Frequency+Day+Time computed cron; remove "custom cron expression" textarea from primary UX) |
| 34 | **PreSendChecklist** (NEW) | `.../emailsendjob/components/PreSendChecklist.tsx` | CREATE — 6 computed items |
| 35 | **DetailReportPage** (NEW) | `.../emailsendjob/components/DetailReportPage.tsx` | CREATE — LAYOUT 2 entry point |
| 36 | **CampaignMetaStrip** (NEW) | `.../emailsendjob/components/detail/CampaignMetaStrip.tsx` | CREATE — top header on DETAIL |
| 37 | **DeliveryFunnel** (NEW) | `.../emailsendjob/components/detail/DeliveryFunnel.tsx` | CREATE — 5-step horizontal funnel |
| 38 | **DeliveryBreakdownCard** (NEW) | `.../emailsendjob/components/detail/DeliveryBreakdownCard.tsx` | CREATE |
| 39 | **EngagementCard** (NEW) | `.../emailsendjob/components/detail/EngagementCard.tsx` | CREATE |
| 40 | **RecipientsTable** (NEW) | `.../emailsendjob/components/detail/RecipientsTable.tsx` | CREATE — paginated per-recipient ledger |
| 41 | JobStatusField | `.../emailsendjob/components/JobStatusField.tsx` | MODIFY — align to 7-state workflow, move to status-badge-only in Step 4 |
| 42 | Progression hooks | `.../emailsendjob/hooks/useSectionProgression.ts` + `useSectionCompletion.ts` | MODIFY — rename from "section" → "step" semantics; hard-code 4 steps (setup/audience/content/review) |
| 43 | SaveTemplateDialog | `.../emailsendjob/components/SaveTemplateDialog.tsx` | MODIFY (verify FE fetches EMAILTEMPLATESTATUS correctly per EmailTemplate #24 Session 2 contract) |
| 44 | OrganizationalUnitCreateModal | `.../emailsendjob/components/OrganizationalUnitCreateModal.tsx` | KEEP as-is (used in Step 1) |
| 45 | RecipientFilterBuilder + RecipientFilterDialog | `.../emailsendjob/components/RecipientFilter*.tsx` | DELETE or REPURPOSE — fold into "Saved Filter" sub-form of RecipientSourcePicker if still needed |
| 46 | `notify-service-entity-operations.ts` | `src/application/services/notify-service/*` | MODIFY — add new 7 workflow operations (Schedule, SendNow, Pause, Resume, Cancel, Retry, Duplicate) |
| 47 | Route Page | `src/app/[lang]/crm/communication/emailcampaign/page.tsx` | KEEP path; verify imports from new index.tsx |
| 48 | Shared renderers (3 registries) | `.../presentation/components/shared/column-renderers/*` + `basic/component-column.tsx` + `advanced/component-column.tsx` + `flow/component-column.tsx` | MODIFY — register `rate-bar` (if not from #30/#32), `email-campaign-row-actions`, `campaign-name-link` |
| 49 | Email starter templates resource | `src/resources/email-starter-templates.json` | CREATE — 5 starter HTML bodies |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `entity-operations.ts` | Add 7 workflow operations: `SCHEDULE_CAMPAIGN`, `SEND_NOW`, `PAUSE_CAMPAIGN`, `RESUME_CAMPAIGN`, `CANCEL_CAMPAIGN`, `RETRY_CAMPAIGN`, `DUPLICATE_CAMPAIGN` |
| 2 | `operations-config.ts` | Import + register above operations |
| 3 | Sidebar menu config (if menu rename needed) | Ensure `EMAILCAMPAIGN` (not `EMAILSENDJOB`) code is used |
| 4 | FE barrels (5 expected): `emailsendjob/components/index.ts`, `emailsendjob/components/steps/index.ts`, `emailsendjob/components/detail/index.ts`, `notify-stores/index.ts`, `shared-cell-renderers/index.ts` | Export new components + rendererss |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Email Campaigns
MenuCode: EMAILCAMPAIGN
ParentMenu: CRM_COMMUNICATION
Module: CRM
MenuUrl: crm/communication/emailcampaign
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: EMAILCAMPAIGN

AdditionalSeedData:
  MasterData TypeCodes (4 new + 1 extended):
    - EMAILCAMPAIGNTYPE: CAMPAIGN (teal), AUTOMATED (purple), NEWSLETTER (orange)
    - EMAILRECIPIENTSOURCE: SAVEDSEGMENT, SAVEDFILTER, BYTAG, IMPORTLIST, ALLCONTACTS
    - EMAILJOBSTATUS: DRAFT (slate), SCHEDULED (blue), SENDING (amber), SENT (green), PAUSED (amber), FAILED (red), CANCELLED (slate)
    - EMAILSTARTERTEMPLATE: CAMPAIGN_APPEAL, THANK_YOU, MONTHLY_NEWSLETTER, EVENT_INVITATION, BLANK
    - EMAILSENDJOBTYPE (existing — verify codes): SENDNOW, SCHEDULE, RECURRING

  Sample Campaigns: 3-5 sample campaigns across DRAFT / SCHEDULED / SENT / PAUSED / FAILED states for E2E testing

  Starter Template HTMLs: 5 HTML bodies (resources/email-starter-templates.json)
---CONFIG-END---
```

**Menu code migration note**: existing menu may be seeded as `EMAILSENDJOB`. Seed script must UPDATE existing row to `EMAILCAMPAIGN` + MenuName `Email Campaigns` + MenuUrl `crm/communication/emailcampaign` in a single idempotent UPDATE, NOT re-INSERT (to preserve role-capability rows).

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `EmailSendJobQueries`
- Mutation type: `EmailSendJobMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `emailSendJobs` (GetEmailSendJobs) | Paginated [EmailSendJobResponseDto] | searchText, pageNo, pageSize, sortField, sortDir, isActive, jobStatusId, campaignTypeId, dateFrom, dateTo |
| `emailSendJobById` (GetEmailSendJobById) | EmailSendJobResponseDto | emailSendJobId |
| `emailSendJobSummary` (GetEmailSendJobSummary) | EmailSendJobSummaryDto | — (CompanyScope from HttpContext) |
| `resolveAudiencePreview` (ResolveAudiencePreview) | ResolveAudiencePreviewDto | recipientSourceId, savedSegmentId?, savedFilterId?, recipientTagIds?, importListFileUrl?, excludeTagIds?, excludeSegmentId?, excludeRecentDays? |
| `emailCampaignReport` (GetEmailCampaignReport) | EmailCampaignReportDto | emailSendJobId |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createEmailSendJob` | EmailSendJobRequestDto | EmailSendJobRequestDto (incl. new ID) |
| `updateEmailSendJob` | EmailSendJobRequestDto | EmailSendJobRequestDto |
| `deleteEmailSendJob` | emailSendJobId | bool |
| `activateDeactivateEmailSendJob` | emailSendJobId | bool |
| `scheduleEmailCampaign` | emailSendJobId | EmailSendJobRequestDto (status=SCHEDULED) |
| `sendEmailCampaignNow` | emailSendJobId | EmailSendJobRequestDto (status=SENDING) |
| `pauseEmailCampaign` | emailSendJobId | bool |
| `resumeEmailCampaign` | emailSendJobId | bool |
| `cancelEmailCampaign` | emailSendJobId | bool |
| `retryEmailCampaign` | emailSendJobId | EmailSendJobRequestDto |
| `duplicateEmailCampaign` | emailSendJobId | EmailSendJobRequestDto (new cloned DRAFT) |
| `sendTestEmail` | SendTestEmailRequestDto (+ inline body + subject + from) | SendTestEmailResponseDto |

**Response DTO Fields** — `EmailSendJobResponseDto` (FE receives):

| Field | Type | Notes |
|-------|------|-------|
| emailSendJobId | number | PK |
| jobCode | string | — |
| jobName | string | — |
| subjectLine | string | NEW |
| preheaderText | string \| null | NEW |
| fromName | string | NEW |
| fromEmail | string | NEW |
| replyToEmail | string \| null | NEW |
| campaignTypeId | number | NEW FK |
| campaignTypeName | string | NEW denorm |
| sendJobTypeId | number | — |
| sendJobTypeName | string | — |
| jobStatusId | number | — |
| jobStatusName | string | — |
| jobStatusColorHex | string \| null | from MasterData.DataSetting |
| organizationalUnitId | number \| null | — |
| organizationalUnitName | string \| null | — |
| recipientSourceId | number | NEW |
| recipientSourceName | string | NEW |
| savedSegmentId | number \| null | NEW |
| savedSegmentName | string \| null | NEW denorm |
| savedFilterId | number \| null | — |
| savedFilterName | string \| null | denorm |
| recipientTagIds | string \| null | NEW (comma-separated) |
| importListFileUrl | string \| null | NEW |
| recipientTypeId | number \| null | — |
| recipientTypeName | string \| null | denorm |
| excludeTagIds | string \| null | NEW |
| excludeSegmentId | number \| null | NEW |
| excludeRecentDays | number \| null | NEW |
| emailConfigurationId | number \| null | — |
| emailTemplateId | number \| null | — |
| emailTemplateName | string \| null | denorm |
| inlineEmailBodyHtml | string \| null | NEW |
| starterTemplateKey | string \| null | NEW |
| scheduleStartDatetime | string (ISO) \| null | — |
| scheduleTimezone | string \| null | NEW |
| recurringCronExpression | string \| null | — |
| recurringEndDate | string (ISO) \| null | — |
| previewTotalRecordsMatched | number \| null | — |
| totalEmailsQueued | number \| null | — |
| totalEmailsSend | number \| null | — |
| totalEmailsFailed | number \| null | — |
| openRatePct | number \| null | NEW grid aggregation |
| clickRatePct | number \| null | NEW grid aggregation |
| lastExecutionStartedAt | string (ISO) \| null | — |
| lastExecutionEndedAt | string (ISO) \| null | — |
| nextExecutionAt | string (ISO) \| null | — |
| isActive | boolean | inherited |
| createdAt, modifiedAt | string (ISO) | inherited |

**EmailSendJobSummaryDto**: `{ totalCampaigns, thisMonthCount, emailsSentMonth, lastMonthEmailsSent, avgOpenRatePct, previousOpenRate, avgClickRatePct, previousClickRate }`

**ResolveAudiencePreviewDto**: `{ totalMatched, withEmail, pctWithEmail, withoutEmail, unsubscribedCount, netRecipients, sampleRecipients: [{ name, email, tags: [tagName] }] (10 rows) }`

**EmailCampaignReportDto** (for DETAIL): `{ funnel: {queued, sent, delivered, opened, clicked}, breakdown: {delivered, bouncedSoft, bouncedHard, spamReported, unsubscribed}, engagement: {uniqueOpens, totalOpens, uniqueClicks, totalClicks, avgTimeToOpenMins, topClickedLinks: [{url, clickCount}]}, recipientsPage: Paginated<{name, email, sentAt, status, opens, clicks, lastActivity}>, errorSummary: {message, stackTrace} | null }`

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (existing code may have 5 pre-existing SavedFilter errors per #27 ISSUE-10 — verify not regressed)
- [ ] Migration applies cleanly on fresh DB
- [ ] Incremental seed SQL applies idempotently (ON CONFLICT guards)
- [ ] `pnpm tsc --noEmit` — 0 errors in emailsendjob folder
- [ ] `pnpm dev` — page loads at `/{lang}/crm/communication/emailcampaign`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid: ScreenHeader renders, 4 KPI widgets render with real counts, DataTableContainer has no duplicate header
- [ ] Grid: 10 columns present (checkbox, Campaign Name, Type badge, Status badge, Recipients, Sent, Open Rate bar, Click Rate bar, Date, Actions)
- [ ] Grid: 6 filter chips filter by JobStatus
- [ ] Grid: Type dropdown + From/To date filters work
- [ ] Grid: Bulk actions drawer shows when ≥1 row selected
- [ ] Grid: Status-driven row actions render correctly per row state
- [ ] `?mode=new`: Wizard Step 1 renders; Step 2/3/4 disabled until Step 1 valid
- [ ] Step 1: 3-card Campaign Type selector persists; Subject field accepts `{{Placeholder}}` chips; From Email dropdown lists verified senders only
- [ ] Step 2: 5-card source picker swaps sub-form correctly; Exclusions panel persists; Audience Preview 5-count panel updates live (debounced 400ms); Preview Recipients toggle shows 10 sample rows
- [ ] Step 3: 5 starter tiles; selecting swaps editor content with confirm if dirty; toolbar buttons work; Insert Placeholder dropdown inserts at cursor; inline Send Test input + button (no modal); Live Preview pane sticky, updates on content/subject/from change; Desktop/Mobile toggle resizes preview
- [ ] Step 4: 7-row Campaign Summary computed; 3-card Schedule Options picker; Send Now shows no sub-form; Schedule for Later has Date/Time/Timezone + 2 Suggested chips (clickable auto-fill); Recurring has Frequency/Day/Time + computed cron helper; Pre-send Checklist renders 6 items
- [ ] Save Draft → creates with JobStatus=DRAFT; stays on step; toast "Draft saved"
- [ ] Schedule Campaign → confirm dialog → creates + schedules Hangfire → redirect to `?mode=read&id={newId}`
- [ ] Send Now workflow → confirm → enqueues Hangfire → redirect to DETAIL
- [ ] `?mode=read&id=X`: DETAIL renders campaign-report layout (NOT wizard-disabled) — Meta Strip + Delivery Funnel (5 steps) + Recipients Table + Delivery Breakdown + Engagement + Error Summary (if FAILED)
- [ ] Edit button on DETAIL (non-SENT) → `?mode=edit&id=X` → wizard pre-filled
- [ ] Status transitions: Pause/Resume/Cancel/Retry/Duplicate work from row actions
- [ ] FK ApiSelects load: OrganizationalUnit, SavedFilter, EmailTemplate, CompanyEmailConfiguration, Segment, Tag
- [ ] Send Test mutation succeeds with current wizard state (no saved template required)
- [ ] Permissions: Edit/Delete buttons respect BUSINESSADMIN capability
- [ ] Unsaved changes dialog triggers on dirty wizard navigation

**DB Seed Verification:**
- [ ] Menu `EMAILCAMPAIGN` visible in sidebar under CRM > Communication (order 2 — per MODULE_MENU_REFERENCE)
- [ ] Grid columns render correctly (10 columns with rate-bar renderers)
- [ ] GridFormSchema is NULL/SKIP (FLOW screen)
- [ ] 4 new MasterData TypeCodes seeded (EMAILCAMPAIGNTYPE / EMAILRECIPIENTSOURCE / EMAILJOBSTATUS / EMAILSTARTERTEMPLATE)
- [ ] MasterData rows have correct ColorHex in DataSetting (for status/type badges)
- [ ] Sample campaigns render in grid (≥3 rows spanning multiple statuses)
- [ ] UI uniformity grep — 5 standard checks pass (no `bg-primary`, no hex colors in JSX, no inline font-family, no `.eslintignore` bypasses, no `tsc` escapes)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**ALIGN-scope discipline:**
- DO NOT regenerate files from scratch. The existing `emailsendjob` folder has ~25 files; most stay, some REFACTOR, some DELETE. See §⑧ for action markers.
- The REFACTOR of `view-page.tsx` from flat accordion → 4-step wizard is the single largest piece of work. Read the existing file first; preserve status-awareness (`isFormEditable`, `canEditScheduleConfig`, etc.) and regulate it per step.
- Keep existing Zustand store + hooks — just extend/rename.
- Menu code migration: existing seed may have `EMAILSENDJOB` — UPDATE to `EMAILCAMPAIGN` (MenuName + MenuCode + MenuUrl) idempotently in a single statement; don't INSERT new row (would duplicate capabilities).

**Schema / FK notes:**
- `CompanyId` is NOT a form field — from HttpContext (existing convention)
- `EmailTemplateId` is nullable — campaign can use `InlineEmailBodyHtml` instead (XOR at send-time, not at save-time; allows DRAFT with neither)
- `RecipientTagIds` and `ExcludeTagIds` stored as comma-separated strings (NOT separate join table) — matches SMSCampaign #30 precedent for BYTAG filtering; store as `NVARCHAR(500)`
- Tag + Segment FKs: verify `GetTags` / `GetSegments` GraphQL queries exist; if not, mark BYTAG and SAVEDSEGMENT sub-forms as SERVICE_PLACEHOLDER (empty options list + TODO) — do NOT block the rest of the screen
- EmailJobStatus MasterData needs `ColorHex` in `DataSetting` JSON for status-badge coloring (precedent: SMSCampaign #30 SMSCAMPAIGNSTATUS)

**FLOW-specific:**
- FLOW screens do NOT generate GridFormSchema — SKIP it
- view-page.tsx handles ALL 3 modes (new/edit/read); read mode uses LAYOUT 2 (DetailReportPage), NOT a disabled wizard
- Wizard step gating uses `useSectionProgression` (reuse — rename internals from "section" to "step")

**Cross-screen dependencies:**
- **Closes SavedFilter #27 ISSUE-5** ("Save&Use Campaign handoff pending #25 verify") — after build, verify `?savedFilterId={id}` query param on `/emailcampaign?mode=new` auto-selects SAVEDFILTER source + pre-populates filter dropdown
- **Closes EmailTemplate #24 ISSUE-12** (cross-screen rename to emailsendjob) — verify `SaveTemplateDialog.tsx`, `SendTestEmailDialog.tsx` (DELETE), `TemplateConfiguration.tsx` (DELETE), `view-page.tsx` (REFACTOR) all resolve cleanly
- **Reuses EmailTemplate #24 artifacts**: `email-template-editor` component, `DeviceTypeSelector`, `StatusSegmentedToggle` pattern, `EMAILTEMPLATESTATUS` MasterData
- **Reuses PlaceholderDefinition #26 artifacts**: `type-badge` renderer (extend with 3 new variants for Campaign/Automated/Newsletter), `TypeBadgeRenderer`
- **Reuses SMSCampaign #30 artifacts**: `StepProgress` / `WizardStepHeader` pattern, `rate-bar` renderer (if not already shared), Delivery Funnel layout in DETAIL, status-driven row actions
- **Reuses WhatsAppCampaign #32 artifacts**: same report-layout precedent
- Pattern-match SMSCampaign #30 and WhatsAppCampaign #32 for: step gating logic, audience-preview debounce, workflow mutation names (`sendNow` / `cancel` / `pause` / `resume` vs alternatives)

**Service Dependencies (SERVICE_PLACEHOLDER — UI built, handler mocked):**
- ⚠ **DynamicQueryBuilder** — `ResolveAudiencePreview` query returns static/hardcoded counts until query engine lands. Affects Step 2 AudiencePreviewPanel live counts + Pre-send Checklist item 3. Same placeholder per SavedFilter #27 ISSUE-1.
- ⚠ **Suggested Best Times (Step 4 SCHEDULE sub-form)** — 2 hardcoded chips ("Tue 10:00 AM" / "Thu 2:00 PM") until engagement-prediction service exists
- ⚠ **Import List CSV ingest** (Step 2 IMPORTLIST) — upload stores file to object storage; actual CSV parsing + recipient list ingestion is a separate backend job (not in scope here — stub with file-upload only + "Processing..." placeholder)
- ⚠ **Automation Workflow trigger wiring** (CampaignType=AUTOMATED) — no Automation Workflow module yet (Wave 4). CampaignType card remains selectable but "Configure Trigger" link is a toast-placeholder until Wave 4
- ⚠ **AI-suggested Subject Line A/B tests** — NOT in mockup; NOT in scope
- ⚠ **Placeholder resolution in Live Preview** — static sample contact ("Sarah / sarah@example.com") hardcoded; no UI to swap sample contact
- ⚠ **Unsubscribe link validation** — Pre-send Checklist item 5 uses regex `{{UnsubscribeLink}}` or `/unsubscribe` — actual link-generation service is a separate concern (placeholder per EmailTemplate #24)

**Layout Variant:** `widgets-above-grid` → **Variant B MANDATORY**: ScreenHeader + widget components + DataTableContainer `showHeader={false}`. Violation = double-header UI bug (ContactType #19 precedent).

**DETAIL design source:** The HTML mockup does NOT include an analytics/report page. DETAIL layout is derived from SMSCampaign #30 / WhatsAppCampaign #32 report patterns + existing child table structure (`EmailJobAnalytics`, `EmailClickTracking`, `EmailWebhookEventLog`, `EmailSendQueue`, `EmailExecutionLog`). Solution Resolver may refine before UX Architect finalizes.

**Starter template seeding decision:** Store 5 HTMLs in a FE JSON file (`src/resources/email-starter-templates.json`) vs MasterData seed. Recommendation = JSON file (fast iteration, no migration round-trips for copy tweaks); `StarterTemplateKey` on entity only persists the key. Solution Resolver may override.

**Orchestrator patch expectations (precedent):**
- `type-badge` renderer — extend with 3 new variants (campaign/automated/newsletter) in 3 registries (basic/advanced/flow)
- `rate-bar` renderer — verify registered (SMSCampaign #30 may have created it; WhatsAppCampaign #32 may have extended it)
- Seed renderer-name check — ensure grid seed column names match FE-registered renderer names (SavedFilter #27 `icon-text-renderer` → `icon-text` precedent)

**Open bugs inherited from related screens (must not regress):**
- SavedFilter #27 ISSUE-1 (DynamicQueryBuilder SERVICE_PLACEHOLDER) → affects AudiencePreview here
- EmailTemplate #24 ISSUE-11 (stats-report SQL function) → may need re-apply after this migration
- SMSCampaign #30 ISSUE-2 (LastUsedAt hook from Campaign) → applies here too (EmailTemplate's LastUsedAt update when a campaign references it)

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
