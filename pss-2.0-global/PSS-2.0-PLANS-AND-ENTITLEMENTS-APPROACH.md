# PSS 2.0 — Plans, Subscriptions & Entitlements — Implementation Approach

> **Status:** Design / approach doc — **build later** (not in the immediate MVP-1 onboarding gate). Design is locked; this document is the blueprint the build pipeline follows when scheduled.
> **Prepared:** 2026-07-22 · **Owner:** Karthick · **Companions:** `PSS-2.0-MVP-SCOPE-AND-SETTINGS.md` §6 (executive view) · `PSS-2.0-GTM-LEAD-ONBOARDING-AND-PRODUCT-ADMIN-APPROACH.md` (where a Subscription is *created* — provisioning step 2 — and where plan entitlements filter the capabilities a new tenant receives — step 4).
> **Migration rule:** all EF migrations are **user-owned** — this doc specifies entities/columns; the developer authors + applies the migration and seed. No `dotnet ef migrations add/update` is run on the user's behalf.

---

## 0. TL;DR — the decisions already made

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | **Records-based metering, not storage** | It's a CRM/donation product; buyers think in contacts/donors; measurable via `COUNT(*)`; no blob store exists to meter GB. |
| D2 | **Hybrid tiered model** | Fixed annual plan (predictable for NGO budgets) + records value-metric + channel feature entitlements. |
| D3 | **Three independent gates** | Entitlement ∩ Quota ∩ RBAC — never collapse plan-gating into roles. |
| D4 | **Per-meter limits** (one row per meter) | Lets a client raise *only* donations without a full tier jump; enables add-on packs later. |
| D5 | **BE = truth, FE = cosmetic** | All enforcement server-side in the MediatR pipeline; FE only hides menus + shows usage. |
| D6 | **Additive / build-anytime** | Layer is purely additive; the expensive part (design) is done here. Build after the onboarding gate, before onboarding a 2nd differently-pland client. |
| D7 | **Custom = overrides, not new Plan rows** | One `CUSTOM` base plan + `SubscriptionOverride` rows per client. |

**Open decisions still needing management input:** see §16.

---

## 1. Current state (what exists vs. what's missing)

**Exists (the primitives we build on):**
- `Company` (`app.Companies`) — the tenant. No plan/limit fields today.
- `Module` (`auth.Modules`) + `RoleModule` — module access **by role** (RBAC). `ModuleCode` is the natural key we reuse for `MODULE:*` feature codes.
- `Menu`, `Grid`, `Role`, `Capability`, `RoleCapability` — RBAC matrix.
- `OrganizationSetting` — per-tenant EAV config.
- **MediatR pipeline** with `[TenantScope]` attribute + behaviors: `TenantIsolationBehavior → TenantAccessBehavior → AuthorizationBehavior → CommandValidationBehavior → …` (`Base.Application/Behaviors/`). `ITenantContext` exposes `GetCurrentTenantId()`, `IsSuperAdmin()`, `GetAccessibleCompanyIds()`.
- CQRS commands like `CreateContactCommand(ContactRequestDto) : ICommand<CreateContactResult>`, donation composite `CreateGlobalDonationWithChildrenRequestDto`. Handlers take `IApplicationDbContext`.

**Missing entirely (this whole doc):** `Plan`, `PlanEntitlement`, `PlanQuota`, `Subscription`, `SubscriptionOverride`, `UsageCounter`, `IEntitlementService`, the feature/quota pipeline behaviors, and the SUPERADMIN plan screens. The only "Subscription" code today is **GraphQL real-time subscriptions** — unrelated.

---

## 2. Guiding principles

1. **Three gates, resolved in order** — a request proceeds only if all pass:
   - **Entitlement** (tenant paid for this feature/module?) — company-scoped.
   - **Quota** (tenant under its record limit?) — company-scoped, metered.
   - **RBAC** (user's role allows the action?) — user-scoped. *Already exists.*
   Effective access = **Entitlement ∩ Quota ∩ RBAC**.
2. **Records-based, per-meter.** Each limit is its own `(Plan, MeterCode)` row. Never a single bundled number.
3. **Stock vs flow enforce differently** (§6).
4. **BE is the only real gate.** FE gating is UX-only and prevents nothing.
5. **Additive.** New schema + new behaviors + new screens. Existing handlers stay untouched except for the metered-create guard hook.
6. **Fail-closed** on revenue-bearing limits; **cache with immediate invalidation** on plan change.

---

## 3. Domain model

Proposed new schema `billing` (or reuse `auth`). All entities inherit the existing `Entity` base (audit fields `createdDate` / `modifiedDate`).

> **Key type — corrected 2026-07-24.** All PKs/FKs below are **`int` identity**, matching every existing PSS entity. In particular `Company.CompanyId` is **`int`** (verified in `Base.Domain/Models/ApplicationModels/Company.cs`), *not* `Guid`. Do not introduce a `Guid` key family into this codebase.

### 3.1 Plan — SUPERADMIN catalog
```
Plan
  PlanId           int     PK
  PlanCode         string  UNIQUE   (FREE | PLAN_50K | PLAN_100K | CUSTOM)  [CaseFormat upper]
  PlanName         string
  Description      string?
  Price            decimal          (0 for Free; base sticker for tiers)
  Currency         string           (e.g. INR)
  BillingCycle     enum             (Monthly | Annual)
  IsCustom         bool             (true only for the CUSTOM base)
  IsActive         bool
  SortOrder        int
```

### 3.2 PlanEntitlement — boolean feature flags per plan
```
PlanEntitlement
  PlanEntitlementId int    PK
  PlanId            int    FK → Plan
  FeatureCode       string          (see §4 registry: MODULE:*, CHANNEL:*)
  IsEnabled         bool
  UNIQUE (PlanId, FeatureCode)
```
> `FeatureCode` values of form `MODULE:<ModuleCode>` map 1:1 onto `auth.Modules.ModuleCode` — reuse the Module primitive; do not invent a parallel module list.

### 3.3 PlanQuota — numeric limits per plan
```
PlanQuota
  PlanQuotaId      int     PK
  PlanId           int     FK → Plan
  MeterCode        string           (CONTACTS | DONATIONS | EMAILS | WHATSAPP | SMS | USERS …)
  MeterType        enum             (STOCK | FLOW)
  LimitValue       long?            (null = unlimited)
  Period           enum?            (null for STOCK; MONTH for FLOW)
  UNIQUE (PlanId, MeterCode)
```

### 3.4 Subscription — Company → Plan (the assignment)
```
Subscription
  SubscriptionId     int    PK
  CompanyId          int    FK → app.Companies      (one ACTIVE per company)
  PlanId             int    FK → Plan
  CommercialTermId   int?   FK → ops.CommercialTerm  (the approved deal this came from;
                                                      null for internal/demo tenants)
  Status             enum   (Trial | Active | PastDue | Suspended | Cancelled)
  StartDate          DateTime (UTC)
  CurrentPeriodStart DateTime (UTC)
  CurrentPeriodEnd   DateTime (UTC)
  TrialEndsOn        DateTime? (UTC)
  CancelledOn        DateTime? (UTC)
  UNIQUE filtered index (CompanyId) WHERE Status IN (Trial, Active, PastDue)
```
> All DateTimes are `timestamp with time zone`, `Kind=Utc` (Npgsql throws on Unspecified — see project convention).

### 3.5 SubscriptionOverride — per-company exceptions (Custom + one-off deals + add-ons)
```
SubscriptionOverride
  SubscriptionOverrideId int  PK
  SubscriptionId    int    FK → Subscription
  FeatureCode       string?         (set → overrides a PlanEntitlement)
  MeterCode         string?         (set → overrides a PlanQuota LimitValue)
  OverrideValue     long?           (feature: 0/1; meter: the new limit; null = unlimited)
  Note             string?          (why — e.g. "add-on: +2M donations, PO#123")
  CHECK (FeatureCode IS NOT NULL) <> (MeterCode IS NOT NULL)   -- exactly one
```

### 3.6 UsageCounter — usage state
```
UsageCounter
  UsageCounterId   int     PK
  CompanyId        int     FK → app.Companies
  MeterCode        string
  PeriodStart      DateTime (UTC)   (STOCK: constant/epoch; FLOW: cycle start)
  CurrentValue     long
  UNIQUE (CompanyId, MeterCode, PeriodStart)
```
> **STOCK meters (contacts, donations):** enforced via `COUNT(*)` on the real table (drift-free); this row is only an optional **cached display** value refreshed by a job. **FLOW meters (emails/mo):** this row is the **authoritative** counter, rolled fresh each period, never decremented.

### 3.7 Relationships (text ERD)
```
Company (app) ─1──1─ Subscription ─*──1─ Plan
                        │                  ├─* PlanEntitlement
                        └─* SubscriptionOverride    └─* PlanQuota
Company (app) ─1──* UsageCounter
Plan.PlanEntitlement.FeatureCode  ⇄  auth.Modules.ModuleCode   (for MODULE:* codes)
```

---

## 4. Feature & meter code registry (the vocabulary)

Keep these as constants (`FeatureCodes`, `MeterCodes` static classes) — single source of truth.

**FeatureCodes (entitlement, boolean):**
- `MODULE:CONTACTS`, `MODULE:DONATION`, `MODULE:CASE`, `MODULE:GRANT`, `MODULE:VOLUNTEER`, `MODULE:EVENT`, `MODULE:MEMBERSHIP`, … (one per business module, code = `auth.Modules.ModuleCode`)
- `CHANNEL:EMAIL`, `CHANNEL:WHATSAPP`, `CHANNEL:SMS`

**MeterCodes (quota, numeric):**
- `CONTACTS` (STOCK), `DONATIONS` (STOCK), `USERS` (STOCK, if seat-limited)
- `EMAILS` (FLOW/MONTH), `WHATSAPP` (FLOW/MONTH), `SMS` (FLOW/MONTH)

---

## 5. Plan matrix (confirm blanks with management — §16)

| Feature / Meter | Type | Free | 50K | 100K | Custom |
|-----------------|------|------|-----|------|--------|
| Contacts | STOCK | 2,000 | 500,000 | 1,000,000 | override |
| Donations | STOCK | ❓ | 5,000,000 | 10,000,000 | override |
| `CHANNEL:EMAIL` | feature | ❓ | ✅ | ✅ | ✅ |
| `CHANNEL:WHATSAPP` | feature | ❌ | ❌ | ✅ | override |
| `CHANNEL:SMS` | feature | ❌ | ❌ | ✅ | override |
| Module set | entitlement | ❓ | Contacts+Donation+Email | + all channels | override |
| Users (seats) | STOCK | ❓ | ❓ | ❓ | override |

---

## 6. Entitlement resolution — `IEntitlementService`

Central service that turns *Company → effective features + limits*. One resolution point; everything else calls it.

```csharp
public interface IEntitlementService
{
    Task<TenantEntitlements> ResolveAsync(int companyId, CancellationToken ct);
    // Convenience:
    Task<bool> HasFeatureAsync(int companyId, string featureCode, CancellationToken ct);
    Task<long?> GetLimitAsync(int companyId, string meterCode, CancellationToken ct); // null = unlimited
}

public sealed record TenantEntitlements(
    int CompanyId,
    string PlanCode,
    SubscriptionStatus Status,
    IReadOnlyDictionary<string,bool> Features,   // FeatureCode → enabled (override ?? plan)
    IReadOnlyDictionary<string,long?> Limits);   // MeterCode  → limit   (override ?? plan)
```

**Resolution rule:** effective feature = `SubscriptionOverride ?? PlanEntitlement.IsEnabled`; effective limit = `SubscriptionOverride.OverrideValue ?? PlanQuota.LimitValue`.

**Caching:** in-memory keyed by `CompanyId`, **~60s TTL as a backstop**, **explicitly invalidated** whenever a Subscription / override / plan changes (raise a domain event → cache flush). Stale entitlements after a downgrade are the classic bug — TTL alone is not enough.

**Suspended/PastDue:** `Suspended` → resolve to read-only (no create on any meter); `PastDue` → soft-warn but still functional until grace expires (policy §12).

---

## 7. Enforcement — pipeline integration

The gates slot into the **existing** MediatR pipeline, right after `AuthorizationBehavior`:

```
TenantIsolationBehavior → TenantAccessBehavior → AuthorizationBehavior
   → FeatureEntitlementBehavior   (NEW)   ③ feature gate
   → QuotaBehavior                (NEW)   ④ quota reserve
   → CommandValidationBehavior → Handler
```

### 7.1 Feature gate — `FeatureEntitlementBehavior`
Mirrors `TenantAccessBehavior`: reads a `[RequiresFeature("CHANNEL:WHATSAPP")]` attribute off the request type; if `!HasFeatureAsync` → throw a typed `PlanFeatureNotEntitledException` mapped to GraphQL error / HTTP **403** (`PLAN_FEATURE_NOT_ENTITLED`). SuperAdmin + background contexts bypass (same guard shape as `TenantAccessBehavior` lines 30-37).

```csharp
[TenantScope(TenantScopeType.Current)]
[RequiresFeature("CHANNEL:WHATSAPP")]
public record SendWhatsAppCampaignCommand(...) : ICommand<...>;
```

### 7.2 Quota gate — `QuotaBehavior`
Reads a `[MeteredResource("CONTACTS", MeterType.Stock)]` attribute. Runs the reservation **inside the handler transaction, before the insert side-effect**.

**STOCK (contacts, donations):**
```csharp
// inside txn, take a row lock to avoid TOCTOU:
var used = await db.Contacts
    .Where(c => c.CompanyId == tenant)
    .CountAsync(ct);                      // authoritative COUNT
if (limit is not null && used >= limit)
    throw new QuotaExceededException("CONTACTS", used, limit); // → HTTP 402
```
Guard the check+insert against races with a **Postgres advisory lock** (or `SELECT … FOR UPDATE` on the UsageCounter row) — the **same TOCTOU fix already proven in the Case-Management fund guard (C-1 double-spend)**. Reuse that pattern; do not re-invent.

**FLOW (emails/whatsapp/sms per month):**
```csharp
// authoritative counter row for the current period:
var row = await db.UsageCounters.FromSql..."WHERE CompanyId=@t AND MeterCode=@m AND PeriodStart=@p FOR UPDATE";
if (limit is not null && row.CurrentValue >= limit) throw new QuotaExceededException(...);
row.CurrentValue += batchSize;           // increment; never decrement; roll new row each cycle
```

**Bulk import:** check `used + batchSize <= limit` **once up-front**, not per row.

**Fail-closed:** if `IEntitlementService`/store errors on a revenue-bearing limit → **deny**, never default allow.

**HTTP/GraphQL error codes:** `403` feature-not-entitled · `402` quota-exceeded · `429` rate-throttle (future).

### 7.3 Concrete integration points (first meters)
| Meter | Guard on | File(s) |
|-------|----------|---------|
| CONTACTS (stock) | `CreateContactCommand` handler + any bulk contact import | `ContactBusiness/Contacts/Commands/CreateContact.cs` |
| DONATIONS (stock) | global-donation create handler | `DonationSchemas/GlobalDonationCompositeSchemas.cs` create path (`CreateGlobalDonationWithChildrenRequestDto`) |
| EMAILS/WHATSAPP/SMS (flow) | the send/campaign command | Communication send handlers |

---

## 8. Menu / module gating

- **BE:** the module/menu resolution query (what a tenant's user sees) is filtered by `TenantEntitlements.Features` — a menu belongs to a module; module not entitled → menu hidden. This makes **#126 Modules plan-driven**, not manual per-company toggles.
- **FE:** on login, call `myEntitlements` (GraphQL) → returns features + limits + current usage. FE hides un-entitled menus/modules, renders usage meters ("1,847 / 2,000 contacts"), and shows upgrade CTAs at 80% / 100%. Purely cosmetic — the BE gates still fire.

---

## 9. Per-meter increase / add-ons (client wants "more donations only")

Because limits are **per-`MeterCode`**, raising one meter never touches another. Three exposures, all on `SubscriptionOverride` — pick per phase:
- **Per-meter override (Phase 2, free):** SUPERADMIN sets `SubscriptionOverride(MeterCode=DONATIONS, OverrideValue=8_000_000)`. Works with the skeleton, zero new code.
- **Add-on packs (Phase 3):** sell increments ("+2M donations / ₹X"); each applies an override delta. Clean product form.
- **Overage billing (Phase 3+):** allow over-limit, invoice excess; needs billing engine.

---

## 10. Subscription lifecycle

- **Provisioning:** the **Company Onboarding wizard** (see MVP doc §3A) ends by creating the `Subscription` (pick plan → seed entitlements from the catalog). **Onboarding and Plans are coupled** — build the subscription-create step as part of onboarding.
- **Trial → Active:** optional `TrialEndsOn`; a scheduled job flips `Trial → Active`/`PastDue`.
- **Upgrade/downgrade:** change `Subscription.PlanId` (+ optional overrides) → invalidate entitlement cache → new limits apply in seconds. No role surgery (payoff of gate separation).
- **Suspend/cancel:** billing failure → `PastDue → Suspended`; suspended = read-only, **never delete tenant data**.

---

## 11. Over-limit & downgrade policy (recommend soft-block — confirm §16)

- **Warn at 80%, block *new* creates at 100%** for the affected meter; existing data stays fully readable/editable.
- **Downgrade below current usage** (e.g. 3,000 contacts → Free/2,000): do **not** delete; set **read-only-over-limit** for that meter — no new contacts until back under the line.
- **Hard suspend** only on billing failure, not on hitting a usage cap.

---

## 12. Screens (SUPERADMIN + tenant)

| Screen | Type | Owner | Purpose |
|--------|------|-------|---------|
| **Plan Catalog** | MASTER_GRID / CONFIG | SUPERADMIN | CRUD Plan + PlanEntitlement + PlanQuota (the §5 matrix). |
| **Subscription Management** | MASTER_GRID | SUPERADMIN | Assign Company→Plan; set overrides (Custom/add-ons); status; trial/expiry. |
| **Plan & Usage** | REPORT / dashboard widget | BUSINESSADMIN (read-only) | Current plan, usage vs limits, upgrade CTA. |
| **#126 Modules** | MASTER_GRID | SUPERADMIN | Becomes plan-driven module visibility. |

Follow the existing screen templates (`_CONFIG.md` for catalog; MASTER_GRID for subscription list; REPORT/widget for usage).

---

## 13. Seeding

- Seed the **4 plans** (FREE, PLAN_50K, PLAN_100K, CUSTOM) + their `PlanEntitlement` + `PlanQuota` rows via a **SQL seed** (I author the seed file; user applies — per the seed convention).
- Idempotent (upsert on `PlanCode` / `(PlanId, MeterCode)`), so re-running is safe.
- Backfill: every **existing** company with no Subscription gets a default (e.g. an internal `CUSTOM`/unlimited) subscription so nothing breaks the day the guards go live.

---

## 14. Migration & rollout (user-owned)

1. Developer authors EF migration for the 6 entities (new `billing` schema).
2. Build to prove compile; hand the **migration spec** + **seed SQL** to the user.
3. User runs migration + seed, commits.
4. **Rollout is safe because guards are opt-in per attribute** — no `[MeteredResource]`/`[RequiresFeature]` = no enforcement. Add attributes meter-by-meter after backfill (§13), so no tenant is retroactively blocked.

---

## 15. Phased implementation roadmap

| Phase | Scope | Depends on | Rough size (1 dev) |
|-------|-------|-----------|--------------------|
| **P0 — Design** | This document | — | ✅ done |
| **P1 — Skeleton** | 6 entities + migration + seed (4 plans) + `IEntitlementService` + backfill existing companies | after onboarding gate | ~M |
| **P2 — Enforcement** | `FeatureEntitlementBehavior` + `QuotaBehavior`; guard CONTACTS + DONATIONS (stock) + channel features; `myEntitlements` endpoint; FE menu hide + usage widget; SUPERADMIN Plan Catalog + Subscription screens; per-meter override | P1 | ~L |
| **P3 — Productize** | Add-on packs, FLOW meters (email/whatsapp/sms per cycle), trial/expiry jobs, upgrade/downgrade UX for BUSINESSADMIN, Plan & Usage report | P2 | ~L |
| **P4 — Billing** | Self-serve checkout/payment, proration, dunning, overage invoicing, automated PastDue→Suspend | P3 | separate initiative |

**Trigger to start P1/P2:** before onboarding a **2nd** client on a **different** plan (first client gets everything, so gating earns nothing until then).

---

## 16. Open decisions (management input)

1. **Free plan:** any donations? any email? contacts-only?
2. **Per-plan module set** — which business modules each tier unlocks.
3. **Seat/user limits** per plan.
4. **"50K/100K"** — annual price + currency? billing cycle?
5. **Over-limit policy** — soft-block (recommended, §11) vs hard-block.
6. **Trial** — offer a trial period, or assign paid plan on onboarding directly?

---

## 17. Testing strategy

- **Unit:** `IEntitlementService` resolution (plan vs override precedence; unlimited nulls; suspended → read-only).
- **Concurrency:** two parallel creates at `limit-1` → exactly one succeeds (TOCTOU regression, mirror the fund-guard test).
- **Flow reset:** counter rolls to a fresh period row; prior period untouched.
- **Downgrade:** company over new limit → existing rows readable, new create blocked (`402`).
- **Fail-closed:** entitlement store error → create denied, not allowed.
- **Backfill:** legacy company with no subscription is never blocked before assignment.

---

*Design locked 2026-07-22. Build when scheduled — additive, no rearchitecting required.*
