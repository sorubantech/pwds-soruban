# Bulk Donation — pipeline UX and completion notification

## 0. Relationship to the other two prompts

This is the **third** of three, and it is deliberately the thinnest.

| Prompt | Scope |
|---|---|
| [import_code_generation_prompt.md](import_code_generation_prompt.md) | `import.generate_sequence_number` — the hard blocker for donation receipt numbers |
| [bulk_donation_import_development_prompt.md](bulk_donation_import_development_prompt.md) | The donation import path itself: on-demand, scheduled, quota, route, menu |
| **This one** | The 5-tab pipeline UI and the once-only completion popup, as they apply to donations |
| [import_pipeline_ux_notification_prompt.md](import_pipeline_ux_notification_prompt.md) | The **base** build of that pipeline + notification work, grid-neutral |

**Read the base prompt first and treat it as the specification.** Do not re-implement it here. Almost
everything in it is grid-neutral by construction — the wizard contains zero `BULKDONATION` references
and is driven entirely off `ImportGridDefinition` — so if this prompt were done correctly the
donation grid would light up with no UI work at all.

The purpose of this prompt is to find the places where that is **not** true, and to add the handful
of things that are genuinely donation-shaped. If you find yourself writing a donation-specific
component, stop: that is a sign the base build hardcoded a contact assumption, and the fix belongs in
the shared component.

Sequence: base prompt lands → this parity pass → done.

---

## 1. What is already grid-neutral (verify, don't rebuild)

Confirm each with `file:line`, and treat a contradiction as a defect in the shared layer:

- **The wizard.** No `BULKDONATION` or `CONTACT` literal anywhere in
  `presentation/components/custom-components/import-wizard/`. The grid is chosen in
  `import-step-select-grid.tsx` from the server's grid list.
- **The pipeline rail.** `import-wizard-container.tsx:85-150` — `steps` + `iconForState`. Nothing
  entity-aware.
- **Tab 1 instructions.** The base prompt requires this be generated from the field metadata
  `GenerateFieldsAsync` already returns (`DisplayName`, `IsRequired`, `DataType`, `MaxLength`,
  `DateFormat`, `AllowedValues`). Because donation fields come from the same
  `ImportGridFields` table, correct Tab 1 content for donations is a **consequence** of building Tab 1
  correctly, not extra work. If Tab 1 needed a donation-specific copy block, it was built wrong.
- **Paged results.** `GetStagingDataQuery(sessionId, page, size, validationStatusFilter,
  executionStatusFilter)` reads the per-session staging table and returns `ExecutionStatus`,
  `ExecutionStatusName`, `ExecutionError`. Staging tables are per session, so this is grid-neutral
  with zero changes.
- **Live progress.** `ImportProgressHub` groups per **session**, not per grid or per user. Donations
  broadcast the same 8 events.
- **The notification triggers.** The five codes on `ImportNotificationService` derive from committed
  session status, not from the grid. A donation import already dispatches a notification today.
- **The idempotency key.** The base prompt stamps `("ImportSession", sessionId)` — session-scoped,
  therefore grid-neutral. `PushedAt` likewise.

---

## 2. What is genuinely donation-shaped

Four items. Nothing else should appear in your plan without justification.

### 2.1 Validation stage rail (Tab 3)

The base prompt requires the Tab 3 rail be driven by the **real** `CurrentStep` values on the
`ValidationProgress` broadcast, not by an invented stage list.

`import.validate_bulk_donation_data` (419 lines) delegates to the shared `import.validate_common(...)`
layer, but it also runs donation-specific checks — currency, donation mode, amount, and the
contact-resolution step described in the development prompt's §3.1. Those may emit `CurrentStep`
values the contact path never produces.

Enumerate the donation function's actual stage vocabulary and compare it to the contact function's.
Then:
- if the sets differ, the rail must be **data-driven per grid**, not a hardcoded array — the natural
  home is the grid definition or the validation metadata seed
  (`BulkDonationImport-seed-validation-metadata.sql` already exists and is the obvious place);
- if the rail was hardcoded to the contact stages in the base build, that is the defect to fix.

Do not show a stage the donation function never reports. A permanently-pending node reads as a hung
import.

### 2.2 Result summary (Tab 5)

This is the one screen where donations legitimately show different numbers. Beyond the shared
status / imported / failed / skipped / duration / timestamp, add:

- **total amount imported**, broken down **per currency** — a single summed figure across mixed
  currencies is meaningless and actively misleading;
- **receipt numbers**: how many were taken from the file versus generated (the precedence rule at
  `BulkDonationImport-fn-execute.sql:301-314`), and **any row committed with a null receipt number**
  called out as a warning, not buried. See the development prompt §3.2 — if that decision lands as
  "null receipt is never acceptable", this reduces to an assertion that the count is zero.

Implement this as a **grid-optional summary block** driven by data the backend already returns, not
as an `if (gridCode === "BULKDONATION")` in the Tab 5 component. Contacts get their own block or
none.

### 2.3 Notification message tokens

The five templates are shared. Verify the token snapshot passed by `ImportNotificationService`
includes the grid's display name, so a completed donation import says "Bulk Donation Upload" and not
a contact-shaped or generic sentence. Check the seeded template bodies in
`import-notification-templates-seed.sql` for any contact-specific wording; if a body reads naturally
only for contacts, fix the **template**, not the code.

The completion popup's `ActionUrl` must deep-link to the donation import session — which requires the
donation route from the development prompt §5 to exist first.

### 2.4 Quota copy

The advisory quota strip (gate A) reads from `GetImportQuotaStatus`, which resolves the meter from
`EntityType`. For donations that is `MeterCodes.Donations`, not Contacts. Verify the strip labels the
meter it is actually showing rather than saying "contacts". If the development prompt's §3.1 decision
is "create the contact", this strip must show **both** meters — a donation import that silently
consumes contact quota while displaying only donation quota is worse than showing nothing.

---

## 3. Explicit non-goals

- No second notification implementation, no new transport, no per-grid notification service.
- No donation fork of the wizard, the rail, the staging grid, or the progress view.
- No new paged API — `GetStagingDataQuery` already covers it.
- No change to the import engine, batching, or quota gates.
- No EF migrations created by you.

---

## 4. Output

1. A parity audit: for every item in §1, confirmed or contradicted, with `file:line`. Contradictions
   are defects in the shared layer — list them as such and fix them there.
2. The donation validation stage vocabulary from §2.1, compared against the contact one.
3. Diffs for the four §2 items only.
4. Test cases that matter here: a donation import completing while the user is on another screen
   produces exactly one popup; the Tab 3 rail matches the stages the donation function actually
   emits; mixed-currency totals never sum across currencies.
5. Anything this prompt gets wrong about the codebase. The codebase wins.

Stage your work. Do not commit.
