# PROMPT 21 — Lead Ownership, Assignment & Account-Manager Continuity

**Status:** NOT BUILT.
**Surface:** BE (assign command + history table + assignee picker + "my leads") · FE (`/ops/leads` assign action, owner column, My Leads default) · migration spec (user-owned) · seed SQL (user-applied).
**Depends on:** P-05 lead slice (built), P-04 provisioning (built), P-20 product enquiry (built).
**Trigger:** *"assign the staff for that lead, then that particular staff will communicate and maintain that lead and onboarding — everything should be that person. And track who assigned the managing person."*

---

## ⚠️ Rules for whoever builds this

1. **Do not run `dotnet build`.** The user builds the backend.
2. **Migrations are strictly user-owned.** Never run `dotnet ef migrations add` / `database update` / `remove`, and never hand-author a migration or a snapshot. Write the *spec* (§3.7); the user authors, runs and commits it.
3. **Seed SQL is written, not run.** Files go in `sql-scripts-dyanmic/`; the user applies them.
4. **Frontend typecheck:** `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, no pipe. Only exit 0 counts as clean.
5. **`PSS_2.0_Backend/` is gitignored** — Grep/Glob return zero `.cs` matches. Use `find -iname`, or scope `grep -rn --include=*.cs` to **one** project subdirectory (a repo-wide backend grep times out at 120 s). Absolute-path `Read` works.
6. **HotChocolate strips `Get`** from every resolver and appends `Input` to input types: `GetAssignableLeadOwners` → `assignableLeadOwners`, `AssignLeadInputDto` → `AssignLeadInputDtoInput`. tsc cannot see gql field names — a wrong name builds clean and fails only at runtime.
7. **DB is UTC-only.** Use `DateTime.UtcNow`; never `DateTime.Today` in an EF predicate.
8. **`ops` is platform-global.** Every read needs `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true` guard — platform callers have `CurrentTenantId == null`, so the tenant filter is off and soft-deleted rows would otherwise come back.

---

## ⓪ Verified on disk 2026-08-03

| What | Where | State |
|---|---|---|
| Owner column | `Base.Domain/Models/OpsModels/Lead.cs:38` | `public int? OwnerUserId { get; set; }` — *"Owning platform sales user — FK → auth.Users (optional; unassigned leads are legal)"*. **Already exists.** |
| Index / FK | `LeadConfiguration.cs:40-44` | `HasIndex(l => l.OwnerUserId)`. **Deliberately NO FK** — comment: *"auth.Users is tenant-scoped and platform users are…"*. Keep that decision; new columns follow it. |
| Filter | `GetLeads.cs:64` | `ownerUserId` filter already implemented. |
| Display name | `GetLeads.cs:104-140` (`EnrichAsync`, shared with `GetLeadById`) | Batched owner lookup → `OwnerName`. ⚠️ Selects **`u.UserName`**, not a display name. |
| DTOs | `LeadSchemas.cs:28, 53` | `OwnerUserId` on both request and response; `OwnerName` on response. |
| Write path | `UpdateLead.cs` | Owner is set by `dto.Adapt(entity)` inside the generic edit. `[CustomAuthorize("PLATFORM_LEADS", "PLATFORM_LEAD_EDIT")]`. |
| Lifecycle | `LeadHelper.cs:35-51` | `NEW → QUALIFIED\|LOST`, `QUALIFIED → LOST`, `LOST → NEW`. **`WON` is never a manual target** — only `ApproveCommercialTerm` sets it. Same-state is always allowed. |
| Conversion freeze | `UpdateLead.cs:68-75` | Once `ConvertedCompanyId != null`, **only `Notes` is editable** and status cannot move. Matters in §3.6. |
| Capabilities | `sql-scripts-dyanmic/ops-platform-rbac-seed.sql:99-101` | `PLATFORM_LEAD_VIEW` (86), `PLATFORM_LEAD_EDIT` (87), `PLATFORM_LEAD_EXPORT` (88). **No assign capability exists.** `PLATFORM_LEAD_EDIT` is held by `PLATFORM_SALES`, `PLATFORM_ADMIN`, `SUPERADMIN`. |
| Acting user | `Base.API/EndPoints/Ops/Mutations/TenantProvisioningMutations.cs:50-57` | `TryGetActingUserId` reads the JWT **`"UserId"`** claim at the **mutation layer**; the command layer stays pure and receives it as a parameter. **Copy this pattern exactly** — there is no `ICurrentUserService`. |
| Provisioning run | `TenantProvisioningRun.cs` | Has `LeadId?`, `CommercialTermId?`, `CompanyId?`, `InitiatedByUserId?`. **No owner/account-manager field.** |
| FE list | `.../page-components/ops/leads/lead-list-page.tsx:77, 94, 321` | Owner filter + owner column already render. |
| FE form | `.../ops/leads/lead-form-dialog.tsx:111` | Owner is **not** an editable field. |

### The three defects this prompt exists to close

**D1 — `OwnerUserId` is completely unvalidated.** Neither `CreateLeadValidator` nor `UpdateLeadValidator` mentions it, and there is no FK. Any integer is accepted: a tenant user, a soft-deleted user, an inactive user, `999999`. The grid then renders `—` because `EnrichAsync` finds no matching row, so a lead can look unassigned while carrying a junk owner.

**D2 — silent reassignment by anyone who can edit.** `UpdateLead` sets the owner through `dto.Adapt(entity)` under `PLATFORM_LEAD_EDIT`, which every salesperson holds. One salesperson can take a colleague's lead, or drop their own, and **nothing anywhere records that it happened or who did it**. This is precisely the "track who assigned the managing person" the request asks for, and it does not exist today.

**D3 — the frontend comment is false.** `lead-form-dialog.tsx:111` says *"OwnerUserId is stamped server-side from the acting platform user on create."* Grepped: **`CreateLead.cs` never touches `OwnerUserId`.** So every lead created through the UI is born unowned, and — because `lead-list-page.tsx:94` builds the owner filter dropdown from the owners *visible in the currently loaded rows* — the filter is empty on an all-unowned table. Delete the comment; do not implement what it claims (§3.2 explains why create-time auto-stamping is the wrong fix).

---

## ① The one idea

**Ownership is a governed event, not a form field.**

The column exists, is indexed, is filtered on, and is already rendered. What is missing is that changing it is currently indistinguishable from editing a phone number: no dedicated permission, no record of who did it, no validation that the target is even a platform employee, and no consequence downstream.

So this build adds one thing and lets everything else follow from it: **an `AssignLead` command that is the only path to `Lead.OwnerUserId`**, writing a history row every time, validating the assignee is real platform staff, and carrying the resulting owner forward into provisioning so the same human owns the relationship from first enquiry to live tenant.

**Corollary:** `OwnerUserId` must be removed from the `UpdateLead` write path. If two paths can set it, the history table is a lie the first time someone uses the other one.

---

## ② Design

### 2.1 `AssignLead` — the only writer

```
Base.Application/Business/OpsBusiness/LeadManagement/Commands/AssignLead.cs
Base.API/EndPoints/Ops/Mutations/LeadMutations.cs          (extend existing file)
```

```csharp
[CustomAuthorize("PLATFORM_LEADS", "PLATFORM_LEAD_ASSIGN")]
public record AssignLeadCommand(int LeadId, int? AssigneeUserId, string? Note, int ActingUserId)
    : ICommand<AssignLeadResult>;
public record AssignLeadResult(int LeadId, int? OwnerUserId, string? OwnerName);
```

`ActingUserId` is **not** client-supplied — the mutation layer resolves it from the `"UserId"` claim exactly as `TenantProvisioningMutations.TryGetActingUserId` does, and returns `UnAuthorized` if the claim is missing or unparseable. A client-settable "assigned by" would defeat the entire audit trail.

`AssigneeUserId = null` means **unassign** (§2.5).

**Handler order — validate before you mutate:**

1. Load the lead (`IgnoreQueryFilters()` + `IsDeleted != true`); `NotFoundException` if absent.
2. If `AssigneeUserId` is non-null, assert the target is **platform staff** (§2.3). Reject otherwise.
3. **Idempotency:** if `AssigneeUserId == entity.OwnerUserId`, return success and write **no history row**. A double-clicked assign button must not produce two rows saying the same thing.
4. Close the open `LeadAssignment` row (`UnassignedOn = UtcNow`), if one exists.
5. Insert the new `LeadAssignment` row (skip when unassigning).
6. Update the lead: `OwnerUserId`, `AssignedByUserId = ActingUserId`, `AssignedOn = UtcNow`, `ModifiedDate = UtcNow`.
7. If the lead is already converted, propagate to `Company.AccountManagerUserId` (§3.6).
8. `SaveChangesAsync` — steps 4–7 are **one** SaveChanges, so a partial write is impossible.
9. Notify the new owner (§2.6) — **after** the save, fire-and-forget.

### 2.2 Who may assign — and the self-claim carve-out

New capability **`PLATFORM_LEAD_ASSIGN`** (§3.8 seeds it). Granted to `PLATFORM_ADMIN` and `SUPERADMIN`.

But an assign-only-by-admin model means a salesperson who spots an unowned inbound enquiry at 9pm has to wait for an administrator to hand it to them, and in practice they will instead just work it without owning it — which is exactly the untracked state this prompt is trying to end. So:

| Action | Requires |
|---|---|
| Claim an **unowned** lead for **yourself** | `PLATFORM_LEAD_VIEW` only |
| Assign an **unowned** lead to **someone else** | `PLATFORM_LEAD_ASSIGN` |
| **Reassign** a lead that already has an owner (to anyone, including yourself) | `PLATFORM_LEAD_ASSIGN` |
| **Unassign** (`AssigneeUserId = null`) | `PLATFORM_LEAD_ASSIGN` |

Self-claim is safe because it is only reachable when `OwnerUserId IS NULL` — it can take work *on*, never take work *away*. Every path still writes the same history row, so a self-claim is as visible as an admin assignment.

⚠️ **`[CustomAuthorize]` on the command record cannot express this**, because it is a static attribute and the rule depends on the row's current state. Attribute the command with `PLATFORM_LEADS`/`PLATFORM_LEAD_VIEW` (the floor everyone needs) and enforce the `PLATFORM_LEAD_ASSIGN` requirement **inside the handler** for the three privileged branches, throwing `ForbiddenException`. Write this in a comment above the attribute or the next person will "tidy" it back to a plain attribute.

### 2.3 The assignee must be platform staff

Reuse the discriminator decided in **PROMPT-19 Phase 2 §11.4** — a platform user is an `auth.Users` row holding at least one active `UserRole` on a `Role` where `CompanyId IS NULL`:

```csharp
var isPlatformStaff = await dbContext.Users
    .IgnoreQueryFilters().AsNoTracking()
    .AnyAsync(u => u.UserId == assigneeUserId
                && u.IsActive == true && u.IsDeleted != true
                && u.UserRoles.Any(ur => ur.IsActive == true && ur.IsDeleted != true
                                      && ur.Role!.CompanyId == null), ct);
```

**Do not use `User.CompanyId IS NULL` alone** — same warning as PROMPT-19 §11.4. The roles are the authority.

Reject with a specific `BadRequestException` here. This is an authenticated platform-staff surface, not a public form — the generic-error rule from PROMPT-20 §3.3 does not apply, and a vague failure would just waste an administrator's afternoon.

Closes **D1** for the assign path. §2.4 closes it for the edit path.

### 2.4 Remove the owner from `UpdateLead`

- Drop `OwnerUserId` from `LeadRequestDto`, **or** — if you would rather not churn the DTO — preserve it explicitly in the handler the way `ConvertedCompanyId` already is:

```csharp
var ownerUserId = entity.OwnerUserId;
dto.Adapt(entity);
entity.ConvertedCompanyId = convertedCompanyId;   // existing
entity.OwnerUserId        = ownerUserId;          // NEW — assignment is AssignLead's job only
```

**Prefer removing it from the DTO.** A field that is accepted and silently ignored is a trap for the next caller, and GraphQL will happily keep advertising it. Removing it is a breaking schema change for exactly one consumer — the lead form dialog, which never sent it anyway (D3).

Also drop it from `LeadRequestDto`'s create path for the same reason. Closes **D2**.

### 2.5 Unassign, and the gate that makes unowned leads harmless

Unassigning is legitimate — someone leaves, a lead goes cold, a territory changes. It closes the open history row and sets `OwnerUserId = NULL`, `AssignedByUserId = ActingUserId`, `AssignedOn = UtcNow` (the stamp records *when it became unowned and who did that*, which is the useful fact).

**Gate:** a lead may not leave `NEW` while unowned. Add to `UpdateLeadValidator`/handler: a transition to `QUALIFIED` requires `entity.OwnerUserId != null`.

This is the right place for the gate, and provisioning is not. Blocking `ProvisionTenant` on a bookkeeping field is how a signed deal stalls on a Friday evening; blocking *qualification* costs one click at the moment a human is already looking at the lead. Everything downstream of `QUALIFIED` — deals, approval, provisioning — then inherits an owner for free, because `WON` is only reachable from `QUALIFIED`.

`LOST` is deliberately **not** gated: closing out an unowned dead lead should never require assigning it to someone first.

### 2.6 Notify the new owner

On successful assignment, email the assignee through the platform's own sender (`ops.PlatformCommunicationProviders`, EMAIL channel) — the same path PROMPT-20 uses, **not** a tenant provider.

Include: company name, contact name + email, source, status, the assigner's name, the optional note, and a deep link to `/ops/leads?leadId=…`.

**Fire-and-forget. A failed notification must never fail the assignment** — the ownership row is already durable, and losing the email costs a delay while losing the assignment costs the deal. If no platform EMAIL provider row exists, log a warning and return success.

Do not notify on **self-claim** (the person is looking at the screen) or on **unassign** with no new owner. Optionally notify the *previous* owner on reassignment — worth doing, but it is a courtesy, so put it behind the same fire-and-forget and never let it fail anything.

### 2.7 "My leads"

The whole point of assignment is that the owner has a queue. Add `mine: bool?` to `GetLeadsQuery`, resolved **server-side from the acting user's claim**:

```csharp
if (query.mine == true && actingUserId.HasValue)
    filteredQuery = filteredQuery.Where(l => l.OwnerUserId == actingUserId.Value);
```

`mine` and a client-supplied `ownerUserId` are different things and must stay different: never implement "mine" by having the frontend pass its own user id, because that is a filter anyone can point at anyone. (Lead *visibility* stays platform-wide — this is a default view, not a security boundary. If leads should be invisible across owners, say so; that is a different and much larger change, §⑨ Q4.)

Also add `unassigned: bool?` → `OwnerUserId == null`. The unowned queue is the one an administrator actually needs to see, and inbound enquiries from PROMPT-20 land straight in it.

### 2.8 The assignee picker

New anonymous-to-platform-staff query:

```
GetAssignableLeadOwnersQuery → IReadOnlyList<{ UserId, UserName, DisplayName, RoleNames[] }>
[CustomAuthorize("PLATFORM_LEADS", "PLATFORM_LEAD_VIEW")]
```

Active, non-deleted users matching the §2.3 platform-staff predicate, name-ordered. Small and stable — cache ~5 min.

This also replaces the `lead-list-page.tsx:94` hack that derives the owner filter from whatever rows happen to be loaded. That approach cannot show an owner whose leads are on page 2, and shows nothing at all when the table is empty.

⚠️ `EnrichAsync` currently returns **`u.UserName`** as `OwnerName` — a login handle, not a person's name. Resolve a real display name in both the picker and `EnrichAsync` (check what `auth.Users` actually carries — `FirstName`/`LastName`/`DisplayName` — and fall back to `UserName`). Do this once, in a shared helper, so the grid and the dropdown cannot disagree about what a person is called.

---

## ③ Data

### 3.1 `ops.LeadAssignments` — the history

The request is explicitly *"track who assigned the managing person"*. A pair of columns on `Lead` records only the **current** state; the moment a lead is reassigned, the previous assignment is gone. The question sales will ask within a month — *"how long did this sit with Rahim before it moved?"* — needs rows.

```csharp
[Table("LeadAssignments", Schema = "ops")]
public class LeadAssignment : Entity
{
    public int LeadAssignmentId { get; set; }
    public int LeadId { get; set; }
    public virtual Lead? Lead { get; set; }

    /// <summary>Platform user who owns the lead for this interval. No FK — auth.Users is
    /// tenant-scoped; same reasoning as Lead.OwnerUserId (LeadConfiguration.cs:40).</summary>
    public int AssignedToUserId { get; set; }

    /// <summary>Platform user who performed the assignment. Equals AssignedToUserId on a self-claim.</summary>
    public int AssignedByUserId { get; set; }

    public DateTime AssignedOn { get; set; }

    /// <summary>NULL ⇒ this is the currently open assignment. Exactly one open row per lead.</summary>
    public DateTime? UnassignedOn { get; set; }

    public string? Note { get; set; }
}
```

**Indexes:** `(LeadId, UnassignedOn)` for "the current owner of this lead", and `(AssignedToUserId, UnassignedOn)` for "everything currently on Rahim's desk".

**Invariant: at most one open row per lead.** Enforce in the handler (close-then-insert in one SaveChanges). A partial unique index (`WHERE "UnassignedOn" IS NULL`) would enforce it in the database, but EF Core's `HasFilter` on a soft-delete-bearing table is easy to get subtly wrong — enforce in code, and add the detection query to acceptance (§⑧).

**Never soft-deleted in practice.** `LeadAssignment` inherits `IsDeleted` from `Entity`, but nothing should ever set it — history that can be erased is not history. Guard reads with `IsDeleted != true` anyway, per rule 8.

### 3.2 Current-state columns on `ops.Leads`

```csharp
/// <summary>Platform user who last set OwnerUserId. NULL ⇒ never assigned.</summary>
public int? AssignedByUserId { get; set; }

/// <summary>UTC instant OwnerUserId last changed (including to NULL).</summary>
public DateTime? AssignedOn { get; set; }
```

Denormalised deliberately: the grid shows owner + assigned-by + age-in-queue on every row, and a per-row join to the history table for a 50-row page is a waste when the open row is by definition the one on the lead.

### 3.3 `app.Companies.AccountManagerUserId`

*"…and onboarding — everything should be that person."* The relationship must survive conversion, and it must survive the provisioning run, so it cannot live on `TenantProvisioningRun` (which is a job record that completes and stops being interesting).

```csharp
/// <summary>Platform user who owns this customer relationship — carried over from the originating
/// Lead.OwnerUserId at provisioning time. NULL for tenants created before P-21 or without a lead.
/// No FK: platform users are not tenant-scoped. Platform-facing only — never shown to the tenant.</summary>
public int? AccountManagerUserId { get; set; }
```

Stamped by `ProvisionTenant` (§3.6), thereafter maintained by `AssignLead` on a converted lead, and surfaced on `/ops/tenants`.

**It lives on `app.Companies` rather than an `ops` side-table** because it is 1:1 with the tenant, is read on every tenant list render, and an `ops.TenantAccountManagers` table would be a join that only ever returns one row. The cost is a platform concept sitting on a tenant table — acceptable, and flagged as §⑨ Q3 if you disagree.

### 3.4 `TenantProvisioningRun.OwnerUserId`

Snapshot the lead's owner onto the run at creation time, alongside the existing `InitiatedByUserId`. These are genuinely different people: the owner is the salesperson who has been talking to the prospect for six weeks; the initiator may be whoever happened to run the wizard. Recording only one of them loses the fact that they differed.

### 3.5 What the lead detail screen shows

An **Assignment** panel: current owner, assigned by, assigned on, time-in-queue, and the history as a reverse-chronological list (`AssignedToUserId`, `AssignedByUserId`, interval, note). Add `GetLeadAssignments(leadId)` or fold the list into `GetLeadById`'s response — prefer folding it in; it is a bounded list and one fewer round trip.

### 3.6 Conversion: the freeze rule and the assign rule deliberately differ

`UpdateLead` freezes a converted lead to `Notes`-only. **`AssignLead` must NOT be frozen.** A tenant's account manager leaves the company a year after go-live and the relationship has to move to someone else — that is the single most likely assignment ever performed, and the freeze would block it.

So on a converted lead, `AssignLead`:
- writes the history row and the `Lead` columns as normal, **and**
- updates `Company.AccountManagerUserId` on the converted company in the same `SaveChanges`.

`ProvisionTenant` gains one line at the point it stamps `Lead.ConvertedCompanyId`: copy `lead.OwnerUserId` into `company.AccountManagerUserId` and onto the run. If the lead is unowned (legal but unusual — §2.5 means it will have had an owner at `QUALIFIED`, but the owner could have been removed since), leave both null and **log a warning**; do not block provisioning.

### 3.7 Migration spec — hand this to the user, do not run it

```
Add_LeadAssignment_And_AccountManager

  CREATE TABLE ops."LeadAssignments"
      LeadAssignmentId  serial PK
      LeadId            int          NOT NULL  FK → ops."Leads"("LeadId")
      AssignedToUserId  int          NOT NULL          -- no FK (auth.Users is tenant-scoped)
      AssignedByUserId  int          NOT NULL          -- no FK
      AssignedOn        timestamptz  NOT NULL
      UnassignedOn      timestamptz  NULL
      Note              varchar(500) NULL
      + the standard Entity audit columns (CreatedDate/ModifiedDate/IsDeleted/…)
      INDEX IX_LeadAssignments_LeadId_UnassignedOn          (LeadId, UnassignedOn)
      INDEX IX_LeadAssignments_AssignedToUserId_UnassignedOn (AssignedToUserId, UnassignedOn)

  ops."Leads"        + AssignedByUserId       int          NULL
  ops."Leads"        + AssignedOn             timestamptz  NULL
  app."Companies"    + AccountManagerUserId   int          NULL
  ops."TenantProvisioningRuns" + OwnerUserId  int          NULL
```

All additive, all nullable except inside the new table, no backfill required.

**Optional backfill, user's call:** existing leads with a non-null `OwnerUserId` have no history row, so their Assignment panel will show a current owner with an empty history. A one-off seed can synthesise an opening row (`AssignedOn = Lead.CreatedDate`, `AssignedByUserId = AssignedToUserId`, `Note = 'Backfilled — pre-P-21 assignment, assigner unknown'`). Worth doing, and the note must say it is synthetic — an invented audit row that looks genuine is worse than a gap. Ships as `sql-scripts-dyanmic/lead-assignment-history-backfill.sql`.

### 3.8 Seed — `sql-scripts-dyanmic/ops-lead-assign-capability-seed.sql`

Idempotent, following the shape of `ops-platform-rbac-seed.sql`:

```
auth."Capabilities"  + ('Platform Assign Leads', 'PLATFORM_LEAD_ASSIGN',
                        'Assign or reassign a lead to a platform staff member.', 89)
auth."RoleCapabilities" grants:
    PLATFORM_ADMIN → PLATFORM_LEADS / PLATFORM_LEAD_ASSIGN
    SUPERADMIN     → PLATFORM_LEADS / PLATFORM_LEAD_ASSIGN
```

`89` sits in the gap between `PLATFORM_LEAD_EXPORT` (88) and `PLATFORM_TENANT_VIEW` (90) — verify it is still free before writing.

**`PLATFORM_SALES` is deliberately not granted it** — sales self-claims unowned leads under §2.2 without it. Flag as §⑨ Q1; if the user wants a sales manager who can move work between reps, the answer is a grant to `PLATFORM_SALES`, or a sixth role, not a code change.

---

## ④ Build steps

1. **BE — entity + config:** `LeadAssignment.cs`, `LeadAssignmentConfiguration.cs`, `DbSet` on `IApplicationDbContext`/`OpsDbContext`, the four added columns (§3.2–3.4).
2. **Migration spec** (§3.7) → hand to the user and **stop**. Steps 3+ do not compile until it is applied.
3. **BE — `AssignLead`** command/validator/handler + mutation endpoint with `TryGetActingUserId` (§2.1–2.3, §2.5).
4. **BE — close the second write path:** remove `OwnerUserId` from `LeadRequestDto`; preserve it in `UpdateLeadHandler` (§2.4). Add the `QUALIFIED`-requires-owner gate (§2.5).
5. **BE — `GetAssignableLeadOwners`** + the shared display-name helper; fix `EnrichAsync`'s `UserName` (§2.8).
6. **BE — `mine` / `unassigned` filters** on `GetLeads`; assignment history on `GetLeadById` (§2.7, §3.5).
7. **BE — `ProvisionTenant`** stamps `Company.AccountManagerUserId` + `run.OwnerUserId` (§3.6).
8. **Seed** (§3.8) — write, do not run.
9. **FE — assign action** on `/ops/leads`: row action + bulk-select assign, dialog with the assignee combobox (searchable — a platform can have 30 staff) and an optional note.
10. **FE — filters:** My Leads / Unassigned / All segmented control, defaulting to **My Leads** for a user without `PLATFORM_LEAD_ASSIGN` and **Unassigned** for one with it. Replace the derived owner dropdown (`lead-list-page.tsx:94`) with `assignableLeadOwners`.
11. **FE — grid columns:** Owner, Assigned By, Assigned (relative age). Delete the false comment at `lead-form-dialog.tsx:111`.
12. **FE — lead detail Assignment panel** (§3.5).
13. **FE — `/ops/tenants`** shows Account Manager.
14. **Typecheck** — exit 0. Then update §⑬ and the task list.

---

## ⑤ UI notes

- **Assignee combobox is searchable and shows the role** — "Fatima (Platform Sales)" disambiguates two Fatimas without an org chart.
- **Bulk assign** matters: the realistic action is "twelve inbound enquiries arrived overnight, give them all to Rahim". One dialog, one confirmation, N history rows.
- **"Assign to me"** as a one-click shortcut on any unowned row — that is the §2.2 self-claim path and it should cost one click, not a dialog.
- **Unassigned rows need to be visible**, not merely filterable: a muted "Unassigned" chip in the Owner cell, not an em-dash that reads as "no data".
- **Time-in-queue is the number a sales manager actually scans for.** Relative ("3 days"), with the absolute UTC-rendered-local timestamp in a tooltip.
- **Icon container / status chips:** solid `bg-X-600` + `text-white`, per house style. No `bg-X-50`/`text-X-700`.
- Design tokens only — no raw hex, no raw px. `@iconify` Phosphor icons. Shaped skeletons for the history list. xs→xl responsive; `ar` is RTL, so logical properties (`ms-`/`me-`/`text-start`).
- The assign dialog's confirm button is gated by RHF `formState.isValid`, never by a capability flag — capability controls whether the *entry point* renders.

---

## ⑥ Invariants

1. **`AssignLead` is the only writer of `Lead.OwnerUserId`.** If any other path can set it, the history is wrong.
2. **Every ownership change writes exactly one `LeadAssignment` row** — including self-claims, unassignments and admin reassignments.
3. **At most one open (`UnassignedOn IS NULL`) row per lead**, always.
4. **`AssignedByUserId` comes from the JWT claim**, never from the request body.
5. **The assignee must be platform staff** by the §2.3 role predicate — never `User.CompanyId IS NULL` alone.
6. **Assigning to the current owner is a no-op**, not a new row.
7. **A lead cannot reach `QUALIFIED` unowned.** `LOST` is exempt.
8. **Conversion does not freeze assignment**, even though it freezes everything else.
9. **A failed notification never fails an assignment.**
10. **`mine` resolves from the claim**, never from a client-supplied user id.
11. **Assignment history is never soft-deleted.**

---

## ⑦ Out of scope

- Round-robin / auto-assignment of inbound enquiries (§⑨ Q2). Inbound leads land unowned; a human picks them up.
- Ownership-based **visibility** — every platform user still sees every lead (§⑨ Q4).
- Teams, territories, quotas, or a second owner (pre-sales vs implementation). The request is explicitly one person end-to-end.
- SLA timers, escalation on stale unowned leads, "no touch in 7 days" alerts.
- Reassigning `CommercialTerm.ApprovedByUserId` — that is a record of who approved, not who owns, and it is correctly immutable.
- Tenant-side visibility of the account manager. It is platform-facing only.
- Any change to `/ops/leads` beyond assignment.

---

## ⑧ Acceptance

- [ ] Assigning an unowned lead to a platform user sets `OwnerUserId`, `AssignedByUserId` (= the caller, from the claim), `AssignedOn`, and inserts one `LeadAssignments` row with `UnassignedOn IS NULL`.
- [ ] Reassigning closes the prior row (`UnassignedOn` stamped) and opens exactly one new one. `SELECT "LeadId", COUNT(*) FROM ops."LeadAssignments" WHERE "UnassignedOn" IS NULL GROUP BY 1 HAVING COUNT(*) > 1` returns **zero rows** after a reassign, a double-click, and a bulk assign.
- [ ] Assigning to the **current** owner returns success and adds **no** row.
- [ ] Assigning to a **tenant** user → rejected. To a soft-deleted or inactive user → rejected. To `999999` → rejected.
- [ ] A user with only `PLATFORM_LEAD_VIEW` can claim an **unowned** lead for themselves, and is **forbidden** from assigning it to a colleague or from reassigning an owned lead.
- [ ] A crafted mutation supplying its own `assignedByUserId` cannot influence the stored value — **verify by reading the row**, not the response.
- [ ] `UpdateLead` can no longer change the owner: the field is gone from the schema, or a mutation carrying it leaves `OwnerUserId` unchanged in the database.
- [ ] `NEW → QUALIFIED` on an unowned lead is rejected; the same transition succeeds once assigned. `NEW → LOST` succeeds unowned.
- [ ] Unassign sets `OwnerUserId = NULL`, closes the open row, and opens none.
- [ ] Assignment succeeds on a **converted** lead and updates `app.Companies.AccountManagerUserId` on the converted tenant.
- [ ] Provisioning a lead owned by X stamps `Company.AccountManagerUserId = X` and `TenantProvisioningRuns.OwnerUserId = X`, even when a different user ran the wizard (`InitiatedByUserId ≠ OwnerUserId`).
- [ ] Deleting the platform EMAIL provider row → assignment still succeeds, warning logged.
- [ ] `mine: true` returns only the caller's leads; passing another user's id as `ownerUserId` is still permitted (visibility is not scoped) and is a *different* filter.
- [ ] The owner dropdown lists platform staff who own **no** leads — proving it no longer derives from loaded rows.
- [ ] `OwnerName` renders a person's name, not a login handle, in both the grid and the picker.
- [ ] Lead detail shows full history in reverse-chronological order with assigner, assignee, interval and note.
- [ ] Bulk-assigning 12 leads writes 12 rows and sends 1 notification per assignee (not 12 to the same person — batch it, or state plainly that it does not).
- [ ] `ar` renders the assign dialog RTL; xs→xl no horizontal scroll.
- [ ] `npx tsc --noEmit --incremental false` exits 0.

---

## ⑨ Open questions

**Q1 — should `PLATFORM_SALES` get `PLATFORM_LEAD_ASSIGN`?** §2.2/§3.8 says no: sales self-claims unowned leads, and moving work between reps is a manager's act. If there is a sales-manager persona, the fix is a grant or a sixth role, not code. **Blocks step 8.**

**Q2 — auto-assign inbound enquiries?** PROMPT-20 leads arrive unowned by design. Round-robin is tempting and usually regretted — it assigns leads to whoever is on holiday. Recommendation: ship the Unassigned queue first, measure whether anything actually rots in it, and only then automate. Say if you want it now.

**Q3 — `AccountManagerUserId` on `app.Companies`, or an `ops` side-table?** §3.3 argues for the column. The counter-argument is schema purity: a platform concept on a tenant table. Cheap to change now, expensive later.

**Q4 — is lead visibility ever scoped by owner?** Everything above assumes no: all platform staff see all leads, and "My Leads" is a convenience. If a rep must not see another rep's pipeline, that is a filter in `GetLeads` **and** `GetLeadById` **and** the assignee picker **and** exports — a materially bigger change with a real risk of a leak through a path someone forgets.

**Q5 — what is the display-name field on `auth.Users`?** §2.8 needs it. Whatever it is, resolve it once in a shared helper.

**Q6 — should the previous owner be notified on reassignment?** §2.6 suggests yes. It is a small courtesy that occasionally reads as a demotion; your call on the copy.

---

## ⑩ Build log

### 2026-08-03 — built, all 14 steps of §④

**Backend**

| # | What | Where |
|---|---|---|
| 1 | `LeadAssignment` entity + EF config + `DbSet`; `Lead.AssignedByUserId` / `AssignedOn`, `Company.AccountManagerUserId`, `TenantProvisioningRun.OwnerUserId` | `Base.Domain/Models/OpsModels/`, `Base.Infrastructure/.../OpsConfigurations/` |
| 3 | `AssignLead` command + validator + handler; `AssignLeads` bulk; both resolvers (`assignLead`, `assignLeads`) | `Base.Application/Business/OpsBusiness/Leads/Commands/AssignLead.cs`, `Base.API/EndPoints/Ops/Mutations/LeadMutations.cs` |
| 4 | `OwnerUserId` removed from `LeadRequestDto`; Create/Update handlers no longer touch it; `OpsMappings` ignores it | `Base.Application/Schemas/OpsSchemas/LeadSchemas.cs`, `.../Leads/Commands/`, `OpsMappings.cs` |
| 5 | `GetAssignableLeadOwners` + `assignableLeadOwners` resolver (incl. `RoleNames`, `OpenLeadCount`); shared `PlatformUserHelper` (staff predicate + display-name ladder) | `.../Leads/Queries/GetAssignableLeadOwners.cs`, `.../OpsBusiness/Shared/PlatformUserHelper.cs` |
| 6 | `unassignedOnly` + `mine` on `GetLeads` (`mine` resolves from the JWT claim, never a client id); `GetLeadById` returns `AssignmentHistory` | `.../Leads/Queries/` |
| 7 | `ProvisionTenant` stamps `Company.AccountManagerUserId` and `run.OwnerUserId` from the source lead's owner | `.../Tenants/Commands/ProvisionTenant.cs` |
| 13 | `AccountManagerUserId` / `AccountManagerName` on both tenant DTOs; both handlers enrich the name via `PlatformUserHelper` (one bounded lookup per page) | `TenantSchemas.cs`, `GetTenants.cs`, `GetTenantById.cs` |

**Frontend** — `LeadDto` (`AssignableUserDto`, assignment fields, no `ownerUserId` on the request), `LeadMutation`/`LeadQuery` (`assignLead`, `assignLeads`, `assignableLeadOwners`), and under `page-components/ops/leads/`: new `lead-assign-dialog.tsx` (searchable picker showing the role, `UNASSIGN = -1` sentinel → `null`, bulk = one dialog / one confirmation / N history rows, partial-failure toast), `lead-assignment-panel.tsx` (Sheet timeline), `lead-time.ts` (relative age + absolute UTC-rendered-local `title`); `lead-list-page.tsx` rewritten for the server-side My / Unassigned / All views, capability-driven landing view, page-scoped bulk selection, one-click "Assign to me", the muted **Unassigned** chip (no em-dash) and the Assigned-by / Assigned columns. `/ops/tenants` list + detail now show **Account manager** with the same chip.

**Steps 2 & 8 — written, not run (user-owned):** `PSS-2.0-ONBOARDING-PROMPT-21-MIGRATION-SPEC.md`, `sql-scripts-dyanmic/lead-assignment-history-backfill.sql`, `sql-scripts-dyanmic/ops-lead-assign-capability-seed.sql`.

**Step 14:** `npx tsc --noEmit --incremental false` → **exit 0, no diagnostics**. `dotnet build` not run per the rules — the backend compile is the user's.

**Deviations from the spec, for review**
1. The backfill uses `COALESCE(ModifiedDate, CreatedDate)` for `AssignedOn` where §3.7 suggested `Lead.CreatedDate` — a lead owned since creation is rare, and `ModifiedDate` is the closer approximation of when ownership was last touched. Change the one expression if you disagree.
2. The synthetic backfill `Note` is longer than §3.7's `'Backfilled — pre-P-21 assignment, assigner unknown'`; it states explicitly that the row is reconstructed and its timestamp approximate, so no one later reads it as a real episode.

**Still open:** Q1 (does `PLATFORM_SALES` get `PLATFORM_LEAD_ASSIGN`? — the seed follows §3.8 and says **no**; it is one row to add if you decide otherwise) and Q6 (previous-owner notification copy).
