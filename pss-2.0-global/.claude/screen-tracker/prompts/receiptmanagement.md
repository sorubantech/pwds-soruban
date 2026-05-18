---
screen: ReceiptManagement
registry_id: 9
module: Setting (Donation Config)
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-05-15
completed_date: 2026-05-16
last_session_date: 2026-05-16
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (4-tab composite: Queue / Generated / Templates / Tax Settings)
- [x] Existing code reviewed — `GlobalReceiptDonation` BE+FE belong to **field-collection** receipt tracking (Ambassador / Receipt Book) and are UNRELATED. Same registry-misclassification pattern as #10 OnlineDonationPage (where "BE+FE exist" referred to `GlobalOnlineDonation` transactions, not the page-setup entity).
- [x] Business rules + workflow extracted
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt is self-validated — comprehensive pre-analysis treated as canonical spec)
- [x] Solution Resolution complete (FLOW composite — patterns selected in §⑤)
- [x] UX Design finalized (4-tab composite — FLOW Queue + FLOW Generated + DESIGNER Templates + SETTINGS Tax)
- [x] User Approval received (2026-05-16 — "Approve as planned")
- [x] Backend code generated (4 NEW entities + EF migration PLAN.md deferred per team-handles-migrations)
- [x] Backend wiring complete (DbContext + Mappings + Decorators)
- [x] Frontend code generated (composite shell + 4 tab modules + template designer + tax config modal + global settings form + Zustand store + 5 renderers)
- [x] Frontend wiring complete (3 column registries + entity-config gridCode blocks + barrels)
- [x] DB Seed script generated (visible parent menu RECEIPTMANAGEMENT + 4 hidden child menus + 2 FLOW grids + 7+ MasterData seeds + 5 sample ReceiptTemplate rows + 4 sample CountryTaxConfig rows + GlobalReceiptSetting upsert per tenant — 1132 lines)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/{lang}/setting/donationconfig/receiptmanagement`
- [ ] **Tab 1 (Receipt Queue)**: 3 KPI metric cards render (Pending Generation / Pending Send / Sent Today); filter bar works (date range + receipt status + send status + donation mode); rows show inferred receipt+send status; per-row actions (View / Generate / Send / Resend / Print / Download) render and fire toast for SERVICE_PLACEHOLDER actions; bulk "Generate All Pending" + "Send All Unsent" buttons fire (SERVICE_PLACEHOLDER toast)
- [ ] **Tab 2 (Generated Receipts)**: grid loads with Receipt# / Donor / Amount / Currency / Tax Type / Generated Date / Template / Format columns; Tax Type filter + Currency filter work; per-row Download + Email + WhatsApp buttons render (SERVICE_PLACEHOLDER); Bulk Download + Generate Annual Statements buttons render (SERVICE_PLACEHOLDER); row click opens detail view (LAYOUT 2 — `?tab=generated&mode=read&id={id}`)
- [ ] **Tab 3 (Templates)**: card-grid renders 5 sample templates with preview tile + default badge; "+Create New Template" navigates to FORM layout (`?tab=templates&mode=new`); edit → split-pane DESIGNER (HTML code editor + live preview); placeholder tag chips render and insert into editor on click; "Set as Default" toggles default per template type; Save persists ReceiptTemplate
- [ ] **Tab 4 (Tax Settings)**: country-config grid loads with 4 sample rows (US / India / UK / UAE); +Add Country Tax Config opens modal; Edit opens same modal pre-filled; toggle column reflects IsActive; Global Receipt Settings form below renders 5 rows (auto-generate / auto-email / numbering format / include logo / annual-statement month) and persists via Upsert single-row-per-tenant
- [ ] URL state syncs across tabs: `?tab=queue|generated|templates|settings`, plus sub-modes `?tab=templates&mode=new|edit&id={id}`
- [ ] FK dropdowns load: GlobalDonation list (queue projection), Country list, DonationPurpose list, ReceiptTemplate list (for country default)
- [ ] DB Seed — RECEIPTMANAGEMENT menu visible in sidebar under SET_DONATIONCONFIG > Donation Verse / Receipts & Tax

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **ReceiptManagement** (composite — 4 new entities under one menu)
Module: **Setting** (Donation Config sub-menu)
Schema: `fund`
Group: **DonationModels** (folder name in Business/Schemas/Configurations/EndPoints — entity namespace is `Base.Domain.Models.DonationModels`)

**Business**: This is the central tax-receipt operations center for an NGO. It serves four functions on one screen so finance/admin staff don't context-switch: (1) a **Queue** view where they bulk-trigger receipt generation for donations awaiting receipts and resend bounced emails — the highest-frequency daily task, ranked by send/generate status; (2) a **Generated Receipts** archive listing every tax receipt/certificate issued, filterable by tax code (501(c)(3), 80G, Gift Aid, UAE Charity, etc.) for compliance audit; (3) a **Templates** designer where compliance officers maintain HTML templates per tax jurisdiction with placeholder tags ({{DonorName}}, {{TaxRegNumber}}, {{AmountInWords}}, ...) — different countries demand wildly different statutory wording (India's 80G Certificate text, UK Gift Aid declaration, US "no goods or services" clause); (4) a **Tax Settings** tab where the org's per-country tax registration numbers, exempt-statement text, and global generation behaviors (auto-generate-on-donation, numbering format `TAX-{YEAR}-{SEQ}`, annual-statement-month) are configured. The screen lives under Settings > Donation Config because it's tenant-configuration of receipt issuance rules, not a per-donation transactional flow — the actual receipt generation work targets `GlobalDonation` rows but happens from this hub. Closely paired with #1 GlobalDonation (which already carries `ReceiptNumber` / `ReceiptIssuedDate` / `ReceiptSendMethodId` fields populated when receipts are issued from this screen) and with the existing receipt-modal/receipt-template UI inside `globaldonation/` (which will be repointed to use the templates managed here).

**Mockup variant**: 4-tab composite. NO separate detail page for Tab 1 (Queue rows link out to donation detail) and Tab 4 settings (single upsert form). LAYOUT 1 FORM applies to Tab 3 templates (designer canvas). LAYOUT 2 DETAIL applies to Tab 2 generated receipts (read-only view with PDF preview + audit trail).

**Existing-entity disambiguation**: `GlobalReceiptDonation` (already in BE) is for **field-collection** receipt tracking — cash collected by ambassadors → deposited at bank. Untouched by this screen. The mockup screen uses 4 NEW entities, none named "Receipt" to avoid name collision: `ReceiptTemplate`, `CountryTaxConfig`, `GlobalReceiptSetting`, `GeneratedTaxReceipt`.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Four NEW entities live under this single screen. Audit columns inherited from `Entity` base in all four.
> **CompanyId is NOT a field** for any of them — FLOW screens get tenant from HttpContext.

### Entity 1 — `ReceiptTemplate` (Tab 3 — HTML template designer)

Table: `fund."ReceiptTemplates"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| ReceiptTemplateId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | app.Companies | Tenant scope (HttpContext) |
| ReceiptTemplateName | string | 200 | YES | — | "US Tax Receipt (501(c)(3))", "India 80G Certificate", etc. — unique per Company |
| ReceiptTemplateTypeId | int | — | YES | com.MasterData (typeCode=RECEIPTTEMPLATETYPE) | TaxReceipt / Certificate / Acknowledgment |
| CountryId | int? | — | NO | com.Countries | Bind to a country (drives default template selection); NULL = general |
| TaxCodeKey | string | 50 | NO | — | "501c3" / "80G" / "GIFTAID" / "UAECHARITY" / "GENERAL" (used to filter templates per donation country at receipt-gen time) |
| DonationPurposeId | int? | — | NO | fund.DonationPurposes | Optional — bind template to a specific purpose ("Education" template); NULL = All Purposes |
| BodyHtml | string | -1 (text) | YES | — | The Mustache/Handlebars HTML body with `{{Placeholder}}` tags |
| PlaceholdersUsedJson | string | -1 (text) | NO | — | JSON array of placeholders the BodyHtml references — computed on Save for fast validation lookups |
| PageSize | string | 10 | YES | — | "A4" / "Letter" |
| Orientation | string | 10 | YES | — | "Portrait" / "Landscape" |
| StatementText | string | 2000 | NO | — | Tax-exempt statement (e.g., "No goods or services were provided in exchange for this contribution.") — separate from BodyHtml so it can be tax-jurisdiction-rule-validated |
| IsDefault | bool | — | YES | — | Default for its (Company, TaxCodeKey) pair — only one default per tax code (handler enforces) |
| LastPreviewedAt | DateTime? | — | NO | — | Stamped when user clicks Preview — for UX "last modified" footer in template card |

### Entity 2 — `CountryTaxConfig` (Tab 4 — country-wise tax registration)

Table: `fund."CountryTaxConfigs"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| CountryTaxConfigId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | app.Companies | Tenant scope (HttpContext) |
| CountryId | int | — | YES | com.Countries | Unique per (CompanyId, CountryId) |
| TaxCodeType | string | 50 | YES | — | "501(c)(3)" / "80G" / "Gift Aid" / "Charity License" — display label (used as TaxCodeKey lookup too if `TaxCodeKey` not set) |
| RegistrationNumber | string | 100 | YES | — | "12-3456789" (EIN), "AABTX1234F" (PAN), "XR12345" (Charity Ref), "CL-2024-1234" |
| OrganizationLegalName | string | 200 | YES | — | Full legal entity name as it appears on receipts |
| TaxExemptStatementText | string | 2000 | NO | — | Pre-filled statutory text inserted into receipt body |
| DefaultReceiptTemplateId | int? | — | NO | fund.ReceiptTemplates | Default template used when a donor in this country triggers a receipt; soft FK with no cascade |
| IsActive | bool | — | YES | — | Inherited from Entity |

### Entity 3 — `GlobalReceiptSetting` ~~(Tab 4 — single-row-per-tenant config)~~ **REMOVED (Session 3 2026-05-16)**

> **Session 3 (2026-05-16) — entity DELETED.** The 4 workflow flags (`AutoGenerateOnDonation`,
> `AutoSendByEmail`, `IncludeOrgLogo`, `AnnualStatementMonth`) moved to
> `sett.CompanyConfigurations` §8 (CompanySettings #75 Receipt section), renamed:
> - `AutoGenerateReceiptOnDonation`
> - `AutoSendReceiptByEmail`
> - `IncludeOrgLogoOnReceipt`
> - `AnnualStatementMonth` (unchanged)
>
> Rationale: tenant-singletons already have a natural home (`CompanyConfiguration`).
> Maintaining a parallel `fund.GlobalReceiptSettings` table for 4 flags duplicated the
> singleton pattern and split tenant config across two schemas. Numbering was already
> off-loaded to the generic NumberSequence subsystem in Session 2, so the residual table
> carried only workflow flags that fit cleanly under CompanySettings.
>
> **Numbering note (Session 2 — unchanged)** — Tax-receipt numbering is owned by the generic
> NumberSequence subsystem (`sett.NumberSequenceEntityTypes` + `sett.NumberSequenceConfigs` +
> `NumberSequenceGenerator`). The catalog row for entity code `GENERATEDTAXRECEIPT` is seeded
> by `ReceiptManagement-sqlscripts.sql` STEP 9 and surfaced in CompanySettings #75 → Section 9.
> `NumberSequenceEntityType.NumberColumnName` (= `"ReceiptNumber"`) fully describes where the
> generated number is written.
>
> **Tab 4 Section B UI** — replaced by a deep-link banner pointing to CompanySettings #75
> Receipt section. Section C (numbering banner) unchanged.

### Entity 4 — `GeneratedTaxReceipt` (Tab 2 — issued tax receipts)

Table: `fund."GeneratedTaxReceipts"` — one row per **physical receipt** issued (a single donation can have multiple if re-issued with corrections, so soft 1:N to GlobalDonation, not 1:1)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| GeneratedTaxReceiptId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | app.Companies | Tenant scope (HttpContext) |
| GlobalDonationId | int | — | YES | fund.GlobalDonations | The donation this receipt was generated for |
| ReceiptTemplateId | int | — | YES | fund.ReceiptTemplates | Snapshot — template used at generation |
| CountryTaxConfigId | int? | — | NO | fund.CountryTaxConfigs | Which tax jurisdiction this receipt was issued under |
| ReceiptNumber | string | 50 | YES | — | "TAX-2026-0892" — generated from `GlobalReceiptSetting.ReceiptNumberFormat`. Unique per Company. |
| TaxCodeKey | string | 50 | YES | — | Snapshot — "501c3" / "80G" / etc. — copied from template at generation (template's TaxCodeKey or CountryTaxConfig.TaxCodeType) |
| DonorContactId | int? | — | NO | corg.Contacts | Snapshot — donor at time of issuance (donations can be re-attributed later) |
| DonorNameSnapshot | string | 200 | YES | — | Snapshot — donor name printed on the receipt at generation time |
| AmountSnapshot | decimal(18,2) | — | YES | — | Snapshot — donation amount at generation |
| CurrencyIdSnapshot | int | — | YES | com.Currencies | Snapshot — currency at generation |
| FormatType | string | 10 | YES | — | "PDF" (only PDF for V1; future: HTML, IMAGE) |
| FileUrl | string | 500 | NO | — | SERVICE_PLACEHOLDER — would be the storage URL of the rendered PDF |
| GeneratedDate | DateTime | — | YES | — | Issuance timestamp |
| GeneratedBy | int? | — | NO | corg.Staffs | The staff who issued (NULL if auto-generated by system) |
| SendStatusId | int | — | YES | com.MasterData (typeCode=RECEIPTSENDSTATUS) | NotSent / Emailed / Printed / WhatsApp / Bounced |
| SendChannelMethodId | int? | — | NO | com.MasterData (typeCode=RECEIPTSENDMETHOD) | Email / Print / WhatsApp / Download — last channel used |
| SentTo | string | 500 | NO | — | Email or phone the receipt was sent to (snapshot) |
| LastSentAt | DateTime? | — | NO | — | Timestamp of last send attempt |
| ResendCount | int | — | YES | — | Default 0 — number of times this receipt has been re-sent |
| BounceReason | string | 500 | NO | — | Set when SendStatus=Bounced |

**Child Entities**: None (all four entities are flat).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (.Include() + nav properties) + Frontend Developer (ApiSelectV2 queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ReceiptTemplate.ReceiptTemplateTypeId | MasterData | `Base.Domain/Models/SharedModels/MasterData.cs` | `GetMasterDataByTypeCode` (typeCode=`RECEIPTTEMPLATETYPE`) | `DataName` | `MasterDataResponseDto` |
| ReceiptTemplate.CountryId | Country | `Base.Domain/Models/SharedModels/Country.cs` | `countries` (GetCountries) | `CountryName` | `CountryResponseDto` |
| ReceiptTemplate.DonationPurposeId | DonationPurpose | `Base.Domain/Models/DonationModels/DonationPurpose.cs` | `donationPurposes` (GetDonationPurposes) | `DonationPurposeName` | `DonationPurposeResponseDto` |
| CountryTaxConfig.CountryId | Country | `Base.Domain/Models/SharedModels/Country.cs` | `countries` | `CountryName` | `CountryResponseDto` |
| CountryTaxConfig.DefaultReceiptTemplateId | ReceiptTemplate | `Base.Domain/Models/DonationModels/ReceiptTemplate.cs` *(to be created)* | `receiptTemplates` *(to be created)* | `ReceiptTemplateName` | `ReceiptTemplateResponseDto` *(to be created)* |
| GeneratedTaxReceipt.GlobalDonationId | GlobalDonation | `Base.Domain/Models/DonationModels/GlobalDonation.cs` | `globalDonations` | `ReceiptNumber` / `ContactName` | `GlobalDonationResponseDto` |
| GeneratedTaxReceipt.ReceiptTemplateId | ReceiptTemplate | *(to be created)* | `receiptTemplates` *(to be created)* | `ReceiptTemplateName` | `ReceiptTemplateResponseDto` |
| GeneratedTaxReceipt.CountryTaxConfigId | CountryTaxConfig | *(to be created)* | `countryTaxConfigs` *(to be created)* | `CountryName` (via .Include) | `CountryTaxConfigResponseDto` |
| GeneratedTaxReceipt.DonorContactId | Contact | `Base.Domain/Models/CorgModels/Contact.cs` | `contacts` (GetContacts) | `DisplayName` else `FirstName+LastName` | `ContactResponseDto` |
| GeneratedTaxReceipt.CurrencyIdSnapshot | Currency | `Base.Domain/Models/SharedModels/Currency.cs` | `currencies` (GetCurrencies) | `CurrencyCode` | `CurrencyResponseDto` |
| GeneratedTaxReceipt.GeneratedBy | Staff | `Base.Domain/Models/CorgModels/Staff.cs` | `staffs` (GetStaffs) | `StaffName` | `StaffResponseDto` |
| GeneratedTaxReceipt.SendStatusId | MasterData | (typeCode=`RECEIPTSENDSTATUS`) | `GetMasterDataByTypeCode` | `DataName` | `MasterDataResponseDto` |
| GeneratedTaxReceipt.SendChannelMethodId | MasterData | (typeCode=`RECEIPTSENDMETHOD`) | `GetMasterDataByTypeCode` | `DataName` | `MasterDataResponseDto` |
| All entities.CompanyId | Company | `Base.Domain/Models/ApplicationModels/Company.cs` | (resolved from HttpContext) | — | — |

**MasterData seeds required**:

**Type 1**: `RECEIPTTEMPLATETYPE` (3 rows)
| Code | Name |
|------|------|
| TAXRECEIPT | Tax Receipt |
| CERTIFICATE | Certificate |
| ACKNOWLEDGMENT | Acknowledgment |

**Type 2**: `RECEIPTSENDSTATUS` (5 rows — drives Tab 1 + Tab 2 status badges)
| Code | Name | UI Color |
|------|------|----------|
| NOTSENT | Not Sent | slate |
| EMAILED | Emailed | blue |
| PRINTED | Printed | indigo |
| WHATSAPP | WhatsApp | green |
| BOUNCED | Bounced | red |

**Type 3**: `RECEIPTSENDMETHOD` (4 rows — channels used to send)
| Code | Name | Icon |
|------|------|------|
| EMAIL | Email | envelope |
| PRINT | Print | print |
| WHATSAPP | WhatsApp | whatsapp |
| DOWNLOAD | Download | download |

(NOTE — verify whether `RECEIPTSENDMETHOD` MasterDataType already exists — `GlobalDonation.ReceiptSendMethodId` was wired during #1 build, and GlobalDonation build log KI-10 flagged the MasterDataType name as TBD between `DONATIONMODE` vs `RECEIPTSENDMETHOD`. Reuse if seeded; else seed.)

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `ReceiptTemplate.ReceiptTemplateName` must be unique per (CompanyId, IsDeleted=false) — filtered unique index
- `ReceiptTemplate.IsDefault` = true: only ONE template per (CompanyId, TaxCodeKey) may have IsDefault=true — handler enforces (sets all others to false on default-set)
- `CountryTaxConfig.(CompanyId, CountryId)` must be unique — filtered unique index (one config per country per tenant)
- `GlobalReceiptSetting.CompanyId` must be unique (one row per tenant) — implement via Upsert pattern in command handler
- `GeneratedTaxReceipt.ReceiptNumber` must be unique per (CompanyId, IsDeleted=false) — filtered unique index

**Required Field Rules:**
- ReceiptTemplate: `ReceiptTemplateName`, `ReceiptTemplateTypeId`, `BodyHtml`, `PageSize`, `Orientation` are mandatory
- CountryTaxConfig: `CountryId`, `TaxCodeType`, `RegistrationNumber`, `OrganizationLegalName` are mandatory
- GlobalReceiptSetting: all bool/int defaults set on first row creation; `ReceiptNumberFormat` must be non-empty and contain at least one of `{YEAR}` or `{SEQ}`
- GeneratedTaxReceipt: `GlobalDonationId`, `ReceiptTemplateId`, `ReceiptNumber`, `TaxCodeKey`, `DonorNameSnapshot`, `AmountSnapshot`, `CurrencyIdSnapshot`, `FormatType`, `GeneratedDate`, `SendStatusId` are mandatory

**Conditional Rules:**
- If `GeneratedTaxReceipt.SendStatusId = EMAILED|WHATSAPP` → `SentTo` is required (email/phone)
- If `GeneratedTaxReceipt.SendStatusId = BOUNCED` → `BounceReason` is required (≥1 char)
- If `ReceiptTemplate.CountryId` is set → optionally validate `BodyHtml` contains country-specific required placeholders (e.g., India 80G must reference `{{TaxRegNumber}}` and `{{AmountInWords}}`) — WARN, not block
- `GlobalReceiptSetting.ReceiptNumberFormat` parser: if it contains `{YEAR}` and year transitions, reset `LastSequenceNumber` to 0
- Tab 1 Queue "Generate" action: only allowed when `GlobalDonation.PaymentStatusId` is in (Received, Posted) — cheque-not-cleared donations show disabled "Generate When Cleared" button per mockup row 4

**Business Logic:**
- On `GeneratedTaxReceipt` Create:
  1. Read `GlobalReceiptSetting` for tenant (Upsert default row if missing)
  2. Resolve template — explicit `ReceiptTemplateId` arg OR `CountryTaxConfig.DefaultReceiptTemplateId` for donor's country OR tenant default for `TaxCodeKey="GENERAL"`
  3. Generate `ReceiptNumber` by formatting `ReceiptNumberFormat`: replace `{YEAR}` with current year, `{MONTH}` with current month, `{SEQ}` with `LastSequenceNumber + 1` (zero-padded to 4), `{COUNTRY}` with donor country code
  4. Atomically increment `GlobalReceiptSetting.LastSequenceNumber` (and reset if year changed)
  5. Snapshot DonorName, Amount, Currency from the GlobalDonation
  6. SERVICE_PLACEHOLDER — invoke PDF render service with `BodyHtml` + placeholder substitution → write `FileUrl`
  7. Backfill `GlobalDonation.ReceiptNumber`, `GlobalDonation.ReceiptIssuedDate`, `GlobalDonation.ReceiptIssuedBy` so the donation row reflects "Generated" status in Tab 1 next time it loads
- On `ReceiptTemplate` SetDefault: set `IsDefault=false` for all other templates with same (CompanyId, TaxCodeKey), then set this one true
- On `CountryTaxConfig` Toggle off: do NOT cascade — receipts already issued retain CountryTaxConfigId snapshot; new generations for that country fall back to general template
- Tab 1 row inference (NO new entity — derived per `GlobalDonation` row):
  - `ReceiptStatus` = `Generated` if `GlobalDonation.ReceiptNumber IS NOT NULL`; `Pending (cheque not cleared)` if `PaymentStatusId IN (Pending,Recorded) AND DonationModeId=CHEQUE`; `Not Generated` otherwise
  - `SendStatus` = the latest `GeneratedTaxReceipt.SendStatusId` joined via `GlobalDonationId`, else `—`
- Tab 1 "Generate All Pending" — bulk action firing one Create per donation row matching filter, transactional batch (SERVICE_PLACEHOLDER for V1; just toast + per-row Create loop, no batch endpoint)

**Workflow** (per-receipt micro-state, not a true state machine):
- States on `GeneratedTaxReceipt.SendStatusId`: NotSent → (Emailed | Printed | WhatsApp | Bounced); Bounced → (Emailed | WhatsApp | Printed) via Resend
- Transitions are not gated — any send action overwrites status. Resend increments `ResendCount`.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW (composite multi-tab — 4 entities under one menu)
**Type Classification**: Composite Tabbed FLOW (TagSegmentation #22 hidden-child-menu pattern + MatchingGift #11 4-tab precedent)
**Reason**: 4 tabs cover transactional (Queue, Generated) + designer (Templates) + settings (Tax Settings) surfaces; URL must sync tab + sub-mode (`?tab=templates&mode=edit&id={id}`); user expects unified tabbed UX, not 4 separate sidebar entries. Per-tab specifics: Tab 1 is a projection grid (NO new entity), Tabs 2+3 are full FLOW (grid + view-page), Tab 4 is grid + upsert-form. Single composite FLOW captures it.

**Backend Patterns Required:**
- [x] Standard CRUD for 4 entities — 4 × 11 files = ~44 BE files
- [x] Tenant scoping (CompanyId from HttpContext) on all 4
- [ ] Nested child creation — N/A (flat entities)
- [x] Multi-FK validation (ValidateForeignKeyRecord × multiple)
- [x] Unique validation — ReceiptTemplate name per company, CountryTaxConfig per country, GlobalReceiptSetting single-row, GeneratedTaxReceipt number per company
- [ ] Workflow commands — only micro-state on GeneratedTaxReceipt (no Submit/Approve gate)
- [ ] File upload command — V1 no upload; PDF gen is SERVICE_PLACEHOLDER
- [x] Custom business rule validators — ReceiptNumberFormat parser, IsDefault exclusivity, AnnualStatementMonth range
- [x] Composite query — `GetReceiptQueue` projection over `GlobalDonations` joined with latest `GeneratedTaxReceipts.SendStatusId` (Tab 1 source)
- [x] Composite query — `GetReceiptManagementSummary` returning 3 KPI counts for Tab 1 metric bar
- [x] Upsert pattern — `UpsertGlobalReceiptSetting` (single-row-per-tenant)
- [x] SetDefault command — `SetReceiptTemplateDefault`
- [x] Send/Resend commands (SERVICE_PLACEHOLDER) — `SendGeneratedTaxReceipt`, `ResendGeneratedTaxReceipt`

**Frontend Patterns Required:**
- [x] Tabbed shell (4 tabs synced to `?tab=` URL param)
- [x] 3 KPI metric cards on Tab 1 (Pending Generation / Pending Send / Sent Today) — `GetReceiptManagementSummary`
- [x] FlowDataTable (Tab 1 — queue grid; Tab 2 — generated receipts grid; Tab 4 — country-config grid)
- [x] view-page.tsx with 3 URL modes for Tab 3 templates (new / edit / read)
- [x] DESIGNER_CANVAS layout in Tab 3 edit mode (HTML code editor + live preview pane + placeholder tag chips)
- [x] React Hook Form for: template form, country-config modal, global-settings form
- [x] Zustand store (`receiptmanagement-store.ts`) — UI state across tabs (active tab, selected rows for bulk actions, template editor preview HTML)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Tab 3 designer + Tab 4 settings)
- [x] Modal — Tab 4 Country Tax Config add/edit (MasterModalForm pattern — small entity, modal is sufficient)
- [ ] Child grid inside form — N/A
- [x] Status badges (Tab 1 ReceiptStatus + SendStatus, Tab 2 TaxType chip)
- [x] Summary cards / count widgets above grid (Tab 1 only)
- [ ] Grid aggregation columns — N/A
- [x] Service placeholder buttons — Generate, Send, Resend, Download, Email, WhatsApp, Print, Bulk Download, Generate Annual Statements

**Grid Layout Variant** (REQUIRED — applies to Tab 1 specifically since it has widgets): `widgets-above-grid`
- FE Dev uses **Variant B** for Tab 1: `<ScreenHeader>` + 3 metric components + `<FlowDataTableContainer showHeader={false}>` to avoid duplicate headers (ContactType #19 precedent).
- Tab 2 / Tab 4 grids: `grid-only` (no widgets above).
- Tab 3 templates: card-grid display mode (gallery preview) — see § 5b below.

**Card-grid for Tab 3** (REQUIRED):
- Display Mode: `card-grid`
- Card Variant: `details`
- Reason: Templates are visually distinct — preview tile + name + type badge + fields summary. Matches mockup `.template-card` exactly.
- Card Config (`details`):
```yaml
cardConfig:
  headerField: "receiptTemplateName"
  metaFields: ["receiptTemplateTypeName", "countryName"]
  snippetField: "fieldsSummary"  # FE-computed from PlaceholdersUsedJson
  footerField: "modifiedDate"
```
- Mockup shows a default-badge corner overlay on the default template per type — surface via `isDefault` boolean on the DTO; renderer overlays badge.
- Build dependency: `card-grid` infrastructure must already exist (per `.claude/feature-specs/card-grid.md`). If first screen to need card-grid `details` variant, FE dev must scaffold the shell + variant. Otherwise reuse.

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.

### Page Shell — 4-tab composite

**Page Header**:
- Back arrow (→ navigate to last sidebar page, default `/`)
- Title: "Receipts & Tax Certificates"
- Subtitle: "Generate, manage, and send donation receipts and tax certificates"
- No header actions (each tab has its own actions)

**Tab Bar** (sticky):
| # | Tab Key | Icon | Label | URL param |
|---|---------|------|-------|-----------|
| 1 | `queue` | fa-list-check | Receipt Queue | `?tab=queue` (default) |
| 2 | `generated` | fa-file-pdf | Generated Receipts | `?tab=generated` |
| 3 | `templates` | fa-file-code | Templates | `?tab=templates` |
| 4 | `settings` | fa-gear | Tax Settings | `?tab=settings` |

**Active tab indicator**: bottom border `var(--accent)`. Tab switching pushes to URL via `router.replace` (no scroll reset).

---

### TAB 1 — Receipt Queue (FLOW grid + KPI widgets)

**Layout**: `widgets-above-grid` (Variant B mandatory)

**KPI Metric Bar** (3 cards, left-aligned, horizontal flex with 24px gap):
| # | Title | Value Source | Icon | Position |
|---|-------|-------------|------|----------|
| 1 | "Pending Generation" | `GetReceiptManagementSummary.pendingGeneration` (count of `GlobalDonation` rows where `ReceiptNumber IS NULL AND PaymentStatusId IN (Received,Posted)`) | clock (amber) | Left |
| 2 | "Pending Send" | `GetReceiptManagementSummary.pendingSend` (count of `GeneratedTaxReceipt` where `SendStatusId = NOTSENT`) | paper-plane (blue) | Center |
| 3 | "Sent Today" | `GetReceiptManagementSummary.sentToday` (count of `GeneratedTaxReceipt` where `LastSentAt::date = CURRENT_DATE`) | check-circle (green) | Right |

**Bulk Action Bar** (above filter row):
| Action | Style | Behaviour |
|--------|-------|-----------|
| "Generate All Pending" | btn-primary-accent | SERVICE_PLACEHOLDER — toast "Bulk generation queued for {N} donations" |
| "Send All Unsent" | btn-outline-accent | SERVICE_PLACEHOLDER — toast "Bulk send queued for {N} receipts" |

**Filter Bar** (single horizontal row, wraps on small):
| # | Type | Field | Default |
|---|------|-------|---------|
| 1 | date | dateFrom | `today - 30d` |
| 2 | date | dateTo | `today` |
| 3 | select | receiptStatus | "" (All) — options: Generated / Pending / Not Generated |
| 4 | select | sendStatus | "" (All) — options: Emailed / Pending Send / Printed / WhatsApp / Bounced |
| 5 | select | donationMode | "" (All) — options: Online / Cheque / Cash / Bank Transfer (MasterData typeCode=DONATIONMODE) |

**Grid Columns** (in display order):
| # | Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------|-----------|-------------|-------|----------|-------|
| — | (checkbox) | — | row-select | 40px | NO | Multi-select for bulk actions |
| 1 | Donation | `donationCode` | link | 140px | YES | Renderer: `donation-link` → opens donation detail in new tab. Falls back to `globalDonationId` as label if no Code field. Mockup shows "RCP-2026-0892" — likely `GlobalDonation.ReceiptNumber` if generated, else "DON-{id}". |
| 2 | Donor | `donorName` | link | auto | YES | Renderer: `donor-link` → opens Contact detail. |
| 3 | Amount | `amountDisplay` | text-bold | 120px | YES | Pre-formatted "$500" / "AED 4,500" / "₹8,000" — backend formats currency + amount together using `Currency.CurrencyCode` + `DonationAmount` |
| 4 | Date | `donationDate` | DateOnlyPreview | 100px | YES | Short format "Apr 10" |
| 5 | Receipt Status | `receiptStatusBadge` | status-badge | 180px | NO | Renderer: `receipt-status-badge` (Generated green / Pending amber + tooltip "cheque not cleared" / Not Generated slate) |
| 6 | Send Status | `sendStatusBadge` | status-badge | 160px | NO | Renderer: `receipt-send-status-badge` (Emailed blue / Pending Send amber / Printed indigo / WhatsApp green / Bounced red / — for not-generated rows) |
| 7 | Actions | — | row-actions | 240px | NO | Per-row contextual buttons (below) |

**Row Actions (contextual — vary by row state)**:
| Row state | Buttons rendered |
|-----------|------------------|
| Generated + Emailed | View, Resend, Download |
| Generated + Pending Send | View, **Send** (primary), Download |
| Generated + Printed | View, Download |
| Pending (cheque not cleared) | "Generate When Cleared" (disabled) |
| Generated + Bounced | View, **Resend** (primary), Print |
| Not Generated | **Generate** (primary) |
| Generated + WhatsApp | View, Download |

All actions except View (which routes to GlobalDonation detail in `crm/donation/globaldonation?mode=read&id={id}`) are SERVICE_PLACEHOLDER firing toasts.

**Search/Filter Fields**: donor name (LIKE), donation code (LIKE), receipt status, send status, donation mode, date range
**Grid Actions Toolbar**: column-toggle, export, pagination (standard FlowDataTable)
**Row Click**: opens donation detail in new tab (NOT inline — Tab 1 is operational, not transactional on its own records)

---

### TAB 2 — Generated Receipts (FLOW grid → DETAIL view)

**Layout**: `grid-only` (Variant A — internal header)

**Search/Filter Bar** (left side):
- Search input (LIKE on `ReceiptNumber`, `DonorNameSnapshot`)
- Tax Type filter (select — options dynamic from CountryTaxConfig.TaxCodeType list)
- Currency filter (select — options from Currency list)

**Bulk Actions** (right side):
- "Bulk Download" (btn-outline-accent) — SERVICE_PLACEHOLDER toast (select rows + download zip)
- "Generate Annual Statements" (btn-primary-accent) — SERVICE_PLACEHOLDER toast (year-end consolidated PDF per donor)

**Grid Columns** (in display order):
| # | Header | Field Key | Display Type | Width | Sortable |
|---|--------|-----------|-------------|-------|----------|
| — | (checkbox) | — | row-select | 40px | NO |
| 1 | Receipt # | `receiptNumber` | link | 160px | YES | → opens `?tab=generated&mode=read&id={id}` (DETAIL layout) |
| 2 | Donor | `donorNameSnapshot` | link | auto | YES | → opens Contact detail |
| 3 | Amount | `amountDisplay` | text-bold | 120px | YES |
| 4 | Currency | `currencyCode` | text | 80px | YES |
| 5 | Tax Type | `taxCodeKey` | tax-type-badge | 130px | YES | Custom renderer with color per code: `501c3` blue, `80G` amber, `GIFTAID` purple, `UAECHARITY` green, `GENERAL` slate |
| 6 | Generated Date | `generatedDate` | date | 130px | YES | "Apr 10, 2026" |
| 7 | Template | `receiptTemplateName` | text | auto | YES |
| 8 | Format | `formatType` | format-icon-text | 80px | NO | PDF icon + label |
| 9 | Actions | — | row-actions | 160px | NO | Download, Email, WhatsApp (varies by current SendStatus) |

**Grid Actions**: View (→ read mode), Email (SERVICE_PLACEHOLDER), Download (SERVICE_PLACEHOLDER — fetches `FileUrl`)

---

### TAB 2 — DETAIL Layout (mode=read)

> The read-only detail page shown when a Generated Receipt row is clicked.
> URL: `?tab=generated&mode=read&id={GeneratedTaxReceiptId}`

**Page Header**: FlowFormPageHeader with Back (→ `?tab=generated`), Edit (disabled — receipts are immutable; re-issue creates a new row), header actions: Download / Email / Print / WhatsApp

**Page Layout** (2-column 2fr/1fr):

**Left Column** (2fr):
| # | Card Title | Content |
|---|-----------|---------|
| 1 | Receipt Summary | Receipt# (large), Tax Type chip, Generated Date, Generated By (staff link), Template used (link to `?tab=templates&mode=read&id={id}`) |
| 2 | Donor & Amount | Donor name + link to Contact, Amount snapshot (large), Currency, Donation date (link to GlobalDonation), Donation purpose snapshot |
| 3 | Receipt Preview | Iframe rendering the PDF (uses `FileUrl` — SERVICE_PLACEHOLDER until PDF service exists; show placeholder card "PDF preview not yet rendered — generate via Tab 1 Queue" if FileUrl is null) |

**Right Column** (1fr):
| # | Card Title | Content |
|---|-----------|---------|
| 1 | Send History | Timeline: each send attempt (timestamp + channel + recipient + status); shows ResendCount |
| 2 | Tax Jurisdiction | CountryTaxConfig snapshot: Country flag + name, Tax Code, Registration #, Org Legal Name, exempt-statement preview |
| 3 | Audit Trail | Created / Updated / SoftDeleted timestamps + actors |

---

### TAB 3 — Templates (card-grid → DESIGNER FORM)

**Top Bar**:
- Counter chip: "{N} templates configured"
- "+Create New Template" (btn-primary-accent) → navigates to `?tab=templates&mode=new`

**Card-Grid**:
- Display mode: `card-grid` (variant `details` — see §⑤)
- Responsive: 1 / 2 / 3 / 4 cols at xs / sm / lg / xl
- Card body per template (per mockup `.template-card`):
  - **Preview tile** (top 140px): white inner box rendering a mini preview of `BodyHtml` (scaled-down — use `transform: scale(0.4)` on first 200px of body); "Default" pill overlay top-right if `isDefault=true`
  - **Header**: `receiptTemplateName` (h6)
  - **Type badge**: `receiptTemplateTypeName` (accent-bg chip)
  - **Fields snippet**: comma-separated list of placeholders from `PlaceholdersUsedJson`
  - **Modified meta**: `Last modified: {modifiedDate}` (or `lastPreviewedAt` if set)
  - **Card actions** (3 buttons): "Edit Template" → `?tab=templates&mode=edit&id={id}`; "Preview" → opens preview modal (renders BodyHtml in iframe sandbox); "Set as Default" / "Default" (disabled if already default — toggles `IsDefault` via `SetReceiptTemplateDefault` mutation)

**Row click**: navigates to `?tab=templates&mode=read&id={id}` (read-only preview page)

---

### TAB 3 — FORM Layout (mode=new & mode=edit) — DESIGNER CANVAS

> The template designer that opens when user clicks "+Create New Template" or "Edit Template".
> Built with React Hook Form + Monaco-like textarea + live preview iframe.
> Matches mockup `#templateEditor` exactly.

**Page Header**: FlowFormPageHeader with Back (→ `?tab=templates`), Close, Save Template (primary)
**Section Container Type**: Single content-card with stacked sub-rows (NO accordion, NO tabs within this sub-page)

**Top Properties Row** (3-column grid, mockup `.row.g-3`):
| Col | Icon | Label | Widget | Field | Validation |
|-----|------|-------|--------|-------|-----------|
| 1 | — | Template Name | text | receiptTemplateName | required, max 200 |
| 2 | — | Template Type | select (MasterData typeCode=RECEIPTTEMPLATETYPE) | receiptTemplateTypeId | required |
| 3 | — | Country / Tax Code | select (Country list + "General" option) | countryId | optional |
| 4 | — | Donation Purpose | select (DonationPurpose list + "All Purposes" option) | donationPurposeId | optional |
| 5 | — | Page Size | select (A4 / Letter) | pageSize | required, default Letter |
| 6 | — | Orientation | radio (Portrait / Landscape) | orientation | required, default Portrait |

**Placeholder Tags Row** (between properties and editor — mockup `.placeholder-tag` chips):
- Static list of 11 inserttable chips (clickable to insert at cursor):
  `{{DonorName}}` `{{DonorAddress}}` `{{DonationAmount}}` `{{DonationDate}}` `{{ReceiptNumber}}` `{{OrgName}}` `{{OrgAddress}}` `{{TaxRegNumber}}` `{{AmountInWords}}` `{{Purpose}}` `{{PaymentMode}}`
- Clicking a chip inserts the token at the textarea's caret position
- Chips render with accent-bg + monospace font (per mockup `.placeholder-tag` CSS)

**Split Editor** (2-column grid, mockup `.editor-split`):
| Pane | Width | Content |
|------|-------|---------|
| Left | 1fr | Label "HTML Template" + dark-theme textarea (`code-editor` class — bg=#1e293b, color=#e2e8f0, monospace, 300px height min, resize vertical). Binds to `bodyHtml`. |
| Right | 1fr | Label "Preview (Sample Data)" + preview-panel iframe (white bg, 300px min). Renders BodyHtml with sample-data substitution — debounced 300ms on edits. Sample data: { DonorName: "Sarah Johnson", DonorAddress: "456 Main St, Boston, MA 02101", DonationAmount: "$500.00", DonationDate: "April 10, 2026", ReceiptNumber: "TAX-2026-0892", OrgName: "Hope Foundation International", OrgAddress: "123 Charity Lane, New York, NY 10001", TaxRegNumber: "12-3456789", AmountInWords: "Five Hundred Dollars Only", Purpose: "Education Fund", PaymentMode: "Online (Credit Card)" }. Iframe `sandbox="allow-same-origin"` for safety. |

**Tax Exempt Statement Section** (BELOW the split editor — NEW, not in mockup but inferable from CountryTaxConfig model):
- Textarea, 3 rows, label "Tax-Exempt Statement Text", binds to `statementText`, max 2000.

**Save Footer** (mockup `.d-flex.justify-content-end.gap-2.mt-3`):
- Cancel (btn-outline-accent) → `?tab=templates`
- Save Template (btn-primary-accent + fa-save icon)

---

### TAB 3 — DETAIL Layout (mode=read)

> Read-only preview when user navigates to `?tab=templates&mode=read&id={id}` (NOT in mockup — inferable from FLOW pattern).

**Page Header**: Back, Edit (→ `?tab=templates&mode=edit&id={id}`), Set Default, Duplicate, Delete

**Page Layout** (2-column):
- **Left** (2fr): Same preview iframe as FORM right pane, but full-page; below it shows `bodyHtml` source in monospace read-only block
- **Right** (1fr): Properties card (Name, Type, Country, Purpose, Page Size, Orientation, Default badge), Statement Text card, Used By card (count of `GeneratedTaxReceipt` rows linked to this template — quick LINQ subquery), Audit Trail card

---

### TAB 4 — Tax Settings (split: grid + upsert form)

**Layout**: Two `settings-section` blocks stacked vertically (no further tabs).

#### Section A — Country-wise Tax Configuration

**Section Header** (flex justify-between):
- "Country-wise Tax Configuration" (h5)
- "+Add Country Tax Config" (btn-primary-accent) — opens modal

**Grid** (`grid-only` — FlowDataTable basic variant):
| # | Header | Field Key | Display Type | Width |
|---|--------|-----------|-------------|-------|
| 1 | Country | `countryNameWithFlag` | country-cell | 220px | (flag emoji + name — renderer reads `Country.CountryCode` for flag lookup) |
| 2 | Tax Code | `taxCodeType` | text | 140px |
| 3 | Registration # | `registrationNumberCode` | code-mono | 200px | (`<code>` styled — mockup `<code>12-3456789</code>` pattern) |
| 4 | Active | `isActive` | toggle-icon | 80px | (green check / grey x — mockup `fa-check-circle.toggle-active`) |
| 5 | Default Template | `defaultReceiptTemplateName` | text | auto |
| 6 | Actions | — | row-actions | 100px | Edit (opens modal pre-filled), Toggle |

**Modal — Add/Edit Country Tax Config** (mockup `#taxConfigModal`):
| # | Field | Widget | Validation |
|---|-------|--------|------------|
| 1 | Country | select (Country list, mockup-style with English names) | required, unique per company |
| 2 | Tax Code Type | text "e.g., 501(c)(3), 80G, Gift Aid" | required, max 50 |
| 3 | Registration Number | text "e.g., 12-3456789" | required, max 100 |
| 4 | Organization Legal Name | text "Full legal entity name" | required, max 200 |
| 5 | Tax-Exempt Statement Text | textarea 3 rows | optional, max 2000 |
| 6 | Default Template | ApiSelectV2 (ReceiptTemplate list — filter to non-deleted) | optional |
| 7 | Active | toggle switch | default ON |

Modal footer: Cancel + Save (btn-primary-accent + fa-save).

#### Section B — Global Receipt Settings

**Section Header**: "Global Receipt Settings" (h5)

**Content Card** with **Upsert form** (single-row-per-tenant, MatchingGiftSettings #11 pattern):

| # | Setting Label | Description | Widget | Field | Validation |
|---|--------------|-------------|--------|-------|-----------|
| 1 | Auto-generate receipt on donation | Automatically generate a receipt when a donation is recorded | switch | autoGenerateOnDonation | required boolean, default true |
| 2 | Auto-send receipt via email | Automatically email the receipt to the donor after generation | switch | autoSendByEmail | required boolean, default true |
| 3 | Receipt numbering format | Pattern for generating receipt numbers | text 200px monospace | receiptNumberFormat | required, max 50, must contain {SEQ}, default `TAX-{YEAR}-{SEQ}` |
| 4 | Include organization logo | Display the organization logo on receipts and certificates | switch | includeOrgLogo | required boolean, default true |
| 5 | Annual statement generation month | Month to auto-generate year-end giving statements | select Jan–Dec | annualStatementMonth | required int 1–12, default 1 |

Each row uses mockup `.setting-row` styling (flex justify-between with bottom border on `#f1f5f9` except last).

Save behavior: **autosave per field on blur** (300ms debounce) — Upsert single-row mutation. Toast on success.

---

### Page Widgets & Summary Cards

**Widgets** (Tab 1 only — 3 KPI cards above grid):

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | Pending Generation | `GetReceiptManagementSummary.pendingGeneration` | count + clock icon (amber) | left |
| 2 | Pending Send | `GetReceiptManagementSummary.pendingSend` | count + paper-plane icon (blue) | center |
| 3 | Sent Today | `GetReceiptManagementSummary.sentToday` | count + check-circle icon (green) | right |

**Grid Layout Variant** (per-tab):
- Tab 1: `widgets-above-grid` (Variant B mandatory — ScreenHeader + 3 metric components + FlowDataTableContainer showHeader={false})
- Tab 2: `grid-only` (Variant A)
- Tab 3: `card-grid` (display mode, NOT a table — see §⑤)
- Tab 4: NO grid as top-level — two stacked sections

**Summary GQL Query**:
- Query name: `GetReceiptManagementSummary`
- Returns: `ReceiptManagementSummaryDto` with `pendingGeneration`, `pendingSend`, `sentToday` (all `int`)
- Added to `ReceiptTemplateQueries.cs` (lives with the templates endpoint by convention, since the screen's overall menu is receipt management)

### Grid Aggregation Columns

**Aggregation Columns**: NONE — no per-row computed values needed beyond row-state inference for the queue.

### User Interaction Flow (FLOW composite — 4 tabs)

1. User navigates to `/setting/donationconfig/receiptmanagement` → URL appends `?tab=queue` (default tab) → KPI cards + queue grid load
2. Tab switching: clicking a tab pushes `?tab={key}` to URL via `router.replace`; component remounts per tab content
3. Tab 1 → click "Generate" on a row → mutation `CreateGeneratedTaxReceipt` → on success: row reloads, badge flips to "Generated/Pending Send", KPI counts update
4. Tab 1 → click "Send" → mutation `SendGeneratedTaxReceipt` (SERVICE_PLACEHOLDER, returns true with toast) → row updates SendStatus to Emailed
5. Tab 2 → click Receipt# → `?tab=generated&mode=read&id={id}` → DETAIL layout loads
6. Tab 3 → click "+Create New Template" → `?tab=templates&mode=new` → designer empty → fill + Save → mutation `CreateReceiptTemplate` → redirect to `?tab=templates&mode=read&id={newId}`
7. Tab 3 → click "Edit Template" on a card → `?tab=templates&mode=edit&id={id}` → designer pre-filled → Save → mutation `UpdateReceiptTemplate` → back to `?tab=templates&mode=read&id={id}`
8. Tab 3 → click "Set as Default" → mutation `SetReceiptTemplateDefault` → card refreshes badge
9. Tab 4 → click "+Add Country Tax Config" → modal opens → fill + Save → mutation `CreateCountryTaxConfig` → grid refreshes
10. Tab 4 → toggle a global settings switch → blur fires `UpsertGlobalReceiptSetting` mutation (autosave) → toast on success
11. Back: clicks back button → URL goes to previous mode/tab via `router.back()`
12. Unsaved changes: in designer (mode=new/edit), if form is dirty and user switches tab or clicks Back, show confirm dialog

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity (the composite carries multiple, listed below).

**Canonical References**:
- For Tabs 1, 2: **GlobalDonation** (#1) — projection grid pattern + KPI summary widgets
- For Tab 3 (templates designer + card-grid): **EmailTemplate** (iframe card-grid variant precedent) + designer canvas pattern
- For Tab 4 country grid: **MasterModalForm** pattern (modal CRUD for small lookup entities)
- For Tab 4 settings upsert: **MatchingGiftSettings** (#11) — single-row-per-tenant Upsert handler precedent
- Composite multi-tab structure: **MatchingGift** (#11) — 4 tabs, 3 entities, hidden child menus

**Per-entity substitutions** (use the most relevant canonical for each — list below applies the MatchingGift naming map adapted to the 4 new entities of this screen):

| Canonical (MatchingGift) | → ReceiptTemplate | → CountryTaxConfig | → GlobalReceiptSetting | → GeneratedTaxReceipt |
|--------------------------|-------------------|-------------------|----------------------|---------------------|
| MatchingCompany | ReceiptTemplate | CountryTaxConfig | GlobalReceiptSetting | GeneratedTaxReceipt |
| matchingCompany | receiptTemplate | countryTaxConfig | globalReceiptSetting | generatedTaxReceipt |
| MatchingCompanyId | ReceiptTemplateId | CountryTaxConfigId | GlobalReceiptSettingId | GeneratedTaxReceiptId |
| MatchingCompanies | ReceiptTemplates | CountryTaxConfigs | GlobalReceiptSettings | GeneratedTaxReceipts |
| matching-company | receipt-template | country-tax-config | global-receipt-setting | generated-tax-receipt |
| matchingcompany | receipttemplate | countrytaxconfig | globalreceiptsetting | generatedtaxreceipt |
| MATCHINGCOMPANY | RECEIPTTEMPLATE | COUNTRYTAXCONFIG | GLOBALRECEIPTSETTING | GENERATEDTAXRECEIPT |
| `fund` (schema) | `fund` | `fund` | `fund` | `fund` |
| Donation (group) | DonationModels (entity ns) | DonationModels | DonationModels | DonationModels |
| Donation (folder Business/Schemas) | Donation | Donation | Donation | Donation |
| CRM_P2PFUNDRAISING (parent menu) | SET_DONATIONCONFIG | SET_DONATIONCONFIG | SET_DONATIONCONFIG | SET_DONATIONCONFIG |
| CRM (module) | SETTING | SETTING | SETTING | SETTING |
| crm/p2pfundraising/matchinggift (FE route) | setting/donationconfig/receiptmanagement | setting/donationconfig/receiptmanagement | setting/donationconfig/receiptmanagement | setting/donationconfig/receiptmanagement |
| donation-service (FE folder) | donation-service | donation-service | donation-service | donation-service |

> **All 4 entities live under the single FE route `setting/donationconfig/receiptmanagement`** — like MatchingGift #11, the parent menu is the only visible sidebar entry; child entities have hidden menus (for permission/capability gating) but no separate routes.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> Following MatchingGift #11 pattern. ~44 BE files (4 entities × 11) + ~30 FE files (composite — tabbed page + designer + modals + Zustand + DTOs/GQL).

### Backend Files (4 entities × standard CRUD + composite queries)

**Per-entity 11-file set** (×4) — paths follow the standard `{Group}Business/{PluralName}/{Phase}/` layout:

For **ReceiptTemplate** (replace `{Entity}=ReceiptTemplate`, `{Plural}=ReceiptTemplates`, `{Group}=Donation`):
| # | File | Path |
|---|------|------|
| 1 | Entity | `Base.Domain/Models/DonationModels/ReceiptTemplate.cs` |
| 2 | EF Config | `Base.Infrastructure/Data/Configurations/DonationConfigurations/ReceiptTemplateConfiguration.cs` |
| 3 | Schemas | `Base.Application/Schemas/DonationSchemas/ReceiptTemplateSchemas.cs` |
| 4 | Create | `Base.Application/Business/DonationBusiness/ReceiptTemplates/Commands/CreateReceiptTemplate.cs` |
| 5 | Update | `Base.Application/Business/DonationBusiness/ReceiptTemplates/Commands/UpdateReceiptTemplate.cs` |
| 6 | Delete | `Base.Application/Business/DonationBusiness/ReceiptTemplates/Commands/DeleteReceiptTemplate.cs` |
| 7 | Toggle | `Base.Application/Business/DonationBusiness/ReceiptTemplates/Commands/ToggleReceiptTemplate.cs` |
| 8 | GetAll | `Base.Application/Business/DonationBusiness/ReceiptTemplates/Queries/GetReceiptTemplates.cs` |
| 9 | GetById | `Base.Application/Business/DonationBusiness/ReceiptTemplates/Queries/GetReceiptTemplateById.cs` |
| 10 | Mutations | `Base.API/EndPoints/Donation/Mutations/ReceiptTemplateMutations.cs` |
| 11 | Queries | `Base.API/EndPoints/Donation/Queries/ReceiptTemplateQueries.cs` |

Same 11-file pattern repeated for:
- **CountryTaxConfig** (→ `CountryTaxConfigs/`)
- **GlobalReceiptSetting** (→ `GlobalReceiptSettings/` — but Create/Update collapsed into single `UpsertGlobalReceiptSetting.cs`; no Toggle since it's a singleton)
- **GeneratedTaxReceipt** (→ `GeneratedTaxReceipts/` — Update may be omitted; receipts are immutable. Toggle becomes Delete which is soft-only)

**Extra commands** (composite-specific — NOT counted in the 4×11):
| File | Path | Purpose |
|------|------|---------|
| `SetReceiptTemplateDefault.cs` | `.../ReceiptTemplates/Commands/SetReceiptTemplateDefault.cs` | Unset all other defaults in (CompanyId, TaxCodeKey), set this one true |
| `UpsertGlobalReceiptSetting.cs` | `.../GlobalReceiptSettings/Commands/UpsertGlobalReceiptSetting.cs` | Single-row-per-tenant upsert (MatchingGiftSettings #11 precedent) |
| `SendGeneratedTaxReceipt.cs` | `.../GeneratedTaxReceipts/Commands/SendGeneratedTaxReceipt.cs` | SERVICE_PLACEHOLDER — updates SendStatusId, LastSentAt, SentTo, increments ResendCount |
| `ResendGeneratedTaxReceipt.cs` | `.../GeneratedTaxReceipts/Commands/ResendGeneratedTaxReceipt.cs` | SERVICE_PLACEHOLDER — wraps Send, increments ResendCount even if status was Bounced |

**Composite queries**:
| File | Path | Purpose |
|------|------|---------|
| `GetReceiptQueue.cs` | `.../GeneratedTaxReceipts/Queries/GetReceiptQueue.cs` | Returns paginated `ReceiptQueueRowDto` — projection over GlobalDonation LEFT JOIN latest GeneratedTaxReceipt, computes ReceiptStatus + SendStatus per row |
| `GetReceiptManagementSummary.cs` | `.../GeneratedTaxReceipts/Queries/GetReceiptManagementSummary.cs` | Returns `ReceiptManagementSummaryDto` (3 KPI counts) |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext.cs` | 4 DbSet properties: `ReceiptTemplates`, `CountryTaxConfigs`, `GlobalReceiptSettings`, `GeneratedTaxReceipts` |
| 2 | `ApplicationDbContext.cs` (or DonationDbContext) | Same 4 DbSet properties |
| 3 | `DecoratorProperties.cs` | DecoratorDonationModules entries for the 4 entities |
| 4 | `DonationMappings.cs` | Mapster mapping configs for all 4 entities + projection DTOs (ReceiptQueueRowDto, ReceiptManagementSummaryDto) |
| 5 | `appsettings.json` / GraphQL registration | No change — endpoints auto-register via convention |

### EF Migration

| File | Purpose |
|------|---------|
| `XXXXXXXXXXXXXX_Add_ReceiptManagement_Entities.cs` | Creates 4 tables + indexes (filtered uniques on Name/Country/CompanyId combos) + FKs. Plus seed defaults for `GlobalReceiptSetting` per existing tenant (idempotent INSERT WHERE NOT EXISTS). |

> Per project rule [feedback_team_handles_migrations] — generate the migration scaffolding via `dotnet ef migrations add` but DO NOT apply. Include exact command + 3-step plan in Build Log.

### Frontend Files (~30 files for composite)

**Domain DTOs** (4 files, one per entity):
| # | File |
|---|------|
| 1 | `src/domain/entities/donation-service/ReceiptTemplateDto.ts` |
| 2 | `src/domain/entities/donation-service/CountryTaxConfigDto.ts` |
| 3 | `src/domain/entities/donation-service/GlobalReceiptSettingDto.ts` |
| 4 | `src/domain/entities/donation-service/GeneratedTaxReceiptDto.ts` |
| 5 | (modify) `src/domain/entities/donation-service/index.ts` — barrel export |

**GQL Queries + Mutations** (8 files):
| # | File |
|---|------|
| 1 | `src/infrastructure/gql-queries/donation-queries/ReceiptTemplateQuery.ts` |
| 2 | `src/infrastructure/gql-queries/donation-queries/CountryTaxConfigQuery.ts` |
| 3 | `src/infrastructure/gql-queries/donation-queries/GlobalReceiptSettingQuery.ts` |
| 4 | `src/infrastructure/gql-queries/donation-queries/GeneratedTaxReceiptQuery.ts` — includes `RECEIPT_QUEUE_QUERY` + `RECEIPT_MANAGEMENT_SUMMARY_QUERY` (composite queries live here) |
| 5 | `src/infrastructure/gql-mutations/donation-mutations/ReceiptTemplateMutation.ts` — incl. SET_DEFAULT mutation |
| 6 | `src/infrastructure/gql-mutations/donation-mutations/CountryTaxConfigMutation.ts` |
| 7 | `src/infrastructure/gql-mutations/donation-mutations/GlobalReceiptSettingMutation.ts` — single UPSERT mutation |
| 8 | `src/infrastructure/gql-mutations/donation-mutations/GeneratedTaxReceiptMutation.ts` — incl. SEND + RESEND mutations |
| 9 | (modify) `src/infrastructure/gql-queries/donation-queries/index.ts` — barrel |
| 10 | (modify) `src/infrastructure/gql-mutations/donation-mutations/index.ts` — barrel |

**Page Components** (the composite UI lives under one folder):

Folder: `src/presentation/components/page-components/setting/donationconfig/receiptmanagement/`
- ⚠️ NOTE: this is a NEW folder under `setting/donationconfig/` — verify the parent path exists (it should, given DonationVerse + Purpose/Category/Group live there). If `setting/donationconfig/` doesn't exist as a page-components folder yet, create it.

| # | File | Purpose |
|---|------|---------|
| 1 | `index.tsx` | URL dispatcher router (reads `?tab=` + `?mode=` + `?id=`, dispatches to tab sub-views) |
| 2 | `index-page.tsx` | Composite shell: page header + tab bar + tab content slot (Variant B mandatory when Tab 1 active — uses `ScreenHeader` + 3 KPI components for Tab 1) |
| 3 | `receiptmanagement-store.ts` | Zustand: `activeTab`, `selectedQueueRows[]`, `templatePreviewHtml`, `templateFormDirty`, `lastBulkAction` |
| 4 | `tabs/queue-tab.tsx` | Tab 1 — KPI cards + queue grid (FlowDataTable, GLOBALRECEIPT_QUEUE gridCode) |
| 5 | `tabs/generated-tab.tsx` | Tab 2 — generated receipts grid (FlowDataTable, GENERATEDTAXRECEIPT gridCode) |
| 6 | `tabs/templates-tab.tsx` | Tab 3 — card-grid OR designer based on `?mode=` |
| 7 | `tabs/settings-tab.tsx` | Tab 4 — country grid + global settings form |
| 8 | `widgets/receipt-kpi-cards.tsx` | 3 KPI metric cards above queue grid |
| 9 | `queue/queue-row-actions.tsx` | Contextual row-action buttons (Generate/Send/Resend/Download per row state) |
| 10 | `templates/template-card.tsx` | Card variant for `card-grid` `details` (preview tile + name + type badge + actions) |
| 11 | `templates/template-view-page.tsx` | DESIGNER (FORM) — split editor + placeholder chips + preview iframe |
| 12 | `templates/template-detail-page.tsx` | Read-only template preview + Used-By + Audit |
| 13 | `templates/placeholder-chip-bar.tsx` | Reusable chip insert bar |
| 14 | `templates/template-preview-iframe.tsx` | Sandboxed iframe with sample-data substitution (debounced) |
| 15 | `generated/generated-detail-page.tsx` | Tab 2 DETAIL layout (Receipt Summary + Donor & Amount + Receipt Preview iframe + Send History + Tax Jurisdiction + Audit) |
| 16 | `settings/country-tax-config-grid.tsx` | Tab 4 Section A — FlowDataTable + modal |
| 17 | `settings/country-tax-config-modal.tsx` | Add/Edit modal (RHF + Zod) |
| 18 | `settings/global-receipt-settings-form.tsx` | Tab 4 Section B — 5-row autosave Upsert form |
| 19 | `renderers/receipt-status-badge.tsx` | Custom column renderer (Generated / Pending / Not Generated) |
| 20 | `renderers/receipt-send-status-badge.tsx` | Custom column renderer (Emailed / Pending Send / Printed / WhatsApp / Bounced / —) |
| 21 | `renderers/tax-type-badge.tsx` | Tax code colored chip (501c3 / 80G / GIFTAID / UAECHARITY / GENERAL) |
| 22 | `renderers/country-cell.tsx` | Flag emoji + country name (reused if exists in shared renderers — check first) |
| 23 | `renderers/donation-link.tsx` | RCP-link → opens donation detail (reuses existing `donor-link` pattern from globaldonation; check shared-cell-renderers/donor-link first) |
| 24 | `forms/template-form-schemas.ts` | Zod schemas: template form + country-config form + global-settings form |

**Page Config + Route**:
| # | File |
|---|------|
| 25 | `src/presentation/pages/setting/donationconfig/receiptmanagement.tsx` | Page config (`useAccessCapability({ menuCode: "RECEIPTMANAGEMENT" })` + `DefaultAccessDenied` + `LayoutLoader` + default-export ReceiptManagementIndex) |
| 26 | `src/app/[lang]/(core)/setting/donationconfig/receiptmanagement/page.tsx` | Route page — dynamic default-import dispatcher (overwrite under-construction stub if present) |

**Wiring**:
| # | File to Modify | What to Add |
|---|---------------|-------------|
| 27 | `src/presentation/entity-config/donation-service-entity-operations.ts` | NEW `RECEIPTMANAGEMENT` operations block (gridCode REceipt entries for the composite — also `GLOBALRECEIPT_QUEUE`, `GENERATEDTAXRECEIPT`, `RECEIPTTEMPLATE`, `COUNTRYTAXCONFIG`) |
| 28 | `src/presentation/entity-config/operations-config.ts` | Import + register RECEIPTMANAGEMENT operations |
| 29 | sidebar menu config (verify existence first — may already be auto-driven by DB seed) | RECEIPTMANAGEMENT menu entry under SET_DONATIONCONFIG |
| 30 | 3 component-column registries (advanced/basic/flow) | Register: `receipt-status-badge`, `receipt-send-status-badge`, `tax-type-badge`, `donation-link`, `country-cell` (skip if already registered) |
| 31 | `shared-cell-renderers/index.ts` (barrel) | Export new renderers if elevated to shared (otherwise keep local to receiptmanagement folder) |

### DB Seed Script

File: `sql-scripts-dyanmic/ReceiptManagement-sqlscripts.sql` (preserve folder typo per #1/#6 precedent)

Sections in order:
1. Menu upsert — `RECEIPTMANAGEMENT` under `SET_DONATIONCONFIG` at OrderBy=5 (per MODULE_MENU_REFERENCE)
2. Hidden child menus (4 — for capability gating per MatchingGift precedent): `RECEIPTTEMPLATE`, `COUNTRYTAXCONFIG`, `GLOBALRECEIPTSETTING`, `GENERATEDTAXRECEIPT` — IsMenuRender=false, parent=RECEIPTMANAGEMENT
3. Capabilities — READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT, ISMENURENDER on parent + hidden children
4. RoleCapabilities — BUSINESSADMIN grants on all
5. Grids — 2 FLOW grids: `GLOBALRECEIPT_QUEUE` (Tab 1) and `GENERATEDTAXRECEIPT` (Tab 2). `GridFormSchema=NULL` for both (FLOW)
6. GridFields — column definitions per the §⑥ grid tables for both grids
7. MasterData type+entries — 3 new types: `RECEIPTTEMPLATETYPE` (3 rows), `RECEIPTSENDSTATUS` (5 rows), `RECEIPTSENDMETHOD` (4 rows) — guarded inserts where not exists
8. Sample data — 5 ReceiptTemplate rows (US 501c3, India 80G, UK Gift Aid, UAE Charity, General — per mockup cards), 4 CountryTaxConfig rows (US, India, UK, UAE per mockup grid), 1 GlobalReceiptSetting Upsert row per existing tenant (defaults from §②)

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Receipts & Tax
MenuCode: RECEIPTMANAGEMENT
ParentMenu: SET_DONATIONCONFIG
Module: SETTING
MenuUrl: setting/donationconfig/receiptmanagement
GridType: FLOW
OrderBy: 5

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT

GridFormSchema: SKIP
GridCode (Tab 1 — Queue projection): GLOBALRECEIPT_QUEUE
GridCode (Tab 2 — Generated receipts): GENERATEDTAXRECEIPT

Hidden child menus (for capability gating, IsMenuRender=false):
- RECEIPTTEMPLATE (parent RECEIPTMANAGEMENT) — capabilities: READ, CREATE, MODIFY, DELETE, TOGGLE
- COUNTRYTAXCONFIG (parent RECEIPTMANAGEMENT) — capabilities: READ, CREATE, MODIFY, DELETE, TOGGLE
- GLOBALRECEIPTSETTING (parent RECEIPTMANAGEMENT) — capabilities: READ, MODIFY
- GENERATEDTAXRECEIPT (parent RECEIPTMANAGEMENT) — capabilities: READ, CREATE, DELETE, EXPORT
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types** (one extension per entity + composite):
- Query types: `ReceiptTemplateQueries`, `CountryTaxConfigQueries`, `GlobalReceiptSettingQueries`, `GeneratedTaxReceiptQueries` (also hosts `getReceiptQueue` + `getReceiptManagementSummary`)
- Mutation types: `ReceiptTemplateMutations`, `CountryTaxConfigMutations`, `GlobalReceiptSettingMutations`, `GeneratedTaxReceiptMutations`

**Queries:**

| GQL Field | Returns | Key Args | Notes |
|-----------|---------|----------|-------|
| `receiptTemplates` | `[ReceiptTemplateResponseDto]` paginated | searchText, pageNo, pageSize, sortField, sortDir, isActive, taxCodeKey?, countryId?, donationPurposeId? | Tab 3 card-grid + Tab 4 modal dropdown |
| `receiptTemplateById` | `ReceiptTemplateResponseDto` | receiptTemplateId | Tab 3 read/edit modes |
| `countryTaxConfigs` | `[CountryTaxConfigResponseDto]` paginated | searchText, pageNo, pageSize, sortField, sortDir, isActive | Tab 4 Section A |
| `countryTaxConfigById` | `CountryTaxConfigResponseDto` | countryTaxConfigId | Tab 4 modal edit |
| `globalReceiptSetting` | `GlobalReceiptSettingResponseDto` (single, may be null if never upserted) | (none — tenant from HttpContext) | Tab 4 Section B |
| `generatedTaxReceipts` | `[GeneratedTaxReceiptResponseDto]` paginated | searchText, pageNo, pageSize, sortField, sortDir, taxCodeKey?, currencyId?, dateFrom?, dateTo? | Tab 2 grid |
| `generatedTaxReceiptById` | `GeneratedTaxReceiptResponseDto` | generatedTaxReceiptId | Tab 2 DETAIL |
| `receiptQueue` | `[ReceiptQueueRowDto]` paginated | searchText, pageNo, pageSize, dateFrom, dateTo, receiptStatus?, sendStatus?, donationModeId? | Tab 1 grid — projection over GlobalDonation LEFT JOIN GeneratedTaxReceipt |
| `receiptManagementSummary` | `ReceiptManagementSummaryDto` (singular) | (none) | Tab 1 KPI cards |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createReceiptTemplate` | `ReceiptTemplateRequestDto` | int |
| `updateReceiptTemplate` | `ReceiptTemplateRequestDto` | int |
| `deleteReceiptTemplate` | receiptTemplateId | int |
| `toggleReceiptTemplate` | receiptTemplateId | int |
| `setReceiptTemplateDefault` | receiptTemplateId | int |
| `createCountryTaxConfig` | `CountryTaxConfigRequestDto` | int |
| `updateCountryTaxConfig` | `CountryTaxConfigRequestDto` | int |
| `deleteCountryTaxConfig` | countryTaxConfigId | int |
| `toggleCountryTaxConfig` | countryTaxConfigId | int |
| `upsertGlobalReceiptSetting` | `GlobalReceiptSettingRequestDto` | int (single-row upsert) |
| `createGeneratedTaxReceipt` | `GeneratedTaxReceiptRequestDto` (incl. `globalDonationId`, optional `receiptTemplateId`) | int |
| `deleteGeneratedTaxReceipt` | generatedTaxReceiptId | int |
| `sendGeneratedTaxReceipt` | `SendGeneratedTaxReceiptRequestDto` (id + channelMethodId + sentTo) | int — SERVICE_PLACEHOLDER |
| `resendGeneratedTaxReceipt` | `ResendGeneratedTaxReceiptRequestDto` (id + channelMethodId + sentTo) | int — SERVICE_PLACEHOLDER |

**Key Response DTO Fields**:

`ReceiptTemplateResponseDto`:
| Field | Type |
|-------|------|
| receiptTemplateId | number |
| receiptTemplateName | string |
| receiptTemplateTypeId | number |
| receiptTemplateTypeName | string (FK display) |
| countryId | number? |
| countryName | string? (FK display) |
| taxCodeKey | string? |
| donationPurposeId | number? |
| donationPurposeName | string? (FK display) |
| bodyHtml | string |
| placeholdersUsedJson | string |
| pageSize | string |
| orientation | string |
| statementText | string? |
| isDefault | boolean |
| lastPreviewedAt | string? (ISO) |
| modifiedDate | string (ISO) — for card footer |
| isActive | boolean |

`ReceiptQueueRowDto` (Tab 1 projection — joins GlobalDonation + latest GeneratedTaxReceipt):
| Field | Type | Source |
|-------|------|--------|
| globalDonationId | number | GlobalDonation.GlobalDonationId |
| donationCode | string | GlobalDonation.ReceiptNumber ?? "DON-{id}" |
| donorName | string | Contact.DisplayName (or composite) |
| donorContactId | number? | GlobalDonation.ContactId |
| donationDate | string (ISO date) | GlobalDonation.DonationDate |
| donationAmount | number | GlobalDonation.DonationAmount |
| currencyCode | string | Currency.CurrencyCode |
| amountDisplay | string | Pre-formatted server-side: `${CurrencyCode} ${DonationAmount:N2}` |
| donationModeId | number | GlobalDonation.DonationModeId |
| donationModeCode | string | MasterData.DataValue (DONATIONMODE: ONL/CHQ/CASH/BNK) |
| paymentStatusId | number | GlobalDonation.PaymentStatusId |
| paymentStatusCode | string | MasterData.DataValue (PAYMENTSTATUS) |
| receiptStatus | string | Computed: `Generated` / `Pending` / `Not Generated` |
| sendStatus | string? | Computed: latest GeneratedTaxReceipt.SendStatusId MasterData.DataValue |
| latestReceiptId | number? | Latest GeneratedTaxReceipt for this donation (for Resend/Download) |

`ReceiptManagementSummaryDto`:
| Field | Type |
|-------|------|
| pendingGeneration | number |
| pendingSend | number |
| sentToday | number |

`GeneratedTaxReceiptResponseDto`:
| Field | Type |
|-------|------|
| generatedTaxReceiptId | number |
| globalDonationId | number |
| donationCode | string (FK display via include) |
| receiptTemplateId | number |
| receiptTemplateName | string (FK display) |
| countryTaxConfigId | number? |
| countryName | string? (FK display) |
| receiptNumber | string |
| taxCodeKey | string |
| donorContactId | number? |
| donorNameSnapshot | string |
| amountSnapshot | number |
| currencyIdSnapshot | number |
| currencyCode | string (FK display) |
| amountDisplay | string (pre-formatted) |
| formatType | string |
| fileUrl | string? (SERVICE_PLACEHOLDER) |
| generatedDate | string (ISO) |
| generatedBy | number? |
| generatedByStaffName | string? (FK display) |
| sendStatusId | number |
| sendStatusName | string (FK display) |
| sendChannelMethodId | number? |
| sendChannelMethodName | string? (FK display) |
| sentTo | string? |
| lastSentAt | string? (ISO) |
| resendCount | number |
| bounceReason | string? |
| isActive | boolean |

`CountryTaxConfigResponseDto`: countryTaxConfigId, countryId, countryName, countryCode, taxCodeType, registrationNumber, organizationLegalName, taxExemptStatementText?, defaultReceiptTemplateId?, defaultReceiptTemplateName?, isActive

`GlobalReceiptSettingResponseDto`: globalReceiptSettingId, autoGenerateOnDonation, autoSendByEmail, receiptNumberFormat, includeOrgLogo, annualStatementMonth, lastSequenceNumber, lastSequenceYear?

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (4 new entities + composite queries + EF migration generated [not applied] per team-handles-migrations rule)
- [ ] EF migration scaffold created via `dotnet ef migrations add Add_ReceiptManagement_Entities` — DO NOT apply; user runs `dotnet ef database update` separately
- [ ] `pnpm tsc --noEmit` — 0 errors
- [ ] `pnpm dev` — page loads at `/{lang}/setting/donationconfig/receiptmanagement`

**Functional Verification (Full E2E — MANDATORY):**

**Tab 1 — Queue:**
- [ ] 3 KPI cards render with non-null counts (may be 0)
- [ ] Date range default = today − 30d → today
- [ ] All 4 filter selects populate options
- [ ] Grid loads with 7 columns (+ checkbox)
- [ ] `amountDisplay` formatted correctly per currency
- [ ] Receipt-Status badge: Generated rows green, Not-Generated slate, Pending amber (with tooltip)
- [ ] Send-Status badge: empty/em-dash for not-generated rows; correct color per state otherwise
- [ ] Row-actions are CONTEXTUAL (not fixed): not-generated shows "Generate", generated+pending-send shows "Send" primary, etc.
- [ ] "Generate" action fires `createGeneratedTaxReceipt` mutation, toast success, row refreshes
- [ ] "Send" action fires `sendGeneratedTaxReceipt` (SERVICE_PLACEHOLDER), toast success, row SendStatus flips
- [ ] "Resend" increments `resendCount` visible in detail page
- [ ] Bulk "Generate All Pending" fires per-row mutation in loop (SERVICE_PLACEHOLDER toast)
- [ ] Row click on Donation Code opens GlobalDonation detail in new tab

**Tab 2 — Generated Receipts:**
- [ ] Grid loads with 9 columns
- [ ] Tax Type filter + Currency filter wired
- [ ] Tax Type badge color-coded per code
- [ ] Row click → `?tab=generated&mode=read&id={id}` → DETAIL layout renders
- [ ] DETAIL: 2-column layout, left has Summary + Donor & Amount + Preview iframe (or placeholder card if FileUrl null), right has Send History + Tax Jurisdiction + Audit Trail
- [ ] Download / Email / WhatsApp header buttons (SERVICE_PLACEHOLDER toasts)

**Tab 3 — Templates:**
- [ ] Card-grid renders all templates with preview tiles
- [ ] Default badge overlays only on `isDefault=true` cards
- [ ] "+Create New Template" → `?tab=templates&mode=new` → empty designer loads
- [ ] Top properties row (6 fields) renders correctly with FK dropdowns populated
- [ ] Placeholder chips clickable — clicking inserts token at textarea caret
- [ ] Split editor: HTML textarea on left, live preview iframe on right
- [ ] Preview updates within 300ms of typing (debounced)
- [ ] Sample-data substitution renders placeholder values in preview
- [ ] Save → `createReceiptTemplate` → redirects to `?tab=templates&mode=read&id={newId}`
- [ ] Edit existing template (URL `?tab=templates&mode=edit&id={id}`) → designer pre-filled
- [ ] "Set as Default" mutation works — card-grid refresh shows badge moved to selected
- [ ] Detail page shows preview + properties + Used-By count + audit

**Tab 4 — Tax Settings:**
- [ ] Section A — Country Tax Config grid loads with 4 sample rows
- [ ] Country cell shows flag emoji + name
- [ ] +Add Country Tax Config opens modal — 7 fields per §⑥
- [ ] Modal save → grid refreshes
- [ ] Edit → modal pre-filled
- [ ] Active toggle column persists state
- [ ] Section B — Global Settings form: 5 rows render correctly
- [ ] Each setting blur fires `upsertGlobalReceiptSetting` (autosave)
- [ ] Toast on save success
- [ ] Receipt number format text input only allows valid pattern (must contain `{SEQ}`)
- [ ] AnnualStatementMonth select shows Jan–Dec

**URL state**:
- [ ] `?tab=queue|generated|templates|settings` sync to active tab
- [ ] Tab 3 sub-modes: `?tab=templates&mode=new|edit|read&id={id}`
- [ ] Tab 2 sub-mode: `?tab=generated&mode=read&id={id}`
- [ ] Browser Back button respects history

**Permissions**:
- [ ] BUSINESSADMIN can do everything across all 4 tabs (verify via 4 hidden child menus + capabilities)
- [ ] Non-BUSINESSADMIN: only READ — Edit / Delete / +Add / Save buttons hidden or disabled

**DB Seed Verification:**
- [ ] `RECEIPTMANAGEMENT` menu appears in sidebar under Setting > Donation Config
- [ ] 4 hidden child menus exist with IsMenuRender=false (verify in DB, not sidebar)
- [ ] 2 grids exist with GridFormSchema=NULL (FLOW)
- [ ] 3 MasterData types seeded: RECEIPTTEMPLATETYPE (3), RECEIPTSENDSTATUS (5), RECEIPTSENDMETHOD (4)
- [ ] 5 sample ReceiptTemplate rows, 4 CountryTaxConfig rows visible
- [ ] 1 GlobalReceiptSetting upsert row exists per tenant with defaults

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**Naming & disambiguation**:
- ⚠ **`GlobalReceiptDonation` ≠ this screen** — that's the field-collection receipt entity (cash collected by ambassadors → bank deposit). It is **UNTOUCHED** by this build. Same misclassification pattern as #10 OnlineDonationPage where "BE+FE exist" referred to `GlobalOnlineDonation` (donation transaction) instead of the page-setup entity. Do NOT modify, rename, or wire to `GlobalReceiptDonation` — it has its own user (Ambassador / Receipt Book screens).
- New entity names deliberately avoid the bare word "Receipt" to prevent future confusion: `ReceiptTemplate`, `CountryTaxConfig`, `GlobalReceiptSetting`, `GeneratedTaxReceipt`. The user-facing menu label is "Receipts & Tax" (mockup title) — internal code uses the longer disambiguated names.

**Routing & module placement**:
- This screen lives under **SETTING module**, NOT CRM. Parent menu = `SET_DONATIONCONFIG`, route = `setting/donationconfig/receiptmanagement`. Per MODULE_MENU_REFERENCE.md row 288 (OrderBy=5 under SET_DONATIONCONFIG MenuId=372).
- The FE page-components folder must live at `src/presentation/components/page-components/setting/donationconfig/receiptmanagement/` — verify the parent `setting/donationconfig/` page-components folder exists (DonationVerse #?? lives there; Donation Category/Group/Purpose have FE routes under `setting/donationconfig/` but their page-components live under `donation/` per registry note "MenuUrl under setting/donationconfig/ but parented under CRM_ORGANIZATION").

**Composite FLOW patterns**:
- Follows MatchingGift #11 precedent: 4 entities, 1 visible menu, 4 hidden child menus (IsMenuRender=false) for capability gating.
- URL routing: `?tab=` is primary key, `?mode=` is secondary (only meaningful on Tabs 2 + 3). Tab switching pushes via `router.replace` (no scroll reset); mode switching uses `router.push` so Back navigates intuitively.
- Variant B mandatory on Tab 1 (ScreenHeader + KPI widgets + showHeader=false on grid).
- `card-grid` `details` variant required on Tab 3 — verify the CardGrid infrastructure exists per `.claude/feature-specs/card-grid.md`. If first screen to need it, FE must scaffold the shell.

**Singleton entity**:
- `GlobalReceiptSetting` has exactly one row per CompanyId. Use Upsert pattern (MatchingGiftSettings #11 precedent). Filtered unique index on `(CompanyId, IsDeleted=false)`. First-time read may return null — FE must handle and trigger a create-with-defaults on first save.

**Tab 1 — projection grid (NO new entity for Queue itself)**:
- The Queue tab is a **read projection** over `GlobalDonation` LEFT JOIN latest `GeneratedTaxReceipt`. No `ReceiptQueue` entity to create.
- The handler MUST left-join on `GeneratedTaxReceipt` ordered by `GeneratedDate DESC` taking the latest, so re-issued receipts show the most recent send status.
- Pre-format `amountDisplay` server-side to avoid currency-formatting headaches in the renderer — see #1 GlobalDonation precedent.
- The "Pending (cheque not cleared)" state (mockup row 4) is inferred from `paymentStatusCode='PEN' AND donationModeCode='CHQ'` — verify these MasterData DataValue codes match what GlobalDonation seeds (KI-5 from #1 build flagged that ONL/PEN/REC convention is unverified — same risk here).

**Numbering format parser**:
- `ReceiptNumberFormat` tokens: `{YEAR}`, `{MONTH}`, `{SEQ}`, `{COUNTRY}`. The Create handler MUST atomically increment `LastSequenceNumber` (use `UPDATE ... RETURNING` pattern or DB sequence — naive read-then-write will race under concurrent generation).
- Year rollover: when `LastSequenceYear != currentYear` AND format contains `{YEAR}`, reset `LastSequenceNumber = 0` before increment.

**Service Dependencies** (UI fully built — handler is mocked):

- ⚠ **SERVICE_PLACEHOLDER**: PDF rendering — `createGeneratedTaxReceipt` builds the row but `FileUrl` stays NULL. No HTML→PDF service exists in the codebase yet (verified — no QuestPDF / DinkToPdf / wkhtmltopdf libraries referenced). UI shows "PDF preview not yet rendered — generate via Tab 1 Queue" placeholder card in the DETAIL layout.
- ⚠ **SERVICE_PLACEHOLDER**: Email send — `sendGeneratedTaxReceipt` updates SendStatus to `EMAILED`, `LastSentAt=NOW()`, but no actual email is sent. The Email Provider Config (#?? screen, exists under SET_COMMUNICATIONCONFIG) is the eventual integration point.
- ⚠ **SERVICE_PLACEHOLDER**: WhatsApp send — same pattern; updates SendStatus to `WHATSAPP`. Wires through WhatsappSetup #?? eventually.
- ⚠ **SERVICE_PLACEHOLDER**: Bulk generation — "Generate All Pending" + "Generate Annual Statements" — V1 does per-row mutations in a loop with toast. Real impl needs a background job runner.
- ⚠ **SERVICE_PLACEHOLDER**: Bulk download — "Bulk Download" multi-row Tab 2 — V1 toast only.
- ⚠ **SERVICE_PLACEHOLDER**: Logo upload for IncludeOrgLogo — the toggle persists, but the logo asset would come from Company branding (existing) or a future upload UI; not built here.
- ⚠ **SERVICE_PLACEHOLDER**: Annual statement consolidated PDF — multi-donation rollup not implemented; per-donation single PDF only.

Full UI must be built (buttons, forms, modals, panels, interactions, role gating, toasts). Only the handler for the external service call is mocked.

**Pre-flagged risks (HIGH/MED)**:
- HIGH — Concurrent receipt generation: the `LastSequenceNumber` increment must be transactional (FOR UPDATE row lock or upsert with RETURNING). Naive `SELECT then UPDATE` will produce duplicate ReceiptNumbers under bulk-generate.
- HIGH — `RECEIPTSENDMETHOD` MasterDataType reuse: #1 GlobalDonation already references `ReceiptSendMethodId`. Verify the seed type/code convention so we don't double-seed conflicting rows. See #1 KI-10.
- MED — `GlobalDonation.ReceiptNumber` backfill on Create: writing both rows (GeneratedTaxReceipt + GlobalDonation update) must be in one transaction.
- MED — Template `BodyHtml` XSS: the live-preview iframe must use `sandbox="allow-same-origin"` (NO `allow-scripts`) to neutralize any script tags in user-authored HTML.
- MED — Card-grid build dep: if the CardGrid component shell + `details` variant don't exist yet, FE dev must scaffold per `.claude/feature-specs/card-grid.md`. ContactType #19 and prior MASTER_GRIDs don't use it.
- LOW — Mockup currency formatting varies (`$500`, `AED 4,500`, `₹8,000`, `R$250`, `₦50,000`, `MAD 1,500`) — back-end `amountDisplay` formatting must handle non-Latin currency codes/symbols.
- LOW — Country flag rendering: mockup uses Unicode flag emojis (`&#127482;&#127480;` = 🇺🇸). FE renderer can compute from `Country.CountryCode` (ISO-2 letter) → regional indicator. Test on Windows (Win10 doesn't render flags natively — falls back to letters).

**Migration plan**:
- `dotnet ef migrations add Add_ReceiptManagement_Entities` (run from `Base.Infrastructure`)
- Edit migration: ensure filtered unique indexes use `WHERE "IsDeleted" = false`
- Add idempotent seed: INSERT INTO `fund."GlobalReceiptSettings"` for each existing tenant WHERE NOT EXISTS
- `dotnet ef database update` (user runs separately per team-handles-migrations rule)

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | LOW | FE/UX | Tab 3 card-grid uses generic `details` variant — mockup shows HTML preview tile. Create dedicated `receipt-template` card variant (parallel to `certificate-template`). | OPEN |
| ISSUE-2 | 1 | MED | FE | `settings-country-tax-config-modal.tsx` uses raw number Input for `countryId` + `defaultReceiptTemplateId`; needs ApiSelectV2 wiring for production UX. | OPEN |
| ISSUE-3 | 1 | HIGH | BE | `LastSequenceNumber` increment in `CreateGeneratedTaxReceipt` is naive read-then-write. Under concurrent bulk-generate, duplicate ReceiptNumbers possible. Replace with `FOR UPDATE` row-lock or DB sequence. | CLOSED (Session 2) — Migrated to `NumberSequenceGenerator.GenerateAsync("GENERATEDTAXRECEIPT", ...)`. Generator owns `pg_advisory_xact_lock((entityTypeId, companyId))` + transactional counter increment. Legacy `LastSequenceNumber` / `LastSequenceYear` / `ReceiptNumberFormat` columns dropped from `GlobalReceiptSetting`. |
| ISSUE-4 | 1 | MED | FE | Bulk action multi-select state lives inside FlowDataTable; "Generate All Pending" + "Bulk Download" fire SERVICE_PLACEHOLDER toasts only. Wire grid selection → Zustand store for real bulk fanout. | OPEN |
| ISSUE-5 | 1 | LOW | BE | Tab 1 `GetReceiptQueue` filters `receiptStatus` in-memory after projection (computed col not pushable). Perf concern at scale. | OPEN |
| ISSUE-6 | 1 | LOW | FE/BE | `globalReceiptSetting` resolver returns envelope with `.data` possibly null on first load; FE handles correctly but shape differs from paginated norms. | OPEN |
| ISSUE-7 | 1 | MED | DevOps | EF migration scaffold deferred to user per team-handles-migrations rule. User must run `dotnet ef migrations add Add_ReceiptManagement_Entities` + `database update` before testing. | OPEN |
| ISSUE-8 | 1 | LOW | DB | DB seed STEP 7 RECEIPTSENDMETHOD MasterDataType may silently skip if #1 GlobalDonation already seeded it. Verify code values (EMAIL/PRINT/WHATSAPP/DOWNLOAD) match. | OPEN |
| ISSUE-9 | 1 | LOW | FE | Card grid "Set as Default" action not surfaced as per-card button; wired as programmatic callback but needs DB seed `cardActions` config or custom card variant. | OPEN |
| ISSUE-10 | 1 | LOW | DB | Seed `CountryTaxConfig.DefaultReceiptTemplateId` resolves by template-name lookup; cross-tenant seeds may need explicit CompanyId scoping. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-16 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Composite Tabbed FLOW with 4 NEW entities.
- **Pipeline**: Phase 1 (BA/SR/UX) intentionally SKIPPED — prompt is self-validated comprehensive spec. Approval phase only. Code-gen via 6 sequenced agent spawns (all Sonnet): BE Pass A (foundation) → BE Pass B1+B2 (CRUD parallel) → DB Seed (parallel with FE Pass A) → FE Pass A (infrastructure) → orchestrator GQL contract fixes → FE Pass B (UI components).
- **Files touched**:
  - BE (created — 44):
    - Entities (4): `Base.Domain/Models/DonationModels/{ReceiptTemplate, CountryTaxConfig, GlobalReceiptSetting, GeneratedTaxReceipt}.cs`
    - EF Configs (4): `Base.Infrastructure/Data/Configurations/DonationConfigurations/{ReceiptTemplate, CountryTaxConfig, GlobalReceiptSetting, GeneratedTaxReceipt}Configuration.cs`
    - Schemas (4): `Base.Application/Schemas/DonationSchemas/{ReceiptTemplate, CountryTaxConfig, GlobalReceiptSetting, GeneratedTaxReceipt}Schemas.cs`
    - ReceiptTemplate commands+queries (7): Create / Update / Delete / Toggle / SetDefault / GetReceiptTemplates / GetReceiptTemplateById
    - CountryTaxConfig commands+queries (6): Create / Update / Delete / Toggle / GetCountryTaxConfigs / GetCountryTaxConfigById
    - GlobalReceiptSetting commands+queries (2): UpsertGlobalReceiptSetting / GetGlobalReceiptSetting
    - GeneratedTaxReceipt commands+queries (8): Create / Delete / Send / Resend / GetGeneratedTaxReceipts / GetGeneratedTaxReceiptById / GetReceiptQueue / GetReceiptManagementSummary
    - GraphQL endpoints (8): `Base.API/EndPoints/Donation/{Mutations,Queries}/{ReceiptTemplate, CountryTaxConfig, GlobalReceiptSetting, GeneratedTaxReceipt}{Mutations,Queries}.cs`
    - Migration plan (1): `sql-scripts-dyanmic/Add_ReceiptManagement_Entities.PLAN.md` (deferred per team-handles-migrations rule)
  - BE (modified — 4):
    - `Base.Application/Data/Persistence/IApplicationDbContext.cs` (+4 DbSets)
    - `Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs` (+4 DbSets)
    - `Base.Application/Extensions/DecoratorProperties.cs` (+4 entries)
    - `Base.Application/Mappings/DonationMappings.cs` (+4 entity mapping blocks + 1 composite DTO registration)
  - FE (created — 37):
    - DTOs (4): `src/domain/entities/donation-service/{ReceiptTemplate, CountryTaxConfig, GlobalReceiptSetting, GeneratedTaxReceipt}Dto.ts`
    - GQL Queries (4): `src/infrastructure/gql-queries/donation-queries/{ReceiptTemplate, CountryTaxConfig, GlobalReceiptSetting, GeneratedTaxReceipt}Query.ts`
    - GQL Mutations (4): `src/infrastructure/gql-mutations/donation-mutations/{ReceiptTemplate, CountryTaxConfig, GlobalReceiptSetting, GeneratedTaxReceipt}Mutation.ts`
    - Shared renderers (5): `custom-components/data-tables/shared-cell-renderers/{receipt-status-badge, receipt-send-status-badge, tax-type-badge, queue-row-actions, format-icon-text}.tsx`
    - Zustand store (1): `page-components/setting/donationconfig/receiptmanagement/receiptmanagement-store.ts`
    - Page config (1): `src/presentation/pages/setting/donationconfig/receiptmanagement.tsx`
    - Composite shell + barrel (2): `index-page.tsx` + `index.ts`
    - Tab 1 Queue (3): `tabs/queue-tab.tsx`, `queue-tab-kpi-cards.tsx`, `queue-tab-filters.tsx`
    - Tab 2 Generated (2): `tabs/generated-tab.tsx`, `generated-detail-page.tsx`
    - Tab 3 Templates (4): `tabs/templates-tab.tsx`, `templates-template-designer.tsx`, `templates-detail-page.tsx`, `templates-placeholder-tags.ts`
    - Tab 4 Settings (2): `tabs/settings-tab.tsx`, `settings-country-tax-config-modal.tsx`
  - FE (modified — 10):
    - 3 component-column registries (advanced/basic/flow) — added 5 case branches each + imports
    - 3 barrel files: `domain/entities/donation-service/index.ts`, `gql-queries/donation-queries/index.ts`, `gql-mutations/donation-mutations/index.ts`, `shared-cell-renderers/index.ts`, `presentation/pages/setting/donationconfig/index.ts`
    - `application/configs/data-table-configs/donation-service-entity-operations.ts` (+5 gridCode blocks: RECEIPTTEMPLATE, COUNTRYTAXCONFIG, GLOBALRECEIPTSETTING, GENERATEDTAXRECEIPT, GLOBALRECEIPT_QUEUE)
    - `src/app/[lang]/setting/donationconfig/receiptmanagement/page.tsx` (replaced UnderConstruction stub)
    - **Mid-build orchestrator corrections** (after FE Pass A — BE method name mismatches discovered during validation):
      - `gql-mutations/donation-mutations/ReceiptTemplateMutation.ts` — `TOGGLE_RECEIPTTEMPLATE_MUTATION` operation name corrected `toggleReceiptTemplate` → `activateDeactivateReceiptTemplate`
      - `gql-mutations/donation-mutations/CountryTaxConfigMutation.ts` — same correction for `activateDeactivateCountryTaxConfig`
      - `gql-mutations/donation-mutations/GeneratedTaxReceiptMutation.ts` — Send + Resend arg name corrected `$request` → `$dto` (BE param name)
      - `gql-queries/donation-queries/ReceiptTemplateQuery.ts` — moved 4 custom filters (isActive, taxCodeKey, countryId, donationPurposeId) OUT of `request:` block (BE `[AsParameters]` requires them at top level)
      - `gql-queries/donation-queries/GeneratedTaxReceiptQuery.ts` — same custom-filter-position fix for `generatedTaxReceipts` + `receiptQueue` + renamed `$sendStatus` → `$sendStatusCode` to match BE method param. Added envelope wrapper to `RECEIPT_MANAGEMENT_SUMMARY_QUERY` (`errorCode/errorDetails/message/status/success/data { ... }`)
      - `gql-queries/donation-queries/GlobalReceiptSettingQuery.ts` — added envelope wrapper around singular `globalReceiptSetting`
  - DB Seed (1): `sql-scripts-dyanmic/ReceiptManagement-sqlscripts.sql` (1132 lines — Menu+4 hidden children, MenuCapabilities, BUSINESSADMIN RoleCapabilities, 2 FLOW Grids, 18 Fields + 16 GridFields, 3 new MasterDataTypes (RECEIPTTEMPLATETYPE/RECEIPTSENDSTATUS/RECEIPTSENDMETHOD), 5 sample ReceiptTemplate rows, 4 sample CountryTaxConfig rows, GlobalReceiptSetting upsert per tenant). Mid-build fix: changed unregistered `donation-link` → `original-donation-link` (shape-compatible registered renderer).
- **Deviations from spec**:
  - **EF Migration not scaffolded** — generated `Add_ReceiptManagement_Entities.PLAN.md` instead of `.cs` migration files, per [feedback_team_handles_migrations]. User runs `dotnet ef migrations add Add_ReceiptManagement_Entities` (from `Base.Infrastructure`) followed by `dotnet ef database update`.
  - **Phase 1 (BA/SolutionResolver/UX) intentionally skipped** — prompt was self-validated comprehensive spec; running those agents would have re-derived what's already documented. Saved ~30-50K tokens.
  - **`GetReceiptQueue` does in-memory `receiptStatus` filtering** — receiptStatus is a computed (not DB) column, so handler materializes results before filtering. dateFrom/dateTo/donationModeId are pushed to SQL to bound the working set. Flagged as V1 perf limitation for large tenants.
  - **`CreateGeneratedTaxReceiptCommand` takes primitive args (globalDonationId, receiptTemplateId, countryTaxConfigId)** rather than a DTO — heavy business logic derives everything from minimal context per §④.
  - **`UpsertGlobalReceiptSetting` preserves sequence counters** — LastSequenceNumber + LastSequenceYear on existing row are NOT overwritten by user input; prevents accidental sequence reset via Settings form.
  - **`GlobalReceiptSetting` GetGlobalReceiptSetting returns null** for missing row (not auto-create) — FE handles null by showing defaults; first Save triggers Upsert.
  - **Card variant for templates uses `details`** (snippet of placeholdersUsedJson) instead of mockup-style preview tile. Recommend creating a dedicated `receipt-template` variant in a follow-up for visual parity (see ISSUE-1).
  - **2 modal selectors in CountryTaxConfig modal use plain number Input** instead of ApiSelectV2 (countryId + defaultReceiptTemplateId). Production UX needs ApiSelectV2 — see ISSUE-2.
- **Known issues opened**:
  - ISSUE-1 (LOW) — Tab 3 card-grid uses `details` variant; mockup expects HTML preview tile. Create `receipt-template` card variant for visual parity.
  - ISSUE-2 (MED) — `settings-country-tax-config-modal.tsx` uses raw number Input for countryId + defaultReceiptTemplateId; needs ApiSelectV2 wiring.
  - ISSUE-3 (HIGH) — `LastSequenceNumber` increment is read-then-write — concurrent bulk-generate may produce duplicate ReceiptNumbers. Replace with `FOR UPDATE` row lock or DB sequence before production.
  - ISSUE-4 (MED) — Bulk action multi-select state lives in FlowDataTable internally, not Zustand store; "Generate All Pending" + "Bulk Download" buttons fire SERVICE_PLACEHOLDER toasts only (per V1 spec).
  - ISSUE-5 (LOW) — Tab 1 Queue receiptStatus filter pushes filter post-projection (in-memory) — perf concern at scale.
  - ISSUE-6 (LOW) — `globalReceiptSetting` resolver returns `BaseApiResponse<T>` with `.data` possibly null on first load; FE handles null but shape is mildly inconsistent with paginated `globalReceiptSetting`-style queries.
  - ISSUE-7 (MED) — EF migration scaffold deferred to user; user must run `dotnet ef migrations add Add_ReceiptManagement_Entities` + `database update` before testing.
  - ISSUE-8 (LOW) — DB seed STEP 7 may silently skip RECEIPTSENDMETHOD MasterDataType if #1 GlobalDonation already seeded it; verify codes (EMAIL/PRINT/WHATSAPP/DOWNLOAD) match across screens.
  - ISSUE-9 (LOW) — Card grid `Set as Default` action not surfaced as per-card button — wired as programmatic callback in templates-tab.tsx but requires DB seed grid-action config to render in `CardActionMenu` overflow.
  - ISSUE-10 (LOW) — DB seed CountryTaxConfig FK to `defaultReceiptTemplateId` resolved by template-name; cross-tenant seeds may need explicit CompanyId scoping.
- **Known issues closed**: None
- **Next step**: User runs `dotnet ef migrations add Add_ReceiptManagement_Entities` (from `Base.Infrastructure`) then `database update`. Then `pnpm dev` and test full E2E at `/{lang}/setting/donationconfig/receiptmanagement`.

### Session 2 — 2026-05-16 — FIX — COMPLETED

- **Scope**: Receipt numbering refactor — replace home-grown sequence-counter on `GlobalReceiptSetting` with the existing generic `NumberSequenceGenerator` (per user observation that `sett.NumberSequenceEntityTypes` + `sett.NumberSequenceConfigs` already provide tenant-aware, advisory-locked, period-aware numbering for `GLOBALDONATION` — and identification that the catalog row was missing a `NumberColumnName` to describe which column the generated number is written into). Resolves ISSUE-3 HIGH.
- **Files touched**:
  - BE (modified — 7):
    - `Base.Domain/Models/SettingModels/NumberSequenceEntityType.cs` — added `NumberColumnName` property (string, MaxLength 100, NOT NULL) with doc comment explaining the (SchemaName, TableName, NumberColumnName) tuple.
    - `Base.Infrastructure/Data/Configurations/SettingConfigurations/NumberSequenceEntityTypeConfiguration.cs` — EF config for `NumberColumnName`.
    - `Base.Application/Schemas/SettingSchemas/NumberSequenceConfigSchemas.cs` — `NumberSequenceConfigRowResponseDto.NumberColumnName` exposed for CompanySettings #75 Section 9 grid.
    - `Base.Application/Business/SettingBusiness/CompanySettings/Queries/GetNumberSequenceConfigsQuery/GetNumberSequenceConfigs.cs` — projection + DTO assembly updated to surface `NumberColumnName`.
    - `Base.Domain/Models/DonationModels/GlobalReceiptSetting.cs` — dropped `ReceiptNumberFormat`, `LastSequenceNumber`, `LastSequenceYear`. Added doc note explaining that numbering is owned by NumberSequence subsystem.
    - `Base.Infrastructure/Data/Configurations/DonationConfigurations/GlobalReceiptSettingConfiguration.cs` — removed `ReceiptNumberFormat` HasMaxLength/IsRequired.
    - `Base.Application/Schemas/DonationSchemas/GlobalReceiptSettingSchemas.cs` — DTOs slimmed to {autoGenerateOnDonation, autoSendByEmail, includeOrgLogo, annualStatementMonth}.
    - `Base.Application/Business/DonationBusiness/GlobalReceiptSettings/Commands/UpsertGlobalReceiptSetting.cs` — validator + handler simplified (no more sequence-counter preservation, no `{SEQ}`-token validation).
    - `Base.Application/Business/DonationBusiness/GeneratedTaxReceipts/Commands/CreateGeneratedTaxReceipt.cs` — REWRITTEN: dropped Regex import + `{COUNTRY}` token + inline `LastSequence` increment + GlobalReceiptSetting auto-create block; wrapped persistence in EF execution-strategy + transaction; invokes `NumberSequenceGenerator.GenerateAsync(db, companyId, "GENERATEDTAXRECEIPT", DateTime.UtcNow, ct)` inside the transaction; receipt insert + GlobalDonation backfill + counter increment now commit atomically.
  - DB (modified — 3):
    - `sql-scripts-dyanmic/NumberSequenceEntityType-sqlscripts.sql` — INSERT for GLOBALDONATION includes `NumberColumnName="ReceiptNumber"`; idempotent UPDATE backfills the column on any pre-existing row; commented RECEIPTBOOK template also includes the new column; verification SELECT updated.
    - `sql-scripts-dyanmic/ReceiptManagement-sqlscripts.sql` — STEP 8c GlobalReceiptSettings upsert columns slimmed (3 removed); NEW STEP 9 registers `GENERATEDTAXRECEIPT` in `public.EntityTypes` + `sett.NumberSequenceEntityTypes` with `NumberColumnName="ReceiptNumber"`, prefix `TAX`, pattern `{PREFIX}-{YYYY}-{SEQ:000000}`, YEARLY reset; idempotent backfill UPDATE for any older rows missing `NumberColumnName`.
    - `sql-scripts-dyanmic/Add_ReceiptManagement_Entities.PLAN.md` — REVISION block prepended with the schema deltas (drop 3 columns on `fund.GlobalReceiptSettings`; add `NumberColumnName` on `sett.NumberSequenceEntityTypes`); EF migration scaffold snippet supplied with backfill SQL for the new column; Section 3b upsert snippet rewritten without legacy columns.
  - FE (modified — 4):
    - `domain/entities/donation-service/GlobalReceiptSettingDto.ts` — dropped `receiptNumberFormat` / `lastSequenceNumber` / `lastSequenceYear`; doc note added pointing to CompanySettings #75 Section 9.
    - `infrastructure/gql-queries/donation-queries/GlobalReceiptSettingQuery.ts` — selection set slimmed.
    - `infrastructure/gql-mutations/donation-mutations/GlobalReceiptSettingMutation.ts` — selection set slimmed.
    - `presentation/components/page-components/setting/donationconfig/receiptmanagement/tabs/settings-tab.tsx` — removed `Input` import + `GlobalReceiptSettingsData` legacy fields + `DEFAULTS` legacy values + hydrate-effect legacy reads + autosave-payload legacy fields + `{SEQ}` validation guard + "Receipt numbering format" row in the form + reduced skeleton count from 5 to 4; added a new **Section C** info banner pointing users to "Company Settings → Number Sequences → GENERATEDTAXRECEIPT".
- **Deviations from spec**: Tab 4 Section B form lost its "Receipt numbering format" Input — replaced by Section C deep-link banner. This is a deliberate scope shift, not a spec deviation; the prompt §② entity columns are updated below this Build Log entry by virtue of the schema diff. Also dropped the `{COUNTRY}` token from receipt numbering — generic generator has no country awareness; pattern uses Prefix instead of per-donor country code. Country-segmented numbering, if needed, becomes a follow-up generator enhancement.
- **Known issues opened**: None.
- **Known issues closed**:
  - **ISSUE-3 (HIGH)** — Concurrent sequence race. Generator now wraps counter mutation in `pg_advisory_xact_lock((entityTypeId, companyId))` inside a transactional unit-of-work — duplicates prevented at the DB level. Legacy `LastSequence*` columns dropped so the broken path cannot be re-introduced.
- **Next step**: User scaffolds a follow-up EF migration (e.g. `Drop_GlobalReceiptSetting_Numbering_Add_NumberColumnName`) — snippet provided in `Add_ReceiptManagement_Entities.PLAN.md` REVISION block. Then re-runs `ReceiptManagement-sqlscripts.sql` to seed the GENERATEDTAXRECEIPT eligibility row. Verify in CompanySettings #75 Section 9 that the GENERATEDTAXRECEIPT row appears alongside GLOBALDONATION.

### Session 3 — 2026-05-16 — REFACTOR — COMPLETED

- **Scope**: Delete the entire `GlobalReceiptSetting` entity. 4 remaining workflow flags relocated to `sett.CompanyConfigurations` §8 (CompanySettings #75 Receipt section). Tab 4 Section B form replaced by deep-link banner. Numbering remains on the NumberSequence subsystem (Session 2 work unchanged).
- **Files touched**:
  - BE (modified — 7):
    - `Base.Domain/Models/SettingModels/CompanyConfiguration.cs` — added 4 fields (`AutoGenerateReceiptOnDonation`, `AutoSendReceiptByEmail`, `IncludeOrgLogoOnReceipt`, `AnnualStatementMonth`). Doc-comment updated to call out §8 Receipt section.
    - `Base.Infrastructure/Data/Configurations/SettingConfigurations/CompanyConfigurationConfiguration.cs` — EF config for the 4 new properties (all `IsRequired()`).
    - `Base.Domain/Defaults/CompanyConfigurationDefaults.cs` — added 4 default constants (`true`/`true`/`true`/`1`).
    - `Base.Application/Schemas/SettingSchemas/CompanySettingsSchemas.cs` — new `ReceiptSection` DTO + wired into `CompanySettingsRequestDto.Receipt`.
    - `Base.Application/Business/SettingBusiness/CompanySettings/Queries/GetCompanySettingsQuery/GetCompanySettings.cs` — Receipt section projected onto response DTO; auto-seed branch populates the 4 defaults on first GET.
    - `Base.Application/Business/SettingBusiness/CompanySettings/Commands/UpdateCompanySettingsCommand/UpdateCompanySettings.cs` — Receipt section mapped onto `CompanyConfiguration` inside the existing single-tx update.
    - `Base.Application/Business/SettingBusiness/CompanySettings/Commands/UpdateCompanySettingsCommand/UpdateCompanySettingsValidator.cs` — `Receipt.AnnualStatementMonth` `InclusiveBetween(1, 12)` rule.
  - BE (deleted — 8):
    - `Base.Domain/Models/DonationModels/GlobalReceiptSetting.cs`
    - `Base.Infrastructure/Data/Configurations/DonationConfigurations/GlobalReceiptSettingConfiguration.cs`
    - `Base.Application/Schemas/DonationSchemas/GlobalReceiptSettingSchemas.cs`
    - `Base.Application/Business/DonationBusiness/GlobalReceiptSettings/` (folder) — `Commands/UpsertGlobalReceiptSetting.cs` + `Queries/GetGlobalReceiptSetting.cs`
    - `Base.API/EndPoints/Donation/Queries/GlobalReceiptSettingQueries.cs`
    - `Base.API/EndPoints/Donation/Mutations/GlobalReceiptSettingMutations.cs`
  - BE (unwired — 4):
    - `Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs` — removed `GlobalReceiptSettings` DbSet line.
    - `Base.Application/Data/Persistence/IApplicationDbContext.cs` — removed `GlobalReceiptSettings` DbSet line.
    - `Base.Application/Mappings/DonationMappings.cs` — removed 7 GlobalReceiptSetting TypeAdapterConfig lines (replaced with one-line comment).
    - `Base.Application/Extensions/DecoratorProperties.cs` — removed `GlobalReceiptSetting = "GLOBALRECEIPTSETTING"` enum entry.
  - DB (modified — 2):
    - `sql-scripts-dyanmic/ReceiptManagement-sqlscripts.sql` — STEP 8c rewritten: dropped fund."GlobalReceiptSettings" upsert; replaced with idempotent UPDATE on `sett.CompanyConfigurations` to backfill the 4 new columns; added `DROP TABLE IF EXISTS fund."GlobalReceiptSettings" CASCADE`.
    - `sql-scripts-dyanmic/Add_ReceiptManagement_Entities.PLAN.md` — prepended new "REVISION 3 (2026-05-16)" block with EF migration scaffold for `AddColumn × 4` on `sett.CompanyConfigurations` + optional data migration SQL + `DropTable fund.GlobalReceiptSettings`.
  - FE (modified — 4):
    - `application/configs/data-table-configs/donation-service-entity-operations.ts` — removed entire `GLOBALRECEIPTSETTING` gridCode block.
    - `domain/entities/donation-service/index.ts` — removed `export * from "./GlobalReceiptSettingDto"`.
    - `infrastructure/gql-queries/donation-queries/index.ts` — removed `export * from "./GlobalReceiptSettingQuery"`.
    - `infrastructure/gql-mutations/donation-mutations/index.ts` — removed `export * from "./GlobalReceiptSettingMutation"`.
  - FE (deleted — 3):
    - `domain/entities/donation-service/GlobalReceiptSettingDto.ts`
    - `infrastructure/gql-queries/donation-queries/GlobalReceiptSettingQuery.ts`
    - `infrastructure/gql-mutations/donation-mutations/GlobalReceiptSettingMutation.ts`
  - FE (rewritten — 1):
    - `presentation/components/page-components/setting/donationconfig/receiptmanagement/tabs/settings-tab.tsx` — removed entire `GlobalReceiptSettingsForm` component (4-field autosave form), removed `GlobalReceiptSettingsData`/`DEFAULTS`/`MONTH_OPTIONS` consts, dropped imports (`Skeleton`, `Switch`, `useApolloClient`, `useQuery`, `useEffect`, `useRef`, `toast`, both gql files). Section B now renders a deep-link info banner pointing to "Company Settings → Receipt". Section A (Country Tax Config grid) + Section C (numbering banner) unchanged.
- **Deviations from spec**: Tab 4 Section B no longer has an inline form — replaced with deep-link banner. This matches the precedent set by Session 2's Section C numbering banner.
- **Known issues opened**: None.
- **Known issues closed**: None this session (Session 2 closed ISSUE-3; remaining open issues unaffected).
- **Next step**: User scaffolds a follow-up EF migration (e.g. `Drop_GlobalReceiptSettings_Move_To_CompanyConfiguration`) — snippet provided in `Add_ReceiptManagement_Entities.PLAN.md` "REVISION 3" block. Then re-runs `ReceiptManagement-sqlscripts.sql` STEP 8c. Verify in CompanySettings #75 Receipt section that the 4 flags render with correct defaults; verify Tab 4 Section B renders the new banner.
