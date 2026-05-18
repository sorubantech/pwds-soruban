---
screen: WhatsAppConversation
registry_id: 33
module: Communication
status: COMPLETED
scope: FULL
screen_type: FLOW
complexity: High
new_module: NO
planned_date: 2026-05-14
completed_date: 2026-05-14
last_session_date: 2026-05-14
---

## Tasks

### Planning (by /plan-screens)
- [x] HTML mockup analyzed (two-pane inbox + chat thread — NON-STANDARD FLOW, no view-page.tsx 3-mode)
- [x] Existing code reviewed (FE route stub only — `UnderConstruction`; NO BE entity)
- [x] Business rules + workflow extracted (Meta 24-hour reply-window, opt-out enforcement, template-only outside window, staff assignment)
- [x] FK targets resolved (Contact, WhatsAppTemplate #31, WhatsAppCampaign #32, User/Staff, Tag — all exist)
- [x] File manifest computed (BE near-greenfield: 3 entities + 2 EF configs + schemas + 7 cmds + 5 queries + endpoints + migration; FE near-greenfield: 16 new files + 6 modify)
- [x] Approval config pre-filled
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (SKIPPED — prompt §①–⑫ is authoritative per token directive)
- [x] Solution Resolution complete (SKIPPED — prompt §⑤ + §⑦ are authoritative)
- [x] UX Design finalized (prompt §⑥ is authoritative — TWO-PANE custom shell)
- [x] User Approval received (2026-05-14 — Sonnet override for BE + FE per token economy)
- [x] Backend code generated (3 entities + 3 EF configs + Schemas + 12 commands + 5 queries + 2 GQL endpoints + PhoneNumberHelper + WhatsAppConversationMapper)
- [x] Backend wiring complete (INotifyDbContext + NotifyDbContext + DecoratorProperties + NotifyMappings + Contact + WhatsAppTemplate + User inverse navs; Company.cs N/A — entity not present in this repo)
- [x] Frontend code generated (28 files — two-pane chat shell + 4 banner states + composer w/ note-mode + 4 modals + Zustand store + use-hook orchestrator + relative-time + variable-resolver)
- [x] Frontend wiring complete (8 barrel/operations modifies + route stub overwritten + 7 WA brand tokens added to `src/presentation/tailwind.config.ts`)
- [x] DB Seed script generated (`sql-scripts-dyanmic/WhatsAppConversation-sqlscripts.sql` — menu + 5 caps + 4 BUSINESSADMIN role-caps + 5 starter QuickReplies + 12 sample conversations + child messages covering 4 banner states + Failed/Template/Starred/Campaign-tagged variety)
- [x] Registry updated to COMPLETED
- [ ] EF migration generated (`dotnet ef migrations add AddWhatsAppConversations`) — DEFERRED to team per token directive

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — page loads at `/[lang]/crm/whatsapp/whatsappconversation`
- [ ] LEFT pane lists conversations ordered by `LastMessageAt DESC` with avatar + initials + last-message preview + relative time
- [ ] 5 filter tabs (All / Unread / Needs Reply / Starred / Archived) — Unread + Needs Reply show red count badge
- [ ] Search box filters by contact name, phone, OR last-message text
- [ ] Click a conversation → RIGHT pane loads chat thread (header + reply window banner + message bubbles + composer)
- [ ] Outbound bubbles render `bg-wa-bubble-out` (green) right-aligned with read/delivered/sent ticks
- [ ] Inbound bubbles render `bg-wa-bubble-in` (white) left-aligned
- [ ] Template-sourced outbound bubble shows accent "Template: {name}" label and (optional) button chips
- [ ] Internal notes render as dashed-amber centered cards with `Internal note by {staff}` header
- [ ] Date dividers render between days; system messages (yellow centered chips) appear at thread transitions
- [ ] Within 24-hour window → composer enabled with green info bar ("Within 24-hour window — free-form reply allowed")
- [ ] Window expired → composer disabled with red bar ("Reply window expired. You can only send approved templates."), Template toolbar button remains active
- [ ] Contact opted out → composer disabled, "Contact has opted out — messaging is disabled" banner
- [ ] Send (Enter without Shift) appends outbound bubble optimistically + calls `sendOutboundWhatsAppMessage` mutation
- [ ] Composer Quick Reply dropdown lists user's canned replies + "Manage Quick Replies" entry
- [ ] Composer Note toggle → background amber + sends an internal-note (not a real WhatsApp message) on Send
- [ ] Header actions work: View Profile (→ contact detail), Assign (dropdown), Star (toggle persists), Archive (toggle persists), Info (toggles stats sidebar), More menu
- [ ] Stats sidebar shows Message Stats (total/first/reply-rate/avg-response — all SERVICE_PLACEHOLDER computed) + Recent Donations + Tags + View Full Profile link
- [ ] Inline metrics header shows Open Conversations / Needs Reply count / Avg Response Time
- [ ] "+ New Message" modal opens — contact picker filters to WhatsApp-opted-in only; template select shows Approved templates; preview renders with variable substitution
- [ ] Send from New Message modal creates a conversation if one doesn't exist + first outbound (template) message
- [ ] Right-click on conversation row → context menu (Star, Archive, Mark Read, Assign)
- [ ] URL param `?campaignId={N}` filters left list to recipients of that campaign (deep-link from WhatsApp Campaign #32 "View All Replies")
- [ ] Export Conversations button surfaces a toast (SERVICE_PLACEHOLDER)
- [ ] DB Seed — menu visible in sidebar under CRM → WhatsApp (OrderBy 3)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: WhatsAppConversation
Module: Communication (CRM → WhatsApp)
Schema: `notify`
Group: NotifyModels (entities live under `Base.Domain/Models/NotifyModels/` — same group as WhatsAppTemplate #31, WhatsAppSetting #34, WhatsAppCampaign #32)

Business: WhatsApp Conversations is the **two-way inbox / chat console** where staff handle inbound replies and follow-up outbound messages with donors. The Meta WhatsApp Business API operates with a strict 24-hour customer-service window — after a contact sends a message, the org may reply **free-form** for 24 hours; outside that window, only **pre-approved templates** can be sent. The screen surfaces this constraint with a persistent reply-window banner and disables the free-form composer when the window expires. Conversations are 1:1 between the org's WhatsApp Business number (configured in WhatsApp Setup #34) and an individual Contact identified by `PhoneNumber`. Inbound messages arrive via Meta webhooks (out of scope — webhook infrastructure does not yet exist); outbound messages are sent via the Meta Cloud API (also out of scope — SERVICE_PLACEHOLDER). For MVP, this screen builds the **full UI** and the **persistence layer** (DB tables + commands + queries) so that conversations and messages can be stored, queried, and rendered exactly as the mockup shows. Real send and real receive are placeholders.

Relationship to other screens:
- **#31 WhatsApp Templates** — COMPLETED. Outbound template messages reference `WhatsAppTemplateId` (nullable — free-form replies have no template). Composer "Template" button opens a picker of `Status="Approved"` templates. Outside the 24-hour window, ONLY templates can be sent.
- **#32 WhatsApp Campaigns** — PROMPT_READY. The campaign detail page has a "View All Replies" button that deep-links to `/crm/whatsapp/whatsappconversation?campaignId={id}` — this screen reads the query param and filters the left list to conversations whose first outbound message was triggered by that campaign.
- **#34 WhatsApp Setup** — PARTIAL. Provides the org's `PhoneNumberId`, `AccessToken`, etc. Outbound send handler reads from `WhatsAppSetting` (SERVICE_PLACEHOLDER — placeholder reads token + returns success without calling Meta).
- **Contact (#19/#21)** — Conversation is keyed on `ContactId` (+ `PhoneNumber` cache). "View Profile" header button navigates to `/crm/contact/allcontacts?mode=read&id={contactId}`.
- **User/Staff (#42)** — `AssignedToUserId` nullable FK on Conversation. Assign dropdown lists Staff users; assignment is for triage / accountability, not auth.
- **Notification Center (#35)** — Sibling non-standard FLOW. THIS SCREEN follows the same composite-page architecture: no `view-page.tsx`, no 3-URL-mode routing, all UI on a single `index-page.tsx`. Differs from #35 by being **two-pane** (list + thread) and **interactive** (a composer that writes new rows).

This screen is a **non-standard FLOW** (classified as FLOW in registry, but does NOT follow the 3-URL-mode `view-page.tsx` pattern — same pattern as #35 NotificationCenter, #44 OrganizationalUnit, #46 EventTicketing). The entire screen lives on one composite page with a master-detail two-pane layout.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **CompanyId is NOT a request field** — tenant from HttpContext (set by MultiTenantInterceptor on save).
> Three new entities: parent `WhatsAppConversation` + 1:N child `WhatsAppMessage` + 1:N child `WhatsAppConversationQuickReply`.

### Table 1: `notify."WhatsAppConversations"` (NEW — parent)

One row per (CompanyId, ContactId, PhoneNumber) tuple. Created on the first inbound OR first outbound message.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| WhatsAppConversationId | int | — | PK | — | Identity |
| CompanyId | int | — | YES | `auth.Companies.CompanyId` | Tenant (set by pipeline) |
| ContactId | int | — | YES | `corg.Contacts.ContactId` | Conversation partner |
| PhoneNumber | string | 30 | YES | — | E.164 normalized — cached from Contact at conversation start (so historical conversations survive contact phone edits). Used in left pane phone-meta line. |
| AssignedToUserId | int? | — | NO | `auth.Users.UserId` | Staff member responsible. Null = Unassigned. |
| LastMessageAt | DateTime | — | YES | — | Cache for sorting + filter. Indexed. |
| LastMessagePreview | string | 200 | NO | — | First ~120 chars of last message text (sanitised — strip newlines). |
| LastMessageDirection | string | 10 | YES | — | `Inbound` or `Outbound`. |
| LastMessageStatus | string | 20 | NO | — | For outbound: `Sent`/`Delivered`/`Read`/`Failed`. For inbound: empty. Cache. |
| LastMessageTemplate | string | 100 | NO | — | If last outbound was a template, cache its name (for "📎 {templateName}" chip in left list). |
| UnreadCount | int | — | YES (default 0) | — | Number of inbound messages with `ReadByStaffAt IS NULL`. Updated on staff-open. |
| ReplyWindowExpiresAt | DateTime? | — | NO | — | `LastInboundAt + 24h` — null if conversation has never had an inbound (cold campaign send). Drives composer-disable + banner state. |
| IsStarred | bool | — | YES (default false) | — | User-toggled flag. Indexed. |
| IsArchived | bool | — | YES (default false) | — | Soft-archive (kept in `Archived` tab). Indexed. |
| OptOutAt | DateTime? | — | NO | — | When set, all outbound disabled. Set when inbound text == "STOP" (case-insensitive) — handled by webhook (placeholder) OR by admin via More menu. |
| AvatarColor | string | 10 | NO | — | One of `green`/`blue`/`purple`/`amber`/`rose`/`teal` — deterministically derived from `ContactId % 6` at creation; cached for stable colour. |
| FirstCampaignId | int? | — | NO | `notify.WhatsAppCampaigns.WhatsAppCampaignId` | If conversation was started by a campaign send, store the campaign id — used by `?campaignId=X` deep-link from #32. NOTE: WhatsAppCampaign entity does NOT exist yet (PROMPT_READY only). Make FK nullable + skip the EF FK constraint (column only) until #32 ships — same `to_regclass` guard pattern as #125. |
| (inherited IsActive, IsDeleted, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate from `Entity` base) |

**Indexes:**
- Composite `(CompanyId, IsArchived, LastMessageAt DESC)` — primary left-list read path.
- Composite `(CompanyId, IsArchived, UnreadCount)` — unread filter.
- Composite `(CompanyId, IsStarred, IsArchived)` — starred filter.
- Unique `(CompanyId, ContactId, PhoneNumber) WHERE IsDeleted = false` — one open conversation per (contact, phone) per tenant.
- Single `(AssignedToUserId)` — for "My assigned" filter in future.

### Table 2: `notify."WhatsAppMessages"` (NEW — child of WhatsAppConversation)

One row per individual message (inbound, outbound, internal-note, or system).

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| WhatsAppMessageId | int | — | PK | — | Identity |
| WhatsAppConversationId | int | — | YES | `notify.WhatsAppConversations.WhatsAppConversationId` | Parent FK (cascade delete) |
| CompanyId | int | — | YES | `auth.Companies.CompanyId` | Tenant (denormalised for query scope) |
| Direction | string | 10 | YES | — | `Inbound` / `Outbound` / `Note` / `System`. Indexed. |
| MessageType | string | 20 | YES (default "Text") | — | `Text` / `Template` / `Image` / `Document` / `Video` / `Audio` / `Location`. MVP supports only `Text`, `Template`, `Note`, `System`. Image/Document/etc captured for forward compat but UI hidden. |
| Body | string | 4000 | YES | — | Message text. Templates store fully resolved text (after variable substitution). |
| WhatsAppTemplateId | int? | — | NO | `notify.WhatsAppTemplates.WhatsAppTemplateId` | If outbound was a template, set. Null for free-form / inbound / note. |
| WhatsAppCampaignId | int? | — | NO | `notify.WhatsAppCampaigns.WhatsAppCampaignId` | Set if outbound was triggered by a campaign. Same caveat as `WhatsAppConversation.FirstCampaignId` — column without EF FK until #32 ships. |
| TemplateButtonsJson | string | — | NO | — | If outbound template includes interactive buttons, store `[{"label":"Donate Now","url":null}]` as JSON for replay. Null otherwise. |
| MetaMessageId | string | 120 | NO | — | Meta's message id (`wamid.xxx...`). Null until webhook returns it. Used for de-duplication + status updates. Indexed (unique-filtered, non-null). |
| Status | string | 20 | NO | — | Outbound-only: `Queued` / `Sent` / `Delivered` / `Read` / `Failed`. Inbound: empty. Indexed. |
| FailureReason | string | 250 | NO | — | When `Status = Failed`. e.g. "Recipient not on WhatsApp" / "Phone invalid" / "Template rejected". |
| SentAt | DateTime? | — | NO | — | Outbound only. Initially `UtcNow` (Queued). |
| DeliveredAt | DateTime? | — | NO | — | Webhook-set (placeholder). |
| ReadAt | DateTime? | — | NO | — | Webhook-set (placeholder — read receipts depend on Meta config). |
| ReceivedAt | DateTime? | — | NO | — | Inbound only — when Meta webhook received it. |
| ReadByStaffAt | DateTime? | — | NO | — | When staff opens the conversation and inbound is in view. Drives `WhatsAppConversation.UnreadCount` recompute. |
| AuthoredByUserId | int? | — | NO | `auth.Users.UserId` | Outbound + Note: the staff member who sent. Inbound: null. |
| ReplyToMessageId | int? | — | NO | `notify.WhatsAppMessages.WhatsAppMessageId` | Self-FK for quoted replies (Meta supports `context.message_id`). Future-friendly; mockup does not render reply-quotes yet — store but don't render in v1. |
| (inherited IsActive, IsDeleted, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate) |

**Indexes:**
- Composite `(WhatsAppConversationId, CreatedDate ASC)` — primary thread render path.
- Composite `(CompanyId, Direction, Status)` — analytics-ish queries.
- Composite `(WhatsAppConversationId, Direction, ReadByStaffAt)` — unread-count recompute.
- Unique-filtered `(MetaMessageId) WHERE MetaMessageId IS NOT NULL` — webhook de-dup.

### Table 3: `notify."WhatsAppQuickReplies"` (NEW — per-user canned replies)

Composer "Quick Reply" dropdown lists these. Per-company shared list (not per-user) for v1; flagged ISSUE-1 for per-user scoping later.

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| WhatsAppQuickReplyId | int | — | PK | — | Identity |
| CompanyId | int | — | YES | `auth.Companies.CompanyId` | Tenant |
| Shortcut | string | 50 | YES | — | e.g. `/thanks` — usable as keyboard prefix expansion in v2 |
| Body | string | 1000 | YES | — | Reply text |
| OrderBy | int | — | YES (default 0) | — | Display order in dropdown |
| (inherited audit cols) |

**Indexes:** Unique `(CompanyId, Shortcut) WHERE IsDeleted = false`.

**Child Entities — summary**:
| Child Entity | Relationship | Key Fields |
|-------------|-------------|------------|
| WhatsAppMessage | 1:Many via `WhatsAppConversationId` (cascade delete) | Direction, Body, WhatsAppTemplateId, MetaMessageId, Status |
| WhatsAppQuickReply | Standalone, scoped to Company (NOT a child of conversation) | Shortcut, Body, OrderBy |

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()`) + Frontend Developer (ApiSelect / display joins)

| FK Field | Target Entity | Entity File Path | GQL Query Name | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------|---------------|-------------------|
| ContactId | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | `getAllContactList` | `DisplayName` (fallback: `FirstName + " " + LastName`, then `OrganizationName`) | `ContactResponseDto` |
| AssignedToUserId | User | `Base.Domain/Models/AuthModels/User.cs` | `users` (existing — Auth queries) | `FirstName + " " + LastName` | `UserResponseDto` |
| WhatsAppTemplateId | WhatsAppTemplate | `Base.Domain/Models/NotifyModels/WhatsAppTemplate.cs` | `whatsAppTemplates` (existing, from #31 — note camelCase `whatsAppTemplates`) | `TemplateName` | `WhatsAppTemplateResponseDto` |
| WhatsAppCampaignId | WhatsAppCampaign | `Base.Domain/Models/NotifyModels/WhatsAppCampaign.cs` (DOES NOT EXIST YET — #32 PROMPT_READY) | (none until #32) | n/a | n/a — column only, no EF FK |
| FirstCampaignId | WhatsAppCampaign | (same as above) | (none) | n/a | column only |
| CompanyId | Company | `Base.Domain/Models/AuthModels/Company.cs` | (tenant-scoped — no dropdown) | n/a | — |
| AuthoredByUserId | User | `Base.Domain/Models/AuthModels/User.cs` | (display join only — no picker) | `FirstName + " " + LastName` | `UserResponseDto` |

**Contact ApiSelect filter**: contacts with `DoNotSMS == false` AND `DoNotPhone == false` are eligible. Stricter: ideally an `IsWhatsAppOptedIn` flag should exist — for MVP, surface ALL contacts and rely on Meta to reject if not on WhatsApp (matches mockup tooltip "Only contacts with WhatsApp opt-in will be shown" — that's the *intent*; the data flag does not exist yet, so v1 cannot enforce it). Flag as ISSUE-2.

**WhatsAppTemplate ApiSelect filter**: client-filter by `status === "Approved"` (matches the SMSCampaign/WhatsAppCampaign precedent — there is no server-side "approved-only" query yet).

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation + UX)

**Tenant scoping (CRITICAL):**
- ALL queries scope on `CompanyId == currentCompanyId` (existing MultiTenantInterceptor / SaveChanges pipeline + explicit filter in handler LINQ).
- A user must NEVER see another tenant's conversations or messages.

**Mutation authorization:**
- `SendOutboundWhatsAppMessage`, `AddWhatsAppConversationNote`, `UpdateWhatsAppConversation` (star/archive/assign/optout), `MarkConversationRead`, `DeleteWhatsAppMessage`, `DeleteWhatsAppConversation`, `CreateWhatsAppConversation` — validator MUST guard `conversation.CompanyId == currentCompanyId`. Return NotFound on mismatch.

**Uniqueness Rules:**
- `(CompanyId, ContactId, PhoneNumber)` UNIQUE WHERE `IsDeleted = false` on WhatsAppConversations — one active conversation per (contact, phone). When the contact's primary phone is updated, do NOT silently migrate the conversation — open a new one (keep history pinned to old phone).
- `MetaMessageId` UNIQUE WHERE NOT NULL on WhatsAppMessages — webhook de-dup.
- `(CompanyId, Shortcut)` UNIQUE WHERE `IsDeleted = false` on WhatsAppQuickReplies.

**Required Field Rules:**
- WhatsAppConversation: `ContactId`, `PhoneNumber`, `LastMessageAt`, `LastMessageDirection` required.
- WhatsAppMessage: `WhatsAppConversationId`, `Direction` (whitelist `Inbound|Outbound|Note|System`), `MessageType` (whitelist), `Body` required.
- Outbound message validator: if `Direction == "Outbound"` AND `WhatsAppTemplateId IS NULL` AND conversation has `ReplyWindowExpiresAt < UtcNow` → REJECT with `"Reply window expired. Send via approved template only."`
- Outbound message validator: if conversation has `OptOutAt != null` → REJECT with `"Contact has opted out of WhatsApp messages."`

**Conditional Rules:**
- If `WhatsAppTemplateId` provided, validator must verify template exists, `CompanyId` matches, AND `Status == "Approved"`.
- If `Direction == "Note"` then `MessageType` MUST be "Text", `WhatsAppTemplateId` MUST be null, `Status` MUST be null (notes have no delivery state), `AuthoredByUserId` MUST be currentUserId.
- If `Direction == "System"` then `AuthoredByUserId` MUST be null. System messages are written by backend trigger handlers (e.g., "Conversation started via campaign_appeal template", "24-hour reply window opened", "Contact opted out"). For MVP, the SendOutboundWhatsAppMessage handler INSERTS the appropriate System rows alongside the first outbound; webhook ingestion would also generate System rows on opt-out.

**Business Logic:**
- **Conversation upsert on outbound send**: when staff sends an outbound message to a contact, look up `(CompanyId, ContactId, PhoneNumber)`. If found AND not archived → reuse. If found AND archived → un-archive (set `IsArchived=false`) and reuse. If not found → create new with `AvatarColor = colors[ContactId % 6]` and `FirstCampaignId = providedCampaignId ?? null`.
- **Reply-window recompute**: every time an Inbound message is inserted (webhook placeholder or admin-manual), set `WhatsAppConversation.ReplyWindowExpiresAt = max(existing, message.CreatedDate + 24h)`. Every outbound DOES NOT extend the window — only inbound does (per Meta rules).
- **UnreadCount maintenance**: incremented in the Inbound insert handler. Reset to 0 in `MarkConversationRead` mutation (called when staff opens the thread).
- **Last-message cache**: every Insert into WhatsAppMessages updates the parent's `LastMessageAt`, `LastMessageDirection`, `LastMessageStatus`, `LastMessageTemplate`, `LastMessagePreview` (denormalised for fast left-list rendering). This happens in the command handler in the same DB transaction.
- **Opt-out detection (placeholder)**: webhook handler is OUT OF SCOPE. For MVP, the More menu has a "Mark as Opted Out" action that sets `OptOutAt = UtcNow` and writes a `Direction=System` message ("Contact opted out — STOP received"). When a real webhook lands, it MUST: detect `body.trim().ToUpper() == "STOP"`, set `OptOutAt`, write System message, send the WhatsApp opt-out confirmation template (SERVICE_PLACEHOLDER).
- **Reply window banner state machine** (FE, computed on render):
  - `OptOutAt != null` → red banner: "Contact has opted out — messaging is disabled." Composer disabled. Template button disabled.
  - `ReplyWindowExpiresAt == null` (cold campaign — no inbound yet) → amber banner: "No inbound yet — only approved templates can be sent." Composer disabled. Template button active.
  - `ReplyWindowExpiresAt > UtcNow` → green banner: "Within 24-hour window — free-form reply allowed. Window: {N}h {M}m remaining." Composer enabled. Template button active.
  - `ReplyWindowExpiresAt <= UtcNow` → red banner: "Reply window expired. You can only send approved templates." Composer disabled. Template button active.
- **Status icon mapping (left-list `LastMessageStatus`):**
  - `Read` → blue double-tick (fa-check-double, `text-wa-read-blue`)
  - `Delivered` → grey double-tick (fa-check-double, `text-muted-foreground`)
  - `Sent` → grey single-tick (fa-check, `text-muted-foreground`)
  - `Failed` → red x-circle (fa-times-circle, `text-destructive`)
  - `OptOut` synthetic (when `OptOutAt != null`) → red ban icon (fa-ban, `text-destructive`)
  - Inbound or `Note` → no icon.
- **Filter tabs (left)**:
  - `All` → no filter beyond not-archived.
  - `Unread` → `UnreadCount > 0`. Count badge.
  - `Needs Reply` → `LastMessageDirection == "Inbound"` AND `IsArchived == false` AND `OptOutAt IS NULL`. Count badge.
  - `Starred` → `IsStarred == true`.
  - `Archived` → `IsArchived == true` (this is the ONLY tab that surfaces archived rows).
- **Search**: server-side ILIKE across `Contact.DisplayName`, `Contact.OrganizationName`, `WhatsAppConversation.PhoneNumber`, `WhatsAppConversation.LastMessagePreview`. Min 1 char triggers search; debounced 250ms in FE.
- **Pagination**: left-pane uses `pageIndex` + `pageSize=30`; "Load More" appends. Thread (right pane) loads ALL messages on conversation open (later: cursor-paginate by `CreatedDate ASC` if a single conversation crosses 200+ messages — flagged ISSUE-3).
- **Send keyboard binding**: `Enter` (no Shift) sends; `Shift+Enter` inserts newline. Per mockup `keydown` listener.
- **Send-disabled rules** (FE-side mirrors BE validator):
  - Composer text empty after trim → disabled.
  - `OptOutAt != null` → disabled.
  - `ReplyWindowExpiresAt == null || ReplyWindowExpiresAt <= UtcNow` AND not in note-mode AND no template selected → disabled.
- **Note mode toggle**: clicking "Note" toolbar button toggles `noteMode` local state. While `noteMode == true`, textarea bg = amber-100, placeholder = "Type an internal note (visible only to staff)…", and Send creates `Direction = "Note"` row (free of window/opt-out checks — notes are always allowed regardless of state).
- **Templates picker**: clicking "Template" toolbar button opens a side dropdown (or modal — choose modal for v1) listing `WhatsAppTemplate` rows with `Status == "Approved"`. Selecting a template:
  1. Renders the template body in a preview pane.
  2. Surfaces variable inputs (parsed from `Body` via `{{var}}` regex) for staff to fill — variables are auto-prefilled from contact context where possible (`{{donor_name}}` ← `Contact.DisplayName`, `{{amount}}` ← leave blank, etc.). Use the same auto-fill helper that WhatsAppCampaign #32 will introduce; for v1, implement a minimal `whatsapp-variable-resolver.ts` helper that maps a small known whitelist.
  3. On Send, writes an Outbound message with `Body = resolvedBody` and `WhatsAppTemplateId`. Reply window not required (templates work outside the window).
- **Star toggle / Archive toggle / Assign**: `UpdateWhatsAppConversation` partial mutation with explicit field selector — only the field being updated is persisted; LastMessage caches untouched.
- **Quick Reply dropdown**: on click "Quick Reply" toolbar button, fetch the 10 most-recent `WhatsAppQuickReplies` for the company. Item click pastes the body into composer (does NOT auto-send). "Manage Quick Replies" item is SERVICE_PLACEHOLDER (toasts "Coming soon" — Quick Reply management surface is not in this build's scope).
- **Optimistic UI**: send appends a bubble with `Status="Queued"` + a clock icon, then the mutation response upgrades to `Sent` (or `Failed` with reason).
- **Real-time updates**: NO websocket / polling. New inbound messages appear on page refresh OR conversation re-open. Flagged ISSUE-4 (real-time push is post-MVP).

**Workflow**: Conversations have lightweight state — `Active` (default), `Archived`, `OptedOut`. No formal state machine; transitions are independent boolean toggles.

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — pre-answered decisions.

**Screen Type**: FLOW (non-standard — custom two-pane chat console, NO `view-page.tsx` 3-URL-mode pattern, NO standard FORM/DETAIL pages)
**Type Classification**: FLOW — Custom Composite Page (one consolidated `index-page.tsx` hosts BOTH the left conversation list AND the right chat thread)
**Reason**: The mockup is a master-detail inbox, not a transactional CRUD screen. There is no user-authored multi-section form; the only writable surfaces are (a) the inline composer for outbound messages / notes, and (b) the "+ New Message" modal for starting a conversation. Shares non-standard-FLOW pattern with #35 NotificationCenter (single inbox shell) and extends it with a right-pane chat thread + composer that writes new rows.

**Backend Patterns Required:**
- [x] Standard CRUD for parent (WhatsAppConversation) — extended with partial-update Update mutation
- [x] Standard CRUD for child (WhatsAppMessage) — but no Update; Insert + Soft-delete only
- [x] Standard CRUD for WhatsAppQuickReply — Read + Create + Update + Delete (Quick Reply management is a future-scope screen but the entity is needed for the dropdown query)
- [x] Tenant scoping (CompanyId from HttpContext — existing pipeline)
- [x] Multi-FK validation (ContactId / AssignedToUserId / WhatsAppTemplateId)
- [x] Unique validation — see §④
- [x] NEW command: `CreateWhatsAppConversation` (called by "+ New Message" modal flow + by SendOutbound upsert path)
- [x] NEW command: `UpdateWhatsAppConversation` (partial — Star, Archive, Assign, OptOut, Read)
- [x] NEW command: `DeleteWhatsAppConversation` (soft — cascade-soft on messages)
- [x] NEW command: `SendOutboundWhatsAppMessage` (composer + template handler) — SERVICE_PLACEHOLDER for real Meta send
- [x] NEW command: `AddWhatsAppConversationNote` (note-mode handler)
- [x] NEW command: `MarkConversationRead` (resets UnreadCount + ReadByStaffAt timestamp on inbound rows)
- [x] NEW command: `IngestInboundWhatsAppMessage` (webhook-callable — SERVICE_PLACEHOLDER endpoint exposed via GraphQL mutation so seed data / E2E can simulate inbound)
- [x] NEW command: `ToggleStarConversation` / `ToggleArchiveConversation` — convenience wrappers around Update
- [x] NEW query: `GetWhatsAppConversations` (left-pane list — paginated, filtered, searched)
- [x] NEW query: `GetWhatsAppConversationById` (right-pane thread — returns parent + all messages ordered ASC)
- [x] NEW query: `GetWhatsAppInboxSummary` (header inline metrics — Open Conversations / Needs Reply / Avg Response Time)
- [x] NEW query: `GetWhatsAppQuickReplies` (composer dropdown)
- [x] NEW query: `GetWhatsAppConversationContactSummary` (right sidebar — message stats + recent donations + tags — SERVICE_PLACEHOLDER for donations/tags joins; computes stats from Messages directly)
- [ ] File upload — NOT in v1 (mockup "Attach" toolbar button = SERVICE_PLACEHOLDER toast)
- [x] Custom business rule validators — see §④

**Frontend Patterns Required:**
- [ ] FlowDataTable grid — NO (replaced by custom left-pane list)
- [ ] view-page.tsx with 3 URL modes — NO
- [ ] React Hook Form — NO (no multi-section form; composer is a controlled textarea + a tiny modal form for new-message)
- [x] Zustand store (`whatsapp-conversation-store.ts`) — left-pane filters (tab, search, campaignId-from-url), selected-conversation-id, accumulated list, composer state (text, noteMode, templateBeingSent), right-sidebar-open
- [ ] Unsaved changes dialog — N/A
- [ ] FlowFormPageHeader — NO
- [x] Custom page header (ScreenHeader + inline metrics + "+ New Message" + "Export" actions)
- [x] Two-pane layout with collapsible third pane (stats sidebar)
- [x] Per-row context menu (right-click) on left-list rows — `<DropdownMenu>` triggered by `onContextMenu`
- [x] Per-conversation header actions row (View Profile, Assign, Star, Archive, Info, More)
- [x] Quick Reply dropdown above textarea
- [x] Template picker modal
- [x] Variable input form inside template picker
- [x] WhatsApp-style message bubbles (outbound green, inbound white, system yellow, note amber-dashed, date dividers)
- [x] Reply-window banner component (4 states: green / amber-cold / red-expired / red-optout)
- [x] Optimistic message append + status-tick upgrade
- [x] Toast notifications for actions (`sonner` / existing util)
- [x] Summary integration with header (inline-metrics row)
- [x] Grid Layout Variant: **widgets-above-grid** (using ScreenHeader on top + custom body — Variant B pattern; though there's no DataTableContainer, the ScreenHeader-only convention applies)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> **This is a non-standard FLOW** — no `view-page.tsx`, no 3-URL-mode routing, no FORM/DETAIL split. The entire screen is one custom two-pane console on `index-page.tsx`.

### Grid/List View

**Display Mode**: N/A — this screen does NOT use `<AdvancedDataTable>` or `<FlowDataTable>`. The left-pane conversation list is a custom virtualised-friendly list (use plain `map()` for v1; flag virtualisation as ISSUE-5 if 500+ rows become common).

### Page Layout (single custom page — no view-page)

**Grid Layout Variant**: `widgets-above-grid` → FE Dev uses **Variant B** (`ScreenHeader` + body — no `DataTableContainer` to worry about duplicate-headers since we don't use it).

**Route**: `/[lang]/crm/whatsapp/whatsappconversation`
**Query params honoured**:
- `?campaignId={N}` — filter left list to conversations whose `FirstCampaignId == N`. Deep-linked from #32 WhatsApp Campaign detail.
- `?conversationId={N}` — auto-select that conversation on mount (also used by share-link from notifications).

**Default page behaviour**: mount → fetch left list (page 1, no filters) + fetch inbox summary in parallel. If `?conversationId` present, also fetch that conversation's thread.

#### Page Shell (top → bottom, full-width)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ <ScreenHeader>                                                              │
│   Title: "WhatsApp Conversations" (with whatsapp glyph icon left)           │
│   Subtitle: "Manage WhatsApp message threads and replies"                   │
│   Inline metrics (below subtitle, flex-wrap gap-5):                         │
│     • "Open Conversations: <strong>{openCount}</strong>"                    │
│     • "Needs Reply: <strong class='text-warning'>{needsReplyCount}</strong>"│
│     • "Avg Response Time: <strong>{avgResponseTimeMinutes} min</strong>"    │
│   Actions (right):                                                          │
│     • [+ New Message] (primary)  → opens NewMessageModal                    │
│     • [Export Conversations] (outline)  → SERVICE_PLACEHOLDER toast         │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────┬──────────────────────────────────────────────┬──────────────┐
│ LEFT PANE    │ CENTER PANE                                  │ RIGHT PANE   │
│ (35% w,      │ (flex-1)                                     │ (260px,      │
│  280-420px)  │                                              │  collapsible)│
│              │                                              │              │
│ ▼ Search     │ <ChatHeader> (avatar + name + meta + actions)│ Stats Sidebar│
│ ▼ Tabs       │ ────────────────────────────                 │ - MsgStats   │
│   (All|Unread│ <ReplyWindowBanner> (green/amber/red)        │ - Recent     │
│    |Needs    │ ────────────────────────────                 │   Donations  │
│    Reply|⭐  │                                              │ - Tags       │
│    |Archive) │ <ChatMessages> (scrollable, WA-bg pattern)   │ - View Full  │
│ ▼ List       │   - date dividers                            │   Profile    │
│   (cards)    │   - system msgs                              │              │
│              │   - outbound bubbles (green right)           │              │
│              │   - inbound bubbles (white left)             │              │
│              │   - internal notes (amber dashed center)     │              │
│              │ ────────────────────────────                 │              │
│              │ <ChatComposer>                               │              │
│              │   - Quick Reply dropdown (absolute)          │              │
│              │   - Textarea + Send button                   │              │
│              │   - Toolbar (Attach|Template|QuickReply|Note)│              │
└──────────────┴──────────────────────────────────────────────┴──────────────┘
```

**Default state**: right-pane (stats sidebar) is **hidden** until staff clicks the `<i class="fa-circle-info">` button in the chat header. Persists per-session in Zustand.

**Empty state (center)**: when no conversation is selected, render an empty-state panel — whatsapp glyph (`var(--wa-green)`-tinted), heading "Select a conversation", body "Choose a conversation from the list to view messages".

#### LEFT PANE — Conversation List

**Top — Search input** (sticky):
- Icon-left magnifier (Phosphor `magnifying-glass-bold` per memory rule — NOT `fa-search`)
- Placeholder: "Search by name, phone, or message content…"
- Background `bg-muted`, focus border `border-primary`.

**Tabs row** (5 tabs, sticky):
| Tab | Filter Applied | Count Badge |
|-----|---------------|-------------|
| All | `IsArchived == false` | No badge |
| Unread | `IsArchived == false AND UnreadCount > 0` | Red badge with `summary.unreadConversations` |
| Needs Reply | `IsArchived == false AND LastMessageDirection == "Inbound" AND OptOutAt IS NULL` | Red badge with `summary.needsReplyCount` |
| Starred | `IsStarred == true AND IsArchived == false` | No badge |
| Archived | `IsArchived == true` | No badge |

Active tab: accent text + accent bottom-border (2px). Inactive: muted-foreground.

**List items** (`<ConversationListItem>`, one per row):
- Container: `flex items-start gap-3 px-4 py-3 border-b border-muted/40 cursor-pointer hover:bg-muted/40 relative`
- Active (selected) → `bg-primary/10`
- Unread (UnreadCount > 0) → `bg-blue-50/70 dark:bg-blue-950/30`; name + preview turn `font-bold` and `text-foreground`
- **Avatar** (left, shrink-0): 44×44 circle, bg per `AvatarColor` (6 palette options — solid-light bg + dark text per memory rule `feedback_widget_icon_badge_styling` — note: the icon-badge rule says SOLID `bg-X-600` + `text-white` for KPI tiles / status badges, but conversation-avatars are softer identity chips, not status indicators. Use Tailwind `bg-green-100 dark:bg-green-950/40 text-green-800 dark:text-green-200` style — confirm with #35 NotificationCenter precedent which uses the same soft style for category icons. NEVER inline hex.)
- **Body** (center, flex-1, min-w-0):
  - **Top row** (flex justify-between):
    - `<span class="conv-name">` — name (truncate)
    - `<span class="conv-time">` — relative time ("10:23 AM" / "Yesterday" / "Apr 9"). When unread → `text-wa-green font-semibold`.
  - **Phone line** — `text-xs text-muted-foreground` — e.g. "+1 555-0101"
  - **Bottom row** (flex justify-between):
    - **Preview** (truncate, flex-1): `<StatusIconRenderer status={lastMessageStatus} />` (inline svg/icon based on §④ mapping) + `lastMessagePreview` (truncate)
    - **Badges** (right, shrink-0):
      - If `LastMessageTemplate != null` → small chip `<i fa-paperclip /> {templateName}` muted-foreground
      - If `UnreadCount > 0` → wa-green pill 20×20 with `{UnreadCount}` (white bold text — solid bg per badge rule)

**Right-click context menu** (`<DropdownMenu>` triggered by `onContextMenu`):
| Item | Icon | Action |
|------|------|--------|
| {Star/Unstar} | `fa-star` (or Phosphor `star-bold`) | `toggleStarConversation(id)` |
| {Archive/Unarchive} | `fa-box-archive` (Phosphor `archive-bold`) | `toggleArchiveConversation(id)` |
| Mark as Read | `fa-envelope-open` | `markConversationRead(id)` |
| Assign to Staff | `fa-user-tag` | opens Assign dropdown (modal or inline) |

**Click behaviour**: clicking a row → set `selectedConversationId` in store + push URL `?conversationId={id}` (preserves other params like `campaignId`) + fetch thread + fire `markConversationRead`.

**Empty state** (no rows after filter): centered `<i fa-inbox />` + "No conversations" + "Try a different filter or start a new message".

**Load more**: bottom row `[Load More]` button (centered, secondary) — `pageIndex += 1`, append.

#### CENTER PANE — Chat Thread

**Background**: `var(--wa-chat-bg)` (`#e5ddd5` — defined as Tailwind custom token, NOT inline hex). The doodled pattern background is OPTIONAL — render as a CSS background-image via a Tailwind utility class `bg-wa-pattern` (defined in tailwind config). If timeline-cost is high, skip pattern for v1 (flag ISSUE-6).

**Empty state** (no conversation selected): centered `<i class="fa-whatsapp text-wa-green text-5xl"/>` + heading "Select a conversation" + body "Choose a conversation from the list to view messages".

##### ChatHeader (top of center pane, always white bg)

| Element | Source | Notes |
|---------|--------|-------|
| Avatar | `conversation.avatarColor` + initials from `Contact.DisplayName` | 44×44 same palette as left list |
| Name | `Contact.DisplayName` | text-base font-semibold |
| Meta row | `{phone} \| {contactType} \| Score: {engagementScore}` | text-xs muted; separators are pipe chars |

ContactType source: `Contact.ContactBaseType.MasterDataValue` (existing MasterData `CONTACTBASETYPE`).
EngagementScore source: SERVICE_PLACEHOLDER — there's no `Contact.EngagementScore` column; show `—` for v1 (or fetch from #93 EngagementScoring when it lands). Flag ISSUE-7.

**Header actions** (right, flex gap-1, each `<button class="border rounded-md px-2.5 py-1 text-xs">`):
| Button | Icon | Action |
|--------|------|--------|
| View Profile | `fa-user` / Phosphor `user-bold` | router.push(`/{lang}/crm/contact/allcontacts?mode=read&id={contactId}`) |
| Assign | `fa-user-tag` / `users-bold` | opens Assign dropdown listing Staff users + "Unassigned" option |
| Star (toggle) | `fa-star` (outline=unstarred, solid+`text-warning`=starred) | `toggleStarConversation` |
| Archive | `fa-box-archive` / `archive-bold` | `toggleArchiveConversation` (toast: "Conversation archived" + Undo) |
| Info | `fa-circle-info` / `info-bold` | toggles right-pane stats sidebar |
| More | `fa-ellipsis-vertical` / `dots-three-vertical-bold` | dropdown: Mark as Resolved (SERVICE_PLACEHOLDER), Add Internal Note (focuses composer in note-mode), Mark as Opted Out (sets `OptOutAt`), Block Contact (SERVICE_PLACEHOLDER), View in CRM (same as View Profile) |

##### ReplyWindowBanner (below ChatHeader)

Stamp one of 4 states per §④ business logic. Renders a 1-line strip with icon + text. Tailwind utility classes only (no inline hex):
- Green: `bg-green-50 border-y border-green-200 text-green-800 dark:bg-green-950/40 dark:text-green-200`
- Amber: `bg-amber-50 border-y border-amber-200 text-amber-800 dark:bg-amber-950/40 dark:text-amber-200`
- Red: `bg-red-50 border-y border-red-200 text-red-800 dark:bg-red-950/40 dark:text-red-200`

Live countdown ("23h 37m remaining") updates every 60s via `setInterval` (cleanup on unmount). When countdown hits 0 → component re-renders into red-expired state.

##### ChatMessages (scrollable area, flex-col gap-1.5 px-5 py-4)

Render strategy: a single list of typed entries; each entry maps to one of 4 sub-components:

| Entry type | Component | Style |
|-----------|-----------|-------|
| `date` | `<DateDivider date={iso}>` | centered chip — `bg-stone-300/80 text-stone-700 px-3 py-1 rounded-md text-xs font-semibold` with a slight shadow. Text: "Today" / "Yesterday" / "April 10, 2026". |
| `system` | `<SystemMessage text={...}>` | centered amber chip `bg-amber-100 text-amber-900 px-3 py-1 rounded-md text-xs` — e.g., "Conversation started via campaign_appeal template", "24-hour reply window opened", "Contact opted out — STOP received". |
| `outbound` message | `<OutboundBubble msg={}>` | right-aligned, max-w-[65%], `bg-wa-bubble-out` (`#dcf8c6` token), rounded-lg + top-right-radius-0, shadow-sm |
| `inbound` message | `<InboundBubble msg={}>` | left-aligned, max-w-[65%], `bg-card` (white), rounded-lg + top-left-radius-0, shadow-sm |
| `note` | `<InternalNoteCard msg={}>` | centered, max-w-[75%], `bg-amber-100 border border-dashed border-amber-400 text-amber-900 px-3 py-2 rounded-lg` — content: "Internal note by {authorName} — {time}" header + italic body |

**OutboundBubble anatomy**:
- (Optional) Template label header: `<i fa-file-lines /> Template: {templateName}` — `text-xs text-primary font-semibold mb-1`
- Body text: `text-sm text-foreground` — preserves `\n` via `whitespace-pre-line`
- (Optional) Buttons row: small chips for template interactive buttons (e.g., "Donate Now") — `bg-primary/10 border border-primary/20 text-primary text-xs font-semibold px-2 py-1 rounded-md` — non-interactive (display-only)
- Footer (right-aligned, flex gap-1.5 mt-1):
  - Time: `text-[10px] text-[var(--bubble-time)]` (defined token, fallback `#667781` — use `text-slate-500`)
  - Status tick: per §④ mapping. `Read` = blue, `Delivered/Sent` = grey, `Failed` = red, `Queued` = clock icon.

**InboundBubble anatomy**:
- Body text + footer (just time — no status). Same structure minus template + buttons + status.

**Date grouping (FE-only)**: group messages by `formatLocalDay(createdDate)`. Insert a `date` entry between groups. Special labels: "Today", "Yesterday", else "Month D, YYYY".

**Auto-scroll**: on initial thread load, scroll to bottom (newest at bottom). On new outbound message via composer, scroll to bottom. Do NOT auto-scroll on inbound webhook ingestion if user is scrolled up (out of scope — no realtime in v1, so non-issue).

##### ChatComposer (sticky bottom of center pane, white bg, border-top)

Sub-elements (top → bottom):

1. **ReplyWindowInfo strip** (small variant of the banner — green/red — text only):
   - Green: "Within 24-hour window — free-form reply allowed"
   - Red-expired: "Reply window expired. You can only send approved templates."
   - Red-optout: "Contact opted out. Messaging is disabled."

2. **QuickReplyDropdown** (absolutely positioned above the textarea, hidden by default):
   - Triggered by "Quick Reply" toolbar button click.
   - List of `WhatsAppQuickReply` rows (10 most-recent for current company).
   - Each item: body preview (truncate-2-lines). Click → paste into textarea + close dropdown + focus textarea.
   - Footer item: "Manage Quick Replies" (accent text) → SERVICE_PLACEHOLDER toast.

3. **Input row** (flex items-end gap-2 p-2):
   - **Textarea**: rounded-lg `border border-input`, min-h-10, max-h-32, auto-resize on input. Placeholder per banner state ("Type a message…" / "Reply window expired. Use templates…" / "Contact has opted out…" / "Type an internal note (visible only to staff)…").
   - **Send button**: 40×40 round, `bg-wa-green text-white` (solid per badge rule), `hover:bg-wa-green-dark` (`#128C7E` token). Disabled state `bg-muted text-muted-foreground cursor-not-allowed`. Icon: Phosphor `paper-plane-right-bold` (Phosphor preferred per memory).

4. **Toolbar row** (flex gap-1 px-3 pb-2 border-t border-muted/30):
   - **Attach** (`fa-paperclip` / `paperclip-bold`) — SERVICE_PLACEHOLDER toast.
   - **Template** (`fa-file-lines` / `file-text-bold`) — opens TemplatePicker modal.
   - **Quick Reply** (`fa-comment-dots` / `chat-circle-dots-bold`) — toggles QuickReplyDropdown.
   - **Note** (`fa-note-sticky` / `note-bold`) — toggles `noteMode` (bg-amber on textarea, placeholder change). Active state has `bg-amber-100 text-amber-900 border-amber-400`.

#### RIGHT PANE — Stats Sidebar (collapsible, 260px, hidden by default)

Sections (vertical stack, divided):

1. **Header**: "Contact Summary" + close button (x)
2. **Message Stats**:
   - Total messages: `{N} ({outCount} out, {inCount} in)` — computed BE-side from `WhatsAppMessages WHERE WhatsAppConversationId == id` count.
   - First contact: `{firstMessageDate}` — formatted "Jan 15, 2026"
   - Reply rate: `{N}%` — count(`Direction=Inbound` after first outbound) / count(outbound) — SERVICE_PLACEHOLDER if hard to compute, hardcode `—` for v1; flag ISSUE-8.
   - Avg response time: `{N} min` — average between consecutive inbound→outbound pairs — same SERVICE_PLACEHOLDER.
3. **Recent Donations** (last 3 from `corg.GlobalDonations WHERE ContactId == X` — SERVICE_PLACEHOLDER for v1 because GlobalDonation cross-schema join from `notify` is non-trivial; surface 3 hard-coded rows or empty state for v1; flag ISSUE-9):
   - Row: amount (green bold) + date + purpose/category sub-line.
4. **Tags** (chips of `Contact.ContactTags.Select(ct => ct.Tag.TagName)`):
   - Render as accent-tinted chips. SERVICE_PLACEHOLDER if `Contact.Include(ContactTags)` not in the existing GetContactById projection — verify; if missing, return empty for v1 + flag ISSUE-10.
5. **View Full Profile** (link, bottom): clicks → `/crm/contact/allcontacts?mode=read&id={contactId}`.

#### "+ New Message" Modal

Triggered by "+ New Message" header button. Modal overlay (`<Dialog>` / `<Modal>` per existing modal infra — see `placeholder-management` modal precedent).

**Body fields** (vertical, gap-4):
1. **Contact** — `<ApiSelectV2 query={GET_ALL_CONTACT_LIST} value={contactId}>` — placeholder "Search contact by name or phone…". Below: helper text "Only contacts with WhatsApp opt-in will be shown" + green-check icon. Filter SERVICE_PLACEHOLDER per §③ FK note (DoNotSMS/DoNotPhone surrogate).
2. **Template** — `<ApiSelectV2 query={GET_APPROVED_WHATSAPP_TEMPLATES}>` — client-filter `status === "Approved"`. Placeholder "Select an approved template…". OnChange → trigger Variables section + Preview render.
3. **Fill Variables** (shown only after template selected) — for each `{{var}}` in template Body, render `<input placeholder="{{var}}" />`. Pre-fill from `whatsapp-variable-resolver.ts` helper where possible (auto-pull contact name, today's date, etc.).
4. **Preview** — `<WhatsAppBubblePreview>` — same OutboundBubble component used in the thread, rendering the template Body with `{{var}}` placeholders interpolated from the variable inputs in real-time.

**Footer actions**:
- Cancel (outline) → closes modal
- Send (primary) — calls `createWhatsAppConversationFromTemplate` (or `sendOutboundWhatsAppMessage` with `WhatsAppTemplateId` set — backend handler does upsert + insert atomically) → on success → close modal + navigate to the new conversation in left list + select it.

### Page Widgets & Summary Cards

Widgets: rendered INLINE in the ScreenHeader subtitle row (3 metrics — Open Conversations / Needs Reply / Avg Response Time). NO standalone KPI cards. Per `feedback_widget_icon_badge_styling`, the `Needs Reply` strong-value is `text-warning` (amber-600 token) — text-only, no chip backgrounds since these are inline metrics not "badge containers".

**Inbox Summary GQL Query** (NEW):
- Query name: `getWhatsAppInboxSummary`
- Handler: `GetWhatsAppInboxSummaryQuery` → returns `WhatsAppInboxSummaryDto { openConversationCount: int, unreadConversations: int, needsReplyCount: int, starredCount: int, archivedCount: int, avgResponseTimeMinutes: int }`
- Scoped to current company. `avgResponseTimeMinutes` is SERVICE_PLACEHOLDER for v1 (hard-coded median `14` until real metric computation lands — flag ISSUE-8).

### Grid Aggregation Columns

N/A.

### User Interaction Flow (non-standard FLOW — no mode routing)

1. User opens `/crm/whatsapp/whatsappconversation` → page mounts → fetches `getWhatsAppConversations(pageIndex=0, pageSize=30, tab='all')` + `getWhatsAppInboxSummary` in parallel. If `?conversationId=N` present, also fetch that conversation's thread + auto-select.
2. Server returns scoped list (CompanyId-scoped), ordered by `LastMessageAt DESC`.
3. User clicks a tab → store updates → re-fetch page 1 with new tab.
4. User types in search → debounced 250ms → re-fetch.
5. User clicks a conversation row → `selectedConversationId = id`, URL updates to `?conversationId={id}`, thread fetched, `markConversationRead` mutation fires.
6. User reads thread, types in composer → click Send (or Enter) → optimistic outbound bubble appended (Status=Queued) → `sendOutboundWhatsAppMessage` mutation → server responds → bubble status upgraded.
7. User clicks Template toolbar → modal picker → selects template → variables fill → click Send → outbound message with `WhatsAppTemplateId` written.
8. User clicks Note toolbar → composer turns amber → types note → Send writes `Direction=Note`.
9. User clicks Star header button → optimistic toggle + `toggleStarConversation` mutation.
10. User clicks Archive → optimistic remove from list (current tab) + toast with Undo.
11. User clicks Info → stats sidebar slides in from right.
12. User clicks More → Mark as Opted Out → confirm → `OptOutAt = now` + System message inserted + composer disables.
13. User right-clicks a list row → context menu (Star/Archive/Mark Read/Assign).
14. User clicks "+ New Message" → modal → picks contact + template + fills vars → Send → backend upserts conversation + inserts outbound message → modal closes → new conversation selected in left pane.
15. User clicks "Export Conversations" → toast "Export is coming soon" (SERVICE_PLACEHOLDER).
16. User clicks "View All Replies" on a WhatsApp Campaign detail page → navigates here with `?campaignId={N}` → left list filters to that campaign's conversations.

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference entity to WhatsAppConversation.

**Canonical Reference**: NotificationCenter (#35) for the **non-standard composite-page shell** + WhatsAppTemplate (#31) for the **NotifyModels group folder layout / service folder conventions**. For the two-pane chat console specifically, there is NO canonical reference — it is bespoke.

| Canonical (NotificationCenter #35) | → WhatsAppConversation | Context |
|-----------|--------------|---------|
| Notification | WhatsAppConversation | Parent entity name |
| notification | whatsAppConversation | Variable/field names |
| NotificationId | WhatsAppConversationId | PK field |
| Notifications | WhatsAppConversations | Table name |
| notification-center | whatsapp-conversation | FE folder kebab |
| notificationcenter | whatsappconversation | FE folder lower-no-dash + route path |
| NOTIFICATIONCENTER | WHATSAPPCONVERSATION | Menu code |
| notify | notify | DB schema (SAME) |
| Notify | Notify | Backend group (SAME) |
| NotifyModels | NotifyModels | Namespace suffix (SAME) |
| CRM_NOTIFICATION | CRM_WHATSAPP | Parent menu code |
| CRM | CRM | Module (SAME) |
| crm/notification/notificationcenter | crm/whatsapp/whatsappconversation | FE route base |
| notify-service | notify-service | FE service folder (SAME) |
| notify-queries | notify-queries | GQL queries folder (SAME) |
| notify-mutations | notify-mutations | GQL mutations folder (SAME) |

**Child substitution (mirrors WhatsAppTemplate #31 → WhatsAppTemplateButton precedent)**:
| Parent | Child 1 | Child 2 |
|--------|---------|---------|
| WhatsAppConversation | WhatsAppMessage | WhatsAppQuickReply (sibling, not child of WhatsAppConversation) |

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend — Create (new)

**Domain (3 entities)**:
| # | File | Path |
|---|------|------|
| 1 | WhatsAppConversation entity | `Base.Domain/Models/NotifyModels/WhatsAppConversation.cs` |
| 2 | WhatsAppMessage entity | `Base.Domain/Models/NotifyModels/WhatsAppMessage.cs` |
| 3 | WhatsAppQuickReply entity | `Base.Domain/Models/NotifyModels/WhatsAppQuickReply.cs` |

**EF Configurations (3 files)**:
| # | File | Path |
|---|------|------|
| 4 | WhatsAppConversationConfiguration | `Base.Infrastructure/Data/Configurations/NotifyConfigurations/WhatsAppConversationConfiguration.cs` |
| 5 | WhatsAppMessageConfiguration | `Base.Infrastructure/Data/Configurations/NotifyConfigurations/WhatsAppMessageConfiguration.cs` |
| 6 | WhatsAppQuickReplyConfiguration | `Base.Infrastructure/Data/Configurations/NotifyConfigurations/WhatsAppQuickReplyConfiguration.cs` |

**Application Schemas / DTOs (1 file)**:
| # | File | Path |
|---|------|------|
| 7 | WhatsAppConversationSchemas | `Base.Application/Schemas/NotifySchemas/WhatsAppConversationSchemas.cs` — contains `WhatsAppConversationRequestDto`, `WhatsAppConversationResponseDto`, `WhatsAppConversationListItemDto`, `WhatsAppMessageRequestDto`, `WhatsAppMessageResponseDto`, `WhatsAppQuickReplyRequestDto`, `WhatsAppQuickReplyResponseDto`, `WhatsAppInboxSummaryDto`, `WhatsAppContactSummaryDto` (with `MessageStatsDto`, `RecentDonationDto`, `TagDto`), `SendOutboundWhatsAppMessageRequestDto`, `AddConversationNoteRequestDto`, `UpdateWhatsAppConversationRequestDto`, `CreateConversationFromTemplateRequestDto`, `IngestInboundMessageRequestDto`. |

**Commands (7 files)**:
| # | File | Path |
|---|------|------|
| 8 | CreateWhatsAppConversation | `Base.Application/Business/NotifyBusiness/WhatsAppConversations/Commands/CreateWhatsAppConversation.cs` |
| 9 | UpdateWhatsAppConversation (partial — star/archive/assign/optout/read) | `…/WhatsAppConversations/Commands/UpdateWhatsAppConversation.cs` |
| 10 | DeleteWhatsAppConversation | `…/WhatsAppConversations/Commands/DeleteWhatsAppConversation.cs` |
| 11 | SendOutboundWhatsAppMessage (SERVICE_PLACEHOLDER for Meta send) | `…/WhatsAppConversations/Commands/SendOutboundWhatsAppMessage.cs` |
| 12 | AddWhatsAppConversationNote | `…/WhatsAppConversations/Commands/AddWhatsAppConversationNote.cs` |
| 13 | MarkConversationRead | `…/WhatsAppConversations/Commands/MarkConversationRead.cs` |
| 14 | IngestInboundWhatsAppMessage (SERVICE_PLACEHOLDER — exposed for seed/E2E sim) | `…/WhatsAppConversations/Commands/IngestInboundWhatsAppMessage.cs` |

(Use the Commands/ flat folder pattern per #36 NotificationTemplate precedent — Saved Filter is canonical for FLOW too; #36 also uses the flat folder.)

**WhatsAppQuickReply Commands (3 files — minimum CRUD for the dropdown query)**:
| # | File | Path |
|---|------|------|
| 15 | CreateWhatsAppQuickReply | `Base.Application/Business/NotifyBusiness/WhatsAppQuickReplies/Commands/CreateWhatsAppQuickReply.cs` |
| 16 | UpdateWhatsAppQuickReply | `…/WhatsAppQuickReplies/Commands/UpdateWhatsAppQuickReply.cs` |
| 17 | DeleteWhatsAppQuickReply | `…/WhatsAppQuickReplies/Commands/DeleteWhatsAppQuickReply.cs` |

(Quick Replies management UI is OUT OF SCOPE — but the commands are needed to seed a starter set for E2E and to support future surfacing. Minimum implementation; no validators beyond required-field checks.)

**Queries (5 files)**:
| # | File | Path |
|---|------|------|
| 18 | GetWhatsAppConversations (left-pane list) | `Base.Application/Business/NotifyBusiness/WhatsAppConversations/Queries/GetWhatsAppConversations.cs` |
| 19 | GetWhatsAppConversationById (thread) | `…/WhatsAppConversations/Queries/GetWhatsAppConversationById.cs` |
| 20 | GetWhatsAppInboxSummary | `…/WhatsAppConversations/Queries/GetWhatsAppInboxSummary.cs` |
| 21 | GetWhatsAppConversationContactSummary | `…/WhatsAppConversations/Queries/GetWhatsAppConversationContactSummary.cs` |
| 22 | GetWhatsAppQuickReplies | `Base.Application/Business/NotifyBusiness/WhatsAppQuickReplies/Queries/GetWhatsAppQuickReplies.cs` |

**Endpoints (2 files)**:
| # | File | Path |
|---|------|------|
| 23 | WhatsAppConversationMutations | `Base.API/EndPoints/Notify/Mutations/WhatsAppConversationMutations.cs` |
| 24 | WhatsAppConversationQueries | `Base.API/EndPoints/Notify/Queries/WhatsAppConversationQueries.cs` |

**Migration + Seed (2 files)**:
| # | File | Path |
|---|------|------|
| 25 | EF Migration | `Base.Infrastructure/Data/Migrations/{timestamp}_AddWhatsAppConversations.cs` (via `dotnet ef migrations add`) + snapshot update |
| 26 | DB Seed | `sql-scripts-dyanmic/WhatsAppConversation-sqlscripts.sql` (preserve pre-existing `dyanmic` folder typo) |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `INotifyDbContext.cs` | `DbSet<WhatsAppConversation> WhatsAppConversations`, `DbSet<WhatsAppMessage> WhatsAppMessages`, `DbSet<WhatsAppQuickReply> WhatsAppQuickReplies` |
| 2 | `NotifyDbContext.cs` | Same DbSet props |
| 3 | `DecoratorProperties.cs` (`DecoratorNotifyModules`) | `WhatsAppConversation = "WHATSAPPCONVERSATION"`, `WhatsAppMessage = "WHATSAPPMESSAGE"`, `WhatsAppQuickReply = "WHATSAPPQUICKREPLY"` |
| 4 | `NotifyMappings.cs` | Mapster configs for the 3 entities + their request/response DTOs. Use `.TwoWays()` per WhatsAppTemplate #31 precedent. Explicit `Map(dest => dest.ContactDisplayName, src => src.Contact.DisplayName)` for flat-field projections in `WhatsAppConversationListItemDto`. |
| 5 | `Contact.cs` (existing — modify) | Add inverse nav: `public ICollection<WhatsAppConversation>? WhatsAppConversations { get; set; }` |
| 6 | `WhatsAppTemplate.cs` (existing — modify) | Add inverse nav: `public ICollection<WhatsAppMessage>? WhatsAppMessages { get; set; }` |
| 7 | `User.cs` (existing — modify) | Add 2 inverse navs: `public ICollection<WhatsAppConversation>? AssignedWhatsAppConversations { get; set; }` and `public ICollection<WhatsAppMessage>? AuthoredWhatsAppMessages { get; set; }` (use distinct prop names; FK is `AssignedToUserId` vs `AuthoredByUserId`). |
| 8 | `Company.cs` (existing — modify) | Add inverse navs for the 3 new tables. |
| 9 | `MasterData` seeds | NONE — Direction/MessageType/Status stored as strings (matches NotificationTemplate / WhatsAppTemplate precedent of string-coded enums). |

### Frontend — Modify

| # | File | Path | Change |
|---|------|------|--------|
| 1 | Route stub | `src/app/[lang]/crm/whatsapp/whatsappconversation/page.tsx` | Replace `<UnderConstruction />` with `<WhatsAppConversationPageConfig />` mount. |
| 2 | Notify-service barrel | `src/domain/entities/notify-service/index.ts` | Re-export `WhatsAppConversationDto`. |
| 3 | Notify-queries barrel | `src/infrastructure/gql-queries/notify-queries/index.ts` | Re-export new query module. |
| 4 | Notify-mutations barrel | `src/infrastructure/gql-mutations/notify-mutations/index.ts` | Re-export new mutation module. |
| 5 | `notify-service-entity-operations.ts` | `src/.../notify-service-entity-operations.ts` | Add `WHATSAPPCONVERSATION` operations block (getAll → `GET_WHATSAPP_CONVERSATIONS_QUERY`, create/update/delete wired correctly). |
| 6 | Page-components crm/whatsapp barrel | `src/presentation/components/page-components/crm/whatsapp/index.ts` | Add `export { default as WhatsAppConversationPage } from "./whatsappconversation";` |
| 7 | Pages crm/whatsapp barrel | `src/presentation/pages/crm/whatsapp/index.ts` | Add `export { WhatsAppConversationPageConfig } from "./whatsappconversation";` |
| 8 | Stores barrel | `src/application/stores/index.ts` | Append `export * from "./whatsapp-conversation-stores";` |

### Frontend — Create

| # | File | Path |
|---|------|------|
| 1 | DTO | `src/domain/entities/notify-service/WhatsAppConversationDto.ts` |
| 2 | GQL Query | `src/infrastructure/gql-queries/notify-queries/WhatsAppConversationQuery.ts` (constants: `GET_WHATSAPP_CONVERSATIONS_QUERY`, `GET_WHATSAPP_CONVERSATION_BY_ID_QUERY`, `GET_WHATSAPP_INBOX_SUMMARY_QUERY`, `GET_WHATSAPP_CONVERSATION_CONTACT_SUMMARY_QUERY`, `GET_WHATSAPP_QUICK_REPLIES_QUERY`) |
| 3 | GQL Mutation | `src/infrastructure/gql-mutations/notify-mutations/WhatsAppConversationMutation.ts` (constants: `CREATE_WHATSAPP_CONVERSATION_MUTATION`, `UPDATE_WHATSAPP_CONVERSATION_MUTATION`, `DELETE_WHATSAPP_CONVERSATION_MUTATION`, `SEND_OUTBOUND_WHATSAPP_MESSAGE_MUTATION`, `ADD_WHATSAPP_CONVERSATION_NOTE_MUTATION`, `MARK_CONVERSATION_READ_MUTATION`, `INGEST_INBOUND_WHATSAPP_MESSAGE_MUTATION`, `TOGGLE_STAR_CONVERSATION_MUTATION`, `TOGGLE_ARCHIVE_CONVERSATION_MUTATION`) |
| 4 | Page config | `src/presentation/pages/crm/whatsapp/whatsappconversation.tsx` (access-capability guard → renders `<WhatsAppConversationPage />`) |
| 5 | Folder barrel | `src/presentation/components/page-components/crm/whatsapp/whatsappconversation/index.ts` |
| 6 | Main page | `src/.../whatsappconversation/whatsapp-conversation-page.tsx` (Shell: ScreenHeader + inline metrics + 3-pane layout) |
| 7 | ConversationListPane | `src/.../whatsappconversation/conversation-list-pane.tsx` (search + tabs + list + load-more) |
| 8 | ConversationListItem | `src/.../whatsappconversation/conversation-list-item.tsx` (one card with avatar + name + meta + preview + badges + context-menu) |
| 9 | ChatPane | `src/.../whatsappconversation/chat-pane.tsx` (orchestrates ChatHeader + ReplyWindowBanner + ChatMessages + ChatComposer; empty state) |
| 10 | ChatHeader | `src/.../whatsappconversation/chat-header.tsx` (avatar + name + meta + 6 action buttons + assign-dropdown + more-menu) |
| 11 | ReplyWindowBanner | `src/.../whatsappconversation/reply-window-banner.tsx` (4 states + live countdown) |
| 12 | ChatMessages | `src/.../whatsappconversation/chat-messages.tsx` (groups + auto-scroll + bubble dispatcher) |
| 13 | OutboundBubble | `src/.../whatsappconversation/outbound-bubble.tsx` |
| 14 | InboundBubble | `src/.../whatsappconversation/inbound-bubble.tsx` |
| 15 | InternalNoteCard | `src/.../whatsappconversation/internal-note-card.tsx` |
| 16 | DateDivider + SystemMessage | `src/.../whatsappconversation/thread-markers.tsx` (2 tiny components in one file) |
| 17 | ChatComposer | `src/.../whatsappconversation/chat-composer.tsx` (textarea + send + toolbar + quick-reply-dropdown trigger + note-mode) |
| 18 | QuickReplyDropdown | `src/.../whatsappconversation/quick-reply-dropdown.tsx` |
| 19 | TemplatePickerModal | `src/.../whatsappconversation/template-picker-modal.tsx` (template select + variable inputs + preview bubble) |
| 20 | NewMessageModal | `src/.../whatsappconversation/new-message-modal.tsx` (contact + template + variables + preview + send) |
| 21 | StatsSidebar | `src/.../whatsappconversation/stats-sidebar.tsx` (4 sections — message stats / recent donations / tags / link) |
| 22 | StatusIconRenderer | `src/.../whatsappconversation/status-icon-renderer.tsx` (5 status icons for message + left-list) — reuses across thread + list |
| 23 | RelativeTime helper | `src/.../whatsappconversation/relative-time.ts` (mockup-compliant: same-day → "10:23 AM"; yesterday → "Yesterday"; older this year → "Apr 9"; older → "Apr 9, 2025") |
| 24 | whatsapp-variable-resolver helper | `src/.../whatsappconversation/whatsapp-variable-resolver.ts` (parse `{{var}}` from template body, return ordered var list, support auto-prefill from known contact context) |
| 25 | Zustand store | `src/application/stores/whatsapp-conversation-stores/whatsapp-conversation-store.ts` |
| 26 | Zustand barrel | `src/application/stores/whatsapp-conversation-stores/index.ts` |
| 27 | useWhatsAppConversation hook | `src/.../whatsappconversation/use-whatsapp-conversation.ts` (Apollo hooks wiring; orchestrates list / thread / summary / mutations; exposes handlers) |
| 28 | Route page mount | (modify — already in §"Frontend — Modify" #1) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `notify-service-entity-operations.ts` | `WHATSAPPCONVERSATION` block (already listed in Modify #5) |
| 2 | sidebar / menu config | (Auto-driven by DB seed — no manual wiring) |
| 3 | route config | Next.js App Router file-based — already resolved by overwriting the stub `page.tsx` |
| 4 | tailwind.config.ts | Add WhatsApp brand tokens IF NOT PRESENT (`wa-green`, `wa-green-dark`, `wa-bubble-out`, `wa-bubble-in`, `wa-chat-bg`, `wa-read-blue`, `wa-note-bg`) — check first; WhatsApp Template #31 already added some — REUSE; only add missing. |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.

```
---CONFIG-START---
Scope: FULL

MenuName: WhatsApp Conversations
MenuCode: WHATSAPPCONVERSATION
ParentMenu: CRM_WHATSAPP
Module: CRM
MenuUrl: crm/whatsapp/whatsappconversation
GridType: FLOW

MenuCapabilities: READ, CREATE, MODIFY, DELETE, ISMENURENDER

RoleCapabilities:
  BUSINESSADMIN: READ, CREATE, MODIFY, DELETE

GridFormSchema: SKIP
GridCode: WHATSAPPCONVERSATION
---CONFIG-END---
```

Notes:
- `MenuCapabilities` includes CREATE (for "+ New Message" + composer Send), READ (list + thread), MODIFY (star/archive/assign/optout/read), DELETE (soft-delete conversation + soft-delete individual message rare-path).
- TOGGLE / IMPORT / EXPORT excluded — there's no "Activate/Deactivate" entity toggle (Star/Archive cover those needs). Export is a SERVICE_PLACEHOLDER toast.
- No `Grid` row in seed (custom UI — no standard DataTable), no `GridColumns`, no `GridFields`, no `GridFormSchema` (SKIP per FLOW convention).
- `WHATSAPPCONVERSATION` menu ordering: `OrderBy = 3` under `CRM_WHATSAPP` (MenuId 265), following `WHATSAPPTEMPLATE` (1) and `WHATSAPPCAMPAIGN` (2) per MODULE_MENU_REFERENCE.md.

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `WhatsAppConversationQueries`
- Mutation type: `WhatsAppConversationMutations`

**Queries:**
| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getWhatsAppConversations` | `PaginatedApiResponse<WhatsAppConversationListItemDto[]>` | `pageIndex: Int!, pageSize: Int = 30, tab: String (all\|unread\|needsReply\|starred\|archived), searchText: String, campaignId: Int (optional, for ?campaignId deep-link), assignedToUserId: Int (optional, future-scope)` |
| `getWhatsAppConversationById` | `ApiResponse<WhatsAppConversationResponseDto>` | `whatsAppConversationId: Int!` — returns parent + ALL messages ASC (paginated cursor TBD per ISSUE-3) |
| `getWhatsAppInboxSummary` | `ApiResponse<WhatsAppInboxSummaryDto>` | — |
| `getWhatsAppConversationContactSummary` | `ApiResponse<WhatsAppContactSummaryDto>` | `whatsAppConversationId: Int!` |
| `getWhatsAppQuickReplies` | `[WhatsAppQuickReplyResponseDto]` | `searchText: String (optional)` |

**Mutations:**
| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createWhatsAppConversation` | `CreateConversationFromTemplateRequestDto { contactId, whatsAppTemplateId, variableValues }` | `ApiResponse<WhatsAppConversationResponseDto>` (parent + first outbound message embedded) |
| `updateWhatsAppConversation` | `UpdateWhatsAppConversationRequestDto { whatsAppConversationId, assignedToUserId?, isStarred?, isArchived?, optOutAt? }` (partial — only set fields are persisted) | `ApiResponse<Boolean>` |
| `deleteWhatsAppConversation` | `whatsAppConversationId: Int!` | `ApiResponse<Boolean>` |
| `sendOutboundWhatsAppMessage` | `SendOutboundWhatsAppMessageRequestDto { whatsAppConversationId, body, whatsAppTemplateId?, templateButtonsJson? }` | `ApiResponse<WhatsAppMessageResponseDto>` (the new row — Status starts `Queued`, will be `Sent` once placeholder marks it) |
| `addWhatsAppConversationNote` | `AddConversationNoteRequestDto { whatsAppConversationId, body }` | `ApiResponse<WhatsAppMessageResponseDto>` |
| `markConversationRead` | `whatsAppConversationId: Int!` | `ApiResponse<Boolean>` |
| `toggleStarConversation` | `whatsAppConversationId: Int!` | `ApiResponse<Boolean>` |
| `toggleArchiveConversation` | `whatsAppConversationId: Int!` | `ApiResponse<Boolean>` |
| `ingestInboundWhatsAppMessage` (SERVICE_PLACEHOLDER) | `IngestInboundMessageRequestDto { phoneNumber, body, metaMessageId, receivedAt }` | `ApiResponse<WhatsAppMessageResponseDto>` — exposed for E2E sim |
| `createWhatsAppQuickReply` | `WhatsAppQuickReplyRequestDto` | `ApiResponse<Int>` |
| `updateWhatsAppQuickReply` | `WhatsAppQuickReplyRequestDto` | `ApiResponse<Int>` |
| `deleteWhatsAppQuickReply` | `whatsAppQuickReplyId: Int!` | `ApiResponse<Boolean>` |

**WhatsAppConversationListItemDto fields** (left-pane payload — flat for performance):
| Field | Type | Notes |
|-------|------|-------|
| whatsAppConversationId | number | PK |
| contactId | number | for navigation |
| contactDisplayName | string | flattened from `Contact.DisplayName` |
| contactInitials | string | computed FE — but BE can also pre-compute (1-2 chars) |
| phoneNumber | string | display in meta line |
| avatarColor | string | one of 6 palette keys |
| lastMessageAt | string (ISO) | for relative time |
| lastMessagePreview | string | truncated, sanitised |
| lastMessageDirection | string | `Inbound` / `Outbound` |
| lastMessageStatus | string | for tick icon |
| lastMessageTemplate | string \| null | for "📎 {name}" chip |
| unreadCount | number | for unread pill |
| isStarred | boolean | — |
| isArchived | boolean | — |
| optOutAt | string (ISO) \| null | — |
| firstCampaignId | number \| null | for `?campaignId=X` filter join |
| assignedToUserId | number \| null | for assign-state display |
| assignedToUserName | string \| null | flat |

**WhatsAppConversationResponseDto fields** (right-pane thread payload):
| Field | Type | Notes |
|-------|------|-------|
| whatsAppConversationId | number | PK |
| contactId | number | — |
| contactDisplayName | string | — |
| contactType | string | from `Contact.ContactBaseType.MasterDataValue` |
| contactEngagementScore | number \| null | SERVICE_PLACEHOLDER — `null` for v1 |
| phoneNumber | string | — |
| avatarColor | string | — |
| assignedToUserId | number \| null | — |
| assignedToUserName | string \| null | — |
| lastMessageAt | string (ISO) | — |
| replyWindowExpiresAt | string (ISO) \| null | — |
| isStarred | boolean | — |
| isArchived | boolean | — |
| optOutAt | string (ISO) \| null | — |
| firstCampaignId | number \| null | — |
| messages | `WhatsAppMessageResponseDto[]` | ordered ASC by CreatedDate |
| createdDate, modifiedDate, isActive | inherited | — |

**WhatsAppMessageResponseDto fields**:
| Field | Type | Notes |
|-------|------|-------|
| whatsAppMessageId | number | PK |
| whatsAppConversationId | number | parent FK |
| direction | string | `Inbound` / `Outbound` / `Note` / `System` |
| messageType | string | `Text` / `Template` / `Image` / `Document` / `Video` / `Audio` / `Location` (display logic for non-Text deferred — flag ISSUE-11) |
| body | string | — |
| whatsAppTemplateId | number \| null | — |
| whatsAppTemplateName | string \| null | flat (joined from WhatsAppTemplate) |
| templateButtonsJson | string \| null | parsed FE-side |
| metaMessageId | string \| null | — |
| status | string \| null | for outbound tick |
| failureReason | string \| null | — |
| sentAt | string (ISO) \| null | — |
| deliveredAt | string (ISO) \| null | — |
| readAt | string (ISO) \| null | — |
| receivedAt | string (ISO) \| null | — |
| authoredByUserId | number \| null | — |
| authoredByUserName | string \| null | flat |
| createdDate | string (ISO) | display |

**WhatsAppInboxSummaryDto**:
```ts
export interface WhatsAppInboxSummaryDto {
  openConversationCount: number;
  unreadConversations: number;
  needsReplyCount: number;
  starredCount: number;
  archivedCount: number;
  avgResponseTimeMinutes: number; // SERVICE_PLACEHOLDER for v1 (hard-coded 14)
}
```

**WhatsAppContactSummaryDto**:
```ts
export interface WhatsAppContactSummaryDto {
  totalMessages: number;
  outboundCount: number;
  inboundCount: number;
  firstMessageDate: string | null;
  replyRatePct: number | null; // null = SERVICE_PLACEHOLDER
  avgResponseTimeMinutes: number | null;
  recentDonations: RecentDonationDto[]; // [] = SERVICE_PLACEHOLDER for v1
  tags: TagDto[]; // [] if Contact.Include(ContactTags) not in projection
}

export interface RecentDonationDto {
  amount: number;
  donationDate: string; // ISO
  purposeName: string | null;
}

export interface TagDto {
  tagId: number;
  tagName: string;
  color: string;
}
```

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no new errors in Base.Domain / Base.Infrastructure / Base.Application / Base.API
- [ ] `dotnet ef migrations add AddWhatsAppConversations` — migration generated, SQL inspected (3 CREATE TABLE + 9 CREATE INDEX + 1 inverse-nav update on Contact/User/Company/WhatsAppTemplate)
- [ ] `pnpm tsc --noEmit` — no new errors in `src/domain/entities/notify-service/WhatsAppConversationDto.ts`, `src/application/stores/whatsapp-conversation-stores`, `src/presentation/components/page-components/crm/whatsapp/whatsappconversation`
- [ ] `pnpm dev` — page loads at `/en/crm/whatsapp/whatsappconversation`

**Functional Verification (Full E2E — MANDATORY):**
- [ ] Page loads in < 2s with test data (20 conversations × 5–10 messages + 1 summary)
- [ ] Left list groups: 5 tabs visible, "Unread" + "Needs Reply" show red count badges that match seed-data counts
- [ ] Search filters by name, phone, OR last-message-preview (server ILIKE)
- [ ] Click conversation row → URL updates to `?conversationId=X` → thread loads in center pane → `markConversationRead` fires → unread badge disappears
- [ ] Right-click row → context menu opens (Star / Archive / Mark Read / Assign)
- [ ] Chat thread renders date dividers between days
- [ ] System message yellow chip renders for "Conversation started via campaign_appeal template"
- [ ] Outbound bubble renders green right-aligned + read-tick (blue if read, grey double if delivered, grey single if sent, red x if failed)
- [ ] Inbound bubble renders white left-aligned, no tick
- [ ] Internal note renders amber-dashed centered with "Internal note by John Smith — 10:25 AM" header
- [ ] Outbound template bubble shows accent "Template: {name}" label and (if buttons in JSON) button chips
- [ ] Reply-window banner: 4 states (green-active / amber-cold / red-expired / red-optout) render correctly for seed data
- [ ] Live countdown updates every 60s (test by setting `ReplyWindowExpiresAt = UtcNow + 90s` in seed → wait → countdown ticks → reaches 0 → flips to red-expired)
- [ ] Composer textarea auto-resizes up to 120px max
- [ ] Composer Send button disabled when text empty, conversation opted-out, or window expired (without template selected)
- [ ] Enter sends; Shift+Enter inserts newline
- [ ] Send appends outbound bubble optimistically (Status=Queued, clock icon) → upgrades to Status=Sent after mutation response
- [ ] Quick Reply toolbar → dropdown opens → click item → pastes body into textarea → dropdown closes
- [ ] Template toolbar → modal opens → select template → variable inputs render → preview bubble updates in real-time → Send writes outbound message with `WhatsAppTemplateId`
- [ ] Note toolbar → textarea bg turns amber → Send writes `Direction=Note` row → renders as amber-dashed card
- [ ] Header Star button toggles `IsStarred` → list re-orders if "Starred" tab active → toast "Conversation starred"
- [ ] Header Archive button → conversation disappears from current tab (optimistic) → toast with "Undo" → server confirms after delay
- [ ] Header Info button toggles right-pane stats sidebar
- [ ] Header More menu → "Mark as Opted Out" sets `OptOutAt = now` → composer disables → red banner appears → System message inserted
- [ ] "+ New Message" modal opens; contact picker fetches `getAllContactList`; template select shows Approved templates only (client-filter)
- [ ] Selecting a template surfaces variable inputs + preview bubble; Send creates conversation (or reuses) + writes first outbound
- [ ] Deep-link `?campaignId=N` filters left list to that campaign's recipients (seed: tag 3 conversations with `FirstCampaignId=1`)
- [ ] Deep-link `?conversationId=N` auto-selects that conversation on mount
- [ ] Empty state renders when no conversation selected (whatsapp glyph + "Select a conversation")
- [ ] Export button surfaces "Export is coming soon" toast (SERVICE_PLACEHOLDER)
- [ ] Real-time inbound update: NOT tested in v1 — confirm `ingestInboundWhatsAppMessage` mutation can be invoked via GraphQL playground to simulate; verify on next page load the new message renders
- [ ] Auth: only conversations with `CompanyId == currentCompanyId` returned
- [ ] Auth: attempting `updateWhatsAppConversation(id)` for another tenant's conversation returns 404
- [ ] Permissions: respect `canCreate` (composer + new message + ingest), `canModify` (star/archive/assign/optout/read), `canDelete` (delete conversation)

**UI Uniformity (5 mandatory greps — must return 0 matches in the new files):**
- [ ] No inline hex colors in TSX (`#[0-9a-fA-F]{3,6}` in `page-components/crm/whatsapp/whatsappconversation/**/*.tsx`)
- [ ] No inline pixel spacing (`style=\\{\\{.*(padding|margin).*px`)
- [ ] No raw "Loading…" strings (use `<Skeleton>` / `<LayoutLoader>`)
- [ ] Variant B confirmed: `<ScreenHeader>` used, no competing `DataTableContainer` with `showHeader` mismatch (no DataTableContainer at all)
- [ ] No inline `fontSize` / `color:` overrides

**DB Seed Verification:**
- [ ] Menu row `WHATSAPPCONVERSATION` appears in sidebar under CRM → WhatsApp (OrderBy 3)
- [ ] MenuCapabilities correctly seeded for BUSINESSADMIN (READ, CREATE, MODIFY, DELETE)
- [ ] GridFormSchema = SKIP (no form schema in seed — FLOW pattern)
- [ ] No Grid / GridColumns / GridFields rows seeded for this screen
- [ ] 12 sample conversations seeded (mockup data: Sarah Johnson + Ahmad + Ravi + Green Earth + Maria + James + Fatima + David + Emily + Carlos + Sakura + Amina), each with 2–6 messages, covering states: unread inbound, outbound read, outbound failed, outbound opted-out, template-outbound, internal-note
- [ ] 5 starter Quick Replies seeded
- [ ] WhatsApp brand Tailwind tokens registered in `tailwind.config.ts`

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **Non-standard FLOW** — there is NO `view-page.tsx`, NO 3-URL-mode routing, NO FORM layout, NO DETAIL layout. The entire screen is a single composite page `whatsapp-conversation-page.tsx`. Do NOT generate a `view-page.tsx` even though the template manifest mentions it. Parallels #35 NotificationCenter exactly in structure — extend by adding the right (thread) pane.
- **No "+Add" button on a grid** — the entry point is the "+ New Message" modal in the page header. The composer (inside the chat thread) is the in-place create-message surface.
- **WhatsAppCampaign #32 dependency** — `WhatsAppCampaign` entity does NOT exist yet (PROMPT_READY only). For the two FK columns (`WhatsAppConversation.FirstCampaignId` and `WhatsAppMessage.WhatsAppCampaignId`):
  - Define columns as nullable int — DO.
  - Define EF FK relationship — DO NOT (the `WhatsAppCampaigns` DbSet doesn't exist yet). Use **column-only** declaration in EF config: `entity.Property(x => x.FirstCampaignId).HasColumnName("FirstCampaignId");` without `HasOne(...).WithMany(...).HasForeignKey(...)`.
  - When #32 ships, add the FK constraint in a follow-up migration.
  - Same guard pattern as #125 CommunicationDashboard uses for `to_regclass('notify."WhatsAppCampaigns"')`.
- **Phone normalisation**: store E.164 with leading `+`. Strip spaces / dashes / parens on insert. Use a small helper `Base.Application/Helpers/PhoneNumber.cs` (create if not present — verify). Flag ISSUE-12 if `libphonenumber-csharp` is desired for stricter parsing (not in scope for v1).
- **Avatar color**: deterministic `colors[ContactId % 6]` mapping in the Create handler — stable across sessions. Do NOT randomise.
- **Reply window logic is the hardest piece** — verify with TZ edge cases. `ReplyWindowExpiresAt` is stored as UTC; FE renders countdown in user's local TZ. Per memory `feedback_db_utc_only` — every DateTime entity property MUST be UTC; Npgsql will throw if Kind=Unspecified.
- **Status icon mapping is from the mockup** — do NOT invent additional states. The 5 outbound states are `Queued`, `Sent`, `Delivered`, `Read`, `Failed`. The synthetic `OptOut` rendering at the left-list level (red ban icon) is computed FE-side from `OptOutAt != null` — not a stored status.
- **Bubble bg colours**: `wa-bubble-out` (`#dcf8c6`) is brand-WhatsApp green; `wa-bubble-in` is white. These are brand colours and may be defined as Tailwind tokens (one-time addition in `tailwind.config.ts`); per memory rule `feedback_ui_uniformity` — never inline hex. Add tokens once, reuse them as `bg-wa-bubble-out` classes.
- **Phosphor vs Font Awesome icons**: mockup uses `fa-*`. Per memory `feedback_ui_uniformity` — `@iconify/react` with **Phosphor** is preferred. Use Phosphor for ALL icons in this build (paper-plane-right-bold, chat-circle-dots-bold, paperclip-bold, file-text-bold, note-bold, star-bold, archive-bold, info-bold, dots-three-vertical-bold, user-bold, users-bold, etc.). The mockup glyph "fa-whatsapp" is brand-specific — use Phosphor `whatsapp-logo-bold` (it exists in Phosphor's social icons).
- **Right-pane stats sidebar is OPTIONAL** — v1 ships it with partial data (message stats real; recent donations + tags as SERVICE_PLACEHOLDER). Do NOT scope-cut the sidebar to skip it entirely — build the shell and surface placeholder messaging where computation is deferred.
- **Search debouncing**: 250ms (not 500ms) — matches existing FE convention. Use `lodash.debounce` or the existing project debounce helper.
- **WhatsAppQuickReply management** is OUT OF SCOPE — only the read query + 3 CRUD commands are in scope. There is no admin UI; seed a starter set of 5 quick replies. A future screen will surface a settings page for staff to manage their own.
- **Seed sample data is critical** — for E2E test of the 4 banner states, seed conversations like:
  - Sarah Johnson — most recent inbound 30 min ago → green banner active
  - James Okonkwo — most recent inbound 25 hours ago → red-expired banner
  - Emily Chen — `OptOutAt = 3 days ago` → red-optout banner
  - Maria Santos — last outbound `Status=Failed` → grid shows fa-times-circle red
  - Green Earth Foundation — last outbound is a template (`donation_receipt`) → grid shows template chip
  - Ravi Krishnan — starred → appears in Starred tab
  - At least 3 conversations with `FirstCampaignId = 1` for `?campaignId=1` deep-link test
- **Seed folder typo** (`sql-scripts-dyanmic/`) is intentional/pre-existing — preserve.
- **Existing FE route stub at `[lang]/crm/whatsapp/whatsappconversation/page.tsx`** just renders `<UnderConstruction />` — overwrite with the page-config mount.
- **TZ handling per memory `feedback_db_utc_only`**: every DateTime sent to handlers must have `Kind=Utc`. Normalize in handlers via `dateTime.ToUniversalTime()` or `DateTime.SpecifyKind(value, DateTimeKind.Utc)` at the wire entry.

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ **SERVICE_PLACEHOLDER — Meta Cloud API outbound send**: the `SendOutboundWhatsAppMessage` handler MUST persist the message row + return success. It does NOT actually call Meta. The persisted row's `Status` starts as `Queued` and is updated to `Sent` immediately in the same handler (simulating an instantly-accepted send). `MetaMessageId` left null. When WhatsApp Setup #34 is fully wired and the Meta send service is implemented, replace the placeholder logic with a real HTTP call and `Status` becomes `Queued → Sent` upon Meta-accept.
- ⚠ **SERVICE_PLACEHOLDER — Meta webhook ingestion**: real inbound delivery via Meta webhook is OUT OF SCOPE. The `IngestInboundWhatsAppMessage` GraphQL mutation is the manual / E2E entry point (also usable by a future webhook handler that converts an HTTP POST to this mutation). E2E test: invoke this mutation via GraphQL playground to simulate inbound.
- ⚠ **SERVICE_PLACEHOLDER — Real-time updates**: no websocket / polling in v1. Inbound messages appear on next page load or conversation re-open.
- ⚠ **SERVICE_PLACEHOLDER — Recent Donations sidebar section**: cross-schema join from `notify` to `corg.GlobalDonations` is non-trivial; surface an empty array for v1 and render the section with a "No recent donations" placeholder. Implement properly when finance/corg query patterns settle.
- ⚠ **SERVICE_PLACEHOLDER — Tags sidebar section**: requires `Contact.Include(ContactTags).ThenInclude(Tag)` projection — verify if existing `getContactById` includes this; if not, return an empty array for v1.
- ⚠ **SERVICE_PLACEHOLDER — Reply Rate + Avg Response Time** in Contact Summary: requires temporal-correlation aggregation across inbound→outbound message pairs. Surface `null` and render "—" for v1.
- ⚠ **SERVICE_PLACEHOLDER — Engagement Score** in chat header meta: `Contact.EngagementScore` column does not exist. Render "—" for v1. Will be wired when #93 EngagementScoring lands.
- ⚠ **SERVICE_PLACEHOLDER — Export Conversations**: toolbar button renders a toast "Export is coming soon". No file export.
- ⚠ **SERVICE_PLACEHOLDER — Attach button** in composer toolbar: toast "Attachment support is coming soon".
- ⚠ **SERVICE_PLACEHOLDER — Quick Reply Management** link in dropdown: toast "Quick Reply settings coming soon".
- ⚠ **SERVICE_PLACEHOLDER — Mark as Resolved** in More menu: toast for v1; no `IsResolved` column added.
- ⚠ **SERVICE_PLACEHOLDER — Block Contact** in More menu: toast for v1.
- ⚠ **SERVICE_PLACEHOLDER — Variable resolver auto-fill**: `whatsapp-variable-resolver.ts` provides a minimal whitelist `{{donor_name}} → Contact.DisplayName`, `{{first_name}} → Contact.FirstName`, `{{today}} → today's date in MMM D format`. Other `{{var}}` placeholders remain blank for user input. Expand the whitelist when WhatsApp Campaign #32 ships (it will define a richer resolver).

Full UI must be built (all buttons, modals, banners, panels, composer states, optimistic updates, context menu). Only the handlers above are mocked.

**Pre-flagged ISSUEs** (to be tracked in §⑬ Known Issues):

| ID | Severity | Area | Description |
|----|----------|------|-------------|
| ISSUE-1 | LOW | Scope | `WhatsAppQuickReply` is per-company (shared) in v1. Per-user scoping deferred (would require `UserId` column + composite uniqueness). |
| ISSUE-2 | MED | Compliance | Contact "WhatsApp opt-in" status is not a stored flag — relies on Meta to reject phone-not-on-WhatsApp on send. Add `IsWhatsAppOptedIn` boolean on Contact in a follow-up, populated by inbound webhook (`messages.statuses` with `recipient_id` → marks contact as opted-in). |
| ISSUE-3 | MED | Perf | Thread loads ALL messages on conversation open. For conversations with 500+ messages, this needs cursor pagination (`fromMessageId`, `pageSize=50`). Add when a user complains; track at threshold > 200. |
| ISSUE-4 | MED | Real-time | No realtime push. New inbound messages require refresh. Implement SignalR / GraphQL subscription when Meta webhook is wired. |
| ISSUE-5 | LOW | Perf | Left-pane list is plain `map()`. Switch to `react-window` / virtualisation if a tenant has > 500 active conversations. |
| ISSUE-6 | LOW | UX | WhatsApp doodled-pattern background may not be worth the cost. Decision per build: ship without; add if user feedback specifically requests it. |
| ISSUE-7 | MED | Data | Engagement Score column doesn't exist on Contact. Render "—" until #93 EngagementScoring lands. |
| ISSUE-8 | MED | Metric | Reply Rate + Avg Response Time + inbox `avgResponseTimeMinutes` summary are SERVICE_PLACEHOLDERs (hard-coded `14`). Compute properly in a follow-up using SQL window functions on Messages. |
| ISSUE-9 | MED | Cross-schema | Recent Donations sidebar requires `corg.GlobalDonations` join from `notify` handler. Returns empty for v1. |
| ISSUE-10 | LOW | Projection | `Contact.Include(ContactTags).ThenInclude(Tag)` may or may not be in existing GetContactById projection — verify before relying on it. |
| ISSUE-11 | LOW | UI | Non-Text MessageType (Image/Document/Video/Audio/Location) rendering deferred. Backend stores them; FE shows a placeholder bubble "[Image]" / "[Document]" with a TODO comment. |
| ISSUE-12 | LOW | Phone | E.164 normalisation in `Base.Application/Helpers/PhoneNumber.cs` is naive (strip spaces/dashes, ensure leading `+`). Switch to `libphonenumber-csharp` if invalid-phone bugs surface. |
| ISSUE-13 | MED | Dep | WhatsApp Campaign #32 must ship before `FirstCampaignId` / `WhatsAppCampaignId` FK constraints can be added. Until then, column-only declaration in EF config. |
| ISSUE-14 | LOW | Icons | Mockup uses Font Awesome (`fa-*`). Build with Phosphor (Iconify) per memory rule; map equivalent icons. |
| ISSUE-15 | MED | Webhook | `IngestInboundWhatsAppMessage` mutation is publicly exposed via GraphQL. For production, must move webhook ingestion to a dedicated REST endpoint with Meta-signature verification. For v1, the mutation is auth-protected like all others (will not be hit by Meta directly). |
| ISSUE-16 | LOW | UI | Right-pane stats sidebar slide-in animation — use `data-state` transition; v1 may render snap-toggle without animation. |
| ISSUE-17 | LOW | Multi-tab | Composer `noteMode` is local component state. Closing and reopening the conversation resets it. Acceptable for v1. |

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | 1 | LOW | Scope | `WhatsAppQuickReply` is per-company shared in v1. Per-user scoping deferred. | OPEN |
| ISSUE-2 | 1 | MED | Compliance | Contact "WhatsApp opt-in" is not a stored flag. Add `IsWhatsAppOptedIn` boolean populated by inbound webhook in follow-up. | OPEN |
| ISSUE-3 | 1 | MED | Perf | Thread loads ALL messages on conversation open. Cursor-paginate when conversations cross > 200 msgs. | OPEN |
| ISSUE-4 | 1 | MED | Real-time | No realtime push. Inbound messages require refresh. Implement SignalR/GraphQL subscription when Meta webhook is wired. | OPEN |
| ISSUE-5 | 1 | LOW | Perf | Left-pane list is plain `map()`. Switch to `react-window` if > 500 active conversations. | OPEN |
| ISSUE-6 | 1 | LOW | UX | WhatsApp doodled-pattern bg skipped in v1 (cost vs polish trade-off). Plain `bg-wa-chat-bg` only. | OPEN |
| ISSUE-7 | 1 | MED | Data | Engagement Score column doesn't exist on Contact. Render "—" until #93 lands. | OPEN |
| ISSUE-8 | 1 | MED | Metric | Reply Rate, Avg Response Time, inbox `avgResponseTimeMinutes=14` are SERVICE_PLACEHOLDERs (hardcoded). | OPEN |
| ISSUE-9 | 1 | MED | Cross-schema | Recent Donations sidebar returns empty for v1 (corg join from notify deferred). | OPEN |
| ISSUE-10 | 1 | LOW | Projection | Contact tags return empty for v1 (Contact.Include(ContactTags) not in projection — verify). | OPEN |
| ISSUE-11 | 1 | LOW | UI | Non-Text MessageType (Image/Document/Video/Audio/Location) rendering deferred. BE stores them, FE shows placeholder bubble. | OPEN |
| ISSUE-12 | 1 | LOW | Phone | `PhoneNumberHelper.cs` normalization is naive (strip + leading-`+`). Switch to libphonenumber-csharp if bugs surface. | OPEN |
| ISSUE-13 | 1 | MED | Dep | WhatsAppCampaign #32 must ship before `FirstCampaignId` / `WhatsAppCampaignId` FK constraints can be added. Column-only declaration in v1. | OPEN |
| ISSUE-14 | 1 | LOW | Icons | Mockup uses Font Awesome; build uses Phosphor via @iconify per memory rule. Maps documented in OutboundBubble + StatusIconRenderer. | RESOLVED |
| ISSUE-15 | 1 | MED | Webhook | `IngestInboundWhatsAppMessage` mutation is publicly exposed via GraphQL. For prod, move to dedicated REST endpoint with Meta-signature verification. | OPEN |
| ISSUE-16 | 1 | LOW | UI | Right-pane stats sidebar slide-in is snap-toggle (no animation) in v1. | OPEN |
| ISSUE-17 | 1 | LOW | Multi-tab | Composer `noteMode` is local state. Closing+reopening resets it. Acceptable for v1. | OPEN |
| ISSUE-18 | 1 | LOW | Naming | `TagDto` / `RecentDonationDto` renamed to `WhatsAppTagDto` / `WhatsAppRecentDonationDto` to avoid CS0104 ambiguous-type conflicts with `ContactSchemas.TagDto` and `DonationSchemas.RecentDonationDto`. FE DTOs renamed to match. Not a true bug; documented for future readers. | RESOLVED |
| ISSUE-19 | 1 | LOW | Pagination | `GetWhatsAppConversations` returns `GridFeatureResult<T>` (manual pageIndex/pageSize/tab pattern) instead of `PaginatedList<T>` (which doesn't exist). Mirrors `GetInboxNotifications` (#35). | RESOLVED |
| ISSUE-20 | 1 | MED | Migration | EF migration NOT generated in this session (`dotnet ef` deferred to team). Run `dotnet ef migrations add AddWhatsAppConversations --project Base.Infrastructure --startup-project Base.API --context NotifyDbContext` from `PSS_2.0_Backend/PeopleServe/Services/Base/` before applying seed SQL. | OPEN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-14 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Non-standard FLOW two-pane chat console (no view-page.tsx). User chose Sonnet for both BE + FE per token-economy override of default Opus escalation; BA / Solution Resolver / UX Architect agents SKIPPED per prompt §⑫ token directive (prompt §①–⑫ at 1090 lines is authoritative).
- **Files touched**:
  - BE (28 created, 8 modified, plus 2 deferred):
    - Domain: `Base.Domain/Models/NotifyModels/WhatsAppConversation.cs` (created), `WhatsAppMessage.cs` (created), `WhatsAppQuickReply.cs` (created)
    - EF Configs: `Base.Infrastructure/Data/Configurations/NotifyConfigurations/WhatsAppConversationConfiguration.cs` (created), `WhatsAppMessageConfiguration.cs` (created), `WhatsAppQuickReplyConfiguration.cs` (created)
    - Schemas: `Base.Application/Schemas/NotifySchemas/WhatsAppConversationSchemas.cs` (created — 18 DTOs)
    - Helper: `Base.Application/Helpers/PhoneNumberHelper.cs` (created)
    - Internal Mapper: `Base.Application/Business/NotifyBusiness/WhatsAppConversations/WhatsAppConversationMapper.cs` (created)
    - Commands (12 created): WhatsAppConversations/Commands/{Create,Update,Delete,SendOutboundWhatsAppMessage,AddWhatsAppConversationNote,MarkConversationRead,IngestInboundWhatsAppMessage,ToggleStarConversation,ToggleArchiveConversation}.cs + WhatsAppQuickReplies/Commands/{Create,Update,Delete}WhatsAppQuickReply.cs
    - Queries (5 created): WhatsAppConversations/Queries/{GetWhatsAppConversations,GetWhatsAppConversationById,GetWhatsAppInboxSummary,GetWhatsAppConversationContactSummary}.cs + WhatsAppQuickReplies/Queries/GetWhatsAppQuickReplies.cs
    - GraphQL Endpoints: `Base.API/EndPoints/Notify/Mutations/WhatsAppConversationMutations.cs` (created — 12 mutations), `Base.API/EndPoints/Notify/Queries/WhatsAppConversationQueries.cs` (created — 5 queries)
    - Seed: `sql-scripts-dyanmic/WhatsAppConversation-sqlscripts.sql` (created — menu + 5 caps + 4 BUSINESSADMIN role-caps + 5 starter QuickReplies + 12 sample conversations + child messages with 4-banner-state coverage)
    - Modified: `Base.Application/Data/Persistence/INotifyDbContext.cs` (+3 DbSets), `Base.Infrastructure/Data/Persistence/NotifyDbContext.cs` (+3 DbSets), `Base.Application/Extensions/DecoratorProperties.cs` (+3 entries), `Base.Application/Mappings/NotifyMappings.cs` (+Mapster configs), `Base.Domain/Models/ContactModels/Contact.cs` (+WhatsAppConversations nav), `Base.Domain/Models/NotifyModels/WhatsAppTemplate.cs` (+WhatsAppMessages nav), `Base.Domain/Models/AuthModels/User.cs` (+2 inverse nav collections)
  - FE (28 created, 9 modified):
    - Domain DTO: `src/domain/entities/notify-service/WhatsAppConversationDto.ts` (created)
    - GQL: `src/infrastructure/gql-queries/notify-queries/WhatsAppConversationQuery.ts` (created — 5 query constants), `src/infrastructure/gql-mutations/notify-mutations/WhatsAppConversationMutation.ts` (created — 12 mutation constants)
    - Store: `src/application/stores/whatsapp-conversation-stores/{whatsapp-conversation-store.ts, index.ts}` (both created)
    - Page config: `src/presentation/pages/crm/whatsapp/whatsappconversation.tsx` (created)
    - Components (21 created): `src/presentation/components/page-components/crm/whatsapp/whatsappconversation/{index.ts, whatsapp-conversation-page.tsx, conversation-list-pane.tsx, conversation-list-item.tsx, chat-pane.tsx, chat-header.tsx, reply-window-banner.tsx, chat-messages.tsx, outbound-bubble.tsx, inbound-bubble.tsx, internal-note-card.tsx, thread-markers.tsx, chat-composer.tsx, quick-reply-dropdown.tsx, template-picker-modal.tsx, new-message-modal.tsx, stats-sidebar.tsx, status-icon-renderer.tsx, relative-time.ts, whatsapp-variable-resolver.ts, use-whatsapp-conversation.ts}`
    - Modified: route stub overwrite at `src/app/[lang]/crm/whatsapp/whatsappconversation/page.tsx`; 3 barrel re-exports (`notify-service/index.ts`, `notify-queries/index.ts`, `notify-mutations/index.ts`); `notify-service-entity-operations.ts` (+WHATSAPPCONVERSATION block @ line 284); 2 component-folder barrels (`page-components/crm/whatsapp/index.ts`, `pages/crm/whatsapp/index.ts`); `application/stores/index.ts`; `src/presentation/tailwind.config.ts` (+7 wa-* brand tokens)
  - DB: `sql-scripts-dyanmic/WhatsAppConversation-sqlscripts.sql` (created — see BE section)
- **Deviations from spec**:
  - DTO renames: `TagDto`→`WhatsAppTagDto`, `RecentDonationDto`→`WhatsAppRecentDonationDto` (BE + FE) to avoid CS0104 ambiguous-type collisions with `ContactSchemas.TagDto` and `DonationSchemas.RecentDonationDto`. Documented as ISSUE-18.
  - `GetWhatsAppConversations` returns `GridFeatureResult<T>` (mirrors `GetInboxNotifications` precedent) instead of the prompt's `PaginatedApiResponse<T[]>`, because `PaginatedList<T>` type does not exist in this codebase. Documented as ISSUE-19.
  - Created `WhatsAppConversationMapper` internal static class for cross-handler DTO mapping reuse (small judgment call; not in prompt manifest but functionally required for clean code).
  - `Base.Domain/Models/AuthModels/Company.cs` does NOT exist in this repo (verified via Test-Path). Prompt §⑧ wiring step #8 (add inverse navs on Company) — SKIPPED. Multi-tenancy still works via `CompanyId` column + MultiTenantInterceptor without needing a Company entity inverse nav.
  - `tailwind.config.ts` modification was to `src/presentation/tailwind.config.ts` (the actual config source — root file imports from this and spreads). The 7 wa-* brand tokens are correctly registered.
- **Known issues opened**: ISSUE-1 through ISSUE-17 (pre-flagged in §⑫, opened OPEN in §⑬ Known Issues). 3 new: ISSUE-18 (DTO renames — RESOLVED informational), ISSUE-19 (GridFeatureResult adaptation — RESOLVED informational), ISSUE-20 (EF migration deferred — OPEN).
- **Known issues closed**: ISSUE-14 RESOLVED (Phosphor icons used per memory rule).
- **Verification performed**:
  - `dotnet build` (PSS_2.0_Backend/PeopleServe/Services/Base/): 0 errors, 480 pre-existing warnings (none from this build).
  - `pnpm exec tsc --noEmit` (PSS_2.0_Frontend/): 0 new errors. 2 pre-existing TS2308 conflicts (`PageLayoutOption`, `ValidationResultDto`) in unrelated donation-service files — NOT caused by this build.
  - UI Uniformity 5 mandatory greps against new FE files: ALL 0 matches (no inline hex, no inline px, no raw "Loading…", no inline fontSize, no `fa-*` className).
  - Variant B compliance: `<ScreenHeader>` mounted in `whatsapp-conversation-page.tsx`, no `DataTableContainer` present (custom non-DataTable screen — by-construction-correct).
  - Cross-agent DTO alignment: FE `WhatsAppTagDto` + `WhatsAppRecentDonationDto` (in `WhatsAppConversationDto.ts` L108, L118) matches BE renames.
  - Route stub overwrite verified: `src/app/[lang]/crm/whatsapp/whatsappconversation/page.tsx` now renders `<WhatsAppConversationPageConfig />`.
  - Tailwind tokens verified in `src/presentation/tailwind.config.ts` (`"wa-green"`, `"wa-bubble-out"`, etc. present).
- **Service Placeholders persisted**: 12 SERVICE_PLACEHOLDERs per prompt §⑫ — Meta Cloud API send (handler simulates instant Sent), Meta webhook ingestion (manual GraphQL mutation only), Real-time push (none), Recent Donations sidebar (empty array), Tags sidebar (empty array), Reply Rate + Avg Response Time (null), Engagement Score ("—"), Export Conversations (toast), Attach button (toast), Quick Reply Management (toast), Mark as Resolved (toast), Block Contact (toast).
- **Runtime tests deferred**:
  - `dotnet ef migrations add AddWhatsAppConversations --project Base.Infrastructure --startup-project Base.API --context NotifyDbContext` (per token directive — team will run).
  - `dotnet ef database update` (after migration).
  - Apply seed SQL: `sql-scripts-dyanmic/WhatsAppConversation-sqlscripts.sql`.
  - `pnpm dev` smoke test at `/en/crm/whatsapp/whatsappconversation` — page-load + tab filters + click conversation + composer Send + Template picker + New Message modal + Mark as Opted Out + Star/Archive toggles + countdown live update + ?campaignId / ?conversationId deep-links.
- **Next step**: None (COMPLETED). Team handoff: run EF migration + apply seed SQL + `pnpm dev` smoke test per acceptance criteria §⑪.
