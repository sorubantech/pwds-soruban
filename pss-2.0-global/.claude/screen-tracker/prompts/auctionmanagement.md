---
screen: AuctionItem
registry_id: 48
module: Organization / CRM_EVENT
status: PENDING
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO — reuses Application (ApplicationModels) group
planned_date: 2026-04-20
completed_date:
last_session_date:
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (console-style single-page with inline form + side panels — not standard 3-mode FLOW)
- [x] Existing code reviewed (FE route is `Need to Develop` stub; ZERO BE — no AuctionItem/AuctionBid entities exist)
- [x] Business rules + workflow extracted (bidding state machine + item state machine + payment state machine)
- [x] FK targets resolved (Event, Contact — verified paths + GQL)
- [x] File manifest computed
- [x] Approval config pre-filled (MenuCode=AUCTIONMANAGEMENT, ParentMenu=CRM_EVENT, OrderBy=3)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [ ] BA Analysis validated
- [ ] Solution Resolution complete
- [ ] UX Design finalized (single console page — NOT standard view-page; see §⑥ for non-standard layout)
- [ ] User Approval received
- [ ] Backend code generated (4 entities: EventAuction, AuctionItem, AuctionBid, AuctionItemPhoto + workflow commands + migration + 5 MasterData seeds)
- [ ] Backend wiring complete
- [ ] Frontend code generated (console page + inline form + 4 modals + Zustand store + bid-feed poller)
- [ ] Frontend wiring complete
- [ ] DB Seed script generated (GridFormSchema=SKIP; includes 5 MasterData types + sample data)
- [ ] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `/[lang]/crm/event/auctionmanagement`
- [ ] Event selector dropdown loads events; switching event reloads items+bids+winners
- [ ] 4 KPI widgets display correct counts from `GetAuctionSummary` query
- [ ] Auction Items grid loads with 10 columns and server-side search/filter (category, status)
- [ ] "+Add Item" expands inline collapsible form below grid; Save creates AuctionItem; form collapses
- [ ] Row "Edit" action opens Edit Item modal; Save updates item; grid refreshes
- [ ] Row "Pause"/"Remove"/"Lower Reserve" actions work with optimistic + confirm dialogs
- [ ] "Open Bidding" / "Close Bidding" buttons update EventAuction.BiddingStatusId and trigger status badge + timer refresh
- [ ] "View Bids" button opens Bid History modal showing AuctionBid rows
- [ ] Bid Activity Feed polls (30 s) and appends new bids to top (SERVICE_PLACEHOLDER for websocket)
- [ ] Winners & Payment table shows items with WinnerContactId set; actions: Receipt (PLACEHOLDER), Send Invoice (PLACEHOLDER), Collect (RecordPayment), Override (AwardItem for below-reserve), Re-auction (ReAuctionItem)
- [ ] Bidder / Donor / Winner contact name links navigate to `/[lang]/crm/contact/contact?mode=read&id={contactId}`
- [ ] Event breadcrumb + Back button navigate to `/[lang]/crm/event/event`
- [ ] Photos upload placeholder renders; upload handler shows toast (SERVICE_PLACEHOLDER)
- [ ] DB Seed — menu "Auction Management" visible in sidebar under CRM_EVENT at OrderBy=3
- [ ] 5 MasterData types seeded (AUCTIONITEMCATEGORY/AUCTIONITEMSTATUS/AUCTIONPAYMENTSTATUS/AUCTIONBIDDINGSTATUS/AUCTIONTYPE) with ColorHex where applicable

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage.

Screen: **Auction Management** (entity: `AuctionItem`; parent config: `EventAuction`; children: `AuctionBid`, `AuctionItemPhoto`)
Module: **CRM → Events** (parent menu `CRM_EVENT`, MenuId 271, OrderBy 3)
Schema: **`app`**
Group: **Application** (Business/Endpoints/Schemas) / **ApplicationModels** (Domain) / **ApplicationConfigurations** (EF configs)

Business:
Fundraising events frequently include charity auctions — attendees bid on donated/sponsored items, highest accepted bid wins, proceeds go to the event's cause. This screen is a **per-event auction console** launched from the Event list/detail: an admin selects an Event (via the header event-selector) and manages that event's auction end-to-end from a single console page — items catalog, bid tracking, winner settlement, and payment collection. The screen encapsulates five parallel flows: (1) item lifecycle (add → active → paused/below-reserve → won/no-winner); (2) event-level bidding window (not-started → open → closed); (3) live bid activity feed; (4) post-bidding winner resolution; (5) winner payment collection. Related but distinct from Event Ticketing (#46, registration revenue) and Event (#40, event definition); auctions are orthogonal sub-entity of a single event. There is no separate "Auction Catalog" across events — items belong to exactly one event.

The mockup is **NOT a standard grid+form+detail FLOW**. It is a **console/dashboard page** for one event at a time with:
- Event-scoped item grid (10 columns)
- Inline collapsible Add/Edit form below the grid
- 4 KPI cards above the grid
- Two-column lower panel (live Bid Activity Feed | Winners & Payment table)
- No separate "detail" URL mode — row interactions use modals (Edit, View Bids, Lower Reserve, Award)

This is formally logged as `screen_type: FLOW` to match registry classification, but Section ⑤ documents the non-standard deviations.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer.
> All fields extracted from HTML mockup. Audit columns inherited from `Entity` base. **CompanyId is NOT a field** — tenant scope comes from HttpContext.

### Entity 1 — `EventAuction` (1:1 with Event, governs event-level bidding state)

Table: **`app."EventAuctions"`**

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| EventAuctionId | int | — | PK | — | Primary key |
| EventId | int | — | YES | app.Events | **Unique** (one auction per event) |
| BiddingStatusId | int | — | YES | shared.MasterData | AUCTIONBIDDINGSTATUS (NotStarted/Open/Closed) |
| BiddingOpensAt | DateTime? | — | NO | — | Scheduled open time (optional) |
| BiddingClosesAt | DateTime? | — | NO | — | Scheduled close time (drives "Closes in 2h 30m") |
| ActualOpenedAt | DateTime? | — | NO | — | Set when OpenBidding called |
| ActualClosedAt | DateTime? | — | NO | — | Set when CloseBidding called |
| AuctionNotes | string? | 500 | NO | — | Admin notes |

### Entity 2 — `AuctionItem` (main grid entity)

Table: **`app."AuctionItems"`**

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AuctionItemId | int | — | PK | — | Primary key |
| EventId | int | — | YES | app.Events | Auction scope (denormalized for query speed; also index) |
| EventAuctionId | int | — | YES | app.EventAuctions | Parent auction |
| ItemName | string | 200 | YES | — | Display name |
| Description | string | 2000 | YES | — | Detailed description (textarea) |
| CategoryId | int? | — | NO | shared.MasterData | AUCTIONITEMCATEGORY (Travel/Dining/Art/…) |
| AuctionTypeId | int | — | YES | shared.MasterData | AUCTIONTYPE (Silent / Live) |
| DonorName | string? | 200 | NO | — | Free-text donor/sponsor ("Atlantis Hotel") |
| DonorContactId | int? | — | NO | corg.Contacts | Optional link if donor is a tracked contact |
| EstimatedValue | decimal? | (18,2) | NO | — | Marketing value |
| StartingBid | decimal | (18,2) | YES | — | Opening bid floor |
| BidIncrement | decimal | (18,2) | YES | — | Default 100 per mockup |
| ReservePrice | decimal? | (18,2) | NO | — | If NULL, no reserve; bids below reserve → BelowReserve status |
| CurrentHighBid | decimal? | (18,2) | NO | — | Cached max(AuctionBid.Amount); updated by trigger/app logic |
| BidsCount | int | — | YES | — | Cached COUNT(AuctionBid); default 0 |
| StatusId | int | — | YES | shared.MasterData | AUCTIONITEMSTATUS (Active/BelowReserve/Paused/Closed/Won/NoWinner) |
| WinnerContactId | int? | — | NO | corg.Contacts | Set on AwardItem |
| WinningBidAmount | decimal? | (18,2) | NO | — | = the winning AuctionBid.Amount |
| PaymentStatusId | int? | — | NO | shared.MasterData | AUCTIONPAYMENTSTATUS (Pending/Awaiting/Paid) |
| PaymentMethodText | string? | 100 | NO | — | Free text: "Cash", "•••4567" |
| PaymentCollectedDate | DateTime? | — | NO | — | — |
| CurrencyId | int | — | YES | gen.Currency | Inherit from Company default |
| SortOrder | int | — | YES | — | Display order in grid; default = last |

### Entity 3 — `AuctionBid` (child of AuctionItem; powers Bid Activity feed)

Table: **`app."AuctionBids"`**

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AuctionBidId | int | — | PK | — | Primary key |
| AuctionItemId | int | — | YES | app.AuctionItems | Parent item |
| BidderContactId | int | — | YES | corg.Contacts | Who placed bid |
| Amount | decimal | (18,2) | YES | — | Bid amount |
| BidDate | DateTime | — | YES | — | Server-side DateTime.UtcNow on insert |
| IsCurrentHighest | bool | — | YES | — | True for the top bid per item (update on new bid); filtered-index for fast lookup |
| IsValid | bool | — | YES | — | True unless retracted/disqualified |
| Note | string? | 200 | NO | — | Admin note |

### Entity 4 — `AuctionItemPhoto` (child of AuctionItem; up to 6 photos per mockup)

Table: **`app."AuctionItemPhotos"`**

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| AuctionItemPhotoId | int | — | PK | — | Primary key |
| AuctionItemId | int | — | YES | app.AuctionItems | Parent item |
| PhotoUrl | string | 500 | YES | — | Storage URL (SERVICE_PLACEHOLDER — mock uploader) |
| DisplayOrder | int | — | YES | — | 0..5 |
| UploadedDate | DateTime | — | YES | — | — |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (for `.Include()` and navigation) + Frontend Developer (for ApiSelectV2).

| FK Field | Target Entity | Entity File Path | GQL Query (FE) | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| EventId | Event | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/Event.cs` | `events` (existing in `EVENTS_QUERY` — `EventQuery.ts`) | eventCategory.dataName or a composed title (Event has no EventName — per #40 plan ISSUE-1) | EventResponseDto |
| DonorContactId / BidderContactId / WinnerContactId | Contact | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ContactModels/Contact.cs` | `contacts` (existing in `ContactQuery.ts`) | displayName / fullName | ContactResponseDto |
| CategoryId / AuctionTypeId / StatusId / PaymentStatusId / BiddingStatusId | MasterData | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/MasterData.cs` | `masterDataByType` (GetMasterDataByType) | dataName | MasterDataResponseDto |
| CurrencyId | Currency | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/SharedModels/Currency.cs` | `currencies` (existing) | currencyCode | CurrencyResponseDto |

**Notes:**
- **Event name is missing** (ISSUE-1 in #40 Event plan). Use a composed title client-side (e.g. `EventCategory.DataName + " · " + StartDate`) until Event.EventName column is added. Auction page header event-selector must gracefully handle this.
- **Campaign FK is NOT needed** — Registry lists it as a dep but the mockup does NOT reference Campaign. Auctions attach to Events only. Confirmed by line-by-line mockup read.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation).

**Uniqueness Rules:**
- `EventAuction.EventId` — UNIQUE INDEX (one auction per event)
- `AuctionItem.ItemName` — unique per EventId (filtered index on IsActive=1)

**Required Field Rules:**
- AuctionItem: EventId, EventAuctionId, ItemName, Description, AuctionTypeId, StartingBid, BidIncrement, StatusId, CurrencyId
- AuctionBid: AuctionItemId, BidderContactId, Amount, BidDate
- EventAuction: EventId, BiddingStatusId

**Conditional Rules:**
- ReservePrice must be ≥ StartingBid if provided
- BidIncrement > 0 (default 100)
- EstimatedValue, StartingBid, BidIncrement, ReservePrice → decimal ≥ 0
- `AuctionBid.Amount` must be ≥ `(CurrentHighBid ?? StartingBid) + BidIncrement` UNLESS it's the first bid
- `AuctionItem.WinnerContactId` / `WinningBidAmount` / `PaymentStatusId` only set when StatusId ∈ (Won, NoWinner→payment null)
- Photos: max 6 per AuctionItem (enforce in Create/Update command)

**Business Logic (state machines):**

### Bidding Status (EventAuction.BiddingStatusId) — event-level
```
NotStarted ──(OpenBidding)──▶ Open ──(CloseBidding)──▶ Closed
                                 ▲                        │
                                 └───(ReOpenBidding)──────┘  (admin override, audit logged)
```
- On `OpenBidding`: require ≥1 AuctionItem; set ActualOpenedAt; cascade Active to all items (except Paused/Won).
- On `CloseBidding`: set ActualClosedAt; for each item resolve winner — highest valid bid ≥ reserve → set StatusId=Won, WinnerContactId, WinningBidAmount, PaymentStatusId=Awaiting; items below reserve → StatusId=NoWinner.

### Item Status (AuctionItem.StatusId)
```
Active ─┬─(bid accepted)─▶ Active (remains; CurrentHighBid/BidsCount updated)
        ├─(bid below reserve, highest)─▶ BelowReserve
        ├─(PauseItem)─▶ Paused ──(ResumeItem)──▶ Active
        ├─(CloseBidding: ≥reserve)─▶ Won
        ├─(CloseBidding: <reserve)─▶ NoWinner
        ├─(AwardItem — admin override for NoWinner/BelowReserve)─▶ Won
        └─(ReAuctionItem)─▶ Active (clears WinnerContactId, bids, resets BidsCount; does NOT delete AuctionBid history — flag IsValid=false)
```

### Payment Status (AuctionItem.PaymentStatusId, only when Status=Won)
```
Awaiting ──(SendInvoice)──▶ Awaiting (marker only; SERVICE_PLACEHOLDER)
Awaiting ──(RecordPayment/Collect)──▶ Paid (sets PaymentMethodText + PaymentCollectedDate)
```

**Workflow commands (beyond CRUD):**
- `OpenBidding(eventAuctionId)` / `CloseBidding(eventAuctionId)` / `ReOpenBidding(eventAuctionId)`
- `PauseItem(auctionItemId)` / `ResumeItem(auctionItemId)`
- `LowerReserve(auctionItemId, newReservePrice)`
- `AwardItem(auctionItemId, winnerContactId, winningBidAmount)` — admin override
- `ReAuctionItem(auctionItemId)` — invalidates all prior AuctionBids, resets status to Active
- `RecordPayment(auctionItemId, paymentMethodText)` — collects payment
- `SendInvoice(auctionItemId)` — SERVICE_PLACEHOLDER (no email infra wired to this)
- `PlaceBid(auctionItemId, bidderContactId, amount, note?)` — admin manual entry (mocks the public bidder-submitted flow for now)
- `ReorderItems(eventAuctionId, orderedItemIds[])` — manual grid drag-reorder
- `UploadItemPhoto(auctionItemId, photoUrl)` — SERVICE_PLACEHOLDER (no blob storage)

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — PRE-ANSWERED decisions based on mockup analysis.

**Screen Type**: FLOW (registry-declared), **custom console variant**
**Type Classification**: Console / Hub screen with inline form + modal row-editor + side panels
**Reason**: Event-scoped single-page console — not the canonical FLOW with `?mode=new/edit/read` URL switching. The mockup has inline collapsible Add form, modal Edit, no separate DETAIL page. Classification deviates from pure FLOW and is closer to MASTER_GRID with side panels + context-selector.

**Deviations from canonical FLOW (`_FLOW.md` template)**:
1. **NO `view-page.tsx` with 3 URL modes**. The entire screen is one component (index-page.tsx) at `/[lang]/crm/event/auctionmanagement`.
2. **NO URL mode** — `?eventId={selectedEventId}` is the only URL param (context scope).
3. **Add Item** = inline collapsible card below grid (toggled by state, scrolls into view). NOT URL-driven.
4. **Edit Item** = modal dialog triggered from row action. NOT URL-driven.
5. **View Bids** = modal dialog (bid-history-modal). NOT a detail page.
6. **LAYOUT 1 (FORM)** = the inline collapsible card. **LAYOUT 2 (DETAIL)** = N/A (no detail page). The mockup does not use `?mode=read&id=X`.

**Backend Patterns Required:**
- [x] Standard CRUD × 4 entities (EventAuction simple CRUD, AuctionItem 11-file standard, AuctionBid CRUD, AuctionItemPhoto CRUD)
- [x] Tenant scoping (CompanyId from HttpContext on all 4 entities)
- [x] Nested child creation — AuctionItem command may include inline Photos array
- [x] Multi-FK validation (ValidateForeignKeyRecord × 5: Event, Contact×3, MasterData×5, Currency)
- [x] Unique validation — EventAuction.EventId, AuctionItem.ItemName per Event
- [x] **Workflow commands × 10** (OpenBidding, CloseBidding, PauseItem, ResumeItem, LowerReserve, AwardItem, ReAuctionItem, RecordPayment, SendInvoice [SERVICE_PLACEHOLDER], PlaceBid)
- [x] Summary query (GetAuctionSummary — 4 KPIs)
- [x] Bid feed query (GetBidActivityByEvent — last N bids across all items, real-time feed)
- [x] Winners query (GetAuctionWinnersByEvent — items with WinnerContactId set)
- [x] File upload command — UploadItemPhoto (SERVICE_PLACEHOLDER)
- [x] Custom business rule validators — state transition guards, Amount vs reserve, max photos=6

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) — Variant B (because widgets above)
- [x] ScreenHeader with Event selector dropdown in the right-slot + Back button + 3 action buttons (Add Item, Open Bidding, Close Bidding)
- [x] 4 KPI widget cards via GetAuctionSummary
- [x] **Inline collapsible Add/Edit form** (NOT view-page) — RHF
- [x] **4 modals**: Edit Item, View Bids (bid history), Lower Reserve (single-field), Award Item (winner picker)
- [x] Zustand store (`auctionmanagement-store.ts`) — tracks: selectedEventId, isAddFormOpen, editingItemId, viewingBidsItemId, loweringReserveItemId, awardingItemId, collectingPaymentItemId
- [x] **Bid Activity Feed component** — polls (30 s interval; SERVICE_PLACEHOLDER for websocket)
- [x] **Winners & Payment table** — separate table component below grid
- [x] Photos upload widget (mocked handler)
- [x] Summary cards / count widgets above grid (4 widgets → Layout Variant = `widgets-above-grid+side-panel` → Variant B MANDATORY)
- [x] Grid aggregation columns — `CurrentHighBid`, `BidsCount` (cached on AuctionItem; no per-row subquery needed)

**Layout Variant (§⑥ stamp)**: `widgets-above-grid+side-panel` (4 KPIs above grid + Bid Activity + Winners panels below grid → NOT `grid-only` → Variant B mandatory).

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer. Extracted directly from HTML mockup.

**Layout Variant**: `widgets-above-grid+side-panel` → **Variant B mandatory** (`ScreenHeader` + KPI widgets + `DataTableContainer showHeader={false}`).

### Page Header (Variant B ScreenHeader)

**Left slot** (under ScreenHeader title area):
- Back button → navigates to `/[lang]/crm/event/event` (event list)
- Breadcrumb: `Events › Auction Management`
- Title: **"Auction Management"**
- Subtitle: "Manage auction items, bids, and winners"
- **Event selector dropdown** — shows current event name (composed: `{eventCategory.dataName} · {startDate}`); clicking opens event-picker popover listing all Events for this Company (loads via `EVENTS_QUERY`); selected `eventId` is stored in URL (`?eventId=123`) and Zustand.
- **Bidding status badge** (animated pulse for Open): `NotStarted` = grey "Not Started", `Open` = green "Bidding Open" with pulse-dot, `Closed` = red "Bidding Closed"

**Right slot** (header actions — 3 buttons):
- **Add Item** (primary, accent color) → toggles inline Add form visibility
- **Open Bidding** (outline accent, disabled when status=Open) → calls OpenBidding mutation with confirm dialog
- **Close Bidding** (outline danger, disabled when status≠Open) → calls CloseBidding mutation with confirm dialog + "This will resolve winners automatically" message

### Page Widgets & Summary Cards (4 KPIs — above grid)

**Widgets**: 4 cards in responsive grid (auto-fit, minmax(200px, 1fr)).

| # | Widget Title | Value Source | Display Type | Subtitle |
|---|-------------|-------------|-------------|----------|
| 1 | Total Items | `summary.totalItems` | number | "Live: {liveCount} · Silent: {silentCount}" |
| 2 | Total Bids | `summary.totalBids` | number | "Unique bidders: {uniqueBidders}" |
| 3 | Current High Bids Total | `summary.currentHighBidsTotal` | currency (accent) | "Across all active items" |
| 4 | Bidding Status | `summary.biddingStatusLabel` (emoji + label) | text | `Open` → "Closes in {timeRemaining}"; `Closed` → "Closed {relativeTime} ago"; `NotStarted` → "Not yet opened" |

**Summary GQL query**: `GetAuctionSummary(eventAuctionId: Int!)` returns `AuctionSummaryDto { totalItems, liveItemsCount, silentItemsCount, totalBids, uniqueBidders, currentHighBidsTotal, biddingStatusCode, biddingStatusLabel, biddingClosesAt, biddingClosedAt }`.

### Grid/List View

**Display Mode**: `table`

**Grid Columns** (Auction Items grid, 10 columns):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | # | sortOrder | number | 48px | YES | Running index / display order |
| 2 | Item | itemName | text-bold | auto | YES | — |
| 3 | Category | category.dataName | badge-with-icon | 140px | YES | New renderer: `auction-category-badge` (icon from MasterData.DataSetting.icon; color from MasterData.DataSetting.color) |
| 4 | Donor / Sponsor | donorName \|\| donorContact.displayName | text | 160px | NO | If donorContactId set → link to `/[lang]/crm/contact/contact?mode=read&id={id}`; else plain text |
| 5 | Starting Bid | startingBid | currency | 110px | YES | — |
| 6 | Current Bid | currentHighBid | currency-bold | 120px | YES | Bold, right-aligned |
| 7 | Bids | bidsCount | number-with-action | 70px | YES | Click → opens Bid History modal (NEW renderer: `bids-count-link`) |
| 8 | Reserve | reservePrice + reserveMet | reserve-status | 110px | NO | NEW renderer: `reserve-status-cell` — shows "$X ✓" green if currentHighBid ≥ reserve, "$X ✗" red otherwise, "—" if null |
| 9 | Status | status.dataName | status-badge | 130px | YES | Colors from MasterData.DataSetting.ColorHex (Active=green/BelowReserve=amber/Paused=grey/Closed=slate/Won=purple/NoWinner=red) |
| 10 | Actions | — | row-actions | 140px | NO | **View Bids** (primary action-btn — same as bidsCount click) + **Kebab menu** (Edit / Pause or Resume / Lower Reserve / Remove) |

**Search/Filter Fields** (mockup header-search):
- Search input: filters by itemName + description (server-side ILIKE)
- Category dropdown: filters by categoryId (pulls from MasterData AUCTIONITEMCATEGORY)
- Status dropdown: filters by statusId (pulls from MasterData AUCTIONITEMSTATUS)
- **Implicit filter**: eventId (from event-selector, always scoped)

**Grid Actions** (row kebab):
- **Edit** → opens Edit Item modal
- **Pause** (when status=Active or BelowReserve) → PauseItem mutation
- **Resume** (when status=Paused) → ResumeItem mutation
- **Lower Reserve** (when status=BelowReserve) → Lower Reserve modal (single decimal input)
- **Remove** (Delete) → confirm dialog → DeleteAuctionItem mutation (soft delete, cascades to bids)

**Row Click**: default = no action (grid clicks don't navigate — this is a console page). The "Bids" cell and the explicit "View Bids" button are the interaction affordances.

---

### LAYOUT 1: INLINE ADD/EDIT FORM (collapsible card below grid)

> This is the mockup's "Add New Auction Item" collapsible dash-card. Toggled by the "+Add Item" header button. Serves both Create (empty) and Edit (pre-filled via modal OR inline prefill when editingItemId set).

**Render container**: `<dash-card>` directly under Auction Items grid, collapsible via state `isAddFormOpen`. Uses React Hook Form.

**Section layout**: 2-column grid (`grid-template-columns: 1fr 1fr`); full-width fields span both.

**Fields** (10 total, in display order from mockup):

| Field | RHF Path | Widget | Grid Span | Placeholder | Validation | Notes |
|-------|----------|--------|-----------|-------------|------------|-------|
| Item Name | `itemName` | text | col-1 | "e.g., Weekend at Atlantis" | required, maxLen 200 | — |
| Category | `categoryId` | ApiSelectV2 | col-1 | "Select category..." | optional | Query: masterDataByType(type=AUCTIONITEMCATEGORY) |
| Description | `description` | textarea (min-h 80px) | full-width | "Detailed description of the auction item..." | required, maxLen 2000 | — |
| Donated By | `donorName` | text | col-1 | "Donor or sponsor name" | optional, maxLen 200 | free text |
| Estimated Value | `estimatedValue` | currency | col-1 | "$0.00" | optional, ≥0 | — |
| Starting Bid | `startingBid` | currency | col-1 | "$0.00" | required, >0 | — |
| Bid Increment | `bidIncrement` | currency | col-1 | "$100" (default `100`) | required, >0 | — |
| Reserve Price | `reservePrice` | currency | col-1 | "$0.00" | optional, ≥ startingBid if set | Label suffix "(optional)" |
| Auction Type | `auctionTypeId` | ApiSelectV2 | col-1 | — | required | Query: masterDataByType(type=AUCTIONTYPE) — 2 options Silent/Live |
| Photos | `photos[]` | photo-gallery-uploader | full-width | "Click to upload or drag photos here\nJPG, PNG up to 5MB each · Max 6 photos" | max 6 files | SERVICE_PLACEHOLDER — mocked click handler, toast "Upload handler pending file-storage infra"; render stub thumbnails |

**Form footer** (actions):
- **Save Item** (primary accent) → submits → on success collapse form + reset + grid refresh + success toast
- **Cancel** (outline accent) → collapse form + reset

**Form header collapse toggle**: clicking the card header toggles the body visibility (chevron rotates). Also the "+Add Item" header button toggles + scrolls form into view.

**Edit mode**: when user clicks row "Edit" action → open `EditAuctionItemModal` (separate Dialog component). The inline form is Create-only; Edit uses modal to avoid ambiguous state.

---

### LAYOUT 2: DETAIL — N/A

> **No separate detail URL mode.** The mockup does not have a `?mode=read` detail page. All read-only info is shown in:
> - Grid row (summary data)
> - **Bid History modal** (bid-history-modal, triggered by "View Bids" button or clicking the Bids count cell)
> - **Winners & Payment table** (bottom half of the console, NOT a separate page)
>
> Status documented: "No separate detail layout — this is a console page. Row interactions use modals, not URL modes."

---

### Lower Side Panels (Two-column layout below the grid)

#### Panel A — Bid Activity Feed (left, col-lg-5)

Card header: `● Bid Activity — Real-time` + `Live` indicator (green pulse).

Body: scrollable feed (`max-height: 340px; overflow-y: auto`), each item = `bid-feed-item`:
- **Time** (left, small grey) — e.g. "2:30 PM"
- **Text** (right): `{bidderContactName}` (link to contact detail) + " bid " + `$amount` (bold) + " on " + `{itemName}` (purple)

**Data source**: `GetBidActivityByEvent(eventAuctionId, limit=20)` → returns `[AuctionBidResponseDto]` ordered by `BidDate DESC`.
**Refresh strategy**: poll every 30 s (SERVICE_PLACEHOLDER for websocket / SSE — FE note: `// TODO: replace polling with SignalR when infra available`).

#### Panel B — Winners & Payment Table (right, col-lg-7)

Card header: `🏆 Winners & Payment` + subtitle "Post-bidding settlement".

Columns (6):
| # | Column | Field | Notes |
|---|--------|-------|-------|
| 1 | Item | itemName | bold |
| 2 | Winner | winnerContact.displayName | contact link OR "—" (for NoWinner items) |
| 3 | Winning Bid | winningBidAmount | bold; "$X (below reserve)" small grey for NoWinner |
| 4 | Payment | paymentMethodText | icon + text (credit-card icon for `•••XXXX`, money-bill for "Cash"); "Pending" amber for Awaiting; "—" for NoWinner |
| 5 | Status | paymentStatus.dataName | renderer: `payment-status-badge` — Paid=green/Awaiting=amber/NoWinner=red |
| 6 | Actions | — | Conditional by status: `Paid` → **Receipt** (SERVICE_PLACEHOLDER toast); `Awaiting` → **Send Invoice** (PLACEHOLDER) + **Collect** (RecordPayment modal); `NoWinner` → **Override** (AwardItem modal for admin-pick winner below reserve) + **Re-auction** (confirm dialog → ReAuctionItem) |

**Data source**: `GetAuctionWinnersByEvent(eventAuctionId)` → returns all AuctionItems with `statusId IN (Won, NoWinner)` OR `paymentStatusId IS NOT NULL`.

---

### Modals (4 total)

| Modal | Trigger | Fields | Action |
|-------|---------|--------|--------|
| **EditAuctionItemModal** | Row kebab → Edit | Same 10 fields as inline form | UpdateAuctionItem mutation |
| **BidHistoryModal** | "View Bids" button OR Bids count cell click | Read-only table: Time, Bidder (link), Amount (bold), IsCurrentHighest (crown icon), IsValid | Displays `GetBidsByAuctionItem(auctionItemId)` results; footer "+ Place Bid" button opens sub-modal `PlaceBidModal` (BidderContactId via ApiSelectV2 contacts + Amount + Note) → calls PlaceBid mutation |
| **LowerReserveModal** | Row kebab → Lower Reserve (BelowReserve status only) | Current reserve (readonly) + New Reserve (currency, required, ≥ startingBid, < current reserve) | LowerReserve mutation |
| **AwardItemModal** | Winners table → Override (NoWinner items) | Winner Contact (ApiSelectV2 contacts filtered by those who bid on this item) + Winning Bid Amount (currency, required) | AwardItem mutation |
| **CollectPaymentModal** | Winners table → Collect | Payment Method Text (text) + Collected Date (datepicker, default today) | RecordPayment mutation |

### Grid Aggregation Columns

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Current Bid | max Amount across AuctionBid.AuctionItemId = row.AuctionItemId where IsValid=true | Cached as `AuctionItem.CurrentHighBid` | Update via PlaceBid command; no runtime subquery |
| Bids | count AuctionBid where AuctionItemId = row.AuctionItemId and IsValid=true | Cached as `AuctionItem.BidsCount` | Update via PlaceBid / ReAuctionItem commands |

### User Interaction Flow (Console — no URL modes)

1. User navigates to `/[lang]/crm/event/auctionmanagement`. If `?eventId` URL param is missing, display event picker (first event auto-selected if only one has an active auction).
2. Event selected → URL updates to `?eventId=123` → page loads:
   - GetAuctionSummary → 4 KPIs
   - GetAllAuctionItemsByEvent → grid
   - GetBidActivityByEvent → bid feed
   - GetAuctionWinnersByEvent → winners table
   - GetEventAuctionByEvent → bidding status badge
3. User clicks **+Add Item** → inline form expands below grid. Fill + Save → new AuctionItem created → grid refreshes → form collapses.
4. User clicks row kebab → Edit → modal opens pre-filled → Save → close + grid refresh.
5. User clicks **Open Bidding** → confirm → OpenBidding mutation → badge turns green, all items that were Paused stay Paused; rest become Active.
6. User clicks **View Bids** on a row → BidHistoryModal opens with full bid list + Place Bid footer.
7. Bid feed polls every 30 s → new bids appear at top.
8. User clicks **Close Bidding** → confirm "Winners will be resolved automatically" → CloseBidding mutation → badge red, items resolved into Won/NoWinner, Winners table refreshes.
9. User works Winners table: Collect (modal → RecordPayment) / Override (AwardItem modal) / Receipt / Re-auction.
10. Event selector dropdown switch → URL `?eventId` updates → all 5 queries re-fire.
11. Back button → navigates to `/[lang]/crm/event/event`.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer. Maps canonical reference → this entity.

**Canonical Reference**: **DonationInKind #7** (FLOW with side-panel console variation — recent completed precedent) + **MatchingGift #11** (multi-entity under one menu pattern — for AuctionItem/AuctionBid/EventAuction under AUCTIONMANAGEMENT).

### Primary entity (AuctionItem)

| Canonical (SavedFilter / DonationInKind) | → This Entity | Context |
|-----------|--------------|---------|
| DonationInKind | **AuctionItem** | Entity/class name |
| donationInKind | **auctionItem** | Variable/field names |
| DonationInKindId | **AuctionItemId** | PK field |
| DonationInKinds | **AuctionItems** | Table/collection name |
| donation-in-kind | **auction-item** (not used in routes) | kebab-case |
| donationinkind | **auctionmanagement** (route/folder — menu-code-based, NOT entity-code-based) | FE folder / route path |
| DONATIONINKIND | **AUCTIONMANAGEMENT** (menu code) / **AUCTIONITEM** (grid code) | UPPER codes |
| fund | **app** | DB schema |
| DonationModels | **ApplicationModels** | Backend Domain group |
| Donation | **Application** | Backend Business/Endpoints group |
| CRM_DONATION | **CRM_EVENT** | Parent menu code |
| CRM | **CRM** | Module code |
| crm/donation/donationinkind | **crm/event/auctionmanagement** | FE route path |
| donation-service | **contact-service** (preserve — AuctionItem DTOs live under contact-service per #40 Event precedent) | FE service folder |

### Secondary entities

| Entity | Group | Table | Grid | Schema file |
|--------|-------|-------|------|-------------|
| EventAuction | ApplicationModels | app."EventAuctions" | — (no grid) | EventAuctionSchemas.cs |
| AuctionBid | ApplicationModels | app."AuctionBids" | — (queried by item, no standalone grid) | AuctionBidSchemas.cs |
| AuctionItemPhoto | ApplicationModels | app."AuctionItemPhotos" | — | AuctionItemPhotoSchemas.cs |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer.

### Backend Files — Create (~34 files)

#### AuctionItem (11 standard + workflow commands)
| # | File | Path |
|---|------|------|
| 1 | Entity | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ApplicationModels/AuctionItem.cs` |
| 2 | EF Config | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/ApplicationConfigurations/AuctionItemConfiguration.cs` |
| 3 | Schemas (DTOs + Summary + inputs) | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/ApplicationSchemas/AuctionItemSchemas.cs` |
| 4 | CreateAuctionItem | `.../Business/ApplicationBusiness/AuctionItems/CreateCommand/CreateAuctionItem.cs` |
| 5 | UpdateAuctionItem | `.../AuctionItems/UpdateCommand/UpdateAuctionItem.cs` |
| 6 | DeleteAuctionItem | `.../AuctionItems/DeleteCommand/DeleteAuctionItem.cs` |
| 7 | ToggleAuctionItem | `.../AuctionItems/ToggleCommand/ToggleAuctionItem.cs` |
| 8 | PauseAuctionItem (workflow) | `.../AuctionItems/PauseCommand/PauseAuctionItem.cs` |
| 9 | ResumeAuctionItem (workflow) | `.../AuctionItems/ResumeCommand/ResumeAuctionItem.cs` |
| 10 | LowerReserveAuctionItem | `.../AuctionItems/LowerReserveCommand/LowerReserveAuctionItem.cs` |
| 11 | AwardAuctionItem | `.../AuctionItems/AwardCommand/AwardAuctionItem.cs` |
| 12 | ReAuctionAuctionItem | `.../AuctionItems/ReAuctionCommand/ReAuctionAuctionItem.cs` |
| 13 | RecordPaymentAuctionItem | `.../AuctionItems/RecordPaymentCommand/RecordPaymentAuctionItem.cs` |
| 14 | SendInvoiceAuctionItem (SERVICE_PLACEHOLDER) | `.../AuctionItems/SendInvoiceCommand/SendInvoiceAuctionItem.cs` |
| 15 | ReorderAuctionItems | `.../AuctionItems/ReorderCommand/ReorderAuctionItems.cs` |
| 16 | GetAllAuctionItems (by event) | `.../AuctionItems/GetAllQuery/GetAllAuctionItems.cs` |
| 17 | GetAuctionItemById | `.../AuctionItems/GetByIdQuery/GetAuctionItemById.cs` |
| 18 | GetAuctionSummary | `.../AuctionItems/GetSummaryQuery/GetAuctionSummary.cs` |
| 19 | GetAuctionWinnersByEvent | `.../AuctionItems/GetWinnersQuery/GetAuctionWinnersByEvent.cs` |
| 20 | Mutations endpoint | `PSS_2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Application/Mutations/AuctionItemMutations.cs` |
| 21 | Queries endpoint | `PSS_2.0_Backend/.../EndPoints/Application/Queries/AuctionItemQueries.cs` |

#### EventAuction (parent config)
| # | File | Path |
|---|------|------|
| 22 | Entity | `.../Base.Domain/Models/ApplicationModels/EventAuction.cs` |
| 23 | EF Config | `.../Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventAuctionConfiguration.cs` |
| 24 | Schemas | `.../Base.Application/Schemas/ApplicationSchemas/EventAuctionSchemas.cs` |
| 25 | UpsertEventAuction (create-or-update — 1:1 with Event) | `.../Business/ApplicationBusiness/EventAuctions/UpsertCommand/UpsertEventAuction.cs` |
| 26 | OpenBidding | `.../EventAuctions/OpenBiddingCommand/OpenBidding.cs` |
| 27 | CloseBidding (resolves winners) | `.../EventAuctions/CloseBiddingCommand/CloseBidding.cs` |
| 28 | ReOpenBidding | `.../EventAuctions/ReOpenBiddingCommand/ReOpenBidding.cs` |
| 29 | GetEventAuctionByEvent | `.../EventAuctions/GetByEventQuery/GetEventAuctionByEvent.cs` |
| 30 | Mutations endpoint | `.../EndPoints/Application/Mutations/EventAuctionMutations.cs` |
| 31 | Queries endpoint | `.../EndPoints/Application/Queries/EventAuctionQueries.cs` |

#### AuctionBid (child)
| # | File | Path |
|---|------|------|
| 32 | Entity | `.../Base.Domain/Models/ApplicationModels/AuctionBid.cs` |
| 33 | EF Config | `.../ApplicationConfigurations/AuctionBidConfiguration.cs` |
| 34 | Schemas | `.../Base.Application/Schemas/ApplicationSchemas/AuctionBidSchemas.cs` |
| 35 | PlaceBid (Create) | `.../Business/ApplicationBusiness/AuctionBids/PlaceBidCommand/PlaceBid.cs` |
| 36 | RetractBid (soft flag IsValid=false) | `.../AuctionBids/RetractCommand/RetractBid.cs` |
| 37 | GetBidsByAuctionItem | `.../AuctionBids/GetByItemQuery/GetBidsByAuctionItem.cs` |
| 38 | GetBidActivityByEvent | `.../AuctionBids/GetActivityByEventQuery/GetBidActivityByEvent.cs` |
| 39 | Mutations endpoint | `.../EndPoints/Application/Mutations/AuctionBidMutations.cs` |
| 40 | Queries endpoint | `.../EndPoints/Application/Queries/AuctionBidQueries.cs` |

#### AuctionItemPhoto (child)
| # | File | Path |
|---|------|------|
| 41 | Entity | `.../ApplicationModels/AuctionItemPhoto.cs` |
| 42 | EF Config | `.../ApplicationConfigurations/AuctionItemPhotoConfiguration.cs` |
| 43 | Schemas | `.../ApplicationSchemas/AuctionItemPhotoSchemas.cs` |
| 44 | UploadAuctionItemPhoto (SERVICE_PLACEHOLDER) | `.../Business/ApplicationBusiness/AuctionItemPhotos/UploadCommand/UploadAuctionItemPhoto.cs` |
| 45 | DeleteAuctionItemPhoto | `.../AuctionItemPhotos/DeleteCommand/DeleteAuctionItemPhoto.cs` |
| 46 | GetPhotosByAuctionItem | `.../AuctionItemPhotos/GetByItemQuery/GetPhotosByAuctionItem.cs` |
| 47 | Endpoints (combined into AuctionItemMutations/Queries) | — reuse files #20/#21 |

#### Migration + MasterData seed
| # | File | Path |
|---|------|------|
| 48 | EF Migration | `PSS_2.0_Backend/.../Base.Infrastructure/Migrations/{timestamp}_AuctionManagement_Initial.cs` |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Base.Application/Common/Interfaces/IApplicationDbContext.cs` | 4 new `DbSet<>`: EventAuctions, AuctionItems, AuctionBids, AuctionItemPhotos |
| 2 | `Base.Infrastructure/Data/ApplicationDbContext.cs` | Same 4 DbSets + `OnModelCreating` auto-picks configurations (or add explicit ApplyConfig lines) |
| 3 | `Base.Application/Common/DecoratorProperties.cs` | `DecoratorApplicationModules.AuctionItem`, `.AuctionBid`, `.EventAuction`, `.AuctionItemPhoto` constants + add to `AUCTIONMANAGEMENT` menu code map |
| 4 | `Base.Application/Mapper/ApplicationMappings.cs` (or create if not exists — note: Event uses `ContactMappings.cs` per OrgUnit precedent; preserve) | Mapster config for AuctionItem / AuctionBid / EventAuction / AuctionItemPhoto |
| 5 | `Base.API/Program.cs` or GraphQL schema registration | Register 4 new Mutations + 4 new Queries types under `Application` endpoint group |
| 6 | `Base.Application/Business/ApplicationBusiness/Events/GetByIdQuery/GetEventById.cs` | Optionally project `EventAuction` navigation so Event detail knows if it has an auction (for #40 detail-page "Auction" section link) |

### Frontend Files — Create (~22 files)

| # | File | Path |
|---|------|------|
| 1 | DTO: AuctionItem | `PSS_2.0_Frontend/src/domain/entities/contact-service/AuctionItemDto.ts` |
| 2 | DTO: EventAuction | `.../contact-service/EventAuctionDto.ts` |
| 3 | DTO: AuctionBid | `.../contact-service/AuctionBidDto.ts` |
| 4 | DTO: AuctionSummary | `.../contact-service/AuctionSummaryDto.ts` |
| 5 | GQL Query: Items+Summary+Winners | `PSS_2.0_Frontend/src/infrastructure/gql-queries/contact-queries/AuctionItemQuery.ts` |
| 6 | GQL Query: Bids feed + history | `.../contact-queries/AuctionBidQuery.ts` |
| 7 | GQL Query: EventAuction | `.../contact-queries/EventAuctionQuery.ts` |
| 8 | GQL Mutation: AuctionItem (includes workflow mutations) | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/contact-mutations/AuctionItemMutation.ts` |
| 9 | GQL Mutation: AuctionBid | `.../contact-mutations/AuctionBidMutation.ts` |
| 10 | GQL Mutation: EventAuction (Open/Close/ReOpen) | `.../contact-mutations/EventAuctionMutation.ts` |
| 11 | Page Config | `PSS_2.0_Frontend/src/presentation/pages/crm/event/auctionmanagement.tsx` |
| 12 | Index (container) | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/event/auctionmanagement/index.tsx` |
| 13 | Index Page (console) | `.../auctionmanagement/index-page.tsx` |
| 14 | Auction Items Grid section | `.../auctionmanagement/auction-items-grid.tsx` |
| 15 | Inline Add Form | `.../auctionmanagement/auction-item-add-form.tsx` |
| 16 | Edit Item Modal | `.../auctionmanagement/auction-item-edit-modal.tsx` |
| 17 | Bid History Modal | `.../auctionmanagement/bid-history-modal.tsx` |
| 18 | Place Bid Modal (nested in BidHistory) | `.../auctionmanagement/place-bid-modal.tsx` |
| 19 | Lower Reserve Modal | `.../auctionmanagement/lower-reserve-modal.tsx` |
| 20 | Award Item Modal | `.../auctionmanagement/award-item-modal.tsx` |
| 21 | Collect Payment Modal | `.../auctionmanagement/collect-payment-modal.tsx` |
| 22 | Event Selector (header popover) | `.../auctionmanagement/event-selector.tsx` |
| 23 | KPI Widgets (4 cards) | `.../auctionmanagement/auction-widgets.tsx` |
| 24 | Bid Activity Feed (poller) | `.../auctionmanagement/bid-activity-feed.tsx` |
| 25 | Winners & Payment Table | `.../auctionmanagement/winners-payment-table.tsx` |
| 26 | Photos Uploader (stub) | `.../auctionmanagement/photos-uploader.tsx` |
| 27 | Zustand Store | `.../auctionmanagement/auctionmanagement-store.ts` |
| 28 | Form schemas (zod) | `.../auctionmanagement/auction-item-schemas.ts` |
| 29 | Route page (OVERWRITE existing stub) | `PSS_2.0_Frontend/src/app/[lang]/crm/event/auctionmanagement/page.tsx` |

### Frontend Cell Renderers — Create 4 new + register

| # | Renderer | Registers in |
|---|---------|-------------|
| 1 | `auction-category-badge` — icon + colored pill | `advanced-column-types.ts`, `basic-column-types.ts`, `flow-column-types.ts`, `shared-cell-renderers/index.ts` |
| 2 | `reserve-status-cell` — "$X ✓ green" / "$X ✗ red" / "—" | same 4 files |
| 3 | `bids-count-link` — clickable count opens BidHistoryModal via store | same 4 files |
| 4 | `payment-status-badge` — Paid/Awaiting/NoWinner with ColorHex | same 4 files |

(Note: reuse existing `status-badge` for item status; add ColorHex mapping via MasterData seed.)

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `domain/services/contact-service/entity-operations.ts` | `AUCTIONITEM` operations config (query/mutation refs for CRUD) + `AUCTIONMANAGEMENT` page-level ops |
| 2 | `domain/services/contact-service/operations-config.ts` | Import + register AUCTIONITEM operations |
| 3 | `infrastructure/gql-mutations/contact-mutations/index.ts` (or equivalent barrel) | Export 3 new mutation files |
| 4 | `infrastructure/gql-queries/contact-queries/index.ts` (barrel) | Export 3 new query files |
| 5 | `presentation/components/shared-cell-renderers/index.ts` | Export 4 new renderers |
| 6 | `presentation/components/page-components/crm/event/index.ts` | Re-export auctionmanagement index |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: Auction Management
MenuCode: AUCTIONMANAGEMENT
ParentMenu: CRM_EVENT
Module: CRM
MenuUrl: crm/event/auctionmanagement
GridType: FLOW
OrderBy: 3

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: AUCTIONITEM

# Hidden child menus (for governance of sub-entities accessed only through the console page):
HiddenChildMenus:
  - MenuName: Auction Bids
    MenuCode: AUCTIONBID
    ParentMenu: AUCTIONMANAGEMENT
    Module: CRM
    MenuUrl: (none — hidden, accessed only via BidHistoryModal)
    GridType: NONE
    IsMenuRender: false
  - MenuName: Event Auction Config
    MenuCode: EVENTAUCTION
    ParentMenu: AUCTIONMANAGEMENT
    Module: CRM
    MenuUrl: (none — hidden, governed by AuctionManagement page)
    GridType: NONE
    IsMenuRender: false
---CONFIG-END---
```

### Master Data Seeds (REQUIRED — 5 new MasterDataType codes)

```sql
-- AUCTIONITEMCATEGORY (8 rows — icons + colors in DataSetting JSON)
INSERT INTO shared.MasterDataType (MasterDataTypeCode, MasterDataTypeName, CompanyId) VALUES ('AUCTIONITEMCATEGORY', 'Auction Item Category', {CompanyId});
-- 8 rows: TRAVEL (fa-plane / #3b82f6), DINING (fa-utensils / #f59e0b),
--        ART (fa-palette / #ec4899), SPORTS (fa-baseball-bat-ball / #10b981),
--        FASHION (fa-gem / #8b5cf6), EXPERIENCE (fa-spa / #06b6d4),
--        TECH (fa-laptop / #64748b), OTHER (fa-tag / #94a3b8)

-- AUCTIONITEMSTATUS (6 rows — ColorHex in DataSetting)
INSERT INTO shared.MasterDataType VALUES ('AUCTIONITEMSTATUS', 'Auction Item Status', ...);
-- Active=#22c55e, BelowReserve=#f59e0b, Paused=#64748b,
-- Closed=#1e293b, Won=#7c3aed, NoWinner=#dc2626

-- AUCTIONPAYMENTSTATUS (3 rows)
-- Awaiting=#f59e0b, Paid=#22c55e, NoPayment=#94a3b8

-- AUCTIONBIDDINGSTATUS (3 rows)
-- NotStarted=#64748b, Open=#22c55e, Closed=#dc2626

-- AUCTIONTYPE (2 rows)
-- Silent, Live
```

**Decorator decoration**: add decorator entries in `DecoratorProperties.cs`:
```csharp
public static class DecoratorApplicationModules
{
    public const string AuctionItem = "AuctionItem";
    public const string AuctionBid = "AuctionBid";
    public const string EventAuction = "EventAuction";
    public const string AuctionItemPhoto = "AuctionItemPhoto";
}
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer.

### GraphQL Types

- Mutations: `AuctionItemMutations`, `AuctionBidMutations`, `EventAuctionMutations`, `AuctionItemPhotoMutations` (merged into `AuctionItemMutations`)
- Queries: `AuctionItemQueries`, `AuctionBidQueries`, `EventAuctionQueries`

### Queries

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `auctionItemsByEvent` | `[AuctionItemResponseDto]` (paged) | eventAuctionId, searchText, categoryId?, statusId?, pageNo, pageSize, sortField, sortDir |
| `auctionItemById` | `AuctionItemResponseDto` | auctionItemId |
| `auctionSummaryByEvent` | `AuctionSummaryDto` | eventAuctionId |
| `auctionWinnersByEvent` | `[AuctionWinnerRowDto]` | eventAuctionId |
| `bidsByAuctionItem` | `[AuctionBidResponseDto]` | auctionItemId |
| `bidActivityByEvent` | `[AuctionBidFeedDto]` | eventAuctionId, limit (default 20) |
| `eventAuctionByEvent` | `EventAuctionResponseDto?` | eventId |
| `photosByAuctionItem` | `[AuctionItemPhotoResponseDto]` | auctionItemId |

### Mutations

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createAuctionItem` | `AuctionItemRequestDto` (with optional `photos: [AuctionItemPhotoRequestDto]`) | int |
| `updateAuctionItem` | `AuctionItemRequestDto` | int |
| `deleteAuctionItem` | `auctionItemId: Int!` | int |
| `toggleAuctionItem` | `auctionItemId: Int!` | int |
| `pauseAuctionItem` | `auctionItemId: Int!` | int |
| `resumeAuctionItem` | `auctionItemId: Int!` | int |
| `lowerReserveAuctionItem` | `auctionItemId: Int!, newReservePrice: Decimal!` | int |
| `awardAuctionItem` | `auctionItemId: Int!, winnerContactId: Int!, winningBidAmount: Decimal!` | int |
| `reAuctionAuctionItem` | `auctionItemId: Int!` | int |
| `recordPaymentAuctionItem` | `auctionItemId: Int!, paymentMethodText: String!, collectedDate: DateTime?` | int |
| `sendInvoiceAuctionItem` | `auctionItemId: Int!` | int (SERVICE_PLACEHOLDER — returns success toast only) |
| `reorderAuctionItems` | `eventAuctionId: Int!, orderedItemIds: [Int!]!` | int |
| `placeBid` | `AuctionBidRequestDto` | int |
| `retractBid` | `auctionBidId: Int!` | int |
| `upsertEventAuction` | `EventAuctionRequestDto` | int |
| `openBidding` | `eventAuctionId: Int!` | int |
| `closeBidding` | `eventAuctionId: Int!` | int (resolves winners server-side) |
| `reOpenBidding` | `eventAuctionId: Int!` | int |
| `uploadAuctionItemPhoto` | `auctionItemId: Int!, photoUrl: String!` | int (PLACEHOLDER) |
| `deleteAuctionItemPhoto` | `auctionItemPhotoId: Int!` | int |

### Response DTO fields (what FE receives)

**AuctionItemResponseDto**:
```ts
{
  auctionItemId: number;
  eventId: number;
  eventAuctionId: number;
  itemName: string;
  description: string;
  categoryId: number | null;
  category: { dataName: string; dataSetting: { icon: string; color: string } } | null;
  auctionTypeId: number;
  auctionType: { dataName: string; dataCode: "Silent" | "Live" };
  donorName: string | null;
  donorContactId: number | null;
  donorContact: { displayName: string } | null;
  estimatedValue: number | null;
  startingBid: number;
  bidIncrement: number;
  reservePrice: number | null;
  currentHighBid: number | null;
  bidsCount: number;
  statusId: number;
  status: { dataName: string; dataCode: string; dataSetting: { colorHex: string } };
  winnerContactId: number | null;
  winnerContact: { displayName: string; contactId: number } | null;
  winningBidAmount: number | null;
  paymentStatusId: number | null;
  paymentStatus: { dataName: string; dataSetting: { colorHex: string } } | null;
  paymentMethodText: string | null;
  paymentCollectedDate: string | null;
  currencyId: number;
  currency: { currencyCode: string; currencySymbol: string };
  sortOrder: number;
  photos: [AuctionItemPhotoResponseDto];
  reserveMet: boolean; // computed: currentHighBid >= reservePrice
  isActive: boolean;
  createdDate: string;
  modifiedDate: string;
}
```

**AuctionSummaryDto**:
```ts
{
  totalItems: number;
  liveItemsCount: number;
  silentItemsCount: number;
  totalBids: number;
  uniqueBidders: number;
  currentHighBidsTotal: number;
  biddingStatusCode: "NotStarted" | "Open" | "Closed";
  biddingStatusLabel: string;
  biddingClosesAt: string | null;
  biddingClosedAt: string | null;
  pausedItemsCount: number;
  wonItemsCount: number;
  noWinnerItemsCount: number;
}
```

**AuctionBidFeedDto** (for live feed):
```ts
{
  auctionBidId: number;
  auctionItemId: number;
  itemName: string;
  bidderContactId: number;
  bidderName: string;
  amount: number;
  bidDate: string; // ISO
  bidTimeDisplay: string; // "2:30 PM" — server-formatted or FE-formatted
}
```

**EventAuctionResponseDto**:
```ts
{
  eventAuctionId: number;
  eventId: number;
  event: { eventId: number; eventTitle: string; startDate: string };
  biddingStatusId: number;
  biddingStatus: { dataName: string; dataCode: string };
  biddingOpensAt: string | null;
  biddingClosesAt: string | null;
  actualOpenedAt: string | null;
  actualClosedAt: string | null;
  auctionNotes: string | null;
}
```

**AuctionWinnerRowDto**:
```ts
{
  auctionItemId: number;
  itemName: string;
  winnerContactId: number | null;
  winnerName: string | null;
  winningBidAmount: number | null;
  paymentMethodText: string | null;
  paymentStatusCode: string | null;
  paymentStatusLabel: string | null;
  statusCode: string; // Won / NoWinner
  reserveMet: boolean;
  reservePrice: number | null;
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors; migration `AuctionManagement_Initial` applies cleanly
- [ ] `pnpm tsc --noEmit` — no AuctionManagement errors
- [ ] `pnpm dev` — page loads at `/[lang]/crm/event/auctionmanagement`

**Functional Verification (Full E2E — MANDATORY):**

**Page load & event selection:**
- [ ] Without `?eventId` param, event picker renders with events list; selecting one sets URL `?eventId=X`
- [ ] With valid `?eventId`, page loads 5 data sections (items grid, 4 KPIs, bid feed, winners table, bidding status badge)
- [ ] Event selector dropdown in header allows switching between events; all 5 queries re-fire on switch
- [ ] If event has no EventAuction row, auto-upsert on page open (initialize with BiddingStatusId=NotStarted)

**KPI widgets (4):**
- [ ] Total Items shows correct count with Live/Silent split subtitle
- [ ] Total Bids shows correct count with unique bidders subtitle
- [ ] Current High Bids Total shows sum of `currentHighBid` across active items in accent color
- [ ] Bidding Status shows emoji+label, subtitle shows countdown (Open) or closed-time (Closed)

**Items grid:**
- [ ] 10 columns render correctly (# / Item / Category badge / Donor link-or-text / Starting / Current / Bids count / Reserve cell / Status badge / Actions)
- [ ] Search filters itemName+description server-side
- [ ] Category and Status dropdowns filter correctly
- [ ] Reserve cell shows ✓ green when met, ✗ red when not met, "—" when null
- [ ] Status badge uses ColorHex from MasterData.DataSetting

**Inline Add form:**
- [ ] "+Add Item" button expands form with smooth scroll
- [ ] 10 fields render in 2-column layout (Item Name / Category / Description full-width / Donor / Estimated Value / Starting Bid / Bid Increment / Reserve / Auction Type / Photos full-width)
- [ ] Category and AuctionType dropdowns load via masterDataByType
- [ ] Photos uploader stub renders; clicking shows toast "Upload handler pending infra"
- [ ] Save creates AuctionItem → grid refreshes → form collapses
- [ ] Cancel collapses form + resets RHF state

**Row actions:**
- [ ] Edit row → EditAuctionItemModal opens pre-filled → Save updates + grid refreshes
- [ ] Pause (on Active/BelowReserve) → PauseItem → status changes to Paused
- [ ] Resume (on Paused) → ResumeItem → status back to Active
- [ ] Lower Reserve (on BelowReserve) → modal → LowerReserve → reserve updates, status may flip back to Active
- [ ] Remove → confirm → DeleteAuctionItem → grid removes row
- [ ] Bids count click OR "View Bids" button → BidHistoryModal opens with bid list + Place Bid footer

**Bidding workflow:**
- [ ] Open Bidding button (disabled when status=Open) → confirm → OpenBidding → badge turns green pulse
- [ ] Close Bidding button (disabled when status≠Open) → confirm → CloseBidding → badge turns red, winners resolved server-side (Won for ≥reserve, NoWinner for <reserve), Winners table + KPIs refresh
- [ ] ReOpen Bidding action available via secondary (Close→ReOpen cycle)

**Bid history + place bid:**
- [ ] BidHistoryModal lists bids ordered by BidDate desc with bidder link, amount, highest-crown, valid flag
- [ ] Place Bid footer opens PlaceBidModal → ApiSelectV2 contact picker + amount + note → PlaceBid mutation → list refreshes; CurrentHighBid + BidsCount update on AuctionItem
- [ ] Validation: Amount ≥ (CurrentHighBid ?? StartingBid) + BidIncrement (UNLESS first bid — then ≥ StartingBid)

**Bid Activity Feed:**
- [ ] Feed renders last 20 bids across all items with time, bidder link, amount (bold), item name (purple)
- [ ] Feed polls every 30 s; SERVICE_PLACEHOLDER note visible in code comment
- [ ] "Live" indicator pulses green when bidding is Open

**Winners & Payment table:**
- [ ] Rows list all items with statusId ∈ (Won, NoWinner)
- [ ] Winner name links to contact detail; "—" shown for NoWinner
- [ ] Payment column shows icon+text (credit-card / cash / pending) + badge
- [ ] Paid row: Receipt action → PLACEHOLDER toast
- [ ] Awaiting row: Send Invoice (PLACEHOLDER toast) + Collect (CollectPaymentModal → RecordPayment → status=Paid)
- [ ] NoWinner row: Override (AwardItemModal → AwardItem → status=Won, added to winners) + Re-auction (confirm → ReAuctionItem → invalidates bids, status=Active)

**Contact links:**
- [ ] All bidder / winner / donor name links navigate to `/[lang]/crm/contact/contact?mode=read&id={contactId}` in new browser tab (optional) or same tab
- [ ] Back button from auction page returns to `/[lang]/crm/event/event`

**DB Seed Verification:**
- [ ] Menu "Auction Management" appears in sidebar under "Events" at OrderBy=3
- [ ] 2 hidden child menus (AUCTIONBID, EVENTAUCTION) registered but `IsMenuRender=false`
- [ ] 5 MasterDataType codes seeded with all rows (AUCTIONITEMCATEGORY×8, AUCTIONITEMSTATUS×6, AUCTIONPAYMENTSTATUS×3, AUCTIONBIDDINGSTATUS×3, AUCTIONTYPE×2)
- [ ] DataSetting JSON has `icon` + `colorHex` for items referenced by renderers
- [ ] GridFormSchema is SKIP (code-driven forms)
- [ ] Optional: 10–12 sample AuctionItems for first seeded event + 30–50 AuctionBids + 3–4 EventAuctions (one per sample event)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things easy to get wrong.

**Schema / group:**
- Schema is **`app`** (same as Event, Campaign).
- Backend group is **`Application`** for Business/Endpoints/Schemas, **`ApplicationModels`** for Domain, **`ApplicationConfigurations`** for EF. Do NOT create a new schema or group.
- FE service folder is **`contact-service`** (preserve — same precedent as Event #40, OrgUnit #44).
- FE page folder is **`crm/event/auctionmanagement`** (matches route + menu URL).

**CompanyId is NOT a request field** — tenant scope comes from HttpContext in commands/queries. All 4 entities include `CompanyId` column for multi-tenant isolation (inherited from Entity base) but it's set server-side on Create and filtered in queries.

**FLOW screens do NOT generate GridFormSchema** — SKIP in DB seed. Forms are code-driven.

**Non-standard FLOW**: NO view-page.tsx with 3 URL modes. This is a single console page at `/[lang]/crm/event/auctionmanagement?eventId=X`. Do NOT force the canonical pattern.
- Inline collapsible Add form replaces `?mode=new`
- Edit modal replaces `?mode=edit`
- No separate read/detail page replaces `?mode=read` — info lives in grid row + BidHistoryModal + Winners table

**Event dependency (ISSUE from #40)**:
- Event entity does NOT have `EventName` column (ISSUE-1 in #40 Event plan). Auction header/event-selector must compose a display title: `{eventCategory.dataName} · {startDate.toLocaleDateString()}` OR fall back to `"Event #" + eventId`. When #40 builds, rewire the event-selector to use the real `eventName`.
- If Event entity gets renamed `PostpondedToDate` → `PostponedToDate` in #40's migration, no impact here.

**Campaign FK is NOT required** — Registry Summary lists it as a dep but the mockup is event-only. Do NOT add `CampaignId` to any of the 4 entities. Note in Known Issues if the business team later asks for it.

**Workflow state machine (CRITICAL)** — enforce via validator + dedicated commands (NOT via `UpdateAuctionItem` free-form):
- Pause / Resume / LowerReserve / Award / ReAuction / RecordPayment each have their own command with specific state guards (e.g. LowerReserve requires StatusId=BelowReserve; AwardItem requires StatusId ∈ (NoWinner, BelowReserve)).
- `CloseBidding` is the main server-side winner-resolver — loops items of the event, reads `CurrentHighBid` vs `ReservePrice`, updates StatusId + WinnerContactId + WinningBidAmount + PaymentStatusId=Awaiting in a transaction. Test this with at least one mixed scenario (some Won, some NoWinner, some Paused carried forward as Paused).
- `PlaceBid` must update `AuctionItem.CurrentHighBid` + `BidsCount` + flip prior highest bid's `IsCurrentHighest=false` — all in one transaction.

**CurrentHighBid + BidsCount caching** — these two fields on `AuctionItem` are cached aggregates of `AuctionBid`. They MUST be updated atomically with every PlaceBid / RetractBid / ReAuctionItem. Not computed at query time (performance). Add a DB-level CHECK or app-level assert in tests.

**Uniqueness**:
- `EventAuction.EventId` must be a UNIQUE index (1:1 with Event).
- `AuctionItem.ItemName` unique per EventId (filtered index on IsActive=true, ignoring soft-deleted).

**Service Dependencies** (UI-only — mock handler):
- ⚠ **SERVICE_PLACEHOLDER: Send Invoice** (`SendInvoiceAuctionItem` command, `sendInvoiceAuctionItem` mutation) — handler toasts success; no email/WhatsApp send until SMS/Email service layer is shared.
- ⚠ **SERVICE_PLACEHOLDER: Generate Receipt** (FE "Receipt" button in Winners table) — opens toast; no PDF generation service yet.
- ⚠ **SERVICE_PLACEHOLDER: Photos upload** (`UploadAuctionItemPhoto`) — FE uploader shows toast; BE command accepts `photoUrl` string but no blob storage integration yet.
- ⚠ **SERVICE_PLACEHOLDER: Bid Activity Feed real-time** — initial build uses 30 s polling. Replace with SignalR/SSE when shared real-time infra lands.
- ⚠ **SERVICE_PLACEHOLDER: Public Bidder Submissions** — the public-facing bidder UI is out of scope. Admin uses the PlaceBid modal as a manual entry surface. Public bidding page is a separate future screen.
- ⚠ **SERVICE_PLACEHOLDER: Payment gateway for collect** — `RecordPayment` writes `PaymentMethodText` + `PaymentCollectedDate` but does NOT call any payment gateway. Cash and manual card-pos entries are assumed.

Full UI must be built for all above (buttons, modals, toasts). Only the external service call is mocked.

**Pre-flagged ISSUES (draft — write to §⑬ Known Issues on first BUILD session):**

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | HIGH | Data | `CurrentHighBid` + `BidsCount` caching must be kept in sync — add integration test for PlaceBid + RetractBid cycles. Risk of drift if commands bypass this update. |
| ISSUE-2 | MED | Data | `AuctionBid.IsCurrentHighest` flag must be flipped atomically when a new higher bid lands. Consider DB trigger OR EF change-tracking in command. |
| ISSUE-3 | MED | Domain | Event has no EventName field (#40 ISSUE-1). Event-selector composes title from category + date. Track #40 resolution to swap to real eventName. |
| ISSUE-4 | MED | Service | Bid Activity feed uses 30 s polling — replace with SignalR when real-time infra lands. |
| ISSUE-5 | MED | Service | Send Invoice / Generate Receipt / Upload Photo are SERVICE_PLACEHOLDER toasts. No email/pdf/blob infra. |
| ISSUE-6 | MED | Service | Public bidder-submissions UI is out-of-scope; PlaceBid admin modal is the only bid entry surface. Future screen for public bidding. |
| ISSUE-7 | MED | UX | When Event changes via event-selector, all 5 queries refire in parallel. Confirm no flicker / stale data (Apollo cache eviction on eventId change). |
| ISSUE-8 | MED | Workflow | CloseBidding atomically resolves winners server-side. Concurrency: if an admin clicks CloseBidding while another places a bid, transaction must serialize. Use `SERIALIZABLE` or `REPEATABLE READ` isolation. |
| ISSUE-9 | LOW | UX | Mockup shows "Closes in 2h 30m" countdown. Live countdown must be FE computed from `biddingClosesAt`; re-render every minute. |
| ISSUE-10 | LOW | Data | AuctionTypeId could be a plain string column with CHECK constraint instead of MasterData FK (Silent/Live is small fixed enum). Using MasterData for consistency; revisit if query overhead noticed. |
| ISSUE-11 | LOW | UX | Lower Reserve modal: after lowering reserve, if currentHighBid ≥ newReserve, item auto-flips BelowReserve → Active. Add unit test. |
| ISSUE-12 | LOW | UX | Re-auction soft-invalidates AuctionBids (IsValid=false); history preserved. If user wants full delete, add separate "Purge Bids" admin tool — defer. |
| ISSUE-13 | LOW | FE | If an event has >1 auction scheduled (future multi-session events), the current 1:1 EventAuction model breaks. Not in mockup — defer. |
| ISSUE-14 | LOW | Data | BidderContactId FK — if bidder is a walk-in guest without a Contact record, admin must create Contact first OR a `BidderName` free-text fallback on AuctionBid. Mockup uses real contacts; deferred. |
| ISSUE-15 | LOW | Seed | MasterData DataSetting JSON schema for colors/icons is not yet standardized — confirm pattern used by ContactType/Branch. |
| ISSUE-16 | LOW | FE | Renderers `auction-category-badge` / `reserve-status-cell` / `bids-count-link` / `payment-status-badge` must be registered in all 3 column-type registries + barrel. Follow ContactType #19 ISSUE-1 precedent. |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — pre-flagged ISSUE-1..16 in §⑫ will be moved here on first BUILD session) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

(No sessions recorded yet — filled in after /build-screen completes.)
