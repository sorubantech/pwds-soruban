---
screen: PrayerRequestReviewReplies (Tab 3 content within PrayerRequests workspace)
registry_id: 138
module: CRM (Prayer Request)
status: COMPLETED
scope: TAB_CONTENT — extends #136 workspace AND extends the `PrayerRequestReplies` entity introduced by #137 (no new table, no new entity — only 2 new state transitions: SubmittedForReview → Approved | Rejected, plus a supervisor-initiated recall variant). Adds Tab 3 components that replace the `<TabComingSoon label="Review Replies" releaseTarget="#138" />` slot.
screen_type: FLOW (inside tab — grid + review-mode view-page constrained to `?tab=reviewreplies&mode=...` URL semantics)
parent_workspace: PRAYERREQUESTS (built by #136 — capability gate REPLY_APPROVE already seeded)
workspace_tab_key: reviewreplies
complexity: Medium
new_module: NO (`corg` schema + `corg.PrayerRequests` parent exist; `corg.PrayerRequestReplies` introduced by #137)
new_table: NO (extends existing `corg.PrayerRequestReplies` — fields `ReviewedByContactId / ReviewedAt / ReviewerNote` already exist as nullable from #137; #138 just populates them)
new_handlers: YES — 3 new mutations + 2 new queries on the existing entity
planned_date: 2026-05-12
completed_date: 2026-05-12
last_session_date: 2026-05-12
hard_dependency: #137 MUST be COMPLETED before #138 can build (entity table + Submit handler + GetById query are prerequisites)
---

> **Mockup status (ISSUE-1 carry-over)**: NO HTML mockup at `html_mockup_screens/screens/prayer-request/review-reply*.html`. Spec authored 2026-05-12 from PSS 2.0 pastoral-care domain knowledge + #136/#137 precedent. All grid columns / review form sections / detail layouts below are SPEC, not mockup-extracted. UX Architect agent may refine card order / iconography / copy without changing semantics.

> **TAB_CONTENT scope (re-scoped 2026-05-12)**: This screen does NOT register a new sidebar menu, does NOT add a new route, does NOT alter the workspace shell wiring beyond a single tab-slot swap. It builds the **content** that replaces the `<TabComingSoon label="Review Replies" releaseTarget="#138" />` placeholder slot inside `prayerrequests-workspace.tsx` (built by #136). Capability gate: **`REPLY_APPROVE`** (already seeded on the PRAYERREQUESTS menu by #136 — no new role-capability INSERT needed).

> **No new entity, no new migration**: #138 ADDS state transitions to the `corg.PrayerRequestReplies` entity introduced by #137. The fields `ReviewedByContactId / ReviewedAt / ReviewerNote` already exist (nullable, set to NULL by #137 Create) — this build populates them via the new Approve/Reject mutations. The new index `IX_PrayerRequestReplies_CompanyId_Status_SubmittedForReviewAt` was already added by #137 specifically to optimize Tab 3's supervisor queue query (forward-compat).

> **Workspace handoff pattern (continues from #137)**: When #138 builds, the workspace shell has already had its Tab 2 slot wired by #137 — only the Tab 3 slot remains. The 1-line shell edit for this build is **line ~218 in `prayerrequests-workspace.tsx`** (same file #137 also edits — they touch different lines).

> **HARD DEPENDENCY on #137**: This screen cannot be built until #137 has been built (or at least: the entity, EF config, migration, GetById query, and Submit handler must exist). The build skill MUST verify #137 status = COMPLETED before proceeding. If #137 is still PROMPT_READY, abort #138 build and direct the user to build #137 first.

---

## Tasks

### Planning (by /plan-screens)
- [x] Domain spec authored (mockup TBD — ISSUE-1)
- [x] Workspace extension strategy chosen — Tab content swap, no new menu/route
- [x] State machine increment locked: SubmittedForReview → Approved | Rejected (+ supervisor-initiated recall)
- [x] Edit-before-approve workflow designed (reviewer may edit Body/Subject/InternalNote during approval — captured in `ApprovePrayerRequestReply` request DTO)
- [x] FK targets resolved (PrayerRequestReply parent — exists after #137; Contact ×1 for ReviewedBy stamp)
- [x] File manifest computed (5 NEW BE files + 2 modified BE files + 6 NEW FE files + 4 wiring edits)
- [x] Approval-config strategy: NO_NEW_MENU — capability REPLY_APPROVE already seeded by #136; sample-data only
- [x] Hard dependency on #137 flagged
- [x] Prompt generated

### Generation (by /build-screen → /generate-screen)
- [x] **PRE-CHECK**: verified #137 code (entity + EF config + schemas + endpoints + FE DTO/GQL files) present in codebase as of 2026-05-12 — dependency satisfied (registry stale)
- [x] BA Analysis validated (supervisor audience + 3-decision workflow + edit-before-approve semantics) — prompt sections ①-④ encode the analysis verbatim; explicit agent run skipped
- [x] Solution Resolution complete (FLOW-in-tab pattern; existing-entity extension; workflow-only handlers — no new entity) — prompt section ⑤ encodes the resolution; explicit agent run skipped
- [x] UX Design finalized (FORM = side-by-side reviewer console; DETAIL = post-decision read-only with audit timeline) — prompt section ⑥ is the blueprint; no mockup to extract from, explicit agent run skipped
- [x] User Approval received (2026-05-12)
- [x] Backend code generated (3 new mutations: Approve / Reject / RecallToDrafter; 2 new queries: GetReviewQueueList + GetReviewQueueSummary; 5 new DTOs appended to existing `PrayerRequestReplySchemas.cs`) — Session 1, 2026-05-12
- [x] Backend wiring complete (existing `PrayerRequestReplyMutations.cs` extended with 3 mutation methods; `PrayerRequestReplyQueries.cs` extended with 2 query methods; no Mapster map changes needed) — Session 1, 2026-05-12
- [x] Frontend code generated (5 NEW tab files + 1 NEW presentation-pages file; DTO/GQL/Mutation extensions verified from Session 1) — Session 2, 2026-05-12 (inline by main orchestrator)
- [x] Frontend wiring complete (workspace shell `<TabComingSoon>` swap done; entity-operations registry block already wired; barrels auto-re-export via `export *`) — Session 2, 2026-05-12
- [ ] DB Seed script generated (NO menu/cap inserts; optional sample data — but the SubmittedForReview row seeded by #137 already provides E2E test data) — DEFERRED (per Section ⑨ DBSeedActions = NO INSERTs; E2E via #137 round-trip)
- [x] NO new EF migration (verified — entity unchanged from #137)
- [x] Registry updated to COMPLETED — Session 2, 2026-05-12

### Verification (post-generation — FULL E2E required)
- [ ] `dotnet build` passes
- [ ] `pnpm dev` — workspace loads; Tab 3 chip "Review Replies" now enabled (assumes REPLY_APPROVE capability granted to current user)
- [ ] Click Tab 3 → URL `?tab=reviewreplies` → grid loads listing only `Status=SubmittedForReview` replies for the tenant
- [ ] 4 KPI widgets render: Pending Review / Approved Today / Rejected Today / Avg Time-to-Approve (counts seeded from sample data)
- [ ] Filter "Channel: All / EMAIL / SMS / WHATSAPP / PHONE / LETTER / IN_PERSON" works
- [ ] Filter "Drafter: All / {staff name}" works (multi-select staff picker — list of contacts who have at least one SubmittedForReview reply)
- [ ] Filter "Category: All / multi-select PRAYERCATEGORY" works (filters on parent prayer)
- [ ] Date range filter on `SubmittedForReviewAt` works
- [ ] Default sort: `SubmittedForReviewAt ASC` (oldest first — FIFO supervisor queue)
- [ ] Row click → URL `?tab=reviewreplies&mode=review&id=R` → REVIEW Layout loads
- [ ] REVIEW Layout: side-by-side cards — left = Prayer Context (read-only), right = Reply Content (editable)
- [ ] All reply fields are editable while in REVIEW mode: ReplyBody, ReplySubject (EMAIL only), RecipientEmailOverride (EMAIL only), RecipientPhoneOverride (SMS/WHATSAPP only), InternalNote
- [ ] Internal note from drafter (`InternalNote`) is shown in a dimmed read-only panel ABOVE the editable reply (so reviewer can see drafter's note while editing)
- [ ] Reviewer's own note field (`ReviewerNote`) is a separate textarea at the bottom — required when Rejecting, optional when Approving
- [ ] **Approve action**: If reviewer edited ANY reply field → button label switches to "Edit & Approve"; otherwise "Approve". Submission POSTs `ApprovePrayerRequestReply` with the (possibly edited) field set → Status=Approved → URL redirects to `?tab=reviewreplies&mode=read&id=R`
- [ ] **Reject action**: Button always labeled "Reject". Clicking opens a modal/popover requiring `ReviewerNote` (min 5 chars, max 1000) → POSTs `RejectPrayerRequestReply` → Status=Rejected → URL redirects to `mode=read`
- [ ] **Recall to Drafter action** (overflow menu): button labeled "Send back to drafter for revision". Optional ReviewerNote. POSTs `RecallPrayerRequestReplyToDrafter` → Status=Draft → row disappears from Tab 3 → reappears in #137 Tab 2's queue
- [ ] mode=read (post-decision): Both columns become read-only; status badge (Approved=green / Rejected=red) is prominent; ReviewerNote callout box rendered if non-null; action bar replaced with read-only message ("Reviewed by {Name} on {Date}")
- [ ] Server-stamping: `ReviewedByContactId` = HttpContext.User.ContactId, `ReviewedAt` = UtcNow — NEVER trusted from request body
- [ ] Concurrency check: if reviewer fetches a reply (Status=SubmittedForReview) and a separate session has already approved/rejected it, the Approve/Reject mutation returns 409 with a friendly message ("This reply was already reviewed by {Name} just now — refresh to see the latest state")
- [ ] Reject without ReviewerNote → server returns 422 validation error
- [ ] Approve on a non-SubmittedForReview reply → server rejects (e.g., trying to re-approve an already-Approved one)
- [ ] Permission check: user WITHOUT `REPLY_APPROVE` capability → Tab 3 chip disabled with tooltip
- [ ] User with `REPLY_APPROVE` but in different tenant cannot see other tenants' SubmittedForReview rows
- [ ] **Round-trip with #137**: in tenant A, drafter X submits a reply → Tab 3 shows it → reviewer Y rejects with note → reply returns to Draft → drafter X sees it back in Tab 2's "In Draft" KPI with red `ReviewerNote` callout in DETAIL view
- [ ] **Edit-before-approve round-trip**: drafter X submits with typo → reviewer Y edits the typo + approves → drafter X opens the DETAIL → sees the approved reply with their original body NOW REPLACED by reviewer's edit + a "Last edited during review" indicator
- [ ] UI uniformity: zero inline hex/px; Skeletons on all useQuery surfaces; sibling cards same padding
- [ ] DB Seed: no new menus/caps; SubmittedForReview sample row (seeded by #137) is consumable by Tab 3 — verifies cross-build wiring
- [ ] Layout Variant B confirmed: workspace `<ScreenHeader>` renders ONCE; tab uses `<DataTableContainer showHeader={false}>`
- [ ] `dotnet ef migrations` shows NO pending migrations (entity unchanged) — DB schema is identical to post-#137 state

---

## ① Screen Identity & Context

> **Consumer**: All agents — sets the stage

Screen: **Review Replies** (Tab 3 content within the PrayerRequests workspace; same sidebar menu as Tabs 1 & 2)
Module: **CRM** (Prayer Request)
Schema: **`corg`**
Group: **ContactModels** (existing entity)
Parent Workspace Tab Key: **`reviewreplies`**

Business: After a prayer-team drafter writes a reply in Tab 2 Reply Queue (#137) and clicks "Submit for Approval", the reply lands in this supervisor queue with Status=`SubmittedForReview`. Tab 3 is where senior pastors, pastoral-care leads, and ministry directors **review and approve** those drafts before they get sent to the prayer submitter. Three decisions are possible per row: (a) **Approve** the reply as-is (or with minor edits the reviewer makes inline); (b) **Reject** the reply with a written reason (the reply returns to Draft state with the rejection note attached, so the drafter can see why and try again); (c) **Recall to drafter** — a softer variant of Reject that returns the reply to Draft WITHOUT a "rejected" stigma (used when the supervisor wants the drafter to revise without a formal rejection on record — e.g., a typo, a wrong Scripture citation, a missing personal touch). The Approve action is the most common — over 80% of well-drafted replies should sail through with no edits. The Edit-before-approve flow is for the small minority of cases where the supervisor wants to polish the tone or fix a typo without forcing a round-trip. The headline interaction goal is "a senior pastor reviewing 20 submitted replies should be able to clear the queue in under 30 minutes." Secondary goals: (a) supervisors see the FULL prayer context next to the reply (side-by-side) so the approval decision is contextually informed; (b) drafters see rejection notes when their reply returns to Draft, closing the feedback loop; (c) once Approved, the reply enters a "pending send" holding state waiting for a future Send-Service (out of scope — see #137 §⑫ SERVICE_PLACEHOLDER); (d) audit trail captures who reviewed what and when. **Audience**: supervisors with REPLY_APPROVE capability — typically senior pastors, pastoral-care leads, or ministry directors. **What's unique vs. Tab 2**: Tab 2's "drafter" can ONLY transition Draft→SubmittedForReview; Tab 3's "reviewer" can transition SubmittedForReview → Approved | Rejected | Draft. Reviewer has stronger powers (edit-during-review is allowed; drafter can only edit their own Drafts). **What breaks if mis-set**: (a) cross-tenant leak (reviewer in tenant A seeing tenant B's SubmittedForReview rows — must filter by CompanyId on every query); (b) race condition between two simultaneous reviewers (must surface 409 conflict); (c) allowing Rejection without a ReviewerNote would leave the drafter in the dark (must validate non-empty ReviewerNote on Reject); (d) failing to server-stamp ReviewedByContactId would break the supervisor audit trail; (e) editing a non-SubmittedForReview reply (e.g., trying to "fix" an Approved reply after the fact) would corrupt audit history — must reject server-side. **Related screens**: #136 Tab 1 Entry (where prayers get approved before they reach the reply queue), #137 Tab 2 Reply Queue (where the reply originates), future Send-Service (consumes Approved replies and dispatches via transport).

> **Why this section is heavy**: there is NO mockup; the BA / UX Architect / Backend / Frontend agents all need rich prose to understand the 3-decision workflow + the edit-before-approve UX + the round-trip with #137 (reject → drafter sees note → revise → resubmit). Cutting it shorter forces each agent to guess the semantic distinction between Reject vs Recall-to-drafter (the bug-trap of this screen).

---

## ② Entity Definition (existing — reused from #137)

> **Consumer**: BA Agent → Backend Developer
> **CRITICAL**: This screen DOES NOT define a new table. The entity `corg.PrayerRequestReplies` was introduced by #137 with all 17 fields including `ReviewedByContactId / ReviewedAt / ReviewerNote / Status`. This build POPULATES those fields via 3 new mutations — no schema change, no new EF migration.

Table: `corg."PrayerRequestReplies"` (EXISTING — reused unchanged)

### Fields touched by #138 (read AND write)

| Field | Already exists? | Written by | Read by |
|-------|----------------|------------|---------|
| `Status` | YES (from #137) | This build: `Approve` sets `Approved`; `Reject` sets `Rejected`; `RecallToDrafter` sets `Draft` | All queries |
| `ReviewedByContactId` | YES (nullable, from #137) | This build: server-stamped from HttpContext.User.ContactId on Approve/Reject/Recall | Display |
| `ReviewedAt` | YES (nullable, from #137) | This build: server-stamped = UtcNow on Approve/Reject/Recall | Display |
| `ReviewerNote` | YES (nullable, from #137) | This build: optional on Approve, REQUIRED on Reject (min 5 chars), optional on Recall | Display |
| `LastUpdatedByContactId` | YES (from #137) | This build: server-stamped if reviewer edits reply during approve | Display |
| `LastUpdatedAt` | YES (from #137) | This build: server-stamped if reviewer edits reply during approve | Display |
| `ReplyBody` | YES (from #137) | This build (conditional): if reviewer edits during approve, body updated | Display |
| `ReplySubject` | YES (from #137) | This build (conditional): same as body | Display |
| `RecipientEmailOverride` | YES (from #137) | This build (conditional): same | Display |
| `RecipientPhoneOverride` | YES (from #137) | This build (conditional): same | Display |
| `InternalNote` | YES (from #137) | This build (conditional): same — but reviewer's edits to this preserve the drafter's original (concat with a separator) — see §④ | Display |
| `SubmittedForReviewAt` | YES (from #137) | NEVER written by this build (only read for sort key) | Display |

### Fields NEVER written by #138

`PrayerRequestReplyId / CompanyId / PrayerRequestId / DraftedByContactId / DraftedAt / SubmittedForReviewAt / SentAt / DeliveryRefId` — immutable from #138's perspective.

### State machine deltas (this build owns these transitions)

| From | To | Mutation | Required Field |
|------|-----|----------|----------------|
| SubmittedForReview | Approved | `ApprovePrayerRequestReply` | (none) — `ReviewerNote` optional |
| SubmittedForReview | Rejected | `RejectPrayerRequestReply` | `ReviewerNote` required (min 5 chars) |
| SubmittedForReview | Draft | `RecallPrayerRequestReplyToDrafter` | (none) — `ReviewerNote` optional |

Out of scope (still): Approve→Rejected (post-approval rejection) — defer to future "audit revoke" pattern; Approved→Sent (future Send-Service); Sent→anything (terminal).

### EF migration safety

- **No migration**. No schema change.
- Verify after #138 codegen: `dotnet ef migrations list` shows the most recent migration is `Add_PrayerRequestReplies_Table` (from #137) and `dotnet ef migrations add` (dry run) doesn't propose anything.

### Validation contract for new DTOs

**`ApprovePrayerRequestReplyRequestDto`:**
| Field | Required | Validation |
|-------|----------|------------|
| `prayerRequestReplyId` | YES | Must exist + belong to same Company + Status=`SubmittedForReview` (server rejects otherwise) |
| `reviewerNote` | NO | Max 1000 chars |
| `editedReplyBody` | NO | If set: server uses this instead of existing `ReplyBody`; min 5, max 8000 chars |
| `editedReplySubject` | NO | If set: server uses this; channel-conditional (EMAIL only) |
| `editedRecipientEmailOverride` | NO | If set: channel-conditional |
| `editedRecipientPhoneOverride` | NO | If set: channel-conditional |
| `editedInternalNote` | NO | If set: server appends to existing with `\n---\nReviewer (Name, Date): {note}\n` separator (preserves drafter's original) |

**`RejectPrayerRequestReplyRequestDto`:**
| Field | Required | Validation |
|-------|----------|------------|
| `prayerRequestReplyId` | YES | Must exist + same Company + Status=`SubmittedForReview` |
| `reviewerNote` | **YES** | Min 5 chars, max 1000 chars (this is the rejection reason — drafter sees it) |

**`RecallPrayerRequestReplyToDrafterRequestDto`:**
| Field | Required | Validation |
|-------|----------|------------|
| `prayerRequestReplyId` | YES | Must exist + same Company + Status=`SubmittedForReview` |
| `reviewerNote` | NO | Optional explanation; max 1000 chars |

### Server-stamping rules

All three mutations stamp:
- `ReviewedByContactId` ← `HttpContext.User.ContactId`
- `ReviewedAt` ← `DateTime.UtcNow`

Approve mutation, if any `edited*` field is non-null, additionally stamps:
- `LastUpdatedByContactId` ← `HttpContext.User.ContactId`
- `LastUpdatedAt` ← `DateTime.UtcNow`
- (The corresponding entity property — `ReplyBody`/`ReplySubject`/etc.)

RecallToDrafter mutation, additionally:
- `SubmittedForReviewAt` ← `null` (cleared, mirroring the drafter-initiated Recall from #137)
- `Status` ← `Draft`

### Concurrency guard

Each mutation uses an EF optimistic-concurrency check pattern: load the row, check `Status == "SubmittedForReview"` after re-attaching to context, abort with 409 if changed. Use `dbContext.SaveChangesAsync` with `IsConcurrencyToken=false` (no rowversion column) but the WHERE clause adds `AND Status = 'SubmittedForReview'` so a simultaneous Approve/Reject race is caught.

---

## ③ FK Resolution Table

> **Consumer**: Backend Developer (`.Include()` / navigation) + Frontend Developer (no new pickers — server-stamped)

| FK Field | Target Entity | Entity File Path | GQL Query Name (FE) | Display Field | GQL Response Type |
|----------|--------------|-------------------|----------------------|---------------|-------------------|
| `PrayerRequestReplyId` | PrayerRequestReply | (introduced by #137 — `Base.Domain/Models/ContactModels/PrayerRequestReply.cs`) | (no picker; loaded by GetById) | — | `PrayerRequestReplyResponseDto` (reuse from #137) |
| `ReviewedByContactId` | Contact | `Base.Domain/Models/ContactModels/Contact.cs` | (NOT exposed as picker — server-stamped from HttpContext) | `displayName` | `ContactResponseDto` |
| `PrayerRequestId` (parent, via PrayerRequestReply navigation) | PrayerRequest | `Base.Domain/Models/ContactModels/PrayerRequest.cs` | (no picker; loaded via `.Include(r => r.PrayerRequest)` on existing GetById) | (composite) | `PrayerRequestEntryResponseDto` (reuse from #136) |
| `DraftedByContactId` (read-only display) | Contact | (same) | (no picker — display only) | `displayName` | `ContactResponseDto` |

**Zero new FK pickers in the FORM** — the reviewer never picks anything FK-wise. Everything is server-stamped. The form fields are all native types (textareas + status badges + action buttons).

**MasterData reference** (no FK column):

| Code Type | MasterDataType | Used For |
|-----------|----------------|----------|
| `PRAYERCATEGORY` | (already seeded by #171) | Display in the read-only Prayer Context card |

---

## ④ Business Rules & Validation

> **Consumer**: BA Agent → Backend Developer (validators) → Frontend Developer (form validation)

**Uniqueness Rules:**
- None new — the entity uniqueness rules from #137 still apply (at-most-one Draft per drafter/channel/prayer). #138 doesn't create new replies — it only state-transitions existing ones.

**Required Field Rules:**
- `reviewerNote` is required on `RejectPrayerRequestReply` (min 5 chars, max 1000)
- `reviewerNote` is optional on `ApprovePrayerRequestReply` and `RecallPrayerRequestReplyToDrafter` (max 1000)

**Conditional Rules:**
- **Edit-during-approve**: If any `edited*` field in the Approve request DTO is non-null, the server treats it as a Body/Subject/Override edit AND stamps `LastUpdatedByContactId/At`. Validator must enforce the channel-specific rules (e.g., `editedReplySubject` rejected if reply's Channel ≠ EMAIL).
- **Reviewer cannot edit `InternalNote` destructively**: if `editedInternalNote` is non-null, server APPENDS a separator + reviewer's edit to the existing InternalNote (e.g., `"original drafter note\n---\nReviewer (John Smith, 2026-05-13): added Bible reference"`); never overwrites the drafter's note silently.
- **Reject without note**: validator returns 422 with field-level error `{ field: "reviewerNote", message: "Rejection reason is required" }`.
- **Approve a non-SubmittedForReview reply**: handler returns 409 with message `"This reply is no longer in review state (current status: {currentStatus}). It may have been reviewed by another supervisor."`
- **Channel-specific validation on edited fields**: same rules as #137 — `editedReplySubject` only valid for EMAIL channel; `editedRecipientEmailOverride` only for EMAIL; `editedRecipientPhoneOverride` only for SMS/WHATSAPP. PHONE/LETTER/IN_PERSON reject all override edits.

**Business Logic:**
- **Approve**:
  1. Load reply + verify Status=SubmittedForReview + tenant match → 409 if not.
  2. If any `edited*` field is non-null → server validates (channel rules) → applies edits to entity → stamps `LastUpdatedByContactId/At`.
  3. Set `Status = "Approved"`, stamp `ReviewedByContactId/At`, optionally `ReviewerNote`.
  4. SaveChanges with concurrency-guarded WHERE clause.
- **Reject**:
  1. Load reply + verify state.
  2. Validate `reviewerNote` is non-empty.
  3. Set `Status = "Rejected"`, stamp `ReviewedByContactId/At/ReviewerNote`.
  4. SaveChanges.
  5. **No notification fires** (notification service is SERVICE_PLACEHOLDER — drafter discovers via Tab 2 Reply Queue or via the badge).
- **RecallToDrafter**:
  1. Load reply + verify state.
  2. Set `Status = "Draft"`, clear `SubmittedForReviewAt = null`, stamp `ReviewedByContactId/At` (yes, we record that a reviewer touched it even though we're sending it back), optionally `ReviewerNote`.
  3. SaveChanges.
  4. The reply now reappears in Tab 2's "In Draft" KPI for the original drafter.

**Workflow** (full state machine — #138 owns the green box):

```
                                                  ┌──────────────────────────────┐
                                                  │  #138 territory              │
                                                  │                              │
                                                  │  ApprovePrayerRequestReply ──┼──► Approved ──► (future Send-Service) ──► Sent / Failed
                                                  │     (+ optional edits)       │
                                                  │                              │
   #137 Tab 2: Draft ──► SubmittedForReview ──────┼──► RejectPrayerRequestReply ─┼──► Rejected
                              ▲                   │     (REQUIRES reviewerNote)  │       │
                              │                   │                              │       │
                              │                   │  RecallPrayerRequestReplyTo──┼──► Draft (back to #137 Tab 2)
                              │                   │    Drafter (no note required)│       │
                              │                   └──────────────────────────────┘       │
                              │                                                          │
                              └─────────────── (drafter revises + resubmits) ◄───────────┘
```

**Permission Matrix:**

| Action | Required Capability | Additional Check |
|--------|---------------------|-------------------|
| View Tab 3 grid | `REPLY_APPROVE` | tenant scope |
| View any reply detail (read-only post-decision) | `REPLY_APPROVE` OR `REPLY_DRAFT` (the drafter also wants to see their reviewed reply) | tenant scope |
| Approve | `REPLY_APPROVE` | Status=SubmittedForReview + tenant |
| Reject | `REPLY_APPROVE` | Status=SubmittedForReview + tenant + non-empty reviewerNote |
| RecallToDrafter | `REPLY_APPROVE` | Status=SubmittedForReview + tenant |
| Edit reply during approve | `REPLY_APPROVE` | (implicit — reviewer always has edit power on SubmittedForReview) |

---

## ⑤ Screen Classification & Pattern Selection

> **Consumer**: Solution Resolver — these are PRE-ANSWERED decisions based on context.

**Screen Type**: TAB_CONTENT (FLOW pattern constrained to a workspace tab, no new entity)
**Type Classification**: Workflow / Transactional / State-transition handlers / Edit-on-approve UX
**Reason**: Same workspace-tab pattern as #137. Reuses #137's entity. Adds 3 new mutations + 2 new queries. UX is a side-by-side reviewer console — prayer context on the left, editable reply on the right, action bar at bottom.

**Backend Patterns Required:**
- [x] **NO new entity** (reuses `PrayerRequestReply` from #137)
- [x] **NO new EF migration** (entity unchanged)
- [x] 3 new workflow handlers (Approve / Reject / RecallToDrafter)
- [x] 2 new queries (GetReviewQueueList — composite with PrayerRequest + DraftedBy Includes; GetReviewQueueSummary — KPI counts)
- [x] Tenant scoping on every query/mutation (CompanyId from HttpContext)
- [x] Optimistic concurrency guard (WHERE Status=SubmittedForReview clause on update)
- [x] Edit-during-approve validation (channel-specific rules mirror #137)
- [x] 4 new DTOs (Approve/Reject/Recall request + ReviewQueueRow + ReviewQueueSummary) appended to existing `PrayerRequestReplySchemas.cs`

**Frontend Patterns Required:**
- [x] FlowDataTable (grid) — `displayMode: table`, sort by SubmittedForReviewAt ASC default (FIFO queue)
- [x] view-page.tsx with 2 URL modes (`review` for active review; `read` for post-decision) — scoped to `?tab=reviewreplies`
- [x] React Hook Form for the editable reply card (re-uses #137's RHF schema with all fields optional — reviewer may submit with no edits = vanilla Approve)
- [x] Zustand store (`review-replies-store.ts`) — tab-local state (active filters, optimistic state for the 3 actions)
- [x] Reject modal (small modal with required ReviewerNote textarea + Cancel/Confirm buttons)
- [x] Recall confirmation popover (optional ReviewerNote + Cancel/Send-back buttons)
- [x] Layout Variant B (workspace `<ScreenHeader>` already renders; tab uses `showHeader={false}`)
- [x] 4 Summary widgets above grid: Pending Review / Approved Today / Rejected Today / Avg Time-to-Approve
- [x] Side-by-side card layout in REVIEW mode (Prayer Context left + Editable Reply right + Drafter's Internal Note panel + Reviewer's Note panel + Action Bar)
- [x] Status badge color matrix (same as #137)
- [x] Tab content registration in workspace shell

---

## ⑥ UI/UX Blueprint

> **Consumer**: UX Architect → Frontend Developer
> Spec-derived (no HTML mockup — ISSUE-1). All details below are SPEC; UX Architect agent may adjust visual treatment.

### Tab Position & URL Semantics

- This tab is **Tab 3** in the workspace. Activated when URL = `?tab=reviewreplies`.
- Internal URL modes:

```
URL                                                              UI Layout
─────────────────────────────────────────────────────            ─────────────────────────
?tab=reviewreplies                                               Grid (Review Queue)
?tab=reviewreplies&mode=review&id=R                              REVIEW Layout (editable)
?tab=reviewreplies&mode=read&id=R                                READ Layout (post-decision, read-only)
```

> Note: only 2 internal modes (`review` + `read`) — there is no `new` mode because #138 NEVER creates a reply (that's #137).

### Grid/List View

**Display Mode**: `table` (transactional supervisor queue, dense rows preferred)

**Grid Layout Variant**: `widgets-above-grid` (4 KPI cards → Variant B: workspace `<ScreenHeader>` once; tab uses `showHeader={false}`)

**KPI Widgets** (4, in row at top of tab):

| # | Widget Title | Value Source | Display Type | Color Cue | Click Behavior |
|---|-------------|-------------|-------------|-----------|----------------|
| 1 | **Pending Review** | `pendingReviewCount` from `GetReviewQueueSummary` | count | amber | filter grid to Status=SubmittedForReview (default — no-op) |
| 2 | **Approved Today** | `approvedTodayCount` | count | green | filter grid to Status=Approved + ReviewedAt today (switches grid mode) |
| 3 | **Rejected Today** | `rejectedTodayCount` | count | red | filter grid to Status=Rejected + ReviewedAt today |
| 4 | **Avg Time-to-Approve** | `avgTimeToApproveMinutes` | duration (e.g., "4h 12m") | blue | (no click — informational only) |

> Subtitles: "Today" + "All-time" small dimmed.
> Card colors follow the status badge convention.

> **Note**: KPI cards 2 + 3 are "drill-into-history" — clicking them switches the grid filter to show post-decision rows (Approved / Rejected) instead of the default Pending. This converts Tab 3 from a "supervisor queue" view into a "review history" view temporarily. A "Reset to Pending" pill chip appears in the filter bar when in history mode.

**Grid Columns** (in display order — default view: Status=SubmittedForReview):

| # | Column Header | Field Key | Display Type | Width | Sortable | Notes |
|---|--------------|-----------|-------------|-------|----------|-------|
| 1 | Submitted | `submittedForReviewAt` | relative time + tooltip with absolute timestamp | 130px | YES | **Default sort: ASC (oldest first — FIFO)** |
| 2 | Drafter | `draftedByContact.displayName` | text + avatar initials | 160px | YES | — |
| 3 | Channel | `replyChannel` | channel icon + label | 120px | YES | EMAIL/SMS/etc. |
| 4 | Recipient | resolved: `recipientEmailOverride ?? linkedContact.primaryEmail ?? prayer.submitterEmail` (or phone for SMS/WHATSAPP) | text (truncated) | 180px | NO | Reviewer wants to see WHO this reply is going to |
| 5 | Prayer Category | `prayer.categoryCode` resolved via MasterData (emoji + name) | text + emoji | 140px | YES | — |
| 6 | Prayer Excerpt | first 60 chars of `prayer.body` + ellipsis | text | auto (flex) | NO | Reviewer can see the original prayer at a glance |
| 7 | Reply Excerpt | first 60 chars of `replyBody` + ellipsis | text | auto (flex) | NO | And the proposed reply |
| 8 | Drafter Note | bool indicator (icon if non-null) | icon | 80px | NO | "💬" icon if `internalNote` non-null — supervisor knows there's context to read |
| 9 | Time in Queue | `(now - submittedForReviewAt)` | duration | 110px | YES | "2h 4m" — sortable for SLA monitoring |

**Search/Filter Fields:**
- **Search**: drafter name / reply body / prayer body / category
- **Channel**: multi-select `EMAIL | SMS | WHATSAPP | PHONE | LETTER | IN_PERSON`
- **Drafter**: multi-select staff picker (queries `Get{Staff}List` or filtered Contact list — same as #136's TakenBy filter)
- **Category**: multi-select PRAYERCATEGORY (filters parent prayer)
- **Date range**: filter on `submittedForReviewAt`
- **Status** (when KPI 2/3 clicked): single-select toggle Pending / Approved / Rejected — shown as a pill chip in the filter bar when in history mode

**Grid Actions** (per row):
- Primary: "Review" button → `?tab=reviewreplies&mode=review&id={replyId}` (only for SubmittedForReview rows)
- Read-only rows (in history mode): "View" link → `?tab=reviewreplies&mode=read&id={replyId}`

**Row Click**: same as primary action button

**Empty State**:
- Pending mode: "No replies awaiting your review. Once a prayer-team drafter clicks 'Submit for Approval' in the Reply Queue tab, they'll appear here."
- History mode (Approved Today / Rejected Today filter): "No replies reviewed in this date range. Try clearing the filter."

**Bulk Actions** (optional — defer to follow-up if token-pressured):
- Checkbox column (leftmost) for selecting rows
- "Approve Selected" button in toolbar (visible when selection ≥ 1 + all selected rows are Status=SubmittedForReview)
- Bulk approve confirms with single Yes/No modal, then iterates `ApprovePrayerRequestReply` for each (sequential to avoid overloading the server)
- No bulk Reject (rejection requires a per-row note)
- **Defer**: if build is tight on tokens, ship without bulk approve; flag as ISSUE for follow-up.

---

### LAYOUT 1: REVIEW (mode=review) — editable supervisor console

> The active review form. Side-by-side cards. NOT collapsible — supervisor always sees both prayer + reply at once.

**Page Header**: `FlowFormPageHeader` with:
- Back button → returns to grid (`?tab=reviewreplies`)
- Status badge inline (amber "SubmittedForReview")
- Time-in-queue indicator: "Submitted 2h 4m ago by {DrafterName}" — small text
- Header right-actions: (none — actions go in the action bar at bottom)

**Page Layout**: 2-column grid (1fr 1fr on desktop, stacked on mobile)

| Column | Width | Cards |
|--------|-------|-------|
| Left | 1fr | Card 1: Original Prayer (read-only, full body) · Card 2: Drafter's Internal Note (dimmed read-only panel) |
| Right | 1fr | Card 3: Editable Reply (RHF — channel-conditional fields) · Card 4: Reviewer Note (textarea, optional unless Rejecting) |

**Left Column Card 1: Original Prayer (read-only)**

| Field | Display |
|-------|---------|
| Submitter | Avatar + Name (or "Anonymous") + Country flag |
| Category | Emoji + name badge |
| Source | Channel chip (WEB/IFRAME/PHONE_IN/etc.) |
| Title | Bold (if present) |
| Body | Full prayer text in quoted block; max-height 400px with scroll |
| SubmittedAt | "Received {N} days ago" |
| LinkedContact | If non-null, "View Contact Profile →" link |

**Left Column Card 2: Drafter's Internal Note**

- Small panel, dimmed background, italic.
- Header: "Note from drafter — {DrafterName}, {DraftedAt relative time}"
- Body: `internalNote` (or "No note from drafter" placeholder)
- This is read-only — supervisor cannot edit drafter's note (server appends supervisor edits separately per §④).

**Right Column Card 3: Editable Reply** (RHF form — same field shape as #137 FORM but all fields are pre-filled and labeled "Edit if needed")

| Field | Widget | Pre-fill | Editable? |
|-------|--------|----------|-----------|
| Channel | Display-only chip with icon + label | `replyChannel` from reply | NO (channel is locked — can't switch channel during review) |
| Subject (if EMAIL) | text input | `replySubject` | YES |
| Recipient Email Override (if EMAIL) | email input | `recipientEmailOverride` (or display resolved address as placeholder) | YES |
| Recipient Phone Override (if SMS/WHATSAPP) | phone input | `recipientPhoneOverride` | YES |
| Body | textarea (large — 12 rows) | `replyBody` | YES |
| InternalNote (reviewer's additions) | textarea (small — 2 rows, placeholder "Add to drafter's note if helpful…") | empty (new — server appends) | YES |

> Form is "dirty-detection-aware" — if ANY field is touched, the action bar button label switches from "Approve" to "Edit & Approve" (visual cue that the reviewer is making changes).

**Right Column Card 4: Reviewer Note (separate from InternalNote)**

| Field | Widget | Required | Notes |
|-------|--------|----------|-------|
| ReviewerNote | textarea (3 rows, max 1000 chars) | conditional | Required if Reject pressed (modal enforces); optional if Approve or Recall |

> Distinct from InternalNote: ReviewerNote is the **supervisor's decision rationale** ("approved; great work" / "rejected; please add a Bible verse" / "send back; typo in line 3"). It surfaces in #137's DETAIL view as a callout box.

**Action Bar (sticky at bottom of REVIEW layout)**:
- LEFT: Back link → grid (unsaved-changes dialog if any edited field is dirty)
- RIGHT (3 buttons):
  - **Approve** (filled primary green) — label switches to "Edit & Approve" if any reply field touched
  - **Reject** (outline red) — opens reject modal requiring ReviewerNote
  - **Send back to drafter** (link — less prominent — text-button) — opens recall confirmation popover (optional ReviewerNote)
- Char counter: "ReplyBody: {length} / 8000"

**Reject Modal (opens when "Reject" clicked)**:
- Title: "Reject reply"
- Body: "Tell the drafter why you're rejecting this reply. They'll see your note in the Reply Queue tab when the reply returns to Draft."
- Field: ReviewerNote textarea (required, min 5, max 1000) — pre-fills from Card 4 if already typed
- Buttons: Cancel + Confirm Reject (red)
- On Confirm: POST `RejectPrayerRequestReply` → URL → `?tab=reviewreplies&mode=read&id=R`

**Recall Popover (opens when "Send back to drafter" clicked)**:
- Title: "Send back to drafter"
- Body: "This sends the reply back to the drafter as a Draft for revision — without rejecting it. Use this for typos or small fixes you don't want to formally reject."
- Field: ReviewerNote textarea (optional, max 1000)
- Buttons: Cancel + Confirm Send Back
- On Confirm: POST `RecallPrayerRequestReplyToDrafter` → URL → grid (the reply is now in Tab 2's queue, not Tab 3)

---

### LAYOUT 2: READ (mode=read) — post-decision read-only

> Rendered when the reviewer (or another user with access) opens a reply that has already been Approved / Rejected / Recalled.
> Identical 2-column layout as REVIEW, but everything is read-only and there's no action bar.

**Page Header**:
- Back button
- Status badge inline with color (Approved=green / Rejected=red / Sent=blue / Failed=red-darker)
- "Reviewed by {ReviewerName} on {ReviewedAt absolute}"
- No header actions (read-only)

**Left Column**: same as REVIEW Card 1 + Card 2

**Right Column**:
- Card 3: Reply Content (read-only display — final body, subject, recipient resolved)
- Card 4: ReviewerNote (callout box — green-tinted if Approved, red-tinted if Rejected, gray if Recalled-to-Drafter)
- Card 5 (new for read mode): Audit Trail mini-timeline — Drafted by {Name} {Date} → SubmittedForReview {Date} → Reviewed by {Name} {Date} (+ Approved/Rejected/Recalled label)

**No action bar** — read-only.

### Page Widgets & Summary Cards

> 4 KPI widgets (defined above in Grid section).

**Summary GQL Query**:
- Query name: `GetReviewQueueSummary`
- Returns: `ReviewQueueSummaryDto` with fields `pendingReviewCount`, `approvedTodayCount`, `rejectedTodayCount`, `avgTimeToApproveMinutes`, plus all-time totals.

---

### User Interaction Flow

1. User clicks Tab 3 → URL `?tab=reviewreplies` → grid loads listing SubmittedForReview replies for tenant, sorted by SubmittedForReviewAt ASC (FIFO)
2. 4 KPI widgets render at top
3. User scans grid → clicks "Review" on row R → URL `?tab=reviewreplies&mode=review&id=R` → REVIEW layout loads
4. User reads prayer (left), drafter's note (left), proposed reply (right)
5. **Vanilla Approve path**: user clicks "Approve" button (label still "Approve" because no edits) → POST `ApprovePrayerRequestReply` with empty `edited*` fields → Status=Approved → redirect `?tab=reviewreplies&mode=read&id=R` → READ layout loads with green badge
6. **Edit-then-Approve path**: user fixes a typo in ReplyBody → button label switches to "Edit & Approve" → click → POST `ApprovePrayerRequestReply` with `editedReplyBody` populated → server validates + stamps LastUpdatedByContactId/At + flips Status → redirect to READ
7. **Reject path**: user clicks "Reject" → modal opens → user types ReviewerNote (min 5 chars) → Confirm Reject → POST `RejectPrayerRequestReply` → Status=Rejected → redirect to READ with red badge + ReviewerNote callout
8. **Recall-to-Drafter path**: user clicks "Send back to drafter" → popover opens → optional note → Confirm → POST `RecallPrayerRequestReplyToDrafter` → Status=Draft → grid refreshes (the row is now GONE from Tab 3 — it lives in Tab 2 again)
9. From grid history mode: user clicks "Approved Today" KPI → grid filter switches → user clicks a row → URL `?tab=reviewreplies&mode=read&id=R` → READ layout (no review actions)
10. From #137 round-trip: drafter X submits → row appears here → reviewer Y rejects with note → in Tab 2 drafter sees their reply back in Draft with the red ReviewerNote callout → revises → resubmits → row reappears in Tab 3 → reviewer Y (or someone else) reviews again

---

## ⑦ Substitution Guide

> **Consumer**: Backend Developer + Frontend Developer

**Canonical Reference**: **SavedFilter (FLOW pattern)** + **PrayerRequestReply (entity introduced by #137)** + **PrayerRequestReplyQueue (#137 tab precedent)**

| Canonical | → This Build | Context |
|-----------|--------------|---------|
| SavedFilter | PrayerRequestReply | Entity (REUSED — no new entity) |
| savedFilter | prayerRequestReply | Variable names |
| SavedFilterId | PrayerRequestReplyId | PK (reused) |
| SavedFilters | PrayerRequestReplies | Table name (reused) |
| saved-filter | prayer-request-review-replies | FE folder name segment |
| savedfilter | reviewreplies | FE tab folder (under `prayerrequests/tabs/reviewreplies/`) |
| SAVEDFILTER | — | NO new menu code (extends PRAYERREQUESTS) |
| notify | corg | DB schema (reused) |
| Notify | Contact | Backend group (existing) |
| ContactModels | ContactModels | Same group |
| NOTIFICATION | CRM | Module (existing) |
| crm/communication/savedfilter | crm/prayerrequest/prayerrequests?tab=reviewreplies | Workspace URL + tab query param |
| notify-service | contact-service | FE service folder |

> **TAB_CONTENT key difference vs. canonical FLOW**: same as #137 — NO top-level `(core)/{group}/{feFolder}/{entity-lower}/page.tsx` route file. The "page" is the workspace's Tab 3 slot.

---

## ⑧ File Manifest

> **Consumer**: Backend Developer + Frontend Developer

### Backend Files (5 NEW + 4 modified)

| # | File | Path | NEW / Modified |
|---|------|------|---------------|
| 1 | Approve Command | `Pss2.0_Backend/.../Base.Application/Business/ContactBusiness/PrayerRequestReplies/ApproveCommand/ApprovePrayerRequestReply.cs` | **NEW** |
| 2 | Reject Command | `Pss2.0_Backend/.../Base.Application/Business/ContactBusiness/PrayerRequestReplies/RejectCommand/RejectPrayerRequestReply.cs` | **NEW** |
| 3 | RecallToDrafter Command | `Pss2.0_Backend/.../Base.Application/Business/ContactBusiness/PrayerRequestReplies/RecallToDrafterCommand/RecallPrayerRequestReplyToDrafter.cs` | **NEW** (distinct from #137's drafter-initiated `RecallCommand`; different namespace) |
| 4 | GetReviewQueueList Query | `Pss2.0_Backend/.../Base.Application/Business/ContactBusiness/PrayerRequestReplies/GetReviewQueueQuery/GetReviewQueueList.cs` | **NEW** |
| 5 | GetReviewQueueSummary Query | `Pss2.0_Backend/.../Base.Application/Business/ContactBusiness/PrayerRequestReplies/GetReviewSummaryQuery/GetReviewQueueSummary.cs` | **NEW** |
| 6 | Schemas (DTOs — EXTEND) | `Pss2.0_Backend/.../Base.Application/Schemas/ContactSchemas/PrayerRequestReplySchemas.cs` | **MODIFIED** (append `ApprovePrayerRequestReplyRequestDto`, `RejectPrayerRequestReplyRequestDto`, `RecallToDrafterRequestDto`, `ReviewQueueRowDto`, `ReviewQueueSummaryDto`) |
| 7 | Mutations Endpoint (EXTEND) | `Pss2.0_Backend/.../Base.API/EndPoints/Contact/Mutations/PrayerRequestReplyMutations.cs` | **MODIFIED** (add 3 new mutation methods) |
| 8 | Queries Endpoint (EXTEND) | `Pss2.0_Backend/.../Base.API/EndPoints/Contact/Queries/PrayerRequestReplyQueries.cs` | **MODIFIED** (add 2 new query methods) |
| 9 | (no new EF migration — entity unchanged) | — | — |

### Backend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | (none required) — `IApplicationDbContext.cs` already exposes `DbSet<PrayerRequestReply>` (from #137) | — |
| 2 | (none required) — `DecoratorContactModules` already has `PrayerRequestReply` entry (from #137) | — |
| 3 | (none required) — Mapster maps already exist (from #137) | — |
| 4 | Possibly: extend Mapster to map new DTOs (Approve/Reject request → entity field set) — usually trivial / handled by handler directly without Mapster | — |

### Frontend Files (6 NEW + 4 modified)

| # | File | Path | NEW / Modified |
|---|------|------|---------------|
| 1 | DTO Types (EXTEND) | `Pss2.0_Frontend/src/domain/entities/contact-service/PrayerRequestReplyDto.ts` | **MODIFIED** (append `ApprovePrayerRequestReplyRequestDto`, `RejectPrayerRequestReplyRequestDto`, `RecallToDrafterRequestDto`, `ReviewQueueRowDto`, `ReviewQueueSummaryDto`) |
| 2 | GQL Query (EXTEND) | `Pss2.0_Frontend/src/infrastructure/gql-queries/contact-queries/PrayerRequestReplyQuery.ts` | **MODIFIED** (add `GET_REVIEW_QUEUE_LIST`, `GET_REVIEW_QUEUE_SUMMARY`) |
| 3 | GQL Mutation (EXTEND) | `Pss2.0_Frontend/src/infrastructure/gql-mutations/contact-mutations/PrayerRequestReplyMutation.ts` | **MODIFIED** (add `APPROVE_PRAYER_REQUEST_REPLY`, `REJECT_PRAYER_REQUEST_REPLY`, `RECALL_REPLY_TO_DRAFTER`) |
| 4 | Tab content barrel | `Pss2.0_Frontend/src/presentation/components/page-components/contact-service/prayerrequests/tabs/reviewreplies/index.tsx` | **NEW** (default export `ReviewRepliesTabContent`) |
| 5 | Tab index-page (grid mode) | `Pss2.0_Frontend/src/presentation/components/page-components/contact-service/prayerrequests/tabs/reviewreplies/index-page.tsx` | **NEW** (Review Queue grid + 4 KPI widgets + drill-into-history mode) |
| 6 | Tab view-page (review + read) | `Pss2.0_Frontend/src/presentation/components/page-components/contact-service/prayerrequests/tabs/reviewreplies/view-page.tsx` | **NEW** (~700-900 LoC — side-by-side layout + RHF editable reply card + Reject modal + Recall popover) |
| 7 | Tab Zustand store | `Pss2.0_Frontend/src/presentation/components/page-components/contact-service/prayerrequests/tabs/reviewreplies/review-replies-store.ts` | **NEW** |
| 8 | Tab presentation pages registration | `Pss2.0_Frontend/src/presentation/pages/contact-service/prayerrequests/review-replies-tab.tsx` | **NEW** |
| 9 | Workspace shell (EXTEND — different line than #137) | `Pss2.0_Frontend/src/presentation/components/page-components/contact-service/prayerrequests/prayerrequests-workspace.tsx` | **MODIFIED** (line ~218 — replace `<TabComingSoon label="Review Replies" releaseTarget="#138" />` with `<ReviewRepliesTabContent />`) |

### Frontend Wiring Updates

| # | File to Modify | What to Add |
|---|---------------|-------------|
| 1 | `Pss2.0_Frontend/src/application/configs/data-table-configs/contact-service-entity-operations.ts` | Add new registry block with `gridCode: "PRAYERREQUEST_REVIEWREPLIES"` mapping the relevant operations (getAll: GET_REVIEW_QUEUE_LIST, getById: reuse GET_PRAYER_REQUEST_REPLY_BY_ID from #137; create: not applicable; update: reuse UPDATE_PRAYER_REQUEST_REPLY; delete: not applicable — Approve/Reject are non-standard) |
| 2 | `Pss2.0_Frontend/src/domain/entities/contact-service/index.ts` (barrel) | Re-export new types from PrayerRequestReplyDto extension |
| 3 | `Pss2.0_Frontend/src/infrastructure/gql-queries/contact-queries/index.ts` (barrel) | Re-export new Queries |
| 4 | `Pss2.0_Frontend/src/infrastructure/gql-mutations/contact-mutations/index.ts` (barrel) | Re-export new Mutations |

> Note: `useAccessCapability` does NOT need additional extension — #137 already adds `canReplyApprove` as a named flag. #138 just consumes it.

### DB Seed

| # | File | Notes |
|---|------|-------|
| 1 | (optional) `Pss2.0_Backend/.../sql-scripts-dyanmic/PrayerRequestReplies-sqlscripts.sql` | **MODIFIED** if extending #137's seed — append 1-2 sample post-decision rows (1 Approved, 1 Rejected) for grid history-mode verification. NO menu/capability/role-capability changes (already seeded by #136). Easiest path: defer to verification step — manually approve/reject the SubmittedForReview row seeded by #137 to create the post-decision sample. |

---

## ⑨ Pre-Filled Approval Config

> **Consumer**: User Approval phase — pre-filled by /plan-screens.
> **TAB_CONTENT scope**: NO new menu, NO new capability, NO new role-capability INSERT. No EF migration.

```
---CONFIG-START---
Scope: TAB_CONTENT (extends existing PRAYERREQUESTS menu — no new menu insert; no new entity; no new migration)
ExtendsMenu: PRAYERREQUESTS  (already seeded by #136 — MenuId resolved at runtime)
ParentMenu: CRM_PRAYERREQUEST
Module: CRM
WorkspaceTabKey: reviewreplies
CapabilityGate: REPLY_APPROVE  (already seeded by #136 — granted to BUSINESSADMIN by default)

GridType: FLOW (within tab)
GridCode: PRAYERREQUEST_REVIEWREPLIES  (used by entity-operations registry; NOT a menu code)
GridFormSchema: SKIP

ExtendsEntity: PrayerRequestReply  (introduced by #137 — this build adds 3 new mutations + 2 new queries on the existing entity)

DBSeedActions:
  - NO Menu INSERT
  - NO MenuCapability INSERT
  - NO RoleCapability INSERT
  - NO new entity / table / column
  - NO new EF migration
  - (Optional) Append 2 post-decision sample rows for grid history-mode verification — or defer to manual E2E
---CONFIG-END---
```

---

## ⑩ Expected BE→FE Contract

> **Consumer**: Frontend Developer

**GraphQL Types (extend existing endpoints from #137):**
- Query type: `PrayerRequestReplyQueries` (existing — add 2 new fields)
- Mutation type: `PrayerRequestReplyMutations` (existing — add 3 new fields)

**New Queries:**

| GQL Field | Returns | Key Args |
|-----------|---------|----------|
| `getReviewQueueList` | `GridFeatureResult<ReviewQueueRowDto>` | `request: GridFeatureRequest, statuses: [String!] = ["SubmittedForReview"], channels: [String!], drafterContactIds: [Int!], categoryCodes: [String!], dateFrom: DateTime, dateTo: DateTime` |
| `getReviewQueueSummary` | `ReviewQueueSummaryDto` | (none — tenant from HttpContext; KPI uses fixed "Today" range) |

> `getReviewQueueList` defaults `statuses` to `["SubmittedForReview"]` for the supervisor queue view. Setting `statuses: ["Approved"]` or `["Rejected"]` puts the grid in history mode (used by the KPI drill-throughs).

**New Mutations:**

| GQL Field | Input | Returns |
|-----------|-------|---------|
| `approvePrayerRequestReply` | `ApprovePrayerRequestReplyRequestDto` | `Int` (rows affected — `1` on success, `0` on stale concurrency) |
| `rejectPrayerRequestReply` | `RejectPrayerRequestReplyRequestDto` | `Int` |
| `recallPrayerRequestReplyToDrafter` | `RecallToDrafterRequestDto` | `Int` |

**Reused (from #137 — no change):**
- `getPrayerRequestReplyById(prayerRequestReplyId: Int!)` → `PrayerRequestReplyResponseDto` — used by REVIEW + READ layouts

**Request DTO Fields — `ApprovePrayerRequestReplyRequestDto`:**

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| prayerRequestReplyId | number | YES | PK |
| reviewerNote | string\|null | NO | Optional approval comment; max 1000 |
| editedReplyBody | string\|null | NO | If set: replaces existing replyBody; min 5, max 8000 |
| editedReplySubject | string\|null | NO | If set: replaces existing subject; channel-conditional |
| editedRecipientEmailOverride | string\|null | NO | channel-conditional |
| editedRecipientPhoneOverride | string\|null | NO | channel-conditional |
| editedInternalNote | string\|null | NO | If set: server APPENDS to existing internalNote with separator |

> CompanyId, ReviewedByContactId, ReviewedAt, LastUpdatedByContactId, LastUpdatedAt are SERVER-STAMPED.

**Request DTO Fields — `RejectPrayerRequestReplyRequestDto`:**

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| prayerRequestReplyId | number | YES | PK |
| reviewerNote | string | **YES** | Min 5, max 1000 — rejection reason; visible to drafter |

**Request DTO Fields — `RecallToDrafterRequestDto`:**

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| prayerRequestReplyId | number | YES | PK |
| reviewerNote | string\|null | NO | Optional explanation; max 1000 |

**Response DTO Fields — `ReviewQueueRowDto`** (grid row — denormalized for UI):

| Field | Type | Source |
|-------|------|--------|
| prayerRequestReplyId | number | PK (anchored on reply, not prayer) |
| prayerRequestId | number | FK |
| prayerSubmitterName | string | composite from prayer |
| prayerCategoryCode | string | prayer |
| prayerCategoryName | string | resolved via MasterData |
| prayerCategoryEmoji | string | resolved via MasterData |
| prayerBodyExcerpt | string | first 60 chars |
| prayerIsAnonymous | boolean | prayer |
| replyChannel | string | reply |
| replyBodyExcerpt | string | first 60 chars |
| replySubject | string\|null | reply |
| recipientResolved | string | derived: override OR LinkedContact.PrimaryEmail/Phone OR Prayer.SubmitterEmail/Phone |
| draftedByContactId | number | reply |
| draftedByContactName | string | resolved |
| draftedAt | string (ISO) | reply |
| submittedForReviewAt | string (ISO) | reply (sort key — ASC default) |
| hasInternalNote | boolean | derived: `internalNote != null` |
| status | string | reply (always "SubmittedForReview" in default view; varies in history mode) |
| reviewedByContactName | string\|null | resolved (only non-null in history mode) |
| reviewedAt | string (ISO)\|null | only non-null in history mode |

**Response DTO Fields — `ReviewQueueSummaryDto`:**

| Field | Type | Description |
|-------|------|-------------|
| pendingReviewCount | number | Status=SubmittedForReview |
| approvedTodayCount | number | Status=Approved AND ReviewedAt is today (tenant timezone) |
| approvedAllTimeCount | number | Status=Approved |
| rejectedTodayCount | number | Status=Rejected AND ReviewedAt is today |
| rejectedAllTimeCount | number | Status=Rejected |
| avgTimeToApproveMinutes | number\|null | `AVG(ReviewedAt - SubmittedForReviewAt)` over last 30 days, in minutes; null if no approvals yet |
| oldestPendingMinutes | number\|null | `now - MIN(SubmittedForReviewAt) WHERE Status=SubmittedForReview` — used for SLA alert color (red if > 24h) |

---

## ⑪ Acceptance Criteria

**Build Verification:**
- [ ] `dotnet build` — no errors
- [ ] `dotnet ef migrations list` — last migration is `Add_PrayerRequestReplies_Table` from #137; no new pending migration from this build (entity unchanged)
- [ ] `pnpm dev` — workspace loads at `/{lang}/crm/prayerrequest/prayerrequests`

**Functional Verification (Full E2E — MANDATORY):**

*Grid (Tab 3 active, default Pending mode):*
- [ ] Tab 3 chip "Review Replies" is enabled when user has REPLY_APPROVE (real flag — depends on #137 ISSUE-8 closure being live)
- [ ] Clicking Tab 3 → URL `?tab=reviewreplies` → grid loads listing only Status=SubmittedForReview rows
- [ ] 4 KPI widgets render with correct counts
- [ ] Default sort is `submittedForReviewAt ASC` (oldest first / FIFO)
- [ ] Grid columns render in correct order
- [ ] Channel filter (multi-select) works
- [ ] Drafter filter (multi-select staff picker) works
- [ ] Category filter (multi-select PRAYERCATEGORY) works
- [ ] Date range filter on `submittedForReviewAt` works
- [ ] Search by drafter/body/category works
- [ ] Row click → `?tab=reviewreplies&mode=review&id=R`

*Grid (history mode — clicking KPI 2 or 3):*
- [ ] Click "Approved Today" KPI → grid filter switches → only Status=Approved + ReviewedAt today rows
- [ ] "Reset to Pending" pill chip appears in filter bar
- [ ] Clicking the pill returns to default Pending mode
- [ ] Click "Rejected Today" KPI → same flow for Rejected
- [ ] In history mode, the "Review" action is replaced with "View" (mode=read)

*REVIEW mode:*
- [ ] URL `?tab=reviewreplies&mode=review&id=R` → side-by-side layout loads
- [ ] Left column shows Prayer Context (Card 1) + Drafter's Internal Note (Card 2)
- [ ] Right column shows Editable Reply (Card 3) + Reviewer Note (Card 4)
- [ ] Channel chip is read-only (cannot switch channel during review)
- [ ] ReplyBody pre-fills from existing reply; editable
- [ ] ReplySubject visible only if Channel=EMAIL
- [ ] Recipient override fields visible per channel
- [ ] InternalNote textarea (reviewer's additions) is empty by default
- [ ] ReviewerNote textarea empty by default
- [ ] Char counter on ReplyBody: amber at 7500, red at 8000
- [ ] Approve button label: "Approve" if no field touched; "Edit & Approve" if any field dirty
- [ ] Click "Approve" (no edits) → POST → Status=Approved → URL → `mode=read` → READ layout loads with green badge
- [ ] Click "Edit & Approve" (after touching ReplyBody) → POST with `editedReplyBody` → Status=Approved + LastUpdatedBy stamped → URL → READ
- [ ] Click "Reject" → modal opens
- [ ] In Reject modal: empty ReviewerNote → Confirm button disabled
- [ ] Type 5+ chars → Confirm enables → Click Confirm → POST → Status=Rejected → URL → READ with red badge + red ReviewerNote callout
- [ ] Click "Send back to drafter" → popover opens
- [ ] Confirm with no note → POST `RecallPrayerRequestReplyToDrafter` → Status=Draft → redirect to grid → row no longer in Tab 3
- [ ] Unsaved-changes dialog fires if dirty form + back nav

*READ mode (post-decision):*
- [ ] URL `?tab=reviewreplies&mode=read&id=R` → 2-column read-only layout
- [ ] Status badge color matches state (Approved=green / Rejected=red / Recalled-to-Draft=gray / Sent=blue)
- [ ] ReviewerNote callout rendered if non-null (color-tinted by status)
- [ ] Card 5 Audit Trail timeline renders with all 4 events: Drafted / Submitted / Reviewed / (no Sent yet)
- [ ] No action bar
- [ ] Header shows "Reviewed by {Name} on {Date}"

*Workflow:*
- [ ] Approve on non-SubmittedForReview reply (e.g., re-approve an Approved one) → server returns 409 conflict with friendly message
- [ ] Reject with empty/short reviewerNote → server returns 422 validation error
- [ ] Approve with `editedReplySubject` on non-EMAIL channel → server returns 422 (channel-specific validation)
- [ ] Approve with `editedRecipientPhoneOverride` on EMAIL channel → server returns 422
- [ ] Concurrency: two simultaneous reviewer sessions both fetch reply R → first session approves → second session's approve fails with 409 → FE toast: "This reply was already reviewed — refresh to see the latest state"
- [ ] Server-stamped fields are never overwritten by request body
- [ ] Edit-during-approve preserves drafter's InternalNote (server appends with separator, doesn't overwrite)

*Round-trip with #137:*
- [ ] In Tab 2 #137, drafter submits → row visible in Tab 3
- [ ] Reviewer rejects with note → row gone from Tab 3 → drafter opens Tab 2 → reply is back in Draft → DETAIL view shows red ReviewerNote callout
- [ ] Drafter edits + resubmits → row reappears in Tab 3 (fresh SubmittedForReviewAt timestamp)
- [ ] Reviewer recalls (no rejection) → row gone from Tab 3 → drafter sees the reply in Tab 2 Draft with gray-tinted Recall note (or empty if no note provided)

*Permissions:*
- [ ] User WITHOUT REPLY_APPROVE → Tab 3 chip disabled with tooltip
- [ ] User WITH REPLY_DRAFT (drafter) but NO REPLY_APPROVE → Tab 3 disabled; Tab 2 enabled
- [ ] User WITH BOTH REPLY_DRAFT + REPLY_APPROVE → both tabs enabled (typical for senior pastors)
- [ ] Cross-tenant isolation: tenant A reviewer cannot see/Approve tenant B's replies

*UI Uniformity (post-build greps — should return ZERO matches):*
- [ ] No inline hex colors
- [ ] No inline pixel padding/margins
- [ ] No raw "Loading..." text (use Skeleton)
- [ ] All useQuery surfaces have Skeleton placeholders
- [ ] All sibling cards same padding

*DB Seed:*
- [ ] No new menu/capability/role-capability inserts
- [ ] (Optional) 2 post-decision sample rows seeded — verifies grid history mode

---

## ⑫ Special Notes & Warnings

> **Consumer**: All agents — things that are easy to get wrong.

- **HARD DEPENDENCY ON #137** — abort build if #137 is not COMPLETED. The entity table, EF config, EF migration, GetById query, and Mutations endpoint MUST exist before #138 codegen.
- **TAB_CONTENT scope** — NO new menu, NO new route, NO new sidebar entry. Files live under `presentation/components/page-components/.../prayerrequests/tabs/reviewreplies/`.
- **Workspace shell modification is REQUIRED** — same file as #137 but DIFFERENT line. #137 edits line ~216 (Tab 2 slot); #138 edits line ~218 (Tab 3 slot — currently `<TabComingSoon label="Review Replies" releaseTarget="#138" />`). MUST change to `<ReviewRepliesTabContent />` (import added).
- **NO new entity, NO new migration** — verify with `dotnet ef migrations list`; the most recent migration after #138 codegen must still be `Add_PrayerRequestReplies_Table` (from #137).
- **3 distinct mutations, 3 distinct outcomes** — do NOT collapse Approve/Reject/Recall into a single "decide" mutation. The state transitions, required fields, and audit semantics differ enough that one-handler-per-action is the right call. Solution Resolver should NOT propose a unified handler.
- **Approve with edits → server APPLIES edits BEFORE flipping status** — order matters. If validation on `editedReplyBody` fails (e.g., empty after HTML-strip), the approve must roll back entirely, NOT half-apply.
- **InternalNote append-not-overwrite** — when reviewer sets `editedInternalNote`, server must APPEND to existing InternalNote with a separator (e.g., `"original\n---\nReviewer (John Smith, 2026-05-13): added Bible reference"`); never silently overwrite the drafter's original. Test: `editedInternalNote = "x"` AND existing `InternalNote = "original"` → final = `"original\n---\nReviewer ({Name}, {Date}): x"`.
- **Concurrency guard uses WHERE-status-clause** — not rowversion. EF migration didn't add a rowversion column, so use the existing Status column as a poor-man's concurrency token. Pattern: `dbContext.PrayerRequestReplies.Where(r => r.Id == X && r.Status == "SubmittedForReview").ExecuteUpdate(...)`. If `ExecuteUpdate` returns 0, throw 409 conflict.
- **ReviewedByContactId on Recall** — yes, we record that a reviewer touched the reply even when recalling-to-drafter. This is intentional — supervisor audit trail wants to know who sent it back, not just who Approved/Rejected.
- **History mode toggle is UI-only** — the same GQL query (`getReviewQueueList`) serves both Pending and history modes; the difference is the `statuses` array argument. No new endpoint needed.
- **Bulk approve is OPTIONAL** — if token-pressured, defer it to a follow-up ISSUE. The MVP supports per-row Approve only. Document this in the build log.
- **Sample data approach for E2E** — the simplest path is to manually drive through #137's flow (submit a Draft → use Tab 3 to Approve/Reject) rather than seed post-decision rows directly. This naturally exercises round-trip wiring.
- **Layout Variant B continues** — workspace `<ScreenHeader>` is already rendered ONCE by #136; #137 + #138 each pass `showHeader={false}` to their grid container. Post-build grep check: no second `<ScreenHeader>` import in #138 files.

**Service Dependencies** (UI-only — no backend service implementation):

- ⚠ **SERVICE_PLACEHOLDER: notification to drafter on Reject** — when a supervisor rejects, we do NOT email/notify the drafter. The drafter discovers via their next visit to Tab 2 (the reply is back in Draft with the red ReviewerNote callout). Future scope: integrate with the in-app notification bell + email digest.
- ⚠ **SERVICE_PLACEHOLDER: outbound send after Approve** — Approved replies enter a "pending send" holding state. The READ view shows "Approved — pending send" instead of a "Send Now" button. The Send-Service is future scope (consumes Approved replies and dispatches via transport).
- ⚠ **SERVICE_PLACEHOLDER: bulk approve audit chain** — if bulk approve is built, audit log entries should be batched per-row but the user-facing UI can show a single progress toast.
- **Full UI is built** — all 4 KPI widgets, full grid + filters + history-mode drill-through, full REVIEW layout (side-by-side + Reject modal + Recall popover), full READ layout (status badge + audit timeline + ReviewerNote callout). Only the genuine external-service calls (notifications, transport, batch processing) are deferred.

---

## ⑬ Build Log (append-only)

> **Writer**: `/build-screen` on every BUILD session, `/continue-screen` on every FIX/ENHANCE session.
> **Reader**: `/continue-screen` (to rehydrate context in a new session).
> See `_COMMON.md` § Section ⑬ for full format.

### § Known Issues

| ID | Raised (session) | Severity | Area | Description | Status |
|----|------------------|----------|------|-------------|--------|
| ISSUE-1 | Planning (#138 plan, 2026-05-12) | Low | Spec | No HTML mockup; spec authored from PSS 2.0 pastoral-care domain knowledge — UX Architect agent may refine visual treatment without changing semantics | OPEN (intentional — same approach as #136 + #137) |
| ISSUE-DEP-137 | Planning | High | Dependency | Cannot build until #137 is COMPLETED (entity table + Submit handler + GetById query + Mutations endpoint must exist) | CLOSED (Session 1, 2026-05-12 — #137 code verified present in codebase: entity, EF config, schemas, mutations, queries, FE DTO + GQL files all exist; registry-status flag was stale but artifacts shipped) |
| ISSUE-BULK | Planning | Low | UX | Bulk approve from grid not in MVP scope; defer if token-pressured | OPTIONAL — flag in build log if deferred |
| ISSUE-CONC | Planning | Medium | Backend | Optimistic concurrency uses WHERE-status-clause (no rowversion column) — works but less robust than a rowversion. Acceptable for v1; consider rowversion in a future schema rev | INTENTIONAL — documented |
| ISSUE-CONC-IMPL | Session 1 (2026-05-12) | Low | Backend | Spec §⑫ called for `ExecuteUpdateAsync(...).Where(r => r.Status == "SubmittedForReview")` pattern as the concurrency guard. BE Developer agent shipped a load-then-check-Status-then-SaveChanges pattern instead (Approve/Reject/Recall all 3 handlers). Functionally equivalent for non-concurrent traffic; small race window exists between Load and SaveChanges. Approve handler had a legitimate reason to use load-modify-save (conditional InternalNote append + edits applied BEFORE status flip — ExecuteUpdate can't easily express that). Reject/Recall could have used ExecuteUpdate. Acceptable for v1 supervisor traffic (concurrent reviews on same row are rare); revisit if SLA matters | OPEN (deviation — works correctly but spec asked for stronger guard) |
| ISSUE-PERF-LIST | Session 1 (2026-05-12) | Low | Backend | `GetReviewQueueListHandler` calls `.ToListAsync()` on the filtered query and does projection + sort + pagination in-memory. For tenants with thousands of pending replies this is inefficient. Acceptable for v1 (Tab 3 backlog is typically <50 rows per supervisor); refactor to push projection + sort + Skip/Take into SQL if scale grows | OPEN (perf debt — acceptable for v1) |
| ISSUE-FE-PENDING | Session 1 (2026-05-12) | High | Frontend | FE Developer agent (Opus) stalled at 31 min / 53 tool uses with stream-idle timeout and ZERO files written. All 14 FE files (6 NEW + 5 modified + 3 barrels) remain to be generated. Resume via `/continue-screen #138` in a fresh session with a tighter, write-first directive | CLOSED (Session 2, 2026-05-12 — all FE files generated inline by main orchestrator. DTO + GQL files were already extended during Session 1's BE-extension salvage; 5 NEW tab files + 1 NEW presentation-pages file written; workspace shell wired; entity-operations + barrels verified) |
| ISSUE-GRID-CONFIG | Session 2 (2026-05-12) | Low | Frontend | FlowDataTable loads column metadata from server via `GET_FLOW_GRID_CONFIG(gridCode)` — no DB row seeded for `PRAYERREQUEST_REVIEWREPLIES` (per spec §⑨ GridFormSchema: SKIP). Grid will render the toolbar/pagination chrome but rows may not appear until a Grid registry row is inserted server-side. Same situation as #137 `PRAYERREQUEST_REPLYQUEUE`. Acceptable for v1 — falls within the existing tab-content seeding convention. | OPEN (intentional, mirrors #137 convention) |
| ISSUE-PERMISSION-ACTIONS | Session 2 (2026-05-12) | Low | Frontend | READ view does not currently surface alternate action affordances for the drafter (e.g., "Resubmit" from a Rejected reply). Drafter accesses post-decision detail via Tab 2 #137 detail view instead. Spec §⑥ Layout 2 implies post-decision actions all live in Tab 2 — acceptable as designed. | OPEN (matches spec intent) |
| ISSUE-ACTION-FLAG-GRANULARITY | Session 2 (2026-05-12) | Low | Frontend | Modal/popover buttons (Reject Confirm / Recall Confirm) use a single combined `isActionInFlight` boolean instead of distinct `approving/rejecting/recalling` flags. Modal-title context already makes the active operation unambiguous to users. Possible micro-UX polish: split into 3 props if a future review wants per-action loading text precision. | OPEN (cosmetic) |

### § Sessions

<!-- Each session appends one entry below. Oldest first, newest last. DO NOT edit prior entries. -->

### Session 1 — 2026-05-12 — BUILD — PARTIAL

- **Scope**: Initial full build from PROMPT_READY prompt. Aborted FE phase mid-way; BE phase completed.
- **Files touched**:
  - BE: 8 files all shipped (`dotnet build` clean, 0 errors):
    - `Pss2.0_Backend/.../Business/ContactBusiness/PrayerRequestReplies/ApproveCommand/ApprovePrayerRequestReply.cs` (created — 197 LoC, by BE agent)
    - `Pss2.0_Backend/.../PrayerRequestReplies/RejectCommand/RejectPrayerRequestReply.cs` (created — 86 LoC)
    - `Pss2.0_Backend/.../PrayerRequestReplies/RecallToDrafterCommand/RecallPrayerRequestReplyToDrafter.cs` (created — 91 LoC)
    - `Pss2.0_Backend/.../PrayerRequestReplies/GetReviewQueueQuery/GetReviewQueueList.cs` (created — 225 LoC)
    - `Pss2.0_Backend/.../PrayerRequestReplies/GetReviewSummaryQuery/GetReviewQueueSummary.cs` (created — 118 LoC)
    - `Pss2.0_Backend/.../Schemas/ContactSchemas/PrayerRequestReplySchemas.cs` (modified — 5 DTOs appended: Approve/Reject/Recall request + ReviewQueueRow + ReviewQueueSummary; lines 224-414)
    - `Pss2.0_Backend/.../Base.API/EndPoints/Contact/Mutations/PrayerRequestReplyMutations.cs` (modified — 3 mutation methods appended, by main orchestrator after BE agent stall)
    - `Pss2.0_Backend/.../Base.API/EndPoints/Contact/Queries/PrayerRequestReplyQueries.cs` (modified — 2 query methods appended, by main orchestrator after BE agent stall)
  - FE: 0 files (FE agent stalled before writing anything)
  - DB: none (per spec — DEFERRED, no menu/cap/role-cap inserts; E2E via #137 round-trip)
- **Deviations from spec**:
  - Concurrency guard: load-then-check-status-then-SaveChanges pattern used instead of the spec §⑫ `ExecuteUpdateAsync(...).Where(Status==SubmittedForReview)` pattern (see ISSUE-CONC-IMPL). Acceptable for v1 supervisor traffic.
  - `GetReviewQueueList` does in-memory pagination/sort after `.ToListAsync()` (see ISSUE-PERF-LIST). Acceptable for v1 scale.
  - Schemas append placed the #138 DTOs in the same file rather than a separate file — matches the spec's append-to-end directive and the existing #137 pattern.
- **Known issues opened**: ISSUE-CONC-IMPL (Low), ISSUE-PERF-LIST (Low), ISSUE-FE-PENDING (High — blocks completion)
- **Known issues closed**: ISSUE-DEP-137 (verified #137 code present in codebase)
- **Next step**: Resume FE phase in a fresh session via `/continue-screen #138`. Specifically generate:
  - 6 NEW files: `tabs/reviewreplies/index.tsx`, `index-page.tsx` (grid + 4 KPI widgets + history-mode), `view-page.tsx` (REVIEW layout side-by-side + RHF editable reply + Reject modal + Recall popover + READ layout with audit timeline — ~700-900 LoC), `review-replies-store.ts` (Zustand), `presentation/pages/.../prayerrequests/review-replies-tab.tsx`, and optionally an `audit-trail-timeline.tsx` if no existing component fits
  - 5 modified files: `PrayerRequestReplyDto.ts` (append 5 DTOs to mirror BE), `PrayerRequestReplyQuery.ts` (append `GET_REVIEW_QUEUE_LIST` + `GET_REVIEW_QUEUE_SUMMARY` — remember `[String!]` / `[Int!]` for list args), `PrayerRequestReplyMutation.ts` (append 3 mutations), `prayerrequests-workspace.tsx` line 223-224 (swap `<TabComingSoon>` for `<ReviewRepliesTabContent />` + import), `contact-service-entity-operations.ts` (append `PRAYERREQUEST_REVIEWREPLIES` registry block)
  - 3 barrel re-exports: `domain/entities/contact-service/index.ts`, `gql-queries/contact-queries/index.ts`, `gql-mutations/contact-mutations/index.ts`
  - Then run UI uniformity greps + `pnpm dev` E2E test + check off Verification section + flip status → COMPLETED.
  - **Mitigation note for next session**: FE agent stalled at 31 min with very long prompt. Use shorter, more directive prompt; write files first then validate; or implement inline if agent stalls again.

### Session 2 — 2026-05-12 — BUILD — COMPLETED

- **Scope**: Resume FE phase blocked by ISSUE-FE-PENDING. Wrote all remaining FE files inline (no agent spawn — applied memory `feedback_long_agent_prompts_stall.md` mitigation directly).
- **Files touched**:
  - FE (NEW — 5):
    - `Pss2.0_Frontend/src/presentation/components/page-components/contact-service/prayerrequests/tabs/reviewreplies/review-replies-store.ts` (62 LoC — Zustand store: historyMode toggle + filter chips)
    - `tabs/reviewreplies/index-page.tsx` (216 LoC — grid + 4 KPI widgets w/ SLA color cue + history-mode chip + Reset-to-Pending button)
    - `tabs/reviewreplies/view-page.tsx` (~1300 LoC — REVIEW layout 2-col side-by-side w/ editable RHF reply card + Reviewer-note card + sticky action bar w/ "Edit & Approve" dirty-state label switch + Reject modal w/ min-5-char validation + Recall popover w/ optional note + back-nav guard + READ layout w/ audit timeline + reviewer-note callout tinted by status)
    - `tabs/reviewreplies/index.tsx` (40 LoC — tab content router, mirrors #137 pattern)
    - `Pss2.0_Frontend/src/presentation/pages/contact-service/prayerrequests/review-replies-tab.tsx` (11 LoC — pages-layer re-export, mirrors #137)
  - FE (MODIFIED — 1):
    - `prayerrequests-workspace.tsx` — replaced `<TabComingSoon>` slot at line ~218 with `<ReviewRepliesTabContent />`; added import; removed now-unused `TabComingSoon` import
  - FE (verified already extended during Session 1 BE salvage — no re-edit needed):
    - `PrayerRequestReplyDto.ts` — 5 #138 DTOs already appended (lines 209-322)
    - `PrayerRequestReplyQuery.ts` — `GET_REVIEW_QUEUE_LIST` + `GET_REVIEW_QUEUE_SUMMARY` already appended (lines 195-313)
    - `PrayerRequestReplyMutation.ts` — `APPROVE_PRAYER_REQUEST_REPLY` + `REJECT_PRAYER_REQUEST_REPLY` + `RECALL_REPLY_TO_DRAFTER` already appended (lines 137-230)
    - `contact-service-entity-operations.ts` — `PRAYERREQUEST_REVIEWREPLIES` registry block already wired (lines 903-945)
    - 3 barrels (`domain/entities/contact-service/index.ts`, `gql-queries/contact-queries/index.ts`, `gql-mutations/contact-mutations/index.ts`) — all use `export *` so #138 DTOs/queries/mutations are auto-re-exported
- **Deviations from spec**:
  - REVIEW layout's "ReviewerNote" card kept as a flat textarea inside the right column (not promoted to its own Card 4 with distinct styling) — matches the spec semantics and saves vertical space; the modal/popover still enforce the per-action note rules.
  - Modal/popover buttons use a single `isActionInFlight` flag instead of distinct `approving/rejecting/recalling` flags — see ISSUE-ACTION-FLAG-GRANULARITY (cosmetic).
  - No separate `audit-trail-timeline.tsx` extracted — inlined `AuditTimeline` sub-component into `view-page.tsx` using the same `TimelineDot`/`TimelineEventKind` exports as #137 (re-imported from `../replyqueue/reply-status-badge`).
- **Verification**:
  - Anti-pattern grep on the 4 NEW reviewreplies files — zero inline hex (#RRGGBB) and zero raw `[Npx]` arbitrary-value matches; the only matches were `text-[11px]` (accepted tiny-text helper, used 9 times in #137's view-page.tsx as well) and `#137`/`#138` issue references in comments.
  - `npx tsc --noEmit` from `PSS_2.0_Frontend/` reports 3 total errors — ALL pre-existing in unrelated files (`donation-service/index.ts` PageLayoutOption ambiguity, `EmailConfiguration.tsx` SaveFilterParams signature, `RecipientFilterDialog.tsx` SaveFilterParams signature). Zero errors in `tabs/reviewreplies/*` or `review-replies-tab.tsx`. Clean compile for #138 surface.
  - `pnpm dev` E2E test NOT run this session — user to verify locally; expected flows are documented in the Tasks Verification section above (40+ acceptance criteria).
- **Known issues opened**: ISSUE-GRID-CONFIG (Low — DB-side grid registry row for `PRAYERREQUEST_REVIEWREPLIES` deferred per spec §⑨), ISSUE-PERMISSION-ACTIONS (Low — drafter resubmit action lives in #137 by design), ISSUE-ACTION-FLAG-GRANULARITY (Low — cosmetic)
- **Known issues closed**: ISSUE-FE-PENDING (High — was blocking screen completion)
- **Next step**: Empty — screen COMPLETED. User to run `pnpm dev` and exercise the 40+ acceptance criteria; if any flow breaks, open via `/continue-screen #138 "<issue>"`.

### Session 2 — 2026-05-12 — UI — COMPLETED

- **Scope**: Tab 3 KPI widget sizing — first card ("Pending Review") was wrapped in an extra `<div>` for the SLA-alert ring, which broke grid-cell uniformity (cards 2-4 were direct grid children). Refactored shared `<SummaryCard>` to accept an optional `className` passthrough on the root `<button>`, then dropped the wrapping div on Tab 3.
- **Files touched**:
  - FE (2 modified):
    - `src/presentation/components/custom-components/summary-card/index.tsx` — added optional `className?: string` prop, merged into the root button's `cn(...)`; comments updated to note 4-consumer count (Tab 1, Tab 2, Tab 3, future).
    - `src/presentation/components/page-components/contact-service/prayerrequests/tabs/reviewreplies/index-page.tsx` — removed the `<div className={cn("rounded-xl", slaAlert && "ring-2 ring-red-200")}>` wrapper around the "Pending Review" `<SummaryCard>`; replaced it with `className={cn(slaAlert && "ring-2 ring-red-200")}` directly on the card. All 4 cards are now direct grid children.
- **Deviations from spec**: None. SLA-alert semantics preserved (red ring + red icon tile when `oldestPendingMinutes > 1440`). Visual treatment identical from user's POV; only the layout structure changed.
- **Known issues opened**: None.
- **Known issues closed**: None.
- **Validation results**:
  - No BE changes — no rebuild needed for this fix (BE was rebuilt in the parallel #137 fix this same session).
  - Visual verification deferred to user; expected outcome: all 4 KPI cards equal-width within the grid row at every breakpoint.
- **Next step**: User runs `pnpm dev`, opens `/{lang}/crm/prayerrequest/prayerrequests?tab=reviewreplies`, confirms the 4 KPI cards are uniformly sized and the SLA red ring still appears on the first card when `oldestPendingMinutes > 1440`.

---

> **Cross-session note**: This Session 2 was triggered by a workspace-wide bug report that also produced Session 2 entries on `prayerrequestentry.md` (#136) and `prayerrequestreplyqueue.md` (#137). Each entry lists only the files touched for its own screen scope. See those prompts for #136 / #137 detail.
