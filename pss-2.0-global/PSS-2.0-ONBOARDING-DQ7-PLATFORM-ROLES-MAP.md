# D-Q7 — Who owns onboarding → `PLATFORM_*` roles map (decision brief)

> ✅ **DECIDED 2026-07-24.** All three forks confirmed as recommended: **5 roles** (Sales / Implementation / Support / Finance / Admin); provisioning trigger held by **Implementation + Admin only**; P-03 seeds **capabilities + role bundles**. The "Recommended default role → capability matrix" below is now the seed spec for P-03.
>
> **Implementation note carried into P-03 (discovered while grounding the prompt):** the live RBAC model is **menu-scoped** — `auth.RoleCapability(RoleId, MenuId, CapabilityId, HasAccess)`, enforced by `CustomAuthorizeService.HasAccessAsync(userId, menuCode, capabilityCode)`. `CapabilityCode` is free varchar, so `PLATFORM_TENANT_PROVISION` slots in cleanly **as a capability scoped to a seeded `(master)` menu** (e.g. `PLATFORM_TENANTS`). This keeps ONE authorization model app-wide (no new flat-capability primitive) and the `(master)` menus seeded here are exactly what P-04's control-plane screens hang off. The 5 roles are **global** (`IsSystem=true`, `CompanyId=null`).

**Why this blocks P-03:** provisioning is control-plane work. Every P-03 resolver/command is gated by an explicit `PLATFORM_*` capability (never `IsSuperAdmin()` alone — §11). To seed those capabilities into concrete **internal staff roles**, P-03 needs a fixed list of (a) the capability family, (b) the role bundles, and (c) which role holds the provisioning trigger. The design doc §11 already prescribes the *shape* ("three roles, not one god-role; least privilege for our own staff"); this brief pins the exact cells.

**The capability family is already fixed (§11, §M-11) — not up for decision:**
`PLATFORM_LEAD_VIEW`, `PLATFORM_LEAD_EDIT`, `PLATFORM_LEAD_EXPORT`, `PLATFORM_DEAL_APPROVE`, `PLATFORM_TENANT_VIEW`, `PLATFORM_TENANT_PROVISION`, `PLATFORM_TENANT_SUSPEND`, `PLATFORM_PLAN_EDIT`, `PLATFORM_IMPERSONATE`, `PLATFORM_AUDIT_VIEW`.

---

## Recommended default role → capability matrix

| Capability | PLATFORM_SALES | PLATFORM_IMPLEMENTATION | PLATFORM_SUPPORT | PLATFORM_FINANCE | PLATFORM_ADMIN |
|---|---|---|---|---|---|
| `PLATFORM_LEAD_VIEW`     | ✅ | ✅ | – | – | ✅ |
| `PLATFORM_LEAD_EDIT`     | ✅ | – | – | – | ✅ |
| `PLATFORM_LEAD_EXPORT`   | – | – | – | – | ✅ (audited) |
| `PLATFORM_DEAL_APPROVE`  | – | – | – | ✅ | ✅ |
| `PLATFORM_TENANT_VIEW`   | – | ✅ | ✅ | ✅ | ✅ |
| `PLATFORM_TENANT_PROVISION` | – | ✅ | – | – | ✅ |
| `PLATFORM_TENANT_SUSPEND`   | – | – | – | – | ✅ |
| `PLATFORM_PLAN_EDIT`     | – | – | – | – | ✅ |
| `PLATFORM_IMPERSONATE`   | – | ✅ | ✅ | – | ✅ |
| `PLATFORM_AUDIT_VIEW`    | – | – | – | – | ✅ |

**Rationale (maps directly onto §11 "least privilege for our own staff"):**
- **PLATFORM_SALES** — works the pipeline: sees & edits leads. No tenant data, no commercial approval (they *request* the deal; Finance approves), no provisioning. This is the "sales sees leads, not tenant data" line.
- **PLATFORM_IMPLEMENTATION** — the consultant who runs assisted onboarding (§10: "our implementation consultant drives"). Holds the **provisioning trigger** + tenant view + impersonate (to configure the fresh tenant). Reads leads (context for the handoff) but doesn't edit the pipeline.
- **PLATFORM_SUPPORT** — "the screen support lives in all day" (A-03 Tenant 360): tenant metadata + impersonation for troubleshooting. No commercials, no provisioning.
- **PLATFORM_FINANCE** — approves commercial terms / discounts (feeds D-Q5) and views subscriptions. "Finance sees subscriptions, not lead notes."
- **PLATFORM_ADMIN** — the internal superset (plan editing, suspend, audit, lead export). Held by a tiny number of people. This is *not* `IsSuperAdmin()` — it is a capability bundle; `IsSuperAdmin()` remains tenancy-only.

> `IsSuperAdmin()` stays orthogonal: it bypasses the tenant filter (tenancy), it is **not** a control-plane grant. A user needs both an `aud=platform` token *and* the relevant `PLATFORM_*` capability to reach `/ops`.

---

## The forks worth an explicit call (everything else follows the matrix)

1. **Role granularity** — 5 roles as above (Sales / Implementation / Support / Finance / Admin) **[recommended]** vs the doc's literal "three roles" (fold Implementation→Support and drop a separate Finance, giving Sales / Support+Impl / Admin). Five is barely more seed data and draws cleaner lines; three is simpler to administer at very low headcount.
2. **Who can pull the provisioning trigger** (`PLATFORM_TENANT_PROVISION`) — **Implementation + Admin only [recommended]** vs also Sales (lets a rep self-provision a signed deal without a handoff — faster, but weaker separation between "closed the deal" and "switched on the tenant").
3. **Seed scope in P-03** — seed the `PLATFORM_*` **capabilities + these role bundles** as a global (non-tenant) seed now, as part of P-03 **[recommended]** vs seed only the capabilities and leave role bundling to a later admin screen (A-14). Recommended = a real internal user can be granted a role the day provisioning lands; deferring means every provisioning test needs manual capability wiring first.

> MVP note: like D-Q4, get the **shape** right — the exact per-role cells are trivially editable later via A-14 (platform user & role admin). Lock the role list + who provisions; don't over-tune edge capabilities now.
