# PSS 2.0 AIDA — Phase 2 Implementation Plan

## Global Chat + Memory + Retrieval (Weeks 11–20)

> **Companion to** `AI-Platform-Architecture.md` and `Implementation-Plan-Phase-0-1.md`.
> **Plans** the 10 weeks following Phase 1 GA.
> **Replan trigger:** end of Phase 1 soak week (W10) — adjust this doc with Phase 1 learnings before Sprint 6 starts.
> **Status:** Ready for review now; refresh required at W10.

---

## 1. Locked Decisions (for now — confirm at W10)

These build on the Phase 0–1 locks. Items marked ⚠️ are higher-uncertainty and to be re-confirmed at end of Phase 1.

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | **Vector store** | **pgvector** in Phase 2 | Already in Postgres; no new infra. Migrate to Qdrant only if a tenant exceeds ~5M chunks. |
| 2 | **Embedding model** | OpenAI `text-embedding-3-small` (1536 dims) for English; `text-embedding-3-large` opt-in for Tamil/Hindi tenants | Cheap, multilingual-ok; embedding cost is the smallest LLM cost. |
| 3 | **Retrieval strategy** | Hybrid: BM25 (Postgres FTS) + vector (pgvector) + RRF fusion | RRF beats either alone for mixed-intent queries. |
| 4 | **Streaming** | SSE (Server-Sent Events) — not WebSocket | Cheaper, works through HTTP infra, one-way is fine (server → client). WebSocket reserved for Phase 3 multi-agent. |
| 5 | **Working memory backing** | Redis Cluster (shared with PSS Core's Redis) | Already in stack; partitioned by `companyId:sessionId` key namespace. |
| 6 | **Persona presets** | Ship 4: PSS default, Claude-style, GPT-style, Perplexity-style | Covers 80% of "I want it to feel like X" requests. Custom persona builder is Phase 4. |
| 7 | **Tools in Phase 2** | **Read-only tools only.** Write tools defer to Phase 3 | Allows real value (donor summaries, comparisons, anomaly flags) without HITL infra. |
| 8 | **Critic agent** | Behind a feature flag, OFF by default | Costs 2× per response. Enable per-tenant for high-stakes use cases. |
| 9 | ⚠️ **Chat retention default** | 60 days | Confirm with Compliance at W10; some tenants may require 7 years. |
| 10 | ⚠️ **KB ingestion sources** | Phase 2.A: PSS entities (Donors, Donations, Campaigns, Reports). Phase 2.B: tenant-uploaded PDFs/docs | Phase 2.B may slip to Phase 3 if PDF processing complexity is high. |

---

## 2. Scope Map — what ships in Phase 2

```
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2  ·  GLOBAL CHAT + MEMORY  ·  Weeks 11–20                │
│  ─────────────────────────────────────────                       │
│  Sprint 6  (W11–12)  Memory + KB foundation                      │
│  Sprint 7  (W13–14)  Retrieval + first 5 skills                  │
│  Sprint 8  (W15–16)  Chat surface end-to-end + streaming         │
│  Sprint 9  (W17–18)  Persona + tool registry + 5 more skills     │
│  Sprint 10 (W19–20)  Polish + Critic + Pilot rollout             │
│                                                                  │
│  → Deliverable: Global Chat live for 2 pilot tenants. 10 skills.│
│    Refresh-safe sessions. Hybrid retrieval. 4 personas.         │
└─────────────────────────────────────────────────────────────────┘
```

**Phase 2 explicitly does NOT include:** write-capable tools, agents (planner/executor/validator), hooks, conversational workflows, multimodal, fine-tuning. All Phase 3+.

---

## 3. Phase 2 Sprint Plan

### 3.1 Sprint 6 (W11–W12) — Memory & KB Foundation

**Goal:** pgvector extension live; KB documents from PSS entities ingested; embedding pipeline working; memory tables persisting.

| Story | Owner | Acceptance |
|---|---|---|
| Enable `pgvector` extension on Postgres; verify HNSW index works | DevOps + BE | `CREATE EXTENSION vector` succeeds; test query returns; index < 100ms on 100k rows |
| Tables: `ai.memory_entries`, `ai.kb_documents`, `ai.kb_chunks` (with `embedding vector(1536)`) | BE Lead | EF migrations applied; FKs to `companies`; partial indexes verified |
| `EmbeddingService` with OpenAI text-embedding-3-small adapter | BE | Unit-tested; rate-limited; cached; cost tracked per embedding call |
| `KbIngestionService` for PSS entity → KbDocument → chunks pipeline | BE | E2E test: insert Donor → KbDocument row created → 3 KbChunks with embeddings |
| Initial ingestion pipeline (Hangfire jobs) for Donors / Donations / Campaigns / Reports | BE | Each entity type has a `KbIngestor<T>` implementation; backfill job idempotent |
| Chunk strategy: 1000-token max, 200-token overlap, semantic boundaries (paragraph + heading) | BE | Unit-tested on sample docs; chunks respect entity field boundaries |
| Document update / delete cascade: on PSS entity update, re-embed; on delete, soft-delete chunks (retain 7 days for audit) | BE | Update test: edit Donor → KbChunks updated within 60s; delete test: row marked deleted, hard-purged on Day 7 |
| `MemoryEntriesService` CRUD with scope=user/team/tenant | BE | Unit-tested; cross-tenant access fails |
| `Forget memory` API (cascade delete by memory_id, requires user ownership) | BE | API test: user A cannot delete user B's memory; audit log shows the delete |
| Embedding cost surfacing in `ai.usage_daily` (provider='openai', skill_code='embedding') | BE | Aggregates correctly; visible in admin UI |

**Sprint 6 DoD:**
- 1 PSS tenant's Donor + Campaign data fully indexed in `ai.kb_chunks` with embeddings.
- A REST call `/ai/internal/retrieve?company_id=X&q=...` returns top-K chunks via raw vector search (no permission filter yet).
- Embedding job runs nightly; failures alert.

### 3.2 Sprint 7 (W13–W14) — Hybrid Retrieval + First 5 Skills

**Goal:** Hybrid retrieval works with permission filtering; first 5 skills implemented and tested.

| Story | Owner | Acceptance |
|---|---|---|
| `HybridRetrievalService` — BM25 (Postgres `tsvector`) + vector + RRF | BE | Returns top-K with retrieval scores; ablation tested vs vector-only |
| Permission filter pushed into retrieval (user must have `entity.read` capability for the entity backing the chunk) | BE | Critical test: user without `donor.read` runs query "show me donor X" → no donor rows returned |
| `RetrievalContext` shape: `{ chunk_id, doc_id, source_type, score, snippet, citation_meta }` | BE | Schema documented; all skills consume same shape |
| Skill: `donor_summary` — full profile + giving history + suggested next-best action | BE + Prompt Eng | E2E test: returns coherent summary with 3+ citations; 90% factual accuracy on 20-sample eval |
| Skill: `campaign_performance_explainer` — compare campaigns, surface lag drivers | Prompt Eng | E2E test: matches chatbot mockup §1 output style |
| Skill: `summarization` — generic "summarize this entity" with cited bullets | BE | E2E test: 200-word output, 5+ citations, no hallucinated stats |
| Skill: `anomaly_flag` — read-only; given a donation, return risk score + reasons | BE | E2E test: flags 4-of-5 seeded suspicious donations; <10% false positive on clean set |
| Skill: `fx_explanation` — explains why a donation in foreign currency was booked at X rate | BE | E2E test: cites `fx_rates` table; never invents a rate (always tool-sourced) |
| All 5 skills declare `tools_allowed` (read-only PSS API calls); skill manifest validates | BE | Skills cannot call un-declared tools (runtime enforced) |
| `ToolCallExecutor` — runs declared tool, applies user's PSS permissions, returns result | BE | Tool call test: user attempts tool against entity they can't see → 403; result not exposed to LLM |
| `tools_registry` table + `tool_call_log` table | BE | DDL applied; tool calls logged with input/output hashes |

**Sprint 7 DoD:**
- 5 skills callable via `/ai/internal/skill/{code}` REST.
- Each skill writes audit + tool call log rows.
- Retrieval respects per-user capability (test: BUSINESSADMIN vs StaffReadOnly see different chunks).

### 3.3 Sprint 8 (W15–W16) — Chat Surface End-to-End

**Goal:** Real chat thread persists, streams, survives refresh. Frontend wired to backend SSE.

| Story | Owner | Acceptance |
|---|---|---|
| `ChatOrchestrator` — turn lifecycle (load → retrieve → compile → call → stream → persist → audit) | BE | Integration test: 4-turn conversation, every turn writes 2 messages + 1 audit row |
| SSE endpoint `/ai/chat/sessions/:id/messages/stream` — events: `thinking`, `tool_call`, `tool_result`, `content_chunk`, `citation`, `done`, `error` | BE | Browser SSE client receives all event types; reconnect handled |
| Working memory in Redis: key `aida:wm:{companyId}:{sessionId}` → compiled context | BE | Cache miss triggers rebuild from `chat_messages`; rebuild < 200ms for 50-msg session |
| Refresh-safety: `SessionId` in URL `?session={guid}` + `localStorage`; on page load, fetch last 50 messages | BE + FE | Refresh test: refresh mid-conversation → full thread restored, no message loss |
| Streaming partial-message handling: mid-stream messages stored as `status='streaming'`; refresh during stream drops the in-flight message | BE | Refresh during stream test: in-flight message not in DB, completed messages all present |
| Session CRUD: create, list (paginated), get with messages, archive, delete, pin/unpin, rename | BE | All endpoints; `BUSINESSADMIN` only for cross-user listing |
| Frontend: `<ChatPanel>` component matching `global-chatbot.html` mockup | FE | Renders messages with role-based bubbles, trace block, KPI tiles, citations, follow-ups, msg actions |
| Frontend: composer with 4 mode tabs (Ask/Draft/Analyze/Automate — only Ask functional in Phase 2; others UI-only) | FE | Composer with attach, slash, mention, mic buttons; send on Enter; cancel mid-stream |
| Frontend: integration into PSS app shell — floating button bottom-right opens panel; deep-link `/aida/chat/{sessionId}` | FE | Cross-page navigation preserves session; back button works |
| Conversation summarization (Sprint 6 prereq): when turn count > 20 OR tokens > 70% of context, summarize turns 1..N-10 into 400-token summary | BE | Test: 25-turn convo correctly summarized; original turns retained in DB for audit, hidden from context |
| User rating on messages (thumbs up/down + optional comment) | FE + BE | Stored on `chat_messages.user_rating`; flows to quality metrics |
| Telemetry: `ai_chat_turn_latency`, `ai_chat_ttft` (time-to-first-token), `ai_chat_tokens_per_session` | DevOps | Grafana dashboard live |

**Sprint 8 DoD:**
- End-to-end chat works on dev: open panel → send message → see thinking → see streaming response → tool call visible → response with citations → rate it.
- Refresh test passes on dev.
- TTFT ≤ 1.5s, full response ≤ 8s P95.

### 3.4 Sprint 9 (W17–W18) — Persona + Tool Registry + 5 More Skills

**Goal:** Persona presets selectable per tenant; 10 total skills available; user preferences persist.

| Story | Owner | Acceptance |
|---|---|---|
| `Persona` entity + 4 seed personas: `pss_default`, `claude_style`, `gpt_style`, `perplexity_style` | Prompt Eng | Each persona = system-prompt prefix + style guide; previewable in admin UI |
| `TenantConfig.persona_code` → injected into every chat skill at compile time | BE | Test: switching persona changes response style (eval by Critic OR human review on 10 sample queries) |
| Skill: `meeting_notes_to_actions` — paste notes → tasks + assignees + dates | Prompt Eng | E2E: 5 sample meeting notes → 5 sets of 3+ actionable tasks; assignees match attendees |
| Skill: `pledge_followup_planner` — given a pledge, suggest reminder cadence | Prompt Eng | E2E: pledges of varying sizes get appropriate cadence (small=1 reminder, large=3 with escalation) |
| Skill: `duplicate_donor_resolver` — find merge candidates, explain confidence | Prompt Eng | E2E: surfaces known seeded duplicates with confidence > 0.8 |
| Skill: `compliance_validator` (read-only Phase 2) — check donation against policy (FCRA, foreign-funds) | BE + Prompt Eng | E2E: flags simulated FCRA-required donations; no false positives on clean set |
| Skill: `dik_valuation_assistant` (read-only Phase 2) — help estimate FMV for in-kind donations | Prompt Eng | E2E: lookup_market_value tool integration; suggests valuation range with citations |
| `tools_registry` populated with read-only tools: `get_donor`, `list_donors`, `get_campaign`, `compare_campaigns`, `list_donations`, `get_pledge`, `lookup_market_value`, `lookup_fx_rate`, `get_kpi` | BE | All tools authenticated via existing PSS Authorization filters; tested for cross-tenant leak |
| `ai.user_preferences` table + API | BE | User can pin skills, set default persona, set preferred locale; cross-user isolation enforced |
| `forget_fact(id)` API + UI in side-panel sources | FE + BE | One-click removal of a memory entry; audit logged |
| Admin UI: persona selector with live preview | FE | Switch persona → preview pane re-renders with sample response |
| Skill chaining (preview-only in Phase 2): `donor_summary` → `acknowledgement_drafter` (chain definition validated; not executed end-to-end) | BE | Chain manifest tested; full execution gated to Phase 3 |

**Sprint 9 DoD:**
- 10 skills total in registry; all platform-visibility.
- 4 personas live; tenants can switch via admin UI.
- 5 sample chats per persona shown internally — verified style differences.

### 3.5 Sprint 10 (W19–W20) — Polish, Critic, Pilot Rollout

**Goal:** Quality gates pass. Critic optional. 2 pilot tenants live.

| Story | Owner | Acceptance |
|---|---|---|
| `CriticAgent` (LLM-as-judge) — re-reads response + retrieved sources, scores faithfulness 0-1 | BE | Feature-flagged per tenant; runs on samples 5% of traffic when ON; high-stakes skills (anomaly_flag, compliance_validator) get 100% |
| Critic threshold action: < 0.7 → mark as `low_confidence`, show banner in UI ("AI confidence low — please verify"); < 0.5 → regenerate once | BE + FE | Test: synthetic hallucinated response triggers regeneration; banner shown |
| Eval set extension: 200 chat questions across the 10 skills; CI-blocking ≥ 85% schema-valid + ≥ 70% Critic-passing | QA + Prompt Eng | Eval suite runs nightly + on PRs touching prompts; results visible in `ai.eval_results` |
| Prompt-injection red team: 100 adversarial inputs (vs Phase 1's 50) | QA | None produces unauthorized tool call or cross-tenant data; all rejected gracefully |
| Per-session cost budget: hard cap at $0.50/session (auto-end session, suggest "Start new chat for follow-up") | BE | Test: 100 expensive turns trigger cap; user sees friendly message |
| Performance: TTFT P95 ≤ 1.5s, full response P95 ≤ 8s | BE | Grafana shows; load test with 50 concurrent sessions passes |
| Chat History page (matches `chat-history.html` mockup) — sessions rail + viewer + details panel | FE | Surfaces all session types; filters work; resume goes back to chat page |
| In-app onboarding: first-use tooltip ("Try asking AIDA…") with 5 suggested prompts | FE | Shown once per user; dismissable; A/B test impression vs click-through |
| Pilot enablement: same 2 tenants from Phase 1 + 1 new tenant if available | CS | Feature flag flipped per tenant; soak 1 week each |
| Runbooks: "Critic flapping low-confidence", "Embedding job stuck", "Chat latency P95 alert", "User reports cross-tenant leak" | DevOps | All 4 reviewed by oncall |
| Help center articles: "What can AIDA do?", "How to phrase questions", "Privacy & memory", "Personas explained" | Product + CS | 4 published |
| Per-tenant memory dashboard (admin): see all memory entries, all sessions, total cost, top skills | FE | Backed by `/ai/admin/memory` + `/ai/admin/sessions` |

**Sprint 10 / Phase 2 DoD:**
- ≥ 3 pilot tenants using chat daily (target: ≥ 5 chat sessions/user/week among active users)
- Eval pass rate ≥ 85% schema-valid + ≥ 70% Critic-passing on 200-question set
- TTFT P95 ≤ 1.5s; full response P95 ≤ 8s
- Median cost per chat turn ≤ $0.02
- Zero cross-tenant leaks (CrossTenantLeakTests passing on retrieval, memory, sessions, tools)
- ≥ 60% user thumbs-up rate
- Refresh-safety test passes on prod
- All 10 skills + 4 personas live in admin UI

---

## 4. Database Design — Phase 2 Additions

> Same DDL → EF code-first entity translation as Phase 0–1. `ai` schema.

```sql
-- ─────────────────────── ai.memory_entries ───────────────────────
-- Semantic memory: facts, preferences, learned examples. Scoped to user/team/tenant.
CREATE TABLE ai.memory_entries (
  memory_id              BIGSERIAL PRIMARY KEY,
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  user_id                BIGINT,                      -- NULL = team/tenant scope
  team_id                BIGINT,                      -- NULL = tenant scope
  scope                  VARCHAR(20) NOT NULL,        -- 'user'|'team'|'tenant'
  kind                   VARCHAR(50) NOT NULL,        -- 'fact'|'preference'|'skill_example'|'correction'
  body                   TEXT NOT NULL,
  embedding              vector(1536),                -- pgvector
  source                 VARCHAR(100),                -- 'user_explicit'|'skill_emit'|'workflow_persist'
  provenance             JSONB,                       -- { session_id, message_id, skill_code }
  expires_date           TIMESTAMPTZ,
  is_pinned              BOOLEAN NOT NULL DEFAULT FALSE,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by             BIGINT NOT NULL,
  modified_date          TIMESTAMPTZ,
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  is_deleted             BOOLEAN NOT NULL DEFAULT FALSE,
  CHECK ((scope='user' AND user_id IS NOT NULL) OR
         (scope='team' AND team_id IS NOT NULL) OR
         (scope='tenant'))
);
CREATE INDEX ix_mem_company_user_kind ON ai.memory_entries(company_id, user_id, kind)
  WHERE is_active = TRUE AND is_deleted = FALSE;
CREATE INDEX ix_mem_embedding ON ai.memory_entries
  USING hnsw (embedding vector_cosine_ops) WHERE embedding IS NOT NULL;

-- ─────────────────────── ai.kb_documents ───────────────────────
-- Top-level KB document. One row per PSS entity / uploaded doc.
CREATE TABLE ai.kb_documents (
  document_id            BIGSERIAL PRIMARY KEY,
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  source_type            VARCHAR(50) NOT NULL,        -- 'pss_entity'|'upload'|'url'
  source_ref             VARCHAR(200) NOT NULL,       -- e.g., 'Donor:12345'
  title                  VARCHAR(500) NOT NULL,
  content_hash           VARCHAR(64) NOT NULL,        -- to detect changes
  access_control         JSONB NOT NULL,              -- { entity_type, capability, owner_check }
  language               VARCHAR(10),                 -- 'en','ta','hi'
  total_chunks           INT NOT NULL DEFAULT 0,
  metadata               JSONB,
  ingested_date          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  modified_date          TIMESTAMPTZ,
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  is_deleted             BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE (company_id, source_type, source_ref)
);
CREATE INDEX ix_kbd_company ON ai.kb_documents(company_id, source_type) WHERE is_active = TRUE;

-- ─────────────────────── ai.kb_chunks ───────────────────────
-- Vectorized chunks. The retrieval target.
CREATE TABLE ai.kb_chunks (
  chunk_id               BIGSERIAL PRIMARY KEY,
  company_id             BIGINT NOT NULL,             -- denormalized for fast tenant filter
  document_id            BIGINT NOT NULL REFERENCES ai.kb_documents(document_id) ON DELETE CASCADE,
  chunk_index            INT NOT NULL,                -- order within document
  content                TEXT NOT NULL,
  content_tokens         INT NOT NULL,
  embedding              vector(1536) NOT NULL,
  bm25_tsv               tsvector,                    -- precomputed for BM25
  metadata               JSONB,                       -- { headings, entity_field, source_url }
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  modified_date          TIMESTAMPTZ,
  is_deleted             BOOLEAN NOT NULL DEFAULT FALSE,
  deleted_date           TIMESTAMPTZ,                 -- soft-delete with 7-day grace
  UNIQUE (document_id, chunk_index)
);
CREATE INDEX ix_kbc_embedding ON ai.kb_chunks
  USING hnsw (embedding vector_cosine_ops) WHERE is_deleted = FALSE;
CREATE INDEX ix_kbc_bm25 ON ai.kb_chunks USING GIN(bm25_tsv) WHERE is_deleted = FALSE;
CREATE INDEX ix_kbc_company ON ai.kb_chunks(company_id) WHERE is_deleted = FALSE;

-- ─────────────────────── ai.tools_registry ───────────────────────
-- Declared tools the LLM can request to call. Each tool maps to a real PSS API.
CREATE TABLE ai.tools_registry (
  tool_id                BIGSERIAL PRIMARY KEY,
  code                   VARCHAR(100) NOT NULL UNIQUE,
  display_name           VARCHAR(150) NOT NULL,
  description            TEXT NOT NULL,
  input_schema           JSONB NOT NULL,              -- JSON Schema for tool inputs
  output_schema          JSONB NOT NULL,
  is_write              BOOLEAN NOT NULL DEFAULT FALSE,  -- TRUE in Phase 3; FALSE in Phase 2
  capability_required    VARCHAR(100),                -- PSS capability for permission check
  implementation_ref     VARCHAR(200) NOT NULL,       -- e.g., 'Aida.Tools.PSS.GetDonor'
  default_timeout_ms     INT NOT NULL DEFAULT 10000,
  max_retries            INT NOT NULL DEFAULT 1,
  visibility             VARCHAR(20) NOT NULL DEFAULT 'platform',  -- 'platform'|'tenant_private'
  owner_company_id       BIGINT REFERENCES companies(company_id),  -- NULL = platform
  status                 VARCHAR(20) NOT NULL DEFAULT 'published',
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active              BOOLEAN NOT NULL DEFAULT TRUE
);

-- Per-tenant enable/disable of tools (defaults to enabled when row absent)
CREATE TABLE ai.tenant_tools (
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  tool_code              VARCHAR(100) NOT NULL,
  is_enabled             BOOLEAN NOT NULL DEFAULT TRUE,
  config_json            JSONB,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  modified_date          TIMESTAMPTZ,
  PRIMARY KEY (company_id, tool_code)
);

-- ─────────────────────── ai.tool_call_log ───────────────────────
-- Audit of every tool call. Critical for security review.
CREATE TABLE ai.tool_call_log (
  tool_call_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id             BIGINT NOT NULL,
  user_id                BIGINT,
  session_id             UUID,
  message_id             BIGINT,
  tool_code              VARCHAR(100) NOT NULL,
  input_hash             VARCHAR(64) NOT NULL,        -- SHA-256 of input JSON
  input_json             JSONB,                       -- redacted if PII detected
  output_hash            VARCHAR(64),
  output_json            JSONB,                       -- redacted if PII detected
  outcome                VARCHAR(20) NOT NULL,        -- 'success'|'error'|'denied'|'timeout'
  error_class            VARCHAR(100),
  latency_ms             INT,
  capability_checked     VARCHAR(100),
  permission_granted     BOOLEAN,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ix_tcl_session ON ai.tool_call_log(session_id, created_date);
CREATE INDEX ix_tcl_company_date ON ai.tool_call_log(company_id, created_date DESC);
CREATE INDEX ix_tcl_denied ON ai.tool_call_log(outcome) WHERE outcome = 'denied';

-- ─────────────────────── ai.personas ───────────────────────
-- Persona presets: bundle of system-prompt prefix + style guide + default model class.
CREATE TABLE ai.personas (
  persona_id             BIGSERIAL PRIMARY KEY,
  code                   VARCHAR(50) NOT NULL UNIQUE,
  display_name           VARCHAR(100) NOT NULL,
  description            TEXT,
  system_prompt_prefix   TEXT NOT NULL,
  style_guide            TEXT,
  default_model_class    VARCHAR(50) NOT NULL DEFAULT 'reasoning_mid',
  default_temperature    NUMERIC(3,2) NOT NULL DEFAULT 0.5,
  citation_style         VARCHAR(20) NOT NULL DEFAULT 'inline_marker',  -- 'inline_marker'|'footnote'|'none'
  is_platform            BOOLEAN NOT NULL DEFAULT TRUE,
  owner_company_id       BIGINT REFERENCES companies(company_id),  -- NULL if platform
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────── ai.user_preferences ───────────────────────
CREATE TABLE ai.user_preferences (
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  user_id                BIGINT NOT NULL,
  preferred_locale       VARCHAR(10),
  preferred_persona_code VARCHAR(50),
  preferred_response_format VARCHAR(20),              -- 'concise'|'detailed'|'bullets'
  pinned_skills          TEXT[],                      -- array of skill_codes
  pinned_sessions        UUID[],
  hide_trace_by_default  BOOLEAN NOT NULL DEFAULT FALSE,
  metadata               JSONB,
  modified_date          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (company_id, user_id)
);

-- ─────────────────────── ai.eval_results ───────────────────────
-- Track CI eval set results over time. One row per eval-set run.
CREATE TABLE ai.eval_results (
  result_id              BIGSERIAL PRIMARY KEY,
  eval_set_name          VARCHAR(100) NOT NULL,       -- 'grid_ask_ai.v1'|'chat_skills.v1'
  eval_set_version       VARCHAR(20) NOT NULL,
  skill_code             VARCHAR(100),
  prompt_id              BIGINT,                      -- which prompt version was tested
  total_questions        INT NOT NULL,
  schema_valid_count     INT NOT NULL,
  user_intent_match_count INT,                        -- LLM-judged or human-judged
  critic_pass_count      INT,
  avg_latency_ms         INT,
  avg_cost_usd           NUMERIC(10,6),
  total_cost_usd         NUMERIC(10,4),
  ran_by                 VARCHAR(50),                 -- 'ci'|'manual'|'scheduled'
  trigger_ref            VARCHAR(200),                -- e.g., 'commit-sha-abc' or 'cron'
  details                JSONB,                       -- per-question pass/fail + diff vs baseline
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ix_eval_skill_date ON ai.eval_results(skill_code, created_date DESC);
```

### 4.1 Seed data — Phase 2

```sql
-- Personas (4 presets)
INSERT INTO ai.personas (code, display_name, description, system_prompt_prefix, style_guide, default_model_class, citation_style) VALUES
('pss_default',     'PSS Default',     'Balanced, professional, plain-language',
  'You are AIDA, an AI assistant for NGO operations. Be helpful, accurate, and cite sources.',
  'Use plain language. Avoid jargon. Always cite sources with [#N] markers.',
  'reasoning_mid', 'inline_marker'),

('claude_style',    'Claude-style',    'Concise, balanced, prose-first',
  'You are AIDA. Respond with measured, balanced analysis. Brief is better than verbose. No headings unless necessary.',
  'Plain text. Single-paragraph answers preferred. Avoid bullet lists unless the user requested them.',
  'reasoning_mid', 'inline_marker'),

('gpt_style',       'GPT-style',       'Structured, headers, bullets',
  'You are AIDA. Structure responses with clear headers, bullet lists, and tables where appropriate.',
  'Use headers. Use bullet lists. Use tables for comparisons. Cite all data.',
  'reasoning_mid', 'inline_marker'),

('perplexity_style','Perplexity-style','Citation-heavy, source-prominent',
  'You are AIDA. Every factual claim must be followed by [#N]. Surface sources prominently. Refuse if no sources available.',
  'Citation-dense. Refuse uncited claims. Group citations at end as numbered list.',
  'reasoning_mid', 'footnote');

-- Tool registry (Phase 2 read-only tools)
INSERT INTO ai.tools_registry (code, display_name, description, input_schema, output_schema, is_write, capability_required, implementation_ref) VALUES
('get_donor',           'Get donor',
  'Fetch a donor record by ID, with full profile and computed metrics.',
  '{"type":"object","properties":{"donor_id":{"type":"integer"}},"required":["donor_id"]}',
  '{"type":"object"}', FALSE, 'donor.read', 'Aida.Tools.PSS.GetDonor'),

('list_donors',         'List donors',
  'List donors matching filter; max 50 returned.',
  '{"type":"object","properties":{"filter":{"type":"object"},"limit":{"type":"integer","maximum":50}}}',
  '{"type":"object"}', FALSE, 'donor.read', 'Aida.Tools.PSS.ListDonors'),

('get_campaign',        'Get campaign',
  'Fetch a campaign with aggregate stats.',
  '{"type":"object","properties":{"campaign_id":{"type":"integer"}},"required":["campaign_id"]}',
  '{"type":"object"}', FALSE, 'campaign.read', 'Aida.Tools.PSS.GetCampaign'),

('compare_campaigns',   'Compare campaigns',
  'Return numeric comparison between 2 or more campaigns.',
  '{"type":"object","properties":{"campaign_ids":{"type":"array","items":{"type":"integer"}}}}',
  '{"type":"object"}', FALSE, 'campaign.read', 'Aida.Tools.PSS.CompareCampaigns'),

('list_donations',      'List donations',
  'List donations matching filter; max 100.',
  '{"type":"object","properties":{"filter":{"type":"object"},"limit":{"type":"integer","maximum":100}}}',
  '{"type":"object"}', FALSE, 'donation.read', 'Aida.Tools.PSS.ListDonations'),

('lookup_market_value', 'Look up market value',
  'Estimate fair-market value for a donated item.',
  '{"type":"object","properties":{"item_description":{"type":"string"},"condition":{"type":"string"}}}',
  '{"type":"object"}', FALSE, 'dik.read', 'Aida.Tools.PSS.LookupMarketValue'),

('lookup_fx_rate',      'Look up FX rate',
  'Fetch FX rate for a (from, to, date) tuple.',
  '{"type":"object","properties":{"from":{"type":"string"},"to":{"type":"string"},"date":{"type":"string"}}}',
  '{"type":"object"}', FALSE, 'fx_rate.read', 'Aida.Tools.PSS.LookupFxRate'),

('get_kpi',             'Get KPI',
  'Fetch a named KPI for a tenant/period.',
  '{"type":"object","properties":{"kpi_code":{"type":"string"},"period":{"type":"string"}}}',
  '{"type":"object"}', FALSE, 'dashboard.read', 'Aida.Tools.PSS.GetKpi');

-- 10 skills (5 from Sprint 7, 5 from Sprint 9). Manifests truncated for brevity.
-- Each skill row references the prompt_key it uses.
-- (Insert statements would mirror Phase 1's grid_ask_ai pattern.)
```

---

## 5. Backend Project Layout — Phase 2 Deltas

Additions under `PSS_2.0_Backend/PeopleServe/Services/Aida/`:

```
Aida.Domain/
├── Entities/
│   ├── MemoryEntry.cs              [NEW]
│   ├── KbDocument.cs               [NEW]
│   ├── KbChunk.cs                  [NEW]
│   ├── ToolDefinition.cs           [NEW]
│   ├── ToolCallLog.cs              [NEW]
│   ├── Persona.cs                  [NEW]
│   ├── UserPreference.cs           [NEW]
│   └── EvalResult.cs               [NEW]
├── ValueObjects/
│   ├── RetrievalResult.cs          [NEW]
│   ├── ChatTurnContext.cs          [NEW]
│   └── ToolCall.cs                 [NEW]
└── Events/
    ├── KbDocumentIngestedEvent.cs  [NEW]
    └── ChatTurnCompletedEvent.cs   [NEW]

Aida.Application/
├── Memory/
│   ├── IMemoryService.cs           [NEW]
│   ├── MemoryHandlers.cs           [NEW]
│   └── ForgetMemoryHandler.cs      [NEW]
├── KnowledgeBase/
│   ├── IKbIngestionService.cs      [NEW]
│   ├── KbIngestor<T>.cs            [NEW] (one per ingested entity)
│   ├── ChunkingService.cs          [NEW]
│   └── EmbeddingService.cs         [NEW]
├── Retrieval/
│   ├── IRetrievalService.cs        [NEW]
│   ├── HybridRetrievalService.cs   [NEW] (BM25 + vector + RRF)
│   ├── PermissionFilter.cs         [NEW]
│   └── RerankerService.cs          [NEW, optional]
├── Chat/
│   ├── ChatOrchestrator.cs         [NEW]
│   ├── WorkingMemoryService.cs     [NEW]
│   ├── SummarizationService.cs     [NEW]
│   └── StreamingService.cs         [NEW]
├── Tools/
│   ├── IToolRegistry.cs            [NEW]
│   ├── ToolCallExecutor.cs         [NEW]
│   ├── PSS/                        [NEW] — concrete tool implementations
│   │   ├── GetDonor.cs
│   │   ├── ListDonors.cs
│   │   ├── GetCampaign.cs
│   │   ├── CompareCampaigns.cs
│   │   ├── ListDonations.cs
│   │   ├── LookupMarketValue.cs
│   │   ├── LookupFxRate.cs
│   │   └── GetKpi.cs
│   └── ToolDtos.cs                 [NEW]
├── Personas/
│   ├── IPersonaService.cs          [NEW]
│   └── PersonaInjector.cs          [NEW]
├── Skills/                          [EXTENDED]
│   ├── DonorSummary.cs             [NEW]
│   ├── CampaignPerformanceExplainer.cs [NEW]
│   ├── Summarization.cs            [NEW]
│   ├── AnomalyFlag.cs              [NEW]
│   ├── FxExplanation.cs            [NEW]
│   ├── MeetingNotesToActions.cs    [NEW]
│   ├── PledgeFollowupPlanner.cs    [NEW]
│   ├── DuplicateDonorResolver.cs   [NEW]
│   ├── ComplianceValidator.cs      [NEW]
│   └── DikValuationAssistant.cs    [NEW]
├── Critic/
│   └── CriticAgent.cs              [NEW]
└── Evaluation/
    ├── EvalSetRunner.cs            [NEW]
    └── EvalSets/
        └── chat_skills_v1.json     [NEW] (200 questions)

Aida.Infrastructure/
├── Persistence/Configurations/     [+8 new IEntityTypeConfiguration<T>]
├── Embeddings/
│   ├── OpenAiEmbeddingClient.cs    [NEW]
│   └── EmbeddingCache.cs           [NEW] (Redis-backed)
├── VectorSearch/
│   └── PgVectorClient.cs           [NEW] — HNSW search wrapper
├── BackgroundJobs/
│   ├── KbIngestionScheduler.cs     [NEW] — Hangfire jobs per entity type
│   └── KbChunkPurgeJob.cs          [NEW] — hard-delete 7-day-old soft-deleted chunks
└── Streaming/
    └── SseResponseWriter.cs        [NEW]

Aida.Api/
├── Controllers/
│   ├── ChatController.cs           [NEW] — sessions, messages CRUD
│   ├── MemoryController.cs         [NEW]
│   ├── PersonaController.cs        [NEW] — admin
│   ├── PreferencesController.cs    [NEW]
│   └── AdminEvalController.cs      [NEW]
├── Sse/
│   └── ChatStreamEndpoint.cs       [NEW]
└── Middleware/
    └── SessionContextMiddleware.cs [NEW]
```

---

## 6. Frontend Project Layout — Phase 2 Deltas

```
src/components/ai/
├── ChatPanel/                          [NEW]
│   ├── ChatPanel.tsx
│   ├── FloatingChatLauncher.tsx        ← bottom-right button
│   ├── MessageBubble.tsx
│   ├── MessageActions.tsx
│   ├── TraceBlock.tsx
│   ├── KpiTileRow.tsx
│   ├── CitationStrip.tsx
│   ├── ToolCallIndicator.tsx
│   ├── Composer.tsx
│   ├── ModeTabs.tsx
│   └── EmptyState.tsx
├── ChatHistory/                        [NEW]
│   ├── SessionsRail.tsx
│   ├── SessionItem.tsx
│   ├── ConversationViewer.tsx
│   ├── DetailsPanel.tsx
│   └── ResumeBar.tsx
├── PersonaSelector/                    [NEW]
│   ├── PersonaSelector.tsx
│   └── PersonaPreview.tsx
└── MemoryManager/                      [NEW]
    ├── MemoryList.tsx
    └── ForgetMemoryButton.tsx

src/features/ai/
├── chat/                               [NEW]
│   ├── api.ts                          ← REST + SSE
│   ├── streamingHandler.ts
│   ├── useChatSession.ts
│   ├── useChatStream.ts
│   └── types.ts
├── history/                            [NEW]
│   ├── api.ts
│   └── useSessionsList.ts
└── memory/                             [NEW]
    └── api.ts

src/app/[lang]/aida/                    [NEW]
├── chat/
│   └── [sessionId]/page.tsx            ← deep-link to a chat
├── history/page.tsx                    ← matches chat-history.html
└── preferences/page.tsx

src/lib/ai/                             [EXTENDED]
└── chatPersistence.ts                  [NEW] — localStorage SessionId
```

---

## 7. API Surface — what Phase 2 adds

```
# Sessions
POST   /ai/chat/sessions                     # create new session (returns sessionId)
GET    /ai/chat/sessions                     # list user's sessions (paginated, filterable)
GET    /ai/chat/sessions/:id                 # get session + last 50 messages
PATCH  /ai/chat/sessions/:id                 # rename, pin/unpin, archive
DELETE /ai/chat/sessions/:id                 # "forget this conversation" cascade delete

# Messages
POST   /ai/chat/sessions/:id/messages        # send message (non-streaming)
GET    /ai/chat/sessions/:id/messages/stream # SSE — start streaming reply
POST   /ai/chat/sessions/:id/cancel          # cancel in-flight stream
POST   /ai/chat/messages/:id/rate            # thumbs up/down

# Memory
GET    /ai/memory                            # list user's memory
POST   /ai/memory                            # add explicit fact
DELETE /ai/memory/:id                        # forget a fact

# Knowledge Base (admin)
GET    /ai/admin/kb/documents                # list ingested docs
POST   /ai/admin/kb/reindex                  # re-embed everything (or filter)
DELETE /ai/admin/kb/documents/:id            # remove from KB

# Tools (admin)
GET    /ai/admin/tools                       # list registry
PATCH  /ai/admin/tools/:code/enable          # tenant enable/disable

# Personas
GET    /ai/personas                          # list available
GET    /ai/personas/:code/preview            # render a sample with this persona

# Preferences
GET    /ai/preferences                       # current user's prefs
PUT    /ai/preferences                       # update

# Eval
GET    /ai/admin/eval/results                # eval-set history
POST   /ai/admin/eval/run                    # trigger a run (typically CI)
```

---

## 8. Phase 2 Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Embedding cost spike (KB grows fast) | Med | Med | Budget alert on embedding spend; only embed `pss_entity` changes (delta-only) |
| pgvector HNSW slow at scale (>5M chunks) | Med | Med | Performance test in Sprint 6; have Qdrant migration plan ready (it's just a different `IVectorClient`) |
| Refresh mid-stream loses partial message | Low | Low | By design — messages are committed only on completion; documented in UX |
| Tool call leaks data the user can't access | Low | **Critical** | Tools wrap existing PSS authorized APIs — same auth as if user called directly; `tool_call_log.permission_granted` audited |
| Critic flapping (low-confidence on good responses) | Med | Low | Tune threshold per skill; allow user-override "Show anyway"; baseline against eval set |
| RAG retrieval returns stale data (KB lag) | Med | Med | Document update → re-embed within 60s; show "data as of HH:MM" in UI for stale-sensitive skills |
| User memory grows unbounded | Low | Low | Per-user cap (e.g., 500 entries); oldest non-pinned auto-expired after retention period |
| Tenants conflict on persona — same tenant, different users want different defaults | Low | Low | `ai.user_preferences.preferred_persona_code` overrides tenant default per user |
| Chat session count explodes (1 per query culture) | Med | Low | "Continue last session" is the default in UI; explicit "New" required to mint |
| KB ingestion job stuck on one entity, blocks rest | Med | Med | Per-entity-type Hangfire queue with isolation; failed jobs go to DLQ with alert |
| Embedding model deprecated by OpenAI | Low | Med | Adapter pattern; pin model version in `model_class_map`; full re-embed run is ~6h for 1M chunks |
| Streaming connection drops mid-response | Med | Low | Client reconnects with `Last-Event-Id` SSE header; server replays from buffer (Redis, 30s TTL) |

---

## 9. Definition of Ready — Sprint 6 can start when

- [ ] Phase 1 GA review passed (`Implementation-Plan-Phase-0-1.md` §3 Phase 1 DoD all green)
- [ ] OpenAI embeddings dev key procured + stored in Key Vault
- [ ] pgvector extension installable on prod Postgres (DBA approval)
- [ ] Redis Cluster capacity for working memory verified (~200MB per 1000 active sessions)
- [ ] Hangfire dashboard accessible to Aida service
- [ ] Phase 1 learnings doc written (which prompts worked, which didn't, what tenants asked for)
- [ ] 2 pilot tenants confirmed (continue from Phase 1, OR swap if A or B churned)
- [ ] Replan workshop held (W10 retro → adjust §1 decisions if needed)

---

## 10. Decision Points During Phase 2

| Week | Decision |
|---|---|
| W12 (end Sprint 6) | KB ingestion working at expected scale? If not, defer Phase 2.B (uploaded docs) to Phase 3 |
| W14 (end Sprint 7) | Skills meeting 90% schema-valid rate? If <80%, pause and tune before Sprint 8 |
| W16 (end Sprint 8) | Refresh-safety + streaming stable? If not, hold the chat surface from pilot until fix |
| W18 (end Sprint 9) | Persona presets land well in internal review? If "all four feel the same", spend time differentiating |
| W20 (end Sprint 10) | GA decision: ship Global Chat to all tenants OR extend pilot OR adjust persona/skill set |

---

## 11. What Phase 2 enables for Phase 3

When Phase 2 GAs, the substrate is ready for Phase 3 without further re-architecture:
- **Sessions** can be hook-spawned (just set `surface='hook'` + `event_id`)
- **Tools** registry can hold write tools (just flip `is_write=true` after HITL plumbing)
- **Skills** can be chained (manifest already supports it; orchestrator just needs to execute)
- **Memory** can hold workflow checkpoints (workflows use a tag `kind='workflow_state'`)

Phase 3 plan: `Implementation-Plan-Phase-3.md`.

---

*— End of Phase 2 plan —*
