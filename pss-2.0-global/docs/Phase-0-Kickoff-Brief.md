# PSS 2.0 AIDA — Phase 0 Kickoff Brief

> **Companion to:** `AI-Platform-Architecture.md` (the vision) and `Implementation-Plan-Phase-0-1.md` (the sprint plan).
> **This document:** closes the 7 open items + supplies Week-0 setup checklist + Day-1 agenda. After this, Sprint 1 starts.
> **Status:** Draft for Engineering Lead approval. Mark items ⚠️ if you disagree; rest move ahead as defaults.

---

## 1. Open Items — defaults locked

These were left open at the end of the implementation plan. Below are the defaults I'm locking in. **Flag any disagreement now**; changes after Sprint 1 starts are expensive.

### 1.1 Hosting / region

**Default: same Kubernetes cluster as PSS Core, new namespace `pss-aida`.**

| Why | Trade-off |
|---|---|
| Shared ops surface — same monitoring, secrets, CI/CD, oncall | If AIDA grows to multi-region or needs dedicated GPU nodes later, we carve out a separate cluster. Phase 4 concern. |
| Internal network to PSS Core for gRPC tool calls (no public hop) | — |
| Existing platform team already manages this cluster | — |

Region: **`asia-south1` (or whatever PSS Core's primary is today)**. Add EU/US when first regulated tenant lands.

### 1.2 Key Vault

**Default: Azure Key Vault** *(assuming PSS runs on Azure — if AWS, swap to AWS KMS + Secrets Manager; if neutral/on-prem, HashiCorp Vault).*

Setup:
- New vault: `pss-aida-kv-prod` (and `-dev`, `-staging`).
- Each tenant's provider keys stored as **separate secrets**: `tenant-{companyId}-anthropic`, `tenant-{companyId}-openai`.
- AIDA service identity (managed identity / service principal) gets **Get** + **Decrypt** only — never **List** or **Set** at runtime.
- Key rotation: 90-day reminder per secret, manual rotation for now (Phase 4 = automated).

### 1.3 Provider key procurement (for pilot)

**Default: shared platform keys for the 2 pilots, with per-tenant cost attribution via `ai.audit_log`.**

| Why | Trade-off |
|---|---|
| 2 pilots is too small to negotiate 2 separate enterprise contracts | Pilots can't claim "their" cost in their books — they see usage but platform pays |
| Anthropic + OpenAI enterprise contracts negotiated centrally on volume — better rates | Phase 2 onboarding model: any enterprise tenant brings their own keys (multi-tenant cost model formalised then) |
| Faster to ship | — |

The DB schema (`ai.tenant_provider_key`) is **still built and used** for one reason: when a tenant brings their own key in Phase 2, no code change required — only data.

### 1.4 Pilot tenants

**Default: pick 2 tenants meeting these criteria, in order of priority:**

1. High Donations volume (≥ 500 records last quarter) — Ask-AI's accuracy only shows on real data
2. An identified power-user admin willing to give weekly feedback
3. **Standard PII posture** (no data-residency requirement, English/Tamil acceptable) — defers the hard compliance work
4. **No compliance flag** (no FCRA/HIPAA constraints in the data they want to query)

**Customer Success picks the 2 names** by end of Week 0. Until named, treat them as `Pilot-A` and `Pilot-B` in code/configs.

**Tenants must explicitly opt in** via a one-page consent: AI accesses their grid schema and rows, returns filter expressions only, audit logged. Provided as `docs/pilot-consent.md` (TODO).

### 1.5 Eval set ownership

**Default: BE Lead + 1 BA write 100 questions in Sprint 3 across these 5 categories (20 each):**

| Category | Example |
|---|---|
| Simple field filter | "show donations over ₹50,000" |
| Date range | "last quarter's recurring donations" |
| Multi-condition AND | "unreceipted donations from corporate donors over ₹1L" |
| Multi-condition OR | "donations from Bengaluru or Chennai" |
| Edge cases (vague / impossible) | "interesting donations" / "donations by people named Ramesh who are from Mars" |

**Evaluator** = a JSON file checked into repo. CI runs it on every prompt change; merge blocked if pass rate < 90% on Categories 1–4 (Category 5 is a "does it refuse gracefully?" test).

### 1.6 Cutover

**Default: per-tenant feature flag, 1-week soak per tenant.**

| Week | Action |
|---|---|
| W9 | Pilot-A enabled; daily standup reviews errors, latency, thumbs |
| W10 | Pilot-B enabled (only if Pilot-A passes Definition of Done) |
| W11 | If both pilots stable, AI Settings UI becomes self-service for any tenant; sign-up gates remain |

**Rollback contract:** flipping the feature flag off must take effect within 60s for any tenant (no cache TTL > 60s for `ai_enabled`).

### 1.7 Cost ownership during pilot

**Default: platform absorbs pilot AI costs for 90 days, capped at $200/tenant/month.**

| Why | Trade-off |
|---|---|
| Removes friction; pilots focus on whether the feature works, not whether they can afford it | Platform takes a small hit. Realistic estimate: 2 tenants × Ask-AI traffic at $0.001/call × 5,000 calls/month ≈ $10/tenant/month. Cap is a safety net, not the expected number. |
| At Day 91, pilots either continue paying via standard SaaS tier upcharge OR drop to a read-only "AI off" tier | — |

Budget gate (`monthly_budget_usd = 200`) hard-stops at the cap regardless. No surprise bills.

---

## 2. Defaults summary table

| # | Open item | Default | Owner to confirm/change |
|---|---|---|---|
| 1 | Hosting | Same K8s cluster, new namespace `pss-aida` | DevOps Lead |
| 2 | Key Vault | Azure Key Vault | DevOps Lead |
| 3 | Provider keys | Platform-shared during pilot | Eng Lead |
| 4 | Pilot tenants | 2 tenants meeting criteria (CS picks names) | Customer Success |
| 5 | Eval set | BE Lead + 1 BA, 100 Qs, 5 categories | BE Lead |
| 6 | Cutover | Per-tenant flag, 1-week soak each | Eng Lead |
| 7 | Pilot cost | Platform absorbs, $200/tenant/month cap | Finance + Eng Lead |

---

## 3. Week 0 Setup Checklist

To be completed **before** Sprint 1 Day 1. Owner is one named person per row.

### 3.1 Infrastructure

- [ ] **DevOps:** Postgres user `aida_svc` created with `CREATE SCHEMA ai` permission on the PSS DB
- [ ] **DevOps:** Postgres `pgcrypto` extension enabled (for key wrapping)
- [ ] **DevOps:** New K8s namespace `pss-aida` created; resource quota set (4 CPU / 8 GB RAM initial)
- [ ] **DevOps:** Azure Key Vault `pss-aida-kv-dev` provisioned; AIDA managed identity granted Get+Decrypt
- [ ] **DevOps:** OTel collector endpoint reachable from `pss-aida` namespace
- [ ] **DevOps:** Hangfire dashboard hosted within Aida service (auth gated to internal admins)
- [ ] **DevOps:** New CI/CD pipeline for `Aida` service (build, test, image push, deploy)
- [ ] **DevOps:** Grafana folder "AIDA" created; placeholder dashboards committed in `infra/grafana/`

### 3.2 Provider accounts

- [ ] **Eng Lead:** Anthropic enterprise dev API key procured + stored in Key Vault as `platform-anthropic-dev`
- [ ] **Eng Lead:** OpenAI enterprise dev API key procured + stored in Key Vault as `platform-openai-dev`
- [ ] **Eng Lead:** Confirm both vendor contracts include "no training on customer data" clause
- [ ] **Eng Lead:** Budget alerts configured at vendor portals (Anthropic Console, OpenAI dashboard) — $500/month soft alert in dev

### 3.3 Code scaffolding

- [ ] **BE Lead:** New solution folder `PSS_2.0_Backend/PeopleServe/Services/Aida` created
- [ ] **BE Lead:** Four projects scaffolded: `Aida.Domain`, `Aida.Application`, `Aida.Infrastructure`, `Aida.Api`
- [ ] **BE Lead:** Solution builds locally with empty projects
- [ ] **BE Lead:** `appsettings.Development.json` template (no secrets) committed
- [ ] **BE Lead:** `AidaDbContext` skeleton wired to the shared Postgres with `ai` schema
- [ ] **BE Lead:** First EF migration `Initial_Aida_Schema` creates the schema and an empty marker table

### 3.4 Team & process

- [ ] **Eng Lead:** Confirm allocations: **2 BE engineers** (full-time, 10 weeks), **1 FE engineer** (W5–W10), **1 DevOps** (50%, W1–W4 + spikes after), **1 QA** (W7–W10)
- [ ] **Eng Lead:** Prompt Engineer assigned (or BA doubling) for Sprints 3–5
- [ ] **Eng Lead:** Slack channel `#pss-aida` created; oncall rotation defined (BE lead + 1 secondary)
- [ ] **Eng Lead:** Daily standup time agreed (suggest 10:00 local)
- [ ] **Eng Lead:** Sprint demos scheduled — biweekly Friday 14:00, stakeholders invited

### 3.5 Documentation links shared

- [ ] **Eng Lead:** `AI-Platform-Architecture.md` shared with all stakeholders
- [ ] **Eng Lead:** `Implementation-Plan-Phase-0-1.md` shared with team
- [ ] **Eng Lead:** This kickoff brief shared
- [ ] **Eng Lead:** Mockups (`grid-ask-ai.html`, `global-chatbot.html`, `chat-history.html`, `state-model.html`) shared with stakeholders for visual context

### 3.6 Risk acknowledgements (signed off)

- [ ] **Compliance / Legal:** AIDA does not train models on customer data — vendor contracts reviewed
- [ ] **Compliance / Legal:** Pilot tenant consent template approved
- [ ] **Security:** AIDA per-tenant key isolation pattern reviewed (Key Vault + Postgres cipher)
- [ ] **Security:** Cross-tenant leak test approach approved (`CrossTenantLeakTests` in `Aida.IntegrationTests`)

---

## 4. Sprint 1 — Day 1 Agenda

09:30 — **Kickoff (45 min)**

1. (5 min) Recap goals: by end of W4, an authorized internal client can call `/ai/internal/echo` with full per-tenant routing + audit + fallback
2. (10 min) Walk the 4-project layout and the Phase 0 DB schema (`providers`, `model_class_map`, `tenant_config`, `tenant_provider_preference`, `tenant_provider_key`, `audit_log`, `usage_daily`)
3. (10 min) Walk the routing policy — primary/fallback/circuit breaker decision tree
4. (10 min) Story breakdown for Sprint 1: gateway, adapters, model-class resolver, OTel
5. (5 min) Assign owners
6. (5 min) Sprint goal one-liner agreed and posted to `#pss-aida`

10:15 — **Pair on first stories**

- Pair 1: scaffold `AnthropicAdapter` + integration test against dev key
- Pair 2: design `IModelClient` interface signature + DTOs

15:00 — **Day-1 retro (15 min)**

- What's blocking? Anything missing from Week-0 checklist?
- Confirm tomorrow's standup time and demo target for Friday of Week 2

---

## 5. Communication contract

| Surface | Cadence | Audience |
|---|---|---|
| Daily standup | 10 min @ 10:00 | Aida team |
| Sprint demo | Biweekly Friday 14:00 (30 min) | Aida team + Eng Lead + Customer Success + Product |
| Phase milestone review | End of Phase 0 (W4), end of Phase 1 (W10) | + CTO, + Compliance |
| Slack channel | `#pss-aida` | Aida team + stakeholders |
| Incidents | PagerDuty rotation; auto-page on circuit breaker trip in prod | Oncall BE + DevOps |
| Status updates | Async Friday EOW summary in `#pss-aida` | Team + stakeholders |

---

## 6. What "GA-ready" means for Phase 1

(So we don't keep moving the goalposts.)

At the end of Week 10, **all** of these must be true:

- [ ] **2 pilot tenants** using Ask-AI daily on **Donations + Contacts grids**
- [ ] **Eval pass rate ≥ 90%** on Categories 1–4 of the 100-question set
- [ ] **P95 latency ≤ 2.0s** end-to-end (from user keypress to results rendered)
- [ ] **Median cost ≤ $0.001** per Ask-AI invocation
- [ ] **Zero cross-tenant leaks** in `CrossTenantLeakTests` integration suite
- [ ] **User thumbs-up ≥ 70%** on rated responses (from telemetry)
- [ ] **All 50 red-team prompt-injection inputs** produce safe filters (or graceful refusal)
- [ ] **Per-tenant budget gate** verified in prod (a test tenant at 105% gets hard-stopped)
- [ ] **Audit log** has a row for every single LLM call in prod for the soak week — zero gaps
- [ ] **Two runbooks** approved: "Provider outage" + "Budget exceeded"
- [ ] **Rollback drill** rehearsed: feature flag flipped off, AI invocations stop within 60s

If any item is red at W10, we **soak longer** before GA — we don't ship a half-baked AI feature.

---

## 7. After this brief

The next decision points are:

- **End of Week 2** — Sprint 1 demo. Decision: continue to Sprint 2 as planned, or adjust scope?
- **End of Week 4** — Phase 0 complete. Decision: green-light Phase 1, or extend Phase 0?
- **End of Week 10** — Phase 1 complete. Decision: GA Ask-AI to all tenants, or extend pilot soak?
- **At Week 10** — Start planning Phase 2 (Global Chat + Memory) in detail.

---

*Approved by: __________________________ (Engineering Lead)*
*Date: __________________________*

*Approved by: __________________________ (CTO)*
*Date: __________________________*

*— End of brief —*
