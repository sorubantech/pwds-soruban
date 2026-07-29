# PSS 2.0 — P-05b + P-05c combined hand-back (T-B7 lead lifecycle · T-B8 gateway picker)

Run driver: `PSS-2.0-ONBOARDING-PROMPT-05BC-COMBINED-RUN.md`
Sub-prompts: `…-PROMPT-05B-LEAD-LIFECYCLE.md` (T-B7), `…-PROMPT-05C-PAYMENT-GATEWAY-PICKER.md` (T-B8)

**Schema · migration · capability · mutation · query · seed: NONE added by either patch.**

---

## ① Build evidence (run once, after both patches)

| | Command | Result |
|---|---|---|
| **BE** | `dotnet build …\Base.API\Base.API.csproj -c Debug -p:OutputPath=<scratch>\be-build\` | **0 Error(s)**, 652 warnings (all pre-existing: NPOI EULA, CS0108/CS8604/CS0168 in untouched files). No `error CS`, no `error MSB`. |
| **FE** | `npx tsc --noEmit --incremental false` | **exit 0** — a real full-project check, not a config-only no-op. |

**Redirected-output build was used.** `Base.API` (PID 30556) was running and holds a lock on
`Base.API\bin\Debug\net10.0\*.dll`; rather than kill the user's running API I passed a global
`-p:OutputPath` pointing at the session scratchpad, so the compile ran against the real sources
and only the file-copy destination moved. The running process was left untouched.

---

## ② P-05b / T-B7 — lead lifecycle now server-governed

### ②.1 The four backend edits (all in `Base.Application/Business/OpsBusiness/LeadManagement/`)

1. **`LeadHelper.cs`** — added `_allowedStatusTransitions` + `IsAllowedManualStatusTransition(...)`
   immediately after `AllowedStatuses`.
2. **`Commands/UpdateLead.cs`** — guard at the top of the *not-converted* `else` branch, before
   `dto.Adapt(entity)`; throws `BadRequestException` on an illegal move.
3. **`Commands/ApproveCommercialTerm.cs`** — the LOST pre-condition guard and the auto-WON
   advance, both inside `Handle`, **before** `SaveChangesAsync`.
4. **`Commands/CreateLead.cs`** — `CreateLeadValidator` rule blocking `WON` at birth.

### ②.2 `WON` is unreachable via `UpdateLead` — exact rejected transitions

`IsAllowedManualStatusTransition(from, to)` returns `true` only for:

| from | allowed `to` |
|---|---|
| any | itself (same-state — an ordinary edit that doesn't touch status always passes) |
| `NEW` | `QUALIFIED`, `LOST` |
| `QUALIFIED` | `LOST` |
| `LOST` | `NEW` |
| `WON` | *(nothing)* |

Every other pair is **rejected** with
`Illegal lead status change {from} → {to}. WON is set only by approving a commercial term.`
The complete rejected set:

- **→ WON, from every state** (short-circuited before the table is even consulted):
  `NEW → WON`, `QUALIFIED → WON`, `LOST → WON` — this is the guarantee the prompt asked for.
- **Skipping / reversing the funnel:** `QUALIFIED → NEW`, `LOST → QUALIFIED`.
- **Off WON:** `WON → NEW`, `WON → QUALIFIED`, `WON → LOST` (WON is terminal to the client;
  only provisioning acts on it, and it does so by stamping `ConvertedCompanyId`).
- Any unknown/blank `from` (not a table key) rejects everything except same-state.

`WON` therefore has exactly one producer in the whole codebase: `ApproveCommercialTermHandler`.

### ②.3 Create rejects `WON`

`CreateLeadValidator` now accepts a status only when it is blank (handler defaults it to `NEW`)
**or** is in `AllowedStatuses` **and** is not `STATUS_WON` →
*"A new lead cannot be created as WON — WON is earned by approving a deal."*
Creating a lead already `LOST` still works (with the existing lost-reason-required rule), as specified.

### ②.4 Auto-WON — one transaction, idempotent

`ApproveCommercialTermHandler` now takes **one tracked read** of the parent lead
(`.IgnoreQueryFilters()` + `IsDeleted != true`, per the control-plane rule) and uses it for both
jobs — the prompt explicitly permitted merging its two `if (command.approve)` blocks:

- **Pre-condition:** `lead?.Status == LOST` → `BadRequestException("Cannot approve a deal for a
  lead that has been marked LOST.")`, thrown before anything is mutated.
- **Advance:** only when `approve && lead is not null && lead.ConvertedCompanyId is null &&
  status ∈ {NEW, QUALIFIED}` → `Status = WON`, `ModifiedDate = DateTime.UtcNow` (UTC only),
  `ModifiedBy = actingUserId`.

Both the term row and the lead row are dirty on the **same `SaveChangesAsync`** — a failed save
leaves neither APPROVED nor WON. A re-approval, an already-WON lead and a converted lead are
silent no-ops; the WON path never throws.

### ②.5 Frontend — dropdown gone, lifecycle actions in

- **Status dropdown deleted.** `lead-form-dialog.tsx` no longer has the
  `FormSelect name="status" options={LEAD_STATUS_OPTIONS}`; the `useWatch`-driven `isLost`
  conditional lost-reason textarea went with it, and the `LEAD_STATUS_OPTIONS` import is gone.
- **Schema trimmed.** `lead-form-schemas.ts` drops `status`, `lostReason` and the `.refine()` that
  tied them together; `leadFormSchema` is now a plain `z.object` and `emptyLeadForm` matches.
- **New `lead-lifecycle-actions.tsx`** (exported from the leads barrel) holds the buttons, each
  resending the **full current lead** through the existing `UPDATE_LEAD_MUTATION` — **no new
  mutation**:

  | Button (icon) | Shown when | Sends | Extra |
  |---|---|---|---|
  | Qualify `ph:check-circle-duotone` | `NEW` | `QUALIFIED` | — |
  | Mark lost `ph:prohibit-duotone` | `NEW` / `QUALIFIED` | `LOST` | opens a reason dialog; the confirm button is disabled until the reason is non-blank (max 500) |
  | Reopen `ph:arrow-counter-clockwise-duotone` | `LOST` | `NEW` (`lostReason` → null) | — |
  | *(none)* | `WON` | — | read-only `ph:seal-check-duotone` marker, tooltip **"Won on deal approval"** |

  Converted leads (`convertedCompanyId != null`) and users without `PLATFORM_LEAD_EDIT` get no
  buttons at all. On failure the component surfaces the backend message verbatim
  (`result.message` + `errorDetails`) — the guard is the source of truth, the FE only *requests*
  a transition.

**Decision — where the buttons live: the list row's action cell** (left of Convert / Deals /
Edit / Delete), not a detail header. Reason: S-01 has no lead-detail route — the row click
navigates to `/{lang}/ops/deals?leadId=…`, so a header would have had to be invented on the deals
screen. Keeping them on the row lets the funnel be worked without leaving the list, and the cell
already `stopPropagation()`s the row-click navigation.

### ②.6 `LEAD_STATUS_OPTIONS` and the chip

- `lead-status-chip.tsx` — **untouched**; `STATUS_STYLES` still covers all four states so `WON`
  keeps rendering as a chip (display-only now).
- `LEAD_STATUS_OPTIONS` in `LeadDto.ts` — **left with all four values**. Its only *selectable-for-
  write* consumer was the form dropdown, which is deleted; the one remaining consumer is the list
  page's **status filter**, where `WON` must stay so won leads can still be filtered. That
  satisfies ④.3 ("remove WON from any selectable option list") without breaking the filter — flagging
  it here because the prompt implied editing the constant.

---

## ③ P-05c / T-B8 — payment gateway picker (FE only)

- `CommercialTermDto.ts` — added `PAYMENT_GATEWAY_OPTIONS` **verbatim as specified**
  (`""` → "— Not decided —", `RAZORPAY` → "Razorpay", `STRIPE` → "Stripe"), with the one-line
  `TODO` about sourcing it from a future `PLATFORM_PAYMENT_GATEWAYS` setting.
- `deal-form-dialog.tsx` — the free-text `FormInput name="paymentGatewayCode"` is replaced by a
  `FormSelect` bound to that constant.
- **Still optional, still saves `null` when blank:** `deal-form-schemas.ts` was **not touched**
  (no `required` prop, no zod change) and the submit path's existing
  `paymentGatewayCode: values.paymentGatewayCode?.trim() || null` turns the blank option into `null`.
- **Editing a deal that already has a code pre-selects it:** `toFormValues` already maps
  `paymentGatewayCode: term.paymentGatewayCode ?? ""`, and `FormSelect` matches the option by
  `opt.value?.toString() === value?.toString()`, so `"RAZORPAY"` lands on Razorpay and a null code
  lands on "— Not decided —".
- **No backend, schema, GraphQL or seed touched.**

---

## ④ Things that differed from what the prompts assumed (flagged, not silently renamed)

1. **`FormSelect` numeric-coerces its value — the blank option needed a local repair.**
   `FormSelect.tsx:492-498` does
   `isNaN(Number(newValue)) ? newValue : parseInt(String(newValue))`. Because `Number("")` is `0`
   (not `NaN`), picking "— Not decided —" would push `parseInt("")` → **`NaN`** into a
   `z.string()…optional().nullable()` field, failing zod and disabling the `isValid`-gated Save
   button. Rather than change the shared component or bend the prompt's verbatim constant, the
   dialog normalises it back with an `onChangeCallback` that resets the field to `""` whenever the
   incoming value isn't a string (this also covers the clear-"×" path, which emits `undefined`).
   If a shared fix is ever wanted, `FormSelect`'s coercion should skip non-numeric-typed option
   lists — that is a wider change than these patches allow.
   *(Note: `FormSelect` is a Command/Popover combobox, not Radix `Select`, so a `""` option value
   does **not** hit the Radix "empty string value" error.)*

2. **`LeadHelper.IsAllowedManualStatusTransition` takes `string?`, not `string`.**
   The prompt's signature was `(string from, string to)` but its own body does `from ?? ""`,
   which the nullable analyzer flags as unreachable on a non-nullable parameter — and both call
   sites pass nullable values (`Lead.Status` and `LeadRequestDto.Status` are both nullable at the
   C# level). Widened to `(string? from, string? to)` with `to ?? ""` in the `Contains` call.
   Behaviour is identical.

3. **`UpdateLeadValidator` still requires `Status`, and `LeadRequestDto.status` is non-optional in
   TS** — so the edit dialog cannot simply stop sending the field. It now resends the lead's
   **current** status unchanged (`isEdit ? lead?.status ?? "NEW" : "NEW"`), a same-state
   transition the new guard always allows, and likewise resends `lead.lostReason` untouched so an
   already-LOST lead keeps satisfying the "reason required when LOST" validator. Prompt ④.1
   anticipated this ("if the DTO requires the field, send `NEW`") — this is that branch, with the
   edit case preserved rather than reset.

4. **Pre-existing (not fixed — out of scope): `UpdateLead` can wipe `OwnerUserId`.**
   `UpdateLeadHandler` does a blind `dto.Adapt(entity)` and `lead-form-dialog.tsx` has never sent
   `ownerUserId`, so saving the edit form nulls the lead's owner. The new
   `lead-lifecycle-actions.tsx` round-trip **does** send `ownerUserId: lead.ownerUserId ?? null`,
   so the lifecycle buttons are safe; the edit dialog's existing gap is left as-is and reported
   here for a follow-up.

---

## ⑤ Files changed

**Backend (4)**
- `Base.Application/Business/OpsBusiness/LeadManagement/LeadHelper.cs`
- `…/LeadManagement/Commands/UpdateLead.cs`
- `…/LeadManagement/Commands/ApproveCommercialTerm.cs`
- `…/LeadManagement/Commands/CreateLead.cs`

**Frontend (6, one new)**
- `src/domain/entities/ops-service/CommercialTermDto.ts` *(P-05c)*
- `src/presentation/components/page-components/ops/deals/deal-form-dialog.tsx` *(P-05c)*
- `src/presentation/components/page-components/ops/leads/lead-form-dialog.tsx`
- `src/presentation/components/page-components/ops/leads/lead-form-schemas.ts`
- `src/presentation/components/page-components/ops/leads/lead-lifecycle-actions.tsx` **(new)**
- `src/presentation/components/page-components/ops/leads/lead-list-page.tsx`
- `src/presentation/components/page-components/ops/leads/index.ts` (barrel export)

**Nothing to run:** no migration, no seed script, no capability row. Both patches are code-only.
