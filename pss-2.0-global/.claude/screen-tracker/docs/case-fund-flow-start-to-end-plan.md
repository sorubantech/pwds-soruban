# Case Management — Start→End Funding-Flow Plan

> **Status:** PLAN ONLY (2026-06-26). Nothing built. Written first, by user decision, before any of the four threads start.
> **Origin:** 2026-06-26 management demo review. Verdict: the *center* of the demo (Program → Beneficiary → Case) works, but the **START** (how money comes IN to fund a program) and the **END** (in/out amount tracking that reconciles back to the source) are missing from the narrative.
> **Money-in source of truth:** Option A (donation/pledge layer), LOCKED 2026-06-25. See memory `project_case_fund_accounting_redesign`.
> **Companion:** `PSS_2.0_Backend/DatabaseScripts/Seed/DEMO_manual_program_flow.txt` (the live UI walkthrough — this plan extends its STAGE 3 start and STAGE 13 end).

---

## 1. The narrative gap (what the meeting actually flagged)

The current demo script (`DEMO_manual_program_flow.txt`) runs STAGE 1→13. Its two ends are thin:

- **START (Stage 3 "Fund the program")** — the script says *"pick a grant that exists in CRM ▸ Grants — create it first if none is free."* Money simply **appears** as a grant. There is no story of money being **raised**: no campaign, no P2P fundraiser, no pledge, no donor, no realized donation. A grant is a single static lump; the audience never sees money *arrive*.
- **END (Stage 9 cap + Stage 13 dashboards)** — Collected/Used/Available exist, but they reconcile to a manually-typed payment log, not back to the donations that funded the program. The "where did this ₹ come from / where did it go" loop never closes on screen.

The fix is **mostly wiring + seeding of things that already exist**, plus **one genuine build** (donor-announcement email).

---

## 2. Current architecture — the honest map (verified in code 2026-06-26)

### 2a. The money-IN ledger (donation layer) — EXISTS, rich
- `fund.GlobalDonations` (`GlobalDonation.cs`) = one settled donation. Carries amount/currency/mode/receipt/donor (`ContactId`) **and inflow-surface FKs**: `OnlineDonationPageId`, `P2PCampaignPageId`, `P2PFundraiserId`. Child detail rows: `ChequeDonation`, `GlobalReceiptDonation`, `GlobalOnlineDonation`, `DonationInKind`.
- `fund.GlobalDonationDistributions` (`GlobalDonationDistribution.cs`) = splits a donation across `OrganizationalUnitId` / `ContactId` / `DonationOccasionId` with `AllocatedAmount`.
- `fund.DonationPurposes` (`DonationPurpose.cs`) = the campaign/fund a donor gives toward. Has `TargetAmount`, `Start/EndDate`, `OrganizationalUnitId`. **Donors linked via `ContactDonationPurpose`.**
- Inflow channels (all → `GlobalDonation`): **P2P** (`P2PCampaignPage`/`P2PFundraiser`), **Pledge** (`Pledge`/`PledgePayment`, models committed-vs-partial), **OnlineDonationPage** (#10), **Campaign**. *(Crowdfunding = public route stub only, no BE entity.)*

### 2b. The money-on-PROGRAM ledger (case layer) — EXISTS, separate
- `case.ProgramFundingSource` (`ProgramFundingSource.cs`) = a funder committed to a program. **Three-way XOR identity**: `GrantId` **XOR** `DonationPurposeId` **XOR** `SponsorContactId`. Status PENDING→APPROVED→CLOSED (`FUNDSOURCESTATUS`). Carries `ExpectedAnnualAmount` (the commitment).
- `case.ProgramFundingTransaction` (`ProgramFundingTransaction.cs`) = **manual** payment log per source. Keyed by `FundingSourceId` only. `PaymentStatus` WAITING|TRANSFERRED, `Amount`, `TransactionDate`.
- Rollups (`GetProgramFundingAllocation.cs`): **Collected** = Σ TRANSFERRED `ProgramFundingTransaction`. **Used** = Σ active `BeneficiaryServiceLog.AmountCents` (program-pooled, no per-source attribution). **Available** = Collected − Used.

### 2c. ⚠️ THE BRIDGE DOES NOT EXIST (the spine of this plan)
- `ProgramFundingTransaction` has **no `GlobalDonationId`**. `GlobalDonation` has **no `DonationPurposeId`**.
- So even when a `ProgramFundingSource` points at a `DonationPurpose` (`DonationPurposeId`), **Collected is still hand-typed payment-log rows**, NOT a roll-up of real donations raised against that purpose.
- Memory already flags this as gap **G9** ("no source→origin reconciliation"). Option A's promise — *"Collected rolls up from real settled donations"* — is **future work, not current code.**

**Consequence for the demo:** the START→END loop can be closed **two ways**, and this is the one decision the plan forces (§5):
- **(A) Demo-fake bridge** — seed *both* sides (donations against a purpose for the donation screens **+** matching TRANSFERRED `ProgramFundingTransaction` rows for Collected) and narrate them as the same money. No build. Honest as a demo, not as accounting.
- **(B) Real reconciliation** — build the roll-up so Collected derives from `GlobalDonation`s attributed to the purpose. This is the G9 build (new attribution column(s) + roll-up query). Bigger; out of scope for a near-term demo but the eventual Option-A target.

The one missing build that is *independent* of this fork is the **donor-announcement email** (§4, Thread 1).

---

## 3. Target end-to-end narrative (what the demo should show)

```
  ┌─ START (raise the money) ─────────────────────────────────────────┐
  │ DonationPurpose "Bright Futures Education Fund" (target ₹360k)     │
  │   ├ P2P campaign + a fundraiser → donors give → GlobalDonations    │
  │   ├ a Pledge (₹50k/mo, 70% received) → PledgePayments              │
  │   └ donors = Contacts + ContactDonationPurpose                     │
  │   ⇒ Purpose shows "₹X raised of ₹360k" from real donation records  │
  └───────────────────────────────────────────────────────────────────┘
                              │  (link purpose as a ProgramFundingSource)
                              ▼
  ┌─ CENTER (already built) ──────────────────────────────────────────┐
  │ Program → approve → [PROGRAM_ANNOUNCEMENT email to donors] →       │
  │ Beneficiaries → enrol → verify → Cases → service logs → milestones │
  └───────────────────────────────────────────────────────────────────┘
                              │
                              ▼
  ┌─ END (track in vs out) ───────────────────────────────────────────┐
  │ Fund Allocation: source=Donation Purpose, Committed/Collected/     │
  │   Available + payment log                                          │
  │ Program Dashboard: Need ₹360k · Expected ₹360k · Collected ₹X ·    │
  │   Used ₹Y · Available ₹(X−Y)  ← the 4 numbers, never collapsed     │
  │ (B-only) "Collected" traces back to the donations that raised it   │
  └───────────────────────────────────────────────────────────────────┘
```

The 4 numbers that must never collapse (from `project_case_fund_accounting_redesign`):
**Need** (`ProgramFundingMath.ComputeAnnualNeed`) · **Expected** (`ProgramFundingSource.ExpectedAnnualAmount`) · **Collected** (Σ TRANSFERRED) · **Used** (Σ ServiceLog). Available = Collected − Used.

---

## 4. The four threads — sequenced, with seed-vs-build labels

| # | Thread | Type | My side | User side | Depends on |
|---|--------|------|---------|-----------|-----------|
| 1 | **Donor-announcement email** | **BUILD** (real) | compiling BE changes (copy event pattern) + FE toggle | build BE, run seed | event pattern (exists) |
| 2 | **Wire donation inflow into demo** | **SEED + SCRIPT** | seed SQL + demo-script edit + `__demo.*` helpers | run seed, rebuild FE | §5 fork decision |
| 3 | **(this) Full start→end plan** | **PLAN** | ✅ this document | — | — |
| 4 | **Money in-vs-out on dashboard** | **FE (+ maybe build)** | surface the 4 numbers | FE rebuild | §5 fork (B adds BE) |

### Thread 1 — Donor-announcement email (the one genuine build)
Copy the proven event pattern (`EventCommunicationEmailService.SendDonorAnnouncementAsync` + `EventDonorAudienceQuery`).
- **BE (user compiles):**
  1. `EmailTemplate` seed: `PROGRAM_ANNOUNCEMENT` template.
  2. `PlaceholderDefinition` rows for `EntityType = 'Program'` (program name/code/description/lead/etc.) — mirror the Event placeholder rows.
  3. New `ProgramDonorAudienceQuery` (copy `EventDonorAudienceQuery`) — resolve the donor audience for a program. **Audience source = donors linked to the program's funding-source DonationPurpose(s) via `ContactDonationPurpose`** (and honor `DoNotEmail`, per the event query).
  4. Send hook on **`ApproveProgram`** in `ProgramLifecycle.cs` (approve is the natural announce moment; CreateProgram leaves it DRAFT). Reuse `EmailSendJob`/`EmailSendQueue` + `SendEmailByTemplateKeyAsync` (see memory `project_event_email_comms_design`, `reference_email_provider_resolution`).
  5. Gate the send on a new `Program.AnnounceToDonors` bool (or a command arg) so it's opt-in.
- **FE (mine):** a small "Announce to donors" toggle on the program form / approve action.
- **Handoff:** user builds BE + 1 migration (`Program.AnnounceToDonors` col) + runs the template/placeholder seeds.
- **Independent of the §5 fork** — can start anytime.

### Thread 2 — Wire donation inflow into the demo (seed + script + console)
Make the START visible: money is *raised*, not conjured.
- **Seed (`seed_case_demo_*.sql`, idempotent, PostgreSQL — see memory `project_postgresql_db`):**
  1. A `DonationPurpose` "Bright Futures Education Fund" (target ₹360k), tied to the program's org unit.
  2. An inflow surface or two: a `P2PCampaignPage` + one `P2PFundraiser` (and/or a `Pledge` + `PledgePayment`) referencing the purpose's org unit.
  3. A handful of donor `Contact`s + `ContactDonationPurpose` rows.
  4. Realized `GlobalDonation`s (+ `GlobalDonationDistribution` to the org unit, + child receipt rows) summing to a believable raised figure.
  5. **§5 fork:** if (A), ALSO seed a `ProgramFundingSource` (DonationPurpose type) + matching TRANSFERRED `ProgramFundingTransaction` rows so Collected reflects the raised money. If (B), that roll-up comes from the build instead.
- **Demo script (`DEMO_manual_program_flow.txt`):** add a **STAGE 0 — "Where the money comes from"** before Stage 1 (walk the purpose + P2P/pledge + donors + raised total), and rewrite **STAGE 3** to link the *Donation Purpose* as the funding source (not a bare grant), pointing back to Stage 0's raised money.
- **`__demo.*` console helpers** (extend the pattern in `reference_demo_autofill_console_pattern`): `__demo.donationPurpose()` / `__demo.raiseFunds()` to auto-fill the purpose + donation forms during a live demo, mirroring `__demo.program()`/`__demo.fundAllocation()`.
- **Handoff:** user runs seed + rebuilds FE. **Blocked on §5 decision** (changes whether a `ProgramFundingTransaction` bridge is seeded).

### Thread 4 — Money in-vs-out on the dashboard
Make the END legible: the 4 numbers, side by side.
- **FE (mine):** on the Program Dashboard (`PROGRAMDASHBOARD`, memory `project_program_dashboard_static`) and/or Fund Allocation header, surface **Need · Expected · Collected · Used · Available** as one coherent in-vs-out strip. `GetProgramFundingAllocation` already returns `ComputedAnnualNeed`, `TotalExpected`, `TotalTransferred`, `TotalUsed`, `TotalAvailable` — so for the numbers alone this is **FE-only**.
- **§5 fork (B):** to make Collected *trace back to the donations* (the reconciliation view), add the BE roll-up — out of scope for fork (A).

---

## 5. THE decision this plan forces

> **For the demo, do we (A) fake the bridge with parallel seed rows, or (B) build the source→origin reconciliation roll-up?**

- **(A) Demo-fake bridge** — recommended for a near-term demo. Zero BE build for Threads 2 & 4. Seed donations *and* matching TRANSFERRED transactions; narrate as the same money. Risk: an attendee who probes "is Collected computed from those donations?" gets "seeded to match, not yet auto-reconciled."
- **(B) Real reconciliation (G9)** — the eventual Option-A target. New attribution (e.g. `GlobalDonation.DonationPurposeId` or a designation link) + a roll-up so Collected = Σ settled donations on the purpose. Bigger BE build + migration; makes Threads 2 & 4 truthful end-to-end.

**Recommended sequence:** Thread 1 (independent build, highest value, no fork) → decide §5 → Thread 2 + Thread 4 under fork (A) for the demo → revisit (B) post-demo as part of the staged `project_case_fund_accounting_redesign` plan (phase 1.5 / 6 reconciliation).

---

## 6. Constraints (standing)
- User builds the BE — I make compiling changes only, then hand off (`feedback_user_builds_backend`).
- User creates EF migrations — I never run `ef migrations add` / edit `ModelSnapshot` (`feedback_user_creates_migrations`).
- Work in `pwds-soruban - Copy`, not the sibling (`feedback_agent_sibling_worktree_drift`); verify with `git status` + absolute globs.
- Grep is blind to the nested backend repo — enumerate via Glob / PowerShell Select-String (`feedback_grep_misses_nested_repo_files`, `feedback_nested_git_repos`).
- Prefer Sonnet for spawned agents (`feedback_prefer_sonnet_over_opus`).
- No browser dialogs — inline Textarea / Dialog only (`feedback_no_browser_dialogs`).
- PostgreSQL seed conventions: `now()`, double-quoted idents, TRUE/FALSE, `WHERE NOT EXISTS`, `LIMIT 1` (`project_postgresql_db`).
- FE served by Windows service `PssFrontend` (NSSM) on port 3000; user rebuilds FE.
