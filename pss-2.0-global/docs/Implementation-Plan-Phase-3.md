# PSS 2.0 AIDA — Phase 3 Implementation Plan

## Agents + Hooks + Workflows + Write-Capable Tools (Weeks 21–32)

> **Companion to** `AI-Platform-Architecture.md`, `Implementation-Plan-Phase-0-1.md`, `Implementation-Plan-Phase-2.md`.
> **Plans** the 12 weeks following Phase 2 GA.
> **Replan trigger:** end of Phase 2 GA (W20) — refresh this doc with Phase 2 learnings.
> **Status:** Forward-looking. Will be revised at W20.

---

## 1. Locked Decisions (provisional — confirm at W20)

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | **Agent framework** | Custom orchestrator with a shared Redis blackboard | LangGraph / Semantic Kernel introduce dependency weight; we want narrow ownership of the loop. |
| 2 | **Write-tool gating** | **Mandatory HITL queue** for every write tool in Phase 3 | Trust earned per-skill-per-tenant; auto-approve only granted after tenant explicitly opts in. |
| 3 | **Event bus** | RabbitMQ (or Azure Service Bus if Azure-pinned) | Existing infra. Topic exchange per event class. |
| 4 | **Hook delivery default** | **Async** for everything except compliance-validation hooks | Compliance hooks block the originating transaction (sync); everything else uses queue. |
| 5 | **Idempotency** | Mandatory `EventId` on every event; consumer dedupes on `(EventId, HookId)` | Reprocessing must be safe. |
| 6 | **Multi-agent loop budget** | 8 steps max per turn; 60s wall-clock max | Hard cap. Step budget configurable per skill (1..20). |
| 7 | **Workflow state durability** | Postgres (`ai.workflow_state`), not just Redis | Workflows can span days (e.g., DIK valuation across multiple sessions). |
| 8 | ⚠️ **Critic in agent loop** | ON by default in Phase 3 for agent-driven turns; OFF for simple chat | Agents touch more state — verification matters more. Re-evaluate cost at W26. |
| 9 | ⚠️ **First write tools to ship** | `queue_email_for_review`, `draft_acknowledgement`, `schedule_followup`, `update_donor_note`, `create_task` | All HITL by default. Confirm with pilot tenants. |
| 10 | **Write-tool tenant onboarding** | Tenant explicitly opts in (admin toggle, signed) per write tool | No surprise mutations. |

---

## 2. Scope Map — what ships in Phase 3

```
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3  ·  AGENTS + HOOKS + WORKFLOWS  ·  Weeks 21–32          │
│  ─────────────────────────────────────────                       │
│  Sprint 11 (W21–22)  Planner + Executor agents                   │
│  Sprint 12 (W23–24)  Validator + Compliance agents + Critic-loop │
│  Sprint 13 (W25–26)  Event bus + first 3 hooks                   │
│  Sprint 14 (W27–28)  Write-tools + HITL approval queue           │
│  Sprint 15 (W29–30)  Conversational workflows (DIK, dup-resolve) │
│  Sprint 16 (W31–32)  Polish + Pilot rollout + Hardening          │
│                                                                  │
│  → Deliverable: Hook-driven AI actions live. Multi-step agent   │
│    flows. Write tools with HITL. 5 conversational workflows.    │
└─────────────────────────────────────────────────────────────────┘
```

**Phase 3 explicitly does NOT include:** tenant-private custom skills UI (Phase 4), fine-tuning, multimodal, local LLM. Reading from any new source beyond PSS entities + KB.

---

## 3. Phase 3 Sprint Plan

### 3.1 Sprint 11 (W21–W22) — Planner & Executor Agents

**Goal:** Multi-step turns work. A complex question gets decomposed into N skills/tool calls, executed, and synthesized into one answer.

| Story | Owner | Acceptance |
|---|---|---|
| `IAgent` interface + base `Agent` class with step budget, cancellation token, blackboard access | BE Lead | Unit-tested abstract |
| `PlannerAgent` — decomposes goal into ordered plan of `{ skill / tool, args, depends_on }` | BE + Prompt Eng | Unit test: "Acknowledge yesterday's donations" → 3-step plan (list → draft → queue) |
| `ExecutorAgent` — runs the plan, marshals inputs/outputs, handles tool errors | BE | E2E test: full 3-step plan executes; intermediate artifacts visible on blackboard |
| `Blackboard` — Redis hash keyed by `aida:agent:{sessionId}:{turnId}` with structured artifacts | BE | Read/write/scan tested; TTL = session lifetime |
| `AgentRun` table + lifecycle (`spawned` → `running` → `completed`/`failed`/`cancelled`) | BE | DB rows match agent execution |
| Step-budget enforcement: 8 default, configurable per skill; over-budget = graceful end | BE | Test: skill with budget=2 attempting 3 steps stops at 2; user sees "I couldn't complete in budget" |
| Cancel token propagation: user clicks Cancel → all in-flight agent calls + tool calls abort | BE | Latency test: cancel-to-stop < 500ms |
| Agent telemetry: `ai_agent_steps_per_turn`, `ai_agent_completion_rate`, `ai_agent_avg_duration` | DevOps | Grafana panel; per-skill breakdown |
| First multi-step demo: chat input "Compare this year's Diwali campaign to last year and draft an executive summary" → planner decomposes → executor runs → response | Prompt Eng | Demoable; 90%+ success rate on 20-sample eval |

**Sprint 11 DoD:**
- 5 multi-step skills work end-to-end (planner-decomposed).
- All agent execution traces persisted in `ai.agent_traces`.
- Cancel works fast.

### 3.2 Sprint 12 (W23–W24) — Validator + Compliance + Critic-in-loop

**Goal:** Every agent-driven turn is validated before responding. Compliance-flagged tenants get an additional review layer.

| Story | Owner | Acceptance |
|---|---|---|
| `ValidatorAgent` — checks output against skill's output schema + business rules | BE + Prompt Eng | Test: synthetic invalid output → caught and retried (1×) with stricter prompt |
| Output schema enforcement library — re-uses JSON Schema validators from Phase 1 | BE | Unit tests on 20 schemas |
| `ComplianceAgent` — applies tenant compliance profile (PII mode, block-topics, residency) | BE | Test: tenant with `block_topics=['investment_advice']` → AI declining investment questions; logged |
| Critic re-integrated into agent loop: runs **after** ValidatorAgent on agent-driven turns | BE | Confidence threshold per tenant; below threshold = retry once with tightened prompt |
| Compliance profile defaults seeded for tenants (per `pii_mode` from Phase 0) | BE | Default rows; admin UI to extend |
| Block-list dictionary configurable per tenant (`ai.tenant_block_topics` table) | BE | Tenant admin can add/remove topics; effect within 60s |
| Refusal templates per locale (English, Tamil, Hindi) for compliance-blocked outputs | Prompt Eng | 5 templates; A/B internal review |
| Agent failure observability: count of validator-rejects, compliance-blocks, critic-retries per skill per tenant | DevOps | Grafana panel; alerts when validator-reject rate > 10% for any skill |
| Skill manifest extended with `compliance_sensitive: bool` — when true, ComplianceAgent always runs | BE | Manifest validation enforces |

**Sprint 12 DoD:**
- Every agent turn passes through Validator + (conditional) Compliance + Critic.
- ≥ 95% of in-prod agent turns produce valid output (vs raw LLM ~85%).

### 3.3 Sprint 13 (W25–W26) — Event Bus + First 3 Hooks

**Goal:** PSS domain events trigger async AI work. Three hooks live in pilot.

| Story | Owner | Acceptance |
|---|---|---|
| RabbitMQ (or Service Bus) topic exchange `pss.events` set up | DevOps | Exchange created; AIDA bound as consumer; ack/nack/DLQ tested |
| `EventPublisher` integrated into PSS Core entity lifecycles (start with Donation, Pledge, Case, FxRate, DIK) | PSS Core BE | Each entity emits typed event on create/update; payload includes minimum needed fields |
| `EventEnvelope` schema: `{ event_id, event_type, company_id, occurred_at, payload, causation_id, correlation_id }` | BE | Versioned; backwards-compat negotiated |
| `HooksDispatcher` — consumes events, looks up matching hooks per tenant, applies condition (JsonLogic), enqueues for execution | BE | E2E: donation.created event with amount≥1000 → matching hook executes |
| Tables: `ai.hooks`, `ai.hook_executions` | BE | DDL applied; indexes for lookup |
| Sync-hook fast path: ComplianceAgent invoked inline if hook's `delivery=sync`; result returned to PSS event publisher | BE | Test: sync hook + slow LLM → publisher request fails with timeout; transaction rolls back; alert |
| Idempotency: dedupe consumer by `(event_id, hook_id)` in a Redis SET with 7-day TTL | BE | Replay same event → only 1 hook execution |
| Hook execution retry: 3 attempts, exponential backoff + jitter; failed → DLQ + alert | BE | Failure-injection test verifies behavior |
| First 3 hooks: `acknowledge_after_donation` (≥₹1000), `anomaly_check_after_donation` (≥₹50K OR foreign), `pledge_due_soon_reminder` (30-day window) | Prompt Eng + BE | Manifests committed; eval set runs for each |
| Hook admin UI: list, enable/disable, edit condition, view execution history per tenant | FE | Mirror of REST endpoints |
| Each hook execution spawns a `ChatSession(surface='hook')` so admin can review the AI reasoning | BE | Sessions appear in History UI with "Hook" filter chip |

**Sprint 13 DoD:**
- 3 hooks executing in pilot tenant on real events.
- DLQ + alerts working.
- Hook executions appear in tenant's chat history.

### 3.4 Sprint 14 (W27–W28) — Write Tools + HITL Approval Queue

**Goal:** AI can stage writes; humans approve. Five write tools live.

| Story | Owner | Acceptance |
|---|---|---|
| `IApprovalQueue` interface + `ai.approval_queue` table | BE | Tested |
| `WriteToolExecutor` — wraps any tool with `is_write=true`; instead of executing, stages the call to approval queue | BE | E2E test: tool call → row in approval_queue with status='pending'; tool NOT executed |
| Approval queue UI: pending items grouped by tenant/user/skill; approve/reject/edit | FE | Bulk approve supported; edit-before-approve supported |
| On approve: tool actually executes via PSS API with original args (or edited args); result + audit logged | BE | Test: approve donation-update → entity actually updated; audit chain visible |
| On reject: original AI session updated with rejection reason; AI can be re-asked to revise | BE | Tested |
| First 5 write tools: `queue_email_for_review`, `draft_acknowledgement` (write into Drafts), `schedule_followup` (creates Task), `update_donor_note` (appends a Note), `create_task` | BE | Each tool authorized via existing PSS Capability; CrossTenantLeakTests cover |
| Per-tenant per-tool `auto_approve_threshold` (default = always require approval) | BE | Test: tenant flipping a tool to auto-approve → AI executes directly; still audited |
| Auto-approve safety: rate limit per (tenant, tool) — e.g., max 100 auto-approves per day | BE | Test: hitting limit → fallback to human-approval mode for the day |
| Approval expiry: items pending > 7 days auto-rejected with notification | BE | Hangfire job runs daily |
| Approval queue notifications: email/in-app per tenant policy | BE + FE | Configurable per tenant + per skill |

**Sprint 14 DoD:**
- 5 write tools usable by AI.
- All AI-staged writes flow through approval queue.
- No AI write bypasses approval (audit + integration test verifies).

### 3.5 Sprint 15 (W29–W30) — Conversational Workflows

**Goal:** Multi-turn business workflows that span sessions. State persists; can be paused and resumed.

| Story | Owner | Acceptance |
|---|---|---|
| `IWorkflow` interface + state machine framework | BE Lead | Unit-tested abstraction |
| Tables: `ai.workflow_definitions`, `ai.workflow_state` | BE | DDL applied |
| State persistence: every state transition writes to `ai.workflow_state` with serialized context | BE | Test: pause workflow, restart service, resume successfully |
| `WorkflowEngine` — orchestrates state transitions; integrates with ChatOrchestrator | BE | Workflow turns share session with ad-hoc chat turns |
| First 5 workflows: | Prompt Eng + BE | Each tested end-to-end |
| &nbsp;&nbsp;1. **DIK Valuation** — ask item, photos, condition → look up market value → propose estimate → user confirms → write to DIK record (HITL) | | Demoable with 10 sample items |
| &nbsp;&nbsp;2. **Duplicate Donor Resolve** — list candidates → user picks pair → AI shows confidence + diff → user approves merge (HITL) | | Tested on seeded duplicates |
| &nbsp;&nbsp;3. **Acknowledgement Flow** — pick donation → draft → review → send (HITL on send) | | Email actually queued |
| &nbsp;&nbsp;4. **Pledge Follow-up Cadence** — given pledge → propose 3-touch cadence → user adjusts → schedule tasks (HITL on schedule) | | Tasks created in PSS |
| &nbsp;&nbsp;5. **Case Triage** — incoming case → suggest category, severity, assignee → user approves → update case (HITL) | | Tested on 20 sample cases |
| Workflow timeout: stale workflows auto-archive after 30 days; user can resume from history within window | BE | Hangfire job daily |
| Workflow admin: list active workflows per tenant; force-archive; debug-view state | FE | Admin-only |
| Workflow telemetry: completion rate per workflow; avg duration; rejection rate | DevOps | Grafana |

**Sprint 15 DoD:**
- 5 workflows live in pilot.
- Resumability verified: start workflow → close browser → next day, open History → resume → state intact.

### 3.6 Sprint 16 (W31–W32) — Polish + Pilot Rollout + Hardening

| Story | Owner | Acceptance |
|---|---|---|
| Adversarial red-team: 200 prompt-injection inputs against write tools | QA | None succeeds in unapproved mutation |
| Cross-tenant leak audit: comprehensive review of hook payloads, agent blackboard contents, workflow state | Security + QA | No leak vectors found |
| Performance: agent-turn TTFT P95 ≤ 3s; full turn P95 ≤ 15s | BE | Load test passes |
| Hook execution SLA: P95 < 60s for async hooks from event publish to AI action staged | DevOps | Grafana SLO panel |
| Approval queue UX: keyboard shortcuts, bulk actions, diff view, audit trail per item | FE | Usability tested with 3 pilot admins |
| Per-tenant skill capability dashboard: "What can AIDA do in our org?" | FE | Reads from `ai.skills` × `ai.tenant_skills` × `ai.tenant_tools`; surfaces enabled set |
| Help center: "How AI hooks work", "Approving AI actions", "Workflows in PSS" | Product + CS | 3 articles |
| Runbooks: "Hook flapping", "Approval queue backed up", "Workflow stuck", "Tool call denied storm" | DevOps | 4 reviewed |
| Pilot rollout: 3 tenants → hooks ON for 2, write tools ON for 1, workflows ON for all 3 | CS + Eng | Per-tenant feature flags |
| Final eval: 500 questions across agents + hooks + workflows | QA | ≥ 90% schema-valid, ≥ 80% Critic-pass |

**Sprint 16 / Phase 3 DoD:**
- Hooks executing in prod for ≥ 2 tenants
- Write tools approved + executed via HITL in prod (≥ 50 approvals across tenants in soak week)
- 5 workflows demonstrably resumable across days
- Agent loop P95 ≤ 15s
- Zero auto-approve override incidents in soak
- Approval queue UX usable (NPS ≥ 7 from pilot admins)
- Hook event publish-to-action latency P95 ≤ 60s
- Adversarial test suite passing (200 inputs, 0 successful injections)

---

## 4. Database Design — Phase 3 Additions

```sql
-- ─────────────────────── ai.hooks ───────────────────────
CREATE TABLE ai.hooks (
  hook_id                BIGSERIAL PRIMARY KEY,
  company_id             BIGINT REFERENCES companies(company_id),  -- NULL = platform default for all
  code                   VARCHAR(100) NOT NULL,
  display_name           VARCHAR(200) NOT NULL,
  event_type             VARCHAR(100) NOT NULL,        -- 'donation.created' etc.
  condition_json         JSONB,                        -- JsonLogic filter
  skill_code             VARCHAR(100) NOT NULL,
  args_template          JSONB NOT NULL,               -- JSONPath into event payload
  delivery               VARCHAR(20) NOT NULL,         -- 'sync'|'async'
  retry_policy           JSONB NOT NULL,               -- { max_attempts, backoff, base_ms, jitter }
  timeout_ms             INT NOT NULL DEFAULT 60000,
  on_success             JSONB,                        -- array of follow-up actions
  on_failure             JSONB,
  is_enabled             BOOLEAN NOT NULL DEFAULT FALSE,
  is_compliance_sensitive BOOLEAN NOT NULL DEFAULT FALSE,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by             BIGINT NOT NULL,
  modified_date          TIMESTAMPTZ
);
CREATE INDEX ix_hooks_event_company ON ai.hooks(event_type, company_id) WHERE is_enabled = TRUE;

-- ─────────────────────── ai.hook_executions ───────────────────────
-- One row per hook execution attempt. Idempotency on (event_id, hook_id).
CREATE TABLE ai.hook_executions (
  execution_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id             BIGINT NOT NULL,
  hook_id                BIGINT NOT NULL REFERENCES ai.hooks(hook_id),
  event_id               UUID NOT NULL,
  event_type             VARCHAR(100) NOT NULL,
  session_id             UUID,                         -- chat_session created for this execution
  attempt                INT NOT NULL DEFAULT 1,
  status                 VARCHAR(20) NOT NULL,         -- 'queued'|'running'|'success'|'failed'|'dlq'|'skipped'
  payload_summary        JSONB,                        -- redacted: structure only, no values
  result_summary         JSONB,
  error_class            VARCHAR(100),
  duration_ms            INT,
  started_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_date         TIMESTAMPTZ,
  UNIQUE (event_id, hook_id, attempt)
);
CREATE INDEX ix_he_company_date ON ai.hook_executions(company_id, started_date DESC);
CREATE INDEX ix_he_status ON ai.hook_executions(status) WHERE status IN ('queued','running','failed');
CREATE INDEX ix_he_dlq ON ai.hook_executions(hook_id, started_date DESC) WHERE status = 'dlq';

-- ─────────────────────── ai.tenant_block_topics ───────────────────────
-- Tenant-specific topic block-list for ComplianceAgent.
CREATE TABLE ai.tenant_block_topics (
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  topic_code             VARCHAR(100) NOT NULL,
  description            TEXT,
  block_severity         VARCHAR(20) NOT NULL DEFAULT 'block',  -- 'block'|'warn'|'log'
  refusal_template_key   VARCHAR(100),
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (company_id, topic_code)
);

-- ─────────────────────── ai.agent_traces ───────────────────────
-- Detailed per-step trace of an agent run. One row per step.
CREATE TABLE ai.agent_traces (
  trace_id               BIGSERIAL PRIMARY KEY,
  agent_run_id           UUID NOT NULL,
  session_id             UUID NOT NULL,
  message_id             BIGINT,
  company_id             BIGINT NOT NULL,
  step_index             INT NOT NULL,
  agent_type             VARCHAR(50) NOT NULL,         -- 'planner'|'executor'|'validator'|'compliance'|'critic'
  action_type            VARCHAR(50) NOT NULL,         -- 'plan'|'invoke_skill'|'invoke_tool'|'reflect'|'reject'
  action_payload         JSONB,
  blackboard_keys_read   TEXT[],
  blackboard_keys_written TEXT[],
  outcome                VARCHAR(20) NOT NULL,
  duration_ms            INT,
  cost_usd               NUMERIC(10,6),
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ix_at_run ON ai.agent_traces(agent_run_id, step_index);
CREATE INDEX ix_at_session ON ai.agent_traces(session_id, created_date);

-- ─────────────────────── ai.approval_queue ───────────────────────
CREATE TABLE ai.approval_queue (
  approval_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  staged_by_user_id      BIGINT,                       -- user whose chat initiated this
  session_id             UUID,                         -- originating session
  message_id             BIGINT,                       -- originating message
  hook_execution_id      UUID,                         -- if from hook
  tool_code              VARCHAR(100) NOT NULL,
  tool_input_json        JSONB NOT NULL,               -- proposed args
  proposed_preview       JSONB,                        -- human-readable preview (e.g., email subject + body)
  status                 VARCHAR(20) NOT NULL DEFAULT 'pending',  -- 'pending'|'approved'|'rejected'|'expired'|'auto_approved'
  decided_by_user_id     BIGINT,
  decided_date           TIMESTAMPTZ,
  decision_reason        TEXT,
  edited_input_json      JSONB,                        -- if approver edited args before approving
  executed_date          TIMESTAMPTZ,
  execution_result       JSONB,
  expires_date           TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days',
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ix_aq_pending ON ai.approval_queue(company_id, created_date DESC) WHERE status = 'pending';
CREATE INDEX ix_aq_session ON ai.approval_queue(session_id);
CREATE INDEX ix_aq_expiry ON ai.approval_queue(expires_date) WHERE status = 'pending';

-- Update existing tools_registry — flag write tools (already supports is_write)
-- Add per-tenant per-tool auto-approve setting
CREATE TABLE ai.tenant_tool_auto_approve (
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  tool_code              VARCHAR(100) NOT NULL,
  auto_approve_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
  daily_limit            INT NOT NULL DEFAULT 100,
  current_day_count      INT NOT NULL DEFAULT 0,
  current_day_date       DATE,
  guardrails_json        JSONB,                        -- e.g., max_amount, allowed_recipients
  signed_off_by_user_id  BIGINT,
  signed_off_date        TIMESTAMPTZ,
  modified_date          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (company_id, tool_code)
);

-- ─────────────────────── ai.workflow_definitions ───────────────────────
CREATE TABLE ai.workflow_definitions (
  workflow_id            BIGSERIAL PRIMARY KEY,
  code                   VARCHAR(100) NOT NULL,
  version                VARCHAR(20) NOT NULL,
  display_name           VARCHAR(200) NOT NULL,
  description            TEXT,
  states_json            JSONB NOT NULL,               -- state machine def: { states[], transitions[], initial }
  initial_state          VARCHAR(50) NOT NULL,
  terminal_states        TEXT[] NOT NULL,
  skill_bindings         JSONB NOT NULL,               -- map state → skill_code
  visibility             VARCHAR(20) NOT NULL DEFAULT 'platform',
  owner_company_id       BIGINT REFERENCES companies(company_id),
  status                 VARCHAR(20) NOT NULL DEFAULT 'published',
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (code, version, owner_company_id)
);

-- ─────────────────────── ai.workflow_state ───────────────────────
-- Live workflow instances. Stateful, durable.
CREATE TABLE ai.workflow_state (
  instance_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  user_id                BIGINT NOT NULL,
  workflow_code          VARCHAR(100) NOT NULL,
  workflow_version       VARCHAR(20) NOT NULL,
  session_id             UUID,
  current_state          VARCHAR(50) NOT NULL,
  context_json           JSONB NOT NULL,               -- accumulated state across turns
  history                JSONB NOT NULL DEFAULT '[]',  -- list of {state, transitioned_at, by}
  status                 VARCHAR(20) NOT NULL DEFAULT 'active',  -- 'active'|'paused'|'completed'|'failed'|'archived'
  pause_reason           TEXT,
  started_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_activity_date     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_date         TIMESTAMPTZ,
  expires_date           TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '30 days'
);
CREATE INDEX ix_ws_active ON ai.workflow_state(company_id, user_id, last_activity_date DESC)
  WHERE status = 'active';
CREATE INDEX ix_ws_expiry ON ai.workflow_state(expires_date) WHERE status IN ('active','paused');

-- ─────────────────────── ai.agent_runs ───────────────────────
-- One row per agent invocation (planner/executor lifecycle).
CREATE TABLE ai.agent_runs (
  agent_run_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id             UUID NOT NULL,
  message_id             BIGINT,
  company_id             BIGINT NOT NULL,
  user_goal              TEXT,
  plan_json              JSONB,
  status                 VARCHAR(20) NOT NULL,         -- 'spawned'|'running'|'completed'|'failed'|'cancelled'
  step_count             INT NOT NULL DEFAULT 0,
  step_budget            INT NOT NULL DEFAULT 8,
  duration_ms            INT,
  total_cost_usd         NUMERIC(10,6),
  outcome_summary        TEXT,
  cancellation_reason    TEXT,
  started_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_date         TIMESTAMPTZ
);
CREATE INDEX ix_ar_session ON ai.agent_runs(session_id, started_date);
```

### 4.1 Seed data — Phase 3

```sql
-- Initial hook definitions (platform — tenants opt in to enable)
INSERT INTO ai.hooks (company_id, code, display_name, event_type, condition_json, skill_code, args_template, delivery, retry_policy, is_enabled) VALUES
(NULL, 'acknowledge_after_donation', 'Acknowledge after donation',
  'donation.created',
  '{">=":[{"var":"amount"},1000]}',
  'acknowledgement_drafter',
  '{"donation_id":"$.donation_id","donor_id":"$.donor_id"}',
  'async',
  '{"max_attempts":3,"backoff":"exponential","base_ms":1000,"jitter":true}',
  FALSE),

(NULL, 'anomaly_check_after_donation', 'Check anomalies on big donations',
  'donation.created',
  '{"or":[{">=":[{"var":"amount"},50000]},{"==":[{"var":"is_foreign"},true]}]}',
  'anomaly_flag',
  '{"donation_id":"$.donation_id"}',
  'async',
  '{"max_attempts":2,"backoff":"linear","base_ms":2000}',
  FALSE),

(NULL, 'pledge_due_soon_reminder', 'Plan reminder for pledges due soon',
  'pledge.due_soon',
  '{">=":[{"var":"days_until_due"},0]}',
  'pledge_followup_planner',
  '{"pledge_id":"$.pledge_id"}',
  'async',
  '{"max_attempts":3,"backoff":"exponential","base_ms":2000}',
  FALSE);

-- Workflow definitions (5 platform workflows)
INSERT INTO ai.workflow_definitions (code, version, display_name, initial_state, terminal_states, states_json, skill_bindings, status) VALUES
('dik_valuation', '1.0.0', 'DIK Valuation', 'gathering',
  ARRAY['completed','cancelled'],
  '{"states":["gathering","estimating","confirming","writing","completed"],"transitions":[...]}',
  '{"gathering":"dik_intake_assistant","estimating":"dik_valuation_assistant",...}',
  'published'),

('duplicate_donor_resolve', '1.0.0', 'Duplicate Donor Resolve', 'listing_candidates',
  ARRAY['merged','rejected','cancelled'],
  '{"states":["listing_candidates","scoring","reviewing","merging"]}',
  '{"listing_candidates":"duplicate_donor_resolver",...}',
  'published'),

-- (3 more: acknowledgement_flow, pledge_followup_cadence, case_triage)
;

-- Mark write tools (existing rows in tools_registry get is_write=TRUE)
UPDATE ai.tools_registry SET is_write = TRUE WHERE code IN (
  'queue_email_for_review','draft_acknowledgement','schedule_followup','update_donor_note','create_task'
);
```

---

## 5. Backend Project Layout — Phase 3 Deltas

```
Aida.Domain/Entities/
├── Hook.cs                          [NEW]
├── HookExecution.cs                 [NEW]
├── ApprovalQueueItem.cs             [NEW]
├── WorkflowDefinition.cs            [NEW]
├── WorkflowState.cs                 [NEW]
├── AgentRun.cs                      [NEW]
├── AgentTrace.cs                    [NEW]
├── TenantBlockTopic.cs              [NEW]
└── TenantToolAutoApprove.cs         [NEW]

Aida.Application/
├── Agents/
│   ├── IAgent.cs                    [NEW]
│   ├── PlannerAgent.cs              [NEW]
│   ├── ExecutorAgent.cs             [NEW]
│   ├── ValidatorAgent.cs            [NEW]
│   ├── ComplianceAgent.cs           [NEW]
│   ├── CriticAgent.cs               [MOVE from Phase 2]
│   ├── Blackboard.cs                [NEW]
│   ├── StepBudgetEnforcer.cs        [NEW]
│   └── CancellationPropagator.cs    [NEW]
├── Hooks/
│   ├── IEventConsumer.cs            [NEW]
│   ├── HooksDispatcher.cs           [NEW]
│   ├── HookExecutionEngine.cs       [NEW]
│   ├── EventEnvelope.cs             [NEW]
│   ├── JsonLogicEvaluator.cs        [NEW]
│   └── IdempotencyGuard.cs          [NEW]
├── Approvals/
│   ├── IApprovalQueue.cs            [NEW]
│   ├── ApprovalHandler.cs           [NEW]
│   ├── AutoApprovePolicy.cs         [NEW]
│   └── ApprovalExpiryJob.cs         [NEW]
├── Tools/                           [EXTENDED]
│   ├── WriteToolExecutor.cs         [NEW]
│   └── PSS/
│       ├── QueueEmailForReview.cs   [NEW]
│       ├── DraftAcknowledgement.cs  [NEW]
│       ├── ScheduleFollowup.cs      [NEW]
│       ├── UpdateDonorNote.cs       [NEW]
│       └── CreateTask.cs            [NEW]
├── Workflows/
│   ├── IWorkflow.cs                 [NEW]
│   ├── WorkflowEngine.cs            [NEW]
│   ├── WorkflowStateRepository.cs   [NEW]
│   └── Definitions/
│       ├── DikValuationWorkflow.cs  [NEW]
│       ├── DuplicateDonorResolveWorkflow.cs [NEW]
│       ├── AcknowledgementFlowWorkflow.cs   [NEW]
│       ├── PledgeFollowupCadenceWorkflow.cs [NEW]
│       └── CaseTriageWorkflow.cs    [NEW]
└── Compliance/
    └── TenantBlockTopicsService.cs  [NEW]

Aida.Infrastructure/
├── MessageBus/                      [NEW]
│   ├── RabbitMqConsumer.cs (or ServiceBusConsumer.cs)
│   ├── RabbitMqPublisher.cs
│   └── DeadLetterHandler.cs
├── Persistence/Configurations/      [+10 new IEntityTypeConfiguration<T>]
└── BackgroundJobs/
    ├── ApprovalExpiryScheduler.cs   [NEW]
    └── WorkflowExpiryScheduler.cs   [NEW]

Aida.Api/Controllers/
├── HooksController.cs               [NEW]
├── ApprovalsController.cs           [NEW]
├── WorkflowsController.cs           [NEW]
└── AgentTracesController.cs         [NEW]
```

---

## 6. Frontend Project Layout — Phase 3 Deltas

```
src/components/ai/
├── ApprovalQueue/                   [NEW]
│   ├── ApprovalQueuePage.tsx
│   ├── PendingItemCard.tsx
│   ├── ProposedPreview.tsx          ← e.g., email subject + body
│   ├── ApproveRejectButtons.tsx
│   ├── EditArgsModal.tsx
│   └── BulkActionsBar.tsx
├── Hooks/                           [NEW]
│   ├── HooksManager.tsx             ← admin
│   ├── HookCard.tsx
│   ├── HookEditor.tsx
│   ├── HookConditionBuilder.tsx     ← visual JsonLogic builder
│   └── HookExecutionHistory.tsx
├── Workflows/                       [NEW]
│   ├── WorkflowPanel.tsx
│   ├── WorkflowStateBadge.tsx
│   ├── ResumeWorkflowButton.tsx
│   └── WorkflowTimeline.tsx
├── AgentTrace/                      [NEW]
│   ├── AgentTraceViewer.tsx
│   └── StepCard.tsx
└── AutoApproveSettings/             [NEW]
    └── ToolAutoApproveTab.tsx

src/app/[lang]/aida/                 [EXTENDED]
├── approvals/page.tsx               [NEW]
├── hooks/page.tsx                   [NEW]
├── workflows/[instanceId]/page.tsx  [NEW]
└── admin/hooks/page.tsx             [NEW]

src/features/ai/
├── approvals/                       [NEW]
├── hooks/                           [NEW]
└── workflows/                       [NEW]
```

---

## 7. API Surface — what Phase 3 adds

```
# Hooks (admin)
GET    /ai/admin/hooks                        # list per tenant
POST   /ai/admin/hooks                        # create custom hook
PATCH  /ai/admin/hooks/:id/enable             # toggle
PUT    /ai/admin/hooks/:id                    # update condition/args
DELETE /ai/admin/hooks/:id
GET    /ai/admin/hooks/:id/executions         # history

# Approvals
GET    /ai/approvals                          # pending for current user/tenant
GET    /ai/approvals/:id
POST   /ai/approvals/:id/approve              # body: optional edited args
POST   /ai/approvals/:id/reject               # body: reason
POST   /ai/approvals/bulk/approve

# Auto-approve (admin)
GET    /ai/admin/auto-approve
PUT    /ai/admin/auto-approve/:tool_code      # body: enabled, daily_limit, guardrails

# Workflows
GET    /ai/workflows                          # active instances for user
GET    /ai/workflows/:instanceId
POST   /ai/workflows                          # start
POST   /ai/workflows/:instanceId/resume
POST   /ai/workflows/:instanceId/cancel
GET    /ai/admin/workflow-definitions         # list available

# Agent traces (debugging / transparency)
GET    /ai/sessions/:id/agent-runs            # list runs in session
GET    /ai/agent-runs/:runId/traces           # step-by-step

# Block topics (compliance admin)
GET    /ai/admin/block-topics
POST   /ai/admin/block-topics
DELETE /ai/admin/block-topics/:topic_code
```

---

## 8. Phase 3 Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| AI auto-approves something it shouldn't | Med | **Critical** | Auto-approve OFF by default; explicit per-tool tenant sign-off; daily limits; guardrails JSON (e.g., max amount); rate limiter |
| Hook payload contains PII that ends up in LLM | Med | High | Hook payload `payload_summary` is structure-only by default; full payload only when explicitly needed and PII-masked |
| Hook storm (mass-import triggers thousands of events) | Med | Med | Per-tenant per-hook rate limiter; batch detection in event consumer; throttle if > N/min |
| Agent loop infinite-loops despite step budget | Low | Med | Step budget enforced unconditionally; circuit breaker per (skill, tenant) on completion-rate drop |
| Workflow stuck mid-state, blocks user | Med | Low | Auto-expire at 30 days; admin force-archive; resumable from history; user sees current state |
| Compliance refusal cascade — blocks too much | Med | Med | Each block logged; tenant admin reviews block-topic list; refusal templates editable |
| Approval queue overwhelms users | Med | Low | Bulk-approve; smart grouping; auto-approve once tenant trusts a tool |
| Idempotency dedupe fails under partition | Low | Med | Redis SET keyed by `(event_id, hook_id)`; on Redis failure, defer to consumer's at-least-once + DB unique constraint |
| Cross-session blackboard leak | Low | **Critical** | Blackboard keyed by `(company_id, session_id, turn_id)`; cross-tenant test in CI |
| Tool execution after approval succeeds, but downstream PSS write fails | Med | Med | Approval queue records both stages; rollback impossible (already approved); audit clearly shows partial completion + alert |
| Hook circular trigger (hook output emits an event matching another hook) | Med | Med | `causation_id` chain on every event; loop detector blocks 3rd+ hop in chain |
| Write-tool tenant onboarding friction | Med | Med | Self-serve admin UI with explicit "I understand this will execute changes" toggle; one-page contract |

---

## 9. Definition of Ready — Sprint 11 can start when

- [ ] Phase 2 GA review passed
- [ ] RabbitMQ (or Service Bus) provisioned, AIDA bound
- [ ] PSS Core team commits to publishing events for Donation/Pledge/Case/FxRate/DIK (Sprint 13 prereq)
- [ ] Pilot tenants for Phase 3 confirmed (likely overlap with Phase 2 pilots)
- [ ] Approval queue UX wireframes approved by 2 pilot admins (do this in W19–W20)
- [ ] Compliance review for write-tools posture signed
- [ ] DLQ + alerts pre-configured

---

## 10. Decision Points During Phase 3

| Week | Decision |
|---|---|
| W22 (end S11) | Planner accuracy ≥ 85% on 50-sample eval? If not, tune before Sprint 12 |
| W24 (end S12) | Validator catching ≥ 95% of malformed outputs? Adjust thresholds if too strict |
| W26 (end S13) | Hook execution stable at scale? Adjust queue concurrency / DLQ policy |
| W28 (end S14) | Approval queue UX working for pilot admins? Tune before write-tool GA |
| W30 (end S15) | Workflow completion rate ≥ 70% on pilot? If not, simplify state machines |
| W32 (end S16) | GA decision: ship Phase 3 to all tenants OR extend pilot OR adjust scope |

---

## 11. What Phase 3 enables for Phase 4

By Phase 3 GA, the substrate is mature enough for tenant-driven extension:
- **Custom skills** (tenant-private) just need a manifest editor UI (Phase 4 Sprint 17)
- **Custom hooks** can already be tenant-created via REST — needs the visual builder UI
- **Custom workflows** need a definition editor + state-machine validator
- **Fine-tuned models** plug into the provider gateway via a new adapter

Phase 4 plan: `Implementation-Plan-Phase-4.md`.

---

*— End of Phase 3 plan —*
