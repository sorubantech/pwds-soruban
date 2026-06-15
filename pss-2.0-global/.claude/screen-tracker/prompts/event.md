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
last_session_date: 2026-06-12
revision: "Consolidation (re-planned 2026-06-10) — #40 Event becomes the HOST of a 4-tab screen that ABSORBS #46 Event Ticketing + #169 Event Registration Page as embedded tabs. Final tabs: 1 Basic Info / 2 Venue & Schedule / 3 Ticketing (#46) / 4 Registration Page (#169). The old 'Content & Speakers' tab is FOLDED INTO tab 4 (banner/agenda/speakers/gallery — #169 already owns Branding/Speakers/Gallery cards). PER-TAB Save (no composite mutation): tabs 1-2 save Event; tab 3 = #46 inline CRUD; tab 4 = #169 editor's own Save. Tabs 3 & 4 enabled only after the Event exists (1:1 dependency). #46 + #169 standalone menus seeded IsLeastMenu=false + old routes redirect into the #40 tab (#77/#78/#167 absorption pattern). See §⓪ CONSOLIDATION REVISION (authoritative delta). Status reset COMPLETED→PROMPT_READY for the consolidation build."
---

## ⓪ CONSOLIDATION REVISION (2026-06-10 — AUTHORITATIVE DELTA)

> **This block OVERRIDES the older §②/③/⑥/⑧/⑩/⑪ wherever they conflict.** The original #40 was a 3-tab Event wizard (Basic / Venue / Content & Speakers) after #169 was extracted to its own screen+table. This revision turns #40 into the **HOST of a 4-tab consolidated screen** that absorbs #46 Event Ticketing and #169 Event Registration Page as embedded tabs. Build agents: treat §⓪ as the source of truth for tab structure, save model, embedding mechanics, and wiring. Where §⓪ is silent, the older sections still apply.
>
> **Scope = FE-heavy + thin BE/seed.** No new entities. No new composite mutation. Both absorbed screens are already `eventId`-prop-driven, so this is primarily a host-shell + embed + menu/route reconciliation.

### ⓪.1 Final tab structure (4 tabs)

| Tab | Title | Source | Persists to | Save trigger | Gating |
|-----|-------|--------|-------------|--------------|--------|
| 1 | Basic Info | existing `BasicInfoTab` | `app.Events` (Event mutation) | host sticky-footer **Save as Draft / Save & Publish** | always |
| 2 | Venue & Schedule | existing `VenueScheduleTab` | `app.Events` (Event mutation) | host sticky-footer (shared with tab 1) | always |
| 3 | Ticketing | **#46 embedded** (`EventTicketingContent` cards) | `app.EventTickets` etc. via #46's own mutations | #46 inline per-card CRUD (Add/Edit/Save inside the cards) | **enabled only after Event exists** (`!isAdd && recordId > 0`) |
| 4 | Registration Page | **#169 editor embedded** (`EventRegistrationPageEditorPage`) — **absorbs old Content & Speakers** | `app.EventRegistrationPages` + Event child collections via `updateEventRegistrationPageSetup` | #169 editor's **own Save** (surfaced inside the tab) | **enabled only after Event exists** |

- The old **Content & Speakers tab is REMOVED** as a standalone tab. Its four concerns (banner image, detailed agenda HTML, speakers[], galleryPhotos[]) move into **tab 4**: #169 already renders Card 8 (Branding & banner), Card 10 (Speakers), Card 11 (Gallery) over the **same Event child collections**. The only field with no #169 home is **`detailedAgendaHtml`** — add it to the #169 editor (new small card "Event Agenda" OR a field on the Branding card). See §⓪.5 reconciliation.

### ⓪.2 Save model — PER-TAB (user-locked, no composite mutation)

- **Tabs 1–2 (Event):** keep the existing host sticky-footer **Save as Draft / Save & Publish** + validation summary + dirty guard. These persist the Event via `CREATE_EVENT_MUTATION` / `UPDATE_EVENT_MUTATION` exactly as today.
- **Tab 3 (#46):** uses #46's existing inline CRUD — each card saves itself through #46's mutations. No host Save involved.
- **Tab 4 (#169):** uses the #169 editor's existing `updateEventRegistrationPageSetup` flow with its own Save button. No host Save involved.
- **Host sticky footer visibility:** show the Event Save/Publish footer **only on tabs 1–2**. On tabs 3–4 hide it (the embedded screens own their saves) to avoid two competing Save buttons. The footer's `readOnly`/`canSave` logic stays unchanged for tabs 1–2.
- **Dirty tracking:** the host's `isDirty` (Event form) and the #169 store's independent `dirtyFields` set are **separate**. Each tab's unsaved-changes state is owned by that tab. The host unsaved-changes dialog should only consider Event-form dirtiness (tabs 1–2). The #169 editor's own `beforeunload` guard must be **suppressed when embedded** (see ⓪.4) so it doesn't fire for the whole host page.

### ⓪.3 Tab gating — Event-exists dependency (1:1)

- #46 and #169 are both keyed by `eventId` and are **1:1 on an existing Event**. In **add mode** (no `recordId` yet) tabs 3 & 4 cannot load.
- Render tabs 3 & 4 as **disabled** (greyed step circle, not clickable) while `isAdd || !recordId`. Show an inline empty-state inside each: *"Save the event first to configure ticketing / the registration page."*
- After the first successful create, the host already switches the URL to `?mode=edit&id={newId}` (see [event-form-page.tsx:508-511](../../PSS_2.0_Frontend/src/presentation/components/page-components/crm/event/event/event-form-page.tsx#L508-L511)) — tabs 3 & 4 become enabled immediately, no reload.

### ⓪.4 FE embedding mechanics (both screens are already `eventId`-prop-driven)

**#46 Event Ticketing → Tab 3:**
- Component: `EventTicketingContent` is currently **internal** to `…/crm/event/eventticketing/index.tsx`. **Export it** (or add a thin `EventTicketingTab({ eventId }: { eventId: number })` wrapper in the same folder) that calls `useEventTicketingStore().setSelectedEventId(eventId)` on mount and renders the card grid directly.
- **Drop** the event-selector `<Select>` in `headerActions` and the `?eventId=` URL-sync `useEffect` ([index.tsx:77-118](../../PSS_2.0_Frontend/src/presentation/components/page-components/crm/event/event/eventticketing/index.tsx)) — `eventId` comes from the host form, not the URL.
- All 5 cards (`SummaryBar`, `TicketTypesCard`, `TicketFormCard`, `RegistrantsCard`, `PublicPreviewCard`) already accept `eventId` as a plain prop — re-compose them inside the tab.
- Reset the singleton `useEventTicketingStore` on mount/unmount (`reset()`) so a previously-open event's inline-form state doesn't leak.

**#169 Reg Page editor → Tab 4:**
- Component: `EventRegistrationPageEditorPage` **already takes `eventId: number` as a prop** ([editor-page.tsx:74-76](../../PSS_2.0_Frontend/src/presentation/components/page-components/setting/publicpages/eventregpage/editor-page.tsx#L74-L76)). Render `<EventRegistrationPageEditorPage eventId={recordId} />` directly in the tab.
- Add an `embedded?: boolean` prop to the editor. When `embedded`:
  - **hide** its top "Back" button and the standalone page chrome,
  - **suppress** the `beforeunload` guard ([editor-page.tsx:378-386](../../PSS_2.0_Frontend/src/presentation/components/page-components/setting/publicpages/eventregpage/editor-page.tsx#L378-L386)),
  - keep its **Save** button (it's the tab-4 save), but render it inline within the tab body, and
  - make its archive/lifecycle actions that call `router.push(…eventregpage)` no-op or stay-in-tab.
- The editor self-loads via `GetEventRegistrationPageById($eventId)` — no extra plumbing.

**Host (`event-form-page.tsx`):**
- Extend `EVENT_STEPS` from 3 → 4 entries: keep `1 Basic Info`, `2 Venue & Schedule`; replace old `3 Content & Speakers` with `3 Ticketing` and add `4 Registration Page`. Update the `EventStepId` type, `FIELD_TAB` map, `isStepComplete`, and `stepHasErrors` accordingly (tabs 3 & 4 have no host-validated fields — they self-validate).
- Add `<TabsContent value="3">` → Ticketing tab; `<TabsContent value="4">` → Reg Page tab. Both wrapped in the Event-exists gate.
- Step navigator (the numbered circle stepper) renders 4 steps; tabs 3 & 4 show a lock/disabled state until the Event exists.

### ⓪.5 Field-ownership reconciliation (Event mutation vs #169 setup mutation)

Because tab 4 now owns banner/agenda/speakers/gallery, prevent **double-write conflicts**:
- The Event `buildPayload` ([event-form-page.tsx:395-470](../../PSS_2.0_Frontend/src/presentation/components/page-components/crm/event/event/event-form-page.tsx#L395-L470)) currently sends `speakers`, `galleryPhotos`, `bannerImageUrl`, `detailedAgendaHtml`. After consolidation these are **edited in tab 4** via `updateEventRegistrationPageSetup` (which already reuses `UpsertSpeakers`/`UpsertGalleryPhotos` from `UpdateEvent.cs`). **Stop sending `speakers`/`galleryPhotos` from the Event form's tabs-1-2 Save** (remove from `buildPayload`, or send them unchanged-as-loaded so they're not wiped). Decision for Solution Resolver: cleanest = drop them from the host payload entirely so tab 4 is the single writer.
- `bannerImageUrl`: #169 Card 8 already edits the page banner. Confirm whether banner lives on `app.Events.BannerImageUrl` or `app.EventRegistrationPages` — if the former, route the tab-4 banner edit through the setup mutation (it already upserts Event fields) and drop it from the host payload.
- `detailedAgendaHtml`: lives on `app.Events`. Add it to the #169 setup input + `UpdateEventRegistrationPageSetup` handler so tab 4 persists it, then drop it from the host payload. (Thin BE delta: 1 DTO field + 1 input field + 1 handler line + Mapster.)
- Net BE work: small — extend `EventRegistrationPageSetupInput`/`…SetupDto` + handler with `detailedAgendaHtml` (and banner if Event-owned); no new entity, no new mutation.

### ⓪.6 Menu / route reconciliation (HIDE + redirect — #77/#78/#167 pattern)

- **Hide standalone menus:** in the seed scripts set `IsLeastMenu=false` on the `EVENTTICKET` menu ([EventTicketing-sqlscripts.sql](../../PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/EventTicketing-sqlscripts.sql)) and the `EVENTREGPAGE` menu ([event-reg-page-sqlscripts.sql](../../PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/event-reg-page-sqlscripts.sql)). They disappear from the sidebar but their **MenuCapabilities + BUSINESSADMIN role grants stay** (capability cascade preserved). Idempotent `UPDATE … WHERE MenuCode IN ('EVENTTICKET','EVENTREGPAGE')`.
- **Redirect old routes into the host tab** (preserve bookmarked/legacy URLs):
  - `crm/event/eventticketing/page.tsx` (`?eventId=X`) → redirect to `crm/event/event?mode=edit&id=X&tab=3` (or list if no eventId).
  - `setting/publicpages/eventregpage/page.tsx` (`?id=X` = eventId) → redirect to `crm/event/event?mode=edit&id=X&tab=4` (or list if no id).
  - Implement as a thin client redirect in each `page.tsx` (read the param, `router.replace(...)`). Keep the original components on disk (still imported by the host tabs).
- **Host deep-link:** the host should read a `?tab=` query param on mount and set `activeTab` so the redirects land on the right tab. Add `tab` to the existing `?mode=&id=` URL handling in `event-form-page.tsx`.
- **Capability gates inside the tabs:** #46 gates on `menuCode:"EVENTTICKET"`, #169 on `menuCode:"EVENTREGPAGE"` — keep those `useAccessCapability` checks so a BUSINESSADMIN without the absorbed capability sees the tab disabled. (Cascade seeding keeps BUSINESSADMIN granted.)

### ⓪.7 File manifest (consolidation)

**FE — MODIFY (host):**
- `…/crm/event/event/event-form-page.tsx` — 3→4 tabs, gating, `?tab=` handling, per-tab footer visibility, drop speakers/gallery/banner/agenda from `buildPayload`.
- `…/crm/event/event/form-tabs/index.ts` + `types.ts` — export the 4-tab set; old `ContentSpeakersTab` retired from the wizard (component may be reused inside tab 4 for agenda, or deleted).

**FE — MODIFY (absorbed #46):**
- `…/crm/event/eventticketing/index.tsx` — export `EventTicketingContent` or add `EventTicketingTab({eventId})` wrapper; remove selector + URL-sync when embedded.
- `…/crm/event/eventticketing/eventticketing-store.ts` — ensure `reset()` exists for mount/unmount.
- `src/app/[lang]/crm/event/eventticketing/page.tsx` — redirect stub.

**FE — MODIFY (absorbed #169):**
- `…/setting/publicpages/eventregpage/editor-page.tsx` — add `embedded?` prop (hide back/chrome, suppress beforeunload, inline Save), add **Event Agenda** card/field, persist `detailedAgendaHtml` (+ banner if Event-owned) via setup input.
- `…/setting/publicpages/eventregpage/cards/` — optional new `agenda` card OR field on `8-branding-seo-card.tsx`.
- `src/app/[lang]/setting/publicpages/eventregpage/page.tsx` — redirect stub.
- `EventRegistrationPageDto.ts` + `EventRegistrationPageQuery.ts` + `EventRegistrationPageMutation.ts` — add `detailedAgendaHtml` (+ banner) to setup DTO/input + GetById selection.

**BE — MODIFY (thin):**
- `EventRegistrationPageSchemas.cs` — `+detailedAgendaHtml` on SetupDto + SetupInput (+ banner if Event-owned).
- `UpdateEventRegistrationPageSetup.cs` — persist `detailedAgendaHtml` onto the Event row (reuses the existing Event-field upsert path).
- `GetEventRegistrationPageById.cs` — project `detailedAgendaHtml`.
- Mapster (`ApplicationMappings.cs`) — if a new field needs an explicit map.

**DB seed — MODIFY:**
- `EventTicketing-sqlscripts.sql` — `UPDATE … IsLeastMenu=false WHERE MenuCode='EVENTTICKET'`.
- `event-reg-page-sqlscripts.sql` — `UPDATE … IsLeastMenu=false WHERE MenuCode='EVENTREGPAGE'`.

**Migration:** none required (no new columns) unless banner ownership forces one — `detailedAgendaHtml` already exists on `app.Events`.

### ⓪.8 Acceptance criteria (consolidation)

- [ ] Host Event screen shows **4 tabs**: Basic Info / Venue & Schedule / Ticketing / Registration Page.
- [ ] In **add mode**, tabs 3 & 4 are disabled with a "Save the event first" empty-state; tabs 1–2 work.
- [ ] After creating an Event (Save as Draft), tabs 3 & 4 become enabled in place (URL flips to `?mode=edit&id=…`).
- [ ] **Tab 3** renders the #46 ticketing cards for the host event (no selector dropdown); Add/Edit/Delete ticket works and refreshes inline.
- [ ] **Tab 4** renders the #169 editor for the host event; its own Save persists; banner/speakers/gallery/**agenda** edit and save here.
- [ ] Host **Save as Draft / Save & Publish** footer is visible only on tabs 1–2; hidden on tabs 3–4.
- [ ] Saving the Event on tabs 1–2 does **not** wipe speakers/gallery/banner/agenda (single-writer = tab 4).
- [ ] Old route `crm/event/eventticketing?eventId=X` **redirects** to `…/event?mode=edit&id=X&tab=3`.
- [ ] Old route `setting/publicpages/eventregpage?id=X` **redirects** to `…/event?mode=edit&id=X&tab=4`.
- [ ] `EVENTTICKET` and `EVENTREGPAGE` menus **no longer appear in the sidebar** but BUSINESSADMIN still has their capabilities (cascade intact).
- [ ] No regression: tabs 1–2 validation summary, dirty guard, publish flow unchanged.
- [ ] FE `npx tsc --noEmit` clean; BE `dotnet build` PASS.

### ⓪.9 Open issues / risks (consolidation)

- **CR-ISSUE-1** — Singleton Zustand stores (`useEventTicketingStore`, `useEventRegistrationPageStore`) are global; mounting them in host tabs requires mount/unmount `reset()`/`hydrate()` discipline so switching between events (or host↔tab) doesn't leak state. Verify on event-switch.
- **CR-ISSUE-2** — Banner ownership ambiguity: confirm whether `BannerImageUrl` is on `app.Events` or `app.EventRegistrationPages` before deciding the single writer (drives whether a tiny BE/migration touch is needed). Resolver verifies in entity before build.
- **CR-ISSUE-3** — `detailedAgendaHtml` relocation: it stays on `app.Events`; tab 4 writes it through the setup mutation's Event-field upsert. Confirm `UpdateEventRegistrationPageSetup` already touches the Event row (it does for speakers/gallery) so no new write path is needed.
- **CR-ISSUE-4** — Two independent dirty/`beforeunload` guards (host Event form + #169 editor). The embedded `#169` guard MUST be suppressed or the whole host page double-prompts. Covered by the `embedded` prop (⓪.4).
- **CR-ISSUE-5** — #46 capability menuCode is `EVENTTICKET` (not `EVENTTICKETING`); #169 has **no** entity-operations block (custom editor, gated only via `useAccessCapability("EVENTREGPAGE")`). Keep both gate keys when embedding.
- **CR-ISSUE-6** — `?tab=` deep-link + redirect ordering: the host must apply `?tab=` AFTER the record loads, else the gate flips the user back to tab 1. Set `activeTab` from `?tab=` once `loadingRecord` resolves.

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
| ISSUE-18 | Build (2026-06-10) | Low | FE Cleanup | `form-tabs/content-speakers-tab.tsx` is now dead (retired from the wizard by the consolidation; banner/agenda/speakers/gallery live in Tab 4 / #169). Still on disk + exported by the `form-tabs/index.ts` barrel but imported by nothing. Delete in a future cleanup pass. | OPEN |
| ISSUE-19 | Build (2026-06-10) | Low | Arch | Two-writer overlap on `ShowCountdown`: editable both in host Tab 2 (Schedule) and Tab 4 / #169 RegistrantExperienceCard. Last-save-wins on a single bool; harmless. Host `MapRegistrationPage` deliberately still writes `ShowCountdown` + `SendLinkTimingCode` (the only two page fields the host tabs own); everything else on the page row is single-written by Tab 4. | CLOSED (session 11) |

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

### Session 2 — 2026-06-02 — UI — COMPLETED

- **Scope**: Replace the hand-rolled per-screen `EventDataTable` (custom TanStack table) on the index list view with the shared **FlowDataTableContainer** (canonical FlowGrid), per the "reuse existing grids — never fork" convention. Reference screen: `allcontacts` (`crm/contact/contact/index-page.tsx`). Modes (add/read/edit/delete/toggle) now come from the shared grid + existing `EventPage` dispatcher.
- **Files touched**:
  - BE: None.
  - FE:
    - `src/presentation/components/page-components/crm/event/event/index-page.tsx` (rewritten — now uses `FlowDataTableStoreProvider` + `useFlowInitializeColumns()` + `useFlowInitializeData()` + `<FlowDataTableContainer showHeader={false} />`. Status-chip selection is converted to a `TAdvanceFilter` (`eventStatusCode = <chip>`) and pushed to the flow store via `initialAdvancedFilter` (Provider seed) + JSON-deduped `setAdvanceFilter`/`setPageIndex` sync — mirrors the contact pattern. KPI widgets, status chips, and list/calendar toggle preserved unchanged.)
    - `src/presentation/components/page-components/crm/event/event/event-data-table.tsx` (**deleted** via `git rm` — the dead hand-rolled grid; no remaining references; barrel never exported it).
  - DB: None.
- **Deviations from spec**:
  - Grid columns are now DB-driven from the seeded EVENT grid config (Grid + 10 GridFields from Session 1) and rendered through the registered cell renderers (event-name / event-mode-badge / event-status-badge / event-venue / event-capacity-progress), instead of the inline `ColumnDef[]` the custom table hard-coded.
  - **Row-click destination simplified**: the old custom table sent DRAFT rows → `?mode=edit` and others → `?mode=read` (`decideRowClickMode`). The shared grid uses per-row action buttons (View/Edit/Delete/Toggle) + the `+New Event` button, all navigating via `?mode=...&id=` (Add→new, View→read, Edit→edit). Draft rows are edited via the row Edit action rather than a status-conditional row click. Behaviour is standard-grid-consistent; no functional capability lost.
- **Known issues opened**: None.
- **Known issues closed**: None (this is a UI refactor; the OPEN SERVICE_PLACEHOLDER issues are unaffected). Note: ISSUE-15 (calendar view) and the KPI widgets are untouched and still functional.
- **Verification**: `npx tsc --noEmit` — 0 errors across `components/page-components/crm/event/**`. Runtime E2E (grid load via seeded EVENT config, chip filter refetch, add/view/edit/delete navigation) to be confirmed by user with `pnpm dev` (requires the Session-1 migration + `Event-sqlscripts.sql` already applied so the EVENT grid config + GridFields exist).
- **Next step**: COMPLETED. If the grid renders empty columns at runtime, confirm `Event-sqlscripts.sql` (Grid + 10 GridFields) has been seeded — the shared FlowGrid reads columns from that config, unlike the old hard-coded table.

### Session 3 — 2026-06-03 — ENHANCEMENT — Org-unit hierarchy (Parent Org Unit)

- **Scope**: Repurpose the Event form's "Organizational Unit" field into a nullable **"Parent Org Unit"** picker and make each Event a node in the `app.OrganizationalUnits` recursive tree. On create, the BE auto-creates the event's own org-unit node (UnitType = `EVENT`) and sets `Event.OrganizationalUnitId` to it; the form-selected parent flows into that node's `ParentUnitId`. (User clarifications: 3 unit types `EVENT`/`CAMPAIGN`/`DONATIONPURPOSE` already exist in the runtime DB; **Event-only** scope this session; keep the 1..4 `HierarchyLevel` check constraint; on delete/deactivate — block when the node has active children, else soft-delete both event + node.)
- **Model**: `Event.OrganizationalUnitId` stays **required** (own node). The repurposed form field maps to the new DTO field `ParentOrganizationalUnitId` (nullable). Response keeps `organizationalUnit` (own node); edit pre-fills the field from `organizationalUnit.parentUnitId`.
- **Files touched**:
  - BE:
    - `EventSchemas.cs` — `EventRequestDto.OrganizationalUnitId` `int`→`int?` (server-managed) + new `ParentOrganizationalUnitId int?`. (`OrganizationalEventResponseDto` left unchanged.)
    - `CreateEvent.cs` — validator: drop OrganizationalUnitId FK check, add nullable `ParentOrganizationalUnitId` FK check. Handler: new `BuildOwnOrganizationalUnitAsync` resolves the `EVENT` UNITTYPE master-data id, validates parent (company-scoped, not deleted) + depth (≤4), builds the own node (UnitName = EventName≤100, UnitCode = EventCode), attaches via `newEvent.OrganizationalUnit` so EF inserts node→event in one SaveChanges.
    - `UpdateEvent.cs` — validator swap (same). `MapScalars` no longer overwrites `OrganizationalUnitId`. New `SyncOwnOrganizationalUnitAsync` re-parents the existing node (cycle guard walks ancestor chain; depth ≤4; keeps UnitName in sync); lazily creates a node for legacy events that lack one.
    - `DeleteEvent.cs` — block with a clear message when the node has active child units ("already mapped"); otherwise soft-delete **both** event and node (`IsActive=false, IsDeleted=true`). (Previously only set `IsDeleted=true` on the event.)
    - `ToggleEvent.cs` — block **deactivation** when the node has active children (mirrors delete).
  - DB seed:
    - `Event-sqlscripts.sql` — new idempotent STEP 9c seeds UNITTYPE master-data `EVENT`/`CAMPAIGN`/`DONATIONPURPOSE` (`WHERE NOT EXISTS`; no-op if already present). Requires the `UNITTYPE` MasterDataType (from `OrganizationalUnit-sqlscripts.sql`).
  - FE:
    - `EventDto.ts` — `organizationalUnitId?` now optional/nullable + new `parentOrganizationalUnitId?`.
    - `EventQuery.ts` — `EVENT_BY_ID_QUERY` `organizationalUnit { … parentUnitId }` (for edit pre-fill).
    - `basic-info-tab.tsx` — field relabelled "Parent Org Unit", `required` dropped, hint added, clearable.
    - `event-form-page.tsx` — removed `organizationalUnitId` from required/step-complete/`buildErrors`; edit pre-fill reads `rec.organizationalUnit?.parentUnitId`; `buildPayload` sends `parentOrganizationalUnitId` (omits server-managed `organizationalUnitId`).
- **Assumption to confirm**: the EVENT unit-type `DataValue` is **`'EVENT'`** (under `MasterDataType.TypeCode='UNITTYPE'`). The handler resolves by this string and the new seed defines it. If your existing rows use a different DataValue, tell me and I'll adjust both ends.
- **Side effect (noted, not changed)**: the grid column `EVENT_ORGANIZATIONALUNIT` shows the own node's `unitName` (= event name), now somewhat redundant with the Name column. Left as-is; can be re-pointed to the parent's name if desired.
- **Migration note**: no schema change (entity `OrganizationalUnitId` stays non-nullable). Re-run `Event-sqlscripts.sql` to seed the unit types (no-op if present). Legacy events without an own node get one lazily created on their next Update.
- **Verification**: BE `dotnet build Base.Application` → **0 errors** (pre-existing warnings only). FE `npx tsc --noEmit` → **0 errors**. Runtime (create nests under selected parent; edit re-parents; delete/deactivate guard) to be confirmed by user with `pnpm dev`.

### Session 4 — 2026-06-03 — FIX — Event Status = system-managed + parent-picker scope (FE only)

- **Event Status is no longer a manual field.** It was a *required dropdown*; now it's a **read-only colored badge** that reflects the lifecycle: DRAFT on create → advanced only by actions (Publish / Complete / Cancel). The colored background is the dynamic indicator, not an editable input.
  - `basic-info-tab.tsx` — replaced the "Event Status" `SelectField` with a read-only badge (`STATUS_BADGE`/`STATUS_LABEL` maps mirroring the index-page chip colors; code via `statusCodeById`, default DRAFT). Destructure swapped `statuses` → `statusCodeById`.
  - `event-form-page.tsx` — removed `eventStatusId` from `requiredFields`/`errorKeys`/`isStepComplete`/`buildErrors`. `buildPayload` now `statusOverride || form.eventStatusId || DRAFT` (`||` not `??`, since a new event's id is `0`) → new events persist as DRAFT; edits preserve the loaded status; lifecycle actions still pass `statusOverride`.
- **Parent-picker scope fix** (`use-event-dropdowns.ts`) — `orgUnits` was hard-filtered to `unitType === 'SU'` (old geographic model), so the new Parent Org Unit picker showed **no** Event/Campaign/DonationPurpose nodes. Broadened to those three types; labels now suffixed with the type, e.g. `Annual Gala (Event)`.
- **Verification**: FE `npx tsc --noEmit` → **0 errors**. BE untouched (the Create/Update validators already required a valid `EventStatusId`, which the DRAFT default satisfies).

### Session 5 — 2026-06-04 — FIX — Tenant currency + full-width on the read-mode view (FE only)

- **Scope**: NEW bug (not in pre-flagged Known Issues). The read-mode **view page** (`event-dashboard-page.tsx`, rendered by `view-page.tsx` when `crudMode === "read"`) hardcoded a `$` symbol for all monetary values and constrained its content to a centered `max-w-7xl` column instead of filling the canvas like the form/index pages.
- **Files touched**:
  - BE: None.
  - DB: None.
  - FE:
    - `event-dashboard-page.tsx` — (1) the local `formatCurrency(n)` helper (hardcoded `$` + K/M scaling) now delegates to the canonical `formatCompactCurrency` from `@/presentation/utils/companySettingsFormatters`, which reads the tenant's company-session currency (`baseCurrencyCode` + `currencyDisplayFormat`) and honors Indian L/Cr grouping. All ~10 call sites (ticket sold amount, avg ticket price, donations pledged, post-event donations, ticket-type Price/Revenue cells, revenue-summary ticket/donations/auction/total) inherit the company currency with **no call-site changes** — same name/signature preserved. Reference precedent: `event-widgets.tsx` already used `formatCompactCurrency` on this same screen. (2) Content wrapper `mx-auto max-w-7xl` → `w-full max-w-full`, matching `event-form-page.tsx` (line 602) and `index-page.tsx` (line 193). The empty-state / loading / check-in-panel containers were left centered (intentional).
- **Deviations from spec**: None. (§⑥ blueprint is currency-agnostic; this aligns the read view with the tenant currency-formatting convention already used elsewhere.)
- **Known issues opened**: None. (Noted, not fixed: the **form** tabs `settings-tab.tsx` suggested-amount pills and `registration-tab.tsx` ticket prices still render a literal `$` prefix in input adornments — left as-is to keep this session's surface to the read-mode view the user pointed at; can be folded into a follow-up if desired.)
- **Known issues closed**: None (this is a NEW bug fix outside the pre-flagged ISSUE table).
- **Verification**: FE `npx tsc --noEmit` → **0 errors** in `event-dashboard-page.tsx` + `companySettingsFormatters`. Runtime (open any event in read mode → amounts show the org currency symbol/code per CompanySettings, dashboard spans full width) to be confirmed by user with `pnpm dev`. Requires the CompanySettings session store (#75) to be populated — it already drives the KPI widget currency on the index page.

### Session 6 — 2026-06-04 — UI — Read-view actions alignment + solid icon/badge treatment (FE only)

- **Scope**: Two UI polish requests on the read-mode **view page** (`event-dashboard-page.tsx`): (1) the secondary action row (Publish / Send Reminder / Check-in Mode / More) rendered left-aligned under the page header — move it to the right end; (2) apply the app-wide [[solid-icon-bg-white-foreground]] convention to the icon/badge areas (accent = SOLID background, icon/text WHITE).
- **Files touched**:
  - BE / DB: None.
  - FE:
    - `event-dashboard-page.tsx` —
      - `headerActions` wrapper `flex items-center gap-2` → `flex w-full items-center justify-end gap-2` so the action buttons sit at the right end of the header's children row (PageHeader renders `children` in a full-width `mt-2` row).
      - `ACCENT_CLASSES` (6 KPI-card icon chips: teal/emerald/blue/purple/amber/pink) — `iconBg` light tint (`bg-*-100 dark:bg-*-900/30`) → **solid** (`bg-*-600`, amber `bg-*-500`); `iconColor` (`text-*-700 dark:text-*-300`) → `text-white`.
      - `STATUS_CONFIG` (5 lifecycle status badges: DRAFT/PUBLISHED/INPROGRESS/COMPLETED/CANCELLED) — `pill` light tint → **full solid pill** (`bg-*-500/600 text-white`); `dot` → `bg-white` so it reads on the solid pill.
- **Deviations from spec**: None. (Aligns the read view with the [[solid-icon-bg-white-foreground]] convention already mandated for KPI icons + status/mode badges app-wide.)
- **Note (not changed)**: the index-page status chips (`index-page.tsx`) still use the older tinted palette referenced by Session 4; this session only touched the read-mode dashboard the user pointed at. The neutral/muted mode + date + countdown chips were left as informational (non-accent) chips. The "More actions" dropdown menu-item icons stay `text-muted-foreground` (menu rows, not badge/icon chips).
- **Known issues opened / closed**: None.
- **Verification**: FE `npx tsc --noEmit` → **0 errors** in `event-dashboard-page.tsx`. Visual confirmation (actions right-aligned; KPI icon chips + status badge render solid with white glyphs) pending user `pnpm dev`.
- **Follow-up (same session)**: extended the solid-status treatment to the **calendar view** (`event-calendar-view.tsx`) — the per-day event chips' `STATUS_CHIP` map (DRAFT/PUBLISHED/UPCOMING/INPROGRESS/COMPLETED/CANCELLED) went from tinted (`bg-*-100 text-*-800`) to **full solid** (`bg-amber-500`/`bg-*-600` + `text-white`), matching the dashboard `STATUS_CONFIG` colors. The toolbar legend dots were already solid `bg-*-500` and left unchanged. `npx tsc --noEmit` → 0 errors.
- **Calendar premium UI polish (same session)** (`event-calendar-view.tsx`, presentation-only — no logic/query changes): outer container `rounded-lg`→`rounded-xl` + `shadow-sm`; toolbar gets a gradient bar + a **segmented prev/next navigator** (bordered pill, replaces two outline buttons), larger `text-base` month title, Today button gains a crosshair icon; legend dots enlarged with soft ring halos and solid `-600/-500` colors. Weekday header: bolder uppercase `tracking-widest`, weekend columns (Sun/Sat) dimmed. Day cells: min-height `96px`→`112px`, right border removed on every 7th cell (`[&:nth-child(7n)]:border-r-0`), subtle weekend tint, `hover:bg-primary/[0.04]`, **today** cell highlighted via inset primary ring + tint, date number rendered as a rounded badge (solid primary for today), per-day event **count badge** revealed on cell hover. Event chips: `rounded-md` with `shadow-sm` + hover lift (`-translate-y-px`, `shadow-md`, `brightness-110`). Skeletons updated to match. `npx tsc --noEmit` → 0 errors.

### Session 7 — 2026-06-04 — UI — Uniform form fields on the Ticket Type form (FE only)

- **Scope**: Make every input on the **Add/Edit/Duplicate Ticket Type** form (`eventticketing/ticket-form-card.tsx`) use the app-wide canonical form-field components, matching the Contact-create form reference, per [[reuse-canonical-form-fields]]. The form previously hand-rolled each field with raw `Input`/`Select`/`Textarea` primitives wrapped in local `SectionLabel` + `FieldError` helpers + per-field `Controller`s.
- **Files touched**:
  - BE / DB: None.
  - FE:
    - `eventticketing/ticket-form-card.tsx` —
      - Imports: dropped `Input`/`Label`/`Select*`/`Textarea` from `common-components` (kept `Button`/`Skeleton`/`Switch`); added `FormDatePicker`/`FormInput`/`FormSelect`/`FormTextarea` (+ `SelectOption` type) from `@/presentation/components/custom-components/form-fields`.
      - Removed the local `SectionLabel` and `FieldError` helpers (the canonical components render their own label + RHF error text) and dropped the now-unused `errors` from `formState`.
      - Added three `useMemo` `SelectOption[]` adapters: `pricingTypeOptions` / `visibilityOptions` (MasterData → `{value: masterDataId, label: dataName}`) and `currencyOptions` (`{value: currencyId, label: "CODE — Name"}`).
      - Field conversions (all RHF `control`-bound, so field names + zod schema unchanged): Ticket Name → `FormInput`; Pricing Type / Currency / Visibility → `FormSelect` (searchable, `loading` wired to each query); Description → `FormTextarea`; Price / Group Size / Qty Available / Min·Max Per Order → `FormInput type="number"`; **Sale Start/End Date** → `FormDatePicker` (replaces native `type="date"` inputs). The discount toggle stays a `Switch` (no canonical FormSwitch exists); the conditional Discount Code input is now a label-less `FormInput`.
      - Schema: `saleStartDate`/`saleEndDate` gained `.nullable()` (the `FormDatePicker` emits `null` on clear; `onSubmit` + the cross-field refines already treat falsy as "no date", and `dateFormat="yyyy-MM-dd"` matches the existing `.slice(0,10)` prefill + ISO writeback).
- **Deviations from spec**: None. Field set, labels, validation, and the create/update payload are unchanged — this is a component-uniformity refactor only.
- **Known issues opened / closed**: None.
- **Runtime fix (same session)**: "Add Ticket" click threw `Cannot destructure property 'getFieldState' of useFormContext(...) as it is null`. The canonical `FormLabel`/`FormControl`/`FormItem` read `useFormContext()` via `useFormField`, which is `null` without a `FormProvider`. The old bare `Controller` fields didn't need one; the `Form*` components do. Fix: captured the full `useForm()` return as `form` (still destructuring `control`/`handleSubmit`/etc. from it) and wrapped the `<form>` element in `<Form {...form}>` (the `FormProvider` re-export from `common-components`), mirroring the Contact reference (`parent-form.tsx:665`).
- **Verification**: FE `npx tsc --noEmit` → **0 errors** in `ticket-form-card.tsx`. Runtime (open an event → Tickets → Add/Edit ticket; form renders, dropdowns searchable, date pickers open calendars, save round-trips) to be confirmed by user with `pnpm dev`.

#### Follow-up enhancements (same session — all FE, `ticket-form-card.tsx`)

- **Helper text on confusing fields**: added `helperText` to Pricing Type, Qty Available, Min/Max Per Order, Visibility, and the Sale Start/End dates so staff understand each field's purpose. Clear/obvious fields (Ticket Name, Description, Price) left without helper text to avoid noise.
- **Dynamic Group Size label**: the conditional Group Size field now relabels per pricing type — **"Group Size (Table)"** (helper "Seats per table…", placeholder "e.g., 10 seats") when `PER_TABLE`, **"Group Size (Group)"** (helper "People per group…", placeholder "e.g., 5 people") when `PER_GROUP`. Computed via `isPerTable`/`groupSizeLabel`/`groupSizeHelper`/`groupSizePlaceholder` right after `needsGroupSize`.
- **Currency locked to org base currency (#75)**: removed the `CURRENCIES_QUERY` dropdown entirely. Currency now reads from the **company session settings store** (`useCompanySettingsSession` → `baseCurrencyId` / `baseCurrencyCode` / `baseCurrencyName`); `currencyOptions` is a single derived option (`"CODE — Name"`) so the disabled select always displays it (the earlier "value not displayed" bug was the async currencies list not resolving the label). The `<FormSelect name="currencyId">` is now `disabled` with helper "Set by your organization's base currency — applies to all tickets." `currencyId` is seeded to `baseCurrencyId` on add **and** edit/duplicate prefill (`baseCurrencyId || t.currencyId`), so every ticket bills in the tenant currency. Payload unchanged (`currencyId`).
- **Sale-window validation against event start (UX)**: the zod schema is now built per-event via `buildTicketSchema(eventBounds)` (base object `ticketBaseSchema` + `.refine()` chain; `TicketFormData` inferred from the base). The form fetches the event via `EVENT_BY_ID_QUERY` (`cache-first`) to derive `eventBounds = { startMs, startLabel }` (tenant-formatted via `formatDate`), `useMemo`'d into the resolver — RHF 7.72 reassigns `control._options` each render so the rebuilt resolver takes effect once the event loads. New rules + inline messages: **Sale Start** must be before the event start (`Sales must open before the event starts (<date>)`); **Sale End** must be before the event start (`Sales must close before the event starts (<date>)`); **Sale End ≥ Sale Start** (relaxed from `>` to `>=` to allow a one-day window); plus an added **Max Per Order ≤ Qty Available** rule. Sale-date `helperText` also now names the event start date so the rule is visible before submit.
- **Event context banner**: a slim strip between the form header and body shows the selected event's **name (+ code), date range (start → end), and venue** (or virtual platform when `eventModeCode === "VIRTUAL"`) — gives staff context for which event they're ticketing and surfaces the start date the sale window validates against. Skeleton while the event loads.
- **Verification**: FE `npx tsc --noEmit` → **0 errors** in `ticket-form-card.tsx` after each change.

### Session 8 — 2026-06-10 — BUILD (CONSOLIDATION) — COMPLETED

- **Scope**: The §⓪ CONSOLIDATION REVISION — turn #40 into the **4-tab host** that absorbs **#46 Event Ticketing** (Tab 3) and the **#169 Registration Page editor** (Tab 4). Old "Content & Speakers" tab retired (its banner/agenda/speakers/gallery are owned by Tab 4 / #169). FE-heavy + surgical BE guard + 2 seed flips. No new entities/mutations/migration. Agents: ONE `frontend-developer` (Sonnet) for the #169 `embedded` prop; everything else done directly in the main session.
- **Files touched**:
  - BE (1 — modified):
    - `Base.Application/.../Events/Commands/UpdateEvent.cs` — **decoupled the host Event save from Tab-3/Tab-4-owned data** so a tabs-1-2 Save can't wipe what those tabs persist: (a) null-guard the 4 child upserts (`UpsertSpeakers`/`UpsertRegistrationFormFields`/`UpsertCommunicationTriggers`/`UpsertGalleryPhotos` early-return when the dto collection is `null` = "leave untouched"); (b) null-guard `BannerImageUrl`/`DetailedAgendaHtml` in `MapScalars`; (c) `MapRegistrationPage` is now **create-only** — it lazily creates a missing page row (legacy events) but, for an existing row, only writes the two host-owned page fields `ShowCountdown` + `SendLinkTimingCode` (Tab 2) and leaves everything else for Tab 4 / #169.
  - DB seed (2 — modified):
    - `EventTicketing-sqlscripts.sql` — INSERT literal `IsLeastMenu` `true`→`false` + new idempotent `UPDATE … SET IsLeastMenu=false WHERE MenuCode='EVENTTICKETING'` (forces hide for already-seeded DBs). MenuCapabilities + BUSINESSADMIN grants untouched (cascade preserved). NB: the seeded code is `EVENTTICKETING`, not the FE gate's `EVENTTICKET`.
    - `event-reg-page-sqlscripts.sql` — INSERT literal `true`→`false` and the existing upsert `UPDATE … IsLeastMenu` flipped `true`→`false`.
  - FE (5 — modified):
    - `crm/event/event/event-form-page.tsx` (host) — `EVENT_STEPS` 3→4 (`1 Basic Info / 2 Venue & Schedule / 3 Ticketing / 4 Registration Page`; tabs 3-4 carry `gated:true`). Removed the `ContentSpeakersTab` import + its `<TabsContent value="3">`. Added gated `<TabsContent>` for tab 3 (`<EventTicketingTab eventId={recordId} …/>`) and tab 4 (`<EventRegistrationPageEditorPage eventId={recordId} embedded/>`), each wrapped in an Event-exists gate (`eventExists = recordId > 0 && !isAdd`) with a `GatedTabEmptyState` ("Save the event first…"). Step navigator shows a lock + "Save event first" sublabel + disabled click for gated tabs while `!eventExists`. `?tab=` deep-link applied AFTER the record loads (CR-ISSUE-6) + add-mode snap-back to tab 1. Sticky Save/Publish footer + validation summary + why-disabled hint now gated on `!isEmbedTab` (visible only on tabs 1-2). `buildPayload` now sends `null` for `speakers`/`registrationFormFields`/`communicationTriggers`/`galleryPhotos` and `bannerImageUrl`/`detailedAgendaHtml` (single-writer = Tab 4); removed the now-unused `stripTypename` helper.
    - `crm/event/eventticketing/index.tsx` (#46) — added exported `EventTicketingTab({ eventId, canCreate?, canUpdate?, canDelete? })`: drives the singleton `useEventTicketingStore` off the prop (`setSelectedEventId` on mount, `reset()` on unmount → no state leak between events), renders the 5 cards directly with NO `ScreenHeader`/event-selector. Standalone `EventTicketingIndex` + selector left intact for the (now redirect-only) route.
    - `setting/publicpages/eventregpage/editor-page.tsx` (#169) — added `embedded?: boolean` prop (via the Sonnet FE agent): when embedded, hides the standalone `<header>`+Back, suppresses the `beforeunload` guard, renders an inline Save/Publish action bar at the top of the cards column, and no-ops the lifecycle `router.push`. Non-embedded path byte-for-byte unchanged.
    - `app/[lang]/crm/event/eventticketing/page.tsx` — replaced with a thin client redirect: `?eventId=X` → `crm/event/event?mode=edit&id=X&tab=3` (else event list).
    - `app/[lang]/setting/publicpages/eventregpage/page.tsx` — replaced with a thin client redirect: `?id=X` → `crm/event/event?mode=edit&id=X&tab=4` (else event list).
- **Deviations from spec**:
  - §⓪.5 anticipated only an FE buildPayload change + possible `detailedAgendaHtml` BE delta. In practice **`detailedAgendaHtml`/banner relocation was already complete** (BE SetupInput/handler + FE DTO/GQL all already carried it; `BannerImageUrl` lives on `app.Events` and the #169 setup handler already writes it). So zero delta there — instead the real risk was the host's `UpdateEvent` **wiping** Tab-4-owned data; fixed with the surgical guards above (user-approved "Surgical BE guards" option).
  - `content-speakers-tab.tsx` retired from the wizard but left on disk + barrel (dead code) — see ISSUE-18.
  - `MapRegistrationPage` keeps writing `ShowCountdown` + `SendLinkTimingCode` because those two page fields are still edited in host Tab 2 — see ISSUE-19.
- **Known issues opened**: ISSUE-18 (dead `content-speakers-tab.tsx`), ISSUE-19 (`ShowCountdown` two-writer overlap — harmless).
- **Known issues closed**: None (the consolidation doesn't touch the #46-dependent SERVICE_PLACEHOLDER set; #46 itself is now embedded, so its real registrant/ticket data flows in Tab 3).
- **Verification**: BE `dotnet build Base.Application` → **0 errors** (541 pre-existing warnings). FE `npx tsc --noEmit` → **0 errors** project-wide. All edits confirmed in the `pwds-soruban - Copy` working copy (no sibling-worktree drift); `BaseUrlConfig.ts` left as the user manages it. Runtime E2E per §⓪.8 to be walked by the user with `pnpm dev` (requires re-running the two seed scripts to hide the absorbed menus).
- **Next step**: COMPLETED. User to (1) re-run `EventTicketing-sqlscripts.sql` + `event-reg-page-sqlscripts.sql` so the two menus disappear from the sidebar; (2) `pnpm dev` and verify §⓪.8 — 4 tabs, add-mode gating, tab 3 ticketing for the host event (no selector), tab 4 reg-page editor + Save, footer hidden on tabs 3-4, no wipe of speakers/gallery/banner/agenda on a tabs-1-2 save.

#### Follow-up (same session) — physical consolidation + dead-route removal (FE only)

User asked to physically move the absorbed UI into the Event location and delete the legacy routes outright (no redirect stubs). Decisions: keep #46 where it is (`crm/event/eventticketing/` — already a sibling), move #169 only; user handles the menu/DB removal, so seed scripts were left as-is.
- **Moved** (git-tracked as 18 renames): `setting/publicpages/eventregpage/` → **`crm/event/eventregpage/`** (`editor-page.tsx`, `eventregpage-store.ts`, 12 cards, 6 components). Cards/components use relative imports → survived the move; the one ESCAPING relative import (`9-payment-gateway-card.tsx` → `../../onlinedonationpage/components/api-single-select`) was repointed to an absolute `@/…/setting/publicpages/onlinedonationpage/…` path.
- **Deleted (dead after route removal)**: `eventregpage-root.tsx` (dispatcher), `list-page.tsx` (standalone list), the folder `index.ts` barrel.
- **Deleted routes** (replaced the Session-8 redirect stubs with full removal): `app/[lang]/crm/event/eventticketing/` and `app/[lang]/setting/publicpages/eventregpage/`.
- **Deleted orphaned PageConfig wrappers** + trimmed barrels: `pages/crm/event/eventticketing.tsx` (− export in `pages/crm/event/index.ts`), `pages/setting/publicpages/eventregpage.tsx` (− export in `pages/setting/publicpages/index.ts`), and `page-components/setting/publicpages/index.ts` (− `export * from "./eventregpage"`).
- **Repointed imports**: host `event-form-page.tsx` (editor now `@/…/crm/event/eventregpage/editor-page`); `eventticketing/public-preview-card.tsx` (`editorToPublicDto` from the new path); editor-page's two non-embedded `router.push` back/archive targets → `/${lang}/crm/event/event`.
- **Repointed 4 dashboard drill-downs** (`event-analytics-widgets/*`) that pushed to the now-deleted `/crm/event/eventticketing?eventId=` → `/crm/event/event?mode=edit&id=…&tab=3` (the `&tab=registrants`/`&ticketTypeId=` #46-internal params dropped — host doesn't honor them).
- **Verification**: FE `npx tsc --noEmit` → **0 errors**; final grep for `crm/event/eventticketing` / `setting/publicpages/eventregpage` / the deleted PageConfig exports → **0 matches**. BE untouched. NB: the public registration page (`(public)/event/[slug]`) imports the SEPARATE `page-components/public/eventregpage/` tree — unaffected by the admin-folder move.

### Session 9 — 2026-06-10 — ENHANCEMENT — Cross-tab publish gates + real status transition

- **Scope**: Wire the absorbed tabs' state INTO the Event publish flow. Three asks: (a) the registration page (Tab 4) must be published before the Event can publish; (b) at least one ticket (Tab 3) must exist; (c) "Save & Publish" must actually flip the Event status (it was staying DRAFT).
- **Root cause of (c)**: the consolidated host form's "Save & Publish" routed through `UPDATE_EVENT` with a *client-resolved* PUBLISHED id — if `statusIdByCode.get("PUBLISHED")` was empty it silently fell back to the current status. The dedicated, server-authoritative `publishEvent` command (resolves PUBLISHED server-side + validates) was only wired to the read-mode dashboard button, never to the in-form button.
- **Files touched**:
  - BE (1 — modified): `Base.Application/.../Events/Commands/PublishEvent.cs` — after the existing required-field checks, added a `blockers` list with two cross-tab gates: **(a)** resolve the 1:1 `RegistrationPage.PageStatusId` → `DataValue` and require it to be `PUBLISHED` or `ACTIVE`; **(b)** `EventTickets.AnyAsync(t => t.EventId == … && t.IsDeleted != true)`. Combined throw now reads "Cannot publish event. Missing required fields: …. <blocker sentences>". The status flip itself (`entity.EventStatusId = PUBLISHED`) was already correct.
  - FE (1 — modified): `crm/event/event/event-form-page.tsx` — imported `PUBLISH_EVENT_MUTATION` + `useMutation` (`publishing` folded into `saving`). **Split the save path**: `handleSave()` is now draft-only (creates/updates preserving DRAFT/current status — no more forced PUBLISHED via update); new `handlePublish()` persists pending tab-1-2 edits first (only if dirty, keeping current status), then calls `publishEvent({ eventId })`, sets `eventStatusId`←PUBLISHED on success, and surfaces the BE blocker via a new `publishError` banner ("Can't publish yet") + toast. "Save & Publish" button now `onClick={handlePublish}` and is **only rendered when `eventExists`** (edit mode) — add mode shows Draft only, since the gates require a saved event with tabs 3-4 populated. `publishError` clears on any field edit.
- **Deviations from spec**: ticket gate is "≥1 non-deleted ticket (any status)" — the literal ask. (The reg-page's OWN publish-gate already enforces the stricter ONSALE+PUBLIC-or-capacity rule, so duplicating it here would be redundant.) Reg-page gate accepts both PUBLISHED and its auto-advanced ACTIVE state.
- **Known issues opened**: None. **Known issues closed**: None.
- **Verification**: BE `dotnet build Base.Application` → **0 errors** (557 pre-existing warnings). FE `npx tsc --noEmit` → **0 errors**. Runtime walk by user: in edit mode, publishing a DRAFT event with no published reg page / no ticket should now show the blocker; once Tab 4 is published + a ticket exists, Save & Publish flips the status badge to PUBLISHED.
- **Next step**: COMPLETED.

### Session 10 — 2026-06-10 — UI/ENHANCEMENT — Registrants → "Event Tracking" drill-in; drop public-preview from Tab 3

- **Scope**: Two asks on the consolidated Ticketing tab (Tab 3). (1) Remove the right-column **"Public Registration Page Preview"** card — no longer needed. (2) Relocate the **Registrants** grid out of Tab 3 into a dedicated, reusable destination. Decision (user, AskUserQuestion): **drill-in route + Event-grid row action** (NOT a new menu screen), and **remove Registrants from Tab 3** entirely.
- **Files touched** (FE only):
  - `eventticketing/index.tsx` (modified) — dropped `PublicPreviewCard` from BOTH layouts (embedded `EventTicketingTab` + standalone `EventTicketingContent`), flattened the old 12-col grid (left col-8 / right col-4 sticky preview) to a full-width stack; removed `RegistrantsCard` from both. Tab 3 is now purely ticket setup (Summary + Ticket Types + Add/Edit Form).
  - `eventticketing/public-preview-card.tsx` (DELETED) — orphaned after the above; only `index.tsx` referenced it.
  - `event/event-tracking-page.tsx` (created) — `EventTrackingPage({ eventId })`: back header + reused `SummaryBar` (ticket KPI snapshot) + reused `RegistrantsCard` (full attendee console). Capabilities via `useAccessCapability("EVENT")`; resets the singleton `useEventTicketingStore` on mount/unmount so a prior event's registrant filter state can't leak.
  - `event/event-tracking-action.tsx` (created) — `EventTrackingAction({ event })`: extra grid row action (ph:users-three icon, "Event tracking" tooltip) navigating to `?mode=track&id=X`. Mirrors the View option's button/tooltip styling.
  - `event/index-page.tsx` (modified) — registers the action into the shared FlowGrid via `setCustomRowActions((row) => <EventTrackingAction event={row} />)` in a `useEffect`, cleared to `null` on unmount.
  - `event/event-page.tsx` (modified) — dispatcher gained a `mode=track` branch (`crudMode="track"` — the store's `crudMode` is a plain `string`, no union change) rendering `<EventTrackingPage eventId={recordId} />`.
- **Reuse**: `RegistrantsCard` + `SummaryBar` are imported verbatim from the `eventticketing/` folder — zero re-build of the registrants console (search / ticket filter / check-in toggle / edit / cancel / QR / pagination all intact).
- **Capability gate (new `EVENTTRACKING` cap)**: follows the standard READ/CREATE/MODIFY format (PrayerRequests `APPROVE`/`REPLY_*` precedent). DB (`Event-sqlscripts.sql`, modified): STEP 1b idempotently inserts the special `EVENTTRACKING` row into `auth."Capabilities"` (IsSpecial=true, OrderBy 40); STEP 2 MenuCapabilities IN-list += `EVENTTRACKING` (now 9); STEP 3 RoleCapabilities IN-list (BUSINESSADMIN) += `EVENTTRACKING` (now 8, HasAccess=true). FE: `useCapability.ts` maps `EVENTTRACKING`→`canEventTracking`; `TCapability.ts` adds `canEventTracking?`. The Event grid only registers the "Event Tracking" row action when `canEventTracking` (else `setCustomRowActions(null)`); `event-tracking-page.tsx` hard-gates direct `?mode=track` URLs with `LayoutLoader`/`DefaultAccessDenied`. No new BE authorization — the drill-in reuses already-authorized EventRegistration/EventTicket queries.
- **Deviations from spec**: none. **Known issues opened**: dead store fields `previewDevice`/`setPreviewDevice` in `eventticketing-store.ts` (only the deleted PublicPreviewCard used them) — harmless, left in place. **Known issues closed**: None.
- **Files touched (capability addon)**: BE `Event-sqlscripts.sql` (modified); FE `useCapability.ts`, `TCapability.ts`, `event/index-page.tsx`, `event/event-tracking-page.tsx` (modified).
- **Verification**: FE `npx tsc --noEmit` → **0 errors**. No BE code changes (seed only — user runs it).
- **Next step**: COMPLETED. Registrants reachable ONLY via the Event grid's "Event Tracking" row action → `?mode=track&id=X`, itself gated on the new `EVENTTRACKING` capability. **User must run `Event-sqlscripts.sql`** (STEP 1b/2/3) so BUSINESSADMIN gets the cap, else the action won't render.

### Session 11 — 2026-06-11 — UI — COMPLETED

- **Scope**: 9-item UI/UX polish pass across the consolidated 4-tab Event screen (host tabs 1-2 + embedded Tab 3 Ticketing + Tab 4 #169 Registration Page editor). All UI/in-scope — no Spec change. Removing the duplicate countdown control (item 5) also closes the long-standing two-writer overlap (ISSUE-19).
- **Files touched**:
  - BE (1 — modified):
    - `Base.Application/.../Events/Commands/UpdateEvent.cs` — `MapRegistrationPage` existing-page branch **no longer writes `ShowCountdown`** (item 5). Tab 4 / #169 RegistrantExperience card is now the SINGLE writer of the page countdown; the host's `SendLinkTimingCode` write stays. Closes ISSUE-19. (The lazy-create branch still seeds it once for legacy events — harmless.) No schema/migration change.
  - FE (7 — modified):
    - `crm/event/event/event-form-page.tsx` — **item 6**: completed step circles + connectors + sublabels now render GREEN (emerald, with a check) while the active step keeps the primary accent + focus ring; replaced the bare 3-block loading skeleton with a premium layout-matching skeleton (step navigator → guide banner → section card). **item 2**: added a unified `FormNotice` helper (clean card + colored left-accent stripe, no saturated full-bg wash) and migrated the validation summary, publish blocker, why-disabled and publish-readiness hints onto it, grouped in one `space-y-3` block. **item 3**: the tabs-1-2 sticky footer is now a detached, centered, `rounded-full` floating action pill (`pointer-events-none` wrapper so it never blocks content; buttons `size="sm"` + `rounded-full`; `flex-wrap` for xs). Added `ReactNode` import.
    - `crm/event/event/form-tabs/venue-schedule-tab.tsx` — **item 5**: removed the "Show Countdown" `Toggle` (+ its now-unused import); Timezone select stays in the schedule grid.
    - `crm/event/eventregpage/components/section-card.tsx` — **items 1 + 8**: section header now uses the host's solid primary icon chip + WHITE glyph (was a `bg-muted/50` bar + colored icon) so tabs 1-4 headers read uniform; card badges are full-solid pills with white text (was light-tint). Body padding `p-3.5 sm:p-4`.
    - `crm/event/eventregpage/components/status-bar.tsx` — **item 1**: `STATUS_CHIP` page-status pills converted from light-tint to full-solid bg + white text/dot.
    - `crm/event/eventregpage/components/live-preview.tsx` — **item 9**: preview now scales to FIT the measured pane width via a `ResizeObserver` callback ref (desktop = faithful browser-window shot at fit-zoom; mobile = a 390px phone frame with bezel ring), clamped so it never overflows the embedded Tab-4 pane nor shrinks to a thumbnail. Template-code + Preview badges made solid (item 1).
    - `crm/event/eventregpage/components/announcement-audience-section.tsx` — **item 7**: the native `<select>` saved-filter picker → canonical `FormSelect`.
    - `crm/event/eventregpage/editor-page.tsx` — **item 1**: `SaveStatus` (Saving/Unsaved/Saved) pills converted to full-solid bg + white text.
  - DB: None.
- **Item 4 (responsive)**: audited xl/lg/md/sm/xs across the screen — host tabs (`md:grid-cols-2`, mode cards `sm:grid-cols-3`), Tab-3 ticketing (`grid-cols-2 sm:grid-cols-4`, `hidden sm:inline` button labels), Tab-4 editor (`lg:flex-row` stack, cards `sm:grid-cols-2`) and the new floating pill (`flex-wrap`) were already responsive; the real defect was the live-preview overflowing the narrow embedded pane, fixed by the fit-to-pane scaling in item 9. Step navigator already hides labels < sm. No further changes needed.
- **Item 7 scope note**: only ONE native dropdown existed in Tab 4 (the saved-filter `<select>`) — converted. All other Tab-4 dropdowns already used `SelectField`/`FormSelect`; date pickers already route through the host `TextField`→`FormDateTimePicker` wrapper. Remaining raw `<input>`s are checkboxes (reminder channels, payment methods, form-field require/visible) and modal type-to-confirm text fields — not dropdowns/date-pickers, left as-is.
- **Deviations from spec**: None. The host `Event.ShowCountdown` scalar is still sent in the Event payload (the event-level field); only the duplicate PAGE-level write was removed (item 5 decision: "FE field + stop BE writing it").
- **Known issues opened**: None. **Known issues closed**: ISSUE-19 (ShowCountdown two-writer overlap — host no longer writes the page field).
- **Verification**: FE `npx tsc --noEmit` → **0 errors** project-wide. BE `dotnet build Base.Application` → **0 errors** (539 pre-existing warnings). All edits confirmed in the `pwds-soruban - Copy` working copy (no agents spawned → no sibling-worktree drift). Runtime visual confirmation (green ticks, floating pill, solid badges/headers, preview desktop/mobile fit, countdown gone from Tab 2) pending user `pnpm dev`.
- **Next step**: COMPLETED.

### Session 12 — 2026-06-11 — ENHANCEMENT — Event Unpublish + lock-when-live — COMPLETED

- **Scope**: Add the missing reverse of the consolidation-#40 publish flow. There was no way to take a PUBLISHED event back to editable, so the registration page could never be edited after going live. Now: PUBLISHED event → **Unpublish** → event DRAFT + page cascaded to ReadyToPublish (offline) → "Cancel Ready to Publish" (existing) → DRAFT → editable. Plus: while the event is PUBLISHED, **all fields across every tab are locked** (read-only) and the only actions are Unpublish (host) and the page's operational buttons (Preview / Close Early / Archive / Resend / Reset Branding).
- **Files touched**:
  - BE (2):
    - `Base.Application/.../Events/Commands/UnpublishEvent.cs` (created) — `UnpublishEventCommand`: validates event is PUBLISHED → DRAFT (resolves EVENTSTATUS/DRAFT row, mirrors PublishEvent/CancelEvent). **Cascade**: registration page Published/Active → **ReadyToPublish** (the symmetric inverse of PublishEvent's ReadyToPublish→Published cascade — NOT Draft, so the existing Unlock/"Cancel Ready to Publish" step still completes the path to editing). Registrations preserved; PagePublishedAt left intact (republish uses `??=`). Public page goes offline because the BySlug handler serves only {Published, Active, Closed}.
    - `Base.API/.../Mutations/EventMutations.cs` (modified) — `UnpublishEvent(eventId)` GraphQL mutation, placed right after `PublishEvent`.
  - FE (3):
    - `gql-mutations/contact-mutations/EventMutation.ts` (modified) — `UNPUBLISH_EVENT_MUTATION` (selects `eventId/statusCode/pageStatusCode`).
    - `crm/event/event/event-form-page.tsx` (modified) — destructured `statusCodeById` from `useEventDropdowns`; derived `eventPublished` from the loaded `eventStatusId`; added `unpublishEvent` hook (folded into `saving`) + `handleUnpublish` (success → toast, `bumpRefresh()`, optimistically set status → DRAFT). **Floating pill is now status-aware**: PUBLISHED → renders ONLY "Unpublish"; otherwise the existing Cancel / Save as Draft / Save & Publish trio. Publish-readiness hint suppressed while published. **Lock-when-live**: tabs 1-2 `readOnly={readOnly || eventPublished}`; tab 3 ticketing `canCreate/Update/Delete={canEdit && !eventPublished}`. Added a **full-screen centered progress overlay** (fixed `inset-0`, backdrop-blur, card with ping/pulse icon + spinner) shown while `publishing || unpublishing` — distinct copy for "Publishing event…" vs "Unpublishing event…".
    - `crm/event/eventregpage/editor-page.tsx` (modified, #169) — `locked` extended from `isReadyToPublish` to `isReadyToPublish || liveLocked` where `liveLocked = isPublished || isActive`; the existing `<fieldset disabled={locked}>` now greys out every page field when live, and the embedded Save gained `|| locked`. Split the frozen banner: ReadyToPublish keeps the violet "Unlock to make changes" + Cancel-Ready-to-Publish button; new emerald **"This page is live — unpublish the event to edit"** banner for Published/Active (no unlock button — Unlock only accepts ReadyToPublish). Operational actions (Preview / Resend / Close Early / Archive / Reset Branding) are NOT gated by `locked` → stay live, per the requirement.
  - DB: None.
- **Deviations from spec**: The pre-existing standalone `UnpublishEventRegistrationPageCommand` (Published/Active → **Draft**) is left intact but is NOT what the event-level Unpublish uses — the cascade targets **ReadyToPublish** to keep the publish/unpublish path symmetric (so "Cancel Ready to Publish" remains the single unlock step). No schema/migration change; both transitions reuse seeded EVENTSTATUS / EVENTREGPAGESTATUS rows.
- **Known issues opened**: None. **Known issues closed**: None.
- **Verification**: BE `dotnet build Base.API` → **0 errors** (632 pre-existing warnings). FE `npx tsc --noEmit` → **0 errors** (no event-file errors). Edits confirmed in the `pwds-soruban - Copy` working copy (no agents spawned). Runtime confirmed by user: Unpublish renders and flips state. Lock-when-live behavior pending user `pnpm dev` re-check.
- **Next step**: COMPLETED.

### Session 13 — 2026-06-11 — UI — COMPLETED

- **Scope**: Second 11-item UI/UX polish batch on the 4-tab Event screen (disabled-field colour bug, label/section uniformity, template & URL field differentiation, reminders coming-soon, payment-gateway dropdown swap, floating-pill scroll animation, locked-banner de-emphasis). All UI/in-scope — no Spec change, no BE change. One shared field component (`FormInput`) fixed at source (app-wide disabled-state bug). 3 disjoint Tab-4 card items (4/5/10) done by a background `frontend-developer` (Sonnet); the rest in the main session.
- **Files touched** (FE only — 9):
  - `custom-components/form-fields/FormInput.tsx` — **items 1 + 12** (app-wide bug fix): standalone-mode disabled state used `disabled:bg-default-700` (near-black) → rendered every disabled standalone FormInput (incl. the locked URL-slug field and all Event-tab Text inputs) as a BLACK field. Changed to `disabled:bg-muted disabled:text-muted-foreground disabled:cursor-not-allowed`. The RHF-control branch never had the bug. Affects the whole app's standalone FormInputs, not just Event.
  - `crm/event/event/form-tabs/fields.tsx` — **item 8**: `SectionHeader` rebuilt as a STRONG solid-primary header bar (white icon-chip + white title) instead of the old border-bottom + chip; added a new `FormSectionCard` (card shell + the same strong header) so host tabs match the Tab-4 cards. **item 2**: standalone `FieldWrapper` label already canonical; kept. **item 6**: new `UrlField` ({kind:"image"|"link"}) — image kind shows an image icon prefix + live thumbnail preview; link kind shows a link icon prefix + an "Open link" affordance.
  - `crm/event/event/form-tabs/basic-info-tab.tsx` — **item 8**: wrapped the tab in `FormSectionCard`; **item 2**: 3 inline `<label>`s (Event Code / Event Mode / Event Status) aligned to the canonical `text-[11px] font-medium text-foreground sm:text-xs`.
  - `crm/event/event/form-tabs/venue-schedule-tab.tsx` — **item 8**: Schedule / Venue / Virtual sections converted from bare `<section>`+`SectionHeader` to `FormSectionCard` (uniform border/radius/header/spacing). **item 6**: Map Link + Meeting URL → `UrlField kind="link"`.
  - `crm/event/eventregpage/components/section-card.tsx` — **item 8**: `SectionCard` header → strong solid-primary bar (white chip + title) matching the host `FormSectionCard`; badges read as solid pills on the bar. **item 2**: `CardField` label aligned to the canonical token; hints/errors responsive.
  - `crm/event/eventregpage/components/page-template-picker.tsx` — **item 3**: wrapped the tiles in a differentiated dashed tinted panel (`border-dashed border-primary/30 bg-primary/[0.04]`); shrank each tile ~30% (sketch `h-[72px]`→`h-[50px]`, tighter padding/label, grid up to `lg:grid-cols-5`); added a per-tile hover **Preview** eye button (selects the template so the right-pane live preview renders that exact layout).
  - `crm/event/eventregpage/cards/8-branding-seo-card.tsx` — **item 6**: Banner Image URL + Share Image URL → `UrlField kind="image"` (thumbnail preview).
  - `crm/event/event/event-form-page.tsx` — **item 7**: the floating action pill now hides (slide-down + fade) WHILE scrolling and springs back ~280ms after scroll stops (capture-phase scroll listener so it catches inner-container scroll too); pill given a stronger `shadow-xl ring-1`.
  - Background-agent (Sonnet) — 3 files: `cards/7-communications-card.tsx` (**item 4**: Reminder sub-section dimmed `opacity-60 pointer-events-none`, solid "Coming soon" pill, Switch/timing/channels disabled); `cards/9-payment-gateway-card.tsx` (**item 5**: replaced `ApiSingleSelect` with the canonical `SelectField` — same component as "Reminder Timing" — fed by `COMPANYPAYMENTGATEWAYS_QUERY` via useQuery); `eventregpage/editor-page.tsx` (**item 10**: "Ready to publish… locked" banner background de-tinted `bg-violet-50`→`bg-card`, neutral border/buttons, lock icon kept).
- **Item 9 (how-to, no code)**: answered in chat — distinguish transport/network failure (Apollo `error.networkError`, no `graphQLErrors`, often `Failed to fetch`/status 0/5xx) from a real API error (HTTP 200 with `result.success === false` + `errorDetails`, or `error.graphQLErrors[]`). Offered to add a shared `getRequestError()` normalizer if wanted (not implemented).
- **Deviations / interpretations**:
  - "Strong" section header = SOLID primary bar + white text (per the user's repeated solid-accent preference); applied uniformly to host tabs (`FormSectionCard`) and Tab-4 cards (`SectionCard`).
  - Item 3 "preview option per template" = a per-tile eye that selects the template so the existing right-pane live preview renders it (no per-template public route exists to open standalone).
  - Item 6 URL differentiation demonstrated on the two obvious image URLs (banner/share) + two navigation URLs (map link / meeting URL); the `UrlField` component is reusable for the rest.
- **Known issues opened / closed**: None.
- **Verification**: FE `npx tsc --noEmit` → **0 errors** project-wide (covers both main-session and background-agent edits). No BE changes this session. All edits + the agent's edits confirmed in the `pwds-soruban - Copy` working copy (`ApiSingleSelect` fully removed from card 9; "Coming soon"/gateway markers present) — no sibling-worktree drift. Runtime visual confirmation (no black disabled fields, strong uniform headers, floating-pill scroll animation, template panel + smaller tiles, URL thumbnails, reminders disabled, neutral locked banner) pending user `pnpm dev`.
- **Next step**: COMPLETED.

### Session 14 — 2026-06-11 — FIX — COMPLETED

- **Scope**: Index-page **Revenue / Capacity / Remaining** columns came up empty for every event, and the **Event Revenue (YTD)** KPI widget never reflected registrant amounts. Two root causes, both backend; FE (renderers + grid columns + widget) was already correct and bound to the right fields.
  1. `GetEvent` grid handler hard-coded the computed columns: `RegisteredCount = 0`, `EventRevenue = 0m`, `WaitlistCount = 0` (leftover `// TODO: wire to #46` placeholders). Revenue/registered/waitlist were therefore always blank. **Capacity** was additionally broken because the field moved off `Event` → `EventRegistrationPage` (#169), so Mapster's auto-projection produced `null` → the capacity progress renderer showed "No capacity set", and Remaining (capacity − registered) couldn't compute.
  2. `GetEventSummary` revenue KPI summed `TotalAmount` only for `EVENTREGSTATUS = CONFIRMED` registrations, so it read 0 whenever registrations weren't explicitly confirmed — inconsistent with the grid/dashboard.
- **Files touched** (BE only — 2):
  - `Base.Application/Business/ApplicationBusiness/Events/Queries/GetEvent.cs` (modified) — replaced the hard-coded placeholder block with real per-event aggregation over the current grid page's event ids, mirroring `GetEventDashboardById` (EVENTREGSTATUS code set): RegisteredCount = Σ Quantity (non-cancelled), EventRevenue = Σ TotalAmount (non-cancelled), WaitlistCount = Σ Quantity (WAITLIST). Capacity pulled explicitly from `EventRegistrationPages.Capacity` per event (since it no longer lives on `Event`); CapacityFillPct recomputed from the real capacity. "Remaining" is derived client-side from capacity − registered, so it now resolves.
  - `Base.Application/Business/ApplicationBusiness/Events/Queries/GetEventSummary.cs` (modified) — EventRevenueYtd changed from CONFIRMED-only to the same **non-cancelled** basis as the grid/dashboard; removed the now-unused `confirmedStatusId` lookup; refreshed the handler doc (no longer a SERVICE_PLACEHOLDER).
- **Revenue semantics (answer to the user's question)**: revenue is recognised **when a registration is recorded** (any non-cancelled registration's `TotalAmount`), **not** after the event completes. The YTD widget scopes to events whose `StartDate` falls in the current calendar year; the grid Revenue column is per-event lifetime. Both now use the identical non-cancelled basis, so the KPI, the grid column, and the per-event dashboard agree.
- **Deviations from spec**: None. Standardised the revenue basis to non-cancelled across summary + grid + dashboard for internal consistency (previously summary used CONFIRMED-only).
- **Known issues opened / closed**: None.
- **Verification**: BE build deferred to the user (their standing request). No FE changes — `event-revenue-renderer.tsx` / `event-capacity-progress.tsx` / `event-widgets.tsx` already bound to `eventRevenue` / `capacity` / `registeredCount` / `capacityFillPct` / `eventRevenueYtd`.
- **Next step**: COMPLETED (user builds BE → columns + KPI populate).

### Session 15 — 2026-06-12 — FIX — COMPLETED

- **Scope**: A PUBLISHED event whose `EndDate` has passed still showed **Published** (event badge) and the registration page still showed **Published/Active** — neither moved to a "completed" state. Root cause: the screen displays status via a read-time **computed** rule (ISSUE-10 convention — status is derived, never persisted), and the code only computed `PUBLISHED → INPROGRESS` while the event was running; the **`COMPLETED` branch was never added**, so past events fell through to the persisted `PUBLISHED`. The standalone `CompleteEvent` command/mutation exists but is wired to nothing (no button/job). The reg-page badge had no date logic at all. **User chose computed display** (no persisted write / no background job) to stay consistent with how INPROGRESS already works.
- **Files touched**:
  - BE (3 — modified): extended the existing computed-status block to add `PUBLISHED && EndDate < now → COMPLETED` (ahead of the INPROGRESS branch), display-only — stored `EventStatusId` stays PUBLISHED:
    - `Base.Application/.../Events/Queries/GetEvent.cs` (grid badge)
    - `Base.Application/.../Events/Queries/GetEventById.cs` (form load)
    - `Base.Application/.../Events/Queries/GetEventDashboardById.cs` (dashboard/view badge)
  - FE (2 — modified):
    - `crm/event/eventregpage/editor-page.tsx` (#169 Tab 4) — compute `eventEnded` from `page.endDate`; `endedClosed = eventEnded && (isPublished || isActive)` surfaces the page status as **CLOSED** (passed to `EventRegStatusBar` via a new `displayStatus`), adds `endedClosed` to `locked` so a finished event's page stays read-only, and shows a new orange **"This event has ended — registration is closed"** banner (the live "unpublish to edit" banner is suppressed once ended).
    - `crm/event/event/form-tabs/basic-info-tab.tsx` — the Basic Info "Event Status" chip now computes the displayed code locally from the date window (mirrors the BE: PUBLISHED → COMPLETED when past EndDate, INPROGRESS while running), finishing the COMPLETED/INPROGRESS labels+colours that were already defined in the file. Lock logic in `event-form-page.tsx` (`eventPublished`) still keys off the persisted status — unchanged.
  - DB: None.
- **Where the user now sees COMPLETED**: events grid (`GetEvent`→`eventStatusCode`), calendar view, dashboard/view page (`GetEventDashboardById`), Basic Info status chip, and Tab-4 reg-page status bar (as **CLOSED**, with the ended banner + locked fields).
- **Deviations from spec**: None. Pure read-time computation, consistent with the existing INPROGRESS convention (ISSUE-10) — no persisted status change, no migration, no background job. The public registration guard already independently blocks late sign-ups via `RegistrationEndDate`; this change is display/lock only.
- **Known issues opened / closed**: None. (The unused `CompleteEvent` command/mutation is left intact — it would only be needed if the team later switches to a persisted-transition model.)
- **Verification**: FE `npx tsc --noEmit` → **0 errors** project-wide. BE `dotnet build Base.Application` → **0 errors**. Edits confirmed in the `pwds-soruban - Copy` working copy (no agents spawned → no sibling-worktree drift). Runtime visual confirmation (grid/dashboard/form show "Completed", Tab-4 page shows "Closed" + ended banner + locked) pending user `pnpm dev`.
- **Next step**: COMPLETED.
- **⚠ SUPERSEDED by Session 16** — the user then required a **real persisted DB transition via a button**, not a computed display. The computed-COMPLETED display added here was **reverted** in S16 (BE 3 handlers back to INPROGRESS-only; basic-info chip back to persisted-derived; reg-page editor switched from computed `endedClosed` to real persisted `CLOSED`).

### Session 16 — 2026-06-12 — ENHANCEMENT — Persisted "Mark as Completed" button + page cascade — COMPLETED

- **Scope**: Replace S15's computed-only "Completed" display with a real, **button-driven persisted transition**. User requirement: when a PUBLISHED event's `EndDate` has passed, the host floating pill must show a **"Mark as Completed"** button (and **hide Unpublish**); Unpublish stays only while the event is still upcoming/running (`PUBLISHED && !ended`). Clicking Complete writes `EVENTSTATUS=COMPLETED` to the DB **and** cascades the registration page → `CLOSED`, then the action becomes a disabled "Completed" pill. Wires the pre-existing (but un-triggered) `CompleteEvent` command + `COMPLETE_EVENT_MUTATION` to the UI; adds the page cascade.
- **Files touched**:
  - BE (1 — modified):
    - `Base.Application/.../Events/Commands/CompleteEvent.cs` — added the registration-page cascade: on completion, if `RegistrationPage` status is `PUBLISHED` **or** `ACTIVE` → set `PageStatusId` to `CLOSED` (via `EventRegistrationPageStatuses.ResolveIdAsync`; the built-in `CloseEventRegistrationPageCommand` only closes from `ACTIVE`, so the cascade is inline). Added `Include(RegistrationPage).ThenInclude(PageStatus)` + the `EventRegistrationPages` using. The validator/guard already allowed `PUBLISHED && EndDate < now`. No schema change. (Mutation `completeEvent` + FE `COMPLETE_EVENT_MUTATION` already existed.)
  - BE (3 — REVERTED S15): `GetEvent.cs` / `GetEventById.cs` / `GetEventDashboardById.cs` computed-status blocks restored to **INPROGRESS-only** (no computed COMPLETED) — the badge now reflects the real persisted status, which flips only when the button is clicked.
  - FE (3 — modified):
    - `crm/event/event/event-form-page.tsx` — imported + hooked `COMPLETE_EVENT_MUTATION` (`completing` folded into `saving`); added `handleComplete` (success → toast + `bumpRefresh()` + optimistic `eventStatusId → COMPLETED`). New derivations: `eventCompleted`, `eventEnded` (`form.endDate < now`), `eventLocked = eventPublished || eventCompleted`. **Floating pill** rewired: `eventCompleted` → disabled **"Completed"** pill; `eventPublished && eventEnded` → **"Mark as Completed"**; `eventPublished && !eventEnded` → **"Unpublish"**; else the Cancel/Save/Publish trio. **Lock-when-live extended to lock-when-completed**: tabs 1-2 `readOnly` + Tab-3 ticketing `canCreate/Update/Delete` + the publish-readiness hint now key off `eventLocked` (was `eventPublished`). Progress overlay gained a third "Completing event…" state (emerald + check glyph).
    - `crm/event/event/form-tabs/basic-info-tab.tsx` — **REVERTED S15**: status chip back to persisted-derived (`statusCodeById.get(eventStatusId)`); the COMPLETED label/colour already defined there now lights up once the DB row is COMPLETED.
    - `crm/event/eventregpage/editor-page.tsx` — **REVERTED S15 computed `endedClosed`** → real `isClosed = pageStatus === "CLOSED"`; `locked` now includes `isClosed`; status bar gets the raw `page.pageStatus` again; banner reworded to "Registration is closed." (fires for any CLOSED page — completion cascade or Close Early).
  - DB: None (EVENTSTATUS/COMPLETED + EVENTREGPAGESTATUS/CLOSED already seeded).
- **Behaviour summary**: DRAFT → (Save & Publish) → PUBLISHED → while upcoming/running shows **Unpublish** → once `EndDate` passes shows **Mark as Completed** → click persists **COMPLETED** (+ page **CLOSED**) → pill disabled "Completed", whole event locked, Tab-4 page locked w/ "Registration is closed" banner. Badge everywhere (grid/dashboard/form/calendar) now shows the real persisted COMPLETED.
- **Deviations from spec**: Completion is **manual** (admin clicks the button), not an automatic date sweep — matches the user's explicit instruction. The standalone background-sweep option remains unbuilt. `CompleteEvent` keeps its optional `EventSummary` param (FE sends `null`).
- **Known issues opened / closed**: None.
- **Verification**: BE `dotnet build Base.Application` → **0 errors**. FE `npx tsc --noEmit` → **0 errors** project-wide. Edits confirmed in the `pwds-soruban - Copy` working copy (no agents spawned). Runtime (button swap on past-end-date, DB flip to COMPLETED, page → CLOSED + locked) pending user `pnpm dev`.
- **Next step**: COMPLETED.

### Session 17 — 2026-06-12 — ENHANCEMENT — Completed event: lock ALL Tab-4 actions + hide public page — COMPLETED

- **Scope**: Two follow-ups to the S16 completion flow. (1) When the event is completed, **every DB-affecting action inside the event must be disabled** — not just the form fields. The Tab-4 (#169) operational buttons (Resend Announcement, Reset Branding, Archive, Save; Close Early/Ready/Unlock only render for other statuses) were still live (S12 deliberately kept them live for *live* events). (2) Once completed, the **public registration page must not be shown** to visitors.
- **Files touched**:
  - FE (1 — modified): `crm/event/eventregpage/editor-page.tsx` — new `eventCompletedLock = isClosed && eventOver` (event over AND its page CLOSED = the host "Mark as Completed" cascade; a page closed *early* on a still-upcoming event is NOT treated as completed, so it keeps its management actions). `locked` now folds in `eventCompletedLock` (instead of bare `isClosed`). Disabled when `eventCompletedLock`: **Resend Announcement** (both header + embedded bars), **Reset Branding** + **Archive** `DropdownMenuItem`s (both bars). **Save** already gated by `locked`; **Preview** intentionally stays enabled. Banner reworded → "This event is completed. The registration page is closed, hidden from the public, and all actions are locked."
  - BE (1 — modified): `Base.Application/.../EventRegistrationPages/PublicQueries/GetEventRegistrationPageBySlug.cs` — added `.Include(e => e.EventStatus)` (both the primary and the Dev slug-fallback query) and, right after the page-status resolve, a guard: **if the EVENT status is `COMPLETED` → return `(null, false)` (404, page hidden)**. Gated on event status (not page status) so a `CLOSED`-early page on an upcoming event still renders its "registration closed" public view. (Public registration was already blocked for CLOSED pages by `InitiateEventRegistration`'s status gate — no change needed there.)
  - DB: None.
- **Page "completed" status note**: `EVENTREGPAGESTATUS` has no `COMPLETED` value — the lifecycle terminal for registration is `CLOSED` (then optionally `ARCHIVED`). The completion cascade (S16) sets the page to **CLOSED**; the admin Tab-4 chip shows "Closed" with the new "event is completed" banner, and the public page is hidden via the event-status 404 above. No new page-status row was added.
- **Deviations from spec**: Public hide is a hard 404 (`null` result → caller's not-found), not an "event has ended" landing page — matches the user's "we don't show". The 60s BySlug memory-cache means the hide can lag ≤60s after completion.
- **Known issues opened / closed**: None.
- **Verification**: BE `dotnet build Base.Application` → **0 errors**. FE `npx tsc --noEmit` → **0 errors** project-wide. Edits confirmed in the `pwds-soruban - Copy` working copy (no agents spawned). Runtime (Tab-4 Resend/Reset/Archive greyed when completed; public slug 404s) pending user `pnpm dev`.
- **Next step**: COMPLETED.

### Session 18 — 2026-06-12 — FIX — Registration trend collapses to a single bar — COMPLETED

- **Scope**: The view/dashboard "Registration trend" widget rendered only one bar (e.g. all on Jun 11) even though `EventRegistrations` rows have varying registration dates. Root cause: the trend grouped by `CreatedDate` (the EF row insert/seed timestamp — all rows imported together share the same instant → one bucket), not the attendee's actual `RegisteredDate`.
- **Files touched**:
  - BE (1 — modified): `Base.Application/.../Events/Queries/GetEventDashboardById.cs` — trend `GroupBy(r => r.CreatedDate!.Value.Date)` → `GroupBy(r => r.RegisteredDate.Date)`. Dropped the now-unneeded `r.CreatedDate != null` filter (`RegisteredDate` is a non-nullable `DateTime`). Non-cancelled `Quantity`-sum logic unchanged.
  - FE / DB: None.
- **Deviations from spec**: None.
- **Known issues opened / closed**: None.
- **Verification**: BE `dotnet build Base.Application` → **0 errors**. Runtime (multi-day trend bars) pending user `pnpm dev`.
- **Next step**: COMPLETED.

### Session 19 — 2026-06-12 — FIX — Dashboard view: capacity 0, empty registrants, completed-event action lock, toolbar layout — COMPLETED

- **Scope**: Six related view-page (read-mode dashboard) defects. (1) "Registration Progress" showed `810 / 0 capacity` — capacity 0; (2) "Spots left" = 0; (3) "Reg closes" = "—"; (4) Registrants list rendered an empty placeholder despite 810 real registrations; (5) a COMPLETED event still enabled DB-affecting actions (Send Reminder, Archive); (6) Send Reminder + "More actions" sat in a full-width row *below* the header (big empty band) instead of beside the existing Edit button in the top toolbar.
- **Root causes**: (1–3) After #169 the Event entity no longer carries `Capacity` / `RegistrationEndDate` (moved to `app.EventRegistrationPages`), so `entity.Adapt<EventResponseDto>()` left `eventDto.Capacity = 0` and `RegistrationEndDate = null`; the dashboard handler also read `RegistrationPage.Capacity` (a page-level cap the user never set — real cap = sum of #46 ticket `QuantityAvailable` = 900). (4) `Registrants` was a hardcoded `new List<RegistrantDto>()` SERVICE_PLACEHOLDER from before #46 existed; the FE table was a static empty-state. (5) The view-page actions had no terminal-status guard. (6) `FlowFormPageHeader` renders `children` in a `mt-2` block below the header; only its built-in Edit/Save lives in the top-right `rightContent`.
- **Files touched**:
  - BE (1 — modified): `Base.Application/.../Events/Queries/GetEventDashboardById.cs` — capacity now `pageCapacity > 0 ? pageCapacity : Σ ticket.QuantityAvailable`; set `eventDto.Capacity` + `eventDto.RegistrationEndDate` from `entity.RegistrationPage` so the FE hero/`Reg closes` render real values; **populated `Registrants`** from `EventRegistrations` (Include `Status`, non-deleted, ticket-scoped, newest-first → `RegistrantDto` w/ name/email/ticketName/status/registeredDate/amountPaid). Spots-left/fill-pct now derive from the corrected capacity.
  - FE (4 — modified): `gql-queries/contact-queries/EventQuery.ts` — added a `registrants { … }` selection to `EVENT_DASHBOARD_BY_ID_QUERY`. `crm/event/event/event-registrants-table.tsx` — rewritten from static placeholder to a real searchable table (name/email/ticket/status pill/registered/amount) driven by a `registrants` prop, with a "No registrations yet" empty-state. `crm/event/event/event-dashboard-page.tsx` — pass `registrants={dashboard.registrants}`; added `eventTerminal = COMPLETED||CANCELLED` and gated **Send Reminder** (hidden) + **Archive** (disabled) on it (Cancel already disabled for those statuses; Export read-only stays live); moved `headerActions` from `children` into the new `headerActions` toolbar slot and dropped its `w-full justify-end` wrapper. `custom-components/page-header/PageHeader.tsx` (**shared**) — added optional `headerActions?: ReactNode` prop to `FlowFormPageHeader`, rendered in `rightContent` left of the built-in Edit/Save button (additive, default-undefined → no impact on other screens).
  - DB: None.
- **Deviations from spec**: None. Capacity-source precedence (page cap → ticket-sum) is a sensible fallback, not a spec change.
- **Known issues opened / closed**: None.
- **Verification**: BE `dotnet build Base.Application` → **0 errors**. FE `npx tsc --noEmit` → **0 errors** project-wide. Runtime (capacity 810/900, spots 90, reg-closes date, populated registrants table, completed-event greyed actions, toolbar layout) pending user `pnpm dev`.
- **Next step**: COMPLETED.

### Session 20 — 2026-06-12 — FIX — Dashboard registrants: replace all-rows-one-page table with server-paginated RegistrantsCard — COMPLETED

- **Scope**: Session 19 populated the dashboard's registrants by embedding the **entire** registrant list in the `eventDashboardById` payload and rendering it on a single page with client-side search. For an 810-registrant event that means one heavy query + 810 DOM rows, no real pagination. User: "Registrants get all query … currently we render with search pagination so it's retrieved all the records and shown in single page — it's not correct so change it" and pointed at the track page (`crm/event/event?mode=track&id=13`) as the correct pattern.
- **Root cause**: The dashboard forked its own registrants table instead of reusing the existing server-paginated console. The #46 Ticketing module already ships `RegistrantsCard` (used by `EventTrackingPage` at `?mode=track`), which drives off `useEventTicketingStore` and queries `getAllEventRegistrationList` (BE `EventRegistrationQueries` → `GridFeatureRequest`: pageSize 20 + searchTerm + ticket filter, server-sorted by `RegisteredDate desc`) with prev/next pagination, check-in toggle, edit & cancel.
- **Fix**: Reuse `RegistrantsCard` in the read-mode dashboard; stop embedding registrants in the dashboard payload entirely. Honors the reuse-existing-grids rule (never fork a per-screen grid).
- **Files touched**:
  - BE (1 — modified): `Base.Application/.../Events/Queries/GetEventDashboardById.cs` — removed the full `EventRegistrations` projection (the Session-19 block); `Registrants` left as an empty list (the dedicated paginated endpoint serves the list now). Dashboard query no longer reads all registrant rows.
  - FE (3 — modified, 1 — deleted): `event-dashboard-page.tsx` — render `<RegistrantsCard eventId={recordId} canUpdate={canEdit && !eventTerminal} canDelete={canDelete && !eventTerminal} />` in place of the bespoke table; reset the singleton ticketing store on mount/unmount (mirrors `EventTrackingPage`) so a prior event's search/filter/page can't leak; added `canDelete` from `capability`. `EventQuery.ts` — dropped the `registrants { … }` selection from `EVENT_DASHBOARD_BY_ID_QUERY`. `crm/event/event/index.ts` — removed the `EventRegistrantsTable` export. **Deleted** `crm/event/event/event-registrants-table.tsx` (the Session-19 bespoke table, now dead).
  - DB: None.
- **Deviations from spec**: None. Completed-event lock (Session 19 rule 5) carried forward — terminal events pass `canUpdate=false`/`canDelete=false` so the card's edit/cancel actions are hidden (the inline check-in toggle remains, matching the track-page console).
- **Known issues opened / closed**: None.
- **Verification**: BE `dotnet build Base.Application` → **0 errors**. FE `npx tsc --noEmit` → **0 errors** project-wide. Runtime (paginated 20/page, server search + ticket filter, prev/next over 810 rows, no full-list payload) pending user `pnpm dev`.
- **Next step**: COMPLETED.