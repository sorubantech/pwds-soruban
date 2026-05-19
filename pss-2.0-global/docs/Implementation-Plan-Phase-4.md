# PSS 2.0 AIDA — Phase 4 Implementation Plan

## Platformization: Tenant-private Skills · Persona Builder · Multimodal · Fine-tuning · Local LLM · Marketplace

> **Companion to** previous phase plans.
> **Plans** the 20 weeks (10 sprints) following Phase 3 GA.
> **Status:** Strategic intent. Higher uncertainty than earlier phases. Decisions in §1 will be **re-confirmed at end of Phase 3 (W32)**; sprint scope may swap based on tenant demand.
> **Spirit:** Phase 4 is where AIDA stops being a *product feature* and becomes a *platform*. Lower velocity on net-new capabilities, higher velocity on enabling tenants to extend.

---

## 1. Locked Decisions (provisional — confirm at W32)

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | **Custom skill authoring** | Low-code skill manifest editor + live-eval preview | YAML-style manifest + visual prompt editor + paste-test-set + run-eval flow. Power users only (gated capability). |
| 2 | **Custom persona** | Visual persona builder; tenant can override platform personas | Builds on Phase 2 persona infrastructure. |
| 3 | **Fine-tuning** | OFFER, not default. Per-tenant fine-tunes on tenant's own data | Sold as enterprise add-on. Most tenants won't need it. |
| 4 | **Multimodal scope** | Vision only (receipts, donation forms, signatures) — no audio/video in Phase 4 | Concrete NGO use cases: scan a paper donation form, OCR a receipt. Audio is Phase 5. |
| 5 | **Local LLM** | Llama 3.1 70B as the default local; opt-in deployment per tenant | For regulated tenants. New `LocalAdapter` in provider gateway. |
| 6 | **Marketplace** | Internal first (Sorubаn-curated catalog of skills/workflows tenants can adopt). External marketplace deferred to Phase 5 | Reduces governance burden. |
| 7 | ⚠️ **Self-serve fine-tune UI** | NO — fine-tuning is concierge service in Phase 4 | UI is heavy; concierge serves the few tenants who actually need it. |
| 8 | ⚠️ **Federated knowledge** | Defer to Phase 5 | Cross-tenant cooperation introduces consent & data-sharing complexity. |
| 9 | **Backwards compatibility** | All Phase 0–3 APIs remain stable; Phase 4 adds new ones | No breaking changes. |
| 10 | **Phase 4 cadence** | Slower: 2-week sprints, but each may ship independently. Sprints **don't need to land sequentially** | Phase 4 is a portfolio of independent capability adds. |

---

## 2. Scope Map — what ships in Phase 4

```
┌──────────────────────────────────────────────────────────────────┐
│  PHASE 4  ·  PLATFORMIZATION  ·  Weeks 33–52  (20 wks, 10 sprints)│
│  ────────────────────────────────────────────                     │
│  Track A: Tenant Self-serve                                       │
│    Sprint 17 (W33–34)  Custom skill authoring                     │
│    Sprint 18 (W35–36)  Custom prompt editor + eval runner UI      │
│    Sprint 19 (W37–38)  Custom persona builder                     │
│    Sprint 20 (W39–40)  Custom hook & workflow editors             │
│                                                                   │
│  Track B: Multimodal + Local LLM                                  │
│    Sprint 21 (W41–42)  Vision adapter (receipts, KYC)             │
│    Sprint 22 (W43–44)  Local LLM adapter + isolated deployment    │
│                                                                   │
│  Track C: Marketplace & Fine-tuning                               │
│    Sprint 23 (W45–46)  Internal skill marketplace catalog         │
│    Sprint 24 (W47–48)  Fine-tuning pipeline (concierge)           │
│                                                                   │
│  Track D: Hardening + Optionality                                 │
│    Sprint 25 (W49–50)  Tenant-isolated infra option (carve-out)   │
│    Sprint 26 (W51–52)  Platform polish + Phase 5 planning         │
│                                                                   │
│  Tracks can run in parallel; sequencing is flexible.              │
└──────────────────────────────────────────────────────────────────┘
```

**Phase 4 explicitly does NOT include:** federated cross-tenant knowledge, voice/audio modalities, third-party marketplace, automatic per-tenant fine-tuning at scale, real-time stream processing of external feeds. All Phase 5+.

---

## 3. Phase 4 Sprint Plan

### Track A — Tenant Self-serve

#### 3.1 Sprint 17 (W33–W34) — Custom Skill Authoring

**Goal:** A power user in a tenant can create, test, and publish a private skill without writing code.

| Story | Owner | Acceptance |
|---|---|---|
| `ai.skills` extended to support `visibility='tenant_private'` properly (already exists; now UI surfaces it) | BE | Tenant-private skills only callable from same tenant; CrossTenantLeakTests cover |
| Skill manifest editor — form UI mapped to `manifest` JSONB schema | FE | Form fields generated from JSON Schema; live JSON preview |
| Prompt body editor — markdown + variable autocomplete (declared variables from manifest) | FE | Variable suggestions on `{{ ... }}`; syntax-highlighted |
| Skill workspace: draft → test → approve → publish workflow | BE + FE | State machine enforced; only `BUSINESSADMIN` can publish |
| Test-runner: paste 5–20 sample inputs → run against current draft → see outputs side-by-side | FE | Diff view: expected vs actual; cost + latency shown |
| Eval-set linking: a skill draft can attach an eval set (JSON file uploaded); CI runs on every save | BE | Eval set saved as `ai.eval_sets` rows; runs via `EvalSetRunner` from Phase 2 |
| Skill clone-from-platform: a tenant can fork a platform skill, edit prompt, save as tenant-private | BE + FE | Forked skill carries `parent_skill_id`; updates to platform skill do NOT auto-propagate |
| New capability `ai.skill.author` — required to create/edit; separate from `ai.config.manage` | BE | RBAC enforced |
| Audit: every skill draft save + publish logged | BE | Audit rows in `ai.audit_log` with `skill_code` + new field `action='skill_authored'` |
| Help center: "Authoring a skill for your team" (with video) | Product | Published |

**Sprint 17 DoD:**
- 2 pilot tenants have authored ≥ 1 tenant-private skill each.
- Skill goes through full lifecycle: draft → eval-pass → approve → publish → used in chat.

#### 3.2 Sprint 18 (W35–W36) — Custom Prompt Editor + Eval Runner UI

| Story | Owner | Acceptance |
|---|---|---|
| Prompt editor on existing platform skills (tenant overrides) — already in DB; now full UI | FE | List tenants' overrides; edit, version, publish |
| A/B test UI: tenant can split traffic between prompt version A and B | FE + BE | Backend already supports A/B; UI surfaces it |
| Eval runner dashboard — `ai.eval_results` browser, trend over time per skill | FE | Pass rate trendline; per-question pass/fail detail; cost trend |
| Compare eval runs — "this version vs last version" diff | FE | Side-by-side per-question diff |
| Auto-rollback rule: if a published prompt's eval pass rate drops > 10% vs prior version, auto-rollback after 24h | BE | Hangfire job; alert before rollback |
| Prompt sharing within tenant: a power user's draft can be reviewed by another power user before publish | BE + FE | Review workflow with comments |
| Prompt versions cleanup: archived versions > 90 days auto-purged (DDL retained, body cleared) | BE | Hangfire job |

**Sprint 18 DoD:**
- A tenant power user can override any platform skill's prompt, A/B test it, and roll back from UI.
- Eval runner shows trends for both platform skills and tenant overrides.

#### 3.3 Sprint 19 (W37–W38) — Custom Persona Builder

| Story | Owner | Acceptance |
|---|---|---|
| Persona builder UI — fork a platform persona OR start blank | FE | All fields editable (prefix, style guide, default model class, temperature, citation style) |
| Persona preview — type a sample question, see response in this persona | FE | Real LLM call cost-tracked; cached |
| Persona library — tenant can save multiple personas, switch per user OR per skill | BE | `ai.user_preferences.preferred_persona_code` already exists; UI now surfaces it |
| Per-skill persona override — a tenant can set "use Perplexity-style for reporting skills, Claude-style for chat" | BE | New JSONB on `ai.tenant_skills.config_json.persona_override` |
| Persona governance — admin can lock the tenant default and prevent per-user override | BE | New `ai.tenant_config.persona_lock_user_override` |
| Persona import/export — JSON file; signed by source tenant | BE + FE | Validates structure; warns if persona uses unavailable model class |

**Sprint 19 DoD:**
- A tenant can build a persona named "Our Charity Voice" and have all chat skills use it by default.

#### 3.4 Sprint 20 (W39–W40) — Custom Hook & Workflow Editors

| Story | Owner | Acceptance |
|---|---|---|
| Hook editor — visual condition builder over JsonLogic | FE | Drag-drop AND/OR/Comparison nodes; live preview against sample event payload |
| Hook eval against historical events — pick a past event, see what the hook would have done | BE + FE | Read past 30 days of `ai.audit_log` events, replay through hook |
| Custom hook publishing — tenant-private hook becomes active on configured event | BE | Same enable/disable as platform hooks |
| Workflow definition editor — visual state-machine builder | FE | Drag-drop states + transitions; skill binding dropdown; export as JSON |
| Workflow eval — start a test instance with synthetic input, step through states | BE + FE | Each state callable in isolation; full instance run also possible |
| Workflow + Hook combo: a tenant-custom hook can start a tenant-custom workflow | BE | Manifest validation enforces |
| Capability: `ai.hook.author`, `ai.workflow.author` | BE | RBAC enforced |

**Sprint 20 / Track A DoD:**
- A tenant can: create a custom skill, override prompts, create a persona, define a hook + workflow — all without engineering involvement.

### Track B — Multimodal + Local LLM

#### 3.5 Sprint 21 (W41–W42) — Vision Adapter

| Story | Owner | Acceptance |
|---|---|---|
| Vision-capable model class `vision` (already in seed; Phase 2 didn't use it) | BE | `model_class_map` already supports it |
| `IMultiModalClient` interface — extends `IModelClient` with image input | BE | Implemented for Claude Sonnet + GPT-4o |
| Image attachment storage — leverage existing PSS file store (S3/Azure Blob); referenced by URL in messages | BE | Test: image uploaded → URL referenced in chat → LLM receives it |
| First vision skill: `receipt_ocr_extractor` — image of receipt → structured fields (donor, amount, date, fund) | Prompt Eng + BE | 30-sample eval: 90% accuracy on legible receipts, 60% on poor quality |
| Second vision skill: `paper_form_to_donation` — image of paper donation form → draft Donation entity with HITL approval | Prompt Eng + BE | Demoable with 10 sample forms |
| Composer: image upload button; client-side image compression to < 2MB | FE | Multiple images per message supported |
| Cost surfacing: image tokens (Claude/GPT charge per image) tracked in `ai.audit_log` | BE | Visible in admin usage view |
| Privacy: images opt-out per tenant; image storage retention configurable | BE | `ai.tenant_config.image_retention_days` |

**Sprint 21 DoD:**
- 2 pilot tenants using `receipt_ocr_extractor` for ≥ 50 receipts each.

#### 3.6 Sprint 22 (W43–W44) — Local LLM Adapter

| Story | Owner | Acceptance |
|---|---|---|
| `LocalLlamaAdapter` implementing `IModelClient` against vLLM-served Llama 3.1 70B | BE + DevOps | Health endpoint; streaming works; tool calls via JSON mode |
| GPU node pool in K8s (or cloud GPU instances) — node-affinity for `LocalLlamaAdapter` pods | DevOps | Capacity tested for 5 concurrent requests at acceptable latency |
| Provider rows: `local-llama-70b` added to `ai.providers` | BE | Seed migration |
| Model-class entries: `reasoning_mid_local`, `reasoning_fast_local` (Llama 8B for fast) | BE | `ai.model_class_map` rows added |
| Per-tenant routing: tenant can pin a class to local-only — provider gateway respects, refuses fallback to cloud | BE | Test: tenant with `local-only=true` + local down → graceful error, NOT fallback to cloud |
| Compliance label on responses: when local-LLM-served, response carries metadata `served_by: local` | BE + FE | UI shows badge |
| Performance: Llama 70B P95 ≤ 8s on standard GPU node | BE + DevOps | Load test |
| Quality regression check: 100-question eval set — local vs cloud accuracy gap measured | QA + Prompt Eng | Gap published; tenants choose with eyes open |
| First regulated-tenant onboarding: tenant data residency = local-only, all skills work | CS | Onboarded |

**Sprint 22 / Track B DoD:**
- Vision skills live in 2 tenants.
- Local LLM serving 1 regulated tenant end-to-end.
- Provider gateway transparently swaps between cloud/local based on tenant config.

### Track C — Marketplace & Fine-tuning

#### 3.7 Sprint 23 (W45–W46) — Internal Skill Marketplace

| Story | Owner | Acceptance |
|---|---|---|
| Marketplace catalog — curated set of `visibility='shared'` skills/workflows that any tenant can adopt | BE | Existing schema supports it |
| Catalog UI — browse, filter (category, cost class, ratings), preview, adopt | FE | Tenants see ratings + adoption count |
| Adoption flow — adopt = clone into tenant-private namespace + auto-enable | BE | Clones manifest, prompt, eval set; tenant can edit clone freely |
| Catalog rating + usage telemetry — tenants rate adopted skills; aggregate visible | BE + FE | Privacy: usage metrics aggregated, not tenant-attributed |
| Source-of-truth for marketplace — `ai.marketplace_skills` view over `ai.skills` with `visibility='shared'` + curation flag | BE | View created; admin curation UI |
| Marketplace skill update notifications — when a shared skill is updated, adopters see "Update available" | FE | One-click upgrade with diff preview |
| Initial catalog seed: 10 curated skills (the platform skills + 5 highly-requested patterns from pilot tenants) | Prompt Eng + Product | Catalog populated |
| Help center: "Marketplace: adopt vs author" | Product | Published |

**Sprint 23 DoD:**
- 10-skill catalog live.
- ≥ 5 pilot tenants adopted ≥ 1 marketplace skill each.

#### 3.8 Sprint 24 (W47–W48) — Fine-tuning Pipeline (Concierge)

| Story | Owner | Acceptance |
|---|---|---|
| `ai.fine_tune_jobs` table + lifecycle (`requested → data_prepared → training → ready → deployed → archived`) | BE | DDL applied |
| Data preparation pipeline: extract tenant's chat sessions + ratings → training pairs (prompt, response, label) → validation set | BE | Pipeline produces `train.jsonl` + `val.jsonl` per spec |
| Fine-tuning runner — wraps Anthropic / OpenAI fine-tune APIs (whichever supports per-tenant tuning) | BE | E2E run on 1 dataset |
| Fine-tuned model registered as new `model_class_map` row with tenant-specific filter | BE | Only the tenant's class lookup returns this model |
| Tenant model card UI: shows base model, training data range, eval scores, last refresh | FE | Cards visible in admin |
| Refresh cadence — manual trigger; quarterly auto-suggest based on drift | BE | Hangfire job |
| Cost transparency — fine-tune cost surfaced; ongoing per-call cost may be higher than base | BE | Visible to admin |
| Operational: fine-tune jobs run async, no SLA on completion (can take days) | BE | Admin UI shows estimated completion |
| First concierge engagement — 1 tenant fine-tunes their `donor_summary` skill on their own donor history | CS + Eng | Delivered end-to-end |

**Sprint 24 / Track C DoD:**
- Marketplace live; ≥ 1 tenant adopted.
- ≥ 1 fine-tuned model deployed and serving traffic.

### Track D — Hardening & Optionality

#### 3.9 Sprint 25 (W49–W50) — Tenant-isolated Infra Option

| Story | Owner | Acceptance |
|---|---|---|
| Isolated deployment mode — for very-regulated tenants, AIDA runs in tenant-dedicated namespace with tenant-owned KMS | DevOps + BE | Tooling: `aida-isolate-tenant` script; documented runbook |
| Tenant DB carve-out — per-tenant Postgres schema OR separate Postgres (config switch) | BE + DevOps | Migration script tested with synthetic tenant |
| Tenant network egress whitelisting — outbound only to declared LLM endpoints (per-tenant config) | DevOps | Tested with iptables rules in dev |
| Tenant audit export — daily encrypted dump of tenant audit log to tenant-controlled S3/bucket | BE | Configurable; test export |
| SLA differentiation — isolated tenants get separate health monitors and on-call routing | DevOps | Pagerduty routing rules |
| Marketing one-pager: "AIDA Isolated Cloud" for enterprise sales | Product + CS | Document published |

**Sprint 25 DoD:**
- Tooling exists to spin up an isolated AIDA stack for a single tenant.
- 1 customer (real or simulated) successfully onboarded into isolated mode.

#### 3.10 Sprint 26 (W51–W52) — Platform Polish + Phase 5 Planning

| Story | Owner | Acceptance |
|---|---|---|
| Performance audit — top 5 latency hotspots fixed | BE | P95 metrics improved by ≥ 20% on baseline |
| Cost audit — top 5 cost drivers per tenant identified; optimization recs published | BE + Product | Per-tenant cost reduction recommendations |
| Documentation pass — all admin features documented with screenshots | Product + Tech writer | Help center updated |
| Internal training — engineering, CS, sales trained on full AIDA platform | Product | Recorded session |
| Phase 5 planning workshop — themes, candidate features, pilot interview synthesis | Product + Eng Lead | `Implementation-Plan-Phase-5.md` skeleton |
| Retro: full-year AIDA retrospective (W1–W52 outcomes vs plan) | Eng Lead | Written retrospective; shared org-wide |
| GA: all Phase 4 capabilities default-enabled for all tenants who opt in | Product + CS | Announcement post |

**Sprint 26 / Phase 4 DoD:**
- All tracks A–D shipped to GA OR explicitly deferred with rationale.
- ≥ 50% of tenants using ≥ 1 Phase 4 capability (custom skill, persona, hook, or marketplace adoption).
- Year-end retrospective complete.

---

## 4. Database Design — Phase 4 Additions

```sql
-- ─────────────────────── ai.persona_overrides ───────────────────────
-- Tenant-built personas. References ai.personas with parent_persona_id when forked.
-- Already covered by ai.personas with owner_company_id != NULL.
-- This table adds tenant-level constraints + per-user assignment.
CREATE TABLE ai.persona_assignments (
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  user_id                BIGINT,                      -- NULL = tenant default
  skill_code             VARCHAR(100),                -- NULL = applies to all skills
  persona_code           VARCHAR(50) NOT NULL,
  is_locked              BOOLEAN NOT NULL DEFAULT FALSE,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (company_id, user_id, skill_code, persona_code)
);

-- ─────────────────────── ai.eval_sets ───────────────────────
-- Eval sets — JSON files of test inputs + expected outputs (or rubric).
CREATE TABLE ai.eval_sets (
  eval_set_id            BIGSERIAL PRIMARY KEY,
  code                   VARCHAR(100) NOT NULL,
  version                VARCHAR(20) NOT NULL,
  company_id             BIGINT REFERENCES companies(company_id),  -- NULL = platform
  skill_code             VARCHAR(100),
  description            TEXT,
  questions_json         JSONB NOT NULL,              -- array of { input, expected, criteria }
  question_count         INT NOT NULL,
  pass_threshold_pct     INT NOT NULL DEFAULT 90,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by             BIGINT NOT NULL,
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (code, version, company_id)
);

-- ─────────────────────── ai.marketplace_items ───────────────────────
-- A flat catalog over shared skills + workflows for the marketplace UI.
-- Materializes from ai.skills WHERE visibility='shared'.
CREATE TABLE ai.marketplace_items (
  item_id                BIGSERIAL PRIMARY KEY,
  item_type              VARCHAR(20) NOT NULL,         -- 'skill'|'workflow'|'persona'
  source_id              BIGINT NOT NULL,              -- FK to ai.skills/ai.workflow_definitions/ai.personas
  display_name           VARCHAR(200) NOT NULL,
  short_description      TEXT NOT NULL,
  long_description       TEXT,
  category               VARCHAR(50),                  -- 'fundraising'|'communication'|'reporting'|'compliance'|...
  cost_class             VARCHAR(20),
  cover_image_url        TEXT,
  is_curated             BOOLEAN NOT NULL DEFAULT FALSE,
  is_featured            BOOLEAN NOT NULL DEFAULT FALSE,
  adoption_count         INT NOT NULL DEFAULT 0,
  avg_rating             NUMERIC(3,2),
  rating_count           INT NOT NULL DEFAULT 0,
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  modified_date          TIMESTAMPTZ
);

CREATE TABLE ai.marketplace_adoptions (
  adoption_id            BIGSERIAL PRIMARY KEY,
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  item_id                BIGINT NOT NULL REFERENCES ai.marketplace_items(item_id),
  cloned_into_id         BIGINT NOT NULL,              -- the new tenant-private skill/workflow id
  rating                 INT,                          -- 1-5
  review                 TEXT,
  adopted_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  unadopted_date         TIMESTAMPTZ,
  UNIQUE (company_id, item_id)
);

-- ─────────────────────── ai.fine_tune_jobs ───────────────────────
CREATE TABLE ai.fine_tune_jobs (
  job_id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id             BIGINT NOT NULL REFERENCES companies(company_id),
  skill_code             VARCHAR(100),                 -- which skill is being tuned
  base_model_id          VARCHAR(100) NOT NULL,
  fine_tuned_model_id    VARCHAR(100),                 -- assigned when complete
  status                 VARCHAR(30) NOT NULL,         -- 'requested'|'data_prepared'|'training'|'ready'|'deployed'|'failed'|'archived'
  data_source            VARCHAR(50),                  -- 'tenant_sessions'|'tenant_uploads'|'custom'
  data_period_start      DATE,
  data_period_end        DATE,
  training_sample_count  INT,
  validation_sample_count INT,
  training_cost_usd      NUMERIC(10,2),
  hyperparameters        JSONB,
  eval_baseline          JSONB,                        -- before/after metrics
  provider_job_id        VARCHAR(100),                 -- vendor's job ID
  error_message          TEXT,
  requested_date         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_date           TIMESTAMPTZ,
  completed_date         TIMESTAMPTZ,
  deployed_date          TIMESTAMPTZ,
  archived_date          TIMESTAMPTZ
);
CREATE INDEX ix_ft_company_status ON ai.fine_tune_jobs(company_id, status);

-- ─────────────────────── ai.tenant_deployments ───────────────────────
-- Tracks tenants that are on isolated infrastructure.
CREATE TABLE ai.tenant_deployments (
  company_id             BIGINT PRIMARY KEY REFERENCES companies(company_id),
  deployment_mode        VARCHAR(20) NOT NULL,         -- 'shared'|'isolated_namespace'|'isolated_db'|'isolated_cluster'
  namespace              VARCHAR(100),
  database_name          VARCHAR(100),
  cluster_name           VARCHAR(100),
  kms_endpoint           VARCHAR(500),                 -- tenant-controlled KMS for keys
  egress_whitelist       TEXT[],
  audit_export_target    VARCHAR(500),                 -- e.g., 's3://tenant-x-audit/'
  sla_tier               VARCHAR(20),                  -- 'standard'|'premium'|'enterprise'
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  modified_date          TIMESTAMPTZ
);

-- ─────────────────────── ai.image_attachments ───────────────────────
-- Image attachments to chat messages (and hook payloads).
CREATE TABLE ai.image_attachments (
  attachment_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id             BIGINT NOT NULL,
  message_id             BIGINT REFERENCES ai.chat_messages(message_id),
  storage_url            TEXT NOT NULL,                -- S3/Blob URL
  filename               VARCHAR(500),
  mime_type              VARCHAR(100),
  size_bytes             INT,
  width                  INT,
  height                 INT,
  uploaded_by_user_id    BIGINT,
  uploaded_date          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_date           TIMESTAMPTZ,                  -- per tenant retention
  is_deleted             BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX ix_img_message ON ai.image_attachments(message_id);
CREATE INDEX ix_img_expiry ON ai.image_attachments(expires_date) WHERE is_deleted = FALSE;

-- ─────────────────────── ai.skill_authoring_drafts ───────────────────────
-- Live drafts during skill authoring; auto-saved.
CREATE TABLE ai.skill_authoring_drafts (
  draft_id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id             BIGINT NOT NULL,
  user_id                BIGINT NOT NULL,
  draft_name             VARCHAR(200) NOT NULL,
  draft_manifest         JSONB,
  draft_prompt           TEXT,
  parent_skill_id        BIGINT REFERENCES ai.skills(skill_id),  -- if forked
  status                 VARCHAR(20) NOT NULL DEFAULT 'in_progress',  -- 'in_progress'|'testing'|'submitted_for_review'|'rejected'|'published'
  modified_date          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_date           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ix_sad_user ON ai.skill_authoring_drafts(company_id, user_id, modified_date DESC);
```

### 4.1 Seed data — Phase 4

```sql
-- Marketplace items (initial catalog)
INSERT INTO ai.marketplace_items (item_type, source_id, display_name, short_description, category, cost_class, is_curated, is_featured) VALUES
('skill', (SELECT skill_id FROM ai.skills WHERE code='donor_summary'),
  'Donor 360', 'One-click donor profile with history and next-best-action suggestion', 'fundraising', 'medium', TRUE, TRUE),
('skill', (SELECT skill_id FROM ai.skills WHERE code='campaign_performance_explainer'),
  'Campaign Doctor', 'Why is my campaign underperforming? AI explains.', 'fundraising', 'medium', TRUE, TRUE),
-- ... 8 more entries
;

-- Vision provider rows (Phase 4 Sprint 21)
INSERT INTO ai.model_class_map (class_code, provider_id, model_id, priority, cost_in_per_mtok, cost_out_per_mtok, context_window) VALUES
('vision', (SELECT provider_id FROM ai.providers WHERE code='anthropic'), 'claude-sonnet-4-6', 1, 3.0, 15.0, 200000),
('vision', (SELECT provider_id FROM ai.providers WHERE code='openai'),    'gpt-4o',           2, 5.0, 15.0, 128000);

-- Local LLM provider (Phase 4 Sprint 22)
INSERT INTO ai.providers (code, display_name, base_url, capabilities, auth_mode) VALUES
('local-llama', 'Local Llama (vLLM)', 'http://aida-llama.pss-aida.svc.cluster.local:8000', '{"chat":true,"tools":true}', 'iam');

INSERT INTO ai.model_class_map (class_code, provider_id, model_id, priority, cost_in_per_mtok, cost_out_per_mtok, context_window) VALUES
('reasoning_mid_local',  (SELECT provider_id FROM ai.providers WHERE code='local-llama'), 'llama-3.1-70b-instruct', 1, 0, 0, 128000),
('reasoning_fast_local', (SELECT provider_id FROM ai.providers WHERE code='local-llama'), 'llama-3.1-8b-instruct',  1, 0, 0, 128000);
```

---

## 5. Backend Project Layout — Phase 4 Deltas

```
Aida.Domain/Entities/
├── EvalSet.cs                          [NEW]
├── MarketplaceItem.cs                  [NEW]
├── MarketplaceAdoption.cs              [NEW]
├── FineTuneJob.cs                      [NEW]
├── TenantDeployment.cs                 [NEW]
├── ImageAttachment.cs                  [NEW]
├── SkillAuthoringDraft.cs              [NEW]
└── PersonaAssignment.cs                [NEW]

Aida.Application/
├── SkillAuthoring/                     [NEW]
│   ├── DraftService.cs
│   ├── SkillValidator.cs               ← validates manifest before publish
│   ├── SkillForkService.cs
│   └── SkillTestRunner.cs              ← run draft against sample inputs
├── PromptAuthoring/                    [NEW]
│   ├── PromptOverrideService.cs
│   ├── AbTestController.cs
│   └── AutoRollbackJob.cs
├── PersonaBuilder/                     [NEW]
│   ├── PersonaForkService.cs
│   └── PersonaPreviewService.cs
├── Marketplace/                        [NEW]
│   ├── MarketplaceCatalogService.cs
│   ├── AdoptionHandler.cs              ← clones into tenant-private namespace
│   └── RatingService.cs
├── FineTune/                           [NEW]
│   ├── DataPreparationService.cs
│   ├── FineTuneRunner.cs               ← wraps Anthropic/OpenAI fine-tune APIs
│   ├── FineTuneJobLifecycle.cs
│   └── ModelRegistry.cs
├── MultiModal/                         [NEW]
│   ├── IMultiModalClient.cs
│   ├── ImageAttachmentService.cs
│   ├── ImageCompressionService.cs
│   └── Skills/
│       ├── ReceiptOcrExtractor.cs
│       └── PaperFormToDonation.cs
└── TenantDeployment/                   [NEW]
    ├── IsolationProvisioner.cs
    └── AuditExportJob.cs

Aida.Infrastructure/
├── Providers/                           [EXTENDED]
│   ├── Local/
│   │   └── LocalLlamaAdapter.cs        [NEW] — vLLM client
│   └── Vision/
│       └── (adapters extended)
├── ImageStorage/
│   └── BlobStorageClient.cs            [NEW]
├── FineTune/
│   ├── AnthropicFineTuneClient.cs      [NEW]
│   └── OpenAIFineTuneClient.cs         [NEW]
└── Marketplace/
    └── MarketplaceIndexer.cs           [NEW] — keeps ai.marketplace_items in sync

Aida.Api/Controllers/
├── SkillAuthoringController.cs         [NEW]
├── PromptAuthoringController.cs        [NEW]
├── PersonaBuilderController.cs         [NEW]
├── MarketplaceController.cs            [NEW]
├── FineTuneController.cs               [NEW]
├── ImageAttachmentController.cs        [NEW]
└── TenantDeploymentController.cs       [NEW]
```

---

## 6. Frontend Project Layout — Phase 4 Deltas

```
src/components/ai/
├── SkillAuthoring/                     [NEW]
│   ├── SkillAuthoringPage.tsx
│   ├── ManifestEditor.tsx
│   ├── PromptEditor.tsx                ← markdown + autocomplete
│   ├── TestRunner.tsx
│   ├── EvalAttachment.tsx
│   ├── DiffView.tsx
│   └── PublishWorkflow.tsx
├── PromptAuthoring/                    [NEW]
│   ├── PromptOverridesPage.tsx
│   ├── AbTestController.tsx
│   └── EvalRunnerDashboard.tsx
├── PersonaBuilder/                     [NEW]
│   ├── PersonaBuilderPage.tsx
│   ├── PersonaLibrary.tsx
│   └── PersonaPreviewPane.tsx
├── Marketplace/                        [NEW]
│   ├── MarketplaceCatalog.tsx
│   ├── MarketplaceItemCard.tsx
│   ├── AdoptionDialog.tsx
│   └── RatingWidget.tsx
├── FineTune/                           [NEW]
│   ├── FineTuneJobsList.tsx
│   ├── ModelCard.tsx
│   └── RequestFineTuneDialog.tsx
├── VisionSkills/                       [NEW]
│   ├── ImageUploader.tsx
│   ├── ReceiptViewerWithExtracted.tsx
│   └── PaperFormViewer.tsx
└── TenantDeployment/                   [NEW]
    └── IsolatedDeploymentBadge.tsx

src/app/[lang]/aida/
├── authoring/
│   ├── skills/page.tsx                 [NEW]
│   ├── prompts/page.tsx                [NEW]
│   ├── personas/page.tsx               [NEW]
│   ├── hooks/page.tsx                  [NEW]
│   └── workflows/page.tsx              [NEW]
├── marketplace/page.tsx                [NEW]
└── admin/
    ├── fine-tune/page.tsx              [NEW]
    └── deployment/page.tsx             [NEW]
```

---

## 7. API Surface — what Phase 4 adds

```
# Skill authoring
GET    /ai/authoring/skills/drafts
POST   /ai/authoring/skills/drafts
PATCH  /ai/authoring/skills/drafts/:id
POST   /ai/authoring/skills/drafts/:id/test
POST   /ai/authoring/skills/drafts/:id/submit-for-review
POST   /ai/authoring/skills/drafts/:id/publish
POST   /ai/authoring/skills/fork                 # body: source_skill_id

# Prompt authoring
GET    /ai/authoring/prompts                     # tenant overrides
PUT    /ai/authoring/prompts/:key/override
POST   /ai/authoring/prompts/:key/ab-test/start
POST   /ai/authoring/prompts/:key/ab-test/end    # promote A or B

# Eval sets
GET    /ai/eval-sets
POST   /ai/eval-sets
POST   /ai/eval-sets/:id/run

# Persona
POST   /ai/personas                              # tenant-private create
PUT    /ai/personas/:code/assign                 # body: { user_id?, skill_code?, persona_code, lock? }

# Marketplace
GET    /ai/marketplace                           # browse catalog
GET    /ai/marketplace/:id
POST   /ai/marketplace/:id/adopt
POST   /ai/marketplace/:id/rate                  # body: { rating, review }
DELETE /ai/marketplace/:id/unadopt

# Fine-tune
GET    /ai/admin/fine-tune/jobs
POST   /ai/admin/fine-tune/jobs                  # body: { skill_code, data_source, data_period }
GET    /ai/admin/fine-tune/jobs/:id
POST   /ai/admin/fine-tune/jobs/:id/deploy
POST   /ai/admin/fine-tune/jobs/:id/archive

# Vision
POST   /ai/chat/sessions/:id/messages/attach     # multipart upload, returns attachment_id
DELETE /ai/attachments/:id

# Tenant deployment (super-admin only)
GET    /ai/super-admin/deployments
POST   /ai/super-admin/deployments/:companyId/isolate
POST   /ai/super-admin/deployments/:companyId/audit-export
```

---

## 8. Phase 4 Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Tenant-authored skill produces low-quality output, hurts confidence in AIDA | Med | Med | Mandatory eval set; publish gated on pass rate; clear "tenant-authored" badge in UI |
| Tenant authors a skill that escalates capabilities (calls write tools without HITL) | Low | **Critical** | Manifest validation rejects undeclared tools; capability-required field enforced; security review on all tenant-published skills |
| Marketplace becomes spam / quality decay | Med | Med | Curation gate; only curated items featured; non-curated items show with warnings |
| Fine-tuned model drifts from base — answers become inconsistent | Med | Med | Eval before deploy; periodic refresh; one-click rollback to base |
| Fine-tuning provider deprecates API mid-job | Low | Med | Lifecycle tracks vendor job ID; graceful "vendor unavailable" status; user can retry later |
| Vision skill misreads receipts, drafts wrong donation | Med | High | Always HITL on form-to-donation skill; receipt-OCR alone is informational |
| Image uploaded contains PII / sensitive data + ends up in LLM cache | Med | High | Per-tenant image retention; vendor enterprise contracts cover no-train; warn user before uploading docs |
| Local LLM quality regression invisible to users | Med | Med | Quality gap published per tenant; banner when local model in use; eval re-run on every model change |
| GPU node failure — isolated tenant down with no fallback | Med | Med | Multi-node deployment; for local-only tenants, SLA reflects vulnerability |
| Isolated tenant deployment ops burden | Med | Low (per tenant) but Med (cumulative) | Tooling-first: every isolated tenant managed by same scripts; explicit headcount cost per isolated tenant |
| Custom hook causes infinite event loop | Med | Med | Loop detector from Phase 3 catches; new hooks require dry-run before enable |
| Tenant exports audit log, exposes prompt content they shouldn't see (cross-user within tenant) | Med | Med | Audit export filters per user-scope rules; super-admin export marked |

---

## 9. Definition of Ready — Sprint 17 can start when

- [ ] Phase 3 GA review passed
- [ ] Capability framework supports `ai.skill.author`, `ai.hook.author`, `ai.workflow.author`, `ai.persona.author`
- [ ] Pilot tenants for Phase 4 confirmed (target: 3-5 tenants willing to author + adopt)
- [ ] Storage capacity for tenant-uploaded images allocated
- [ ] GPU node pool capacity planned (for Sprint 22)
- [ ] Fine-tune partner relationships established (Anthropic + OpenAI fine-tune access)

---

## 10. Decision Points During Phase 4

| Week | Decision |
|---|---|
| W34 (end S17) | Tenant authoring viable? If usage < 1 tenant per week, simplify UX before Sprint 18 |
| W40 (end S20) | All Track A complete and adopted by ≥ 2 tenants? If not, hold Track B until they're stable |
| W42 (end S21) | Vision quality acceptable? If poor on Indian receipts, retrain prompts before Sprint 22 |
| W44 (end S22) | Local LLM serves regulated tenant well? If not, defer regulated-tenant onboarding |
| W48 (end S24) | Fine-tune ROI clear? If first fine-tune doesn't show measurable improvement, deprioritize for Phase 5 |
| W52 (end S26) | Year-end retro: which tracks worth pursuing in Phase 5 |

---

## 11. What Phase 4 enables (and what comes next)

By Phase 4 GA:
- AIDA is no longer a feature — it's a platform with self-serve tenant extension.
- Sales motion changes: "configure AIDA for your org" replaces "we'll build it for you".
- Engineering team can shift focus to platform reliability, cost optimization, and Phase 5 themes.

**Phase 5 candidate themes** (revisit at W50 retro):
- **External marketplace** — third-party publishers, revenue share
- **Voice modality** — donor call summarization, transcription-to-CRM
- **Real-time external feeds** — bank txn streams → AI-flagged anomalies
- **Federated knowledge** — opt-in cross-tenant insights for benchmarking
- **Proactive AI** — "you should know that…" insights pushed (vs only on demand)
- **Mobile-first AI surfaces** — field staff + volunteer apps
- **Tenant-tunable RLHF** — feedback-driven continuous improvement
- **AI-generated dashboards** — describe a metric, AI builds the dashboard

Phase 5 plan (`Implementation-Plan-Phase-5.md`) — written at end of Phase 4 (~W50–52) after retro.

---

*— End of Phase 4 plan —*
