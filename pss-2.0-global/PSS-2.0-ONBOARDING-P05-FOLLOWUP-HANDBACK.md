# PSS 2.0 — P-05 follow-up combined hand-back (T-B11 · T-B7 · T-B8 · T-B10)

Run driver: `PSS-2.0-ONBOARDING-PROMPT-05-FOLLOWUP-COMBINED-RUN.md`
Sub-prompts: 05f (T-B11), 05b (T-B7), 05c (T-B8), 05e (T-B10)

**Headline:** only **P-05f was outstanding**. P-05b, P-05c and P-05e were already fully landed in the
working tree before this session (05b/05c by the earlier `…-P05BC-HANDBACK.md` run; 05e was already
absent from the wizard). Each was re-verified against source rather than taken on trust — evidence in
§③–§⑤. This session's code change is **P-05f only**.

**Capability · mutation · query · seed added by any of the four: NONE.**
**Schema touch: P-05f's three re-scoped `auth.Roles` indexes only — migration is YOURS (§②).**

---

## ① Combined build evidence (run once, after all four)

| | Command | Result |
|---|---|---|
| **BE** | `dotnet build …\Base.API\Base.API.csproj -c Debug -p:OutputPath=<scratch>\be-build\` | **0 Error(s)**, 559 warnings, exit 0. Zero `error CS`, zero `error MSB`. |
| **FE** | `npx tsc --noEmit --incremental false` | **exit 0** — a real full-project check, not a config-only no-op. |

**Redirected-output build was used.** `Base.API` (PID 18760) was running and holds the lock on
`Base.API\bin\Debug\…\*.dll`. Rather than kill your running API I passed a global `-p:OutputPath`
into the session scratchpad — the compile ran against the real sources, only the file-copy
destination moved. The running process was left untouched.

---

## ② P-05f / T-B11 — critical provisioning fix

### ②.1 The three Role unique indexes now lead with `CompanyId`

`Base.Infrastructure/Data/Configurations/AuthConfigurations/RoleConfiguration.cs` now reads exactly:

```csharp
builder.HasIndex(o => new { o.CompanyId, o.RoleName, o.IsActive }).IsUnique();
builder.HasIndex(o => new { o.CompanyId, o.RoleCode, o.IsActive }).IsUnique();
builder.HasIndex(o => new { o.CompanyId, o.OrderBy,  o.IsActive }).IsUnique();
```

`IsActive` stays last (soft-delete-aware intent preserved, matches `UserRoleConfiguration`'s
`(UserId, RoleId, CompanyId, IsActive)`). Nothing else in the file changed — no column, no FK, no
other index.

### ②.2 Migration — spec handed to you, **migration NOT run**

No `dotnet ef migrations add` / `database update` / `remove` was executed and no migration or
snapshot was hand-authored. Full spec: **`PSS-2.0-ONBOARDING-P05F-MIGRATION-SPEC.md`**.

The expected diff is **`DropIndex` × 3 + `CreateIndex` × 3 on `auth.Roles` and nothing else** —
`IX_Roles_{RoleName,RoleCode,OrderBy}_IsActive` dropped, `IX_Roles_CompanyId_{RoleName,RoleCode,OrderBy}_IsActive`
created `unique`. No column, no data movement, no other table. The spec tells you to stop and report
if `migrations add` emits anything beyond those six operations (that would be unrelated model drift).

### ②.3 `ProvisionIdempotency.KeyFor` — one formula, three call sites

Added as an `internal static class` in `ProvisionTenant.cs`, immediately after
`ProvisionTenantRequestDto` and before `ProvisionTenantResult`:

```csharp
public static string KeyFor(ProvisionTenantRequestDto req) =>
    req.LeadId is int leadId ? $"LEAD:{leadId}|CODE:{req.CompanyCode}" : $"CODE:{req.CompanyCode}";
```

Used by **all three** places that need the key:
1. `ProvisionTenantCommandHandler.Handle` — the inline computation is gone, replaced by
   `var idempotencyKey = ProvisionIdempotency.KeyFor(req);`
2. the Subdomain uniqueness `MustAsync`,
3. the CompanyCode uniqueness `MustAsync`.

**The key string is byte-identical to the previous inline formula** — same ternary, same
`LEAD:{id}|CODE:{code}` / `CODE:{code}` shapes, same interpolation order. Existing `PAUSED_ON_ERROR`
runs (including `leadId = 2`) keep their key and stay resumable.

### ②.4 How the validator now excludes the run's own half-built company

Both uniqueness clauses moved to FluentValidation's **root-object** `MustAsync`
(`(command, value, ctx, ct) => …`) so the whole `ProvisionTenantRequestDto` — hence the idempotency
key — is in scope. The exclusion is a deliberate **two-step, translatable** query, not a nested
sub-query:

**Step 1 — collect the company ids this run already owns:**

```csharp
var ownCompanyIds = await dbContext.TenantProvisioningRuns
    .IgnoreQueryFilters()
    .Where(r => r.IdempotencyKey == key && r.IsDeleted != true
                && r.Status != "ABANDONED" && r.CompanyId != null)
    .Select(r => r.CompanyId!.Value)
    .ToListAsync(ct);
```

**Step 2 — a company only conflicts if it is *not* in that set:**

```csharp
return !await dbContext.Companies
    .IgnoreQueryFilters()
    .AnyAsync(c => c.Subdomain == sub && c.IsDeleted != true
                   && !ownCompanyIds.Contains(c.CompanyId), ct);   // CompanyCode == code for the other clause
```

Why this shape:
- **`ops.TenantProvisioningRuns` is the ownership record, not `app.Companies`.** A company row carries
  no back-pointer to its provisioning run, so the run header's `CompanyId` (stamped by Step 1
  `CREATE_COMPANY`) is the only link. Matching on `IdempotencyKey` means "the same lead + the same
  company code" — precisely *this* run, resumed.
- **`Status != "ABANDONED"`** — an abandoned run forfeits its claim, so its leftover company correctly
  goes back to being a hard conflict (the operator must pick a new code/subdomain).
- **`CompanyId != null`** — a run that never reached Step 1 owns nothing and excludes nothing.
- **`.IgnoreQueryFilters()` + explicit `IsDeleted != true` on both reads** — control-plane callers have
  `CurrentTenantId == null`, per the standing rule.
- **A genuinely different tenant on the same subdomain still fails**, exactly as before: its
  `CompanyId` is not in `ownCompanyIds`, so `AnyAsync` still finds it.
- Two extra `ToListAsync` reads inside a validator are acceptable here (provisioning is a rare,
  operator-driven action) and the two-step form was kept deliberately rather than nesting a DbSet
  `.Any()` inside another DbSet's EF predicate, which would not translate.

Everything else in the validator is untouched: the DNS-label regex, the consecutive-hyphen rule, the
reserved-word blocklist, `MaximumLength(63)`, `NotEmpty` on CompanyCode, and the CompanyName /
Address / CountryId / PlanCode / CurrencyId / BillingCycle / AdminName / AdminEmail / Mode rules.

**No rollback path was added** — the engine stays resume-based by design, per §⑦.3 of the prompt.

### ②.5 🔴 Flagged — code that relied on Role codes being globally unique across tenants

The old global index guaranteed *at most one active `BUSINESSADMIN` row in the entire database*.
Two lookups leaned on that and now become ambiguous once a second tenant exists. **Not fixed — out of
this prompt's scope (§② forbids touching other config or handlers) — reporting for a follow-up patch:**

| File | Line | Code |
|---|---|---|
| `AuthBusiness/RoleCapabilities/Commands/ResetRoleCapabilityMatrix.cs` | 42-43 | `dbContext.Roles.FirstOrDefaultAsync(r => r.RoleCode == "BUSINESSADMIN" && r.IsDeleted == false, …)` |
| `AuthBusiness/RoleCapabilities/Commands/ResetRoleCapabilityMatrixForRole.cs` | 53-54 | same call, same shape |

Both fetch the "BUSINESSADMIN template role" whose `RoleCapabilities` become the reset baseline.
Neither carries a `CompanyId` filter. The reflection-built tenant query filter in
`ApplicationDbContext` (`CurrentTenantId == null || CompanyId == CurrentTenantId || IsSystem == true`)
does **not** fully save them:

- For a **platform caller** (`CurrentTenantId == null`) the filter is a no-op → `FirstOrDefault` picks
  an arbitrary tenant's BUSINESSADMIN.
- Even for a **normal tenant user**, the `|| IsSystem == true` leg admits the template company's
  BUSINESSADMIN alongside their own → again arbitrary.

Consequence: a matrix reset could seed one tenant's capabilities from another tenant's role. The fix
is a `CompanyId == CurrentTenantId` (or explicit template-company) predicate on those two reads —
one focused patch, best done before the second tenant goes live.

Checked and **clear**:
- `BulkUpdateRoleCapabilityMatrix.cs:60` — `r.RoleCode == "SUPERADMIN"` filters an already
  `roleIds`-scoped in-memory projection, not a global DB lookup.
- `ProvisionTenant.cs:752` — `OrderByDescending(r => r.RoleCode == "BUSINESSADMIN")` is a sort key
  inside the run's own company-scoped query.
- `DeleteRole.cs` / `UpdateRole.cs` / `DeleteUser.cs` / `GetUserCredential.cs` / `SwitchCompany.cs` —
  all test `RoleCode` on a role already loaded by id or reached through `UserRoles`, never by a bare
  global code lookup.
- No `RoleName ==` lookup exists anywhere in the backend.

---

## ③ P-05b / T-B7 — lead lifecycle (already landed — re-verified)

Verified present in source this session:

- `LeadManagement/LeadHelper.cs:45` — `public static bool IsAllowedManualStatusTransition(string? from, string? to)`
  plus the `_allowedStatusTransitions` table.
- `LeadManagement/Commands/UpdateLead.cs:79` — the guard fires in the not-converted `else` branch
  before `dto.Adapt(entity)`.
- `Commands/ApproveCommercialTerm.cs` — LOST pre-condition guard + auto-WON advance, both before
  `SaveChangesAsync` (one transaction).
- `Commands/CreateLead.cs` — `CreateLeadValidator` blocks `WON` at birth.

**`WON` is unreachable via `UpdateLead` — the exact rejected transitions.** `IsAllowedManualStatusTransition`
returns `true` only for same-state, `NEW → {QUALIFIED, LOST}`, `QUALIFIED → LOST`, `LOST → NEW`.
Everything else throws `BadRequestException("Illegal lead status change {from} → {to}. WON is set only
by approving a commercial term.")`:

- **→ `WON` from every state** — `NEW → WON`, `QUALIFIED → WON`, `LOST → WON` (short-circuited before
  the table is consulted; this is the guarantee the prompt asked for).
- **Funnel skips / reversals** — `QUALIFIED → NEW`, `LOST → QUALIFIED`.
- **Off `WON`** — `WON → NEW`, `WON → QUALIFIED`, `WON → LOST`. `WON` is terminal to the client.
- Any unknown/blank `from` rejects everything except same-state.

`ApproveCommercialTermHandler` is therefore the **only** producer of `WON` in the codebase.

**Create rejects `WON`:** *"A new lead cannot be created as WON — WON is earned by approving a deal."*
Creating a lead already `LOST` still works (lost-reason rule intact).

**FE dropdown gone → lifecycle action buttons.** `lead-form-dialog.tsx` has no
`FormSelect name="status"`; `lead-lifecycle-actions.tsx` holds Qualify (`NEW`→`QUALIFIED`), Mark lost
(`NEW`/`QUALIFIED`→`LOST`, with a required-reason dialog), Reopen (`LOST`→`NEW`), and a read-only
`WON` marker tooltipped "Won on deal approval". Each resends the full lead through the existing
`UPDATE_LEAD_MUTATION` — no new mutation.

**Where the buttons live — the list row's action cell**, not a detail header. S-01 has no lead-detail
route (the row click navigates to `/{lang}/ops/deals?leadId=…`), so a header would have had to be
invented on the deals screen; the row cell already `stopPropagation()`s the navigation.

---

## ④ P-05c / T-B8 — payment-gateway picker (already landed — re-verified)

- `domain/entities/ops-service/CommercialTermDto.ts:21` — `PAYMENT_GATEWAY_OPTIONS` present verbatim:
  `""` → "— Not decided —", `RAZORPAY` → "Razorpay", `STRIPE` → "Stripe", with the one-line `TODO`
  about a future `PLATFORM_PAYMENT_GATEWAYS` setting.
- `ops/deals/deal-form-dialog.tsx:35, 221` — imports the constant and binds it to a `FormSelect`; the
  free-text `FormInput` is gone.
- **Still optional, still saves `null` when blank** — `deal-form-schemas.ts` untouched
  (`z.string().trim().max(50).optional().nullable()`), and the submit path's existing
  `paymentGatewayCode: values.paymentGatewayCode?.trim() || null` turns the blank option into `null`.
- **Editing a deal with an existing code pre-selects it** — `toFormValues` maps
  `term.paymentGatewayCode ?? ""` and `FormSelect` matches on `opt.value?.toString() === value?.toString()`.
- **No BE / schema / GraphQL / seed file touched.**

---

## ⑤ P-05e / T-B10 — Document header/footer dropped from the wizard (already landed — re-verified)

A repo-wide grep for `companyHeader` / `companyFooter` / "Document header" / "Document footer" across
`PSS_2.0_Frontend/src` returns **zero hits under `page-components/ops/provisioningwizard/`**:

- `provision-wizard-schemas.ts` — `wizardTenantSchema` holds only `companyName`, `companyCode`,
  `subdomain`, `countryId`, `address`, `adminName`, `adminEmail`; `emptyProvisionWizard` matches. No
  header/footer key, no orphaned default.
- `provision-wizard-page.tsx` — no "Document header"/"Document footer" `FormInput`, and the submit
  handler's `request` object carries no `companyHeader` / `companyFooter`. Step 3's grid closes up
  cleanly (Address → Administrator name); no dangling `col-span`.

The only surviving `companyHeader`/`companyFooter` references in the FE are the **tenant-owned**
company screens (`contact-service/CompanyDto.ts`, `CompanyMutation.ts`, `CompanyQuery.ts`) — correctly
untouched — plus an unrelated WhatsApp template-card label.

**BE deliberately unchanged, as §④ of the prompt requires:** `ProvisionTenantRequestDto` still declares
`public string? CompanyHeader` / `CompanyFooter` (ProvisionTenant.cs:39-40) and the GraphQL input keeps
them. They now simply arrive `null`, and the handler's existing fallback

```csharp
CompanyHeader = string.IsNullOrWhiteSpace(req.CompanyHeader) ? req.CompanyName : req.CompanyHeader!,
CompanyFooter = string.IsNullOrWhiteSpace(req.CompanyFooter) ? req.CompanyName : req.CompanyFooter!,
```

means a completed run stamps the new tenant's `Company.CompanyHeader` / `CompanyFooter` **equal to the
company name**. **No BE property removed, no `Company` column dropped.**

---

## ⑥ Deviations / things that differed from what the prompts assumed

1. **Three of the four patches were already done.** The runner doc presented all four as outstanding;
   only 05f was. Nothing was re-applied or re-written on top of the existing 05b/05c/05e code — each
   was verified against source and reported above. (05b/05c's own deviations are documented in
   `PSS-2.0-ONBOARDING-P05BC-HANDBACK.md` §④ and still stand — notably `FormSelect`'s numeric
   coercion needing a local blank-option repair, `IsAllowedManualStatusTransition` widened to
   `string?`, and the edit dialog resending the lead's current status.)
2. **No `HasQueryFilter` calls exist in the codebase** — tenant filters are built by reflection in
   `ApplicationDbContext.OnModelCreating` via `entityType.SetQueryFilter(...)`. Relevant because it is
   what makes the §②.5 flag real: the generated filter includes an `|| IsSystem == true` leg, so it
   does not reliably scope a bare `RoleCode ==` lookup to one tenant.
3. **`ProvisionIdempotency` placement** — the prompt said "next to the DTO"; it sits between
   `ProvisionTenantRequestDto` and `ProvisionTenantResult`, `internal` and file-local as specified.

---

## ⑦ Files changed this session

**Backend (2)**
- `Base.Infrastructure/Data/Configurations/AuthConfigurations/RoleConfiguration.cs` — 3 index edits.
- `Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs` —
  `ProvisionIdempotency` helper, handler call-site swap, 2 resume-aware validator clauses.

**Frontend (0)** — 05b/05c/05e were already in place.

**Docs (2, new)**
- `PSS-2.0-ONBOARDING-P05F-MIGRATION-SPEC.md`
- `PSS-2.0-ONBOARDING-P05-FOLLOWUP-HANDBACK.md` (this file)

---

## ⑧ Your next two steps

1. **Run the migration** — `PSS-2.0-ONBOARDING-P05F-MIGRATION-SPEC.md`. Confirm the diff is
   `DropIndex` × 3 / `CreateIndex` × 3 and nothing else, then commit.
2. **Re-submit the provisioning wizard for `leadId = 2`** — no manual SQL. The resume-aware validator
   sees the `PAUSED_ON_ERROR` run owns that company and allows it; `Handle` skips the SUCCEEDED
   Steps 1 & 2, re-runs Step 3 (roles now insert cleanly per-tenant), and runs through Step 9,
   reusing the half-built company + subscription. Then finish the O-01 provisioning smoke test —
   including the 05b × 05c end-to-end eyeball: save a deal with a chosen gateway, approve it, and
   confirm (a) the gateway code persists and (b) the parent lead flips to `WON`.
