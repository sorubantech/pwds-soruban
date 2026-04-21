---
screen: EventTicketing
registry_id: 46
module: CRM (Event)
status: PROMPT_READY
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO — uses existing `app` schema / ApplicationModels group
planned_date: 2026-04-20
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (single-page composite config with 5 cards)
- [x] Existing code reviewed (FE stub "Need to Develop"; no BE ticketing entities)
- [x] Business rules + 5 sub-entities identified
- [x] FK targets resolved (Event, Contact, Currency, MasterData)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated (composite multi-entity scope)
- [ ] Solution Resolution complete
- [ ] UX Design finalized (5-card stacked layout, event selector, inline CRUD for tickets)
- [ ] User Approval received
- [ ] Backend code generated (4 primary entities + 1 child + 5 MasterData TypeCodes + migration)
- [ ] Backend wiring complete
- [ ] Frontend code generated (single-page composite index-page, no 3-mode view-page)
- [ ] Frontend wiring complete
- [ ] DB Seed script generated (menu + 5 MasterData sets + GridFormSchema SKIP)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/crm/event/eventticketing`
- [ ] Event selector dropdown populates from `getEvents` and switches `?eventId=X`
- [ ] Event Summary Bar shows selected event's name, date, venue, capacity, registered count, revenue, registration status
- [ ] Ticket Types card: grid loads for selected event with sold progress bar
- [ ] +Add Ticket Type → inline form card toggles open (NOT modal, NOT new URL)
- [ ] Pricing Type = "Per table" or "Per group" → Group Size field shows
- [ ] Pricing Type = "Per person" → Group Size field hidden
- [ ] Benefits checklist: add/remove custom benefits inside form
- [ ] Discount Code toggle → conditional code input appears
- [ ] Save → creates EventTicket + benefits → grid refreshes, form closes
- [ ] Edit button on ticket row → form opens pre-filled → save updates
- [ ] More menu: Duplicate / Pause Sales / Delete (toggle status)
- [ ] Registration Settings card: 3 top toggles persist (Registration Open, Waitlist, Approval Required)
- [ ] Custom Questions list: add/edit/delete/reorder rows (drag handle visible — reorder is SERVICE_PLACEHOLDER)
- [ ] Email/Check-in toggles persist (Confirmation Email, Reminder Emails + 7-day/1-day checkboxes, QR Code Check-in)
- [ ] Public Registration Page Preview card renders the computed preview with desktop/mobile toggle
- [ ] Preview subtotal updates when user adjusts qty (client-side only — preview is illustrative)
- [ ] Registrants card: collapsible; grid loads with Name/Email/Ticket/Qty/Amount/Registered/Check-in/Actions
- [ ] Search + ticket-type filter filter registrants
- [ ] Check-in checkbox toggles CheckedIn status and stores CheckedInDate
- [ ] QR/Edit/Cancel actions work (QR = SERVICE_PLACEHOLDER, Cancel = soft cancel registration)
- [ ] Preview Public Page button opens placeholder URL in new tab (SERVICE_PLACEHOLDER)
- [ ] Share Registration Link button copies URL to clipboard (client-side, in scope)
- [ ] DB Seed — menu "Event Ticketing" visible under CRM → Events → OrderBy=2
- [ ] DB Seed — 5 MasterData TypeCodes present (EVENTPRICINGTYPE, EVENTTICKETVISIBILITY, EVENTTICKETSTATUS, EVENTREGSTATUS, EVENTQUESTIONTYPE)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **EventTicketing**
Module: **CRM → Event** (Menu parent: CRM_EVENT)
Schema: **`app`** (existing — Event lives here)
Group: **`ApplicationModels`** (same namespace as Event)

Business: Event Ticketing is a single-page **configuration console** for one Event at a time. After a user picks an event from the top-right selector, the page reveals five stacked cards that together define how the event sells, registers, and checks in attendees: (1) a summary strip showing capacity and revenue, (2) a CRUD grid of ticket types (VIP / Premium / Standard / Complimentary etc. — each with pricing, quantity, benefits, sale window, visibility, and discount code), (3) a registration-settings card (open/close window, waitlist, approval, confirmation & reminder emails, QR check-in, and a sortable custom-questions list), (4) a live preview of the public registration page (desktop/mobile), and (5) a collapsible registrants grid with check-in and cancellation actions. This screen is the NGO's primary control panel for ticketed galas, charity walks, youth summits, and paid workshops. It reads the parent Event (existing entity) and writes five new sibling entities: **EventTicket**, **EventTicketBenefit**, **EventRegistration**, **EventCustomQuestion**, **EventSetting**. It sits between the existing "Events" list (#44) and the "Event Analytics" dashboard (#47).

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> This screen introduces **5 new tables** in the existing `app` schema. All link back to the existing `app.Events` table (no Event changes required).
> Audit columns (CreatedBy/CreatedDate/ModifiedBy/ModifiedDate/IsActive) omitted — inherited from Entity base.
> **CompanyId is NOT a field** on any of these tables — scoped via `Event.CompanyId` + HttpContext filter.

### Table 2.1 — `app.EventTickets` (PRIMARY — the grid in card #2)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| EventTicketId | int | — | PK | — | Primary key |
| EventTicketCode | string | 50 | YES | — | Auto-gen `EVT-TKT-{NNNN}` per Event if empty |
| EventId | int | — | YES | app.Events | Parent event |
| TicketName | string | 100 | YES | — | e.g., "VIP Table (10 seats)" |
| EmojiIcon | string | 20 | NO | — | e.g., 🥇 / 🎭 / 🎟️ (optional UI accent) |
| Description | string | 500 | NO | — | Rich description for public page |
| PricingTypeId | int | — | YES | com.MasterDatas | typeCode=`EVENTPRICINGTYPE` (PER_PERSON / PER_TABLE / PER_GROUP) |
| CurrencyId | int | — | YES | general.Currencies | |
| Price | decimal(18,2) | — | YES | — | 0 allowed for Complimentary |
| GroupSize | int | — | NO | — | REQUIRED when PricingType = PER_TABLE or PER_GROUP |
| QuantityAvailable | int | — | YES | — | Total tickets/tables available |
| SaleStartDate | DateTime | — | NO | — | Optional early-access gate |
| SaleEndDate | DateTime | — | NO | — | Optional cut-off |
| MinPerOrder | int | — | NO | — | Default 1 |
| MaxPerOrder | int | — | NO | — | Default 10 |
| VisibilityId | int | — | YES | com.MasterDatas | typeCode=`EVENTTICKETVISIBILITY` (PUBLIC / HIDDEN / PASSWORD) |
| DiscountCode | string | 50 | NO | — | Optional promo code |
| StatusId | int | — | YES | com.MasterDatas | typeCode=`EVENTTICKETSTATUS` (ONSALE / SOLDOUT / PAUSED / EXPIRED) |
| SortOrder | int | — | NO | — | Display order within event (default 0) |

**Computed/derived (NOT stored — projected via LINQ):**
- `soldCount` = `COUNT(EventRegistrations WHERE EventTicketId = x AND StatusId ≠ Cancelled)`
- `revenue` = `SUM(Registrations.TotalAmount)` or `Price × soldCount`
- `soldPercent` = `soldCount / QuantityAvailable × 100`

### Table 2.2 — `app.EventTicketBenefits` (child of EventTicket — checklist rows)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| EventTicketBenefitId | int | — | PK | — | |
| EventTicketId | int | — | YES | app.EventTickets | Cascade delete |
| BenefitText | string | 200 | YES | — | e.g., "VIP lounge access" |
| IsIncluded | bool | — | YES | — | Checkbox state (checked = included in this ticket) |
| OrderBy | int | — | YES | — | Display order |

### Table 2.3 — `app.EventRegistrations` (the registrants grid in card #5)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| EventRegistrationId | int | — | PK | — | |
| EventRegistrationCode | string | 50 | YES | — | Auto-gen `EVT-REG-{NNNN}` |
| EventId | int | — | YES | app.Events | |
| EventTicketId | int | — | YES | app.EventTickets | Which ticket type |
| ContactId | int | — | NO | corg.Contacts | Linked contact (nullable — allows guest registration) |
| RegistrantName | string | 200 | YES | — | Denormalized for guest registrants |
| RegistrantEmail | string | 200 | YES | — | Denormalized |
| RegistrantPhone | string | 50 | NO | — | Denormalized |
| Quantity | int | — | YES | — | Number of tickets purchased |
| TotalAmount | decimal(18,2) | — | YES | — | Snapshot at purchase time (currency = Ticket.Currency) |
| RegisteredDate | DateTime | — | YES | — | Default now |
| CheckedIn | bool | — | YES | — | Default false |
| CheckedInDate | DateTime | — | NO | — | Set when CheckedIn flips true |
| QRCodeToken | string | 100 | NO | — | Opaque token for QR gen (SERVICE_PLACEHOLDER) |
| StatusId | int | — | YES | com.MasterDatas | typeCode=`EVENTREGSTATUS` (PENDING / CONFIRMED / CANCELLED / WAITLIST) |

### Table 2.4 — `app.EventCustomQuestions` (draggable question list in card #3)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| EventCustomQuestionId | int | — | PK | — | |
| EventId | int | — | YES | app.Events | |
| QuestionText | string | 500 | YES | — | e.g., "Dietary requirements" |
| QuestionTypeId | int | — | YES | com.MasterDatas | typeCode=`EVENTQUESTIONTYPE` (TEXT / DROPDOWN / CHECKBOX / RADIO / NUMBER / DATE) |
| IsRequired | bool | — | YES | — | Default false |
| OptionsJson | string | max | NO | — | JSON array for DROPDOWN/RADIO/CHECKBOX options |
| OrderBy | int | — | YES | — | Display order, used by drag-reorder |

### Table 2.5 — `app.EventSettings` (SINGLETON — one row per event; card #3 toggles)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| EventSettingId | int | — | PK | — | |
| EventId | int | — | YES UNIQUE | app.Events | **Unique index — one setting row per event** |
| IsRegistrationOpen | bool | — | YES | — | Master toggle (mirrors/overrides Event.RegistrationRequired) |
| WaitlistEnabled | bool | — | YES | — | Default true |
| ApprovalRequired | bool | — | YES | — | Default false — manual approval workflow |
| SendConfirmationEmail | bool | — | YES | — | Default true |
| SendReminderEmails | bool | — | YES | — | Default true |
| ReminderDaysBefore | string | 50 | NO | — | CSV e.g. `"7,1"` — days before event to send reminders |
| QRCheckInEnabled | bool | — | YES | — | Default true |
| PasswordProtectedCode | string | 100 | NO | — | Optional event-level password if any ticket is password-protected |

**Child Entities recap**:
| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| EventTicketBenefit | 1:Many via EventTicketId (cascade) | BenefitText, IsIncluded, OrderBy |
| EventRegistration | 1:Many via EventTicketId + EventId | RegistrantName, Quantity, TotalAmount |
| EventCustomQuestion | 1:Many via EventId | QuestionText, QuestionTypeId, OrderBy |
| EventSetting | 1:1 via EventId (unique) | singleton config row |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for .Include() and navigation properties) + Frontend Developer (for ApiSelect queries)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| EventId | Event | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/Event.cs` | `getEvents` (NOT `GetAllEventList` — existing unusual name) | ShortDescription (used as EventName proxy) | EventResponseDto |
| ContactId | Contact | `PSS_2.0_Backend/.../Base.Domain/Models/CorgModels/Contact.cs` | `GetAllContactList` | ContactName (derived from DisplayName or FirstName + LastName) | ContactResponseDto |
| CurrencyId | Currency | `PSS_2.0_Backend/.../Base.Domain/Models/GeneralModels/Currency.cs` | `GetAllCurrencyList` | CurrencyCode / CurrencyName | CurrencyResponseDto |
| PricingTypeId | MasterData (typeCode=EVENTPRICINGTYPE) | `PSS_2.0_Backend/.../Base.Domain/Models/ComModels/MasterData.cs` | `GetMasterDataByTypeCode` arg `typeCode="EVENTPRICINGTYPE"` | MasterDataName | MasterDataResponseDto |
| VisibilityId | MasterData (typeCode=EVENTTICKETVISIBILITY) | `…/ComModels/MasterData.cs` | `GetMasterDataByTypeCode` | MasterDataName | MasterDataResponseDto |
| StatusId (EventTicket) | MasterData (typeCode=EVENTTICKETSTATUS) | `…/ComModels/MasterData.cs` | `GetMasterDataByTypeCode` | MasterDataName | MasterDataResponseDto |
| StatusId (EventRegistration) | MasterData (typeCode=EVENTREGSTATUS) | `…/ComModels/MasterData.cs` | `GetMasterDataByTypeCode` | MasterDataName | MasterDataResponseDto |
| QuestionTypeId | MasterData (typeCode=EVENTQUESTIONTYPE) | `…/ComModels/MasterData.cs` | `GetMasterDataByTypeCode` | MasterDataName | MasterDataResponseDto |

**Note on Event query**: The existing query is `getEvents` (GraphQL field name — lowercase `g`), NOT the standard `GetAllEventList`. Returns `PaginatedApiResponse<IEnumerable<EventResponseDto>>`. Event display uses `shortDescription` (there is **no `EventName` field** on the Event entity). The event-selector dropdown in this screen must use `getEvents` and render `shortDescription` as the label.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- `EventTicket.TicketName` unique per `EventId` (case-insensitive)
- `EventTicket.EventTicketCode` globally unique (auto-gen)
- `EventRegistration.EventRegistrationCode` globally unique (auto-gen)
- `EventSetting.EventId` unique (singleton enforcement via unique index)

**Required Field Rules (EventTicket):**
- TicketName, EventId, PricingTypeId, CurrencyId, Price, QuantityAvailable, VisibilityId, StatusId are mandatory
- `GroupSize` REQUIRED when `PricingTypeId` resolves to PER_TABLE or PER_GROUP

**Required Field Rules (EventRegistration):**
- EventId, EventTicketId, RegistrantName, RegistrantEmail, Quantity, TotalAmount, StatusId mandatory
- ContactId optional (guest flow — enables name/email without a contact record)

**Required Field Rules (EventCustomQuestion):**
- EventId, QuestionText, QuestionTypeId mandatory
- `OptionsJson` REQUIRED when QuestionType is DROPDOWN / RADIO / CHECKBOX

**Conditional Rules:**
- `SaleEndDate > SaleStartDate` when both set
- `MaxPerOrder >= MinPerOrder`
- `QuantityAvailable > 0`
- `Price >= 0` (allows 0 for complimentary)
- If `VisibilityId` = PASSWORD, parent `EventSetting.PasswordProtectedCode` must be set
- Registration capacity: cannot create new CONFIRMED registration if `SUM(Registrations.Quantity) WHERE EventTicketId = x` would exceed `QuantityAvailable` — route to WAITLIST if `EventSetting.WaitlistEnabled`
- `SaleStartDate >= today` enforced only on Create (not on Edit, to preserve history)

**Business Logic:**
- **Sold count**: projected via LINQ — `COUNT(Registrations WHERE EventTicketId = x AND StatusId ∈ {CONFIRMED, PENDING})`
- **Revenue**: projected via LINQ — `SUM(Registrations.TotalAmount)` for the ticket / event
- **Status auto-transitions (background or on-read)**:
  - ONSALE → SOLDOUT when `soldCount >= QuantityAvailable`
  - ONSALE → EXPIRED when `SaleEndDate < now`
  - PAUSED stays PAUSED until user explicitly resumes (sets back to ONSALE)
- **Delete ticket**: forbidden when `soldCount > 0`. Allow archive-via-toggle (IsActive=false) instead.
- **Cancel registration**: sets StatusId=CANCELLED, does NOT reduce grid sold count (history preserved), but DOES free capacity so waitlist promotion logic can fire
- **Check-in flow**: toggle `CheckedIn=true` → set `CheckedInDate=now`; toggle false → `CheckedInDate=null`
- **Confirmation email on register**: if `EventSetting.SendConfirmationEmail = true`, enqueue email (SERVICE_PLACEHOLDER — email service not implemented; return success, toast "Email queued")
- **Reminder emails**: persist config only — actual scheduling is SERVICE_PLACEHOLDER

**Workflow** (EventRegistration state machine):
- States: `PENDING → CONFIRMED → CANCELLED` (or `PENDING → WAITLIST → CONFIRMED → CANCELLED`)
- Transitions:
  - User registers: PENDING (approval required) OR CONFIRMED (no approval needed, capacity available) OR WAITLIST (no capacity, waitlist enabled)
  - Admin approves: PENDING → CONFIRMED
  - Admin rejects / User cancels: any → CANCELLED
  - Spot frees (another cancellation): WAITLIST → CONFIRMED (oldest-first)
- Side effects: CONFIRMED → enqueue confirmation email; CANCELLED → trigger waitlist promotion check

**Workflow** (EventTicket lifecycle):
- States: `ONSALE ↔ PAUSED`, `ONSALE → SOLDOUT` (auto), `ONSALE → EXPIRED` (auto on SaleEndDate)
- "Pause Sales" row-action: flips StatusId ONSALE ↔ PAUSED

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW (**non-standard composite variant**)
**Type Classification**: Composite single-page configuration screen bound to a parent entity (Event). Similar in shape to MatchingGift #11 settings tabs but WITHOUT the 3-mode view-page pattern — everything is inline on one URL (`/crm/event/eventticketing?eventId=X`). No separate `?mode=new | edit | read` routes for tickets — inline toggle form instead.
**Reason**: The mockup shows NO grid list of "ticketings" (it's not a CRUD workflow on one entity). The page is an event-scoped configuration console. The "list" is the Event dropdown; the "form" is the inline ticket-type card; the "detail" is the five-card composite itself.

**Backend Patterns Required:**
- [x] Standard CRUD × 4 entities (EventTicket, EventRegistration, EventCustomQuestion, EventSetting)
- [x] Nested child creation for EventTicket → EventTicketBenefits (included in Create/Update EventTicket)
- [x] Multi-FK validation (ValidateForeignKeyRecord ×3 on EventTicket, ×2 on each other entity)
- [x] Unique validation — TicketName per Event; EventSetting.EventId unique
- [x] Workflow commands — `PauseEventTicket`, `ResumeEventTicket`, `CheckInRegistration`, `CancelRegistration`, `ApproveRegistration`
- [x] Custom business rule validators — GroupSize conditional, OptionsJson conditional, capacity check
- [x] Singleton upsert — `UpsertEventSetting` (Create-or-Update based on EventId)
- [x] Reorder command — `ReorderEventCustomQuestions` (batch order update)
- [x] Computed projections — SoldCount + Revenue via LINQ subquery on EventTicket GetAll
- [x] Summary query — `GetEventTicketingSummary(eventId)` → Capacity, Registered, Revenue, Status (for top summary bar)
- [ ] File upload command — NOT required
- [x] Tenant scoping — via Event.CompanyId join (all queries must filter by Event.CompanyId = HttpContext.CompanyId)

**Frontend Patterns Required:**
- [x] **Variant B** page layout (ScreenHeader + composite body, NOT a FlowDataTable list page)
- [x] Event selector dropdown (ApiSelectV2 using `getEvents`)
- [x] URL param `?eventId=X` — selected event persisted in query string
- [x] 5 stacked cards (Summary Bar, Ticket Types grid, Add/Edit Ticket Form inline card, Registration Settings, Public Preview, Registrants collapsible)
- [x] Inline CRUD for EventTicket within page (toggle card, NOT modal, NOT new URL)
- [x] Inline CRUD for EventCustomQuestion (small modal)
- [x] Inline toggle-persist for EventSetting
- [x] Zustand store (`eventticketing-store.ts`) — selectedEventId, ticketFormOpen, editingTicketId, questionFormOpen, editingQuestionId, registrantSearchText, registrantTicketFilter
- [x] Child grid inside form — EventTicketBenefit checklist (add/remove rows)
- [x] Conditional form field — GroupSize appears when PricingType = PER_TABLE/PER_GROUP
- [x] Conditional form field — Discount Code input appears when toggle is on
- [x] Toggle switches styled to match mockup
- [x] Inline progress bar cell renderer (Sold column)
- [x] Collapsible card wrapper (Registrants card)
- [x] Desktop/Mobile toolbar toggle for Public Preview card (pure client-side)
- [x] Drag handle UI on CustomQuestions (reorder is SERVICE_PLACEHOLDER if dnd library not already in registry — otherwise wire)
- [ ] 3-mode view-page.tsx with `?mode=new/edit/read` — **NOT used** (non-standard FLOW)
- [ ] FlowDataTable — NOT used on the page shell; Ticket Types uses a simple AdvancedDataTable inside a card
- [x] Summary cards inside the top Summary Bar (4 stats: Capacity, Registered, Revenue, Reg Status)
- [ ] Grid aggregation columns — Sold / Revenue are projected from BE, not FE-computed

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Extracted directly from `html_mockup_screens/screens/organization/event-ticketing.html`.
> **NON-STANDARD FLOW** — describe as ONE composite page. No separate FORM vs DETAIL layouts. Section ordering follows the mockup top-to-bottom.

**Grid Layout Variant**: `widgets-above-grid+side-panel` → **Variant B MANDATORY** (ScreenHeader + composite body, NO FlowDataTable wrapper).

**Display Mode**: `table` (inside card #2 ticket-types grid and card #6 registrants grid — both inline within their respective cards, NOT the page shell).

### Page Structure (top to bottom)

```
┌──────────────────────────────────────────────────────────────────────────┐
│ PAGE HEADER                                                                │
│  [←]  Events › Event Ticketing                                             │
│       Event Ticketing                                                      │
│       Configure tickets, pricing, and registration for events              │
│                                       [Event Selector ▼] [Preview] [Share] │
├──────────────────────────────────────────────────────────────────────────┤
│ CARD 1 — EVENT SUMMARY BAR                                                 │
│  Fundraising Gala 2026 | 📅 Apr 20 | 📍 Grand Hyatt Dubai                 │
│       300 Capacity   234 Registered (78%)   $67,800 Revenue   🟢 Open      │
├──────────────────────────────────────────────────────────────────────────┤
│ CARD 2 — TICKET TYPES                       [+ Add Ticket Type]            │
│  ┌─────────────────────────────────────────────────────────────────────┐ │
│  │ Ticket | Price | Qty | Sold (progress) | Revenue | Status | Actions │ │
│  │ 🥇 VIP Table | $5000 | 10 | ━━━━━━ 7  | $35,000 | On Sale | Edit ⋯  │ │
│  │ 🎭 Premium  | $500  | 50 | ━━━━━━ 42 | $21,000 | On Sale | Edit ⋯  │ │
│  │ ...                                                                 │ │
│  └─────────────────────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────────────────────┤
│ CARD 3 (CONDITIONAL) — ADD/EDIT TICKET TYPE FORM (inline, toggled)         │
│  [Ticket Name*]  [Pricing Type ▼]                                          │
│  [Description textarea]                                                    │
│  [Currency▼ + Price*]  [GroupSize (conditional)]  [Qty Available*]         │
│  [Sale Start Date]  [Sale End Date]                                        │
│  [Min Per Order]  [Max Per Order]                                          │
│  Benefits: ☑ VIP lounge  ☑ Meet & greet  ☐ Premium menu  [+ Add Benefit]   │
│  [Visibility ▼]  [Discount Code ⚪ toggle + conditional input]             │
│                                          [Cancel] [✓ Save Ticket Type]     │
├──────────────────────────────────────────────────────────────────────────┤
│ CARD 4 — REGISTRATION SETTINGS                                             │
│  Registration Open                                   [⚪━]                  │
│  Waitlist                                            [⚪━]                  │
│  Approval Required                                   [○━]                  │
│  ──────────────────────────────                                            │
│  📋 Custom Questions                                                       │
│    ⋮⋮ Dietary requirements  [Dropdown]  [✎]                               │
│    ⋮⋮ Accessibility needs   [Text]      [✎]                               │
│    [+ Add Question]                                                        │
│  ──────────────────────────────                                            │
│  Confirmation Email                                  [⚪━]                  │
│  Reminder Emails  ☑ 7 days  ☑ 1 day                 [⚪━]                  │
│  QR Code Check-in                                    [⚪━]                  │
├──────────────────────────────────────────────────────────────────────────┤
│ CARD 5 — PUBLIC REGISTRATION PAGE PREVIEW                                  │
│  [🖥 Desktop] [📱 Mobile]                                                  │
│  [... rendered preview iframe / dom ...]                                   │
├──────────────────────────────────────────────────────────────────────────┤
│ CARD 6 — REGISTRANTS (collapsible)  (234 total) [search] [filter▼]  [v]   │
│  Name | Email | Ticket | Qty | Amount | Registered | Check-in | Actions   │
│  ... paginated table ...                                                   │
└──────────────────────────────────────────────────────────────────────────┘
```

### Page Header (ScreenHeader)

- **Title**: "Event Ticketing"
- **Subtitle**: "Configure tickets, pricing, and registration for events"
- **Breadcrumb**: Events › Event Ticketing (Events link navigates to `/crm/event/event`)
- **Right-side actions**:
  1. **Event Selector** (ApiSelectV2 — queries `getEvents`, label=`shortDescription`, value=`eventId`, searchable). On change, updates URL `?eventId=X` and refetches all cards.
  2. **Preview Public Page** button — opens `/public/event/{eventId}/register` in new tab (SERVICE_PLACEHOLDER — toast "Public preview opens in new tab" for now)
  3. **Share Registration Link** button — `navigator.clipboard.writeText(publicUrl)` then toast "Registration link copied" (CLIENT-SIDE, IN SCOPE)

### Card 1 — Event Summary Bar

Source: `GetEventTicketingSummary(eventId)` single GQL call returning:

| Field | Source | Display |
|-------|--------|---------|
| eventName | Event.ShortDescription | "Fundraising Gala 2026" (bold) |
| eventDate | Event.StartDate | "📅 Apr 20, 2026" |
| venueName | Event.VenueName | "📍 Grand Hyatt Dubai" |
| capacity | SUM(EventTickets.QuantityAvailable) WHERE EventId | `300` |
| registered | SUM(Registrations.Quantity) WHERE StatusId ≠ CANCELLED | `234` |
| registeredPercent | registered / capacity × 100 | `78%` |
| totalRevenue | SUM(Registrations.TotalAmount) WHERE StatusId = CONFIRMED | `$67,800` (success color) |
| registrationStatus | computed: Event.EventStatusId + Setting.IsRegistrationOpen + dates | "🟢 Open" / "🔴 Closed" + "closes Apr 18" |

Layout: horizontal flex bar with 2 zones — left (name + date + venue pills) / right (4 stat tiles). Full-width card, card-shadow, 1rem padding.

### Card 2 — Ticket Types (the grid)

Data source: `GetAllEventTicketList(eventId)` returns `EventTicketResponseDto[]` with projected `soldCount`, `soldPercent`, `revenue`.

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Ticket | `emojiIcon` + `ticketName` | text-bold with emoji prefix | auto | YES | `🥇 VIP Table (10 seats)` |
| 2 | Price | `price` + `currencyCode` + `pricingTypeCode` suffix | currency | 120px | YES | `$5,000/table` when PER_TABLE, else `/person` |
| 3 | Qty Available | `quantityAvailable` + "tables"/"" suffix | text | 110px | YES | `10 tables` for PER_TABLE |
| 4 | Sold | `soldCount` + `soldPercent` | **inline-progress renderer** | 150px | NO | Progress bar + "7" label; color via `soldPercent` (<70 success, 70-90 warning, 100 grey) |
| 5 | Revenue | `revenue` | currency bold | 110px | YES | `$35,000` |
| 6 | Status | `statusCode` + `statusName` | **status-badge renderer** (existing) | 100px | YES | ONSALE=success, SOLDOUT=grey, PAUSED=warning, EXPIRED=grey italic |
| 7 | Actions | — | row-actions | 110px | NO | **Edit** button + **More** dropdown (Duplicate / Pause Sales / Delete) |

**Row hover**: light bg `#f8fafc`.
**Expired row style**: `opacity: 0.55` when statusCode = EXPIRED.
**Edit hidden** on SOLDOUT/EXPIRED rows (only More dropdown).

**Grid actions** (header):
- `[+ Add Ticket Type]` primary button — toggles Card 3 form visible (empty, `editingTicketId=null`)

**Row actions**:
- Edit → toggle Card 3 form visible, preload fields from row (`editingTicketId=row.id`)
- Duplicate → prefill Card 3 form with row values + blank id + "(Copy)" suffix on name
- Pause Sales → call `PauseEventTicket(id)` mutation → flips StatusId ONSALE↔PAUSED, refresh grid
- Delete → confirm dialog → `DeleteEventTicket(id)` (fails if soldCount > 0, server-side)

### Card 3 — Add/Edit Ticket Type FORM (inline, conditional)

Rendered only when `ticketFormOpen === true`. Header shows "Add Ticket Type" or "Edit Ticket Type" + close ✕. Uses React Hook Form (local — this is NOT a full-page view-page; it's an inline form within the index page).

**Section Container Type**: Single card, grid-style form rows (no accordion).

**Form Sections** (in display order — all within one card body):
| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | — | (Identity row) | 2-column | always expanded | TicketName, PricingType |
| 2 | — | (Description) | full-width | always expanded | Description (textarea 3 rows) |
| 3 | — | (Pricing row) | 3-column | always expanded | Currency + Price, GroupSize (conditional), QuantityAvailable |
| 4 | — | (Sale window) | 2-column | always expanded | SaleStartDate, SaleEndDate |
| 5 | — | (Order limits) | 2-column | always expanded | MinPerOrder, MaxPerOrder |
| 6 | — | Benefits | full-width | always expanded | Benefits checklist (dynamic) |
| 7 | — | (Visibility + Discount) | 2-column | always expanded | Visibility, Discount Code (toggle + input) |
| 8 | — | (Action row) | flex-end | — | [Cancel] [Save Ticket Type] |

**Field Widget Mapping**:
| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| TicketName | 1 | text | "e.g., VIP Table, Standard Seat" | required, max 100 | — |
| PricingTypeId | 1 | select (MasterData EVENTPRICINGTYPE) | — | required | Options: Per person / Per table / Per group |
| Description | 2 | textarea | "Describe what's included with this ticket type..." | max 500 | — |
| CurrencyId | 3 | select (ApiSelectV2, GetAllCurrencyList) | — | required | Compact — 80px width + Price beside |
| Price | 3 | number | "0.00" | required, >=0 | flex:1 |
| GroupSize | 3 | number | "e.g., 10 seats per table" | required IF PricingType=PER_TABLE/PER_GROUP | **Conditional** — hidden on PER_PERSON |
| QuantityAvailable | 3 | number | "e.g., 100" | required, >=1 | — |
| SaleStartDate | 4 | datepicker | — | optional | — |
| SaleEndDate | 4 | datepicker | — | optional, > SaleStartDate | — |
| MinPerOrder | 5 | number | — | required, >=1, default 1 | — |
| MaxPerOrder | 5 | number | — | required, >=MinPerOrder, default 10 | — |
| Benefits[] | 6 | **checklist widget** (dynamic array) | — | — | Each row: checkbox + text + remove; [+ Add Benefit] link at bottom; `IsIncluded` bool + `BenefitText` string per row |
| VisibilityId | 7 | select (MasterData EVENTTICKETVISIBILITY) | — | required | Options: Public / Hidden / Password protected |
| DiscountCode | 7 | **toggle + text** | "e.g., EARLYVIP20" | max 50 | Input hidden unless toggle on |

**Special Form Widgets**:

- **Conditional Sub-forms**:
  | Trigger Field | Trigger Value | Sub-form Fields |
  |--------------|---------------|-----------------|
  | PricingType | PER_TABLE or PER_GROUP | Show `GroupSize` field (hide on PER_PERSON) |
  | DiscountCode toggle | true | Show `DiscountCode` text input |

- **Child widget: Benefits checklist** (custom `<BenefitChecklistWidget>`):
  - Dynamic array of `{ benefitText: string, isIncluded: bool }`
  - Each row: checkbox + editable text + trash icon
  - Footer link: "[+ Add Benefit]" — appends empty row
  - Data flows as `benefits: EventTicketBenefitRequestDto[]` in Create/Update payload

**Form submit**:
- `[Save Ticket Type]` → `CreateEventTicket` or `UpdateEventTicket` (atomic: ticket + all benefits)
- On success: toast, refetch grid, close form (`ticketFormOpen=false`)
- `[Cancel]` → close form, discard edits (no unsaved-changes dialog for inline form — simple discard)

### Card 4 — Registration Settings

All controls **auto-persist on change** via debounced `UpsertEventSetting(eventId, patch)` — no save button.

**Top toggles** (each `<ToggleSwitch>` row):
| # | Label | Sublabel | Field | Default |
|---|-------|----------|-------|---------|
| 1 | Registration Open | "Open: {RegistrationOpenDate} — Close: {RegistrationCloseDate}" (from Event) | EventSetting.IsRegistrationOpen | true |
| 2 | Waitlist | "Allow signups when capacity is reached; auto-promote when spots open" | EventSetting.WaitlistEnabled | true |
| 3 | Approval Required | "Manually approve each registration before confirming" | EventSetting.ApprovalRequired | false |

**Custom Questions subsection**:
- Header: 📋 Custom Questions
- List of `<QuestionRow>` cards (draggable via grip handle):
  - ⋮⋮ icon (drag handle)
  - Question text
  - Question type badge (Dropdown / Text / Checkbox / Radio / Number / Date)
  - ✎ Edit button → opens inline edit row OR small modal
  - 🗑️ Delete button (missing in mockup — add as consistency with other screens)
- Footer: `[+ Add Question]` link
- **Drag-reorder**: uses existing dnd library if available in FE registry; otherwise mark as SERVICE_PLACEHOLDER — on drag-end, call `ReorderEventCustomQuestions(eventId, [{id, orderBy}])`
- Add Question opens small modal: QuestionText (text), QuestionTypeId (select), IsRequired (toggle), OptionsJson (textarea, CSV — conditional on DROPDOWN/RADIO/CHECKBOX)
- Edit reuses same modal

**Bottom toggles** (below horizontal divider):
| # | Label | Sublabel | Field | Default |
|---|-------|----------|-------|---------|
| 4 | Confirmation Email | "Send automatic confirmation with ticket details and QR code" | EventSetting.SendConfirmationEmail | true |
| 5 | Reminder Emails | checkbox-group: ☑ 7 days before ☑ 1 day before (CSV stored) | EventSetting.SendReminderEmails + ReminderDaysBefore | true + "7,1" |
| 6 | QR Code Check-in | "Generate unique QR codes for each registrant for event-day check-in" | EventSetting.QRCheckInEnabled | true |

### Card 5 — Public Registration Page Preview

Pure **client-side** render — no persistence. Reads the already-loaded `EventTicketList` + `Event` + `EventSetting` and renders a styled preview.

- Toolbar with URL hint (`events.peopleserve.org/{eventSlug}`) + Desktop / Mobile toggle
- Desktop: full card width, frame max-width 100%
- Mobile: frame max-width 375px, centered
- Content:
  - Banner placeholder (gradient) with text "Event Banner Image" (SERVICE_PLACEHOLDER — real banner upload is out of this screen's scope — Event entity has no banner field, so this is display-only)
  - Event title (bold)
  - Event meta (date + venue)
  - Description (from Event.FullDescription)
  - "Select Tickets" header + list of ticket rows: name + price/person + "{remaining} remaining" + qty stepper (- 0 +)
  - Subtotal line (sums ticket.price × selectedQty across all rows — client-side only)
  - "Register Now" button (SERVICE_PLACEHOLDER — opens toast "Public registration link: {url}")

Qty stepper state is local component state (not persisted). No backend writes from this card.

### Card 6 — Registrants (collapsible)

Data source: `GetAllEventRegistrationList(eventId, searchText, ticketId, pageNo, pageSize)`.

Collapse default: **expanded**. Chevron rotates on toggle.

**Header controls** (inline, right of title):
- Search input (`registrantSearchText` store state) — searches name + email
- Ticket-type filter dropdown (populates from the EventTicket list for this event + "All Tickets" option)
- Chevron for collapse

**Grid columns**:
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Name | `registrantName` / `contactDisplayName` | **link renderer** | auto | YES | Links to `/crm/contact/contact?mode=read&id={contactId}` if ContactId set, else plain text |
| 2 | Email | `registrantEmail` | text muted | auto | NO | — |
| 3 | Ticket | `ticketName` | text | 130px | YES | — |
| 4 | Qty | `quantity` + suffix | text | 70px | NO | `2 tables` if Ticket.PricingType=PER_TABLE else `2` |
| 5 | Amount | `totalAmount` | currency bold | 100px | YES | `$10,000` |
| 6 | Registered | `registeredDate` | date | 110px | YES | `Mar 5, 2026` |
| 7 | Check-in | `checkedIn` | **check-in-toggle renderer** | 80px | NO | Simple checkbox, click toggles `CheckInRegistration` mutation |
| 8 | Actions | — | row-actions | 110px | NO | QR / Edit / Cancel |

**Row actions**:
- QR Code (qrcode icon) — download QR (SERVICE_PLACEHOLDER — toast "QR code generation pending service")
- Edit (pen icon) — opens small modal with editable name/email/qty
- Cancel (red x) — confirm dialog → `CancelRegistration(id)` → StatusId=CANCELLED, toast

**Pagination**: standard — 20 per page, page buttons 1 / 2 / 3 / ... / last, prev/next arrows.

### Page Widgets & Summary Cards

The "widgets" in this screen are the 4 stats inside Card 1's Summary Bar:

| # | Widget Title | Value Source | Display Type | Position |
|---|-------------|-------------|-------------|----------|
| 1 | Capacity | summary.capacity | number | Right stat 1 |
| 2 | Registered | summary.registered + registeredPercent | number + pct | Right stat 2 |
| 3 | Revenue | summary.totalRevenue | currency (success color) | Right stat 3 |
| 4 | Reg Status | summary.registrationStatus + closeDate | badge + subtext | Right stat 4 |

**Grid Layout Variant**: `widgets-above-grid+side-panel` — stamp this so FE Dev uses **Variant B** (`<ScreenHeader>` + composite body + no `<FlowDataTable>` wrapper on the page shell).

**Summary GQL Query**:
- Query name: `GetEventTicketingSummary(eventId: int)`
- Returns: `EventTicketingSummaryDto` with fields: `eventName, eventDate, venueName, capacity, registered, registeredPercent, totalRevenue, registrationStatus, registrationCloseDate`
- Added to `EventTicketQueries.cs` (new endpoint file).

### Grid Aggregation Columns

**Aggregation Columns** (on Ticket Types grid):

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Sold | Count of non-cancelled registrations for this ticket | `COUNT(Registrations) WHERE EventTicketId = row.EventTicketId AND StatusId ≠ CANCELLED` | LINQ subquery in GetAllEventTicketList handler |
| Revenue | Sum of confirmed-registration totals for this ticket | `SUM(Registrations.TotalAmount) WHERE EventTicketId = row.EventTicketId AND StatusId = CONFIRMED` | LINQ subquery |
| Sold Percent | Sold / QuantityAvailable × 100 | derived (FE or BE) | Computed in DTO |

### User Interaction Flow (NON-STANDARD — single-page composite)

1. User navigates to `/crm/event/eventticketing` (no query param). If no `eventId` → show empty state "Select an event to configure ticketing" with Event selector active.
2. User picks an event from the selector → URL updates to `?eventId={X}` → all 6 cards fetch data for that event in parallel:
   - `GetEventTicketingSummary(eventId)` → Card 1
   - `GetAllEventTicketList(eventId)` → Card 2 (+ Card 5 preview data)
   - `GetEventSettingByEventId(eventId)` → Card 4 toggles (auto-create default row if missing on first load)
   - `GetAllEventCustomQuestionList(eventId)` → Card 4 questions
   - `GetAllEventRegistrationList(eventId, ...)` → Card 6
3. User clicks `+ Add Ticket Type` → Card 3 form card becomes visible (empty). User fills + Save → `CreateEventTicket` → refresh Card 2 → form closes.
4. User clicks Edit on a ticket row → Card 3 form card opens with prefilled values. Save → `UpdateEventTicket` → refresh Card 2 → form closes.
5. User toggles a Registration Settings switch → debounced `UpsertEventSetting(eventId, patch)` → success toast.
6. User adds a Custom Question → small modal → `CreateEventCustomQuestion` → list refreshes.
7. User drags to reorder questions → `ReorderEventCustomQuestions(eventId, [{id, orderBy}, …])` → list refreshes.
8. User adjusts qty in Public Preview card → client-only subtotal recomputes (no backend call).
9. User searches/filters registrants → Card 6 refetches with filter args.
10. User toggles Check-in checkbox on a registrant → `CheckInRegistration(id, checkedIn)` → row refreshes.
11. User clicks Share Registration Link → `navigator.clipboard.writeText(...)` → toast "Copied".
12. User switches Event in dropdown → URL updates → all cards refetch.
13. Back button → navigates to `/crm/event/event` (Events list).
14. No unsaved-changes dialog — settings auto-save; ticket form uses explicit Save/Cancel.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to THIS entity.

**Canonical Reference**: **MatchingGift #11** (composite multi-entity FLOW — precedent for multi-entity under-one-menu screens). For the main EventTicket CRUD pieces, `SavedFilter` is the FLOW code-structure canonical, but **this screen does NOT use the 3-mode view-page** — only the file-layout conventions.

### Primary entity substitution (EventTicket ↔ SavedFilter)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | EventTicket | Entity/class name |
| savedFilter | eventTicket | Variable/field names |
| SavedFilterId | EventTicketId | PK field |
| SavedFilters | EventTickets | Table name, collection names |
| saved-filter | event-ticket | kebab-case file names |
| savedfilter | eventticket | FE folder segment (entity-lower-no-dash) |
| SAVEDFILTER | EVENTTICKETING | Grid code / Menu code — **note: MenuCode is EVENTTICKETING (the screen), not EVENTTICKET (the entity). Entity codes use EVENTTICKET, EVENTREG, EVENTCQ, EVENTSETTING individually.** |
| notify | app | DB schema |
| Notify | Application | Backend group root (to match Event's folder: `ApplicationModels`) |
| NotifyModels | ApplicationModels | Namespace suffix |
| NOTIFICATIONSETUP | CRM_EVENT | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/event/eventticketing | FE route path |
| notify-service | application-service | FE service folder name (verify during build — may also use `event-service` if that's the existing sibling) |

### Cross-entity substitution map

| Entity | PascalCase | camelCase | kebab | UPPER | Namespace |
|--------|-----------|-----------|-------|-------|-----------|
| EventTicket | EventTicket | eventTicket | event-ticket | EVENTTICKET | Base.Domain.Models.ApplicationModels |
| EventTicketBenefit | EventTicketBenefit | eventTicketBenefit | event-ticket-benefit | EVENTTICKETBENEFIT | Base.Domain.Models.ApplicationModels |
| EventRegistration | EventRegistration | eventRegistration | event-registration | EVENTREG | Base.Domain.Models.ApplicationModels |
| EventCustomQuestion | EventCustomQuestion | eventCustomQuestion | event-custom-question | EVENTCQ | Base.Domain.Models.ApplicationModels |
| EventSetting | EventSetting | eventSetting | event-setting | EVENTSETTING | Base.Domain.Models.ApplicationModels |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files — EventTicket (11 files — standard CRUD + workflow)

| # | File | Path |
|---|------|------|
| 1 | Entity | `Pss2.0_Backend/.../Base.Domain/Models/ApplicationModels/EventTicket.cs` |
| 2 | EF Config | `Pss2.0_Backend/.../Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventTicketConfiguration.cs` |
| 3 | Schemas (DTOs) | `Pss2.0_Backend/.../Base.Application/Schemas/ApplicationSchemas/EventTicketSchemas.cs` (Request, Response, ExportDto) |
| 4 | Create Command | `…/Business/ApplicationBusiness/EventTickets/CreateCommand/CreateEventTicket.cs` |
| 5 | Update Command | `…/Business/ApplicationBusiness/EventTickets/UpdateCommand/UpdateEventTicket.cs` |
| 6 | Delete Command | `…/Business/ApplicationBusiness/EventTickets/DeleteCommand/DeleteEventTicket.cs` |
| 7 | Toggle/Pause Command | `…/Business/ApplicationBusiness/EventTickets/ToggleCommand/ToggleEventTicket.cs` (Pause / Resume — flips Status ONSALE↔PAUSED) |
| 8 | GetAll Query | `…/Business/ApplicationBusiness/EventTickets/GetAllQuery/GetAllEventTicket.cs` (filters by eventId; projects soldCount + revenue) |
| 9 | GetById Query | `…/Business/ApplicationBusiness/EventTickets/GetByIdQuery/GetEventTicketById.cs` (includes Benefits) |
| 10 | Mutations endpoint | `Pss2.0_Backend/.../Base.API/EndPoints/Application/Mutations/EventTicketMutations.cs` |
| 11 | Queries endpoint | `Pss2.0_Backend/.../Base.API/EndPoints/Application/Queries/EventTicketQueries.cs` (also hosts `GetEventTicketingSummary`) |

### Backend Files — EventTicketBenefit (child; no standalone endpoints — managed within EventTicket create/update)

| # | File | Path |
|---|------|------|
| 1 | Entity | `…/ApplicationModels/EventTicketBenefit.cs` |
| 2 | EF Config | `…/ApplicationConfigurations/EventTicketBenefitConfiguration.cs` |
| 3 | DTOs (inline inside `EventTicketSchemas.cs` — request + response) | — |

### Backend Files — EventRegistration (13 files incl. workflow commands)

| # | File | Path |
|---|------|------|
| 1 | Entity | `…/ApplicationModels/EventRegistration.cs` |
| 2 | EF Config | `…/ApplicationConfigurations/EventRegistrationConfiguration.cs` |
| 3 | Schemas | `…/ApplicationSchemas/EventRegistrationSchemas.cs` |
| 4 | Create | `…/EventRegistrations/CreateCommand/CreateEventRegistration.cs` |
| 5 | Update | `…/EventRegistrations/UpdateCommand/UpdateEventRegistration.cs` |
| 6 | Delete | `…/EventRegistrations/DeleteCommand/DeleteEventRegistration.cs` |
| 7 | CheckIn | `…/EventRegistrations/CheckInCommand/CheckInEventRegistration.cs` (workflow) |
| 8 | Cancel | `…/EventRegistrations/CancelCommand/CancelEventRegistration.cs` (workflow + waitlist promotion) |
| 9 | Approve | `…/EventRegistrations/ApproveCommand/ApproveEventRegistration.cs` (workflow) |
| 10 | GetAll | `…/EventRegistrations/GetAllQuery/GetAllEventRegistration.cs` (search + ticket filter + pagination) |
| 11 | GetById | `…/EventRegistrations/GetByIdQuery/GetEventRegistrationById.cs` |
| 12 | Mutations endpoint | `…/Application/Mutations/EventRegistrationMutations.cs` |
| 13 | Queries endpoint | `…/Application/Queries/EventRegistrationQueries.cs` |

### Backend Files — EventCustomQuestion (10 files)

| # | File | Path |
|---|------|------|
| 1 | Entity | `…/ApplicationModels/EventCustomQuestion.cs` |
| 2 | EF Config | `…/ApplicationConfigurations/EventCustomQuestionConfiguration.cs` |
| 3 | Schemas | `…/ApplicationSchemas/EventCustomQuestionSchemas.cs` |
| 4 | Create | `…/EventCustomQuestions/CreateCommand/CreateEventCustomQuestion.cs` |
| 5 | Update | `…/EventCustomQuestions/UpdateCommand/UpdateEventCustomQuestion.cs` |
| 6 | Delete | `…/EventCustomQuestions/DeleteCommand/DeleteEventCustomQuestion.cs` |
| 7 | Reorder | `…/EventCustomQuestions/ReorderCommand/ReorderEventCustomQuestions.cs` (batch order update) |
| 8 | GetAll | `…/EventCustomQuestions/GetAllQuery/GetAllEventCustomQuestion.cs` |
| 9 | Mutations endpoint | `…/Application/Mutations/EventCustomQuestionMutations.cs` |
| 10 | Queries endpoint | `…/Application/Queries/EventCustomQuestionQueries.cs` |

### Backend Files — EventSetting (singleton upsert — 7 files)

| # | File | Path |
|---|------|------|
| 1 | Entity | `…/ApplicationModels/EventSetting.cs` |
| 2 | EF Config | `…/ApplicationConfigurations/EventSettingConfiguration.cs` (unique index on EventId) |
| 3 | Schemas | `…/ApplicationSchemas/EventSettingSchemas.cs` |
| 4 | Upsert | `…/EventSettings/UpsertCommand/UpsertEventSetting.cs` (Create-or-Update by EventId) |
| 5 | GetByEventId | `…/EventSettings/GetByEventIdQuery/GetEventSettingByEventId.cs` (returns default row if missing) |
| 6 | Mutations endpoint | `…/Application/Mutations/EventSettingMutations.cs` |
| 7 | Queries endpoint | `…/Application/Queries/EventSettingQueries.cs` |

### Backend — Summary query (piggy-backs on EventTicket endpoint)

| # | File | Path |
|---|------|------|
| 1 | Summary DTO | added to `EventTicketSchemas.cs` — `EventTicketingSummaryDto` |
| 2 | Summary Handler | `…/EventTickets/GetSummaryQuery/GetEventTicketingSummary.cs` |
| 3 | Summary GQL field | registered in `EventTicketQueries.cs` |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext.cs` | DbSet<EventTicket>, DbSet<EventTicketBenefit>, DbSet<EventRegistration>, DbSet<EventCustomQuestion>, DbSet<EventSetting> |
| 2 | `ApplicationDbContext.cs` | Same 5 DbSets + OnModelCreating wiring if needed |
| 3 | `DecoratorProperties.cs` | Extend `DecoratorApplicationModules` with 5 new entity props |
| 4 | `ApplicationMappings.cs` (or per-entity mapping files, following existing convention) | Mapster profiles for all 5 entities (Request↔Entity, Entity↔Response, including child Benefits) |
| 5 | EF migration | One migration `AddEventTicketingEntities` — 5 tables + unique indices + FKs |

### Frontend Files (single-page composite — NO view-page.tsx)

| # | File | Path |
|---|------|------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/application-service/EventTicketDto.ts` |
| 2 | DTO Types | `…/application-service/EventRegistrationDto.ts` |
| 3 | DTO Types | `…/application-service/EventCustomQuestionDto.ts` |
| 4 | DTO Types | `…/application-service/EventSettingDto.ts` |
| 5 | DTO Types | `…/application-service/EventTicketingSummaryDto.ts` |
| 6 | GQL Queries | `src/infrastructure/gql-queries/application-queries/EventTicketQuery.ts` (list + byId + summary) |
| 7 | GQL Queries | `…/application-queries/EventRegistrationQuery.ts` |
| 8 | GQL Queries | `…/application-queries/EventCustomQuestionQuery.ts` |
| 9 | GQL Queries | `…/application-queries/EventSettingQuery.ts` |
| 10 | GQL Mutations | `src/infrastructure/gql-mutations/application-mutations/EventTicketMutation.ts` |
| 11 | GQL Mutations | `…/application-mutations/EventRegistrationMutation.ts` |
| 12 | GQL Mutations | `…/application-mutations/EventCustomQuestionMutation.ts` |
| 13 | GQL Mutations | `…/application-mutations/EventSettingMutation.ts` |
| 14 | Page Config | `src/presentation/pages/crm/event/eventticketing.tsx` (page component factory) |
| 15 | Index Page (composite shell) | `src/presentation/components/page-components/crm/event/eventticketing/index.tsx` (Variant B: ScreenHeader + body) |
| 16 | Summary Bar card | `…/eventticketing/summary-bar.tsx` |
| 17 | Ticket Types card | `…/eventticketing/ticket-types-card.tsx` (inline grid using AdvancedDataTable) |
| 18 | Ticket Form card | `…/eventticketing/ticket-form-card.tsx` (inline add/edit, RHF) |
| 19 | Benefit Checklist widget | `…/eventticketing/benefit-checklist-widget.tsx` |
| 20 | Registration Settings card | `…/eventticketing/registration-settings-card.tsx` (toggles + questions subsection) |
| 21 | Custom Question modal | `…/eventticketing/custom-question-modal.tsx` |
| 22 | Public Preview card | `…/eventticketing/public-preview-card.tsx` (client-side render with device toggle) |
| 23 | Registrants card | `…/eventticketing/registrants-card.tsx` (collapsible grid) |
| 24 | Registrant Edit modal | `…/eventticketing/registrant-edit-modal.tsx` |
| 25 | Zustand store | `…/eventticketing/eventticketing-store.ts` |
| 26 | Inline progress renderer | `…/eventticketing/cell-renderers/inline-progress-cell.tsx` |
| 27 | Check-in toggle renderer | `…/eventticketing/cell-renderers/checkin-toggle-cell.tsx` |
| 28 | Route page | `src/app/[lang]/crm/event/eventticketing/page.tsx` (**REPLACE** existing stub — the "Need to Develop" stub must be overwritten) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `entity-operations.ts` | EVENTTICKET, EVENTREG, EVENTCQ, EVENTSETTING operations configs |
| 2 | `operations-config.ts` | Import + register 4 new operations |
| 3 | column-type registries (advanced + flow + basic) | Register `inline-progress-cell`, `checkin-toggle-cell` renderers |
| 4 | shared-cell-renderers barrel | Export new renderers |
| 5 | Sidebar menu config | EVENTTICKETING menu entry under CRM_EVENT (OrderBy=2) — auto-pulled from DB seed |
| 6 | Pages barrel | `src/presentation/pages/crm/event/index.ts` — export eventticketing page |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Event Ticketing
MenuCode: EVENTTICKETING
ParentMenu: CRM_EVENT
Module: CRM
MenuUrl: crm/event/eventticketing
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: EVENTTICKETING
---CONFIG-END---
```

**MasterData seeds required** (append to the current MasterData seed entry point used by other masters):

| TypeCode | Code | Name | OrderBy |
|----------|------|------|---------|
| EVENTPRICINGTYPE | PER_PERSON | Per person | 1 |
| EVENTPRICINGTYPE | PER_TABLE | Per table | 2 |
| EVENTPRICINGTYPE | PER_GROUP | Per group | 3 |
| EVENTTICKETVISIBILITY | PUBLIC | Public | 1 |
| EVENTTICKETVISIBILITY | HIDDEN | Hidden | 2 |
| EVENTTICKETVISIBILITY | PASSWORD | Password protected | 3 |
| EVENTTICKETSTATUS | ONSALE | On Sale | 1 |
| EVENTTICKETSTATUS | SOLDOUT | Sold Out | 2 |
| EVENTTICKETSTATUS | PAUSED | Paused | 3 |
| EVENTTICKETSTATUS | EXPIRED | Expired | 4 |
| EVENTREGSTATUS | PENDING | Pending | 1 |
| EVENTREGSTATUS | CONFIRMED | Confirmed | 2 |
| EVENTREGSTATUS | CANCELLED | Cancelled | 3 |
| EVENTREGSTATUS | WAITLIST | Waitlist | 4 |
| EVENTQUESTIONTYPE | TEXT | Text | 1 |
| EVENTQUESTIONTYPE | DROPDOWN | Dropdown | 2 |
| EVENTQUESTIONTYPE | CHECKBOX | Checkbox | 3 |
| EVENTQUESTIONTYPE | RADIO | Radio | 4 |
| EVENTQUESTIONTYPE | NUMBER | Number | 5 |
| EVENTQUESTIONTYPE | DATE | Date | 6 |

**DB Seed file**: `EventTicketing-sqlscripts.sql` (idempotent — `IF NOT EXISTS` guards on Menu / MenuCapability / RoleCapability / MasterData rows). Seed file goes in `sql-scripts-dyanmic/` (preserve existing repo-wide typo).

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query types: `EventTicketQueries`, `EventRegistrationQueries`, `EventCustomQuestionQueries`, `EventSettingQueries` (all extend `[ExtendObjectType("Query")]`)
- Mutation types: `EventTicketMutations`, `EventRegistrationMutations`, `EventCustomQuestionMutations`, `EventSettingMutations`

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| getAllEventTicketList | [EventTicketResponseDto] | eventId, searchText, pageNo, pageSize, sortField, sortDir, isActive |
| getEventTicketById | EventTicketResponseDto | eventTicketId |
| getEventTicketingSummary | EventTicketingSummaryDto | eventId |
| getAllEventRegistrationList | [EventRegistrationResponseDto] | eventId, ticketId, searchText, pageNo, pageSize, sortField, sortDir |
| getEventRegistrationById | EventRegistrationResponseDto | eventRegistrationId |
| getAllEventCustomQuestionList | [EventCustomQuestionResponseDto] | eventId |
| getEventSettingByEventId | EventSettingResponseDto | eventId (returns default row if not present) |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| createEventTicket | EventTicketRequestDto (with benefits[]) | int |
| updateEventTicket | EventTicketRequestDto | int |
| deleteEventTicket | eventTicketId | int (fails if soldCount > 0) |
| toggleEventTicket | eventTicketId | int (IsActive toggle) |
| pauseEventTicket | eventTicketId | int (Status ONSALE→PAUSED) |
| resumeEventTicket | eventTicketId | int (Status PAUSED→ONSALE) |
| createEventRegistration | EventRegistrationRequestDto | int |
| updateEventRegistration | EventRegistrationRequestDto | int |
| deleteEventRegistration | eventRegistrationId | int |
| checkInEventRegistration | { eventRegistrationId, checkedIn } | int |
| cancelEventRegistration | eventRegistrationId | int |
| approveEventRegistration | eventRegistrationId | int |
| createEventCustomQuestion | EventCustomQuestionRequestDto | int |
| updateEventCustomQuestion | EventCustomQuestionRequestDto | int |
| deleteEventCustomQuestion | eventCustomQuestionId | int |
| reorderEventCustomQuestions | { eventId, items: [{ id, orderBy }] } | int |
| upsertEventSetting | EventSettingRequestDto | int |

**Response DTO Fields — `EventTicketResponseDto`:**
| Field | Type | Notes |
|-------|------|-------|
| eventTicketId | number | PK |
| eventTicketCode | string | — |
| eventId | number | FK |
| eventName | string | Projected from Event.ShortDescription |
| ticketName | string | — |
| emojiIcon | string | — |
| description | string | — |
| pricingTypeId | number | FK |
| pricingTypeCode | string | PER_PERSON / PER_TABLE / PER_GROUP |
| pricingTypeName | string | Display |
| currencyId | number | FK |
| currencyCode | string | "USD" |
| price | number | — |
| groupSize | number \| null | — |
| quantityAvailable | number | — |
| saleStartDate | string \| null | ISO |
| saleEndDate | string \| null | ISO |
| minPerOrder | number | — |
| maxPerOrder | number | — |
| visibilityId | number | FK |
| visibilityCode | string | — |
| discountCode | string \| null | — |
| statusId | number | FK |
| statusCode | string | ONSALE / SOLDOUT / PAUSED / EXPIRED |
| statusName | string | — |
| sortOrder | number | — |
| **soldCount** | number | **Projected: count of non-cancelled registrations** |
| **revenue** | number | **Projected: sum of confirmed-registration totals** |
| **soldPercent** | number | **Derived: soldCount / quantityAvailable × 100** |
| benefits | EventTicketBenefitResponseDto[] | Nested child (from GetById) |
| isActive | boolean | Inherited |

**Response DTO Fields — `EventTicketBenefitResponseDto`:**
| Field | Type |
|-------|------|
| eventTicketBenefitId | number |
| eventTicketId | number |
| benefitText | string |
| isIncluded | boolean |
| orderBy | number |

**Response DTO Fields — `EventRegistrationResponseDto`:**
| Field | Type | Notes |
|-------|------|-------|
| eventRegistrationId | number | PK |
| eventRegistrationCode | string | — |
| eventId | number | — |
| eventTicketId | number | — |
| ticketName | string | Projected |
| contactId | number \| null | — |
| contactDisplayName | string \| null | Projected (if linked contact) |
| registrantName | string | — |
| registrantEmail | string | — |
| registrantPhone | string \| null | — |
| quantity | number | — |
| totalAmount | number | — |
| currencyCode | string | Projected from ticket |
| registeredDate | string | ISO |
| checkedIn | boolean | — |
| checkedInDate | string \| null | — |
| qrCodeToken | string \| null | — |
| statusId | number | — |
| statusCode | string | — |
| statusName | string | — |
| isActive | boolean | — |

**Response DTO Fields — `EventCustomQuestionResponseDto`:**
| Field | Type |
|-------|------|
| eventCustomQuestionId | number |
| eventId | number |
| questionText | string |
| questionTypeId | number |
| questionTypeCode | string |
| questionTypeName | string |
| isRequired | boolean |
| optionsJson | string \| null |
| orderBy | number |

**Response DTO Fields — `EventSettingResponseDto`:**
| Field | Type |
|-------|------|
| eventSettingId | number \| null |
| eventId | number |
| isRegistrationOpen | boolean |
| waitlistEnabled | boolean |
| approvalRequired | boolean |
| sendConfirmationEmail | boolean |
| sendReminderEmails | boolean |
| reminderDaysBefore | string \| null |
| qrCheckInEnabled | boolean |
| passwordProtectedCode | string \| null |

**Response DTO Fields — `EventTicketingSummaryDto`:**
| Field | Type | Source |
|-------|------|--------|
| eventId | number | arg |
| eventName | string | Event.ShortDescription |
| eventDate | string | Event.StartDate (ISO) |
| venueName | string | Event.VenueName |
| venueAddress | string | Event.VenueAddress |
| capacity | number | SUM(EventTickets.QuantityAvailable) |
| registered | number | SUM(Registrations.Quantity) WHERE Status ≠ CANCELLED |
| registeredPercent | number | registered / capacity × 100 |
| totalRevenue | number | SUM(Registrations.TotalAmount) WHERE Status = CONFIRMED |
| currencyCode | string | Most common currency across tickets (or first) |
| registrationStatus | string | "Open" / "Closed" / "Not started" — computed from EventSetting.IsRegistrationOpen + dates |
| registrationCloseDate | string \| null | Event.RegistrationEndDate OR EventSetting-derived |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `pnpm dev` — page loads at `/{lang}/crm/event/eventticketing` and at `?eventId=1`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Page header renders with breadcrumb, title, subtitle, event selector dropdown, Preview + Share buttons
- [ ] Event selector dropdown populates from `getEvents` query, label = ShortDescription
- [ ] Selecting an event updates URL `?eventId=X` and triggers re-fetch of all cards
- [ ] With no eventId selected: shows "Select an event to configure ticketing" empty state
- [ ] **Card 1** — Summary Bar shows event name, date, venue, capacity, registered+%, revenue, status badge; values come from `GetEventTicketingSummary`
- [ ] **Card 2** — Ticket Types grid loads for selected event with all 7 columns
- [ ] Sold column shows inline progress bar + numeric value; color adjusts by percent
- [ ] Status column renders badge (ONSALE green, SOLDOUT grey, PAUSED warning, EXPIRED grey italic)
- [ ] Expired rows have `opacity: 0.55` styling
- [ ] `+ Add Ticket Type` opens Card 3 (inline form)
- [ ] **Card 3** — form renders all fields as specified; PricingType=PER_PERSON hides GroupSize, PER_TABLE/PER_GROUP shows it
- [ ] Discount Code toggle shows/hides code input
- [ ] Benefits checklist: add / remove / toggle individual rows; "+ Add Benefit" link appends row
- [ ] Save creates EventTicket + child benefits atomically → grid refreshes → form closes
- [ ] Edit row → form opens pre-filled → save updates → grid refreshes
- [ ] More menu: Duplicate prefills form, Pause Sales toggles status, Delete confirms + deletes (fails with toast if soldCount > 0)
- [ ] **Card 4** — 3 top toggles persist on change (debounced upsert)
- [ ] Custom Questions list renders from GetAllEventCustomQuestionList
- [ ] Add Question modal saves new question → list refreshes
- [ ] Edit question modal updates → list refreshes
- [ ] Drag-reorder sends ReorderEventCustomQuestions mutation (if dnd available; otherwise toast "Reorder pending service")
- [ ] Bottom 3 toggles (Confirmation / Reminder + checkboxes / QR) persist on change
- [ ] **Card 5** — Public Preview renders with desktop/mobile toggle; ticket rows render with qty steppers; subtotal recomputes client-side
- [ ] Register Now button fires toast / placeholder (SERVICE_PLACEHOLDER)
- [ ] **Card 6** — Registrants card is collapsible; expanded by default
- [ ] Search filters registrants by name/email
- [ ] Ticket-type dropdown filters registrants
- [ ] Check-in checkbox toggles CheckedIn status → row updates
- [ ] QR action button shows toast (SERVICE_PLACEHOLDER)
- [ ] Edit action opens inline modal with name/email/qty → save updates registration
- [ ] Cancel action confirms + cancels registration (StatusId=CANCELLED)
- [ ] Pagination works (20 per page)
- [ ] Preview Public Page button (header) opens `/public/event/{eventId}/register` in new tab (SERVICE_PLACEHOLDER)
- [ ] Share Registration Link button copies link to clipboard (client-side, IN SCOPE)
- [ ] Back button navigates to `/crm/event/event`
- [ ] Variant B layout verified: `<ScreenHeader>` is the page-level header; no double headers
- [ ] No standard FlowDataTable wrapper on the page shell (internal card grids use AdvancedDataTable inline mode)
- [ ] Permissions: Edit / Delete buttons respect role capabilities

**DB Seed Verification:**
- [ ] Menu "Event Ticketing" appears in sidebar under CRM → Events (OrderBy=2) — between Events (OrderBy=1) and Auction Management (OrderBy=3)
- [ ] Role capabilities seeded for BUSINESSADMIN
- [ ] 5 new MasterData TypeCodes present with all rows (EVENTPRICINGTYPE × 3, EVENTTICKETVISIBILITY × 3, EVENTTICKETSTATUS × 4, EVENTREGSTATUS × 4, EVENTQUESTIONTYPE × 6)
- [ ] GridFormSchema: SKIP (no RJSF schema generated — this screen uses inline forms)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

**NON-STANDARD FLOW PATTERN:**
- This FLOW screen is a **single-page composite configuration screen**, NOT the standard 3-mode grid→form→detail workflow.
- There is **NO `view-page.tsx` with `?mode=new|edit|read`**. All CRUD happens inline within the main page.
- Do NOT generate the standard FLOW view-page.tsx + Zustand store-for-form pattern. Zustand is still used, but only for UI state (which card/form is open).
- Mark GridType: FLOW in Approval Config for consistency with the registry, but the page shell is **Variant B** (ScreenHeader + composite body) NOT `<FlowDataTable>`.

**MULTI-ENTITY SCOPE** (5 new tables + 1 migration):
- This prompt creates **5 new BE entities** (EventTicket, EventTicketBenefit, EventRegistration, EventCustomQuestion, EventSetting) in the existing `app` schema.
- No new module/DbContext required — `app` schema already has DbContext infrastructure. Just extend `IApplicationDbContext`, `ApplicationDbContext`, `DecoratorApplicationModules`, `ApplicationMappings` (or per-entity mapping files if that's the convention).
- One EF migration `AddEventTicketingEntities` creates all 5 tables + unique indices + FKs.
- Backend file count is **~48 files** (entity stacks for all 5 + shared migration + summary query). Plan accordingly.

**FE ROUTE ALREADY STUBBED:**
- `PSS_2.0_Frontend/src/app/[lang]/crm/event/eventticketing/page.tsx` currently contains a "Need to Develop" stub.
- FE Dev MUST **replace** this file (not create alongside it). The path is correct — do not change the route.

**EVENT ENTITY QUIRKS (FK target):**
- Event entity lives in `app` schema / `ApplicationModels` group — **NOT** in an `Organization` or `Events` group as the mockup filename suggests.
- Event has **no `EventName` field** — display name is `ShortDescription`. FE ApiSelectV2 for the event selector must map `label: eventResp.shortDescription`.
- The GQL field for Event list is `getEvents` (camelCase, unusual), NOT `GetAllEventList`. Verify spelling when wiring the selector.
- Event has no `Capacity` field. The summary "Capacity = 300" in the mockup is DERIVED from `SUM(EventTickets.QuantityAvailable)`, NOT a field on Event.

**FILE-FOLDER CONVENTIONS:**
- Backend: All 5 entities go under the `ApplicationModels` group to match Event's location.
  - Models folder: `Base.Domain/Models/ApplicationModels/`
  - EF configs folder: `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/`
  - Schemas folder: `Base.Application/Schemas/ApplicationSchemas/`
  - Business folder: `Base.Application/Business/ApplicationBusiness/{PluralEntityName}/`
  - Endpoints folder: `Base.API/EndPoints/Application/{Mutations|Queries}/`
- Frontend:
  - Domain entities: `src/domain/entities/application-service/` (verify exists — if not, create; sibling of other service folders)
  - GQL queries: `src/infrastructure/gql-queries/application-queries/`
  - GQL mutations: `src/infrastructure/gql-mutations/application-mutations/`
  - Page component: `src/presentation/components/page-components/crm/event/eventticketing/` (NEW folder)
  - Pages: `src/presentation/pages/crm/event/eventticketing.tsx` (NEW file)
  - Route: `src/app/[lang]/crm/event/eventticketing/page.tsx` (REPLACE existing stub)

**WIRING FOR EXISTING APPLICATION GROUP:**
- Confirm which wiring files exist for ApplicationModels. If `ApplicationMappings.cs` doesn't exist, use the existing convention (check `EventMappings.cs` or similar) — the group may use a per-entity mapping pattern, not one combined file.
- The `application-service` FE domain folder may need to be created if no sibling uses it yet. Alternatively, place DTOs under `event-service/` if that already exists for Event. Verify during build.

**WORKFLOW / STATE MACHINE:**
- EventTicket: ONSALE ↔ PAUSED (manual); ONSALE → SOLDOUT (auto on capacity); ONSALE → EXPIRED (auto on SaleEndDate). Auto-transitions happen in the GetAll projection (lazy evaluation — do NOT persist until explicit change OR run a nightly job to materialize).
- EventRegistration: PENDING → CONFIRMED → CANCELLED; with WAITLIST bypass when over capacity.
- Waitlist promotion: when a CONFIRMED cancels, promote the oldest WAITLIST registration for the same ticket. Implement inline in `CancelEventRegistration` handler.

**SERVICE DEPENDENCIES (UI-only — no backend service implementation yet):**

- ⚠ SERVICE_PLACEHOLDER: **Preview Public Page** header button — full UI implemented. Handler opens `/public/event/{eventId}/register` in new tab or shows toast with URL. The public registration page itself is NOT in this screen's scope.
- ⚠ SERVICE_PLACEHOLDER: **Register Now** button inside the Public Preview card — fires toast. Actual public registration flow is a separate screen/feature.
- ⚠ SERVICE_PLACEHOLDER: **Event Banner Image** preview — shows gradient placeholder. Real banner upload is a separate feature (Event entity has no banner field). Do NOT add a banner upload widget to this screen.
- ⚠ SERVICE_PLACEHOLDER: **Download QR Code** registrant row action — toast "QR code generation pending service". QR library integration is future work.
- ⚠ SERVICE_PLACEHOLDER: **Confirmation Email send** — EventSetting.SendConfirmationEmail persists correctly; on a real registration, email send is conditional on an email-service layer that may not yet exist. Do NOT block registration on email failure — enqueue/toast success regardless.
- ⚠ SERVICE_PLACEHOLDER: **Reminder Email scheduling** — EventSetting.ReminderDaysBefore persists; actual scheduled-job dispatch is out of scope.
- ⚠ SERVICE_PLACEHOLDER: **Drag-to-reorder custom questions** — if `@dnd-kit` (or equivalent) is not already in the FE registry, render draggable UI but stub the handler with toast "Reorder pending — save via edit form instead". The `ReorderEventCustomQuestions` BE command should still be implemented.

Full UI must be built (buttons, forms, modals, panels, cards, interactions). Only the handlers for external service calls are mocked. The Share Registration Link button uses `navigator.clipboard.writeText(url)` and is fully in scope (client-side only, no external service required).

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Planning | HIGH | BE | Event entity's GQL field is `getEvents` (not `GetAllEventList`); event has no `EventName` — uses `ShortDescription`. Event selector must handle both. | OPEN |
| ISSUE-2 | Planning | HIGH | BE | Event has no `Capacity` column. Summary capacity = `SUM(EventTickets.QuantityAvailable)` — NOT a field. Must be projected in summary query. | OPEN |
| ISSUE-3 | Planning | MED | BE | `application-service` FE domain folder may not exist yet — verify and create if needed, or use `event-service` if that's the existing sibling. | OPEN |
| ISSUE-4 | Planning | MED | BE | `ApplicationMappings.cs` may not exist — group may use per-entity mapping files. Follow the existing Event mapping convention. | OPEN |
| ISSUE-5 | Planning | MED | BE | Auto-transition ONSALE→SOLDOUT and ONSALE→EXPIRED is lazy (computed in GetAll). No nightly job implemented. May require follow-up job. | OPEN |
| ISSUE-6 | Planning | LOW | FE | Drag-to-reorder custom questions requires dnd library. If not available, render handle but stub handler with toast; BE reorder command still implemented. | OPEN |
| ISSUE-7 | Planning | LOW | FE | Public Preview card's qty stepper is client-side illustration only — does not persist. Subtotal recomputes on change. | OPEN |
| ISSUE-8 | Planning | LOW | BE | Waitlist promotion logic: on `CancelEventRegistration`, promote oldest WAITLIST for same ticket if capacity frees. Handler must implement this inline. | OPEN |
| ISSUE-9 | Planning | LOW | BE/FE | QR code generation is SERVICE_PLACEHOLDER — `QRCodeToken` column exists; FE QR download action toasts. Follow-up feature. | OPEN |
| ISSUE-10 | Planning | LOW | BE/FE | Email service (confirmation + reminders) is SERVICE_PLACEHOLDER. Settings persist; actual send is deferred. | OPEN |
| ISSUE-11 | Planning | LOW | FE | Public page Preview uses hardcoded gradient banner placeholder — Event entity has no banner field. Out of this screen's scope. | OPEN |
| ISSUE-12 | Planning | MED | FE | `inline-progress-cell` renderer is new — must be registered in all 3 column-type registries (advanced + flow + basic) + shared-cell-renderers barrel. | OPEN |
| ISSUE-13 | Planning | LOW | DB | Seed file goes in `sql-scripts-dyanmic/` (preserve existing repo typo). | OPEN |
| ISSUE-14 | Planning | MED | BE | `DeleteEventTicket` must reject when `soldCount > 0` (non-cancelled registrations exist). Provide archive-via-toggle alternative. | OPEN |
| ISSUE-15 | Planning | LOW | BE | EventSetting is singleton per event. `UpsertEventSetting` handler must create default row if none exists (triggered by GetByEventId missing). Default values defined in § 2.5. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}
