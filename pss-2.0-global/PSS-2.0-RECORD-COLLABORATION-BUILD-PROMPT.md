# PSS 2.0 — Record Collaboration (Comments · @Mentions · Activity) — Build Prompt

> Covers **T-8** from `PSS-2.0-PRODUCT-SHELL-FEATURE-EXPLORATION.md` §④ — the direct fix for **G-2**, *"nothing in the product is alive."*
> **Do not trust this header for status. Verify against disk.**

---

## ① Why this exists

| # | Defect | Evidence |
|---|--------|----------|
| **D-1** | **There is no comment, mention or discussion layer anywhere in the product.** `find PSS_2.0_Backend -path "*Models*" \( -iname "*Comment*" -o -iname "*Mention*" \)` returns exactly one file — `IntegrationModels/SocialMediaMention.cs`, which is social-media listening and unrelated. | verified on disk |
| **D-2** | Exactly **one** record type in the entire CRM supports notes, and it is bespoke. `case.CaseNotes` is welded to `CaseId`, `AuthorStaffId` and `NoteTypeId` — it cannot serve a donation, a contact, a grant or anything else. | `Base.Domain/Models/CaseModels/CaseNote.cs` |
| **D-3** | **The activity half already exists and is invisible on records.** `audit.AuditLogs` carries `EntityType`, `EntityId`, `UserDisplayName`, `UserEmail`, `UserRoleName`, `ActionType` and `Timestamp` — a complete per-record history, written for every CREATE/UPDATE/DELETE/APPROVE/SEND. Every detail page in the product could show "who changed what on this record" today and none of them do. | `Base.Domain/Models/ReportAuditModels/AuditLog.cs:6-60` |
| **D-4** | The audit read layer is **report-shaped, not record-shaped**. `AUDIT_TRAIL_REPORT_QUERY` filters by `$entityType` but takes **no `entityId` argument** — you can ask "all donation changes", never "this donation's changes". | `infrastructure/gql-queries/reportaudit-queries/AuditTrailQueries.ts:13,28` |
| **D-5** | Consequence: **a user cannot leave a trace on a record**, cannot ask a colleague a question about one, and cannot be told when someone needs them. Every record in the CRM is a dead form. This is the single biggest reason the product reads as a data-entry tool rather than a place a team works. | — |

**This is the third time in this programme we have found we already own the expensive half.** The platform audit data layer existed and only lacked an estate view (P-3). The automation canvas existed and was never demoed (T-15). Here the per-record history exists and is unreachable by record id. The build below adds the missing half and joins them.

---

## ② Rules this build must not break

1. **`case.CaseNotes` is not touched, not migrated, not superseded.** It has a working screen, a note type, a follow-up date and a supervisor flag — real business semantics the generic layer does not have. The new panel sits **beside** it on the Case screen, not instead of it. Migrating case notes is a separate decision with a separate prompt.
2. **Migrations are the user's.** Never run `dotnet ef migrations add` / `database update` / `remove`, never hand-author a migration or snapshot. Write entity + configuration + `DbSet`, prove it compiles, hand over the §⑨ spec. Do not run `dotnet build` either.
3. **These are tenant tables, so `CompanyId` is correct here** — the exact opposite of the `ops` rule. `TenantSaveChangesInterceptor` stamps it and the convention filter must attach. Do **not** copy the `ops.PlatformAuditLog` naming trick into `app` tables.
4. **No raw SQL in application code.** `ExecuteUpdateAsync`/`ExecuteDeleteAsync` over LINQ are EF and fine. Hand-written `.sql` under `sql-scripts-dyanmic/` that the user applies is the separate permitted channel — one script per file.
5. **Never render a comment body as HTML.** Bodies are user-authored plain text and are rendered as text with `whitespace-pre-wrap`. Mentions are resolved from a **stored id list**, never by re-parsing the body at render time. A comment layer is the most obvious stored-XSS surface in any CRM; this rule is the mitigation.
6. **A mention is an authorization decision, not a text match.** `@` autocomplete lists only users in the current tenant. On save, the server **re-validates** every mentioned user id against the current tenant and silently drops any that fail — never trust the client's id list.
7. **Deletes are soft and visible.** A deleted comment renders as a tombstone (*"Comment deleted by Priya R."*) rather than vanishing. A thread that silently loses messages is worse than one that shows a gap. Only the author or a user with the manage capability may delete.
8. **HotChocolate strips `Get` from every resolver** and appends `Input` to input types. `GetRecordActivity` → `recordActivity`; `RecordCommentCreateDto` → `RecordCommentCreateDtoInput`. `tsc` cannot see GraphQL field names — a wrong name compiles clean and fails at runtime only. Read the resolver.
9. **UTC only.** `timestamptz` everywhere, `DateTime.UtcNow`, never `DateTime.Today` in an EF predicate.
10. **House UI rules.** Solid `bg-X-600` + `text-white` for icon containers, status badges and chips — never `bg-X-50/100`, never `text-X-700/800`, never `bg-muted`/`text-muted-foreground` as a status, never `/10` tints. Tokens not hex/px. Shaped Skeletons. `@iconify` Phosphor icons. xs→xl responsive.
11. **Tenant accent.** Everything here is `(core)`. Paint from `brand-surface.ts` (`brandSolid`/`brandGradient`/`brandSoft`, reading `var(--shell-accent*)`). Anything painted `bg-primary-600` renders the static platform violet inside a tenant's page.
12. **Submit enablement is RHF `formState.isValid`**, never `canCreate`/`canUpdate`.
13. **RBAC seeds are additive.** `INSERT … SELECT … WHERE NOT EXISTS`; soft-delete only, never `DELETE FROM auth`; `ISMENURENDER` is never inserted, only granted; `SUPERADMIN` matched by `RoleCode` alone and never overwritten.
14. **Do not touch `app-topbar/index.tsx` or anything under `(master)/ops`.** The Support & Audit build owns both files right now. The topbar mention badge is deliberately deferred to §⑦ for this reason.

---

## ③ The mental model

> **A record's activity feed is one stream with two writers: the system writes what changed, people write why.**

Comments and audit rows are not two features that happen to sit near each other — they are the same timeline. `audit.AuditLogs` already answers *"the stage moved to Approved at 14:02"*; the comment layer adds *"approving early because the funder's deadline moved — Priya"*. Interleaved by timestamp, those two sentences are a record's story. Apart, they are noise and a suggestion box.

That framing is why this build ships **one** panel with three tabs over one merged query, not a Comments feature and an Activity feature.

---

## ④ Backend

### The merged read — `GetRecordActivity`

`Base.Application/Business/ApplicationBusiness/Collaboration/Queries/GetRecordActivity.cs`

Signature `GetRecordActivityQuery(string entityType, int entityId, string filter, GridFeatureRequest gridFilterRequest)` where `filter` ∈ `ALL` | `COMMENTS` | `CHANGES`.

- Two queries, materialised separately, merged in memory, sorted by timestamp **descending**, then paged. Do **not** attempt a SQL `UNION` across `app.RecordComments` and `audit.AuditLogs` — different shapes, different schemas, and the row counts here are per-record and small.
- Comments source: `app.RecordComments` where `EntityType == entityType && EntityId == entityId && IsDeleted != true`. Tenant filter attaches by convention — do not add `IgnoreQueryFilters()`.
- Changes source: `audit.AuditLogs` where `EntityType == entityType && EntityId == entityId`. Same convention filter.
- Both project into one `RecordActivityItemDto` with a discriminator `ItemKind` ∈ `COMMENT` | `CHANGE`.
- `filter == COMMENTS` skips the audit query entirely; `CHANGES` skips the comment query. Do not fetch and discard.
- Authorization: `[CustomAuthorize]` on the **owning module of the entity type**, not a new global capability. A user who cannot read donations must not read donation comments through this endpoint. Implement with a small server-side `entityType → (menuCode, capability)` map in one file; **an unknown `entityType` is rejected, never defaulted to allow.** This is the security-critical line of the build.

### `RecordActivityItemDto`

| Field | Notes |
|---|---|
| `itemKind` | `COMMENT` \| `CHANGE` |
| `timestamp` | UTC. The single sort key. |
| `actorUserId`, `actorName`, `actorRoleName` | Snapshots. Audit rows already store `UserDisplayName`/`UserRoleName`; comments store their own. |
| `body` | Comment text. Null on `CHANGE`. |
| `mentions` | `[{ userId, displayName }]`. Empty on `CHANGE`. |
| `parentCommentId` | One-level threading. Null = root. |
| `isEdited`, `isDeleted` | Comment only. `isDeleted` drives the tombstone. |
| `actionType` | `CREATE`/`UPDATE`/`APPROVE`/… Null on `COMMENT`. |
| `fieldChanges` | `[{ field, before, after }]` parsed from `AuditLog.ChangesJson`. **That is the on-disk shape — do not rename to `oldValue`/`newValue`.** The column is documented as *"For UPDATE actions: array [{field, before, after}] as JSON. Max 64KB."* Null/empty when unparseable — **never throw on bad JSON**. |
| `summary` | `AuditLog.Description` — already a human narrative (*"Updated amount from $200 to $500"*). Use it as the change item's one-line text rather than composing your own. Null on `COMMENT`. |
| `severity` | `AuditLog.Severity` (`LOW`/`MEDIUM`/`HIGH`/`CRITICAL`). Carry it through; the FE may tone a `CRITICAL` change differently. Null on `COMMENT`. |
| `recordCommentId`, `auditLogId` | Whichever applies. |

### Commands

- `CreateRecordComment` — validates `entityType` against the same map, body 1–4000 chars, re-validates mention ids against the tenant (rule 6), stores the surviving ids, snapshots author name, returns the created item. Then notifies via the **existing writer** — see §⑥, which now carries the exact call. Do not build a second notification path and do not write `notify.Notifications` rows directly.
- `UpdateRecordComment` — author only; sets `IsEdited = true`; mention list re-validated identically. Editing does not re-notify.
- `DeleteRecordComment` — soft delete; author, or manage-capability holder. Sets `IsDeleted`, preserves `AuthorUserName` for the tombstone.
- `MarkMentionRead` — flips `IsRead` on `app.RecordCommentMentions` for the current user.

### Queries

- `GetRecordActivity` (above).
- `GetMyMentions(bool unreadOnly, GridFeatureRequest)` — the current user's mentions across all records, newest first, each carrying `entityType`, `entityId`, a resolved record label and the comment excerpt. Feeds §⑤'s mentions page.

---

## ⑤ Frontend

### `<RecordCollaborationPanel entityType entityId />`

`presentation/components/custom-components/collaboration/record-collaboration-panel.tsx`

One self-contained component taking only those two props, so mounting it on a new record type is a one-line change. It fetches its own data and owns its own loading and error states.

**Header** — segmented tabs **All · Comments · Changes**, with a live count badge on Comments. Right side: a refresh icon button.

**Composer**, pinned at the top of the All and Comments tabs:

- Avatar of the current user, then a `Textarea` with placeholder *"Add a comment. Use @ to notify someone."*
- Auto-grows 2 → 8 rows, then scrolls.
- Typing `@` opens an inline autocomplete popover over tenant users — avatar, name, role. Arrow keys navigate, Enter/Tab selects, Escape closes. The inserted token renders as a solid `brandSolid` chip in the composer; the underlying value stored is the **user id**, not the text.
- `Ctrl/Cmd + Enter` submits. The **Comment** button is solid `brandSolid`, disabled until the body is non-empty, spinner while in flight.
- Optimistic append on submit, reconciled against the server response; on failure the item is rolled back and the body is restored to the composer — never lost.

**Feed**, newest first, interleaved by timestamp:

- **Comment item** — avatar, author name, role chip, relative time (absolute on hover), body with `whitespace-pre-wrap`, mention chips rendered solid `brandSoft` and linking to the mentioned user. Hover reveals **Reply · Edit · Delete** (Edit/Delete only for the author or a manage-capability holder). `(edited)` marker where applicable.
- **Reply** — one level only, indented with a left rule, replies always chronological under their parent. No infinite nesting.
- **Tombstone** — muted italic *"Comment deleted by {author}"* with a `ph:trash` icon in a solid `bg-slate-600` container. No body, no actions.
- **Change item** — visually distinct from comments: no avatar bubble, a small solid action-toned icon container instead (`CREATE` `bg-emerald-600` `ph:plus`, `UPDATE` `bg-blue-600` `ph:pencil-simple`, `DELETE` `bg-red-600` `ph:trash`, `APPROVE` `bg-emerald-600` `ph:check`, `SEND` `bg-violet-600` `ph:paper-plane-tilt`, default `bg-slate-600` `ph:dot`). One-line summary *"Priya R. changed Status"*, expandable to a `field · from → to` table. A change with no parseable field list shows the summary line alone.
- **Day separators** — *Today*, *Yesterday*, then absolute dates.
- **Empty state** — `ph:chat-centered-text` in a solid `bg-slate-600` container, **"No activity yet"**, sub-line *"Comments and changes on this record will appear here."*
- **Loading** — shaped Skeletons matching real item geometry (avatar circle + two text bars), not a spinner.
- **Paging** — a **Load older** button, not infinite scroll. Newest-first feeds and infinite scroll fight each other.

### Mounting

Mount on exactly these four records. **The treatment per record is decided — it was surveyed on disk 2026-08-12, do not re-survey and do not choose differently.** Only two of the four have a tab container; the other two take the bottom-section fallback rather than being restructured.

| Record | Host file | Treatment |
|---|---|---|
| **Case** | `crm/casemanagement/caselist/case/tabs/` | **New tab** named **Discussion**, added beside the existing `notes-tab.tsx`, which is untouched (rule 1). |
| **Contact** | `crm/contact/contact/detail/tabs/` | **New tab** named **Discussion**. `timeline-tab.tsx` is untouched — see the warning below. |
| **Grant** | `crm/grant/grantlist/grant/grant-detail.tsx` | **Bottom section.** `grep TabsTrigger` returns 0 — there is no tab container. Do not build one. |
| **Donation** | `crm/donation/globaldonation/view-page.tsx` | **Bottom section.** `grep TabsTrigger` returns 0. Do not build one. |

> **Contact already has a timeline and it is not this.** `contact/detail/tabs/timeline-tab.tsx` is a **business-event** feed — donations and emails, merged from `CONTACT_DONATIONS_QUERY` and `CONTACT_EMAIL_QUEUE_QUERY`. It is a different axis from record activity (field changes + discussion) and it stays exactly as it is.
>
> It does, however, carry a chip list with `{ key: "notes", label: "Notes", hasData: false }` that renders a "coming soon" empty state. **Leave that chip alone in this build.** Wiring it to comments is a one-line-looking change that quietly makes the timeline depend on the collaboration layer, and it is the user's call whether Notes belongs on the business timeline or only in Discussion. Raise it in the build log; do not decide it.

### `/crm/mentions` — "Mentions me"

A simple list page over `GetMyMentions`: record label + type badge, comment excerpt, author, relative time, unread dot. Row click navigates to the record and marks read. Toolbar switch **Unread only**, default on. Empty state *"You're all caught up."*

New menu `CRM_MENTIONS`, `MenuUrl = '/crm/mentions'`, in the CRM module.

---

## ⑥ Notifications — the path already exists, use it exactly

**Verified on disk 2026-08-12.** `Base.Application/Services/Notifications/` contains a complete, mute-aware fan-out writer. Inject `INotificationWriter` and call `StageAsync`. Nothing new is needed and nothing may be added.

```csharp
await notificationWriter.StageAsync(new NotificationWriteRequest
{
    Scope             = NotificationScope.Tenant,   // the writer THROWS if this and CompanyId disagree
    CompanyId         = currentUser.CompanyId,      // required for Tenant, must be null for Platform
    RecipientUserIds  = survivingMentionedUserIds,  // already re-validated per rule 6; empty list is legal, returns 0
    Title             = $"{authorName} mentioned you",
    Body              = excerpt,                    // ALREADY RENDERED — the writer does no token substitution
    Category          = "Mention",
    Priority          = "Normal",                   // NOT "Urgent" — that bypasses every mute rule
    IconCode          = "fa-at",
    ActionUrl         = recordPath,                 // scope-relative, NO locale prefix and NO host — the FE prepends both
    ActionLabel       = "View comment",
    FromUserId        = currentUser.UserId,
    TriggerCode       = "RECORD_MENTION",           // required; also the finest-grained key a user can mute on
    SourceEntityType  = entityType,                 // the RECORD, not the comment — lets a later feature find or revoke these
    SourceEntityId    = entityId,
}, cancellationToken);
```

Four things that will bite if ignored:

- **`Scope` and `CompanyId` are one value.** `NotificationWriter.StageAsync` throws `ArgumentException` when a Tenant request has no `CompanyId`. This is deliberate — that pair *is* the inbox security predicate.
- **`Title`/`Body` must be fully rendered.** The writer persists and mute-filters; it does not render tokens.
- **`ActionUrl` is scope-relative.** No `/en`, no host.
- **`Priority = "Urgent"` bypasses every mute rule.** A mention is not urgent. Someone who muted mentions must stay muted.

The FE side needs no work — `notifications-panel/index.tsx` and its `useFetchNotifications`/`useNotificationCount` hooks already render whatever the writer stages.

**Do not** add a second notification mechanism, a second badge, or a topbar change (rule 14).

> **Namespace quirk, will cost you a build error.** `Notification.cs` lives in `Base.Domain/Models/NotifyModels/` but its namespace is `Base.Domain.Models.SharedModels`. The folder does not tell you the `using`.

---

## ⑦ Explicitly out of scope

- **Topbar mention badge / unread count in the shell.** `app-topbar/index.tsx` is being edited by the in-flight Support & Audit build. The `/crm/mentions` page carries the count for now.
- **Migrating `case.CaseNotes`** to the generic layer (rule 1).
- **File or image attachments on comments** — no blob container exists, same constraint that made grant attachments URL-paste. A file input that cannot store a file is a lie.
- **Rich text, markdown, emoji reactions, edit history.** Plain text with mentions. Every one of these is a real feature and none of them is why records feel dead.
- **Email digests of mentions.** In-app only. A digest is a separate decision about frequency and opt-out.
- **Mentioning a team, role or `@here`.** Individual users only — a role mention is a fan-out with no owner, and people stop reading fan-outs.
- **Comments on platform-side `(master)/ops` records.** Different surface, different audience, and that route group is owned by another build.
- **Extending `AUDIT_TRAIL_REPORT_QUERY`** with an `entityId` argument. The report is a different screen with a different shape; this build adds its own record-scoped query rather than reshaping a working report.
- **Running any migration, `dotnet build`, or `dotnet ef` command.**

---

## ⑧ Files touched

> **Backend path prefix.** Every backend path below is relative to
> `PSS_2.0_Backend/PeopleServe/Services/Base/`.
> The projects are **not** at `PSS_2.0_Backend/Base.Application/` — that directory does not exist.
> Frontend paths are relative to `PSS_2.0_Frontend/src/`.

### Backend — new

```
Base.Domain/Models/ApplicationModels/RecordComment.cs
Base.Domain/Models/ApplicationModels/RecordCommentMention.cs
Base.Infrastructure/Data/Configurations/ApplicationConfigurations/RecordCommentConfiguration.cs
Base.Infrastructure/Data/Configurations/ApplicationConfigurations/RecordCommentMentionConfiguration.cs
Base.Application/Schemas/ApplicationSchemas/RecordCollaborationSchemas.cs
Base.Application/Business/ApplicationBusiness/Collaboration/CollaborationEntityMap.cs      ← the entityType → (menu, capability) map
Base.Application/Business/ApplicationBusiness/Collaboration/Commands/CreateRecordComment.cs
Base.Application/Business/ApplicationBusiness/Collaboration/Commands/UpdateRecordComment.cs
Base.Application/Business/ApplicationBusiness/Collaboration/Commands/DeleteRecordComment.cs
Base.Application/Business/ApplicationBusiness/Collaboration/Commands/MarkMentionRead.cs
Base.Application/Business/ApplicationBusiness/Collaboration/Queries/GetRecordActivity.cs
Base.Application/Business/ApplicationBusiness/Collaboration/Queries/GetMyMentions.cs
Base.API/EndPoints/Application/Mutations/RecordCollaborationMutations.cs
Base.API/EndPoints/Application/Queries/RecordCollaborationQueries.cs
```

### Backend — edited

```
IApplicationDbContext + ApplicationDbContext    (+ 2 DbSets)
```

### Frontend — new

```
app/[lang]/(core)/crm/mentions/page.tsx
domain/entities/application-service/RecordCollaborationDto.ts
infrastructure/gql-queries/application-queries/RecordCollaborationQuery.ts
infrastructure/gql-mutations/application-mutations/RecordCollaborationMutation.ts
presentation/components/custom-components/collaboration/record-collaboration-panel.tsx
presentation/components/custom-components/collaboration/comment-composer.tsx
presentation/components/custom-components/collaboration/mention-autocomplete.tsx
presentation/components/custom-components/collaboration/activity-item-comment.tsx
presentation/components/custom-components/collaboration/activity-item-change.tsx
presentation/components/custom-components/collaboration/use-record-activity.ts
presentation/components/custom-components/collaboration/index.ts
presentation/components/page-components/crm/mentions/mentions-list-page.tsx
presentation/components/page-components/crm/mentions/index.ts
sql-scripts-dyanmic/crm-mentions-menu-capability-seed.sql
```

### Frontend — edited

```
4 detail screens (Donation, Contact, Case, Grant) — mount the panel as one tab
infrastructure/gql-queries/application-queries/index.ts
infrastructure/gql-mutations/application-mutations/index.ts
presentation/components/page-components/crm/index.ts
```

**Not edited, by rule 14:** `app-topbar/index.tsx`, anything under `(master)/ops`.
**Not edited, by rule 1:** `crm/casemanagement/caselist/case/tabs/notes-tab.tsx`, `CaseNote.cs`.

---

## ⑨ Data model spec (for the user's migration)

**Do not author the migration.** Entity + configuration only, prove compile, hand this over.

### `app.RecordComments`

| Column | Type | Notes |
|---|---|---|
| `RecordCommentId` | `int` identity PK | |
| `CompanyId` | `int` NOT NULL | Tenant scope. Auto-stamped by `TenantSaveChangesInterceptor` — rule 3. |
| `EntityType` | `varchar(60)` NOT NULL | `Donation`, `Contact`, `Case`, `Grant`. Must match a key in `CollaborationEntityMap`. |
| `EntityId` | `int` NOT NULL | |
| `ParentCommentId` | `int` NULL | FK → self. One level only — enforced in the handler, not the schema. |
| `Body` | `text` NOT NULL | Plain text. Never rendered as HTML (rule 5). |
| `AuthorUserId` | `int` NULL | FK → `auth.Users`, `ON DELETE SET NULL`. |
| `AuthorUserName` | `varchar(150)` NOT NULL | Snapshot — survives rename and deactivation. |
| `IsEdited` | `boolean` NOT NULL default `false` | |
| audit columns | | inherited from `Entity`; `IsDeleted` drives the tombstone |

Indexes: `(CompanyId, EntityType, EntityId, CreatedDate DESC)` — the feed's only access path. Plus `(ParentCommentId)`.

### `app.RecordCommentMentions`

| Column | Type | Notes |
|---|---|---|
| `RecordCommentMentionId` | `int` identity PK | |
| `CompanyId` | `int` NOT NULL | |
| `RecordCommentId` | `int` NOT NULL | FK → `app.RecordComments`, cascade. |
| `MentionedUserId` | `int` NOT NULL | FK → `auth.Users`. Server-validated against the tenant on write (rule 6). |
| `IsRead` | `boolean` NOT NULL default `false` | |
| `ReadDate` | `timestamptz` NULL | |
| audit columns | | |

Indexes: **unique** `(RecordCommentId, MentionedUserId)` — mentioning someone twice in one comment notifies once. Plus `(CompanyId, MentionedUserId, IsRead)` for the mentions page.

### Seed — `sql-scripts-dyanmic/crm-mentions-menu-capability-seed.sql`

One file, idempotent, no DDL, safe to re-run. Copy the header shape from `sql-scripts-dyanmic/platform-intimations-menu-capability-seed.sql` (house template) — it carries the `auth`-not-`app` schema note, the two-required-checks note and the `ISMENURENDER`-never-inserted rule.

1. Menu `CRM_MENTIONS`, `MenuUrl = '/crm/mentions'` (leading slash, unique), under the CRM module.
2. Capability `CRM_COMMENT_MANAGE` — *delete another user's comment* (rule 7). Idempotency guard checks `CapabilityName`; `auth."Capabilities"` is UNIQUE on `(CapabilityName, IsActive)`, not on the code.
3. `MenuCapabilities` rows.
4. `RoleCapabilities` grants — `ISMENURENDER` on `CRM_MENTIONS` for **every** tenant role (mentions are personal; anyone who can be mentioned must be able to see their mentions), and `CRM_COMMENT_MANAGE` for `BUSINESSADMIN` and `SUPERADMIN` only.
5. Closing verify block, two counts, both must be **0**: menus with a capability but no `ISMENURENDER` grant; `MenuCapabilities` rows pointing at a non-existent `MenuCode`.

**Before writing it:** confirm `CRM_MENTIONS` and `CRM_COMMENT_MANAGE` return **0 matches** across `sql-scripts-dyanmic/`. If either exists, stop and report — a colliding menu code silently re-points live grants.

---

## ⑩ Acceptance criteria

1. `grep -rn "dangerouslySetInnerHTML" src/presentation/components/custom-components/collaboration/` → **0 matches** (rule 5).
2. `grep -rn "whitespace-pre-wrap" src/presentation/components/custom-components/collaboration/activity-item-comment.tsx` → non-zero.
3. Mentions render from the stored id list — `grep -rn "\.split\|match(\|RegExp" activity-item-comment.tsx` shows **no body re-parsing** at render time.
4. `CollaborationEntityMap` rejects unknown types: `grep -n "throw\|Unauthorized\|return false" CollaborationEntityMap.cs` → an explicit reject path exists and there is **no** default-allow branch.
5. `grep -n "IgnoreQueryFilters" Base.Application/Business/ApplicationBusiness/Collaboration/` → **0 matches**. These are tenant tables; the convention filter must attach (rule 3).
6. `CreateRecordCommentHandler` re-validates mention ids server-side — `grep -n "MentionedUserId\|Users" CreateRecordComment.cs` shows a tenant-scoped user existence check before insert.
7. `git diff --stat` shows **no change** to `CaseNote.cs`, `notes-tab.tsx`, `app-topbar/index.tsx`, or any file under `(master)/ops` (rules 1 and 14).
8. `grep -rn "bg-primary-600" src/presentation/components/custom-components/collaboration/` → **0 matches**; `grep -rn "brandSolid\|--shell-accent"` → non-zero (rule 11).
9. `grep -rn "bg-muted\|text-muted-foreground\|bg-\(blue\|emerald\|red\|violet\|slate\)-\(50\|100\)" src/presentation/components/custom-components/collaboration/` → **0 matches** on icon containers, badges and chips.
10. `grep -rn "AUDIT_TRAIL_REPORT_QUERY" src/presentation/components/custom-components/collaboration/` → **0 matches**. The panel uses its own record-scoped query.
11. `grep -n "entityId" …/Collaboration/Queries/GetRecordActivity.cs` → the audit source is filtered by both `EntityType` **and** `EntityId`.
11b. `grep -rn "oldValue\|newValue" …/Collaboration/` → **0 matches**. The on-disk `ChangesJson` shape is `[{field, before, after}]`.
11c. `grep -rn "StageAsync\|INotificationWriter" …/Collaboration/Commands/CreateRecordComment.cs` → non-zero, and `grep -rn "Notifications.Add\|new Notification" …/Collaboration/` → **0 matches** (no second write path, §⑥).
11d. `grep -rn "Urgent" …/Collaboration/` → **0 matches**. A mention must not bypass mute rules.
11e. `git diff --stat` shows **no change** to `contact/detail/tabs/timeline-tab.tsx`, and `grep -n "hasData: false" timeline-tab.tsx` still shows the `notes` chip untouched (§⑤).
12. The `ALL`/`COMMENTS`/`CHANGES` filter short-circuits — `grep -n "if.*filter" GetRecordActivity.cs` shows the skipped source is never queried.
13. `grep -n "DELETE FROM auth" sql-scripts-dyanmic/crm-mentions-menu-capability-seed.sql` → **0 matches**; `ISMENURENDER` appears in a grant and in no `INSERT INTO auth."Capabilities"`.
14. The seed's closing verify block returns 0 and 0.
15. `grep -rn "ExecuteSqlRaw\|FromSqlRaw" Base.Application/Business/ApplicationBusiness/Collaboration/` → **0 matches**.
16. No migration file, snapshot file, or `dotnet` invocation appears in the change set.
17. The panel is mounted on all four record types — `grep -rln "RecordCollaborationPanel" src/presentation/components/page-components/crm/` → **4 or more** files.
18. Every new `gql` document's field names were read off the resolver, not guessed. Spot-check: the query selects `recordActivity`, not `getRecordActivity`.
19. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` → **exit 0**. A run reporting only a "pre-existing" `TS2688` config error checked **zero files** and does not count.

---

## ⑪ Work order

**Build agent: Sonnet** (BE and FE). §④–⑨ are specified to the field level.

1. Read first, all of them, before writing anything: `AuditLog.cs`, `AuditTrailQueries.ts`, `CaseNote.cs`, `notes-tab.tsx`, `CommonExtension.cs`, `notifications-panel/index.tsx` and its hooks, `brand-surface.ts`, `platform-intimations-menu-capability-seed.sql`.
2. ~~Confirm the code names are free.~~ **Already verified 2026-08-12 — `CRM_MENTIONS` and `CRM_COMMENT_MANAGE` both return 0 matches across `sql-scripts-dyanmic/`.** Do not re-litigate. Re-run the grep only as a sanity check, expecting 0.
3. ~~Locate the four detail screens and their tab containers.~~ **Already surveyed — §⑤ names the host file and the treatment for each of the four.** Case and Contact get tabs; Grant and Donation get bottom sections because neither has a tab container. Follow the table; do not invent a tab container.
4. ~~Confirm the audit change payload shape.~~ **Already confirmed — `AuditLog.ChangesJson`, array `[{field, before, after}]`, max 64KB.** Parse defensively: a row whose JSON does not match returns an empty list and renders `Description` alone. Never throw.
5. ~~Confirm the notification write path.~~ **Already confirmed — `INotificationWriter.StageAsync`, call spelled out verbatim in §⑥.** Use it as written.
6. Backend: entities → configurations → `DbSet`s → `CollaborationEntityMap` → schemas → `GetRecordActivity` → commands → `GetMyMentions` → endpoints.
7. Frontend: DTOs → gql documents → `use-record-activity` → item components → composer → autocomplete → panel → four mounts → mentions page.
8. Seed script last, after menu URLs are final.
9. `npx tsc --noEmit --incremental false`. Exit 0 or keep working.
10. Report: the §⑨ migration spec verbatim, the seed path, which of the four screens took the tab vs bottom-section treatment, the audit change-payload shape found in step 4, and anything in §⑩ not satisfied — with the reason, not a workaround.

**Hand back to the user, do not do yourself:** the EF migration, `dotnet build`, applying the seed.

---

## ⑫ Build log

*(append-only, newest first, last 5 sessions — git keeps the rest)*

| Date | Session | Outcome |
|---|---|---|
| 2026-08-12 | **BUILD — complete, handed back** | Backend + frontend + seed all written; `npx tsc --noEmit --incremental false` → **exit 0** (real file-check: an intermediate run caught two genuine `TS2322` `Badge variant="secondary"` errors — the shared atom takes `color="secondary"`, `variant` is only `"outline" \| "soft"` — fixed in `record-collaboration-panel.tsx` and `mentions-list-page.tsx`). Split authorization landed as designed: coarse `[CustomAuthorize(…, Permissions.Read)]` floor + mandatory runtime `CollaborationEntityMap.TryResolve` → `HasAccessAsync` in **every** handler, unknown `entityType` → `ForbiddenAccessException`, no default-allow. Two post-agent corrections applied by hand: **(a)** `DeleteRecordComment`'s non-author branch had been written against a module-level `Permissions.Delete` grant, which would have made the seeded `CRM_COMMENT_MANAGE` dead code — rewritten to gate the moderator path on `CRM_COMMENT_MANAGE` alone (rule 7, §⑨ pt 2); **(b)** the class-level floors on Delete (`Permissions.Delete`) and Update (`Permissions.Modify`) would have blocked an author from retracting/correcting their own comment on a record they can only read — both lowered to `Permissions.Read`, ownership enforced at runtime. Mount treatment: Case + Contact took **Discussion tabs** (each also needed a `"discussion"` key added to its tab store), Grant + Donation took **bottom sections** (no tab container, per §⑤). `@mention` autocomplete reuses the existing **`STAFFS_QUERY`** — no new user-lookup query. Seed written to repo-root `sql-scripts-dyanmic/crm-mentions-menu-capability-seed.sql`; `CRM_MENTIONS` sits root-level under the CRM module, which renders correctly because `GetParentChildMenu` **computes** `LeastMenu` from child count rather than reading the column. §⑩: 18 of 19 criteria verified; **criteria 7 / 11e cannot be run as written** — `.gitignore:12` excludes `PSS_2.0_Frontend/` (and the backend tree likewise), so `git diff --stat` reports nothing for either tree; substituted mtime evidence (`notes-tab.tsx` Jul 9 15:51, `timeline-tab.tsx` Jul 9 15:17, `app-topbar/index.tsx` Aug 11 20:09 — all predate the build, `(master)/ops` 0 files touched) plus the `hasData: false` notes chip still present at `timeline-tab.tsx:37`. **Criterion 14 is unrunnable here** (needs a DB — the seed is the user's to apply). **Handed back, not done: the EF migration (§⑨ spec), `dotnet build`, applying the seed.** |
| 2026-08-12 | pre-flight before first run | Six corrections applied, all verified on disk. **(1)** Every backend path was missing the `PeopleServe/Services/Base/` segment — `PSS_2.0_Backend/Base.Application/` does not exist; §⑧ now states the prefix. **(2)** `ChangesJson` is `[{field, before, after}]`, not `{oldValue,newValue}`; §④ corrected and criterion 11b added. `AuditLog` also carries `Description`, `Severity`, `EntityDisplayKey` — now used. **(3)** The notification path exists and is richer than assumed: `INotificationWriter.StageAsync(NotificationWriteRequest)` already does mute filtering, scope/CompanyId validation, and carries `SourceEntityType`/`SourceEntityId`/`ActionUrl`/`TriggerCode`. §⑥ rewritten with the verbatim call; §⑪ step 5's "stop and report" is void. **(4)** Only 2 of the 4 mount targets have a tab container — Case and Contact do, Grant (`grant-detail.tsx`) and Donation (`view-page.tsx`) return 0 for `TabsTrigger`; §⑤ now names host file + treatment per record. **(5)** Contact already has `timeline-tab.tsx` (business events: donations + emails) with a dead `notes` chip — flagged, explicitly out of scope, criterion 11e guards it. **(6)** `Notification.cs` sits in `NotifyModels/` but its namespace is `Base.Domain.Models.SharedModels`. Menu/capability codes `CRM_MENTIONS` and `CRM_COMMENT_MANAGE` confirmed free. |
| 2026-08-11 | prompt authored | Not yet built. Verified on disk: no comment/mention layer exists anywhere (`SocialMediaMention` is social listening, unrelated); `case.CaseNotes` is the only note surface and is welded to `CaseId`/`AuthorStaffId`/`NoteTypeId`; **`audit.AuditLogs` already carries `EntityType`+`EntityId`+actor+timestamp per record** — the activity half needs no new writer; `AUDIT_TRAIL_REPORT_QUERY` filters `entityType` but takes no `entityId`, which is why per-record history is unreachable today. |

### Known issues

- **Topbar mention badge deferred** until the Support & Audit build releases `app-topbar/index.tsx`.
- **No blob storage** blocks comment attachments — same constraint as grant file upload.
- **Contact's timeline `notes` chip stays dead.** `timeline-tab.tsx` advertises a Notes filter with `hasData: false`. Once Discussion ships, a Contact page shows a working Discussion tab *and* a "Notes coming soon" chip on the timeline — visibly inconsistent. Wiring the chip to comments is small, but whether discussion belongs on a business-event timeline is a product call, not a build call. **Decide this after the build, not inside it.**
- **`case.CaseNotes` now has a neighbour, not a successor.** The Case screen will show both a Notes tab and a Discussion tab. That is intentional for this build and is a genuine UX question to revisit once the generic layer has real usage.
- **`FEATURE:INTELLIGENCE` visibility decision** still open from the AI module prompt — unrelated to this build, still unanswered.
