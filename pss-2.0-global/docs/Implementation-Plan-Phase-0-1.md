# PSS 2.0 AIDA — Phase 0 & Phase 1 Implementation Plan

> **Companion to** `docs/AI-Platform-Architecture.md`.
> **Covers** the first 10 weeks of build: Foundation (Phase 0) → Grid Ask-AI (Phase 1).
> **Audience** Engineering leads, BE/FE devs, DevOps, QA.
> **Status** Ready-to-execute. Pending only the open items in §10.

---

## 1. Locked Decisions

These were open in the architecture doc's Appendix B. I'm pinning them now so we can move; revisit at Phase 1 GA.

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | **Provider posture** | **Multi-provider gateway day-1**, with Claude primary + OpenAI fallback | The whole "configuration over code" thesis depends on it. Retrofitting later means rewriting the gateway. Adds ~1 sprint week vs single-provider; insures against Claude outages and gives us GPT-style/Perplexity-style tenants for free in Phase 2. |
| 2 | **Vector store** | **pgvector** (no Qdrant in Phase 0–1) | Phase 1 (Grid Ask-AI) doesn't need vectors at all. Phase 2 adds retrieval — pgvector is already in Postgres, zero new infra. Migrate to Qdrant only if/when a tenant exceeds ~5M vectors. |
| 3 | **Write-capable tools** | **Read-only in Phase 1** | Grid Ask-AI emits *filter expressions* — no mutations possible by design. Write tools introduced in Phase 2 with mandatory HITL queue. |
| 4 | **Service boundary** | **Module inside Base** — folders under `PeopleServe/Services/Base/Base.{Domain,Application,Infrastructure,API}` mirroring how Donation/Contact/Auth modules live there | PSS publishes a single app service. One DbContext (`ApplicationDbContext`), one migration history, one deploy. Aida shares the existing tenant filter (`CompanyId` global query filter) for free. *(Earlier draft proposed a separate microservice — corrected after team review.)* |
| 5 | **Schema name** | All tables under `ai.*` Postgres schema, same DB | Logical isolation for backup/restore + clean visual grouping in DB tools. |
| 6 | **Persona presets in Phase 1?** | **No** — defer to Phase 2 | Phase 1 has one persona ("PSS default"). Custom personas (Claude-style / GPT-style / Perplexity-style) ship with Global Chat where they actually matter. |
| 7 | **Critic agent** | **No in Phase 1** | Grid Ask-AI uses schema validation as its quality gate. No prose to score. Critic comes online in Phase 2 alongside chat. |
| 8 | **Local LLM** | **No in Phase 1** | No regulated tenant in flight. Phase 4 concern. |

---

## 2. Scope Map — what ships when

```
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 0  ·  FOUNDATION  ·  Weeks 1–4                            │
│  ─────────────────────────────────────────                       │
│  • Provider Gateway (Claude + OpenAI adapters, model-class map) │
│  • Tenant Config (3-layer compile, per-tenant API keys)         │
│  • Audit + Usage tracking                                        │
│  • Internal /ai/echo proof endpoint                              │
│  → Deliverable: a callable AI gateway with per-tenant routing,  │
│    audit, and cost tracking. NO end-user UI yet.                │
└─────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1  ·  GRID ASK-AI  ·  Weeks 5–10                          │
│  ─────────────────────────────────────────                       │
│  • Skills Registry + Prompt Registry                             │
│  • grid_ask_ai skill (NL → GraphQL filter)                       │
│  • Schema validation + safe expression translator                │
│  • ChatSessions (Design B — auto-archived per query)             │
│  • Admin UI: enable/disable skills, view audit, set provider    │
│  • Pilot on Donations + Contacts grids, 2 tenants                │
│  → Deliverable: Live "Ask AI" on two grids for 2 pilot tenants. │
└─────────────────────────────────────────────────────────────────┘
```

**Phase 0 explicitly does NOT include:** any UI, retrieval/RAG, memory, chat history surface, hooks, vector store, fine-tuning. Those are Phase 2+.

---

## 3. Phase 0 — Foundation (Weeks 1–4)

### 3.1 Goals

By end of Week 4, an authorized internal client can call:

```
POST /ai/internal/echo
Authorization: Bearer <jwt-with-CompanyId>
{ "prompt": "Say hello", "model_class": "reasoning_fast" }
```

…and get back a response from the **tenant's configured provider** with a row in `ai.audit_log` and `ai.usage_daily`. If the primary provider is down, the request transparently falls back to the secondary. Per-tenant monthly budget gates work.

### 3.2 Non-goals

- No user-facing UI.
- No skills, prompts, sessions, chat — those are Phase 1.
- No retrieval, memory, vector store.
- No GraphQL surface (REST + gRPC only for now).

### 3.3 Sprint 1 (W1–W2) — Gateway & Models

**Stories**

| Story | Owner | Acceptance |
|---|---|---|
| Bootstrap `Aida` microservice (new .NET 8 project under `PeopleServe/Services/Aida`) with the 4 sub-projects | BE Lead | Solution builds; runs locally; health endpoint returns 200 |
| Define `IModelClient` interface + DTOs (`ChatRequest`, `ChatResponse`, `ChatChunk`) | BE | Unit-tested with stub adapter |
| Implement `AnthropicAdapter` (Claude Sonnet 4.6, Haiku 4.5, Opus 4.7) | BE | Integration test against real API succeeds; streams chunks |
| Implement `OpenAIAdapter` (GPT-4.1, GPT-4.1-mini) | BE | Same as above |
| Implement `ModelClassResolver` (class → provider+model) reading from `ai.model_class_map` | BE | Unit-tested: `reasoning_mid` → claude-sonnet-4-6 by default |
| Tables: `ai.providers`, `ai.model_class_map` | BE | EF migration applied; seed data committed |
| OTel traces wired for every adapter call | DevOps | Trace visible in Tempo with provider+model attributes |

**Definition of Done**

- Two adapters callable from a unit test runner.
- Health endpoint `/ai/health` returns provider availability for both.
- One Grafana panel: "Provider latency P50/P95" by adapter.

### 3.4 Sprint 2 (W3–W4) — Tenancy, Audit, Routing

**Stories**

| Story | Owner | Acceptance |
|---|---|---|
| Tables: `ai.tenant_config`, `ai.tenant_provider_preference`, `ai.tenant_provider_key`, `ai.audit_log`, `ai.usage_daily` | BE | EF migrations applied; all FKs to `Companies.CompanyId` |
| Encrypted provider-key storage (pgcrypto + Key Vault wrap) | BE + DevOps | A key written via API can be read back symmetrically; raw bytes not readable from DB |
| `TenantConfigService` with 60s cache invalidated on config change | BE | Read benchmark: < 5ms cached, < 30ms cold |
| `RoutingPolicyEngine` — picks provider+model from (class, tenant prefs, health, budget) | BE | Unit tests cover: tenant override, primary-down fallback, budget-exhausted downgrade, region pinning |
| Circuit breaker per (provider, region) — opens after 5 errors in 60s, half-opens after 120s | BE | Failure-injection test verifies behavior |
| `IAuditWriter` — **audit row written before LLM call**, completed after | BE | If LLM call panics/throws, audit row still exists with `outcome='error'` |
| Usage rollup job: daily aggregate `ai.audit_log` → `ai.usage_daily` | BE | Hangfire job runs nightly; idempotent |
| `POST /ai/internal/echo` (gRPC + REST) | BE | End-to-end: request → tenant resolve → routing → adapter → audit → response |
| Tenant budget gate (`MonthlyBudgetUsd`) — pre-call hard stop OR auto-downgrade | BE | Unit test: tenant at 110% budget → request 402-style refusal; tenant at 91% → auto-downgrade to `reasoning_fast` |
| Authn middleware: JWT extraction + `CompanyId` claim → request context | BE | Requests without claim are 401; mismatch claim vs body is 403 |

**Definition of Done — Phase 0**

- An end-to-end request hits the gateway, routes by tenant config, falls back on simulated outage, and writes both audit + usage rows.
- Adding a new tenant = inserting rows into `ai.tenant_config` + Key Vault entry. No code change.
- Pre-decision check: a tenant with `AiEnabled=false` gets an instant 423-style refusal with `outcome='disabled'` audit row.
- All migrations reversible.

---

## 4. Phase 1 — Grid Ask-AI (Weeks 5–10)

### 4.1 Goals

End-user on `/donations` grid types *"unreceipted donations over ₹50K this quarter"*, gets the grid filtered correctly in ≤ 2 seconds, with the generated filter expression shown above the grid (editable, removable per-pill, save-as-filter). Same on `/contacts`. Two pilot tenants live.

### 4.2 Sprint 3 (W5–W6) — Skills & Prompt Registry

**Stories**

| Story | Owner | Acceptance |
|---|---|---|
| Tables: `ai.skills`, `ai.tenant_skills`, `ai.prompts` | BE | EF migrations + seed for `grid_ask_ai` skill (platform, v1.0.0) |
| `SkillRegistryService` — resolve skill for `(tenant, code)` with overrides | BE | Unit test: platform skill returned when no tenant override; tenant override wins when present |
| `PromptCompilerService` — 4-layer compile (base ← tenant ← workflow ← runtime) | BE | Unit test: variables substituted; tenant override applied; runtime ctx interpolated |
| Prompt versioning: status `draft → approved → published → archived` | BE | State machine enforced; cannot publish without approval |
| Initial prompts seeded for `grid_ask_ai` (one per supported grid: donations, contacts) | BE + Prompt Eng | Prompts stored in DB; loaded via registry, not hardcoded |
| `ai.skills` `Manifest JSONB` schema documented + validated on insert | BE | JSON Schema validation in app layer; bad manifest → 400 |
| Admin REST: `GET/PUT /ai/admin/skills`, `GET /ai/admin/prompts/:key/versions` | BE | Authorized to `BUSINESSADMIN` only |

**Definition of Done — Sprint 3**

- Calling the gateway with `skill_code='grid_ask_ai'` resolves and compiles a prompt; no hardcoded prompt text in source.
- An admin can disable the skill per tenant via REST; subsequent calls return `outcome='disabled'`.

### 4.3 Sprint 4 (W7–W8) — Grid Ask-AI Skill End-to-End

**Stories**

| Story | Owner | Acceptance |
|---|---|---|
| `GridSchemaService` — exposes per-grid field metadata (fields visible, types, allowed operators, value sources) | BE | Pulls from existing PSS grid configuration; tenant-scoped + role-filtered |
| `grid_ask_ai` skill prompt: instructs LLM to emit JSON matching `GridFilterExpression` schema | Prompt Eng | Test set of 30 questions → ≥ 90% schema-valid outputs |
| `GridFilterValidator` — strict JSON Schema validation of LLM output | BE | Malformed/unknown-field outputs rejected; retry once with stricter prompt |
| `GridFilterTranslator` — `GridFilterExpression` → GraphQL filter object the existing query path accepts | BE | All operators (`eq`, `ne`, `gt`, `lt`, `gte`, `lte`, `between`, `in`, `like`, `is_null`) translate correctly |
| `ChatSessions` Design B: every grid query → new `Session(Surface='grid_ask', Status='auto_archived')` + 2 messages (user, assistant) | BE | DB rows verified for each query |
| `POST /ai/grid/ask { grid, question }` REST endpoint (also gRPC for service-to-service) | BE | E2E test: question → 200 with `{ filter, sessionId, model, latency_ms, tokens, confidence }` |
| Streaming variant: SSE on `/ai/grid/ask/stream` (sends `thinking`/`filter_chunk`/`done` events) | BE | UI can render progress |
| Cost: every grid_ask_ai call uses `reasoning_fast` (Haiku/4.1-mini) — verified in routing config | BE | Audit rows show only fast-class models |
| Permission check: skill manifest declares `capability_required: <entity>.read` — middleware enforces | BE | Test: user without `donation.read` calling for `donations` grid → 403 |

**Definition of Done — Sprint 4**

- End-to-end: REST call with 30 sample questions → schema-valid filters → executed via existing grid query path → matching rows.
- All audit rows populated; usage rolls up nightly.
- Avg latency ≤ 1.5s for `reasoning_fast`.

### 4.4 Sprint 5 (W9–W10) — Admin UI + Pilot

**Stories**

| Story | Owner | Acceptance |
|---|---|---|
| Frontend: `<AskAiBar>` React component (matches `grid-ask-ai.html` mockup exactly) | FE | Bootstrapped via existing PSS form/grid component library; respects tenant tokens |
| Wire `<AskAiBar>` into Donations and Contacts grids (feature-flag controlled) | FE | Visible only to tenants with `AiEnabled=true` AND `grid_ask_ai` enabled |
| Result banner: filter pills, expandable "View query", "Save as filter", "Re-run", "Edit" | FE | Pills are individually removable and re-run on remove |
| Frontend: Admin "AI Settings" page — provider preference, skills enable/disable, monthly budget, audit search | FE | Mirror of REST admin endpoints; `BUSINESSADMIN` only |
| Backend: `Save filter from AI result` — persists to existing `SavedFilter` table with `Source='AI'` flag | BE | Stored filters surface alongside user-created ones; flagged in UI |
| Telemetry: `ai_grid_ask_invocations`, `ai_grid_ask_latency_seconds`, `ai_grid_ask_validation_failures`, `ai_grid_ask_user_thumbs` | DevOps | Grafana dashboard live |
| Per-tenant audit search UI (filter by skill/outcome/date) | FE | Backed by `GET /ai/admin/audit` |
| Red-team prompt-injection test suite (50 adversarial inputs) | QA + BE | None of 50 inputs produces a filter the user couldn't have written themselves |
| Pilot enablement: Acme Charity + Sterling Foundation | Customer Success | Both tenants live on Donations + Contacts grids |
| Runbook: "AIDA Provider Outage" + "Tenant exceeded budget" + "Filter validation failing" | DevOps | Reviewed by oncall |

**Definition of Done — Phase 1**

- Two pilot tenants using `Ask AI` daily on two grids each.
- ≥ 90% schema-valid output rate on a fixed 100-question eval set.
- P95 latency ≤ 2.0s end-to-end.
- Zero cross-tenant data leaks in integration tests (CompanyId filter is mandatory at repo).
- ≥ 70% user thumbs-up rate (target; observe and tune).
- Median cost per Ask-AI ≤ $0.001.

---

## 5. Database Design — Phase 0 & 1 Tables

> **Implementation note.** PSS uses EF Core code-first migrations under `Base.Infrastructure/Migrations/`. The actual artifacts are C# entity classes + `IEntityTypeConfiguration<T>` + auto-generated migrations. The DDL below is the **logical contract** for review — translate one-to-one into the entity model. All tables live in the `ai` schema. Every row carries `CreatedDate`, `CreatedBy`, `ModifiedDate`, `ModifiedBy`, `IsActive`, `IsDeleted` per PSS convention.

### 5.1 Phase 0 tables

```sql
-- ─────────────────────── ai.providers ───────────────────────
CREATE TABLE ai.providers (
  provider_id            BIGSERIAL PRIMARY KEY,
  code                   VARCHAR(50) NOT NULL UNIQUE,    -- 'anthropic'|'openai'|'gemini'|'local'
  display_name           VARCHAR(100) NOT NULL,
  base_url               VARCHAR(500) NOT NULL,
  capabilities           JSONB NOT NULL,                  -- { chat:true, embed:false, vision:false }
  auth_mode              VARCHAR(50) NOT NULL DEFAULT 'api_key',
  health_endpoint        VARCHAR(500),
  is_enabled_platform    BOOLEAN NOT NULL DEFAULT TRUE,
  notes                  TEXT,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by             BIGINT NOT NULL,
  modified_date          TIMESTAMPTZ,
  modified_by            BIGINT,
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  is_deleted             BOOLEAN NOT NULL DEFAULT FALSE
);

-- ─────────────────────── ai.model_class_map ───────────────────────
-- Maps abstract classes ('reasoning_top', 'reasoning_mid', 'reasoning_fast', 'embedding', 'vision')
-- to concrete (provider, model). Priority determines fallback order in routing.
CREATE TABLE ai.model_class_map (
  map_id                 BIGSERIAL PRIMARY KEY,
  class_code             VARCHAR(50) NOT NULL,
  provider_id            BIGINT NOT NULL REFERENCES ai.providers(provider_id),
  model_id               VARCHAR(100) NOT NULL,
  priority               INT NOT NULL,                    -- 1=primary, 2=fallback-1, ...
  cost_in_per_mtok       NUMERIC(10,4),
  cost_out_per_mtok      NUMERIC(10,4),
  context_window         INT,
  max_output_tokens      INT,
  supports_streaming     BOOLEAN NOT NULL DEFAULT TRUE,
  supports_tools         BOOLEAN NOT NULL DEFAULT TRUE,
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  modified_date          TIMESTAMPTZ,
  UNIQUE (class_code, provider_id, model_id)
);
CREATE INDEX ix_mcm_class_priority ON ai.model_class_map(class_code, priority) WHERE is_active = TRUE;

-- ─────────────────────── ai.tenant_config ───────────────────────
-- 1:1 with Companies. Default row inserted on Company creation (trigger or app-side).
CREATE TABLE ai.tenant_config (
  company_id             BIGINT PRIMARY KEY REFERENCES companies(company_id),
  ai_enabled             BOOLEAN NOT NULL DEFAULT TRUE,
  region                 VARCHAR(20) NOT NULL DEFAULT 'india',   -- 'india'|'eu'|'us'|'mea'
  persona_code           VARCHAR(50),                            -- NULL = platform default
  monthly_budget_usd     NUMERIC(12,2),                          -- NULL = no cap
  budget_alert_pct       INT NOT NULL DEFAULT 75,
  budget_block_pct       INT NOT NULL DEFAULT 100,               -- > pct → hard stop
  pii_mode               VARCHAR(20) NOT NULL DEFAULT 'mask_outbound',
  chat_retention_days    INT NOT NULL DEFAULT 60,                -- Phase 2
  memory_retention_days  INT NOT NULL DEFAULT 365,               -- Phase 2
  allowed_providers      TEXT[],                                 -- NULL = all platform providers
  metadata               JSONB,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by             BIGINT NOT NULL,
  modified_date          TIMESTAMPTZ,
  modified_by            BIGINT
);

-- ─────────────────────── ai.tenant_provider_preference ───────────────────────
-- Per-tenant overrides on the model_class_map. Most tenants will not have rows here
-- (they take platform defaults). Power tenants pin their preferred order.
CREATE TABLE ai.tenant_provider_preference (
  preference_id          BIGSERIAL PRIMARY KEY,
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  class_code             VARCHAR(50) NOT NULL,
  provider_id            BIGINT NOT NULL REFERENCES ai.providers(provider_id),
  model_id               VARCHAR(100) NOT NULL,
  priority               INT NOT NULL,
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by             BIGINT NOT NULL,
  UNIQUE (company_id, class_code, provider_id, model_id)
);
CREATE INDEX ix_tpp_company_class ON ai.tenant_provider_preference(company_id, class_code, priority);

-- ─────────────────────── ai.tenant_provider_key ───────────────────────
-- Per-tenant API keys. KeyCipher is wrapped by KMS data key; key_version tracks rotation.
CREATE TABLE ai.tenant_provider_key (
  key_id                 BIGSERIAL PRIMARY KEY,
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  provider_id            BIGINT NOT NULL REFERENCES ai.providers(provider_id),
  key_cipher             BYTEA NOT NULL,
  key_version            INT NOT NULL,
  rotated_date           TIMESTAMPTZ,
  expires_date           TIMESTAMPTZ,
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by             BIGINT NOT NULL,
  UNIQUE (company_id, provider_id, key_version)
);
CREATE INDEX ix_tpk_company_active ON ai.tenant_provider_key(company_id, provider_id) WHERE is_active = TRUE;

-- ─────────────────────── ai.audit_log (PARTITIONED) ───────────────────────
-- One row per LLM call. Audit row written BEFORE the call (status='pending'),
-- updated AFTER with outcome + tokens + cost.
CREATE TABLE ai.audit_log (
  audit_id               BIGSERIAL,
  company_id             BIGINT NOT NULL,
  user_id                BIGINT,
  session_id             UUID,                      -- nullable in Phase 0; required in Phase 1
  skill_code             VARCHAR(100),              -- nullable in Phase 0
  surface                VARCHAR(20),               -- 'grid_ask'|'global_chat'|'workflow'|'hook'|'internal'
  provider_code          VARCHAR(50),
  model_id               VARCHAR(100),
  prompt_hash            VARCHAR(64),               -- SHA-256 of compiled prompt
  input_tokens           INT,
  output_tokens          INT,
  cost_usd               NUMERIC(10,6),
  latency_ms             INT,
  tool_calls_json        JSONB,
  policy_checks_json     JSONB,                     -- { pii_detected, guardrail_flags, etc }
  outcome                VARCHAR(20) NOT NULL,      -- 'pending'|'success'|'fallback'|'filtered'|'error'|'disabled'
  error_class            VARCHAR(100),
  fallback_from          VARCHAR(50),               -- provider that failed before this attempt
  trace_id               VARCHAR(64),               -- OTel trace ID
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_date         TIMESTAMPTZ,
  PRIMARY KEY (audit_id, created_date)
) PARTITION BY RANGE (created_date);

CREATE INDEX ix_audit_company_date ON ai.audit_log(company_id, created_date DESC);
CREATE INDEX ix_audit_session ON ai.audit_log(session_id) WHERE session_id IS NOT NULL;
CREATE INDEX ix_audit_outcome ON ai.audit_log(outcome, created_date DESC);

-- Initial partitions (auto-create job thereafter)
CREATE TABLE ai.audit_log_2026_05 PARTITION OF ai.audit_log
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE ai.audit_log_2026_06 PARTITION OF ai.audit_log
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

-- ─────────────────────── ai.usage_daily ───────────────────────
-- Pre-aggregated cost / token usage for fast quota checks + dashboards.
-- Refreshed nightly from ai.audit_log; also incrementally updated by adapter on success.
CREATE TABLE ai.usage_daily (
  company_id             BIGINT NOT NULL,
  user_id                BIGINT NOT NULL DEFAULT 0,   -- 0 = tenant-total roll-up row
  usage_date             DATE NOT NULL,
  skill_code             VARCHAR(100) NOT NULL DEFAULT '*',
  provider_code          VARCHAR(50) NOT NULL DEFAULT '*',
  input_tokens           BIGINT NOT NULL DEFAULT 0,
  output_tokens          BIGINT NOT NULL DEFAULT 0,
  cost_usd               NUMERIC(12,4) NOT NULL DEFAULT 0,
  request_count          INT NOT NULL DEFAULT 0,
  error_count            INT NOT NULL DEFAULT 0,
  fallback_count         INT NOT NULL DEFAULT 0,
  modified_date          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (company_id, user_id, usage_date, skill_code, provider_code)
);
CREATE INDEX ix_usage_company_month ON ai.usage_daily(company_id, usage_date DESC);
```

### 5.2 Phase 1 tables (added on top of Phase 0)

```sql
-- ─────────────────────── ai.skills ───────────────────────
CREATE TABLE ai.skills (
  skill_id               BIGSERIAL PRIMARY KEY,
  code                   VARCHAR(100) NOT NULL,
  version                VARCHAR(20) NOT NULL,                  -- semver
  visibility             VARCHAR(20) NOT NULL,                  -- 'platform'|'tenant_private'|'shared'
  owner_company_id       BIGINT REFERENCES companies(company_id), -- NULL = platform
  display_name           VARCHAR(150) NOT NULL,
  description            TEXT NOT NULL,
  manifest               JSONB NOT NULL,                        -- full SkillManifest (see §6.2 of arch doc)
  status                 VARCHAR(20) NOT NULL DEFAULT 'draft',  -- 'draft'|'approved'|'published'|'archived'
  default_model_class    VARCHAR(50) NOT NULL,
  capability_required    VARCHAR(100),                          -- PSS capability for permission check
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by             BIGINT NOT NULL,
  approved_date          TIMESTAMPTZ,
  approved_by            BIGINT,
  published_date         TIMESTAMPTZ,
  modified_date          TIMESTAMPTZ,
  modified_by            BIGINT,
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (code, version, owner_company_id)
);
CREATE INDEX ix_skills_lookup ON ai.skills(code, owner_company_id, status) WHERE status = 'published';

-- ─────────────────────── ai.tenant_skills ───────────────────────
CREATE TABLE ai.tenant_skills (
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  skill_code             VARCHAR(100) NOT NULL,
  is_enabled             BOOLEAN NOT NULL DEFAULT TRUE,
  pinned_version         VARCHAR(20),                  -- NULL = always use latest published
  model_class_override   VARCHAR(50),
  prompt_override_key    VARCHAR(100),
  config_json            JSONB,                        -- skill-specific tenant config
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  modified_date          TIMESTAMPTZ,
  PRIMARY KEY (company_id, skill_code)
);

-- ─────────────────────── ai.prompts ───────────────────────
CREATE TABLE ai.prompts (
  prompt_id              BIGSERIAL PRIMARY KEY,
  prompt_key             VARCHAR(150) NOT NULL,        -- e.g., 'grid_ask_ai.donations'
  version                VARCHAR(20) NOT NULL,
  company_id             BIGINT REFERENCES companies(company_id),  -- NULL = platform
  status                 VARCHAR(20) NOT NULL DEFAULT 'draft',
  body                   TEXT NOT NULL,
  variables              JSONB,                         -- declared placeholders + types
  parent_prompt_id       BIGINT REFERENCES ai.prompts(prompt_id),
  ab_bucket              VARCHAR(1),                    -- NULL | 'A' | 'B'
  ab_traffic_pct         INT,                           -- 0–100 for B if A/B active
  notes                  TEXT,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by             BIGINT NOT NULL,
  approved_date          TIMESTAMPTZ,
  approved_by            BIGINT,
  published_date         TIMESTAMPTZ,
  modified_date          TIMESTAMPTZ,
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (prompt_key, version, company_id)
);
CREATE INDEX ix_prompts_resolve ON ai.prompts(prompt_key, company_id, status) WHERE status = 'published';

-- ─────────────────────── ai.chat_sessions ───────────────────────
CREATE TABLE ai.chat_sessions (
  session_id             UUID PRIMARY KEY,
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  user_id                BIGINT NOT NULL,
  surface                VARCHAR(20) NOT NULL,         -- 'grid_ask'|'global_chat'|'workflow'|'hook'
  context_ref            VARCHAR(200),                 -- e.g., 'grid:donations', 'workflow:dik-valuation'
  skill_code             VARCHAR(100),                 -- primary skill driving this session
  title                  VARCHAR(300),                 -- auto-generated; user-editable later
  event_id               UUID,                         -- nullable; set if hook-spawned
  status                 VARCHAR(20) NOT NULL DEFAULT 'active',  -- 'active'|'archived'|'auto_archived'
  message_count          INT NOT NULL DEFAULT 0,
  total_cost_usd         NUMERIC(10,6) NOT NULL DEFAULT 0,
  total_tokens_in        INT NOT NULL DEFAULT 0,
  total_tokens_out       INT NOT NULL DEFAULT 0,
  started_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_activity_date     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  archived_date          TIMESTAMPTZ,
  is_pinned              BOOLEAN NOT NULL DEFAULT FALSE,
  created_by             BIGINT NOT NULL,
  modified_date          TIMESTAMPTZ
);
CREATE INDEX ix_sess_company_user_active ON ai.chat_sessions(company_id, user_id, last_activity_date DESC)
  WHERE status = 'active';
CREATE INDEX ix_sess_surface ON ai.chat_sessions(company_id, surface, last_activity_date DESC);

-- ─────────────────────── ai.chat_messages ───────────────────────
CREATE TABLE ai.chat_messages (
  message_id             BIGSERIAL PRIMARY KEY,
  session_id             UUID NOT NULL REFERENCES ai.chat_sessions(session_id) ON DELETE CASCADE,
  company_id             BIGINT NOT NULL,              -- denormalized for fast tenant queries
  role                   VARCHAR(20) NOT NULL,         -- 'user'|'assistant'|'system'|'tool'
  content                TEXT,                         -- nullable when tool_calls_json carries the payload
  tool_calls_json        JSONB,
  attachments_json       JSONB,
  citations_json         JSONB,                        -- structured refs to KB chunks / entities
  parent_message_id      BIGINT REFERENCES ai.chat_messages(message_id),
  tokens_in              INT,
  tokens_out             INT,
  cost_usd               NUMERIC(10,6),
  provider_code          VARCHAR(50),
  model_id               VARCHAR(100),
  latency_ms             INT,
  audit_id               BIGINT,                       -- link to ai.audit_log (logical FK; cross-partition)
  user_rating            VARCHAR(10),                  -- 'up'|'down'|NULL
  user_rating_comment    TEXT,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ix_msg_session ON ai.chat_messages(session_id, created_date);
CREATE INDEX ix_msg_company_date ON ai.chat_messages(company_id, created_date DESC);
```

### 5.3 Seed data — Phase 0 + Phase 1

```sql
-- Providers
INSERT INTO ai.providers (code, display_name, base_url, capabilities, auth_mode, created_by) VALUES
  ('anthropic', 'Anthropic',    'https://api.anthropic.com',          '{"chat":true,"embed":false,"vision":true,"tools":true}', 'api_key', 1),
  ('openai',    'OpenAI',       'https://api.openai.com',             '{"chat":true,"embed":true,"vision":true,"tools":true}',  'api_key', 1),
  ('gemini',    'Google Gemini','https://generativelanguage.googleapis.com', '{"chat":true,"embed":true,"vision":true,"tools":true}',  'api_key', 1);

-- Model class map (priority 1 = primary, 2+ = fallback)
INSERT INTO ai.model_class_map (class_code, provider_id, model_id, priority, cost_in_per_mtok, cost_out_per_mtok, context_window, max_output_tokens) VALUES
  -- reasoning_top
  ('reasoning_top',  (SELECT provider_id FROM ai.providers WHERE code='anthropic'), 'claude-opus-4-7',     1, 15.0, 75.0, 200000, 8000),
  ('reasoning_top',  (SELECT provider_id FROM ai.providers WHERE code='openai'),    'gpt-4.1',             2,  3.0, 12.0, 128000, 8000),
  -- reasoning_mid
  ('reasoning_mid',  (SELECT provider_id FROM ai.providers WHERE code='anthropic'), 'claude-sonnet-4-6',   1,  3.0, 15.0, 200000, 8000),
  ('reasoning_mid',  (SELECT provider_id FROM ai.providers WHERE code='openai'),    'gpt-4.1',             2,  3.0, 12.0, 128000, 8000),
  ('reasoning_mid',  (SELECT provider_id FROM ai.providers WHERE code='gemini'),    'gemini-2.5-pro',      3,  3.5, 10.5, 200000, 8000),
  -- reasoning_fast  (default for Phase 1's grid_ask_ai)
  ('reasoning_fast', (SELECT provider_id FROM ai.providers WHERE code='anthropic'), 'claude-haiku-4-5',    1,  0.8,  4.0, 200000, 4000),
  ('reasoning_fast', (SELECT provider_id FROM ai.providers WHERE code='openai'),    'gpt-4.1-mini',        2,  0.4,  1.6, 128000, 4000);

-- grid_ask_ai skill
INSERT INTO ai.skills (code, version, visibility, owner_company_id, display_name, description, manifest, status, default_model_class, capability_required, created_by, approved_date, approved_by, published_date)
VALUES (
  'grid_ask_ai',
  '1.0.0',
  'platform',
  NULL,
  'Grid Ask AI',
  'Translates a natural-language question into a structured filter expression scoped to a single grid. Stateless, read-only, single-turn.',
  '{
    "input_schema_key": "schema_grid_ask_in",
    "output_schema_key": "schema_grid_ask_out",
    "tools_allowed": [],
    "provider_policy": { "preferred_model_class": "reasoning_fast", "max_tokens": 800, "temperature": 0.1 },
    "permissions": { "capability_required": "grid.read" },
    "cost_class": "cheap",
    "chainable": false,
    "hooks_compatible": []
  }',
  'published',
  'reasoning_fast',
  'grid.read',
  1, NOW(), 1, NOW()
);

-- Initial prompts (one per supported grid)
INSERT INTO ai.prompts (prompt_key, version, company_id, status, body, variables, created_by, approved_date, approved_by, published_date) VALUES
('grid_ask_ai.donations', '1.0.0', NULL, 'published',
'<<<system_prompt_for_donations_grid_ask_ai>>>',  -- full prompt body managed separately
'{"grid_schema":"object","user_question":"string","tenant_locale":"string","tenant_today":"date"}',
1, NOW(), 1, NOW()),

('grid_ask_ai.contacts', '1.0.0', NULL, 'published',
'<<<system_prompt_for_contacts_grid_ask_ai>>>',
'{"grid_schema":"object","user_question":"string","tenant_locale":"string","tenant_today":"date"}',
1, NOW(), 1, NOW());
```

### 5.4 Indexes / partitioning summary

| Table | Reason | Index / Partition |
|---|---|---|
| `audit_log` | High write volume; retention 7 yrs for some tenants | Monthly partitions; `(company_id, created_date DESC)` |
| `chat_messages` | Hot read by `session_id`, time-ordered | Monthly partitions in Phase 2 (not needed Phase 1); B-tree on `session_id, created_date` |
| `chat_sessions` | History list scan by user | Partial index `WHERE status='active'` |
| `prompts` | Hot path: resolve published prompt | Partial index `WHERE status='published'` |
| `tenant_provider_key` | Per-call key lookup | Partial index `WHERE is_active=TRUE` |
| `usage_daily` | Budget gate read on every call | Composite PK already covers it; consider materialized view for tenant-month totals |

---

## 6. Backend Project Layout

Aida lives **inside the existing Base service**, mirroring how Donation / Contact / Auth / Notify modules are organized. One `ApplicationDbContext` (extended via partial classes), one migration history, one publish.

```
PSS_2.0_Backend/PeopleServe/Services/Base/
│
├── Base.Domain/Models/AidaModels/                 [NEW MODULE FOLDER]
│   ├── Provider.cs
│   ├── ModelClassMap.cs
│   ├── TenantConfig.cs
│   ├── TenantProviderPreference.cs
│   ├── TenantProviderKey.cs
│   ├── AuditLog.cs                                # distinct from ReportAuditModels.AuditLog
│   ├── UsageDaily.cs
│   ├── Skill.cs
│   ├── TenantSkill.cs
│   ├── Prompt.cs
│   ├── ChatSession.cs
│   ├── ChatMessage.cs
│   ├── AidaEnums.cs                               # ModelClass / Surface / SessionStatus / etc.
│   ├── ChatRequest.cs                             # provider-agnostic value object
│   ├── ChatResponse.cs                            # + ChatChunk
│   └── GridFilterExpression.cs                    # grid_ask_ai output contract
│
├── Base.Application/
│   ├── Data/Persistence/IAidaDbContext.cs         [NEW] 12 DbSet<>
│   ├── Services/Aida/                             [NEW MODULE FOLDER]
│   │   ├── IModelClient.cs                        # + IModelClientFactory + ProviderHealthSnapshot
│   │   ├── IRoutingPolicyEngine.cs                # + IProviderCircuitBreaker + RoutingDecision
│   │   ├── ITenantConfigService.cs                # + EffectiveAiConfig
│   │   ├── ITenantKeyProvider.cs
│   │   ├── IAuditWriter.cs                        # + AuditPendingInput / AuditCompletionInput
│   │   ├── IUsageTracker.cs                       # + UsageRecord + BudgetStatus
│   │   └── ISkillRegistryService.cs               # + IPromptCompilerService + CompiledPrompt
│   └── Business/AidaBusiness/                     [NEW MODULE FOLDER]
│       └── GridAsk/
│           ├── Commands/AskGrid/
│           │   ├── AskGridCommand.cs              # MediatR IRequest + AskGridResponseDto
│           │   └── AskGridCommandHandler.cs       # orchestrator (skeleton — Sprint 4)
│           └── GridFilterValidator.cs             # JSON-schema gate (skeleton — Sprint 4)
│
├── Base.Infrastructure/
│   ├── Data/Persistence/AidaDbContext.cs          [NEW] partial ApplicationDbContext : IAidaDbContext
│   ├── Data/Configurations/AidaConfigurations/    [NEW] 12 IEntityTypeConfiguration<T>
│   ├── Services/Aida/                             [NEW MODULE FOLDER]
│   │   ├── ModelClientFactory.cs
│   │   ├── Anthropic/AnthropicAdapter.cs          # skeleton — Sprint 1
│   │   ├── OpenAI/OpenAIAdapter.cs                # skeleton — Sprint 1
│   │   ├── KeyVault/AzureKeyVaultTenantKeyProvider.cs   # implemented
│   │   ├── Routing/RoutingPolicyEngine.cs         # skeleton — Sprint 2 (+ ProviderCircuitBreaker)
│   │   ├── Audit/AuditWriter.cs                   # WritePendingAsync implemented; Complete is Sprint 2
│   │   └── AidaDependencyInjection.cs             # AddAidaServices(configuration)
│   ├── DependencyInjection.cs                     [PATCHED] + services.AddAidaServices(configuration)
│   └── Base.Infrastructure.csproj                 [PATCHED] + Azure.Identity, Azure.Security.KeyVault.Secrets
│
└── Base.API/
    └── EndPoints/Aida/                            [NEW MODULE FOLDER]
        ├── Mutations/GridAskMutations.cs          # mutation: aidaAskGrid → AskGridResponseDto
        └── Queries/AidaHealthQueries.cs           # query: aidaProviderHealth → ProviderHealthSnapshot[]
```

### What this layout buys us

- **Zero deploy changes** — Aida ships in the existing Base.API publish.
- **Free tenant isolation** — `ApplicationDbContext.ApplyTenantFilters` reflects over `CompanyId` properties; Aida entities inherit the global query filter automatically.
- **Single migration history** — `dotnet ef migrations add Add_Aida_Schema` from `Base.Infrastructure` (startup project `Base.API`) creates schema `ai` + all 12 tables in the existing PSS Postgres.
- **Existing auth pipeline reused** — `ITenantContext`, JWT middleware, role-based authorization all work out of the box.
- **Same dev cycle** — same `Base.sln`, same `dotnet run`, same `https://localhost:5xxx/graphql` endpoint with `aidaAskGrid` mutation appearing alongside `createDonationCategory` etc.

See [`Base/AIDA-MODULE-README.md`](../PSS_2.0_Backend/PeopleServe/Services/Base/AIDA-MODULE-README.md) for the per-file file index and Sprint-1 Day-0 setup steps.

---

## 7. Frontend Project Layout

Additions under `PSS_2.0_Frontend/src/`:

```
src/
├── components/
│   └── ai/
│       ├── AskAiBar/
│       │   ├── AskAiBar.tsx                 # the purple bar in the grid mockup
│       │   ├── AskAiResultBanner.tsx        # filter pills + actions
│       │   ├── FilterPill.tsx
│       │   ├── ViewQueryPanel.tsx           # collapsible "View query" block
│       │   └── SuggestionChips.tsx
│       ├── ConfidenceBadge.tsx
│       └── shared/
│           ├── tokens.ts                    # AI accent constants (purple)
│           └── icons.ts
│
├── features/
│   └── ai/
│       ├── grid-ask/
│       │   ├── api.ts                       # REST client for /ai/grid/ask
│       │   ├── useAskAi.ts                  # React hook
│       │   ├── types.ts                     # GridFilterExpression, AskAiResponse
│       │   └── translator.ts                # client-side: filter pill add/remove
│       └── admin/
│           ├── AiSettingsPage.tsx
│           ├── SkillsTab.tsx
│           ├── ProvidersTab.tsx
│           ├── BudgetTab.tsx
│           └── AuditTab.tsx
│
├── app/[lang]/admin/ai/                     # admin route (BUSINESSADMIN only)
│   ├── page.tsx
│   ├── skills/page.tsx
│   ├── providers/page.tsx
│   ├── budget/page.tsx
│   └── audit/page.tsx
│
└── lib/
    └── ai/
        ├── featureFlags.ts                  # ai.enabled, grid_ask_ai.enabled
        └── telemetry.ts                     # client-side: invocation, rating events
```

Integration into existing grids (Donations / Contacts):

```tsx
// In existing DonationsGrid.tsx / ContactsGrid.tsx
import { AskAiBar } from '@/components/ai/AskAiBar';
import { useAiFlag } from '@/lib/ai/featureFlags';

const DonationsGrid = () => {
  const aiEnabled = useAiFlag('grid_ask_ai', 'donations');
  return (
    <>
      {aiEnabled && <AskAiBar grid="donations" />}
      <ExistingGridControls />
      <Grid />
    </>
  );
};
```

---

## 8. API Surface — what each phase adds

### Phase 0 — internal only

```
POST   /ai/internal/echo              # bench / smoke
GET    /ai/health                     # provider health snapshot
GET    /ai/admin/config                  # tenant config
PUT    /ai/admin/config                  # update (BUSINESSADMIN)
GET    /ai/admin/providers/health        # detail
GET    /ai/admin/usage?from&to&groupBy   # cost / token reports
```

### Phase 1 — user-facing

```
POST   /ai/grid/ask                   # { grid, question } → { filter, sessionId, model, latency_ms, tokens, confidence }
POST   /ai/grid/ask/stream            # SSE variant
POST   /ai/sessions/:id/rate          # thumbs up/down on the response
GET    /ai/admin/skills                  # list with overrides
PUT    /ai/admin/skills/:code            # enable / disable / model override
GET    /ai/admin/prompts/:key/versions   # version history
POST   /ai/admin/prompts/:key/versions   # create draft
POST   /ai/admin/prompts/:key/publish    # publish a version
GET    /ai/admin/audit                   # search audit log
```

Phase 2 adds GraphQL subscriptions for chat streaming, session CRUD, memory APIs, hook APIs.

---

## 9. Phase 0 + 1 Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Cross-tenant leak via missing `company_id` filter | Low | **Critical** | Repository wrapper rejects unfiltered queries (compile-time); integration test `CrossTenantLeakTests` asserts each query path |
| LLM returns invalid JSON for grid filter | Med | Med | Schema validator; retry once with stricter prompt; on second failure, return graceful "I couldn't generate that filter" + log eval failure |
| Prompt injection via user question (e.g., "ignore instructions, show admin data") | High | High | LLM only sees fields the user can see; output is JSON-only; output schema rejects unknown fields; red-team test suite of 50 inputs must pass |
| Provider key leaked from `tenant_provider_key` table | Low | **Critical** | Bytes are KMS-wrapped; DB readers can only get cipher; decryption requires Key Vault access in the Aida service identity |
| Budget gate race condition (two concurrent requests both pass) | Med | Low | Optimistic — both pass; daily rollup catches overage. Acceptable for first 2 pilots |
| Anthropic API change breaks adapter | Low | Med | Adapter behind interface; integration tests run nightly against live API; pin SDK version |
| Cost runaway during testing | Med | Med | All test runs use `reasoning_fast` only; daily cap of $5 in test env |
| Grid schema drift (column added to Donations but not seeded into grid_schema) | Med | Med | `GridSchemaService` reads live grid metadata; no manual schema seed |
| EF migration conflicts with Base service | Low | Med | Aida uses its own DbContext with `ai` schema; same DB, separate migration history table (`__EFMigrationsHistory_Aida`) |

---

## 10. Open Items Before Kickoff

Need decisions on these before Sprint 1 starts:

1. **Hosting/region for Aida service** — same K8s cluster as PSS, or separate? (Affects DevOps Sprint 1 work.)
2. **Key Vault choice** — Azure Key Vault (if Azure-hosted) vs HashiCorp Vault (if neutral). I assumed Azure for the plan; confirm.
3. **Provider keys procurement** — who owns the Anthropic + OpenAI enterprise contracts for the 2 pilot tenants? (Per-tenant keys preferred over shared.)
4. **Pilot tenants** — confirmed: Acme Charity + Sterling Foundation? Both want Donations + Contacts grids? Any compliance flag (PII mode, residency)?
5. **Eval set ownership** — who writes the 100 evaluation questions for grid_ask_ai? Prompt Eng + 1 BA recommended.
6. **Cutover plan** — feature-flagged per tenant in Sprint 5, or all pilots simultaneously? I recommend per-tenant flag + soak 1 week each.
7. **Cost ownership during pilot** — platform pays, or pilots? Affects budget gate defaults.

---

## 11. Definition of Ready — Sprint 1 can start when

- [ ] All 7 open items above are answered
- [ ] Aida service has a Postgres user with `CREATE SCHEMA` on the shared DB
- [ ] Anthropic + OpenAI enterprise API keys provisioned for dev environment
- [ ] Key Vault namespace created with Aida service identity granted read-decrypt
- [ ] OTel collector reachable from Aida service
- [ ] Two BE engineers + one DevOps + one FE engineer allocated for the 10 weeks
- [ ] Prompt Engineer (or stand-in) identified for Sprint 3–5

---

## 12. After Phase 1 — what's next

| Phase | Weeks | Headline | When to start planning |
|---|---|---|---|
| **Phase 2** | W11–W20 | Global Chat + Memory + 10 skills + tool registry (read-only) + pgvector retrieval | When Phase 1 hits soak week (W10) |
| **Phase 3** | W21–W32 | Agents (Planner/Executor/Validator) + Async Hooks + Write tools with HITL + Conversational workflows | When Phase 2 is at GA candidate |
| **Phase 4** | W33–W52 | Tenant-private skills UI + persona builder + fine-tuned tenant models + multimodal + local LLM | Strategy review at end of Phase 3 |

---

*— End of plan —*

*Authors: AI Platform Team. Reviewers: Eng Lead, BE Lead, FE Lead, DevOps, QA, Customer Success. Next step: resolve the 7 open items, then Sprint 1 kickoff.*
