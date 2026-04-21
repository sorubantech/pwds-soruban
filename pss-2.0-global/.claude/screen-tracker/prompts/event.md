---
screen: Event
registry_id: 40
module: Organization (menu lives under CRM_EVENT)
status: COMPLETED
scope: ALIGN
screen_type: FLOW
complexity: High
new_module: NO — app schema + ApplicationModels group already exist
planned_date: 2026-04-20
completed_date: 2026-04-21
last_session_date: 2026-04-21
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (grid + FORM layout + DETAIL layout)
- [x] Existing code reviewed
- [x] Business rules + workflow extracted
- [x] FK targets resolved (paths + GQL queries verified)
- [x] File manifest computed
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated
- [x] Solution Resolution complete
- [x] UX Design finalized (FORM + DETAIL layouts specified)
- [x] User Approval received
- [x] Backend code generated (migration + fields + 6 child entities + summary query)
- [x] Backend wiring complete (DbContext + Mapster + decorator)
- [x] Frontend code generated (index-page + view-page + detail-page + store + widgets + renderers)
- [x] Frontend wiring complete
- [x] DB Seed script generated (GridFormSchema: SKIP for FLOW + MasterData seeds for EventCategory/EventMode/EventStatus — TIMEZONE shared via OrganizationalUnit seed)
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/{lang}/crm/event/event`
- [ ] Grid loads with 10 columns + search + 6 status chip filters + type/org-unit/date-range filter
- [ ] List / Calendar view toggle works
- [ ] 4 KPI widgets render with summary values
- [ ] `?mode=new` — empty FORM renders 5 tabs (Basic/Venue/Reg/Content/Settings) with all fields
- [ ] `?mode=edit&id=X` — FORM loads pre-filled
- [ ] `?mode=read&id=X` — DETAIL layout (dashboard) loads — hero progress bar + 6 KPI cards + ticket type table + registration trend chart + registrants table (placeholder) + post-event analytics panel
- [ ] Create flow: +Add → fill 5 tabs → Save → redirects to `?mode=read&id={newId}`
- [ ] Edit button on detail → `?mode=edit&id=X` → form pre-filled
- [ ] EventMode radio cards (In-person / Virtual / Hybrid) toggle virtual platform fields
- [ ] Child grids inside form (Ticket Types, Speakers) add/remove rows
- [ ] FK dropdowns load via ApiSelect (OrgUnit, Campaign, Country, Pincode, DonationPurpose, NotificationTemplate)
- [ ] Status workflow chips (Draft / Published / InProgress / Completed / Cancelled) render correctly in badge
- [ ] Service placeholder buttons (Check-in Mode, Send Reminder, QR scan, Registrants list) render with toast
- [ ] Unsaved changes dialog triggers on back/navigate with dirty form
- [ ] DB Seed — menu visible under CRM_EVENT

---

## ① Screen Identity & Context

Screen: Event
Module: CRM → Event (MenuId 271)
Schema: `app`
Group: Application (Models = ApplicationModels, Schemas = ApplicationSchemas, Business/Endpoints = Application)

Business: Events is the tenant's full event-management workspace — used by fundraising, marketing, and community staff to plan and run in-person, virtual, and hybrid events (galas, walkathons, webinars, volunteer drives, iftar dinners, town halls). Each event is tied to an Org Unit (HQ / region / branch) and optionally to a Campaign + Donation Purpose so that ticket revenue and event donations flow into the right bucket. The list view shows upcoming/in-progress/completed events with registration progress and revenue; the form is a 5-tab setup wizard (Basic Info → Venue & Schedule → Registration & Tickets → Content & Speakers → Settings). The read-mode "Dashboard" layout is the operational cockpit for a single event — live registration progress, KPI cards, ticket-type breakdown, registration trend chart, registrants list, and a check-in mode with QR scanner for the event day. Registrant-level data comes from Event Ticketing (screen #46) which is not yet built — those sections render as SERVICE_PLACEHOLDERs on the dashboard.

---

## ② Entity Definition

> Table already exists at `app."Events"` with ~32 fields. This ALIGN adds many new fields + 6 child collections to match the mockup. All new fields go into ONE migration.

Table: `app."Events"` (exists)

### Existing Fields (keep as-is, possibly rename per ⑫)
| Field | C# Type | MaxLen | Required | FK Target | Status |
|-------|---------|--------|----------|-----------|--------|
| EventId | int | — | PK | — | Existing |
| CompanyId | int | — | YES | app.Companies | Existing — from HttpContext |
| OrganizationalUnitId | int | — | YES | app.OrganizationalUnits | Existing |
| EventCategoryId | int | — | YES | setting.MasterData (code=EVENTCATEGORY) | Existing |
| EventTypeId | int | — | YES | setting.MasterData (code=EVENTTYPE) | Existing — legacy, possibly retire |
| EventModeId | int | — | YES | setting.MasterData (code=EVENTMODE) | Existing — In-person / Virtual / Hybrid |
| EventStatusId | int | — | YES | setting.MasterData (code=EVENTSTATUS) | Existing — Draft / Published / InProgress / Completed / Cancelled |
| TimezoneId | int | — | NO | setting.MasterData (code=TIMEZONE) | Existing |
| CountryId | int | — | NO | shared.Countries | Existing |
| PincodeId | int | — | NO | shared.Pincodes | Existing |
| StartDate | DateTime | — | YES | — | Existing (combine w/ start time) |
| EndDate | DateTime | — | NO | — | Existing (combine w/ end time) |
| RegistrationRequired | bool | — | NO | — | Existing |
| RegistrationUrl | string | 1000 | NO | — | Existing |
| RegistrationOpenDate | DateTime | — | NO | — | Existing |
| RegistrationEndDate | DateTime | — | NO | — | Existing |
| ShortDescription | string | 1000 | NO | — | Existing — mockup "Description" |
| FullDescription | string | 1000 | NO | — | Existing — legacy, merge into DetailedAgendaHtml |
| EventHighlights | string | 1000 | NO | — | Existing — legacy |
| VenueName | string | 100 | NO | — | Existing — **bump to 200** |
| VenueAddress | string | 1000 | NO | — | Existing |
| VirtualPlatform | string | 100 | NO | — | Existing |
| VirtualMeetingUrl | string | 1000 | NO | — | Existing |
| VirtualMeetingId | string | 100 | NO | — | Existing |
| VirtualMeetingPassword | string | 100 | NO | — | Existing |
| CancellationReason | string | 1000 | NO | — | Existing |
| PostpondedToDate | DateTime | — | NO | — | Existing — **rename to PostponedToDate (ISSUE-3)** |
| EventSummary | string | 1000 | NO | — | Existing |
| Note | string | 1000 | NO | — | Existing |

### NEW Fields to Add (migration)
| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| EventName | string | 200 | YES | — | **Critical missing field — mockup shows "Event Name"** |
| EventCode | string | 50 | YES | — | Unique per Company, auto-gen from EventName if empty |
| RelatedCampaignId | int | — | NO | app.Campaigns | FK — donations attributed to campaign |
| LinkedDonationPurposeId | int | — | NO | donation.DonationPurposes | FK — donations during event go here |
| ShowCountdown | bool | — | NO | — | Settings toggle |
| VenueCity | string | 100 | NO | — | Mockup shows City separately |
| MapLink | string | 1000 | NO | — | Google Maps URL |
| ParkingInfo | string | 500 | NO | — | Free-form text |
| DressCode | string | 100 | NO | — | e.g., "Black tie / Formal" |
| DialInNumbers | string | 1000 | NO | — | Virtual event phone bridge info |
| SendLinkTimingCode | string | 30 | NO | — | enum: `IMMEDIATE` \| `1HR_BEFORE` \| `DAY_BEFORE` \| `EVENT_DAY` |
| Capacity | int | — | YES | — | Total attendees allowed |
| WaitlistEnabled | bool | — | NO | — | default false |
| WaitlistCapacity | int | — | NO | — | null when WaitlistEnabled=false |
| EarlyBirdDeadline | DateTime | — | NO | — | — |
| SendConfirmationEmail | bool | — | NO | — | default true |
| ConfirmationTemplateId | int | — | NO | notify.NotificationTemplates | FK — ALIGN check (see ⑫) |
| SendReminder | bool | — | NO | — | default true |
| ReminderTimingCode | string | 30 | NO | — | enum: `24HR` \| `1HR` \| `BOTH` |
| ReminderChannelEmail | bool | — | NO | — | default true |
| ReminderChannelWhatsApp | bool | — | NO | — | default false |
| ReminderChannelSms | bool | — | NO | — | default false |
| BannerImageUrl | string | 1000 | NO | — | URL to uploaded cover image |
| DetailedAgendaHtml | string | — | NO | — | **nvarchar(max) — rich text** |
| PublicEventPage | bool | — | NO | — | default false |
| CustomUrl | string | 500 | NO | — | Public event-page URL slug |
| AcceptDonations | bool | — | NO | — | default false |
| ShowFundraisingGoal | bool | — | NO | — | default false |
| GoalAmount | decimal(18,2) | — | NO | — | — |
| QrCheckinEnabled | bool | — | NO | — | default true |
| PostEventSurveyEnabled | bool | — | NO | — | default false |
| ShareTitle | string | 200 | NO | — | Open Graph title |
| ShareDescription | string | 160 | NO | — | Open Graph description |
| ShareImageUrl | string | 1000 | NO | — | OG image URL (falls back to banner) |

**Unique Index**: `(CompanyId, EventCode)` filtered `WHERE IsActive = 1`

### Child Entities (NEW — 1:Many via EventId)

| Child | Table | Fields |
|-------|-------|--------|
| **EventTicketType** | `app."EventTicketTypes"` | Id, EventId, TicketName (200), Price decimal(18,2), Capacity int, EarlyBirdPrice decimal(18,2)?, Available bool, SortOrder int |
| **EventSpeaker** | `app."EventSpeakers"` | Id, EventId, Name (200), TitleRole (200)?, ShortBio (200)?, PhotoUrl (1000)?, SortOrder int |
| **EventRegistrationFormField** | `app."EventRegistrationFormFields"` | Id, EventId, FieldCode (30), FieldLabel (100), IsEnabled bool, IsRequired bool, IsSystem bool, SortOrder int. Seed system fields (FULLNAME/EMAIL always enabled+required). Custom fields append |
| **EventSuggestedAmount** | `app."EventSuggestedAmounts"` | Id, EventId, Amount decimal(18,2), SortOrder int |
| **EventCommunicationTrigger** | `app."EventCommunicationTriggers"` | Id, EventId, TriggerCode (30), ChannelCodes (CSV or 3 bools: Email/WhatsApp/Sms), TimingCode (30), TemplateId (FK NotificationTemplate?) |
| **EventGalleryPhoto** | `app."EventGalleryPhotos"` | Id, EventId, PhotoUrl (1000), Caption (200)?, SortOrder int |

All child entities inherit audit columns from `Entity` base. All have FK → Event with cascade delete.

---

## ③ FK Resolution Table

> All resolved by glob + grep on 2026-04-20.

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response DTO Type |
|----------|--------------|-------------------|----------------|---------------|-----------------------|
| CompanyId | Company | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/Company.cs` | — (tenant from HttpContext, no ApiSelect) | companyName | CompanyResponseDto |
| OrganizationalUnitId | OrganizationalUnit | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/OrganizationalUnit.cs` | `getOrganizationalUnits` / `ORGANIZATIONALUNITS_QUERY` | unitName | OrganizationalUnitResponseDto |
| RelatedCampaignId | Campaign | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/Campaign.cs` | `getCampaigns` / `CAMPAIGNS_QUERY` | shortDescription (or campaignName) | CampaignResponseDto |
| LinkedDonationPurposeId | DonationPurpose | `PSS_2.0_Backend/.../Base.Domain/Models/DonationModels/DonationPurpose.cs` | `getDonationPurposes` / `CONTACTDONATIONPURPOSES_QUERY` | donationPurposeName | DonationPurposeResponseDto |
| EventCategoryId | MasterData (code=EVENTCATEGORY) | `PSS_2.0_Backend/.../Base.Domain/Models/SettingModels/MasterData.cs` | `getMasterDatas` (filter by code) / `MASTERDATAS_QUERY` | dataName | MasterDataResponseDto |
| EventModeId | MasterData (code=EVENTMODE) | same | same | dataName | MasterDataResponseDto |
| EventStatusId | MasterData (code=EVENTSTATUS) | same | same | dataName | MasterDataResponseDto |
| TimezoneId | MasterData (code=TIMEZONE) | same | same | dataName | MasterDataResponseDto |
| CountryId | Country | `PSS_2.0_Backend/.../Base.Domain/Models/SharedModels/Country.cs` | `getCountries` / `COUNTRIES_QUERY` | countryName | CountryResponseDto |
| PincodeId | Pincode | `PSS_2.0_Backend/.../Base.Domain/Models/SharedModels/Pincode.cs` | `getPincodes` / `PINCODES_QUERY` | code | PincodeResponseDto |
| ConfirmationTemplateId | NotificationTemplate | `PSS_2.0_Backend/.../Base.Domain/Models/NotifyModels/NotificationTemplate.cs` | `getNotificationTemplates` | templateName | NotificationTemplateResponseDto |

EventType FK is retained for back-compat but **marked deprecated** — mockup only uses EventMode (In-person/Virtual/Hybrid) + EventCategory (Gala/Walkathon/Webinar/...).

---

## ④ Business Rules & Validation

**Uniqueness Rules:**
- `EventCode` unique per `CompanyId` (filtered index `WHERE IsActive = 1`)
- Auto-generate `EventCode` from `EventName` if empty (uppercase, dash-separated, suffix `-{YYYY}`). e.g., "Annual Charity Gala 2026" → `GALA-2026` (fall back to `EVT-{seq}` on collision)

**Required Field Rules:**
- `EventName`, `EventCode`, `EventCategoryId`, `EventModeId`, `EventStatusId`, `OrganizationalUnitId`, `StartDate`, `EndDate`, `TimezoneId`, `VenueName` (when EventModeId resolves to `INPERSON` or `HYBRID`), `Capacity`, `ShortDescription` are mandatory at publish time.
- For Draft status: only `EventName` + `EventCategoryId` + `EventModeId` + `StartDate` + `OrganizationalUnitId` are required.

**Conditional Rules:**
- If `EventModeId` code = `VIRTUAL` → VenueName/Address NOT required; VirtualPlatform + VirtualMeetingUrl required.
- If `EventModeId` code = `HYBRID` → BOTH venue AND virtual fields required.
- If `EventModeId` code = `INPERSON` → virtual fields optional.
- If `WaitlistEnabled = true` → `WaitlistCapacity > 0` required.
- If `AcceptDonations = true` → `LinkedDonationPurposeId` required; at least one `EventSuggestedAmount` child row required.
- If `ShowFundraisingGoal = true` → `GoalAmount > 0` required.
- If `SendReminder = true` → at least one reminder channel (Email/WhatsApp/Sms) must be true.
- `EndDate` > `StartDate`.
- `RegistrationEndDate` ≤ `StartDate` (can't register after event starts).
- `EarlyBirdDeadline` ≤ `RegistrationEndDate` when set.

**Business Logic:**
- Sum of `EventTicketType.Capacity` should not exceed `Event.Capacity` (warn, not hard fail).
- At least 2 system `EventRegistrationFormFields` rows auto-seeded on Create: `{FULLNAME, enabled=true, required=true, system=true}`, `{EMAIL, enabled=true, required=true, system=true}`. These cannot be deleted.
- When Status transitions to `CANCELLED` → `CancellationReason` required.
- When Status transitions to `COMPLETED` → `EventSummary` recommended (not enforced).
- Event cannot transition back from `COMPLETED` or `CANCELLED`.

**Workflow** (EventStatus state machine via MasterData code `EVENTSTATUS`):
- States: `DRAFT → PUBLISHED → INPROGRESS → COMPLETED | CANCELLED`
- `INPROGRESS` derived automatically when `NOW BETWEEN StartDate AND EndDate` AND `Status = PUBLISHED` (computed in query projection; not persisted).
- `Save as Draft` sets Status=DRAFT. `Save & Publish` sets Status=PUBLISHED.
- Transitions fire Communication Triggers (out-of-scope for this build — tracked as SERVICE_PLACEHOLDER).

---

## ⑤ Screen Classification & Pattern Selection

**Screen Type**: FLOW
**Type Classification**: Transactional workflow entity with multi-tab form + dashboard-style detail view + child collections
**Reason**: Mockup shows URL navigation (`event-list` → `event-form` for add/edit, `event-list` → `event-dashboard` for read). Form is a full-page 5-tab wizard, detail is a completely different UI (dashboard with hero + KPIs + charts + registrants). Multiple child collections. Modal-form won't fit.

**Backend Patterns Required:**
- [x] Standard CRUD (11 files — ALIGN — most exist, update Schemas/Create/Update to handle new fields + child collections)
- [x] Tenant scoping (CompanyId from HttpContext — ALIGN existing)
- [x] Nested child creation (6 child collections save atomically with parent)
- [x] Multi-FK validation (ValidateForeignKeyRecord × 11)
- [x] Unique validation — `EventCode` per Company
- [x] Workflow commands — `PublishEvent`, `CancelEvent`, `CompleteEvent`, `DuplicateEvent` (new, beyond generic Update)
- [ ] File upload command — BannerImageUrl + ShareImageUrl + EventGalleryPhotos (SERVICE_PLACEHOLDER — file-upload infra TBD, use URL input fallback)
- [x] Custom business rule validators — EventMode→Venue/Virtual field conditionals, Sum(TicketType.Capacity) ≤ Event.Capacity warning, Status transition guard
- [x] Summary query — `GetEventSummary` returning 4 tenant-wide KPIs
- [x] Per-event dashboard query — `GetEventDashboardById` returning computed metrics (registered count, tickets sold $, donations pledged $, waitlist count — mostly SERVICE_PLACEHOLDER until #46 exists)

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) — **rebuild: existing data-table.tsx has row actions disabled**
- [x] view-page.tsx with 3 URL modes (new, edit, read)
- [x] React Hook Form (5 tabs)
- [x] Zustand store (`event-store.ts`) — viewMode ('list'|'calendar'), activeTab, dashboardPanelState
- [x] Unsaved changes dialog
- [x] FlowFormPageHeader (Back, Save as Draft, Save & Publish, breadcrumb)
- [x] Child grids inside form — Ticket Types, Speakers, Suggested Amounts, Custom Registration Fields, Gallery Photos
- [x] Workflow status badge + action buttons — Edit, Send Reminder, Check-in Mode, More (Duplicate/Export/Archive/Cancel)
- [x] File upload widget — BannerImageUrl + EventGalleryPhotos (SERVICE_PLACEHOLDER — use URL text input)
- [x] Summary cards (4 KPI widgets above grid, "widgets-above-grid" layout → Variant B mandatory)
- [x] Grid aggregation columns — RegisteredCount / Capacity with progress bar, Revenue (subquery on ticket sales, mostly 0 until #46)
- [x] Calendar view alt rendering — month grid with events as colored chips
- [x] Radio-card component (In-person / Virtual / Hybrid)
- [x] Rich text editor for DetailedAgendaHtml (use existing rich editor if present, else simple textarea fallback)
- [x] Tag-input component for SuggestedAmounts
- [x] Dashboard detail layout: hero progress + 6 KPI cards + ticket-type table with inline progress + mini-bar chart + registrants table placeholder + check-in mode panel (toggle)

---

## ⑥ UI/UX Blueprint

**Grid Layout Variant**: `widgets-above-grid` → FE Dev MUST use **Variant B** (`<ScreenHeader>` + 4 KPI widgets + view-toggle + `<DataTableContainer showHeader={false}>`). Mandatory to avoid duplicate headers.

### Grid/List View

**Display Mode**: `table` (with alt calendar view toggle — not card-grid)

**Grid Columns** (10 total, in display order):
| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Event Name | eventName | link (event-name renderer — click navigates to `?mode=read&id={eventId}`) | auto | YES | Accent color, font-weight 600 |
| 2 | Type | eventModeCode | icon+text (event-mode-badge renderer: 🏛️ In-person / 💻 Virtual / 🔀 Hybrid) | 120px | YES | — |
| 3 | Org Unit | organizationalUnit.unitName | text | 140px | YES | FK display |
| 4 | Date & Time | startDate | datetime (formatted "Apr 25, 7:00 PM") | 160px | YES | — |
| 5 | Venue / Platform | venueName \|\| virtualPlatform | text (event-venue renderer — coalesce) | auto | NO | Shows venueName for in-person, virtualPlatform for virtual |
| 6 | Registered | registeredCount | text (format "345 / 400") | 100px | NO | — |
| 7 | Capacity | capacityFillPct | progress-bar renderer (colors: green ≥70%, amber 40-70%, red <40%) | 140px | YES | Computed `registeredCount * 100.0 / capacity` |
| 8 | Revenue | eventRevenue | currency | 120px | YES | Right-aligned; SERVICE_PLACEHOLDER (0 until #46) |
| 9 | Status | eventStatusCode | badge (status-badge renderer with colors: purple=UPCOMING/PUBLISHED, green=INPROGRESS, blue=COMPLETED, red=CANCELLED, amber=DRAFT) | 110px | YES | — |
| 10 | Actions | — | actions column (Dashboard / Edit or View / More dropdown: Duplicate, Send Reminder, Cancel Event) | 160px | — | Conditional: Edit for pre-event, View for post-event |

**Row Click**: Navigates to `?mode=read&id={id}` (DETAIL/Dashboard layout)

**Search/Filter Fields**: `eventName`, `eventCode`, `venueName`, `virtualPlatform` (client+server-side search)

**Status Filter Chips** (6, above grid): `All`, `Upcoming`, `In Progress`, `Completed`, `Cancelled`, `Draft` — each shows count.

**Advanced Filter Panel**:
- Type (EventModeId multi-select)
- Org Unit (OrganizationalUnitId tree-select)
- Date Range (StartDate between)
- Campaign (RelatedCampaignId select)
- Category (EventCategoryId multi-select)

**Grid Actions** (toolbar): Export CSV, Import (future), "+ New Event" → `?mode=new`.

**View Toggle**: `List View` ⇄ `Calendar View`. Calendar view = month grid (7×5 cells), events rendered as colored chips (color by status), click chip → `?mode=read&id={eventId}`, prev/next month buttons. Preserve toolbar/filter chips.

### Page Widgets & Summary Cards

**Widgets** (4 KPI cards above grid):
| # | Widget Title | Value Source | Display Type | Icon | Position |
|---|-------------|-------------|-------------|------|----------|
| 1 | Upcoming Events | summary.upcomingEventsCount | number | teal calendar-check | Top-left |
| 2 | Total Registrations (Active) | summary.totalRegistrationsActive / summary.totalCapacity (show pct subtitle) | number + pct | green user-plus | Top-center-left |
| 3 | Event Revenue (YTD) | summary.eventRevenueYtd | currency | blue hand-holding-dollar | Top-center-right |
| 4 | Avg Attendance Rate | summary.avgAttendanceRate | percent | purple people-group | Top-right |

**Summary GQL Query**: `GetEventSummary` → returns `EventSummaryDto { upcomingEventsCount int, upcomingThisMonth int, totalRegistrationsActive int, totalCapacity int, eventRevenueYtd decimal, eventsYtdCount int, avgAttendanceRate decimal }`.

### Grid Aggregation Columns

| Column Header | Value Description | Source | Implementation |
|--------------|-------------------|--------|----------------|
| Registered | Count of confirmed registrants per event | Subquery `EventRegistrations WHERE EventId = row.EventId AND Status = CONFIRMED` | LINQ subquery — **SERVICE_PLACEHOLDER** (EventRegistration entity belongs to #46; return 0 for now with TODO comment) |
| Capacity Fill % | `registeredCount * 100 / capacity` | Computed | Post-projection in query handler |
| Revenue | `SUM(EventTicketRegistrations.AmountPaid)` per event | Subquery | **SERVICE_PLACEHOLDER** (return 0) |

---

### FLOW View-Page — 3 URL Modes & 2 Distinct UI Layouts

---

#### LAYOUT 1: FORM (mode=new & mode=edit)

**Page Header**: `FlowFormPageHeader` with:
- Back button → `/[lang]/crm/event/event` (with unsaved-changes guard)
- Breadcrumb: `Events > Create Event` (or `Events > {eventName}`)
- Actions: `Cancel` (text-only) + `Save as Draft` (outline) + `Save & Publish` (primary accent)

**Section Container Type**: `tabs` (5 horizontal tabs, 2px accent bottom-border on active)

**Form Sections** (5 tabs in display order):

| # | Icon | Tab Title | Layout | Collapse | Fields |
|---|------|-----------|--------|----------|--------|
| 1 | `fa-info-circle` | Basic Info | 2-column | always-expanded | EventName, EventCode (auto-gen hint), EventMode (3-card radio), EventCategoryId (select), OrganizationalUnitId (tree-select), RelatedCampaignId (ApiSelect), EventStatusId (select — Draft/Published/InProgress/Completed/Cancelled), ShortDescription (textarea full-width) |
| 2 | `fa-map-marker-alt` | Venue & Schedule | mixed | always-expanded | **Schedule section**: StartDate (date+time 2-col), EndDate (date+time), TimezoneId (select) + ShowCountdown toggle. **Venue section** (conditional on EventMode ≠ Virtual): VenueName, VenueAddress (full-width), VenueCity, CountryId (select), MapLink, ParkingInfo, DressCode. **Virtual Platform section** (conditional on EventMode ≠ In-person): VirtualPlatform (Zoom/Teams/Meet/Custom dropdown), VirtualMeetingUrl, VirtualMeetingId, VirtualMeetingPassword, DialInNumbers (textarea), SendLinkTimingCode (radio group: Immediate / 1hr before / Day before / Event day) |
| 3 | `fa-ticket-alt` | Registration | mixed | always-expanded | **Registration Required toggle**. If true: Capacity, WaitlistEnabled toggle (+ WaitlistCapacity conditional). **Registration Period**: RegistrationOpenDate, RegistrationEndDate, EarlyBirdDeadline. **Ticket Types child grid**: 5 cols (Name / Price / Capacity / EarlyBirdPrice / Available checkbox) + remove button per row + "Add Ticket Type" button. **Registration Form Fields checkbox list**: Full Name + Email (locked=always required), Phone, Organization, Dietary, Accessibility, T-shirt Size, Emergency Contact (checkboxes). "+ Add Custom Field" button appends custom rows. **Confirmation Settings**: SendConfirmationEmail toggle + ConfirmationTemplateId (ApiSelect on NotificationTemplate). **Reminder Settings**: SendReminder toggle + ReminderTimingCode (24hr/1hr/Both) + ReminderChannelEmail/WhatsApp/Sms (3 checkboxes) |
| 4 | `fa-microphone` | Content & Speakers | full-width | always-expanded | **BannerImageUrl**: upload area → SERVICE_PLACEHOLDER, fallback URL input field with preview. **DetailedAgendaHtml**: rich editor (simple toolbar — bold/italic/list/link/image/quote). **Speakers child grid**: photo (circle placeholder 80px, upload SERVICE_PLACEHOLDER) + Name, TitleRole, ShortBio (textarea maxLen 200 with char counter). "+ Add Speaker" button. **Event Gallery**: upload area → SERVICE_PLACEHOLDER (for post-event) |
| 5 | `fa-cog` | Settings | mixed | always-expanded | **Public Event Page toggle** + CustomUrl input (conditional). **Accept Donations toggle** + LinkedDonationPurposeId (select), SuggestedAmounts (tag-input — add chips like "$100", "$250"), ShowFundraisingGoal toggle + GoalAmount. **QrCheckinEnabled toggle**. **PostEventSurveyEnabled toggle**. **Social Sharing**: ShareTitle, ShareDescription (maxLen 160 with char counter), ShareImageUrl + live social-preview card (image + domain + title + desc). **Communication Triggers table** (display-only matrix of trigger/channel/timing — mirrors seed data, not editable here; wire to EventCommunicationTriggers child) |

**Field Widget Mapping** (consolidated — all tabs):

| Field | Tab | Widget | Placeholder | Validation | Notes |
|-------|-----|--------|-------------|------------|-------|
| EventName | 1 | text | "e.g., Annual Charity Gala 2026" | required, max 200 | — |
| EventCode | 1 | text | "Auto-generated" | max 50, unique/Company | Auto-fill from EventName on blur |
| EventMode | 1 | **radio-card-group** (3 cards) | — | required | 🏛️ In-person / 💻 Virtual / 🔀 Hybrid (toggles Venue+Virtual sections in Tab 2) |
| EventCategoryId | 1 | select (MasterData code=EVENTCATEGORY) | "Select category..." | optional | Icons via dataAttribute |
| OrganizationalUnitId | 1 | ApiSelect (tree) | "Select org unit..." | required | Hierarchical indent |
| RelatedCampaignId | 1 | ApiSelect | "Select campaign (optional)..." | optional | With hint |
| EventStatusId | 1 | select | — | required | Status workflow |
| ShortDescription | 1 | textarea (rows=3) | — | required at publish | max 1000 |
| StartDate/EndDate | 2 | datetime-picker (date + time 2-col) | — | required | End > Start |
| TimezoneId | 2 | select (MasterData code=TIMEZONE) | — | required | With GMT offset display |
| ShowCountdown | 2 | toggle | — | default true | — |
| VenueName | 2 | text | — | required if EventMode ∈ {INPERSON, HYBRID} | max 200 |
| VenueAddress | 2 | text | — | optional | max 1000 |
| VenueCity | 2 | text | — | optional | max 100 |
| CountryId | 2 | ApiSelect | — | optional | With flag icon |
| MapLink | 2 | url | "https://maps.google.com/..." | optional | — |
| ParkingInfo | 2 | textarea (rows=2) | — | optional | — |
| DressCode | 2 | text | — | optional | — |
| VirtualPlatform | 2 | select | — | required if EventMode ∈ {VIRTUAL, HYBRID} | Zoom/Teams/Meet/Custom |
| VirtualMeetingUrl | 2 | url | "https://zoom.us/j/..." | required if Virtual | — |
| VirtualMeetingId/Password | 2 | text | — | optional | — |
| DialInNumbers | 2 | textarea (rows=2) | — | optional | — |
| SendLinkTimingCode | 2 | radio-group | — | default "1HR_BEFORE" | 4 options |
| RegistrationRequired | 3 | toggle | — | default true | Unlocks registration section |
| Capacity | 3 | number | — | required if RegistrationRequired | min 1 |
| WaitlistEnabled | 3 | toggle | — | default false | Unlocks WaitlistCapacity |
| WaitlistCapacity | 3 | number | — | required if Waitlist | — |
| RegistrationOpenDate/EndDate | 3 | date | — | optional | — |
| EarlyBirdDeadline | 3 | date | — | optional | — |
| **EventTicketTypes** (child) | 3 | **inline repeatable grid** | — | min 1 row if RegRequired | Add/remove rows |
| **EventRegistrationFormFields** (child) | 3 | checkbox-list + "Add Custom Field" | — | — | FULLNAME + EMAIL locked |
| SendConfirmationEmail | 3 | toggle | — | default true | — |
| ConfirmationTemplateId | 3 | ApiSelect (NotificationTemplate) | — | optional | — |
| SendReminder | 3 | toggle | — | default true | — |
| ReminderTimingCode | 3 | select | — | default "BOTH" | 3 options |
| ReminderChannelEmail/WhatsApp/Sms | 3 | 3 inline checkboxes | — | default email=true | — |
| BannerImageUrl | 4 | upload-area → fallback URL input | — | optional | **SERVICE_PLACEHOLDER** |
| DetailedAgendaHtml | 4 | rich-text-editor | — | optional | — |
| **EventSpeakers** (child) | 4 | repeatable cards (photo 80px + 3 fields) | — | optional | Add/remove |
| **EventGalleryPhotos** (child) | 4 | upload-multi → URL list fallback | — | optional | **SERVICE_PLACEHOLDER** |
| PublicEventPage | 5 | toggle | — | default false | Unlocks CustomUrl |
| CustomUrl | 5 | text | "events.domain.org/slug" | required if PublicEventPage | — |
| AcceptDonations | 5 | toggle | — | default false | Unlocks donation fields |
| LinkedDonationPurposeId | 5 | ApiSelect | — | required if AcceptDonations | — |
| **EventSuggestedAmounts** (child) | 5 | tag-input (add/remove chips) | "Add amount..." | min 1 if AcceptDonations | — |
| ShowFundraisingGoal | 5 | toggle | — | default false | — |
| GoalAmount | 5 | currency | — | required if ShowFundraisingGoal | — |
| QrCheckinEnabled | 5 | toggle | — | default true | — |
| PostEventSurveyEnabled | 5 | toggle | — | default false | — |
| ShareTitle/Description/ImageUrl | 5 | text/text maxLen 160 / url | — | optional | With live social preview card |
| **EventCommunicationTriggers** (child) | 5 | read-only display table | — | — | Seeded from system defaults; future-editable |

**Special Form Widgets** (reusable):

- **Radio-Card Group (3-col)** — EventMode selector:
  | Card | Icon | Label | Description | Triggers |
  |------|------|-------|-------------|----------|
  | INPERSON | 🏛️ | In-person | Physical venue, on-site attendance | Show Venue section, hide Virtual section |
  | VIRTUAL | 💻 | Virtual | Online only (Zoom, Teams, webinar) | Hide Venue section, show Virtual section |
  | HYBRID | 🔀 | Hybrid | Both physical venue + virtual stream | Show BOTH Venue and Virtual sections |

- **Conditional Sections** (Tab 2 Venue/Virtual visibility driven by EventMode).

- **Repeatable Child Grids**:
  | Child | Grid Columns | Add/Edit | Delete |
  |-------|-------------|----------|--------|
  | EventTicketType | Name / Price / Capacity / EarlyBird Price / Available / × | inline row | remove row |
  | EventSpeaker | photo (80px circle) + Name / TitleRole / ShortBio (textarea w/ char count) / × | card | remove card |
  | EventRegistrationFormField | checkbox + label (system rows disabled) | — | — (system locked) |
  | EventSuggestedAmount | chip tag-input | + btn | × on chip |
  | EventGalleryPhoto | upload thumbnail list | upload btn | × on thumbnail |

- **Tag-Input Widget** (SuggestedAmounts) — enter amount, Enter key adds chip, × removes.

- **Social Preview Card** (live OG preview) — renders ShareImageUrl + CustomUrl domain + ShareTitle + ShareDescription as 400px-wide card.

---

#### LAYOUT 2: DETAIL (mode=read) — Dashboard (DIFFERENT UI)

> Mockup is `event-dashboard.html`. This is a **fully different UI** from the form — an operational cockpit for a single event.

**Page Header**: `FlowFormPageHeader` with:
- Back button → `/[lang]/crm/event/event`
- Breadcrumb: `Events > {eventName}`
- Event title (`eventName`) + 3 header-badges: [EventMode icon+text] [EventStatus badge] [Date range + Timezone]
- Countdown sub-line (for upcoming events): `Countdown: X days, Y hours remaining` (computed client-side, hidden if COMPLETED/CANCELLED)
- Actions (right): `Edit Event` (outline — navigates to `?mode=edit&id=X`), `Send Reminder` (outline — SERVICE_PLACEHOLDER toast), `Check-in Mode` (primary accent — toggles check-in panel), `More ⋮` dropdown (Duplicate Event, Export Registrants, Archive Event, Cancel Event)

**Page Layout** (single column, stacked sections with `section-gap` between):

| Section | Content |
|---------|---------|
| Hero Progress Card | Large registration progress bar: `{registeredCount} registered of {capacity} capacity` + 20px progress bar + big pct + 3 sub-stats (spots left / on waitlist / reg closes date) |
| KPI Grid (6 cards) | Registered (+weeklyDelta), Tickets Sold ($ + avgPerTicket), Donations Pledged ($ + donorCount), Waitlist count, Check-in Rate (—/post-event), Post-event Donations (—/post-event) |
| Registration by Ticket Type | Table: Name / Price / Sold / Capacity (inline progress bar) / Revenue / Status. Reads `EventTicketTypes` joined with sold counts (sold count = 0 until #46 exists — SERVICE_PLACEHOLDER) |
| Registration Trend Chart | Mini-bars chart (20 daily bars) showing daily registration count over time. X-axis: dates from RegistrationOpenDate. Y-axis: count. Annotations for Early bird deadline + Email blast events (hard-coded "Mar 9" + "Mar 25" placeholder dates in legend until real analytics exists — SERVICE_PLACEHOLDER) |
| Registrants List | Table: Name (link→contact detail) / Email / Ticket / Amount / Registered date / Status (Confirmed/Waitlisted) / Check-in checkbox / Actions (View/Cancel or Promote/Remove for waitlist). Bulk actions bar: Send Reminder / Export List / Send Communication. Pagination. **SERVICE_PLACEHOLDER — entire table renders empty-state card "Registrants will appear here once Event Ticketing (#46) is built. Data model: EventRegistration { ContactId, EventId, TicketTypeId, Status, CheckedInAt }"** |
| Post-Event Analytics | 3-column grid (Attendance Summary / Event Revenue / Follow-up Status) with `.post-event-muted` opacity 0.5 when status ≠ COMPLETED. Values: Registered/Attended/No-show; TicketSales/Donations/Auction/Total; Thank-you emails sent / Surveys sent / Donation follow-up count. SERVICE_PLACEHOLDER until #46 + post-event hooks exist |

**Check-in Mode Panel** (toggled from header button — hides main dashboard, shows full-page panel):
- Header: `Check-in Mode — {eventName}` + Exit button (red outline)
- Big counter: `✅ {checkedInCount} / {registeredCount} checked in ({pct}%)`
- QR Scanner area (dashed border placeholder) — SERVICE_PLACEHOLDER (camera access)
- Search input: "Type name or email to check in..."
- Recent check-ins feed (last 10 with timestamp)
- All actions SERVICE_PLACEHOLDER until #46 exists

**Dashboard Detail GQL Query**: `GetEventDashboardById(eventId)` → returns `EventDashboardDto { event: EventResponseDto, registeredCount int, capacityFillPct decimal, spotsLeft int, waitlistCount int, ticketsSoldAmount decimal, avgTicketPrice decimal, donationsPledged decimal, donorCount int, checkedInCount int, checkInRate decimal?, postEventDonations decimal?, attendanceSummary { registered, attended, noShow }, revenueSummary { ticket, donations, auction, total }, ticketTypeBreakdown: [{ name, price, sold, capacity, revenue }], registrationTrend: [{ date, count }], registrants: [RegistrantDto] (paginated) }`.

All per-event counts except `registeredCount`/`waitlistCount`/`ticketsSoldAmount` return 0 or null until #46 exists — mark SERVICE_PLACEHOLDER in handler with TODO comment.

### User Interaction Flow

1. Grid → "+ New Event" → `?mode=new` → 5-tab empty form → user fills all tabs → `Save as Draft` or `Save & Publish` → API creates Event + children atomically → URL redirects to `?mode=read&id={newId}` (Dashboard).
2. Grid row click → `?mode=read&id=X` → Dashboard loads.
3. Dashboard `Edit Event` → `?mode=edit&id=X` → same 5-tab form pre-filled.
4. Save in edit → URL returns to `?mode=read&id=X`.
5. Back button → `/[lang]/crm/event/event` (grid).
6. Check-in Mode button → swaps main content with check-in panel (URL unchanged, local state only).
7. Calendar view toggle → re-renders same data as month grid; click chip → `?mode=read&id={eventId}`.
8. Unsaved changes guard on all back/navigate when form dirty.

---

## ⑦ Substitution Guide

**Canonical Reference**: SavedFilter (FLOW — URL mode precedent) + DonationInKind #7 (FLOW + detail drawer precedent — though this uses a dashboard page, not a drawer)

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | Event | Entity/class name |
| savedFilter | event | Variable/field names (camelCase) |
| SavedFilterId | EventId | PK field |
| SavedFilters | Events | Table name, collection names |
| saved-filter | event | FE route segment, file names (kebab → event is already single word) |
| savedfilter | event | FE folder (already `crm/event/event` — preserve) |
| SAVEDFILTER | EVENT | Grid code, menu code |
| notify | app | DB schema |
| Notify | Application | Backend group name (Models = ApplicationModels / Schemas = ApplicationSchemas / Business = Application / EndPoints = Application) |
| NotifyModels | ApplicationModels | Namespace suffix |
| NOTIFICATIONSETUP | CRM_EVENT | Parent menu code |
| NOTIFICATION | CRM | Module code |
| crm/communication/savedfilter | crm/event/event | FE route path |
| notify-service | **contact-service** | FE service folder name (preserve — existing DTO lives there) |

**⚠ Important deviation**: The FE service folder for Event is `contact-service` (not `application-service`), because that's where the existing `EventDto.ts`, `EventQuery.ts`, and `EventMutation.ts` already live. Do NOT move them — just extend in place.

---

## ⑧ File Manifest

### Backend Files (ALIGN — most exist; modify in place)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | Entity | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/Event.cs` | **MODIFY** — add 33 new fields + 6 child nav collections + rename `PostpondedToDate`→`PostponedToDate` (ISSUE-3) |
| 2 | Child Entity: EventTicketType | `PSS_2.0_Backend/.../Base.Domain/Models/ApplicationModels/EventTicketType.cs` | **CREATE** |
| 3 | Child Entity: EventSpeaker | `.../ApplicationModels/EventSpeaker.cs` | **CREATE** |
| 4 | Child Entity: EventRegistrationFormField | `.../ApplicationModels/EventRegistrationFormField.cs` | **CREATE** |
| 5 | Child Entity: EventSuggestedAmount | `.../ApplicationModels/EventSuggestedAmount.cs` | **CREATE** |
| 6 | Child Entity: EventCommunicationTrigger | `.../ApplicationModels/EventCommunicationTrigger.cs` | **CREATE** |
| 7 | Child Entity: EventGalleryPhoto | `.../ApplicationModels/EventGalleryPhoto.cs` | **CREATE** |
| 8 | EF Config: Event | `.../Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventConfiguration.cs` | **MODIFY** — add 33 field configs + 6 child HasMany + unique index (CompanyId, EventCode) |
| 9 | EF Configs: 6 children | `.../ApplicationConfigurations/EventTicketTypeConfiguration.cs` etc. ×6 | **CREATE** (6 files) |
| 10 | Schemas (DTOs) | `.../Base.Application/Schemas/ApplicationSchemas/EventSchemas.cs` | **MODIFY** — add 33 fields to EventRequestDto + 6 child collections; add EventSummaryDto + EventDashboardDto + RegistrantDto; prune `OrganizationalEventResponseDto` duplicate |
| 11 | Create Command | `.../Base.Application/Business/Application/Events/Commands/CreateEvent.cs` | **MODIFY** — handle child collections; auto-gen EventCode; seed system registration form fields |
| 12 | Update Command | `.../Commands/UpdateEvent.cs` | **MODIFY** — upsert children (delete missing, update existing, insert new); guard status transitions |
| 13 | Delete Command | `.../Commands/DeleteEvent.cs` | (existing — verify cascades) |
| 14 | Toggle Command | `.../Commands/ToggleEvent.cs` | (existing — verify) |
| 15 | NEW: PublishEvent Command | `.../Commands/PublishEvent.cs` | **CREATE** — Draft → Published transition + validation |
| 16 | NEW: CancelEvent Command | `.../Commands/CancelEvent.cs` | **CREATE** — guard only Draft/Published/InProgress; require CancellationReason |
| 17 | NEW: CompleteEvent Command | `.../Commands/CompleteEvent.cs` | **CREATE** — InProgress → Completed; populate EventSummary |
| 18 | NEW: DuplicateEvent Command | `.../Commands/DuplicateEvent.cs` | **CREATE** — clones Event + child rows, EventCode+" Copy", Status=DRAFT |
| 19 | GetAll Query | `.../Queries/GetEvent.cs` | **MODIFY** — project 10 new grid fields incl. registeredCount SERVICE_PLACEHOLDER subquery; advanced filters; computed capacityFillPct |
| 20 | GetById Query | `.../Queries/GetEventById.cs` | **MODIFY** — include 6 child collections + all FK navigations |
| 21 | NEW: GetEventSummary Query | `.../Queries/GetEventSummary.cs` | **CREATE** — returns EventSummaryDto (4 KPI values, tenant-scoped) |
| 22 | NEW: GetEventDashboardById Query | `.../Queries/GetEventDashboardById.cs` | **CREATE** — returns EventDashboardDto (per-event operational metrics + SERVICE_PLACEHOLDER zeros for #46-dependent fields) |
| 23 | Mutations GQL | `.../Base.API/EndPoints/Application/Mutations/EventMutations.cs` | **MODIFY** — register PublishEvent / CancelEvent / CompleteEvent / DuplicateEvent |
| 24 | Queries GQL | `.../Base.API/EndPoints/Application/Queries/EventQueries.cs` | **MODIFY** — register GetEventSummary + GetEventDashboardById; retire GetOrganizationalEventById if unused |
| 25 | Migration | `.../Base.Infrastructure/Data/Migrations/YYYYMMDDHHMMSS_EventAlignMockup.cs` | **CREATE** — 33 new columns + 6 child tables + unique index + rename Postponded |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `IApplicationDbContext.cs` | DbSet<EventTicketType>, DbSet<EventSpeaker>, DbSet<EventRegistrationFormField>, DbSet<EventSuggestedAmount>, DbSet<EventCommunicationTrigger>, DbSet<EventGalleryPhoto> (6 new) |
| 2 | `ApplicationDbContext.cs` | Same 6 DbSets + apply 6 new configs |
| 3 | `DecoratorProperties.cs` | DecoratorApplicationModules entries for 6 new child entities (if pattern applies) |
| 4 | `ApplicationMappings.cs` (Mapster) | Add .Map for 33 new Event scalar fields + 6 child RequestDto↔Entity maps + EventSummaryDto + EventDashboardDto mappings |

### Frontend Files (ALIGN — rebuild UI on top of existing DTO/GQL)

| # | File | Path | Action |
|---|------|------|--------|
| 1 | DTO Types | `PSS_2.0_Frontend/src/domain/entities/contact-service/EventDto.ts` | **MODIFY** — extend EventRequestDto with 33 new fields + 6 child interfaces (EventTicketTypeDto, EventSpeakerDto, EventRegistrationFormFieldDto, EventSuggestedAmountDto, EventCommunicationTriggerDto, EventGalleryPhotoDto); add EventSummaryDto + EventDashboardDto + RegistrantDto |
| 2 | GQL Query | `PSS_2.0_Frontend/src/infrastructure/gql-queries/contact-queries/EventQuery.ts` | **MODIFY** — extend EVENTS_QUERY (add all grid + dashboard projection fields), EVENT_BY_ID_QUERY (include 6 children); ADD EVENT_SUMMARY_QUERY + EVENT_DASHBOARD_BY_ID_QUERY |
| 3 | GQL Mutation | `PSS_2.0_Frontend/src/infrastructure/gql-mutations/contact-mutations/EventMutation.ts` | **MODIFY** — extend Create/Update with new fields + 6 child arrays; ADD PUBLISH_EVENT / CANCEL_EVENT / COMPLETE_EVENT / DUPLICATE_EVENT mutations |
| 4 | Page Config | `PSS_2.0_Frontend/src/presentation/pages/crm/event/event.tsx` | **MODIFY** — replace `<EventDataTable />` with `<EventPage />` (the new index-page component) |
| 5 | Index Page Barrel | `PSS_2.0_Frontend/src/presentation/components/page-components/crm/event/event/index.ts` | **MODIFY** — export EventPage |
| 6 | Router | `.../page-components/crm/event/event/index.tsx` | **CREATE** — URL dispatcher: if `?mode=new\|edit\|read` → `<EventViewPage />`, else → `<EventIndexPage />` |
| 7 | Index Page | `.../page-components/crm/event/event/index-page.tsx` | **CREATE** — Variant B: `<ScreenHeader>` + 4 KPI widgets + view-toggle (list/calendar) + `<DataTableContainer showHeader={false}>` OR custom calendar grid |
| 8 | View Page (form — 3 modes) | `.../page-components/crm/event/event/view-page.tsx` | **CREATE** — full-page 5-tab form for new/edit; delegates to `<EventDashboardPage />` when mode=read |
| 9 | Dashboard Page | `.../page-components/crm/event/event/event-dashboard-page.tsx` | **CREATE** — read-mode dashboard UI (hero + KPIs + ticket-type table + trend chart + registrants placeholder + post-event analytics + check-in panel toggle) |
| 10 | Zustand Store | `.../page-components/crm/event/event/event-store.ts` | **CREATE** — viewMode ('list'\|'calendar'), activeTab (1-5), checkinModeOpen (bool), dashboardFilters |
| 11 | Form: Basic Info Tab | `.../page-components/crm/event/event/form-tabs/basic-info-tab.tsx` | **CREATE** |
| 12 | Form: Venue & Schedule Tab | `.../form-tabs/venue-schedule-tab.tsx` | **CREATE** |
| 13 | Form: Registration Tab (+ ticket-types-grid, registration-form-fields) | `.../form-tabs/registration-tab.tsx` + child fields | **CREATE** |
| 14 | Form: Content & Speakers Tab (+ speakers-repeater, rich-editor wrapper) | `.../form-tabs/content-speakers-tab.tsx` | **CREATE** |
| 15 | Form: Settings Tab (+ suggested-amounts-tag-input, social-preview-card, comm-triggers-table) | `.../form-tabs/settings-tab.tsx` | **CREATE** |
| 16 | KPI Widgets | `.../page-components/crm/event/event/event-widgets.tsx` | **CREATE** — 4 KPI cards binding EventSummaryDto |
| 17 | Calendar View | `.../page-components/crm/event/event/event-calendar-view.tsx` | **CREATE** — month-grid reading EVENTS_QUERY |
| 18 | Check-in Panel | `.../page-components/crm/event/event/event-checkin-panel.tsx` | **CREATE** — SERVICE_PLACEHOLDER QR scanner + search + recent-feed |
| 19 | Registrants Table (placeholder) | `.../page-components/crm/event/event/event-registrants-table.tsx` | **CREATE** — empty-state card with #46 placeholder message |
| 20 | Route Page | `PSS_2.0_Frontend/src/app/[lang]/crm/event/event/page.tsx` | **MODIFY** — already renders `<EventPageConfig />`; verify no change needed |
| 21 | Legacy Route Delete | `PSS_2.0_Frontend/src/app/[lang]/organization/organizationsetup/event/page.tsx` | **DELETE** — duplicate legacy route |
| 22 | Renderer: event-name link | `PSS_2.0_Frontend/src/presentation/components/data-table/renderers/event-name-renderer.tsx` | **CREATE** — link to `?mode=read&id={row.eventId}` |
| 23 | Renderer: event-mode-badge | `.../renderers/event-mode-badge-renderer.tsx` | **CREATE** — icon+text (🏛️💻🔀) |
| 24 | Renderer: event-status-badge | `.../renderers/event-status-badge-renderer.tsx` | **CREATE** — 5 colors |
| 25 | Renderer: progress-bar (capacity fill) | existing `progress-bar-renderer.tsx` or **CREATE** | Color thresholds (green/amber/red) |
| 26 | Renderer: event-venue-coalesce | `.../renderers/event-venue-renderer.tsx` | **CREATE** — VenueName \|\| VirtualPlatform |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `domain/services/entity-ops/contact-service-entity-operations.ts` | Extend EVENT ops with publishEvent, cancelEvent, completeEvent, duplicateEvent, getSummary, getDashboard |
| 2 | `operations-config.ts` | Verify EVENT registered (already is — no change) |
| 3 | Sidebar menu config | Already points to `crm/event/event` via DB seed — no config change |
| 4 | Route config | No change needed — `/crm/event/event` exists |
| 5 | 3 column-type registries (advanced / basic / flow) | Register 4 new renderers: event-name, event-mode-badge, event-status-badge, event-venue |
| 6 | `shared-cell-renderers.ts` barrel | Export 4 new renderers |

---

## ⑨ Pre-Filled Approval Config

```
---CONFIG-START---
Scope: ALIGN

MenuName: Events
MenuCode: EVENT
ParentMenu: CRM_EVENT
Module: CRM
MenuUrl: crm/event/event
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE, TOGGLE, IMPORT, EXPORT

GridFormSchema: SKIP
GridCode: EVENT
---CONFIG-END---
```

**MasterData seeds required** (if not already present):
- Code `EVENTCATEGORY`: Gala / Walkathon / Webinar / VolunteerDrive / CommunityGathering / AwardsCeremony / Workshop / ReligiousGathering / Other (9 rows)
- Code `EVENTMODE`: INPERSON ("In-person") / VIRTUAL ("Virtual") / HYBRID ("Hybrid") (3 rows)
- Code `EVENTSTATUS`: DRAFT / PUBLISHED / INPROGRESS / COMPLETED / CANCELLED (5 rows, with colors: amber/purple/green/blue/red)
- Code `TIMEZONE`: Asia/Dubai (GMT+4) / Asia/Kolkata (GMT+5:30) / Europe/London (GMT+0) / America/New_York (GMT-5) / America/Los_Angeles (GMT-8) / Asia/Riyadh (GMT+3) / Australia/Sydney (GMT+11) (7 rows minimum)

Seed script: `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/Event-sqlscripts.sql` (preserve repo typo).

---

## ⑩ Expected BE→FE Contract

**GraphQL Types:**
- Query type: `EventQueries`
- Mutation type: `EventMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getEvents` | `EventListPage` (paginated EventResponseDto[]) | searchText, pageNo, pageSize, sortField, sortDir, isActive, dateFrom, dateTo, statusCode, eventModeCode, organizationalUnitId, campaignId, categoryId |
| `getEventById` | `EventResponseDto` | eventId |
| `getEventSummary` | `EventSummaryDto` | — (tenant from HttpContext) |
| `getEventDashboardById` | `EventDashboardDto` | eventId |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createEvent` | EventRequestDto (with 6 child arrays) | int (new EventId) |
| `updateEvent` | EventRequestDto | int |
| `deleteEvent` | eventId | int |
| `activateDeactivateEvent` | eventId | int |
| `publishEvent` | eventId | int |
| `cancelEvent` | { eventId, cancellationReason } | int |
| `completeEvent` | { eventId, eventSummary? } | int |
| `duplicateEvent` | eventId | int (new EventId) |

**Response DTO fields** (EventResponseDto — extended list):
| Field | Type | Notes |
|-------|------|-------|
| eventId | number | PK |
| eventName | string | NEW required |
| eventCode | string | NEW unique |
| organizationalUnitId | number | FK |
| organizationalUnit | { unitName } | nav |
| eventCategoryId | number | FK → MasterData |
| eventCategory | { dataName, dataCode } | nav |
| eventModeId | number | FK → MasterData |
| eventMode | { dataName, dataCode } | nav — INPERSON/VIRTUAL/HYBRID |
| eventStatusId | number | FK |
| eventStatus | { dataName, dataCode } | nav |
| eventModeCode | string | Projected shortcut for grid |
| eventStatusCode | string | Projected shortcut |
| relatedCampaignId | number? | NEW FK |
| relatedCampaign | { shortDescription } | nav |
| startDate / endDate | ISO datetime | — |
| timezoneId + timezone | FK+nav | — |
| venueName / venueAddress / venueCity | string? | existing + NEW VenueCity |
| countryId + country | FK+nav | — |
| mapLink / parkingInfo / dressCode | string? | NEW |
| virtualPlatform / virtualMeetingUrl / virtualMeetingId / virtualMeetingPassword / dialInNumbers | string? | — |
| sendLinkTimingCode | enum string | NEW |
| capacity | number | NEW required |
| waitlistEnabled / waitlistCapacity | bool, number? | NEW |
| registrationRequired / registrationUrl / registrationOpenDate / registrationEndDate / earlyBirdDeadline | mixed | — |
| sendConfirmationEmail / confirmationTemplateId | bool, number? | NEW |
| sendReminder / reminderTimingCode / reminderChannelEmail / reminderChannelWhatsApp / reminderChannelSms | bool×4 + enum | NEW |
| bannerImageUrl / detailedAgendaHtml | string? | NEW |
| publicEventPage / customUrl | bool, string? | NEW |
| acceptDonations / linkedDonationPurposeId / showFundraisingGoal / goalAmount | mixed | NEW |
| qrCheckinEnabled / postEventSurveyEnabled | bool×2 | NEW |
| shareTitle / shareDescription / shareImageUrl | string? | NEW |
| eventSummary / cancellationReason / note / postponedToDate | existing | — |
| registeredCount / capacityFillPct / eventRevenue | number (projected) | grid aggregates — SERVICE_PLACEHOLDER zeros |
| ticketTypes: EventTicketTypeDto[] | array | child |
| speakers: EventSpeakerDto[] | array | child |
| registrationFormFields: EventRegistrationFormFieldDto[] | array | child |
| suggestedAmounts: EventSuggestedAmountDto[] | array | child |
| communicationTriggers: EventCommunicationTriggerDto[] | array | child |
| galleryPhotos: EventGalleryPhotoDto[] | array | child |
| isActive | boolean | inherited |

**EventSummaryDto**: `{ upcomingEventsCount int, upcomingThisMonth int, totalRegistrationsActive int, totalCapacity int, eventRevenueYtd decimal, eventsYtdCount int, avgAttendanceRate decimal }`

**EventDashboardDto**: see §⑥ LAYOUT 2

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — 0 errors
- [ ] EF migration `EventAlignMockup` applies cleanly (includes 33 column adds + 6 new tables + unique-filtered-index + Postponded rename)
- [ ] `pnpm dev` — page loads at `/{lang}/crm/event/event`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Grid loads with 10 columns: Event Name, Type, Org Unit, Date & Time, Venue/Platform, Registered, Capacity, Revenue, Status, Actions
- [ ] 4 KPI widgets show values from GetEventSummary
- [ ] 6 status filter chips work (All / Upcoming / In Progress / Completed / Cancelled / Draft — each with count badge)
- [ ] Advanced filter: Type, Org Unit, Date Range, Campaign, Category
- [ ] View toggle List ⇄ Calendar works; calendar shows events as colored chips by status
- [ ] `?mode=new`: empty form renders 5 tabs with correct field count per tab
- [ ] EventMode radio card toggle shows/hides Venue section + Virtual Platform section correctly (3 modes)
- [ ] Tab 3 ticket-types child grid: add row, edit, remove row
- [ ] Tab 3 registration-form-fields: FULLNAME + EMAIL are locked+required; custom fields can be added
- [ ] Tab 4 speakers child grid: add card, remove card, char counter on bio (max 200)
- [ ] Tab 5 suggested-amounts tag-input: add chip, remove chip
- [ ] Tab 5 social-preview-card updates live as ShareTitle/Description/ImageUrl change
- [ ] Save as Draft creates event with Status=DRAFT → redirects to `?mode=read&id={newId}`
- [ ] Save & Publish creates event with Status=PUBLISHED (validates all required fields for publish)
- [ ] `?mode=read&id=X`: Dashboard layout loads (completely different UI from form)
- [ ] Dashboard hero shows registration progress bar + pct + spots-left/waitlist/closes-date
- [ ] 6 KPI cards render (3 SERVICE_PLACEHOLDER zeros for now acceptable)
- [ ] Ticket-type breakdown table renders from child rows (sold count = 0 SERVICE_PLACEHOLDER)
- [ ] Registration Trend chart renders as static mini-bars (SERVICE_PLACEHOLDER)
- [ ] Registrants table renders empty-state with #46 message
- [ ] Check-in Mode button opens full-page panel (counter + QR placeholder + search + recent-feed all SERVICE_PLACEHOLDERs)
- [ ] Edit button on dashboard → `?mode=edit&id=X` form pre-filled with all 5 tabs' data + 6 child collections populated
- [ ] Save in edit mode updates record (children upserted: added/modified/deleted)
- [ ] Publish Event transition: DRAFT → PUBLISHED via dedicated mutation
- [ ] Cancel Event requires CancellationReason modal input
- [ ] Duplicate Event copies all fields + children, Status=DRAFT, EventCode="{orig}-COPY"
- [ ] FK dropdowns load: OrgUnit (tree), Campaign, Country, Pincode, DonationPurpose, NotificationTemplate, EventCategory, EventMode, EventStatus, Timezone
- [ ] Unsaved changes dialog triggers on dirty-form navigation
- [ ] Permissions: Edit/Delete buttons respect BUSINESSADMIN capabilities

**DB Seed Verification:**
- [ ] Menu "Events" appears in sidebar under CRM module → Events parent menu (CRM_EVENT)
- [ ] Grid columns render correctly (10 columns)
- [ ] MasterData seeds present: EVENTCATEGORY (9 rows), EVENTMODE (3 rows), EVENTSTATUS (5 rows), TIMEZONE (7+ rows)
- [ ] GridFormSchema is NULL for FLOW (no form schema generated)
- [ ] Legacy `/organization/organizationsetup/event` route removed from sidebar (if present)

---

## ⑫ Special Notes & Warnings

- **CompanyId is NOT a form field** — tenant from HttpContext in all FLOW screens. Don't include in EventRequestDto inputs.
- **FLOW screens do NOT generate GridFormSchema** in DB seed — SKIP it.
- **view-page.tsx handles all 3 modes** — new/edit share the 5-tab FORM layout; read mode renders a completely different DASHBOARD layout (event-dashboard-page.tsx).
- **DASHBOARD layout is NOT the form disabled** — do not wrap the form in `<fieldset disabled>`. It is a bespoke multi-section page with hero, KPIs, ticket-type table, trend chart, registrants, check-in mode toggle.
- **Existing BE fields to RETAIN**: `EventTypeId`, `FullDescription`, `EventHighlights`, `PostpondedToDate` (→ rename `PostponedToDate`). Retire-in-place (keep column, mark `[Obsolete]` in entity comments) until a future cleanup pass.
- **FE service folder is `contact-service`** (not `application-service`). Existing `EventDto.ts` / `EventQuery.ts` / `EventMutation.ts` live there — extend in place. Do NOT relocate.
- **Legacy duplicate route**: `PSS_2.0_Frontend/src/app/[lang]/organization/organizationsetup/event/page.tsx` imports the same `EventPageConfig`. **DELETE** during build.
- **ISSUE-1 CRITICAL**: mockup requires `EventName` field — entity has NO such field today (only descriptions). Migration MUST add it as `VARCHAR(200) NOT NULL`. Existing rows (if any) need backfill — use `COALESCE(ShortDescription, 'Untitled Event ' + CAST(EventId AS VARCHAR))` default.
- **ISSUE-2 CRITICAL**: mockup requires `EventCode` field for unique display/URL. Migration MUST add it + backfill (auto-generate from EventName), add filtered unique index.
- **ISSUE-3**: Rename `PostpondedToDate` → `PostponedToDate` (typo fix). Use `sp_rename` to preserve data. Update all C# + TS references.
- **ISSUE-4 SERVICE_PLACEHOLDERs** (below) are mandatory because Event Ticketing #46 is not yet built — the Registrants/Check-in/Ticket Revenue/Post-Event Analytics features all depend on an `EventRegistration` entity that lives in #46's scope.
- **ISSUE-5**: The existing `OrganizationalEventResponseDto` is a duplicate with no nav objects. Prune from Schemas unless proven in use (grep showed `getOrganizationalEventById` query reference — verify call sites before pruning).
- **ISSUE-6**: Empty `EventDto` subclass of EventResponseDto — remove unless HotChocolate filtering needs it.
- **ISSUE-7**: `RelatedCampaignId` exists in FE DTO but NOT in BE entity — migration MUST add the column and FK. Without it, Campaign dropdown can't bind.
- **ISSUE-8**: FE `EVENTS_QUERY` does NOT currently project `relatedCampaign` — extend query string.
- **ISSUE-9**: `registeredCount`, `eventRevenue`, `waitlistCount` are projected via LINQ subqueries against an EventRegistration table that DOES NOT YET EXIST. Return `0` constants for the first build with `// TODO: wire to #46 Event Ticketing` comments — do NOT block on #46.
- **ISSUE-10**: `INPROGRESS` status is computed (not persisted) — it's derived from `StartDate ≤ NOW ≤ EndDate AND Status = PUBLISHED`. Expose via `eventStatusCode` projection string, NOT persisted EventStatus row. Design decision — document in handler.
- **ISSUE-11**: The mockup form tab 3 "Confirmation template" dropdown expects NotificationTemplate entries scoped to EventConfirmation category. The `confirmationTemplateId` FK is optional — during the first build, use a plain select with hardcoded values as fallback if NotificationTemplate categorization is unclear.
- **ISSUE-12**: `EventCommunicationTriggers` child table includes default seed rows (Registration confirmed / Event reminder / Post-event thank you / Post-event survey). Table is read-only in the UI (editing is deferred). Build the table but expose no edit affordance.
- **ISSUE-13**: `DetailedAgendaHtml` should use the repo's existing rich-text component if one exists (grep for `rich-text-editor` / `RichTextEditor` / `react-quill`). Otherwise fall back to `<textarea>` with a `// TODO: rich-text` marker.
- **ISSUE-14**: Audit-column compat — feedback memory says use `createdDate`/`modifiedDate` (not `createdAt`). Verify BE EventResponseDto uses those property names.
- **ISSUE-15 CALENDAR**: Calendar view is a listing variant, not a separate route. Read same EVENTS_QUERY, render custom month grid. Clicking a chip navigates to `?mode=read&id=X` just like a row click. Preserve toolbar/filters.
- **ISSUE-16 RADIO CARD**: No existing radio-card-group component found in repo (during planning). FE Dev may need to create a reusable one (or inline) — escalate if it needs to be a MASTER_GRID-worthy infrastructure component per feedback memory.
- **ISSUE-17 STATUS COLORS**: EventStatus 5-value color palette (amber=DRAFT, purple=PUBLISHED/UPCOMING, green=INPROGRESS, blue=COMPLETED, red=CANCELLED) — seed `ColorHex` on MasterData rows.

### Service Dependencies (UI-only handlers — external service mocked)

Full UI must be built for all of these. Handlers render a toast (`sonner` or equivalent) and log the intended action. Replace with real integration when the named infrastructure lands.

- **⚠ SERVICE_PLACEHOLDER #1 (BannerImageUrl + ShareImageUrl + EventGalleryPhotos upload)**: File-upload service layer unclear. Build upload-area UI; handler currently toasts "File upload coming soon. Paste URL below." and falls back to a URL input.
- **⚠ SERVICE_PLACEHOLDER #2 (Registrants table on dashboard)**: Depends on Event Ticketing #46's `EventRegistration` entity which is not yet built. Full table UI is built; binds to empty-state card with message "Registrant data will appear once Event Ticketing (#46) is built. Data shape: `{ ContactId, EventId, TicketTypeId, Status, CheckedInAt, AmountPaid }`".
- **⚠ SERVICE_PLACEHOLDER #3 (Check-in Mode — QR scanner)**: Camera/QR service not implemented. Full panel UI is built (counter, scanner placeholder, search, recent-feed). Button handler toggles panel; QR "scan" toast-only.
- **⚠ SERVICE_PLACEHOLDER #4 (Send Reminder / Send Communication / Bulk email)**: Depends on notification infrastructure (Email/WhatsApp/SMS send services). Buttons render; handler toasts "Reminder queue pending notification infra wiring."
- **⚠ SERVICE_PLACEHOLDER #5 (Registration Trend chart)**: Real daily registration counts come from #46. Render mini-bars chart with static placeholder data (20 bars with sample values); label as "Sample — real data available after Event Ticketing #46". Switch to GetEventDashboardById response when data exists.
- **⚠ SERVICE_PLACEHOLDER #6 (Post-Event Analytics panel)**: Attendance/Revenue/Follow-up sections depend on #46 + post-event hook. Render UI with `.muted` opacity when Status ≠ COMPLETED; when Status = COMPLETED, show "Data pending Event Ticketing #46 integration."
- **⚠ SERVICE_PLACEHOLDER #7 (Export Registrants / Export List / Duplicate / Archive header actions)**: Exports depend on export-service. Handler toasts "Export queued." (Duplicate is REAL — wired to `duplicateEvent` mutation.)
- **⚠ SERVICE_PLACEHOLDER #8 (Communication Triggers editable matrix in Tab 5)**: Table is read-only display for Session 1. Editing UI deferred — render non-editable table showing default triggers, no save wiring.

Every SERVICE_PLACEHOLDER renders the full UI component with a toast-only handler. Nothing is "hidden" or "removed from scope."

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Planning (2026-04-20) | CRITICAL | BE Schema | `EventName` field missing from entity; mockup requires it | RESOLVED (Session 1) |
| ISSUE-2 | Planning (2026-04-20) | CRITICAL | BE Schema | `EventCode` field missing from entity; mockup requires unique code for display/URL | RESOLVED (Session 1) |
| ISSUE-3 | Planning (2026-04-20) | Low | BE Schema | Typo `PostpondedToDate` → `PostponedToDate` | RESOLVED (Session 1) |
| ISSUE-4 | Planning (2026-04-20) | High | Arch | Event Ticketing #46 dependency — registrants, check-in, ticket-sales-revenue, post-event analytics all SERVICE_PLACEHOLDER | OPEN (awaiting #46) |
| ISSUE-5 | Planning (2026-04-20) | Low | BE Schemas | `OrganizationalEventResponseDto` duplicate — prune if unused | OPEN (deferred — TODO comment in code) |
| ISSUE-6 | Planning (2026-04-20) | Low | BE Schemas | Empty `EventDto` subclass — remove unless HC filtering requires | OPEN (deferred — TODO comment in code) |
| ISSUE-7 | Planning (2026-04-20) | Critical | BE Schema | `RelatedCampaignId` FK missing from entity (exists in FE DTO) | RESOLVED (Session 1) |
| ISSUE-8 | Planning (2026-04-20) | Medium | FE GQL | EVENTS_QUERY missing `relatedCampaign` projection | RESOLVED (Session 1) |
| ISSUE-9 | Planning (2026-04-20) | High | BE Query | `registeredCount`/`eventRevenue`/`waitlistCount` — return 0 with TODO until #46 exists | OPEN |
| ISSUE-10 | Planning (2026-04-20) | Medium | BE Logic | `INPROGRESS` status computed (not persisted) via date-range+Published check | OPEN |
| ISSUE-11 | Planning (2026-04-20) | Medium | FE Form | ConfirmationTemplateId — ApiSelect vs hardcoded fallback | OPEN |
| ISSUE-12 | Planning (2026-04-20) | Medium | FE Form | EventCommunicationTriggers table is read-only for Session 1 | OPEN |
| ISSUE-13 | Planning (2026-04-20) | Medium | FE Form | DetailedAgendaHtml rich-editor — use existing if present, else textarea | OPEN |
| ISSUE-14 | Planning (2026-04-20) | Low | BE Schemas | Audit column naming — verify createdDate/modifiedDate not createdAt | OPEN |
| ISSUE-15 | Planning (2026-04-20) | Medium | FE Index | Calendar view — same query, different render; click chip → read mode | OPEN |
| ISSUE-16 | Planning (2026-04-20) | Medium | FE Infra | Radio-card-group component — may need creation if not in registry | OPEN |
| ISSUE-17 | Planning (2026-04-20) | Low | DB Seed | EventStatus 5-color palette must be seeded on MasterData rows | RESOLVED (Session 1 — DataSetting "bg/fg" per row) |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-04-21 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt — BE (25 files) + FE (26 files + 1 delete + 1 legacy cleanup) + DB Seed.
- **Files touched**:
  - BE (25):
    - `Base.Domain/Models/ApplicationModels/Event.cs` (modified — +33 fields, 6 nav collections, PostpondedToDate→PostponedToDate rename)
    - `Base.Domain/Models/ApplicationModels/EventTicketType.cs` (created)
    - `Base.Domain/Models/ApplicationModels/EventSpeaker.cs` (created)
    - `Base.Domain/Models/ApplicationModels/EventRegistrationFormField.cs` (created)
    - `Base.Domain/Models/ApplicationModels/EventSuggestedAmount.cs` (created)
    - `Base.Domain/Models/ApplicationModels/EventCommunicationTrigger.cs` (created)
    - `Base.Domain/Models/ApplicationModels/EventGalleryPhoto.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventConfiguration.cs` (modified — 33 field configs + 6 HasMany cascades + filtered unique index on (CompanyId, EventCode))
    - `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventTicketTypeConfiguration.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventSpeakerConfiguration.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventRegistrationFormFieldConfiguration.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventSuggestedAmountConfiguration.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventCommunicationTriggerConfiguration.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/EventGalleryPhotoConfiguration.cs` (created)
    - `Base.Application/Schemas/ApplicationSchemas/EventSchemas.cs` (modified — +33 fields on Request + 6 child DTO pairs + EventSummaryDto + EventDashboardDto + RegistrantDto + breakdown DTOs; OrganizationalEventResponseDto / empty EventDto retained with TODO per ISSUE-5/6)
    - `Base.Application/Business/ApplicationBusiness/Events/Commands/CreateEvent.cs` (modified — auto-gen EventCode, seed FULLNAME+EMAIL system form fields, child collection insert, FK validators)
    - `Base.Application/Business/ApplicationBusiness/Events/Commands/UpdateEvent.cs` (modified — 6 child upsert helpers, IsSystem-row protection, status-transition guard)
    - `Base.Application/Business/ApplicationBusiness/Events/Commands/PublishEvent.cs` (created — full publish-validation + status transition)
    - `Base.Application/Business/ApplicationBusiness/Events/Commands/CancelEvent.cs` (created — reason-required + status guard)
    - `Base.Application/Business/ApplicationBusiness/Events/Commands/CompleteEvent.cs` (created)
    - `Base.Application/Business/ApplicationBusiness/Events/Commands/DuplicateEvent.cs` (created — clones parent + 6 children, collision-safe EventCode suffix)
    - `Base.Application/Business/ApplicationBusiness/Events/Queries/GetEvent.cs` (modified — 10-col projection, INPROGRESS computed from PUBLISHED+date-range, advanced filter args)
    - `Base.Application/Business/ApplicationBusiness/Events/Queries/GetEventById.cs` (modified — includes 6 child collections + all FK navs)
    - `Base.Application/Business/ApplicationBusiness/Events/Queries/GetEventSummary.cs` (created — tenant-wide KPIs)
    - `Base.Application/Business/ApplicationBusiness/Events/Queries/GetEventDashboardById.cs` (created — per-event dashboard)
    - `Base.API/EndPoints/Application/Mutations/EventMutations.cs` (modified — +4 workflow resolvers)
    - `Base.API/EndPoints/Application/Queries/EventQueries.cs` (modified — +getEventSummary, +getEventDashboardById)
    - `Base.Infrastructure/Migrations/20260421120000_EventAlignMockup.cs` (created — 33 AddColumn, RenameColumn, AlterColumn VenueName 100→200, 3 new FK+index, filtered unique index, 6 CreateTable for children, SQL backfill for EventName/EventCode)
  - BE wiring (3 modified):
    - `Base.Application/Data/Persistence/IContactDbContext.cs` — +6 DbSet interface members
    - `Base.Infrastructure/Data/Persistence/ContactDbContext.cs` — +6 DbSets (configs auto-applied via `ApplyConfigurationsFromAssembly`)
    - `Base.Application/Mappings/ApplicationMappings.cs` — Event + 6 child Request↔Entity↔Response + summary/dashboard/registrant configs
  - FE (28 — verified/completed in prior prep work; this session finalized routing barrel + deleted legacy data-table.tsx):
    - `src/domain/entities/contact-service/EventDto.ts` (modified — +33 fields, 6 child DTOs, EventSummaryDto, EventDashboardDto, RegistrantDto)
    - `src/infrastructure/gql-queries/contact-queries/EventQuery.ts` (modified — EVENTS_QUERY + EVENT_BY_ID_QUERY extended; +EVENT_SUMMARY_QUERY + EVENT_DASHBOARD_BY_ID_QUERY)
    - `src/infrastructure/gql-mutations/contact-mutations/EventMutation.ts` (modified — CREATE/UPDATE extended; +PUBLISH/CANCEL/COMPLETE/DUPLICATE)
    - `src/presentation/pages/crm/event/event.tsx` (modified — renders `<EventPage />` gated by useAccessCapability)
    - `src/presentation/components/page-components/crm/event/event/index.ts` (modified — barrel exports, legacy EventDataTable export removed)
    - `src/presentation/components/page-components/crm/event/event/event-page.tsx` (created — URL dispatcher)
    - `src/presentation/components/page-components/crm/event/event/index-page.tsx` (created — **Variant B**: ScreenHeader + EventWidgets + list/calendar toggle + FlowDataTableContainer showHeader={false})
    - `src/presentation/components/page-components/crm/event/event/view-page.tsx` (created — new/edit → form, read → dashboard)
    - `src/presentation/components/page-components/crm/event/event/event-form-page.tsx` (created — 5-tab form + FlowFormPageHeader + Save as Draft / Save & Publish + unsaved-changes guard)
    - `src/presentation/components/page-components/crm/event/event/event-dashboard-page.tsx` (created — hero progress + 6 KPI + ticket-type table + trend chart + registrants placeholder + post-event analytics + check-in toggle)
    - `src/presentation/components/page-components/crm/event/event/event-store.ts` (created — Zustand: viewMode, activeTab, checkinModeOpen, statusFilter)
    - `src/presentation/components/page-components/crm/event/event/event-widgets.tsx` (created — 4 KPI cards bound to EVENT_SUMMARY_QUERY)
    - `src/presentation/components/page-components/crm/event/event/event-calendar-view.tsx` (created — month grid)
    - `src/presentation/components/page-components/crm/event/event/event-checkin-panel.tsx` (created — SERVICE_PLACEHOLDER #3)
    - `src/presentation/components/page-components/crm/event/event/event-registrants-table.tsx` (created — SERVICE_PLACEHOLDER #2)
    - `src/presentation/components/page-components/crm/event/event/form-tabs/basic-info-tab.tsx` (created)
    - `src/presentation/components/page-components/crm/event/event/form-tabs/venue-schedule-tab.tsx` (created — conditional Venue/Virtual sections by EventMode)
    - `src/presentation/components/page-components/crm/event/event/form-tabs/registration-tab.tsx` (created — TicketTypes inline grid + RegFormFields checkbox list w/ FULLNAME+EMAIL locked)
    - `src/presentation/components/page-components/crm/event/event/form-tabs/content-speakers-tab.tsx` (created — banner/gallery upload fallback + speakers repeater cards)
    - `src/presentation/components/page-components/crm/event/event/form-tabs/settings-tab.tsx` (created — donations + social preview live + comm triggers read-only)
    - `src/presentation/components/page-components/crm/event/event/form-tabs/fields.tsx` (created — shared form fields helper)
    - `src/presentation/components/page-components/crm/event/event/form-tabs/types.ts` (created)
    - `src/presentation/components/page-components/crm/event/event/form-tabs/use-event-dropdowns.ts` (created — centralized FK ApiSelect data sources)
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/event-name-renderer.tsx` (created)
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/event-mode-badge-renderer.tsx` (created)
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/event-status-badge-renderer.tsx` (created — 5-color pill, token-based)
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/event-venue-renderer.tsx` (created)
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/event-capacity-progress.tsx` (created — green/amber/red threshold)
  - FE wiring (4 modified):
    - `src/presentation/components/custom-components/data-tables/advanced/data-table-column-types/component-column.tsx` — 5 new cases + imports
    - `src/presentation/components/custom-components/data-tables/basic/data-table-column-types/component-column.tsx` — 5 new cases + imports
    - `src/presentation/components/custom-components/data-tables/flow/data-table-column-types/component-column.tsx` — 5 new cases + imports
    - `src/presentation/components/custom-components/data-tables/shared-cell-renderers/index.ts` — 5 new exports
  - FE deleted (2):
    - `src/presentation/components/page-components/crm/event/event/data-table.tsx` (legacy; now unused after event.tsx → <EventPage />)
    - `src/app/[lang]/organization/organizationsetup/event/page.tsx` (legacy duplicate route)
  - DB:
    - `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/Event-sqlscripts.sql` (created — Menu/Caps/RoleCaps for EVENT, MasterData for EVENTCATEGORY (9) / EVENTMODE (3) / EVENTSTATUS (5 with ColorHex), Grid + 10 Fields + 10 GridFields, GridFormSchema=NULL per FLOW; TIMEZONE shared with OrganizationalUnit seed)
- **Deviations from spec**:
  - DbContext wiring routed through `IContactDbContext` + `ContactDbContext` (NOT `IApplicationDbContext`/`ApplicationDbContext` as the §⑧ wiring table stated) — the Event entity already lived in ContactDbContext per repo convention; BE agent followed the existing pattern.
  - DecoratorProperties NOT updated for the 6 new child entities — child CRUD always happens via the parent Event mutation, so the existing `Event = "EVENT"` entry covers permissions.
  - Workflow mutations (publishEvent/cancelEvent/completeEvent/duplicateEvent) are called directly by the dashboard page rather than registered in `contact-service-entity-operations.ts` — the shared `TDataTableOperation` type only supports the 6 standard CRUD keys; extending it would be a cross-cutting refactor outside this screen's scope.
  - ISSUE-5 (`OrganizationalEventResponseDto`) and ISSUE-6 (empty `EventDto`) are retained with `// TODO: prune` comments — defer to future session per prompt §⑫.
- **Known issues opened**: None new — all 17 pre-flagged ISSUEs from planning were addressed or carried forward with documented SERVICE_PLACEHOLDERs.
- **Known issues closed**: ISSUE-1 (EventName added), ISSUE-2 (EventCode added + filtered unique index), ISSUE-3 (PostpondedToDate → PostponedToDate via RenameColumn), ISSUE-7 (RelatedCampaignId FK added), ISSUE-8 (EVENTS_QUERY extended with relatedCampaign), ISSUE-17 (EVENTSTATUS rows carry ColorHex in DataSetting). Remaining ISSUEs (4/9/10/11/12/13/15/16 + 5/6 deferred) tracked via SERVICE_PLACEHOLDERs until #46 Event Ticketing lands.
- **Next step**: User to run (1) `dotnet ef database update` to apply migration `20260421120000_EventAlignMockup`; (2) execute `Event-sqlscripts.sql` in the DB; (3) `pnpm dev` and walk the full E2E per §⑪ (grid + 4 KPI widgets + calendar toggle + 5-tab form create/edit + dashboard read + Publish/Cancel/Duplicate workflows).