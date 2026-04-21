---
screen: SMSCampaign
registry_id: 30
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
- [x] HTML mockup analyzed (LIST view with 4 KPI widgets + 3-STEP WIZARD form + REPORT detail view)
- [x] Existing code reviewed (FE stub at `src/app/[lang]/crm/sms/smscampaign/page.tsx` — `"Need to Develop"`; no BE entity)
- [x] Business rules + 7-state workflow extracted
- [x] FK targets resolved (SMSTemplate #29, Contact, Tag #22, Segment #22, SavedFilter #27, Language, Country, MasterData)
- [x] File manifest computed
- [x] Approval config pre-filled (MenuCode=SMSCAMPAIGN, ParentMenu=CRM_SMS, OrderBy=2, MenuUrl=crm/sms/smscampaign)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated (prompt-embedded — skip agent spawn per SavedFilter/Family precedent)
- [ ] Solution Resolution complete (prompt-embedded — FLOW + widgets-above-grid Variant B + 3-step wizard + separate report detail)
- [ ] UX Design finalized (Section ⑥ pre-analyzed — wizard form + report detail are DIFFERENT UIs)
- [ ] User Approval received
- [ ] Backend code generated
- [ ] Backend wiring complete (INotifyDbContext, NotifyDbContext, NotifyMappings, SMSTemplate inverse nav, DecoratorNotifyModules)
- [ ] Frontend code generated (index Variant B + view-page 3 modes with wizard FORM and report DETAIL + Zustand store)
- [ ] Frontend wiring complete (entity-operations, sidebar, barrels, column-type registries)
- [ ] DB Seed script generated (GridFormSchema: SKIP for FLOW; 5 new MasterData TypeCodes; 3-4 sample campaigns)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` — 0 errors
- [ ] `pnpm dev` — page loads at `/{lang}/crm/sms/smscampaign`
- [ ] Grid loads with 4 KPI widgets above (Variant B — ScreenHeader + widgets + DataTableContainer showHeader={false})
- [ ] Grid columns render: Campaign Name, Template, Status badge, Recipients, Sent, Delivered (rate bar), Failed, DND Skipped, Cost, Date, Actions
- [ ] Row actions vary by status: Active(Auto) → View Log + Pause; Sent → View Report + Duplicate; Scheduled → Edit + Cancel; Draft → Edit + Delete
- [ ] `?mode=new` — 3-step wizard renders (Step 1: Setup, Step 2: Audience, Step 3: Review)
- [ ] Step 1: Campaign Name, Campaign Type (2 radio cards), Template dropdown (SMSTemplate ApiSelect), Sender ID dropdown, Schedule (2 radio cards), Quiet Hours toggle
- [ ] Step 2: Recipient Source (5 radio cards), conditional sub-selector per source, Audience Preview card (live counts), Exclusions checkboxes, Cost Estimate card, Country Distribution chips
- [ ] Step 3: Campaign Summary table + live SMS Preview bubble + Pre-send Checklist with warnings (budget, recently-messaged, quiet-hours)
- [ ] Wizard step navigation works (Next/Back) with validation gates
- [ ] "Send Now" opens confirmation modal showing net recipients + estimated cost + budget warning
- [ ] "Save Draft" saves without sending → redirects to `?mode=read&id={newId}` with draft status
- [ ] "Schedule" path: date/time/timezone picker appears when Schedule card selected → saves as Scheduled
- [ ] `?mode=edit&id=X` for Draft only — wizard loads pre-filled; Scheduled can also edit until lock window
- [ ] `?mode=read&id=X`:
  - For Draft → read-only wizard summary (or form disabled)
  - For Scheduled / Active-Auto / Sent → REPORT detail layout (Delivery Funnel + Breakdown + By-Country + Reply Summary + Recipients table) — completely different UI from the wizard
- [ ] Delivery Funnel renders 5 steps with arrows: Queued → DND Scrubbed → Sent → Delivered → Failed
- [ ] Recipients table loads (supports pagination — SERVICE_PLACEHOLDER until dispatch service wired)
- [ ] FK dropdowns (SMSTemplate, Segment, SavedFilter, Tag, Country for import) load via ApiSelectV2
- [ ] Audience Preview shows real counts after source selection (BE computes via LINQ — SERVICE_PLACEHOLDER where DynamicQueryBuilder absent)
- [ ] Cost Estimate updates live as Audience changes (server-computed — SERVICE_PLACEHOLDER)
- [ ] Unsaved changes dialog triggers on dirty wizard navigation
- [ ] Permissions: Edit/Delete/SendNow/Schedule/Pause respect role capabilities
- [ ] DB Seed — "SMS Campaigns" menu appears in sidebar under CRM → SMS

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: SMSCampaign
Module: Communication
Schema: notify
Group: NotifyModels (co-located with SMSTemplate, SavedFilter, NotificationTemplate, WhatsAppTemplate)

Business: The SMS Campaign screen lets Communication Admins compose, schedule, and dispatch outbound SMS messages — fundraising appeals, event reminders, donation receipts, membership renewal alerts, pledge reminders — to targeted audiences using pre-built **SMS Templates** (#29). A campaign binds ONE `SMSTemplate` (with mergeable `{{placeholder}}` tokens) to ONE `RecipientSource` (Saved Segment / Saved Filter / Tag / Import List / All Opted-in) and optionally to a `Schedule`. Per-recipient dispatch, delivery tracking, DND scrubbing, quiet-hour queuing, country-specific cost, and inbound reply capture are all tracked as child records. It is the **consumer** of the SMS Template library — every campaign picks one template. Two campaign types are supported: `Broadcast` (one-time manual send) and `Automated` (system-triggered by events like "donation received" or "pledge overdue" — linked to the future Automation Workflow screen #37). The screen has THREE distinct UIs on one `view-page.tsx`: a **grid list with 4 KPIs**, a **3-step wizard FORM** (for Draft/new), and a **delivery REPORT detail** (for Sent/Active/Scheduled) — these are structurally different layouts, not the same form in different states.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Audit columns (CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, CompanyId, IsActive) inherited from Entity base — NOT listed.
> **CompanyId is NOT a form field** — FLOW screens get tenant from HttpContext.

### Parent Table: `notify."SMSCampaigns"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| SMSCampaignId | int | — | PK | — | Primary key |
| SMSCampaignCode | string | 50 | YES | — | Unique per Company, upper-cased, auto-generated if empty (`SMC-{NNNN}`) |
| SMSCampaignName | string | 150 | YES | — | Unique per Company (user-visible) |
| CampaignTypeId | int | — | YES | `general.MasterDatas` (TypeCode=`SMSCAMPAIGNTYPE`: Broadcast/Automated) | Drives behavior — Automated type bypasses Schedule fields and registers a trigger |
| TriggerEvent | string | 100 | NO | — | When CampaignTypeId=Automated — event key (e.g., `donation.received`, `pledge.overdue`). NULL for Broadcast. SERVICE_PLACEHOLDER — wire to Automation Workflow #37 later |
| SMSTemplateId | int | — | YES | `notify.SMSTemplates` | The template to merge per-recipient. Must exist + template.TemplateStatus="Active" at send time |
| SenderType | string | 20 | YES | — | Enum: `"Alphanumeric"` \| `"PhoneNumber"`. Alphanumeric is reply-disabled. Country restrictions apply (US/Canada force PhoneNumber) |
| SenderValue | string | 50 | YES | — | Alphanumeric ID (e.g., `"HopeFound"`) or E.164 phone (e.g., `"+14155550100"`) — validated per SenderType |
| RecipientSource | string | 30 | YES | — | Enum: `"SavedSegment"` \| `"SavedFilter"` \| `"Tag"` \| `"ImportList"` \| `"AllOptedIn"` |
| RecipientSegmentId | int? | — | NO | `corg.Segments` | Populated when RecipientSource=`SavedSegment` |
| RecipientSavedFilterId | int? | — | NO | `notify.SavedFilters` | Populated when RecipientSource=`SavedFilter` |
| RecipientTagId | int? | — | NO | `corg.Tags` | Populated when RecipientSource=`Tag` |
| RecipientImportBatchRef | string? | 100 | NO | — | When RecipientSource=`ImportList` — external import batch reference (SERVICE_PLACEHOLDER — import store pending) |
| ScheduleMode | string | 20 | YES | — | Enum: `"SendNow"` \| `"Scheduled"`. For Automated campaigns, set to `"Triggered"` |
| ScheduledAt | DateTime? | — | NO | — | UTC. Populated when ScheduleMode=Scheduled |
| ScheduledTimezone | string? | 50 | NO | — | IANA tz name (e.g., `America/New_York`) — for display only; backend converts to UTC |
| RespectQuietHours | bool | — | YES | — | Default `true`. Promotional-category messages queue until 9 AM recipient local time |
| ExcludeTagId | int? | — | NO | `corg.Tags` | Optional — contacts with this tag are skipped |
| ExcludeSegmentId | int? | — | NO | `corg.Segments` | Optional — contacts in this segment are skipped |
| ExcludeRecentlyMessagedHours | int? | — | NO | — | Values: `null` / `12` / `24` / `48`. Contacts messaged by ANY SMS campaign within this window are skipped |
| SkipStopRepliers | bool | — | YES | — | Default `true`. Contacts who replied STOP are skipped (enforces regulatory opt-out) |
| SkipDNDRegistry | bool | — | YES | — | Default `true` and NOT UI-editable (mandatory per mockup — field disabled). Kept as a column to make the policy explicit and auditable per campaign |
| AudienceTotalCount | int | — | NO | — | Snapshotted at save. Total contacts before filters |
| AudienceWithMobileCount | int | — | NO | — | Contacts with a non-null PrimaryPhoneNumber |
| AudienceOptedInCount | int | — | NO | — | Contacts with `DoNotSMS = false` (or null) |
| AudienceDNDBlockedCount | int | — | NO | — | Estimated DND matches (SERVICE_PLACEHOLDER — DND registry API not wired) |
| AudienceNetRecipientsCount | int | — | YES | — | Computed: `OptedIn - DNDBlocked - Exclusions`. Displayed on review step |
| EstimatedCostCents | int | — | NO | — | Integer cents (avoid decimal precision). Computed from NetRecipients × segments × per-country rate |
| ActualCostCents | int | — | NO | — | Post-send. Populated by dispatch worker |
| BudgetCapCents | int? | — | NO | — | Optional per-campaign budget cap. If set + EstimatedCost exceeds, warning shown on review step |
| CampaignStatusId | int | — | YES | `general.MasterDatas` (TypeCode=`SMSCAMPAIGNSTATUS`) | Enum values: Draft/Scheduled/Sending/Sent/ActiveAuto/Paused/Cancelled/Failed. Workflow state — see ④ |
| SentAt | DateTime? | — | NO | — | Populated when status transitions to Sent |
| SegmentsPerMessage | int | — | NO | — | Snapshotted at save from SMSTemplate.SegmentCount (avoids cross-query at send time) |
| EnableReplyCapture | bool | — | YES | — | Default `true` when SenderType=PhoneNumber; forced `false` when Alphanumeric |
| LastRunAt | DateTime? | — | NO | — | For Automated campaigns — last trigger firing |
| LastRunCount | int? | — | NO | — | Count of messages sent on last trigger firing |

### Child Table: `notify."SMSCampaignRecipients"` (1:Many via SMSCampaignId, cascade delete)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| SMSCampaignRecipientId | int | — | PK | — | Primary key |
| SMSCampaignId | int | — | YES | `notify.SMSCampaigns` | FK parent |
| ContactId | int? | — | NO | `corg.Contacts` | NULL for Import List rows where contact not matched |
| ContactNameSnapshot | string | 150 | YES | — | Snapshot of DisplayName at queue time (audit stability) |
| PhoneNumberSnapshot | string | 30 | YES | — | E.164 at queue time |
| CountryId | int? | — | NO | `general.Countries` | Resolved from phone number |
| DeliveryStatusId | int | — | YES | `general.MasterDatas` (TypeCode=`SMSDELIVERYSTATUS`) | Queued / Sent / Delivered / Failed / DNDBlocked / StopBlocked |
| QueuedAt | DateTime? | — | NO | — | When worker picked up |
| SentAt | DateTime? | — | NO | — | When carrier accepted |
| DeliveredAt | DateTime? | — | NO | — | When carrier confirmed delivery |
| FailureReason | string? | 200 | NO | — | "Invalid number" / "Carrier rejected" / "DND blocked" / "Network error" |
| Segments | int | — | YES | — | Per-recipient segment count (usually matches SegmentsPerMessage but may differ if encoding flips) |
| CostCents | int | — | YES | — | Per-recipient cost (0 for DND/Stop-blocked) |
| ReplyText | string? | 500 | NO | — | Inbound SMS reply (SERVICE_PLACEHOLDER — reply webhook not wired) |
| ReplyReceivedAt | DateTime? | — | NO | — | When inbound reply landed |
| IsQuietHoursQueued | bool | — | YES | — | True if message was held until recipient local time |

> **Note**: `SMSCampaignRecipients` has NO inherited audit columns on purpose — this is a high-volume log table. Use a lean config without `IsActive`/`CreatedBy`/etc. (follow the `EmailSendQueue` precedent in NotifyModels).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` navigation) + Frontend Developer (`ApiSelectV2` queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| SMSTemplateId | SMSTemplate | `Base.Domain/Models/NotifyModels/SMSTemplate.cs` | `GetSMSTemplates` *(note: name is `GetSMSTemplates` — NOT `GetAllSMSTemplateList` — orchestrator post-patched this in SMS Template #29)* | SMSTemplateName | `SMSTemplateResponseDto` |
| CampaignTypeId | MasterData | `Base.Domain/Models/AppModels/MasterData.cs` | `GetAllMasterDataList` filtered by `MasterDataTypeCode=SMSCAMPAIGNTYPE` | MasterDataName | `MasterDataResponseDto` |
| CampaignStatusId | MasterData | same as above | filtered by `MasterDataTypeCode=SMSCAMPAIGNSTATUS` | MasterDataName (+ DataSetting hex for badge color) | `MasterDataResponseDto` |
| RecipientSegmentId | Segment | `Base.Domain/Models/CorgModels/Segment.cs` *(new from Tag/Segmentation #22 — verify exact group; if not CorgModels use what #22 wrote)* | `GetSegments` | SegmentName | `SegmentResponseDto` |
| RecipientSavedFilterId | SavedFilter | `Base.Domain/Models/NotifyModels/SavedFilter.cs` | `GetSavedFilters` | FilterName | `SavedFilterResponseDto` |
| RecipientTagId | Tag | `Base.Domain/Models/CorgModels/Tag.cs` *(new from Tag/Segmentation #22 — exact path per that screen — uses `HotChocolate.Types.Tag` aliasing)* | `GetTags` | TagName | `TagResponseDto` |
| ExcludeTagId | Tag | same as RecipientTagId | same | same | same |
| ExcludeSegmentId | Segment | same as RecipientSegmentId | same | same | same |
| ContactId *(child)* | Contact | `Base.Domain/Models/CorgModels/Contact.cs` | `GetContacts` (per Contact #18) | DisplayName | `ContactResponseDto` |
| CountryId *(child)* | Country | `Base.Domain/Models/GenModels/Country.cs` | `GetAllCountryList` | CountryName + CountryCode + Flag | `CountryResponseDto` |
| DeliveryStatusId *(child)* | MasterData | same as above | filtered by `MasterDataTypeCode=SMSDELIVERYSTATUS` | MasterDataName | `MasterDataResponseDto` |

**Also referenced (not FK):**

| Reference | Target | File Path | GQL Query | Purpose |
|-----------|--------|-----------|-----------|---------|
| SMS Template preview | SMSTemplate | `Base.Domain/Models/NotifyModels/SMSTemplate.cs` | `GetSMSTemplateById` | For live phone preview bubble in Step 3 |
| Audience Preview counts | Contact (aggregate) | — | new custom query `PreviewSMSCampaignAudience` (see §⑩) | Returns live counts when source changes in Step 2 |

> **Verify during build**: confirm Tag.cs + Segment.cs live under `CorgModels` (not `ContactModels` — Tag #22 used CorgModels per registry notes). The Explore subagent reported "ContactModels" but Tag/Segmentation #22 registry note uses CorgModels-compatible paths; canonicalize via glob before writing Mapster config.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `SMSCampaignName` must be unique per Company
- `SMSCampaignCode` must be unique per Company (auto-generated `SMC-{NNNN}` if empty)

**Required Field Rules:**
- `SMSCampaignName`, `CampaignTypeId`, `SMSTemplateId`, `SenderType`, `SenderValue`, `RecipientSource`, `ScheduleMode`, `CampaignStatusId` — mandatory
- Step 1 required: Name, Type, Template, Sender, Schedule
- Step 2 required: RecipientSource (+ conditional FK per source)
- Step 3 required: gate on Checklist — any `isCritical` failure blocks Send Now

**Conditional Rules:**
- If `RecipientSource = "SavedSegment"` → `RecipientSegmentId` required
- If `RecipientSource = "SavedFilter"` → `RecipientSavedFilterId` required
- If `RecipientSource = "Tag"` → `RecipientTagId` required
- If `RecipientSource = "ImportList"` → `RecipientImportBatchRef` required — SERVICE_PLACEHOLDER (upload widget mocked)
- If `RecipientSource = "AllOptedIn"` → no extra FK; query all Contacts WHERE DoNotSMS=false AND PrimaryPhoneNumber IS NOT NULL
- If `CampaignTypeId = "Automated"` → `ScheduleMode = "Triggered"`, `ScheduledAt = null`, `TriggerEvent` required — wizard Step 1 hides the Schedule card and Step 3 hides the Send Now modal; save creates an ActiveAuto campaign
- If `ScheduleMode = "Scheduled"` → `ScheduledAt` required (must be > now + 5 min buffer) AND `ScheduledTimezone` required
- If `SenderType = "Alphanumeric"` → `EnableReplyCapture` forced to `false`
- If `SenderType = "PhoneNumber"` → `SenderValue` must pass E.164 regex `^\+[1-9]\d{1,14}$`
- If `SenderType = "Alphanumeric"` → `SenderValue` max 11 chars, alphanumeric only, case-preserved
- If audience contains US/Canada recipients AND `SenderType = "Alphanumeric"` → show warning on Step 3 Checklist (not blocked — dispatch will fall back to phone auto-selected by worker)
- If `BudgetCapCents` is set AND `EstimatedCostCents > BudgetCapCents` → show Checklist warning (not blocked — user can still send)
- If `ExcludeRecentlyMessagedHours` is set → exclude contacts in `SMSCampaignRecipients` where DeliveredAt > (now - hours)

**Business Logic (send-time — mostly SERVICE_PLACEHOLDER):**
1. On `SendNow` or `Schedule` action:
   - Re-evaluate audience counts at the moment of save
   - Snapshot `SegmentsPerMessage` from current template.SegmentCount
   - Materialize `SMSCampaignRecipients` rows (status=`Queued`) for each net recipient (SERVICE_PLACEHOLDER — LINQ-based resolution works; real DynamicQueryBuilder would power Segment/SavedFilter — use simple Segment.RulesJson=empty → all contacts fallback, same pattern as SavedFilter #27 ISSUE-1)
   - Compute `EstimatedCostCents` = `AudienceNetRecipientsCount × SegmentsPerMessage × baseRateCents` (baseRate default 4¢; country overrides deferred — SERVICE_PLACEHOLDER)
   - Transition `CampaignStatusId` → `Sending` (SendNow) or `Scheduled` (Schedule) or `ActiveAuto` (Automated)
2. On `Duplicate` action: clones the campaign with `_copy` suffix, `CampaignStatusId = Draft`, resets audience snapshots, `SentAt = null`, recipients-table not cloned
3. On `Pause` (Automated only): `CampaignStatusId = Paused`, trigger worker stops firing
4. On `Resume`: `CampaignStatusId = ActiveAuto`
5. On `Cancel` (Scheduled only, before SentAt): `CampaignStatusId = Cancelled`
6. On SMS delivery webhook (SERVICE_PLACEHOLDER): update `SMSCampaignRecipients.DeliveryStatusId`, `DeliveredAt`, `FailureReason`; aggregate into parent campaign's live funnel

**Workflow** (state machine — transitions implemented as explicit mutations):
- States (`SMSCAMPAIGNSTATUS` MasterData): `Draft` → `Scheduled` → `Sending` → `Sent` (terminal)
- Alt path: `Draft` → `Sending` (SendNow) → `Sent` (terminal)
- Automated path: `Draft` → `ActiveAuto` ↔ `Paused` (looping)
- Exception paths: any state → `Cancelled` (user) or `Failed` (worker)
- Transition commands (see §⑧ File Manifest and §⑩ BE→FE Contract):
  - `SaveSMSCampaignDraft` — save with CampaignStatusId=Draft (default Create path)
  - `SendSMSCampaignNow` — Draft → Sending → Sent
  - `ScheduleSMSCampaign` — Draft → Scheduled
  - `PauseSMSCampaign` — ActiveAuto → Paused
  - `ResumeSMSCampaign` — Paused → ActiveAuto
  - `CancelSMSCampaign` — Draft|Scheduled → Cancelled
  - `DuplicateSMSCampaign` — returns new SMSCampaignId (Draft)
- Side effects: `SentAt` stamped on Sent transition, `LastRunAt`+`LastRunCount` on Automated trigger
- Guard rails: `DeleteSMSCampaign` only allowed when `CampaignStatusId ∈ {Draft, Cancelled, Failed}` (Sent/ActiveAuto/Paused → BadRequestException with message "Cannot delete an in-flight or sent campaign; cancel it first")

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions.

**Screen Type**: FLOW
**Type Classification**: Transactional multi-step wizard (create/edit) + delivery-report dashboard (read)
**Reason**: `+New Campaign` opens a full-page 3-step wizard (NOT a modal) — so it's FLOW, not MASTER_GRID. The read mode renders a **completely different UI** (funnel + breakdowns + recipients table — a dashboard-style detail page) that the wizard form cannot fit. The list view needs 4 KPI widgets above the grid → Variant B layout (ScreenHeader + widgets + DataTableContainer showHeader={false}) is MANDATORY to avoid the double-header bug (ContactType #19 precedent).

**Backend Patterns Required:**
- [x] Standard CRUD (11 base files)
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Nested child creation — `SMSCampaignRecipient` 1:Many (materialized at send-time)
- [x] Multi-FK validation (`ValidateForeignKeyRecord` × 8 — SMSTemplate, Segment, SavedFilter, Tag×2, Country, 3×MasterData TypeCodes)
- [x] Unique validation — `SMSCampaignName`, `SMSCampaignCode` per Company
- [x] Workflow commands — `SendSMSCampaignNow`, `ScheduleSMSCampaign`, `PauseSMSCampaign`, `ResumeSMSCampaign`, `CancelSMSCampaign`, `DuplicateSMSCampaign` (6 extra commands)
- [x] Summary query — `GetSMSCampaignSummary` (4 KPI widget values — see §⑥)
- [x] Report query — `GetSMSCampaignReport` (funnel + breakdown + by-country + reply + recipients aggregate)
- [x] Audience Preview query — `PreviewSMSCampaignAudience` (live counts, country distribution)
- [x] Custom business rule validators — SenderType format, ScheduledAt buffer, RecipientSource-source FK consistency, delete-guard by status
- [ ] File upload command — N/A (Import List deferred to Contact Import #23)

**Frontend Patterns Required:**
- [x] FlowDataTable (grid — table display mode, NOT card-grid — transactional list per mockup)
- [x] **Variant B** layout (ScreenHeader + 4 KPI widgets + FlowDataTableContainer showHeader={false})
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] Multi-step wizard UI for new/edit modes (3 steps with step-progress bar)
- [x] React Hook Form with per-step validation gates
- [x] Zustand store (`sms-campaign-store.ts` — tracks currentStep, audiencePreview, costEstimate, excludedFlags, reviewChecklist)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back, Save Draft, Next, Back, Send Now buttons per step)
- [x] **Different DETAIL UI** — NOT fieldset-disabled form; a report dashboard with funnel + breakdown tables + recipients table
- [x] Workflow status badge on grid rows (color-coded per SMSCAMPAIGNSTATUS MasterData.DataSetting hex)
- [x] Row actions that vary by status (Active-Auto → Pause, Sent → View Report, Scheduled → Edit/Cancel, Draft → Edit/Delete)
- [x] 4 summary widget cards above grid
- [x] Grid aggregation columns: Delivery rate-bar (Delivered / Sent %), Failed %, DND Skipped count, Cost
- [x] Per-step radio-card-groups (Campaign Type, Schedule, Recipient Source) — reusable `<RadioCardGroup>` widget
- [x] Live Audience Preview card (updates on source change — fires `PreviewSMSCampaignAudience`)
- [x] Country Distribution chips (top 5 from audience preview)
- [x] Live SMS Preview bubble (Step 3 — reuses phone-preview component from SMS Template #29 with placeholders merged)
- [x] Pre-send Checklist with severity icons (success/warning)
- [x] Send Confirmation Modal (Step 3 → "Send Now" → modal → Confirm & Send)
- [x] Delivery Funnel component (5 steps with arrows — detail layout)
- [x] Delivery Breakdown / By-Country / Reply Summary / Recipients tables (detail layout)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted from `html_mockup_screens/screens/communication/sms-campaigns.html`.
> **CRITICAL**: FORM (wizard) and DETAIL (report) are DIFFERENT UIs — not the same component in different states.

### Grid/List View

**Display Mode**: `table` (default — transactional list, NOT card-grid)

**Grid Layout Variant**: `widgets-above-grid` → **Variant B** MANDATORY (ScreenHeader + widgets + `<DataTableContainer showHeader={false}>`). Missing this will double-header-bug.

**Page Widgets / Summary Cards** (mockup lines 385-418 — 4 KPI cards above grid):

| # | Widget Title | Value Source | Display Type | Icon | Color Scheme | Subtitle |
|---|-------------|-------------|-------------|------|-------------|----------|
| 1 | Campaigns Sent (Month) | summary.campaignsSentMonth | integer | `ph:chat-circle-dots` | sms-blue | "This week: {n}" (summary.campaignsSentWeek) |
| 2 | Messages Sent (Month) | summary.messagesSentMonth | integer | `ph:paper-plane-tilt` | blue | "Segments: {n}" (summary.segmentsSentMonth) |
| 3 | Delivery Rate | summary.deliveryRatePct | percentage | `ph:check` | green | "vs Email: {x}% ↑/↓" (summary.deliveryRateDeltaPct) |
| 4 | Total Cost (Month) | summary.totalCostMonth | currency | `ph:currency-dollar` | purple | "Avg/campaign: {x}" (summary.avgCostPerCampaign) |

**Summary GQL Query**: `GetSMSCampaignSummary` returns `SMSCampaignSummaryDto { campaignsSentMonth, campaignsSentWeek, messagesSentMonth, segmentsSentMonth, deliveryRatePct, deliveryRateDeltaPct, totalCostMonth, avgCostPerCampaign }`. Delivery aggregation uses `SMSCampaignRecipients` — values will be 0 until dispatch worker wired (SERVICE_PLACEHOLDER fallback).

**Grid Columns** (in display order — 11 columns):

| # | Column Header | Field Key | Display Type | Renderer | Width | Sortable | Notes |
|---|--------------|-----------|-------------|----------|-------|----------|-------|
| 1 | Campaign Name | smsCampaignName | text | `campaign-name-link` *(new — row.smsCampaignName bold; click → mode=read)* | auto | YES | Primary click target |
| 2 | Template | smsTemplateName | text | `template-ref-mono` *(new — mono-font slug style)* | 180px | YES | From SMSTemplate.SMSTemplateName |
| 3 | Status | campaignStatusName | badge | `status-badge` *(existing)* | 120px | YES | Color from MasterData.DataSetting |
| 4 | Recipients | audienceNetRecipientsCount | integer-or-Auto | `recipients-count` *(new — shows `Auto` if CampaignTypeId=Automated else integer)* | 100px | YES | — |
| 5 | Sent | totalSentCount | integer | plain | 80px | YES | From aggregate query on recipients (status ≥ Sent) |
| 6 | Delivered | deliveredWithRate | rate-bar | `rate-bar-percent` *(new — mini bar + count (pct%))* | 180px | YES | Composite `{count, percent, color}` — green ≥90%, amber 70-90%, red <70% |
| 7 | Failed | failedWithPercent | text | `count-with-percent` *(new — `123 (5.0%)`)* | 100px | YES | — |
| 8 | DND Skipped | dndSkippedCount | integer | `italic-muted-count` *(new — italic, muted color; shows `Est. ~110` for pre-send)* | 100px | YES | — |
| 9 | Cost | actualOrEstimatedCost | currency-with-warning | `cost-cell` *(new — `$X.XX`; prefix `Est.` if CampaignStatusId=Draft/Scheduled; warning icon if Estimated > BudgetCap)* | 110px | YES | — |
| 10 | Date | campaignDate | text-or-Always | `campaign-date-cell` *(new — `Apr 1` for Sent; `Always` for ActiveAuto; `—` for Draft)* | 90px | YES | Computed from ScheduledAt/SentAt/CampaignTypeId |
| 11 | Actions | — | row-actions | `smscampaign-row-actions` *(new — status-aware menu)* | 140px | NO | See below |

**Status-aware Row Action Menu** (per-row actions differ by CampaignStatus):

| Status | Actions |
|--------|---------|
| `Draft` | Edit (→mode=edit) · Delete (with confirm) |
| `Scheduled` | Edit · Cancel (confirm) |
| `Sending` | View Progress (→mode=read — read-only funnel view) |
| `Sent` | View Report (→mode=read — full report layout, PRIMARY action) · Duplicate |
| `ActiveAuto` | View Log (→mode=read — running stats) · Pause (warning-style button) |
| `Paused` | View Log · Resume |
| `Cancelled` | Duplicate · Delete |
| `Failed` | View Log · Duplicate · Delete |

**Filter Chips Bar** (above grid — new set):
| Chip | Filter |
|------|--------|
| All (default) | all statuses |
| Draft | campaignStatusCode=DRAFT |
| Scheduled | campaignStatusCode=SCHEDULED |
| Active | campaignStatusCode IN (ActiveAuto, Paused) |
| Sent | campaignStatusCode=SENT |

**Search/Filter Fields**: searchText (Name + TemplateName), templateId select, statusId select, typeId select, dateFrom / dateTo

**Row Click**: Navigates to `?mode=read&id={id}` (DETAIL/REPORT layout — see LAYOUT 2).

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

```
URL MODE                              UI LAYOUT
─────────────────────────────────     ─────────────────────────────────────────
/crm/sms/smscampaign?mode=new     →   LAYOUT 1: FORM (3-step wizard, empty)
/crm/sms/smscampaign?mode=edit&id →   LAYOUT 1: FORM (3-step wizard, pre-filled) — only allowed if status ∈ {Draft, Scheduled, ActiveAuto-meta-edit}
/crm/sms/smscampaign?mode=read&id →   LAYOUT 2: REPORT DETAIL (funnel + breakdown + by-country + recipients — NOT the wizard disabled)
```

> **The two layouts are completely different components**, sharing only the `FlowFormPageHeader` and the URL mode dispatch at the top of `view-page.tsx`. Implement them as two sibling page-component files imported by `view-page.tsx`.

---

#### LAYOUT 1: FORM (mode=new & mode=edit) — 3-STEP WIZARD

> Full-page wizard at `?mode=new` or `?mode=edit&id=X`. Built with React Hook Form + zod validation + Zustand for cross-step state. Must match mockup exactly.

**Page Header**: `FlowFormPageHeader` (title: `"Create SMS Campaign"` / `"Edit {name}"`; actions: Cancel (→list), persistent "Save Draft" secondary, step-contextual primary (Next / Send Now))

**Step Progress Bar** (mockup lines 604-620 — top of wizard):
- Step 1: "Campaign Setup" (fa-cog or ph:gear)
- Step 2: "Select Audience" (fa-users or ph:users)
- Step 3: "Review & Send" (fa-paper-plane or ph:paper-plane-tilt)
- Active step: accent background; completed step: green check; connector: green fill on completion

**Section Container Type**: `stepped-card` (each step renders inside a `step-content-card` with step-title + step-desc header)

---

##### STEP 1 — Campaign Setup

**Layout**: single card, 6 stacked form groups, full-width.

| # | Field | Widget | Layout | Placeholder | Validation |
|---|-------|--------|--------|-------------|------------|
| 1.1 | Campaign Name | text input | full-width | "Enter campaign name" | required, unique per Company |
| 1.2 | Campaign Type | **RadioCardGroup** (2 cards) | flex-row, flex-wrap | — | required — defaults to Broadcast |
| 1.3 | Template | **ApiSelectV2** → SMSTemplate | full-width | "Select a template..." | required; optionLabel shows `"{name} — {category} · {language} · {chars} chars · {segs} segment(s)⚠"` (⚠ if segs > 1); filters to `TemplateStatus=Active` |
| 1.4 | Sender ID | select (from Company config) | full-width | — | required; options: `"HopeFound (Alphanumeric — no replies)"`, `"+1 415 555 0100 (Phone number — replies enabled)"`. **Hint text**: "Alphanumeric sender IDs are not supported in US/Canada. Phone number will be used automatically for those recipients." |
| 1.5 | Schedule | **RadioCardGroup** (2 cards: Send Now / Schedule) | flex-row | — | required — defaults to Send Now |
| 1.5a | Scheduled At + Timezone | DateTimePicker + TimezoneSelect | 2-column, appears only when Schedule=Schedule card selected | — | required when visible; ScheduledAt > now + 5min |
| 1.6 | Respect Quiet Hours | toggle switch (in sub-card with label + description) | full-width pill | — | default `true` |

**Campaign Type RadioCardGroup**:
| Card | Emoji/Icon | Title | Description | Triggers |
|------|-----------|-------|-------------|----------|
| broadcast | 📢 | Broadcast | One-time bulk send to selected audience | default (hides TriggerEvent, shows Schedule) |
| automated | 🔁 | Automated | Triggered by system event (links to automation workflows) | Hides Schedule card + shows TriggerEvent select (SERVICE_PLACEHOLDER — TriggerEvent options hardcoded to mock list until Automation Workflow #37 ships) |

**Schedule RadioCardGroup**:
| Card | Emoji | Title | Description | Effect |
|------|-------|-------|-------------|--------|
| send_now | 🚀 | Send Now | Send immediately after confirmation | ScheduledAt=null |
| scheduled | 📅 | Schedule | Choose date, time, and timezone | Reveals DateTimePicker + TimezoneSelect |

**Step 1 Footer**: right-aligned `Next →` (primary); disabled until all required Step 1 fields valid.

---

##### STEP 2 — Select Audience

**Layout**: single card, 5 sub-sections.

**Section 2.1 — Recipient Source** (RadioCardGroup, 5 cards, wrap on narrow):

| Card | Emoji | Title | Revealed Sub-field |
|------|-------|-------|---------------------|
| saved_segment | 📋 | Saved Segment | ApiSelectV2 → Segment |
| saved_filter | 🔍 | Saved Filter | ApiSelectV2 → SavedFilter |
| by_tag | 🏷️ | By Tag | ApiSelectV2 → Tag |
| import_list | 📁 | Import List | **SERVICE_PLACEHOLDER** — File upload stub + toast "Contact Import coming with screen #23" |
| all_opted_in | 👥 | All Opted-in | No sub-field (selected by default per mockup) |

**Section 2.2 — Audience Preview** (inline muted card — mockup lines 738-762 — title icon `fa-users` / `ph:users`):

Fetched via `PreviewSMSCampaignAudience(recipientSource, sourceId)` — updates on source change AND on exclusion change. Renders 5 rows:

| Row | Label | Value | Notes |
|-----|-------|-------|-------|
| 1 | Total Contacts | `{total}` | integer |
| 2 | With mobile number | `{withMobile} ({pct}%)` | pct = withMobile/total |
| 3 | Opted-in for SMS | `{optedIn} ({pct}%)` | pct = optedIn/total |
| 4 | On DND registry | `~{dnd} (will be scrubbed)` in danger-red with 🚫 icon | SERVICE_PLACEHOLDER — estimate via heuristics |
| — | divider | — | — |
| 5 | **Net Recipients (estimated)** | `~{net}` in accent color, bold 1rem | bold + accent, row divider above |

**Section 2.3 — Exclusions** (checkboxes group — mockup lines 764-786 — title icon `fa-filter` / `ph:funnel`):

| Checkbox | Label | Fields Affected |
|----------|-------|-----------------|
| 1 | Exclude tag / Exclude segment | Reveals 2 ApiSelectV2 (Tag / Segment) when checked |
| 2 | Exclude recently messaged (within [select: 12h / 24h (default) / 48h]) | `ExcludeRecentlyMessagedHours` |
| 3 | Skip contacts who replied STOP (default checked) | `SkipStopRepliers` |
| 4 | Skip contacts on DND registry (mandatory — **disabled + checked**) | `SkipDNDRegistry` (always true, UI non-editable) |

**Section 2.4 — Cost Estimate** (muted card — mockup lines 788-807 — title icon `fa-calculator` / `ph:calculator`):

| Row | Label | Value |
|-----|-------|-------|
| 1 | Template segments | `{n} segment per message` (from Step 1 template) |
| 2 | Net recipients | `~{net}` |
| 3 | **Estimated cost** | `{net} × $0.04 = ~${total}` in accent bold |
| — | info-box | "Actual cost may vary by recipient country. International SMS may cost more." |

**Section 2.5 — Country Distribution** (chips row — mockup lines 809-819 — title icon `fa-globe` / `ph:globe`):

Top 5 countries from preview, rendered as `country-chip` pills: `🇺🇸 US: 1,890`. Data from `PreviewSMSCampaignAudience.countryDistribution[]`.

**Step 2 Footer**: `← Back` (secondary) | `Next →` (primary); Next disabled until source selection + (conditional sub-field) valid.

---

##### STEP 3 — Review & Send

**Layout**: single card, grid 2 columns (Summary left / SMS Preview right) + Checklist below.

**Section 3.1 — Campaign Summary** (left column — mockup lines 835-849 — `summary-table`):

| Row | Label | Value Source |
|-----|-------|--------------|
| 1 | Campaign | smsCampaignName |
| 2 | Type | CampaignTypeId name (Broadcast / Automated) |
| 3 | Template | `{smsTemplateName} ({category}, {language})` |
| 4 | Segments/msg | segmentsPerMessage |
| 5 | Sender ID | `{senderValue} ({senderType})` |
| 6 | Recipients | `~{net} (after DND scrub)` |
| 7 | Estimated Cost | `~${estimatedCost}` |
| 8 | Schedule | `Send Now` \| `{scheduledAt} {scheduledTimezone}` \| `Triggered (auto)` |
| 9 | Quiet Hours | `Respect (Promotional)` \| `Ignore (Transactional)` |

**Section 3.2 — SMS Preview** (right column — mockup lines 851-861 — reuse phone-preview from SMS Template #29):

Renders the SMS phone-bubble component with:
- Small centered "Today, 10:00 AM" header
- Blue bubble (sms-blue) with SMSTemplate body, placeholders merged with sample contact values (first contact in audience preview). If no audience, use literal placeholders visible.
- "10:00 AM ✓✓" meta footer

**Section 3.3 — Pre-send Checklist** (below grid — mockup lines 864-895 — styled card):

Computed server-side via `GetSMSCampaignChecklist(campaignId?)` returning array of `{ label, severity: success | warning | critical, linkUrl? }`. Examples:

| Icon | Severity | Message |
|------|----------|---------|
| ✓ | success | "Template active" |
| ✓ | success | "Recipients selected (~{net})" |
| ✓ | success | "All recipients opted-in for SMS" |
| ✓ | success | "DND registry scrubbed (est. {n} contacts removed)" |
| ⚠ | warning | "Budget warning: Estimated cost (${est}) exceeds remaining budget (${remaining}). [Increase budget cap] or reduce audience." |
| ⚠ | warning | "{n} contacts messaged in last 24 hours (will still send)" |
| ⚠ | warning | "Quiet hours: {n} {country} recipients — messages will queue until 9:00 AM {tz}" |
| ✗ | critical | (blocks Send Now — e.g., template missing DLT registration for India audience) |

**Step 3 Footer**: `← Back` | right group: `💾 Save Draft` (outline) + `📧 Send Now` (primary).

**Send Confirmation Modal** (mockup lines 1121-1134 — triggered by Send Now):
- Title: `"Confirm SMS Campaign Send"` with paper-plane icon
- Body: `"You are about to send ~{net} SMS messages (~{segments} segments). Estimated cost: ~${cost}. Messages to recipients in quiet-hour zones will be queued. This action cannot be undone."`
- Budget warning box (if budget exceeded) — amber styled
- Actions: Cancel + "Confirm & Send" (primary, dispatches `SendSMSCampaignNow` mutation)

---

##### Special Form Widgets

- **`<RadioCardGroup>`** — shared component used 3× (Type, Schedule, RecipientSource). Props: `options: { id, icon, title, description?, disabled? }[]`, `value`, `onChange`. Create at `presentation/components/shared/radio-card-group.tsx` if not already present; otherwise reuse Contact #18's `contact-type-card-selector` generalized version.
- **`<PhonePreviewBubble>`** — reuse from SMS Template #29 (`presentation/components/page-components/crm/sms/smstemplate/phone-preview.tsx`) — pass `templateBody`, `placeholderSampleValues`, `senderValue`.
- **`<AudiencePreviewCard>`** — new sub-component, takes `{ total, withMobile, optedIn, dndBlocked, net }` + re-fires on mount and on source change.
- **`<CostEstimateCard>`** — new, takes `{ segments, netRecipients, totalCents, currency }`.
- **`<CountryDistributionChips>`** — new, takes `{ countries: { code, name, count, flag }[] }`.
- **`<ChecklistList>`** — new, takes `{ items: { severity, message, linkUrl? }[] }`.

---

#### LAYOUT 2: DETAIL (mode=read) — DELIVERY REPORT DASHBOARD

> The read-only detail view for any non-Draft campaign. Structurally DIFFERENT from the wizard form. Must match mockup lines 908-1118 exactly.

**Page Header**: `FlowFormPageHeader` with:
- Back button → list
- Title: `"{smsCampaignName} — Campaign Report"` with `ph:chat-circle-dots` icon (sms-blue color)
- Meta row (below title): Template (mono) · Sender · Sent datetime · Recipients count
- Actions (right):
  - `Sent` status: Export CSV (SERVICE_PLACEHOLDER) + Duplicate
  - `ActiveAuto` status: View Log (jump to recipients table) + Pause
  - `Paused` status: Resume
  - `Scheduled` status: Edit (→mode=edit) + Cancel
  - `Sending` status: (no actions — in-flight)
  - `Failed` status: Duplicate + Delete

**Page Layout**: single-column, stacked report cards (not 2-col — all cards full-width).

##### Card 1: Delivery Funnel (mockup lines 927-956)

Horizontal 5-step funnel with arrows between. Each step is a `funnel-step` card with:

| Step | Value Source | Label | Pct Footer |
|------|-------------|-------|-----------|
| 1 | `queued` (count) | Queued | — |
| 2 | `dndScrubbed` | DND Scrubbed | `Removed` (warning amber) |
| 3 | `totalSent` | Sent | — |
| 4 | `delivered` | Delivered | `{pct}%` (success green) |
| 5 | `failed` | Failed | `{pct}%` (danger red) |

Separator: `fa-arrow-right` / `ph:arrow-right` between each step.

##### Card 2: Delivery Breakdown (mockup lines 958-985)

Report card with title `"Delivery Breakdown"` (icon `fa-chart-pie` / `ph:chart-pie`). Table inside with columns `Status | Count | %`:

| Row | Icon | Label | Count | Pct |
|-----|------|-------|-------|-----|
| 1 | ✓ success | Delivered | count | % |
| 2 | ✗ danger | Failed | count | % |
| 3 | (colspan=3 footer row) | — | — | `Failed reasons: Invalid number (42), Carrier rejected (28), DND blocked (18), Network error (17)` |

##### Card 3: Delivery by Country (mockup lines 987-1036)

Report card with title `"Delivery by Country"` (icon `fa-globe` / `ph:globe`). Table with columns `Country | Sent | Delivered | Failed | Cost`:

Rows: one per country present in `SMSCampaignRecipients` grouped by CountryId. Country cell shows `{flag} {CountryName}`. Delivered shows `count (pct%)`, Failed same format. Cost shows `${sum}`.

##### Card 4: Reply Summary (mockup lines 1038-1056)

Report card with title `"Reply Summary"` (icon `fa-reply` / `ph:arrow-u-up-left`). Body contains:
- Label row: Total Inbound Replies + big number
- Keyword chips: `STOP (8)`, `DONATE (12)`, `YES (6)`, `Other (19)` — categorized by classifier (SERVICE_PLACEHOLDER — until reply webhook wired, all chips show 0)
- Outline button: "View All Replies" (opens modal with full replies list — SERVICE_PLACEHOLDER, show empty-state)

##### Card 5: Recipients Table (mockup lines 1058-1117)

Report card with title `"Recipients"` (icon `fa-users` / `ph:users`). Inside, paginated table with columns:

| # | Header | Field | Renderer |
|---|--------|-------|----------|
| 1 | Contact | contactNameSnapshot | bold text |
| 2 | Phone | phoneNumberSnapshot | plain text |
| 3 | Country | countryCode + countryName | `{flag} {code}` chip |
| 4 | Status | deliveryStatusId → MasterData | icon + badge (✓ Delivered / ✗ Failed / 🚫 DND Blocked / STOP Blocked) |
| 5 | Delivered At | deliveredAt | formatted + `(queued - quiet hrs)` badge if `isQuietHoursQueued=true` |
| 6 | Reply | replyText | pill-styled text badge in danger red if STOP, neutral for others; `—` if no reply |
| 7 | Cost | costCents / 100 | `$0.04` format |

Server-side paginated (use existing FlowDataTable/BasicDataTable pattern). Page size 25.

##### DETAIL layout if status = Draft

If `CampaignStatusId = Draft` AND user navigates to `?mode=read&id=X` directly, render a condensed read-only **wizard summary** (reuse Step 3 Summary table + SMS Preview + Checklist) with a big "Edit Campaign" button in the header. This mirrors the "show what it will do" pattern without the report metrics.

---

### Page Widgets & Summary Cards — see Grid/List View above (4 KPI widgets).

### Grid Aggregation Columns

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Sent | Count of recipients where DeliveryStatusId >= Sent | SUM by SMSCampaignId | LINQ subquery in GetAll projection |
| Delivered | Count + pct | SUM WHERE DeliveryStatusId=Delivered | LINQ subquery |
| Failed | Count + pct | SUM WHERE DeliveryStatusId=Failed | LINQ subquery |
| DND Skipped | Count | SUM WHERE DeliveryStatusId=DNDBlocked | LINQ subquery |
| Cost | SUM of CostCents /100 | SUM by SMSCampaignId | LINQ subquery |

> Implementation pattern: extend `GetAllSMSCampaignList` with LEFT JOIN subqueries on `SMSCampaignRecipients` aggregated by `SMSCampaignId`. Use `.GroupJoin(...)` or a precomputed `.Select(new SMSCampaignListDto { ..., deliveredCount = c.Recipients.Count(r => r.DeliveryStatusId == deliveredId) ... })`. SavedFilter #27's `SavedFilterSummaryBuilder` pattern is the canonical reference.

### User Interaction Flow

1. User lands on list → sees 4 KPIs + grid with 11 columns + 5 filter chips
2. Click `+ New Campaign` → `?mode=new` → wizard Step 1 (empty form, Broadcast+SendNow defaults)
3. Fills Step 1 → Next → Step 2 → selects source → audience + cost preview fire → Next → Step 3 → reviews → `Save Draft` OR `Send Now`
4. `Send Now` → modal confirm → server transitions Draft → Sending → Sent → redirect to `?mode=read&id={id}` → REPORT layout
5. From grid row click on Sent campaign → `?mode=read&id={id}` → REPORT layout
6. From grid row click on Draft → `?mode=read&id={id}` → summary + Edit button (not a wizard)
7. From grid row Edit on Draft/Scheduled → `?mode=edit&id={id}` → wizard pre-filled
8. From grid Pause (ActiveAuto) → mutation fires, row refreshes to Paused status
9. Back navigation: any wizard step → confirm unsaved if dirty → returns to list

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer

**Canonical References**: **SavedFilter** (FLOW) + **SMSTemplate** (sibling FLOW in same group/schema)

| Canonical (SavedFilter) | → This Entity | Context |
|------------------------|--------------|---------|
| SavedFilter | SMSCampaign | Entity/class name |
| savedFilter | smsCampaign | Variable/field names |
| SavedFilterId | SMSCampaignId | PK field |
| SavedFilters | SMSCampaigns | Table name, DbSet name |
| saved-filter | sms-campaign | FE kebab-case |
| savedfilter | smscampaign | FE folder + import paths + URL |
| SAVEDFILTER | SMSCAMPAIGN | Grid code, menu code, MasterData TypeCode prefix |
| notify | notify | DB schema — SAME |
| Notify | Notify | Backend group — SAME |
| NotifyModels | NotifyModels | Namespace suffix — SAME |
| notify-service | notify-service | FE service folder — SAME |
| notify-queries | notify-queries | — SAME |
| notify-mutations | notify-mutations | — SAME |
| CRM_COMMUNICATION | CRM_SMS | ParentMenuCode (MenuId 266) |
| CRM | CRM | Module code — SAME |
| crm/communication/savedfilter | crm/sms/smscampaign | FE route path |
| _COMMUNICATIONCONFIG_ | _SMS_ | Sidebar grouping |

**Additional canonical**: SMSTemplate (screen #29, same schema+group) for DbContext wiring, NotifyMappings pattern, seed SQL structure. Study `prompts/smstemplate.md` §⑧ + §⑨ before writing manifest/seeds.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Paths relative to repo root. Base folder: `PSS_2.0_Backend/PeopleServe/Services/Base/` and `PSS_2.0_Frontend/`.

### Backend Files — Base CRUD (11 files)

| # | File | Path |
|---|------|------|
| 1 | Parent Entity | `Base.Domain/Models/NotifyModels/SMSCampaign.cs` |
| 2 | Child Entity | `Base.Domain/Models/NotifyModels/SMSCampaignRecipient.cs` |
| 3 | Parent EF Config | `Base.Infrastructure/Data/Configurations/NotifyConfigurations/SMSCampaignConfiguration.cs` |
| 4 | Child EF Config | `Base.Infrastructure/Data/Configurations/NotifyConfigurations/SMSCampaignRecipientConfiguration.cs` |
| 5 | Schemas (DTOs) | `Base.Application/Schemas/NotifySchemas/SMSCampaignSchemas.cs` (RequestDto, ResponseDto, SummaryDto, ReportDto, AudiencePreviewDto, RecipientDto, ChecklistItemDto) |
| 6 | CreateCommand | `Base.Application/Business/NotifyBusiness/SMSCampaigns/CreateCommand/CreateSMSCampaign.cs` |
| 7 | UpdateCommand | `Base.Application/Business/NotifyBusiness/SMSCampaigns/UpdateCommand/UpdateSMSCampaign.cs` |
| 8 | DeleteCommand | `Base.Application/Business/NotifyBusiness/SMSCampaigns/DeleteCommand/DeleteSMSCampaign.cs` |
| 9 | ToggleCommand | `Base.Application/Business/NotifyBusiness/SMSCampaigns/ToggleCommand/ToggleSMSCampaign.cs` |
| 10 | GetAll Query | `Base.Application/Business/NotifyBusiness/SMSCampaigns/GetAllQuery/GetAllSMSCampaign.cs` |
| 11 | GetById Query | `Base.Application/Business/NotifyBusiness/SMSCampaigns/GetByIdQuery/GetSMSCampaignById.cs` |

### Backend Files — Workflow + Extras (8 files)

| # | File | Path |
|---|------|------|
| 12 | SendNow Command | `.../SMSCampaigns/SendNowCommand/SendSMSCampaignNow.cs` (transitions Draft → Sending → Sent; materializes recipients; SERVICE_PLACEHOLDER dispatch worker stub) |
| 13 | Schedule Command | `.../SMSCampaigns/ScheduleCommand/ScheduleSMSCampaign.cs` (Draft → Scheduled) |
| 14 | Pause Command | `.../SMSCampaigns/PauseCommand/PauseSMSCampaign.cs` (ActiveAuto → Paused) |
| 15 | Resume Command | `.../SMSCampaigns/ResumeCommand/ResumeSMSCampaign.cs` (Paused → ActiveAuto) |
| 16 | Cancel Command | `.../SMSCampaigns/CancelCommand/CancelSMSCampaign.cs` (Draft/Scheduled → Cancelled) |
| 17 | Duplicate Command | `.../SMSCampaigns/DuplicateCommand/DuplicateSMSCampaign.cs` (returns new SMSCampaignId as Draft) |
| 18 | Summary Query | `.../SMSCampaigns/GetSummaryQuery/GetSMSCampaignSummary.cs` (4 KPIs) |
| 19 | Report Query | `.../SMSCampaigns/GetReportQuery/GetSMSCampaignReport.cs` (funnel + breakdown + by-country + reply + recipients paged) |

### Backend Files — Audience (2 files)

| # | File | Path |
|---|------|------|
| 20 | Audience Preview Query | `.../SMSCampaigns/PreviewAudienceQuery/PreviewSMSCampaignAudience.cs` (counts + country distribution given `recipientSource` + `sourceId` + `exclusion` flags) |
| 21 | Checklist Query | `.../SMSCampaigns/GetChecklistQuery/GetSMSCampaignChecklist.cs` (pre-send checklist items for Step 3) |

### Backend Files — Migration + Endpoints (3 files)

| # | File | Path |
|---|------|------|
| 22 | EF Migration | `Base.Infrastructure/Data/Migrations/{timestamp}_SMSCampaign_Initial.cs` + `.Designer.cs` (2 files) |
| 23 | Mutations endpoint | `Base.API/EndPoints/Notify/Mutations/SMSCampaignMutations.cs` — registers Create/Update/Delete/Toggle/SendNow/Schedule/Pause/Resume/Cancel/Duplicate |
| 24 | Queries endpoint | `Base.API/EndPoints/Notify/Queries/SMSCampaignQueries.cs` — registers GetAll/GetById/GetSummary/GetReport/PreviewAudience/GetChecklist |

**Backend Total**: 24 new files (21 business + 2 migration + no more — Mutations/Queries count 2).

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Base.Application/Data/Persistence/INotifyDbContext.cs` | `DbSet<SMSCampaign>`, `DbSet<SMSCampaignRecipient>` |
| 2 | `Base.Infrastructure/Data/Persistence/NotifyDbContext.cs` | same DbSets |
| 3 | `Base.Application/Mappings/NotifyMappings.cs` | Mapster configs for SMSCampaign+Request+Response+Summary+Report+AudiencePreview+Recipient |
| 4 | `Base.Application/Extensions/DecoratorProperties.cs` | Add `SMSCampaign` + `SMSCampaignRecipient` to `DecoratorNotifyModules` |
| 5 | `Base.Domain/Models/NotifyModels/SMSTemplate.cs` | Add inverse nav: `public ICollection<SMSCampaign>? SMSCampaigns { get; set; }` |
| 6 | `Base.Domain/Models/AppModels/MasterData.cs` | Add inverse nav collections for 3 new TypeCode usages (CampaignType/CampaignStatus/DeliveryStatus) if required by Mapster convention |
| 7 | `Base.Domain/Models/CorgModels/Tag.cs` *(or wherever #22 put it)* | Add inverse nav: `public ICollection<SMSCampaign>? RecipientSMSCampaigns`, `ExcludeSMSCampaigns` (optional — skip if #22 convention doesn't use inverse navs) |
| 8 | `Base.Domain/Models/CorgModels/Segment.cs` | same pattern |
| 9 | `Base.Domain/Models/NotifyModels/SavedFilter.cs` | Add inverse nav `RecipientSMSCampaigns` (optional) |

### Frontend Files — Standard FLOW (9 files)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `src/domain/entities/notify-service/SMSCampaignDto.ts` (SMSCampaignDto + RequestDto + ResponseDto + SummaryDto + ReportDto + AudiencePreviewDto + RecipientDto + ChecklistItemDto) |
| 2 | GQL Query | `src/infrastructure/gql-queries/notify-queries/SMSCampaignQuery.ts` (GET_ALL, GET_BY_ID, GET_SUMMARY, GET_REPORT, PREVIEW_AUDIENCE, GET_CHECKLIST) |
| 3 | GQL Mutation | `src/infrastructure/gql-mutations/notify-mutations/SMSCampaignMutation.ts` (CREATE, UPDATE, DELETE, TOGGLE, SEND_NOW, SCHEDULE, PAUSE, RESUME, CANCEL, DUPLICATE) |
| 4 | Page Config | `src/presentation/pages/crm/sms/smscampaign.tsx` (new — sibling of smstemplate.tsx) |
| 5 | Barrel / Entry | `src/presentation/components/page-components/crm/sms/smscampaign/index.tsx` |
| 6 | Index Page | `src/presentation/components/page-components/crm/sms/smscampaign/index-page.tsx` (Variant B: ScreenHeader + 4 widgets + filter chips + FlowDataTableContainer showHeader={false}) |
| 7 | **View Page (3 modes)** | `src/presentation/components/page-components/crm/sms/smscampaign/view-page.tsx` (dispatches to form-wizard-page OR report-detail-page by URL mode) |
| 8 | **Zustand Store** | `src/presentation/components/page-components/crm/sms/smscampaign/sms-campaign-store.ts` (currentStep, wizard state, audiencePreview cache, costEstimate cache) |
| 9 | Route Page | `src/app/[lang]/crm/sms/smscampaign/page.tsx` (REPLACE existing stub `"Need to Develop"`) |

### Frontend Files — Wizard FORM (6 component files)

| # | File | Path |
|---|------|------|
| 10 | Wizard Shell | `.../smscampaign/form-wizard-page.tsx` (step progress bar + current step renderer + footer + unsaved-changes dialog) |
| 11 | Step 1 | `.../smscampaign/steps/step1-campaign-setup.tsx` |
| 12 | Step 2 | `.../smscampaign/steps/step2-select-audience.tsx` |
| 13 | Step 3 | `.../smscampaign/steps/step3-review-send.tsx` |
| 14 | Send Confirm Modal | `.../smscampaign/send-confirm-modal.tsx` |
| 15 | Audience Preview Card | `.../smscampaign/audience-preview-card.tsx` (+ cost-estimate-card.tsx + country-distribution-chips.tsx + checklist-list.tsx) |

### Frontend Files — REPORT DETAIL (6 component files)

| # | File | Path |
|---|------|------|
| 16 | Report Shell | `.../smscampaign/report-detail-page.tsx` (renders if CampaignStatus ≠ Draft) |
| 17 | Delivery Funnel | `.../smscampaign/report/delivery-funnel.tsx` |
| 18 | Delivery Breakdown | `.../smscampaign/report/delivery-breakdown-card.tsx` |
| 19 | Delivery By Country | `.../smscampaign/report/delivery-by-country-card.tsx` |
| 20 | Reply Summary | `.../smscampaign/report/reply-summary-card.tsx` |
| 21 | Recipients Table | `.../smscampaign/report/recipients-table-card.tsx` |

### Frontend Files — Grid Support (4 files)

| # | File | Path |
|---|------|------|
| 22 | Widgets Strip | `.../smscampaign/smscampaign-widgets.tsx` (4 KPI cards wired to GetSMSCampaignSummary) |
| 23 | Filter Chips | `.../smscampaign/filter-chips-bar.tsx` |
| 24 | Row Actions (status-aware) | `.../smscampaign/smscampaign-row-actions.tsx` |
| 25 | Shared Radio Card Group | `src/presentation/components/shared/radio-card-group.tsx` (create if missing; verify not already present) |

### Frontend Files — Renderers (new cell renderers)

| # | Renderer | Where Registered |
|---|----------|-----------------|
| 26 | `campaign-name-link` | 3 column-type registries (advanced, basic, flow) + shared-cell-renderers barrel |
| 27 | `template-ref-mono` | same |
| 28 | `rate-bar-percent` | same |
| 29 | `count-with-percent` | same |
| 30 | `italic-muted-count` | same |
| 31 | `cost-cell` | same |
| 32 | `campaign-date-cell` | same |
| 33 | `recipients-count` (Auto-or-integer) | same |
| 34 | `country-flag-chip` (for Recipients table) | same |

**Frontend Total**: ~25 new files (9 standard + 6 wizard + 6 report + 4 grid support) + renderer additions across 3 registries.

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `src/infrastructure/entity-operations.ts` (or equivalent) | Register `SMSCAMPAIGN` operations config (mirror SMSTEMPLATE pattern) |
| 2 | `src/infrastructure/operations-config.ts` | Import + register SMSCampaign operations |
| 3 | `src/domain/entities/notify-service/index.ts` | Barrel export SMSCampaignDto types |
| 4 | `src/infrastructure/gql-queries/notify-queries/index.ts` | Barrel export SMSCampaignQuery |
| 5 | `src/infrastructure/gql-mutations/notify-mutations/index.ts` | Barrel export SMSCampaignMutation |
| 6 | `src/presentation/components/page-components/crm/sms/index.ts` (if exists) | Barrel export smscampaign sub-module |
| 7 | 3× column-type registries (`advanced-`, `basic-`, `flow-`) | Register 9 new renderers (items 26-34 above) |
| 8 | `src/presentation/components/shared/cell-renderers/index.ts` | Barrel export new renderers |
| 9 | Sidebar menu config (data-driven from DB seed — no code change needed if seed inserts MenuCode=SMSCAMPAIGN under ParentMenu=CRM_SMS) | — |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens per MODULE_MENU_REFERENCE.md.

```
---CONFIG-START---
Scope: FULL

MenuName: SMS Campaigns
MenuCode: SMSCAMPAIGN
ParentMenu: CRM_SMS
Module: CRM
MenuUrl: crm/sms/smscampaign
MenuOrderBy: 2
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: SMSCAMPAIGN
---CONFIG-END---
```

**DB Seed must also create these MasterData TypeCodes** (idempotent ON CONFLICT):

| TypeCode | Values (+ DataSetting hex where applicable) |
|----------|--------------------------------------------|
| `SMSCAMPAIGNTYPE` | `BROADCAST` (📢 "Broadcast"), `AUTOMATED` (🔁 "Automated") |
| `SMSCAMPAIGNSTATUS` | `DRAFT` (gray #94a3b8), `SCHEDULED` (blue #2563eb), `SENDING` (amber #f59e0b), `SENT` (green #15803d), `ACTIVEAUTO` (green #16a34a), `PAUSED` (amber #d97706), `CANCELLED` (slate #64748b), `FAILED` (red #dc2626) |
| `SMSDELIVERYSTATUS` | `QUEUED`, `SENT`, `DELIVERED`, `FAILED`, `DNDBLOCKED`, `STOPBLOCKED` |
| `SMSSENDERTYPE` | `ALPHANUMERIC` ("Alphanumeric — no replies"), `PHONENUMBER` ("Phone number — replies enabled") |
| `SMSRECIPIENTSOURCE` | `SAVEDSEGMENT`, `SAVEDFILTER`, `TAG`, `IMPORTLIST`, `ALLOPTEDIN` |

**DB Seed — Grid rows**: 1 Grid row (GridType=FLOW, GridFormSchema=NULL), ~11 GridFields matching the grid columns, ~11 GridField entries.

**DB Seed — sample rows**: 3-4 sample campaigns mirroring mockup (Donation Receipts Auto, Ramadan Appeal Sent, Event Reminder Gala Sent, Year-End Appeal Draft). Keep recipient counts low (5-10 rows per campaign) to keep seed fast.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `SMSCampaignQueries`
- Mutation type: `SMSCampaignMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `smsCampaigns` (GetAllSMSCampaignList) | `[SMSCampaignResponseDto]` | searchText, pageNo, pageSize, sortField, sortDir, isActive, dateFrom, dateTo, campaignStatusId, campaignTypeId, smsTemplateId |
| `smsCampaignById` (GetSMSCampaignById) | `SMSCampaignResponseDto` | smsCampaignId |
| `smsCampaignSummary` (GetSMSCampaignSummary) | `SMSCampaignSummaryDto` | (tenant-scoped; no args) |
| `smsCampaignReport` (GetSMSCampaignReport) | `SMSCampaignReportDto` | smsCampaignId, pageNo, pageSize (for recipients table) |
| `previewSMSCampaignAudience` (PreviewSMSCampaignAudience) | `SMSCampaignAudiencePreviewDto` | recipientSource, recipientSegmentId?, recipientSavedFilterId?, recipientTagId?, excludeTagId?, excludeSegmentId?, excludeRecentlyMessagedHours?, skipStopRepliers, skipDNDRegistry |
| `smsCampaignChecklist` (GetSMSCampaignChecklist) | `[ChecklistItemDto]` | smsCampaignId? (null for new-in-progress), campaignDraft (RequestDto — for pre-save checklist) |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createSMSCampaign` | `SMSCampaignRequestDto` | `int` (new SMSCampaignId) |
| `updateSMSCampaign` | `SMSCampaignRequestDto` | `int` |
| `deleteSMSCampaign` | `int smsCampaignId` | `int` (deleted id) |
| `toggleSMSCampaign` | `int smsCampaignId` | `int` |
| `sendSMSCampaignNow` | `int smsCampaignId` | `int` (transitions Draft → Sending, returns campaign id; asynchronous dispatch — status flips to Sent via worker — SERVICE_PLACEHOLDER) |
| `scheduleSMSCampaign` | `int smsCampaignId, DateTime scheduledAt, string timezone` | `int` |
| `pauseSMSCampaign` | `int smsCampaignId` | `int` |
| `resumeSMSCampaign` | `int smsCampaignId` | `int` |
| `cancelSMSCampaign` | `int smsCampaignId` | `int` |
| `duplicateSMSCampaign` | `int smsCampaignId` | `int` (new SMSCampaignId as Draft) |

**Response DTO Fields** (`SMSCampaignResponseDto` — list + detail projection):

| Field | Type | Notes |
|-------|------|-------|
| smsCampaignId | number | PK |
| smsCampaignCode | string | auto-gen format `SMC-{NNNN}` |
| smsCampaignName | string | user-visible |
| campaignTypeId | number | FK |
| campaignTypeName | string | projection from MasterData |
| triggerEvent | string? | nullable |
| smsTemplateId | number | FK |
| smsTemplateName | string | projection |
| smsTemplateBody | string | projection — for preview bubble |
| senderType | string | `Alphanumeric` / `PhoneNumber` |
| senderValue | string | — |
| recipientSource | string | `SavedSegment` / `SavedFilter` / `Tag` / `ImportList` / `AllOptedIn` |
| recipientSegmentId / Name | number? / string? | FK + projection |
| recipientSavedFilterId / Name | number? / string? | — |
| recipientTagId / Name | number? / string? | — |
| recipientImportBatchRef | string? | — |
| scheduleMode | string | `SendNow` / `Scheduled` / `Triggered` |
| scheduledAt | string (ISO)? | — |
| scheduledTimezone | string? | — |
| respectQuietHours | boolean | — |
| excludeTagId / Name | number? / string? | — |
| excludeSegmentId / Name | number? / string? | — |
| excludeRecentlyMessagedHours | number? | — |
| skipStopRepliers | boolean | — |
| skipDNDRegistry | boolean | — |
| audienceTotalCount / withMobileCount / optedInCount / dndBlockedCount / netRecipientsCount | number | snapshots |
| estimatedCostCents / actualCostCents | number? | — |
| budgetCapCents | number? | — |
| campaignStatusId | number | FK |
| campaignStatusName | string | projection (for badge) |
| campaignStatusCode | string | projection (DRAFT / SCHEDULED / etc. — drives row-actions + chips) |
| campaignStatusColorHex | string? | from MasterData.DataSetting |
| sentAt | string (ISO)? | — |
| segmentsPerMessage | number | snapshot |
| enableReplyCapture | boolean | — |
| lastRunAt / lastRunCount | string? / number? | Automated only |
| **Aggregations** (from recipients via subquery) | | |
| totalSentCount | number | COUNT recipients WHERE deliveryStatusId ≥ Sent |
| deliveredCount | number | — |
| deliveredPct | number | (0-100, one decimal) |
| failedCount | number | — |
| failedPct | number | — |
| dndSkippedCount | number | — |
| totalActualCostCents | number | SUM(CostCents) |
| createdDate / modifiedDate / createdByName / modifiedByName | string? | audit projections (Contact #18 pattern — honor per-feedback memory `verify_properties`: use `createdDate`/`modifiedDate` NOT `createdAt`) |

**SummaryDto:**
```
{ campaignsSentMonth, campaignsSentWeek, messagesSentMonth, segmentsSentMonth, deliveryRatePct, deliveryRateDeltaPct, totalCostCentsMonth, avgCostPerCampaignCents }
```

**ReportDto:**
```
{
  campaignMetadata: { name, templateName, senderValue, sentAt, recipientsCount },
  funnel: { queued, dndScrubbed, totalSent, delivered, failed, deliveredPct, failedPct },
  breakdown: { deliveredCount, failedCount, failureReasons: [{ reason, count }] },
  byCountry: [{ countryCode, countryName, flag, sent, delivered, deliveredPct, failed, failedPct, costCents }],
  replySummary: { totalReplies, byKeyword: [{ keyword, count }] },
  recipientsPage: { rows: [RecipientDto], totalCount, pageNo, pageSize }
}
```

**AudiencePreviewDto:**
```
{ totalContacts, withMobileCount, withMobilePct, optedInCount, optedInPct, dndBlockedCount, netRecipientsCount, segmentsPerMessage, estimatedCostCents, countryDistribution: [{ code, name, flag, count }] }
```

**ChecklistItemDto:**
```
{ key, severity: 'success' | 'warning' | 'critical', message, linkUrl?, linkLabel? }
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — 0 errors, ≤ pre-existing warning count
- [ ] `pnpm tsc --noEmit` — 0 new errors attributable to smscampaign files
- [ ] `pnpm dev` — page loads at `/{lang}/crm/sms/smscampaign`

**Functional Verification (Full E2E — MANDATORY):**

*List view:*
- [ ] 4 KPI widgets render with icons + values + subtitle (zero values OK until data)
- [ ] Grid renders 11 columns including rate-bar and cost-with-warning cells
- [ ] Filter chips switch grid results
- [ ] Row actions menu changes shape based on row's campaignStatusCode

*Wizard FORM (`?mode=new`):*
- [ ] Step progress bar advances on Next / regresses on Back
- [ ] Step 1: all 6 fields render; Campaign Type cards select with accent; Schedule card "Schedule" reveals DateTime + TZ
- [ ] Template ApiSelectV2 shows only Active templates with formatted option labels
- [ ] Campaign Type "Automated" hides Schedule card and Send Now CTA
- [ ] Step 2: 5 recipient-source cards; sub-selector reveals per card; Audience Preview fires real `previewSMSCampaignAudience` query and updates live
- [ ] Exclusion checkboxes wire to Zustand store and re-trigger preview
- [ ] Step 3: Summary table shows all 9 rows; SMS Preview renders bubble with placeholder-merged text; Checklist shows ≥ 4 success rows + conditional warnings
- [ ] "Save Draft" saves as Draft and navigates to `?mode=read&id={newId}`
- [ ] "Send Now" opens confirm modal → Confirm & Send transitions to Sending → redirect to `?mode=read&id={id}` → REPORT layout
- [ ] "Schedule" path saves as Scheduled
- [ ] Unsaved-changes dialog triggers on Back/Cancel

*Report DETAIL (`?mode=read&id=X`):*
- [ ] Draft status → condensed summary (NOT wizard)
- [ ] Sent/Active/Paused/Cancelled/Failed → full report layout
- [ ] Delivery Funnel renders 5 steps with arrows; counts match recipients aggregate
- [ ] Delivery Breakdown table + colspan footer with failure reasons
- [ ] Delivery by Country table renders with flag cells
- [ ] Reply Summary chips + View All Replies button (stub modal)
- [ ] Recipients table paginates; rows show status icon + country chip + replied-badge

*Aggregations / Mutations:*
- [ ] `SendSMSCampaignNow` materializes recipient rows (even if dispatch itself is placeholder — status goes to Sending)
- [ ] `PauseSMSCampaign` / `ResumeSMSCampaign` flip ActiveAuto ↔ Paused
- [ ] `CancelSMSCampaign` blocked on already-Sent campaign with 400 error
- [ ] `DeleteSMSCampaign` blocked on Sent/ActiveAuto/Paused with 400 error
- [ ] `DuplicateSMSCampaign` creates new Draft with `_copy` suffix

*Permissions:*
- [ ] BUSINESSADMIN has full CRUD + workflow actions
- [ ] Edit/Delete/SendNow/Pause respect MenuCapability

**DB Seed Verification:**
- [ ] `SMS Campaigns` menu appears under CRM → SMS at OrderBy=2
- [ ] 5 MasterData TypeCodes inserted idempotently (ON CONFLICT DO NOTHING)
- [ ] 3-4 sample campaigns visible in grid with varied statuses
- [ ] Grid registered in `Grids` table with GridFormSchema=NULL (FLOW rule)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Architecture / convention gotchas:**
- **CompanyId is NOT a form field** — FLOW screens get tenant from HttpContext (EmailTemplate/SMSTemplate precedent).
- **GridFormSchema is SKIP** — FLOW screens don't seed form schema. Don't let the build agent try to generate one.
- **Schema + Group are SAME as SMSTemplate** — `notify` schema, `NotifyModels` group, `notify-service` FE folder, `notify-queries`/`notify-mutations` paths. Don't invent new paths.
- **Two separate layouts in one view-page.tsx** — the FORM (wizard) and DETAIL (report) are different components. `view-page.tsx` dispatches based on URL mode AND `campaignStatusCode` for read. DO NOT just disable the wizard inputs for read mode.
- **Variant B layout MANDATORY** — 4 KPI widgets above grid → `<ScreenHeader>` + widgets + `<FlowDataTableContainer showHeader={false}>`. Double-header bug precedent: ContactType #19.
- **GetSMSTemplates name** — SMS Template #29 uses `GetSMSTemplates`/`GetSMSTemplateById` (post-patched from `GetAllSMSTemplateList`/`GetSMSTemplateById`). Verify current name in `SMSTemplateQueries.cs` before wiring FE ApiSelect.
- **`HotChocolate.Types.Tag` ambiguity** — Tag entity conflicts with HotChocolate's `Tag` type. Use using-alias `using TagEntity = Base.Domain.Models.CorgModels.Tag;` and/or fully-qualified DbSet reference (Tags & Segmentation #22 precedent). Applies to Mutations/Queries endpoint + any file that imports both.
- **Audit field naming** — project uses `CreatedDate`/`ModifiedDate` (NOT `CreatedAt`/`ModifiedAt`). Honored in Response DTO projection.
- **Seed folder typo** — repo-wide path is `sql-scripts-dyanmic/` (NOT `dynamic/`). Keep the typo — several screens already use it (ISSUE-9 from Placeholder Definition #26).
- **Migration snapshot regeneration** — after `dotnet ef migrations add SMSCampaign_Initial`, the user must regenerate the EF snapshot locally. Flag this in Build Log.
- **LastUsedAt on SMSTemplate** — SMS Template #29 ISSUE-2 says "LastUsedAt handler owned by SMS Campaign #30". This build MUST update `SMSTemplate.LastUsedAt` when a campaign with that template transitions to Sent (Send-time hook in `SendSMSCampaignNow`). Include in the handler.
- **SegmentsPerMessage snapshot** — copy from `SMSTemplate.SegmentCount` at save time; don't recompute at send time (template could change between schedule and send).

**Service Dependencies** (UI-only — build full UI, stub backend handlers with toasts/mocks):

- ⚠ **SERVICE_PLACEHOLDER: SMS Dispatch Worker** — actual sending via Twilio / MessageBird / AWS SNS is not wired. `SendSMSCampaignNow` transitions status and materializes recipient rows (status=Queued) but does NOT call an external SMS API. Status flips to Sent synchronously for demo (`sentAt = now`, recipients to Delivered with simulated delivery rate). Leave a clear `// TODO: SMS_DISPATCH_SERVICE_NOT_WIRED` marker.
- ⚠ **SERVICE_PLACEHOLDER: DND Registry Check** — national DND registries (DNC-USA, TRAI-India, CRTC-Canada) require external API access. `AudienceDNDBlockedCount` is estimated via heuristic (e.g., 3% of opted-in audience). Leave marker.
- ⚠ **SERVICE_PLACEHOLDER: Cost per-country rate table** — carrier rates differ per country. For now, use flat `$0.04/segment/recipient`. Future: driven by a `CarrierRate` MasterData or config table.
- ⚠ **SERVICE_PLACEHOLDER: Inbound Reply Webhook** — reply capture requires a webhook endpoint + carrier configuration. `SMSCampaignRecipient.ReplyText` stays null until wired. `Reply Summary` card shows zeros + "No replies yet — reply capture not yet configured" hint.
- ⚠ **SERVICE_PLACEHOLDER: Quiet-hours scheduler** — background worker to queue until recipient local time is not in the repo. Field `IsQuietHoursQueued` is set based on recipient country heuristic (UAE/India = night hours) for demo.
- ⚠ **SERVICE_PLACEHOLDER: DynamicQueryBuilder for Segment/SavedFilter audience resolution** — same ISSUE-1 as SavedFilter #27. For SavedSegment and SavedFilter recipient sources, fall back to a simplified LINQ resolution (no advanced filter JSON evaluation): select contacts matching basic `Company + DoNotSMS=false`. Mark `// TODO: DYNAMIC_QUERY_RESOLVER_NOT_WIRED`.
- ⚠ **SERVICE_PLACEHOLDER: Contact Import List source** — Import List option reveals a file-upload stub with toast "Contact Import ships with screen #23". No actual import processing.
- ⚠ **SERVICE_PLACEHOLDER: Automation Trigger Events** — "Automated" campaign type exposes a TriggerEvent dropdown with 5 hardcoded options (`donation.received`, `pledge.overdue`, `event.registered`, `membership.expired`, `member.birthday`) — real automation binding ships with Automation Workflow #37.
- ⚠ **SERVICE_PLACEHOLDER: Phone-number format validation (E.164) for SenderValue** — use basic regex `^\+[1-9]\d{1,14}$`. Full libphonenumber validation (including country-specific formatting) is future work.
- ⚠ **SERVICE_PLACEHOLDER: Print/Export for report detail** — Export CSV button in header shows toast "Export coming soon".
- ⚠ **SERVICE_PLACEHOLDER: Country flag emoji** — compute flag via `Country.CountryCode` → Unicode regional-indicator pair, OR if Country entity lacks it, leave flag field blank and show code only.

All UI (buttons, forms, modals, panels, toggles, tables) MUST be built. Only the handler for the external service call is mocked/toasted.

**ALIGN / partial-code warnings:** N/A — Scope=FULL. Route stub at `src/app/[lang]/crm/sms/smscampaign/page.tsx` (contains just `"Need to Develop"`) will be overwritten.

**Pre-flagged ISSUEs** (for Build Log to expand during session):

| ID | Area | Severity | Description |
|----|------|----------|-------------|
| ISSUE-1 | BE | MED | DynamicQueryBuilder absent → Segment/SavedFilter audience resolution simplified (SavedFilter #27 ISSUE-1 inherited) |
| ISSUE-2 | BE | MED | EF snapshot regeneration pending (user runs locally) |
| ISSUE-3 | BE | MED | SMS Dispatch service not wired — SendNow simulates delivery for demo |
| ISSUE-4 | BE | LOW | LastUsedAt update on SMSTemplate — new hook inside SendSMSCampaignNow (closes SMS Template #29 ISSUE-2) |
| ISSUE-5 | BE | LOW | DND registry placeholder estimate (3% heuristic) |
| ISSUE-6 | BE | LOW | Cost per-country rate placeholder (flat $0.04) |
| ISSUE-7 | BE | LOW | Inbound reply webhook not wired — ReplyText always null |
| ISSUE-8 | BE | LOW | Quiet-hours background scheduler placeholder |
| ISSUE-9 | BE | LOW | Automation TriggerEvent hardcoded list until #37 ships |
| ISSUE-10 | FE | MED | Shared `<RadioCardGroup>` — verify reuse vs create; follow feedback memory `component_reuse_create` (FE agent searches registries first) |
| ISSUE-11 | FE | LOW | Country flag emoji derivation (Country.CountryCode → regional indicator) |
| ISSUE-12 | FE | LOW | Status-aware row actions — 8 status-variant menus (maintenance cost noted) |
| ISSUE-13 | FE | LOW | Wizard step persistence — Zustand store persists wizard state per draft campaign, clears on submit |
| ISSUE-14 | DB | LOW | Seed folder typo `sql-scripts-dyanmic/` (inherited — do not fix in this session) |
| ISSUE-15 | DB | LOW | 5 new MasterData TypeCodes — ON CONFLICT idempotency required |
| ISSUE-16 | BE | LOW | Tag / Segment entity group verification — #22 may have used CorgModels; verify before Mapster config + using-alias for `Tag` to avoid HotChocolate clash |
| ISSUE-17 | FE | LOW | Live SMS Preview bubble reuses SMS Template #29 phone-preview.tsx — imported path stability check |
| ISSUE-18 | BE | LOW | BudgetCap column nullable int cents — null means "no budget cap set"; check handling in pre-send checklist |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | PLAN | MED | BE | DynamicQueryBuilder absent (SavedFilter #27 inheritance) | OPEN |
| ISSUE-2 | PLAN | MED | BE | EF snapshot regeneration pending | OPEN |
| ISSUE-3 | PLAN | MED | BE | SMS Dispatch service SERVICE_PLACEHOLDER | OPEN |
| ISSUE-4 | PLAN | LOW | BE | LastUsedAt hook (closes SMS Template #29 ISSUE-2) | OPEN |
| ISSUE-5 | PLAN | LOW | BE | DND registry heuristic SERVICE_PLACEHOLDER | OPEN |
| ISSUE-6 | PLAN | LOW | BE | Cost per-country flat rate | OPEN |
| ISSUE-7 | PLAN | LOW | BE | Reply webhook SERVICE_PLACEHOLDER | OPEN |
| ISSUE-8 | PLAN | LOW | BE | Quiet-hours scheduler SERVICE_PLACEHOLDER | OPEN |
| ISSUE-9 | PLAN | LOW | BE | Automation trigger hardcoded | OPEN |
| ISSUE-10 | PLAN | MED | FE | RadioCardGroup reuse-or-create | OPEN |
| ISSUE-11 | PLAN | LOW | FE | Country flag derivation | OPEN |
| ISSUE-12 | PLAN | LOW | FE | Status-aware row actions maintenance | OPEN |
| ISSUE-13 | PLAN | LOW | FE | Wizard state persistence rules | OPEN |
| ISSUE-14 | PLAN | LOW | DB | Seed folder typo (inherited) | OPEN |
| ISSUE-15 | PLAN | LOW | DB | MasterData ON CONFLICT idempotency | OPEN |
| ISSUE-16 | PLAN | LOW | BE | Tag/Segment group verification + HotChocolate alias | OPEN |
| ISSUE-17 | PLAN | LOW | FE | PhonePreviewBubble path reuse | OPEN |
| ISSUE-18 | PLAN | LOW | BE | BudgetCap nullable semantics | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}
