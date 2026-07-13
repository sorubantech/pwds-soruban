# Continuation Prompt — Screen #10 (Online Donation Page) Bug Remediation

> Paste this into a new session to resume the `/continue-screen` remediation flow.

## Context

Continuing bug-remediation for **screen #10 (Online Donation Page)**, driven by the audit register `.claude/screen-tracker/bug-reports/onlinedonationpage-audit-2026-07-10.md`. Screen type = **EXTERNAL_PAGE / DONATION_PAGE** (anonymous public donor surfaces at `/p/{slug}` NAV + `/embed/{slug}` IFRAME).

## Repo layout (3 independent git repos)

| Repo | Stack | Notes |
|------|-------|-------|
| `PSS_2.0_Frontend` | Next.js 14 / React / TS | its own git repo |
| `PSS_2.0_Backend` | .NET 8 / EF Core / GraphQL (HotChocolate) | its own git repo |
| `pss-2.0-global` | `.claude/screen-tracker` docs | its own git repo |

- Stage/commit **per-repo**.
- **User commits themselves — do NOT commit without explicit approval.**

## ✅ DONE — ODP-H9 (failed-PayU donor dead-end, P1) — COMMITTED

- `payu/return/route.ts` — fixed dead cancel branch (`"userCancelled"` compared after `.toLowerCase()` → now matches `usercancelled` / `cancel` / `cancelled`).
- `p/[slug]/page.tsx` — reads `?donation=failed&reason=`, `describeDonationFailure()` maps to a charge-state-aware message, passes `forceError` to `<DonationPage>`.
- `donation-page.tsx` — `forceError` prop + dismissible `PaymentFailureBanner` rendered once in the dispatcher (covers all 7 templates).
- Tracker docs updated (prompt Build Log Session 41 + audit Fix Log). FE `tsc --noEmit` = 0 errors.

## ⏳ PENDING — pick next task from the audit register

1. **ODP-H8 (recommended next)** — add `frame-ancestors` CSP to the public NAV page for clickjacking protection (FE `next.config.mjs` / middleware). Self-contained; no secrets / migration / product decision.
2. **ODP-M10** — config-key drift (BE config).
3. **ODP-M11** — dead legacy Braintree credential path (BE cleanup).

### Deferred (bigger scope / product decision — NOT quick wins)

- reCAPTCHA + CSRF shared-platform hardening pass.
- ODP-B5 auto-promotion → route via `/plan-screens`.

## Standing constraints (from memory — always in effect)

- **NEVER** run `dotnet ef migrations add` / `database update` / `remove` or hand-author migrations/snapshots — migrations are strictly user-owned. I write seed files; user applies.
- DB columns are UTC `timestamptz` (`DateTimeKind.Utc`; Npgsql throws on `Kind=Unspecified`).
- Prove compilation before handoff (BE build / FE `tsc --noEmit`).
- Default to **Sonnet** for build agents (cost-conscious).
- Reuse established sibling patterns; be honest about partial vs. full scope.

## Start by

Re-read the audit register (`onlinedonationpage-audit-2026-07-10.md`) to confirm current open findings, then proceed with **ODP-H8** unless told otherwise.
