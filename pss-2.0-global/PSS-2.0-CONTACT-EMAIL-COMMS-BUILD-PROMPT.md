# BUILD PROMPT — Contact (#18) Detail Page: 1:1 Communication (Email live · SMS/WhatsApp coming soon)

> Paste this into a fresh session. Companion analysis: `PSS-2.0-CONTACT-1TO1-COMMS-PLAN-AND-REVIEW.md`.
> **Start with `/plan-screens #18`** — this adds a new entity, which exceeds #18's registered ALIGN scope. Do NOT try to ship it through `/continue-screen`.

---

## ① Goal

On the **Contact detail (view) page**, give staff three communication actions — **Email, SMS, WhatsApp**.

- **Email** — fully implemented this phase (compose → send → logged → visible in Communication tab).
- **SMS** and **WhatsApp** — buttons **visible but disabled**, badged **"Coming soon"**. Do NOT wire the send path. The UI contract must be built so Phase 2 only swaps the disabled state for a live channel tab.
- The contact's **preferred communication channel** must be surfaced prominently so staff use the channel the contact actually wants.

Out of scope: bulk send, inbound handling, campaign integration, attachments.

---

## ② What already exists (reuse, do not rebuild)

| Thing | Where | Use for |
|---|---|---|
| `IEmailTemplateService.SendComposedEmailForCompanyAsync(EmailDto, companyId)` | `Base.Application/Data/Services/IEmailTemplateService.cs:24` | the actual send |
| `SendGrantCommunication.cs` | `Base.Application/Business/GrantBusiness/GrantCommunications/CreateCommand/` | **the reference implementation — clone its shape** |
| `GrantCommunication.cs` | `Base.Domain/Models/GrantModels/` | entity shape to model the new log on |
| `Contact.PreferredCommunicationId` → `MasterData` (`PREFERREDCOMMUNICATION`: Email/Phone/SMS/WhatsApp/Postal) | `Base.Domain/Models/ContactModels/Contact.cs:32,58` | preference badge — **already exists, no migration** |
| `Contact.DoNotEmail / DoNotPhone / DoNotSMS / DoNotPostal` | same file, lines 33–36 | consent gate — **already exist** |
| `Contact.ContactEmailAddresses` (`ContactEmailAddress` w/ IsPrimary) | same file | recipient picker |
| `EmailSendQueue.ContactId` (nullable, line 12) + full webhook tracking | `Base.Domain/Models/NotifyModels/EmailSendQueue.cs` | delivery drill-down |
| `TemplatePlaceholderRenderer`, Email Template screen (#24, COMPLETED) | — | template picker |
| Existing read-only Communication tab | `.../crm/contact/contact/detail/tabs/communication-tab.tsx` | **to be replaced** |

---

## ③ Backend

### 3.1 New entity — `contact.ContactCommunications`

Channel-agnostic from day one so SMS/WhatsApp need no migration in Phase 2.

```csharp
[Table("ContactCommunications", Schema = "contact")]
public class ContactCommunication : Entity
{
    public int ContactCommunicationId { get; set; }
    public int ContactId { get; set; }
    public int? CompanyId { get; set; }

    public string Channel { get; set; } = default!;   // EMAIL | SMS | WHATSAPP  (only EMAIL written this phase)
    public string Direction { get; set; } = default!; // OUTBOUND
    public string? Purpose { get; set; }              // FOLLOWUP | THANKYOU | RECEIPT | GENERAL

    public string ToAddress { get; set; } = default!; // email address (E.164 phone later)
    public string? CcEmail { get; set; }
    public string? Subject { get; set; }
    public string Body { get; set; } = default!;
    public string? TemplateCode { get; set; }

    public int? ContactEmailAddressId { get; set; }
    public int? ContactPhoneNumberId { get; set; }
    public int? EmailSendQueueId { get; set; }
    public int? WhatsAppMessageId { get; set; }

    public int? SentByStaffId { get; set; }
    public DateTime SentDate { get; set; }            // DateTime.UtcNow — Kind=Utc mandatory
    public string Status { get; set; } = default!;    // SENT | FAILED | BLOCKED
    public string? BlockedReason { get; set; }        // DO_NOT_EMAIL | NO_ADDRESS | RATE_LIMIT
    public string? ProviderMessageId { get; set; }
    public string? ErrorMessage { get; set; }

    public virtual Contact? Contact { get; set; }
    public virtual Staff? SentByStaff { get; set; }
}
```

**Indexes**: `(CompanyId, ContactId, SentDate DESC)` — the tab's only read path.

**MIGRATION IS USER-OWNED.** Build to prove it compiles, then hand over the migration spec (table + FKs + indexes). Do NOT run `dotnet ef migrations add` / `database update` / `remove`, and do NOT hand-author a migration or model snapshot.

Wiring: add `DbSet<ContactCommunication> ContactCommunications` to `IContactDbContext` + `ContactDbContext.cs`, and an EF configuration. **Warn the user before editing shared wiring files** (`AppDbContext`, `Query.cs`, `Mutation.cs`) — parallel sessions may touch them.

### 3.2 `SendContactEmailCommand`

Clone `SendGrantCommunication.cs` exactly in shape.

```csharp
[CustomAuthorize(DecoratorContactModules.Contact, Permissions.Create)]
[RequiresTenant]
[TenantScope(TenantScopeType.Current)]
public record SendContactEmailCommand(ContactCommunicationRequestDto communication)
    : ICommand<SendContactEmailResult>;
public record SendContactEmailResult(int contactCommunicationId, bool sent, string? blockedReason);
```

**Validator** (`BaseCommandFluentValidator`):

| Rule | Value |
|---|---|
| Required | `ContactId`, `ToEmail`, `Subject`, `BodyHtml` |
| `ValidateStringLength` | ToEmail 320 · CcEmail 500 · Subject 500 · TemplateCode 60 · Purpose 40 · BodyHtml 100000 |
| `.EmailAddress()` | ToEmail always; CcEmail when non-blank |
| `ValidateForeignKeyRecord` | `ContactId` → `dbContext.Contacts` |

**Handler order — do not reorder:**

1. Load contact (`ContactId`, `CompanyId`, `DoNotEmail`) — the global query filter in `ApplicationDbContext.ApplyTenantFilters` already scopes by tenant; no extra CompanyId predicate needed. `NotFoundException` if null.
2. **Consent gate** — if `DoNotEmail == true`: write a `ContactCommunication` row with `Status = "BLOCKED"`, `BlockedReason = "DO_NOT_EMAIL"`, **do not call the provider**, return `(id, sent: false, "DO_NOT_EMAIL")`. The blocked row IS the compliance evidence — always persist it.
3. **Address ownership check** — if `ContactEmailAddressId` was supplied, verify that row belongs to this `ContactId`; if not → `NotFoundException`. (Prevents address injection via a foreign child id.) If not supplied, resolve the contact's `IsPrimary` email; none → `Status = "BLOCKED"`, `BlockedReason = "NO_ADDRESS"`.
4. **Rate guard** — count rows for `(ContactId, Channel = "EMAIL", SentDate >= UtcNow.AddHours(-1))`; if `>= 10` → `Status = "BLOCKED"`, `BlockedReason = "RATE_LIMIT"`. (Constant for now; move to `OrganizationSettings` later.)
5. Build `EmailDto { ToEmail, CcEmail, Subject, EmailContent = BodyHtml }` → `SendComposedEmailForCompanyAsync(emailDto, companyId)` inside `try/catch`. **Never rethrow** on provider failure — `Status = "FAILED"`, `ErrorMessage = ex.Message`.
6. Resolve actor staff id (same helper pattern as `GrantCommunicationHelper.ResolveActorStaffIdAsync`).
7. Persist the log row (`SentDate = DateTime.UtcNow`). Wrap `SaveChanges` in `catch (DbUpdateException) → InternalServerException`.
8. Return `(id, sent, blockedReason)`. FE toasts from `sent`.

### 3.3 `GetContactCommunicationsQuery`

```csharp
[CustomAuthorize(DecoratorContactModules.Contact, Permissions.Read)]
[RequiresTenant]
[TenantScope(TenantScopeType.Current)]
public record GetContactCommunicationsQuery(GridFeatureRequest gridFilterRequest)
    : IQuery<GetContactCommunicationsResult>;
```

Standard paged grid query (copy `GetContact.cs` structure). **Call `ValidateGridFeatures` — do not comment it out** (see ISSUE-26). Project to a response DTO including `Channel, Status, BlockedReason, Subject, ToAddress, SentDate, SentByStaff.DisplayName, ErrorMessage`. Sort default `SentDate DESC`.

### 3.4 GraphQL wiring

Register the mutation + query in `Mutation.cs` / `Query.cs`. Warn user first (shared files).

---

## ④ Frontend

### 4.1 Preferred-communication banner — contact sidebar

In `detail/contact-sidebar.tsx`, above the quick-action row, render a single line:

> `Prefers: [Email]` — solid `bg-primary` chip, `text-white`, icon `ph:envelope-simple` / `ph:phone` / `ph:chat-circle-dots` / `ph:whatsapp-logo` / `ph:mailbox` per `preferredCommunication.dataName`.
> When `preferredCommunicationId` is null → `No preference set` in muted text (do not hide the row — its absence is itself information for staff).

The preferred channel's action button gets a subtle ring (`ring-2 ring-primary`) so staff's eye lands on it first.

### 4.2 Quick-action row — three buttons, one live

Replace the current raw `tel:` / `mailto:` / `wa.me` deep links (lines ~215/224/233).

| Button | State | Behaviour |
|---|---|---|
| **Email** | live | opens compose drawer. **Disabled** when `doNotEmail === true` (tooltip: "Contact has opted out of email") or no email address exists (tooltip: "No email address on file"). |
| **SMS** | disabled | `Coming soon` badge, `cursor-not-allowed`, tooltip "SMS sending is not yet available". No handler. |
| **WhatsApp** | disabled | same, badge `Coming soon`. |
| **Call** | keep `tel:` link | no telephony service exists to route through. Disable when `doNotPhone === true`. |

"Coming soon" badge = solid `bg-slate-600 text-white` per project token rule (never `bg-X-100 text-X-700`). Every icon-only button needs an `aria-label`; disabled reasons must be conveyed by tooltip **and** `title` (not colour alone).

### 4.3 Compose drawer — `detail/communication/compose-email-drawer.tsx`

Single component, built with a **channel tab strip** even though only one tab is enabled — this is the Phase 2 seam.

```
[ Email ]  [ SMS · Coming soon ]  [ WhatsApp · Coming soon ]
   ^live        ^disabled tab          ^disabled tab
```

Email tab fields:

| Field | Control | Rules |
|---|---|---|
| To | select over the contact's own email addresses, primary preselected | **never free-text** — kills typo-sends |
| Cc | optional text | `.email()`, max 500 |
| Template | ApiSelect over email templates (#24), optional | on select → render via placeholder renderer into Body, staff-editable after insert |
| Purpose | select: General / Follow-up / Thank you / Receipt | max 40 |
| Subject | text | required, max 500, live counter |
| Body | rich text / textarea | required, max 100000 |

- Zod schema with `.email()` and `.max()` mirroring the BE caps exactly (this screen currently has **zero** of either — see ISSUE-27; do not repeat that).
- Send button gated on RHF `formState.isValid` — **not** on `canCreate`. Capability only controls whether the Email button appears at all.
- On submit: await mutation → `sent === true` → `toast.success`; `sent === false` with `blockedReason` → `toast.warning` naming the reason; network/GraphQL error → `toast.error`. Then refetch the Communication tab and close.
- Disable the Send button while in-flight and show a spinner — a double-click must not send twice.
- Focus trap + Esc-to-close + focus returns to the triggering button on close.

### 4.4 Communication tab rewrite — `detail/tabs/communication-tab.tsx`

Replace the current implementation.

- Source: `GetContactCommunicationsQuery`, **server-paged 25/page with pagination controls** (current hard cap of `pageSize: 100, pageIndex: 0` silently truncates — ISSUE-30).
- Columns: Date · Channel · Purpose · Subject · Recipient · Sent by · Status.
- Channel filter chips: All / Email / SMS / WhatsApp (SMS + WhatsApp chips render with a `Coming soon` badge and are disabled).
- Status badges — **solid `bg-X-600` + `text-white`** (the current `bg-emerald-100 text-emerald-700` etc. violates the project rule — ISSUE-29):
  `SENT` → `bg-emerald-600` · `FAILED` → `bg-rose-600` · `BLOCKED` → `bg-amber-600`.
  Pair every badge with an icon so status is not colour-only (WCAG 1.4.1).
- `BLOCKED` / `FAILED` rows show the reason inline beneath the badge.
- Empty state: keep the existing well-written pattern, updated copy ("No communication yet. Use the Email button to send the first message.").
- Shaped Skeleton while loading. Card-stack fallback below `sm` — a 7-column table does not fit a phone.
- Header shows a "Compose email" button so the tab is self-sufficient without scrolling back to the sidebar.

### 4.5 Files

```
FE (new)
  detail/communication/compose-email-drawer.tsx
  detail/communication/channel-tab-strip.tsx
  detail/communication/communication-status-badge.tsx
  infrastructure/gql-queries/contact-queries/ContactCommunicationQueries.ts
  application/dtos/.../ContactCommunicationDto.ts
FE (modified)
  detail/contact-sidebar.tsx          — preference banner + 3-button row
  detail/tabs/communication-tab.tsx   — full rewrite
BE (new)
  Base.Domain/Models/ContactModels/ContactCommunication.cs
  Base.Infrastructure/.../Configurations/ContactCommunicationConfiguration.cs
  Base.Application/Business/ContactBusiness/ContactCommunications/CreateCommand/SendContactEmail.cs
  Base.Application/Business/ContactBusiness/ContactCommunications/Queries/GetContactCommunications.cs
  Base.Application/Business/ContactBusiness/ContactCommunications/DTOs/*.cs
BE (modified — WARN USER FIRST)
  ContactDbContext.cs · IContactDbContext.cs · Query.cs · Mutation.cs
```

---

## ⑤ Acceptance criteria

**Email**
1. Contact with a primary email + `DoNotEmail` false/null → Email button enabled → drawer opens → template loads and is editable → send → `toast.success` → row appears in Communication tab with `SENT` within one refetch.
2. Provider failure → row appears with `FAILED` + error message; **no exception surfaces to the user**; toast is an error, not a crash.
3. `DoNotEmail = true` → Email button disabled with tooltip; if the mutation is called directly, the BE returns `sent: false, blockedReason: "DO_NOT_EMAIL"` and persists a `BLOCKED` row **without calling the provider**.
4. Contact with no email address → button disabled, tooltip "No email address on file".
5. Passing a `ContactEmailAddressId` belonging to a *different* contact → `NotFoundException`, nothing sent.
6. 11th send within one hour → `BLOCKED` / `RATE_LIMIT`, provider not called.
7. Zod blocks an invalid Cc / over-length Subject **client-side** before the mutation fires.
8. Double-clicking Send produces exactly one row.

**Coming soon**
9. SMS and WhatsApp buttons render, are visibly disabled, carry a `Coming soon` badge, and have no click handler. Their drawer tabs are present but not selectable.
10. No SMS/WhatsApp mutation exists in the schema this phase.

**Preference**
11. `preferredCommunicationId = SMS` → banner reads "Prefers: SMS", SMS button carries the highlight ring *and* remains disabled with the Coming soon badge (preference and availability are independent signals).
12. Null preference → "No preference set", no ring.

**Cross-cutting**
13. `dotnet build` green, 0 new errors. `tsc --incremental false` exits 0 (exit 0 is the only pass — a run that reports only a pre-existing config error checked zero files).
14. Communication tab paginates past 25 rows.
15. All badges solid `bg-X-600` + `text-white`; no hex, no px, no `bg-X-100/text-X-700`.
16. Tenant isolation verified: a contact from another company is not reachable.

---

## ⑥ Guardrails

- **No real sends from a dev session without explicit per-run authorization** — email is outward-facing. Use a provider sandbox address.
- **Migrations are user-owned.** Compile-prove, then hand over the spec. Never run `dotnet ef migrations add` / `database update` / `remove`.
- **Seed**: `PREFERREDCOMMUNICATION` MasterData rows are assumed already seeded (the Contact form's Section 4 uses them). If a `Purpose` lookup is added later, write the seed file but let the user apply it.
- Warn before touching shared wiring files.
- Build agent: **Sonnet** for both BE and FE — this prompt is detailed enough.
- Append a Build Log entry to `.claude/screen-tracker/prompts/contact.md` §⑬ on completion, and close ISSUE-25 (consent now enforced), ISSUE-29 (badge tokens), ISSUE-30 (pagination) if the work covers them.

---

## ⑦ Known issues this build should NOT try to fix

Separate work — leave alone: ISSUE-19 (LocalityId lost in `UpdateContact` diff — **fix this first, independently; it is the top production blocker**), ISSUE-21 (inert tagIds filter), ISSUE-24 (`EmailSendQueue.contactId` filter allow-list — moot once the tab reads `ContactCommunications` instead), ISSUE-26 (`ExportContact` validation commented out), ISSUE-3 / ISSUE-4 (engagement score, timeline).
