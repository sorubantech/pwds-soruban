# PSS 2.0 — Payment Gateways (Screen #167): Own the Credential Form

> **Screen:** `(core)/setting/paymentconfig/companypaymentgateway`
> **Folder:** `PSS_2.0_Frontend/src/presentation/components/page-components/setting/paymentconfig/companypaymentgateway/`
> **Status:** NOT STARTED
> **Scope:** Frontend only. No DTO changes, no GraphQL contract changes, no entity/migration work.

---

## ① Why this exists

This screen has the opposite problem to Email Provider Config. That one is over-built and
under-organised. This one is **under-built**: 860 lines across 5 files, a 151-line page — because
the part that actually matters, the credential form, **was never written**. It is delegated to the
generic DB-driven RJSF pipeline, and that pipeline cannot express a single one of this screen's
requirements.

Verified defects, with code evidence:

| # | Defect | Evidence |
|---|---|---|
| 1 | **The Configure button cannot configure.** It switches tabs and shows a toast asking the user to find, by name, the gateway they just clicked | `index-page.tsx:65-72` — the comment admits it: *"there is no supported way to pre-bind PaymentGatewayId. The toast names the gateway to pick."* |
| 2 | **Credentials render as plain visible text inputs.** The widget registry has 30 widgets and **not one is a secret/password widget** | `data-table-form/dgf-widgets/` — `email-widget`, `url-widget`, `uppercase-text-widget`… no password widget exists |
| 3 | **Editing a gateway probably writes the mask back as the credential.** RJSF seeds the edit form from `getById`, which returns the masked value; an unchanged Save posts that mask string into `encryptedApiKey` | `shared-service-entity-operations.ts:223-234` — `getById` and `update` share `CompanyPaymentGatewayRequestDto`. **Verify this before anything else — if true it is a live data-corruption bug** |
| 4 | Three CSV fields render as free-text | `supportedCurrencies` / `supportedCountryCodes` / `supportedPaymentMethods` are ISO-4217 / ISO-3166 / MasterData CSVs typed by hand. One typo silently narrows what the gateway will accept |
| 5 | `gatewayEnvironment` is a raw string field | `"sandbox"` / `"production"`, hand-typed, while the UI labels them Test / Live (`gateway-card.tsx:33-45`). A user who types `Production` gets a Test gateway |
| 6 | The whole grid action chain is a workaround | `enableAdd` must stay `true` not for the New button but because `DataTableAddOption` is the only listener for the `"new-record"` grid action; Tab 2 must be `forceMount`-ed so the listener exists before a fire-and-forget action clears itself 100ms later (`index-page.tsx:87-90, 122-124`) |
| 7 | Responsive is essentially absent | `gateway-card.tsx` and `index-page.tsx`: `sm:` **0**, `md:` **0**, `lg:` **0**, `xl:` **0**. `available-gateways-tab.tsx` has 2 `sm:` + 2 `xl:`, no `md:` |
| 8 | No content max-width, no zero-state | The tenant with no configured gateway sees an empty DataTable, not "you have no gateway yet — here is why that matters and what to do" |
| 9 | Alpha/pastel surfaces against house rule | `border-primary/20 bg-primary/5 text-primary` overflow chip (`gateway-card.tsx:77`, `available-gateways-tab.tsx:169`); `bg-muted/50`, `bg-muted/30` card header/footer; `bg-red-50 text-red-700` webhook error (`webhook-log-drawer.tsx:182`). 28 violating lines across 4 files |
| 10 | Zero brand adoption | No `--shell-accent` / `brand-surface` usage. The tenant's own brand never appears |
| 11 | No default-gateway guard in the UI | `isDefault` is a plain boolean per row. Nothing in the UI explains that setting a second default demotes the first, or what "default" is even used for |
| 12 | Test Connection is per-card only | Correct and well-built (`gateway-card.tsx:151-175`, never echoes the credential) — but there is no equivalent reassurance anywhere during **creation**, which is exactly when a typo happens |

---

## ② Rules this build must not break

1. **Credentials are write-only.** `encryptedApiKey` / `encryptedApiSecret` /
   `encryptedWebhookSecret` are plaintext **on the wire during Create/Update only**; the backend
   encrypts, and the list returns them masked. The client must **never** render a stored secret
   into an editable input, and must **never** post a mask back. Empty means *keep the stored value*.
2. **`companyId` is set by the backend** from `CurrentUserService`. It is on the DTO but it is
   **not a form field**. Never send it.
3. **Test Connection returns a verdict, never a credential.** `GatewayConnectionTestDto` carries
   `success` + `message` only. Keep it that way; render `message` verbatim on failure.
4. **Fit is advice, never a rule.** `Mismatch` is amber, never red, and never blocks a save
   (`PaymentGatewayDto.ts:18-23`). The one narrow refusal lives in the backend command.
5. **The catalogue is read-only.** `app.PaymentGateways` is a code artefact — `isImplemented`
   reflects what `PaymentGatewayFactory` can resolve. Tab 1 reads, never writes.
6. **A retired catalogue row stays visible** so existing configurations still resolve a name, but
   nothing new may point at it (`available-gateways-tab.tsx:116-117`).
7. **`rec.reason` is rendered verbatim** — composed by the backend, never reworded or templated on
   the client (`PaymentGatewayDto.ts:30`).
8. **No DTO edits, no GraphQL contract edits.** The three CSV fields stay CSV strings on the wire;
   the friendly multi-select is a presentation layer over them, joined back to CSV on submit.
9. **Boundary respect.** `(master)/platform/gateways`, `ops/gateways/platform-gateway-config-page.tsx`
   and `ops/plans/platform-gateway-environment-panel.tsx` own the *platform's* gateway config.
   This screen owns the *tenant's own credentials only*. Do not duplicate, contradict or link into
   the platform surface. Prior prompts `-14-BILLING-GATEWAY`, `-15-TENANT-GATEWAY-CONFIG` and
   `-05C-PAYMENT-GATEWAY-PICKER` govern that boundary; **read them before writing code**.

---

## ③ The mental model to adopt

> **The screen owns its own credential dialog. The generic table form is not fit for secrets.**

Everything else in this build follows. Once the screen owns the dialog, the gateway can be
pre-bound (killing defect #1), secrets get write-only semantics (#2, #3), the CSV fields get
multi-selects (#4), the environment gets a segmented control (#5), and the entire fire-and-forget
grid-action workaround disappears (#6).

---

## ④ The credential dialog

New `gateway-config-dialog.tsx`. Opened in two ways, both pre-bound:

- Tab 1 **Configure** → `open({ mode: "create", gateway })` — the gateway is already chosen.
- Tab 2 card **Edit** → `open({ mode: "edit", row })`.

React Hook Form. Fields, in order:

| Field | Control | Notes |
|---|---|---|
| Gateway | read-only identity strip (icon + name + code) in create mode; same in edit | Never a dropdown. The user already chose |
| Environment | `ToggleGroup` segmented — **Test** / **Live** | Maps to `"sandbox"` / `"production"`. Selecting Live shows an inline amber note: *"Live keys move real money. Test the connection before you enable this gateway."* |
| Merchant ID | `Input` | Optional |
| API Key | secret input | §⑤ |
| API Secret | secret input | §⑤ |
| Webhook Secret | secret input, optional | §⑤ |
| Currencies | `FancyMultiSelect` | §⑥ |
| Payment methods | `FancyMultiSelect` | §⑥ |
| Countries | `FancyMultiSelect` | §⑥ |
| Additional config | `Textarea`, collapsed under "Advanced" | Free-form JSON. Validate `JSON.parse` on blur; block submit on invalid with the parser's own message |
| Set as default | `Switch` | §⑧ |

**Required in create mode:** environment, API key, API secret. **Required in edit mode:**
environment only — a blank secret means "unchanged".

Submit calls `CREATE_COMPANYPAYMENTGATEWAY_MUTATION` / `UPDATE_COMPANYPAYMENTGATEWAY_MUTATION`
directly (both already exported from `CompanyPaymentGatewayMutation.ts` and already registered in
`shared-service-entity-operations.ts` — **read the file, do not guess the mutation field names**;
HotChocolate strips `Get` and appends `Input`, and `tsc` cannot see gql field names). On success,
refetch the Tab 2 grid.

Save is gated on RHF `formState.isValid`, never on `canCreate`/`canUpdate`. Capability gates the
entry-point button only.

---

## ⑤ Secret handling — the load-bearing part

**Before writing anything, verify defect #3.** Open the Edit form on an existing row and inspect
the value RJSF seeds into `encryptedApiKey`. If it is the mask, the current screen corrupts
credentials on every unchanged Save. Record the finding in the build log either way.

The new dialog's rule, non-negotiable:

- Secret inputs are `type="password"`, **never pre-filled**, no reveal toggle on a stored value.
- When a secret exists on the row (edit mode), placeholder reads `Stored — leave blank to keep it`,
  with a helper line: `A key is on file. Type a new one only to replace it.`
- On submit, a blank secret field is **omitted from the mutation variables entirely** — not sent as
  `""`, not sent as the mask. Build the variables object by conditional spread, not by object
  literal with empty strings.
- In create mode a reveal toggle **is** allowed (the user just typed the value and needs to check
  it against their provider dashboard) — but it must reset to hidden on blur.

Reuse `SecretInput` from
`presentation/components/page-components/setting/communicationconfig/smssetup/secret-input.tsx`.
It already implements this contract for the SMS screen. Do not fork it. If it needs a `helper` prop,
add it as optional and leave the SMS usages unchanged.

**Also add a `secret-widget.tsx` to `dgf-widgets/` and register it**, so that any other grid whose
metadata marks a field as a secret gets the same treatment instead of a visible text input. This is
a small, additive, self-contained change — no existing widget behaviour changes.

---

## ⑥ The three CSV fields

Stored and transmitted as comma-joined strings. Presented as chip multi-selects.

| Field | Option source | Format |
|---|---|---|
| `supportedCurrencies` | The currency master list already queried elsewhere on the settings tree — reuse the existing currency query rather than a hard-coded ISO-4217 list | `"USD,EUR,GBP"` |
| `supportedCountryCodes` | The country master list, same rule | `"US,GB,IN"` — alpha-2 |
| `supportedPaymentMethods` | MasterData `PAYMENTMETHODTYPE` | `"CARD,UPI"` |

Two pure helpers in a new `csv.ts`:

```ts
export const csvToList = (csv?: string | null): string[] =>
  (csv ?? "").split(",").map(s => s.trim()).filter(Boolean);

export const listToCsv = (list: string[]): string | null =>
  list.length ? list.join(",") : null;
```

`gateway-card.tsx`'s `ChipStrip` currently reimplements the split inline (line 58) — refactor it to
use `csvToList` so parsing lives in one place.

**Cross-check against the catalogue.** When the chosen currencies have a zero intersection with the
gateway's `supportedCurrencyCodes` from `GATEWAY_RECOMMENDATIONS_QUERY`, show an amber inline warning
in the dialog *before* submit — the backend refuses this case and the user should learn it here, not
from a server error.

---

## ⑦ Retire the grid-action workaround

Once the dialog is screen-owned:

- `handleConfigure` no longer calls `triggerGridAction("new-record")` and no longer emits a toast
  telling the user to go find their gateway. It calls `openDialog({ mode: "create", gateway })`.
- Tab 2 no longer needs `forceMount` for that reason. **Keep `forceMount` only if the grid's own
  state needs it** — verify, and if it is no longer needed, remove it and say so in the build log.
- `enableAdd` may stay `true` for the New button's own sake, but the New button should now open the
  screen's dialog. If the DataTable's add option cannot be redirected, replace it: set
  `enableAdd: false` and put an explicit `+ New Gateway` button in a small toolbar above the grid,
  gated on the create capability.
- `enableActions.enableEdit` likewise: the card footer's `DataTableUpdateOption` must open the
  screen's dialog, not RJSF. If it cannot be redirected, replace the footer Edit button with a plain
  button that calls `openDialog({ mode: "edit", row })`.

**Delete-and-Toggle stay on the DataTable's own options** — they carry no credential and their
confirm flows already work.

---

## ⑧ Default gateway, explained

`isDefault` today is a bare boolean with a star badge and no explanation.

- In the dialog, the Switch's helper line: *"The default gateway is used for donation pages and
  campaigns that do not name one explicitly."*
- When switching it **on** while another gateway is already default, show the demotion inline
  before submit: *"Razorpay is currently the default. Saving will make this gateway the default
  instead."* — computed client-side from the loaded grid rows.
- A **disabled** gateway may not be the default. If the user sets default on a disabled gateway,
  block submit with: *"Enable this gateway before making it the default."*
- On the card, keep the amber `Default` pill (already correct, `gateway-card.tsx:186-192`).

---

## ⑨ Zero-state and readiness

Tab 2 with no rows currently shows a bare empty DataTable. Replace with a purpose-built empty state:

- Icon `ph:credit-card` in `bg-slate-600 text-white`.
- *"No payment gateway configured"*
- *"Donation pages, campaigns and events cannot take an online payment until one gateway is
  configured and enabled."*
- A primary CTA `Browse available gateways` that switches to Tab 1, painted `brandGradient`.

Add a **readiness strip** above both tabs, always visible:

| Condition | Strip |
|---|---|
| No gateway configured | `bg-amber-600 text-white` chip + *"Online payments are off"* |
| Gateways configured but none enabled | same |
| Only Test-environment gateways enabled | `bg-amber-600 text-white` + *"Test mode only — no real payment will be captured"* |
| ≥1 Live gateway enabled, one is default | `bg-emerald-600 text-white` + *"Online payments are live via {name}"* |

This is the single highest-value addition on the screen: it answers, at a glance, the only question
a staff member actually has.

---

## ⑩ Colour and brand

| Forbidden (current) | Replacement |
|---|---|
| `border-primary/20 bg-primary/5 text-primary` overflow chip (`gateway-card.tsx:77`, `available-gateways-tab.tsx:169`) | `bg-slate-600 text-white` — same as its neighbours; the "+N more" chip is not brand-intent |
| `bg-muted/50` card header (`gateway-card.tsx:196`) | `bg-muted` flat |
| `bg-muted/30` card footer (`gateway-card.tsx:237`) and error panels | `bg-muted` flat |
| `bg-red-50 text-red-700 dark:…` webhook processing error (`webhook-log-drawer.tsx:182`) | `border-red-600 bg-card text-foreground`, with an `ph:warning` chip in `bg-red-600 text-white` |
| `text-primary` gateway icon (`gateway-card.tsx:198`, `available-gateways-tab.tsx:131`) | `style={brandText}` |
| primary CTAs — `Configure`, `+ New Gateway`, dialog Save | `style={brandGradient}` |
| card ring when the row is the default | `style={brandOutline}` |

Import from `@/presentation/utils/brand-surface`. The existing solid status badges — `FIT_TONE`,
`EnvBadge`, `StatusBadge` — are already correct house style. **Leave them alone.**

`text-muted-foreground` stays only on genuinely secondary prose (labels, hints). It is not a status
colour and must not carry an "empty/unknown" meaning on its own.

---

## ⑪ Responsive spec, xs → 2xl

Content column: `mx-auto w-full max-w-[1100px] xl:max-w-[1320px]`.

| Element | xs (`<640`) | sm (`640`) | md (`768`) | lg (`1024`) | xl (`1280`) |
|---|---|---|---|---|---|
| Tab 1 catalogue grid | 1 col | 2 col | **2 col** | **3 col** | 3 col *(today: 1 / 2 / — / — / 3)* |
| Tab 2 configured card grid | 1 col | 2 col | **2 col** | **3 col** | 3 col |
| Gateway card meta rows | label above value, stacked | stacked | **label left `w-24`, value right** | same | same *(today: always side-by-side — the 24-unit label column crushes the value at 375px)* |
| Card footer actions | wrap to two rows, toggle on its own row | inline | inline | inline | inline |
| `ChipStrip` max chips | 3 | 4 | 5 | 6 | 6 *(today: fixed 6/5/6 at every width)* |
| Tabs list | full-width, `flex-1` triggers | auto | auto | auto | auto |
| Readiness strip | icon + text wraps to two lines | one line | one line | one line | one line |
| Credential dialog | full-screen sheet | `max-w-lg` dialog | `max-w-lg` | `max-w-2xl`, two-column field pairs | `max-w-2xl` |
| Webhook log drawer | `w-full` | `sm:max-w-xl` (already correct) | same | `lg:max-w-2xl` | same |

`md:` appears **zero** times in the entire folder today. That column is the bulk of the new work.

---

## ⑫ Explicitly out of scope

1. `CompanyPaymentGatewayDto.ts`, `PaymentGatewayDto.ts`, `PaymentWebhookLogDto.ts` — no edits.
2. Any GraphQL query/mutation **contract** change.
3. The platform-side gateway surface — `(master)/platform/gateways`, `ops/gateways/*`,
   `ops/plans/platform-gateway-environment-panel.tsx`, `ops/tenants/tenant-gateway-activity.tsx`.
4. `card-grid/variants/payment-gateway-card.tsx` and its skeleton — the card-grid variant registry
   stays; only the leaf `gateway-card.tsx` it renders is restyled.
5. `shared-cell-renderers/gateway-brand-badge.tsx` / `gateway-cell.tsx` — used by other grids.
6. The webhook **ingestion** path, retry logic, or raw-payload fetching.
7. Backend, entities, migrations, seeds. If the mask-write-back bug (#3) turns out to need a backend
   fix, **write it up in the build log as a spec — do not implement it.**
8. Screen #168 "Gateway Master" — deliberately gone, not moved here.

---

## ⑬ Files touched

**New (4):** `gateway-config-dialog.tsx`, `csv.ts`, `readiness-strip.tsx`,
`dgf-widgets/secret-widget.tsx` (+ its registry entry)

**Modified (6):** `index-page.tsx`, `gateway-card.tsx`, `available-gateways-tab.tsx`,
`webhook-log-drawer.tsx`, `index.ts`,
`../../communicationconfig/smssetup/secret-input.tsx` (optional `helper` prop only)

---

## ⑭ Acceptance criteria — each one greppable

1. `handleConfigure` in `index-page.tsx` contains **no** `triggerGridAction` and **no** `toast.info`.
2. `gateway-config-dialog.tsx` exists, uses RHF, and its submit gate is `formState.isValid`.
3. No secret field in the dialog is ever given a `defaultValue` / `value` from a loaded row —
   grep the file for `encryptedApiKey` and confirm every occurrence is a *write*, never a seed.
4. The mutation variables object is built with conditional spread; `grep -c '"" as'` and
   `encryptedApiKey: ""` both return **0**.
5. `csvToList` / `listToCsv` exist in `csv.ts` and `gateway-card.tsx` imports `csvToList` instead of
   splitting inline.
6. All three CSV fields use `FancyMultiSelect`; `grep -c 'type="text".*supported'` returns **0**.
7. `gatewayEnvironment` is bound to a `ToggleGroup`, never a free-text input.
8. `grep -c "bg-primary/5\|border-primary/20\|bg-muted/50\|bg-muted/30\|bg-red-50\|text-red-700"`
   across the folder returns **0**.
9. `grep -c " md:"` across the folder returns **≥ 12** (today: 0).
10. `readiness-strip.tsx` exists and renders all four states in §⑨.
11. `secret-widget.tsx` exists in `dgf-widgets/` and is registered; no existing widget's behaviour
    changed.
12. `companyId` appears in **no** mutation variables object in the folder.
13. `rec.reason` is still rendered verbatim, unwrapped.
14. Test Connection still never renders a credential — `verdict.message` only.
15. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` exits **0**. Only exit 0 counts.
16. Manual pass at 375 / 640 / 768 / 1024 / 1280 / 1440 px, with zero / one Test / one Live +
    one Test gateway configured. Record findings in the build log.
17. The §⑤ verification of defect #3 is recorded in the build log — confirmed, refuted, or
    inconclusive, with what was observed.

---

## ⑮ Build agent + work order

**Model: Sonnet.** The spec is field-level and the surface is small. The only genuine judgement call
is §⑦ (whether the DataTable's add/edit options can be redirected), and the fallback for both is
written out.

1. Read the three governing prior prompts (§②.9) and
   `.claude/screen-tracker/prompts/companypaymentgateway.md` before touching code.
2. **Verify defect #3 first** (§⑤). It changes nothing about the plan, but it may be a live bug the
   user needs to know about today.
3. Read `CompanyPaymentGatewayMutation.ts` and `CompanyPaymentGatewayQuery.ts` end to end. Do not
   guess a field name.
4. Add `csv.ts`. Refactor `ChipStrip` onto it. Typecheck.
5. Build `gateway-config-dialog.tsx` — fields, RHF, validation, secret handling. Typecheck.
6. Wire Tab 1 Configure and Tab 2 New/Edit to it (§⑦). Remove the workaround. Typecheck.
7. Add `secret-widget.tsx` + registry entry (§⑤). Typecheck.
8. Default-gateway explanation and guards (§⑧).
9. `readiness-strip.tsx` + Tab 2 zero-state (§⑨).
10. Colour sweep (§⑩).
11. Responsive sweep (§⑪) — the long step; file by file, breakpoint by breakpoint.
12. `npx tsc --noEmit --incremental false`. Then append to the build log below.

---

## Build Log

*(append-only, newest first, last 5 sessions retained — git keeps the rest)*

### 2026-08-11 — full build, §⑮ steps 1-12

**Status: complete.** `npx tsc --noEmit --incremental false` → **EXIT=0**.

**Files new (5):** `gateway-config-dialog.tsx`, `csv.ts`, `readiness-strip.tsx`,
`data-table-form/dgf-widgets/secret-widget.tsx`, + its two registry keys (`secret`, `SecretWidget`)
in that folder's `index.tsx`.
**Files modified (6):** `index-page.tsx`, `gateway-card.tsx`, `available-gateways-tab.tsx`,
`webhook-log-drawer.tsx`, `index.ts`, `../../communicationconfig/smssetup/secret-input.tsx`.

`secret-input.tsx` gained two **optional** props only — `allowReveal` (default `true`) and
`resetRevealOnBlur` (default `false`). Both defaults reproduce the previous behaviour exactly, so
every SMS/WhatsApp usage is unchanged. The `helper` prop §⑤ asked about already existed.

#### AC #17 — defect #3 (mask write-back) is REFUTED, and the real finding is different

The prompt hypothesised that the generic form seeds an editable input from a **masked** credential and
posts the mask back, corrupting the stored key. Verified against the backend:

- `GetCompanyPaymentGatewaysQueryHandler` (the **list**) masks the three `encrypted*` fields.
- `GetCompanyPaymentGatewayByIdQueryHandler` does **not** — it carries
  `// Decrypt keys for admin view (GetById shows full keys)` and returns **plaintext**.
- RJSF seeds the edit form from `getById`, not from the list row.

So an untouched Save re-posts the true plaintext and re-encrypts it correctly. **No credential
corruption exists today.** The mask is only ever rendered in read contexts.

What the check surfaced instead is worse and real: **`companyPaymentGatewayById` ships decrypted
credentials over the wire to any caller holding Read permission on this grid.** Read is a much
weaker gate than "may rotate the payment credential", and the values land in the browser's Apollo
cache and in any request log along the path. Written up as spec B below; **not implemented** (§⑫.7).

Note this refutation does not make the dialog optional. The generic form still puts a live secret in
a visible text box, still has no write-only semantics, and the new `secret-widget.tsx` is what fixes
that for every *other* screen that authors a credential field.

#### §⑤ — "omit a blank secret entirely" is achievable for one of the three fields, not three

`encryptedApiKey` and `encryptedApiSecret` are declared `String!` on **both** mutations, both
validators call `ValidatePropertyIsRequired` on them, and `UpdateCompanyPaymentGatewayHandler`
re-encrypts both unconditionally. Omitting them on edit is a GraphQL error; sending `""` would
encrypt an empty credential over a working one. Only `encryptedWebhookSecret` is nullable.

Resolution shipped: in **edit** mode a blank secret box is resolved at submit time via
`useLazyQuery(COMPANYPAYMENTGATEWAY_BY_ID_QUERY, { fetchPolicy: "network-only" })` and passed
straight into the mutation variables. The fetched value is **never** bound to an input, never enters
form state, and is never rendered — it exists for the duration of one submit. Every other optional
field, and `encryptedWebhookSecret`, use the conditional spread §⑤ asks for. `companyId` is sent
nowhere (AC #12 grep: 0 hits in any variables object).

The clean fix is backend; see spec A. Once it lands, delete the passthrough block in
`gateway-config-dialog.tsx` and let all three secrets fall through the conditional spread.

#### Backend specs — written up, NOT implemented (§⑫.7)

**Spec A — blank secret must mean "keep the stored value".**
Relax `EncryptedApiKey` / `EncryptedApiSecret` to nullable on
`UpdateCompanyPaymentGatewayCommand` and drop their `ValidatePropertyIsRequired` calls **on the
update validator only** (create keeps them required). In `UpdateCompanyPaymentGatewayHandler`,
encrypt-and-assign each of the three only when the incoming string is non-empty; otherwise leave the
stored column untouched. This is the standard "write-only credential" contract and removes the
client-side round-trip above.

**Spec B — `GetCompanyPaymentGatewayById` must mask like the list does.**
Apply the same masking helper the list handler uses. Nothing in the product needs the plaintext on a
read path: the dialog never seeds a secret, the gateway SDK decrypts server-side at charge time, and
after spec A the update path no longer needs to read one back either. Land A before B — B alone
would break the passthrough this build currently depends on.

#### §⑦ — DataTable Add/Edit could NOT be redirected; the prompt's fallback was taken

`data-table-update-option.tsx` and the add option are hard-wired to `useGridForm` + `DataGridForm` +
`convertToFormGql` with no injection point for an alternate editor. So:
`enableAdd: false` + an explicit `+ New Gateway` button in a toolbar above the grid, gated on
`capabilities.canCreate` from `useAccessCapability({ menuCode: "COMPANYPAYMENTGATEWAY" })`; and
`enableActions.enableEdit: false` + a plain Edit button on the card footer calling
`openDialog({ mode: "edit", row })`. **Delete and Toggle stay on the DataTable's own options** as
specified. The route page resolves capabilities but passes none down and is out of §⑬ scope, so
`index-page.tsx` calls the hook itself.

The `+ New Gateway` button lands on Tab 1 rather than opening the dialog directly: create mode binds
to a specific gateway, which the dialog shows as a **read-only identity strip, never a dropdown**, so
the provider has to be chosen before the dialog can open. Sending the user to the catalogue is the
only way to honour §④ from a button that has no gateway in hand.

#### `forceMount` — REMOVED

It existed so the Tab 2 grid was mounted when Tab 1's Configure fired `triggerGridAction("new-record")`
into it — a fire-and-forget signal cleared 100 ms later, which needed a live listener. Configure now
opens the dialog directly and touches no grid state, so the handshake is gone. Checked the remaining
Tab 2 state for a second dependency and found none: the grid owns its paging/filter state in the
advanced-table store keyed by grid code, which survives unmount. Removed, and the tab content is a
plain `TabsContent` again.

Grid refresh after a save is now explicit instead: `GatewayDialogProvider`'s `onSaved` bumps a
`refreshKey` that both re-keys `<AdvancedDataTable>` and `refetch()`es the page's own
`COMPANYPAYMENTGATEWAYS_QUERY` read (which feeds the readiness strip, the zero-state and the
demotion notice).

#### Deliberate circular import — leave it alone

`gateway-card.tsx` imports `useGatewayDialog` from `gateway-config-dialog.tsx`; the dialog imports
`getGatewayIcon` back from the card. Both bindings are referenced only inside render bodies, never at
module-evaluation time, so ESM resolves it and tsc is clean. Do **not** "fix" this by duplicating
`getGatewayIcon` — the icon map must have one owner.

#### FancyMultiSelect — two quirks absorbed in `MultiSelectField`

Its `onValueChange` sits in a `useEffect` dependency array, so an inline arrow re-fires it every
render (infinite loop). Handled with a ref + `useCallback(…, [])` stable handler. Separately it reads
`selected` only as a `useState` initial value, so a preselection that arrives after the option list
does is ignored; handled with `key={`opts-${options.length}`}` to remount once options land.

Option sources are the existing masters, not hard-coded lists: currencies ← `CURRENCIES_QUERY`,
countries ← `COUNTRIES_QUERY` (alpha-2), methods ← MasterData `PAYMENTMETHODTYPE`. All three follow
the house `pageSize: -1, pageIndex: 0` convention.

#### AC results

| # | Criterion | Result |
|---|---|---|
| 1 | no `triggerGridAction` / `toast.info` in the folder | 0 hits |
| 3 | every `encryptedApiKey` in the dialog is a write | 4 hits: 2 comments, 1 submit-time passthrough assignment, 1 mutation variable. **No seed into any input.** |
| 4 | `'"" as'` and `encryptedApiKey: ""` | 0 / 0 |
| 6 | `type="text".*supported` | 0 |
| 8 | forbidden-colour grep | 0 (the only `border-primary` left is a `focus:` ring in the shared secret widget) |
| 9 | `grep -o ' md:' \| wc -l` ≥ 12 | **15** |
| 12 | `companyId` in a mutation variables object | 0 (one hit, a comment explaining why it is absent) |
| 15 | `npx tsc --noEmit --incremental false` | **EXIT=0** |

#### AC #16 — responsive: verified by inspection, NOT in a browser

**This is the one criterion not fully met as written.** This environment has no browser, so the
375 / 640 / 768 / 1024 / 1280 / 1440 px pass across the zero / one-Test / one-Live+one-Test states was
done by reading the class ladders, not by rendering them. What is in place:

- content column `mx-auto w-full max-w-[1100px] xl:max-w-[1320px]`
- both grids `grid-cols-1 sm:grid-cols-2 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-3`
- card meta rows stacked below `md:`, then `label left w-24`
- footer actions wrap, toggle on its own row at xs
- ChipStrip reveal ladder 3 / 4 / 5 / 6 / 6, CSS-only
- tab triggers `flex-1` at xs, `sm:flex-none` above
- readiness strip: icon + headline hold line 1, detail is `w-full md:w-auto`
- dialog full-screen sheet at xs → `sm:max-w-lg` / `md:max-w-lg` → `lg:max-w-2xl` two-column
- drawer `w-full` → `sm:max-w-xl` → `lg:max-w-2xl`

Someone with the app running should still do the visual pass, particularly the dialog's xs
full-screen sheet and the card footer wrap — those are the two places a class ladder can look right
and read wrong.
