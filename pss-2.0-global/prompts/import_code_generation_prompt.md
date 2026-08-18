# Import: entity code generation (ContactCode, ReceiptNumber)

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`.
- Do NOT execute SQL against any database. Idempotent scripts, handed off.
- Do NOT probe ports, processes or API liveness.
- `PSS_2.0_Backend` / `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server.
- Enterprise-level app. No shortcuts. Backend enforcement, never frontend-only.

**Run this AFTER `import_custom_fields_prompt.md` has landed.** That session owns the import
execute functions you are about to change. Confirm it is finished before you start; if its changes are
still in flight, stop and report rather than editing around it.

---

## The defect

Two write paths create the same entities and they do not agree on how the entity's business code is
produced.

**Contacts.** The UI path generates from the `CONTACT` number sequence
([`CreateContact.cs:343`](../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/ContactBusiness/Contacts/Commands/CreateContact.cs)):

```csharp
var generatedContactCode = await NumberSequenceGenerator.GenerateAsync(
    dbContext, contact.CompanyId, "CONTACT", ..., cancellationToken);
```

The import path does this instead:

```sql
-- 5e: Set ContactCode = ContactId
SET "ContactCode" = v_new_contact_id::TEXT
```

So one tenant ends up with `CON-2026-00042` beside `88317` in the same column. Worse, the import
value bypasses the counter entirely — it neither consumes nor observes `LastSequence`, so a code the
generator hands out later can collide with one the import already wrote.

**Donations.** `ReceiptNumber` is read verbatim from the spreadsheet column and written as `NULL`
when blank (`BulkDonationImport-fn-execute.sql`). Nothing generates it. The UI path generates from
`GLOBALDONATION` for every mode. A bulk donation import therefore produces donations with no receipt
number at all — and for donations the receipt number is the tax-facing identifier, not a convenience
label.

## Why this is not a small fix

`NumberSequenceGenerator` is C# and its contract requires an open EF transaction so the counter
update flushes with the parent insert. Both import executions are PL/pgSQL functions running set-based
row loops. Calling back into C# per row is not viable, and re-implementing the format in SQL "close
enough" guarantees the two paths drift.

The generator must therefore get a **PL/pgSQL counterpart that shares the same tables, the same lock
and the same semantics** — not a parallel implementation.

---

## A. Establish the ground truth first

Report each with file and line.

1. **Which contact execute function is live.** There are three candidates:
   `DatabaseScripts/Functions/import/execute_contact_import.sql`,
   `Base/sql-scripts-dyanmic/ContactImport-fn-execute.sql`, and
   `Base/sql-scripts-dyanmic/ContactImport-fn-execute-current.sql` (already flagged stale and slated
   for deletion). Determine which one the deployed `import.execute_contact_import` actually came from,
   say how you determined it, and **fix exactly one**. Report the others and recommend deleting the
   dead copies — three copies of a function nobody can identify is how the next divergence happens.

2. **Whether `CONTACT` is seeded** in `sett."EntityTypes"` / `sett."NumberSequenceEntityTypes"`.
   `GenerateAsync` throws loudly when the eligibility row is missing, so if it is not seeded, the UI
   path is already throwing and that is a separate bug to report. Write a read-only query that shows
   the current `CONTACT` and `GLOBALDONATION` rows with their `DefaultPattern`,
   `DefaultSequenceResetPolicy` and `IsEnabled`. Do not run it.

3. **How many rows already carry an import-shaped `ContactCode`** (numeric, equal to `ContactId`).
   Read-only count query, grouped by company. This sizes the backfill question in § F.

## B. Build the PL/pgSQL counterpart

Create `import.generate_sequence_number(p_company_id int, p_entity_type_code text, p_context_date date)`
returning `text`, in its own file under `PSS_2.0_Backend/DatabaseScripts/Functions/import/`.

It must mirror `NumberSequenceGenerator.GenerateAsync` step for step. Read that file — it is the
specification, not a reference. In particular:

- **The advisory lock key formula must be bit-identical:**
  `((0x4E554D53::bigint << 24) # (entity_type_id::bigint << 24)) # company_id::bigint`
  Verify the operator mapping (`^` in C# is `#` in PostgreSQL) and prove the two produce the same
  bigint for a worked example in your report. If they differ by even one bit, the import and the UI
  take *different* locks and the mutual exclusion that makes this whole thing correct evaporates —
  silently, under concurrency only.
- **Bootstrap** the `sett."NumberSequenceConfigs"` row when absent, exactly as the C# does, holding
  the lock.
- **Both kill switches:** eligibility `IsEnabled = false` → return NULL; config `IsEnabled = false`
  → return NULL. Missing eligibility row → `RAISE EXCEPTION` (loud, matching the C#).
- **Effective values** are `config.X` falling back to `entityType.DefaultX`, per field.
- **Period key:** `NEVER` → `''`, `YEARLY` → `YYYY`, `MONTHLY` → `YYYY-MM`, `FY` → the financial-year
  key. FY reads `FINANCIAL_YEAR_START` from `sett."OrganizationSettings"`, preferring the tenant row
  over the `CompanyId IS NULL` platform default, accepting either a month number or a month name, and
  falling back to the calendar year on anything unparseable. Unknown policy → treat as `YEARLY`.
- **Rollover** resets `LastSequence` to 0 when the period key changes, then increments.
- **Token rendering:** `{PREFIX}`, `{SUFFIX}`, `{YYYY}`, `{YY}`, `{MM}`, `{DD}`, `{FY}`,
  `{COMPANYID}`, and `{SEQ:0000}`. **The `SEQ` width is the number of digits typed, not their numeric
  value** — `{SEQ:0000}` means pad to 4, and the counter is allowed to grow past it (9999 → 10000).
  Getting this wrong produces plausible-looking codes that are wrong only at the boundary.

Add a header comment stating that this function and `NumberSequenceGenerator.cs` are two
implementations of one contract and must be changed together, naming the other file. Add the mirror
comment to the C# side. This is the only defence against the next drift.

## C. Decide: per-row or block-reserve

`pg_advisory_xact_lock` is held until the transaction ends, so a per-row call inside an import
transaction takes the lock on the first row and **holds it for the entire import**. A 1,200-row import
therefore blocks every UI contact creation for that tenant for the duration.

Decide and argue one:

- **Per-row call.** Simplest, no gaps, exactly matches UI semantics. Cost: the sequence lock is held
  for the whole batch. Whether that is acceptable depends on the import transaction's actual scope —
  **read the execute function and state whether it is one transaction for the whole import or one per
  row/chunk**, because that single fact decides this question. Report what you found.
- **Block reservation.** Take the lock once, advance `LastSequence` by the row count, release, then
  render codes locally from the reserved block. Short lock hold. Cost: **rows that fail validation
  leave permanent gaps in the sequence.** For `ContactCode` a gap is cosmetic. For a donation
  `ReceiptNumber` a gap is an audit question someone will eventually have to answer, so say plainly
  which entity you applied it to and why.

Do not pick on implementation convenience. Pick on what the batch's transaction scope actually is,
and on whether the entity tolerates gaps.

## D. Contacts

Replace step 5e. On generation returning NULL (a kill switch is off), the fallback must be
**deliberate and documented**, not the current accident. State what you chose:

- keep `ContactId::TEXT` as an explicit disabled-generation fallback, or
- leave `ContactCode` NULL and let the column's nullability decide.

Check whether `ContactCode` is `NOT NULL` in the schema and whether anything (certificate lookup,
`GetContactByCode`) breaks on NULL before choosing. **`GetContactByCode` resolves a contact by this
column** — a NULL or a duplicate here is a lookup that returns the wrong contact or none.

## E. Donations

Precedence rule, to be implemented and stated explicitly:

- Spreadsheet supplies a receipt number → **keep it**. It is very likely a historical receipt being
  migrated, and overwriting it destroys the tenant's own audit trail.
- Blank → **generate** from `GLOBALDONATION`, using the row's donation date as `contextDate` so
  period-reset tokens land in the right period. Do not use `now()`; a back-dated donation must get a
  code from its own year.

Then handle the collision this creates: a file-supplied receipt number can duplicate one the sequence
will later generate. Report whether `ReceiptNumber` has a uniqueness constraint today, and if it does
not, say whether one should exist rather than adding it silently.

## F. Existing rows

Do **not** backfill. Write the audit query only (§ A.3 sizes it) and report the count.

Re-coding existing contacts changes an identifier that may already be printed on a document, quoted in
an email, or stored in a tenant's own external system. That is the user's decision, not this task's.
State the option and its risk; leave the data alone.

## G. Verification

Deliver, under `sql-scripts-dyanmic/`, a script that is read-only or transaction-wrapped-and-rolled-back:

1. The advisory-lock key equivalence check from § B.
2. A rendering check for each pattern token, including `{SEQ:0000}` at 1, 9999 and 10000.
3. FY period-key resolution for a tenant with `FINANCIAL_YEAR_START` set, one without, and one with an
   unparseable value.
4. A contact-code format distribution query — after an import, generated and UI-created codes must be
   indistinguishable in shape.

Do not run any of it. The user runs it.

## Out of scope

- Any change to `NumberSequenceGenerator.cs` beyond the mirror comment in § B.
- Any change to `sett."NumberSequenceEntityTypes"` / `Configs` seed data — report what is missing,
  deliver an idempotent seed script if `CONTACT` is absent, do not run it.
- Backfilling existing codes.
- Column mapping, CSV upload, or anything else deferred on the import roadmap.
- Adding a uniqueness constraint to `ReceiptNumber` — report the recommendation only.

## Output

Stage everything. Report:

1. Which contact execute function is live, how you determined it, and which copies are dead.
2. Whether `CONTACT` and `GLOBALDONATION` are seeded, with the read-only query.
3. The worked example proving the advisory-lock keys match bit for bit.
4. The import transaction scope you found, and your per-row vs block-reserve decision with the argument.
5. The contact NULL-generation fallback you chose and whether `ContactCode` is `NOT NULL`.
6. The donation precedence rule as implemented, and whether `ReceiptNumber` is unique today.
7. The count of existing import-shaped contact codes, and the explicit statement that you did not
   backfill.
8. The migration, if any, that the user must create.
9. Confirmation you touched nothing outside the two execute functions and the new sequence function.
10. Anything you could not complete and why.
