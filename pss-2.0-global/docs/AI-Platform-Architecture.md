# PSS 2.0 — Multi-Tenant AI Orchestration Platform
## Enterprise Architecture & Product Strategy

> **Audience:** CTO, Heads of Engineering, Enterprise Architects, AI Engineers, Product, Compliance, Customer Success.
> **Status:** Architecture Proposal — Draft v1.0
> **Scope:** Tenant-configurable AI substrate powering Grid "Ask AI", Global Chatbot, and Conversational Workflows across all PSS 2.0 modules.
> **Implementation horizon:** 3 quarters to GA (Phase 0–2); 12 months to full agent platform (Phase 3–4).

---

## Table of Contents

1. [Product Vision](#1-product-vision)
2. [Business Problem](#2-business-problem)
3. [Architecture Goals & Non-Goals](#3-architecture-goals--non-goals)
4. [Multi-Tenant Strategy](#4-multi-tenant-strategy)
5. [AI Orchestration Flow](#5-ai-orchestration-flow)
6. [Skills Architecture](#6-skills-architecture)
7. [Agent Architecture](#7-agent-architecture)
8. [Prompt Management Architecture](#8-prompt-management-architecture)
9. [Provider Gateway & Fallback Routing](#9-provider-gateway--fallback-routing)
10. [Chat History & Memory Design](#10-chat-history--memory-design)
11. [Hooks & Event System](#11-hooks--event-system)
12. [Governance, Security & Compliance](#12-governance-security--compliance)
13. [Database Design](#13-database-design)
14. [Vector Search Design](#14-vector-search-design)
15. [API Design](#15-api-design)
16. [Configuration Management](#16-configuration-management)
17. [Observability & Monitoring](#17-observability--monitoring)
18. [Scalability Strategy](#18-scalability-strategy)
19. [Deployment Architecture](#19-deployment-architecture)
20. [High-Level Diagrams](#20-high-level-diagrams)
21. [Example Workflows](#21-example-workflows)
22. [Tenant Customization Examples](#22-tenant-customization-examples)
23. [Failure Handling](#23-failure-handling)
24. [AI Cost Optimization](#24-ai-cost-optimization)
25. [Recommended Technical Stack](#25-recommended-technical-stack)
26. [Roadmap (Phase 0 → Phase 4)](#26-roadmap-phase-0--phase-4)
27. [Risks & Mitigation](#27-risks--mitigation)
28. [Best Practices](#28-best-practices)
29. [Future AI Expansion Strategy](#29-future-ai-expansion-strategy)

---

## 1. Product Vision

> **"Make every PSS 2.0 module AI-native, while making every client's AI behavior a configuration — not a code branch."**

We are building **AIDA** (AI Decision Assistant) — a tenant-aware AI substrate baked into PSS 2.0. AIDA powers three end-user surfaces:

| Surface | Pattern | Anchored entity |
|---|---|---|
| **Grid Ask-AI** | Stateless NL → query expression | One grid / one entity |
| **Global Chatbot** | Stateful retrieval-augmented chat with tool calls | Whole tenant workspace |
| **Conversational Workflows** | Multi-turn agent flows triggered by hooks or user | A specific business process |

Underneath the three surfaces, **one shared substrate**: provider gateway, skills registry, prompt registry, memory store, audit pipeline, policy engine. Onboarding a new client should be **configuration, not code**.

**North-star metric:** ≥ 70% of new client AI requirements satisfied via configuration alone (no code change).

---

## 2. Business Problem

### 2.1 Today's reality

- ReportGen-AI prototype: hardcoded prompts, hardcoded provider keys, no tenancy, no fallback, no audit. Works for one client; doesn't scale to N.
- Every new client AI request becomes a custom development cycle (4–8 weeks).
- No central inventory of what AI does, where, for whom, at what cost.
- No way to disable AI per tenant for compliance-sensitive customers.
- LLM provider lock-in: a Claude outage = AI down for everyone.

### 2.2 Heterogeneous client expectations

| Client archetype | Expectation |
|---|---|
| **Style-driven** | "Make it answer like Claude" / "Like ChatGPT" / "Like Perplexity with citations" |
| **Compliance-strict** | "AI must mask PII, never leave India, citations mandatory" |
| **AI-off** | "Disable AI entirely until our board approves" |
| **AI-light** | "Only for reports — no chatbot, no automation" |
| **AI-deep** | "Automate triage, flag anomalies, draft acknowledgements" |
| **Hybrid** | "AI drafts, humans approve every output" |
| **Brand-aligned** | "Use our voice, our taxonomy, our tone" |

### 2.3 The thesis

A platform layer — not a feature — turns this into a configuration problem. Every client choice (provider, persona, skills enabled, retention, masking, approval workflows) is a **policy row in a database**, not a code branch.

---

## 3. Architecture Goals & Non-Goals

### 3.1 Goals

1. **Tenant isolation** at every layer (data, embeddings, prompts, tools, audit, cost).
2. **Provider neutrality** — Claude / OpenAI / Gemini / Perplexity / local, swappable per-tenant per-skill.
3. **Configuration over code** — new client = config rows + optional skill overrides.
4. **Permission-aware retrieval** — AI never sees what the user can't.
5. **Auditable & reversible** — every prompt, every tool call, every output recorded.
6. **Cost-predictable** — per-tenant budgets enforced before spending.
7. **Hooks-extensible** — domain events trigger AI workflows declaratively.
8. **Degradable** — fallback paths, including "human takes over".

### 3.2 Non-Goals (Phase 1–2)

- Training/fine-tuning custom models. (Defer to Phase 4.)
- Generic "build-your-own-agent" UI for end users. (Power users only in Phase 3.)
- Voice / image / video modalities. (Phase 4+.)
- Self-hosted LLMs as default. (Optional add-on for regulated tenants.)

---

## 4. Multi-Tenant Strategy

### 4.1 Tenancy primitives

Every AI resource carries `(CompanyId)`. The same way PSS today scopes Donations, Campaigns, and Donors, AIDA scopes **everything**:

| Resource | Tenant boundary |
|---|---|
| Chat sessions & messages | `CompanyId + UserId` |
| Memory entries | `CompanyId + UserId + scope` |
| Embeddings (vectors) | `CompanyId` filter in every query |
| Prompts (custom) | `CompanyId` override row |
| Skills (enabled set) | `CompanyId` config |
| Tools available | `CompanyId` config × user role |
| Provider config | `CompanyId` config |
| Quotas / budgets | `CompanyId` (org) + `UserId` (per-seat) |
| Audit logs | `CompanyId` partition |
| Knowledge base docs | `CompanyId` |

### 4.2 The three-layer config model

```
┌──────────────────────────────────────┐
│  Platform Layer  (immutable defaults)│  ← provider list, base prompts, base skills
└──────────────────────────────────────┘
                 ▼ override
┌──────────────────────────────────────┐
│  Tenant Layer    (per-company)       │  ← chosen provider, persona, skills enabled
└──────────────────────────────────────┘
                 ▼ override
┌──────────────────────────────────────┐
│  Workspace/User Layer (per-user/team)│  ← personal pinned skills, language pref
└──────────────────────────────────────┘
                 ▼ runtime
┌──────────────────────────────────────┐
│  Request Context (this turn)         │  ← skill being invoked, grid/screen, locale
└──────────────────────────────────────┘
                 ▼
        Final Compiled Behavior
```

Each layer **only overrides what it sets**; everything else inherits. The compiled config is computed once per request and cached for the session.

### 4.3 Isolation enforcement points

| Point | Mechanism |
|---|---|
| API edge | JWT carries `CompanyId`; middleware rejects any request whose body/query mentions another company |
| Memory store | `WHERE CompanyId = @currentCompanyId` enforced at repository, not query layer |
| Vector search | `filter: {CompanyId: @tenant}` on every Qdrant/pgvector query — non-optional |
| Tool execution | Each tool re-checks PSS authorization (Role, Capability, RLS) — AI provides args, app authorizes |
| Provider call | Per-tenant key OR shared key with per-tenant budget |
| Audit | Append-only audit row written *before* provider call (so failures are still logged) |

---

## 5. AI Orchestration Flow

### 5.1 The canonical request lifecycle

```
[1] User sends message ──► AI Gateway
                          │
[2]                       ├─► Resolve tenant config (cached)
[3]                       ├─► Identify intent / skill
[4]                       ├─► Policy gate (allowed? PII? budget?)
[5]                       ├─► Retrieve memory + KB context (permission-filtered)
[6]                       ├─► Compile prompt (base ← tenant ← workflow ← runtime)
[7]                       ├─► Route to provider (primary/fallback)
[8]                       ├─► LLM call (streaming)
[9]                       ├─► Tool invocation loop (if requested)
[10]                      ├─► Validate output (guardrails, schema, PII)
[11]                      ├─► Persist (memory + audit + cost)
[12]                      └─► Stream response to client
```

### 5.2 The orchestration loop (with tool calls)

```
  ┌──────────────────────┐
  │   Skill Resolver     │ ──► picks skill from registry
  └──────┬───────────────┘
         │
  ┌──────▼───────────────┐
  │  Prompt Compiler     │ ──► base + tenant override + ctx injection
  └──────┬───────────────┘
         │
  ┌──────▼───────────────┐
  │  Provider Gateway    │ ──► Claude / OpenAI / Gemini / local
  └──────┬───────────────┘
         │
   ┌─────▼─────┐
   │ LLM call  │◄──────────┐
   └─────┬─────┘           │
         │ tool_use?       │
    ┌────▼────┐  yes   ┌───┴──────────┐
    │   ?     │───────►│ Tool runner  │  (auth, execute, return result)
    └────┬────┘        └──────────────┘
         │ no
   ┌─────▼─────┐
   │  Guardrail│
   └─────┬─────┘
         │
   ┌─────▼─────────────┐
   │ Memory + Audit    │
   └─────┬─────────────┘
         │
   ┌─────▼─────┐
   │ Response  │
   └───────────┘
```

---

## 6. Skills Architecture

### 6.1 What is a skill?

A **skill** is a discrete, reusable AI capability — the unit of orchestration. It encapsulates:

- A name and trigger description (when to invoke)
- A prompt template (with placeholders for context injection)
- An optional declared toolset (which tools it may call)
- Optional input/output schemas (JSON Schema)
- Default routing policy (preferred provider / model class)
- Permission/capability requirements
- Cost & latency expectations

The pattern echoes the existing `.claude/skills/<name>/SKILL.md` convention — we lift it from filesystem into a **database-backed registry** for runtime swappability.

### 6.2 Skill manifest (canonical)

```yaml
id: donation_anomaly_detection
version: 1.4.0
visibility: platform        # platform | tenant_private | shared
description: |
  Inspects a donation record and recent donor history; flags
  potential fraud, duplicate, or compliance issues.
prompt_template_id: prompt_donation_anomaly_v3
input_schema_id: schema_donation_anomaly_in
output_schema_id: schema_donation_anomaly_out
tools_allowed:
  - getDonorRecentDonations
  - getCampaignContext
  - lookupCountryRiskScore
provider_policy:
  preferred_model_class: reasoning_mid       # mapped per-tenant
  max_tokens: 1500
  temperature: 0.2
permissions:
  role_any_of: [BUSINESSADMIN, ComplianceOfficer]
  capability_required: donation.read
cost_class: medium          # cheap | medium | expensive
chainable: true
hooks_compatible: [donation.created]
```

### 6.3 Skill registry layers

```
┌──────────────────────────────────┐
│ Platform Skills (global library) │   ← PSS-built, all tenants inherit
└──────────────────────────────────┘
              │
┌──────────────────────────────────┐
│ Tenant Skill Overrides           │   ← override prompt / disable / re-route
└──────────────────────────────────┘
              │
┌──────────────────────────────────┐
│ Tenant-Private Skills            │   ← custom skills only this tenant has
└──────────────────────────────────┘
```

### 6.4 Initial skill catalog (PSS 2.0 specific)

| Skill | Surface | Notes |
|---|---|---|
| `grid_ask_ai` | Grid | NL → GraphQL filter expression |
| `report_generator` | Reports | NL → report config + SQL (read-only) |
| `donation_anomaly_detection` | Hooks | On `donation.created`, score risk |
| `donor_summary` | Chatbot | Profile + history + suggested next-best-action |
| `acknowledgement_drafter` | Hooks | Draft thank-you email, human-approved |
| `dik_valuation_assistant` | FLOW | Help estimate fair-market value for in-kind donations |
| `compliance_validator` | Hooks | Verify donation against policy (e.g., foreign-funds rules) |
| `campaign_performance_explainer` | Dashboard | "Why is this campaign underperforming?" |
| `duplicate_donor_resolver` | Workflow | Identify and merge candidates |
| `pledge_followup_planner` | Workflow | Schedule reminder cadence |
| `fx_explanation` | Read-only | Explain why a donation in USD was booked at X rate |
| `meeting_notes_to_actions` | Chatbot | Paste notes → tasks + assignments |

### 6.5 Skill composition

Skills can **chain** — the output of one becomes input to another, mediated by the **planner agent** (see §7). Example: *"Acknowledge yesterday's donations"* →
`list_donations(filter)` → for each → `acknowledgement_drafter` → `compliance_validator` → `email_send` (tool).

---

## 7. Agent Architecture

### 7.1 Agents vs skills

| Skill | Agent |
|---|---|
| One LLM call, well-scoped | Loops; calls multiple skills/tools |
| Stateless within call | Holds task state across turns |
| Declarative manifest | Has a system prompt + control loop |
| "Verb" | "Worker" |

Your existing `.claude/agents/` (BA, Solution Resolver, UX, Backend Dev, FE Dev, Tester, PM) is *exactly* this pattern, scoped to dev-time. AIDA brings the same pattern to runtime.

### 7.2 The agent roster

| Agent | Responsibility |
|---|---|
| **Planner** | Decompose user goal → ordered list of skills/tools |
| **Executor** | Run a skill or tool, marshal IO |
| **Validator** | Check output against schema + business rules |
| **Compliance** | Apply tenant policies (masking, restricted topics) |
| **Reporting** | Specialized for report generation (uses report skill family) |
| **Workflow** | Drive a multi-step business workflow (e.g., pledge follow-up) |
| **Analytics** | Numeric reasoning over result sets — never invents numbers |
| **Critic** *(optional)* | LLM-as-judge for response quality scoring |

### 7.3 Inter-agent communication

Agents communicate via a **shared blackboard** (Redis hash, conversation-scoped). Each writes structured artifacts; subsequent agents read them. No agent calls another directly — all routing goes through the orchestrator.

```
                ┌────────────────────────────┐
User goal ────► │       Orchestrator         │
                └──────┬──────────┬──────────┘
                       │          │
                  ┌────▼───┐  ┌───▼─────┐
                  │Planner │  │Compliance│
                  └────┬───┘  └─────────┘
                       │
                  ┌────▼────┐
                  │Executor │──► Skill A ──► Skill B ──► Tool X
                  └────┬────┘
                       │
                  ┌────▼─────┐
                  │Validator │
                  └────┬─────┘
                       │
                  ┌────▼────┐
                  │Response │
                  └─────────┘
```

### 7.4 Agent lifecycle

- **Spawned** per conversation turn (light, stateless instances).
- **Bounded** by a step budget (max 8 steps default) and time budget (60s).
- **Cancellable** — user-initiated cancel propagates through the orchestrator.
- **Resumable** — for long-running async workflows, state checkpointed every N steps.

---

## 8. Prompt Management Architecture

### 8.1 The four-layer prompt model

```
   ┌────────────────────────────────┐
   │ ① Base Prompt (skill default)  │  ─ versioned in registry
   └────────────────────────────────┘
                 ▼ tenant overrides
   ┌────────────────────────────────┐
   │ ② Tenant Override              │  ─ optional, tenant-specific
   └────────────────────────────────┘
                 ▼ workflow injects
   ┌────────────────────────────────┐
   │ ③ Workflow Prompt Injection    │  ─ e.g., "you are in an approval flow"
   └────────────────────────────────┘
                 ▼ runtime injects
   ┌────────────────────────────────┐
   │ ④ Runtime Context              │  ─ user, locale, data, KB excerpts
   └────────────────────────────────┘
                 ▼
        Final Compiled Prompt
```

### 8.2 Prompt as a first-class entity

Prompts live in **PostgreSQL** (source of truth) with semantic search via **embeddings in Qdrant/pgvector** (for "find similar prompt" tooling, A/B selection).

```
Prompts table:
  PromptId (UUID), Key, Version, Status (Draft|Approved|Published|Archived),
  Body, Variables (JSONB), ParentPromptId (lineage),
  CompanyId NULL (= platform) OR set (= tenant override),
  CreatedBy, CreatedDate, ApprovedBy, ApprovedDate, PublishedDate,
  ABBucket (NULL|'A'|'B'), Metadata JSONB
```

### 8.3 Compilation pipeline

```
compile(skill_id, ctx) {
  base    = registry.getApproved(skill_id, ctx.tenantId)   // tenant override else platform
  context = retrieve(skill_id, ctx)                        // memory + KB + RAG
  vars    = collect(ctx.user, ctx.locale, ctx.data, ctx.persona)
  prompt  = template.render(base.body, { ...vars, ...context })
  return { system, messages, model_hints, audit_id }
}
```

### 8.4 Governance & lifecycle

| Stage | Who | Action |
|---|---|---|
| Draft | Prompt Engineer | Author/edit; runs locally against eval set |
| In Review | Tech Lead | Peer-reviews; compares vs. previous version |
| Approved | PromptOps | Marks promotable |
| Published (A/B) | PromptOps | Releases to % of traffic |
| Active | — | Default for all/segment |
| Archived | — | Replaced by new version; retained for audit |

**Rollback** is a one-row update: flip `Status` to `Archived`, previous version reactivates automatically (no deploy needed).

### 8.5 A/B testing

Each conversation turn is hashed `(SessionId + SkillId)` → bucket A or B. Outputs are scored (latency, cost, user thumbs, downstream task success). Winner is promoted.

### 8.6 Prompt as code (still)

Prompts ship via **migrations** (versioned SQL inserts) so they're code-reviewed, not just hand-edited in production. The UI can still edit, but every UI edit creates a new `Version` row — never overwriting.

---

## 9. Provider Gateway & Fallback Routing

### 9.1 The gateway abstraction

```
┌─────────────────────────────────────────────────────────────┐
│                   AIDA Provider Gateway                     │
├─────────────────────────────────────────────────────────────┤
│  IModelClient interface:                                    │
│    SendAsync(ChatRequest) → ChatResponse                    │
│    StreamAsync(ChatRequest) → IAsyncEnumerable<ChatChunk>   │
│    EmbedAsync(string[]) → float[][]                         │
└─────────────────────────────────────────────────────────────┘
       │             │             │            │
   ┌───▼───┐    ┌────▼───┐    ┌────▼────┐  ┌───▼────┐
   │Claude │    │ OpenAI │    │ Gemini  │  │ Local  │
   │Adapter│    │Adapter │    │Adapter  │  │Adapter │
   └───────┘    └────────┘    └─────────┘  └────────┘
```

All app code talks to `IModelClient`. The concrete adapter is selected per request via the **router**.

### 9.2 Model classes (abstraction over model IDs)

Tenants don't pick "claude-sonnet-4-6"; they pick a **class**, and the platform maps to current best model:

| Class | Maps to (today) | Use case |
|---|---|---|
| `reasoning_top` | Claude Opus 4.7 | Hard reasoning, agent planning |
| `reasoning_mid` | Claude Sonnet 4.6 / GPT-4.1 | Default for most skills |
| `reasoning_fast` | Claude Haiku 4.5 / GPT-4.1-mini | Grid Ask-AI, classification |
| `embedding` | OpenAI text-embedding-3-small / Voyage | Vectorization |
| `vision` | Claude Sonnet / GPT-4o | OCR, receipts |
| `cited_search` | Perplexity Sonar | When tenant prefers citation-style answers |

Provider/model upgrades are a config flip, not a code change.

### 9.3 Routing policy

```yaml
routing_policy:                       # platform default
  reasoning_mid:
    primary:   { provider: anthropic, model: claude-sonnet-4-6, timeout_ms: 30000 }
    fallback:
      - { provider: openai,    model: gpt-4.1,       timeout_ms: 25000 }
      - { provider: gemini,    model: gemini-2.5-pro, timeout_ms: 25000 }
      - { provider: local,     model: llama-3.1-70b,  timeout_ms: 60000 }
    retry:     { max_attempts: 2, backoff: exponential, jitter: true }
    circuit_breaker: { threshold: 5, window_sec: 60, half_open_after_sec: 120 }
```

### 9.4 Routing decision inputs

| Input | Effect |
|---|---|
| Provider health (rolling 5-min error rate) | Skip if unhealthy |
| P95 latency | Skip if breaching SLO |
| Tenant preference | Override default order |
| Skill cost class | Cheap class doesn't use top tier |
| Budget remaining | Force cheap tier when ≤ 10% budget |
| Region pinning | EU tenant can't use US-only model |
| Compliance flags | "No third-party LLM" → local only |

### 9.5 Fallback semantics

- **Soft fallback** (retryable): timeout, 5xx, rate-limit → next provider.
- **Hard fallback** (non-retryable): content-filter block, auth failure → return error, do **not** silently swap. Compliance must know.
- **Quality fallback**: if response fails schema validation twice, escalate model class (mid → top), not provider.

### 9.6 Health monitoring

Each adapter emits: latency histogram, error rate, token cost, fallback-trigger counter. Surfaced in Grafana + alerted to oncall.

---

## 10. Chat History & Memory Design

### 10.1 Statefulness across the three surfaces (the cheat sheet)

This is **the** most important framing for AIDA. Misunderstand it and you'll either burn money persisting things that don't need persistence, or ship a chatbot that loses people's work on refresh.

| Surface | In-turn memory | Multi-turn state | Persisted to DB | Survives refresh | In History UI | SessionId |
|---|---|---|---|---|---|---|
| **Grid Ask-AI** | Yes (just to compile prompt) | **No** | Audit row + optional 1-turn session | N/A (single shot) | Opt-in | New per query (Design B) or none (Design A) |
| **Global Chat** | Yes | **Yes** | Every message | **Yes** | Yes | One per conversation |
| **Chat History** | — (read-only) | — | Reads only | Yes | It *is* the UI | Browses existing |

#### Working memory vs persistent memory — don't conflate them

```
┌───────────────────────────────────────────────────────────┐
│  Working memory (Redis)  —  EPHEMERAL, evictable          │
│  Compiled context for the next turn. Lost on Redis evict  │
│  or restart. Rebuilt from Postgres on demand.             │
└───────────────────────────────────────────────────────────┘
                            ▲ rebuild
┌───────────────────────────────────────────────────────────┐
│  Persistent memory (Postgres)  —  SOURCE OF TRUTH         │
│  ai.ChatSessions + ai.ChatMessages, written every turn.   │
│  Survives refresh, restart, eviction.                     │
└───────────────────────────────────────────────────────────┘
```

Working memory is **derived state** — it can always be rebuilt from Postgres. Postgres is what we owe the user.

#### The refresh-safety contract (Global Chat)

We promise the user: *"anything you sent or saw is recoverable on refresh."*

Implementation:

1. `SessionId UUID` lives in URL (`?session={guid}`) and `localStorage`.
2. Every user message and every assistant message is **persisted to Postgres before** the streamed response is closed.
3. On page load, frontend reads `SessionId` → GraphQL `chatSession(id)` → renders last N messages.
4. Redis working memory is rebuilt lazily on the next user send.

**The only tolerated loss:** if the LLM is mid-stream when the user refreshes, the partial reply is dropped (it was never committed). The user retries via *Regenerate*. Everything completed survives.

#### SessionId minting — when does a new GUID get created?

| Trigger | New SessionId? | Surface tag |
|---|---|---|
| User clicks **+ New chat** | ✅ Yes | `global_chat` |
| Grid Ask-AI query (**Design B — recommended**) | ✅ Yes, auto-archived | `grid_ask` |
| Grid Ask-AI query (Design A — minimal) | ❌ No — audit row only | — |
| Hook fires (`donation.created` etc.) | ✅ Yes | `hook` |
| Workflow starts (DIK valuation, duplicate-resolve…) | ✅ Yes | `workflow` |
| User resumes from History | ❌ No — same SessionId | (same) |
| Page refresh / tab close+reopen | ❌ No — same SessionId | (same) |

#### Grid Ask-AI: Design A vs Design B

| | Design A | Design B (**recommended default**) |
|---|---|---|
| Storage | Audit row only | New `ChatSessions(Surface='grid_ask', Status='auto_archived')` per query |
| Pros | Smallest footprint; cheapest write path | Uniform data model; appears in History UI's "Grid" filter; consistent cost/usage reporting |
| Cons | Grid queries are special-cased in every reporting path | One extra row per query (~tens of bytes) |
| Pick if | Tenants are extremely cost-sensitive and grid query volume is huge | Default — uniformity pays back day-2 |

#### Identifier hierarchy

```
SessionId  (UUID)              ← one conversation
   ├── MessageId (bigserial)   ← each user/AI turn
   │     ├── AuditId (bigserial)   ← each LLM call (>1 on retry/fallback)
   │     └── ToolCallId (uuid)     ← inside ToolCallsJson
   ├── EventId (UUID, nullable)    ← hook trigger if session was hook-spawned
   └── CompanyId · UserId (BIGINT) ← tenancy keys (on every row)
```

`SessionId` is the durable key. Every child identifier hangs off it. Frontend persists `SessionId` in URL + localStorage; backend uses it for memory partitioning, audit grouping, and resume-from-history.

---

### 10.2 Memory taxonomy

| Type | TTL | Scope | Backing store | Purpose |
|---|---|---|---|---|
| **Working memory** | conversation lifetime | session | Redis | Most recent N turns, tool results |
| **Episodic memory** | tenant-configurable (default 30 days) | user | Postgres | Past conversations, queryable |
| **Semantic memory** | until invalidated | user / team / tenant | Postgres + Qdrant | Facts, preferences ("user prefers PDF") |
| **Knowledge base** | until invalidated | tenant | Postgres + Qdrant | Indexed business docs, policies |
| **Skill memory** | until invalidated | skill × tenant | Postgres + Qdrant | Few-shot examples, prior good outputs |

### 10.3 Working memory: token-budgeted context window

For a chat turn, working memory assembles:

```
[system prompt (compiled)]
[N pinned facts from semantic memory]
[K retrieved chunks from KB (top by similarity)]
[last M turns of dialog (most recent)]
[summary of older turns if window > budget]
[current user message]
```

Budgeted to ≤ 70% of model context window. Older turns are summarized via the **summarizer skill**, not dropped raw.

### 10.4 Conversation summarization

Triggered when conversation > 20 turns OR token budget > 70%:

1. Take turns 1..N-10 (keep last 10 raw).
2. Summarize via `reasoning_fast` class into ≤ 400 tokens.
3. Store summary as a memory entry; replace raw turns in context window.
4. Original raw turns kept in DB for audit, hidden from context.

### 10.5 Semantic memory: when does the bot "learn"?

Explicit signals only — no silent learning:

- User says: "remember that…"
- A workflow declares: `persist_fact(text)`
- Skill output explicitly emits a `learned_fact` field

Each entry has provenance (who, when, source) and is **user-editable** ("forget that I prefer PDF").

### 10.6 Retrieval

Hybrid retrieval = BM25 (Postgres FTS or Elastic) + vector (Qdrant). Reciprocal Rank Fusion on results. Permission filter pushed into the storage layer.

```
results = fuse(
    bm25_search(query,  filter={CompanyId, allowed_doc_ids}),
    vector_search(query, filter={CompanyId, allowed_doc_ids}),
    method=RRF, k=60
)[:topK]
```

### 10.7 Memory isolation

- `(CompanyId, UserId)` enforced at the repository.
- Cross-user shared memory is opt-in per tenant (team memory).
- Cross-tenant **never**.

### 10.8 Hallucination mitigation

- **Grounded answers** (cited): retrieval results carry IDs; the response template *requires* `[#cite_id]` markers. Validator strips uncited claims when the skill is configured `strict_grounding=true`.
- **Numeric facts** never come from the LLM. Numbers are produced by tools (SQL, aggregates) and **inlined** post-LLM by the formatter.
- **Critic agent** (optional, expensive) re-reads the response and the source docs and scores faithfulness 0–1; below threshold = retry once with stricter prompt.

---

## 11. Hooks & Event System

### 11.1 What's a hook?

A declarative binding: *"when **this domain event** occurs in **this tenant**, run **this skill/agent** with **these args**."* Mirrors the `.claude` hooks idea, productionized.

### 11.2 Event taxonomy (initial)

| Event | Payload |
|---|---|
| `donation.created` | DonationId, DonorId, Amount, Channel |
| `donation.matched` | (matching gift) |
| `donor.profile_updated` | DonorId, changed fields |
| `pledge.due_soon` | PledgeId, due in N days |
| `campaign.milestone` | (50%, 100%) |
| `case.escalated` | CaseId, priority |
| `report.scheduled.before` | ReportId |
| `anomaly.detected` | (from a hook itself) |
| `external_page.submission` | PageId, submission data |
| `dik.realized` | DonationInKindId |
| `fx_rate.synced` | (post-OpenExchangeRates sync) |

### 11.3 Hook binding

```yaml
hook:
  id: ack_after_donation
  event: donation.created
  tenants: [acme_charity]                # or [*] for global
  condition: "$.Amount >= 1000"          # JsonLogic filter
  action:
    skill: acknowledgement_drafter
    args: { donation_id: "$.DonationId" }
    delivery:
      mode: async                        # sync | async
      queue: ai-events
      retry: { max: 3, backoff: exponential }
    on_success:
      - tool: queue_email_for_review     # human-in-the-loop
    on_failure:
      - tool: log_and_alert
  enabled: true
```

### 11.4 Execution model

- **Sync hooks** — run in-process, block the originating transaction. Use for low-latency validation (e.g., compliance check before save).
- **Async hooks** — enqueue to **RabbitMQ / Azure Service Bus**, worker pool consumes. Default mode.
- **Idempotency** — every event carries an `EventId`; consumer dedupes on `(EventId, HookId)`.
- **Failure** — DLQ + alert; retried per policy; never silently dropped.

### 11.5 Why this matters

Hooks turn AI from a chatbox into an **ambient assistant**. Acknowledge donations, flag anomalies, draft follow-ups, summarize cases — all without a user clicking anything. And every behavior is one config row away from being disabled per tenant.

---

## 12. Governance, Security & Compliance

### 12.1 Defense in depth

```
   ┌──────────────────────────────────────┐
   │  Edge: WAF, rate-limit, auth         │
   ├──────────────────────────────────────┤
   │  Policy gate (pre-LLM)               │  ← can this tenant run this skill?
   ├──────────────────────────────────────┤
   │  PII redaction (pre-LLM)             │  ← mask before provider sees data
   ├──────────────────────────────────────┤
   │  Retrieval filter (permission-aware) │  ← user can't pull doc they can't read
   ├──────────────────────────────────────┤
   │  Provider call                       │
   ├──────────────────────────────────────┤
   │  Output moderation                   │  ← block unsafe, re-mask if needed
   ├──────────────────────────────────────┤
   │  Tool authorization (per call)       │  ← AI provides args, app authorizes
   ├──────────────────────────────────────┤
   │  Audit log (append-only)             │
   └──────────────────────────────────────┘
```

### 12.2 PII handling

Configurable PII handling per tenant:

| Mode | Behavior |
|---|---|
| `none` | No special handling (low-risk tenants, internal use) |
| `mask_outbound` | Names → `[NAME_1]`, emails → `[EMAIL_1]` before LLM; un-mask on response |
| `redact_outbound` | Replace with placeholder; never restored |
| `local_only` | PII-bearing fields force local-model routing |

Detection: regex + Microsoft Presidio (or AWS Comprehend) for high-confidence cases.

### 12.3 Audit log (the centerpiece)

Append-only, partitioned by month, retained per tenant policy.

```
AIAuditLog:
  AuditId, CompanyId, UserId, SessionId, SkillId, AgentId,
  Provider, Model, PromptCompiledHash, InputTokens, OutputTokens,
  CostUsd, LatencyMs, ToolCalls JSONB, RetrievedDocIds INT[],
  PolicyChecks JSONB, GuardrailFlags JSONB,
  Outcome (success|filtered|error|fallback), ErrorClass,
  CreatedDate
```

**Prompt content** is **not** stored in audit by default (only the hash). Full content lives in `ChatMessages` with the tenant's chosen retention. Compliance can opt-in to full prompt retention for regulated workloads.

### 12.4 Data residency

- Tenant `Region` field (`india` / `eu` / `us` / `mea`).
- Provider gateway honors region — refuses providers without a regional endpoint.
- Data stores (Postgres, Qdrant, Redis) deployed regionally; tenant routed to its region's stack.

### 12.5 Role-based AI permissions

Reuses PSS RBAC (Role × Capability). New capabilities:

- `ai.chat.use`
- `ai.skill.<skill_id>.invoke`
- `ai.config.manage`
- `ai.audit.read`
- `ai.prompt.edit`
- `ai.workflow.publish`

### 12.6 Compliance policies (per tenant)

```yaml
compliance_profile:
  pii_mode: mask_outbound
  data_residency: india
  allowed_providers: [anthropic, local]
  block_topics: [investment_advice, medical_diagnosis]
  block_countries_for_donor_data: [...]
  require_human_approval_for:
    - acknowledgement_drafter.send
    - email_send
  retention:
    chat_messages_days: 60
    audit_log_days: 2555     # 7 years
    memory_facts_days: 365
```

---

## 13. Database Design

> Postgres (per PSS convention). All FKs preserve the audit fields `CreatedDate / CreatedBy / ModifiedDate / ModifiedBy`. `IsActive`, `IsDeleted` standard soft-delete. `CompanyId` everywhere.

### 13.1 Core tables

```sql
-- AI providers (platform-level + tenant override)
CREATE TABLE ai.Providers (
  ProviderId         BIGSERIAL PRIMARY KEY,
  Code               TEXT NOT NULL UNIQUE,   -- 'anthropic', 'openai', 'gemini', 'local'
  Name               TEXT NOT NULL,
  BaseUrl            TEXT NOT NULL,
  Capabilities       JSONB NOT NULL,         -- { chat, embed, vision, ... }
  AuthMode           TEXT NOT NULL,          -- 'api_key' | 'oauth' | 'iam'
  HealthEndpoint     TEXT,
  IsEnabledPlatform  BOOLEAN NOT NULL DEFAULT TRUE,
  CreatedDate        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Model classes -> concrete models
CREATE TABLE ai.ModelClassMap (
  ClassCode         TEXT NOT NULL,          -- 'reasoning_top'
  ProviderId        BIGINT NOT NULL REFERENCES ai.Providers,
  ModelId           TEXT NOT NULL,          -- 'claude-opus-4-7'
  Priority          INT NOT NULL,           -- 1 = primary
  CostInPerMTok     NUMERIC(10,4),
  CostOutPerMTok    NUMERIC(10,4),
  ContextWindow     INT,
  IsActive          BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (ClassCode, ProviderId, ModelId)
);

-- Tenant AI configuration (1:1 with Company)
CREATE TABLE ai.TenantConfig (
  CompanyId             BIGINT PRIMARY KEY REFERENCES Company,
  AiEnabled             BOOLEAN NOT NULL DEFAULT TRUE,
  Region                TEXT NOT NULL,        -- 'india' | 'eu' | 'us' | 'mea'
  PersonaCode           TEXT,                 -- 'claude-style' | 'gpt-style' | 'perplexity-style'
  ChatRetentionDays     INT NOT NULL DEFAULT 60,
  MemoryRetentionDays   INT NOT NULL DEFAULT 365,
  MonthlyBudgetUsd      NUMERIC(12,2),
  PiiMode               TEXT NOT NULL DEFAULT 'mask_outbound',
  Metadata              JSONB,
  CreatedDate           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ModifiedDate          TIMESTAMPTZ
);

-- Provider preferences per tenant (overrides platform routing)
CREATE TABLE ai.TenantProviderPreference (
  CompanyId        BIGINT NOT NULL REFERENCES Company,
  ClassCode        TEXT NOT NULL,
  ProviderId       BIGINT NOT NULL REFERENCES ai.Providers,
  ModelId          TEXT NOT NULL,
  Priority         INT NOT NULL,
  IsActive         BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (CompanyId, ClassCode, ProviderId, ModelId)
);

-- Per-tenant API keys (provider keys; encrypted at rest via pgcrypto/KMS)
CREATE TABLE ai.TenantProviderKey (
  CompanyId        BIGINT NOT NULL REFERENCES Company,
  ProviderId       BIGINT NOT NULL REFERENCES ai.Providers,
  KeyCipher        BYTEA NOT NULL,
  KeyVersion       INT NOT NULL,
  RotatedDate      TIMESTAMPTZ,
  ExpiresDate      TIMESTAMPTZ,
  PRIMARY KEY (CompanyId, ProviderId, KeyVersion)
);

-- Skills registry
CREATE TABLE ai.Skills (
  SkillId          BIGSERIAL PRIMARY KEY,
  Code             TEXT NOT NULL,
  Version          TEXT NOT NULL,
  Visibility       TEXT NOT NULL,            -- 'platform' | 'tenant_private' | 'shared'
  OwnerCompanyId   BIGINT NULL REFERENCES Company,  -- NULL = platform
  Manifest         JSONB NOT NULL,
  Status           TEXT NOT NULL,            -- 'draft' | 'approved' | 'published' | 'archived'
  CreatedDate      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ApprovedDate     TIMESTAMPTZ,
  UNIQUE (Code, Version, OwnerCompanyId)
);

-- Skills enabled per tenant (subset of platform skills + tenant-private ones)
CREATE TABLE ai.TenantSkill (
  CompanyId        BIGINT NOT NULL REFERENCES Company,
  SkillId          BIGINT NOT NULL REFERENCES ai.Skills,
  IsEnabled        BOOLEAN NOT NULL DEFAULT TRUE,
  ProviderOverride TEXT NULL,                -- override model class
  PromptOverrideId BIGINT NULL,              -- override prompt
  Config           JSONB,
  PRIMARY KEY (CompanyId, SkillId)
);

-- Prompts (versioned)
CREATE TABLE ai.Prompts (
  PromptId         BIGSERIAL PRIMARY KEY,
  Key              TEXT NOT NULL,            -- 'prompt_donation_anomaly'
  Version          TEXT NOT NULL,
  CompanyId        BIGINT NULL REFERENCES Company,  -- NULL = platform
  Status           TEXT NOT NULL,            -- 'draft'|'approved'|'published'|'archived'
  Body             TEXT NOT NULL,
  Variables        JSONB,
  ParentPromptId   BIGINT NULL REFERENCES ai.Prompts,
  ABBucket         TEXT NULL,                -- 'A'|'B'
  Metadata         JSONB,
  CreatedDate      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ApprovedDate     TIMESTAMPTZ,
  PublishedDate    TIMESTAMPTZ,
  UNIQUE (Key, Version, CompanyId)
);

-- Chat sessions
CREATE TABLE ai.ChatSessions (
  SessionId        UUID PRIMARY KEY,
  CompanyId        BIGINT NOT NULL REFERENCES Company,
  UserId           BIGINT NOT NULL REFERENCES Users,
  Surface          TEXT NOT NULL,            -- 'grid_ask' | 'global_chat' | 'workflow'
  ContextRef       TEXT,                     -- e.g., grid name, workflow id
  StartedDate      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  LastActivity     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  Status           TEXT NOT NULL,            -- 'active'|'archived'
  SummaryDigest    TEXT
);
CREATE INDEX idx_sess_company_user ON ai.ChatSessions(CompanyId, UserId, LastActivity DESC);

-- Chat messages
CREATE TABLE ai.ChatMessages (
  MessageId        BIGSERIAL PRIMARY KEY,
  SessionId        UUID NOT NULL REFERENCES ai.ChatSessions,
  CompanyId        BIGINT NOT NULL,
  Role             TEXT NOT NULL,            -- 'user'|'assistant'|'system'|'tool'
  Content          TEXT,
  ToolCallsJson    JSONB,
  TokensIn         INT,
  TokensOut        INT,
  CostUsd          NUMERIC(10,6),
  Provider         TEXT,
  Model            TEXT,
  LatencyMs        INT,
  CreatedDate      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_msg_session ON ai.ChatMessages(SessionId, CreatedDate);

-- Semantic memory (per user/team/tenant)
CREATE TABLE ai.MemoryEntries (
  MemoryId         BIGSERIAL PRIMARY KEY,
  CompanyId        BIGINT NOT NULL,
  UserId           BIGINT NULL,              -- NULL = team/tenant scope
  Scope            TEXT NOT NULL,            -- 'user'|'team'|'tenant'
  Kind             TEXT NOT NULL,            -- 'fact'|'preference'|'skill_example'
  Body             TEXT NOT NULL,
  Source           TEXT,
  Provenance       JSONB,
  ExpiresDate      TIMESTAMPTZ,
  CreatedDate      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ModifiedDate     TIMESTAMPTZ
);
CREATE INDEX idx_mem_company_user ON ai.MemoryEntries(CompanyId, UserId, Kind);

-- Knowledge base documents (RAG corpus)
CREATE TABLE ai.KbDocuments (
  DocumentId       BIGSERIAL PRIMARY KEY,
  CompanyId        BIGINT NOT NULL,
  Title            TEXT NOT NULL,
  SourceType       TEXT NOT NULL,            -- 'pss_entity'|'upload'|'url'
  SourceRef        TEXT,                     -- e.g., 'Donor:12345'
  Content          TEXT NOT NULL,
  AccessControl    JSONB,                    -- role/capability rules
  CreatedDate      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Hooks
CREATE TABLE ai.Hooks (
  HookId           BIGSERIAL PRIMARY KEY,
  CompanyId        BIGINT NULL,              -- NULL = platform
  Event            TEXT NOT NULL,
  ConditionJson    JSONB,
  SkillCode        TEXT NOT NULL,
  ArgsTemplate     JSONB,
  Delivery         TEXT NOT NULL,            -- 'sync'|'async'
  RetryPolicy      JSONB,
  IsEnabled        BOOLEAN NOT NULL DEFAULT TRUE
);

-- Audit log (partitioned monthly)
CREATE TABLE ai.AuditLog (
  AuditId          BIGSERIAL,
  CompanyId        BIGINT NOT NULL,
  UserId           BIGINT,
  SessionId        UUID,
  SkillCode        TEXT,
  Provider         TEXT,
  Model            TEXT,
  PromptHash       TEXT,
  InputTokens      INT,
  OutputTokens     INT,
  CostUsd          NUMERIC(10,6),
  LatencyMs        INT,
  ToolCallsJson    JSONB,
  PolicyChecks     JSONB,
  Outcome          TEXT NOT NULL,
  ErrorClass       TEXT,
  CreatedDate      TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (CreatedDate);

-- Token & cost tracking (aggregated, fast queries)
CREATE TABLE ai.UsageDaily (
  CompanyId        BIGINT NOT NULL,
  UserId           BIGINT,
  Day              DATE NOT NULL,
  SkillCode        TEXT,
  Provider         TEXT,
  InputTokens      BIGINT NOT NULL DEFAULT 0,
  OutputTokens     BIGINT NOT NULL DEFAULT 0,
  CostUsd          NUMERIC(12,4) NOT NULL DEFAULT 0,
  RequestCount     INT NOT NULL DEFAULT 0,
  PRIMARY KEY (CompanyId, UserId, Day, SkillCode, Provider)
);
```

### 13.2 Indexing & partitioning

- `AuditLog` and `ChatMessages` partitioned by month for cheap retention/drop.
- `MemoryEntries` `(CompanyId, UserId, Kind)` for hot retrieval.
- `Prompts (Key, CompanyId, Status)` partial index `WHERE Status='published'` for the compiler hot path.

---

## 14. Vector Search Design

### 14.1 Choice: pgvector or Qdrant

| Concern | pgvector | Qdrant |
|---|---|---|
| Infra cost | $0 (Postgres already there) | Separate service |
| Operational simplicity | Same DB, same backups | New ops surface |
| Scale ceiling | ~10M vectors per tenant | 100M+ |
| Filtering perf | Excellent with btree + ivfflat | Excellent |
| HNSW | Yes (modern versions) | Native |

**Recommendation:** Start with **pgvector** for Phase 1. Migrate to Qdrant (or Azure AI Search) only when a tenant crosses ~5M vectors or we need cross-tenant analytics. Single interface so the swap is invisible.

### 14.2 Collection layout

One logical collection per **(CompanyId, embedding_kind)** — partitioned but co-located. Filter on `CompanyId` is mandatory in every query path; the repository refuses to issue an unfiltered query (compile-time check + runtime assert).

```
collections:
  kb_chunks         (chunks of KB docs)
  memory_facts      (semantic memory)
  skill_examples    (few-shot canonical inputs/outputs)
  prompt_corpus     (for "find similar prompt" tool)
```

### 14.3 Embedding pipeline

```
[doc/event ingested]
   → split into chunks (1k token max, 200 overlap, semantic boundaries)
   → embed (OpenAI text-embedding-3-small / Voyage / local BGE)
   → write { CompanyId, DocumentId, Chunk#, Vector, Metadata }
   → write inverse keyword index for hybrid
```

Reindex on document update; soft-delete on doc delete (vector retained 7 days for audit, then purged).

### 14.4 Retrieval recipe (default)

```
1. Pre-filter: CompanyId = @tenant AND AccessControl.matches(user)
2. Vector search: top-K = 50
3. BM25 search: top-K = 50
4. RRF fusion → top-K = 20
5. Re-rank with cross-encoder (optional, expensive)
6. Return top 5–10 with chunk text + DocumentId
```

---

## 15. API Design

### 15.1 Surfaces

GraphQL for chat (streaming via subscriptions or SSE), REST for admin/config, internal gRPC for high-frequency provider-gateway traffic.

### 15.2 GraphQL — Chat surface (sketch)

```graphql
type ChatSession {
  sessionId: ID!
  surface: ChatSurface!
  contextRef: String
  startedDate: DateTime!
  lastActivity: DateTime!
  messages(limit: Int = 50, before: ID): [ChatMessage!]!
}

type ChatMessage {
  messageId: ID!
  role: MessageRole!
  content: String
  toolCalls: [ToolCall!]
  citations: [Citation!]
  createdDate: DateTime!
}

type Mutation {
  startChatSession(input: StartChatInput!): ChatSession!
  sendChatMessage(sessionId: ID!, content: String!, attachments: [Upload!]): ChatMessage!
  cancelChatMessage(sessionId: ID!): Boolean!
  rateChatMessage(messageId: ID!, rating: Rating!, comment: String): Boolean!
  archiveChatSession(sessionId: ID!): Boolean!
  forgetMemory(memoryId: ID!): Boolean!
}

type Subscription {
  chatStream(sessionId: ID!): ChatStreamEvent!
  # emits: thinking | tool_call | tool_result | content_chunk | citation | done | error
}
```

### 15.3 REST — Admin / Config

```
GET    /api/ai/config                     → tenant config
PUT    /api/ai/config                     → update
POST   /api/ai/config/test                → run a test prompt against current routing
GET    /api/ai/skills                     → enabled skills + overrides
PUT    /api/ai/skills/:code               → enable/disable, override
GET    /api/ai/prompts/:key/versions      → version list
POST   /api/ai/prompts/:key/versions      → create new draft
POST   /api/ai/prompts/:key/publish       → publish a version
GET    /api/ai/audit                      → query audit log (filter, paginate)
GET    /api/ai/usage                      → cost & tokens
POST   /api/ai/hooks                      → register hook
GET    /api/ai/providers/health           → provider health snapshot
```

### 15.4 Internal gRPC — Provider gateway

`Generate(ChatRequest) → stream ChatChunk` — used by orchestrator service. Auth via mTLS + signed JWT carrying tenant context.

---

## 16. Configuration Management

### 16.1 Three-layer compile (recap)

`Platform → Tenant → User → Request` → compiled into an immutable `EffectiveAiConfig` cached for 60 seconds (invalidated on tenant config change).

### 16.2 Surfacing config

Admin UI: a "AI Settings" area per tenant with sections — Providers, Skills, Prompts, Hooks, Quotas, Compliance, Audit. Each setting shows:

- current value
- where it comes from (platform default | tenant override | user override)
- "Reset to default" button
- preview impact ("3 skills affected")

### 16.3 GitOps option (large clients)

For tenants who want change control, configs are exportable as YAML and importable via API. Each import is diffed and audit-logged.

### 16.4 Feature flags

Cross-cutting flags (e.g., `chat.enabled`, `streaming.enabled`, `critic.enabled`) live in the same store; flippable per-tenant.

---

## 17. Observability & Monitoring

### 17.1 What we measure

| Metric family | Examples |
|---|---|
| **Cost** | Tokens in/out by tenant/skill/provider/day; $ projected to month-end |
| **Latency** | TTFT (time-to-first-token), full-completion P50/P95/P99 by skill/provider |
| **Quality** | Thumbs up/down, downstream success (did the user accept the draft?) |
| **Reliability** | Error rate, fallback rate, circuit-breaker trips, timeouts |
| **Safety** | Policy filter hits, PII detections, guardrail blocks, refusals |
| **Behavior** | DAUs/MAUs of chat, skill invocation distribution, abandonment rate |
| **Drift** | Prompt A/B win rates, hallucination scores from critic |

### 17.2 Stack

OpenTelemetry traces (every turn = one trace, every skill/tool = a span) → Tempo / Jaeger. Metrics → Prometheus → Grafana. Logs → Loki / Seq.

### 17.3 Dashboards

- **Tenant Cost** — per-tenant burn, days-to-budget, top skills by cost.
- **Provider Health** — error rate, latency, fallback frequency per provider.
- **Skill Performance** — invocations, success, avg cost, avg latency per skill.
- **Audit Stream** — live recent calls, filterable by tenant/skill/outcome.
- **Hallucination Watch** — sample of low-fidelity responses, manual review queue.

### 17.4 Alerts

- Tenant > 90% monthly budget
- Skill error rate > 5% in 10 min
- Provider P95 > SLO for 5 min
- Audit write failures (CRITICAL — never silently swallow)
- PII detector confidence > 0.9 in outbound traffic when masking disabled

---

## 18. Scalability Strategy

### 18.1 Workload shape

- **Read-heavy** (retrieval) — caches and replicas dominate.
- **Bursty writes** (chat messages) — async-batched audit + usage rollups.
- **Long-tail latency** — LLM calls 1–30s; streaming is mandatory for UX.

### 18.2 Tactics

| Layer | Tactic |
|---|---|
| API | Stateless orchestrator pods, horizontal scale; sticky sessions only for streaming |
| Provider gateway | Connection pooling, per-provider concurrency limits, queueing on saturation |
| Postgres | Read replicas for retrieval and audit reads; write to primary |
| Qdrant/pgvector | Shard by tenant once large tenants emerge |
| Redis | Cluster mode for working memory + rate-limit + circuit-breaker state |
| Queue | RabbitMQ or Azure Service Bus, separate queues per priority class |
| Cache | Tenant config (60s), prompt registry (5m), skill manifests (5m), retrieval results (30s) |

### 18.3 Tenant noisy-neighbor protection

- Per-tenant rate limit (req/min) at gateway.
- Per-tenant concurrent LLM call cap.
- Per-tenant fair-queueing on the provider pool.
- Hard ceiling on context window per request.

---

## 19. Deployment Architecture

```
                     ┌─────────────────────────┐
   Users ──────────► │   Edge (CDN + WAF)      │
                     └────────────┬────────────┘
                                  │
                     ┌────────────▼─────────────┐
                     │   API Gateway (.NET 8)   │  ← Auth, tenant context, rate limit
                     └────┬─────────┬────────┬──┘
                          │         │        │
        ┌─────────────────▼───┐  ┌──▼──────┐ │
        │ AIDA Orchestrator   │  │ PSS Core │ │
        │  (.NET 8 + Hangfire)│  │  (GraphQL,│ │
        └─┬───────┬──────────┬┘  │   EF Core)│ │
          │       │          │   └───────────┘ │
          │       │          │                 │
          ▼       ▼          ▼                 ▼
   ┌──────────┐ ┌─────────┐ ┌──────────┐  ┌──────────┐
   │ Provider │ │ Retrieval│ │ Memory   │  │ Audit    │
   │ Gateway  │ │  Service │ │  Service │  │ Service  │
   └────┬─────┘ └────┬─────┘ └────┬─────┘  └────┬─────┘
        │            │            │              │
        ▼            ▼            ▼              ▼
   [Anthropic]  [Postgres + pgvector / Qdrant]   [Audit Log / Loki]
   [OpenAI]
   [Gemini]
   [Local LLM]

  ┌─────────────────────────────────────────────────────────┐
  │ Async workers (event hooks, summarization, embeddings)  │
  │   ← consume RabbitMQ / Service Bus                      │
  └─────────────────────────────────────────────────────────┘

  Per-region stack (india / eu / us / mea) — same shape; data never crosses.
```

- **Runtime:** .NET 8 (matches PSS); orchestrator a separate service for blast-radius isolation.
- **Queues:** RabbitMQ (or Azure Service Bus on Azure-pinned tenants).
- **State:** Postgres (primary + replicas), Redis (Sentinel/Cluster), Qdrant *or* pgvector.
- **Containerization:** Docker + Kubernetes (one namespace per region).
- **Secrets:** HashiCorp Vault or Azure Key Vault — per-tenant provider keys live there, never in DB plaintext.

---

## 20. High-Level Diagrams

### 20.1 Context diagram

```
                ┌────────────────┐
                │   PSS Users    │
                └───┬────┬───┬───┘
                    │    │   │
                Grid│ Chat│ Hook│
                 Ask│  bot│ event│
                    ▼    ▼   ▼
                 ┌────────────────┐
                 │  PSS 2.0 App   │
                 └────────┬───────┘
                          │
                 ┌────────▼───────┐
                 │     AIDA       │
                 │  Orchestrator  │
                 └─┬───┬───┬───┬──┘
                   │   │   │   │
              Skills Prompts Memory Tools
                   │   │   │   │
                 ┌─▼───▼───▼───▼─┐
                 │ Provider Gw   │
                 └──┬──┬──┬──────┘
                    ▼  ▼  ▼
                Claude OpenAI Gemini
```

### 20.2 Sequence — single chat turn

```
User → PSS UI → API GW → AIDA Orch ──► Policy Gate
                                  ──► Memory Retrieve
                                  ──► Prompt Compile
                                  ──► Provider GW ──► Claude
                                                  ◄── stream
                                  ──► Tool Loop (auth + execute)
                                  ──► Guardrail
                                  ──► Persist + Audit
                                  ──► Stream chunks back
                                                 ◄── done
User ◄ UI ◄ API GW ◄ AIDA Orch
```

### 20.3 Sequence — async hook

```
PSS Event Bus → AIDA Subscriber → enqueue
                                   │
                                   ▼
                              [Worker pool]
                              for each hook matching event:
                                resolve skill
                                run chat turn
                                tool calls (idempotent)
                                persist + audit
                                emit downstream event (optional)
```

---

## 21. Example Workflows

### 21.1 Grid Ask-AI on Donations grid

User on `/donations` grid types: *"my unreceipted donations over ₹50,000 this quarter"*.

```
1. UI calls /ai/grid/ask { grid: 'donations', q: '...' }
2. Orchestrator picks skill `grid_ask_ai`
3. Skill manifest declares input schema { fields_visible[], filters_allowed[] }
4. Prompt compiles with grid schema (only fields user can see)
5. LLM returns JSON: { filter: {...}, sort: {...} }
6. Schema-validate; reject if invalid
7. Translate to GraphQL filter & execute via existing query path
8. Return rows + the generated filter for "edit & re-run"
9. Audit: skill, tokens, cost, generated filter
```

### 21.2 Global Chatbot — "summarize this campaign"

User: *"How is Campaign Diwali Drive performing vs. last year's drive?"*

```
1. Planner agent: needs (a) campaign retrieval (b) numeric facts (c) explanation
2. Executor: tool `get_campaign(name='Diwali Drive')` → 2 candidates (this, last year)
3. Executor: tool `compare_campaigns([id1, id2])` → returns numeric deltas
4. Skill `campaign_performance_explainer` with numbers as input
5. Output: prose + a tile of numbers (numbers are tool output, not LLM output)
6. Persist; user thumbs up → quality metric improves
```

### 21.3 Hook — donation.created → acknowledge

```
event: donation.created (₹2,500 from "Mr. R")
   → match hook: ack_after_donation (amount >= 1000)
   → enqueue
   → worker:
       skill = acknowledgement_drafter
       inputs = donor profile + donation + tenant template + KB tone-guide
       → drafted email
       → tool: compliance_validator(email) → passes
       → action: queue_email_for_human_approval (delivery=hybrid)
       → Notify donor relationship manager
   → audit: full trail
```

### 21.4 Conversational workflow — DIK valuation

A two-turn workflow:

```
Turn 1 — agent asks: "What's the item? Photos? Estimated condition?"
Turn 2 — user answers; agent calls `lookup_market_value` tool, drafts an estimate,
         requests user confirmation, posts to DIK valuation form.
```

State persists in session; user can resume tomorrow.

---

## 22. Tenant Customization Examples

| Tenant archetype | Configuration |
|---|---|
| **"Claude-style answers"** | Persona prompt prepends "Be concise, balanced, plain-text" + provider order pins Claude first |
| **"ChatGPT-style structure"** | Persona prepends "Use headings, bullet lists, tables when appropriate" + GPT-4.1 primary |
| **"Perplexity-style"** | Enable `cited_search` model class; require `[#cite]` markers; surface citations in UI |
| **"AI off"** | `AiEnabled=false` — gateway short-circuits with friendly "AI is disabled for your organization" |
| **"Reports only"** | Enabled skills = [`report_generator`, `grid_ask_ai` (reports grid only)]; everything else disabled |
| **"Human in the loop"** | `require_human_approval_for: [*]` — every AI output queues for review before send/save |
| **"Strict compliance"** | `pii_mode=mask_outbound`, `allowed_providers=[local]`, `block_topics=[...]`, full audit retention |
| **"Brand voice"** | Tenant-private prompt overrides for `acknowledgement_drafter` and `case_summary` with custom tone |

Every one of the above is a **handful of config rows**, no code change.

---

## 23. Failure Handling

| Failure | Detection | Behavior |
|---|---|---|
| Primary provider 5xx | HTTP status | Retry once (jitter) → fallback per policy |
| Primary timeout | Deadline | Cancel → fallback |
| All providers down | All circuit-breakers open | Return `service_degraded`, suggest retry in N min; do not pretend to answer |
| LLM returns invalid JSON (schema break) | Schema validator | Retry once with stricter prompt; on second failure escalate model class |
| Tool call fails | Tool returns error | Re-prompt with error; max 2 retries per tool |
| Guardrail blocks | Output classifier | Return safe refusal; log policy hit |
| Budget exceeded | Pre-check | Either gate (deny) or downgrade (cheap class), per tenant policy |
| PII leak detected | Post-classifier | Auto-redact + alert + audit `policy_violation` |
| Memory write fails | DB error | Surface to user *only* if it affects correctness; always audit |
| Audit write fails | Audit pipeline | **Block the response.** No silent ops. |

---

## 24. AI Cost Optimization

| Technique | Saving |
|---|---|
| **Right-size model class per skill** | Grid Ask-AI on Haiku, not Opus → ~10× cheaper |
| **Caching identical prompts** (1h TTL) | 10–40% saving on common questions |
| **Prompt-template compression** | Trim system prompts; strip examples once skill matures |
| **Retrieval before reasoning** | Send only top-K chunks, not full docs → smaller input tokens |
| **Conversation summarization** | Cap context; older turns → 300-token summary |
| **Tool-driven numeric output** | Don't ask LLM to do arithmetic; use SQL/aggregations |
| **Cheap classifier upstream** | Tiny model decides if a heavy skill is even needed |
| **Per-tenant monthly budget cap** | Hard stop or auto-downgrade |
| **Off-peak batch jobs** | Acks, summaries, KB embeddings run cheap-tier overnight |
| **Provider negotiation** | Volume contracts; reserved capacity for production tenants |

Target unit economics: median chat turn ≤ $0.002, complex agent turn ≤ $0.02. Per-tenant monthly cost predictable within ±10%.

---

## 25. Recommended Technical Stack

| Concern | Choice | Why |
|---|---|---|
| Runtime | **.NET 8** | Matches PSS; mature, performant |
| Orchestrator framework | **Custom + Semantic Kernel** (or LangChain.NET) | Take just the abstractions we need; don't depend on the full framework |
| Provider SDKs | Native (Anthropic.SDK, OpenAI .NET, Google.Cloud.AIPlatform) | First-party reliability |
| Embeddings | OpenAI `text-embedding-3-small` or local BGE-M3 | Cheap + multilingual |
| Vector DB | **pgvector** (Phase 1), Qdrant (Phase 3+) | Operational simplicity first |
| Relational | **PostgreSQL 16** | Already standardized in PSS |
| Cache / working memory | **Redis 7** (Cluster) | Standard |
| Queue / events | **RabbitMQ** (or Azure Service Bus) | Match deployment cloud |
| Search (BM25) | Postgres FTS (Phase 1), Elastic/Opensearch (Phase 3) | Avoid extra infra |
| Workflow engine | **Hangfire** (BG jobs) + state machines | Already in PSS toolbox |
| Observability | OTel + Prometheus + Grafana + Loki + Tempo | Open standards |
| Secrets | Azure Key Vault / HashiCorp Vault | Per-tenant key isolation |
| API | GraphQL (chat) + REST (admin) + gRPC (internal) | Match PSS conventions |
| Streaming | SSE (browser) + WebSocket (deep clients) | Wide compatibility |
| PII detection | Microsoft Presidio | Open-source, extensible |
| Frontend SDK | Next.js + custom React chat components | Match PSS frontend |

---

## 26. Roadmap (Phase 0 → Phase 4)

### Phase 0 — Foundation (Weeks 1–4)

- Provider gateway with Anthropic + OpenAI adapters, model-class abstraction.
- Tenant config tables, admin endpoints, three-layer compile.
- Audit log skeleton.
- Per-tenant key vault integration.
- **Deliverable:** an internal "/ai/echo" skill returning a model-generated response, gated by tenant config. *Proof the substrate works.*

### Phase 1 — Grid Ask-AI (Weeks 5–10)

- Skills registry (DB-backed); first skill `grid_ask_ai`.
- Schema-validated JSON outputs; translation to GraphQL filter.
- Quotas + cost tracking.
- Admin UI: enable/disable skills, set provider preference, view audit.
- **Deliverable:** Donations / Contacts / Campaigns grids ship "Ask AI" search. Live for 2 pilot tenants.

### Phase 2 — Global Chatbot + Memory (Weeks 11–20)

- Chat sessions, message history, working memory.
- pgvector retrieval over Donors, Donations, Campaigns, Reports.
- 10 skills (summarization, donor summary, campaign explainer, anomaly detection, etc).
- Tool registry with read-only tools.
- Critic agent (LLM-as-judge) optional, behind feature flag.
- **Deliverable:** Side-panel chat in PSS, GA for early-adopter tenants.

### Phase 3 — Agents, Hooks & Workflows (Weeks 21–32)

- Planner + Executor + Validator agents.
- Event bus + async hooks; first 5 hooks (ack drafter, anomaly, pledge-followup, …).
- Write-capable tools (with human approval gating).
- Prompt versioning + A/B testing.
- Conversational workflows (DIK valuation, duplicate resolve).
- **Deliverable:** Ambient AI across PSS; 30%+ tenants opt in to hooks.

### Phase 4 — Platformization (Weeks 33–52)

- Tenant-private skills + custom prompts UI.
- Self-serve admin: persona builder, prompt editor with eval set.
- Fine-tuned tenant models (opt-in, isolated infra).
- Multi-modal (vision for receipts, OCR for KYC).
- Marketplace for community skills (curated).
- Local-LLM deployments for regulated tenants.

---

## 27. Risks & Mitigation

| Risk | Severity | Mitigation |
|---|---|---|
| Cross-tenant data leak via retrieval | **Critical** | `CompanyId` filter mandatory at repo; compile-time check; integration test asserts |
| Provider outage cascades | High | Multi-provider routing, circuit breakers, async hooks isolated from chat |
| Hallucinated numbers in reports | High | Numbers come from tools, not LLMs; critic agent for high-stakes outputs |
| Prompt injection via user input | High | System/user separation; tool-call schema validation; deny-list on tools |
| Cost overrun for power-user tenant | Medium | Per-tenant budgets, real-time alerts, auto-downgrade |
| Latency UX (chat feels slow) | Medium | Mandatory streaming; TTFT SLO < 1.5s; spinner with phase ("thinking", "searching", "writing") |
| Regulatory pushback (data residency) | Medium | Region-pinned deployments, allow-list providers per region |
| Vendor lock-in to one LLM | Medium | Model-class abstraction; gateway adapter pattern |
| Skill bloat (too many to manage) | Low | Curation; versioning; usage telemetry deprecates dead skills |
| Audit log overflow | Low | Monthly partitions, automated archive to cold storage |
| LLM provider trains on our prompts | High (compliance) | Use enterprise endpoints with no-train clauses (Anthropic, OpenAI Enterprise); document in DPA |
| Forge-style malicious tenant skill | Medium | Tenant-private skills sandboxed; cannot exceed tenant's own permissions |

---

## 28. Best Practices

### Engineering
1. **Audit before action** — write the audit row *before* calling the provider, complete it after.
2. **Idempotency keys** on every hook execution.
3. **Schemas everywhere** — every skill input/output has a JSON Schema. No raw blobs.
4. **No raw SQL from LLMs** in writes — LLM-emitted SQL is read-only; mutations go through declared tools.
5. **Two-eye for write tools** — any tool that changes data is behind a human approval gate in Phase 1–2.
6. **Versioning is non-negotiable** — prompts, skills, tools, schemas all versioned.
7. **Streaming or it's broken** — non-streaming chat = bad UX.

### Product
1. **Show the work** — UI shows "searching donors…", "drafting reply…", retrieved sources, cited IDs.
2. **Editable AI output** — users edit drafts before send; their edits become quality signal.
3. **One-click "forget that"** — undoability builds trust.
4. **No silent mode-switches** — if we degrade from Claude to OpenAI mid-conversation, tell the user.
5. **Per-tenant onboarding playbook** — capture client expectations into config; don't ad-hoc.

### Security
1. **Tenant key isolation** — per-tenant provider keys in Key Vault, rotated quarterly.
2. **Output moderation always on** — even when input was internal.
3. **PII in audit** — store *hashes*, not values, for sensitive fields.
4. **Red-team prompt injection** — quarterly exercise; failures become test cases.

---

## 29. Future AI Expansion Strategy

### Year 1 — make it solid
Grid Ask-AI, Global Chat, Hooks, 10–20 skills, 2 providers.

### Year 2 — make it ambient
Conversational workflows, write-capable tools with approval, agent orchestration, prompt marketplace internal.

### Year 3 — make it intelligent
Per-tenant continuous learning (RLHF from approve/edit signals), fine-tuned tenant models, multimodal (receipts, signatures), voice (donor calls → summaries), proactive insights ("you should know that…").

### Year 4 — open the platform
Skill marketplace for partners/clients to publish capabilities; revenue share. Customer-built agents via low-code studio. Federated knowledge across cooperative tenants (with opt-in).

### Standing principles regardless of phase
- **Configuration over code.**
- **Tenant isolation over convenience.**
- **Audit over speed.**
- **Provider neutrality over single-vendor optimizations.**
- **Humans in the loop until trust is earned per skill, per tenant, per use case.**

---

## Appendix A — Glossary

- **AIDA**: AI Decision Assistant — the platform name proposed.
- **Skill**: A reusable AI capability (one task; declarative manifest).
- **Agent**: A worker that loops, planning and executing multiple skills/tools.
- **Tool**: An app-side function the LLM may request; authorization is the app's job.
- **Hook**: A declarative event→skill binding.
- **Prompt**: A versioned template with variables; the unit of behavior tuning.
- **Provider gateway**: One internal API fronting all LLM providers.
- **Model class**: Abstract tier (`reasoning_top`, `reasoning_mid`, `reasoning_fast`, `embedding`, `vision`).
- **Working / Episodic / Semantic memory**: Conversation-scoped / per-user-historic / fact-based memory tiers.
- **Critic**: An LLM-as-judge that scores faithfulness of a response to retrieved sources.
- **Compliance profile**: Per-tenant policy bundle (PII mode, residency, block-lists, retention).

---

## Appendix B — Open Questions for Stakeholders

1. **Provider posture** — start with Claude-only and add fallbacks in Phase 2, or build the multi-provider gateway day-one?
2. **Vector store** — accept pgvector for Phase 1, or invest in Qdrant up front?
3. **Self-hosted LLM** — is there a tenant in the pipeline who'll require it? (Decides infra scope.)
4. **Write-capable AI** — Phase 1 strict read-only, or allow write with mandatory approval gate?
5. **Critic agent** — pay the cost premium for high-stakes outputs from day one, or defer?
6. **Persona presets** — ship 4–5 canned personas ("Claude-style", "GPT-style", "Perplexity-style", "Custom"), or fully open prompt editor?
7. **Per-tenant model fine-tuning** — interested customers? Compliance constraints? (Sets Phase 4 ambition.)
8. **Skill marketplace** — internal-only forever, or open to partners?

---

*— End of document —*

*Authors: AI Platform Team. Reviewers: CTO, Head of Engineering, Head of Compliance, Customer Success Lead. Next step: stakeholder review meeting to resolve Appendix B questions, then Phase 0 kickoff.*
