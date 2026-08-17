# Import remediation — P8 sweep (UI/UX MVP) + two P2/P4 carry-overs

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`
Plan of record: `prompts/import_gap_remediation_prompt.md` § P8
Prior phases complete: P0, P1, P2, P3, P4, P5, P6, P9, P10. P7 (async parse) is in flight in a parallel session.

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`.
- `PSS_2.0_Backend` and `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server. Seed SQL idempotent.
- Enterprise-level app. No shortcuts. Backend enforcement, never frontend-only.
- **No `window.confirm` / `window.alert` / `window.prompt`** anywhere. Dialog components only.
- Scheduled imports are staying. Do not refactor the schedule stack.

**P7 collision warning.** A parallel session is restructuring `UploadImportFile` into request + PARSE job and touching `import-wizard-container.tsx` (the poller) and the upload step. **Do not edit the upload step or the poller's status set.** If a P8 item needs a wizard-level change, make it in the step component, not the container. Read `prompts/import_p7_async_parse_prompt.md` before starting so you know what is moving.

Frontend surface: `PSS_2.0_Frontend/src/presentation/components/custom-components/import-wizard/`.
The bulk of the work is in `import-step-review-results.tsx` (~1249 lines) — read it fully first. It already holds the inline edit / accept / omit UI, the Decision column, the warnings filter, and the xlsx error export.

---

## Already verified DONE — do not rebuild

| # | Where |
|---|---|
| P8.1 polling fallback | `import-wizard-container.tsx:182-210` (slow poll) — **P7 is editing this file; leave it alone** |
| P8.2 downloadable error report | `import-step-review-results.tsx:300-400`, with P6.6 `sanitizeCell` applied to the header row too |
| P8.5 created / failed / skipped on completion | present on both success and failure paths |
| P8.8 confirmation dialog before execute | `AlertDialog`, not `window.confirm` |

---

## The work

### P8.6 — Quota context before commit  *(highest value; P2 just landed and this is its missing half)*

`Base.Application/Services/Import/ImportQuotaGuard.cs` exists and is correct. It exposes a check that resolves the meter from the grid's `EntityType` (`CONTACT → MeterCodes.Contacts`, `GLOBALDONATION`/`DONATION → MeterCodes.Donations`) and returns limit / used / whether it fits.

The problem: **there is no quota surface on the frontend at all.** A grep for `quota` across the whole `import-wizard/` directory returns zero matches. So today a user reviews 5,000 rows, clicks Import, and receives a 402 — after all the review work. The comment in `StartImport.cs` describes GATE A as "already warned on the review screen." That warning does not exist.

- Expose the quota check as a **query** the review screen can call — it must not be a side effect of a mutation. Read how the existing review-screen counts are fetched and follow that shape. `ImportQuotaGuard` already has the resolution logic; do not duplicate it, and **do not re-derive the meter code in the frontend** — the mapping is backend policy.
- Surface it on the review step **before** the Import button: rows to be imported vs remaining plan capacity. When it does not fit, state the actual numbers ("this file will import 5,000 contacts; your plan allows 240 more"), not a generic failure.
- Respect the semantics `QuotaBehavior` already documents: **`null` limit = unlimited** (show nothing, or "unlimited" — do not render `0`), and **`limit == 0` = not provisioned, fail-closed.** Getting these backwards means either a scary false warning on an unlimited plan or a silent pass on an unprovisioned one.
- Count **`ValidRows`**, matching GATE B in `StartImport.cs` — invalid rows are never written. If P8.4's decisions change the effective count, use the count that will actually be imported and say which you used.
- This is advisory. GATE B stays authoritative. **Do not let a frontend quota check gate the Import button as the only enforcement** — it informs, the backend refuses.
- Confirm `PlanQuotaExceededException` still renders as 402 / `PLAN_QUOTA_EXCEEDED` with `{ meterCode, limit, used }` through `CustomErrorFilter`, and that the wizard renders those fields rather than a raw error string.

### P8.4 — Bulk accept-all / omit-all for undecided rows

Rows with `RowDecision = NULL` are silently excluded from the import. The **wording** already exists (`import-step-review-results.tsx` ~`:618`, `:758`, `:1133`); the **bulk actions do not**. A user with 200 warning rows currently clicks 200 times.

- Add accept-all / omit-all over the **currently filtered** set, not the whole session — the warnings filter at `:530-543` is how a user narrows to what they are deciding on, and a bulk action that ignores the filter will silently decide rows the user never looked at. State the scope in the button label and in the confirmation.
- Confirm before applying (Dialog component), stating the row count and that it applies to the filtered set.
- **Backend-side bulk**, not a client loop of N mutations. Extend `SetStagingRowDecision` or add a sibling bulk command; either way one round trip, one transaction, and it must respect the same authorization the single-row command does. A 5,000-row loop from the browser is not an acceptable implementation.
- The bulk decision must be audited as one event with a count — not N rows in the audit log (see P4 carry-over below).
- `canProceed` (`:407-409`) and the undecided-count wording must both reflect the result without a full refetch if that is how the single-row path already behaves; match it.

### P8.3 — Pre-validation preview

**Not done.** The "Template Preview" at `import-step-configure-template.tsx:241-250` is a *field-list* preview (which columns the template expects) — not what P8.3 asks for, which is the **first 10 parsed rows plus the resolved column mapping**, shown before committing to a full validation pass.

- Show the first 10 rows as parsed, alongside how each file column resolved to a grid field — including **columns that resolved to nothing**, which is the whole point: a user finds a misaligned header here instead of after validating 50,000 rows.
- The data is already in `staging_{id}` after parse; page it, do not add a second parse.
- Apply P6.6 sanitization to displayed cell values and to column headers (headers are tenant-authored on `ImportGridFields`).
- **P7 dependency:** after P7, `Parsed` arrives asynchronously. Build this to read from the session's parsed state, and do not assume the preview data is available at the moment the upload call returns.

### P8.7 — Per-field help during review

Required / format / allowed values, available at the point of correction. `import-step-review-results.tsx` has no `helpText` or field-metadata surface today (the only `Tooltip` usage in the directory is in `import-session-list.tsx`, unrelated).

- Source from the existing grid-field metadata — required flags, data type, and for FK/lookup fields the allowed values. **Read what `ImportGridFields` already carries before adding any column**; if a field genuinely has nowhere to hold help text, report that as a finding rather than adding a column in this phase.
- Attach it to the column header and to the inline editor, so it is visible while a user is fixing a cell.

### P8.9 — Cancel-during-execution messaging

Cancel mid-execution leaves already-committed batches in the live tables. The UI does not say so. The only near-miss is `import-session-list.tsx:978` ("This action cannot be undone"), which is a different action.

- The cancel confirmation, **while a session is `Importing` (8)**, must state that rows already committed remain and will not be rolled back. Cancelling a `Scheduled` or `Queued` session has no such consequence — do not show the same warning there, it is misleading.
- After cancel, the session summary must show what was actually committed before the stop. P3.1 made execution resumable and per-row idempotent, so the count exists — surface it.

### P8.10 — Human-readable field-level errors  *(verify, then close)*

P6.5 landed the field-level error structure and P1.7 required that raw SP text never reach the screen. The review grid renders `Error Type` / `Error Details` from staging.

- Verify against **real** failing data (bad date, FK miss, missing required, duplicate) that what renders names the row and the column in the user's own terms and contains no SQL, no constraint name, no stack text.
- If any raw database text still leaks, fix it at the source (the message the SP/handler writes), **not** by regex-scrubbing in the frontend.
- If it is already clean, say so and change nothing.

---

## P2 / P4 carry-overs

### `UpdateStagingRow` is unaudited

P4 wired 7 commands. `Base.Application/Business/ImportBusiness/Sessions/Commands/UpdateStagingRow.cs` has **zero** matches for `ISelfAuditedRequest|IAuditLogWriter`.

Its sibling `SetStagingRowDecision` *was* audited — so the trail records "a staff member omitted this row" but not "a staff member changed this cell's value before it was written to live data." That is the higher-value event of the two.

- Wire it exactly as `SetStagingRowDecision` is wired: same `IAuditLogWriter` method, same correlation key (the import session id), same explicit tenant/actor resolution.
- **Record which field changed and that it changed — not the before/after values.** P4's rule stands: no row data, no PII in audit rows. A contact's phone number must not land in the audit log because someone corrected it during review.
- Apply the same to the P8.4 bulk decision command: one audit row carrying the count and the filter scope.

### Quota seed — confirmed unnecessary

`ImportQuotaGuard` reuses the existing `MeterCodes.Contacts` / `MeterCodes.Donations` meters, so no new `PlanQuota` rows are needed and `sql-scripts-dyanmic/import-plan-quota-seed.sql` should **not** be created. Stated here so it is not "discovered" as a gap and built anyway. If you find a tenant whose plan has no row for those meters at all, that is a **provisioning** finding to report — not a reason to seed from this session.

---

## Output

Stage everything (`git add` in each affected repo). Report:

1. Each P8 item: done / already-done / deliberately-not-done, with reasoning for the last.
2. For P8.6 — the query added, and how `null` vs `0` limit render.
3. For P8.4 — the bulk command shape and confirmation that it is one round trip, one transaction, one audit row.
4. For P8.7 — whether existing grid-field metadata was sufficient, or what is missing.
5. For P8.10 — what you tested against and whether any raw DB text still leaks.
6. Any file you avoided because P7 is editing it.
7. Any migration the user needs to create, by name. Any seed file to run.
8. Anything you could not complete and why.
