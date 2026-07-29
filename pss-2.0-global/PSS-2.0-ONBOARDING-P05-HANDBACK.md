# P-05 Hand-back — Lead, Commercial Term & Provisioning Wizard

Prompt: `PSS-2.0-ONBOARDING-PROMPT-05-LEAD-DEAL-WIZARD.md`
Status: **all five deliverables (T-B1, T-B2, T-B3, T-B4, T-B6) complete.**
`dotnet build` exit 0 · `npx tsc --noEmit --incremental false` exit 0.
P-06 (go-live / `Company.Status → ACTIVE` / `OnboardedOn`) **not started**, as instructed.

---

## 1. Definition of done

| # | Item | Status |
|---|---|---|
| 1 | `ops.Lead` + `ops.CommercialTerm` entities, EF config, DbContext, DTOs | ✅ |
| 2 | CRUD + Submit + Approve commands, queries, GraphQL wrappers | ✅ |
| 3 | Backend builds clean | ✅ `dotnet build` exit 0 |
| 4 | S-01 Lead screen on `(master)` | ✅ `/[lang]/ops/leads` |
| 5 | S-02 Commercial Term screen + approval workflow | ✅ `/[lang]/ops/deals` |
| 6 | O-01 Provisioning Wizard (4 steps → `provisionTenant` → run monitor) | ✅ `/[lang]/ops/onboarding/provision` |
| 7 | Welcome email CTA → real P-04 activation route with the minted token | ✅ step 9 |
| 8 | Frontend typechecks clean | ✅ exit 0 |
| 9 | Migration spec handed over, migration **not** authored or run | ✅ `PSS-2.0-ONBOARDING-P05-MIGRATION-SPEC.md` |

Migrations remain strictly user-owned: no `dotnet ef migrations add` / `database update` / `remove`
was run, no migration or model-snapshot file was hand-authored, and **no SQL was executed against
any database**. Seed files are written; you apply them.

---

## 2. Where the discount threshold is read from

- **Source:** `sett."OrganizationSettings"` where `CompanyId IS NULL` (the platform-global baseline
  row) and `ParamCode = 'PLATFORM_DISCOUNT_APPROVAL_THRESHOLD_PCT'`.
- **Resolution:** `CurrentValue ?? ParamDefaultValue`, parsed as `decimal`.
- **Seeded default:** `15`.
- **Reader:** `LeadHelper.GetDiscountApprovalThresholdAsync(...)`
  (`Base.Application/Business/OpsBusiness/LeadManagement/LeadHelper.cs`).
- **Code fallback:** `LeadHelper.DefaultDiscountThresholdPct = 15m`, used **only** when the settings
  row is absent or unparseable (a fresh database before the seed runs). The threshold is never
  hardcoded at a decision site — `SubmitCommercialTermCommandHandler` always calls the helper.
- Auto-approval rule: `DiscountPercent <= threshold` ⇒ `DRAFT → APPROVED`, otherwise
  `DRAFT → PENDING_APPROVAL`. The resolved threshold is returned to the client on the submit result
  (`thresholdPercent`) so the UI can explain *why* a deal auto-approved.

---

## 3. Migration

Full spec in **`PSS-2.0-ONBOARDING-P05-MIGRATION-SPEC.md`**. Summary:

- **2 new tables:** `ops."Leads"`, `ops."CommercialTerms"` (suggested migration name
  `Add_Ops_Leads_And_CommercialTerms`). No existing table or column is altered.
- **4 FKs created by EF:**
  `Leads.CountryId → com.Countries`, `Leads.ConvertedCompanyId → app.Companies`,
  `CommercialTerms.LeadId → ops.Leads`, `CommercialTerms.CurrencyId → com.Currencies` — all
  `ON DELETE RESTRICT`.
- **4 pre-existing "deferred FK" columns were left as plain nullable ints**
  (`ops.TenantProvisioningRuns.LeadId` / `.CommercialTermId`, `app.Companies.SourceLeadId`,
  `billing.Subscriptions.CommercialTermId`). Activating them in EF means editing P-03/P-04
  configuration files, which the brief puts out of scope. §4 of the spec gives ready-to-paste raw-SQL
  `ALTER TABLE … ADD CONSTRAINT` statements plus an orphan-check query if you want them enforced.
- **No FK** on `Leads.OwnerUserId` / `CommercialTerms.ApprovedByUserId` — `auth.Users` is
  tenant-scoped and platform users are resolved from the JWT claim; guarded in code instead.

---

## 4. Seeds created (you apply, in this order)

1. **`sql-scripts-dyanmic/ops-platform-rbac-seed.sql`** (from P-04, unchanged) — `PLATFORM` module,
   menus `PLATFORM_TENANTS` / `PLATFORM_LEADS` / `PLATFORM_PLANS` / `PLATFORM_AUDIT`, capabilities
   `PLATFORM_LEAD_VIEW` / `PLATFORM_LEAD_EDIT` / `PLATFORM_LEAD_EXPORT` / `PLATFORM_DEAL_APPROVE` /
   `PLATFORM_TENANT_VIEW` / `PLATFORM_TENANT_PROVISION` / `PLATFORM_TENANT_SUSPEND` /
   `PLATFORM_IMPERSONATE`, the 5 platform roles, and their grants.
2. **`sql-scripts-dyanmic/ops-lead-deal-seed.sql`** (new, P-05) — 5 idempotent steps:
   - **Step 1** — hidden setting group `PLATFORM`.
   - **Step 2** — platform-global settings (`CompanyId IS NULL`):
     `PLATFORM_DISCOUNT_APPROVAL_THRESHOLD_PCT` = `15`,
     `PLATFORM_ACTIVATION_URL_TEMPLATE` (tokens `{SUBDOMAIN}` / `{LANG}` / `{TOKEN}`),
     `PLATFORM_DEFAULT_LANG` = `en`.
   - **Step 3** — MasterData `PLATFORMEMAIL` (email category for platform-issued mail).
   - **Step 4** — `notify.EmailTemplates` row `TENANT_ADMIN_ACTIVATION` (passwordless).
   - **Step 5** — 8 `COUNTRY` / `CURRENCY` `READ` grants across the 4 platform roles, so the
     `(master)` pickers can resolve the shared lookups (those resolvers are gated on tenant menus).

**RBAC reconciliation vs DQ7:** P-05 introduces **no new menu and no new capability**. Everything
hangs off the existing `PLATFORM_LEADS` menu. The brief's `PLATFORM_LEAD_MANAGE`,
`PLATFORM_LEAD_CONVERT`, `PLATFORM_DEAL_VIEW`, `PLATFORM_DEAL_MANAGE` and `PLATFORM_ONBOARD_RUN`
were **not** created — the P-04 capability set already covers every action:

| Action | Gate |
|---|---|
| Read leads / deals | `PLATFORM_LEADS` + `PLATFORM_LEAD_VIEW` |
| Create/update/delete leads & deals, submit for approval | `PLATFORM_LEADS` + `PLATFORM_LEAD_EDIT` |
| Approve / reject a commercial term | `PLATFORM_LEADS` + `PLATFORM_DEAL_APPROVE` |
| Run the provisioning wizard | `PLATFORM_TENANTS` + `PLATFORM_TENANT_PROVISION` |

No existing `PLATFORM_TENANT_*` row was re-seeded.

---

## 5. The `ProvisionTenant` mutation input, field by field

GraphQL: `provisionTenant(request: ProvisionTenantInputDtoInput!)`
(`Base.API/EndPoints/Ops/Mutations/TenantProvisioningMutations.cs`). The wizard sends:

| Field | Type | Wizard source |
|---|---|---|
| `companyName` | `String!` | Step 3 (prefilled from `Lead.CompanyName`) |
| `companyCode` | `String!` | Step 3 (prefilled via `codeify(lead.companyName)`) |
| `subdomain` | `String!` | Step 3 (prefilled via `slugify(lead.companyName)`) |
| `countryId` | `Int!` | Step 3 (prefilled from `Lead.CountryId`) |
| `address` | `String!` | Step 3 (typed) |
| `companyHeader` | `String` | Step 3, optional → `null` when blank |
| `companyFooter` | `String` | Step 3, optional → `null` when blank |
| `planCode` | `String!` | **selected CommercialTerm** |
| `currencyId` | `Int!` | **selected CommercialTerm** (int FK, never an ISO string) |
| `billingCycle` | `String!` | **selected CommercialTerm** |
| `paymentGatewayCode` | `String` | **selected CommercialTerm** |
| `adminName` | `String!` | Step 3 (prefilled from `Lead.ContactName`) |
| `adminEmail` | `String!` | Step 3 (prefilled from `Lead.ContactEmail`) |
| `mode` | `String!` | hardcoded `"ASSISTED"` |
| `leadId` | `Int` | Step 1 |
| `commercialTermId` | `Int` | Step 2 |

The acting user is **not** in the payload — the mutation resolves it from the HTTP `UserId` claim
(`ExceptionCode.UnAuthorized` when missing). No money field is ever sent from the browser: the
commercial term supplies plan/currency/cycle/gateway only, and the engine re-resolves pricing
server-side. On success the wizard reads `result.data.runId` and pushes
`/{lang}/ops/tenants/provisioning-runs/{runId}` (the O-03 monitor). **No P-04 mutation, query,
monitor or activation endpoint was modified.**

---

## 6. Where `Lead.ConvertedCompanyId` is stamped

`ProvisionTenantCommandHandler.StampLeadConversionAsync(...)`, called at the end of
**step 9 (`SEND_WELCOME`)** in
`Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs`.

- Sets `Lead.ConvertedCompanyId = companyId` and forces `Status = WON` (a no-op in practice — only a
  WON lead is provisionable), plus `ModifiedDate = DateTime.UtcNow`.
- **Idempotent:** returns early when the lead is already stamped with the same company, so a resumed
  run re-executing step 9 is harmless.
- **No-op when there is no lead** (`SELF_SERVICE`, or an assisted run started without one).
- `Company.SourceLeadId` is stamped in **step 1** (`ProvisionTenant.cs:375`) — the other half of the
  same pair. This is the only change made to the P-03 engine besides the sanctioned step-9 email
  edit.
- Consequence for the UI: `GetLeads` exposes `canConvert = Status == WON && ConvertedCompanyId == null`,
  and the wizard's lead picker passes `convertibleOnly: true` so an already-provisioned lead cannot
  be converted twice.

---

## 7. The activation route the email links to

- **Route:** `/{lang}/activate?token=…` — the real P-04 activation surface
  (`src/app/[lang]/(auth)/activate/page.tsx`, which reads the `token` search param, then calls
  `validateActivationToken(token)` and `activateAccount(token, newPassword, confirmPassword)`).
- **Token:** the live `auth.PasswordResets` row minted in **step 8** is *read*, never re-minted
  (step 8 skips minting when a live token exists, so a resume reuses it); the token is
  `Uri.EscapeDataString`-encoded into the link.
- **Host:** built by `BuildActivationUrlAsync` from the platform setting
  `PLATFORM_ACTIVATION_URL_TEMPLATE` (tokens `{SUBDOMAIN}`, `{LANG}`, `{TOKEN}`) so each tenant gets
  its own subdomain. When the setting row is absent it falls back to `Frontend:BaseUrl` from
  appsettings (single-host dev behaviour, matching ForgotPassword).
- **`{LANG}`** comes from the platform setting `PLATFORM_DEFAULT_LANG` (default `en`).
- **No password anywhere** — not in the email, not in the payload, not in the logs. The placeholder
  set is `USER_NAME`, `COMPANY_NAME`, `SUBDOMAIN`, `ACTIVATION_LINK`, `EXPIRY_DATE` (UTC-formatted),
  `CURRENT_YEAR`.

---

## 8. Everything that differs from the brief

### Backend

| # | Brief said | Built as | Why |
|---|---|---|---|
| 1 | Email template `USER_WELCOME_INVITE` | **`TENANT_ADMIN_ACTIVATION`** (new platform template) | `USER_WELCOME_INVITE` is shared with SendUserInvite / ResetUserPassword / BulkResetPasswords, which legitimately mail a temporary password, and `PlaceholderEngine` has no `{{#if}}` support — the password block cannot be suppressed per caller. Stripping it would break three live tenant flows. `USER_WELCOME_INVITE` left untouched. |
| 2 | `ApproveCommercialTermCommand(int, bool, string?)` | **4 params** — a trailing `int actingUserId` | The acting user comes from the HTTP `UserId` claim at the mutation layer; handlers have no HTTP context. |
| 3 | — | On **auto**-approval, `ApprovedByUserId` stays **null** while `ApprovedOn` is stamped | No human approved it. The UI renders "Auto-approved". |
| 4 | FK for `OwnerUserId` / `ApprovedByUserId` | **No DB FK**, code-guarded | `auth.Users` is tenant-scoped; a hard constraint fights the tenant query filter. |
| 5 | — | New file `Base.Application/Mappings/OpsMappings.cs` + 1 registration line in `DependencyInjection.cs:107` | Mapster config for the two new entities; `ConvertedCompanyId` is explicitly `.Ignore()`d so the client can never set it. |
| 6 | — | `ProvisionTenantCommandHandler` gained a 6th ctor dependency, `IConfiguration` | Needed for the `Frontend:BaseUrl` activation-link fallback. |
| 7 | — | New hidden setting group `PLATFORM`, new MasterData `PLATFORMEMAIL`, new settings `PLATFORM_ACTIVATION_URL_TEMPLATE` + `PLATFORM_DEFAULT_LANG` | Supporting rows for the threshold and the activation link. |
| 8 | — | 8 `COUNTRY`/`CURRENCY` `READ` grants added to the 4 platform roles | Those resolvers are gated on tenant menus; without the grants the `(master)` country/currency pickers 403. |

### Frontend

| # | Brief said | Built as | Why |
|---|---|---|---|
| 9 | `PLATFORM_LEAD_MANAGE` / `PLATFORM_LEAD_CONVERT` / `PLATFORM_DEAL_VIEW` / `PLATFORM_DEAL_MANAGE` / `PLATFORM_ONBOARD_RUN` | **Not created.** Uses the existing `PLATFORM_LEAD_VIEW` / `PLATFORM_LEAD_EDIT` / `PLATFORM_DEAL_APPROVE` / `PLATFORM_TENANT_PROVISION` | See §4 — the P-04 set already covers every action; fewer capabilities means less RBAC drift. |
| 10 | S-02 as its own screen | **One `/ops/deals` screen serving two modes** — unscoped it is the approval queue, `?leadId=N` scopes it to one prospect | Same data, same actions; a second screen would duplicate the table and the dialogs. |
| 11 | Plan picker from the plan catalogue | **Static FE constant `PLAN_CODE_OPTIONS`** (`FREE`, `PLAN_50K`, `PLAN_100K`, `CUSTOM`) | `billing.Plans` has **no GraphQL surface at all** (`Base.API/EndPoints/` has no `Billing` directory). Replace with a real query when the billing read model lands. |
| 12 | Owner filter | Derived client-side from the loaded page of leads | No platform user-directory query exists. |
| 13 | — | `usePlatformCapabilities` is called with `has(code)`, not its `canView` | The hook's `canView` is hardcoded to `PLATFORM_TENANT_VIEW`; the wizard calls the hook twice (`PLATFORM_LEADS` and `PLATFORM_TENANTS`). |
| 14 | — | `domain/entities/ops-service/CommercialTermDto.ts` exports **`DealBillingCycle`**, not `BillingCycle` | `setting-service` already exports `BillingCycle` through the `domain/entities` barrel — the collision was a TS2308 typecheck error. |
| 15 | — | `/ops/deals` and `/ops/onboarding/provision` routes are `<Suspense>`-wrapped | Both read `?leadId=` via `useSearchParams`, which Next.js requires be inside a Suspense boundary. |

### New routes

| Route | Screen |
|---|---|
| `/[lang]/ops/leads` | S-01 Lead management |
| `/[lang]/ops/deals` (optional `?leadId=`) | S-02 Commercial terms + approval queue |
| `/[lang]/ops/onboarding/provision` (optional `?leadId=`) | O-01 Provisioning wizard |

---

## 9. Known gaps / follow-ups

1. **No `checkSubdomain` query** (P-04 Gap #6). The wizard validates the subdomain client-side with a
   regex only; real uniqueness and reserved-word rejection surface as a `ProvisionTenantCommandValidator`
   error **after** the user clicks Provision. A pre-flight availability query would be a better UX.
2. **Plan codes are a static FE list** (deviation #11) — wire to `billing.Plans` once it has a read API.
3. The **four deferred FKs** are still un-enforced at the database level (§3 / spec §4).
4. **P-06 not started:** the tenant stays inactive after provisioning; nothing here flips
   `Company.Status → ACTIVE` or stamps `OnboardedOn`.

---

## 10. Apply checklist

1. Author + run the migration from `PSS-2.0-ONBOARDING-P05-MIGRATION-SPEC.md`, commit it.
2. Apply `sql-scripts-dyanmic/ops-platform-rbac-seed.sql` (if not already applied).
3. Apply `sql-scripts-dyanmic/ops-lead-deal-seed.sql`.
4. Set `PLATFORM_ACTIVATION_URL_TEMPLATE`'s `CurrentValue` to your real host pattern before any
   production provisioning run (the seeded default is a placeholder pattern).
5. Smoke test: create a lead → mark WON → quote a term at ≤15% (auto-approves) and one at >15%
   (goes to PENDING_APPROVAL, approve it) → run the wizard → land on the run monitor → confirm the
   activation email links to `/{lang}/activate?token=…` on the tenant's subdomain.
