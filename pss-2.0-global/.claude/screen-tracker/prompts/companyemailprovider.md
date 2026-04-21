---
screen: CompanyEmailProvider
registry_id: 28
module: Settings / Communication Config
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
- [x] HTML mockup analyzed (single-page settings config, NOT grid+form)
- [x] Existing code reviewed (BE CRUD exists, FE is stub `AdvancedDataTable` — wrong pattern)
- [x] Business rules + schema gaps extracted (12 new first-class fields + 1 child entity)
- [x] FK targets resolved (MasterData × 2 typeCodes + Currency + Company)
- [x] File manifest computed (BE: modify 10 + add 11 + child entity 3 + migration; FE: delete 3 + create 10 + modify 4)
- [x] Approval config pre-filled (menu EMAILPROVIDERCONFIG — already seeded, rename GridCode from COMPANYEMAILPROVIDER)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (6-card stacked config layout)
- [ ] User Approval received
- [ ] Backend code generated (entity fields + child entity + upsert/workflow commands)
- [ ] Backend wiring complete (DbContext/inverse-nav/Mappings/validators)
- [ ] Frontend code generated (single config page — NO grid, NO view-page 3 modes, NO Zustand grid store)
- [ ] Frontend wiring complete (relocate from `crm/communication/companyemailprovider` → `setting/communicationconfig/emailproviderconfig`)
- [ ] DB Seed script generated (Grid SKIP, GridFormSchema SKIP, MasterData EMAILPROVIDER + EMAILPROVIDERTYPE typeCodes, GridCode rename seed)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/setting/communicationconfig/emailproviderconfig`
- [ ] Sidebar shows "Email Provider Config" under Setting → Communication Config
- [ ] Connection status banner renders (Connected ✓ / Not Configured ⚠)
- [ ] Provider selection: 4 cards (SendGrid, Mailgun, AWS SES, Custom SMTP), single-select radio UX
- [ ] Selecting "Custom SMTP" hides API Settings + Sending Domain cards, shows SMTP Config card
- [ ] Selecting any cloud provider shows API Settings + Sending Domain cards, hides SMTP Config
- [ ] API Key `input[type=password]` + Show/Hide toggle in input-addon
- [ ] API Region dropdown (Global / EU)
- [ ] Webhook URL readonly box with Copy-to-clipboard feedback ("Copied!" tick, 2s revert)
- [ ] 6 Events Tracked checkboxes round-trip to TrackingEventsCsv CSV field
- [ ] Sending Domain: domain name + Verify button (SERVICE_PLACEHOLDER toast) + DNS records table (SERVICE_PLACEHOLDER — 4 rows SendGrid sample data)
- [ ] Sending Identities: table with N rows + inline Edit + ⋯ menu (Set Default / Delete) + "+Add Sending Identity" opens modal
- [ ] Default identity marked with green ✓; only one row can be default per provider
- [ ] Sending Limits & Throttling: 3 numeric inputs (Daily / Hourly / Rate) + 2 usage bars (daily %, monthly %) — usage values from SERVICE_PLACEHOLDER stats query
- [ ] IP & Reputation: 5 stat cards (IP, IP Rep, Domain Rep, Bounce Rate, Spam Rate) — all SERVICE_PLACEHOLDER
- [ ] Custom SMTP Config (when Custom SMTP selected): Host, Port dropdown, Encryption, Auth, Username, Password + Show toggle + Test Connection button (SERVICE_PLACEHOLDER "Connection successful" toast after 1.5s)
- [ ] Header "Send Test Email" button opens modal (SERVICE_PLACEHOLDER toast on send)
- [ ] Header "View Delivery Logs" button → noop SERVICE_PLACEHOLDER (or navigates to EmailAnalytics #41 if built)
- [ ] Action bar sticky bottom: Test Connection + Save Configuration — Save writes single record via upsert mutation
- [ ] Save persists all first-class fields + ProviderConfiguration JSON blob (API key, SMTP creds encrypted client → BE)
- [ ] Unsaved changes dialog triggers on navigation with dirty form
- [ ] Permissions: BUSINESSADMIN READ + MODIFY only (no CREATE/DELETE — single config record per Company)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: CompanyEmailProvider (Email Provider Config)
Module: Settings / Communication Config (SET_COMMUNICATIONCONFIG)
Schema: `notify`
Group: NotifyModels (co-located with EmailTemplate #24, EmailSendJob #25, SavedFilter #27, SMSTemplate #29, WhatsAppTemplate #31)

Business: Email Provider Config is the NGO admin's single-page settings screen for wiring up the transactional/marketing email delivery stack for a Company. One Company selects ONE active provider (SendGrid, Mailgun, AWS SES, or Custom SMTP), provides the API credentials (or SMTP host/port/auth), verifies a sending domain via DNS CNAME/TXT records, registers one-or-more sending identities (From Name / From Email / Reply-To), and sets daily/hourly/per-second throttling limits. Downstream Email Campaign #25, Email Template #24 and every notification-email consumer reads the active provider's ProviderConfiguration + default sending identity at send-time. Unlike a grid+form screen, this is a **single-record configuration page per Company** — the UI is 6 stacked cards with a sticky Save Configuration action bar at the bottom. Reputation metrics (IP score, domain score, bounce rate, spam rate) and daily/monthly usage bars are read-only telemetry pulled from the provider's API on page load.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Audit columns omitted — inherited from Entity base. **CompanyId IS a field** here (not from HttpContext) because the entity existed pre-tenant-scoping — current BE already stores CompanyId explicitly. On Create/Upsert, set from HttpContext user's CompanyId.

Table: `notify."CompanyEmailProviders"` (EXISTING — ALIGN scope)

### Existing columns (keep as-is)
| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CompanyEmailProviderId | int | — | PK | — | Identity |
| CompanyId | int | — | YES | app.Companies | Tenant |
| EmailProviderId | int | — | YES | setting.MasterDatas (typeCode=EMAILPROVIDER) | Provider brand |
| EmailProviderTypeId | int | — | YES | setting.MasterDatas (typeCode=EMAILPROVIDERTYPE) | Transactional / Marketing |
| Priority | int? | — | NO | — | Ordering |
| ProviderConfiguration | string (jsonb) | — | YES | — | Encrypted JSON blob — holds API Key / SMTP host+port+user+pass / OAuth tokens per provider |
| HourlyEmailLimit | int? | — | NO | — | Throttle: emails/hour |
| DailyEmailLimit | int? | — | NO | — | Throttle: emails/day |
| MonthlyEmailLimit | int? | — | NO | — | Throttle: emails/month (provider tier ceiling) |
| DefaultFromEmail | string | 100 | NO | — | Fallback From (overridden by default SendingIdentity) |
| DefaultFromName | string | 100 | NO | — | Fallback From name |
| WebhookUrl | string | 1000 | NO | — | Read-only — generated by app, admin pastes into provider dashboard |
| WebhookSecret | string | 1000 | NO | — | HMAC secret for webhook verification |
| CostPerEmail | decimal(18,6)? | — | NO | — | Pricing telemetry |
| CurrencyId | int? | — | NO | app.Currencies | For CostPerEmail |

### NEW columns to ADD (via EF migration)
| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| ApiRegion | string | 20 | NO | — | "Global" / "EU" — shown for SendGrid/Mailgun/AWS; hidden for Custom SMTP |
| TrackingEventsCsv | string | 500 | NO | — | CSV of enabled events: "Delivered,Opened,Clicked,Bounced,SpamReport,Unsubscribed" |
| RatePerSecond | int? | — | NO | — | Throttle: emails/second (new throttle row in mockup) |
| SendingDomainName | string | 255 | NO | — | FQDN like `mail.ghf.org` — single active sending domain |
| DomainStatus | string | 30 | NO | — | "Pending" / "Verified" / "Failed" — set by VerifyDomain (SERVICE_PLACEHOLDER) |
| DomainVerifiedAt | DateTime? | — | NO | — | UTC timestamp of last successful verification |
| SendingIp | string | 45 | NO | — | Dedicated IP (IPv4/IPv6 max 45 chars) — read-only, SERVICE_PLACEHOLDER from provider |
| IsDefault | bool | — | YES | — | Default `false`. One row per Company may have IsDefault=true (enforced by unique filtered index) |
| LastEmailSentAt | DateTime? | — | NO | — | Populated by EmailSendJob #25 dispatch — used by status banner "last email sent 2 minutes ago" |
| IpReputationScore | int? | — | NO | — | 0-100 score — SERVICE_PLACEHOLDER snapshot refreshed on Save |
| DomainReputationScore | int? | — | NO | — | 0-100 score — SERVICE_PLACEHOLDER snapshot |
| BounceRate | decimal(5,2)? | — | NO | — | Percentage (0.00-100.00) — SERVICE_PLACEHOLDER snapshot |
| SpamRate | decimal(5,2)? | — | NO | — | Percentage (0.00-100.00) — SERVICE_PLACEHOLDER snapshot |

### Child Entity — NEW: `EmailSendingIdentity`

Table: `notify."EmailSendingIdentities"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| EmailSendingIdentityId | int | — | PK | — | Identity |
| CompanyEmailProviderId | int | — | YES | notify.CompanyEmailProviders | Parent provider |
| FromName | string | 100 | YES | — | e.g. "Global Humanitarian Foundation" |
| FromEmail | string | 100 | YES | — | e.g. `noreply@mail.ghf.org` — must share SendingDomainName |
| ReplyToEmail | string | 100 | NO | — | e.g. `info@ghf.org` — optional override |
| IsDefault | bool | — | YES | — | Only one default per parent (enforced by unique filtered index) |
| IsVerified | bool | — | YES | — | Default `false` — set via VerifySendingIdentity SERVICE_PLACEHOLDER |
| VerifiedAt | DateTime? | — | NO | — | Last verification success timestamp |

### Child Relationship Summary
| Child Entity | Relationship | Cascade | Notes |
|-------------|-------------|---------|-------|
| EmailSendingIdentity | 1 CompanyEmailProvider : Many EmailSendingIdentities via CompanyEmailProviderId | Cascade delete on parent | Navigation property `SendingIdentities` on parent |

### Indexes
- Existing: unique `(CompanyId, EmailProviderId, EmailProviderTypeId, IsActive)` — KEEP
- NEW unique filtered index: `(CompanyId) WHERE IsDefault = true AND IsDeleted = false` — enforces single-default-per-Company
- NEW child unique filtered index: `(CompanyEmailProviderId) WHERE IsDefault = true AND IsDeleted = false` — enforces single-default-identity-per-provider

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (Include + validators) + Frontend Developer (ApiSelectV2 queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| CompanyId | Company | `Base.Domain/Models/ApplicationModels/Company.cs` | (tenant — HttpContext, no picker) | CompanyName | CompanyResponseDto |
| EmailProviderId | MasterData (typeCode=EMAILPROVIDER) | `Base.Domain/Models/SettingModels/MasterData.cs` | `masterDatasByTypeCode(typeCode:"EMAILPROVIDER")` via existing `MasterDataQueries` | DataName | MasterDataResponseDto |
| EmailProviderTypeId | MasterData (typeCode=EMAILPROVIDERTYPE) | `Base.Domain/Models/SettingModels/MasterData.cs` | `masterDatasByTypeCode(typeCode:"EMAILPROVIDERTYPE")` | DataName | MasterDataResponseDto |
| CurrencyId | Currency | `Base.Domain/Models/SharedModels/Currency.cs` | `currencies` via existing `CurrencyQueries` | CurrencyName | CurrencyResponseDto |

**Note**: MasterData inverse nav props already exist on `MasterData.cs:47-48`:
```csharp
public ICollection<CompanyEmailProvider>? EmailProviders { get; set; }
public ICollection<CompanyEmailProvider>? EmailProviderTypes { get; set; }
```
No new inverse-nav needed.

**FE ApiSelect pattern**: Frontend uses provider-CARD selector for EmailProviderId (NOT a dropdown) — 4 visual cards mapped from `masterDatasByTypeCode(typeCode:"EMAILPROVIDER")`. Card icon/color comes from a client-side lookup keyed by DataCode (`SENDGRID`, `MAILGUN`, `AWSSES`, `SMTP`). EmailProviderTypeId stays as a hidden field (defaults to "Transactional") — not shown in mockup; wire silently.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- Exactly ONE default `CompanyEmailProvider` per Company (unique filtered index `(CompanyId) WHERE IsDefault = true AND IsDeleted = false`).
- Exactly ONE default `EmailSendingIdentity` per `CompanyEmailProvider` (same pattern).
- SendingDomainName must be unique per Company (SendGrid requires single-tenant domains).
- FromEmail must be unique per CompanyEmailProvider.

**Required Field Rules:**
- EmailProviderId, EmailProviderTypeId, ProviderConfiguration — already required (keep).
- When Provider DataCode = `SMTP`: ProviderConfiguration JSON MUST contain `smtpHost`, `smtpPort`, `encryption`, `authMethod`, `username`, `password`. Validator parses JSON and enforces.
- When Provider DataCode != `SMTP`: ProviderConfiguration JSON MUST contain `apiKey`. `apiRegion` optional.
- SendingDomainName required when saving ANY non-SMTP provider with identities configured.
- FromName + FromEmail required on every EmailSendingIdentity.

**Conditional Rules:**
- If EmailProvider.DataCode = `SMTP` → ApiRegion, WebhookUrl, WebhookSecret hidden/null on FE; SendingDomainName + DNS records card hidden.
- If EmailProvider.DataCode ∈ {`SENDGRID`, `MAILGUN`, `AWSSES`} → SMTP config card hidden; API Settings + Sending Domain cards shown.
- TrackingEventsCsv defaults to `"Delivered,Opened,Clicked,Bounced,SpamReport,Unsubscribed"` (all 6) on Create.
- HourlyEmailLimit ≤ DailyEmailLimit ≤ MonthlyEmailLimit (when all three set).
- RatePerSecond ≤ HourlyEmailLimit / 3600 (soft warning, not hard fail).

**Business Logic:**
- FromEmail domain MUST match SendingDomainName (e.g., FromEmail `noreply@mail.ghf.org` + SendingDomainName `mail.ghf.org` ✓). Enforce via FluentValidation.
- Setting `IsDefault=true` on a CompanyEmailProvider auto-sets ALL other providers for the same Company to `IsDefault=false` (in transaction).
- Setting `IsDefault=true` on an EmailSendingIdentity auto-sets all other identities under the same provider to `IsDefault=false`.
- Deleting a provider that has `LastEmailSentAt` within the last 7 days → block with friendly error (BadRequestException: "Provider has recent email activity — deactivate instead of deleting").

**Workflow** (simplified — not a full state machine):
- DomainStatus: `null` → `Pending` (on Save with domain) → `Verified` (VerifyDomain success SERVICE_PLACEHOLDER) → `Failed` (on retry failure).
- Transitions triggered by: user clicks "Verify Domain" button → `VerifySendingDomain` mutation → SERVICE_PLACEHOLDER sets `DomainStatus='Verified'`, `DomainVerifiedAt=UtcNow`.
- IsActive toggle unchanged (inherited) — but FE HIDES the Toggle action (single-record config; use IsDefault flip instead).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — PRE-ANSWERED decisions.

**Screen Type**: FLOW (non-standard — **single-record config page**, NOT grid+form+detail)
**Type Classification**: Config / Single-Record Settings (sibling pattern to NotificationCenter #35 — no grid, custom layout)
**Reason**: The mockup shows ONE record per Company (the active email provider) on a single scrollable page with 6 stacked cards. There is NO grid-list of providers — users don't browse a list; they configure "the" provider. NO `?mode=new / edit / read` URL switching — the page is always in "edit the single record" mode. NO view-page.tsx 3-mode pattern.

**Backend Patterns Required:**
- [x] Standard CRUD on parent (11 files) — ALIGN: Create/Update/Delete/Toggle/GetAll/GetById already exist, MUST extend with new fields
- [x] Tenant scoping (CompanyId from HttpContext on Upsert)
- [x] Nested child creation — EmailSendingIdentity (parent Save sends list; handler diffs create/update/delete)
- [x] Multi-FK validation (MasterData × 2 + Currency — already in place)
- [x] Unique filtered index × 2 (IsDefault-per-Company, IsDefault-per-provider)
- [x] Conditional validation (SMTP vs cloud provider based on EmailProvider.DataCode)
- [x] Upsert command (Create-or-Update) — new `SaveCompanyEmailProviderCommand`
- [x] Workflow commands — `VerifySendingDomain`, `TestEmailProviderConnection`, `VerifySendingIdentity` (all SERVICE_PLACEHOLDER returning mock success)
- [x] Active-record query — new `GetActiveCompanyEmailProvider(companyId)` — returns the single IsDefault=true row with children
- [x] Stats query — new `GetEmailProviderStats(companyEmailProviderId)` — SERVICE_PLACEHOLDER returning mocked usage + reputation

**Frontend Patterns Required:**
- [ ] FlowDataTable grid — **NO** (single-record page)
- [ ] view-page.tsx 3-modes — **NO** (single page)
- [x] React Hook Form (single giant form wrapping all 6 cards)
- [x] Zustand store (for transient UI state: selected provider, password-reveal toggles) — OR `useState` suffices given single-page
- [x] Unsaved changes dialog (dirty form)
- [ ] FlowFormPageHeader — **NO** (uses `<ScreenHeader>` + sticky bottom action bar)
- [x] Child inline table (EmailSendingIdentities) — with +Add modal + row edit + ⋯ menu (Set Default, Delete)
- [x] Card selector (4 provider cards — single-select)
- [x] Conditional sub-forms (SMTP card vs cloud-provider API+Domain cards)
- [x] Show/Hide password inputs (API Key, SMTP Password)
- [x] Copy-to-clipboard button (Webhook URL)
- [x] Usage progress bars × 2 (daily, monthly — readonly SERVICE_PLACEHOLDER)
- [x] Reputation stat cards × 5 (IP, IP Rep, Domain Rep, Bounce Rate, Spam Rate — readonly SERVICE_PLACEHOLDER)
- [x] Status banner (Connected / Not Configured — driven by DomainStatus + LastEmailSentAt)
- [x] DNS records readonly table (SERVICE_PLACEHOLDER — seed 4 sample rows from provider SDK mock)
- [x] ScreenHeader + 2 header action buttons (Send Test Email, View Delivery Logs)
- [x] Sticky bottom ActionBar (Test Connection, Save Configuration)
- [ ] Summary cards above grid — **NO**
- [ ] Grid aggregation columns — **NO**

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from `html_mockup_screens/screens/settings/email-provider-config.html`.
>
> **CRITICAL**: This is NOT a standard FLOW screen. There is NO grid. There is NO view-page with 3 modes. There is ONE config page that loads the current Company's active provider (or empty if none).

### Layout Variant
**Grid Layout Variant**: `NONE — custom config page` (stamp: no grid)
Build pattern: Variant B equivalent — `<ScreenHeader>` at top + stacked `<Card>` components in a max-width 1280px container + sticky bottom `<ActionBar>` (position:sticky, bottom:0). NO `<DataTableContainer>`, NO `<FlowDataTable>`, NO `<AdvancedDataTable>`.

### Page Header (`<ScreenHeader>`)

Title: "Email Provider" (with `fa-envelope` / Phosphor `envelope-simple` icon, brand accent color)
Subtitle: "Configure email service provider, sending domain, and delivery settings"
Right-side actions:
1. **Send Test Email** — outline button, `paper-plane` icon → opens test-email modal (fields: To Email, optional Message) → SERVICE_PLACEHOLDER toast "Test email sent" (no real dispatch)
2. **View Delivery Logs** — outline button, `chart-line` icon → SERVICE_PLACEHOLDER toast "Delivery logs coming in Email Analytics" (or navigate to `/crm/communication/emailanalytics` when #41 is built)

### Status Banner (below header, above first card)

Conditional banner:
- **Connected** (green): shown when `DomainStatus='Verified' AND SendingIdentities has ≥1 verified default AND LastEmailSentAt within 24h`. Text: "Connected to {EmailProvider.DataName} — Domain verified, last email sent {relative time}."
- **Not Configured** (amber/warning): shown when no default provider OR DomainStatus != 'Verified'. Text: "Not configured — Select a provider and verify your sending domain."
- **Configured but inactive** (grey): default provider exists but no email sent ever. Text: "Provider configured — send a test email to verify connectivity."

### Card 1 — Email Service Provider (always shown)

Icon: `plug` (accent color) · Title: "Email Service Provider"

4 provider cards in responsive grid (`repeat(auto-fill, minmax(220px, 1fr))`). Single-select radio UX — clicking a card selects it, shows radio-dot indicator, tints border + background with accent color.

| DataCode (MasterData) | DataName | Icon | Color Token | Volume Hint |
|----------------------|----------|------|-------------|-------------|
| SENDGRID | SendGrid | `paper-plane` | blue-500 | "Up to 100K/month" |
| MAILGUN | Mailgun | `envelope-circle-check` | pink-600 | "Up to 50K/month" |
| AWSSES | AWS SES | `aws` (brand) | amber-600 | "Unlimited" |
| SMTP | Custom SMTP | `gear` | slate-500 | "Varies" |

Card content: Icon (48px rounded-12 tinted bg), Name (bold), Description (muted), Volume hint (accent color, small).

**Client-side card registry**: static TS map keyed by DataCode → { icon, colorClass, description, volumeHint }. Do NOT hardcode provider list; iterate over `masterDatasByTypeCode(typeCode:"EMAILPROVIDER")` and enrich each row with the registry entry. If a provider DataCode is not in the registry → render a generic grey card with `gear` icon.

**Selection behavior**:
- On select → update form.emailProviderId + DataCode.
- If DataCode === `SMTP` → hide Card 2 (API Settings) + Card 3 (Sending Domain); show Card 7 (SMTP Config) below reputation card (same position as mockup).
- If DataCode ∈ {cloud providers} → show Card 2 + Card 3; hide Card 7.

### Card 2 — API Settings (shown for cloud providers only)

Icon: `key` · Title: "API Settings"

2-column grid:
- **API Key** (required, password input with Show/Hide toggle in input-addon) — stored in ProviderConfiguration.apiKey (encrypted)
- **API Region** (dropdown: Global / EU) — binds to ApiRegion column

Full-width row:
- **Webhook URL** (readonly code-box + Copy button) — computed server-side as `{apiBaseUrl}/webhooks/{provider-code-lowercase}` e.g. `https://api.ghf.org/webhooks/sendgrid`. Copy button shows "Copied!" + green tick for 2 seconds, then reverts. Subtitle hint: "Provide this URL in your SendGrid dashboard to receive delivery events."

Full-width row:
- **Events Tracked** — 6 checkboxes (Delivered, Opened, Clicked, Bounced, Spam Report, Unsubscribed). Round-trip to `TrackingEventsCsv` as CSV string. All 6 checked by default on Create.

### Card 3 — Sending Domain (shown for cloud providers only)

Icon: `globe` · Title: "Sending Domain" · Right-side buttons:
- **Verify Domain** button (`rotate` icon) → calls `VerifySendingDomain` mutation → SERVICE_PLACEHOLDER sets DomainStatus='Verified' after mock 1.5s, reloads card
- **Add New Domain** button (`plus` icon) → SERVICE_PLACEHOLDER toast "Multi-domain support coming soon" (single-domain MVP)

Body:
- **Domain name row**: monospace large font + Verified badge (green `circle-check` + "Verified (DNS records confirmed)") when DomainStatus='Verified'; grey "Pending verification" when Pending; red "Verification failed" when Failed.
- **DNS Records Required** section (label + table):

DNS records table — 4 columns: Type, Name, Value, Status. Rows are SERVICE_PLACEHOLDER — provider returns this list via SDK (SendGrid `WhitelabelDomains.dns.*`, AWS SES `IdentityDkimAttributes`, Mailgun `/domains/{domain}/dns_records`). For MVP, BE returns 4 hardcoded sample rows from `GetSendingDomainDnsRecords(companyEmailProviderId)` SERVICE_PLACEHOLDER query:

| Type | Name | Value | Status |
|------|------|-------|--------|
| CNAME | `em1234.{domain}` | `u1234.wl.sendgrid.net` | Verified |
| CNAME | `s1._domainkey.{domain}` | `s1.domainkey.u1234.wl...` | Verified |
| CNAME | `s2._domainkey.{domain}` | `s2.domainkey.u1234.wl...` | Verified |
| TXT | `{domain}` | `v=spf1 include:sendgrid.net ~all` | Verified |

Value column uses monospace font with truncate-with-tooltip for long strings.

### Card 4 — Sending Identities (always shown)

Icon: `user-tag` · Title: "Sending Identities" · Right-side button:
- **+Add Sending Identity** (`plus` icon) → opens `<AddSendingIdentityDialog>` modal

Body: full-width table (no grid-component wrapper, plain `<table>` styled `.data-table`):

| Column | Width | Content |
|--------|-------|---------|
| From Name | auto | Bold text (e.g. "Global Humanitarian Foundation") |
| From Email | auto | `<code>` styled badge (e.g. `noreply@mail.ghf.org`) |
| Reply-To | auto | Plain text (e.g. `info@ghf.org`) or em-dash if null |
| Default | 60px | Green `circle-check` icon if IsDefault=true; empty otherwise |
| Verified | 80px | Green "Verified" badge if IsVerified=true; amber "Pending" badge otherwise |
| Actions | 120px | Edit button (`pen` icon) opens edit-modal + `⋯` kebab menu (Set Default / Resend Verification / Delete) |

Row UX:
- Edit → modal pre-filled (FromName, FromEmail, ReplyToEmail)
- Set Default → confirms with `setDefaultSendingIdentity` mutation, refreshes list
- Resend Verification → SERVICE_PLACEHOLDER toast "Verification email sent"
- Delete → confirm dialog; blocks if IsDefault=true with error "Cannot delete default identity — set another as default first"

**AddSendingIdentityDialog** (and EditSendingIdentityDialog):
Form fields:
- From Name (text, required, max 100) — placeholder "e.g., Global Humanitarian Foundation"
- From Email (text, required, max 100) — placeholder "e.g., noreply@mail.ghf.org" — validator: must match `@{SendingDomainName}` suffix
- Reply-To Email (text, optional, max 100) — placeholder "e.g., info@ghf.org"
- Make Default checkbox (only shown when no existing default OR on Edit)

Dialog actions: Cancel / Save (Save calls create/update + closes).

### Card 5 — Sending Limits & Throttling (always shown)

Icon: `gauge-high` · Title: "Sending Limits & Throttling"

3-column grid (row 1):
- **Daily Limit** (numeric input, max-width 120px + "emails/day" suffix label) — binds DailyEmailLimit
- **Hourly Limit** (numeric input + "emails/hour" suffix) — binds HourlyEmailLimit
- **Rate Limit** (numeric input + "emails/second" suffix) — binds RatePerSecond

Below: 2 usage bars (stacked vertically, full-width each):

1. **Current Usage Today** bar:
   - Right-aligned accent % value (e.g., "24.7%")
   - Progress bar (8px tall, rounded, accent-color fill; warning orange at >75%, red at >90%)
   - Label below: "{DailyUsageCount} sent" · "{DailyEmailLimit} limit"
   - Values from `GetEmailProviderStats` SERVICE_PLACEHOLDER query

2. **Monthly Usage** bar (same structure, uses MonthlyUsageCount / MonthlyEmailLimit)

### Card 6 — IP & Reputation (always shown)

Icon: `shield-halved` · Title: "IP & Reputation"

5 reputation cards in responsive grid (`repeat(auto-fill, minmax(180px, 1fr))`):

| Card | Label | Value | Detail |
|------|-------|-------|--------|
| 1 | Sending IP | `{SendingIp}` (monospace) | "Dedicated IP" or "Shared IP" derived from provider |
| 2 | IP Reputation | green-dot + "Good ({IpReputationScore}/100)" | "Excellent standing" / "Good standing" / "Needs attention" |
| 3 | Domain Reputation | green-dot + "Good ({DomainReputationScore}/100)" | same scale |
| 4 | Bounce Rate | success-color `{BounceRate}%` | "Target: <2%" |
| 5 | Spam Rate | success-color `{SpamRate}%` | "Target: <0.1%" |

Color coding by score: ≥90 green, 70-89 yellow, <70 red. For rates: <2% green, 2-5% yellow, >5% red.

All values SERVICE_PLACEHOLDER from `GetEmailProviderStats` query — BE returns mocked constants from a `EmailProviderReputationMock` class until real provider SDK integration is added.

### Card 7 — SMTP Configuration (shown ONLY when Provider.DataCode = 'SMTP')

Icon: `server` · Title: "SMTP Configuration"

2-column grid × 3 rows:

Row 1: SMTP Host (text, required, placeholder `smtp.office365.com`) · SMTP Port (dropdown: 25, 465, 587, 2525 — default 587)
Row 2: Encryption (dropdown: None / SSL/TLS / STARTTLS — default STARTTLS) · Authentication (dropdown: PLAIN / LOGIN / CRAM-MD5 — default LOGIN)
Row 3: Username (text, required, placeholder email) · Password (password input + Show/Hide toggle)

All SMTP fields persist into `ProviderConfiguration` JSON blob as `smtpHost`, `smtpPort`, `encryption`, `authMethod`, `username`, `password` (encrypted server-side on upsert).

Below fields:
- **Test Connection** outline button (`plug-circle-check` icon) → calls `TestEmailProviderConnection` mutation → SERVICE_PLACEHOLDER returns mock success after 1.5s → inline result indicator right of button: spinner → green check + "Connection successful" (or red × + error message).

### Sticky Bottom Action Bar (always shown)

`position:sticky; bottom:0` inside the page container. White background + subtle top-shadow.

Right-aligned buttons:
1. **Test Connection** (outline button, `plug-circle-check` icon) — for cloud providers calls a provider-specific health endpoint; for SMTP delegates to Card 7's Test Connection logic.
2. **Save Configuration** (primary accent button, `floppy-disk` icon) — calls `SaveCompanyEmailProviderCommand` upsert mutation with entire form payload (parent fields + child identities list + ProviderConfiguration JSON).

### Page Widgets & Summary Cards
**Widgets**: NONE (no count widgets above — page IS the widget layout)

### Grid Aggregation Columns
**Aggregation Columns**: NONE (no grid)

### User Interaction Flow

1. User navigates to `/setting/communicationconfig/emailproviderconfig`.
2. Page calls `GetActiveCompanyEmailProvider` → returns either:
   - The default provider with children (normal case) → form pre-fills, status banner "Connected"
   - Null (first-time setup) → form shows empty with default provider card none-selected, status banner "Not Configured", save button disabled until provider + domain entered
3. User picks a provider card → Cards 2+3 or Card 7 conditionally render.
4. User fills API Key (or SMTP creds), domain, identities, limits.
5. User clicks Verify Domain → SERVICE_PLACEHOLDER → DomainStatus='Verified'.
6. User clicks +Add Sending Identity → modal → Save → row appended to table.
7. User clicks Save Configuration → upsert mutation → toast "Configuration saved" → page reloads with fresh data.
8. User clicks Test Connection → mutation → inline result indicator.
9. User clicks Send Test Email in header → modal → submit → toast "Test email sent" (SERVICE_PLACEHOLDER).
10. Back button (browser) or sidebar nav while dirty → confirm dialog "You have unsaved changes. Discard?"

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer

**Canonical Reference**: SavedFilter (FLOW — closest FLOW precedent) + NotificationCenter #35 (for non-grid custom FLOW UI pattern)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | CompanyEmailProvider | Entity/class name |
| savedFilter | companyEmailProvider | Variable/field names |
| SavedFilterId | CompanyEmailProviderId | PK field |
| SavedFilters | CompanyEmailProviders | Table name, collection names |
| saved-filter | email-provider-config | **FE route path / folder name (ALIGN rename)** |
| savedfilter | emailproviderconfig | **FE folder path (kebab-free), menu url path segment** |
| SAVEDFILTER | EMAILPROVIDERCONFIG | **GridCode (ALIGN rename from COMPANYEMAILPROVIDER → EMAILPROVIDERCONFIG)** |
| notify | notify | DB schema (same) |
| Notify | Notify | Backend group name (same) |
| NotifyModels | NotifyModels | Namespace suffix (same) |
| CRM_COMMUNICATION | **SET_COMMUNICATIONCONFIG** | **ParentMenuCode (ALIGN: move from CRM to Setting module)** |
| CRM | **SETTING** | **ModuleCode (ALIGN)** |
| crm/communication/savedfilter | **setting/communicationconfig/emailproviderconfig** | **FE route path (ALIGN move)** |
| notify-service | notify-service | FE service folder name (same) |

**ALIGN renames — explicit list** (search-and-replace targets across repo):

| From | To | Files |
|------|----|-------|
| GridCode `COMPANYEMAILPROVIDER` | `EMAILPROVIDERCONFIG` | BE seed SQL + FE `notify-service-entity-operations.ts` + FE `data-table.tsx` (DELETE this file) + page-config `useAccessCapability({ menuCode: "..." })` |
| FE folder `crm/communication/companyemailprovider/` | **DELETE** (move to new path) | 2 files |
| FE folder `setting/communicationconfig/emailproviderconfig/` | **CREATE** | NEW (10 files) |
| FE page `crm/communication/companyemailprovider.tsx` | **DELETE** (replaced) | 1 file |
| FE page `setting/communicationconfig/emailproviderconfig.tsx` | **CREATE** | NEW |
| Old menu COMPANYEMAILPROVIDER (from Pss2.0_Old_Menu_List.sql line 96) | **DEPRECATE** via seed UPDATE | 1 SQL idempotent patch |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files — ALIGN (11 existing + 5 new + 1 migration)

**MODIFY existing (10 files)**:

| # | File | Change |
|---|------|--------|
| 1 | `Base.Domain/Models/NotifyModels/CompanyEmailProvider.cs` | Add 13 new columns + `ICollection<EmailSendingIdentity>? SendingIdentities` nav |
| 2 | `Base.Infrastructure/Data/Configurations/NotifyConfigurations/CompanyEmailProviderConfiguration.cs` | Add `.Property()` configs for 13 new columns, new unique filtered index on `(CompanyId)` where IsDefault=true, cascade-delete to SendingIdentities |
| 3 | `Base.Application/Schemas/NotifySchemas/CompanyEmailProviderSchemas.cs` | Add 13 new fields to Request+Response DTOs, add child `IEnumerable<EmailSendingIdentityRequestDto>? SendingIdentities`, add new `CompanyEmailProviderStatsDto`, add new `EmailDnsRecordDto`, add new `EmailSendingIdentityRequestDto` + `EmailSendingIdentityResponseDto` |
| 4 | `Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Commands/CreateCompanyEmailProvider.cs` | Add validators for new fields (ApiRegion enum, FromEmail domain match, SMTP JSON structure) |
| 5 | `Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Commands/UpdateCompanyEmailProvider.cs` | Same validators + handle IsDefault flip transaction (unset others) |
| 6 | `Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Commands/DeleteCompanyEmailProvider.cs` | Add "recent activity" block rule (LastEmailSentAt within 7d) |
| 7 | `Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Queries/GetCompanyEmailProvider.cs` | Add `.Include(x => x.SendingIdentities)` + post-projection flatten for FE — rename method GetCompanyEmailProviderHandler (typo: currently singular even though plural query — keep) |
| 8 | `Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Queries/GetCompanyEmailProviderById.cs` | Same Include + flatten |
| 9 | `Base.API/EndPoints/Notify/Mutations/CompanyEmailProviderMutations.cs` | Add `SaveCompanyEmailProvider` upsert endpoint + `VerifySendingDomain` + `TestEmailProviderConnection` + `CreateSendingIdentity` + `UpdateSendingIdentity` + `DeleteSendingIdentity` + `SetDefaultSendingIdentity` + `VerifySendingIdentity` (8 new GQL fields) |
| 10 | `Base.API/EndPoints/Notify/Queries/CompanyEmailProviderQueries.cs` | Add `GetActiveCompanyEmailProvider` (current-company single record) + `GetEmailProviderStats` + `GetSendingDomainDnsRecords` (3 new GQL fields) |

**CREATE (5 files + 1 migration)**:

| # | File | Purpose |
|---|------|---------|
| 1 | `Base.Domain/Models/NotifyModels/EmailSendingIdentity.cs` | NEW child entity |
| 2 | `Base.Infrastructure/Data/Configurations/NotifyConfigurations/EmailSendingIdentityConfiguration.cs` | EF config + FK + unique filtered index on (CompanyEmailProviderId) WHERE IsDefault=true |
| 3 | `Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Commands/SaveCompanyEmailProvider.cs` | Upsert command + handler (diffs children, flips defaults) |
| 4 | `Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Commands/WorkflowCompanyEmailProvider.cs` | VerifyDomain + TestConnection + VerifyIdentity commands (SERVICE_PLACEHOLDER) — collocate in one file |
| 5 | `Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Queries/GetCompanyEmailProviderStats.cs` | Stats query + GetActiveCompanyEmailProvider query + GetSendingDomainDnsRecords query (SERVICE_PLACEHOLDER mocks) |
| 6 | `Base.Infrastructure/Migrations/{Timestamp}_ExpandCompanyEmailProviderForConfigPage.cs` | EF migration: 13 new columns + EmailSendingIdentities table + 2 unique filtered indexes |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Base.Application/Data/Persistence/INotifyDbContext.cs` | `DbSet<EmailSendingIdentity> EmailSendingIdentities { get; }` |
| 2 | `Base.Infrastructure/Data/Persistence/NotifyDbContext.cs` | `public DbSet<EmailSendingIdentity> EmailSendingIdentities => Set<EmailSendingIdentity>();` |
| 3 | `Base.Application/Extensions/DecoratorProperties.cs` | `DecoratorNotifyModules.EmailSendingIdentity = "EmailSendingIdentity"` constant |
| 4 | `Base.Application/Mappings/NotifyMappings.cs` | Mapster mapping: `EmailSendingIdentity ↔ EmailSendingIdentityRequestDto`, `EmailSendingIdentity → EmailSendingIdentityResponseDto`; parent mapping `CompanyEmailProvider → CompanyEmailProviderResponseDto` add `.Map(dest => dest.SendingIdentities, src => src.SendingIdentities)` |

### Frontend Files — ALIGN (3 delete + 10 create + 4 modify)

**DELETE (3 files — obsolete stub)**:

| # | File | Why |
|---|------|-----|
| 1 | `Pss2.0_Frontend/src/presentation/components/page-components/crm/communication/companyemailprovider/data-table.tsx` | Stub `AdvancedDataTable` — wrong pattern (no grid for config screen) |
| 2 | `Pss2.0_Frontend/src/presentation/components/page-components/crm/communication/companyemailprovider/index.ts` | Exports deleted component |
| 3 | `Pss2.0_Frontend/src/presentation/pages/crm/communication/companyemailprovider.tsx` | Page-config in wrong module; orphan (no route registered) |

**CREATE (10 files — new config page at correct path)**:

| # | File | Path |
|---|------|------|
| 1 | Page Config | `Pss2.0_Frontend/src/presentation/pages/setting/communicationconfig/emailproviderconfig.tsx` |
| 2 | Index (barrel + page-config wiring) | `Pss2.0_Frontend/src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/index.ts` |
| 3 | Main page component | `Pss2.0_Frontend/src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/email-provider-config-page.tsx` |
| 4 | Provider card selector | `Pss2.0_Frontend/src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/provider-card-selector.tsx` |
| 5 | Sending identities table | `Pss2.0_Frontend/src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/sending-identities-table.tsx` |
| 6 | Add/Edit identity dialog | `Pss2.0_Frontend/src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/sending-identity-dialog.tsx` |
| 7 | DNS records readonly table | `Pss2.0_Frontend/src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/dns-records-table.tsx` |
| 8 | Reputation stat cards | `Pss2.0_Frontend/src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/reputation-cards.tsx` |
| 9 | Usage bars | `Pss2.0_Frontend/src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/usage-bars.tsx` |
| 10 | Provider card registry (TS constants) | `Pss2.0_Frontend/src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/provider-registry.ts` |
| 11 | Route Page | `Pss2.0_Frontend/src/app/[lang]/(core)/setting/communicationconfig/emailproviderconfig/page.tsx` |

(File count: 10 page-components + 1 route-page = 11 creates. Adjust if "CREATE 10" line count conflicts — this is the actual list.)

**MODIFY (4 files)**:

| # | File | Change |
|---|------|--------|
| 1 | `Pss2.0_Frontend/src/domain/entities/notify-service/CompanyEmailProviderDto.ts` | Add 13 new fields + `SendingIdentities?: EmailSendingIdentityDto[]` + new `EmailSendingIdentityDto` + `CompanyEmailProviderStatsDto` + `EmailDnsRecordDto` |
| 2 | `Pss2.0_Frontend/src/infrastructure/gql-queries/notify-queries/CompanyEmailProviderQuery.ts` | Add `COMPANY_EMAIL_PROVIDER_ACTIVE_QUERY` + `COMPANY_EMAIL_PROVIDER_STATS_QUERY` + `SENDING_DOMAIN_DNS_RECORDS_QUERY`; extend existing by-id query with children + new fields |
| 3 | `Pss2.0_Frontend/src/infrastructure/gql-mutations/notify-mutations/CompanyEmailProviderMutation.ts` | Add `SAVE_COMPANY_EMAIL_PROVIDER_MUTATION` (upsert) + `VERIFY_SENDING_DOMAIN_MUTATION` + `TEST_EMAIL_PROVIDER_CONNECTION_MUTATION` + 5 identity mutations (create/update/delete/setDefault/verify) |
| 4 | `Pss2.0_Frontend/src/application/configs/data-table-configs/notify-service-entity-operations.ts` | **RENAME gridCode** `"COMPANYEMAILPROVIDER"` → `"EMAILPROVIDERCONFIG"` (line 37). Remove Dtos/Mutations references for the old data-table flow (not used — single-page config doesn't read from this registry). **Keep the entry for backwards-compat of any lingering grid refs**; flag the entry with a `// TODO: unused — kept for registry contract` comment. |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Pss2.0_Frontend/src/presentation/pages/setting/communicationconfig/index.ts` | `export { EmailProviderConfigPageConfig } from "./emailproviderconfig";` — replace `//EntityPageConfigExport` placeholder |
| 2 | Sidebar config / menu route auto-derives from seeded menu | Ensure `setting/communicationconfig/emailproviderconfig` renders the page — verify after DB seed |
| 3 | `Pss2.0_Frontend/src/presentation/pages/crm/communication/index.ts` | REMOVE `export { CompanyEmailProviderPageConfig }` line (it was wrong module) |
| 4 | DTO barrel (`notify-service/index.ts` if exists) | Add new dto exports for EmailSendingIdentityDto etc. |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.
> **IMPORTANT**: Menu already seeded in `Pss2.0_Global_Menus_List.sql:468` — seed script adds ONLY GridCode rename + MasterData typeCodes. **Do NOT** re-seed the menu row.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Email Provider Config
MenuCode: EMAILPROVIDERCONFIG
ParentMenu: SET_COMMUNICATIONCONFIG
Module: SETTING
MenuUrl: setting/communicationconfig/emailproviderconfig
GridType: FLOW

MenuCapabilities: READ, MODIFY, ISMENURENDER
(no CREATE — single record per Company; no DELETE — use deactivate instead; no TOGGLE — IsDefault flip replaces toggle semantics; no IMPORT/EXPORT)

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY

GridFormSchema: SKIP
GridCode: EMAILPROVIDERCONFIG

(Note: Old GridCode was COMPANYEMAILPROVIDER — rename in notify-service-entity-operations.ts + any Grid table row. Menu row already seeded under SET_COMMUNICATIONCONFIG at line 468 of Pss2.0_Global_Menus_List.sql — do NOT re-insert.)
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `CompanyEmailProviderQueries` (existing — extend)
- Mutation type: `CompanyEmailProviderMutations` (existing — extend)

**Queries** (existing + new):
| GQL Field | Returns | Key Args | Status |
|-----------|---------|----------|--------|
| companyEmailProviders | Paginated<CompanyEmailProviderResponseDto> | searchTerm, pageIndex, pageSize, sortColumn, sortDescending, advancedFilter | KEEP (legacy — admin UX may list all provider configs if multi-provider supported later) |
| companyEmailProviderById | CompanyEmailProviderResponseDto | companyEmailProviderId | MODIFY — add Include(SendingIdentities) |
| **activeCompanyEmailProvider** | CompanyEmailProviderResponseDto | (none — uses HttpContext CompanyId) | NEW |
| **emailProviderStats** | CompanyEmailProviderStatsDto | companyEmailProviderId | NEW (SERVICE_PLACEHOLDER) |
| **sendingDomainDnsRecords** | [EmailDnsRecordDto] | companyEmailProviderId | NEW (SERVICE_PLACEHOLDER) |

**Mutations** (existing + new):
| GQL Field | Input | Returns | Status |
|-----------|-------|---------|--------|
| createCompanyEmailProvider | CompanyEmailProviderRequestDto | CompanyEmailProviderResponseDto | KEEP (legacy) |
| updateCompanyEmailProvider | CompanyEmailProviderRequestDto | CompanyEmailProviderResponseDto | KEEP |
| deleteCompanyEmailProvider | int | bool | KEEP |
| activateDeactivateCompanyEmailProvider | int | bool | KEEP |
| **saveCompanyEmailProvider** | CompanyEmailProviderRequestDto (with SendingIdentities[]) | CompanyEmailProviderResponseDto | NEW — upsert, diffs children |
| **verifySendingDomain** | companyEmailProviderId: int | bool (SERVICE_PLACEHOLDER success) | NEW |
| **testEmailProviderConnection** | companyEmailProviderId: int | string (mock result message) | NEW |
| **createSendingIdentity** | EmailSendingIdentityRequestDto | EmailSendingIdentityResponseDto | NEW |
| **updateSendingIdentity** | EmailSendingIdentityRequestDto | EmailSendingIdentityResponseDto | NEW |
| **deleteSendingIdentity** | int | bool | NEW |
| **setDefaultSendingIdentity** | int | bool | NEW — flips IsDefault flag in transaction |
| **verifySendingIdentity** | int | bool (SERVICE_PLACEHOLDER) | NEW |

**Response DTO Fields** (CompanyEmailProviderResponseDto — FE receives):
| Field | Type | Notes |
|-------|------|-------|
| companyEmailProviderId | number | PK |
| companyId | number | Tenant |
| emailProviderId | number | FK |
| emailProvider | { dataName, dataCode } | Expanded FK display (dataCode drives card icon lookup) |
| emailProviderTypeId | number | FK (typically 'Transactional') |
| emailProviderType | { dataName } | Expanded FK display |
| priority | number | — |
| providerConfiguration | string (JSON) | Encrypted blob — FE parses to extract smtpHost/port/etc. for SMTP card |
| apiRegion | string (nullable) | — |
| trackingEventsCsv | string (nullable) | FE splits/joins CSV for 6 checkboxes |
| hourlyEmailLimit | number (nullable) | — |
| dailyEmailLimit | number (nullable) | — |
| monthlyEmailLimit | number (nullable) | — |
| ratePerSecond | number (nullable) | NEW |
| defaultFromEmail | string (nullable) | — |
| defaultFromName | string (nullable) | — |
| sendingDomainName | string (nullable) | NEW |
| domainStatus | string (nullable) | NEW — "Pending"/"Verified"/"Failed" |
| domainVerifiedAt | string (ISO, nullable) | NEW |
| sendingIp | string (nullable) | NEW |
| webhookUrl | string (nullable) | — |
| webhookSecret | string (nullable) | — |
| costPerEmail | number (nullable) | — |
| currencyId | number (nullable) | — |
| currency | { currencyName, currencyCode } | Expanded |
| isDefault | boolean | NEW |
| lastEmailSentAt | string (ISO, nullable) | NEW |
| ipReputationScore | number (nullable) | NEW — SERVICE_PLACEHOLDER |
| domainReputationScore | number (nullable) | NEW — SERVICE_PLACEHOLDER |
| bounceRate | number (nullable) | NEW — SERVICE_PLACEHOLDER |
| spamRate | number (nullable) | NEW — SERVICE_PLACEHOLDER |
| sendingIdentities | EmailSendingIdentityResponseDto[] | NEW child collection |
| isActive | boolean | Inherited |
| createdDate / modifiedDate / createdBy / modifiedBy | — | Inherited |

**EmailSendingIdentityResponseDto fields**:
| Field | Type | Notes |
|-------|------|-------|
| emailSendingIdentityId | number | PK |
| companyEmailProviderId | number | FK |
| fromName | string | — |
| fromEmail | string | — |
| replyToEmail | string (nullable) | — |
| isDefault | boolean | — |
| isVerified | boolean | — |
| verifiedAt | string (ISO, nullable) | — |
| isActive | boolean | Inherited |

**CompanyEmailProviderStatsDto fields** (all SERVICE_PLACEHOLDER — mocked):
| Field | Type | Notes |
|-------|------|-------|
| dailyUsageCount | number | Emails sent today |
| monthlyUsageCount | number | Emails sent this month |
| dailyUsagePercentage | number | dailyUsageCount / dailyEmailLimit × 100 |
| monthlyUsagePercentage | number | monthlyUsageCount / monthlyEmailLimit × 100 |
| ipReputationScore | number | Echoed from snapshot |
| domainReputationScore | number | Echoed from snapshot |
| bounceRate | number | Echoed |
| spamRate | number | Echoed |
| lastEmailSentAt | string (ISO, nullable) | Echoed |

**EmailDnsRecordDto fields**:
| Field | Type | Notes |
|-------|------|-------|
| recordType | string | CNAME / TXT / MX |
| recordName | string | FQDN |
| recordValue | string | Target value |
| isVerified | boolean | — |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (expect 13 new EF property warnings cleared by configuration file)
- [ ] EF migration generated and applies cleanly against an empty DB + an existing DB with seeded rows
- [ ] `pnpm dev` — page loads at `/{lang}/setting/communicationconfig/emailproviderconfig`
- [ ] Sidebar: "Email Provider Config" menu item visible under Setting → Communication Config

**Functional Verification (Full E2E — MANDATORY):**
- [ ] First-time user (no CompanyEmailProvider row for tenant): page loads, status banner shows "Not configured", all form fields empty, Save disabled until EmailProviderId + basic fields set
- [ ] Provider card selection: click SendGrid card → radio-dot + accent border appear; click AWS SES → SendGrid de-selects, AWS selects
- [ ] Select Custom SMTP: API Settings card + Sending Domain card hide; SMTP Configuration card appears below Reputation card
- [ ] Select SendGrid again: API Settings + Sending Domain return; SMTP card hides
- [ ] API Key Show/Hide toggle works; Show icon flips eye ↔ eye-slash; input type changes password ↔ text
- [ ] API Region dropdown shows Global + EU
- [ ] Webhook URL readonly box rendered; Copy button → clipboard contains URL; button shows green "Copied!" for 2s then reverts
- [ ] 6 Events Tracked checkboxes round-trip to TrackingEventsCsv ("Delivered,Opened,..." CSV)
- [ ] Sending Domain: domain name displayed with verified green badge when DomainStatus='Verified'
- [ ] Verify Domain button → SERVICE_PLACEHOLDER mock delay → DomainStatus='Verified', verified badge + timestamp refresh
- [ ] DNS records table shows 4 rows (SERVICE_PLACEHOLDER sample)
- [ ] Sending Identities table loads rows for this provider
- [ ] +Add Sending Identity → modal → fill form → Save → new row appended
- [ ] Edit identity → modal pre-filled → Save → row updates
- [ ] ⋯ menu → Set Default → confirm → default badge moves to clicked row, other rows lose default
- [ ] ⋯ menu → Delete on non-default → confirm → row removed
- [ ] ⋯ menu → Delete on default → error "Cannot delete default identity"
- [ ] FromEmail domain mismatch with SendingDomainName → validation error on save
- [ ] Sending Limits: 3 numeric inputs accept values; HTML5 number constraints respected
- [ ] Usage bars render with SERVICE_PLACEHOLDER values + color-coded (green <75%, amber 75-90%, red >90%)
- [ ] Reputation: 5 stat cards render with dots (green/yellow/red) + score values
- [ ] SMTP Configuration card: Host, Port (dropdown 25/465/587/2525), Encryption (None/SSL-TLS/STARTTLS), Auth (PLAIN/LOGIN/CRAM-MD5), Username, Password + Show/Hide
- [ ] SMTP Test Connection → SERVICE_PLACEHOLDER → spinner → green check "Connection successful" after 1.5s
- [ ] Bottom Save Configuration → upsert succeeds → toast "Configuration saved" → page reloads with fresh data
- [ ] Bottom Test Connection (for cloud providers) → SERVICE_PLACEHOLDER → inline result
- [ ] Header Send Test Email → modal with To Email + Message → Send → SERVICE_PLACEHOLDER toast
- [ ] Header View Delivery Logs → SERVICE_PLACEHOLDER toast (or navigate to EmailAnalytics route if present)
- [ ] Unsaved changes dialog appears when navigating away with dirty form
- [ ] Permissions: BUSINESSADMIN sees page and can Save; non-BUSINESSADMIN user sees Access Denied via `DefaultAccessDenied`
- [ ] Refresh page → state rehydrates from `activeCompanyEmailProvider` query

**DB Seed Verification:**
- [ ] Menu EMAILPROVIDERCONFIG appears in sidebar under Setting → Communication Config (already seeded — verify present)
- [ ] MasterData typeCode EMAILPROVIDER seeded with 4 rows: SendGrid / Mailgun / AWS SES / Custom SMTP (DataCode: SENDGRID, MAILGUN, AWSSES, SMTP)
- [ ] MasterData typeCode EMAILPROVIDERTYPE seeded with 2 rows: Transactional / Marketing
- [ ] GridFormSchema is SKIP (custom UI — no RJSF)
- [ ] Grid row seed (optional): if Grid table requires an entry for GridCode=EMAILPROVIDERCONFIG, insert FLOW-type placeholder; else SKIP
- [ ] Old GridCode `COMPANYEMAILPROVIDER` renamed in-DB to `EMAILPROVIDERCONFIG` via idempotent UPDATE (if Grid row exists)
- [ ] Legacy menu `Pss2.0_Old_Menu_List.sql:96` (`COMPANYEMAILPROVIDER` under MenuId 121) flagged as deprecated — NOT active; do NOT re-seed
- [ ] MenuCapabilities row seeded for EMAILPROVIDERCONFIG: READ + MODIFY only (no CREATE/DELETE/IMPORT/EXPORT)
- [ ] RoleCapabilities for BUSINESSADMIN: READ, MODIFY

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

### Module / Path Gotchas
- **ALIGN rename — this is the FIRST screen in Setting → Communication Config module**. No existing FE structure at `setting/communicationconfig/`. Verify that the sidebar route resolver picks up `setting/communicationconfig/emailproviderconfig` (the `Pss2.0_Global_Menus_List.sql:468` seed provides the menu; route resolver expects a page-config export in `setting/communicationconfig/index.ts`). **Do NOT hack a CRM-module path** — follow the canonical Setting module path per `MODULE_MENU_REFERENCE.md`.
- **The existing FE code was mis-located** in `crm/communication/companyemailprovider` — this was orphan (no route, no sidebar entry). DELETE that path entirely. Do not re-wire.
- **GridCode rename**: existing code uses `COMPANYEMAILPROVIDER`. Registry source of truth (`MODULE_MENU_REFERENCE.md`) says `EMAILPROVIDERCONFIG`. Rename in all references. Keep backward-compat DB UPDATE in seed (idempotent).

### FLOW Pattern Deviation
- **This is NOT a standard FLOW screen**. Registry type=FLOW because it's under the `notify` schema and uses FlowDataTable-grid precedent for the legacy CRUD commands. But the mockup is a **single-record config page** — no grid, no view-page.tsx, no `?mode=new/edit/read` URL switching. Use NotificationCenter #35 as the precedent (custom page, `<ScreenHeader>` + custom body, no `<FlowDataTable>`, no Zustand grid store).
- Do NOT generate `view-page.tsx` with 3 URL modes. Do NOT generate `store.ts` (Zustand grid store). The single config page needs only React Hook Form + local `useState` for UI toggles + RTK/Apollo cache for data.
- Keep the legacy `companyEmailProviders` paginated query + create/update/delete mutations — BE continues to support multi-provider-per-Company as future extension. FE MVP uses only `activeCompanyEmailProvider` + `saveCompanyEmailProvider`.

### Schema Decisions
- `ProviderConfiguration` stays as an encrypted JSON blob (not normalized to first-class columns) because provider-specific fields vary heavily (SendGrid `apiKey` vs SMTP `host+port+encryption+auth+username+password`). Keep schema polymorphic; validate shape per `EmailProvider.DataCode` in the validator.
- 13 fields hoisted to first-class columns are those shared across ALL providers and used in UI for filtering/listing/reputation display. Provider-specific secrets/tokens stay in the JSON blob.
- `EmailSendingIdentity` modeled as a child table (not JSON array in ProviderConfiguration) because rows are independently verifiable, mutable, and uniqueness-constrained.
- SMTP password encryption: use repository-standard secret cipher (check `IEncryptionService` or equivalent — if absent, flag as ISSUE for follow-up; MVP: store base64-encoded as placeholder with `// TODO: encrypt` comment).

### Service Dependencies

Everything in the mockup is in scope and fully built as UI. Backend handlers for the following external-service calls return mocked success payloads and are labeled SERVICE_PLACEHOLDER — full UI still implemented:

- **SERVICE_PLACEHOLDER: VerifySendingDomain** — no SendGrid/Mailgun/AWS SDK integration yet. Handler flips `DomainStatus='Verified'` + `DomainVerifiedAt=UtcNow` after a 1.5s artificial delay. Real impl will call `sendgrid.whitelabel.domains.validate(domainId)` (or Mailgun/AWS equivalents) and parse the response.
- **SERVICE_PLACEHOLDER: TestEmailProviderConnection** — no real HTTP health-check. Handler returns `"Connection successful"` after mock delay. Real impl will call provider's `/me` or `/account` endpoint with the stored API key.
- **SERVICE_PLACEHOLDER: VerifySendingIdentity** — no real "Click the link in your inbox" flow. Handler flips `IsVerified=true`. Real impl will send an SDK-provider-specific verification email and mark verified on webhook callback.
- **SERVICE_PLACEHOLDER: SendTestEmail (header button)** — no real email dispatch. Handler logs "would send" and returns success. Real impl uses the active provider's send endpoint.
- **SERVICE_PLACEHOLDER: GetSendingDomainDnsRecords** — handler returns 4 hardcoded sample rows (derived from SendGrid's typical CNAME+TXT shape). Real impl calls provider's DNS-setup-status endpoint.
- **SERVICE_PLACEHOLDER: GetEmailProviderStats** — handler returns mocked constants (dailyUsageCount=1234, monthlyUsageCount=28456, ipReputationScore=98, domainReputationScore=96, bounceRate=0.8, spamRate=0.02). Real impl aggregates from EmailSendQueue delivery events + calls provider reputation endpoints.
- **SERVICE_PLACEHOLDER: SecretEncryption** — provider API keys and SMTP passwords stored base64-encoded with `// TODO: encrypt` marker. Pending integration of a repository-standard `IEncryptionService`.

### ALIGN-scope caveats
- Do NOT regenerate BE CRUD files from scratch. MODIFY existing entity + configuration + schemas + commands + queries in-place. See §⑧ "MODIFY existing" table for the exact edit scope.
- Do NOT create a new `PlaceholderDefinitionDataTable`-style wrapper. Delete the old one.
- EF snapshot must be regenerated after migration — call out to user in build output.
- If MasterData typeCodes EMAILPROVIDER + EMAILPROVIDERTYPE are already seeded (grep `sql-scripts-dyanmic/*.sql`) use idempotent `ON CONFLICT DO UPDATE` to avoid duplicates.

### Cross-Screen Dependencies
- **EmailSendJob #25** (Email Campaign): reads the active CompanyEmailProvider + default SendingIdentity at dispatch time. Campaign's "From Name" / "From Email" dropdowns should source from THIS screen's identities. Flag as follow-up wiring.
- **EmailTemplate #24**: already completed. Its FromEmail test-send flow should use the active provider/identity. Minor touch-up post-#28 build.
- **EmailAnalytics #41** (not yet built): the header "View Delivery Logs" button will route here when available.

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

{No sessions recorded yet — filled in after /build-screen completes.}