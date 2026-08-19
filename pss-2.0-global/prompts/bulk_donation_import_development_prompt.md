# Bulk Donation Import — on-demand and scheduled parity with Contact Import

## 0. What this is

Contact import now works end to end: upload → parse → stage → validate → review → **Import Now**
(queued Hangfire job) or **Schedule** (nightly re-validate + execute), with plan-quota gates and
terminal notifications.

Bulk donation import has to reach the same bar. Most of the machinery is grid-agnostic and already
covers it. This prompt is a **parity and correctness pass**, not a new feature build. The work is:
find every place the pipeline is contact-shaped, close the gaps, and resolve three genuine
donation-only decisions.

Do **not** fork the import engine per grid. If something needs to differ by grid, it differs by
`ImportGridDefinition` data, not by a `if (gridCode == "BULKDONATION")` branch.

---

## 1. Blocker — read this before planning anything else

`sql-scripts-dyanmic/BulkDonationImport-fn-execute.sql:323` calls:

```sql
v_final_receipt_no := import.generate_sequence_number( ... );
```

and its own header, lines 26-27, states:

> DEPENDENCY: `import.generate_sequence_number` (DatabaseScripts/Functions/import/
> generate_sequence_number.sql) must be deployed BEFORE this function.

**That function does not exist anywhere in the repository.** A repo-wide search for
`*generate_sequence*` returns nothing — no script, no migration, no `DatabaseScripts/Functions/import/`
file. So unless it was hand-created directly in the database, every bulk donation import run fails at
the first row that needs a generated receipt number with `function import.generate_sequence_number(...)
does not exist`.

That function is exactly what **[import_code_generation_prompt.md](import_code_generation_prompt.md)
§B** specifies — the PL/pgSQL counterpart of `NumberSequenceGenerator.GenerateAsync`.

**Sequencing is therefore fixed:**

1. First: confirm whether `import.generate_sequence_number` exists in the target database
   (`SELECT to_regprocedure('import.generate_sequence_number(int,text,date)');`).
2. If it does not, `import_code_generation_prompt.md` §B lands **before** this work can be tested.
3. If it does exist in the DB but not in the repo, that is a worse problem than it missing: the
   deployed function is unversioned and unreviewable. Extract it, commit it as a script, and say so.

Do not work around this by falling back to a synthetic receipt number. `ReceiptNumber` is the
tax-facing identifier; a placeholder that later collides with a real sequence value is a compliance
problem, not a cosmetic one.

---

## 2. What already exists (verify each, then build only the gaps)

Cite `file:line` for every confirmation or contradiction.

**SQL assets — present, deployment status unknown:**
- `BulkDonationImport-seed.sql` — `ImportGridDefinitions` row: `GridCode='BULKDONATION'`,
  `EntityType='GlobalDonation'`, target `fund.GlobalDonations`, `HasChildren=FALSE`,
  `ValidationProcedure='import.validate_bulk_donation_data'`,
  `ImportProcedure='import.execute_bulk_donation_import'`, 10 MB / 10,000 rows, display order 2.
- `BulkDonationImport-fn-validate.sql` (419 lines) — delegates to the shared
  `import.validate_common(...)` layer per its header.
- `BulkDonationImport-fn-execute.sql` (522 lines).
- `BulkDonationImport-seed-validation-metadata.sql`.

**Grid-agnostic and confirmed to carry no `"CONTACT"` literal** — a search across
`Base.Application/Business/ImportBusiness/`, `Base.Support/Import/`, and
`Base.Infrastructure/Services/Import/` returns zero hits. Upload, parse, staging, validation
orchestration, queue dispatch, scheduled execution, progress broadcast and quota enforcement are all
driven by `ImportGridDefinition`. Treat this as verified; if you find a contact assumption anywhere,
that is a bug in the shared layer, fix it there.

**Quota** — `ImportQuotaGuard.ResolveMeterCode` maps `"GLOBALDONATION" or "DONATION"` →
`MeterCodes.Donations`. The seed's `EntityType='GlobalDonation'` uppercases to `GLOBALDONATION`, so
all four gates already apply to bulk donation:
- **A** advisory `GetImportQuotaStatus` on the review screen,
- **B** hard refuse `EnsureAllowedAsync(...)` in `StartImport.cs:141` / `ScheduleImport.cs:93`,
- **C** re-check at scheduled re-validation,
- **D** the guarantee — `EnsureCapacityAsync` at `ImportExecutionService.cs:365`, inside the batch
  transaction under `pg_advisory_xact_lock`.

Confirm the arithmetic is honest for donations the same way it is for contacts: `used + ValidRows <=
limit` is only correct if the execute function is **insert-only**. `BulkDonationImport-fn-execute.sql`
shows `INSERT INTO fund."GlobalDonations"` with no upsert branch (its only `ON CONFLICT` is on
`import."ImportProgresses"`, which is progress bookkeeping, not donation rows). Verify that and state
it. If an upsert path is ever added, gate B over-charges.

**Frontend** — the import wizard contains **zero** `BULKDONATION` references. It is entirely
grid-driven off the grid list. So no wizard fork is needed. The route itself is an 8-line shim:

```tsx
// app/[lang]/(core)/crm/contact/contactimport/page.tsx — the ONLY import route that exists
"use client";
import { ImportPageConfig } from "@/presentation/pages/shared/import";
export default function Page() {
  return <ImportPageConfig gridCode="CONTACT" menuCode="CONTACTIMPORT" />;
}
```

So the entire frontend build for this feature is **one file plus a menu seed** — see §5.

⚠️ **Name collision, do not trip on it.** The frontend already uses the literal `"BULKDONATION"` as a
*data-table* grid code in `application/configs/data-table-configs/donation-service-entity-operations.ts:284`
for BulkDonation CRUD. That is a different registry from `import."ImportGridDefinitions"."GridCode"`,
which also happens to be `'BULKDONATION'`. Same string, two unrelated systems. Confirm the
`enableImport` flag on that data-table config (one of the ~114 known-inert flags) is not silently
pointing the CRUD grid's toolbar at the import wizard, and do not "reuse" one code for the other.

---

## 3. The three donation-only decisions

These are not parity items. They are real design decisions the contact path never had to make. Give
one answer each, with reasoning — not "either approach works".

### 3.1 Donor resolution when the contact does not exist

The BD field set resolves a donor by `contact_code`, `donor_email`, or `donor_name`. Decide what
happens when none of the three resolves:

- **Fail the row** (validation error, row skipped, reported in the failed download), or
- **Create the contact** as part of the import.

If you choose "create the contact", note the consequence carefully: **creating contacts consumes the
`Contacts` meter, and the Donations quota gate does not check it.** A 10,000-row donation import
would silently create up to 10,000 contacts with no quota gate anywhere in the path — a hole in an
otherwise fail-closed system. Choosing "create" therefore obliges you to add a second meter check
for the projected new-contact count at gates B and D. Weigh that before choosing.

My reading: **fail the row** for MVP. It keeps the quota model honest, keeps the import insert-only
against one table, and makes the failure legible to the user (they fix the sheet or import contacts
first, which is a flow that already exists). Argue otherwise if the business requires it, but then
build the second meter check.

### 3.2 ReceiptNumber precedence and the "kill switch"

`BulkDonationImport-fn-execute.sql:301-314` documents: file value wins, generate only when blank,
and a NULL from generation — "generation switched off at either kill switch" — leaves `ReceiptNumber`
null. **There is exactly one reference to a kill switch in the whole file, and it is that comment.**
No setting is read, no flag is checked.

Establish whether the kill switches exist (in `NumberSequenceConfigs` / `NumberSequenceEntityTypes`,
or in organization settings) or whether the comment describes intent that was never built. Then
either wire them or delete the comment. A comment describing a control that does not exist is worse
than no comment.

Also decide explicitly: is a **null** `ReceiptNumber` an acceptable committed state for a donation?
For a tax-facing identifier the answer is almost certainly no — in which case generation failure must
fail the row, not commit it blank.

### 3.3 Duplicate donation detection

Contacts dedupe on identity. Donations have no natural key — the same donor can legitimately give the
same amount on the same day twice. Decide what "duplicate" means for a bulk donation row, or decide
explicitly that there is no duplicate rule and that re-uploading the same file creates a second set
of donations. Whichever you choose, it must be stated in the Tab 1 instructions (see the pipeline
prompt) so the user is not surprised.

Note the operational risk if there is no rule: a user who is unsure whether the first import worked
will re-upload. Consider whether the file-hash-per-session check that exists for uploads already
covers this, and if not, whether it should.

---

## 4. On-demand and scheduled parity

Both paths are shared code, so the work here is verification plus whatever the audit turns up.

**On-demand (Import Now):** `StartImport` enqueues a Hangfire job — it is *not* synchronous, despite
the "don't close the tab" copy on the wizard. Confirm the queue dispatcher handles a
`HasChildren=FALSE` grid cleanly: `ImportExecutionService` has parent/child logic written for
contacts, and the child branch must be a clean no-op for donations, not a zero-row query per batch.

**Scheduled:** `ImportScheduledExecutionService` re-validates before executing, because master data
and quota can move between scheduling and the nightly run. Confirm the donation validate function is
safe to run twice on the same staging table — specifically that re-validation resets prior validation
state rather than appending to it.

**Retry:** validation failure and import failure must both offer a retry path. Its absence is a known
live complaint on the contact path; do not ship the donation path without it.

**Terminal notification:** the five trigger codes are grid-agnostic and `ImportNotificationService`
fires from committed session status, so donations already produce a notification. Verify the token
set renders a sentence that names the donation grid rather than a contact-shaped message. See the
pipeline prompt for the popup and idempotency work.

---

## 5. Reachability

**There is currently no way in.** `app/[lang]/(core)/crm/contact/contactimport/page.tsx` is the only
import route in the application. Bulk donation import has no page, so no menu can point at it.

Build:

1. **The route** — mirror the contact shim exactly, under the donation module's path segment (decide
   the path from where the donation menus already live; do not park a donation screen under `crm/contact/`):
   ```tsx
   "use client";
   import { ImportPageConfig } from "@/presentation/pages/shared/import";
   export default function Page() {
     return <ImportPageConfig gridCode="BULKDONATION" menuCode="BULKDONATIONIMPORT" />;
   }
   ```
   `gridCode` must match `import."ImportGridDefinitions"."GridCode"`; `menuCode` must match the seeded
   `auth."Menus"` row. Confirm both strings against the database rather than assuming.

2. **The menu + capability seed** — an idempotent `seed_bulkdonationimport_menu.sql` covering
   `Menus`, `MenuCapabilities` and `RoleCapabilities` (BUSINESSADMIN), following the pattern the
   `CONTACTIMPORT` menu already uses. Note that `CustomAuthorize` matches a parent menu group code
   exactly, so if the donation menu group is new, grant the group row too or every call 403s. Hand
   the script off; do not execute it.

Then verify:
- the menu renders for the intended roles and the route resolves;
- the grid appears in the wizard's grid picker for a tenant with the donation module;
- `[CustomAuthorize]` on **every** import command and query includes
  `DecoratorDonationModules.BulkDonation`, not just the queries. `GetStagingData` already lists both
  modules — check `StartValidation`, `StartImport`, `ScheduleImport`, `CancelImport`,
  `UploadImportFile`, `DownloadImportResult` and anything else in the folder. A query the user can
  read but a command they cannot run is a 403 at the worst possible moment.

---

## 6. Custom fields

`ImportGridDefinitions.CustomFieldGridCode` is `CONTACT → CONTACT` and `BULKDONATION → NULL` —
donations deliberately have no custom-field support in the import path. Confirm this is still the
intent. If donation custom fields are wanted, that is a separate scoped piece of work, not a
side-effect of this one; say so rather than quietly enabling it.

---

## 7. Verification (the user runs these; you write them)

Produce a runnable checklist, not prose:

1. `to_regprocedure` checks for `import.validate_bulk_donation_data`,
   `import.execute_bulk_donation_import`, `import.generate_sequence_number`, `import.validate_common`.
2. `SELECT "GridCode","EntityType","ValidationProcedure","ImportProcedure","IsActive"
   FROM import."ImportGridDefinitions";` — expect the BULKDONATION row exactly as seeded.
3. A happy-path import of a small file: rows land in `fund."GlobalDonations"` with non-null
   `ReceiptNumber`, `ExecutionStatus=1` on every staging row, `ImportExecutionResults` populated.
4. A mixed file: valid rows commit, invalid rows come back `ExecutionStatus=3` (Skipped) with a
   readable `ExecutionError`, and the failed-rows download matches.
5. A quota-exceeded run: gate B refuses with 402 / `PLAN_QUOTA_EXCEEDED` before any row commits.
6. A scheduled run: schedule, then verify re-validation ran and the execution followed.
7. Receipt-number sequence continuity: import, then create a donation through the UI, and confirm the
   next number does not collide. This is the exact defect
   [import_code_generation_prompt.md](import_code_generation_prompt.md) exists to prevent.

---

## 8. Out of scope

Column mapping, saved mapping templates, value mapping, CSV upload, donation custom fields, and any
change to the contact import path. Do not create EF migrations — hand off SQL scripts and migration
bodies for the user to apply.

## 9. Output

1. Audit findings with `file:line` citations, including a clear verdict on §1.
2. The three §3 decisions, each with one answer and its reasoning.
3. Implementation plan in dependency order.
4. Compiling C# diffs — do not run `dotnet build`.
5. Idempotent SQL under `sql-scripts-dyanmic/`, plus any migration body as markdown for the user.
6. The §7 checklist.
7. Anything in this prompt the codebase contradicts. The codebase wins.

Stage your work. Do not commit.
