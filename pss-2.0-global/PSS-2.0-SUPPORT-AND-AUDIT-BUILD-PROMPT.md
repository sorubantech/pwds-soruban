# PSS 2.0 — Support Loop & Estate Audit — Build Prompt

> Covers **T-9** (tenant-side bug / feedback raiser), **P-6** (platform-side support inbox), **P-3** (cross-tenant audit log).
> Companion doc: `PSS-2.0-PRODUCT-SHELL-FEATURE-EXPLORATION.md` — §④ T-9, §⑤ P-3/P-6, §⑥ dummy-first rules.
> **Do not trust this header for status. Verify against disk.**

---

## ① Why this exists

| # | Defect | Evidence |
|---|--------|----------|
| **D-1** | A tenant who hits a bug has **no way to tell us**. No feedback control anywhere in the shell. The topbar icon cluster is Plan chip → Theme → Fullscreen → Notifications → Profile and nothing else. | `presentation/components/layout-components/app-topbar/index.tsx:207-221` |
| **D-2** | There is **no support ticket table, entity, handler or screen** anywhere in the product. `find PSS_2.0_Backend -iname "*Ticket*" -o -iname "*Feedback*"` returns only `EventTicket*` (event ticketing — unrelated business domain). | verified on disk |
| **D-3** | The seeded `PLATFORM_AUDIT` menu at `/ops/audit` renders a **placeholder**, not a screen. Platform staff clicking Audit in the sidebar get a "coming soon" card. | `app/[lang]/(master)/ops/audit/page.tsx` renders `ControlPlaneComingSoon` |
| **D-4** | The audit **data layer already exists and is good** — entity, writer, DTO, query, grid pipeline, a working per-tenant tab — but is reachable only from inside one tenant's detail page. There is no way to answer *"what did our staff do across the estate today?"* The handler docblock says so outright: *"The estate-wide view is a separate surface."* | `Base.Application/Business/OpsBusiness/PlatformAudit/Queries/GetTenantAuditTrail.cs` (header comment); UI at `presentation/components/page-components/ops/tenants/tenant-audit-tab.tsx` |
| **D-5** | Platform-only actions (`TargetCompanyId IS NULL` — plan baseline edits, staff invites, RBAC pushes) are written to `ops.PlatformAuditLog` and are **currently visible in no UI at all**. The per-tenant tab correctly excludes them; nothing includes them. | same handler: `.Where(a => a.TargetCompanyId == query.companyId)` |

**The demo consequence.** D-1 + D-3 together are why the shell reads as unfinished: the product has no visible support story on either side of the vendor/customer line. This build closes the loop end to end — a tenant staffer reports a bug in three clicks, it lands in the platform inbox with full technical context attached, and the audit screen sits beside it in the same surface.

---

## ② Rules this build must not break

1. **Audit is never dummied.** §⑥ rule 4 of the exploration doc. P-3 reads real `ops.PlatformAuditLog` rows through real handlers or it does not ship. No canned rows, no `_data/*.ts` for P-3.
2. **The support loop is real too.** A form that says "Report sent" and drops the payload is worse than no form. T-9/P-6 get a real table, a real command, a real query. This is the one place in the shell programme where dummy-first does **not** apply.
3. **Migrations are the user's.** Never run `dotnet ef migrations add` / `database update` / `remove`. Never hand-author a migration or snapshot file. Write the entity + configuration + `DbSet`, prove it compiles, then hand over the migration spec in §⑩. Do **not** run `dotnet build` either — the user builds.
4. **No raw SQL in application code.** `ExecuteUpdateAsync` / `ExecuteDeleteAsync` over LINQ are EF and fine. Hand-written `.sql` under `sql-scripts-dyanmic/` that the user applies is the permitted separate channel — one script per file, the file *is* the thing to execute.
5. **No `CompanyId` property on any `ops` entity.** The convention-based tenant filter attaches by property name. `ops.PlatformAuditLog` deliberately names its tenant column `TargetCompanyId` for exactly this reason (see the entity docblock). `ops.SupportTicket` follows the same rule with `RaisedByCompanyId`. Tenant scoping on the tenant-facing read is then an **explicit** `.Where()` in the handler, written deliberately and commented.
6. **Every `ops` read needs both guards** — `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true`. Copy the pattern and the reasoning comment from `GetTenantAuditTrail.cs`.
7. **RBAC seeds are additive.** `INSERT … SELECT … WHERE NOT EXISTS`, guarded repair `UPDATE`s that are no-ops once correct. Soft-delete only (`IsDeleted=true, IsActive=false`), never `DELETE FROM auth`. `ISMENURENDER` already exists as a base-app capability and is **never inserted** by a seed — it is only *granted*. `SUPERADMIN` is matched by `RoleCode` alone and is never revoked or overwritten.
8. **Menu codes are join keys.** `auth."RoleCapabilities"` joins Role → Menu(**MenuCode**) → Capability. Never rename an existing `MenuCode`. `PLATFORM_AUDIT` already exists — reuse it, do not re-create it.
9. **Both checks are required for a menu to work.** (a) API authorization reads `auth."RoleCapabilities"`; (b) sidebar rendering comes from `GetParentChildMenuHandler`, which lists menus the user holds `ISMENURENDER` on. A menu with a capability but no `ISMENURENDER` grant is URL-callable and completely invisible in the nav.
10. **HotChocolate strips `Get` from every resolver** and appends `Input` to input types. `GetPlatformAuditTrail` → `platformAuditTrail`. `SupportTicketCreateDto` → `SupportTicketCreateDtoInput`. `tsc` cannot see GraphQL field names — a wrong name compiles clean and fails at runtime only. Read the resolver before writing the `gql` document.
11. **UTC only.** Every date column is `timestamptz`; Npgsql throws on `Kind=Unspecified`. `DateTime.UtcNow`, never `DateTime.Today` in an EF predicate.
12. **House UI rules.** Solid `bg-X-600` + `text-white` for icon containers, status badges and helper chips — never `bg-X-50/100`, never `text-X-700/800`, never `bg-muted`/`text-muted-foreground` as a status, never `/10` alpha tints. Tokens not hex/px. Shaped Skeletons. `@iconify` Phosphor icons. xs→xl responsive.
13. **Two-surface colour.** The tenant-side T-9 launcher and dialog paint from `brand-surface.ts` (`brandSolid` / `brandGradient` / `brandSoft`, reading `var(--shell-accent*)`) so they follow the tenant's own primary. The `(master)` P-3/P-6 screens keep the static platform violet→blue. Anything painted `bg-primary-600` inside a tenant page renders the platform violet — that is the bug this rule prevents.
14. **Save/submit enablement is RHF `formState.isValid`**, never `canCreate`/`canUpdate`. Capability gates the entry-point button's visibility only.
15. **Do not touch `(core)/ai` or `(core)/crm`.** The AI module build is in flight in a parallel session and owns those route groups. This build touches `(core)` only at the topbar mount point in §⑤.

---

## ③ The mental model

> **A support ticket is the tenant's half of the audit log.** One table records what we did to them; the other records what they told us. Both are append-only, both carry who/when/why, and both belong on the same `(master)/ops` surface — because "what happened to this tenant" is one question, not two.

That framing drives every design call below: the ticket carries an actor snapshot and a technical context blob for the same reason the audit row carries `ActorUserName` and `ChangesJson` — the record must stay readable after the ids it mentions are gone.

---

## ④ T-9 — Tenant-side bug / feedback raiser

### Surface

A persistent launcher in the tenant shell's topbar icon cluster, immediately left of `<ThemeButton />` in `app-topbar/index.tsx`. Rendered only when `!isPlatformUser` — platform staff working inside a tenant do not file tenant tickets.

- Icon `ph:lifebuoy`, `aria-label="Send feedback"`, same `size-9 rounded-md hover:bg-white/10` geometry as its neighbours so the cluster stays even.
- On `md` and up it may carry a text label; below `md` it is icon-only.
- Clicking opens a **Dialog** (not a Sheet, not a route) — the user must never lose the page they are reporting about.

### The dialog

Header: title **Send feedback**, subtitle *"Goes straight to the product team."*

| Field | Control | Rules |
|-------|---------|-------|
| Category | 3 selectable cards, single-select — **Bug** (`ph:bug`, `bg-rose-600`), **Idea** (`ph:lightbulb`, `bg-amber-600`), **Question** (`ph:question`, `bg-blue-600`) | required; default none; the selected card gets a solid accent border + the icon container goes solid, unselected stay outline |
| Subject | Input | required, 5–150 chars |
| Description | Textarea, 5 rows | required, min 20 chars, max 4000; placeholder differs per category ("What did you expect to happen, and what happened instead?" for Bug) |
| Severity | Segmented control — Low / Medium / High | **Bug only**; hidden for Idea and Question; default Medium |
| Contact me about this | Switch | default on; when on, the ticket is flagged so the platform side knows a reply is wanted |

Below the fields, a **collapsed disclosure** labelled *"Technical details we'll send"*, chevron-expandable, listing exactly what is captured — nothing hidden, nothing extra:

```
Page          /en/crm/donation/globaldonation?tab=list
Tenant        Acme Foundation (#42)
Reported by   Priya R. (priya@acme.org)
Browser       Chrome 141 · Windows
Screen        1440 × 900
App version   2.0.0-mvp1
Local time    2026-08-11 14:22 (+05:30)
```

That disclosure is what makes the feature trustworthy — a support widget that silently harvests context is a widget people stop using. It is read-only, it is never editable, and the same values are what gets serialised into `ContextJson`.

Footer: **Cancel** (ghost) · **Send feedback** (solid, `brandSolid`, disabled until `formState.isValid`, spinner + disabled while in flight).

### After submit

Dialog closes; a `toast.success` reads **"Thanks — reference SUP-000137"** with the real returned reference. The form resets. There is no tenant-side ticket list in this build (see §⑦) — the toast reference is the tenant's receipt.

On failure: dialog stays open, fields keep their values, inline destructive alert at the top of the dialog body carrying the server message. Never a silent close.

### Screenshot attachment — deliberately excluded

There is no blob storage account provisioned (same constraint that made grant attachments URL-paste). A file input that cannot store a file is a lie. Ship without it; the `ContextJson` payload carries the route and viewport, which is 80% of what a screenshot would have told us. Re-open when a private container exists.

---

## ⑤ P-6 — Platform support inbox

Route `(master)/ops/support`, menu code **`PLATFORM_SUPPORTDESK`** (new), sidebar label **Support**, icon `ph:lifebuoy`, placed directly after the existing Audit entry in the ops group.

> **Why not `PLATFORM_SUPPORT`.** That string is already taken — it is a **role code** (`ops-platform-rbac-seed.sql:122`, "Platform Support"). Roles and menus live in different tables so the database would tolerate it, but every seed script in `sql-scripts-dyanmic/` writes grants as bare tuples `('ROLE_CODE', 'MENU_CODE', 'CAPABILITY_CODE')` — see `ops-platform-rbac-seed.sql:158`. A menu whose code equals a role code makes those tuples ambiguous to read and one transposition away from silently granting the wrong thing. Use `PLATFORM_SUPPORTDESK`.

### List page

Follow the house pattern of `presentation/components/page-components/ops/intimations/platform-intimations-list-page.tsx` — it is the closest analogue (platform-global grid, status chips, no tenant filter).

**Header row** — title **Support**, subtitle *"What tenants are telling us."* Right side: a refresh icon button. No Create button — platform staff do not raise tenant tickets.

**Summary strip**, 4 tiles across (`grid-cols-2 lg:grid-cols-4`), each a solid icon container + count + label:

| Tile | Icon | Container |
|---|---|---|
| New | `ph:tray` | `bg-blue-600` |
| In progress | `ph:spinner-gap` | `bg-amber-600` |
| Awaiting tenant | `ph:hourglass` | `bg-violet-600` |
| Resolved (30d) | `ph:check-circle` | `bg-emerald-600` |

Counts come from the same query's aggregate block, not from four extra round trips.

**Grid columns** — Reference · Category · Subject · Tenant · Raised by · Severity · Status · Raised (relative + absolute on hover) · row action.

- Category and Severity render as solid badges (`bg-rose-600` Bug / `bg-amber-600` Idea / `bg-blue-600` Question; severity High `bg-red-600`, Medium `bg-amber-600`, Low `bg-slate-600`).
- Status badges: New `bg-blue-600`, In progress `bg-amber-600`, Awaiting tenant `bg-violet-600`, Resolved `bg-emerald-600`, Closed `bg-slate-600`.
- Tenant cell links to `/ops/tenants/{raisedByCompanyId}` — the inbox and the tenant record must be one click apart.
- Toolbar: search box (searches reference, subject, description, tenant name, reporter name) + status filter + category filter. Server-side through the existing grid pipeline.
- Empty state: `ph:tray` in a solid `bg-slate-600` container, **"No tickets yet"**, sub-line *"When a tenant sends feedback it lands here."* Never a bare "No records found".
- Loading: shaped Skeletons matching the real row geometry, not a spinner.

### Detail drawer

Row click opens a right-side **Sheet** (not a route — the queue is the workspace).

- **Head**: reference + subject; category and severity badges; status badge.
- **Body**, in order:
  1. Description, rendered with `whitespace-pre-wrap` so the reporter's line breaks survive.
  2. **Technical context** — a definition list built from `ContextJson`, same seven rows the tenant saw in the disclosure, plus a copy-all button. If `ContextJson` is null or unparseable, render *"No context captured"* — never crash the drawer on bad JSON.
  3. **Reporter** — name, email, tenant name, and a link to the tenant record.
  4. **Internal notes** — append-only list of `{ author, timestamp, body }`, newest last, plus a textarea + **Add note** button. Notes are platform-internal and are never shown to the tenant; the drawer says so in a one-line helper.
- **Footer actions**: a status `Select` (New / In progress / Awaiting tenant / Resolved / Closed) and an **Assign to** `Select` populated from platform staff. Both save through one `updateSupportTicket` mutation; the drawer shows a saving state and the grid row updates in place.
- Every status change and assignment writes an `ops.PlatformAuditLog` row through the existing `PlatformAuditWriter` — `ActionType = "platform.support.ticket_updated"`, `TargetCompanyId` = the raising tenant, `ChangesJson` = before/after status and assignee. This is the point of rule 2: the support loop and the audit log are the same fabric.

---

## ⑥ P-3 — Estate-wide audit log

Replaces the `ControlPlaneComingSoon` placeholder at `app/[lang]/(master)/ops/audit/page.tsx`. Reuses menu code `PLATFORM_AUDIT` — already seeded, do not re-create.

### Backend — one new query, modelled line for line on `GetTenantAuditTrail`

`Base.Application/Business/OpsBusiness/PlatformAudit/Queries/GetPlatformAuditTrail.cs`

- `[CustomAuthorize("PLATFORM_AUDIT", "PLATFORM_AUDIT_VIEW")]` — reading the whole estate's trail is a **higher** authority than reading one tenant's, so it does not inherit `PLATFORM_TENANT_VIEW`.
- Signature `GetPlatformAuditTrailQuery(int? targetCompanyId, bool includePlatformOnly, GridFeatureRequest gridFilterRequest)`.
- Base query identical to the per-tenant one minus the `TargetCompanyId` equality — `IgnoreQueryFilters()`, `AsNoTracking()`, `IsDeleted != true`, `OrderByDescending(a => a.Timestamp)`. Carry over the explanatory comment about why both guards are present.
- `targetCompanyId` non-null → filter to it. `includePlatformOnly == false` → `.Where(a => a.TargetCompanyId != null)`. Default is `true` — **the whole point of this screen is that platform-only rows finally have somewhere to appear** (D-5).
- Same `searchTerm` clause plus tenant name.
- Validator: reuse the `ValidSortColumns` set from `GetTenantAuditTrailValidator` (`PlatformAuditLogId`, `ActionType`, `EntityType`, `ActorUserName`, `Timestamp`). Sorting is over the **entity**, not the DTO — do not add a sort column that does not exist on `PlatformAuditLog`.

**Tenant name.** `CommonExtension.ApplyGridFeatures` materialises entities and maps in memory via `results.ToDtoList<T, TDto>()` (`Base.Application/Extensions/CommonExtension.cs:105`) — it is **not** a `ProjectTo`, so a flattened `TargetCompany.CompanyName` will not appear by itself. Do not fight the mapper and do not add an `Include` hoping it flattens. Instead, after `ApplyGridFeatures` returns, take the page's distinct non-null `TargetCompanyId`s (≤ pageSize values), fetch `{ CompanyId, CompanyName }` in one query, and fill `TargetCompanyName` on the DTO list. Explicit, one extra round trip per page, no mapper convention relied on.

New DTO `PlatformAuditRowDto` in `Base.Application/Schemas/OpsSchemas/PlatformAuditSchemas.cs` — every field of `TenantAuditRowDto` plus `public string? TargetCompanyName { get; set; }`. Do **not** modify `TenantAuditRowDto`; the existing tab's auto-projection depends on its property names matching the entity one-for-one.

### Frontend

`presentation/components/page-components/ops/audit/platform-audit-list-page.tsx`, exported through `page-components/ops/index.ts`. The page file becomes a thin route wrapper.

Lift the presentation from `ops/tenants/tenant-audit-tab.tsx` — including its `actionTone()` helper (solid `bg-red-600` / `bg-amber-600` / `bg-emerald-600` / `bg-blue-600` / `bg-slate-600`, "icon containers are never tinted"). Do not re-invent the tone mapping; if it needs a new verb, extend it in one place.

- **Header** — title **Audit**, subtitle *"Everything platform staff did, newest first."* Plus a right-aligned non-dismissible helper chip reading **Append-only** — no edit, no delete, no acknowledge, and the screen should say so rather than leave people looking for the buttons.
- **Filter bar** — search input; a Tenant combobox (All tenants / a specific tenant, sourced from the existing tenants query); a **Show platform-only actions** switch, default **on**, with helper text *"Actions not aimed at any single tenant — plan edits, staff invites, RBAC pushes."*
- **Columns** — When (relative, absolute on hover) · Action (the dotted verb, toned badge) · Tenant (name, or a `bg-slate-600` **Platform** badge when `targetCompanyId` is null) · Entity (`entityType` + `#entityId`) · Description · Actor (`actorUserName`) · row expand.
- **Row expand**, not a drawer — audit rows are read-only and short: reveals `Reason` (rendered prominently with a `ph:seal-check` icon when present, since it is the break-glass justification), `IpAddress`, and `ChangesJson` pretty-printed in a `<pre>` inside an `overflow-x-auto` container. If `ChangesJson` is null, the block is omitted, not shown empty.
- **No row actions at all.** No kebab menu. The absence is the feature.
- Empty state `ph:list-magnifying-glass` in `bg-slate-600`, **"Nothing recorded yet"**.
- Skeleton rows while loading; the money/id columns use `tabular-nums`.

---

## ⑦ Explicitly out of scope

- **Any file or screenshot upload** — no blob container exists (§④).
- **A tenant-side "my tickets" list.** The toast reference is the receipt for this build. Add it once tenants actually file volume.
- **Email or in-app notification on ticket status change.** The notification plumbing exists but wiring it is a separate decision about who gets told what.
- **SLA timers, priority queues, escalation rules, canned replies.** A queue with a status and an assignee is a support tool; the rest is a support *product*.
- **Replying to the tenant from the drawer.** Internal notes only. A tenant-visible reply thread needs the notification decision above first.
- **Exporting the audit log to CSV/PDF.** Real requirement, separate build, needs a decision on whether an export is itself an auditable action.
- **Impersonation (P-2).** `ImpersonateUser.cs` is a documented `SERVICE_PLACEHOLDER` returning `AccessToken = "PLACEHOLDER"`, and the FE guard at `user-actions-cell.tsx:97-99` is cosmetic. It stays that way — do not build on it and do not remove the placeholder.
- **Touching `(core)/ai` or `(core)/crm`** (rule 15).
- **Running any migration, `dotnet build`, or `dotnet ef` command** (rule 3).

---

## ⑧ Files touched

### Backend — new

```
Base.Domain/Models/OpsModels/SupportTicket.cs
Base.Domain/Models/OpsModels/SupportTicketNote.cs
Base.Infrastructure/Data/Configurations/OpsConfigurations/SupportTicketConfiguration.cs
Base.Infrastructure/Data/Configurations/OpsConfigurations/SupportTicketNoteConfiguration.cs
Base.Application/Schemas/OpsSchemas/SupportTicketSchemas.cs
Base.Application/Business/OpsBusiness/Support/Commands/CreateSupportTicket.cs
Base.Application/Business/OpsBusiness/Support/Commands/UpdateSupportTicket.cs
Base.Application/Business/OpsBusiness/Support/Commands/AddSupportTicketNote.cs
Base.Application/Business/OpsBusiness/Support/Queries/GetSupportTickets.cs
Base.Application/Business/OpsBusiness/Support/Queries/GetSupportTicketById.cs
Base.Application/Business/OpsBusiness/PlatformAudit/Queries/GetPlatformAuditTrail.cs
Base.API/EndPoints/Ops/Mutations/SupportTicketMutations.cs
Base.API/EndPoints/Ops/Queries/SupportTicketQueries.cs
```

### Backend — edited

```
Base.Application/Schemas/OpsSchemas/PlatformAuditSchemas.cs   (+ PlatformAuditRowDto)
Base.API/EndPoints/Ops/Queries/PlatformAuditQueries.cs        (+ GetPlatformAuditTrail)
IApplicationDbContext + ApplicationDbContext                  (+ 2 DbSets)
```

### Frontend — new

```
app/[lang]/(master)/ops/support/page.tsx
domain/entities/ops-service/SupportTicketDto.ts
infrastructure/gql-queries/ops-queries/SupportTicketQuery.ts
infrastructure/gql-mutations/ops-mutations/SupportTicketMutation.ts
presentation/components/page-components/ops/support/platform-support-list-page.tsx
presentation/components/page-components/ops/support/support-ticket-drawer.tsx
presentation/components/page-components/ops/support/support-status-badge.tsx
presentation/components/page-components/ops/support/support-category-badge.tsx
presentation/components/page-components/ops/support/index.ts
presentation/components/page-components/ops/audit/platform-audit-list-page.tsx
presentation/components/page-components/ops/audit/index.ts
presentation/components/layout-components/feedback-launcher/index.tsx
presentation/components/layout-components/feedback-launcher/feedback-dialog.tsx
presentation/components/layout-components/feedback-launcher/use-client-context.ts
sql-scripts-dyanmic/platform-support-menu-capability-seed.sql
```

### Frontend — edited

```
presentation/components/layout-components/app-topbar/index.tsx   (mount FeedbackLauncher when !isPlatformUser)
presentation/components/page-components/ops/index.ts             (+ 2 exports)
infrastructure/gql-queries/ops-queries/index.ts                  (+ SupportTicketQuery)
infrastructure/gql-mutations/ops-mutations/index.ts              (+ SupportTicketMutation)
app/[lang]/(master)/ops/audit/page.tsx                           (placeholder → real page)
```

`presentation/components/page-components/ops/common/control-plane-coming-soon.tsx` **stays** — other placeholder routes still use it.

---

## ⑨ Data model spec (for the user's migration)

**Do not author the migration.** Write the entity + configuration, prove compile, hand this over.

### `ops.SupportTicket`

| Column | Type | Notes |
|---|---|---|
| `SupportTicketId` | `int` identity PK | |
| `TicketReference` | `varchar(20)` NOT NULL | `SUP-000137`. **Unique index.** Generated server-side on create — never by the client. |
| `RaisedByCompanyId` | `int` NOT NULL | FK → `app.Companies`. **Not** named `CompanyId` — rule 5. |
| `RaisedByUserId` | `int` NULL | FK → `auth.Users`, `ON DELETE SET NULL`. |
| `RaisedByUserName` | `varchar(150)` NOT NULL | Snapshot, same reasoning as `PlatformAuditLog.ActorUserName`. |
| `RaisedByUserEmail` | `varchar(200)` NULL | Snapshot. |
| `Category` | `varchar(20)` NOT NULL | `BUG` / `IDEA` / `QUESTION`. |
| `Severity` | `varchar(20)` NULL | `LOW` / `MEDIUM` / `HIGH`. Null for non-bugs. |
| `Subject` | `varchar(150)` NOT NULL | |
| `Description` | `text` NOT NULL | |
| `ContextJson` | `text` NULL | Route, viewport, user agent, app version, local time. **Never a secret** — same contract as `ChangesJson`. |
| `WantsContact` | `boolean` NOT NULL default `true` | |
| `Status` | `varchar(30)` NOT NULL default `'NEW'` | `NEW` / `IN_PROGRESS` / `AWAITING_TENANT` / `RESOLVED` / `CLOSED`. |
| `AssignedToUserId` | `int` NULL | FK → `auth.Users`, `ON DELETE SET NULL`. |
| `ResolvedDate` | `timestamptz` NULL | |
| audit columns | | inherited from `Entity` |

Indexes: unique on `TicketReference`; `(Status, CreatedDate DESC)`; `(RaisedByCompanyId, CreatedDate DESC)`.

### `ops.SupportTicketNote`

| Column | Type | Notes |
|---|---|---|
| `SupportTicketNoteId` | `int` identity PK | |
| `SupportTicketId` | `int` NOT NULL | FK → `ops.SupportTicket`, cascade. |
| `AuthorUserId` | `int` NULL | |
| `AuthorUserName` | `varchar(150)` NOT NULL | Snapshot. |
| `Body` | `text` NOT NULL | |
| audit columns | | |

Index: `(SupportTicketId, CreatedDate)`.

### Reference generation

`TicketReference` is generated in `CreateSupportTicketHandler`. Use `NumberSequenceGenerator` **only if** a `SUPPORTTICKET` entity registration is trivially addable through the existing idempotent `BulkRegister` seed; otherwise use `"SUP-" + (MaxId + 1).ToString("000000")` computed inside the same transaction. Do not invent a third numbering mechanism. State in the build log which path was taken and why.

### Seed — `sql-scripts-dyanmic/platform-support-menu-capability-seed.sql`

One file, idempotent, no DDL, safe to re-run. Header block must carry the schema note (`auth` not `app`), the two-required-checks note, and the `ISMENURENDER`-never-inserted rule — copy the header shape from `sql-scripts-dyanmic/platform-intimations-menu-capability-seed.sql`, which is the house template.

Contents, in order:
1. Menu `PLATFORM_SUPPORTDESK`, `MenuUrl = '/ops/support'` (leading slash, unique), under the existing ops parent. Existing Audit is `OrderBy 940` (`ops-platform-rbac-seed.sql:84`) — place Support at `950`.
2. Capabilities `PLATFORM_SUPPORTDESK_VIEW`, `PLATFORM_SUPPORTDESK_MANAGE`. Idempotency guard checks `CapabilityName` — `auth."Capabilities"` has a UNIQUE index on `(CapabilityName, IsActive)`, not on the code.
3. **`PLATFORM_AUDIT_VIEW` already exists** — seeded at `ops-platform-rbac-seed.sql:108` and granted to `PLATFORM_ADMIN` (:158) and `SUPERADMIN` (:183) on menu `PLATFORM_AUDIT` (:84, `/ops/audit`). Reuse it. **Do not insert it, do not re-grant it, do not touch those rows.** P-3 needs no new RBAC at all — the screen simply starts honouring a grant that already exists.
4. `MenuCapabilities` rows linking `PLATFORM_SUPPORTDESK` to its two capabilities. `PLATFORM_AUDIT`'s link already exists (`platform-menu-capability-backfill-seed.sql:92`) — leave it alone.
5. `RoleCapabilities` grants on `PLATFORM_SUPPORTDESK` for the `PLATFORM_SUPPORT` and `PLATFORM_ADMIN` roles and `SUPERADMIN` — including `ISMENURENDER`, without which the menu is invisible. Note the deliberate near-collision here: role `PLATFORM_SUPPORT` is granted on menu `PLATFORM_SUPPORTDESK`. Write the tuples with a comment so the next reader does not "fix" it.
6. Closing verify block. Two counts must both be **0**: menus with a capability but no `ISMENURENDER` grant; and `MenuCapabilities` rows pointing at a non-existent `MenuCode`.

---

## ⑩ Acceptance criteria

Each is greppable or runnable.

1. `grep -n "FeedbackLauncher" src/presentation/components/layout-components/app-topbar/index.tsx` → mounted, guarded by `!isPlatformUser`.
2. `grep -rn "brandSolid\|--shell-accent" src/presentation/components/layout-components/feedback-launcher/` → non-zero. The tenant dialog follows the tenant accent.
3. `grep -rn "bg-primary-600" src/presentation/components/layout-components/feedback-launcher/` → **0 matches**.
4. `grep -rn "bg-muted\|text-muted-foreground\|bg-\(rose\|amber\|blue\|emerald\|violet\|slate\)-\(50\|100\)" src/presentation/components/page-components/ops/support/ src/presentation/components/page-components/ops/audit/` → **0 matches** on status/badge/icon-container elements.
5. `grep -rn "CompanyId" Base.Domain/Models/OpsModels/SupportTicket.cs` → matches `RaisedByCompanyId` only; **no bare `CompanyId` property**.
6. `grep -n "IgnoreQueryFilters" Base.Application/Business/OpsBusiness/Support/Queries/*.cs Base.Application/Business/OpsBusiness/PlatformAudit/Queries/GetPlatformAuditTrail.cs` → present in every file, each paired with an `IsDeleted != true` guard.
7. `grep -n "TargetCompanyId ==" GetPlatformAuditTrail.cs` → appears only inside the optional-filter branch, never unconditionally.
8. `grep -rn "ControlPlaneComingSoon" src/app/\[lang\]/\(master\)/ops/audit/page.tsx` → **0 matches**.
9. `grep -rn "_data/" src/presentation/components/page-components/ops/audit/` → **0 matches**. Audit is never dummied.
10. `grep -n "DELETE FROM auth" sql-scripts-dyanmic/platform-support-menu-capability-seed.sql` → **0 matches**.
11. `grep -n "ISMENURENDER" platform-support-menu-capability-seed.sql` → appears in a `RoleCapabilities` grant, and in **no** `INSERT INTO auth."Capabilities"`.
11b. `grep -rn "PLATFORM_SUPPORT'" sql-scripts-dyanmic/platform-support-menu-capability-seed.sql` → matches **only** in the role-code position of a grant tuple. The new menu code is `PLATFORM_SUPPORTDESK` and appears nowhere as `PLATFORM_SUPPORT`.
11c. `grep -n "PLATFORM_AUDIT_VIEW" sql-scripts-dyanmic/platform-support-menu-capability-seed.sql` → **0 matches**. It already exists and is already granted; this seed must not touch it.
12. The seed's closing verify block returns 0 and 0.
13. `grep -rn "ExecuteSqlRaw\|FromSqlRaw" Base.Application/Business/OpsBusiness/Support/` → **0 matches**.
14. `PlatformAuditWriter` is called from `UpdateSupportTicketHandler` — `grep -n "PlatformAudit" UpdateSupportTicket.cs` → non-zero.
15. `TenantAuditRowDto` is byte-identical to its pre-build state — `git diff` on `PlatformAuditSchemas.cs` shows only additions.
16. Every new `gql` document's field names were read off the resolver, not guessed. Spot-check: the audit query selects `platformAuditTrail`, not `getPlatformAuditTrail`.
17. No migration file, snapshot file, or `dotnet` invocation appears in the change set.
18. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` → **exit 0**. A run reporting only a "pre-existing" `TS2688` config error checked **zero files** and does not count.

---

## ⑪ Work order

**Build agent: Sonnet** (BE and FE). §④–⑨ are specified to the field level.

1. Read `GetTenantAuditTrail.cs`, `PlatformAuditSchemas.cs`, `PlatformAuditLog.cs`, `PlatformAuditWriter.cs`, `tenant-audit-tab.tsx`, `platform-intimations-list-page.tsx`, `platform-intimations-menu-capability-seed.sql`, `app-topbar/index.tsx`, `brand-surface.ts`. Do not start writing before all nine are read.
2. **Code collisions are already resolved — do not re-litigate them.** Verified 2026-08-11: `PLATFORM_SUPPORT` is a role code (taken, hence `PLATFORM_SUPPORTDESK`); `PLATFORM_AUDIT_VIEW` and menu `PLATFORM_AUDIT` both already exist and are already granted. Before writing the seed, confirm only that `PLATFORM_SUPPORTDESK` returns **0 matches** across `sql-scripts-dyanmic/`. If it does not, **stop and report** — a colliding menu code silently re-points live grants.
3. Confirm `PlatformAuditWriter`'s public surface before designing the audit call in `UpdateSupportTicketHandler`. If it needs a `TargetCompanyId` you do not have at that point, say so rather than passing null.
4. Backend: entities → configurations → `DbSet`s → schemas → handlers → endpoints. `GetPlatformAuditTrail` first (smallest, and it validates the pattern), then the support side.
5. Frontend: DTOs → gql documents → badges → list pages → drawer → launcher → topbar mount → route wrappers.
6. Seed script last, after the menu URLs are final.
7. `npx tsc --noEmit --incremental false`. Exit 0 or keep working.
8. Report: the migration spec (§⑨) verbatim for the user to author, the seed file path, the reference-generation path taken (§⑨), and anything in §⑩ that could not be satisfied — with the reason, not a workaround.

**Hand back to the user, do not do yourself:** the EF migration, `dotnet build`, applying the seed.

---

## ⑫ Build log

*(append-only, newest first, last 5 sessions — git keeps the rest)*

| Date | Session | Outcome |
|---|---|---|
| 2026-08-11 | pre-flight | Ready to run. Seed-code check corrected three assumptions: `PLATFORM_SUPPORT` is a **role** code → new menu is `PLATFORM_SUPPORTDESK`; `PLATFORM_AUDIT_VIEW` **already exists and is already granted** → P-3 needs no RBAC seed; Audit menu is `OrderBy 940` → Support takes `950`. AI module build confirmed landed (12 `(core)/ai` routes + `ai-module-promotion-seed.sql` on disk) — no route-group overlap with this build. |
| 2026-08-11 | prompt authored | Not yet built. Facts verified on disk: no support ticket entity exists anywhere; audit data layer complete and per-tenant only; `/ops/audit` is a `ControlPlaneComingSoon` placeholder; `ApplyGridFeatures` maps in memory via `ToDtoList`, not `ProjectTo`. |

### Known issues

- **`FEATURE:INTELLIGENCE` visibility decision still open** (carried from the AI module prompt) — hide the AI module on FREE/PLAN_50K, or show it locked as an upgrade lever. Unrelated to this build but unanswered.
- **No blob storage** blocks screenshot attachment (§④) and, separately, real grant file upload.
