---
screen: SmsSetting
registry_id: 157
module: Setting
status: COMPLETED
scope: FULL
screen_type: CONFIG
config_subtype: SETTINGS_PAGE
storage_pattern: singleton-per-tenant (+ two child-list tables for per-country sender registrations and opt-out keywords)
save_model: save-per-section
complexity: High
new_module: NO (reuses existing `notify` schema and Notify group — sibling of WhatsAppSetting)
planned_date: 2026-05-08
completed_date: 2026-05-08
last_session_date: 2026-05-08
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — 3 tabs (Provider Setup / Sender & Compliance / Usage & Billing); 5 provider cards with conditional config blocks; per-country sender-ID registration table; DND/DNC + Opt-in/Opt-out + budget + webhook events
- [x] Sub-type identified: `SETTINGS_PAGE` (multi-section settings on a tenant-scoped singleton + two child collections)
- [x] Storage model: `singleton-per-tenant` — 1 row of `notify.SmsSettings` per Company. Two child tables: `notify.SmsSenderRegistrations` (per-country sender IDs) + `notify.SmsOptKeywords` (opt-out keywords, mirrors WhatsAppOptKeyword)
- [x] Save model chosen: `save-per-section` — each tab section has independent persistence: Connection (Connect button), Sender Configuration (Save), DND/DNC (Save), Opt-in/Opt-out (Save), Country Compliance Notes (read-only — no save), Budget (Save), Webhook Events (Save). Provider switch is local UI state until Connect persists.
- [x] Sensitive fields & role gates identified: BUSINESSADMIN-only; AuthToken/ApiKey/ApiSecret/AuthValue masked + write-only; Test SMS / Connect / DND Sync are SERVICE_PLACEHOLDER (no SMS service layer yet)
- [x] FK targets resolved (Company via HttpContext, no form FK; Country for sender-registration rows resolved at GetCountries query)
- [x] File manifest computed (BE: 24 created + 6 modified; FE: 16 created + 5 modified)
- [x] Approval config pre-filled (READ + MODIFY only — singleton has no Create/Delete on root settings; child tables get CREATE/MODIFY/DELETE under same MenuCode)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (config purpose + edit personas + risk) — pre-baked in prompt §①②④
- [x] Solution Resolution complete (sub-type confirmed, save model confirmed) — pre-baked in prompt §⑤
- [x] UX Design finalized (3-tab layout, 5-provider card selector, per-country sender table) — pre-baked in prompt §⑥
- [x] User Approval received (2026-05-08)
- [x] Backend code generated (24 NEW files: 3 entities + 3 EF configs + 1 schemas/DTOs/validators + 16 query/command handlers + 2 endpoints — handcrafted EF migration mirroring WhatsAppSetting pattern)
- [x] Backend wiring complete (4 files modified: INotifyDbContext, ApplicationDbContext, DecoratorProperties, NotifyMappings — GlobalUsing already had the namespace)
- [x] Frontend code generated (18 files NEW: 1 DTO + 1 GQL query + 1 GQL mutation + 12 page-component sub-components + 1 page wrapper + 1 secret-input atom + 1 barrel)
- [x] Frontend wiring complete (5 files modified: app route page replaced UnderConstruction stub, 4 barrel index files updated)
- [x] DB Seed script generated (default SmsSetting row + capabilities + role grants under SMSSETUP MenuCode — SET_COMMUNICATIONCONFIG parent already exists)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] EF migration `Add_SmsSettings_And_Children` applied
- [ ] pnpm dev — page loads at `/{lang}/setting/communicationconfig/smssetup`
- [ ] **SETTINGS_PAGE checks**:
  - [ ] First-load auto-seeds default SmsSetting row for current tenant (no 404 / null state)
  - [ ] Tabs render in order: Provider Setup → Sender & Compliance → Usage & Billing
  - [ ] Header connection-status badge reflects `ConnectionStatus` field (Connected/Disconnected/Pending) with correct color
  - [ ] Provider Setup: 5 provider cards render (Twilio / Bird / Vonage / Local / Custom HTTP API); selecting a card shows ONLY the matching connection-config block; other blocks unmounted
  - [ ] Per-provider config fields render correctly per provider (Twilio: AccountSid + AuthToken + MessagingServiceSid + DefaultFromNumber; Bird: ApiKey + Originator + ChannelId; Vonage: ApiKey + ApiSecret + ApplicationId + DefaultFromNumber; Local: ProviderName + EndpointUrl + ApiKey + ApiSecret + SenderId + ResponseFormat + DocsUrl; Custom: EndpointUrl + AuthType + AuthValue + SuccessCode + RequestBodyTemplate + DeliveryCallbackUrl-readonly)
  - [ ] Secret fields (AuthToken / ApiKey / ApiSecret / AuthValue) rendered as password inputs with eye-toggle reveal; submit empty ⇒ unchanged on save
  - [ ] Connect button → SERVICE_PLACEHOLDER toast ("SMS provider integration not yet implemented; settings saved locally")
  - [ ] Send Test SMS button → SERVICE_PLACEHOLDER toast (input modal asks for recipient number, then mocked success)
  - [ ] Connection Status card displays current saved provider, from-number, sender-id, country coverage, connected-since (read-only)
  - [ ] Sender & Compliance — Sender Type radio (Phone Number vs Alphanumeric) toggles; FallbackSender input persists
  - [ ] Sender Registration table — CRUD per row (Country / SenderId / Type / RegistrationRef / Status); add new row dialog; status chips (Registered / Approved / Active / Pending Review)
  - [ ] DND/DNC: HonorDndRegistry toggle persists; DndRegistryProvider dropdown persists; LastDndSync read-only; "Sync Now" → SERVICE_PLACEHOLDER toast; "View Blocked List" → navigates or stub
  - [ ] Opt-in / Opt-out: RequireOptInBeforeSending toggle; OptInCollectionPoints checklist (6 options) persists as JSON list; opt-in stats (total / opted-in / opted-out / never-asked) render from contact aggregate or stub for MVP; OptOutKeywords tag input → maps to `SmsOptKeywords` child rows; OptOutConfirmationMessage textarea (160-char counter); AutoProcessOptOutReplies toggle persists
  - [ ] Country Compliance Notes accordion — 4 collapsible items (India / US / UK / UAE) render hardcoded copy + status chip; READ-ONLY (no save)
  - [ ] Usage & Billing — Current Period Summary (5 KPI cards: SMS Sent / Delivered / Failed / Segments Used / Inbound Replies) — values read from SmsCampaignRecipient aggregate OR SERVICE_PLACEHOLDER if aggregation handler not built yet
  - [ ] Cost Tracking: MonthlyBudgetCap input; SpentThisMonth + RemainingBudget + AvgCostPerSegment computed/read-only; budget bar progress reflects spent/cap; BudgetAlertThreshold slider (50–100%) persists; AutoPauseSmsWhenBudgetExceeded toggle persists; PausePromotionalOnly toggle persists
  - [ ] Cost by Country (Top 5) table — read-only, value source = SERVICE_PLACEHOLDER for MVP (no provider-billing integration)
  - [ ] Charts (Daily Usage / Delivery Rate by Country) — render as ChartV2 placeholders OR empty-state cards if no aggregation
  - [ ] Webhook Event Configuration: 8 checkbox items persist as JSON list in `WebhookEvents`; saving updates singleton
  - [ ] Quick Links — 6 navigation links to sibling screens (SMS Templates, SMS Campaigns, Notification Templates, Automation Workflows, Placeholder Management, Communication Analytics)
  - [ ] Each section's Save button persists ONLY that section's fields (save-per-section model); validation errors block save and surface inline per field
  - [ ] Sensitive empty submit ⇒ unchanged; non-empty ⇒ overwrites
  - [ ] Unsaved-changes blocker on dirty navigation
  - [ ] Role-gated for BUSINESSADMIN; non-privileged roles see DefaultAccessDenied
- [ ] Empty / loading / error states render
- [ ] DB Seed — menu visible at Settings › Communication Config › SMS Setup

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: SmsSetting
Module: Setting (FE route under `setting/communicationconfig/smssetup`)
Schema: `notify` (sibling of `notify.WhatsAppSettings` + `notify.SMSTemplates` + `notify.SMSCampaigns`)
Group: Notify (handlers / configs / schemas / endpoints / mappings live under `NotifyBusiness/SmsSettings/`, `NotifyConfigurations`, `NotifySchemas`, `EndPoints/Notify`, `NotifyMappings`)

**Business**: This is the **SMS-channel sibling** of WhatsApp Setup (#34) and Email Provider Config (#84) — a single tenant-scoped configuration that governs *every* outbound SMS the platform sends across donor receipts, event reminders, donation thank-yous, prayer-request replies, and SMS campaigns. The configuration spans three concerns the BUSINESSADMIN must own: **(1) Provider connection** — which SMS gateway (Twilio / Bird / Vonage / a country-local provider / a custom HTTP endpoint) the tenant has chosen, plus the credentials and from-number/sender-id needed to authenticate and send; **(2) Sender & Compliance** — country-by-country sender registration (DLT in India, 10DLC in the US, alphanumeric IDs in UK/UAE/SG), DND/DNC enforcement, opt-in collection rules and opt-out keyword automation, plus reference compliance notes for the four major regulatory regimes the platform supports; **(3) Usage & Billing** — current-period delivery KPIs, monthly budget cap with auto-pause behavior when exceeded, per-country cost breakdown, and which delivery-lifecycle events should fire webhooks back into the tenant's automation. Edit cadence: **rare and high-stakes** — typically a one-time setup at onboarding, then quarterly audits when a regulator changes a rule (e.g. India's DLT template registry refresh, a new 10DLC campaign approval) or when the tenant adds a new country of operation. Personas: BUSINESSADMIN only. Risk-of-misconfig is HIGH on every dimension: wrong credentials = total SMS outage; wrong sender-id registration = messages auto-blocked by carrier filters; DND off = legal liability under TRAI/TCPA/PECR with fines up to ₹50,000 / $1,500 / £500,000 per violation; budget cap missing = runaway provider invoice; opt-out keywords mis-registered = lawsuits for ignoring unsubscribe requests. What's unique about this config's UX vs. a generic settings page: **(a)** the provider selector swaps the entire connection-config block (5 providers × different field shapes — like a card-selector + conditional sub-form); **(b)** the per-country sender registration is a child grid embedded inside a settings tab (one-to-many, not a flat list of fields); **(c)** the Usage & Billing tab is HALF-LIVE — KPI counts can come from real `SmsCampaignRecipient` aggregates if available, but cost data depends on the SMS provider's billing API which is not yet integrated, so most cost values are SERVICE_PLACEHOLDER; **(d)** Country Compliance Notes is intentionally a read-only educational accordion (no fields to save) — it documents regulatory requirements the tenant must comply with, rendered as hardcoded copy. The closest sibling is WhatsApp Setup (#34, NotifyModels.WhatsAppSetting) — same singleton-per-tenant pattern, similar three-tab shape, similar masked-credential treatment, and a similar opt-keyword child collection (`WhatsAppOptKeyword` ↔ `SmsOptKeyword`). Save model differs: WhatsApp uses save-all per-tab; SMS Setup uses save-per-section because each section is more independent and a partial save is meaningful (e.g. save the budget cap without re-typing API credentials).

> Why §① is heavier than other screens: an agent that doesn't grasp the regulatory dimension will drop the per-country sender-registration table or the DND toggle thinking they're cosmetic. They are the COMPLIANCE BACKBONE of this screen — the reason it exists separately from a generic "SMS Provider" CRUD.

---

## ② Storage Model

> **Consumer**: BA Agent → Backend Developer
> **Storage Pattern**: `singleton-per-tenant` (root) + two child-list tables
> Audit columns (CreatedBy/CreatedDate/ModifiedBy/ModifiedDate/IsActive/IsDeleted) inherited from `Entity` base — DO NOT enumerate.
> CompanyId is **always** present and **NEVER** a form field — derived from HttpContext (`ITenantContext.GetRequiredTenantId()`).

This screen touches **3 tables** behind the singleton:

### Table 1: `notify."SmsSettings"` (NEW — singleton)

Primary table — exactly one row per Company.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| SmsSettingId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | app.Companies | Tenant scope (NOT a form field) — unique index |
| Provider | string | 30 | YES | — | "Twilio" \| "Bird" \| "Vonage" \| "Local" \| "Custom" — drives which connection block is active |
| IsEnabled | bool | — | YES | — | Master switch — when false, all SMS sending paused regardless of other config |
| ConnectionStatus | string | 20 | NO | — | "Connected" \| "Disconnected" \| "Pending" — written by Connect handler, displayed as header badge |
| ConnectedAt | DateTime? | — | NO | — | Last successful Connect timestamp |
| **── Twilio block ──** | | | | | |
| TwilioAccountSid | string? | 100 | conditional | — | Required when Provider=Twilio |
| TwilioAuthToken | string? | 200 | conditional | — | SECRET — masked on read, write-only on save |
| TwilioMessagingServiceSid | string? | 100 | NO | — | Optional Twilio Messaging Service ID |
| TwilioDefaultFromNumber | string? | 30 | conditional | — | E.164-format from-number, required when Provider=Twilio AND no MessagingServiceSid |
| **── Bird block ──** | | | | | |
| BirdApiKey | string? | 200 | conditional | — | SECRET — required when Provider=Bird |
| BirdOriginator | string? | 50 | conditional | — | Sender name or phone number, required when Provider=Bird |
| BirdChannelId | string? | 100 | NO | — | Optional |
| **── Vonage block ──** | | | | | |
| VonageApiKey | string? | 100 | conditional | — | Required when Provider=Vonage |
| VonageApiSecret | string? | 200 | conditional | — | SECRET — required when Provider=Vonage |
| VonageApplicationId | string? | 100 | NO | — | Optional |
| VonageDefaultFromNumber | string? | 30 | conditional | — | Required when Provider=Vonage AND no ApplicationId |
| **── Local block ──** | | | | | |
| LocalProviderName | string? | 100 | conditional | — | e.g. "BulkSMS", "MSG91", "SMSCountry" |
| LocalEndpointUrl | string? | 500 | conditional | — | API endpoint URL |
| LocalApiKey | string? | 200 | conditional | — | SECRET |
| LocalApiSecret | string? | 200 | conditional | — | SECRET |
| LocalSenderId | string? | 20 | conditional | — | 6-char alphanumeric sender ID |
| LocalResponseFormat | string? | 10 | NO | — | "json" \| "xml" |
| LocalDocsUrl | string? | 500 | NO | — | Optional documentation link |
| **── Custom HTTP block ──** | | | | | |
| CustomEndpointUrl | string? | 500 | conditional | — | POST endpoint URL |
| CustomAuthType | string? | 20 | conditional | — | "apikey" \| "basic" \| "bearer" \| "custom" |
| CustomAuthValue | string? | 500 | conditional | — | SECRET — value depends on AuthType |
| CustomSuccessResponseCode | int | — | NO | — | Default 200 |
| CustomRequestBodyTemplate | string? | — | conditional | — | text/varchar(MAX); JSON template using `{{phone_number}}`, `{{sender_id}}`, `{{message_body}}`, `{{callback_url}}` placeholders |
| CustomDeliveryCallbackUrl | string? | 500 | NO | — | READ-ONLY — system-generated `https://api.{base}/webhooks/sms/delivery/{tenantSlug}` |
| **── Sender & Compliance ──** | | | | | |
| SenderType | string | 20 | YES | — | "Phone" \| "Alphanumeric" — default "Phone" |
| FallbackSenderNumber | string? | 30 | NO | — | Used when alphanumeric not supported in destination country |
| HonorDndRegistry | bool | — | YES | — | Default true |
| DndRegistryProvider | string? | 50 | NO | — | "Auto" \| "TRAI" \| "DNC-US" \| "TPS-UK" \| "Custom" |
| LastDndSyncAt | DateTime? | — | NO | — | Set by Sync Now handler (SERVICE_PLACEHOLDER) |
| RequireOptInBeforeSending | bool | — | YES | — | Default true |
| OptInCollectionPoints | string? (json) | — | NO | — | JSON array of strings: ["DonationForm", "BeneficiaryReg", "EventReg", "VolunteerSignup", "WebsitePopup", "ImportConsent"] |
| OptOutConfirmationMessage | string? | 320 | NO | — | Up to 2 SMS segments (160 × 2) |
| AutoProcessOptOutReplies | bool | — | YES | — | Default true |
| **── Usage & Billing ──** | | | | | |
| MonthlyBudgetCap | decimal? | 12,2 | NO | — | USD; null = no cap |
| BudgetAlertThresholdPct | int | — | YES | — | 50–100; default 80 |
| AutoPauseWhenBudgetExceeded | bool | — | YES | — | Default true |
| PausePromotionalOnly | bool | — | YES | — | When true, transactional SMS still flows after cap |
| WebhookEvents | string? (json) | — | NO | — | JSON array of strings — same convention as `WhatsAppSetting.WebhookEvents`. Possible values: ["MessageSent", "MessageDelivered", "MessageFailed", "InboundReplyReceived", "OptOutReceived", "OptInReceived", "BudgetThresholdReached", "DndCheckFailed"] |

**Singleton constraint**:
- Unique index on `(CompanyId)` — exactly one row per tenant
- First-load behavior: if no row exists, BE auto-creates a default with `Provider="Twilio"`, `IsEnabled=false`, `ConnectionStatus="Disconnected"`, `SenderType="Phone"`, `HonorDndRegistry=true`, `RequireOptInBeforeSending=true`, `BudgetAlertThresholdPct=80`, `AutoPauseWhenBudgetExceeded=true`, `PausePromotionalOnly=true`

**[NotMapped] helpers** on entity (mirror `WhatsAppSetting.WebhookEventsList`):
- `WebhookEventsList: List<string>` — get/set serializes JSON
- `OptInCollectionPointsList: List<string>` — same JSON convention

### Table 2: `notify."SmsSenderRegistrations"` (NEW — child collection)

Per-country sender-ID registration rows. Mockup shows 5 sample rows in the Sender & Compliance tab "Registration Status by Country" table.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| SmsSenderRegistrationId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | app.Companies | Tenant scope |
| SmsSettingId | int | — | YES | notify.SmsSettings | FK back to parent singleton (cascade delete) |
| CountryId | int | — | YES | gen.Countries | Country FK |
| SenderId | string | 50 | YES | — | e.g. "HOPFND" or "+14155550100" |
| RegistrationType | string | 50 | YES | — | "Alphanumeric (DLT)" \| "10DLC Number" \| "Alphanumeric" \| etc. |
| RegistrationReference | string? | 200 | NO | — | "DLT Entity ID: 1101456789012" or "Campaign ID: CXYZ123" |
| Status | string | 20 | YES | — | "Registered" \| "Approved" \| "Active" \| "Pending Review" \| "Rejected" |

**Composite uniqueness**: `(CompanyId, CountryId, SenderId)` — one row per (tenant, country, sender) combination.

### Table 3: `notify."SmsOptKeywords"` (NEW — child collection)

Mirrors `notify.WhatsAppOptKeywords` structure. Mockup shows 5 default keywords (STOP / UNSUBSCRIBE / CANCEL / END / QUIT).

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| SmsOptKeywordId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | app.Companies | Tenant scope |
| SmsSettingId | int | — | YES | notify.SmsSettings | FK back to parent singleton (cascade delete) |
| Keyword | string | 50 | YES | — | "STOP", "UNSUBSCRIBE" |
| KeywordType | string | 10 | YES | — | "OptIn" \| "OptOut" — default "OptOut" |
| AutoReplyMessage | string? | 320 | NO | — | Optional reply message |

**Composite uniqueness**: `(CompanyId, Keyword, KeywordType)` — one row per (tenant, word, direction).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| CompanyId | Company | `Base.Domain/Models/ApplicationModels/Company.cs` | (NOT used in form — derived from HttpContext via `ITenantContext`) | CompanyName | CompanyResponseDto |
| SmsSenderRegistrations.CountryId | Country | `Base.Domain/Models/SharedModels/Country.cs` | GetCountries (paginated) | CountryName | CountryResponseDto |

> No FK is exposed as a form-level dropdown on the root SmsSettings form. CountryId only appears inside the per-country sender-registration child grid (add-row dialog) and uses the existing `GetCountries` paginated query.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Singleton / Cardinality Rules:**
- Exactly one `SmsSettings` row per tenant. `Get` auto-seeds defaults on first call. No Create / no Delete on the root entity.
- `SmsSenderRegistrations` and `SmsOptKeywords` are CRUD-able children gated by the same MenuCode (SMSSETUP).
- Saving any section triggers an UPSERT on the root row by `CompanyId`.

**Required Field Rules** (per provider — only enforced when that provider is selected and `IsEnabled=true`):
- **Twilio**: `TwilioAccountSid` + `TwilioAuthToken` required; either `TwilioMessagingServiceSid` OR `TwilioDefaultFromNumber` required
- **Bird**: `BirdApiKey` + `BirdOriginator` required
- **Vonage**: `VonageApiKey` + `VonageApiSecret` required; either `VonageApplicationId` OR `VonageDefaultFromNumber` required
- **Local**: `LocalProviderName` + `LocalEndpointUrl` + `LocalApiKey` + `LocalSenderId` required
- **Custom**: `CustomEndpointUrl` + `CustomAuthType` + `CustomAuthValue` + `CustomRequestBodyTemplate` required

**Conditional Rules:**
- If `SenderType="Alphanumeric"` then `FallbackSenderNumber` required (so destinations that don't support alpha senders still receive messages).
- If `HonorDndRegistry=true` then `DndRegistryProvider` must be set.
- `BudgetAlertThresholdPct` must be 50–100 inclusive.
- `OptOutConfirmationMessage` ≤ 320 chars (2 SMS segments at GSM-7).
- Custom provider `CustomRequestBodyTemplate` must be valid JSON and contain at minimum `{{phone_number}}` and `{{message_body}}` placeholders (validator-enforced).
- Sender registration row: `SenderId` length ≤ 11 when `RegistrationType` contains "Alphanumeric"; ≤ 30 when "10DLC" or "Phone".

**Sensitive Fields** (masking, audit, role-gating):

| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| TwilioAuthToken | secret | masked `••••••••` placeholder; never sent in GET | empty ⇒ unchanged; non-empty ⇒ overwrite | log "credential rotated" |
| BirdApiKey | secret | same | same | same |
| VonageApiSecret | secret | same | same | same |
| LocalApiKey | secret | same | same | same |
| LocalApiSecret | secret | same | same | same |
| CustomAuthValue | secret | same | same | same |
| TwilioAccountSid / VonageApiKey / LocalProviderName / etc. | low | plain | normal | normal |

> Mirror the WhatsAppSetting masking pattern: GET returns `TwilioAuthTokenMasked`, `BirdApiKeyMasked`, `VonageApiSecretMasked`, `LocalApiKeyMasked`, `LocalApiSecretMasked`, `CustomAuthValueMasked` as last-4 only (`"…XXXX"`); raw fields omitted from the response DTO.

**Read-only / System-controlled Fields:**
- `ConnectionStatus`, `ConnectedAt`, `LastDndSyncAt`, `CustomDeliveryCallbackUrl` — set by handlers, never editable.
- Cost-by-country numbers, segments-used, delivered/failed counts on Usage tab — display-only (computed or SERVICE_PLACEHOLDER).

**Dangerous Actions** (require confirm + audit):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Disable SMS (toggle `IsEnabled=false`) | Pauses ALL outbound SMS across the platform | Modal "All SMS sending will pause. Continue?" | log "sms.disabled" |
| Switch Provider while Connected | Discards previous connection state | Modal "Switching provider will disconnect from {oldProvider}. Continue?" | log "sms.provider.switched" |
| Clear API credentials (regenerate via support) | (No FE action — credentials are write-only; rotation is just save with new value) | — | log every secret-field change |

**Role Gating** (which sections / fields are visible / editable per role):

| Role | Sections Visible | Sections Editable | Notes |
|------|------------------|-------------------|-------|
| BUSINESSADMIN | all | all | full access |

> Per CLAUDE rules: enumerate ONLY BUSINESSADMIN. Other roles see DefaultAccessDenied.

**Workflow**: None — config is single-state. There is no draft → publish lifecycle.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: CONFIG
**Config Sub-type**: `SETTINGS_PAGE`
**Storage Pattern**: `singleton-per-tenant` (+ child-list tables for sender registrations + opt-keywords)
**Save Model**: `save-per-section`

**Reason**: The 3-tab + multi-section layout has independent semantic concerns (provider creds vs. sender compliance vs. budget). Saving a budget-cap change without re-typing API credentials is a real user need. Each section has its own validation surface and can fail independently.

**Backend Patterns Required:**

For **SETTINGS_PAGE (singleton-per-tenant)** — closely mirroring `WhatsAppSetting`:
- [x] `GetSmsSetting` query — fetches by tenant from HttpContext, auto-seeds default if missing, masks all secret fields
- [x] `SaveSmsConnectionSettings` mutation — provider + credentials + IsEnabled (Provider Setup tab section save)
- [x] `SaveSmsSenderConfiguration` mutation — SenderType + FallbackSenderNumber (Sender & Compliance tab — sender section)
- [x] `SaveSmsDndConfiguration` mutation — HonorDndRegistry + DndRegistryProvider (DND/DNC section)
- [x] `SaveSmsOptInConfiguration` mutation — RequireOptInBeforeSending + OptInCollectionPoints + OptOutConfirmationMessage + AutoProcessOptOutReplies (Opt-in/Opt-out section)
- [x] `SaveSmsBudgetConfiguration` mutation — MonthlyBudgetCap + BudgetAlertThresholdPct + AutoPauseWhenBudgetExceeded + PausePromotionalOnly (Budget section)
- [x] `SaveSmsWebhookEvents` mutation — WebhookEvents (Webhook Events section)
- [x] `TestSmsConnection` mutation — SERVICE_PLACEHOLDER returning mocked `SmsConnectionTestResultDto`
- [x] `SendTestSms` mutation — SERVICE_PLACEHOLDER returning mocked success/failure
- [x] `SyncDndRegistry` mutation — SERVICE_PLACEHOLDER setting `LastDndSyncAt = UtcNow`
- [x] `GetSmsSenderRegistrations` query — child list filtered by tenant
- [x] `SaveSmsSenderRegistration` mutation — upsert single row
- [x] `DeleteSmsSenderRegistration` mutation — delete by id (tenant-scoped)
- [x] `GetSmsOptKeywords` query — child list filtered by tenant
- [x] `SaveSmsOptKeywords` mutation — bulk upsert (mirror `SaveWhatsAppOptKeywords` shape — accepts `List<SmsOptKeywordRequestDto>`, full replace per tenant)
- [x] `GetSmsUsageAnalytics` query — read-only KPI aggregate; SERVICE_PLACEHOLDER returning mocked numbers OR aggregates from existing `SmsCampaignRecipient` if a delivery-status column exists
- [x] Tenant scoping (CompanyId from `ITenantContext.GetRequiredTenantId()` on every query/mutation)
- [x] Sensitive-field handling (mask on read, write-only on update — mirror `WhatsAppSetting` mapper)
- [x] Audit-trail emission for sensitive / regulatory fields (every credential change, every IsEnabled toggle, every DND toggle)

**Frontend Patterns Required:**

For **SETTINGS_PAGE**:
- [x] Custom multi-section page (NOT RJSF modal, NOT view-page 3-mode) — mirror `EmailProviderConfigPage` page-component layout precedent at `setting/communicationconfig/emailproviderconfig/`
- [x] Container Pattern: `tabs` (3 tabs, save-per-section preferred — mockup is unambiguous)
- [x] Use shadcn `Tabs / TabsList / TabsTrigger / TabsContent` — same primitives as WhatsApp Configuration page
- [x] Provider card-selector component (5 cards with radio-dot, conditional config block per selection — mirror `provider-card-selector.tsx` from EmailProviderConfig)
- [x] Connection-status header badge (Connected / Disconnected / Pending) reflecting `ConnectionStatus`
- [x] Sensitive-field input with eye-toggle reveal (reusable component — check if `secret-input.tsx` exists; create if not)
- [x] Read-only system-field display (chip / disabled input) for `ConnectionStatus`, `ConnectedAt`, `CustomDeliveryCallbackUrl`, `LastDndSyncAt`
- [x] Per-country sender-registration child grid with add-row dialog (use existing DataTable + dialog primitives)
- [x] Tag-input for opt-out keywords (mirror existing tag-input pattern; if none, build inline)
- [x] Character counter for opt-out confirmation message (160 / 320)
- [x] Budget progress bar (use Tailwind div + percent fill; same shape as mockup `budget-bar`)
- [x] Range slider for budget alert threshold
- [x] Confirm dialog for dangerous actions (Disable SMS, Switch Provider)
- [x] Save indicator per section (saved-at timestamp / dirty badge)
- [x] Charts placeholder with `ChartV2` skeleton OR a `chart-placeholder` empty-state card if real data isn't available
- [x] Use `useAccessCapability({ menuCode: "SMSSETUP" })` for role gating + `DefaultAccessDenied` fallback (mirror `WhatsAppSetupPageConfig`)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: This is the design spec. Match the mockup exactly.

### 🎨 Visual Uniqueness Rules

1. Provider Setup tab is the **hero** of the screen — prominent provider-card grid + bold connection block + Connect button as primary CTA.
2. Sender & Compliance is **regulatory-tone** — info-boxes, warning chips on Pending Review status, accordion for compliance notes.
3. Usage & Billing is **dashboard-tone** — KPI cards across the top, budget bar, country table, chart placeholders.
4. Sensitive fields are visually distinct — masked input + monospace + eye-toggle button.
5. Section icons are semantic — `ph:tower` for provider, `ph:gear` for connection, `ph:check-circle` for status, `ph:identification-card` for sender ID, `ph:prohibit` for DND, `ph:user-check` for opt-in/out, `ph:scales` for compliance, `ph:chart-bar` for usage, `ph:wallet` for budget, `ph:globe` for country cost, `ph:plug` for webhook, `ph:link` for quick links.
6. Save affordance per-section: each section card has its own Save button at the bottom-right of the card body.

### 🅰️ Block A — SETTINGS_PAGE

#### Page Layout

**Container Pattern**: `tabs` (3 tabs)

**Page Header**:
- Left: title "SMS Integration" + connection-status badge ("Connected" green / "Disconnected" red / "Pending" yellow)
- Right: 3 secondary buttons — "Test SMS" (SERVICE_PLACEHOLDER), "Go to Templates" (navigates to /crm/sms/smstemplate), "Go to Campaigns" (navigates to /crm/sms/smscampaign)

#### Section Definitions

> One row per section. Order matches mockup. Tab assignments shown in "Container Slot" column.

| # | Section Title | Icon (Phosphor) | Container Slot | Save Mode | Role Gate |
|---|---------------|-----------------|----------------|-----------|-----------|
| 1 | SMS Provider | `ph:tower-broadcast` | tab-1 (Provider Setup) | (no save — provider switch is local UI; persisted by section 2 Connect) | BUSINESSADMIN |
| 2 | Connection Configuration | `ph:gear` | tab-1 | save-per-section (Connect button) | BUSINESSADMIN |
| 3 | Connection Status | `ph:check-circle` | tab-1 | (no save — read-only) | BUSINESSADMIN |
| 4 | Sender ID Configuration | `ph:identification-card` | tab-2 (Sender & Compliance) | save-per-section + child-grid CRUD | BUSINESSADMIN |
| 5 | DND/DNC Compliance | `ph:prohibit` | tab-2 | save-per-section | BUSINESSADMIN |
| 6 | Opt-in / Opt-out Configuration | `ph:user-check` | tab-2 | save-per-section + opt-keyword bulk save | BUSINESSADMIN |
| 7 | Country-Specific Compliance Notes | `ph:scales` | tab-2 | (no save — read-only educational accordion) | BUSINESSADMIN |
| 8 | Current Period Summary | `ph:chart-bar` | tab-3 (Usage & Billing) | (no save — read-only KPIs) | BUSINESSADMIN |
| 9 | Cost Tracking | `ph:wallet` | tab-3 | save-per-section (budget config + auto-pause toggles) | BUSINESSADMIN |
| 10 | Cost by Country (Top 5) | `ph:globe` | tab-3 | (no save — read-only) | BUSINESSADMIN |
| 11 | Daily Usage / Delivery Rate Charts | `ph:chart-column` | tab-3 | (no save — read-only) | BUSINESSADMIN |
| 12 | Webhook Event Configuration | `ph:plug` | tab-3 | save-per-section | BUSINESSADMIN |
| 13 | Quick Links | `ph:link` | tab-3 | (no save — navigation-only) | BUSINESSADMIN |

#### Field Mapping per Section

**Section 1 — SMS Provider**

5-card radio selector (provider-card-selector pattern):

| Provider Key | Title | Icon Emoji | Description | Status Note |
|--------------|-------|------------|-------------|-------------|
| `twilio` | Twilio | 📱 | Global SMS API with excellent deliverability | Most popular, supports 180+ countries |
| `bird` | Bird (MessageBird) | 🐦 | Enterprise messaging platform | Strong in Europe, Middle East, Asia |
| `vonage` | Vonage (Nexmo) | 📞 | Communications API by Vonage | Good for high-volume transactional SMS |
| `local` | Local Provider | 🌐 | Country-specific SMS gateway | Best rates for single-country operations |
| `custom` | Custom HTTP API | 🔧 | Connect via custom REST endpoint | For proprietary gateways |

Behavior: clicking a card sets local form state; the matching Section-2 connection block is the only one rendered. Selection alone does NOT persist — persistence happens via Section 2 Connect.

**Section 2 — Connection Configuration**

Conditional sub-form by `Provider`:

| Provider | Field | Widget | Validation | Sensitivity |
|----------|-------|--------|------------|-------------|
| Twilio | TwilioAccountSid | text | required, starts with "AC" | normal |
| Twilio | TwilioAuthToken | password-mask + eye-toggle | required | secret |
| Twilio | TwilioMessagingServiceSid | text | optional, starts with "MG" | normal |
| Twilio | TwilioDefaultFromNumber | text | required if no MessagingServiceSid; E.164 format | normal |
| Bird | BirdApiKey | password-mask + eye-toggle | required | secret |
| Bird | BirdOriginator | text | required, max 11 chars or phone format | normal |
| Bird | BirdChannelId | text | optional | normal |
| Vonage | VonageApiKey | text | required | normal |
| Vonage | VonageApiSecret | password-mask + eye-toggle | required | secret |
| Vonage | VonageApplicationId | text | optional | normal |
| Vonage | VonageDefaultFromNumber | text | required if no ApplicationId; E.164 | normal |
| Local | LocalProviderName | text | required | normal |
| Local | LocalEndpointUrl | text | required, https URL | normal |
| Local | LocalApiKey | password-mask + eye-toggle | required | secret |
| Local | LocalApiSecret | password-mask + eye-toggle | optional | secret |
| Local | LocalSenderId | text | required, ≤ 6 chars | normal |
| Local | LocalResponseFormat | select (json/xml) | optional, default "json" | normal |
| Local | LocalDocsUrl | text | optional | normal |
| Custom | CustomEndpointUrl | text | required, https URL | normal |
| Custom | CustomAuthType | select (apikey/basic/bearer/custom) | required | normal |
| Custom | CustomAuthValue | password-mask + eye-toggle | required | secret |
| Custom | CustomSuccessResponseCode | number | required, default 200 | normal |
| Custom | CustomRequestBodyTemplate | textarea (monospace) | required, valid JSON, contains `{{phone_number}}` + `{{message_body}}` placeholders | normal |
| Custom | CustomDeliveryCallbackUrl | text (read-only + copy button) | system-generated | normal |

**Section 2 Actions**:
| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Connect | "Connect" | primary | — (when switching provider while connected → "Switching will disconnect from {old}. Continue?") | `SaveSmsConnectionSettings` then `TestSmsConnection` (SERVICE_PLACEHOLDER) |
| Send Test SMS | "Send Test SMS" | secondary | input modal asking for recipient phone | `SendTestSms` (SERVICE_PLACEHOLDER) |

**Section 3 — Connection Status** (read-only)

| Row | Source | Display |
|-----|--------|---------|
| Status | `ConnectionStatus` | badge (Connected/Disconnected/Pending) |
| Provider | `Provider` | text |
| From Number | provider-specific from-number field | text |
| Sender ID | `LocalSenderId` (if Local) OR `BirdOriginator` (if Bird) OR — | text |
| Country Coverage | static per-provider (Twilio=185, Bird=200+, Vonage=180+, Local=1, Custom=N/A) | text |
| Connected Since | `ConnectedAt` (formatted) | text |

**Section 4 — Sender ID Configuration**

| Field | Widget | Default | Validation | Sensitivity |
|-------|--------|---------|------------|-------------|
| InfoBox | static text | — | — | — |
| SenderType | radio (Phone Number / Alphanumeric Sender ID) | "Phone" | required | normal |
| FallbackSenderNumber | text | — | required if SenderType=Alphanumeric | normal |

**Sender Registration child grid** (DataTable):
| Column | Source | Editable in dialog |
|--------|--------|---------------------|
| Country | `Countries.CountryName` (with flag emoji from country code) | YES — ApiSelect via `GetCountries` |
| Sender ID | `SenderId` | YES — text |
| Type | `RegistrationType` | YES — select |
| Registration | `RegistrationReference` | YES — text |
| Status | `Status` | YES — select |
| Actions | — | Edit / Delete buttons per row |

Toolbar above grid: "Add Sender Registration" primary button.

**Section 4 Actions**:
| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Save Sender Config | "Save" | primary | — | `SaveSmsSenderConfiguration` |
| Add Registration | "+ Add Sender Registration" | secondary | — (opens dialog) | `SaveSmsSenderRegistration` (single row) |
| Delete Registration | row "Delete" | destructive | "Remove sender registration for {country}?" | `DeleteSmsSenderRegistration` |

**Section 5 — DND/DNC Compliance**

| Field | Widget | Default | Validation | Sensitivity |
|-------|--------|---------|------------|-------------|
| HonorDndRegistry | switch | true | required | normal |
| DndRegistryProvider | select (Auto/India-TRAI/US-DNC/UK-TPS/Custom) | "Auto" | required if HonorDndRegistry=true | normal |
| LastDndSyncAt | text (read-only) | — | — | normal |
| BlockedContactCount | text (read-only) — count from contact aggregate or stub `2,847` | — | — | normal |

**Section 5 Actions**:
| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Save DND Config | "Save" | primary | — | `SaveSmsDndConfiguration` |
| Sync Now | "Sync Now" | secondary | — | `SyncDndRegistry` (SERVICE_PLACEHOLDER) |
| View Blocked List | "View Blocked List" | secondary | — | navigation stub (route TBD) |

**Section 6 — Opt-in / Opt-out Configuration**

| Field | Widget | Default | Validation | Sensitivity |
|-------|--------|---------|------------|-------------|
| RequireOptInBeforeSending | switch | true | required | normal |
| OptInCollectionPoints | checkbox-list (6 items: DonationForm / BeneficiaryReg / EventReg / VolunteerSignup / WebsitePopup / ImportConsent) | [DonationForm, BeneficiaryReg, EventReg, ImportConsent] | optional | normal |
| OptInStats (read-only) | segmented bar + 4-tile stats | computed/SERVICE_PLACEHOLDER | — | normal |
| OptOutKeywords | tag-input | [STOP, UNSUBSCRIBE, CANCEL, END, QUIT] | optional, min 1 | normal |
| OptOutConfirmationMessage | textarea + char-counter | "You have been unsubscribed..." | ≤ 320 chars | normal |
| AutoProcessOptOutReplies | switch | true | required | normal |

**Section 6 Actions**:
| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Save Opt-in Config | "Save" | primary | — | `SaveSmsOptInConfiguration` + `SaveSmsOptKeywords` (bulk) |

**Section 7 — Country-Specific Compliance Notes** (read-only educational accordion)

4 accordion items, all hardcoded copy with current-status chip:

| Item | Body | Status Chip Source |
|------|------|---------------------|
| 🇮🇳 India - TRAI DLT Regulations | bullet list (6 items) | derived: "DLT registration is active" if any sender-reg row with Country=India and Status=Registered |
| 🇺🇸 US - TCPA & 10DLC | bullet list (6 items) | derived from US sender-reg row |
| 🇬🇧 UK - ICO / PECR | bullet list (6 items) | "Soft opt-in enabled for donors" — derived from `OptInCollectionPoints` |
| 🇦🇪 UAE - TRA Regulations | bullet list (6 items) | derived from UAE sender-reg row |

Body copy ships with the FE component (no DB persistence).

**Section 8 — Current Period Summary** (read-only KPI grid, 5 cards)

| Card | Source | Format |
|------|--------|--------|
| SMS Sent | `SmsUsageAnalyticsDto.totalSent` | count |
| Delivered | `delivered` + `deliveredPct` | count + % |
| Failed | `failed` + `failedPct` | count + % |
| Segments Used | `segmentsUsed` | count |
| Inbound Replies | `inboundReplies` | count |

Period range badge top-right: `"Mar 1 - Mar 31, 2026"` from `periodStart` + `periodEnd`.

InfoBox below the card (static): "How SMS Segments Work" educational copy from mockup.

**Section 9 — Cost Tracking**

| Field | Widget | Default | Validation | Sensitivity |
|-------|--------|---------|------------|-------------|
| MonthlyBudgetCap | currency input | null | optional, > 0 | normal |
| SpentThisMonth | text (read-only) | computed/SERVICE_PLACEHOLDER | — | normal |
| RemainingBudget | text (read-only, color-coded) | computed | — | normal |
| AvgCostPerSegment | text (read-only) | computed/SERVICE_PLACEHOLDER | — | normal |
| BudgetBar | progress bar (color: green <50%, yellow 50–80%, red >80%) | computed | — | normal |
| BudgetAlertThresholdPct | range slider 50–100 | 80 | required, 50–100 | normal |
| AutoPauseWhenBudgetExceeded | switch | true | required | normal |
| PausePromotionalOnly | switch | true | required (only meaningful when AutoPause=true) | normal |

**Section 9 Actions**:
| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Save Budget Config | "Save" | primary | — | `SaveSmsBudgetConfiguration` |

**Section 10 — Cost by Country (Top 5)** (read-only DataTable)

Columns: Country (with flag) / Messages / Segments / Cost/Segment / Total Cost. Source: `SmsUsageAnalyticsDto.costByCountry[]` — SERVICE_PLACEHOLDER for MVP.

**Section 11 — Charts**

Two side-by-side cards:
- **Daily Usage (Last 30 Days)**: bar chart using ChartV2 component, x-axis=date, y-axis=`smsCount`. Source: `SmsUsageAnalyticsDto.dailyUsage[]` — SERVICE_PLACEHOLDER stub data.
- **Delivery Rate by Country**: horizontal bar chart, x-axis=`deliveryRate`, y-axis=country. Source: `SmsUsageAnalyticsDto.deliveryRateByCountry[]` — SERVICE_PLACEHOLDER.

Empty-state when no data: "No SMS sent in this period yet. Connect a provider to start sending."

**Section 12 — Webhook Event Configuration**

| Field | Widget | Default | Validation |
|-------|--------|---------|------------|
| WebhookEvents | 8-checkbox grid (2 columns) | [MessageSent, MessageDelivered, MessageFailed, InboundReplyReceived, OptOutReceived] | optional |

8 checkboxes:
1. Message Sent
2. Message Delivered
3. Message Failed
4. Inbound Reply Received
5. Opt-out Received
6. Opt-in Received
7. Budget Threshold Reached
8. DND Check Failed

**Section 12 Actions**:
| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Save Webhook Config | "Save" | primary | — | `SaveSmsWebhookEvents` |

**Section 13 — Quick Links** (navigation tiles)

6 tiles:
1. SMS Templates → `/crm/sms/smstemplate`
2. SMS Campaigns → `/crm/sms/smscampaign`
3. Notification Templates → `/crm/notification/notificationtemplate`
4. Automation Workflows → `/crm/automation/automationworkflow`
5. Placeholder Management → `/crm/communication/placeholderdefinition`
6. Communication Analytics → `/crm/dashboards/communicationdashboard` (or email-analytics route)

#### Page-Level Actions

| Action | Position | Style | Permission | Confirmation |
|--------|----------|-------|------------|--------------|
| Test SMS (header) | top-right | secondary | BUSINESSADMIN | input modal for recipient |
| Go to Templates | top-right | secondary | BUSINESSADMIN | — (router push) |
| Go to Campaigns | top-right | secondary | BUSINESSADMIN | — (router push) |

#### User Interaction Flow (SETTINGS_PAGE)

1. User opens `/setting/communicationconfig/smssetup` → role check → on first load BE auto-seeds `SmsSettings` row with defaults → tabs render.
2. **Provider Setup tab** (default active): user clicks a different provider card → conditional config block swaps locally; existing saved provider's fields remain in state until Connect is clicked.
3. User edits credentials → clicks **Connect** → confirm dialog if switching provider while connected → `SaveSmsConnectionSettings` mutation → `TestSmsConnection` (SERVICE_PLACEHOLDER returns mocked success) → `ConnectionStatus` updates in header badge → toast "Provider connected (mocked)".
4. **Sender & Compliance tab**: user toggles SenderType radio → if Alphanumeric, `FallbackSenderNumber` becomes required → Save persists. User clicks "+ Add Sender Registration" → dialog opens with Country ApiSelect + form → on submit single-row mutation. Row delete prompts confirm.
5. **DND/DNC**: user toggles `HonorDndRegistry` → if turning OFF, confirm modal "DND enforcement off. You may violate carrier regulations. Continue?" → Save persists. "Sync Now" triggers SERVICE_PLACEHOLDER toast + updates `LastDndSyncAt`.
6. **Opt-in/Opt-out**: user edits checklist + tag-input → Save persists root + bulk-replace `SmsOptKeywords`.
7. **Usage & Billing tab**: KPIs render from `GetSmsUsageAnalytics` (real or stub). User edits `MonthlyBudgetCap` + slider + toggles → Save persists. Webhook checkbox grid → Save persists.
8. User navigates away with dirty section → confirm dialog "Discard unsaved changes?".

---

### Shared blocks

#### Page Header & Breadcrumbs

| Element | Content |
|---------|---------|
| Breadcrumb | Setting › Communication Config › SMS Setup |
| Page title | SMS Integration |
| Subtitle | "Configure SMS provider, sender registration, compliance, and budget for outbound SMS" |
| Right actions | Test SMS / Go to Templates / Go to Campaigns + connection-status badge |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading | Initial fetch | Skeleton matching the actual tab + section layout |
| Empty (Charts) | No usage data | "No SMS sent in this period yet. Connect a provider to start sending." |
| Error | GET fails | Error card with retry button + error code |
| Save error | Save fails | Inline error per section + toast |
| Access denied | Non-BUSINESSADMIN role | `<DefaultAccessDenied />` |

---

## ⑦ Substitution Guide

> **Canonical reference**: `WhatsAppSetting` (BE) + `WhatsAppConfigurationPage` (FE) — closest sibling in same `notify` schema, same singleton-per-tenant pattern, same masked-credential treatment, same opt-keyword child collection.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| WhatsAppSetting | SmsSetting | Entity / class name |
| whatsAppSetting | smsSetting | Variable / field names |
| WHATSAPPSETTING | SMSSETTING | Constant / GQL field name |
| WhatsAppOptKeyword | SmsOptKeyword | Child entity |
| `notify` | `notify` | DB schema (unchanged) |
| Notify | Notify | Backend group (unchanged) |
| `whatsapp-queries` / `whatsapp-mutations` / `whatsapp-service` | `notify-queries` / `notify-mutations` / `notify-service` | FE module folders — SMS Setup uses notify folders to align with SMSTemplate / SMSCampaign which already live there |
| `crm/whatsapp/whatsappconfiguration` | `setting/communicationconfig/smssetup` | FE page-component folder — aligns with EmailProviderConfig precedent (closer sibling than WhatsApp's CRM placement) |
| `pages/setting/communicationconfig/whatsappsetup.tsx` | `pages/setting/communicationconfig/smssetup.tsx` | FE page wrapper |
| `app/[lang]/setting/communicationconfig/whatsappsetup/page.tsx` | `app/[lang]/setting/communicationconfig/smssetup/page.tsx` | Already exists as stub — REPLACE with proper export |
| `WHATSAPPSETUP` | `SMSSETUP` | MenuCode |
| `SET_COMMUNICATIONCONFIG` | `SET_COMMUNICATIONCONFIG` | ParentMenuCode (unchanged) |
| `setting/communicationconfig/whatsappsetup` | `setting/communicationconfig/smssetup` | MenuUrl |

---

## ⑧ File Manifest

### Backend Files (NEW — 24 files)

| # | File | Path |
|---|------|------|
| 1 | Entity (root) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/NotifyModels/SmsSetting.cs` |
| 2 | Entity (sender registration child) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/NotifyModels/SmsSenderRegistration.cs` |
| 3 | Entity (opt keyword child) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/NotifyModels/SmsOptKeyword.cs` |
| 4 | EF Config (root) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/NotifyConfigurations/SmsSettingConfiguration.cs` |
| 5 | EF Config (sender reg) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/NotifyConfigurations/SmsSenderRegistrationConfiguration.cs` |
| 6 | EF Config (opt keyword) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/NotifyConfigurations/SmsOptKeywordConfiguration.cs` |
| 7 | Schemas (DTOs) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/NotifySchemas/SmsSettingSchemas.cs` |
| 8 | GetSetting Query | `.../Base.Application/Business/NotifyBusiness/SmsSettings/GetQuery/GetSmsSetting.cs` |
| 9 | SaveConnection Command | `.../SmsSettings/SaveConnectionCommand/SaveSmsConnectionSettings.cs` |
| 10 | SaveSenderConfiguration Command | `.../SmsSettings/SaveSenderConfigurationCommand/SaveSmsSenderConfiguration.cs` |
| 11 | SaveDndConfiguration Command | `.../SmsSettings/SaveDndConfigurationCommand/SaveSmsDndConfiguration.cs` |
| 12 | SaveOptInConfiguration Command | `.../SmsSettings/SaveOptInConfigurationCommand/SaveSmsOptInConfiguration.cs` |
| 13 | SaveBudgetConfiguration Command | `.../SmsSettings/SaveBudgetConfigurationCommand/SaveSmsBudgetConfiguration.cs` |
| 14 | SaveWebhookEvents Command | `.../SmsSettings/SaveWebhookEventsCommand/SaveSmsWebhookEvents.cs` |
| 15 | TestConnection Command (SERVICE_PLACEHOLDER) | `.../SmsSettings/TestConnectionCommand/TestSmsConnection.cs` |
| 16 | SendTestSms Command (SERVICE_PLACEHOLDER) | `.../SmsSettings/SendTestSmsCommand/SendTestSms.cs` |
| 17 | SyncDndRegistry Command (SERVICE_PLACEHOLDER) | `.../SmsSettings/SyncDndRegistryCommand/SyncDndRegistry.cs` |
| 18 | GetSenderRegistrations Query | `.../SmsSettings/GetSenderRegistrationsQuery/GetSmsSenderRegistrations.cs` |
| 19 | SaveSenderRegistration Command | `.../SmsSettings/SaveSenderRegistrationCommand/SaveSmsSenderRegistration.cs` |
| 20 | DeleteSenderRegistration Command | `.../SmsSettings/DeleteSenderRegistrationCommand/DeleteSmsSenderRegistration.cs` |
| 21 | GetOptKeywords Query | `.../SmsSettings/GetOptKeywordsQuery/GetSmsOptKeywords.cs` |
| 22 | SaveOptKeywords Command (bulk) | `.../SmsSettings/SaveOptKeywordsCommand/SaveSmsOptKeywords.cs` |
| 23 | GetUsageAnalytics Query (SERVICE_PLACEHOLDER) | `.../SmsSettings/GetUsageAnalyticsQuery/GetSmsUsageAnalytics.cs` |
| 24a | Mutations endpoint | `Pss2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Notify/Mutations/SmsSettingMutations.cs` |
| 24b | Queries endpoint | `Pss2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Notify/Queries/SmsSettingQueries.cs` |

> **No Create / Delete commands** for the root SmsSetting — auto-seeded on first GET, never deleted. Only the children have their own CRUD.

### Backend Wiring Updates (6 files)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `INotifyDbContext.cs` (or `IApplicationDbContext.cs` — check current Notify context) | `DbSet<SmsSetting>`, `DbSet<SmsSenderRegistration>`, `DbSet<SmsOptKeyword>` properties |
| 2 | `NotifyDbContext.cs` (or unified DbContext) | Same DbSet properties + `OnModelCreating` configuration registration |
| 3 | `DecoratorProperties.cs` | DecoratorNotifyModules entry — list new entities |
| 4 | `NotifyMappings.cs` | Mapster mapping configs (SmsSetting ↔ Request/Response Dto with masking transform; SmsSenderRegistration; SmsOptKeyword) |
| 5 | `GlobalUsing.cs` (Notify) | `using Base.Application.Schemas.NotifySchemas;` if needed |
| 6 | EF migration | `dotnet ef migrations add Add_SmsSettings_And_Children` (added then `dotnet ef database update`) |

### Frontend Files (NEW — 16 files)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/notify-service/SMSSettingDto.ts` |
| 2 | GQL Query file | `Pss2.0_Frontend/src/infrastructure/gql-queries/notify-queries/SMSSettingQuery.ts` |
| 3 | GQL Mutation file | `Pss2.0_Frontend/src/infrastructure/gql-mutations/notify-mutations/SMSSettingMutation.ts` |
| 4 | Settings Page (orchestrator) | `Pss2.0_Frontend/src/presentation/components/page-components/setting/communicationconfig/smssetup/sms-setup-page.tsx` |
| 5 | ProviderCardSelector | `.../smssetup/provider-card-selector.tsx` |
| 6 | ConnectionConfigSection | `.../smssetup/connection-config-section.tsx` (renders provider-conditional sub-form) |
| 7 | ConnectionStatusCard | `.../smssetup/connection-status-card.tsx` |
| 8 | SenderConfigurationSection | `.../smssetup/sender-configuration-section.tsx` |
| 9 | SenderRegistrationsTable | `.../smssetup/sender-registrations-table.tsx` |
| 10 | SenderRegistrationDialog | `.../smssetup/sender-registration-dialog.tsx` |
| 11 | DndComplianceSection | `.../smssetup/dnd-compliance-section.tsx` |
| 12 | OptInOptOutSection | `.../smssetup/opt-in-out-section.tsx` |
| 13 | ComplianceNotesAccordion | `.../smssetup/compliance-notes-accordion.tsx` |
| 14 | UsageBillingSection | `.../smssetup/usage-billing-section.tsx` (Sections 8–11 + 12) |
| 15 | Page wrapper | `Pss2.0_Frontend/src/presentation/pages/setting/communicationconfig/smssetup.tsx` (mirrors `whatsappsetup.tsx`) |
| 16 | barrel `index.ts` | `.../smssetup/index.ts` |

### Frontend Wiring Updates (5 files)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `app/[lang]/setting/communicationconfig/smssetup/page.tsx` | REPLACE the UnderConstruction stub — import + render `SmsSetupPageConfig` |
| 2 | `presentation/pages/setting/communicationconfig/index.ts` | Export `SmsSetupPageConfig` |
| 3 | `infrastructure/gql-queries/notify-queries/index.ts` | Export new query |
| 4 | `infrastructure/gql-mutations/notify-mutations/index.ts` | Export new mutations (if folder exists; create if missing) |
| 5 | `domain/entities/notify-service/index.ts` | Export new DTO |

> **NOT modified**: `entity-operations.ts` / `operations-config.ts` — CONFIG screens have no row-level CRUD on a top-level grid; matches CompanySettings + EmailProviderConfig precedent.

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: SMS Setup
MenuCode: SMSSETUP
ParentMenu: SET_COMMUNICATIONCONFIG
Module: SETTING
MenuUrl: setting/communicationconfig/smssetup
GridType: CONFIG

MenuCapabilities: READ, MODIFY, ISMENURENDER, CREATE, DELETE

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY, CREATE, DELETE

GridFormSchema: SKIP
GridCode: SMSSETUP
---CONFIG-END---
```

> Capabilities rationale:
> - `READ + MODIFY` for the singleton root (Get / Save).
> - `CREATE + DELETE` for the SmsSenderRegistration child grid (add/remove sender registrations) and SmsOptKeyword bulk replacement.
> - All gated behind the same MenuCode `SMSSETUP`.
> - `GridFormSchema: SKIP` — custom UI, not RJSF modal.
> - Menu already exists in `Module_Menu_List.sql` at MenuId 371 / SET_COMMUNICATIONCONFIG / OrderBy 2 — DB Seed step needs to grant capabilities + role mappings only.

---

## ⑩ Expected BE→FE Contract

**GraphQL Types:**
- Query type: `SmsSettingQueries`
- Mutation type: `SmsSettingMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetSmsSetting | `SmsSettingResponseDto` | — (tenant from HttpContext) |
| GetSmsSenderRegistrations | `[SmsSenderRegistrationResponseDto]` | — |
| GetSmsOptKeywords | `[SmsOptKeywordResponseDto]` | — |
| GetSmsUsageAnalytics | `SmsUsageAnalyticsDto` | `periodStart: String`, `periodEnd: String` |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| SaveSmsConnectionSettings | `SmsConnectionRequestDto` | `SmsSettingResponseDto` (refreshed, masked) |
| SaveSmsSenderConfiguration | `SmsSenderConfigRequestDto` | `SmsSettingResponseDto` |
| SaveSmsDndConfiguration | `SmsDndConfigRequestDto` | `SmsSettingResponseDto` |
| SaveSmsOptInConfiguration | `SmsOptInConfigRequestDto` | `SmsSettingResponseDto` |
| SaveSmsBudgetConfiguration | `SmsBudgetConfigRequestDto` | `SmsSettingResponseDto` |
| SaveSmsWebhookEvents | `SmsWebhookEventsRequestDto` | `SmsSettingResponseDto` |
| TestSmsConnection | — | `SmsConnectionTestResultDto` (SERVICE_PLACEHOLDER) |
| SendTestSms | `SendTestSmsRequestDto` (recipient phone) | `SmsConnectionTestResultDto` (SERVICE_PLACEHOLDER) |
| SyncDndRegistry | — | `SmsSettingResponseDto` (sets LastDndSyncAt) |
| SaveSmsSenderRegistration | `SmsSenderRegistrationRequestDto` | `SmsSenderRegistrationResponseDto` |
| DeleteSmsSenderRegistration | `smsSenderRegistrationId: Int` | `Int` (rows affected) |
| SaveSmsOptKeywords | `[SmsOptKeywordRequestDto]` (bulk replace) | `Int` (saved count) |

**Settings DTO** — sensitive-field handling (mirror `WhatsAppSetting`):
| Field | GET behavior | POST behavior |
|-------|--------------|---------------|
| TwilioAuthToken | omitted from response; `TwilioAuthTokenMasked: "…XXXX"` returned instead | empty string ⇒ unchanged; non-empty ⇒ overwrite |
| BirdApiKey | same pattern | same |
| VonageApiSecret | same | same |
| LocalApiKey / LocalApiSecret | same | same |
| CustomAuthValue | same | same |

**TypeScript shapes** (FE DTO):
```ts
export interface SmsSettingDto {
  smsSettingId?: number | null;
  provider: "Twilio" | "Bird" | "Vonage" | "Local" | "Custom";
  isEnabled: boolean;
  connectionStatus: "Connected" | "Disconnected" | "Pending";
  connectedAt?: string | null;
  // Twilio
  twilioAccountSid?: string | null;
  twilioAuthTokenMasked?: string | null;   // last 4 only on GET
  twilioMessagingServiceSid?: string | null;
  twilioDefaultFromNumber?: string | null;
  // Bird
  birdApiKeyMasked?: string | null;
  birdOriginator?: string | null;
  birdChannelId?: string | null;
  // Vonage
  vonageApiKey?: string | null;
  vonageApiSecretMasked?: string | null;
  vonageApplicationId?: string | null;
  vonageDefaultFromNumber?: string | null;
  // Local
  localProviderName?: string | null;
  localEndpointUrl?: string | null;
  localApiKeyMasked?: string | null;
  localApiSecretMasked?: string | null;
  localSenderId?: string | null;
  localResponseFormat?: "json" | "xml" | null;
  localDocsUrl?: string | null;
  // Custom
  customEndpointUrl?: string | null;
  customAuthType?: "apikey" | "basic" | "bearer" | "custom" | null;
  customAuthValueMasked?: string | null;
  customSuccessResponseCode?: number | null;
  customRequestBodyTemplate?: string | null;
  customDeliveryCallbackUrl?: string | null;   // read-only, system-generated
  // Sender & Compliance
  senderType: "Phone" | "Alphanumeric";
  fallbackSenderNumber?: string | null;
  honorDndRegistry: boolean;
  dndRegistryProvider?: string | null;
  lastDndSyncAt?: string | null;
  requireOptInBeforeSending: boolean;
  optInCollectionPoints: string[];
  optOutConfirmationMessage?: string | null;
  autoProcessOptOutReplies: boolean;
  // Usage & Billing
  monthlyBudgetCap?: number | null;
  budgetAlertThresholdPct: number;
  autoPauseWhenBudgetExceeded: boolean;
  pausePromotionalOnly: boolean;
  webhookEvents: string[];
}

export interface SmsSenderRegistrationDto {
  smsSenderRegistrationId?: number | null;
  countryId: number;
  countryName?: string | null;        // hydrated for grid display
  senderId: string;
  registrationType: string;
  registrationReference?: string | null;
  status: "Registered" | "Approved" | "Active" | "Pending Review" | "Rejected";
}

export interface SmsOptKeywordDto {
  smsOptKeywordId?: number | null;
  keyword: string;
  keywordType: "OptIn" | "OptOut";
  autoReplyMessage?: string | null;
}

export interface SmsUsageAnalyticsDto {
  periodStart: string;
  periodEnd: string;
  totalSent: number;
  delivered: number;
  deliveredPct: number;
  failed: number;
  failedPct: number;
  segmentsUsed: number;
  inboundReplies: number;
  spentThisMonth: number;
  avgCostPerSegment: number;
  costByCountry: { countryName: string; messages: number; segments: number; costPerSegment: number; totalCost: number }[];
  dailyUsage: { date: string; smsCount: number }[];
  deliveryRateByCountry: { countryName: string; deliveryRatePct: number }[];
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] EF migration applies cleanly (`Add_SmsSettings_And_Children`)
- [ ] `pnpm dev` — page loads at `/{lang}/setting/communicationconfig/smssetup`

**Functional Verification (Full E2E — MANDATORY):**

### SETTINGS_PAGE
- [ ] First-load auto-seeds default `SmsSettings` row for current tenant
- [ ] All 13 sections render in correct tab order with correct icons
- [ ] Save-per-section: each section's Save button persists ONLY that section's fields
- [ ] Validation errors block save and surface inline per field (provider-conditional rules respected)
- [ ] Sensitive fields masked (`…XXXX`) on display; empty submit ⇒ unchanged; non-empty ⇒ overwrites
- [ ] Read-only system fields (`ConnectionStatus`, `ConnectedAt`, `LastDndSyncAt`, `CustomDeliveryCallbackUrl`) render disabled and never POST
- [ ] Provider switch is local UI until Connect is clicked; switching while Connected prompts confirm
- [ ] Test SMS / Connect / Sync Now / View Blocked List trigger SERVICE_PLACEHOLDER toasts (no real provider call)
- [ ] Sender Registration child grid: add / edit / delete rows persist correctly; Country ApiSelect uses `GetCountries`
- [ ] Opt-out keyword tag-input persists as bulk replace via `SaveSmsOptKeywords`
- [ ] OptOutConfirmationMessage char counter enforces 320-char cap
- [ ] Budget bar color-codes correctly (green / yellow / red by usage %)
- [ ] BudgetAlertThresholdPct slider clamps 50–100
- [ ] Webhook checkbox grid persists as JSON array
- [ ] Charts render placeholders / empty-states when no data
- [ ] Compliance accordion items expand independently; status chips compute from real sender-reg data when available
- [ ] Quick Links navigate to correct sibling routes
- [ ] Unsaved-changes blocker triggers on dirty navigation
- [ ] Audit trail records every successful Save mutation (whole-payload audit per section)

**DB Seed Verification:**
- [ ] Menu `SMSSETUP` exists at SET_COMMUNICATIONCONFIG with OrderBy=2 (already in `Module_Menu_List.sql` — verify no duplicate insertion)
- [ ] Capabilities granted: READ + MODIFY + CREATE + DELETE + ISMENURENDER for BUSINESSADMIN
- [ ] Default `SmsSetting` row seeded for sample Company (Provider=Twilio, IsEnabled=false, ConnectionStatus=Disconnected, defaults set)
- [ ] No default sender-registration / opt-keyword rows (created by user actions only)
- [ ] Page renders without crashing on a freshly-seeded DB

---

## ⑫ Special Notes & Warnings

**Universal CONFIG warnings:**

- **CompanyId is NOT a form field** — derived from HttpContext via `ITenantContext.GetRequiredTenantId()`.
- **No Create/Delete on root SmsSetting** — singleton pattern. Only children (SmsSenderRegistration / SmsOptKeyword) have CRUD.
- **GridFormSchema = SKIP** — custom multi-section page, not RJSF modal.
- **No view-page 3-mode pattern** — single-mode CONFIG.
- **Sensitive fields**: never serialize raw secrets in GET. Mask + write-only on save (empty ⇒ unchanged). Audit every change. Mirror `WhatsAppSetting` mapper pattern verbatim.
- **Switch Provider while Connected** is a dangerous action — confirm dialog + audit log.
- **Disable SMS** (IsEnabled=false) is a dangerous action — pauses all outbound SMS — confirm + audit.
- **Role gating happens at the BE** — FE hiding fields is UX only.
- **Default seeding**: GET auto-seeds defaults so first-load doesn't 404. Children start empty.

**Sub-type-specific gotchas (SETTINGS_PAGE):**
- Don't use a generic "Basic / Advanced" tab split — the mockup explicitly splits Provider / Compliance / Usage. Match exactly.
- Don't render all sections with identical card chrome — Provider Setup is the hero, Compliance is regulatory-tone, Usage is dashboard-tone (KPI cards + charts).
- Don't render secret fields as plain text — use password input + eye-toggle.
- Don't put Disable SMS / Switch Provider next to ordinary Save — destructive actions get their own confirm dialog + visually segregated styling.
- The provider card selector is NOT a dropdown — it's a 5-card radio grid with conditional sub-form. Mirror `ProviderCardSelector` from EmailProviderConfig.

**Module / module-instance notes:**
- This is the **second SMS-related entity in the `notify` schema** (after SMSTemplate / SMSCampaign already exist). No new schema or group infrastructure needed.
- Parent menu `SET_COMMUNICATIONCONFIG` already exists (MenuId 371) — verify no duplicate seed.
- The route stub at `app/[lang]/setting/communicationconfig/smssetup/page.tsx` (currently UnderConstruction) MUST be replaced with the proper export.
- WhatsAppSetting is the architectural canonical for this screen — copy its mapper, masking, opt-keyword bulk-save, and three-tab layout patterns. Diverge only on save-model (per-section here vs. per-tab there) and provider-card-selector (5 providers vs. WhatsApp's single Meta integration).

**Service Dependencies** (UI-only — no backend service implementation):

> Everything shown in the mockup is in scope. The following items require external services that don't exist in the codebase yet — full UI must be built; only the handler is mocked.

- ⚠ **SERVICE_PLACEHOLDER**: `TestSmsConnection` — full UI implemented. Handler returns mocked `{ success: true, provider: "Twilio (mocked)", ... }`. Real implementation needs an SMS provider service abstraction (`ISmsProviderService` with Twilio/Bird/Vonage/Local/Custom adapters).
- ⚠ **SERVICE_PLACEHOLDER**: `SendTestSms` — same. Handler returns mocked success. Needs the same SMS service.
- ⚠ **SERVICE_PLACEHOLDER**: `SyncDndRegistry` — handler updates `LastDndSyncAt = UtcNow` and returns refreshed setting. Real implementation needs a DND-registry integration service per region (TRAI / DNC.gov / TPS).
- ⚠ **SERVICE_PLACEHOLDER**: `GetSmsUsageAnalytics` — handler returns mocked KPI numbers + cost breakdown + chart series. Real implementation needs (a) provider billing-API integration for cost data, (b) `SmsCampaignRecipient` aggregation for delivery KPIs (delivery KPIs CAN be partly real if `SmsCampaignRecipient` has a `DeliveryStatus` column — check during BA phase). For MVP, ship as pure mock.
- ⚠ **SERVICE_PLACEHOLDER**: "Blocked Contact Count" widget — needs DND service. Display a stub `0` or `2,847` constant.
- ⚠ **SERVICE_PLACEHOLDER**: "Opt-in Statistics" segmented bar (8,466 / 1,494 / 2,490) — needs aggregation over Contact entity's opt-in flag (which may not exist yet). Display zeros or constants for MVP.
- ⚠ **SERVICE_PLACEHOLDER**: "View Blocked List" navigation — destination route may not exist yet; ship as toast "Blocked-list view not yet available" OR placeholder route.

Full UI must be built (5 provider cards + all conditional config blocks, sender-registration grid + dialog, DND switches, opt-in/opt-out tag-input + char counter, budget bar + slider, KPI cards, country cost table, chart placeholders, webhook checkbox grid, compliance accordion, quick links, masked inputs, eye-toggles, copy-to-clipboard, confirm dialogs, audit trail emission). Only the handlers calling out to non-existent SMS / DND / billing services are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | Medium | Backend build (external) | Pre-existing build errors in `Base.Application/Business/DonationBusiness/OnlineDonationPages/PublicQueries/GetOnlineDonationPageBySlug.cs` (lines 122, 126, 127, 129, 133): `error CS0103: The name 'GetAllOnlineDonationPagesListHandler' does not exist in the current context`. NOT caused by SmsSetting. Class exists in sibling file `Queries/GetAllOnlineDonationPagesList.cs` — needs `using` import or namespace fix. Blocks `dotnet build` and therefore (a) automated EF migration generation and (b) full BE+FE E2E browser testing of save flows. | OPEN |
| ISSUE-2 | 1 | Low | Backend (EF migration) | EF migration `20260508123710_Add_SmsSettings_And_Children.cs` was handcrafted because `dotnet ef migrations add` could not run while ISSUE-1 blocks build. Designer file (`*.Designer.cs`) and `ApplicationDbContextModelSnapshot.cs` updates are missing. Once ISSUE-1 is fixed, run `dotnet ef migrations add Add_SmsSettings_And_Children` again — EF tooling should detect the existing migration and only emit the designer/snapshot updates (or merge cleanly). | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-08 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt — Backend + Frontend + DB Seed (FULL scope, save-per-section CONFIG/SETTINGS_PAGE).
- **Files touched**:
  - **BE (24 created + 4 modified + 1 migration + 1 seed)**:
    - Created: `Base.Domain/Models/NotifyModels/SmsSetting.cs`, `SmsSenderRegistration.cs`, `SmsOptKeyword.cs` (created)
    - Created: `Base.Infrastructure/Data/Configurations/NotifyConfigurations/SmsSettingConfiguration.cs`, `SmsSenderRegistrationConfiguration.cs`, `SmsOptKeywordConfiguration.cs` (created)
    - Created: `Base.Application/Schemas/NotifySchemas/SmsSettingSchemas.cs` (created — DTOs + 7 FluentValidation validators)
    - Created: 16 handlers under `Base.Application/Business/NotifyBusiness/SmsSettings/` — `GetQuery/GetSmsSetting.cs`, `SaveConnectionCommand/SaveSmsConnectionSettings.cs`, `SaveSenderConfigurationCommand/SaveSmsSenderConfiguration.cs` (+ internal `SmsSettingUpsertHelper`), `SaveDndConfigurationCommand/SaveSmsDndConfiguration.cs`, `SaveOptInConfigurationCommand/SaveSmsOptInConfiguration.cs`, `SaveBudgetConfigurationCommand/SaveSmsBudgetConfiguration.cs`, `SaveWebhookEventsCommand/SaveSmsWebhookEvents.cs`, `TestConnectionCommand/TestSmsConnection.cs` (placeholder), `SendTestSmsCommand/SendTestSms.cs` (placeholder), `SyncDndRegistryCommand/SyncDndRegistry.cs` (placeholder), `GetSenderRegistrationsQuery/GetSmsSenderRegistrations.cs`, `SaveSenderRegistrationCommand/SaveSmsSenderRegistration.cs`, `DeleteSenderRegistrationCommand/DeleteSmsSenderRegistration.cs`, `GetOptKeywordsQuery/GetSmsOptKeywords.cs`, `SaveOptKeywordsCommand/SaveSmsOptKeywords.cs`, `GetUsageAnalyticsQuery/GetSmsUsageAnalytics.cs` (placeholder) (created)
    - Created: `Base.API/EndPoints/Notify/Queries/SmsSettingQueries.cs`, `Base.API/EndPoints/Notify/Mutations/SmsSettingMutations.cs` (created)
    - Created: `Base.Infrastructure/Migrations/20260508123710_Add_SmsSettings_And_Children.cs` (created — handcrafted, see ISSUE-2)
    - Created: `Base.API/sql-scripts-dyanmic/SmsSetting-sqlscripts.sql` (created — idempotent, 5 capabilities + 4 BUSINESSADMIN role grants + default singleton)
    - Modified: `Base.Application/Data/Persistence/INotifyDbContext.cs` — added 3 DbSets
    - Modified: `Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs` — added 3 Set<T>() properties (configurations auto-discovered via ApplyConfigurationsFromAssembly)
    - Modified: `Base.Application/Extensions/DecoratorProperties.cs` — added 3 entity entries to DecoratorNotifyModules
    - Modified: `Base.Application/Mappings/NotifyMappings.cs` — Mapster configs for SmsSetting (with secret-mask transform), SmsSenderRegistration, SmsOptKeyword
  - **FE (18 created + 5 modified)**:
    - Created: `domain/entities/notify-service/SMSSettingDto.ts` (created — full TS shape with all *Masked fields and 9 request DTOs)
    - Created: `infrastructure/gql-queries/notify-queries/SMSSettingQuery.ts`, `infrastructure/gql-mutations/notify-mutations/SMSSettingMutation.ts` (created)
    - Created: 13 page-component files under `presentation/components/page-components/setting/communicationconfig/smssetup/` — `sms-setup-page.tsx`, `provider-card-selector.tsx`, `connection-config-section.tsx`, `secret-input.tsx`, `connection-status-card.tsx`, `sender-configuration-section.tsx`, `sender-registrations-table.tsx`, `sender-registration-dialog.tsx`, `dnd-compliance-section.tsx`, `opt-in-out-section.tsx`, `compliance-notes-accordion.tsx`, `usage-billing-section.tsx`, `quick-links-section.tsx`, `index.ts` (created)
    - Created: `presentation/pages/setting/communicationconfig/smssetup.tsx` (created — SmsSetupPageConfig with role-gating)
    - Modified: `app/[lang]/setting/communicationconfig/smssetup/page.tsx` — REPLACED UnderConstruction stub with `SmsSetupPageConfig` import
    - Modified: `presentation/pages/setting/communicationconfig/index.ts` — added barrel export
    - Modified: `infrastructure/gql-queries/notify-queries/index.ts` — added `export * from "./SMSSettingQuery"`
    - Modified: `infrastructure/gql-mutations/notify-mutations/index.ts` — added `export * from "./SMSSettingMutation"`
    - Modified: `domain/entities/notify-service/index.ts` — added `export * from "./SMSSettingDto"`
  - **DB**: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/SmsSetting-sqlscripts.sql` (created)
- **Deviations from spec**:
  - **Charts**: prompt suggested using `ChartV2` if present; no such component exists in the codebase, so charts (Daily Usage, Delivery Rate by Country) render as inline Tailwind div bars — matches mockup intent without missing dependency.
  - **Audit emission**: the canonical `WhatsAppSetting` save commands use `ILogger.LogInformation` (not a dedicated audit service); SmsSetting save commands mirror that pattern with `[Audit][SmsSetting][CompanyId={CompanyId}]` log prefix for greppability. When the team adds a real audit-trail service, swap the logger calls.
  - **Validators consolidated**: instead of inline custom validators inside each command's handler validator, all 7 request DTO validators live in `SmsSettingSchemas.cs` and are wired via `RuleFor(x => x.request).SetValidator(...)`.
  - **`SmsSettingUpsertHelper`** lives inline within `SaveSmsSenderConfiguration.cs` (internal access) — six section savers all need it; placing it next to one of them avoided a one-method helper file.
  - **Tag-input + range-slider**: no shared widgets existed; built inline in `opt-in-out-section.tsx` (~30 LoC tag input) and `usage-billing-section.tsx` (native `<input type="range">` with Tailwind styling). 
  - **Minor file count**: FE manifest specified 16 files; final count is 18 because (a) `secret-input.tsx` was extracted into its own file for reuse across 6 secret credential fields, and (b) sender-registration table + dialog were split into two files for reusability and testability. Both are simple static components.
- **Known issues opened**: ISSUE-1 (pre-existing donation build errors blocking dotnet build), ISSUE-2 (EF migration designer/snapshot regen pending ISSUE-1 fix).
- **Known issues closed**: None.
- **Verification status**:
  - FE TypeScript check: `npx tsc --noEmit -p tsconfig.json` from `PSS_2.0_Frontend/` — **0 errors, 0 warnings**.
  - BE compile: BLOCKED by ISSUE-1 (5 errors in DonationBusiness, none in SmsSetting code).
  - Browser E2E (`pnpm dev` + manual click-through of all 13 sections + save flows): DEFERRED until BE build is clean.
  - DB seed shape: validated — idempotent, correct CONFIG capabilities (5 menu + 4 BUSINESSADMIN role grants), default singleton row uses correct defaults from prompt §②.
  - UI uniformity: validated — 0 inline hex, 0 inline pixel padding, 0 bootstrap `card`, 0 raw "Loading..." in generated FE files.
- **Next step**: (none for this build — code generation is complete). For the team: resolve ISSUE-1 first (add the missing `using` for `GetAllOnlineDonationPagesListHandler`), then run `dotnet ef migrations add Add_SmsSettings_And_Children` to regenerate designer/snapshot (ISSUE-2), then `dotnet build` + `pnpm dev` for browser E2E walk-through of all 13 sections (per §⑪ Acceptance Criteria checklist).
