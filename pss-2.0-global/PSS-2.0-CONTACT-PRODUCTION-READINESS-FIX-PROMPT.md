# PSS 2.0 — Contact (#18) Production-Readiness Fix Prompt

**Screen**: #18 Contact · `screen_type: FLOW` · `scope: FULL` · `status: NEEDS_FIX`
**Prompt file**: `.claude/screen-tracker/prompts/contact.md`
**Purpose**: close the remaining production blockers on the Contact screen. Each ITEM below is
**self-contained and executed in its own session**. Do not batch them.

---

## How to run an item

In a fresh session:

```
/continue-screen #18 "ITEM <n> from PSS-2.0-CONTACT-PRODUCTION-READINESS-FIX-PROMPT.md"
```

Then paste the ITEM block. The skill rehydrates §①⑥⑧⑫⑬ from `contact.md`; this document
supplies the fix spec.

**Recommended order**: ITEM 0 → 1 → 2 → 3 → 4 → 5 → 6.
ITEM 0 is bookkeeping only (~5 min). ITEM 2 is the largest (half a session).

### Standing constraints — apply to every item

| Rule | Detail |
|---|---|
| Migrations are user-owned | NEVER run `dotnet ef migrations add` / `database update` / `remove`, never hand-author a migration or snapshot. Build to prove compile, then hand over the migration spec. **No item below needs a migration.** |
| Seed SQL | Claude writes the file, the user applies it. |
| Shared wiring files | `ApplicationDbContext.cs`, `ContactQueries.cs`, `ContactMutations.cs`, `Routes.tsx`, seed SQL, DI registrations, sidebar nav → warn the user before editing (parallel sessions). |
| REGISTRY.md | `grep` only, never `Read` (~700 KB). Status flips via scripted `sed -i`. |
| Verification | BE: `dotnet build` → **exit 0 only**. FE: `npx tsc --noEmit --incremental false` → **exit 0 only**. A run that reports only a "pre-existing" TS2688 config error checked ZERO files and is NOT a pass. |
| Search | Use the Grep/Glob tools with an explicit `path` into `PSS_2.0_Backend` / `PSS_2.0_Frontend` — those subtrees are untracked by the outer repo, so ripgrep skips them by default. Never Bash `grep -r` (times out on this repo). |
| Change surface | Minimal. Only files named in the item. No adjacent refactors, no regenerating existing files. |

### Closing an item

1. Append one entry to `contact.md` §⑬ `§ Sessions` using the skill's template.
2. Cap `§ Sessions` at the **last 5** entries (scripted edit — do not `Read` the whole prompt file to prune).
3. Flip the closed issue rows in `§ Known Issues` from `OPEN` → `CLOSED (session N)`. **Never delete rows.**
4. Leave `status: NEEDS_FIX` until the last item; flip to `COMPLETED` only when no OPEN blocker remains.

---

## ITEM 0 — Close three issues that are already resolved (bookkeeping)

**Type**: FIX (log only — no code change expected)
**Effort**: ~5 min

Three Known-Issues rows are stale. Verify each, then close.

### 0a — ISSUE-25 (Critical / Compliance) — consent flags not enforced
Fixed by Sessions 4–5 (the `SendContactEmail` consent gate: `DoNotEmail == true` →
persists a `SkipReason = "DO_NOT_EMAIL"` row and never calls the provider).
**User has tested this.** Close it.

### 0b — ISSUE-19 (Low / Data integrity) — `LocalityId` not synced on address update
**Already fixed in the working tree.** Verified at
[UpdateContact.cs:274](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/Contacts/Commands/UpdateContact.cs#L274)
(existing-row branch) and
[UpdateContact.cs:294](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/Contacts/Commands/UpdateContact.cs#L294)
(new-row branch). Both assign `LocalityId = dto.LocalityId`.
Re-confirm with a grep before closing.

> While in that file: the address diff-update copies `AddressTypeId`, `AddressLine1–4`,
> `CountryId`, `StateId`, `DistrictId`, `CityId`, `LocalityId`, `PincodeId` — but **not**
> `IsPrimary` / `IsActive` if the DTO carries them. Check `ContactAddressRequestDto`. If those
> fields exist on the DTO and are dropped, that's a **new** issue row (same silent-data-loss
> class) — open it, fix it in this item since it's two lines, and log both.

### 0c — ISSUE-7 (Med / Feature) — bulk Send Email from list
**Descoped by the user (2026-07-23):** bulk email is owned by the dedicated **Email Send Job**
screen. The Contact list will not get its own bulk-send path.
Close as `CLOSED (session N) — descoped, bulk email owned by Email Send Job screen`.
The dead UI control is removed in **ITEM 3**, not here.

**Acceptance**: three rows read `CLOSED (session N)`; one Build Log entry; no `dotnet build`
needed unless 0b's DTO check produced a code change.

---

## ITEM 1 — Harden the contact export endpoint (ISSUE-26)

**Type**: FIX · **Severity**: Critical → **corrected to Medium** (see below)
**File**: [ExportContact.cs](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/Contacts/Queries/ExportContact.cs)
**Effort**: ~1–2 h

### Correction to the logged issue text

The Known-Issues row says *"unvalidated sort/filter input on a bulk-PII endpoint"*. That is
**partly wrong** and the item must not be executed on the original premise:

`ExportContactHandler.Handle` does not query the DB itself — line 61 does
`_mediator.Send(new GetContactsQuery(modifiedRequest))`, and `QueryValidationBehavior<,>` is
registered as an **open pipeline behavior**
([DependencyInjection.cs:34](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/DependencyInjection.cs#L34)),
so the nested send runs `GetContactsValidator` — which *does* call `ValidateGridFeatures`
([GetContact.cs:31](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/Contacts/Queries/GetContact.cs#L31)).
Sort/filter input **is** validated today, transitively.

The real, unmitigated gaps are the other two:

1. **No row cap.** [ExportContact.cs:58](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/Contacts/Queries/ExportContact.cs#L58)
   sets `pageSize = int.MaxValue`. An unfiltered export on a large tenant materialises every
   contact row plus every included collection into memory and builds one Excel file from it —
   an OOM / DoS surface on a PII endpoint.
2. **No export audit log.** A bulk-PII extraction leaves no record of who exported what.

### Fix specification

**1a — Restore the defense-in-depth validation.** Uncomment
[line 27](PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/Contacts/Queries/ExportContact.cs#L27).
`ValidSortColumns` is already declared at line 22 (currently unused). Mirror the *four-argument*
overload used by `GetContactsValidator` (direct fields + aggregate fields + collection mapping)
so a filter that passes the list query does not fail the export query — a two-argument call
would reject aggregate filters the grid legitimately sends. If the overloads can't be matched
exactly, **keep the 2-arg sort-only form and log the divergence** rather than breaking export.

**1b — Add a max-row guard.** Replace `int.MaxValue` with a bounded page size read from
`IConfiguration` (`_configuration` is not yet injected — `Microsoft.Extensions.Configuration` is
already imported at line 8). Key: `Export:Contact:MaxRows`, default **10000**.
Run the count first; if `contactResult.contacts.TotalCount > maxRows`, return
`ExportContactResult(Array.Empty<byte>(), "", "", Success: false, ErrorMessage: ...)` with a
message naming the cap and telling the user to narrow the filter. Do **not** silently truncate —
a partial export that looks complete is worse than a refused one.

**1c — Audit every export.** Before returning the file, write one audit record: actor
(`_httpContextAccessor.GetCurrentUserId()`), company id, row count, and the serialised
`GridFeatureRequest`. Use the existing audit path — check `AuditEventPipelineBehavior` /
whatever `sys` audit table the codebase already uses **before inventing anything**. If no
suitable sink exists, fall back to a structured `_logger.LogInformation` with all four values as
named properties and open a follow-up issue for the durable sink. **No new table, no migration.**

### Acceptance criteria
- [ ] Validation line restored and compiling; a bogus sort column on export is rejected.
- [ ] Export of a filtered set under the cap still produces a correct .xlsx.
- [ ] Export exceeding `Export:Contact:MaxRows` returns `Success: false` with a clear message; no file bytes.
- [ ] Cap is configurable; default 10000 applies when the key is absent.
- [ ] Every successful export emits an audit record/log with actor + company + row count + filter.
- [ ] `dotnet build` exits 0.

---

## ITEM 2 — Mirror backend validation into the Zod schemas (ISSUE-27)

**Type**: FIX · **Severity**: Critical
**File**: `PSS_2.0_Frontend/.../crm/contact/contact/contact-validation-schemas.ts` (591 lines)
**Effort**: half a session — this is the big one

### The issue (verbatim from `contact.md`)
> `contact-validation-schemas.ts` (591 ln) contains ZERO `.email()` and ZERO `.max()` rules —
> `grep -c` returns 0. Only HTML-level `type="email"` / `maxLength` attributes exist
> (`form/email-address-section.tsx:145,150`, `form/phone-number-section.tsx:201,206`),
> which are not enforcement. Mirror the BE string-length + format rules in Zod.

HTML attributes are trivially bypassed and, more practically, they don't drive RHF
`formState.isValid` — which is what gates the page-header Create/Save button. A user can
currently arm the submit button with a malformed email and eat a 400 from the server.

### Fix specification

1. **Derive the rules from the backend, do not invent them.** Read the FluentValidation
   validators for Contact create/update (`CreateContact.cs`, `UpdateContact.cs`, plus the child
   validators for email addresses, phone numbers, addresses, social links) and the EF
   configuration / entity string lengths. Every `.MaximumLength(n)` on the BE becomes a
   `.max(n)` on the FE with the same `n`. Every BE email/URL/phone format rule becomes the
   matching Zod refinement.
2. **Do not tighten beyond the backend.** A FE rule stricter than the BE blocks legitimate
   data and is a bug, not extra safety.
3. **Every string field gets a `.max()`**, including the ones with no BE rule — use the column
   length from the EF config as the bound.
4. **Emails**: `.email()` on every email field (primary + the repeatable email-address rows).
   Optional fields stay optional — `.email()` must not fire on empty string; use
   `.union([z.literal(""), z.string().email()])` or `.optional()` per the file's existing idiom.
5. **Phones**: match the BE rule. If the BE has none, apply a permissive digits/`+`/space/`-`
   pattern plus the column-length `.max()` — do not impose a locale-specific format.
6. **URLs** (social links): `.url()` where the BE validates a URL.
7. **Messages** must go through the file's existing localisation/message idiom — do not hardcode
   English strings if the file doesn't already.
8. **Keep the HTML attributes.** They're good UX (mobile keyboard, native affordance); the Zod
   rules are the enforcement layer, not a replacement.

### Acceptance criteria
- [ ] `grep -c "\.email(" contact-validation-schemas.ts` > 0; `grep -c "\.max(" ` covers every string field.
- [ ] Every `.max(n)` matches the BE `MaximumLength(n)` / column length — spot-check 5 field pairs and record them in the Build Log.
- [ ] Malformed email in a repeatable email row keeps the header Create/Save button disabled and shows an inline field error.
- [ ] Optional email/URL fields left blank do NOT show an error and do NOT block submit.
- [ ] Existing valid contacts still open and save unchanged (no false-positive on legacy data).
- [ ] `npx tsc --noEmit --incremental false` exits 0.

---

## ITEM 3 — Remove the dead bulk-action controls from the contact list

**Type**: UI · **Severity**: Med (visible dead controls in production)
**File**: [bulk-actions-bar.tsx](PSS_2.0_Frontend/src/presentation/components/page-components/crm/contact/contact/list/bulk-actions-bar.tsx)
**Effort**: ~30 min

Four controls fire toast-only placeholders:

| Line | Control | Disposition |
|---|---|---|
| 30 | Bulk Send Email | **Remove.** Descoped — bulk email is the Email Send Job screen's job (ISSUE-7, closed in ITEM 0c). |
| 39 | Add Tags | **Remove** for MVP unless a tag-assign mutation already exists — check first. |
| 48 | Export Selected | **Decide:** the export endpoint exists (`ExportContactQuery`) but takes a `GridFeatureRequest`, not an id list. If a selected-ids filter can be expressed through `GridFeatureRequest`, **wire it**; otherwise **remove** it — the toolbar Export already covers the filtered-set case. |
| 56 | Bulk Delete | **Remove.** No bulk-delete endpoint, and bulk-deleting PII behind an unconfirmed control is not something to ship half-built. |

If every control is removed, remove the bar and its `useContactStore` selection wiring from the
list page too — leaving an empty bar that appears on row-select is worse than no bar. Check
whether `bulkSelectedIds` is read anywhere else before deleting the store slice; if it is, leave
the slice and remove only the bar.

**Rule: nothing that ships may render a control whose only behaviour is a toast saying it
doesn't work.**

### Acceptance criteria
- [ ] No `SERVICE_PLACEHOLDER` / "not yet wired" toast remains in the contact list surface (grep the whole `contact/` FE folder, not just this file).
- [ ] Selecting rows either surfaces working actions or no bar at all.
- [ ] No unused imports / dead store selectors left behind.
- [ ] `npx tsc --noEmit --incremental false` exits 0.

---

## ITEM 4 — Tenant-attribute parity on `GetContactById` (ISSUE-28)

**Type**: FIX · **Severity**: Med (defense-in-depth; **not** a live vulnerability)
**File**: `.../ContactBusiness/Contacts/Queries/GetContactById.cs`
**Effort**: ~15 min

`GetContactById` carries `[CustomAuthorize]` but not `[RequiresTenant]` / `[TenantScope(TenantScopeType.Current)]`.
**Verified safe today**: `ApplicationDbContext.ApplyTenantFilters` installs a global query filter on
every entity with a `CompanyId`, so a cross-tenant id returns null rather than another tenant's
contact. This item is about not depending on that single layer — a future `IgnoreQueryFilters()`
or raw-SQL path would silently open the hole.

### Fix specification
Add `[RequiresTenant]` and `[TenantScope(TenantScopeType.Current)]` to the query record, matching
the sibling queries in the same folder. Copy the attribute set from a query that already has them
(e.g. `SendContactEmailCommand`) rather than composing from memory.

Then **audit the rest of the Contact folder** for the same omission and fix any siblings in the
same pass — this is the cheap moment to do it.

### Acceptance criteria
- [ ] `GetContactByIdQuery` carries both attributes; any sibling with the same gap is fixed.
- [ ] Contact detail page still loads for a normal `BUSINESSADMIN` user (the attributes must not break the happy path).
- [ ] `dotnet build` exits 0.

---

## ITEM 5 — Verify the `EmailSendQueue.contactId` advanced filter is allow-listed (ISSUE-24)

**Type**: FIX · **Severity**: Low-to-Med — **fails open, so verify before assuming it's benign**
**Effort**: ~30 min

The Communication tab filters `EmailSendQueue` rows by `contactId` through the advanced-filter
contract. If `contactId` is not in the allow-list for that grid, the filter is **dropped rather
than rejected** — the query returns *all* rows the tenant filter permits, i.e. one contact's
communication tab showing another contact's email history. Same-tenant, but still a leak.

### Fix specification
1. Reproduce first: open a contact with **zero** emails whose tenant has emails for other
   contacts. If the tab shows rows, the filter is being dropped — confirmed.
2. Find the allow-list for the `EmailSendQueue` grid query and confirm `ContactId` is present.
3. If missing → add it.
4. **If the contract genuinely fails open**, that is the real defect. The contact-scoped query
   must not rely on a droppable client filter: pin `ContactId` **server-side in the handler**
   from the route/query argument, so the tab is scoped regardless of what the client sends.
   Prefer this fix — it's the one that can't regress.

### Acceptance criteria
- [ ] A contact with no emails shows an empty state, never another contact's rows.
- [ ] Scoping is enforced server-side, not only via a client-supplied filter.
- [ ] `dotnet build` exits 0.

---

## ITEM 6 — Hide the unimplemented engagement stubs (ISSUE-3, ISSUE-4)

**Type**: UI · **Severity**: High as *visible* stubs, Low as *features*
**Effort**: ~30 min

- **ISSUE-3** — engagement score: unimplemented.
- **ISSUE-4** — cross-entity timeline: stubbed.

**Hide them; do not build them.** Both are post-MVP features that need real cross-entity
aggregation. Shipping a score that's always `0` or a timeline that's always empty tells users
the data is missing, not the feature.

### Fix specification
Remove or feature-flag the engagement-score widget and the cross-entity timeline tab/section
from the contact detail page. Prefer **removal** over a flag unless the codebase already has a
feature-flag idiom for this screen. Keep the DTO fields and any BE plumbing — only the render
path goes. Leave both issue rows **OPEN** (they're deferred features, not fixed ones) and note
in each row that the UI is now hidden.

### Acceptance criteria
- [ ] Neither the score nor the timeline renders on the contact detail page.
- [ ] No empty-shell tab or zero-value card remains in their place.
- [ ] ISSUE-3 / ISSUE-4 stay OPEN, annotated `UI hidden (session N) — deferred post-MVP`.
- [ ] `npx tsc --noEmit --incremental false` exits 0.

---

## Deferred — do NOT execute

Leave these OPEN and untouched for the MVP:
**ISSUE-1, 2, 5, 6, 8, 9, 10, 16, 17, 18, 20, 21, 22, 23.**

If a session wants to pull one forward, that's a scope decision for the user — ask, don't assume.

## Already closed — do not reopen

**ISSUE-29** (badge tokens) · **ISSUE-30** (100-row cap → 25/page pagination) ·
**ISSUE-37** (`EmailSendQueue.ContactId` nullable — deliberate, documented in the entity).

## Post-completion

After ITEM 6, flip `contact.md` frontmatter to `status: COMPLETED` **only if** no OPEN row is a
release blocker (the deferred list and the two hidden-stub rows are not blockers), then update
REGISTRY.md via scripted `sed -i`:

```bash
sed -i -E "s/^(\| *#?18 \|.*\| )(COMPLETED|NEEDS_FIX)( \|)/\1COMPLETED\3/" .claude/screen-tracker/REGISTRY.md
```
