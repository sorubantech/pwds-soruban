# Custom fields — storage type, indexing, and per-entity limits

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`. State the migration; the user creates it.
- Do NOT execute SQL against any database. Idempotent scripts, handed off.
- `PSS_2.0_Backend` / `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server.
- Enterprise-level app. No shortcuts. Backend enforcement, never frontend-only.

**Target scale: 500,000+ records per tenant per entity.** Every decision below is judged at that size,
not at demo size. Anything that works at 500 rows and collapses at 500,000 is a defect.

---

## The three findings this task exists to fix

### 1. The column is `text`, not `jsonb`

`ApplicationDbContextModelSnapshot.cs` declares `CustomFields` as `HasColumnType("text")` on all three
entities that have it — `Contact` (`corg."Contacts"`), `ContactDonationPurpose`
(`corg."ContactDonationPurposes"`) and `Country` (`com."Countries"`). Elsewhere in the codebase JSON
columns are declared properly (`AiAuditLogConfigurations.cs:19-20`, `ChatMessageConfigurations.cs:12-14`
and the rest of the Aida configurations all use `jsonb`). Custom fields did not get the same treatment.

The consequence at 500K rows:

- `text` is stored as raw characters. Every key read re-parses the whole document. `jsonb` is stored
  pre-decoded in binary, so `->>` is a lookup, not a parse.
- **`text` cannot be indexed for key access at all.** A GIN index needs `jsonb`. Filtering
  `CustomFields::jsonb ->> 'bloodGroup' = 'A+'` on a `text` column casts and parses **every one of the
  500,000 rows on every query**, single-threaded per worker, with no index able to help.
- The code already believes it is `jsonb` — `GridQueryBuilderHelper.cs:310` says *"the flagIcon value in
  CustomFields JSONB column"*. The comment describes the intended design; the schema never matched it.

**Fix the type.** This is the highest-leverage change in the task and it is cheapest now, before volume.

### 2. Custom-field sorting sorts one page, not the dataset

`GridQueryBuilderHelper.ApplyCustomFieldSortingToList` (`:313-348`) is called **after
`ToListAsync()`** — its own comment at `:311` states this. It therefore reorders the rows already
fetched for the current page.

That is not slow sorting. **That is wrong sorting.** A user sorting a 500K-row grid by a custom field
descending gets the first page of the *default* order, re-sorted among its own 25 rows, presented as if
it were the top of the dataset. There is no error and no visual cue. The user makes decisions on it.

Sorting must happen in the database, in the `ORDER BY`, before paging. Once the column is `jsonb` this
is expressible and indexable. Until then, a custom-field sort should be **refused**, not faked.

### 3. Global search does an unindexed full-blob scan

`GetContact.cs:69` — `!string.IsNullOrEmpty(c.CustomFields) && c.CustomFields.ToLower().Contains(searchTerm)`
— translates to `lower("CustomFields") LIKE '%term%'` across the table. Sequential scan, `lower()` on
every row, no index possible. Same shape at `GetCountries.cs:52-53` (harmless there — small table;
fatal on Contacts).

It also searches *keys as well as values*, so a search for "phone" matches every row that merely has a
`phone` custom field. Decide whether custom fields belong in global search at all, and if they do,
implement it so it is indexable.

---

## The limits — decide, justify, enforce

The user's question was "how many custom fields per entity?" The honest answer is that **field count is
not the variable that costs money — indexed field count is.** Fifty display-only keys in a `jsonb`
document cost close to nothing to read. One filterable key on a `text` column costs a full scan. Set
two separate budgets accordingly.

Recommended starting values — implement these unless you can argue better, and state your reasoning
either way:

| Budget | Value | Why this number |
|---|---|---|
| Custom fields per entity per tenant | **50** | A form-design limit more than a database one. Past ~50 extra attributes the tenant needs a related entity, not more keys. Also keeps the document small enough to stay inline. |
| **Filterable / sortable** custom fields per entity per tenant | **5** | Each one costs a real index on a 500K-row shared table — storage, write amplification on every insert/update, and autovacuum work. This is the budget that actually has a price. |
| Value length, text-type custom field | **500 chars** | Keeps the whole document under PostgreSQL's ~2KB compression threshold so the row stays inline. A field needing more is a notes field, and must be non-filterable. |
| Total assembled document per row | **~2KB target, hard cap higher** | Above ~2KB PostgreSQL compresses the value; above ~8KB it moves out of line to TOAST, adding an extra I/O to any read that selects the column. State the cap you set. |

Verify the TOAST/compression thresholds against the PostgreSQL version actually in use rather than
taking the numbers above on faith, and report what you found.

**Enforcement is server-side, in the create/update custom-field handlers, per tenant per entity.** A
disabled "Add" button in the UI is not a limit. Note that `CreateCustomFieldValidator`
(`CreateCustomField.cs:26`) currently validates `FieldName` uniqueness **globally across `sett.Fields`**
rather than per tenant — confirm whether `Field.CompanyId` is even stamped on creation (the handler
never sets it) and report, because every per-tenant count depends on the answer.

Counting rule: the cap counts **active, non-deleted custom fields attached to that entity's grid for
that tenant** — `sett.GridFields` with `ParentObject = 'customFields'` and the tenant's `CompanyId`.
Say what happens to a tenant already over the cap when the limit ships: existing fields keep working,
new ones are refused. Never delete a tenant's data to enforce a new limit.

---

## Indexing — the multi-tenant trap

The tables are **shared across tenants**. A naive expression index for one tenant's custom field is
built over every tenant's rows, including the majority who do not have that field at all. Ten tenants
× five filterable fields is fifty full-table indexes on one 500K-row table, and every insert pays for
all of them.

**Use partial indexes scoped to the owning tenant:**

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_contacts_cf_<tenant>_<fieldkey>
  ON corg."Contacts" ((("CustomFields")->>'<fieldKey>'))
  WHERE "CompanyId" = <tenantId> AND "IsDeleted" = FALSE;
```

Each index then covers only that tenant's slice. This is what makes a per-tenant filterable budget
affordable at all.

**The predicate must match for the index to be used.** Every custom-field query must carry the
`CompanyId` equality predicate — which tenancy requires anyway, so confirm the existing query paths
already do rather than assuming. Verify with `EXPLAIN` that the planner actually chooses the partial
index; an index the planner ignores is pure write cost. Deliver the `EXPLAIN` commands for the user to
run; do not run them.

Decide and justify between:

- **A GIN index** on the whole `jsonb` column (`jsonb_path_ops`) — one index serves equality/containment
  on *any* key, so it scales with tenants rather than with fields. It does **not** help range queries,
  `ORDER BY`, or prefix matching, and it is larger and slower to update.
- **Per-field partial B-tree expression indexes** as above — support equality, range and sort, are small,
  but need one per declared-filterable field.

State which you chose, for which access patterns, and why. "Both" is acceptable if you say which
queries each serves.

Index creation must be **`CONCURRENTLY`** — a plain `CREATE INDEX` takes an `ACCESS EXCLUSIVE`-blocking
share lock on a 500K-row production table. Note that `CONCURRENTLY` cannot run inside a transaction
block, which constrains how it can be delivered in a migration; state how you handled that.

---

## Which entities may have custom fields

The rule is **row volume and write frequency**, not entity importance.

- **Allow** on low-volume, user-curated master records: Contact, Beneficiary, Program, Grant, Event,
  Campaign, Donation Purpose. Human-entered, thousands of rows, read far more than written.
- **Deny** on high-volume transactional and machine-written tables: donations/transactions, audit and
  log tables, notification and email queues, import staging, anything a background job writes at rate.
  These are precisely the tables that reach 500K+ first, and they are the ones where an extra `jsonb`
  column and its indexes are paid for on every write.

`ContactDonationPurpose` and `Country` already carry a `CustomFields` column — assess both against this
rule and report. `Country` is a small reference table and is fine. Judge `ContactDonationPurpose` on its
actual row count and write pattern, and say so.

**Make the allow-list explicit and data-driven**, not a hardcoded `switch` — a flag or configuration on
the entity's `sett.Grids` row is the natural home, since that is already where custom fields attach.
Adding an entity later must not require a code change. Report the mechanism you chose.

Do not add a `CustomFields` column to any new entity in this task.

---

## Forward constraint: database segregation is planned

A future architecture is planned in which a **common platform/security database** holds tenant
management, credentials and login, and **each tenant's business data lives in its own database**.
Nothing in this task builds that. But two decisions above change because of it, and one sequencing risk
becomes the most important item in this file.

### The sequencing risk — do the type migration BEFORE segregation

`text` → `jsonb` on one shared database is **one** operation, one window, one outcome. After
segregation it is **N** operations across N tenant databases, each with its own window, each able to
fail independently, each with its own population of malformed values — and a partial failure leaves
tenant databases on different schemas, which is the expensive kind of problem.

Do not defer this migration until after segregation. State this explicitly in your report.

### Partial indexes become plain indexes — so generate them, don't hand-write them

The `WHERE "CompanyId" = <tenantId>` partial predicate exists **only** because the tables are shared
today. In a per-tenant database the table holds one tenant's rows and a plain expression index is
correct; the partial predicate would be permanently-true dead weight needing a rebuild.

So do not hand-author index DDL. Build a small **index provisioning routine** driven by the
"filterable" flag on the field definition, with tenancy mode as an input: it emits partial indexes in
shared mode and plain indexes in per-tenant mode. Same metadata, same call site, different DDL. That
makes segregation a configuration change here rather than a rewrite.

**Keep the `CompanyId` column even in a per-tenant database.** It costs nothing, keeps one code path
across both modes, and keeps a tenant's rows self-identifying if data is ever restored, merged or
migrated. Queries keep the predicate.

### The decision that actually matters: where custom-field *definitions* live

Values live in the tenant business database. The definitions — `sett.Fields` custom rows,
`sett.GridFields` tenant rows — could go either way, and the wrong choice is very expensive.

**Recommendation: tenant configuration lives in the tenant business database, alongside the data it
describes.** The platform/security database holds identity, credentials, the tenant registry and
subscription/billing — and nothing that is joined to business rows.

The reason is not preference, it is capability. PostgreSQL cannot join across databases without a
foreign data wrapper. If definitions sit centrally and values sit per tenant:

- every "what custom fields does this grid have" resolution becomes a second round trip or an FDW hop;
- and **every PL/pgSQL function that reads configuration stops working entirely** — which is not
  hypothetical, it is exactly what `import.validate_common` does today when it reads
  `import."ImportGridFields"` from inside the function body. A validator cannot read a table in another
  database.

Product-shipped global configuration — standard grids, global `MasterDatas` with `CompanyId IS NULL` —
is then **seeded and versioned into every tenant database** rather than shared by reference. That
converts the problem into schema/seed propagation across N databases, which is a solved pipeline
problem, instead of cross-database joins, which is not.

Do not implement any of this now. Do confirm that nothing you write in this task makes it harder —
specifically, no new query may join custom-field definitions to business rows in a way that assumes
they are permanently co-resident with the platform tables.

### Make the limits configuration, not constants

Because the filterable-field budget is partly a commercial lever (an Enterprise tenant reasonably gets
more than a Starter tenant) and because its justification changes under segregation, the caps must be
**configuration resolvable per tenant** — and the subscription `Plan` entities already in the model are
the natural key. Do not hardcode 50 and 5 as constants. Ship those as the defaults, resolved through
configuration, so raising them later is a data change.

## Migration and backfill

- `text` → `jsonb` on each affected column. This is a rewrite of the table; state the expected duration
  at 500K rows and whether it needs a maintenance window.
- **Existing values may not be valid JSON.** `GetContactById.cs:118` already handles malformed JSON by
  leaving `CustomFieldsParsed` null — proof the codebase expects it. A `USING "CustomFields"::jsonb`
  cast will **fail the entire migration** on the first bad row. Deliver a pre-flight audit query that
  finds every non-parseable value, and a migration strategy that does not abort on one bad record.
  State what happens to unparseable values: quarantined, nulled with the original preserved, or the
  migration blocks until the user cleans them. Recommend one.
- Empty string is not valid `jsonb`. Normalise `''` to `NULL` before the cast.
- Reversibility: state what the down-migration is and what it loses.
- **Do not create the migration.** State the exact operations; the user creates it.

---

## Code changes that follow the type change

- EF: `HasColumnType("jsonb")` on each property, in the configuration class, matching how the Aida
  configurations do it. Confirm whether Npgsql then requires the CLR property to change and what that
  breaks — the property is `string` today and a lot of code reads it as a string.
- `GetContact.cs:69` global search — fix or scope per the finding above.
- `GridQueryBuilderHelper.ApplyCustomFieldSortingToList` — move the sort into the query, before paging.
  Until it is in the database, a custom-field sort must be refused with a clear message rather than
  returning a page-local sort that looks correct.
- Filtering on custom fields, wherever `DynamicFilterBuilder` / `GridQueryBuilderHelper` expose it, must
  be **restricted to fields the tenant declared filterable** — that is what makes the index budget
  enforceable. An arbitrary key filter with no index is the full scan this whole task exists to remove.
- Anywhere `CustomFields` is read as a raw string and parsed in C#, confirm it still works.

---

## Output

Stage everything (`git add` in each affected repo). Report:

1. The exact migration operations the user must create, per column, including the empty-string
   normalisation and the malformed-value strategy — with the pre-flight audit query.
2. Expected migration duration at 500K rows and whether a window is needed.
3. The limits you set — total, filterable, value length, document size — each with its reasoning, and
   confirmation the TOAST/compression thresholds were verified against the deployed PostgreSQL version.
4. Where each limit is enforced server-side, and what a tenant already over the limit experiences.
5. Whether `Field.CompanyId` is actually stamped on custom-field creation, and what that means for
   per-tenant counting and for the global `FieldName` uniqueness rule.
6. The indexing strategy — GIN vs partial expression, which access patterns each serves, the index
   naming/creation scheme, how `CONCURRENTLY` is delivered, and the `EXPLAIN` commands the user should
   run to confirm the planner uses them.
7. Confirmation that every custom-field query path carries the `CompanyId` predicate the partial indexes
   depend on.
8. The entity allow-list, the data-driven mechanism that holds it, and your assessment of
   `ContactDonationPurpose` and `Country` against the volume rule.
9. What you did about page-local custom-field sorting, and the interim behaviour before the sort is in
   the database.
10. What you did about the global-search full-blob scan.
11. A before/after measurement plan the user can run: a filter on a custom field over a 500K-row table,
    timed on `text` with no index and on `jsonb` with the index. Deliver it runnable; do not run it.
12. Confirmation that the index DDL is generated from field metadata with tenancy mode as an input —
    not hand-authored — and that nothing added in this task assumes custom-field definitions stay
    co-resident with platform tables after database segregation.
13. Where the caps are read from (configuration, plan-resolved) rather than hardcoded.
14. Anything you could not complete and why.
