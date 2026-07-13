# Crowdfunding #16 — Session Handoff (continue next session)

> Paste-to-resume prompt. Run `/continue-screen #16` then feed this. Register:
> `.claude/screen-tracker/bug-reports/crowdfunding-audit-2026-07-10.md`.
> Prompt/Build Log: `.claude/screen-tracker/prompts/crowdfunding.md` (§⑬).

---

## Where we left off (end of Session 16 — 2026-07-13)

**Done this session (CF-H7 + CF-H11/H12 batch — FE `tsc --noEmit` clean, 0 errors):**
- **CF-H7** — removed the dead "Cover processing fees" toggle from the public
  donate form (`crowdfundingpage/donate-form.tsx`). Config flag kept on the DTO
  for one-line re-enable when real fee support exists.
- **CF-H11** — mounted the orphaned `LifecycleConfirmModal` + `DeleteCrowdFundModal`
  in `crowdfunding/index.tsx`; added a status-aware Lifecycle section to
  `crowdfund-detail-sheet.tsx` (Publish/Unpublish/Close/Archive/Duplicate/Delete);
  fixed dead header Edit → routes to editor; dropped dead Quick-Edit row; deleted
  orphan `crowdfund-quick-edit-dialog.tsx` (was untracked).
- **CF-H12** — `index-page.tsx` refetches grid rows + chip summary on `refreshToken`
  bump (widgets already subscribed); disabled native row Delete; Delete now goes
  through the Draft-only drawer path (restores CF-M10 affordance).

**Git state (NOT yet committed):**
- FE repo `PSS_2.0_Frontend` (branch `module/case`): **4 files STAGED**, ready to commit —
  `crowdfunding/index.tsx`, `crowdfunding/index-page.tsx`,
  `crowdfunding/crowdfund-detail-sheet.tsx`, `crowdfundingpage/donate-form.tsx`.
  - Commit msg drafted (see below). **First action next session: commit these** (or discard if superseded).
- Main repo `.claude/` docs: register + §⑬ Build Log edits are **UNSTAGED** — commit separately in the main repo.

**Drafted FE commit message:**
```
fix(crowdfunding): remove dead cover-fees toggle + wire CRM lifecycle actions/refetch (CF-H7/H11/H12)
```

---

## Pending backlog (pick next — recommended order)

### 1. CF-H1 — Razorpay recurring subscription created at *Initiate*  ⬅ recommended next HIGH
- Plan/subscription is created before payment proof (`#173 BE InitiateCrowdFundDonation :468-494`);
  an abandoned tab orphans a live, un-cancellable auto-charging subscription with no local record.
- **Fix:** create plan/subscription only after Confirm succeeds; persist gateway subscription id
  for cancel/track. **BE-only, #173 recurring-flow.** No schema change if we reuse existing columns —
  verify first. Likely mirrors P2P (#170) / ODP — check before editing (fix as a set).

### 2. CF-H4 — Multi-currency totals summed with no FX
- `NetAmount` is donor-currency; `BaseCurrencyAmount` ignored (6 BE queries, `GetCrowdFundPublicStats`
  self-documents as ISSUE-8). Violates direct-pair FX rule ([[feedback-fx-direct-pair]]).
- **Fix:** aggregate on `BaseCurrencyAmount`; if null, resolve via `IFxRateService` snapshot value.
- **Deferred** pending a real cross-currency donation test (see session 10). Needs test data.

### 3. CF-B4 remainder — anti-automation (⚠️ PARTIAL, needs infra/shared-wiring go-ahead)
Done: honeypot (Crowdfund FE) + idempotency (Crowdfund + P2P, in-proc `IMemoryCache`).
**Remaining — DO NOT start without user go-ahead (shared-wiring / infra):**
- Rate-limit binding — needs shared `Base.API/DependencyInjection.cs` + a GraphQL per-operation guard/interceptor.
- reCAPTCHA — needs a Google reCAPTCHA secret provisioned.
- Real CSRF — needs antiforgery middleware/cookie infra.
- ODP idempotency — `IdempotencyKey` not plumbed on ODP Initiate (DTO/GraphQL/FE); plumb first.
- In-proc cache is best-effort (no cross-instance / concurrent-double-submit); distributed cache
  or DB unique key on `IdempotencyKey` would close it (schema/infra = user-owned).

### 4. CF-B1 — Real-time "Raised" is chronically $0 (deferred promotion)  — PRODUCT DECISION
- Public donation writes only `OnlineDonationStaging`; `GlobalDonation` + `CrowdFundDonations`
  junction (all totals read these) created only when staff resolve in Donation Inbox (#175).
- Changes real-time semantics for **all three** public donation types — sequence deliberately.
  Don't start until the user makes the call.

### MEDIUM cluster (still open — lower priority)
CF-M1 (StartDate not enforced), CF-M2 (no EndDate auto-close), CF-M3 (Draft preview-token no-op),
CF-M4 (spoofable tenant host), CF-M5 (stored-XSS surface), CF-M6 (Confirm no wrapping txn),
CF-M8 (BE errors → 404), CF-M9 (no mobile sticky donate widget). See register MEDIUM table.

---

## Guardrails (still in force)
- **Migrations user-owned:** never run `dotnet ef migrations add`/`database update`/`remove`,
  never hand-author migration/snapshot. I build to prove compile → hand user the migration spec.
  I write seed files; user applies. [[feedback-migrations-strictly-user-owned]]
- **Shared-wiring files** (`DependencyInjection.cs`, DbContext, `Query.cs`, `Mutation.cs`,
  `Routes.tsx`, seed SQL, DI, sidebar nav, `card-variant-registry.ts`): warn user before editing.
- **Backend is gitignored in main repo** — pass explicit backend path to Grep/ripgrep.
- **Stage FE and BE separately by explicit path — never `git add -A`.** `.claude/` docs live only in main repo.
- **Fix cross-surface bugs as a set** — crowdfund handlers mirror P2P (#170) + ODP field-for-field.
