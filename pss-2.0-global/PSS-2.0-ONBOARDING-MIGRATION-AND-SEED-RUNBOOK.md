# PSS 2.0 Onboarding — Migration & Seed Runbook

**Date:** 2026-07-28 · **Covers:** P-01 → P-07 (all code built, nothing applied to the database yet)

This is the single ordered list of everything you must run to make the assisted onboarding flow
testable. Migrations are **yours to author, run and commit** — this runbook tells you what to author
and in what order, it does not author anything.

> **Read once before starting:** P-02 has **not** been run, so the P-02b amendment must be **folded
> into the P-02 migration**, not applied as a follow-up. If you author P-02 from its own spec alone
> you will create `billing."Plans"."Currency" varchar` and then have to drop it. See step **M2**.

---

## 0. Preconditions

| Check | Why | How |
|---|---|---|
| `com."Currencies"` is populated | Every billing seed resolves an ISO code → `CurrencyId` by JOIN. An empty table silently seeds **zero** price rows. | `SELECT count(*) FROM com."Currencies";` — expect the full ISO list, incl. `INR USD EUR GBP AUD SGD AED CAD` |
| `Base.API` is **not running** | Holds a file lock on `Base.Support.dll` / `Base.Application.dll` / `Base.Infrastructure.dll`; `dotnet ef` will fail to build. | stop the app (and any debug session in Visual Studio) before the first `migrations add` |
| Backend compiles | `dotnet ef` builds the project first; a compile error surfaces as a confusing EF error. | `dotnet build Services/Base/Base.API/Base.API.csproj -c Debug` → 0 `CS` errors |
| DB backup taken | M2 and M3 add FKs and a backfill runs in M2. | your normal snapshot |

---

## 1. Migrations — author and run in this order

Each row: author from the spec, review the generated `Up`/`Down`, run, commit.

### M1 — `Add_Ops_TenantProvisioning_And_Company_Columns`

**Spec:** `PSS-2.0-ONBOARDING-P01-MIGRATION-SPEC.md`

- new schema `ops`
- new table `ops."TenantProvisioningRuns"` (spec §2)
- new table `ops."TenantProvisioningRunSteps"` (spec §3)
- **additive** columns on `app."Companies"` (spec §4) — nullable, no backfill needed
- spec §5 lists columns deliberately left **without** an FK — leave them alone

**Verify:** `SELECT table_name FROM information_schema.tables WHERE table_schema='ops';` → 2 tables.

---

### M2 — `Add_Billing_Plans_Subscriptions_Usage` ⚠ **fold P-02b in**

**Specs:** `PSS-2.0-ONBOARDING-P02-MIGRATION-SPEC.md` **+** `PSS-2.0-ONBOARDING-P02B-MIGRATION-SPEC.md`

Author as **one** migration combining both:

| From P-02 | From P-02b |
|---|---|
| new schema `billing` | `Plans."CurrencyId" int NOT NULL` **instead of** `Plans."Currency" varchar` (P-02b §0 — the string column never exists, so no add-backfill-drop dance) |
| `billing."Plans"` | new table `billing."PlanPrices"` (P-02b §1) |
| `billing."PlanEntitlements"` | `Subscriptions` currency/amount snapshot columns (P-02b §2) |
| `billing."PlanQuotas"` | — |
| `billing."Subscriptions"` (incl. the filtered UNIQUE index on the active set) | — |
| `billing."SubscriptionOverrides"` | — |
| `billing."UsageCounters"` | — |

All three currency columns — `Plans.CurrencyId`, `PlanPrices.CurrencyId`, `Subscriptions.CurrencyId` —
are `int` FKs → `com."Currencies"`, `ON DELETE RESTRICT`. **Not** ISO strings. (`Subscriptions."Currency"`
remains the ISO **snapshot value** — that is a different column and stays a string.)

P-02b §3 describes a backfill of the snapshot columns on existing subscription rows — there are none
yet on a clean database, so it is a no-op here. Keep it in the migration anyway; it makes the migration
correct if it is ever run against an environment that already has rows.

**Verify:**
```sql
SELECT table_name FROM information_schema.tables WHERE table_schema='billing';  -- 6 tables
SELECT column_name FROM information_schema.columns
 WHERE table_schema='billing' AND table_name='Plans' AND column_name LIKE 'Curren%';
-- expect CurrencyId only; if you see "Currency" varchar, P-02b was NOT folded in — fix before seeding
```

---

### M3 — `Add_Ops_Leads_And_CommercialTerms`

**Spec:** `PSS-2.0-ONBOARDING-P05-MIGRATION-SPEC.md`

- `ops."Leads"` (spec §1)
- `ops."CommercialTerms"` (spec §2)
- spec §3 lists columns intentionally **without** a database FK — leave them
- spec §4 is **optional** (activating four deferred FK columns, not modelled in EF). **Skip it for
  now** — it is not needed to test the flow and it is not represented in the EF model, so a later
  `migrations add` could try to drop what you added by hand.

**Verify:** `SELECT count(*) FROM ops."Leads";` → 0 rows, no error.

---

## 2. Seeds — run in this order

Location: `sql-scripts-dyanmic/`. All are idempotent; re-running is safe.

| # | Script | Needs | Seeds |
|---|---|---|---|
| S1 | `ops-template-company-seed.sql` | M1 | the single `__TEMPLATE__` company **shell** (`IsInternal=true`, `Status='PROVISIONING'`) that every new tenant is cloned from |
| S2 | `ops-platform-rbac-seed.sql` | — (existing `auth` tables) | PLATFORM module · 5 `(master)` menus · the 10 `PLATFORM_*` capabilities · 5 internal-staff roles · role→capability bundles (D-Q7) |
| S3 | `billing-plan-catalog-seed.sql` | M2 + `com."Currencies"` | the 4 tiers (FREE / PLAN_50K / PLAN_100K / CUSTOM) with their entitlement + quota matrix, verbatim from the D-Q4 map |
| S4 | `billing-backfill-subscriptions.sql` | S3 | a default `CUSTOM / Active` subscription for **every** existing company incl. `__TEMPLATE__`, so the entitlement resolver never fail-closes a live tenant |
| S5 | `billing-plan-prices-seed.sql` | S3 | the curated price book — PLAN_50K + PLAN_100K × 8 currencies × both billing cycles. FREE and CUSTOM get no rows **by design** |
| S6 | `ops-lead-deal-seed.sql` | M3 | PLATFORM setting group · 3 platform-global settings (discount threshold **15%**, activation-URL template, default lang) · `PLATFORMEMAIL` email category · the `TENANT_ADMIN_ACTIVATION` welcome email template |

**S3 before S4 before S5** is not cosmetic: S4 assigns the CUSTOM plan (must exist), and S5's price
rows reference plans by code (must exist).

**Verify after all six:**
```sql
SELECT "PlanCode", "CurrencyId" FROM billing."Plans" ORDER BY "PlanCode";        -- 4 rows, CurrencyId not null
SELECT count(*) FROM billing."PlanPrices";                                        -- > 0  (0 ⇒ com.Currencies was empty)
SELECT count(*) FROM billing."Subscriptions" WHERE "Status"='Active';             -- one per existing company
SELECT "CompanyCode","Status","IsInternal" FROM app."Companies" WHERE "CompanyCode"='__TEMPLATE__';
SELECT count(*) FROM auth."Capabilities" WHERE "CapabilityCode" LIKE 'PLATFORM%'; -- 10
```

---

## 3. Populate the template company — the step that is easy to forget

S1 seeds only a **shell**. Provisioning steps 3–7 clone roles, master data, settings and field
configuration **from this company**. If it is left empty, every tenant you provision comes out with no
roles, no master data and no settings — and it will look like the provisioning engine is broken.

Populate it through the **normal application UI**, logged in against the `__TEMPLATE__` company
(design §9.2 option A — deliberately not a script, so the template stays editable by the business):

1. Roles and their capability matrix (the tenant-side roles a new charity should start with)
2. Master data every tenant needs — salutations, document types, donation purposes, case categories…
3. Company Settings + General Settings defaults (the setting groups)
4. Number-sequence definitions (receipt, case, grant, event…)
5. Menu visibility / module set for a baseline tenant

> Whatever you leave out here is what every future customer will be missing. Worth a business
> review pass before the first real provisioning run.

---

## 4. Smoke test — assisted flow, end to end

Run in this order; each step is independently observable in the control plane.

| # | Action | Expect |
|---|---|---|
| 1 | Sign in as an internal user holding a `PLATFORM_*` role (S2) | `/ops` surface reachable; tenant list renders (P-07) |
| 2 | Create a Lead (S-01) | row in `ops."Leads"` |
| 3 | Add commercial terms with a discount **above 15%** (S-02) | approval required — exercises the S6 threshold setting |
| 4 | Approve → mark WON | lead moves to the won state, feeds the wizard |
| 5 | Run the O-01 wizard (7 steps) → provision | a `ops."TenantProvisioningRuns"` row + its step rows |
| 6 | Watch the provisioning monitor (P-04) | each step completes; a failed step is retryable, not the whole run |
| 7 | Check the new tenant | appears in the tenant list with its plan and status; roles/master data/settings copied from `__TEMPLATE__` |
| 8 | Welcome / activation email | `TENANT_ADMIN_ACTIVATION` sent, activation link built from `PLATFORM_ACTIVATION_URL_TEMPLATE` |

**DNS is only needed for the final hop** — the prospect opening their own tenant subdomain from the
activation link. Steps 1–7 are all testable before DNS is stood up, so do not let Phase 0 DNS block
this test.

---

## 5. Known open items (not blockers for the test)

- **`Company.Status` vocabulary is not formally enumerated** — BE documents
  `PROVISIONING | ACTIVE | SUSPENDED | CHURNED`; the subscription side uses
  `Trial | Active | PastDue | Suspended | Cancelled`. The tenant status chip maps both and falls back
  to a neutral chip showing the raw value. Confirm the canonical set and promote it to a shared constant.
- **No tenant lifecycle actions yet** — the tenant detail screen is read-only; Suspend / Reactivate /
  Change-plan need their own prompt (commands + capability + audit trail).
- **P-08 not generated** — the public product-page lead-capture (`EXTERNAL_PAGE` → `ops.Lead`).
  Deliberately queued until the assisted flow above is verified.
- **D-Q8 open** — target time-to-live-tenant (recommended < 1 hr). This defines "done" for the engine;
  time the smoke test above and use the number to settle it.
- **D-Q5** — the 15% discount-approval threshold is a tunable platform setting; confirm or override
  the default.
