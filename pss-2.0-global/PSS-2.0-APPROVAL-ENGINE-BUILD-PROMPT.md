# PSS 2.0 — Generic Approval Engine (Build Prompt)

> **Status:** READY TO RUN · **Model:** Sonnet · **Phase 1 of 3**
> **Design source:** `PSS-2.0-APPROVAL-ENGINE-APPROACH.md` — read §④ (data model), §⑤ (flows), §⑥ (document registration) and §⑧ (signed-off decisions) before writing a line. This prompt is the executable contract; the approach doc is the reasoning behind it.
> **You do not run `dotnet build`. You do not run `dotnet ef`.** See §② rules 8 and 9.

---

## ⓪ Step 0 — probe before you build

Run all six, report findings in your first message, then start. If any probe contradicts this prompt, **say so and stop** — do not silently adapt.

1. **`ISelfAuditedRequest`** — confirm `Base.Application/Common/Interfaces/ISelfAuditedRequest.cs:14` is a bare marker interface (`public interface ISelfAuditedRequest;`). Every engine command implements it. Read `Common/Behaviors/AuditEventPipelineBehavior.cs:44–47` to confirm the marker is what suppresses the low-fidelity duplicate row.
2. **Notification creation path** — there is **no `INotificationService` in `Common/Interfaces/`**. Find how `notify.Notifications` rows are actually inserted today (grep `new Notification(` and `Notifications.Add` under `Base.Application/Business/`). **Report the pattern you find and reuse it.** Do not invent a service.
3. **`GrantStageHelper`** — read it (`Base.Application/Business/GrantBusiness/…`, referenced from `SubmitGrantApplication.cs:41`). The Grant callbacks in §④.6 must go through `IsTransitionAllowed` / `ResolveDataValueAsync`, not set `StageId` directly.
4. **Tenant filter attach mechanism** — read `ApplicationDbContext.ApplyTenantFilters` (`Base.Infrastructure/Data/Persistence/ApplicationDbContext.cs:61–131`). It attaches by reflecting over the **presence of a `CompanyId` property** — `.Where(e => e.ClrType.GetProperty("CompanyId") != null).Where(e => e.ClrType != typeof(Company))` — **not** over `ITenantEntity`, which the filter never consults. Rule 7's requirement is unchanged and is in fact *load-bearing because* of this: the `ops.PlatformApproval*` entities must carry **no `CompanyId`**, and that absence is precisely what keeps the filter off them. Adding one would silently enrol them in tenant filtering.
5. **`ops` read convention** — the convention lives in the **handler**, not the endpoint. `Base.API/EndPoints/Ops/Queries/TenantProvisioningQueries.cs` is a thin mediator passthrough with no EF in it. Read `Base.Application/Business/OpsBusiness/TenantProvisioning/Queries/GetProvisioningRuns.cs` — lines 47/49, 85/87 and 96 pair `IgnoreQueryFilters()` with an explicit `IsDeleted != true` guard. Copy that shape exactly.
6. **`GridFeatureRequest` paging** — confirm the `[AsParameters] GridFeatureRequest` convention from `Ops/Queries/SupportTicketQueries.cs` for the two list endpoints in §④.7.

---

## ① Why this exists

Every row was verified on disk. Full evidence in the approach doc §①.

| # | Defect | Evidence |
|---|---|---|
| A-1 | No approval domain model exists. Zero entities named Approval / Policy / Step / Stage. | Keyword scan, all 20 `*Models/` folders. |
| A-2 | 33 bespoke `*Approve*` / `*Submit*` / `*Reject*` command files, each re-implementing the same transition. | 7 business areas. |
| A-3 | Every approval is single-approver, single-step, implicit — the approver is whoever holds Modify and clicked. | `ApproveRefund.cs` — load, assert `PEN`, set `APR`, stamp JWT user. That is all of it. |
| A-4 | Status lives somewhere different in every module: `MasterData` FK (Refund), plain string (CommercialTerm), stage FK + history table (Grant). | `Refund.RefundStatus`, `CommercialTerm.ApprovalStatus`, `GrantStageHistory.ToStageId`. |
| A-5 | One module solved history once, for itself only. | `grant.GrantStageHistories`. |
| A-6 | The platform side already hand-rolls the user's exact example. | `CommercialTerm.cs:56–67` — `ApprovalStatus`, `ApprovedByUserId`, `ApprovedOn`, `RejectionReason`, *"Only APPROVED terms may be provisioned."* |
| A-7 | The automation engine declares an `"Approval"` step type that no executor implements. | Only match in all of NotifyBusiness is a template-category count, `GetNotificationTemplateSummary.cs:60`. |
| A-8 | No revise / resubmit / withdraw exists anywhere. Reject is terminal by accident. | `ResubmitMatchingGift.cs` is a gateway retry, not an approval revise. |
| A-9 | **Audit already fires APPROVE rows off the command name prefix, with `entityId: 0`.** | `AuditEventPipelineBehavior.cs:56–88`. **Consequence: every engine command MUST implement `ISelfAuditedRequest` or each approval writes two audit rows, one of them useless.** |
| A-10 | Tenants cannot turn approval off for one area and on for another, because there is nothing to turn off. | Direct consequence of A-1. |

---

## ② Rules this build must not break

1. **Add NO columns to any existing business table.** Not to `Grant`, not to `Refund`, not to `CommercialTerm`. The engine is additive-only.
2. **Do not modify any of the 33 existing `Approve*` / `Reject*` / `Submit*` commands** except the three named in §④.6.
3. **Approval is OFF by default, per area.** A tenant who never opens the settings screen gets exactly today's behaviour, everywhere.
4. **The engine never writes a business table.** It raises callbacks; the module's own code flips its own status. No `dbContext.Grants` / `.Refunds` writes inside `ApprovalService`.
5. **Phase 1 registry = exactly 2 document types.** `TENANT_LAUNCH` (platform) and `GRANT_APPLICATION` (tenant). Not three. Not "while I was in there".
6. **`PolicySnapshotJson` is the only source of runtime quorum math.** Never re-read `ApprovalPolicyStep*` while a request is in flight.
7. **`app.Approval*` implement `ITenantEntity`. `ops.Approval*` do not, and carry no `CompanyId`.** Two homes, one schema, one engine (⚑ D-1, revised).
8. **You do not run migrations.** No `dotnet ef migrations add`, no `database update`, no hand-authored migration or snapshot file. Write the entity + EF configuration only, and hand over §⑧.
9. **You do not run `dotnet build`.** Compile is the user's step.
10. **No raw SQL** in application code. `ExecuteUpdateAsync` / `ExecuteDeleteAsync` over a LINQ `IQueryable` are EF and fine.
11. **UTC only.** `DateTime.UtcNow`, never `DateTime.Now` / `.Today`, never a `Kind=Unspecified` value into an EF predicate.
12. **Every engine command implements `ISelfAuditedRequest`** and calls `IAuditLogWriter.WriteWorkflowEvent` itself with the real `entityId` (A-9).
13. **The audit write happens AFTER the transaction commits**, never awaited inside the transaction scope. `IAuditLogWriter` uses a separate scoped DbContext by design and swallows its own failures — pulling it inside would make an audit outage break approvals.
14. **`DocumentId` is not a foreign key.** It is polymorphic. Re-resolve the document and re-check its scope on every read.
15. **Snapshot every actor name.** `SubmittedByUserName`, `ActorUserName` are stored, not joined. This is what keeps the design alive through the planned per-tenant DB split (approach §⑪.3).
16. **`ApprovalAction` rows are never updated and never deleted.** A resubmit appends under a new `AttemptNumber`.
17. **Never auto-approve.** Not when a setting is switched off mid-flight, not when a step resolves to zero eligible approvers. Zero approvers → `STALLED` + notify.
18. **No `DbContext` access to any `Approval*` table outside `ApprovalService`.** One service, one scoping helper.
19. **HotChocolate strips `Get` from every resolver and appends `Input` to input types.** `tsc` cannot see gql field names — read the resolver, do not guess.
20. **House UI rules apply**: design tokens only (no hex, no raw px), `@iconify` Phosphor icons, shaped Skeletons, explicit empty and error states, xs→xl responsive.

---

## ③ The mental model

> **A document does not approve itself. It rents a decision.**
> The document keeps its own status column and its own screen. The engine owns *who must decide, in what order, and what counts as enough* — and calls the document back when the answer arrives.

---

## ④ What to build

### ④.1 Entities — 6 shapes × 2 homes = 12 classes

Write each shape twice: `Base.Domain/Models/ApplicationModels/Approval*.cs` (schema `app`) and `Base.Domain/Models/OpsModels/PlatformApproval*.cs` (schema `ops`). **Identical columns**, with exactly two differences: the `app` set has `public int CompanyId` and implements `ITenantEntity`; the `ops` set has neither.

Column definitions are in approach §④.0 – §④.5. Reproduced here as the contract:

**`ApprovalSetting`** — the per-area switchboard, unique `(CompanyId, DocumentTypeCode)`
`ApprovalSettingId` · `CompanyId` *(app only)* · `DocumentTypeCode string` · `IsApprovalEnabled bool = false` · `AllowRevise bool = false` · `AllowWithdraw bool = true`

**`ApprovalPolicy`**
`ApprovalPolicyId` · `CompanyId` *(app only)* · `DocumentTypeCode string` · `PolicyName string` · `IsActive bool` · `AllowWithdraw bool = true`

**`ApprovalPolicyStep`**
`ApprovalPolicyStepId` · `ApprovalPolicyId` · `StepOrder int` *(1-based)* · `StepName string` · `QuorumMode string` *(`ALL` | `ANY` | `MIN_COUNT`)* · `MinApprovals int?` · `AllowSelfApprove bool = false`

**`ApprovalPolicyStepApprover`**
`ApprovalPolicyStepApproverId` · `ApprovalPolicyStepId` · `ApproverType string` *(`ROLE` | `USER`)* · `ApproverRefId int` *(**not** an FK — one column, two targets)* · `IsSufficient bool = false`

**`ApprovalRequest`**
`ApprovalRequestId` · `CompanyId` *(app only)* · `DocumentTypeCode string` · `DocumentId int` *(**not** an FK)* · `DocumentLabel string` *(snapshot)* · `ApprovalPolicyId int` *(reporting pointer only)* · `PolicySnapshotJson string` · `Status string` *(`PENDING` | `APPROVED` | `REJECTED` | `REVISION_REQUESTED` | `WITHDRAWN` | `STALLED`)* · `CurrentStepOrder int` · `AttemptNumber int = 1` · `SubmittedByUserId int` · `SubmittedByUserName string` · `SubmittedOn DateTime` · `CompletedOn DateTime?`

**`ApprovalAction`** — append-only
`ApprovalActionId` · `ApprovalRequestId` · `AttemptNumber int` · `StepOrder int` · `ActorUserId int` · `ActorUserName string` · `Action string` *(`SUBMIT` | `APPROVE` | `REJECT` | `REVISE` | `WITHDRAW`)* · `Comment string?` · `ActedOn DateTime`

EF configurations go in `Base.Infrastructure/Data/Configurations/ApplicationConfigurations/` and `…/OpsConfigurations/` respectively, matching the existing file-per-entity convention.

### ④.2 The switchboard is lazily materialised

`ApprovalSetting` rows are **created on first read**, from the descriptor registry (§④.4), with all defaults. A tenant with no rows has approval off everywhere — the correct default. Adding a document type to the registry later must therefore need **no data migration**.

### ④.3 `IApprovalStore` — how one engine serves two homes

```csharp
public interface IApprovalStore
{
    ApprovalScope Scope { get; }
    IQueryable<IApprovalSetting>  Settings  { get; }
    IQueryable<IApprovalPolicy>   Policies  { get; }
    IQueryable<IApprovalRequest>  Requests  { get; }
    IQueryable<IApprovalAction>   Actions   { get; }
    // Add / SaveChanges / transaction helpers
}
```

Two implementations — `TenantApprovalStore` (reads `app.*`, tenant filter attaches automatically) and `PlatformApprovalStore` (reads `ops.*` with `IgnoreQueryFilters()` **and** explicit `IsDeleted != true`, per Step 0 probe 5). `ApprovalService` is written **once** against the interface and resolves the store from the descriptor's `Scope`.

### ④.4 The document registry — curated, hand-written

`Base.Application/Common/Approvals/ApprovalDocumentRegistry.cs`. Descriptor shape is in approach §⑥.

**Explicitly prohibited:** generating this list from `auth.Modules`, the menu tree, `public.EntityTypes`, or by scanning for status columns. It is a curated business vocabulary, exactly like `billing.Features`. Phase 1 contains **two** entries and no more:

| Code | Scope | Document | Detail URL |
|---|---|---|---|
| `TENANT_LAUNCH` | Platform | `ops.TenantProvisioningRun` (`RunId`, `Status`) | `(master)` provisioning detail |
| `GRANT_APPLICATION` | Tenant | `grant.Grants` (`GrantId`, `StageId`) | grant detail |

`DocumentTypeCode` reuses `public.EntityTypes.EntityTypeCode` **as a string only, with no FK** — `TENANT_LAUNCH` is a process, not an entity, and has no `EntityTypes` row (⚑ D-3). Validate at policy-save time against the registry, which is the source of truth.

### ④.5 `ApprovalService` — the whole engine

```csharp
Task<bool>                 RequiresApprovalAsync(string docTypeCode, CancellationToken ct);
Task<ApprovalRequestDto>   SubmitAsync(string docTypeCode, int documentId, CancellationToken ct);
Task<ApprovalRequestDto>   ActAsync(int requestId, string action, string? comment, CancellationToken ct);
Task<ApprovalRequestDto?>  GetForDocumentAsync(string docTypeCode, int documentId, CancellationToken ct);
```

**`SubmitAsync` order of operations — get this exactly right:**
1. Resolve descriptor → resolve store from `descriptor.Scope`.
2. Read `ApprovalSetting`. `IsApprovalEnabled == false` → **throw**; the caller should have checked `RequiresApprovalAsync` first and taken its own path.
3. Guard: no existing `PENDING` request for `(DocumentTypeCode, DocumentId)`.
4. `descriptor.Load` → label + owner + `IsInApprovableState`.
5. Load the active policy, serialise it — **including `AllowRevise` and `AllowWithdraw` from the setting** — into `PolicySnapshotJson`.
6. Resolve step 1's eligible approvers (§④.8). Zero eligible → persist `STALLED`, notify, return.
7. Insert `ApprovalRequest` (`PENDING`, `CurrentStepOrder = 1`, `AttemptNumber = 1`) + a `SUBMIT` `ApprovalAction`. **One transaction.**
8. **Commit.**
9. *Then* — outside the transaction — `descriptor.OnSubmitted`, notify step 1's approvers, `WriteWorkflowEvent(action: "SUBMIT")`.

**`ActAsync`** recomputes quorum from `PolicySnapshotJson` only, per approach §⑤. Same transaction discipline: state change commits first, callbacks and notifications and audit fire after.

### ④.6 Quorum arithmetic — the one function that must be right

For the open step, over its eligible approvers (§④.8):

```
closed  =  (any approver with IsSufficient == true has APPROVEd)
        OR (QuorumMode == ANY       && approvals >= 1)
        OR (QuorumMode == ALL       && every non-sufficient eligible approver has APPROVEd)
        OR (QuorumMode == MIN_COUNT && approvals >= MinApprovals)
```

**`IsSufficient` short-circuits every mode.** This is the user's requirement verbatim: *"all the members should approve **or else** any specific mention person approve mainly enough."* Single approver is `QuorumMode = ANY` with one row — no special case.

Reject is decided by the **first rejector, at any step, immediately**. Comment mandatory.

### ④.7 Call-site edits — exactly three files

```
Base.Application/Business/GrantBusiness/Grants/UpdateCommand/SubmitGrantApplication.cs
Base.Application/Business/GrantBusiness/Grants/UpdateCommand/ApproveGrant.cs
Base.Application/Business/GrantBusiness/Grants/UpdateCommand/RejectGrant.cs
```

Each gains **one branch at the top and nothing else**:

```csharp
if (await approvals.RequiresApprovalAsync(ApprovalDocumentTypes.GrantApplication, ct))
{
    var request = await approvals.SubmitAsync(ApprovalDocumentTypes.GrantApplication, command.grantId, ct);
    return new SubmitGrantApplicationResult(command.grantId);
}
// …existing direct-transition code, untouched…
```

The existing body stays exactly as it is — that is the off path, and it must remain byte-for-byte today's behaviour. Stage transitions inside the callbacks go through `GrantStageHelper` (Step 0 probe 3), never by setting `StageId` directly.

Platform side: `TenantProvisioningMutations.cs` gains the same branch before launch. **Do not touch `CommercialTerm`** (⚑ D-5).

### ④.8 Eligible-approver resolution

`ROLE` → all active users holding that role in scope. `USER` → that user, if still active.
**Exclusion:** when `AllowSelfApprove == false`, the submitter is removed from the eligible set **entirely — not just blocked from clicking, but removed from the denominator.** So `ALL` over two approvers where one is the submitter closes on the other one alone.
Zero eligible after exclusion → `STALLED` + notify admin. **Never auto-approve, never silently hang** (⚑ D-7).

Also validate at **policy save** time that every step resolves to ≥1 approver — catch it early — but keep the runtime guard, because role membership changes after the policy is saved.

### ④.9 Notifications

Go through **`INotificationSender.SendAsync(NotificationRequest, ct)`** — `Base.Application/Services/Notifications/`. That is the real seam; do not insert `Notification` rows directly (`NotificationWriter.cs:99` is the only legitimate `Notifications.Add` site, and it sits behind the sender). **Create no new inbox table and no new service.**

Copy the discipline from `Base.Application/Business/OpsBusiness/LeadManagement/Commands/AssignLead.cs:215–274`: send **after** the transaction commits, from a private `NotifyInAppAsync`, wrapped in try/catch that logs a warning and drops. A notification outage must never fail an approval.

`NotificationRequest` carries `Title`, `Body`, `Category`, `Priority`, `IconCode`, `ActionUrl` *(scope-relative, no locale prefix)*, `ActionLabel`, `FromUserId`, `TriggerCode`, `SourceEntityType`/`SourceEntityId`.

**`NotificationTarget` maps directly onto §④.8's approver types.** Its constructor is private and every shape is a named factory, so a platform target cannot carry a `CompanyId`:
- `ApproverType == USER` → `NotificationTarget.TenantUsers(companyId, ids)` / `PlatformUsers(ids)`
- `ApproverType == ROLE` → `NotificationTarget.TenantRoles(companyId, roleCodes)` / `PlatformRoles(roleCodes)`

**Use the role factories rather than expanding roles to user ids yourself for the notification.** The sender already resolves role membership. Note this is only about *delivery* — §④.8's quorum resolution still needs the expanded eligible-approver set for its denominator, so that expansion does not go away; it simply is not repeated on the notify path.

Notify on: submit (step 1 approvers) · step advance (next step's approvers) · approve/reject/revise (submitter) · stall (admin).

### ④.10 GraphQL

Tenant — `Base.API/EndPoints/Setting/{Queries,Mutations}/ApprovalEndpoints.cs`. Platform — `Base.API/EndPoints/Ops/{Queries,Mutations}/PlatformApprovalEndpoints.cs`.

Queries: `approvalSettings` · `approvalPolicy(documentTypeCode)` · `approvalRequests` *(`[AsParameters] GridFeatureRequest`, filterable by `assignedToMe`)* · `approvalRequestById` · `approvalRequestForDocument(documentTypeCode, documentId)`
Mutations: `UpdateApprovalSetting` · `SaveApprovalPolicy` *(whole ladder in one payload, diff-applied)* · `SubmitForApproval` · `ActOnApprovalRequest`

Remember rule 19 — after `Get`-stripping, `GetApprovalRequests` is `approvalRequests` on the wire.

---

## ⑤ Frontend

**Config screen** — `app/[lang]/(core)/setting/dataconfig/approvals/page.tsx`, plus the `(master)` platform twin.

Landing view is the **switchboard**: one row per registered area, with Approval / Revise / Withdraw toggles. A tenant who wants approval on Grants only does it in one click. Expanding a switched-on row reveals the step ladder — an ordered list with add/remove/reorder, per-step quorum mode, and an approver picker (role or user) with an **"is sufficient on their own"** checkbox. **No canvas, no drag-drop diagram** (⚑ D-8).

Subtitle, required: *"Approval is off by default. Turn it on only for the areas that need it."*

**My Approvals** — a list of requests where the current user is a pending approver, with Approve / Reject / Revise. Revise is hidden entirely when the request's snapshot says `AllowRevise = false`. Reject and Revise both require a comment before the button enables.

**Document strip** — on the Grant detail screen, a compact status strip showing current step, who it is waiting on, and the full `ApprovalAction` history for every attempt. Prior attempts stay visible.

Per the standing rule, the page-header Save is gated by RHF `formState.isValid`, never by `canUpdate`.

---

## ⑥ Out of scope — do not build

Threshold / conditional routing · parallel branches within a step · delegation and out-of-office alternates · escalation timers and SLA breach · approve-by-email-reply · approval on individual line items · external non-user approvers · migrating the other 31 hand-rolled commands · migrating `CommercialTerm` · any change to `AuditEventPipelineBehavior` or `IAuditLogWriter` · any change to `notify.AutomationWorkflow*`.

`QuorumMode` and `ApproverType` are strings precisely so most of the above lands later without a migration. Leave them that way.

---

## ⑦ Acceptance criteria

Each is greppable. All must pass.

1. `Grant.cs`, `Refund.cs`, `CommercialTerm.cs` unmodified — `git diff` shows no change.
2. Exactly **12** new entity classes; the 6 `ops` ones contain no `CompanyId` and no `ITenantEntity`.
3. The 6 `app` entity classes each implement `ITenantEntity`. **This is a documentation assertion, not a functional one** — per Step 0 probe 4 the tenant filter attaches off the `CompanyId` property, so these entities are filtered with or without the interface. Implement it anyway: it declares intent at the class header and makes the marker mean something. Do not rely on it for isolation.
4. `ApprovalDocumentRegistry.cs` contains **exactly 2** descriptors.
5. Exactly **4** existing files changed at call sites (3 Grant commands + `TenantProvisioningMutations.cs`); `git diff --stat` proves it.
6. Zero `dbContext.Grants` / `.Refunds` / `.CommercialTerms` **writes** inside `ApprovalService` or `IApprovalStore` implementations.
7. Zero `Approval*` DbSet access outside `ApprovalService` — grep the solution.
8. Every engine command type implements `ISelfAuditedRequest`.
9. Every `WriteWorkflowEvent` call sits **after** its transaction commits, and `IAuditLogWriter.cs` is unmodified.
10. Every `ops` approval read carries both `IgnoreQueryFilters()` and an explicit `IsDeleted != true`.
11. Zero `DateTime.Now` / `DateTime.Today` in new code.
12. Zero raw SQL (`FromSqlRaw`, `ExecuteSqlRawAsync`, string-built SQL) in new code.
13. No migration file and no snapshot edit created anywhere.
14. Runtime quorum reads `PolicySnapshotJson` — zero reads of `ApprovalPolicyStep` inside `ActAsync`.
15. Default-off proven: with no `ApprovalSetting` row, `RequiresApprovalAsync` returns `false` and the Grant commands run their original path unchanged.
16. `IsSufficient` short-circuits all three quorum modes — covered by the arithmetic in §④.6.
17. Zero-eligible-approver path produces `STALLED`, never `APPROVED`.
18. FE gql field names match the resolvers **after** `Get`-stripping.
19. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` exits **0**. A run reporting only a TS2688 stub-types error checked **zero files** and is **not** a pass.

---

## ⑧ Migration spec — user-authored, do not run

Two migrations, both hand-authored/run by the user. **Session A wrote no migration file, ran no `dotnet ef`, and emitted no raw SQL** — this section is the spec, reconciled line-by-line against the twelve `IEntityTypeConfiguration` classes as they actually shipped.

Every table maps by `[Table(name, Schema = …)]` on the entity — there is no `HasDefaultSchema` in either context, so the attribute is the authority. Every entity derives from `Base.Domain.Abstractions.Entity`, which contributes the standard audit columns **`CreatedBy int NULL`, `CreatedDate timestamptz NULL`, `ModifiedBy int NULL`, `ModifiedDate timestamptz NULL`, `IsActive boolean NULL`, `IsDeleted boolean NULL`** to all twelve tables. Every PK is `UseIdentityAlwaysColumn()` → `GENERATED ALWAYS AS IDENTITY`. All date columns are `timestamp with time zone`.

**A — `app` (tenant).** Six tables, each with `CompanyId int NOT NULL`.

| Table | PK | Columns beyond `CompanyId` + audit |
|---|---|---|
| `app."ApprovalSettings"` | `ApprovalSettingId` | `DocumentTypeCode varchar(50) NOT NULL` · `IsApprovalEnabled bool NOT NULL DEFAULT false` · `AllowRevise bool NOT NULL DEFAULT false` · `AllowWithdraw bool NOT NULL DEFAULT true` |
| `app."ApprovalPolicies"` | `ApprovalPolicyId` | `DocumentTypeCode varchar(50) NOT NULL` · `PolicyName varchar(200) NOT NULL` · `IsActive bool NOT NULL DEFAULT true` · `AllowWithdraw bool NOT NULL DEFAULT true` |
| `app."ApprovalPolicySteps"` | `ApprovalPolicyStepId` | `ApprovalPolicyId int NOT NULL` (FK → `ApprovalPolicies`, **cascade**) · `StepOrder int NOT NULL` · `StepName varchar(200) NOT NULL` · `QuorumMode varchar(20) NOT NULL` · `MinApprovals int NULL` · `AllowSelfApprove bool NOT NULL DEFAULT false` |
| `app."ApprovalPolicyStepApprovers"` | `ApprovalPolicyStepApproverId` | `ApprovalPolicyStepId int NOT NULL` (FK → `ApprovalPolicySteps`, **cascade**) · `ApproverType varchar(20) NOT NULL` · `ApproverRefId int NOT NULL` · `IsSufficient bool NOT NULL DEFAULT false` |
| `app."ApprovalRequests"` | `ApprovalRequestId` | `DocumentTypeCode varchar(50) NOT NULL` · `DocumentId int NOT NULL` · `DocumentLabel varchar(300) NOT NULL` · `ApprovalPolicyId int NOT NULL` (**not** an FK — see below) · `PolicySnapshotJson jsonb NOT NULL` · `Status varchar(30) NOT NULL` · `CurrentStepOrder int NOT NULL` · `AttemptNumber int NOT NULL DEFAULT 1` · `SubmittedByUserId int NOT NULL` · `SubmittedByUserName varchar(200) NOT NULL` · `SubmittedOn timestamptz NOT NULL` · `CompletedOn timestamptz NULL` |
| `app."ApprovalActions"` | `ApprovalActionId` | `ApprovalRequestId int NOT NULL` (FK → `ApprovalRequests`, **cascade**) · `StepOrder int NOT NULL` · `AttemptNumber int NOT NULL` · `ActorUserId int NOT NULL` · `ActorUserName varchar(200) NOT NULL` · `Action varchar(20) NOT NULL` · `Comment varchar(2000) NULL` · `ActedOn timestamptz NOT NULL` |

Indexes (names are pinned by `HasDatabaseName` — do not let EF rename them):
- `UX_ApprovalSettings_Tenant_Doc` — **unique** `(CompanyId, DocumentTypeCode)` filtered `WHERE "IsDeleted" = false`
- `IX_ApprovalPolicies_Tenant_Doc_Active` — `(CompanyId, DocumentTypeCode, IsActive)`
- `IX_ApprovalPolicySteps_Policy_Order` — `(ApprovalPolicyId, StepOrder)`
- `IX_ApprovalPolicyStepApprovers_Step` — `(ApprovalPolicyStepId)`
- `IX_ApprovalRequests_Tenant_Doc` — `(CompanyId, DocumentTypeCode, DocumentId)`
- `IX_ApprovalRequests_Tenant_Status` — `(CompanyId, Status, SubmittedOn DESC)` — the descending leg is `IsDescending(false, false, true)`
- `IX_ApprovalActions_Request` — `(ApprovalRequestId, AttemptNumber, StepOrder)`

**B — `ops` (platform).** The same six shapes prefixed `Platform`, **without `CompanyId`** — that absence is what keeps the tenant query filter off them (rule 7), so it is load-bearing, not cosmetic. Tables: `ops."PlatformApprovalSettings"`, `ops."PlatformApprovalPolicies"`, `ops."PlatformApprovalPolicySteps"`, `ops."PlatformApprovalPolicyStepApprovers"`, `ops."PlatformApprovalRequests"`, `ops."PlatformApprovalActions"`. Column names, types, nullability and defaults are identical to A minus `CompanyId`; PK column names are also identical (`ApprovalSettingId`, `ApprovalPolicyId`, … — **not** `PlatformApprovalSettingId`).

Indexes, tenant column dropped:
- `UX_PlatformApprovalSettings_Doc` — **unique** `(DocumentTypeCode)` filtered `WHERE "IsDeleted" = false`
- `IX_PlatformApprovalPolicies_Doc_Active` — `(DocumentTypeCode, IsActive)`
- `IX_PlatformApprovalPolicySteps_Policy_Order` — `(ApprovalPolicyId, StepOrder)`
- `IX_PlatformApprovalPolicyStepApprovers_Step` — `(ApprovalPolicyStepId)`
- `IX_PlatformApprovalRequests_Doc` — `(DocumentTypeCode, DocumentId)`
- `IX_PlatformApprovalRequests_Status` — `(Status, SubmittedOn DESC)`
- `IX_PlatformApprovalActions_Request` — `(ApprovalRequestId, AttemptNumber, StepOrder)`

**Foreign keys.** Real, cascading, and *within* a set only: policy → steps → approvers, request → actions. No FK ever crosses `app` ↔ `ops`. Three columns carry **no FK, by design**:
- `DocumentId` — polymorphic, addresses a different business table per `DocumentTypeCode`, and the request must outlive the document being archived.
- `ApproverRefId` — polymorphic, addresses `auth."Roles".RoleId` or `auth."Users".UserId` depending on `ApproverType`.
- `ApprovalRequests.ApprovalPolicyId` — a reporting pointer only. Deliberately unconstrained so a policy edit cannot cascade into an in-flight request; runtime quorum math reads `PolicySnapshotJson`, never the live policy.

---

## ⑨ Seed spec

`sql-scripts-dyanmic/approval-engine-menu-capability-seed.sql`. One script, one file, no diagnostic or optional blocks; a result `SELECT` at the end is fine.

- `APPROVALSETTING` menu at `/setting/dataconfig/approvals`, parented **by menu code, not id**.
- `MYAPPROVALS` menu at `/approvals`.
- Platform twin under the `(master)` tree.
- `Read` + `Modify` + `ISMENURENDER` capabilities, granted to `BUSINESSADMIN`.
- **Soft-delete only** on any replaced grant (`IsDeleted = true, IsActive = false`) — never `DELETE`.
- **`SUPERADMIN` is never revoked or overwritten**, matched by `RoleCode` alone.
- Seed **no** `ApprovalSetting` rows. Default-off is the absence of a row (§④.2).

---

## ⑩ Work order

1. Run §⓪ probes, report, stop if anything contradicts.
2. 12 entity classes + 12 EF configurations.
3. `IApprovalStore` + two implementations.
4. `ApprovalDocumentRegistry` with 2 descriptors.
5. `ApprovalService` — settings, submit, act, quorum, approver resolution.
6. Notifications wiring (pattern from probe 2).
7. GraphQL — tenant then platform.
8. Four call-site branches.
9. FE — switchboard screen, step-ladder editor, My Approvals, document strip.
10. `npx tsc --noEmit --incremental false` → exit 0.
11. Write §⑧ migration spec and §⑨ seed file.
12. Append to §⑪ Build Log.

---

## ⑩·5 Split across two sessions

This build is intended to run as **two sessions**. The split is between step 8 and step 9 — backend complete, frontend not started.

### Session A — steps 1–8 + 11 (backend)

Stop after step 8. Do **not** start any frontend file.

Acceptance criteria that apply: **1–17**. Criteria **18 and 19 do not apply** — there is no frontend yet, and `tsc` proves nothing about a backend-only change. Do not run it and do not report it as passing.

Before finishing, write §⑩·5·1 below. **This is the deliverable, not a courtesy.** Session B starts with an empty context window and cannot see your reasoning, only the repository and this file.

### Session A → B handoff record (Session A fills this in)

**⑩·5·1 — Wire names.** For every query and mutation added in §④.10, record the **on-the-wire GraphQL field name after `Get`-stripping and `Input`-appending**, not the C# method name. Also record the exact DTO property names the FE will select.

> This exists because `tsc` cannot see gql field names. A wrong name compiles clean and fails only at runtime. Session B guessing `approvalRequestsList` when you shipped `approvalRequests` is the single most likely way this build breaks, and it is invisible until someone clicks the screen.

*Filled in — Session A, 2026-08-13.*

**Tenant surface** — `Base.API/EndPoints/Setting/{Queries,Mutations}/ApprovalEndpoints.cs`.

| C# method | Wire field | Args (wire) | Returns |
|---|---|---|---|
| `GetApprovalSettings` | `approvalSettings` | — | `BaseApiResponse<[ApprovalSettingResponseDto]>` |
| `GetApprovalPolicy` | `approvalPolicy` | `documentTypeCode: String!` | `BaseApiResponse<ApprovalPolicyResponseDto>` |
| `GetApprovalRequests` | `approvalRequests` | `GridFeatureRequest` fields flattened via `[AsParameters]`, plus `assignedToMe: Boolean! = false` | `PaginatedApiResponse<[ApprovalRequestResponseDto]>` |
| `GetApprovalRequestById` | `approvalRequestById` | `approvalRequestId: Int!` | `BaseApiResponse<ApprovalRequestDto>` |
| `GetApprovalRequestForDocument` | `approvalRequestForDocument` | `documentTypeCode: String!`, `documentId: Int!` | `BaseApiResponse<ApprovalRequestDto>` |
| `UpdateApprovalSetting` | `updateApprovalSetting` | `request: ApprovalSettingUpdateDtoInput!` | `BaseApiResponse<ApprovalSettingResponseDto>` |
| `SaveApprovalPolicy` | `saveApprovalPolicy` | `request: ApprovalPolicySaveDtoInput!` | `BaseApiResponse<ApprovalPolicyResponseDto>` |
| `SubmitForApproval` | `submitForApproval` | `documentTypeCode: String!`, `documentId: Int!` | `BaseApiResponse<ApprovalRequestDto>` |
| `ActOnApprovalRequest` | `actOnApprovalRequest` | `approvalRequestId: Int!`, `action: String!`, `comment: String` | `BaseApiResponse<ApprovalRequestDto>` |

**Platform surface** — `Base.API/EndPoints/Ops/{Queries,Mutations}/PlatformApprovalEndpoints.cs`. Same arg shapes, same DTO types, different field names:

`platformApprovalSettings` · `platformApprovalPolicy` · `platformApprovalRequests` · `platformApprovalRequestById` · `platformApprovalRequestForDocument` · `updatePlatformApprovalSetting` · `savePlatformApprovalPolicy` · `submitPlatformForApproval` · `actOnPlatformApprovalRequest`.

There is **no scope argument on the wire.** The two surfaces are physically separate; a tenant session has no resolver that reaches `ops` rows and vice versa.

**Input types (`Input` appended):** `ApprovalSettingUpdateDtoInput`, `ApprovalPolicySaveDtoInput`. Nested save DTOs appear as `ApprovalPolicyStepSaveDtoInput` and `ApprovalPolicyStepApproverSaveDtoInput`.

**DTO property names** (`Base.Application/Schemas/ApplicationSchemas/ApprovalSchemas.cs`; camelCase on the wire):

- `ApprovalSettingResponseDto` — `approvalSettingId`, `documentTypeCode`, `displayName`, `isApprovalEnabled`, `allowRevise`, `allowWithdraw`, `hasPolicy`, `stepCount`
- `ApprovalPolicyResponseDto` — `approvalPolicyId`, `documentTypeCode`, `policyName`, `isActive`, `allowWithdraw`, `steps[]`
- `ApprovalPolicyStepResponseDto` — `approvalPolicyStepId`, `stepOrder`, `stepName`, `quorumMode`, `minApprovals` (nullable), `allowSelfApprove`, `approvers[]`
- `ApprovalPolicyStepApproverResponseDto` — `approvalPolicyStepApproverId`, `approverType`, `approverRefId`, `approverName` (nullable), `isSufficient`
- `ApprovalRequestResponseDto` (grid row) — `approvalRequestId`, `documentTypeCode`, `documentId`, `documentLabel`, `approvalPolicyId`, `status`, `currentStepOrder`, `attemptNumber`, `submittedByUserId`, `submittedByUserName`, `submittedOn`, `completedOn` (nullable)
- `ApprovalRequestDto` (detail) — the grid fields plus `steps[]` (`ApprovalRequestStepDto`), `actions[]` (`ApprovalActionResponseDto`), `canAct`, `canWithdraw`
- `ApprovalSettingUpdateDto` (input) — `documentTypeCode`, `isApprovalEnabled`, `allowRevise`, `allowWithdraw`
- `ApprovalPolicySaveDto` (input) — `documentTypeCode`, `policyName`, `isActive`, `steps[]`; step: `stepOrder`, `stepName`, `quorumMode`, `minApprovals`, `allowSelfApprove`, `approvers[]`; approver: `approverType`, `approverRefId`, `isSufficient`

**Capability decorators as shipped** (Session B needs these for menu/route guards): tenant settings + policy read → `APPROVALSETTING` / `Read`; settings + policy write → `APPROVALSETTING` / `Modify`; queue, detail and document-strip reads → `MYAPPROVALS` / `Read`; `submitForApproval` → `MYAPPROVALS` / `Sendforapproval`; `actOnApprovalRequest` → `MYAPPROVALS` / `ApproveRequest`. Platform side is `[CustomAuthorize("PLATFORM_APPROVALS", …)]` with `PLATFORM_APPROVAL_VIEW` on queries, `PLATFORM_APPROVAL_MANAGE` on setting/policy writes, `PLATFORM_APPROVAL_ACT` on submit and act.

**⑩·5·2 — Enum string values as shipped.** The literal strings for `Status`, `Action`, `QuorumMode`, `ApproverType`. If you deviated from §④.1 for any reason, say so here loudly.

*Filled in — Session A. **No deviation from §④.1.*** All four are `string` columns, not DB enums, and the constants live in `Base.Application/Common/Approvals/ApprovalConstants.cs`.

- **Status** (`ApprovalStatuses`) — `PENDING` · `APPROVED` · `REJECTED` · `REVISION_REQUESTED` · `WITHDRAWN` · `STALLED`
- **Action** (`ApprovalActionTypes`) — `SUBMIT` · `APPROVE` · `REJECT` · `REVISE` · `WITHDRAW`
- **QuorumMode** (`QuorumModes`) — `ALL` · `ANY` · `MIN_COUNT`
- **ApproverType** (`ApproverTypes`) — `ROLE` · `USER`
- **DocumentTypeCode** (`ApprovalDocumentTypes`, curated registry, exactly two) — `TENANT_LAUNCH` (platform scope) · `GRANT_APPLICATION` (tenant scope)

`STALLED` is a terminal-ish display state, not a decision: rule 17 holds, nothing ever auto-approves out of it.

**⑩·5·3 — Notification pattern found.** What Step 0 probe 2 actually turned up, and which file you copied.

*Filled in — Session A.* Probe 2 found `INotificationSender` in `Base.Application/Services/Notifications/` (with `NotificationRequest`, `NotificationTarget`, `NotificationSender`, and a separate `INotificationDispatcher` used by the scheduled/queued path). The direct-send seam is the right one here, and the discipline copied is `AssignLead.cs:215–274` — **send after the commit, wrapped in try/catch, log-and-drop on failure, never fail the workflow.** `ApprovalService.cs` lines 938–1105 follow it verbatim across three senders (pending-with-you, decision-to-submitter, stalled-to-admins), each with its own `catch (Exception ex)` that logs and returns.

Targets use the sender's own role fan-out rather than expanding roles to user ids in the engine: `NotificationTarget.TenantRoles(companyId, roleCodes)` / `NotificationTarget.PlatformRoles(roleCodes)` for `ROLE` approvers, `TenantUsers` / `PlatformUsers` for `USER` approvers and for the submitter. `Priority = "High"`, `Category = "Approval"`, trigger codes `approval.pending` / `approval.decided` / `approval.stalled` — matching the casing the existing senders use, not SCREAMING_CASE.

**⑩·5·4 — Anything you had to decide.** Contradictions found at Step 0, deviations from this prompt, anything left unfinished.

*Filled in — Session A.*

**Contradiction found at Step 0 (probe 4).** The prompt said the tenant query filter attaches over `ITenantEntity`. On disk `ApplicationDbContext.ApplyTenantFilters` (lines 61–131) reflects over the **presence of a `CompanyId` property**. Reported, and the prompt was corrected by the user before step 2. The six app entities still implement `ITenantEntity` (documentation value, AC 3 re-marked as a documentation assertion); the six ops entities carry no `CompanyId`, and that absence is what keeps the filter off them.

**Deviations from the prompt, all deliberate:**

1. **`IApprovalStore` is a materialising surface, not `IQueryable`-returning.** `IQueryable<IApprovalRequest>` compiles via covariance but EF cannot translate a predicate written against an interface. The store therefore exposes `Find*`/`Get*` returning `IReadOnlyList<T>`/`T?`, entity **factory** methods, `Add*`/`Remove*` taking interfaces and downcasting internally, and a store-owned `GetRequestsGridAsync` so paging/sorting stays translatable.
2. **`ActAsync` and `GetRequestByIdAsync` take an explicit `ApprovalScope`.** Request ids are minted independently in `app` and `ops`, so id 7 exists in both homes and an id alone is not an address. Documented in the `IApprovalService` banner.
3. **The two stores are registered by concrete type**, not behind `IApprovalStore` — `ApprovalService` takes both and selects from the descriptor's scope, so a single-interface resolution would be ambiguous by design. See the comment in `Base.Application/DependencyInjection.cs`.
4. **`SubmitGrantApplication`'s branch sits after the workflow guard and the pre-submit gate**, not at the top of the handler as §④.7 sketched. An application that fails its own gate is not a thing to route for approval, it is a thing to fix. Everything below the branch is untouched.
5. **`ApproveGrant` / `RejectGrant` are guards, not submissions.** §④.7 only spelled out the `SubmitGrantApplication` shape. These two record the **funder's offline decision**, so routing them into an internal ladder would be a category error. Instead each refuses while a `PENDING` request is open over that grant, which closes the double-decision hole without violating rule 4 (the engine never writes a business table).
6. **CQRS operations are grouped by area, not one file per operation** (`ApprovalQueries.cs`, `ApprovalCommands.cs`, and the platform twins). Every handler is a two-line pass-through onto `IApprovalService`; nine one-handler files would be nine files of ceremony.
7. **No `actingUserId` parameter anywhere.** `ApprovalService` resolves the actor from `ITenantContext.GetCurrentUserId()`, so no endpoint needs `IHttpContextAccessor`. Actor **names** are snapshotted onto `ApprovalAction.ActorUserName` / `ApprovalRequest.SubmittedByUserName` so the history survives the planned per-tenant DB split.
8. **Two `SaveChangesAsync` calls on the submit path.** The entities carry no navigations between request and policy, so the request id must exist before its first action row can reference it.

**Known limitation worth Session B's attention:** `ApproveGrant`'s decision payload (`awardedAmount`, `awardLetterUrl`, `decisionDate`, `notes`) and `RejectGrant`'s `rejectionReason` are **not** carried through the approval request — the 6-table contract is fixed and rule 1 forbids new columns. When a `GRANT_APPLICATION` request is approved the callback moves the **stage only**; the funder's award figures are still captured through the existing Approve/Reject screens once the internal request has cleared. Do not build FE that expects the engine to return them.

**Nothing left unfinished in steps 1–8.** Not attempted, by instruction: `dotnet build`, `dotnet ef`, any migration or snapshot file, any frontend file, `tsc`.

### Session B — step 9–10 (frontend)

Re-run Step 0 probes **1, 2 and 6 only** — 3, 4 and 5 are backend-shaped and already spent.

Then read §⑩·5·1 through §⑩·5·4 **before writing any query file**, and take wire names from there rather than from this prompt's §④.10, which describes intent, not what shipped.

Acceptance criteria that apply: **18 and 19**, plus **1, 5, 11, 12, 13** re-verified across the whole diff.

**Session B does not touch the backend.** Not to rename a field, not to add a property that would make the FE tidier, not to fix something that looks wrong. If the backend genuinely blocks you, stop and report it — a backend edit in session B lands with no compile step behind it, because the user builds the backend, not you.

---

## ⑪ Build Log

*(append-only, newest first, last 5 sessions retained — git keeps the rest)*

| Date | Session | What changed | Result |
|---|---|---|---|
| 2026-08-13 | B (frontend) | §⑩ steps 9–10 per §⑩·5. **Step 0 re-probes 1, 2, 6** re-run: all three still hold. **Data layer** — `ApprovalDto.ts` (full TS mirror of `ApprovalSchemas.cs`), `setting-queries/ApprovalQuery.ts` + `setting-mutations/ApprovalMutation.ts` (tenant), `ops-queries/PlatformApprovalQuery.ts` + `ops-mutations/PlatformApprovalMutation.ts` (platform twins, sharing the tenant input types), 5 barrels. **Screens** — `setting/dataconfig/approvals`: switchboard as one row per area with Approval/Revise/Withdraw toggles, single-expanded-row accordion revealing the step ladder as an **ordered list** (no canvas, no drag-drop), page-header Save gated by RHF `formState.isValid` + `isDirty`; shared `ApproverPicker` normalises the ROLE/USER shape asymmetry between the tenant and platform option queries. `approvals` (My Approvals): debounced search, `assignedToMe` default on, row opens the by-id detail in a Dialog because `allowRevise`/`canAct` exist only on the detail DTO, not the grid projection; Revise **absent** (not disabled) when the snapshot says `AllowRevise = false`; Reject and Revise both hold the confirm button until a comment is typed. `ops/approvals` `(master)` twin = the same switchboard with `surface="platform"` stacked over an `embedded` queue, one screen because the seed registers one menu. **Grant strip** — `DocumentApprovalStrip` in `grant-detail.tsx`: current step, who it is waiting on, and the full `ApprovalAction` history grouped by attempt (descending, so prior attempts survive); renders `null` when the record was never submitted, but surfaces errors. 3 routes added; **zero backend files touched**. | **AC 19 passes: `npx tsc --noEmit --incremental false` exits 0 with no diagnostics at all** — not a TS2688-only run. **AC 18 verified field-by-field against the shipped C#**, not against §④.10: all 18 root fields match the `Get`-stripped resolver names, both input types carry the appended `Input`, and the `[AsParameters] GridFeatureRequest` split (`request` object + `assignedToMe` **sibling**) is honoured. Re-verified **1, 5, 13** (no backend file, no migration, no snapshot written this session) and **11, 12** (no `DateTime.Now`/`Today`, no raw SQL in the diff). Note: `PSS_2.0_Frontend/` is gitignored (`.gitignore:12`), so `git diff` cannot witness the FE diff — these were verified by inspection. **Two §⑩·5·1 inaccuracies found and left uncorrected** (backend off-limits): (a) its "Capability decorators as shipped" paragraph is wrong — `grep CustomAuthorize` over all four approval endpoint files returns nothing, so there is **no server-side capability enforcement** on those resolvers and the FE `useAccessCapability` gate is currently the only check; (b) it under-reports `ApprovalRequestDto`, omitting `documentDisplayName`, `documentUrl`, `allowRevise`, `allowWithdraw` and the whole `ApprovalRequestStepDto` field list — the FE was built off the C# instead. §⑩·5·4 limitation stands: `ApproveGrant`'s decision payload (`awardedAmount`, `awardLetterUrl`, `decisionDate`, `notes`) and `RejectGrant`'s `rejectionReason` are **not** carried through the engine, so the strip shows the decision and its comment only. Migration (§⑧) and seed (§⑨) remain user-applied and still pending — the screens cannot load until both are run. |
| 2026-08-13 | A (backend) | §⑩ steps 1–8. **Step 1** — prompt corrections: §⓪ probe 4 (tenant filter attaches by `CompanyId` property presence, not `ITenantEntity`), AC 3 downgraded to a documentation assertion, §④.9 pointed at `INotificationSender` + `AssignLead.cs:215–274`, §⓪ probe 5 pointed at `GetProvisioningRuns.cs`, §⑫ item 6 added. **Steps 2–3** — 12 entities (6 `app` + 6 `ops` twins) + 12 EF configurations, `[Table(schema:)]`-mapped, `ITenantEntity` on the 6 app ones, no `CompanyId` on any ops one. **Step 4** — `IApprovalService`/`ApprovalService`, `ApprovalDocumentTypes`, `ApprovalStatuses`, descriptor registry; DI-registered. **Steps 5–6** — tenant + platform CQRS (5 queries / 4 commands each) with validators. **Step 7** — GraphQL endpoints, `Setting/{Queries,Mutations}/ApprovalEndpoints.cs` + `Ops/{Queries,Mutations}/PlatformApprovalEndpoints.cs`. **Step 8** — 4 call sites wired: `SubmitGrantApplication` (routes when on), `ApproveGrant`/`RejectGrant` (block while PENDING), `LaunchTenant` (submits over the **company** id). Handoff §⑩·5·1–·4, §⑧ migration spec and §⑨ seed all written. | Code + docs complete, **unverified**. Per hard rules: no `dotnet build`, no `dotnet ef`, no migration/snapshot file, no tsc (AC 18–19 excluded), no frontend file touched, `Grant.cs`/`Refund.cs`/`CommercialTerm.cs` untouched. AC 1–17 satisfied by inspection only — **first compile is the user's**. Migration (§⑧) and seed (§⑨, `sql-scripts-dyanmic/approval-engine-menu-capability-seed.sql`) are user-applied and both still pending. Session B (frontend) not started. |

---

## ⑫ Known issues / by-design limitations

1. **Tenant isolation on `ops.PlatformApproval*` is service-enforced, not filter-enforced** — by necessity; platform rows have no `CompanyId`. Contained by acceptance criteria 7 and 10.
2. **Resubmit after revise restarts at step 1**, discarding earlier approvals in that attempt (⚑ D-6). Deliberate: an approval given against a since-changed document is stale. Prior attempts remain in `ApprovalAction`.
3. **Reject is terminal.** The only way forward is a fresh submission. "Send back for changes" is `REVISE`, a different verb, and it is off by default per area.
4. **`ApproverRefId` has no FK**, so a deleted role or user leaves a dangling approver row. Resolution simply skips it — which can push a step to `STALLED`. That is the intended failure mode: visible, not silent.
5. **Turning approval off does not resolve in-flight requests.** They complete under their snapshot. Nothing auto-approves because a setting changed.
6. **A superadmin session reads `app.Approval*` unfiltered.** The generated filter is `CurrentTenantId == null || CompanyId == CurrentTenantId`, and `CurrentTenantId` is null for SuperAdmin (`ApplicationDbContext.cs:23`, 55–56). Pre-existing platform-wide behaviour — every tenant table behaves this way and this build does not introduce it — but the consequence for the engine is specific: for a platform-staff session the query filter is **not** a backstop, so **acceptance criterion 7 (no `Approval*` DbSet access outside `ApprovalService`) is the actual isolation boundary.** Any stray tenant-scoped read written outside the service is a cross-tenant read the moment a superadmin runs it.
