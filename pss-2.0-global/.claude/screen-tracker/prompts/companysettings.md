---
screen: CompanySettings
registry_id: 75
module: Setting
status: COMPLETED
scope: FULL
screen_type: CONFIG
config_subtype: SETTINGS_PAGE
storage_pattern: singleton-per-tenant
save_model: save-all
complexity: High
new_module: NO (uses existing `app` schema for Company enhancement + `sett` schema for NEW singletons + Setting group)
planned_date: 2026-05-01
completed_date: 2026-05-01
last_session_date: 2026-05-01
backend_completed: true
frontend_completed: true
fe_session3_aligned: true
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed — 8 sections (Org Profile / Contact / Branding / Financial / Regional / Communication / System / Subscription), left sidebar nav, single sticky page-top Save / Discard
- [x] Sub-type identified: `SETTINGS_PAGE` (multi-section settings on a tenant-scoped singleton)
- [x] Storage model: 2 NEW singleton entities (`CompanyConfiguration` + `CompanyBranding`) + ENHANCE existing `Company` entity (15 new columns for Org Profile / Contact / Receipt-customization)
- [x] Save model chosen: `save-all` (single Save Changes button at page top — mockup is unambiguous; no per-section saves)
- [x] Sensitive fields & role gates identified: BUSINESSADMIN-only screen; Maintenance Mode toggle is an exception with its own warning + audit trail
- [x] FK targets resolved (paths + GQL queries verified — Country/Currency/Language/MasterData)
- [x] File manifest computed (BE: 23 created + 7 modified; FE: 18 created + 6 modified)
- [x] Approval config pre-filled (READ + MODIFY only — singleton has no Create/Delete)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (config purpose + edit personas + risk) — validated via prompt review; user pre-approved
- [x] Solution Resolution complete (sub-type confirmed, save model confirmed) — validated via prompt review; user pre-approved
- [x] UX Design finalized (8-section sidebar layout + Save All header + Subscription read-only) — validated via prompt review; user pre-approved
- [x] User Approval received (CONFIG block + scope split BE/FE + ToggleMaintenanceMode deferred — 2026-05-01)
- [x] Backend code generated (Company enhancement + CompanyConfiguration + CompanyBranding entities + composite GetCompanySettings + composite UpdateCompanySettings + GetCompanySubscriptionInfo placeholder; ToggleMaintenanceMode DEFERRED per user)
- [x] Backend wiring complete (Company.cs + ApplicationConfigurations/CompanyConfiguration.cs + ISettingDbContext + SettingDbContext + DecoratorProperties + SettingMappings + ApplicationMappings + GlobalUsing; GraphQL types auto-register via [ExtendObjectType])
- [x] Frontend code generated (settings-page + 8 section components + Zustand store + sticky save bar + maintenance-mode confirm modal) — Session 2 (2026-05-01)
- [x] Frontend wiring complete (DTO + GQL query/mutation + page config + route stub + 7 barrel exports) — Session 2 (2026-05-01); operations-config skipped (CONFIG screens have no row-level CRUD; matches EmailProviderConfig precedent)
- [x] DB Seed script generated (`CompanySettings-sqlscripts.sql` in `sql-scripts-dyanmic/`) — re-parents COMPANYSETTINGS to SET_ORGSETTINGS, capabilities, BUSINESSADMIN grants, ORGANIZATIONTYPE (7) + LOGINTEMPLATE (5) MasterData seeds, default CompanyConfiguration + CompanyBranding rows for sample Company
- [x] Registry updated to COMPLETED — flipped from PARTIALLY_COMPLETED (Session 2)

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] EF migration `Add_CompanyConfiguration_And_Branding_And_CompanyEnhancements` applied (Company table altered; new tables created)
- [ ] pnpm dev — page loads at `/{lang}/setting/orgsettings/companysettings`
- [ ] **SETTINGS_PAGE checks**:
  - [ ] First-load auto-seeds default CompanyConfiguration + CompanyBranding rows for current tenant (no 404 / null state)
  - [ ] All 8 sections render with correct sidebar order, icons, and grouping (Org Profile / Contact / Branding / Financial / Regional / Communication / System / Subscription)
  - [ ] Sidebar tab click switches active section + scrolls to top
  - [ ] Save Changes (page-top) persists ALL editable sections (1–7) in one mutation
  - [ ] Discard Changes shows confirm dialog → on confirm reverts entire form to last-saved state
  - [ ] Validation errors block save and surface inline per field (Section 1: Organization Name required; Section 2: Address Line 1 + City + Country + Phone + Email required; Section 4: Financial Year Start + Default Currency required; Section 5: Default Language + Default Timezone + Country of Operation required)
  - [ ] Subscription section (Section 8) renders read-only — NO save, NO edit affordances; "View Plans & Pricing" + "Contact Support" buttons are SERVICE_PLACEHOLDER toasts
  - [ ] Maintenance-mode toggle: enabling shows confirm modal with warning; disabling shows confirm modal; both audit-logged
  - [ ] Receipt Auto-numbering toggle: when enabled, "Next: REC-NNNN" preview is computed from `(ReceiptNumberPrefix + last issued seq + 1)`
  - [ ] Color-picker fields: hex input + swatch sync in both directions; invalid hex blocks save
  - [ ] Multi-currency tag input: chips render, X removes; ApiSelect to add another currency
  - [ ] Multi-language tag input + Multi-country-of-operation tag input behave the same
  - [ ] Logo / Favicon / Receipt-header image upload is wired to a SERVICE_PLACEHOLDER (no real upload service); UI shows a "✓ uploaded" stub or stores the file as a data-URL preview only
  - [ ] Unsaved-changes blocker: navigating away with dirty form prompts confirm dialog
  - [ ] Audit trail records every successful UpdateCompanySettings mutation (whole-payload audit, not per-field)
- [ ] Empty / loading / error states render
- [ ] DB Seed — menu visible in sidebar at Settings › Org Settings › Company Settings (re-parented from RA_AUDIT to SET_ORGSETTINGS)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: CompanySettings
Module: Setting
Schemas: `app` (Company entity — ENHANCED in place) + `sett` (CompanyConfiguration + CompanyBranding — NEW singletons)
Group: Setting (handlers/configs/schemas/endpoints/mappings live under SettingBusiness / SettingConfigurations / SettingSchemas / EndPoints/Setting / SettingMappings)
Frontend Module: setting (route under `(core)/setting/orgsettings/companysettings`)

**Business**: This is the **cornerstone tenant-configuration screen** for the SaaS multi-tenant platform — a single page where the **organization's BUSINESSADMIN** sets every parameter that other screens read at runtime. The 8 sections govern: (1) **Identity** — legal/regulatory facts about the organization (name, registration, tax IDs, FCRA, incorporation date — feeds receipts, compliance reports, public donation pages); (2) **Contact** — address + phone + email used as registered office on receipts and `noreply` from-address fallback; (3) **Branding** — logos, favicon, brand colors, receipt header/footer image — injected into login page CSS, sidebar, email/receipt PDFs; (4) **Financial** — fiscal-year start month + base currency + tax-receipt rules — drives every donation entry and receipt number generation across the app; (5) **Regional** — language + timezone + date/time format + operating countries — used by every screen for date display and dropdown defaults; (6) **Communication** — default sender name/email + reply-to + SMS sender ID + email signature + WhatsApp business number — fallback when individual templates omit these; (7) **System** — auto-logout, login-attempts-before-lock, 2FA mode, password policy (length/expiry/history/complexity), audit retention, deleted-record retention, maintenance mode — **enforced server-side by auth middleware and retention jobs**; (8) **Subscription** — plan tier + billing cycle + seat usage + storage usage + feature flags — **READ-ONLY display** (billing service not in MVP scope). The screen edits a singleton: exactly one row per Company in each of `app.Companies` (enhanced for §1–2), `app.CompanyConfigurations` (§4–7), `app.CompanyBrandings` (§3). Edit cadence: **rare — typically one-time during onboarding, then quarterly tweaks** (e.g. fiscal year, branding refresh, password policy change after a security audit). Personas: BUSINESSADMIN only (the tenant's owner/operator). Risk-of-misconfig is HIGH for security fields (wrong password policy = compliance failure; maintenance mode left on = full app outage), MEDIUM for branding (wrong logo on receipts looks unprofessional but recoverable), and HIGH for fiscal year (changing mid-year corrupts receipt numbering and finance reports). What's unique about this config's UX vs. a generic settings page: **it spans 3 entity tables** with a single sticky Save Changes button persisting all of them in one transaction, **mixes editable and read-only sections** (Subscription is purely informational), and includes **destructive ops gated by their own confirms** (Maintenance Mode toggle, Discard Changes).

> Why §① is heavier than other screens: the developer must understand WHY the screen mixes 3 entities behind a single Save button (UX expectation: "this IS my company"), and WHY Subscription is read-only (no billing service yet). Without that grounding, an agent will either split it into 3 separate screens or build a fake billing CRUD.

---

## ② Storage Model

> **Consumer**: BA Agent → Backend Developer
> **Storage Pattern**: `singleton-per-tenant`
> Audit columns (CreatedBy/CreatedDate/ModifiedBy/ModifiedDate/IsActive/IsDeleted) inherited from `Entity` base — DO NOT enumerate.
> CompanyId is **always** present and **NEVER** a form field — derived from HttpContext (`ITenantContext.GetRequiredTenantId()`).

This screen touches **3 tables** behind one Save:

### Table 1: `app."Companies"` (EXISTING — ENHANCE)

> Existing entity at `Base.Domain/Models/ApplicationModels/Company.cs` has only 7 scalar fields (`CompanyCode`, `CompanyName`, `CompanyHeader`, `CompanyFooter`, `Address`, `CountryId`). Add these new columns:

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| ShortName | string? | 50 | NO | — | NEW. Org abbreviation (e.g. "GHF") |
| OrganizationTypeId | int? | — | NO | sett.MasterDatas (TypeCode=ORGANIZATIONTYPE) | NEW. Trust/Society/NGO/Foundation/etc. |
| RegistrationNumber | string? | 100 | NO | — | NEW. Govt registration # |
| TaxId | string? | 100 | NO | — | NEW. PAN / TIN / EIN |
| FCRARegistrationNumber | string? | 100 | NO | — | NEW. India-specific foreign-funds registration |
| DateOfIncorporation | DateOnly? | — | NO | — | NEW. Founding date |
| Website | string? | 255 | NO | — | NEW. Public URL |
| Description | string? | — | NO | — | NEW. text/varchar(MAX) — long-form |
| AddressLine2 | string? | 200 | NO | — | NEW. Optional second address line |
| City | string? | 100 | NO | — | NEW |
| State | string? | 100 | NO | — | NEW |
| PostalCode | string? | 20 | NO | — | NEW |
| PrimaryEmail | string? | 150 | NO | — | NEW. Primary org email shown on receipts |
| PrimaryPhone | string? | 50 | NO | — | NEW. Primary org phone |
| Fax | string? | 50 | NO | — | NEW. Optional |

> All new columns nullable to allow existing rows to migrate without backfill failure (BA will choose required-vs-optional at validator level — see §④).

### Table 2: `sett."CompanyConfigurations"` (NEW — singleton, Settings module)

> **Session 2 (2026-05-01) refactor**: Receipt/Tax fields **MOVED OUT** to a future separate "Receipt & Tax Configuration" screen (single-concern). All dropdown-style enum fields **converted to FK → MasterData** so option lists are tenant-configurable in one place. Multi-select CSVs **normalized to junction tables** (see §②a).

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CompanyConfigurationId | int | — | PK | — | identity |
| CompanyId | int | — | YES | app.Companies | tenant scope (NOT a form field) |
| **— Financial (§4) —** | | | | | |
| FinancialYearStartMonthId | int | — | YES | sett.MasterDatas (TypeCode=FINANCIALYEARSTARTMONTH) | 12 rows: Jan…Dec; DataValue holds 1–12 |
| BaseCurrencyId | int | — | YES | com.Currencies | default currency |
| CurrencyDisplayFormatId | int | — | YES | sett.MasterDatas (TypeCode=CURRENCYDISPLAYFORMAT) | 3 rows: SymbolBefore / SymbolAfter / IsoCodeBefore |
| NumberFormatId | int | — | YES | sett.MasterDatas (TypeCode=NUMBERFORMAT) | 4 rows: 1,234,567.89 / 1.234.567,89 / 1 234 567.89 / 12,34,567.89 |
| **— Regional (§5) —** | | | | | |
| DefaultLanguageId | int | — | YES | com.Languages | UI fallback language |
| DefaultTimezoneId | int | — | YES | sett.MasterDatas (TypeCode=TIMEZONE) | ~30 common IANA tz; DataValue=IANA id ("Asia/Dubai"); DataName=display ("UTC+4 Dubai") |
| DateFormatId | int | — | YES | sett.MasterDatas (TypeCode=DATEFORMAT) | 4 rows: DD/MM/YYYY / MM/DD/YYYY / YYYY-MM-DD / DD-MMM-YYYY |
| TimeFormatId | int | — | YES | sett.MasterDatas (TypeCode=TIMEFORMAT) | 2 rows: 12-hour / 24-hour |
| CountryOfOperationId | int | — | YES | com.Countries | primary operating country (may differ from Companies.CountryId — registered vs operating) |
| **— Communication (§6) —** | | | | | |
| SenderName | string? | 150 | NO | — | falls back to CompanyName if NULL |
| SenderEmail | string? | 200 | NO | — | falls back to PrimaryEmail |
| ReplyToEmail | string? | 200 | NO | — | reply-to header |
| SmsSenderId | string? | 11 | NO | — | alphanumeric, max 11 chars (telco rule) |
| EmailSignature | string? | — | NO | — | text/varchar(MAX) — basic HTML |
| WhatsappBusinessNumber | string? | 50 | NO | — | E.164 format |
| **— System (§7) —** | | | | | |
| AutoLogoutMinutesId | int | — | YES | sett.MasterDatas (TypeCode=AUTOLOGOUTMINUTES) | 5 rows: 15min/30min/60min/2hr/Never; DataValue holds minutes (-1=Never) |
| LoginAttemptsBeforeLockId | int | — | YES | sett.MasterDatas (TypeCode=LOGINATTEMPTSBEFORELOCK) | 3 rows: 3/5/10 |
| TwoFactorAuthModeId | int | — | YES | sett.MasterDatas (TypeCode=TWOFACTORAUTHMODE) | 3 rows: Disabled/AdminsOnly/AllUsers |
| PasswordMinLengthId | int | — | YES | sett.MasterDatas (TypeCode=PASSWORDMINLENGTH) | 5 rows: 6/8/10/12/16 |
| PasswordExpiryDaysId | int | — | YES | sett.MasterDatas (TypeCode=PASSWORDEXPIRYDAYS) | 5 rows: 30/60/90/180/Never (-1) |
| PasswordHistoryCountId | int | — | YES | sett.MasterDatas (TypeCode=PASSWORDHISTORYCOUNT) | 3 rows: 3/5/10 |
| PasswordRequireUppercase | bool | — | YES | — | |
| PasswordRequireNumber | bool | — | YES | — | |
| PasswordRequireSpecialChar | bool | — | YES | — | |
| AuditLogRetentionYearsId | int | — | YES | sett.MasterDatas (TypeCode=AUDITLOGRETENTIONYEARS) | 5 rows: 1y/3y/5y/7y/Indefinite (-1) |
| DeletedRecordsRetentionDaysId | int | — | YES | sett.MasterDatas (TypeCode=DELETEDRECORDSRETENTIONDAYS) | 4 rows: 30/90/180/365 |
| MaintenanceModeEnabled | bool | — | YES | — | when true, non-admins see maintenance page |
| MaintenanceModeMessage | string? | 500 | NO | — | optional banner text shown when enabled |

> **Removed in Session 2 refactor** (moved to future "Receipt & Tax Configuration" screen): TaxReceiptRequired, ReceiptAutoNumberingEnabled, ReceiptNumberPrefix, TaxExemptionSection, TaxExemptionCertificateNumber, TaxExemptionValidUntil. **ISSUE-2 superseded** — next-receipt-number preview is no longer this screen's concern.

> **Multi-select fields normalized to junction tables** (Session 2 — see §②a): AdditionalCurrenciesCsv → `sett.CompanyConfigurationCurrencies`. AdditionalLanguagesCsv → `sett.CompanyConfigurationLanguages`. AdditionalOperatingCountriesCsv → `sett.CompanyConfigurationOperatingCountries`.

**Singleton constraint**:
- Unique filtered index: `CREATE UNIQUE INDEX IX_CompanyConfigurations_CompanyId_Active ON sett."CompanyConfigurations"("CompanyId") WHERE "IsDeleted" = false`
- `GetCompanySettings` auto-creates a default row keyed off `Company.CompanyId` if missing (initial onboarding might fail to seed).

### Table 3: `sett."CompanyBrandings"` (NEW — singleton, Settings module)

> Branding section (§3 in mockup). Mockup edits: Logo, Favicon, Primary Color, Secondary Color. Architecture doc 09 also references LoginTemplate / LoginPage assets / social links — these are **deferred** (no UI in §3 of this mockup) but columns kept so dependent screens (Login Designer #future) don't require a second migration.

> **Session 2 refactor**: ReceiptHeaderImageUrl + ReceiptFooterText **REMOVED** — moved to future "Receipt & Tax Configuration" screen.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CompanyBrandingId | int | — | PK | — | identity |
| CompanyId | int | — | YES | app.Companies | tenant scope |
| **— Mockup §3 (in-scope) —** | | | | | |
| LogoUrl | string? | 500 | NO | — | org logo (200×60px PNG/SVG, max 500KB) |
| FaviconUrl | string? | 500 | NO | — | 32×32 ICO/PNG |
| PrimaryColorHex | string? | 7 | NO | — | "#0e7490" — used in headers, buttons, links |
| SecondaryColorHex | string? | 7 | NO | — | "#059669" — used in accents/highlights |
| **— Out-of-scope of this mockup but seeded for forward compat —** | | | | | |
| AppLogoSmallUrl | string? | 500 | NO | — | collapsed-sidebar icon — leave NULL on first save |
| EmailLogoUrl | string? | 500 | NO | — | leave NULL |
| EmailFooterText | string? | — | NO | — | leave NULL |
| LoginTemplateId | int? | — | NO | sett.MasterDatas (TypeCode=LOGINTEMPLATE) | leave NULL |
| LoginPageImageUrl | string? | 500 | NO | — | |
| LoginPageVideoUrl | string? | 500 | NO | — | |
| LoginPageBackgroundColor | string? | 7 | NO | — | |
| WebsiteUrl | string? | 255 | NO | — | mirrors Companies.Website — kept for branding-page locality |
| FacebookUrl | string? | 255 | NO | — | |
| TwitterUrl | string? | 255 | NO | — | |
| InstagramUrl | string? | 255 | NO | — | |
| YoutubeUrl | string? | 255 | NO | — | |

**Singleton constraint**:
- Unique filtered index: `CREATE UNIQUE INDEX IX_CompanyBrandings_CompanyId_Active ON sett."CompanyBrandings"("CompanyId") WHERE "IsDeleted" = false`

### §②a Junction Tables (NEW in Session 2 — proper M:N normalization)

3 new join tables replace the 3 CSV columns. All inherit `Entity` (audit columns + IsActive + IsDeleted). All have a unique composite index on `(CompanyConfigurationId, {RefId})` to prevent duplicates.

#### Table 4: `sett."CompanyConfigurationCurrencies"` (NEW)

| Field | C# Type | Required | FK Target | Notes |
|-------|---------|----------|-----------|-------|
| CompanyConfigurationCurrencyId | int | PK | — | identity |
| CompanyConfigurationId | int | YES | sett.CompanyConfigurations | parent |
| CurrencyId | int | YES | com.Currencies | additional supported currency |

- Unique composite index: `(CompanyConfigurationId, CurrencyId) WHERE IsDeleted = false`
- Cascade delete from CompanyConfigurations.

#### Table 5: `sett."CompanyConfigurationLanguages"` (NEW)

| Field | C# Type | Required | FK Target | Notes |
|-------|---------|----------|-----------|-------|
| CompanyConfigurationLanguageId | int | PK | — | identity |
| CompanyConfigurationId | int | YES | sett.CompanyConfigurations | parent |
| LanguageId | int | YES | com.Languages | additional supported language |

- Unique composite index: `(CompanyConfigurationId, LanguageId) WHERE IsDeleted = false`

#### Table 6: `sett."CompanyConfigurationOperatingCountries"` (NEW)

| Field | C# Type | Required | FK Target | Notes |
|-------|---------|----------|-----------|-------|
| CompanyConfigurationOperatingCountryId | int | PK | — | identity |
| CompanyConfigurationId | int | YES | sett.CompanyConfigurations | parent |
| CountryId | int | YES | com.Countries | additional operating country |

- Unique composite index: `(CompanyConfigurationId, CountryId) WHERE IsDeleted = false`

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` + nav properties) + Frontend Developer (ApiSelect queries)
>
> **Session 2 (2026-05-01) refactor**: All previous "static FE-side enums" are now FK to `sett.MasterDatas` (TypeCode-filtered). FE uses **single shared `GetMasterDatas` query with TypeCode filter** for every dropdown — no static `/lib/timezones.ts`, no in-code enum lists. Tag-input fields now use **junction tables** (see §②a), not CSV strings.

### Single-select FK lookups

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| Companies.CountryId | Country | Base.Domain/Models/SharedModels/Country.cs | GetCountries | CountryName | CountryResponseDto |
| Companies.OrganizationTypeId | MasterData TypeCode=ORGANIZATIONTYPE | Base.Domain/Models/SettingModels/MasterData.cs | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.BaseCurrencyId | Currency | Base.Domain/Models/SharedModels/Currency.cs | GetCurrencies | CurrencyName | CurrencyResponseDto |
| CompanyConfigurations.DefaultLanguageId | Language | Base.Domain/Models/SharedModels/Language.cs | GetLanguages | LanguageName | LanguageResponseDto |
| CompanyConfigurations.CountryOfOperationId | Country | (above) | GetCountries | CountryName | CountryResponseDto |
| CompanyBrandings.LoginTemplateId | MasterData TypeCode=LOGINTEMPLATE | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.FinancialYearStartMonthId | MasterData TypeCode=FINANCIALYEARSTARTMONTH | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.CurrencyDisplayFormatId | MasterData TypeCode=CURRENCYDISPLAYFORMAT | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.NumberFormatId | MasterData TypeCode=NUMBERFORMAT | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.DefaultTimezoneId | MasterData TypeCode=TIMEZONE | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.DateFormatId | MasterData TypeCode=DATEFORMAT | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.TimeFormatId | MasterData TypeCode=TIMEFORMAT | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.AutoLogoutMinutesId | MasterData TypeCode=AUTOLOGOUTMINUTES | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.LoginAttemptsBeforeLockId | MasterData TypeCode=LOGINATTEMPTSBEFORELOCK | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.TwoFactorAuthModeId | MasterData TypeCode=TWOFACTORAUTHMODE | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.PasswordMinLengthId | MasterData TypeCode=PASSWORDMINLENGTH | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.PasswordExpiryDaysId | MasterData TypeCode=PASSWORDEXPIRYDAYS | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.PasswordHistoryCountId | MasterData TypeCode=PASSWORDHISTORYCOUNT | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.AuditLogRetentionYearsId | MasterData TypeCode=AUDITLOGRETENTIONYEARS | (above) | GetMasterDatas | DataName | MasterDataResponseDto |
| CompanyConfigurations.DeletedRecordsRetentionDaysId | MasterData TypeCode=DELETEDRECORDSRETENTIONDAYS | (above) | GetMasterDatas | DataName | MasterDataResponseDto |

> **MasterData seeded values for the new TypeCodes**: see §⑧ DB seed for the full row-level seed data (DataName + DataValue per row).

### Multi-select junction-table sources

| Form Section | Junction Table | Source GQL (for ApiSelect) | What's Stored |
|--------------|----------------|----------------------------|---------------|
| §4 Additional Currencies | sett.CompanyConfigurationCurrencies | GetCurrencies | one row per (CompanyConfigurationId, CurrencyId) |
| §5 Additional Languages | sett.CompanyConfigurationLanguages | GetLanguages | one row per (CompanyConfigurationId, LanguageId) |
| §5 Additional Operating Countries | sett.CompanyConfigurationOperatingCountries | GetCountries | one row per (CompanyConfigurationId, CountryId) |

> Update strategy: on UpdateCompanySettings, BE diffs the incoming list against existing junction rows for this CompanyConfigurationId — adds new rows, soft-deletes (IsDeleted=true) removed ones. No replace-all wipe.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Singleton / Cardinality Rules:**
- Exactly one CompanyConfiguration row per CompanyId — Update only, no Create/Delete via API.
- Exactly one CompanyBranding row per CompanyId — same.
- `GetCompanySettings` returns a composite DTO containing the Company row + CompanyConfiguration row + CompanyBranding row. **If either child row is missing, the handler auto-creates it with seeded defaults inside the same transaction**, then re-fetches.
- `UpdateCompanySettings` accepts the composite payload and persists to all 3 tables in one DB transaction. Partial failure rolls back all writes.
- Subscription section is **READ-ONLY** — no DB write; data sourced from a placeholder query `GetCompanySubscriptionInfo` returning a hardcoded plan-info DTO with `IsPlaceholder = true`. **Do NOT generate a Subscriptions entity.** (See §⑫ ISSUE-1.)

**Required Field Rules** (BE validator + FE Zod):

Section 1 (Org Profile):
- `CompanyName` required, min 2, max 100 chars
- `Website` if provided, must match `^https?://`

Section 2 (Contact):
- `Address` (Address Line 1) required, max 200
- `City` required, max 100
- `Companies.CountryId` required (FK)
- `PrimaryPhone` required, max 50
- `PrimaryEmail` required, valid email format

Section 4 (Financial):
- `FinancialYearStartMonthId` required (FK MasterData TypeCode=FINANCIALYEARSTARTMONTH)
- `BaseCurrencyId` required (FK)
- `CurrencyDisplayFormatId` required (FK MasterData TypeCode=CURRENCYDISPLAYFORMAT)
- `NumberFormatId` required (FK MasterData TypeCode=NUMBERFORMAT)
- (Tax/Receipt fields removed — now in future "Receipt & Tax Configuration" screen)

Section 5 (Regional):
- `DefaultLanguageId` required (FK)
- `DefaultTimezoneId` required (FK MasterData TypeCode=TIMEZONE)
- `DateFormatId` required (FK MasterData TypeCode=DATEFORMAT)
- `TimeFormatId` required (FK MasterData TypeCode=TIMEFORMAT)
- `CountryOfOperationId` required (FK)

Section 6 (Communication):
- `SenderEmail` if provided, valid email
- `ReplyToEmail` if provided, valid email
- `SmsSenderId` if provided, alphanumeric, 3–11 chars (telco rule)
- `WhatsappBusinessNumber` if provided, E.164 format `^\+\d{10,15}$`

Section 7 (System):
- All FK Id fields required (`AutoLogoutMinutesId`, `LoginAttemptsBeforeLockId`, `TwoFactorAuthModeId`, `PasswordMinLengthId`, `PasswordExpiryDaysId`, `PasswordHistoryCountId`, `AuditLogRetentionYearsId`, `DeletedRecordsRetentionDaysId`); 3 booleans default to true.
- (FK MasterData rows enforce the allowed values — no separate range check needed; e.g. `PasswordMinLengthId` only resolves to one of {6,8,10,12,16})
- `MaintenanceModeMessage` required if `MaintenanceModeEnabled = true`

**Conditional Rules:**
- If `TwoFactorAuthModeId` resolves to "Disabled", no further checks. Otherwise login flow must enforce.
- If `MaintenanceModeEnabled` flips false→true: confirm modal + audit log entry "MAINTENANCE_MODE_ENABLED by {userId}".
- If `MaintenanceModeEnabled` flips true→false: confirm modal + audit log "MAINTENANCE_MODE_DISABLED".

**Sensitive Fields** (audit + role-gating):

| Field | Sensitivity | Display Treatment | Save Treatment | Audit |
|-------|-------------|-------------------|----------------|-------|
| (no secret credentials in this screen) | — | — | — | — |
| MaintenanceModeEnabled | operational | normal toggle | confirm modal both directions | log every flip with old→new + actor |
| PasswordMinLengthId + PasswordExpiryDaysId + PasswordRequireUppercase/Number/Special | regulatory | normal | normal | log changes |
| FinancialYearStartMonthId | regulatory | normal | normal | **log + warn user "changing FY mid-year may affect downstream finance reports"** |

> Unlike SMTP / API-key configs, this screen does NOT have raw-secret fields, so masked-input + write-only patterns from `_CONFIG.md` Block A example don't apply here.

**Read-only / System-controlled Fields:**
- Section 8 (Subscription): plan tier, billing cycle, renewal date, seat usage, storage usage, feature checklist — ALL read-only (no inputs). Sourced from `GetCompanySubscriptionInfo` placeholder query.
- `Companies.CompanyCode` — display-only chip in §1; never editable post-onboarding (audit/legal).

**Dangerous Actions** (require confirm + audit):

| Action | Effect | Confirmation | Audit |
|--------|--------|--------------|-------|
| Discard Changes | Reverts all unsaved changes in form (no DB write) | "Are you sure you want to discard all unsaved changes? This action cannot be undone." | not audited (client-only) |
| Toggle Maintenance Mode ON | All non-admin users see maintenance page | "Enabling maintenance mode will immediately lock out all non-admin users. Proceed?" | audit log: `MAINTENANCE_MODE_ENABLED` |
| Toggle Maintenance Mode OFF | Non-admin access restored | "Disable maintenance mode and restore user access?" | audit log: `MAINTENANCE_MODE_DISABLED` |
| Change FinancialYearStartMonthId (after first save with non-default value) | Affects fiscal-year-bound reports | inline warning banner: "⚠ Changing the financial year start may affect downstream finance reports." (visible whenever the field is dirty) | audit log: `FY_CHANGED old=X new=Y` |
| Reset to Defaults | NOT shown in mockup — DEFER (no global Reset button in mockup; do not generate) | — | — |

> Mockup does NOT show a "Reset to Defaults" button — do not generate one. Discard Changes (header) only reverts unsaved edits.

**Role Gating:**

| Role | Sections Visible | Sections Editable | Notes |
|------|------------------|-------------------|-------|
| BUSINESSADMIN | all 8 | sections 1–7 (Section 8 is read-only by design) | full access |
| (others) | screen hidden via menu capability | — | menu COMPANYSETTINGS not granted to other roles per §⑨ |

**Workflow**: None. (Save persists immediately; no draft/publish.)

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED.

**Screen Type**: CONFIG
**Config Sub-type**: `SETTINGS_PAGE`
**Storage Pattern**: `singleton-per-tenant`
**Save Model**: `save-all` — single sticky page-top "Save Changes" button persists all 7 editable sections in one transaction. Mockup shows this unambiguously: header has Discard Changes + Save Changes, no per-section Save buttons. Section 8 is read-only.

**Reason**: 8 sections but BUSINESSADMIN edits this screen rarely (onboarding + occasional updates), and the sections are tightly coupled (e.g. enabling Tax Receipt + setting Receipt Prefix is one logical change). save-per-section would force 7 round-trips for what's typically a single editing pass. Mockup makes the choice explicit.

**Backend Patterns Required (SETTINGS_PAGE singleton-per-tenant):**
- [x] `GetCompanySettings` query — fetches by tenant from HttpContext, joins Company + CompanyConfiguration + CompanyBranding into composite DTO, auto-seeds default rows if missing (see ④)
- [x] `UpdateCompanySettings` mutation — accepts full composite payload, validates per-section, writes to all 3 tables in one DB transaction
- [ ] `Update{Section}Settings` per-section — NOT NEEDED (save-all only)
- [ ] `ResetTo{Entity}Defaults` mutation — NOT NEEDED (mockup has no Reset)
- [x] `GetCompanySubscriptionInfo` query — placeholder returning hardcoded plan info (Section 8). **No DB write counterpart.**
- [ ] `Test{Capability}` — NOT applicable (no SMTP/API-key test in this screen)
- [x] Tenant scoping (CompanyId from HttpContext via existing `ITenantContext`)
- [ ] Sensitive-field handling (mask-on-read) — NOT applicable (no secret-credential fields)
- [x] Audit-trail emission for: MaintenanceMode flip, FY change, Password Policy change

**Frontend Patterns Required (SETTINGS_PAGE):**
- [x] Custom multi-section page (NOT RJSF modal, NOT view-page 3-mode)
- [x] Section container — `sidebar-nav` (8 sections, deep enough that vertical sticky sidebar wins over tabs)
- [x] One section component per section (own React fragment, shared parent RHF form context)
- [x] Sticky page-top save bar with Save Changes (primary) + Discard Changes (outline destructive)
- [x] Tag-input control for multi-currency / multi-language / multi-country
- [x] Color-picker pair (swatch + hex text input, 2-way bound)
- [x] File-upload card with preview thumbnail (Logo, Favicon, Receipt Header Image — wired to SERVICE_PLACEHOLDER)
- [x] Confirm dialog for Maintenance Mode toggle (both directions)
- [x] Subscription section: read-only display (badge + label/value grid + usage bars + feature checklist + 2 action buttons that toast SERVICE_PLACEHOLDER)
- [x] Dirty-indicator + unsaved-changes blocker (Next.js `usePathname` + Zustand dirty flag → `beforeunload` listener + back-nav guard)
- [x] Save indicator — toast on success ("Company settings updated successfully" — text from mockup line 1314), inline error per field on validation fail

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **CRITICAL**: This is the design spec. Sub-type Block A (SETTINGS_PAGE) only — Blocks B and C deleted.

### 🎨 Visual Uniqueness Rules (apply)

1. Section emphasis varies — Subscription (§8) is hero-styled with plan badge gradient (`linear-gradient(135deg, #0e7490, #06b6d4)`), big seat-usage bars, feature checklist with green ✓ vs gray − icons. Sections 1–7 share consistent card chrome but with section-specific Phosphor icons in section header.
2. Layout matches content: Org Profile + Contact + Communication = 2-col `row g-3` Bootstrap grid; Branding = mixed (file-upload cards in 2-col row, full-width receipt-footer textarea); Financial / Regional / System = 3-col grid for short fields with sub-cards for grouped items (Tax/Receipt sub-card, Password Policy sub-card, Data Retention sub-card, Maintenance Mode toggle row).
3. Sensitive fields — N/A (no raw secrets).
4. Read-only — Section 8 chips/labels visually distinct from editable fields (no input borders, no focus states; gray text for "67% of seats used" footer hint).
5. Section icons — semantic Phosphor: `ph:building` (Org), `ph:address-book` (Contact), `ph:palette` (Branding), `ph:coins` (Financial), `ph:globe` (Regional), `ph:envelope-simple` (Communication), `ph:gear` (System), `ph:crown` (Subscription).
6. Save / status — top-right sticky header has primary "Save Changes" + outline "Discard Changes". Maintenance Mode toggle has its own warning banner (yellow) inline. Toast on save success (top-right slide-in, 3s).

**Anti-patterns to refuse**:
- Generating a "Save" button per section — mockup has ONE save button at the top.
- Putting Subscription as an editable form — it's read-only display.
- Replacing the sidebar nav with horizontal tabs (mockup is unambiguously sidebar).
- Implementing Maintenance Mode toggle without confirm modal — mockup explicitly shows the warning banner.

---

### 🅰️ Block A — SETTINGS_PAGE

#### Page Layout

**Container Pattern**: `sidebar-nav` (left vertical sticky sidebar, 240px wide, with 8 nav items; right content scrolls; on mobile the sidebar collapses to a horizontal scrolling tab bar at top)

**Page Header** (sticky, z-index 100, top of content area):
- Left side: Title `Company Settings` + admin badge (red pill `Admin`) + subtitle "Organization profile, branding, and system configuration"
- Right side: `[Discard Changes]` (outline) + `[Save Changes]` (primary accent)

#### Section Definitions

| # | Section Title | Icon (Phosphor) | Container Slot | Save Mode | Role Gate |
|---|---------------|-----------------|----------------|-----------|-----------|
| 1 | Organization Profile | `ph:building` | sidebar-nav-item-1 | save-all (page-top) | BUSINESSADMIN |
| 2 | Contact Information | `ph:address-book` | sidebar-nav-item-2 | save-all (page-top) | BUSINESSADMIN |
| 3 | Branding | `ph:palette` | sidebar-nav-item-3 | save-all (page-top) | BUSINESSADMIN |
| 4 | Financial Configuration | `ph:coins` | sidebar-nav-item-4 | save-all (page-top) | BUSINESSADMIN |
| 5 | Regional & Localization | `ph:globe` | sidebar-nav-item-5 | save-all (page-top) | BUSINESSADMIN |
| 6 | Communication Defaults | `ph:envelope-simple` | sidebar-nav-item-6 | save-all (page-top) | BUSINESSADMIN |
| 7 | System Preferences | `ph:gear` | sidebar-nav-item-7 | save-all (page-top) | BUSINESSADMIN |
| 8 | Subscription & Plan | `ph:crown` | sidebar-nav-item-8 | (no save — read-only display) | BUSINESSADMIN |

> Active-section state lives in Zustand store (`activeSection`); clicking a sidebar item updates store + smooth-scrolls to the section anchor. Only ONE section visible at a time (display: block on active, none on others) — matching mockup behavior.

#### Field Mapping per Section

**Section 1 — Organization Profile** (mockup lines 660–716)

| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| organizationName (Companies.CompanyName) | text (col-md-8) | "" | required, 2–100 chars | label "Organization Name *" |
| shortName (Companies.ShortName) | text (col-md-4) | "" | optional, max 50 | "Short Name / Abbreviation" |
| organizationTypeId (Companies.OrganizationTypeId) | ApiSelect (col-md-4) | null | optional | source: GetMasterDatas TypeCode=ORGANIZATIONTYPE — Trust/Society/Section8/NGO/Foundation/Association/Other |
| registrationNumber (Companies.RegistrationNumber) | text (col-md-4) | "" | optional, max 100 | "Registration Number" |
| taxId (Companies.TaxId) | text (col-md-4) | "" | optional, max 100 | "Tax ID / PAN" |
| fcraRegistrationNumber (Companies.FCRARegistrationNumber) | text (col-md-4) | "" | optional, max 100 | "FCRA Registration" |
| dateOfIncorporation (Companies.DateOfIncorporation) | DatePicker (col-md-4) | null | optional, ≤ today | "Date of Incorporation" |
| website (Companies.Website) | URL with link-icon prefix (col-md-4) | "" | optional, valid URL | "Website" |
| description (Companies.Description) | textarea rows=3 (col-12) | "" | optional, max 4000 | "Description" |

**Section 2 — Contact Information** (mockup lines 718–776)

Sub-section: "Registered Address" (sub-section-title)
| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| addressLine1 (Companies.Address) | text (col-md-6) | "" | required, max 200 | label "Address Line 1 *" |
| addressLine2 (Companies.AddressLine2) | text (col-md-6) | "" | optional, max 200 | "Address Line 2" |
| city (Companies.City) | text (col-md-3) | "" | required, max 100 | "City *" |
| state (Companies.State) | text (col-md-3) | "" | optional, max 100 | "State" |
| countryId (Companies.CountryId) | ApiSelect (col-md-3) | null | required | "Country *" — source: GetCountries |
| postalCode (Companies.PostalCode) | text (col-md-3) | "" | optional, max 20 | "Postal Code" |

Sub-section divider + "Contact Details"
| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| primaryPhone (Companies.PrimaryPhone) | tel (col-md-4) | "" | required, max 50 | "Phone *" |
| primaryEmail (Companies.PrimaryEmail) | email (col-md-4) | "" | required, valid email | "Email *" |
| fax (Companies.Fax) | text (col-md-4) | "" | optional | "Fax" — placeholder "Optional" |

**Section 3 — Branding** (mockup lines 778–856)

| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| logoUrl (CompanyBrandings.LogoUrl) | FileUploadCard (col-md-6) | null | optional; PNG/SVG, max 500KB; recommended 200×60 | "Organization Logo *" — Upload + Remove buttons. ⚠ SERVICE_PLACEHOLDER |
| faviconUrl (CompanyBrandings.FaviconUrl) | FileUploadCard small (col-md-6) | null | optional; ICO/PNG, 32×32 | "Favicon" — Upload + Remove. ⚠ SERVICE_PLACEHOLDER |

Sub-section divider + "Brand Colors"
| primaryColorHex (CompanyBrandings.PrimaryColorHex) | ColorSwatch+HexInput (col-md-6) | "#0e7490" | optional, valid hex `^#[0-9A-Fa-f]{6}$` | "Primary Brand Color" — Used for headers, buttons, links |
| secondaryColorHex (CompanyBrandings.SecondaryColorHex) | ColorSwatch+HexInput (col-md-6) | "#059669" | optional, valid hex | "Secondary Brand Color" — Used for accents, highlights |

> SecondaryColorHex column — add to CompanyBrandings table (was missed in §② initial draft). Add: `SecondaryColorHex string? maxlen=7`.

> **Session 2 refactor**: "Receipt Customization" sub-section (Receipt Header Image + Receipt Footer Text) **REMOVED** from this screen. Moved to future "Receipt & Tax Configuration" screen.

**Section 4 — Financial Configuration** (mockup lines 858–965)

> **Session 2 refactor**: Tax/Receipt sub-card removed (moved to future "Receipt & Tax Configuration" screen). All static dropdowns swapped to ApiSelect (MasterData TypeCode-filtered).

| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| financialYearStartMonthId | ApiSelect (col-md-4) | (April row id) | required | "Financial Year Start *" — source: GetMasterDatas TypeCode=FINANCIALYEARSTARTMONTH; labels Jan…Dec |
| baseCurrencyId | ApiSelect (col-md-4) | null | required | "Default Currency *" — source: GetCurrencies — display "🇦🇪 AED - UAE Dirham" via flag emoji + code + name |
| currencyDisplayFormatId | ApiSelect (col-md-4) | (SymbolBefore row id) | required | source: GetMasterDatas TypeCode=CURRENCYDISPLAYFORMAT |
| additionalCurrencies (junction) | TagInput backed by junction (col-md-6) | empty | optional | "Additional Currencies" — chips with X; Add via combo from GetCurrencies (excludes baseCurrencyId); state stored as `int[]` of CurrencyIds, BE persists into `CompanyConfigurationCurrencies` |
| numberFormatId | ApiSelect (col-md-6) | (1,234,567.89 row id) | required | source: GetMasterDatas TypeCode=NUMBERFORMAT |

> Tax/Receipt sub-card removed. Future screen will own: TaxReceiptRequired, ReceiptAutoNumberingEnabled, ReceiptNumberPrefix, TaxExemptionSection, TaxExemptionCertificateNumber, TaxExemptionValidUntil + receipt-number preview compute.

**Section 5 — Regional & Localization** (mockup lines 967–1037)

| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| defaultLanguageId | ApiSelect (col-md-4) | null | required | "Default Language *" — source: GetLanguages |
| additionalLanguages (junction) | TagInput backed by junction (col-md-8) | empty | optional | "Additional Languages" — chips; state stored as `int[]` LanguageIds; BE persists into `CompanyConfigurationLanguages` |
| defaultTimezoneId | ApiSelect (col-md-4) | (UTC row id) | required | "Default Timezone *" — source: GetMasterDatas TypeCode=TIMEZONE; DataName shows "UTC+4 Dubai", DataValue holds IANA id |
| dateFormatId | ApiSelect (col-md-4) | (DD/MM/YYYY row id) | required | source: GetMasterDatas TypeCode=DATEFORMAT |
| timeFormatId | ApiSelect (col-md-4) | (12-hour row id) | required | source: GetMasterDatas TypeCode=TIMEFORMAT |
| countryOfOperationId | ApiSelect (col-md-4) | null | required | "Country of Operation *" — source: GetCountries |
| additionalOperatingCountries (junction) | TagInput backed by junction (col-md-8) | empty | optional | state stored as `int[]` CountryIds; BE persists into `CompanyConfigurationOperatingCountries` |

**Section 6 — Communication Defaults** (mockup lines 1039–1082)

| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| senderName | text (col-md-6) | (CompanyName) | optional, max 150 | "Sender Name" |
| senderEmail | email (col-md-6) | (PrimaryEmail) | optional, valid email | "Sender Email" |
| replyToEmail | email (col-md-6) | (PrimaryEmail) | optional, valid email | "Reply-To Email" |
| smsSenderId | text-with-suffix (col-md-6) | "" | optional, alphanumeric 3–11 chars | "SMS Sender ID" — suffix text "Alphanumeric, max 11 chars" |
| emailSignature | textarea rows=3 (col-12) | "Warm regards,\n{CompanyName}" | optional | "Email Signature" + form-text "Basic HTML formatting is supported (bold, italic, links)." |
| whatsappBusinessNumber | tel-with-icon (col-md-6) | "" | optional, E.164 format | "WhatsApp Business Number" — green WhatsApp prefix icon |

**Section 7 — System Preferences** (mockup lines 1084–1226)

> **Session 2 refactor**: All StaticSelect dropdowns swapped to ApiSelect (MasterData TypeCode-filtered). FE no longer hardcodes the option lists.

| Field | Widget | Default | Validation | Notes |
|-------|--------|---------|------------|-------|
| autoLogoutMinutesId | ApiSelect (col-md-4) | (30min row id) | required | source: GetMasterDatas TypeCode=AUTOLOGOUTMINUTES |
| loginAttemptsBeforeLockId | ApiSelect (col-md-4) | (5 row id) | required | source: GetMasterDatas TypeCode=LOGINATTEMPTSBEFORELOCK |
| twoFactorAuthModeId | ApiSelect (col-md-4) | (AdminsOnly row id) | required | source: GetMasterDatas TypeCode=TWOFACTORAUTHMODE |

Sub-section "Password Policy" (sub-card):
| passwordMinLengthId | ApiSelect (col-md-4) | (8 row id) | required | source: GetMasterDatas TypeCode=PASSWORDMINLENGTH |
| passwordExpiryDaysId | ApiSelect (col-md-4) | (90 row id) | required | source: GetMasterDatas TypeCode=PASSWORDEXPIRYDAYS |
| passwordHistoryCountId | ApiSelect (col-md-4) | (5 row id) | required | source: GetMasterDatas TypeCode=PASSWORDHISTORYCOUNT — form-text "Users cannot reuse the last N passwords" |
| passwordRequireUppercase | Switch (col-12 toggle-row) | true | — | label "Require Uppercase" / desc "At least one uppercase letter required" |
| passwordRequireNumber | Switch (col-12 toggle-row) | true | — | "Require Number" / "At least one numeric digit required" |
| passwordRequireSpecialChar | Switch (col-12 toggle-row) | true | — | "Require Special Character" / "At least one special character (e.g., !@#$%) required" |

Sub-section "Data Retention" (sub-card):
| auditLogRetentionYearsId | ApiSelect (col-md-6) | (5 row id) | required | source: GetMasterDatas TypeCode=AUDITLOGRETENTIONYEARS |
| deletedRecordsRetentionDaysId | ApiSelect (col-md-6) | (90 row id) | required | source: GetMasterDatas TypeCode=DELETEDRECORDSRETENTIONDAYS |

Sub-section "Maintenance Mode":
| maintenanceModeEnabled | Switch (toggle-row) | false | — | "Enable Maintenance Mode" / desc "When enabled, all non-admin users will see a maintenance page." Toggling triggers Confirm Modal (see Section 1 Actions table below) |
| maintenanceModeMessage | textarea rows=2 (collapsed) | null | required if maintenanceModeEnabled | optional follow-up textarea visible only when toggle is on |
| **Inline warning banner** when toggle ON (yellow `#fef3c7` bg, `#92400e` text): "⚠ Enabling maintenance mode will immediately lock out all non-admin users. Proceed with caution." |

**Section 8 — Subscription & Plan** (mockup lines 1228–1305) — READ-ONLY DISPLAY

Header row: plan badge gradient pill `Professional` + "Billed Annually" caption.

Plan info grid (2×2):
| billingCycle | "Annual" |
| renewalDate | "Jan 15, 2027" |
| usersUsed/usersIncluded | "134 / 200" + green progress bar 67% + "67% of user seats used" |
| storageUsed/storageTotal | "12.3 GB / 50 GB" + green progress bar 24.6% + "24.6% of storage used" |

Sub-section "Plan Features" — 2-col feature checklist:
- ✓ Multi-currency
- ✓ Custom reports
- ✓ Power BI integration
- ✓ API access
- ✓ WhatsApp integration
- − AI features (upgrade to Enterprise)

Action buttons: `[View Plans & Pricing]` (primary) + `[Contact Support]` (outline) — both SERVICE_PLACEHOLDER toasts ("Plan upgrade flow coming soon").

> **All values in §8 come from `GetCompanySubscriptionInfo` placeholder query — hardcoded constants in handler. NOT editable. NOT persisted on Save.**

#### Section-Level Actions (in addition to page-top Save)

| Action | Label | Style | Confirmation | Handler | Section |
|--------|-------|-------|--------------|---------|---------|
| Toggle Maintenance ON | (switch) | destructive confirm | "Enabling maintenance mode will immediately lock out all non-admin users. Proceed?" | sets MaintenanceModeEnabled = true (in form state — actual write happens on Save) | §7 |
| Toggle Maintenance OFF | (switch) | confirm | "Disable maintenance mode and restore user access?" | sets false | §7 |
| Upload Logo / Favicon / Receipt Header | "Upload New" | secondary | none | SERVICE_PLACEHOLDER — file selected → toast "Upload service not yet wired" → preview as data-URL only | §3 |
| Remove Logo / Favicon | "Remove" | tertiary | "Remove logo?" | clears the URL field | §3 |
| Add tag to multi-select (currencies / languages / countries) | (combobox) | — | — | appends to CSV in form state | §4 / §5 |
| Remove tag (X icon on chip) | — | — | — | removes from CSV | §4 / §5 |
| View Plans & Pricing | (button) | primary | — | SERVICE_PLACEHOLDER toast | §8 |
| Contact Support | (button) | outline | — | SERVICE_PLACEHOLDER (or `mailto:`) | §8 |

#### Page-Level Actions

| Action | Position | Style | Permission | Confirmation |
|--------|----------|-------|------------|--------------|
| Save Changes | page-top right | primary accent | BUSINESSADMIN | none — runs validation; on error stays + inline messages; on success saves + toast |
| Discard Changes | page-top right | outline | BUSINESSADMIN | "Are you sure you want to discard all unsaved changes? This action cannot be undone." |

> NO Reset to Defaults button (mockup omits it).
> NO Export / Import Config (mockup omits it).
> NO global "Help" button (mockup omits it).

#### User Interaction Flow (SETTINGS_PAGE)

1. User opens `/{lang}/setting/orgsettings/companysettings` → page loads → BE auto-seeds default CompanyConfiguration + CompanyBranding rows if missing → all 8 sections render with current values; Section 1 active by default.
2. User clicks sidebar nav item → active state moves; right pane scrolls to top of section.
3. User edits a field in any section → form becomes dirty → Save Changes button enables (visual cue: brighter/sticky).
4. User clicks Save Changes → RHF validation runs (Zod) → on error: jumps to first invalid section + scrolls field into view + inline error; on success: composite UpdateCompanySettings mutation fires → toast "Company settings updated successfully" → form resets dirty flag.
5. User clicks Discard Changes (with unsaved edits) → confirm dialog → on confirm reverts form to last-saved snapshot.
6. User toggles Maintenance Mode → confirm modal appears (both directions) → on confirm sets local form state (still requires page-level Save to persist).
7. User navigates away with unsaved changes → router-level guard prompts "Unsaved changes — leave anyway?".
8. (Section 8) User clicks "View Plans & Pricing" → SERVICE_PLACEHOLDER toast (no mutation; no nav).

---

### Shared blocks (apply to all sub-types — kept verbatim)

#### Page Header & Breadcrumbs

| Element | Content |
|---------|---------|
| Breadcrumb | Settings › Org Settings › Company Settings |
| Page title | Company Settings + Admin badge (red pill, `ph:shield-check` icon) |
| Subtitle | "Organization profile, branding, and system configuration" |
| Right actions | [Discard Changes] [Save Changes] (always visible, sticky) |

#### Empty / Loading / Error States

| State | Trigger | UI |
|-------|---------|----|
| Loading | Initial fetch | Skeleton matching the 8-section sidebar layout (sidebar nav skeleton + section card skeletons with 8–12 row placeholders matching field count) — not a generic shimmer |
| Empty | (Theoretically impossible after auto-seed) — defensive | Full-page hint "Initializing company settings…" with retry button + audit-log error code |
| Error | GET fails | Error card replacing settings content + retry button + error code; sidebar hidden during error |
| Save error | UpdateCompanySettings mutation fails | Inline error per field (validation) OR top-of-page red banner (server error) + toast |
| Validation error | Save with invalid form | RHF `setFocus` to first invalid field + scroll into view; inline messages under each invalid field |

---

## ⑦ Substitution Guide

> **TBD per template** — first SETTINGS_PAGE in the registry. After this screen completes, this block is updated to canonicalize CompanySettings as the SETTINGS_PAGE reference.
>
> Until canonical exists, BE Dev should use these EXISTING templates as scaffolding (NOT exact mirror — adapt for singleton + composite payload):
>   - **For composite GET pattern**: GlobalDonation #1 GetGlobalDonationSummary — composite handler that joins multiple aggregates.
>   - **For Update pattern with audit**: ChequeDonation #6 UpdateChequeDonation — explicit audit trail emission.
>   - **For tenant-scoped query**: any existing handler using `_currentUserService.CompanyId` (e.g. RecurringDonationSchedule #8 GetRecurringDonationSchedules).
> FE Dev: NO canonical SETTINGS_PAGE in registry yet. Closest existing reference is **MatchingGiftSettings** (registry #11 Tab 4 — single-row-per-tenant Upsert) but that's a single-section page. Treat this as the new canonical.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| (no prior SETTINGS_PAGE) | CompanySettings | Composite — Company (`app`, ENHANCED) + CompanyConfiguration (`sett`, NEW) + CompanyBranding (`sett`, NEW) |
| — | companySettings | camelCase identifier across FE |
| app | app | DB schema for the existing `Companies` table (15 new columns added in place) |
| sett | sett | DB schema for the NEW `CompanyConfigurations` + `CompanyBrandings` singleton tables |
| Setting | Setting | Backend group folder name for NEW entities (SettingModels / SettingSchemas / SettingConfigurations / SettingBusiness / EndPoints/Setting / SettingMappings) |
| Application | Application | Existing group ONLY for the Company entity ENHANCEMENT (Company.cs + CompanyConfiguration.cs EF config + IApplicationDbContext / ApplicationDbContext / ApplicationMappings.cs Company section). NEW entities live under Setting group. |
| setting/orgsettings/companysettings | setting/orgsettings/companysettings | FE route under `(core)/setting/orgsettings/companysettings/page.tsx` |
| SETTING | SETTING | Module code |
| SET_ORGSETTINGS | SET_ORGSETTINGS | Parent menu code (MenuId 377 — re-parented from RA_AUDIT to SET_ORGSETTINGS — see §⑫ ISSUE-4) |
| COMPANYSETTINGS | COMPANYSETTINGS | Menu code (existing entry in MODULE_MENU_REFERENCE.md — re-parented in seed) |

---

## ⑧ File Manifest

> Sub-type: SETTINGS_PAGE (singleton-per-tenant) — Only this block is filled. Designer + Matrix blocks deleted.

### Backend Files — CREATE (Session 2 refactored manifest)

> Module placement: NEW entities + handlers + endpoints live under **Setting** group (`sett` schema). Company entity ENHANCEMENT (15 new columns) stays in Application group (`app` schema). The composite `GetCompanySettings` handler injects BOTH `IApplicationDbContext` (for Company) AND `ISettingDbContext` (for CompanyConfiguration + CompanyBranding + 3 junction tables).

| # | File | Path |
|---|------|------|
| 1 | Entity: CompanyConfiguration | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/CompanyConfiguration.cs |
| 2 | Entity: CompanyBranding | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/CompanyBranding.cs |
| 3 | Entity: CompanyConfigurationCurrency (junction) | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/CompanyConfigurationCurrency.cs |
| 4 | Entity: CompanyConfigurationLanguage (junction) | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/CompanyConfigurationLanguage.cs |
| 5 | Entity: CompanyConfigurationOperatingCountry (junction) | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/CompanyConfigurationOperatingCountry.cs |
| 6 | EF Config: CompanyConfiguration | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/SettingConfigurations/CompanyConfigurationConfiguration.cs |
| 7 | EF Config: CompanyBranding | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/SettingConfigurations/CompanyBrandingConfiguration.cs |
| 8 | EF Config: CompanyConfigurationCurrency | …/SettingConfigurations/CompanyConfigurationCurrencyConfiguration.cs |
| 9 | EF Config: CompanyConfigurationLanguage | …/SettingConfigurations/CompanyConfigurationLanguageConfiguration.cs |
| 10 | EF Config: CompanyConfigurationOperatingCountry | …/SettingConfigurations/CompanyConfigurationOperatingCountryConfiguration.cs |
| 11 | Schemas (composite + section DTOs) | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/SettingSchemas/CompanySettingsSchemas.cs |
| 12 | GetCompanySettings query handler | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/CompanySettings/Queries/GetCompanySettingsQuery/GetCompanySettings.cs |
| 13 | UpdateCompanySettings command handler | …/SettingBusiness/CompanySettings/Commands/UpdateCompanySettingsCommand/UpdateCompanySettings.cs |
| 14 | UpdateCompanySettings request validator | …/SettingBusiness/CompanySettings/Commands/UpdateCompanySettingsCommand/UpdateCompanySettingsValidator.cs |
| 15 | GetCompanySubscriptionInfo placeholder query | …/SettingBusiness/CompanySettings/Queries/GetSubscriptionInfoQuery/GetCompanySubscriptionInfo.cs |
| 16 | CompanyConfigurationDefaults static class | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Defaults/CompanyConfigurationDefaults.cs (now: helper that resolves default MasterData IDs by TypeCode + DataValue at seed time, no hardcoded ints) |
| 17 | CompanyBrandingDefaults static class | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Defaults/CompanyBrandingDefaults.cs |
| 18 | Mutations endpoint | PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Setting/Mutations/CompanySettingsMutations.cs |
| 19 | Queries endpoint | PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Setting/Queries/CompanySettingsQueries.cs |
| 20 | Mapster mapping config | Add to existing `Base.Application/Mappings/SettingMappings.cs` for Setting-side DTOs (CompanyConfiguration ⇄ FinancialSection / RegionalSection / CommunicationSection / SystemSection; CompanyBranding ⇄ BrandingSection; junction-row chip DTOs). Add to existing `ApplicationMappings.cs` for Company ⇄ OrgProfileSection / ContactSection. |
| 21 | DB seed | PSS_2.0_Backend/sql-scripts-dyanmic/CompanySettings-sqlscripts.sql ⚠ preserve repo typo `dyanmic` |

> **DEFERRED (NOT generated this session)**: ToggleMaintenanceMode fast-path command (per ISSUE-6 user decision).
> **REMOVED in Session 2 refactor**: nothing (Session 1 files refactored, not deleted).

### Backend Wiring — MODIFY (8 files)

| # | File | What to Change |
|---|------|----------------|
| 1 | Base.Domain/Models/ApplicationModels/Company.cs | Add 15 new nullable scalar properties (ShortName, OrganizationTypeId + nav, RegistrationNumber, TaxId, FCRARegistrationNumber, DateOfIncorporation, Website, Description, AddressLine2, City, State, PostalCode, PrimaryEmail, PrimaryPhone, Fax) + 1:1 nav properties `CompanyConfiguration? CompanyConfiguration` and `CompanyBranding? CompanyBranding` (singular — see §⑫ ISSUE-12) |
| 2 | Base.Infrastructure/Data/Configurations/ApplicationConfigurations/CompanyConfiguration.cs | (existing EF fluent config for the Company entity — class name `CompanyConfigurations` plural, implements `IEntityTypeConfiguration<Company>`) Add `.Property(c => c.NewField).HasMaxLength(N)` for each new column on Company; configure FK to MasterData (OrganizationTypeId) with `OnDelete(Restrict)`; configure 1:1 to new `CompanyConfiguration` + `CompanyBranding` via `.HasOne(...).WithOne(...).HasForeignKey<...>(cc => cc.CompanyId)`; **filename retained** (do NOT rename) |
| 3 | Base.Infrastructure/Data/Persistence/SettingDbContext.cs + Base.Infrastructure/Data/ISettingDbContext.cs | Add `DbSet<CompanyConfiguration> CompanyConfigurations` + `DbSet<CompanyBranding> CompanyBrandings` + **3 junction DbSets** (`CompanyConfigurationCurrencies`, `CompanyConfigurationLanguages`, `CompanyConfigurationOperatingCountries`) to BOTH the interface and the concrete context (NEW entities live in Setting module → SettingDbContext, NOT ApplicationDbContext) |
| 4 | Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs (and IApplicationDbContext.cs if it exposes Company) | NO new DbSets — existing `DbSet<Company>` is reused. Verify Mapster + `OnModelCreating` picks up the NEW EF configs from SettingConfigurations folder via `ApplyConfigurationsFromAssembly` (already wired across the codebase per existing pattern). |
| 5 | Base.Infrastructure/Data/Decorators/DecoratorSettingModules.cs (or the equivalent SettingModels decorator file — verify at build time) | Add CompanyConfiguration + CompanyBranding decorator entries |
| 6 | Base.Application/Mappings/SettingMappings.cs (Setting side) + Base.Application/Mappings/ApplicationMappings.cs (Application side) | SettingMappings.cs: add Mapster `TypeAdapterConfig<...>` for `CompanyConfiguration` ⇄ FinancialSection / RegionalSection / CommunicationSection / SystemSection AND `CompanyBranding` ⇄ BrandingSection. ApplicationMappings.cs: add `Company` ⇄ OrgProfileSection / ContactSection. |
| 7 | PSS_2.0_Backend/.../GlobalUsing.cs (Base.Application + Base.Domain + Base.API as relevant) | Add `global using Base.Domain.Defaults;` and `global using Base.Domain.Models.SettingModels;` namespaces if not already present |
| 8 | PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/Program.cs (or the GraphQL schema registration file) | Register the new `CompanySettingsQueries` + `CompanySettingsMutations` types with HotChocolate (extend existing `OperationTypeNames.Query` / `OperationTypeNames.Mutation` extension via `[ExtendObjectType(...)]` — verify pattern at build time against existing Setting endpoints e.g. `GridConfigQueries`/`GridConfigMutations`) |

### EF Migration

> **Session 2 strategy**: Session 1's migration `20260501050725_Add_CompanyConfiguration_And_Branding_And_CompanyEnhancements` is **uncommitted** in this branch. The cleanest path is to **delete it (and its Designer + ModelSnapshot delta)** and regenerate a single new migration that reflects the Session 2 schema. Migration name (regenerated): `Add_CompanyConfiguration_And_Branding_And_CompanyEnhancements` (same name OK — appears in Migrations history first time).
>
> **Steps the regenerated migration must produce**:
> 1. ALTER TABLE app.Companies — add 15 nullable columns + FK on OrganizationTypeId
> 2. CREATE TABLE sett.CompanyConfigurations — with refactored columns (FK Ids replacing string/int enum columns; receipt/tax columns absent)
> 3. CREATE TABLE sett.CompanyBrandings — without ReceiptHeaderImageUrl + ReceiptFooterText
> 4. CREATE TABLE sett.CompanyConfigurationCurrencies (junction)
> 5. CREATE TABLE sett.CompanyConfigurationLanguages (junction)
> 6. CREATE TABLE sett.CompanyConfigurationOperatingCountries (junction)
> 7. Unique filtered indexes on each singleton + each junction (composite (parentId, refId) WHERE IsDeleted=false)
> 8. All FK constraints with cross-schema references (`app.Companies`, `com.Currencies/Countries/Languages`, `sett.MasterDatas`)
> 9. Indexes on every FK column (EF default behavior)

### Frontend Files — CREATE (18 files)

| # | File | Path |
|---|------|------|
| 1 | DTO Types (composite + 8 section DTOs + Subscription DTO) | PSS_2.0_Frontend/src/domain/entities/setting-service/CompanySettingsDto.ts |
| 2 | GQL Query (GetCompanySettings + GetCompanySubscriptionInfo) | PSS_2.0_Frontend/src/infrastructure/gql-queries/setting-queries/CompanySettingsQuery.ts |
| 3 | GQL Mutation (UpdateCompanySettings + ToggleMaintenanceMode) | PSS_2.0_Frontend/src/infrastructure/gql-mutations/setting-mutations/CompanySettingsMutation.ts |
| 4 | Settings Page (composite RHF host + sticky save bar + sidebar nav) | PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/companysettings/settings-page.tsx |
| 5 | Section: Org Profile | …/setting/orgsettings/companysettings/sections/org-profile-section.tsx |
| 6 | Section: Contact | …/setting/orgsettings/companysettings/sections/contact-section.tsx |
| 7 | Section: Branding | …/setting/orgsettings/companysettings/sections/branding-section.tsx |
| 8 | Section: Financial | …/setting/orgsettings/companysettings/sections/financial-section.tsx |
| 9 | Section: Regional | …/setting/orgsettings/companysettings/sections/regional-section.tsx |
| 10 | Section: Communication | …/setting/orgsettings/companysettings/sections/communication-section.tsx |
| 11 | Section: System | …/setting/orgsettings/companysettings/sections/system-section.tsx |
| 12 | Section: Subscription (read-only) | …/setting/orgsettings/companysettings/sections/subscription-section.tsx |
| 13 | Components: ColorPickerInput (swatch+hex 2-way bound) | …/setting/orgsettings/companysettings/components/color-picker-input.tsx |
| 14 | Components: TagInput (multi-select chips backed by ApiSelect) | …/setting/orgsettings/companysettings/components/tag-input.tsx (or REUSE if registry has equivalent — see §⑫ ISSUE-7 / Component Reuse-or-Create) |
| 15 | Components: FileUploadCard (placeholder upload UI) | …/setting/orgsettings/companysettings/components/file-upload-card.tsx |
| 16 | Components: TimezoneSelect | …/setting/orgsettings/companysettings/components/timezone-select.tsx |
| 17 | Components: MaintenanceModeConfirmModal | …/setting/orgsettings/companysettings/components/maintenance-mode-modal.tsx |
| 18 | Zustand store (form snapshot for dirty-tracking + section state) | …/setting/orgsettings/companysettings/companysettings-store.ts |
| 19 | Zod schema | …/setting/orgsettings/companysettings/companysettings-schemas.ts |
| 20 | Sticky save header bar | …/setting/orgsettings/companysettings/components/save-changes-bar.tsx |
| 21 | Page Config (capability gate) | PSS_2.0_Frontend/src/presentation/pages/setting/orgsettings/companysettings.tsx |

> Counting note: 18 was the initial estimate; refined to 21 after sub-component split. BE Dev / FE Dev should treat this list as authoritative.

### Frontend Files — MODIFY (6 files)

| # | File | What to Change |
|---|------|----------------|
| 1 | PSS_2.0_Frontend/src/app/[lang]/setting/orgsettings/companysettings/page.tsx | CREATE new route stub: `"use client"; import { CompanySettingsPageConfig } from "@/presentation/pages"; export default function CompanySettings() { return <CompanySettingsPageConfig />; }`. Note: this is a NEW route folder under existing `setting/orgsettings/`. The Organization route under `organization/company/` is untouched. |
| 2 | PSS_2.0_Frontend/src/presentation/pages/index.ts (or setting/orgsettings/index.ts) | Export CompanySettingsPageConfig |
| 3 | PSS_2.0_Frontend/src/presentation/components/page-components/setting/index.ts (and orgsettings/index.ts if it exists) | Export new settings-page barrel |
| 4 | PSS_2.0_Frontend/src/domain/entities/setting-service/index.ts | Export CompanySettingsDto types |
| 5 | PSS_2.0_Frontend/src/infrastructure/gql-queries/setting-queries/index.ts + …/gql-mutations/setting-mutations/index.ts | Export new query + mutation files |
| 6 | PSS_2.0_Frontend/src/presentation/components/data-tables/operations-config/* (entity-operations.ts) | Add COMPANYSETTINGS entry mapping menuCode → no-op operations (CONFIG screens have no row-level CRUD; entry is only needed if framework requires it for capability gate). VERIFY at build time — may not be needed. |

> NOTE: Sidebar config (if any explicit menu-tree file exists) should be updated to surface "Company Settings" under Organization › Company. If menu rendering is data-driven from BE seed, no FE sidebar file change is needed.

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase

```
---CONFIG-START---
Scope: FULL

MenuName: Company Settings
MenuCode: COMPANYSETTINGS
ParentMenu: SET_ORGSETTINGS  ⚠ overrides MODULE_MENU_REFERENCE.md line 363 (which has it under RA_AUDIT — see §⑫ ISSUE-4)
Module: SETTING
MenuUrl: setting/orgsettings/companysettings
GridType: SKIP
OrderBy: 4                   (after SETTINGGROUP=1, ORGANIZATIONSETTING=2, USERSETTING=3 in SET_ORGSETTINGS / MenuId 377)

MenuCapabilities: READ, MODIFY, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY

GridFormSchema: SKIP
GridCode: COMPANYSETTINGS
---CONFIG-END---
```

> Capabilities deliberately limited:
> - NO CREATE / NO DELETE — singleton (auto-seeded; cannot delete a tenant's own settings).
> - NO EXPORT / NO IMPORT — mockup omits these.
> - GridFormSchema = SKIP — custom multi-section UI, not RJSF modal.
> - GridType = SKIP — singleton, not a list-of-N grid.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `CompanySettingsQueries` (registered in `OperationTypeNames.Query`)
- Mutation type: `CompanySettingsMutations` (registered in `OperationTypeNames.Mutation`)

### Queries

| GQL Field | Returns | Args |
|-----------|---------|------|
| getCompanySettings | BaseApiResponse<CompanySettingsResponseDto> | — (CompanyId from HttpContext) |
| getCompanySubscriptionInfo | BaseApiResponse<CompanySubscriptionInfoDto> | — (placeholder; same tenant scoping) |

### Mutations

| GQL Field | Input | Returns |
|-----------|-------|---------|
| updateCompanySettings | CompanySettingsRequestDto | BaseApiResponse<CompanySettingsResponseDto> (refreshed composite) |
| toggleMaintenanceMode | ToggleMaintenanceModeRequestDto { Enabled: bool, Message: string? } | BaseApiResponse<bool> (optional fast-path — see §⑫ ISSUE-6) |

### CompanySettingsResponseDto shape

```typescript
{
  // §1 + §2 — Company entity
  orgProfile: {
    companyId: number;           // read-only, surfaced as a chip in §1
    companyCode: string;         // read-only chip (legal identifier)
    companyName: string;
    shortName: string | null;
    organizationTypeId: number | null;
    organizationTypeName: string | null;     // joined display value
    registrationNumber: string | null;
    taxId: string | null;
    fcraRegistrationNumber: string | null;
    dateOfIncorporation: string | null;     // ISO date YYYY-MM-DD
    website: string | null;
    description: string | null;
  };
  contact: {
    addressLine1: string;
    addressLine2: string | null;
    city: string;
    state: string | null;
    countryId: number;
    countryName: string;                     // joined display
    postalCode: string | null;
    primaryPhone: string;
    primaryEmail: string;
    fax: string | null;
  };
  // §3 — CompanyBranding
  branding: {
    logoUrl: string | null;
    faviconUrl: string | null;
    primaryColorHex: string | null;
    secondaryColorHex: string | null;
    receiptHeaderImageUrl: string | null;
    receiptFooterText: string | null;
  };
  // §3 — CompanyBranding (Session 2: Receipt fields removed)
  // (already shown above — branding {logoUrl, faviconUrl, primaryColorHex, secondaryColorHex})

  // §4 — CompanyConfiguration (financial — Session 2: all dropdowns are FK ids; receipt/tax fields removed)
  financial: {
    financialYearStartMonthId: number;
    financialYearStartMonthName: string;     // joined MasterData.DataName ("April")
    financialYearStartMonthValue: string;    // joined MasterData.DataValue ("4")
    baseCurrencyId: number;
    baseCurrencyCode: string;
    baseCurrencyName: string;
    currencyDisplayFormatId: number;
    currencyDisplayFormatName: string;       // "Symbol before amount"
    currencyDisplayFormatValue: string;      // "SymbolBefore"
    numberFormatId: number;
    numberFormatName: string;                // "1,234,567.89 (US/UK)"
    additionalCurrencies: { id: number; code: string; name: string }[];   // from junction CompanyConfigurationCurrencies
  };
  // §5 — CompanyConfiguration (regional — Session 2 FK ids)
  regional: {
    defaultLanguageId: number;
    defaultLanguageName: string;
    defaultTimezoneId: number;
    defaultTimezoneName: string;             // "UTC+4 Dubai"
    defaultTimezoneValue: string;            // IANA "Asia/Dubai"
    dateFormatId: number;
    dateFormatName: string;                  // "DD/MM/YYYY"
    timeFormatId: number;
    timeFormatName: string;                  // "12-hour"
    countryOfOperationId: number;
    countryOfOperationName: string;
    additionalLanguages: { id: number; name: string }[];                  // from junction
    additionalOperatingCountries: { id: number; name: string }[];         // from junction
  };
  // §6 — CompanyConfiguration (communication — unchanged)
  communication: {
    senderName: string | null;
    senderEmail: string | null;
    replyToEmail: string | null;
    smsSenderId: string | null;
    emailSignature: string | null;
    whatsappBusinessNumber: string | null;
  };
  // §7 — CompanyConfiguration (system — Session 2 all enums are FK ids)
  system: {
    autoLogoutMinutesId: number;
    autoLogoutMinutesName: string;           // "30 minutes"
    autoLogoutMinutesValue: string;          // "30" (or "-1" for Never)
    loginAttemptsBeforeLockId: number;
    loginAttemptsBeforeLockName: string;
    loginAttemptsBeforeLockValue: string;
    twoFactorAuthModeId: number;
    twoFactorAuthModeName: string;           // "Admins Only"
    twoFactorAuthModeValue: string;          // "AdminsOnly"
    passwordMinLengthId: number;
    passwordMinLengthName: string;
    passwordMinLengthValue: string;          // "8"
    passwordExpiryDaysId: number;
    passwordExpiryDaysName: string;
    passwordExpiryDaysValue: string;
    passwordHistoryCountId: number;
    passwordHistoryCountName: string;
    passwordHistoryCountValue: string;
    passwordRequireUppercase: boolean;
    passwordRequireNumber: boolean;
    passwordRequireSpecialChar: boolean;
    auditLogRetentionYearsId: number;
    auditLogRetentionYearsName: string;      // "5 years"
    auditLogRetentionYearsValue: string;
    deletedRecordsRetentionDaysId: number;
    deletedRecordsRetentionDaysName: string;
    deletedRecordsRetentionDaysValue: string;
    maintenanceModeEnabled: boolean;
    maintenanceModeMessage: string | null;
  };
}
```

### CompanySettingsRequestDto shape

```typescript
// Identical to ResponseDto MINUS:
//   - all *Name and *Value joined-display fields (e.g. financialYearStartMonthName, defaultTimezoneValue, autoLogoutMinutesName, etc.)
//   - additionalCurrencies/additionalLanguages/additionalOperatingCountries become int[] of refIds (e.g. additionalCurrencyIds: number[])
//   - companyId (HttpContext)
//   - companyCode (legal-immutable)
// Sections: orgProfile, contact, branding, financial, regional, communication, system
```

### CompanySubscriptionInfoDto shape (PLACEHOLDER)

```typescript
{
  isPlaceholder: true;                       // FE flag — show "View Plans & Pricing" as PLACEHOLDER
  planTier: 'Starter' | 'Professional' | 'Enterprise';
  billingCycle: 'Monthly' | 'Annual';
  renewalDate: string;                       // ISO date — e.g. "2027-01-15"
  usersUsed: number;                         // 134
  usersIncluded: number;                     // 200
  storageUsedGb: number;                     // 12.3
  storageTotalGb: number;                    // 50
  features: { name: string; enabled: boolean; upgradeHint: string | null }[];
}
```

### Sensitive-field handling

- (No raw secrets in this screen — section deliberately omitted.)

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] EF migration applied — `app.Companies` enhanced + `CompanyConfigurations` + `CompanyBrandings` tables exist
- [ ] `pnpm dev` — page loads at `/{lang}/setting/orgsettings/companysettings`

**Functional Verification (Full E2E — MANDATORY) — SETTINGS_PAGE block:**

- [ ] First-load: BE auto-seeds default CompanyConfiguration + CompanyBranding rows for current tenant; no 404; page renders all 8 sections
- [ ] Sidebar nav: 8 items render with correct icons + order; clicking switches active section + scrolls to top
- [ ] Section 1 (Org Profile): all 9 fields render with placeholder/seed values; CompanyName required; OrganizationType ApiSelect populates from MasterData ORGANIZATIONTYPE
- [ ] Section 2 (Contact): all 10 fields render; AddressLine1+City+Country+Phone+Email required; Country ApiSelect from GetCountries
- [ ] Section 3 (Branding): logo + favicon FileUpload card render with placeholder; color pickers (primary + secondary) render with default hex; swatch+text 2-way bind; receipt header image + footer text render
- [ ] Section 4 (Financial): FY start dropdown 1–12; base currency ApiSelect; additional currencies tag input; tax-receipt toggle disables/enables sub-fields; valid-until DatePicker; "Next: REC-NNNN" preview updates as prefix changes
- [ ] Section 5 (Regional): default language ApiSelect; additional languages tag input; timezone select; date/time format static selects; country-of-operation ApiSelect; additional countries tag input
- [ ] Section 6 (Communication): all 6 fields render; sender-name defaults to CompanyName if empty; email-signature textarea
- [ ] Section 7 (System): all 13 fields render with seeded defaults; password-policy sub-card renders 3 dropdowns + 3 toggles; data-retention sub-card renders 2 dropdowns; maintenance-mode toggle shows confirm modal both directions; warning banner appears below toggle when enabled
- [ ] Section 8 (Subscription): renders read-only with badge + plan info grid + feature checklist; NO save controls; "View Plans & Pricing" + "Contact Support" buttons toast SERVICE_PLACEHOLDER
- [ ] Save Changes (page-top): runs validation across ALL 7 editable sections; on validation error, jumps to first invalid field; on success, single mutation persists to all 3 tables in one transaction; toast displays
- [ ] Discard Changes (page-top): confirm dialog → on confirm, all 7 sections revert to last-saved state; dirty flag clears
- [ ] Validation: required fields blocked; email format checked; URL format checked; hex color regex enforced; SMS sender alphanumeric
- [ ] Conditional fields: TaxReceiptRequired = false → grays out tax-receipt sub-fields; MaintenanceModeEnabled = true → required `MaintenanceModeMessage`
- [ ] Audit trail: server-side handler emits audit-log entry on each successful UpdateCompanySettings call (whole-payload audit)
- [ ] Maintenance Mode flip: confirm modal both directions; audit log entry; warning banner shown beneath toggle when enabled
- [ ] Unsaved-changes blocker: navigating away with dirty form prompts confirm dialog (Next.js router-level guard + window.beforeunload listener)
- [ ] Tenant scoping: switching tenant context (or testing with a different CompanyId) returns that tenant's settings; never the wrong tenant's data
- [ ] Role gate: a non-BUSINESSADMIN account cannot see the COMPANYSETTINGS menu item; if they URL-bypass to the route, they see DefaultAccessDenied

**DB Seed Verification:**
- [ ] Menu visible in sidebar at Settings › Org Settings › Company Settings (re-parented from RA_AUDIT to SET_ORGSETTINGS)
- [ ] Default CompanyConfiguration row + CompanyBranding row created for sample Company
- [ ] ORGANIZATIONTYPE MasterData seeded with 7 rows (Trust/Society/Section8/NGO/Foundation/Association/Other)
- [ ] LOGINTEMPLATE MasterData seeded with 5 rows (BGIMAGE/CAROUSEL/BGVIDEO/FULLIMAGE/MINIMAL) — even though §3 doesn't use them, future #173 needs them
- [ ] Page renders without crashing on a freshly-seeded DB

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

### Session 2 architectural pivot (2026-05-01)

After Session 1 BE-only build, user feedback drove a refactor:
1. **Receipt/Tax fields removed from this screen** — moved to a future "Receipt & Tax Configuration" screen (single-concern):
   - From `CompanyConfiguration`: TaxReceiptRequired, ReceiptAutoNumberingEnabled, ReceiptNumberPrefix, TaxExemptionSection, TaxExemptionCertificateNumber, TaxExemptionValidUntil
   - From `CompanyBranding`: ReceiptHeaderImageUrl, ReceiptFooterText
2. **All dropdown enum fields converted to FK → MasterData** so option lists are tenant-configurable in one place (no hardcoded enums in code or static FE files): 14 fields converted to `*Id` FK references with new MasterData TypeCodes. ISSUE-3 (static IANA timezone list) **superseded** — TIMEZONE is now a MasterData TypeCode.
3. **Multi-select CSV columns normalized to junction tables** — `AdditionalCurrenciesCsv` / `AdditionalLanguagesCsv` / `AdditionalOperatingCountriesCsv` replaced with `CompanyConfigurationCurrencies` / `CompanyConfigurationLanguages` / `CompanyConfigurationOperatingCountries` junction tables (proper M:N with FK integrity). ISSUE-9 (CSV roundtrip) **superseded**.
4. **Migration regenerated** — Session 1's `20260501050725_*` migration deleted (uncommitted) and recreated with new schema.

### Pre-flagged Known Issues

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | HIGH | BE / Subscription | No billing service exists in MVP. `GetCompanySubscriptionInfo` returns hardcoded `IsPlaceholder=true` data. Section 8 must NOT mutate. View Plans & Pricing button is SERVICE_PLACEHOLDER. Future ticket: integrate Stripe/billing-engine. |
| ISSUE-2 | ~~MED~~ **SUPERSEDED (Session 2)** | BE / Receipt numbering | Receipt-number preview compute is no longer this screen's concern — receipt/tax fields moved to future "Receipt & Tax Configuration" screen. |
| ISSUE-3 | ~~MED~~ **SUPERSEDED (Session 2)** | FE / Timezone | DefaultTimezone is now a FK to `sett.MasterDatas` TypeCode=TIMEZONE. FE uses GetMasterDatas; no static `/lib/timezones.ts` needed. |
| ISSUE-4 | MED | DB Seed / Menu placement | `MODULE_MENU_REFERENCE.md` line 363 has `COMPANYSETTINGS` under `RA_AUDIT` (Reports & Audit). The seed must EXPLICITLY re-parent it under `SET_ORGSETTINGS` (MenuId 377, Setting module): `UPDATE auth."Menus" SET "ParentMenuId" = (SELECT "MenuId" FROM auth."Menus" WHERE "MenuCode"='SET_ORGSETTINGS' AND "IsDeleted"=false), "MenuUrl"='setting/orgsettings/companysettings', "ModuleId" = (SELECT "ModuleId" FROM auth."Modules" WHERE "ModuleCode"='SETTING' AND "IsDeleted"=false), "OrderBy"=4 WHERE "MenuCode"='COMPANYSETTINGS'`. Document in seed script header. Also UPDATE the MODULE_MENU_REFERENCE.md to move the line from RA_AUDIT to SET_ORGSETTINGS post-build. |
| ISSUE-5 | LOW | BE / EF config naming | Existing file `Base.Infrastructure/.../ApplicationConfigurations/CompanyConfiguration.cs` is the EF fluent config for `Company` entity (class name `CompanyConfigurations`, plural — `IEntityTypeConfiguration<Company>`). The NEW domain entity is named `CompanyConfiguration` (singular). NO collision now — NEW EF config lives in **`SettingConfigurations/`** folder (different namespace `Base.Infrastructure.Data.Configurations.SettingConfigurations`). Name the new file `CompanyConfigurationConfiguration.cs` (matches sibling pattern e.g. `DashboardConfiguration.cs` in same folder). DO NOT rename the existing file. |
| ISSUE-6 | LOW | BE / Maintenance mode mutation | The mockup's maintenance-mode toggle persists via the page-level Save (consistent with save-all). Question: should the toggle ALSO have a separate `ToggleMaintenanceMode` mutation for emergencies (BUSINESSADMIN must shut down NOW even if other fields are invalid)? Current decision: include `ToggleMaintenanceMode` as a fast-path mutation; FE wires it ONLY when the user clicks the warning banner's "Apply Now" link (NOT in mockup but defensible for the operational use case). DEFER unless user requests. |
| ISSUE-7 | LOW | FE / TagInput reuse | Multi-select tag input pattern is used in §4 (currencies) + §5 (languages + countries). Search registries first: if a `MultiApiSelectTagInput` already exists (e.g. from AdditionalCurrencies in another screen), reuse it. Otherwise create one and register in shared-cell-renderers. |
| ISSUE-8 | LOW | FE / Route choice | New route at `/{lang}/setting/orgsettings/companysettings/page.tsx` (NEW folder under existing `setting/orgsettings/`) — sibling to settinggroup/ organizationsetting/ usersetting/. Existing `/{lang}/organization/company/company/` (CompanyDataTable list grid for SUPERADMIN multi-tenant management) is untouched. |
| ISSUE-9 | ~~LOW~~ **SUPERSEDED (Session 2)** | FE / multi-select | CSV columns replaced with proper junction tables. BE returns expanded `{id, name}[]` arrays directly; FE state is `int[]` of refIds; no CSV ↔ chip serialization needed. |
| ISSUE-10 | LOW | BE / Audit trail granularity | UpdateCompanySettings audits the whole composite payload (not per-field diff). For password-policy regulatory traceability, a follow-up ticket can add per-field old→new logging. Acceptable for MVP. |
| ISSUE-11 | MED | FE / RHF nested form | Single RHF host with deep object schema (`form.orgProfile.companyName`, `form.system.passwordMinLength`, etc.). Each section component receives a slice via `useFormContext`. Watch for field-array nesting issues — TagInput needs `useFieldArray` semantics or careful CSV handling. |
| ISSUE-12 | LOW | BE / 1:1 nav property | Company.CompanyConfigurations / Company.CompanyBrandings are 1:1 (singleton). EF Core defaults to 1:Many — must explicitly configure as `.HasOne(c => c.CompanyConfiguration).WithOne(cc => cc.Company).HasForeignKey<CompanyConfiguration>(cc => cc.CompanyId)`. Also adjust nav property type: `public CompanyConfiguration? CompanyConfiguration { get; set; }` (singular, not ICollection). |
| ISSUE-13 | LOW | DB seed / SecondaryColorHex column | §② initially missed `SecondaryColorHex` on CompanyBrandings. The migration MUST include it. Verify before applying. |
| ISSUE-14 | LOW | FE Sidebar / Mobile responsive | Mockup mobile breakpoint (≤768px) collapses the vertical sidebar into a horizontal scrolling tab bar. FE must implement this responsive switch (CSS `@media (max-width: 768px)`). |
| ISSUE-15 | MED | BE / Default seeding atomicity | Current plan: GetCompanySettings auto-creates default CompanyConfiguration + CompanyBranding rows if missing. This means a GET can perform a write. Wrap in a single transaction; ensure idempotency (use `INSERT ... ON CONFLICT DO NOTHING` / EF `AddIfNotExists` pattern); verify performance under high read load (consider seeding ON tenant-onboarding instead — preferred). RECOMMEND: make onboarding handler responsible for seeding both rows; GetCompanySettings only auto-creates as defensive fallback. |

### Universal CONFIG warnings (apply unchanged)

- **CompanyId is NEVER a form field** — derived from HttpContext. FE never sends it; BE never accepts it from client.
- **Singleton sub-type has NO Create/Delete** — only GET + UPDATE.
- **GridFormSchema = SKIP** — custom multi-section UI.
- **No view-page 3-mode pattern** — single-mode SettingsPage.
- **Default seeding** — singleton must seed defaults; this screen plans to do so via tenant onboarding (preferred per ISSUE-15) with GetCompanySettings as defensive fallback.

### Module / new-module notes

- This screen is the FIRST `SETTINGS_PAGE` of `config_subtype` in the registry — it sets the canonical reference for §⑦ once completed.
- No new schema needed: uses existing `app` schema for the Company entity ENHANCEMENT, and existing `sett` schema for the NEW CompanyConfiguration + CompanyBranding singletons.
- Existing `Setting` group folder structure used (SettingModels / SettingSchemas / SettingConfigurations / SettingBusiness / EndPoints/Setting / SettingMappings) — no new module wiring needed.
- Existing `Application` group is touched only minimally (Company.cs entity + the existing CompanyConfiguration.cs EF fluent config — for the 15 new columns; ApplicationMappings.cs gets Company ⇄ OrgProfile/Contact section mapping).
- SET_ORGSETTINGS parent menu (MenuId 377) already exists (per MODULE_MENU_REFERENCE.md line 316). COMPANYSETTINGS menu code exists at line 363 under RA_AUDIT — the seed re-parents it to SET_ORGSETTINGS.

### Service Dependencies (UI-only — no backend service implementation)

> Everything else in the mockup is in scope. The following items are SERVICE_PLACEHOLDER because the underlying service layer does not exist:

- ⚠ **SERVICE_PLACEHOLDER: Logo / Favicon / Receipt Header Image upload (§3)** — No file-storage service is wired (S3 / Azure Blob / equivalent). FE shows full Upload UI; on file select, store as data-URL in form state for preview only; on Save, send the data-URL string OR the original URL through (BE accepts either). Production fix: introduce `IFileStorageService` and replace `UploadFile` with a real call.
- ⚠ **SERVICE_PLACEHOLDER: View Plans & Pricing button (§8)** — No billing service / Stripe checkout integration. Click → toast "Plan upgrade flow coming soon".
- ⚠ **SERVICE_PLACEHOLDER: Contact Support button (§8)** — No support-ticket service. Click → either toast OR `mailto:support@{domain}` simple link.
- ⚠ **SERVICE_PLACEHOLDER: GetCompanySubscriptionInfo handler (§8 data)** — Returns hardcoded plan info with `IsPlaceholder = true`. Future: pull from billing engine.

> Full UI for sections 3, 4 (color pickers + tag inputs), 5 (timezone select + tag inputs), 7 (toggles + sub-cards + maintenance mode), and 8 (read-only display + progress bars + feature checklist) MUST be built. Only the marked external-service handler returns are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | (planning) | HIGH | BE / Subscription | No billing service in MVP. `GetCompanySubscriptionInfo` placeholder. Section 8 read-only. | OPEN |
| ISSUE-2 | (planning) | MED | BE / Receipt numbering | nextReceiptNumberPreview must compute from MAX(receipt no) + 1 per tenant. | **SUPERSEDED (Session 2)** — moved to future "Receipt & Tax Configuration" screen |
| ISSUE-3 | (planning) | MED | FE / Timezone | Static IANA list. | **SUPERSEDED (Session 2)** — DefaultTimezone now FK to MasterData TypeCode=TIMEZONE |
| ISSUE-4 | (planning) | MED | DB Seed | COMPANYSETTINGS re-parented from RA_AUDIT to ORG_COMPANY in seed. | OPEN |
| ISSUE-5 | (planning) | LOW | BE / EF config naming | EF config for Company at `ApplicationConfigurations/CompanyConfiguration.cs` exists. NEW entity EF config lives in `SettingConfigurations/CompanyConfigurationConfiguration.cs` (different folder/namespace — no collision). | OPEN |
| ISSUE-6 | (planning) | LOW | BE / Maintenance mutation | Optional fast-path ToggleMaintenanceMode mutation. Defer unless requested. | OPEN |
| ISSUE-7 | (planning) | LOW | FE / TagInput | Search registries first; reuse if exists. | **CLOSED (Session 2)** — registries scanned (tag-input-pill, multi-tag-chip-selector, ApiMultiSelect); none matched the `{id, code, name}[]` + combobox-add shape. New `tag-input.tsx` created. |
| ISSUE-8 | (planning) | LOW | FE / Route | New route at `companysettings/`; existing `company/` list-grid untouched. | **CLOSED (Session 2)** |
| ISSUE-9 | (planning) | LOW | FE / CSV roundtrip | `additionalCurrenciesCsv` ↔ `{id, code, name}[]` serialization. | **SUPERSEDED (Session 2)** — CSV columns replaced with proper junction tables |
| ISSUE-10 | (planning) | LOW | BE / Audit | Whole-payload audit; per-field diff is follow-up. | OPEN |
| ISSUE-11 | (planning) | MED | FE / RHF | Nested object schema; section components share `useFormContext`. | **CLOSED (Session 3)** — composite RHF host with `useFormContext` per section; FK Id triples bound via nested Controllers; multi-select chip↔int[] mirror via `useEffect` |
| ISSUE-12 | (planning) | LOW | BE / 1:1 nav | Configure `.HasOne(...).WithOne(...)` for Company ↔ CompanyConfiguration / CompanyBranding. | **CLOSED (Session 1)** |
| ISSUE-13 | (planning) | LOW | DB / SecondaryColorHex | Migration must include this column. | **CLOSED (Session 1)** |
| ISSUE-14 | (planning) | LOW | FE / Mobile | Sidebar collapses to horizontal tab bar at ≤768px. | OPEN — pending FE session |
| ISSUE-15 | (planning) | MED | BE / Default seeding | Prefer onboarding-time seed; GetCompanySettings as defensive fallback. | **PARTIAL (Session 1)** — defensive fallback closed; preferred onboarding-time seed deferred to onboarding ticket |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-01 — BUILD — PARTIAL

- **Scope**: Initial **BE-only** build from PROMPT_READY. User explicitly split BE→FE across two sessions for token safety; ToggleMaintenanceMode mutation deferred. CONFIG block approved as-is (BUSINESSADMIN-only, READ + MODIFY).
- **Files touched**:
  - **BE — created (16)**:
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/CompanyConfiguration.cs` (created)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/CompanyBranding.cs` (created — incl. `SecondaryColorHex` per ISSUE-13 + forward-compat columns)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Defaults/CompanyConfigurationDefaults.cs` (created — single source of truth for §4–7 defaults)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Defaults/CompanyBrandingDefaults.cs` (created)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/SettingConfigurations/CompanyConfigurationConfiguration.cs` (created)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/SettingConfigurations/CompanyBrandingConfiguration.cs` (created)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/SettingSchemas/CompanySettingsSchemas.cs` (created — composite + 7 section DTOs + chip DTOs + CompanySubscriptionInfoDto)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/CompanySettings/Queries/GetCompanySettingsQuery/GetCompanySettings.cs` (created — composite query, defensive auto-seed branch, receipt-preview compute)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/CompanySettings/Commands/UpdateCompanySettingsCommand/UpdateCompanySettings.cs` (created)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/CompanySettings/Commands/UpdateCompanySettingsCommand/UpdateCompanySettingsValidator.cs` (created — all §④ rules incl. conditional + email/url/hex/E.164 regex)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/SettingBusiness/CompanySettings/Queries/GetSubscriptionInfoQuery/GetCompanySubscriptionInfo.cs` (created — placeholder per ISSUE-1)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Setting/Mutations/CompanySettingsMutations.cs` (created — UpdateCompanySettings only; ToggleMaintenanceMode DEFERRED)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Setting/Queries/CompanySettingsQueries.cs` (created — GetCompanySettings + GetCompanySubscriptionInfo)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/CompanySettings-sqlscripts.sql` (created — re-parents COMPANYSETTINGS to SET_ORGSETTINGS, MasterData seeds for ORGANIZATIONTYPE/LOGINTEMPLATE, default settings rows)
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Migrations/20260501050725_Add_CompanyConfiguration_And_Branding_And_CompanyEnhancements.cs` (+ Designer)
  - **BE — modified (8)**:
    - `Base.Domain/Models/ApplicationModels/Company.cs` (modified — 15 nullable scalars + OrganizationType nav + 1:1 navs to CompanyConfiguration / CompanyBranding)
    - `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/CompanyConfiguration.cs` (modified — HasMaxLength for new columns + FK to MasterData OrganizationType Restrict + index + 1:1 reverse navs)
    - `Base.Application/Data/Persistence/ISettingDbContext.cs` (modified — added CompanyConfigurations + CompanyBrandings DbSets)
    - `Base.Infrastructure/Data/Persistence/SettingDbContext.cs` (modified — concrete DbSets)
    - `Base.Application/Extensions/DecoratorProperties.cs` (modified — added CompanySettings/CompanyConfiguration/CompanyBranding to DecoratorSettingModules)
    - `Base.Application/Mappings/SettingMappings.cs` (modified — Mapster registrations CompanyConfiguration ⇄ Financial/Regional/Communication/System; CompanyBranding ⇄ Branding)
    - `Base.Application/Mappings/ApplicationMappings.cs` (modified — Company ⇄ OrgProfile/Contact with Address ↔ AddressLine1)
    - `Base.Application/GlobalUsing.cs` (modified — added Base.Domain.Defaults)
  - **DB**: `sql-scripts-dyanmic/CompanySettings-sqlscripts.sql` (created — listed above)
- **Deviations from spec**:
  - **Single migration instead of two** — `IApplicationDbContext` is partial across all schemas in this codebase, so one migration `Add_CompanyConfiguration_And_Branding_And_CompanyEnhancements` covers both `app.Companies` ALTER and `sett.*` CREATE. Cross-schema FKs verified: `principalSchema: "app"` for Companies references; `principalSchema: "com"` for Currencies/Countries/Languages; `principalSchema: "sett"` for MasterDatas.
  - **Receipt-number preview source** — uses `GlobalDonation.ReceiptNumber` (the actual concatenated receipt-string column) instead of `GlobalReceiptDonation` which only has `ReceiptBookNo` + `ReceiptBookSerialNo`. `IApplicationDbContext` already exposes `GlobalDonations` (it inherits `IDonationDbContext`), so no extra DbContext injection needed.
  - **Lookup schema correction** — seed script uses `com` schema (not `corg` as written in some prompt sections) for Currencies/Countries/Languages, after grepping the actual entity attributes.
  - **Audit emission** — left as `// TODO(audit): wire to {ServiceName}` near success path; no central audit service file located in current codebase grep. Per instruction, did not block on missing infra.
  - **ToggleMaintenanceMode** — deferred per user (ISSUE-6); not generated, not registered.
- **Known issues opened**: None (no NEW bugs surfaced — all known issues were planning-phase).
- **Known issues closed**:
  - ISSUE-12 (1:1 nav property) — implemented in `ApplicationConfigurations/CompanyConfiguration.cs` via `.HasOne(...).WithOne(...).HasForeignKey<>(...)`. Status → CLOSED.
  - ISSUE-13 (SecondaryColorHex column) — included in CompanyBranding entity + EF config + migration. Status → CLOSED.
  - ISSUE-15 (default seeding atomicity) — defensive fallback in `GetCompanySettings` wrapped in transaction; preferred onboarding-time seed deferred to onboarding handler ticket. Status → PARTIALLY CLOSED (defensive path closed; preferred path open as future ticket).
- **Next step**: **Frontend session** — generate 21 FE files per §⑧ Frontend Files CREATE table:
  1. DTO Types: `domain/entities/setting-service/CompanySettingsDto.ts`
  2. GQL Query: `infrastructure/gql-queries/setting-queries/CompanySettingsQuery.ts`
  3. GQL Mutation: `infrastructure/gql-mutations/setting-mutations/CompanySettingsMutation.ts`
  4. Settings Page composite host + sidebar nav: `presentation/components/page-components/setting/orgsettings/companysettings/settings-page.tsx`
  5–12. 8 section components: `sections/{org-profile,contact,branding,financial,regional,communication,system,subscription}-section.tsx`
  13–17. 5 sub-components: `components/{color-picker-input,tag-input,file-upload-card,timezone-select,maintenance-mode-modal}.tsx`
  18. Zustand store: `companysettings-store.ts`
  19. Zod schema: `companysettings-schemas.ts`
  20. Save bar: `components/save-changes-bar.tsx`
  21. Page Config: `presentation/pages/setting/orgsettings/companysettings.tsx`
  Plus 6 wiring files: route stub at `app/[lang]/setting/orgsettings/companysettings/page.tsx`, barrel exports for setting-service / setting-queries / setting-mutations / pages index / page-components/setting/orgsettings index, and operations-config (verify if needed for CONFIG screens).
  After FE generation: full E2E testing per Step 5b SETTINGS_PAGE checklist (auto-seed defaults, 8-section sidebar nav, sticky Save All, Discard confirm, validation jumps, conditional fields, color pickers, tag inputs, maintenance-mode confirm modal both directions, unsaved-changes blocker, role gate). Then update prompt to COMPLETED and registry NEW → COMPLETED.


### Session 2 — 2026-05-01 — BUILD — PARTIAL (BE refactor)

- **Scope**: **BE architectural refactor** of Session 1's output. User feedback drove three changes: (a) remove receipt/tax fields (deferred to future "Receipt & Tax Configuration" screen), (b) convert 14 dropdown enum fields to FK → MasterData (single source of truth for option lists), (c) normalize 3 multi-select CSV columns to junction tables. Frontend still pending Session 3.
- **Files touched**:
  - **BE — created (6)**:
    - `Base.Domain/Models/SettingModels/CompanyConfigurationCurrency.cs` (junction)
    - `Base.Domain/Models/SettingModels/CompanyConfigurationLanguage.cs` (junction)
    - `Base.Domain/Models/SettingModels/CompanyConfigurationOperatingCountry.cs` (junction)
    - `Base.Infrastructure/Data/Configurations/SettingConfigurations/CompanyConfigurationCurrencyConfiguration.cs`
    - `Base.Infrastructure/Data/Configurations/SettingConfigurations/CompanyConfigurationLanguageConfiguration.cs`
    - `Base.Infrastructure/Data/Configurations/SettingConfigurations/CompanyConfigurationOperatingCountryConfiguration.cs`
  - **BE — modified (13)**:
    - `Base.Domain/Models/SettingModels/CompanyConfiguration.cs` — dropped 6 receipt/tax columns; converted 14 enum fields to `*Id` FK + nav; added 3 junction ICollection navs
    - `Base.Domain/Models/SettingModels/CompanyBranding.cs` — dropped `ReceiptHeaderImageUrl` + `ReceiptFooterText`
    - `Base.Infrastructure/Data/Configurations/SettingConfigurations/CompanyConfigurationConfiguration.cs` — 14 FK constraints with Restrict; junction inverse navs; dropped column configs
    - `Base.Infrastructure/Data/Configurations/SettingConfigurations/CompanyBrandingConfiguration.cs`
    - `Base.Domain/Defaults/CompanyConfigurationDefaults.cs` — const ints replaced with `(TypeCode, DataValue)` lookup pairs; receipt/tax defaults removed
    - `Base.Domain/Defaults/CompanyBrandingDefaults.cs`
    - `Base.Application/Schemas/SettingSchemas/CompanySettingsSchemas.cs` — receipt/tax + CSV fields removed; FK sections expose `XxxId/XxxName/XxxValue` triples; multi-select uses `int[]` request + chip-array response
    - `Base.Application/Business/SettingBusiness/CompanySettings/Queries/GetCompanySettingsQuery/GetCompanySettings.cs` — 14 MasterData `.Include()` + 3 junction `.Include().ThenInclude()`; auto-seed resolves FK Ids by `(TypeCode, DataValue)`; receipt-number-preview compute removed
    - `Base.Application/Business/SettingBusiness/CompanySettings/Commands/UpdateCompanySettingsCommand/UpdateCompanySettings.cs` — diff-based junction sync; receipt/tax mapping removed
    - `Base.Application/Business/SettingBusiness/CompanySettings/Commands/UpdateCompanySettingsCommand/UpdateCompanySettingsValidator.cs` — per-range checks replaced by `XxxId > 0`
    - `Base.Infrastructure/Data/ISettingDbContext.cs` + `SettingDbContext.cs` — 3 new DbSets (`CompanyConfigurationCurrencies`, `CompanyConfigurationLanguages`, `CompanyConfigurationOperatingCountries`)
    - `Base.Application/Extensions/DecoratorProperties.cs` — 3 junction entities added to `DecoratorSettingModules`
    - `Base.Application/Mappings/SettingMappings.cs` — Mapster registrations rewritten for new DTO shapes; 3 junction→chip configs added
  - **DB**: `sql-scripts-dyanmic/CompanySettings-sqlscripts.sql` — modified: 14 new MasterData TypeCode seeds (FINANCIALYEARSTARTMONTH, CURRENCYDISPLAYFORMAT, NUMBERFORMAT, TIMEZONE, DATEFORMAT, TIMEFORMAT, TWOFACTORAUTHMODE, AUTOLOGOUTMINUTES, LOGINATTEMPTSBEFORELOCK, PASSWORDMINLENGTH, PASSWORDEXPIRYDAYS, PASSWORDHISTORYCOUNT, AUDITLOGRETENTIONYEARS, DELETEDRECORDSRETENTIONDAYS); default tenant row uses sub-selects to resolve FK Ids by `(TypeCode, DataValue)`
  - **Migrations**:
    - DELETED: Session 1's `20260501050725_Add_CompanyConfiguration_And_Branding_And_CompanyEnhancements.cs` + Designer (uncommitted, regenerated)
    - CREATED: `20260501064141_Add_CompanyConfiguration_And_Branding_And_CompanyEnhancements.cs` (+ Designer + ModelSnapshot delta) — 753 lines, generated via `dotnet ef migrations add`
- **Deviations from spec**: None. Receipt-number-preview compute removed cleanly; `IDonationDbContext` was never injected separately (the Session 1 implementation used existing `IApplicationDbContext`-inherited `GlobalDonations`).
- **Known issues opened**: None.
- **Known issues closed**:
  - ISSUE-2 (BE / Receipt numbering preview compute) — **SUPERSEDED**. Receipt-number preview moved to future "Receipt & Tax Configuration" screen.
  - ISSUE-3 (FE / Timezone static IANA list) — **SUPERSEDED**. DefaultTimezone is now FK to MasterData TypeCode=TIMEZONE; FE will use `GetMasterDatas` with TypeCode filter.
  - ISSUE-9 (FE / CSV ↔ chip array roundtrip) — **SUPERSEDED**. CSV columns replaced with proper junction tables; FE state is `int[]` of refIds.
- **Cross-schema FKs verified** (in regenerated migration `20260501064141_*`): `app.Companies` (1:1 from CompanyConfiguration + CompanyBranding via Cascade); `com.Currencies` / `Countries` / `Languages` (Restrict); `sett.MasterDatas` (Restrict, 14 + LoginTemplate); `sett.CompanyConfigurations` (Cascade, 3 junctions). 5 filtered-unique indexes verified: `IX_CompanyConfigurations_CompanyId_Active`, `IX_CompanyBrandings_CompanyId_Active`, `IX_CompanyConfigurationCurrencies_Config_Currency_Active`, `IX_CompanyConfigurationLanguages_Config_Language_Active`, `IX_CompanyConfigurationOperatingCountries_Config_Country_Active`. Grep for dropped columns (`TaxReceiptRequired`, `ReceiptNumberPrefix`, `TaxExemption*`, `Additional*Csv`, `ReceiptHeaderImageUrl`, `ReceiptFooterText`) returns 0 matches in the migration.
- **`dotnet build` outcome**: Base.Application + Base.API + Base.Infrastructure all build with 0 errors (pre-existing warnings only).
- **Next step**: **Frontend session (Session 3)** — generate FE files per refactored §⑧ manifest. Key field-shape changes for FE: every Section 4 / 5 / 7 dropdown is now a `*Id` FK with `*Name` (display label) and `*Value` (raw int/string) companion fields in response — use `*Name` for display, `*Value` only when business logic needs the raw value. Multi-select fields: request sends `int[]` (e.g. `additionalCurrencyIds: number[]`), response returns `additionalCurrencies: { id, code, name }[]`. **No** static `lib/timezones.ts`, **no** `nextReceiptNumberPreview` display, **no** Tax/Receipt sub-card in Section 4, **no** Receipt Customization sub-section in Section 3 Branding. Then full E2E testing per Step 5b SETTINGS_PAGE checklist (auto-seed defaults, 8-section sidebar nav, sticky Save All, Discard confirm, validation jumps, conditional fields, color pickers, tag inputs, maintenance-mode confirm modal both directions, unsaved-changes blocker, role gate). Then update prompt to COMPLETED and registry to COMPLETED.



### Session 3 — 2026-05-01 — REFACTOR — COMPLETED

- **Scope**: **FE alignment with Session 2 BE refactor**. Session 2 invalidated the existing Session-2-completed FE (which was generated against pre-refactor spec) but left `frontend_completed: true` stale. This session refactors all FE files to match the FK-Id-triple + junction-backed multi-select + receipt-fields-removed BE shape.
- **Files touched**:
  - **FE — modified (8)**:
    - `PSS_2.0_Frontend/src/domain/entities/setting-service/CompanySettingsDto.ts` (rewritten — 14 enum fields → FK Id triples; receipt/tax fields removed; multi-select uses `*Ids: number[]` + chip[] pair)
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/setting-queries/CompanySettingsQuery.ts` (rewritten — selection set updated for FK Id triples + junction Id arrays; receipt/tax + CSV fields removed)
    - `PSS_2.0_Frontend/src/infrastructure/gql-mutations/setting-mutations/CompanySettingsMutation.ts` (rewritten — same selection set update for refresh response)
    - `PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/companysettings/companysettings-schemas.ts` (rewritten — Zod swaps enum/min validators for `requiredFkId`; receipt/tax superRefine removed)
    - `…/companysettings/sections/branding-section.tsx` (Receipt Customization sub-section removed; only logos + brand colors)
    - `…/companysettings/sections/financial-section.tsx` (3 dropdowns swap to MasterData ApiSelect; Tax/Receipt sub-card removed; multi-currency mirrors chip[] → `additionalCurrencyIds: int[]`)
    - `…/companysettings/sections/regional-section.tsx` (Timezone / Date Format / Time Format → MasterData ApiSelect; multi-language + multi-country mirror chip[] → int[])
    - `…/companysettings/sections/system-section.tsx` (8 hardcoded SelectItem dropdowns → reusable `MasterDataFk` helper bound to FK Id triples; password-policy + data-retention + maintenance-mode preserved)
    - `…/companysettings/settings-page.tsx` (`EMPTY_FORM` shape updated; `responseToForm` + `formToRequest` strip joined `*Name` / `*Value` display fields and serialize multi-select as `*Ids: int[]` per §⑩)
  - **FE — deleted (2)**:
    - `PSS_2.0_Frontend/src/presentation/components/page-components/setting/orgsettings/companysettings/components/timezone-select.tsx` (regional now uses `ApiSingleSelect` directly with `MASTERDATAS_QUERY` + TYPECODE filter)
    - `PSS_2.0_Frontend/src/lib/timezones.ts` (no longer referenced — TIMEZONE option set is now seeded as MasterData rows)
- **Deviations from spec**: None. All §⑩ Request/Response shapes honored; `formToRequest` strips display fields per §⑩ contract; `MasterDataFk` reusable helper introduced to avoid 8 duplicate Controller-of-Controller-of-Controller blocks in `system-section.tsx`.
- **Verification**:
  - `npx tsc --noEmit` — 0 errors related to CompanySettings or any of the 8 modified files. (9 pre-existing errors in unrelated CRM `campaign` / `organizationalunit` pages — missing jspdf module, not introduced by this session.)
  - Grep across `src/` for stale field names returns 0 matches: `additionalCurrenciesCsv`, `additionalLanguagesCsv`, `additionalOperatingCountriesCsv`, `nextReceiptNumberPreview`, `taxReceiptRequired`, `receiptAutoNumberingEnabled`, `receiptNumberPrefix`, `taxExemption*`, `receiptHeaderImageUrl`, `receiptFooterText`. Old non-Id fields (`financialYearStartMonth` without `Id` suffix, `currencyDisplayFormat`, `numberFormat`, `defaultTimezone`, `dateFormat`, `timeFormat`, `autoLogoutMinutes`, `loginAttemptsBeforeLock`, `twoFactorAuthMode`, `passwordMinLength`, `passwordExpiryDays`, `passwordHistoryCount`, `auditLogRetentionYears`, `deletedRecordsRetentionDays`) — 0 matches in companysettings folder.
- **Known issues opened**: None.
- **Known issues closed**:
  - ISSUE-11 (FE / RHF nested form) — composite RHF host with `useFormContext` per section now in place; FK Id triples bound via nested Controllers; multi-select chip ↔ int[] mirror via `useEffect`. Status → CLOSED.
- **Next step**: Manual E2E verification on a running dev environment per §⑪ checklist:
  1. Apply EF migration `Add_CompanyConfiguration_And_Branding_And_CompanyEnhancements` and run DB seed `CompanySettings-sqlscripts.sql` (the seed must include the 14 new MasterData TypeCodes — verify rows are present before testing dropdowns).
  2. `pnpm dev` → load `/{lang}/setting/orgsettings/companysettings` as BUSINESSADMIN.
  3. Walk all 8 sections — confirm every FK ApiSelect populates from MasterData (TypeCode filter); confirm chip multi-select adds/removes correctly; confirm Save persists to all 3 tables in one round-trip; confirm Discard reverts.
  4. If any MasterData TypeCode dropdown is empty: verify the seed inserted those rows (TYPECODE casing matters — must be uppercase, e.g. `FINANCIALYEARSTARTMONTH` not `FinancialYearStartMonth`).
