---
screen: NotificationCenter
registry_id: 35
module: Communication
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
- [x] HTML mockup analyzed (feed/inbox-style list — NOT standard FLOW)
- [x] Existing code reviewed (BE entity + 7 commands + 3 queries + endpoints; FE route stub + minimal DTO/Query/Mutation — no page-components folder)
- [x] Business rules + workflow extracted (system-generated, user marks read/star/delete/mute)
- [x] FK targets resolved (Contact, User, NotificationTemplate, Company — all exist)
- [x] File manifest computed (BE align-adds + FE near-greenfield custom inbox UI)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (prompt-driven — agents skipped per token directive)
- [x] Solution Resolution complete (prompt-driven)
- [x] UX Design finalized (prompt §⑥ is authoritative)
- [x] User Approval received (pre-filled config + user directive)
- [x] Backend code modified (entity + config + schemas + validators + Mappings + 2 mutations + 2 queries)
- [x] Backend wiring complete (SharedMappings explicit NotificationTemplateTitle flat-map; existing DbSet + DecoratorProperties unchanged)
- [x] Frontend code generated (custom inbox UI + Zustand store + Radix dropdown)
- [x] Frontend wiring complete (barrels + notify-service-entity-operations + route stub overwritten)
- [x] DB Seed script generated (menu + capabilities; no Grid row — GridFormSchema SKIP)
- [x] Registry updated to COMPLETED
- [ ] EF migration (DEFERRED per user directive — dev team to run `dotnet ef migrations add AddNotificationInboxColumns` + `database update` + seed SQL)

### Verification (post-generation — FULL E2E required)
- [ ] dotnet build passes
- [ ] pnpm dev — page loads at `/[lang]/crm/notification/notificationcenter`
- [ ] Inbox loads grouped by date sections (Today / Yesterday / Earlier This Week / Older)
- [ ] 4 status filter chips (All / Unread / Read / Starred) switch filter
- [ ] Category dropdown filters by Donation / Contact / Campaign / Event / System
- [ ] Priority dropdown filters by Normal / High / Urgent
- [ ] Unread notification has blue left border + light-blue background
- [ ] High priority = amber left border; Urgent priority = red left border
- [ ] Urgent + unread = subtle pulse animation
- [ ] Click notification card body → marks as read + navigates to ActionUrl (when present)
- [ ] Click action button → navigates to ActionUrl without unwanted event bubbling
- [ ] Star toggle persists (server-side)
- [ ] More menu: Mark Read/Unread, Star/Unstar, Mute this type, Delete — all work
- [ ] "Mark All as Read" header button works
- [ ] "Notification Settings" header button navigates to `/crm/notification/notificationtemplate`
- [ ] Load More pagination appends next page (infinite-scroll-like)
- [ ] Empty state renders when filters return zero results ("You're all caught up!")
- [ ] Unread count badge in header stays in sync with `userNotifications.unreadCount`
- [ ] DB Seed — menu visible under CRM → Notification sidebar group

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: NotificationCenter
Module: Communication (CRM → Notification)
Schema: `notify`
Group: NotifyModels (entity lives in `Base.Domain/Models/NotifyModels/Notification.cs` with existing `namespace Base.Domain.Models.SharedModels;` header — pre-existing inconsistency, preserve to avoid breaking the working Module/User nav-properties)

Business: The Notification Center is the in-app activity feed / inbox where every user sees notifications targeted at them (ToUserId = current user). Notifications are **system-generated** — there is NO "+Add" action, no user-authored creation flow, and no separate FORM/DETAIL view-page. Server-side triggers (donation received, recurring-donation failed, contact-duplicate detected, refund approval pending, campaign goal reached, event registration, etc.) instantiate Notifications via background workers / handlers (out of scope for this screen; consumers of the backend API). Users INTERACT with the feed: mark read/unread, star/unstar, mute a notification type, delete, and click-through to the linked entity via an Action URL stored on each notification. The screen complements Notification Templates (#36 COMPLETED) which defines the template metadata (icon, color, category, priority, action url/label) that each generated Notification copies from. The global unread count (shown in the app's top-nav bell) is sourced from `userNotifications` and kept in sync here.

Relationship to other screens:
- **#36 Notification Templates** — COMPLETED. Defines `NotificationTemplate` rows with Category (Donation/Contact/Campaign/Event/System), Priority (Normal/High/Urgent), IconCode, IconColor, ActionUrl, ActionLabel. Each user Notification references the template via `NotificationTemplateId` (nullable FK — templates can be deleted without nuking historical notifications, so copy display fields onto the Notification).
- **Parent bell icon** (top-nav) — uses `userNotifications` query for unread count. Same query must be kept backwards-compatible.
- **ActionUrl target screens** — generic navigation via `router.push(ActionUrl)`. No changes to those target screens.

This screen is a **non-standard FLOW** (classified as FLOW in registry, but does NOT follow the 3-URL-mode `view-page.tsx` pattern — similar to #44 Organizational Unit and #46 Event Ticketing which are also non-standard FLOWs).

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> Existing entity minimal — ALIGN mode adds 7 new columns to match mockup.
> **CompanyId is NOT a request field** — tenant from HttpContext (already present on entity, stays populated by existing pipeline).

Table: `notify."Notifications"` (already exists)

### Existing columns (keep)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| NotificationId | int | — | PK | — | Identity |
| NotificationTypeId | int | — | YES | — | Free-form integer type id (legacy — keep, not used by mockup filters) |
| NotificationTitle | string | 250 | YES | — | `[CaseFormat("title")]` |
| NotificationText | string | — | YES | — | Body (no max length on entity today; ALIGN: cap at 1000) |
| ModuleId | Guid | — | YES | `auth.Modules.ModuleId` | Existing; legacy cross-module linkage |
| FromUserId | int? | — | NO | `auth.Users.UserId` | Optional — "System" when null |
| ToUserId | int | — | YES | `auth.Users.UserId` | Recipient — filter target |
| IsRead | bool | — | YES (default false) | — | — |
| CompanyId | int? | — | NO | `auth.Companies.CompanyId` | Tenant (set by pipeline) |
| (inherited IsActive, IsDeleted, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate from `Entity` base) |

### NEW columns to add (ALIGN — match mockup requirements)

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| NotificationTemplateId | int? | — | NO | `notify.NotificationTemplates.NotificationTemplateId` | Nullable FK — templates may be deleted; display fields are cached below |
| Category | string | 30 | YES (default "System") | — | One of: "Donation", "Contact", "Campaign", "Event", "System". Cached from template. Indexed. |
| Priority | string | 10 | YES (default "Normal") | — | One of: "Normal", "High", "Urgent". Cached from template. Indexed. |
| IconCode | string | 60 | YES (default "fa-bell") | — | fa-* icon slug. Cached from template. |
| IconColor | string | 10 | NO | — | Hex color. Cached from template. |
| ActionUrl | string | 500 | NO | — | Target relative URL when action button clicked. |
| ActionLabel | string | 60 | NO | — | Button label (e.g., "View Donation"). |
| IsStarred | bool | — | YES (default false) | — | User-set star. Indexed. |

**Indexes to add** (migration):
- Composite index `(ToUserId, IsDeleted, CreatedDate DESC)` — primary read path (GetInboxNotifications scoped to current user, newest first).
- Composite index `(ToUserId, IsRead, IsDeleted)` — unread filter + count.
- Composite index `(ToUserId, IsStarred, IsDeleted)` — starred filter.
- Single index on `Category` and `Priority` — dropdown filters.

**Child Entities**: NONE. Single table.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()`) + Frontend Developer (ApiSelect / display joins)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| FromUserId | User | `Base.Domain/Models/AuthModels/User.cs` | (via Include → UserResponseDto) | `FirstName + LastName` | `UserResponseDto` (already on NotificationResponseDto) |
| ToUserId | User | `Base.Domain/Models/AuthModels/User.cs` | (scoped from HttpContext, no dropdown) | n/a | `UserResponseDto` |
| ModuleId | Module | `Base.Domain/Models/AuthModels/Module.cs` | (via Include → ModuleDto) | `ModuleName` | `ModuleRequestDto` (already on NotificationResponseDto) |
| CompanyId | Company | `Base.Domain/Models/AuthModels/Company.cs` | (tenant scoped) | n/a | — |
| NotificationTemplateId (NEW) | NotificationTemplate | `Base.Domain/Models/NotifyModels/NotificationTemplate.cs` | `notificationTemplates` (existing, from #36) | `NotificationTemplateTitle` | `NotificationTemplateResponseDto` |

No user-facing ApiSelect dropdowns on this screen. All FKs are read-side display joins.

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (client behaviour)

**Tenant scoping (CRITICAL):**
- **ALL read operations MUST filter `ToUserId == currentUserId`** (from `IHttpContextAccessor.GetCurrentUserId()`). This is the SavedFilter-style explicit scope used in `GetUserNotifications` already — extend this to `GetInboxNotifications`.
- CompanyId scope additionally applied by existing MultiTenantInterceptor / SaveChanges pipeline.
- A user must NEVER see another user's notifications even inside the same company.

**Mutation authorization:**
- `UpdateReadNotification` / `UpdateReadAllNotifications` / `DeleteNotification` / `DeleteAllNotifications` / `ToggleStarNotification` (NEW) / `MuteNotificationType` (NEW SERVICE_PLACEHOLDER) — validator MUST guard `notification.ToUserId == currentUserId` — return NotFound on mismatch (don't leak existence).

**Uniqueness Rules:** NONE (there are no uniqueness constraints on this entity — multiple identical-text notifications are legitimate e.g. two donations from the same donor).

**Required Field Rules** (already enforced — keep):
- `NotificationTitle`, `NotificationText`, `NotificationTypeId`, `ModuleId`, `ToUserId` required.
- NEW: `Category ∈ {"Donation","Contact","Campaign","Event","System"}` (validator whitelist).
- NEW: `Priority ∈ {"Normal","High","Urgent"}` (validator whitelist).
- NEW: `IconCode` required (default "fa-bell" on entity).

**Conditional Rules:**
- If `NotificationTemplateId` is provided, validator must verify it exists AND belongs to the same Company. Display fields (Category, Priority, IconCode, IconColor, ActionUrl, ActionLabel) should be populated by the caller (back-end trigger handler) from the template — this screen does not create notifications.

**Business Logic:**
- **Date grouping (FE-only)**: compute group on the client from `createdDate`:
  - Today: same calendar day as now (user timezone from session).
  - Yesterday: previous calendar day.
  - "Earlier This Week": day before yesterday through start of current ISO week.
  - "Older": anything before start of current ISO week (labeled by the ISO-week-start date: e.g., "Week of Apr 6" or simply "Older"). Mockup shows 3 groups with today's data — extend with "Older" for historical pages loaded via "Load More".
- **Urgent+Unread pulse**: CSS `animation: urgentPulse 2s ease-in-out infinite;` only when `priority === "Urgent" && !isRead`.
- **Click on card body** (NOT action button, star, menu): `{ if (!isRead) markAsRead(id); if (actionUrl) router.push(actionUrl); }`
- **Click action button**: `router.push(actionUrl)` with `event.stopPropagation()`; does NOT mark read (per mockup — `navigateTo` calls `event.stopPropagation` and does NOT mutate status).
  - NOTE: diverges from the mockup's implicit behaviour. ALIGN decision: keep mockup behaviour exactly — card body marks read on click; action button bypasses stopPropagation handling at `.notif-action-btn` level via `event.stopPropagation()` first, then navigates without status change. Card-body click still marks read.
- **Star toggle** / **menu actions**: `event.stopPropagation()` — do NOT mark read when toggling star or opening dropdown.
- **Mute this type** (from menu): SERVICE_PLACEHOLDER — surface a toast "Muted. You can unmute from Notification Settings." and no persistent server call for MVP. A mute-preference service (per-user-per-template) is not yet built; wire the button to a toast with a clear placeholder comment.
- **Delete** (from menu): soft-delete (set `IsDeleted=true` via existing `DeleteNotification` command). Removed from feed immediately (optimistic update + re-fetch).
- **Mark All as Read** (header): calls existing `updateReadAllNotifications` — MUST filter to `ToUserId == currentUserId` (verify current handler does this; if not, FIX it — see ISSUE-1).
- **Load More**: cursor-less pagination via `pageIndex += 1, pageSize = 20`. Infinite-scroll-like: append to list, don't replace.

**Workflow**: None (no state machine — notifications are boolean read/unread + boolean starred + soft-delete).

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — pre-answered decisions.

**Screen Type**: FLOW (non-standard — custom inbox UI, NO view-page.tsx 3-URL-mode pattern, NO FORM, NO DETAIL page)
**Type Classification**: FLOW — Custom Composite Page (one consolidated index-page.tsx replaces both grid and view-page)
**Reason**: The mockup is a feed/inbox, not a transactional CRUD screen. There is no user-authored create/edit/read workflow. Data is inserted by server-side triggers (out of scope), and the user's interaction is purely read + mark-read/star/delete/mute + click-through. Shares non-standard-FLOW pattern with #44 Organizational Unit (tree+split-pane custom index) and #46 Event Ticketing (composite single-page console).

**Backend Patterns Required:**
- [x] Extend existing CRUD commands (no new entity — ALIGN adds 7 columns)
- [x] Tenant scoping (CompanyId from HttpContext — existing)
- [x] **User scoping** (ToUserId from HttpContext — critical, add to GetInboxNotifications + Mutations)
- [ ] Nested child creation — N/A
- [x] Multi-FK validation (NotificationTemplateId when present)
- [ ] Unique validation — N/A
- [x] NEW command: `ToggleStarNotificationCommand`
- [x] NEW command: `MuteNotificationTypeCommand` (SERVICE_PLACEHOLDER — accepts templateId/typeId, returns success, no persistence layer)
- [x] NEW query: `GetInboxNotificationsQuery` (current-user scoped, filter by status/category/priority/starred, paginated, ordered by CreatedDate DESC)
- [x] NEW query: `GetInboxSummaryQuery` (returns `NotificationInboxSummaryDto { totalCount, unreadCount, starredCount, categoryCounts: Map<string,int>, priorityCounts: Map<string,int> }`)
- [x] KEEP existing `GetUserNotificationsQuery` for top-nav bell (returns `NotificationUnreadDto { unreadCount }`) — backwards-compat
- [ ] File upload — N/A
- [ ] Custom business rule validators — see §④

**Frontend Patterns Required:**
- [ ] FlowDataTable grid — NO (replaced by custom inbox feed)
- [ ] view-page.tsx with 3 URL modes — NO (no mode routing)
- [ ] React Hook Form — NO (no form)
- [x] Zustand store (`notification-center-store.ts`) — stores status filter chip, category dropdown, priority dropdown, page index, accumulated list
- [ ] Unsaved changes dialog — N/A
- [ ] FlowFormPageHeader — NO
- [x] Custom page header (ScreenHeader + action buttons on the right)
- [ ] Child grid inside form — N/A
- [x] Filter chip row (4 chips + 2 dropdowns)
- [x] Date-grouped card list
- [x] Per-card dropdown menu (click-outside-close behaviour)
- [x] Optimistic updates for star/read/delete
- [x] Toast notifications for actions (`sonner` / existing toast util)
- [x] Summary integration with top-nav bell (`UNREAD_NOTIFICATIONS_QUERY` — already in use)
- [x] Grid Layout Variant: **widgets-above-grid** (using ScreenHeader on top + custom body — Variant B pattern for consistency)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **This is a non-standard FLOW** — no view-page 3-mode, no FORM, no DETAIL. Entire screen is one custom inbox on `index-page.tsx`.

### Page Layout (single custom page — no view-page)

**Grid Layout Variant**: `widgets-above-grid` → FE Dev uses **Variant B** (`ScreenHeader` + body — do NOT include duplicate `DataTableContainer` headers because there is no DataTableContainer).

**Route**: `/[lang]/crm/notification/notificationcenter`
**Default page behaviour**: mount → fetch page 1 of inbox (pageSize=20, isRead=null, category=null, priority=null, starred=null) + fetch inbox summary → render.

#### Page Shell (top → bottom)

```
┌────────────────────────────────────────────────────────────────┐
│ <ScreenHeader>                                                 │
│   Title: "Notifications" + unread badge "{N} unread" (red)     │
│   Subtitle: "Your in-app alerts and activity feed"             │
│   Actions: [Mark All as Read]  [Notification Settings]         │
│     - Mark All as Read → button, calls updateReadAllNotifications│
│     - Notification Settings → link → /crm/notification/notificationtemplate │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ <FilterBar> (flex-wrap gap-2)                                  │
│   [All] [Unread] [Read] [Starred]   |   [Category ▾] [Priority ▾]│
│   (filter chips — pill-shaped; active = accent bg + white text)│
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ <InboxList>                                                    │
│   TODAY ─────────────────────────                              │
│   [NotificationCard] [NotificationCard] [NotificationCard]     │
│   YESTERDAY ────────────────────                               │
│   [NotificationCard] [NotificationCard]                        │
│   EARLIER THIS WEEK ────────────                               │
│   [NotificationCard] [NotificationCard]                        │
│   OLDER ────────────────────────                               │
│   [NotificationCard] [NotificationCard]                        │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│ <LoadMore>                                                     │
│   [↓ Load More Notifications] (centered, secondary button)    │
└────────────────────────────────────────────────────────────────┘

<EmptyState> (shown only when the filtered list is empty)
  icon: fa-bell-slash
  title: "You're all caught up!"
  body: "No notifications match your filters. You'll be notified when important events happen."
```

#### NotificationCard anatomy

**Container** (flex row, align-items-flex-start, gap 0.875rem, padding 1rem 1.25rem, rounded `--card-radius`, `bg-card`, shadow-sm, border-left 3px transparent, margin-bottom 0.5rem, cursor pointer):
- `.unread` → bg `bg-primary/5` (NOT `#f0f9ff` hex — use token variant; mockup hex = `#f0f9ff` = light cyan-50), border-left color `accent` (accent = primary token).
- `.priority-high` → border-left color `warning` token (amber).
- `.priority-urgent` → border-left color `destructive` token (red).
- `.priority-urgent.unread` → subtle pulse (see business logic §④).

**Left slot** (shrink-0):
- Circle icon 42px × 42px, bg `bg-{category}/10`, text `text-{category}`, displays `<i className="fas {IconCode}">`.
- **Category color palette** (use Tailwind / token expression, NOT inline hex):
  | Category | BG token | FG token | Notes |
  |----------|----------|----------|-------|
  | Donation | `bg-green-100 dark:bg-green-950/40` | `text-green-800 dark:text-green-300` | `--cat-donation` |
  | Contact  | `bg-blue-100 dark:bg-blue-950/40`   | `text-blue-800 dark:text-blue-300`   | `--cat-contact` |
  | Campaign | `bg-purple-100 dark:bg-purple-950/40` | `text-purple-800 dark:text-purple-300` | `--cat-campaign` |
  | Event    | `bg-orange-100 dark:bg-orange-950/40` | `text-orange-800 dark:text-orange-300` | `--cat-event` |
  | System   | `bg-slate-100 dark:bg-slate-800/60` | `text-slate-700 dark:text-slate-300` | `--cat-system` |
  Extract these into a tiny helper `categoryTheme(category) → { bgClass, fgClass }` in the page-components folder. NO inline hex; NO inline `style={{ ... }}`.

**Center slot** (flex-1, min-w-0):
- **Title**: `text-sm font-semibold text-foreground` — truncate to single line (flexible — current mockup does NOT clamp title, but long titles should not break layout; default to no clamp, allow 2-line wrap).
- **Body**: `text-[13px] text-muted-foreground leading-[1.4] line-clamp-2` — 2-line ellipsis clamp (webkit-line-clamp).
- **Action button** (inline below body, if `actionUrl && actionLabel`): `<Button size="sm" variant="soft-accent">`
  - Classes: `text-xs font-semibold text-primary bg-primary/10 hover:bg-primary hover:text-primary-foreground px-2.5 py-1 rounded-md`
  - Label = `{ActionLabel}`
  - onClick: `e.stopPropagation(); router.push(actionUrl);`

**Right slot** (flex-col items-end gap-2, min-w-[100px]):
- **Time** (top): `<RelativeTime date={createdDate} />` — format per mockup:
  - < 60 min: "{N} min ago"
  - < 24 h: "{N} hour(s) ago" (use floor; don't show "just now")
  - Yesterday: "Yesterday {h:mm A}"
  - This week: short day "Mon 4:30 PM" — or just "Apr 9" per mockup precedent
  - Older: "Apr 9" / "Jan 3, 2025" if prior year
  - Use `date-fns` `formatDistanceToNowStrict` + custom weekday/short-date selector.
- **Actions row** (flex gap-2 items-center):
  - Star button (`fa-star` outline when unstarred, solid when starred; color `text-muted-foreground` → `text-warning` on hover/starred). onClick: `e.stopPropagation(); toggleStar(id);`
  - Menu button (kebab `fa-ellipsis-vertical`). onClick: `e.stopPropagation(); openDropdown(id);` Hover: light muted background.
- **Dropdown menu** (absolute top-full right-0, z-50, closed by default, click-outside-closes):
  | Item | Icon | Action |
  |------|------|--------|
  | Mark as {Read/Unread} | `fa-envelope-open` / `fa-envelope` | `updateReadNotification(id)` |
  | {Star/Unstar} | `fa-star` | `toggleStarNotification(id)` |
  | Mute this type | `fa-bell-slash` | SERVICE_PLACEHOLDER toast |
  | Delete (danger) | `fa-trash` | `deleteNotification(id)` (confirm? mockup does not confirm — skip confirm for MVP; surface an undo toast) |

**Card click** (card container onClick):
- If event target is inside action button / star button / menu button / dropdown → ignore (early return — they have their own handlers).
- Else: `if (!isRead) markAsRead(id); if (actionUrl) router.push(actionUrl);`
- This matches the mockup's `handleCardClick` closure-check exactly.

#### Filter Bar

**Status chips** (4 — pill-shaped, one active at a time — controlled):
| Chip | Value | Filter Applied |
|------|-------|----------------|
| All | `all` | No read/starred filter |
| Unread | `unread` | `isRead === false` |
| Read | `read` | `isRead === true` |
| Starred | `starred` | `isStarred === true` (ignores read status) |

**Category dropdown** (`<ApiSelect>` not needed — static list):
| Option | Value |
|--------|-------|
| All Categories | `""` (default) |
| Donation | `Donation` |
| Contact | `Contact` |
| Campaign | `Campaign` |
| Event | `Event` |
| System | `System` |

**Priority dropdown** (static):
| Option | Value |
|--------|-------|
| All Priorities | `""` (default) |
| Normal | `Normal` |
| High | `High` |
| Urgent | `Urgent` |

**Behaviour**: any filter change resets `pageIndex = 0`, empties accumulated list, re-fetches page 1. Active chip visibly distinguishable (accent bg).

#### Page Widgets & Summary Cards

Widgets: NONE as standalone KPI cards (the "unread badge" lives inline on the page title, NOT as a widget row). The `Grid Layout Variant` stays `widgets-above-grid` because we render a custom `<ScreenHeader>` above the custom body — this is to preserve the Variant B convention without a duplicate toolbar header from `DataTableContainer`. Since we do NOT use `DataTableContainer` at all, there is no duplicate header to worry about.

**Inbox Summary GQL Query** (new):
- Query name: `getInboxSummary`
- Handler: `GetInboxSummaryQuery` → returns
  ```
  NotificationInboxSummaryDto {
    totalCount: int,
    unreadCount: int,
    starredCount: int,
    categoryCounts: [{ category: string, count: int }],    // 5 rows
    priorityCounts: [{ priority: string, count: int }]     // 3 rows
  }
  ```
- All counts scoped to `ToUserId = currentUserId AND IsDeleted = false`.
- Used for the inline unread badge ("4 unread") and optionally for category-chip counts in a future iteration. In this first build, only `unreadCount` is surfaced in the ScreenHeader.

### Grid Aggregation Columns

N/A (no grid).

### User Interaction Flow (non-standard FLOW — no mode routing)

1. User opens `/crm/notification/notificationcenter` → page mounts → fetches `getInboxNotifications(pageIndex=0, pageSize=20)` + `getInboxSummary` in parallel.
2. Server returns scoped list (`ToUserId = currentUserId`), ordered by `CreatedDate DESC`. Client groups by date.
3. User clicks a **filter chip** → state updates, re-fetch page 1.
4. User changes **Category dropdown** → state updates, re-fetch.
5. User changes **Priority dropdown** → state updates, re-fetch.
6. User **clicks a card body** → if unread, mark-read (optimistic + mutation); if `actionUrl` present, `router.push(actionUrl)`.
7. User **clicks action button** → `e.stopPropagation(); router.push(actionUrl);` (no status change).
8. User **clicks star** → toggle star (optimistic + `toggleStarNotification` mutation).
9. User **opens menu** → dropdown visible; clicking outside closes all dropdowns.
10. User **clicks Mark as Read/Unread** from menu → toggles + closes dropdown + re-fetches summary.
11. User **clicks Star/Unstar** from menu → toggles.
12. User **clicks Mute this type** from menu → SERVICE_PLACEHOLDER toast + closes dropdown.
13. User **clicks Delete** from menu → soft-delete mutation + remove from list (optimistic) + toast "Notification deleted".
14. User **clicks "Mark All as Read"** header button → `updateReadAllNotifications` + optimistic set-all-read + summary re-fetch.
15. User **clicks "Notification Settings"** header button → `router.push("/{lang}/crm/notification/notificationtemplate")`.
16. User scrolls to bottom → clicks **"Load More Notifications"** → `pageIndex += 1`, fetch, append.
17. If the filtered list is empty → render `<EmptyState>` ("You're all caught up!").

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to Notification.

**Canonical Reference**: NotificationTemplate (#36) — sibling in same module, FE folder layout & service folder precedent; but NotificationCenter is a **non-standard FLOW** so view-page.tsx/3-mode pattern does NOT transfer. For the inbox-UI specifically, there is no canonical reference — it is bespoke.

| Canonical (NotificationTemplate #36) | → Notification | Context |
|-----------|--------------|---------|
| NotificationTemplate | Notification | Entity/class name |
| notificationTemplate | notification | Variable/field names |
| NotificationTemplateId | NotificationId | PK field |
| NotificationTemplates | Notifications | Table name, collection |
| notification-template | notification-center | FE route segment (`notificationtemplate` → `notificationcenter`) |
| notificationtemplate | notificationcenter | FE folder, import paths |
| NOTIFICATIONTEMPLATE | NOTIFICATIONCENTER | Grid code, menu code |
| notify | notify | DB schema (SAME) |
| Notify | Notify | Backend group name (SAME) |
| NotifyModels | NotifyModels | Namespace suffix (SAME — keep pre-existing `SharedModels` header on Notification.cs) |
| CRM_NOTIFICATION | CRM_NOTIFICATION | Parent menu code (SAME) |
| CRM | CRM | Module code (SAME) |
| crm/notification/notificationtemplate | crm/notification/notificationcenter | FE route path |
| notify-service | notify-service | FE service folder (SAME) |
| notify-queries | notify-queries | GQL queries folder (SAME) |
| notify-mutations | notify-mutations | GQL mutations folder (SAME) |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend — Modify (ALIGN adds)

| # | File | Path | Change |
|---|------|------|--------|
| 1 | Entity | `Base.Domain/Models/NotifyModels/Notification.cs` | Add 7 columns (`NotificationTemplateId`, `Category`, `Priority`, `IconCode`, `IconColor`, `ActionUrl`, `ActionLabel`, `IsStarred`) + nav property `NotificationTemplate? NotificationTemplate { get; set; }`. Update `Create()` factory + `Validate()`. Keep existing `namespace Base.Domain.Models.SharedModels;` header. |
| 2 | EF Config | `Base.Infrastructure/Data/Configurations/NotifyConfigurations/NotificationConfiguration.cs` | Add column property configs (maxlen + defaults) + 4 indexes (Composite ToUserId+IsDeleted+CreatedDate DESC; Composite ToUserId+IsRead+IsDeleted; Composite ToUserId+IsStarred+IsDeleted; Single on Category; Single on Priority) + nav `HasOne(x => x.NotificationTemplate).WithMany().HasForeignKey(x => x.NotificationTemplateId).OnDelete(DeleteBehavior.SetNull)`. |
| 3 | NotificationTemplate Entity | `Base.Domain/Models/NotifyModels/NotificationTemplate.cs` | Add inverse nav `public ICollection<Notification> Notifications { get; set; } = new List<Notification>();` |
| 4 | Schemas | `Base.Application/Schemas/NotifySchemas/NotificationSchemas.cs` | Add 8 new fields on `NotificationRequestDto` + `NotificationResponseDto` (Category, Priority, IconCode, IconColor, ActionUrl, ActionLabel, IsStarred, NotificationTemplateId, NotificationTemplateTitle). Add `NotificationInboxSummaryDto` (+ `CategoryCountDto`, `PriorityCountDto`). Keep existing `NotificationUnreadDto`. Namespace: keep `Base.Application.Schemas.SharedSchemas` (pre-existing). |
| 5 | Existing Create Command | `Base.Application/Business/NotifyBusiness/Notifications/Commands/CreateNotification.cs` | Extend validator — validate new fields (whitelist Category/Priority, optional FK NotificationTemplateId exists). No handler changes required (Adapt covers new fields). |
| 6 | Existing Update Command | `Base.Application/Business/NotifyBusiness/Notifications/Commands/UpdateNotification.cs` | Same as CreateNotification — extend validator, no handler change. |
| 7 | Existing GetNotifications Query | `Base.Application/Business/NotifyBusiness/Notifications/Queries/GetNotifications.cs` | Keep as-is for backwards compatibility (it's used by legacy ApplyGridFeatures path). NO changes. |
| 8 | Existing GetUserNotifications Query | `Base.Application/Business/NotifyBusiness/Notifications/Queries/GetUserNotifications.cs` | Keep as-is — top-nav bell consumer. No changes. |
| 9 | Existing NotificationMutations | `Base.API/EndPoints/Notify/Mutations/NotificationMutations.cs` | Add 2 new mutations: `ToggleStarNotification(int notificationId)` and `MuteNotificationType(int notificationTemplateId)`. Keep existing. |
| 10 | Existing NotificationQueries | `Base.API/EndPoints/Notify/Queries/NotificationQueries.cs` | Add `GetInboxNotifications(InboxFilterRequest)` + `GetInboxSummary()`. Keep `GetNotifications`, `GetUserNotifications`, `GetNotificationById`. |
| 11 | SharedMappings | `Base.Application/Mappings/SharedMappings.cs` | Extend existing Notification mappings (lines 113-120) — Mapster covers new flat props by default; no explicit adds needed unless overrides. Ensure `NotificationResponseDto` populates from `NotificationTemplateTitle` via `src => src.NotificationTemplate.NotificationTemplateTitle` — add explicit `Map()` for this nav-field. |

### Backend — Create (new)

| # | File | Path |
|---|------|------|
| 12 | Toggle Star Command | `Base.Application/Business/NotifyBusiness/Notifications/Commands/ToggleStarNotification.cs` |
| 13 | Mute Type Command (placeholder) | `Base.Application/Business/NotifyBusiness/Notifications/Commands/MuteNotificationType.cs` |
| 14 | GetInboxNotifications Query | `Base.Application/Business/NotifyBusiness/Notifications/Queries/GetInboxNotifications.cs` |
| 15 | GetInboxSummary Query | `Base.Application/Business/NotifyBusiness/Notifications/Queries/GetInboxSummary.cs` |
| 16 | EF Migration | `Base.Infrastructure/Data/Migrations/{timestamp}_AddNotificationInboxColumns.cs` (via `dotnet ef migrations add`) + snapshot update |
| 17 | DB Seed | `sql-scripts-dyanmic/NotificationCenter-sqlscripts.sql` (preserve pre-existing `dyanmic` folder typo) |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `INotifyDbContext.cs` | No change — `DbSet<Notification>` already wired (existing `NotificationMutations.cs` uses `dbContext.Notifications`). Confirm. |
| 2 | `NotifyDbContext.cs` | No change — already present. Confirm. |
| 3 | `DecoratorProperties.cs` (`DecoratorNotifyModules`) | No change — `Notification = "NOTIFICATION"` already exists. |
| 4 | `SharedMappings.cs` | See entry #11 above. |
| 5 | `MasterData` | No new MasterData TypeCodes (Category/Priority stored as strings, matching NotificationTemplate #36 pattern). |

### Frontend — Modify

| # | File | Path | Change |
|---|------|------|--------|
| 1 | Route stub | `src/app/[lang]/crm/notification/notificationcenter/page.tsx` | Replace `return <div>Need to Develop</div>` with proper page-config mount (see Frontend — Create #1). |
| 2 | DTO | `src/domain/entities/notify-service/NotificationDto.ts` | Add 8 new fields on `NotificationResponseDto` + add `NotificationInboxSummaryDto`, `CategoryCountDto`, `PriorityCountDto`. |
| 3 | GQL Query | `src/infrastructure/gql-queries/notify-queries/NotificationsQuery.ts` | Add `INBOX_NOTIFICATIONS_QUERY` (calls `getInboxNotifications`) + `INBOX_SUMMARY_QUERY` (calls `getInboxSummary`). Keep existing `NOTIFICATIONS_QUERY` and `UNREAD_NOTIFICATIONS_QUERY`. |
| 4 | GQL Mutation | `src/infrastructure/gql-mutations/notify-mutations/NotificationMutation.ts` | Add `TOGGLE_STAR_NOTIFICATION_MUTATION`, `DELETE_NOTIFICATION_MUTATION`, `DELETE_ALL_NOTIFICATIONS_MUTATION`, `MARK_ALL_READ_NOTIFICATIONS_MUTATION`, `MUTE_NOTIFICATION_TYPE_MUTATION`. Keep existing `MARK_READ_UNREAD_NOTIFICATIONS_MUTATION`. |
| 5 | Page-components barrel | `src/presentation/components/page-components/crm/notification/index.ts` | Add `export { default as NotificationCenterPage } from "./notificationcenter";` |
| 6 | Pages barrel | `src/presentation/pages/crm/notification/index.ts` | Add `export { NotificationCenterPageConfig } from "./notificationcenter";` |

### Frontend — Create

| # | File | Path |
|---|------|------|
| 1 | Route page mount | `src/app/[lang]/crm/notification/notificationcenter/page.tsx` (overwrite stub → render `<NotificationCenterPageConfig />`) |
| 2 | Page config | `src/presentation/pages/crm/notification/notificationcenter.tsx` (access-capability guard → `<NotificationCenterPage />`) |
| 3 | Folder barrel | `src/presentation/components/page-components/crm/notification/notificationcenter/index.ts` → `export { default } from "./notification-center-page";` |
| 4 | Main page | `src/presentation/components/page-components/crm/notification/notificationcenter/notification-center-page.tsx` (ScreenHeader + FilterBar + InboxList + LoadMore + EmptyState) |
| 5 | InboxList | `src/presentation/components/page-components/crm/notification/notificationcenter/inbox-list.tsx` (date-grouping + maps to NotificationCard) |
| 6 | NotificationCard | `src/presentation/components/page-components/crm/notification/notificationcenter/notification-card.tsx` (single card with all behaviours — click-body-marks-read, action-button, star, menu) |
| 7 | NotificationFilterBar | `src/presentation/components/page-components/crm/notification/notificationcenter/notification-filter-bar.tsx` (4 chips + 2 dropdowns) |
| 8 | NotificationMenu | `src/presentation/components/page-components/crm/notification/notificationcenter/notification-menu.tsx` (Radix dropdown — Mark Read/Unread, Star/Unstar, Mute, Delete) |
| 9 | EmptyState | `src/presentation/components/page-components/crm/notification/notificationcenter/empty-state.tsx` (icon + heading + body) |
| 10 | Category theme helper | `src/presentation/components/page-components/crm/notification/notificationcenter/category-theme.ts` (`categoryTheme(category): { bgClass, fgClass }`) |
| 11 | RelativeTime helper | `src/presentation/components/page-components/crm/notification/notificationcenter/relative-time.ts` (format per mockup rules) |
| 12 | Zustand store | `src/application/stores/notification-center-stores/notification-center-store.ts` (filters state, page index, accumulated list, optimistic-update helpers) |
| 13 | Zustand store barrel | `src/application/stores/notification-center-stores/index.ts` |
| 14 | Stores barrel update | `src/application/stores/index.ts` — append `export * from "./notification-center-stores";` |
| 15 | useNotificationCenter hook | `src/presentation/components/page-components/crm/notification/notificationcenter/use-notification-center.ts` (Apollo hooks: inbox query, summary query, mutations; wires store state → GQL variables; exposes handlers for card / menu / header actions) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `notify-service-entity-operations.ts` | Add `NOTIFICATIONCENTER` operations block (even if some entries are stubs — document contract; `getAll` → `INBOX_NOTIFICATIONS_QUERY`, `delete` → `DELETE_NOTIFICATION_MUTATION`, etc.) |
| 2 | sidebar / menu config | (Auto-driven by DB seed — no manual wiring; verify menu renders under CRM → Notification after seed runs.) |
| 3 | route config | Next.js App Router — file-based, already resolved by creating `/crm/notification/notificationcenter/page.tsx`. No central route config edits needed. |
| 4 | `notify-service/index.ts` | Ensure `NotificationDto` additions exported; if `NotificationInboxSummaryDto` new — add to barrel. |
| 5 | `notify-queries/index.ts` | Add `export * from "./NotificationsQuery";` is already there — verify new named exports flow through. |
| 6 | `notify-mutations/index.ts` | Same — verify new named exports flow through. |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: ALIGN

MenuName: Notification Center
MenuCode: NOTIFICATIONCENTER
ParentMenu: CRM_NOTIFICATION
Module: CRM
MenuUrl: crm/notification/notificationcenter
GridType: FLOW

MenuCapabilities: READ, MODIFY, DELETE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, MODIFY, DELETE

GridFormSchema: SKIP
GridCode: NOTIFICATIONCENTER
---CONFIG-END---
```

Notes:
- `MenuCapabilities` intentionally excludes CREATE/TOGGLE/IMPORT/EXPORT — notifications are system-generated, not user-created. TOGGLE (activate/deactivate entity) is unused on this screen.
- No `Grid` row in seed (custom index — no standard DataTable), no `GridColumns`, no `GridFields`, no `GridFormSchema` (SKIP is correct per FLOW convention).
- `NOTIFICATIONCENTER` menu ordering: `OrderBy = 2` under `CRM_NOTIFICATION` (MenuId 267), following `NOTIFICATIONTEMPLATE` (OrderBy 1) per MODULE_MENU_REFERENCE.md.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `NotificationQueries` (existing — extended)
- Mutation type: `NotificationMutations` (existing — extended)

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getInboxNotifications` (NEW) | `PaginatedApiResponse<NotificationResponseDto[]>` | `pageIndex: Int!, pageSize: Int = 20, statusFilter: String (all\|unread\|read\|starred), category: String, priority: String` |
| `getInboxSummary` (NEW) | `ApiResponse<NotificationInboxSummaryDto>` | — |
| `getNotifications` (KEEP) | `PaginatedApiResponse<NotificationResponseDto[]>` | `GridFeatureRequest` (legacy grid) — NOT consumed by this screen. |
| `userNotifications` (KEEP) | `ApiResponse<NotificationUnreadDto>` | — (top-nav bell — backwards-compat) |
| `getNotificationById` (KEEP) | `ApiResponse<NotificationResponseDto>` | `notificationId: Int!` |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `updateReadNotification` (KEEP) | `notificationId: Int!` | `ApiResponse<Boolean>` |
| `updateReadAllNotifications` (KEEP — FIX to scope `ToUserId == currentUserId`) | — | `ApiResponse<Boolean>` |
| `deleteNotification` (KEEP) | `notificationId: Int!` | `ApiResponse<Boolean>` |
| `deleteAllNotifications` (KEEP — optional "Clear Inbox" — NOT on mockup, leave wired but UI-hidden for MVP) | — | `ApiResponse<Boolean>` |
| `toggleStarNotification` (NEW) | `notificationId: Int!` | `ApiResponse<Boolean>` |
| `muteNotificationType` (NEW — SERVICE_PLACEHOLDER) | `notificationTemplateId: Int!` (or fallback to `category: String!` if templateId not available on the row) | `ApiResponse<Boolean>` (always success for MVP) |
| `createNotification` (KEEP) | `NotificationRequestDto` | `ApiResponse<NotificationRequestDto>` (consumed by server-side trigger handlers, not the UI) |
| `updateNotification` (KEEP) | `NotificationRequestDto` | `ApiResponse<NotificationRequestDto>` (admin-only; not on mockup) |
| `activateDeactivateNotification` (KEEP) | `notificationId: Int!` | `ApiResponse<NotificationRequestDto>` (unused by UI) |

**NotificationResponseDto fields after ALIGN** (what FE receives):
| Field | Type | Notes |
|-------|------|-------|
| notificationId | number | PK |
| notificationTypeId | number | legacy — FE ignores |
| moduleId | string (Guid) | legacy — FE ignores except for admin views |
| fromUserId | number \| null | null = "System" |
| toUserId | number | matches current user |
| notificationTitle | string | card title |
| notificationText | string | card body (line-clamp-2) |
| category | string | "Donation" \| "Contact" \| "Campaign" \| "Event" \| "System" (NEW) |
| priority | string | "Normal" \| "High" \| "Urgent" (NEW) |
| iconCode | string | e.g. "fa-hand-holding-dollar" (NEW) |
| iconColor | string \| null | hex — optional (NEW) |
| actionUrl | string \| null | route target (NEW) |
| actionLabel | string \| null | button label (NEW) |
| isRead | boolean | — |
| isStarred | boolean | (NEW) |
| notificationTemplateId | number \| null | (NEW) |
| notificationTemplateTitle | string \| null | Flattened from nav (NEW) |
| createdDate | string (ISO) | — |
| isActive | boolean | inherited |
| module | { moduleName: string } \| null | legacy |
| fromUser | { userId, firstName, lastName, ... } \| null | — |

**NotificationInboxSummaryDto** (NEW):
```ts
export interface NotificationInboxSummaryDto {
  totalCount: number;
  unreadCount: number;
  starredCount: number;
  categoryCounts: { category: string; count: number }[];
  priorityCounts: { priority: string; count: number }[];
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no new errors in Base.Domain / Base.Infrastructure / Base.Application / Base.API
- [ ] `dotnet ef migrations add AddNotificationInboxColumns` — migration generated, SQL inspected (5 ALTER COLUMN + 4 CREATE INDEX)
- [ ] `pnpm tsc --noEmit` — no new errors in `src/domain/entities/notify-service`, `src/application/stores/notification-center-stores`, `src/presentation/components/page-components/crm/notification/notificationcenter`
- [ ] `pnpm dev` — page loads at `/en/crm/notification/notificationcenter`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Page loads in < 2s with test data (20 notifications + summary)
- [ ] Inbox groups render under "TODAY" / "YESTERDAY" / "EARLIER THIS WEEK" / "OLDER" headings based on `createdDate`
- [ ] Filter chip "All" active by default; clicking "Unread" filters to unread-only
- [ ] Filter chip "Read" → only read rows; "Starred" → only starred rows
- [ ] Category dropdown filters list to that category
- [ ] Priority dropdown filters list to that priority
- [ ] Category + Priority + Status chip filters COMBINE (AND)
- [ ] Unread row has accent left-border + light bg
- [ ] High-priority row has amber left-border
- [ ] Urgent-priority+unread row has red left-border + pulse animation
- [ ] Category icon renders in circle with correct category color (5 categories)
- [ ] Click card body: unread → becomes read (optimistic + server); if actionUrl present → navigates
- [ ] Click action button: navigates via router.push; does NOT mark read
- [ ] Click star: toggles starred state; persists on refresh
- [ ] Click kebab: dropdown opens; click outside closes all dropdowns
- [ ] Dropdown → Mark as Read/Unread: toggles state
- [ ] Dropdown → Star/Unstar: toggles
- [ ] Dropdown → Mute this type: toast appears ("Muted. You can unmute from Notification Settings."); no error
- [ ] Dropdown → Delete: removes from list optimistically; toast "Notification deleted"
- [ ] Header "Mark All as Read" button: sets all visible rows to read; unread badge goes to 0
- [ ] Header "Notification Settings" button: navigates to `/en/crm/notification/notificationtemplate`
- [ ] Load More: appends next 20 rows; does not duplicate rows
- [ ] Empty state renders when filter combo yields 0 rows
- [ ] Unread badge in ScreenHeader matches `summary.unreadCount`
- [ ] Top-nav bell count (global) stays in sync after mark-read (re-fetch `userNotifications`)
- [ ] Auth: only notifications with `ToUserId == currentUserId` are returned
- [ ] Auth: attempting `updateReadNotification(id)` for another user's notification returns 404/403 (validator check — see §④)
- [ ] Permissions: respect `canModify` for star/read toggles; `canDelete` for delete

**UI Uniformity (5 mandatory greps — must return 0 matches in the new files):**
- [ ] No inline hex colors in TSX (`#[0-9a-fA-F]{3,6}` in `page-components/crm/notification/notificationcenter/**/*.tsx`)
- [ ] No inline pixel spacing (`style=\\{\\{.*(padding|margin).*px`)
- [ ] No raw "Loading…" strings (use `<Skeleton>` / `<LayoutLoader>`)
- [ ] Variant B confirmed: `<ScreenHeader>` used, no competing `DataTableContainer` with `showHeader` mismatch
- [ ] No inline `fontSize` / `color:` overrides

**DB Seed Verification:**
- [ ] Menu row `NOTIFICATIONCENTER` appears in sidebar under CRM → Notification (OrderBy 2)
- [ ] MenuCapabilities correctly seeded for BUSINESSADMIN (READ, MODIFY, DELETE)
- [ ] GridFormSchema = SKIP (no form schema in seed — FLOW pattern)
- [ ] No Grid / GridColumns / GridFields rows seeded for this screen (custom UI — none required)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **Non-standard FLOW** — there is NO `view-page.tsx`, NO 3-URL-mode routing, NO FORM layout, NO DETAIL layout. `index-page.tsx` IS the entire screen. Do NOT generate a `view-page.tsx` just because the template manifest mentions it. Parallels #44 Organizational Unit and #46 Event Ticketing (both non-standard FLOWs).
- **No `+Add` button** — notifications are system-generated by server-side trigger handlers (out of scope for this screen). The ScreenHeader MUST NOT include an Add button.
- **Notification entity namespace inconsistency** (pre-existing, DO NOT fix):
  - File lives in `Base.Domain/Models/NotifyModels/Notification.cs`
  - But `namespace Base.Domain.Models.SharedModels;` (file header)
  - Consequently Mapster config is in `SharedMappings.cs` not `NotifyMappings.cs`
  - EF config is in `NotifyConfigurations/NotificationConfiguration.cs`
  - Keep this split to avoid breaking nav-property references on `Module`, `User.FromNotification`, `User.ToNotification`, `Company.Notifications`. Do NOT attempt to move the namespace — it would cascade into multiple unrelated files.
- **User scoping is security-critical**: EVERY query/mutation touching notifications MUST filter by `ToUserId == currentUserId`. Verify the existing `updateReadAllNotifications` handler does this — if not, add the scope in this ALIGN pass (see ISSUE-1).
- **GetInboxNotifications vs legacy `getNotifications`**: keep both queries. Legacy `getNotifications` uses `GridFeatureRequest` / `ApplyGridFeatures` (from other admin screens). New `getInboxNotifications` is the FE's primary consumer, takes simple args, filters by current user automatically. Don't try to consolidate.
- **Mapster flat-field for `notificationTemplateTitle`**: explicit `Map(dest => dest.NotificationTemplateTitle, src => src.NotificationTemplate!.NotificationTemplateTitle)` — required for EF projection to surface the template title.
- **Category / Priority stored as strings** (not MasterData FK) — follows NotificationTemplate #36 precedent. Do NOT introduce `NOTIFICATIONCATEGORY` / `NOTIFICATIONPRIORITY` MasterData TypeCodes unless user-editable values are required later.
- **Card-body click decision**: click on card body marks-read AND optionally navigates (if actionUrl). Click on action button only navigates (no status change). Click on star / menu button only does its thing. This exact ordering must be preserved — matches mockup `handleCardClick` closure check.
- **CompanyId on Notification is nullable** (`int?`) — system/global notifications may have `CompanyId == null`. Query must allow `CompanyId == currentCompanyId OR CompanyId == null` for system messages. (Confirm with user — mockup is ambiguous; default to company-scoped only for MVP, flag as ISSUE-7.)
- **Test timezone assumption**: "Today / Yesterday" grouping is user-timezone-dependent. For MVP, use the browser's local timezone (`new Date()`); later, align with the user's preference from `/setting/general-setting`. Flag as ISSUE-5.
- **Existing FE files are minimal** (DTO has basic shape; one query; one mutation). ALIGN the DTO additively, do NOT restructure.
- **Route stub at `src/app/[lang]/crm/notification/notificationcenter/page.tsx`** is just `return <div>Need to Develop</div>` — replace with `<NotificationCenterPageConfig />` mount.
- **Seed folder typo** (`sql-scripts-dyanmic/`) is intentional/pre-existing per #24/#27/#31/#36 precedent — preserve.

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ **SERVICE_PLACEHOLDER — "Mute this type"**: full UI (dropdown item + icon + toast) is implemented. Server mutation `muteNotificationType(templateId)` accepts the call and returns success, but does NOT actually write a mute preference (no `UserNotificationMute` table yet). On the next trigger for that template, notifications WILL still be created. Flag as ISSUE-2. User-facing toast: "Muted. You can unmute from Notification Settings." — wording from mockup.
- ⚠ **SERVICE_PLACEHOLDER — "Delete All / Clear Inbox"** (not on mockup, but the existing `DeleteAllNotifications` mutation is kept available in the contract): UI deliberately hides this button for MVP. No placeholder needed if UI-hidden.
- ⚠ **Notification creation by server-side triggers** (donation received, etc.) is OUT OF SCOPE for this screen. The mockup's sample data simulates what the trigger handlers would create. Actual trigger wiring lives in the business-event publish-subscribe infrastructure (not this build). Document in Build Log §⑬ that rows must be seeded manually for E2E testing until triggers are live. Flag as ISSUE-3.

Full UI must be built (all buttons, dropdowns, date groups, pulse animation, empty state, load-more). Only the two placeholder handlers above are mocked.

**Pre-flagged ISSUEs** (to be tracked in §⑬ Known Issues):

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | HIGH | BE Security | Existing `updateReadAllNotifications` handler may not filter by `ToUserId == currentUserId`. Review and FIX in this ALIGN pass — a cross-user mass-read would be a data-integrity + compliance issue. |
| ISSUE-2 | MED | Service placeholder | `muteNotificationType` has no persistence layer. UI + mutation stub built; actual mute enforcement not yet wired. |
| ISSUE-3 | MED | Test data | Notifications are system-generated; trigger handlers are out of scope. E2E testing requires manually seeded rows from `NotificationCenter-sqlscripts.sql`. |
| ISSUE-4 | MED | EF migration | Existing snapshot may already show Notification columns — verify migration diff before `ef database update`. If snapshot out-of-sync with DB (common per #27 ISSUE-2 precedent), regenerate. |
| ISSUE-5 | LOW | UX | Date grouping uses browser local TZ. Should align with user's preferred TZ from /setting/general-setting in a later enhancement. |
| ISSUE-6 | LOW | Nav prop | `Company.Notifications` inverse navigation already exists (from existing EF config). `NotificationTemplate.Notifications` inverse nav is NEW — verify added correctly. |
| ISSUE-7 | MED | Scope | Global/system notifications with `CompanyId == null` — do they surface to the user? MVP: NO (company-scoped only). Confirm with product. |
| ISSUE-8 | LOW | Perf | For users with 10k+ notifications, the "Mark All as Read" bulk update could timeout. Add `BATCH SIZE 1000` loop in handler if performance shows issues. |
| ISSUE-9 | LOW | FE | `NotificationResponseDto.moduleId` is `Guid` (string) — legacy; keep but FE should ignore it. |
| ISSUE-10 | LOW | Icon lib | Mockup uses Font Awesome (`fa-*`). Repo's preferred icon lib is `@iconify/react` (Phosphor per memory) — decision: render `<i className={"fas " + iconCode}>` directly (raw FA), matching NotificationTemplate #36 precedent. Do NOT re-map to Iconify Phosphor — would require IconCode value rewrites and break template #36 data. |
| ISSUE-11 | MED | FE | Action button's `stopPropagation` must fire BEFORE the parent `onClick` — ensure React event ordering (both on same bubble phase — use pattern from NotificationTemplate `live-preview-pane` or equivalent). |
| ISSUE-12 | LOW | A11y | Dropdown menu needs keyboard support (Escape closes, Tab cycles). Radix `DropdownMenu` provides this out-of-box — use it instead of hand-rolled dropdown. |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| — | — | — | — | (empty — no issues raised yet; pre-flagged ISSUEs from §⑫ will be opened by BUILD) | — |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

{No sessions recorded yet — filled in after /build-screen completes.}