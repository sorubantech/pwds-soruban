# Import custom fields — tenant-aware field plan

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`. State the migration; the user creates it.
- Do NOT execute SQL against any database. Idempotent scripts, handed off.
- `PSS_2.0_Backend` / `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server.
- Enterprise-level app. No shortcuts. Backend enforcement, never frontend-only.
- No `window.confirm` / `alert` / `prompt`. Dialog components only.

**Prerequisites — confirm before starting.** This task sits downstream of the custom-field governance
work. Confirm all three, and stop and report if any is not true:

1. `custom_fields_governance_fix_prompt.md` has completed and its changes are staged. (Done.)
2. The `text` → `jsonb` migration has been applied — the three carrier columns are `jsonb` in the
   database. **This one is blocking**; § E writes into that column.

Known gap, deliberately **not** blocking this task: the custom-field expression indexes have not been
created. `CustomFieldIndexPlanner` is registered in DI but has no caller, so its DDL has never been
emitted and every custom-field filter is a sequential scan. This task must not sort or filter on a
custom-field column anyway (§ J), so it is unaffected. Do not build the DDL-emission path here — it is
separate work. Do not add a call to `CustomFieldIndexPlanner`.

---

## The problem

A tenant defines a custom field, it appears on their contact form, and **import cannot carry it.**

Custom fields are not dynamic DDL and there is no per-tenant code generation. A custom field is:

- a `sett.Fields` row with `FieldSource = "Custom"` (`CreateCustomField.cs:61`), whose `FieldKey` is the
  camelCase of the field name (`:71-78`) and whose `FieldCode` is the uppercase form (`:63-70`);
- attached to a grid by a `sett.GridFields` row with `ParentObject = "customFields"` and a `CompanyId`
  (`AddCustomFieldGridSchema.cs:66-77`) — **`GridField.CompanyId` is the tenant scope**;
- rendered from the grid's `GridFormSchema` JSON;
- **stored as one JSON string column**: `Contact.CustomFields` (`Contact.cs:45`).

Import's only current path is `ContactImport-fn-execute.sql:642`, which reads a staging field literally
named `CustomFields` and writes it straight through — i.e. the user is expected to hand-author a JSON
blob in a spreadsheet cell, unvalidated. Nobody will do that, and a malformed blob imports clean.

**The root cause is one line.** `IDynamicFieldGeneratorService.GenerateFieldsAsync(int gridId, ...)`
takes no tenant. The field plan is global, so every downstream consumer — template, staging DDL, parse,
review grid, result workbook — is blind to tenant fields by construction.

## The fix

Make the field plan **tenant-resolved at runtime**, and let custom fields ride through the pipeline as
first-class fields: one template column each, one staging column each, validated by the common layer,
assembled into the target JSON at execute.

**Do not add tenant rows to `import.ImportGridFields`.** That table is global — neither it nor
`ImportGridDefinition` has a `CompanyId` — and per-tenant rows in a shared config table is a data-leak
shape, not a design.

**Forward note, do not build:** column mapping (user uploads their own file and maps their headers to
our fields) is a deferred follow-on. It needs exactly this same tenant-resolved field plan as its list
of mapping targets. Build the plan as a runtime resolution so mapping is additive later. Do not add any
mapping UI, mapping persistence, or mapping API in this task.

---

## A. Link the import grid to its setting grid

Custom fields hang off `sett.Grids` via `GridFields`. `ImportGridDefinition` has **no link to
`sett.Grids`** — it has `EntityType` ("Contact") and `GridCode`, and `sett.Grids` has its own
`GridCode`. Matching those by string coincidence is guessing, and a silent mismatch means custom fields
never resolve with no error anywhere.

Establish the link **explicitly**. The recommended shape is one nullable column on
`ImportGridDefinition` naming the setting grid (code or id — pick one and justify), seeded per grid.
Null means "this import grid has no custom-field support", which must be a supported state, not a crash.

If you can prove an existing reliable key already joins them, use it and show the proof — the actual
seeded values on both sides, not the column names.

**Do not create the migration.** State the column, type, nullability, and the idempotent seed.

## B. Tenant-aware field plan

Change the contract to `GenerateFieldsAsync(int gridId, int companyId, ...)` — or an equivalent that
makes the tenant impossible to omit. A nullable/optional tenant that silently degrades to "no custom
fields" is the failure mode to design out.

Resolution: `sett.Fields` where `FieldSource = "Custom"`, joined through `sett.GridFields` on the linked
grid with `ParentObject = "customFields"` and `CompanyId = <tenant>`, active and not deleted. Match the
active/deleted predicates the custom-field queries already use (`GetCustomFields.cs:32`) — do not invent
different ones.

**Every caller must pass the correct tenant, and they do not all get it from the same place.** There are
five, find them all and confirm each:

- `ImportParseService.cs:151` — **runs in Hangfire**. The tenant is `session.CompanyId`. `HttpContext`
  is absent or, worse, belongs to whatever request the worker last saw. The P4 comment at `:122-125`
  states this rule; follow it.
- `TemplateGeneratorService.cs:33` and `:69` — request-scoped caller.
- `GetStagingData.cs:97` — the review grid's columns.
- `ImportResultWorkbookService.cs:126` — may run outside a request; resolve from the session.

A caller that resolves the tenant from ambient context inside a background job is the defect this whole
section exists to prevent. State, per caller, where its tenant value came from.

## C. Staging column naming — collision is the trap

Custom fields become staging columns alongside standard and child-generated ones (`Email1`,
`Email1_Type`, …). Nothing today prevents a tenant naming a custom field so its key collides with a
standard field or a generated child name.

Define a deterministic, collision-proof naming rule and state it. Requirements:

- Distinguishable from standard/child columns by construction (a reserved prefix is the obvious shape).
- Safe as a PostgreSQL identifier: **63-byte limit**, quoting, case, non-ASCII field names. A tenant with
  a long or non-Latin custom field name must not produce a truncated or invalid identifier.
- **Collisions fail loudly.** If two resolved fields would produce the same staging column, fail the
  parse with a readable configuration error naming both fields. Never let one silently overwrite the
  other — that is a data-integrity bug the user cannot see.

`StagingTableService` already builds the DDL from the field list, so the table becomes tenant-shaped for
free once the plan is right. Confirm that, do not rebuild it.

## D. Validation — the metadata problem

The common validator is **metadata-driven off `import."ImportGridFields"`**, read inside the SQL
function. Custom fields are not in that table and must not be put there (§ above). So the SQL layer
needs a per-session source of field metadata.

**Recommended: a session-scoped field snapshot.** At parse time, persist the complete resolved field
plan — standard *and* custom — into a session-scoped table, and have `import.validate_common` read the
snapshot when one exists, falling back to `ImportGridFields` when it does not.

Two reasons, and the second matters as much as the first:

1. It is the only way custom fields get required/type/length/regex/lookup validation, which is the entire
   point of the common layer that just landed.
2. **It fixes an existing bug.** Staging columns are generated at parse time while validation reads
   config live, so a config edit between parse and re-validate makes the table and the metadata disagree
   — today handled only by an `information_schema` guard that skips the column, i.e. silently stops
   validating it. A snapshot makes the session validate against the config it was actually parsed with.

Evaluate this against alternatives and justify your choice. If you judge the blast radius on the
newly-landed validator too large and choose a narrower shape, say so explicitly and state what is lost.

Hard requirements either way:

- **Sessions parsed before this feature must keep validating exactly as they do now.** The fallback path
  is not optional.
- Custom-field metadata must carry enough to drive the existing rules: data type (`Field.DataTypeId` →
  `sett.DataTypes`), required, max length, and any option list. Map `DataTypeCode` to the `DataType`
  strings `ImportGridFields` already uses; report any custom data type with no import equivalent rather
  than defaulting it to text silently.
- If a custom field's type implies a fixed option list (check `Field.FieldTypeId` / `FieldTypeCode` and
  any option configuration), it must validate as a lookup, not as free text.
- No change to `SourceRowNumber` anchoring, batching, `has_more`, or progress reporting.

## E. Execute — assemble the JSON

At execute, build the target JSON object from the validated per-field staging columns and write it to
the entity's custom-field column (`Contact.CustomFields` for CONTACT).

- **The JSON key must be `Field.FieldKey`** — the camelCase form. Verify against what the contact
  form/save actually writes; if import writes a different key the value is stored and then invisible on
  the screen, which is worse than not importing it. State how you verified.
- Type the values properly — a date custom field must not land as a raw string if the form writes a
  date. Match the form's shape exactly.
- Omit unfilled fields rather than writing nulls, unless the form writes nulls. Follow the form.
- **Remove the raw `CustomFields` passthrough column** from the user-facing field plan
  (`ContactImport-fn-execute.sql:642`, `:689`). Asking a user to paste JSON into a cell is not a feature.
  If you believe an escape hatch must stay, argue it and define precedence explicitly — silent
  last-writer-wins between a raw blob and typed columns is not acceptable.
- Update, not just insert: if an import path can update an existing row, state whether the JSON is
  replaced or merged, and why.

## F. Template

Custom columns appear in the tenant's downloaded template, after the standard columns.

- Header = the custom field's display name, marked required if it is.
- Data-type-appropriate cell formatting, consistent with how standard columns of that type are written.
- If the field has an option list, include it the way standard lookups are included today
  (`IsLookUpTableToExcel` and the existing lookup-sheet mechanism) — do not invent a second mechanism.
- Two tenants downloading the same grid's template must get **different** files. Say how you confirmed
  no caching layer (HTTP, in-memory, blob) serves one tenant's template to another. This is the
  highest-severity leak in this task.

## G. Read path — imported values must be visible

`ContactSchemas.cs:107-113` defines `ContactCustomFieldsDto` with **four hardcoded properties**
(`AnniversaryDate`, `ReferredBy`, `PreferredContactTime`, `TaxIdNumber`), populated into
`CustomFieldsParsed` (`:216`). Any custom field outside those four is stored in the JSON and then
invisible to that typed read path.

Importing a value the user cannot then see on the record is not a completed feature. Either make that
read path dynamic, or prove the screen renders custom fields from `GridFormSchema` + the raw JSON and
that `CustomFieldsParsed` is not the path the UI uses. **Verify which; do not assume.** Report what you
found and what you changed.

## H. Scope — which grids

The mechanism is generic; enable it only where the target entity actually has a custom-field JSON column.

- CONTACT qualifies (`Contact.CustomFields`).
- Check BULKDONATION's target entity and state whether it qualifies. If it does not, the link column
  from § A stays null for it and everything must behave exactly as today.

Do not add a custom-field column to any entity in this task.

## I. Negative scenarios — handle and report each

1. Tenant has no custom fields → identical behaviour to today, byte for byte in the template.
2. Custom field **deleted, soft-deleted or toggled off** between template download and upload → the
   uploaded file has a column the plan no longer contains. Warn, ignore the column, import the rest. Do
   not fail the file.
3. Custom field **added** between template download and upload → the column is missing from the file.
   Not an error unless the field is required; if required, say so clearly and name the field.
4. Custom field **renamed** between download and upload → header no longer matches. Header matching is
   `DisplayName` or `FieldName`, exact, case-insensitive (`FileParserService.cs:120-121`). State the
   resulting behaviour and whether matching on the stable `FieldKey` as a fallback is warranted.
5. Config change between parse and validate → covered by § D; confirm.
6. **Cross-tenant leakage** — tenant A's custom field must never appear in tenant B's template, staging
   table, review grid, validation metadata, or result workbook. State how each of those five is scoped.
7. `CreateCustomFieldValidator` enforces `FieldName` uniqueness **globally across `sett.Fields`**, not
   per tenant (`CreateCustomField.cs:26`). Confirm whether `Field.CompanyId` is actually stamped on
   creation — the handler never sets it. Report what you find; if custom fields are not tenant-stamped
   on `sett.Fields` and tenancy rests solely on `GridField.CompanyId`, say so plainly, because every
   scoping decision above depends on it. **Do not change custom-field creation in this task** — report it.
8. A custom field whose display name contains a formula-injection prefix → headers are tenant-authored
   and go into a workbook. P6.6 sanitisation applies to custom column headers in the template, the
   result workbook and the review grid.

## J. Field-count limits and the JSON storage constraint

**Read this section carefully — it was written before the governance work landed and has been corrected.
Do not act on any earlier draft you may have seen.**

### The column is `jsonb`, not `text`

The three custom-field carriers are **`Contact` (`corg."Contacts"`), `ContactEmailAddress`
(`corg."ContactEmailAddresses"`) and `Country` (`com."Countries"`)**. `ContactDonationPurpose` is **not**
a carrier — do not look for a `CustomFields` column on it.

All three moved from `text` to `jsonb` in migration
`20260817091615_Change_Text_To_JsonB_To_CustomFields_In_Contact_Entities`. Confirm the current state
against the EF model before you write anything (`IProperty.GetColumnType()`, or the entity
configurations) rather than against the model snapshot, which may be mid-flight. Consequences you must
build for:

- **Never emit `lower()`, `Contains`, `StartsWith`, `IsNullOrEmpty` or string concatenation against a
  `CustomFields` property.** `lower(jsonb)` does not exist and PostgreSQL raises **42883**. Go through
  `CustomFieldDbFunctions.JsonText(document, key)`.
- Writing the assembled object at execute (§ E) writes **jsonb**, not a string. A malformed blob no
  longer imports clean — the column rejects it. That is an improvement, but the failure now surfaces as
  a database error, so catch it and turn it into a readable per-row import error rather than letting it
  abort a batch.
- `com."Countries"` has **no `CompanyId`** — it is shared reference data. Any tenant-scoping logic you
  write must not assume all three carriers are tenant-scoped.

### The per-entity cap

The cap is `MaxFieldsPerEntity`, resolved through three tiers: `appsettings` section `CustomFields` →
`billing."PlanQuotas"` by `MeterCode` → `billing."SubscriptionOverrides"`. The governance meter codes
are `CUSTOM_FIELDS` and `CUSTOM_FIELDS_FILTERABLE`, held in `CustomFieldMeterCodes` and deliberately
absent from `MeterCodes.All`.

Resolve the cap through `ICustomFieldPolicy` — **do not read `appsettings` directly** and do not
re-derive it. Note that `CustomFieldPolicy.Merge` distinguishes an *absent* meter (fall back to the
configured default) from *present-and-zero* (the plan genuinely forbids it); if you consume the policy
anywhere, preserve that distinction.

`CreateCustomField`'s count predicate was scoped per entity by the governance fix pass. Read the current
predicate before relying on any statement about it here.

### Filterable keys are governed

Only keys declared filterable in `sett."GridFields"` are indexed, and the filter/sort paths reject an
undeclared key rather than silently dropping it. Import must not assume a custom field is filterable.

- Do not assume unlimited when sizing template columns, staging columns or the review grid.
- **Do not make import a path that bypasses the cap.** Import fills values for fields that already
  exist; it must never create a field, and it must not write JSON keys that have no `sett.Fields` row.
  An unknown key in a source file is ignored with a warning, never persisted.
- **Do not sort or filter the review grid on a custom-field column** via
  `GridQueryBuilderHelper.ApplyCustomFieldSortingToList` — it sorts after `ToListAsync()`, i.e. within
  the fetched page only. Custom columns in the review grid are display-only in this task.
- Cap the assembled JSON per row and fail the row with a clear error if a tenant's field set plus
  values exceeds it. State the limit you chose and why.

## K. Forward constraint: database segregation is planned

A future architecture separates a common platform/security database (tenant management, credentials,
login) from **one business database per tenant**. Do not build for it. Do make sure this task does not
obstruct it:

- The tenant-resolved field plan (§ B) must resolve custom-field definitions through a path that could
  become a different connection later. Do not introduce a SQL join between custom-field definitions and
  business rows that assumes they are permanently in the same database.
- The § D validation metadata snapshot is **required** rather than merely preferable under this plan:
  `import.validate_common` reads `import."ImportGridFields"` from **inside the function body**, and
  PostgreSQL cannot read a table in another database. A session-scoped snapshot co-located with the
  staging table keeps the validator working regardless of where configuration ends up living. Say in
  your report that you accounted for this.
- The Hangfire path already takes the tenant from `session.CompanyId` rather than ambient context
  (`ImportParseService.cs:122-125`). Under segregation the same value must also select the tenant's
  *connection*. Do not add any new background path that resolves tenant from ambient context — it will
  read the wrong database, not merely the wrong tenant.

## L. Frontend

- Review grid and session detail already render columns from the field plan — confirm custom columns
  flow through with no per-field frontend change, or state what was needed.
- `sanitizeCell` on every custom cell value **and** header.
- Template download is unchanged from the user's point of view; it just contains more columns.

---

## Output

Stage everything (`git add` in each affected repo). Report:

1. How the import grid ↔ setting grid link is established, the exact migration column the user must
   create, and the seed.
2. The new `GenerateFieldsAsync` signature and, per caller, where its tenant value comes from — calling
   out the Hangfire path specifically.
3. The staging column naming rule, the 63-byte/quoting/non-ASCII handling, and how a collision fails.
4. The validation-metadata approach you chose, why, what it means for the just-landed common validator,
   and how pre-feature sessions keep working unchanged.
5. The `DataTypeCode` → import data-type map, and any custom type with no equivalent.
6. The JSON key you write, and how you verified it matches what the form writes.
7. What you did with the raw `CustomFields` passthrough column.
8. Whether `ContactCustomFieldsDto` is the UI's read path, and what you changed so imported values are
   visible on the record.
9. Which grids are enabled and why the others are not.
10. Each of the nine negative scenarios in § I, with the actual behaviour.
11. How template caching was ruled out as a cross-tenant leak.
12. Exact migration(s) the user must create — columns, types, nullability — and seed scripts by filename
    and order.
13. Anything you could not complete and why.
