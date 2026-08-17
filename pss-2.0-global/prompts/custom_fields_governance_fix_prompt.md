# Custom-field governance — close the six gaps left by the first pass

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`. State the migration; the user creates it.
- Do NOT execute SQL against any database. Idempotent scripts, handed off.
- `PSS_2.0_Backend` / `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server.
- Enterprise-level app. No shortcuts. Backend enforcement, never frontend-only.

**Collision warning — read first.** A separate session owns plan tiering
(`custom_fields_plan_tiering_prompt.md`) and is editing `billing.PlanQuotas` seeds, the platform plan
editor, and the tenant usage panels. **Do not touch `CustomFieldPolicy`, `ICustomFieldPolicy`,
`CustomFieldPolicyOptions`, `CustomFieldMeterCodes`, `MeterCodes`, `plan-usage-panel.tsx`,
`plan-status-banner.tsx` or anything under `presentation/hooks/useEntitlements/**`.** If you believe a
change is needed there, stop and report it rather than editing.

---

## Context

The `text` → `jsonb` conversion and the index planner landed and are largely correct. The migration has
**not been created or applied yet** — the columns are still `text` in the database. That ordering is
what makes the items below fixable now rather than incidents later.

Six things were missed. They are listed in the order they will hurt.

---

### 1. The 360° child-entity filter path was never migrated (breaks at runtime on migration day)

`GridQueryBuilderHelper.BuildChildCustomFieldCondition` (around lines 1896-2039) still builds:

```csharp
var propertyAccessLower = Expression.Call(propertyAccess, toLowerMethod);
var containsFieldKey    = Expression.Call(propertyAccessLower, containsMethod, Expression.Constant(fieldKeyPattern));
var containsSearchValue = Expression.Call(propertyAccessLower, containsMethod, Expression.Constant(searchValue));
condition = Expression.AndAlso(containsFieldKey, containsSearchValue);
```

plus `string.IsNullOrEmpty(propertyAccess)` on the same column. Against a `jsonb` column that emits
`lower(jsonb)` and `PostgreSQL` rejects it with **42883 — function lower(jsonb) does not exist**. Every
360° child-entity custom-field filter dies the moment the migration runs.

Migrate it to the same seam the parent path now uses: `CustomFieldDbFunctions.JsonText(document, key)`,
with the explicit `!= null` guard before any value comparison. Note the semantic change and make it
deliberately — the old code matched the key name and the value anywhere in the blob (so a row whose
*other* field contained the search text matched); the new code targets the key. That is the correct
behaviour, not a regression, but say so in your report.

Then **grep the whole backend for any remaining `.CustomFields` usage that is not through
`CustomFieldDbFunctions`** — `ToLower()`, `Contains(`, `IsNullOrEmpty(`, `StartsWith(`, `Length`,
`PropertyOrField("CustomFields")`, string concatenation, raw SQL. Use PowerShell `Select-String` across
both nested repos, not Grep alone — Grep has silently missed nested-repo files in this codebase before.
List every hit and its disposition (migrated / safe / left alone with reason). An empty result is not
acceptable as evidence; show the command you ran.

### 2. Close the governance loop — filter and sort must honour declared keys

`ICustomFieldRegistry`'s own doc says *"only declared-filterable keys get an index and only indexed keys
may be filtered on — that is the whole governance loop."* Today that is enforced on exactly one path.

- `BuildCustomFieldCondition` (~line 470) validates `IsValidCustomFieldKey` only — charset and length.
- `ApplyCustomFieldSorting` (~line 248) does the same.
- Only `BuildCustomFieldSearchPredicate` takes `declaredKeys`.

So a client can filter or sort on any syntactically valid undeclared key and get an unindexed
sequential scan on a 500,000-row table — precisely the outcome the index budget exists to prevent.

Thread the declared-key set into both paths. Design constraints:

- The registry call is `async` and these are synchronous expression builders on the grid hot path. **Do
  not** block on `.Result` / `.GetAwaiter().GetResult()`. Resolve the key set once per request, above
  the expression-building layer, and pass it down. Show where you resolved it and why that layer.
- Decide and justify the **failure mode** when an undeclared key arrives: reject with a 400 naming the
  key, or silently drop the rule. Reject is almost certainly right — a silently dropped filter returns
  wrong data that looks correct — but argue it, and make sure the message is actionable ("Custom field
  'x' is not enabled for filtering on this grid").
- Empty declared set must mean **no custom-field filtering**, never "allow everything".
- Trace every caller that reaches these two methods and confirm each supplies the set. A caller that
  quietly passes `null` and falls back to permissive re-opens the hole.

### 3. `CreateCustomField` counts per tenant, not per entity

The limit is named `MaxFieldsPerEntity`. The check is:

```csharp
var existingCustomFields = await dbContext.Fields
    .CountAsync(f => f.FieldSource == "Custom" && f.IsDeleted == false, cancellationToken);
```

No entity or grid predicate. 50 fields on Contact exhausts the ceiling for Country. Scope the count to
the entity the field is being created for, and confirm which column actually carries that association —
read the `Field` / `GridField` / `Grid` relationship before writing the predicate, do not assume.

While you are in there: the governance prompt asked whether `Field.CompanyId` is stamped on creation.
It is not — the handler relies on the global query filter. **Report** what that means for the
pre-existing global (rather than per-tenant) `FieldName` uniqueness constraint. Do not fix the
uniqueness constraint in this pass; it needs a migration and a decision. Just state the exposure
precisely.

### 4. Registry admits `text` carriers it claims to exclude

`CustomFieldRegistry.GetEntities()` filters on `ClrType.GetProperty("CustomFields")?.PropertyType ==
typeof(string)`, while the interface doc promises "if and only if it actually has a CustomFields column
mapped to jsonb". Benign today — all three carriers are jsonb — but a fourth carrier added as `text`
would be silently admitted, and every `jsonb_extract_path_text` emitted for it would fail.

Assert the mapped column type from the EF model (`IProperty.GetColumnType()`), not the CLR type. Decide
whether a `text` carrier should be **excluded silently** or **throw at startup** — throwing is the
better failure for a governance component, since silent exclusion reproduces exactly the "feature just
appears to be off" mode the doc warns about. Argue whichever you pick.

### 5. `BulkUpdateGridConfiguration` misses newly-added filterable rows

The budget check counts `existingFields` — the tracked list loaded from the database. Updates to those
rows are counted (same object references, mutated in place before the check). Rows created through
`dbContext.GridFields.Add(newField)` in the same payload are **not**. A save that adds thirty new
filterable custom-field rows in one request passes the check and commits sixty indexes' worth of intent.

Count the post-save state: existing-and-surviving + newly-added, excluding soft-deleted. Confirm the
`ParentObject` comparison stays case-insensitive against `CustomFieldMetadata.ParentObject`.

### 6. Ship the SQL safety net for the migration

Nothing was written to disk. The `text` → `jsonb` migration is the single riskiest step in this
programme and it currently has no pre-flight. Deliver, under `sql/` (match the existing folder
convention — find it, do not invent one):

- **Pre-flight audit query.** Per carrier table (`Contact`, `ContactEmailAddress`, `Country` — confirm
  the list from the EF model, do not take my word for it): count of rows where `CustomFields` is NULL,
  empty string, whitespace, not valid JSON, and valid JSON whose root is not an object. The last two
  are the rows that will fail the cast. Include enough identifying columns to find them.
- **Normalisation script**, idempotent: `''` and whitespace → NULL. State plainly what it does with
  rows that are non-parseable or non-object — it must **not** silently discard tenant data. Either
  quarantine them into an audit table or leave them and require a human decision. Say which and why.
- **The migration's `USING` clause**, written out for the user, with an explicit statement of what
  happens to any row that still fails after normalisation (the transaction aborts — say so).
- **`EXPLAIN (ANALYZE, BUFFERS)`** statements for one filter, one sort and one global search over a
  custom field, so index usage can be confirmed after the DDL runs. Include what a *good* plan looks
  like (Index Scan / Bitmap Index Scan naming the emitted index) versus the failure signature (Seq Scan
  — the index expression did not match the query expression).

Also fix the comment in `ContactConfiguration.cs` claiming *"text cannot be GIN-indexed for key
access"*. `text::jsonb` is immutable, so expression indexes over `text` are legal — the real reasons for
the conversion are storage (parsed binary, no reparse per row), operator support, and validation at the
column. State those instead. Check whether the same wording was copied into the other two
configurations and fix all occurrences.

---

## Explicitly out of scope

- The `text` → `jsonb` migration itself — the user creates it.
- Anything the plan-tiering session owns (see collision warning).
- The global `Field.FieldName` uniqueness constraint — report it, do not change it.
- Frontend work of any kind, unless item 2's rejection path needs an error message surfaced, in which
  case say what you changed and keep it minimal.

## Output

Stage everything (`git add` in each affected repo). Report:

1. Every remaining raw-`CustomFields` usage found by the sweep, the exact command you ran, and each
   hit's disposition.
2. The semantic change in the child-entity filter path, stated plainly.
3. Where you resolved the declared-key set for the filter/sort paths, why that layer, and the failure
   mode you chose for an undeclared key with your reasoning.
4. Every caller of the filter/sort paths and confirmation each supplies the declared set.
5. The per-entity scoping predicate for `CreateCustomField` and which column carries the association.
6. The `Field.CompanyId` / global `FieldName` uniqueness exposure, precisely.
7. Silent-exclude vs throw-at-startup for a `text` carrier, and why.
8. The SQL filenames delivered, and confirmation each is idempotent and re-runnable.
9. What the normalisation script does with non-parseable and non-object rows.
10. Confirmation no migration was created by you, and confirmation you edited nothing the plan-tiering
    session owns.
11. Anything you could not complete and why.
