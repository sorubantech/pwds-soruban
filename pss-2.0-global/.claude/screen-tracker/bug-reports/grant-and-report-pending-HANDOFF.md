# HANDOFF — Grant (#62) & Grant Report Generation (#178) — Pending Items

> **Purpose:** session-continuation checklist. Both screens are `status: COMPLETED`; the items
> below are the *remaining* open/deferred/unverified work so a fresh session can pick up without
> re-reading the full prompt files. Source of truth remains each screen's `⑬ Build Log § Known Issues`
> — this file is a roll-up snapshot as of **2026-07-13**.
>
> To resume a screen: `/continue-screen #62` or `/continue-screen #178`.
> Spec changes (new tables/columns) require `/plan-screens` first, not `/continue-screen`.

---

## 1 · Grant Report Generation (#178 · GrantDocument)

**File:** `prompts/grantdocument.md` · REPORT/DOCUMENT · query-only (NO migration) · COMPLETED (Session 1, 2026-07-10)
**Commits:** BE `f5875192` · FE `ea129a11` · docs `33af79f` — all landed.

### 1a · Deferred issues (design-locked, not bugs)
| ID | Sev | Area | Item | Status |
|----|-----|------|------|--------|
| DOC-1 | LOW | Impact | Beneficiaries-served has no direct Grant→Case FK; V1 may ship **target-only** (Program.TargetBeneficiaries + "actual count pending" note). Upgrade if a clean enrollment-count query is found. | OPEN |
| DOC-2 | LOW | Export | Server-side **stored** PDF + **email attachment** are SERVICE_PLACEHOLDER. On-screen + print-CSS + browser print-to-PDF is REAL. Email handler writes the GrantCommunication audit row + toasts; it does NOT attach a generated PDF. | OPEN |
| DOC-3 | LOW | Audit | No persisted issued-document row in V1 (query-only). Future `report-row-table` if issued-doc versioning/audit is required. | DEFERRED |

### 1b · Unverified — FULL E2E never run (highest-value next work)
The build compiled/landed but the runtime checklist (§⑪ / Verification) is **entirely unchecked**. Run against a live seeded DB:
- [ ] `dotnet build` + `pnpm dev` — page loads at `/crm/grant/grantdocument`
- [ ] **`GRANTDOCUMENT` menu row present in seeded DB** — `sql-scripts-dyanmic/GrantDocument-sqlscripts.sql` exists but menu-row execution was **never re-verified** against a live DB (explicit Session-1 next-step).
- [ ] Grant picker + Document Type render; Generate disabled until a grant is picked
- [ ] FINANCIAL doc renders full A4 layout (letterhead / funder / summary / receipts / budget-vs-actual / programs / signature / footer)
- [ ] IMPACT doc renders full A4 layout (narrative / deliverable KPI bars / impact stories / beneficiaries / challenges / timeline)
- [ ] Tenant logo + address + brand color from Company + OrganizationSetting (not hardcoded)
- [ ] **Financial totals reconcile exactly with the Grant detail financial summary** (top failure mode — divergent aggregation)
- [ ] All amounts FX-normalized (`GrantCurrencyAmount ?? Amount`); no raw mixed-currency sums
- [ ] ComplianceRate computed + displayed; "No reports due yet" when due=0
- [ ] Over-spent budget lines + admin>10% advisory render
- [ ] Print preview == on-screen render (no app chrome); Download PDF identical via print-CSS (NOT html2canvas)
- [ ] Email to Funder → SERVICE_PLACEHOLDER toast + GrantCommunication row (Direction=OUTBOUND_FUNDER)
- [ ] BOTH type → both docs render with page break
- [ ] Role-scoped: only in-scope grants pickable; **InternalNotes / RejectionReason absent from network payload**
- [ ] Draft/Rejected grant → diagnostic empty-state, no document

### 1c · Deliberately NOT built (spec-sanctioned deferrals — do not "fix" without a decision)
- Signatory-override dropdown (§⑥ panel #4) — `getGrantDocument` takes no signatory arg; issuer.signatoryName is tenant default.
- Bulk zip download — optional, SERVICE_PLACEHOLDER, skipped.
- `grant-service-entity-operations.ts` registration — screen uses `useLazyQuery`/`useMutation` directly (like `grantreporting`), never the operations-registry; a `getById` registration would be dead config.
- Future document types (`PERIOD_PROGRESS`, `AWARD_LETTER`, `COMPLETION_CERTIFICATE`, `COMPLIANCE_SUMMARY`) — enum is architected open; add = one enum value + one BE assembly branch + one FE `<XDocument>` component. Do NOT build now.

---

## 2 · Grant (#62 · GrantDocument entity core)

**File:** `prompts/grant.md` · FLOW · COMPLETED (last Session 16, 2026-07-10)
**Working-tree note:** `prompts/grant.md` is currently **unstaged-modified** (belongs to other in-flight tasks; left unstaged intentionally).

### 2a · OPEN issues
| ID | Sev | Area | Item |
|----|-----|------|------|
| ISSUE-3 | MED | FE | Rich-text editor missing — 4 narrative fields (ProblemStatement / ProposedSolution / ExpectedOutcomes / SustainabilityPlan) fall back to plain textarea. Wave-4 follow-up to add Quill/Tiptap. |
| ISSUE-4 | MED | FE | Kanban Pipeline is custom flex layout, **no drag-drop in V1**. Stage transitions via DETAIL header actions. V2 = add `react-dnd`. |
| ISSUE-5 | MED | BE | Verify `GRANTSTAGE` MasterData codes match `GrantStageHelper` constants (alignment check). |
| ISSUE-6 | MED | BE | Cached `Grant.TotalSpent` / `ComplianceRatePct` stay 0/NULL until #63 wires expense logging transactionally. **Partly overtaken** — GrantExpense create/delete now exists (Session-4 cash engine); confirm the cached columns are actually refreshed on expense mutations, else this reduces to a refresh-wiring check. |
| ISSUE-8 | MED | FE | `<ApiSelectV2 isMulti />` for Implementing Branches — verify it exists; fallback = `<MultiSelectChips>` composite. |
| ISSUE-10 | MED | FE/BE | Amount-Range filter enum codes (`<50K`, `50K-100K`, …) must stay in sync between FE select and `GetGrants` BE parser. Document codes as shared constants. |
| ISSUE-11 | LOW | BE | `NextReportDueDate` auto-compute deferred → post-#63 `recomputeNextReportDueDate(grantId)` mutation. Manual nullable field for now. |
| ISSUE-12 | LOW | FE | Quick-Stat "Next Report Due" color-coding (amber < 30d, red < 7d / overdue) via conditional class. |
| ISSUE-14 | LOW | FE | Currency thousand-separator formatting on blur — reuse `<CurrencyInput>` if present in FE registry. |

### 2b · Partially addressed
| ID | Sev | Item |
|----|-----|------|
| ISSUE-2 | HIGH | File-upload attachments: Documents-tab "Upload Document" opens URL-paste modal + persists via `updateGrant` echo (Session 15 WI-10). **Real blob/multipart upload still dormant** — flip on when a private blob container is provisioned. See `[[project-grant-attachment-url-vs-upload]]`. |
| ISSUE-1 | HIGH | Original premise "GrantReport #63 + GrantExpense not built" — **GrantExpense cash engine now exists** (Session-4). Reconcile: confirm which Budget/Reports tab placeholders are still live vs. wired, then split or close this issue. |

### 2c · Preserve / non-actionable
- **ISSUE-15 (PRESERVE):** the seed folder is spelled `sql-scripts-dyanmic/` (typo) on purpose — match the precedent, do not "correct" it.

### 2d · Separate workstream (NOT part of screen issues)
- **"Grant Module Stabilization Pass"** plan at `C:\Users\USER\.claude\plans\goofy-forging-rivest.md` (WI-1…WI-12). BE/FE halves landed as Grant Sessions 15/16 (commits `7e1e41a5`, `ca242be9`). **Needs a reconcile pass** to confirm what, if anything, remains before the plan can be closed. Requires explicit go-ahead before starting.

---

## Closed / resolved (for reference — do not re-open)
- **#62:** ISSUE-7 (GrantCode gen — NON-BUG, uses NumberSequenceGenerator), ISSUE-9 (Export dropdown removed, no CSV util exists), ISSUE-13 (inline "+ New Funder" modal), ISSUE-16 (admin-flag exact match + soft cap warning), ISSUE-17/18/19 (Program→Grant fund allocation + double-spend fix, Session 4).
- **#178:** none closed beyond planning-state (DOC-1/2/3 remain as documented).

---

## Suggested next-session order
1. **#178 E2E + menu-seed verification** (§1b) — the only screen with zero runtime verification; highest risk of a silent "menu missing / totals drift" defect.
2. **Grant Module Stabilization reconcile** (§2d) — determine if the plan is fully shipped or has a tail.
3. **#62 quick FE polish batch** — ISSUE-12 + ISSUE-14 (color-coding + currency formatting) are small, self-contained, no BE/migration.
4. Leave ISSUE-3/4/8/10 (larger FE efforts) and ISSUE-5/6/11 (BE, #63-coupled) for scoped sessions.
