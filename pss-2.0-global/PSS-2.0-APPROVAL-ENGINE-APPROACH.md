# PSS 2.0 — Generic Approval Engine (Approach)

> **Status:** DESIGN — decisions ⚑ D-1..D-9 need sign-off before a build prompt is written.
> **This document is not executable.** It is the design that a `PSS-2.0-APPROVAL-ENGINE-BUILD-PROMPT.md` will be generated from.
> **Scope:** platform side (`ops`) **and** tenant side, one engine, any document.

---

## ① Why this exists — what is actually on disk today

Every finding below was verified by reading the file named.

| # | Defect | Evidence |
|---|---|---|
| **A-1** | **There is no approval domain model.** Not one entity named Approval, ApprovalPolicy, ApprovalRequest, ApprovalStep, Stage or Escalation exists anywhere in `Base.Domain/Models/`. | Keyword scan of all 20 `*Models/` folders returns zero. |
| **A-2** | **33 bespoke approve/submit/reject command files**, each hand-rolling the same transition. Spread over ApplicationBusiness, ContactBusiness, DonationBusiness, FieldCollectionBusiness, GrantBusiness, MemBusiness, NotifyBusiness. | `ApproveGrant.cs`, `ApproveRefund.cs`, `ApproveP2PFundraiser.cs`, `ApproveVolunteerHourLog.cs`, … |
| **A-3** | **Every approval is single-approver, single-step, and implicit.** The approver is *whoever holds the Modify permission and clicked the button*. There is no configured approver, no second step, no quorum. | `ApproveRefund.cs` — `[CustomAuthorize(…, Permissions.Modify)]`, load row, assert `Status == "PEN"`, set `APR`, stamp `ApprovedBy` from the JWT. That is the whole approval. |
| **A-4** | **Status lives in a different place in every module.** Refund uses `MasterData` FK (`REFUNDSTATUS` → `PEN`/`APR`). CommercialTerm uses a plain string column. Grant uses a stage FK plus a `GrantStageHistory` table. | `Refund.RefundStatus` (FK), `CommercialTerm.ApprovalStatus` (string), `GrantStageHistory.ToStageId` (FK + history). |
| **A-5** | **One module already solved history, once, for itself.** `grant.GrantStageHistories` has From/To stage, actor, date, notes. Nothing else has it. | `GrantStageHistory.cs`. |
| **A-6** | **The platform side already has a hand-rolled approval and it is the user's exact example.** `ops.CommercialTerms` carries `ApprovalStatus DRAFT \| PENDING_APPROVAL \| APPROVED \| REJECTED`, `ApprovedByUserId`, `ApprovedOn`, `RejectionReason` — and *"Only APPROVED terms may be provisioned."* One approver, no config, no second step. | `CommercialTerm.cs:56–67`. |
| **A-7** | **The automation engine has an `"Approval"` step type that no executor implements.** `AutomationWorkflowStep.StepType` is used with `"Email"`, `"Wait"`, `"Condition"`, `"Approval"` — but `Approval` appears only as a *notification-template category count*, never as an executed step. | `GetNotificationTemplateSummary.cs:60` is the only match for `Approval` in all of NotifyBusiness. |
| **A-8** | **There is no "revise", no "resubmit", no "withdraw" anywhere.** Reject is terminal-by-accident (the row just sits in `REJ`). The submitter has no path back. | Zero matches for Revise/Resubmit/Withdraw as a transition; `ResubmitMatchingGift.cs` is a gateway retry, not an approval revise. |
| **A-9** | **Audit already fires APPROVE rows off a *name prefix*, with no entity id.** `AuditEventPipelineBehavior` maps `Approve*` → APPROVE, `Reject*` → REJECT, `Submit*` → APPROVE, and writes `entityId: 0` because *"EntityId not extractable at pipeline level without reflection."* | `AuditEventPipelineBehavior.cs:56–88`. **Consequence:** engine commands must implement `ISelfAuditedRequest` or every approval writes two audit rows, one of them useless. |

**Shape of the problem:** this is the 188-identical-delete-commands pattern again. Thirty-three copies of a five-line transition, none configurable, and the one requirement the business actually has — *"two approvers, and either all must approve or one named person is enough"* — cannot be expressed anywhere in the product.

---

## ② The mental model

> **A document does not approve itself. It rents a decision.**
> The document keeps its own status column and its own screen. The engine owns *who must decide, in what order, and what counts as enough* — and calls the document back when the answer arrives.

Two consequences that shape everything below:

1. **The engine never writes a business table.** It flips no `RefundStatus`, no `GrantStage`. It raises a callback and the module's own code does the flip. This is what lets it be generic across 33 existing commands without rewriting their status semantics.
2. **The policy is snapshotted at submit time.** Changing the approval matrix tomorrow must not silently re-route a request that is already half-approved. Same rule the codebase already applies to receipt numbers and FX rates: *store the value, not the pointer*.

---

## ③ How enterprise engines actually model this

Research consensus across the systems that do this well:

- **Quorum is declared explicitly per step**, not inferred — *all-of*, *any-of*, or *minimum count*. ([Oracle multi-level approval](https://docs.oracle.com/en/industries/financial-services/ofs-analytical-applications/model-management-and-governance/8.1.3.0.0/mmisg/multi-level-approval.html), [Power Automate multi-level](https://www.matthewdevaney.com/the-hidden-multi-level-approval-feature-in-power-automate/))
- **The approval matrix is a decision table**, separate from the document, that answers "does this transaction need approval, and who approves it." ([Cflow](https://www.cflowapps.com/approval-matrix/), [Moxo](https://www.moxo.com/blog/approval-matrix), [SAP](https://help.sap.com/doc/132b1ea8da1d4281a2da23f3cf506809/2.0.06/en-US/07dc534035524965a902c5bd6ffdbc3a.html))
- **Reject is decided by the first rejector; approve needs the full quorum.** "Approved when all approvers have approved, rejected when any one has rejected." ([ZoneApprovals](https://approvals-help.zoneandco.com/hc/en-us/articles/30190424523931-Approval-Matrix))
- **Approvers are references, not people** — role, group, or named user, resolved at request time. ([Oracle Identity Domains `ApprovalWorkflowStep`](https://docs.oracle.com/en-us/iaas/tools/dotnet/latest/api/Oci.IdentitydomainsService.Models.ApprovalWorkflowStep.html), [Dataverse `approvalprocess`](https://learn.microsoft.com/en-us/power-apps/developer/data-platform/reference/entities/approvalprocess))
- **Threshold routing, delegation, escalation timers and parallel branches are the layer above.** Every mature product has them; every mature product shipped without them first. ([Kinetic Data](https://www.kineticdata.com/blog/enterprise-approval-workflows), [ApproveThis](https://approvethis.com/multi-step-approvals))

We take the first four for MVP and explicitly defer the fifth.

---

## ④ Data model — 6 tables

### 4.0 `ApprovalSetting` — *the per-area switchboard* **(the on/off layer)**

One row per registered document type per scope. This is the table the settings screen renders as a list of toggles.

| Column | Notes |
|---|---|
| `ApprovalSettingId` | PK |
| `CompanyId` | Tenant table only. Platform mirror has no such column. See ⚑ D-1. |
| `DocumentTypeCode string` | `GRANT_APPLICATION`, `CASE`, `P2P_CAMPAIGN`, `TENANT_LAUNCH`… |
| `IsApprovalEnabled bool` | **Default `false`.** Off = the module keeps its existing direct transition, exactly as it behaves today. |
| `AllowRevise bool` | Default `false`. Off = approvers get Approve / Reject only, no send-back. |
| `AllowWithdraw bool` | Default `true`. Can the submitter pull it back before the first decision. |

Unique on `(CompanyId, DocumentTypeCode)`. Rows are **lazily created on first read** from the descriptor registry, so adding a new document type to the registry does not need a data migration — a tenant who has never opened the screen simply has no rows, and no rows means everything is off, which is the correct default.

**Three rules that make this safe:**

1. **`IsApprovalEnabled` is read once, at submit time.** The submitting module asks `IApprovalService.RequiresApprovalAsync(docTypeCode, ct)`. `false` → the module runs its old direct transition and no `ApprovalRequest` row is ever created. This is what makes the engine adoptable one area at a time without changing any existing behaviour.
2. **Turning approval OFF does not touch in-flight requests.** They run to completion under the policy they were submitted with. The engine never auto-approves anything because a setting changed — same principle as `PolicySnapshotJson`.
3. **`AllowRevise` is snapshotted into `PolicySnapshotJson` at submit**, so an approver who opens a request tomorrow sees the same three buttons they'd have seen yesterday.

### 4.1 `ApprovalPolicy` — *what needs approving*

| Column | Notes |
|---|---|
| `ApprovalPolicyId` | PK |
| `CompanyId int?` | **null = platform scope.** See ⚑ D-1. |
| `DocumentTypeCode string` | e.g. `TENANT_LAUNCH`, `GRANT_APPLICATION`. Reuses `public.EntityTypes.EntityTypeCode` where one exists — see ⚑ D-3. |
| `PolicyName string` | Shown in config UI. |
| `IsActive bool` | Exactly one active policy per (scope, DocumentTypeCode) — enforced in the save handler, not by index (soft-delete rows would collide). |
| `AllowWithdraw bool` | Can the submitter pull it back before the first decision. Default `true`. |

### 4.2 `ApprovalPolicyStep` — *the ladder*

| Column | Notes |
|---|---|
| `ApprovalPolicyStepId` | PK |
| `ApprovalPolicyId` | FK |
| `StepOrder int` | 1-based, sequential. Step 2 does not open until step 1 closes. |
| `StepName string` | "Finance review", "Management sign-off". |
| `QuorumMode string` | `ALL` \| `ANY` \| `MIN_COUNT`. |
| `MinApprovals int?` | Required only when `QuorumMode = MIN_COUNT`. |
| `AllowSelfApprove bool` | Default **false**. |

### 4.3 `ApprovalPolicyStepApprover` — *who decides*

| Column | Notes |
|---|---|
| `ApprovalPolicyStepApproverId` | PK |
| `ApprovalPolicyStepId` | FK |
| `ApproverType string` | `ROLE` \| `USER`. (`STAFF` deferred — Staff resolves to a User anyway.) |
| `ApproverRefId int` | RoleId or UserId. Deliberately **not** an FK — one column, two targets; resolved and validated in the service. |
| `IsSufficient bool` | **This is the user's requirement.** Default `false`. When `true`, this single approver's APPROVE closes the step regardless of `QuorumMode`. |

**How the user's sentence maps:**

> *"all the members should approve **or else** any specific mention person approve mainly enough"*

`QuorumMode = ALL` + one approver flagged `IsSufficient = true`. Step closes when **(any sufficient approver approved) OR (all non-sufficient approvers approved)**. Single approver = one row, `QuorumMode = ANY`. No special case, no fourth mode.

### 4.4 `ApprovalRequest` — *one live decision*

| Column | Notes |
|---|---|
| `ApprovalRequestId` | PK |
| `CompanyId int?` | null = platform. |
| `DocumentTypeCode string`, `DocumentId int` | **Not an FK** — the target is polymorphic. Re-resolve and re-check scope on every read (same rule as `RecycleBinEntry.EntityId`). |
| `DocumentLabel string` | **Snapshot** at submit. Survives the document being renamed or deleted. |
| `ApprovalPolicyId int` | Pointer, for reporting only. |
| `PolicySnapshotJson string` | **The policy as it stood at submit.** All runtime quorum math reads *this*, never the live tables. |
| `Status string` | `PENDING` \| `APPROVED` \| `REJECTED` \| `REVISION_REQUESTED` \| `WITHDRAWN` \| `STALLED` |
| `CurrentStepOrder int` | Which rung of the ladder is open. |
| `AttemptNumber int` | Increments on each resubmit after a revise. Starts at 1. |
| `SubmittedByUserId int`, `SubmittedByUserName string`, `SubmittedOn DateTime` | |
| `CompletedOn DateTime?` | |

### 4.5 `ApprovalAction` — *the immutable log*

| Column | Notes |
|---|---|
| `ApprovalActionId` | PK |
| `ApprovalRequestId` | FK |
| `AttemptNumber int`, `StepOrder int` | |
| `ActorUserId int`, `ActorUserName string` | Snapshot the name. |
| `Action string` | `SUBMIT` \| `APPROVE` \| `REJECT` \| `REVISE` \| `WITHDRAW` |
| `Comment string?` | **Required when `REJECT` or `REVISE`.** |
| `ActedOn DateTime` | UTC. |

**Rows are never updated and never deleted.** A revise-and-resubmit adds rows under a new `AttemptNumber`; it does not erase attempt 1.

---

## ⑤ The four flows the user named

### Approve
Approver acts → append `ApprovalAction` → recompute quorum for the open step from `PolicySnapshotJson`.
- Step not closed → request stays `PENDING`, nothing else happens.
- Step closed and a next step exists → `CurrentStepOrder++`, notify the next step's approvers.
- Step closed and it was the last → `Status = APPROVED`, `CompletedOn` stamped, **`OnApproved` callback fires** and the module flips its own status column.

### Reject
**First rejector wins, immediately, at any step.** Comment mandatory. `Status = REJECTED`, `OnRejected` fires. Terminal — no path back except a brand-new submission. This is deliberate: "reject" and "send back for changes" are two different verbs and conflating them is the most common design mistake in this space.

### Revise (send back) — **per-area, off by default**
Available only when `ApprovalSetting.AllowRevise` was `true` at submit time (§4.0). When off, approvers see Approve and Reject only.
Any approver on the open step can request a revision. Comment mandatory. `Status = REVISION_REQUESTED`, `OnRevisionRequested` fires, the document returns to an editable state, and the submitter is notified.
On resubmit: **`AttemptNumber++` and the ladder restarts at step 1.** ⚑ D-6 — approvals given against an older version of the document are stale, so they are not carried forward. Prior attempts stay visible in `ApprovalAction`.

### Self-approve
`AllowSelfApprove` is per step, default **false**. When false, the submitter is excluded from that step's quorum math entirely (not just blocked from clicking — excluded from the denominator, so `ALL` of two approvers where one is the submitter means the other one alone closes it).
**If exclusion leaves a step with zero eligible approvers**, the request goes to `STALLED` and an admin is notified. It does not silently auto-approve, and it does not silently hang. ⚑ D-7.

---

## ⑥ How a document joins the engine

**Not by rewriting 33 commands.** By registering a descriptor — the same shape the recycle bin uses, and for the same reason: a curated hand-written list beats anything generated from the menu tree.

```csharp
public sealed record ApprovalDocumentDescriptor(
    string DocumentTypeCode,
    string DisplayName,
    ApprovalScope Scope,                       // Platform | Tenant
    string DetailUrlTemplate,                  // "/setting/…/{id}" — drives Notification.ActionUrl
    Func<IApplicationDbContext, int, CancellationToken, Task<ApprovalDocumentSnapshot>> Load,
    Func<IApprovalCallbackContext, CancellationToken, Task> OnSubmitted,
    Func<IApprovalCallbackContext, CancellationToken, Task> OnApproved,
    Func<IApprovalCallbackContext, CancellationToken, Task> OnRejected,
    Func<IApprovalCallbackContext, CancellationToken, Task> OnRevisionRequested);
```

`Load` returns `(Label, OwnerUserId, IsInApprovableState)`. The four callbacks are where `Refund` sets `PEN → APR` and `CommercialTerm` sets `PENDING_APPROVAL → APPROVED` — each module keeps its own status vocabulary. The engine never learns what `APR` means.

Existing `Approve*` commands are **left alone** in Phase 1. A document either uses the engine or keeps its hand-rolled transition; nothing is half-migrated.

---

## ⑦ What we reuse instead of building

| Need | Already own it |
|---|---|
| Notify the approvers | `notify.Notifications` — already has `Scope` (`TENANT`/`PLATFORM`), `SourceEntityType`/`SourceEntityId`, `ActionUrl`, `ActionLabel`, `Category`, `Priority`, `IsRead`. **No new inbox table.** |
| Audit trail | `IAuditLogWriter.WriteWorkflowEvent(userId, entityType, entityId, transition, description)` — exists, unused outside 8 donation call sites. Engine commands **must** implement `ISelfAuditedRequest` (see A-9) or the pipeline behavior double-writes. |
| Document type vocabulary | `public.EntityTypes.EntityTypeCode` where the document is already registered. ⚑ D-3. |
| Approver = role | `auth.Roles` + existing RBAC. No approval-specific permission model. |
| "My approvals" screen | A query over `ApprovalRequest`, not a new table. |

---

## ⑧ Decisions needing sign-off

| ⚑ | Decision | Recommendation |
|---|---|---|
| **D-1** ↺ | **Platform + tenant: one table set or two?** *(REVISED — see §⑪. The planned per-tenant database split settles this.)* | **Two homes, one schema, one engine.** `app.Approval*` (tenant, `CompanyId` non-nullable, implements `ITenantEntity` → filter attaches for free) and `ops.Approval*` (platform, no `CompanyId`). Identical column shape. The engine is written once against an `IApprovalStore` and registered twice. 12 tables instead of 6, two EF config sets, **one** implementation. This also restores the codebase precedent (`PlatformAuditLog`/`AuditLog`, `PlatformPaymentGateway`, `PlatformCommunicationProvider`) that my earlier answer broke. |
| **D-2** | **Phase 1 document types.** | Exactly **two** — one per scope, to prove the engine is genuinely generic: `TENANT_LAUNCH` (platform, the user's own example, hooks `ops.TenantProvisioningRun`) and `GRANT_APPLICATION` (tenant, replaces `SubmitGrantApplication`/`ApproveGrant`/`RejectGrant`). Everything else is a registry entry in Phase 2. |
| **D-3** | **Does `DocumentTypeCode` reuse `public.EntityTypes`?** Thread (q) established we already have three parallel entity registries and must not add a fourth. | **Reuse the code string, do not add an FK.** `TENANT_LAUNCH` is a *process*, not an entity, so some codes will have no `EntityTypes` row. Validate at policy-save time against the descriptor registry, which is the real source of truth. |
| **D-4** | **Does the engine host on `notify.AutomationWorkflowSteps`?** It has a self-referencing tree, `StepOrder`, `StepType`, `StepConfig` JSON — and an unimplemented `"Approval"` step type (A-7). | **No.** Automation is fire-and-forget: trigger → actions → done. Approval is a *durable blocking state* with a per-request instance row, quorum arithmetic, and a document that cannot move until a human acts. Forcing it into `StepConfig` JSON means quorum lives in untyped JSON and "who is waiting on what" is unqueryable. Stand alone. Later, an automation step can *raise* an approval — that is a one-line integration, not a shared schema. |
| **D-5** | **`CommercialTerm` already has hand-rolled approval fields (A-6). Migrate it?** | **Not in Phase 1.** It works. Migrating it means a data backfill of in-flight terms. Add it to the registry in Phase 2 and leave the columns as a denormalised cache. |
| **D-6** | **On resubmit after revise, restart at step 1 or resume at the sending step?** | **Restart at step 1.** An approval given against a document that has since changed is worthless, and "resume" is how audit findings happen. Restarting is more clicks and defensible; resuming is fewer clicks and indefensible. |
| **D-7** | **Zero eligible approvers (self-approve exclusion, or a role with no members).** | **`STALLED` + notify admin.** Never auto-approve, never silently hang. Also validate at *policy save* time that each step has at least one resolvable approver — catch it early, but keep the runtime guard because role membership changes after the policy is saved. |
| **D-8** | **Is approval configuration a screen, or seed-only, for MVP?** | **A screen** — `setting/dataconfig/approvals` on the tenant side, `(master)` equivalent on the platform side. Landing view is the §4.0 switchboard: **one row per area, with Approval / Revise / Withdraw toggles**, so a tenant who wants approval on Grants only and nowhere else does it in one click. Expanding a row that is switched on reveals the step ladder — a simple ordered list, not a canvas. No drag-drop diagram. |
| **D-9** | **Delegation / out-of-office alternates.** The user did not ask for it; every enterprise product has it. | **Out of scope, and say so loudly in the build prompt** so nobody adds a `DelegateToUserId` column "while they're in there". The `ApproverType` enum leaves room for `DELEGATE` later without a migration. |

---

## ⑨ Explicitly out of scope for Phase 1

Threshold / conditional routing ("over ₹5L also needs the CFO") · parallel branches within a step · delegation and out-of-office alternates · escalation timers and SLA breach · approve-by-email-reply · approval on individual line items · external (non-user) approvers · migrating the other 31 hand-rolled commands · any change to `AuditEventPipelineBehavior` or `IAuditLogWriter`.

`QuorumMode` as a string and `ApproverType` as a string are the two extension points that let most of the above land later without a migration. That is deliberate.

---

## ⑩ Hard rule regardless of D-1

**No `DbContext` access to any `Approval*` table outside `ApprovalService`.** One service, one scoping helper, one place to get tenant isolation wrong. Enforce it as an acceptance criterion in the build prompt.

---

## ⑪ Forward-planning: the per-tenant database split

The plan is a **security DB** and a **primary (business) DB** per tenant. That is not built yet, but it changes two decisions *now*, because retrofitting them later is expensive.

### 11.1 The likely topology

| Store | Holds | Count |
|---|---|---|
| **Control-plane DB** | `ops.*` (provisioning, leads, support, platform audit), `billing.*` (plans, subscriptions, features), the tenant directory | **One**, shared |
| **Security DB** | `auth.*` — Users, Roles, UserRoles, Capabilities, Menus, RefreshTokens, PasswordResets | One shared, **or** one per tenant — see 11.3 |
| **Primary / business DB** | Everything else — `app`, `corg`, `grant`, `case`, `donation`, `notify`, `sett`, `audit`, `mem`, `vol`, `report` | **One per tenant** |
| **Reference data** | `public.*` — countries, currencies, EntityTypes, global master data | Shared / replicated read-only |

Your instinct — *"maximum business table only we keep individual db"* — is the right one. The split that pays for itself is **business-per-tenant, identity-shared-or-mirrored, platform-always-shared**. Splitting reference data buys nothing and costs a sync problem.

### 11.2 What this does to the approval engine

**It kills the single-table design outright.** A table with `CompanyId int?` where `null` means platform cannot exist when platform rows and tenant rows live in *different physical databases*. That is why ⚑ D-1 flipped to mirrored tables. Building it mirrored today costs one extra EF config set; building it single today costs a data migration across two servers later.

Concretely after the split:
- `app.Approval*` ships inside **each tenant's business DB**. Approval rows travel with the tenant — which is also what you want for backup, restore, export and tenant offboarding.
- `ops.Approval*` stays in the **control-plane DB**, where `TENANT_LAUNCH` and `CommercialTerm` approvals belong.
- Nothing needs to move. That is the whole point of deciding it now.

### 11.3 The real cost of the split — cross-database foreign keys

This is the part that bites, and it is worth knowing before the split rather than during it.

**Postgres cannot enforce a foreign key across databases.** If `auth.Users` leaves the business DB, then every one of these becomes an unenforceable plain `int`:

```
Refund.ApprovedByUserId          → auth.Users
GrantStageHistory.ActorStaffId   → Staff → auth.Users
Notification.ToUserId            → auth.Users
AuditLog.UserId                  → auth.Users
ApprovalAction.ActorUserId       → auth.Users
```

Two ways out, and the codebase has already picked one by accident:

1. **Keep `auth.*` inside each tenant's business DB** (one security DB *per tenant*, colocated). FKs survive. Cost: a user who belongs to two tenants exists twice, and platform staff need a separate identity store. Simplest, and it fits a product where users are already tenant-scoped.
2. **Move `auth.*` to one shared security DB** and demote every user FK to a plain int + a **snapshotted display name**. Cost: no referential integrity on actor columns, and every screen that shows "approved by" must read the snapshot, not a join.

**The approval engine is already designed for option 2 and works under option 1.** Every actor column in §4.4/§4.5 stores both the id *and* the name — `SubmittedByUserName`, `ActorUserName`, `RestoredByUserName`. That is not decoration. It is the discipline that makes a database split survivable, and the same discipline the recycle bin and the FX-rate snapshot rule already follow: **store the value, not just the pointer.**

The rule to carry into every new table from here on: **any column pointing at a user, a company, or a tenant-crossing row stores a snapshot of what it needs to display.** Apply it now and the split is a deployment change. Skip it and the split is a rewrite.

### 11.4 What I am *not* claiming

I have not read a sharding plan, a connection-routing design or a migration runner for this, because none exists on disk yet. The topology above is the standard shape for this product type, not something I verified against your intent. Treat 11.1 as a proposal to react to; treat 11.2 and 11.3 as consequences that hold under any version of the split.

---

*Next step: sign off ⚑ D-1..D-9, then this becomes `PSS-2.0-APPROVAL-ENGINE-BUILD-PROMPT.md` with §①–⑫, a Step 0 probe list, a migration spec for the 5 tables, and a menu/capability seed.*
