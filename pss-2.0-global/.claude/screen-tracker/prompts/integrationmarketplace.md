---
screen: IntegrationMarketplace
registry_id: 87
module: SETTING
status: COMPLETED
scope: FULL
screen_type: CONFIG
config_subtype: SETTINGS_PAGE
storage_pattern: definition-list
save_model: save-all
complexity: High
new_module: NO
planned_date: 2026-05-18
completed_date: 2026-05-19
last_session_date: 2026-05-19
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (sub-type: hybrid SETTINGS_PAGE with embedded definition-list)
- [x] Business context read (catalog hub + webhook builder; tenant-scoped; admin-only)
- [x] Storage model identified (1 new entity `CustomIntegration` + 1 MasterDataType seed `INTEGRATIONPROVIDER`)
- [x] Save model chosen (catalog cards are nav-only; Custom Integration form = per-row save-all)
- [x] Sensitive fields & role gates identified (no secrets stored — OAuth/API-key paths route to existing screens)
- [x] FK targets resolved (4 status-source entities verified: CompanyPaymentGateway / CompanyEmailProvider / SmsSetting / WhatsAppSetting)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (catalog hub vs new master entity decision confirmed)
- [x] Solution Resolution complete (sub-type confirmed, save model confirmed)
- [x] UX Design finalized (catalog grid + featured row + custom-integration card)
- [x] User Approval received
- [x] Backend code generated
- [x] Backend wiring complete
- [x] Frontend code generated
- [x] Frontend wiring complete
- [x] DB Seed script generated (MasterDataType + 26 provider rows + Menu already seeded)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [x] dotnet build — 0 errors in #87 files (5 pre-existing errors in unrelated #88/#89 PROMPT_READY screens, see ISSUE-12)
- [ ] pnpm dev — page loads at `/{lang}/setting/integration/integrationmarketplace`
- [ ] Featured row + 7 category sections render correctly
- [ ] Category pills filter visible sections
- [ ] Search filters cards by name within visible sections
- [ ] "Connected" badge shows correctly for providers with active backing rows (Stripe / SendGrid / Twilio / WhatsApp / etc.)
- [ ] "Configure" on Connected provider routes to its backing screen with correct deep-link
- [ ] "Connect" on Available provider opens Connect API modal (V1 = SERVICE_PLACEHOLDER toast; V2 = real OAuth/key store)
- [ ] Detail modal shows Features / Configuration / Sync Activity for Connected providers
- [ ] Custom Integration card: Create / Test / Edit / Toggle / Delete persist correctly
- [ ] Custom Integration list renders below the form (newly added)
- [ ] DB seed — INTEGRATIONPROVIDER MasterDataType + ≥25 provider rows seeded
- [ ] Menu visible in sidebar at `Settings → Integration → Marketplace`
- [ ] Empty / loading / error states render

---

## ① Screen Identity & Context

**Consumer**: All agents — sets the stage

Screen: IntegrationMarketplace
Module: SETTING
Schema: `sett`
Group: `Setting`

Business: The Integration Marketplace is a **single-page hub** that catalogs every third-party integration PSS 2.0 can talk to, grouped by category (Payment / Accounting / Communication / CRM / Productivity / Analytics / Custom). It serves two distinct purposes: **(1) a navigation surface** — each catalog card either deep-links to an existing dedicated config screen (Stripe → #167 Payment Gateways; SendGrid → #84 Email Provider Config; Twilio → #157 SMS Setup; WhatsApp → #34 WhatsApp Setup; etc.) or opens a Connect API modal for providers that don't yet have a dedicated screen — and **(2) a webhook automation workshop** — admins compose lightweight "when X happens, do Y" automations (e.g. "When donation > $1000, send Slack alert") without leaving the page. Edited by **BUSINESSADMIN only**, browsed occasionally during initial setup and quarterly review. The "Connected/Available" badge on each card is **computed at query time** by joining against the 4 backing tables that already exist (CompanyPaymentGateway / CompanyEmailProvider / SmsSetting / WhatsAppSetting) — this screen owns NO secret-credential storage itself. What's unique about its UX: it's the only screen in the tenant where the user surveys the full integration landscape, so the visual treatment must communicate **category breadth + connection state + path-to-configure** clearly. Failures: a wrong "Connected" badge misleads admins into skipping a real setup; a broken webhook automation silently swallows donation events. Role gate is hard: even a STAFFADMIN cannot land here.

> **Why this screen is unusual within CONFIG**: it's NOT a single tenant-config record. It's a **read-mostly catalog browser** (status computed from sibling tables) with an embedded definition-list (CustomIntegration rows). The closest fit is SETTINGS_PAGE (because the catalog itself is read-only configuration), but storage is `definition-list` for the webhook automations. Solution Resolver should treat the catalog as static data + computed status, and CRUD only the CustomIntegration entity.

---

## ② Storage Model

**Storage Pattern**: `definition-list` (for `CustomIntegrations`) + read-only catalog (rendered from MasterDataType rows + status computed from sibling tables — NO new table for the catalog itself in V1)

### New Table: `sett."CustomIntegrations"`

Primary table for webhook automations defined in the "Custom Integration" section of the mockup.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CustomIntegrationId | int | — | PK | — | Identity column |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (from HttpContext on Create) |
| IntegrationName | string | 100 | YES | — | Free-text label (e.g. "Slack alert for major gifts") |
| TriggerEventCode | string | 60 | YES | MasterData.Code where MasterDataType=`INTEGRATIONTRIGGER` | e.g. DONATION_CREATED / CONTACT_CREATED / EVENT_REGISTERED / CAMPAIGN_GOAL_REACHED / VOLUNTEER_SIGNED_UP / MEMBERSHIP_RENEWED |
| ActionTypeCode | string | 60 | YES | MasterData.Code where MasterDataType=`INTEGRATIONACTION` | e.g. WEBHOOK / CRM_RECORD / SLACK_MSG / GOOGLE_SHEET_ROW / EMAIL / PROJECT_TASK |
| WebhookUrl | string? | 500 | conditional | — | Required when ActionTypeCode='WEBHOOK'; nullable otherwise |
| DataPayloadJson | string | jsonb | YES | — | JSON array of field codes to include — e.g. `["DonationId","Amount","ContactName"]` |
| FilterField | string? | 60 | NO | — | e.g. 'Amount' / 'Campaign' / 'ContactType' — nullable |
| FilterOperator | string? | 20 | conditional | — | 'gt' / 'lt' / 'eq' / 'contains' — required when FilterField set |
| FilterValue | string? | 200 | conditional | — | required when FilterField set |
| IsActive | bool | — | YES | — | Default true. Toggle from row (Pause / Resume) |
| LastTriggeredAt | DateTime? | — | NO | — | Set when trigger fires (V2 — V1 keeps null) |
| TriggerCount | int | — | YES | — | Default 0. Incremented when trigger fires (V2) |

**Indexes**:
- Filtered unique on `(CompanyId, IntegrationName)` WHERE `IsDeleted = false` — duplicate names per tenant blocked
- Non-unique on `(CompanyId, TriggerEventCode, IsActive)` — trigger dispatch lookup (V2)
- Standard audit columns inherited from `Entity` base

### MasterDataType rows to seed (NOT new tables — use existing MasterData infrastructure)

| MasterDataType | Description | Rows to seed |
|----------------|-------------|--------------|
| `INTEGRATIONPROVIDER` | The catalog of all third-party providers shown on cards | 25+ rows — see §④ Catalog Definition table |
| `INTEGRATIONTRIGGER` | Trigger events for custom integrations | 6 rows: DONATION_CREATED / CONTACT_CREATED / EVENT_REGISTERED / CAMPAIGN_GOAL_REACHED / VOLUNTEER_SIGNED_UP / MEMBERSHIP_RENEWED |
| `INTEGRATIONACTION` | Action types for custom integrations | 6 rows: WEBHOOK / CRM_RECORD / SLACK_MSG / GOOGLE_SHEET_ROW / EMAIL / PROJECT_TASK |
| `INTEGRATIONPAYLOADFIELD` | Available data fields admins can include in a payload | 6 rows: DONATION_ID / AMOUNT / CONTACT_NAME / PURPOSE / CAMPAIGN / TIMESTAMP |
| `INTEGRATIONFILTERFIELD` | Filterable trigger fields | 3 rows: AMOUNT / CAMPAIGN / CONTACTTYPE |
| `INTEGRATIONFILTEROP` | Filter operators | 3 rows: gt (Greater than) / lt (Less than) / eq (Equals) / contains (Contains) |

> Why MasterData instead of new tables: The catalog is a slowly-changing reference list (new providers added quarterly at most). Using existing `sett.MasterData` infrastructure means admins can extend the catalog via the #76 Master Data screen without code deploys, and we don't introduce a new entity just to hold static rows. The `DataSetting` JSON column on MasterData carries per-provider extras (category / iconClass / brandColor / configRoute / providerType / isFeatured).

### Computed Catalog Status — NOT stored

Card "Connected/Available" badge is computed at query time inside `GetIntegrationMarketplaceState`:

| Provider category | Backing table | Status rule |
|-------------------|---------------|-------------|
| Payment (Stripe, PayPal, Razorpay, Square, Authorize.net, Paytm) | `fund."CompanyPaymentGateways"` + master `fund."PaymentGateways"` | `Connected` when row exists with matching gateway code + `IsActive=true` + `IsDeleted=false`; else `Available` |
| Email (SendGrid) | `notify."CompanyEmailProviders"` | `Connected` when row with matching `Provider` + `IsActive=true`; else `Available` |
| SMS (Twilio) | `notify."SmsSettings"` | `Connected` when row with matching `ProviderType` + `IsActive=true` |
| WhatsApp Business | `notify."WhatsAppSettings"` | `Connected` when row with `IsActive=true` |
| Mailchimp / QuickBooks / Xero / Tally / Zoho Books / Salesforce / HubSpot / Slack / Teams / Zapier / GA / Power BI / Mixpanel / Hotjar / Google Workspace / Google Contacts / Microsoft 365 | **NO backing table in V1** | Always `Available` — Connect button = SERVICE_PLACEHOLDER toast: "Connection storage for {provider} ships in a future release" |

> **V2 deferral**: When the first of those "no backing table" providers needs real connection storage, introduce a generic `sett."CompanyIntegrationConnection"` table (CompanyId / ProviderCode / EncryptedCredentialsJson / Environment / ConnectedAt). Log as `ISSUE-1` in §⑫.

### Sync Activity (Detail modal)

The Configuration / Sync Activity panels in the detail modal (e.g. Stripe's "45 payments / $12,340 / 2 failed") are READ-ONLY rollups of:

| Stat | Source | Aggregate |
|------|--------|-----------|
| Successful syncs | `fund."GlobalDonations"` where `PaymentGatewayId=Stripe` AND `DonationDate >= NOW()-7d` AND `PaymentStatus='Success'` | COUNT |
| Amount | same | SUM(Amount) |
| Failed | same with PaymentStatus='Failed' | COUNT |

Detail modals for email/SMS/WhatsApp providers query their respective send-log tables (out of scope for V1 — render placeholder cards with "Activity tracking ships in a future release"). Log as `ISSUE-2`.

---

## ③ FK Resolution Table

**Status-source entities** (used in `GetIntegrationMarketplaceState` aggregate query):

| FK / Source | Target Entity | Entity File Path | GQL Query Name | Display Field | Response Type |
|-------------|---------------|------------------|----------------|---------------|---------------|
| Status: Payment | CompanyPaymentGateway | Base.Domain/Models/DonationModels/CompanyPaymentGateway.cs | (computed inline — no public GQL) | — | inline projection |
| Status: Email | CompanyEmailProvider | Base.Domain/Models/NotifyModels/CompanyEmailProvider.cs | (computed inline) | — | inline projection |
| Status: SMS | SmsSetting | Base.Domain/Models/NotifyModels/SmsSetting.cs | (computed inline) | — | inline projection |
| Status: WhatsApp | WhatsAppSetting | Base.Domain/Models/NotifyModels/WhatsAppSetting.cs | (computed inline) | — | inline projection |
| Detail stats: Payment | GlobalDonation | Base.Domain/Models/DonationModels/GlobalDonation.cs | (computed inline) | — | inline COUNT/SUM |

**FK fields on `CustomIntegration` itself**: none beyond CompanyId — all field references are by Code (string) into MasterData, NOT by FK Id. This avoids contaminating the entity with 5+ FK columns and matches the convention used by `Field.FieldType` / `Grid.GridType`.

**Required GraphQL queries for FE dropdowns** (already exist, reuse — no new queries needed):
| Dropdown | GQL Query | Filter |
|----------|-----------|--------|
| Trigger Event | `GetMasterDatasByTypeId` from #76 | `masterDataTypeCode = 'INTEGRATIONTRIGGER'` |
| Action Type | same | `masterDataTypeCode = 'INTEGRATIONACTION'` |
| Data field checkboxes | same | `masterDataTypeCode = 'INTEGRATIONPAYLOADFIELD'` |
| Filter field | same | `masterDataTypeCode = 'INTEGRATIONFILTERFIELD'` |
| Filter operator | same | `masterDataTypeCode = 'INTEGRATIONFILTEROP'` |

---

## ④ Business Rules & Validation

### Catalog Definition (seed in DB)

| ProviderCode | Category | Display Name | Icon Class | Brand Color | Featured? | Backing Status Source | Config Route (Connected click) |
|--------------|----------|--------------|------------|-------------|-----------|----------------------|--------------------------------|
| STRIPE | payment | Stripe | fa-brands fa-stripe-s | #635bff | YES | CompanyPaymentGateway WHERE gateway='Stripe' | `setting/paymentconfig/companypaymentgateway?provider=STRIPE` |
| PAYPAL | payment | PayPal | fa-brands fa-paypal | #003087 | NO | CompanyPaymentGateway WHERE gateway='PayPal' | `setting/paymentconfig/companypaymentgateway?provider=PAYPAL` |
| RAZORPAY | payment | Razorpay | fa-solid fa-r | #2d88ff | NO | CompanyPaymentGateway WHERE gateway='Razorpay' | `setting/paymentconfig/companypaymentgateway?provider=RAZORPAY` |
| SQUARE | payment | Square | fa-solid fa-square | #3e4348 | NO | CompanyPaymentGateway WHERE gateway='Square' | `setting/paymentconfig/companypaymentgateway?provider=SQUARE` |
| AUTHNET | payment | Authorize.net | fa-solid fa-a | #0078b4 | NO | CompanyPaymentGateway WHERE gateway='Authorize.Net' | `setting/paymentconfig/companypaymentgateway?provider=AUTHNET` |
| PAYTM | payment | Paytm | fa-solid fa-p | #00baf2 | NO | CompanyPaymentGateway WHERE gateway='Paytm' | `setting/paymentconfig/companypaymentgateway?provider=PAYTM` |
| QUICKBOOKS | accounting | QuickBooks | fa-solid fa-book | #2ca01c | YES | (none — V1 always Available) | (none — Connect modal SERVICE_PLACEHOLDER) |
| XERO | accounting | Xero | fa-solid fa-x | #13b5ea | NO | (none — V1) | SERVICE_PLACEHOLDER |
| TALLY | accounting | Tally | fa-solid fa-t | #d22a31 | NO | (none — V1) | SERVICE_PLACEHOLDER |
| ZOHOBOOKS | accounting | Zoho Books | fa-solid fa-z | #e42527 | NO | (none — V1) | SERVICE_PLACEHOLDER |
| MAILCHIMP | communication | Mailchimp | fa-brands fa-mailchimp | #ffe01b | YES | (none — V1) | SERVICE_PLACEHOLDER |
| SENDGRID | communication | SendGrid | fa-solid fa-paper-plane | #1a82e2 | NO | CompanyEmailProvider WHERE Provider='SendGrid' | `setting/communicationconfig/emailproviderconfig?provider=SENDGRID` |
| TWILIO | communication | Twilio | fa-solid fa-phone | #f22f46 | NO | SmsSetting WHERE ProviderType='Twilio' | `setting/communicationconfig/smssetup?provider=TWILIO` |
| WHATSAPP | communication | WhatsApp Business | fa-brands fa-whatsapp | #25d366 | NO | WhatsAppSetting WHERE IsActive=true | `setting/communicationconfig/whatsappsetup` |
| SALESFORCE | crm | Salesforce | fa-brands fa-salesforce | #00a1e0 | NO | (none — V1) | SERVICE_PLACEHOLDER |
| HUBSPOT | crm | HubSpot | fa-brands fa-hubspot | #ff7a59 | NO | (none — V1) | SERVICE_PLACEHOLDER |
| GOOGLECONTACTS | crm | Google Contacts | fa-brands fa-google | #4285f4 | NO | (none — V1) | SERVICE_PLACEHOLDER |
| MICROSOFT365 | crm | Microsoft 365 | fa-brands fa-microsoft | #0078d4 | NO | (none — V1) | SERVICE_PLACEHOLDER |
| GOOGLEWORKSPACE | productivity | Google Workspace | fa-brands fa-google | #4285f4 | NO | (none — V1) | SERVICE_PLACEHOLDER |
| SLACK | productivity | Slack | fa-brands fa-slack | #4a154b | NO | (none — V1) | SERVICE_PLACEHOLDER |
| MSTEAMS | productivity | Microsoft Teams | fa-brands fa-microsoft | #6264a7 | NO | (none — V1) | SERVICE_PLACEHOLDER |
| ZAPIER | productivity | Zapier | fa-solid fa-bolt | #ff4a00 | NO | (none — V1) | SERVICE_PLACEHOLDER |
| GA | analytics | Google Analytics | fa-solid fa-chart-line | #f9ab00 | NO | (none — V1) | SERVICE_PLACEHOLDER |
| POWERBI | analytics | Power BI | fa-solid fa-chart-bar | #f2c811 | NO | (none — V1) | SERVICE_PLACEHOLDER |
| MIXPANEL | analytics | Mixpanel | fa-solid fa-m | #7856ff | NO | (none — V1) | SERVICE_PLACEHOLDER |
| HOTJAR | analytics | Hotjar | fa-solid fa-fire | #fd3a5c | NO | (none — V1) | SERVICE_PLACEHOLDER |

> Seed all 26 rows as MasterData under MasterDataType `INTEGRATIONPROVIDER`. Store category / icon / brandColor / isFeatured / configRoute / backingTable / backingFilter as JSON in `DataSetting`.

### CustomIntegration Rules

**Required Field Rules:**
- `IntegrationName`, `TriggerEventCode`, `ActionTypeCode`, `DataPayloadJson` (must be non-empty JSON array) are always required
- `WebhookUrl` is required when `ActionTypeCode = 'WEBHOOK'`; **ignored** for other action types
- `FilterField`, `FilterOperator`, `FilterValue` are all-or-nothing — if any is set, all three must be set

**Conditional Rules:**
- DataPayloadJson MUST be a JSON array of strings — each string MUST exist as a Code under MasterDataType `INTEGRATIONPAYLOADFIELD`
- TriggerEventCode MUST exist as a Code under `INTEGRATIONTRIGGER`
- ActionTypeCode MUST exist as a Code under `INTEGRATIONACTION`
- WebhookUrl must be a valid HTTPS URL when present (http:// rejected — production-only validation)
- FilterValue type-checked against FilterField: 'Amount' → numeric; 'Campaign'/'ContactType' → string

**Unique Constraint:**
- `(CompanyId, IntegrationName)` unique among non-deleted rows — duplicate names rejected with friendly message

### Sensitive Fields

| Field | Sensitivity | Display | Save | Audit |
|-------|-------------|---------|------|-------|
| WebhookUrl | semi-secret (URL may contain auth token in querystring) | shown plain on Edit (admin viewing own setup) | normal POST | log on every CREATE / UPDATE / DELETE |
| (No API key / secret stored on CustomIntegration) | — | — | — | — |

> **By design**, this screen stores NO credentials for the catalog providers. The Connect modal opens for V1 providers without backing tables, and the Save & Connect button is wired to a SERVICE_PLACEHOLDER handler that toasts "Coming soon" — no DB write. When V2 ships the generic connection store, the modal handler swaps to real persistence.

### Dangerous Actions

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Delete Custom Integration | Soft-delete row (IsDeleted=true) | Modal "Delete '{name}'? This stops the automation immediately." | log |
| Disconnect (provider with backing table) | Routes user to the BACKING screen — no in-marketplace disconnect handler in V1 | — (handled by backing screen) | — |

### Role Gating

| Role | Sections Visible | Editable | Notes |
|------|------------------|----------|-------|
| BUSINESSADMIN | all | all | full access |
| All others | hidden — page returns 403 | — | hard role gate; no read-only fallback |

> Frontend hides the menu via ISMENURENDER capability; backend rejects mutations from non-BUSINESSADMIN with explicit 403.

### Workflow

None — CustomIntegration is a simple definition record. No draft/publish, no approval chain. IsActive toggle = pause/resume.

---

## ⑤ Screen Classification & Pattern Selection

**Screen Type**: CONFIG
**Config Sub-type**: `SETTINGS_PAGE` (with embedded definition-list workshop — see §⑥ for the hybrid blueprint)
**Storage Pattern**: `definition-list` (CustomIntegrations) + read-only catalog (MasterData + computed status)
**Save Model**: `save-all` per CustomIntegration row (form-level save), no save on catalog cards (they're nav-only or modal-trigger)

**Reason**: This is the canonical "settings hub with embedded workshop" shape — a static-mostly catalog browser used for navigation and status, plus a small definition-list CRUD for webhook automations. SETTINGS_PAGE is the closest sub-type because (a) there is no list-of-N grid as the primary surface, (b) the page is a single tenant-scoped configuration view, and (c) save semantics are simple (form save per webhook). Diverges from pure SETTINGS_PAGE only in that the catalog cards aren't editable fields — they're status surfaces + navigation. Document the hybrid in §⑫ so the next developer reading this template understands.

**Backend Patterns Required:**

For the **Marketplace state composite**:
- [x] `GetIntegrationMarketplaceState` query — returns `IntegrationMarketplaceStateDto { providers: ProviderCardDto[], customIntegrations: CustomIntegrationDto[] }`. Joins MasterData INTEGRATIONPROVIDER rows with the 4 backing tables (CompanyPaymentGateway / CompanyEmailProvider / SmsSetting / WhatsAppSetting) for status computation. Tenant-scoped via HttpContext.
- [x] `GetIntegrationProviderDetail` query — args `providerCode: String!`; returns ProviderDetailDto { features: string[], configuration: KeyValuePair[], syncActivity?: SyncActivityDto }. Configuration items are masked (`••••••••7890`-style) by inspecting the backing table; syncActivity computed from GlobalDonations / send-logs (V1 = donations only; rest return null).

For **CustomIntegration CRUD** (standard 11-file pattern):
- [x] Get{Entity}List query — paginated, default sort by CreatedDate desc
- [x] Get{Entity}ById query
- [x] Create{Entity} command
- [x] Update{Entity} command
- [x] Delete{Entity} command (soft delete)
- [x] Toggle{Entity}Status command (IsActive on/off)
- [x] Test{Entity} command — SERVICE_PLACEHOLDER for V1: posts mock payload to WebhookUrl with timeout, returns success/failure toast. Real signing + retry queue ships V2.
- [x] Tenant scoping via HttpContext on all
- [x] Audit-trail emission on Create/Update/Delete

For **Connect (V1 SERVICE_PLACEHOLDER)**:
- [x] `ConnectIntegrationProvider` mutation — args (providerCode, apiKey, apiSecret, environment). V1 behavior: logs the attempt, returns success toast, persists NOTHING. Documented in §⑫ as ISSUE-1.

**Frontend Patterns Required:**

- [x] Custom multi-section page (NOT RJSF modal, NOT 3-mode view-page)
- [x] Featured cards row (3 cards, slightly larger, "Featured" badge)
- [x] Category section pattern — section title with icon + count chip + grid of integration cards
- [x] Category pill filter strip (8 pills: All + 7 categories — controls section visibility)
- [x] Search input (filters cards by name within visible sections; preserves category filter)
- [x] Integration Card component (icon / brand color / name / one-line description / status badge / primary action button)
- [x] Detail Drawer / Modal (Features list / Configuration rows / Sync Activity stats / footer actions: Disconnect ↔ View Logs ↔ Save)
- [x] Connect API Modal (API Key / API Secret / Environment select — small modal, 480px)
- [x] Custom Integration card with multi-section form:
  - 2-column Trigger + Action selects
  - WebhookUrl input (conditional on Action='WEBHOOK')
  - Data to Send checkbox group
  - Filter row (field + op + value, inline)
  - Test + Save buttons
- [x] Custom Integration LIST below the form — shows existing rows with Name / Trigger / Action / Status badge / Edit / Toggle / Delete actions
- [x] Edit mode: clicking Edit on a list row populates the form above (single-form-instance pattern)

---

## ⑥ UI/UX Blueprint

### Layout Variant Stamp

`grid-only` is wrong for this screen. The layout variant is **`marketplace-hub`** — a custom variant that:
- Does NOT use FlowDataTable or AdvancedDataTable as its primary surface
- Has a Page Header (title + subtitle + search), then category pills, then featured row, then categorized card grids, then Custom Integration workshop card, then existing Custom Integrations list
- The integration cards are NOT in a shared grid — they're a static layout per the mockup

Stamp: `marketplace-hub` (new variant — first canonical for hybrid catalog + workshop screens). Update `_CONFIG.md` §⑥ Visual Uniqueness Rules to add this variant when this screen completes.

### Page Header

| Element | Content |
|---------|---------|
| Title | "Integration Marketplace" with `fa-solid fa-store` icon (mp-accent color #7c3aed) |
| Subtitle | "Connect PSS 2.0 with your favorite tools and services" |
| Right side | Search input (max-width 360px) — filters cards by name across all visible sections |

### Category Pills

8 pills, horizontally scrollable on mobile:
- All (default active) | Payment | Accounting | Communication | CRM | Productivity | Analytics | Custom

Active pill: mp-accent background, white text. Clicking a pill hides all sections NOT matching that category; "All" shows everything.

### Featured Row (only visible when category = All)

3 cards in a horizontal row — same chrome as regular int-card but with:
- "Featured" badge in top-right corner (mp-accent background, white text)
- Slightly larger (~250px wide × 90px tall)
- 3 cards: Stripe / QuickBooks / Mailchimp (driven by `isFeatured: true` in catalog DataSetting JSON)

### Category Sections (7 total)

Each section renders identically:
```
<section-title>
  <icon (semantic per category)> {Category Name}  <count-chip>{N} integrations</count-chip>
</section-title>
<int-grid>
  <int-card> × N
</int-grid>
```

| Category | Section Icon | Cards |
|----------|--------------|-------|
| Payment & Processing | `fa-solid fa-credit-card` | 6 — Stripe / PayPal / Razorpay / Square / Authorize.net / Paytm |
| Accounting | `fa-solid fa-calculator` | 4 — QuickBooks / Xero / Tally / Zoho Books |
| Communication | `fa-solid fa-comments` | 4 — Mailchimp / SendGrid / Twilio / WhatsApp Business |
| CRM & Data | `fa-solid fa-address-book` | 4 — Salesforce / HubSpot / Google Contacts / Microsoft 365 |
| Productivity | `fa-solid fa-puzzle-piece` | 4 — Google Workspace / Slack / Microsoft Teams / Zapier |
| Analytics | `fa-solid fa-chart-pie` | 4 — Google Analytics / Power BI / Mixpanel / Hotjar |
| Custom Integration | `fa-solid fa-code` | (NO cards — instead, the Custom Integration workshop card + the list of existing custom integrations) |

### Integration Card Component

Card layout (≈180px wide × 200px tall):
```
┌─────────────────────────────┐
│ [icon-box: brand color bg]  │  ← 48×48 round icon
│                             │
│ {Provider Name}             │  ← bold, 14px
│ {one-line description}      │  ← muted, 12px
│                             │
│ [status badge]              │  ← "Connected" (green) or "Available" (gray)
│                             │
│ [primary action button]     │  ← "Configure" (when Connected) or "Connect" (when Available)
└─────────────────────────────┘
```

Visual states:
- Connected: card has subtle green left-border accent, "Connected" badge is green with check-circle icon, primary button is "Configure" (mp-accent)
- Available: no accent, "Available" badge is gray with circle icon, primary button is "Connect" (outlined)
- Card hover: subtle lift (shadow + 1px translate-y)
- Whole card is clickable (opens detail modal for Connected, Connect modal for Available); button stops event propagation and routes specifically

### Card Click Behavior (CRITICAL — drives navigation)

| Click target | Provider status | Action |
|--------------|-----------------|--------|
| Card body OR "Configure" button | Connected | Open Detail Modal (loads `GetIntegrationProviderDetail`); FOOTER "Save" button routes to backing config screen with `?provider={code}` |
| Card body OR "Connect" button | Available, has backing screen | Route directly to backing config screen with `?provider={code}` (e.g. Stripe → `setting/paymentconfig/companypaymentgateway?provider=STRIPE`) |
| Card body OR "Connect" button | Available, no backing screen (V1) | Open Connect API Modal — Save button calls `ConnectIntegrationProvider` mutation = SERVICE_PLACEHOLDER toast |

> Backing config screens MUST read the `?provider=` query param and pre-select the matching gateway/provider on mount. Log as `ISSUE-3` for follow-up coordination with #167 / #84 / #157 / #34.

### Detail Modal (Connected providers)

Modal box 640px wide. Header: provider icon + name. Body sections:

| Section | Content |
|---------|---------|
| Status row | "Connected since {date}" + connected badge |
| Description | One-paragraph provider description (from catalog DataSetting) |
| Features | Bulleted list of capabilities (from catalog DataSetting) |
| Configuration | Key/Value rows: API Key (masked `••••••••XXXX` with Show toggle), Webhook URL, Mode (Production/Sandbox), Test Mode toggle |
| Sync Activity (last 7 days) | 3 stat chips: Success count / Amount / Failed count |

Footer: `[Disconnect]` (destructive outline, left) | `[View Logs]` (secondary, V1 SERVICE_PLACEHOLDER toast) | `[Save]` (primary — routes to backing config screen)

> Configuration rows are READ-ONLY in this modal. Real editing happens on the backing screen — clicking Save routes there. The modal is a status preview, not an editor. Log as `ISSUE-4` if user wants inline edit V2.

### Connect API Modal (Available providers without backing screen — V1 SERVICE_PLACEHOLDER)

Modal box 480px wide. Header: key icon + "Connect Integration". Body:
- Description: "Enter your API credentials to connect {Provider} with PSS 2.0."
- Field: API Key (text)
- Field: API Secret (password — masked input)
- Field: Environment (select — Production / Sandbox)

Footer: `[Cancel]` | `[Connect]` (primary, calls `ConnectIntegrationProvider` → V1 toast "Coming soon — connection storage ships next release", V2 persists to generic CompanyIntegrationConnection)

### Custom Integration Section (the workshop)

Section title: `<fa-code icon>` "Custom Integration"

**Workshop Card** (single card, full-width):
- Header: `<fa-webhook icon>` "Create Custom Integration" (or "Edit '{name}'" when row is being edited)
- Body — 6 form rows:

| Row | Layout | Fields |
|-----|--------|--------|
| 1 | 2-col | Trigger (select, hint "Choose the event that triggers this integration") + Action (select, hint "What should happen when the trigger fires") |
| 2 | full-width | Webhook URL (text input, type=url, placeholder `https://your-service.com/webhook`) — **visible only when Action='Send webhook to URL'** |
| 3 | full-width | Data to Send (6 inline checkboxes — Donation ID / Amount / Contact Name / Purpose / Campaign / Timestamp) |
| 4 | full-width | Filter (optional) — inline row: "Only trigger when" + field-select + operator-select + value-input |
| 5 | full-width | Integration Name (text input, max 100) — added on top of the mockup since mockup lacks an explicit name field but storage requires one; default value: `{TriggerEvent} → {Action}` auto-suggest |
| 6 | right-aligned | `[Test Integration]` (outline, fa-flask icon) + `[Save & Activate]` (primary, fa-check icon) |

> The mockup is missing an explicit "Integration Name" field. Add it (Row 5) above the action buttons. Default-fill it from `{TriggerLabel} → {ActionLabel}` when fields change so admins rarely retype. Log as `ISSUE-5`.

**Existing Custom Integrations List** (below the workshop card):

A compact table listing previously-saved custom integrations:

| Column | Width | Content |
|--------|-------|---------|
| Name | flex | IntegrationName |
| Trigger | 200px | Trigger label (resolved from MasterData) |
| Action | 160px | Action label (resolved from MasterData) |
| Filter | flex | "{FilterField} {op} {value}" or "—" |
| Status | 90px | "Active" green pill / "Paused" gray pill (from IsActive) |
| Actions | 140px | Edit (pencil) / Toggle (play/pause) / Delete (trash) icon buttons |

Empty state: "No custom integrations yet. Build your first automation above."

Loading state: 3 skeleton rows matching the table layout.

### User Interaction Flow

1. User opens `/{lang}/setting/integration/integrationmarketplace` → page loads → `GetIntegrationMarketplaceState` returns 26 provider cards (with computed status) + 0-N customIntegrations
2. User clicks "Payment" pill → only Payment section visible; featured row hides
3. User types "stri" in search → only Stripe card visible
4. User clicks Stripe card → Detail Modal opens with status / config / activity → clicks Save → routes to `setting/paymentconfig/companypaymentgateway?provider=STRIPE`
5. User clicks back → back to marketplace
6. User clicks PayPal "Connect" → routes to `setting/paymentconfig/companypaymentgateway?provider=PAYPAL` (Available + has backing screen)
7. User clicks Slack "Connect" → Connect API Modal opens → fills key + secret + env → clicks Connect → toast "Coming soon" (V1 SERVICE_PLACEHOLDER)
8. User scrolls to Custom Integration section → picks Trigger="When donation is created" + Action="Send Slack message" → Webhook URL field hides → Data to Send checkboxes default to first 3 ticked → Filter row stays optional → Integration Name auto-suggests "Donation Created → Send Slack message"
9. User edits name to "Major gift alert" → clicks Filter, picks Amount > $1000 → clicks Save & Activate → POST → toast → form clears → new row appears in list below
10. User clicks the new row's pause icon → IsActive=false → row shows "Paused" badge
11. User clicks Edit on a different row → form above populates with that row's values → header changes to "Edit '{name}'" → Cancel button appears → Save updates the row in place

### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading | Initial fetch | Skeleton: page header + pill strip + 7 category section skeletons (each = title row + 4-card grid skeleton) + workshop card skeleton |
| Empty (customIntegrations only) | First page load, no rows yet | "No custom integrations yet. Build your first automation above." inside the list area |
| Error | GET fails | Inline error card replacing the whole content area with retry button |
| Save error | POST fails | Toast at top-right + form keeps values + Save button re-enabled |

---

## ⑦ Substitution Guide

**Canonical reference**: `smssetup.md` (#157 — CONFIG/SETTINGS_PAGE with embedded child list — closest pattern, though SMS Setup has only 3 tabs vs. marketplace's hub layout). For the catalog-card pattern, no canonical exists — this screen establishes one. Mark in `_COMMON.md` post-completion.

| Canonical (SmsSetup-ish) | → This Entity | Context |
|--------------------------|---------------|---------|
| SmsSetting | CustomIntegration | Primary new entity |
| smsSetting | customIntegration | camelCase var name |
| SmsSettingId | CustomIntegrationId | PK column |
| smsSettingId | customIntegrationId | camelCase id var |
| notify | sett | DB schema |
| Notify | Setting | Backend group |
| NotifyModels | SettingModels | Domain folder |
| NotifyConfigurations | SettingConfigurations | EF config folder |
| NotifyBusiness | SettingBusiness | Application layer folder |
| NotifySchemas | SettingSchemas | DTO folder |
| Notify | Setting | API endpoint group folder |
| notify-service | setting-service | FE domain folder |
| notify-queries | setting-queries | FE GQL folder |
| notify-mutations | setting-mutations | FE GQL mutations |
| communicationconfig | integration | FE feFolder (under setting/) |
| smssetup | integrationmarketplace | FE entity-lower path |
| SMSSETUP | INTEGRATIONMARKETPLACE | Menu/Grid code |
| SET_COMMUNICATIONCONFIG | SET_INTEGRATION | Parent menu code |
| SETTING | SETTING | Module code (same) |

---

## ⑧ File Manifest

### Backend Files — NEW (definition-list pattern for CustomIntegration)

| # | File | Path |
|---|------|------|
| 1 | Entity | Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/CustomIntegration.cs |
| 2 | EF Config | Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/SettingConfigurations/CustomIntegrationConfiguration.cs |
| 3 | Schemas (DTOs) | Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/SettingSchemas/CustomIntegrationSchemas.cs |
| 4 | Schemas (Marketplace composite) | Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/SettingSchemas/IntegrationMarketplaceSchemas.cs |
| 5 | GetList Query | …/Base.Application/Business/SettingBusiness/CustomIntegrations/GetCustomIntegrationListQuery/GetCustomIntegrationList.cs |
| 6 | GetById Query | …/CustomIntegrations/GetCustomIntegrationByIdQuery/GetCustomIntegrationById.cs |
| 7 | Create Command | …/CustomIntegrations/CreateCustomIntegrationCommand/CreateCustomIntegration.cs |
| 8 | Update Command | …/CustomIntegrations/UpdateCustomIntegrationCommand/UpdateCustomIntegration.cs |
| 9 | Delete Command | …/CustomIntegrations/DeleteCustomIntegrationCommand/DeleteCustomIntegration.cs |
| 10 | Toggle Command | …/CustomIntegrations/ToggleCustomIntegrationCommand/ToggleCustomIntegrationStatus.cs |
| 11 | Test Command (SERVICE_PLACEHOLDER) | …/CustomIntegrations/TestCustomIntegrationCommand/TestCustomIntegration.cs |
| 12 | Marketplace State Query | …/SettingBusiness/IntegrationMarketplace/GetIntegrationMarketplaceStateQuery/GetIntegrationMarketplaceState.cs |
| 13 | Provider Detail Query | …/IntegrationMarketplace/GetIntegrationProviderDetailQuery/GetIntegrationProviderDetail.cs |
| 14 | Connect Provider Command (SERVICE_PLACEHOLDER) | …/IntegrationMarketplace/ConnectIntegrationProviderCommand/ConnectIntegrationProvider.cs |
| 15 | Validator: CustomIntegration | …/SettingBusiness/CustomIntegrations/Validators/CustomIntegrationRequestValidator.cs |
| 16 | CustomIntegration Mutations endpoint | Pss2.0_Backend/.../Base.API/EndPoints/Setting/Mutations/CustomIntegrationMutations.cs |
| 17 | CustomIntegration Queries endpoint | Pss2.0_Backend/.../Base.API/EndPoints/Setting/Queries/CustomIntegrationQueries.cs |
| 18 | Marketplace Queries endpoint | Pss2.0_Backend/.../Base.API/EndPoints/Setting/Queries/IntegrationMarketplaceQueries.cs |
| 19 | Marketplace Mutations endpoint | Pss2.0_Backend/.../Base.API/EndPoints/Setting/Mutations/IntegrationMarketplaceMutations.cs |
| 20 | EF Migration | Pss2.0_Backend/.../Base.Infrastructure/Migrations/{timestamp}_Add_CustomIntegrations.cs |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | Base.Domain/IApplicationDbContext.cs | `DbSet<CustomIntegration> CustomIntegrations { get; set; }` |
| 2 | Base.Infrastructure/Data/ApplicationDbContext.cs | DbSet property + apply CustomIntegrationConfiguration |
| 3 | Base.API/DecoratorProperties.cs | `DecoratorSettingModules` entry — `nameof(IApplicationDbContext.CustomIntegrations)` |
| 4 | Base.Application/Mappings/ApplicationMappings.cs (or SettingMappings.cs if it exists) | Mapster: CustomIntegration ↔ CustomIntegrationRequestDto + CustomIntegration ↔ CustomIntegrationResponseDto |
| 5 | Base.API/Program.cs OR ServicesRegistration | Auto-discovery via IQueries/IMutations — likely zero change needed; verify per #80 pattern |

### Frontend Files — NEW

| # | File | Path |
|---|------|------|
| 1 | DTO Types | Pss2.0_Frontend/src/domain/entities/setting-service/CustomIntegrationDto.ts |
| 2 | DTO Types (Marketplace composite) | Pss2.0_Frontend/src/domain/entities/setting-service/IntegrationMarketplaceDto.ts |
| 3 | GQL Query (CustomIntegration) | Pss2.0_Frontend/src/infrastructure/gql-queries/setting-queries/CustomIntegrationQuery.ts |
| 4 | GQL Query (Marketplace) | Pss2.0_Frontend/src/infrastructure/gql-queries/setting-queries/IntegrationMarketplaceQuery.ts |
| 5 | GQL Mutation (CustomIntegration) | Pss2.0_Frontend/src/infrastructure/gql-mutations/setting-mutations/CustomIntegrationMutation.ts |
| 6 | GQL Mutation (Marketplace Connect) | Pss2.0_Frontend/src/infrastructure/gql-mutations/setting-mutations/IntegrationMarketplaceMutation.ts |
| 7 | Marketplace Page (root) | Pss2.0_Frontend/src/presentation/components/page-components/setting/integration/integrationmarketplace/marketplace-page.tsx |
| 8 | Page Store (Zustand) | …/integrationmarketplace/integrationmarketplace-store.ts |
| 9 | Page Header component | …/integrationmarketplace/components/marketplace-header.tsx |
| 10 | Category Pills component | …/integrationmarketplace/components/category-pills.tsx |
| 11 | Featured Row component | …/integrationmarketplace/components/featured-row.tsx |
| 12 | Category Section component | …/integrationmarketplace/components/category-section.tsx |
| 13 | Integration Card component | …/integrationmarketplace/components/integration-card.tsx |
| 14 | Detail Modal component | …/integrationmarketplace/components/provider-detail-modal.tsx |
| 15 | Connect API Modal component | …/integrationmarketplace/components/connect-api-modal.tsx |
| 16 | Custom Integration Workshop component | …/integrationmarketplace/components/custom-integration-workshop.tsx |
| 17 | Custom Integration List component | …/integrationmarketplace/components/custom-integration-list.tsx |
| 18 | Status Badge component (reusable) | …/integrationmarketplace/components/status-badge.tsx |
| 19 | Page Config | Pss2.0_Frontend/src/presentation/pages/setting/integration/integrationmarketplace.tsx |
| 20 | Route Page (REPLACE existing UnderConstruction stub) | Pss2.0_Frontend/src/app/[lang]/setting/integration/integrationmarketplace/page.tsx |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | src/infrastructure/operations/entity-operations.ts | INTEGRATIONMARKETPLACE block |
| 2 | src/infrastructure/operations/operations-config.ts | Import + register INTEGRATIONMARKETPLACE operations |
| 3 | src/infrastructure/gql-queries/setting-queries/index.ts (or barrel) | Re-export new files |
| 4 | src/infrastructure/gql-mutations/setting-mutations/index.ts (or barrel) | Re-export new files |
| 5 | src/domain/entities/setting-service/index.ts (or barrel) | Re-export new DTOs |
| 6 | src/presentation/pages/setting/integration/index.ts (if exists) | Re-export page config |

### DB Seed Files

| # | File | Path |
|---|------|------|
| 1 | New seed script | Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/integrationmarketplace-sqlscripts.sql |

Seed sections (idempotent):
- Section 1 — Re-confirm Menu INTEGRATIONMARKETPLACE under SET_INTEGRATION (already exists per `MODULE_MENU_REFERENCE.md` MenuId 378; defensive UPSERT)
- Section 2 — 3 MenuCapabilities (READ, MODIFY, ISMENURENDER) + DELETE for custom integrations
- Section 3 — BUSINESSADMIN role grants
- Section 4 — Grid `INTEGRATIONMARKETPLACE` (GridType=CONFIG, GridFormSchema NULL)
- Section 5 — MasterDataType `INTEGRATIONPROVIDER` + 26 rows (see §④ table) with DataSetting JSON
- Section 6 — MasterDataType `INTEGRATIONTRIGGER` + 6 rows
- Section 7 — MasterDataType `INTEGRATIONACTION` + 6 rows
- Section 8 — MasterDataType `INTEGRATIONPAYLOADFIELD` + 6 rows
- Section 9 — MasterDataType `INTEGRATIONFILTERFIELD` + 3 rows
- Section 10 — MasterDataType `INTEGRATIONFILTEROP` + 4 rows
- Section 11 — 1-2 sample CustomIntegration rows for the seeded sample tenant (optional, for E2E QA)

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: Integration Marketplace
MenuCode: INTEGRATIONMARKETPLACE
ParentMenu: SET_INTEGRATION
Module: SETTING
MenuUrl: setting/integration/integrationmarketplace
GridType: CONFIG

MenuCapabilities: READ, CREATE, MODIFY, DELETE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE

GridFormSchema: SKIP
GridCode: INTEGRATIONMARKETPLACE
---CONFIG-END---
```

> Note: `INTEGRATIONMARKETPLACE` menu is already seeded under `SET_INTEGRATION` (MenuId 378, OrderBy 4) per `MODULE_MENU_REFERENCE.md` — the seed script's Menu section should be defensive UPSERT to set capabilities + URL without breaking the existing row. CREATE/DELETE capabilities apply to the embedded CustomIntegration CRUD, not the catalog itself.

---

## ⑩ Expected BE→FE Contract

**GraphQL Types:**
- Query types: `CustomIntegrationQueries`, `IntegrationMarketplaceQueries`
- Mutation types: `CustomIntegrationMutations`, `IntegrationMarketplaceMutations`

### Queries

| GQL Field | Returns | Key Args | Tenant Scope |
|-----------|---------|----------|--------------|
| getIntegrationMarketplaceState | IntegrationMarketplaceStateDto | — | HttpContext |
| getIntegrationProviderDetail | IntegrationProviderDetailDto | providerCode: String! | HttpContext |
| getAllCustomIntegrationList | PaginatedResponse<CustomIntegrationResponseDto> | pageNo: Int!, pageSize: Int!, search: String, isActive: Boolean | HttpContext |
| getCustomIntegrationById | CustomIntegrationResponseDto | customIntegrationId: Int! | HttpContext |

### Mutations

| GQL Field | Input | Returns |
|-----------|-------|---------|
| createCustomIntegration | CustomIntegrationRequestDto | Int (new CustomIntegrationId) |
| updateCustomIntegration | CustomIntegrationRequestDto (with Id) | Int |
| deleteCustomIntegration | customIntegrationId: Int! | Int |
| toggleCustomIntegrationStatus | customIntegrationId: Int!, isActive: Boolean! | Int |
| testCustomIntegration (SERVICE_PLACEHOLDER) | customIntegrationId: Int! | TestResultDto { success: Boolean, message: String, durationMs: Int? } |
| connectIntegrationProvider (V1 SERVICE_PLACEHOLDER) | ConnectIntegrationRequestDto { providerCode: String!, apiKey: String!, apiSecret: String!, environment: String! } | Boolean (always true V1) |

### DTO Shapes

```typescript
// FE DTO file: IntegrationMarketplaceDto.ts
export interface IntegrationMarketplaceStateDto {
  providers: ProviderCardDto[];
  customIntegrations: CustomIntegrationResponseDto[];
}

export interface ProviderCardDto {
  providerCode: string;          // 'STRIPE'
  providerName: string;          // 'Stripe'
  category: string;              // 'payment'
  description: string;
  iconClass: string;             // 'fa-brands fa-stripe-s'
  brandColor: string;            // '#635bff'
  isFeatured: boolean;
  status: 'Connected' | 'Available';
  connectedSince: string | null; // ISO date — when connected
  configRoute: string | null;    // Route to open when Configure/Connect clicked (null for SERVICE_PLACEHOLDER providers)
  hasBackingScreen: boolean;     // true if Connect routes; false if Connect opens modal
}

export interface IntegrationProviderDetailDto {
  providerCode: string;
  providerName: string;
  description: string;
  features: string[];
  configuration: ProviderConfigRowDto[];   // [{ label, value, isMasked }, …]
  syncActivity: SyncActivityDto | null;    // null when no backing table
  connectedSince: string | null;
  configRoute: string | null;
}

export interface ProviderConfigRowDto {
  label: string;          // 'API Key'
  value: string;          // 'sk_live_••••••••7890'
  isMasked: boolean;
}

export interface SyncActivityDto {
  windowDays: number;       // 7
  successCount: number;
  totalAmount: number | null;
  failedCount: number;
  currencyCode: string | null;
}

// FE DTO file: CustomIntegrationDto.ts
export interface CustomIntegrationResponseDto {
  customIntegrationId: number;
  integrationName: string;
  triggerEventCode: string;
  triggerEventLabel: string;   // resolved server-side from MasterData
  actionTypeCode: string;
  actionTypeLabel: string;     // resolved server-side
  webhookUrl: string | null;
  dataPayloadFields: string[]; // ['DonationId','Amount','ContactName']
  filterField: string | null;
  filterOperator: string | null;
  filterValue: string | null;
  isActive: boolean;
  lastTriggeredAt: string | null;
  triggerCount: number;
  createdDate: string;
  createdBy: string;
}

export interface CustomIntegrationRequestDto {
  customIntegrationId?: number; // present on update only
  integrationName: string;
  triggerEventCode: string;
  actionTypeCode: string;
  webhookUrl: string | null;
  dataPayloadFields: string[];
  filterField: string | null;
  filterOperator: string | null;
  filterValue: string | null;
  isActive: boolean;
}
```

> CRITICAL — see memory `[[feedback_fe_query_nullability_must_match_be]]`: declare list variables in GQL as `[String!]` (matches BE `string[]?` nullable list of non-null strings). Do NOT use `[String]`.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — 0 errors
- [ ] `pnpm dev` — page loads at `/{lang}/setting/integration/integrationmarketplace`
- [ ] `npx tsc --noEmit` — no new TS errors introduced

**Functional Verification (Full E2E):**

### Catalog Hub
- [ ] First load → 26 cards render across 6 numbered category sections + Custom Integration section
- [ ] Featured row shows exactly 3 cards (Stripe / QuickBooks / Mailchimp) when category=All
- [ ] Clicking each category pill narrows visible sections correctly; Featured row hides for non-All
- [ ] Search "stri" narrows to Stripe; "Sales" narrows to Salesforce; case-insensitive
- [ ] Search + category combined narrows correctly (e.g. payment pill + "ray" → Razorpay only)
- [ ] Connected badge shows correctly for at least 1 connected provider (seed Stripe row in CompanyPaymentGateway for sample tenant)
- [ ] Available badge shows correctly for all unconnected providers

### Detail Modal (Connected)
- [ ] Click Stripe card → modal opens with Features list + Configuration rows (masked API Key) + Sync Activity (last 7 days)
- [ ] Configuration: API Key shows `••••••••XXXX` with no "Show" reveal in V1 (defer to V2 / log ISSUE-6)
- [ ] Sync Activity for Stripe shows correct count from `GlobalDonations` (test by seeding 5 successful + 1 failed in last 7 days)
- [ ] Save button routes to `/{lang}/setting/paymentconfig/companypaymentgateway?provider=STRIPE`
- [ ] Modal Disconnect button is visible but disabled in V1 (or hidden — log ISSUE-7)

### Connect Modal (Available without backing screen)
- [ ] Click Slack Connect → Connect API Modal opens with key/secret/env fields
- [ ] Submit → toast "Coming soon — connection storage ships next release"
- [ ] Modal closes after submit
- [ ] No DB row written (verify via SELECT against any candidate table)

### Available with backing screen
- [ ] Click PayPal Connect → routes to `/{lang}/setting/paymentconfig/companypaymentgateway?provider=PAYPAL`
- [ ] Click SendGrid Connect → routes to `/{lang}/setting/communicationconfig/emailproviderconfig?provider=SENDGRID`
- [ ] Click Twilio Connect → routes to `/{lang}/setting/communicationconfig/smssetup?provider=TWILIO`

### Custom Integration Workshop
- [ ] Trigger and Action selects populate from MasterData (6 + 6 options)
- [ ] Webhook URL field shows ONLY when Action='Send webhook to URL'; hides otherwise
- [ ] Data to Send shows 6 checkboxes; first 3 (Donation ID / Amount / Contact Name) default-checked
- [ ] Filter row: setting field shows operator + value; clearing field clears all 3
- [ ] Integration Name auto-suggests from Trigger/Action labels; manual override persists
- [ ] Test Integration button → V1 SERVICE_PLACEHOLDER toast (verify it calls handler and returns success)
- [ ] Save & Activate → row appears in list below; form clears; toast "Saved"
- [ ] Duplicate name within tenant blocked with inline validation error

### Custom Integration List
- [ ] List below workshop shows all rows for tenant, default sort by CreatedDate DESC
- [ ] Edit icon → populates workshop above; header changes to "Edit '{name}'"; Cancel button appears
- [ ] Toggle icon → IsActive flips; status pill updates without page reload
- [ ] Delete icon → confirm modal → row removed from list (soft delete)
- [ ] Empty state: "No custom integrations yet. Build your first automation above."

### Role Gate
- [ ] Non-BUSINESSADMIN role does NOT see menu in sidebar
- [ ] Direct URL access by non-BUSINESSADMIN returns 403

**DB Seed Verification:**
- [ ] `setting/integration/integrationmarketplace` menu visible in sidebar under "Settings → Integration → Marketplace"
- [ ] MasterDataType `INTEGRATIONPROVIDER` + 26 rows seeded
- [ ] 4 supporting MasterDataTypes (TRIGGER / ACTION / PAYLOADFIELD / FILTERFIELD / FILTEROP) seeded with correct rows
- [ ] Grid `INTEGRATIONMARKETPLACE` row exists with GridType=CONFIG
- [ ] Page renders without crashing on a fresh-seeded DB

---

## ⑫ Special Notes & Warnings

### Universal CONFIG warnings (applicable)

- **CompanyId is NOT a form field** — auto-resolved from HttpContext on Create
- **No view-page 3-mode** — single-mode custom page
- **GridFormSchema = SKIP** — custom UI, no RJSF modal
- **Role gating happens at the BE** — BUSINESSADMIN check enforced server-side, not just FE
- **MasterData seed: idempotent UPSERT pattern** — seed must work on fresh DB AND on subsequent re-runs without duplicating rows. Use `WHERE NOT EXISTS` checks per `_COMMON.md` seed convention.

### Hybrid sub-type — first canonical of `marketplace-hub` variant

This screen establishes a NEW layout variant within CONFIG: `marketplace-hub` — read-mostly catalog + embedded definition-list. When the build completes:
1. Update `_CONFIG.md` §⑥ Visual Uniqueness Rules to add `marketplace-hub` as a fourth container pattern alongside `tabs / sidebar-nav / accordion / vertical-stack`
2. Update `_COMMON.md` Substitution Guide table with this screen as the canonical for the variant
3. Note in `_CONFIG.md` §⑦ that `integrationmarketplace.md` is the SETTINGS_PAGE canonical for catalog + workshop hybrids

### Module / Schema notes

- Schema `sett` and group `Setting` already exist (used by Field / Grid / MasterData / Dashboard / etc.) — NO new module infrastructure needed
- Parent menu `SET_INTEGRATION` already seeded (MenuId 378). Sibling screens at this parent: ACCOUNTINGINTEGRATION / SOCIALMEDIAINTEGRATION / APIMANAGEMENT — all currently SKIP_CONFIG, all FE stubs only

### Pre-flagged issues (KNOWN ISSUES at planning time)

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | LOW | V2 architecture | Generic `sett."CompanyIntegrationConnection"` table needed for V2 to back providers without dedicated screens (Mailchimp, Salesforce, Slack, GA, etc.). V1 ships with SERVICE_PLACEHOLDER toast; design the table in V2. |
| ISSUE-2 | MED | Sync activity completeness | V1 `SyncActivity` populates only for payment providers (from `GlobalDonations`). Email / SMS / WhatsApp sync stats deferred until send-log queries exist. Render placeholder card "Activity tracking ships in a future release" for non-payment connected providers. |
| ISSUE-3 | HIGH | Cross-screen coordination | Backing screens (#167 / #84 / #157 / #34) must read `?provider=` query param and pre-select the matching provider on mount. This requires a small FE PATCH on each of those 4 screens. Coordinate with those screens' owners before this build completes. |
| ISSUE-4 | LOW | Detail modal scope | Detail modal in V1 is READ-ONLY status preview; inline edit of configuration deferred to V2. User who wants to edit must click Save → routes to backing screen. Confirm this is acceptable UX during BA review. |
| ISSUE-5 | LOW | Mockup gap | Mockup lacks an explicit "Integration Name" field on the Custom Integration workshop. We added one (auto-suggested from Trigger/Action labels) since storage requires it. Verify UX with stakeholder. |
| ISSUE-6 | LOW | Sensitive-field reveal | "Show" toggle on masked API Key in detail modal is in the mockup but defer reveal to V2 (requires temporary-decrypt + audit-log). V1 stays fully masked. |
| ISSUE-7 | LOW | Disconnect UX | Detail modal "Disconnect" button — V1 behavior unclear (delegate to backing screen vs. inline destructive action). Recommend hiding in V1; ship Disconnect in V2 once generic connection store exists. |
| ISSUE-8 | MED | Status query cost | `GetIntegrationMarketplaceState` joins 4 backing tables on each page load. With 26 providers × 4 tables, query plan needs verification — add indexes on the lookup columns (`fund.CompanyPaymentGateways.PaymentGatewayId` likely already indexed; verify `notify.CompanyEmailProviders.Provider` / `notify.SmsSettings.ProviderType` are queryable efficiently). |
| ISSUE-9 | INFO | UnderConstruction stub | Existing FE route `setting/integration/integrationmarketplace/page.tsx` is an UnderConstruction stub — REPLACE entirely with the real page. The other 3 stubs (accountingintegration / apimanagement / socialmediaintegration) remain stubs for V1. |
| ISSUE-10 | LOW | MasterData CRUD via #76 | After build, admins can extend the INTEGRATIONPROVIDER catalog via the #76 Master Data screen. But adding a provider row alone is insufficient — they also need a backing-table check rule, which is hardcoded in `GetIntegrationMarketplaceState`. Document this in admin-facing docs (out of scope for this screen build). |
| ISSUE-11 | INFO | V2 webhook execution | The runtime that actually FIRES custom-integration webhooks (when a donation is created, etc.) is out of scope for this screen. V1 ships the configuration UI + storage only. Wiring the event-bus dispatcher → webhook executor is a separate epic. |

### Service Dependencies (SERVICE_PLACEHOLDER)

Everything in the mockup is in scope. The following handlers are mocked because the underlying integrations don't yet exist:

- ⚠ **SERVICE_PLACEHOLDER: ConnectIntegrationProvider** — Connect API Modal Save button. V1 toasts "Coming soon" and persists nothing. Full UI is implemented (modal + 3 fields + validation + success indicator).
- ⚠ **SERVICE_PLACEHOLDER: TestCustomIntegration** — Test Integration button. V1 returns mocked `{ success: true, durationMs: 142, message: 'OK (mock)' }` after a 500ms artificial delay. Full UI implemented (button → loading state → toast result).
- ⚠ **SERVICE_PLACEHOLDER: View Logs** — Detail modal "View Logs" button. V1 toasts "Log viewer ships next release". Button rendered, click handler mocked.
- ⚠ **SERVICE_PLACEHOLDER: Custom Integration runtime** — when an event fires, the webhook actually does nothing in V1. The CustomIntegration record stores the *configuration*; the *execution* belongs to a separate event-bus integration not yet built.
- ⚠ **SERVICE_PLACEHOLDER: Disconnect (detail modal)** — hidden in V1 per ISSUE-7. Visible in V2 once generic connection store exists.

Full UI must be built for all of the above (modals / buttons / form fields / toasts / loading states / list items). Only the backend service-call body is mocked.

---

## ⑬ Build Log (append-only)

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | planning (2026-05-18) | LOW | V2 architecture | Generic `sett.CompanyIntegrationConnection` table needed for V2 — V1 stays SERVICE_PLACEHOLDER | open |
| ISSUE-2 | planning (2026-05-18) | MED | Sync activity | V1 sync stats payment-only; email/SMS/WhatsApp deferred | open |
| ISSUE-3 | planning (2026-05-18) | HIGH | Cross-screen | #167/#84/#157/#34 must read `?provider=` param | open |
| ISSUE-4 | planning (2026-05-18) | LOW | Detail modal | V1 detail modal is read-only — inline edit V2 | open |
| ISSUE-5 | planning (2026-05-18) | LOW | Mockup gap | Integration Name field added (mockup missing) | open |
| ISSUE-6 | planning (2026-05-18) | LOW | Sensitive reveal | "Show" toggle deferred to V2 | open |
| ISSUE-7 | planning (2026-05-18) | LOW | Disconnect UX | V1 hides Disconnect button — V2 wiring | open |
| ISSUE-8 | planning (2026-05-18) | MED | Query perf | Verify indexes on backing-table status columns | open |
| ISSUE-9 | planning (2026-05-18) | INFO | FE stub | Existing UnderConstruction route to be replaced | open |
| ISSUE-10 | planning (2026-05-18) | LOW | Catalog extensibility | Hardcoded backing-table rules vs MasterData-driven catalog | open |
| ISSUE-11 | planning (2026-05-18) | INFO | Runtime | V1 = config UI only; webhook execution is separate epic | open |
| ISSUE-12 | session-1 (2026-05-19) | MED | Cross-screen build blocker | Pre-existing CS errors in #88 AccountingIntegrations + #89 SocialMedia BE files (screens PROMPT_READY, never built) block the *solution-level* `dotnet build`. #87 files themselves compile clean. Affected files: IntegrationMappings.cs (2), ConnectSocialMediaAccount.cs / AddSocialMediaKeyword.cs (ConflictException), BulkUpsertAccountingPaymentModeMappings.cs / BulkUpsertAccountingAccountMappings.cs / AutoMapAccountingAccounts.cs / GetAccountingIntegrationSettings.cs (bool? casts). Resolve when #88/#89 are built. | open |
| ISSUE-13 | session-1 (2026-05-19) | LOW | Contract drift fixed inline | BE agent's initial Request DTO used `DataPayloadJson: string` while FE GQL mutation sends `dataPayloadFields: [String!]!`. Realigned: Request DTO now uses `DataPayloadFields: List<string>`; Create/Update handlers serialize via `JsonSerializer.Serialize` to entity's `DataPayloadJson` column. | closed |
| ISSUE-14 | session-1 (2026-05-19) | LOW | MasterData field-name drift fixed inline | BE handlers referenced `MasterData.Code` and `PaymentGateway.GatewayCode` (don't exist) — entities have `DataValue` and `PaymentGatewayCode`. Fixed in `Get*MarketplaceState`, `Get*ProviderDetail`, `GetCustomIntegrationList/ById`, `Validator`. | closed |
| ISSUE-15 | session-1 (2026-05-19) | LOW | WhatsAppSetting field-name drift | `w.IsActive` → `w.IsEnabled` (entity uses IsEnabled). Fixed in marketplace state + provider detail. | closed |
| ISSUE-16 | session-1 (2026-05-19) | MED | SyncActivity stubbed to null | Real per-gateway sync stats need `GlobalOnlineDonations → PaymentTransaction → PaymentGateway` join — `GlobalDonation` has NO `PaymentGatewayId`, and `PaymentStatus` is a MasterData navigation (not string). V1 returns `syncActivity: null`; FE renders placeholder card per ISSUE-2 pattern. **Extends ISSUE-2** to all connected providers (payment included) in V1. | open |
| ISSUE-17 | session-1 (2026-05-19) | LOW | FE GQL `data` wrapper | Initial agent-emitted `IntegrationMarketplaceQuery.ts` projected `result.providers` directly. BE returns through `ApiResponseHelper.ReturnObjectApiResponse` which wraps in `{ success, message, data }`. Re-wrote query with `data { ... }` wrapper. | closed |
| ISSUE-18 | session-1 (2026-05-19) | LOW | MASTER_DATA_QUERY_BY_TYPE doesn't exist | Workshop imported `MASTER_DATA_QUERY_BY_TYPE` (not defined). Replaced with `MASTERDATAS_QUERY` + `advancedFilter { rules: [{ field: 'MasterDataType.TypeCode', operator: '=', value: typeCode }] }` per #86 sibling pattern. | closed |
| ISSUE-19 | session-1 (2026-05-19) | LOW | Hand-written EF migration | Per ISSUE-15 precedent (#172/#86), the migration `20260519120000_Add_CustomIntegrations.cs` is hand-written. User must regen Designer/Snapshot OR run `dotnet ef database update` directly. | open |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-19 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt — BE + FE + DB seed + EF migration. FULL single-session per user approval (declined the 2-session split).
- **Files touched**:
  - BE (20 NEW + 5 wiring + EF mig + DB seed = 27 total):
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/CustomIntegration.cs` (created)
    - `Base.Infrastructure/Data/Configurations/SettingConfigurations/CustomIntegrationConfiguration.cs` (created)
    - `Base.Application/Schemas/SettingSchemas/CustomIntegrationSchemas.cs` (created, then revised for DataPayloadFields contract — ISSUE-13)
    - `Base.Application/Schemas/SettingSchemas/IntegrationMarketplaceSchemas.cs` (created)
    - `Base.Application/Business/SettingBusiness/CustomIntegrations/{GetList,GetById,Create,Update,Delete,Toggle,Test}*.cs` (7 handlers created)
    - `Base.Application/Business/SettingBusiness/IntegrationMarketplace/{GetState,GetDetail,Connect}*.cs` (3 handlers created)
    - `Base.Application/Business/SettingBusiness/CustomIntegrations/Validators/CustomIntegrationRequestValidator.cs` (created)
    - `Base.API/EndPoints/Setting/Queries/CustomIntegrationQueries.cs` (created)
    - `Base.API/EndPoints/Setting/Queries/IntegrationMarketplaceQueries.cs` (created)
    - `Base.API/EndPoints/Setting/Mutations/CustomIntegrationMutations.cs` (created)
    - `Base.API/EndPoints/Setting/Mutations/IntegrationMarketplaceMutations.cs` (created in salvage pass — agent stalled)
    - `Base.Infrastructure/Migrations/20260519120000_Add_CustomIntegrations.cs` (created — hand-written, ISSUE-19)
    - `sql-scripts-dyanmic/integrationmarketplace-sqlscripts.sql` (created — 10 sections, 26+6+6+6+3+4 MasterData rows)
    - `Base.Application/Data/Persistence/ISettingDbContext.cs` (modified — added CustomIntegrations DbSet)
    - `Base.Infrastructure/Data/Persistence/SettingDbContext.cs` (modified — DbSet property)
    - `Base.Application/Extensions/DecoratorProperties.cs` (modified — CustomIntegration + IntegrationMarketplace constants)
    - `Base.Application/Mappings/SettingMappings.cs` (modified — Mapster CustomIntegration↔DTOs with DataPayloadFields/DataPayloadJson ignored both directions)
  - FE (20 NEW + 5 wiring = 25 total):
    - `domain/entities/setting-service/CustomIntegrationDto.ts` (created)
    - `domain/entities/setting-service/IntegrationMarketplaceDto.ts` (created)
    - `infrastructure/gql-queries/setting-queries/CustomIntegrationQuery.ts` (created)
    - `infrastructure/gql-queries/setting-queries/IntegrationMarketplaceQuery.ts` (created, then re-wrote with `data { ... }` wrapper — ISSUE-17)
    - `infrastructure/gql-mutations/setting-mutations/CustomIntegrationMutation.ts` (created)
    - `infrastructure/gql-mutations/setting-mutations/IntegrationMarketplaceMutation.ts` (created)
    - `presentation/components/page-components/setting/integration/integrationmarketplace/integrationmarketplace-store.ts` (created)
    - `…/integrationmarketplace/components/category-pills.tsx` (created)
    - `…/integrationmarketplace/components/featured-row.tsx` (created)
    - `…/integrationmarketplace/components/category-section.tsx` (created)
    - `…/integrationmarketplace/components/integration-card.tsx` (created)
    - `…/integrationmarketplace/components/status-badge.tsx` (created)
    - `…/integrationmarketplace/components/provider-detail-modal.tsx` (created, then patched to consume `result.data` wrapper + lang param)
    - `…/integrationmarketplace/components/connect-api-modal.tsx` (created)
    - `…/integrationmarketplace/components/custom-integration-workshop.tsx` (created, then patched: MASTERDATAS_QUERY + advancedFilter — ISSUE-18)
    - `…/integrationmarketplace/components/custom-integration-list.tsx` (created in salvage pass)
    - `…/integrationmarketplace/components/marketplace-header.tsx` (created in salvage pass)
    - `…/integrationmarketplace/marketplace-page.tsx` (created in salvage pass — orchestrates the 9 components)
    - `…/integrationmarketplace/index.ts` (created — barrel)
    - `presentation/pages/setting/integration/integrationmarketplace.tsx` (created — page-config with `useAccessCapability`)
    - `app/[lang]/setting/integration/integrationmarketplace/page.tsx` (replaced UnderConstruction stub → IntegrationMarketplacePageConfig)
    - `application/configs/data-table-configs/setting-service-entity-operations.ts` (modified — INTEGRATIONMARKETPLACE block)
    - `domain/entities/setting-service/index.ts` (modified — barrel re-export)
    - `infrastructure/gql-queries/setting-queries/index.ts` (modified — barrel re-export)
    - `infrastructure/gql-mutations/setting-mutations/index.ts` (modified — barrel re-export)
  - DB: `sql-scripts-dyanmic/integrationmarketplace-sqlscripts.sql` (created — see BE list above)
- **Deviations from spec**:
  - SyncActivity stubbed to `null` in V1 (ISSUE-16) — `GlobalDonation` has no `PaymentGatewayId` field; needs `GlobalOnlineDonations` join in V2.
  - DataPayloadFields list-of-strings (FE contract) serializes to `entity.DataPayloadJson` via `JsonSerializer.Serialize` in Create/Update handlers (ISSUE-13).
  - `ISSUE-3` cross-screen `?provider=` deep-link patches to #167/#84/#157/#34 deferred per user approval — backing screens won't pre-select on deep-link in V1.
  - Both Backend Developer and Frontend Developer agents stalled at 600s stream-idle watchdog; remaining files + contract realignment completed inline by orchestrator (per memory `feedback_long_agent_prompts_stall`).
- **Known issues opened**: ISSUE-12 (cross-screen build blocker), ISSUE-16 (SyncActivity stub), ISSUE-19 (hand-written EF migration).
- **Known issues closed**: ISSUE-13 (DataPayloadFields contract), ISSUE-14 (MasterData.Code → DataValue + PaymentGatewayCode), ISSUE-15 (WhatsAppSetting.IsEnabled), ISSUE-17 (GQL `data` wrapper), ISSUE-18 (MASTERDATAS_QUERY substitution).
- **Next step**: User runs `dotnet ef database update` (the hand-written migration applies cleanly — verify via `dotnet ef migrations list`), then executes `integrationmarketplace-sqlscripts.sql` against the seed tenant DB, then `pnpm dev` from `PSS_2.0_Frontend/`, opens `/{lang}/setting/integration/integrationmarketplace`, and runs the E2E checklist from §⑪.