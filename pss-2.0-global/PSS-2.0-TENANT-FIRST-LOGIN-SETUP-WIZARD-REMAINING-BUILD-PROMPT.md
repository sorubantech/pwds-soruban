# PSS 2.0 — Tenant First-Login Setup Wizard — REMAINING BUILD PROMPT

**Status:** NOT_STARTED (behavioural layers)
**Parent spec:** `PSS-2.0-TENANT-FIRST-LOGIN-SETUP-WIZARD-BUILD-PROMPT.md`
**Scope of this prompt:** everything the parent spec asks for that is **not on disk**, plus one defect fix in the code that *is* on disk.
**Do not re-read the parent spec for instructions** — everything you need is restated here, grounded in code verified on disk on 2026-08-07. Where this prompt and the parent disagree, **this prompt wins**.

---

## ⓪ What is already built — DO NOT rebuild

Verified on disk. Treat these as fixed API surface; consume them, do not modify them (except §① below).

| Artefact | Path | State |
|---|---|---|
| `TenantSetupTask` entity | `Base.Domain/Models/SettingModels/TenantSetupTask.cs` | built |
| EF configuration | `Base.Infrastructure/Data/Configurations/SettingConfigurations/TenantSetupTaskConfiguration.cs` | built |
| `ISettingDbContext` / `SettingDbContext` DbSet | — | wired |
| `Company.SetupWizardCompletedDate` (line 72), `Company.SetupWizardVersion` (line 77), `Company.TenantSetupTasks` | `Base.Domain/Models/ApplicationModels/Company.cs` | built |
| Migration | `Base.Infrastructure/Migrations/20260807045628_Add_TenantSetupTask.cs` | built, **backfill missing → see §①** |

Entity shape you must code against (exact names):

```csharp
[Table("TenantSetupTasks", Schema = "sett")]
public class TenantSetupTask : Entity
{
    public int TenantSetupTaskId { get; set; }
    public int CompanyId { get; set; }
    public string TaskCode { get; set; } = default!;   // varchar(60)
    public string Status { get; set; } = default!;     // varchar(20), CHECK: PENDING|COMPLETED|SKIPPED|NOT_APPLICABLE
    public bool IsRequired { get; set; }
    public int DisplayOrder { get; set; }
    public DateTime? CompletedDate { get; set; }
    public int? CompletedByUserId { get; set; }        // plain nullable int — NO navigation, NO FK
    public DateTime? SkippedDate { get; set; }
    public Company Company { get; set; } = default!;

    public static TenantSetupTask Create(int companyId, string taskCode, string status, bool isRequired, int displayOrder);
    public static void Validate(IList<TenantSetupTask> list);
}
```

Indexes already present: unique `IX_TenantSetupTasks_CompanyId_TaskCode`, non-unique `IX_TenantSetupTasks_CompanyId_Status`. FK to `app.Companies` is `Restrict`.

**Query filter warning:** the global `CompanyId` filter applies to `TenantSetupTask`. Provisioning (§④.2 hook) runs in **platform context with no ambient tenant**, so every read/write there must use `.IgnoreQueryFilters()`. Tenant-context reads (queries/mutations in §④.3–④.6) must **not**.

---

## ① DEFECT FIX — the migration backfill (do this FIRST)

`20260807045628_Add_TenantSetupTask.cs` adds `SetupWizardCompletedDate` and `SetupWizardVersion` as **NULL for every existing tenant** and never runs the parent spec's §③.3 backfill.

**Consequence if unfixed:** the moment §⑥'s login gate ships, *every existing tenant admin* — including live tenants — is thrown into the wizard on next login. Acceptance #2 fails. Today the columns are inert only because nothing reads them.

**Migrations are user-owned.** Do not author, edit, or run a migration. Instead:

Write `sql-scripts-dyanmic/tenant-setup-wizard-existing-tenant-backfill.sql`. One file, executable as-is, no optional blocks:

```sql
-- Existing tenants predate the setup wizard. Mark them completed so the
-- first-login gate never ambushes them. New tenants are stamped NULL at
-- provisioning and are the only ones the wizard should ever catch.
UPDATE app."Companies"
SET    "SetupWizardCompletedDate" = now(),
       "SetupWizardVersion"       = 1
WHERE  "SetupWizardCompletedDate" IS NULL;

-- RESULT 1 — expect 0 rows after the update.
SELECT COUNT(*) AS companies_still_null
FROM   app."Companies"
WHERE  "SetupWizardCompletedDate" IS NULL;

-- RESULT 2 — expect the table to exist and be empty on a fresh install.
SELECT COUNT(*) AS tenant_setup_task_rows
FROM   sett."TenantSetupTasks";
```

**Pre-build gate:** the user must confirm RESULT 1 returns `0` before §⑥ ships. Do not ship the FE gate until they do. §④ is safe to land beforehand.

---

## ② Missing constants — create these (referenced by existing comments, do not exist)

`Base.Domain/Constants/` (match the folder convention used by sibling constant classes — search for an existing `*Codes.cs` under `Base.Domain` and place these alongside it).

```csharp
public static class TenantSetupTaskCodes
{
    public const string OrgProfileConfirm = "ORG_PROFILE_CONFIRM";
    public const string OrgLocale         = "ORG_LOCALE";
    public const string EmailSender       = "EMAIL_SENDER";
    public const string PaymentGateway    = "PAYMENT_GATEWAY";
    public const string InviteTeam        = "INVITE_TEAM";
    public const string Branding          = "BRANDING";
    public const string WhatsAppSender    = "WHATSAPP_SENDER";
    public const string SmsSender         = "SMS_SENDER";
}

public static class TenantSetupTaskStatus
{
    public const string Pending       = "PENDING";
    public const string Completed     = "COMPLETED";
    public const string Skipped       = "SKIPPED";
    public const string NotApplicable = "NOT_APPLICABLE";
}

public static class TenantSetupConstants
{
    public const int CurrentSetupWizardVersion = 1;
}
```

Use these constants everywhere. No string literals for task codes or statuses outside these classes.

---

## ③ The task catalog (authoritative)

| Order | TaskCode | Surface | Required | Entitlement gate | Deep link (FE) |
|---|---|---|---|---|---|
| 1 | `ORG_PROFILE_CONFIRM` | wizard step 1 | no | — | `/organization/organizationsetup/company` |
| 2 | `ORG_LOCALE` | wizard step 2 | **yes** | — | `/organization/organizationsetup/company` |
| 3 | `EMAIL_SENDER` | wizard step 3 | no | `CHANNEL:EMAIL` | `/setting/communicationconfig/emailproviderconfig` |
| 4 | `PAYMENT_GATEWAY` | wizard step 3 | no | — | `/setting/paymentconfig/companypaymentgateway` |
| 5 | `INVITE_TEAM` | checklist only | no | — | `/organization/staff/staff` |
| 6 | `BRANDING` | checklist only | no | — | `/organization/organizationsetup/company` |
| 7 | `WHATSAPP_SENDER` | checklist only | no | `CHANNEL:WHATSAPP` | `/setting/communicationconfig/whatsappsetup` |
| 8 | `SMS_SENDER` | checklist only | no | `CHANNEL:SMS` | `/setting/communicationconfig/smssetup` |

Deep links are **verified route paths on disk** (2026-08-07). Prefix with the active locale at render time (`/${lang}/...`) — the app is locale-prefixed by root `middleware.ts`.

"Checklist only" = never blocks the wizard; appears in the dashboard checklist widget (§⑥.4) so the tenant can finish it later.

---

## ④ Backend

### ④.1 `ITenantSetupService` — new

`Base.Application/Interfaces/ITenantSetupService.cs`, implementation in `Base.Infrastructure/Services/Setting/TenantSetupService.cs`. Register in DI beside the other `Base.Infrastructure` service registrations (scoped).

```csharp
public interface ITenantSetupService
{
    /// Idempotent. Creates any missing task rows for the company and reconciles
    /// entitlement-gated rows. Safe to call repeatedly.
    Task MaterialiseAsync(int companyId, bool platformContext, CancellationToken ct = default);

    /// Marks a task COMPLETED if it exists and is not already COMPLETED.
    /// No-op when the task is absent or NOT_APPLICABLE. Never throws.
    Task AutoCompleteAsync(int companyId, string taskCode, CancellationToken ct = default);
}
```

**Materialiser rules — these are the correctness core:**

1. Read existing rows for the company (`IgnoreQueryFilters()` when `platformContext: true`).
2. For each of the 8 catalog codes, resolve its target status:
   - ungated codes → `PENDING`
   - gated codes → `PENDING` if `await entitlements.HasFeatureAsync(companyId, "<CHANNEL:...>")`, else `NOT_APPLICABLE`
3. **Missing row** → insert via `TenantSetupTask.Create(...)` with the target status, `IsRequired` and `DisplayOrder` from §③.
4. **Existing row** → the **only** permitted transition is `NOT_APPLICABLE → PENDING` (tenant upgraded their plan and the channel became available).
   - Never move `COMPLETED` or `SKIPPED` back to `PENDING`.
   - Never move `PENDING` → `NOT_APPLICABLE` (a downgrade must not erase a pending task; leave it and let the enforcement layer refuse the action).
   - Never touch `CompletedDate` / `SkippedDate` / `CompletedByUserId` here.
5. Call `TenantSetupTask.Validate(list)` before save.
6. Single `SaveChangesAsync`. No raw SQL — **`ExecuteSqlRawAsync` / `FromSqlRaw` / string-built SQL are forbidden in application code.**

**Entitlement dependency — use `IEntitlementService`, not a hand-rolled `billing.PlanEntitlements` query.** Verified contract at `Base.Application/Interfaces/IEntitlementService.cs`:

```csharp
Task<bool> HasFeatureAsync(int companyId, string featureCode, CancellationToken ct = default);
```

It is already fail-closed (no active subscription → `Status = "None"`, empty feature map, returns `false`, never throws) and cached ~60 s, and it removes the `IgnoreQueryFilters()` burden on `billing.*` from your new service. Its XML doc still says "MODULE:\* / CHANNEL:\*" — stale wording predating the `MODULE:` → `FEATURE:` rename; the `CHANNEL:` codes this wizard needs are unaffected.

### ④.2 Provisioning hook

`Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs`.

`Step9_FinalizeAsync` (around line 1530, dispatched from `case 9:` at line 422) is now finalize-only — it stamps `ops.Lead.ConvertedCompanyId` and sends nothing. Add the materialiser call **after** `StampLeadConversionAsync` and **before** the completion log:

```csharp
try
{
    await _tenantSetup.MaterialiseAsync(companyId, platformContext: true, ct);
}
catch (Exception ex)
{
    _logger.LogError(ex,
        "Tenant provisioning run {RunId}: setup-task materialisation failed for company {CompanyId}. " +
        "Provisioning continues; the first tenantSetup query will self-heal.", run.RunId, companyId);
}
```

Guarded on purpose: a wizard-checklist failure must never fail or pause a provisioning run. §④.3's self-heal is the safety net.

New tenants must be left with `SetupWizardCompletedDate = NULL` and `SetupWizardVersion = NULL` — that is already the DB default; **do not stamp them at provisioning.** Only `finishTenantSetup` (§④.5) stamps.

### ④.3 Query — `GetTenantSetup`

New CQRS query under `Base.Application/Business/SettingBusiness/TenantSetup/Queries/GetTenantSetupQuery/`.

- HotChocolate strips `Get` → the GraphQL field is **`tenantSetup`**. Do not add `[GraphQLName]`.
- Tenant scoping: `var companyId = httpContextAccessor.GetCurrentUserStaffCompanyId();` — ignore any CompanyId on the payload.
- **Self-heal:** if zero rows exist for the company, call `MaterialiseAsync(companyId, platformContext: false, ct)` then re-read. This covers tenants provisioned before this build and any run where §④.2's guarded call failed.
- Authorization: any authenticated staff user of the tenant may read. Do not gate behind a capability — the wizard must be reachable by a brand-new tenant admin before they have configured anything.

Result DTO:

```csharp
public record TenantSetupResultDto(
    bool   IsSetupComplete,          // Company.SetupWizardCompletedDate != null
    int?   SetupWizardVersion,
    int    CompletedCount,           // COMPLETED only
    int    ApplicableCount,          // excludes NOT_APPLICABLE
    bool   HasPendingRequired,       // any IsRequired && Status == PENDING
    IReadOnlyList<TenantSetupTaskDto> Tasks);

public record TenantSetupTaskDto(
    string    TaskCode,
    string    Status,
    bool      IsRequired,
    int       DisplayOrder,
    DateTime? CompletedDate,
    DateTime? SkippedDate);
```

Order by `DisplayOrder`. Do **not** return `NOT_APPLICABLE` rows filtered out — return them; the FE decides what to hide, and the checklist widget needs the count to be honest.

### ④.4 Mutation — `CompleteTenantSetupStep`

New command under `Base.Application/Business/SettingBusiness/TenantSetup/Commands/CompleteTenantSetupStepCommand/`.

Input `TenantSetupStepRequestDto` → GraphQL input type **`TenantSetupStepRequestDtoInput`** (HotChocolate appends `Input`).

```csharp
public record TenantSetupStepRequestDto(
    string TaskCode,
    string? DefaultTimezoneId,       // MasterData id
    string? DateFormatId,            // MasterData id
    string? TimeFormatId,            // MasterData id
    string? FinancialYearStartId,    // MasterData id
    string? DefaultLanguageId);      // MasterData id
```

Behaviour by `TaskCode`:

- **`ORG_LOCALE`** — write the locale settings, then mark the task COMPLETED.
- **`ORG_PROFILE_CONFIRM`** — no writes; mark COMPLETED (the tenant is confirming what provisioning already set).
- Any other code → reject with `SETUP_TASK_NOT_INTERACTIVE`.

**⚠ The round-trip hazard — read this before writing a single line.**

`sett.OrganizationSettings` stores **display names, not ids**. `UpdateCompanySettings.cs` resolves every MasterData FK id back to its `DataName` before upserting. If you write an id where Company Settings (#75) expects a name, the settings screen renders a **blank select** and the bug surfaces only at acceptance #8.

Reuse the exact `(SettingGroupId, ParamName, DataType)` triples from `UpdateCompanySettings.cs` (`SG_Organization = 6`):

| ParamCode | SettingGroupId | ParamName | DataType | MasterData TypeCode |
|---|---|---|---|---|
| `TIME_ZONE` | 6 | `Time Zone` | `SELECT` | `TIMEZONE` |
| `DATE_FORMAT` | 6 | `Date Format` | `SELECT` | `DATEFORMAT` |
| `TIME_FORMAT` | 6 | `Time Format` | `SELECT` | `TIMEFORMAT` |
| `FINANCIAL_YEAR_START` | 6 | `Financial Year Start` | `SELECT` | `FINANCIALYEARSTARTMONTH` |
| `DEFAULT_LANGUAGE` | 6 | `Default Language` | `SELECT` | — (name as stored by #75) |

Copy the resolution idiom verbatim from `UpdateCompanySettings.cs`:

```csharp
Upsert(existingByCode, companyId, "TIME_ZONE", mdNamesById.Get(dto.DefaultTimezoneId));
```

Do **not** duplicate the `Upsert` / `MdNameResolver` helpers by copy-paste if you can extract them — but if extraction risks touching `UpdateCompanySettings.cs`'s behaviour, prefer a private copy in the new handler over refactoring a live screen's handler. Correctness beats DRY here.

After a successful save: `orgSettings.InvalidateCompany(companyId);` — same as `UpdateCompanySettings.cs` line 208. Skipping this leaves the tenant on a stale cached locale.

Validation: `ORG_LOCALE` requires all five ids non-null (it is the one required task). Reject with a field-level validation error, not a generic 500.

Task update: set `Status = COMPLETED`, `CompletedDate = DateTime.UtcNow`, `CompletedByUserId = <current user id>`. **UTC only** — every Postgres date column is `timestamp with time zone` and Npgsql throws on `Kind=Unspecified`.

Idempotent: completing an already-`COMPLETED` task is a success no-op, not an error.

### ④.5 Mutations — `SkipTenantSetupStep` / `FinishTenantSetup`

GraphQL fields: `skipTenantSetupStep`, `finishTenantSetup` (no `Get` prefix to strip).

**`skipTenantSetupStep(taskCode)`**
- If the task `IsRequired` → reject with error code **`SETUP_TASK_REQUIRED`** and a message naming the step. The FE surfaces this as an inline error on the step, not a toast-and-continue.
- Otherwise `Status = SKIPPED`, `SkippedDate = DateTime.UtcNow`. Idempotent.
- `NOT_APPLICABLE` tasks cannot be skipped — they are already out of scope; return success no-op.

**`finishTenantSetup()`**
- Guard: if any task has `IsRequired == true && Status == PENDING` → reject with **`SETUP_TASK_REQUIRED`**. This is the server-side twin of the FE's disabled Finish button; the FE guard is convenience, this one is the rule.
- Stamp `Company.SetupWizardCompletedDate = DateTime.UtcNow` and `Company.SetupWizardVersion = TenantSetupConstants.CurrentSetupWizardVersion`.
- Idempotent: already-complete → success no-op, do not re-stamp the date.

Both mutations scope via `GetCurrentUserStaffCompanyId()`.

### ④.6 Auto-close hooks

When a tenant completes a setup task **outside** the wizard (via the real screen), the checklist must reflect it. Route every hook through **one** call — `ITenantSetupService.AutoCompleteAsync(companyId, taskCode, ct)` — never scattered inline `TenantSetupTask` writes.

| Hook site | Task to auto-complete |
|---|---|
| Company settings saved with all five locale params present (`UpdateCompanySettings` handler, after `SaveChanges`) | `ORG_LOCALE` |
| Company branding saved | `BRANDING` |
| A `CompanyEmailProvider` row is created/activated | `EMAIL_SENDER` |
| A `CompanyPaymentGateway` row is created/activated | `PAYMENT_GATEWAY` |
| A staff user other than the tenant admin is created/invited | `INVITE_TEAM` |
| WhatsApp sender config saved | `WHATSAPP_SENDER` |
| SMS sender config saved | `SMS_SENDER` |

`AutoCompleteAsync` must never throw into the host handler — wrap its body, log on failure, return. A checklist bookkeeping failure must not roll back a settings save. Do not add it inside the host's transaction if that risks the host's `SaveChanges`; call it after.

**Verify each hook site's real handler name and file path before editing** — do not assume. Backend is gitignored, so Grep returns zero; use `find -iname` or scope `grep -rn --include=*.cs` to one project subdirectory.

### ④.7 Domain events (§⑤ of parent)

Three events, published from the handlers above, following the existing `INotification` / MediatR domain-event convention in this codebase (find a sibling event and copy its shape):

| Event | Published from | Payload |
|---|---|---|
| `TenantSetupStartedEvent` | first successful `tenantSetup` query where nothing was previously completed | CompanyId, UserId, OccurredUtc |
| `TenantSetupStepCompletedEvent` | `CompleteTenantSetupStep`, `SkipTenantSetupStep`, `AutoCompleteAsync` | CompanyId, UserId, TaskCode, Status, OccurredUtc |
| `TenantSetupCompletedEvent` | `FinishTenantSetup` (only on the real stamp, not the no-op) | CompanyId, UserId, CompletedCount, SkippedCount, OccurredUtc |

Handlers: audit-log only for now. No emails, no notifications.

---

## ⑤ Frontend

### ⑤.1 The gate — where it actually goes

**Confirmed on disk:** NextAuth's `authorized({ auth, request })` callback in `src/infrastructure/lib/configs/auth.ts` returns a **boolean only** (public-route allowlist + `!!auth`). It performs no redirects and has no access to tenant state. Root `middleware.ts` does locale-prefix redirection only. **Neither is the gate.**

The gate belongs in the authenticated shell: `src/app/[lang]/(core)/layout.tsx`, which currently reads:

```tsx
<RouteGuard requireAuth={true}>
  <RoleCapabilityProvider>
    <PlanEnforcementProvider>
      <DashBoardLayoutProvider trans={trans}>{children}</DashBoardLayoutProvider>
    </PlanEnforcementProvider>
  </RoleCapabilityProvider>
</RouteGuard>
```

Add a `TenantSetupGate` **inside `RoleCapabilityProvider`, wrapping `PlanEnforcementProvider`**. Reason: it needs an authenticated session and the ambient tenant (same reason `PlanEnforcementProvider` sits inside the shell and not on public routes), and it must run before the dashboard paints.

`TenantSetupGate` behaviour:
- Query `tenantSetup` once (cache it — this is the same query the wizard and the checklist widget use; do not fire it three times).
- `isSetupComplete === true` → render children unchanged. **This is the path every existing tenant takes**, which is exactly why §① must be applied first.
- `isSetupComplete === false` → `router.replace(\`/${lang}/setup\`)` and render the shell's loading skeleton meanwhile. Never flash the dashboard.
- Query error / network failure → **render children** (fail-open). A wizard-checklist outage must not lock a tenant out of their own product.

### ⑤.2 The `/setup` route

New route group so the wizard renders **without** sidebar/header chrome:

```
src/app/[lang]/(setup)/layout.tsx     — RouteGuard requireAuth only; no DashBoardLayoutProvider
src/app/[lang]/(setup)/setup/page.tsx — the wizard
```

`(setup)` parentheses do not appear in the URL → the path is `/en/setup`. The `(setup)` layout must **not** include `TenantSetupGate` (infinite redirect loop).

If the tenant navigates to `/setup` when already complete → `router.replace(\`/${lang}\`)`.

### ⑤.3 The wizard — 3 steps

Full-page, centred, max-width container, progress indicator across the top showing 3 steps.

**Step 1 — Confirm your organisation (`ORG_PROFILE_CONFIRM`)**
Read-only summary of what provisioning already set: organisation name, country, currency, plan. A "Looks right" primary action → `completeTenantSetupStep({ taskCode: "ORG_PROFILE_CONFIRM" })` → advance. A secondary link "Edit in Company Settings" → new tab to `/${lang}/organization/organizationsetup/company`. Skippable.

**Step 2 — Regional settings (`ORG_LOCALE`) — REQUIRED**
Five selects, MasterData-driven: Time Zone (`TIMEZONE`), Date Format (`DATEFORMAT`), Time Format (`TIMEFORMAT`), Financial Year Start (`FINANCIALYEARSTARTMONTH`), Default Language. Submit → `completeTenantSetupStep` with all five ids.
- **No Skip button on this step.** The server enforces `SETUP_TASK_REQUIRED`; the FE simply must not offer the escape hatch.
- Next/Submit gated by RHF `formState.isValid` (all five required), never by a capability check.

**Step 3 — Get ready to transact (`EMAIL_SENDER`, `PAYMENT_GATEWAY`)**
Two cards, each with a short explanation, a status chip, and a "Configure" button deep-linking (new tab) to the route in §③. Each card has "Skip for now" → `skipTenantSetupStep`. Both optional.
- If `EMAIL_SENDER` came back `NOT_APPLICABLE` (no `CHANNEL:EMAIL` entitlement), **hide the card entirely** — do not render a disabled or upsell tile inside the first-run wizard.
- If both cards are hidden, the step still renders with the finish action and a short "you're all set" message.

**Finish** → `finishTenantSetup()` → `router.replace(\`/${lang}\`)`. Button disabled while `hasPendingRequired === true`.

Refetch `tenantSetup` after every mutation so the progress indicator and card chips stay truthful. The wizard must be resumable: closing the browser mid-wizard and logging back in returns the tenant to the first non-terminal step.

### ⑤.4 Dashboard checklist widget

New widget on the tenant dashboard. Shows the full 8-item checklist (excluding `NOT_APPLICABLE` rows), each with status and a deep link from §③.
- Hide the widget entirely when `completedCount + skippedCount === applicableCount`.
- Progress as `completedCount / applicableCount`.
- This is a **new renderer** under the dashboard's `widgets/` tree — no legacy widget reuse — and must be visually distinct from the KPI tiles around it (a checklist list, not another number tile).

### ⑤.5 UI standards (non-negotiable)

- Design tokens only — **no hex, no raw px**. Uniform spacing.
- Icon containers, status chips and badges: solid `bg-X-600` + `text-white`. **Never** `bg-X-50/100`, `text-X-700/800`, `bg-muted`, or `text-muted-foreground` on a badge or icon container.
- Shaped `Skeleton` loaders matching the real layout; explicit empty and error states.
- Responsive xs → xl. The wizard must be usable on a phone.
- Icons: `@iconify` Phosphor.
- Reuse existing components — search the component registries before creating anything. Create only if genuinely missing and static.

### ⑤.6 GraphQL wiring

Add the query and three mutations to the frontend GraphQL layer following the existing convention. **tsc cannot see GraphQL field names** — a wrong name compiles clean and fails only at runtime. Field names, exactly:

| Operation | GraphQL field | Input type |
|---|---|---|
| query | `tenantSetup` | — |
| mutation | `completeTenantSetupStep` | `TenantSetupStepRequestDtoInput` |
| mutation | `skipTenantSetupStep` | (scalar `taskCode`) |
| mutation | `finishTenantSetup` | — |

---

## ⑥ Out of scope — do NOT build

- Any change to the `TenantSetupTask` entity, its EF configuration, or the existing migration.
- A v2 wizard, version-comparison re-prompting, or any use of `SetupWizardVersion` beyond stamping it.
- Editing email/SMS/WhatsApp/payment provider config **inside** the wizard — the wizard deep-links to the real screens, it does not reimplement them.
- Platform-side (`(master)`) visibility of tenant setup progress.
- Emails or notifications on any wizard event.
- Touching `billing.PlanEntitlements` directly — go through `IEntitlementService`.

---

## ⑦ Acceptance criteria

1. `sett.TenantSetupTasks` gets 8 rows per newly provisioned tenant, with gated rows `NOT_APPLICABLE` when the plan lacks the channel.
2. **Every pre-existing tenant logs in straight to the dashboard — the wizard never appears for them.** (Depends on §① being applied.)
3. A newly provisioned tenant admin's first login lands on `/setup`, not the dashboard, with no dashboard flash.
4. Step 2 cannot be skipped from the UI, and `skipTenantSetupStep("ORG_LOCALE")` returns `SETUP_TASK_REQUIRED`.
5. `finishTenantSetup` with `ORG_LOCALE` still `PENDING` returns `SETUP_TASK_REQUIRED`.
6. After Finish, `Companies.SetupWizardCompletedDate` and `SetupWizardVersion` are stamped and the next login goes to the dashboard.
7. Closing the browser mid-wizard and logging back in resumes at the correct step with prior steps still marked complete.
8. **Locale values chosen in the wizard render correctly as selected values on Company Settings (#75)** — not blank selects. This is the round-trip test for §④.4.
9. Configuring an email provider on the real screen flips `EMAIL_SENDER` to `COMPLETED` in the dashboard checklist without visiting the wizard.
10. A tenant with no `CHANNEL:EMAIL` entitlement never sees the email card in the wizard or the checklist.
11. Upgrading a plan flips a `NOT_APPLICABLE` task to `PENDING` on the next materialise; a `COMPLETED` task is never reverted.
12. Calling every mutation twice produces the same end state as calling it once.
13. A `tenantSetup` query on a tenant with zero task rows self-heals to 8 rows and returns them in the same response.
14. A materialiser failure during provisioning logs an error and the provisioning run still completes.
15. The dashboard checklist widget disappears once every applicable task is COMPLETED or SKIPPED.

---

## ⑧ Build rules

- **Do not run `dotnet build`** — the user builds the backend.
- **Do not author, run, or remove EF migrations.** §① is a `sql-scripts-dyanmic/` script the user applies.
- **No raw SQL in application code** — no `ExecuteSqlRawAsync`, `FromSqlRaw`, or string-built SQL. `ExecuteUpdateAsync` / `ExecuteDeleteAsync` over a LINQ `IQueryable` are EF and allowed.
- Frontend typecheck: `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`. No pipe. **Only exit 0 counts as clean.** Run in background if it exceeds 10 minutes.
- Backend and frontend are gitignored — Grep/Glob return zero matches. Use `find -iname` or `grep -rn --include=*.cs` scoped to a single project subdirectory. Absolute-path `Read` works. Repo-wide greps time out at 120 s.
- **Never assume a GraphQL field, DTO property, or column name — read the source first.**
- UTC everywhere: `DateTime.UtcNow`, never `DateTime.Today` in an EF predicate.

---

## ⑨ Open questions

None. §⑨ Q3 (deep links) and Q4 (redirect authority) of the parent spec are resolved above from disk. The only external dependency is the user applying §①'s script and confirming RESULT 1 returns `0`.

---

## ⑩ Build log

_(empty — append one entry per session, newest last, keep the last 5)_
