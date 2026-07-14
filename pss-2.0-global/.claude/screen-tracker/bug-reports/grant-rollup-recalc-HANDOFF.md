# Grant Rollup Recalc — Session Handoff (ISSUE-6 + ISSUE-11)

**Screen:** Grant FLOW · Registry **#62** · schema `grant` · `screen_type: FLOW` · `status: COMPLETED`
**Task name:** `fix(grant): refresh cached Grant rollup columns on every report state change`
**Repos:** BE = `PSS_2.0_Backend` (separate git repo) · docs = outer `pss-2.0-global` repo

---

## ✅ COMPLETED (code written + build clean, 0 errors)

**Deliverable:** two cached rollup columns on `Grant` were never refreshed when a
report changed state. Fixed with ONE shared helper invoked from every mutating handler.
No schema change — both columns already exist.

- `Grant.ComplianceRate` (int?)  ← ISSUE-6
- `Grant.NextReportDueDate` (DateTime?) ← ISSUE-11

**New file (core deliverable):**
- `Base.Application/Business/GrantBusiness/GrantReports/GrantRollupRecalculator.cs`
  - `static Task RecomputeAsync(IApplicationDbContext dbContext, int grantId, CancellationToken ct)`
  - `NextReportDueDate` = earliest DueDate of non-deleted, non-Accepted reports
  - `ComplianceRate` = round(acceptedReports / dueReports * 100), null when dueReports == 0
  - Formula mirrors on-read source `GetGrantDocument.BuildComplianceAsync`

**Wired into all 7 mutating handlers** (`GrantReports/`):
| Handler | RecomputeAsync placement |
|---|---|
| CreateGrantReport.cs | after `strategy.ExecuteAsync` closes, inside outer try (line ~136) |
| UpdateGrantReport.cs | inside try after SaveChanges (line ~109) — DueDate is editable |
| DeleteGrantReport.cs | inside try after SaveChanges (line ~41) — soft-delete drops from set |
| SubmitToFunderGrantReport.cs | after SaveChanges try/catch (line ~84), before email |
| RequestRevisionGrantReport.cs | after SaveChanges try/catch (line ~56), before email |
| AcceptGrantReport.cs | after SaveChanges try/catch (~line 48–50), before email |
| ReopenGrantReport.cs | inside try between SaveChanges and return (~line 41–43) |

**Intentionally excluded:** `ToggleGrantReport.cs` — only flips `IsActive`, which no rollup predicate reads.

**Docs:** `.claude/screen-tracker/prompts/grant.md` — Session 20 entry appended; ISSUE-6 & ISSUE-11 marked CLOSED; § Sessions pruned to 5. REGISTRY row #62 stays `COMPLETED` (no change).

---

## ⏳ PENDING — START HERE next session

1. **Commit the BE changes** (NOT yet committed — awaiting explicit "commit" confirmation).
   - 8 grant files already staged in `PSS_2.0_Backend` repo.
   - ⚠️ A stray `DonationBusiness/CrowdFunds/Commands/InitiateCrowdFundDonation.cs` was pre-staged by ANOTHER session. Decide whether to exclude it (a plain `git commit` would sweep it in — use `git reset HEAD <file>` first, or commit only the 8 grant files explicitly).
   - Commit message (subject = task name above):
     ```
     fix(grant): refresh cached Grant rollup columns on every report state change

     Add GrantRollupRecalculator.RecomputeAsync helper and invoke it from all
     seven mutating grant-report handlers (Create, Update, Delete, SubmitToFunder,
     RequestRevision, Accept, Reopen) so Grant.ComplianceRate (ISSUE-6) and
     Grant.NextReportDueDate (ISSUE-11) stay in sync with the live report set.

     Toggle is intentionally excluded — it only flips IsActive, which no rollup
     predicate reads. No schema change; both columns already exist. Build clean.

     Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
     ```

2. **Commit the docs change separately** — `grant.md` lives in the OUTER `pss-2.0-global` repo, a different repo/commit from the BE `.cs` files.

3. **Verify at runtime** (optional, if not already): create/submit/accept/delete a report and confirm `Grant.ComplianceRate` and `Grant.NextReportDueDate` update on the grant.

---

## Guardrails (still in force)
- Do NOT commit without explicit user confirmation.
- Migrations strictly user-owned (never `dotnet ef migrations add`/`database update`/`remove`).
- NEVER `Read` the whole REGISTRY.md — `grep` only; status updates via scripted `sed -i`.
- Path quirk: Glob display omits `PSS_2.0_Backend`, but Read/Edit MUST include the full `PSS_2.0_Backend\...` prefix.
- Do NOT delegate this to a subagent (backend-developer delegation thrashed last time) — surgical main-session edits only.
