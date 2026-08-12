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
| `fieldChanges` | `[{ field, oldValue, newValue }]` parsed from the audit row's change payload. Null/empty when unparseable — **never throw on bad JSON**. |
| `recordCommentId`, `auditLogId` | Whichever applies. |

### Commands

- `CreateRecordComment` — validates `entityType` against the same map, body 1–4000 chars, re-validates mention ids against the tenant (rule 6), stores the surviving ids, snapshots author name, returns the created item. Fires one notification per surviving mentioned user through the **existing** notification infrastructure (`useFetchNotifications`/`useNotificationCount` already consume it) — do not build a second notification path.
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

Mount as a **tab** on the detail screens of exactly these four records for this build:

| Record | Notes |
|---|---|
| Donation | highest-traffic record in the product |
| Contact | the relationship record; where a team most needs shared context |
| Case | mounts as a **second** tab named **Discussion**, beside the existing **Notes** tab, which is untouched (rule 1) |
| Grant | longest-lived record, most hand-offs between staff |

If any of these four detail screens does not have a tab container, mount the panel as a full-width section at the bottom of the page rather than restructuring the screen. Say which route took which treatment in the build log.

### `/crm/mentions` — "Mentions me"

A simple list page over `GetMyMentions`: record label + type badge, comment excerpt, author, relative time, unread dot. Row click navigates to the record and marks read. Toolbar switch **Unread only**, default on. Empty state *"You're all caught up."*

New menu `CRM_MENTIONS`, `MenuUrl = '/crm/mentions'`, in the CRM module.

---

## ⑥ Notifications

Reuse the existing notification pipeline — the panel at `layout-components/notifications-panel/index.tsx` and its `useFetchNotifications`/`useNotificationCount` hooks already render whatever the backend writes. A mention writes one notification per mentioned user with a deep link to the record.

**Do not** add a second notification mechanism, a second badge, or a topbar change (rule 14).

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
11. `grep -n "entityId" Base.Application/Business/ApplicationBusiness/Collaboration/Queries/GetRecordActivity.cs` → the audit source is filtered by both `EntityType` **and** `EntityId`.
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
2. **Confirm the code names are free.** `CRM_MENTIONS`, `CRM_COMMENT_MANAGE` → 0 matches in `sql-scripts-dyanmic/`. If not, stop and report.
3. **Locate the four detail screens and their tab containers before designing the mount.** If a screen has no tab container, note it and use the bottom-section fallback (§⑤) — do not restructure a working screen.
4. Confirm how `audit.AuditLogs` stores its field-level change payload (column name and JSON shape) before writing the `fieldChanges` parser. If the shape is inconsistent across writers, parse defensively and return an empty list rather than throwing — and say so in the build log.
5. Confirm the notification write path used by `useFetchNotifications` before wiring mention notifications. If a mention cannot be written through the existing path without changing it, **stop and report** rather than building a second path.
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
| 2026-08-11 | prompt authored | Not yet built. Verified on disk: no comment/mention layer exists anywhere (`SocialMediaMention` is social listening, unrelated); `case.CaseNotes` is the only note surface and is welded to `CaseId`/`AuthorStaffId`/`NoteTypeId`; **`audit.AuditLogs` already carries `EntityType`+`EntityId`+actor+timestamp per record** — the activity half needs no new writer; `AUDIT_TRAIL_REPORT_QUERY` filters `entityType` but takes no `entityId`, which is why per-record history is unreachable today. |

### Known issues

- **Topbar mention badge deferred** until the Support & Audit build releases `app-topbar/index.tsx`.
- **No blob storage** blocks comment attachments — same constraint as grant file upload.
- **`case.CaseNotes` now has a neighbour, not a successor.** The Case screen will show both a Notes tab and a Discussion tab. That is intentional for this build and is a genuine UX question to revisit once the generic layer has real usage.
- **`FEATURE:INTELLIGENCE` visibility decision** still open from the AI module prompt — unrelated to this build, still unanswered.
