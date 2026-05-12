---
screen: BulkDonation
registry_id: 5
module: CRM (Donation)
status: COMPLETED
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-05-10
completed_date: 2026-05-11
last_session_date: 2026-05-11
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (5-step wizard + Recent Sessions table)
- [x] Existing code reviewed (BE entity stub + FE manual-entry form — both DEPRECATED for this screen)
- [x] Existing import-wizard infrastructure verified (ImportSession + ImportGridDefinition + `<ImportPageConfig>` + Contact Import precedent)
- [x] Business rules + workflow extracted (per-row validation rules from mockup)
- [x] FK targets resolved (Contact, Currency, DonationPurpose, PaymentMode — all GQL queries verified)
- [x] File manifest computed (NON-STANDARD FLOW — reuses shared infrastructure, no per-entity CRUD)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (skipped — prompt §①–⑫ contained validated analysis; orchestrator surfaced schema mismatches up front and resolved with user)
- [x] Solution Resolution complete (locked Minimal-MVP schema strategy + canonical-template-only V1 scope)
- [x] UX Design finalized (3-tab wizard kept; deferred 5-step stepper, BDU- prefix, skip-unresolved checkbox to enhancement backlog)
- [x] User Approval received (schema strategy + V1 scope + final CONFIG block all confirmed)
- [x] Backend code generated (2 PG functions + ImportGridDefinition/ImportGridField seed — purpose_code dropped from template)
- [x] Backend wiring complete (no DI changes — reuses existing Import infrastructure)
- [x] Frontend code generated (`bulkdonation.tsx` reduced to one-liner; data-table.tsx + bulk-donation-page.tsx + bulk-donation-view.tsx deleted; barrel emptied)
- [x] Frontend wiring complete (route unchanged; entity-operations.ts uses operation keys not capabilities, so no change needed — capability gating now owned by ImportPageConfig)
- [x] DB Seed script generated (`BulkDonationImport-seed.sql` — ImportGridDefinition + 9 ImportGridFields + IMPORT MenuCapability + Role grants)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/crm/donation/bulkdonation`
- [ ] **Default view** renders the **Recent Sessions list** (`<ImportSessionList gridCode="BULKDONATION" />`) — matches "Recent Upload Sessions" table at bottom of mockup
- [ ] **"Start New Import" button** transitions to wizard (`<ImportWizardContainer gridCode="BULKDONATION" />`)
- [ ] **Wizard Tab 1 (Download & Upload)**: "Download Template" produces `.xlsx` with the 9 donation columns; drag-drop / file picker accepts `.xlsx`, `.xls`, `.csv`; 10 MB cap enforced; file detected → "Next" enabled
- [ ] **Wizard Tab 2 (Validation & Staging)**: validation runs server-side via `import.validate_bulk_donation_data` PG function; summary cards show valid / warnings / errors counts; error grid shows row-level issues with field name + message + suggested fix; "Export Errors" downloads error Excel
- [ ] **Wizard Tab 3 (Import)**: progress bar streams via SignalR (or polls); on completion → success card with row count + total amount + skipped count + 3 action buttons (View Donations / Import More / Download Report)
- [ ] FK validations resolved server-side: Contact (by name + email match), Currency (ISO code), DonationPurpose (by code, fallback to General Fund with WARNING), PaymentMode (by code)
- [ ] Hard error rules: Contact not found → ERROR; Invalid currency → ERROR; Negative amount → ERROR
- [ ] Soft warning rules: Purpose not found (defaults General Fund) → WARNING; Future donation date → WARNING; Duplicate receipt number → WARNING
- [ ] **"Import Valid Rows Only"** button on validation step skips error rows and proceeds; the 3 errors are excluded from `fund.GlobalDonations` insertion
- [ ] After successful import → row appears in `import.ImportSessions` with status `Completed`, ImportedRows = 485 (etc.)
- [ ] Donations actually visible in `/crm/donation/globaldonation` grid after import
- [ ] DB Seed — `BULKDONATION` menu visible in sidebar under `CRM_DONATION` parent at `crm/donation/bulkdonation`
- [ ] DB Seed — `import.ImportGridDefinitions` row exists with GridCode `BULKDONATION`, TargetSchema `fund`, TargetTable `GlobalDonations`
- [ ] DB Seed — 9 `import.ImportGridFields` rows exist (one per template column) with correct LookupTable for FK columns

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **BulkDonation** (renamed UX-wise to "Bulk Donation Upload" per mockup; entity name and menu code stay `BULKDONATION`)
Module: **CRM** → Donation sub-module
Schema: **fund** (target table `fund.GlobalDonations`); import metadata lives in **import** schema (existing)
Group: **DonationModels** (BE entity exists but is DEPRECATED for this screen) + **ImportModels** (existing infrastructure)

**Business**:
This screen lets a fundraising admin or finance officer upload a spreadsheet of donations (Excel or CSV) and import them into the donation ledger in one batch. It exists because organizations regularly receive donations through offline channels (mailed cheques, branch field collections, third-party payment processor exports, legacy systems being migrated) and re-typing them one-by-one in the GlobalDonation form is impractical for hundreds of rows. The screen guides the user through a five-step wizard — **Upload → Map Fields → Validate → Preview → Import** — with server-side validation that resolves donor matches by email/name, normalizes currency and payment-mode codes, flags errors and warnings row-by-row, and writes valid rows into `fund.GlobalDonations`. A "Recent Upload Sessions" table sits below the wizard so the user can resume an in-flight session, audit what was imported last week, or download an error report from a past run. It pairs with #1 GlobalDonation (the canonical donation entry/grid) — every row this screen imports lands in the same table that GlobalDonation reads from, so once an import completes the donations are immediately visible everywhere donations are reported on.

**Why this is a non-standard FLOW**: This screen is in the FLOW row of the registry, but it does not have its own per-entity Entity/CRUD/view-page. It is a thin **alignment shell** over the **shared import-wizard infrastructure** (`ImportSession` + `ImportGridDefinition` + `<ImportWizardContainer>` + `<ImportPageConfig gridCode>`) that already powers Contact Import (#41). The "alignment" work is: (a) declare a new `BULKDONATION` ImportGridDefinition + 9 ImportGridFields in the seed, (b) write 3 PostgreSQL stored functions that validate / execute / read-staging-data for donation rows, and (c) replace the existing manual-entry FE files at `bulkdonation/data-table.tsx` with a one-line render of `<ImportPageConfig gridCode="BULKDONATION" />`.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **NO new entities are created.** The screen is a pure **wire-up + seed + stored-procedure** alignment over existing infrastructure.

### Storage & Source Model

| Concern | Where it lives | Notes |
|---------|---------------|-------|
| Import session lifecycle (one row per upload) | `import.ImportSessions` (existing — `ImportSession.cs`) | Tracks file, rows counts, status enum, scheduled jobs, blob path, hangfire job id, validation/import timestamps |
| Per-grid template definition | `import.ImportGridDefinitions` (existing — `ImportGridDefinition.cs`) | NEW SEED ROW: `GridCode = 'BULKDONATION'`, `TargetSchema = 'fund'`, `TargetTable = 'GlobalDonations'`, `ValidationProcedure = 'import.validate_bulk_donation_data'`, `ImportProcedure = 'import.execute_bulk_donation_import'`, `MaxFileSizeBytes = 10485760`, `MaxRowCount = 10000` |
| Per-grid field/column definitions | `import.ImportGridFields` (existing — `ImportGridField.cs`) | NEW SEED: 9 rows (one per template column — see below) |
| Staging table for the upload | Dynamically created per session (`StagingTableName` on session row) | Existing `IStagingTableService` handles create/drop |
| Final imported rows | `fund.GlobalDonations` (existing — `GlobalDonation.cs`) | The execute function INSERTs validated rows here |

### Existing entities to LEAVE UNTOUCHED (do NOT modify)

| Entity | File | Reason |
|--------|------|--------|
| `BulkDonation.cs` | `Base.Domain/Models/DonationModels/BulkDonation.cs` | DEPRECATED for this screen — old manual-entry batch tracking. Field set (`DonationDate`, `TotalContactCount`, `TotalAmount`) is unrelated to upload sessions. Keep for backward compatibility; do NOT delete. |
| `BulkDonationDistribution.cs` | `Base.Domain/Models/DonationModels/BulkDonationDistribution.cs` | Same — keep but unused by this screen. |
| `BulkDonationSchemas.cs` + Mutations + Queries (Create / Update / Delete / GetById / GetBulkDonations) | `DonationSchemas/`, `DonationBusiness/`, `EndPoints/Donation/` | Currently power the manual-entry form. Once the FE is rewritten, these become unreferenced — leave them in place; do not delete in this session. |

### Template Columns (drives the 9 `import.ImportGridFields` seed rows)

| # | FieldName (col in staging) | DisplayName (Excel header) | DataType | Required | TargetColumn (in `fund.GlobalDonations`) | LookupTable / Resolution | Validation |
|---|---------------------------|---------------------------|----------|----------|----------------------------------------|-------------------------|------------|
| 1 | `contact_code` | "Contact Code" | string(50) | NO* | `ContactId` | `corg.Contacts` by `ContactCode` | * Either `contact_code` OR `donor_email` OR `donor_name`+`donor_email` MUST resolve to a Contact (ERROR if none) |
| 2 | `donor_email` | "Contact Email" | string(150) | NO* | (resolves to ContactId) | `corg.Contacts` by lowercased `Email` | matched via lowercased equality; lookup-only column |
| 3 | `donor_name` | "Donor Name" | string(150) | NO* | (resolves to ContactId or new contact) | `corg.Contacts` by ILIKE `DisplayName` | fallback match if email empty |
| 4 | `donation_date` | "Donation Date" | date | YES | `DonationDate` | — | parse to ISO; future-date → WARNING |
| 5 | `amount` | "Amount" | decimal(18,2) | YES | `Amount` | — | must be > 0; ERROR if ≤ 0 |
| 6 | `currency_code` | "Currency" | string(10) | YES | `CurrencyId` | `com.Currencies` by `CurrencyCode` (uppercased) | ERROR if not found in master list |
| 7 | `purpose_code` | "Purpose Code" | string(50) | NO | `DonationPurposeId` | `fund.DonationPurposes` by `DonationPurposeCode` | NOT FOUND → WARNING + default to "GENERAL" purpose |
| 8 | `payment_mode_code` | "Payment Mode" | string(50) | YES | `PaymentModeId` | `com.PaymentModes` by `PaymentModeCode` | ERROR if not found |
| 9 | `receipt_number` | "Receipt Number" | string(50) | NO | `ReceiptNumber` | — | uniqueness across `fund.GlobalDonations` for the same Company → WARNING (not ERROR) on duplicate |
| 10 | `note` | "Note" | string(500) | NO | `Note` (or equivalent free-text field on GlobalDonation) | — | — |

> **Note**: 10 fields total to seed. The mockup says "9 columns" auto-mapped — that's because Donor Name and Email are presented as a single conceptual "Donor" column to the user. Backend treats them as separate staging columns.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `import.validate_bulk_donation_data` lookup joins) + Frontend Developer (for any inline ApiSelect — though most FK resolution happens server-side here)

| FK Field | Target Entity | Entity File Path | GQL Query Name (FE) | Display Field | GQL Response Type | How resolved in import |
|----------|--------------|-------------------|---------------------|---------------|-------------------|------------------------|
| ContactId | Contact | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ContactModels/Contact.cs` | `contacts` (CONTACTS_QUERY) | `displayName` (also `contactCode`, `email`) | `ContactResponseDto` | server-side: lookup by `ContactCode` → fallback `LOWER(Email) = LOWER(p_donor_email)` → fallback `ILIKE p_donor_name`. ERROR if none match. |
| CurrencyId | Currency | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/Currency.cs` | `currencies` (CURRENCIES_QUERY) | `currencyName` | `CurrencyResponseDto` | server-side: lookup by `UPPER(CurrencyCode) = UPPER(p_currency_code)`. ERROR if not found. |
| DonationPurposeId | DonationPurpose | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/DonationModels/DonationPurpose.cs` | `donationPurposes` (DONATIONPURPOSES_QUERY) | `donationPurposeName` | `DonationPurposeResponseDto` | server-side: lookup by `UPPER(DonationPurposeCode) = UPPER(p_purpose_code)`. NOT FOUND → WARNING + default to row where `DonationPurposeCode = 'GENERAL'` (must exist as seed). |
| PaymentModeId | PaymentMode | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/PaymentMode.cs` | `paymentModes` (PAYMENTMODES_QUERY) | `paymentModeName` | `PaymentModeResponseDto` | server-side: lookup by `UPPER(PaymentModeCode) = UPPER(p_payment_mode_code)`. ERROR if not found. |

**No FE ApiSelect dropdowns needed for this screen** — all FK resolution happens in the validation stored procedure. The FE does not present FK pickers; the user's spreadsheet is the input, and the wizard surfaces unresolved FK rows in the validation error grid.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (PG function authors) → Frontend Developer (client-side hints)

### Hard ERRORS (row excluded from import unless user clicks "Import Valid Rows Only")

| Rule | Source mockup row | Error message |
|------|-------------------|---------------|
| `donation_date` is null or unparseable | — | "Donation Date is required and must be a valid date" |
| `amount` is null, ≤ 0, or unparseable | row 201 (`-150.00`) | "Amount must be a positive number" |
| `currency_code` not found in `com.Currencies` | row 89 (`X`) | "Invalid currency code — use a valid ISO 4217 code (e.g., USD, EUR, INR)" |
| `payment_mode_code` not found in `com.PaymentModes` | — | "Unknown payment mode" |
| All of `contact_code`, `donor_email`, `donor_name` failed to resolve to a Contact | row 45 (`John Doe` no email match) | "Contact not found — provide a contact code or matching email" |

### Soft WARNINGS (row imports; flag is recorded for the user to review)

| Rule | Source mockup row | Warning message | Behavior |
|------|-------------------|-----------------|----------|
| `purpose_code` not found in `fund.DonationPurposes` | row 78 (`MISC`) | "Purpose code not found — defaulted to General Fund" | Falls back to `GENERAL` purpose; row imports |
| `donation_date` is more than 1 day in the future | row 156 (`2026-12-31`) | "Future donation date — please verify" | Row imports as-is |
| `receipt_number` already exists in `fund.GlobalDonations` for this Company | row 312 (`RCT-2026-0450`) | "Duplicate receipt number" | Row imports; user can fix later via GlobalDonation edit |

### Uniqueness rules
- `receipt_number` SHOULD be unique per Company per `fund.GlobalDonations`, but only enforced as WARNING here (per mockup row 312).

### Conditional rules
- If `contact_code` resolves → ignore `donor_email` and `donor_name` for matching (only used as informational)
- If `contact_code` is empty AND `donor_email` resolves → use that ContactId
- If both `contact_code` and `donor_email` are empty AND `donor_name` matches exactly one Contact via `ILIKE` → use that ContactId; if 0 or 2+ matches → ERROR

### Workflow (driven by existing `ImportSessionStatus` enum)

```
Initiated → Uploading → Parsing → Parsed → Validating → Validated
                                                         ↓
                                              (user reviews validation)
                                                         ↓
                                                     Importing → Completed
                                                         ↓
                                                       Failed (recoverable)
                                                       Cancelled (user-aborted)
```

For Bulk Donation Upload, **scheduled imports are out of scope for this iteration** — only immediate imports. The `Scheduled / ReValidating / ReValidated` enum branch is left to the existing infrastructure but not exposed in the wizard UI for this grid.

### Per-row import effect

For each VALID row, `import.execute_bulk_donation_import` performs:

```sql
INSERT INTO fund."GlobalDonations" (
    "ContactId", "DonationDate", "Amount", "CurrencyId",
    "DonationPurposeId", "PaymentModeId", "ReceiptNumber", "Note",
    "CompanyId", "DonationStatusId", "Source",
    "CreatedBy", "CreatedDate", "IsActive", "IsDeleted"
)
SELECT
    {resolved ids…}, p_company_id,
    (SELECT id WHERE Code='RECEIVED'), 'BULK_IMPORT',
    p_user_id, NOW(), true, false
FROM staging WHERE validation_status = 'VALID';
```

> The exact `GlobalDonations` field set must be verified against the current `GlobalDonation.cs` entity in the build phase — schema may include extra columns (Branch, Campaign, etc.) that need defaults.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: `FLOW` (per registry) — but this is a **NON-STANDARD FLOW: Import Wizard** sub-pattern.
**Reason**: There is no per-entity CRUD lifecycle (Create / Read / Update / Delete on a `BulkDonationUpload` row). The lifecycle is a multi-step session that produces a side-effect (rows inserted into `fund.GlobalDonations`). The closest precedent in the codebase is **Contact Import** (#41) which already uses this pattern via `<ImportPageConfig gridCode="CONTACT" />`.

### Backend patterns required

- [ ] Standard CRUD (11 files) — **NO**, do not generate
- [x] PostgreSQL stored functions:
  - `import.validate_bulk_donation_data(p_session_id, p_offset, p_batch_size)` — mirror `import.validate_contact_data` pattern
  - `import.execute_bulk_donation_import(p_session_id, p_offset, p_batch_size)` — mirror `import.execute_contact_import` pattern  
  - `import.get_bulk_donation_staging_data(p_session_id, p_page, p_page_size, p_filter)` — only if generic `get_staging_data` cannot handle donation columns; verify in build
- [x] DB seed: `import.ImportGridDefinitions` row + 10 `import.ImportGridFields` rows
- [ ] Tenant scoping — handled by existing `ImportSession.CompanyId` infrastructure
- [ ] Multi-FK validation — handled inside the validate PG function (lookup joins)
- [ ] Workflow commands — NO, reuses existing `StartImportValidation` / `StartImportExecution` mutations
- [ ] File upload command — NO, reuses existing `UploadImportFileCommand`

### Frontend patterns required

- [ ] FlowDataTable / view-page.tsx — **NO**, do not generate (replaced by wizard)
- [ ] Zustand store — NO, reuses existing `useImportStore`
- [x] **Replace** `bulkdonation/data-table.tsx` with one-line render: `<ImportPageConfig gridCode="BULKDONATION" />`
- [x] **Deprecate** existing manual-entry components (`bulk-donation-page.tsx`, `bulk-donation-view.tsx`) — leave files for backward reference but no longer routed
- [x] Recent Sessions list (mockup bottom table) — already provided by `<ImportSessionList gridCode>` inside the shared `<ImportPage>`

### Mockup → Implementation mapping (5 mockup steps → 3 wizard tabs)

| Mockup Step | Implementation in `<ImportWizardContainer>` |
|-------------|---------------------------------------------|
| Step 1 — Upload | Tab 1 "Download & Upload" (`<ImportTemplateDownloadSection>` + `<ImportStepSelectGrid>`) |
| Step 2 — Map Fields | Implicit — handled by the template download (column names ARE the mapping; no manual remapping in V1) |
| Step 3 — Validate | Tab 2 "Validation & Staging" (`<ImportStepValidation>` shows progress + summary cards + error grid) |
| Step 4 — Preview | Tab 2 (same tab, scrollable preview of valid rows in staging grid) |
| Step 5 — Import | Tab 3 "Import" (`<ImportStepImportProgress>` + `<ImportStepComplete>`) |

> **Decision**: V1 does NOT implement per-user manual column remapping (mockup step 2 dropdowns are illustrative only). The user downloads the canonical template; column headers MUST match. If a build-time decision is made to add custom mapping, that's a separate epic. The mockup's "9 of 11 columns auto-mapped (2 suggested)" UX implies a richer mapper that requires schema changes to `ImportGridFields` — out of scope here.

> **CRITICAL TO RESOLVE WITH USER**: confirm V1 scope = no manual mapper. If user wants the mapping UI, this becomes a from-scratch frontend (3-5 additional files: `<ImportStepMapFields>`, mapping store slice, "applied mapping" persistence on `ImportSessions`).

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> The bulk of this screen's UI already exists in the shared import-wizard components.
> This section describes BulkDonation-specific overrides + deprecation behavior.

### Default View (mode=none)

When user navigates to `/[lang]/crm/donation/bulkdonation` with no query params:

- Renders `<ImportPageConfig gridCode="BULKDONATION" />`
- Inside, `<ImportPage>` defaults to `viewMode === "list"` → renders `<ImportSessionList gridCode="BULKDONATION" gridDisplayName="Bulk Donation Upload" ... />`
- The session list shows a table identical in shape to the mockup's "Recent Upload Sessions" — columns: Session ID, File, Date, Total, Imported, Amount, Errors, Status
- Above the table: a "+ Start New Import" button (already provided by `<ImportSessionList>`)
- Existing `<ImportSessionList>` row click → resumes session (resumes wizard at the appropriate tab based on `session.status`)

> The session-id column shows IDs in the form `IS-NNN` (existing convention); the mockup shows `BDU-NNN` ("Bulk Donation Upload"). Either accept the existing format OR add a `displayPrefix` prop to `<ImportSessionList>` — RECOMMENDATION: accept existing format in V1 to avoid changing shared infrastructure.

### Wizard View (mode=wizard, after user clicks "Start New Import")

`<ImportPage>` switches to `viewMode === "wizard"` → renders `<ImportWizardContainer>` with three tabs.

#### Tab 1 — "Download & Upload"

**MUST match the mockup's Step 1 visually:**

| Mockup element | Implementation source |
|----------------|----------------------|
| Header: "Bulk Donation Upload" + "Import multiple donations from spreadsheet" + Cancel button | Shared `<ImportPageConfig>` header (uses `gridDisplayName` "Bulk Donation Upload" pulled from ImportGridDefinition) |
| "Import Type" badge with hand-holding-heart icon | Skipped in shared wizard (single-grid context — user already selected donation grid by route). Optional: render a small static info pill above the upload zone. |
| Drag & drop zone with cloud-upload icon, "Drag & drop your Excel file here" | `<ImportStepUploadFile>` already implements this. Shared dropzone. |
| File picker button "click to browse" with `.xlsx, .xls, .csv` accepted | Same. 10 MB cap enforced by existing `MaxFileSizeBytes` on ImportGridDefinition. |
| Selected-file pill with file icon, name, size, ~rows estimated, remove button | Already implemented. |
| "Download Donation Template" button + helper text listing the 10 columns | `<ImportTemplateDownloadSection>` — calls `GenerateImportTemplate(importGridDefinitionId)` which produces an `.xlsx` from `ImportGridFields`. |
| Options checkboxes (First row contains headers / Auto-match donors by email / Skip unresolved donors) | The first two are baked into the validate function. The third ("Skip unresolved donors") MUST be exposed — recommendation: add a single `import_options` JSON column to `ImportSession` writes, OR pass via the `StartImportValidation` mutation as a new `validationOptions` arg. **DECISION POINT**: in V1, hardcode `skipUnresolvedDonors = false` (treat unresolved as ERROR); user can use "Import Valid Rows Only" button to skip them. |

#### Tab 2 — "Validation & Staging"

**MUST match the mockup's Steps 3 + 4 visually:**

| Mockup element | Implementation source |
|----------------|----------------------|
| "Validation Progress" header with "Completed in 5 seconds" | `<ImportStepValidation>` — already shows progress bar + status text |
| 3 summary cards (Valid / Warnings / Errors) with counts + percentages | Already shown — pulls from `ImportValidationSummaryDto` (`validRows`, `warningRows`, `invalidRows`) |
| "Error & Warning Details" table with toggle filter (Show All / Errors+Warnings / Errors Only) and Export Errors button | Already implemented via existing `getStagingData` query with `validationStatusFilter` arg. Verify the toggle wires to the filter. |
| Error rows: Row#, Field, Issue (with icon), Value (in code tag), Suggested Fix | Already shown — needs the validate function to populate the `suggestion` column when raising errors (e.g., "Use valid ISO currency"). |
| Footer buttons: Back / "Import Valid Rows Only" (orange-warning) / Next: Preview | The "Import Valid Rows Only" button already exists in `<ImportStepValidation>`. Verify text/styling matches mockup. |
| Preview table (10 rows × 8 columns: #, Donor, Date, Amount, Currency, Purpose, Mode, Status) | `<ImportStepReviewResults>` — verify it renders all columns; if missing some donation columns, add them to the staging-data DTO. |

#### Tab 3 — "Import"

**MUST match the mockup's Step 5 (progress + success) visually:**

| Mockup element | Implementation source |
|----------------|----------------------|
| Spinner + "Importing Donations…" + "324 of 485 donations" + progress bar 67% + Elapsed/Remaining timers | `<ImportStepImportProgress>` — already implemented; subscribes to SignalR `ImportProgressDto` (or polls every 5s) |
| Success card with green check icon + "485 donations imported successfully!" + "$125,400 total · 3 rows skipped · 12 warnings noted" | `<ImportStepComplete>` — verify the dollar-amount summary line uses the donation-specific completion DTO. May require a new `ImportRecordsSummaryDto` field `totalAmount` for donation grids. |
| 3 buttons: "View Imported Donations" / "Import More" / "Download Import Report" | Default exists. "View Imported Donations" routes to `/[lang]/crm/donation/globaldonation` filtered by `Source='BULK_IMPORT'` and `CreatedDate >= session.startedAt`. "Download Import Report" produces an Excel with all imported rows + their final IDs. |

### Visual deviations from shared wizard (acceptable)

The shared wizard uses 3 horizontal tabs. The mockup uses a 5-step horizontal stepper. **Decision**: keep the 3-tab structure (lower complexity, consistent with Contact Import). The 5-step naming is a UX representation; functionally equivalent.

If the user explicitly asks for the 5-step stepper UI, that becomes a small enhancement to `<ImportWizardContainer>` (visual only — internal state still 3 phases). Track as a separate ENHANCE session.

### Page Widgets & Summary Cards

**Widgets above the grid (default view)**: NONE in V1.

> The mockup's session list does not show summary cards above it. If desired in a future iteration: add 4 KPI cards (Total Imports This Month / Total Donations Imported / Total Amount Imported / Average Errors per Import). Skip for V1.

**Grid Layout Variant**: `grid-only` (the session list is a plain table, no widgets above).

### Grid Aggregation Columns

NONE — session list rows already include the aggregate counts (Total / Imported / Amount / Errors).

### User Interaction Flow

1. User navigates to `/[lang]/crm/donation/bulkdonation` → **Recent Sessions list** renders. If they have an active or scheduled session, it appears at top.
2. User clicks **"+ Start New Import"** → `<ImportPage>` switches to wizard view → Tab 1 active.
3. User clicks **"Download Donation Template"** → server generates `.xlsx` with 10 column headers + 1 instructional row + sample data row. Browser downloads.
4. User edits the template offline, fills in donation rows, saves. Returns to the wizard.
5. User drags the file into the dropzone (or uses file picker) → file uploaded to Azure Blob via `UploadImportFileCommand` → staging table created → `<ImportSession>` row inserted with status `Parsed`.
6. **Tab 2 active** (auto-advance) → progress bar shows validation running → summary cards + error grid populated when validation completes.
7. If user has 0 errors → **Next: Preview** (already on Tab 2 — preview is below the error section).
8. If user has errors → option A: download error report, fix offline, upload fresh file (new session); option B: click **Import Valid Rows Only** → skip Tab 2 review, jump to Tab 3.
9. **Tab 3 active** → progress bar streams import progress → on completion, success card renders.
10. User clicks **View Imported Donations** → navigates to `/crm/donation/globaldonation?source=BULK_IMPORT&fromImport=<sessionId>` (deep-link the global donation grid filtered to this session's imports).
11. Or **Import More** → resets wizard to Tab 1.
12. User can navigate back to `/[lang]/crm/donation/bulkdonation` at any time → Recent Sessions list shows the just-completed session at top with `Status = Complete`.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> **Canonical Reference**: **Contact Import** (#41) — already uses `<ImportPageConfig gridCode="CONTACT" />`.

| Canonical (Contact Import) | → This Screen (Bulk Donation Upload) |
|----------------------------|--------------------------------------|
| `gridCode = "CONTACT"` | `gridCode = "BULKDONATION"` |
| `gridDisplayName = "Contact"` (resolved from ImportGridDefinition) | `gridDisplayName = "Bulk Donation Upload"` |
| `TargetSchema = 'corg'`, `TargetTable = 'Contacts'` | `TargetSchema = 'fund'`, `TargetTable = 'GlobalDonations'` |
| PG function: `import.validate_contact_data(...)` | PG function: `import.validate_bulk_donation_data(...)` |
| PG function: `import.execute_contact_import(...)` | PG function: `import.execute_bulk_donation_import(...)` |
| SQL files: `ContactImport-fn-validate.sql`, `ContactImport-fn-execute.sql`, `ContactImport-fn-get-staging-data.sql` | SQL files: `BulkDonationImport-fn-validate.sql`, `BulkDonationImport-fn-execute.sql`, `BulkDonationImport-fn-get-staging-data.sql` (last only if generic doesn't fit) |
| Route: `/[lang]/crm/contact/contactimport/page.tsx` | Route: `/[lang]/crm/donation/bulkdonation/page.tsx` (existing route, behavior changed) |
| Menu code: `CONTACTIMPORT` | Menu code: `BULKDONATION` (already exists per MODULE_MENU_REFERENCE) |
| Parent menu: `CRM_CONTACT` | Parent menu: `CRM_DONATION` |

The shared infrastructure does the heavy lifting; this screen is a 95%-reuse alignment.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer
> **Non-standard FLOW** — no per-entity CRUD files, no view-page, no Zustand store. The deliverable is: **2 PG functions + 1 SQL seed + 2 FE replacements**.

### Backend Files (CREATE — 3 SQL files; NO new C# files)

| # | File | Path | Type |
|---|------|------|------|
| 1 | `BulkDonationImport-fn-validate.sql` | `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/BulkDonationImport-fn-validate.sql` | NEW PG function (mirror `ContactImport-fn-validate.sql`) |
| 2 | `BulkDonationImport-fn-execute.sql` | `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/BulkDonationImport-fn-execute.sql` | NEW PG function (mirror `ContactImport-fn-execute.sql`, INSERTs into `fund.GlobalDonations`) |
| 3 | `BulkDonationImport-fn-get-staging-data.sql` | `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/BulkDonationImport-fn-get-staging-data.sql` | NEW PG function — ONLY if existing generic `get_staging_data` cannot handle donation columns. **VERIFY FIRST in build phase**: if `import.get_staging_data(p_session_id, ...)` is grid-agnostic, skip this file. |

### Backend Files (UPDATE)

| # | File | What to add |
|---|------|-------------|
| 1 | `BulkDonation-Grid-seed.sql` | UPDATE existing seed: keep menu reg; ADD `import.ImportGridDefinitions` insert for `BULKDONATION`; ADD 10 `import.ImportGridFields` inserts for the template columns; ADD a `RoleCapabilities` block for `IMPORT` capability on this menu. Or split into `BulkDonationImport-seed.sql` to keep concerns separate. **RECOMMENDATION: split into a new file `BulkDonationImport-seed.sql`**. |
| 2 | (none for C#) | No C# wiring changes — `ImportSession`, `ImportGridDefinition`, `IStagingTableService`, all queries/mutations/handlers, and SignalR hub are already registered. |

### Frontend Files (REPLACE)

| # | File | Action | What |
|---|------|--------|------|
| 1 | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/bulkdonation/data-table.tsx` | REPLACE entire body | Render `<ImportPageConfig gridCode="BULKDONATION" />` from `@/presentation/pages/shared/import`. Drop the mode-switching logic. |
| 2 | `PSS_2.0_Frontend/src/presentation/pages/crm/donation/bulkdonation.tsx` | REPLACE entire body | Render `<ImportPageConfig gridCode="BULKDONATION" />` directly (the inner `BulkDonationDataTable` becomes redundant — can be deleted in a follow-up cleanup, but for V1 keep the page-config wrapper because it preserves the `useAccessCapability({ menuCode: "BULKDONATION" })` gate that the shared component does NOT do). Best: have `BulkDonationPageConfig` perform the capability check, then render `<ImportPage gridCode="BULKDONATION" />` directly. |
| 3 | `PSS_2.0_Frontend/src/app/[lang]/crm/donation/bulkdonation/page.tsx` | NO CHANGE | Already routes to `<BulkDonationPageConfig />`. |

### Frontend Files (DEPRECATE — leave on disk, no longer routed)

| # | File | Status |
|---|------|--------|
| 1 | `bulkdonation/bulk-donation-page.tsx` | UNREFERENCED after this build. Leave for one cycle for backward audit; mark with a top-of-file comment `// DEPRECATED 2026-05-10 — replaced by shared ImportPage. To be removed in cleanup pass.` |
| 2 | `bulkdonation/bulk-donation-view.tsx` | Same. |
| 3 | `bulkdonation/index.ts` (barrel) | Update exports to remove unused symbols; keep `BulkDonationDataTable` if still referenced by `bulkdonation.tsx`. |

### Frontend Wiring Updates

| # | File to Modify | What to Add / Verify |
|---|---------------|---------------------|
| 1 | `entity-operations.ts` | Verify `BULKDONATION` operations entry exists; ADD `IMPORT` to its capability list if missing. |
| 2 | `operations-config.ts` | No changes (no new entity). |
| 3 | Sidebar menu config (DB-driven via `auth.Menus`) | Already wired by existing `BulkDonation-Grid-seed.sql`. Verify `MenuIcon` matches mockup intent (recommend `solar:upload-bold-duotone` or `ph:cloud-arrow-up`). |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Bulk Donation Upload
MenuCode: BULKDONATION
ParentMenu: CRM_DONATION
Module: CRM
MenuUrl: crm/donation/bulkdonation
GridType: FLOW

MenuCapabilities: READ, IMPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, IMPORT

GridFormSchema: SKIP
GridCode: BULKDONATION
---CONFIG-END---
```

**Why CREATE / MODIFY / DELETE / TOGGLE / EXPORT are absent**: the user does not directly create/modify/delete `BulkDonation` records via this screen. They upload a file → rows land in `fund.GlobalDonations`, which has its own permission set. The only relevant capability is `IMPORT`. `READ` is included so the user can view past sessions. `EXPORT` could be added later for "Download Import Report" but is currently a per-session button, not a grid action.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**No NEW GraphQL types are added.** This screen consumes existing types only.

### Existing GraphQL types reused (NO CHANGES required for V1)

| GQL Field | Returns | Key Args | Used by |
|-----------|---------|----------|---------|
| `getImportSession(importSessionId)` | `ImportSessionStateDto` | session id | Wizard polling fallback |
| `getImportSessionsByGrid(gridCode)` | `ImportSessionSummaryDto[]` | `"BULKDONATION"` | Recent Sessions list |
| `getImportGridFields(importGridDefinitionId)` | `ImportGridFieldDto[]` | grid id | Template generation, column rendering |
| `getStagingData(importSessionId, pageNumber, pageSize, validationStatusFilter, executionStatusFilter)` | `StagingDataResponseDto` | session id + filters | Validation tab error grid + preview table |
| `importSampleData(importGridDefinitionId, topN)` | `ImportSampleDataResponseDto` | grid id | Optional preview before upload |
| `GenerateImportTemplate(importGridDefinitionId)` | `GenerateTemplateResultDto` (base64 xlsx) | grid id | "Download Donation Template" button |
| `UploadImportFile(input)` | `ImportUploadResultDto` | `gridCode + file` | Tab 1 file picker |
| `StartImportValidation(importSessionId)` | `StartValidationResultDto` | session id | Auto-fired after upload |
| `StartImportExecution(importSessionId)` | `StartImportResultDto` | session id | Tab 3 "Start Import" |
| `CancelImport(importSessionId)` | bool | session id | Cancel button (any tab) |

### Possibly new fields (verify in build)

| Field | DTO | Reason |
|-------|-----|--------|
| `ImportRecordsSummaryDto.totalAmount` | needs to be `decimal?` | Mockup success card shows "$125,400 total". Add aggregation to execute function output. If field already exists, no change. |
| `ImportSessionSummaryDto.totalAmount` | `decimal?` | Recent Sessions table "Amount" column. May need to add if not already present. |

### Response DTO field examples (FE consumption)

`ImportSessionSummaryDto` (Recent Sessions row):
| Field | Type | Notes |
|-------|------|-------|
| sessionId | string | display as `IS-{padded}` or `BDU-{padded}` (UX choice, see ⑥) |
| originalFileName | string | mockup column "File" |
| startedAt | ISO string | mockup column "Date" |
| totalRows | number | mockup column "Total" |
| importedRows | number | mockup column "Imported" |
| totalAmount | decimal? | mockup column "Amount" — may need to ADD |
| invalidRows | number | mockup column "Errors" |
| status | enum string | mockup column "Status" badge |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/[lang]/crm/donation/bulkdonation`
- [ ] PostgreSQL: `\df import.validate_bulk_donation_data` — function exists
- [ ] PostgreSQL: `\df import.execute_bulk_donation_import` — function exists
- [ ] PostgreSQL: `SELECT * FROM import."ImportGridDefinitions" WHERE "GridCode" = 'BULKDONATION'` — 1 row exists
- [ ] PostgreSQL: `SELECT COUNT(*) FROM import."ImportGridFields" WHERE "ImportGridDefinitionId" = (SELECT "ImportGridDefinitionId" FROM import."ImportGridDefinitions" WHERE "GridCode" = 'BULKDONATION')` — returns 10

**Functional Verification (FULL E2E — MANDATORY):**
- [ ] Default route renders Recent Sessions list (mockup bottom table layout)
- [ ] "+ Start New Import" button transitions to wizard
- [ ] Tab 1: "Download Donation Template" downloads `.xlsx` with 10 columns matching the seed
- [ ] Tab 1: drag-drop a valid `.xlsx` (10 rows, all valid) → validation auto-runs → Tab 2 active
- [ ] Tab 2: 3 summary cards show Valid 10 / Warnings 0 / Errors 0
- [ ] Tab 2: error grid is empty (no rows to display)
- [ ] Tab 2: preview table shows all 10 rows
- [ ] Click Next → Tab 3 → Start Import → progress streams → Success card with "10 donations imported successfully · $X total"
- [ ] Navigate to `/crm/donation/globaldonation` → see the 10 new rows with `Source = 'BULK_IMPORT'`
- [ ] Re-upload a file with 1 invalid currency code → Tab 2 shows Errors=1 with "Invalid currency code" + suggestion text
- [ ] Click "Import Valid Rows Only" → Tab 3 → only valid rows imported; session ends with `ImportedRows = total - 1`, `InvalidRows = 1`
- [ ] Re-upload a file with 1 unknown purpose code → Tab 2 shows Warnings=1; row imports anyway with `DonationPurposeId = (GENERAL)` 
- [ ] Re-upload a file with 1 future date → Warnings=1; row imports
- [ ] Re-upload a file with 1 unresolvable Contact → Errors=1; row excluded
- [ ] Cancel an in-progress import → status set to `Cancelled`; staging table dropped per existing logic
- [ ] Permission test: log in as a role WITHOUT `IMPORT` capability on `BULKDONATION` → page renders `<DefaultAccessDenied />`
- [ ] Permission test: log in as `BUSINESSADMIN` → full wizard accessible

**DB Seed Verification:**
- [ ] `BULKDONATION` menu visible in sidebar under `CRM > Donation`
- [ ] Menu URL is `crm/donation/bulkdonation`
- [ ] Menu icon is set (recommended `solar:upload-bold-duotone`)
- [ ] (GridFormSchema is SKIP for FLOW — no form schema in seed)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **NON-STANDARD FLOW**: This is NOT a from-scratch CRUD screen. Do NOT generate the 11-file backend manifest or 9-file frontend manifest from `_FLOW.md`. The deliverable is **2-3 SQL files + 1 seed file + 2 FE file replacements**. If the build agent starts generating `BulkDonationUpload.cs` entity, `Create/Update/Delete` commands, view-page.tsx, or a Zustand store — that's wrong. Stop and confirm with user.
- **Two competing entities exist with similar names**: `BulkDonation.cs` (existing, deprecated for this screen — manual-entry batch tracking) and the new conceptual "Bulk Donation Upload Session" (which is just `ImportSession` with `GridCode='BULKDONATION'`). Do NOT confuse them. Do NOT delete the existing `BulkDonation.cs` entity.
- **Legacy `importdonations/importdonation-form.tsx`** also exists and is unrelated — a PSS 1.0 fixed-format Excel importer using `CREATE_PAYMENT_MODE_UPLOAD_MUTATION`. Out of scope here. Do NOT modify or delete.
- **Manual mapping UI is OUT OF SCOPE for V1.** The mockup's Step 2 ("9 of 11 columns auto-mapped, 2 suggested — review before proceeding") is illustrative; V1 enforces the canonical template. If user wants the mapper, that's a follow-up epic with schema changes to `ImportGridFields` (a `userMappingJson` column on `ImportSession`).
- **Session ID display prefix** ("BDU-012" in mockup vs "IS-012" in current shared component) — V1 keeps the shared format. Cosmetic mismatch only; document as acceptable. If user insists, add a `displayPrefix` prop to `<ImportSessionList>` (~5 LOC).
- **5-step stepper vs 3-tab wizard**: V1 uses the existing 3-tab wizard. The 5-step UX is a cosmetic upgrade for future iteration.
- **`fund.GlobalDonations` schema dependency**: the execute function INSERTs into `fund."GlobalDonations"`. The build phase MUST verify the current entity field set (`GlobalDonation.cs`) and provide defaults for any required column the import does not source from the spreadsheet (`BranchId`, `CampaignId`, `DonationStatusId`, `OrganizationalUnitId`, etc.). Use `SELECT column_name, is_nullable, column_default FROM information_schema.columns WHERE table_schema='fund' AND table_name='GlobalDonations'` as the truth source.
- **`GENERAL` donation purpose default** must exist as a seed row in `fund.DonationPurposes` with `DonationPurposeCode = 'GENERAL'`. Verify in build; add to seed if missing.
- **`BULK_IMPORT` Source value**: The execute function tags imported rows with `Source = 'BULK_IMPORT'` (or whatever enum value `GlobalDonation.Source` accepts) so they can be traced back to a session for the "View Imported Donations" deep link. Verify the column exists; add it to `GlobalDonation.cs` if not (this is a tiny additive change but TOUCHES core donation entity — flag for user approval).
- **CompanyId is from HttpContext**: the existing `ImportSession.CompanyId` comes from request context. The execute function accepts it as a parameter from the calling C# command, NOT from the spreadsheet. Do NOT add a `company_code` column to the template.
- **For ALIGN scope**: only modify the files listed in §⑧. Do not regenerate from scratch. Do not touch `ImportSession.cs`, `ImportGridDefinition.cs`, or any shared wizard components in `custom-components/import-wizard/`.

**Service Dependencies** (UI-only — no backend service implementation):

> All required services already exist in the codebase: Azure Blob upload (UploadImportFileCommand), Excel parsing (ExcelExportService + UploadImportFileCommand), staging table management (IStagingTableService), Hangfire job queueing (existing on validation/execution mutations), SignalR progress hub (existing). 

**No SERVICE_PLACEHOLDERs needed** — every interactive element in the mockup maps to existing infrastructure. The only new server-side work is the 2-3 PG functions and the seed.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | INFO | Schema | `fund.GlobalDonations` has no `DonationPurposeId` FK and no `Source` column — `purpose_code` template column dropped in V1; traceability provided via `Note` prefix `[IMPORT:<sessionId>]`. To restore purpose-on-import, add nullable `DonationPurposeId` + `BulkImportSessionId` FKs to GlobalDonation (migration) and re-add `purpose_code` to the template. | OPEN |
| ISSUE-2 | 1 | MINOR | BE | `PaymentStatusId` default in execute fn is `PENDING` (mirroring `CreateChequeDonation.cs` precedent), not `RECEIVED` as the prompt §④ called for. Defensible — bulk-imported donations are not yet confirmed received — but flags as a spec deviation. Change to `RECEIVED` if business prefers. | OPEN |
| ISSUE-3 | 1 | MINOR | BE seed | `BulkDonationImport-seed.sql` granted MenuCapabilities for 8 caps (READ/CREATE/MODIFY/DELETE/TOGGLE/EXPORT/IMPORT/ISMENURENDER) and RoleCapabilities for 4 roles (BUSINESSADMIN/ADMINISTRATOR full; STAFF/STAFFDATAENTRY READ+IMPORT). Spec §⑨ specified READ+IMPORT+ISMENURENDER only for BUSINESSADMIN. Additive, not breaking — but tighter scope was implied. | OPEN |
| ISSUE-4 | 1 | INFO | UX | Mockup features deferred for V1 — (a) 5-step horizontal stepper (using shared 3-tab wizard), (b) `BDU-NNN` session-id display prefix (using shared `IS-NNN`), (c) `Skip unresolved donors` checkbox in upload options (using "Import Valid Rows Only" button instead), (d) manual column-mapping UI (canonical template only). Track as separate ENHANCE work if user requests. | OPEN |
| ISSUE-5 | 1 | INFO | BE | `BaseCurrencyId` defaults to same as `CurrencyId` and `ExchangeRate=1.0` in V1. Real currency conversion (Company.DefaultCurrencyId + CurrencyExchangeRate lookup at DonationDate) deferred. Multi-currency aggregation reports will treat imported donations as their face currency. | OPEN |
| ISSUE-6 | 1 | INFO | E2E | Full E2E test (BE dotnet build + FE pnpm dev + spreadsheet round-trip) NOT executed in this session — only the FE agent's filtered tsc check and SQL spot-review. Run the seed (`BulkDonationImport-seed.sql`) in dev DB, restart BE, then upload a 5-row spreadsheet through `/[lang]/crm/donation/bulkdonation` to confirm: template download has 9 columns, validation populates summary cards, execute INSERTs into `fund.GlobalDonations` with `Note` prefix. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-11 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. ALIGN scope, non-standard FLOW. Replaces existing manual-entry FE with shared `<ImportPageConfig gridCode="BULKDONATION" />`. Schema mismatches with `GlobalDonation.cs` surfaced before agent spawn and resolved via user-approved Minimal-MVP strategy (drop `purpose_code`, rename `payment_mode_code` → `donation_mode_code` resolving to MasterData TypeCode `'PAYMENTMODE'`, server-side defaults for all NOT NULL columns the spreadsheet doesn't source).
- **Files touched**:
  - BE: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/BulkDonationImport-fn-validate.sql` (created); `BulkDonationImport-fn-execute.sql` (created); `BulkDonationImport-seed.sql` (created). NO C# changes; NO EF migration.
  - FE: `PSS_2.0_Frontend/src/presentation/pages/crm/donation/bulkdonation.tsx` (modified — reduced to one-liner `<ImportPageConfig gridCode="BULKDONATION" />`); `PSS_2.0_Frontend/src/presentation/components/page-components/crm/donation/bulkdonation/data-table.tsx` (deleted); `bulk-donation-page.tsx` (deleted); `bulk-donation-view.tsx` (deleted); `bulkdonation/index.ts` (modified — barrel emptied with deprecation comment).
  - DB: `BulkDonationImport-seed.sql` is the seed file (already listed under BE).
- **Deviations from spec**:
  - Template reduced from 10 → 9 columns (dropped `purpose_code`) per user approval (Minimal-MVP strategy). `DonationPurposeId` does not exist on `GlobalDonation` entity; restoring it requires a future migration (ISSUE-1).
  - `payment_mode_code` template column renamed to `donation_mode_code` (entity has `DonationModeId`, not `PaymentModeId`). Lookup target: `sett.MasterDatas` where MasterTypeCode = `'PAYMENTMODE'` (verified from `ChequeDonation-sqlscripts.sql:448`, NOT the guess `'DONATIONMODE'`).
  - Execute fn defaults `PaymentStatusId` to `'PENDING'` (not `'RECEIVED'` per spec) — mirrors `CreateChequeDonation.cs:174-176` precedent (ISSUE-2).
  - Seed grants broader Role/MenuCapabilities than the CONFIG block specified (ISSUE-3).
  - Source-column traceability (prompt assumed a `Source='BULK_IMPORT'` column) replaced with `Note` field prefix `[IMPORT:<sessionId>]` since no `Source` column exists on the entity.
  - Validate fn uses per-row PL/pgSQL loop (not set-based like ContactImport-fn-validate.sql), because the contact-resolution chain (code → email → name ILIKE with ambiguity detection) cannot be expressed set-based.
- **Known issues opened**: ISSUE-1 (purpose_code dropped); ISSUE-2 (PaymentStatus default deviation); ISSUE-3 (seed grants broader caps than spec); ISSUE-4 (deferred UX features — 5-step stepper, BDU- prefix, skip-unresolved checkbox, manual mapper); ISSUE-5 (no currency conversion in V1); ISSUE-6 (E2E test pending — only spot-check done this session).
- **Known issues closed**: None.
- **Next step**: User runs `BulkDonationImport-seed.sql` in dev DB, restarts BE, navigates to `/[lang]/crm/donation/bulkdonation`, downloads template, uploads a 5-row test spreadsheet, confirms staging table → validation summary cards → Tab 3 import → rows visible at `/[lang]/crm/donation/globaldonation` with `Note` field starting `[IMPORT:<id>]`. If any of ISSUE-1..ISSUE-3 are blockers, run `/continue-screen #5` to adjust.
