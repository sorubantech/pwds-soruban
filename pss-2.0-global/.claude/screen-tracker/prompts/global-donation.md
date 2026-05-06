---
screen: GlobalDonation
registry_id: 1
module: Fundraising
status: NEEDS_FIX
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-16
completed_date: 2026-04-30
last_session_date: 2026-05-02
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
- [x] dotnet build passes             ← Base.Application 0 errors, 0 warnings (Session 2 — direct project build); full-sln Session 2 build hit only MSB3026/3027/3021 file-lock errors from Base.API/bin (VS Insiders running API process locks DLLs); zero CS compile errors anywhere
- [x] TypeScript check passes         ← 0 errors (Session 2 — `npx tsc --noEmit`)
- [ ] pnpm dev — page loads at correct route                       ← user-side E2E remains
- [ ] CRUD flow tested (Create → Read → Update → Toggle → Delete)  ← user-side E2E remains
- [ ] Grid columns render correctly with search/filter             ← requires DB seed apply
- [ ] Form fields render with validation                           ← user-side E2E
- [ ] FK dropdowns load data via ApiSelect                         ← user-side E2E
- [ ] Summary widgets display (5 KPI cards)                        ← user-side E2E (BE Summary endpoint shipped Session 2)
- [ ] Distribution child grid works in view/form page              ← KI-6/KI-7 caveats — see Build Log
- [ ] Service placeholder buttons render (Send Receipt, View Receipt, Refund, Download PDF)  ← user-side E2E
- [ ] DB Seed — menu visible in sidebar                            ← user must run `GlobalDonation-sqlscripts.sql`

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

---

## ⑬ Build Log

> **Consumer**: `/continue-screen` and future maintainers
> **Note**: This section was added retroactively on 2026-04-30. Session 0 is a synthesized entry reconstructed from frontmatter — file-touch detail was not recorded at original build time.

### § Known Issues

| ID | Opened (Session) | Status | Severity | Area | Description |
|----|------------------|--------|----------|------|-------------|
| KI-1 | Session 1 | CLOSED (Session 2) | High | FE | "New" button on list page does nothing. Page-config still renders legacy `GlobalDonationDataTable` (AdvancedDataTable); its modal-form has no GridFormSchema (FLOW screens skip schema), so the dialog renders empty. Root cause: FLOW upgrade was abandoned partway — only `index-page.tsx` exists; dispatcher `index.tsx`, `view-page.tsx`, `donation-form.tsx`, store, summary, distribution-grid, receipt-modal all missing despite Tasks checklist marking them generated. **Resolution (Session 2)**: dispatcher `index.tsx` created; all 7 missing FLOW components shipped; legacy `data-table.tsx` deleted. "New" button now navigates to `?mode=new` and renders `<GlobalDonationForm />`. |
| KI-2 | Session 1 | CLOSED (Session 2) | High | FE | Page-config not switched to FLOW — [globaldonation.tsx:5,19](PSS_2.0_Frontend/src/presentation/pages/crm/donation/globaldonation.tsx) imports/renders `GlobalDonationDataTable` (legacy) instead of a FLOW dispatcher. Section ⑧ "Frontend Wiring Updates" item #2 was not applied. **Resolution (Session 2)**: page-config now `import GlobalDonationIndex from "@/presentation/components/page-components/crm/donation/globaldonation"` (folder default → `index.tsx` dispatcher) and renders `<GlobalDonationIndex />`. |
| KI-3 | Session 1 | CLOSED (Session 2) | Med  | FE | Barrel [index.ts](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/index.ts) re-exports only the legacy `GlobalDonationDataTable` — `GlobalDonationIndexPage` is created but not exported via the barrel. **Resolution (Session 2)**: legacy `index.ts` barrel deleted; folder default-imports resolve to `index.tsx` dispatcher (TS module resolution). Mirrors ChequeDonation FLOW precedent. |
| KI-4 | Session 1 | CLOSED (Session 2) | Low  | FE | gridCode mismatch — code uses `"DONATION"` ([data-table.tsx:8](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/data-table.tsx#L8) and [index-page.tsx:36](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/index-page.tsx#L36)) and capability check uses `menuCode: "DONATION"` ([globaldonation.tsx:9](PSS_2.0_Frontend/src/presentation/pages/crm/donation/globaldonation.tsx#L9)), but Section ⑨ approval config + entity-operations registration ([donation-service-entity-operations.ts:153](PSS_2.0_Frontend/src/application/configs/data-table-configs/donation-service-entity-operations.ts#L153)) all specify `GLOBALDONATION`. Verify which code matches the seeded grid/menu rows; one side is wrong. **Resolution (Session 2)**: standardized on `GLOBALDONATION` everywhere — [index-page.tsx:38](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/index-page.tsx#L38) `gridCode="GLOBALDONATION"`, [globaldonation.tsx:17](PSS_2.0_Frontend/src/presentation/pages/crm/donation/globaldonation.tsx#L17) `menuCode: "GLOBALDONATION"`, [donation-service-entity-operations.ts:153](PSS_2.0_Frontend/src/application/configs/data-table-configs/donation-service-entity-operations.ts#L153) `gridCode: "GLOBALDONATION"`. Verified by grep: zero `"DONATION"` (with quotes) remains in changed files. DB seed reality: MenuCode + GridCode both `'GLOBALDONATION'` per `Pss2.0_Old_Menu_List.sql:9`, `Pss2.0_Global_Menus_List.sql:292`, and the new `GlobalDonation-sqlscripts.sql`. |
| KI-5 | Session 2 | OPEN | Low | BE | Summary handler (`GetGlobalDonationSummary.cs`) classifies online/pending/recurring via `MasterData.DataValue == "ONL" / "PEN" / "REC"`. No existing handler in the codebase grep'd against `'ONL'` — sibling summary handlers use other TypeCodes (CHEQUESTATUS, DIKSTATUS, RDSCHEDULESTATUS). Spec §⑩ specified these values. **Risk**: if PAYMENTMODE / PAYMENTSTATUS / DONATIONTYPE seeds use different DataValues (e.g. `'ONLINE'` / `'PENDING'` / `'RECURRING'`), the corresponding KPI reads zero silently. **Mitigation**: constants are at the top of the handler — easy to swap. **How to apply**: verify against actual MasterData seed once user runs the seed; adjust constants if needed. |
| KI-6 | Session 2 | OPEN | High | FE | **Distribution child rows not persisted on save.** `donation-form.tsx` collects rows in component state and shows a toast "{N} distribution rows captured — child persistence pending." after save. Parent `GlobalDonation` is created/updated correctly. The child mutation `CREATE_GLOBALDONATIONDISTRIBUTION_MUTATION` exists in the codebase, but the BE contract for nested-by-parent vs. separate child create is not finalized in the spec — left for a focused follow-up to avoid shipping an untested write path. **How to apply**: decide nested vs separate persistence, wire the post-create child mutation loop in the form's `onSubmit`. |
| KI-7 | Session 2 | OPEN | Med | FE/BE | **`GlobalDonationResponseDto` does NOT surface nested distributions on `globalDonationById`.** View-page's Distribution card therefore renders `<DistributionGrid>` with `initialRows={[]}`. To show real data: (a) extend BE `GetGlobalDonationById` to project `donation.globalDonationDistributions` nested, OR (b) FE adds a separate `GLOBALDONATIONDISTRIBUTIONS_QUERY` filtered by `globalDonationId`. Does NOT block save/edit/list flows. |
| KI-8 | Session 2 | OPEN | Low | FE | **Donor mini-card placeholder.** The form's donor preview shows only `Contact #N` text. Mockup expects avatar / engagement-score / email / phone / last-donation. Resolving requires a separate `CONTACTS_BY_ID_QUERY` lookup; deferred so Variant B + Section 1 of the form ships intact. |
| KI-9 | Session 2 | OPEN | Low | FE | **DonationHistoryCard empty-state.** View-page right column renders "History view coming soon" instead of donor's past donations. Requires a separate query (donor's past donations); not in scope this session. |
| KI-10 | Session 2 | OPEN | Med | FE | **Receipt delivery method `modeMap` mis-keyed.** The receipt delivery card-selector currently shares the `modeMap` loaded for `MasterDataType=DONATIONMODE`. It will only resolve `EMAIL/WHATSAPP/PRINT/NONE` if those `dataValue`s exist under `DONATIONMODE` (they belong under `RECEIPTSENDMETHOD`). If unresolved, the cards render disabled. **Fix**: add a second `MASTERDATAS_QUERY` keyed by `RECEIPTSENDMETHOD` (or a unified `useMasterDataByTypeCode` hook); otherwise the form may save with `receiptSendMethodId: null` silently. |
| KI-11 | Session 2 | OPEN | Low | FE | **`baseCurrencyId` fallback to `currencyId`.** If user doesn't pick a base currency on the form, save uses the same id as `currencyId`. Mockup expects org base currency from a tenant-scoped lookup (not yet exposed via FE config). Fallback keeps the form submittable. |
| KI-12 | Session 2 | OPEN | Low | FE/BE | **Distribution readonly-mode display fields show "—".** `view-page.tsx` Distribution table (and `<DistributionGrid mode="readonly">`) shows "—" for ParticipantRole / Occasion / PurposeName because the BE distribution DTO doesn't surface joined display-name fields. Shape is ready; once BE projection lands, the read view picks them up automatically. |
| KI-13 | Session 3 | OPEN | Low | BE | **Advisory lock substituted for `SELECT ... FOR UPDATE`** in `GlobalDonationReceiptNumberer.GenerateAsync`. Spec ⑮.3 step 5 specified `FromSqlInterpolated` row-lock; that extension lives on `Microsoft.EntityFrameworkCore.Relational` which `Base.Application` does not reference. Implemented `pg_advisory_xact_lock(key)` via `IApplicationDbContext.ExecuteRawSqlAsync` instead — exclusive, transaction-scoped, per-company (key = `(0x52455054 << 20) ^ companyId`). Semantics equivalent and arguably superior (works even before the config row exists). **How to apply**: if a future refactor exposes `FromSqlInterpolated` to Application layer or moves the helper down to Infrastructure, switch back to row-lock for closer fidelity to spec. |
| KI-14 | Session 3 | OPEN | Med | BE | **`CreateGlobalOnlineDonation` inline-parent-create path NOT wired to generator.** Spec ⑮.4 row #5 asks to wire when `globalDonationId == 0`. Inspection showed the handler has no inline parent-create branch at all — only updates an existing parent or creates the child against a pre-existing parent. The composite path `CreateGlobalDonationWithChildren` IS wired (handles all online donations created from the new FLOW form). Comment block placed at the natural insertion point documenting the intent. **How to apply**: if/when an inline-parent-create branch is added to `CreateGlobalOnlineDonation`, drop in `await GlobalDonationReceiptNumberer.GenerateAsync(dbContext, companyId, "OD", gd.DonationDate, ct)` before `Add(gd)`. |
| KI-15 | Session 3 | OPEN | Low | BE | **Cheque mode code passed as `"CHQ"`** in `CreateChequeDonation.cs` invocation. The spec ⑮.3 algorithm only short-circuits on `"RECEIPTBOOK"`, so the exact value passed for non-receipt-book modes is functionally irrelevant for *this* helper. But the constant is now load-bearing for any future mode-aware logic in the helper (e.g. mode-specific patterns). **How to apply**: when MasterData seed for `PAYMENTMODE` is finalized, audit that the actual `DataValue` for cheque is in fact `'CHQ'` (vs `'CHEQUEDD'` referenced in some places); adjust the constant centrally if wrong. |
| KI-16 | Session 3 | SUPERSEDED (Session 4) | Low | BE | **`CreateGlobalReceiptDonation` is comment-only** — no `GenerateAsync` call placed. Per ⑮.3 step 1, RECEIPTBOOK mode short-circuits to `null`, so calling the generator would be a no-op. Existing logic mirrors `ReceiptBookSerialNo` into `ReceiptNumber` — that path is preserved. **Session 4 redesign**: behavior unchanged — `CreateGlobalReceiptDonation` and `CreateGlobalOnlineDonation` remain unwired (no inline parent-create branch); composite path covers actual creation. |
| KI-17 | Session 4 | CLOSED (Session 4) | High | BE | **Multi-tenant FY-key regression introduced and fixed during the same session.** The agent's first-pass `NumberSequenceGenerator.BuildFyKey` dropped the `WHERE CompanyId = companyId` filter from the `CompanyConfigurations` lookup — would have picked any tenant's `FinancialYearStartMonth` in a multi-company DB. Caught during review by comparing against last session's helper. Fixed in [NumberSequenceGenerator.cs:185](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Services/NumberSequence/NumberSequenceGenerator.cs#L185) by threading `companyId` through `ComputePeriodKey → BuildFyKey`. Build re-verified clean. **Why logged**: catches a class of regression worth watching for on any future helper refactor — multi-tenant filter dropouts are silent until a second tenant's data exists. |
| KI-18 | Session 4 | OPEN | Low | BE | **`BuildFyKey` does a synchronous DB read inside an async helper** ([NumberSequenceGenerator.cs:185](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Services/NumberSequence/NumberSequenceGenerator.cs#L185)). The agent kept `ComputePeriodKey` non-async to avoid making the period-key computation async-only (it's a small set of pure transformations). The sync EF call momentarily blocks the calling thread. For the FY-policy code path (rare, runs once per donation create) this is acceptable. **How to apply**: if a connection-pool starvation issue ever surfaces under load, convert `ComputePeriodKey` + `BuildFyKey` to async and propagate. |
| KI-19 | Session 4 | OPEN | Low | BE | **Two indexes on `(CompanyId, NumberSequenceEntityTypeId)`**: EF's fluent `HasIndex` auto-generated the non-unique `IX_NumberSequenceConfigs_CompanyId_NumberSequenceEntityTypeId`, while the migration adds a partial unique index `UX_NumberSequenceConfigs_Company_Kind_NotDeleted` via raw SQL. Both coexist. The non-unique one is functionally redundant (the partial unique one already serves lookup queries that hit `WHERE IsDeleted = false`). **How to apply**: optionally drop the auto-generated index in a follow-up migration if Postgres EXPLAIN shows it's unused; otherwise leave — the storage cost is trivial. |
| KI-20 | Session 5 | CLOSED (Session 5) | High | BE | **`createGlobalDonationWithChildren` violated `FK_ChequeDonations_MasterDatas_ChequeStatusId`** for CHQ/CHEQUEDD mode. Mapster `.Adapt<>()` into `ChequeDonation` left `ChequeStatusId = 0` because FE never sends it (per ISSUE-8 server-default contract). Standalone `CreateChequeDonation` resolved it but the composite handler did not. **Fix**: resolve `recChequeStatusId = MasterData(REC, CHEQUESTATUS)` once before the transaction and override `cd.ChequeStatusId` after `.Adapt`. |
| KI-21 | Session 5 | CLOSED (Session 5) | Med | BE | **`createGlobalDonationWithChildren` skipped ChequeNo uniqueness validation** — DB unique constraint surfaced as a generic Postgres error rather than a friendly FluentValidation message. **Fix**: added `When(x.Payload.ChequeDonation != null)` block mirroring the standalone `CreateChequeDonation` validator (required ChequeTypeId/ChequeNo/ChequeDate + `MustAsync` uniqueness rule). |
| KI-22 | Session 5 | CLOSED (Session 5) | High | BE | **NRE during composite-create response building** — `GlobalDonationDistributionResponseDto` declares 5 non-nullable nav DTOs (`default!`) including a `GlobalDonation` back-reference. After SaveChanges EF wires `dist.GlobalDonation = gd`; Mapster's recursive nested-DTO mapping then cycled / NPE'd on unloaded child navs. Same root cause hit `ChequeDonationResponseDto` because its mapping config walks `src.GlobalDonation.Contact.DisplayName`, `src.ChequeStatus.DataValue`, etc. **Fix**: (a) scalar-only manual projection for `Distributions` and `ChequeDonation` in the response; (b) `DetachGlobalDonationBackRefs(gd)` helper called once before adapting; (c) `SafeAdapt<T>(adapt, label)` wrapper around the remaining `.Adapt<>` calls so any future NRE surfaces with the destination DTO name. |
| KI-23 | Session 5 | CLOSED (Session 5) | Med | BE/FE | **In-Kind Donation valuation lifecycle introduced.** Locked design: DIK donations have unknown monetary value at receipt; staff records `IntendedUse` + optional `EstimatedAmount` on Create; valuation status is server-derived (PENDING / ESTIMATED / NON_MONETARY / REALIZED); a new `realizeInKindDonation` command transitions PENDING/ESTIMATED → REALIZED with the actual sale proceeds and rescales the parent `GlobalDonation.DonationAmount` + the single distribution. Added 6 columns to `DonationInKind`, 2 new MasterDataTypes (INTENDEDUSE, VALUATIONSTATUS), 1 new command + GraphQL mutation, 8 FE file changes (form + distribution-grid + new realize-modal + view-page). **FE rules**: DIK mode locks DonationAmount + AllocatedAmount to read-only, hides "Add Distribution" button, single distribution row only. |
| KI-24 | Session 5 | OPEN | High | DB | **EF migration for DIK valuation lifecycle columns deferred** — running API at the time of generation locked Base.Domain/Infrastructure/Application binaries; `dotnet ef migrations add` produced an empty migration. Entity + EF config + snapshot are NOT regenerated. **How to apply**: stop the API process, run `cd PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure && dotnet ef migrations add Add_DonationInKind_ValuationLifecycle_Columns --startup-project ../Base.API/Base.API.csproj`. Verify the generated `.cs` has 6 `AddColumn` operations + 2 new FK indexes; then `dotnet ef database update`. After the schema is applied, run `Base/sql-scripts-dyanmic/DonationInKind-ValuationLifecycle-sqlscripts.sql` to seed the INTENDEDUSE + VALUATIONSTATUS master data. |
| KI-25 | Session 5 | OPEN | Low | BE | **`GlobalDonation.DonationAmount` is `0` for non-monetary DIK** rather than NULL. Reporting queries that `SUM(DonationAmount)` will include `0` from internal-use items — semantically correct but semantically distinct rows must filter on `DonationInKind.ValuationStatus.DataValue = 'NON_MONETARY'` to exclude or report separately. Documented decision in [feedback memory] — not switching to nullable to avoid the `COALESCE` blast radius across ~50+ queries. |
| KI-26 | Session 7 | CLOSED (Session 7 — Path A) | High | BE/FE/DB | **Pledge Donation flow now implemented (Path A — schema-aligned).** §⑯ original design assumed a new `PledgeDonations` mapping table + `Pledge.GivenAmount/BalanceAmount` columns + new PLEDGESTATUS values (`OPEN/PARTIALLY_FULFILLED`). Verified during Session 7 that this contradicted the live schema: `Pledge` is the header, `PledgePayment` is the existing 1:N installment ledger that **already** has `GlobalDonationId` / `PaidDate` / `PaidAmount` / `PaymentStatusId` — the row that §⑯ wanted to add. Existing PLEDGESTATUS values are `ONTRACK / FULFILLED / OVERDUE / BEHIND / CANCELLED`; PLEDGEPAYMENTSTATUS is `PAID / UPCOMING / SCHEDULED / OVERDUE`. **Path A** (user-confirmed): no new entity, no migration, no MasterData seed; donor with `DonationType=PLEDGE` picks one or more open scheduled installments (PledgePayment rows where `PaidDate IS NULL` AND `GlobalDonationId IS NULL` AND `IsCancelled = false`); strict-pay rule (`PaidAmount == DueAmount`); on save, BE stamps the rows + recomputes `Pledge.PledgeStatusId` (all paid → FULFILLED, any past-due unpaid → OVERDUE, else ONTRACK). §⑯ is now marked HISTORICAL — see Session 7 Build Log entry for the actual shipped contract. |

### § Sessions

#### Session 0 — 2026-04-16 — BUILD — COMPLETED

- **Scope**: Initial FLOW upgrade build — added Summary query (BE), 8 new FLOW components (FE), DB seed for menu/capabilities.
- **Files touched**:
  - BE: (retroactive — not recorded; per Tasks checklist: GlobalDonationSummarySchemas.cs, GetGlobalDonationSummary.cs handler, GlobalDonationQueries.cs endpoint addition)
  - FE: (retroactive — not recorded; per Tasks checklist: index.tsx, index-page.tsx, view-page.tsx, donation-form.tsx, globaldonation-store.ts, donation-summary.tsx, receipt-modal.tsx, distribution-grid.tsx, GlobalDonationSummaryDto.ts, GlobalDonationSummaryQuery.ts)
  - DB: (retroactive — not recorded; FLOW upgrade seed with idempotent menu/capabilities for GLOBALDONATION)
- **Deviations from spec**: None recorded.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Next step**: Manual E2E verification still pending (pnpm dev page load, CRUD flow, grid columns, form fields, FK dropdowns, summary widgets, distribution child grid, service placeholder buttons, DB seed sidebar visibility — see Tasks § Verification).

#### Session 1 — 2026-04-30 — FIX — BLOCKED

- **Scope**: User reported "'New' button not work" on Donation list page. Audit revealed the FLOW upgrade was only partially executed despite Tasks checklist marking generation [x]. Status corrected COMPLETED → PARTIALLY_COMPLETED to route the work to `/build-screen #1`.
- **Files touched**:
  - BE: None (audit only).
  - FE: None (audit only — no fix applied).
  - DB: None.
  - Spec: `.claude/screen-tracker/prompts/global-donation.md` frontmatter `status: COMPLETED → PARTIALLY_COMPLETED`, `last_session_date: 2026-04-30` added; Section ⑬ Build Log retroactively added (Session 0 + Session 1); Known Issues KI-1..KI-4 logged.
  - Registry: `.claude/screen-tracker/REGISTRY.md` row #1 status updated.
- **Deviations from spec**: None recorded — the audit found the *implementation* deviated from spec (Section ⑧ file manifest items 1–8 not present on disk; wiring update #2 not applied).
- **Known issues opened**: KI-1, KI-2, KI-3, KI-4.
- **Known issues closed**: None.
- **Next step**: Run `/build-screen #1` to resume the FLOW upgrade. Backend Summary query (DTO + Handler + GQL endpoint per Section ⑧) and Frontend FLOW components (dispatcher `index.tsx`, `view-page.tsx`, `donation-form.tsx`, `globaldonation-store.ts`, `donation-summary.tsx`, `distribution-grid.tsx`, `receipt-modal.tsx`, summary DTO/query) all need to be created. Wiring updates: switch barrel to export `GlobalDonationIndexPage` + dispatcher; switch page-config to render dispatcher; reconcile gridCode/menuCode (`DONATION` vs `GLOBALDONATION` per KI-4) before continuing.

#### Session 2 — 2026-04-30 — BUILD — COMPLETED

- **Scope**: Resume PARTIALLY_COMPLETED FLOW upgrade. Closed KI-1..KI-4 by shipping the missing BE Summary query + 9 FE FLOW components + 5 wiring fixes + 2 deletes + DB seed. Parallel Opus BE + Opus FE per FLOW+complexity=High model selection table; BA/SR/UX agent spawns SKIPPED per Family #20 precedent (prompt §①–⑫ deep — original Session 0 approval stands).
- **Files touched**:
  - **BE created (3)**:
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/DonationSchemas/GlobalDonationSummarySchemas.cs` (created) — `GlobalDonationSummaryDto` 10 fields per spec §⑩.
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/GlobalDonations/Queries/GetGlobalDonationSummary.cs` (created) — Mediator query + handler. Tenant-scoped via `IHttpContextAccessor.GetCurrentUserStaffCompanyId()`. Two `GroupBy + Select` round-trips (this-month aggregate, pending aggregate) plus one `SumAsync` for last-month total. Cross-currency totals normalized via `BaseCurrencyAmount`.
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/GlobalDonation-sqlscripts.sql` (created) — Idempotent FLOW seed: Menu-guard (against pre-seeded global menu in `Pss2.0_Old_Menu_List.sql:9`), 8 MenuCapabilities, 7 BUSINESSADMIN RoleCapabilities, FLOW Grid `'GLOBALDONATION'` (`GridFormSchema=NULL`), 10 Fields, 10 GridFields (1 hidden PK + 9 visible columns). `sql-scripts-dyanmic/` typo preserved per ChequeDonation #6 ISSUE-15 precedent.
  - **BE modified (1)**:
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Donation/Queries/GlobalDonationQueries.cs` (modified) — Appended `GetGlobalDonationSummary` GQL endpoint (no args; mirrors `ChequeDonationSummary` shape; returns `BaseApiResponse<GlobalDonationSummaryDto>`).
  - **FE created (9)**:
    - `PSS_2.0_Frontend/src/domain/entities/donation-service/GlobalDonationSummaryDto.ts` (created) — TS DTO mirrors BE shape.
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/donation-queries/GlobalDonationSummaryQuery.ts` (created) — `GLOBALDONATION_SUMMARY_QUERY` GraphQL doc.
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/index.tsx` (created) — URL-mode dispatcher (default + named export `GlobalDonationIndex`). Reads `?mode=*&id=*` and dispatches: no params → `<GlobalDonationIndexPage>`, `mode=new|edit` → `<GlobalDonationForm>`, `mode=read` → `<GlobalDonationViewPage>`. Forces fresh form mount when switching records via `key={crudMode}-${recordId}`.
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/view-page.tsx` (created) — Read-mode 2-column detail layout (9 cards) + delete confirm + receipt modal mount.
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/donation-form.tsx` (created) — New/edit form with 6 accordion sections, mode card-selector (NOT dropdown), conditional payment sub-form summaries, delivery card-selector, computed BaseAmount/NetAmount, RHF + Zod, unsaved-changes dialog. Form fidelity per §⑫.
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/globaldonation-store.ts` (created) — Zustand store: `refreshToken` cross-component bump + `receiptModal*` open/close.
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/donation-summary.tsx` (created) — 5 KPI tiles (Total / Count / Recurring / Online-vs-Offline split-bar / Pending). 4 standard tone tiles + 1 visually distinct split-bar tile.
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/distribution-grid.tsx` (created) — Editable + readonly distribution rows, allocation status bar, ApiSelect for purpose / participant role / occasion.
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/receipt-modal.tsx` (created) — SERVICE_PLACEHOLDER receipt preview (Download/Print toast "Coming soon").
  - **FE modified (5)**:
    - `PSS_2.0_Frontend/src/domain/entities/donation-service/index.ts` (modified) — Added `export * from "./GlobalDonationSummaryDto";`.
    - `PSS_2.0_Frontend/src/infrastructure/gql-queries/donation-queries/index.ts` (modified) — Added `export * from "./GlobalDonationSummaryQuery";`.
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/index-page.tsx` (modified) — `gridCode="DONATION"` → `"GLOBALDONATION"` (closes KI-4); injected `<GlobalDonationSummary />` between `<ScreenHeader>` and `<FlowDataTableContainer showHeader={false} />`; mounted `<ReceiptModal />` for Zustand-driven receipt preview.
    - `PSS_2.0_Frontend/src/presentation/pages/crm/donation/globaldonation.tsx` (modified) — Imports default `GlobalDonationIndex` from the page-components folder (resolves to `index.tsx` dispatcher); `menuCode: "DONATION"` → `"GLOBALDONATION"` (closes KI-2 + KI-4); renders `<GlobalDonationIndex />`.
    - `PSS_2.0_Frontend/src/application/configs/data-table-configs/donation-service-entity-operations.ts` (modified) — `gridCode: "DONATION"` (line ~153) → `"GLOBALDONATION"` (closes KI-4 last site).
  - **FE deleted (2)**:
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/data-table.tsx` (deleted) — legacy `GlobalDonationDataTable` (AdvancedDataTable wrapper), replaced by FLOW dispatcher.
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/index.ts` (deleted) — legacy barrel that only re-exported the legacy `GlobalDonationDataTable`. Removed to avoid the prompt's flagged `index.ts ↔ index.tsx` self-import; matches the chequedonation FLOW pattern (page-config default-imports the dispatcher folder, TS resolves to `index.tsx`).
  - **DB seed**: see "BE created (3)" above — `GlobalDonation-sqlscripts.sql`.
- **Build verification**:
  - **Backend**: `Base.Application` direct build → 0 errors / 0 warnings / 2.30s. Full-sln build hit 8 errors — all `MSB3026` / `MSB3027` / `MSB3021` file-lock errors from `Base.API/bin` (Visual Studio Insiders running the API process locks DLLs during copy step). **Zero CS compile errors** anywhere. Code is correct; build artifacts couldn't fully publish only because dev server is running. Per build directive memory ("avoid full builds unless necessary"), the targeted `Base.Application` build is the binding signal.
  - **Frontend**: `npx tsc --noEmit` from `PSS_2.0_Frontend/` → exit 0, zero output (clean pass).
- **Renderer keys (Component Reuse-or-Create check)**:
  - **Reused** (in BE seed `GridFields.GridComponentName`): `text-bold`, `DateOnlyPreview`, `donor-link`, `text-truncate`, `currency-amount`, `status-badge`. All registered in FE `data-tables/*/data-table-column-types/component-column.tsx` via prior siblings (ChequeDonation #6, etc.).
  - **Created**: NONE — no new renderers added this session.
  - **Flagged**: NONE — no missing/complex renderers.
  - **Display atoms inlined** (NOT registered renderers, scoped to view-page/form): `PaymentStatusBadge`, `CardShell`, `FieldRow`, `DonorMiniCard`, `ModeCardSelector`, `PaymentSubForm`, `ComputedReadonlyField`, `AllocationStatusBar`, `KpiTile`, `OnlineOfflineTile`, `ReceiptField` — all simple-static, no API calls, no cross-screen reuse.
- **Variant B compliance**: VERIFIED. `index-page.tsx` imports `ScreenHeader` from `@/presentation/components/custom-components/page-header` AND uses `<FlowDataTableContainer showHeader={false} />`. Layout Variant = `widgets-above-grid` (5 KPI summary widgets injected between header and grid).
- **UI uniformity** (5 grep checks per `frontend-developer.md` § "UI Uniformity & Polish"):
  - Inline hex (`style=\{\{[^}]*#[0-9a-fA-F]{3,6}`): not exhaustively rerun this session — agent reported Tailwind tokens used throughout new files.
  - Inline pixel padding/margins (`style=\{\{[^}]*(padding|margin):\s*\d+`): not exhaustively rerun.
  - Bootstrap card mixed with tailwind: not introduced this session (new files use shadcn `<Card>`).
  - Hand-rolled skeleton hex: not introduced — `<Skeleton>` from shadcn used per memory directive.
  - Raw "Loading..." text: not introduced — Skeletons render during loading.
- **Deviations from spec**:
  - View-page Distribution card renders empty until BE projection extends (KI-7).
  - Distribution child rows are captured but not persisted on save — toast warns user (KI-6). BE child mutation exists but write path is unspec'd; deferred for focused follow-up rather than ship untested code.
  - Donor mini-card minimal placeholder until `CONTACTS_BY_ID_QUERY` lookup added (KI-8).
  - DonationHistoryCard empty-state (KI-9) — separate query needed.
  - Receipt delivery method may bind to wrong MasterDataType (KI-10).
- **Known issues opened**: KI-5, KI-6, KI-7, KI-8, KI-9, KI-10, KI-11, KI-12.
- **Known issues closed**: KI-1, KI-2, KI-3, KI-4 (all original Session 1 issues resolved).
- **Next step**: User-side E2E verification remains:
  1. Apply DB seed: run `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/GlobalDonation-sqlscripts.sql` (idempotent — guards against pre-seeded global menu).
  2. Stop Visual Studio Insiders if running the API, then `dotnet build` from `PeopleServe/` for a clean full-sln build (only required to refresh `Base.API/bin` artifacts; code compiles fine).
  3. `pnpm dev` from `PSS_2.0_Frontend/` and visit `/en/crm/donation/globaldonation`.
  4. **Golden path E2E**: list loads → 5 KPI widgets render → "+ New" navigates to form → fill 6 sections → save → redirects to `?mode=read&id=X` → detail page renders 2-column layout → "Edit" returns to form pre-filled → "Back" returns to list. Note KI-6: distribution rows captured but parent-only persistence in MVP — toast confirms.

#### Session 3 — 2026-05-02 — ENHANCE — SUPERSEDED (Session 4)

> **⚠ SUPERSEDED**: After this session shipped, the user requested generalizing the design so that future entities (ReceiptBook, Contact, etc.) can share the number-generation infrastructure rather than each spawning its own bespoke table. Session 3's entire BE delta was **reverted by the user before Session 4 started**. The Session 3 entry is preserved below as audit history; the live architecture is the generic 2-table design from Session 4.

- **Scope**: Implemented Section ⑮ pre-planned **Receipt Number Auto-Generation** feature (Option A settings model, BE only per ⑮.5). New `sett.ReceiptNumberConfigs` 1-row-per-tenant entity + bootstrap-on-first-call generator helper + wired into Create handlers + EF migration with partial unique index on `fund.GlobalDonations(CompanyId, ReceiptNumber)`. NO FE changes (form already passes through BE-generated value via response). User-confirmed decisions: Option A schema; BE-only scope; no settings-management UI this session.
- **Files touched**:
  - **BE created (4)**:
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/ReceiptNumberConfig.cs` — entity per ⑮.2 Option A (Prefix / Pattern / SequenceResetPolicy / LastSequence / LastResetPeriodKey / IsEnabled + audit fields).
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/SettingConfigurations/ReceiptNumberConfigConfiguration.cs` — EF config: explicit `sett.ReceiptNumberConfigs` table, FK to `app.Companies`, unique index on `CompanyId`, server-side defaults for `Prefix='RCPT'` / `Pattern='{PREFIX}-{YYYY}-{SEQ:000000}'` / `SequenceResetPolicy='YEARLY'` / `LastSequence=0` / `IsEnabled=true`.
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/GlobalDonations/Services/GlobalDonationReceiptNumberer.cs` — `public static async Task<string?> GenerateAsync(IApplicationDbContext db, int companyId, string modeCode, DateTime donationDate, CancellationToken ct)`. Algorithm per ⑮.3: RECEIPTBOOK short-circuit → null; bootstrap missing config row idempotently; skip if `IsEnabled=false`; period key per `SequenceResetPolicy` (NEVER/YEARLY/FY/MONTHLY); FY derived from `CompanyConfiguration.FinancialYearStartMonth.DataValue` with YEARLY fallback; advisory-lock + counter increment + period rollover; template render with tokens `{PREFIX} {YYYY} {YY} {MM} {DD} {FY} {COMPANYID} {SEQ:N}`; uniqueness retry up to 3 times. Side-effect-only on tracked entity — no `SaveChangesAsync` so outer `BeginTransactionAsync` commits atomically with parent insert.
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Migrations/20260502040318_Add_ReceiptNumberConfig_And_GlobalDonation_ReceiptNumber_UniqueIndex.cs` (+ `.Designer.cs`) — migration creates `sett.ReceiptNumberConfigs` + adds partial unique index `IX_GlobalDonations_CompanyId_ReceiptNumber UNIQUE (CompanyId, ReceiptNumber) WHERE ReceiptNumber IS NOT NULL AND IsDeleted = false` via `migrationBuilder.Sql`.
  - **BE modified (7)**:
    - `Base.Application/Data/Persistence/ISettingDbContext.cs` — added `DbSet<ReceiptNumberConfig> ReceiptNumberConfigs { get; }`.
    - `Base.Infrastructure/Data/Persistence/SettingDbContext.cs` — added `public DbSet<ReceiptNumberConfig> ReceiptNumberConfigs => Set<ReceiptNumberConfig>();`.
    - `Base.Application/Extensions/DecoratorProperties.cs` — added `, ReceiptNumberConfig = "RECEIPTNUMBERCONFIG"` to `DecoratorSettingModules`.
    - `Base.Application/Business/DonationBusiness/GlobalDonations/Commands/CreateGlobalDonationWithChildren.cs` — `GenerateAsync` invoked inside `strategy.ExecuteAsync` block, BEFORE `dbContext.GlobalDonations.Add(gd)` (around line 217). Existing RECEIPTBOOK serial-mirroring path stays.
    - `Base.Application/Business/DonationBusiness/GlobalDonations/Commands/CreateGlobalDonation.cs` — added `MasterData.DataValue` mode lookup; `GenerateAsync` invoked BEFORE `Add(globalDonation)`.
    - `Base.Application/Business/DonationBusiness/ChequeDonations/Commands/CreateChequeDonation.cs` — `GenerateAsync` called with `modeCode = "CHQ"` inside `if (req.GlobalDonationId <= 0)` inline-create block; result assigned to `gd.ReceiptNumber` and surfaced on response DTO (see KI-15 for mode-code constant audit).
    - `Base.Application/Business/DonationBusiness/GlobalReceiptDonations/Commands/CreateGlobalReceiptDonation.cs` + `GlobalOnlineDonations/Commands/CreateGlobalOnlineDonation.cs` — comment-only (KI-14 / KI-16 explain why no active wire is needed).
- **Build verification**:
  - `Base.Application` targeted build: **0 errors / 0 warnings** (binding signal per build directive memory).
  - Full `PeopleServe.sln` build: **0 errors / 1 warning** (pre-existing NPOI EULA warning, unrelated). NOTE: full-sln cleanly built this session unlike Session 2 where `Base.API/bin` MSB30xx file-locks blocked publish — VS Insiders not running this session.
- **Renderer keys (Component Reuse-or-Create check)**: N/A — BE-only session, no FE renderers touched.
- **Variant B compliance**: N/A — no FE changes.
- **UI uniformity**: N/A — no FE changes.
- **Deviations from spec**:
  - Advisory lock (`pg_advisory_xact_lock`) substituted for spec's `SELECT ... FOR UPDATE` row-lock (KI-13). `FromSqlInterpolated` not available to Application layer; advisory-lock path is equivalent and works even pre-bootstrap.
  - `CreateGlobalOnlineDonation` is comment-only — has no inline parent-create path to wire (KI-14). Composite handler covers actual OD creation flow.
  - `CreateGlobalReceiptDonation` is comment-only — RECEIPTBOOK mode short-circuits to `null` so the call would be a no-op (KI-16). Existing serial-mirror logic preserved.
  - Cheque mode constant passed as `"CHQ"` — pending audit against final `PAYMENTMODE` MasterData seed (KI-15). No functional impact today since helper only special-cases `"RECEIPTBOOK"`.
- **Known issues opened**: KI-13, KI-14, KI-15, KI-16.
- **Known issues closed**: None this session (Section ⑮ acceptance checklist items are now all met — see ⑮.6).
- **Next step**: User-side verification:
  1. **Apply migration** — `dotnet ef database update` (the team-owned step — migration files are committed). The migration is non-blocking since the partial unique index excludes existing NULL `ReceiptNumber` rows.
  2. **Smoke E2E** per ⑮.6 final checklist item: create one donation per mode (CASH, CHEQUEDD, OD, BANKTRANSFER, DIK, RECEIPTBOOK). First five should auto-generate `RCPT-2026-000001` style numbers; RECEIPTBOOK should retain its book serial.
  3. Verify `sett.ReceiptNumberConfigs` row was bootstrapped on first donation create for the tenant (single row, defaults).
  4. (Optional) Audit cheque mode constant per KI-15 against the actual seed.
- **Notes**:
  - All 9 acceptance checklist items in ⑮.6 are met (see Tasks below — added `[x]` markers).
  - Pre-existing 8 OPEN KIs (KI-5..KI-12) remain intentionally deferred, untouched this session.
  - Registry hygiene: `REGISTRY.md` has a stale duplicate row for screen #1 at line 447 (status `PARTIALLY_COMPLETED`). The authoritative row at line 85 is correct (`COMPLETED`). Worth a follow-up cleanup pass — not modified this session to keep `/continue-screen` scope tight.

#### Session 4 — 2026-05-02 — ENHANCE — COMPLETED

- **Scope**: **Architectural redesign** of the Receipt Number feature into a **generic, globally reusable NumberSequence system** that any business entity (donations today; ReceiptBook, Contact, etc. tomorrow) can plug into. User reverted Session 3's bespoke `sett.ReceiptNumberConfigs` schema and asked for a model where the generator is entity-agnostic. New 2-table design: a global eligibility catalog (`sett.NumberSequenceEntityTypes`) FK'd to existing `public.EntityTypes`, plus a per-tenant override table (`sett.NumberSequenceConfigs`) with one row per `(CompanyId, NumberSequenceEntityTypeId)`. Tenant overrides inherit from defaults via NULL-coalesce. Initial seed scopes only `GLOBALDONATION` (per user choice — Option A: ship only what's wired today; ReceiptBook/Contact rows added when their consuming features land).
- **Files touched**:
  - **BE created (5)**:
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/NumberSequenceEntityType.cs` — eligibility entity. FK to `public.EntityTypes` (UNIQUE — one row per eligible entity globally). Holds `DefaultPrefix / DefaultSuffix / DefaultPattern / DefaultSequenceResetPolicy / IsEnabled` + audit. Added `Suffix` support (new `{SUFFIX}` token in renderer).
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SettingModels/NumberSequenceConfig.cs` — per-tenant override entity. FKs to `app.Companies` + `sett.NumberSequenceEntityTypes`. All format columns nullable (NULL = inherit defaults). Counter columns: `LastSequence`, `LastResetPeriodKey`. Per-tenant `IsEnabled` kill-switch.
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/SettingConfigurations/NumberSequenceEntityTypeConfiguration.cs` — EF fluent config: identity column, server-side defaults (`Prefix='RCPT'`, `Pattern='{PREFIX}-{YYYY}-{SEQ:000000}'`, `SequenceResetPolicy='YEARLY'`, `IsEnabled=true`), unique index on `EntityTypeId`, `OnDelete(Restrict)` to `public.EntityTypes`.
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/SettingConfigurations/NumberSequenceConfigConfiguration.cs` — EF fluent config: nullable override columns, `LastSequence` default 0, `IsEnabled` default true, indexes for FK navigation, `OnDelete(Restrict)` on both FKs. The partial unique index `UX_NumberSequenceConfigs_Company_Kind_NotDeleted` is added in the migration via `migrationBuilder.Sql()` because EF Core fluent API doesn't support partial indexes natively.
    - `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Services/NumberSequence/NumberSequenceGenerator.cs` — generic `public static Task<string?> GenerateAsync(IApplicationDbContext db, int companyId, string entityTypeCode, DateTime contextDate, CancellationToken ct)`. Algorithm: (1) resolve eligibility row by `EntityTypes.EntityTypeCode` join — throws `InvalidOperationException` if not registered (loud failure, not silent skip); (2) global kill-switch returns null; (3) per-(entityType, company) advisory lock via `pg_advisory_xact_lock` — different entities and tenants never block each other (lock-key formula `((long)0x4E554D53L << 24) ^ ((long)numberSequenceEntityTypeId << 24) ^ (long)companyId`); (4) load-or-bootstrap tenant config row (one `SaveChangesAsync` during bootstrap only, advisory lock makes it race-free); (5) per-tenant kill-switch; (6) effective-value resolution via `config.Field ?? eligibility.DefaultField`; (7) period-key computation (NEVER/YEARLY/FY/MONTHLY) — FY scoped to caller's `companyId` (see KI-17); (8) increment counter with rollover detection; (9) render pattern with `{PREFIX} {SUFFIX} {YYYY} {YY} {MM} {DD} {FY} {COMPANYID} {SEQ:N}`. Counter update is left tracked-but-unflushed so the caller's outer transaction commits the sequence increment + parent insert atomically. **`RECEIPTBOOK` short-circuit moved OUT of the helper INTO callers** — donation-mode logic is not the generic helper's concern.
  - **BE modified (6)**:
    - `Base.Application/Data/Persistence/ISettingDbContext.cs` — added `DbSet<NumberSequenceEntityType> NumberSequenceEntityTypes { get; }` and `DbSet<NumberSequenceConfig> NumberSequenceConfigs { get; }`.
    - `Base.Infrastructure/Data/Persistence/SettingDbContext.cs` — implemented both DbSets with `=> Set<...>()`.
    - `Base.Application/Extensions/DecoratorProperties.cs` — added `, NumberSequenceEntityType = "NUMBERSEQUENCEENTITYTYPE", NumberSequenceConfig = "NUMBERSEQUENCECONFIG"` to `DecoratorSettingModules`.
    - `Base.Application/Business/DonationBusiness/GlobalDonations/Commands/CreateGlobalDonation.cs` — added `MasterData.DataValue` mode lookup (line 56–60); wrapped existing `Add` in `strategy.ExecuteAsync` + `BeginTransactionAsync` (line 70–86) so `pg_advisory_xact_lock` has a transaction to attach to; injected RECEIPTBOOK skip + `NumberSequenceGenerator.GenerateAsync(_, companyId, "GLOBALDONATION", DonationDate, ct)` BEFORE `Add(globalDonation)` (line 75–82).
    - `Base.Application/Business/DonationBusiness/GlobalDonations/Commands/CreateGlobalDonationWithChildren.cs` — composite handler already wraps in `strategy.ExecuteAsync` + `BeginTransactionAsync`; injected RECEIPTBOOK skip + `NumberSequenceGenerator.GenerateAsync(_, gd.CompanyId, "GLOBALDONATION", gd.DonationDate, ct)` BEFORE `dbContext.GlobalDonations.Add(gd)` (line 200–207).
    - `Base.Application/Business/DonationBusiness/ChequeDonations/Commands/CreateChequeDonation.cs` — wrapped the `if (req.GlobalDonationId <= 0)` inline-parent-create branch in a new `strategy.ExecuteAsync` + `BeginTransactionAsync` (line 187–190); injected RECEIPTBOOK skip + generator call inside that branch.
  - **BE migration (1)**: `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Migrations/20260502044341_Add_NumberSequence_Generic_Tables_And_GlobalDonation_Receipt_UniqueIndex.cs` (+ Designer + ModelSnapshot deltas). Operations:
    1. `CreateTable("NumberSequenceEntityTypes", schema: "sett")` with FK to `public.EntityTypes`.
    2. `CreateTable("NumberSequenceConfigs", schema: "sett")` with FKs to `app.Companies` + `sett.NumberSequenceEntityTypes`.
    3. EF auto-generated indexes: `IX_NumberSequenceConfigs_CompanyId_NumberSequenceEntityTypeId` (non-unique), `IX_NumberSequenceConfigs_NumberSequenceEntityTypeId`, `IX_NumberSequenceEntityTypes_EntityTypeId` (unique).
    4. Raw SQL: `CREATE UNIQUE INDEX UX_NumberSequenceConfigs_Company_Kind_NotDeleted ON sett."NumberSequenceConfigs" (CompanyId, NumberSequenceEntityTypeId) WHERE IsDeleted = false`.
    5. Idempotent UPSERT into `public.EntityTypes` for `EntityTypeCode='GLOBALDONATION'` — uses `ON CONFLICT ON CONSTRAINT "IX_EntityTypes_EntityTypeCode_IsActive" DO NOTHING` so it's safe whether the row pre-exists.
    6. Idempotent INSERT-SELECT into `sett.NumberSequenceEntityTypes` seeding the `GLOBALDONATION` eligibility row (defaults: `'RCPT'` / `'{PREFIX}-{YYYY}-{SEQ:000000}'` / `'YEARLY'` / enabled). Wrapped in `WHERE NOT EXISTS` for re-run safety.
    7. Raw SQL: `CREATE UNIQUE INDEX IF NOT EXISTS UX_GlobalDonations_Company_ReceiptNumber_NotNull ON fund."GlobalDonations" (CompanyId, ReceiptNumber) WHERE ReceiptNumber IS NOT NULL` (recreates the partial unique index that the reverted Session 3 migration also added).
    Down migration is fully symmetric except it preserves the `public.EntityTypes` GLOBALDONATION row (other features may reference it via `SearchableEntities`).
- **Build verification**:
  - `Base.Application` direct build: **0 errors / 0 warnings** (binding signal). After the KI-17 fix → re-verified 0/0.
  - `Base.Infrastructure` direct build: **0 errors / 1 pre-existing warning** (NPOI EULA, unrelated). Solution-wide build: 0 errors, 373 pre-existing warnings (none in our created/edited files). Per build directive memory ("avoid full builds unless necessary"), targeted project builds are the binding signal.
- **Renderer keys (Component Reuse-or-Create check)**: N/A — BE-only session, no FE renderers touched.
- **Variant B compliance**: N/A — no FE changes.
- **UI uniformity**: N/A — no FE changes.
- **Deviations from spec (Session 4 brief)**:
  - **Transaction wrapping added to two handlers** that previously had no explicit transaction. `CreateGlobalDonation` and `CreateChequeDonation` did not wrap their `Add + SaveChanges` in `strategy.ExecuteAsync + BeginTransactionAsync`. The advisory lock requires an open transaction (`pg_advisory_xact_lock` is transaction-scoped). I wrapped both — minimal-surface change, mirrors the composite handler's pattern. Documented as part of this session's intentional broadening.
  - **Multi-tenant FY-key regression (caught + fixed inside this session)** — see KI-17. The first-pass agent output dropped the `WHERE CompanyId = companyId` filter from `BuildFyKey`. Caught during review, fixed, build re-verified.
  - **Synchronous DB read inside async helper** — `BuildFyKey` does a sync EF lookup to keep `ComputePeriodKey` non-async. See KI-18 for trade-off.
  - **Two indexes on the same column pair** — EF auto-generated a non-unique index alongside the manually-added partial unique index. See KI-19. Functionally redundant but not harmful.
  - **`RECEIPTBOOK` short-circuit moved into callers** — by design (generic helper has no donation-mode awareness).
- **Architecture decisions (durable — write into ⑮ for future readers)**:
  - **Eligibility table over flag-on-EntityTypes**: A `SupportsNumberSequence` boolean on `public.EntityTypes` would have polluted a generic registry shared with search/audit. Dedicated eligibility table keeps EntityTypes clean and makes the admin UI's eligibility-list query trivial.
  - **FK from Configs → Eligibility (not Configs → EntityTypes directly)**: The Configs table can ONLY reference an entity that's been explicitly registered for numbering. No rogue config rows for arbitrary entities. Eligibility is enforced at the database, not the application.
  - **Override-via-NULL-coalesce, not full-row-copy**: When a tenant configures a sequence, only the override columns they actually changed get filled. Defaults are read from the eligibility row at generation time. Means changing the global default (e.g., updating `DefaultPattern` for `GLOBALDONATION`) automatically applies to all tenants who haven't overridden the pattern column.
  - **Loud failure on missing eligibility**: `GenerateAsync` throws if `entityTypeCode` isn't registered, rather than silently returning null. A typoed entity-type code is a programmer bug, not a runtime "no number please" signal.
  - **Lock key mixes entity + company**: `pg_advisory_xact_lock` key derives from both `numberSequenceEntityTypeId` and `companyId`, so contention is scoped tightly — donations of company A do NOT serialize with contacts of company A, nor with donations of company B.
- **Known issues opened**: KI-17 (closed same session), KI-18, KI-19.
- **Known issues closed**: KI-17 (multi-tenant FY-key regression — caught + fixed within Session 4).
- **Known issues superseded**: KI-13 (advisory lock substitution — preserved in new design), KI-14 (CreateGlobalOnlineDonation comment-only — behavior unchanged), KI-15 (cheque mode constant — moot since RECEIPTBOOK is the only special-cased value), KI-16 (CreateGlobalReceiptDonation comment-only — behavior unchanged).
- **Next step**: User-side verification (unchanged from Session 3, just retargeted at the new schema):
  1. **Apply migration** — `dotnet ef database update` (team-owned step). Migration is idempotent for the seed/upsert blocks.
  2. **Smoke E2E**: create one donation per mode (CASH, CHEQUEDD, OD, BANKTRANSFER, DIK, RECEIPTBOOK). First five should auto-generate `RCPT-2026-000001`-style numbers (eligibility row's defaults); RECEIPTBOOK should retain its book serial (caller-side short-circuit).
  3. Verify a `sett.NumberSequenceConfigs` row gets bootstrapped on first donation create per tenant (one row, all override columns NULL, `LastSequence=1`, `LastResetPeriodKey='2026'`).
  4. Verify `public.EntityTypes` has a `GLOBALDONATION` row (either pre-existing or seeded by this migration).
  5. (Future) When ReceiptBook auto-numbering is wired: add a row to `public.EntityTypes` for `RECEIPTBOOK` (if not present) + a row to `sett.NumberSequenceEntityTypes` with desired defaults (e.g., `'BOOK'` / `'{PREFIX}-{YYYY}-{SEQ:0000}'` / `'YEARLY'`) — no helper code changes required.

---

## ⑮ Receipt Number Auto-Generation — IMPLEMENTED (Session 4 architecture)

> **Status (2026-05-02 post-Session-4)**: ✅ **Implemented as a generic 2-table NumberSequence system** that any business entity can plug into. Live architecture details are in §⑮.0 below; the original Session 3 single-table plan (§⑮.1–⑮.5) is preserved as historical reference but **does not match the shipped code** — Session 3 was reverted by the user and replaced. The Session 4 architecture is the source of truth.
>
> **Goal (unchanged)**: When a GlobalDonation is created in any mode *except* RECEIPTBOOK, the BE auto-generates a unique, human-readable receipt number using a tenant-configurable pattern (prefix + sequence + optional date/year/suffix tokens). RECEIPTBOOK donations continue to derive their receipt number from the physical book serial (`ReceiptBookSerialNo`) — that path is preserved.

### ⑮.0 Live architecture (Session 4) — generic NumberSequence

Two tables under schema `sett`, both FK'd into existing `public.EntityTypes` so the generator is entity-agnostic:

```
sett.NumberSequenceEntityTypes  (global eligibility catalog + defaults — one row per kind)
  NumberSequenceEntityTypeId    PK
  EntityTypeId                  FK → public.EntityTypes (UNIQUE)
  DefaultPrefix                 varchar(20)   default 'RCPT'
  DefaultSuffix                 varchar(20)   nullable
  DefaultPattern                varchar(100)  default '{PREFIX}-{YYYY}-{SEQ:000000}'
  DefaultSequenceResetPolicy    varchar(20)   default 'YEARLY'
  IsEnabled                     bool          default true
  + standard audit columns

sett.NumberSequenceConfigs      (per-tenant override + counter — one row per (CompanyId, kind))
  NumberSequenceConfigId        PK
  CompanyId                     FK → app.Companies
  NumberSequenceEntityTypeId    FK → sett.NumberSequenceEntityTypes
  Prefix, Suffix, Pattern, SequenceResetPolicy   nullable (NULL = inherit defaults)
  LastSequence                  int           default 0
  LastResetPeriodKey            varchar(20)   nullable
  IsEnabled                     bool          default true   (per-tenant kill-switch)
  + standard audit columns
  Partial UNIQUE (CompanyId, NumberSequenceEntityTypeId) WHERE NOT IsDeleted
```

**Initial seed** (per migration `20260502044341`): only `GLOBALDONATION` is registered as an eligible entity (Option A — "ship only what's wired today"). Adding `RECEIPTBOOK` / `CONTACT` later is a one-row INSERT into `NumberSequenceEntityTypes` plus the consuming feature's caller-side wiring — no helper code changes.

**Helper**: `Base.Application/Services/NumberSequence/NumberSequenceGenerator.cs`

```csharp
public static Task<string?> GenerateAsync(
    IApplicationDbContext db,
    int companyId,
    string entityTypeCode,    // matches public.EntityTypes.EntityTypeCode, e.g. "GLOBALDONATION"
    DateTime contextDate,
    CancellationToken ct);
```

Behavior:
- Throws `InvalidOperationException` if `entityTypeCode` is not in `NumberSequenceEntityTypes` (loud failure on misconfig — programmer bugs surface immediately, not silently).
- Returns `null` if either kill-switch (eligibility-level or tenant-level) is off.
- Acquires `pg_advisory_xact_lock` keyed on `(numberSequenceEntityTypeId, companyId)` so different entities and tenants never block each other.
- Bootstraps a tenant config row idempotently on first call (advisory lock makes it race-free).
- Effective values resolve via `config.Field ?? eligibility.DefaultField` — global default changes automatically reach tenants who never overrode.
- Tokens supported: `{PREFIX} {SUFFIX} {YYYY} {YY} {MM} {DD} {FY} {COMPANYID} {SEQ:N}`.
- Counter increment is left tracked-but-unflushed; the caller's outer transaction commits it atomically with the parent insert.

**Caller wiring** — RECEIPTBOOK short-circuit lives in callers, not the helper:
- `CreateGlobalDonationWithChildren.cs:200` (composite path)
- `CreateGlobalDonation.cs:75` (standalone path)
- `CreateChequeDonation.cs:187` (inline-parent-create branch)

**Why this design** (durable rationale — see Session 4 entry for full discussion):
- Eligibility table over flag-on-EntityTypes — keeps the generic `public.EntityTypes` registry clean.
- FK Configs → Eligibility — eligibility enforced at the database, not the application.
- Override-via-NULL-coalesce — global default changes propagate to non-overriding tenants automatically.
- Loud failure on missing eligibility — typo'd codes are programmer bugs, not silent runtime no-ops.

---

### ⑮ HISTORICAL — original Session 3 plan (single-table, RECEIPT-only)

> The sections below were the carry-over plan written between Session 2 and Session 3. Session 3 implemented this design, the user reverted it, and Session 4 replaced it with the generic system above. The text is preserved for audit. **DO NOT use it as a coding guide.**

### ⑮.1 Current state (verified 2026-05-02)

- **Entity**: `fund.GlobalDonations.ReceiptNumber` — `string`, max 100, **nullable** today. The prompt line 90 already declares it "Auto-generated receipt code"; line 148 already declares the uniqueness rule per Company. Both are aspirational — neither is enforced anywhere in code.
- **FE submit** (`donation-form.tsx:1847`): `receiptNumber: loaded?.receiptNumber ?? null` — Create always NULL, Edit preserves existing.
- **BE create handler** (`CreateGlobalDonationWithChildren.cs`): no generation step; persists whatever FE sends.
- **BE create handler** (`CreateGlobalDonation.cs` standalone receipt-only path): same — no generation.
- **CompanyConfiguration entity** (`Base.Domain.Models.SettingModels.CompanyConfiguration`): explicit comment at top says "Receipt / Tax fields removed (moved to future 'Receipt & Tax Configuration' screen)" — meaning the receipt prefix/pattern fields **do not exist** in the domain today. They were intentionally deferred.
- **Existing prefix precedent**: `GenerateReceiptBooksHandler` uses a hard-coded `YY + CompanyId + 000001` pattern for receipt-book serial seeds (no settings-driven config). Don't reuse this — it's physical-book inventory, separate concern.

### ⑮.2 Settings model — what to add

A net-new singleton-like entity is the cleanest fit. Two options, with a clear recommendation:

**Option A (RECOMMENDED) — Add a `ReceiptNumberConfig` 1-row-per-company table under schema `sett`:**
```
sett.ReceiptNumberConfigs
  ReceiptNumberConfigId    int PK
  CompanyId                int FK → app.Companies (UNIQUE — one row per tenant)
  Prefix                   varchar(20)   default 'RCPT'      -- e.g. 'RCPT', 'DON', 'GFT'
  Pattern                  varchar(100)  default '{PREFIX}-{YYYY}-{SEQ:000000}'
                                          -- supported tokens:
                                          -- {PREFIX}      → Prefix column
                                          -- {YYYY}/{YY}   → 4- or 2-digit calendar year of donation
                                          -- {MM}/{DD}     → calendar month / day
                                          -- {FY}          → financial-year tag (uses CompanyConfiguration.FinancialYearStartMonth)
                                          -- {SEQ:NNNN}    → zero-padded sequence width = N
                                          -- {COMPANYID}   → tenant id (rarely needed; mostly for multi-co reports)
  SequenceResetPolicy      varchar(20)   default 'YEARLY'    -- NEVER | YEARLY | FY | MONTHLY
  LastSequence             int           default 0           -- monotonic counter (resets per policy)
  LastResetPeriodKey       varchar(20)   nullable            -- e.g. '2026', 'FY2026', '2026-04' — used to detect rollover
  IsEnabled                bool          default true        -- if false, ReceiptNumber stays NULL until issued manually
  + standard audit columns (CreatedDate / ModifiedDate / IsActive / IsDeleted)
```

- **Why a separate table** (not folded back into `CompanyConfiguration`): the entity comment says receipt/tax explicitly belongs in a future "Receipt & Tax Configuration" screen. Keeping it isolated lets that future screen grow without touching the heavyweight CompanyConfiguration row.
- **Bootstrap**: same pattern as `BootstrapReceiptStatusSeedAsync` in `GlobalReceiptDonationInventory.cs` — first call to the generator creates a default row idempotently if missing.

**Option B (lighter, can ship sooner) — reuse two simple columns on `app.Companies`:**
```
ALTER TABLE app."Companies"
  ADD COLUMN "ReceiptPrefix" varchar(20) NULL,
  ADD COLUMN "ReceiptPattern" varchar(100) NULL DEFAULT '{PREFIX}-{YYYY}-{SEQ:000000}';
```
A separate `app.CompanyReceiptCounters` table holds `(CompanyId, PeriodKey, LastSequence)` so the counter is row-locked without contending on the main company row. Adopt this if user wants the smallest possible footprint and is fine deferring the full settings UI. Concurrency story is the same as Option A.

### ⑮.3 Generation algorithm (mode-aware)

Place the helper in the same folder as `GlobalReceiptDonationInventory.cs`:

```
Base.Application/Business/DonationBusiness/GlobalDonations/Services/GlobalDonationReceiptNumberer.cs

public static class GlobalDonationReceiptNumberer
{
    /// Returns a fresh receipt number for the current tenant.
    /// Caller is the Create handler — both standalone (CreateGlobalDonation
    /// / Cheque / Online / DIK) and composite (CreateGlobalDonationWithChildren).
    /// MUST be called inside the same EF unit-of-work + transaction so the
    /// LastSequence row update + GlobalDonation insert commit together.
    public static async Task<string?> GenerateAsync(
        IApplicationDbContext db,
        int companyId,
        string modeCode,                  // CASH | CHEQUEDD | OD | BANKTRANSFER | DIK | RECEIPTBOOK
        DateTime donationDate,
        CancellationToken ct);
}
```

Algorithm:
1. **Mode short-circuit**: if `modeCode == "RECEIPTBOOK"` → return `null`. The caller already wires `receiptNumber = ReceiptBookSerialNo` in the receipt-book branch, so mid-stream auto-gen would clobber it.
2. **Load config** for `companyId` (or bootstrap defaults via the seed pattern).
3. **Skip if disabled**: `IsEnabled == false` → return `null` so the field stays empty until issued via the future "Issue Receipt" action.
4. **Compute period key** based on `SequenceResetPolicy`:
   - `NEVER` → `""`
   - `YEARLY` → `donationDate.Year.ToString()`
   - `FY` → derive financial-year start month from `CompanyConfiguration.FinancialYearStartMonth.DataValue` (already FK-driven), e.g. `FY2026`
   - `MONTHLY` → `donationDate.ToString("yyyy-MM")`
5. **Acquire & increment counter** under row-lock:
   - `SELECT ... FOR UPDATE` (Postgres) on the `ReceiptNumberConfigs` row scoped by `CompanyId`.
   - If `LastResetPeriodKey != periodKey` → reset `LastSequence = 0`, set `LastResetPeriodKey = periodKey`.
   - `LastSequence += 1`. Capture the new value as `seq`.
6. **Render template** by replacing tokens in `Pattern`:
   - `{PREFIX}` → `Prefix`
   - `{YYYY}/{YY}/{MM}/{DD}/{FY}/{COMPANYID}` → date / tenant tokens
   - `{SEQ:N}` → `seq.ToString().PadLeft(N, '0')`
7. **Uniqueness safety net**: enforce a partial unique index `IX_GlobalDonations_CompanyId_ReceiptNumber UNIQUE (CompanyId, ReceiptNumber) WHERE ReceiptNumber IS NOT NULL AND IsDeleted = false`. If the insert ever races to a duplicate (e.g. someone manually crafted a row with a future serial), retry the increment up to 3 times before bubbling a clear error.

**Concurrency notes**:
- The composite handler already wraps the create in `strategy.ExecuteAsync(... BeginTransactionAsync ...)` — the row-lock above must run inside that same transaction, otherwise two parallel saves can both compute the same `seq`.
- Postgres `NpgsqlRetryingExecutionStrategy` is enabled; the helper must NOT call `SaveChanges` before the parent insert — keep it side-effect-only on the tracked entity until the outer commit.

### ⑮.4 Wire-in points (BE)

| File | Change |
|---|---|
| `CreateGlobalDonationWithChildren.cs:144` (mode-branch block) | After resolving `modeCode`, if `req.Donation.ReceiptNumber` is null/empty AND `modeCode != "RECEIPTBOOK"`, call `GlobalDonationReceiptNumberer.GenerateAsync(...)` and assign to `gd.ReceiptNumber` BEFORE `dbContext.GlobalDonations.Add(gd)`. For `RECEIPTBOOK`, the existing logic that mirrors the serial number stays. |
| `CreateGlobalDonation.cs` (standalone) | Same mode-aware call right before `dbContext.GlobalDonations.Add(...)`. Today this handler doesn't even peek at mode code — pass it explicitly via the DTO or look up `MasterData.DataValue` first. |
| `CreateGlobalReceiptDonation.cs` / `CreateChequeDonation.cs` / `CreateGlobalOnlineDonation.cs` (per-child standalone create paths) | These create the parent inline when `globalDonationId == 0`. Apply the same generator at the same place — once the parent's `DonationModeId` and `DonationDate` are known. |
| `UpdateGlobalDonation*` handlers | **No change** — receipt number is allocated at create-time and immutable thereafter. If `loaded.ReceiptNumber` is null AND someone toggles a "Issue Receipt" action later, that'll be a separate transition command (Phase 2). |
| New EF migration | Add the `sett.ReceiptNumberConfigs` table + the partial unique index on `fund.GlobalDonations(CompanyId, ReceiptNumber)`. Backfill: leave existing NULL rows as-is — the unique index is partial (`WHERE ReceiptNumber IS NOT NULL`), so the migration is non-blocking. |

### ⑮.5 Wire-in points (FE)

- `donation-form.tsx:1847` — change `receiptNumber: loaded?.receiptNumber ?? null` (already correct in spirit; no FE change needed).
- After save, the response payload now carries the BE-generated `receiptNumber` — use it to update the FlowDataTable + the receipt modal preview.
- Future enhancement (NOT in scope for the next session): a CompanySettings sub-screen / drawer that lets BUSINESSADMIN edit the prefix + pattern + reset policy, with a live preview of the next 3 receipt numbers.

### ⑮.6 Acceptance checklist (status reflects Session 4 generic implementation)

- [x] ~~New `sett.ReceiptNumberConfigs` table~~ → **`sett.NumberSequenceEntityTypes` + `sett.NumberSequenceConfigs`** EF entities + EF Configurations + DbSets wired. ← Session 3 (reverted) → Session 4 (redesigned generic)
- [x] Bootstrap seed inside `NumberSequenceGenerator.GenerateAsync` so a fresh tenant works without a manual seed step. ← Session 4
- [x] Helper supports tokens: `{PREFIX} {SUFFIX} {YYYY} {YY} {MM} {DD} {FY} {COMPANYID} {SEQ:N}`. ← Session 4 (added `{SUFFIX}` over Session 3's plan)
- [x] Mode-aware: RECEIPTBOOK short-circuit moved into callers (helper is entity-agnostic by design); helper itself returns `null` when global or per-tenant `IsEnabled = false`. ← Session 4
- [x] Period-reset rollover correct for `YEARLY` / `FY` / `MONTHLY` / `NEVER`. ← Session 4 — FY scoped to caller's `companyId` (KI-17 fix).
- [x] Concurrency: advisory-lock (`pg_advisory_xact_lock`) keyed on `(numberSequenceEntityTypeId, companyId)` inside the parent transaction. ← Session 4 — different entities + tenants don't block each other.
- [x] Partial unique index on `fund.GlobalDonations(CompanyId, ReceiptNumber) WHERE ReceiptNumber IS NOT NULL` recreated. ← Session 4 — migration `20260502044341` ships it; `dotnet ef database update` is the team-owned step.
- [x] Wired into both standalone Create handlers and the composite `CreateGlobalDonationWithChildren` handler at the right point in the flow. ← Session 4 — 3 active wires (composite + standalone GD + ChequeDonation inline). `CreateGlobalReceiptDonation` and `CreateGlobalOnlineDonation` remain unwired by design (no inline parent-create branch — composite handler covers actual creation).
- [x] Eligibility-driven extension model — adding ReceiptBook / Contact / etc. requires only a row in `sett.NumberSequenceEntityTypes` + caller-side wiring; no helper code changes. ← Session 4 (new criterion vs Session 3's RECEIPT-only plan).
- [x] Update `dotnet build` clean. ← Session 4 — `Base.Application` 0/0; `Base.Infrastructure` 0/1 pre-existing NPOI warning. FE `tsc --noEmit` not applicable (no FE changes).
- [ ] Manual E2E: create one donation per mode (CASH, CHEQUEDD, OD, BANKTRANSFER, DIK, RECEIPTBOOK) — first five get the templated `RCPT-2026-000001` style, RECEIPTBOOK keeps its book serial. ← User-side verification remains

#### Session 5 — 2026-05-02 — FIX + ENHANCE — COMPLETED

- **Scope**: Two parts.
  1. **FIX** — three bugs in `createGlobalDonationWithChildren` surfaced while testing the cheque flow: (a) `FK_ChequeDonations_MasterDatas_ChequeStatusId` violation on insert, (b) missing ChequeNo uniqueness validation in the composite validator, (c) `NullReferenceException` during response DTO mapping (first on Distributions, then on ChequeDonation).
  2. **ENHANCE** — In-Kind Donation valuation lifecycle: `DonationInKind` carries `IntendedUseId / ValuationStatusId / EstimatedAmount / RealizedAmount / RealizedDate / RealizationNotes`; new `realizeInKindDonation` command transitions PENDING/ESTIMATED → REALIZED; FE form locks DonationAmount/Distribution amounts to read-only when mode=DIK and exposes only `EstimatedAmount` for editing.
- **Files touched**:
  - BE:
    - [DonationInKind.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/DonationInKind.cs) — 6 new columns + 2 nav props
    - [DonationInKindConfiguration.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/DonationConfigurations/DonationInKindConfiguration.cs) — decimal precision + FK config for IntendedUse/ValuationStatus
    - [DonationInKindSchemas.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/DonationSchemas/DonationInKindSchemas.cs) — added `IntendedUseId`/`EstimatedAmount` to RequestDto; 6 fields + 2 nav DTOs to ResponseDto
    - [CreateGlobalDonationWithChildren.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/GlobalDonations/Commands/CreateGlobalDonationWithChildren.cs) — KI-20/KI-21/KI-22 fixes (recChequeStatusId resolution + override; `When(ChequeDonation != null)` validator block with uniqueness rule; scalar projection for Distributions + ChequeDonation; DetachGlobalDonationBackRefs helper; SafeAdapt wrapper); KI-23 DIK auto-fill (resolve VALUATIONSTATUS dictionary, derive `derivedStatusCode` from `EstimatedAmount > 0` / `IntendedUse=INTERNAL_USE` / else PENDING; override gd.DonationAmount/NetAmount/BaseCurrencyAmount; force single distribution row mirroring estimated)
    - [RealizeInKindDonation.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/DonationInKinds/Commands/RealizeInKindDonation.cs) **(new)** — guard PENDING/ESTIMATED → REALIZED; atomically updates DIK + parent GD.DonationAmount + the single distribution
    - [DonationInKindMutations.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Donation/Mutations/DonationInKindMutations.cs) — wired `realizeInKindDonation` GraphQL mutation
  - FE:
    - [DonationInKindDto.ts](PSS_2.0_Frontend/src/domain/entities/donation-service/DonationInKindDto.ts) — 6 new response fields + 2 nav DTOs; 2 new request fields
    - [GlobalDonationCompositeMutation.ts](PSS_2.0_Frontend/src/infrastructure/gql-mutations/donation-mutations/GlobalDonationCompositeMutation.ts) — extended `donationInKind` selection sets in create/update; new `REALIZE_IN_KIND_DONATION_MUTATION`
    - [GlobalDonationQuery.ts](PSS_2.0_Frontend/src/infrastructure/gql-queries/donation-queries/GlobalDonationQuery.ts) — extended by-id query for new DIK fields
    - [donation-form.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/donation-form.tsx) — `dikIntendedUseId` + `dikEstimatedAmount` Zod fields; INTENDED_USE filter + dropdown; reactive auto-fill (estimated → donationAmount); locks DonationAmount when isDikMode; DIK info banner; passes isDikMode to DistributionGrid
    - [distribution-grid.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/distribution-grid.tsx) — `isDikMode` prop hides Add/Remove buttons + locks AllocatedAmount input; auto-filled label hint
    - [globaldonation-store.ts](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/globaldonation-store.ts) — Zustand state for realize modal
    - [realize-modal.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/realize-modal.tsx) **(new)** — RealizedAmount/Date/Notes form; calls REALIZE_IN_KIND_DONATION_MUTATION; bumpRefresh on success
    - [view-page.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/view-page.tsx) — "Realize" action button (visible only for DIK + status PENDING/ESTIMATED); mounted modal; extended DIK card with new fields + colored ValuationStatus chip
  - DB:
    - [DonationInKind-ValuationLifecycle-sqlscripts.sql](PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/DonationInKind-ValuationLifecycle-sqlscripts.sql) **(new)** — INTENDEDUSE (3 rows) + VALUATIONSTATUS (4 rows) idempotent seed
- **Deviations from spec**: None. FE preserved the legacy `dikBillAmount` Zod field (no longer rendered or validated) to avoid breaking serialized form state.
- **Known issues opened**: KI-20 (FIXED same session), KI-21 (FIXED same session), KI-22 (FIXED same session), KI-23 (FIXED same session — DIK lifecycle delivered), KI-24 (OPEN — EF migration deferred due to running API), KI-25 (OPEN — DonationAmount=0 for non-monetary DIK is by design; reporting queries must filter on ValuationStatus).
- **Known issues closed**: KI-20, KI-21, KI-22, KI-23.
- **Next step**: User-side: stop running API, run `dotnet ef migrations add Add_DonationInKind_ValuationLifecycle_Columns` (per KI-24), apply via `dotnet ef database update`, run the new seed SQL, restart API. Then E2E test the DIK create flow (FOR_SALE + 5000 estimated → REALIZE with 4750 → confirm parent DonationAmount updates).

#### Session 6 — 2026-05-02 — FIX — COMPLETED

- **Scope**: Two follow-up fixes after Session 5 testing:
  1. **DIK currency lock** — donor's currency is meaningless for in-kind donations (org keeps the item, sells/uses it in base currency), so on the donation form `currencyId` is now disabled and force-set to the company base currency whenever mode=DIK.
  2. **DateTime UTC normalisation** — Postgres `timestamp with time zone` rejected `Kind=Unspecified` values from JSON-deserialised payloads (`Cannot write DateTime with Kind=Unspecified ...`). Fixed globally at the `AuditableEntityInterceptor` level so every Add/Modify pass coerces all DateTime/DateTime? scalar properties to UTC kind before EF persists them.
- **Files touched**:
  - BE:
    - [AuditableEntityInterceptor.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Interceptors/AuditableEntityInterceptor.cs) — added `NormalizeDateTimesToUtc()` method called from both `SavingChanges` and `SavingChangesAsync`. Policy: Utc kept, Local → ToUniversalTime, Unspecified → SpecifyKind(Utc).
  - FE:
    - [donation-form.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/donation-form.tsx) — `lock.currencyId` includes `isDikMode`; new effect mirrors `sessionBaseCurrencyId` into the form's `currencyId` field whenever DIK mode is selected and base currency is hydrated.
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: None (these were follow-ups, not registered KIs).
- **Next step**: Pending Session 5 user-side actions (KI-24 migration + seed). Once those are applied + API restarted, retest cheque create (UTC fix) and DIK create with currency observed locked at base currency.

#### Session 7 — 2026-05-02 — ENHANCE — COMPLETED

- **Scope**: KI-26 — Pledge Donation lifecycle wired into the existing GlobalDonation FLOW screen. §⑯'s original spec assumed a new `PledgeDonations` mapping table + `Pledge.GivenAmount/BalanceAmount` + new PLEDGESTATUS rows; verified during this session that this contradicted the live schema (Pledge is the header; PledgePayment is the existing 1:N installment ledger and already has `GlobalDonationId/PaidDate/PaidAmount/PaymentStatusId`). User-confirmed **Path A** — re-use the existing `PledgePayment` row as the fulfillment ledger; **no new entity, no migration, no new MasterData seed**. Strict partial-pay rule chosen: `PaidAmount` per row must equal that row's `DueAmount`. Pledge stays under `DonationType=PLEDGE` (NOT Mode) — Pledge fulfillment can combine with any payment Mode (Cash / Cheque / etc).
- **Files touched**:
  - **BE created (1)**:
    - [PledgeFulfillmentSchemas.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/DonationSchemas/PledgeFulfillmentSchemas.cs) — `PledgeFulfillmentRequestDto { int PledgePaymentId; decimal PaidAmount; }` + `PledgeFulfillmentResponseDto { 16 fields covering fulfillment row + pledge header snapshot }`.
  - **BE modified (4)**:
    - [GlobalDonationCompositeSchemas.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/DonationSchemas/GlobalDonationCompositeSchemas.cs) — added `PledgeFulfillments` list to both `CreateGlobalDonationWithChildrenRequestDto` and `CreateGlobalDonationWithChildrenResponseDto`.
    - [GlobalDonationSchemas.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/DonationSchemas/GlobalDonationSchemas.cs) — added `PledgeFulfillments` to `GlobalDonationDto` (used by `getGlobalDonationById`).
    - [CreateGlobalDonationWithChildren.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/GlobalDonations/Commands/CreateGlobalDonationWithChildren.cs) — Validator: `When(PledgeFulfillments non-empty)` block with per-item rules (PledgePaymentId>0, PaidAmount>0), no-duplicate-PledgePaymentId rule, `MustAsync` batch verification (existence + open status + `PaidAmount == DueAmount` strict + cross-donor guard + tenant scope), and a cross-cutting `Custom` rule that sum of `PaidAmount` equals `Donation.DonationAmount` (±0.01) when fulfillments are present. Handler: inside the existing `strategy.ExecuteAsync` block, AFTER `dbContext.SaveChangesAsync` populates `gd.GlobalDonationId`, BEFORE `transaction.CommitAsync`: re-loads tracked PledgePayment rows, stamps each with `GlobalDonationId / PaidDate (= Donation.DonationDate) / PaidAmount / PaymentStatusId (= MasterData PAID under PLEDGEPAYMENTSTATUS)`, then re-loads each affected Pledge's full schedule and recomputes `PledgeStatusId` (all rows paid → `FULFILLED`; any unpaid past-due → `OVERDUE`; else → `ONTRACK`). Response build: new private static helper `ProjectFulfillmentsAsync` does scalar-only projection from PledgePayments-with-Pledge/Currency/PaymentStatus joins (mirrors Session 5 KI-22 NRE-avoidance pattern).
    - [GetGlobalDonationById.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/GlobalDonations/Queries/GetGlobalDonationById.cs) — after `ApplyEntityQuery` materializes the donation, runs a separate `AsNoTracking` query against `PledgePayments WHERE GlobalDonationId = id AND IsDeleted = false` (with `.Include` on Pledge/Pledge.PledgeStatus/Pledge.Currency/PaymentStatus), projects to `PledgeFulfillmentResponseDto[]` via manual scalar projection, and assigns to the first result's `PledgeFulfillments` property when non-empty. **Deliberate choice**: did NOT add a `PledgePayments` back-nav to the GlobalDonation entity to keep the EF model surface unchanged.
  - **BE not touched**:
    - [UpdateGlobalDonationWithChildren.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/GlobalDonations/Commands/UpdateGlobalDonationWithChildren.cs) — confirmed it does not touch PledgePayments. Edit-mode treats existing fulfillments as immutable audit rows (no add/remove via update). Future support is out of scope per Session 7 contract.
    - GraphQL endpoints — HotChocolate auto-discovers `PledgeFulfillmentRequestDto` / `PledgeFulfillmentResponseDto` via the existing composite mutation/query type registration; no manual GQL type registration needed.
  - **FE created (3)**:
    - [PledgeFulfillmentDto.ts](PSS_2.0_Frontend/src/domain/entities/donation-service/PledgeFulfillmentDto.ts) — TS DTOs mirror BE shapes (request 2 fields, response 16 fields).
    - [OpenPledgeInstallmentsByContactQuery.ts](PSS_2.0_Frontend/src/infrastructure/gql-queries/donation-queries/OpenPledgeInstallmentsByContactQuery.ts) — new GQL query against existing `pledges` resolver with `advancedFilter` (contactId + computedStatusCode IN ONTRACK/OVERDUE/BEHIND), requests `paymentSchedule` nested array. Component flattens client-side to rows where `paidDate == null && globalDonationId == null && isCancelled == false`. **No new BE field requested.**
    - [pledge-fulfillment-grid.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/pledge-fulfillment-grid.tsx) — in-form picker block (≈14kB). Props: `contactId`, `donationAmount`, `value`, `onChange`, `disabled`. Renders shaped `<Skeleton>` while loading; "select donor first" / "no open installments" empty states; shadcn `<Card> + <Table> + <Checkbox>` table with 1 row per OPEN installment showing PledgeCode + InstallmentNumber + DueDate + DueAmount + Currency; selecting a row auto-fills `PaidAmount = DueAmount` (read-only — strict rule); currency-mismatch rows are disabled with tooltip; live "Applied: X / Donation: Y" total chip (green when equal, amber when ≠). Tokens only — no inline hex / no inline px.
  - **FE modified (7)**:
    - [GlobalDonationCompositeMutation.ts](PSS_2.0_Frontend/src/infrastructure/gql-mutations/donation-mutations/GlobalDonationCompositeMutation.ts) — extended CREATE mutation input variables + selection set with `pledgeFulfillments`.
    - [GlobalDonationQuery.ts](PSS_2.0_Frontend/src/infrastructure/gql-queries/donation-queries/GlobalDonationQuery.ts) — added `pledgeFulfillments { ... }` selection to `GLOBALDONATION_BY_ID_QUERY`.
    - [GlobalDonationCompositeDto.ts](PSS_2.0_Frontend/src/domain/entities/donation-service/GlobalDonationCompositeDto.ts) + [GlobalDonationDto.ts](PSS_2.0_Frontend/src/domain/entities/donation-service/GlobalDonationDto.ts) — added `pledgeFulfillments?:` to request/response DTOs.
    - [donation-service/index.ts](PSS_2.0_Frontend/src/domain/entities/donation-service/index.ts) + [donation-queries/index.ts](PSS_2.0_Frontend/src/infrastructure/gql-queries/donation-queries/index.ts) — barrel re-exports.
    - [donation-form.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/donation-form.tsx) — Zod `pledgeFulfillments` field + `superRefine` balance check (sum-of-paid-amounts equals donationAmount); `donationTypeRows` state + effect to resolve type DataValue; `isPledgeMode = donationType.dataValue === "PLEDGE"` computed; `pledgeFulfillments` local state mirrored to RHF; contactId-change reset effect; `<PledgeFulfillmentGrid>` block in Section 2 (after Mode cards), conditional on `isPledgeMode`; `pledgeFulfillmentsPayload` extracted in `onSubmit` and passed to both new + edit composite mutation calls; `pledgeFulfillments` restored on `reset()` for edit-mode (read-only).
    - [view-page.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/view-page.tsx) — new `<PledgeFulfillmentsCard>` mounted in right column under DonorCard; renders only when `donation.pledgeFulfillments?.length > 0`; per-row PledgeCode + InstallmentNumber + DueDate + PaidAmount + status badge; footer total of applied-vs-donation.
- **Build verification**:
  - **Backend**: `Base.Application` direct build → **0 errors / 0 warnings / 4.19s** (binding signal per build directive memory).
  - **Frontend**: `npx tsc --noEmit` from `PSS_2.0_Frontend/` → **exit 0, 0 errors**.
- **Renderer keys (Component Reuse-or-Create check)**:
  - **Reused**: shadcn `<Card>`, `<Table>`, `<Checkbox>`, `<Skeleton>`, `<Badge>` — all already in the registry.
  - **Created**: NONE — no new GridComponentName renderer registered. PledgeFulfillmentGrid is a screen-scoped component, not a registered grid renderer.
- **Variant B compliance**: VERIFIED unchanged — index-page.tsx untouched.
- **UI uniformity** (per directive): no inline hex / no inline px in created/modified files — agent reported clean; manual spot-check confirmed Tailwind tokens throughout.
- **Deviations from spec / scope notes**:
  - **§⑯ design SUPERSEDED by Path A** — see `### ⑯.0 STATUS` note added at top of §⑯. The `PledgeDonations` mapping entity, `Pledge.GivenAmount/BalanceAmount` columns, and `OPEN / PARTIALLY_FULFILLED` PLEDGESTATUS values from the original §⑯ design are **NOT** part of the shipped contract. The shipped contract uses existing `PledgePayment` + existing PLEDGESTATUS values + strict-pay rule. KI-26 description has been rewritten to point at this Session 7 entry as the source of truth.
  - **Currency mismatch handling**: rows with currency ≠ donation currency are shown but disabled with tooltip ("Currency mismatch — switch donation currency or pick a different pledge"). Cross-currency FX conversion is **out of scope this session** per §⑯.11 — single-currency-only in v1.
  - **"Add by next-due" quick action** (§⑯ optional) — NOT implemented this session. Rationale: requires sort/filter pass over loaded installments; can be added as a follow-up if user wants.
  - **Update-mode fulfillments** are read-only audit rows — no add/remove via Update. The Update mutation is NOT extended with `pledgeFulfillments`. Documented decision; deferred to future session if business needs change.
- **Known issues opened (none new)**: see KI-27..KI-29 below if/when surfaced. None opened this session.
- **Known issues closed**: KI-26 — superseded original §⑯ design and shipped Path A.
- **Next step (user-side)**:
  1. **Apply Session 5 prereqs first** (KI-24 — DIK migration + seed); Pledge fulfillment doesn't depend on these but the API needs to start cleanly for E2E.
  2. **Restart API**, then `dotnet build` from `PeopleServe/` for full-sln if you want a clean publish.
  3. `pnpm dev` from `PSS_2.0_Frontend/` and visit `/en/crm/donation/globaldonation`.
  4. **Smoke E2E (Pledge mode)**:
     - Pre-req: a donor (Contact) with at least one Pledge that has open scheduled installments (`PaidDate IS NULL`).
     - Click "+ New" donation. Pick the donor. Set `DonationType = Pledge`. Section 2 should now show the **Pledge Fulfillments** block.
     - Pick one or more open installments. Each selected row's PaidAmount auto-fills to its DueAmount (read-only). The "Applied / Donation" chip should turn green when sums match.
     - Adjust `DonationAmount` to equal sum of selected installments. Pick any payment Mode (Cash, Cheque, etc.). Save.
     - Verify in `view-page` (`?mode=read`): Pledge Fulfillments card renders with the rows you stamped.
     - Verify in DB: stamped `PledgePayment` rows have `GlobalDonationId / PaidDate / PaidAmount / PaymentStatusId = PAID`. Affected `Pledge.PledgeStatusId` recomputed (FULFILLED if all installments now paid, else ONTRACK/OVERDUE).
  5. **Negative tests**:
     - Sum-mismatch (PaidAmount sum ≠ DonationAmount) → form blocks submit with red chip + Zod error.
     - Strict-pay violation (e.g. send modified PaidAmount via DevTools) → BE returns 400 with strict-pay error.
     - Cross-donor pledge selection (manual API call) → BE rejects.
     - Fulfilling already-fulfilled installment (race) → BE rejects with "no longer eligible".
- **Notes**:
  - The 13 OPEN KIs from prior sessions (KI-5/6/7/8/9/10/11/12/13/18/19/24/25) remain unchanged — **none touched this session.**
  - Session 7 follows Session 6 same-day; total session count is now 7 (8 if you count Session 0 BUILD).

#### Session 8 — 2026-05-02 — FIX — COMPLETED

- **Scope**: Hot-fix discovered immediately after Session 7 ship. User reported: "Selected DonationType=Pledge but contact's pledge details not shown." Two root causes:
  1. **`GetPledges` did NOT populate `paymentSchedule` on its DTO** — only `GetPledgeById` did. The Session 7 FE picker fetches via the LIST query (`pledges`), so every pledge came back with `paymentSchedule = null` and the picker rendered the "no open installments" empty state regardless of the donor's actual pledge state.
  2. **FE picker filtered via `advancedFilter` on `contactId` AND `computedStatusCode`** — the latter is a computed DTO field, not an entity column, so the filter was silently broken; even the contactId rule was relying on the generic advancedFilter handler instead of an explicit, type-safe filter.
- **Files touched**:
  - **BE modified (2)**:
    - [GetPledges.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/Pledges/Queries/GetPledges.cs) — added `int? ContactId = null` to `GetPledgesQuery` record; handler applies `Where(p => p.ContactId == request.ContactId.Value)` filter alongside the other explicit filters; new `public static void ProjectPaymentSchedule(dto, src, today)` helper mirrors the per-row projection from `GetPledgeById` (PaymentStatusCode/Name/Color + DaysUntilDue) and populates `dto.PaymentSchedule`. Post-projection loop now calls both `ProjectFields` AND `ProjectPaymentSchedule` for each row. Added a new `private static MapPaymentStatusColor` (mirrors the one in `GetPledgeById` — kept duplicated locally to avoid cross-handler dependency).
    - [PledgeQueries.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Donation/Queries/PledgeQueries.cs) — added `int? contactId = null` arg to the GraphQL `GetPledges` endpoint signature; passed through to `GetPledgesQuery` constructor.
  - **FE modified (2)**:
    - [OpenPledgeInstallmentsByContactQuery.ts](PSS_2.0_Frontend/src/infrastructure/gql-queries/donation-queries/OpenPledgeInstallmentsByContactQuery.ts) — rewritten to use explicit `$contactId: Int` GraphQL variable passed as a top-level arg on `pledges(...)` (alongside `request: { pageSize: 100, pageIndex: 0, ... }`). Dropped the `$advancedFilter: QueryBuilderModelInput` rule construction.
    - [pledge-fulfillment-grid.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/pledge-fulfillment-grid.tsx) — removed the `advancedFilter` `useMemo` block; `useQuery` now passes `variables: { contactId }` directly. The component's existing client-side filter on `paymentSchedule` (`paidDate == null && globalDonationId == null && !isCancelled`) remains the source of truth for "open installments" — pledges with no remaining open rows simply produce zero picker rows.
- **Build verification**:
  - **Backend**: `Base.Application` direct build → **0 errors / 373 pre-existing warnings / 26.96s** (binding signal). The pre-existing warnings are unrelated NPOI / nullability / CA2022 noise across the project — none in our created/edited files.
  - **Frontend**: `npx tsc --noEmit` from `PSS_2.0_Frontend/` → **exit 0, 0 errors**.
- **Renderer keys**: N/A — no FE renderers touched.
- **Variant B compliance**: N/A.
- **UI uniformity**: N/A.
- **Deviations from spec**: None.
- **Known issues opened**: None.
- **Known issues closed**: None (these are post-ship hot-fixes for a regression introduced by Session 7's choice to use the LIST query rather than a dedicated by-contact endpoint — KI-26 stays CLOSED, this just makes the shipped code actually work).
- **Next step (user-side)**:
  1. **Restart API** (if running) so the new `GetPledgesQuery` shape and the `contactId` GraphQL arg take effect.
  2. **Re-run the seed** [`Demo-PledgeFulfillment-sqlscripts.sql`](PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/Demo-PledgeFulfillment-sqlscripts.sql) (if not already applied) — idempotent.
  3. **Refresh the donation form** (no FE rebuild needed — `pnpm dev` HMR will pick up the changes). Pick "Demo Pledge Donor", set DonationType = Pledge — the picker should now load 6 open installments. Selecting them auto-fills `PaidAmount = DueAmount` per row, the "Applied / Donation" chip turns green when sums match, and Save stamps the rows + recomputes pledge status.
- **Notes**:
  - The 13 OPEN KIs from prior sessions remain unchanged — none touched this session.
  - The fix preserves backward compatibility: existing Pledge grid screen #12 (`/crm/donation/pledge`) continues to work unchanged — the new `paymentSchedule` field on the LIST response is additive (was always declared on the DTO; previously just `null`).
  - **2026-05-02 follow-up to Session 8**: User reported the picker still didn't fetch even after the BE fix landed. Discovered a third bug: `isPledgeMode` matched only `dataValue === "PLEDGE"`, but the tenant's actual DONATIONTYPE seed uses `dataValue = 'PLEDGEDONATION'` (per user). Hardened the matcher in [donation-form.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/globaldonation/donation-form.tsx#L1923-L1934) to accept `PLEDGEDONATION` / `PLEDGE` / `PLG` (DataValue) and `PLEDGE` / `PLEDGE DONATION` (DataName) — same multi-form pattern used elsewhere in the form for the Recurring exclusion. Without this match, `isPledgeMode` stayed false, the `<PledgeFulfillmentGrid>` never mounted, and no API call was ever issued. tsc still 0 errors after the change. **Lesson for future sessions**: never hardcode a single MasterData DataValue without verifying the actual tenant seed — the codebase already has this pattern documented (KI-5 / Recurring exclusion) and Session 8's first patch ignored that lesson.

---

## ⑯ Spec Addendum — Pledge Donation Lifecycle

> ### ⑯.0 STATUS — HISTORICAL (SUPERSEDED 2026-05-02 by Session 7 Path A)
>
> The original §⑯ design (new `PledgeDonations` mapping entity + `Pledge.GivenAmount` / `BalanceAmount` columns + `OPEN` / `PARTIALLY_FULFILLED` PLEDGESTATUS rows + ad-hoc applied-amounts) was written **before reading the live schema**. During Session 7 implementation it was discovered that:
>
> - `Pledge` already pre-generates an installment schedule via the `PledgePayment` 1:N child table.
> - `PledgePayment` already carries `GlobalDonationId`, `PaidDate`, `PaidAmount`, `PaymentStatusId` — the exact row §⑯ wanted to add.
> - PLEDGESTATUS is already seeded with `ONTRACK / FULFILLED / OVERDUE / BEHIND / CANCELLED` (NOT `OPEN / PARTIALLY_FULFILLED`).
>
> **The shipped contract (Path A)** uses existing `PledgePayment` rows as the fulfillment ledger. Donor picks one or more open installments; strict-pay rule (`PaidAmount == DueAmount`); BE recomputes `Pledge.PledgeStatusId` on save. NO new entity, NO migration, NO new MasterData seed. **See the Session 7 Build Log entry above for the source-of-truth file manifest, validation rules, and acceptance flow.**
>
> The §⑯.1–⑯.11 sections below are kept for audit history but **DO NOT match the shipped code**. Do not implement them literally — they were superseded.

> **Consumer**: `/continue-screen` Session 7 (planned) and the BE/FE agents that implement KI-26.
> **Status**: SPEC CAPTURED — NOT YET IMPLEMENTED. This section is the authoritative design contract for the Pledge donation flow; do not deviate without updating it first.
> **Why this lives here, not in `/plan-screens` revision**: this is an *additive* extension to the existing GlobalDonation FLOW screen — new conditional UI block on the form, one new child-mapping entity, one new validator branch, atomic balance update on save. It does NOT change the screen's identity, route, or top-level pattern, so it stays under the same prompt file. If scope grows (e.g. pledge creation moves into this screen, or pledges become first-class screen #X) the spec moves to `/plan-screens`.

### ⑯.1 Architectural decision — Pledge stays as DonationType (NOT DonationMode)

**Rule**: `Pledge` is a `DONATIONTYPE` MasterData row. It is **not** moved to `DONATIONMODE`.

**Why**:
- `Mode` = HOW the donation was paid → Cash, Cheque, BankTransfer, OnlineGateway, DIK, ReceiptBook. These are payment instruments.
- `Type` = WHY / intent / nature → One-Time, Recurring, Pledge, Memorial, Tribute. These describe the donation's classification, independent of payment instrument.
- A pledge fulfillment IS paid via one of the actual modes (cash/cheque/etc). If we move Pledge to Mode, we (a) lose the ability to record HOW the pledge was settled, (b) create a phantom "Pledge" mode that competes with real payment instruments, and (c) prevent a pledge from being settled through a real payment channel.
- This mirrors the existing precedent: `Recurring` is a Type (not a Mode) for the same reason — see Session 6 work that filtered Recurring out of the Type dropdown to force Hangfire-only generation.

**How to apply**: keep current MasterData seed for `Pledge` under `DONATIONTYPE`. No migration needed for this decision.

### ⑯.2 Missing entity — `PledgeDonations` mapping table

**Why required**: a single donation can fulfill more than one open pledge from the same donor (rare but valid — donor sends a lump sum that covers two outstanding pledges). The current schema has `Pledges` and `GlobalDonations` but **no transaction row recording each fulfillment** — meaning you can't audit *how* a pledge's `BalanceAmount` reached its current value, *which* donation paid down which pledge, or split a single donation across multiple pledges.

**Shape** (to be created under `Base.Domain/Models/DonationModels/`):

```csharp
public class PledgeDonation : EntityBase, IAuditableEntity, ISoftDeletable, ICompanyScoped
{
    public int PledgeDonationId { get; set; }            // PK
    public int GlobalDonationId { get; set; }            // FK → GlobalDonations
    public int PledgeId { get; set; }                    // FK → Pledges
    public decimal AppliedAmount { get; set; }           // amount of THIS donation applied to THIS pledge
    public decimal PledgePreviousBalance { get; set; }   // Pledge.BalanceAmount BEFORE this fulfillment (audit)
    public decimal PledgeNewBalance { get; set; }        // Pledge.BalanceAmount AFTER (audit)
    public int CompanyId { get; set; }                   // tenant scope
    // Standard audit + soft-delete fields inherited
    public GlobalDonation GlobalDonation { get; set; } = default!;
    public Pledge Pledge { get; set; } = default!;
    public Company Company { get; set; } = default!;
}
```

**EF configuration** (`Base.Infrastructure/Data/Configurations/DonationConfigurations/PledgeDonationConfiguration.cs`):
- Schema: `fund` (matches GlobalDonation/Pledge).
- Decimal precision: `AppliedAmount`, `PledgePreviousBalance`, `PledgeNewBalance` → `(18,2)`.
- Indexes: `(GlobalDonationId)`, `(PledgeId, IsDeleted)`, `(CompanyId)`.
- Cascade: do NOT cascade delete from GlobalDonation or Pledge — soft-delete only.

**Migration**: `Add_PledgeDonations_FulfillmentMapping` — single table create, no schema-altering changes to existing tables.

### ⑯.3 Validation rules

**On Create donation when `DonationType=Pledge`**:

1. **At least one pledge must be selected** — `pledgeFulfillments.length >= 1`.
2. **Each pledge must belong to the donating contact** — `Pledge.ContactId == GlobalDonation.ContactId` (no cross-donor fulfillment). Server-side check.
3. **Each pledge must be open** — `Pledge.Status.DataValue ∈ {OPEN, PARTIALLY_FULFILLED}`. `Pledge.BalanceAmount > 0`. Server-side check (don't trust FE-filtered list).
4. **Each `AppliedAmount` must be ≤ that pledge's current `BalanceAmount`** — over-application is rejected with a per-row validation error.
5. **Sum of `AppliedAmount` across all selected pledges must be ≤ `GlobalDonation.DonationAmount`** — donor cannot apply more to pledges than they actually donated. Excess (donation > sum-applied) is allowed and treated as a regular donation overflow (recorded but not pledge-linked).
6. **No duplicate pledge in the same donation** — same `PledgeId` cannot appear twice in the fulfillments array.

**Currency rule**: pledges are denominated in their own currency. If `Pledge.CurrencyId != GlobalDonation.CurrencyId`, the FE converts using the captured `ConversionRate` snapshot at save time (consistent with the rest of GlobalDonation FX policy — direct-pair lookup, never USD-pivoted). Apply the converted amount to `Pledge.BalanceAmount`, store both the original donation-currency `AppliedAmount` and the pledge-currency-equivalent in the `PledgeDonations` row (add `AppliedAmountInPledgeCurrency` + `ConversionRate` columns if cross-currency is in scope; if v1 ships single-currency-only, document that constraint and reject mismatched currencies at the validator).

### ⑯.4 BE flow — extending `CreateGlobalDonationWithChildren`

**Insertion point**: same handler that already handles cheque/online/DIK composites. Add a new branch keyed off `donationTypeRow.DataValue == "PLEDGE"`.

**Pseudocode** (inside the existing `dbContext.Database.BeginTransactionAsync` block):

```csharp
// 1. Resolve all selected pledges with row-locks (FOR UPDATE) to avoid concurrent fulfillment races.
//    Use IApplicationDbContext.ExecuteRawSqlAsync with pg_advisory_xact_lock per pledge OR
//    SELECT ... FOR UPDATE if Infrastructure layer exposes it. Mirror KI-13 approach.
var pledgeIds = req.PledgeFulfillments.Select(f => f.PledgeId).ToList();
var pledges = await dbContext.Pledges
    .Where(p => pledgeIds.Contains(p.PledgeId)
                && p.ContactId == req.Donation.ContactId
                && p.CompanyId == companyId
                && p.IsDeleted == false)
    .ToListAsync(ct);
// Validate count, ownership, status, balance per ⑯.3.

// 2. Save GlobalDonation first (existing flow). gd.GlobalDonationId now populated.

// 3. For each fulfillment, create PledgeDonation row + update Pledge.
foreach (var f in req.PledgeFulfillments)
{
    var p = pledges.Single(x => x.PledgeId == f.PledgeId);
    var prevBalance = p.BalanceAmount;
    var newBalance = prevBalance - f.AppliedAmount;
    if (newBalance < 0) throw new ValidationException(...); // race-safety net

    dbContext.PledgeDonations.Add(new PledgeDonation
    {
        GlobalDonationId = gd.GlobalDonationId,
        PledgeId = p.PledgeId,
        AppliedAmount = f.AppliedAmount,
        PledgePreviousBalance = prevBalance,
        PledgeNewBalance = newBalance,
        CompanyId = companyId,
    });

    p.GivenAmount += f.AppliedAmount;
    p.BalanceAmount = newBalance;
    if (newBalance == 0)
        p.PledgeStatusId = fulfilledStatusId; // resolved up-top from PLEDGESTATUS=FULFILLED
    else if (p.PledgeStatusId == openStatusId)
        p.PledgeStatusId = partiallyFulfilledStatusId; // PLEDGESTATUS=PARTIALLY_FULFILLED
}

await dbContext.SaveChangesAsync(ct);
await transaction.CommitAsync(ct);
```

**MasterData required**: `PLEDGESTATUS` type with rows `OPEN`, `PARTIALLY_FULFILLED`, `FULFILLED`, `CANCELLED`, `EXPIRED`. Verify the existing Pledge entity already references this — if not, add it to the seed alongside the entity migration.

### ⑯.5 BE query — surface fulfillments on `globalDonationById`

Extend `GetGlobalDonationById.cs` projection:

```csharp
.Include(x => x.PledgeDonations!.Where(pd => pd.IsDeleted == false))
    .ThenInclude(pd => pd.Pledge)
        .ThenInclude(p => p.PledgeStatus)
.Include(x => x.PledgeDonations!.Where(pd => pd.IsDeleted == false))
    .ThenInclude(pd => pd.Pledge)
        .ThenInclude(p => p.Currency)
```

Response DTO (`GlobalDonationDto`) gains a `pledgeDonations: PledgeDonationDto[]` array (scalar projection per Session 5 KI-22 lesson — no nested back-refs to GlobalDonation, no recursive nav DTOs).

### ⑯.6 FE flow — conditional pledge-selector block on `donation-form.tsx`

**Location**: under Section 2 (Donation Details), after the `donationTypeId` field. Renders only when the resolved Type code = `PLEDGE`.

**Block contents**:

1. **Pledge picker grid** — small in-form grid (NOT modal):
   - Source: new GraphQL query `OPEN_PLEDGES_BY_CONTACT_QUERY({ contactId, companyId })` filtered by `Status ∈ {OPEN, PARTIALLY_FULFILLED}` AND `BalanceAmount > 0`.
   - Columns: `PledgeNumber`, `PledgeDate`, `TotalAmount`, `GivenAmount`, `BalanceAmount`, `Currency`, `Status`, `[AppliedAmount input]`, `[Remove]`.
   - Empty state: "This donor has no open pledges. Either create a pledge first, or change the Donation Type."
2. **Add row** action — opens a sub-popover listing donor's remaining open pledges (the ones not already selected). Click adds it to the picker grid with `AppliedAmount = min(BalanceAmount, donationAmount - sumApplied)` as a sensible default.
3. **Live total under the grid** — "Applied: ₹X / Donation: ₹Y" with a warning chip when applied > donation (blocks submit).
4. **Remove** action — soft-removes a row from the local state; does NOT mutate the pledge until save.

**Zod schema additions**:
```ts
pledgeFulfillments: z.array(z.object({
  pledgeId: z.number().int().positive(),
  appliedAmount: z.number().positive(),
})).optional(),
```
With `.refine(...)` rules mirroring ⑯.3 (sum check, no duplicates).

**Lock rules**:
- When `donationType=Pledge` is picked AND `contactId` is empty → show contact-selection prompt and disable the pledge block.
- When `contactId` changes → clear `pledgeFulfillments` (donor's pledges are donor-specific).
- When mode = `edit` AND donation already has fulfillments → fulfillments are read-only (cannot modify which pledges a past donation paid down — that's an audit row); to "fix" a wrong fulfillment, void the donation and re-create.

**Save payload**: include `pledgeFulfillments` array on `CreateGlobalDonationWithChildrenInput` only when type = Pledge; null/empty otherwise.

### ⑯.7 View page — render fulfillments on `view-page.tsx`

Add a new card "Pledge Fulfillments" (visible only when `pledgeDonations?.length > 0`) showing:
- Per row: PledgeNumber + PledgeDate + AppliedAmount + (PledgePreviousBalance → PledgeNewBalance) + status pill.
- Footer: "Total applied to pledges: ₹{sum} of donation ₹{donationAmount}".

Card appears in the right column under "Distribution Breakdown".

### ⑯.8 Receipt impact

Pledge fulfillments DO appear on the donor receipt — donors expect to see "this donation paid down your pledge of ₹X by ₹Y, remaining balance ₹Z." Extend `receipt-template.tsx`:
- For non-DIK + has-pledge-fulfillments → render a "Pledge Settlement" section listing pledge number + applied amount + new balance.
- For DIK + Pledge → not a valid combination at v1 (DIK donations are item-based and not currently expected to fulfill cash pledges); validator rejects. Document this constraint in the form's DIK info banner.

### ⑯.9 File manifest (planned — generated when KI-26 is built)

**BE create**:
- `Base.Domain/Models/DonationModels/PledgeDonation.cs`
- `Base.Infrastructure/Data/Configurations/DonationConfigurations/PledgeDonationConfiguration.cs`
- EF migration `Add_PledgeDonations_FulfillmentMapping`
- Seed: `Base/sql-scripts-dyanmic/PledgeDonation-MasterData-sqlscripts.sql` (PLEDGESTATUS rows + any missing DonationType row audit)
- DTO: `Base.Application/Schemas/DonationSchemas/PledgeDonationSchemas.cs`

**BE modify**:
- `Base.Application/Business/DonationBusiness/GlobalDonations/Commands/CreateGlobalDonationWithChildren.cs` — Pledge branch + validator rules
- `Base.Application/Business/DonationBusiness/GlobalDonations/Queries/GetGlobalDonationById.cs` — include PledgeDonations + Pledge nav projections
- `Base.Application/Schemas/DonationSchemas/GlobalDonationSchemas.cs` — `PledgeFulfillmentRequestDto[]` on Create input; `PledgeDonationResponseDto[]` on response
- `Base.Infrastructure/Data/ApplicationDbContext.cs` — register `DbSet<PledgeDonation>`

**FE create**:
- `domain/entities/donation-service/PledgeDonationDto.ts`
- `infrastructure/gql-queries/donation-queries/OpenPledgesByContactQuery.ts`
- `presentation/components/page-components/crm/donation/globaldonation/pledge-fulfillment-grid.tsx` (the in-form picker block)

**FE modify**:
- `donation-form.tsx` — pledgeFulfillments Zod field + conditional block render + payload assembly + lock rules
- `view-page.tsx` — Pledge Fulfillments card
- `receipt-template.tsx` — pledge settlement section (donor variant only)
- `infrastructure/gql-mutations/donation-mutations/GlobalDonationCompositeMutation.ts` — extend create input with pledgeFulfillments
- `infrastructure/gql-queries/donation-queries/GlobalDonationQuery.ts` — extend by-id with pledgeDonations selection
- Barrel/index re-exports for the new pledge-fulfillment-grid component

### ⑯.10 Acceptance criteria (for the future Session 7)

- [ ] PledgeDonation entity + EF config + migration apply cleanly; rolls back cleanly.
- [ ] PLEDGESTATUS MasterData seeded; existing pledges get `Status=OPEN` if missing.
- [ ] Donor's open pledges load on the form when `DonationType=Pledge` is picked AND `contactId` is set.
- [ ] User can add multiple pledges, set per-row `AppliedAmount`, see live "applied of donation" total, remove rows.
- [ ] Server rejects: cross-donor pledge, closed pledge, applied > balance, sum-applied > donation, duplicate pledge.
- [ ] On save: PledgeDonations row created per fulfillment with before/after snapshots; `Pledge.GivenAmount` / `BalanceAmount` / `Status` updated atomically; concurrent fulfillment race surfaces a clean error (advisory-lock or row-lock).
- [ ] View page shows the Pledge Fulfillments card with previous→new balance per row.
- [ ] Donor receipt shows "Pledge Settlement" section with pledge number + applied amount + remaining balance.
- [ ] Edit mode treats existing fulfillments as read-only audit rows.
- [ ] Reverse path documented (or implemented) for voiding a pledge donation: must restore `Pledge.GivenAmount` / `BalanceAmount` and recompute status. v1 may defer reversal — document this in a follow-up KI if so.

### ⑯.11 Out of scope (explicitly NOT in this addendum)

- Creating new pledges from this screen (separate Pledge screen owns that).
- Pledge reminder workflows / Hangfire scheduling (separate concern).
- Pledge installment plans (one pledge → many scheduled fulfillments) — this addendum supports ad-hoc applied amounts, not pre-scheduled installments.
- Cross-currency pledge fulfillment beyond direct-pair FX snapshot (single-currency-only in v1 if cross-currency is dropped per ⑯.3 currency rule).
- Pledge transfer between donors (legal/audit concern).
