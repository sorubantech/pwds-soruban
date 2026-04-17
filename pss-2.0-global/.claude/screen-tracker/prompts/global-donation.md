---
screen: GlobalDonation
registry_id: 1
module: Fundraising
status: COMPLETED
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-16
completed_date: 2026-04-16
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed
- [x] Existing code reviewed
- [x] Business rules extracted
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized
- [x] User Approval received
- [x] Backend code generated          ← Summary query added (DTO + Handler + GQL endpoint)
- [x] Backend wiring complete         ← GlobalDonationQueries.cs updated
- [x] Frontend code generated         ← FLOW upgrade: index.tsx, index-page.tsx, view-page.tsx, store, summary, distribution, receipt modal
- [x] Frontend wiring complete        ← Barrel exports, page config, store barrel updated
- [x] DB Seed script generated        ← FLOW upgrade seed + idempotent menu/capabilities
- [x] Registry updated to COMPLETED

### Verification (post-generation — builds verified)
- [x] dotnet build passes             ← 0 errors, 366 warnings (all pre-existing)
- [x] TypeScript check passes         ← 0 errors
- [ ] pnpm dev — page loads at correct route
- [ ] CRUD flow tested (Create → Read → Update → Toggle → Delete)
- [ ] Grid columns render correctly with search/filter
- [ ] Form fields render with validation
- [ ] FK dropdowns load data via ApiSelect
- [ ] Summary widgets display (5 KPI cards)
- [ ] Distribution child grid works in view/form page
- [ ] Service placeholder buttons render (Send Receipt, View Receipt, Refund, Download PDF)
- [ ] DB Seed — menu visible in sidebar

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: GlobalDonation
Module: Fundraising (CRM)
Schema: fund
Group: DonationModels (Backend), donation-service (Frontend)

Business: The Global Donation screen is the central hub for all donation management in PSS 2.0 (PeopleServe). It provides a unified view of every donation received by the NGO — regardless of channel (online, receipt book, cheque, cash, bank transfer, in-kind). Staff and administrators use this screen daily to record new donations, review incoming gifts, track payment statuses, generate and send receipts, and monitor fundraising KPIs. Each donation links to a donor contact, can be split across multiple donation purposes (distribution), and supports multi-currency with automatic base currency conversion. The screen is the most complex and heavily-used in the entire platform, connecting to Contacts, Campaigns, Receipt management, Refunds, and Reporting modules.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **STATUS**: Entity ALREADY EXISTS in backend. No BE entity changes needed.

Table: fund."GlobalDonations"

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| GlobalDonationId | int | — | PK | — | Primary key |
| CompanyId | int | — | YES | app.Companies | Tenant FK (from HttpContext) |
| DonationModeId | int | — | YES | sett.MasterDatas | Cash/Cheque/Online/Receipt/BankTransfer/InKind |
| DonationTypeId | int | — | YES | sett.MasterDatas | One-time/Recurring/Pledge |
| DonationAmount | decimal | — | YES | — | Primary donation amount |
| CurrencyId | int | — | YES | com.Currencies | Donation currency |
| ExchangeRate | decimal | — | YES | — | Rate to base currency |
| BaseCurrencyId | int | — | YES | com.Currencies | Organization base currency |
| BaseCurrencyAmount | decimal | — | YES | — | Computed: Amount × Rate |
| NetAmount | decimal | — | YES | — | Computed: Amount - Fee |
| FeeAmount | decimal | — | NO | — | Gateway/processing fee |
| DonationDate | DateTime | — | YES | — | Date of donation |
| ReceivedDate | DateTime? | — | NO | — | Date received by org |
| PostedDate | DateTime? | — | NO | — | Date posted to accounting |
| PaymentStatusId | int | — | YES | sett.MasterDatas | Completed/Pending/Failed/Refunded |
| ReceiptNumber | string | 100 | NO | — | Auto-generated receipt code |
| ReceiptIssuedBy | int? | — | NO | app.Staffs | Staff who issued receipt |
| ReceiptIssuedDate | DateTime? | — | NO | — | When receipt was issued |
| ReceiptSendMethodId | int? | — | NO | sett.MasterDatas | Email/WhatsApp/Print/DontSend |
| ReceiptSentTo | string | 100 | NO | — | Email/Phone of receipt dest |
| SourceTypeId | int? | — | NO | app.Branches | Branch/source of donation |
| IsIndividualDonation | bool | — | NO | — | Individual vs Corporate |
| Note | string | 1000 | NO | — | Internal note |
| ContactId | int? | — | NO | corg.Contacts | Donor contact (nullable for anonymous) |
| OrganizationalUnitId | int? | — | NO | app.OrganizationalUnits | Org unit allocation |

**Child Entities** (all ALREADY EXIST):

| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| GlobalDonationDistribution | 1:Many via GlobalDonationId | PurposeId (via ContactDonationPurpose), AllocatedAmount, ParticipantRoleId, DonationOccasionId, AllocationNote |
| GlobalOnlineDonation | 1:Many via GlobalDonationId | PaymentGatewayId, GatewayTransactionId, PaymentMethodId, TransactionStatusId, Fees |
| GlobalReceiptDonation | 1:Many via GlobalDonationId | ReceiptBookId, CollectedBy, PaymentMethodId |
| ChequeDonation | 1:Many via GlobalDonationId | ChequeNo, ChequeDate, BankId, ChequeStatusId, Images |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer + Frontend Developer
> All FK entities EXIST. Paths and GQL queries verified via glob/grep.

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ContactId | Contact | Base.Domain/Models/ContactModels/Contact.cs | GetContacts | displayName | ContactResponseDto |
| CurrencyId | Currency | Base.Domain/Models/SharedModels/Currency.cs | GetCurrencies | currencyName | CurrencyResponseDto |
| BaseCurrencyId | Currency | Base.Domain/Models/SharedModels/Currency.cs | GetCurrencies | currencyName | CurrencyResponseDto |
| DonationModeId | MasterData | Base.Domain/Models/SettingModels/MasterData.cs | GetMasterDatas | dataName | MasterDataResponseDto |
| DonationTypeId | MasterData | Base.Domain/Models/SettingModels/MasterData.cs | GetMasterDatas | dataName | MasterDataResponseDto |
| PaymentStatusId | MasterData | Base.Domain/Models/SettingModels/MasterData.cs | GetMasterDatas | dataName | MasterDataResponseDto |
| ReceiptSendMethodId | MasterData | Base.Domain/Models/SettingModels/MasterData.cs | GetMasterDatas | dataName | MasterDataResponseDto |
| ReceiptIssuedBy | Staff | Base.Domain/Models/ApplicationModels/Staff.cs | GetStaffs | staffName | StaffResponseDto |
| SourceTypeId | Branch | Base.Domain/Models/ApplicationModels/Branch.cs | GetBranches | branchName | BranchResponseDto |
| OrganizationalUnitId | OrganizationalUnit | Base.Domain/Models/ApplicationModels/OrganizationalUnit.cs | GetOrganizationalUnits | unitName | OrganizationalUnitResponseDto |
| PaymentGatewayId | PaymentGateway | Base.Domain/Models/SharedModels/PaymentGateway.cs | GetPaymentGateways | gatewayName | PaymentGatewayResponseDto |
| BankId | Bank | Base.Domain/Models/SharedModels/Bank.cs | GetBanks | bankName | BankResponseDto |

**Distribution child FKs:**
| FK Field | Target Entity | GQL Query Name | Display Field |
|----------|--------------|----------------|---------------|
| DonationPurposeId | DonationPurpose | GetDonationPurposes | donationPurposeName |
| DonationCategoryId | DonationCategory | GetDonationCategories | donationCategoryName |
| ParticipantRoleId | MasterData | GetMasterDatas | dataName |
| DonationOccasionId | MasterData | GetMasterDatas | dataName |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer → Frontend Developer
> **STATUS**: Most validation ALREADY EXISTS in BE. FE needs to implement form-level validation to match.

**Uniqueness Rules:**
- ReceiptNumber must be unique per Company (auto-generated, not user-entered)

**Required Field Rules:**
- CompanyId, DonationModeId, DonationTypeId, DonationAmount, CurrencyId, ExchangeRate, BaseCurrencyId, BaseCurrencyAmount, NetAmount, DonationDate, PaymentStatusId — all mandatory
- ContactId is optional (anonymous donations allowed via IsAnonymous checkbox)

**Conditional Rules:**
- If DonationMode = "Online" → show Online Payment fields (Gateway, TransactionId, PaymentMethod)
- If DonationMode = "Cheque" → show Cheque fields (ChequeNo, ChequeDate, Bank, ChequeStatus, Images)
- If DonationMode = "Receipt Book" → show Receipt fields (ReceiptBook, CollectedBy, CollectionDate)
- If DonationMode = "Bank Transfer" → show Transfer fields (Reference, FromBank, DepositedTo)
- If DonationMode = "In-Kind" → show In-Kind fields (ItemCategory, Description, EstimatedValue)
- If DonationMode = "Cash" → no additional payment sub-form needed

**Computed Fields:**
- BaseCurrencyAmount = DonationAmount × ExchangeRate (auto-calculate on change)
- NetAmount = DonationAmount - FeeAmount (auto-calculate on change)
- Distribution total must equal DonationAmount (allocation balance check)

**Business Logic:**
- DonationAmount must be > 0
- ExchangeRate must be > 0
- Sum of all distribution AllocatedAmounts must equal DonationAmount (balanced allocation)
- At least one distribution row is required
- Anonymous donations: ContactId is null, IsIndividualDonation is irrelevant
- Receipt generation is optional via toggle

**Workflow**: None (no state machine — PaymentStatus is a simple lookup, not a workflow)

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver
> **STATUS**: Pre-answered based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: Type 3 — Complex parent entity with multiple child collections, multi-mode payment sub-forms, summary widgets, and distribution grid
**Reason**: 3 HTML pages (list + form + detail), parent-child relationship (Donation → Distribution), conditional payment sub-forms, 5 KPI summary widgets, accordion form sections, 2-column detail layout — far beyond simple CRUD

**Backend Patterns Required:**
- [x] Standard CRUD (already exists — 11 files for GlobalDonation)
- [x] Nested child creation (Distribution, OnlineDonation, ReceiptDonation, ChequeDonation — already exist)
- [x] Multi-FK validation — already exists
- [x] Tenant scoping (CompanyId from HttpContext) — already exists
- [ ] Summary query (GetGlobalDonationSummary) — **NEW — needs to be added**

**Frontend Patterns Required:**
- [x] FlowDataTable (list page with navigation to view/form)
- [x] React Hook Form View Page (detail page with 2-column layout)
- [x] React Hook Form Edit Page (accordion form with 6 sections)
- [x] Child grid in view page (Distribution table)
- [x] Zustand store (FLOW screens only)
- [x] Unsaved changes dialog (FLOW screens only)
- [x] Summary cards / count widgets (5 KPI cards above grid)
- [ ] Grid aggregation columns — NONE needed (amounts are per-row fields, not aggregated)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup.

### Grid/List View

**Grid Columns** (in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | (checkbox) | — | checkbox | 36px | NO | Row selection for bulk actions |
| 2 | Receipt # | receiptNumber | link | 130px | YES | Clicks navigate to detail page. Shows "—" if no receipt |
| 3 | Date | donationDate | date | 110px | YES | Format: "Apr 10, 2026" |
| 4 | Contact | contact.displayName | avatar+text | auto | YES | Avatar with initials + clickable name |
| 5 | Purpose | distribution[0].purposeName | badge | 150px | YES | Colored badge per category |
| 6 | Amount | donationAmount | currency-right | 120px | YES | Right-aligned, monospace, with currency symbol |
| 7 | Currency | currency.currencyName | label | 70px | YES | Small label (e.g., "USD") |
| 8 | Mode | donationMode.dataName | icon+text | 160px | YES | Icon prefix (globe=online, file=receipt, cheque, gift=in-kind, repeat=recurring) |
| 9 | Status | paymentStatus.dataName | badge | 130px | YES | Colored badge: green=Completed, yellow=Pending, red=Failed, gray=Refunded |
| 10 | Receipt Sent | receiptSentTo | icon | 90px | NO | Check circle (green) or X circle (red) |
| 11 | Actions | — | dropdown | 44px | NO | View, Edit, View Receipt, Send Receipt, Refund, Delete |

**Search/Filter Fields**: searchText (searches by receipt number, contact name, amount)

**Date Range Filter**: donationDate from/to

**Filter Chips** (quick filters): All, Online, Receipt, Cheque, In-Kind, Recurring, Pending

**Advanced Filters**:
| Filter | Type | Source |
|--------|------|--------|
| Donation Purpose | multi-select | DonationPurpose lookup |
| Donation Category | select | DonationCategory lookup |
| Payment Mode | multi-select | MasterData lookup (DonationMode type) |
| Currency | select | Currency lookup |
| Amount Range | min/max number | User input |
| Payment Status | select | MasterData lookup (PaymentStatus type) |
| Branch | select | Branch lookup |
| Organizational Unit | select | OrganizationalUnit lookup |

**Bulk Actions** (when rows selected): Send Receipts, Export Selected, Bulk Status Update

**Grid Row Actions** (dropdown menu):
| Action | Type | Behavior |
|--------|------|----------|
| View | Navigate | Go to detail page (?mode=read&id={id}) |
| Edit | Navigate | Go to form page (?mode=edit&id={id}) |
| View Receipt | Modal | Open receipt preview modal (SERVICE_PLACEHOLDER) |
| Send Receipt | Action | Send receipt via selected channel (SERVICE_PLACEHOLDER) |
| Refund | Navigate | Navigate to refund screen (SERVICE_PLACEHOLDER) |
| Delete | Confirm | Confirmation dialog → soft delete |

### Form Layout (New/Edit Page)

**Form Type**: React Hook Form View Page (accordion sections)
**Navigation**: Back button → returns to list

**Form Sections** (accordion — in order):
| Section | Icon | Title | Layout | Fields |
|---------|------|-------|--------|--------|
| 1 | fa-user | Donor Information | 2-column | Contact (ApiSelect), Org Unit (ApiSelect), IsAnonymous (checkbox), DonorMiniCard (readonly display) |
| 2 | fa-hand-holding-heart | Donation Details | 2-column + full-width mode cards | DonationDate, ReceivedDate, DonationType (select), DonationMode (card selector — 6 cards: Online/Receipt Book/Cheque-DD/Cash/Bank Transfer/In-Kind) |
| 3 | fa-coins | Amount & Currency | 3-column | Currency (ApiSelect), DonationAmount (large input), (spacer), BaseCurrency (readonly), ExchangeRate, BaseCurrencyAmount (computed), FeeAmount, NetAmount (computed) |
| 4 | fa-layer-group | Purpose & Distribution | full-width child grid | Distribution rows (Purpose ApiSelect, Category readonly, AllocatedAmount, ParticipantRole select, Occasion select, Note text), Add Distribution button, Allocation status bar |
| 5 | fa-credit-card | Payment Details | 2-column (collapsed by default) | Dynamic sub-form based on DonationMode (5 variants — see Conditional Rules) |
| 6 | fa-envelope-open-text | Receipt & Communication | 2-column (collapsed by default) | GenerateReceipt toggle, DeliveryMethod card selector (Email/WhatsApp/Print/Don't Send), SendTo field, PrayerRequest textarea, Note textarea |

**Field Widget Mapping**:
| Field | Widget | Placeholder | Validation | Notes |
|-------|--------|-------------|------------|-------|
| ContactId | ApiSelectV2 | "Search contact by name, code or email..." | required (unless anonymous) | Query: GetContacts |
| OrganizationalUnitId | ApiSelectV2 | "Select unit..." | optional | Query: GetOrganizationalUnits |
| DonationDate | datepicker | — | required | Default: today |
| ReceivedDate | datepicker | — | optional | Default: today |
| DonationTypeId | select | — | required | Options: One-time, Recurring, Pledge Payment |
| DonationModeId | card-selector | — | required | 6 visual cards |
| CurrencyId | ApiSelectV2 | — | required | Query: GetCurrencies |
| DonationAmount | number (large) | "0.00" | required, > 0 | Monospace font |
| ExchangeRate | number | — | required, > 0 | |
| FeeAmount | number | "0.00" | optional | |
| DonationPurposeId | ApiSelectV2 | "Select purpose..." | required | Per distribution row |
| AllocatedAmount | number | "0.00" | required, > 0 | Per distribution row |
| ParticipantRoleId | select | — | optional | Options: Donor, Sponsor, Beneficiary |
| DonationOccasionId | select | — | optional | Options: General, Birthday, Memorial, Anniversary |
| PrayerRequest | textarea | "Enter prayer request if any..." | optional | |
| Note | textarea | "Internal note (not visible to donor)..." | optional | |

**Donor Mini Card** (shown when contact selected):
- Avatar (initials), Name, Engagement Score badge, Email, Phone, Last donation info

**Distribution Row Structure** (repeating child):
- Purpose (ApiSelect) | Category (auto-fill from purpose) | Allocated Amount | Participant Role (select) | Occasion (select) | Note (text) | Remove button
- "Add Distribution" button
- Allocation Status Bar: shows allocated vs total, balanced/unbalanced state

**Payment Sub-forms** (5 variants — conditionally shown):
1. **Online**: Gateway (ApiSelect), TransactionId, Reference, PaymentMethod (select), TransactionStatus (select)
2. **Receipt Book**: ReceiptBook (ApiSelect), ReceiptNumber (readonly/auto), CollectedBy (ApiSelect), CollectionLocation (text), CollectionDate
3. **Cheque/DD**: ChequeNo, ChequeDate, Bank (ApiSelect), BankBranch, AccountHolder, ChequeType (select), ChequeStatus (select), Front/Back image uploads
4. **Bank Transfer**: Reference, TransferDate, FromBank, DepositedTo (ApiSelect)
5. **In-Kind**: ItemCategory (select), ItemDescription (textarea), EstimatedValue, BillNo, BillDate, ValuationReceipt (upload)

**Receipt Delivery Method** (card selector):
- Email (shows contact email), WhatsApp (shows contact phone), Print, Don't Send (Generate Only)

### Detail/View Page (2-column layout)

**Left Column** (2fr):
| Card | Content |
|------|---------|
| Donation Summary | Receipt#, DonationDate, ReceivedDate, PostedDate, Mode (icon+text), Type, PaymentStatus (badge) |
| Amount | Large amount display, Exchange Rate, Base Currency Amount, Gateway Fee, Net Amount |
| Distribution | Table: Purpose (with category sub-text), Amount, Role, Occasion |
| Payment Details | Dynamic fields based on mode (Gateway, TransactionId, etc.) |
| Receipt | ReceiptIssued (yes/no), IssuedBy, SendMethod, SentTo, Download link |
| Prayer Request & Notes | Prayer request block, Internal note block |

**Right Column** (1fr):
| Card | Content |
|------|---------|
| Donor | Avatar, Name, ContactCode, Type badges, Engagement Score, Email, Phone, "View Full Profile" link |
| Donation History | Table of past donations (Date, Amount, Purpose) for same contact, "View All" link |
| Audit Trail | Timeline: Created, Receipt Generated, Receipt Emailed (with timestamps) |

**Header Actions**: Edit (→ form), Send Receipt (SERVICE_PLACEHOLDER), Print, More (Refund, Duplicate, Delete)

### Page Widgets & Summary Cards

**Widgets**: 5 KPI cards above the grid

| # | Widget Title | Value Source | Display Type | Position | Icon |
|---|-------------|-------------|-------------|----------|------|
| 1 | Total Donations (This Month) | GetGlobalDonationSummary.totalAmount | currency | Top-1 | fa-hand-holding-dollar (green) |
| 2 | Donation Count | GetGlobalDonationSummary.donationCount | count + "Avg: $X" subtitle | Top-2 | fa-hashtag (blue) |
| 3 | Recurring Active | GetGlobalDonationSummary.recurringCount | count + "$X/month" subtitle | Top-3 | fa-repeat (purple) |
| 4 | Online vs Offline | GetGlobalDonationSummary.onlinePercentage | percentage + mini pie | Top-4 | fa-globe (teal) |
| 5 | Pending Processing | GetGlobalDonationSummary.pendingCount | count + "$X pending" subtitle | Top-5 | fa-clock (orange) |

**Summary GQL Query** (NEW — needs to be added to BE):
- Query name: `GetGlobalDonationSummary`
- Returns: `GlobalDonationSummaryDto` with fields:
  - totalAmount (decimal), donationCount (int), averageAmount (decimal)
  - recurringCount (int), recurringMonthlyAmount (decimal)
  - onlinePercentage (decimal), offlinePercentage (decimal)
  - pendingCount (int), pendingAmount (decimal)
  - percentageChangeVsLastMonth (decimal)

### Grid Aggregation Columns

**Aggregation Columns**: NONE — amounts are direct entity fields, not computed aggregations across related tables

### User Interaction Flow

**FLOW pattern:**
1. User sees FlowDataTable list with 5 KPI summary cards → clicks "+New Donation" → navigates to ?mode=new
2. Form page loads with 6 accordion sections → fills donor info, selects mode, enters amount, adds distribution(s) → clicks "Save & Generate Receipt"
3. Success → redirects to ?mode=read&id={id} → detail page shows 2-column read-only layout
4. Edit: clicks Edit button → navigates to ?mode=edit&id={id} → form pre-fills
5. Back: clicks back → returns to list
6. View Receipt: clicks in grid → receipt preview modal opens (SERVICE_PLACEHOLDER)
7. Send Receipt: sends via selected channel (SERVICE_PLACEHOLDER)

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> **NOTE**: For this ALIGN screen, use the existing Donation code as reference, NOT the canonical SavedFilter/ContactType templates.

**Canonical Reference**: SavedFilter (FLOW) — but existing GlobalDonation code takes priority

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | GlobalDonation | Entity/class name |
| savedFilter | globalDonation | Variable/field names |
| SavedFilterId | GlobalDonationId | PK field |
| SavedFilters | GlobalDonations | Table name, collection names |
| saved-filter | globaldonation | FE route path, file names |
| savedfilter | globaldonation | FE folder, import paths |
| SAVEDFILTER | GLOBALDONATION | Grid code, menu code |
| notify | fund | DB schema |
| Notify | Donation | Backend group name |
| NotifyModels | DonationModels | Namespace suffix |
| NOTIFICATIONSETUP | CRM_DONATION | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/donation/globaldonation | FE route path |
| notify-service | donation-service | FE service folder name |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files (ALREADY EXIST — no new files needed, only modify)

All 11 standard CRUD files exist for GlobalDonation:
- Entity: `Base.Domain/Models/DonationModels/GlobalDonation.cs` ✅
- EF Config: exists ✅
- Schemas: `Base.Application/Schemas/DonationSchemas/GlobalDonationSchemas.cs` ✅
- CreateCommand, UpdateCommand, DeleteCommand, ToggleCommand: all exist ✅
- GetAll Query, GetById Query: exist ✅
- Mutations: `Base.API/EndPoints/Donation/Mutations/GlobalDonationMutations.cs` ✅
- Queries: `Base.API/EndPoints/Donation/Queries/GlobalDonationQueries.cs` ✅

**NEW backend file needed:**

| # | File | Path | Purpose |
|---|------|------|---------|
| 1 | Summary DTO | Base.Application/Schemas/DonationSchemas/GlobalDonationSummarySchemas.cs | GlobalDonationSummaryDto |
| 2 | Summary Query Handler | Base.Application/Business/DonationBusiness/GlobalDonations/Queries/GetGlobalDonationSummary.cs | Summary data aggregation |
| 3 | Summary GQL Endpoint | Add to existing GlobalDonationQueries.cs | GetGlobalDonationSummary method |

### Backend Wiring Updates (MINIMAL)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | GlobalDonationQueries.cs | Add GetGlobalDonationSummary endpoint |
| 2 | DonationMappings.cs | Add GlobalDonationSummaryDto mapping (if needed) |

### Frontend Files (MAJOR — create new FLOW components)

**Existing FE files** (to be MODIFIED or REPLACED):

| # | File | Path | Status |
|---|------|------|--------|
| 1 | Route Page | PSS_2.0_Frontend/src/app/[lang]/(core)/crm/donation/globaldonation/page.tsx | EXISTS — keep |
| 2 | Page Config | PSS_2.0_Frontend/src/presentation/pages/crm/donation/globaldonation.tsx | EXISTS — modify to use FlowDataTable |
| 3 | DTO Types | PSS_2.0_Frontend/src/domain/entities/donation-service/GlobalDonationDto.ts | EXISTS — extend with SummaryDto |
| 4 | GQL Query | PSS_2.0_Frontend/src/infrastructure/gql-queries/donation-queries/GlobalDonationQuery.ts | EXISTS — add summary query |
| 5 | GQL Mutation | PSS_2.0_Frontend/src/infrastructure/gql-mutations/donation-mutations/GlobalDonationMutation.ts | EXISTS — keep |
| 6 | Entity Operations | PSS_2.0_Frontend/src/application/configs/data-table-configs/donation-service-entity-operations.ts | EXISTS — update getAll config |
| 7 | Data Table | PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/data-table.tsx | EXISTS — REPLACE with FlowDataTable |

**New FE files** to create:

| # | File | Path |
|---|------|------|
| 1 | Index Page | PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/index.tsx |
| 2 | Index Page Component | PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/index-page.tsx |
| 3 | View Page | PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/view-page.tsx |
| 4 | Form Component | PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/donation-form.tsx |
| 5 | Zustand Store | PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/globaldonation-store.ts |
| 6 | Summary Widgets | PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/donation-summary.tsx |
| 7 | Receipt Modal | PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/receipt-modal.tsx |
| 8 | Distribution Grid | PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/distribution-grid.tsx |
| 9 | Summary DTO | PSS_2.0_Frontend/src/domain/entities/donation-service/GlobalDonationSummaryDto.ts |
| 10 | Summary Query | PSS_2.0_Frontend/src/infrastructure/gql-queries/donation-queries/GlobalDonationSummaryQuery.ts |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | donation-service-entity-operations.ts | Update GLOBALDONATION config for FlowDataTable |
| 2 | globaldonation.tsx (page config) | Switch from AdvancedDataTable to FLOW index component |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase
> **NOTE**: DB Seed menu entry likely ALREADY EXISTS. Verify before regenerating.

```
---CONFIG-START---
Scope: ALIGN

MenuName: All Donations
MenuCode: GLOBALDONATION
ParentMenu: CRM_DONATION
Module: CRM
MenuUrl: crm/donation/globaldonation
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  SUPERADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT
  ADMINISTRATOR: READ, CREATE, MODIFY, DELETE, TOGGLE, EXPORT
  STAFF: READ, CREATE, MODIFY, EXPORT
  STAFFDATAENTRY: READ, CREATE, MODIFY
  STAFFCORRESPONDANCE: READ
  SYSTEMROLE:

GridFormSchema: SKIP
GridCode: GLOBALDONATION
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer
> **STATUS**: All CRUD endpoints ALREADY EXIST. Only Summary query is NEW.

**GraphQL Types:**
- Query type: `GlobalDonationQueries` (exists)
- Mutation type: `GlobalDonationMutations` (exists)

**Queries (EXISTING):**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetGlobalDonations | [GlobalDonationResponseDto] | GridFeatureRequest (searchTerm, pageNo, pageSize, sortField, sortDir, advancedFilter) |
| GetGlobalDonationById | GlobalDonationResponseDto | globalDonationId |

**Queries (NEW — to be added):**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetGlobalDonationSummary | GlobalDonationSummaryDto | — (company-scoped, month filter optional) |

**Mutations (ALL EXISTING):**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| CreateGlobalDonation | GlobalDonationRequestDto | int (new ID) |
| UpdateGlobalDonation | GlobalDonationRequestDto | int |
| DeleteGlobalDonation | globalDonationId | int |
| ActivateDeactivateGlobalDonation | globalDonationId | int |

**Response DTO Fields** (what FE receives — ALL EXISTING):
| Field | Type | Notes |
|-------|------|-------|
| globalDonationId | number | PK |
| companyId | number | Tenant |
| donationModeId | number | FK |
| donationMode | { dataName } | FK display |
| donationTypeId | number | FK |
| donationType | { dataName } | FK display |
| donationAmount | number | Primary amount |
| currencyId | number | FK |
| currency | { currencyName, currencySymbol } | FK display |
| exchangeRate | number | |
| baseCurrencyId | number | FK |
| baseCurrency | { currencyName, currencySymbol } | FK display |
| baseCurrencyAmount | number | Computed |
| netAmount | number | Computed |
| feeAmount | number | |
| donationDate | string | ISO date |
| receivedDate | string | ISO date |
| postedDate | string | ISO date |
| paymentStatusId | number | FK |
| paymentStatus | { dataName } | FK display |
| receiptNumber | string | |
| receiptIssuedBy | number | FK |
| receiptIssued | { staffName } | FK display |
| receiptIssuedDate | string | ISO date |
| receiptSendMethodId | number | FK |
| receiptSendMethod | { dataName } | FK display |
| receiptSentTo | string | |
| sourceTypeId | number | FK |
| donationSourceType | { branchName } | FK display |
| isIndividualDonation | boolean | |
| note | string | |
| contactId | number | FK |
| contact | { displayName } | FK display |
| organizationalUnitId | number | FK |
| organizationalUnit | { unitName } | FK display |
| isActive | boolean | |

**Summary DTO Fields (NEW):**
| Field | Type | Notes |
|-------|------|-------|
| totalAmount | number | Sum of donations this month |
| donationCount | number | Count of donations this month |
| averageAmount | number | Average donation amount |
| recurringCount | number | Active recurring schedules |
| recurringMonthlyAmount | number | Total monthly recurring |
| onlinePercentage | number | % of online donations |
| offlinePercentage | number | % of offline donations |
| pendingCount | number | Pending processing count |
| pendingAmount | number | Total pending amount |
| percentageChangeVsLastMonth | number | Month-over-month change % |

---

## ⑪ Acceptance Criteria

> **Consumer**: Verification phase

**Build Verification:**
- [ ] `dotnet build` — no errors (new summary query compiles)
- [ ] `pnpm dev` — page loads at `/en/crm/donation/globaldonation`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] **List Page**: Grid loads with columns: Receipt#, Date, Contact, Purpose, Amount, Currency, Mode, Status, Receipt Sent
- [ ] **Summary Widgets**: 5 KPI cards above grid show data (Total Amount, Count, Recurring, Online/Offline, Pending)
- [ ] **Search**: Filters by receipt number, contact name
- [ ] **Filter Chips**: All/Online/Receipt/Cheque/In-Kind/Recurring/Pending quick filters work
- [ ] **Advanced Filters**: Purpose, Category, Mode, Currency, Amount Range, Status, Branch, Org Unit filters work
- [ ] **Add new**: Click "New Donation" → form page loads with 6 accordion sections
- [ ] **Form — Donor**: Contact ApiSelect works, donor mini-card shows on selection, anonymous toggle works
- [ ] **Form — Details**: Donation mode card selection works, shows/hides payment sub-form
- [ ] **Form — Amount**: Currency select, auto-calculation of base currency amount and net amount
- [ ] **Form — Distribution**: Add/remove distribution rows, purpose select, allocation balance check
- [ ] **Form — Payment**: Conditional sub-forms render for each mode (Online/Cheque/Receipt/Transfer/InKind)
- [ ] **Form — Receipt**: Delivery method card selector, send-to field updates
- [ ] **Save**: Creates donation → redirects to detail page
- [ ] **Detail Page**: 2-column layout shows all donation info, donor profile, distribution table, audit trail
- [ ] **Edit**: Pre-fills form → save updates → detail page refreshes
- [ ] **Toggle**: Active/inactive toggle works from grid
- [ ] **Delete**: Soft delete with confirmation
- [ ] **Permissions**: Buttons/actions respect GLOBALDONATION role capabilities

**Service Placeholder Verification:**
- [ ] "Send Receipt" button renders and shows "Coming soon" toast
- [ ] "View Receipt" modal opens with receipt preview (static/placeholder data)
- [ ] "Refund" action navigates to refund page (or shows placeholder)
- [ ] "Download PDF" button in receipt modal shows placeholder

**DB Seed Verification:**
- [ ] Menu appears in sidebar under CRM > Donations > All Donations
- [ ] Grid columns render correctly (if grid config exists)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents

**CRITICAL — This is a CODE_EXISTS/ALIGN screen:**
- Backend is COMPREHENSIVE and COMPLETE. All 11 CRUD files + 4 child entity sets exist.
- DO NOT regenerate backend CRUD — only add the Summary query endpoint.
- Frontend needs a MAJOR upgrade from AdvancedDataTable (MASTER_GRID pattern) to FlowDataTable (FLOW pattern).
- The existing FE route at `src/app/[lang]/(core)/crm/donation/globaldonation/page.tsx` MUST be preserved — do not create a new route.
- Existing entity-operations config for GLOBALDONATION must be updated, not duplicated.
- The existing GQL queries and mutations must be REUSED, not recreated.

**Scope of FE Changes:**
- Replace `data-table.tsx` (AdvancedDataTable → FlowDataTable with summary widgets)
- Add `index.tsx` / `index-page.tsx` (FLOW page routing: list ↔ view ↔ form)
- Add `view-page.tsx` (2-column detail layout matching donation-detail.html)
- Add donation form component (6 accordion sections matching donation-form.html)
- Add Zustand store for FLOW state management
- Add summary widgets component
- Add receipt preview modal component
- Add distribution child grid component

**Entity Naming:**
- Backend entity is `GlobalDonation` (not just `Donation`) — use this consistently
- FE route segment is `globaldonation` (no dash, no space)
- Grid code is `GLOBALDONATION`
- Menu code is `GLOBALDONATION`

**CompanyId**: Comes from HttpContext in FLOW screens — NOT a field in the form.

**FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it.

**Service Dependencies** (UI-only — no backend service implementation):
- SERVICE_PLACEHOLDER: "Send Receipt" button (Email/WhatsApp/Print) — render the delivery method selector and send button, but use a placeholder handler that shows "Receipt sending coming soon" toast.
- SERVICE_PLACEHOLDER: "View Receipt" modal — render the receipt preview modal with formatted receipt data, but "Download PDF" and "Print" buttons use placeholder handlers.
- SERVICE_PLACEHOLDER: "Refund" action — render the navigation link/button, but target page may not exist yet. Use `router.push('/crm/donation/refund')` or show toast if route doesn't exist.
- SERVICE_PLACEHOLDER: "Bulk Actions" (Send Receipts, Export Selected, Bulk Status Update) — render the bulk action bar when rows are selected, but use placeholder handlers.
- SERVICE_PLACEHOLDER: "Duplicate" action in detail page — render the button but show "Feature coming soon" toast.
- Note: For all SERVICE_PLACEHOLDER items — implement full UI (buttons, modals, card selectors, grid interactions) but bind to placeholder actions. The user interaction flow must be complete even if the backend service doesn't exist yet.

**Complexity Warning:** This is the HIGHEST complexity screen in the entire registry. The form alone has 6 sections with conditional sub-forms, child distribution grid, computed fields, and card selectors. Plan for multiple build iterations. Consider breaking FE work into sub-tasks: (1) list page + summary, (2) form page, (3) detail page.
