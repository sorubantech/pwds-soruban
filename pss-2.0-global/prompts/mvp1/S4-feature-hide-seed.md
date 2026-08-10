# S4 — Withdraw Non-Shippable Features (Seed + FE)

**Wave 1 · run in parallel with S1, S2, S3 · ~45 min**
**Repos:** `pss-2.0-global/sql-scripts-dyanmic` (seed) and `PSS_2.0_Frontend` (grid actions)

## Standing rules for this session
- **Never `git commit`.** Stage only (`git add`) and report. No push, amend, or tag.
- No `Co-Authored-By: Claude` / "Generated with Claude Code" lines in any commit message you draft.
- **PostgreSQL, not SQL Server.** `now()`, double-quoted identifiers, `TRUE`/`FALSE`, `WHERE NOT EXISTS`, `LIMIT 1`.
- **The seed must be idempotent** and re-runnable.
- **No migration.** No new columns. This is data-level configuration only.
- Do not touch `middleware.ts` — S3 owns the Member Portal route block.

## Why this session exists
Each feature below reports success while doing nothing. Shipping them visible is worse than shipping without them: a refund that says "complete" and moves no money is a finance incident, not a missing feature.

## What gets hidden

| Feature | Reason | Action |
|---|---|---|
| **Refunds** (`#41`, `#53`) | never calls the gateway; born "complete"; mutates the ledger with no money moving | hide menu **and** the per-row Refund action |
| **Recurring-donation manual Retry** (`#39`) | fabricates a SUCCESS, increments counts, contacts no processor | **hide the Retry button only** |
| **Scheduled Reports** (`#10`) | no execution engine; runs stick on RUNNING forever | hide menu |
| **Custom Report Builder** (`#61`) | preview / run / export all fabricated | hide menu |
| **Member Portal** (`#86`) | "auth" is a localStorage check | hide menu (S3 blocks the route) |

## ⚠️ Recurring donations stay — read this twice
**Do not hide the recurring-donation feature.** It is a headline MVP-1 capability and it is being kept. Only the **manual Retry action** is withdrawn. If your change hides the recurring donation menu, list, or subscription flow, you have overshot — revert and narrow.

## How to hide

**Sidebar visibility and grid capability are different mechanisms** — you need both, and they are not interchangeable:
- **Sidebar** = the `ISMENURENDER` role grant. Set it to `false`.
- **Keep `Menu.IsActive = true`.** Setting it false disables the grid's capability resolution and can break shared grids. Hide via `ISMENURENDER`.
- **Grid row actions** (Refund, Retry) are frontend action configuration — remove the action from the grid config. **Do not fork the shared grid component.** Every screen uses `FlowDataTable` / `AdvancedDataTable`; the action goes out of the config, not into a new component.

Deliver `sql-scripts-dyanmic/seed_mvp1_feature_hide.sql`. Leave every row in place — MVP-2 flips them back, so nothing is deleted.

## Acceptance
- [ ] The five entries above are absent from the sidebar for all roles including BUSINESSADMIN
- [ ] Recurring donations remain fully visible and usable; only Retry is gone
- [ ] Refund action absent from the donation grid rows
- [ ] Seed re-runs cleanly a second time with no duplicate rows and no error
- [ ] No shared grid component was forked

## Out of scope
`middleware.ts` (S3). Any backend C# file. Any migration.

## Report back
The exact list of menu codes touched, so it can be reversed in one statement for MVP-2.
