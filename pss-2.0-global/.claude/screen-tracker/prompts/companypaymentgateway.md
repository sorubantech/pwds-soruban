---
screen: CompanyPaymentGateway
registry_id: 167
module: Setting (paymentconfig)
status: COMPLETED
scope: FE_ONLY + BE_ALIGN_DELTAS
screen_type: MASTER_GRID
display_mode: card-grid
card_variant: details
complexity: Medium
new_module: NO
planned_date: 2026-05-15
completed_date: 2026-05-15
last_session_date: 2026-05-15
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (`html_mockup_screens/screens/fundraising/payment-gateway-config.html`)
- [x] Existing code reviewed (BE complete: entity + EF + schemas + 2 queries + 4 mutations + encryption + Mapster; FE = under-construction stub)
- [x] Business rules extracted (encryption at rest, masking on list, single default per company)
- [x] FK target resolved (PaymentGatewayId → `com.PaymentGateways` via existing `paymentGateways` paginated query)
- [x] File manifest computed (FE-mostly; BE delta = 1 new column + 1 list query + 1 seed update)
- [x] Approval config pre-filled (MenuCode=COMPANYPAYMENTGATEWAY, ParentMenu=SET_PAYMENTCONFIG, Module=SETTING)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (slim Phase 1 pass, 2026-05-15)
- [x] Solution Resolution complete (validated — no custom RJSF widgets needed; use existing dgf-widgets registry)
- [x] UX Design finalized (card-grid + RJSF modal pattern mirrored from SMS Template #29)
- [x] User Approval received (2026-05-15 — menu re-parent to SET_PAYMENTCONFIG, seed #168 master rows, hand-crafted EF migration)
- [x] Backend ALIGN deltas applied (1 new column on entity + EF config + DTO append + composite unique index + default-clearing in Create+Update handlers + new GetAllPaymentGatewayList query + PaymentGatewayQueries endpoint append + migration + snapshot delta)
- [x] Backend wiring complete (DonationMappings auto-picks SupportedPaymentMethods via Mapster convention; DecoratorDonationModules.CompanyPaymentGateway confirmed in DecoratorProperties.cs:276; IEncryptionService DI registration confirmed in DependencyInjection.cs:53)
- [x] Frontend code generated (DTO + GQL Query/Mutation + page-config dispatcher + index-page AdvancedDataTable card-grid + gateway-card custom variant + barrel updates)
- [x] Frontend wiring complete (entity-operations COMPANYPAYMENTGATEWAY block appended + card-grid variant registry registered + 5 barrel exports added + route stub replaced)
- [x] DB Seed script generated (menu re-parent UPDATE to SET_PAYMENTCONFIG/SETTING + URL + MenuCapabilities + RoleCapabilities + Grid + GridFormSchema + 6 PaymentGateway master rows for #168)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] EF migration applied (`dotnet ef database update`)
- [ ] DB Seed SQL executed (menu re-parent + PaymentGateway master Stripe/PayPal/Razorpay/Braintree/Square/Manual)
- [ ] `pnpm dev` — page loads at `/{lang}/setting/paymentconfig/companypaymentgateway`
- [ ] Card-grid renders: gateway icon + name + env badge + default star + Merchant ID + Currencies chips + Methods chips + footer action buttons
- [ ] Loading state shows ≥4 `DetailsCardSkeleton` instances
- [ ] Empty state renders ("No gateways configured" with `+ Add Gateway` CTA)
- [ ] `+ Add Gateway` → modal opens with all 10 fields + Test Connection + Save
- [ ] PaymentGateway dropdown (ApiSelectV2) loads Stripe/PayPal/Razorpay/Braintree/Square/Manual from `com.PaymentGateways`
- [ ] Environment toggle (Test/Live) flips correctly
- [ ] API Key / API Secret / Webhook Secret render as `type="password"` and submit plain text (encrypted server-side)
- [ ] Currencies multi-select & Country Codes multi-select accept tag input + chip remove
- [ ] AdditionalConfig accepts valid JSON; client-side validation rejects malformed JSON
- [ ] Save → `createCompanyPaymentGateway` mutation succeeds → card appears with masked API key
- [ ] Edit on card → modal pre-fills (API key/secret displayed as decrypted plain text from GetById; masked in list)
- [ ] Update → re-encrypts on save (existing handler behavior preserved)
- [ ] Toggle Active (footer "Disable" → renamed) → `activateDeactivateCompanyPaymentGateway` mutation
- [ ] Delete → soft delete → card disappears
- [ ] Default-star badge shows when `IsDefault=true`; only one card per company can have it (BE rule — Section ④)
- [ ] SERVICE_PLACEHOLDER buttons render with toast: Test Connection, View Logs, Webhook Event Log section, Monthly Volume, Webhook Status
- [ ] Permissions: BUSINESSADMIN sees all actions; other roles read-only per RoleCapabilities seed

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **CompanyPaymentGateway** (registry #167 — Payment Gateways, Per-Company)
Module: **Setting** (under sidebar group `setting/paymentconfig/`)
Schema: **fund** (existing — joins DonationModels namespace)
Group: **DonationModels** (BE) / **donation-service** (FE)

Business: The Payment Gateway Configuration screen lets a tenant's Business Admin choose which payment gateway providers (Stripe / PayPal / Razorpay / Braintree / Square / Manual Bank Transfer) the company has enabled for online donations, supply the API credentials, designate the **default** gateway, and configure per-gateway scope — supported currencies, supported country codes, payment methods (Card / UPI / Wallet / Apple Pay etc.), and arbitrary provider-specific JSON config. Credentials are **encrypted at rest** using `IEncryptionService` + `PaymentGateway:CredentialEncryptionKey` config; on the list view keys are **masked** (last-4 only); on GetById they are **decrypted in full** for the edit modal. The screen is a sibling of **#168 PaymentGateway Master** — #168 is the global catalog of supported provider codes (`STRIPE`, `PAYPAL`, …); #167 is the company's per-tenant activation/credential record that FKs into #168. Online Donation Page (#28-family) and Event Registration (#169), P2P Campaign (#170), CrowdFunding (#173) all reference `CompanyPaymentGatewayId` to decide where to route a payment session — see `.Ignore(dest => dest.CompanyPaymentGateway!)` lines throughout `DonationMappings.cs` (8 occurrences). This is the first screen to **make those references real** by giving admins a UI to populate the table.

**Status pre-build**: BE was generated in an earlier round (entity + EF config + schemas + 2 queries + 4 mutations + Mapster + decryption-in-query logic). FE is an `UnderConstruction` stub at `setting/paymentconfig/companypaymentgateway/page.tsx`. Build scope = **FE_ONLY + small BE ALIGN deltas**.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Audit columns (CreatedBy / CreatedDate / ModifiedBy / ModifiedDate / IsActive / IsDeleted / CompanyId-implicit) inherited from `Entity` base — NOT listed below.
> Existing entity already covers most fields — see ALIGN deltas at end.

Table: `fund."CompanyPaymentGateways"` (already created; existing migration in place)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CompanyPaymentGatewayId | int | — | PK | — | Identity. Already in BE. |
| CompanyId | int | — | YES | `com.Companies` | Already FK'd with `OnDelete(Restrict)`. Set by `CurrentUserService.CompanyId` — NOT a form field. |
| PaymentGatewayId | int | — | YES | `com.PaymentGateways` (#168) | Already FK'd with `OnDelete(Restrict)`. Driven by modal dropdown. |
| GatewayEnvironment | string | 20 | YES | — | Already exists. Allowed values: `"sandbox"` \| `"production"`. **Mockup labels them "Test" / "Live"** — FE maps Test→sandbox / Live→production. Default `"sandbox"`. |
| EncryptedApiKey | string | 1000 | YES | — | Already exists. Stored encrypted via `IEncryptionService.EncryptData(plainText, key)`. List query masks to `***last4`; GetById decrypts in full. **Modal sends plain text on Create/Update; BE encrypts before save.** |
| EncryptedApiSecret | string | 1000 | YES | — | Same encryption pattern. Always masked in list (`"********"`). |
| EncryptedWebhookSecret | string? | 1000 | NO | — | Same encryption pattern. Optional. |
| MerchantId | string? | 200 | NO | — | Already exists. Free-text gateway-specific identifier (e.g., `acct_1234567890`, `merchant@org.com`, `rzp_live_abc123`). |
| AdditionalConfig | string? | (text) | NO | — | Already exists. Free-form JSON blob, e.g., `{"statement_descriptor": "MyOrg Donation", "metadata_prefix": "pss_"}`. FE renders as `<textarea>` with `font-family: monospace`. Client-side JSON.parse validation before submit. |
| IsDefault | bool | — | YES | — | Already exists. Default `false`. **Business rule**: only ONE record per CompanyId can have `IsDefault=true` (enforce in Create + Update handlers — see ALIGN delta below). |
| SupportedCurrencies | string? | 200 | NO | — | Already exists. CSV of ISO-4217 codes (`"USD,EUR,GBP,INR"`). FE renders as multi-select tag input — splits on save, joins on load. |
| SupportedCountryCodes | string? | 200 | NO | — | Already exists. CSV of ISO-3166-1 alpha-2 codes (`"US,GB,IN,AE"`). Same multi-select pattern. |

### ALIGN delta — NEW column

| New Field | C# Type | MaxLen | Required | Notes |
|-----------|---------|--------|----------|-------|
| **SupportedPaymentMethods** | string? | 200 | NO | CSV of MasterData PAYMENTMETHODTYPE codes (`"CARD,UPI,APPLEPAY,GOOGLEPAY"`). Maps to the "Methods" chips in the mockup (rendered per-card via the chip strip). Reuse existing seeded MasterDataType `PAYMENTMETHODTYPE` (rows: CARD / UPI / NETBANKING / WALLET / ACH / APPLEPAY / GOOGLEPAY / PAYPAL — see `PaymentGateway-MasterData-seed.sql:30-39`). |

**Migration**: `Add_CompanyPaymentGateway_SupportedPaymentMethods` — single `AddColumn` with `MaxLength(200)`, nullable. No backfill needed (existing rows leave NULL → FE shows "All methods" or hides the strip).

**Child Entities**: NONE.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` navigation) + Frontend Developer (`ApiSelectV2` queries).

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|---------------|-------------------|----------------|---------------|-------------------|
| PaymentGatewayId | PaymentGateway (#168) | `Base.Domain/Models/SharedModels/PaymentGateway.cs` | `paymentGateways` (paginated, existing) **OR** new lightweight `GetAllPaymentGatewayList` (ALIGN delta — see below) | `paymentGatewayName` | `PaymentGatewayResponseDto` (existing — `paymentGatewayId / paymentGatewayCode / paymentGatewayName / isActive`) |
| CompanyId | Company | `Base.Domain/Models/SharedModels/Company.cs` | — (set from `CurrentUserService.CompanyId`) | — | — (not a form field) |

### ALIGN delta — NEW lightweight list query

The existing `paymentGateways` query is **paginated** (uses `GridFeatureRequest`). For `ApiSelectV2` dropdowns we need a non-paginated `GetAllPaymentGatewayList` that returns `[{ paymentGatewayId, paymentGatewayCode, paymentGatewayName, isActive }]` filtered to `IsActive=true AND IsDeleted=false`, ordered by `PaymentGatewayName`. Pattern: copy `GetAllCurrencyList` / `GetAllLanguageList` in `Base.Application/Business/SharedBusiness/`. Add to `PaymentGatewayQueries.cs` alongside the existing two methods.

**FE consumes** the new `paymentGatewayList` GQL field (lowercased) via `GET_PAYMENTGATEWAY_LIST` query barrel in `infrastructure/gql-queries/shared-queries/PaymentGatewayQuery.ts` (file already exists — append new gql template literal).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation).

**Uniqueness Rules:**
- `(CompanyId, PaymentGatewayId, GatewayEnvironment)` triplet should be **unique** per company (a tenant should not configure Stripe-Live twice). **ALIGN delta**: add filtered unique index in EF migration:
  ```csharp
  builder.HasIndex(c => new { c.CompanyId, c.PaymentGatewayId, c.GatewayEnvironment })
         .HasFilter("\"IsDeleted\" = false")
         .IsUnique();
  ```
- BE Create/Update handler must throw `ValidationException` ("This gateway is already configured for this environment") on conflict.

**Required Field Rules:**
- `PaymentGatewayId`, `GatewayEnvironment`, `EncryptedApiKey`, `EncryptedApiSecret` — already in `CreateCompanyPaymentGatewayValidator` (lines 11-14). No change.
- `MerchantId`, `EncryptedWebhookSecret`, `AdditionalConfig`, `SupportedCurrencies`, `SupportedCountryCodes`, `SupportedPaymentMethods` — optional.

**Conditional Rules:**
- If `PaymentGateway.PaymentGatewayCode = "MANUAL"` (Bank Transfer) → `EncryptedApiKey` / `EncryptedApiSecret` are not really credentials but BE schema requires them (1+ char). FE workaround: pre-fill with placeholder `"manual"` when gateway = MANUAL is selected. Alternative for V2: make ApiKey/Secret nullable for MANUAL — out of scope this build.
- `GatewayEnvironment="production"` should require non-empty `MerchantId` (warning, not hard block — V2).

**Business Logic — Single-Default Rule (ALIGN delta):**
- Only **one** active record per `(CompanyId)` may have `IsDefault=true`.
- Create handler: if `command.companyPaymentGateway.IsDefault == true`, before inserting, run `dbContext.CompanyPaymentGateways.Where(c => c.CompanyId == currentCompanyId && c.IsDefault && !c.IsDeleted).ExecuteUpdateAsync(b => b.SetProperty(c => c.IsDefault, false))`.
- Update handler: same atomic clearing pattern, excluding the row being updated by ID.
- Pattern reference: `CertificateTemplate` default-clearing (planned #83 — see registry note: "default-clearing atomic logic in Create+Update").

**JSON validation** (AdditionalConfig):
- Client-side: try `JSON.parse(value)` on submit; show inline error if it throws.
- Server-side: no validation (stored as opaque string) — gateway provider integration parses at runtime.

**Workflow**: None (pure CRUD; no state machine).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED based on mockup analysis.

**Screen Type**: `MASTER_GRID`
**Display Mode**: `card-grid` (stamped)
**Card Variant**: `details` (stamped) — uses the existing `<CardGrid>` infrastructure (built for SMS Template #29, 2026-04-18)
**Type Classification**: Type 2 — flat entity with 1 FK + small per-row scope (Currencies/Countries/Methods CSV strips) + encrypted credentials + visual card layout (NOT a generic table).
**Reason**: Mockup shows 4 gateway cards in a responsive grid (`gateway-grid` — `repeat(auto-fill, minmax(340px, 1fr))`). "+ Add Gateway" opens a **Bootstrap modal**; Edit opens the same modal pre-filled. No multi-mode URL routing. No child grid. Workflow = none. → MASTER_GRID + card-grid is the correct classification (registry's `FLOW` is wrong; corrected by user confirmation on 2026-05-15).

**Backend Patterns Required:**
- [x] Standard CRUD (existing — 11 BE files already in place)
- [ ] Nested child creation — N/A (no child entities)
- [x] Multi-FK validation (`ValidateForeignKeyRecord` for PaymentGatewayId — already in BE handlers; CompanyId set by CurrentUserService)
- [x] Composite-unique validation (NEW — `(CompanyId, PaymentGatewayId, GatewayEnvironment)`)
- [x] Custom business rule — single-default-per-company (NEW)
- [x] Field encryption at rest (existing — `IEncryptionService` already wired)
- [ ] File upload — N/A

**Frontend Patterns Required:**
- [x] `<CardGrid>` infrastructure with `details` variant (already exists from SMS Template #29; this screen REUSES it)
- [x] RJSF Modal Form (driven by `GridFormSchema` from DB seed)
- [ ] AdvancedDataTable — NOT used (card-grid replaces it)
- [x] Multi-select tag widget (custom RJSF widget — currencies, country codes, payment methods)
- [x] JSON editor textarea widget (custom RJSF widget — AdditionalConfig)
- [x] Password input widget (custom RJSF widget — API key, secret, webhook secret)
- [ ] Summary cards — NONE (mockup has no count widgets above grid)
- [ ] Grid aggregation columns — N/A (card-grid)
- [ ] Info / side panel — N/A
- [ ] Drag-to-reorder — N/A

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from `payment-gateway-config.html` — this IS the design spec.

### Page Layout — Variant

**Layout Variant** (REQUIRED — stamped): `grid-only`
- Page has a single H1 + subtitle + `+ Add Gateway` button row, then the card-grid, then a collapsible "Webhook Event Log" section. **No KPI / count widgets** above the grid → use **Variant A** (`<AdvancedDataTable>`-style internal header), NOT Variant B with `<ScreenHeader>`. Per FE Dev convention this avoids the duplicate-header bug (ContactType #19 precedent — see `feedback_external_page_dictionary_binding.md` for the FE pattern).
- Webhook Event Log section is a SEPARATE collapsible section rendered BELOW the card-grid — not a widget strip.

### Grid/List View

**Display Mode**: `card-grid`
**Card Variant**: `details`
**Card Config**:
```yaml
cardConfig:
  headerField: "paymentGatewayName"         # e.g., "Stripe" — large bold card-header
  headerIconField: "paymentGatewayIcon"     # FE-computed: stripe→fab-stripe-s, paypal→fab-paypal, razorpay→fas-bolt, manual→fas-building-columns, default→ph:credit-card. NOT a DTO field — local mapping by paymentGatewayCode.
  envBadgeField: "gatewayEnvironment"       # rendered as colored badge (Live=green, Test=orange, sandbox→Test, production→Live)
  defaultBadgeField: "isDefault"            # yellow star icon top-right when true
  metaFields:                               # rendered as 4-row label/value strips inside card body
    - { label: "Merchant ID", field: "merchantId", display: "code-mono" }
    - { label: "Currencies", field: "supportedCurrencies", display: "chip-strip-csv", maxChips: 6, moreLink: true }
    - { label: "Methods", field: "supportedPaymentMethods", display: "chip-strip-csv-mastercoded", maxChips: 5, master: "PAYMENTMETHODTYPE" }
    - { label: "Country Codes", field: "supportedCountryCodes", display: "chip-strip-csv", maxChips: 6, moreLink: true }
  servicePlaceholderRows:                   # rendered last; flagged as SERVICE_PLACEHOLDER (Section ⑫)
    - { label: "Webhook Status", display: "webhook-status-stub", fallback: "Not monitored" }
    - { label: "Monthly Volume", display: "volume-stub", fallback: "—" }
  footerActions:                            # button strip at card bottom
    - { label: "Edit",            icon: "fas-pen",   action: "openEditModal",        permission: "MODIFY" }
    - { label: "Test Connection", icon: "fas-plug",  action: "SERVICE_PLACEHOLDER",  toast: "Test Connection coming soon" }
    - { label: "View Logs",       icon: "fas-list",  action: "SERVICE_PLACEHOLDER",  toast: "View Logs coming soon" }
    - { label: "Disable",         icon: "fas-ban",   action: "toggleActive",         permission: "TOGGLE", variant: "danger-hover" }
```

**Responsive breakpoints** (from existing CardGrid infrastructure): 1 col (xs) → 2 col (sm) → 3 col (lg) → 4 col (xl). Card inner padding `p-4`, gap `gap-3`.

**Search/Filter Fields** (above card-grid, in the internal-header bar):
- Search box: matches against `paymentGatewayName` + `merchantId` (already wired in existing `GetCompanyPaymentGatewaysHandler.cs:18`)
- Environment chip filter: All / Live / Test
- Default filter: All / Default only

**Grid Actions** (in the search bar row, right-aligned):
- `+ Add Gateway` (primary, accent color) → opens Add/Edit modal

**Page Title / Header**:
- H1: "Payment Gateway Configuration"
- Subtitle: "Manage payment processing integrations"
- Breadcrumb: Settings / Payment Gateway Configuration

### Page Widgets & Summary Cards

**Widgets**: NONE — mockup has no count cards above the grid. `grid-only` variant.

### Grid Aggregation Columns

**Aggregation Columns**: NONE (card-grid has no columns).

### Side Panels / Info Displays

**Side Panel**: NONE — no row-detail panel in mockup.

### RJSF Modal Form — "Add / Edit Payment Gateway"

> Mockup: `payment-gateway-config.html:886-975`. Modal header = accent (#0e7490) bg + white text + credit-card icon. Modal size = `modal-lg`. Single-pane 2-column grid (`row g-3` with `col-md-6` per field).

**Form Sections** (in display order):

| # | Title | Layout | Fields |
|---|-------|--------|--------|
| 1 | Gateway Selection | 2-column | PaymentGatewayId, GatewayEnvironment |
| 2 | Credentials | 2-column | EncryptedApiKey, EncryptedApiSecret, EncryptedWebhookSecret, MerchantId |
| 3 | Scope | 2-column | SupportedCurrencies, SupportedCountryCodes, SupportedPaymentMethods, IsDefault |
| 4 | Advanced | 1-column full-width | AdditionalConfig (JSON textarea) |

> Sections do NOT need explicit headers in the mockup — they are visual groupings only. RJSF should render them as inline groups, NOT as collapsible accordions. Use uiSchema `"ui:order"` to enforce field order.

**Field Widget Mapping**:

| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| PaymentGatewayId | 1 | `ApiSelectV2` | "Select gateway..." | required | Query: `GET_PAYMENTGATEWAY_LIST` (new — ALIGN delta). Display: `paymentGatewayName`. Value: `paymentGatewayId`. |
| GatewayEnvironment | 1 | `toggle-switch-binary` (custom) | — | required | Renders as "Test ⇄ Live" toggle. Maps Test→`"sandbox"`, Live→`"production"` in onChange. Default: Live (`production`). |
| EncryptedApiKey | 2 | `password-input` (custom) | "Enter API key" | required, max 1000 | `type="password"`. Help text below: "Encrypted and stored securely". |
| EncryptedApiSecret | 2 | `password-input` | "Enter API secret" | required, max 1000 | Same encryption notice. |
| EncryptedWebhookSecret | 2 | `password-input` | "Enter webhook secret" | optional, max 1000 | Same encryption notice. |
| MerchantId | 2 | `text-input` | "Enter merchant ID" | optional, max 200 | Free text. |
| SupportedCurrencies | 3 | `multi-select-tags` (custom) | "Add currency..." | optional | Pre-populated chip list. ISO-4217 codes. **Datasource**: `GetAllCurrencyList` query (existing — from Currency Management #79). Splits on save: `["USD","EUR"]` → `"USD,EUR"`. Joins on load. |
| SupportedCountryCodes | 3 | `multi-select-tags` | "Add country..." | optional | ISO-3166-1 alpha-2. **Datasource**: hardcoded ISO list OR `GetAllCountryList` if it exists (verify in Step 2). If absent, FE ships a static 250-entry constant — flagged as ISSUE-3. |
| SupportedPaymentMethods | 3 | `multi-select-tags` | "Add method..." | optional | **Datasource**: `GetAllMasterDataList` filtered by `TypeCode=PAYMENTMETHODTYPE`. Stores by `DataValue` (CARD / UPI / …). Joins/splits same as currencies. |
| IsDefault | 3 | `toggle-switch` | — | optional | "Set as default gateway" label. Default off. If toggled ON: client-side warning toast "This will replace the existing default gateway" (because BE auto-clears prior default — Section ④). |
| AdditionalConfig | 4 | `json-editor-textarea` (custom) | `{ "statement_descriptor": "MyOrg Donation" }` | optional, valid JSON | Monospace font, min 4 rows. Client-side `JSON.parse` on blur — inline error if malformed. |

**Modal Footer Buttons** (in order):
1. `Test Connection` — **SERVICE_PLACEHOLDER** (green-tinted button on the LEFT). Toast: "Test Connection requires gateway integration — coming in V2".
2. `Cancel` — closes modal.
3. `Save` — submits to `createCompanyPaymentGateway` or `updateCompanyPaymentGateway` (primary, accent color).

**Conditional Sub-forms**:

| Trigger Field | Trigger Value | Effect |
|---------------|---------------|--------|
| PaymentGatewayId | `PaymentGatewayCode = "MANUAL"` | Hide Credentials section (or grey-out + pre-fill API Key/Secret with placeholder `"manual"`). Show a notice card: "Bank Transfer is a manual/offline gateway. Configure bank account details in V2." |
| PaymentGatewayId | Stripe / PayPal / Razorpay / Braintree / Square | Show all credential fields. |

### Webhook Event Log Section (BELOW the card-grid)

> Mockup `:828-883` — collapsible section card with chevron toggle. Section title "Webhook Event Log" + scroll icon.
> **SERVICE_PLACEHOLDER** — this section is rendered exactly as mockup shows, but the table is wired to **mock data** (or an empty-state with a "No webhook events yet — configure a webhook secret and connect a gateway to start receiving events" message). Future: a `PaymentGatewayWebhookEvent` entity + receiver endpoint will populate it (out of scope this build).

Table columns (when populated): Timestamp / Gateway / Event Type (code-chip) / Status (badge — Processed/Retry/Failed) / Transaction ID / Processing Time.

### User Interaction Flow

1. User lands at `/{lang}/setting/paymentconfig/companypaymentgateway` → card-grid renders existing CompanyPaymentGateway rows (decryption + masking handled server-side per existing handler).
2. Empty state ("No gateways configured") shows + Add Gateway CTA.
3. `+ Add Gateway` → modal opens → user picks Stripe → form fields appear → fills API key/secret + currencies → Save.
4. POST `createCompanyPaymentGateway` (request DTO carries plain-text key; BE encrypts before insert; single-default-clearing logic runs if IsDefault=true).
5. Modal closes → grid refetches → new Stripe card appears with masked credentials + default star.
6. Edit on existing card → modal opens with pre-filled fields. API Key/Secret/WebhookSecret come back from `GetCompanyPaymentGatewayById` decrypted in full (existing handler behavior).
7. Update → modal closes → grid refetches → card reflects new values.
8. Disable (footer button) → confirm dialog → `activateDeactivateCompanyPaymentGateway` mutation → card grays out (or filters out per env-chip filter).
9. Test Connection / View Logs / Webhook Event Log section → toast "Coming soon".

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps canonical reference (**SMS Template #29** for the card-grid+details FE pattern; **ContactType** for the RJSF modal CRUD pattern) → CompanyPaymentGateway.

| Canonical | → This Entity | Context |
|-----------|---------------|---------|
| SMSTemplate (FE card-grid pattern) | CompanyPaymentGateway | Card-grid + details variant reuse |
| smsTemplate | companyPaymentGateway | Variable / camelCase |
| ContactType (BE CRUD pattern) | CompanyPaymentGateway | Already-built BE — no copy-from needed |
| CompanyPaymentGateway | CompanyPaymentGateway | Entity / class name (unchanged) |
| companyPaymentGateway | companyPaymentGateway | Variable / camelCase |
| CompanyPaymentGatewayId | CompanyPaymentGatewayId | PK field |
| CompanyPaymentGateways | CompanyPaymentGateways | Table / collection |
| company-payment-gateway | companypaymentgateway | NO kebab in routes/folders — single token (matches existing route stub) |
| companypaymentgateway | companypaymentgateway | FE folder, import paths, route segment |
| COMPANYPAYMENTGATEWAY | COMPANYPAYMENTGATEWAY | Menu code, grid code |
| fund | fund | DB schema (already used) |
| Donation | Donation | BE group (DonationModels, DonationBusiness, DonationSchemas, DonationConfigurations) |
| DonationModels | DonationModels | Namespace suffix |
| SET_PAYMENTCONFIG | SET_PAYMENTCONFIG | Parent menu code (from MODULE_MENU_REFERENCE.md:271) |
| SETTING | SETTING | Module code (NOT DONATION — registry classifies this as a Setting screen) |
| setting/paymentconfig/companypaymentgateway | setting/paymentconfig/companypaymentgateway | FE route path (matches existing stub) |
| donation-service | donation-service | FE DTO/GQL service folder (matches `domain/entities/donation-service/`) |
| donation-queries | donation-queries | FE GQL query folder |
| donation-mutations | donation-mutations | FE GQL mutation folder |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Exact files to create/modify. No guessing.

### Backend — ALIGN deltas only (existing 11 files unchanged in body, 4 small additions)

| # | Action | File | What to do |
|---|--------|------|------------|
| 1 | MODIFY | `Base.Domain/Models/DonationModels/CompanyPaymentGateway.cs` | Append `public string? SupportedPaymentMethods { get; set; }` after `SupportedCountryCodes`. |
| 2 | MODIFY | `Base.Infrastructure/Data/Configurations/DonationConfigurations/CompanyPaymentGatewayConfiguration.cs` | Add `builder.Property(c => c.SupportedPaymentMethods).HasMaxLength(200);`. Add composite unique index `(CompanyId, PaymentGatewayId, GatewayEnvironment)` with filter `"IsDeleted" = false`. |
| 3 | MODIFY | `Base.Application/Schemas/DonationSchemas/CompanyPaymentGatewaySchemas.cs` | Append `public string? SupportedPaymentMethods { get; set; }` to both Request + Response DTOs. |
| 4 | MODIFY | `Base.Application/Business/DonationBusiness/CompanyPaymentGateways/Commands/CreateCompanyPaymentGateway.cs` | Insert single-default-clearing block before `dbContext.CompanyPaymentGateways.Add(entity)`. See Section ④ for the LINQ pattern. |
| 5 | MODIFY | `Base.Application/Business/DonationBusiness/CompanyPaymentGateways/Commands/UpdateCompanyPaymentGateway.cs` | Apply assignment `entity.SupportedPaymentMethods = command.companyPaymentGateway.SupportedPaymentMethods;`. Insert same default-clearing block (excluding the row being updated by ID). |
| 6 | NEW | `Base.Application/Business/SharedBusiness/PaymentGateways/Queries/GetAllPaymentGatewayList.cs` | Non-paginated list query. Returns `List<PaymentGatewayResponseDto>` ordered by `PaymentGatewayName`, filtered `IsActive=true AND IsDeleted=false`. Decorator: `[CustomAuthorize(DecoratorSharedModules.PaymentGateway, Permissions.Read)]`. Pattern: copy `GetAllCurrencyList`. |
| 7 | MODIFY | `Base.API/EndPoints/Shared/Queries/PaymentGatewayQueries.cs` | Append `GetAllPaymentGatewayList` GQL field method. Returns `BaseApiResponse<List<PaymentGatewayResponseDto>>`. |
| 8 | NEW | EF Migration `Add_CompanyPaymentGateway_SupportedPaymentMethods_And_UniqueIndex` | Hand-crafted (per `feedback_*` notes on EF migration manual regen). User must run `dotnet ef migrations add ...` post-build to regen Designer + Snapshot, OR `dotnet ef database update` direct. |
| 9 | NEW (replace) | `Services/Base/sql-scripts-dyanmic/PaymentGateway-Menus-seed.sql` (split into NEW file `companypaymentgateway-sqlscripts.sql`) | **DO NOT touch the existing `PaymentGateway-Menus-seed.sql`** (it has other menus). Create new SQL: (a) UPDATE auth."Menus" SET ParentMenuId = (SELECT MenuId FROM auth."Menus" WHERE MenuCode='SET_PAYMENTCONFIG'), ModuleId = (SELECT ModuleId FROM auth."Modules" WHERE ModuleCode='SETTING'), MenuUrl='setting/paymentconfig/companypaymentgateway', OrderBy=1 WHERE MenuCode='COMPANYPAYMENTGATEWAY'. (b) INSERT into auth."Grids" + auth."GridFormSchemas" (COMPANYPAYMENTGATEWAY, GridType=MASTER_GRID, GridFormSchema=JSON below). (c) INSERT PaymentGateway master rows for #168 (Stripe / PayPal / Razorpay / Braintree / Square / Manual — 6 rows in com."PaymentGateways"). All idempotent (`ON CONFLICT DO NOTHING` or guard with NOT EXISTS subquery). |

### Backend Wiring Updates

| # | File | What to Add |
|---|------|-------------|
| 1 | `Base.Application/Mappings/DonationMappings.cs` | No change — existing `NewConfig()` registrations (lines 187-190) auto-pick up the new `SupportedPaymentMethods` field via Mapster convention. |
| 2 | `Base.Application/Common/Decorators/DecoratorProperties.cs` | Verify `DecoratorDonationModules.CompanyPaymentGateway` already exists (used in handlers — line 3 of every command/query). If not, add it. |
| 3 | `Base.Infrastructure/Data/IApplicationDbContext.cs` | Verify `DbSet<CompanyPaymentGateway>` exists. If not, add. |

### Frontend Files — 6 new + 4 modifications

| # | Action | File | Path |
|---|--------|------|------|
| 1 | NEW | DTO Types | `Pss2.0_Frontend/src/domain/entities/donation-service/CompanyPaymentGatewayDto.ts` |
| 2 | NEW | GQL Query | `Pss2.0_Frontend/src/infrastructure/gql-queries/donation-queries/CompanyPaymentGatewayQuery.ts` |
| 3 | NEW | GQL Mutation | `Pss2.0_Frontend/src/infrastructure/gql-mutations/donation-mutations/CompanyPaymentGatewayMutation.ts` |
| 4 | NEW | Page Config (dispatcher) | `Pss2.0_Frontend/src/presentation/pages/setting/paymentconfig/companypaymentgateway.tsx` |
| 5 | NEW | Index Page Component (card-grid + modal orchestration) | `Pss2.0_Frontend/src/presentation/components/page-components/setting/paymentconfig/companypaymentgateway/index-page.tsx` |
| 6 | NEW | Card-grid renderer (gateway-specific icon + chip strip mapping) | `Pss2.0_Frontend/src/presentation/components/page-components/setting/paymentconfig/companypaymentgateway/gateway-card.tsx` |
| 7 | REPLACE | Route Page (stub → live) | `Pss2.0_Frontend/src/app/[lang]/setting/paymentconfig/companypaymentgateway/page.tsx` (currently `UnderConstruction` — replace contents to import `CompanyPaymentGatewayPageConfig`) |
| 8 | MODIFY | GQL Query (append list query) | `Pss2.0_Frontend/src/infrastructure/gql-queries/shared-queries/PaymentGatewayQuery.ts` — append `GET_PAYMENTGATEWAY_LIST` constant |
| 9 | MODIFY | Pages barrel | `Pss2.0_Frontend/src/presentation/pages/index.ts` — add `export * from "./setting/paymentconfig/companypaymentgateway"` (or equivalent index pattern in use) |
| 10 | MODIFY | entity-operations registry | `Pss2.0_Frontend/src/...entity-operations.ts` — add `COMPANYPAYMENTGATEWAY` block (mirror `PAYMENTGATEWAY` block for #168) |

### Frontend Wiring Updates

| # | File | What to Add |
|---|------|-------------|
| 1 | `entity-operations.ts` | `COMPANYPAYMENTGATEWAY` block with permissions config |
| 2 | `operations-config.ts` | Import + register the operations |
| 3 | Sidebar menu config (if hard-coded) | Should be picked up automatically from DB seed menu update. Verify the SET_PAYMENTCONFIG group already renders both PAYMENTGATEWAY (#168) and COMPANYPAYMENTGATEWAY (#167) — order 1 / order 2. |

### Custom RJSF Widgets Required

Three widgets may not yet exist as reusable widgets — Solution Resolver to confirm during Step 2 of `/build-screen`:
1. `password-input` — `type="password"` with optional reveal toggle (`<button> 👁</button>`). **Verify**: grep `presentation/components/rjsf/widgets/` for `password-input.tsx`. If absent → NEW widget.
2. `multi-select-tags` — tag input with chip remove + autocomplete from async query OR static list. **Verify**: grep for `multi-select-tags.tsx` or similar. SMS Template's placeholder mapping uses a related pattern. If absent → NEW widget.
3. `json-editor-textarea` — monospace `<textarea>` + onBlur `JSON.parse` validation. **Verify**: grep for `json-editor.tsx`. If absent → NEW widget.
4. `toggle-switch-binary` — Test/Live two-label toggle (custom binary toggle that maps strings). Pattern: SmsSetup #157 had similar provider-switch.

If any are absent, build them under `presentation/components/rjsf/widgets/` and register in the widget map. These should land as **reusable** widgets, not screen-specific.

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FE_ONLY + BE_ALIGN_DELTAS

MenuName: Payment Gateways
MenuCode: COMPANYPAYMENTGATEWAY
ParentMenu: SET_PAYMENTCONFIG
Module: SETTING
MenuUrl: setting/paymentconfig/companypaymentgateway
OrderBy: 1
MenuIcon: lucide:credit-card
GridType: MASTER_GRID
DisplayMode: card-grid
CardVariant: details

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE

GridFormSchema: GENERATE
GridCode: COMPANYPAYMENTGATEWAY

# Existing seed at PaymentGateway-Menus-seed.sql has wrong ParentMenuId + null URL — see Section ⑫ ISSUE-1.
# DO NOT regenerate that file; new seed lives in companypaymentgateway-sqlscripts.sql with an UPDATE statement.
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer — exact contract for what BE will expose (mostly already there).

**GraphQL Types:**
- Query type: `CompanyPaymentGatewayQueries` (existing — `Base.API/EndPoints/Donation/Queries/CompanyPaymentGatewayQueries.cs`)
- Mutation type: `CompanyPaymentGatewayMutations` (existing — `Base.API/EndPoints/Donation/Mutations/CompanyPaymentGatewayMutations.cs`)
- Helper: `PaymentGatewayQueries` (existing — `Base.API/EndPoints/Shared/Queries/PaymentGatewayQueries.cs`) — ALIGN: append `paymentGatewayList`.

**Queries:**

| GQL Field | Returns | Key Args | Status |
|-----------|---------|----------|--------|
| `companyPaymentGateways` | `PaginatedApiResponse<[CompanyPaymentGatewayResponseDto]>` | `request: GridFeatureRequest` (searchTerm, pageIndex, pageSize, sort) | **EXISTING** — `GetCompanyPaymentGateways` |
| `companyPaymentGatewayById` | `BaseApiResponse<CompanyPaymentGatewayResponseDto>` | `companyPaymentGatewayId: Int!` | **EXISTING** — `GetCompanyPaymentGatewayById` |
| `paymentGatewayList` | `BaseApiResponse<[PaymentGatewayResponseDto]>` | — | **NEW** (ALIGN delta — for ApiSelectV2 in modal) |

**Mutations:**

| GQL Field | Input | Returns | Status |
|-----------|-------|---------|--------|
| `createCompanyPaymentGateway` | `CompanyPaymentGatewayRequestDto` (PLAIN-TEXT API key/secret; BE encrypts) | `BaseApiResponse<CompanyPaymentGatewayRequestDto>` | **EXISTING** — encrypts on save, returns plain back |
| `updateCompanyPaymentGateway` | `CompanyPaymentGatewayRequestDto` | `BaseApiResponse<CompanyPaymentGatewayRequestDto>` | **EXISTING** |
| `activateDeactivateCompanyPaymentGateway` | `companyPaymentGatewayId: Int!` | `BaseApiResponse<CompanyPaymentGatewayRequestDto>` | **EXISTING** |
| `deleteCompanyPaymentGateway` | `companyPaymentGatewayId: Int!` | `BaseApiResponse<CompanyPaymentGatewayRequestDto>` | **EXISTING** |

**Response DTO Fields** (what FE receives — TypeScript shapes):

```ts
export type CompanyPaymentGatewayRequestDto = {
  companyPaymentGatewayId?: number | null;   // null on Create
  companyId: number;                          // set by BE from CurrentUserService
  paymentGatewayId: number;                   // FK to PaymentGateway (#168)
  gatewayEnvironment: string;                 // "sandbox" | "production"
  encryptedApiKey: string;                    // plain text on Create/Update; masked on list; full on GetById
  encryptedApiSecret: string;                 // same pattern
  encryptedWebhookSecret?: string | null;
  merchantId?: string | null;
  additionalConfig?: string | null;           // JSON string
  isDefault: boolean;
  supportedCurrencies?: string | null;        // CSV "USD,EUR"
  supportedCountryCodes?: string | null;      // CSV "US,GB"
  supportedPaymentMethods?: string | null;    // CSV "CARD,UPI" — NEW (ALIGN delta)
};

export interface CompanyPaymentGatewayResponseDto extends CompanyPaymentGatewayRequestDto {
  isActive: boolean;                          // inherited
  paymentGateway?: PaymentGatewayRequestDto;  // nested navigation (from .Include() in handler)
}
```

**Masking behavior in list query** (already implemented — `GetCompanyPaymentGateway.cs:23-33`):
- `EncryptedApiKey` → `***last4` of decrypted value (or `"****"` on decrypt failure)
- `EncryptedApiSecret` → `"********"`
- `EncryptedWebhookSecret` → `"********"` (or null if originally null)

**Full decryption in GetById** (already implemented — `GetCompanyPaymentGatewayById.cs:21-28`):
- Returns plain text for edit modal.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors after ALIGN deltas applied
- [ ] EF migration runs cleanly forward + reverse
- [ ] `pnpm dev` — page loads at `/{lang}/setting/paymentconfig/companypaymentgateway` with no console errors

**Functional Verification (Full E2E):**
- [ ] Empty state: shows "No gateways configured" + `+ Add Gateway` CTA
- [ ] Add Stripe gateway → modal opens → fill fields → Save → card appears
- [ ] Card shows: Stripe icon, gateway name, env badge (Live/Test), default star (if IsDefault), Merchant ID code-chip, currencies chip strip, methods chip strip, country codes chip strip, "Webhook Status — Not monitored" stub row, "Monthly Volume — —" stub row, footer Edit/Test/Logs/Disable buttons
- [ ] Add 2nd gateway as IsDefault=true → 1st card's default star disappears (BE atomic default-clearing)
- [ ] Edit card → modal shows full decrypted API key + secret + webhook secret → modify → Save → list re-renders with new masked value
- [ ] Multi-select tag widget: type "USD", press Enter → chip appears. Click × on chip → removes. Submit → CSV correctly joined.
- [ ] Multi-select for SupportedPaymentMethods loads PAYMENTMETHODTYPE MasterData options
- [ ] Multi-select for SupportedCurrencies loads from `GetAllCurrencyList`
- [ ] AdditionalConfig: malformed JSON → inline error on blur. Valid JSON → no error.
- [ ] Toggle Active (Disable button) → confirm dialog → gateway becomes inactive
- [ ] Delete (from somewhere — possibly inside Edit modal or a confirm dialog from a delete button — TBD UX): soft-delete → card disappears
- [ ] Test Connection / View Logs / Webhook Event Log section: render but only emit toast
- [ ] PaymentGateway dropdown loads Stripe/PayPal/Razorpay/Braintree/Square/Manual (depends on #168 master seed being executed)
- [ ] Filter chip Live / Test: filters card grid
- [ ] Search: matches `paymentGatewayName` + `merchantId`
- [ ] Permissions: non-BUSINESSADMIN sees no `+ Add Gateway` / Edit / Disable buttons (per RoleCapabilities)
- [ ] Mockup parity check: open mockup HTML side-by-side with browser — confirm visual fidelity

**DB Seed Verification:**
- [ ] Menu appears in sidebar under `Settings → Payment Configuration` (NOT under Donation)
- [ ] Menu URL matches `setting/paymentconfig/companypaymentgateway`
- [ ] GridFormSchema renders the form correctly via RJSF
- [ ] #168 master rows (Stripe/PayPal/etc.) seeded — visible in PaymentGateway dropdown

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Status of this screen pre-build:**
1. **Registry was wrong about TYPE + SCOPE + STATUS** (confirmed 2026-05-15):
   - Registry said `FLOW / FULL / NEW` → corrected to `MASTER_GRID(card-grid) / FE_ONLY+ALIGN / PARTIAL(BE_ONLY)`.
   - Reason: BE entity, EF config, schemas, 2 queries, 4 mutations, Mapster all exist. Mockup clearly shows card-grid + Bootstrap modal (NOT a full-page FLOW).
   - `/build-screen` must update the registry row to reflect the corrected classification when finalizing.

2. **Existing seed file is wrong**:
   - `Services/Base/sql-scripts-dyanmic/PaymentGateway-Menus-seed.sql` seeds COMPANYPAYMENTGATEWAY under `ParentMenuCode=PAYMENTGATEWAY` (non-leaf parent) in `ModuleCode=DONATION` with `MenuUrl=null`.
   - MODULE_MENU_REFERENCE.md (line 274) says it belongs under `SET_PAYMENTCONFIG` (MenuId 370) in `SETTING` module with URL `setting/paymentconfig/companypaymentgateway`.
   - **DO NOT touch the existing seed file** (it has 7 other menus + master data).
   - NEW seed file `companypaymentgateway-sqlscripts.sql` will issue an idempotent `UPDATE auth."Menus" SET ParentMenuId=..., ModuleId=..., MenuUrl=..., OrderBy=1 WHERE MenuCode='COMPANYPAYMENTGATEWAY'` to fix the row.

3. **#168 PaymentGateway Master rows are NOT seeded**:
   - `PaymentGateway-MasterData-seed.sql` only seeds MasterData lookups (PAYMENTMETHODTYPE etc.), NOT the `com.PaymentGateways` table itself.
   - The new seed file must insert 6 PaymentGateway rows: Stripe (STRIPE) / PayPal (PAYPAL) / Razorpay (RAZORPAY) / Braintree (BRAINTREE) / Square (SQUARE) / Manual Bank Transfer (MANUAL) — IsActive=true, IsDeleted=false. Pattern: idempotent `INSERT ... WHERE NOT EXISTS`.
   - Without these rows, the modal dropdown will be empty.

4. **CardGrid infrastructure is already built** (SMS Template #29, 2026-04-18). FE Dev REUSES it with `cardVariant=details`. Do NOT re-create.

5. **PaymentMethodsJson encoding choice**: stored as CSV string (`"CARD,UPI,APPLEPAY"`), NOT as a JSON array column. Reason: matches existing pattern for SupportedCurrencies / SupportedCountryCodes. FE splits on load: `value.split(',').filter(Boolean)`.

6. **Decryption key configuration**: BE handlers read `configuration["PaymentGateway:CredentialEncryptionKey"]`. Verify this key is set in `appsettings.json` / `appsettings.Development.json` before testing. If missing, Create handler throws `InvalidOperationException("Encryption key not configured")`.

**Service Dependencies** (UI-only — no backend service implementation):

The following items render fully in the UI but emit toast/placeholder because the backend service layer doesn't exist:

- **SERVICE_PLACEHOLDER: "Test Connection"** button (modal footer + each card's footer). Toast: "Test Connection requires gateway SDK integration — coming in V2". Future: needs `IPaymentGatewayProvider.TestConnectionAsync()` implementations per provider (Stripe/PayPal/Razorpay SDKs).
- **SERVICE_PLACEHOLDER: "View Logs"** button (each card's footer). Toast: "Log viewer coming soon". Future: link to PaymentTransaction grid filtered by this gateway.
- **SERVICE_PLACEHOLDER: "Webhook Status: Connected (last event 2 min ago)"** per-card row. Renders fallback "Not monitored". Future: needs `PaymentGatewayWebhookEvent` entity + timestamp aggregation.
- **SERVICE_PLACEHOLDER: "Monthly Volume: $34,500 (245 transactions)"** per-card row. Renders fallback "—". Future: SUM/COUNT aggregation over `GlobalDonations` (or `PaymentTransactions`) filtered by `CompanyPaymentGatewayId`.
- **SERVICE_PLACEHOLDER: "Webhook Event Log" collapsible table** below the card-grid. Renders empty state "No webhook events yet". Future: needs `PaymentGatewayWebhookEvent` entity + Stripe/PayPal/Razorpay webhook receiver endpoints + listing query.
- **SERVICE_PLACEHOLDER: "Edit Bank Accounts"** action on Manual gateway card (mockup line 822). Toast: "Bank account configuration coming in V2". Future: needs `CompanyBankAccount` child entity (1:M with CompanyPaymentGateway) + per-gateway bank account CRUD.

Full UI must be built (cards, modals, chips, buttons, sections). Only the handler logic for the external service call is mocked.

### § Known Issues (pre-build flagged for Solution Resolver / build agents)

| ID | Raised | Severity | Area | Description | Status |
|----|--------|----------|------|-------------|--------|
| 1 | /plan-screens 2026-05-15 | HIGH | BE seed | Existing `PaymentGateway-Menus-seed.sql` seeds COMPANYPAYMENTGATEWAY with WRONG ParentMenu + null URL. New seed must issue UPDATE rather than INSERT, since the menu row already exists. Idempotent guard required. | OPEN |
| 2 | /plan-screens 2026-05-15 | HIGH | BE seed | `com.PaymentGateways` (#168 master) is NOT seeded anywhere — modal dropdown will be empty without 6 master rows. Seed in `companypaymentgateway-sqlscripts.sql` Section 3. | OPEN |
| 3 | /plan-screens 2026-05-15 | MED | FE | `GetAllCountryList` query may not exist. Verify in Step 2 of `/build-screen` (grep `Base.API/EndPoints/Shared/Queries/` for `Country`). If absent: FE ships static ISO-3166 250-entry constant OR build a NEW BE list query. Recommend the static constant — fewer moving parts. | OPEN |
| 4 | /plan-screens 2026-05-15 | MED | FE widgets | Three custom RJSF widgets may not exist (`password-input`, `multi-select-tags`, `json-editor-textarea`). Solution Resolver must verify existence and either reuse or build as reusable widgets. | OPEN |
| 5 | /plan-screens 2026-05-15 | MED | BE | `(CompanyId, PaymentGatewayId, GatewayEnvironment)` unique index does NOT exist in current migration. Add via new migration `Add_CompanyPaymentGateway_SupportedPaymentMethods_And_UniqueIndex` — combine with the new column to avoid migration sprawl. | OPEN |
| 6 | /plan-screens 2026-05-15 | MED | BE | Single-default-per-company rule NOT enforced in existing Create/Update handlers. Add atomic `ExecuteUpdateAsync` block before insert/update. | OPEN |
| 7 | /plan-screens 2026-05-15 | LOW | UX | When IsDefault toggle is flipped ON in modal, FE should show inline warning toast "This will replace the existing default gateway: {currentDefaultName}". Requires reading current default before submit — small extra query OR rely on BE's atomic clearing + toast after Save. Latter is simpler. | OPEN |
| 8 | /plan-screens 2026-05-15 | LOW | UX | Mockup labels env "Test" / "Live" but BE stores `"sandbox"` / `"production"`. FE must map both directions. Document in widget code. | OPEN |
| 9 | /plan-screens 2026-05-15 | LOW | UX | MANUAL gateway (Bank Transfer) doesn't really have an API key. Mockup card #4 shows different fields (Type / Display / Bank Accounts). Modal currently requires both API key + secret. For V1: pre-fill `"manual"` placeholder when MANUAL is selected; hide Webhook Secret. For V2: nullable credentials when gateway=MANUAL. | OPEN |
| 10 | /plan-screens 2026-05-15 | LOW | FE | "Disable" footer button name doesn't match registry convention (TOGGLE). Render as "Disable" when IsActive=true; "Enable" when IsActive=false. Tooltip clarifies. | OPEN |
| 11 | /plan-screens 2026-05-15 | LOW | FE | Mockup has a "+20 more" link on the currencies chip strip — implement as hover tooltip listing all currencies OR as a popover. Use existing CardGrid chip-strip overflow pattern if available. | OPEN |
| 12 | /plan-screens 2026-05-15 | LOW | BE | Registry's `OrderBy=1` for COMPANYPAYMENTGATEWAY puts it ABOVE PAYMENTGATEWAY (#168 OrderBy=2) under SET_PAYMENTCONFIG. Confirm with user — alternatively flip (PAYMENTGATEWAY master = 1, COMPANYPAYMENTGATEWAY = 2). Per MODULE_MENU_REFERENCE.md current order: COMPANYPAYMENTGATEWAY=1, PAYMENTGATEWAY=2. Keep as-is. | CLOSED |
| 13 | /plan-screens 2026-05-15 | LOW | Test | `IEncryptionService` must be present in DI. Verify `Base.API/DependencyInjection.cs` registers it. | CLOSED — confirmed at `Base.Infrastructure/DependencyInjection.cs:53` (`AddScoped<IEncryptionService, EncryptionService>()`) during Session 1. |
| 14 | /build-screen 2026-05-15 | MED | BE migration | Hand-crafted migration has `.cs` + `ApplicationDbContextModelSnapshot.cs` delta, but `.Designer.cs` was NOT generated (BE Dev's deliberate decision — the 30k-line snapshot copy is error-prone by hand). Apply via `dotnet ef database update` (uses `.cs` Up() — Designer not strictly required) OR run `dotnet ef migrations add Add_CompanyPaymentGateway_SupportedPaymentMethods_And_UniqueIndex --no-build` to regenerate the Designer cleanly. | OPEN |
| 15 | /build-screen 2026-05-15 | LOW | FE | Custom `payment-gateway` card variant was added to card-grid registry (5-file extension — types.ts union + card-variant-registry.ts entry + variants/payment-gateway-card.tsx wrapper + skeletons/payment-gateway-card-skeleton.tsx + index.ts exports) instead of force-fitting the generic `details` variant. `DetailsCardConfig` has no concept of gateway icons / env badges / chip strips / default star / 4-button footer. Same pattern as MembershipTierCard / CertificateTemplateCard precedents. | CLOSED — accepted as the right call. |
| 16 | /build-screen 2026-05-15 | LOW | FE | `GET_PAYMENTGATEWAY_LIST` query in FE assumes `BaseApiResponse<List<...>>` wrapped shape (`result { data { ... } }`). If BE returns a top-level array, FE will need a minor shape adjustment. BE handler returns `BaseApiResponse<List<PaymentGatewayResponseDto>>` so wrapped is correct — verify at `pnpm dev` time. | OPEN |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-15 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Slim Phase 1 validation pass (single Sonnet agent) + user-approved CONFIG block (menu re-parent to SET_PAYMENTCONFIG, seed 6 #168 master rows, hand-crafted EF migration) + Backend Developer (Sonnet) + Frontend Developer (Sonnet). Token cost ~30K total.
- **Files touched**:
  - BE NEW (3):
    - `Base.Application/Business/SharedBusiness/PaymentGateways/Queries/GetAllPaymentGatewayList.cs` (created) — non-paginated list query for ApiSelectV2 source, `[CustomAuthorize(DecoratorSharedModules.PaymentGateway, Permissions.Read)]`.
    - `Base.Infrastructure/Migrations/20260515120000_Add_CompanyPaymentGateway_SupportedPaymentMethods_And_UniqueIndex.cs` (created) — AddColumn + filtered unique CreateIndex; Down reverses both. **NOTE: `.Designer.cs` NOT generated — see ISSUE-14**.
    - `sql-scripts-dyanmic/companypaymentgateway-sqlscripts.sql` (created) — 5-section idempotent seed: menu UPDATE re-parent, MenuCapabilities, BUSINESSADMIN RoleCapabilities, Grid+GridFormSchema (11 fields, 4-section uiSchema), 6 #168 master rows.
  - BE MODIFIED (7):
    - `Base.Domain/Models/DonationModels/CompanyPaymentGateway.cs` (modified) — appended `SupportedPaymentMethods` property.
    - `Base.Infrastructure/Data/Configurations/DonationConfigurations/CompanyPaymentGatewayConfiguration.cs` (modified) — `MaxLength(200)` + composite unique filtered index `IX_CompanyPaymentGateway_Company_Gateway_Env_Unique`.
    - `Base.Application/Schemas/DonationSchemas/CompanyPaymentGatewaySchemas.cs` (modified) — `SupportedPaymentMethods` appended to RequestDto (ResponseDto inherits — see Deviation 2).
    - `Base.Application/Business/DonationBusiness/CompanyPaymentGateways/Commands/CreateCompanyPaymentGateway.cs` (modified) — single-default-clearing `ExecuteUpdateAsync` block inserted before `.Add(entity)`.
    - `Base.Application/Business/DonationBusiness/CompanyPaymentGateways/Commands/UpdateCompanyPaymentGateway.cs` (modified) — added `SupportedPaymentMethods` assignment + single-default-clearing block (excluding current row) before `SaveChangesAsync`.
    - `Base.API/EndPoints/Shared/Queries/PaymentGatewayQueries.cs` (modified) — appended `GetAllPaymentGatewayList` GQL method (`paymentGatewayList` field).
    - `Base.Infrastructure/Migrations/ApplicationDbContextModelSnapshot.cs` (modified) — added `SupportedPaymentMethods` property + index to CompanyPaymentGateway snapshot block.
  - FE NEW (9):
    - `domain/entities/donation-service/CompanyPaymentGatewayDto.ts` (created) — `CompanyPaymentGatewayDto`, `CompanyPaymentGatewayRequestDto`, `CompanyPaymentGatewayResponseDto`.
    - `infrastructure/gql-queries/donation-queries/CompanyPaymentGatewayQuery.ts` (created) — paginated + by-id queries.
    - `infrastructure/gql-mutations/donation-mutations/CompanyPaymentGatewayMutation.ts` (created) — create/update/delete/activate-deactivate mutations.
    - `presentation/pages/setting/paymentconfig/companypaymentgateway.tsx` (created) — page-config dispatcher (capability check → renders index-page).
    - `presentation/components/page-components/setting/paymentconfig/companypaymentgateway/index-page.tsx` (created) — AdvancedDataTable wrapper, displayMode `card-grid`, cardVariant `payment-gateway`.
    - `presentation/components/page-components/setting/paymentconfig/companypaymentgateway/gateway-card.tsx` (created) — custom card body: gateway icon mapped by paymentGatewayCode, env badge, default star, 4 meta-rows, 2 SERVICE_PLACEHOLDER rows, 4-button footer with toast handlers.
    - `presentation/components/page-components/setting/paymentconfig/companypaymentgateway/index.ts` (created) — folder barrel.
    - `presentation/components/page-components/card-grid/variants/payment-gateway-card.tsx` (created) — registry wrapper delegating to GatewayCard.
    - `presentation/components/page-components/card-grid/skeletons/payment-gateway-card-skeleton.tsx` (created) — skeleton matching card shape (header + 4 meta rows + 2 placeholder rows + footer buttons).
  - FE MODIFIED (11):
    - `app/[lang]/setting/paymentconfig/companypaymentgateway/page.tsx` (modified) — REPLACED `UnderConstruction` stub with live page importing CompanyPaymentGatewayPageConfig.
    - `infrastructure/gql-queries/shared-queries/PaymentGatewayQuery.ts` (modified) — appended `GET_PAYMENTGATEWAY_LIST` gql constant.
    - `domain/entities/donation-service/index.ts` (modified) — barrel `export * from "./CompanyPaymentGatewayDto"`.
    - `infrastructure/gql-queries/donation-queries/index.ts` (modified) — barrel `export * from "./CompanyPaymentGatewayQuery"`.
    - `infrastructure/gql-mutations/donation-mutations/index.ts` (modified) — barrel `export * from "./CompanyPaymentGatewayMutation"`.
    - `presentation/pages/setting/paymentconfig/index.ts` (modified) — `export { CompanyPaymentGatewayPageConfig }`.
    - `application/configs/data-table-configs/shared-service-entity-operations.ts` (modified) — appended COMPANYPAYMENTGATEWAY block (6 operations) alongside PAYMENTGATEWAY (lines ~212-236).
    - `presentation/components/page-components/card-grid/types.ts` (modified) — added `"payment-gateway"` to `CardVariant` union + `PaymentGatewayCardConfig` interface.
    - `presentation/components/page-components/card-grid/card-variant-registry.ts` (modified) — registered `payment-gateway` → `{PaymentGatewayCard, PaymentGatewayCardSkeleton}`.
    - `presentation/components/page-components/card-grid/index.ts` (modified) — exported new variant + skeleton + config type.
  - DB: `sql-scripts-dyanmic/companypaymentgateway-sqlscripts.sql` (created — see BE NEW above).
- **Deviations from spec**:
  1. `.Designer.cs` migration file NOT created — BE Dev's deliberate decision (30k-line snapshot copy by hand is error-prone). Snapshot was updated. Apply via `dotnet ef database update` (works) or regenerate Designer with `dotnet ef migrations add ... --no-build`. Tracked as ISSUE-14.
  2. `ResponseDto` does not redeclare `SupportedPaymentMethods` — it inherits from `RequestDto`. Redeclaration with `new` would shadow + risk Mapster mismatch. Correct call.
  3. FE built a custom `payment-gateway` card variant (5-file extension to card-grid registry) rather than force-fitting the generic `details` variant. Same precedent as MembershipTierCard / CertificateTemplateCard. Tracked as ISSUE-15 (CLOSED — accepted).
  4. Anti-pattern grep all-zero. Layout Variant `grid-only` confirmed compliant (no `ScreenHeader` import; the string appears only in one comment explaining Variant A).
  5. Sibling worktree drift check passed — all writes landed in `pwds-soruban - Copy/`; no leaks to `pwds-soruban/`.
- **Known issues opened**: ISSUE-14 (Designer.cs regen, MED), ISSUE-16 (GET_PAYMENTGATEWAY_LIST shape verification, LOW).
- **Known issues closed**: ISSUE-13 (IEncryptionService DI confirmed at DependencyInjection.cs:53). ISSUE-15 (custom variant accepted as the right call).
- **Next step**: User to run (1) `dotnet ef database update` to apply migration (after stopping API if it's holding file locks per `feedback_baseurl_user_managed.md`-style file-lock advice), (2) execute `companypaymentgateway-sqlscripts.sql` against the database, (3) `dotnet build` to verify BE, (4) `pnpm dev` to verify FE — page loads at `/{lang}/setting/paymentconfig/companypaymentgateway`, exercise full CRUD + the 22 acceptance criteria in Section ⑪.
