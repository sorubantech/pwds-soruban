# PSS 2.0 — Company Onboarding: Build Task List

**Scope:** the onboarding process only — from a **WON lead** to an **ACTIVE tenant whose primary admin has logged in**. Lead capture and the marketing site are the GTM half and are tracked separately; they appear here only where onboarding depends on them.

**Source of truth:** `PSS-2.0-GTM-LEAD-ONBOARDING-AND-PRODUCT-ADMIN-APPROACH.md` (engine §6.4/§9, sequences §6.6, screens §5.4/§5.5, API §8.4, MVP §12) and `PSS-2.0-PLANS-AND-ENTITLEMENTS-APPROACH.md` (billing skeleton).

**Conventions carried in from project rules**
- 🔒 **Migrations are user-owned.** For any schema task I write the entity + EF config + a migration *spec*, and build to prove it compiles. **The user authors, runs, and commits the migration.** Never `dotnet ef migrations add/update/remove`.
- 🌱 **Seed files:** I write them (idempotent `INSERT … WHERE NOT EXISTS`, `sql-scripts-dyanmic` style); the user applies them.
- All `DateTime` columns `timestamptz`, values `DateTimeKind.Utc`. Audit fields `createdDate`/`modifiedDate`.
- All PKs/FKs `int` identity. `Company.CompanyId` is `int`.
- Register every new screen in `.claude/screen-tracker/REGISTRY.md` before `/plan-screens`.

**Layer legend:** `INFRA` · `BE` (.NET) · `FE` (Next.js) · `DB` (🔒 migration) · `SEED` (🌱) · `DECISION` (management, blocks a task).

---

## Blocking decisions (clear these first — each blocks a task below)

| # | Decision (from §14) | Blocks |
|---|---|---|
| D-Q4 | **Which modules ship in which plan?** (Plans doc §16 blank) | T-A5 seed, provisioning **step 4** — hard blocker |
| D-Q7 | Who owns onboarding — sales / implementation team / support? | `PLATFORM_*` role design (T-A9) |
| D-Q8 | Target time-to-live-tenant (recommend **< 1 hour** from WON) | Defines "done" for the whole engine |
| D-Q5 | Discount threshold needing management approval (e.g. >15%)? | Commercial approval routing (T-B4) |

---

## Phase 0 — Domain & infra prerequisite  *(size S, external lead time — start day one)*

> Nothing is reachable without this, and it is procurement/DNS lead time, not code. Start immediately, finish before Phase A lands.

| ID | Task | Layer | Depends on | Done when |
|----|------|-------|-----------|-----------|
| T-0.1 | Register/confirm apex domain; carve the three hostnames `www` · `admin` · `*.<product>.com` | INFRA | — | DNS zone exists |
| T-0.2 | **Wildcard DNS** `*.<product>.com` → app ingress | INFRA | T-0.1 | `anything.<product>.com` resolves |
| T-0.3 | **Wildcard TLS cert** via **DNS-01 challenge** + auto-renew | INFRA | T-0.2 | `https://x.<product>.com` serves valid cert with no per-tenant step |
| T-0.4 | Bind three host headers to one deploy: `admin`→`(master)` route group, `www`→`(public)`, `*`→tenant app | INFRA | T-0.3 | Each host routes correctly; tenant resolved from subdomain |
| T-0.5 | Reserved-subdomain blocklist as config (`www, admin, api, app, mail, static, cdn, status, support, blog, login, auth` + profanity) | BE | — | Blocklist reachable by the availability check (T-A7) |

---

## Phase A — Provisioning engine  *(size L — the hard, high-value core; do this before any wizard UI)*

### A.1 Data model

| ID | Task | Layer | Depends on | Done when |
|----|------|-------|-----------|-----------|
| T-A1 | `ops.TenantProvisioningRun` (Id, LeadId, CompanyId?, IdempotencyKey UNIQUE, Status RUNNING/SUCCEEDED/FAILED, current step, error, audit) + `ops.TenantProvisioningRunStep` (RunId, StepNo, StepName, Status, startedOn, finishedOn, error) | DB 🔒 | — | Entities + EF config compile; **migration spec handed to user** |
| T-A2 | `app.Companies` additions: `Status` (PROVISIONING/ACTIVE/SUSPENDED), `IsInternal bool`, `OnboardedOn timestamptz?` | DB 🔒 | — | Compiles; spec handed to user; existing rows default sanely |
| T-A3 | **Template company** row (`IsInternal=true`, `CompanyCode='__TEMPLATE__'`) as the clone source for roles/master-data/settings/fields | SEED 🌱 | T-A2 | Idempotent seed written; user applies; template is complete + inert |

### A.2 Plans skeleton (dependency of step 4 — build alongside, not after)

| ID | Task | Layer | Depends on | Done when |
|----|------|-------|-----------|-----------|
| T-A4 | `billing` entities: `Plan`, `PlanEntitlement`, `PlanQuota`, `Subscription` (+ `CommercialTermId` FK), `SubscriptionOverride` — all `int` keys | DB 🔒 | — | Compiles; migration spec handed to user |
| T-A5 | `IEntitlementService` + plan/entitlement seed **from D-Q4 mapping** | BE + SEED 🌱 | T-A4, **D-Q4** | Given a plan, returns the capability ∩ entitlement set that step 4 consumes |

### A.3 The command

| ID | Task | Layer | Depends on | Done when |
|----|------|-------|-----------|-----------|
| T-A6 | **`ProvisionTenantCommand`** — orchestrator: create Run, execute steps 1–9, park `FAILED` at the failing step, resume from failed step, never step 1 | BE | T-A1..T-A5 | Full green-path run creates a usable tenant; a forced mid-step failure parks + resumes correctly |
| — | ↳ Step 1 · create `app.Companies` (+ CompanyCode + **Subdomain uniqueness by index**) | BE | T-A2, T-A7 | idempotent |
| — | ↳ Step 2 · create `billing.Subscription` from approved `CommercialTerm` | BE | T-A4, T-B3 | idempotent |
| — | ↳ Step 3 · seed Roles from template (BUSINESSADMIN + standard set) | BE | T-A3 | idempotent |
| — | ↳ Step 4 · seed RoleCapability/RoleModule **filtered by plan entitlements** | BE | T-A5 | idempotent; capabilities = template ∩ plan |
| — | ↳ Step 5 · seed MasterData + MasterDataType from template | BE | T-A3 | idempotent |
| — | ↳ Step 6 · seed OrganizationSetting defaults + NumberSequence definitions | BE | T-A3 | idempotent |
| — | ↳ Step 7 · seed Field/GridField per-tenant config | BE | T-A3 | idempotent |
| — | ↳ Step 8 · create primary admin `User` (`PENDING`) + UserRole BUSINESSADMIN + **one-time activation token** (no password) | BE | T-A2 | idempotent; token single-use + expiring |
| — | ↳ Step 9 · send welcome email + stamp `Lead.ConvertedCompanyId`/`ConvertedOn` (set once) | BE | T-A8 | idempotent; Lead→CUSTOMER |
| T-A7 | **Subdomain availability + validation** service — lowercase alnum+hyphen, 3–63 chars, unique index, reserved blocklist, immutable once ACTIVE | BE | T-0.5, T-A2 | `check(subdomain)` returns available/taken/reserved/invalid |
| T-A8 | **Activation-token flow** — issue single-use expiring token (step 8), `POST /activate` sets the admin's own password on the tenant domain, marks User `ACTIVE` | BE + FE | T-A6 | Admin sets password on `<tenant>` host; token burns on use; **no password ever emailed** |
| T-A9 | `PLATFORM_*` capability family + `ProvisionTenant` authorization (NOT `IsSuperAdmin()` alone) | BE | **D-Q7** | Only platform staff can invoke provisioning; enforced in the pipeline |
| T-A10 | **Abandon-provisioning** cleanup path — DELETE-cascade allowed only for runs that never reached step 8 (no user has logged in); after step 8 → suspend, never delete | BE | T-A6 | Half-run before step 8 is cleanly removable; post-step-8 blocked |

### A.4 Provisioning API + monitor UI

| ID | Task | Layer | Depends on | Done when |
|----|------|-------|-----------|-----------|
| T-A11 | GraphQL surface (§8.4): `provisionTenant`, `resumeProvisioning`, `abandonProvisioning`, `checkSubdomain`; queries for runs/steps | BE | T-A6, T-A7, T-A10 | Wired; `PLATFORM_*` guarded |
| T-A12 | **O-03 Provisioning Run Monitor** — `MASTER_GRID` of runs + step-by-step detail (status, duration, error) + Resume/Abandon actions | FE | T-A11 | Support can see *which step failed* and resume without reading logs |
| T-A13 | **O-05 Tenant List + read-only Tenant Detail** — `/ops/tenants` control-plane list of provisioned tenants (name/subdomain/plan/status/onboarded), header nav → O-03 run monitor; read-only detail at `/ops/tenants/[companyId]` (profile + current subscription). Read-only MVP — **no** suspend/reactivate/plan-change (fast-follow). Gated `PLATFORM_TENANT_VIEW`; control-plane null-tenant reads (`IgnoreQueryFilters()` + `IsDeleted != true`); excludes `IsInternal`. No schema change. | BE + FE | T-A11, T-A12 | A platform operator sees every real tenant, opens one, reads its plan/subscription, and jumps to its provisioning history — no SQL |

**Phase A exit test:** from a seeded WON lead + approved CommercialTerm, one `provisionTenant` call yields a reachable `acme.<product>.com`, admin sets their own password via the activation link, logs in as BUSINESSADMIN, and every provisioning step shows SUCCEEDED in O-03 — with no developer and no hand-run SQL.

---

## Phase B — Assisted wizard + commercial gate  *(size M — the MVP-1 default onboarding path)*

> The commercial gate must exist because provisioning step 2 has no input without an approved `CommercialTerm`.

| ID | Task | Layer | Depends on | Done when |
|----|------|-------|-----------|-----------|
| T-B1 | `ops.CommercialTerm` entity (plan, price, currency, discount, quota overrides, Status DRAFT/APPROVED, approver, audit) | DB 🔒 | T-A4 | Compiles; migration spec handed to user |
| T-B2 | **S-01 Capture commercial terms** (`FLOW`) on the won lead | FE + BE | T-B1 | Sales captures terms; saved DRAFT |
| T-B3 | **S-02 Approve** — approval routing (management sign-off above the D-Q5 discount threshold) → `APPROVED`, Lead → WON | FE + BE | T-B2, **D-Q5** | Terms cannot reach provisioning until APPROVED |
| T-B4 | **O-01 Onboarding Wizard (assisted)** — `FLOW`, 7 steps on `admin`: company info (pre-filled from Lead) → localization → **primary administrator identity (explicit)** → subdomain (last, permanent, live availability) → plan **read-only** → review → Provision | FE | T-A11, T-A12, T-B3 | Staff fill wizard from a won lead; "Provision" calls `provisionTenant`; primary admin never omitted |
| T-B5 | Wizard ↔ engine wiring: idempotency key from `LeadId`+`CompanyCode`; double-click "Provision" never makes two tenants; failed run surfaces the "we'll email you shortly" state, resumable from O-03 | FE + BE | T-B4, T-A6 | Double-submit safe; failure path visible + resumable |
| T-B6 | Welcome email template (tenant URL + activation link) via existing `EmailTemplate` infra, platform scope | BE + SEED 🌱 | T-A8 | The single assisted-mode email renders correctly; seed applied by user |
| T-B7 | **Lead lifecycle enforcement** (follow-up patch to P-05, `PROMPT-05B`) — server-governed `Lead.Status`: ordered transition guard (`NEW→QUALIFIED→WON`, `→LOST`, `LOST→NEW` reopen), `WON` unreachable manually (derived from `ApproveCommercialTerm` only), create-time `WON` block; FE swaps the free status dropdown for lifecycle action buttons. **No schema / migration / capability / mutation.** | BE + FE | T-B2, T-B3 | `UpdateLead` rejects illegal transitions; `WON` set only on deal approval; FE dropdown removed |
| T-B8 | **Payment-gateway picker** (follow-up patch to P-05, `PROMPT-05C`) — replace the deal form's free-text `paymentGatewayCode` `FormInput` with a closed `FormSelect` (`RAZORPAY` / `STRIPE` + "— Not decided —"); field stays optional (blank → null). **FE only — no schema / migration / capability / mutation / seed.** Server-configurable gateway list deferred until a real gateway integration lands. | FE | T-B1 | Gateway is a dropdown of the two backend-named codes; blank saves `null`; edit pre-selects existing code |
| T-B9 | **Auto-approval master switch** (follow-up patch to P-05, `PROMPT-05D`) — new platform-global BOOLEAN setting `PLATFORM_DEAL_AUTO_APPROVE_ENABLED` (default `true`); gate the `SubmitCommercialTerm` `autoApproved` computation so **OFF ⇒ every deal → `PENDING_APPROVAL`** regardless of discount. Adds `LeadHelper.GetAutoApproveEnabledAsync` (reuses `GetPlatformSettingAsync`). **BE 2 edits + 1 seed row (`ops-deal-autoapprove-toggle-seed.sql`) — no schema / migration / capability / mutation / FE.** | BE | T-B1 | With setting `'false'` a 0%-discount deal lands PENDING; with `'true'`/absent, within-threshold still auto-approves |
| T-B10 | **Drop Document header/footer from O-01 wizard** (follow-up patch to P-05, `PROMPT-05E`) — remove the Step-3 `companyHeader` / `companyFooter` free-text fields from the provisioning wizard (schema + form + request payload). Redundant: `Company.CompanyHeader/Footer` are tenant-owned columns and receipts/pages/comms render from selected templates, not a parent-level string. **FE only, 2 files — no BE / schema / migration / capability / mutation / seed; `Company` columns retained; handler already defaults blank → company name.** | FE | T-B4 | Wizard Step 3 no longer shows Document header/footer; payload omits both keys; run still completes with `Company.*` = company name |
| T-B11 | **Provisioning: per-tenant Role unique indexes + resume-safe validator** (critical fix to P-03/P-04, `PROMPT-05F`) — Defect A: `RoleConfiguration` unique indexes `(RoleName,IsActive)`/`(RoleCode,IsActive)`/`(OrderBy,IsActive)` are **global** → Step 3 `SEED_ROLES` collides with the template's `BUSINESSADMIN`/OrderBy=1 role (`roles_isactive` violation), blocking every 2nd tenant; prepend `CompanyId` to all three. Defect B: `ProvisionTenantCommandValidator` rejects the resumable retry ("subdomain/code taken") → make both uniqueness `MustAsync` clauses exclude companies owned by this run's own idempotency key; extract `ProvisionIdempotency.KeyFor` shared helper. **BE: 1 config file (3 index edits) + validator + key helper; index-only migration is USER-OWNED (dev proves compile only); no rollback path (engine is resume-based); no new column/capability/mutation/query/seed/FE.** | BE | T-A6 | 2nd tenant provisions cleanly; re-submitting the stuck leadId=2 run resumes from Step 3 → SUCCEEDED, reusing the half-built company (no duplicate, no manual SQL) |

**Phase B exit test:** an implementation-team member takes a won, approved lead through O-01 in a few minutes, the tenant provisions, the customer receives exactly one welcome email, sets their own password, and lands in their tenant — the customer never touches `admin` and never holds a control-plane account (§6.6.2).

---

## Phase C — Go-live handoff  *(size S — closes the loop; can trail Phase B)*

| ID | Task | Layer | Depends on | Done when |
|----|------|-------|-----------|-----------|
| T-C1 | **O-04 / T-05 Go-Live checklist** (`CONFIG`/widget) on the tenant domain: branding · ≥1 user invited · gateway/email configured (if in plan) · contacts imported-or-skipped · one test donation | FE | Phase B | Checklist drives activation; visible to customer (± impersonation support) |
| T-C2 | Flip `Company.Status = ACTIVE` + stamp `OnboardedOn` on checklist completion (or on provision, per §6.5 policy) | BE | T-C1 | Lifecycle state correct; internal tenants excluded from metrics via `IsInternal` |

---

## Deferred to MVP-2 (self-service · Option A) — tracked, not built now

Gated on **D-Q1** ("do we sell self-service at all?"). Same engine (`ProvisionTenantCommand`), different shell:
- **O-02 / P-08** self-service wizard as a **token-authenticated public route** `www/onboarding/{token}` (token IS the auth — no account, no prospect login before the tenant exists).
- `ops.OnboardingInvite` + single-use invite token; "Send onboarding invite" action on the won lead.
- Email 1 (invitation link) + Email 2 (welcome/activation) — still no password in either.
- Plan/modules **read-only** to the customer.

---

## Critical path (one line)

**Phase 0 (start now, runs in parallel)** → T-A1/A2 → T-A4/A5 *(needs D-Q4)* → **T-A6 the command** → T-A11/A12 monitor → T-B1..B3 commercial gate *(needs D-Q5)* → **T-B4 wizard** → T-C1/C2 go-live.

Everything is blocked on **T-A6**, and **T-A6 step 4 is blocked on D-Q4**. Clear the module-to-plan mapping first.
