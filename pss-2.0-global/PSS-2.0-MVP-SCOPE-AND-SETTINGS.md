# PSS 2.0 — MVP Release Scope & Required Settings Screens

> **Purpose:** Define a releasable MVP-1 that lets management onboard a real client, based on the business modules already ≥70% complete — and the Settings/Onboarding screens those modules need before a client can actually use them.
>
> **Prepared:** 2026-07-22 · **Source of truth:** live screen registry (`.claude/screen-tracker/REGISTRY.md`, updated 2026-07-20) + Case Management audit (`BUGS-case-management.md`). The `PSS-2.0-PROGRESS-MONITOR.xlsx` was **not** used for status — it predates the last two build sessions.
>
> **Context:** Decided by owner after the 2026-07-21 management demo. Management wants to onboard a client and release quickly; only one developer is active. Strategy = finish the strong business modules, add a thin onboarding + settings slice, ship MVP-1; defer everything else to MVP-2.

---

## 1. Executive summary

- **MVP-1 business scope = 6 modules:** Case Management, Grants, Volunteer, Organization/Events, Contacts, and **Fundraising (core donation + receipt only)**.
- **The real gate is not the business modules — it's onboarding + settings.** A client cannot be created, configured, or logged in without them, and today there is **no Company Onboarding screen at all**. This must be built/decided regardless of business-module progress.
- **"Built" ≠ "business-ready."** Grants / Volunteer / Organization show as built in the registry but were never business-retested (the Excel delivery-lead marked them ~45% functional). Only Case Management has a real audit behind it. Each MVP module needs one **business-retest pass** before sign-off.
- **Biggest efficiency win:** most reference masters (Gender, Bank, Payment Mode, etc.) can be **SQL-seeded** instead of building ~8 CRUD screens now. Build only the screens a client actually edits during onboarding.
- **⚠️ Product-critical gap — Plans & Entitlements do not exist.** There is no `Plan`, `Subscription`, `Entitlement`, or `Quota` layer in the codebase. Today access is RBAC-only (Role→Module). Selling Free / 50K / 100K / Custom plans with feature-gating and record limits (2k contacts, etc.) needs a **new subscription + entitlement + usage-metering layer** (§6). Build the **enforcement skeleton in MVP-1**; retrofitting quota checks into dozens of existing create-handlers later is expensive.

---

## 2. MVP-1 business modules — readiness (live registry)

Effective % excludes SKIP/MERGED rows. "Business-retested" = verified against real business flow, not just build-flag.

| # | Module | Built | Eff. % | In MVP-1? | Last-mile work to reach true done |
|---|--------|-------|--------|-----------|-----------------------------------|
| 1 | **Case Management** | 5/5 | 100% | ✅ **Anchor** | Close ~3 remaining minor audit items (2 Critical + most High/Med already fixed). Demo-proven. |
| 2 | **Grants** | 4/4 | 100% | ✅ Yes | **Business-retest only** — no build work. |
| 3 | **Volunteer** | 4/4 | 100% | ✅ Yes | **Business-retest only** (#56 dashboard is SKIP, not needed). |
| 4 | **Organization / Events** | 8/10 | 80% | ✅ Yes | Finish #42 Staff (prompt ready), #45 Company alignment. |
| 5 | **Contacts** | 6/8 | 75% | ✅ Yes | Fix #19 Contact Type (minor). #23 Contact Import = optional, can defer. |
| 6 | **Fundraising — CORE ONLY** | 13/19 | ~68% | 🟡 Partial | Keep: single donation, receipt (#9 align), pledge. **Descope** #16 Crowdfund, #135 P2P, #5 Bulk, #13 Refund-realtime, #10 Online Donation Page. |

### Deferred to MVP-2 (out of scope now)
| Module | Built | Eff. % | Why deferred |
|--------|-------|--------|--------------|
| Membership | 3/4 | 75% | Member Portal (#61) still partial; not needed for first client. |
| Prayer Request | 2/3 | 67% | Replies tab (#138) partial. |
| Communication | 11/17 | 65% | WhatsApp (#32/#33/#34), Automation (#37), Email Campaign (#25) incomplete. **See "reply module" note below.** |
| Field Collection | 4/7 | 57% | Record Collection (#133), Ambassador dashboard (#134) not built. |
| Certificate | 1/2 | 50% | #130 workspace not built. |
| Reports | 4/7 | ~57% | PowerBI (#155), Custom Report Builder (#96), Viewer (#97) not built. |

> **"Reply module" clarification needed:** if the owner meant email/WhatsApp auto-reply, that lives in Communication (#132 Email Keywords, #33 WhatsApp Conversations, #138 Prayer Replies) — all currently deferred. Confirm whether a minimal auto-reply is in MVP-1 or MVP-2.

---

## 3. Settings / Onboarding screens the MVP needs

These are the screens **outside** the business modules that MVP-1 depends on. Grouped by why they're needed and current build state.

### 3A. Onboarding & Access — the release gate (MUST build)
Without these you cannot create a company, create users, or control what a client sees.

| # | Screen | Type | Status | Action for MVP | Notes |
|---|--------|------|--------|----------------|-------|
| — | **Company Onboarding** | FLOW (wizard) | ❌ **DOES NOT EXIST** | **DECISION NEEDED** | No screen/mockup/prompt anywhere. Options: (a) build a guided wizard (create company → seed masters → create admin user → pick modules), or (b) MVP-1 stopgap = use #75 Company Settings + #72 User Management manually + seed script. **This is management's literal demo question.** |
| 75 | Company Settings | Config | ✅ COMPLETED | Verify only | Org profile exists; not a guided onboarding flow. |
| 72 | **User Management** | MASTER_GRID | 🔨 PROMPT_READY | **BUILD** | Required to create the client's users. Prompt exists (`usermanagement.md`). |
| 70 | **Role Management** | Config | 🔨 PROMPT_READY | **BUILD** | Role + Capability + Role-Capability matrix. Prompt exists (`rolemanagement.md`). Required for access control. |
| 126 | **Modules** (enable/disable per company) | MASTER_GRID | 🔨 NEW | **BUILD** | Lets you ship ONLY the MVP modules to a client and hide deferred ones — directly supports the MVP strategy. |
| 71 | Menu Management | DESIGNER_CANVAS | 🔨 PROMPT_READY | **Build or defer** | Needed only if per-tenant menu customization is required at launch; otherwise static menus suffice for MVP-1. |

### 3B. Organization configuration (finish existing partials)
Per-tenant config the business modules read.

| # | Screen | Type | Status | Action for MVP | Needed by |
|---|--------|------|--------|----------------|-----------|
| 85 | Organization Settings | Config | 🟡 PARTIAL | **FINISH** | Org-wide config (number sequences, defaults) — all modules. |
| 84 | Email Provider Config | Config | 🔨 PROMPT_READY | **BUILD** | Receipt emails, any client comms (`companyemailprovider.md`). |
| 157 | SMS Setup | Config | ✅ COMPLETED | — | Optional for MVP. |
| 79 | Currency Management | MASTER_GRID | 🟡 PARTIAL | **FINISH (base currency)** | Donations/receipts — at least the client's base currency. |
| 80 | Region Hierarchy | Config | 🟡 PARTIALLY_COMPLETED | **FINISH** | Address data (Country→State→District→City→Locality→Pincode) for Contacts/Case/Beneficiary. |
| 81 | Document Types | MASTER_GRID | 🟡 PARTIAL | **FINISH** | Attachments for Grants + Case. |

### 3C. Reference masters — RECOMMEND SEED, not build
Business modules depend on these lookups, but a first client rarely edits them. **Seed via SQL for MVP-1; build the maintenance CRUD screens in MVP-2.**

| # | Master | Status | Needed by | Recommendation |
|---|--------|--------|-----------|----------------|
| 145 | Payment Mode | NEW | Donations, Receipts, Field Collection | **Seed** (build screen MVP-2) |
| 139 | Bank | NEW | Donations, bank accounts | **Seed** |
| 142 | Gender | NEW | Contacts, Beneficiary | **Seed** |
| 146 | Relation | NEW | Family, Contacts | **Seed** |
| 144 | Occupation | NEW | Contacts | **Seed** |
| 140 | Blood Group | NEW | Beneficiary, Volunteer | **Seed** |
| 143 | Language | NEW | Contacts, comms | **Seed** |
| 147 | Salutation | ✅ COMPLETED | Contacts | Done |
| 141 | Currency Conversion | ✅ COMPLETED | Donations (multi-currency) | Done |
| 76 | Master Data (combined) | PROMPT_READY | Cross-module lookups | **Build if any master must be client-editable at launch; else seed** |

### 3D. Explicitly DEFER for MVP-1
| # | Screen | Reason |
|---|--------|--------|
| 167 / 168 | Payment Gateways / Gateway Master | Online/card payments descoped (no Online Donation Page / Crowdfund in MVP-1). MVP-1 = offline/manual donations. |
| 83 | Certificate Templates | Certificate module deferred. |
| 77 | Grid Config | Custom fields — not launch-critical. |
| 78 | Dashboard Config | Dashboards deferred. |
| 86/87/88/89 | API / Integration Marketplace / Accounting / Social | Already COMPLETED but not MVP-critical; leave as-is. |

---

## 4. Recommended MVP-1 build backlog (sequenced)

**Parallelize onboarding/settings with business-module retest — do NOT leave onboarding for last, or management still can't onboard.**

1. **Onboarding gate (highest priority):** decide Company Onboarding approach → build #72 User Management, #70 Role Management, #126 Modules.
2. **Org config:** finish #85 Organization Settings, #79 Currency (base), #80 Region, #81 Document Types; build #84 Email Provider.
3. **Seed reference masters** (#139–146) via SQL — user-owned seed apply per existing process.
4. **Business last-mile:** finish #42 Staff, #45 Company, #19 Contact Type, #9 Receipt alignment.
5. **Business-retest pass** (the real "45%→done" work): Grants, Volunteer, Organization, Contacts, Case Management, Fundraising-core — one structured flow test each.
6. **Fundraising descope confirmation:** ensure Crowdfund/P2P/Bulk/Refund/Online-Page are hidden (via #126 Modules) so they don't appear half-built to the client.

---

## 5. Open decisions (need owner/management input)

1. **Company Onboarding** — build a real wizard, or MVP-1 stopgap via Company Settings + manual user creation + seed script?
2. **"Reply module"** — is minimal auto-reply in MVP-1, or fully MVP-2? (It lives in the deferred Communication module.)
3. **Reference masters** — confirm seed-not-build for MVP-1 (saves ~8 screens).
4. **Payment Gateways** — confirm MVP-1 is offline donations only (defers #167/#168).
5. **Menu Management (#71)** — static menus for MVP-1, or per-tenant customization at launch?
6. **Plans (§6)** — confirm the plan matrix (§6.3), and the MVP-1 vs MVP-2 split for the entitlement layer (§6.7). Decide over-limit behavior: hard-block vs soft-block (§6.5).

---

# 6. Plans & Entitlements — enterprise architecture

> **Full design:** `PSS-2.0-PLANS-AND-ENTITLEMENTS-APPROACH.md` (entities, `IEntitlementService`, enforcement behaviors, screens, P0–P4 roadmap). This section is the executive summary.
> **Adjacent:** `PSS-2.0-GTM-LEAD-ONBOARDING-AND-PRODUCT-ADMIN-APPROACH.md` — lead capture → sales → **tenant provisioning** → product administration. A Subscription is created by provisioning step 2; plan entitlements filter the capabilities a new tenant is granted at step 4. The two layers ship together.

> **This is the product layer that turns "an NGO app" into "a SaaS you can sell."** It does not exist yet and must be designed before the first paid client, because it changes how *every* create-flow and menu behaves. Build the **enforcement skeleton early** (§6.7) — retrofitting quota checks into 40+ existing command handlers after launch is the expensive path.

## 6.0 Records-based vs storage-based — the PM decision (researched)

**Recommendation: price on RECORDS (contacts / donation rows), not storage (GB). Model = hybrid tiered — fixed annual plan + a records value-metric + feature entitlements.**

The universal rule from SaaS pricing research: *the meter must be the unit of value the customer receives, and it must be predictable and easy to measure.* For a donor-management/CRM product sold to NGOs, that unit is **records**, not gigabytes:

| Factor | **Records** (recommend ✅) | Storage (GB) |
|--------|---------------------------|--------------|
| Category norm | Every CRM/donation platform (HubSpot, Salesforce, Mailchimp) prices on **contacts/records** — buyers already think this way | Infra/file products only (AWS, Cloudinary) |
| Buyer predictability | NGO knows *"we have 5,000 donors"* — budgetable | No NGO knows *"we use 3.2 GB"* → *"budget anxiety"* |
| Buildable today | Trivial: tenant-scoped `COUNT(*)` on existing tables, **zero new infra** | Needs byte-accounting **+ a blob store you have not provisioned** (attachments are URL links today) |
| Enforcement accuracy | `COUNT(*)` is always exact | Byte counters drift; need reconciliation jobs |

**Why hybrid-tiered, not pure usage:** 2025/26 data shows hybrid is now the most common enterprise model (~41%, fastest-growing) because pure per-seat under-charges heavy tenants and pure usage-based scares finance teams. **NGOs need a fixed annual budget** — so sell *packaged tiers* (Free/50K/100K) whose boundary is a records metric, with communication **channels** as the feature differentiator. **Custom = overrides, not a new plan row.**

**Storage's real role:** a *secondary anti-abuse guardrail* added in MVP-2/3 once blob storage exists (fair-use cap on uploaded documents) — never the primary/headline meter.

## 6.1 The core principle — three independent gates, never conflate them

An enterprise SaaS answers **three different questions** at three different layers. PSS today only has the third.

| Gate | Question | Scope | Exists today? |
|------|----------|-------|---------------|
| **1. Entitlement** (plan feature) | "Did this **tenant** pay for WhatsApp / this module?" | Company (plan) | ❌ **No** |
| **2. Quota** (plan limit) | "Has this **tenant** hit 2,000 contacts / 5M donations?" | Company (metered) | ❌ **No** |
| **3. RBAC** (role capability) | "Can this **user** perform this action?" | User (role) | ✅ Yes (`Role→Capability`, `RoleModule`) |

**Effective access = Entitlement ∩ Quota ∩ RBAC.** A user sees/uses a feature only if the plan includes it (1), the tenant is under its limit (2), **and** the user's role allows it (3). Keeping these separate is the whole architecture — collapsing plan-gating into RBAC (e.g. "just don't give Free-plan users the WhatsApp role") is the classic mistake: it breaks the moment a tenant has multiple roles, and it makes upgrades a manual role-surgery job instead of one field change.

## 6.2 Two kinds of limit — they enforce differently

- **STOCK meters** (a *count of rows that exist*): Contacts, Donation records. Limit = "how many can exist at once." Checked on **Create/Import**. Deleting frees capacity. Recomputable by `COUNT(*)`.
- **FLOW meters** (a *rate over a period*): Emails / WhatsApp / SMS sent per month. Limit = "how many actions per billing cycle." Checked on **Send**. **Resets** each cycle. Never decrements.

Mixing these up is the most common quota bug. Contacts is stock; communications are flow.

## 6.3 The plan matrix (from your spec — confirm the blanks)

| Feature / Meter | Meter type | **Free** | **50K** | **100K** | **Custom** |
|-----------------|-----------|---------|--------|---------|-----------|
| Contacts (records) | STOCK | 2,000 | 500,000 | 1,000,000 | configurable |
| Donation records | STOCK | ❓ *(0 / small?)* | 5,000,000 | 10,000,000 | configurable |
| Email channel | FLOW / feature | ❓ | ✅ | ✅ | ✅ |
| WhatsApp channel | feature | ❌ | ❌ | ✅ | configurable |
| SMS channel | feature | ❌ | ❌ | ✅ | configurable |
| Business modules included | entitlement set | ❓ *(Contacts only?)* | Contacts + Donations + Email | + all comms | all / configurable |
| Users (seats) | STOCK | ❓ | ❓ | ❓ | configurable |

> **Blanks to confirm:** (a) Does **Free** include any donations, or contacts-only? (b) Does **Free** get email at all? (c) Per-plan **module set** (which of the 6 MVP business modules each plan unlocks). (d) **Seat/user** limits per plan. (e) Are the 50K/100K names the **price** (₹50,000 / ₹1,00,000 per year?) — confirm currency + billing cycle.

**Custom plan design rule:** do **not** create a new `Plan` row per custom client. Keep one `CUSTOM` base plan and store the per-client numbers as **subscription overrides** (§6.4). Otherwise the plan catalog explodes to one row per customer.

## 6.4 Data model (new — all greenfield)

Proposed entities. Catalog is **SUPERADMIN-owned**; assignment is per `Company`.

```
Plan                     (auth or new "billing" schema — SUPERADMIN catalog)
  PlanId, PlanCode (FREE|PLAN_50K|PLAN_100K|CUSTOM), PlanName,
  Price, Currency, BillingCycle (Monthly|Annual), IsCustom, IsActive, SortOrder

PlanEntitlement          (Plan → boolean feature flags)
  PlanEntitlementId, PlanId, FeatureCode (MODULE:CONTACTS, MODULE:DONATION,
    CHANNEL:EMAIL, CHANNEL:WHATSAPP, CHANNEL:SMS, ...), IsEnabled
  ↳ FeatureCode maps 1:1 onto existing auth.Modules.ModuleCode where the
    feature IS a module — reuse the Module primitive, don't reinvent it.

PlanQuota                 (Plan → numeric limits)
  PlanQuotaId, PlanId, MeterCode (CONTACTS, DONATIONS, EMAILS, WHATSAPP, SMS,
    USERS, ...), MeterType (STOCK|FLOW), LimitValue (null = unlimited), Period (null|MONTH)

Subscription             (Company → Plan — the assignment; 1 active per company)
  SubscriptionId, CompanyId (FK app.Companies), PlanId,
  Status (Trial|Active|PastDue|Suspended|Cancelled),
  StartDate, CurrentPeriodStart, CurrentPeriodEnd, TrialEndsOn, CancelledOn

SubscriptionOverride     (per-company exceptions — powers CUSTOM & one-off deals)
  SubscriptionOverrideId, SubscriptionId,
  FeatureCode? / MeterCode?, OverrideValue      (null-vs-set = which kind)

UsageCounter             (FLOW meters = source of truth; STOCK meters = cached display only)
  UsageCounterId, CompanyId, MeterCode, PeriodStart,
  CurrentValue                                  (UNIQUE (CompanyId, MeterCode, PeriodStart))
  ↳ STOCK limits (contacts, donations) enforce via COUNT(*) on the real table (§6.5),
    NOT this row. FLOW limits (emails/mo) use this row as the authoritative counter.
```

**Effective limit resolution:** `SubscriptionOverride.OverrideValue ?? PlanQuota.LimitValue`. **Effective feature:** `override ?? PlanEntitlement.IsEnabled`. One service (`IEntitlementService`) owns this resolution + caches it per company.

## 6.5 Enforcement architecture (defense in depth — BE is truth, FE is UX)

**Backend = the only real gate. Never trust the FE.** The enforcement **order is load-bearing** (industry pattern): **① resolve tenant context → ② load cached entitlements → ③ atomic quota reservation *before* the side effect → ④ policy gate.** A tenant over its limit is refused *before* any work runs.

1. **Feature entitlement** — a MediatR pipeline behavior (mirrors the existing `TenantAccessBehavior` / `TenantIsolationBehavior`) + a `[RequiresFeature("CHANNEL:WHATSAPP")]` marker on commands/queries. Missing feature → deny `403 PLAN_FEATURE_NOT_ENTITLED`.
2. **Quota** — a guard invoked *inside the create/send handler's transaction*, before insert. **Stock and flow enforce differently (research-backed):**
   - **STOCK** (contacts, donations) → derive from the **authoritative table**: `SELECT COUNT(*) … WHERE CompanyId=@t FOR UPDATE`-guarded, `if (count >= effectiveLimit) reject(402 QUOTA_EXCEEDED)`. **Do not rely on a maintained `+1/-1` counter as the source of truth** — a `COUNT(*)` on the real table is drift-free and self-healing. (`UsageCounter` for stock is only an optional *cached display* value, refreshed by a job.)
   - **FLOW** (emails/WhatsApp/SMS per cycle) → a **maintained counter** in the current-period `UsageCounter` row (high-frequency, can't `COUNT` a rate); roll a fresh `PeriodStart` row each cycle, never decrement.
   - **⚠️ TOCTOU / race:** two concurrent creates can both read "4,999 < 5,000" and both insert → over-limit. Reserve atomically: **lock inside the txn** (`FOR UPDATE` / Postgres advisory lock) — the **exact same fix already proven in the Case Management fund guard (C-1 double-spend)**. Reuse that pattern; don't re-discover it.
   - **Bulk import** must check `count + batchSize <= limit` **once up front**, not per row.
   - **Fail-closed:** if the entitlement/quota store errors, **deny** revenue-bearing limits — never default to "allow."
   - **Block vs bill is where pricing becomes code:** a "hard" limit refuses the write (`402`); a "soft"/metered limit allows and records overage. Pick per meter (§6.5 decision).
3. **Entitlement cache** — resolve once per request, cache keyed by `CompanyId`, **short TTL (~60s) as a backstop, invalidated immediately on any plan/subscription change** (stale entitlements after a downgrade are the classic failure mode).
4. **FE = cosmetic only** — on login, call a `myEntitlements` endpoint → hide un-entitled menus/modules (drives #126 Modules from the *plan*, not manual toggles), show usage meters ("1,847 / 2,000 contacts"), and show upgrade CTAs at 80% / 100%. FE gating only avoids dead-ends; it prevents nothing.

**Over-limit behavior (decision 6):** enterprise norm is **soft-block** — warn at 80%, block *new* creates at 100% but keep existing data readable/editable (never delete or hide their data). Hard-suspend only on billing failure (`PastDue → Suspended`). **Downgrade below current usage** (e.g. has 3,000 contacts, moves to Free/2,000) → do **not** delete; set read-only-over-limit: no new contacts until they're back under. Confirm this policy.

## 6.6 Multi-tenant resolution & lifecycle

- **Resolution:** on login, resolve `Company → active Subscription → effective entitlements+quotas`, cache (per-request or short-TTL) and expose to FE. Invalidate cache on any plan change / override edit.
- **Provisioning:** the Company Onboarding wizard (§3A) ends by **creating the Subscription** (pick plan → seed entitlements). Onboarding and Plans are therefore coupled — build them together.
- **SUPERADMIN** owns the Plan catalog + assigns/overrides subscriptions. **BUSINESSADMIN** sees their plan + usage **read-only** + an upgrade request.
- **Plan change / upgrade:** one field on `Subscription` (+ optional overrides). Entitlements recompute; no role surgery. This is the payoff of keeping gate 1 separate from gate 3.

## 6.65 Per-meter increase / add-ons (client asks for "more donations only")

**Real, common ask:** e.g. on 50K plan, contacts 50% used but **donations 99% full** — client wants to raise *only* donations, not jump a whole tier. **The design already supports this** because `PlanQuota` and `SubscriptionOverride` are **per-`MeterCode`** — donations and contacts are independent dials. Raising donations edits only the `DONATIONS` override; contacts is untouched. (A monolithic "50K bundle" limit could not do this — this is *why* meters are split.)

Three ways to expose it, all on the **same entity** — pick when productizing:
- **Per-meter override** — SUPERADMIN sets `SubscriptionOverride(MeterCode=DONATIONS, OverrideValue=8_000_000)`. **✅ Works with the MVP skeleton, zero extra code.**
- **Add-on packs** (post-MVP) — sell increments ("+2M donations / ₹X"); each pack applies an override delta. The clean product form.
- **Overage billing** (post-MVP) — allow over-limit, invoice the excess; needs the billing engine.

**Dev takeaway:** the only thing to get right *now* is keeping limits **per-meter** (not one bundled number). Then donation-only increases are just a value edit on one override row.

## 6.7 What to build for MVP-1 vs MVP-2

You do **not** need self-serve billing to sell MVP-1 — you need the **enforcement skeleton** so the product genuinely gates, plus a SUPERADMIN way to assign a plan.

**MVP-1 (build now — cheap to add now, expensive to retrofit):**
- The 6 entities (§6.4) + migration (spec handed to user; user owns migrations).
- `IEntitlementService` (resolve effective features + limits, cached).
- Quota guard on the **two meters that matter first**: Contacts (stock) + Donations (stock), reusing the fund-guard lock pattern.
- Feature gate on **comms channels** (Email/WhatsApp/SMS) — cheap, and it's your headline plan differentiator.
- SUPERADMIN **Plan Catalog** + **Subscription assignment** screens (§7). Seed the 4 plans via SQL.
- FE: entitlement-driven menu hide + a usage widget on the tenant dashboard.

**MVP-2 (defer):** self-serve checkout/payment, proration, dunning/invoicing, automated PastDue→Suspend, per-user seat metering, usage analytics, plan-change UI for BUSINESSADMIN, annual-vs-monthly billing engine.

## 7. New Plans/Entitlement screens (add to the §3A onboarding gate)

| Screen | Type | Owner | Status | MVP | Purpose |
|--------|------|-------|--------|-----|---------|
| **Plan Catalog** | MASTER_GRID / CONFIG | SUPERADMIN | ❌ NEW | MVP-1 | CRUD plans + entitlements + quotas (the §6.3 matrix). |
| **Subscription Management** | MASTER_GRID | SUPERADMIN | ❌ NEW | MVP-1 | Assign Company→Plan, set overrides (Custom), status, trial/expiry. |
| **Plan & Usage** (tenant) | REPORT / dashboard widget | BUSINESSADMIN | ❌ NEW | MVP-1 | Read-only: current plan, usage vs limits, upgrade CTA. |
| #126 **Modules** | MASTER_GRID | SUPERADMIN | 🔨 NEW | MVP-1 | Becomes **plan-driven** (entitlement decides module visibility) rather than manual per-company toggles. |

---

*Status legend: ✅ done · 🟡 partial (finish) · 🔨 not built (build) · ❌ missing (does not exist)*
