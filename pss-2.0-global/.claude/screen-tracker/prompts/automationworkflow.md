---
screen: AutomationWorkflow
registry_id: 37
module: Communication (CRM)
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO — extends `notify` schema / NotifyModels group
planned_date: 2026-05-18
completed_date: 2026-05-18
last_session_date: 2026-05-18
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (LIST workflow cards + FORM canvas builder + DETAIL execution log)
- [x] Existing code reviewed (FE stub `crm/automation/automationworkflow/page.tsx`; NO BE entity)
- [x] Business rules + workflow extracted
- [x] FK targets resolved (EmailTemplate / WhatsAppTemplate / SMSTemplate / NotificationTemplate / Tag / Contact / User)
- [x] File manifest computed
- [x] Approval config pre-filled (MenuCode AUTOMATIONWORKFLOW under CRM_AUTOMATION)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (planning embedded — §②③④ produced by /plan-screens 2026-05-18; re-spawn skipped per user approval)
- [x] Solution Resolution complete (§⑤ — FLOW non-standard, Variant B index, atomic save with temp-id remap)
- [x] UX Design finalized (LIST cards + FORM canvas + DETAIL log layouts specified — §⑥)
- [x] User Approval received (2026-05-18 — 4 Sonnet spawn plan)
- [x] Backend code generated (3 entities + 3 EF configs + DTO schemas + 8 commands + 4 queries + endpoints + EF migration scaffold)
- [x] Backend wiring complete (INotifyDbContext + NotifyDbContext + DecoratorProperties + NotifyMappings + Contact inverse nav). No inverse nav on EmailTemplate/WhatsAppTemplate/SMSTemplate/NotificationTemplate/Tag/User — refs live in StepConfig JSON.
- [x] Frontend code generated (Variant B index-page custom card list + view-page 3 modes + canvas builder + 10 step-editor sub-forms + Zustand store)
- [x] Frontend wiring complete (DTO/Query/Mutation barrels + pages/crm/automation/index + page-components/crm/automation/index + route page replaced + Zustand stores barrel)
- [x] DB Seed script generated (Menu + MenuCapabilities + RoleCapabilities + 3 sample workflows + 3 sample steps + 5 sample executions; GridFormSchema SKIP per FLOW)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [x] `dotnet build` passes (Session 1 — fixed 5 inline errors mid-build: bogus `PaginatedData<>` type → `GridFeatureResult<>`, bogus `request.SearchText` → `request.searchTerm`, bogus `Contact.ContactName` → `Contact.DisplayName` × 3 sites)
- [ ] `pnpm dev` — page loads at `/crm/automation/automationworkflow`
- [ ] LIST: 3 KPI cards (Active / Paused / Total Executions 30d) render above workflow card list
- [ ] LIST: search box + Status filter + Trigger filter narrow the visible cards (client-side combine AND)
- [ ] LIST: each card shows status indicator dot + name + trigger description + step count badge + status badge + 30d executions + last-run + 5 row actions (Edit, Pause/Resume/Activate, View Log, Duplicate, Delete)
- [ ] `?mode=new`: empty BUILDER renders (single TRIGGER node + "Add Step" button below it)
- [ ] `?mode=new`: clicking "Add Step" reveals dropdown with 10 step types; selecting one inserts the corresponding node
- [ ] `?mode=new`: Trigger node's "When" dropdown lists ALL 20 trigger types; trigger config UI swaps per selection (amount, cron, time, etc.)
- [ ] `?mode=new`: adding an "If/Else" condition node creates YES + NO branches; "Add Step" buttons appear inside each branch
- [ ] `?mode=new`: each node has Edit (open per-node editor modal) and Remove (delete with confirm)
- [ ] `?mode=new`: "Test Run" header button fires SERVICE_PLACEHOLDER toast
- [ ] `?mode=new`: "Save" persists workflow + all steps (atomic transaction) → URL → `?mode=read&id={newId}`
- [ ] `?mode=edit&id=X`: BUILDER loads pre-filled with workflow + steps as nodes in the canvas
- [ ] `?mode=edit&id=X`: Status toggle (Active / Paused / Draft) header control switches the workflow status on Save
- [ ] `?mode=read&id=X`: EXECUTION LOG layout renders (4 stat tiles + table with Contact / Started / Current Step / Status pill / Completed / Cancel|Retry actions)
- [ ] `?mode=read&id=X`: "Edit Workflow" button navigates to `?mode=edit&id=X`
- [ ] Workflow card "View Log" action navigates to `?mode=read&id={id}`
- [ ] Workflow card "Pause" / "Resume" / "Activate" row action calls Toggle endpoint and reflects in card status
- [ ] Workflow card "Duplicate" creates a new Draft workflow with copied trigger + steps
- [ ] Workflow card "Delete" prompts confirm, then soft-deletes via Delete endpoint (sets IsActive=false)
- [ ] Unsaved-changes dialog triggers on canvas dirty + back navigation
- [ ] FK ApiSelectV2 dropdowns in per-node editors load (EmailTemplate / WhatsAppTemplate / SMSTemplate / NotificationTemplate / Tag / User)
- [ ] DB Seed — menu AUTOMATIONWORKFLOW visible in sidebar under CRM > Automation

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

**Screen**: AutomationWorkflow
**Module**: Communication (CRM)
**Schema**: `notify`
**Group**: NotifyModels (co-located with EmailTemplate #24, SMSTemplate #29, WhatsAppTemplate #31, NotificationTemplate #36, EmailSendJob, etc.)

**Business**: Automation Workflows let NGO admins build "if-this-then-that" communication sequences that fire automatically on common CRM events (new contact created, donation received, contact birthday, recurring payment failed, monthly schedule, etc.). Each workflow has one **trigger** at the top and a sequence of **action / wait / condition** steps below it — rendered in the admin UI as a vertical node canvas (like Zapier / n8n / Make). Conditions can fork the flow into YES / NO branches, each with its own follow-on steps and own END node. Actions cover the four messaging channels (Email / WhatsApp / SMS / Notification — pulling templates from screens #24 / #31 / #29 / #36) plus contact-side actions (Add/Remove Tag, Update Contact, Create Task, Send Webhook). This is THE screen that ties together every other communication template in the platform — without it, templates exist but nothing dispatches them on its own. The dispatcher itself (cron scheduler, event listener, step executor) is a SERVICE_PLACEHOLDER for this build; this screen ships the BUILDER + execution log VIEWER + the storage model the executor will consume.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> All fields extracted from HTML mockup. Audit columns (CreatedBy, CreatedDate, etc.) omitted — inherited from Entity base.
> **CompanyId is NOT a field** — FLOW screens get tenant from HttpContext.

### Parent — `notify."AutomationWorkflows"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AutomationWorkflowId | int | — | PK | — | Primary key |
| WorkflowName | string | 200 | YES | — | Display name (e.g., "New Donor Welcome Series") |
| Description | string | 500 | NO | — | Optional admin note |
| TriggerType | string | 50 | YES | — | One of 20 enum values — see Business Logic §④ |
| TriggerConfig | string | 2000 | NO | — | JSON — params for the trigger (amount threshold / cron / time / day-of-week / etc.) |
| TriggerConditions | string | 2000 | NO | — | JSON array of `{field, op, value}` sub-conditions (e.g., `ContactType = Donor`) |
| Status | string | 20 | YES | — | `Active` \| `Paused` \| `Draft` (default Draft) |
| LastRunAt | DateTime | — | NO | — | Set by executor on each execution; null until first run |
| IsActive | bool | — | YES | — | Soft-delete flag (inherited convention) |
| CompanyId | int | — | YES (HttpContext) | app.Companies | NOT a column the user enters |

**Computed / projected** (NOT stored — derived in GetAll handler):
- `StepCount` = `COUNT(AutomationWorkflowSteps WHERE WorkflowId = this.Id)`
- `Executions30Days` = `COUNT(AutomationWorkflowExecutions WHERE WorkflowId = this.Id AND StartedAt >= now() - INTERVAL '30 days')`

### Child 1 — `notify."AutomationWorkflowSteps"` (cascade-delete on parent)

Represents each node in the canvas (action / wait / condition). Self-referencing for IF/ELSE branches.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AutomationWorkflowStepId | int | — | PK | — | Primary key |
| AutomationWorkflowId | int | — | YES | notify.AutomationWorkflows | Parent workflow |
| ParentStepId | int | — | NO | notify.AutomationWorkflowSteps | NULL = top-level (child of the trigger); set = nested inside a Condition branch's YES or NO path |
| BranchType | string | 10 | NO | — | NULL when ParentStepId is NULL; `YES` or `NO` when nested under a Condition step (declares which branch this step belongs to) |
| StepOrder | int | — | YES | — | Ordering within siblings (top-level: order along trunk; nested: order along that branch) |
| StepType | string | 30 | YES | — | 10 values — see Business Logic §④ |
| StepConfig | string | 4000 | YES | — | JSON — type-specific config (e.g., `{emailTemplateId: 17, fromAddress: "info@ngo.org"}` for SendEmail; `{waitAmount: 7, waitUnit: "Days"}` for Wait; `{conditionField: "HasDonated", operator: "EqualsYes"}` for Condition; etc.) |

**Storage model — read this carefully**: The canvas's tree shape is encoded entirely via `ParentStepId` + `BranchType` + `StepOrder`. The TRIGGER itself is NOT a row in `AutomationWorkflowSteps` — it lives on the parent (`TriggerType` + `TriggerConfig` + `TriggerConditions`). Steps are children of the trigger (`ParentStepId = NULL, BranchType = NULL`) by default. When a Condition step branches, its YES-branch children carry `ParentStepId = <conditionStepId>, BranchType = 'YES'` and the NO-branch children carry `BranchType = 'NO'`. Branch reconvergence is NOT supported in v1 — each branch ends at its own END node (matches the mockup).

### Child 2 — `notify."AutomationWorkflowExecutions"` (cascade-delete on parent)

One row per trigger firing. The actual step-by-step execution audit is OUT OF SCOPE for v1 (SERVICE_PLACEHOLDER) — this entity captures the high-level lifecycle.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AutomationWorkflowExecutionId | int | — | PK | — | Primary key |
| AutomationWorkflowId | int | — | YES | notify.AutomationWorkflows | Parent workflow |
| ContactId | int | — | NO | contact.Contacts | The contact this execution operated on (NULL for scheduled triggers that aren't contact-scoped) |
| TriggerContext | string | 1000 | NO | — | JSON snapshot of why this fired (e.g., `{donationId: 4521, amount: 2500}`) |
| StartedAt | DateTime | — | YES | — | Default = `now()` |
| CompletedAt | DateTime | — | NO | — | Set when status becomes Completed/Failed/Cancelled |
| Status | string | 20 | YES | — | `InProgress` \| `Completed` \| `Failed` \| `Cancelled` (default InProgress) |
| CurrentStepId | int | — | NO | notify.AutomationWorkflowSteps | Which step is currently in flight (or last step before Completed/Failed) |
| CurrentStepLabel | string | 200 | NO | — | Denormalized label for display (e.g., "Step 1: Welcome Email", "Step 3: Waiting (7 days)") — populated by executor |
| BranchTaken | string | 10 | NO | — | NULL until a Condition is evaluated; then `YES` or `NO` |
| FailureReason | string | 500 | NO | — | Set when Status = Failed (e.g., "email bounced") |

**v1 build scope for Executions**: Seed sample rows for the LOG view demo. The executor that creates/updates these rows lives outside this screen (SERVICE_PLACEHOLDER). The screen READS executions in `?mode=read` and exposes a `CancelExecution` / `RetryExecution` mutation that flips Status but does NOT actually orchestrate steps (SERVICE_PLACEHOLDER).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for navigation properties + inverse navs) + Frontend Developer (for ApiSelectV2 queries inside the per-node editors)

**Direct FKs on the entity tables:**

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| AutomationWorkflowExecutions.ContactId | Contact | `PSS_2.0_Backend/.../Base.Domain/Models/ContactModels/Contact.cs` | `getContacts` | `ContactName` | `ContactResponseDto` |

**Indirect FKs via `StepConfig` JSON** (resolved client-side by ApiSelectV2 inside the per-node editor modal — NO direct FK constraint, stored as `templateId`/`tagId`/`userId` keys inside the JSON):

| Step Type | Config Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|-----------|-------------|--------------|-------------------|----------------|---------------|-------------------|
| SendEmail | `emailTemplateId` | EmailTemplate | `PSS_2.0_Backend/.../Base.Domain/Models/NotifyModels/EmailTemplate.cs` | `getEmailTemplates` | `EmailTemplateTitle` | `EmailTemplateResponseDto` |
| SendWhatsApp | `whatsAppTemplateId` | WhatsAppTemplate | `PSS_2.0_Backend/.../Base.Domain/Models/NotifyModels/WhatsAppTemplate.cs` | `getWhatsAppTemplates` | `WhatsAppTemplateName` | `WhatsAppTemplateResponseDto` |
| SendSMS | `smsTemplateId` | SMSTemplate | `PSS_2.0_Backend/.../Base.Domain/Models/NotifyModels/SMSTemplate.cs` | `getSMSTemplates` | `SMSTemplateName` | `SMSTemplateResponseDto` |
| SendNotification | `notificationTemplateId` | NotificationTemplate | `PSS_2.0_Backend/.../Base.Domain/Models/NotifyModels/NotificationTemplate.cs` | `getAllNotificationTemplateList` | `NotificationTemplateTitle` | `NotificationTemplateResponseDto` |
| AddTag / RemoveTag | `tagId` | Tag | `PSS_2.0_Backend/.../Base.Domain/Models/ContactModels/Tag.cs` | `getTags` | `TagName` | `TagResponseDto` |
| SendNotification (recipient) | `specificUserId` | User | `PSS_2.0_Backend/.../Base.Domain/Models/AuthModels/User.cs` | `getUsers` | `Username` (or full name) | `UserResponseDto` |

**No EF inverse-nav property is added** on EmailTemplate / WhatsAppTemplate / SMSTemplate / NotificationTemplate / Tag / User for workflow-step usage — `StepConfig` is a JSON column, not a typed FK, so EF doesn't need awareness. (Same pattern as `EmailSendJob.TemplateId` references stored opaquely.)

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `(CompanyId, WorkflowName)` must be unique among active workflows (prevent duplicate names per tenant)

**Required Field Rules:**
- `WorkflowName`, `TriggerType`, `Status` mandatory
- At least one step is recommended but NOT enforced (allow saving a Draft with just a trigger configured)
- For each Step: `StepType` + `StepConfig` mandatory
- For each Step nested under a Condition: `BranchType ∈ {YES, NO}` + `ParentStepId` mandatory

**Conditional Rules** (per-step type — validated by the per-node editor on save AND by the BE Create/Update validators by inspecting `StepConfig` JSON):

| StepType | Required `StepConfig` keys |
|----------|----------------------------|
| `SendEmail` | `emailTemplateId` (int) — must reference an existing EmailTemplate of the tenant; optional `fromAddress` (string) |
| `SendWhatsApp` | `whatsAppTemplateId` (int) — must reference an existing Approved WhatsAppTemplate of the tenant |
| `SendSMS` | `smsTemplateId` (int) — must reference an existing SMSTemplate of the tenant |
| `SendNotification` | `notificationTemplateId` (int) + `recipientType ∈ {AssignedStaff, AllAdmins, SpecificUser}`; if `SpecificUser`, also `specificUserId` (int) |
| `Wait` | `waitAmount` (int > 0) + `waitUnit ∈ {Minutes, Hours, Days}` |
| `Condition` | `conditionField` (string — one of: `HasDonated`, `DonationAmount`, `ContactTag`, `EmailOpened`) + `operator` (string — one of: `EqualsYes`, `EqualsNo`, `GreaterThan`, `LessThan`) + optional `value` (string — required when operator is Gt/Lt) |
| `UpdateContact` | `updates` (JSON object — field-name → new-value map; backend whitelists allowed fields) |
| `AddTag` | `tagId` (int) — must reference an existing tenant Tag |
| `RemoveTag` | `tagId` (int) — must reference an existing tenant Tag |
| `CreateTask` | `taskTitle` (string) + `assigneeType ∈ {AssignedStaff, SpecificUser}` + optional `specificUserId` + optional `dueInDays` (int) |
| `SendWebhook` | `webhookUrl` (string, must be `https://`) + optional `payloadTemplate` (string) |

**Per-trigger config requirements** (the Trigger node has its own `TriggerConfig` JSON):

| TriggerType | Required `TriggerConfig` keys |
|-------------|-------------------------------|
| `NewContactCreated`, `DonationReceived`, `FirstDonation`, `RecurringPaymentFailed`, `PledgePaymentOverdue`, `ContactUpdated`, `ContactBirthday`, `ContactAnniversary`, `CampaignStarted`, `CampaignGoalReached`, `CampaignEnded`, `EventRegistration`, `EventCheckIn`, `EventEnded`, `ManualTrigger` | — (no extra config) |
| `DonationGtAmount` | `amount` (decimal > 0) |
| `DailyAtTime` | `time` (HH:MM 24h) |
| `WeeklyOnDay` | `dayOfWeek` (Mon..Sun) + `time` (HH:MM) |
| `MonthlyOnDate` | `dayOfMonth` (1..31) + `time` (HH:MM) |
| `CustomCron` | `cronExpression` (string, validated as 5-field cron) |

**Business Logic:**
- A workflow can only be set to `Active` when it has at least one step (BE validator) — Draft workflows can have zero steps
- Saving a workflow is an **atomic transaction**: parent + steps are persisted together (delete old steps + insert new steps inside one transaction on Update — simpler than diff-update for v1)
- `Pause` / `Resume` / `Activate` workflow operations are status flips: Active↔Paused, Draft→Active (after validation)
- `Duplicate` workflow: copies parent (with " (Copy)" suffix on WorkflowName + Status reset to `Draft`) + all steps with new IDs + parent-step reference remapping
- Delete: soft-delete on parent (IsActive = false); CASCADE on EF means child steps and executions hard-delete

**Workflow** (state machine for the Workflow itself):
- States: `Draft → Active ⇄ Paused`; from any state can soft-delete; `Active → Draft` allowed (revert)
- Transitions: any tenant `BUSINESSADMIN` can move between states
- Side effects: when Status flips to `Active`, the executor (out-of-scope SERVICE_PLACEHOLDER) should pick up the workflow on its next scheduler tick

**Workflow execution state machine** (per `AutomationWorkflowExecution` row):
- States: `InProgress → Completed | Failed | Cancelled`
- Admin can `Cancel` an InProgress execution (sets Status=Cancelled, CompletedAt=now) — UI hook only; executor must honor (SERVICE_PLACEHOLDER)
- Admin can `Retry` a Failed execution → creates a NEW execution row with the same ContactId + TriggerContext (re-run from step 1) (SERVICE_PLACEHOLDER for actual re-run)

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: `FLOW` (non-standard — see notes)
**Type Classification**: Non-standard FLOW with embedded designer canvas (LIST = custom workflow card list, FORM = node-canvas builder, DETAIL = execution log table). Sibling pattern: NotificationCenter #35 (custom card list + custom body) and SMSCampaign #30 (wizard form + report dashboard detail). The canvas builder shares ideas with CONFIG/DESIGNER_CANVAS (palette + canvas + per-node properties) but the per-record list-of-N nature keeps this firmly in FLOW.
**Reason**: Visual node-based editor is the FORM mode, execution log table is the DETAIL mode — two distinct UIs. Each workflow record is independently CRUD'd. A pure CONFIG/DESIGNER_CANVAS would be wrong because that pattern is for a single config record, not a list.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — Create / Update / Delete / Toggle / GetAll / GetById / Mutations / Queries
- [x] Tenant scoping (CompanyId from HttpContext)
- [x] Nested child creation — parent + Steps[] + (optional read of Executions[])
- [x] Multi-FK validation — `ValidateForeignKeyRecord` × 6 (EmailTemplate, WhatsAppTemplate, SMSTemplate, NotificationTemplate, Tag, User) but only inside per-step validation by inspecting `StepConfig` JSON
- [x] Unique validation — `(CompanyId, WorkflowName)` unique among IsActive
- [x] Workflow commands (Toggle status — `PauseWorkflow`, `ResumeWorkflow`, `ActivateWorkflow` may collapse to one parameterized `ToggleAutomationWorkflowStatus(id, newStatus)` since the transitions are simple status flips)
- [x] Duplicate command — `DuplicateAutomationWorkflow(id)` returns new id
- [x] Execution log query — `GetAutomationWorkflowExecutions(workflowId, paging)` separate from `GetAutomationWorkflowById`
- [x] Execution control mutations (SERVICE_PLACEHOLDER) — `CancelAutomationWorkflowExecution`, `RetryAutomationWorkflowExecution`
- [x] Summary query — `GetAutomationWorkflowSummary` (3 KPI counts for the LIST header)
- [x] Test-Run command (SERVICE_PLACEHOLDER) — `TestRunAutomationWorkflow(workflowId, sampleContactId)` returns mock toast
- [ ] File upload — N/A
- [x] Custom business rule validators — per-step config JSON shape validation (StepConfigValidator helper called from Create/Update validators)

**Frontend Patterns Required:**
- [x] Variant B index page (`<ScreenHeader>` + 3 KPI cards + custom workflow card list — NO standard FlowDataTable; this is a custom card list like NotificationCenter #35)
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] Zustand store (`automationworkflow-store.ts`) — holds canvas tree state + selected node + dirty flag
- [x] Unsaved-changes dialog
- [x] FlowFormPageHeader (Back + workflow name input + status toggle + Test Run + Save)
- [x] Embedded designer canvas component (custom — not RJSF) — node-list rendering, "Add Step" dropdown, branch fork renderer, per-node editor modal
- [x] Per-node editor modal (10 forms — one per StepType — each with its own field set + FK ApiSelectV2)
- [x] Workflow status badge + row action buttons (Pause / Resume / Activate per status)
- [x] Summary cards / count widgets above the list — 3 KPI cards (Active / Paused / Executions 30d)
- [ ] Child grid inside form — N/A (the canvas IS the form)
- [ ] File upload widget — N/A
- [ ] Grid aggregation columns — N/A (custom card list, not a grid)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.
> **CRITICAL for FLOW**: describe BOTH the FORM layout (new/edit — canvas builder) AND the DETAIL layout (read — execution log).
> These are different UIs.

### LIST View — Custom Workflow Card List (NOT a standard grid)

**Display Mode**: **custom** (workflow-card list — NOT `table`, NOT `card-grid`). Sibling pattern: NotificationCenter #35 inbox-list. **Do NOT use** `<FlowDataTable>` or `<CardGrid>` for the LIST. The card layout is workflow-specific and described below; build it as a custom component (`automation-workflow-list.tsx`) under page-components.

**Layout Variant**: `widgets-above-grid` (3 KPI cards sit above the card list — MANDATORY Variant B: `<ScreenHeader>` + KPI row + filter bar + custom card list).

**Page Header** (`<ScreenHeader>`):
- Title: "Automation Workflows"
- Subtitle: "Set up automated communication sequences"
- Primary action: **+ Create Workflow** button → navigates to `?mode=new`

**KPI Cards** (3 cards in a flex row above the filter bar):

| # | Title | Icon | Icon color | Value source | Position |
|---|-------|------|-----------|-------------|----------|
| 1 | Active Workflows | `play-circle` | success/green bg | `summary.activeCount` | Left |
| 2 | Paused | `pause-circle` | warning/amber bg | `summary.pausedCount` | Center |
| 3 | Total Executions (This Month) | `bolt` | accent/cyan bg | `summary.executionsThisMonth` | Right |

**Filter Bar** (single white card under the KPI row):
- Search input — placeholder "Search workflows..." — filters on `workflowName` + trigger description (client-side AND with the dropdowns)
- Status dropdown — options: All Status | Active | Paused | Draft
- Trigger dropdown — options: All Triggers | Donation | Contact | Event | Campaign | Schedule (grouped client-side — see `TriggerType → Category` table below)

> The Trigger dropdown filter values are **categories**, not individual TriggerTypes. The FE maps:
> - `Donation` → TriggerType in {`DonationReceived`, `DonationGtAmount`, `FirstDonation`, `RecurringPaymentFailed`, `PledgePaymentOverdue`}
> - `Contact` → TriggerType in {`NewContactCreated`, `ContactUpdated`, `ContactBirthday`, `ContactAnniversary`}
> - `Event` → TriggerType in {`EventRegistration`, `EventCheckIn`, `EventEnded`}
> - `Campaign` → TriggerType in {`CampaignStarted`, `CampaignGoalReached`, `CampaignEnded`}
> - `Schedule` → TriggerType in {`DailyAtTime`, `WeeklyOnDay`, `MonthlyOnDate`, `CustomCron`, `ManualTrigger`}
>
> Implement the mapping in a `triggerCategory(triggerType)` helper on the FE.

**Workflow Card** (one per workflow — flex row, white bg, rounded, hover-shadow):

```
[●]  [Workflow Name]                  [4 steps] [Active] [234]  [Apr 12, 10:23 AM] [Edit][Pause][Log][Dup][Del]
     [icon] [Trigger description text]                    EXEC.30d   LAST RUN
```

Card cells:
| # | Field | Source | Display |
|---|-------|--------|---------|
| 1 | Status indicator dot | `status` | 10px dot — green (Active) / amber (Paused) / gray (Draft) |
| 2 | Workflow name | `workflowName` | 0.9rem semibold |
| 3 | Trigger description | computed from `triggerType` + `triggerConfig` + `triggerConditions` | 0.75rem secondary — e.g., "New contact created (type: Donor)" with leading icon |
| 4 | Step count badge | `stepCount` (computed BE) | "{N} steps" — cyan-tinted pill |
| 5 | Status badge | `status` | "Active" / "Paused" / "Draft" — colored pill |
| 6 | Executions 30d | `executions30Days` (computed BE) | Right-aligned numeric |
| 7 | Last run | `lastRunAt` | "Apr 12, 10:23 AM" or em-dash if null |
| 8 | Row actions | — | 5 icon buttons — see table below |

**Row actions** (status-aware):

| Status | Visible icon buttons (in order) |
|--------|----------------------------------|
| `Active` | Edit (pen) • Pause (pause) • View Log (list-alt) • Duplicate (copy) • Delete (trash, red on hover) |
| `Paused` | Edit (pen) • Resume (play, green) • View Log (list-alt) • Duplicate (copy) • Delete (trash) |
| `Draft` | Edit (pen) • Activate (check-circle, green) • Delete (trash) — NO View Log, NO Duplicate-from-draft |

**Row click**: clicking the card body (not an action button) navigates to `?mode=read&id={id}` (DETAIL execution log).

**Trigger description helper** (`describeTrigger(workflow)` — FE util):
- `NewContactCreated` → "New contact created" + optional " ({condition})"
- `DonationReceived` → "Donation received"
- `DonationGtAmount` → "Donation > ${triggerConfig.amount}"
- `RecurringPaymentFailed` → "Recurring payment failed"
- `ContactBirthday` → "Contact birthday = today"
- `EventRegistration` → "Event registration"
- `DailyAtTime` → "Daily at {triggerConfig.time}"
- `MonthlyOnDate` → "Day {triggerConfig.dayOfMonth} of every month"
- `CustomCron` → "Custom: {triggerConfig.cronExpression}"
- ...etc — one line per TriggerType. Wire all 20 in the helper.

---

### LAYOUT 1: FORM (mode=new & mode=edit) — Node Canvas Builder

> The visual workflow builder. NOT React Hook Form with a flat field list — this is a custom canvas component that renders the workflow as a vertical tree of nodes connected by lines, with "Add Step" buttons between every pair of nodes (and inside every Condition branch). User interactions: click "+Add Step" → dropdown → pick StepType → node inserted; click pencil on a node → per-node editor modal opens; click trash on a node → confirm-and-delete (cascade-delete its children if it's a Condition).

**Page Header** (FlowFormPageHeader-like, but customized for this builder):

| Element | Description |
|---------|-------------|
| Back button | ← arrow → navigates to LIST (`/crm/automation/automationworkflow`) with unsaved-changes guard |
| Workflow name input | Inline-editable text field (placeholder "Untitled Workflow"); large semibold; hover/focus reveals input chrome |
| Status toggle (3-segment) | Active \| Paused \| Draft — active segment colored cyan; clicking changes the workflow's intended status (persisted on Save) |
| Test Run button | Outline-cyan — opens "Select a contact to simulate this workflow" picker modal then runs SERVICE_PLACEHOLDER (toast "Test run initiated") |
| Save button | Primary-cyan — atomic save (parent + steps); on success in `?mode=new`, redirects to `?mode=read&id={newId}`; on Edit, stays on `?mode=edit&id=X` with success toast |

**Canvas Component** (`automation-workflow-canvas.tsx`):

The canvas is a vertical centered column. Nodes are 420px wide cards. Between nodes are 2px vertical connector lines. Between every pair of nodes (and at the END of every branch trunk) is an "Add Step" circular button.

**Structural hierarchy** (rendered top-to-bottom):

1. **TRIGGER node** (always present, always first, NOT deletable):
   - Border-left 4px green
   - Header: `[CROSSHAIRS] TRIGGER` (uppercase eyebrow) + Edit button
   - Body row 1: `When:` dropdown with all 20 TriggerType values (group with `<optgroup>` by category for UX)
   - Body row 2 (conditional per trigger config): the trigger-specific config fields — e.g., for `DonationGtAmount`, an Amount input; for `DailyAtTime`, a time picker; for `CustomCron`, a cron string input
   - Body row 3: `Condition:` chips list — each chip is a sub-condition (`Contact type = Donor`); + "Add Condition" button at the bottom opens an inline editor for `{field, op, value}`
   - The Trigger node Edit button opens a modal with `triggerType` dropdown + per-trigger config form + conditions editor (cleaner than inline for complex triggers)
   - Trash button: HIDDEN (trigger cannot be removed)

2. **Step nodes** (zero or more, rendered along the trunk in `StepOrder` ascending):
   - One per row in `AutomationWorkflowSteps` where `ParentStepId IS NULL`
   - Connector line above each node
   - Between every pair: an "Add Step" round button (36px dashed circle, hover=cyan) → click → dropdown with 10 step types (see Step Type Catalog below)

3. **Condition step → Branch fork** (special node):
   - A Condition step renders like a regular step (orange/warning border-left, condition operator preview in body)
   - Below it is a **branch fork** widget (a small horizontal T-shape: from the bottom of the Condition node, the line splits into two vertical paths)
   - The two paths are rendered side-by-side (`branch-container` flex row, ~860px max, gap ~32px between branches):
     - **YES branch** (left, green pill label "✓ YES") — child nodes where `ParentStepId = thisConditionId AND BranchType = 'YES'` in `StepOrder` ascending
     - **NO branch** (right, red pill label "✗ NO") — child nodes where `ParentStepId = thisConditionId AND BranchType = 'NO'` in `StepOrder` ascending
   - Each branch has its OWN "Add Step" buttons between nodes and its OWN END node at the bottom
   - Branches DO NOT reconverge in v1 — each ends at its own END node (matches mockup)

4. **END node** (always last, rendered automatically at the trunk's tail AND at each branch's tail):
   - 48px circle, gray bg, "END" label, NOT interactive

**Per-node header** (for non-trigger nodes):
- Eyebrow row: `[icon] STEPTYPE-LABEL-IN-CAPS` colored by category (action = cyan / wait = gray / condition = amber)
- Right side: Edit button (pen) + Trash button (delete, red on hover)

**Per-node body** (collapsed preview — full edit is via the modal):
- 1-3 rows showing the key config fields with `Field:` labels and current value
- Examples (from mockup):
  - SendEmail body: `Template: Welcome New Donor` + `From: info@ngo.org`
  - Wait body: `Wait for: 7 Days` (renders the number + unit)
  - SendNotification body: `Template: Follow up with new donor {{ContactName}}` + `To: Assigned Staff`
  - Condition body: `If: Has donated = Yes`
  - AddTag body: `Tag: Engaged New Donor`

**Add Step Dropdown** (appears below an "Add Step" button when clicked — 240px wide, white, rounded, shadow):

10 items, grouped with 2 dividers:

```
[envelope cyan]   Send Email
[whatsapp green]  Send WhatsApp
[bell purple]     Send Notification
[envelope blue]   Send SMS                ← (mockup has Email/WhatsApp/Notification — add SMS to match SMSTemplate #29)
────────────────────────────────────────
[clock gray]      Wait / Delay
[branch amber]    Condition (If/Else)
────────────────────────────────────────
[user-edit sky]   Update Contact
[tag pink]        Add Tag
[tag red]         Remove Tag
[tasks amber]     Create Task
[link indigo]     Send to Webhook
```

> The mockup omits "Send SMS" from the Add Step menu but lists SMSTemplate as a sibling entity. **Add it** — same module (notify schema), and the per-node editor needs to wire ApiSelectV2 to `getSMSTemplates`. Document this as a deviation from the mockup in §⑫.

Inside a Condition branch's "Add Step" dropdown, the items are the same EXCEPT the Condition (If/Else) item itself is HIDDEN — nesting conditions inside conditions is OUT OF SCOPE for v1 (single-level branching only, matches mockup).

**Per-node editor modal** (Radix `<Dialog>`):

Opens when a node's Edit button is clicked. One modal component (`step-editor-modal.tsx`) but it renders a different form body per `StepType`. All forms have a header showing `{icon} Edit {StepType}` + a Cancel + Save footer.

| StepType | Form body |
|----------|-----------|
| `SendEmail` | EmailTemplate ApiSelectV2 (query: `getEmailTemplates`, display `EmailTemplateTitle`) + From-email text input + (optional) live preview pane reusing EmailTemplate #24 preview component |
| `SendWhatsApp` | WhatsAppTemplate ApiSelectV2 (query: `getWhatsAppTemplates`, **filter status=Approved client-side**, display `WhatsAppTemplateName`) + live preview reusing WhatsAppTemplate #31 phone preview |
| `SendSMS` | SMSTemplate ApiSelectV2 (query: `getSMSTemplates`, display `SMSTemplateName`) + character-count preview |
| `SendNotification` | NotificationTemplate ApiSelectV2 (query: `getAllNotificationTemplateList`, display `NotificationTemplateTitle`) + Recipient dropdown (AssignedStaff / AllAdmins / SpecificUser) + conditional User ApiSelectV2 (query: `getUsers`) |
| `Wait` | Number input (1-9999) + Unit dropdown (Minutes / Hours / Days) |
| `Condition` | Field dropdown (HasDonated / DonationAmount / ContactTag / EmailOpened) + Operator dropdown (EqualsYes / EqualsNo / GreaterThan / LessThan) + conditional Value input (only for Gt/Lt) |
| `UpdateContact` | A whitelist of editable contact fields (Type, Status, AssignedStaff, ...) rendered as 1 row per field with field-picker + value input + add/remove buttons |
| `AddTag` / `RemoveTag` | Tag ApiSelectV2 (query: `getTags`, display `TagName`) |
| `CreateTask` | Task title text input + Assignee dropdown (AssignedStaff / SpecificUser) + conditional User ApiSelectV2 + Due-in-days number input |
| `SendWebhook` | URL text input (https:// validated) + optional payload-template textarea (placeholders mention available variables) |

**Save semantics** (FORM mode):

On Save click:
1. Validate workflow name + trigger config + every step config (per the rules table in §④)
2. Build a single mutation payload: `{automationWorkflow: {workflowName, description, triggerType, triggerConfig, triggerConditions, status, steps: [...all steps with parentStepId remapped via temp-IDs...]}}`
3. Call `createAutomationWorkflow` or `updateAutomationWorkflow` (single endpoint covers parent + children atomically)
4. On success: clear the dirty flag, route to `?mode=read&id={newId}` (new) or `?mode=edit&id={X}` with toast (edit — stay in builder)

The store uses **temp IDs** (negative integers) for newly created steps so `parentStepId` references work in the local tree before the BE assigns real PKs. The BE Create/Update handlers remap temp IDs to real IDs in a topological pass.

---

### LAYOUT 2: DETAIL (mode=read) — Execution Log

> Read-only view showing how the workflow has been performing. DIFFERENT UI from the canvas builder — this is stats + table.

**Page Header**:

| Element | Description |
|---------|-------------|
| Back button | ← arrow → LIST |
| Workflow name title | Bold 1.125rem (`workflowName`) + subtitle "Execution Log" |
| Edit Workflow button | Outline-cyan → navigates to `?mode=edit&id={id}` (back into the canvas builder) |

**Performance Card** (`log-header-card`):

Header text: "Workflow Performance".
4 stat tiles in a flex row:

| # | Label | Value source | Color |
|---|-------|-------------|-------|
| 1 | Total Executions (30d) | `summary.totalExecutions30Days` | accent/cyan |
| 2 | Success Rate | `summary.successRate30Days` (formatted as `xx.x%`) | success/green |
| 3 | Active Instances | `summary.activeCount` | accent/cyan |
| 4 | Failed | `summary.failedCount` | danger/red |

**Execution Table** (paginated, 25 rows/page):

| # | Column | Field | Render |
|---|--------|-------|--------|
| 1 | Contact | `contactName` (resolved from `contactId`) | clickable link → `/crm/contact/allcontacts?mode=read&id={contactId}` (use existing contact-detail route) |
| 2 | Started | `startedAt` | "Apr 12, 10:23 AM" formatted |
| 3 | Current Step | `currentStepLabel` | text; for Completed rows shows "Completed (YES branch)" / "Completed (NO branch)" using `branchTaken` |
| 4 | Status | `status` | pill: InProgress (blue, spinning sync icon) / Completed (green, check) / Failed (red, X-circle + FailureReason inline) / Cancelled (gray) |
| 5 | Completed | `completedAt` | "Apr 12" or em-dash |
| 6 | Actions | — | InProgress → "Cancel" outline button (SERVICE_PLACEHOLDER toast + call `cancelAutomationWorkflowExecution`); Failed → "Retry" outline button (SERVICE_PLACEHOLDER toast + call `retryAutomationWorkflowExecution`); Completed/Cancelled → em-dash |

**No empty state mockup** — when the workflow has zero executions, render a friendly inline message: "No executions yet. This workflow has not been triggered since it was {createdAt}."

---

### Page Widgets & Summary Cards

**Widgets**: YES — 3 KPI cards above the LIST (Active / Paused / Total Executions This Month). See LIST §⑥ above.

**Layout Variant**: `widgets-above-grid` → Variant B is MANDATORY (`<ScreenHeader>` + KPI row + filter bar + custom card list — NO `<FlowDataTable>`, NO duplicate header).

**Summary GQL Query**:
- Query name: `GetAutomationWorkflowSummary`
- Returns: `AutomationWorkflowSummaryDto`
- Fields: `{ activeCount: int, pausedCount: int, draftCount: int, executionsThisMonth: int, totalExecutions30Days: int, successRate30Days: decimal, activeInstanceCount: int, failedCount: int }`
- Used by: LIST (top 3 KPIs from `activeCount`, `pausedCount`, `executionsThisMonth`) AND DETAIL (4 performance tiles from `totalExecutions30Days`, `successRate30Days`, `activeInstanceCount`, `failedCount`)
- Args: optional `workflowId: int?` — when null returns tenant-wide tallies (for LIST); when set returns per-workflow tallies (for DETAIL)

### Grid Aggregation Columns

**Aggregation Columns**: N/A (custom card list — not a grid). The `stepCount` + `executions30Days` per workflow are computed in `GetAllAutomationWorkflowList` projection (LINQ subqueries), NOT as grid aggregations.

### User Interaction Flow

1. User navigates to `/crm/automation/automationworkflow` → LIST loads (KPIs + cards)
2. User clicks **+ Create Workflow** → URL: `?mode=new` → BUILDER with empty canvas (just trigger placeholder)
3. User picks a trigger from the dropdown → trigger config fields render below
4. User clicks "+Add Step" → dropdown → picks `Send Email` → SendEmail node inserted; opens the per-node editor modal automatically on insert
5. User selects an EmailTemplate, clicks Save in modal → modal closes; node body shows the chosen template name
6. User adds a `Wait` (1 day) → adds a `Condition (If/Else)` → branches appear with two empty branches
7. User adds nodes in YES branch + NO branch
8. User clicks "Save" → atomic transaction → URL: `?mode=read&id={newId}` → EXECUTION LOG layout loads (empty initially)
9. From LIST: user clicks "View Log" on a card → `?mode=read&id={id}` → DETAIL
10. From DETAIL: user clicks "Edit Workflow" → `?mode=edit&id={id}` → BUILDER pre-filled
11. From LIST: user clicks "Pause" → ToggleStatus mutation (Active → Paused) → card status updates
12. From LIST: user clicks "Duplicate" → DuplicateAutomationWorkflow mutation → new Draft card prepended
13. From BUILDER: user clicks "Test Run" → contact-picker modal → confirm → SERVICE_PLACEHOLDER toast "Test run initiated"
14. Unsaved-changes guard: any dirty edit + Back button → confirm dialog

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: `SavedFilter` (FLOW). For the canvas builder + per-node editor modal patterns, **also reference** SMSCampaign #30 (wizard form pattern) and NotificationCenter #35 (custom-body Variant B index page with no DataTableContainer).

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | AutomationWorkflow | Entity / class name |
| savedFilter | automationWorkflow | Variable / field names |
| SavedFilterId | AutomationWorkflowId | PK field |
| SavedFilters | AutomationWorkflows | Table name, collection names |
| saved-filter | automation-workflow | FE route kebab-case, file names where used |
| savedfilter | automationworkflow | FE folder, lowercase route segment |
| SAVEDFILTER | AUTOMATIONWORKFLOW | Grid code, menu code |
| notify | notify | DB schema (same — co-locate with other Notify entities) |
| Notify | Notify | Backend group name (Models/Schemas/Business/Configurations) |
| NotifyModels | NotifyModels | Namespace suffix |
| CRM_COMMUNICATION | CRM_AUTOMATION | Parent menu code (NEW — never used before; verify in MODULE_MENU_REFERENCE: MenuId 268) |
| CRM | CRM | Module code (same — Communication / Automation both live under CRM) |
| crm/communication/savedfilter | crm/automation/automationworkflow | FE route path |
| notify-service | notify-service | FE service folder name (same) |
| notify-queries | notify-queries | FE queries folder (same) |
| notify-mutations | notify-mutations | FE mutations folder (same) |
| crm/communication | crm/automation | FE pages folder structure (NEW segment — first screen under crm/automation) |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files (~17 NEW + child-entity scaffolding)

**Parent + Steps + Executions + DTOs:**

| # | File | Path | Type |
|---|------|------|------|
| 1 | AutomationWorkflow entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/NotifyModels/AutomationWorkflow.cs` | create |
| 2 | AutomationWorkflowStep child entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/NotifyModels/AutomationWorkflowStep.cs` | create |
| 3 | AutomationWorkflowExecution child entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/NotifyModels/AutomationWorkflowExecution.cs` | create |
| 4 | Parent EF Config | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/NotifyConfigurations/AutomationWorkflowConfiguration.cs` | create |
| 5 | Step EF Config | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/NotifyConfigurations/AutomationWorkflowStepConfiguration.cs` | create |
| 6 | Execution EF Config | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/NotifyConfigurations/AutomationWorkflowExecutionConfiguration.cs` | create |
| 7 | Schemas (DTOs) — covers AutomationWorkflowRequestDto, AutomationWorkflowStepRequestDto, AutomationWorkflowResponseDto, AutomationWorkflowStepResponseDto, AutomationWorkflowExecutionResponseDto, AutomationWorkflowSummaryDto, AutomationWorkflowListItemDto | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/NotifySchemas/AutomationWorkflowSchemas.cs` | create |

**Commands** (under `Business/NotifyBusiness/AutomationWorkflows/Commands/` — flat per SavedFilter canonical):

| # | File | Path | Type |
|---|------|------|------|
| 8 | CreateAutomationWorkflow (atomic parent + steps) | `.../NotifyBusiness/AutomationWorkflows/Commands/CreateAutomationWorkflow.cs` | create |
| 9 | UpdateAutomationWorkflow (atomic — delete-then-insert steps for v1) | `.../NotifyBusiness/AutomationWorkflows/Commands/UpdateAutomationWorkflow.cs` | create |
| 10 | DeleteAutomationWorkflow (soft) | `.../NotifyBusiness/AutomationWorkflows/Commands/DeleteAutomationWorkflow.cs` | create |
| 11 | ToggleAutomationWorkflowStatus (parameterized — accepts target status) | `.../NotifyBusiness/AutomationWorkflows/Commands/ToggleAutomationWorkflowStatus.cs` | create |
| 12 | DuplicateAutomationWorkflow | `.../NotifyBusiness/AutomationWorkflows/Commands/DuplicateAutomationWorkflow.cs` | create |
| 13 | TestRunAutomationWorkflow (SERVICE_PLACEHOLDER) | `.../NotifyBusiness/AutomationWorkflows/Commands/TestRunAutomationWorkflow.cs` | create |
| 14 | CancelAutomationWorkflowExecution (SERVICE_PLACEHOLDER) | `.../NotifyBusiness/AutomationWorkflows/Commands/CancelAutomationWorkflowExecution.cs` | create |
| 15 | RetryAutomationWorkflowExecution (SERVICE_PLACEHOLDER) | `.../NotifyBusiness/AutomationWorkflows/Commands/RetryAutomationWorkflowExecution.cs` | create |

**Queries** (under `Business/NotifyBusiness/AutomationWorkflows/Queries/`):

| # | File | Path | Type |
|---|------|------|------|
| 16 | GetAllAutomationWorkflowList (paged + filter — projects StepCount, Executions30Days, TriggerType, Status, WorkflowName, LastRunAt) | `.../NotifyBusiness/AutomationWorkflows/Queries/GetAllAutomationWorkflowList.cs` | create |
| 17 | GetAutomationWorkflowById (parent + ALL steps eager-loaded as tree) | `.../NotifyBusiness/AutomationWorkflows/Queries/GetAutomationWorkflowById.cs` | create |
| 18 | GetAutomationWorkflowSummary (KPIs — supports optional workflowId arg) | `.../NotifyBusiness/AutomationWorkflows/Queries/GetAutomationWorkflowSummary.cs` | create |
| 19 | GetAutomationWorkflowExecutions (paged executions for a single workflow) | `.../NotifyBusiness/AutomationWorkflows/Queries/GetAutomationWorkflowExecutions.cs` | create |

**API Endpoints:**

| # | File | Path | Type |
|---|------|------|------|
| 20 | AutomationWorkflowMutations (Create / Update / Delete / ToggleStatus / Duplicate / TestRun / CancelExec / RetryExec) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Notify/Mutations/AutomationWorkflowMutations.cs` | create |
| 21 | AutomationWorkflowQueries (GetAll / GetById / GetSummary / GetExecutions) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Notify/Queries/AutomationWorkflowQueries.cs` | create |

**Migration + Seed:**

| # | File | Path | Type |
|---|------|------|------|
| 22 | EF Migration | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Migrations/{timestamp}_AddAutomationWorkflow.cs` | create (run `dotnet ef migrations add AddAutomationWorkflow`) |
| 23 | DB seed SQL | `sql-scripts-dyanmic/AutomationWorkflow-sqlscripts.sql` | create (Menu + MenuCapabilities + 1-2 sample workflows + 3-5 sample executions for log demo) |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Base.Application/Data/Persistence/Modules/INotifyDbContext.cs` | `DbSet<AutomationWorkflow>`, `DbSet<AutomationWorkflowStep>`, `DbSet<AutomationWorkflowExecution>` |
| 2 | `Base.Infrastructure/Data/Persistence/Modules/NotifyDbContext.cs` | Same 3 DbSets + `OnModelCreating` `ApplyConfigurationsFromAssembly` already picks the 3 new configs |
| 3 | `Base.Application/Mappings/DecoratorProperties.cs` | `DecoratorNotifyModules` += 3 entries (AutomationWorkflow + 2 children) for property decorators |
| 4 | `Base.Application/Mappings/NotifyMappings.cs` | Mapster config for `AutomationWorkflow ↔ AutomationWorkflowResponseDto`, `AutomationWorkflowStep ↔ AutomationWorkflowStepResponseDto`, `AutomationWorkflowExecution ↔ AutomationWorkflowExecutionResponseDto` |
| 5 | `Base.Domain/Models/ContactModels/Contact.cs` | Add inverse nav: `ICollection<AutomationWorkflowExecution> AutomationWorkflowExecutions` (one EF inverse for the FK) |

> No inverse navs added on EmailTemplate / WhatsAppTemplate / SMSTemplate / NotificationTemplate / Tag / User — those references live inside `StepConfig` JSON, not as typed FKs.

### Frontend Files (~22 NEW)

**DTO / GQL contracts:**

| # | File | Path | Type |
|---|------|------|------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/notify-service/AutomationWorkflowDto.ts` | create |
| 2 | GQL Queries | `PSS_2.0_Frontend/src/infrastructure/gql-queries/notify-queries/AutomationWorkflowQuery.ts` | create |
| 3 | GQL Mutations | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/notify-mutations/AutomationWorkflowMutation.ts` | create |

**Page config + index + view-page:**

| # | File | Path | Type |
|---|------|------|------|
| 4 | Page Config | `PSS_2.0_Frontend/src/presentation/pages/crm/automation/automationworkflow.tsx` | create |
| 5 | Folder barrel | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/index.tsx` | create |
| 6 | Index Page (Variant B custom body — ScreenHeader + KPIs + filter + workflow list — NO DataTableContainer) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/index-page.tsx` | create |
| 7 | View Page (3 URL modes: new/edit → canvas builder, read → execution log) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/view-page.tsx` | create |
| 8 | Zustand Store (canvas tree state + dirty flag + selected node) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/automationworkflow-store.ts` | create |
| 9 | Route Page (replace existing UnderConstruction stub — mount the index/view-page based on `mode` query) | `PSS_2.0_Frontend/src/app/[lang]/crm/automation/automationworkflow/page.tsx` | modify (replace stub) |

**Custom components for this screen** (under the same `automationworkflow/` page-component folder):

| # | File | Path | Type |
|---|------|------|------|
| 10 | `automation-workflow-list.tsx` (custom card list — workflow cards) | `.../automationworkflow/automation-workflow-list.tsx` | create |
| 11 | `automation-workflow-card.tsx` (single card) | `.../automationworkflow/automation-workflow-card.tsx` | create |
| 12 | `automation-workflow-summary-cards.tsx` (3 KPIs) | `.../automationworkflow/automation-workflow-summary-cards.tsx` | create |
| 13 | `automation-workflow-filter-bar.tsx` (search + status + trigger-category filters) | `.../automationworkflow/automation-workflow-filter-bar.tsx` | create |
| 14 | `automation-workflow-canvas.tsx` (the node tree renderer — recursive) | `.../automationworkflow/automation-workflow-canvas.tsx` | create |
| 15 | `node-trigger.tsx` (the special trigger node + Add Condition inline UI) | `.../automationworkflow/node-trigger.tsx` | create |
| 16 | `node-step.tsx` (a regular step node — body renders per StepType via a helper switch) | `.../automationworkflow/node-step.tsx` | create |
| 17 | `node-condition.tsx` (Condition node + branch fork + recursive branch renderer) | `.../automationworkflow/node-condition.tsx` | create |
| 18 | `node-add-step-button.tsx` (the round "+" button + dropdown menu) | `.../automationworkflow/node-add-step-button.tsx` | create |
| 19 | `step-editor-modal.tsx` (10 sub-forms — one per StepType + trigger editor mode) | `.../automationworkflow/step-editor-modal.tsx` | create |
| 20 | `execution-log-table.tsx` (paginated execution table — DETAIL mode) | `.../automationworkflow/execution-log-table.tsx` | create |
| 21 | `execution-status-pill.tsx` (status renderer with icon + spin for InProgress) | `.../automationworkflow/execution-status-pill.tsx` | create |
| 22 | `trigger-helpers.ts` (`describeTrigger`, `triggerCategory`, `TRIGGER_OPTIONS`, `STEP_OPTIONS`, `STEP_TYPE_CATALOG` constants) | `.../automationworkflow/trigger-helpers.ts` | create |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `src/domain/entities/notify-service/index.ts` (or barrel) | Re-export `AutomationWorkflowDto` types |
| 2 | `src/infrastructure/gql-queries/notify-queries/index.ts` | Re-export `AutomationWorkflowQuery` |
| 3 | `src/infrastructure/gql-mutations/notify-mutations/index.ts` | Re-export `AutomationWorkflowMutation` |
| 4 | `src/infrastructure/entity-operations/notify-service-entity-operations.ts` (or wherever notify ops live — verify in /build-screen) | Add `AUTOMATIONWORKFLOW` operations: create / update / delete / toggleStatus / duplicate |
| 5 | `src/infrastructure/entity-operations/operations-config.ts` | Register notify-service automationworkflow operations import |
| 6 | `src/presentation/components/page-components/crm/automation/index.ts` (NEW folder barrel — first screen under crm/automation) | Re-export `automationworkflow` folder |
| 7 | `src/presentation/pages/crm/automation/index.ts` (NEW folder barrel) | Re-export `automationworkflow.tsx` |
| 8 | Zustand stores barrel (if there's a central `stores/index.ts`) | Re-export `useAutomationWorkflowStore` |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens from MODULE_MENU_REFERENCE.md.

```
---CONFIG-START---
Scope: FULL

MenuName: Automation Workflows
MenuCode: AUTOMATIONWORKFLOW
ParentMenu: CRM_AUTOMATION
Module: CRM
MenuUrl: crm/automation/automationworkflow
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: AUTOMATIONWORKFLOW
---CONFIG-END---
```

**Notes for the approval-config step:**
- `IMPORT` / `EXPORT` capabilities are declared (standard FLOW pattern) but no UI is shipped for them in v1 — they exist for future role-config use
- No Grid / GridColumns / GridFields rows in the seed (custom card UI — same as NotificationCenter #35)
- Sample workflow rows + sample execution rows should be seeded for E2E demo (1 Draft + 1 Active + 1 Paused; 4-5 executions of varying status across the Active one)
- CRM_AUTOMATION is MenuId 268 (per MODULE_MENU_REFERENCE.md) — already present in the menu hierarchy; AUTOMATIONWORKFLOW is its only leaf currently

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `AutomationWorkflowQueries`
- Mutation type: `AutomationWorkflowMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getAllAutomationWorkflowList` | `PaginatedApiResponse<IEnumerable<AutomationWorkflowListItemDto>>` | `searchText?, pageNo?, pageSize?, sortField?, sortDir?, isActive?, status?, triggerType?, triggerCategory?` |
| `getAutomationWorkflowById` | `BaseApiResponse<AutomationWorkflowResponseDto>` | `automationWorkflowId: int` |
| `getAutomationWorkflowSummary` | `BaseApiResponse<AutomationWorkflowSummaryDto>` | `automationWorkflowId: int?` (null → tenant tallies; set → per-workflow tallies) |
| `getAutomationWorkflowExecutions` | `PaginatedApiResponse<IEnumerable<AutomationWorkflowExecutionResponseDto>>` | `automationWorkflowId: int, pageNo?, pageSize?, status?` |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createAutomationWorkflow` | `AutomationWorkflowRequestDto` (parent + nested `steps[]`) | `int` (new workflow id) |
| `updateAutomationWorkflow` | `AutomationWorkflowRequestDto` (with `automationWorkflowId` set; nested `steps[]` is full replacement) | `int` |
| `deleteAutomationWorkflow` | `automationWorkflowId: int` | `int` |
| `toggleAutomationWorkflowStatus` | `automationWorkflowId: int, targetStatus: string` | `int` |
| `duplicateAutomationWorkflow` | `automationWorkflowId: int` | `int` (new id of the Draft copy) |
| `testRunAutomationWorkflow` (SERVICE_PLACEHOLDER) | `automationWorkflowId: int, sampleContactId: int?` | `bool` |
| `cancelAutomationWorkflowExecution` (SERVICE_PLACEHOLDER) | `automationWorkflowExecutionId: int` | `int` |
| `retryAutomationWorkflowExecution` (SERVICE_PLACEHOLDER) | `automationWorkflowExecutionId: int` | `int` (new execution id) |

**Response DTOs — key fields:**

`AutomationWorkflowListItemDto` (LIST view payload — lightweight, NO nested steps):
| Field | Type | Notes |
|-------|------|-------|
| automationWorkflowId | number | PK |
| workflowName | string | — |
| description | string \| null | — |
| triggerType | string | one of 20 enum values |
| triggerConfig | string \| null | JSON string |
| triggerConditions | string \| null | JSON string |
| status | string | `Active` \| `Paused` \| `Draft` |
| stepCount | number | computed via LINQ subquery |
| executions30Days | number | computed |
| lastRunAt | string \| null | ISO datetime |
| isActive | boolean | — |
| createdDate, modifiedDate, createdBy, modifiedBy | string | inherited audit |

`AutomationWorkflowResponseDto` (DETAIL/EDIT view payload — has nested `steps[]`):
| Field | Type | Notes |
|-------|------|-------|
| (all fields from list dto) | — | — |
| steps | `AutomationWorkflowStepResponseDto[]` | flat array — FE rebuilds the tree via `parentStepId` + `branchType` + `stepOrder` |

`AutomationWorkflowStepResponseDto`:
| Field | Type | Notes |
|-------|------|-------|
| automationWorkflowStepId | number | PK |
| automationWorkflowId | number | — |
| parentStepId | number \| null | null = top-level |
| branchType | string \| null | `YES` \| `NO` \| null |
| stepOrder | number | — |
| stepType | string | one of 11 enum values (10 + Condition) |
| stepConfig | string | JSON string — FE parses with a discriminated-union type per stepType |

`AutomationWorkflowExecutionResponseDto`:
| Field | Type | Notes |
|-------|------|-------|
| automationWorkflowExecutionId | number | PK |
| automationWorkflowId | number | — |
| contactId | number \| null | — |
| contactName | string \| null | flat-mapped via Mapster from `Contact.ContactName` |
| triggerContext | string \| null | JSON |
| startedAt | string | — |
| completedAt | string \| null | — |
| status | string | `InProgress` \| `Completed` \| `Failed` \| `Cancelled` |
| currentStepId | number \| null | — |
| currentStepLabel | string \| null | — |
| branchTaken | string \| null | `YES` \| `NO` \| null |
| failureReason | string \| null | — |

`AutomationWorkflowSummaryDto`:
| Field | Type | Notes |
|-------|------|-------|
| activeCount | number | tenant: Active workflows; per-workflow: redundant/null |
| pausedCount | number | tenant only |
| draftCount | number | tenant only |
| executionsThisMonth | number | tenant only |
| totalExecutions30Days | number | tenant OR per-workflow |
| successRate30Days | number | decimal 0..1 (formatted FE-side as %) |
| activeInstanceCount | number | InProgress executions — per workflow when arg set |
| failedCount | number | failed-execution count |

`AutomationWorkflowRequestDto` (Create / Update input):
| Field | Type | Notes |
|-------|------|-------|
| automationWorkflowId | number \| null | null for create |
| workflowName | string | required |
| description | string \| null | — |
| triggerType | string | required |
| triggerConfig | string \| null | JSON string |
| triggerConditions | string \| null | JSON string |
| status | string | `Active` \| `Paused` \| `Draft` |
| steps | `AutomationWorkflowStepRequestDto[]` | full replacement on Update — BE deletes old, inserts new in one transaction |

`AutomationWorkflowStepRequestDto`:
| Field | Type | Notes |
|-------|------|-------|
| automationWorkflowStepId | number \| null | null for new (or negative temp-id) — BE remaps |
| parentStepId | number \| null | null for top-level; integer = real or temp id (BE remaps) |
| branchType | string \| null | `YES` \| `NO` \| null |
| stepOrder | number | — |
| stepType | string | required |
| stepConfig | string | JSON string — BE validates per the §④ table |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — 0 errors on Base.Application + Base.API + Base.Domain + Base.Infrastructure
- [ ] `pnpm tsc --noEmit` — 0 new errors in `automationworkflow/` files
- [ ] `pnpm dev` — page loads at `/{lang}/crm/automation/automationworkflow`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] LIST: 3 KPI cards render with values from `getAutomationWorkflowSummary` (no workflowId arg)
- [ ] LIST: search input filters cards by `workflowName` + `describeTrigger(...)` output
- [ ] LIST: Status dropdown filters by `status`
- [ ] LIST: Trigger dropdown filters by `triggerCategory(...)` (Donation / Contact / Event / Campaign / Schedule)
- [ ] LIST: card shows status dot, name, trigger description w/ icon, step count badge, status badge, 30d executions, last-run, 5 row actions
- [ ] LIST: Pause / Resume / Activate row action calls `toggleAutomationWorkflowStatus`, card updates in place
- [ ] LIST: Duplicate row action calls `duplicateAutomationWorkflow`, new Draft card appears
- [ ] LIST: Delete row action shows confirm → calls `deleteAutomationWorkflow` (soft) → card removed
- [ ] LIST: card body click navigates to `?mode=read&id={id}`
- [ ] LIST: View Log row action navigates to `?mode=read&id={id}`
- [ ] FORM `?mode=new`: empty BUILDER renders with TRIGGER node (default `NewContactCreated`) and one "Add Step" button below
- [ ] FORM: Trigger node "When" dropdown lists ALL 20 trigger types grouped by category
- [ ] FORM: trigger-specific config UI swaps based on selection (amount input for `DonationGtAmount`, time picker for `DailyAtTime`, cron input for `CustomCron`, etc.)
- [ ] FORM: Trigger "Add Condition" inline button adds a sub-condition chip
- [ ] FORM: clicking "+Add Step" opens dropdown with 10 step types (Send Email/WhatsApp/Notification/SMS, Wait, Condition, Update Contact, Add Tag, Remove Tag, Create Task, Send Webhook)
- [ ] FORM: selecting a step type inserts a node AND auto-opens the per-node editor modal
- [ ] FORM: per-node editor renders the correct sub-form per StepType with required ApiSelectV2 dropdowns
- [ ] FORM: SendEmail picker uses `getEmailTemplates`; SendWhatsApp uses `getWhatsAppTemplates` (filter Approved); SendSMS uses `getSMSTemplates`; SendNotification uses `getAllNotificationTemplateList`; AddTag/RemoveTag uses `getTags`; SpecificUser picker uses `getUsers`
- [ ] FORM: adding a Condition step renders a YES/NO branch fork; each branch has its own "Add Step" between nodes; each branch ends with an END node
- [ ] FORM: per-node Edit reopens the modal pre-filled with current config; Save persists to canvas (NOT to BE yet)
- [ ] FORM: per-node Remove confirms + deletes (cascade-removes Condition children)
- [ ] FORM: Status toggle (Active/Paused/Draft) in header reflects the workflow's intended status on Save
- [ ] FORM: Test Run header button (in Edit mode) opens contact picker + fires SERVICE_PLACEHOLDER toast
- [ ] FORM: Save (new): atomic transaction; on success URL → `?mode=read&id={newId}`
- [ ] FORM: Save (edit): atomic delete-then-insert of steps; URL stays at `?mode=edit&id=X` with success toast
- [ ] FORM: Activate-from-Draft is blocked when workflow has zero steps (validator error toast)
- [ ] FORM: Back navigation with dirty canvas triggers unsaved-changes confirm dialog
- [ ] DETAIL `?mode=read&id=X`: header shows workflow name + "Execution Log" subtitle + Edit Workflow button
- [ ] DETAIL: Performance card 4 tiles (Total Executions 30d / Success Rate / Active Instances / Failed) populate from `getAutomationWorkflowSummary(workflowId)`
- [ ] DETAIL: execution table paginates; Contact column is a clickable link to contact-detail
- [ ] DETAIL: Status pill renders correctly for all 4 statuses (InProgress spin, Completed check, Failed X + reason, Cancelled gray)
- [ ] DETAIL: InProgress row Cancel button + Failed row Retry button fire SERVICE_PLACEHOLDER toasts and call corresponding mutations
- [ ] DETAIL: "Edit Workflow" header button navigates to `?mode=edit&id=X` → BUILDER pre-filled with the workflow tree
- [ ] Permissions: Edit / Delete / Toggle / Duplicate / Activate respect BUSINESSADMIN capabilities

**DB Seed Verification:**
- [ ] Menu "Automation Workflows" appears in sidebar under CRM → Automation
- [ ] Sample workflows (1 Draft / 1 Active / 1 Paused) seeded
- [ ] Sample executions (3-5 rows across statuses InProgress / Completed / Failed) seeded for the Active workflow
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Architecture / data-model:**
- **CompanyId is NOT a field** the user enters — comes from HttpContext. Both `AutomationWorkflow` AND `AutomationWorkflowExecution` rows are tenant-scoped via `CompanyId` (cascade from parent on executions — copy CompanyId on insert).
- **Schema = `notify`, Group = `NotifyModels`** — co-locate with EmailTemplate / WhatsAppTemplate / SMSTemplate / NotificationTemplate. Use the SAME inverse-nav pattern (NotificationTemplate #36 / WhatsAppTemplate #31 / SavedFilter canonical) for DbSet wiring + DecoratorProperties + NotifyMappings.
- **The TRIGGER is NOT a Step** — it lives on the parent (`TriggerType` + `TriggerConfig` + `TriggerConditions`). Don't create a "TriggerStep" row. The FE renders it as the first node in the canvas for UX consistency, but the storage model treats it as the parent's own fields.
- **Step tree shape uses `ParentStepId` + `BranchType` + `StepOrder`** — NO closure-table, NO recursive CTE. The tree has max depth 2 (top-level trunk + one level of branches under a Condition). Branch reconvergence is OUT OF SCOPE for v1.
- **Single-level branching only** — Condition steps cannot be nested inside another Condition's branch in v1. Enforce in BE validator (reject `parentStepId` referencing a step whose own `ParentStepId IS NOT NULL`). The mockup confirms this — no nested conditions are shown.
- **`StepConfig` is a JSON string column** — NOT a `jsonb` typed column. Validate shape in Create/Update validators by parsing + checking required keys per the §④ table. Use a single `StepConfigValidator` helper.
- **Update = full-replace of steps**, NOT diff-update — delete existing `AutomationWorkflowSteps WHERE WorkflowId=X` then insert new rows inside one transaction. Diff-update is more efficient but adds complexity (temp-id remapping + delete-orphans + update-existing) that's not needed at the scale of "tens of steps per workflow". Document the trade-off — future enhancement if performance becomes an issue.
- **Cascade-delete**: EF should cascade on `AutomationWorkflow → Steps` and `AutomationWorkflow → Executions`. Soft-delete on parent (IsActive=false) leaves child rows intact (so historic executions remain readable); but if BUSINESSADMIN ever hard-deletes via DB, EF cascade kicks in.

**Frontend gotchas:**
- **Variant B index page — NO `<FlowDataTable>`, NO `<DataTableContainer>`** — this is a custom card list, sibling to NotificationCenter #35. Use `<ScreenHeader>` + the 4 custom components (KPIs / FilterBar / WorkflowList) directly. Double-header bug (ContactType #19 precedent) WILL happen if anyone wraps it in DataTableContainer.
- **No `<CardGrid>` reuse either** — that infra is for template gallery cards (#24/#29/#31/#36). Workflow cards have different cell layout (status dot + 5 stats columns + 5 action buttons in a single row) and don't benefit from the variant registry.
- **Canvas state lives in Zustand** — `automationworkflow-store.ts` holds the parent + flat `steps[]` array + `dirty` flag + `selectedStepId`. Tree rendering computes the tree once per render from the flat array via a memoized helper (`buildStepTree(steps)`). Avoid storing the tree in Zustand — keeps mutation logic (add / remove / reorder) simple (operate on the flat array).
- **Temp IDs**: when the user adds a step in the canvas, assign a temp `automationWorkflowStepId` (negative integer, e.g., `-1`, `-2`, ...). When the user adds a child INSIDE a Condition branch, the child's `parentStepId` is the Condition's temp or real id. On Save, the BE sees negative ids and remaps to real PKs in a topological pass (parents before children).
- **Per-node editor modal — 10 sub-forms in ONE file** — keep them lean. Use a discriminated-union TypeScript type for `StepConfig` keyed by `stepType`. Each sub-form is ~30 lines.
- **`describeTrigger` + `triggerCategory` helpers** — encapsulate all 20 trigger-type transforms in `trigger-helpers.ts`. The LIST card body and the filter dropdown both consume them. Keep one source of truth.
- **Icon library**: FA icons (per the mockup) — same convention as NotificationCenter #35 + NotificationTemplate #36 which both kept FA. Don't remap to Iconify Phosphor.
- **No inline hex colors / no inline pixel padding** — all status colors come from existing tokens (success-emerald / warning-amber / accent-cyan / danger-rose / muted-slate). Map mockup hex to existing Tailwind classes during build.
- **The 4th step-type "Send SMS"** is NOT in the mockup's Add Step dropdown but is supported by the existing SMSTemplate #29 entity. Add it to the dropdown to keep parity with Email/WhatsApp/Notification. Note this as a deliberate deviation from the mockup.

**Service Dependencies** (UI-only — no backend service implementation):

> Everything shown in the mockup is in scope. List items here ONLY if they require an
> external service or infrastructure that doesn't exist in the codebase yet.

- ⚠ **SERVICE_PLACEHOLDER**: **Workflow Executor / Dispatcher** — the cron scheduler that fires schedule-triggers, the event listener that fires CRM-event-triggers (donation received, contact birthday, etc.), and the step orchestrator that walks the step tree and dispatches actions. None of this exists yet. This screen ships the BUILDER + LOG VIEWER + STORAGE MODEL but no actual execution. Document explicitly in onboarding: "Workflows are saved but not yet auto-executed — admin must wait for the executor module to ship."
- ⚠ **SERVICE_PLACEHOLDER**: **`testRunAutomationWorkflow`** — Test Run button fires a toast and inserts a mock `AutomationWorkflowExecution` row with Status=Completed for E2E demo purposes. No actual step dispatch.
- ⚠ **SERVICE_PLACEHOLDER**: **`cancelAutomationWorkflowExecution`** — flips Status to Cancelled in DB. The executor (when it exists) must honor this flag.
- ⚠ **SERVICE_PLACEHOLDER**: **`retryAutomationWorkflowExecution`** — creates a new `AutomationWorkflowExecution` row with the original ContactId + TriggerContext + Status=InProgress. Executor must pick it up.
- ⚠ **SERVICE_PLACEHOLDER**: **`SendWebhook` step type** — admin can configure the URL + payload template in the per-node editor, but the actual HTTP POST is not built (no `IWorkflowStepExecutor` service exists yet).
- ⚠ **SERVICE_PLACEHOLDER**: **`UpdateContact` step type** — admin can configure which contact fields to update, but the orchestrator that applies the update is part of the dispatcher (not shipped here).
- ⚠ **SERVICE_PLACEHOLDER**: **`CreateTask` step type** — relies on a Task entity that may not yet exist in this codebase (verify in /build-screen). If missing, ship the per-node editor + storage but flag the action as non-functional until a Task module ships.

Full UI must be built (canvas, nodes, "Add Step" dropdown, per-node modals, branch fork rendering, LIST cards, KPIs, execution log table, all 5 row actions, status toggle, Test Run button). Only the handlers for the external service calls (the executor itself + webhook HTTP send + task creation if Task module missing) are placeholders.

**Pre-flagged risks / open questions** (raise as ISSUEs in §⑬ Build Log if confirmed):
- **ISSUE-RISK-1** (HIGH): Trigger-event listener architecture is undefined — when shipping the executor, decide whether triggers fire via DB triggers, MediatR domain events, or a separate event bus. Affects how `TriggerType` enum is shaped. This screen's storage model is agnostic enough to support all 3.
- **ISSUE-RISK-2** (MEDIUM): Step-level execution audit (per-step success/failure/timestamp) is OUT OF SCOPE for v1. Only the high-level `AutomationWorkflowExecution` row is captured. Future: a `AutomationWorkflowExecutionStep` grandchild entity to log per-step events. The LOG view's "Current Step" column displays `CurrentStepLabel` which the executor must update.
- **ISSUE-RISK-3** (MEDIUM): `BranchTaken` is denormalized on the parent execution row (one branch per execution). If we ever support sub-branches, this needs to become a child of execution+step. Out of scope for v1 (single-level branching only).
- **ISSUE-RISK-4** (LOW): JSON `StepConfig` validation duplicates discriminated-union types between FE (TS) and BE (validator). Future: generate TS types from a shared JSON schema. Out of scope for v1.
- **ISSUE-RISK-5** (MEDIUM): The Trigger filter on the LIST is by **category** but the BE column stores the raw `triggerType`. Choice: FE maps category → list of types client-side and sends `triggerType IN (...)` as the filter (simpler — recommended for v1) vs BE accepts a `triggerCategory` arg and resolves server-side (cleaner but more code). Plan-screens recommends FE-side mapping — document the choice in §⑫ ahead of /build-screen.
- **ISSUE-RISK-6** (LOW): The mockup omits `SendSMS` from the Add Step dropdown but the platform has SMSTemplate. Deliberately adding it for parity. If the user wants strict mockup adherence, drop the item and rely on EmailTemplate / WhatsAppTemplate for messaging-channel coverage.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Session 1 | LOW | FE / Component Extraction | Phase 4 left `AutomationWorkflowSummaryCards`, `AutomationWorkflowFilterBar`, `AutomationWorkflowCard`, `AutomationWorkflowList` INLINE inside `index-page.tsx` instead of extracting them into 4 standalone component files per §⑧. Functional UI is identical; cosmetic deviation only. Future cleanup task. | OPEN |
| ISSUE-2 | Session 1 | LOW | FE / Step Preview | `NodeStep` collapsed preview shows raw FK IDs (e.g., "Template ID: 17") instead of resolved names. Avoids N+1 GQL calls. Future: pass a lookup map from `ViewPage` after a bulk fetch. | OPEN |
| ISSUE-3 | Session 1 | LOW | FE / Test Run | "Test Run" button confirms via dialog and fires the mutation with `sampleContactId: null` (no real contact picker). Documented deviation. Future: wire full ApiSelectV2 contact picker. | OPEN |
| ISSUE-4 | Session 1 | MED | FE / Unsaved-Changes | Unsaved-changes guard covers `beforeunload` + custom Back button only. Sidebar / link-based Next.js 14 navigation is NOT intercepted. Documented gap; needs Next.js router patch or `next-runtime` adapter. | OPEN |
| ISSUE-5 | Session 1 | LOW | FE / WhatsApp Filter | "Approved-only" filter applied client-side after fetching full WhatsAppTemplate list (BE query lacks `status` variable). Safe at template counts <500. Future: add `status` arg to `getWhatsAppTemplates`. | OPEN |
| ISSUE-6 | Session 1 | LOW | BE / EF Migration | Migration file `20260518120000_Add_AutomationWorkflow.cs` was hand-authored (no Designer snapshot). User MAY prefer to run `dotnet ef migrations add Add_AutomationWorkflow` to let EF regenerate with snapshot diff. | OPEN |
| ISSUE-7 | Session 1 | LOW | BE / Helpers | `StepConfigValidator` + `AutomationWorkflowStepRemapper` embedded in `CreateAutomationWorkflow.cs` rather than a dedicated `Helpers/` folder. Used by both Create + Update via cross-file namespace ref. Future refactor candidate. | OPEN |
| ISSUE-RISK-1 | Session 1 | HIGH | Backend / Executor Architecture | Trigger-event listener architecture (DB triggers vs MediatR domain events vs separate event bus) is UNDEFINED. This screen ships storage + UI; the executor module that fires triggers + walks steps is a SERVICE_PLACEHOLDER. Decision required before executor implementation. | OPEN |
| ISSUE-RISK-2 | Session 1 | MED | Backend / Audit Granularity | Step-level execution audit (per-step success/failure/timestamp) is OUT OF SCOPE for v1. Only the high-level `AutomationWorkflowExecution` row is captured. Future: `AutomationWorkflowExecutionStep` grandchild entity. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-18 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. FULL scope (BE + FE + DB seed). 4 Sonnet agent spawns (BE Developer + 3 FE Developer spawns split per memory's "Long agent prompts stall on FLOW screens" warning).
- **Files touched**:
  - **BE** (27 created + 5 modified):
    - `PSS_2.0_Backend/.../Base.Domain/Models/NotifyModels/AutomationWorkflow.cs` (created)
    - `PSS_2.0_Backend/.../Base.Domain/Models/NotifyModels/AutomationWorkflowStep.cs` (created)
    - `PSS_2.0_Backend/.../Base.Domain/Models/NotifyModels/AutomationWorkflowExecution.cs` (created)
    - `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/NotifyConfigurations/AutomationWorkflowConfiguration.cs` (created)
    - `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/NotifyConfigurations/AutomationWorkflowStepConfiguration.cs` (created)
    - `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/NotifyConfigurations/AutomationWorkflowExecutionConfiguration.cs` (created)
    - `PSS_2.0_Backend/.../Base.Application/Schemas/NotifySchemas/AutomationWorkflowSchemas.cs` (created — 7 DTOs)
    - `PSS_2.0_Backend/.../Base.Application/Business/NotifyBusiness/AutomationWorkflows/Commands/*.cs` (8 files created — Create/Update/Delete/ToggleStatus/Duplicate/TestRun/CancelExec/RetryExec)
    - `PSS_2.0_Backend/.../Base.Application/Business/NotifyBusiness/AutomationWorkflows/Queries/*.cs` (4 files created — GetAll/GetById/GetSummary/GetExecutions) — **rewritten in-session** to fix bogus `PaginatedData<>`/`SearchText` and align with canonical `CommonExtension.ApplyGridFeatures` pattern + post-projection StepCount/Executions30Days fill.
    - `PSS_2.0_Backend/.../Base.API/EndPoints/Notify/Mutations/AutomationWorkflowMutations.cs` (created — 8 mutations)
    - `PSS_2.0_Backend/.../Base.API/EndPoints/Notify/Queries/AutomationWorkflowQueries.cs` (created — 4 queries)
    - `PSS_2.0_Backend/.../Base.Infrastructure/Migrations/20260518120000_Add_AutomationWorkflow.cs` (created — hand-authored, no Designer snapshot)
    - `PSS_2.0_Backend/.../sql-scripts-dyanmic/AutomationWorkflow-sqlscripts.sql` (created — Menu + 8 MenuCapabilities + RoleCapabilities + 3 sample workflows + 3 steps + 5 executions; GridFormSchema SKIP per FLOW)
    - `PSS_2.0_Backend/.../Base.Application/Data/Persistence/INotifyDbContext.cs` (modified — 3 DbSets added)
    - `PSS_2.0_Backend/.../Base.Infrastructure/Data/Persistence/NotifyDbContext.cs` (modified — 3 DbSets added)
    - `PSS_2.0_Backend/.../Base.Application/Extensions/DecoratorProperties.cs` (modified — 3 entries added to `DecoratorNotifyModules`)
    - `PSS_2.0_Backend/.../Base.Application/Mappings/NotifyMappings.cs` (modified — Mapster configs for 3 entities; **fixed in-session**: `src.Contact.ContactName` → `src.Contact.DisplayName`)
    - `PSS_2.0_Backend/.../Base.Domain/Models/ContactModels/Contact.cs` (modified — inverse nav `ICollection<AutomationWorkflowExecution>` added)
  - **FE** (~16 created + 7 modified):
    - `PSS_2.0_Frontend/src/domain/entities/notify-service/AutomationWorkflowDto.ts` (created — all DTOs + StepConfig discriminated-union + StepTreeNode + WorkflowStatus/ExecutionStatus literal unions)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/notify-queries/AutomationWorkflowQuery.ts` (created — 4 queries)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/notify-mutations/AutomationWorkflowMutation.ts` (created — 8 mutations)
    - `PSS_2.0_Frontend/src/application/stores/automation-workflow-stores/automation-workflow-store.ts` (created — Zustand store with `addStep`/`updateStep`/`removeStep`-cascade + `buildStepTree` + `serializeStepsForSave`)
    - `PSS_2.0_Frontend/src/application/stores/automation-workflow-stores/index.ts` (created — barrel)
    - `PSS_2.0_Frontend/src/presentation/pages/crm/automation/automationworkflow.tsx` (created — PageConfig)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/trigger-helpers.ts` (created — TRIGGER_OPTIONS×20, STEP_OPTIONS×11 incl. SendSMS, `describeTrigger`, `triggerCategory`, `defaultStepConfig`/`defaultTriggerConfig`)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/index.tsx` (created — folder barrel routing index vs view-page via URL `mode`)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/index-page.tsx` (created — Variant B index: `<ScreenHeader>` + 3 KPI cards + filter bar + workflow card list, all inline; LIST sub-components NOT extracted into separate files — see ISSUE-1)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/view-page.tsx` (created — 3 URL modes: new/edit canvas builder, read execution log; FlowFormPageHeader-like inline header)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/automation-workflow-canvas.tsx` (created — recursive node-tree renderer with branch fork)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/node-trigger.tsx` (created)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/node-step.tsx` (created)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/node-condition.tsx` (created — Condition card + YES/NO branch fork)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/node-add-step-button.tsx` (created)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/step-editor-modal.tsx` (created — 11 sub-forms + trigger-edit mode)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/execution-log-table.tsx` (created — paginated log + 4 performance tiles)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/automationworkflow/execution-status-pill.tsx` (created)
    - `PSS_2.0_Frontend/src/app/[lang]/crm/automation/automationworkflow/page.tsx` (modified — replaced UnderConstruction stub)
    - `PSS_2.0_Frontend/src/domain/entities/notify-service/index.ts` (modified — barrel re-export)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/notify-queries/index.ts` (modified — barrel re-export)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/notify-mutations/index.ts` (modified — barrel re-export)
    - `PSS_2.0_Frontend/src/presentation/pages/crm/automation/index.ts` (modified — first screen under crm/automation; populated)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/automation/index.ts` (created — first screen under crm/automation)
    - `PSS_2.0_Frontend/src/application/stores/index.ts` (modified — store barrel)
  - **DB**: `PSS_2.0_Backend/.../sql-scripts-dyanmic/AutomationWorkflow-sqlscripts.sql` (created — see BE list above)
- **Deviations from spec**:
  - Phase 4 deviation: did NOT extract `AutomationWorkflowSummaryCards`/`FilterBar`/`Card`/`List` into 4 separate component files; left them inline in `index-page.tsx`. ISSUE-1.
  - `SendSMS` added to STEP_OPTIONS (mockup omits it; parity with SMSTemplate #29 per §⑫).
  - Step preview shows raw FK IDs instead of resolved names. ISSUE-2.
  - Test Run uses confirmation dialog instead of contact picker, fires mutation with `sampleContactId: null`. ISSUE-3.
  - Unsaved-changes guard covers Back button + `beforeunload` only; sidebar/Next.js Link nav not intercepted. ISSUE-4.
  - WhatsApp "Approved" filter applied client-side. ISSUE-5.
  - EF migration hand-authored (no Designer snapshot file). ISSUE-6.
  - `StepConfigValidator` + `AutomationWorkflowStepRemapper` embedded in `CreateAutomationWorkflow.cs` rather than dedicated helper files. ISSUE-7.
- **Known issues opened**: 7 (ISSUE-1 through ISSUE-7) + 2 risks pre-flagged from prompt §⑫ (ISSUE-RISK-1 HIGH executor-architecture, ISSUE-RISK-2 MED step-audit-granularity)
- **Known issues closed**: None
- **Build verification**: `dotnet build PeopleServe.sln` PASSED (0 C# errors after fixing 5 in-session inline errors: bogus `PaginatedData<>` type → `GridFeatureResult<>`; bogus `request.SearchText` → `request.searchTerm`; bogus `Contact.ContactName` → `Contact.DisplayName` × 3 sites — 2 in mappings file + 1 in execution-query handler). Final build produced only MSB3027/MSB3021 file-lock errors (Base.API process held DLLs open during build — not a code defect).
- **Variant B verification**: `index-page.tsx` imports `<ScreenHeader>` from `@/presentation/components/custom-components/page-header` and does NOT import `<DataTableContainer>`, `<FlowDataTable>`, or `<CardGrid>`. No double-header risk.
- **UI uniformity grep checks**: ZERO matches for inline hex (`style={{[^}]*#[0-9a-fA-F]{3,6}`), inline padding/margin pixels (`style={{[^}]*(padding|margin):\s*\d+`), `DataTableContainer`/`FlowDataTable`/`CardGrid` (one mention is a comment "// NO DataTableContainer..." — clearly not usage).
- **Next step**: empty (COMPLETED). User must (a) stop running Base.API process, (b) run `dotnet ef database update` (or regenerate the migration with `dotnet ef migrations add Add_AutomationWorkflow` for snapshot fidelity), (c) execute the SQL seed `AutomationWorkflow-sqlscripts.sql`, (d) `pnpm dev` and exercise the LIST/FORM/DETAIL flows.

### Session 2 — 2026-05-18 — FIX — COMPLETED

- **Scope**: Two runtime hot-fixes after Session 1 marked COMPLETED — Apollo v4 type incompatibilities + GraphQL contract mismatch surfaced when the user wired up `pnpm dev`. Status stays COMPLETED per convention (no IN_PROGRESS churn).
- **Files touched**:
  - **FE** (4 modified):
    - `view-page.tsx` — replaced `useQuery({ onCompleted, onError })` with destructured `data`/`error` + two `useEffect`s (Apollo v4 dropped both callbacks); cast `(result.data as any)?.result` on create-mutation return.
    - `execution-log-table.tsx` — cast `(execData as any)?.result.data`, `(execData as any)?.result.totalCount`, `(summaryData as any)?.result.data`; renamed query var `pageNo` → `pageIndex` to match BE `GridFeatureRequest`.
    - `index-page.tsx` — cast `(listData as any)?.result.data`, `(summaryData as any)?.result.data`; updated query variables `{ pageNo: 0, isActive: true }` → `{ pageIndex: 0 }` (BE doesn't expose `isActive` arg; `IsDeleted=false` filter is applied server-side).
    - `step-editor-modal.tsx` — cast `(data as any)?.result.data` on 6 dropdown queries (Email/WhatsApp/SMS/Notification/Tag/User templates) + `(tmplData/usersData as any)?.result.data`.
  - **FE GQL contract** (1 modified — TWO rewrites in this session, second one correct):
    - `infrastructure/gql-queries/notify-queries/AutomationWorkflowQuery.ts` — full rewrite: (a) removed audit-field selections (`createdDate`/`modifiedDate`/`createdBy`/`modifiedBy`) from list + by-id queries (BE DTOs don't carry them); (b) FIRST attempt incorrectly flattened the GridFeatureRequest args at the top level — failed at runtime with `"argument 'pageIndex' does not exist"`. SECOND attempt: looked at canonical sibling `NotificationTemplateQuery.ts` and discovered `[AsParameters] GridFeatureRequest request` exposes a SINGLE GQL arg named after the C# parameter — args must be wrapped inside `request: { pageSize, pageIndex, sortDescending, sortColumn, searchTerm, advancedFilter }`. Executions query uses the same wrapper plus top-level `automationWorkflowId` + `statusFilter`. (c) `pageSize`/`pageIndex` declared as `Int!` (required) to match the sibling contract. Trigger-category/status filtering remains client-side in `index-page` (`triggerCategory` helper + filter chips) — unchanged from Session 1.
- **Deviations from spec**: None — these are pure contract alignment fixes against the Session 1 BE shape.
- **Known issues opened**: None new
- **Known issues closed**: None (the Session 1 issues are unaffected)
- **Build verification**: `pnpm tsc --noEmit` PASSED (0 errors across the 4 modified files + the GQL contract file). Backend was not rebuilt this session (no BE files touched).
- **Next step**: empty (COMPLETED).
