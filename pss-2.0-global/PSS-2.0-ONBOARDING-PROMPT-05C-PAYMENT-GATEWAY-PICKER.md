# PSS 2.0 — P-05c / T-B8 — Payment-gateway picker on the deal form

**Type:** Follow-up patch to P-05 (S-02 Commercial Terms). **Not** a new screen.
**Schema change:** NONE. **Migration:** NONE. **New capability:** NONE. **New mutation/query:** NONE. **Seed:** NONE.
**Backend area:** none — **frontend only.**
**Frontend area:** `presentation/components/page-components/ops/deals/` + `domain/entities/ops-service/`

---

## ① Why this prompt exists

`CommercialTerm.PaymentGatewayCode` is the routing choice for **which processor collects the
tenant's money** — carried onto `Subscription.PaymentGatewayCode` at provisioning. Today the deal
form renders it as a **free-text `FormInput`** (`deal-form-dialog.tsx`, placeholder
`"Optional — e.g. RAZORPAY"`). Free text lets a salesperson type `razorpay`, `RazorPay`, `Stipe`,
etc. — the field feeds billing routing, so an unconstrained string is a latent data-quality hole.

Swap it for a **closed dropdown** of the gateways the platform actually names, plus an explicit
"not decided yet" blank so it stays optional on a DRAFT.

---

## ② Scope — do exactly this, nothing more

**In scope:** add a `PAYMENT_GATEWAY_OPTIONS` constant; replace the gateway `FormInput` with a
`FormSelect` bound to it; keep the field optional (blank = null).

**Out of scope (do NOT build):**
- Any backend change, DTO change, mutation, query, capability, seed, or migration. The write DTO
  field (`paymentGatewayCode?: string | null`) and the BE column are already correct and unchanged.
- A **server-configurable** gateway list (a `PLATFORM_PAYMENT_GATEWAYS` setting the form reads over
  GraphQL). That is a real BE read-path that does not exist yet and is **deliberately deferred** —
  the gateways aren't integrated for collection anyway, so a hard-coded FE list matching the two
  codes the backend references is the correct MVP. When a gateway integration actually lands, that
  upgrade becomes worthwhile; not before. Leave a one-line `// TODO` noting it.

---

## ③ Frontend changes (2 edits)

Verified names to use (read from source — do not rename):
- `CommercialTermDto.ts` already exports `BILLING_CYCLE_OPTIONS` in the shape
  `{ value; label }[]` and is re-exported through `@/domain/entities/ops-service`.
- `deal-form-dialog.tsx` already imports `FormSelect` (used for `planCode` and `billingCycle`) and
  `BILLING_CYCLE_OPTIONS` from `@/domain/entities/ops-service`.
- The gateway field is at ~L214–219 as a `FormInput name="paymentGatewayCode" label="Payment gateway"`.
- Schema: `deal-form-schemas.ts` — `paymentGatewayCode: z.string().trim().max(50).optional().nullable()`.
- Submit already coalesces blank → null: `paymentGatewayCode: values.paymentGatewayCode?.trim() || null`.

### ③.1 `CommercialTermDto.ts` — add the options constant

Next to `BILLING_CYCLE_OPTIONS`, add (an **empty first value** so the picker can be cleared back to
"not decided", keeping the field optional):

```ts
/** Payment processors the platform can route collection to. Kept in sync with the codes the backend
 *  names on CommercialTerm/Subscription (RAZORPAY | STRIPE). Blank = routing not yet decided (null on save).
 *  TODO: when a real gateway integration lands, source this from a PLATFORM_PAYMENT_GATEWAYS setting. */
export const PAYMENT_GATEWAY_OPTIONS: { value: string; label: string }[] = [
  { value: "", label: "— Not decided —" },
  { value: "RAZORPAY", label: "Razorpay" },
  { value: "STRIPE", label: "Stripe" },
];
```

### ③.2 `deal-form-dialog.tsx` — swap `FormInput` → `FormSelect`

- Add `PAYMENT_GATEWAY_OPTIONS` to the existing `@/domain/entities/ops-service` import (the same
  import block that already pulls `BILLING_CYCLE_OPTIONS` / `PLAN_CODE_OPTIONS`).
- Replace the gateway `FormInput` block with:

```tsx
<FormSelect
  control={form.control}
  name="paymentGatewayCode"
  label="Payment gateway"
  options={PAYMENT_GATEWAY_OPTIONS}
  placeholder="Optional — select gateway"
/>
```

(No `required` — it stays optional. The blank option maps to `""`, which the existing submit
line already turns into `null`. `resetTermToForm` maps `null → ""`, which now matches the blank
option instead of an empty text box — no schema change needed since `""` still satisfies the
`.optional().nullable()` rule.)

Do **not** touch `deal-form-schemas.ts` — `z.string().trim().max(50).optional().nullable()` already
accepts `""` and every option value. (Optional tidy, not required: you *may* narrow it to
`z.enum(["", "RAZORPAY", "STRIPE"]).optional().nullable()` for symmetry, but only if you also keep
edit-loading of any legacy free-text value from working — safer to leave the string rule as-is.)

---

## ④ Hard constraints

1. **Frontend only.** No BE, DTO, mutation, query, capability, seed, or migration.
2. **Field stays optional** — blank option present; save still coalesces to `null`.
3. **No new selectable value the backend can't route** — RAZORPAY / STRIPE only (the two codes the
   entity comments name). Extra gateways wait for real integration.
4. **Reuse `FormSelect`** already imported in the dialog — add no new component.

---

## ⑤ Build evidence to return in the hand-back

- **FE:** `npx tsc --noEmit --incremental false` → **exit 0** (only exit 0 counts as clean).
- Confirm: the gateway control is now a dropdown of Razorpay / Stripe + "— Not decided —"; the field
  is still optional and saves `null` when blank; editing a deal that already has a gateway code
  pre-selects it; and no BE/schema/seed file was touched.
