# Settings partition — session handoff (continue here)

Previous session executed `PSS-2.0-SETTINGS-PARTITION-EXECUTION-PROMPT.md` (§7 of
`PSS-2.0-SETTINGS-SCREEN-RECONCILIATION.md`) end to end. **All three steps are done and staged, not
committed.** Read the §Findings section of the execution prompt first — it holds the verdicts,
deviations and read-site checks; do not re-derive them.

## State as of 2026-08-03

| Repo | Branch | State |
|---|---|---|
| `PSS_2.0_Backend` | `module/case` | 8 settings files **staged**, uncommitted. Unstaged billing/plan work belongs to another task — leave it. |
| `PSS_2.0_Frontend` | `module/case` | 15 settings files **staged**, uncommitted. Unstaged: `BaseUrlConfig.ts` (local dev URL switch), `footer.tsx`, all `ops/plans` + `PlanDto` files — leave them. |
| outer `pwds-soruban` | `master` | 4 files staged: `orgsettings.md`, `companysettings.md`, `setting-groups.sql`, the execution prompt. Unstaged onboarding/billing prompts + `sql-scripts-dyanmic/*.sql` — leave them. |

Commit messages for BE and FE were drafted in the previous session's final message; regenerate if the
scrollback is gone. Backend #75 step-1 edits (`GetCompanySettings.cs`) were already swept into the
user's commit `cedcc30c`, so nothing is pending for that file.

`npx tsc --noEmit --incremental false` → exit 0. Backend compiled by **inspection only** — no
`dotnet build` was run.

## Rules still binding

- **No `dotnet build`**, **no migration** (tool or hand-authored), **no entity/column change**.
- **Seed SQL: write, never run.** User applies.
- Backend is gitignored → Grep/Glob return zero `.cs` hits. Use `find -iname` or scope
  `grep -rn --include=*.cs` to **one** project dir; repo-wide times out.
- `grep` `REGISTRY.md`, never `Read` it (~700KB).
- HotChocolate: `Get` stripped from resolvers, `Input` appended to input DTOs.

## Next, in order

1. **Commit the three staged sets** if the user approves. Nothing else in this task is blocked on it.
2. **E2E verify the partition against a running stack** (never done — the previous session had no
   build/run). Three checks:
   - #75 Company Settings: Communication / Security / Receipt sections gone; the new Organization
     section shows `AUDIT_TRAIL_RETENTION` + `MULTI_BRANCH_MODE`; save round-trips.
   - #85 Organization Settings: no branding/login/org/regional-identity codes; no empty group cards;
     `ALLOW_MULTI_CURRENCY` present, `DEFAULT_CURRENCY` absent.
   - `/setting/orgsettings/usersetting`: loads via `userSettingsView`, shows ThemeCustomizer + the 4
     notification codes, Import button hidden, save hits `bulkUpdateUserSettings`, blanking a field
     reverts to the org default. **GraphQL field names are the runtime risk** — tsc cannot see them.
3. **ISSUE-01 — `ResetOrganizationSettingsToDefaultsHandler` has no `CompanyId` filter**, so one
   tenant's reset clears every tenant's rows. Logged in `.claude/screen-tracker/prompts/orgsettings.md`
   § Known Issues. One predicate: `s.CompanyId == httpContextAccessor.GetCurrentUserStaffCompanyId()`.
   Ask before doing it — it was ruled out of scope, not forgotten.

## Deliberately parked (do not "fix" without a decision)

- The 8 §5B ParamCodes **stay** in the KV store — 0 of 8 destinations exist, and `TAX_SECTION`,
  `SHOW_TAX_INFO_ON_RECEIPT`, `AUTHORIZED_SIGNATORY` are read live by `DonationReceiptService`.
  The cleanup `DELETE` in `setting-groups.sql` is commented out with per-code verdicts inline,
  re-enableable one line at a time once #9 / #2 / #19 grow the fields.
- `DATA_RESIDENCY` stays on #85 (blueprint says #75, but #75 never writes it — moving it orphans it).
- `NOTIFICATION_RETENTION` is not user-overridable (retention policy, not preference).
- `ALLOWED_CURRENCIES` is seeded by `OrgSettingsDefaultSeeder.cs:208` though the blueprint says 0
  rows. Left alone — a seeder change is a data change.
- Out of scope entirely: building the absorbing fields on #9 / #2 / #19, #79 Currency Management,
  the number-sequence engine.
