# Custom-field limits — make plan tiering actually take effect

Repo root: `d:\Repos\PWDS\pwds-soruban - Copy\pss-2.0-global`

**Standing rules for this session**
- Stage only (`git add`). NEVER `git commit`, push, amend, or tag. No `Co-Authored-By` trailer anywhere.
- Do NOT run `dotnet build` — the user builds.
- Do NOT run `ef migrations add`, do NOT edit `ApplicationDbContextModelSnapshot.cs`. State the migration; the user creates it.
- Do NOT execute SQL against any database. Idempotent scripts, handed off.
- `PSS_2.0_Backend` / `PSS_2.0_Frontend` are nested git repos — `cd` into each to stage.
- PostgreSQL, not SQL Server.
- Enterprise-level app. No shortcuts. Backend enforcement, never frontend-only.

**Collision warning — read first.** A separate session owns the custom-fields governance work and is
actively editing `Base.Application/CommonServiceFeatures/CustomFields/**`,
`Base.Infrastructure/Services/CustomFields/**` and `CustomFieldsGuardInterceptor.cs`. **Do not edit
those files.** This task consumes what that session built; it does not modify it. If you believe a
change is needed inside `CustomFieldPolicy` / `ICustomFieldPolicy` / `CustomFieldPolicyOptions`, stop
and report it rather than editing — say exactly what and why.

---

## Current state

Custom-field limits already resolve through three tiers, and the resolution is correct:

1. `CustomFieldPolicyOptions` — `appsettings` section `CustomFields`, the global default.
2. `billing.PlanQuotas` — per plan, keyed by `MeterCode`.
3. `billing.SubscriptionOverrides` — per tenant, layered over the plan by `EntitlementService`.

`CustomFieldPolicy.Merge` distinguishes an **absent** meter (fall back to the configured default) from
**present-and-zero** (the plan genuinely forbids it). That distinction is load-bearing — do not break
it, and do not "simplify" it into a `GetLimitAsync` call, which is fail-closed for billing and would
resolve every tenant to zero.

Two governance meter codes are reserved in `CustomFieldMeterCodes`:

| Code | Governs |
|---|---|
| `CUSTOM_FIELDS` | max custom field definitions per entity |
| `CUSTOM_FIELDS_FILTERABLE` | max fields marked filterable/sortable — this is the index budget |

They are **deliberately excluded from `MeterCodes.All`**, because they are governance ceilings, not
consumption meters a tenant is billed against. Keep that exclusion. Everything below exists because of
it.

**The mechanism works and is not in use.** No `PlanQuota` row declares either code, so every tenant on
every plan silently resolves to the appsettings default, and plan tiering is inert.

---

## What to build

### A. Seed the plan quotas

Deliver an **idempotent** seed script adding `billing."PlanQuotas"` rows for both codes across every
plan in the catalog.

- Read `Base.Application/Interfaces/BillingCodes.cs` → `PlanCodes` for the real plan set. Do not
  invent tiers.
- `MeterType` = `STOCK`, `Period` = `NULL` — these are live ceilings, not per-period rates. Confirm
  against `PlanQuota`'s own doc comment and the existing seeded quota rows before you write it; match
  what `CONTACTS` / `USERS` do.
- Respect `UNIQUE (PlanId, MeterCode)`. `ON CONFLICT` or `WHERE NOT EXISTS` — either, but it must be
  re-runnable.
- **Propose the numbers, do not guess silently.** Put the proposed per-plan values in a table in your
  report with a one-line rationale each, and state clearly that the user owns the final numbers. Anchor
  them to the configured defaults (50 fields / 5 filterable) — the mid tier should land near the
  default so existing tenants see no change on the day the seed runs.
- `CUSTOM_FIELDS_FILTERABLE` is an **index budget**, not a feature knob. Every filterable field earns a
  B-tree expression index on a 500K-row table. Say in your report what a generous value on the top tier
  actually costs in write throughput and disk, so the number is chosen with that in front of the user.
- `LimitValue = NULL` means unlimited and is honoured as unlimited. Do not use NULL on any tier for
  `CUSTOM_FIELDS_FILTERABLE` — unlimited indexes is not a product decision anyone means to make. Say so
  if you disagree, with reasoning.

**Deployment ordering matters.** Seeding a value *below* what a tenant already uses must not break
them. Deliver an audit query that lists, per company, the current count of custom field definitions and
filterable definitions per entity, so the user can confirm no tenant exceeds its proposed plan ceiling
before running the seed. State what the enforcement code does today when an existing tenant is already
over a newly lowered ceiling — read the guard/create paths and report the actual behaviour, do not
assume it degrades gracefully.

### B. Platform plan editor must be able to set these

`CUSTOM_FIELDS` is not in `MeterCodes.All`, and the frontend meter list in
`presentation/hooks/useEntitlements/index.ts` mirrors that array. So the platform-side plan editor
almost certainly cannot enter these codes at all, and would render them unlabelled if it could.

- Verify what the plan editor actually does today — find the screen that writes `PlanQuotaInputDto`
  through `PlanCatalogMutations`, and report whether the meter code is a fixed picker, free text, or
  something else. Read it; do not assume.
- Make both governance meters selectable **with a label and a description**, without adding them to
  `MeterCodes.All` and without them leaking into billing seeding or usage display.
  The clean shape is a separate governance-meter list on both sides that the editor unions in for
  selection only. Propose the shape you chose and why.
- The editor must make the semantics visible: these are **ceilings**, not consumption. A quota row for
  `CUSTOM_FIELDS` does not bill anyone. If the existing editor UI implies metering (usage columns,
  period selectors), the governance meters must not render those controls.
- Backend validation, not frontend-only: the mutation that saves a plan quota must reject an unknown
  `MeterCode`, and must reject `Period` set on a STOCK meter. Check whether that validation already
  exists before adding a second one.

### C. Keep governance meters out of the tenant usage surfaces

`plan-usage-panel.tsx` renders every meter the entitlement response carries as a consumption bar.
A row reading "Custom Fields 12 / 50 used" in a tenant's billing screen is wrong — it implies a
metered resource they are being charged for, and it will generate support tickets asking why the
number does not appear on the invoice.

- Exclude governance meters from `plan-usage-panel.tsx`, `communication-usage-panel.tsx` and
  `plan-status-banner.tsx`. Follow the existing `COMMUNICATION_METER_CODES` partition pattern rather
  than inventing a second filtering idiom.
- Check `plan-enforcement-provider.tsx` and `quota-guard.tsx`: confirm a governance meter reaching
  either does not produce an "upgrade to add more" interstitial in the wrong place. If the custom-field
  limit *should* produce an upgrade CTA, it belongs on the custom-field admin screen at the point of
  creation — say whether it exists there today.
- Verify the exclusion is by an explicit list, not by string prefix matching on `CUSTOM_`. Prefix
  matching will silently swallow a future real meter.
- Decide and state whether the tenant should see their custom-field ceiling **anywhere**. They should —
  a tenant hitting a limit needs to know the limit exists. Propose where (the custom-field settings
  screen, as a "12 of 50 used" caption next to the create button, is the obvious candidate) and build
  it if it is not already there.

---

## Explicitly out of scope

- Any change to `MaxValueLength`, `MaxDocumentBytes` or `MaxDocumentKeys`. Those are engine limits
  (TOAST threshold, B-tree page size), not commercial levers, and they stay global by design.
- Any change to the `text` → `jsonb` conversion or the index planner. Different session.
- Adding either governance code to `MeterCodes.All`.

---

## Output

Stage everything (`git add` in each affected repo). Report:

1. The proposed per-plan values for both meters, in a table, with rationale — and an explicit statement
   that the user owns the final numbers.
2. What a generous `CUSTOM_FIELDS_FILTERABLE` value costs in indexes, write throughput and disk at the
   500K-rows-per-tenant target.
3. The seed script filename, and confirmation it is idempotent and re-runnable.
4. The audit query, and what the enforcement code actually does today for a tenant already over a
   newly lowered ceiling.
5. What the plan editor did before your change, and the shape you chose to make governance meters
   selectable without polluting `MeterCodes.All`.
6. The backend validation on the plan-quota save path — what existed, what you added.
7. Every tenant-facing surface you excluded governance meters from, and how the exclusion is expressed.
8. Where a tenant can see their own custom-field ceiling, and whether you built it or found it.
9. Confirmation that no migration is required — or, if you believe one is, exactly why.
10. Confirmation that you edited nothing under `CommonServiceFeatures/CustomFields/**` or
    `Services/CustomFields/**`, and anything you would have changed there but did not.
11. Anything you could not complete and why.
