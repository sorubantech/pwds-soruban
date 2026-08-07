# Grant Management — Development Tracker

> **Purpose.** Single index of every open development item across the Grant ecosystem
> (registry **#62 Grant**, **#63 Grant Report**, **#177 Program Fund Allocation**, and the
> layered §⑭ projects). Each item is a **self-contained prompt you run in its OWN session**
> so no single session carries the whole ~1200-line `grant.md` + backend. This file is the
> map; the per-item prompts below are the territory.
>
> **Token discipline (applies to EVERY prompt here).**
> - **NEVER** `Read` the whole `REGISTRY.md` (~700 KB) — `grep` the one row you need.
> - **NEVER** `Read` `grant.md` / `grantreport.md` end-to-end — `sed -n`/`grep` only the
>   sections/line-ranges the prompt names.
> - Load **only** the files listed under "Load" in each item. Do not open adjacent code
>   "for context." If a file isn't named, you don't need it.
> - BE repo path prefix is `PSS_2.0_Backend\...` even though Glob hides it.
> - Do **not** commit/push without explicit user say-so. Migrations are user-owned.

**Last reconciled:** 2026-07-14 · **Maintainer note:** update the Status column here whenever
an item's session lands; the authoritative per-screen state still lives in each prompt's §⑬.

---

## Backlog — priority order (flow-wise)

| # | Item | Screen | Kind | Buildable now? | Blocker | Status |
|---|------|--------|------|----------------|---------|--------|
| **D1** | Wire Grant Reports/Expense UI to live #63 BE | #62 | FIX (FE-mostly) | — | — | ✅ **DONE (ISSUE-1 CLOSED, session 21 — no code change; wiring landed with #63 working set)** |
| **D2** | Rich-text editor on 5 narrative fields (ISSUE-3) | #62 | ENHANCE (reuse) | ✅ YES | — | ✅ **DONE (in-session, session 22) — reused existing `RhfRichText`, no new dependency** |
| **D3** | Apply pending EF migrations + seeds (grant module) | #62/#63/§⑭ | USER-OWNED | n/a | user must run `dotnet ef` + apply seed | READY ▶ checklist below |
| **D4** | `pnpm install` DOMPurify (grantreport ISSUE-8) | #63 | USER-OWNED | n/a | user must run `pnpm add` | READY ▶ checklist below |
| **D5** | Blob file-upload (flip dormant path live) | #62/#63 | FIX | ❌ NO | external — needs provisioned PRIVATE storage container | BLOCKED (infra) |
| **D6** | Sponsor allocation-from-source screen | §⑭ | PLAN | ❌ NO | design-deferred; new screen scope | DEFERRED ▶ needs `/plan-screens` |

**Legend.** *Buildable now* = no external infra, no new npm/nuget dependency, no schema change,
fits `/continue-screen` guardrails. D3/D4 are user tasks (I can't run migrations or installs).
D5/D6 are genuinely blocked — do not fabricate work on them.

---

## D1 ▶ DONE — Wire Grant #62 UI to the live #63 GrantReport backend

**Outcome (2026-07-14).** Closed with **no code change**. The SERVICE_PLACEHOLDER wiring for
grant.md **ISSUE-1** had already landed with the (uncommitted) #63-completion working set, so
by the time a session opened for it the fallbacks were already gone. grant.md session 21 marks
ISSUE-1 **CLOSED** and closes grantreport.md ISSUE-5. **Do not re-dispatch** — a fresh session
here does nothing but re-verify (wastes tokens).

---

## D2 ▶ DONE (in-session) — Rich-text editor on Grant narrative fields (ISSUE-3)

**The earlier "DEFERRED / needs new renderer" verdict was WRONG on two facts and is now corrected:**
- **`RhfRichText` DOES exist** — `grant/grantreporting/form-widgets/rhf-rich-text.tsx` (an RHF-bound
  wrapper around `MinimalTiptapEditor`, `output="html"`). It was already used 3× in the #63 grant
  report form. The prior "no `RHFRichText` symbol" was a casing/lookup error.
- **`isomorphic-dompurify` IS installed** — imported and used in
  `grant/grantreporting/utils/sanitize.ts` (`sanitizeHtml`). No `pnpm add` was needed.

Grant #62's narrative fields render via a **hand-written RHF form** (`grant-form.tsx`), NOT the
config-schema FLOW pipeline — so this was a plain component swap, fully inside `/continue-screen`
scope. **No new component, no new dependency, no Spec change.**

**What landed (this session):**
- `grant-form.tsx` Section 3 "Proposal Narrative" — the 5 `<FormTextarea>` (executiveSummary,
  problemStatement, proposedSolution, expectedOutcomes, sustainabilityPlan) replaced with
  `<RhfRichText>` (rows→minHeight: 4→160, 6→200; dropped `maxLength`; labels/helperText preserved).
- `grant-form.tsx` submit guard — executiveSummary emptiness + min-length(10) checks now strip
  HTML tags first (`.replace(/<[^>]*>/g, "").trim()`) so `<p></p>` no longer passes as content.
- `grantdocument/components/impact-document.tsx` — the 5 narrative sections + impactStories +
  challengesAndRisks now render via `sanitizeHtml(...)` + `dangerouslySetInnerHTML` instead of
  plain `{value}`, so HTML narrative prints as formatted text, not raw tags.
- Backward-compatible: existing plain-text drafts render fine as innerHTML.
- Verified: `tsc --noEmit` clean (0 errors) across the whole frontend.

---

## D3 ▶ USER-OWNED — Apply pending EF migrations + seeds

These were generated/authored in prior sessions but **not applied** (migrations are strictly
user-owned per policy). Run locally, then commit. I cannot run these.

- **#63 GrantReport tables** (grantreport.md ISSUE-9):
  `dotnet ef migrations add AddGrantModule_GrantReports_Initial -p Base.Infrastructure -s Base.API`
  then `dotnet ef database update`.
- **Grant fund-receipt tracking** — migration generated NOT applied; seed under
  `sql-scripts-dyanmic/` pending. (memory `project_grant_fund_receipt_tracking`)
- **Program → Grant fund allocation (§⑭)** — migration generated NOT applied.
  (memory `project_grant_program_fund_allocation_integration`)
- **Grant funder communication** — migration + 7 seeded templates user-owned.
  (memory `project_grant_funder_communication`)

> After each `database update`, run the paired seed file, then a smoke check on the affected row.

---

## D4 ▶ USER-OWNED — Frontend package install (grantreport ISSUE-8)

`isomorphic-dompurify` is referenced in `package.json` but not installed (agent bash was
sandboxed). Run in `PSS_2.0_Frontend/`:

```
pnpm add isomorphic-dompurify @types/dompurify
```

Blocks the rich-text sanitisation path used by D2 if not already present.

---

## D5 ▶ BLOCKED (infra) — Blob file-upload

Grant #62 ISSUE-2 and grantreport.md ISSUE-2 both fall back to URL-paste. The full blob-upload
path (`uploadGrantAttachment` mutation + FE multipart service + DocumentTypes seed) is **BUILT
but DORMANT** — it needs a provisioned **PRIVATE** storage container that does not exist yet.
This is infrastructure, not code. **Do not build.** Flip live only after storage is provisioned;
see memory `project_grant_attachment_url_vs_upload`.

---

## D6 ▶ DEFERRED — Sponsor allocation-from-source (§⑭ tail)

grant.md ISSUE-20: DonationPurpose half is planned (`donationpurpose.md` §⑮). **Sponsor**
allocation remains design-deferred and is a *different screen's* scope — not a Grant fix.
Requires `/plan-screens` if/when the business prioritises it. **Do not build under
`/continue-screen`.**

---

## Closed this reconciliation (2026-07-14)

- Synced grant.md top "pre-flagged" table to the live §⑬ (9 rows → CLOSED/PARTIALLY_ADDRESSED).
- ISSUE-6 + ISSUE-11 confirmed CLOSED (session 20 — `GrantRollupRecalculator`; BE commit
  `8402650a`, pushed).
- Corrected stale assumption: #63 is COMPLETED (not a stub).
- **D1 verified DONE** (ISSUE-1 CLOSED session 21, no code change).
- **D2/ISSUE-3 DONE in-session (session 22)** — the earlier DEFERRED verdict was based on two
  false facts (`RhfRichText` "missing" was a casing lookup error; `isomorphic-dompurify` is in
  fact installed). It was a plain in-scope component swap in the hand-written `grant-form.tsx`,
  not a FLOW-renderer job. Reused `RhfRichText`, no new dependency, no Spec change.

## Backlog now: nothing is in-scope for `/continue-screen`

Every remaining item is either **done** (D1, D2), **out-of-scope/needs `/plan-screens`** (D6),
**user-owned** (D3 migrations, D4 `pnpm add`), or **infra-blocked** (D5). Do **not** generate
another `/continue-screen` prompt from this tracker until a genuinely new in-scope fix surfaces.
```
