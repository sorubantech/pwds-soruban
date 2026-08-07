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

**All eight tasks are sections on the SINGLE `/setup` page.** There is no "checklist only" tier and no step-by-step navigation. See §⑤ for why.

| Order | TaskCode | Required | Entitlement gate | Inline section content | Owning screen (reference only — DO NOT link to it) |
|---|---|---|---|---|---|
| 1 | `ORG_PROFILE_CONFIRM` | no | — | Org name, country, currency — editable inline | `/organization/organizationsetup/company` |
| 2 | `ORG_LOCALE` | **yes** | — | 5 MasterData selects | `/organization/organizationsetup/company` |
| 3 | `BRANDING` | no | — | Logo upload + primary colour | `/organization/organizationsetup/company` |
| 4 | `EMAIL_SENDER` | no | `CHANNEL:EMAIL` | Provider select + credential fields | `/setting/communicationconfig/emailproviderconfig` |
| 5 | `PAYMENT_GATEWAY` | no | — | Gateway select + credential fields | `/setting/paymentconfig/companypaymentgateway` |
| 6 | `INVITE_TEAM` | no | — | Repeatable name/email/role rows | `/organization/staff/staff` |
| 7 | `WHATSAPP_SENDER` | no | `CHANNEL:WHATSAPP` | Provider select + credential fields | `/setting/communicationconfig/whatsappsetup` |
| 8 | `SMS_SENDER` | no | `CHANNEL:SMS` | Provider select + credential fields | `/setting/communicationconfig/smssetup` |

The "owning screen" column exists so you can find the **existing form component, DTO, and mutation to reuse** in that section. It is **not** a deep link — the wizard must never navigate the user there. See §⑤.4.

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

New tenants must be left with `SetupWizardCompletedDate = NULL` and `SetupWizardVersion = NULL` — that is already the DB default; **do not stamp them at provisioning.** Only `saveTenantSetup` with `finish: true`, once it passes the guard (§④.5), stamps.

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

### ④.4 Mutation — `SaveTenantSetup` — ONE CALL SAVES EVERYTHING

**There is exactly one write mutation for the setup page.** No per-section save, no per-section mutation, no partial submits. The frontend holds every field in a client store and posts the whole thing once (§⑤.3).

New command under `Base.Application/Business/SettingBusiness/TenantSetup/Commands/SaveTenantSetupCommand/`.

GraphQL field: **`saveTenantSetup`**. Input `TenantSetupRequestDto` → **`TenantSetupRequestDtoInput`**.

```csharp
public record TenantSetupRequestDto(
    TenantSetupProfileDto?  Profile,        // null = section untouched
    TenantSetupLocaleDto    Locale,         // REQUIRED — never null
    TenantSetupBrandingDto? Branding,
    TenantSetupEmailDto?    EmailSender,
    TenantSetupGatewayDto?  PaymentGateway,
    IReadOnlyList<TenantSetupInviteDto>? TeamInvites,
    TenantSetupWhatsAppDto? WhatsAppSender,
    TenantSetupSmsDto?      SmsSender,
    IReadOnlyList<string>?  SkippedTaskCodes,   // sections the tenant explicitly skipped
    bool                    Finish);            // true = also stamp the wizard complete

public record TenantSetupLocaleDto(
    string DefaultTimezoneId,        // MasterData id
    string DateFormatId,
    string TimeFormatId,
    string FinancialYearStartId,
    string DefaultLanguageId);
```

The per-domain child DTOs (`TenantSetupEmailDto`, `TenantSetupGatewayDto`, …) must **mirror the field set of the existing screen's request DTO** for that domain. Read each one before defining it — do not invent field names.

**Null vs empty is meaningful:** `null` = the tenant did not touch that section (leave existing data alone). A populated object = save it. A code in `SkippedTaskCodes` = mark SKIPPED. A section can never be both.

**Handler contract:**

1. `var companyId = httpContextAccessor.GetCurrentUserStaffCompanyId();`
2. **One explicit transaction wrapping everything.** All-or-nothing: if any section fails, nothing is written — not the locale, not the invites, not the task rows. A tenant must never end up half-configured with no idea which half.
3. For each non-null section, **delegate to the existing domain service/handler** for that domain (email provider, gateway, branding, staff invite). Do not reimplement their logic, validation, or credential masking. If a domain's logic lives only inside its command handler, invoke that handler through the mediator inside the transaction rather than copying its body.
4. Locale is written by this handler directly — see the hazard note below.
5. Task bookkeeping, after the domain writes succeed:
   - section saved → `COMPLETED`, `CompletedDate = DateTime.UtcNow`, `CompletedByUserId = <current user>`
   - code in `SkippedTaskCodes` → `SKIPPED`, `SkippedDate = DateTime.UtcNow`
   - untouched → leave as-is
   - `ORG_PROFILE_CONFIRM` → `COMPLETED` whenever `Profile` is non-null
6. `Finish == true` → apply the §④.5 finish guard and stamp the company. `Finish == false` → save and return, wizard stays open (this is the "Save and continue later" path).
7. `orgSettings.InvalidateCompany(companyId);` after commit.
8. **Fully idempotent and re-runnable.** The same payload posted twice must produce the same end state — this mutation is also the *update* path when the tenant returns from the dashboard checklist. Sections must upsert, never blind-insert; `TeamInvites` must not re-invite an address that already has a staff row.

**Error shape:** return field-level errors keyed by section so the FE can expand the offending card and highlight the field. A flat message string is not acceptable — with one submit carrying eight sections, "validation failed" is useless to the user.

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
Upsert(existingByCode, companyId, "TIME_ZONE", mdNamesById.Get(dto.Locale.DefaultTimezoneId));
```

Do **not** duplicate the `Upsert` / `MdNameResolver` helpers by copy-paste if you can extract them — but if extraction risks touching `UpdateCompanySettings.cs`'s behaviour, prefer a private copy in the new handler over refactoring a live screen's handler. Correctness beats DRY here.

Validation: `Locale` is mandatory and all five ids must be non-null. Reject with a field-level error under the locale section, not a generic 500.

**UTC only** — every Postgres date column is `timestamp with time zone` and Npgsql throws on `Kind=Unspecified`.

### ④.5 The finish guard

Applied inside `SaveTenantSetup` when `Finish == true`:

- If any task would still be `IsRequired == true && Status == PENDING` **after** this payload is applied → reject the whole mutation with error code **`SETUP_TASK_REQUIRED`** and roll back. Evaluate against the post-payload state, not the pre-payload state: a submit that supplies the locale *and* sets `Finish = true` must succeed in one call.
- Otherwise stamp `Company.SetupWizardCompletedDate = DateTime.UtcNow` and `Company.SetupWizardVersion = TenantSetupConstants.CurrentSetupWizardVersion`.
- Already complete → do not re-stamp the date; the rest of the payload still saves normally (this is the update path from the dashboard checklist).

Required tasks can never be skipped: a `SkippedTaskCodes` list containing `ORG_LOCALE` is rejected with `SETUP_TASK_REQUIRED`.

Scoping is `GetCurrentUserStaffCompanyId()` throughout.

### ④.6 Auto-close hooks

**Scope first, so this does not collide with §④.4.** `SaveTenantSetup` does **all** of its own task bookkeeping inside its own transaction — it marks each supplied section COMPLETED and each `SkippedTaskCodes` entry SKIPPED itself. These hooks are **not** part of that path and must never fire from it.

They exist for one case only: a tenant who **skipped** a section in the wizard and later configures it on the **real admin screen** (Company Settings, Email Provider Config, Payment Gateway, Staff, WhatsApp, SMS). The dashboard checklist has to notice.

Two hard rules:
- **No double-write.** `AutoCompleteAsync` must be a no-op when the task is already `COMPLETED`. Read-then-write under the existing unique index `(CompanyId, TaskCode)`; on a race, swallow the unique violation.
- **Never call it from `SaveTenantSetup`** or from any handler `SaveTenantSetup` invokes via mediator. If a section's domain handler already carries the hook, `SaveTenantSetup` must suppress it (pass a flag on the command, or set an `ITenantSetupService` ambient suppression for the duration of the transaction — pick one and record which in §⑩). Two writers to the same row inside one transaction is the bug this rule prevents.

Route every hook through **one** call — `ITenantSetupService.AutoCompleteAsync(companyId, taskCode, ct)` — never scattered inline `TenantSetupTask` writes.

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

### ④.7 Login landing override — THE GATE

**This is where the wizard gate lives. Not the frontend.**

Verified on disk: the `login` mutation already returns `defaultLandingUrl` (a role-resolved relative route, no locale prefix). The frontend consumes it in `useAuth`'s `resolvePostLoginLanding` (`src/presentation/hooks/useAuth/index.ts:48`) and `router.push`es the result — falling back to `MASTER_URL` when it is null. **That is the single post-login redirect authority in this product.**

In the login handler, after the role's `DefaultLandingUrl` is resolved and immediately before the response is built:

```csharp
// First-run setup outranks the role landing. A tenant that has not finished
// setup goes to /setup and nowhere else — no dashboard is rendered first.
if (isTenantStaff && company.SetupWizardCompletedDate is null)
{
    defaultLandingUrl = "setup";
}
```

Rules:
- **Tenant staff only.** Platform staff (`(master)` surface) must never be diverted — their company row is not a tenant and has no wizard. Use whatever platform-staff discriminator the login handler already computes; do not invent a new one.
- Return `"setup"` **without** a leading slash and **without** a locale prefix, matching the existing `defaultLandingUrl` contract (`resolvePostLoginLanding` strips leading slashes and prefixes `/${lang}/`).
- No frontend change is needed for the redirect itself — `resolvePostLoginLanding` will route to `/${lang}/setup` unmodified. Its module-resolution block will simply find no owning module for `setup`, which is harmless (it only skips pre-setting module context).

**Why not a client-side gate:** any redirect decided inside `(core)/layout.tsx` or a provider means the dashboard shell mounts, queries, and paints before bouncing to `/setup`. That is the flash the tenant sees today and it is unacceptable. Deciding at login means the dashboard is never requested at all.

Defence in depth (cheap, keep it): the `(setup)` page itself redirects to `/${lang}` if `tenantSetup.isSetupComplete === true`, so a bookmarked `/setup` cannot trap a finished tenant. Do **not** add the inverse guard to `(core)` — the login override is the gate.

### ④.8 Domain events (§⑤ of parent)

Three events, published from the handlers above, following the existing `INotification` / MediatR domain-event convention in this codebase (find a sibling event and copy its shape):

| Event | Published from | Payload |
|---|---|---|
| `TenantSetupStartedEvent` | first successful `tenantSetup` query where nothing was previously completed | CompanyId, UserId, OccurredUtc |
| `TenantSetupStepCompletedEvent` | `SaveTenantSetup` — one per section saved or skipped in the payload; plus `AutoCompleteAsync` | CompanyId, UserId, TaskCode, Status, OccurredUtc |
| `TenantSetupCompletedEvent` | `SaveTenantSetup` when `Finish: true` passes the guard and the `SetupWizardCompletedDate` stamp actually lands (never on a re-submit that finds it already stamped) | CompanyId, UserId, CompletedCount, SkippedCount, OccurredUtc |

Publish **after** the transaction commits, not inside it — a submit that rolls back must emit nothing. Collect the events in a local list as sections are processed, then dispatch once on success.

Handlers: audit-log only for now. No emails, no notifications.

---

## ⑤ Frontend

### ⑤.0 The three rules that govern this whole section

**RULE 1 — ONE PAGE. NO NAVIGATION.**
Every field the tenant needs is on `/setup` itself. The wizard **never** sends the user to another screen to configure email, payment, branding, or anything else. Bouncing a brand-new user around six admin screens and hoping they find their way back is not onboarding — it is a maze. Nobody ships that.

There is no multi-step stepper, no Next/Back, no "Configure →" link, no new tab. One scrollable page, all sections visible, one submit at the end.

**RULE 2 — ONE SUBMIT. NO PER-SECTION API CALLS.**
Every field lives in a client-side **Zustand** store as the tenant types. Nothing is sent to the server until they press **Finish setup**, which fires exactly one `saveTenantSetup` mutation carrying all eight sections. The same single call handles updates when they come back later.

No autosave, no per-card Save button hitting the API, no debounced background writes. Eight small requests that can each half-fail is exactly the state we are avoiding.

**RULE 3 — THE DASHBOARD IS NEVER RENDERED FIRST.**
The redirect is decided at login by the backend (§④.7). By the time the browser navigates anywhere, the destination is already `/setup`. There is no dashboard mount, no query, no paint, no bounce.

Do **not** add any setup gate, provider, or redirect to `(core)/layout.tsx`. It stays exactly as it is today.

### ⑤.1 The `/setup` route

New route group so the page renders **without** sidebar/header chrome — a first-run user has nothing to navigate to yet, and the sidebar is a distraction from the one job on screen:

```
src/app/[lang]/(setup)/layout.tsx     — RouteGuard requireAuth only; NO DashBoardLayoutProvider
src/app/[lang]/(setup)/setup/page.tsx — the setup page
```

`(setup)` parentheses do not appear in the URL → the path is `/en/setup`.

Keep a minimal header on the page itself: tenant logo/name on the left, user menu + Sign out on the right. A user who lands here must always be able to leave the product.

If `tenantSetup.isSetupComplete === true` → `router.replace(\`/${lang}\`)`. This is the only guard on this route.

**The page occupies the full viewport.** Not a narrow card floating in an ocean of grey. Concretely:
- The `(setup)` layout is `min-h-screen w-full` with a page background; the content column is `w-full max-w-5xl mx-auto` with real page padding — wide enough that a 3-across field row (time zone / date format / time format) fits on one line at `lg`.
- Section cards are full content-width. Field grids inside them are `grid-cols-1 md:grid-cols-2 lg:grid-cols-3`, not a single stacked column in a 600px box.
- No fixed-width dialog shell, no `max-w-2xl` centred panel, no vertical dead space above the heading.

**Not a modal over the master dashboard.** It was considered and rejected: a modal means the dashboard mounts, queries and paints behind it, which is exactly the flash §④.7 exists to eliminate, and it puts a 6-section form inside a scroll-trapped box. The wizard is its own full-page route reached directly from login. (The one place a modal is still permitted is §⑤.4's OAuth/multi-step fallback — a dialog *on* `/setup`, never over the dashboard.)

### ⑤.2 Page anatomy

```
┌──────────────────────────────────────────────────────┐
│  [logo] Acme Foundation              [user ▾] Sign out│
├──────────────────────────────────────────────────────┤
│  Finish setting up Acme Foundation                    │
│  A few details and you're ready to go.                │
│  ▓▓▓▓▓▓▓░░░░░░░░  3 of 7 done                         │
├──────────────────────────────────────────────────────┤
│  ▼ Regional settings                    ● Required    │
│    [Time zone ▾] [Date format ▾] [Time format ▾]      │
│    [Financial year start ▾] [Language ▾]              │
├──────────────────────────────────────────────────────┤
│  ▶ Organisation profile                 ✎ Filled      │
├──────────────────────────────────────────────────────┤
│  ▶ Branding                             ○ Not set     │
├──────────────────────────────────────────────────────┤
│  ▶ Email sender                         ○ Not set     │
├──────────────────────────────────────────────────────┤
│  ▶ Payment gateway                      ⊘ Skipped     │
├──────────────────────────────────────────────────────┤
│  ▶ Invite your team                     ○ Not set     │
├──────────────────────────────────────────────────────┤
│  [ Finish setup ]  ← the ONLY button that calls an API│
└──────────────────────────────────────────────────────┘
```

- One page, one vertical stack of **collapsible section cards** — not tabs, not a stepper.
- Card header carries the section title and a status chip. Chips reflect **client store state**, not server state: `Required` / `Filled` / `Not set` / `Skipped` / `Saved` (the last only after a successful submit).
- **Regional settings is expanded on load**; every other section starts collapsed. Expanding one does not collapse another.
- Each card body contains the **real fields**. **No card has a Save button.** Only `Skip for now`, on optional sections, which is a local store flag — not an API call.
- `Finish setup` is the single submit, bottom of page, sticky footer on mobile. Disabled while the required section is incomplete, with the reason shown next to it — never a silently dead button.
- Sections whose task is `NOT_APPLICABLE` are **not rendered at all**. No disabled cards, no upsell tiles in a first-run flow.

**Banned on this page** — each of these was on an earlier build and is wrong:
- A horizontal step-chip row (`Your organisation ▸ Regional settings ▸ Get ready to transact`) with `Back` / `Next`. That is a stepper. RULE 1 forbids it.
- A `Configure →` button that routes anywhere. The fields belong in the card.
- Any grouping card that bundles several tasks behind one chip ("Get ready to transact" holding email + gateway). One card per task, so the count and the UI agree.

**⑤.2.1 The progress counter — count exactly what is on screen**

The counter and the cards must be driven by **one** array. Derive the rendered section list first, then compute both from it. Never count the catalog and render a filtered subset — that is how `2 of 6 done` appears above three visible items.

```ts
const sections = catalog
  .filter(s => s.status !== "NOT_APPLICABLE")   // entitlement-gated sections vanish
  .filter(s => s.isVisibleInWizard);            // any other render condition goes HERE, not in the JSX

const total = sections.length;                                   // denominator
const done  = sections.filter(s => isResolved(store, s.code)).length;  // numerator
// isResolved = filled in the store OR already COMPLETED on the server OR skipped
```

Rules:
- **Denominator = number of cards actually rendered.** If a card is not on screen, it is not in the count. If it is on screen, it is in the count.
- **SKIPPED counts as resolved.** A skipped optional section is a decision, not outstanding work; leaving it in the numerator's "not done" set makes the bar unreachable — the tenant can never see `6 of 6`.
- Both numbers come from the client store, not from a server field. There is no server round-trip while the tenant works (RULE 2), so a server-computed `completedCount` would be stale the moment they type.
- If the counter and the visible card count ever disagree, that is a bug, not a display preference. Acceptance criterion 24.

### ⑤.3 State — one Zustand store, one submit

Create a dedicated store at `src/application/stores/tenant-setup-stores/tenant-setup-store.ts` with a paired `tenant-setup-istore.ts` holding the state interface. That is the verified convention in this codebase — ~126 stores follow it, and `src/presentation/store/` **does not exist**. Open a sibling store under `src/application/stores/` and copy its shape exactly.

The store holds:
- one slice per section, mirroring that section's DTO in §④.4
- `skipped: Set<string>` of task codes
- `expandedSection`, `submitting`, and `sectionErrors: Record<string, FieldError[]>` returned by the server

Flow:
1. On mount, hydrate the store from the `tenantSetup` query plus each section's existing values (a tenant returning from the dashboard checklist must see what they already saved, not blank fields).
2. Every keystroke and select writes to the store. **Zero network traffic.**
3. `Finish setup` → build one `TenantSetupRequestDto` from the store → **one** `saveTenantSetup` call with `finish: true`.
4. Success → refetch `tenantSetup`, then `router.replace(\`/${lang}\`)`.
5. Failure → keep every field exactly as typed, write `sectionErrors` into the store, auto-expand the first failing section and scroll to it. **Never clear the form on error.** The whole payload failed as one unit, so the user re-submits once after fixing.

Per-section forms may still use RHF for field-level validation, but their values must be synced into the Zustand store — the store is the single source of truth at submit time.

**Regional settings has no Skip control.** The server enforces `SETUP_TASK_REQUIRED`; the UI simply must not offer the escape hatch.

`Skip for now` toggles a local flag → chip becomes `Skipped`, card collapses, its slice is sent as `null` and its code added to `skippedTaskCodes` on submit.

**Unsaved-changes guard:** because nothing persists until submit, warn on tab close / sign-out if the store is dirty. Without this, a tenant who fills six sections and closes the tab loses everything — the one genuine cost of single-submit, and it must be handled, not ignored.

| Section | Fields | Store slice | Optional |
|---|---|---|---|
| Organisation profile | org name, country, currency | `profile` | yes |
| **Regional settings** | 5 MasterData selects | `locale` | **no — required** |
| Branding | logo upload, primary colour | `branding` | yes |
| Email sender | provider select + credentials | `emailSender` | yes |
| Payment gateway | gateway select + credentials | `paymentGateway` | yes |
| Invite your team | repeatable name / email / role rows | `teamInvites` | yes |
| WhatsApp sender | provider select + credentials | `whatsAppSender` | yes |
| SMS sender | provider select + credentials | `smsSender` | yes |

### ⑤.4 How the sections get their fields — REUSE, do not reimplement

Each section's fields already exist as a form on its owning screen (§③). **Reuse the presentational field group** — extract it into a shared component if it is currently welded to its page. Do not fork a second copy of a credentials form.

What you must **not** reuse on the frontend is the owning screen's **mutation call**. Those forms submit themselves; the setup page's sections must not. Extract fields and validation, drop the submit. If a form component cannot be used without its submit wiring, extract the field group rather than bending the component.

Server-side reuse happens instead inside `SaveTenantSetup` (§④.4), which delegates each section to the existing domain handler. That is where the "don't reimplement" rule is enforced.

**Credential fields keep their existing security behaviour** — masked, write-only, audited. Do not weaken it because the surface changed. Note that holding credentials in a client store until submit is unavoidable under single-submit; keep them in memory only, and **never** persist the store to `localStorage` / `sessionStorage` or Zustand's `persist` middleware.

**The one permitted fallback:** if a section's form genuinely cannot be rendered inline — it has its own multi-step flow, or an OAuth/redirect handshake with an external provider — open it in a **modal dialog on the same page**. A dialog is not navigation; the user never leaves `/setup`. Sending them to another route is still forbidden. Note any section you resolve this way in the build log with the reason.

### ⑤.5 Dashboard checklist widget

New widget on the tenant dashboard, for whatever was skipped or left unset. Shows the applicable tasks (excluding `NOT_APPLICABLE`) with their status.
- Each row's action is **"Finish setup"** → back to `/${lang}/setup` with that section pre-expanded (`/setup#branding` or an equivalent query param). Consistent with RULE 1: setup is edited in one place. Do not deep-link rows to individual admin screens.
- Hide the widget entirely when `completedCount + skippedCount === applicableCount`.
- Progress as `completedCount / applicableCount`.
- This is a **new renderer** under the dashboard's `widgets/` tree — no legacy widget reuse — and must be visually distinct from the KPI tiles around it (a checklist list, not another number tile).

Because the widget can return the user to `/setup` after setup is finished, the §⑤.1 guard must allow re-entry: redirect to the dashboard only when the user arrived with **no** section anchor. With an anchor, render the page normally so completed sections can still be edited.

### ⑤.6 UI standards (non-negotiable)

- Design tokens only — **no hex, no raw px**. Uniform spacing.
- Icon containers, status chips and badges: solid `bg-X-600` + `text-white`. **Never** `bg-X-50/100`, `text-X-700/800`, `bg-muted`, or `text-muted-foreground` on a badge or icon container.
- Shaped `Skeleton` loaders matching the real layout; explicit empty and error states.
- Responsive xs → xl. The wizard must be usable on a phone.
- Icons: `@iconify` Phosphor.
- Reuse existing components — search the component registries before creating anything. Create only if genuinely missing and static.
- The page must be usable end-to-end on a phone: cards stack, fields go full-width, `Finish setup` is a sticky footer.

### ⑤.7 GraphQL wiring

Add the query and three mutations to the frontend GraphQL layer following the existing convention. **tsc cannot see GraphQL field names** — a wrong name compiles clean and fails only at runtime. Field names, exactly:

| Operation | GraphQL field | Input type |
|---|---|---|
| query | `tenantSetup` | — |
| mutation | `saveTenantSetup` | `TenantSetupRequestDtoInput` |

**Two operations total.** If you find yourself adding a third, you have reintroduced per-section saving — stop and re-read §⑤.0 RULE 2.

---

## ⑥ Out of scope — do NOT build

- Any change to the `TenantSetupTask` entity, its EF configuration, or the existing migration.
- A v2 wizard, version-comparison re-prompting, or any use of `SetupWizardVersion` beyond stamping it.
- **Reimplementing** email/SMS/WhatsApp/payment/branding forms or their mutations. The setup page renders them inline by **reusing** the existing components and mutations (§⑤.4). Inline is mandatory; a second implementation is forbidden.
- Any redirect, gate, or provider added to `(core)/layout.tsx` — it stays untouched. The gate is the backend login landing (§④.7).
- A multi-step stepper, step-chip row, Next/Back navigation, `Configure →` button, or any link out of `/setup`.
- Rendering the wizard as a **modal/dialog over the master dashboard** — see §⑤.1. It is a full-page route.
- A narrow centred card layout. The page is full-viewport (§⑤.1).
- A server-computed progress count, or any counter whose denominator is the task catalog rather than the rendered card list (§⑤.2.1).
- **Per-section API calls.** No card gets its own Save button that hits the server. No `completeTenantSetupStep`, `skipTenantSetupStep`, or `finishTenantSetup` mutation — those were designed and then deleted; do not resurrect them.
- **Autosave, debounced writes, or optimistic background syncing.** Typing sends nothing.
- **A second write mutation of any kind.** `saveTenantSetup` is the only write, and it is also the update path. Two operations total (§⑤.7).
- Zustand `persist` middleware, `localStorage`, `sessionStorage`, cookies, or IndexedDB for any wizard field — the store is memory-only because it holds provider credentials.
- Platform-side (`(master)`) visibility of tenant setup progress.
- Emails or notifications on any wizard event.
- Touching `billing.PlanEntitlements` directly — go through `IEntitlementService`.

---

## ⑦ Acceptance criteria

1. `sett.TenantSetupTasks` gets 8 rows per newly provisioned tenant, with gated rows `NOT_APPLICABLE` when the plan lacks the channel.
2. **Every pre-existing tenant logs in straight to the dashboard — the wizard never appears for them.** (Depends on §① being applied.)
3. A newly provisioned tenant admin's first login lands on `/setup` **directly** — network trace shows the dashboard route was never requested, and no dashboard chrome paints at any point.
4. **Every field is reachable without leaving `/setup`.** Configuring email, payment gateway, branding and team invites all complete on that one page. No section renders a link or button that navigates to another route.
5. Platform staff logging in still land on their master dashboard and never see `/setup`.
6. Regional settings cannot be skipped from the UI, and a `saveTenantSetup` payload carrying `ORG_LOCALE` in `SkippedTaskCodes` is rejected with `SETUP_TASK_REQUIRED`.
7. `saveTenantSetup` with `finish: true` that leaves `ORG_LOCALE` neither supplied nor already complete returns `SETUP_TASK_REQUIRED`, and the Finish button is disabled with a visible reason.
8. A single `saveTenantSetup` carrying the locale **and** `finish: true` succeeds — the guard is evaluated against post-payload state, not pre-payload (§④.5).
9. After Finish, `Companies.SetupWizardCompletedDate` and `SetupWizardVersion` are stamped and the next login goes to the role's normal `defaultLandingUrl`.

**Single-submit behaviour — these are the criteria the §⑤.0 RULE 2 rework exists for:**

10. **Filling every section and pressing Finish produces exactly ONE write request** in the network trace. Not two, not eight.
11. **Nothing is sent while typing.** With the Network tab open, editing every field in every section produces zero requests until Finish is pressed. No autosave, no debounce, no per-card save.
12. **A failed submit preserves every typed value.** Force a server-side failure in one section; the page still shows all entered values across all sections, the failing section is expanded and scrolled to, and its field-level errors are visible. Nothing is cleared and nothing is silently half-saved — the DB shows no partial write from that attempt.
13. **Credentials never reach browser storage.** After filling the email and gateway sections, `localStorage`, `sessionStorage`, and cookies contain no provider secret, key, or password. Confirmed with devtools before and after submit.
14. Closing the tab with unsaved sections triggers the unsaved-changes guard (§⑤.3).
15. Re-submitting the same payload after a successful save updates rather than duplicates — the same mutation is the update path, and calling it twice produces the same end state as calling it once.

**Round-trip and lifecycle:**

16. **Locale values chosen in the wizard render correctly as selected values on Company Settings (#75)** — not blank selects. This is the round-trip test for §④.4.
17. Saving the email-sender section inline produces the same `CompanyEmailProvider` row, with the same masking and audit behaviour, as saving it on `/setting/communicationconfig/emailproviderconfig`.
18. Configuring an email provider on the real screen after skipping it in the wizard flips `EMAIL_SENDER` to `COMPLETED` in the dashboard checklist (§④.6), and a `saveTenantSetup` that already marked it COMPLETED does not get double-written by the same hook.
19. A tenant with no `CHANNEL:EMAIL` entitlement never sees the email card in the wizard or the checklist.
20. Upgrading a plan flips a `NOT_APPLICABLE` task to `PENDING` on the next materialise; a `COMPLETED` task is never reverted.
21. A `tenantSetup` query on a tenant with zero task rows self-heals to 8 rows and returns them in the same response.
22. A materialiser failure during provisioning logs an error and the provisioning run still completes.
23. The dashboard checklist widget disappears once every applicable task is COMPLETED or SKIPPED, and while visible its items link to `/setup#section` — never to an admin screen.

**Layout and progress:**

24. **The progress denominator equals the number of section cards on screen, always.** Count the cards, read the counter — they match. Verify on a plan with no WhatsApp/SMS entitlement (fewer cards → smaller denominator) and on a fully entitled plan. `2 of 6 done` above three cards is the exact bug this criterion exists to catch.
25. Skipping every optional section and completing the required one shows `N of N done` and a full progress bar — the bar is reachable.
26. The page fills the viewport at 1440px: no fixed-width centred card, no large empty margins, and a 3-across field row renders on one line. At 375px everything stacks with no horizontal scroll.
27. There is no step-chip row, no Back/Next, and no button anywhere on `/setup` that changes the route (other than Sign out and the post-Finish redirect).

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

### 2026-08-07 — one-page rework (BE-1…BE-7, FE-1…FE-7)

**Backend**

- Deleted `CompleteTenantSetupStep.cs`, `SkipTenantSetupStep.cs`, `FinishTenantSetup.cs` (commands + their folders). `TenantSetupMutations.cs` is now a single resolver `SaveTenantSetup(setup: TenantSetupRequestDtoInput)`; the read side keeps `GetTenantSetup` → `tenantSetup`.
- `SaveTenantSetup` runs a pre-flight `Validate` over the whole payload BEFORE any write, so a bad row in section 6 cannot leave sections 1–5 half-written. Field errors come back inside the payload DTO (`sectionErrors[].errors[].field/message`), not in the envelope, because `BaseApiResponse.errorCode` is an `int` and the business codes are strings.
- Locale/branding write `sett.OrganizationSettings` KV rows; email delegates to `SaveCompanyEmailProviderCommand` (`IsDefault = true`); gateway is idempotent Update-else-Create; invites skip already-existing users; SMS delegates to `SaveSmsSenderConfigurationCommand`; WhatsApp `GraphApiVersion` defaults to `v21.0`.
- **§④.6 auto-close suppression — decision: ambient `AsyncLocal<bool>` on `TenantSetupService`,** not a flag threaded through the command. The nine domain handlers `SaveTenantSetup` invokes via mediator already carry their own `CompleteTaskIfPending` hook; threading a suppression flag would have meant changing nine command DTOs and every other caller of those same handlers, purely to serve one caller. The `AsyncLocal` scope is opened once for the duration of the save and disposed in a `finally`, so `SaveTenantSetup` stays the only writer of `TenantSetupTask` inside its transaction. Trade-off accepted: ambient state is invisible at the call site, so the suppression is commented at both the setter and the hook.
- `GetUserCredential.cs` carries the §④.7 login-landing override — it returns the bare `"setup"` (no leading slash, no `[lang]`), because `resolvePostLoginLanding` strips leading slashes and prepends `/${lang}/`.
- `sql-scripts-dyanmic/tenant-setup-task-displayorder-reorder.sql` re-orders already-materialised tenants to the §③ order (ORG_PROFILE_CONFIRM 1 … SMS_SENDER 8). Idempotent CTE UPDATE. **User applies it** — no EF migration was authored, and `dotnet build` was not run here.

**Frontend**

- `tenant-setup-gate.tsx` deleted and un-wired from `(core)/layout.tsx`. There is no setup gate anywhere any more: the redirect is decided once at login, so nothing can bounce a tenant mid-session.
- GraphQL layer collapsed to exactly two operations: `GET_TENANT_SETUP_QUERY` + `SAVE_TENANT_SETUP_MUTATION`.
- New `tenant-setup-stores` (Zustand) holds the eight draft slices. **Memory-only — no `persist`, no localStorage/sessionStorage/cookie/IndexedDB**, because the draft carries live SMTP/API/gateway/WhatsApp credentials. Losing an unsaved draft on refresh is the correct trade. `setSection` marks a card *touched*; `hydrate` deliberately does not, so prefilled ORG_PROFILE_CONFIRM/BRANDING cannot count themselves done on load.
- `/setup` is one full-viewport page of eight collapsible section cards in DisplayOrder with a single Finish submit, a client mirror of the BE `Validate`, client-derived status chips, an x/y counter, a sticky footer that names the reason Finish is blocked, and a `beforeunload` dirty guard. On rejection it expands and scrolls to the first failing card and never clears the form.
- `(setup)/layout.tsx` is chrome-free by design (no sidebar/menu). Because that left no way out, a minimal `tenant-setup-header.tsx` was added: tenant name, signed-in user, Sign out.
- **Plan-gated channel cards (user request this session):** `WHATSAPP_SENDER` and `SMS_SENDER` render only when the tenant's plan entitles the channel — `hasFeature(FEATURE_CODES.ChannelWhatsApp / ChannelSms)` from `useEntitlements()`. Gate is cosmetic and **fails open** while `resolved` is false, matching every other feature gate; the server stays the authority. It is applied *before* the §⑤.2.1 counter and before payload assembly, so a hidden card can neither inflate the denominator nor submit a slice. `billing.PlanEntitlements` is never read directly.
- `TenantSetupChecklistWidget` rows now deep-link to `/${lang}/setup#${anchor}`. The wizard reads `window.location.hash` once in an effect (invisible to `useSearchParams`), suppresses the already-complete redirect when an anchor is present, and expands + scrolls that card.
- Two API mismatches found by reading source rather than assuming: the exported `Alert` takes `color` + `variant ∈ {outline, soft}` (the shadcn `variant="destructive"` belongs to a different file), and `ApiSingleSelect.onChange` yields `number | null` against DTOs typed `number | undefined` (six sites, fixed with `?? 0`).
- `emailProviderTypeId` has no picker anywhere in the app yet the BE requires `> 0`, so TRANSACTIONAL is resolved from the `EMAILPROVIDERTYPE` MasterDataType via a cache-first query.
- No §⑤.4 credential modal fallback was needed — credential fields stayed inline, masked and write-only.
- Typecheck: `npx tsc --noEmit --incremental false` → **exit 0**.
