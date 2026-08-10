# MVP-1 Fix Sessions — Execution Order

**Compiled 2026-08-09 · release target: morning of 2026-08-10**
Source list: [`PSS-2.0-MVP1-PENDING-DEVELOPMENT-LIST.md`](../../PSS-2.0-MVP1-PENDING-DEVELOPMENT-LIST.md)

> ## ⚠️ REVISED 2026-08-09 — the target is DEV/UAT, not production
> Everything below was scoped for a public production release. It isn't one. Revised priorities:
>
> | Session | Revised |
> |---|---|
> | **S1** | **cut to `Auth:PlatformHosts` + CORS, then stop** (~20 min, not 2 h). In UAT these are *functional* blockers — unset `PlatformHosts` means nobody can log in on a real hostname; wrong CORS origin means the frontend can't call the API. All secret rotation → cutover. |
> | **S2** | done and verified. No change. |
> | **S3** | keep the Member Portal route block. `authorize()` server-verify is optional for UAT — finish it if it's close, don't hold the release for it. |
> | **S4** | **now the highest-value session.** UAT is where people judge the product; features that report success while doing nothing generate false bug reports and wasted test cycles. |
> | **S5** | **dropped from tonight.** Flipping a default-open gate to default-closed before a release trades an unknown hole for a known outage, and buys nothing against internal testers. → cutover. |
> | **S6** | unchanged; still first to cut. |
>
> **This holds only while UAT stays UAT:** no real donor/beneficiary PII in the database, and
> sandbox payment credentials only. If either breaks, the security set is blocking again.
>
> Deferrals are recorded in [`PSS-2.0-PRODUCTION-CUTOVER-CHECKLIST.md`](../../PSS-2.0-PRODUCTION-CUTOVER-CHECKLIST.md).

## Before anything starts
**`pg_dump` the release database.** Everything below is reversible except a bad seed against unbacked data.

## Wave 1 — start all four now, in four separate sessions

| Session | Area | Repo | Est. | Why it can run in parallel |
|---|---|---|---|---|
| **S1** | Config & secrets — rotation, CORS allowlist, `Auth:PlatformHosts` | Backend | 1.5–2 h | sole owner of `appsettings.json` + `DependencyInjection.cs` |
| **S2** | Money paths — D-2 one-liner, `.svg` drop, email webhook signature | Backend | 45 m | donation/media files only; touches no config |
| **S3** | Frontend auth — `authorize()` server-verify, Member Portal route block | Frontend | 1 h | different repo entirely |
| **S4** | Withdraw non-shippable features — menu seed + grid actions | SQL + Frontend | 45 m | seed file + grid config only |

**Start S1 first** — it is the long pole and the only item that decides whether an open release is possible at all. The other three finish while it runs.

**The one coordination point:** S3 and S4 both touch Member Portal. S4 hides the **menu**; S3 blocks the **route** in root `middleware.ts`. Neither crosses into the other's file.

## Wave 2 — begin when S2 reports done

| Session | Area | Repo | Est. | Why it waits |
|---|---|---|---|---|
| **S5** | Authorization sweep — the default-open pipeline | Backend | 1.5 h | edits many handler files; would collide with S2 |
| **S6** | Residual defects — Phase 6 §9.3/§9.4, Contact `#18` | Both | flexible | lowest value; **cut this first if time runs short** |

S5 and S6 run in parallel with each other.

## Ordering rationale
Ranked by **blast radius ÷ cost**, then de-conflicted by file ownership.

- **S1 first** because it is the only true blocker on an open release and the only multi-hour item. Nothing else gates on it, so it should be burning while the cheap fixes land.
- **S2 before S5** purely for file ownership — S5's attribute sweep would otherwise collide with S2's handler edits. S2 is short, so the wait is short.
- **S6 last** because none of it is on a money or auth path. It is the designated casualty if the night runs out.
- **The four cheapest fixes total about 30 minutes** — CORS (S1), `.svg` (S2), the D-2 one-liner (S2), `Auth:PlatformHosts` (S1). If everything else fails, these four still ship.

## Common rules — every session
- **Never `git commit`. Stage only (`git add`), then report.** No push, amend, or tag.
- **Never** add `Co-Authored-By: Claude` or "Generated with Claude Code" to any commit message.
- The user builds the backend — **no `dotnet build`**.
- The user creates EF migrations — **no `ef migrations add`**, never edit `ModelSnapshot`. Hand off the intent.
- `BaseUrlConfig.ts` is user-managed. Never edit, stage, or revert it.
- Do not probe ports or API liveness. The user runs the API and reports failures.
- `PSS_2.0_Backend` and `PSS_2.0_Frontend` are **nested git repos** — stage from inside each. `git status` at the top level will not show their changes.
- Recursive `grep`/`rg` silently misses files inside those nested repos. An empty result is not proof of absence — enumerate with PowerShell `Select-String` over an absolute path.
- **Stay inside your session's file list.** Everything else is someone else's session right now.

## Two decisions already made — do not relitigate
- **Media upload stays anonymous.** Public donation and P2P pages depend on it. Only `.svg` is removed, which is what actually closes the XSS.
- **Recurring donations stay visible.** Only the manual **Retry** button is withdrawn — it is the part that fabricates a SUCCESS.

## Deliberately excluded from MVP-1
Dynamic subdomain · Phase 7 (registry, trigger layers, readiness widgets — only its D-2 defect ships) · the three-way `CompanyPaymentGateways` predicate drift · runtime acceptance suites for Phases 4, 5 and 6 · the remaining ~310 non-blocker audit findings.
