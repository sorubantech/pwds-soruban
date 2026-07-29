# PSS 2.0 — P-05e / T-B10 — Drop Document header/footer from the Provisioning Wizard

**Type:** Follow-up patch to P-05 (O-01 Provisioning Wizard). **Not** a new screen.
**Schema change:** NONE. **Migration:** NONE. **New capability / mutation / query / seed:** NONE.
**Backend:** NONE (see §④ — the existing handler already falls back gracefully).
**Frontend area:** `presentation/components/page-components/ops/provisioningwizard/` — 2 files.

---

## ① Why this prompt exists

Step 3 (Tenant details) of the O-01 provisioning wizard currently collects two optional free-text
fields — **"Document header"** (`companyHeader`) and **"Document footer"** (`companyFooter`) — that
get passed to `ProvisionTenant` and written onto the new tenant's `Company` row.

These do **not** belong in onboarding:

- `Company.CompanyHeader` / `Company.CompanyFooter` are **existing tenant-owned columns** (present
  since the initial migration; managed by the tenant's own CreateCompany / UpdateCompany / Company
  settings screen). The wizard is not the right place to author a charity's letterhead.
- Receipts, donation pages, and one-to-one communications all render from **selected templates**,
  not from a single company-level header/footer string — so seeding a parent-level header/footer at
  provisioning time is redundant dead weight.

So: **remove the two fields from the wizard.** The tenant sets its own header/footer later (if ever)
from its own settings. We are **not** dropping the `Company` columns — only the wizard's collection
of them.

---

## ② Scope — do exactly this, nothing more

**In scope (FE only, 2 files):**

1. `provision-wizard-schemas.ts` — remove `companyHeader` / `companyFooter` from `wizardTenantSchema`
   and from the `emptyProvisionWizard` default object.
2. `provision-wizard-page.tsx` — delete the two `FormInput` blocks (labels "Document header" /
   "Document footer") from Step 3, and remove the `companyHeader` / `companyFooter` keys from the
   request object built in the submit handler.

**Out of scope (do NOT touch):**
- The `Company` entity columns `CompanyHeader` / `CompanyFooter` — they stay (tenant-owned).
- Any BE file. The `ProvisionTenant` command DTO and `TenantProvisioningMutations` GraphQL input keep
  their optional-nullable `CompanyHeader` / `CompanyFooter` properties — they simply arrive `null`
  now, and the handler already handles that (see §④). No schema/migration/capability/mutation/query.
- Any other wizard step, field, or the review-step summary rows for lead / commercial term / admin.

---

## ③ Frontend changes (2 files)

### ③.1 `provision-wizard-schemas.ts`

- In `wizardTenantSchema`, **delete** these two lines:
  ```ts
  companyHeader: z.string().trim().max(200).optional().nullable(),
  companyFooter: z.string().trim().max(200).optional().nullable(),
  ```
- In `emptyProvisionWizard`, **delete** the two matching defaults:
  ```ts
  companyHeader: "",
  companyFooter: "",
  ```
- Leave everything else (`companyName`, `companyCode`, `subdomain`, `countryId`, `address`,
  `adminName`, `adminEmail`, the merged `provisionWizardSchema`, `WIZARD_STEP_SCHEMAS`, `slugify`,
  `codeify`) unchanged. `ProvisionWizardValues` re-infers automatically.

### ③.2 `provision-wizard-page.tsx`

- **Delete** the two `<FormInput … name="companyHeader" label="Document header" … />` and
  `name="companyFooter" label="Document footer"` blocks in the Step 3 (Tenant details) grid. The
  surrounding fields (Address above, Administrator name below) close up naturally.
- In the submit handler's `request` object, **remove** these two lines:
  ```ts
  companyHeader: v.companyHeader?.trim() || null,
  companyFooter: v.companyFooter?.trim() || null,
  ```
- Do not touch `FormInput` imports if they're still used by other fields (they are).

---

## ④ Why no backend change is needed

The provisioning handler already defaults a blank header/footer to the company name
(`ProvisionTenant.cs`):

```csharp
CompanyHeader = string.IsNullOrWhiteSpace(req.CompanyHeader) ? req.CompanyName : req.CompanyHeader!,
CompanyFooter = string.IsNullOrWhiteSpace(req.CompanyFooter) ? req.CompanyName : req.CompanyFooter!,
```

With the wizard no longer sending the fields, `req.CompanyHeader` / `req.CompanyFooter` arrive `null`,
so the new tenant's `Company.CompanyHeader` / `CompanyFooter` fall back to the **company name** — a
sensible placeholder the tenant can overwrite in its own settings. The GraphQL input keeps the two
optional properties (harmless, unused now); leaving them avoids a BE build. **Do not** delete the BE
properties in this patch.

---

## ⑤ Hard constraints

1. **Frontend only, 2 files.** No BE edit, no schema/migration/capability/mutation/query/seed.
2. **Do not drop the `Company.CompanyHeader` / `CompanyFooter` columns** — they are tenant-owned and
   used elsewhere (CreateCompany / UpdateCompany / GetCompany / receipt rendering).
3. **No new field, label, or step.** This is a pure removal.
4. Keep the Step 3 grid layout tidy after removal (no orphaned grid gaps / dangling `col-span`).

---

## ⑥ Build evidence to return in the hand-back

- **FE:** `npx tsc --noEmit --incremental false` → **exit 0** (only exit 0 counts as clean — a run
  that reports just a pre-existing config error checked zero files).
- Confirm: the wizard's Step 3 no longer shows "Document header" / "Document footer"; the payload
  posted to `provisionTenant` no longer contains `companyHeader` / `companyFooter`; a provisioning
  run still completes and the new tenant's `Company.CompanyHeader/Footer` equal the company name.
- Flag any component / field / route name that differed from what §③ assumed (verify-before-use).
