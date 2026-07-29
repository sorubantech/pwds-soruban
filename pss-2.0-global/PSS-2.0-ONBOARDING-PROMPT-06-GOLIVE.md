# DEV PROMPT P-06 — O-04 Go-Live Checklist + `Company.Status → ACTIVE` (Phase C, go-live handoff)

> Paste everything below the line into a **fresh development session**. It is self-contained.
> This is the **final** onboarding phase — it closes the loop from a provisioned tenant to a live customer.
> When done, report the outcome to the PM session.

---

## Role & mission

You are a Senior Full-Stack Developer on the PSS 2.0 multi-tenant .NET + Next.js platform (**backend target framework `net10.0`**). Your task is **P-06: build the go-live handoff** — the customer-facing checklist that turns a **provisioned** tenant (Company `Status = PROVISIONING`, admin has activated their account) into a **live** tenant (`Status = ACTIVE`, `OnboardedOn` stamped, Customer Success owns the relationship from here).

Two deliverables:

1. **T-C1 — O-04 Go-Live Checklist** — a customer-facing `CONFIG`-style checklist screen **on the tenant domain** that surfaces the readiness items from §6.5 (branding · ≥1 additional user invited · gateway/email configured *if in plan* · contacts imported-or-skipped · one test donation), each item's status **derived server-side from real tenant data**, with a progress indicator and a **"Go Live"** action enabled only when the required items are satisfied.
2. **T-C2 — Status flip** — a `CompleteGoLiveCommand` that (re-)verifies the required items server-side and flips `Company.Status = ACTIVE` + stamps `OnboardedOn = DateTime.UtcNow`. Idempotent (already-`ACTIVE` = no-op). Internal tenants (`IsInternal = true`) are excluded from activation metrics by that flag — you do not build the metrics, you just honor the flag.

Everything upstream exists: the provisioning engine (P-03) creates the Company in `PROVISIONING` and **never** flips it (it deferred that to here); the API + monitor + activation endpoint (P-04); the lead/deal/wizard funnel (P-05). **P-06 is the last mile — the customer's own first-run experience, not a control-plane screen.**

## Read first (grounding — do not skip)

1. `PSS-2.0-ONBOARDING-TASK-LIST.md` — **T-C1, T-C2** (Phase C) are your scope. Note T-A2: `app.Companies` was to gain `Status` / `IsInternal` / `OnboardedOn` (spec handed to the user — **verify these columns exist** before relying on them; see constraints).
2. `PSS-2.0-GTM-LEAD-ONBOARDING-AND-PRODUCT-ADMIN-APPROACH.md` — **§6.5 (Go-live)** is the exact checklist + the ordering (`PROVISIONED → admin sets password → checklist → Status = ACTIVE`). **§6.6.1 step 9's "Company ACTIVE"** is the *self-service* future path — **it does not apply here**: this build flips to ACTIVE on **checklist completion**, matching P-03 which deliberately created the Company as `PROVISIONING`. **§11** for the domain boundary: this screen is on the **tenant domain** (`(core)` route group), gated by the tenant's **BUSINESSADMIN** capability — **not** the `(master)` control-plane / `PLATFORM_*` caps that P-04/P-05 used.
3. `PSS-2.0-ONBOARDING-P03-HANDBACK.md` — confirms `Company` lives in `app` schema, is created `Status = PROVISIONING` and **never** flipped (§2 step 1, §6). The admin user is created with no password + activation token (P-04 consumes it).
4. **Prior-phase reality:** if the P-05 hand-back reported deviations (entity/route/capability names), reconcile against them. P-06 depends little on P-05 internals — it reads the **Company** row + ordinary tenant data (users, contacts, donations, settings) — but confirm the `Company` entity's real field names.
5. **The real anchor files** (paths below) — the `Company` entity + its `Status`, a `CONFIG`/settings-page screen to model the checklist layout on, the `OrganizationSetting` KV read/write path, `IEntitlementService` (to conditionally show plan-gated items), and a simple `ICommand` handler. Open each before writing; do not assume property names. Audit fields are `CreatedDate`/`ModifiedDate` (from `Entity` base).

## Hard constraints (violating any of these fails the task)

- 🔒 **Migrations are strictly user-owned.** Do **NOT** run `dotnet ef migrations add` / `database update` / `remove`, and do **NOT** hand-author a migration/model-snapshot. **Aim for zero schema change** (see below). If `Company.OnboardedOn` / `IsInternal` turn out **not** to exist yet (T-A2 was a spec, may be unapplied), hand the user a **migration spec (markdown)** for exactly those columns — do not author it. `Status` already exists (P-03 writes it).
- 🚫 **No new tables for checklist state.** Persist any "skipped" decisions (e.g. *contacts import skipped*) as **`sett.OrganizationSetting` KV flags** (e.g. `GOLIVE_CONTACTS_SKIPPED = true`), reusing the existing settings KV path — **not** a new entity. This keeps P-06 schema-free.
- **Tenant context, not platform.** Unlike P-04/P-05, this runs in a **normal tenant context** (`CurrentTenantId` = the tenant's `CompanyId`). Do **NOT** use `IgnoreQueryFilters()` here — the global filter is exactly what you want; every count/read is naturally scoped to the acting tenant. Gate on **BUSINESSADMIN**, not `PLATFORM_*`.
- **Server-authoritative checklist.** Each item's satisfied/unsatisfied state is **computed on the backend from real data** (counts/settings), never trusted from the client. The `CompleteGoLiveCommand` **re-derives** the required items and refuses the flip if any required item is unmet — the button being enabled on the client is a convenience, not the gate.
- **UTC only.** `OnboardedOn = DateTime.UtcNow` (Kind=Utc); `timestamp with time zone`.
- **All PKs/FKs `int`.** No new Guid keys.
- **Idempotent + safe.** Flipping an already-`ACTIVE` company is a no-op success. Never move `ACTIVE → PROVISIONING`. Do not touch `IsInternal` (set at provision/seed time).
- **Verify every property name before use** (Company fields, settings ParamCodes, the donation/contact/user table names). Read the entity first.
- **Reuse-or-create for FE;** design tokens only (no hex/px), @iconify Phosphor icons, solid `bg-X-600 + text-white` status chips, shaped skeletons, empty/error states, responsive.

## Codebase anchors (study these, then follow them)

- **`Company` entity** (`app` schema) — its `Status` field (values `PROVISIONING`/`ACTIVE`/`SUSPENDED`) + confirm `OnboardedOn` / `IsInternal` presence. This is what T-C2 flips.
- **A `CONFIG` / settings-page screen** — find an existing `SETTINGS_PAGE`-style screen (a single-record, section-grouped page — e.g. the Company/Organization Settings screens) to model O-04's layout on: card sections, each a checklist row with a derived status chip + a CTA/skip. Reuse the settings-page primitives; O-04 is **not** a list-of-N grid.
- **`OrganizationSetting` KV path** — how settings are read/written (the #75/#85 settings surface). Use it to (a) check branding is populated (logo/colour keys) and (b) store the skip flags.
- **`IEntitlementService`** — resolve whether the tenant's plan includes payment-gateway / email so the "configure gateway/email" item **only appears when it's in the plan** (an item not in the plan is neither shown nor required).
- **Count queries** — the real Users / Contacts / Donations tables + their tenant-scoped access, for the "≥1 additional user", "contacts imported", "one test donation" items. Confirm table/entity names.
- **A minimal `ICommand<T>` + handler + GraphQL mutation** wrapper (the `IMutations` pattern from P-04/P-05) for `CompleteGoLive`, resolving the acting user from the `UserId` claim for the audit stamp.

## Scope — build exactly this

### T-C1 · O-04 Go-Live Checklist (tenant domain, customer-facing)

A single-page `CONFIG`-style checklist on the **`(core)` tenant surface**, gated **BUSINESSADMIN**, listing the §6.5 readiness items. Each row shows: label, short helper text, a **derived status** (satisfied ✓ / not-yet / skipped), and a CTA (deep-link to the relevant setup screen) or a **Skip** control where the item is optional.

Items (each **derived server-side**):
| Item | Satisfied when | Required? |
|---|---|---|
| **Branding uploaded** | branding settings (logo + primary colour keys) are populated in `OrganizationSetting` | **required** |
| **≥1 additional user invited** | `COUNT(auth.Users for this tenant) > 1` (beyond the primary admin) | **required** |
| **Payment gateway / email configured** | the relevant provider settings are set — **only shown & required when the plan includes it** (`IEntitlementService`); absent from plan ⇒ omitted | conditional |
| **Contacts imported** | `COUNT(contacts) > 0` **OR** `GOLIVE_CONTACTS_SKIPPED = true` | required-unless-skipped |
| **One test donation recorded** | `COUNT(donations) > 0` | **required** |

- A **progress indicator** (n of m required complete). A **"Go Live"** button gated on all required items satisfied (per the form-enablement rule: capability controls visibility, readiness controls enablement) → calls `CompleteGoLive` (T-C2) → on success show the "You're live" state and reflect `Status = ACTIVE`.
- Expose a **query** (e.g. `GetGoLiveChecklist`) returning each item's derived state + the overall `canGoLive` flag + current `Company.Status`, so the screen renders from one server-authoritative payload (don't compute readiness in the browser).
- The **Skip** control (contacts only) writes the `GOLIVE_CONTACTS_SKIPPED` KV flag via the settings path and refetches.

### T-C2 · `CompleteGoLiveCommand` — flip to ACTIVE

- `CompleteGoLiveCommand : ICommand<…>` (+ `IMutations` wrapper `CompleteGoLive`, gated BUSINESSADMIN, acting user from `UserId` claim).
- **Re-derives** the required checklist items server-side; if any required item is unmet → return an error listing what's missing (do not flip).
- On success: `Company.Status = "ACTIVE"`, `Company.OnboardedOn = DateTime.UtcNow` (Kind=Utc), save. **Idempotent:** if already `ACTIVE`, return success without re-stamping `OnboardedOn`. Never flips a `SUSPENDED` company (out of scope — return a clear error).
- Audit `GO_LIVE` (acting user + company). No email, no external emit — the §6.5 "Customer Success owns the relationship" handoff is a manual/CRM step, not built here.

## Out of scope for P-06 (do NOT build)

- **Impersonation / "support view"** of the checklist — §6.5 notes it as a *± support* nicety; not this prompt.
- **The in-app first-run widget (T-05)** as a separate dashboard widget — O-04 is the deliverable; a dashboard widget is a later enhancement.
- **Suspend / offboard / reactivate lifecycle**, and any `SUSPENDED` transitions.
- **Activation-rate / time-to-live metrics dashboards** — you honor `IsInternal` but build no metrics (D-Q8's target time-to-live is a **reporting SLA, not a code gate** — it does not block P-06).
- **Self-service (Option A) public onboarding** — this is the assisted path's final step only.
- **Any schema beyond confirming/spec'ing `Company.OnboardedOn` + `IsInternal`.**

## Definition of done

1. Solution **builds clean** (`dotnet build` real exit 0). If the user says they'll build it, prove correctness by reading and say so.
2. **T-C1 O-04** checklist screen on the **`(core)` tenant surface**, BUSINESSADMIN-gated, renders each §6.5 item from a **server-authoritative** `GetGoLiveChecklist` query with derived statuses; plan-gated item shown only when in plan (`IEntitlementService`); contacts **Skip** writes the KV flag; progress indicator + **Go Live** button enabled only when required items are met.
3. **T-C2 `CompleteGoLiveCommand`** re-derives required items, flips `Status = ACTIVE` + stamps `OnboardedOn = UtcNow`, is **idempotent**, refuses on unmet items / `SUSPENDED`, audits `GO_LIVE`. Exposed as the `CompleteGoLive` mutation.
4. **No `IgnoreQueryFilters()`** (tenant context) and **no new tables** — skip-state is `OrganizationSetting` KV.
5. **Zero schema change**, OR a **migration spec (markdown)** for `Company.OnboardedOn` / `IsInternal` **only if** they don't already exist. No migration authored/run. No SQL executed.
6. UI uniformity + reuse-or-create honored; empty/error/"already live" states present.
7. A short **hand-back note**.

## Report back to the PM session

State: build clean (Y/N, or "left to user"); whether `Company.OnboardedOn` / `IsInternal` **already existed** (or a migration spec was handed over); the **exact checklist items** built + how each is derived (which tables/settings) + which item(s) you made plan-conditional; that the flip is **idempotent + server-re-derived** (Y/N); confirmation it's on the **tenant `(core)` surface / BUSINESSADMIN** (not `PLATFORM_*`); and **every property / table / setting-ParamCode / route name that differed** from this brief. This is the **final onboarding phase** — note the loop is closed (WON lead → ACTIVE tenant).
