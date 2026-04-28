---
screen: MemberEnrollment
registry_id: 59
module: Membership
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: YES — mem schema
planned_date: 2026-04-24
completed_date: 2026-04-25
last_session_date: 2026-04-25
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (grid + FORM wizard + DETAIL tabs)
- [x] Existing code reviewed (FE stub 3-line, NO BE entity)
- [x] Business rules + workflow extracted (6-state lifecycle)
- [x] FK targets resolved (Contact, MembershipTier[BLOCKED], OrgUnit, MasterData)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (FORM 3-step wizard + DETAIL single-column/4-tab specified)
- [ ] User Approval received
- [ ] Backend code generated
- [ ] Backend wiring complete
- [ ] Frontend code generated (view-page with 3-step wizard + 4-tab detail + Zustand store)
- [ ] Frontend wiring complete
- [ ] DB Seed script generated (GridFormSchema: SKIP for FLOW)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/crm/membership/memberenrollment`
- [ ] Grid loads: Member ID/Name/Contact/Tier/Joined/Expires/Auto-Renew/Amount/Status/Actions
- [ ] Search filters by: member ID, name, email (contact)
- [ ] Tier filter chips (Bronze/Silver/Gold/Platinum/Lifetime) filter grid
- [ ] Status filter chips (Active/Expired/Pending/Cancelled/Suspended) filter grid
- [ ] Advanced filters (Renewal Due / Join Date From/To / Branch) apply correctly
- [ ] `?mode=new` — 3-step wizard renders, Step 1 active, steps 2-3 disabled until prior complete
- [ ] Step 1: Contact search (ApiSelect) + inline contact card + tier card grid + benefits preview panel
- [ ] Step 2: Payment amount auto-calculated, 5 payment methods, conditional card sub-form (Card Number/Expiry/CVV)
- [ ] Step 3: Enrollment summary review + 4 post-enrollment action checkboxes
- [ ] Step navigation: Back / Next / Complete Enrollment flow + step click works if valid
- [ ] `?mode=edit&id=X` — Wizard pre-fills all 3 steps with existing data
- [ ] `?mode=read&id=X` — DETAIL layout renders: full-width single column, header + 5 stats row + 4-tab card
- [ ] 4 Detail tabs: Overview / Payment History / Benefits / Activity (all populate)
- [ ] Create flow: wizard → Complete → POST /Create → redirects to `?mode=read&id={newId}`
- [ ] Edit button on detail → `?mode=edit&id=X` → wizard pre-filled → Save → redirect to detail
- [ ] FK ApiSelects load: Contact search / OrgUnit (Branch) / MembershipTier
- [ ] 4 KPI widgets display (Total Members / Revenue YTD / Renewals Due 30 days / New Members This Month)
- [ ] Workflow transitions: Approve (Pending→Active) / Suspend (Active→Suspended) / Cancel (Active→Cancelled) / Reject (Pending→Cancelled)
- [ ] MEMBER code auto-generated (MEM-NNNN per Company)
- [ ] Auto-Renew toggle persists and displays on detail
- [ ] Lifetime tier sets EndDate=NULL and period=one-time
- [ ] Service placeholder buttons render with toast (Send Card / Send Email / Print Certificate / Export PDF)
- [ ] Unsaved changes dialog triggers on wizard navigation with dirty form
- [ ] DB Seed — MEMBERENROLLMENT menu visible in sidebar under CRM_MEMBERSHIP
- [ ] mem schema migration applied (NEW module)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

**Screen**: MemberEnrollment
**Module**: CRM (Membership sub-module)
**Schema**: `mem` (NEW — does not exist yet)
**Group**: `MemModels` (NEW)

**Business**: Member Enrollment is the core transactional screen of the NGO's paid-membership program, where staff register individuals (existing Contacts) into one of several membership tiers (Bronze/Silver/Gold/Platinum/Lifetime), capture the initial payment, and activate benefits. Membership admins and front-desk staff use this screen to enroll new members walk-in or via imported lists; approvers use it to review Pending self-registrations before activation. The screen powers the NGO's recurring-revenue engine — it feeds the Renewal screen (#60), the member portal (#61), and downstream benefit-tracking and audience-segmentation features. The read-mode detail view conveys the member's full lifecycle: tier/status/expiry at a glance, then deep-dive tabs for payment history, benefit utilization, and activity timeline (upgrades, renewals, suspensions). This is a P2-Core screen that depends on MembershipTier (#58) as a hard FK; if #58's backend isn't built first, this screen's backend cannot compile (see §⑫ ISSUE-1).

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> All fields extracted from HTML mockup. Audit columns omitted — inherited from Entity base.
> **CompanyId is NOT a field** — FLOW screens get tenant from HttpContext.

**Table**: `mem."MemberEnrollments"`

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| MemberEnrollmentId | int | — | PK | — | Primary key |
| MemberCode | string | 50 | YES | — | Auto-generated `MEM-{NNNN}` per Company, unique per Company |
| ContactId | int | — | YES | corg.Contacts | FK — the person being enrolled |
| MembershipTierId | int | — | YES | mem.MembershipTiers | FK — selected tier (Bronze/Silver/Gold/Platinum/Lifetime) |
| StartDate | DateTime | — | YES | — | Membership start date (default: today) |
| EndDate | DateTime? | — | NO | — | NULL for Lifetime tier; computed from tier.DurationMonths otherwise |
| StatusId | int | — | YES | corg.MasterData (MEMBERSTATUS) | State machine: Pending/Active/Expires Soon/Expired/Suspended/Cancelled |
| AutoRenew | bool | — | YES | — | Default true |
| MembershipFee | decimal(18,2) | — | YES | — | Fee for the tier (snapshotted from Tier at enrollment) |
| JoiningFee | decimal(18,2) | — | NO | — | One-time joining fee (0 for renewals) |
| TotalAmount | decimal(18,2) | — | YES | — | Computed: MembershipFee + JoiningFee |
| CurrencyId | int | — | YES | corg.Currencies | Default: Company default currency |
| PaymentModeId | int | — | YES | corg.MasterData (PAYMENTMODE) | CARD / BANK / CASH / CHQ / WAIVE |
| PaymentDate | DateTime? | — | NO | — | When payment was captured |
| PaymentReference | string? | 100 | NO | — | Card last-4 / Cheque# / Bank ref |
| PaymentGatewayTxnId | string? | 100 | NO | — | Online gateway txn reference (SERVICE_PLACEHOLDER) |
| CardSavedForAutoRenew | bool | — | NO | — | Only meaningful if AutoRenew=true and Mode=CARD |
| WaiveReason | string? | 500 | NO | — | Required when PaymentModeId=WAIVE |
| BranchId | int? | — | NO | corg.OrganizationalUnits | FK — enrolling branch (optional) |
| ReferredByContactId | int? | — | NO | corg.Contacts | Self-ref FK — referring contact (optional) |
| CampaignId | int? | — | NO | camp.Campaigns | FK — source campaign (optional, see ISSUE-8) |
| SendWelcomeEmail | bool | — | NO | — | Post-enrollment action, default true |
| GenerateCard | bool | — | NO | — | Post-enrollment action, default true |
| AddToNewsletter | bool | — | NO | — | Post-enrollment action, default true |
| SendWelcomeKit | bool | — | NO | — | Post-enrollment action, default false |
| SuspendedDate | DateTime? | — | NO | — | Set on Suspend transition |
| SuspensionReason | string? | 500 | NO | — | Required on Suspend |
| CancelledDate | DateTime? | — | NO | — | Set on Cancel transition |
| CancellationReason | string? | 500 | NO | — | Required on Cancel |
| ApprovedByStaffId | int? | — | NO | corg.Staffs | Set on Approve transition |
| ApprovedDate | DateTime? | — | NO | — | Set on Approve transition |
| Notes | string? | 2000 | NO | — | Internal notes |

**Child Entities**: NONE (no add-on rows, no dependents in mockup)

**Projected/Computed Fields** (not persisted — built in GetAll/GetById projection):
| Field | Computation |
|-------|-------------|
| daysUntilExpiry | (EndDate - today).Days — used for "Expires Soon" chip (≤30 days) |
| totalPaymentCount | COUNT(PaymentTransactions where MemberEnrollmentId=row.Id) — see ISSUE-6 |
| benefitsUsedCount / benefitsTotalCount | from MembershipBenefit usage tracking — see ISSUE-11 (deferred) |
| lifetimeDonationAmount | SUM(GlobalDonation where ContactId=row.ContactId) — for "Also a Donor" card |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ContactId | Contact | `Base.Domain/Models/CorgModels/Contact.cs` | `GetContacts` (`contacts` field) | FirstName + " " + LastName (composite) | ContactResponseDto |
| MembershipTierId | **MembershipTier** | `Base.Domain/Models/MemModels/MembershipTier.cs` **[DOES NOT EXIST — ISSUE-1]** | `GetMembershipTiers` (to be added with #58) | TierName | MembershipTierResponseDto |
| StatusId | MasterData (MEMBERSTATUS) | `Base.Domain/Models/CorgModels/MasterData.cs` | `GetMasterDatas` (filter by TypeCode="MEMBERSTATUS") | Name | MasterDataResponseDto |
| CurrencyId | Currency | `Base.Domain/Models/SharedModels/Currency.cs` | `GetCurrencies` | Code | CurrencyResponseDto |
| PaymentModeId | MasterData (PAYMENTMODE) | `Base.Domain/Models/CorgModels/MasterData.cs` | `GetMasterDatas` (filter by TypeCode="PAYMENTMODE") | Name | MasterDataResponseDto |
| BranchId | OrganizationalUnit | `Base.Domain/Models/ApplicationModels/OrganizationalUnit.cs` | `GetOrganizationalUnits` | OrgUnitName | OrganizationalUnitResponseDto |
| ReferredByContactId | Contact (self-ref alias) | same as ContactId | `GetContacts` (second instance, aliased) | FirstName + LastName | ContactResponseDto |
| CampaignId | Campaign | `Base.Domain/Models/ApplicationModels/Campaign.cs` | `GetCampaigns` | CampaignName | CampaignResponseDto |
| ApprovedByStaffId | Staff | `Base.Domain/Models/ApplicationModels/Staff.cs` | `GetStaffs` | FirstName + LastName | StaffResponseDto |

**FK readiness**:
- ✅ Contact / OrgUnit / Currency / MasterData / Campaign / Staff — all exist
- ❌ **MembershipTier — BLOCKED** (does not exist; #58 is PARTIAL FE-stub-only). BE cannot compile without it. See §⑫ ISSUE-1.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `MemberCode` must be unique per Company (auto-generated `MEM-{NNNN}` with tenant-scoped sequence)
- A single Contact can have multiple `MemberEnrollment` rows ONLY if prior ones are `Cancelled` / `Expired` — i.e., a Contact cannot have two *simultaneously active* memberships (enforce in Create handler; show amber warning if mockup's existing-member alert triggers)

**Required Field Rules:**
- `ContactId`, `MembershipTierId`, `StartDate`, `PaymentModeId`, `CurrencyId`, `MembershipFee`, `TotalAmount` are mandatory
- `AutoRenew` mandatory (bool, default true)
- `StatusId` mandatory (defaults to `Pending` on Create, unless bypass flag; see ISSUE-4)

**Conditional Rules:**
- If `PaymentModeId` = WAIVE → `WaiveReason` required (min 10 chars)
- If `PaymentModeId` = CARD → `PaymentReference` (card last-4) required; CVV/expiry captured but NOT persisted (PCI)
- If `PaymentModeId` = CHQ → `PaymentReference` (cheque#) required
- If `PaymentModeId` = BANK → `PaymentReference` (bank txn ref) required
- If `CardSavedForAutoRenew` = true → `AutoRenew` must be true AND `PaymentModeId` = CARD
- If tier.IsLifetime = true → `EndDate` MUST be NULL (server overrides any client value)
- If tier.IsLifetime = false → `EndDate` = `StartDate` + tier.DurationMonths (server computes)
- On `StatusId` = `Suspended` → `SuspendedDate` + `SuspensionReason` (min 10) required
- On `StatusId` = `Cancelled` → `CancelledDate` + `CancellationReason` (min 10) required

**Business Logic:**
- `MembershipFee` snapshotted from tier at enrollment time (NOT a live FK join — protects historical payment records from future price changes)
- `TotalAmount` = `MembershipFee` + (`JoiningFee` ?? 0) — server computes, client displays
- `JoiningFee` = 0 for upgrades (but Upgrade is deferred — see ISSUE-9)
- Automatic status transition: daily job checks `EndDate ≤ today` → `StatusId` = `Expired`; `EndDate - today ≤ 30` → "Expires Soon" chip (computed, not persisted as a separate status — see ISSUE-3)
- `ApprovedByStaffId` / `ApprovedDate` populated on Approve transition (handler resolves `HttpContext.User.StaffId`)
- Post-enrollment action flags (SendWelcomeEmail / GenerateCard / AddToNewsletter / SendWelcomeKit) — persisted as-is; actual side-effect execution is SERVICE_PLACEHOLDER (§⑫)

**Workflow** (state machine on `StatusId` — backed by MasterData TypeCode="MEMBERSTATUS"):

```
                               ┌────────────┐
     ┌─────────── Approve ──→  │   Active   │ ──── Suspend ──→  Suspended ──┐
     │                         └──────┬─────┘                                │
     ▼                                │                                      ├→ (Resume = back to Active)
  Pending                    EndDate−today ≤ 30                              │
     │                          (computed chip                               │
     │                           only, not state)                            │
     │                                │                                      │
     │                                ▼                                      │
     │                         ┌────────────┐                                │
     │                      ┌─►│  Expired   │  (auto by daily job on EndDate)│
     │                      │  └──────┬─────┘                                │
     │                      │         │                                      │
     │                      Renew (#60)                                      │
     │                      │         │                                      │
     └── Reject ─→ Cancelled ◄────Cancel (any time)────────────────────────┘
```

- **Transitions**:
  | Transition | From states | To state | Handler | Side effects |
  |------------|-------------|----------|---------|-------------|
  | `Approve` | Pending | Active | `ApproveMemberEnrollment` | Set ApprovedBy + ApprovedDate; trigger SendWelcomeEmail (placeholder) |
  | `Reject` | Pending | Cancelled | `RejectMemberEnrollment` | Set CancelledDate + reason |
  | `Suspend` | Active | Suspended | `SuspendMemberEnrollment` | Set SuspendedDate + reason; auto-renew disabled |
  | `Resume` | Suspended | Active | `ResumeMemberEnrollment` | Clear SuspendedDate |
  | `Cancel` | Active, Suspended, Pending | Cancelled | `CancelMemberEnrollment` | Set CancelledDate + reason; auto-renew disabled |
  | *(auto)* | Active | Expired | daily job | When EndDate ≤ today; only non-Lifetime tiers |

- **Permissions**: All transitions require `MODIFY` on MEMBERENROLLMENT menu. Reject/Cancel additionally require DELETE-equivalent.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW
**Type Classification**: Workflow-heavy transactional FLOW with wizard form + tabbed detail (non-canonical form layout — closest precedent: Beneficiary #49's multi-section form, but this one uses a horizontal 3-step wizard strip).
**Reason**: Mockup shows "+Enroll Member" navigates to a full page (not modal), URL changes, and the read view is a completely different multi-tab layout. Wizard pattern is mandated by mockup — cannot collapse to flat form without breaking UX.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files)
- [x] Tenant scoping (CompanyId from HttpContext)
- [ ] Nested child creation — NONE (no child grids)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 8: Contact, MembershipTier, MasterData×2 Status/PaymentMode, Currency, OrgUnit, Contact-self-ref, Campaign, Staff)
- [x] Unique validation — MemberCode per Company; Contact-active-enrollment uniqueness
- [x] **Workflow commands** (Approve, Reject, Suspend, Resume, Cancel) — 5 transition handlers
- [ ] File upload command — NONE (no file fields in mockup; welcome kit is service-only)
- [x] Custom business rule validators — WaiveReason-when-WAIVE; EndDate-from-tier; CardSavedForAutoRenew guards
- [x] Auto-code generation (MEM-{NNNN}, tenant-scoped, concurrency-safe — ChequeDonation #6 ISSUE-5 precedent)
- [x] **Background/scheduled task** — daily expiry check (can be hosted as IHostedService or cron endpoint; spec as a `CheckMemberEnrollmentExpiries` command callable by cron — ISSUE-5)

**Frontend Patterns Required:**
- [x] FlowDataTable (grid)
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form (for FORM layout — wizard)
- [x] Zustand store (`memberenrollment-store.ts`)
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (with Back, Save/Next/Complete buttons)
- [ ] Child grid inside form — NONE
- [x] **Workflow status badge + action buttons** (Approve/Reject for Pending, Renew/Upgrade/Suspend/Cancel for Active)
- [ ] File upload widget — NONE
- [x] Summary cards / count widgets above grid — 4 KPIs (Total Members / Revenue YTD / Renewals Due / New This Month)
- [ ] Grid aggregation columns — none (all projection-based, not LINQ subquery)
- [x] **Wizard step-strip component** (3 steps, clickable, completion indicators, validation-gated progression) — NEW pattern; create reusable component `flow-wizard-strip.tsx`
- [x] **Tier card selector** (visual cards with tier name/price/description, single-select with selected border + checkmark) — NEW renderer pattern
- [x] **Inline Contact card** (shown after ContactId selected; avatar + name + email + phone + code + clear button)
- [x] **Payment method card list** (5 visual cards with conditional sub-form expansion)
- [x] **Benefits preview panel** (dynamic, refreshes on tier selection)
- [x] **Single-column detail + 4 tabs** (Overview/Payment History/Benefits/Activity) — NOT 2-column; see §⑥ LAYOUT 2
- [x] **5-card stats row** above detail tabs (Tier/Member Since/Expires/Total Paid/Benefits Used)
- [x] **Activity vertical timeline** component — use existing `activity-timeline` from Pledge / RecurringDonation or create if missing

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from HTML mockup — this IS the design spec.

### Grid/List View

**Display Mode**: `table` (default dense grid — transactional list)

**Grid Layout Variant**: `widgets-above-grid` (4 KPI cards + filter chips + grid) → **MANDATORY Variant B** (ScreenHeader + widgets + `<DataTableContainer showHeader={false}>`) — ContactType #19 precedent avoids double-header.

### Page Widgets & Summary Cards

| # | Widget Title | Value Source | Display Type | Position | Icon |
|---|-------------|-------------|-------------|----------|------|
| 1 | Total Members | `totalMembers` (number) + breakdown `activeCount / expiredCount / pendingCount` as subtitle | number + breakdown caption | 1st | ph:identification-card (cyan) |
| 2 | Revenue (YTD) | `revenueYtd` (decimal, company default currency) + `yoyGrowthPercent` as trend arrow | currency + %-trend | 2nd | ph:currency-dollar (green) |
| 3 | Renewals Due (30 days) | `renewalsDueCount` (int) + `renewalsAtRiskAmount` (decimal, red) | count + secondary currency | 3rd | ph:calendar-x (amber) |
| 4 | New Members (Month) | `newMembersThisMonth` (int) + `topTierThisMonth` ("Silver (5)") | count + caption | 4th | ph:user-plus (blue) |

**Summary GQL Query**:
- Query name: `GetMemberEnrollmentSummary`
- Returns: `MemberEnrollmentSummaryDto { totalMembers, activeCount, expiredCount, pendingCount, revenueYtd, yoyGrowthPercent, renewalsDueCount, renewalsAtRiskAmount, newMembersThisMonth, topTierThisMonth }`
- Added to `MemberEnrollmentQueries.cs` alongside `GetAll` and `GetById`
- Multi-currency caveat: sum in Company default currency; if rows in other currencies, add disclaimer tooltip (PaymentReconciliation #14 ISSUE-12 precedent)

**Filter Chips (2 independent groups, top-level GQL args)**:
- **Tier group**: `All (default) | Bronze | Silver | Gold | Platinum | Lifetime` → passes `tierCode` (single value)
- **Status group**: `All Status (default) | Active | Expired | Pending | Cancelled | Suspended` → passes `statusCode` (single value); "Expires Soon" handled via `daysUntilExpiryMax` arg (=30)

Per ChequeDonation #6 ISSUE-10 / Refund #13 ISSUE-10: filter chips route through `advancedFilter` path on FlowDataTable, NOT top-level GQL args.

**Advanced Filter Panel (collapsible, 4 fields in a row)**:
| Field | Widget | Values | GQL arg |
|-------|--------|--------|---------|
| Renewal Due | select | All / This Month / Next 30 Days / Next 90 Days / Overdue | `renewalDueBucket` |
| Join Date From | datepicker | — | `joinDateFrom` |
| Join Date To | datepicker | — | `joinDateTo` |
| Branch | ApiSelect | OrganizationalUnit list | `branchId` |

**Search**: Single search input with placeholder "Search by name, member ID, email..." (GQL arg `searchText` — matches `MemberCode OR Contact.FirstName OR Contact.LastName OR Contact.Email OR Contact.Phone`)

**Grid Columns** (in display order, min-width 1100px):

| # | Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------|-----------|-------------|-------|----------|-------|
| 0 | — | — | checkbox | 40px | NO | Bulk select |
| 1 | Member ID | memberCode | text-bold (accent color) | 120px | YES | Default sort desc |
| 2 | Name | contactName | text-bold | auto | YES | FK display via Contact join |
| 3 | Contact | contactCode | **contact-link-badge** renderer | 130px | YES | CON-XXXX badge → navigate to Contact profile (SERVICE_PLACEHOLDER until #18 built) |
| 4 | Tier | tierName | **tier-badge** renderer (NEW) | 130px | YES | Emoji + name + tier-colored pill (reuses MasterData ColorHex if tier has one; else static map) |
| 5 | Joined | startDate | date (MMM YYYY) | 110px | YES | — |
| 6 | Expires | endDate | date or "Lifetime" | 110px | YES | Shows "Lifetime" for null EndDate |
| 7 | Auto-Renew | autoRenew | icon (ph:check = success, ph:x = muted) | 100px | NO | — |
| 8 | Amount Paid | totalAmount | currency-amount renderer | 120px | YES | Right-aligned, currencyCode prefix |
| 9 | Status | statusName | **member-status-badge** renderer (NEW) | 130px | YES | Dot + colored pill (Active=green, Expires Soon=amber, Expired=gray, Pending=blue, Cancelled=red, Suspended=orange) |
| 10 | Actions | — | action-buttons | 140px | NO | See Row Actions below |

**Row Actions** (context-dependent):
- **Always**: View button (`ph:eye`, accent) → navigate to `?mode=read&id=X`
- **Expires Soon / Expired rows**: Renew button (`ph:arrows-clockwise`, amber) → navigates to `/crm/membership/membershiprenewal?source=X` (SERVICE_PLACEHOLDER until #60 built)
- **Pending rows**: Approve button (green, inline) → triggers `ApproveMemberEnrollment` mutation
- **Dropdown (`ph:dots-three-vertical`)**:
  - For Active/Expires Soon: View / Edit / Renew / Upgrade Tier (SERVICE_PLACEHOLDER) / — / Suspend / Cancel (danger)
  - For Pending: View / Edit / — / Reject (danger)
  - For Expired: View / Renew / — / Cancel (danger)
  - For Suspended: View / Resume / Cancel (danger)
  - For Cancelled: View (only)

**Toolbar Buttons**:
- **Enroll Member** (primary, `ph:plus`) → navigates `?mode=new`
- **Import** (outline, `ph:file-arrow-up`) — SERVICE_PLACEHOLDER (bulk import)
- **Export** (outline, `ph:file-arrow-down`) — SERVICE_PLACEHOLDER

**Bulk Actions** (shown when rows selected):
- Send Renewal Reminders (`ph:envelope`) — SERVICE_PLACEHOLDER
- Export (`ph:file-arrow-down`) — SERVICE_PLACEHOLDER

**Row Click**: Navigates to `?mode=read&id={id}` (DETAIL layout)

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

#### LAYOUT 1: FORM (mode=new & mode=edit) — 3-STEP WIZARD

> **Non-standard FORM layout**: horizontal 3-step wizard, NOT flat-sectioned cards or accordion.
> Precedent: no existing FLOW screen uses this wizard; create a reusable `<FlowWizardStrip>` component.

**Page Header**: `FlowFormPageHeader` with:
- Back button (navigates to grid; triggers unsaved-changes dialog if dirty)
- Title: "Enroll New Member" (mode=new) / "Edit Member Enrollment — {memberCode}" (mode=edit)
- Subtitle: "Register a new member with tier selection and payment" / "Update enrollment details"
- Right: "Step X of 3" indicator (top-right)

**Section Container Type**: `horizontal-wizard` (3 clickable steps in a strip)

**Wizard Strip Component** (`<FlowWizardStrip>` NEW):
- Renders 3 tabs in a horizontal bar above the content area
- Active step: white bg + 2px accent bottom border
- Completed step: green bg + checkmark circle (click allowed to re-edit)
- Upcoming step: gray bg, locked (cannot click until prior step valid)
- In `mode=edit`, all 3 steps are pre-validated and clickable

**Footer Bar (fixed bottom)**:
- Left: Back button (returns to prior step; disabled on step 1)
- Center: "Step X of 3" text
- Right: Next button (steps 1, 2) / Complete Enrollment button (step 3 — primary color)

**Form Sections (3 wizard steps)**:

| # | Icon | Step Title | Layout | Collapse | Fields |
|---|------|-----------|--------|----------|--------|
| 1 | ph:user-plus | Contact & Tier | full-width | always expanded | contactId, newContactInline (placeholder), membershipTierId, benefitsPreview, startDate, startDateMode, membershipPeriod, branchId, autoRenew, referredByContactId, campaignId |
| 2 | ph:credit-card | Payment | full-width | always expanded | totalAmountDisplay (readonly), membershipFee (readonly), joiningFee (readonly), paymentModeId, paymentMode sub-form (conditional), paymentDate |
| 3 | ph:clipboard-check | Confirmation | full-width | always expanded | enrollmentSummary (readonly display), sendWelcomeEmail, generateCard, addToNewsletter, sendWelcomeKit |

**Field Widget Mapping (all fields across all steps)**:

| Field | Step | Widget | Placeholder | Validation | Notes |
|-------|------|--------|-------------|------------|-------|
| contactId | 1 | ApiSelectV2 + search | "Search by name, email, phone..." | required | Query: `GetContacts`; triggers Inline Contact Card |
| newContactInline | 1 | link button | — | — | SERVICE_PLACEHOLDER — toast "Inline contact creation coming soon" |
| membershipTierId | 1 | tier-card-selector (NEW) | — | required | Visual card grid; populated from `GetMembershipTiers` (BLOCKED — ISSUE-1); triggers Benefits Preview |
| benefitsPreview | 1 | readonly info panel | — | — | Amber bg + dashed border; shows `tier.Benefits` bullet list |
| startDateMode | 1 | select | — | required | Options: "Today" / "Specific date..." |
| startDate | 1 | datepicker | "Select date" | required | Visible only when startDateMode="Specific date" |
| membershipPeriod | 1 | text (readonly) | — | — | Auto-computed: "Jan 15, 2026 – Jan 14, 2027" (or "Lifetime" for lifetime tier) |
| branchId | 1 | ApiSelectV2 | "Select branch" | optional | Query: `GetOrganizationalUnits` |
| autoRenew | 1 | switch/toggle | — | — | Default ON; disabled for Lifetime tier |
| referredByContactId | 1 | ApiSelectV2 | "Search contact..." | optional | Query: `GetContacts` (self-ref, separate instance) |
| campaignId | 1 | ApiSelectV2 | "Select campaign" | optional | Query: `GetCampaigns`; ISSUE-8 — only show if Campaign entity is populated for this tenant |
| totalAmountDisplay | 2 | amount banner (readonly) | — | — | Large amber gradient banner: "Total Amount Due: $X.XX" + tier label |
| membershipFee | 2 | currency (readonly) | — | — | 3-col summary card: Membership Fee |
| joiningFee | 2 | currency (readonly) | — | — | 3-col summary card: Joining Fee |
| totalAmountSummary | 2 | currency (readonly, accent) | — | — | 3-col summary card: Total (accent-colored) |
| paymentModeId | 2 | payment-method-card-list (5 cards) | — | required | Visual radio-card list (Card/Bank/Cash/Cheque/Waive); conditional sub-form expands inside selected card |
| cardNumber (transient) | 2 | text (masked) | "4242 4242 4242 4242" | required when Mode=CARD | **NOT persisted** (PCI); only last-4 stored |
| cardExpiry (transient) | 2 | text MM/YY | "MM/YY" | required when Mode=CARD | NOT persisted |
| cardCvv (transient) | 2 | password | "123" | required when Mode=CARD | NOT persisted |
| cardSavedForAutoRenew | 2 | checkbox | "Save card for auto-renewal" | — | Only when Mode=CARD and AutoRenew=true |
| bankRef | 2 | text | "Transaction reference" | required when Mode=BANK | Persisted to PaymentReference |
| chequeNo | 2 | text | "Cheque number" | required when Mode=CHQ | Persisted to PaymentReference |
| waiveReason | 2 | textarea | "Reason for waiving fee (required)" | required-when-WAIVE, min 10 | Admin-only label note; persisted |
| paymentDate | 2 | datepicker | "Today" default | required | — |
| enrollmentSummary | 3 | readonly-info-card | — | — | Displays: Member (name+code), Tier (emoji+name+price), Period, Payment (method+masked+amount), Auto-Renew (Yes/No), Branch |
| sendWelcomeEmail | 3 | checkbox | — | — | Default CHECKED |
| generateCard | 3 | checkbox | — | — | Default CHECKED; SERVICE_PLACEHOLDER for PDF generation |
| addToNewsletter | 3 | checkbox | — | — | Default CHECKED; SERVICE_PLACEHOLDER for segment add |
| sendWelcomeKit | 3 | checkbox | — | — | Default UNCHECKED; SERVICE_PLACEHOLDER for fulfillment |

**Special Form Widgets**:

- **Tier Card Selector** (NEW — build as reusable component `tier-card-selector.tsx`):

  | Card | Visual | Triggers |
  |------|--------|----------|
  | Per-tier card | Emoji (large) + TierName (bold) + Price (amber) + Period + Description + "Select" button | On select: border→amber + checkmark badge + refresh Benefits Preview + set membershipFee from tier + compute membershipPeriod |

  Cards populated dynamically from `GetMembershipTiers` response. Grid: `auto-fill, minmax(200px, 1fr)`.

- **Conditional Sub-forms** (inside payment method card):

  | Trigger Field | Trigger Value | Sub-form Fields |
  |--------------|---------------|-----------------|
  | paymentModeId | CARD | cardNumber (masked), cardExpiry, cardCvv, cardSavedForAutoRenew (if AutoRenew=true) |
  | paymentModeId | BANK | bankRef |
  | paymentModeId | CHQ | chequeNo |
  | paymentModeId | CASH | (no sub-form — PaymentReference nullable) |
  | paymentModeId | WAIVE | waiveReason (textarea, required min 10) |

- **Inline Mini Display — Contact Card**:

  | Widget | Trigger | Content |
  |--------|---------|---------|
  | Contact Card | When contactId selected | Avatar (initials gradient), Name (bold), Email + Phone row, Location + Code badge row, X button to clear selection |

- **Inline Alert — Existing Member Warning**:

  | Widget | Trigger | Content |
  |--------|---------|---------|
  | Amber warning box | When selected ContactId already has an Active membership | "This contact already has an active {TierName} membership expiring {EndDate}. Consider renewal instead." with link to #60 |

**Child Grids in Form**: NONE

**Wizard Step-Gating Rules** (enforced client-side + validated on Complete):
- Step 1 → Step 2: contactId + membershipTierId + startDate + branchId (optional but valid if provided) all populated
- Step 2 → Step 3: paymentModeId + mode-specific required fields filled
- Step 3 Complete: all required fields across all 3 steps valid; submit to `CreateMemberEnrollment`

---

#### LAYOUT 2: DETAIL (mode=read) — FULL-WIDTH SINGLE COLUMN + 4 TABS

> The read-only detail page — **NOT a 2-column card layout**. It's a full-width single-column design with a header, 5-card stats row, and a tabbed content card.

**Page Header**: `FlowFormPageHeader` extended with:
- Back button → grid
- **Tier badge pill** (large, with emoji + tier name + tier color) + Member Name (h1)
- Meta row (below title): MEM-XXXX code + Status dot+badge + "Since {StartDate}" + Contact link (CON-XXXX)
- Header Action Buttons (right):
  1. **Edit** (`ph:pencil`, outline) → `?mode=edit&id=X`
  2. **Renew** (`ph:arrows-clockwise`, amber outline) → navigate to `/crm/membership/membershiprenewal?source=X` (SERVICE_PLACEHOLDER until #60 built)
  3. **Upgrade/Downgrade** (`ph:arrow-up-right`, outline) — SERVICE_PLACEHOLDER (ISSUE-9)
  4. **Send Card** (`ph:identification-card`, outline) — SERVICE_PLACEHOLDER
  5. **More dropdown** (`ph:dots-three-vertical`): Send Email / Print Certificate / Export PDF / — / Suspend / Cancel Membership (danger)

**Quick Stats Row** (5 cards, 5-col → 3-col tablet → 2-col mobile — BELOW header, ABOVE tabs):

| # | Card Title | Value | Subtitle |
|---|-----------|-------|----------|
| 1 | Tier | Emoji + TierName | Price/Period ("$150/year") |
| 2 | Member Since | StartDate (MMM YYYY) | "X years, Y months" (computed) |
| 3 | Expires | EndDate or "Lifetime" | "N months remaining" (green if healthy, amber if ≤30d, red if expired) |
| 4 | Total Paid | currency sum | "N annual payments" (from PaymentHistory subquery — ISSUE-6) |
| 5 | Benefits Used | "8 of 10" | "80% utilization" (ISSUE-11 — deferred) |

**Page Layout** (below stats row):

| Column | Width | Content |
|--------|-------|---------|
| Main | full-width (1fr) | Single tabbed card with 4 tabs |

**Tabbed Detail Card (4 tabs)**:

**Tab 1 — Overview** (default active):
Two `info-section` blocks, each with 2-col `info-grid`:

| Info Section | Fields |
|-------------|--------|
| Membership Info | Member ID, Tier (emoji+name), Status (badge), Joined (date), Current Period ("{StartDate} – {EndDate}" or "Lifetime"), Auto-Renew (Yes/No + card last-4 if saved), Branch (OrgUnit name) |
| Contact Info | Contact Name, Email, Phone, Location, Contact Code (link badge), "Also a Donor" row (lifetime donation value, green) — ISSUE-10 for the donor-value join |

**Tab 2 — Payment History**:
Table columns: Date / Period / Amount / Method (icon+text) / Receipt (link — SERVICE_PLACEHOLDER for PDF) / Status
Data source: new query `GetMemberEnrollmentPaymentHistory` (pulls from `PaymentTransaction` or `GlobalDonation` joined via `MemberEnrollmentId` — see ISSUE-6).
V1 fallback: show ONE row (the enrollment's own payment) until the payment-transactions link is implemented (ISSUE-6).

**Tab 3 — Benefits**:
Table columns: Benefit (icon+name) / Status (Receiving/Sent/Invited/Eligible/Listed/Available/Not used) / Used (descriptive text + optional "Set Up" button for unused benefits — SERVICE_PLACEHOLDER)
Data source: derived from `MembershipTier.Benefits` JSON + `MembershipBenefitUsage` tracking (ISSUE-11 — deferred; V1 shows "No benefits tracked yet" empty state).

**Tab 4 — Activity**:
Vertical timeline component (reuse from Pledge #12 / RecurringDonation #8 if available; else create `membership-activity-timeline.tsx`). Items:
- Colored dot (enrollment=cyan, payment=green, reminder=amber, upgrade=amber-membership, suspension=orange, cancellation=red)
- Date (small, secondary)
- Action description
Data source: union of MemberEnrollment audit trail (Created/Approved/Suspended/Resumed/Cancelled) + payment events. V1: just enrollment state changes from audit columns (CreatedDate / ModifiedDate / ApprovedDate / SuspendedDate / CancelledDate) + hardcoded "Membership created" event.

**If mockup does NOT have a separate detail view**: N/A — this one has a fully different layout.

### Grid Aggregation Columns

**Aggregation Columns**: NONE (all computed fields live in GetAll projection, not per-row subquery)

### User Interaction Flow

1. User navigates to `/crm/membership/memberenrollment` → grid with 4 KPIs + 2 filter-chip groups + advanced filter panel
2. Clicks "Enroll Member" → `?mode=new` → 3-step wizard (step 1 active)
3. Step 1: selects Contact (inline card appears) + Tier card (benefits preview refreshes) + sets StartDate/Branch/AutoRenew → clicks Next
4. Step 2: sees amount banner + 3 fee cards + picks payment method card (sub-form expands) → fills fields → clicks Next
5. Step 3: reviews summary + toggles post-enrollment checkboxes → clicks Complete Enrollment
6. API creates record → URL redirects to `?mode=read&id={newId}` → DETAIL layout (header + 5 stats + 4 tabs)
7. From detail, user clicks Edit → `?mode=edit&id=X` → same wizard, all 3 steps pre-filled and navigable
8. User clicks Suspend / Cancel / Approve (modal) → status transition → detail refreshes
9. From grid, user clicks row → `?mode=read&id=X` → detail layout directly
10. Back button → grid (unsaved changes dialog if dirty)

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: SavedFilter (FLOW pattern) + RecurringDonationSchedule #8 (workflow commands + KPIs + alert banner — closest sibling for rich-state FLOW)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | MemberEnrollment | Entity/class name |
| savedFilter | memberEnrollment | Variable/field names |
| SavedFilterId | MemberEnrollmentId | PK field |
| SavedFilters | MemberEnrollments | Table name, collection names |
| saved-filter | member-enrollment | (unused — FE paths use no-dash form) |
| savedfilter | memberenrollment | FE folder, import paths |
| SAVEDFILTER | MEMBERENROLLMENT | Grid code, menu code |
| notify | mem | DB schema (**NEW**) |
| Notify | Mem | Backend group name (Models/Schemas/Business/Configurations) |
| NotifyModels | MemModels | Namespace suffix |
| NOTIFICATIONSETUP | CRM_MEMBERSHIP | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/membership/memberenrollment | FE route path |
| notify-service | mem-service | FE service folder name |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files (NEW — 19 files, including 5 workflow commands + summary query)

| # | File | Path |
|---|------|------|
| 1 | Entity | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/MemModels/MemberEnrollment.cs` |
| 2 | EF Config | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/MemConfigurations/MemberEnrollmentConfiguration.cs` |
| 3 | Schemas (DTOs) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/MemSchemas/MemberEnrollmentSchemas.cs` |
| 4 | Create Command | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/MemBusiness/MemberEnrollments/CreateCommand/CreateMemberEnrollment.cs` |
| 5 | Update Command | `.../MemberEnrollments/UpdateCommand/UpdateMemberEnrollment.cs` |
| 6 | Delete Command | `.../MemberEnrollments/DeleteCommand/DeleteMemberEnrollment.cs` |
| 7 | Toggle Command | `.../MemberEnrollments/ToggleCommand/ToggleMemberEnrollment.cs` |
| 8 | Approve Command | `.../MemberEnrollments/ApproveCommand/ApproveMemberEnrollment.cs` |
| 9 | Reject Command | `.../MemberEnrollments/RejectCommand/RejectMemberEnrollment.cs` |
| 10 | Suspend Command | `.../MemberEnrollments/SuspendCommand/SuspendMemberEnrollment.cs` |
| 11 | Resume Command | `.../MemberEnrollments/ResumeCommand/ResumeMemberEnrollment.cs` |
| 12 | Cancel Command | `.../MemberEnrollments/CancelCommand/CancelMemberEnrollment.cs` |
| 13 | CheckExpiries Command | `.../MemberEnrollments/CheckExpiriesCommand/CheckMemberEnrollmentExpiries.cs` (job-callable) |
| 14 | GetAll Query | `.../MemberEnrollments/GetAllQuery/GetAllMemberEnrollment.cs` |
| 15 | GetById Query | `.../MemberEnrollments/GetByIdQuery/GetMemberEnrollmentById.cs` |
| 16 | GetSummary Query | `.../MemberEnrollments/GetSummaryQuery/GetMemberEnrollmentSummary.cs` |
| 17 | GetPaymentHistory Query | `.../MemberEnrollments/GetPaymentHistoryQuery/GetMemberEnrollmentPaymentHistory.cs` (V1 stub — ISSUE-6) |
| 18 | Mutations | `Pss2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Mem/Mutations/MemberEnrollmentMutations.cs` |
| 19 | Queries | `Pss2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Mem/Queries/MemberEnrollmentQueries.cs` |

### Backend Wiring Updates (NEW module infrastructure — larger than usual)

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Base.Application/Common/Interfaces/IMemDbContext.cs` (**NEW**) | Interface for `mem` schema context with `DbSet<MemberEnrollment>` |
| 2 | `Base.Infrastructure/Data/MemDbContext.cs` (**NEW**) | Concrete DbContext for mem schema, inherits base context pattern |
| 3 | `Base.Application/Common/Decorators/DecoratorProperties.cs` | Add `DecoratorMemModules.MemberEnrollment` decorator class |
| 4 | `Base.Application/Mappings/MemMappings.cs` (**NEW**) | Mapster TypeAdapterConfig for MemberEnrollment ↔ DTO |
| 5 | `Base.Application/Common/GlobalUsing.cs` | Add `global using MemModels` if project uses global using |
| 6 | `Base.Infrastructure/Data/ApplicationDbContextFactory.cs` | Register `mem` schema if factory pattern used |
| 7 | `Base.API/Program.cs` or `Startup.cs` | Register MemDbContext + MediatR handlers for MemBusiness assembly |
| 8 | EF Migration | `Add_MemberEnrollment_And_MemSchema` — creates schema + table + indexes + FKs |

### Frontend Files (14 files — FLOW + wizard + tier-card-selector + payment-cards + 4-tab detail)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/mem-service/MemberEnrollmentDto.ts` |
| 2 | GQL Query | `Pss2.0_Frontend/src/infrastructure/gql-queries/mem-queries/MemberEnrollmentQuery.ts` |
| 3 | GQL Mutation | `Pss2.0_Frontend/src/infrastructure/gql-mutations/mem-mutations/MemberEnrollmentMutation.ts` |
| 4 | Page Config | `Pss2.0_Frontend/src/presentation/pages/crm/membership/memberenrollment.tsx` |
| 5 | Index Dispatcher | `Pss2.0_Frontend/src/presentation/components/page-components/crm/membership/memberenrollment/index.tsx` |
| 6 | Index Page (Variant B) | `.../memberenrollment/index-page.tsx` |
| 7 | **View Page (3 modes)** | `.../memberenrollment/view-page.tsx` |
| 8 | **Wizard Form (Step 1+2+3 orchestrator)** | `.../memberenrollment/memberenrollment-wizard-form.tsx` |
| 9 | **Detail Page (header + 5-stats + 4-tabs)** | `.../memberenrollment/memberenrollment-detail-page.tsx` |
| 10 | **Zustand Store** | `.../memberenrollment/memberenrollment-store.ts` |
| 11 | **KPI Widgets** | `.../memberenrollment/memberenrollment-widgets.tsx` |
| 12 | **Filter Chips** | `.../memberenrollment/memberenrollment-filter-chips.tsx` |
| 13 | **Advanced Filters** | `.../memberenrollment/memberenrollment-advanced-filters.tsx` |
| 14 | Route Page (OVERWRITE stub) | `Pss2.0_Frontend/src/app/[lang]/(core)/crm/membership/memberenrollment/page.tsx` |

**NEW Reusable Components** (5 — may be in shared folders for future reuse):

| # | Component | Path | Notes |
|---|-----------|------|-------|
| R1 | **`<FlowWizardStrip>`** | `src/presentation/components/common/flow-wizard-strip/flow-wizard-strip.tsx` | Reusable 3+ step wizard bar; first screen to use it |
| R2 | **`<TierCardSelector>`** | `.../memberenrollment/tier-card-selector.tsx` | Visual tier card grid; screen-local (may hoist later) |
| R3 | **`<PaymentMethodCardList>`** | `src/presentation/components/common/payment-method-card-list/payment-method-card-list.tsx` | 5-card visual payment picker with conditional sub-forms; reusable |
| R4 | **`<InlineContactCard>`** | `src/presentation/components/common/inline-contact-card/inline-contact-card.tsx` | Small contact summary card; likely reused by Beneficiary/Case |
| R5 | **Cell renderers**: `tier-badge` + `member-status-badge` + `contact-link-badge` | `src/presentation/components/custom-components/data-tables/shared-cell-renderers/` | Register in advanced/basic/flow component-column registries |

**Component Reuse-or-Create check** (per feedback memory): FE agent must search shared renderers first. If `contact-link-badge` exists from Contact #18 work, REUSE. Otherwise create.

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `src/domain/entities/mem-service/entity-operations.ts` (**NEW folder**) | `MEMBERENROLLMENT` operations config |
| 2 | `src/domain/entities/operations-config.ts` | Import + register `memEntityOperations` |
| 3 | Sidebar menu config (data-driven from DB seed — auto) | Menu entry via seed |
| 4 | Route config | App Router auto-picks up `[lang]/(core)/crm/membership/memberenrollment/page.tsx` |
| 5 | 3 column-type registries (advanced / basic / flow) | Register new renderer keys: `tier-badge`, `member-status-badge`, `contact-link-badge` |
| 6 | `shared-cell-renderers/index.ts` barrel | Export 3 new renderers |
| 7 | `gql-queries/index.ts` / `gql-mutations/index.ts` barrels | Export new Q/M |
| 8 | `mem-service/index.ts` (**NEW**) barrel | Export MemberEnrollmentDto |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

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
OrderBy: 2
---CONFIG-END---
```

**MasterData TypeCodes to seed** (6 new rows total across 1 new type + existing type additions):
- New `MEMBERSTATUS` TypeCode (or `MEMBERENROLLMENTSTATUS`): 6 values — Pending (blue #2563eb), Active (green #16a34a), ExpiresSoon (amber #d97706) — *computed but add for explicit state*, Expired (gray #6b7280), Suspended (orange #ea580c), Cancelled (red #dc2626)
- Ensure `PAYMENTMODE` has rows: CARD, BANK, CASH, CHQ, WAIVE (add any missing, idempotent)

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types**:
- Query type: `MemberEnrollmentQueries` (extends `ObjectType` at `OperationTypeNames.Query`)
- Mutation type: `MemberEnrollmentMutations` (extends at `OperationTypeNames.Mutation`)

**Queries**:
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getAllMemberEnrollmentList` | `[MemberEnrollmentResponseDto]` + `totalCount` | searchText, pageNo, pageSize, sortField, sortDir, isActive, tierCode, statusCode, joinDateFrom, joinDateTo, renewalDueBucket, branchId, daysUntilExpiryMax, advancedFilter |
| `getMemberEnrollmentById` | `MemberEnrollmentResponseDto` | memberEnrollmentId |
| `getMemberEnrollmentSummary` | `MemberEnrollmentSummaryDto` | — (tenant-scoped) |
| `getMemberEnrollmentPaymentHistory` | `[MemberEnrollmentPaymentHistoryDto]` | memberEnrollmentId (V1 stub — returns just enrollment's own payment row) |

**Mutations**:
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createMemberEnrollment` | MemberEnrollmentRequestDto | int (new ID) |
| `updateMemberEnrollment` | MemberEnrollmentRequestDto | int |
| `deleteMemberEnrollment` | memberEnrollmentId | int |
| `toggleMemberEnrollment` | memberEnrollmentId | int |
| `approveMemberEnrollment` | { memberEnrollmentId } | int |
| `rejectMemberEnrollment` | { memberEnrollmentId, rejectionReason } | int |
| `suspendMemberEnrollment` | { memberEnrollmentId, suspensionReason, suspendedDate } | int |
| `resumeMemberEnrollment` | { memberEnrollmentId } | int |
| `cancelMemberEnrollment` | { memberEnrollmentId, cancellationReason, cancelledDate } | int |

**Response DTO Fields** (`MemberEnrollmentResponseDto`):
| Field | Type | Notes |
|-------|------|-------|
| memberEnrollmentId | number | PK |
| memberCode | string | Auto-generated MEM-NNNN |
| contactId | number | FK |
| contactName | string | FK display (First + Last) |
| contactCode | string | FK display (CON-NNNN) |
| contactEmail | string? | Contact join |
| contactPhone | string? | Contact join |
| contactLocation | string? | Contact join (City/Country) |
| lifetimeDonationAmount | number? | For "Also a Donor" card (ISSUE-10) |
| membershipTierId | number | FK |
| tierName | string | FK display |
| tierEmoji | string? | Tier visual icon |
| tierColor | string? | Tier brand color hex |
| tierDescription | string? | Short description |
| tierBenefits | string[] | JSON-parsed benefits list |
| tierIsLifetime | boolean | — |
| tierDurationMonths | number? | — |
| startDate | string (ISO date) | — |
| endDate | string? (ISO date) | NULL for Lifetime |
| daysUntilExpiry | number? | Computed |
| statusId | number | FK MasterData |
| statusName | string | FK display |
| statusCode | string | FK code for UI logic |
| autoRenew | boolean | — |
| membershipFee | number | — |
| joiningFee | number | — |
| totalAmount | number | Computed |
| currencyId | number | — |
| currencyCode | string | FK display |
| paymentModeId | number | FK MasterData |
| paymentModeName | string | FK display |
| paymentModeCode | string | FK code for UI logic |
| paymentDate | string? (ISO date) | — |
| paymentReference | string? | — |
| paymentGatewayTxnId | string? | — |
| cardSavedForAutoRenew | boolean | — |
| waiveReason | string? | — |
| branchId | number? | — |
| branchName | string? | FK display (OrgUnit) |
| referredByContactId | number? | — |
| referredByContactName | string? | Self-ref FK display |
| campaignId | number? | — |
| campaignName | string? | FK display |
| sendWelcomeEmail | boolean | — |
| generateCard | boolean | — |
| addToNewsletter | boolean | — |
| sendWelcomeKit | boolean | — |
| suspendedDate | string? (ISO date) | — |
| suspensionReason | string? | — |
| cancelledDate | string? (ISO date) | — |
| cancellationReason | string? | — |
| approvedByStaffId | number? | — |
| approvedByStaffName | string? | FK display |
| approvedDate | string? (ISO date) | — |
| notes | string? | — |
| isActive | boolean | Inherited |
| createdDate | string (ISO date) | Inherited (NOT createdAt) |
| modifiedDate | string (ISO date) | Inherited (NOT modifiedAt) |

**Summary DTO Fields** (`MemberEnrollmentSummaryDto`):
| Field | Type | Notes |
|-------|------|-------|
| totalMembers | number | count of non-deleted |
| activeCount | number | statusCode=ACT |
| expiredCount | number | statusCode=EXP |
| pendingCount | number | statusCode=PEN |
| cancelledCount | number | statusCode=CAN |
| suspendedCount | number | statusCode=SUS |
| revenueYtd | number | SUM TotalAmount WHERE YEAR(PaymentDate)=current |
| yoyGrowthPercent | number | computed (revenueYtd / revenueYtdLastYear − 1) × 100 |
| renewalsDueCount | number | count EndDate in next 30 days, not Cancelled |
| renewalsAtRiskAmount | number | SUM TotalAmount of renewalsDue |
| newMembersThisMonth | number | count StartDate in current month |
| topTierThisMonth | string? | tier name with most enrollments this month |
| defaultCurrencyCode | string | For UI display |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors (requires #58 MembershipTier BE to be built FIRST or stub — see ISSUE-1)
- [ ] `pnpm dev` — page loads at `/[lang]/crm/membership/memberenrollment`
- [ ] EF migration `Add_MemberEnrollment_And_MemSchema` applied (creates `mem` schema + table + 8 FK constraints + indexes)

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with all 10 columns
- [ ] Search filters by: member code, contact name, email, phone
- [ ] 2 filter-chip groups independently filter grid (Tier + Status)
- [ ] Advanced filter panel opens/closes; 4 fields apply filters correctly
- [ ] 4 KPI widgets display with correct values (from GetMemberEnrollmentSummary)
- [ ] **`?mode=new` — 3-step wizard**:
  - [ ] Step 1 active, Steps 2+3 locked
  - [ ] Contact search fires ApiSelect query; selection renders inline contact card with clear button
  - [ ] Tier card grid loads from GetMembershipTiers; selection highlights card + refreshes benefits preview
  - [ ] Existing-member warning box appears when selected Contact has active membership
  - [ ] StartDate/Branch/AutoRenew work; membershipPeriod auto-computes ("Jan 2026 – Jan 2027" or "Lifetime")
  - [ ] Next button enables only when required Step 1 fields valid
  - [ ] Step 2: amount banner shows total; 3 summary cards populate; 5 payment method cards visible
  - [ ] Payment method selection expands conditional sub-form (CARD: number/expiry/cvv/save-card; BANK: ref; CHQ: chequeNo; WAIVE: reason)
  - [ ] Step 3: summary card shows all prior choices; 4 post-action checkboxes (3 default CHECKED, 1 default UNCHECKED)
  - [ ] Complete Enrollment → POST createMemberEnrollment → receives new ID → redirect to `?mode=read&id={newId}`
- [ ] **`?mode=edit&id=X`**: wizard pre-fills all 3 steps with existing data; all steps clickable (not gated in edit)
- [ ] **`?mode=read&id=X` — DETAIL layout**:
  - [ ] Header renders with tier badge + name + status + member/contact codes
  - [ ] 5 header action buttons render; dropdown has Suspend/Cancel + Send Email/Print/Export
  - [ ] 5 quick-stat cards display correct values
  - [ ] 4 tabs render; default = Overview
  - [ ] Overview tab: 2 info-section blocks (Membership Info + Contact Info) with 2-col grids
  - [ ] Payment History tab: table with 1+ row (V1 stub for multi-payment per ISSUE-6)
  - [ ] Benefits tab: shows empty state V1 OR benefits table (depending on ISSUE-11 resolution)
  - [ ] Activity tab: timeline with at least "Membership Created" event
- [ ] Edit button on detail → `?mode=edit&id=X` → wizard pre-filled → Save → back to detail
- [ ] Renew button → navigates to renewal screen (SERVICE_PLACEHOLDER until #60 built)
- [ ] **Workflow transitions**:
  - [ ] Pending row → Approve inline → modal confirm → status=Active + ApprovedBy/Date set
  - [ ] Pending row → Reject dropdown → modal (reason required) → status=Cancelled
  - [ ] Active row → Suspend dropdown → modal (reason + date) → status=Suspended
  - [ ] Suspended row → Resume dropdown → modal confirm → status=Active
  - [ ] Any row → Cancel dropdown → modal (reason + date) → status=Cancelled
- [ ] FK ApiSelects load: Contact / MembershipTier / OrgUnit / Currency / Campaign
- [ ] MEM code auto-generated (MEM-0001, MEM-0002, … per Company)
- [ ] Lifetime tier selection sets EndDate=NULL, disables AutoRenew toggle
- [ ] AutoRenew toggle ON + PaymentMode=CARD shows cardSavedForAutoRenew checkbox
- [ ] AutoRenew toggle OFF or PaymentMode≠CARD hides cardSavedForAutoRenew checkbox
- [ ] WaiveReason required when PaymentMode=WAIVE (form blocks submit until filled)
- [ ] Unsaved changes dialog triggers on wizard step-click with dirty form
- [ ] Unsaved changes dialog triggers on Back button / grid row click with dirty form
- [ ] Toast messages render for service placeholders (Send Card / Import / Export / Welcome Kit / Generate Card)
- [ ] Permissions: Edit/Delete/Approve buttons respect BUSINESSADMIN capabilities

**UI Uniformity Grep Checks (5 MUST be zero):**
- [ ] 0 inline hex in `style={{...}}` (except renderer-local BRAND_MAP constants per PaymentReconciliation #14 precedent)
- [ ] 0 inline px values
- [ ] 0 raw "Loading..." strings
- [ ] 0 `fa-*` icon classes (all must be `ph:*` Phosphor via @iconify)
- [ ] 0 hex in Skeleton components

**DB Seed Verification:**
- [ ] MEMBERENROLLMENT menu visible in sidebar under CRM_MEMBERSHIP at OrderBy=2
- [ ] Grid columns render correctly (10 columns, GridFormSchema=NULL per FLOW convention)
- [ ] MEMBERSTATUS MasterDataType seeded with 6 rows + ColorHex
- [ ] PAYMENTMODE MasterData has WAIVE row (add idempotently if absent)
- [ ] `sql-scripts-dyanmic/` folder typo preserved (ChequeDonation #6 ISSUE-15 precedent)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **NEW module infrastructure required** — this is the FIRST entity in `mem` schema. BE dev must create:
  - `IMemDbContext.cs` interface + `MemDbContext.cs` concrete
  - `MemBusiness` / `MemSchemas` / `MemConfigurations` folder trees
  - Register `MemDbContext` in `Program.cs` / `Startup.cs` DI container
  - Add `mem` schema creation to EF migration (before table creation)
  - Add `DecoratorMemModules` class in `DecoratorProperties.cs`
  - Create `MemMappings.cs` with Mapster `TypeAdapterConfig<MemberEnrollment, MemberEnrollmentResponseDto>`
- **CompanyId is NOT a field** in the table — it comes from HttpContext
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it
- **view-page.tsx handles ALL 3 modes** — new/edit share FORM (wizard) layout, read has DETAIL (single-col + 4 tabs) layout
- **DETAIL layout is a separate UI**, not the form disabled — do NOT wrap wizard in fieldset
- **Wizard is NON-CANONICAL for FLOW** — this is the first FLOW screen using a 3-step wizard strip. Create `<FlowWizardStrip>` as reusable in `common/flow-wizard-strip/` for future screens (Onboarding, Multi-step registrations)
- **Contact FK uses CorgModels**, NOT AppModels (confirmed from Ambassador #67 and Beneficiary #49)
- **MembershipTier FK uses MemModels** (SAME group as this entity — but does NOT exist yet: see ISSUE-1)
- **For FULL scope**: overwrite existing stub page.tsx entirely; do not preserve stub content
- **Preserve `sql-scripts-dyanmic/` folder typo** per ChequeDonation #6 ISSUE-15 precedent

**Service Dependencies** (UI fully built — handlers use toast placeholder because external service isn't wired):

- ⚠ **SERVICE_PLACEHOLDER**: **Send Card (PDF generation)** — UI button on detail header. Handler calls toast "Card generation coming soon" because no PDF service layer exists yet. Same as ChequeDonation #6 ISSUE-27 / InKindDonation #7 Receipt PDF.
- ⚠ **SERVICE_PLACEHOLDER**: **Send Welcome Email / Renewal Reminders / Bulk Reminders** — UI checkboxes and bulk-action button. Handler persists flag + emits toast. Actual email dispatch requires notification service not yet wired (same as Pledge #12 ISSUE-SERVICE).
- ⚠ **SERVICE_PLACEHOLDER**: **Generate Membership Card (PDF)** — Step 3 checkbox + detail header button. Flag persisted; PDF generation is a no-op with toast.
- ⚠ **SERVICE_PLACEHOLDER**: **Send Physical Welcome Kit** — Step 3 checkbox. Flag persisted; fulfillment workflow doesn't exist.
- ⚠ **SERVICE_PLACEHOLDER**: **Add to Newsletter Segment** — Step 3 checkbox. Flag persisted; requires Email Campaign Builder / Segmentation (TagSegmentation #22 built, but auto-add hook not wired).
- ⚠ **SERVICE_PLACEHOLDER**: **Payment Gateway Integration (Online Card)** — CARD payment mode captures card data client-side but does NOT process. `PaymentGatewayTxnId` captured as placeholder; real gateway call is out-of-scope. Same as RecurringDonationSchedule #8 ISSUE-SERVICE (UpdatePayment).
- ⚠ **SERVICE_PLACEHOLDER**: **Import Members (CSV bulk)** — toolbar button. Toast "Import coming soon."
- ⚠ **SERVICE_PLACEHOLDER**: **Export Members** — toolbar and bulk-actions button. Toast "Export coming soon" (platform-wide unimplemented).
- ⚠ **SERVICE_PLACEHOLDER**: **Print Certificate / Export PDF (detail dropdown)** — Toast.
- ⚠ **SERVICE_PLACEHOLDER**: **Upgrade/Downgrade Tier** — detail header button; requires dedicated upgrade flow not in this screen's scope (ISSUE-9).
- ⚠ **SERVICE_PLACEHOLDER**: **Renew Membership** — button on detail + row action for Expires Soon/Expired; navigates to `/crm/membership/membershiprenewal?source=X`. Screen #60 not yet built (PARTIAL).
- ⚠ **SERVICE_PLACEHOLDER**: **New Contact (inline form)** — Step 1 link. Toast "Inline contact creation coming soon." User must use full Contact screen to create first.
- ⚠ **SERVICE_PLACEHOLDER**: **Benefit "Set Up" button** — Benefits tab per-row action. Toast "Benefit activation coming soon" (ISSUE-11).
- ⚠ **SERVICE_PLACEHOLDER**: **Daily expiry check** — `CheckMemberEnrollmentExpiries` command exists BE-side but cron/hosted-service scheduling is infra task (ISSUE-5). Admin can manually trigger via mutation for now.

Full UI must be built (buttons, wizard, cards, 5 stats, 4 tabs, modals, interactions). Only the handlers for the external service calls above are mocked.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Planning | **CRITICAL** | BE | **HARD BUILD BLOCKER**: MembershipTier entity (#58) does not exist in BE. MemberEnrollment has required FK to `mem.MembershipTiers`. BE cannot compile without it. RESOLUTION: Either (a) build #58 BE first (recommended — it's P1-Setup, no FK deps), OR (b) build #58 BE in same session as #59 (co-generate), OR (c) stub MembershipTierId as an int with no navigation property + no EF FK constraint (risky; must be retrofitted later). Orchestrator MUST prompt user before starting build. | OPEN |
| ISSUE-2 | Planning | HIGH | BE | NEW `mem` schema + `IMemDbContext` infrastructure required before any BE entity can compile. Adds ~8 wiring files beyond standard 4. Refer to Volunteer #53 `vol` schema precedent when it's built, or look at existing `fund` / `crm` / `notify` schemas for pattern. | OPEN |
| ISSUE-3 | Planning | MED | BE+FE | "Expires Soon" is NOT a persisted status — it's a computed flag (EndDate - today ≤ 30). Decide whether to (a) expose as a computed `isExpiringSoon` boolean in DTO + badge renderer mapping, OR (b) include ExpiresSoon as a 6th MasterData row with runtime auto-transition (heavier, but consistent with StatusId). Recommend (a). | OPEN |
| ISSUE-4 | Planning | MED | BE | Default status on Create: should be `Pending` (requires approval) for self-registered imports, but `Active` for staff-entered enrollments. Decide based on: (a) add `skipApproval` bool to Create command (default false, set true when user has high role), OR (b) always Create as Pending and require manual Approve. Recommend (a) with role check. | OPEN |
| ISSUE-5 | Planning | MED | BE | Daily expiry check: `CheckMemberEnrollmentExpiries` command exists, but scheduling is infra task. Options: (a) IHostedService in BE app, (b) Hangfire/Quartz if already in stack, (c) external cron hitting a GraphQL mutation endpoint. Defer to infra team; document in Build Log. | OPEN |
| ISSUE-6 | Planning | MED | BE+FE | Payment History tab data source unclear: enrollment may link to `PaymentTransaction` or `GlobalDonation` via MemberEnrollmentId (FK doesn't exist yet). V1: `GetMemberEnrollmentPaymentHistory` returns ONE row derived from the enrollment's own fields (date, amount, mode, status). V2: real join once PaymentTransaction table exposes `MemberEnrollmentId` nullable FK or we add `MembershipPayment` child entity. | OPEN |
| ISSUE-7 | Planning | MED | BE+FE | "Also a Donor" card on Overview tab requires `lifetimeDonationAmount` = SUM(GlobalDonation WHERE ContactId=row.ContactId). Implement as LINQ subquery in GetById projection (N+1 safe for single-row). Skip in GetAll to avoid perf hit. | OPEN |
| ISSUE-8 | Planning | LOW | BE+FE | CampaignId FK is optional in mockup (shown as "source campaign" inference, not an explicit field). If source campaign tracking is not required for V1, remove from spec to simplify. Decide with BA. | OPEN |
| ISSUE-9 | Planning | MED | BE+FE | Upgrade/Downgrade Tier flow: detail header has "Upgrade/Downgrade" button but mockup does not show the upgrade form. Deferred — implement as SERVICE_PLACEHOLDER with toast. Future screen: create a dedicated Upgrade wizard that creates a new MemberEnrollment (with `JoiningFee=0`, prorated `MembershipFee`, and closes the old one with `Status=Cancelled` + `CancellationReason='Upgrade to {NewTier}'`). | OPEN |
| ISSUE-10 | Planning | LOW | BE+FE | "Also a Donor" card assumes Contact → GlobalDonation relationship. Verify Contact entity has `IEnumerable<GlobalDonation>` inverse navigation or aggregate query exists. If not, add subquery in MemberEnrollment GetById projection. | OPEN |
| ISSUE-11 | Planning | MED | BE+FE | Benefits tab: mockup shows per-benefit Status + Used columns with "Set Up" action. Requires `MembershipBenefitUsage` entity + `MembershipTier.Benefits` JSON → parsed rows. **DEFERRED to V2**. V1: show "No benefits tracked yet" empty state. Tab remains in UI. | OPEN |
| ISSUE-12 | Planning | LOW | FE | `<FlowWizardStrip>` is a new reusable component. Location decision: (a) `common/flow-wizard-strip/` for cross-feature reuse, OR (b) local to `memberenrollment/` for now. Recommend (a) with 1-step-forward investment. | OPEN |
| ISSUE-13 | Planning | LOW | FE | `<PaymentMethodCardList>` duplicates pattern from ChequeDonation #6 / Pledge #12 form payment sections but with visual radio-card UX. Decide whether to refactor existing usages to use this new component OR leave as forked implementations. Recommend: leave existing, use new for MemberEnrollment only, consolidate in a future ui-uniformity pass. | OPEN |
| ISSUE-14 | Planning | LOW | BE | Unique index on (ContactId, StatusId) where StatusId IN (Active, Suspended, Pending, ExpiresSoon) to enforce one-active-per-contact rule at DB level. Filtered unique index — supported by Postgres. Include in EF migration. | OPEN |
| ISSUE-15 | Planning | LOW | DB seed | `sql-scripts-dyanmic/` folder has typo per ChequeDonation #6 ISSUE-15 precedent — preserve spelling. Seed file: `MemberEnrollment-sqlscripts.sql`. | OPEN |
| ISSUE-16 | Planning | LOW | FE | Tier color/emoji: mockup shows emoji per tier (🥉🥈🥇💎⭐) and tier-branded colors. Persist `tierEmoji` + `tierColor` on MembershipTier entity (#58 spec). Renderer `tier-badge` reads from projection; fallback to static map if null. | OPEN |
| ISSUE-17 | Planning | LOW | FE | Card number / CVV / expiry captured in Step 2 must NEVER hit the backend (PCI). Client-side only; only last-4 digits persisted to `PaymentReference`. RHF form must explicitly exclude these fields from submit payload. Add safety guard. | OPEN |
| ISSUE-18 | Planning | LOW | FE | Icon conversion: all `fa-*` icons in mockup must map to `ph:*` Phosphor per UI uniformity memory. Full mapping: fa-id-card→ph:identification-card, fa-arrows-rotate→ph:arrows-clockwise, fa-arrow-up-right-dots→ph:arrow-up-right, fa-clock-rotate-left→ph:clock-counter-clockwise, fa-circle-info→ph:info, fa-building-columns→ph:bank, fa-money-bill-wave→ph:money, fa-money-check→ph:check-square, fa-hand-holding-heart→ph:hand-heart, fa-clipboard-check→ph:clipboard-text, fa-vote-yea→ph:check-circle. | OPEN |
| ISSUE-19 | Planning | LOW | FE | Page layout decision: mockup's detail view is full-width single column with 4 tabs, NOT the typical 2-column (left 2fr / right 1fr) FLOW detail layout. Confirm with UX Architect before generation — this is a deviation from every prior FLOW screen (ChequeDonation/Refund/Pledge/RecurringDonation all use 2-col). | OPEN |
| ISSUE-20 | Planning | LOW | FE | Renew button on detail header + row actions navigates to `/crm/membership/membershiprenewal?source=X`. #60 is PARTIAL (FE stub only). Until built, the navigation lands on a blank page. Mitigation: SERVICE_PLACEHOLDER toast "Renewal coming soon — #60 not yet built." | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

No sessions recorded yet — filled in after /build-screen completes.