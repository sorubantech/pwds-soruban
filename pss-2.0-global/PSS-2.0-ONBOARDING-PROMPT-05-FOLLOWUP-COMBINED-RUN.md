# PSS 2.0 — P-05 follow-up combined dev-session run (T-B11 + T-B7 + T-B8 + T-B10)

**Purpose:** run **four** independent follow-up patches to P-05 (O-01 Provisioning + Lead/Deal wizard)
in a single dev session. This is a **cover / runner** doc — the full instructions live in the four
prompt files it points to. Do all four, then return **one** combined hand-back.

> **Supersedes** `PSS-2.0-ONBOARDING-PROMPT-05BC-COMBINED-RUN.md` (which bundled only 05b + 05c).
> Use this doc instead — it adds the critical 05f provisioning fix and the 05e wizard cleanup.

**Only P-05f adds a migration** (user-owned — see §③). None of the four adds a
capability · mutation · query · seed. Schema touch is limited to P-05f's three re-scoped indexes.

---

## ① The four patches — run 05f FIRST, then the rest in any order

| # | Prompt file | Task | Area | What it does |
|---|-------------|------|------|--------------|
| 1 | `PSS-2.0-ONBOARDING-PROMPT-05F-PROVISION-ROLE-INDEX-AND-RESUME.md` | **T-B11** 🔴 critical | BE `AuthConfigurations/RoleConfiguration.cs` + `OpsBusiness/TenantProvisioning/Commands/ProvisionTenant.cs` | Prepends `CompanyId` to the 3 global Role unique indexes (fixes the `roles_isactive` Step-3 crash that blocks every 2nd tenant); makes the provisioning validator resume-aware so a paused run's own half-built company no longer trips the subdomain/code uniqueness guards. **Adds a user-owned migration.** |
| 2 | `PSS-2.0-ONBOARDING-PROMPT-05B-LEAD-LIFECYCLE.md` | **T-B7** | BE `OpsBusiness/LeadManagement/` + FE `ops/leads/` | Server-governs `Lead.Status`: ordered transition guard, `WON` reachable **only** via `ApproveCommercialTerm`, create-time `WON` block; FE swaps the free status dropdown for lifecycle action buttons. |
| 3 | `PSS-2.0-ONBOARDING-PROMPT-05C-PAYMENT-GATEWAY-PICKER.md` | **T-B8** | FE `ops/deals/` + `domain/entities/ops-service/CommercialTermDto.ts` | Replaces the deal form's free-text `paymentGatewayCode` `FormInput` with a closed `FormSelect` (`RAZORPAY` / `STRIPE` + "— Not decided —"); field stays optional (blank → null). |
| 4 | `PSS-2.0-ONBOARDING-PROMPT-05E-DROP-WIZARD-DOCHEADER.md` | **T-B10** | FE `ops/provisioningwizard/` (2 files) | Removes the "Document header" / "Document footer" fields from wizard Step 3 (handler already falls back to company name). Pure FE removal — no BE, no columns dropped. |

**Execute each prompt exactly as written** — its own ②/③/④ scope and hard-constraint sections are
authoritative. This cover doc only sequences them and merges the build evidence.

---

## ② Why they combine safely (no conflict)

- **No shared file across the four.** File touch-sets are disjoint:
  - **05f** → `RoleConfiguration.cs`, `ProvisionTenant.cs` (BE only).
  - **05b** → `LeadManagement/` BE + `ops/leads/` FE.
  - **05c** → `ops/deals/` FE + `CommercialTermDto.ts`.
  - **05e** → `ops/provisioningwizard/` FE (2 files).
  The only file two prompts *mention* is `ApproveCommercialTerm.cs` — **05b** edits it (auto-WON hook)
  and **05c** only reads its DTO field name. No merge conflict.
- **05f goes first for a real reason, not just tidiness.** Its BE edit lands with a **migration you run
  yourself** before provisioning works again. Do it first so the dev session builds clean once and the
  provisioning smoke test is unblockable the moment you apply the migration. The other three are
  order-free among themselves (they share no state).
- **One shared runtime surface (05b × 05c):** approving a deal (05c's form feeds it) is exactly what
  05b's auto-WON hook keys off — after both land, saving a deal with a chosen gateway and approving it
  should (a) persist the gateway code and (b) flip the parent lead to `WON`. Worth one end-to-end
  eyeball. **05f × everything:** independent — 05f only changes how roles are indexed and how the
  provisioning validator treats a resume.

---

## ③ The one migration is YOURS (P-05f only)

The dev session must **edit `RoleConfiguration.cs` and prove it compiles only** — it must **NOT** run
`dotnet ef migrations add` / `database update` / `remove`, and must **NOT** hand-author a migration or
snapshot. After the dev session returns clean-build evidence, **you** run:

```
dotnet ef migrations add Rescope_Role_Unique_Indexes_Per_Company
dotnet ef database update
```

It is a pure `DropIndex ×3 / CreateIndex ×3` on `auth.Roles` — no columns, no data movement. The dev
session flags in its hand-back if the generated diff would be anything more than that.

---

## ④ Combined build evidence (run once, after ALL four patches)

- **BE** (05f + 05b touch BE): `dotnet build …/Base.API/Base.API.csproj -c Debug` → **0 CS errors**.
  Stop any running `Base.API` first to avoid the DLL file-copy lock (`MSB3026/3027/3021`); a
  redirected-output build is acceptable evidence — say which you used.
- **FE** (covers 05b + 05c + 05e): `npx tsc --noEmit --incremental false` → **exit 0**. Only exit 0
  counts as clean (a run that reports only a pre-existing config error checked zero files).

---

## ⑤ One combined hand-back — confirm all of:

**P-05f (T-B11) — critical:**
- the 3 Role unique indexes now lead with `CompanyId`; confirm the migration diff is DropIndex ×3 /
  CreateIndex ×3 and nothing else; the shared `ProvisionIdempotency.KeyFor` helper exists and is used
  by **both** the handler and the two validator clauses; and state **how** the validator now excludes
  the run's own half-built company (the exclusion query it settled on). Flag any code you found that
  relied on Role codes being globally unique **across** tenants (a bare `RoleCode == "…"` lookup with
  no tenant filter) — that was masked by the old global index.

**P-05b (T-B7):**
- the 4 BE edits are in place; list the **exact rejected transitions** proving `WON` is unreachable via
  `UpdateLead`; create rejects `WON`; the FE status dropdown is gone → lifecycle action buttons; and
  **where** the buttons live (list row vs a detail header).

**P-05c (T-B8):**
- gateway is now a dropdown of Razorpay / Stripe + "— Not decided —"; field still optional and saves
  `null` when blank; editing a deal that already has a code pre-selects it; **no** BE/schema/seed touched.

**P-05e (T-B10):**
- wizard Step 3 no longer shows "Document header" / "Document footer"; the `provisionTenant` payload no
  longer carries `companyHeader` / `companyFooter`; a run still completes with the new tenant's
  `Company.CompanyHeader/Footer` equal to the company name; **no** BE property or `Company` column dropped.

**All four:**
- the combined BE + FE build evidence above; and any property / component / route name that differed
  from what the prompts assumed (verify-before-use — flag it, don't silently rename).

---

## ⑥ After the dev session returns — your recovery step for the stuck leadId=2 run

Once 05f is built **and** you've applied `Rescope_Role_Unique_Indexes_Per_Company`:
**re-submit the provisioning wizard for leadId=2.** No manual SQL. The now-resume-aware validator
recognises the paused run owns that company → allows it; the handler skips the SUCCEEDED Steps 1 & 2,
re-runs Step 3 (roles insert cleanly per-tenant now), and completes through Step 9, reusing the
half-built company + subscription. Then finish the O-01 provisioning smoke test.
