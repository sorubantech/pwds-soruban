---
screen: MemberEnrolment
registry_id: 59
module: Membership
status: PENDING
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO — mem schema created by screen #58 (MembershipTier)
planned_date: 2026-04-22
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (grid + FORM layout + DETAIL layout)
- [x] Existing code reviewed (FE stub only — `page.tsx` is placeholder)
- [x] Business rules + workflow extracted
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (FORM wizard + DETAIL tab layout specified)
- [ ] User Approval received
- [ ] Backend code generated
- [ ] Backend wiring complete
- [ ] Frontend code generated (view-page with 3 modes + Zustand store)
- [ ] Frontend wiring complete
- [ ] DB Seed script generated (GridFormSchema: SKIP for FLOW)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at correct route
- [ ] Grid loads with columns and search/filter
- [ ] KPI summary widgets (4 cards) appear above grid
- [ ] Tier filter chips work (Bronze/Silver/Gold/Platinum/Lifetime)
- [ ] Status filter chips work (Active/Expired/Pending/Cancelled/Suspended)
- [ ] `?mode=new` — 3-step wizard renders correctly (Contact & Tier → Payment → Confirmation)
- [ ] Step 1: Contact ApiSelectV2 + contact card renders when contact selected
- [ ] Step 1: Tier visual cards load from MembershipTier FK, card selected highlights
- [ ] Step 1: Benefits preview panel updates when tier card is clicked
- [ ] Step 1: Membership options fields render (StartDate, EndDate readonly, Branch, AutoRenew toggle, ReferredBy)
- [ ] Step 2: Amount display banner shows tier fee; fee summary cards (Membership Fee, Joining Fee, Total)
- [ ] Step 2: Payment method radio cards (Card, Bank Transfer, Cash, Cheque, Waive Fee)
- [ ] Step 2: Conditional sub-form appears for selected payment method
- [ ] Step 3: Enrollment summary review; post-enrollment action checkboxes render
- [ ] Save (Complete Enrollment) → creates record, redirects to `?mode=read&id={newId}`
- [ ] `?mode=read&id=X` — DETAIL layout: 5 quick-stat cards + 4-tab panel (Overview, Payment History, Benefits, Activity)
- [ ] Edit button on detail → `?mode=edit&id=X` → wizard pre-filled
- [ ] Approve button on grid row (for Pending records) triggers status change → Active
- [ ] Renew button on grid row → navigates to Membership Renewal screen
- [ ] Post-enrollment action handlers fire (toast for SERVICE_PLACEHOLDER items)
- [ ] FK dropdowns load: Contact (ApiSelectV2), MembershipTier (tier cards), Branch (select)
- [ ] Unsaved changes dialog triggers on dirty form navigation
- [ ] DB Seed — menu visible under CRM_MEMBERSHIP sidebar

---

## ① Screen Identity & Context

Screen: MemberEnrolment
Module: Membership
Schema: mem
Group: MemModels (e.g., MemBusiness, MemModels, MemSchemas)

Business: The Member Enrollment screen is the entry point for registering a contact as a formal member
of the organisation. Staff select a contact, choose a membership tier (Bronze/Silver/Gold/Platinum/Lifetime),
configure the start date, branch, and auto-renewal preference, then process the initial payment through a
3-step wizard. Upon completion the record moves to Pending status awaiting admin approval, after which it
becomes Active. The screen serves membership coordinators and business admins who manage the organisation's
membership programme — a revenue-generating stream offering tiered benefits, voting rights, and recognition.
The detail view gives a full member profile: current tier, validity period, payment history across all
renewals, benefit utilisation, and a chronological activity timeline. The Member Enrollment screen is the
first record per member; subsequent renewals are managed through the Membership Renewal screen (Wave 3).

---

## ② Entity Definition

Table: mem."MemberEnrolments"

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MemberEnrolmentId | int | — | PK | — | Primary key |
| MemberCode | string | 50 | YES | — | Unique per Company; auto-gen MEM-{NNNN} if empty |
| CompanyId | int | — | YES | — | Tenant ID from HttpContext |
| ContactId | int | — | YES | corgs."Contacts" | FK — the person being enrolled |
| MembershipTierId | int | — | YES | mem."MembershipTiers" | FK — selected tier |
| BranchId | int? | — | NO | app."Branches" | Optional branch assignment |
| ReferredByContactId | int? | — | NO | corgs."Contacts" | Optional — who referred them |
| StartDate | DateTime | — | YES | — | Membership start (defaults today) |
| EndDate | DateTime | — | YES | — | Auto-computed from StartDate + tier period |
| AutoRenew | bool | — | YES | — | Default true |
| AmountPaid | decimal(18,2) | — | YES | — | Membership fee collected |
| JoiningFee | decimal(18,2) | — | YES | — | One-time joining fee (default 0) |
| PaymentModeId | int | — | YES | gen."PaymentModes" | FK — Cash/Card/Cheque/BankTransfer/WaiveFee |
| TransactionRef | string? | 100 | NO | — | Card/bank transfer reference number |
| ChequeNo | string? | 50 | NO | — | For cheque payments |
| ChequeDate | DateTime? | — | NO | — | For cheque payments |
| BankName | string? | 100 | NO | — | For cheque/bank transfer |
| Status | string | 30 | YES | — | Pending → Active → Suspended/Cancelled/Expired |
| Notes | string? | 500 | NO | — | Internal notes |

**No child entities** — payment history across renewals is queried from MemberEnrolment + MembershipRenewal
(Wave 3) by ContactId/MemberCode. Benefits are resolved from MembershipTier.MemberBenefits at read time.

---

## ③ FK Resolution Table

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ContactId | Contact | Base.Domain/Models/ContactModels/Contact.cs | GetContacts | firstName + lastName (full name) | ContactResponseDto |
| MembershipTierId | MembershipTier | Base.Domain/Models/MemModels/MembershipTier.cs | GetMembershipTiers | tierName | MembershipTierResponseDto |
| BranchId | Branch | Base.Domain/Models/ApplicationModels/Branch.cs | GetBranches | branchName | BranchResponseDto |
| ReferredByContactId | Contact | Base.Domain/Models/ContactModels/Contact.cs | GetContacts | firstName + lastName | ContactResponseDto |
| PaymentModeId | PaymentMode | Base.Domain/Models/GeneralModels/PaymentMode.cs | GetPaymentModes | paymentModeName | PaymentModeResponseDto |

**Note on GQL names**: ContactQueries.cs exposes `GetContacts` (not `GetAllContactList`). BranchQueries.cs
exposes `GetBranches`. MembershipTierQueries.cs (created by screen #58) exposes `GetMembershipTiers`.
Verify exact names from generated files before wiring ApiSelectV2 queries.

**MembershipTier FK dependency**: MembershipTier entity was created in screen #58. The `mem` schema
DbContext (IMemDbContext / MemDbContext) already exists — DO NOT recreate it.

---

## ④ Business Rules & Validation

**Uniqueness Rules:**
- MemberCode must be unique per Company (auto-generated if blank — format: MEM-{NNNN})
- A ContactId may not have more than one Active membership at the same time (validate on Create/Update)

**Required Field Rules:**
- ContactId, MembershipTierId, StartDate, AmountPaid, PaymentModeId, Status are mandatory
- AutoRenew is required (boolean, defaults true)

**Computed/Readonly:**
- EndDate = StartDate + MembershipTier.MembershipPeriodMonths (or "Lifetime" = StartDate + 99 years)
- MembershipPeriod display string = "{StartDate} – {EndDate}" — computed on frontend and backend

**Conditional Payment Rules:**
- If PaymentMode = Card → TransactionRef recommended (gateway reference)
- If PaymentMode = Cheque → ChequeNo, ChequeDate, BankName all required
- If PaymentMode = BankTransfer → TransactionRef required
- If PaymentMode = WaiveFee → AmountPaid = 0, admin role only

**Workflow:**
- States: Pending → Active → Suspended → Cancelled | Expired (computed — EndDate < today)
- Transitions:
  - Create → Status = Pending (default)
  - ApproveMemberEnrolment (command) → Pending → Active
  - SuspendMemberEnrolment (command) → Active → Suspended
  - CancelMemberEnrolment (command) → Active/Suspended → Cancelled
  - Expired is computed at read time (EndDate < today AND Status = Active)
- "Expires Soon" = Active AND EndDate within 30 days — computed badge, not stored status

**Business Logic:**
- AmountPaid must equal MembershipTier.AnnualFee for the selected tier (validated but overridable by admin)
- JoiningFee defaults to 0 (some tiers may have a one-time joining fee set on the tier)
- ReferredByContactId must be different from ContactId
- WaiveFee payment mode is restricted to BUSINESSADMIN role

---

## ⑤ Screen Classification & Pattern Selection

**Screen Type**: FLOW
**Type Classification**: Transactional workflow — creates a long-lived record with status lifecycle
**Reason**: Enrollment creates a Pending record that transitions through a status workflow; the form is
a 3-step wizard (not a modal), and the detail view is a tabbed member profile — both classic FLOW patterns.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files)
- [x] Tenant scoping (CompanyId from HttpContext)
- [ ] Nested child creation — no child entities
- [x] Multi-FK validation (ValidateForeignKeyRecord × 4 — Contact, MembershipTier, Branch, PaymentMode)
- [x] Unique validation — MemberCode per Company; one Active membership per ContactId
- [x] Workflow commands: ApproveMemberEnrolment, SuspendMemberEnrolment, CancelMemberEnrolment
- [ ] File upload command — no file uploads
- [x] Custom business rule validators — WaiveFee role check; EndDate auto-compute; duplicate active membership

**Frontend Patterns Required:**
- [x] FlowDataTable (grid)
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form (for FORM layout — 3-step wizard)
- [x] Zustand store (memberenrolment-store.ts)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (with Back, Save/Edit buttons)
- [ ] Child grid inside form — none
- [x] Workflow status badge + action buttons (Approve for Pending, Suspend, Cancel)
- [ ] File upload widget — none
- [x] Summary cards / count widgets above grid — 4 KPI cards
- [ ] Grid aggregation columns — none

---

## ⑥ UI/UX Blueprint

### Grid/List View

**Display Mode**: `table`

**Grid Columns** (in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Member ID | memberCode | text (link) | 110px | YES | Accent color, links to read mode |
| 2 | Name | contactName | text | auto | YES | Contact full name |
| 3 | Contact | contactCode | text (link) | 100px | YES | Links to Contact detail screen |
| 4 | Tier | membershipTierName | badge | 120px | YES | Tier badge with emoji (🥉🥈🥇💎⭐) |
| 5 | Joined | startDate | date | 100px | YES | Enrollment start date |
| 6 | Expires | endDate | date | 100px | YES | Expiry date |
| 7 | Auto-Renew | autoRenew | boolean-icon | 90px | NO | ✓ / ✗ icon |
| 8 | Amount Paid | amountPaid | currency | 110px | YES | Right-aligned |
| 9 | Status | status | badge | 110px | YES | Color-coded (Active=green, Expired=red, Pending=purple, ExpiresSoon=yellow, Suspended=gray) |
| 10 | Actions | — | actions | 120px | NO | View + Renew (conditional) + dropdown |

**Search/Filter Fields**: text search (name, member ID, email), Tier chip filter, Status chip filter,
Advanced: Renewal Due (This Month/Next 30/Next 90/Overdue), Join Date range, Branch

**Filter Chips (Tier)**: All | 🥉 Bronze | 🥈 Silver | 🥇 Gold | 💎 Platinum | ⭐ Lifetime
**Filter Chips (Status)**: All Status | Active | Expired | Pending | Cancelled | Suspended

**Grid Actions per row**:
- View (eye icon) → `?mode=read&id={id}`
- Approve (check icon, green) — only shown when Status = Pending
- Renew (refresh icon, amber) — only shown when Status = Active or ExpiresSoon or Expired
- Dropdown: View | Edit | Renew | Upgrade Tier | Suspend | Cancel Membership

**Bulk Actions** (when rows selected): Send Renewal Reminders (SERVICE_PLACEHOLDER) | Export

**Row Click**: Navigates to `?mode=read&id={id}` (DETAIL layout)

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

#### LAYOUT 1: FORM (mode=new & mode=edit) — 3-Step Wizard

> **Critical**: The enrollment form is a WIZARD, not the standard section/accordion layout.
> Use a step-indicator header + conditional step body. New and Edit share this layout.
> On Edit mode, Step 2 (Payment) fields should be read-only / disabled (payment is immutable after enrollment).

**Page Header**: FlowFormPageHeader — Title: "Enroll New Member" (new) / "Edit Enrollment" (edit);
Back button returns to grid; Save button is inside the wizard footer (not in header).

**Wizard Structure — 3 Steps with step indicator bar:**

```
[ ✓ Step 1: Contact & Tier ]  [ ✓ Step 2: Payment ]  [ → Step 3: Confirmation ]
```

Each step shows a number circle (pending: gray, active: accent, completed: green checkmark).
Step indicator is clickable — completed steps are navigable; future steps are locked.
Wizard footer: [Back] [Step N of 3] [Next / Complete Enrollment]

---

**STEP 1 — Contact & Tier**

Section: "Link Contact" (fa-user icon)
- ContactId: ApiSelectV2 — search by name/email/phone, placeholder "Search by name, email, phone..."
  - When contact selected: render **Contact Card** below the search input:
    - Avatar (initials circle, gradient bg), Name (bold), Email, Phone, Location, ContactCode badge
    - "Clear" (×) button to deselect
  - If selected contact already has an Active membership: show **Existing Member Alert** (amber warning box):
    "This contact is already an active member. Enrolling will create a second record."
  - "New Contact (inline form)" link — out of scope for this phase; render as disabled text link

Section divider

Section: "Select Membership Tier" (fa-crown icon)
- MembershipTierId: **Visual Tier Card Grid** (NOT a dropdown)
  - Load all active tiers via GetMembershipTiers query
  - Display as responsive card grid (3-4 cols desktop, 2 cols tablet, 1 col mobile)
  - Each card shows: emoji icon, tier name, price, period (per year / one-time), brief description, "Select" button
  - Selected card: amber border, amber background tint, ✓ checkmark badge top-right, button text "Selected"
  - Clicking a card selects it and updates the **Benefits Preview** panel below
- Benefits Preview (amber-tinted panel): dynamically shows benefits list for selected tier
  - Populated from MembershipTier.Benefits (text list from tier entity)
  - Shows tier name in header

Section divider

Section: "Membership Options" (fa-cog icon) — 2-3 column row layout
| Field | Widget | Notes |
|-------|--------|-------|
| StartDate | date picker | Default: today; label "Start Date" |
| MembershipPeriod | readonly text | Auto-computed: "{StartDate} – {EndDate}"; not stored |
| BranchId | ApiSelectV2 | Loads GetBranches; optional |
| AutoRenew | toggle switch | Default: ON; label shows "Enabled" / "Disabled" |
| ReferredByContactId | ApiSelectV2 | Search contacts; optional; label "Referred By (optional)" |

---

**STEP 2 — Payment**

Amount Display Banner (amber gradient): "Total Amount Due" / large amount / tier label
Fee Summary Row (3 mini-cards): Membership Fee | Joining Fee | Total

Section: "Payment Method" (fa-credit-card icon)
Payment method radio cards (visual selection, NOT a dropdown):

| Option | Icon | Sub-form fields (expand on select) |
|--------|------|-------------------------------------|
| Credit/Debit Card | fa-credit-card | Card Number, Expiry (MM/YY), CVV, "Save card for auto-renewal" checkbox |
| Bank Transfer | fa-building-columns | Account Name, Reference Number, Bank Name |
| Cash (staff-collected) | fa-money-bill-wave | No sub-form (optional: Receipt Reference text) |
| Cheque | fa-money-check | Cheque No, Cheque Date, Bank Name |
| Waive Fee (admin only) | fa-hand-holding-heart | No sub-form; AmountPaid = 0; only show for BUSINESSADMIN role |

Each option renders as a bordered card with a radio circle + icon + label.
On select: card gets accent border + background, sub-form expands below a divider.
Only one payment method is selected at a time.

**Stored fields from Step 2**: PaymentModeId, AmountPaid, JoiningFee, TransactionRef, ChequeNo, ChequeDate, BankName

---

**STEP 3 — Confirmation**

Confirmation hero: clipboard-check icon, "Review Enrollment Details" heading, subtitle

Enrollment Summary card (read-only rows):
| Label | Value |
|-------|-------|
| Member | {contactName} ({contactCode}) |
| Tier | {tierEmoji} {tierName} (${amount}/year) |
| Period | {startDate} – {endDate} |
| Payment | {paymentMode} — ${amountPaid} |
| Auto-Renew | Yes / No |
| Branch | {branchName} |

Post-Enrollment Actions card — 4 checkboxes (all default checked except "Send physical welcome kit"):
1. ✓ Send welcome email with membership details → SERVICE_PLACEHOLDER
2. ✓ Generate membership card (PDF) → SERVICE_PLACEHOLDER
3. ✓ Add to member newsletter segment → SERVICE_PLACEHOLDER
4. ☐ Send physical welcome kit → UI flag only (no backend service)

"Complete Enrollment" button in wizard footer → submits Create command.

---

#### LAYOUT 2: DETAIL (mode=read) — Tabbed Member Profile

**Page Header**: Back button, Member name as title with Tier Badge (e.g., "💎 Platinum Member" prefix),
Member metadata row: MemberCode (accent) | Status badge | "Since {startDate year}" | Contact code link

**Header Actions**:
- Edit (pen icon) → `?mode=edit&id={id}`
- Renew (arrows-rotate icon, amber) → navigates to Membership Renewal screen (SERVICE_PLACEHOLDER if not built)
- Upgrade/Downgrade (arrows icon) → SERVICE_PLACEHOLDER (toast)
- Send Card (id-card icon) → SERVICE_PLACEHOLDER (toast)
- More dropdown: Send Email (SERVICE_PLACEHOLDER) | Print Certificate (SERVICE_PLACEHOLDER) | Export PDF (SERVICE_PLACEHOLDER) | Suspend | Cancel Membership

**Quick Stats Row (5 stat cards, horizontal):**
| # | Label | Value |
|---|-------|-------|
| 1 | Tier | {emoji} {tierName} / {fee}/year |
| 2 | Member Since | {startDate formatted} / {duration text} |
| 3 | Expires | {endDate formatted} / {N months remaining or "Expired"} |
| 4 | Total Paid | ${sum of all payments} / {N payments} |
| 5 | Benefits Used | {N of M} / {utilization%} |

**Tabbed Detail Card (4 tabs):**

**Tab 1 — Overview** (fa-circle-info):
Two sections with 2-col info grid:

Section "Membership Info":
| Field | Value |
|-------|-------|
| Member ID | memberCode |
| Tier | tierName (fee/period) |
| Status | status badge |
| Joined | startDate |
| Current Period | startDate – endDate |
| Auto-Renew | On (card ending XXXX) / Off |
| Branch | branchName |

Section "Contact Info":
| Field | Value |
|-------|-------|
| Name | contactName |
| Email | contact email |
| Phone | contact phone |
| Also a Donor | lifetime donation amount (read from Contact/Donation aggregate, show "—" if none) |

**Tab 2 — Payment History** (fa-credit-card):
Table columns: Date | Period | Amount | Method | Receipt | Status
Data: current enrollment payment + all MembershipRenewal records for this MemberCode
(Initially only shows enrollment payment; renewal records appear once Wave 3 is built)
Each receipt is a clickable link (Receipt #)

**Tab 3 — Benefits** (fa-gift):
Table columns: Benefit | Status (Receiving/Eligible/Not Used) | Usage Info
Data: loaded from MembershipTier.Benefits for the enrolled tier
"Set Up" action button on unused benefits → SERVICE_PLACEHOLDER

**Tab 4 — Activity** (fa-clock-rotate-left):
Timeline component (vertical line + dot per event):
Dot colors: payment=green, reminder=amber, event=purple, upgrade=membership-accent
Events show date + description text
Initially shows: enrollment event + any status changes from audit fields

---

### Page Widgets & Summary Cards

**Widgets**: 4 KPI cards above the grid

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | Total Members | totalMembers (+ active/expired/pending sub-text) | number | Top-left |
| 2 | Revenue (YTD) | revenueYtd + revenueGrowthPercent | currency + trend | Top-2 |
| 3 | Renewals Due (30 days) | renewalsDue30Days + renewalsAtRisk | count + currency warning | Top-3 |
| 4 | New Members (Month) | newMembersThisMonth + topTierThisMonth | count + sub-text | Top-right |

**Grid Layout Variant**: `widgets-above-grid`
FE Dev uses **Variant B**: `<ScreenHeader>` + 4 widget components + `<DataTableContainer showHeader={false}>`.

**Summary GQL Query**:
- Query name: `GetMemberEnrolmentSummary`
- Returns: `MemberEnrolmentSummaryDto`
- Fields: `totalMembers`, `activeMembers`, `expiredMembers`, `pendingMembers`, `revenueYtd`,
  `revenueGrowthPercent` (decimal), `renewalsDue30Days`, `renewalsAtRisk`, `newMembersThisMonth`,
  `topTierThisMonth` (string)
- Added to `MemberEnrolmentQueries.cs` alongside `GetAll` and `GetById`

### Grid Aggregation Columns

**Aggregation Columns**: NONE

### User Interaction Flow

1. Grid → 4 KPI widgets visible + filter chips → click "+Enroll Member" → URL: `?mode=new`
   → FORM LAYOUT loads (Step 1 of 3-step wizard)
2. Step 1: Select contact → contact card appears; click tier card → tier selected, benefits preview updates;
   fill options (start date, branch, auto-renew, referred by) → click Next
3. Step 2: View amount banner; select payment method → sub-form expands; fill payment details → click Next
4. Step 3: Review summary; configure post-enrollment action checkboxes → click "Complete Enrollment"
   → API creates record (Status: Pending) → URL redirects to `?mode=read&id={newId}`
   → DETAIL LAYOUT loads (quick stats + tabs)
5. Admin clicks Approve on grid row → ApproveMemberEnrolment command → Status → Active
6. From detail: click Renew → navigates to Membership Renewal (Wave 3)
7. From detail: click Edit → `?mode=edit&id={id}` → FORM LAYOUT pre-filled (payment step read-only)
8. Back button → returns to grid list with URL cleared

---

## ⑦ Substitution Guide

**Canonical Reference**: SavedFilter (FLOW)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | MemberEnrolment | Entity/class name |
| savedFilter | memberEnrolment | Variable/field names |
| SavedFilterId | MemberEnrolmentId | PK field |
| SavedFilters | MemberEnrolments | Table name, collection names |
| saved-filter | member-enrolment | FE route path segment (not used — route uses memberenrollment) |
| savedfilter | memberenrollment | FE folder name, import paths, route segment |
| SAVEDFILTER | MEMBERENROLLMENT | Grid code, menu code |
| notify | mem | DB schema |
| Notify | Mem | Backend group name (MemBusiness, MemModels, MemSchemas) |
| NotifyModels | MemModels | Namespace suffix |
| NOTIFICATIONSETUP | CRM_MEMBERSHIP | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/membership/memberenrollment | FE route path |
| notify-service | mem-service | FE service folder name |

---

## ⑧ File Manifest

### Backend Files (13 files — 11 standard + 3 workflow commands)

| # | File | Path |
|---|------|------|
| 1 | Entity | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/MemModels/MemberEnrolment.cs |
| 2 | EF Config | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/MemConfigurations/MemberEnrolmentConfiguration.cs |
| 3 | Schemas (DTOs) | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/MemSchemas/MemberEnrolmentSchemas.cs |
| 4 | Create Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MemberEnrolments/CreateCommand/CreateMemberEnrolment.cs |
| 5 | Update Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MemberEnrolments/UpdateCommand/UpdateMemberEnrolment.cs |
| 6 | Delete Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MemberEnrolments/DeleteCommand/DeleteMemberEnrolment.cs |
| 7 | Toggle Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MemberEnrolments/ToggleCommand/ToggleMemberEnrolment.cs |
| 8 | Approve Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MemberEnrolments/ApproveCommand/ApproveMemberEnrolment.cs |
| 9 | Suspend Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MemberEnrolments/SuspendCommand/SuspendMemberEnrolment.cs |
| 10 | Cancel Command | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MemberEnrolments/CancelCommand/CancelMemberEnrolment.cs |
| 11 | GetAll Query | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MemberEnrolments/GetAllQuery/GetAllMemberEnrolment.cs |
| 12 | GetById Query | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MemberEnrolments/GetByIdQuery/GetMemberEnrolmentById.cs |
| 13 | GetSummary Query | PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MemberEnrolments/GetSummaryQuery/GetMemberEnrolmentSummary.cs |
| 14 | Mutations | PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Mem/Mutations/MemberEnrolmentMutations.cs |
| 15 | Queries | PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Mem/Queries/MemberEnrolmentQueries.cs |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | IApplicationDbContext.cs | DbSet<MemberEnrolment> property |
| 2 | MemDbContext.cs | DbSet<MemberEnrolment> property (file created by screen #58) |
| 3 | DecoratorProperties.cs | MemberEnrolment entry in DecoratorMemModules |
| 4 | MemMappings.cs | Mapster mapping config for MemberEnrolment → MemberEnrolmentResponseDto |

### Frontend Files (9 files)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | PSS_2.0_Frontend/src/domain/entities/mem-service/MemberEnrolmentDto.ts |
| 2 | GQL Query | PSS_2.0_Frontend/src/infrastructure/gql-queries/mem-queries/MemberEnrolmentQuery.ts |
| 3 | GQL Mutation | PSS_2.0_Frontend/src/infrastructure/gql-mutations/mem-mutations/MemberEnrolmentMutation.ts |
| 4 | Page Config | PSS_2.0_Frontend/src/presentation/pages/crm/membership/memberenrollment.tsx |
| 5 | Index Page | PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/memberenrollment/index.tsx |
| 6 | Index Page Component | PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/memberenrollment/index-page.tsx |
| 7 | View Page (3 modes) | PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/memberenrollment/view-page.tsx |
| 8 | Zustand Store | PSS_2.0_Frontend/src/presentation/components/page-components/crm/membership/memberenrollment/memberenrollment-store.ts |
| 9 | Route Page (EXISTS) | PSS_2.0_Frontend/src/app/[lang]/crm/membership/memberenrollment/page.tsx ← REPLACE stub |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | entity-operations.ts | MEMBERENROLLMENT operations config |
| 2 | operations-config.ts | Import + register operations |
| 3 | sidebar menu config | Menu entry under CRM_MEMBERSHIP |
| 4 | route config | Route definition for memberenrollment |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: Enroll Member
MenuCode: MEMBERENROLLMENT
ParentMenu: CRM_MEMBERSHIP
Module: CRM
MenuUrl: crm/membership/memberenrollment
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: MEMBERENROLLMENT
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

**GraphQL Types:**
- Query type: `MemberEnrolmentQueries`
- Mutation type: `MemberEnrolmentMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| GetMemberEnrolments | [MemberEnrolmentResponseDto] | searchText, pageNo, pageSize, sortField, sortDir, isActive, dateFrom, dateTo, status, membershipTierId, branchId |
| GetMemberEnrolmentById | MemberEnrolmentResponseDto | memberEnrolmentId |
| GetMemberEnrolmentSummary | MemberEnrolmentSummaryDto | — |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| CreateMemberEnrolment | MemberEnrolmentRequestDto | int (new ID) |
| UpdateMemberEnrolment | MemberEnrolmentRequestDto | int |
| DeleteMemberEnrolment | memberEnrolmentId | int |
| ToggleMemberEnrolment | memberEnrolmentId | int |
| ApproveMemberEnrolment | memberEnrolmentId | int |
| SuspendMemberEnrolment | memberEnrolmentId | int |
| CancelMemberEnrolment | memberEnrolmentId, reason (string) | int |

**Response DTO Fields** (what FE receives):
| Field | Type | Notes |
|-------|------|-------|
| memberEnrolmentId | number | PK |
| memberCode | string | MEM-NNNN |
| contactId | number | FK |
| contactName | string | firstName + lastName joined |
| contactCode | string | e.g., CON-1245 |
| membershipTierId | number | FK |
| membershipTierName | string | Tier display name |
| tierEmoji | string | Emoji for tier (from MembershipTier entity) |
| tierFee | number | Annual fee from tier |
| branchId | number? | FK |
| branchName | string? | — |
| referredByContactId | number? | FK |
| referredByContactName | string? | — |
| startDate | string (ISO date) | — |
| endDate | string (ISO date) | — |
| autoRenew | boolean | — |
| amountPaid | number | — |
| joiningFee | number | — |
| paymentModeId | number | FK |
| paymentModeName | string | Card/Cash/Cheque/BankTransfer/WaiveFee |
| transactionRef | string? | — |
| chequeNo | string? | — |
| chequeDate | string? | — |
| bankName | string? | — |
| status | string | Pending/Active/Suspended/Cancelled/Expired |
| notes | string? | — |
| isActive | boolean | Inherited |

**Summary DTO Fields:**
| Field | Type |
|-------|------|
| totalMembers | number |
| activeMembers | number |
| expiredMembers | number |
| pendingMembers | number |
| revenueYtd | number |
| revenueGrowthPercent | number |
| renewalsDue30Days | number |
| renewalsAtRisk | number |
| newMembersThisMonth | number |
| topTierThisMonth | string |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/en/crm/membership/memberenrollment`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with all 10 columns; pagination works
- [ ] Search filters by name, member ID, email
- [ ] Tier filter chips filter the grid (All/Bronze/Silver/Gold/Platinum/Lifetime)
- [ ] Status filter chips filter the grid (All/Active/Expired/Pending/Cancelled/Suspended)
- [ ] 4 KPI summary widgets display above grid with correct values
- [ ] `?mode=new`: Step 1 — Contact ApiSelectV2 search works; contact card renders on selection
- [ ] `?mode=new`: Existing active member alert shows when contact already enrolled
- [ ] `?mode=new`: Tier visual cards load from API; clicking selects tier + updates benefits preview
- [ ] `?mode=new`: Membership options render (StartDate picker, EndDate readonly computed, Branch, AutoRenew toggle, ReferredBy)
- [ ] Step navigation: Next validates Step 1 (ContactId + MembershipTierId required); Back works
- [ ] Step 2: Amount banner shows tier fee; payment method radio cards work; sub-form expands correctly per method
- [ ] Step 2: Cheque sub-form shows ChequeNo, ChequeDate, BankName when Cheque selected
- [ ] Step 2: WaiveFee option only visible/selectable for BUSINESSADMIN role
- [ ] Step 3: Summary review shows correct values; post-enrollment action checkboxes work
- [ ] "Complete Enrollment" → creates record (Status: Pending) → redirects to `?mode=read&id={newId}`
- [ ] `?mode=read&id=X`: 5 quick-stat cards render (Tier, Member Since, Expires, Total Paid, Benefits Used)
- [ ] `?mode=read&id=X`: 4 tabs render (Overview, Payment History, Benefits, Activity)
- [ ] Overview tab: Membership Info + Contact Info sections with correct field values
- [ ] Payment History tab: shows enrollment payment row
- [ ] Benefits tab: shows tier benefits list with status
- [ ] Activity tab: timeline shows enrollment event
- [ ] Header actions: Edit → `?mode=edit`; Renew → toast (SERVICE_PLACEHOLDER); Upgrade/Downgrade → toast; Send Card → toast
- [ ] Dropdown actions: Send Email → toast; Print Certificate → toast; Export PDF → toast; Suspend → command; Cancel → command with confirmation
- [ ] `?mode=edit&id=X`: Wizard pre-filled; Step 2 payment fields read-only; save → back to detail
- [ ] Approve button on grid (Pending row) → ApproveMemberEnrolment command → Status changes to Active
- [ ] Unsaved changes dialog triggers when navigating away from dirty wizard
- [ ] Permissions: WaiveFee option gated to BUSINESSADMIN

**DB Seed Verification:**
- [ ] "Enroll Member" menu item visible in sidebar under CRM → Membership
- [ ] Grid columns render correctly (no RJSF form schema — SKIP for FLOW)

---

## ⑫ Special Notes & Warnings

- **CompanyId is NOT a field in the form** — it comes from HttpContext in FLOW screens
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it
- **The FE route already exists** at `src/app/[lang]/crm/membership/memberenrollment/page.tsx` as a stub (`<div>Need to Develop</div>`). The FE developer MUST replace this stub — do not create a new file.
- **mem schema infrastructure**: IMemDbContext, MemDbContext, MemMappings were created by screen #58 (MembershipTier). DO NOT recreate these files — only ADD the MemberEnrolment DbSet and mappings to the existing files.
- **Wizard form pattern**: The FORM layout is a 3-step wizard, NOT the standard section/accordion FLOW form. The `view-page.tsx` must implement a step indicator + conditional step body. Use a `currentStep` state variable (1/2/3) to control which step panel is visible.
- **Tier card selector**: MembershipTierId is selected via visual cards, not a dropdown. Load tiers via `GetMembershipTiers` query and render them as clickable cards in a responsive grid. The selected tier drives the benefits preview panel and the amount shown in Step 2.
- **EndDate is computed**: Do not store EndDate directly from user input. Compute it on the backend: `EndDate = StartDate.AddMonths(tier.MembershipPeriodMonths)`. For Lifetime tiers, use `StartDate.AddYears(99)`.
- **Duplicate active membership check**: Before creating, verify the contact does not already have an Active or Pending MemberEnrolment for the same CompanyId. Return a validation error if found.
- **"Expires Soon" is NOT a stored status**: It is a computed display state (EndDate within 30 days AND Status = Active). Compute it in the GetAll LINQ query and return it as part of the DTO, or let the FE compute from endDate.
- **Payment tab in detail**: Payment History tab initially only shows the enrollment payment. Once Wave 3 (Membership Renewal) is built, its records will join the same contact's payment history. Design the query to be extensible.
- **Workflow mutations**: ApproveMemberEnrolment, SuspendMemberEnrolment, CancelMemberEnrolment are separate mutations (not part of UpdateMemberEnrolment). They change Status only. CancelMemberEnrolment accepts a reason string.

**Service Dependencies** (UI-only — no backend service implementation):
- ⚠ SERVICE_PLACEHOLDER: "Send welcome email" — checkbox in Step 3. Full UI implemented. Handler fires a toast ("Welcome email queued") because email service layer is not wired to membership events.
- ⚠ SERVICE_PLACEHOLDER: "Generate membership card (PDF)" — checkbox in Step 3. Handler shows toast. PDF generation service does not exist yet.
- ⚠ SERVICE_PLACEHOLDER: "Add to member newsletter segment" — checkbox in Step 3. Handler shows toast. Segment auto-tagging service not implemented.
- ⚠ SERVICE_PLACEHOLDER: "Renew" button (detail header + grid row) — navigates to Membership Renewal screen URL. That screen (Wave 3, #60+) is not built yet — render as toast for now.
- ⚠ SERVICE_PLACEHOLDER: "Upgrade/Downgrade" header button → toast.
- ⚠ SERVICE_PLACEHOLDER: "Send Card", "Send Email", "Print Certificate", "Export PDF" in detail header dropdown → toast.

All UI elements (buttons, wizard steps, tabs, cards) must be fully built. Only the handler for external services is mocked.

---

## ⑬ Build Log (append-only)

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — no issues raised yet) | — |

### § Sessions

{No sessions recorded yet — filled in after /build-screen completes.}
