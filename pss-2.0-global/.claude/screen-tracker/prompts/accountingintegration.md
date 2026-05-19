---
screen: AccountingIntegration
registry_id: 88
module: Setting
status: COMPLETED
scope: FULL (FE has UnderConstruction stub at `[lang]/setting/integration/accountingintegration/page.tsx` — replace; no BE exists)
screen_type: CONFIG
config_subtype: SETTINGS_PAGE
storage_pattern: singleton-per-tenant (root config) + 4 child-list tables (account mappings / payment-mode mappings / sync logs / failed records)
save_model: save-per-section
complexity: High
new_module: YES — new schema `integ` and new Group `Integration` (this is the FIRST entity under both — Social Media, API Management, and Marketplace siblings under `SET_INTEGRATION` will reuse the same schema/group)
planned_date: 2026-05-18
completed_date: 2026-05-19
last_session_date: 2026-05-19
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (`html_mockup_screens/screens/settings/accounting-integration.html`, 1217 lines) — 7 sections vertical stack: Connection Status Banner / Accounting Provider (5 cards) / QuickBooks Connection Details / Account Mapping (per-DonationPurpose grid) / Payment Mode Mapping (per-PaymentMode grid) / Sync Settings / Recent Sync Log + Failed Records read-only tables
- [x] Sub-type identified: `SETTINGS_PAGE` (multi-section tenant-scoped singleton + 4 child collections)
- [x] Storage model: `singleton-per-tenant` (`integ.AccountingIntegrations` root) + `integ.AccountingAccountMappings` (DonationPurpose → external account/tax) + `integ.AccountingPaymentModeMappings` (PaymentMode → external method/bank) + `integ.AccountingSyncLogs` (write-once history) + `integ.AccountingFailedRecords` (sync-failure queue with Retry/Skip lifecycle)
- [x] Save model: `save-per-section` — Connect button persists provider switch + credentials; Auto-Map persists mappings diff; Save Settings persists sync settings; Retry/Skip persists per-row state. Each section has independent persistence (mirrors SmsSetup #157 sibling pattern).
- [x] Sensitive fields & role gates identified: BUSINESSADMIN-only; OAuth `AccessToken`/`RefreshToken`/`ClientSecret`/`ApiKey` (for Custom API provider) masked + write-only; OAuth Connect/Refresh/Disconnect + Auto-Map + Sync Now + Retry are SERVICE_PLACEHOLDER (no QuickBooks/Xero/Zoho/Tally SDKs in codebase yet)
- [x] FK targets resolved (DonationPurpose at `DonationModels/DonationPurpose.cs` query `GetDonationPurposes`; PaymentMode at `SharedModels/PaymentMode.cs` query `GetPaymentModes`; Company via HttpContext, never a form field)
- [x] File manifest computed (BE: ~25 NEW + 5 MODIFY + EF migration + DB seed; FE: ~17 NEW + 5 wiring)
- [x] Approval config pre-filled (READ + MODIFY only on root singleton; child mapping tables get CREATE/MODIFY/DELETE under same MenuCode)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (pre-baked in prompt §①/④ — config purpose + edit personas + risk + sync-flow semantics)
- [x] Solution Resolution complete (pre-baked in prompt §⑤ — SETTINGS_PAGE / save-per-section / new `integ` schema confirmed)
- [x] UX Design finalized (pre-baked in prompt §⑥ — vertical-stack 8 cards)
- [x] User Approval received (2026-05-18 — FULL scope, Sonnet for both BE+FE)
- [x] Backend code generated (28 NEW + 5 MODIFY incl. IntegrationMappings + DecoratorIntegrationModules)
- [x] Backend wiring complete (IApplicationDbContext + ApplicationDbContext DbSets registered; configurations applied; default seeder DI-registered)
- [x] Frontend code generated (17 NEW: DTO + 2 GQL barrels + composer page + 10 components + Zustand store + page-config + entity-operations)
- [x] Frontend wiring complete (UnderConstruction stub replaced; 8 MODIFY: route page, 2 gql barrel re-exports, entity-operations registry, 2 pages index re-exports, integration sub-folder index, data-table-configs index)
- [x] DB Seed script generated (`accountingintegration-sqlscripts.sql` — Menu under SET_INTEGRATION OrderBy=1, 6 capabilities, BUSINESSADMIN grants, default rows per tenant, Grid `ACCOUNTINGINTEGRATION` GridType=CONFIG, sample SyncLogs)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] EF migration `Add_AccountingIntegration_And_Children` applied (creates `integ` schema if not exists)
- [ ] pnpm dev — page loads at `/{lang}/setting/integration/accountingintegration`
- [ ] **SETTINGS_PAGE checks**:
  - [ ] First-load auto-seeds default AccountingIntegration row for current tenant (no 404 / null state) — `Provider='None'`, `IsConnected=false`, `AutoSyncEnabled=false`, `SyncFrequencyHours=4`, `SyncDirection='PUSH'`, `SyncStartDate=null`, `SyncEntitiesJson='["Donations","Refunds"]'`
  - [ ] Header status banner: when `IsConnected=false` → grey banner "Not connected — pick a provider"; when `true` → green banner with `LastSyncAt` (relative time) + `NextScheduledSyncAt` + Sync Now / Sync History buttons
  - [ ] Provider Selection card: 5 provider cards (QuickBooks Online / Xero / Tally / Zoho Books / Custom API); the currently-connected provider shows "Connected" badge + Disconnect button; others show "Connect" / "Configure" (Custom) button; clicking Connect → SERVICE_PLACEHOLDER toast ("OAuth integration not yet implemented; provider saved locally as 'pending')
  - [ ] Connection Details card visible ONLY when `IsConnected=true` — read-only rows: Company (ExternalCompanyName), Connected Since (ConnectedAt), Connected By (ConnectedByUserName via FK or denormalized), OAuth Status (`AccessTokenExpiresAt` → "Token valid (expires …)" if future, "Token expired" if past), Realm/Tenant ID (`ExternalRealmId`, monospace font), Refresh Token + Disconnect actions (SERVICE_PLACEHOLDER on Refresh; real DB clear on Disconnect — sets IsConnected=false, NULLs token fields)
  - [ ] Account Mapping table: one row per Company DonationPurpose; columns = Purpose name (read-only) + arrow icon + External Account dropdown (free-text combobox — accepts existing or new account code) + Tax Code dropdown (free-text combobox) + Delete (clears the row's mapping); unmapped rows show amber border + "Unmapped" pill + warning arrow icon; Auto-Map button → SERVICE_PLACEHOLDER toast ("Auto-mapping requires provider API — settings preserved"); Create Account in QuickBooks button → SERVICE_PLACEHOLDER modal (input form for new external account → toast on save)
  - [ ] Payment Mode Mapping table: one row per Company PaymentMode (Cash, Cheque, Bank Transfer, Online/Card); columns = Mode (read-only + icon) + arrow + Payment Method combobox + Bank/Deposit Account combobox
  - [ ] Sync Settings card: AutoSyncEnabled switch + label dynamic ("Enabled — sync every {N} hours" vs "Disabled — manual only"); SyncFrequencyHours dropdown (1/2/4/6/12/24/Manual); SyncDirection dropdown (PUSH/PULL/BIDIRECTIONAL) with helper text "Recommended: Push-only to keep PSS as the source of truth"; SyncEntitiesJson checkbox group (Donations / Refunds / Contacts / Pledges / Receipts); SyncStartDate date picker with helper "Only donations on or after this date will be synced"; Save Settings button → PATCH only sync-settings fields
  - [ ] Recent Sync Log card: read-only table, last N=10 from `integ.AccountingSyncLogs` desc by `SyncStartedAt`; columns Sync Time / Direction (PUSH→QB icon) / Records / Synced / Failed / Duration (`DurationMs`) / Status (success/partial/error chip); "View Full Log" link → navigate to `setting/integration/accountingsynclog` (separate screen, NOT in scope here — link only)
  - [ ] Failed Records card: header badge with count from `integ.AccountingFailedRecords WHERE Status='Pending'`; table columns Record (display name + timestamp) / Type (Donation/Refund/Pledge chip) / Error message / Actions (Skip / Retry / View in QB); Skip action → real DB update sets `Status='Skipped'` + drops out of list; Retry action → SERVICE_PLACEHOLDER toast ("Retry requires provider API; record marked queued") + sets `Status='QueuedForRetry'`; View in QB → opens new tab to `{provider}://app/transactions/{externalRefId}` (URL composed client-side; SERVICE_PLACEHOLDER if provider not connected); Retry All / Skip All bulk buttons fire one POST against all current failed records
  - [ ] Sensitive fields (`AccessToken` / `RefreshToken` / `ClientSecret` / Custom API `ApiKey` / `ApiSecret`) rendered as password input + reveal toggle; empty submit ⇒ unchanged; non-empty ⇒ overwrite
  - [ ] Provider switch warning: when user clicks Connect on a NEW provider while currently connected to a different one → modal "Switching providers will disconnect {current} and reset all mappings. Continue?" → on confirm: clear current credentials, set `Provider=<new>`, set `IsConnected=false`, KEEP mappings (mappings are per-purpose, not per-provider)
  - [ ] Save-per-section: each card's Save persists ONLY that card's fields; cards with no save button (read-only tables, status banner) don't show one
  - [ ] Unsaved-changes blocker on dirty navigation
  - [ ] Role-gated for BUSINESSADMIN; non-privileged roles see DefaultAccessDenied
- [ ] Empty / loading / error states render (empty: provider not connected; sync-log empty: "No sync runs yet"; failed-records empty: "No failed records")
- [ ] DB Seed — menu visible at Settings › Integration › Accounting Integration

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: AccountingIntegration
Module: Setting (FE route under `setting/integration/accountingintegration`)
Schema: `integ` (NEW — first entity in the integrations schema; siblings ACCOUNTINGINTEGRATION / SOCIALMEDIAINTEGRATION / APIMANAGEMENT / INTEGRATIONMARKETPLACE under `SET_INTEGRATION` will share this schema as they're built)
Group: `Integration` (handlers / configs / schemas / endpoints / mappings live under `IntegrationBusiness/AccountingIntegrations/`, `IntegrationConfigurations`, `IntegrationSchemas`, `EndPoints/Integration`, `IntegrationMappings`)

**Business**: AccountingIntegration is the **tenant-scoped bridge** between PSS donation activity and an external accounting platform (QuickBooks Online, Xero, Tally for India, Zoho Books, or a generic Custom API endpoint). It encapsulates four orthogonal concerns the BUSINESSADMIN must own: **(1) Provider connection & credentials** — which accounting platform the tenant uses, the OAuth tokens / API keys / realm-id needed to authenticate, and the lifecycle of that connection (connected / token-expired / disconnected); **(2) Chart-of-Accounts & Tax-Code mapping** — for every PSS DonationPurpose, which external GL income account each donation should post to, and which external tax code applies (this is the lynchpin of accurate book-keeping: a donation to "Orphan Care" must always land in the same QB account "4100 — Orphan Care Income"); **(3) Payment-mode mapping** — for every PSS payment mode (Cash, Cheque, Bank Transfer, Online/Card), which external payment method + bank deposit account the matching donation should debit; **(4) Sync behavior & operational health** — whether auto-sync is on, frequency, direction (push-only is recommended — keep PSS as source of truth), which entity types sync, retroactive cut-off date, plus the read-only operational dashboard (recent sync log + failed-records queue with retry/skip). Edit cadence: **one-time onboarding setup** for sections 1-3, **rare re-tuning** (new DonationPurpose added → admin maps it; new bank account opened → admin remaps; provider token expires every 90-180 days → admin re-OAuth's); the sync log & failed-records sections are **operational dashboards** consulted weekly or whenever a failure email fires. Personas: BUSINESSADMIN only — financial-control-sensitive setup. Risk-of-misconfig is **VERY HIGH**: wrong account mapping = donation revenue posted to the wrong GL account = misstated financial statements + audit findings; wrong tax code mapping = mis-claimed tax exemption + tax penalty; wrong sync direction (pull instead of push) = PSS overwritten by stale accounting data; missing failed-record handling = silent revenue leakage where donations never posted. What's unique about this config's UX vs. a generic settings page: **(a)** the provider-card selector is a card-grid pattern (not a dropdown) so each provider's brand identity is visible and the connection state is immediately obvious; **(b)** the connection-details card only renders WHEN connected — the screen has two macro-modes (disconnected: provider grid + sync settings + mappings are read-only / disconnected: provider grid + connection details + mappings active); **(c)** the two mapping tables are NOT child grids inside an RJSF form — they're inline-edit tables with combobox dropdowns whose options come from a SERVICE_PLACEHOLDER for V1 (no real provider API to fetch chart-of-accounts from, so dropdowns become free-text comboboxes that accept manual entries until the integration ships); **(d)** the sync log & failed-records sections are **read mostly, retry rarely** — they bind to tables written by a future background sync worker, but the UI is fully built and the Retry/Skip actions DO persist (Retry sets `Status='QueuedForRetry'` even if no worker picks it up yet, Skip is a real terminal state); **(e)** the "Failed Records" Retry/Skip semantics matter for compliance — Skip is auditable ("we deliberately abandoned this transaction"), Retry just re-queues. The closest sibling is SmsSetup #157 (same singleton + child-tables + save-per-section pattern, similar masked-credentials + SERVICE_PLACEHOLDER on external API) and EmailProviderConfig #84 (provider-card-selector + conditional sub-form per provider); together they form the **"integration trio"** in `SET_INTEGRATION` + `SET_COMMUNICATIONCONFIG` parents.

> **Why §① is heavier than other screens**: an agent that doesn't grasp the **financial-control** dimension (every mapping is a journal-entry rule) will hide the mapping tables behind a tab or omit the "Unmapped" warning UX, breaking the value proposition. They are the COMPLIANCE BACKBONE of this screen — the reason it exists separately from a generic "API Connection Setup".

---

## ② Storage Model

> **Consumer**: BA Agent → Backend Developer
> **Storage Pattern**: `singleton-per-tenant` (root) + 4 child collection tables
> Audit columns (CreatedBy / CreatedDate / ModifiedBy / ModifiedDate / IsActive / IsDeleted) inherited from `Entity` base — DO NOT enumerate.
> CompanyId is **always** present and **NEVER** a form field — derived from HttpContext (`ITenantContext.GetRequiredTenantId()`).

This screen touches **5 tables** behind the singleton:

### Stamp: `singleton-per-tenant` + child-collections

### Primary table: `integ."AccountingIntegrations"` (singleton — 1 row per Company)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AccountingIntegrationId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (NOT a form field — HttpContext); unique index ensures singleton |
| Provider | string | 30 | YES | — | `'QuickBooksOnline' | 'Xero' | 'Tally' | 'ZohoBooks' | 'CustomApi' | 'None'`; default `'None'`. Provider master switch. |
| IsConnected | bool | — | YES | — | true when OAuth/API completed; default false |
| ConnectionStatus | string | 20 | NO | — | `'Active' | 'TokenExpired' | 'Disconnected' | 'Error'`; computed at GET from `IsConnected` + `AccessTokenExpiresAt` |
| ExternalCompanyName | string | 200 | NO | — | e.g. "Global Humanitarian Foundation" — display in connection-details card |
| ExternalRealmId | string | 100 | NO | — | QB Realm ID / Xero Tenant ID / Tally Company ID — monospace display |
| AccessToken | string | 2000 | NO | — | **SENSITIVE** — masked on read (omitted in GET), write-only on update |
| RefreshToken | string | 2000 | NO | — | **SENSITIVE** — same treatment |
| AccessTokenExpiresAt | DateTime? | — | NO | — | UTC; null when never connected; drives "Token valid (expires ...)" badge |
| ClientId | string | 200 | NO | — | OAuth client id (per-tenant for QB, app-level for others — keep per-row to stay flexible) |
| ClientSecret | string | 500 | NO | — | **SENSITIVE** — masked |
| CustomApiBaseUrl | string | 500 | NO | — | Only used when Provider='CustomApi' |
| CustomApiAuthType | string | 30 | NO | — | `'ApiKey' | 'BasicAuth' | 'BearerToken'` — only when Provider='CustomApi' |
| CustomApiKey | string | 1000 | NO | — | **SENSITIVE** — masked; only when CustomApi |
| CustomApiSecret | string | 1000 | NO | — | **SENSITIVE** — masked; only when CustomApi |
| ConnectedAt | DateTime? | — | NO | — | First successful connect timestamp (UTC) |
| ConnectedByUserId | int? | — | NO | corg.Users | Who initiated the connection (FK for audit) |
| LastSyncAt | DateTime? | — | NO | — | Last completed sync run (UTC) |
| NextScheduledSyncAt | DateTime? | — | NO | — | Computed `LastSyncAt + SyncFrequencyHours` when AutoSync=true |
| AutoSyncEnabled | bool | — | YES | — | default false |
| SyncFrequencyHours | int | — | YES | — | 1/2/4/6/12/24 or 0 = Manual; default 4 |
| SyncDirection | string | 20 | YES | — | `'PUSH' | 'PULL' | 'BIDIRECTIONAL'`; default 'PUSH' |
| SyncEntitiesJson | string | 500 | YES | — | JSON array of entity codes: `["Donations","Refunds","Contacts","Pledges","Receipts"]`; default `["Donations","Refunds"]` |
| SyncStartDate | DateTime? | — | NO | — | Date cut-off — only sync donations on/after this date |

**Singleton constraint**:
- Unique filtered index on `(CompanyId)` WHERE `IsDeleted=false` — exactly one row per tenant
- First-load behavior: if no row exists for current tenant in `GetAccountingIntegrationSettings`, auto-create with seeded defaults (Provider='None', AutoSyncEnabled=false, SyncFrequencyHours=4, SyncDirection='PUSH', SyncEntitiesJson=`'["Donations","Refunds"]'`)

### Child table 1: `integ."AccountingAccountMappings"` (per-DonationPurpose mappings)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AccountingAccountMappingId | int | — | PK | — | Primary key |
| AccountingIntegrationId | int | — | YES | integ.AccountingIntegrations | Parent FK |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (denormalized for query convenience) |
| DonationPurposeId | int | — | YES | corg.DonationPurposes | The PSS purpose being mapped |
| ExternalAccountCode | string | 50 | NO | — | e.g. "4100" — nullable when "Unmapped" |
| ExternalAccountName | string | 200 | NO | — | e.g. "Orphan Care Income" |
| ExternalTaxCode | string | 30 | NO | — | e.g. "TAX001" |
| ExternalTaxName | string | 100 | NO | — | e.g. "Exempt" |

**Composite unique**: `(CompanyId, DonationPurposeId)` WHERE `IsDeleted=false` — one mapping per purpose per tenant.

### Child table 2: `integ."AccountingPaymentModeMappings"` (per-PaymentMode mappings)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AccountingPaymentModeMappingId | int | — | PK | — | Primary key |
| AccountingIntegrationId | int | — | YES | integ.AccountingIntegrations | Parent FK |
| CompanyId | int | — | YES | corg.Companies | Tenant scope |
| PaymentModeId | int | — | YES | com.PaymentModes | The PSS payment mode being mapped |
| ExternalPaymentMethod | string | 50 | NO | — | e.g. "Cash" / "Cheque" / "Credit Card" |
| ExternalBankAccountCode | string | 50 | NO | — | e.g. "1010" |
| ExternalBankAccountName | string | 200 | NO | — | e.g. "Petty Cash Account" |

**Composite unique**: `(CompanyId, PaymentModeId)` WHERE `IsDeleted=false`.

### Child table 3: `integ."AccountingSyncLogs"` (read-only history — write-only by future sync worker)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AccountingSyncLogId | int | — | PK | — | Primary key |
| AccountingIntegrationId | int | — | YES | integ.AccountingIntegrations | Parent FK |
| CompanyId | int | — | YES | corg.Companies | Tenant scope (denormalized) |
| SyncStartedAt | DateTime | — | YES | — | UTC start |
| SyncEndedAt | DateTime? | — | NO | — | UTC end; null while in-flight |
| DurationMs | int? | — | NO | — | Computed end-start |
| Direction | string | 20 | YES | — | `'PUSH' | 'PULL'` |
| TotalRecords | int | — | YES | — | Records attempted |
| SyncedRecords | int | — | YES | — | Records successful |
| FailedRecords | int | — | YES | — | Records failed |
| Status | string | 20 | YES | — | `'InProgress' | 'Complete' | 'Partial' | 'Error'` |
| TriggerType | string | 20 | YES | — | `'Manual' | 'Scheduled' | 'OnRetry'` |
| ErrorSummary | string | 500 | NO | — | Top-level error if Status='Error' |

> **No mutation handlers on this table from this screen** — it's read-only from the AccountingIntegration UI (Recent Sync Log card). The write path is owned by the future sync worker. The seed inserts 2-3 sample rows so the table renders during E2E QA.

### Child table 4: `integ."AccountingFailedRecords"` (sync-failure queue — Skip/Retry from UI)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AccountingFailedRecordId | int | — | PK | — | Primary key |
| AccountingSyncLogId | int | — | YES | integ.AccountingSyncLogs | The sync run that produced the failure |
| CompanyId | int | — | YES | corg.Companies | Tenant scope |
| InternalRecordType | string | 30 | YES | — | `'Donation' | 'Refund' | 'Pledge' | 'Contact' | 'Receipt'` |
| InternalRecordId | int | — | YES | — | Soft-FK to the PSS record (Donation.GlobalDonationId etc.) |
| InternalRecordRef | string | 50 | NO | — | Display ref like `'DON-2026-04892'` for the UI |
| InternalRecordDisplayName | string | 200 | NO | — | e.g. "Fatimah Al-Rashid · Apr 12, 2:04 PM" |
| ExternalRefId | string | 200 | NO | — | If partially synced, the external ref to deep-link (View in QB) |
| ErrorMessage | string | 500 | YES | — | "Account 4500 not found in QuickBooks" |
| Status | string | 20 | YES | — | `'Pending' | 'Skipped' | 'QueuedForRetry' | 'Resolved'`; UI shows only `Pending` + `QueuedForRetry` |
| ResolvedAt | DateTime? | — | NO | — | When Skip / Resolved transition fired |
| ResolvedByUserId | int? | — | NO | corg.Users | Audit |

> **Mutations from this screen**: only `SkipFailedRecord` and `RetryFailedRecord` (the Retry being SERVICE_PLACEHOLDER for the actual provider POST but the DB transition `Pending → QueuedForRetry` is real).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation properties) + Frontend Developer (for combobox data sources)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| AccountingAccountMappings.DonationPurposeId | DonationPurpose | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/DonationPurpose.cs` | `getDonationPurposes` (paginated — pass `pageSize=999` for "fetch-all"; see ISSUE-1) | `donationPurposeName` | `DonationPurposeResponseDto` |
| AccountingPaymentModeMappings.PaymentModeId | PaymentMode | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/PaymentMode.cs` | `getPaymentModes` (paginated — same caveat) | `paymentModeName` | `PaymentModeResponseDto` |
| AccountingIntegrations.ConnectedByUserId | User | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/AuthModels/User.cs` | `getUserById` | `userName` | `UserResponseDto` (only ConnectedByUserName projection needed; eager-loaded into the composite settings DTO at Get time) |
| AccountingFailedRecords.ResolvedByUserId | User | (same as above) | (same — audit only) | (same) | (same) |
| AccountingFailedRecords.AccountingSyncLogId | AccountingSyncLog | `integ.AccountingSyncLogs` (this round) | (no public GQL — internal FK only) | — | — |

> **No FK dropdowns for Provider field** — it's a hard-coded enum (`'QuickBooksOnline' | 'Xero' | 'Tally' | 'ZohoBooks' | 'CustomApi' | 'None'`) rendered as card selector.
> **No FK dropdown for ExternalAccountCode/Name** — V1 is a free-text combobox (manual entry). When provider integration ships, this becomes an ApiSelect bound to `GetExternalAccountChartFromProvider` (SERVICE_PLACEHOLDER currently — see §⑫).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Singleton / Cardinality Rules:**
- Only one `AccountingIntegrations` row per Company — Update only, no Create/Delete via API.
- Default row auto-seeded on first GET if missing (Provider='None', defaults as listed in §②).
- Child mapping tables (`AccountingAccountMappings`, `AccountingPaymentModeMappings`) are 1:1 per (CompanyId, ParentEntityId) — composite unique enforces this; the upsert semantic on save is "if exists, update; if not, insert".
- `AccountingSyncLogs` is **append-only from this screen** — no Create/Update/Delete from the AccountingIntegration UI. (Inserts happen from the future sync worker outside this screen's scope.)
- `AccountingFailedRecords` is mutated ONLY via `SkipFailedRecord` and `RetryFailedRecord` from this screen (no Create/Delete).

**Required Field Rules:**
- `Provider` always required (NOT NULL) — defaults to `'None'` until first Connect.
- `AutoSyncEnabled`, `SyncFrequencyHours`, `SyncDirection`, `SyncEntitiesJson` always required (NOT NULL — seeded defaults handle this).
- Mapping rows: `DonationPurposeId` / `PaymentModeId` required; external fields optional (NULL = "Unmapped" state in UI).

**Conditional Rules:**
- If `Provider='CustomApi'` → `CustomApiBaseUrl` + `CustomApiAuthType` are required to set `IsConnected=true`.
- If `Provider='CustomApi'` AND `CustomApiAuthType='ApiKey'` → `CustomApiKey` required.
- If `Provider='CustomApi'` AND `CustomApiAuthType='BasicAuth'` → `CustomApiKey` (username) + `CustomApiSecret` (password) required.
- If `Provider='CustomApi'` AND `CustomApiAuthType='BearerToken'` → `AccessToken` required.
- If `Provider ∈ {QuickBooksOnline, Xero, Tally, ZohoBooks}` → `AccessToken` + `RefreshToken` + `AccessTokenExpiresAt` required to set `IsConnected=true` (set by the SERVICE_PLACEHOLDER OAuth handler).
- If `AutoSyncEnabled=true` → `SyncFrequencyHours > 0` (cannot be 0=Manual).
- If `SyncDirection='BIDIRECTIONAL'` → display a warning toast on save ("Bidirectional sync can overwrite PSS data — confirm").
- Provider switch (changing `Provider` while `IsConnected=true`) → server-side: clear current credentials atomically + set `IsConnected=false` + KEEP mappings (mappings are per-purpose/payment-mode, not per-provider, but external account codes will likely be invalid — UI re-renders all mappings as "Unmapped" visually until admin re-confirms).

**Sensitive Fields** (masking, audit, role-gating):

| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| AccessToken | secret (OAuth) | NEVER returned in GET response (omitted from DTO) | empty string ⇒ unchanged; non-empty ⇒ overwrite | log "OAuth token rotated" with actor + provider |
| RefreshToken | secret (OAuth) | NEVER returned | same | log "Refresh token rotated" |
| ClientSecret | secret | NEVER returned | same | log "Client secret rotated" |
| CustomApiKey | secret | NEVER returned | same | log "Custom API key rotated" |
| CustomApiSecret | secret | NEVER returned | same | log "Custom API secret rotated" |
| ExternalRealmId | identifier (not secret) | plain monospace | normal | log on first connect only |
| Provider | normal | plain | normal | log every change with old→new + actor (provider switch is significant) |

**Read-only / System-controlled Fields:**
- `ConnectionStatus` — computed at GET, never editable.
- `ConnectedAt`, `ConnectedByUserId`, `LastSyncAt`, `NextScheduledSyncAt` — set by handlers, never accepted from form payload.
- All `AccountingSyncLog` fields — written by sync worker, read-only from this screen.

**Dangerous Actions** (require confirm + audit):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Disconnect Provider | Clears AccessToken/RefreshToken/ClientSecret, sets IsConnected=false, KEEPS mappings | Modal "Disconnect {provider}? You can reconnect later. Mappings will be preserved." | log "Provider disconnected" with actor + provider |
| Switch Provider (while connected) | Same as Disconnect + sets new Provider + opens connect flow | Modal "Switching from {current} to {new} will disconnect {current}. Mappings preserved. Continue?" | log "Provider switched" |
| Refresh OAuth Token | SERVICE_PLACEHOLDER — updates AccessTokenExpiresAt | none (low-risk) | log "Token refreshed" |
| Skip All Failed Records | Bulk DB update `Status='Skipped'` on all current Pending failures | Modal "Skip {N} failed records? This is irreversible." | log "Bulk skip — {N} records" |
| Retry All Failed Records | SERVICE_PLACEHOLDER + DB update `Status='QueuedForRetry'` | none (low-risk — can be re-Skipped) | log "Bulk retry — {N} records" |

**Role Gating** (which sections / fields are visible / editable per role):

| Role | Sections Visible | Sections Editable | Notes |
|------|------------------|-------------------|-------|
| BUSINESSADMIN | all | all | full access |
| Others | none | none | non-privileged role → DefaultAccessDenied page |

**Workflow** — not applicable (no draft/publish lifecycle). Connection state machine (`Disconnected → Connecting → Active → TokenExpired → Active(refresh) / Disconnected`) is implicit via fields, not a workflow column.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: CONFIG
**Config Sub-type**: `SETTINGS_PAGE`
**Storage Pattern**: `singleton-per-tenant` (root) + 4 child collections
**Save Model**: `save-per-section`

**Reason**: 7+ semantically-independent cards on a vertical stack — saving the sync settings shouldn't require re-typing OAuth credentials, and mapping changes shouldn't require touching sync settings. Each card is the natural unit of intent (mirror of SmsSetup #157 which uses save-per-section for the same reason). Autosave is too risky for OAuth/credentials and adds no value over an explicit Save button on each card; save-all forces unnecessary repetition. The provider-card grid is special — it's "selection + Connect button" (one combined action that PATCHes Provider field and kicks off OAuth SERVICE_PLACEHOLDER).

**Backend Patterns Required:**

For SETTINGS_PAGE (singleton-per-tenant) + child collections:
- [x] `GetAccountingIntegrationSettings` composite query — fetches root + all mappings + last 10 sync logs + all pending failed records in one tenant-scoped call (single round-trip from FE); auto-seeds defaults if missing
- [x] `UpdateAccountingIntegrationConnection` mutation — updates provider + credentials section only (Provider, IsConnected, ExternalCompanyName, ExternalRealmId, AccessToken, RefreshToken, AccessTokenExpiresAt, ClientId, ClientSecret, CustomApi* fields, ConnectedAt, ConnectedByUserId)
- [x] `UpdateAccountingSyncSettings` mutation — updates sync section only (AutoSyncEnabled, SyncFrequencyHours, SyncDirection, SyncEntitiesJson, SyncStartDate)
- [x] `BulkUpsertAccountingAccountMappings` mutation — accepts list of mapping deltas; upserts by (CompanyId, DonationPurposeId)
- [x] `BulkUpsertAccountingPaymentModeMappings` mutation — accepts list of mapping deltas; upserts by (CompanyId, PaymentModeId)
- [x] `DeleteAccountingAccountMapping` mutation — clears one mapping by id (trash-can icon per row)
- [x] `DisconnectAccountingProvider` mutation — clears credentials atomically (real handler, no service call)
- [x] `ConnectAccountingProvider` mutation — **SERVICE_PLACEHOLDER** — accepts Provider + optional Custom API config; returns mock success with fake AccessToken/RealmId so the UI exercises the Connected state path
- [x] `RefreshAccountingProviderToken` mutation — **SERVICE_PLACEHOLDER** — extends AccessTokenExpiresAt
- [x] `AutoMapAccountingAccounts` mutation — **SERVICE_PLACEHOLDER** — accepts no input; returns the existing mappings unchanged + toast "Auto-mapping requires provider API"
- [x] `CreateExternalAccount` mutation — **SERVICE_PLACEHOLDER** — accepts external account form data; returns mock success
- [x] `TriggerManualAccountingSync` mutation — **SERVICE_PLACEHOLDER** — inserts a `AccountingSyncLog` row with `Status='Complete'` + a few mocked counts so the Recent Sync Log card refreshes
- [x] `SkipAccountingFailedRecord` mutation — **REAL** — DB transition `Status='Skipped'`
- [x] `RetryAccountingFailedRecord` mutation — **SERVICE_PLACEHOLDER (partial)** — DB transition `Status='QueuedForRetry'` (real) + toast "Queued for retry"
- [x] `BulkSkipFailedRecords` + `BulkRetryFailedRecords` — same as above, batched
- [x] Tenant scoping (CompanyId from HttpContext) on every handler
- [x] Sensitive-field handling — DTO projection strips AccessToken/RefreshToken/ClientSecret/CustomApiKey/CustomApiSecret from GET; update commands accept them and apply only when non-empty
- [x] Audit-trail emission for sensitive / regulatory fields (Provider switch, OAuth rotation, disconnect, bulk skip)

**Frontend Patterns Required:**

For SETTINGS_PAGE (vertical-stack, save-per-section):
- [x] Custom multi-card page (NOT RJSF modal, NOT view-page 3-mode) — single page, 8 stacked cards
- [x] Vertical-stack container — no tabs, no sidebar; the cards are conceptually a one-page checklist for an admin
- [x] Card component per section (own React component, own form hook, own save handler)
- [x] Provider Card Selector (5 brand-styled cards in a CSS grid; selected state + Connected badge + Connect/Configure/Disconnect button)
- [x] Conditional rendering: Connection Details card visible only when `IsConnected=true`
- [x] Conditional rendering: CustomApi config block visible only when `Provider='CustomApi'`
- [x] Sensitive-field input (password input with eye-toggle reveal, masked display)
- [x] Read-only system-field display (chip / disabled input for ConnectionStatus / ConnectedAt / LastSyncAt)
- [x] Confirm modal for dangerous actions (Disconnect / Switch provider / Skip All / Retry All)
- [x] Combobox / free-text dropdown for mapping rows (V1: free entry; V2: ApiSelect from provider chart-of-accounts SERVICE_PLACEHOLDER)
- [x] "Unmapped" warning UX — amber row border + amber dropdown border + "Unmapped" pill in actions column
- [x] Save indicator (saved-at timestamp / dirty badge / unsaved-changes blocker)
- [x] Read-only sync-log table (no pagination — fixed last-10; "View Full Log" link to future separate screen)
- [x] Failed-records table with per-row Skip/Retry/View-in-QB actions + bulk Skip All / Retry All
- [x] Zustand store for the page-level state (provider switch warning modal state, dirty-section tracking, mapping table local edits before save) — sibling pattern to SmsSetup's store
- [x] Single composite GraphQL query at mount (`getAccountingIntegrationSettings`) returning all 5 tables' data in one round-trip; per-section save mutations refetch only the affected slice

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Sub-type = SETTINGS_PAGE. Block A applies. Delete unused blocks B/C from `_CONFIG.md` template when finalizing.

### 🎨 Visual Uniqueness Rules

1. **Connection Status Banner is the hero** — full-width band at top with color cue (green/grey/amber/red) and connection summary; never identical to body cards.
2. **Provider cards visually distinct from setting cards** — grid of 5 brand-icon cards (background hue per brand: QB green, Xero blue, Tally amber, Zoho violet, Custom slate), each with provider logo + name + status text + action button.
3. **Connection Details card** has monospace font for `ExternalRealmId` and uses key-value rows (left label icon + label, right value), not a form layout — it's read-only.
4. **Mapping tables** have arrow icons between columns visually emphasizing the directionality (PSS → Accounting) — this is a transformation, not a list.
5. **"Unmapped" rows** get amber border + amber arrow icon + "Unmapped" pill (not a destructive style — it's a warning, not an error).
6. **Sync Settings card** uses sync-icon header + a different accent (settings-accent purple `#6366f1` per mockup) to set it apart from the connection/credential cards.
7. **Sync Log card** has a clock-rotate icon and a "View Full Log" expand button — clearly an operational dashboard, not a config form.
8. **Failed Records card** has a red error-icon header + red pill badge with count — visually demands attention.

**Anti-patterns to refuse**:
- 8 identical card-chrome blocks with only the title swapped.
- Mapping tables rendered as a vanilla "edit / delete" CRUD list with no arrow / amber-warning treatment.
- Provider cards as a dropdown / radio list (the visual choice surface matters here).
- Single huge form with no section structure.

---

### 🅰️ Block A — SETTINGS_PAGE

#### Page Layout

**Container Pattern**: `vertical-stack` — 8 stacked cards, no tabs/sidebar/accordion (mockup has zero tab UI; mockup is a vertical scrollable page).

**Page Header**:
- Title: "Accounting Integration"
- Subtitle: "Connect and sync with your accounting software"
- Icon: `fa-link` / `ph:link-simple-horizontal` (settings-accent purple)
- Top-right actions: `Sync Now` (button — fires `triggerManualAccountingSync` SERVICE_PLACEHOLDER) + `View Sync Log` (navigate to `setting/integration/accountingsynclog` — out of scope but link present)

#### Section Definitions

> One row per section card. Order matches mockup top-to-bottom.

| # | Section Title | Icon (Phosphor) | Card Type | Save Mode | Role Gate |
|---|---------------|-----------------|-----------|-----------|-----------|
| 1 | Connection Status Banner | `ph:circle-wavy-check` | banner (full-width band) | — (display only) | BUSINESSADMIN |
| 2 | Accounting Provider | `ph:plugs` | card with provider grid | per-card Connect | BUSINESSADMIN |
| 3 | {Provider} Connection Details | `ph:link-break` | card (visible if IsConnected) | save-per-section + Refresh/Disconnect actions | BUSINESSADMIN |
| 4 | Account Mapping | `ph:arrows-left-right` | card with table | save-section (Save Mappings) + Auto-Map + Create Account | BUSINESSADMIN |
| 5 | Payment Mode Mapping | `ph:credit-card` | card with table | save-section (Save Mappings) | BUSINESSADMIN |
| 6 | Sync Settings | `ph:sliders` | card with stacked form rows | save-section (Save Settings) | BUSINESSADMIN |
| 7 | Recent Sync Log | `ph:clock-counter-clockwise` | card with read-only table | — (display + View Full Log link) | BUSINESSADMIN |
| 8 | Failed Records | `ph:warning-octagon` | card with table + per-row + bulk actions | (no section save; per-row Skip/Retry persists immediately) | BUSINESSADMIN |

#### Field Mapping per Section

**Section 1 — Connection Status Banner** (display-only band, no fields):

| Element | Source | When |
|---------|--------|------|
| Status icon + label | computed: `IsConnected=true` → green ✓ "Connected to {Provider}"; `false` → grey "Not connected" | always |
| Last sync chip | `LastSyncAt` formatted to local time (e.g. "Apr 12, 2026, 2:00 PM") | when IsConnected |
| Next auto-sync chip | `NextScheduledSyncAt` | when IsConnected AND AutoSyncEnabled |
| Sync Now button | fires `triggerManualAccountingSync` | when IsConnected |
| Sync History button | navigates to sync-log screen | always |

**Section 2 — Accounting Provider** (selector grid):

| Field | Widget | Default | Validation | Sensitivity | Notes |
|-------|--------|---------|------------|-------------|-------|
| Provider (UI: 5 cards) | provider-card-grid | 'None' | enum | normal | Each card: QB / Xero / Tally / Zoho / Custom; brand-styled; selected card shows "Connected" badge + Disconnect button OR "Connect"/"Configure" button. Clicking Connect → confirm-switch modal if currently connected to another provider → SERVICE_PLACEHOLDER `connectAccountingProvider` |

Section 2 Actions:

| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Connect | per-card "Connect" / "Configure" | primary | if switching provider, confirm modal | `connectAccountingProvider` (SERVICE_PLACEHOLDER) |
| Disconnect | per-card "Disconnect" (on connected card only) | destructive | modal "Disconnect {provider}? Mappings preserved." | `disconnectAccountingProvider` (real) |

**Section 3 — {Provider} Connection Details** (visible only when IsConnected; READ-ONLY content + actions):

| Field | Widget | Notes |
|-------|--------|-------|
| Company | text (read-only with icon) | from `ExternalCompanyName` |
| Connected Since | text (read-only) | from `ConnectedAt` |
| Connected By | text (read-only) | from `ConnectedByUserId` (lookup → user name; eager-load in composite query) |
| OAuth Status | computed chip | "Token valid (expires {date})" or "Token expired" or "Disconnected" |
| Realm/Tenant ID | monospace text | from `ExternalRealmId` |

Section 3 Actions:

| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Refresh Token | "Refresh Token" | secondary | none | `refreshAccountingProviderToken` (SERVICE_PLACEHOLDER) |
| Disconnect | "Disconnect" | destructive | modal | `disconnectAccountingProvider` |

**Section 4 — Account Mapping** (table with one row per Company DonationPurpose):

| Column | Widget | Notes |
|--------|--------|-------|
| Purpose | text (read-only) | DonationPurpose.donationPurposeName |
| → (arrow icon) | display | amber when row is unmapped |
| External Account | combobox (free-text + options) | V1: free text + last-used options from existing mappings across tenant + the seeded sample list per provider; V2: bound to `getExternalAccountChartFromProvider` (SERVICE_PLACEHOLDER) |
| Tax Code | combobox | V1: free text + seeded sample list; V2: provider tax codes |
| Actions | trash icon button | clears the row's mapping (sets ExternalAccountCode/Name/TaxCode/TaxName to NULL → row renders as "Unmapped") |

Section 4 Actions:

| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Auto-Map | "Auto-Map" | secondary | none | `autoMapAccountingAccounts` (SERVICE_PLACEHOLDER) |
| Create Account in QuickBooks | "Create Account in {Provider}" | secondary-accent | input modal (new account code/name) | `createExternalAccount` (SERVICE_PLACEHOLDER) |
| Save Mappings | "Save Mappings" | primary | none | `bulkUpsertAccountingAccountMappings` (real — sends diff of changed rows) |

**Section 5 — Payment Mode Mapping** (table — one row per Company PaymentMode):

| Column | Widget | Notes |
|--------|--------|-------|
| Payment Mode | text + mode icon (read-only) | PaymentMode.paymentModeName |
| → (arrow icon) | display | normal |
| Payment Method | combobox | maps to ExternalPaymentMethod |
| Bank / Deposit Account | combobox | maps to ExternalBankAccountCode/Name |

Section 5 Actions: same Save Mappings pattern as Section 4 (handler: `bulkUpsertAccountingPaymentModeMappings`).

**Section 6 — Sync Settings**:

| Field | Widget | Default | Validation | Sensitivity | Notes |
|-------|--------|---------|------------|-------------|-------|
| AutoSyncEnabled | switch (form-row) | false | — | normal | Label updates dynamically based on toggle state |
| SyncFrequencyHours | dropdown | 4 | required | normal | Options: 1/2/4/6/12/24 / Manual (=0) |
| SyncDirection | dropdown | 'PUSH' | required | normal | Options: PUSH (recommended) / PULL / BIDIRECTIONAL; helper text below |
| SyncEntitiesJson | checkbox group | `["Donations","Refunds"]` | at least 1 required | normal | 5 checkboxes: Donations / Refunds / Contacts / Pledges / Receipts |
| SyncStartDate | date | null | optional | normal | Helper "Only donations on or after this date will be synced" |

Section 6 Actions:

| Action | Label | Style | Confirmation | Handler |
|--------|-------|-------|--------------|---------|
| Save Settings | "Save Settings" | primary (settings-accent purple) | none | `updateAccountingSyncSettings` |

**Section 7 — Recent Sync Log** (read-only table, top 10):

| Column | Source | Notes |
|--------|--------|-------|
| Sync Time | `SyncStartedAt` | local time |
| Direction | `Direction` | "PSS → QB" / "QB → PSS" chip |
| Records | `TotalRecords` | center-aligned |
| Synced | `SyncedRecords` | green if >0 else grey |
| Failed | `FailedRecords` | red if >0 else grey |
| Duration | `DurationMs` formatted as "4.2s" | |
| Status | `Status` chip | success / warning (Partial) / danger (Error) |

Section 7 Actions: "View Full Log" link only (out-of-scope navigation).

**Section 8 — Failed Records** (table with badge count in header):

| Column | Source | Notes |
|--------|--------|-------|
| Record | `InternalRecordRef` + `InternalRecordDisplayName` | bold ref + sub-text |
| Type | `InternalRecordType` chip | blue (Donation) / amber (Refund) / etc. |
| Error | `ErrorMessage` | red text |
| Actions | row buttons | Skip / Retry / View in QB (deep-link composed client-side if ExternalRefId present) |

Section 8 Header Actions: `Skip All` + `Retry All` (visible when count > 0).

Section 8 Per-Row Actions: `Skip` (`skipAccountingFailedRecord` — real) / `Retry` (`retryAccountingFailedRecord` — SERVICE_PLACEHOLDER but DB transition real) / `View in QB` (composes external URL — SERVICE_PLACEHOLDER if Provider's deep-link URL format unknown for V1).

#### Page-Level Actions (header)

| Action | Position | Style | Permission | Confirmation |
|--------|----------|-------|------------|--------------|
| Sync Now | top-right | outline-accent | BUSINESSADMIN | none — fires SERVICE_PLACEHOLDER `triggerManualAccountingSync` |
| View Sync Log | top-right | outline-accent | BUSINESSADMIN | none — navigate |

#### User Interaction Flow (SETTINGS_PAGE)

1. User navigates to `/setting/integration/accountingintegration` → page mounts → fires `getAccountingIntegrationSettings` → BE auto-seeds default row if missing → returns root + mappings + sync logs + failed records.
2. Status banner renders based on IsConnected. If disconnected, only the provider grid + sync-settings card are actionable; mappings render as "Unmapped" rows; sync-log + failed-records cards show empty states.
3. User clicks Connect on QuickBooks card → confirm-switch modal if currently connected → SERVICE_PLACEHOLDER toast → BE mocks success → refetch → page renders Connection Details card + mappings activate.
4. User edits a row in Account Mapping → row becomes dirty → "Save Mappings" enables → click Save → diff PATCHes → toast "Saved" → row updates from refetch.
5. User edits Sync Settings → click Save Settings → PATCH → toast "Saved" → status banner refreshes Next Auto-Sync.
6. User clicks Sync Now → SERVICE_PLACEHOLDER toast → BE inserts a mock SyncLog row → Recent Sync Log card refreshes.
7. User clicks Skip on a failed record → real DB update → row removed → badge count decrements.
8. User clicks Retry → SERVICE_PLACEHOLDER toast → row Status changes to QueuedForRetry → row removed from display.
9. User clicks Disconnect on connected provider → confirm modal → real DB clear → page re-renders disconnected state; mappings remain in DB but render as "Unmapped" visually.

---

### 🅱️ Block B / 🅲 Block C — NOT APPLICABLE (delete from final prompt)

(DESIGNER_CANVAS / MATRIX_CONFIG blocks from `_CONFIG.md` template are not relevant — this is a SETTINGS_PAGE.)

---

### Shared blocks (apply)

#### Page Header & Breadcrumbs

| Element | Content |
|---------|---------|
| Breadcrumb | Setting › Integration › Accounting Integration |
| Page title | Accounting Integration |
| Subtitle | Connect and sync with your accounting software |
| Right actions | Sync Now (SERVICE_PLACEHOLDER) + View Sync Log (link) |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading | Initial fetch | Skeleton matching the 8-card vertical stack |
| Empty (Disconnected) | First load with default row | Banner shows "Not connected — pick a provider"; mapping cards collapsed/disabled with "Connect a provider to start mapping" hint |
| Empty (Sync Log) | No `AccountingSyncLogs` rows | "No sync runs yet" placeholder inside the card body |
| Empty (Failed Records) | No `Pending` rows | Card collapsed by default with "No failed records" placeholder; expands when count > 0 |
| Error | GET fails | Error card with retry button + error code |
| Save error | Save fails | Inline error per section + toast |

---

## ⑦ Substitution Guide

> Canonical for first SETTINGS_PAGE: **SMSSETUP** (#157 — same singleton + child-collections + save-per-section + SERVICE_PLACEHOLDER pattern; first canonical of SETTINGS_PAGE sub-type per `_CONFIG.md` §⑦ — when AccountingIntegration completes, BOTH can be referenced).
> Closest sibling structural reference: **SmsSetting** (#157) — vertically-stacked cards / per-card save / masked credentials / SERVICE_PLACEHOLDER on external service / read-only operational table inside settings page.

| Canonical (SmsSetting) | → This Entity (AccountingIntegration) | Context |
|-----------------------|----------------------------------------|---------|
| SmsSetting | AccountingIntegration | Entity / class name (singular) |
| smsSetting | accountingIntegration | Variable / field camelCase |
| sms-setting | accounting-integration | kebab-case (paths, GQL field names where applicable) |
| SMSSETTING (would-be MenuCode) | ACCOUNTINGINTEGRATION | MenuCode UPPER |
| notify | integ | DB schema (NEW for AccountingIntegration — first entity in `integ`) |
| NotifyModels | IntegrationModels | Domain folder |
| Notify | Integration | Backend group name (folders: `IntegrationBusiness/AccountingIntegrations/`, `IntegrationConfigurations`, `IntegrationSchemas`, `EndPoints/Integration`, `IntegrationMappings`) |
| INotifyDbContext | IIntegrationDbContext (NEW — first context for this schema; OR add DbSet directly to IApplicationDbContext per existing convention — confirm with Solution Resolver) |  |
| SmsSenderRegistration (child) | AccountingAccountMapping (child) | One of the two mapping child entities |
| SmsOptKeyword (child) | AccountingPaymentModeMapping (child) | Second mapping child |
| (no precedent) | AccountingSyncLog + AccountingFailedRecord | Read-only operational children — no direct SmsSetup analog (sibling pattern of WhatsApp delivery log if it exists) |
| SET_COMMUNICATIONCONFIG | SET_INTEGRATION | Parent menu code |
| setting/communicationconfig/smssetup | setting/integration/accountingintegration | FE URL |

> **First true SETTINGS_PAGE** of the codebase that also introduces a new schema + new group — the developer should treat the schema-creation steps with extra care (DbContext registration, decorator namespace, etc.). See ISSUE-3 in §⑫.

---

## ⑧ File Manifest

> SETTINGS_PAGE (singleton-per-tenant) + 4 child collections — heavier than the canonical 8-10 BE file count because of the child tables.

### Backend Files — NEW (~25)

| # | File | Path |
|---|------|------|
| 1 | Entity (root) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/IntegrationModels/AccountingIntegration.cs` |
| 2 | Entity (child 1) | `…/IntegrationModels/AccountingAccountMapping.cs` |
| 3 | Entity (child 2) | `…/IntegrationModels/AccountingPaymentModeMapping.cs` |
| 4 | Entity (child 3) | `…/IntegrationModels/AccountingSyncLog.cs` |
| 5 | Entity (child 4) | `…/IntegrationModels/AccountingFailedRecord.cs` |
| 6 | EF Config (root) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/IntegrationConfigurations/AccountingIntegrationConfiguration.cs` |
| 7 | EF Config (child 1) | `…/IntegrationConfigurations/AccountingAccountMappingConfiguration.cs` |
| 8 | EF Config (child 2) | `…/IntegrationConfigurations/AccountingPaymentModeMappingConfiguration.cs` |
| 9 | EF Config (child 3) | `…/IntegrationConfigurations/AccountingSyncLogConfiguration.cs` |
| 10 | EF Config (child 4) | `…/IntegrationConfigurations/AccountingFailedRecordConfiguration.cs` |
| 11 | Schemas (DTOs + validators) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/IntegrationSchemas/AccountingIntegrationSchemas.cs` |
| 12 | GetSettings composite query | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/IntegrationBusiness/AccountingIntegrations/GetSettingsQuery/GetAccountingIntegrationSettings.cs` |
| 13 | UpdateConnection command | `…/AccountingIntegrations/UpdateConnectionCommand/UpdateAccountingIntegrationConnection.cs` |
| 14 | UpdateSyncSettings command | `…/AccountingIntegrations/UpdateSyncSettingsCommand/UpdateAccountingSyncSettings.cs` |
| 15 | BulkUpsertAccountMappings command | `…/AccountingIntegrations/UpsertMappingsCommand/BulkUpsertAccountingAccountMappings.cs` |
| 16 | BulkUpsertPaymentModeMappings command | `…/AccountingIntegrations/UpsertMappingsCommand/BulkUpsertAccountingPaymentModeMappings.cs` |
| 17 | DeleteAccountMapping command | `…/AccountingIntegrations/DeleteMappingCommand/DeleteAccountingAccountMapping.cs` |
| 18 | DisconnectProvider command | `…/AccountingIntegrations/DisconnectCommand/DisconnectAccountingProvider.cs` (REAL — clears credentials atomically) |
| 19 | ConnectProvider command | `…/AccountingIntegrations/ConnectCommand/ConnectAccountingProvider.cs` (SERVICE_PLACEHOLDER) |
| 20 | RefreshToken command | `…/AccountingIntegrations/RefreshTokenCommand/RefreshAccountingProviderToken.cs` (SERVICE_PLACEHOLDER) |
| 21 | AutoMapAccounts command | `…/AccountingIntegrations/AutoMapCommand/AutoMapAccountingAccounts.cs` (SERVICE_PLACEHOLDER) |
| 22 | CreateExternalAccount command | `…/AccountingIntegrations/CreateAccountCommand/CreateExternalAccount.cs` (SERVICE_PLACEHOLDER) |
| 23 | TriggerManualSync command | `…/AccountingIntegrations/SyncCommand/TriggerManualAccountingSync.cs` (SERVICE_PLACEHOLDER — inserts mock SyncLog row) |
| 24 | SkipFailedRecord command + bulk | `…/AccountingIntegrations/FailedRecordCommand/SkipAccountingFailedRecord.cs` + `BulkSkipFailedRecords.cs` (REAL) |
| 25 | RetryFailedRecord command + bulk | `…/AccountingIntegrations/FailedRecordCommand/RetryAccountingFailedRecord.cs` + `BulkRetryFailedRecords.cs` (DB transition REAL, sync REAL is SERVICE_PLACEHOLDER) |
| 26 | Default Seeder | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Seeders/AccountingIntegrationDefaultSeeder.cs` (registers default row on first GET) |
| 27 | Mutations endpoint | `Pss2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Integration/Mutations/AccountingIntegrationMutations.cs` |
| 28 | Queries endpoint | `Pss2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Integration/Queries/AccountingIntegrationQueries.cs` |

### Backend Files — MODIFY (~5) + EF migration + DB seed

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Pss2.0_Backend/.../Base.Application/Common/Interfaces/IApplicationDbContext.cs` | DbSet<AccountingIntegration> + DbSet<AccountingAccountMapping> + DbSet<AccountingPaymentModeMapping> + DbSet<AccountingSyncLog> + DbSet<AccountingFailedRecord> properties |
| 2 | `Pss2.0_Backend/.../Base.Infrastructure/Data/ApplicationDbContext.cs` | DbSet<…> properties + register configurations |
| 3 | `Pss2.0_Backend/.../Base.Application/Common/Authorize/DecoratorProperties.cs` | `DecoratorIntegrationModules.AccountingIntegration = "AccountingIntegration"` entry (new module class) |
| 4 | `Pss2.0_Backend/.../Base.Application/Mappings/IntegrationMappings.cs` (NEW or appended if exists) | Mapster mapping config for all 5 entities ↔ DTOs (strip sensitive fields on read) |
| 5 | `Pss2.0_Backend/.../Base.Infrastructure/Seeders/DependencyInjection.cs` (or equivalent) | Register `AccountingIntegrationDefaultSeeder` |
| 6 (EF) | `Pss2.0_Backend/.../Base.Infrastructure/Data/Migrations/{timestamp}_Add_AccountingIntegration_And_Children.cs` | NEW hand-crafted EF migration: CREATE SCHEMA `integ` IF NOT EXISTS; CREATE 5 tables with indexes + filtered unique constraints; Up/Down idempotent |
| 7 (Seed) | `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/accountingintegration-sqlscripts.sql` | NEW 9-section idempotent seed: Menu ACCOUNTINGINTEGRATION under SET_INTEGRATION OrderBy=1 + 6 Capabilities (READ/MODIFY/DELETE/MAPPING_SAVE/SYNC_TRIGGER/ISMENURENDER) + BUSINESSADMIN role grants + Grid ACCOUNTINGINTEGRATION GridType=CONFIG (GridFormSchema NULL) + default `AccountingIntegrations` row per existing tenant + 1 sample `AccountingSyncLog` + 0 sample failed records (to confirm empty-state UI) |

### Frontend Files — NEW (~17)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/integration-service/AccountingIntegrationDto.ts` (NEW service folder — first entity) |
| 2 | GQL Query barrel | `Pss2.0_Frontend/src/infrastructure/gql-queries/integration-queries/AccountingIntegrationQuery.ts` (NEW folder — first entity) |
| 3 | GQL Mutation barrel | `Pss2.0_Frontend/src/infrastructure/gql-mutations/integration-mutations/AccountingIntegrationMutation.ts` |
| 4 | Settings Page (composer) | `Pss2.0_Frontend/src/presentation/components/page-components/setting/integration/accountingintegration/accounting-integration-page.tsx` |
| 5 | Connection Status Banner | `…/accountingintegration/components/connection-status-banner.tsx` |
| 6 | Provider Card Grid | `…/accountingintegration/components/provider-card-grid.tsx` |
| 7 | Provider Card (single) | `…/accountingintegration/components/provider-card.tsx` |
| 8 | Connection Details Card | `…/accountingintegration/components/connection-details-card.tsx` |
| 9 | Account Mapping Table | `…/accountingintegration/components/account-mapping-table.tsx` |
| 10 | Payment Mode Mapping Table | `…/accountingintegration/components/payment-mode-mapping-table.tsx` |
| 11 | Sync Settings Card | `…/accountingintegration/components/sync-settings-card.tsx` |
| 12 | Recent Sync Log Card | `…/accountingintegration/components/recent-sync-log-card.tsx` |
| 13 | Failed Records Card | `…/accountingintegration/components/failed-records-card.tsx` |
| 14 | Switch Provider Confirm Modal | `…/accountingintegration/components/switch-provider-modal.tsx` |
| 15 | Create External Account Modal | `…/accountingintegration/components/create-external-account-modal.tsx` |
| 16 | Zustand Store | `…/accountingintegration/accounting-integration-store.ts` (page-level state: dirty section tracker, provider-switch modal state, mapping local-edits buffer) |
| 17 | Page Config | `Pss2.0_Frontend/src/presentation/pages/setting/integration/accountingintegration.tsx` |

### Frontend Files — MODIFY (5 wiring)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Pss2.0_Frontend/src/app/[lang]/setting/integration/accountingintegration/page.tsx` | REPLACE UnderConstruction stub with `<AccountingIntegrationPage />` import + `'use client'` |
| 2 | `Pss2.0_Frontend/src/presentation/operations/entity-operations.ts` (or equivalent registry) | Add `ACCOUNTINGINTEGRATION` operations config entry |
| 3 | `Pss2.0_Frontend/src/presentation/operations/operations-config.ts` | Import + register the new operations |
| 4 | `Pss2.0_Frontend/src/infrastructure/gql-queries/index.ts` (barrel) | Re-export `AccountingIntegrationQuery` |
| 5 | `Pss2.0_Frontend/src/infrastructure/gql-mutations/index.ts` (barrel) | Re-export `AccountingIntegrationMutation` |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: Accounting Integration
MenuCode: ACCOUNTINGINTEGRATION
ParentMenu: SET_INTEGRATION
Module: SETTING
MenuUrl: setting/integration/accountingintegration
GridType: CONFIG

MenuCapabilities: READ, MODIFY, DELETE, MAPPING_SAVE, SYNC_TRIGGER, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY, DELETE, MAPPING_SAVE, SYNC_TRIGGER

GridFormSchema: SKIP
GridCode: ACCOUNTINGINTEGRATION
---CONFIG-END---
```

> Notes on capabilities:
> - `READ` — view all sections (including read-only sync log / failed records)
> - `MODIFY` — edit credentials, sync settings, mappings
> - `DELETE` — clear a mapping row (per-row trash icon)
> - `MAPPING_SAVE` — explicit grant for bulk mapping upsert (so future role designs can separate "view mappings" from "change mappings")
> - `SYNC_TRIGGER` — fire Sync Now / Retry actions (separable from MODIFY to support a future "view-only auditor" role)
> - `GridFormSchema: SKIP` — custom UI, not RJSF

---

## ⑩ Expected BE→FE Contract

**GraphQL Types:**
- Query type: `AccountingIntegrationQueries`
- Mutation type: `AccountingIntegrationMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getAccountingIntegrationSettings` | `AccountingIntegrationSettingsDto` (composite: root + mappings list + last 10 sync logs + all pending failed records) | — (tenant from HttpContext) |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `updateAccountingIntegrationConnection` | `AccountingConnectionUpdateRequestDto` (Provider + credentials + custom-api fields) | `AccountingIntegrationSettingsDto` |
| `updateAccountingSyncSettings` | `AccountingSyncSettingsRequestDto` (AutoSyncEnabled + frequency + direction + entities + start date) | `AccountingIntegrationSettingsDto` |
| `bulkUpsertAccountingAccountMappings` | `[AccountingAccountMappingUpsertDto]` (id?, DonationPurposeId, ExternalAccountCode/Name, ExternalTaxCode/Name) | `[AccountingAccountMappingResponseDto]` (refreshed list) |
| `bulkUpsertAccountingPaymentModeMappings` | `[AccountingPaymentModeMappingUpsertDto]` (id?, PaymentModeId, ExternalPaymentMethod, ExternalBankAccountCode/Name) | `[AccountingPaymentModeMappingResponseDto]` |
| `deleteAccountingAccountMapping` | `accountingAccountMappingId: int` | `int` (affected count) |
| `disconnectAccountingProvider` | — | `AccountingIntegrationSettingsDto` |
| `connectAccountingProvider` (SERVICE_PLACEHOLDER) | `provider: string, customApiConfig?: object` | `AccountingIntegrationSettingsDto` |
| `refreshAccountingProviderToken` (SERVICE_PLACEHOLDER) | — | `AccountingIntegrationSettingsDto` |
| `autoMapAccountingAccounts` (SERVICE_PLACEHOLDER) | — | `[AccountingAccountMappingResponseDto]` |
| `createExternalAccount` (SERVICE_PLACEHOLDER) | `CreateExternalAccountRequestDto` (code, name, parentAccount?) | `ExternalAccountDto` (mock) |
| `triggerManualAccountingSync` (SERVICE_PLACEHOLDER) | — | `AccountingSyncLogDto` (the new mock log row) |
| `skipAccountingFailedRecord` | `accountingFailedRecordId: int` | `int` |
| `retryAccountingFailedRecord` (PARTIAL SERVICE_PLACEHOLDER) | `accountingFailedRecordId: int` | `int` |
| `bulkSkipAccountingFailedRecords` | `[int]` (record ids) | `int` (affected count) |
| `bulkRetryAccountingFailedRecords` (PARTIAL SERVICE_PLACEHOLDER) | `[int]` | `int` |

**`AccountingIntegrationSettingsDto` (composite) — sensitive-field handling:**

| Field | GET behavior | POST behavior |
|-------|--------------|---------------|
| accessToken | OMITTED from response (never serialized) | empty string ⇒ unchanged; non-empty ⇒ overwrite (via `updateAccountingIntegrationConnection`) |
| refreshToken | OMITTED | same |
| clientSecret | OMITTED | same |
| customApiKey | OMITTED | same |
| customApiSecret | OMITTED | same |
| isCredentialSet (computed bool) | `true` when DB has a non-null AccessToken or CustomApiKey | — (read-only) |
| accessTokenExpiresAt | included (drives "Token valid (expires ...)" badge) | — |
| externalRealmId | included | normal |

**DTO shape (illustrative — finalize in Schemas.cs):**

```
AccountingIntegrationSettingsDto {
  // Connection
  accountingIntegrationId: int
  provider: 'QuickBooksOnline' | 'Xero' | 'Tally' | 'ZohoBooks' | 'CustomApi' | 'None'
  isConnected: bool
  connectionStatus: 'Active' | 'TokenExpired' | 'Disconnected' | 'Error'
  externalCompanyName: string?
  externalRealmId: string?
  isCredentialSet: bool (computed; NEVER the raw token)
  accessTokenExpiresAt: DateTime?
  connectedAt: DateTime?
  connectedByUserName: string?
  // Custom API (only when Provider='CustomApi')
  customApiBaseUrl: string?
  customApiAuthType: string?
  // Sync settings
  autoSyncEnabled: bool
  syncFrequencyHours: int
  syncDirection: 'PUSH' | 'PULL' | 'BIDIRECTIONAL'
  syncEntitiesJson: string  // JSON-array string OR parsed in DTO: syncEntities: ['Donations',…]
  syncStartDate: DateTime?
  lastSyncAt: DateTime?
  nextScheduledSyncAt: DateTime?
  // Mappings
  accountMappings: [AccountingAccountMappingResponseDto]
  paymentModeMappings: [AccountingPaymentModeMappingResponseDto]
  // Operational
  recentSyncLogs: [AccountingSyncLogDto]  // last 10 desc
  failedRecords: [AccountingFailedRecordDto]  // Status='Pending' only
  failedRecordsCount: int
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (all 5 BE projects compile clean)
- [ ] EF migration `Add_AccountingIntegration_And_Children` applies to dev DB (creates `integ` schema; 5 tables present)
- [ ] `pnpm dev` — page loads at `/{lang}/setting/integration/accountingintegration` with no console errors

**Functional Verification (SETTINGS_PAGE — Full E2E):**

- [ ] First-load auto-seeds default config row for current tenant (no 404 / null state)
- [ ] All 8 cards render in correct order with correct grouping & icons & accents
- [ ] Status banner reflects connection state correctly (disconnected vs connected with last-sync/next-sync info)
- [ ] 5 provider cards render with correct brand styling; selected provider shows "Connected" badge + Disconnect; others show Connect (or Configure for Custom)
- [ ] Click Connect on disconnected provider → SERVICE_PLACEHOLDER toast → BE mocks success → page refetches → Connection Details card appears + mappings activate
- [ ] Click Connect on different provider while connected → confirm-switch modal → on confirm → previous credentials cleared, new provider set to "pending connected"
- [ ] Connection Details card renders correctly with monospace `externalRealmId`, computed OAuth Status chip, and Refresh/Disconnect actions
- [ ] Account Mapping table renders one row per Company DonationPurpose; comboboxes accept manual entry; trash icon clears mapping (row visually becomes Unmapped)
- [ ] Payment Mode Mapping table renders one row per Company PaymentMode
- [ ] Save Mappings sends ONLY changed rows (diff payload), not the full list
- [ ] Unmapped rows show amber border + "Unmapped" pill + amber arrow icon
- [ ] Auto-Map button fires SERVICE_PLACEHOLDER toast; Create Account modal opens + accepts input + fires SERVICE_PLACEHOLDER on save
- [ ] Sync Settings card: each form-row persists; Save Settings button respects role gate (BUSINESSADMIN only)
- [ ] SyncFrequencyHours dropdown disables when AutoSyncEnabled=false
- [ ] SyncEntitiesJson checkbox group: at least 1 required; persists as JSON array
- [ ] SyncStartDate optional; helper text visible
- [ ] Recent Sync Log table renders last 10 rows from `AccountingSyncLogs` desc; status chip color matches Status (success/warning/danger); duration formatted "4.2s"
- [ ] "View Full Log" link navigates to placeholder route (out of scope) — link exists and is clickable
- [ ] Failed Records card shows count badge in header; "Skip All" + "Retry All" buttons visible when count > 0
- [ ] Per-row Skip → real DB update (Status='Skipped') → row disappears immediately
- [ ] Per-row Retry → SERVICE_PLACEHOLDER toast → row Status='QueuedForRetry' → row disappears (UI only shows Pending)
- [ ] Per-row View in QB → opens new tab to composed external URL (if ExternalRefId present; otherwise SERVICE_PLACEHOLDER toast)
- [ ] Sensitive fields (`accessToken` / `refreshToken` / `clientSecret` / `customApiKey` / `customApiSecret`) NEVER appear in GET response payload (verify in browser network tab)
- [ ] Empty submit on sensitive fields ⇒ unchanged on save; non-empty ⇒ overwrites
- [ ] Disconnect → confirm modal → on confirm → DB clears credentials, IsConnected=false; page re-renders disconnected state but mappings preserved
- [ ] Unsaved-changes blocker on dirty navigation (per dirty card)
- [ ] Role-gated for BUSINESSADMIN; non-privileged roles → DefaultAccessDenied
- [ ] Audit log entries written for Provider switch / OAuth rotation / Disconnect / Bulk skip / Bulk retry (verify in `Audit.AuditLogs` table if it exists, OR confirm via log file/console)

**DB Seed Verification:**
- [ ] Menu visible at Settings › Integration › Accounting Integration (sidebar)
- [ ] Default `AccountingIntegrations` row seeded for sample tenant (Provider='None', AutoSyncEnabled=false)
- [ ] 1-2 sample `AccountingSyncLog` rows visible in Recent Sync Log card (idempotent seed)
- [ ] BUSINESSADMIN can access; other roles cannot

---

## ⑫ Special Notes & Warnings

**Universal CONFIG warnings:**

- **CompanyId is NOT a form field** — tenant-scoped via HttpContext (`ITenantContext.GetRequiredTenantId()`).
- **Singleton has NO Create/Delete on root** — `GetAccountingIntegrationSettings` auto-seeds, `Update*` mutations are the only changes. Child mapping tables DO support upsert + per-row delete (via diff or explicit delete command).
- **GridFormSchema = SKIP** — custom UI, not RJSF.
- **No view-page 3-mode pattern** — single page.
- **Sensitive fields**: NEVER serialize raw `AccessToken` / `RefreshToken` / `ClientSecret` / `CustomApiKey` / `CustomApiSecret` in GET responses. Use a projection DTO that omits these fields entirely (do NOT mask with `'••••••••'` — security best practice is omission, see SmsSetup #157 pattern). Audit every change.
- **Dangerous actions** (Disconnect / Switch provider / Skip All / Retry All): require confirm + audit log.
- **Role gating happens at the BE** — FE hiding fields is UX only. Never trust the FE for permission enforcement.
- **Default seeding**: singleton MUST auto-seed default row so first-load doesn't 404 or show null state.

**Module / module-instance notes:**

- **This is the FIRST entity in the `integ` schema and `IntegrationModels` group** — the developer MUST:
  1. Create folder structure: `Base.Domain/Models/IntegrationModels/`, `Base.Infrastructure/Data/Configurations/IntegrationConfigurations/`, `Base.Application/Schemas/IntegrationSchemas/`, `Base.Application/Business/IntegrationBusiness/`, `Base.API/EndPoints/Integration/{Mutations,Queries}/`, `Base.Application/Mappings/IntegrationMappings.cs`
  2. Add `DecoratorIntegrationModules` class to `DecoratorProperties.cs` (mirror `DecoratorNotifyModules`)
  3. Decide on DbContext: either reuse existing `IApplicationDbContext` (simpler — add DbSets directly) OR create `IIntegrationDbContext` interface (cleaner separation but more wiring). Recommendation: reuse `IApplicationDbContext` — see SmsSetting which uses NotifyDbContext but the entity is registered on the shared DbContext too.
  4. EF migration must include `CREATE SCHEMA IF NOT EXISTS integ;` as the first statement.
- **Parent menu `SET_INTEGRATION` already exists** in `MODULE_MENU_REFERENCE.md` (MenuId 378) — no new parent menu needed; just register the child menu in the seed.
- **FE `setting/integration/accountingintegration/page.tsx` already exists** as UnderConstruction stub — REPLACE its content, do not create a sibling file.
- **FK queries `getDonationPurposes` and `getPaymentModes` are paginated** — FE must call with `pageSize=999` (or whatever max is) to fetch the full list for the mapping tables. Not ideal — see ISSUE-1 below.

**Service Dependencies** (UI fully built, handler is a mock):

> Everything in the mockup is in scope. The following SERVICE_PLACEHOLDERs are the ONLY items mocked because the corresponding external SDK / service does not exist in the codebase yet:

1. ⚠ **SERVICE_PLACEHOLDER: `connectAccountingProvider`** — OAuth flow for QuickBooks/Xero/Zoho/Tally is not implemented (no Intuit / Xero / Zoho SDK in the codebase). Handler accepts Provider + Custom API config, returns mocked success (sets `IsConnected=true`, generates fake `AccessToken` + `RefreshToken` + `AccessTokenExpiresAt = +90 days`, sets `ExternalCompanyName='[Mocked] {tenant name}'`, `ExternalRealmId=Guid.NewGuid().ToString()`). Toast notifies user the integration is mocked.
2. ⚠ **SERVICE_PLACEHOLDER: `refreshAccountingProviderToken`** — same reason. Mock extends `AccessTokenExpiresAt` by 90 days.
3. ⚠ **SERVICE_PLACEHOLDER: `autoMapAccountingAccounts`** — depends on `GetExternalAccountChartFromProvider` (which depends on provider SDK). Returns existing mappings unchanged + informative toast.
4. ⚠ **SERVICE_PLACEHOLDER: `createExternalAccount`** — depends on provider POST endpoint. Returns mock account ref.
5. ⚠ **SERVICE_PLACEHOLDER: `triggerManualAccountingSync`** — depends on a sync worker that doesn't exist. Mock implementation inserts a real `AccountingSyncLog` row with synthetic counts (e.g. Status='Complete', TotalRecords=N donations since LastSyncAt, SyncedRecords=N-2, FailedRecords=2, Duration=~3000ms) AND inserts 2 sample `AccountingFailedRecord` rows so the Failed Records card has data to render in E2E QA.
6. ⚠ **SERVICE_PLACEHOLDER: `retryAccountingFailedRecord` / `bulkRetryAccountingFailedRecords`** — DB transition `Pending → QueuedForRetry` IS REAL. The provider re-POST is the mocked part. Toast notifies user.
7. ⚠ **SERVICE_PLACEHOLDER: "View in QB" deep-link composition** — V1: only attempts a URL composition when `ExternalRefId` is present AND Provider is one of the supported brands with a known URL pattern. Otherwise toast "Provider link unavailable for V1".
8. ⚠ **SERVICE_PLACEHOLDER: External Account / Tax Code combobox options** — V1 dropdowns are free-text comboboxes with options sourced from (a) existing-mappings-in-this-tenant dedupe + (b) a hard-coded "common GL accounts" sample list per provider. V2: live fetch from provider chart-of-accounts (depends on Item 1).

All UI is built (cards, tables, modals, buttons, validation, dirty-state, audit log entries, empty/loading/error states). Only the **external API calls** above are mocked.

**Sub-type-specific gotchas:**

- Don't slip into a generic "Connection / Mapping / Sync" tab split — the mockup is intentionally a vertical-stack page where every section is visible at once.
- Don't render Disconnect button with primary styling — it's destructive.
- Don't make mapping tables RJSF modals — they're inline-edit tables.
- Don't omit the Unmapped warning UX — it's the screen's compliance hook.
- Don't reuse a generic "settings card" chrome for the Connection Status Banner (it's a banner band, not a card) or for the Provider Card Grid (it's a card grid, not a single card).

---

### § Known Issues (pre-flagged in §⑫ during planning)

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| ISSUE-1 | MED | BE / FK contract | `getDonationPurposes` + `getPaymentModes` are paginated only — no `GetAll{Entity}List` non-paginated variant exists. FE must call with `pageSize=999` to fetch all rows for the mapping tables. Cleaner long-term: add `GetAllDonationPurposeList` + `GetAllPaymentModeList` query handlers (small handler + endpoint addition) — out of scope for this build but recommended as a follow-up. | OPEN |
| ISSUE-2 | LOW | BE / schema | New schema `integ` — must include `CREATE SCHEMA IF NOT EXISTS integ;` as first statement in the EF migration. EF Core does not auto-create schemas in `migrationBuilder.EnsureSchema(...)` — use that helper. | CLOSED (Session 1 — EnsureSchema integ at top of Up()) |
| ISSUE-3 | MED | BE / module setup | First entity in `IntegrationModels` group requires creating folder structure across 7 namespaces (Domain / Infrastructure config / Application schema / Application business / API endpoints / Mappings / Decorator). Developer should pattern-match SmsSetup #157's NotifyModels layout. | CLOSED (Session 1 — all 7 namespaces seeded; mirrored NotifyModels) |
| ISSUE-4 | MED | FE / sensitive contract | DTO MUST omit `accessToken` / `refreshToken` / `clientSecret` / `customApiKey` / `customApiSecret` from response — not mask. Add a `isCredentialSet: bool` computed field instead, so the UI can show "Credentials set ✓" or "Credentials missing" without leaking the secret. | CLOSED (Session 1 — fields absent from response DTO; isCredentialSet computed server-side) |
| ISSUE-5 | LOW | FE / store | Zustand store should hold the mapping-rows local-edit buffer separately from server state — saves should diff against original (initially-loaded) snapshot, not against current state. Pattern: store both `originalMappings` and `currentMappings`, send diff on save. | CLOSED (Session 1 — Zustand store has originalAccountMappings + currentAccountMappings + getMappingDiff() per-row deep-equal) |
| ISSUE-6 | MED | BE / atomicity | Provider switch operation (Disconnect current + Connect new) must be atomic — single transaction. If `connectAccountingProvider` fails after `disconnectAccountingProvider` succeeds, user is left in a worse state than before. Implement as a single transactional `SwitchProviderCommand` OR client-side compensating action. | CLOSED (Session 1 — ConnectAccountingProvider handles atomic clear-then-set inside single SaveChangesAsync transaction) |
| ISSUE-7 | LOW | UI | "Create Account in QuickBooks" button label is provider-specific in the mockup — generalize to "Create Account in {Provider}" so the same button works for Xero/Zoho/Tally. SERVICE_PLACEHOLDER handler returns mock regardless. | CLOSED (Session 1 — button label interpolates provider name; handleViewInProvider builds QB/Xero deep-link conditionally) |
| ISSUE-8 | LOW | UI | Sync Direction='BIDIRECTIONAL' is risky — should show a warning helper text below the dropdown when selected ("Bidirectional can overwrite PSS donations with stale accounting data") and a confirm modal on Save Settings. | CLOSED (Session 1 — sync-settings-card.tsx renders amber warning + AlertDialog confirm before save when BIDIRECTIONAL) |
| ISSUE-9 | LOW | BE / seed | Seed inserts 1-2 sample `AccountingSyncLog` rows — should be marked clearly as samples (e.g. ErrorSummary='[Seeded sample for E2E QA]') so they're recognizable in tenant data. | CLOSED (Session 1 — sample SyncLog rows tagged in seed script) |
| ISSUE-10 | INFO | UX | The mockup shows a "Sync History" button that navigates to `settings/sync-log` (a separate full sync log screen). That separate screen is NOT in this prompt's scope — it'll be a future REPORT (TABULAR) screen. This screen's "View Full Log" link is a placeholder navigation. Add the future-screen registry entry as a follow-up. | OPEN (future REPORT screen) |
| ISSUE-11 | MED | FE | The mockup shows a static example for QuickBooks ("Global Humanitarian Foundation") in the Connection Details card. The seeded default row should NOT pre-populate these — the card should be hidden until first Connect. Verify the conditional render is on `isConnected`, not on field presence. | CLOSED (Session 1 — ConnectionDetailsCard guarded by `settings?.isConnected === true`) |
| ISSUE-12 | LOW | BE / migration | `integ.AccountingFailedRecords.InternalRecordId` is a soft-FK (no FK constraint to the donation/refund/pledge table) — it's polymorphic across record types. This is intentional but DBAs may flag it; document the design choice in the EF migration's `Up()` comment. | CLOSED (Session 1 — comment added in migration Up()) |
| ISSUE-13 | LOW | BE / migration | Hand-crafted EF migration `20260519120000_Add_AccountingIntegration_And_Children.cs` — Designer.cs and ApplicationDbContextModelSnapshot.cs NOT regenerated by this build (per #169/#172 precedent). User must run `dotnet ef migrations add Add_AccountingIntegration_And_Children` to regen Designer/Snapshot, OR run `dotnet ef database update` directly to apply without regen. | OPEN |
| ISSUE-14 | LOW | BE / pre-existing | 2 pre-existing build errors in unrelated screens (`SocialMediaMutations.cs` line 157 — `DeleteSuccess` overload; `IntegrationMarketplaceMutations.cs` line 26 — `bool` reference type constraint). Surfaced by this build but NOT introduced by AccountingIntegration files. Out of scope for this screen — tracked here for visibility. | OPEN (pre-existing — not this screen) |
| ISSUE-15 | INFO | FE / naming | FK GQL field names use plural-noun convention (`donationPurposes`, `paymentModes`) — prompt §③ wrote `getDonationPurposes`/`getPaymentModes` which is the C# handler method name; HotChocolate strips the `Get` prefix and exposes the plural noun. FE agent correctly used the plural noun form. Update prompt §③ next planning cycle. | CLOSED (Session 1 — FE used correct naming) |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

(See § Known Issues above — 12 OPEN as of planning. Updated during build sessions.)

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-19 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. FULL (BE + FE + Seed) in one session. Sonnet across both BE and FE Developer agents per user preference.
- **Files touched**:
  - BE: 28 NEW + 5 MODIFY + 1 EF migration + 1 DB seed:
    - Entities (5): `Base.Domain/Models/IntegrationModels/{AccountingIntegration,AccountingAccountMapping,AccountingPaymentModeMapping,AccountingSyncLog,AccountingFailedRecord}.cs` (created — NEW folder)
    - EF Configs (5): `Base.Infrastructure/Data/Configurations/IntegrationConfigurations/{...}Configuration.cs` (created — NEW folder)
    - Schemas: `Base.Application/Schemas/IntegrationSchemas/AccountingIntegrationSchemas.cs` (created — NEW folder; composite DTO omits 5 sensitive fields per ISSUE-4)
    - Composite query: `…/AccountingIntegrations/GetSettingsQuery/GetAccountingIntegrationSettings.cs` (created — auto-seeds default row)
    - Mutation commands (15 across 9 subfolders): UpdateConnection / UpdateSyncSettings / BulkUpsertAccountMappings / BulkUpsertPaymentModeMappings / DeleteAccountMapping / DisconnectProvider (REAL) / ConnectProvider (SERVICE_PLACEHOLDER) / RefreshToken (SP) / AutoMap (SP) / CreateExternalAccount (SP) / TriggerManualSync (SP — inserts real SyncLog + 2 FailedRecord rows) / SkipFailedRecord+Bulk (REAL) / RetryFailedRecord+Bulk (PARTIAL — DB transition REAL)
    - Default seeder: `Base.Infrastructure/Seeders/AccountingIntegrationDefaultSeeder.cs` (created)
    - Endpoints (2): `Base.API/EndPoints/Integration/{Mutations,Queries}/AccountingIntegration{Mutations,Queries}.cs` (created — NEW folder)
    - Mappings: `Base.Application/Mappings/IntegrationMappings.cs` (created — Mapster `.Ignore()` for 5 sensitive fields per ISSUE-4)
    - EF Migration: `Base.Infrastructure/Data/Migrations/20260519120000_Add_AccountingIntegration_And_Children.cs` (created — hand-crafted per ISSUE-13; EnsureSchema integ + 5 CreateTable + filtered unique indexes + polymorphic InternalRecordId comment per ISSUE-12)
    - DB seed: `sql-scripts-dyanmic/accountingintegration-sqlscripts.sql` (created — 9 idempotent sections: Menu + 6 Capabilities + BUSINESSADMIN grants + Grid + default per-tenant row + sample SyncLogs tagged per ISSUE-9 + defensive capability inserts)
    - Modified: IApplicationDbContext.cs (5 DbSets) / ApplicationDbContext.cs (DbSets + config registrations) / DecoratorProperties.cs (DecoratorIntegrationModules) / Seeders DI registration / Mappings DI registration
  - FE: 17 NEW + 8 MODIFY:
    - DTOs (2): `domain/entities/integration-service/AccountingIntegrationDto.ts` + `index.ts` (created — NEW folder)
    - GQL Queries (2): `infrastructure/gql-queries/integration-queries/{AccountingIntegrationQuery,index}.ts` (created — NEW folder)
    - GQL Mutations (2): `infrastructure/gql-mutations/integration-mutations/{AccountingIntegrationMutation,index}.ts` (created — NEW folder)
    - Components (12 under `presentation/components/page-components/setting/integration/accountingintegration/`): accounting-integration-page.tsx (composer with `<ScreenHeader>` + 8 cards) + accounting-integration-store.ts (Zustand: original/current mapping snapshots + getMappingDiff per ISSUE-5 + 4 modal states) + components/{connection-status-banner, provider-card-grid, provider-card, connection-details-card (isConnected-gated per ISSUE-11), account-mapping-table (diff-save), payment-mode-mapping-table, sync-settings-card (BIDIRECTIONAL warning + AlertDialog per ISSUE-8), recent-sync-log-card, failed-records-card (Skip real + Retry partial + handleViewInProvider per ISSUE-7), switch-provider-modal, create-external-account-modal}.tsx
    - Page config: `presentation/pages/setting/integration/accountingintegration.tsx` (created)
    - Entity ops: `application/configs/data-table-configs/integration-service-entity-operations.ts` (created — ACCOUNTINGINTEGRATION grid code)
    - Modified: `app/[lang]/setting/integration/accountingintegration/page.tsx` (UnderConstruction → AccountingIntegrationPageConfig) / `gql-queries/index.ts` + `gql-mutations/index.ts` (barrel re-exports) / `domain/entities/index.ts` (integration-service re-export) / `presentation/pages/setting/index.ts` + `setting/integration/index.ts` (page-config re-exports) / `application/configs/data-table-configs/index.ts` (entity-ops spread)
  - DB: `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/accountingintegration-sqlscripts.sql` (created)
- **Deviations from spec**: None material. FK GQL field naming clarification: prompt §③ wrote `getDonationPurposes`/`getPaymentModes` (C# method names); FE agent correctly used the HotChocolate-stripped plural-noun form `donationPurposes`/`paymentModes` per project naming convention. Logged as ISSUE-15 (CLOSED). FE wiring touched 8 files instead of the prompt-§⑧ predicted 5 — additional 3 are barrel-index re-exports for the new `integration-service` domain folder + new `integration` pages sub-folder (clean addition, not a deviation).
- **Known issues opened**: ISSUE-13 (hand-crafted migration — user must regen Designer/Snapshot or apply directly), ISSUE-14 (2 pre-existing build errors in SocialMediaMutations/IntegrationMarketplaceMutations — out of scope for #88), ISSUE-15 (FK GQL naming clarification — CLOSED same-session, doc-only).
- **Known issues closed**: ISSUE-2 (EnsureSchema integ), ISSUE-3 (7-namespace folder structure created), ISSUE-4 (sensitive fields omitted from response DTO + isCredentialSet computed), ISSUE-5 (Zustand snapshot + diff-save), ISSUE-6 (atomic provider switch single SaveChangesAsync), ISSUE-7 (provider-aware View-in-QB deep-link + conditional toast), ISSUE-8 (BIDIRECTIONAL amber warning + AlertDialog confirm), ISSUE-9 (sample SyncLog rows tagged `[Seeded sample for E2E QA]`), ISSUE-11 (Connection Details card guarded by isConnected, not field-presence), ISSUE-12 (polymorphic InternalRecordId comment in migration Up()).
- **Build verification**:
  - `dotnet build` (Pss2.0_Backend): PASS for AccountingIntegration files. 2 remaining errors confirmed pre-existing in unrelated files (SocialMediaMutations.cs line 157 / IntegrationMarketplaceMutations.cs line 26) — logged as ISSUE-14, not introduced by this session.
  - `npx tsc --noEmit` (Pss2.0_Frontend): ZERO new errors introduced. Pre-existing errors remain in unrelated files (event-analytics, menu-store, accesscontrol, ambassador-performance, email-send-job).
  - Worktree: all files landed in `pwds-soruban - Copy/`, none in sibling `pwds-soruban/`. Confirmed via git status + path-explicit Globs.
- **User actions for E2E**:
  1. From `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/`: `dotnet ef migrations add Add_AccountingIntegration_And_Children --project Base.Infrastructure --startup-project ../Base.API` (regen Designer/Snapshot for ISSUE-13) OR `dotnet ef database update --project Base.Infrastructure --startup-project ../Base.API` (apply directly).
  2. Execute `Pss2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/accountingintegration-sqlscripts.sql` against the dev DB to seed menu + capabilities + role grants + Grid + default per-tenant rows + sample SyncLogs.
  3. From `Pss2.0_Frontend/`: `pnpm dev`.
  4. Navigate to `/{lang}/setting/integration/accountingintegration` — sidebar leaf under Settings › Integration → "Accounting Integration" (purple `ph:link-simple-horizontal` icon, OrderBy=1).
  5. Verify default tenant row auto-seeded (Provider='None' / IsConnected=false → grey banner "Not connected — pick a provider"); click Connect on QuickBooks → SERVICE_PLACEHOLDER toast → page refetches → Connection Details card appears + mappings activate + sample SyncLogs render.
- **Next step**: (none — COMPLETED). Optional follow-up: build sibling screens (#86 API Management, #87 Marketplace, #89 Social Media) — they reuse the new `integ` schema and `Integration` group folders without re-creating module infrastructure. Future REPORT screen for "Full Sync Log" (ISSUE-10) can be planned when needed.

(No sessions recorded yet — filled in after /build-screen completes.)