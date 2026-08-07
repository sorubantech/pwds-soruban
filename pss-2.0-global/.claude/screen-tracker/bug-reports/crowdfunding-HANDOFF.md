# Crowdfunding #16 — Session Handoff (continue next session)

> Paste-to-resume prompt. Run `/continue-screen #16` then feed this.
> Register: `.claude/screen-tracker/bug-reports/crowdfunding-audit-2026-07-10.md`.
> Prompt / Build Log: `.claude/screen-tracker/prompts/crowdfunding.md` (§⑬).
> `.claude/` is git-tracked, so this handoff travels across machines/sessions.

**Invoke:** `/continue-screen #16`

---

## 1. Current status (end of Session 24 — 2026-07-13)

- **Screen #16 Crowdfunding** (registry #16, screen #173 — FLOW public donation page + CRM list). All **12 HIGH** findings and the money-truth items (CF-B2, CF-B3, CF-H4, CF-H5) are resolved. Screen is effectively **COMPLETED**; prompt frontmatter still reads `status: NEEDS_FIX` only because medium/low backlog items remain.
- **Last work done (CF-M10-partial):** the "Goal Met" chip **filter** in `GetAllCrowdFundList.cs` was made inclusive to match the already-inclusive chip **count** and row **badge** — a fund that reached its goal while still `Active` now stays visible when the chip is clicked. Reuses the same net-of-refunds base-currency roll-up as the summary handler. **No schema change.**
- **Staged, awaiting your commit** (three repos, staged separately — NOT committed):

  | Surface | Repo / branch | File |
  |---|---|---|
  | BE | `PSS_2.0_Backend` / `module/case` | `.../CrowdFunds/Queries/GetAllCrowdFundList.cs` |
  | FE | `PSS_2.0_Frontend` / `module/case` | `.../crowdfunding/crowdfund-store.ts` (comment-only) |
  | Docs | main repo / `master` | `prompts/crowdfunding.md` + `bug-reports/crowdfunding-audit-2026-07-10.md` |

- **Commit messages already presented:**
  - BE — `fix(crowdfund): Goal-Met chip filter matches its count and row badge (#16/#173)`
  - FE — `docs(crowdfund): refresh chipToStatuses comment for CF-M10 (#16/#173)`
  - Docs — `docs(crowdfund): log Session 24 CF-M10 filter alignment + mark audit fixed (#16)`
- Next Build Log entry = **Session 25**. (Prompt §⑬ Sessions holds 20–24; the audit register uses its own separate counter where CF-M10 = "session 17" — keep each file internally consistent, do NOT reconcile the two counters.)

---

## 2. Where to start

1. **Confirm the three CF-M10 commits landed** — check git log on both `module/case` branches (BE + FE) and `master` (docs).
2. Then pick the next backlog item from the tiers below. **Do NOT build the needs-decision or blocker items without an explicit go-ahead.**

---

## 3. Pending issues (priority tiers)

### Needs a decision before any build (do NOT autonomously build)
- **CF-M2** — No EndDate auto-close job; ended campaigns still cosmetically show "Active" (donations already blocked server-side, so cosmetic). Needs a scheduler / background-job infra decision.
- **CF-M4** — Tenant resolved from spoofable `x-forwarded-host` with silent first-active fallback. Needs a shared host-resolver decision.

### Deferred pending your sign-off (design-decision-sized)
- **CF-M3** — Draft preview-token is a no-op (any non-empty `?previewToken` discloses any Draft). Correct fix = server-**derived** HMAC token spanning two BE handlers (CrowdFund + the Event-mirror `GetEventRegistrationPageBySlug.cs`), a new computed GetById-DTO field, a config secret source, and two FE editor pages.
- **CF-M6** — Confirm has no wrapping transaction on recurring paths; non-locking idempotency read → racing confirms can duplicate schedules.

### LOW cluster (safe FIX/UI passes — good next pick)
- **CF-M10 residual** — "filtered-empty vs truly-empty" list states no longer visually distinct (FE polish; the audit row keeps its `⚠️` for this alone).
- **CF-L1** — Confirm doesn't re-check lifecycle between initiate/confirm.
- **CF-L2** — No maximum-donation cap.
- **CF-L3** — Donor email/IP logged plaintext (`Initiate.cs:563-565`).
- **CF-L4** — 60s public cache has no invalidation → stale status/total after Close.
- **CF-L5** — Duplicate drops PageTemplateId / BeneficiariesJson / DonationFormFieldsJson / email FKs (`DuplicateCrowdFund`).
- **CF-L6** — Thank-you drops receiptUrl/transactionId it already has; a11y (labels lack `htmlFor`, amount chips under 44px tap target, fixed light-theme cards on admin-controlled bg).

### Blockers — do NOT touch without an explicit go-ahead
- **CF-B1** — Real-time "Raised" is chronically $0 under deferred inbox promotion. Public donation writes only `OnlineDonationStaging`; `GlobalDonation` + `CrowdFundDonations` junction (all totals read these) are created only when staff resolve in Donation Inbox (#175). Changes real-time semantics for all three public donation types (Crowdfund / P2P #170 / ODP #10) — sequence deliberately as a set.
- **CF-B4 remainder** — anti-abuse stack: rate-limit binding (needs shared `Base.API/DependencyInjection.cs` + a GraphQL per-operation guard), reCAPTCHA (needs a Google secret), real CSRF (needs antiforgery middleware), ODP idempotency (needs the key plumbed into ODP's Initiate DTO/GQL/FE first). Honeypot + Crowdfund/P2P idempotency already done (Session 12).

---

## 4. Guardrails (carry forward)

- **Three repos, stage separately by explicit path — NEVER `git add -A`.** BE `PSS_2.0_Backend` and FE `PSS_2.0_Frontend` are both on `module/case`; `.claude/` docs live only in the main `master` repo (backend/frontend are gitignored there — pass explicit backend paths to grep/git).
- **I stage only; you commit/push.** Never commit or push unless you ask.
- **Migrations are user-owned** — never run `dotnet ef migrations add` / `database update` / `remove`, never hand-author a migration or snapshot. Build to prove compile, then hand you the migration spec. I write seed files; you apply them.
- **Warn before editing shared-wiring files** (DI, DbContext, `IApplicationDbContext`, `Query.cs` / `Mutation.cs`, `Routes.tsx`, seed SQL, sidebar nav, `card-variant-registry.ts`).
- **Cross-surface bugs are fixed as a set** — crowdfund mirrors P2P #170 + ODP #10 field-for-field.
- **FX:** direct-pair only, no USD triangulation; snapshot the rate VALUE, never an FK; `GetRateAsync` returns null on miss / 1.0 same-code.
- **DB is UTC** — DateTime params must be `Kind=Utc`.
- **Verify properties before use** — read the BE file; never assume a GraphQL field / DTO property / column mapping exists.
- **Token hygiene:** never `Read` REGISTRY.md (~700KB) — grep only; status updates via scripted `sed -i`. Cap prompt §⑬ Sessions at last 5 entries (git keeps the rest); never trim the § Known Issues table; never Read the whole prompt to prune.
- **BUSINESSADMIN role only; Sonnet for BE/FE build agents when the prompt §①–⑫ is detailed** (Opus only on historic-failure patterns); never re-prompt for permissions.
