---
screen: PrayerRequestReplyQueue (Tab 2 content within PrayerRequests workspace)
registry_id: 137
module: CRM (Prayer Request)
status: COMPLETED
scope: TAB_CONTENT — extends #136 workspace; introduces NEW child entity `corg.PrayerRequestReplies` + reply CRUD/submit handlers + Tab 2 components (replaces `<TabComingSoon label="Reply Queue" releaseTarget="#137" />` slot). NO new menu, NO new route, NO new sidebar entry.
screen_type: FLOW (inside tab — grid + 3-mode view-page constrained to `?tab=replyqueue&mode=...` URL semantics)
parent_workspace: PRAYERREQUESTS (built by #136 — capability gate REPLY_DRAFT already seeded)
workspace_tab_key: replyqueue
complexity: Medium-High
new_module: NO (`corg` schema exists; `corg.PrayerRequests` parent exists from #136/#171)
new_table: YES — `corg.PrayerRequestReplies` (first 1:N child of `corg.PrayerRequests`)
planned_date: 2026-05-12
completed_date: 2026-05-12
last_session_date: 2026-05-12
---

> **Mockup status (ISSUE-1 carry-over)**: NO HTML mockup at `html_mockup_screens/screens/prayer-request/reply-queue*.html`. Spec authored 2026-05-12 from PSS 2.0 pastoral-care domain knowledge + #136 precedent. All grid columns / form sections / detail layouts below are SPEC, not mockup-extracted. UX Architect agent may refine card order / iconography / copy without changing semantics.

> **TAB_CONTENT scope (re-scoped 2026-05-12)**: This screen does NOT register a new sidebar menu, does NOT add a new route, and does NOT touch the workspace shell wiring. It builds the **content** that replaces the `<TabComingSoon label="Reply Queue" releaseTarget="#137" />` placeholder slot inside the existing `prayerrequests-workspace.tsx` (built by #136). The URL semantics extend #136's tab pattern: `?tab=replyqueue` (grid) / `?tab=replyqueue&mode=draft&prayerId=N` (new draft for prayer N) / `?tab=replyqueue&mode=edit&id=R` (edit reply R) / `?tab=replyqueue&mode=read&id=R` (detail). Capability gate: **`REPLY_DRAFT`** (already seeded on the PRAYERREQUESTS menu by #136 — no new role-capability INSERT needed).

> **New child entity**: This screen introduces **`corg.PrayerRequestReplies`** — the first 1:N child of `corg.PrayerRequests`. Each row represents one staff-drafted reply to a specific prayer. Multiple replies per prayer are allowed (re-drafts after supervisor rejection, multi-channel replies — e.g., one EMAIL + one SMS). The reply lifecycle (Draft → SubmittedForReview → Approved/Rejected → Sent/Failed) is partially built here (#137 handles Draft + SubmittedForReview transitions); the Approve/Reject transitions belong to #138; the actual Send transition belongs to a future build (when SMS/Email/WhatsApp service layers are wired — see §⑫ SERVICE_PLACEHOLDER).

> **Workspace handoff pattern (ISSUE-5 closure)**: #136 left three named extension points for #137/#138 to hook into:
> 1. `<TabComingSoon label="Reply Queue" releaseTarget="#137" />` in `prayerrequests-workspace.tsx` line ~216 — **replace with `<ReplyQueueTabContent />`**
> 2. `prayerrequests-workspace-store.ts` already has `tabBadges: { entry, replyqueue, reviewreplies }` Zustand state — **populate `replyqueue` badge from new summary query**
> 3. Existing `useAccessCapability({ menuCode: "PRAYERREQUESTS" })` returns `capabilities.canRead` etc.; **#137 must extend it to surface `canReplyDraft` as a named flag (currently soft-falls-back to canRead — closes ISSUE-8)**

---

## Tasks

### Planning (by /plan-screens)
- [x] Domain spec authored (mockup TBD — ISSUE-1)
- [x] Workspace extension strategy chosen — Tab content swap, no new menu/route
- [x] Workflow scope locked: Draft + Submit/Recall (Approve/Reject = #138; Send = SERVICE_PLACEHOLDER)
- [x] New child entity designed: `corg.PrayerRequestReplies` (17 fields + 4 FKs)
- [x] FK targets resolved (PrayerRequest parent, Contact ×3 for DraftedBy/LastUpdatedBy/ReviewedBy)
- [x] File manifest computed (13 BE files + 9 FE files + 2 wiring extensions)
- [x] Approval-config strategy: NO_NEW_MENU — capability REPLY_DRAFT already seeded by #136; sample-data only
- [x] ISSUE-5 closure plan (workspace shell extension points)
- [x] ISSUE-8 closure plan (useAccessCapability named-flag surface)
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] BA Analysis validated (audience + reply lifecycle + channel matrix + permissions)
- [x] Solution Resolution complete (FLOW-in-tab pattern; new child entity; workflow handlers)
- [x] UX Design finalized (FORM = 4 stacked cards w/ channel selector + conditional sub-form; DETAIL = 3-card read view w/ status badge + action bar)
- [x] User Approval received
- [x] Backend code generated (NEW entity + EF config + 5 handlers + 3 queries + 2 endpoint files + EF migration)
- [x] Backend wiring complete (IContactDbContext + ContactDbContext + DecoratorProperties + Mapster + parent entity nav collection)
- [x] Frontend code generated (DTO + GQL query/mutation + 9 tab-content files + workspace shell `<TabComingSoon>` swap + useCapability extension + SummaryCard lift)
- [x] Frontend wiring complete (workspace shell tab content registration + prayerId cleanup + entity-operations PRAYERREQUEST_REPLYQUEUE block + 3 barrel updates + Tab1 SummaryCard import update)
- [x] DB Seed script generated (sample 2 reply rows for E2E QA — no menu/cap inserts)
- [x] EF Migration generated (`Add_PrayerRequestReplies_Table`)
- [x] ISSUE-5 / ISSUE-8 closed
- [x] Registry updated to COMPLETED

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] EF migration applies cleanly (new table — no data risk)
- [ ] `pnpm dev` — workspace loads at `/{lang}/crm/prayerrequest/prayerrequests` and Tab 2 chip now reads "Reply Queue" with badge count
- [ ] Click Tab 2 → URL becomes `?tab=replyqueue` → grid loads listing **Approved prayers** (Status=Approved on parent PrayerRequest) with derived "Reply Status" column
- [ ] 3 KPI widgets render above grid: Awaiting Reply / In Draft / Submitted for Review (counts non-zero for seed data)
- [ ] Filter "Reply Status: All / None / Draft / Submitted / Approved / Sent" works
- [ ] Filter "Channel: All / EMAIL / SMS / WHATSAPP / PHONE / LETTER / IN_PERSON" works
- [ ] Row → "Draft Reply" action → URL `?tab=replyqueue&mode=draft&prayerId=N` → FORM loads with prayer context card pre-populated read-only
- [ ] Channel card selector switches sub-form fields (EMAIL shows subject+recipient-email override; SMS hides subject; PHONE shows call-summary; LETTER shows postal-address override; IN_PERSON hides all transport fields)
- [ ] Reply Body RHF validation: required, max 8000 chars, profanity-flag toast warning (re-uses #171 profanity service if available)
- [ ] "Save as Draft" → POST `CreatePrayerRequestReply` → returns reply ID → URL redirects to `?tab=replyqueue&mode=read&id={newId}`
- [ ] DETAIL layout renders: prayer-context card + reply card + status-action bar (Edit / Submit for Approval if Draft)
- [ ] "Submit for Approval" → POST `SubmitPrayerRequestReplyForReview` → row Status flips to `SubmittedForReview` → grid badge moves from "In Draft" KPI to "Submitted for Review" KPI
- [ ] "Recall" button (only on SubmittedForReview rows owned by current user) → reverts Status to `Draft`
- [ ] Edit existing Draft → `?tab=replyqueue&mode=edit&id=R` → FORM pre-fills → Save updates row
- [ ] Soft-delete a Draft (button gated by REPLY_DRAFT + DraftedBy=current user) → row hidden from grid
- [ ] Multi-tenant isolation: staff in tenant A cannot see/edit replies from tenant B
- [ ] Server-stamping verified: `CompanyId`, `DraftedByContactId`, `DraftedAt`, `SubmittedForReviewAt` NEVER trusted from request body
- [ ] CreateReply rejects if parent prayer Status ≠ Approved (returns validation error "Cannot draft a reply for a non-approved prayer")
- [ ] UpdateReply rejects if reply Status ≠ Draft (server returns 422; FE toast)
- [ ] Empty state ("No prayers awaiting reply yet — once you approve a prayer in the Entry tab, it lands here") + Loading skeleton render
- [ ] useAccessCapability now surfaces `canReplyDraft` as a named flag (ISSUE-8 closed) — workspace tab chip enables/disables on real capability, not soft fallback
- [ ] DB Seed — 2 sample replies seeded (1 Draft, 1 SubmittedForReview) link to existing seeded PrayerRequests
- [ ] If REPLY_APPROVE capability is granted (for #138 testing), the "Approved by reviewer" reply shows up read-only with status badge (no edit/recall — those belong to #138)

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **Reply Queue** (Tab 2 content within the PrayerRequests workspace; same sidebar menu as Tab 1)
Module: **CRM** (Prayer Request)
Schema: **`corg`**
Group: **ContactModels** (parent + new child)
Parent Workspace Tab Key: **`replyqueue`**

Business: After a prayer request lands in `corg.PrayerRequests` (whether via public submission from #171 or internal staff intake from #136) and a moderator approves it (Status → `Approved`), the next step in the pastoral-care workflow is **drafting a personal reply** that will eventually be sent back to the prayer submitter. This is the screen where prayer-team staff sit down with the queue of approved prayers and write — typically in small batches — a one-to-one encouragement reply (a Bible verse, a personal note, an invitation to a service, a follow-up phone callback summary). Drafting happens here, on Tab 2. Once a draft is ready, the drafter clicks "Submit for Approval" — which routes the draft to **Tab 3 Review Replies (#138)** where a supervisor (typically a senior pastor or pastoral-care lead) reviews, optionally edits, and approves. Only after supervisor approval is the reply queued for transport — outbound send via email/SMS/WhatsApp is a downstream service that's out of scope for this build (see §⑫ SERVICE_PLACEHOLDER). The headline interaction goal is "a prayer-team staff member working through 10 approved prayers should be able to draft + submit 10 replies in under 15 minutes." Secondary goals: (a) each prayer can receive multiple replies — e.g., an SMS *and* an Email *and* a follow-up phone-call summary — so the data model is 1:N (one PrayerRequest → many PrayerRequestReplies); (b) drafters can save partially written replies and resume later (Draft state); (c) drafters can recall their own submission if they realize a mistake (SubmittedForReview → Draft); (d) supervisor-rejected replies (rejected by #138) come back here as Draft and the drafter can revise + resubmit. **Audience**: pastoral-care drafters with REPLY_DRAFT capability. **What's unique vs. Tab 1**: Tab 1 surfaces ALL prayers (any status, any channel) and is intake-focused; Tab 2 surfaces ONLY approved prayers and is reply-focused. **What breaks if mis-set**: (a) drafting a reply for an Unapproved prayer would short-circuit the moderation pipeline (must reject server-side with validation error); (b) failing to server-stamp DraftedByContactId would break the audit trail (supervisors must always know WHO wrote a reply); (c) allowing edits to SubmittedForReview replies by anyone except the drafter would race with the supervisor's review session (#138); (d) cross-tenant leak (a drafter in tenant A seeing tenant B's prayers — must filter by CompanyId on every query). **Related screens**: Tab 1 #136 (prayers are approved there before they land here), Tab 3 #138 (supervisor consumes the SubmittedForReview replies from this tab), future Send-Service (consumes Approved replies and dispatches via email/SMS/WhatsApp).

> **Why this section is heavy**: there is NO mockup; the BA / UX Architect / Backend / Frontend agents all need this rich prose to make consistent decisions about the reply lifecycle, the 1:N relationship, the workspace-tab-content extension model, and the deferred Send-Service. Cutting it shorter would force each agent to guess.

---

## ② Entity Definition

> **Consumer**: BA Agent → Backend Developer
> **CRITICAL**: This screen INTRODUCES a NEW table. It does NOT alter `corg.PrayerRequests`. Generate a fresh EF migration `Add_PrayerRequestReplies_Table` that creates the new table + its 4 FKs + 3 indexes.

Table: `corg."PrayerRequestReplies"` (NEW — first 1:N child of `corg.PrayerRequests`)

### Columns

| Field | C# Type | MaxLen | Required | FK Target | Notes |
|-------|---------|--------|----------|-----------|-------|
| `PrayerRequestReplyId` | `int` | — | PK identity | — | Primary key — UseIdentityAlwaysColumn |
| `CompanyId` | `int` | — | YES | — | **Server-stamped from HttpContext** — never from request body |
| `PrayerRequestId` | `int` | — | YES (FK) | `corg.PrayerRequests` | Parent prayer — required; FK Restrict (preserve replies if parent soft-deleted via IsActive) |
| `ReplyChannel` | `string` | 20 | YES | — | `EMAIL` / `SMS` / `WHATSAPP` / `PHONE` / `LETTER` / `IN_PERSON` (validated by `ReplyChannelTypes` static class) |
| `ReplySubject` | `string?` | 200 | NO | — | Only used for EMAIL channel — null otherwise |
| `ReplyBody` | `string` | 8000 | YES | — | The reply text — HTML stripped server-side; min 5 chars |
| `Status` | `string` | 20 | YES | — | `Draft` / `SubmittedForReview` / `Approved` / `Rejected` / `Sent` / `Failed` — defaults to `Draft` on Create |
| `InternalNote` | `string?` | 1000 | NO | — | Drafter's note to the reviewer (e.g., "checked Scripture ref in NIV") — NEVER part of the outbound reply |
| `DraftedByContactId` | `int` | — | YES (FK) | `corg.Contacts` | Staff drafter — **server-stamped from HttpContext.User.ContactId** on Create; never from request body |
| `DraftedAt` | `DateTime` | — | YES | — | **Server-stamped = `DateTime.UtcNow`** on Create |
| `LastUpdatedByContactId` | `int?` | — | NO (FK) | `corg.Contacts` | Last editor — server-stamped on Update; null on first Create |
| `LastUpdatedAt` | `DateTime?` | — | NO | — | Server-stamped on Update |
| `SubmittedForReviewAt` | `DateTime?` | — | NO | — | Server-stamped when status transitions Draft → SubmittedForReview |
| `ReviewedByContactId` | `int?` | — | NO (FK) | `corg.Contacts` | Supervisor — set by #138 (not by this build); FK Restrict |
| `ReviewedAt` | `DateTime?` | — | NO | — | Set by #138 |
| `ReviewerNote` | `string?` | 1000 | NO | — | Supervisor's note on Approve/Reject — set by #138; surfaces in this tab when reviewer rejects (drafter sees why) |
| `SentAt` | `DateTime?` | — | NO | — | Set by future Send-Service (SERVICE_PLACEHOLDER); null in this build |
| `DeliveryRefId` | `string?` | 200 | NO | — | Provider message-id (SMS gateway, email transport) — set by Send-Service; null in this build |
| `RecipientEmailOverride` | `string?` | 200 | NO | — | Used only when ReplyChannel=EMAIL and drafter wants to send to an address other than `LinkedContact.PrimaryEmail` (rare; e.g., spouse's email per submitter's request) |
| `RecipientPhoneOverride` | `string?` | 30 | NO | — | Used only when ReplyChannel=SMS/WHATSAPP and override needed |

> Inherited from `Entity` base: `IsActive`, `IsDeleted`, `CreatedBy`, `CreatedDate`, `LastModifiedBy`, `LastModifiedDate` — do NOT list in the entity properties.

### Allowed `ReplyChannel` values (string column, enforced by validator + `ReplyChannelTypes` static class)

| Value | Description | Channel-specific UI fields |
|-------|-------------|----------------------------|
| `EMAIL` | Outbound email reply | `ReplySubject` (required) + `RecipientEmailOverride` (optional) |
| `SMS` | Outbound SMS | `RecipientPhoneOverride` (optional) — no subject |
| `WHATSAPP` | Outbound WhatsApp | `RecipientPhoneOverride` (optional) — no subject |
| `PHONE` | Phone callback transcript (one-way log; no auto-dial) | No subject, no recipient override — body = call summary |
| `LETTER` | Postal letter (printable PDF generated by future service) | No subject, no recipient override — body printed onto letterhead |
| `IN_PERSON` | In-person follow-up (log-only — no transport) | No subject, no recipient override — body = visit notes |

Add a `ReplyChannelTypes` static class to `Base.Application/Constants/` mirroring the existing `ReceivedSourceTypes` pattern. Validator must reject any unlisted value.

### Allowed `Status` values (state machine — built here for Draft + SubmittedForReview; future states owned by #138 + Send-Service)

| Value | Set by | Transitions FROM |
|-------|--------|-------------------|
| `Draft` | CreatePrayerRequestReply (initial) + RecallPrayerRequestReply (from SubmittedForReview) + #138 Reject (from Approved/SubmittedForReview) | (none) / SubmittedForReview / Approved |
| `SubmittedForReview` | SubmitPrayerRequestReplyForReview | Draft |
| `Approved` | (set by #138 — `ApprovePrayerRequestReply`) | SubmittedForReview |
| `Rejected` | (set by #138 — `RejectPrayerRequestReply`) | SubmittedForReview / Approved (recall-and-reject) |
| `Sent` | (set by future Send-Service when transport succeeds) | Approved |
| `Failed` | (set by future Send-Service on transport failure) | Approved |

**This build's responsibilities**: Create (→ Draft), Update (Draft only), Submit (Draft → SubmittedForReview), Recall (SubmittedForReview → Draft), soft-Delete (Draft only).
**Out of scope for this build**: Approve / Reject / Sent / Failed transitions — those belong to #138 + Send-Service.

### Child Entity Relationship (with parent PrayerRequest)

Parent file (existing): `Base.Domain/Models/ContactModels/PrayerRequest.cs`
**Modification**: Add navigation collection `public virtual ICollection<PrayerRequestReply>? PrayerRequestReplies { get; set; }` at line ~146 (alongside existing `PrayerRequestPrayedLogs`).

### Validation contract for Create/Update DTOs

| Field | Required (Create) | Required (Update) | Validation |
|-------|------------------|-------------------|------------|
| `PrayerRequestId` | YES | (immutable after Create) | Must exist + belong to same Company + Status=`Approved` (rejected for Rejected/Archived/New) |
| `ReplyChannel` | YES | YES | Must be one of `EMAIL / SMS / WHATSAPP / PHONE / LETTER / IN_PERSON` |
| `ReplySubject` | Conditional | Conditional | Required when `ReplyChannel = EMAIL`; max 200 chars; rejected if non-EMAIL |
| `ReplyBody` | YES | YES | Min 5 chars; max 8000 chars; HTML stripped server-side |
| `InternalNote` | NO | NO | Max 1000 chars |
| `RecipientEmailOverride` | NO | NO | Valid email format; rejected if ReplyChannel ≠ EMAIL |
| `RecipientPhoneOverride` | NO | NO | E.164 format; rejected if ReplyChannel ∉ {SMS, WHATSAPP} |
| `Status` | — | — | **STAMPED SERVER-SIDE** — `Draft` on Create; transitions only via Submit/Recall (not via Update) |
| `CompanyId` | — | — | **STAMPED SERVER-SIDE** from HttpContext — never from request body |
| `DraftedByContactId` | — | — | **STAMPED SERVER-SIDE** from HttpContext.User.ContactId on Create — never trusted from request body |
| `DraftedAt` / `LastUpdatedAt` / `SubmittedForReviewAt` | — | — | **SERVER-STAMPED** = `DateTime.UtcNow` at appropriate transition |

### Computed defaults on Create

- `Status` ← `Draft`
- `IsActive` ← `true`
- `LastUpdatedByContactId` ← `null`
- `LastUpdatedAt` ← `null`
- `SubmittedForReviewAt` ← `null`
- All `Review*` and `Sent*` fields ← `null`

### EF migration safety notes

- New table — no existing-row backfill needed.
- New FKs to `corg.Contacts` and `corg.PrayerRequests` — both target tables exist; no FK ordering risk.
- Parent entity gets a nav collection only — no schema change on `corg.PrayerRequests` (collection nav doesn't generate SQL).
- 3 indexes (see §⑥ Index Strategy below).

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` / navigation) + Frontend Developer (ApiSelect — only used for drafter override picker, NOT for the FK columns since DraftedBy/LastUpdatedBy are server-stamped)

| FK Field | Target Entity | Entity File Path | GQL Query Name (FE) | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------------|---------------|-------------------|
| `PrayerRequestId` | PrayerRequest | `Base.Domain/Models/ContactModels/PrayerRequest.cs` | `getAllPrayerRequestList` (filter `statuses: ["Approved"]`) | composite `submitterFirstName + " " + submitterLastName` or `title` or `body` excerpt | `PrayerRequestEntryResponseDto` (reuse from #136) |
| `DraftedByContactId` | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | (NOT exposed as a picker — server-stamped) | `displayName` | `ContactResponseDto` — **read-only display in DETAIL view ONLY** |
| `LastUpdatedByContactId` | Contact | (same) | (NOT exposed as a picker) | `displayName` | `ContactResponseDto` — read-only display |
| `ReviewedByContactId` | Contact | (same) | (NOT exposed in this build — set by #138) | `displayName` | `ContactResponseDto` — read-only display if non-null |

**No FK pickers on the FORM** — drafter doesn't choose any FK manually (PrayerRequestId is locked in from the URL `&prayerId=N`; all Contact FKs are server-stamped). The form's "FK widgets" are reduced to a single channel card selector + a body editor + optional override fields. This is a feature-rich form despite having zero ApiSelect dropdowns.

**MasterData reference** (no FK column — lookup by code):

| Code Type | MasterDataType | Used For |
|-----------|----------------|----------|
| `PRAYERCATEGORY` | (already seeded by #171) | Read-only in the prayer-context card on the Reply form (shows the original prayer's category emoji + name) |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- NO uniqueness constraint — multiple replies per prayer ARE allowed (multi-channel, re-drafts after supervisor rejection).
- Soft uniqueness: at any moment, a prayer should have AT MOST one `Draft` and AT MOST one `SubmittedForReview` reply PER channel-and-drafter combination. The validator must reject a Create that would produce a second `Draft` from the same drafter on the same channel for the same prayer (forces the drafter to either resume or delete the existing draft).

**Required Field Rules:**
- `PrayerRequestId`, `ReplyChannel`, `ReplyBody` are mandatory on Create + Update
- `ReplySubject` conditionally required (only when `ReplyChannel = EMAIL`)

**Conditional Rules:**
- If `ReplyChannel = EMAIL` → `ReplySubject` required; `RecipientEmailOverride` allowed (if blank → use `LinkedContact.PrimaryEmail` or `Prayer.SubmitterEmail`).
- If `ReplyChannel = SMS` or `WHATSAPP` → `ReplySubject` must be null; `RecipientPhoneOverride` allowed (if blank → use `LinkedContact.PrimaryPhone` or `Prayer.SubmitterPhone`).
- If `ReplyChannel = PHONE / LETTER / IN_PERSON` → `ReplySubject`, both overrides must be null (validator rejects non-null values).
- Reply may only be created for prayers where `PrayerRequest.Status = Approved`. (Validator queries parent + rejects if Status ∈ `New / Rejected / Praying / Answered / Archived` — pastoral-care rule: drafter shouldn't reply to an un-moderated prayer.)
- If parent prayer's `LinkedContactId` is null AND `Prayer.SubmitterEmail/Phone` are null AND drafter picks EMAIL/SMS/WHATSAPP with no override → soft warning (toast: "No recipient address on file — provide an override"). Server still saves the draft, but on `SubmitForReview` it rejects (hard validation — supervisor's queue should never contain undeliverable replies).

**Business Logic:**
- Create: server stamps `Status=Draft`, `DraftedByContactId=HttpContext.User.ContactId`, `DraftedAt=UtcNow`, `CompanyId=HttpContext.User.CompanyId`. Body is HTML-stripped via existing `HtmlSanitizer` service (reused from #171).
- Update: allowed ONLY when current `Status = Draft` AND (caller is `DraftedByContactId` OR caller has `MODIFY` capability). Server stamps `LastUpdatedByContactId` + `LastUpdatedAt`.
- Submit: transitions `Draft → SubmittedForReview`. Allowed by drafter OR a `MODIFY` cap holder. Server stamps `SubmittedForReviewAt = UtcNow`. Fires no notification yet (notification service is SERVICE_PLACEHOLDER — see §⑫); the row simply becomes visible to #138's queue.
- Recall: transitions `SubmittedForReview → Draft`. Allowed ONLY by `DraftedByContactId` (not by other drafters; not by reviewers — reviewers reject via #138). Clears `SubmittedForReviewAt`.
- Delete (soft, sets `IsActive=false`): allowed ONLY on `Status=Draft` AND by `DraftedByContactId` OR `DELETE` cap holder. Replies in SubmittedForReview/Approved/Rejected/Sent/Failed CANNOT be soft-deleted from this tab (Reviewer rejection in #138 archives instead). Hard-delete is not exposed.

**Workflow** (state machine — owned partly by this build, partly by #138):

```
                                  ┌────────────── (Submit, by drafter) ──────────► SubmittedForReview
                                  │                                                          │
                                  │                                                          ├── (Approve, by #138 reviewer) ──► Approved ──► (Send, by future Send-Service) ──► Sent / Failed
                                  │                                                          │
   (Create) ──► Draft ◄───────────┤◄── (Recall, by drafter only) ────────────────────────────┘
                                  │
                                  │                                                          ┌── (Reject, by #138 reviewer) ──► Rejected
                                  │                                                          │
                                  └◄── (revise after rejection) ◄────────────────────────────┘
```

States built in this build (#137): **Draft, SubmittedForReview**.
States set externally: **Approved/Rejected** by #138; **Sent/Failed** by future Send-Service.

This build creates handlers for: `CreateReply`, `UpdateReply`, `SubmitReplyForReview`, `RecallReply`, `DeleteReply` (soft).
This build creates queries for: `GetReplyQueueList`, `GetPrayerRequestReplyById`, `GetReplyQueueSummary`.
This build does NOT create: `ApproveReply` / `RejectReply` (owned by #138) / `MarkReplySent` (owned by Send-Service).

**Permission Matrix:**

| Action | Required Capability | Additional Check |
|--------|---------------------|-------------------|
| View Reply Queue grid | `REPLY_DRAFT` | tenant scope |
| View any reply detail | `REPLY_DRAFT` OR `REPLY_APPROVE` | tenant scope |
| Create new draft | `REPLY_DRAFT` | parent prayer Status=Approved |
| Update own draft | `REPLY_DRAFT` | caller = DraftedBy AND Status=Draft |
| Update any draft | `REPLY_DRAFT + MODIFY` | Status=Draft |
| Submit own draft for review | `REPLY_DRAFT` | caller = DraftedBy AND Status=Draft |
| Recall own submission | `REPLY_DRAFT` | caller = DraftedBy AND Status=SubmittedForReview |
| Soft-delete own draft | `REPLY_DRAFT + DELETE` | caller = DraftedBy AND Status=Draft |
| Approve / Reject | (owned by #138 — `REPLY_APPROVE`) | not exposed in this build |

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on context.

**Screen Type**: TAB_CONTENT (FLOW pattern constrained to a workspace tab)
**Type Classification**: Workflow / Transactional / New child entity / State machine (Draft + SubmittedForReview)
**Reason**: This is a transactional screen with a state machine and a 1:N relationship to the parent prayer. The mockup-equivalent (spec-derived) calls for a grid + full-page view (not a modal) because the body editor needs vertical real estate. URL semantics extend #136's existing `?tab=replyqueue&mode=...&id=...` pattern. NO new menu/route — content swaps in for the existing `<TabComingSoon>` slot.

**Backend Patterns Required:**
- [x] New entity + EF Config (PrayerRequestReply)
- [x] EF Migration (`Add_PrayerRequestReplies_Table`)
- [x] Standard CRUD-like handlers (Create + Update + Delete; no Toggle — we use IsActive directly via DeleteSoft)
- [x] Tenant scoping (CompanyId from HttpContext on ALL queries/mutations)
- [x] Multi-FK validation (parent prayer must be Approved + same Company; DraftedBy stamped from context)
- [x] Workflow commands (`SubmitPrayerRequestReplyForReview`, `RecallPrayerRequestReply`)
- [x] Composite "list with derived state" query (`GetReplyQueueList` joins PrayerRequest + latest-PrayerRequestReply per prayer)
- [x] Summary query (`GetReplyQueueSummary`) — 3 KPI counts
- [ ] File upload — N/A this build
- [ ] Body HTML sanitization — reuse existing service from #171
- [x] Soft-uniqueness rule (at-most-one-Draft per drafter/channel/prayer)

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) — `displayMode: table`
- [x] view-page.tsx with 3 URL modes (`draft` / `edit` / `read`) — scoped to `?tab=replyqueue`
- [x] React Hook Form (FORM layout)
- [x] Zustand store (`reply-queue-store.ts`) — tab-local state (active filters, optimistic submit state)
- [x] Unsaved changes dialog (when navigating away from a dirty Draft)
- [x] FlowFormPageHeader (Back + Save-as-Draft + Submit-for-Approval buttons; conditional)
- [x] Layout Variant B: `<ScreenHeader>` is ALREADY rendered by the workspace shell (built by #136); this tab uses `<DataTableContainer showHeader={false}>` (NOT `<FlowDataTable>` with internal header) to avoid duplicate header — the shared `FlowDataTable` was extended with `showHeader?: boolean` prop by #136 (default `true`); this tab passes `showHeader={false}`.
- [x] 3 Summary widgets (KPI cards) above the grid: Awaiting Reply / In Draft / Submitted for Review
- [x] Channel card selector (6 visual cards: Email / SMS / WhatsApp / Phone / Letter / In-Person)
- [x] Conditional sub-form fields (subject + email override for EMAIL; phone override for SMS/WhatsApp; nothing for the rest)
- [x] Status badge color matrix (Draft=gray / SubmittedForReview=amber / Approved=green / Rejected=red / Sent=blue / Failed=red-darker)
- [x] Workflow action bar in DETAIL: Edit (Draft only) + Submit (Draft only) + Recall (SubmittedForReview owned by current user) + Soft-Delete (Draft owned by current user)
- [x] Tab content registration in workspace shell (`prayerrequests-workspace.tsx` line ~216)
- [x] useAccessCapability extension to surface `canReplyDraft` as named flag (ISSUE-8 closure)

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Spec-derived (no HTML mockup — ISSUE-1). All details below are SPEC; UX Architect agent may adjust visual treatment.

### Tab Position & URL Semantics

- This tab is **Tab 2** in the workspace. Activated when URL = `?tab=replyqueue`.
- The tab content has internal URL modes that ADD to the tab key:

```
URL                                                              UI Layout
─────────────────────────────────────────────────────            ─────────────────────────
?tab=replyqueue                                                  Grid (Reply Queue list)
?tab=replyqueue&mode=draft&prayerId=N                            FORM Layout (new draft)
?tab=replyqueue&mode=edit&id=R                                   FORM Layout (edit Draft)
?tab=replyqueue&mode=read&id=R                                   DETAIL Layout (read)
```

> The workspace shell already manages `?tab=` parsing. The tab's internal component reads `mode` + `prayerId` + `id` from `useSearchParams()` and dispatches between the three sub-views (grid / form / detail).

### Grid/List View

**Display Mode**: `table` (default — transactional reply queue, dense rows preferred)

**Grid Layout Variant**: `widgets-above-grid` (3 KPI cards above the grid → triggers Variant B: `<ScreenHeader>` is rendered by workspace shell ONCE; the tab uses widget components + `<DataTableContainer showHeader={false}>`)

**KPI Widgets** (3, in row at top of tab):

| # | Widget Title | Value Source | Display Type | Color Cue | Position |
|---|-------------|-------------|-------------|-----------|----------|
| 1 | **Awaiting Reply** | `awaitingReplyCount` from `GetReplyQueueSummary` (Approved prayers with NO reply record) | count | amber | left |
| 2 | **In Draft** | `inDraftCount` from `GetReplyQueueSummary` (Status=Draft, mine if not admin) | count | blue | center |
| 3 | **Submitted for Review** | `submittedForReviewCount` from `GetReplyQueueSummary` (Status=SubmittedForReview, mine if not admin) | count | green | right |

> Subtitle for each card: small text "Last 30 days" + dimmed total ALL-time count.
> Each card is clickable — clicking the card pre-filters the grid (e.g., click "In Draft" → grid filters to Reply Status = Draft).

**Grid Columns** (in display order):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Approved | `prayer.moderatedAt` | date | 110px | YES | When parent prayer hit Approved status |
| 2 | Source | `prayer.receivedSource` | channel chip | 100px | YES | WEB/IFRAME/WALK_IN/PHONE_IN icon + label |
| 3 | Submitter | composite `prayer.submitterFirstName + " " + prayer.submitterLastName` OR "Anonymous" if `prayer.isAnonymous=true` | text | 200px | YES | Anonymous prayers show "Anonymous" label, not actual name |
| 4 | Category | `prayer.categoryCode` resolved via MasterData (emoji + name) | text + emoji | 140px | YES | e.g., "💚 Healing" |
| 5 | Title / Body excerpt | `prayer.title` OR first 80 chars of `prayer.body` | text | auto (flex) | NO | Body excerpt with ellipsis |
| 6 | Prayed | `prayer.prayedCount` | number badge | 80px | YES | Engagement count from #171 |
| 7 | **Reply Status** | derived: NONE / Draft / Submitted / Approved / Rejected / Sent / Failed | status badge | 130px | YES | NONE = no reply record exists; others = latest reply's status |
| 8 | Drafted By | `latestReply.draftedByContact.displayName` OR "—" | text | 150px | YES | Empty if no reply yet |
| 9 | Last Activity | latest of `latestReply.lastUpdatedAt ?? latestReply.draftedAt ?? prayer.moderatedAt` | relative time ("2 hours ago") | 120px | YES | Default sort key (DESC) |
| 10 | Actions | — | action buttons | 120px | NO | "Draft Reply" (if no reply) / "Continue Draft" (if Draft) / "View Reply" (if Submitted+) |

**Search/Filter Fields:**
- **Search**: prayer body / submitter name / title
- **Reply Status**: multi-select `NONE | Draft | SubmittedForReview | Approved | Rejected | Sent | Failed`
- **Channel**: multi-select `EMAIL | SMS | WHATSAPP | PHONE | LETTER | IN_PERSON | (no reply yet)`
- **Category**: multi-select PRAYERCATEGORY codes
- **Date range**: filter on `prayer.moderatedAt` (when Approved)
- **Mine only**: bool toggle (filters to `latestReply.draftedByContactId = current user`)

**Grid Actions** (per row, in the Actions column):
- If `replyStatus = NONE` → "Draft Reply" button → navigates to `?tab=replyqueue&mode=draft&prayerId={prayerId}`
- If `replyStatus = Draft` AND `draftedBy = current user` → "Continue Draft" button → `?tab=replyqueue&mode=edit&id={replyId}`
- If `replyStatus = Draft` AND `draftedBy ≠ current user` → "View Draft" link (read-only — caller doesn't own it)
- If `replyStatus ∈ {SubmittedForReview, Approved, Rejected, Sent, Failed}` → "View Reply" link → `?tab=replyqueue&mode=read&id={replyId}`

**Row Click**: same as primary action button (clicking the row triggers the most relevant action — Draft → Continue; SubmittedForReview → View; etc.)

**Empty State**: "No prayers awaiting reply yet. Once a moderator approves a prayer in the Entry tab, it lands here for your team to draft a reply."

**Sort Default**: `Last Activity DESC` (most recently touched / approved prayers float to top)

### Grid Aggregation Columns

> Per-row derived values from joined `latestReply` row.

| Column | Source | Implementation |
|--------|--------|----------------|
| Reply Status | latest reply's `Status` field; if no reply rows → "NONE" | LINQ subquery `.OrderByDescending(r => r.DraftedAt).Take(1)` filtered by tenant + prayer |
| Drafted By | latest reply's `DraftedByContact.DisplayName` | same subquery |
| Last Activity | latest reply's `LastUpdatedAt ?? DraftedAt ?? prayer.ModeratedAt` | derived in memory after join |

---

### LAYOUT 1: FORM (mode=draft & mode=edit)

> The form opens when user clicks "Draft Reply" (`?tab=replyqueue&mode=draft&prayerId=N`) or "Continue Draft" (`?tab=replyqueue&mode=edit&id=R`).
> Built with React Hook Form. Reads parent prayer once (server-side fetch via `GetPrayerRequestById`) to populate the read-only prayer-context card; then the rest of the form is the reply draft.

**Page Header**: `FlowFormPageHeader` with:
- Back button → returns to grid (`?tab=replyqueue`)
- "Save as Draft" button (primary — always visible)
- "Submit for Approval" button (secondary — disabled until body length ≥ 5 chars + channel selected; visible only when current Status = Draft or first-time draft)
- Unsaved changes dialog when form is dirty + user navigates

**Section Container**: 4 stacked cards (no accordion — short form)

**Form Sections** (in display order):

| # | Icon | Section Title | Layout | Collapse | Fields |
|---|------|--------------|--------|----------|--------|
| 1 | `ph:hands-praying` | **Original Prayer (read-only)** | full-width single-column | expanded | (read-only): SubmitterName, Category emoji+name, Title, Body, SubmittedAt, ReceivedSource chip, LinkedContact link |
| 2 | `ph:paper-plane-tilt` | **Reply Channel** | full-width single-column | expanded | ChannelCardSelector (6 cards) |
| 3 | `ph:envelope` (dynamic — matches selected channel) | **Reply Content** | full-width single-column | expanded | Subject (if EMAIL), RecipientOverride (if EMAIL/SMS/WHATSAPP), Body editor (full width, monospace-friendly, 12 lines tall) |
| 4 | `ph:note-pencil` | **Internal Note (optional)** | full-width single-column | collapsed by default | InternalNote textarea (placeholder: "Notes for the reviewer — e.g., 'checked verse ref against NIV'") |

**Field Widget Mapping**:

| Field | Section | Widget | Placeholder | Validation | Notes |
|-------|---------|--------|-------------|------------|-------|
| (read-only prayer fields) | 1 | display panel | — | — | Static, fed from `GetPrayerRequestById` |
| ReplyChannel | 2 | **card-selector** (6 cards) | — | required | Card layout 3×2 grid; clicking a card switches Section 3 fields |
| ReplySubject | 3 | text input | "Subject (e.g., 'A prayer for your family')" | required if EMAIL, max 200, hidden otherwise | Only visible for EMAIL |
| RecipientEmailOverride | 3 | email input (optional) | "Override — leave blank to use contact's primary email" | valid email, hidden if non-EMAIL | Optional |
| RecipientPhoneOverride | 3 | phone input (optional) | "Override — leave blank to use contact's primary phone" | E.164, hidden if non-SMS/non-WHATSAPP | Optional |
| ReplyBody | 3 | textarea (large — 12 rows) | "Write your reply here…" | required, min 5, max 8000 | Char counter bottom-right; monospace-friendly font |
| InternalNote | 4 | textarea (small — 3 rows) | "Notes for the reviewer (optional)" | max 1000 | Not part of outbound reply |

**Channel Card Selector** (Section 2):

| Card | Icon | Label | Subtitle | Triggers Sub-form |
|------|------|-------|----------|--------------------|
| EMAIL | `ph:envelope-simple` | **Email** | Send via email | Show Subject + RecipientEmailOverride |
| SMS | `ph:device-mobile` | **SMS** | Send via SMS | Show RecipientPhoneOverride |
| WHATSAPP | `ph:whatsapp-logo` | **WhatsApp** | Send via WhatsApp | Show RecipientPhoneOverride |
| PHONE | `ph:phone-call` | **Phone Callback** | Log a callback transcript | (no extras) |
| LETTER | `ph:envelope` | **Letter** | Print a postal letter | (no extras) |
| IN_PERSON | `ph:user` | **In-Person** | Log an in-person follow-up | (no extras) |

> Card visual: rounded border, hover ring, selected = filled bg + checkmark; 3×2 grid layout (3 cards per row on desktop, 2 per row on tablet, 1 per row on mobile).

**Inline Mini Display** — Prayer Context Card (Section 1):

| Widget | Content |
|--------|---------|
| Submitter | Avatar (initials if no photo) + Name (or "Anonymous") + Country flag (if known) |
| Category Badge | Emoji + name + color cue from PRAYERCATEGORY MasterData (e.g., "💚 Healing", "🙏 Thanksgiving") |
| Source Chip | Channel icon + label (e.g., "Phone Intake" if PHONE_IN) |
| Body | Full prayer body in a quoted block (italic, monospace, max-height 200px scroll) |
| Title | If present, shown as bold above body; hidden if null |
| LinkedContact link | If `linkedContactId` set → "View Contact Profile" link → opens Contact page in new tab |
| SubmittedAt | "Received 3 days ago" relative time |

**Page Footer / Action Bar** (sticky at form bottom):
- LEFT: "Cancel" link → goes back to grid (unsaved-changes confirm if dirty)
- RIGHT: "Save as Draft" (filled primary, always enabled when form is valid) | "Submit for Approval" (outline, enabled when body ≥ 5 chars AND channel selected)
- Char counter: "{bodyLength} / 8000"

---

### LAYOUT 2: DETAIL (mode=read) — DIFFERENT UI from the form

> The read-only detail page shown when the user clicks "View Reply" from the grid (`?tab=replyqueue&mode=read&id=R`).
> Multi-column read-only view with status-action bar. NOT the form in disabled state.

**Page Header**: `FlowFormPageHeader` with:
- Back button → returns to grid (`?tab=replyqueue`)
- Status badge inline with title (e.g., "Reply — SubmittedForReview" with amber badge)
- Header actions (conditional by Status + ownership):
  - **Draft + ownedByCurrentUser**: "Edit" (→ `?tab=replyqueue&mode=edit&id=R`) + "Submit for Approval" + "Delete Draft" (overflow menu)
  - **Draft + NOT ownedByCurrentUser**: "Edit" hidden; read-only view
  - **SubmittedForReview + ownedByCurrentUser**: "Recall to Draft" button (replaces Edit)
  - **SubmittedForReview + NOT ownedByCurrentUser**: read-only — message "Awaiting supervisor review"
  - **Approved**: read-only — message "Approved by {ReviewerName} on {ReviewedAt} — pending send"
  - **Rejected**: "Revise" button → recall + reopen edit (if drafter owns); show ReviewerNote prominently
  - **Sent**: read-only — message "Sent at {SentAt} via {ReplyChannel}"
  - **Failed**: read-only — message "Failed at {SentAt} — please contact support" (Send-Service is future scope)

**Page Layout**:

| Column | Width | Cards / Sections |
|--------|-------|-----------------|
| Left | 2fr | Card 1: Prayer Context (mini, read-only) · Card 2: Reply Content (the body, formatted) |
| Right | 1fr | Card 3: Status + Audit Trail (Drafted, LastUpdated, SubmittedForReview, Reviewed, Sent timestamps + people) · Card 4: ReviewerNote (only if non-null) |

**Left Column Cards**:

| # | Card Title | Content |
|---|-----------|---------|
| 1 | **Original Prayer** | Same content as FORM Section 1 (smaller, condensed — top 4 fields) |
| 2 | **Reply Content** | Channel icon + label header; Subject (if EMAIL); Recipient (resolved — override OR contact primary); Body (full, formatted with line breaks preserved); Internal Note (small, dimmed below body) |

**Right Column Cards**:

| # | Card Title | Content |
|---|-----------|---------|
| 1 | **Status & Audit Trail** | Timeline component: ● Drafted by {Name} {Date} → ● Last edited {Date} → ● Submitted for Review {Date} → ● Reviewed by {Name} {Date} → ● Sent {Date} (only rendered timestamps that are non-null) |
| 2 | **Reviewer Note** | Conditional — only if `ReviewerNote ≠ null`; renders as a callout box with reviewer's name, ReviewedAt, and note text. **Red-tinted if Status=Rejected, green-tinted if Status=Approved.** |

### Page Widgets & Summary Cards

> 3 KPI widgets (already defined above in Grid section).

**Summary GQL Query**:
- Query name: `GetReplyQueueSummary`
- Returns: `ReplyQueueSummaryDto` with fields `awaitingReplyCount`, `inDraftCount`, `submittedForReviewCount`, plus all-time totals.

---

### User Interaction Flow

1. User in workspace → clicks Tab 2 (Reply Queue) → URL `?tab=replyqueue` → grid loads with 3 KPI widgets above + table below
2. User scans grid → clicks "Draft Reply" on row N → URL `?tab=replyqueue&mode=draft&prayerId=N` → FORM loads (Prayer Context card pre-fills from GetPrayerRequestById; reply fields empty)
3. User picks Channel card (e.g., EMAIL) → Section 3 fields update to show Subject + RecipientEmailOverride
4. User types Body → "Save as Draft" enables → user clicks → POST `CreatePrayerRequestReply` → new ID returned → URL redirects to `?tab=replyqueue&mode=read&id={newId}` → DETAIL loads
5. From DETAIL: user clicks "Submit for Approval" → POST `SubmitPrayerRequestReplyForReview` → Status=SubmittedForReview → page refreshes; action bar swaps "Submit" → "Recall" button
6. User realizes mistake → clicks "Recall to Draft" → POST `RecallPrayerRequestReply` → Status=Draft → action bar swaps back
7. User clicks "Edit" → URL `?tab=replyqueue&mode=edit&id=R` → FORM loads pre-filled → user edits Body → clicks "Save as Draft" → POST `UpdatePrayerRequestReply` → back to DETAIL
8. From grid: user clicks a row that's already `Approved` → DETAIL loads in read-only mode (action bar shows "Approved by {Name}; pending send")
9. From workspace: user switches Tab 1 → Tab 2 → URL `?tab=entry` → workspace dumps `mode/id/prayerId` params (per #136's tab-switch behavior) → user lands on Entry grid

---

### Index Strategy (EF migration)

3 composite indexes per query pattern:

| Index Name | Columns | Used By |
|------------|---------|---------|
| `IX_PrayerRequestReplies_CompanyId_PrayerRequestId_Status` | (CompanyId, PrayerRequestId, Status) | GetReplyQueueList — find latest reply per prayer |
| `IX_PrayerRequestReplies_CompanyId_Status_SubmittedForReviewAt` | (CompanyId, Status, SubmittedForReviewAt) | #138 supervisor queue (anticipated) — pre-build for forward-compat |
| `IX_PrayerRequestReplies_CompanyId_DraftedByContactId` | (CompanyId, DraftedByContactId) | "Mine only" filter; drafter activity reports |

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer
> Maps the canonical reference (SavedFilter FLOW) — adapted to TAB_CONTENT scope (Entry tab from #136 is the closer real-world precedent).

**Canonical Reference**: **SavedFilter (FLOW pattern)** + **PrayerRequestEntry (tab-content extension precedent from #136)**

| Canonical | → This Entity | Context |
|-----------|--------------|---------|
| SavedFilter | PrayerRequestReply | Entity/class name (NEW) |
| savedFilter | prayerRequestReply | Variable/field names |
| SavedFilterId | PrayerRequestReplyId | PK field |
| SavedFilters | PrayerRequestReplies | Table name, collection names |
| saved-filter | prayer-request-reply | FE route path / file names — BUT no top-level route is created (TAB_CONTENT) |
| savedfilter | prayerrequestreplyqueue | FE folder (under `prayerrequests/tabs/replyqueue/`) — NO `(core)/{group}/{...}` top-level entry |
| SAVEDFILTER | — | NO new menu code — the parent `PRAYERREQUESTS` menu is reused |
| notify | corg | DB schema |
| Notify | Contact | Backend group name (already exists — `ContactModels` / `ContactBusiness` / `ContactSchemas`) |
| ContactModels | ContactModels | Same group as parent — no change |
| NOTIFICATIONSETUP | — | NO ParentMenuCode (no new menu) |
| NOTIFICATION | CRM | Module code (already exists — Prayer Request submodule) |
| crm/communication/savedfilter | crm/prayerrequest/prayerrequests?tab=replyqueue | "FE route" is actually the workspace URL + tab query param |
| notify-service | contact-service | FE service folder (existing) |

> **TAB_CONTENT key difference vs. canonical SavedFilter FLOW**: NO top-level `(core)/{group}/{feFolder}/{entity-lower}/page.tsx` route file is created. The "page" is the workspace shell's tab content slot. The view-page lives at `presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/view-page.tsx` — NOT at `app/[lang]/...`. This is the same structural pattern Tab 1 (#136) used.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files (13 NEW + 4 modified)

| # | File | Path | NEW / Modified |
|---|------|------|---------------|
| 1 | Entity | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Domain/Models/ContactModels/PrayerRequestReply.cs` | **NEW** |
| 2 | EF Config | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Data/Configurations/ContactConfigurations/PrayerRequestReplyConfiguration.cs` | **NEW** |
| 3 | Schemas (DTOs) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Schemas/ContactSchemas/PrayerRequestReplySchemas.cs` | **NEW** (separate file — keeps the existing `PrayerRequestPageSchemas.cs` clean) |
| 4 | Constants | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Constants/ReplyChannelTypes.cs` | **NEW** (mirror of `ReceivedSourceTypes` pattern) |
| 5 | Create Command | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/PrayerRequestReplies/CreateCommand/CreatePrayerRequestReply.cs` | **NEW** |
| 6 | Update Command | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/PrayerRequestReplies/UpdateCommand/UpdatePrayerRequestReply.cs` | **NEW** |
| 7 | Submit Command | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/PrayerRequestReplies/SubmitCommand/SubmitPrayerRequestReplyForReview.cs` | **NEW** (workflow handler) |
| 8 | Recall Command | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/PrayerRequestReplies/RecallCommand/RecallPrayerRequestReply.cs` | **NEW** (workflow handler) |
| 9 | Delete Command (soft) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/PrayerRequestReplies/DeleteCommand/DeletePrayerRequestReply.cs` | **NEW** (sets IsActive=false) |
| 10 | GetAll Query (list) | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/PrayerRequestReplies/GetAllQuery/GetReplyQueueList.cs` | **NEW** (composite join: PrayerRequest + latest PrayerRequestReply) |
| 11 | GetById Query | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/PrayerRequestReplies/GetByIdQuery/GetPrayerRequestReplyById.cs` | **NEW** |
| 12 | Summary Query | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/PrayerRequestReplies/GetSummaryQuery/GetReplyQueueSummary.cs` | **NEW** (3 KPI counts) |
| 13 | Mutations Endpoint | `Pss2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Contact/Mutations/PrayerRequestReplyMutations.cs` | **NEW** (HotChocolate `[ExtendObjectType]`) |
| 14 | Queries Endpoint | `Pss2.0_Backend/PeopleServe/Services/Base/Base.API/EndPoints/Contact/Queries/PrayerRequestReplyQueries.cs` | **NEW** |
| 15 | EF Migration | `Pss2.0_Backend/PeopleServe/Services/Base/Base.Infrastructure/Migrations/{TIMESTAMP}_Add_PrayerRequestReplies_Table.cs` | **NEW** (regenerate Designer.cs + snapshot via `--force` per ISSUE-6 pattern) |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Pss2.0_Backend/.../Base.Application/Interfaces/IApplicationDbContext.cs` | `DbSet<PrayerRequestReply> PrayerRequestReplies { get; set; }` |
| 2 | `Pss2.0_Backend/.../Base.Application/Extensions/DecoratorProperties.cs` (class `DecoratorContactModules`) | `, PrayerRequestReply = "PRAYERREQUESTREPLY"` (after the existing 3 PrayerRequest entries) |
| 3 | `Pss2.0_Backend/.../Base.Application/Mappings/ContactMappings.cs` | Mapster config for `PrayerRequestReply` ↔ `PrayerRequestReplyRequestDto/ResponseDto` |
| 4 | `Pss2.0_Backend/.../Base.Domain/Models/ContactModels/PrayerRequest.cs` (EXISTING — alter only) | Add nav collection: `public virtual ICollection<PrayerRequestReply>? PrayerRequestReplies { get; set; }` |

### Frontend Files (9 NEW)

| # | File | Path | NEW / Modified |
|---|------|------|---------------|
| 1 | DTO Types | `Pss2.0_Frontend/src/domain/entities/contact-service/PrayerRequestReplyDto.ts` | **NEW** |
| 2 | GQL Query | `Pss2.0_Frontend/src/infrastructure/gql-queries/contact-queries/PrayerRequestReplyQuery.ts` | **NEW** (`GET_REPLY_QUEUE_LIST`, `GET_PRAYER_REQUEST_REPLY_BY_ID`, `GET_REPLY_QUEUE_SUMMARY`) |
| 3 | GQL Mutation | `Pss2.0_Frontend/src/infrastructure/gql-mutations/contact-mutations/PrayerRequestReplyMutation.ts` | **NEW** (`CREATE_PRAYER_REQUEST_REPLY`, `UPDATE_PRAYER_REQUEST_REPLY`, `SUBMIT_REPLY_FOR_REVIEW`, `RECALL_REPLY`, `DELETE_REPLY`) |
| 4 | Tab content barrel | `Pss2.0_Frontend/src/presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/index.tsx` | **NEW** (default export `ReplyQueueTabContent`) |
| 5 | Tab index-page (grid mode) | `Pss2.0_Frontend/src/presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/index-page.tsx` | **NEW** (Reply Queue grid + 3 KPI widgets) |
| 6 | Tab view-page (form + detail) | `Pss2.0_Frontend/src/presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/view-page.tsx` | **NEW** (~700-800 LoC; 3 modes; channel selector; RHF) |
| 7 | Tab Zustand store | `Pss2.0_Frontend/src/presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/reply-queue-store.ts` | **NEW** |
| 8 | Tab Page (presentation pages registration) | `Pss2.0_Frontend/src/presentation/pages/contact-service/prayerrequests/reply-queue-tab.tsx` | **NEW** (re-exports the tab barrel for the workspace) |
| 9 | Tab folder barrel | `Pss2.0_Frontend/src/presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/index.ts` | **NEW** (barrel re-export — may be merged with item 4) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Pss2.0_Frontend/src/presentation/components/page-components/contact-service/prayerrequests/prayerrequests-workspace.tsx` | Import `ReplyQueueTabContent`; replace `<TabComingSoon label="Reply Queue" releaseTarget="#137" />` at line ~216 with `<ReplyQueueTabContent />` |
| 2 | `Pss2.0_Frontend/src/application/configs/data-table-configs/contact-service-entity-operations.ts` | Add new registry block with `gridCode: "PRAYERREQUEST_REPLYQUEUE"` mapping the 5 reply CRUD operations |
| 3 | `Pss2.0_Frontend/src/presentation/hooks/useInitialRendering/useCapability.tsx` | Surface `canReplyDraft` and `canReplyApprove` as named flags on the returned capabilities object (ISSUE-8 closure) — keys derived from capability codes `REPLY_DRAFT` / `REPLY_APPROVE` |
| 4 | `Pss2.0_Frontend/src/domain/entities/contact-service/index.ts` (barrel) | Export `PrayerRequestReplyDto` types |
| 5 | `Pss2.0_Frontend/src/infrastructure/gql-queries/contact-queries/index.ts` (barrel) | Export new `Queries` |
| 6 | `Pss2.0_Frontend/src/infrastructure/gql-mutations/contact-mutations/index.ts` (barrel) | Export new `Mutations` |

### DB Seed

| # | File | Notes |
|---|------|-------|
| 1 | `Pss2.0_Backend/.../sql-scripts-dyanmic/PrayerRequestReplies-sqlscripts.sql` | **NEW** — idempotent; inserts 2 sample reply rows for E2E QA (1 Draft, 1 SubmittedForReview); references existing seeded `PrayerRequests.PrayerRequestId` via subquery. NO menu/capability/role-capability inserts (already seeded by #136). |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.
> **TAB_CONTENT scope**: NO new menu, NO new capability, NO new role-capability INSERT. The CONFIG block below documents the existing parent + capability the tab content extends.

```
---CONFIG-START---
Scope: TAB_CONTENT (extends existing PRAYERREQUESTS menu — no new menu insert)
ExtendsMenu: PRAYERREQUESTS  (already seeded by #136 — MenuId resolved at runtime)
ParentMenu: CRM_PRAYERREQUEST
Module: CRM
WorkspaceTabKey: replyqueue
CapabilityGate: REPLY_DRAFT  (already seeded by #136 — granted to BUSINESSADMIN by default)

GridType: FLOW (within tab)
GridCode: PRAYERREQUEST_REPLYQUEUE  (used by entity-operations registry; NOT a menu code)
GridFormSchema: SKIP  (FLOW pattern — no RJSF schema needed)

DBSeedActions:
  - No Menu INSERT
  - No MenuCapability INSERT
  - No RoleCapability INSERT
  - 2 sample PrayerRequestReplies rows (1 Draft + 1 SubmittedForReview) for E2E QA
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types:**
- Query type: `PrayerRequestReplyQueries` (HotChocolate `[ExtendObjectType<Query>]`)
- Mutation type: `PrayerRequestReplyMutations` (`[ExtendObjectType<Mutation>]`)

**Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getReplyQueueList` | `GridFeatureResult<ReplyQueueRowDto>` | `request: GridFeatureRequest, prayerStatus: String! = "Approved", replyStatuses: [String!], channels: [String!], categoryCodes: [String!], dateFrom: DateTime, dateTo: DateTime, mineOnly: Boolean = false` |
| `getPrayerRequestReplyById` | `PrayerRequestReplyResponseDto` | `prayerRequestReplyId: Int!` |
| `getReplyQueueSummary` | `ReplyQueueSummaryDto` | (none — tenant from HttpContext) |

**Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `createPrayerRequestReply` | `CreatePrayerRequestReplyRequestDto` | `Int` (new ID) |
| `updatePrayerRequestReply` | `UpdatePrayerRequestReplyRequestDto` | `Int` (rows-affected count) |
| `submitPrayerRequestReplyForReview` | `prayerRequestReplyId: Int!` | `Int` |
| `recallPrayerRequestReply` | `prayerRequestReplyId: Int!` | `Int` |
| `deletePrayerRequestReply` | `prayerRequestReplyId: Int!` | `Int` (soft-delete; sets IsActive=false) |

**Response DTO Fields** — `PrayerRequestReplyResponseDto`:

| Field | Type | Notes |
|-------|------|-------|
| prayerRequestReplyId | number | PK |
| companyId | number | tenant scope (echoed for FE display) |
| prayerRequestId | number | parent FK |
| replyChannel | string | EMAIL / SMS / ... |
| replySubject | string\|null | only for EMAIL |
| replyBody | string | required, HTML-stripped |
| status | string | Draft / SubmittedForReview / ... |
| internalNote | string\|null | drafter → reviewer |
| draftedByContactId | number | FK |
| draftedByContactName | string | resolved via .Include() |
| draftedAt | string (ISO) | server-stamped |
| lastUpdatedByContactId | number\|null | FK |
| lastUpdatedByContactName | string\|null | resolved |
| lastUpdatedAt | string (ISO)\|null | server-stamped |
| submittedForReviewAt | string (ISO)\|null | server-stamped on Submit |
| reviewedByContactId | number\|null | FK (set by #138) |
| reviewedByContactName | string\|null | resolved (set by #138) |
| reviewedAt | string (ISO)\|null | set by #138 |
| reviewerNote | string\|null | set by #138 |
| sentAt | string (ISO)\|null | future — SERVICE_PLACEHOLDER |
| deliveryRefId | string\|null | future — SERVICE_PLACEHOLDER |
| recipientEmailOverride | string\|null | only for EMAIL |
| recipientPhoneOverride | string\|null | only for SMS/WHATSAPP |
| isActive | boolean | inherited |
| **prayer** | nested `PrayerRequestEntryResponseDto` | parent prayer fields, resolved via .Include() — read-only context |

**Response DTO Fields** — `ReplyQueueRowDto` (grid row — denormalized for UI):

| Field | Type | Source |
|-------|------|--------|
| prayerRequestId | number | parent FK (NOT prayerRequestReplyId — the row is anchored on the prayer) |
| prayerSubmitterName | string | composite from parent |
| prayerCategoryCode | string | parent |
| prayerCategoryName | string | resolved via MasterData |
| prayerCategoryEmoji | string | resolved via MasterData |
| prayerTitle | string\|null | parent |
| prayerBodyExcerpt | string | first 80 chars of parent.body |
| prayerReceivedSource | string | parent |
| prayerSubmittedAt | string (ISO) | parent |
| prayerModeratedAt | string (ISO) | parent (when Approved hit) |
| prayerPrayedCount | number | parent |
| prayerIsAnonymous | boolean | parent |
| latestReplyId | number\|null | derived (null if no reply yet) |
| latestReplyStatus | string | "NONE" or one of Draft/.../Failed |
| latestReplyChannel | string\|null | derived |
| latestReplyDraftedByContactId | number\|null | derived |
| latestReplyDraftedByContactName | string\|null | derived |
| latestReplyDraftedAt | string (ISO)\|null | derived |
| latestReplyLastActivityAt | string (ISO) | latest of lastUpdatedAt/draftedAt/parent.moderatedAt — used for default sort |

**Response DTO Fields** — `ReplyQueueSummaryDto`:

| Field | Type | Description |
|-------|------|-------------|
| awaitingReplyCount | number | Approved prayers with NO reply (last 30 days) |
| awaitingReplyCountAllTime | number | same but all-time |
| inDraftCount | number | Status=Draft (mine if non-admin; all if admin — server enforces) |
| inDraftCountAllTime | number | same all-time |
| submittedForReviewCount | number | Status=SubmittedForReview |
| submittedForReviewCountAllTime | number | all-time |

**Request DTO Fields** — `CreatePrayerRequestReplyRequestDto`:

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| prayerRequestId | number | YES | parent — validated server-side (Status=Approved + same Company) |
| replyChannel | string | YES | enum-validated |
| replySubject | string\|null | conditional (EMAIL) | server-rejects if non-EMAIL |
| replyBody | string | YES | server HTML-strips + length 5-8000 |
| internalNote | string\|null | NO | max 1000 |
| recipientEmailOverride | string\|null | NO | EMAIL only |
| recipientPhoneOverride | string\|null | NO | SMS/WHATSAPP only |

> CompanyId, DraftedByContactId, DraftedAt are SERVER-STAMPED — must NOT be in the request DTO (HotChocolate will reject if added).

**Request DTO Fields** — `UpdatePrayerRequestReplyRequestDto`:

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| prayerRequestReplyId | number | YES | PK |
| replyChannel | string | YES | (caller may switch channel only while Status=Draft) |
| replySubject | string\|null | conditional | per channel rules |
| replyBody | string | YES | per Create rules |
| internalNote | string\|null | NO | — |
| recipientEmailOverride | string\|null | NO | — |
| recipientPhoneOverride | string\|null | NO | — |

> `prayerRequestId`, `companyId`, `draftedByContactId`, `draftedAt`, `status` are NOT updatable — server ignores if present in the request body.

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] EF migration applies cleanly (new table — no risk to existing rows)
- [ ] `pnpm dev` — workspace loads at `/{lang}/crm/prayerrequest/prayerrequests`

**Functional Verification (Full E2E — MANDATORY):**

*Grid (Tab 2 active):*
- [ ] Tab 2 chip "Reply Queue" is enabled when user has REPLY_DRAFT capability (verified via real flag, not soft fallback)
- [ ] Clicking Tab 2 → URL `?tab=replyqueue` → grid loads
- [ ] 3 KPI widgets render with correct counts from seed data
- [ ] Grid columns render in correct order with correct widths
- [ ] Search by submitter name / title / body excerpt filters correctly
- [ ] Reply Status multi-select filter works (test: select "Draft" → only Draft rows show)
- [ ] Channel multi-select filter works
- [ ] Category multi-select filter works (loads PRAYERCATEGORY codes)
- [ ] Date range filter on `prayer.moderatedAt` works
- [ ] "Mine only" toggle filters to current user's drafts/submissions only
- [ ] Default sort is `Last Activity DESC`; clicking other column headers re-sorts
- [ ] Action column shows the right primary action per row Status

*FORM mode (mode=draft for new):*
- [ ] Click "Draft Reply" on a row → URL `?tab=replyqueue&mode=draft&prayerId=N`
- [ ] Section 1 (Prayer Context) renders read-only with all 7 fields
- [ ] Section 2 (Channel selector) shows 6 cards in 3×2 grid (3 on desktop, 2 on tablet, 1 on mobile)
- [ ] Selecting EMAIL card → Section 3 shows Subject + RecipientEmailOverride
- [ ] Selecting SMS card → Section 3 shows RecipientPhoneOverride (no Subject)
- [ ] Selecting WHATSAPP card → Section 3 shows RecipientPhoneOverride
- [ ] Selecting PHONE / LETTER / IN_PERSON → Section 3 hides all override fields
- [ ] Body textarea has char counter; turns amber at 7500/8000; red at 8000
- [ ] "Save as Draft" enabled only when Body >= 5 chars AND Channel selected
- [ ] "Submit for Approval" same enable condition + visible only on Draft mode
- [ ] Save as Draft → POST mutation → URL redirects to `?tab=replyqueue&mode=read&id={newId}`
- [ ] If user navigates away with dirty form → unsaved-changes dialog fires

*FORM mode (mode=edit for existing Draft):*
- [ ] Click "Continue Draft" on a row → URL `?tab=replyqueue&mode=edit&id=R`
- [ ] All sections pre-fill from existing row
- [ ] Save as Draft → POST `updatePrayerRequestReply` → URL redirects back to DETAIL
- [ ] Editing a SubmittedForReview reply is BLOCKED (server returns 422) — FE shows toast and disables Save

*DETAIL mode (mode=read):*
- [ ] Click "View Reply" on a row → URL `?tab=replyqueue&mode=read&id=R`
- [ ] Left column shows Prayer Context (condensed) + Reply Content (full)
- [ ] Right column shows Status & Audit Trail timeline + (conditional) ReviewerNote
- [ ] Header action bar varies by Status + ownership:
  - Draft owned → "Edit" + "Submit for Approval" + overflow "Delete Draft"
  - Draft not-owned → "Edit" hidden
  - SubmittedForReview owned → "Recall to Draft"
  - SubmittedForReview not-owned → "Awaiting supervisor review" message
  - Approved → "Approved — pending send" message
  - Rejected → "Revise" button + red ReviewerNote callout
- [ ] Submit for Approval → POST → Status flips → action bar updates without page reload
- [ ] Recall → POST → Status flips back to Draft → action bar updates

*Workflow:*
- [ ] CreateReply for a non-Approved prayer → server rejects with validation error
- [ ] Second concurrent Draft from same drafter/channel/prayer → server rejects (soft-uniqueness rule)
- [ ] SubmitForReview when prayer's LinkedContactId is null + channel=EMAIL + no override → server rejects with "No recipient address on file"
- [ ] Recall by non-drafter → server rejects (403)
- [ ] Delete a SubmittedForReview reply → server rejects (only Draft can be deleted)

*Permissions:*
- [ ] User WITHOUT REPLY_DRAFT capability → Tab 2 chip is disabled with tooltip
- [ ] User WITHOUT REPLY_DRAFT but WITH REPLY_APPROVE → Tab 2 disabled; Tab 3 enabled (independent gates)
- [ ] Cross-tenant isolation: tenant A user cannot fetch tenant B's replies (server 403)

*UI Uniformity (post-build greps — should return ZERO matches in new FE files):*
- [ ] No inline hex colors
- [ ] No inline pixel padding/margins
- [ ] No raw "Loading..." text (use Skeleton)
- [ ] All useQuery surfaces have a Skeleton placeholder
- [ ] All sibling cards share same inner padding class

*DB Seed Verification:*
- [ ] 2 sample reply rows exist after seed runs (1 Draft, 1 SubmittedForReview)
- [ ] Sample rows reference existing seeded PrayerRequests (Status=Approved)
- [ ] Seed script is idempotent (re-running doesn't duplicate)

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **TAB_CONTENT scope** — this is NOT a standalone screen. NO new menu, NO new route, NO new `(core)/...` page.tsx. Files live under `presentation/components/page-components/.../prayerrequests/tabs/replyqueue/`.
- **Workspace shell modification is REQUIRED** — `prayerrequests-workspace.tsx` line ~216 currently renders `<TabComingSoon label="Reply Queue" releaseTarget="#137" />`; this line MUST change to `<ReplyQueueTabContent />` (import added). Failing to do this means the user clicks Tab 2 and still sees the placeholder.
- **useAccessCapability extension is REQUIRED (ISSUE-8 closure)** — `useCapability.tsx` currently only surfaces canRead/canCreate/canUpdate/canDelete/canExport/canImport. Extend it to surface `canReplyDraft` (from capability code `REPLY_DRAFT`) and `canReplyApprove` (from `REPLY_APPROVE`). The workspace shell currently soft-falls-back to `canRead` for tabs 2/3 — once the named flags exist, the shell's lines 62-63 can use them directly.
- **CompanyId is NOT a field on the request DTO** — server-stamped. NEVER put it in `CreatePrayerRequestReplyRequestDto` (HotChocolate will reject; or worse, allow a tenant-mismatch attack).
- **DraftedByContactId is NOT a field on the request DTO** — server-stamped from HttpContext.User.ContactId. Same rationale.
- **Status is NOT updatable via UpdateReply** — only via Submit/Recall transitions (which have their own dedicated mutations).
- **EF Designer/snapshot regen** — same caveat as #136 ISSUE-6: after the migration file is hand-crafted, user must run `dotnet ef migrations add Add_PrayerRequestReplies_Table --force` to regenerate Designer.cs + snapshot. **Pre-flag this in the build output so the user can run it before `dotnet ef database update`.**
- **The "latest reply per prayer" subquery in GetReplyQueueList** can be expensive if not properly indexed. Use the new `IX_PrayerRequestReplies_CompanyId_PrayerRequestId_Status` index. Use a `.GroupBy + .OrderByDescending + .FirstOrDefault` pattern inside a SubQuery `Select` to fetch the latest reply per prayer in one round-trip. Avoid N+1.
- **The "prayer must be Status=Approved" validator** runs server-side on Create — the FE shouldn't pre-filter the grid to ONLY Approved prayers (we want to surface ALL approved AND any prayers with at least one existing reply, so the user can find their draft even if the prayer was later re-flagged). The grid's filter combines: `prayer.Status=Approved` OR `prayer.HasAtLeastOneReply` (left outer join).
- **Channel-specific validation must be enforced on BOTH client and server** — RHF + Zod schema mirrors the server validator. Don't trust the client.
- **Profanity/safety filter** — if #171 has an active `HtmlSanitizer` + profanity service on Body, reuse it. Don't re-implement.
- **Multi-reply per prayer is intentional** — drafters may compose a SECOND reply (different channel) for the same prayer. The "Reply Status" grid column shows the LATEST reply's status. The DETAIL page of a specific reply does NOT navigate "next/prev replies for same prayer" — that's a future enhancement.

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ **SERVICE_PLACEHOLDER: actual reply send (Email/SMS/WhatsApp transport)** — this build does NOT implement the outbound send. After supervisor Approval (in #138), the reply sits in `Status=Approved` indefinitely until a future Send-Service is built. The DETAIL view shows "Approved — pending send" for these rows. The action bar on Approved rows does NOT have a "Send Now" button (we don't want to bake in UI for a service that doesn't exist yet). **Future scope.**
- ⚠ **SERVICE_PLACEHOLDER: notification to supervisor on Submit** — when a drafter clicks "Submit for Approval", we do NOT email/notify the supervisor. The supervisor will discover it on next visit to Tab 3 (#138). Future scope: integrate with the in-app notification bell + email digest.
- ⚠ **SERVICE_PLACEHOLDER: profanity filter** — reuse if available; if not, no-op pass-through with a TODO comment.
- ⚠ **SERVICE_PLACEHOLDER: PDF letter generation (LETTER channel)** — the LETTER channel is captured but no print-ready PDF is generated in this build. UI shows a placeholder note: "Letter will be generated and queued for postal mail by your operations team — channel will be available when print integration ships."
- **Full UI is built** — all 6 channel cards, all conditional sub-fields, all status badges, all action buttons. Only the genuine external-service calls (transport, notification, PDF) are deferred.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Planning (#137 plan, 2026-05-12) | Low | Spec | No HTML mockup; spec authored from PSS 2.0 pastoral-care domain knowledge — UX Architect agent may refine visual treatment without changing semantics | OPEN (intentional — same approach as #136) |
| ISSUE-5 (from #136) | Inherited from #136 | Medium | Wiring | Workspace shell must register Tab 2 content (swap `<TabComingSoon>` for `<ReplyQueueTabContent />`) | CLOSED (Session 1 — `prayerrequests-workspace.tsx:222` renders `<ReplyQueueTabContent />`) |
| ISSUE-8 (from #136) | Inherited from #136 | Low | Hook | `useAccessCapability` must surface `canReplyDraft` as a named flag (currently soft-falls-back to canRead) | CLOSED (Session 1 — `useCapability.ts:159-160` surfaces `canReplyDraft` + `canReplyApprove`; workspace shell tab definitions consume them) |
| ISSUE-6-bis | Anticipated (planning) | Medium | EF | New table migration — Designer.cs + snapshot regen via `dotnet ef migrations add ... --force` required (same caveat as #136 ISSUE-6) | OPEN (user must run `dotnet ef migrations add Add_PrayerRequestReplies_Table --force` before `dotnet ef database update`) |
| ISSUE-9 | BA validation (Session 1) | Low | Edge case | Channel switch on UpdateReply nullifies channel-incompatible fields server-side instead of rejecting — graceful UX choice. Documented in Update handler. | RESOLVED-BY-DESIGN |
| ISSUE-10 | BA validation (Session 1) | Low | Edge case | Submit handler hard-rejects EMAIL/SMS/WHATSAPP with no resolvable recipient (no LinkedContact + no override). Drafter must add recipient before submit. | RESOLVED-BY-DESIGN |
| ISSUE-11 | BA validation (Session 1) | Low | Display | DraftedBy/LastUpdatedBy/ReviewedBy contact display falls back to `"(deactivated staff)"` if `Contact.IsActive=false`. Implemented in GetById + GetReplyQueueList. | RESOLVED-BY-DESIGN |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-12 — BUILD — COMPLETED

- **Scope**: Initial full build from PROMPT_READY prompt. Pipeline: BA (Sonnet) → Solution Resolver (Sonnet) → UX Architect (Opus) → user approval → Backend Developer (Sonnet) + Frontend Developer (Opus) → spot-verify wiring.
- **Files touched**:
  - BE (16 created):
    - `Base.Domain/Models/ContactModels/PrayerRequestReply.cs` (created)
    - `Base.Infrastructure/Data/Configurations/ContactConfigurations/PrayerRequestReplyConfiguration.cs` (created — includes unique partial index on (CompanyId, PrayerRequestId, DraftedByContactId, ReplyChannel) WHERE Status='Draft' AND IsActive=true; PostgreSQL dialect)
    - `Base.Application/Schemas/ContactSchemas/PrayerRequestReplySchemas.cs` (created — 5 DTOs: Create/Update request, full Response, ReplyQueueRow, ReplyQueueSummary)
    - `Base.Application/Constants/ReplyChannelTypes.cs` (created — mirror of ReceivedSourceTypes with All HashSet + RequiresSubject/AllowsEmailOverride/AllowsPhoneOverride sub-sets + IsValid)
    - `Base.Application/Business/ContactBusiness/PrayerRequestReplies/CreateCommand/CreatePrayerRequestReply.cs` (created — server-stamps CompanyId/DraftedBy/DraftedAt/Status=Draft; validates parent prayer Status=Approved + same tenant; enforces soft-uniqueness AnyAsync guard; HTML-strips body)
    - `Base.Application/Business/ContactBusiness/PrayerRequestReplies/UpdateCommand/UpdatePrayerRequestReply.cs` (created — Status=Draft guard; channel-incompatible field nullification; stamps LastUpdatedBy/LastUpdatedAt)
    - `Base.Application/Business/ContactBusiness/PrayerRequestReplies/SubmitCommand/SubmitPrayerRequestReplyForReview.cs` (created — re-validates parent prayer Status=Approved at submit-time; hard-rejects EMAIL/SMS/WHATSAPP with no resolvable recipient)
    - `Base.Application/Business/ContactBusiness/PrayerRequestReplies/RecallCommand/RecallPrayerRequestReply.cs` (created — strict DraftedByContactId-only ownership; no MODIFY-cap bypass per §④ matrix)
    - `Base.Application/Business/ContactBusiness/PrayerRequestReplies/DeleteCommand/DeletePrayerRequestReply.cs` (created — soft-delete; Draft-only)
    - `Base.Application/Business/ContactBusiness/PrayerRequestReplies/GetAllQuery/GetReplyQueueList.cs` (created — single Include + correlated subquery for latest-reply-per-prayer; tiebreaker on PrayerRequestReplyId DESC; batched MasterData PRAYERCATEGORY lookup; mine-only filter; LastActivityAt DESC sort)
    - `Base.Application/Business/ContactBusiness/PrayerRequestReplies/GetByIdQuery/GetPrayerRequestReplyById.cs` (created — full Include graph; null-safe "(deactivated staff)" fallback)
    - `Base.Application/Business/ContactBusiness/PrayerRequestReplies/GetSummaryQuery/GetReplyQueueSummary.cs` (created — 6 counts: 3 last-30-day + 3 all-time)
    - `Base.API/EndPoints/Contact/Mutations/PrayerRequestReplyMutations.cs` (created — `[ExtendObjectType<Mutation>]` with 5 mutations)
    - `Base.API/EndPoints/Contact/Queries/PrayerRequestReplyQueries.cs` (created — `[ExtendObjectType<Query>]` with 3 queries; uses ApiResponseHelper + PaginatedApiResponse)
    - `Base.Infrastructure/Migrations/20260512100000_Add_PrayerRequestReplies_Table.cs` (created — hand-crafted Up/Down; 3 composite indexes + 1 PostgreSQL unique partial index via raw SQL; Designer.cs + snapshot NOT regenerated — ISSUE-6-bis remains OPEN)
    - `Base.Infrastructure/sql-scripts-dyanmic/PrayerRequestReplies-sqlscripts.sql` (created — idempotent PostgreSQL DO block; 2 sample rows: 1 Draft EMAIL + 1 SubmittedForReview SMS; NO menu/cap inserts)
  - BE (5 modified):
    - `Base.Application/Data/Persistence/IContactDbContext.cs` (modified — added `DbSet<PrayerRequestReply> PrayerRequestReplies { get; }`)
    - `Base.Infrastructure/Data/Persistence/ContactDbContext.cs` (modified — added pass-through DbSet)
    - `Base.Application/Extensions/DecoratorProperties.cs` (modified — appended `PrayerRequestReply = "PRAYERREQUESTREPLY"` to `DecoratorContactModules`)
    - `Base.Application/Mappings/ContactMappings.cs` (modified — Mapster config for Create/Response/ReplyQueueRow with null-safe display name mapping)
    - `Base.Domain/Models/ContactModels/PrayerRequest.cs` (modified — added `public virtual ICollection<PrayerRequestReply>? PrayerRequestReplies { get; set; }` nav collection)
  - FE (10 created):
    - `src/domain/entities/contact-service/PrayerRequestReplyDto.ts` (created — 214 LoC; 5 DTOs + ReplyChannel/ReplyStatus/ReplyStatusOrNone literal unions)
    - `src/infrastructure/gql-queries/contact-queries/PrayerRequestReplyQuery.ts` (created — 3 named exports; `[String!]` non-null-element list args per HC nullability memory)
    - `src/infrastructure/gql-mutations/contact-mutations/PrayerRequestReplyMutation.ts` (created — 5 mutations)
    - `src/presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/index.tsx` (created — `ReplyQueueTabContent` dispatcher reading mode/prayerId/id from useSearchParams)
    - `src/presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/index-page.tsx` (created — 7178 bytes; 3 KPI widgets via `<SummaryCard>` + `<FlowDataTable gridCode="PRAYERREQUEST_REPLYQUEUE" showHeader={false}>` + Mine-only Switch)
    - `src/presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/view-page.tsx` (created — 59KB / ~1510 LoC; FORM + DETAIL modes; co-located ChannelCardSelector with roving tabindex + arrow nav; AuditTimeline; ReviewerNoteCallout; PrayerContextCard; BodyCharCounter with amber@7500 red@8000; Zod schema mirroring server channel-conditional rules via .superRefine; sticky action bar; unsaved-changes dialog; router.replace on save-success)
    - `src/presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/reply-queue-store.ts` (created — Zustand: mineOnly + pendingFilters)
    - `src/presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/reply-status-badge.tsx` (created — single-source palette map; `<ReplyStatusBadge>` + `<ReplyStatusDot>` + `<TimelineDot>` with role="status" + verbose aria-label)
    - `src/presentation/pages/contact-service/prayerrequests/reply-queue-tab.tsx` (created — re-export barrel for workspace shell)
    - `src/presentation/components/custom-components/summary-card/index.tsx` (created — LIFTED from `tabs/entry/index-page.tsx:31-61` per UX Architect rule-of-two; same prop shape)
  - FE (7 modified):
    - `src/presentation/components/page-components/contact-service/prayerrequests/prayerrequests-workspace.tsx` (modified — line 19 import `ReplyQueueTabContent`; line 222 renders `<ReplyQueueTabContent />` replacing TabComingSoon; lines 116-120 tab-switch handler now deletes `mode`/`id`/`prayerId`; line 43 Tab 2 chip uses `canReplyDraft`; Tab 3 uses `canReplyApprove`)
    - `src/application/configs/data-table-configs/contact-service-entity-operations.ts` (modified — added `PRAYERREQUEST_REPLYQUEUE` block at lines 869-902 mapping 5 mutations + 2 queries)
    - `src/presentation/hooks/useInitialRendering/useCapability.ts` (modified — `.ts` not `.tsx`; added REPLY_DRAFT + REPLY_APPROVE in capabilityFlags map at lines 113-114; surfaced as `canReplyDraft` + `canReplyApprove` named flags at lines 159-160; closes ISSUE-8)
    - `src/domain/entities/contact-service/index.ts` (modified — line 40 exports `PrayerRequestReplyDto`)
    - `src/infrastructure/gql-queries/contact-queries/index.ts` (modified — line 41 exports `PrayerRequestReplyQuery`)
    - `src/infrastructure/gql-mutations/contact-mutations/index.ts` (modified — line 43 exports `PrayerRequestReplyMutation`)
    - `src/presentation/components/page-components/contact-service/prayerrequests/tabs/entry/index-page.tsx` (modified — line 7 imports `SummaryCard` from `custom-components/summary-card`; inline definition removed)
  - DB: `Base.Infrastructure/sql-scripts-dyanmic/PrayerRequestReplies-sqlscripts.sql` (created — see BE list above)
- **Deviations from spec**: None. All UX Architect blueprint decisions honored (channel card roving tabindex + arrow nav; framer-motion conditional sub-form; Zod channel-conditional superRefine; `router.replace` on save-success; `prayerId` cleanup in tab-switch; SummaryCard rule-of-two lift; Variant B header pattern; 8-case action matrix). BA edge cases folded into BE handlers (parent re-validation in Submit; channel-incompatible field nullification in Update; null-safe display name fallback for deactivated staff; latest-reply tiebreaker on PK DESC).
- **Known issues opened**: ISSUE-9, ISSUE-10, ISSUE-11 (all RESOLVED-BY-DESIGN — see § Known Issues table).
- **Known issues closed**: ISSUE-5 (from #136 — workspace tab content registration), ISSUE-8 (from #136 — useCapability named-flag surface).
- **Next step**: User actions: (1) `dotnet ef migrations add Add_PrayerRequestReplies_Table --force` to regen Designer + snapshot (closes ISSUE-6-bis); (2) `dotnet ef database update` to apply migration; (3) Execute `PrayerRequestReplies-sqlscripts.sql` to seed 2 sample rows; (4) `pnpm dev` and E2E test per §⑪ acceptance criteria (workspace → Tab 2 → grid → 3 KPI widgets → draft → channel selector → save → submit → recall → edit → detail). Frontend typecheck/runtime validation deferred to user per session direction.

### Session 2 — 2026-05-12 — FIX — COMPLETED

- **Scope**: Tab 2 GraphQL field mismatches reported by user — `GetReplyQueueSummary` selected 3 fields with wrong names on `ReplyQueueSummaryDto`, and `GetReplyQueueList` selected 4 fields missing from `ReplyQueueRowDto`. Renamed FE side for existing-but-renamed fields (lowest-risk); added 4 new server-computed properties on BE for genuinely missing fields per user direction.
- **Files touched**:
  - BE (2 modified):
    - `Base.Application/Schemas/ContactSchemas/PrayerRequestReplySchemas.cs` — `ReplyQueueRowDto` (lines 150-189) now exposes `PrayerSubmitterName` (anonymous-aware concat), `PrayerBodyExcerpt` (server-truncated ~120 chars), `PrayerSubmittedAt` (from `PrayerRequest.SubmittedAt`, non-nullable), `LatestReplyDraftedAt` (from latest active reply's `DraftedAt`). 4 new properties, no breaking changes to existing fields.
    - `Base.Application/Business/ContactBusiness/PrayerRequestReplies/GetAllQuery/GetReplyQueueList.cs` — projection at lines 134-154 now computes + populates the 4 new fields; anonymous-aware concat: `IsAnonymous ? "Anonymous" : ($"{First} {Last}".Trim())` with null fallback; excerpt at `Body.Length > 120 ? Substring(0,120) + "…" : Body`.
  - FE (4 modified):
    - `src/infrastructure/gql-queries/contact-queries/PrayerRequestReplyQuery.ts` — `REPLY_QUEUE_ROW_FIELDS` renames `latestReplyStatus` → `replyStatus`, `latestReplyLastActivityAt` → `lastActivityAt`; `GET_REPLY_QUEUE_SUMMARY` renames `awaitingReplyCountAllTime` → `awaitingReplyAllTime`, `inDraftCountAllTime` → `inDraftAllTime`, `submittedForReviewCountAllTime` → `submittedForReviewAllTime`.
    - `src/domain/entities/contact-service/PrayerRequestReplyDto.ts` — `ReplyQueueRowDto` + `ReplyQueueSummaryDto` interfaces renamed accordingly; doc-comment refreshed.
    - `src/presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/index-page.tsx` — 3 SummaryCard subtitle expressions updated (`awaitingReplyCountAllTime` → `awaitingReplyAllTime` etc.).
    - `src/presentation/components/page-components/contact-service/prayerrequests/tabs/replyqueue/reply-status-badge.tsx` — comment reference `latestReplyStatus` → `replyStatus`.
- **Deviations from spec**: None. The 4 new BE fields keep the FE row-anchored DTO contract (FE asks for one stable field; server does the concat/truncate/source-attribute work).
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Validation results**:
  - `dotnet build` (Base.API): **0 errors, 466 warnings** (all pre-existing — none in `PrayerRequestReplySchemas.cs` or `GetReplyQueueList.cs`).
  - FE-side: replyqueue grid card columns + status badges unaffected by field renames (verified by grep — no remaining references to old names in the codebase).
- **Next step**: User runs `pnpm dev` and verifies Tab 2 grid loads at `/{lang}/crm/prayerrequest/prayerrequests?tab=replyqueue`. No DB migration / no seed / BE redeploy required after `dotnet build` confirmation.

---

> **Cross-session note**: This Session 2 was triggered by a workspace-wide bug report that also produced Session 2 entries on `prayerrequestentry.md` (#136) and `prayerrequestreviewreplies.md` (#138). Each entry lists only the files touched for its own screen scope. See those prompts for #136 / #138 detail.
