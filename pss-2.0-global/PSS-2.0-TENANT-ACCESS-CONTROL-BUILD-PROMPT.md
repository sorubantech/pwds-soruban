# Tenant Access Control — platform-governed BUSINESSADMIN ceiling

> **Status:** NOT BUILT (written 2026-08-05)
> **Do NOT run before the MVP-1 demo (6 Aug 2026 17:00).** §③ needs a migration; there is no safe window.
> **Order:** after `PSS-2.0-EMAIL-PROVIDER-OWNERSHIP-BUILD-PROMPT.md`.
> **Prerequisite:** §⓪ Q1 answered. The whole build branches on it.

---

## ⚠️ Standing rules (non-negotiable)

1. **Do NOT run `dotnet build`.** The user builds the backend.
2. **Migrations are strictly user-owned.** Never run `dotnet ef migrations add/remove` or `database update`. Never hand-author a migration or a snapshot. Produce a **migration spec**; the user authors and applies it.
3. Seeds go to `sql-scripts-dyanmic/`. The user applies them.
4. Frontend typecheck: `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, **no pipe**. Only exit 0 counts.
5. `PSS_2.0_Backend/` and `PSS_2.0_Frontend/` are gitignored — Grep/Glob return nothing. Use `find -iname`, or scope `grep -rn --include=*.cs` to **one** project subdirectory. A repo-wide backend grep times out at 120 s. Absolute-path `Read` works.
6. HotChocolate strips `Get` from resolver names and appends `Input` to input types. tsc cannot see gql field names — a wrong name builds clean and fails only at runtime.
7. Every Postgres date column is `timestamp with time zone`. `DateTime.UtcNow` only; never `DateTime.Today` in an EF predicate.
8. `ops` / `billing` are platform-global: every read needs `IgnoreQueryFilters()` **and** an explicit `IsDeleted != true` guard.
9. Never assume a GraphQL field, DTO property, or column name — read the source first.
10. SUPERADMIN is never revoked and never overwritten. In SQL, match it by `RoleCode` **alone** — joining `AND r."CompanyId" IS NULL` has silently inserted zero rows in this database.
11. Widget/KPI icon containers and status badges: solid `bg-X-600` + `text-white`. Never `bg-X-50/100`, `text-X-700/800`, or `bg-muted`.
12. RBAC writes are **soft-delete only** (`IsDeleted = true, IsActive = false`). Never `DELETE`. Never revoke a grant until its replacement is written in the same transaction.

---

## §⓪ The blocking question — answer before writing any code

```sql
SELECT c."CompanyName", r."RoleId", r."RoleCode", r."CompanyId", r."IsSystem", r."IsPlatform"
FROM auth."Roles" r
LEFT JOIN app."Companies" c ON c."CompanyId" = r."CompanyId"
WHERE r."RoleCode" = 'BUSINESSADMIN' AND r."IsDeleted" IS DISTINCT FROM true
ORDER BY r."CompanyId" NULLS FIRST;
```

| Result | Consequence |
|---|---|
| Every tenant's BUSINESSADMIN has `IsSystem = false` | §④.1 is a no-op. Skip it. Everything else still builds. |
| Any tenant's BUSINESSADMIN has `IsSystem = true` | §④.1 is **mandatory and first**. Until it lands, the Access tab cannot see the role this whole feature exists to govern. |

Record the answer in §⑩ before proceeding.

---

## §① The problem

The platform sells access. Today it cannot reliably adjust it after the sale.

### Defect 1 — the tab is probably blind to the only role that matters

A tenant's permission structure is a tree with one root. Platform grants capabilities to **BUSINESSADMIN**; that tenant's admin then creates their own roles and hands out subsets. So BUSINESSADMIN is the tenant's **ceiling**. Govern it and you govern the tenant.

The Access tab excludes it.

| File | Line | Behaviour |
|---|---|---|
| `Base.Application/Business/OpsBusiness/PlatformRbac/Queries/GetTenantRoleMatrix.cs` | 136 | `&& r.IsSystem != true` — system roles are dropped as **columns** |
| `Base.Application/Business/OpsBusiness/PlatformRbac/Commands/OverrideTenantRoleCapability.cs` | 104 | write path throws `SYSTEM_ROLE_NOT_OVERRIDABLE` |
| `Base.Application/Business/OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs` | 643 | `Role.Create(…, tr.IsSystem, …)` — **`IsSystem` is copied from the template company** |

Five files in `OpsBusiness` state it directly: *"BUSINESSADMIN and SYSTEMROLE are company-less TENANT system roles."* If the `__TEMPLATE__` row carries `IsSystem = true`, every provisioned tenant inherits it and the exclusion bites.

The exclusion is not wrong in origin — it was written to stop an operator editing a **global** row (`CompanyId IS NULL`) and silently changing every tenant at once. That danger is real. The fix is to narrow the rule to what it was actually protecting, not to delete it.

### Defect 2 — the ceiling is not enforced

Nothing stops a tenant's BUSINESSADMIN granting one of their own roles a capability that BUSINESSADMIN itself does not hold. The tenant-side write commands live in `Base.Application/Business/AuthBusiness/RoleCapabilities/Commands/` — eleven of them, including `BulkUpdateRoleCapabilityMatrix`, `GrantCapabilityToAllRoles`, `CopyRoleCapabilities`, `ResetRoleCapabilityMatrix`. **Verify each one before assuming**; none was found to check a ceiling.

Consequence: the platform revokes a capability from BUSINESSADMIN, and a sub-role created earlier keeps it. The revoke looks applied and is not.

### Defect 3 — no time-boxed access

The stated business case: *"sometimes for certain days they can ask for a feature, we give that access."* Today that grant is permanent. Someone must remember to take it back, and nobody does. Trials become free features.

### Defect 4 — tabs work on tenants that do not exist yet

`/ops/tenants/{companyId}` renders every tab regardless of `Company.Status`. A tenant mid-provisioning has no roles and no subscription, so the tabs show empty panels — indistinguishable from a broken screen — and the Access tab invites an operator to edit a BUSINESSADMIN that Step 3 has not created yet. A churned tenant is fully editable, which is worse: changing access on an account that no longer pays is silent, unbilled work. Fixed by §②.1b.

### Defect 5 — two list pages, one of them better

`tenant-list-page.tsx` (236 lines) and `tenant-access-landing-page.tsx` (259 lines) run the same `TENANTS_QUERY` over the same columns with the same paging. Nearly 500 lines to render one table twice, and the two drift independently.

The access page is the better of the two: it explains itself in the header, warns up front when the operator is read-only, and offers a per-row action. Its structure is what survives; the tenant list adopts it. Fixed by §②.1a.

### Defect 6 — two menus for one screen ✅ already fixed

`sql-scripts-dyanmic/platform-tenant-access-menu-hide-seed.sql` (written 2026-08-05) drops the duplicate sidebar entry and keeps every grant. **Confirm it was applied**; do not rewrite it. All tenant surfaces stay as tabs of `/ops/tenants/{companyId}`.

---

## §② The design

### ②.1 One screen, tabs only — a **complete** move

`/ops/tenants/{companyId}` is the **only** tenant surface. **This build creates no new tabs.** All seven already exist in `tenant-detail-page.tsx:114-120` and stay exactly as they are:

| `value` | Label | Currently gated by |
|---|---|---|
| `overview` | Overview | always visible |
| `features` | Features | `canSeePlans` |
| `usage` | Usage | `canSeePlans` |
| `payments` | Payments | `canSeeBilling` |
| `provisioning` | Provisioning | `canProvision` |
| `audit` | Audit | always visible |
| `access` | Access | `canSeeAccess` |

Access lives here — beside plan, usage and billing — because a permission decision needs the customer's plan and behaviour visible next to it.

The change is to **what the Access tab can do** (§②.2 onward) and **when tabs are usable** (§②.1b), not to the tab set. The existing `.filter((t) => t.visible)` capability gating stays; §②.1b adds a second, independent axis on top of it.

### ②.1a The Tenant Access Control **structure is kept** — it absorbs the tenant list

This is a **merge, not a deletion**. The Tenant Access Control screen's structure is the one to keep; the Tenants list surrenders its own and takes it on.

The two list pages are near-identical clones today — same `TENANTS_QUERY`, same page size, same table, same paging:

| | `tenant-list-page.tsx` (236 lines) | `tenant-access-landing-page.tsx` (259 lines) |
|---|---|---|
| Gate | `PLATFORM_TENANTS` / `canView` | `PLATFORM_TENANT_ACCESS` / `PLATFORM_TENANT_ACCESS_VIEW` |
| Sort | `onboardedOn` desc | `companyName` asc |
| Columns | tenant, subdomain, plan, status, onboarded | tenant, subdomain, plan, status, **Access action** |
| Read-only banner | ✗ | ✓ — explains the missing `PLATFORM_TENANT_RBAC_OVERRIDE` |
| Row click | → `/ops/tenants/{id}` | → `/ops/tenants/{id}?tab=access` |

**Result: one list page, `tenant-list-page.tsx`, carrying the access page's structure.** Specifically, port these in — they are the parts that made that screen better:

1. **The shield-framed header** (`bg-amber-600` icon container + subtitle explaining what the screen governs). Retitle to "Tenants"; the subtitle covers both jobs.
2. **The read-only banner** (`tenant-access-landing-page.tsx:126-140`) — shown when the operator lacks `PLATFORM_TENANT_RBAC_OVERRIDE`. Its own comment states the reason and it is right: *an operator who arrives expecting to edit and finds switches disabled should learn why here, not by clicking.*
3. **The row action column**, capability-driven: "Manage"/"View" → `?tab=access` when they hold `PLATFORM_TENANT_ACCESS_VIEW`; otherwise the plain row click to the Overview tab.
4. **The empty/error/skeleton states** — the access page's are more specific ("Tenants appear here once a provisioning run succeeds"). Keep those strings.
5. **Provisioning entry points** (§②.1c) — new, neither page has them.

Then, and only then:

| Artefact | Action |
|---|---|
| `PLATFORM_TENANT_ACCESS` sidebar entry | Hidden by the §① Defect-6 seed — already done |
| `tenant-access-landing-page.tsx` | **Delete — after** items 1-4 are ported into `tenant-list-page.tsx`. Deleting first loses the structure the user asked to keep |
| The `/ops/tenant-access` route directory | **Delete.** Deep links `?tab=access` still work; only the picker's own URL goes |
| Its export in `ops/tenants/index.ts:9` | **Remove** |
| Stale comments at `index.ts:7-8`, `platformstaff/index.ts:13`, `platform-staff-page.tsx:23`, `tenant-detail-page.tsx:126` | **Update** — they describe the two-door design |
| `auth."Menus"` row `PLATFORM_TENANT_ACCESS` | **KEEP.** It anchors `PLATFORM_TENANT_ACCESS_VIEW` and `PLATFORM_TENANT_RBAC_OVERRIDE`; `auth."RoleCapabilities"` is keyed by `MenuId`, so deleting the row destroys the exact authority this build governs |

Two capability gates on one page is intentional. `PLATFORM_TENANTS` decides who sees the list; `PLATFORM_TENANT_ACCESS_VIEW` decides who sees the access affordances on it. Someone who may browse tenants does not thereby get a way into their permissions — that separation exists today and must survive the merge.

**Do not add a second menu. Do not add a second matrix.**

### ②.1c Provisioning options on the list

The list is where an operator notices a tenant is stuck, so the provisioning actions belong there rather than three clicks away.

Add to each row, gated on `PLATFORM_TENANT_PROVISION` (**verify the exact capability code against `tenant-provisioning-tab.tsx` — do not assume it**):

| Row state | Action |
|---|---|
| `PROVISIONING` | **Resume provisioning** → `/ops/tenants/{id}?tab=provisioning`. Show the failed step name if the run is paused |
| `PROVISIONING` | **Resend activation** — the mutation already exists (`RESEND_TENANT_ACTIVATION_MUTATION`, `tenant-detail-page.tsx:105`) and is already correctly limited to `PROVISIONING` |
| any | **Open** → Overview tab |
| `ACTIVE` / `SUSPENDED` | **Manage access** → `?tab=access` |

Add a status filter row above the table — All / Provisioning / Active / Suspended / Churned — defaulting to All. "Which tenants are stuck?" is the question this screen gets asked most, and today it can only be answered by reading every page.

Reuse the existing pagination and `TenantStatusChip`. Do **not** introduce `AdvancedDataTable` — both pages are deliberately developer-owned lists mirroring the P-04 provisioning-run pattern, and switching engines mid-merge is a second risk on top of the first.

### ②.1b Tabs are disabled until the tenant is onboarded

A half-provisioned tenant has no roles, no subscription and no usage. Its tabs would render empty panels that read like bugs, and the Access tab would offer to edit a BUSINESSADMIN that does not exist yet.

The signal is on the tenant record itself — `TenantDetailResponseDto.Status` (`PROVISIONING | ACTIVE | SUSPENDED | CHURNED`, `Base.Application/Schemas/OpsSchemas/TenantSchemas.cs:21`) and `OnboardedOn`.

| Status | `overview` | `features` | `usage` | `payments` | `provisioning` | `audit` | `access` |
|---|---|---|---|---|---|---|---|
| `PROVISIONING` / `OnboardedOn IS NULL` | ✅ | ⛔ | ⛔ | ⛔ | ✅ | ✅ | ⛔ |
| `ACTIVE` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `SUSPENDED` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `CHURNED` | 👁 | 👁 | 👁 | 👁 | 👁 | ✅ | 👁 |

✅ enabled · ⛔ greyed with reason · 👁 read-only (visible, no writes)

Three deliberate calls:
- **Provisioning stays enabled while provisioning** — it is the tab that tells the operator *why* the tenant is stuck.
- **Audit is always enabled**, in every state. It is read-only by nature and is the first thing anyone opens when something looks wrong.
- **Suspended keeps everything writable** — suspension is exactly when support needs to inspect and adjust access.

This axis is independent of the capability gating already at `tenant-detail-page.tsx:121`. A tab must pass **both**: the operator holds the capability, **and** the tenant's status permits it.

Enforce in **both** places: the tab disables in the UI, and the handlers refuse. A disabled tab is a hint; `OverrideTenantRoleCapability` must reject a write against a `PROVISIONING` or `CHURNED` tenant with `TENANT_NOT_ONBOARDED` / `TENANT_CHURNED`. Read `GetTenantById.cs` first — do not assume how `Status` is populated.

### ②.2 The ceiling model

```
        platform staff
              │  grants / revokes / time-boxes
              ▼
   BUSINESSADMIN  ── the tenant's ceiling ──┐
              │                             │
              │ tenant admin grants subsets │  no sub-role may exceed it
              ▼                             │
   FINANCEMANAGER · FUNDRAISER · … ◄────────┘
```

Two rules, both enforced server-side:

1. **Envelope** — the tenant's maximum is exactly the set of `(MenuId, CapabilityId)` pairs BUSINESSADMIN holds with `HasAccess = true`.
2. **Clamp** — when the platform revokes a pair from BUSINESSADMIN, every sub-role of that tenant loses it in the same transaction.

Without rule 2, rule 1 only governs future writes and every historic over-grant survives. Build both or neither.

### ②.3 Why the ceiling is enforced in the backend only

A frontend check is a courtesy. The tenant's admin reaches these mutations directly. Enforce in one shared guard that every write path calls — see §④.3.

### ②.4 Time-boxed grants

A grant gains an optional expiry. On expiry it reverts to `HasAccess = false`, with an audit row saying it expired rather than that a human revoked it.

**Expiry is evaluated on read, not by a background job.** A job that fails leaves the tenant holding a feature they stopped paying for; a read-time check cannot silently not-run. Add a sweep later if the audit trail needs the revoke recorded at the moment it happens.

### ②.5 What platform staff must not be able to do

| Forbidden | Why |
|---|---|
| Edit a role where `CompanyId IS NULL` | Global row — one write hits every tenant. This is the danger the original `IsSystem` filter existed to prevent. |
| Edit SUPERADMIN by any path | Rule 10 |
| Edit a role where `IsPlatform = true` from the tenant tab | Control-plane roles are not tenant roles |
| Write access for a tenant still `PROVISIONING`, or `CHURNED` | §②.1b — nothing to govern yet, or nothing left to govern |
| Grant a capability the tenant's **plan** does not include | Entitlement and RBAC are separate gates; RBAC must not become a way to sell around the plan. See §②.6 |

### ②.6 Plan entitlement vs RBAC — keep them separate

They answer different questions and both must pass.

| Gate | Question | Source |
|---|---|---|
| **Entitlement** | did this tenant *buy* it? | `billing.FeatureMenuMaps` via `IPlanMenuFilter` |
| **RBAC** | may this *role* do it? | `auth.RoleCapabilities` |

A temporary feature trial (§②.4) is an **entitlement** decision that is being expressed through RBAC. That is acceptable only when the menu is inside the tenant's plan. If it is not, the correct instrument is a plan or feature override, not a capability grant.

**Therefore:** §④.4 must reject a grant on a menu blocked by `IPlanMenuFilter`, with an error naming the plan. If the operator genuinely wants to sell a trial feature, that belongs on the subscription tab. Read `IPlanMenuFilter` before implementing — reuse it, do not reimplement it, since the sidebar and the role matrix already both call it and a third opinion would be a support ticket.

---

## §③ Schema — migration spec (user-owned, do NOT author)

Produce the spec; the user writes and applies the migration.

### ③.1 `auth."RoleCapabilities"` — three new nullable columns

| Column | Type | Null | Purpose |
|---|---|---|---|
| `ExpiresOn` | `timestamp with time zone` | yes | when a time-boxed grant lapses. `NULL` = permanent (every existing row) |
| `GrantedByPlatformUserId` | `integer` | yes | which platform staff member granted it. `NULL` = tenant-side or seeded |
| `GrantReason` | `text` | yes | free text captured at grant time |

All nullable, so the migration is additive and every existing row keeps its meaning. **No backfill.**

Index: `("ExpiresOn") WHERE "ExpiresOn" IS NOT NULL` — the read-time check filters on it and the partial index keeps it off the hot path for permanent grants.

### ③.2 No new table

An expiring grant is still a grant. A parallel table would mean two sources of truth for one question, and the ceiling query would have to union them.

### ③.3 Verify before building

```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'auth' AND table_name = 'RoleCapabilities'
  AND column_name IN ('ExpiresOn','GrantedByPlatformUserId','GrantReason');
```
Zero rows means the migration has not been applied. **Stop.** A mapped property with no column throws on every EF read of `auth."RoleCapabilities"` — which is the login path.

---

## §④ Backend

### ④.1 Make BUSINESSADMIN visible — **only if §⓪ says `IsSystem = true`**

Replace the blunt exclusion with the rule it was standing in for.

`GetTenantRoleMatrix.cs:133-136` — the filter becomes: role belongs to **this** company (`r.CompanyId == context.CompanyId`, which already excludes `NULL`), is not platform, and is not SUPERADMIN by `RoleCode`. Drop `r.IsSystem != true`.

The `CompanyId` equality already does the protective work: a global row has `CompanyId IS NULL` and can never match. Keep `IsSystem` in the projection — the frontend needs it for §⑥.2.

`OverrideTenantRoleCapability.cs:104` — same narrowing. Replace the `IsSystem` rejection with a rejection of `role.CompanyId is null`, error code `GLOBAL_ROLE_NOT_OVERRIDABLE`. Keep the SUPERADMIN guard at `:97` exactly as it is.

Update the comment blocks in both files. They currently explain a rule that will no longer be the rule; a stale comment here is how the exclusion comes back.

### ④.2 Ceiling query — one helper, one definition

Add to `Base.Application/Business/OpsBusiness/PlatformRbac/` a service returning the tenant's envelope: the `(MenuId, CapabilityId)` set held by that company's BUSINESSADMIN with `HasAccess = true`, `IsDeleted != true`, and either `ExpiresOn IS NULL` or `ExpiresOn > DateTime.UtcNow`.

Follow the shape of `IPlanBaselineApplier` (`Base.Application/Interfaces/IPlanBaselineApplier.cs`) — interface in `Interfaces/`, implementation beside the handlers, registered in DI the same way. Read that file first and match it.

Resolve BUSINESSADMIN by `RoleCode` within the company. If the tenant has no such role, return an **empty** envelope and log a warning. Empty means every sub-role write is refused, which is the safe direction; a tenant with no BUSINESSADMIN is already broken.

### ④.3 Enforce the ceiling on tenant-side writes

Every command in `Base.Application/Business/AuthBusiness/RoleCapabilities/Commands/` that can set `HasAccess = true` must call §④.2 first and reject pairs outside the envelope.

**Read all eleven before editing.** At minimum: `BulkUpdateRoleCapabilityMatrix`, `CreateRoleCapability`, `UpdateRoleCapability`, `UpdateRoleCapabilityAccess`, `GrantCapabilityToAllRoles`, `CopyRoleCapabilities`, `ResetRoleCapabilityMatrix`, `ResetRoleCapabilityMatrixForRole`. `Roles/Commands/CreateRole.cs` too if it seeds capabilities.

Rules:
- The check applies when the actor is **tenant-side**. A platform operator editing BUSINESSADMIN itself is the act of moving the ceiling and must not be checked against it.
- BUSINESSADMIN is not checked against its own envelope.
- Error `EXCEEDS_TENANT_CEILING`, naming the menu and capability. A silent drop makes the tenant's admin think the save worked.

Batch commands: reject the **whole batch**, do not partially apply. A half-applied matrix is worse than a refused one.

### ④.4 Platform grant with expiry and reason

Extend `OverrideTenantRoleCapability` — do not add a parallel command.

New optional inputs: `expiresOn`, `reason`. Behaviour:
- `expiresOn` must be in the future (compare against `DateTime.UtcNow`; reject `Kind == Unspecified` per rule 7, or normalise at handler entry).
- `reason` stays mandatory — the existing UI already demands one.
- Write `GrantedByPlatformUserId` from the current platform user.
- **Reject any grant on a menu blocked by `IPlanMenuFilter`** per §②.6, error `MENU_NOT_IN_PLAN` naming the plan.

### ④.5 Clamp on revoke

When the platform sets `HasAccess = false` on a BUSINESSADMIN pair, revoke the same pair on every other non-platform role of that company in the **same transaction**.

Soft-delete semantics per rule 12. One platform audit row for the ceiling change, plus one tenant audit row per clamped sub-role — the tenant must be able to see why their role lost a permission, or it reads as data loss.

Return the clamped count so §⑥.3 can warn before the operator commits.

### ④.6 Expiry on read

Every read that decides access must treat an expired grant as absent: `ExpiresOn IS NULL OR ExpiresOn > now()`.

Audit these and fix each: `GetRoleCapabilityByUser`, `GetParentChildMenu` (the `ISMENURENDER` join at `GetParentChildMenu.cs:64-79`), `GetRoleCapabilityMatrix`, `GetTenantRoleMatrix`, plus `IPlanBaselineApplier` if it reads existing grants for idempotency.

**Missing one of these is the whole feature failing silently** — the grant looks expired on the platform screen and still works in the tenant's sidebar.

### ④.6b Onboarding gate on the write path

`OverrideTenantRoleCapability` resolves the target company's `Status` before doing anything else and refuses:

- `PROVISIONING`, or `OnboardedOn IS NULL` → `TENANT_NOT_ONBOARDED`
- `CHURNED` → `TENANT_CHURNED`
- `SUSPENDED` → **allowed.** Adjusting a suspended tenant's access is a normal support action

`GetTenantRoleMatrix` still **returns** the matrix for those states — the operator must be able to see the current access even when they cannot change it. Add a read-only flag to the response so §⑥.6 can render the reason instead of guessing from `Status`.

### ④.7 GraphQL surface

Extend the existing `overrideTenantRoleCapability` mutation with the new optional inputs. Add expiry fields to the tenant role matrix response DTO so the tab can render them.

Rule 6 applies: `Get` is stripped, `Input` is appended. Verify each field name against the schema file, not against memory.

---

## §⑤ Audit

Reuse `IPlatformAuditWriter` (`Base.Application/Interfaces/IPlatformAuditWriter.cs`). Read it before use — its `entityType` parameter has a documented allowed set.

Every ceiling change writes to **both** logs: the platform's, and the tenant's own audit so their admin can see what changed and when. Record: role, menu, capability, before, after, expiry, reason, actor.

Expiry-driven reversion (§②.4) is recorded as expired, not as a human revoke.

---

## §⑥ Frontend

All work in `PSS_2.0_Frontend/src/presentation/components/page-components/ops/tenants/tenant-access-tab.tsx` (311 lines). Read it fully first — it already has the enable-override switch, the per-cell reason dialog and one-write-per-cell semantics. **Extend that; do not restructure it.**

### ⑥.1 BUSINESSADMIN is the first column

Pin it leftmost and label it as the tenant's ceiling. It is the column operators will use most; making them hunt for it among ten roles is how the wrong cell gets clicked.

### ⑥.2 Say what a cell means

A short panel above the matrix: this row is the ceiling; the tenant's other roles can only be given what the ceiling holds. Two or three sentences. Without it an operator reasonably assumes the columns are independent.

Use `isSystem` from the DTO to mark the ceiling column, not a hard-coded `RoleCode` string in the UI.

### ⑥.3 Revoke confirmation shows the blast radius

When revoking on BUSINESSADMIN, the existing reason dialog also shows how many sub-roles will lose the capability (from §④.5). Solid `bg-amber-600` warning banner, rule 11.

### ⑥.4 Temporary grant

In the same dialog, an optional expiry date. Default off — permanent stays the normal case, and a required date would get filled with a guess.

Granted cells with an expiry render a distinct chip showing the date. Expired cells render as off, with the lapsed date visible — the operator needs to know it *was* granted, or a renewal request looks like a first request.

### ⑥.5 Merge the two list pages — port first, delete second

Implement §②.1a in `tenant-list-page.tsx`. **Order matters:** port items 1-5, typecheck, confirm the merged list works, *then* delete `tenant-access-landing-page.tsx` and its route. Deleting first throws away the structure being preserved and leaves nothing to copy from.

Then fix the four stale comments — leaving them is how the second door gets rebuilt in six months.

No tab is removed from `/ops/tenants/{companyId}`. Access is not promoted out of it into a menu.

### ⑥.5b Provisioning actions on the list

Implement §②.1c. `RESEND_TENANT_ACTIVATION_MUTATION` already exists and already guards on `PROVISIONING` both client- and server-side — reuse it, do not write a second path. Verify the provisioning capability code in `tenant-provisioning-tab.tsx` before gating on it.

### ⑥.6 Tab gating by onboarding status

Implement §②.1b in `tenant-detail-page.tsx`. Rules:

- A disabled tab stays **visible and greyed**, never hidden. An operator who cannot see the Access tab files a bug; one who sees it greyed with "available once provisioning completes" understands the system.
- The reason appears on hover *and* as a line in the panel if the tab is somehow reached by URL — deep links exist.
- `CHURNED` renders every tab read-only: no toggles, no override switch, no action buttons.
- Drive this from the `Status` already returned by the tenant detail query. Do not add a second fetch.

Status chip in the page header: solid backgrounds per rule 11 — `bg-amber-600` PROVISIONING, `bg-emerald-600` ACTIVE, `bg-red-600` SUSPENDED, `bg-slate-600` CHURNED, all `text-white`.

---

## §⑦ Explicitly NOT in this prompt

| Excluded | Why |
|---|---|
| A second Tenant Access menu | The whole point is one menu |
| Per-tenant plan/feature override UI | Entitlement layer, separate build (§②.6) |
| Background expiry sweep job | §②.4 — read-time is the correct default |
| Bulk clamp across many tenants at once | `RbacRolloutRun` territory; blast radius too large without a preview UI |
| Deleting the `auth."Menus"` row for `PLATFORM_TENANT_ACCESS` | It anchors the two capabilities. §②.1 |
| Changing `ProvisionTenant`'s `IsSystem` clone | Would fix new tenants and leave every existing one broken. §④.1 fixes both |

---

## §⑧ Acceptance

★ = security-critical, must be tested deliberately.

1. ☐ §⓪ query run, result recorded in §⑩
2. ☐ Migration applied; §③.3 returns three rows
3. ☐ BUSINESSADMIN appears as a column in the Access tab
4. ★ ☐ A role with `CompanyId IS NULL` never appears as a column
5. ★ ☐ SUPERADMIN cannot be written by any path
6. ★ ☐ A platform role (`IsPlatform = true`) never appears in the tenant tab
7. ☐ Platform can grant a capability to BUSINESSADMIN; the tenant's admin sees it
8. ★ ☐ Tenant admin granting a sub-role a capability outside the envelope is refused with `EXCEEDS_TENANT_CEILING`
9. ★ ☐ Batch write containing one out-of-envelope pair is refused **entirely**
10. ★ ☐ Platform revoking from BUSINESSADMIN clamps every sub-role in the same transaction
11. ☐ Clamp count shown in the confirm dialog matches the rows actually changed
12. ☐ Time-boxed grant works before its expiry
13. ★ ☐ After expiry it is denied on **every** §④.6 read path — including the tenant's sidebar
14. ★ ☐ Grant on a menu outside the tenant's plan is refused with `MENU_NOT_IN_PLAN`
15. ☐ Every ceiling change appears in both the platform and the tenant audit log
16. ☐ Expiry reversion is audited as expired, not as a revoke
17. ☐ Sidebar still shows exactly one tenant menu
18. ☐ All seven tabs present on `/ops/tenants/{companyId}`
19. ☐ One list page only; `tenant-access-landing-page.tsx`, its route and its export are gone; `npx tsc` still exits 0
19a. ☐ The merged list carries the ported header, read-only banner, access action column and empty-state strings from the old access page
19b. ★ ☐ An operator with `PLATFORM_TENANTS` but **not** `PLATFORM_TENANT_ACCESS_VIEW` sees the list with **no** access affordances and cannot reach `?tab=access`
19c. ☐ Status filter (All / Provisioning / Active / Suspended / Churned) works and defaults to All
19d. ☐ Resume-provisioning and resend-activation appear only on `PROVISIONING` rows, only with the provisioning capability
20. ☐ A `PROVISIONING` tenant shows Identity + Provisioning enabled, every other tab greyed with a reason
21. ★ ☐ An override write against a `PROVISIONING` tenant is refused with `TENANT_NOT_ONBOARDED` — tested by calling the mutation directly, not through the greyed UI
22. ★ ☐ Same for `CHURNED` → `TENANT_CHURNED`
23. ☐ A `SUSPENDED` tenant has all tabs enabled and writable
24. ☐ A `CHURNED` tenant renders every tab read-only, no action buttons
25. ☐ `npx tsc --noEmit --incremental false` exits **0**
26. ☐ Backend compiles — **user runs this**

---

## §⑨ Open questions

| # | Question | Blocks |
|---|---|---|
| **Q1** | **§⓪ — is BUSINESSADMIN `IsSystem = true`?** | §④.1. Answer before starting |
| Q2 | On expiry, revert to `HasAccess = false`, or soft-delete the row? Recommend **revert** — history stays, renewal is a flip | §④.6 |
| Q3 | Should the clamp (§④.5) also apply when a grant expires? Recommend **yes**, or an expired ceiling leaves sub-roles above it | §④.5 |
| Q4 | Should a tenant's admin see *why* a capability is unavailable — "not in your plan" vs "not granted"? Recommend yes, but it exposes plan structure | §④.3 |
| Q5 | Max expiry length? An unbounded date makes "temporary" meaningless. Recommend a 90-day cap, overridable by PLATFORM_ADMIN | §④.4 |
| Q6 | Does a suspended tenant's ceiling still apply, or is suspension entirely separate? | §②.5 |
| Q7 | Is `Company.Status` reliably `PROVISIONING` for in-flight tenants, or do some sit at `ACTIVE` with `OnboardedOn IS NULL`? Run the query below. The gate uses whichever is truthful — recommend **both** conditions | §②.1b, §④.6b |
| Q8 | Should a `CHURNED` tenant's tabs be read-only (recommended) or hidden entirely? | §⑥.6 |

```sql
SELECT "Status", COUNT(*), COUNT("OnboardedOn") AS with_onboarded_on
FROM app."Companies"
WHERE "IsDeleted" IS DISTINCT FROM true
GROUP BY "Status" ORDER BY 2 DESC;
```

---

## §⑩ Build log

| Date | Section | What was done | Result |
|---|---|---|---|
| 2026-08-05 | §① Defect 6 | `platform-tenant-access-menu-hide-seed.sql` written | Written, **user has not confirmed applying it** |
| | §⓪ | Q1 query result | |
