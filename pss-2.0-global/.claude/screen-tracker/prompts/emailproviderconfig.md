---
screen: CompanyEmailProvider
display_name: Email Provider Config
registry_id: 84
module: Setting (Communication Configuration)
status: COMPLETED
scope: ALIGN
screen_type: CONFIG
config_subtype: SETTINGS_PAGE
storage_pattern: singleton-per-tenant
save_model: save-all
complexity: Medium
new_module: NO
planned_date: 2026-05-10
completed_date: 2026-05-15
last_session_date: 2026-05-28
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type identified: SETTINGS_PAGE)
- [x] Business context read (tenant email provider; one config per Company; downstream of every notification flow)
- [x] Storage model identified (singleton-per-tenant — `notify."CompanyEmailProviders"`, one ACTIVE row per CompanyId via filtered-unique `IsDefault=true AND IsDeleted=false`)
- [x] Save model chosen (save-all — single sticky-footer button matches mockup; child grid `Sending Identities` saves per-row through dedicated mutations)
- [x] Sensitive fields & role gates identified (API Key + SMTP Password embedded in `ProviderConfiguration` JSON; WebhookSecret column; BUSINESSADMIN-only)
- [x] FK targets resolved
- [x] File manifest computed (BE+FE both EXIST — ALIGN delta only)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (tenant-scoped email provider; transactional vs marketing stream; sensitive credential handling; Send Test Email + Verify Domain are SERVICE_PLACEHOLDERs)
- [x] Solution Resolution complete (sub-type SETTINGS_PAGE confirmed, save model save-all confirmed)
- [x] UX Design finalized (7-card vertical-stack — see §⑥)
- [x] User Approval received
- [x] Backend code aligned — ISSUE-3 patches applied (mask read; preserve on save)
- [x] Backend wiring verified (no changes — pre-existing)
- [x] Frontend code aligned — ISSUE-1 + ISSUE-2 patches applied (webhook always-visible; provider-switch warning)
- [x] Frontend wiring verified (no changes — pre-existing)
- [x] DB Seed updated — ISSUE-5 GridType FLOW→CONFIG with backfill (idempotent)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/{lang}/setting/communicationconfig/emailproviderconfig`
- [ ] **SETTINGS_PAGE sub-type checks**:
  - [ ] First-load auto-fetches active provider (or returns null cleanly when none configured)
  - [ ] All 7 cards render in correct order (Status Banner → Provider Selection → API Settings → Sending Domain → Sending Identities → Sending Limits → IP & Reputation → SMTP Configuration)
  - [ ] Card 2 (API Settings) only renders when a CLOUD provider is selected (SendGrid/Mailgun/AWSSES)
  - [ ] Card 3 (Sending Domain) only renders for CLOUD providers
  - [ ] Card 7 (SMTP Configuration) only renders when Custom SMTP is selected
  - [ ] Cards 1 / 5 / 6 (Provider Selection / Sending Limits / IP & Reputation) ALWAYS render
  - [ ] Single "Save Configuration" sticky-footer button persists all sections
  - [ ] Validation errors block save and surface inline per field
  - [ ] API Key masked-by-default (toggleable via eye icon); SMTP Password masked likewise
  - [ ] Sensitive-field empty submit ⇒ unchanged; non-empty ⇒ overwrites (BE patch — see ISSUE-3)
  - [ ] Read-only stat tiles (Sending IP / Reputation / Bounce / Spam) render disabled and never POST
  - [ ] "Test Connection" handler triggers SERVICE_PLACEHOLDER toast (per existing BE)
  - [ ] "Send Test Email" header button → SERVICE_PLACEHOLDER toast
  - [ ] "View Delivery Logs" header button → navigates to or toasts placeholder
  - [ ] "Verify Domain" button calls VerifySendingDomainCommand and updates `domainStatus` to "Verified"
  - [ ] DNS Records table renders all rows returned by GetSendingDomainDnsRecords
  - [ ] Sending Identities CRUD: Add / Edit / Delete / Set Default works through dedicated mutations
  - [ ] Cannot delete the default Sending Identity (current FE guard already in place)
  - [ ] Webhook URL ALWAYS visible (FE gap — see ISSUE-1)
  - [ ] BUSINESSADMIN role required to view; non-privileged roles see access-denied (existing `useAccessCapability` already handles this)
  - [ ] Unsaved-changes `beforeunload` warning fires on dirty navigation
- [ ] Empty / loading / error states render
- [ ] DB Seed — menu visible at `setting/communicationconfig/emailproviderconfig` under SET_COMMUNICATIONCONFIG → already wired

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: CompanyEmailProvider (display name "Email Provider Config")
Module: Setting / Communication Configuration
Schema: `notify`
Group: Notify (NotifyBusiness, NotifyModels, NotifySchemas, NotifyConfigurations)

Business: This screen lets a tenant administrator pick the email-delivery provider that PSS will use for **every transactional and marketing email** the platform sends — receipts, donor acknowledgements, password resets, campaign blasts, P2P-fundraiser confirmations, prayer-request alerts, etc. The same UI is reachable from `setting/communicationconfig/emailproviderconfig` and from a deep-link inside the Communication Provider Health dashboard widget. Edited rarely (typically once at onboarding, then revisited only when rotating credentials, switching providers, or registering a new sending identity), but **catastrophic if mis-set**: missing/wrong credentials silently break every notification path in the platform — donors stop getting receipts, campaigns stop sending, password-reset emails never arrive. The four supported providers (SendGrid, Mailgun, AWS SES, Custom SMTP) cover the spectrum from highest-deliverability cloud APIs to fully self-hosted SMTP for on-prem deployments. SendGrid/Mailgun/AWSSES use API-key auth + a webhook-receiving endpoint to track deliverability events; SMTP uses host/port/username/password. Domain verification + DNS records (SPF/CNAME/DKIM) gate domain reputation — without these, providers downrate the tenant. The screen also exposes admin-controlled rate limits (daily / hourly / per-second) that act as the platform's outbound throttle, plus a managed list of "Sending Identities" — verified `From Name + From Email + Reply-To` triplets that downstream Email Templates must reference (a tenant typically registers one for general use, one for fundraising, one for events). Read-only IP & Reputation tiles surface deliverability health pulled from the provider's API. **Unique UX vs a generic settings page**: provider choice drives **conditional sections** (cloud-providers reveal API Settings + Sending Domain + DNS records; SMTP reveals an SMTP card and hides the API/Domain blocks); the page combines a singleton-per-tenant parent (the provider config row) with a 1:Many child grid (Sending Identities); and it has BOTH read-only system-populated state (DNS verification, IP reputation) AND admin-edited state in the same surface.

> **Why this section is heavier than other types**: CONFIG screens have no canonical layout —
> the design is derived from the business case. The richer §① is, the better the developer
> can design the right §⑥ blueprint.

---

## ② Storage Model

> **Consumer**: BA Agent → Backend Developer

**Storage Pattern**: `singleton-per-tenant` (with 1:Many child grid for Sending Identities)

The existing data model has been in place since `Screen #28 CompanyEmailProvider — ALIGN (2026-04-24)`. Don't recreate — verify only.

### Tables

Primary table: `notify."CompanyEmailProviders"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CompanyEmailProviderId | int | — | PK | — | identity |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (NOT a form field — set from HttpContext) |
| EmailProviderId | int | — | YES | sett.MasterDatas (TypeCode=EMAILPROVIDER) | brand: SENDGRID / MAILGUN / AWSSES / SMTP |
| EmailProviderTypeId | int | — | YES | sett.MasterDatas (TypeCode=EMAILPROVIDERTYPE) | TRANSACTIONAL / MARKETING |
| Priority | int? | — | no | — | reserved for multi-provider routing |
| ProviderConfiguration | string | — | YES | — | JSON blob — `{apiKey, apiRegion}` for cloud OR `{smtpHost,smtpPort,encryption,authMethod,username,password}` for SMTP. **Currently returned RAW in GetActiveCompanyEmailProvider — see §⑫ ISSUE-3** |
| HourlyEmailLimit | int? | — | no | — | rate limit |
| DailyEmailLimit | int? | — | no | — | rate limit |
| MonthlyEmailLimit | int? | — | no | — | rate limit |
| RatePerSecond | int? | — | no | — | rate limit (added in #28 ALIGN) |
| DefaultFromEmail | string? | 100 | no | — | fallback when no Sending Identity selected |
| DefaultFromName | string? | 100 | no | — | fallback display name |
| WebhookUrl | string? | 1000 | no | — | provider→PSS webhook target (often auto-derived) |
| WebhookSecret | string? | 1000 | no | — | HMAC signing secret. **SENSITIVE — see §④** |
| CostPerEmail | decimal? | (10,4) | no | — | per-tenant negotiated rate |
| CurrencyId | int? | — | no | corg.Currencies | currency of CostPerEmail |
| ApiRegion | string? | 20 | no | — | "Global" / "EU" / "us-east-1" / etc. |
| TrackingEventsCsv | string? | 500 | no | — | comma-separated subset of `Delivered,Opened,Clicked,Bounced,SpamReport,Unsubscribed` |
| SendingDomainName | string? | 255 | no | — | e.g. `mail.{tenant}.org` |
| DomainStatus | string? | 30 | no | — | "Verified" / "Pending" / "Failed" |
| DomainVerifiedAt | DateTime? | — | no | — | timestamp of last successful verify |
| SendingIp | string? | 45 | no | — | IPv4/IPv6 — populated by provider API on read |
| IsDefault | bool | — | YES | — | filtered-unique with IsDeleted=false ensures one ACTIVE row per tenant |
| LastEmailSentAt | DateTime? | — | no | — | populated by webhook listener |
| IpReputationScore | int? | — | no | — | 0-100, polled from provider API |
| DomainReputationScore | int? | — | no | — | 0-100 |
| BounceRate | decimal(5,2)? | — | no | — | percent |
| SpamRate | decimal(5,2)? | — | no | — | percent |

**Singleton constraint** (existing — verify):
- Filtered unique index on `(CompanyId)` where `IsDefault = true AND IsDeleted = false` — exactly one ACTIVE row per tenant
- Unique index on `(CompanyId, EmailProviderId, EmailProviderTypeId, IsActive)` — supports historical rows
- First-load behavior: `GetActiveCompanyEmailProvider` returns null if no row exists (FE handles "Not configured" banner)

**Child Tables** — `notify."EmailSendingIdentities"`:
| Field | C# Type | MaxLen | Required | Notes |
|-------|---------|--------|----------|-------|
| EmailSendingIdentityId | int | — | PK | identity |
| CompanyEmailProviderId | int | — | YES | FK to parent (cascade delete) |
| FromName | string | 100 | YES | display name |
| FromEmail | string | 255 | YES | must match `SendingDomainName` |
| ReplyToEmail | string? | 255 | no | — |
| IsDefault | bool | — | YES | exactly one TRUE per CompanyEmailProviderId via filtered unique |
| IsVerified | bool | — | YES | platform/provider-side verification flag |

**No new entity needed** — both tables exist (EF migrations already applied per #28).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer + Frontend Developer

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| EmailProviderId | MasterData | `Base.Domain/Models/SettingModels/MasterData.cs` | `masterDatasByTypeCode(typeCode: "EMAILPROVIDER")` | DataName | `MasterDataResponseDto[]` |
| EmailProviderTypeId | MasterData | `Base.Domain/Models/SettingModels/MasterData.cs` | `masterDatasByTypeCode(typeCode: "EMAILPROVIDERTYPE")` | DataName | `MasterDataResponseDto[]` |
| CurrencyId | Currency | `Base.Domain/Models/CorgModels/Currency.cs` | `getAllCurrencyList` | CurrencyCode | `CurrencyResponseDto[]` |
| CompanyId | Company | `Base.Domain/Models/CorgModels/Company.cs` | (NOT a form field — HttpContext) | — | — |

**Existing FE GQL query for provider cards** (already wired): `MasterDatasByTypeCode($typeCode: "EMAILPROVIDER")` — `provider-card-selector.tsx` line 10-18.

**Read-only sources** (no FK — populated via SERVICE_PLACEHOLDER handlers):
- `SendingIp` / `IpReputationScore` / `DomainReputationScore` / `BounceRate` / `SpamRate` — all returned by `GetCompanyEmailProviderStats(companyEmailProviderId)` → `CompanyEmailProviderStatsDto`. Currently the BE handler returns hardcoded values; future work to call provider APIs.
- DNS records — `GetSendingDomainDnsRecords(companyEmailProviderId)` → `EmailDnsRecordDto[]`. Currently returns hardcoded SPF/CNAME/DKIM rows for the configured `SendingDomainName`; future work to query provider API.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Singleton / Cardinality Rules:**
- Exactly **one ACTIVE provider row per tenant** (filtered unique on `(CompanyId)` where `IsDefault=true AND IsDeleted=false`).
- `Save` mutation upserts: existing-row update OR new-row insert+set-default+soft-delete-prior. Existing handler `SaveCompanyEmailProvider.cs` implements this.
- Switching providers (e.g. SendGrid → Mailgun): the old row is soft-deleted, new row inserted with `IsDefault=true`. Sending Identities cascade with the new row (NOT migrated automatically — this is a deliberate design choice; identity verification is provider-side and re-verification is required).
- Multiple Sending Identities per CompanyEmailProvider; exactly one `IsDefault=true`.

**Required Field Rules** (per provider mode):

CLOUD providers (SendGrid / Mailgun / AWSSES):
- `EmailProviderId` (radio-card pick) — REQUIRED
- `apiKey` (inside ProviderConfiguration JSON) — REQUIRED
- `apiRegion` — defaulted to "Global"
- `SendingDomainName` — REQUIRED before any Sending Identity can be created
- All limits/throttles — optional

CUSTOM SMTP:
- `EmailProviderId` = SMTP — REQUIRED
- `smtpHost`, `smtpPort`, `username`, `password` (inside ProviderConfiguration JSON) — REQUIRED (mockup shows asterisks)
- `encryption`, `authMethod` — defaulted (STARTTLS, LOGIN)
- Sending Domain card hidden — SMTP relies on the SMTP server's own domain handling

**Conditional Rules:**
- `apiRegion` is sent on Save **only when** a cloud provider is selected (FE clears when switching to SMTP).
- `Sending Identities` card shows empty state with hint "Save configuration first to manage identities" until a `CompanyEmailProviderId` exists. This is by design — child rows need a parent FK.
- `Verify Domain` button is disabled until configuration is saved (needs `companyEmailProviderId`).
- `Test Connection` button is disabled until configuration is saved.

**Sensitive Fields** (masking, audit, role-gating):

| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| `apiKey` (in `ProviderConfiguration` JSON) | secret | masked input + eye-toggle (FE done) | currently raw round-trip — see ISSUE-3 | not yet logged — see ISSUE-4 |
| `password` (in `ProviderConfiguration` JSON, SMTP only) | secret | masked input + eye-toggle (FE done) | currently raw round-trip — see ISSUE-3 | not yet logged — see ISSUE-4 |
| `WebhookSecret` (column) | secret | not surfaced in mockup; backend column | not edited via this screen; populated by webhook subscription action | n/a |

**Read-only / System-controlled Fields:**
- `SendingIp`, `IpReputationScore`, `DomainReputationScore`, `BounceRate`, `SpamRate`, `LastEmailSentAt`, `DomainStatus`, `DomainVerifiedAt` — populated by handlers, never POSTed via Save.
- DNS records list — pulled by `GetSendingDomainDnsRecords` query, never editable.

**Dangerous Actions** (require confirm + audit):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Switch Provider (SendGrid → Mailgun) | Soft-deletes prior row, invalidates identity verifications | Implicit on Save (new EmailProviderId) — **add explicit warning modal — see ISSUE-2** | log "provider switched: from→to" |
| Save with new credentials | Overwrites apiKey/password | (no confirm — relies on save button) | log "credential rotated" — see ISSUE-4 |
| Delete Sending Identity | Removes from-name registration | `confirm("Delete identity \"{email}\"?")` (existing) | inherited from base entity audit |
| Set Default Sending Identity | Changes default-from across all templates | (no confirm) | inherited audit |

**Role Gating:**

| Role | Access | Notes |
|------|--------|-------|
| BUSINESSADMIN | full read+write | only role with `EMAILPROVIDERCONFIG.MODIFY` |
| All other roles | none | route guarded by `useAccessCapability({menuCode:"EMAILPROVIDERCONFIG"})` — returns DefaultAccessDenied |

**Workflow**: None. CONFIG is single-mode. No draft/publish.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: CONFIG
**Config Sub-type**: `SETTINGS_PAGE`
**Storage Pattern**: `singleton-per-tenant` (parent) + 1:Many child grid (Sending Identities)
**Save Model**: `save-all` (single sticky-footer "Save Configuration" button persists the parent record + the in-memory child rows array; standalone identity CRUD mutations also exist for inline row actions)

**Reason**: The mockup shows a singular `<div class="action-bar">` at the bottom with one "Save Configuration" primary button, not per-card save buttons. Cards 1/2/4/5/7 belong logically to one configuration record; the user typically edits multiple cards in a single session before saving. Sending Identities (Card 4) breaks the rule — it has its own "+Add Sending Identity" / Edit / Delete row actions wired to dedicated BE mutations, because identity verification is asynchronous and per-row. The reconciliation: Save persists the parent + the identities list as currently rendered; row actions persist the individual identity immediately. SMS Setup #157 chose `save-per-section`, which is a defensible alternative — but the email mockup's visual signal (one bottom button vs SMS Setup's per-card save buttons) drives this divergence.

**Backend Patterns Required:**

For SETTINGS_PAGE (singleton-per-tenant) — **all already exist**:
- [x] `GetActiveCompanyEmailProvider` query — fetches by tenant from HttpContext, returns null when no row exists (FE handles empty state)
- [x] `SaveCompanyEmailProvider` mutation — upserts (Create OR Update OR Switch-Provider), accepts `Sending Identities` array for cascade-update
- [x] `Update`, `Create`, `Delete`, `ActivateDeactivate` legacy mutations — kept for registry contract; **NOT used by this screen**
- [x] `VerifySendingDomain` mutation — currently SERVICE_PLACEHOLDER (auto-marks Verified)
- [x] `TestEmailProviderConnection` mutation — currently SERVICE_PLACEHOLDER (returns "Connection successful")
- [x] `GetCompanyEmailProviderStats` query — returns usage + reputation snapshot (currently hardcoded; future: provider API call)
- [x] `GetSendingDomainDnsRecords` query — returns required DNS rows (currently hardcoded based on SendingDomainName)
- [x] `CreateSendingIdentity` / `UpdateSendingIdentity` / `DeleteSendingIdentity` / `SetDefaultSendingIdentity` / `VerifySendingIdentity` — child grid CRUD
- [x] Tenant scoping (CompanyId from HttpContext)
- [ ] **Sensitive-field handling** (mask `apiKey`/`password` on read; write-only on save) — **GAP — see §⑫ ISSUE-3**
- [ ] **Audit-trail emission** for credential rotation — **GAP — see §⑫ ISSUE-4**
- [x] No Reset/Regenerate (mockup doesn't ask for them — out of scope)

**Frontend Patterns Required:**

For SETTINGS_PAGE — **mostly already exist**:
- [x] Custom multi-card vertical-stack page (NOT FlowDataTable, NOT view-page)
- [x] Conditional cards (API Settings / Sending Domain visible for cloud only; SMTP visible for SMTP only)
- [x] Status banner (success / warning / muted variants)
- [x] Provider card selector (4 cards, mock-MasterData-driven)
- [x] Masked password inputs with eye-toggle (API Key + SMTP Password)
- [x] Webhook URL display + copy-to-clipboard
- [x] Tracking events checkbox grid (6 events)
- [x] DNS records read-only table
- [x] Sending Identities child grid with Add / Edit / Delete / Set-Default
- [x] Sending Identity Add/Edit dialog (separate component)
- [x] Usage progress bars (daily + monthly)
- [x] Reputation stat tiles (5 metrics)
- [x] Sticky bottom action bar with Test Connection + Save Configuration
- [x] Unsaved-changes `beforeunload` warning
- [x] Dirty-state tracking
- [ ] **Webhook URL always-visible** — currently only renders when `form.webhookUrl` truthy (mockup expects always — **GAP — see §⑫ ISSUE-1**)
- [ ] **Provider-switch warning modal** — currently silent on EmailProviderId change (**GAP — see §⑫ ISSUE-2**)
- [ ] **Required-field asterisks consistent** — mockup shows asterisks on SMTP Host/Port/Username/Password; FE has them; verify Zod-level enforcement.

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer

### 🎨 Visual Uniqueness Rules

This screen has 7 distinct cards with **different visual weight** (mockup-driven):
1. **Card 1 (Provider Selection)** — hero card with 4 large radio-cards (220px min-width) selected via 2px-border highlight + filled radio dot. Branded provider icons (paper-plane / envelope-circle / aws / gear) on tinted backgrounds.
2. **Card 2 (API Settings)** — compact 2-column form for cloud providers; webhook box uses a code/monospace block with copy button.
3. **Card 3 (Sending Domain)** — hybrid (form input + verified-badge + read-only DNS records table); 2 secondary buttons in card header.
4. **Card 4 (Sending Identities)** — full-width data table with row actions (Edit + ⋯ menu); table header has "+ Add Sending Identity" CTA.
5. **Card 5 (Sending Limits & Throttling)** — 3-column compact number inputs (max-width 120px each) + two horizontal usage progress bars.
6. **Card 6 (IP & Reputation)** — 5-tile stat grid (read-only); each tile shows label + bold value + colored detail; reputation tiles have a colored dot indicator.
7. **Card 7 (SMTP Configuration)** — 3-row 2-column form, only visible for SMTP provider; inline "Test Connection" button + result message.

Section icons are semantic Phosphor icons (already implemented):
- Provider Selection → `ph:plug`
- API Settings → `ph:key`
- Sending Domain → `ph:globe`
- Sending Identities → `ph:user-tag`
- Sending Limits → `ph:gauge`
- IP & Reputation → `ph:shield-halved`
- SMTP Configuration → `ph:server`

Sensitive fields (API Key, SMTP Password) are visually distinct: monospace-feel password input with right-aligned eye-toggle button.

---

### 🅰️ Block A — SETTINGS_PAGE

#### Page Layout

**Container Pattern**: `vertical-stack` (7 cards stacked, each in a `<Card>` wrapper with consistent header chrome)

**Page Header**: `<ScreenHeader>` — title "Email Provider", description "Configure email service provider, sending domain, and delivery settings", icon `ph:envelope-simple`, header actions: `Send Test Email` (SERVICE_PLACEHOLDER) + `View Delivery Logs` (SERVICE_PLACEHOLDER → routes to email analytics).

**Page Body**: scrollable region with `max-w-5xl` centered container, 16px card spacing, padding-bottom 96px to clear sticky footer.

**Sticky Footer**: bottom action bar with two buttons — `Test Connection` (calls `TestEmailProviderConnection` mutation; disabled until saved) + `Save Configuration` (primary; disabled when not dirty or no provider selected).

#### Card Definitions (in order)

| # | Card Title | Icon | Visibility | Save Mode | Role Gate |
|---|-----------|------|-----------|-----------|-----------|
| — | (Status Banner — not a card) | success/warning/muted | always (after fetch) | — | — |
| 1 | Email Service Provider | ph:plug | always | save-all | BUSINESSADMIN |
| 2 | API Settings | ph:key | cloud providers only (SendGrid/Mailgun/AWSSES) | save-all | BUSINESSADMIN |
| 3 | Sending Domain | ph:globe | cloud providers only | save-all + per-action (Verify) | BUSINESSADMIN |
| 4 | Sending Identities | ph:user-tag | always (post-save only — child grid) | per-row (own mutations) | BUSINESSADMIN |
| 5 | Sending Limits & Throttling | ph:gauge | always | save-all | BUSINESSADMIN |
| 6 | IP & Reputation | ph:shield-halved | always (read-only) | n/a | BUSINESSADMIN |
| 7 | SMTP Configuration | ph:server | SMTP only | save-all | BUSINESSADMIN |

#### Field Mapping per Card

**Status Banner** (computed from form state — not a saved field):
| Variant | Trigger Condition | Color | Icon | Text |
|---------|------------------|-------|------|------|
| success | provider configured AND domain Verified AND at least 1 verified default identity AND last email sent < 24h ago | green | ph:check-circle | "Connected to {ProviderName} — Domain verified, last email sent {relative time}." |
| muted | provider configured AND no `lastEmailSentAt` | gray | ph:info | "Provider configured — send a test email to verify connectivity." |
| warning | otherwise | amber | ph:warning | "Not configured — Select a provider and verify your sending domain." |

**Card 1 — Email Service Provider**
| Field | Widget | Default | Validation | Sensitivity | Notes |
|-------|--------|---------|------------|-------------|-------|
| emailProviderId | radio-card grid (4 cards) | — | required | normal | populated from `masterDatasByTypeCode("EMAILPROVIDER")`; clicking a card sets `emailProviderId` AND `emailProviderDataValue` (used to gate conditional cards) |

Card 1 layout: 4 cards in a `xl:grid-cols-4 sm:grid-cols-2 grid-cols-1` grid. Each card shows: filled-circle radio dot (top-right), branded icon tile (48x48px rounded), provider name (bold), one-line description, monthly volume hint (tinted text). Visual states: default (border-border), hover (border-primary/50 + bg-primary/5), selected (border-primary + bg-primary/5 + shadow-sm). Mapping per provider via `provider-registry.ts`:

| dataValue | Icon | Volume Hint |
|-----------|------|-------------|
| SENDGRID | ph:paper-plane-tilt (sky) | "Up to 100K/month" |
| MAILGUN | ph:envelope-open (pink) | "Up to 50K/month" |
| AWSSES | ph:cloud (amber) | "Unlimited" |
| SMTP | ph:gear (slate) | "Varies" |

**Card 2 — API Settings** (cloud only)
| Field | Widget | Default | Validation | Sensitivity | Notes |
|-------|--------|---------|------------|-------------|-------|
| apiKey | password input + eye-toggle | — | required | secret | stored inside `ProviderConfiguration` JSON |
| apiRegion | select (Global / EU) | "Global" | — | normal | future: per-provider region lists |
| webhookUrl | read-only code block + copy button | (auto-derived `https://api.{tenant-domain}/webhooks/{providerCode}`) | — | normal | mockup shows ALWAYS visible — **see ISSUE-1** |
| trackingEvents | 6 checkboxes (multi-select) | all 6 checked | — | normal | persisted as CSV in `TrackingEventsCsv` |

**Card 3 — Sending Domain** (cloud only)
Card header right: 2 buttons (`Verify Domain` (calls VerifySendingDomain mutation), `Add New Domain` (SERVICE_PLACEHOLDER)).
| Field | Widget | Default | Validation | Sensitivity | Notes |
|-------|--------|---------|------------|-------------|-------|
| sendingDomainName | text input + status badge | — | hostname format | normal | badge: Verified (green) / Pending (amber) / Failed (red) |
| dnsRecords | read-only table | — | — | n/a | source: `getSendingDomainDnsRecords(companyEmailProviderId)`; columns: Type / Name / Value / Status; only renders when `companyEmailProviderId` exists; empty-state with `ph:database` icon when no records |

**Card 4 — Sending Identities** (full-width child table)
Table columns: From Name (bold) / From Email (monospace code chip) / Reply-To / Default (verified badge if `isDefault && isVerified`) / Actions (`Edit` + `⋯` menu with Set-Default + Resend-Verification + Delete).
| Action | Mutation | Confirm | Behavior |
|--------|----------|---------|----------|
| Add | CreateSendingIdentity | inline dialog | requires `sendingDomainName` for email validation hint |
| Edit | UpdateSendingIdentity | inline dialog | preserves `isDefault` state |
| Delete | DeleteSendingIdentity | `confirm("Delete identity \"{email}\"?")` | blocked when `isDefault===true` ("Cannot delete default identity — set another as default first") |
| Set Default | SetDefaultSendingIdentity | none | flips `isDefault` for the row, clears it on others |
| Resend Verification | (SERVICE_PLACEHOLDER toast) | none | future: provider-API call |

Empty state (no identities yet): "Save configuration first to manage identities" with `ph:user-circle` icon (already in place).

**Card 5 — Sending Limits & Throttling**
3-column grid:
| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| dailyEmailLimit | number input (max-width 120px) + "emails/day" suffix | (empty) | ≥ 0 | optional |
| hourlyEmailLimit | number input + "emails/hour" suffix | (empty) | ≥ 0 | optional |
| ratePerSecond | number input + "emails/second" suffix | (empty) | ≥ 0 | optional; mockup names "Rate Limit" but persisted as `RatePerSecond` |

Below the inputs: 2 stacked usage progress bars (Daily Usage / Monthly Usage) computed from `stats.dailyUsageCount` / `dailyEmailLimit` and `stats.monthlyUsageCount` / `monthlyEmailLimit`. Bar fill color: primary (<60%) / warning (60-89%) / danger (≥90%). Each bar shows labels: "{sent} sent" left and "{limit} limit" right.

**Card 6 — IP & Reputation** (5 read-only stat tiles)
`xl:grid-cols-5 lg:grid-cols-3 sm:grid-cols-2 grid-cols-1`. Each tile: small icon + label / large bold value / small detail.
| Tile | Icon | Value | Detail |
|------|------|-------|--------|
| Sending IP | ph:network | `stats.sendingIp` (mono) | "Dedicated IP" |
| IP Reputation | ph:shield-check | colored dot + "{score}/100" (color: ≥90 green / ≥70 amber / else red) | scoreLabel(score) |
| Domain Reputation | ph:globe | colored dot + "{score}/100" | scoreLabel |
| Bounce Rate | ph:arrow-u-up-right | "{rate}%" colored by threshold (<2% green / <5% amber / else red) | "Target: <2%" |
| Spam Rate | ph:warning-circle | "{rate}%" colored by threshold (<0.1% green / <0.5% amber / else red) | "Target: <0.1%" |

Loading state: 3-line Skeleton per tile.

**Card 7 — SMTP Configuration** (SMTP only)
3-row 2-column grid + inline action button.
| Field | Widget | Default | Validation | Sensitivity | Notes |
|-------|--------|---------|------------|-------------|-------|
| smtpHost | text input | — | required, hostname | normal | mockup placeholder "smtp.office365.com" |
| smtpPort | select | "587" | required, ∈ {25,465,587,2525} | normal | |
| encryption | select | "STARTTLS" | required, ∈ {None, SSL/TLS, STARTTLS} | normal | |
| authMethod | select | "LOGIN" | required, ∈ {PLAIN, LOGIN, CRAM-MD5} | normal | |
| username | email input | — | required, email | normal | |
| password | password input + eye-toggle | — | required | secret | |

Inline action: `Test Connection` button below grid → calls `testEmailProviderConnection(companyEmailProviderId)` → spinner → success (green check + message) OR error (red x + error.message). Disabled while loading.

#### Page-Level Actions

| Action | Position | Style | Permission | Confirmation |
|--------|----------|-------|------------|--------------|
| Send Test Email | header right | outline | BUSINESSADMIN | none — SERVICE_PLACEHOLDER toast |
| View Delivery Logs | header right | outline | BUSINESSADMIN | none — SERVICE_PLACEHOLDER toast |
| Test Connection | sticky footer left | outline | BUSINESSADMIN | none |
| Save Configuration | sticky footer right | primary | BUSINESSADMIN | none — relies on validation gating |

#### User Interaction Flow (SETTINGS_PAGE)

1. User opens `/setting/communicationconfig/emailproviderconfig` → `useAccessCapability` resolves → if `canRead`, render page.
2. Page mounts → `COMPANY_EMAIL_PROVIDER_ACTIVE_QUERY` fires → if a row exists, populate `form` state from response (parses `providerConfiguration` JSON; splits `trackingEventsCsv`); otherwise leave `INITIAL_FORM` and Status Banner shows "Not configured".
3. `COMPANY_EMAIL_PROVIDER_STATS_QUERY` fires when `companyEmailProviderId` known → populates IP/Reputation tiles + usage bars.
4. User clicks a Provider Card → `emailProviderId` + `emailProviderDataValue` set → `isCloudProvider` / `isSmtp` derived → conditional cards swap.
5. User edits any field → `setIsDirty(true)` → Save button enables → `beforeunload` listener registers.
6. User clicks `Save Configuration` → builds `request` payload (provider config JSON serialized, identities array mapped) → fires `SAVE_COMPANY_EMAIL_PROVIDER_MUTATION` → on success: toast + `refetch()` + `setIsDirty(false)`.
7. User clicks `Verify Domain` → `VERIFY_SENDING_DOMAIN_MUTATION` → on success: toast + sets `domainStatus="Verified"`; on failure: toast + sets `domainStatus="Failed"`.
8. User clicks `Test Connection` → `TEST_EMAIL_PROVIDER_CONNECTION_MUTATION` → result rendered next to button OR in Card 7's inline result span.
9. User adds Sending Identity → opens dialog → submits → `CREATE_SENDING_IDENTITY_MUTATION` → on success: refetch parent → identities array refreshed.
10. User clicks `Set Default` on a non-default identity → `SET_DEFAULT_SENDING_IDENTITY_MUTATION` → refetch → row's verified-badge moves.
11. User navigates away with dirty state → browser native `beforeunload` confirm.

---

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Initial load | `COMPANY_EMAIL_PROVIDER_ACTIVE_QUERY` loading | provider cards: 4 skeletons; rest of page: render with empty form |
| No config (first-time tenant) | query returns `null` data | warning Status Banner; provider cards rendered (empty selection); cards 2/3/7 hidden; cards 4/5/6 render with empty/zero state |
| Stats loading | `COMPANY_EMAIL_PROVIDER_STATS_QUERY` loading | reputation tiles: 3-line skeleton each; usage bars: skeleton tracks |
| DNS records loading | `SENDING_DOMAIN_DNS_RECORDS_QUERY` loading | 4 row-skeletons (h-10 each) |
| DNS records empty | query returns `[]` | empty-state with `ph:database` icon + "No DNS records available" |
| Save error | mutation error | toast.error + remain on page with current state |
| Test Connection error | mutation error | inline red x + error message next to button |

---

## ⑦ Substitution Guide

> Canonical SETTINGS_PAGE precedent: **SMS Setup #157** (`prompts/smssetup.md`) — singleton-per-tenant + provider-card-selector + child-grid pattern. **Email Provider Config #84 is the second instance and reinforces the convention.**

| Canonical (SMS Setup #157) | → Email Provider Config (#84) | Context |
|----------------------------|-------------------------------|---------|
| `SmsSetting` | `CompanyEmailProvider` | Entity/class name |
| `smsSetting` (camel) | `companyEmailProvider` | Variable/field names |
| `notify` | `notify` | DB schema (same) |
| `Notify` | `Notify` | Backend group |
| `SMSSETUP` | `EMAILPROVIDERCONFIG` | MenuCode |
| `setting/communicationconfig/smssetup` | `setting/communicationconfig/emailproviderconfig` | MenuUrl |
| 5 provider cards (Twilio/Bird/Vonage/Local/Custom) | 4 provider cards (SendGrid/Mailgun/AWSSES/SMTP) | Provider selector |
| 3 tabs (Provider/Compliance/Usage) | 7 vertical-stack cards | Container pattern (different — vertical-stack, not tabs) |
| save-per-section | save-all | Save model (different — single bottom button per mockup) |
| `SmsSenderRegistration` child grid | `EmailSendingIdentity` child grid | Sub-table pattern |
| `SMSPROVIDER` MasterDataType | `EMAILPROVIDER` MasterDataType | Provider list source |
| `Test SMS` SERVICE_PLACEHOLDER | `Send Test Email` SERVICE_PLACEHOLDER | Verify-action shape |
| Test/Connect/DND-Sync are SERVICE_PLACEHOLDER | Send-Test/Verify-Domain/Test-Connection are SERVICE_PLACEHOLDER | External integration boundary |

**Key divergence from SMS Setup**: container is `vertical-stack` (7 cards) instead of `tabs` (3); save model is `save-all` (one bottom button) instead of `save-per-section`. Both choices are mockup-driven.

---

## ⑧ File Manifest

> **Scope: ALIGN** — all files EXIST. Verify alignment, patch gaps in §⑫.

### Backend Files (existing — verify only)

| # | File | Path | State |
|---|------|------|-------|
| 1 | Entity | `PSS_2.0_Backend/.../Base.Domain/Models/NotifyModels/CompanyEmailProvider.cs` | ✓ exists |
| 2 | EF Config | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/NotifyConfigurations/CompanyEmailProviderConfiguration.cs` | ✓ exists |
| 3 | Schemas (DTOs) | `PSS_2.0_Backend/.../Base.Application/Schemas/NotifySchemas/CompanyEmailProviderSchemas.cs` | ✓ exists (7 DTOs) |
| 4 | GetActive Query | `PSS_2.0_Backend/.../Base.Application/Business/NotifyBusiness/CompanyEmailProviders/Queries/GetCompanyEmailProviderStats.cs` (file holds 3 queries) | ✓ exists |
| 5 | GetById / GetAll Queries | `.../Queries/GetCompanyEmailProviderById.cs`, `.../Queries/GetCompanyEmailProvider.cs` | ✓ exists (legacy — kept for registry) |
| 6 | Save Command | `.../Commands/SaveCompanyEmailProvider.cs` | ✓ exists |
| 7 | Workflow Commands | `.../Commands/WorkflowCompanyEmailProvider.cs` (holds VerifySendingDomain + TestEmailProviderConnection + 5 identity commands) | ✓ exists |
| 8 | Create/Update/Delete/Toggle | `.../Commands/{Create,Update,Delete,Toggle}CompanyEmailProvider.cs` | ✓ exists (legacy — not used by this screen) |
| 9 | Mutations endpoint | `PSS_2.0_Backend/.../Base.API/EndPoints/Notify/Mutations/CompanyEmailProviderMutations.cs` | ✓ exists (12 GQL fields) |
| 10 | Queries endpoint | `PSS_2.0_Backend/.../Base.API/EndPoints/Notify/Queries/CompanyEmailProviderQueries.cs` | ✓ exists (5 GQL fields) |

### Backend Wiring (existing — verify)

| # | File | Status |
|---|------|--------|
| 1 | `INotifyDbContext.cs` / `NotifyDbContext.cs` | ✓ DbSet<CompanyEmailProvider> + DbSet<EmailSendingIdentity> wired |
| 2 | `DecoratorNotifyModules.cs` | ✓ entries present |
| 3 | `NotifyMappings.cs` | ✓ Mapster entries present |
| 4 | `NotifyMutations` / `NotifyQueries` parent endpoints | ✓ child types registered |

### Frontend Files (existing — verify only)

| # | File | Path | State |
|---|------|------|-------|
| 1 | DTO | `PSS_2.0_Frontend/src/domain/entities/notify-service/CompanyEmailProviderDto.ts` | ✓ exists |
| 2 | GQL Query | `PSS_2.0_Frontend/src/infrastructure/gql-queries/notify-queries/CompanyEmailProviderQuery.ts` | ✓ exists (5 queries) |
| 3 | GQL Mutation | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/notify-mutations/CompanyEmailProviderMutation.ts` | ✓ exists (12 mutations) |
| 4 | Page Component (main) | `PSS_2.0_Frontend/src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/email-provider-config-page.tsx` | ✓ exists (953 lines) |
| 5 | Provider Card Selector | `.../emailproviderconfig/provider-card-selector.tsx` | ✓ exists |
| 6 | Provider Registry | `.../emailproviderconfig/provider-registry.ts` | ✓ exists (icon/desc/volume map) |
| 7 | Sending Identities Table | `.../emailproviderconfig/sending-identities-table.tsx` | ✓ exists |
| 8 | Sending Identity Dialog | `.../emailproviderconfig/sending-identity-dialog.tsx` | ✓ exists |
| 9 | DNS Records Table | `.../emailproviderconfig/dns-records-table.tsx` | ✓ exists |
| 10 | Reputation Cards | `.../emailproviderconfig/reputation-cards.tsx` | ✓ exists |
| 11 | Usage Bars | `.../emailproviderconfig/usage-bars.tsx` | ✓ exists |
| 12 | Page Config wrapper | `PSS_2.0_Frontend/src/presentation/pages/setting/communicationconfig/emailproviderconfig.tsx` | ✓ exists (delegates with capability gate) |
| 13 | Pages barrel | `PSS_2.0_Frontend/src/presentation/pages/setting/communicationconfig/index.ts` | ✓ exports `EmailProviderConfigPageConfig` |
| 14 | Route Page | `PSS_2.0_Frontend/src/app/[lang]/setting/communicationconfig/emailproviderconfig/page.tsx` | ✓ exists |

### Frontend Wiring (existing — verify)

| # | File | What's Wired |
|---|------|--------------|
| 1 | `notify-service-entity-operations.ts` | `EMAILPROVIDERCONFIG` gridCode block (legacy CRUD ops — kept for registry contract; the actual screen uses SAVE mutation directly) |
| 2 | DTO/Query/Mutation barrels | `Dtos.CompanyEmailProviderDto`, `Queries.COMPANY_EMAIL_PROVIDER_ACTIVE_QUERY` etc. all exported |
| 3 | Sidebar menu | menu seeded via `Pss2.0_Global_Menus_List.sql` line 468 (MenuCode=EMAILPROVIDERCONFIG, parent SET_COMMUNICATIONCONFIG) |
| 4 | Communication Provider Health Widget | Already deep-links to this route (`CommunicationProviderHealthWidget.tsx:136`) |

### DB Seed (existing — verify)

| # | File | Path | State |
|---|------|------|-------|
| 1 | Seed script | `PSS_2.0_Backend/.../sql-scripts-dyanmic/CompanyEmailProvider-sqlscripts.sql` | ✓ exists (idempotent — seeds EMAILPROVIDER + EMAILPROVIDERTYPE MasterData + Grid registration with rename from `COMPANYEMAILPROVIDER` to `EMAILPROVIDERCONFIG`) |

> **`sql-scripts-dyanmic/` typo preserved** per ChequeDonation #6 ISSUE-15 precedent.

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: ALIGN

MenuName: Email Provider Config
MenuCode: EMAILPROVIDERCONFIG
ParentMenu: SET_COMMUNICATIONCONFIG
Module: SETTING
MenuUrl: setting/communicationconfig/emailproviderconfig
GridType: CONFIG
OrderBy: 3

MenuCapabilities: READ, MODIFY, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY

GridFormSchema: SKIP
GridCode: EMAILPROVIDERCONFIG
---CONFIG-END---
```

> **Notes**:
> - `MenuCode`, `ParentMenu`, `Module`, `MenuUrl`, `OrderBy=3` taken verbatim from `MODULE_MENU_REFERENCE.md` SET_COMMUNICATIONCONFIG block (lines 277-282).
> - Menu row already inserted via `Pss2.0_Global_Menus_List.sql:468`. No re-seed needed unless verification fails.
> - **GridType**: existing seed registers as `FLOW` ("custom config, no grid UI") because the seed predates the formalized `CONFIG` GridType. Acceptable as-is — the FE doesn't render a grid; both `FLOW` and `CONFIG` GridType produce the same effect for this screen. **Optional alignment**: change to `CONFIG` once SMS Setup #157 build settles the convention. Logged as ISSUE-5.
> - **No CREATE/DELETE in MenuCapabilities** — singleton-per-tenant; the legacy mutations stay registered but aren't invoked by this screen.
> - **GridFormSchema = SKIP** — custom UI, no RJSF.

---

## ⑩ Expected BE→FE Contract

> All types EXIST. Verify FE consumers match.

**GraphQL Types:**
- Query type: `CompanyEmailProviderQueries`
- Mutation type: `CompanyEmailProviderMutations`

### Queries (5 fields)

| GQL Field | Returns | Key Args | FE Consumer |
|-----------|---------|----------|-------------|
| `companyEmailProviders(request: GridFeatureRequest)` | `PaginatedApiResponse<CompanyEmailProviderResponseDto[]>` | grid args | unused by this screen (kept for registry) |
| `companyEmailProviderById(companyEmailProviderId: Int!)` | `BaseApiResponse<CompanyEmailProviderResponseDto>` | id | unused by this screen |
| `activeCompanyEmailProvider()` | `BaseApiResponse<CompanyEmailProviderResponseDto>` | — (HttpContext) | **PRIMARY** — `email-provider-config-page.tsx:160` |
| `emailProviderStats(companyEmailProviderId: Int!)` | `BaseApiResponse<CompanyEmailProviderStatsDto>` | id | reputation cards + usage bars |
| `sendingDomainDnsRecords(companyEmailProviderId: Int!)` | `BaseApiResponse<EmailDnsRecordDto[]>` | id | DNS records table |

### Mutations (12 fields)

| GQL Field | Input | Returns | FE Consumer |
|-----------|-------|---------|-------------|
| `saveCompanyEmailProvider(request: CompanyEmailProviderRequestDto!)` | request | `BaseApiResponse<CompanyEmailProviderResponseDto>` | **PRIMARY** — main save |
| `verifySendingDomain(companyEmailProviderId: Int!)` | id | `BaseApiResponse<bool>` | `Verify Domain` button |
| `testEmailProviderConnection(companyEmailProviderId: Int!)` | id | `BaseApiResponse<string>` | `Test Connection` button |
| `createSendingIdentity(request: EmailSendingIdentityRequestDto!)` | request | `BaseApiResponse<EmailSendingIdentityResponseDto>` | identity dialog (Add) |
| `updateSendingIdentity(request: EmailSendingIdentityRequestDto!)` | request | `BaseApiResponse<EmailSendingIdentityResponseDto>` | identity dialog (Edit) |
| `deleteSendingIdentity(emailSendingIdentityId: Int!)` | id | `BaseApiResponse<bool>` | row Delete |
| `setDefaultSendingIdentity(emailSendingIdentityId: Int!)` | id | `BaseApiResponse<bool>` | row "Set Default" |
| `verifySendingIdentity(emailSendingIdentityId: Int!)` | id | `BaseApiResponse<bool>` | row "Resend Verification" (currently SERVICE_PLACEHOLDER toast on FE) |
| `createCompanyEmailProvider`, `updateCompanyEmailProvider`, `deleteCompanyEmailProvider`, `activateDeactivateCompanyEmailProvider` | RequestDto / id | `BaseApiResponse<*>` | unused by this screen (kept for registry) |

### CompanyEmailProviderResponseDto shape (key fields used by FE)

| Field | TS Type | Notes |
|-------|---------|-------|
| companyEmailProviderId | number | PK |
| companyId | number | tenant scope |
| emailProviderId | number | FK MasterData |
| emailProvider | `{ masterDataId, dataName, dataValue }` | nav projection used for `dataValue` switch |
| emailProviderTypeId | number | FK MasterData |
| providerConfiguration | string | JSON blob — parsed by FE into `apiConfig`/`smtpConfig` |
| apiRegion | string? | "Global" \| "EU" |
| trackingEventsCsv | string? | comma-sep |
| sendingDomainName | string? | hostname |
| domainStatus | string? | "Verified" \| "Pending" \| "Failed" |
| isDefault | boolean | always TRUE on the active row |
| hourlyEmailLimit | number? | |
| dailyEmailLimit | number? | |
| monthlyEmailLimit | number? | |
| ratePerSecond | number? | |
| defaultFromEmail | string? | |
| defaultFromName | string? | |
| webhookUrl | string? | |
| lastEmailSentAt | string? | ISO datetime |
| ipReputationScore / domainReputationScore | number? | 0-100 |
| bounceRate / spamRate | number? | percent |
| isActive | boolean | |
| sendingIdentities | EmailSendingIdentityResponseDto[] | nested child rows |

### EmailSendingIdentityResponseDto

| Field | TS Type |
|-------|---------|
| emailSendingIdentityId | number |
| companyEmailProviderId | number |
| fromName | string |
| fromEmail | string |
| replyToEmail | string? |
| isDefault | boolean |
| isVerified | boolean |
| isActive | boolean |

### CompanyEmailProviderStatsDto

| Field | TS Type | Notes |
|-------|---------|-------|
| dailyUsageCount | number? | |
| monthlyUsageCount | number? | |
| dailyUsagePercentage | number? | computed |
| monthlyUsagePercentage | number? | computed |
| sendingIp | string? | |
| ipReputationScore | number? | |
| domainReputationScore | number? | |
| bounceRate | number? | |
| spamRate | number? | |
| lastEmailSentAt | string? | |

### EmailDnsRecordDto

| Field | TS Type | Notes |
|-------|---------|-------|
| recordType | string | "CNAME" / "TXT" / "MX" |
| recordName | string | e.g. `em1234.mail.{tenant}.org` |
| recordValue | string | provider-given target |
| isVerified | boolean | currently always true in placeholder; future: real check |

> **Sensitive-field handling — current state vs target**:
> Currently `providerConfiguration` JSON is returned RAW in `GetActiveCompanyEmailProvider` response (apiKey + password visible in cleartext over GraphQL). FE re-displays them masked, but a network sniffer / dev-tools inspection sees them. Target: BE strips/masks on read, accepts the empty-string sentinel on save. Tracked as ISSUE-3 (HIGH).

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (BE files unchanged or only patches per §⑫)
- [ ] `pnpm tsc --noEmit` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/setting/communicationconfig/emailproviderconfig`

**Functional Verification — SETTINGS_PAGE — Full E2E (MANDATORY):**

Provider Selection (Card 1):
- [ ] 4 provider cards render in `xl:grid-cols-4` layout sourced from `masterDatasByTypeCode("EMAILPROVIDER")`
- [ ] Selected card highlights with primary border + filled radio dot
- [ ] Clicking SendGrid/Mailgun/AWSSES reveals API Settings + Sending Domain cards; hides SMTP card
- [ ] Clicking Custom SMTP reveals SMTP Configuration card; hides API Settings + Sending Domain
- [ ] Switching providers does NOT instantly save — Save button drives the persistence

Status Banner:
- [ ] Renders with `connected` (green) variant when domain verified + identity verified + recent send
- [ ] Renders with `muted` variant when configured but never sent
- [ ] Renders with `warning` variant when not configured

API Settings (Card 2 — cloud only):
- [ ] API Key masked by default; eye-toggle shows plain text
- [ ] API Region select offers Global / EU
- [ ] Webhook URL renders **always** (per ISSUE-1) with copy-to-clipboard button
- [ ] Copy button shows "Copied!" feedback for 2 seconds
- [ ] Tracking Events: 6 checkboxes (Delivered/Opened/Clicked/Bounced/Spam Report/Unsubscribed); all checked by default; toggling persists in `trackingEvents` array; saved as CSV

Sending Domain (Card 3 — cloud only):
- [ ] Domain Name input editable
- [ ] Domain Status badge variant matches `domainStatus` value (Verified=green, Pending=amber, Failed=red)
- [ ] `Verify Domain` button disabled until `companyEmailProviderId` exists; on click fires mutation; on success sets `domainStatus="Verified"` + toast
- [ ] `Add New Domain` SERVICE_PLACEHOLDER toast
- [ ] DNS Records table renders all rows from `getSendingDomainDnsRecords` query; loading state shows 4 skeletons; empty state shows `ph:database` icon + message

Sending Identities (Card 4):
- [ ] Empty state ("Save configuration first to manage identities") when `companyEmailProviderId === null`
- [ ] After save: identity table renders rows with From Name (bold) / From Email (mono code chip) / Reply-To / Default badge / Actions
- [ ] `+ Add Sending Identity` opens dialog → on submit fires `CREATE_SENDING_IDENTITY_MUTATION` → refetch → row appears
- [ ] `Edit` opens dialog with values prefilled → submit fires `UPDATE_SENDING_IDENTITY_MUTATION`
- [ ] `Delete` shows native confirm; if `isDefault` blocks with toast; otherwise fires `DELETE_SENDING_IDENTITY_MUTATION`
- [ ] `Set Default` fires mutation; refetch updates which row shows verified-badge
- [ ] `Resend Verification` SERVICE_PLACEHOLDER toast

Sending Limits (Card 5):
- [ ] 3 numeric inputs (Daily / Hourly / Rate) accept positive integers; reject negatives
- [ ] Daily Usage bar fills proportionally to `stats.dailyUsageCount / dailyEmailLimit`; color shifts at 60% / 90%
- [ ] Monthly Usage bar same logic with monthly counts
- [ ] Loading state: bar tracks shown as skeletons

IP & Reputation (Card 6):
- [ ] All 5 tiles render with skeleton on load
- [ ] Reputation tile dot color: ≥90 green, ≥70 amber, else red
- [ ] Bounce Rate threshold: <2% green, <5% amber, else red
- [ ] Spam Rate threshold: <0.1% green, <0.5% amber, else red
- [ ] All values are read-only — no inputs

SMTP Configuration (Card 7 — SMTP only):
- [ ] Renders only when SMTP provider selected
- [ ] All 6 fields (Host / Port / Encryption / Auth / Username / Password) marked required (visual asterisk + Zod-level validation)
- [ ] Password masked + eye-toggle works
- [ ] `Test Connection` inline button: spinner during loading; green check + message on success; red x + error on failure
- [ ] Disabled until configuration saved

Sticky Footer:
- [ ] `Test Connection` button disabled until `companyEmailProviderId` exists
- [ ] `Save Configuration` button disabled when not dirty OR no provider selected
- [ ] On save success: toast "Configuration saved" + dirty cleared + refetch

Save Behavior:
- [ ] `providerConfiguration` JSON correctly serialized: `{apiKey, apiRegion}` for cloud; `{smtpHost, smtpPort, encryption, authMethod, username, password}` for SMTP
- [ ] `trackingEventsCsv` correctly joined with commas
- [ ] Switching providers (e.g. SendGrid → Custom SMTP) replaces ProviderConfiguration JSON shape, soft-deletes prior row server-side
- [ ] Save fires `SAVE_COMPANY_EMAIL_PROVIDER_MUTATION` with full request payload + identities array

Sensitive Fields (post-ISSUE-3 patch):
- [ ] BE returns `apiKey` and SMTP `password` as `null` OR placeholder `"••••••••"` in `GetActiveCompanyEmailProvider` response
- [ ] FE detects placeholder and treats empty submit as "unchanged"; non-empty as "overwrite"
- [ ] BE on Save: empty/placeholder credential keeps prior value; non-empty overwrites

Role Gating:
- [ ] BUSINESSADMIN sees full page
- [ ] STAFFADMIN / STAFFENTRY / FIELDAGENT / DONORPORTAL / VOLUNTEERPORTAL / MEMBERPORTAL → access denied

DB Seed Verification:
- [ ] Menu row exists under SET_COMMUNICATIONCONFIG with OrderBy=3
- [ ] EMAILPROVIDER MasterData has 4 rows (SENDGRID/MAILGUN/AWSSES/SMTP) with icon keys in DataSetting
- [ ] EMAILPROVIDERTYPE MasterData has 2 rows (TRANSACTIONAL/MARKETING)
- [ ] `sett."Grids"` has row with GridCode=EMAILPROVIDERCONFIG, GridFormSchema=NULL
- [ ] Page renders without crashing on freshly-seeded DB (no active provider row → warning banner + empty form)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Universal CONFIG warnings (already respected):**
- `CompanyId` is NOT a form field — set from HttpContext in `GetActiveCompanyEmailProvider` and `SaveCompanyEmailProvider`.
- No CREATE/DELETE wired into the MenuCapabilities — singleton uses Save (upsert).
- GridFormSchema = SKIP — custom UI.
- No `view-page.tsx` 3-mode pattern — single-mode page.
- BUSINESSADMIN-only via `useAccessCapability`.

**ALIGN-specific notes:**
- This is **ALIGN scope** — both BE and FE EXIST and are largely aligned with the mockup. The build phase should ONLY apply the targeted patches listed below. **Do NOT regenerate** entity / EF config / DTO / queries / commands / mutations / page-component / sidebar wiring from scratch.
- Existing implementation is from **Screen #28 CompanyEmailProvider — ALIGN (2026-04-24)**, which renamed the registry GridCode `COMPANYEMAILPROVIDER` → `EMAILPROVIDERCONFIG` and added 11 columns to align with this mockup. That work is solid; only minor gaps remain.
- Verify `dotnet build` is clean against the existing tree before applying patches; otherwise diagnose unrelated build errors first.

**Service Dependencies (UI-only — no backend service implementation):**

> Everything else in the mockup is in scope. Items below are SERVICE_PLACEHOLDERs because no production service layer exists yet.

- ⚠ **SERVICE_PLACEHOLDER**: `Send Test Email` (header button) — full UI implemented; handler emits toast.
- ⚠ **SERVICE_PLACEHOLDER**: `View Delivery Logs` (header button) — full UI implemented; handler emits toast or navigates to placeholder.
- ⚠ **SERVICE_PLACEHOLDER**: `Test Connection` (footer + Card 7) — BE handler `TestEmailProviderConnectionHandler` returns hardcoded "Connection successful". Future: real provider-API ping.
- ⚠ **SERVICE_PLACEHOLDER**: `Verify Domain` — BE handler `VerifySendingDomainHandler` auto-marks `DomainStatus="Verified"` + `DomainVerifiedAt=now()`. Future: real DNS-record lookup against provider API.
- ⚠ **SERVICE_PLACEHOLDER**: `Add New Domain` (Card 3 header button) — toast "Multi-domain support coming soon".
- ⚠ **SERVICE_PLACEHOLDER**: `Resend Verification` (identity row action) — toast "Verification email sent".
- ⚠ **SERVICE_PLACEHOLDER**: DNS Records data — `GetSendingDomainDnsRecordsHandler` returns hardcoded SPF/CNAME/DKIM rows derived from `SendingDomainName`. Future: real provider-API DNS-record listing.
- ⚠ **SERVICE_PLACEHOLDER**: Reputation/Usage stats — `GetCompanyEmailProviderStatsHandler` returns hardcoded values. Future: real provider-API stats.

Full UI must remain built (sections, masked inputs, copy-to-clipboard, action buttons). Only the handler internals are mocked.

### § Known Issues

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | LOW | FE | Webhook URL renders only when `form.webhookUrl` is set (`email-provider-config-page.tsx:559`). Mockup shows it always — should auto-derive a placeholder URL pattern (e.g. `https://api.{tenant-host}/webhooks/{providerCode}`) when absent. **Fix**: render the webhook box always; show derived value or "Save first to generate webhook URL" message. | CLOSED (S1) |
| ISSUE-2 | MED | FE | Switching providers (e.g. SendGrid → Mailgun) is silent — clicking a different card just changes the form. The mockup's status banner makes the consequence subtle. **Fix**: when `emailProviderId` changes from a previously-saved value, show inline warning "Switching providers will require re-verification of your domain and identities." Confirm modal optional but recommended. | CLOSED (S1) |
| ISSUE-3 | HIGH | BE | Sensitive credentials (API Key, SMTP Password) round-trip RAW through `GetActiveCompanyEmailProvider`. The `ProviderConfiguration` JSON returned by the BE includes the cleartext apiKey and password. FE masks them visually but they're visible to a network sniffer. **Fix**: in `GetActiveCompanyEmailProviderHandler`, post-projection: replace `apiKey` with placeholder (`"••••••••"`) and `password` with same. In `SaveCompanyEmailProviderHandler`: when incoming JSON's apiKey === placeholder OR is empty/null, preserve the prior value (read-modify-write). Same for password. Add unit tests. | CLOSED (S1) — mask helper `SensitiveFieldMasking.MaskCredentials` applied in GetActive + GetById handlers; companion `PreserveSensitiveFields` in SaveCompanyEmailProviderHandler. Unit tests still TODO. |
| ISSUE-4 | MED | BE | Credential rotation is not audit-logged. Changes to apiKey/password should emit an `IDomainEvent` ("CompanyEmailProviderCredentialRotated") with actor + timestamp + provider name (NOT the secret). Future enhancement; ties into platform audit infra. | OPEN (deferred) |
| ISSUE-5 | LOW | Seed | Existing seed registers GridType as `FLOW` (with comment "FLOW — custom config, no grid UI"). After SMS Setup #157 settles the convention, consider re-classifying as `CONFIG` GridType for parity. Functionally equivalent today (FE doesn't render a grid for this screen). | CLOSED (S1) — INSERT updated to CONFIG; idempotent step 5c backfills any prior FLOW row to CONFIG. |
| ISSUE-6 | LOW | FE | The active-provider query response `data.result.data` shape implies double-nesting — the FE reads `activeData?.result?.data` (line 166). Verify the BE actually returns `BaseApiResponse<CompanyEmailProviderResponseDto>` where `result` is the success-flag wrapper and `data` is the DTO. If contract diverges (some queries return `result` as the DTO directly), normalize on the FE side. | VERIFIED (S1) — `result: activeCompanyEmailProvider` aliases the BaseApiResponse wrapper; `.data` is the payload. Shape correct, no code change. |
| ISSUE-7 | LOW | FE | `notify-service-entity-operations.ts` line 37 has TODO comment: "unused — kept for registry contract". Confirm that the entity-operations registry contract truly requires this entry (some other code grep'd `EMAILPROVIDERCONFIG`?). If genuinely dead, delete; else keep with comment. | VERIFIED (S1) — entry confirmed dead (no FE consumer), but retained with TODO for registry-contract safety. No code change. |
| ISSUE-8 | LOW | UX | No "Reset to Defaults" / "Export / Import Config" actions in the mockup. Skip implementing them — they were not asked for. If a future enhancement adds them, log here. | OPEN (deferred) |
| ISSUE-9 | LOW | FE | `Sending Identity` dialog allows email outside the `sendingDomainName` (e.g. `events@ghf.org` while domain is `mail.ghf.org`). Mockup data shows mixed-domain Reply-To values (`info@ghf.org`) but From-Email always within `mail.ghf.org`. Add validation hint: warn when `fromEmail`'s domain ≠ `sendingDomainName` (verification will fail). Non-blocking. | SUPERSEDED (S1) — current FE blocks (stricter than prompt's "non-blocking warn"); kept as-is for safer behavior. BE Save validator is more permissive (allows subdomain match) — minor divergence noted, not blocking. |
| ISSUE-10 | LOW | FE | The status banner's `lastEmailSentAt` "minutes ago" computation uses `Intl.RelativeTimeFormat("en", {numeric:"auto"})` with a `Math.round((past-now)/60000)` value, which yields a NEGATIVE integer (correct for past-relative format). Verify the output reads as "2 minutes ago" rather than "in 2 minutes" — the current arithmetic is correct but worth re-checking with a unit test. | VERIFIED (S1) — arithmetic correct (past time minus future = negative → "X minutes ago"). Unit test still TODO. |
| ISSUE-11 | HIGH | FE | `provider-card-selector.tsx` used a non-existent / mis-shaped GraphQL query (`masterDatasByTypeCode` with `masterDataId` projected directly on `BaseApiResponseOfIEnumerableOfMasterDataResponseDto`) — runtime error at page load: `"The field masterDataId does not exist on the type BaseApiResponseOfIEnumerableOfMasterDataResponseDto."`. **Fix**: switch to the canonical `MASTERDATAS_QUERY` + `advancedFilter { id, combinator, rules: [{ id, field: "MasterDataType.TypeCode", operator: "=", value: "EMAILPROVIDER", dataType: "String" }] }` pattern. Both the outer advancedFilter AND each rule require an `id` (else BE returns `"The required input field id is missing"`). Mirrors `custom-integration-workshop.tsx` (#87). Read array from `result.data` (BaseApiResponse wrapper). | CLOSED (S2) |
| ISSUE-12 | HIGH | BE | `GetActiveCompanyEmailProviderHandler` filtered strictly `IsDefault == true` — legacy CompanyEmailProvider rows (created via the older `CreateCompanyEmailProvider` path) have `IsDefault == false`, so an existing record in the DB was invisible to the FE (page showed "Not Configured" even though a row existed). **Fix**: relax to `CompanyId == X AND IsDeleted == false`, ordered by `IsDefault DESC, ModifiedDate DESC, CreatedDate DESC` — singleton-per-tenant returns the most relevant row whether legacy or new. | CLOSED (S3) |
| ISSUE-13 | MED | FE | Provider card selector showed all 4 providers (SendGrid / Mailgun / AWSSES / SMTP) as fully clickable — but only SendGrid is supported in the current build. **Fix**: gate clicks by `ENABLED_PROVIDERS = { "SENDGRID" }`; non-enabled cards render with `opacity-60 cursor-not-allowed` and a "Coming soon" muted chip. Backend MasterData EMAILPROVIDER seed kept intact for catalog visibility. | CLOSED (S3) |
| ISSUE-14 | HIGH | BE+FE | `GetEmailProviderStatsHandler` returned mocked constants (`dailyUsageCount=1234`, `monthlyUsageCount=28456`, `bounceRate=0.8`, `spamRate=0.02`) instead of real aggregations from EmailSendQueue. Added two new DTO fields (`MonthlyEmailCostAmount`, `RemainingMonthlySends`) and replaced the mocked logic with: daily/monthly send counts via `EmailSendQueue.SendAt` window filter (UTC), `BounceRate` from `IsBounced` flag, `SpamRate` from `IsComplained` flag, `MonthlyEmailCostAmount = SUM(EmailCost)` on current-month window, `RemainingMonthlySends = MAX(0, MonthlyEmailLimit − MonthlyUsageCount)` (null when no limit set). IP / Domain reputation kept as SERVICE_PLACEHOLDER constants — those come from the provider's API, not the DB. **Companion FE fix**: stats GQL query previously selected `dailyUsageCount` directly on `BaseApiResponse<StatsDto>` wrapper (same latent bug as ISSUE-11); wrapped in `data { ... }` and updated consumer to read `statsData?.result?.data`. Added "Remaining this month" hint to UsageBars (Card 5) and a 6th "Monthly Cost" stat tile to ReputationCards (Card 6). | CLOSED (S3) |
| ISSUE-15 | HIGH | FE | `SENDING_DOMAIN_DNS_RECORDS_QUERY` had the same wrapper-shape bug as ISSUE-11/14 — selected `type / name / value / status` directly on `BaseApiResponseOfIEnumerableOfEmailDnsRecordDto` wrapper (BE returns `data: EmailDnsRecordDto[]` inside the wrapper). Additionally the field names were wrong: BE `EmailDnsRecordDto` uses `RecordType / RecordName / RecordValue / IsVerified`, not `Type / Name / Value / Status`. Runtime error: `"The field type does not exist on the type BaseApiResponseOfIEnumerableOfEmailDnsRecordDto"`. **Fix**: wrap query selection in `data { recordType, recordName, recordValue, isVerified }`; update `dns-records-table.tsx` to read `data?.result?.data`, rename row fields, swap `record.status === "Verified"` for `record.isVerified` boolean check. | CLOSED (S4) |
| ISSUE-16 | MED | UI | Page rendered in a `max-w-5xl` centered column with tight spacing — felt narrow and dated on wide monitors. **Fix**: full-width container (`w-full px-4 sm:px-6 lg:px-8`); cards upgraded to `rounded-xl shadow-sm hover:shadow-md` with gradient header strip + tinted icon pill; status banner gets gradient bg + circular icon badge; page body picks up subtle `bg-gradient-to-b from-muted/20` for depth; sticky footer becomes `backdrop-blur-sm shadow-lg` and follows the new full-width container. | CLOSED (S5) |
| ISSUE-17 | MED | FE | Monthly Cost tile hardcoded a `$` prefix — incorrect for tenants whose CompanyEmailProvider is configured with a non-USD billing currency, and offered no equivalent in the tenant's display currency. **Fix**: render the value in the **provider's configured currency** (`CompanyEmailProvider.Currency` → `currencyCode + currencySymbol`); if the provider currency ≠ company base currency, query `currentFxRate(fromCurrencyId, toCurrencyId)` (direct-pair per `[[feedback-fx-direct-pair]]`) and render the company-currency equivalent as a `≈ X` secondary line in the StatCard `detail`. Falls back to "FX rate unavailable" on pair miss (never USD-pivots). Falls back to company base currency when provider currency is unset. Added `currencySymbol` to `currency { ... }` selection in both active + by-id queries. | CLOSED (S5) |
| ISSUE-18 | LOW | UI | Provider cards used generic Phosphor glyphs (`ph:paper-plane-tilt`, `ph:envelope-circle-check`, `ph:cloud`) with tinted backgrounds instead of the real brand marks. **Fix**: switch to Iconify's `logos:` set (full-color brand SVGs loaded on-demand by @iconify/react — no extra install required): SendGrid → `logos:sendgrid`, Mailgun → `logos:mailgun-icon`, AWS SES → `logos:aws`. SMTP stays generic (`ph:gear` — no brand exists). Added `iconHasNativeColor` flag to `ProviderRegistryEntry`; native-color icons render in a neutral `bg-white border-border` tile (so the brand colors read correctly) and drop the `colorClass` text-color tint. Bumped icon size from `h-6 w-6` → `h-7 w-7` for more presence in the larger card. | CLOSED (S6) |
| ISSUE-19 | LOW | UI+Seed | Catalog expanded from 4 → 6 email providers. Added `SPARKPOST` (real SaaS provider, brand silhouette via `simple-icons:sparkpost` + orange tint) and `MAILKIT` (.NET library — not a SaaS brand, so generic `ph:envelope-simple-open` + emerald tint, description "Self-hosted .NET MailKit dispatcher"). Both remain in the "Coming soon" disabled set (only SendGrid is wired); UI just exposes the roadmap. Seed `CompanyEmailProvider-sqlscripts.sql` Step 2 extended from 4 rows → 6 rows (idempotent — `NOT EXISTS` guard means re-running adds only the missing two). Also refreshed the IconKey for SendGrid/Mailgun/AWSSES rows to the new `logos:` values for parity with the FE registry. | CLOSED (S7) |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-15 — BUILD — COMPLETED

- **Scope**: Initial ALIGN session against the existing #28 implementation. Applied targeted patches per §⑫ Known Issues without regenerating entity / EF config / DTO / mutations / queries / page-component.
- **Files touched**:
  - BE:
    - `PSS_2.0_Backend/.../NotifyBusiness/CompanyEmailProviders/Queries/GetCompanyEmailProviderStats.cs` (modified) — added `SensitiveFieldMasking` static helper using `JsonNode`; `GetActiveCompanyEmailProviderHandler` now masks `apiKey`/`password` in returned ProviderConfiguration JSON
    - `PSS_2.0_Backend/.../NotifyBusiness/CompanyEmailProviders/Queries/GetCompanyEmailProviderById.cs` (modified) — applied same mask post-projection (defense in depth even though the FE does not call this query)
    - `PSS_2.0_Backend/.../NotifyBusiness/CompanyEmailProviders/Commands/SaveCompanyEmailProvider.cs` (modified) — UPDATE branch now calls `PreserveSensitiveFields` to restore prior apiKey/password when FE submits empty or the masking placeholder; removed two no-op TODO lines around `existing.ProviderConfiguration = existing.ProviderConfiguration`
  - FE:
    - `PSS_2.0_Frontend/.../emailproviderconfig/email-provider-config-page.tsx` (modified) — added `savedProviderId` state + provider-switch warning banner inside Card 1; removed `{form.webhookUrl && (...)}` gate so Webhook URL block is always visible for cloud providers (shows "Save configuration to generate webhook URL" hint when empty; Copy button disabled in that state)
  - DB:
    - `PSS_2.0_Backend/.../sql-scripts-dyanmic/CompanyEmailProvider-sqlscripts.sql` (modified) — Step 5b INSERT now uses `'CONFIG'` GridType; description text updated; new idempotent Step 5c backfills any prior `EMAILPROVIDERCONFIG` row whose `GridTypeId` still points at `FLOW`
- **Deviations from spec**:
  - **ISSUE-9 not patched** — the existing FE in `sending-identity-dialog.tsx:106-111` already strictly blocks `fromEmail` outside `@{sendingDomainName}`. That's stricter than the prompt's "non-blocking warn" request but is the safer behavior; left unchanged. Minor divergence: BE Save validator (in `SaveCompanyEmailProvider.cs:51-59`) is more permissive (also allows `.{sendingDomainName}` subdomain suffix) — flagged as informational, not blocking.
  - **ISSUE-4 deferred** — prompt itself defers credential-rotation audit logging as a future enhancement tied to platform audit infra; not implemented.
- **Known issues opened**: None new.
- **Known issues closed**: ISSUE-1, ISSUE-2, ISSUE-3, ISSUE-5.
- **Known issues verified (no change)**: ISSUE-6, ISSUE-7, ISSUE-10.
- **Next step**: (none — COMPLETED). Optional follow-ups recorded in §⑫: unit tests for `SensitiveFieldMasking.MaskCredentials` + `PreserveSensitiveFields`; unit test for status-banner relative-time output. The seed Step 5c backfill should be exercised against any tenant DB whose `EMAILPROVIDERCONFIG` row was seeded by the original FLOW INSERT.

### Session 2 — 2026-05-28 — FIX — COMPLETED

- **Scope**: Runtime crash on page load — `MasterDatasByTypeCode` query selected `masterDataId` directly on `BaseApiResponseOfIEnumerableOfMasterDataResponseDto`, causing GraphQL field-resolution error. Switched provider catalog fetch to the canonical `MASTERDATAS_QUERY` + `advancedFilter { MasterDataType.TypeCode = "EMAILPROVIDER" }` pattern used by `custom-integration-workshop.tsx` (#87 Integration Marketplace). Mid-session follow-up: BE rejected initial fix with `"The required input field id is missing"` — `id` field is mandatory on BOTH the outer `advancedFilter` object AND each rule (matches the `#87` reference). Added `id: "1"` to both levels.
- **Files touched**:
  - FE: `PSS_2.0_Frontend/src/presentation/components/page-components/setting/communicationconfig/emailproviderconfig/provider-card-selector.tsx` (modified) — replaced inline `gql` with import from `MASTERDATAS_QUERY`; supplied `pageSize/pageIndex/sortDescending/sortColumn/advancedFilter` variables (with `id` on filter and rule); read providers from `result.data` (BaseApiResponse wrapper).
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-11.
- **Next step**: (none — COMPLETED). User to refresh `pnpm dev` and confirm 4 provider cards render in Card 1.

### Session 3 — 2026-05-28 — FIX+UI+ENHANCE — COMPLETED

- **Scope**: Triple-bundled session.
  - (a) FIX: legacy CompanyEmailProvider record invisible because `GetActiveCompanyEmailProviderHandler` filtered strictly `IsDefault == true` — relaxed to "any non-deleted row for this tenant, prefer IsDefault=true".
  - (b) UI: only SendGrid is supported in the current build — disabled Mailgun / AWSSES / SMTP cards with "Coming soon" chip.
  - (c) ENHANCE: replaced mocked stats constants with real aggregations from `EmailSendQueue` (daily/monthly counts, bounce rate, spam rate, monthly cost) and added two new DTO fields (`MonthlyEmailCostAmount`, `RemainingMonthlySends`).
- **Files touched**:
  - BE (modified, 2):
    - `PSS_2.0_Backend/.../NotifyBusiness/CompanyEmailProviders/Queries/GetCompanyEmailProviderStats.cs` — both handlers in this file:
      - `GetActiveCompanyEmailProviderHandler`: dropped `IsDefault == true` filter, added `OrderByDescending(IsDefault).ThenByDescending(ModifiedDate).ThenByDescending(CreatedDate)`.
      - `GetEmailProviderStatsHandler`: replaced 6 mocked constants with EF aggregations over `EmailSendQueues` (filtered by `CompanyEmailProviderId == providerId AND IsDeleted == false AND SendAt >= window`); uses UTC day/month boundaries per `feedback_db_utc_only`.
    - `PSS_2.0_Backend/.../Schemas/NotifySchemas/CompanyEmailProviderSchemas.cs` — added 2 fields to `CompanyEmailProviderStatsDto`: `MonthlyEmailCostAmount` (decimal), `RemainingMonthlySends` (int?).
  - FE (modified, 5):
    - `PSS_2.0_Frontend/.../emailproviderconfig/provider-card-selector.tsx` — added `ENABLED_PROVIDERS = { "SENDGRID" }`; non-enabled cards render disabled with `opacity-60 cursor-not-allowed` + "Coming soon" chip; per-card interactive flag.
    - `PSS_2.0_Frontend/.../emailproviderconfig/usage-bars.tsx` — new `remainingMonthlySends` prop; renders "Remaining this month: {N}" hint below the monthly bar.
    - `PSS_2.0_Frontend/.../emailproviderconfig/reputation-cards.tsx` — added 6th "Monthly Cost" tile (`ph:currency-dollar`); grid changed from `xl:grid-cols-5` → `xl:grid-cols-6`.
    - `PSS_2.0_Frontend/.../emailproviderconfig/email-provider-config-page.tsx` — `stats` now reads `statsData?.result?.data` (was `statsData?.result` — latent bug surfaced by ISSUE-11's lesson); UsageBars receives `remainingMonthlySends={stats?.remainingMonthlySends}`.
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/notify-queries/CompanyEmailProviderQuery.ts` — `COMPANY_EMAIL_PROVIDER_STATS_QUERY` wrapped in `data { ... }` (was selecting fields on `BaseApiResponse` wrapper — same shape bug as ISSUE-11); added `dailyUsagePercentage`, `monthlyUsagePercentage`, `lastEmailSentAt`, `monthlyEmailCostAmount`, `remainingMonthlySends`.
    - `PSS_2.0_Frontend/src/domain/entities/notify-service/CompanyEmailProviderDto.ts` — `CompanyEmailProviderStatsDto` interface extended with the 5 new optional fields (`dailyUsagePercentage`, `monthlyUsagePercentage`, `lastEmailSentAt`, `monthlyEmailCostAmount`, `remainingMonthlySends`).
- **Deviations from spec**: None. The DTO additions are additive (no breaking changes). IP/Domain reputation remain SERVICE_PLACEHOLDER (annotated inline) since those come from the provider's API.
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-12, ISSUE-13, ISSUE-14.
- **Verification**: `dotnet build` PASS (only pre-existing CS8601 warning unrelated to this work); `pnpm tsc --noEmit` 0 errors in the touched files.
- **Next step**: (none — COMPLETED). User to refresh `pnpm dev` and verify:
  - (1) Existing CompanyEmailProvider record now hydrates the form (Card 1's selected provider, Card 5's limits, Card 4's identities).
  - (2) Only the SendGrid card is clickable; Mailgun / AWSSES / SMTP show "Coming soon" chip.
  - (3) Card 5 shows real Daily/Monthly counts + "Remaining this month: N" hint.
  - (4) Card 6 shows 6 tiles including "Monthly Cost: $X.XX".

### Session 4 — 2026-05-28 — FIX — COMPLETED

- **Scope**: Runtime crash on Card 3 (Sending Domain) — `sendingDomainDnsRecords` query had the same wrapper-shape bug as ISSUE-11/14 plus a field-name mismatch against the BE `EmailDnsRecordDto`. Surfaced after S3 once the Sending Domain card became visible.
- **Files touched**:
  - FE:
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/notify-queries/CompanyEmailProviderQuery.ts` (modified) — `SENDING_DOMAIN_DNS_RECORDS_QUERY` wrapped in `data { ... }`; selection renamed `type → recordType`, `name → recordName`, `value → recordValue`, `status → isVerified` to match the BE DTO shape.
    - `PSS_2.0_Frontend/.../emailproviderconfig/dns-records-table.tsx` (modified) — row type signature + render swapped to the new property names; `record.status === "Verified"` swapped for `record.isVerified` boolean check; reads `data?.result?.data` from the BaseApiResponse wrapper.
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-15.
- **Verification**: `pnpm tsc --noEmit` 0 errors in touched files.
- **Next step**: (none — COMPLETED). User to refresh `pnpm dev` and confirm Card 3 (Sending Domain) renders its 4 sample DNS rows (CNAME × 3 + TXT × 1) with Verified badges.

### Session 5 — 2026-05-28 — UI+ENHANCE — COMPLETED

- **Scope**: Two follow-ups on top of Session 3/4. (a) Premium full-width page polish — drop `max-w-5xl`, upgrade card chrome, refine status banner & sticky footer. (b) Currency-aware Monthly Cost tile — render in the **provider's configured currency** (CompanyEmailProvider.Currency) with a `≈ X` secondary line in the **company display currency** (CompanySessionSettings) when a direct-pair FX rate exists.
- **Files touched**:
  - FE (modified, 4):
    - `PSS_2.0_Frontend/.../emailproviderconfig/email-provider-config-page.tsx` —
      - Card wrapper: `rounded-xl shadow-sm hover:shadow-md`; header strip is gradient + tinted icon pill (`h-7 w-7 rounded-md bg-primary/10`); body padding bumped to `p-5 sm:p-6`.
      - Scroll container: full-width body with `bg-gradient-to-b from-muted/20`; container padding `px-4 sm:px-6 lg:px-8`; vertical spacing `space-y-5`; bottom padding `pb-28` to clear new footer.
      - Status Banner: gradient bg per variant, circular icon badge, font-medium copy.
      - Sticky footer: `backdrop-blur-sm shadow-lg` and follows the new full-width container (no more `max-w-5xl` centering).
      - Card 6 (ReputationCards) now receives `providerCurrencyId / providerCurrencyCode / providerCurrencySymbol` from `activeProvider.currency`.
    - `PSS_2.0_Frontend/.../emailproviderconfig/reputation-cards.tsx` —
      - Added 3 new props for provider currency.
      - Subscribes to `useCompanySettingsSession` for company base currency (id + code).
      - Queries `GET_CURRENT_FX_RATE` (direct-pair) only when provider currency ≠ company currency AND cost > 0; `fetchPolicy: cache-first`.
      - Monthly Cost value rendered via `formatCurrency(amount, { currencyCode, currencySymbol })` using provider currency. Detail line shows `≈ formatCurrency(amount × fxRate, { currencyCode: companyCurrencyCode })` when FX pair available, "FX rate unavailable" when needed but missing, or "Sum of EmailCost this month" otherwise.
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/notify-queries/CompanyEmailProviderQuery.ts` — added `currencySymbol` to `currency { ... }` selection in both `COMPANY_EMAIL_PROVIDER_ACTIVE_QUERY` and `COMPANYEMAILPROVIDER_BY_ID_QUERY`.
- **Deviations from spec**: None. Layout change is purely visual; functional API surface unchanged.
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-16, ISSUE-17.
- **Verification**: `pnpm tsc --noEmit` 0 errors in touched files.
- **Next step**: (none — COMPLETED). User to refresh `pnpm dev` and verify:
  - (1) Page now fills the full viewport width with comfortable side padding.
  - (2) Cards have a noticeably richer chrome (rounded-xl + shadow + gradient header strip + icon pill).
  - (3) Monthly Cost tile shows the value in the provider's currency (e.g. `$12.34` for USD-configured providers); if the company base currency differs and a direct-pair FX rate exists, the StatCard detail reads `≈ ₹1,025.45` (or equivalent).
  - (4) If the FX pair is missing the detail reads "FX rate unavailable" (never falls back to USD-triangulation per `[[feedback-fx-direct-pair]]`).

### Session 6 — 2026-05-28 — UI — COMPLETED

- **Scope**: Replaced generic Phosphor provider icons with real brand marks from Iconify's full-color `logos:` set.
- **Files touched**:
  - FE (modified, 2):
    - `PSS_2.0_Frontend/.../emailproviderconfig/provider-registry.ts` — icon mappings swapped: SendGrid → `logos:sendgrid`, Mailgun → `logos:mailgun-icon`, AWS SES → `logos:aws`. SMTP retained `ph:gear` (no brand). Added `iconHasNativeColor: boolean` field to `ProviderRegistryEntry` interface so the card-selector knows whether to apply `colorClass` text-color tint (false for native-color SVGs).
    - `PSS_2.0_Frontend/.../emailproviderconfig/provider-card-selector.tsx` — icon tile branches on `entry.iconHasNativeColor`: native-color brand SVGs render in a neutral `border border-border bg-white` tile (so brand colors read), monochrome glyphs use the existing `bgClass` + `colorClass` combo. Icon size bumped `h-6 w-6` → `h-7 w-7`.
- **Deviations from spec**: None. Iconify icons load on-demand from the API (the codebase already uses this pattern for `ph:` — no `@iconify/json` install needed).
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-18.
- **Verification**: `pnpm tsc --noEmit` 0 errors in touched files.
- **Next step**: (none — COMPLETED). User to refresh `pnpm dev` and confirm Card 1 shows the real SendGrid / Mailgun / AWS brand marks (each in their native colors on a white tile) plus the generic gear for SMTP.

### Session 7 — 2026-05-28 — UI+Seed — COMPLETED

- **Scope**: Expanded provider catalog from 4 → 6. Added SparkPost (real SaaS, brand silhouette + orange tint) and MailKit (.NET library — not a SaaS, generic envelope + emerald tint, description "Self-hosted .NET MailKit dispatcher"). Both stay in the "Coming soon" disabled set (only SendGrid is wired); UI just publishes the roadmap.
- **Files touched**:
  - FE (modified, 1):
    - `PSS_2.0_Frontend/.../emailproviderconfig/provider-registry.ts` — added `SPARKPOST` entry (`simple-icons:sparkpost`, `text-orange-600`, `bg-orange-50`, "High-deliverability transactional email", "Up to 100K/month") and `MAILKIT` entry (`ph:envelope-simple-open`, `text-emerald-600`, `bg-emerald-50`, "Self-hosted .NET MailKit dispatcher", "Self-hosted").
  - DB (modified, 1):
    - `PSS_2.0_Backend/.../sql-scripts-dyanmic/CompanyEmailProvider-sqlscripts.sql` — Step 2 VALUES block extended from 4 → 6 rows; refreshed `IconKey` for SendGrid/Mailgun/AWSSES to the new `logos:` values for parity with the FE registry (`logos:sendgrid`, `logos:mailgun-icon`, `logos:aws`). Header comment also bumped 4 → 6 row count. INSERT remains idempotent via `NOT EXISTS` per `DataValue`, so re-runs add only the two new rows on existing DBs.
- **Deviations from spec**: None. New providers do not change ENABLED_PROVIDERS set — only SendGrid remains clickable.
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-19.
- **Verification**: `pnpm tsc --noEmit` 0 errors in touched files.
- **Next step**: (none — COMPLETED). User to (1) re-run `CompanyEmailProvider-sqlscripts.sql` on the dev DB to seed the 2 new EMAILPROVIDER rows, then (2) refresh `pnpm dev` to confirm 6 cards render in Card 1 (only SendGrid clickable; SparkPost / MailKit + the original Mailgun / AWS SES / SMTP show "Coming soon").
