# S6 — Residual Screen Defects

**Wave 2 · run in parallel with S5 · lowest priority — first thing to cut if time runs out**
**Repos:** `PSS_2.0_Backend` and `PSS_2.0_Frontend`

## Standing rules for this session
- **Never `git commit`.** Stage only (`git add`) and report. No push, amend, or tag.
- No `Co-Authored-By: Claude` / "Generated with Claude Code" lines in any commit message you draft.
- **You do not run `dotnet build`; you do not create EF migrations.**
- Do not toggle screen status COMPLETED → IN_PROGRESS → COMPLETED for a fix. Append to the Build Log instead.
- **No browser dialogs** — never `window.prompt` / `alert` / `confirm`. Use an inline `Textarea` capture or a Dialog component.
- Reuse the canonical form-field components (`FormInput`, `FormSelect`, `FormDatePicker`) and the shared grids (`FlowDataTable` / `AdvancedDataTable`). Do not fork either.
- Stay clear of files owned by S1–S5.

## Scope, in priority order

### 1. Phase 6 §9.3 — CRITICAL intimations must not be dismissible
In `IntimationService`, the **refresh** branch must, when severity resolves to CRITICAL:
- set `IsDismissible = false`
- soft-delete that intimation's existing `IntimationDismissals`

Otherwise a tenant who dismissed the notice while it was a warning never sees it again after it escalates — which is precisely when they need to. **No migration required.**

### 2. Phase 6 §9.4 — dedup index filter *(decision, then act)*
The partial unique index currently filters on `"Status" = 'ACTIVE'`. The question is whether to widen it to `"Status" = 'ACTIVE' AND "IsDeleted" = false`.

Work out whether a soft-deleted ACTIVE row can currently block a legitimate re-raise. If it can, this is a real bug — but the fix is an index change, so **write the migration intent and hand it to the user**. Do not run `ef migrations add`.

### 3. Contact screen `#18`
Marked `NEEDS_FIX`. Determine what is actually broken, then fix it or report it as a known limitation. Do not expand it into a redesign.

### 4. Tenant communications configuration UI
Defects noted in the demo runbook §4. Triage: fix what is cosmetic-to-moderate, report anything structural.

## Explicitly NOT in scope
- **Phase 7** — the Feature Dependency Registry, trigger layers and readiness widgets are post-MVP-1. The only Phase 7 item shipping tonight is the D-2 one-liner, and **S2 owns it**.
- The three-way `CompanyPaymentGateways` predicate drift across `GoLiveChecklistBuilder.cs:131`, `PaymentGatewayMissingCondition.cs:33` and `ValidateOnlineDonationPageForPublish.cs:213`. Known, documented, deliberately deferred.
- Runtime acceptance suites (Phase 4 §③ Part A, Phase 5 §⑤, Phase 6 §⑤). They are unexercised and will stay that way for MVP-1 — that is a stated, accepted gap, not something to start tonight.

## Acceptance
- [ ] A CRITICAL intimation reappears for a user who previously dismissed it as a warning
- [ ] §9.4 decided, with the migration handed off if one is needed
- [ ] Contact `#18` either fixed or written up as a known limitation
- [ ] Nothing in this session blocked anything in S1–S5
