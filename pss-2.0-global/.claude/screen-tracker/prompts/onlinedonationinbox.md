---
screen: OnlineDonationInbox
registry_id: 175
module: CRM (Donation)
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-05-29
completed_date: 2026-05-29
last_session_date: 2026-06-01
---

## Tasks

### Planning (by /plan-screens)
- [x] Source analyzed (user spec — staff processing screen for `fund.OnlineDonationStagings`; companion to Online Donation Page #10)
- [x] Existing code reviewed (staging entity, RunAutoReconciliation sibling, Contact queries/create, CreateGlobalDonationWithChildren, reconciliation FE workbench, global ContactCreateModal)
- [x] Business rules + 3 processes extracted (ContactCode auto/manual map · name+email/phone match-or-create · recurring verify)
- [x] FK / source targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (inline — codebase deps confirmed; prompt §② entity + DbSet verified)
- [x] Solution Resolution complete (pre-answered §⑤ confirmed — FLOW custom workbench, Reconciliation #14 sibling)
- [x] UX Design finalized (QUEUE workbench + PROCESS page + READ summary specified — §⑥ mockup-derived)
- [x] User Approval received (Sonnet all agents; full build, split FE spawns)
- [x] Backend code generated (10 files + Mapster; builds clean 0 errors)
- [x] Backend wiring complete (DonationMappings.cs; DbSet already registered — ISSUE-5 closed)
- [x] Frontend code generated (workbench index + view-page process/read modes + Zustand store) — tsc clean
- [x] Frontend wiring complete (incl. global ContactCreateModal `prefill` extension — additive, guarded)
- [x] DB Seed script generated (menu + caps + FLOW grid; GridFormSchema SKIP; guarded sample staging)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [x] `dotnet build` passes (Base.Application + Base.API, 0 errors) · `pnpm tsc --noEmit` clean (new files)
- [ ] `pnpm dev` — inbox loads at `/{lang}/crm/donation/onlinedonationinbox` — **runtime E2E pending → run `/test-screen #175`**
- [ ] Queue table lists unresolved COMPLETED staging rows with KPI cards above
- [ ] "Run Auto-Map" bulk-resolves ContactCode-matched + high-confidence name/email rows
- [ ] `?mode=process&id=X` — full processing page renders donor info + payment + contact resolution + donation preview (+ recurring panel if frequency)
- [ ] ContactCode path resolves the contact card; "Confirm" maps it
- [ ] Name/email/phone candidate list ranks matches; manual contact search works
- [ ] "Create new contact" opens the global ContactCreateModal prefilled from staging data; on create, the new contact is selected
- [ ] Promote creates `fund.GlobalDonation` + `GlobalOnlineDonation` child; staging row flips `IsResolved=true` with `PromotedGlobalDonationId`
- [ ] Recurring (FrequencyId set) creates a `RecurringDonationSchedule` (or SERVICE_PLACEHOLDER verify) on promote
- [ ] `?mode=read&id=X` for a resolved row shows the resolution summary + link to the promoted donation; promote is blocked (idempotent)
- [ ] DB Seed — menu visible in sidebar under CRM ▸ Donation

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: OnlineDonationInbox
Module: CRM ▸ Donation
Schema: `fund`
Group: DonationModels

Business: The **Online Donation Inbox** is the staff-facing operations queue that processes online donations captured by the public **Online Donation Page (#10)**. When a donor completes a payment on the public page, the gateway-confirmed donation is written to the **staging table `fund.OnlineDonationStagings`** (it is NOT yet a real donation — it carries only donor-*provided* text fields like name/email/phone/contact-code plus the gateway payment result). Processing staff open this inbox, review each staged donation, **identify or create the donor Contact**, and **promote** the staged row into the canonical `fund.GlobalDonations` ledger (with its `GlobalOnlineDonation` payment-detail child, and a `RecurringDonationSchedule` for recurring gifts). This screen is the bridge between anonymous public giving and the organization's contact-centric donation records. It is a **custom workbench** — architecturally a sibling of the **Payment Reconciliation (#14)** screen (`crm/donation/reconciliation`): a filterable queue + KPI cards + a bulk "Run Auto-Map" action + a per-row resolution flow. It is NOT a CRUD screen — staff never hand-create staging rows; they resolve system-generated ones.

**The three processes (initial scope — more "will come"):**
1. **ContactCode match** — donor supplied a `ProvidedContactCode`; auto/manually map to the existing Contact and promote.
2. **Name + email/phone match-or-create** — no usable code; rank candidate Contacts by email/phone/name; staff picks one or **creates a new Contact** (prefilled from staging data) and promotes.
3. **Recurring verification** — staged row has a `FrequencyId`; on promote, verify/create the recurring subscription + `RecurringDonationSchedule`. Applies to BOTH the contact-exists and new-contact paths.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **This screen creates NO new entity and runs NO Create/Update/Delete on staging.** It READS `fund.OnlineDonationStagings` (built with #10) and WRITES only the resolution fields via the Resolve command, then creates a `GlobalDonation` via the existing composite command. No migration is needed unless the wiring audit (below) finds the staging DbSet missing.

### Source (read) entity — `fund.OnlineDonationStagings` (EXISTING — do NOT recreate)

Entity: `Base.Domain/Models/DonationModels/OnlineDonationStaging.cs`
EF Config: `Base.Infrastructure/Data/Configurations/DonationConfigurations/OnlineDonationStagingConfiguration.cs`

| Field | C# Type | Notes |
|-------|---------|-------|
| OnlineDonationStagingId | int | PK |
| CompanyId | int | tenant |
| OnlineDonationPageId | int | FK → fund.OnlineDonationPages |
| PaymentSessionId | string | unique correlation |
| Amount | decimal(18,2) | |
| CurrencyId | int | FK → Currencies |
| DonationModeId | int | MasterData DONATIONMODE (expect OD) |
| DonationTypeId | int | MasterData DONATIONTYPE |
| DonationPurposeId | int? | FK → fund.DonationPurposes |
| FrequencyId | int? | MasterData RECURRINGFREQUENCY — **non-null ⇒ recurring** |
| ProvidedContactCode | string? | donor-entered → **Process 1** |
| ProvidedFirstName | string | → **Process 2** |
| ProvidedLastName | string | → **Process 2** |
| ProvidedEmail | string | → **Process 2** |
| ProvidedPhone | string? | → **Process 2** |
| ProvidedAddress | string? | for new-contact prefill |
| ProvidedOrganization | string? | for new-contact prefill |
| ProvidedMessage | string? | donor note |
| IsAnonymous | bool | see §④ anonymous rule |
| DedicateNote | string? | |
| PaymentStatusId | int | MasterData PAYMENTSTATUS — **only COMPLETED is promotable** |
| CompanyPaymentGatewayId | int | |
| PaymentGatewayId | int | denormalized |
| PaymentMethodId | int | MasterData PAYMENTMETHOD |
| GatewayTransactionId | string? | (recurring: may carry Braintree subscription id) |
| GatewayResponseCode/Message | string? | |
| GatewayAuthorizationCode | string? | |
| ReceivedDate | DateTime? | capture timestamp |
| IPAddress / UserAgent | string? | |
| **IsResolved** | bool | the inbox gate — false = needs processing |
| **ResolvedContactId** | int? | FK → con.Contacts — set on resolve |
| **PromotedGlobalDonationId** | int? | FK → fund.GlobalDonations — set on promote (idempotency guard) |
| **ResolvedByUserId** | int? | FK → adm.Users |
| **ResolvedDate** | DateTime? | |

Index already present: `IX_OnlineDonationStagings_Company_Status_Resolved (CompanyId, PaymentStatusId, IsResolved)` — the queue's primary filter index.

### Target (write) entities — EXISTING composite (do NOT recreate)
- `fund.GlobalDonations` (`GlobalDonation.cs`) — canonical donation. Created via `CreateGlobalDonationWithChildrenCommand`.
- `fund.GlobalOnlineDonations` (`GlobalOnlineDonation.cs`) — OD payment-detail child.
- `fund.RecurringDonationSchedules` (`RecurringDonationSchedule.cs`) — recurring subscription (Process 3).
- `con.Contacts` (+ `ContactEmailAddresses`, `ContactPhoneNumbers`) — created via `CreateContactCommand`.

---

## ③ FK / Source Resolution Table

> **Consumer**: Backend Developer (.Include + navs) + Frontend Developer (ApiSelect / pickers)

| Need | Target | File / Handler | GQL Name | Display / Key | Response DTO |
|------|--------|----------------|----------|---------------|--------------|
| Staging queue | OnlineDonationStaging | NEW `GetOnlineDonationStagingList.cs` | `onlineDonationStagingList` | — | `OnlineDonationStagingListDto` |
| Staging detail | OnlineDonationStaging | NEW `GetOnlineDonationStagingById.cs` | `onlineDonationStagingById` | — | `OnlineDonationStagingDetailDto` |
| KPI counts | — | NEW `GetOnlineDonationInboxSummary.cs` | `onlineDonationInboxSummary` | — | `OnlineDonationInboxSummaryDto` |
| Candidate matches | Contact | NEW `FindContactMatches.cs` (Process 2) | `findContactMatches` | DisplayName / ContactId | `ContactMatchCandidateDto` |
| ContactCode lookup | Contact | EXISTING `GetContactByCode.cs` | `contactByCode` | ContactCode → ContactDto | `ContactDto` |
| Manual contact search | Contact | EXISTING `GetContact.cs` (paginated) | `contacts` (`[AsParameters] request:`) | DisplayName | `ContactResponseDto` |
| Create contact | Contact | EXISTING `CreateContact.cs` | `createContact` (arg `contact: ContactRequestDtoInput!`) | — | `ContactRequestDto` |
| Promote donation | GlobalDonation+children | EXISTING `CreateGlobalDonationWithChildren.cs` | `createGlobalDonationWithChildren` (arg `payload:`) | — | composite result |
| Recurring schedule | RecurringDonationSchedule | EXISTING `CreateRecurringDonationSchedule.cs` | (verify resolver name in `RecurringDonationScheduleMutations.cs`) | — | — |
| Donation purpose (display) | DonationPurpose | `fund.DonationPurposes` | existing purposes query | DonationPurposeName | — |
| Currency / base currency | Currency / CompanyConfigurations | `CompanyConfigurations.BaseCurrencyId` | — | — | — |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer

**Eligibility / Status Rules:**
- Only staging rows with `PaymentStatus = COMPLETED` AND `IsResolved = false` are **promotable**. The queue defaults to this filter.
- `PENDING` rows = abandoned/incomplete payments (donor never finished) — shown under an "Abandoned" filter, NOT promotable; may be **dismissed**.
- `FAILED` rows = declined payments — shown under "Failed" filter, NOT promotable; may be **dismissed**.
- A row with `PromotedGlobalDonationId != null` is **already resolved** — read-only; promote is blocked server-side (idempotency guard — re-running auto-map must skip it).

**Process 1 — ContactCode:**
- If `ProvidedContactCode` is non-empty → resolve via `contactByCode`. If found → confidence = EXACT (score 100), eligible for auto-map.
- If the code is non-empty but does NOT resolve → fall through to Process 2 (name/email/phone). Surface a "code not found" hint to staff.

**Process 2 — Name + Email/Phone match-or-create:**
- `FindContactMatches` ranks candidate Contacts for a staging row by, in order:
  1. **Email exact** (join `con.ContactEmailAddresses` on `ProvidedEmail`, case-insensitive) → high score.
  2. **Phone exact** (join `con.ContactPhoneNumbers` on normalized `ProvidedPhone`) → high score.
  3. **Name match** (`FirstName` + `LastName` equals/contains `ProvidedFirstName`/`ProvidedLastName`) → medium score.
- Single high-confidence match (email or phone, exactly one contact) → eligible for auto-map. **Multiple matches = ambiguous → manual only** (never auto-pick).
- No match → staff **creates a new Contact** (see Contact-create rule) or searches manually.

**Process 3 — Recurring:**
- `FrequencyId != null` ⇒ recurring. On promote, after the GlobalDonation is created, create a `RecurringDonationSchedule` for the resolved contact (Amount, CurrencyId, FrequencyId, StartDate = today, derived NextBillingDate).
- The schedule requires a `GatewaySubscriptionId`. If the staging row carries one (recurring captures store the Braintree subscription id), use it. If absent → **SERVICE_PLACEHOLDER**: create the schedule in a "verification pending" state and surface a flag; real Braintree subscription verification is deferred (cf. Online Donation Page #10 ISSUE-27).

**Contact-create rule (Process 2 new contact):**
- Reuse the **global `ContactCreateModal`** (`presentation/components/modals/contact-create-modal/index.tsx`), opened via `useModalStore`, **prefilled** from the staging row: `firstName`=ProvidedFirstName, `lastName`=ProvidedLastName, contact method (`childType`/`childValue`)=email if ProvidedEmail else phone, plus ProvidedOrganization → Organization type when present. Use the modal's `onCreated({id,label})` callback to capture the new ContactId. (Requires the small modal extension in §⑧.)

**Promote (Resolve) transaction rules:**
- `ResolveOnlineDonationStaging` must, in ONE transaction: (a) require a resolved ContactId; (b) build the `CreateGlobalDonationWithChildrenRequestDto` (Donation + single Distribution + OnlineDonation child) from the staging row + resolved contact; (c) call the composite create; (d) write back `ResolvedContactId`, `PromotedGlobalDonationId`, `IsResolved=true`, `ResolvedByUserId` (from HttpContext), `ResolvedDate`; (e) for recurring, create the schedule.
- **GlobalDonation field derivation**: `DonationModeId`=OD, `DonationTypeId`=ONETIMEDONATION (or recurring type if defined), `DonationAmount`/`CurrencyId` from staging, `ExchangeRate`+`BaseCurrencyId`+`BaseCurrencyAmount` resolved from `CompanyConfigurations.BaseCurrencyId` (rate = 1 if same currency, else CurrencyConversion lookup), `NetAmount` = Amount − fees, `DonationDate`/`ReceivedDate` from staging.ReceivedDate, `PaymentStatusId`=COMPLETED, `ContactId`=resolved, `OnlineDonationPageId` from staging, `SourceTypeId` = online. Distribution: one row, `AllocatedAmount`=DonationAmount, `ContactId`=resolved, `OrganizationalUnitId`/`DonationOccasionId` from purpose mapping, `ParticipantRoleId`=primary-donor role. OnlineDonation child: `PaymentGatewayId`/`GatewayTransactionId`/`PaymentMethodId`/gateway response fields from staging.

**Anonymous donations (`IsAnonymous=true`):** still require a Contact mapping for ledger integrity. Default: map to the tenant's reserved **"Anonymous Donor"** contact if one exists, else create/resolve a contact normally but set `GlobalDonation.IsIndividualDonation` accordingly and respect anonymity in receipts. ⚠ Confirm with org policy (flagged in §⑫).

**MasterData lookups (reuse canonical codes — see project memory):** `DONATIONMODE/OD`, `DONATIONTYPE/ONETIMEDONATION`, `PAYMENTMETHOD/CARD`, `PAYMENTSTATUS/COMPLETED`. Resolve via TypeCode+DataValue join on `MasterDataTypes` (mirror `RunAutoReconciliation`). **Do NOT filter `IsDeleted` on MasterData** (`IsDeleted` is `bool?`; `== false` excludes seeded NULL rows).

**Workflow (per staging row):** `UNRESOLVED → (Process) → RESOLVED` (terminal, with PromotedGlobalDonationId) · `UNRESOLVED → DISMISSED` (for FAILED/abandoned, terminal). Auto-Map performs UNRESOLVED→RESOLVED in bulk for high-confidence rows only.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — PRE-ANSWERED.

**Screen Type**: FLOW (closest template). **Actual shape**: **custom workbench**, NOT standard CRUD-FLOW.
**Canonical sibling to mirror**: **Payment Reconciliation #14** (`crm/donation/reconciliation`) — custom workbench (KPI cards + filtered queue + bulk "Run Auto" + per-row resolution + detail drawer/page + Zustand store, queries via Apollo `useQuery`/`useLazyQuery`, NOT `FlowDataTable`).
**Reason**: A system-fed processing queue with bulk auto-resolution and a rich per-row decision flow; there is no hand-create/edit/delete of records. The "view-page" carries `?mode=process` (resolve flow) and `?mode=read` (resolution summary) — there is **no `mode=new` and no `mode=edit`**.

**Backend Patterns Required:**
- [x] Read queries (paginated list + detail + summary counts) — tenant-scoped from HttpContext
- [x] Custom command: `ResolveOnlineDonationStaging` (orchestrates `CreateGlobalDonationWithChildren` + writeback + recurring)
- [x] Custom bulk command: `RunAutoMapOnlineDonations` (adapt `RunAutoReconciliation` scoring + batch commit)
- [x] Custom query: `FindContactMatches` (email/phone/name ranking — new)
- [x] Reuse existing: `GetContactByCode`, `CreateGlobalDonationWithChildren`, `CreateContact`, `CreateRecurringDonationSchedule`
- [x] Idempotency guard (PromotedGlobalDonationId)
- [ ] NO standard Create/Update/Delete/Toggle of the staging entity

**Frontend Patterns Required:**
- [x] Custom workbench index (KPI widget cards + toolbar + queue table) — mirror reconciliation `index-page.tsx`, **Variant B** (`ScreenHeader` + widgets + table with `showHeader={false}`)
- [x] view-page.tsx with `?mode=process` + `?mode=read` (NOT new/edit) — full-page processor
- [x] Zustand store (`onlinedonationinbox-store.ts`) — date range, status filter, search, refreshToken, selected staging
- [x] Reuse global `ContactCreateModal` via `useModalStore` (prefilled + onCreated)
- [x] Apollo `useQuery`/`useLazyQuery` (NOT FlowDataTable grid for the queue)
- [x] "Run Auto-Map" toolbar action with confirm + result toast
- [ ] NO RJSF form schema (GridFormSchema SKIP)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer. Mirror Reconciliation #14 for structure.

### QUEUE (index page) — `crm/donation/onlinedonationinbox`

**Grid Layout Variant**: `widgets-above-grid` (Variant B — `ScreenHeader` + KPI widgets + queue table with `showHeader={false}`).
**Display Mode**: `table` (custom Apollo-driven table, like reconciliation — NOT `FlowDataTable`).

**KPI Widget Cards** (above the queue):
| # | Widget | Value Source (`onlineDonationInboxSummary`) | Display | Position |
|---|--------|---------------------------------------------|---------|----------|
| 1 | Awaiting Processing | unresolvedCount (COMPLETED & !IsResolved) | count | left |
| 2 | Resolved Today | resolvedTodayCount | count | center-left |
| 3 | Total Staged (range) | totalStagedCount + totalStagedAmount | count + currency | center-right |
| 4 | Failed / Abandoned | failedCount + abandonedCount | count | right |

**Toolbar**: date-range picker (default last 30 days, presets like reconciliation) · status filter (`Awaiting` default / `Resolved` / `Failed` / `Abandoned` / `All`) · search (donor name / email / contact code) · optional Online Donation Page filter · **[Run Auto-Map]** button (confirm dialog → calls `runAutoMapOnlineDonations(dateFrom,dateTo)` → toast `{autoMapped} mapped, {unresolved} need review, {failed} errors` → `bumpRefresh()`).

**Queue Columns:**
| # | Header | Field | Type | Notes |
|---|--------|-------|------|-------|
| 1 | Donor | providedFirstName + providedLastName | text | + Anonymous chip if isAnonymous |
| 2 | Contact / Email | providedEmail / providedPhone | text | stacked |
| 3 | Code | providedContactCode | chip | grey if empty |
| 4 | Amount | amount + currencyCode | currency | right-aligned |
| 5 | Page | onlineDonationPageName | text | |
| 6 | Type | frequency | badge | "One-time" / "Recurring · {freq}" |
| 7 | Match | matchSuggestion | chip | "✔ CON-0042" (code) · "{name} (email)" · "{n} candidates" · "No match" |
| 8 | Payment | paymentStatusName | badge | COMPLETED green / PENDING amber / FAILED red |
| 9 | Received | receivedDate | date | |
| 10 | State | isResolved | badge | "Awaiting" / "Resolved" |
| 11 | — | actions | buttons | **[Process]** (→ `?mode=process&id`) · resolved rows show **[View]** (→ `?mode=read&id`) |

**Row click**: → `?mode=process&id={id}` for unresolved, `?mode=read&id={id}` for resolved.

---

### PROCESS page (`?mode=process&id=X`) — the decision center

> Full-page processor (NOT a modal). Left = context (read-only), Right = decision + actions. Mirror the multi-column detail layout pattern.

**Page Header**: FlowFormPageHeader — Back (→ queue), title "Process Online Donation #{id}".

**Layout**: 2 columns (left 2fr context, right 1fr action) — or stacked sections on mobile.

**LEFT — context cards (read-only):**
| # | Card | Content |
|---|------|---------|
| 1 | Donor (provided) | First/Last name, Email, Phone, Address, Organization, Anonymous flag, Dedicate note, Message, Provided Contact Code |
| 2 | Payment | Amount + currency, Page, Gateway, Payment method, Transaction id, Auth code, Status badge, Received date |
| 3 | Donation Preview | The `GlobalDonation` that will be created: Mode (OD), Type, Amount, Currency, Base amount + rate, Purpose, Date, → resolved Contact. Single distribution row preview. |
| 4 | Recurring (only if FrequencyId) | Frequency, Amount, Start date, Next billing, Subscription id (or "verification pending" SERVICE_PLACEHOLDER badge) |

**RIGHT — Contact Resolution panel (the core interaction):**
- **If ProvidedContactCode resolves** (`contactByCode`): show resolved contact card (avatar, DisplayName, Code, primary email/phone) + **[Use this contact]** (sets resolvedContactId).
- **Candidate matches** (`findContactMatches`): ranked list, each with match-reason chips (Email / Phone / Name) + confidence; **[Select]** per candidate. Ambiguous sets are clearly labelled "review — multiple matches".
- **Manual search**: `ApiSelectV2`/searchable contacts (`contacts` query) to pick ANY contact.
- **Create new**: **[+ Create new contact]** → opens global `ContactCreateModal` prefilled from staging (firstName/lastName/email-or-phone). `onCreated` → set resolvedContactId + show as selected.
- Selected-contact summary chip with a clear/change affordance.

**Footer actions:** **[Promote → Create Donation]** (enabled only when a contact is selected; calls `resolveOnlineDonationStaging`) · **[Dismiss]** (for FAILED/abandoned rows — `dismissOnlineDonationStaging` with reason) · **[Cancel]** (→ queue).

**On promote success**: toast → redirect to `?mode=read&id={id}`.

---

### READ page (`?mode=read&id=X`) — resolution summary

> For already-resolved (or dismissed) rows. NOT the form disabled — a summary.

- Resolution banner: Resolved by {user} on {date} · status.
- Resolved Contact card (link to contact profile).
- Promoted donation card → link to `crm/donation/globaldonation?mode=read&id={PromotedGlobalDonationId}`.
- Recurring schedule card (if created) → link/code.
- Original staged donor + payment context (read-only).
- Promote is **blocked** (idempotent) — no action buttons except Back.

### User Interaction Flow
1. Staff opens inbox → sees KPI cards + "Awaiting" queue.
2. (Optional) clicks **Run Auto-Map** → ContactCode + single-high-confidence rows auto-promote; ambiguous/no-match remain.
3. Clicks **Process** on a remaining row → `?mode=process&id=X`.
4. Resolves the contact (confirm code match / pick candidate / manual search / create new prefilled).
5. Reviews donation preview (+ recurring panel) → **Promote** → GlobalDonation created, staging flips Resolved → redirect to `?mode=read`.
6. Failed/abandoned rows → **Dismiss** with reason.

---

## ⑦ Substitution Guide

> **Consumer**: Backend + Frontend Developers. **Primary sibling = Payment Reconciliation (#14)** for FE workbench; SavedFilter (FLOW) for view-page scaffolding.

| Canonical (Reconciliation) | → This Screen | Context |
|----------------------------|---------------|---------|
| Reconciliation | OnlineDonationInbox | feature/folder name |
| reconciliation | onlineDonationInbox | camelCase |
| PaymentTransaction | OnlineDonationStaging | the queued source row |
| reconciliation-store | onlinedonationinbox-store | Zustand store file |
| crm/donation/reconciliation | crm/donation/onlinedonationinbox | FE route |
| RECONCILIATION | ONLINEDONATIONINBOX | menu/grid code |
| CRM_DONATION | CRM_DONATION | parent menu (same) |
| CRM | CRM | module |
| matchPaymentTransaction | resolveOnlineDonationStaging | the "resolve" mutation |
| runAutoReconciliation | runAutoMapOnlineDonations | the bulk action |
| fund | fund | schema (same) |
| DonationModels | DonationModels | BE group |

---

## ⑧ File Manifest

> **Consumer**: Backend + Frontend Developers. New folder convention mirrors `DonationBusiness/Reconciliation/`.

### Backend Files (NEW)

| # | File | Path |
|---|------|------|
| 1 | Schemas (DTOs) | `Base.Application/Schemas/DonationSchemas/OnlineDonationInboxSchemas.cs` |
| 2 | Query — list | `Base.Application/Business/DonationBusiness/OnlineDonationInbox/Queries/GetOnlineDonationStagingList.cs` |
| 3 | Query — by id | `.../OnlineDonationInbox/Queries/GetOnlineDonationStagingById.cs` |
| 4 | Query — summary | `.../OnlineDonationInbox/Queries/GetOnlineDonationInboxSummary.cs` |
| 5 | Query — contact matches | `.../OnlineDonationInbox/Queries/FindContactMatches.cs` |
| 6 | Command — resolve/promote | `.../OnlineDonationInbox/Commands/ResolveOnlineDonationStaging.cs` |
| 7 | Command — bulk auto-map | `.../OnlineDonationInbox/Commands/RunAutoMapOnlineDonations.cs` |
| 8 | Command — dismiss | `.../OnlineDonationInbox/Commands/DismissOnlineDonationStaging.cs` |
| 9 | Endpoint — queries | `Base.API/EndPoints/Donation/Queries/OnlineDonationInboxQueries.cs` |
| 10 | Endpoint — mutations | `Base.API/EndPoints/Donation/Mutations/OnlineDonationInboxMutations.cs` |

**Reuse (do NOT recreate)**: `OnlineDonationStaging` entity + config, `CreateGlobalDonationWithChildren`, `CreateContact`, `GetContactByCode`, `GetContact`, `CreateRecurringDonationSchedule`, all composite DTOs.

### Backend Wiring (verify/modify — ⚠ shared files)

| # | File | What |
|---|------|------|
| 1 | `IDonationDbContext.cs` / `DonationDbContext.cs` | **Verify** `DbSet<OnlineDonationStaging>` exists (created with #10); add only if missing |
| 2 | `DonationMappings.cs` | Mapster configs for the new inbox DTOs |
| 3 | `DecoratorProperties.cs` | only if a new decorator group is needed (likely none — reuses Donation) |

### Frontend Files (NEW)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `src/domain/entities/donation-service/OnlineDonationInboxDto.ts` |
| 2 | GQL Queries | `src/infrastructure/gql-queries/donation-queries/OnlineDonationInboxQuery.ts` |
| 3 | GQL Mutations | `src/infrastructure/gql-mutations/donation-mutations/OnlineDonationInboxMutation.ts` |
| 4 | Page Config | `src/presentation/pages/crm/donation/onlinedonationinbox.tsx` |
| 5 | Router shell | `src/presentation/components/page-components/crm/donation/onlinedonationinbox/index.tsx` |
| 6 | Workbench index page | `.../onlinedonationinbox/index-page.tsx` |
| 7 | **View page (process/read)** | `.../onlinedonationinbox/view-page.tsx` |
| 8 | **Zustand store** | `.../onlinedonationinbox/onlinedonationinbox-store.ts` |
| 9 | KPI widgets | `.../onlinedonationinbox/inbox-widgets.tsx` |
| 10 | Toolbar | `.../onlinedonationinbox/inbox-toolbar.tsx` |
| 11 | Queue table | `.../onlinedonationinbox/inbox-table.tsx` |
| 12 | Contact resolution panel | `.../onlinedonationinbox/contact-resolution-panel.tsx` |
| 13 | Donation preview panel | `.../onlinedonationinbox/donation-preview-panel.tsx` |
| 14 | Recurring verify panel | `.../onlinedonationinbox/recurring-verify-panel.tsx` |
| 15 | Route Page | `src/app/[lang]/crm/donation/onlinedonationinbox/page.tsx` |

### Frontend Wiring (modify — ⚠ includes shared files)

| # | File | What |
|---|------|------|
| 1 | `presentation/components/modals/contact-create-modal/index.tsx` | **Extend**: read `modalProps.prefill` → seed `firstName/lastName`, `childType`+`childValue` (email or phone), optional org. Keep existing `onCreated` path. ⚠ SHARED MODAL — additive only, must not break existing callers. |
| 2 | entity-operations.ts / operations-config.ts | register `ONLINEDONATIONINBOX` operations |
| 3 | donation-service entity barrel + GQL barrels | export new DTO + query/mutation docs |
| 4 | sidebar/route config | menu entry + route under CRM ▸ Donation |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: FULL

MenuName: Online Donation Inbox
MenuCode: ONLINEDONATIONINBOX
ParentMenu: CRM_DONATION
Module: CRM
MenuUrl: crm/donation/onlinedonationinbox
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, EXPORT

GridFormSchema: SKIP
GridCode: ONLINEDONATIONINBOX
---CONFIG-END---
```

> Capability mapping for this custom workbench: **READ** = view queue/detail; **CREATE** = promote (creates a GlobalDonation); **MODIFY** = run auto-map / resolve; **DELETE** = dismiss. No TOGGLE (no soft on/off on staging). MenuId/order: insert as order **9** under CRM_DONATION (after REFUND=8).

---

## ⑩ Expected BE→FE Contract

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| onlineDonationStagingList | paginated `OnlineDonationStagingListDto` | `dateFrom: DateTime!, dateTo: DateTime!, statusFilter: String, onlineDonationPageId: Int, request: { pageSize, pageIndex, sortColumn, sortDescending, searchTerm, advancedFilter }` |
| onlineDonationStagingById | `OnlineDonationStagingDetailDto` | `onlineDonationStagingId: Int!` |
| onlineDonationInboxSummary | `OnlineDonationInboxSummaryDto` | `dateFrom: DateTime!, dateTo: DateTime!` |
| findContactMatches | `[ContactMatchCandidateDto]` | `onlineDonationStagingId: Int!` |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| resolveOnlineDonationStaging | `request: { onlineDonationStagingId, contactId, donationPurposeId?, note?, overrides? }` | `BaseApiResponse<int>` (new GlobalDonationId; `data: Int!` — select bare `data`) |
| runAutoMapOnlineDonations | `dateFrom: DateTime!, dateTo: DateTime!` | `RunAutoMapResultDto { autoMapped, unresolved, failed }` |
| dismissOnlineDonationStaging | `onlineDonationStagingId: Int!, reason: String` | `BaseApiResponse<int>` |

> **Memory-driven contract gotchas** (must honor): `BaseApiResponse<int>` → FE selects **bare `data`** (it's `Int!`, no subfields). Input type names keep `Dto`: `...RequestDtoInput!`. Strip Apollo `__typename` on any response→input round-trip. `[AsParameters] GridFeatureRequest` exposes ONE arg named after the C# param (`request:`) — verify against the reconciliation sibling, don't assume. HC strips `Get` and uses the C# param name as the GQL arg name.

**`OnlineDonationStagingListDto` (FE fields, camelCase):** onlineDonationStagingId, providedFirstName, providedLastName, providedEmail, providedPhone, providedContactCode, amount, currencyCode, onlineDonationPageName, frequencyName (null=one-time), donationPurposeName, paymentStatusName, isAnonymous, receivedDate, isResolved, promotedGlobalDonationId, matchSuggestion { kind: "CODE"|"EMAIL"|"PHONE"|"NAME"|"AMBIGUOUS"|"NONE", contactId?, label?, candidateCount? }.

**`ContactMatchCandidateDto`:** contactId, contactCode, displayName, primaryEmail, primaryPhone, matchReasons: ["EMAIL"|"PHONE"|"NAME"], score.

---

## ⑪ Acceptance Criteria

**Build:** `dotnet build` clean · `pnpm tsc --noEmit` clean · page loads at `/{lang}/crm/donation/onlinedonationinbox`.

**Functional (Full E2E):**
- [ ] KPI cards show correct counts for the date range; queue lists only COMPLETED & unresolved by default
- [ ] Status filter switches between Awaiting / Resolved / Failed / Abandoned / All
- [ ] Search filters by donor name / email / contact code
- [ ] **Run Auto-Map** auto-resolves ContactCode matches + single-high-confidence email/phone matches; ambiguous rows stay unresolved; toast reports counts; idempotent on re-run
- [ ] Process page renders donor + payment + donation preview; recurring panel appears only when FrequencyId set
- [ ] ContactCode path shows the resolved contact + "Use this contact"
- [ ] Candidate matches ranked with reason chips; multiple matches flagged ambiguous (no auto-pick)
- [ ] Manual contact search selects any contact
- [ ] "Create new contact" opens the global modal **prefilled** with staging name + email/phone; on create the new contact becomes the selection
- [ ] Promote creates GlobalDonation + GlobalOnlineDonation child; staging flips IsResolved=true with PromotedGlobalDonationId, ResolvedByUserId, ResolvedDate
- [ ] Recurring promote creates RecurringDonationSchedule (or shows verification-pending placeholder)
- [ ] Already-resolved row → read mode shows summary + link to the promoted donation; promote blocked
- [ ] Dismiss works for FAILED/abandoned rows with a reason
- [ ] Permissions respected (READ/CREATE/MODIFY/DELETE)

**DB Seed:** menu visible under CRM ▸ Donation; caps granted to BUSINESSADMIN; GridFormSchema SKIP.

---

## ⑫ Special Notes & Warnings

- **CompanyId from HttpContext** — all queries/commands tenant-scoped; never trust a client-sent CompanyId.
- **No CRUD on staging** — staff never create/edit/delete staging rows. The only writes are resolution fields + dismiss. Do NOT scaffold standard Create/Update/Delete/Toggle.
- **Custom workbench, not FlowDataTable** — the queue is an Apollo-driven custom table like Reconciliation #14, with `widgets-above-grid` (Variant B). Do NOT use `<FlowDataTable>` for the queue. Mirror `crm/donation/reconciliation/index-page.tsx`.
- **view-page modes are `process` + `read` only** — there is NO `mode=new` / `mode=edit`.
- **Idempotency** — `PromotedGlobalDonationId != null` ⇒ already promoted; resolve + auto-map MUST skip. Guard server-side.
- **Reuse the composite create** — promote calls `CreateGlobalDonationWithChildren` (Donation + Distribution + OnlineDonation child); do NOT hand-write GlobalDonation inserts.
- **MasterData**: canonical codes `DONATIONMODE/OD`, `DONATIONTYPE/ONETIMEDONATION`, `PAYMENTMETHOD/CARD`, `PAYMENTSTATUS/COMPLETED`; resolve via TypeCode+DataValue join; **no `IsDeleted` filter on MasterData** (bool? NULL trap).
- **Auto-map scoring** adapts `RunAutoReconciliation` (threshold ≥ 90, batch commit 100). ContactCode exact = 100; single email/phone exact = high; name-only or multi-match = below threshold (manual).
- **DateTime args** must be full ISO-8601 with offset at the GQL boundary (reuse reconciliation's `toIsoStart`/`toIsoEnd` helpers).
- **⚠ Shared-file edit — global ContactCreateModal**: extend it to honor `modalProps.prefill`. Additive only — must not change behavior for existing callers (the dropdown inline-create path). If a parallel session is editing this modal, serialize.
- **⚠ Anonymous-donor policy** — confirm whether anonymous donations map to a reserved "Anonymous Donor" contact or create a normal contact with anonymity flags. Default assumed: reserved contact if present, else normal create. Revisit before go-live.

**Service Dependencies (UI built, handler mocked):**
- ⚠ SERVICE_PLACEHOLDER: **Recurring subscription verification** — when a recurring staging row lacks a usable `GatewaySubscriptionId`, the `RecurringDonationSchedule` is created in a verification-pending state; live Braintree subscription confirmation is deferred (cf. Online Donation Page #10 ISSUE-27, ISSUE-26).
- ⚠ SERVICE_PLACEHOLDER: **Receipt email on promote** — no email infra (cf. #10 ISSUE-3); promote shows a toast / sets receipt-pending; no email is sent.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session). See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | planning 2026-05-29 | MED | Recurring | Live Braintree subscription verification deferred — recurring schedules created verification-pending (depends on #10 ISSUE-27 shipping subscription capture). | OPEN |
| ISSUE-2 | planning 2026-05-29 | MED | Email | Receipt email on promote — no email infra (cf. #10 ISSUE-3). | OPEN |
| ISSUE-3 | planning 2026-05-29 | MED | Policy | Anonymous-donor mapping policy needs org confirmation (reserved contact vs normal create + anonymity flag). | OPEN |
| ISSUE-4 | planning 2026-05-29 | LOW | Matching | `FindContactMatches` phone matching needs a normalization rule (std code / formatting) to avoid false negatives. | OPEN |
| ISSUE-5 | planning 2026-05-29 | LOW | Wiring | Verify `DbSet<OnlineDonationStaging>` is registered in IDonationDbContext/DonationDbContext (created with #10) before BE build. | CLOSED (S1 — confirmed IDonationDbContext.cs:46 / DonationDbContext.cs:49) |
| ISSUE-6 | build 2026-05-29 | LOW | Matching | Queue list `matchSuggestion` is a lightweight CODE/NONE/resolved hint only; full email/phone/name candidate scoring runs on the PROCESS page via `findContactMatches` (not per-row, to avoid N+1). | OPEN |
| ISSUE-7 | build 2026-05-29 | LOW | Data | Prompt §② said Contacts schema `con`; actual is `corg`. BE unaffected (EF navigations); raw DB-seed SQL corrected. | CLOSED (S1) |
| ISSUE-8 | build 2026-05-29 | MED | Grid | S1 shipped the queue as a hand-rolled Apollo `<table>` (`inbox-table.tsx`), violating the "reuse FlowDataTable/AdvancedDataTable — never fork a per-screen grid" rule. | CLOSED (S2 — refactored onto shared `<FlowDataTable gridCode=ONLINEDONATIONINBOX>`; custom cells + Process/View actions are `odi-*` GridComponentName renderers; custom table deleted). |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

#### Session 1 — 2026-05-29 (PART 1: Foundation + Queue Workbench)

**Agent**: Frontend Developer (Sonnet)
**Scope**: PART 1 of 2 — DTOs, GQL queries/mutations, Zustand store, KPI widgets, toolbar, queue table, index page (Variant B), router shell, route page, wiring. PART 2 (process/read view-page) has a stub placeholder.

**Files created**:
- `src/domain/entities/donation-service/OnlineDonationInboxDto.ts`
- `src/infrastructure/gql-queries/donation-queries/OnlineDonationInboxQuery.ts`
- `src/infrastructure/gql-mutations/donation-mutations/OnlineDonationInboxMutation.ts`
- `src/presentation/pages/crm/donation/onlinedonationinbox.tsx`
- `src/presentation/components/page-components/crm/donation/onlinedonationinbox/index.tsx`
- `src/presentation/components/page-components/crm/donation/onlinedonationinbox/index-page.tsx`
- `src/presentation/components/page-components/crm/donation/onlinedonationinbox/view-page.tsx` (stub)
- `src/presentation/components/page-components/crm/donation/onlinedonationinbox/onlinedonationinbox-store.ts`
- `src/presentation/components/page-components/crm/donation/onlinedonationinbox/inbox-widgets.tsx`
- `src/presentation/components/page-components/crm/donation/onlinedonationinbox/inbox-toolbar.tsx`
- `src/presentation/components/page-components/crm/donation/onlinedonationinbox/inbox-table.tsx`
- `src/app/[lang]/crm/donation/onlinedonationinbox/page.tsx`

**Files modified (wiring)**:
- `src/domain/entities/donation-service/index.ts` — added OnlineDonationInboxDto export
- `src/infrastructure/gql-queries/donation-queries/index.ts` — added OnlineDonationInboxQuery export
- `src/infrastructure/gql-mutations/donation-mutations/index.ts` — added OnlineDonationInboxMutation export
- `src/presentation/pages/crm/donation/index.ts` — added OnlineDonationInboxPageConfig export
- `src/application/configs/data-table-configs/donation-service-entity-operations.ts` — added ONLINEDONATIONINBOX config block

**tsc result**: Exit 0 — one pre-existing error in `donation-form.tsx` (Razorpay, Screen #10); zero errors in new files.

**Deviations from spec**: None. Variant B confirmed (ScreenHeader + InboxWidgets + InboxTable). view-page.tsx is a stub (PART 2 scope). DB Seed (menu/caps) handled separately per spec §⑨.

**ISSUE-5 resolution**: DB seed handled by /build-screen DB step; entity-operations wired with ONLINEDONATIONINBOX gridCode.

---

> _[1 older session entries trimmed to save tokens — full history in git: `git log -p -- onlinedonationinbox.md`. Most recent 5 kept below.]_

### Session 2 — 2026-05-29 — REFACTOR — COMPLETED

> Queue grid migrated off the hand-rolled custom table onto the SHARED `<FlowDataTable>`, per user directive: "use flow grid or advanced grid — don't create custom grid; you can create the custom actions in advanced or flow if needed." Resolves ISSUE-8. (Mirrors the Refund #13 sibling — FlowDataTable + Variant B + filter→extraVariables + component-column actions.)

- **Scope**: FE grid refactor + supporting BE/DB/seed changes. No agents spawned — done inline (precise, pre-researched edits). [[reuse-existing-grids]].
- **Files touched**:
  - FE (created): `presentation/components/custom-components/data-tables/shared-cell-renderers/online-donation-inbox-cells.tsx` — 8 `odi-*` renderers (donor / contact / amount / type / match / payment / state / **actions** Process+View).
  - FE (modified): `.../shared-cell-renderers/index.ts` (barrel exports); `.../data-tables/flow/data-table-column-types/component-column.tsx` (8 `odi-*` GridComponentName cases + imports); `.../onlinedonationinbox/index-page.tsx` (rewritten → `FlowDataTableStoreProvider` + `FlowDataTableContainer showHeader={false}`; screen filters → grid `extraVariables` / `searchTerm` / `refresh`); `infrastructure/gql-queries/donation-queries/OnlineDonationInboxQuery.ts` (`$dateFrom`/`$dateTo` → nullable for grid first-fetch).
  - FE (deleted): `.../onlinedonationinbox/inbox-table.tsx` (the hand-rolled `<table>`).
  - FE (unchanged, reused): `inbox-toolbar.tsx`, `inbox-widgets.tsx`, `onlinedonationinbox-store.ts`, `index.tsx` (dispatcher), `view-page.tsx` + panels.
  - BE (modified): `Base.API/EndPoints/Donation/Queries/OnlineDonationInboxQueries.cs` + `Base.Application/.../Queries/GetOnlineDonationStagingList.cs` — `dateFrom`/`dateTo` made nullable; handler defaults null → trailing 90-day window; validator range checks `.When(both present)`. (Summary query left required — widgets always pass a range.)
  - DB (modified): `OnlineDonationInbox-sqlscripts.sql` — STEP 4b `sett.Fields` (11) + STEP 4c `sett.GridFields` (11 `odi-*` component columns); header/footer notes updated. No `IsPrimary` row → ActionColumnBuilder suppressed (P2P #135 precedent); `odi-actions` is the sole action surface.
- **Why nullable dates**: the FlowDataTable fires its first fetch before the screen's `setExtraVariables` effect runs; required `DateTime!` vars would 400 on that first call. Nullable + server default removes the race; the toolbar overrides with the real range on the next tick.
- **Deviations from spec**: Queue is now a config-driven grid (was custom Apollo table in §⑥/§⑫). `odi-*` renderers registered in the **flow** column builder only (this grid renders exclusively via `<FlowDataTable>`; advanced/basic builders not needed).
- **Known issues opened**: None.
- **Known issues closed**: ISSUE-8 (custom grid → FlowDataTable).
- **Validation**: FE `tsc --noEmit` clean (only the pre-existing unrelated #10 Razorpay error; zero errors in new/changed files). BE `Base.Application` compiles `0 Error(s)` (full-solution build only failed on output-DLL file-locks from the running API/VS process — not code). Variant B confirmed (`ScreenHeader` + `FlowDataTableContainer showHeader={false}`). GridComponentName check: all `odi-*` cases registered in the flow `ComponentColumnBuilder`.
- **Next step**: Runtime E2E still pending — run `/test-screen #175`. On first load, confirm the grid renders the 11 columns from the seeded GridFields (run `OnlineDonationInbox-sqlscripts.sql` first) and that Process/View navigation + Run Auto-Map refresh work.

### Session 3 — 2026-05-30 — ENHANCE — COMPLETED

> Two FE polish requests + audit-log integration for the mapping actions. No agents spawned for the edits — inline; two Explore agents used only to map the existing audit subsystem + handlers.

- **Scope**: FE badge restyle + toolbar search removal; BE audit logging for manual-map & auto-map.
- **Files touched**:
  - FE (modified, badge restyle → solid `-600` bg + `text-white`, neutral → `bg-slate-500/600`): `custom-components/data-tables/shared-cell-renderers/online-donation-inbox-cells.tsx` (Anonymous chip, Type, Match, Payment, State badges); `page-components/.../onlinedonationinbox/contact-resolution-panel.tsx` (MatchReasonChip); `.../view-page.tsx` (PaymentCard status + ANONYMOUS chip); `.../recurring-verify-panel.tsx` (RECURRING pill only — surrounding amber callout panel left untouched).
  - FE (modified, search removal): `.../onlinedonationinbox/inbox-toolbar.tsx` — removed the search `<Input>` left of the dropdowns + its now-unused `Input` import and `searchTerm`/`setSearchTerm` store hooks (`bumpRefresh` kept; `searchTerm` field stays in the store, just unset).
  - BE (modified): `Base.Application/.../OnlineDonationInbox/Commands/ResolveOnlineDonationStaging.cs` — inject `IAuditLogWriter`; added optional `bool IsAutoMap = false` to the command record; writes an `OD_MAP` workflow audit (EntityType `OnlineDonationStaging`, EntityId = stagingId) after writeback `SaveChanges`, suppressed when `IsAutoMap`. `RunAutoMapOnlineDonations.cs` — inject `IAuditLogWriter`; passes `IsAutoMap: true` to the inner Resolve; writes ONE `OD_AUTOMAP` batch-summary audit (EntityId 0) after the loop with mapped/unresolved/failed counts + date range.
  - DB: `AUDIT_ACTION_TYPE` codes `OD_MAP` (Online donation map) + `OD_AUTOMAP` (Online donation auto map) seeded by the **user**, not the build. `AuditTrail-sqlscripts.sql` left with only a comment pointer (no rows added by the build).
- **Audit design**: explicit business-event audit via `IAuditLogWriter.WriteWorkflowEvent` (non-blocking queue, never throws, never joins the caller's txn). EntityType is the **staging entity** (`OnlineDonationStaging`) for both paths — manual map = per-row `OD_MAP`, auto-map = single `OD_AUTOMAP` summary (per-row entries suppressed to keep the trail readable). Complements the auto-interceptor's raw UPDATE/CREATE rows with named, human-readable actions.
- **Deviations from spec**: None — audit logging was not in the original §-spec; added per user request ("include the audit log for this screen — manual map + run automap, mainly entity type").
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Validation**: BE `Base.Application` builds `0 Error(s)` (507 pre-existing nullable warnings, none in changed files). FE edits are token/class-only — no type surface change.
- **Next step**: `OD_MAP` / `OD_AUTOMAP` already seeded by user. `/test-screen #175`: do a manual Process→map and a Run Auto-Map, and confirm the Audit Trail (Screen #74) shows the `OD_MAP` / `OD_AUTOMAP` rows under EntityType `OnlineDonationStaging`.

### Session 4 — 2026-05-30 — ENHANCE — COMPLETED (pending user EF migration)

> Converted "Run Auto-Map" from a synchronous in-request for-loop into a **durable, resumable, queued Hangfire background job** with live progress, pause/resume/cancel, actor tracking, and crash recovery. Mirrors the existing Import subsystem (ImportSession → Hangfire → batched loop + LastProcessedOffset resume + startup recovery). Approved plan: `nifty-squishing-dragonfly.md`. Decisions: Apollo polling (not SignalR); job keeps running on screen close; inline panel + history on the inbox.

- **Scope**: New `OnlineDonationMapJob` entity + Hangfire runner/dispatcher + lifecycle commands + queries + GraphQL + FE panel/history. Old synchronous `RunAutoMapOnlineDonations` removed.
- **Architecture note (key)**: the Hangfire job has no HttpContext, but it reuses the canonical `ResolveOnlineDonationStagingCommand` (whose tenant/authorization MediatR pipeline reads claims). The runner installs a **synthetic `ClaimsPrincipal`** from the job's CompanyId + StartedByUserId (the user already authorized at Start) so the per-row resolve passes. Authorization is DB-driven by UserId. Progress counters written via `ExecuteUpdateAsync` (no change-tracking — avoids the Resolve handler's detach logic). One-running-per-company enforced by a partial unique index `WHERE Status='Running'` + FIFO dispatcher.
- **Files touched**:
  - BE (created): `Base.Domain/Models/DonationModels/OnlineDonationMapJob.cs` (entity + 2 enums); `Base.Infrastructure/.../DonationConfigurations/OnlineDonationMapJobConfiguration.cs`; `Base.Application/Services/OnlineDonationMapJobs/` (IOnlineDonationMapJobRunner, OnlineDonationMapJobRunner, IOnlineDonationMapJobDispatcher, OnlineDonationMapJobDispatcher); `.../OnlineDonationInbox/Commands/StartOnlineDonationMapJob.cs` + `OnlineDonationMapJobControlCommands.cs` (Pause/Resume/Cancel); `.../OnlineDonationInbox/Queries/GetOnlineDonationMapJob.cs` (current + history + mapper); `Base.Application/Schemas/DonationSchemas/OnlineDonationMapJobSchemas.cs` (DTO); `Base.API/Extensions/OnlineDonationMapJobRecoveryExtension.cs`.
  - BE (modified): `IDonationDbContext.cs` + `DonationDbContext.cs` (DbSet); `Base.Application/DependencyInjection.cs` (register runner+dispatcher); `OnlineDonationInboxMutations.cs` (−RunAutoMap, +Start/Pause/Resume/Cancel); `OnlineDonationInboxQueries.cs` (+current/history); `Program.cs` (+RecoverOnlineDonationMapJobsAsync).
  - BE (deleted): `RunAutoMapOnlineDonations.cs` (scoring moved verbatim into the runner; `RunAutoMapResultDto` left orphaned-but-harmless in schemas).
  - FE (created): `domain/entities/donation-service/OnlineDonationMapJobDto.ts`; `gql-queries/donation-queries/OnlineDonationMapJobQuery.ts`; `gql-mutations/donation-mutations/OnlineDonationMapJobMutation.ts`; `onlinedonationinbox/automap-job-panel.tsx` (live progress + Pause/Resume/Cancel, polls 2.5s); `onlinedonationinbox/automap-job-history.tsx` (collapsible, actors + counts).
  - FE (modified): `inbox-toolbar.tsx` (Run Auto-Map → START job + bumpRefresh); `index-page.tsx` (mount panel + history); `donation-service/index.ts` + `donation-mutations/index.ts` (barrels); `donation-service-entity-operations.ts` (update slot → START_AUTOMAP_JOB).
- **Deviations from spec**: auto-map is now async/job-based (was a synchronous mutation). FE Job History is a lightweight custom list (a deliberate secondary surface), not a FlowDataTable.
- **Known issues opened**: ISSUE-2 — email(80)/phone(70) confidence scores are below the 90 threshold, so **only ContactCode (100) ever auto-maps** (faithfully ported from the old loop; the toolbar copy that said "email/phone" was already inaccurate). Tune thresholds if email/phone auto-map is desired. Status: OPEN.
- **Known issues closed**: None.
- **Validation**: BE `Base.Application` + `Base.Infrastructure` compile `0 Error(s)` (Base.API errors were output-DLL file-locks from the running app — no `CS` errors). FE `tsc --noEmit` clean in all new/changed files (only the pre-existing unrelated #10 Razorpay error remains).
- **Next step**: **USER must create + run the EF migration** for `fund.OnlineDonationMapJobs` (incl. the partial unique index `WHERE "Status"='Running'`) — agent does not run migrations. Then restart the API and `/test-screen #175`: Start a job → watch the panel progress + `/hangfire`; close+reopen the screen (progress persists); Pause→Resume (resumes from cursor); start a 2nd job (queues); Cancel; confirm completion drops into Job History with actor columns + one `OD_AUTOMAP` audit row.

### Session 5 — 2026-06-01 — FIX — COMPLETED

- **Scope**: Promotion to `fund.GlobalDonations` (via manual map AND Run Auto-Map) was landing the new donation with `OnlineDonationPageId = NULL`, so promoted donations never rolled up into the source Online Donation Page (#10) totals (`totalRaised` / `donorCount` / `lastDonationAt`). Backfill the FK on promote.
- **Root cause**: `ResolveOnlineDonationStaging` builds the `GlobalDonation` through the composite `CreateGlobalDonationWithChildrenCommand`, which Mapster-adapts from `GlobalDonationRequestDto` (`CreateGlobalDonationWithChildren.cs:329`). That request DTO intentionally has **no** `OnlineDonationPageId` (it's a public-page concern, not a generic-donation input), so the column was always written NULL. `GlobalDonation.OnlineDonationPageId` exists (added with #10) and `OnlineDonationStaging.OnlineDonationPageId` is a required FK (always set by `InitiateOnlineDonation`) — the value was simply never carried across the promote. The canonical online one-time/recurring paths don't promote here (`ConfirmOnlineDonation` only flips staging COMPLETED; promotion is the Inbox's job), and the only other direct GD-builder, `PayURecurringChargeService.cs:251`, *does* set it — so the Inbox promote was the lone gap.
- **Fix (1 file, BE-only, no schema change)**: `Base.Application/.../OnlineDonationInbox/Commands/ResolveOnlineDonationStaging.cs` — after the composite create returns a valid `newGlobalDonationId`, issue an `ExecuteUpdateAsync` setting `GlobalDonations.OnlineDonationPageId = staging.OnlineDonationPageId` (scoped by `GlobalDonationId` + `CompanyId`). `ExecuteUpdateAsync` is used (not a tracked save) deliberately — the composite create leaves severed nav back-refs tracked on this scoped context (see the existing detach block), so a tracked save would throw on DetectChanges; the raw UPDATE bypasses the change tracker entirely. Covers BOTH surfaces because the Hangfire auto-map runner dispatches the same `ResolveOnlineDonationStagingCommand` (`OnlineDonationMapJobRunner.cs:142`, `IsAutoMap: true`); the synthetic principal it installs makes `GetCurrentUserStaffCompanyId()` resolve the correct tenant for the `CompanyId` scope.
- **Why not thread it through `GlobalDonationRequestDto`**: that DTO is a shared GraphQL input on every donation create/update mutation; adding the field would widen the public schema for unrelated screens. The contained backfill keeps the change surface to this one screen.
- **Deviations from spec**: None.
- **Known issues opened / closed**: None.
- **Build verification**: `dotnet build Base.Application.csproj` → **0 errors** (523 pre-existing warnings). No EF migration (column already exists). `Base.API` not separately rebuilt here — user rebuilds/restarts to deploy.
- **Next step**: Runtime not exercised. After redeploy: run Run Auto-Map (and/or a manual Process→map) on a staging row, then confirm the promoted `fund.GlobalDonations` row has `OnlineDonationPageId` populated and that the source page's Status-Bar `totalRaised`/`donorCount` (#10 `GetOnlineDonationPageStats`) now reflects it. Existing rows promoted before this fix stay NULL (no backfill of historical rows performed).

### Session 6 — 2026-06-01 — UI — COMPLETED

- **Scope**: Restyle the existing Run-Auto-Map confirmation modal (it already gated job creation — clicking "Run Auto-Map" opens an `AlertDialog`; the job only starts on the dialog's action button). User picked the **two-section card** layout.
- **Files touched**: FE (1, JSX-only) — `presentation/components/page-components/crm/donation/onlinedonationinbox/inbox-toolbar.tsx`. Restyled the `AlertDialog` content: (1) title now has a robot icon in an `bg-primary/10` accent circle; the long paragraph `AlertDialogDescription` became `sr-only` (kept for a11y) and was replaced by a **"What this does"** bulleted section (3 icon bullets — ≥90%/ContactCode maps, ambiguous→queue, server-side/queues-if-busy); (2) the date-range pills + custom inputs + live "Scanning X → Y" preview were wrapped in a bordered `bg-muted/30` **"Date range" card**. No logic touched — `jobPreset`/`jobRange`/`rangeValid`/`handleStartJob`/`START_AUTOMAP_JOB_MUTATION` all unchanged; same pill buttons, same custom From/To inputs, same validation, same footer.
- **Deviations from spec**: None (the modal pre-dates the §-spec; this is pure presentation polish).
- **Known issues opened / closed**: None.
- **Validation**: `pnpm tsc --noEmit` — clean for `inbox-toolbar.tsx`; only the long-standing unrelated #10 `donation-form.tsx:659` Razorpay error remains. All components used (`Icon`, `Label`, `Input`, `AlertDialog*`) were already imported in the file.
- **Next step**: None. Click "Run Auto-Map" to see the restyled confirm.
