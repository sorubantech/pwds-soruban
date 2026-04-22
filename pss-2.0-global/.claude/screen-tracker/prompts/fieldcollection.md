---
screen: FieldCollection
registry_id: 65
module: CRM → Field Collection
status: COMPLETED
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-04-20
completed_date: 2026-04-21
last_session_date: 2026-04-21
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (collection-list.html + collection-form.html)
- [x] Existing code reviewed (AmbassadorCollection entity + full BE stack; FE `collectionlist` route is a STUB; separate `ambassadorcollection` route already implemented but NOT the target route for this screen)
- [x] Business rules + workflow (Pending → Verified | Flagged | Voided) extracted
- [x] FK targets resolved (Contact×2, Branch, Campaign, PaymentMode, MasterData, Bank, Currency, ReceiptBook)
- [x] File manifest computed
- [x] Approval config pre-filled (CRM_FIELDCOLLECTION / COLLECTIONLIST / OrderBy=3)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized (FORM = 6-section accordion; DETAIL = 2-column read view; INDEX = 4-widget header + admin grid with 12 columns + bulk actions)
- [x] User Approval received (pre-approved per build args)
- [x] Backend code generated (ALIGN — extended AmbassadorCollection entity + schemas/config/mappings; added GetAmbassadorCollectionSummary query; added Approve, Flag, Void, BulkApprove commands)
- [x] Backend wiring complete (Queries + Mutations endpoints extended; Mapster mapping includes joined display fields)
- [x] Frontend code generated (9 files: store, widgets, form, detail, view-page, index-page, index, page-config, route)
- [x] Frontend wiring complete (COLLECTIONLIST added to fieldcollection-service-entity-operations; page-config exported from crm/fieldcollection index)
- [ ] DB Seed script — DEFERRED per user directive (skip migration + seed writing this session)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (incl. new migration applies)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/fieldcollection/collectionlist`
- [ ] 4 KPI widgets render (Collections This Month, Pending Approval, Average Collection, Receipt Gaps)
- [ ] Grid loads 12 columns + row checkbox; row-click opens detail
- [ ] Full search + all 8 filters work (ambassador, branch, date range, payment mode, status, min/max amount)
- [ ] Bulk actions bar shows when rows selected (Approve Selected, Export Selected, Send Receipts SERVICE_PLACEHOLDER)
- [ ] Receipt-gap rows render with distinct styling and "Investigate" button
- [ ] Status badges render with mockup colors (Verified green, Pending yellow, Flagged red, Voided grey, Gap dark-red)
- [ ] Row-level Approve (for Pending), Review (for Flagged), Investigate (for Gap) buttons work and trigger correct workflow mutations
- [ ] Row actions dropdown: View, Edit, Void, Print Receipt (SERVICE_PLACEHOLDER), Send Digital Receipt (SERVICE_PLACEHOLDER)
- [ ] `?mode=new` — empty 6-section FORM renders (Collection Details + Donor Information + Payment Details + Donation Purpose & Receipt + Additional Information + Receipt Delivery)
- [ ] Payment-mode card selector (4 cards: Cash/Cheque/Mobile Transfer/Bank Receipt) works; selecting Cheque reveals Cheque Number / Bank / Cheque Date sub-form
- [ ] Donor selector shows inline mini-card with avatar/phone/address/last-donation when contact chosen
- [ ] "Quick Add Contact" button opens modal/toast (defer to Contact create mini-flow — SERVICE_PLACEHOLDER if contact mini-modal doesn't exist)
- [ ] Receipt Book dropdown → Receipt Number auto-suggests next available (SERVICE_PLACEHOLDER if gap-detection service not built)
- [ ] Back-dated validation warning banner appears when CollectedDate < today − N days (N=7 default)
- [ ] Recurring Commitment toggle reveals Frequency + Expected Amount sub-fields
- [ ] Receipt Delivery card selector (4 cards: Email / WhatsApp / SMS / Physical) works
- [ ] Save creates record → URL switches to `?mode=read&id={newId}` with Pending status (or Verified if auto-approve threshold met)
- [ ] `?mode=read&id=X` — 2-column DETAIL layout renders (info cards: Collection Info / Donor Info / Payment / Receipt / Notes / Audit Trail) — NOT disabled form
- [ ] Edit button on detail → `?mode=edit&id=X` → form pre-filled
- [ ] FK dropdowns load via ApiSelect (Ambassador, Branch, Donor, Campaign, Receipt Book, Payment Mode, Donation Purpose, Currency, Bank)
- [ ] Back-dated collection triggers manager-approval workflow (Status = Pending until approved)
- [ ] Unsaved-changes dialog triggers on dirty form back/cancel
- [ ] DB Seed — menu visible under CRM → Field Collection → "Collection List" (OrderBy 3)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: FieldCollection (entity `AmbassadorCollection`, route `collectionlist`)
Module: CRM → Field Collection
Schema: `fund`
Group: `FieldCollection` (Models: `FieldCollectionModels`, Schemas: `FieldCollectionSchemas`, Business: `FieldCollectionBusiness`, API: `EndPoints/FieldCollection`)

Business:
Field Collection is the admin / branch-manager list-and-workflow screen for cash-and-cheque donations collected in-person by ambassadors. Each row is a receipt-level transaction capturing donor + ambassador + branch + payment-mode + purpose + manual/digital receipt #. Managers use this screen to reconcile physical receipt books against recorded transactions, spot receipt-number gaps (indicating missing collections), approve back-dated or high-value entries, and flag suspicious activity (e.g. round-number cash donations far from donor's typical giving pattern). The grid surfaces 4 KPIs (month-to-date collection count, pending approvals, average collection, receipt-number gaps) and supports bulk-approve / bulk-send-receipts operations. +Add opens a 6-section accordion form (collection-form.html) capturing every field needed for the transaction, including conditional cheque fields and recurring-commitment tracking. The read-mode detail view organises the same data into 5 scan-friendly cards plus an audit trail. Upstream: Ambassador (screen #67) & Receipt Book (screen #66). Downstream: Cheque Donations (deposit tracking), Contact history, Campaign totals, Collection Distribution (screen #68).

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> ALIGN note: entity **already exists** at `Base.Domain/Models/FieldCollectionModels/AmbassadorCollection.cs`. The table below shows the **target state after extension**. ✅ = already on entity, ➕ = ADD, ⚠ = deprecate/rename.

Table: `fund."AmbassadorCollections"`

| Field | C# Type | MaxLen | Required | FK Target | Status | Notes |
|-------|---------|--------|----------|-----------|--------|-------|
| AmbassadorCollectionId | int | — | PK | — | ✅ | Primary key |
| CompanyId | int | — | YES | appl.Companies | ✅ | Tenant — from HttpContext, not exposed |
| BranchId | int | — | YES | appl.Branches | ✅ | Collection branch |
| AmbassadorContactId | int | — | YES | corg.Contacts | ➕ | Ambassador who collected (Contact filtered by type=Ambassador OR Staff — see §⑫) |
| CollectedDate | DateTime | — | YES | — | ✅ | Date of collection |
| CollectedTime | TimeSpan? | — | NO | — | ➕ | Time-of-day (mockup: separate "Collection Time" field) |
| ContactId | int | — | YES | corg.Contacts | ✅ | Donor |
| ContactTypeId | int? | — | NO | corg.ContactTypes | ✅ | Optional donor type |
| DonationAmount | decimal(18,2) | — | YES | — | ✅ | Amount |
| CurrencyId | int | — | YES | shrd.Currencies | ➕ | Currency of the amount |
| PaymentModeId | int | — | YES | shrd.PaymentModes | ✅ | Cash / Cheque / Mobile Transfer / Bank Receipt |
| DonationPurposeId | int | — | YES | sttg.MasterDatas | ⚠→✅ | **Existing `DonationTypeId` serves this** — keep field, re-label in DTO/UI as `donationPurposeId`. MasterData.DataType = `DONATIONPURPOSE` |
| CampaignId | int? | — | NO | appl.Campaigns | ➕ | Optional campaign link |
| ReceiptBookId | int? | — | NO | fund.ReceiptBooks | ➕ | Physical book reference |
| ReceiptNumber | string | 50 | YES | — | ➕ | Human-readable receipt # (matches physical book) — must be unique per ReceiptBookId |
| ReceiptType | string | 20 | YES | — | ➕ | `Manual` or `Digital` |
| DeliveryMethod | string | 20 | NO | — | ➕ | `Email` / `WhatsApp` / `SMS` / `Physical` |
| ChequeNumber | string | 50 | NO | — | ➕ | Conditional — required when PaymentMode = Cheque |
| ChequeDate | DateTime? | — | NO | — | ➕ | Conditional — required when PaymentMode = Cheque |
| BankId | int? | — | NO | shrd.Banks | ✅ | Conditional — bank for Cheque / Bank Receipt / Mobile Transfer |
| VisitNotes | string | 2000 | NO | — | ➕ | Free-text notes |
| Location | string | 500 | NO | — | ➕ | Collection location (e.g., "Deira, Dubai") |
| ReceiptPhotoPath | string | 500 | NO | — | ➕ | Uploaded receipt photo (SERVICE_PLACEHOLDER — existing file-upload pipeline, or toast if absent) |
| IsRecurringCommitment | bool | — | YES | — | ➕ | Default false |
| RecurringFrequency | string | 20 | NO | — | ➕ | Conditional when IsRecurringCommitment=true — `Weekly`/`Monthly`/`Quarterly`/`Yearly` |
| RecurringExpectedAmount | decimal(18,2)? | — | NO | — | ➕ | Conditional when IsRecurringCommitment=true |
| Status | string | 20 | YES | — | ➕ | `Pending` / `Verified` / `Flagged` / `Voided`. Default `Pending` on create unless auto-verify rule met. |
| FlagReason | string | 500 | NO | — | ➕ | Set when Status = Flagged |
| VoidReason | string | 500 | NO | — | ➕ | Set when Status = Voided |
| ApprovedByStaffId | int? | — | NO | appl.Staff | ➕ | Set on Verify |
| ApprovedDate | DateTime? | — | NO | — | ➕ | Set on Verify |
| ~~DonationTypeNo~~ | int | — | YES | — | ⚠ | **DEPRECATE**: existing unused int field. Drop in migration OR repurpose as "ReceiptNumberInt" (legacy). BA/BE to decide — recommendation: DROP. |
| ~~DonationTypeDate~~ | DateTime | — | YES | — | ⚠ | **DEPRECATE**: superseded by `ChequeDate`. Drop in migration. |

**Child Entities**: None in this screen's direct scope. (AmbassadorCollectionDistribution is screen #68 — parent-child link via `AmbassadorCollectionId` exists but its CRUD is a separate screen.)

**Uniqueness constraint**: (CompanyId, ReceiptBookId, ReceiptNumber) — cannot reuse a receipt number within the same book per tenant.

**Index suggestions** (performance): BranchId, AmbassadorContactId, CollectedDate DESC, Status.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelectV2 queries)
> ✅ All query names verified against actual `*Queries.cs` files.

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| BranchId | Branch | `Base.Domain/Models/ApplicationModels/Branch.cs` | `GetBranches` | `branchName` | `BranchResponseDto` |
| AmbassadorContactId | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | `GetContacts` (filter: ContactTypeName = "Ambassador") | `displayName` (fallback: `contactCode`) | `ContactResponseDto` |
| ContactId (donor) | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | `GetContacts` | `displayName` | `ContactResponseDto` |
| ContactTypeId | ContactType | `Base.Domain/Models/ContactModels/ContactType.cs` | `GetContactTypes` | `contactTypeName` | `ContactTypeResponseDto` |
| CurrencyId | Currency | `Base.Domain/Models/SharedModels/Currency.cs` | `GetCurrencies` | `currencyName` (or `currencyCode`) | `CurrencyResponseDto` |
| PaymentModeId | PaymentMode | `Base.Domain/Models/SharedModels/PaymentMode.cs` | `GetPaymentModes` | `paymentModeName` | `PaymentModeResponseDto` |
| DonationPurposeId | MasterData | `Base.Domain/Models/SettingModels/MasterData.cs` | `GetMasterDatas` (filter: `dataType = "DONATIONPURPOSE"`) | `dataName` | `MasterDataResponseDto` |
| CampaignId | Campaign | `Base.Domain/Models/ApplicationModels/Campaign.cs` | `GetCampaigns` | `shortDescription` (Campaign has no `campaignName` — confirm during BE dev; fallback: `campaignCode`) | `CampaignResponseDto` |
| ReceiptBookId | ReceiptBook | `Base.Domain/Models/FieldCollectionModels/ReceiptBook.cs` | `GetReceiptBooks` (filter: IsActive=true, BranchId=currentBranch) | `bookNo` + ` (Serial ${receiptStartNo}-${receiptEndNo})` | `ReceiptBookResponseDto` |
| BankId | Bank | `Base.Domain/Models/SharedModels/Bank.cs` | `GetBanks` | `bankName` | `BankResponseDto` |
| ApprovedByStaffId | Staff | `Base.Domain/Models/ApplicationModels/Staff.cs` | `GetStaffs` | `staffName` | `StaffResponseDto` |

**Navigation properties on AmbassadorCollection** (already exist for existing FKs; ADD for new FKs): `AmbassadorContact`, `Currency`, `Campaign`, `ReceiptBook`, `DonationPurpose` (already mapped as `MasterData` nav prop — rename to `DonationPurpose` in DTO), `ApprovedByStaff`.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `(CompanyId, ReceiptBookId, ReceiptNumber)` must be unique — server-side validator (`ValidateDuplicateRecord` pattern).
- Receipt numbers within a book must fall within `[ReceiptBook.ReceiptStartNo, ReceiptBook.ReceiptEndNo]`.

**Required Field Rules:**
- Always required: AmbassadorContactId, CollectedDate, ContactId, DonationAmount, CurrencyId, PaymentModeId, DonationPurposeId, ReceiptNumber, ReceiptType, BranchId.
- Conditionally required:
  - PaymentMode = Cheque → ChequeNumber, ChequeDate, BankId required.
  - PaymentMode = Mobile Transfer / Bank Receipt → BankId required.
  - IsRecurringCommitment = true → RecurringFrequency, RecurringExpectedAmount required.
  - Status = Flagged → FlagReason required.
  - Status = Voided → VoidReason required.

**Conditional Rules:**
- `DonationAmount > 0`.
- `CollectedDate <= today`. Back-dated (more than 7 days in the past) → warn on UI + force Status = Pending on save (requires manager approval to move to Verified).
- High-value cut-off (configurable, default 5000 base-currency) → force Status = Pending regardless of back-date.
- `CollectedTime` ≤ now when CollectedDate = today.

**Business Logic (auto-compute on Create):**
- If user is a branch manager AND amount < high-value threshold AND not back-dated → Status defaults to `Verified`, set ApprovedByStaffId = current user, ApprovedDate = now.
- Else Status = `Pending`.
- Receipt-gap detection: grid list query returns gap markers where `ReceiptNumber` sequence has holes within a book (left-outer-join against a generated sequence). Implemented in `GetAmbassadorCollections` as a virtual "gap row" in the returned page.

**Workflow (state machine):**
```
Pending ──Approve──> Verified
Pending ──Flag────> Flagged (FlagReason required)
Pending ──Void────> Voided  (VoidReason required)
Verified ──Void────> Voided  (VoidReason required)
Flagged ──Approve──> Verified
Flagged ──Void────> Voided
Voided ──(terminal)
```
- `ApproveAmbassadorCollection`: Pending | Flagged → Verified. Sets ApprovedByStaffId + ApprovedDate. BUSINESSADMIN only.
- `FlagAmbassadorCollection(id, reason)`: Pending | Verified → Flagged. Sets FlagReason. BUSINESSADMIN only.
- `VoidAmbassadorCollection(id, reason)`: any non-voided → Voided. Sets VoidReason. Does NOT delete. BUSINESSADMIN only.

**Bulk actions:**
- Bulk approve: array of ids → ApproveAmbassadorCollection loop (single txn).
- Bulk export: delegate to existing export handler for AmbassadorCollections with selected ids.
- Bulk send receipts (SERVICE_PLACEHOLDER): toast "Send receipts pipeline not yet wired".

**Side effects** (on Verified):
- None in this screen. Campaign totals / Contact donation-history aggregations are projections (no write-side updates).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — PRE-ANSWERED.

**Screen Type**: FLOW
**Type Classification**: Transactional with workflow state machine + multi-section form + read-mode detail view + summary widgets + bulk actions.
**Reason**: "+Record Collection" opens a full-page 6-section accordion form (NOT a modal). View opens a different multi-column detail layout. URL drives `?mode=new/edit/read`. Pending-approval workflow governs row actions.

**Backend Patterns Required:**
- [x] Standard CRUD (ALIGN — extend existing 11 files)
- [x] Tenant scoping (CompanyId from HttpContext) — already in place
- [ ] Nested child creation — not for this screen (distribution is #68)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 10)
- [x] Unique validation — (ReceiptBookId, ReceiptNumber)
- [x] Workflow commands: `ApproveAmbassadorCollection`, `FlagAmbassadorCollection`, `VoidAmbassadorCollection`
- [x] Bulk approve mutation: `BulkApproveAmbassadorCollections(ids: [Int!])`
- [x] Summary query: `GetAmbassadorCollectionSummary` (returns dto with 4 KPI values)
- [x] File upload command — existing `FilePathUploadCommand` or equivalent for ReceiptPhotoPath (verify + reuse)
- [x] Custom business rule validators — back-date threshold, high-value threshold, cheque-conditional fields, recurring-conditional fields

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) — with widgets-above-grid variant
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form (for FORM layout)
- [x] Zustand store (`fieldcollection-store.ts`)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (with Back, Save/Edit buttons)
- [ ] Child grid inside form — N/A
- [x] Workflow status badge + action buttons (Approve / Flag / Void row-level)
- [x] Bulk selection + bulk-actions bar (shown when ≥1 row selected)
- [x] File upload widget — ReceiptPhoto (SERVICE_PLACEHOLDER toast if file infra absent)
- [x] Summary cards / count widgets above grid — 4 KPI cards
- [x] Grid aggregation columns — gap detection (virtual rows from server)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockups (`collection-list.html` + `collection-form.html`).

### Grid/List View

**Display Mode**: `table`

**Grid Columns** (in display order — from collection-list.html lines 967-983):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 0 | ☐ | (selection) | checkbox | 36px | — | Row select for bulk actions |
| 1 | Receipt # | receiptNumber | link | 90px | YES | Click → detail (modal on mockup; use `?mode=read&id=X`) |
| 2 | Date | collectedDate | date | 100px | YES | Short format: "Apr 12" |
| 3 | Ambassador | ambassadorContactName | text | 140px | YES | FK display |
| 4 | Donor | contactDisplayName | link | 160px | YES | Click → /crm/corg/contact?mode=read (contact detail) |
| 5 | Amount | donationAmount | currency | 110px | YES | Right-aligned, monospace; format e.g. "$500" with currency-code subscript |
| 6 | Currency | currencyCode | text | 70px | YES | "AED" / "USD" / ... |
| 7 | Mode | paymentModeName | badge (with emoji) | 120px | YES | 💵 Cash / 📄 Cheque / 📱 Mobile / 🏦 Bank |
| 8 | Purpose | donationPurposeName | badge | 130px | YES | Color-coded per mockup (orphan, education, water, healthcare, general) |
| 9 | Campaign | campaignShortDescription | text | 140px | YES | Falls back to "—" if null |
| 10 | Book | receiptBookBookNo | text | 80px | YES | e.g. "RB-045" |
| 11 | Status | status | badge | 120px | YES | Verified ✅ green / Pending ⏳ yellow / Flagged ⚠️ red / Voided ⛔ grey / **Gap 🔴 dark-red** (virtual row) |
| 12 | Actions | (actions) | action-group | 180px | — | View, Receipt, 3-dot: View Details / Edit / Void / Print Receipt / Send Digital Receipt |

**Gap rows** (server-generated virtual rows): Receipt#="—", Donor="—", Amount="—", Mode="—", Purpose="—", Campaign="—", Book=(book no), Status="Gap: #XXXX missing" (dark-red badge), Actions=single red "Investigate" button. CSS: background `#fef2f2` italic text. Implemented server-side by scanning each book's issued range vs. recorded receipts.

**Search/Filter Fields** (from mockup filter-bar rows 886-953):
- Row 1: Search-text (donor / receipt / ambassador), Ambassador dropdown, Branch dropdown, Date From, Date To.
- Row 2: Payment Mode dropdown, Status dropdown, Min Amount, Max Amount, "Clear Filters" link.
- All filters wired to `GetAmbassadorCollections` query args: `searchText`, `ambassadorContactId`, `branchId`, `dateFrom`, `dateTo`, `paymentModeId`, `status`, `minAmount`, `maxAmount`, plus standard `pageNo`, `pageSize`, `sortField`, `sortDir`.

**Header Actions** (collection-list.html lines 826-836): [+ Record Collection] (primary — navigates to `?mode=new`), [Bulk Import] (SERVICE_PLACEHOLDER — toast), [Export] (delegates to existing export infra).

**Bulk Actions Bar** (appears when ≥1 row checked): "{N} selected" label + [Approve Selected], [Export Selected], [Send Receipts] (SERVICE_PLACEHOLDER).

**Row-level action buttons** (conditional by status):
- Status = Verified: `[View] [Receipt]` + 3-dot menu.
- Status = Pending: `[View] [Approve]` + 3-dot menu.
- Status = Flagged: `[View] [Review]` + 3-dot menu. "Review" opens Flag-details modal with Approve / Keep-flagged options.
- Status = Voided: `[View]` only.
- Status = Gap (virtual): `[Investigate]` only → opens a dialog listing possible causes (unrecorded, missing receipt book, etc.).

**3-dot dropdown** (all rows except Gap): View Details / Edit / Void (danger) / Print Receipt (SERVICE_PLACEHOLDER) / Send Digital Receipt (SERVICE_PLACEHOLDER).

**Row Click**: Navigates to `?mode=read&id={id}` (DETAIL layout). (Mockup uses modal — we promote to full detail page per FLOW pattern.)

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

#### LAYOUT 1: FORM (mode=new & mode=edit)

> Matches `collection-form.html` exactly. 6 cards stacked vertically, each with accordion toggle.
> Page title: "Record Collection" (new) or "Edit Collection — #{ReceiptNumber}" (edit).

**Page Header**: FlowFormPageHeader with Back button + breadcrumb ("Field Collection > Record Collection") + right-aligned actions `[Save]` (primary), `[Save & New]` (outline), `[Cancel]` (text).

**Validation Banner** (amber): Renders above card stack when `CollectedDate < today - 7 days` → "Back-dated collection — requires manager approval".

**Section Container Type**: `cards` with accordion toggle (each card has `section-header` + `section-body`, chevron icon rotates on collapse). All sections expanded by default.

**Form Sections** (in display order — matches mockup 6 `<div class="form-card">` blocks):

| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | `fa-clipboard-list` | Collection Details | 3-column | expanded | Ambassador, Collection Date, Collection Time |
| 2 | `fa-user` | Donor Information | full-width | expanded | Donor/Contact (searchable select) + Quick Add Contact button + **Donor Mini-Card** (auto-appears on donor select) |
| 3 | `fa-money-bill-wave` | Payment Details | 2-column (with full-width payment-mode row + full-width conditional cheque sub-form) | expanded | Amount (large input), Currency, Payment Mode (card selector), [conditional] Cheque Number / Bank / Cheque Date |
| 4 | `fa-receipt` | Donation Purpose & Receipt | 2-column | expanded | Donation Purpose, Campaign, Receipt Book, Receipt Number, Receipt Type (radio) |
| 5 | `fa-circle-info` | Additional Information | 2-column (notes full-width, recurring full-width) | expanded | Visit Notes (textarea), Location, Photo of Receipt (file upload), Recurring Commitment toggle + [conditional] Frequency + Expected Amount |
| 6 | `fa-paper-plane` | Receipt Delivery | full-width | expanded | Send Digital Receipt (card selector: Email / WhatsApp / SMS / Physical) |

**Field Widget Mapping** (all fields across all sections):

| Field | Section | Widget | Placeholder / Default | Validation | Notes |
|-------|---------|--------|-----------------------|------------|-------|
| ambassadorContactId | 1 | ApiSelectV2 | "Select ambassador..." | required | Query: `GetContacts` filtered by ContactType=Ambassador. Display `displayName` + `contactCode` + ` (${branchName})` |
| collectedDate | 1 | datepicker | today | required, ≤ today | Trigger back-date banner if < today − 7 days |
| collectedTime | 1 | timepicker | now (hh:mm) | — | Optional |
| contactId | 2 | ApiSelectV2 (searchable) | "Search donor by name, phone or code..." | required | Query: `GetContacts`. Display `displayName` — `phone` — `address`. On select → fetch `GetContactById` → render mini-card. |
| (quickAddContact) | 2 | dashed-outline button | — | — | Label: "+ Quick Add Contact". Opens a lightweight Contact-create modal (reuse Contact's existing create-form if exposed; SERVICE_PLACEHOLDER if not — toast). |
| donationAmount | 3 | number (large, monospace) | "0.00" | required, > 0 | Class: `amount-input-large`, font-size 1.5rem |
| currencyId | 3 | ApiSelectV2 | default = tenant base currency | required | Query: `GetCurrencies`. Display `currencyCode` + ` (${symbol})` |
| paymentModeId | 3 | **card-selector (4 cards)** | default = Cash | required | See Card Selector table below |
| chequeNumber | 3 | text | "Enter cheque number" | required IF paymentMode=Cheque | Inside conditional sub-form |
| bankId | 3 | ApiSelectV2 | "Select bank..." | required IF paymentMode ∈ {Cheque, BankReceipt, MobileTransfer} | Query: `GetBanks` |
| chequeDate | 3 | datepicker | — | required IF paymentMode=Cheque | — |
| donationPurposeId | 4 | ApiSelectV2 | "Select purpose..." | required | Query: `GetMasterDatas` filtered by `DataType=DONATIONPURPOSE` |
| campaignId | 4 | ApiSelectV2 | "Select campaign (optional)..." | — | Query: `GetCampaigns` |
| receiptBookId | 4 | ApiSelectV2 | "Select receipt book..." | — | Query: `GetReceiptBooks` filtered by BranchId + IsActive. Display `bookNo` + ` (Serial ${receiptStartNo}-${receiptEndNo})` |
| receiptNumber | 4 | text | "Enter receipt number" | required, unique per book | Helper text: "Auto-suggested: next available receipt number". On book-select → call backend helper `GetNextReceiptNumber(receiptBookId)` if available, else leave blank. |
| receiptType | 4 | radio-inline (2) | default = Manual | required | "Manual (physical book)" / "Digital (SMS/WhatsApp receipt)" |
| visitNotes | 5 | textarea (rows=3) | "Enter notes about the visit..." | max 2000 | Full-width |
| location | 5 | text | "Enter collection location" | max 500 | — |
| receiptPhotoPath | 5 | file-upload (dashed) | "Click to upload or drag & drop" | JPG/PNG ≤ 5MB | SERVICE_PLACEHOLDER if file infra absent — toast "Photo upload pipeline not yet wired", but field accepts base64/path |
| isRecurringCommitment | 5 | toggle-switch | false | — | Label: "Donor committed to recurring donations" |
| recurringFrequency | 5 | ApiSelectV2 | "Select frequency..." | required IF isRecurring=true | Query: `GetMasterDatas` filtered by `DataType=RECURRINGFREQUENCY`. Options: Weekly/Monthly/Quarterly/Yearly |
| recurringExpectedAmount | 5 | number | "0.00" | required IF isRecurring=true | — |
| deliveryMethod | 6 | **card-selector (4 cards)** | default = WhatsApp | — | See Card Selector table below |

**Card Selectors** (two instances):

*Payment Mode card-selector (Section 3):*
| Card | Icon | Label | Value | Triggers |
|------|------|-------|-------|----------|
| 1 | 💵 | Cash | `Cash` | — |
| 2 | 📄 | Cheque | `Cheque` | **Shows conditional sub-form: Cheque Number / Bank / Cheque Date** + info text "Cheque will be tracked in Cheque Donations screen for deposit and clearance" |
| 3 | 📱 | Mobile Transfer | `MobileTransfer` | Shows BankId required |
| 4 | 🏦 | Bank Receipt | `BankReceipt` | Shows BankId required |

*Receipt Delivery card-selector (Section 6):*
| Card | Icon | Label | Value |
|------|------|-------|-------|
| 1 | 📧 | Email | `Email` |
| 2 | 📱 | WhatsApp | `WhatsApp` (default) |
| 3 | 📲 | SMS | `SMS` |
| 4 | 🖨️ | Physical Only | `Physical` |

Helper hint under cards: "Auto-selected: WhatsApp (donor's preference)" — may read donor's preferred channel from `Contact` when donorId changes.

**Conditional Sub-forms:**
| Trigger Field | Trigger Value | Sub-form Fields |
|--------------|---------------|-----------------|
| paymentModeId | "Cheque" | 3-column: chequeNumber, bankId, chequeDate (+ info text about Cheque Donations) |
| paymentModeId | "MobileTransfer" / "BankReceipt" | bankId becomes required (still in main 2-col layout) |
| isRecurringCommitment | true | 2-column: recurringFrequency, recurringExpectedAmount (+ info text) |

**Inline Mini Display — Donor Mini-Card** (appears when donor selected):
| Element | Value |
|---------|-------|
| Avatar (initials) | First letter(s) of donor name on green circle (bg `#059669`) |
| Name | `contact.displayName` |
| Phone | `📞 ${contact.phone}` |
| Address | `📍 ${contact.address}` (join Apt+City if split) |
| Last donation | `💰 Last donation: $${amt} on ${date}` (query from Contact's donation history; SERVICE_PLACEHOLDER "no data" if aggregation not available) |
| Donor since | `📅 Donor since: ${year}` (from contact creation date) |
| Preferred purpose badge | `<badge> Orphan Care</badge>` (from contact's last/top purpose) |

**Sticky Footer** (mobile-only ≤768px): Same 3 buttons as header (Save / Save & New / Cancel).

**Child Grids in Form**: None.

---

#### LAYOUT 2: DETAIL (mode=read)

> Matches the `detail-modal` design in collection-list.html (lines 1243-1373) but promoted from modal to a 2-column full page.
> **This is NOT the form disabled — it's a separate card-based read view.**

**Page Header**: FlowFormPageHeader with Back button + breadcrumb. Title: "Collection Details — Receipt #{ReceiptNumber}" (receipt number highlighted in accent color).

**Header Actions** (status-dependent):
- Always: `[Edit]`, `[Print Receipt]` (SERVICE_PLACEHOLDER), `[Send Receipt]` (SERVICE_PLACEHOLDER), `[Close/Back]`
- Status ∈ {Pending, Flagged}: `[Approve]` (green)
- Status ≠ Voided: `[Void]` (danger outline)
- Status = Flagged: `[Review flag]` dropdown

**Page Layout**:
| Column | Width | Cards |
|--------|-------|-------|
| Left | 2fr | Card: Collection Info, Card: Payment, Card: Receipt, Card: Notes |
| Right | 1fr | Card: Donor Info, Card: Audit Trail, Card: Status & Workflow |

**Left Column Cards**:

| # | Card Title | Content |
|---|-----------|---------|
| 1 | Collection Info | 2-col grid: Receipt #, Date (full date), Time, Ambassador, Branch |
| 2 | Payment | 2-col grid: Amount (large, green bold ∼1rem, monospace), Currency, Mode (icon+text), Purpose (badge), Campaign; if paymentMode=Cheque → additional: Cheque Number, Bank, Cheque Date |
| 3 | Receipt | 2-col grid: Book, Receipt #, Type (Manual/Digital), Delivery Method (icon+text) |
| 4 | Notes | Full-width italic text in `#f8fafc` pill. Plus Location + Receipt Photo thumbnail (clickable) if present |

**Right Column Cards**:

| # | Card Title | Content |
|---|-----------|---------|
| 1 | Donor Info | Avatar + Name (clickable → contact detail) + Phone + Address (full-width) + Recurring badge if IsRecurring=true (shows Frequency + Expected Amount) |
| 2 | Audit Trail | Timeline (dl-list): Created by (ambassador name + role), Created at, Approved by, Approved at (if Verified), Flagged by + reason (if Flagged), Voided by + reason + voided at (if Voided) |
| 3 | Status & Workflow | Large status badge; buttons matching the row-level-action buttons above (Approve/Review/Void) wired to workflow mutations |

**If user navigates from grid row to `?mode=read&id=X`**, show a lightweight toast if record not found.

---

### Page Widgets & Summary Cards

> 4 KPI cards above the grid (collection-list.html lines 840-881).

**Grid Layout Variant**: `widgets-above-grid` (MANDATORY — `<ScreenHeader>` + widget row + `<DataTableContainer showHeader={false}>`).

**Widgets**:

| # | Widget Title | Value Source | Display Type | Position | Icon / Color |
|---|-------------|-------------|-------------|----------|--------------|
| 1 | Collections (This Month) | `summary.monthToDateCount` + `summary.monthToDateAmountBase` | count + subtitle "Amount: ${amt}" | Top-left | `fa-hand-holding-dollar` / green |
| 2 | Pending Approval | `summary.pendingCount` + breakdown | count + subtitle "Back-dated: N, High-value: M" | Top-center-left | `fa-clock` / orange |
| 3 | Average Collection | `summary.averageAmount` | currency + subtitle "Median: ${amt}" | Top-center-right | `fa-calculator` / blue |
| 4 | Receipt Gaps | `summary.gapCount` | count + subtitle "Missing receipt numbers in sequence" | Top-right | `fa-triangle-exclamation` / red |

**Summary GQL Query**:
- Query name: `GetAmbassadorCollectionSummary`
- Returns: `AmbassadorCollectionSummaryDto` with fields: `monthToDateCount: int`, `monthToDateAmountBase: decimal`, `pendingCount: int`, `pendingBackDatedCount: int`, `pendingHighValueCount: int`, `averageAmount: decimal`, `medianAmount: decimal`, `gapCount: int`.
- Added to `AmbassadorCollectionQueries.cs` alongside existing `GetAmbassadorCollections` and `GetAmbassadorCollectionById`.
- Scoped by tenant (CompanyId from HttpContext). Refreshes whenever grid filters change (re-fire on filter update — pass dateFrom/dateTo + branchId so widgets reflect filters; or leave global — TBD by BA, default: **global** per mockup copy "(This Month)").

---

### Grid Aggregation Columns

**Aggregation Columns**: None as per-row subqueries in this screen.

**Gap-row Injection**: Server-side, not a column — see Grid Columns section above.

---

### User Interaction Flow (FLOW — 3 modes, 2 UI layouts)

1. Grid loads → widgets fetch from `GetAmbassadorCollectionSummary`; grid from `GetAmbassadorCollections`.
2. User clicks `+Record Collection` → `/collectionlist?mode=new` → empty FORM (6 sections expanded, PaymentMode=Cash, DeliveryMethod=WhatsApp).
3. User picks donor → mini-card appears. Picks Cheque → cheque sub-form slides in.
4. User saves → `CreateAmbassadorCollection` mutation → if Pending: URL switches to `?mode=read&id={newId}` with Pending status banner; if auto-Verified: same but Verified.
5. Row click or row View button → `?mode=read&id=X` → DETAIL layout loads.
6. Detail Edit button → `?mode=edit&id=X` → FORM pre-filled.
7. Detail Approve → confirm modal → `ApproveAmbassadorCollection(id)` → status becomes Verified, audit trail updates, stays on detail page.
8. Detail Flag → modal with reason → `FlagAmbassadorCollection(id, reason)` → status = Flagged, returns to detail.
9. Detail Void → confirm modal with reason → `VoidAmbassadorCollection(id, reason)` → status = Voided, buttons collapse to just View/Back.
10. Bulk-approve: select rows → click "Approve Selected" in bulk bar → confirm → `BulkApproveAmbassadorCollections(ids)` → toast + grid refresh + widgets refresh.
11. Back: returns to `/collectionlist` (no params) → grid.
12. Unsaved changes dialog triggers on dirty form back/cancel.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity (SavedFilter) to **this entity** AND notes that `AmbassadorCollection` entity already exists — the BE dev is **extending** rather than creating.

**Canonical Reference**: SavedFilter (FLOW). Also reference the existing `AmbassadorCollection` implementation at `Base.API/EndPoints/FieldCollection/` for context.

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | AmbassadorCollection | Entity/class name (existing) |
| savedFilter | ambassadorCollection | Variable / field names |
| SavedFilterId | AmbassadorCollectionId | PK field (existing) |
| SavedFilters | AmbassadorCollections | Table name, collection names (existing) |
| saved-filter | fieldcollection | FE route folder name (`collectionlist` route inside `crm/fieldcollection/`) |
| savedfilter | collectionlist | FE entity-lower / page folder (**this is the NEW FE route for screen #65** — NOT the existing `ambassadorcollection` route, which is screen #67's "Record Collection" menu) |
| SAVEDFILTER | COLLECTIONLIST | Grid code, menu code |
| notify | fund | DB schema (existing) |
| Notify | FieldCollection | Backend group name (Models/Schemas/Business subfolder) |
| NotifyModels | FieldCollectionModels | Namespace suffix (existing) |
| NOTIFICATIONSETUP | CRM_FIELDCOLLECTION | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/fieldcollection/collectionlist | FE route path |
| notify-service | fieldcollection-service | FE service folder name (already exists — extend DTOs) |

**Key naming clarification for FE agent:**
- **Entity name** in code: `AmbassadorCollection` (DO NOT rename the entity).
- **UI/route name**: "Field Collection" with URL slug `collectionlist`.
- **FE page folder**: `src/presentation/components/page-components/crm/fieldcollection/collectionlist/` (NEW — create this; existing `ambassadorcollection` folder serves a different screen and stays untouched except the shared DTO/GQL files).
- **Shared artifacts to EXTEND not duplicate**: `AmbassadorCollectionDto.ts`, `AmbassadorCollectionQuery.ts`, `AmbassadorCollectionMutation.ts` (add new fields + new queries + new mutations).

---

## ⑧ File Manifest

### Backend Files

> **ALIGN**: all 11 files exist. Extend/modify — do NOT regenerate.

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Entity | `PSS_2.0_Backend/.../Base.Domain/Models/FieldCollectionModels/AmbassadorCollection.cs` | **EXTEND**: add 18 new fields (§②); remove `DonationTypeNo`, `DonationTypeDate` |
| 2 | EF Config | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Configurations/FieldCollectionConfigurations/AmbassadorCollectionConfiguration.cs` | **EXTEND**: column mappings + unique index `(CompanyId, ReceiptBookId, ReceiptNumber)` + new nav-prop configs |
| 3 | Schemas (DTOs) | `PSS_2.0_Backend/.../Base.Application/Schemas/FieldCollectionSchemas/AmbassadorCollectionSchemas.cs` | **EXTEND**: add all new request + response fields; add `AmbassadorCollectionSummaryDto` |
| 4 | Create Command | `PSS_2.0_Backend/.../Base.Application/Business/FieldCollectionBusiness/AmbassadorCollections/CreateCommand/CreateAmbassadorCollection.cs` | **EXTEND**: map new fields; auto-compute Status (Pending vs Verified) + back-date/high-value rules |
| 5 | Update Command | `...UpdateCommand/UpdateAmbassadorCollection.cs` | **EXTEND**: map new fields; enforce immutability of ReceiptNumber (or validate book uniqueness) |
| 6 | Delete Command | `...DeleteCommand/DeleteAmbassadorCollection.cs` | **REVIEW**: prefer soft-delete via Void mutation instead of hard delete |
| 7 | Toggle Command | `...ToggleCommand/ToggleAmbassadorCollection.cs` | unchanged |
| 8 | GetAll Query | `...GetAllQuery/GetAllAmbassadorCollection.cs` | **EXTEND**: add 8 new filter args; add joins for display names; inject Gap virtual rows per book in date range |
| 9 | GetById Query | `...GetByIdQuery/GetAmbassadorCollectionById.cs` | **EXTEND**: include new nav-props (Campaign, ReceiptBook, Currency, AmbassadorContact, ApprovedByStaff) |
| 10 | Mutations | `PSS_2.0_Backend/.../Base.API/EndPoints/FieldCollection/Mutations/AmbassadorCollectionMutations.cs` | **EXTEND**: add `ApproveAmbassadorCollection`, `FlagAmbassadorCollection`, `VoidAmbassadorCollection`, `BulkApproveAmbassadorCollections` |
| 11 | Queries | `PSS_2.0_Backend/.../Base.API/EndPoints/FieldCollection/Queries/AmbassadorCollectionQueries.cs` | **EXTEND**: add `GetAmbassadorCollectionSummary` |

**NEW Backend Files**:
| # | File | Path | Action |
|---|------|------|--------|
| 12 | Summary Query | `.../AmbassadorCollections/GetSummaryQuery/GetAmbassadorCollectionSummary.cs` | NEW |
| 13 | Approve Command | `.../AmbassadorCollections/ApproveCommand/ApproveAmbassadorCollection.cs` | NEW |
| 14 | Flag Command | `.../AmbassadorCollections/FlagCommand/FlagAmbassadorCollection.cs` | NEW |
| 15 | Void Command | `.../AmbassadorCollections/VoidCommand/VoidAmbassadorCollection.cs` | NEW |
| 16 | BulkApprove Command | `.../AmbassadorCollections/BulkApproveCommand/BulkApproveAmbassadorCollections.cs` | NEW |
| 17 | EF Migration | `PSS_2.0_Backend/.../Base.Infrastructure/Data/Migrations/{timestamp}_ExtendAmbassadorCollection.cs` | NEW — auto-generated by `dotnet ef migrations add` |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext.cs` | No change — `AmbassadorCollections` DbSet already present |
| 2 | `FieldCollectionDbContext.cs` (or root) | No change |
| 3 | `DecoratorProperties.cs` | Verify `DecoratorFieldCollectionModules` still lists `AmbassadorCollections`; no new entry |
| 4 | `FieldCollectionMappings.cs` | **EXTEND**: update Request↔Response Mapster config to include all new fields; add mapping for `AmbassadorCollectionSummaryDto` |
| 5 | `BaseInputValidationBehaviour` — add validator registration for new commands | (standard wiring) |

### Frontend Files

> **ALIGN/FE-BUILD**: existing `collectionlist` route is a STUB — **build from scratch** using existing `ambassadorcollection` feature as reference. The `AmbassadorCollectionDto.ts` and `AmbassadorCollectionQuery.ts` already exist — extend them.

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/fieldcollection-service/AmbassadorCollectionDto.ts` | **EXTEND**: add 18 new fields to Request/Response; add `AmbassadorCollectionSummaryDto` interface |
| 2 | GQL Query | `PSS_2.0_Frontend/src/infrastructure/gql-queries/fieldcollection-queries/AmbassadorCollectionQuery.ts` | **EXTEND**: update `GetAmbassadorCollections` with new filter args + new selected fields; add `GetAmbassadorCollectionSummary` query |
| 3 | GQL Mutation | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/fieldcollection-mutations/AmbassadorCollectionMutation.ts` | **EXTEND**: add Approve, Flag, Void, BulkApprove mutations |
| 4 | Page Config | `PSS_2.0_Frontend/src/presentation/pages/crm/fieldcollection/collectionlist.tsx` | **NEW**: CollectionListPageConfig (operations, columns, filters, widgets) |
| 5 | Index Page (wrapper) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/fieldcollection/collectionlist/index.tsx` | **NEW**: re-exports |
| 6 | Index Page Component | `.../collectionlist/index-page.tsx` | **NEW**: ScreenHeader + widgets row + FlowDataTable (showHeader=false) with bulk-actions bar |
| 7 | **View Page** (3 modes) | `.../collectionlist/view-page.tsx` | **NEW**: `?mode=new/edit/read`; FORM (6 sections) vs DETAIL (2-column cards) |
| 8 | **Zustand Store** | `.../collectionlist/collectionlist-store.ts` | **NEW**: form state, workflow actions, dirty tracking |
| 9 | Route Page | `PSS_2.0_Frontend/src/app/[lang]/crm/fieldcollection/collectionlist/page.tsx` | **REPLACE STUB**: delegate to CollectionListPageConfig |

**Supporting FE components** (as separate files if complex, else co-located in view-page):
| # | File | Action |
|---|------|--------|
| 10 | `collectionlist/components/DonorMiniCard.tsx` | NEW |
| 11 | `collectionlist/components/PaymentModeCardSelector.tsx` | NEW (reusable card-selector component) |
| 12 | `collectionlist/components/DeliveryMethodCardSelector.tsx` | NEW (or share `CardSelector` primitive with PaymentMode) |
| 13 | `collectionlist/components/BulkActionsBar.tsx` | NEW (or reuse existing primitive if one exists) |
| 14 | `collectionlist/components/WorkflowActions.tsx` | NEW — Approve/Flag/Void buttons with confirm modals |
| 15 | `collectionlist/components/SummaryWidgets.tsx` | NEW — 4 KPI cards |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `src/application/configs/data-table-configs/fieldcollection-service-entity-operations.ts` | Add `COLLECTIONLIST` operations config |
| 2 | `src/application/configs/data-table-configs/operations-config.ts` | Import + register `COLLECTIONLIST` |
| 3 | Sidebar menu config (DB-seeded via `Menu` table — see §⑨) | Menu row for Collection List under CRM_FIELDCOLLECTION |
| 4 | Route config — Next.js file-based routing — no change needed (page.tsx is the wiring) |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens. Values verified against `MODULE_MENU_REFERENCE.md`.

```
---CONFIG-START---
Scope: ALIGN (extend BE entity; build collectionlist FE feature from stub)

MenuName: Collection List
MenuCode: COLLECTIONLIST
ParentMenu: CRM_FIELDCOLLECTION
Module: CRM
MenuUrl: crm/fieldcollection/collectionlist
GridType: FLOW
OrderBy: 3

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: COLLECTIONLIST
---CONFIG-END---
```

**MasterData seed rows** (needed for FK dropdowns):

| DataType | DataName | DataCode |
|----------|----------|----------|
| DONATIONPURPOSE | Orphan Care | ORPHAN |
| DONATIONPURPOSE | Education Sponsorship | EDUCATION |
| DONATIONPURPOSE | Healthcare Support | HEALTHCARE |
| DONATIONPURPOSE | Clean Water | WATER |
| DONATIONPURPOSE | Food Distribution | FOOD |
| DONATIONPURPOSE | General Fund | GENERAL |
| DONATIONPURPOSE | Zakat | ZAKAT |
| DONATIONPURPOSE | Sadaqah | SADAQAH |
| RECURRINGFREQUENCY | Weekly | WEEKLY |
| RECURRINGFREQUENCY | Monthly | MONTHLY |
| RECURRINGFREQUENCY | Quarterly | QUARTERLY |
| RECURRINGFREQUENCY | Yearly | YEARLY |

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `AmbassadorCollectionQueries`
- Mutation type: `AmbassadorCollectionMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetAmbassadorCollections | `PaginatedApiResponse<[AmbassadorCollectionResponseDto]>` | `searchText`, `ambassadorContactId`, `branchId`, `dateFrom`, `dateTo`, `paymentModeId`, `status`, `minAmount`, `maxAmount`, `pageNo`, `pageSize`, `sortField`, `sortDir`, `isActive` |
| GetAmbassadorCollectionById | `AmbassadorCollectionResponseDto` | `ambassadorCollectionId` |
| GetAmbassadorCollectionSummary | `AmbassadorCollectionSummaryDto` | `dateFrom?`, `dateTo?`, `branchId?` |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| CreateAmbassadorCollection | `AmbassadorCollectionRequestDto` | int (new ID) |
| UpdateAmbassadorCollection | `AmbassadorCollectionRequestDto` | int |
| DeleteAmbassadorCollection | `ambassadorCollectionId` | int (discourage — prefer Void) |
| ToggleAmbassadorCollection | `ambassadorCollectionId` | int |
| **ApproveAmbassadorCollection** | `ambassadorCollectionId` | int |
| **FlagAmbassadorCollection** | `{ ambassadorCollectionId, flagReason }` | int |
| **VoidAmbassadorCollection** | `{ ambassadorCollectionId, voidReason }` | int |
| **BulkApproveAmbassadorCollections** | `[int]` ids | int (count approved) |

**AmbassadorCollectionResponseDto** (what FE receives — full field list):

| Field | Type | Notes |
|-------|------|-------|
| ambassadorCollectionId | number | PK |
| branchId | number | FK |
| branchName | string | joined |
| ambassadorContactId | number | FK |
| ambassadorContactName | string | joined (Contact.displayName) |
| collectedDate | string (ISO date) | — |
| collectedTime | string (ISO time "HH:mm") | nullable |
| contactId | number | FK (donor) |
| contactDisplayName | string | joined |
| contactPhone | string | joined (for mini-card) |
| contactAddress | string | joined |
| contactTypeId | number? | optional FK |
| donationAmount | number | — |
| currencyId | number | FK |
| currencyCode | string | joined |
| paymentModeId | number | FK |
| paymentModeName | string | joined |
| donationPurposeId | number | FK (MasterData) |
| donationPurposeName | string | joined (MasterData.dataName) |
| campaignId | number? | FK |
| campaignShortDescription | string? | joined |
| receiptBookId | number? | FK |
| receiptBookBookNo | string? | joined |
| receiptNumber | string | — |
| receiptType | string | "Manual" / "Digital" |
| deliveryMethod | string? | enum-as-string |
| chequeNumber | string? | conditional |
| chequeDate | string? (ISO) | conditional |
| bankId | number? | FK |
| bankName | string? | joined |
| visitNotes | string? | — |
| location | string? | — |
| receiptPhotoPath | string? | — |
| isRecurringCommitment | boolean | — |
| recurringFrequency | string? | — |
| recurringExpectedAmount | number? | — |
| status | string | "Pending" / "Verified" / "Flagged" / "Voided" / "Gap" (virtual) |
| flagReason | string? | — |
| voidReason | string? | — |
| approvedByStaffId | number? | FK |
| approvedByStaffName | string? | joined |
| approvedDate | string? (ISO) | — |
| isActive | boolean | inherited |
| createdBy | string | inherited (audit) |
| createdDate | string | inherited |
| modifiedBy | string? | inherited |
| modifiedDate | string? | inherited |

**AmbassadorCollectionSummaryDto**:

| Field | Type |
|-------|------|
| monthToDateCount | number |
| monthToDateAmountBase | number |
| pendingCount | number |
| pendingBackDatedCount | number |
| pendingHighValueCount | number |
| averageAmount | number |
| medianAmount | number |
| gapCount | number |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (after migration applied)
- [ ] `dotnet ef database update` — migration applies cleanly
- [ ] `pnpm dev` — page loads at `/[lang]/crm/fieldcollection/collectionlist`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] 4 KPI widgets render with correct values from `GetAmbassadorCollectionSummary`
- [ ] Grid loads 12 columns: receipt#, date, ambassador, donor, amount, currency, mode, purpose, campaign, book, status, actions
- [ ] Row-select checkbox + select-all work; bulk-actions bar appears when ≥1 selected
- [ ] Bulk Approve Selected → confirms → mutates → widgets + grid refresh
- [ ] Filters work individually and combined: search-text, ambassador, branch, date range, payment mode, status, min/max amount
- [ ] Gap rows render with dark-red "Gap: #XXXX missing" badge and Investigate-only action
- [ ] Row hover effect; status-colored badges match mockup colors
- [ ] Row-level action button respects status: Verified→Receipt, Pending→Approve, Flagged→Review, Voided→none
- [ ] 3-dot dropdown: View Details / Edit / Void (danger) / Print Receipt + Send Digital Receipt (SERVICE_PLACEHOLDER toasts)
- [ ] `?mode=new` — empty 6-section form, all sections expanded, accordion toggles work
- [ ] Payment Mode cards: selecting Cheque reveals Cheque sub-form (Number/Bank/Date); selecting non-Cheque hides it
- [ ] Donor select: searchable, chooses contact → Donor Mini Card renders with avatar + phone + address + last-donation + since-year + preferred-purpose badge
- [ ] Quick Add Contact button renders + opens modal (or toast if contact mini-create not available)
- [ ] Receipt Book select cascades Receipt Number placeholder / helper "auto-suggested"
- [ ] Back-date warning banner appears when CollectedDate < today − 7 days
- [ ] Recurring toggle reveals Frequency + Expected Amount fields
- [ ] Photo upload dashed box renders (SERVICE_PLACEHOLDER toast on click if file infra absent)
- [ ] Receipt Delivery cards: default WhatsApp; all 4 options selectable
- [ ] Save → POST → `?mode=read&id={newId}` → detail renders
- [ ] Save & New → POST → toast → stays on `?mode=new` with reset form
- [ ] `?mode=read&id=X` — 2-column detail layout (Collection Info / Payment / Receipt / Notes on LEFT; Donor Info / Audit Trail / Status&Workflow on RIGHT) — NOT disabled form
- [ ] Detail header actions: Edit, Print Receipt, Send Receipt (placeholders), Approve/Review/Void per status
- [ ] Approve/Flag/Void mutations update status in-place, audit trail grows
- [ ] Edit button → `?mode=edit&id=X` → form pre-filled
- [ ] Uniqueness validation: duplicate ReceiptNumber within same book → server error surfaced in toast
- [ ] FK dropdowns load via ApiSelectV2 for Ambassador, Branch, Donor, Campaign, Receipt Book, Payment Mode, Donation Purpose, Currency, Bank
- [ ] Unsaved-changes dialog on dirty form back/cancel
- [ ] Role gating: BUSINESSADMIN sees all actions; lower roles don't see Approve/Void

**DB Seed Verification:**
- [ ] Menu "Collection List" visible under CRM → Field Collection (OrderBy 3)
- [ ] GridFormSchema is SKIP (FLOW)
- [ ] MasterData rows for DONATIONPURPOSE + RECURRINGFREQUENCY present

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **CompanyId is NOT a field** on the form — FLOW pulls tenant from HttpContext server-side. DTO does carry it but the form never shows it.
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it.
- **view-page.tsx handles ALL 3 modes** — new/edit share FORM layout (React Hook Form), read has a **completely different DETAIL layout** (2-column cards, audit, workflow panel). Do NOT wrap the form in `<fieldset disabled>`.
- **Entity is NOT named `FieldCollection`** — it is `AmbassadorCollection` at the BE, but the user-facing UI name + route is "Field Collection"/`collectionlist`. Keep the BE name to avoid breaking the existing working `ambassadorcollection` route.
- **Two FE routes share the same entity**:
  - `crm/fieldcollection/ambassadorcollection` → already implemented; screen #67 (Ambassador → "Record Collection" entry view). **DO NOT TOUCH** beyond extending the shared `AmbassadorCollectionDto.ts` / `AmbassadorCollectionQuery.ts` / `AmbassadorCollectionMutation.ts`.
  - `crm/fieldcollection/collectionlist` → **THIS SCREEN (#65)**. Currently a STUB `<div>Need to Develop</div>`. Build from scratch as an admin FLOW list + form + detail.
- **Ambassador entity resolution**: PSS has no standalone `Ambassador` entity. The mockup's "Ambassador" dropdown is a `Contact` filtered by `ContactType.ContactTypeName = 'Ambassador'`. Solution Resolver / BA must confirm this filter approach; fallback is `Staff` if contact-type filtering proves brittle.
- **Legacy fields to drop**: `DonationTypeNo` (int) and `DonationTypeDate` (DateTime) currently exist on the entity and appear unused in FE today. Recommend dropping in the migration. BA to confirm there are no dependent consumers (grep GRAND-wide for `DonationTypeNo`/`DonationTypeDate` before dropping).
- **Receipt-gap detection** is NOT a per-row aggregation — it's virtual rows injected into the paginated response server-side by scanning each `ReceiptBook`'s issued `[ReceiptStartNo..ReceiptEndNo]` range against the actual `ReceiptNumber`s recorded in the date/filter window. Return the gap row with `status = "Gap"` + descriptive subtitle in `flagReason` or a new `gapMessage` field. Document this in the GetAll handler with a clear comment — easy to miss.
- **Status column uses string values**, not a MasterData FK. Decision: simple enum-as-string — values `Pending` / `Verified` / `Flagged` / `Voided` / `Gap` (virtual). Enforce with validator + UI enum.
- **For ALIGN scope**: only modify existing BE files — do not regenerate from scratch. Run `dotnet ef migrations add ExtendAmbassadorCollection` after entity changes, review the generated migration, then apply.
- **Campaign display field is `shortDescription`** (confirmed — no `campaignName` field on the entity). FE should use `shortDescription` with `campaignCode` fallback.
- **Contact GQL query is `GetContacts`** (not `GetAllContactList` as the generic template suggested). Likewise `GetCampaigns`, `GetStaffs`, `GetBranches`, `GetPaymentModes`, `GetMasterDatas`, `GetCurrencies`, `GetBanks`, `GetReceiptBooks` — all verified against real endpoints.
- **The existing `ambassadorcollection` FE view-page** can serve as a template for view-page.tsx wiring patterns (store, RHF setup, 3-mode router) — but its form layout is DIFFERENT from the 6-section accordion described in §⑥ and should NOT be copy-pasted.

**Service Dependencies** (UI-only — no backend service implementation):

- **⚠ SERVICE_PLACEHOLDER — "Send Digital Receipt" (row-level + bulk + detail header)**: Full UI built (buttons, dropdown, bulk bar). Handler uses toast because the SMS/Email/WhatsApp receipt-delivery service layer is not yet wired. Track the chosen `deliveryMethod` on the record regardless.
- **⚠ SERVICE_PLACEHOLDER — "Print Receipt"**: Full button + dropdown entries; handler opens window.print() on a minimal template OR toasts "Printing pipeline not yet wired" — FE dev's choice.
- **⚠ SERVICE_PLACEHOLDER — "Bulk Import"**: Header button renders; handler toasts "Bulk import coming soon". Do NOT build file-parse pipeline.
- **⚠ SERVICE_PLACEHOLDER — "Quick Add Contact"**: Button renders. If a reusable Contact-create mini-modal exists, wire to it; if not, toast "Open Contact → Create" with a link.
- **⚠ SERVICE_PLACEHOLDER — "Receipt Photo Upload"**: File-upload dashed area renders. If a file-upload primitive + backend pipeline exists, wire it to ReceiptPhotoPath. If not, toast "Photo upload pipeline not yet wired" (keep the field in the DTO so future wiring doesn't require a migration).
- **⚠ SERVICE_PLACEHOLDER — "Auto-suggest next receipt number"**: On Receipt Book select, attempt to call `GetNextReceiptNumber(receiptBookId)`. If BE helper doesn't exist, leave placeholder and show helper text instead of calling.

Full UI must be built (buttons, cards, bulk bar, workflow modals, mini-card, conditional sub-forms). Only the external-service call sites are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — no issues raised yet) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}
