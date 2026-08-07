# HANDOFF — Next Session Prompt

> Paste everything below the line into the next session as the opening message.
> Written 2026-07-15. Author: continuation of the PSS 2.0 estimation work.

---

## ROLE
Act as a **senior project manager + software delivery lead with 20+ years' experience**, producing a
**client-submittable actuals report**. Output must be defensible to a paying client: grounded in real
git data, no invented numbers, every assumption stated.

## PROJECT CONTEXT
- **Product:** PSS 2.0 — multi-tenant NGO SaaS. Backend = .NET 8 (CQRS + GraphQL/HotChocolate, EF Core,
  tenant-scoped by CompanyId). Frontend = Next.js / React / TypeScript. ~137 screens / ~18 modules.
- **Working dir:** `D:\Repos\PWDS\pwds-soruban\pss-2.0-global`
- **Two nested git repos** (each has its own `.git`; both on Azure DevOps):
  - `PSS_2.0_Backend`  → 1,150 commits · history 2025-08-21 → 2026-07-14
  - `PSS_2.0_Frontend` → 1,329 commits · history 2025-08-22 → 2026-07-14
- **Team (author identities as they appear in git — NEEDS ALIASING):**
  | Name | Email | BE commits | FE commits |
  |---|---|---|---|
  | Karthick (git: "Karhick") | karthick004soruban@gmail.com | 788 | 767 |
  | Kavinkumar Thirumalaisamy | kavin1001@soruban.com | 160 | 259 |
  | Saranya C | saranya@soruban.com | 167 | 217 |
  | Shyam Prakash J | shyamprakash@soruban.com | 23 | 37 |
  | ganesh | ganesh@soruban.com | 6 | 31 |
  | PW Data Solutions | support@pwdsweb.com | 5 | 11 |
  | Divya S | divya@wisright.com | 1 | 6 |
  | Divya (DUPLICATE) | divya@wisright.com | — | 1 |
  - ⚠️ **Divya has two identities** on the same email → must be merged with a `.mailmap` or a name→canonical map.
  - Watch for any other name/email drift before aggregating.

## WHAT IS ALREADY DONE (do NOT redo)
1. **Forward estimation deliverable — COMPLETE & SAVED:**
   `D:\Repos\PWDS\pwds-soruban\pss-2.0-global\PSS-2.0-DEVELOPMENT-ESTIMATION.xlsx`
   - 6 module tabs + Summary. Generator script (openpyxl):
     `C:\Users\USER\AppData\Local\Temp\claude\d--Repos-PWDS-pwds-soruban-pss-2-0-global\e3c1c66d-6f12-4497-884b-5a65cd9c3a6e\scratchpad\build_dev_estimation.py`
   - Totals: **146 items · 2,332 h ≈ 389 person-days · +15% buffer → 447 planned person-days.**
   - Sheets: 1 Business Modules (34/55.5d, scaled −40%) · 2 Volunteer & Membership (8/25d) ·
     3 AI Features (13/50d) · 4 System, Roles & Platform (44/119.5d) ·
     5 Client Onboarding/Comms/Leads (10/31.5d) · 6 Engineering & Platform Foundations (37/107d, incl. Azure Front Door).
2. **Production-readiness estimation — SEPARATE & FROZEN. DO NOT TOUCH:**
   - `PRODUCTION-READINESS-BACKLOG.md` (335 findings) — user constraint: *"keep your findings, don't change them."*
   - `SCREEN-STATUS-OVERVIEW-DEV.xlsx` built by `build_estimation.py` — leave as-is.
- **File-lock caveat:** these `.xlsx` files fail to save with `PermissionError [Errno 13]` while open in Excel.
  Ask the user to close the file before any regenerate.

---

## THE TASK FOR THIS SESSION — "COMPLETED HOURS" ACTUALS TRACKER
Build a **completed-effort / actual-hours report from real git history** across **both** repos, tracking
**each individual team member's contribution and estimated hours**. Everything below must be covered.

### 1. Data extraction (both repos, full history)
- Per-commit fields: repo, commit hash, author (canonicalized), date/time, message, files changed,
  insertions, deletions, and derived **module/area** (map file paths → module: Contacts, Donations, Grants,
  Case, Communication, Volunteer, Membership, Events, Finance, Reporting, System/Platform, AI, etc.).
- Apply `.mailmap`/alias map first so Divya (and any other split identity) collapses to one person.
- Consider excluding merge commits and vendored/generated files (lockfiles, `node_modules`, migrations
  snapshots, build output) from churn — but REPORT what was excluded; no silent filtering.

### 2. Hours modelling (state the method openly — this is an ESTIMATE from commits, not a timesheet)
- Choose and document a defensible model. Recommended: **active-day / commit-session** approach —
  cluster each author's commits per day into working sessions (e.g. gap > 90 min starts a new session),
  cap a day at a sane max (e.g. 8–10 h), so an "active engineering day" ≈ real focused hours, rather than
  naïvely multiplying commit counts. Cross-check against a simpler "active days × hours/day" sanity number.
- Make the key parameters top-of-file constants (session gap, max hours/day, hours/day) so the client
  can see and tune them.
- Explicitly label the output **"git-derived effort estimate"** — never present as verified payroll hours.

### 3. Reporting / deliverable
- Build an **Excel workbook** (openpyxl, same visual style as `build_dev_estimation.py` — navy titles,
  blue headers, banded rows, freeze panes, autofilter, no gridlines) named e.g.
  `PSS-2.0-COMPLETED-HOURS-ACTUALS.xlsx`. Suggested tabs:
  1. **Summary** — per-member totals (commits, active days, est. hours, % of effort), grand totals,
     BE vs FE split, project date span.
  2. **By Member** — each member's monthly breakdown + module breakdown.
  3. **By Module** — hours/commits per module across both repos.
  4. **By Month** (timeline) — effort per month per member (burn-up view).
  5. **Commit Detail** (optional raw backing data, filterable) — so the client can audit any number.
- Also print a concise chat summary of headline numbers.

### 4. Quality / integrity rules
- **No fabricated numbers.** Every figure must trace to a git command output.
- Show the extraction commands used, and the alias map, in a "Method & Assumptions" tab or section.
- Flag data-quality issues (identity drift, giant squash/import commits that skew churn, gaps in history).
- Keep the two forward-estimation files untouched; this is a NEW, independent workbook.

### 5. Suggested first commands (verify before trusting)
```bash
# canonical extraction per repo (run for PSS_2.0_Backend and PSS_2.0_Frontend)
git -C <repo> log --no-merges --pretty=format:'%H|%an|%ae|%ad' --date=iso --numstat
git -C <repo> shortlog -sne --all           # author list for the alias map
git -C <repo> log --pretty=format:'%ad' --date=short | sort | uniq -c   # activity by day
```
Prefer a Python script (openpyxl already proven in this project) that shells out to `git log --numstat`,
parses it, applies the alias map + module mapping, models hours, and writes the workbook.

### FIRST STEP WHEN YOU RESUME
Confirm the hours model + parameters with the user (session-gap, max h/day, whether to exclude churn from
generated files), then extract → model → build the workbook. Ask only if a modelling choice materially
changes the client-facing number; otherwise pick the documented default and proceed.
