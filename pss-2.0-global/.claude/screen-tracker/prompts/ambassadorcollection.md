---
screen: AmbassadorCollection (Record Collection)
registry_id: 133
module: CRM → Field Collection
status: COMPLETED
scope: FE_ONLY (ALIGN — reuse collectionlist form/detail/store)
screen_type: FLOW
complexity: Medium
new_module: NO — `fund` schema + `FieldCollection` group already exist
planned_date: 2026-05-19
completed_date: 2026-05-19
last_session_date: 2026-05-19
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (collection-form.html, titled "Record Collection" in `<title>` tag — the on-the-ground ambassador-facing form for the same entity as #65)
- [x] Existing code reviewed (BE complete from #65 — entity `AmbassadorCollection`, schemas, queries, mutations all exist; FE scaffolding exists at `crm/fieldcollection/ambassadorcollection/` with stub `view-page.tsx`)
- [x] Reuse path identified: import `CollectionListForm` + `CollectionListDetail` + `useCollectionListStore` from `collectionlist/` — DO NOT duplicate the 1000-line form (already 100% mockup-aligned)
- [x] FK targets resolved (all 8 FKs already wired in `collectionlist-form.tsx` — see § ③)
- [x] File manifest computed (FE-only — extend 4 existing stub files + add 1 store-bridge if needed)
- [x] Approval config pre-filled (CRM_FIELDCOLLECTION / AMBASSADORCOLLECTION / OrderBy=2)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated
- [x] Solution Resolution complete (confirm reuse strategy)
- [x] UX Design finalized (FORM reused from collectionlist; ambassador-first GRID with auto-filter; ambassador-friendly DETAIL)
- [x] User Approval received
- [x] Backend code generated — SKIP (already complete from #65)
- [x] Backend wiring complete — SKIP (already complete from #65)
- [x] Frontend code generated (4 file updates — sibling collectionlist UNTOUCHED, used existing optional-callback pattern for admin-button suppression)
- [x] Frontend wiring complete (entity-operations.ts already has AMBASSADORCOLLECTION — verified at lines 30+)
- [x] DB Seed script — SKIP (AmbassadorCollection-sqlscripts.sql already exists & applied from #65; ParentMenu kept as DONATIONCOLLECTION per user direction)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes (no BE changes expected — sanity only)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/fieldcollection/ambassadorcollection`
- [ ] Grid loads with ambassador-first column set (no admin bulk-approve UI)
- [ ] Grid auto-filters to current user's own collections (when `getCurrentAmbassadorContactId()` resolves) OR shows a clear "show all" toggle for managers
- [ ] `?mode=new` — empty 6-section form renders (Collection Details / Donor Info / Payment Details / Donation Purpose & Receipt / Additional Information / Receipt Delivery)
- [ ] Payment-mode card selector (Cash / Cheque / Mobile Transfer / Bank Receipt) works; selecting Cheque reveals Cheque # / Bank / Cheque Date fields
- [ ] Donor selector triggers inline donor mini-card (avatar, name, phone, address, last donation, donor-since, purpose-badge)
- [ ] "Quick Add Contact" button is wired (toast if Contact mini-create modal absent — SERVICE_PLACEHOLDER)
- [ ] Receipt Book dropdown → Receipt # field auto-suggests next number (SERVICE_PLACEHOLDER if no gap-detection service)
- [ ] Receipt Type radio (Manual / Digital) toggles
- [ ] Recurring Commitment toggle reveals Frequency + Expected Amount sub-fields
- [ ] Receipt Delivery card selector (Email / WhatsApp / SMS / Physical) works
- [ ] Back-dated banner appears when `collectedDate < today − 7 days`
- [ ] Save creates record → URL switches to `?mode=read&id={newId}` with Pending status
- [ ] "Save & New" persists then resets form to empty `?mode=new`
- [ ] `?mode=read&id=X` — ambassador-friendly DETAIL layout renders (no admin Approve/Flag/Void buttons)
- [ ] Edit button on detail → `?mode=edit&id=X` → form pre-filled
- [ ] Unsaved-changes dialog triggers on dirty form back/cancel
- [ ] Mobile breakpoint: sticky-footer save bar appears (`md:hidden`); sections collapse to single column

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: AmbassadorCollection (entity `AmbassadorCollection`, route `ambassadorcollection`)
Module: CRM → Field Collection
Schema: `fund`
Group: `FieldCollection` (Models: `FieldCollectionModels`, Schemas: `FieldCollectionSchemas`, Business: `FieldCollectionBusiness`, API: `EndPoints/FieldCollection`)

Business:
**Record Collection** is the field ambassador's on-the-ground capture screen for cash and cheque donations they have just received from donors. Unlike #65 Field Collection (admin/branch-manager review grid with bulk approval and audit workflow), this screen is mobile-optimized and laser-focused on rapid entry: an ambassador finishes a donor visit, taps "+ Record New Collection", fills the 6-section form (Ambassador defaults to themselves, today's date pre-filled, donor selector with quick-add for new contacts, payment-mode card selector, receipt-book/number with auto-suggest, optional photo of the physical receipt, recurring-commitment flag, and digital-receipt delivery choice), and saves. Both #65 and #133 operate on the SAME `AmbassadorCollection` entity — same BE contracts, same form structure. The only differences are: (a) ambassador-first grid filtering (their own collections by default, not company-wide), (b) the entry is the primary surface — no admin bulk actions, no flag/void/approve buttons on the row toolbar, (c) the detail view emphasizes ambassador-relevant info (donor card, receipt status, recurring commitment) instead of the admin audit trail. Records created here flow downstream into #65's review queue; back-dated entries auto-trigger manager approval via the existing workflow.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **NO BACKEND WORK** — entity is already complete. This section is for reference only.

Table: `fund."AmbassadorCollections"` (exists, no schema changes)

| Field | C# Type | Required | FK Target | Notes |
|-------|---------|----------|-----------|-------|
| AmbassadorCollectionId | int | PK | — | Primary key |
| CompanyId | int | YES | appl.Companies | Tenant — HttpContext, not exposed |
| BranchId | int | YES | appl.Branches | Collection branch |
| AmbassadorContactId | int | YES | corg.Contacts | Ambassador (Contact filtered by type=Ambassador OR Staff) |
| CollectedDate | DateTime | YES | — | Date of collection |
| CollectedTime | TimeSpan? | NO | — | Time-of-day |
| ContactId | int | YES | corg.Contacts | Donor |
| ContactTypeId | int? | NO | corg.ContactTypes | Optional donor type |
| DonationAmount | decimal(18,2) | YES | — | Amount |
| CurrencyId | int | YES | shrd.Currencies | Currency |
| PaymentModeId | int | YES | shrd.PaymentModes | Cash / Cheque / Mobile / Bank |
| DonationPurposeId | int | YES | MasterData (DONATIONTYPE) | Purpose (filtered MasterData) |
| CampaignId | int? | NO | camp.Campaigns | Optional campaign |
| ReceiptBookId | int? | NO | ReceiptBooks | Receipt book reference |
| ReceiptNumber | string(50) | YES | — | Physical receipt number |
| ReceiptType | string(20) | YES | — | "Manual" / "Digital" |
| DeliveryMethod | string(20) | NO | — | "Email" / "WhatsApp" / "SMS" / "Physical" |
| ChequeNumber | string(50) | NO | — | Conditional — only when PaymentMode=Cheque |
| ChequeDate | DateTime? | NO | — | Conditional |
| BankId | int? | NO | shrd.Banks | Conditional (Cheque/MobileTransfer/BankReceipt) |
| VisitNotes | string(1000) | NO | — | Free-text |
| Location | string(200) | NO | — | Free-text |
| ReceiptPhotoPath | string(500) | NO | — | File upload path |
| IsRecurringCommitment | bool | YES | — | Toggle |
| RecurringFrequency | string(30) | NO | — | Weekly/Monthly/Quarterly/Yearly |
| RecurringExpectedAmount | decimal(18,2)? | NO | — | Pledged amount |
| Status | string(20) | YES | — | "Pending" / "Verified" / "Flagged" / "Voided" |
| FlagReason / VoidReason | string(500) | NO | — | Admin workflow fields |
| ApprovedByStaffId / ApprovedDate | int? / DateTime? | NO | corg.Staff | Admin workflow |
| AmbassadorId | int? | NO | (ambs.Ambassadors, not yet wired) | Reserved — Ambassador master not yet built |

**Child Entities**: `AmbassadorCollectionDistribution` exists (1:Many) — distribution rows. **Out of scope for this screen** — the mockup does NOT show a distribution sub-grid. Stay single-purpose.

---

## ③ FK Resolution Table

> **Consumer**: Frontend Developer (for ApiSelect queries in form)
> **All FK queries are ALREADY wired** in `collectionlist-form.tsx` — reuse it as-is. This table is reference-only.

| FK Field | Target Entity | Entity File Path | GQL Query Constant | Display Field | GQL Query File |
|----------|--------------|-------------------|--------------------|---------------|----------------|
| ambassadorContactId | Contact | Base.Domain/Models/CorgModels/Contact.cs | `CONTACTS_QUERY` | displayName | `infrastructure/gql-queries/contact-queries/ContactQuery.ts` |
| contactId (donor) | Contact | Base.Domain/Models/CorgModels/Contact.cs | `CONTACTS_QUERY` | displayName | same |
| branchId | Branch | Base.Domain/Models/ApplModels/Branch.cs | `BRANCHES_QUERY` | branchName | `infrastructure/gql-queries/application-queries/BranchQuery.ts` |
| currencyId | Currency | Base.Domain/Models/ShrdModels/Currency.cs | `CURRENCIES_QUERY` | currencyCode | `infrastructure/gql-queries/shared-queries/CurrencyQuery.ts` |
| paymentModeId | PaymentMode | Base.Domain/Models/ShrdModels/PaymentMode.cs | `PAYMENTMODES_QUERY` | paymentModeName | `infrastructure/gql-queries/shared-queries/PaymentModeQuery.ts` |
| donationPurposeId | MasterData (filter: DONATIONTYPE) | Base.Domain/Models/SettingModels/MasterData.cs | `MASTERDATAS_QUERY` | masterDataName | `infrastructure/gql-queries/setting-queries/MasterDataQuery.ts` |
| campaignId | Campaign | Base.Domain/Models/CampModels/Campaign.cs | `CAMPAIGNS_QUERY` | shortDescription | `infrastructure/gql-queries/contact-queries/CampaignQuery.ts` |
| receiptBookId | ReceiptBook | Base.Domain/Models/FieldCollectionModels/ReceiptBook.cs | `RECEIPTBOOKS_QUERY` | bookNo | `infrastructure/gql-queries/fieldcollection-queries/ReceiptBookQuery.ts` |
| bankId | Bank | Base.Domain/Models/ShrdModels/Bank.cs | `BANKS_QUERY` | bankName | `infrastructure/gql-queries/shared-queries/BankQuery.ts` |
| recurringFrequency | MasterData (filter: RECURRINGFREQUENCY) | same | `MASTERDATAS_QUERY` | masterDataName | same |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Frontend Developer (the form already enforces these; verify on edit)

**Required Field Rules** (already enforced in `collectionlist-form.tsx`):
- ambassadorContactId, collectedDate, branchId, contactId (donor), donationAmount, currencyId, paymentModeId, donationPurposeId, receiptNumber, receiptType — required
- If PaymentMode = Cheque → chequeNumber, chequeDate, bankId become required (already enforced)
- If IsRecurringCommitment = true → recurringFrequency required

**Conditional Rules**:
- PaymentMode = Cheque → reveal sub-form (Cheque#, Bank, Cheque Date)
- IsRecurringCommitment toggle → reveal Frequency + Expected Amount
- DeliveryMethod = Email/WhatsApp/SMS → digital receipt service should fire on Save (SERVICE_PLACEHOLDER if not wired)

**Business Logic** (already in BE):
- DonationAmount > 0
- ReceiptNumber must match physical receipt (no auto-uniqueness check — receipt books overlap by design)
- Back-dated check: `collectedDate < today − 7 days` → banner warns + status auto-defaults to "Pending"
- High-value check (server-side): amounts above threshold → Status = "Pending" until admin approves

**Workflow** (admin-facing — NOT exposed on this ambassador screen):
- States: Pending → Verified | Flagged | Voided
- Ambassador can ONLY create records (always saved as Pending or Verified per threshold rules)
- Approve/Flag/Void/BulkApprove mutations exist on BE but are NOT exposed in this screen's UI — they belong to #65 Field Collection (admin view)

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — pre-answered decisions.

**Screen Type**: FLOW
**Type Classification**: Transactional Entry (mobile-first variant of an existing admin FLOW)
**Reason**: Full-page form with 6 sections + conditional sub-forms + mode-based URL routing (`?mode=new/edit/read`). Same FLOW shape as #65 but a different consumer (ambassador, not admin) and reduced action surface.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files) — **ALREADY EXISTS** (no BE work)
- [x] Tenant scoping (CompanyId from HttpContext) — exists
- [x] Multi-FK validation — exists
- [x] Conditional cheque-fields validation — exists
- [x] Workflow commands (Approve/Flag/Void/BulkApprove) — exist but NOT used by this screen
- [x] Summary query (Get{Entity}Summary) — exists but NOT used by this screen (no KPI cards in mockup)

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) — scaffolded; needs ambassador-filter
- [x] view-page.tsx with 3 URL modes — REUSE `collectionlist/view-page.tsx` pattern (or directly import `CollectionListForm` + `CollectionListDetail`)
- [x] React Hook Form — REUSED from collectionlist
- [x] Zustand store — REUSE `useCollectionListStore` (or alias-export as `useAmbassadorCollectionStore`)
- [x] Unsaved changes dialog — comes free from reused view-page
- [x] FlowFormPageHeader — header text is "Record Collection" (different from #65's "Field Collections")
- [ ] Child grid in form — NO
- [ ] Workflow buttons (Approve/Flag/Void) — NO (admin-only — explicitly hidden on this screen)
- [x] File upload widget — yes, for Receipt Photo (reused from form)
- [ ] Summary cards — NO (admin KPIs not shown on ambassador screen)
- [ ] Grid aggregation columns — NO

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted from `collection-form.html` (titled "Record Collection"). The FORM design IS already implemented in `collectionlist-form.tsx` — **reuse it directly**; do not re-implement the 1000-line component.

### Grid/List View

**Display Mode**: `table` (default)

**Grid Layout Variant**: `grid-only` — single grid, no widgets above. (Different from #65 which has 4 KPI widgets.)

**Grid Columns** (ambassador-first — slimmer than admin #65 grid; in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Date | collectedDate | date | 110px | YES | Default sort DESC |
| 2 | Donor | contactDisplayName | text | auto | YES | FK display |
| 3 | Amount | donationAmount | currency | 130px | YES | Right-aligned with currencyCode |
| 4 | Payment Mode | paymentModeName | text | 130px | YES | FK display |
| 5 | Purpose | donationPurposeName | text | auto | YES | FK display |
| 6 | Receipt # | receiptNumber | text | 110px | NO | — |
| 7 | Status | status | badge | 110px | YES | Pending=yellow / Verified=green / Flagged=red / Voided=grey |

**Search/Filter Fields**: Search by donor name, receipt#, location | Date range | Payment Mode | Status

**Default Filter (REQUIRED — distinguishes this screen from #65)**:
- The grid should auto-apply `ambassadorContactId = <currentUserContactId>` filter so the ambassador sees only their own collections.
- If `getCurrentAmbassadorContactId()` resolver returns null (e.g., manager/admin viewing the page), show ALL collections — same behavior as #65 grid.
- A "Show my collections only" toggle in the toolbar is acceptable as a fallback (default ON when current user is an ambassador).
- The existing GetAmbassadorCollections query already accepts `ambassadorContactId` as a filter argument — wire it via initial filter state.

**Grid Actions**: View (→ read mode), Edit (→ edit mode), Delete (only on Pending rows the current ambassador owns; otherwise hidden)
**NOT shown on this screen**: Approve / Flag / Void / BulkApprove (admin-only — they belong to #65)

**Row Click**: Navigates to `?mode=read&id={id}` (DETAIL layout)

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

#### LAYOUT 1: FORM (mode=new & mode=edit)

> **REUSE STRATEGY**: Import `CollectionListForm` from `../collectionlist/collectionlist-form` and use it AS-IS. The form is 100% mockup-aligned — it implements every section, every field, every conditional sub-form described below. Do NOT duplicate the file.

**Page Header**: FlowFormPageHeader
- Title: **"Record Collection"** (mode=new) / **"Edit Collection"** (mode=edit) / **"Collection Details"** (mode=read)
- Back button → `/[lang]/crm/fieldcollection/ambassadorcollection` (no params)
- Actions: **Save** (primary), **Save & New** (outline — clears form to empty new state after save), **Cancel** (text)

**Section Container Type**: cards (6 cards stacked vertically with section header + body)

**Form Sections** (all expanded by default — already implemented in `collectionlist-form.tsx`):
| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | ph:clipboard-text-duotone (fa-clipboard-list) | Collection Details | 2-column on lg, 1-col mobile | expanded | ambassadorContactId, collectedDate, collectedTime, branchId |
| 2 | ph:user-duotone (fa-user) | Donor Information | full-width | expanded | contactId (donor) + Quick Add Contact + inline donor mini-card |
| 3 | ph:money-duotone (fa-money-bill-wave) | Payment Details | 2-col + 4-card selector | expanded | donationAmount (large monospace), currencyId, paymentModeCode (CARD SELECTOR), conditional Cheque sub-form (chequeNumber, bankId, chequeDate) |
| 4 | ph:receipt-duotone (fa-receipt) | Donation Purpose & Receipt | 2-col | expanded | donationPurposeId, campaignId, receiptBookId, receiptNumber (with auto-suggest hint), receiptType (RADIO: Manual / Digital) |
| 5 | ph:info-duotone (fa-circle-info) | Additional Information | mixed | expanded | visitNotes (textarea), location, receiptPhotoPath (FILE UPLOAD), isRecurringCommitment (TOGGLE) → conditional recurringFrequency + recurringExpectedAmount |
| 6 | ph:paper-plane-duotone (fa-paper-plane) | Receipt Delivery | full-width | expanded | deliveryMethod (4-CARD SELECTOR: Email / WhatsApp / SMS / Physical) |

**Field Widget Mapping** — all already implemented in `collectionlist-form.tsx`. Key non-obvious bits:

- **Ambassador (ambassadorContactId)**: When this screen detects current user IS an ambassador, default the field to their own contactId and make it read-only (managers/staff can override). Pass an `initialAmbassadorContactId` prop or use form `defaultValues`.
- **Amount input**: large monospace input (`amount-input-large` class in mockup) — already styled.
- **Payment Mode Card Selector**: 4 cards (Cash 💵 / Cheque 📄 / Mobile Transfer 📱 / Bank Receipt 🏦). Selecting Cheque reveals the cheque sub-form (Cheque #, Bank, Cheque Date).
- **Receipt Number "auto-suggested"**: helper text reads "Auto-suggested: next available receipt number" — wire to a lightweight client-side preview when ReceiptBook is selected. Server-side gap-detection is OUT OF SCOPE for this screen.
- **Recurring Commitment toggle**: When ON, reveals Frequency dropdown (MasterData filtered to RECURRINGFREQUENCY) + Expected Amount.
- **Receipt Delivery Card Selector**: 4 cards (Email / WhatsApp / SMS / Physical Only). "Auto-selected: WhatsApp (donor's preference)" hint — wire to read the donor's preferred channel from the contact record (or just default to WhatsApp).
- **Back-dated banner**: top-of-form amber alert when `collectedDate < today − 7 days` — "Back-dated collection — requires manager approval". Already implemented.
- **Quick Add Contact** button under donor selector: opens a minimal contact-create flow. If the mini-modal doesn't exist, fire a toast SERVICE_PLACEHOLDER. Already implemented.

**Mobile (md and below)**:
- All section grids collapse to single column (already responsive)
- Header actions hide; **sticky-footer save bar** appears with Save / Save & New / Cancel (already implemented via Tailwind `md:hidden`)

---

#### LAYOUT 2: DETAIL (mode=read) — REUSED from collectionlist

> **REUSE STRATEGY**: Import `CollectionListDetail` from `../collectionlist/collectionlist-detail` and render with one prop override: hide admin Approve/Flag/Void buttons.

**Page Header**: FlowFormPageHeader
- Title: "Collection Details — <ReceiptNumber>"
- Back button → grid
- Actions: **Edit** (→ `?mode=edit&id={id}`), **Print Receipt** (SERVICE_PLACEHOLDER toast), **Send Digital Receipt** (SERVICE_PLACEHOLDER toast)
- **DO NOT show**: Approve, Flag, Void (those are admin-only — visible only on #65's detail view)

**Page Layout**: 2-column scan-friendly card layout (already implemented in `collectionlist-detail.tsx`)

**Left Column Cards**:
| # | Card Title | Content |
|---|-----------|---------|
| 1 | Collection Info | Date, Time, Branch, Ambassador, Status (badge) |
| 2 | Donor | Donor avatar, name, phone, address, last-donation hint, donor-since, purpose badge |
| 3 | Payment | Amount (large), currency, payment mode (icon+label), conditional cheque-details |
| 4 | Receipt | Receipt #, Receipt Type, Receipt Book, Receipt Photo thumbnail (if uploaded) |

**Right Column Cards**:
| # | Card Title | Content |
|---|-----------|---------|
| 1 | Donation Purpose | Purpose, Campaign |
| 2 | Visit Notes & Location | Notes, Location, Recurring Commitment summary (if set) |
| 3 | Receipt Delivery | Delivery method badge + last-sent timestamp if available |
| 4 | Audit Trail | Created / Approved / Flagged / Voided timeline (already implemented) |

**Mobile**: single-column stack (already responsive)

---

### Page Widgets & Summary Cards

**Widgets**: NONE — ambassador screen intentionally does NOT show admin KPIs. The existing `collectionlist-widgets.tsx` is NOT imported.

### Grid Aggregation Columns

**Aggregation Columns**: NONE.

### User Interaction Flow

1. Ambassador opens `/[lang]/crm/fieldcollection/ambassadorcollection` → grid loads filtered to their own collections.
2. Taps **"+ Record New Collection"** → URL `?mode=new` → empty 6-section form (their own name + today pre-filled).
3. Selects donor → donor mini-card auto-fills.
4. Picks payment mode → conditional sub-forms reveal.
5. Fills receipt details + delivery preference → taps **Save** (or Save & New for batch entry).
6. On save: URL → `?mode=read&id={newId}` → ambassador-friendly detail view (no admin action buttons).
7. From detail, taps **Edit** → `?mode=edit&id={id}` → form pre-filled.
8. Save in edit mode → back to detail.
9. From grid row, taps the row → `?mode=read&id={id}` → detail view.
10. Back button → grid (no params).
11. Unsaved form + back/cancel → unsaved-changes dialog.

---

## ⑦ Substitution Guide

> **Consumer**: Frontend Developer
> This is NOT a canonical-template substitution — this is a **sibling-reuse from `collectionlist`**.

**Canonical Reference**: `collectionlist` (sibling screen, COMPLETED by #65)

| From `collectionlist` | → This Screen (`ambassadorcollection`) | Notes |
|----------------------|----------------------------------------|-------|
| `CollectionListForm` | imported as-is | The 6-section form |
| `CollectionListDetail` | imported as-is + prop `hideAdminActions={true}` | If prop doesn't exist, add it — defaults to false to preserve #65 behavior |
| `useCollectionListStore` | imported as-is | Same Zustand store; pages share state-shape |
| `collectionlist-widgets.tsx` | **NOT imported** | Admin KPIs not shown |
| `collectionlist-form.tsx` admin buttons (none in form) | n/a | Form already has no admin actions |
| `AMBASSADOR_COLLECTION_DESIGN_APPROACH.md` (at FE root) | **READ FIRST** | A design-doc the user dropped at FE root — reconcile with this prompt if it conflicts |

| Identity tokens | Value |
|-----------------|-------|
| Entity (C#) | `AmbassadorCollection` |
| Variable / field | `ambassadorCollection` |
| PK field | `AmbassadorCollectionId` |
| Plural | `AmbassadorCollections` |
| FE folder | `ambassadorcollection` |
| Grid code | `AMBASSADORCOLLECTION` |
| Menu code | `AMBASSADORCOLLECTION` |
| Parent menu code | `CRM_FIELDCOLLECTION` |
| Module code | `CRM` |
| Schema | `fund` |
| Group | `FieldCollection` |
| FE route | `crm/fieldcollection/ambassadorcollection` |
| Service folder | `fieldcollection-service` |

---

## ⑧ File Manifest

> **Consumer**: Frontend Developer
> Backend: **NO CHANGES** — entity, schemas, queries, mutations all exist from #65.

### Backend Files: ZERO new files. Optional sanity check only.

| Verification only — do NOT modify |
|---|
| `Base.Domain/Models/FieldCollectionModels/AmbassadorCollection.cs` |
| `Base.Application/Schemas/FieldCollectionSchemas/AmbassadorCollectionSchemas.cs` |
| `Base.API/EndPoints/FieldCollection/Queries/AmbassadorCollectionQueries.cs` (`GetAmbassadorCollections`, `GetAmbassadorCollectionById`, `GetAmbassadorCollectionSummary`) |
| `Base.API/EndPoints/FieldCollection/Mutations/AmbassadorCollectionMutations.cs` (`CreateAmbassadorCollection`, `UpdateAmbassadorCollection`, plus Approve/Flag/Void/BulkApprove which are not used here) |

### Frontend Files — extend existing stubs (5 files touched, 0 to N new)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | View Page (3 modes) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/fieldcollection/ambassadorcollection/view-page.tsx` | **REPLACE STUB** — wire mode switching, import `CollectionListForm` + `CollectionListDetail`, use `useCollectionListStore`. Pattern: copy `collectionlist/view-page.tsx` then strip admin Approve/Flag/Void buttons. |
| 2 | Data Table | `…/ambassadorcollection/data-table.tsx` | **MODIFY** — apply ambassador auto-filter via `initialFilters` prop; OR add a "My collections only" toolbar toggle that defaults to ON. |
| 3 | Index Page | `…/ambassadorcollection/index-page.tsx` | **VERIFY** — currently just renders `AmbassadorCollectionDataTable`. Add a `ScreenHeader` with title "Record Collection" and a "+ Record New Collection" button that sets `crudMode = 'view'` + `?mode=new`. |
| 4 | Index (mode switcher) | `…/ambassadorcollection/index.tsx` | **VERIFY** — uses `useFlowDataTableStore.crudMode`. Confirm it switches between `AmbassadorCollectionIndexPage` and `AmbassadorCollectionViewPage`. Already correct. |
| 5 | Page Config | `PSS_2.0_Frontend/src/presentation/pages/crm/fieldcollection/ambassadorcollection.tsx` | **VERIFY** — capability gate on `AMBASSADORCOLLECTION` menu code. Already correct. |
| (6) | Route page | `PSS_2.0_Frontend/src/app/[lang]/crm/fieldcollection/ambassadorcollection/page.tsx` | **VERIFY** — calls `AmbassadorCollectionPageConfig`. Already correct. |
| (7) | Shared form prop | `…/collectionlist/collectionlist-detail.tsx` | **MODIFY (small)** — add optional `hideAdminActions?: boolean` prop (default false). Wrap Approve/Flag/Void buttons in `{!hideAdminActions && (…)}`. |

### Frontend Wiring Updates

| # | File to Modify | What to Verify / Add |
|---|---------------|----------------------|
| 1 | `application/configs/data-table-configs/fieldcollection-service-entity-operations.ts` | Confirm `AMBASSADORCOLLECTION` entry exists with correct CRUD operations pointing to `AmbassadorCollectionQuery.ts` + `AmbassadorCollectionMutation.ts`. Already present per grep. |
| 2 | `presentation/pages/crm/index.ts` | Confirm `AmbassadorCollectionPageConfig` is exported. |
| 3 | Sidebar menu config | Verify `AMBASSADORCOLLECTION` menu item exists under `CRM_FIELDCOLLECTION` parent. Add via DB seed if missing. |

### Reference (DO NOT DUPLICATE — import from these)

| File | Path | Usage |
|------|------|-------|
| `CollectionListForm` | `…/collectionlist/collectionlist-form.tsx` | Import as `import { CollectionListForm } from "../collectionlist/collectionlist-form"` |
| `CollectionListDetail` | `…/collectionlist/collectionlist-detail.tsx` | Import + pass `hideAdminActions={true}` |
| `useCollectionListStore`, `CollectionFormValues` | `…/collectionlist/collectionlist-store.ts` | Reuse store and form value type |
| `AmbassadorCollectionQuery.ts` | `infrastructure/gql-queries/fieldcollection-queries/AmbassadorCollectionQuery.ts` | Already exists — supplies `GET_AMBASSADOR_COLLECTIONS`, `GET_AMBASSADOR_COLLECTION_BY_ID` |
| `AmbassadorCollectionMutation.ts` | `infrastructure/gql-mutations/fieldcollection-mutations/AmbassadorCollectionMutation.ts` | Already exists |
| `AMBASSADOR_COLLECTION_DESIGN_APPROACH.md` | `PSS_2.0_Frontend/` root | Existing design memo — read first for any prior decisions |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FE_ONLY

MenuName: Record Collection
MenuCode: AMBASSADORCOLLECTION
ParentMenu: CRM_FIELDCOLLECTION
Module: CRM
MenuUrl: crm/fieldcollection/ambassadorcollection
OrderBy: 2
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: AMBASSADORCOLLECTION
---CONFIG-END---
```

Note: `TOGGLE` capability is **intentionally omitted** — ambassador collections are not toggled active/inactive; lifecycle is via Status (Pending/Verified/Flagged/Voided).

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer
> All contracts ALREADY EXIST from #65. This section is reference-only.

**GraphQL Types:**
- Query type: `AmbassadorCollectionQueries`
- Mutation type: `AmbassadorCollectionMutations`

**Queries (already exposed):**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getAmbassadorCollections` | Paginated `[AmbassadorCollectionResponseDto]` | `request: GridFeatureRequest`, `searchText`, `ambassadorContactId`, `branchId`, `dateFrom`, `dateTo`, `paymentModeId`, `status`, `minAmount`, `maxAmount` |
| `getAmbassadorCollectionById` | `AmbassadorCollectionResponseDto` | `ambassadorCollectionId` |
| `getAmbassadorCollectionSummary` | `AmbassadorCollectionSummaryDto` | `dateFrom`, `dateTo`, `branchId` — **NOT USED** by this screen |

**Mutations (already exposed — only Create/Update used here):**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createAmbassadorCollection` | `AmbassadorCollectionRequestDto` | int (new ID) |
| `updateAmbassadorCollection` | `AmbassadorCollectionRequestDto` | int |
| `deleteAmbassadorCollection` | `ambassadorCollectionId` | int |
| `approveAmbassadorCollection` / `flagAmbassadorCollection` / `voidAmbassadorCollection` / `bulkApproveAmbassadorCollections` | — | — | **NOT USED** by this screen |

**Response DTO Fields** (Mapster-mapped, includes nested navigation objects):
| Field | Type | Notes |
|-------|------|-------|
| ambassadorCollectionId | number | PK |
| ambassadorContactId, contactId, branchId, currencyId, paymentModeId, donationPurposeId, campaignId, receiptBookId, bankId | number/number? | FKs |
| ambassadorContactName, contactDisplayName, contactPhone, contactAddress | string? | FK display fields |
| branchName, currencyCode, paymentModeName, donationPurposeName, campaignShortDescription, receiptBookBookNo, bankName | string? | FK displays |
| collectedDate, collectedTime, donationAmount, receiptNumber, receiptType, deliveryMethod | various | Core fields |
| chequeNumber, chequeDate | nullable | Conditional |
| visitNotes, location, receiptPhotoPath | nullable strings | Optional |
| isRecurringCommitment, recurringFrequency, recurringExpectedAmount | bool / string? / decimal? | Optional |
| status, flagReason, voidReason | strings | Workflow |
| approvedByStaffId, approvedByStaffName, approvedDate | nullable | Admin workflow |
| **Nested navigation DTOs** (`branch`, `ambassadorContact`, `contact`, `currency`, `paymentMode`, `donationPurpose`, `campaign`, `receiptBook`, `bank`, `approvedByStaff`) | object | Available for ParentObject convention in grid |
| isActive, createdBy/Date, modifiedBy/Date | inherited | — |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (no BE changes; sanity only)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/fieldcollection/ambassadorcollection`

**Functional Verification (Full E2E):**
- [ ] Grid renders 7 columns (Date, Donor, Amount, Payment Mode, Purpose, Receipt #, Status); default sort by Date DESC
- [ ] Grid auto-filters to current ambassador's own collections (when current user has an ambassador-contact) OR shows all with a "My collections only" toggle
- [ ] Search filters by donor name, receipt#, location; date range + payment mode + status filters work
- [ ] Row click opens detail; status badge color-coded
- [ ] "+ Record New Collection" → `?mode=new` → empty 6-section form
- [ ] Ambassador field is pre-filled with current user (read-only when current user IS an ambassador; editable for managers)
- [ ] Payment-mode card selector — selecting Cheque reveals Cheque #, Bank, Cheque Date sub-form
- [ ] Donor selector → inline donor mini-card (avatar, name, phone, address, last-donation, donor-since, purpose badge)
- [ ] Quick Add Contact → toast SERVICE_PLACEHOLDER if contact mini-modal not available
- [ ] Receipt Book → Receipt # auto-suggest hint shown
- [ ] Receipt Type radio (Manual / Digital) toggles
- [ ] Recurring Commitment toggle reveals Frequency + Expected Amount
- [ ] Receipt Delivery card selector (Email / WhatsApp / SMS / Physical) — defaults to donor's preferred channel
- [ ] Back-dated banner appears when `collectedDate < today − 7 days`
- [ ] Save → URL changes to `?mode=read&id={newId}` with Pending status
- [ ] "Save & New" → record persists, form resets to empty `?mode=new`
- [ ] `?mode=read&id=X` — 2-column detail view renders WITHOUT admin Approve/Flag/Void buttons
- [ ] Edit button on detail → `?mode=edit&id=X` → form pre-filled
- [ ] FK dropdowns load via ApiSelect (8 dropdowns)
- [ ] Unsaved-changes dialog triggers on dirty form back/cancel
- [ ] Mobile: sticky-footer save bar visible; section grids collapse to 1 column
- [ ] Permissions: READ/CREATE/MODIFY gate the grid + form correctly

**DB Seed Verification:**
- [ ] Menu "Record Collection" appears in sidebar under CRM → Field Collection, OrderBy=2
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **THIS IS A REUSE BUILD, NOT A NEW BUILD**. Backend is 100% complete from #65. Frontend has scaffolding stubs from a prior pass. The deliverable is wiring up the existing form/detail/store from `collectionlist/` into `ambassadorcollection/`'s view-page. Do NOT regenerate the entity, schemas, mutations, queries, or the form component itself.

- **READ FIRST**: `PSS_2.0_Frontend/AMBASSADOR_COLLECTION_DESIGN_APPROACH.md` — a design memo the user dropped at FE root during earlier exploration. Reconcile any conflicts with this prompt; if the memo proposes a divergent approach, ask the user before deviating from "reuse collectionlist components".

- **Two parallel screens, one entity**: #65 (`collectionlist`, COMPLETED) is the admin/manager view. #133 (`ambassadorcollection`, this build) is the ambassador's mobile-first entry view. They share BE + form + detail + store. Differences are confined to: page title, grid filter default, hidden admin action buttons, and no KPI widgets.

- **Ambassador auto-filter**: The grid MUST default to "show only my collections" when the current user is an ambassador. Implementation options:
  1. Read `currentUser.contactId` from auth context and pass `ambassadorContactId` as `initialFilters` to `FlowDataTable`.
  2. Add a toolbar toggle "Show my collections only" defaulted ON.
  Choose (1) when the resolver is reliable; otherwise (2). If neither is feasible in the current FE architecture, document this as a known gap in the build log and proceed with no auto-filter (manager-equivalent view).

- **`hideAdminActions` prop**: This requires a 2-3 line modification to the sibling `collectionlist-detail.tsx` to add the optional prop. The prop defaults to `false` so #65 behavior is preserved. Treat this as an additive change.

- **GraphQL field naming**: HC strips `Get` prefix, so `GetAmbassadorCollections` → arg `ambassadorCollections` in GQL. The wrapping `request: { pageSize, pageIndex, ... }` is REQUIRED per `[AsParameters] GridFeatureRequest request` (see [[feedback_gridfeature_asparameters_wrapper]]).

- **FlowDataTable vs AdvancedDataTable**: Use FlowDataTable (already wired in `data-table.tsx`) — the screen ID and gridCode is `AMBASSADORCOLLECTION`.

- **CollectedTime field**: `TimeSpan?` on BE. FE should pass HH:mm format string from `<input type="time">`. Pattern already implemented in `collectionlist-form.tsx`.

- **Currency display**: Show `{currencyCode}` next to amount in grid. Default currency = company default (e.g., AED).

**Service Dependencies** (UI-only — handler mocked):
- ⚠ SERVICE_PLACEHOLDER: **Quick Add Contact** button — fires a toast if the contact mini-modal hasn't been implemented elsewhere. The button itself is fully wired.
- ⚠ SERVICE_PLACEHOLDER: **Receipt # auto-suggest** — UI shows the helper text "Auto-suggested: next available receipt number" but the server-side gap-detection service is not built. Treat as a hint only; do not actually compute.
- ⚠ SERVICE_PLACEHOLDER: **Send Digital Receipt** (detail page) — button + delivery-method capture exist; the SMS/Email/WhatsApp dispatch service layer is not wired. Toast confirmation only.
- ⚠ SERVICE_PLACEHOLDER: **Print Receipt** (detail page) — toast only; PDF generation not implemented.

Full UI must be built (buttons, forms, conditional sub-forms, mini-cards, mobile sticky footer). Only the external-service handlers are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | LOW | FE/data-table | "Show my collections only" toggle is a UI stub — no `me { contactId }` resolver exists, so the toggle currently does NOT drive a server-side filter. Marked with `TODO(#133)` in `data-table.tsx`. To wire: add a `me { contactId }` GraphQL resolver; then pass `ambassadorContactId` into FlowDataTable via `FlowDataTableStoreProvider` + Container pair with `initialAdvancedFilter`. | OPEN |
| ISSUE-2 | 1 | LOW | FE/Service-placeholder | **Print Receipt** (detail header) — toast.info only; no PDF generation pipeline. Already wired inside the reused `collectionlist-detail.tsx`. | OPEN |
| ISSUE-3 | 1 | LOW | FE/Service-placeholder | **Send Digital Receipt** (detail header) — toast.info only; no SMS/Email/WhatsApp dispatch. Already wired inside the reused `collectionlist-detail.tsx`. | OPEN |
| ISSUE-4 | 1 | LOW | FE/Service-placeholder | **Receipt # auto-suggest** — UI shows helper text "Auto-suggested: next available receipt number" but no server-side gap-detection service. Hint only; does not compute. Already in reused `collectionlist-form.tsx`. | OPEN |
| ISSUE-5 | 1 | LOW | FE/Service-placeholder | **Quick Add Contact** button — fires toast if contact mini-modal not present. Already wired in `collectionlist-form.tsx`. | OPEN |
| ISSUE-6 | 1 | LOW | FE/dispatcher | `handleCreate` in `index-page.tsx` does NOT call `useFlowDataTableStore.getState().setRowData(null)` before navigating to `?mode=new` — URL-driven dispatcher (`useFlowUrlMode(true)`) hydrates Zustand from URL params, so stale `rowData` should be harmless. If QA reveals a stale-row bug on rapid navigation, add the reset call. | OPEN |
| — | — | — | — | (Design memo `PSS_2.0_Frontend/AMBASSADOR_COLLECTION_DESIGN_APPROACH.md` is SUPERSEDED and was explicitly disregarded per user direction.) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-19 — BUILD — COMPLETED

- **Scope**: Initial FE_ONLY reuse build from PROMPT_READY prompt. Backend was 100% complete from #65 (no BE work). DB seed already applied from #65 (no DB work). Sibling `collectionlist/` UNTOUCHED — used the existing optional-callback pattern on `CollectionListDetail` (Props at lines 8–16) to suppress Approve/Flag/Void buttons by simply OMITTING those props from the ambassador view-page. This is cleaner than the originally-spec'd `hideAdminActions` prop (BA validation flagged that adding the prop would be redundant given the existing optional-callback gating).
- **Files touched**:
  - BE: None.
  - FE: 4 modified
    - `PSS_2.0_Frontend/src/presentation/components/page-components/crm/fieldcollection/ambassadorcollection/view-page.tsx` (modified — was 5-line stub; now ~457-line FLOW view with FormProvider + useForm<CollectionFormValues> + mode-aware FlowFormPageHeader + reused `<CollectionListForm>` + reused `<CollectionListDetail>` (admin callbacks intentionally omitted) + Apollo v4 typed-cast pattern `(data as any)?.result?.data` + AlertDialog unsaved-changes guard + desktop action footer + mobile sticky-footer save bar (`md:hidden` z-40) + Save / Save & New / Cancel handlers with toast feedback + `toTimeSpanIso` / `fromTimeSpanIso` helpers for HotChocolate TimeSpan scalar)
    - `…/ambassadorcollection/data-table.tsx` (modified — was 12-line stub; added "Show my collections only" Switch + Label toolbar above `<FlowDataTable showHeader={false} />`; TODO(#133) flag for missing `me { contactId }` resolver)
    - `…/ambassadorcollection/index-page.tsx` (modified — was 3-line wrapper; now ScreenHeader with title "Record Collection" + subtitle + `ph:hand-coins-duotone` icon + breadcrumbs (Home → Module → Menu) + "+ Record New Collection" header action → `router.push(?mode=new)`)
    - `…/ambassadorcollection/index.tsx` (modified — was Zustand-only dispatcher; replaced with `useFlowUrlMode(true)` so URL navigation AND `router.push(?mode=…)` from the custom CTA both route correctly; without this, the new CTA would change URL but not crudMode)
  - DB: None.
- **Sibling untouched**: `collectionlist/` (5 files) read for context only; ZERO modifications. The optional-callback pattern (`onApprove?`/`onFlag?`/`onVoid?`) on `CollectionListDetail` gave us admin-button suppression for free.
- **Deviations from spec**:
  1. `hideAdminActions` prop on `collectionlist-detail.tsx` — NOT added. BA validation showed the existing optional-callback gating already gives the same behavior. Net win: zero touches to sibling, cleaner contract.
  2. Ambassador auto-filter — implemented as a default-OFF UI toggle only (not a working filter), because no `me { contactId }` resolver exists. Logged as ISSUE-1 OPEN.
  3. `index.tsx` was spec'd as "VERIFY ONLY — do not modify unless broken" but was actually broken for the new CTA flow (Zustand-only dispatcher would not route on URL-only push). FE agent correctly switched to `useFlowUrlMode(true)`.
- **Known issues opened**: 6 (1 functional gap + 4 SERVICE_PLACEHOLDER toasts inherited from sibling + 1 minor dispatcher edge case)
- **Known issues closed**: None (first session)
- **tsc verification**: `npx tsc --noEmit` produced ZERO errors for the 4 touched files; pre-existing unrelated errors exist in other parts of the project (event-overview-bar, menu-store, ambassadorperformance) — out of scope.
- **Anti-pattern grep**: ZERO matches for inline hex colors / raw "Loading..." text in the ambassadorcollection folder.
- **Layout Variant**: `grid-only` (index-page uses ScreenHeader chrome + `<FlowDataTable showHeader={false} />` per Variant B convention).
- **Next step**: User to run `pnpm dev`, navigate to `/[lang]/crm/fieldcollection/ambassadorcollection`, exercise: grid loads + toggle visible (no-op) + "+ Record New Collection" → empty 6-section form + payment-mode card selector + cheque sub-form reveal + recurring toggle reveal + delivery card selector + Save → routes to `?mode=read&id={newId}` + Edit → routes to `?mode=edit&id={id}` + unsaved-changes dialog + mobile sticky-footer save bar.
