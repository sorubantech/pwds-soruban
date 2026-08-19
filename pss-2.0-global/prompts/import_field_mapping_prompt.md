# Import — Field-to-Field (Column) Mapping

**Status:** planned, not built
**Programme:** Import (follows P6/P7/P9/P10 remediation, which is complete)
**Reverses:** the "column mapping deferred, template-only upload stays" decision recorded in `SESSION_HANDOFF_import_programme.md`. That decision is now explicitly withdrawn by the user. Template-only upload remains the *happy path*; it stops being the *only* path.

---

## 0. What this feature is

Today the import pipeline matches the uploaded workbook's header row to the template's field plan by **exact text**. If the user renamed a column, reordered nothing but retyped a header, or exported from another system, that column is dropped with a warning and its data never reaches the database.

Field-to-field mapping lets the user say, once per upload: *"the column called `Mobile No` in my file is the template field `Phone1`."*

**Scope of this prompt:** capture, persist, validate and apply a per-session column map, plus the UI to build it. Not in scope: CSV support (see §11), transformation/expression mapping (`concat`, `split`, default values), or multi-sheet selection.

---

## 1. Audit findings — read these before designing anything

These were established by reading the code. Do not re-derive them; do verify them still hold if the codebase has moved.

### 1.1 The seam is exactly one method

`Base.Infrastructure/Services/Import/FileParserService.cs` → `OpenParsePlan(Stream, List<GeneratedFieldDto>)`, STEP 2. The current map is implicit:

```csharp
var headerText = cell?.Text?.Trim().Replace(" *", "").Trim();   // " *" = the required marker
for (int i = 0; i < fields.Count; i++)
    if (fields[i].DisplayName.Equals(headerText, StringComparison.OrdinalIgnoreCase) ||
        fields[i].FieldName .Equals(headerText, StringComparison.OrdinalIgnoreCase))
    { matchIndex = i; break; }
```

It produces `List<(int Column, int FieldIndex)> columnMapping`, which is then handed to `StreamRows`. **That tuple list is already the data structure this feature needs to make user-supplied.** Everything else in the file is unaffected.

Behaviours to preserve verbatim:
- header text is trimmed and has `" *"` stripped;
- when two columns map to the same field, **the later column wins** (today accidental, must become explicitly forbidden — see §6);
- the blank-row test scans *every* cell, not just mapped ones, so row numbers do not shift when a column is unmapped;
- `SourceRowNumber = rowIndex + 1` is the real spreadsheet position;
- `ParseCellValue` coerces per `field.DataType` and **passes uncoercible values through verbatim** so validation can report `INVALID_INTEGER` rather than silently nulling.

### 1.2 Mapping is a parse-time concern only — nothing downstream changes

`StagingTableService` names staging columns from the canonical template name:

```csharp
columns.AddRange(fields.Select(f => $"\"{f.FieldName}\""));
var copyCommand = $"COPY import.\"{tableName}\" ({columnsStr}) FROM STDIN (FORMAT BINARY)";
```

Therefore **`import.create_staging_table`, `import.snapshot_session_fields`, `ImportSessionFields`, every validation procedure and every execute procedure are untouched by this feature.** This is the single most important constraint: if a design change starts requiring PL/pgSQL edits, the design is wrong.

### 1.3 There is no pause point between upload and staging

`UploadImportFileHandler` (`Base.Application/Business/ImportBusiness/Sessions/Commands/UploadImportFile.cs`) does, in order: resolve grid → `ImportGridAuthorization.EnsureGridAccessAsync` → `MaxFileSizeBytes` check → `BuildImportFilePath` → `CreateImportSessionAsync` (session row first, so every stored file is owned) → upload blob → **`session.HangfireJobId = parseService.StartParseJob(sessionId);`** → return `{ ImportSessionId, TotalRows = 0, Status = Uploading }`.

`ImportParseService.ExecuteParseAsync` then guards `session.Status != Uploading → log and return`, calls `EstablishJobPrincipal` **from its own frame** (AsyncLocal flows forward only), and runs straight through parse → staging → `Parsed(3)`.

So the mapping step has to be created; it does not exist to be hooked into.

### 1.4 Status enum has exactly one free slot

Persisted as ints, values appended deliberately:

```
Initiated=0 Uploading=1 Parsing=2 Parsed=3 Validating=4 Validated=5 Scheduled=6
[7 UNUSED] Importing=8 Completed=9 Failed=10 Cancelled=11 ReValidating=12
ReValidated=13 ScheduleValidationFailed=14 ScheduleFailed=15 Queued=16
```

**`7` is free and is the correct slot** for the new state. Do not renumber anything.

### 1.5 Precedent for a per-session user choice as JSON

`ImportSession.ChildCountsJson` is `jsonb` (see `ImportSessionConfiguration` and the initial migration), holds the user's child-count selection, and is read back by `ImportSessionNarrative`. Follow this shape.

### 1.6 Frontend is already a 5-tab wizard

`import-wizard-container.tsx` → `WIZARD_TABS` is already five (`instructions`, `template-upload`, `validation`, `import-processing`, `result`) with named indices `TAB_INSTRUCTIONS…TAB_RESULT`. Tab gating drives off `ImportUIState` via `getTabFromUIState`; `mapStatusToUIState` (`src/domain/types/import-types/index.ts:1184`) maps numeric status → `ImportUIState`. Upload is REST (`import-api-service.ts` → `POST /api/import/upload`, multipart), everything else is GraphQL.

### 1.7 Cancellation and cleanup already cover the new state

`CancelImport` has **no status allow-list** — it cancels from any state, deletes the Hangfire job, sets `Cancelled(11)` and stamps `StagingRetainUntil`. An abandoned mapping session has *no staging table* (nothing was created yet), so the only residue is the blob, which `DropExpiredStagingTablesJob`'s stored-file sweep already reclaims. **No new sweeper is required** — but confirm the stored-file sweep does not assume a terminal status before relying on this.

### 1.8 Mutation surface today (no mapping mutation exists)

`GenerateImportTemplate`, `StartImportValidation`, `StartImportExecution`, `CancelImport`, `ReorderImportQueue`, `UpdateImportStagingRow`, `SetImportStagingRowDecision`, `SetImportStagingRowDecisionsBulk`, `ScheduleImport`, `UpdateImportScheduleJob`. All return `BaseApiResponse<T>`.

---

## 2. Design decision — one answer, with the reasoning

**Split the parse job in two, and stop only when the automatic match is imperfect.**

```
upload → Uploading(1)
      → [job 1: INSPECT]  read header + 5 sample rows, run the auto-match
           ├─ perfect match  → continue straight into staging in the same job → Parsed(3)
           └─ imperfect      → AwaitingMapping(7), job ends
      → user maps columns in the wizard
      → confirmColumnMapping mutation → validates the map → [job 2: STAGE] → Parsed(3)
```

**Why not "always stop and confirm":** the overwhelming majority of uploads use the generated template, whose headers match by construction. Forcing a confirmation click on every one of those adds friction to the path that already works and buys nothing. A per-grid escape hatch (`RequireMappingConfirmation`, default `false`) exists for tenants who want the checkpoint regardless.

**Why not "map before enqueue, inside the upload call":** the upload endpoint is rate-limited to 5/hour/tenant and already does blob I/O synchronously. Parsing a header inside it to render a mapping UI, then having the client come back to the same request, is not expressible; and doing it client-side would put a load-bearing rule (which columns exist) in the browser, which §6 forbids.

**Why not "remap after staging":** staging columns are named by `FieldName` (§1.2). Remapping post-staging means re-COPYing the whole table. Mapping before staging keeps the feature confined to one method and zero PL/pgSQL.

**"Imperfect" is defined as:** any header cell that matched no field, **or** any `IsRequired` field that no column matched. A file with unmatched *optional* template fields but no unknown columns is still "perfect" (that is the normal partial-template case and already works).

---

## 3. Data model changes

Two nullable columns on `import."ImportSessions"` and one flag on `import."ImportGridDefinitions"`.

| Table | Column | Type | Notes |
|---|---|---|---|
| `ImportSessions` | `ColumnMappingJson` | `jsonb` NULL | The **resolved** map, written on every session — auto-matched or user-confirmed. Auditable, and the source for the "Mapping" sheet in the result workbook. |
| `ImportSessions` | `HeaderInspectionJson` | `jsonb` NULL | Header cells + up to 5 sample data rows + the auto-match proposal, captured by job 1. Lets the mapping UI render without a second blob read, and lets support see what the file actually looked like. |
| `ImportGridDefinitions` | `RequireMappingConfirmation` | `boolean NOT NULL DEFAULT false` | Forces the checkpoint even on a perfect match. |

`ColumnMappingJson` shape — **column index → FieldName**, plus provenance:

```json
{
  "version": 1,
  "source": "auto",                       // auto | user | profile
  "headerRowIndex": 0,
  "map": [
    { "columnIndex": 0, "columnHeader": "First Name", "fieldName": "FirstName", "confidence": "exact" },
    { "columnIndex": 4, "columnHeader": "Mobile No",  "fieldName": "Phone1",    "confidence": "user"  }
  ],
  "ignoredColumns": [ { "columnIndex": 7, "columnHeader": "Internal Ref" } ],
  "unmappedFields": [ "MiddleName" ]
}
```

Key by **`fieldName`, never by field index.** The field plan is regenerated per company (custom fields append last) — an index is not stable across a config change, a name is.

**Migration handoff:** the user creates EF migrations. Deliver (a) the `migrationBuilder.Sql(...)` bodies as markdown in the build report, and (b) an idempotent script `sql-scripts-dyanmic/import-column-mapping-schema.sql` using `ADD COLUMN IF NOT EXISTS`. Do not run `ef migrations add`; do not touch `ApplicationDbContextModelSnapshot.cs`; do not execute SQL.

---

## 4. Backend work

### 4.1 `FileParserService` — split the method

```csharp
// NEW — cheap, header + N sample rows, no staging, no field plan needed for the read itself
public HeaderInspection InspectHeader(Stream fileStream, int sampleRowCount = 5);

// NEW — the auto-match, extracted from OpenParsePlan STEP 2 so both paths share one rule
public static ColumnMappingProposal ProposeMapping(HeaderInspection header, IReadOnlyList<GeneratedFieldDto> fields);

// CHANGED — takes an explicit map instead of deriving one
public ExcelParsePlan OpenParsePlan(Stream fileStream, List<GeneratedFieldDto> fields, ColumnMapping mapping);
```

- `InspectHeader` runs the STEP 0 archive-bomb guard (512 MB uncompressed, 200× ratio, 2000 entries) and the magic-byte format detection (`50 4B 03 04` → `XlsxSheetReader`, `D0 CF 11 E0` → NPOI `XlsWorkbookRowSource`) **exactly as `OpenParsePlan` does today**. Extract those into a shared private opener rather than duplicating them — two copies of a security guard is how one of them gets fixed and the other does not.
- `ProposeMapping` keeps the existing rule (case-insensitive on `DisplayName` **or** `FieldName`, after `.Trim().Replace(" *","").Trim()`) as `confidence: "exact"`. You may add a normalised fallback (strip non-alphanumerics, collapse whitespace, so `Mobile No.` → `mobileno`) as `confidence: "fuzzy"` — **a fuzzy match must never auto-apply**; it seeds the picker as a suggestion and marks the session imperfect.
- `OpenParsePlan` now consumes `mapping.Map` directly. It keeps producing the same `plan.Errors` warnings for ignored columns and unmapped required fields, so `ParseWarningsJson` and the result workbook keep working unchanged.
- Cost note to accept and document: job 1 and job 2 each read the blob once. Header-only inspection is cheap next to a full parse; two reads is the price of the pause point.

### 4.2 `ImportParseService` — two jobs

- `ExecuteInspectAsync(sessionId, ct)` — replaces the current entry point on the `Uploading(1)` guard. Calls `EstablishJobPrincipal` **from its own frame**. Generates the field plan, inspects the header, proposes the map, persists `HeaderInspectionJson` + the proposal into `ColumnMappingJson` (`source: "auto"`).
  - Perfect match **and** `RequireMappingConfirmation == false` → fall straight through into the staging path in the same job. No extra round trip, no behaviour change for template uploads.
  - Otherwise → `Status = AwaitingMapping(7)`, save, return.
- `ExecuteStageAsync(sessionId, ct)` — guards `Status is Uploading(1) or AwaitingMapping(7)`; sets `Parsing(2)`; opens the parse plan with the stored map; `CreateStagingTableAsync` → `StreamStagingDataAsync` with `EnforceRowLimit(plan.Rows, grid.MaxRowCount, grid.DisplayName)`; sets `StagingTableName`, `TotalRows`, `Parsed(3)`; appends every `plan.Errors` entry via `ImportAuditHelper.AppendParseWarning`. Keep the existing `rowsWritten == 0 && plan.Errors.Count > 0 → ImportParseFailedException` rule.
- Both keep `[AutomaticRetry(Attempts = 0)]`, `[Queue(ImportQueueOptions.QueueName)]`, the `ImportQueueOptions.ParseCommandTimeout` linked CTS, and one-shot `_backgroundJobClient.Enqueue` (parse writes only to its own staging table, so it is deliberately **not** routed through `ImportQueueDispatcher`).
- `session.HangfireJobId` must be overwritten with job 2's id on confirm, so `CancelImport`'s `BackgroundJob.Delete` still targets the live job.

### 4.3 New GraphQL surface

```
query   importSessionColumnMapping(importSessionId: Int!): BaseApiResponse<ImportColumnMappingDto>
mutation confirmImportColumnMapping(request: { importSessionId: Int!, map: [ColumnMapEntryInput!]!, ignoreUnmappedRequired: Boolean }): BaseApiResponse<Int>
```

- HotChocolate strips the `Get` prefix and the C# parameter name becomes the GraphQL argument name — mirror a sibling in `ImportMutations.cs` exactly rather than inventing a signature. If `[AsParameters]` is used, it exposes **one** argument named after the parameter, so the fields must be wrapped in `request: { … }`.
- `BaseApiResponse<int>` exposes `data: Int!` and the frontend selects bare `data`.
- The query returns: the header cells, the sample rows, the current proposal, and the **full assignable field list** (`FieldName`, `DisplayName`, `DataType`, `IsRequired`, `IsCustomField`, `ChildEntityType`, `ChildSequence`, `DisplayOrder`) so the picker can group parent / child / custom exactly as `DynamicFieldGeneratorService` orders them (parents 0, children 1, custom last — custom sorts last deliberately so adding one never shifts a standard column).
- Both carry `[CustomAuthorize]` matching `UploadImportFileCommand`'s modules/permission **and** call `ImportGridAuthorization.EnsureSessionGridAccessAsync` — the coarse floor plus the per-grid `(RequiredMenuCode, RequiredCapabilityCode)` re-check, same as every other import handler.

---

## 5. Reusable mapping profiles — phase B, not phase A

Ship §1–§4 first. Then add `import."ImportColumnMappingProfiles"`:

`ImportColumnMappingProfileId, CompanyId, ImportGridDefinitionId, Name, HeaderSignature, MappingJson (jsonb), IsDefault, IsDeleted, Created/Modified` — unique on `(CompanyId, ImportGridDefinitionId, Name) WHERE NOT IsDeleted`.

`HeaderSignature` = a stable hash of the normalised, order-preserved header row. On inspect, if a non-deleted profile for this company+grid matches the signature, apply it (`source: "profile"`) and treat the session as perfect — a recurring monthly export from the same upstream system then imports with zero clicks. On confirm, offer "save this mapping as…".

Do not build phase B until phase A is in use. Deliver the phase-B schema as a separate idempotent script.

---

## 6. Validation — backend, not the browser

`ConfirmImportColumnMappingHandler` must refuse, with a specific message per failure:

1. **Session not found for the caller's company** → `NotFoundException` (another tenant's session reads as NotFound, never Forbidden — match `CancelImport`).
2. **Status is not `AwaitingMapping(7)`** → `BadRequestException`. This is also the double-confirm guard: two clicks must not enqueue two staging jobs. Do the status flip and the enqueue under one `SaveChangesAsync`, and enqueue **after** the save succeeds.
3. **Unknown target** — a `fieldName` that is not in the field plan regenerated *now* for this session's grid + company → refuse.
4. **Duplicate target** — two columns mapped to the same `fieldName` → refuse. (Today's "later column wins" is silent data loss and must not survive into an explicit map.)
5. **Column index out of range** of the stored `HeaderInspectionJson` → refuse.
6. **Required field unmapped** → refuse by default. Every row would fail validation anyway, so letting it through wastes a staging table and a validation pass. `ignoreUnmappedRequired: true` allows deliberate override (a conditional field whose requirement the grid resolves at validation time); log it.
7. **Field plan drift** — compare `ImportGridDefinition.LastConfigChangedAt` and the custom-field set against what was captured at inspect time. If either moved, refuse and tell the user to re-map. A map confirmed against a stale plan can point at a column that no longer exists.

Non-blocking, surfaced as warnings in the UI and appended to `ParseWarningsJson`:

- **Sample-value type mismatch** — run each mapped column's stored sample values through `ParseCellValue` for the target `DataType` and report e.g. *"3 of 5 sample values in `Joined On` are not a valid DATE for format `dd/MM/yyyy`."* This is the single highest-value affordance in the whole feature: it catches the wrong-column mistake before 4,000 rows are staged. It must not block — `ParseCellValue` deliberately passes bad values through so validation can name them properly.
- **Ignored column** — *"`Internal Ref` will not be imported."*
- **Unmapped optional field** — *"`Middle Name` will be empty for every row."*

Reuse `ImportCustomFieldNaming.AssertNoCollisions` semantics rather than re-implementing collision logic for `CF_{fieldKey}_{fieldId}` names.

---

## 7. Frontend

**No sixth tab.** Mapping is part of getting the file in, so it renders inside `TAB_TEMPLATE_UPLOAD`.

- `src/domain/types/import-types/index.ts`: add `ImportSessionStatus.AwaitingMapping = 7` and `ImportUIState.MAPPING`; extend `mapStatusToUIState` (`case AwaitingMapping: return MAPPING`) and `getTabFromUIState` (`MAPPING → TAB_TEMPLATE_UPLOAD`). Add `MAPPING` to `isPreSessionState`? **No** — a session exists by then; leave it out so the wizard's "you have work in flight" affordances behave correctly.
- New `import-step-column-mapping.tsx` beside the existing `import-step-*.tsx` files, rendered by `import-wizard-container.tsx` when `uiState === ImportUIState.MAPPING`.
- Layout: one row per **file column** (source-first — the user is looking at their own file, not at our template), showing the header text, the sample values, and a target `FormSelect` listing the assignable fields grouped Parent / Child / Custom with required fields marked. A "Do not import" option, not a blank. Below the table, a live panel: unmapped required fields, duplicate targets, sample-type warnings. Confirm is disabled while a blocking condition stands, with the reason shown — never a bare disabled button.
- Use the canonical app-wide form-field components (`FormSelect` etc.), not per-screen forks. Reuse the pipeline rail: `import-pipeline-rail-state.ts` gets a "Map columns" step that appears only when the session actually stopped for mapping.
- **No `window.confirm`/`alert`/`prompt` anywhere.** The `ignoreUnmappedRequired` override is a Dialog component.
- **Do not touch SignalR.** `use-import-signalr.ts` subscribes only to `VALIDATION_*` and `IMPORT_*` events — there are no parse-phase events at all, and the wizard already picks up `Parsed(3)` through its poller (`import-store.ts`, see the comment at ~line 372). `AwaitingMapping(7)` arrives the same way. Adding a hub event for the mapping stop is out of scope; if the poll latency proves annoying in UAT, raise it as a separate change.
- Apollo: cast `(data as any)?.result?.data`; declare list variables with nullability matching the backend (`string[]?` ⇒ `[String!]`); strip `__typename` recursively before sending the map back.
- Add the new query/mutation to `src/infrastructure/gql-queries/import-queries/` and `gql-mutations/import-mutations/` and re-export from the barrel `index.ts` — do not co-locate an inline query in the component.

---

## 8. What must NOT change

- `import.create_staging_table`, `import.snapshot_session_fields`, `import.process_import_upload`, every validation and execute procedure. Zero PL/pgSQL edits (§1.2).
- `ImportSessionFields` and `import.session_fields(session_id)`.
- `FileParserService.SourceRowKey = "__sourceRow"` — still read by `import.process_import_upload` as `row_data->>'__sourceRow'`.
- The quota gates (A advisory / B `EnsureAllowedAsync` hard refuse / C re-check at scheduled re-validation / D `EnsureCapacityAsync` under `pg_advisory_xact_lock`). They sit at validation and execution; mapping is upstream of all four. `used + ValidRows <= limit` stays honest because import remains insert-only.
- `GenerateImportTemplate` and the generated template itself. Mapping is for files that did *not* come from the template.
- The 5 uploads/hour/tenant rate limit and the 50 MB controller ceiling.
- Existing status integers.

---

## 9. Test plan

1. Template-download → upload unchanged: perfect match, **no mapping step appears**, `Parsed(3)` reached in one job, `ColumnMappingJson.source == "auto"`.
2. One header renamed → session stops at `AwaitingMapping(7)`, wizard lands on Template & Upload showing the mapping step with that column unmatched.
3. Confirm a valid map → staging table columns are still `FieldName`s; row data lands in the right columns; `TotalRows` matches.
4. Duplicate target → refused with the message naming both columns.
5. Required field unmapped → refused; with `ignoreUnmappedRequired` → accepted and every row fails validation as expected.
6. Confirm twice quickly → second call refused; exactly one staging table exists.
7. Cancel from `AwaitingMapping(7)` → `Cancelled(11)`, no staging table, blob reclaimed by the stored-file sweep.
8. Grid config changed between inspect and confirm → refused with the drift message.
9. Custom-field grid (`CustomFieldGridCode` non-null): `CF_{fieldKey}_{fieldId}` fields are assignable, sort last, and land in the entity's `CustomFields` jsonb under `CustomFieldKey`.
10. Child-expanded fields: `Email1`, `Email1_Type`, `Email2` … are individually assignable and honour `ChildCountsJson`.
11. `.xls` (OLE2 / NPOI) as well as `.xlsx` — inspection uses the same magic-byte detection, not the extension.
12. Archive bomb → rejected at inspect, before any session state advances past `Uploading`.
13. Tenant isolation: session id from another company → NotFound on both the query and the mutation.
14. Row-count and file-size limits still enforced in job 2.

---

## 10. Delivery order

1. Domain + EF config + idempotent SQL script; hand the migration bodies to the user.
2. `FileParserService` split (`InspectHeader` / `ProposeMapping` / `OpenParsePlan(mapping)`) with the shared opener + guards extracted.
3. `ImportParseService` split into inspect and stage jobs; status `7`.
4. Query + confirm mutation with the §6 rules.
5. Frontend types, state mapping, mapping step, rail, SignalR.
6. Phase B profiles (§5) — separate change set.

Each step must compile on its own. **The user builds the backend — do not run `dotnet build`.**

---

## 11. Relationship to deferred CSV support

CSV was deferred with `WorkbookRowSource` recorded as the seam. Mapping is the feature that makes CSV genuinely usable: a CSV has no generated template to download, so exact header matching would fail almost every time. Build mapping first; a `CsvRowSource` behind the same `WorkbookRowSource` interface then inherits inspect, propose, map and stage for free. Do not start CSV inside this change set.

---

## 12. Standing rules for whoever executes this

- Enterprise application. No shortcuts. Optimise for correctness, maintainability, scalability, UX and production readiness — not implementation simplicity. Target is DEV/UAT, MVP-1 realtime.
- Critical validation lives at the backend/service layer, never only in the frontend.
- **Never `git commit`.** Stage only (`git add`) and report; the user commits. No push, amend, tag or force. No `Co-Authored-By` or "Generated with Claude Code" trailer anywhere.
- The user builds the backend and creates EF migrations. Never run `dotnet build` or `ef migrations add`; never edit `ApplicationDbContextModelSnapshot.cs`.
- Never execute SQL against any database. Write idempotent scripts under `sql-scripts-dyanmic/`; the user runs them.
- No `auth.Modules` / menu / capability data changes — hand off seed scripts. (This feature adds no new screen, so no `seed_{entity}_menu.sql` is needed.)
- `BaseUrlConfig.ts` is user-managed — never edit, stage or revert it.
- Never print, echo or paste a secret value — key *names* only.
- Repo hazards: `PSS_2.0_Backend/.../Base` and `PSS_2.0_Frontend` are **nested git repos** — `cd` into each to see their status. Repo-wide `grep -rn`/`find` times out at 120 s; scope every search. The Grep tool with no `path` silently misses nested-repo files. Bash heredocs fail on long markdown — use the Write tool. Watch for sibling-worktree drift into `pwds-soruban/` without the `- Copy` suffix; verify with `git status`.
