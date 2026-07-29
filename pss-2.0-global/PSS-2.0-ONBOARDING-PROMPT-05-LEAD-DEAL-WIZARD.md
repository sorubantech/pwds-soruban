# DEV PROMPT P-05 — Lead + Commercial Term + O-01 Provisioning Wizard + welcome email (Phase B, assisted onboarding)

> Paste everything below the line into a **fresh development session**. It is self-contained.
> When done, report back the outcome to the PM session; do **not** proceed to P-06.

---

## Role & mission

You are a Senior Full-Stack Developer on the PSS 2.0 multi-tenant .NET + Next.js platform (**backend target framework `net10.0`**). Your task is **P-05: build the assisted (sales-led) onboarding front-of-funnel** that feeds the provisioning engine — the human workflow that turns a **WON lead** + an **APPROVED commercial term** into a one-click tenant provision.

Five deliverables:

1. **T-B1 — `ops.Lead` + `ops.CommercialTerm` entities** (+ EF config, DTOs, CRUD commands/queries). The Lead CRM is **deliberately thin** (per the GTM approach doc); the Commercial Term is the negotiated deal with a **discount-approval workflow**.
2. **T-B2 — S-01 Lead management screen** (control-plane / `(master)` surface).
3. **T-B3 — S-02 Commercial Term (deal) screen** with the discount-approval workflow.
4. **T-B4 — O-01 Provisioning Wizard** — a guided multi-step screen that takes a WON lead + APPROVED commercial term, assembles the `ProvisionTenant` payload, calls the **P-04 `ProvisionTenant` mutation**, and routes the operator to the **O-03 Run Monitor** (P-04) to watch the run.
5. **T-B6 — Welcome email** — finalize the `USER_WELCOME_INVITE` template P-03 step 9 sends, so its activation link points at the **P-04 `/activate` route** carrying the token.

The provisioning engine (P-03), its GraphQL API + O-03 monitor + activation endpoint (P-04), and the billing/pricing layer (P-02/P-02b) already exist. **You are building the funnel that feeds them — you are not changing the engine or its API.**

> ⚠️ **Depends on P-03 and P-04 having been run.** P-05's O-01 wizard **calls the P-04 `ProvisionTenant` mutation**, and T-B6 finalizes the email that points at the **P-04 activation route**. If those are not in the codebase, stop. If P-04's hand-back reported deviations from its spec (e.g. the `ProvisionTenantRequestDto` field set, where `InitiatedByUserId` was wired, or the activation route path), reconcile against the **real** mutation input + route before building the wizard/email.

## Read first (grounding — do not skip)

1. `PSS-2.0-ONBOARDING-TASK-LIST.md` — tasks **T-B1, T-B2, T-B3, T-B4, T-B6** are your scope.
2. `PSS-2.0-GTM-LEAD-ONBOARDING-AND-PRODUCT-ADMIN-APPROACH.md` — **§4/§5** (lead → deal → provision funnel), **§7** (the *Lead CRM is deliberately thin* — do not build a full CRM; ticketing/calendar/backup were rejected), **§11** (control-plane security). These are control-plane screens on the `(master)` surface, gated by `PLATFORM_*` capabilities.
3. `PSS-2.0-ONBOARDING-DQ7-PLATFORM-ROLES-MAP.md` — **DECIDED role matrix.** Sales owns leads + drafts deals; **Finance + Admin approve deals**; **Implementation + Admin provision**. Use this to assign the new capabilities to roles in the seed.
4. `PSS-2.0-ONBOARDING-P03-HANDBACK.md` + `PSS-2.0-ONBOARDING-PROMPT-04-PROVISIONING-API-AND-MONITOR.md` — the **`ProvisionTenantRequestDto` field set** the wizard must produce (note: **`CurrencyId` is an `int`**, not an ISO string), and the **activation route + `ActivateAccount` flow** the email links to. Ground the wizard's mutation call + the email link against the **real** P-04 output.
5. `PSS-2.0-ONBOARDING-P01-HANDBACK.md` / the P-01 model — `TenantProvisioningRun.LeadId` / `.CommercialTermId`, `Company.SourceLeadId`, `Subscription.CommercialTermId` were created as **nullable no-FK ints** pending these tables. P-05 introduces the tables; adding the real FKs is a **migration spec for the user** (see constraints).
6. **The real anchor files** (paths below) — a canonical CRUD entity/command/query/mutation, the multi-step form pattern, the email-template send path, and the `PLATFORM_*` seed pattern. Open each before writing; do not assume property names. Audit fields are `CreatedDate`/`ModifiedDate` (from `Entity` base).

## Hard constraints (violating any of these fails the task)

- 🔒 **Migrations are strictly user-owned.** Do **NOT** run `dotnet ef migrations add` / `database update` / `remove`, and do **NOT** hand-author a migration or model-snapshot file. P-05 **does** add schema (two `ops` tables + four FK activations). Build to prove the entities/config **compile**, then hand the user a **migration spec (markdown)** describing: the two new tables, and the four FK conversions on the existing nullable int columns (`TenantProvisioningRun.LeadId → ops.Leads`, `.CommercialTermId → ops.CommercialTerms`, `Company.SourceLeadId → ops.Leads`, `Subscription.CommercialTermId → ops.CommercialTerms`). The user authors, runs, and commits it.
- 🌱 **Seeds: you write (idempotent `INSERT … WHERE NOT EXISTS`), the user applies.** Do not execute SQL against any database.
- **All PKs/FKs are `int` identity.** `LeadId`, `CommercialTermId`, `CurrencyId`, `CountryId`, user ids — all `int`. No new Guid keys.
- **UTC only.** `timestamp with time zone`; write `DateTime.UtcNow`, build boundaries `DateTimeKind.Utc`; Npgsql throws on `Kind=Unspecified`.
- **🔑 Control-plane / null-tenant context.** `ops.Lead` and `ops.CommercialTerm` are **platform rows** (pre-tenant → `CompanyId` null / `IsSystem`). They inherit the global tenant query filter, so **every read uses `.IgnoreQueryFilters()` + an explicit `IsDeleted != true` guard**, exactly like the P-03/P-04 ops reads. On writes, do not expect the filter to stamp anything.
- **Verify every property/route name before use.** Read the entity/DTO/mutation first. The wizard's payload field names + the email's activation route must match **P-04 as-built**, not this brief's paraphrase.
- **Reuse-or-create for FE.** Search the component/screen registries first; reuse if found, create if missing-and-static, escalate only if missing-and-complex.
- **UI uniformity:** design tokens only (no hex/px), @iconify Phosphor icons, solid `bg-X-600 + text-white` status chips/badges, shaped skeletons, empty/error states, responsive.

## Codebase anchors (study these, then follow them)

- **A canonical CRUD slice** — e.g. `Base.Application/Business/Application/OrganizationBankAccount*/…` (entity + `IEntityTypeConfiguration` + DTO + `Create/Update/Delete` `ICommand` + `Get`/`GetById` `IQuery` + Mapster mapping + FluentValidation) and its `Base.API/EndPoints/Application/{Mutations,Queries}/OrganizationBankAccount*.cs` GraphQL wrappers. Mirror this shape for **Lead** and **CommercialTerm**.
- **Multi-step / wizard FE pattern** — search the FE for an existing stepper/wizard screen (a multi-page form with a review step) before building O-01; reuse the stepper primitive. If none exists, build a minimal step controller (steps + validation-gated Next + final Review→submit), following the form-fidelity + `formState.isValid`-gates-submit rules.
- **Email-template send path** — `IEmailTemplateService.SendEmailByTemplateKeyAsync(..., "USER_WELCOME_INVITE", ...)` (the call P-03 step 9 already makes). Find where email templates live (DB-seeded rows vs files) and the `USER_WELCOME_INVITE` key; T-B6 finalizes the **body + the activation link**, it does not re-plumb the send.
- **`PLATFORM_*` seed pattern** — `sql-scripts-dyanmic/ops-platform-rbac-seed.sql` (P-03/T-A9). Match its idempotent `NOT EXISTS` style, the module/menu/capability/role/role-capability shape, and the existing module id. Your new seed adds the **Lead / Deal / Wizard** menus + capabilities and grants them per DQ7 — it does **not** touch the existing PLATFORM_TENANT_* rows.
- **The provisioning contract (P-04)** — the `ProvisionTenant` mutation + its input DTO (fields must match `ProvisionTenantRequestDto`, `CurrencyId int`). The wizard's final step sends exactly this.

## Scope — build exactly this

### T-B1 · `ops.Lead` + `ops.CommercialTerm` (entities + EF config + DTOs + CRUD + seed)

**`ops.Lead`** (thin CRM — the WON lead that becomes a tenant):
- `LeadId int` PK; `CompanyName`, `ContactName`, `ContactEmail`, `ContactPhone?`; `CountryId int` FK → `com.Countries`; `Source string` (`INBOUND|OUTBOUND|REFERRAL|EVENT|OTHER`); `Status string` (`NEW|QUALIFIED|WON|LOST`); `OwnerUserId int?` (the sales rep); `EstimatedPlanCode string?`; `Notes string?`; `LostReason string?`; `ConvertedCompanyId int?` (stamped when the wizard provisions — this is the field P-03 step 9 referenced as a guarded no-op; it becomes real here). Plus `Entity` base (`CreatedDate/ModifiedDate/IsDeleted`).
- Lifecycle: `NEW → QUALIFIED → WON` (or `→ LOST` with `LostReason`). **Only a `WON` lead may be provisioned.** Provisioning is not part of Lead CRUD — the wizard (T-B4) drives it.
- CRUD: `Create/Update` (+ a status-transition command or a status field on update — keep it thin), `Get` (paginated, filter by Status/Owner/Source), `GetById`. No hard delete — soft-delete via `IsDeleted`.

**`ops.CommercialTerm`** (the negotiated deal + discount approval):
- `CommercialTermId int` PK; `LeadId int` FK → `ops.Lead`; `PlanCode string`; `CurrencyId int` FK → `com.Currencies`; `BillingCycle string`; `ListAmount decimal` (the catalog price, resolved from the P-02b price book via `IPlanPricingService`); `DiscountPercent decimal` (0–100); `DiscountAmount decimal`; `NetAmount decimal` (the negotiated price that the Subscription will ultimately snapshot); `TermMonths int?`; `PaymentGatewayCode string?`; `ApprovalStatus string` (`DRAFT|PENDING_APPROVAL|APPROVED|REJECTED`); `ApprovedByUserId int?`; `ApprovedOn DateTime?`; `RejectionReason string?`. Plus `Entity` base.
- **On create/update** in `DRAFT`, resolve `ListAmount` from `IPlanPricingService.ResolveAsync(PlanCode, CurrencyId, BillingCycle)` (fail-closed if null — unsellable combo), compute `DiscountAmount`/`NetAmount` server-side (never trust the client's math).
- **Discount-approval workflow (D-Q5 — configurable):**
  - A **`SubmitCommercialTermCommand`** moves `DRAFT → APPROVED` **automatically** when `DiscountPercent <= threshold`, else `DRAFT → PENDING_APPROVAL`.
  - The **threshold is a configurable platform policy**, not a hardcoded literal. Read it from the platform config mechanism (a platform-level `OrganizationSetting`/`IConfiguration` key, e.g. `PLATFORM_DISCOUNT_APPROVAL_THRESHOLD_PCT`), **default `15`**. Seed the default; the value is tunable without a code change. Do not bake the number into the handler.
  - An **`ApproveCommercialTermCommand(int CommercialTermId, bool Approve, string? RejectionReason)`** sets `APPROVED` (stamps `ApprovedByUserId` from the acting user via the HTTP `UserId` claim + `ApprovedOn`) or `REJECTED` (requires `RejectionReason`). Gated by the **deal-approve** capability (see seed) — per DQ7 that's **Finance + Admin**. A rejected/pending term cannot provision.
- CRUD: `Create/Update` (DRAFT only — approved terms are immutable), `Submit`, `Approve`, `Get` (filter by Lead/ApprovalStatus), `GetById`.

**Seed** — `sql-scripts-dyanmic/ops-lead-deal-rbac-seed.sql` (idempotent, matches `ops-platform-rbac-seed.sql`): new menus `PLATFORM_LEADS`, `PLATFORM_DEALS`, `PLATFORM_ONBOARDING` (the wizard), their capabilities — e.g. `PLATFORM_LEAD_VIEW/PLATFORM_LEAD_MANAGE/PLATFORM_LEAD_CONVERT`, `PLATFORM_DEAL_VIEW/PLATFORM_DEAL_MANAGE/PLATFORM_DEAL_APPROVE`, `PLATFORM_ONBOARD_RUN` — and the role→capability grants **per DQ7** (Sales: lead+deal manage; Finance+Admin: deal approve; Implementation+Admin: onboard-run + reuse existing `PLATFORM_TENANT_PROVISION`). Plus the default discount-threshold setting row. **Reconcile the exact capability codes + grants against DQ7** — do not invent grants it doesn't sanction.

### T-B2 · S-01 Lead management screen (control-plane)

A **thin** lead list + create/edit form on the `(master)` surface, gated `PLATFORM_LEAD_VIEW` (index) / `PLATFORM_LEAD_MANAGE` (create-edit). List with status chip (`NEW`/`QUALIFIED`/`WON`/`LOST`), owner, source, estimated plan, created date; filters by status/owner. Detail/edit form for the thin field set. A **"Convert / Provision"** entry point on a `WON` lead that launches the O-01 wizard (gated `PLATFORM_LEAD_CONVERT`). Do **not** build activity timelines, tasks, email threads, or any full-CRM surface — the doc explicitly scopes this thin.

### T-B3 · S-02 Commercial Term (deal) screen with approval

A deal list + form, gated `PLATFORM_DEAL_VIEW` / `PLATFORM_DEAL_MANAGE`. Create/edit a term **against a lead**: pick Plan + Currency (`CurrencyId int`) + BillingCycle → show the resolved **List amount** (from `IPlanPricingService`), enter **Discount %** → show computed **Discount amount + Net amount** (server-authoritative; the form previews, the BE decides). **Submit for approval** → auto-approves under the threshold, else moves to `PENDING_APPROVAL`. An **approval queue / action** (gated `PLATFORM_DEAL_APPROVE`, Finance+Admin) to Approve/Reject with a reason. Status chip: `DRAFT`/`PENDING_APPROVAL`/`APPROVED`(green)/`REJECTED`(grey). Approved terms are read-only.

### T-B4 · O-01 Provisioning Wizard

A guided multi-step control-plane screen, gated `PLATFORM_ONBOARD_RUN` (+ the command's own `PLATFORM_TENANT_PROVISION`), launched from a WON lead (S-01) or standalone:
- **Step 1 — Lead:** select/confirm a `WON` lead (block non-WON).
- **Step 2 — Commercial term:** select an **`APPROVED`** term belonging to that lead (block if none approved; deep-link to S-02 to create/submit one). Show plan/currency/net amount read-only.
- **Step 3 — Tenant details:** `CompanyCode`, `Subdomain` (validated — the P-03 BE validator enforces DNS-label + reserved blocklist + uniqueness; surface its error), `CompanyHeader`, `CompanyFooter`, `Address`, `CountryId` (prefilled from the lead), and the **admin** name + email (prefilled from the lead contact). No password field — activation is token-based.
- **Step 4 — Review & provision:** show the full payload; **submit → call the P-04 `ProvisionTenant` mutation** with a payload whose fields **exactly match `ProvisionTenantRequestDto`** (incl. `PlanCode`, `CurrencyId int`, `BillingCycle`, `PaymentGatewayCode?` from the term, `LeadId`, `CommercialTermId`, `Mode = "ASSISTED"`). On success → **route to the O-03 Run Monitor detail (P-04)** for the returned `RunId` so the operator watches the 9 steps.
- After a successful run start, the engine/DTO carries `LeadId` + `CommercialTermId` onto the run; **stamping `Lead.ConvertedCompanyId` + moving the lead to a terminal converted state** should happen server-side (either in the provision path if P-04/P-03 already wired it, or via a small post-provision command here) — verify which, and don't double-stamp.
- **Validation gates:** each step's Next is gated on that step's `formState.isValid`; the final Provision button is gated on the whole payload being valid (per the form-enablement rule — capability controls visibility, validity controls enablement).

### T-B6 · Welcome email

Finalize the `USER_WELCOME_INVITE` template (the one P-03 step 9 sends): a clean welcome body for the new tenant admin, with a **call-to-action link to the P-04 activation route** carrying the minted token (e.g. `https://{subdomain}.{appHost}/activate?token={token}` — **use the real route P-04 built**, verify it). If templates are DB-seeded, provide/refresh the seed row (idempotent); if file-based, update the template. Ensure the link host uses the tenant's subdomain. **No password is in the email — activation token only.**

## Out of scope for P-05 (do NOT build)

- **Go-live / `Company.Status → ACTIVE` / `OnboardedOn` flip** — that's P-06.
- **Changes to the P-03 engine steps or the P-04 mutations/queries/monitor/activation endpoint** — you consume them. (Fixing a genuine mismatch is fine, but flag it; don't silently rework.)
- **A full CRM** — activity timelines, tasks, sequences, email sync, pipelines/kanban. Lead stays thin.
- **Payment-gateway integration** — `PaymentGatewayCode` remains a captured string; no gateway calls.
- **Self-service (SELF_SERVICE mode) public signup** — this prompt is the **assisted** path only.
- **Re-seeding the existing `PLATFORM_TENANT_*` rows** — your seed only adds Lead/Deal/Wizard menus+caps+grants.

## Definition of done

1. Solution **builds clean** (`dotnet build` real exit 0 — not "only a pre-existing error remained"). **If the PM/user says they'll build it, prove correctness by reading and say the build was left to the user.**
2. **T-B1:** `ops.Lead` + `ops.CommercialTerm` entities + EF config compile; CRUD commands/queries + GraphQL wrappers exist; `CommercialTerm` computes List/Discount/Net **server-side** from `IPlanPricingService` (fail-closed on no price); the **submit → auto-approve-under-threshold / else PENDING_APPROVAL** logic reads a **configurable** threshold (default 15, seeded, not hardcoded); `Approve/Reject` stamps the acting user + gates on the deal-approve capability.
3. **Migration spec (markdown)** delivered for the two tables + the four FK activations (`TenantProvisioningRun.LeadId/CommercialTermId`, `Company.SourceLeadId`, `Subscription.CommercialTermId`). **No migration authored or run.**
4. **Seed** `ops-lead-deal-rbac-seed.sql` — idempotent; adds Lead/Deal/Wizard menus + capabilities + role grants **per DQ7** + the default discount-threshold row; does not touch existing PLATFORM_TENANT_* rows. **You wrote it; the user applies it.**
5. **T-B2 S-01** thin lead screen + **T-B3 S-02** deal screen with the approval workflow — both control-plane, capability-gated, honoring UI uniformity + reuse-or-create.
6. **T-B4 O-01 wizard** assembles a payload matching `ProvisionTenantRequestDto` (`CurrencyId int`, `Mode="ASSISTED"`, `LeadId`+`CommercialTermId`), **calls the P-04 `ProvisionTenant` mutation**, and routes to the **O-03 monitor** on success; step gates + provision-button enablement per the form rules; `Lead.ConvertedCompanyId` stamped exactly once (server-side — verify where).
7. **T-B6** welcome email links to the **real P-04 activation route** with the token; no password anywhere.
8. All ops reads use `.IgnoreQueryFilters()` + explicit `IsDeleted != true`.
9. A short **hand-back note**.

## Report back to the PM session

State: build clean (Y/N, or "left to user"); the two entities + CRUD + approval workflow (Y/N) and **where the discount threshold is read from** + its default; migration spec delivered for the 2 tables + 4 FKs (Y/N); seed written + which capabilities/grants you created (list them, and any place you had to reconcile against DQ7); S-01 + S-02 + O-01 done (Y/N); **the exact `ProvisionTenant` mutation input you sent** (field-by-field) and whether it matched `ProvisionTenantRequestDto` as-built; where `Lead.ConvertedCompanyId` gets stamped (server path vs a post-provision command here); the **activation route** the email links to (and whether it matched P-04); and **every property/table/route/capability name that differed from this brief**. **Do not start P-06.**
