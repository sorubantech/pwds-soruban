# PSS 2.0 — Phase 7: Tenant Configuration Readiness & Feature Dependency Architecture

**Status:** Design review + build prompt. Authored by the guide session, 2026-08-09.
**Precedes:** any further intimation-condition work. Phase 6 §8.10 exclusions are superseded by §⑪ here.
**Reviewer stance:** Enterprise PM · Solution Architect · UX Architect · QA/BA.

---

## ⓪ The finding that reframes the question

The question asked was *"should the tenant only learn about a missing payment gateway from the 03:45 sweep?"*

The answer is no. But the reason is not the one the question assumes. The platform is **not** missing proactive
guidance. It already has three separate proactive mechanisms:

| # | Mechanism | Where | When it runs | Scope |
|---|---|---|---|---|
| 1 | **Go-live checklist** (P-06 / O-04) | `SettingBusiness/GoLive/GoLiveChecklistBuilder.cs` | On demand, tenant dashboard | Pre-`ACTIVE` only |
| 2 | **Publish validation** | `OnlineDonationPages/Queries/ValidateOnlineDonationPageForPublish.cs` | On publish + on demand | One page |
| 3 | **Intimation conditions** (Phase 6) | `Services/Intimations/Conditions/*` | Nightly 03:45 UTC | Whole tenant |
| 4 | **Plan entitlement** | `Services/Billing/EntitlementService.cs` | Per call | Feature availability |

The real defect is that **all three encode the same business fact — "online donation requires a payment
gateway" — independently, and they encode it differently.**

### The proof: three definitions of "has a payment gateway"

```csharp
// 1. GoLiveChecklistBuilder.cs:131-132   → NULL IsActive counts as CONFIGURED
.AnyAsync(g => g.CompanyId == companyId && g.IsDeleted != true && g.IsActive != false, ct)

// 2. PaymentGatewayMissingCondition.cs:33-38 → NULL IsActive counts as MISSING
.AnyAsync(g => g.CompanyId == companyId && g.IsActive == true && g.IsDeleted != true, ct)

// 3. ValidateOnlineDonationPageForPublish.cs:213-217 → IsActive NOT CHECKED AT ALL
.AnyAsync(g => g.CompanyPaymentGatewayId == entity.CompanyPaymentGatewayId
            && g.CompanyId == companyId && g.IsDeleted == false, ct)
```

A tenant whose only gateway row is **inactive** currently gets, simultaneously:

- go-live checklist: **"Payment gateway: configured"** → allowed to go live;
- nightly intimation: **"Online donations cannot be collected"** → CRITICAL banner;
- publish validation: **passes** → the page goes live pointing at a **deactivated gateway**, and donors
  reach the payment step and fail.

That third line is a production money-loss path, and it exists *today*, independent of Phase 6. It is not a
UX gap. It is three hardcoded copies of one rule drifting apart — exactly what happens when dependency
knowledge lives inside each feature instead of in one place.

**So the recommendation is not "add event-driven notifications."** Adding a fourth mechanism to a system that
already has three inconsistent ones makes it worse. The recommendation is: **extract the dependency rule into
one registry, and let all four surfaces read from it.**

---

## ① Current flow problems

### 1.1 Architecture

| ID | Problem | Evidence |
|---|---|---|
| A-1 | **Rule duplication across three engines.** Each surface re-implements "is X configured". | §⓪ |
| A-2 | **Predicate drift already happened.** Three different truths for one fact. | §⓪ |
| A-3 | **No dependency graph.** Nothing anywhere states `OnlineDonationPage → CompanyPaymentGateway`. It is implied by three unrelated files. | grep: no dependency type exists |
| A-4 | **Readiness is not addressable.** No API answers "what is this tenant missing, and for which features?" outside pre-go-live. | `GetGoLiveChecklist` is the only one, and it stops at `ACTIVE` |
| A-5 | **Detection is coupled to its trigger.** `PaymentGatewayMissingCondition.EvaluateAsync` both *decides* and *raises*. It cannot be reused as a read-only check by a screen. | `Conditions/*.cs` |
| A-6 | **No configuration-change event.** Saving a gateway does not tell anything else. Resolution waits for the next nightly tick. | no publisher on `CompanyPaymentGateway` writes |

### 1.2 Lifecycle / business

| ID | Problem |
|---|---|
| B-1 | **The readiness story ends at go-live.** `GoLiveChecklistBuilder` returns `IsAlreadyLive = true` and stops being useful the moment `Company.Status = ACTIVE`. Everything the tenant configures *after* go-live — a second gateway, a new channel, a lapsed credential — has no checklist. |
| B-2 | **Go-live can be granted on a false positive** (A-2), so a tenant can be marked `ACTIVE` while structurally unable to collect money. |
| B-3 | **Up to 24h of blindness.** A tenant onboarded at 04:00 UTC learns nothing until 03:45 the next day. For a trial tenant evaluating the product, that is most of the evaluation window. |
| B-4 | **No distinction between "not configured" and "configured but broken".** Both the checklist and the condition ask a boolean existence question. Expired credentials, a gateway disabled at the provider, a failing webhook — all read as *configured*. |
| B-5 | **Plan-conditionality is inconsistent.** The go-live checklist correctly asks `EntitlementService.HasFeatureAsync(FEATURE:DONATION)` before demanding a gateway. `PaymentGatewayMissingCondition` does not — it infers relevance from the existence of a donation page instead. Two different relevance models. |

### 1.3 UX

| ID | Problem |
|---|---|
| C-1 | **Discovery by dead end.** The user's scenario exactly: the dependency is revealed by an empty dropdown in step 4 of a wizard. An empty `<select>` is not an error message. |
| C-2 | **No contextual remediation.** `ValidateOnlineDonationPageForPublish` returns `"Payment gateway is required."` — a sentence, with no route and no action. Compare `GoLiveChecklistItemDto`, which carries `ActionRoute` + `ActionLabel`. The better pattern exists and was not reused. |
| C-3 | **Failure is disclosed at the latest possible moment.** The gate is at publish. The user has by then filled in a page title, slug, amount chips, org units, branding — then is told the thing they needed first is missing. |
| C-4 | **Nothing warns before entry.** No pre-flight state on the donation-page list screen. |
| C-5 | **Banner-only remediation is capability-filtered.** The Phase-6 banner is filtered by `RequiredMenuCode`+`Create`. Correct for the banner — but it means a fundraising user who *cannot* configure gateways sees nothing at all, and still hits C-1. They need a different message ("ask your administrator"), not silence. |

### 1.4 Technical

| ID | Problem |
|---|---|
| D-1 | `IsActive` nullability is unowned. Three files, three interpretations. The column semantic must be decided once. |
| D-2 | Publish validation ignores gateway active-state (§⓪ line 3) — **a live defect, fix regardless of everything else in this document.** |
| D-3 | No audit trail on readiness transitions. `PublishOnlineDonationPage` writes `auditLogWriter.WriteWorkflowEvent`; configuration readiness writes nothing. |
| D-4 | The nightly sweep is O(tenants × conditions) sequential with no batching, no partitioning and `AutomaticRetry(Attempts = 0)`. Adequate at current volume; it is not a scale strategy. |

---

## ② Recommended enterprise flow

**One registry. Three trigger layers. Four surfaces. Zero duplicated predicates.**

```
                    ┌──────────────────────────────────────────┐
                    │   FEATURE DEPENDENCY REGISTRY (new)      │
                    │   declarative: Feature → Requirement[]    │
                    │   each Requirement = one async probe      │
                    │   returns: SATISFIED | MISSING |          │
                    │            INVALID | EXPIRED | N/A        │
                    └────────────────┬─────────────────────────┘
                                     │ single source of truth
        ┌──────────────┬─────────────┼─────────────┬──────────────────┐
        ▼              ▼             ▼             ▼                  ▼
  ① Go-live      ② Readiness    ③ Contextual   ④ Publish/       ⑤ Intimation
    checklist       dashboard      pre-flight     activate         conditions
    (pre-ACTIVE)    (always)       (screen entry) gate (server)    (notify state)
```

### Trigger layers

| Layer | Fires on | Latency | Responsibility |
|---|---|---|---|
| **L1 — Event-driven** | provisioning complete · go-live · config saved/deleted/deactivated · plan change · integration failure callback | seconds | Re-evaluate **only the affected requirement** for **one tenant**; raise or resolve its intimation immediately |
| **L2 — Journey-time** | screen entry · wizard step · publish/activate attempt | request-time | Read-only evaluation for display; **authoritative enforcement** at publish |
| **L3 — Reconciliation** | nightly 03:45 UTC | ≤24h | **Safety net only** — catch what L1 missed and what changed outside the app |

L1 gives correctness of experience. L2 gives correctness of outcome. L3 gives correctness of state. Removing
any one of the three leaves a real hole; that is why all three are required, and it is not a hedge — each has
a distinct, non-overlapping job, spelled out in §⑤.

### End-to-end

```
Provisioning completes (TenantProvisioningRun → COMPLETED)
   └─ L1 event: evaluate ALL requirements for the new tenant
        ├─ raise intimations for every MISSING requirement whose feature is entitled by plan
        └─ seed the readiness dashboard widget

First login (Company.Status = PROVISIONING)
   └─ tenant lands on the go-live checklist — unchanged, but items now come FROM THE REGISTRY

Go-live (CompleteGoLive)
   └─ re-derives from the registry; cannot pass on a false positive (fixes B-2)
   └─ L1 event: Status → ACTIVE; readiness widget replaces the checklist on the dashboard

Post-go-live steady state
   ├─ readiness widget always present while any requirement is unsatisfied
   ├─ intimation banner for WARNING/CRITICAL gaps (Phase 6, unchanged)
   └─ L3 nightly reconciles

User opens Donation Pages list
   └─ L2 pre-flight: FEATURE:ONLINE_DONATION readiness queried with the list
        └─ if MISSING: inline callout above the grid + "Configure payment gateway" CTA
           — creation NOT blocked

User creates a page → allowed, saved as Draft
   └─ wizard payment step shows the requirement inline, not an empty dropdown

User clicks Publish
   └─ L2 gate: ValidateOnlineDonationPageForPublish, now including registry requirements
        └─ FAIL → modal lists every violation, each with ActionRoute + ActionLabel
        └─ PASS → publish, audit event

User configures the gateway
   └─ L1 event on save: re-evaluate → ResolveAsync → banner clears within the request
        └─ NOT the next morning
```

---

## ③ When should configuration be checked?

| Event | Check? | Notify? | Block? | Action |
|---|---|---|---|---|
| **Tenant provisioning completes** | Yes — full sweep, one tenant | Yes — intimation per entitled+missing requirement; **one** onboarding email digest | No | Seed readiness state; land on checklist |
| **First login** | Yes — cached read | No (already raised) | No | Show go-live checklist |
| **Dashboard access** | Yes — cached read (≤60s TTL) | No | No | Readiness widget with per-item status |
| **Feature screen entry** (list/landing) | Yes — that feature's requirements only | No | No | Inline callout + CTA |
| **Feature create / draft save** | Yes — display only | No | **No** | Never block draft. Show unmet requirements in-form |
| **Feature publish / activate** | Yes — **authoritative, server-side** | No | **Yes** | Reject with the full violation list, each actionable |
| **Configuration saved / changed** | Yes — affected requirement only | Resolve, or raise if now INVALID | No | Clear banner in-request; audit |
| **Configuration deactivated / deleted** | Yes — affected requirement | **Raise immediately** | Consider blocking the delete if a *published* feature depends on it | Warn: "1 published donation page uses this gateway" |
| **Plan change** | Yes — full re-evaluation | Raise/resolve as entitlement changes | No | Requirements for un-entitled features become N/A, not MISSING |
| **Integration/API failure** (webhook, auth error, declined credential) | Yes — mark requirement INVALID | Raise CRITICAL | No | Do not silently degrade |
| **Scheduled reconciliation 03:45** | Yes — all tenants, all requirements | Only on *state change*; reminders per §④ | No | Reconcile + emit drift metric |

**The one rule that matters:** *check early and often for guidance; enforce exactly once, at the server-side
activation boundary.* Guidance may be stale or cached. Enforcement may not.

---

## ④ Notification architecture

Phase 6's `notify.Intimations` is **already the right substrate** — it is a condition table, not an event log,
which is precisely what state-based notification requires. It does not need replacing. It needs *more
triggers* and *one more severity behaviour*.

| Channel | Purpose | Trigger | Frequency |
|---|---|---|---|
| **Contextual (in-screen)** | The primary surface. Callout on the feature screen. | L2, every render | Always while unmet — no dedup, no dismiss |
| **Readiness widget** | The tenant's single answer to "what's left?" | L2, dashboard | Always while any item unmet |
| **Banner (intimation)** | Cross-cutting urgency for gaps not tied to the current screen | L1 raise / L3 reconcile | Once per condition; CRITICAL not dismissible |
| **Notification centre** | Durable record + the audit answer to "were they told?" | On first raise only | Once per raise |
| **Email** | Reaches people not in the app | Onboarding digest; CRITICAL raise; day-3/day-10 reminder | Rate-limited, see below |
| **Platform console** | Ops visibility across tenants | Always | — |

### Anti-spam rules (all enforceable on the existing schema)

1. **First notification** — on first raise only. Already correct: `RaiseAsync` notifies only when it returns
   `true`.
2. **Reminders** — the refresh branch must not notify (already correct). Reminder cadence is a *separate*
   decision keyed off `PublishedAt`: re-notify at **day 3** and **day 10** unresolved, then stop. Store the
   count in `MetadataJson`; no schema change.
3. **Escalation** — WARNING → CRITICAL when a gap starts costing money (a published donation page now has no
   valid gateway). **This is the Phase 6 §9.3 defect** — escalation must clear `IsDismissible` and soft-delete
   the dismissals, or escalation is invisible to whoever dismissed the warning. Fix it before adding triggers.
4. **Suppression** — never raise a requirement whose feature is not entitled by the plan (fixes B-5). Never
   raise for a suspended/churned company.
5. **Acknowledgement** — dismissal is per-user and already modelled (`IntimationDismissals`). Dismissal is
   *not* resolution; the readiness widget and the contextual callout deliberately ignore dismissals.
6. **Resolution** — automatic, on the L1 config-save event. A tenant who fixes the problem must see the banner
   disappear immediately, or they will not believe the system.
7. **Re-notification** — a resolved-then-broken-again requirement raises a **new** row. Guaranteed by the
   partial unique index being filtered on `Status = 'ACTIVE'`.

### Email discipline

Email only for: (a) the onboarding digest, (b) CRITICAL raises, (c) the two reminders. Never for WARNING
raises, never from the nightly sweep for anything already emailed. One email per tenant per day, hard cap —
the digest aggregates, it does not fan out per requirement.

---

## ⑤ What the 03:45 UTC job is *for*

**Keep it.** Narrow it. It becomes the third layer, not the first.

**It IS responsible for:**
- **Drift detection** — state changed outside the app (credential expired at the provider, gateway disabled
  in the provider portal, DNS/domain lapsed). No in-app event exists for these. Only a sweep finds them.
- **Safety net** — an L1 event was lost (deploy, crash, unhandled path). The sweep converges the state.
- **Time-based conditions** — `SUBSCRIPTION_EXPIRING` is genuinely a function of *today's date* and nothing
  else. It has no event. The sweep is its only correct trigger.
- **Expiry of lapsed rows** — already implemented (`ExpireLapsedAsync`).
- **Reminder cadence** — day-3 / day-10 (§④.2).
- **Emitting a drift metric** — *how many gaps did the sweep find that L1 should have caught?* If this is
  persistently non-zero, an L1 publisher is missing. This metric is the entire early-warning system for the
  event layer, and is the single most valuable thing to add.

**It is NOT responsible for:**
- Being the tenant's *first* notice of anything that has an in-app cause. A gap caused by a user action inside
  the product must be raised by that action, in that request.
- Enforcement. It never blocks anything.
- Being the only correctness guarantee. If the sweep is the only thing keeping state true, the event layer is
  broken and the drift metric will say so.

### Operational hardening (in order of value)

| Concern | Requirement |
|---|---|
| Idempotency | Already correct — `RaiseAsync`/`ResolveAsync` are both idempotent by construction |
| Partial processing | Already correct — per-tenant × per-condition try/catch |
| Timezone | Sweep in UTC; **render dates in the tenant's timezone**. A "expires in 3 days" computed in UTC and shown to a UTC+13 tenant is wrong at the boundary |
| Retry | `Attempts = 0` is right for a daily idempotent sweep. Do **not** add retries; add alerting |
| Scale | Current form is sequential. Before ~2k tenants: batch tenants in pages of 200 and fan out with a bounded degree of parallelism. Do not do this now — do it when the completion log crosses ~10 min |
| Monitoring | The completion log line is good. Promote to a metric: companies, evaluated, failed, expired, **drift**. Alert on `failed > 0` and on **absence** of a completion record by 04:30 UTC — a job that silently stops running is the failure mode nobody notices |
| Audit | Every raise/resolve writes an audit row with actor = `SYSTEM:SWEEP` or the user who triggered L1 |

---

## ⑥ The payment-gateway journey, end to end

**Before (today).** Onboard → nothing → create page → 4 wizard steps → empty gateway dropdown → confusion →
publish → `"companyPaymentGatewayId: Payment gateway is required."` → hunt for the settings screen.

**After.**

| Step | What the tenant sees |
|---|---|
| **T+0s** provisioning completes | Readiness evaluated. 3 gaps found. |
| **T+30s** first login | Go-live checklist: *Payment gateway — Not configured — Required for: Online donations — [Configure]* |
| **T+1m** email | One digest: "3 things to set up before you go live", each with a deep link |
| **T+2m** dashboard | Readiness widget: **2 of 5 complete** |
| Opens **Donation Pages** | Callout above the empty grid: *"Online donation pages need a payment gateway before they can be published. You can build a page now and publish it once a gateway is connected."* → **[Configure payment gateway]** · **[Create page anyway]** |
| Creates page | **Allowed.** Saved as Draft. |
| Payment step of the wizard | Not an empty dropdown — an inline empty-state: *"No payment gateway configured."* + CTA that opens configuration **in a new tab / side panel**, preserving the draft |
| Clicks **Publish** | **Blocked, server-side.** Modal lists every violation; each row has its own action route. Gateway row links straight to the gateway screen |
| Configures the gateway | On save, L1 fires: requirement re-evaluated → intimation resolved → **banner disappears on the next render**, not tomorrow |
| Returns, clicks Publish | Passes. Published. Audit row written |
| **Later:** someone deactivates the gateway | L1 fires on the deactivate: page is published and now unbacked → **CRITICAL raised immediately**, non-dismissible; the deactivate screen warns *"1 published donation page uses this gateway"* before committing |
| **Later:** credential expires at the provider | No in-app event exists. **L3 finds it at 03:45** and raises CRITICAL. This is exactly the case the sweep exists for |

The last two rows are the argument for the whole design in miniature: one gap has an in-app cause and must be
caught in-request; the other has an external cause and can only be caught by a sweep. Neither mechanism can
cover both.

---

## ⑦ The dependency framework

**Centralised and declarative. Not hardcoded per feature.** A1–A3 are what hardcoding already cost.

```csharp
// Base.Application/Services/Readiness/IFeatureRequirement.cs
public interface IFeatureRequirement
{
    string RequirementCode { get; }        // PAYMENT_GATEWAY, EMAIL_PROVIDER, …
    string Title { get; }
    string Description { get; }
    string ActionRoute { get; }            // reuse the GoLiveChecklistItemDto contract
    string ActionLabel { get; }
    string RequiredMenuCode { get; }       // who can fix it (banner + CTA gating)
    string RequiredCapability { get; }

    /// THE ONLY PLACE THIS QUESTION IS ANSWERED.
    Task<RequirementStatus> EvaluateAsync(int companyId, CancellationToken ct);
}

public enum RequirementState { NotApplicable, Satisfied, Missing, Invalid, Expired }

public record RequirementStatus(
    RequirementState State,
    string EvidenceLabel,          // "Razorpay — connected 12 Jun 2026"
    string? Detail = null);
```

```csharp
// Feature → requirements. Declarative, one place, reviewable in a diff.
public static class FeatureDependencyMap
{
    public static readonly IReadOnlyDictionary<string, FeatureDefinition> Features = new Dictionary<string, FeatureDefinition>
    {
        ["FEATURE:ONLINE_DONATION"] = new(
            PlanFeatureCode: "FEATURE:DONATION",
            BlocksActivation: ["PAYMENT_GATEWAY"],                    // hard — publish is refused
            WarnsOnly:        ["EMAIL_PROVIDER", "RECEIPT_TEMPLATE"]), // soft — publish allowed, warned
        ["FEATURE:BULK_EMAIL"] = new(
            PlanFeatureCode: "CHANNEL:EMAIL",
            BlocksActivation: ["EMAIL_PROVIDER"],
            WarnsOnly:        []),
    };
}
```

### Why a code registry and not a database table

Requirements are **executable predicates**, not data — each is a query against a different table with
different semantics. A DB-driven rule engine would have to express `IsActive != false AND IsDeleted != true`
generically, which is how you end up with a bad DSL. The *map* (feature → requirement codes, hard vs soft) is
declarative and reviewable; the *probe* is code, in one file per requirement, with one owner.

**Non-negotiable:** once `PaymentGatewayRequirement.EvaluateAsync` exists, the three predicates in §⓪ are
**deleted** and replaced by calls to it. If any survives, this phase has failed and drift resumes.

### The four consumers

```
IReadinessService.EvaluateFeatureAsync(companyId, featureCode)   → FeatureReadiness
IReadinessService.EvaluateTenantAsync(companyId)                 → TenantReadiness (all entitled features)

  ① GoLiveChecklistBuilder      → builds items FROM requirements (keeps its own extra items:
                                   team invited, contacts imported, test donation — those are
                                   onboarding milestones, not dependencies. Keep them separate.)
  ② Readiness dashboard widget  → EvaluateTenantAsync, cached 60s
  ③ Feature screens / publish   → EvaluateFeatureAsync; BlocksActivation ⇒ hard refusal server-side
  ④ Intimation conditions       → the three detectors become thin adapters over requirements
```

### State model — the direct answer to the enum question

**Do not persist a tenant-level readiness status column.** `Not Started / Partially Configured /
Configuration Required / Ready / Configuration Error / Configuration Expired / Reconfiguration Required` is
seven states that all mean "some derived rollup of per-requirement state", and a persisted rollup **will**
drift from the rows it summarises — that is the same failure as §⓪, one level up.

- **Per-requirement state:** the five values above. **Derived on read.** Never stored as truth.
- **Tenant rollup:** computed — `Ready` when every entitled hard requirement is `Satisfied`. Never stored.
- **Cache, don't persist:** a 60-second memory cache keyed `(companyId, featureCode)`, invalidated by the L1
  event. That gets dashboard performance without inventing a second source of truth.
- **What IS persisted:** the *notification* state — `notify.Intimations` — because "have we told them, and
  did they dismiss it" is genuinely stateful and cannot be derived. That table already exists and is correct.

`Company.Status` (`PROVISIONING`/`ACTIVE`/`SUSPENDED`/`CHURNED`) stays exactly as it is. It is a **lifecycle**
state, deliberately distinct from readiness, and conflating the two would make go-live irreversible in the
wrong direction.

---

## ⑧ UX/UI

| Surface | Spec |
|---|---|
| **Readiness widget** (dashboard) | Progress `n of m`. One row per unmet requirement: title · required-for · evidence · CTA. Hidden entirely when everything is satisfied — a permanently green panel trains people to ignore the area |
| **Checklist item** | Reuse `GoLiveChecklistItemDto` verbatim — `Title`, `Description`, `IsSatisfied`, `EvidenceLabel`, `ActionRoute`, `ActionLabel`. It is already the right shape; the registry populates it |
| **Feature-screen callout** | Above the grid. Warning-toned. States the dependency, the consequence, and the remedy. Never blocks the grid |
| **Wizard inline state** | Replace every empty dependent dropdown with an empty-state block: what is missing + CTA. An empty `<select>` is never acceptable for a dependency |
| **Publish modal** | Every violation listed (never first-only — already correct), each with its own action route. "Fix and return" preserves the draft |
| **Blocking state** | Publish button stays **enabled** and explains on click. A disabled button with no explanation is the worst possible affordance — the user cannot discover *why* |
| **Empty states** | Every dependent-entity list gets a dependency-aware empty state |
| **Permission-aware copy** | If the user lacks `RequiredCapability`: *"A payment gateway must be configured before this page can be published. Contact your administrator."* — **never silence** (fixes C-5) |
| **Success** | Toast + immediate banner/widget clear on the same render |
| **Severity colours** | Existing convention: solid `-600` background, white foreground |
| **No browser dialogs** | Inline components or a Dialog. Never `confirm()` |

---

## ⑨ Backend design

### New (Base.Application/Services/Readiness/)
```
IFeatureRequirement.cs · RequirementStatus.cs · FeatureDependencyMap.cs
Requirements/PaymentGatewayRequirement.cs
Requirements/EmailProviderRequirement.cs
Requirements/ReceiptTemplateRequirement.cs
IReadinessService.cs · ReadinessService.cs        (evaluate + 60s cache + entitlement suppression)
IReadinessEventPublisher.cs · ReadinessEventPublisher.cs   (L1 — re-evaluate + raise/resolve)
```

### Modified
| File | Change |
|---|---|
| `GoLiveChecklistBuilder.cs` | `CHANNELS_CONFIGURED` derives from the registry; delete the inline predicates (lines 131-135) |
| `ValidateOnlineDonationPageForPublish.cs` | Gateway check delegates to `PaymentGatewayRequirement`; **add the missing active-state check (D-2)**; add `ActionRoute`/`ActionLabel` to `ValidationFieldEntry` |
| `PaymentGatewayMissingCondition.cs` / `EmailProviderMissingCondition.cs` | Become thin adapters over their requirement — detection removed, notification decision retained |
| `IntimationService.RaiseAsync` | **Phase 6 §9.3 escalation fix — prerequisite, not optional** |
| Gateway/email provider create·update·delete·toggle handlers | Publish an L1 readiness event after `SaveChangesAsync` |
| `ProvisionTenant` / `CompleteGoLive` | Publish an L1 full-evaluation event |
| `Subscription` plan-change handlers | Publish an L1 full-evaluation event |

### API
```graphql
tenantReadiness: TenantReadinessDto!                       # widget — cached
featureReadiness(featureCode: String!): FeatureReadinessDto! # screen pre-flight
```
Both tenant-scoped from claims — **never** a `companyId` argument (INV-10, as with `activeIntimations`).

### Non-negotiables
- **Enforcement is server-side.** FE readiness is presentation. `PublishOnlineDonationPage` already
  re-validates through the query handler — that pattern is correct and must be kept for every new gate.
- **L1 events must never throw into the business handler.** Same discipline as `INotificationSender` /
  `RaiseAsync`: try/catch → `LogWarning`. Failing to update a banner must never fail a gateway save.
- **L1 fires after `SaveChangesAsync`,** never before — never notify on a transaction that then rolls back.
- **Entitlement suppression is inside `ReadinessService`,** not at each call site, or B-5 recurs.
- **`IsActive` semantics decided once (D-1)** and written into the requirement: `IsActive == true` is the
  correct reading — an explicitly deactivated gateway cannot process a payment. Then fix any NULL rows.

---

## ⑩ Edge cases

| # | Scenario | Behaviour |
|---|---|---|
| 1 | Never configures a gateway | Raise → day-3 + day-10 reminders → stop. Never blocked from drafting. Never spammed |
| 2 | Configures after notification | L1 resolves in-request. Banner gone on next render |
| 3 | Gateway becomes invalid (auth failure) | Requirement → `Invalid`; CRITICAL if a published page depends on it |
| 4 | Credentials expire | No in-app event → **L3 catches it**. The canonical sweep-only case |
| 5 | Gateway deleted while a page is published | Warn **before** the delete; on commit raise CRITICAL. Do not silently unpublish |
| 6 | Multiple gateways, one active | `Satisfied`. Evidence names which |
| 7 | Gateway exists but inactive | **`Missing`.** Resolves §⓪ / D-1 / D-2 in one decision |
| 8 | Feature not in plan | `NotApplicable`. No raise, no checklist row, no widget row |
| 9 | User lacks configure permission | Contextual message with "contact your administrator"; banner still filtered by capability; **never silence in-context** |
| 10 | Notification send fails | Intimation already committed; `NotifyAsync` catches. Banner still renders — already correct |
| 11 | Sweep fails | Per-tenant isolation holds. Alert on `failed > 0` **and on a missing completion record** |
| 12 | L1 event processed twice | Idempotent by construction — `RaiseAsync` refreshes, `ResolveAsync` matches zero rows |
| 13 | L1 and L3 race | Same idempotency; partial unique index is the backstop |
| 14 | Thousands of users in a tenant | Intimation is **one row per tenant** (INV-10), not per user. Dismissals are per-user. This is why the Phase 6 model scales |
| 15 | Multiple admins | All see the banner; one dismisses for themselves only; resolution clears it for everyone |
| 16 | Suspended / churned tenant | Suppress all raises. Sweep skips inactive companies — already correct |
| 17 | Tenant timezone | Evaluate in UTC, render in tenant timezone |
| 18 | Company deleted mid-sweep | Per-tenant catch; row soft-deleted; next sweep skips |

---

## ⑪ Final recommendation

**Adopt event-driven + journey-time + scheduled reconciliation — all three, each with a distinct job — on top
of one centralised dependency registry. Do not build a fourth independent mechanism.**

1. **Onboarding.** On provisioning completion, evaluate every entitled requirement for that tenant
   synchronously. Raise an intimation per gap. Send **one** digest email. Land the user on the go-live
   checklist, which now derives from the registry.
2. **Feature access.** Every dependent feature performs a journey-time readiness check at screen entry and
   renders a contextual callout with a direct CTA. No empty dropdown ever stands in for a dependency message.
3. **Creation vs activation.** **Never block creation. Always block activation.** Drafts are free; publishing
   is gated, server-side, with every violation listed and individually actionable. This is already the
   `PublishOnlineDonationPage` pattern — generalise it, do not reinvent it.
4. **Configuration change.** Every create/update/delete/toggle on a configuration entity publishes an L1 event
   that re-evaluates and raises or resolves **in the same request**. This single change is what removes the
   24-hour blindness, and it is the highest-value item in the document.
5. **The 03:45 job stays**, scoped to: externally-caused drift, time-based conditions, missed-event recovery,
   expiry, reminder cadence, and the drift metric. It is never a tenant's first notice of an in-app-caused gap.
6. **Notification triggers:** first raise only; day-3 and day-10 reminders; escalation on money-impact;
   automatic resolution; re-raise on regression. Email only for onboarding, CRITICAL, and the two reminders.
7. **No new state column.** Readiness is derived and cached. The only persisted state is notification state,
   which `notify.Intimations` already models correctly.
8. **How tenants stop discovering gaps through errors:** they are told at onboarding (digest + checklist),
   reminded on the dashboard (widget), warned on entry to the dependent feature (callout), shown the
   dependency in the form (empty-state, not empty dropdown), and refused at publish with an actionable list.
   Five disclosures before any failure, each earlier than the last.

### Sequencing — do these in order

| Order | Item | Why first |
|---|---|---|
| **0** | **Fix D-2** — publish validation ignores gateway active-state | Live money-loss defect, independent of everything else here |
| **0** | **Fix Phase 6 §9.3** — escalation must clear dismissals | Every escalation path below depends on it |
| **1** | Registry + `PaymentGatewayRequirement` + `EmailProviderRequirement`; delete the three duplicated predicates | Ends the drift. Everything else reads from here |
| **2** | L1 events on configuration writes + provisioning + go-live | Removes the 24h blindness — biggest single UX win |
| **3** | `featureReadiness` query + contextual callout + wizard empty-state on donation pages | Fixes the reported scenario end to end |
| **4** | `tenantReadiness` query + dashboard widget | Extends readiness past go-live (B-1) |
| **5** | Reminder cadence, drift metric, alerting | Operational maturity |
| **6** | Extend the registry to the remaining integrations | Repeat the pattern; do not fork it |

Items 0 are defects and should not wait for this phase to be scheduled.
