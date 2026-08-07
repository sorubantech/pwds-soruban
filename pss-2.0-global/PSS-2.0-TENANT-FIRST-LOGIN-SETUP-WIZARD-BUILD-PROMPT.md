# Tenant First-Login Setup Wizard — activation, not data entry

> **Status:** NOT BUILT (written 2026-08-07)
> **Order:** after the entitlement repair + baseline regeneration land, because §④.2 reads `billing.PlanEntitlements`.
> **Prerequisite:** §③ needs a migration. Do not start the frontend before the migration is applied.
> **Scope discipline:** this prompt builds a 3-step wizard and a dashboard checklist. It does **not** build any settings editor — every task in the checklist deep-links to a screen that already exists.

---

## ⚠️ Standing rules (non-negotiable)

1. **Do NOT run `dotnet build`.** The user builds the backend.
2. **Migrations are strictly user-owned.** Never run `dotnet ef migrations add/remove` or `database update`. Never hand-author a migration or a snapshot. Produce the **migration spec** in §③; the user authors and applies it.
3. Seeds go to `sql-scripts-dyanmic/`. The user applies them.
4. Frontend typecheck: `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, **no pipe**. Only exit 0 counts.
5. `PSS_2.0_Backend/` and `PSS_2.0_Frontend/` are gitignored — Grep/Glob return nothing. Use `find -iname`, or scope `grep -rn --include=*.cs` to **one** project subdirectory. A repo-wide backend grep times out at 120 s. Absolute-path `Read` works.
6. HotChocolate strips `Get` from resolver names and appends `Input` to input types. tsc cannot see gql field names — a wrong name builds clean and fails only at runtime.
7. Every Postgres date column is `timestamp with time zone`. `DateTime.UtcNow` only; never `DateTime.Today` in an EF predicate.
8. `ops` / `billing` are platform-global: every read needs `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true` guard.
9. Never assume a GraphQL field, DTO property, or column name — read the source first.
10. Widget/KPI icon containers and status badges: solid `bg-X-600` + `text-white`. Never `bg-X-50/100`, `text-X-700/800`, or `bg-muted`.
11. No raw SQL in application code (`ExecuteSqlRawAsync` / `FromSqlRaw` / string-built SQL). `ExecuteUpdateAsync` / `ExecuteDeleteAsync` over a LINQ `IQueryable` are EF and are fine.
12. Amounts right-align in data contexts only. Tokens, not hex/px. `@iconify` Phosphor icons.

---

## §⓪ Verified facts — already confirmed in code, do not re-litigate

Read these before designing anything. Each one was checked on 2026-08-07 and each one removes work from the proposal.

| Fact | Evidence | Consequence for this build |
|---|---|---|
| Currency is derived from country at provisioning | `ProvisionTenant.cs` step 6b `AlignRegionalSettingsToCountryAsync` writes `DEFAULT_CURRENCY`, `ALLOWED_CURRENCIES`, `DEFAULT_COUNTRY` | Currency is **confirm-only** in the wizard. Never a blank select. Changing it is allowed but warned. |
| `TIME_ZONE`, `DATE_FORMAT`, `TIME_FORMAT`, `FINANCIAL_YEAR_START` are **not** written by provisioning | same file, `paramCodes` array is only the three above | These are the genuinely-missing values. They are the reason the wizard exists. |
| Company profile fields already exist and are populated | `Company.cs` — `CompanyName`, `Address`, `City`, `State`, `PostalCode`, `PrimaryEmail`, `PrimaryPhone`, `Website`, `TaxId`, `RegistrationNumber` | Step 1 is a **read-only confirmation card**, not a form. |
| `UpdateCompanySettingsCommand` is a whole-payload composite | `UpdateCompanySettings.cs` — takes `CompanySettingsRequestDto` covering every section | **Do not call it from the wizard.** A partial payload would clobber unset sections. Build the narrow command in §④.4. |
| ParamCode → SettingGroup registry already exists | `UpdateCompanySettings.ParamCatalog` | Reuse the same `(SettingGroupId, ParamName, DataType)` triples verbatim so #75 round-trips the wizard's writes. |
| Tenant goes ACTIVE on account activation, not provisioning | `Company.Status` comment in `Company.cs`; `OnboardedOn` stamped by AccountActivation | First login happens **after** `Status = 'ACTIVE'`. The wizard gate can rely on that. |
| Blob storage is not provisioned | grant attachments are URL-paste for this reason | **No logo/favicon/background upload anywhere in this build.** Branding is out of the wizard entirely. |
| Plan entitlements gate channels | `billing.PlanEntitlements`, codes `CHANNEL:EMAIL` / `CHANNEL:WHATSAPP` / `CHANNEL:SMS` | Channel tasks are `NOT_APPLICABLE` when the plan does not sell them. See §④.2. |

---

## §① The problem

A newly-provisioned tenant's primary admin sets a password and lands on an empty dashboard. Three things are true at that moment and none of them are visible to them:

1. **The tenant has no time zone, no date format and no financial-year start.** Every timestamp renders against a server default. Receipt dates — which are legally meaningful for tax — can be a day off.
2. **Nothing can send email.** No `CompanyEmailProvider` row exists, so every notification, receipt and campaign silently fails.
3. **There is no signal anywhere that any of this is unconfigured.** Not to the admin, not to the account manager, not to the platform.

The stakeholder ask was "show a setup wizard after first login." The ask is right. The specific design proposed is not, in three ways, and this prompt builds the corrected version.

### What was proposed vs what this builds

| Proposed | Built here | Why |
|---|---|---|
| 5 steps, ~40 fields | 3 steps, 5 editable fields | Completion falls off sharply past 4 steps and past ~6 fields per step. A 40-field wizard is a wizard people Skip. |
| Steps 1–2 re-collect company + org data | Step 1 confirms provisioned data read-only; step 2 collects only what is actually missing | Re-asking for data sales already captured reads as a broken handoff. |
| Step 3 branding (logo, favicon, login background, email branding) | **Cut entirely** | Branding is not activation, and every field in it needs blob storage that does not exist. |
| Appears once, then never again | Wizard once, then a **persistent dashboard checklist** until required tasks are done | This is the important correction. If every step is skippable *and* it never returns, the default outcome is a permanently unconfigured tenant with no surviving signal. |
| Everything skippable | Every *step* skippable. Three *fields* on step 2 are not. | Mandatory is chosen by **irreversibility**, not importance — see §②.2. |

---

## §② The design

### ②.1 Shape

```
Password set → login → BUSINESSADMIN?  ──no──→ dashboard (never sees any of this)
                            │yes
                            ▼
                Companies.SetupWizardCompletedDate IS NULL?
                            │yes                       │no
                            ▼                          ▼
                   redirect → /setup              dashboard
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
          Finish        Skip all      Partial
              └─────────────┴─────────────┘
                            ▼
                        dashboard
                            │
              Setup checklist card, visible until every
              required task is COMPLETED or SKIPPED
```

**Full page at `/setup`, not a modal.** A modal caps width, implies "small and dismissible", and cannot be deep-linked or driven by a Playwright test without owning app state on mount. A route is resumable, linkable and testable.

**The wizard is a read; the checklist is the source of truth.** The wizard renders the task rows; it does not own them. That is what makes "resume the wizard" an unnecessary concept — there is nothing to resume, because the checklist never went away.

### ②.2 Mandatory is chosen by irreversibility

> A field is mandatory in first-run setup **if and only if** changing it later, after transactional data exists, is expensive or impossible.

That test — not "how important is it" — gives the mandatory set:

| Field | Why it cannot wait |
|---|---|
| **Time zone** | Timestamps are stored UTC and rendered local. Wrong zone dates receipts a day off, and receipt dates are legally meaningful. |
| **Financial year start** | Every report period and YTD total re-buckets. Changing it after statements are issued invalidates them. |
| **Date format** | Cheap to change, but it is the third field in the same form and asking for it costs nothing. Include it as required; it is free. |

Currency passes the irreversibility test too — donations and FX snapshots store the rate **value** at write time, so a currency change after the first donation corrupts history. But it is already correct from provisioning, so it appears as a **confirmation with a warning**, not a required input.

Everything else fails the test and is therefore optional. Note what this excludes: email sender configuration is the single highest-value item in the whole feature — nothing sends until it exists — and it is still **not mandatory**, because the admin frequently cannot complete it at first login (it needs DNS records and credentials they do not have to hand). Blocking Finish on it would trap them on a page they cannot leave. It gets prompted hard on the checklist instead.

### ②.3 Task-grained, not step-grained

State is stored per **task**, not per wizard step. Three reasons, and the third is the one that matters:

1. A task can live on the checklist without ever being a wizard step (invite your team).
2. A task completed later through its real Settings screen must close itself without the wizard being involved (§④.6).
3. **`NOT_APPLICABLE`.** A `FREE` tenant cannot configure WhatsApp — the plan does not sell it. Without a per-task not-applicable state, that task sits `PENDING` forever and pins the checklist below 100% permanently. Step-grained state cannot express this.

### ②.4 Plan- and capability-gating

The task list is computed, not fixed. A task is `NOT_APPLICABLE` when the tenant's plan does not entitle it. This reuses exactly the entitlement read the RBAC baseline generator uses — `billing.PlanEntitlements` joined to the tenant's active subscription, `IsEnabled = true`, `IsDeleted IS DISTINCT FROM true`.

Capability gating is by **role code, not menu capability**: only `BUSINESSADMIN` is redirected and only `BUSINESSADMIN` sees the checklist. A staff user logging in first lands on the dashboard normally and never learns the wizard exists.

### ②.5 Rejected alternatives — do not re-propose

| Rejected | Why |
|---|---|
| Store wizard state in `sett.OrganizationSettings` | It is a tenant KV store already contested between screens #75 and #85. Per-task status with timestamps in KV rows is unqueryable — you could never answer "how many tenants stalled on email setup", which is the main reason to track this at all. |
| A single `IsFirstLogin` boolean on `User` | Goes stale the moment anything touches the row. Derive from `SetupWizardCompletedDate IS NULL` instead. |
| A dedicated "Review & Finish" step | A step that collects nothing is a step that costs completion. The review is a summary rail on step 3. |
| Reuse `UpdateCompanySettingsCommand` | Whole-payload composite. See §⓪. |
| A new menu + capability for `/setup` | It is not a menu item; it is a redirect target. A new capability would mean a new seed the user has to apply and a new way for the wizard to be invisible. Reuse `CompanySettings / Modify`. |
| Blocking Finish until email is configured | See §②.2. It traps the admin on a page they cannot complete. |

---

## §③ Schema — migration spec (user-owned, do NOT author)

Produce the spec; the user writes and applies the migration. Name it `Add_TenantSetupWizard`.

### ③.1 New table `sett."TenantSetupTasks"`

| Column | Type | Null | Notes |
|---|---|---|---|
| `TenantSetupTaskId` | `integer` identity | no | PK |
| `CompanyId` | `integer` | no | FK → `app."Companies"` |
| `TaskCode` | `text` | no | see §③.4 |
| `Status` | `text` | no | `PENDING` \| `COMPLETED` \| `SKIPPED` \| `NOT_APPLICABLE` |
| `IsRequired` | `boolean` | no | default `false` |
| `DisplayOrder` | `integer` | no | default `0` |
| `CompletedDate` | `timestamp with time zone` | yes | |
| `CompletedByUserId` | `integer` | yes | plain nullable int, **no FK** — mirrors `Company.AccountManagerUserId`; a hard constraint fights the tenant filter |
| `SkippedDate` | `timestamp with time zone` | yes | |
| standard audit | | | `IsActive`, `IsDeleted`, `CreatedDate`, `ModifiedDate` per `Entity` |

Unique index `("CompanyId", "TaskCode")` — **without** `IsDeleted` in the key, and rows here are never soft-deleted, only status-changed. Index `("CompanyId", "Status")` for the checklist read.

`Status` stays `text` with a check constraint rather than an enum column: the task vocabulary will grow, and an enum type migration for every new task code is friction with no payoff.

### ③.2 `app."Companies"` — two new nullable columns

| Column | Type | Null | Purpose |
|---|---|---|---|
| `SetupWizardCompletedDate` | `timestamp with time zone` | yes | `NULL` = wizard has never been finished or skipped. This is the login-gate read — one scalar, no join. |
| `SetupWizardVersion` | `integer` | yes | which task-set generation the tenant has seen |

`SetupWizardVersion` is the mechanism the original "never appears again" flag would have made impossible: when a new required task is added later, bump `CurrentSetupWizardVersion` in code and tenants below it get the wizard again showing only the new tasks. Without it, adding a task means a data migration or it never surfaces.

### ③.3 Backfill — mandatory, in the same migration

```
UPDATE app."Companies"
SET    "SetupWizardCompletedDate" = now(),
       "SetupWizardVersion" = 1
WHERE  "SetupWizardCompletedDate" IS NULL;
```

Every existing tenant is treated as already set up. Without this, every live tenant's admin gets ambushed by a setup wizard on their next login. No `TenantSetupTasks` rows are created for them — no rows means no checklist card, which is correct.

### ③.4 Task codes — the MVP set

| TaskCode | Where | Required | Entitlement gate | Deep link |
|---|---|---|---|---|
| `ORG_PROFILE_CONFIRM` | wizard step 1 | no | — | Company Settings (#75) |
| `ORG_LOCALE` | wizard step 2 | **yes** | — | Company Settings (#75) |
| `EMAIL_SENDER` | wizard step 3 | no | `CHANNEL:EMAIL` | Email provider config |
| `PAYMENT_GATEWAY` | wizard step 3 | no | — | Payment gateway config |
| `INVITE_TEAM` | checklist only | no | — | Staff / Users screen |
| `BRANDING` | checklist only | no | — | Company Settings (#75) §3 |
| `WHATSAPP_SENDER` | checklist only | no | `CHANNEL:WHATSAPP` | provider config |
| `SMS_SENDER` | checklist only | no | `CHANNEL:SMS` | provider config |

Exactly one task is required. That is the point.

### ③.5 Verify before building

```sql
SELECT column_name, data_type, is_nullable
FROM   information_schema.columns
WHERE  table_schema = 'app' AND table_name = 'Companies'
  AND  column_name IN ('SetupWizardCompletedDate','SetupWizardVersion');

SELECT to_regclass('sett."TenantSetupTasks"');
```

Fewer than two rows, or a null `to_regclass`, means the migration has not been applied. **Stop.** A mapped property with no column throws on every EF read of `app."Companies"` — which is the login path.

---

## §④ Backend

Everything lands under `Base.Application/Business/SettingBusiness/TenantSetup/`. Follow the folder shape of `SettingBusiness/CompanySettings/` — `Commands/`, `Queries/`, DTOs in `Base.Application/Schemas/SettingSchemas/`.

### ④.1 Domain + EF config

`Base.Domain/Models/SettingModels/TenantSetupTask.cs`, `[Table("TenantSetupTasks", Schema = "sett")]`, inheriting `Entity` like `OrganizationSetting.cs` does. Add the EF configuration alongside `OrganizationSettingConfiguration.cs` and register it the same way. Add `ICollection<TenantSetupTask>? TenantSetupTasks` to `Company.cs` next to `OrganizationSettings`, and the two scalar columns from §③.2.

### ④.2 `ITenantSetupService` — the task-set resolver

Interface in `Base.Application/Interfaces/`, implementation beside the handlers, registered in DI. Match the registration shape of `IOrgSettingsService` — read that file first.

One method that matters: **materialise the task set for a company.** Idempotent. For each code in the §③.4 catalog:

- resolve applicability from the tenant's active subscription → plan → `billing.PlanEntitlements`. Remember `billing` is platform-global: `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true`.
- a task whose gate is not entitled is written `NOT_APPLICABLE`, not skipped and not omitted. It must exist as a row so the completion maths is stable if the tenant upgrades later.
- a task that already exists keeps its `Status` **unless** it is `NOT_APPLICABLE` and the plan now entitles it — in which case it moves to `PENDING`. That is the upgrade path, and it is the only transition this method is allowed to make to an existing row.
- never move a `COMPLETED` or `SKIPPED` row back to `PENDING`.

Call it from **`ProvisionTenant` step 9** (`Step9_FinalizeAsync`), so the rows exist before the admin ever logs in and the wizard is a pure read. Step 9 is already the finalise step and already resolves the plan. Guard it the way the other step-9 work is guarded — a failure here must not fail provisioning; log and continue, and let §④.3 self-heal.

### ④.3 `GetTenantSetup` query — resolver field `tenantSetup`

Returns the wizard/checklist payload for the calling tenant: `setupWizardCompletedDate`, `setupWizardVersion`, `currentVersion`, and the task list (`taskCode`, `status`, `isRequired`, `displayOrder`, plus a UI-facing `title`/`description`/`deepLink` resolved server-side from the catalog).

**Self-heal:** if the company has zero task rows and `SetupWizardCompletedDate IS NULL`, call §④.2 before projecting. This is what makes a tenant provisioned before this build still work, and what covers the step-9 failure path.

Tenant-scoped from `HttpContext` `CompanyId`. Ignore any client-supplied company id.

### ④.4 `CompleteTenantSetupStep` — the narrow write

`CompleteTenantSetupStepCommand(TenantSetupStepRequestDto request)`. HotChocolate will expose `completeTenantSetupStep` with input `TenantSetupStepRequestDtoInput`.

`[CustomAuthorize(DecoratorSettingModules.CompanySettings, Permissions.Modify)]` — reuse, no new capability seed.

Payload is one `taskCode` plus the fields that task owns. For `ORG_LOCALE` that is `timeZone`, `dateFormat`, `financialYearStart`, `timeFormat?`, `defaultLanguage?`.

Write path: upsert `sett.OrganizationSettings` per ParamCode using the **same** `(SettingGroupId, ParamName, DataType)` triples as `UpdateCompanySettings.ParamCatalog`, and the same value forms — MasterData FK ids resolve back to `DataName`, currency to `CurrencyCode`, country to `CountryName`. Writing an id where #75 expects a name renders as a blank select on the settings screen; that is the single most likely defect in this build.

Then set the task row `Status = 'COMPLETED'`, `CompletedDate = DateTime.UtcNow`, `CompletedByUserId` from the caller. Call `IOrgSettingsService.InvalidateCompany` after the write.

Validate: `ORG_LOCALE` rejects a missing time zone, date format or financial-year start with a field-level error. Every other task code accepts a body-less complete.

### ④.5 `SkipTenantSetupStep` and `FinishTenantSetup`

`skipTenantSetupStep` — sets `Status = 'SKIPPED'`, `SkippedDate = DateTime.UtcNow`. Refuses a task with `IsRequired = true` (error code `SETUP_TASK_REQUIRED`). The UI hides Skip on required steps; this is the server-side twin, not a duplicate.

`finishTenantSetup` — stamps `Companies.SetupWizardCompletedDate = DateTime.UtcNow` and `SetupWizardVersion = CurrentSetupWizardVersion`. Refuses if any `IsRequired` task is still `PENDING`. This is also the "Skip all" target: skipping the whole wizard still has to satisfy the one required task, which is the entire mechanism by which the mandatory set is enforced.

`CurrentSetupWizardVersion` is a `const int = 1` in the service. One definition, referenced everywhere.

### ④.6 Auto-close from the real Settings screens

When `UpdateCompanySettingsHandler` writes `TIME_ZONE`, `DATE_FORMAT` and `FINANCIAL_YEAR_START` to non-empty values, close `ORG_LOCALE` if it is `PENDING`. Same for the email-provider create path closing `EMAIL_SENDER`, and the gateway create path closing `PAYMENT_GATEWAY`.

Without this the checklist lies: an admin who skips the wizard, goes to Settings and configures everything properly still sees "1 of 6 done" forever, which trains them to ignore the card. Implement it as one call into `ITenantSetupService` — do not scatter status writes across handlers.

---

## §⑤ Audit

`TenantSetupTask` status transitions only. Domain events beside `OrganizationSettingEvents/`: created, completed, skipped. Do not version field values here — `OrganizationSettings` already owns that history and duplicating it produces two answers to one question.

`CompletedByUserId` is the accountability record: who finished setup for this tenant.

---

## §⑥ Frontend

### ⑥.1 Route and gate

`/setup`, in the authenticated app but **without the sidebar and topbar chrome** — verify how the existing route groups are structured before choosing where the file lives; do not invent a new group if one already fits.

The gate belongs wherever post-login redirect is already decided (find it; there is already logic choosing the landing route). Conditions, all three: role code is `BUSINESSADMIN`, `setupWizardCompletedDate` is null, `setupWizardVersion` is null or below `currentVersion`. Anything else falls through to the normal landing route.

Guard against a redirect loop: `/setup` itself must never re-trigger the gate.

### ⑥.2 The wizard

Three steps. Header shows **"Step 2 of 3"** plus a segmented progress bar — never a percentage. Welcome panel states "About 2 minutes."

| Step | Content |
|---|---|
| 1 — Confirm your organization | Read-only summary card: name, address, contact, website, tax id, country, **currency**. One "Edit in Settings" link opening #75 in a new tab. Currency carries a short warning that it is difficult to change once donations exist. |
| 2 — Localisation & financial year | The only form. Time zone, date format, financial year start (required); time format, language (optional). Selects sourced from the same MasterData the #75 screen uses — read that screen's query before writing new ones. |
| 3 — Start sending | Two action cards: email sender, payment gateway. Each shows configured / not configured and links out. A summary rail on the right lists steps 1–2 so there is no fourth review step. |

Buttons: `Back` · `Skip for now` (text button) · `Continue` (primary). Skipping is available, not attractive. On the last step `Continue` becomes `Finish`. `Skip for now` is **hidden on step 2** — required.

Autosave on every step transition via `completeTenantSetupStep` / `skipTenantSetupStep`. Never hold three steps of state and commit at the end.

Steps whose tasks are all `NOT_APPLICABLE` are not rendered and do not count toward "of 3".

### ⑥.3 The checklist widget

A dashboard card, `BUSINESSADMIN` only, visible while any task is `PENDING`. Per §⑥ house rules the icon containers are solid `bg-X-600` + `text-white`.

- Progress counts `COMPLETED` over (`total` − `NOT_APPLICABLE`). A `FREE` tenant reaching 100% without ever touching WhatsApp is the correctness test for this line.
- Each row: title, status chip, deep link to the owning Settings screen.
- `SKIPPED` rows stay visible with a muted chip and remain re-completable — skipping is deferral, not refusal.
- A `Dismiss` action hides the card permanently once every required task is closed; while a required task is `PENDING`, `Dismiss` is not offered.
- Shaped skeletons while loading; an explicit empty state.

### ⑥.4 Responsive + tokens

xs→xl. Tokens only, no hex or px. Wizard content column caps around `max-w-3xl` and centres — a full-bleed 5-field form on a wide monitor reads as unfinished.

---

## §⑦ Explicitly NOT in this prompt

- Any branding upload — logo, favicon, login background, email branding. Blocked on blob storage.
- Any new Settings editor. Every deep link targets a screen that already exists.
- Working days / business hours / language allow-lists / number sequences / RBAC / notification templates. All entity- or policy-scoped, all Configure-Later.
- Non-admin onboarding, product tours, tooltips.
- A "reopen the wizard" entry point in Settings. The checklist replaces it.
- Any change to `UpdateCompanySettingsCommand`'s payload shape. §④.6 adds a service call, nothing more.
- A platform-side setup-completion report. Wanted, but a separate prompt — the data model here supports it.

---

## §⑧ Acceptance

1. Migration applied; §③.5 returns two columns and a non-null `to_regclass`.
2. Every pre-existing tenant has `SetupWizardCompletedDate` non-null and sees no wizard and no checklist card.
3. A freshly provisioned tenant has `TenantSetupTasks` rows before first login, written by step 9.
4. A `FREE` tenant's `WHATSAPP_SENDER` and `SMS_SENDER` rows are `NOT_APPLICABLE`; a `PLAN_100K` tenant's are `PENDING`.
5. BUSINESSADMIN first login redirects to `/setup`. A staff user's first login does not.
6. Step 1 renders provisioned company data read-only, with a non-empty currency.
7. Step 2 refuses Continue with any of the three required fields blank, and shows no Skip button.
8. Completing step 2 writes `TIME_ZONE`, `DATE_FORMAT`, `FINANCIAL_YEAR_START` to `sett.OrganizationSettings`, and **screen #75 renders those exact values in its selects** — not blanks. This is the round-trip test; a value written as an id instead of a name fails here and nowhere else.
9. Skip on step 3 sets `SKIPPED` and advances. Finish stamps `SetupWizardCompletedDate` and `SetupWizardVersion = 1`.
10. `finishTenantSetup` is refused while `ORG_LOCALE` is `PENDING`, error `SETUP_TASK_REQUIRED`.
11. After Finish, reloading the app lands on the dashboard, not `/setup`.
12. The checklist card shows on the dashboard with correct progress, and `NOT_APPLICABLE` tasks are excluded from the denominator.
13. Configuring an email provider through its own Settings screen flips `EMAIL_SENDER` to `COMPLETED` without the wizard being involved (§④.6).
14. Once every required task is closed, Dismiss hides the card and it does not return.
15. Frontend typecheck exits 0 under `npx tsc --noEmit --incremental false`.

---

## §⑨ Open questions

**Q1 — is `SetupWizardCompletedDate` per company or per user?**
Built as **per company** (it is a tenant fact, not a personal one). Consequence: the second admin invited to the tenant never sees the wizard. That is usually right and occasionally surprising. Say so if you want it per user; it changes §③.2 only.

**Q2 — should `PAYMENT_GATEWAY` be entitlement-gated?**
Currently ungated — there is no `FEATURE:` code for payments in the curated 17. If gateways should be plan-restricted, that is a new feature code and a change to the curated vocabulary, which is a separate decision (features are curated, never derived).

**Q3 — deep-link targets.**
§③.4 names the screens by function, not route. Confirm the actual routes for email-provider config, payment-gateway config and the staff/users screen before wiring the links, or the checklist ships with dead links that nothing type-checks.

**Q4 — is there an existing post-login redirect decision point?**
There must be, but it was not located during planning. Find it before writing §⑥.1; adding a second redirect authority is how login loops get built.

---

## §⑩ Build log

_(append per session: what landed, what deviated from this prompt and why, known issues)_
