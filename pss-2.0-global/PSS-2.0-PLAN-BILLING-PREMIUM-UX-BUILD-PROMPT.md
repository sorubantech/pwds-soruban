# PSS 2.0 — Plan & Billing Premium UX Build Prompt

> **Status:** BUILT — §①–⑧ complete, `tsc --noEmit --incremental false` exit 0. (Read §⑬.)
> **Surface:** tenant `(core)/billing/*` + the shared `presentation/components/plan/*` shell widgets.
> **Screen tracker:** this is a `/continue-screen` style FE-only pass over the P-12 / P-13 / P-14
> billing work. It is **front-end only**: no entity, no migration, no GraphQL schema change.

---

## ① Why this exists

The billing surface is functionally complete and visually unfinished. Every architectural decision in
it is correct — the cards render server-decided outcomes, no amount is re-derived client-side, the
tones are solid not tinted — but a tenant staff member arriving at `/billing/plans` sees three
identical bordered rectangles in a two-column grid with no visual hierarchy, no sense of which plan
they should be looking at, and a price set in the same type size as the plan description.

Three concrete defects, all verified in code:

1. **The tenant's brand colour never reaches this surface.** `useShellAccent` overrides `--primary`,
   `--primary-foreground` and `--ring` from the tenant's `PRIMARY_COLOR_HEX`. It does **not** touch
   the numbered scale. Every brand-intent surface on the billing pages is written as `bg-primary-600`
   / `border-primary-600`, and `--primary-600: 254 86% 58%` in `globals.scss` is a **static platform
   violet**. So a tenant who configured a green brand sees violet chips on their own billing page.
   Ten sites, listed in §④.

2. **Responsive coverage is partial.** `billing-plans-page.tsx` uses `grid-cols-1 md:grid-cols-2
   xl:grid-cols-3` — no `sm:`, no `lg:`, so a 900px tablet gets two very wide cards and a 1100px
   laptop gets two cards with a third orphaned on the next row. `billing-overview-page.tsx` jumps
   `sm:` → `xl:` and skips the whole middle. §⑦ specifies every breakpoint for every element.

3. **No hierarchy on the cards.** The only differentiation that exists is
   `border-primary-600 ring-1 ring-primary-600` on the current plan. There is no elevation, no
   recommended treatment, no tier identity, no price emphasis, and the `allFeatureCodes` /
   `allMeterCodes` arrays the server already returns are fetched and thrown away — the comparison
   data is on the wire and unrendered.

The audience is **tenant staff, specifically the BUSINESSADMIN** — the one person in the org who can
actually spend money. They arrive here in one of three moods: a trial is ending, a limit was hit, or
a payment failed. Every layout decision below is ordered by that.

---

## ② The rule this build must not break

Copied forward from `billing-plans-page.tsx`, unchanged and load-bearing:

> **No card decides its own behaviour.** Whether a plan is purchasable comes from `canSelfServe` on
> the server, and the sentence explaining a refusal comes from `selfServeBlockedReason` via
> `selfServeBlockedCopy()`. Which branch a card takes is an OUTCOME of the data, not a string typed
> into JSX.

And from `billing-overview-page.tsx`:

> **No amount on this page is re-derived.** Everything is the snapshot the subscription carries, so a
> catalogue reprice never silently restates what the tenant is being charged today.

A premium redesign that computes a "save 20% annually" figure, invents a discount, or hardcodes
"Most popular" on the middle card violates both. §⑤ says what may be derived and how.

---

## ③ The two colour systems — the actual mechanism

There is no new theming work. The mechanism exists and is correct; the billing surface simply does
not consume it.

`presentation/hooks/useShellAccent/index.ts` publishes five CSS variables on `documentElement`, and
picks its source from `navSource`:

| Variable | `(master)` — platform | `(core)` — tenant |
| --- | --- | --- |
| `--shell-accent` | `#8c37eb` (static) | `PRIMARY_COLOR_HEX`, else `hsl(var(--primary))` |
| `--shell-accent-2` | `#315deb` (static) | `SECONDARY_COLOR_HEX`, else = accent |
| `--shell-accent-gradient` | `linear-gradient(135deg,#8c37eb,#315deb)` | tenant pair, flattens to solid when only a primary is set |
| `--shell-accent-gradient-soft` | same at 95% alpha | same |
| `--shell-accent-foreground` | `#ffffff` | **WCAG-derived** — `#111827` on a pale brand |

Plus three derived-at-use-time values from `globals.scss` that follow whatever the accent currently
is: `--shell-accent-soft` (8% tint), `--shell-accent-hover` (14%), `--shell-accent-border` (30%).

**Therefore the rule for this build is a single sentence:** *every brand-intent surface paints from
`var(--shell-accent*)`; every semantic-status surface keeps its solid `bg-X-600 text-white` token.*
Do that and the platform surface renders the static product gradient and the tenant surface renders
their own colour, from one code path, with no `navSource` branch anywhere in a billing component.

### ③.1 What counts as brand vs. status

| Brand intent → accent vars | Status intent → keep `bg-X-600 text-white` |
| --- | --- |
| Current-plan ring, badge, tier rail | Subscription status chip (`subscriptionStatusTone`) |
| Recommended-plan gradient border + ribbon | Invoice status chip (`invoiceStatusTone`) |
| Price hero emphasis | Past-due banner (`bg-destructive-600`) |
| Primary CTA fill | Trial banner tone (`bg-info-600` / `bg-warning-600`) |
| Feature-check chip on the recommended card | Meter warning strips (`bg-warning-600` / `bg-destructive-600`) |
| Usage-meter "ok" fill | Usage-meter warn/over fills |

The house rule "solid `bg-X-600` + `text-white`, never a tint" is **unchanged** for the status column.
The brand column is exempt from the numbered-token form only because the accent is a free-form hex
and its readable foreground is computed — that is what `--shell-accent-foreground` is for. Nothing
here licenses `bg-primary-50` or `text-primary-700` anywhere.

**Do not** hardcode `#8c37eb` / `#315deb` in any component. `PLATFORM_BRAND_*` in
`application/constants/platform-brand.ts` is the only place those hexes live.

---

## ④ New shared module — `brand-surface.ts`

Create `src/presentation/components/plan/brand-surface.ts`. Style objects, not Tailwind classes,
because Tailwind arbitrary values cannot reference a runtime CSS variable through the class scanner
in every position (border-image, gradient stops) and a helper keeps the vocabulary in one file.

```ts
/** Solid accent fill + its computed readable foreground. The everyday brand chip. */
export const brandSolid: React.CSSProperties = {
  backgroundColor: "var(--shell-accent)",
  color: "var(--shell-accent-foreground)",
};

/** The two-stop brand gradient. Flat on a tenant with only a primary; the product violet→blue on
 *  the platform surface. Used for the recommended card's ribbon and the primary CTA. */
export const brandGradient: React.CSSProperties = {
  backgroundImage: "var(--shell-accent-gradient)",
  color: "var(--shell-accent-foreground)",
};

/** The 8% wash + 30% border used for panels that belong to the brand but must not shout. */
export const brandSoft: React.CSSProperties = {
  backgroundColor: "var(--shell-accent-soft)",
  borderColor: "var(--shell-accent-border)",
};

/** Accent-coloured text/icon on a neutral ground. */
export const brandText: React.CSSProperties = { color: "var(--shell-accent)" };

/** Focus ring + hover border on an accent-owned interactive element. */
export const brandRing: React.CSSProperties = { outlineColor: "var(--shell-accent)" };
```

### ④.1 The ten replacement sites (all verified present)

| File | Line ref | Today | Becomes |
| --- | --- | --- | --- |
| `billing-plans-page.tsx` | card shell | `border-primary-600 ring-1 ring-primary-600` | `style={{ borderColor: "var(--shell-accent)", boxShadow: "0 0 0 1px var(--shell-accent)" }}` |
| `billing-plans-page.tsx` | current badge | `bg-primary-600 text-white` | `style={brandSolid}` |
| `billing-plans-page.tsx` | contact-us icon chip | `bg-primary-600 text-white` | `style={brandSolid}` |
| `billing-overview-page.tsx` | plan-name badge | `bg-primary-600 text-white` | `style={brandSolid}` |
| `billing-checkout-page.tsx` | plan badge | `bg-primary-600 text-white` | `style={brandSolid}` |
| `plan-switch-dialog.tsx` | target-plan panel | `border-primary-600 ring-1 ring-primary-600` | accent border + ring, as above |
| `plan-switch-dialog.tsx` | arrow chip | `bg-primary-600 text-white` | `style={brandSolid}` |
| `plan-usage-panel.tsx` | `ok` meter fill | `bg-primary-600 text-white` | `style={brandSolid}` |
| `plan-usage-panel.tsx` | plan badge | `bg-primary-600 text-white` | `style={brandSolid}` |
| `communication-usage-panel.tsx` | `ok` meter fill | `bg-primary-600 text-white` | `style={brandSolid}` |

The meter maps in the two usage panels are `Record<string, string>` of class names. Convert them to
`Record<string, { className?: string; style?: React.CSSProperties }>` so `ok` can carry a style while
`warn` / `over` keep their `bg-warning-600` / `bg-destructive-600` classes untouched.

`upgrade-cta.tsx` uses `<Button color="primary">`, which resolves through `hsl(var(--primary))` —
that token **is** overridden by `useShellAccent`, so it is already correct. Leave it.

`plan-status-chip.tsx` keeps its amber gradient. That is a deliberate decision recorded in the file:
the upgrade action is the one revenue affordance in the shell and reads as an *offer*, not as brand
chrome. Making it follow a tenant's brand would camouflage it against the very rail it sits on. **Do
not repaint it.** The surrounding tone strip (`bg-info-600` / `bg-warning-600` / `bg-destructive-600`)
stays urgency signalling and is also unchanged.

---

## ⑤ The premium plan card

### ⑤.1 What may be derived

`SellablePlanDto` carries: `planId, planCode, planName, description, sortOrder, isCustom,
isCurrentPlan, trialDurationDays, amount, currencyCode, priceSource, canSelfServe,
selfServeBlockedReason, features[], quotas[]`.

There is **no** `isRecommended`, `isPopular`, `tier`, `badgeText` or `colorHex` field, and none is to
be added. Everything visual must fall out of what is above.

**Recommended treatment — the derivation, in one place, `recommendedPlanId(plans)`:**

- If a plan has `isCurrentPlan`, the recommended plan is the next non-custom plan by ascending
  `sortOrder` that is strictly above it. Copy: **"Your next step up"**.
- If no plan is current (`currentPlanCode === "None"`), it is the lowest-`sortOrder` non-custom plan
  with a non-null `amount`. Copy: **"Recommended to start"**.
- If neither resolves, **nothing is recommended** and no card gets the treatment. A grid with no
  ribbon is correct; a ribbon on an arbitrary card is not.

Never render "Most popular". We cannot evidence a claim about other customers' choices — the
marketing plans section already refuses this for the same reason, and the two surfaces must not
disagree.

**Tier identity** is `sortOrder`-indexed, not name-matched: position 0 → `ph:seedling`, 1 →
`ph:plant`, 2 → `ph:tree`, 3+ → `ph:buildings`; `isCustom` always → `ph:handshake`. Icon only. Do not
invent a per-tier colour — that would compete with the tenant's brand.

### ⑤.2 Card anatomy, top to bottom

```
┌─────────────────────────────────────┐
│ ▔▔▔ accent ribbon (recommended only)│  h-1.5, style={brandGradient}
├─────────────────────────────────────┤
│ [tier icon]  PLAN NAME     [badge]  │  badge = "Current plan" (brandSolid) or ribbon label
│ description — 2 lines, clamped      │  line-clamp-2, min-h reserved so cards align
├─────────────────────────────────────┤
│  ₹ 4,999      / month               │  PRICE HERO — see ⑤.3
│  Converted from our published price │  priceSource line, text-xs, only when FX
│  Includes a 14-day free trial.      │  only when trialDurationDays
├─────────────────────────────────────┤
│  WHAT'S INCLUDED                    │  eyebrow, uppercase tracking-widest text-[0.625rem]
│  ✓ Donations                        │  first 5 enabled features
│  ✓ Grants                           │
│  + 4 more                           │  <button> toggling the rest; not a link, not a tooltip
├─────────────────────────────────────┤
│  LIMITS                             │
│  Contacts              25,000       │  tabular-nums, text-right
│  Emails / month        10,000       │
├─────────────────────────────────────┤
│  [        CTA — see ⑤.4         ]   │  mt-auto so every card's CTA sits on one line
└─────────────────────────────────────┘
```

Elevation: `border border-default-200 shadow-sm transition-shadow hover:shadow-md`. Recommended card
additionally: accent border, `shadow-lg`, and at `lg` and above `lg:-translate-y-2 lg:scale-[1.02]`
so it physically breaks the row. Below `lg` the lift is dropped — a card that pokes out of a
single-column stack just looks misaligned. Current-plan card: accent border + accent 1px ring, **no**
lift (it is a state, not an offer).

A card can be both current and recommended only if the derivation is wrong; assert it cannot by
excluding `isCurrentPlan` from the recommendation candidates.

### ⑤.3 Price hero

The single largest thing on the card. `text-3xl font-bold tracking-tight tabular-nums` at `xs`,
`text-4xl` from `md`. Three branches, unchanged in behaviour from today:

- `isCustom` → the word **"Let's talk"**, and the cycle line reads "Priced with you". The `amount` is
  a 0 anchor and must never be printed.
- `amount != null` → `formatMoney(plan.amount, plan.currencyCode ?? quoteCurrencyCode)`, with
  `/ {formatCycle(billingCycle).toLowerCase()}` as a `text-sm text-default-500` sibling on the same
  baseline.
- otherwise → **"Price on request"** at `text-2xl`, never `—`, never `0`.

`amount === 0` prints as **"Free"** with cycle line "No cost, not a trial". That is a formatting
choice about a real value, not a derivation.

The `priceSource` line renders only when `priceSource === "FX"`, using `PRICE_SOURCE_LABEL.FX`. FREE
and BOOK are the unremarkable cases and a line explaining them is noise.

### ⑤.4 CTA — three branches, behaviour unchanged

| Condition | Render |
| --- | --- |
| `plan.isCurrentPlan` | full-width `variant="outline"` disabled, "Your current plan", `ph:check-circle` |
| `plan.canSelfServe` | `<PlanSwitchDialog>` trigger, full-width, `style={brandGradient}` on the recommended card and `style={brandSolid}` otherwise, label "Switch to {planName}" (or "Get started" when there is no current plan) |
| else | the bordered contact panel, `style={brandSoft}`, accent icon chip, body = `selfServeBlockedCopy(plan.selfServeBlockedReason)` |

The contact panel stays **not a link**. There is no in-product contact route; making it look
clickable and doing nothing is worse than the sentence alone.

The checkout href keeps `cycle=${encodeURIComponent(formatCycle(billingCycle))}` — **`formatCycle`,
not `.toUpperCase()`.** The API validates case-SENSITIVELY against "Monthly" / "Annual". This comment
must survive the refactor; it is the kind of thing a redesign silently breaks and `tsc` cannot catch.

---

## ⑥ New: the comparison matrix

`MySellablePlansDto` already returns `allFeatureCodes: string[]` and `allMeterCodes: string[]`. The
page fetches both and renders neither. Build the comparison off them — **zero BE change**.

Placement: below the card grid, behind a `<Collapsible>` labelled "Compare all plans side by side",
collapsed by default. The cards answer "which one", the matrix answers "prove it"; opening it by
default pushes the CTAs below the fold on a laptop.

- Rows: `allFeatureCodes` (via `featureLabel()`), then a separator row "Limits", then `allMeterCodes`
  (via `meterLabel()`).
- Columns: the same sorted `plans` array, current plan column with an accent-tinted header cell
  (`style={brandSoft}`).
- Cell for a feature: `ph:check` in an accent chip when the plan's `features` entry has
  `isEnabled === true`; `ph:minus` in `text-default-400` when absent or false. Never a blank cell —
  blank reads as "not loaded".
- Cell for a meter: `quotaText(limitValue, period)`, `tabular-nums text-right`. Missing meter → `—`.
- The plan-name header row is `sticky top-0` inside the scroll container so a 14-row matrix stays
  readable.

Below `md` the matrix is not a table. Render one `<Accordion>` item per plan, each listing that
plan's features and limits — a 4-column table on a 390px phone is a horizontal-scroll trap, and a
tenant admin checking a limit on their phone is a real case.

---

## ⑦ Responsive spec — every element, every breakpoint

Tailwind defaults: `xs` = base (< 640), `sm` ≥ 640, `md` ≥ 768, `lg` ≥ 1024, `xl` ≥ 1280.
**Every rule below must be present in the built markup — this is the checklist §⑪ tests against.**

### ⑦.1 `/billing/plans`

| Element | xs | sm | md | lg | xl |
| --- | --- | --- | --- | --- | --- |
| Page padding | `px-4 py-4` | `px-5` | `px-6 py-6` | — | — |
| Header (title + actions) | stacked, actions full-width | actions inline, `justify-between` | — | — | — |
| Arrival note | below title | inline under title | — | — | — |
| Card grid | `grid-cols-1 gap-4` | `sm:grid-cols-2 sm:gap-5` | — | `lg:grid-cols-3 lg:gap-6` | `xl:gap-8` |
| Recommended card | in flow | `sm:col-span-2` when the count is odd | — | `lg:col-span-1` + lift | — |
| Price hero | `text-3xl` | — | `md:text-4xl` | — | — |
| Includes list | 5 + "more" | — | — | `lg:` show 7 before truncating | — |
| Card CTA | full-width `h-11` | — | `md:h-10` | — | — |
| Comparison | accordion per plan | — | `md:` table | sticky header | — |
| Skeletons | 1 card | 2 | 2 | 3 | 3 |

Skeleton count must match the grid at each breakpoint. Rendering three skeletons into a
single-column phone layout produces a 1200px grey wall.

### ⑦.2 `/billing`

| Element | xs | sm | md | lg | xl |
| --- | --- | --- | --- | --- | --- |
| Header actions | stacked full-width, primary first | `sm:flex-row sm:w-auto`, primary last | — | — | — |
| Trial / past-due banner | stacked, CTA full-width below text | `sm:flex-row sm:items-center sm:justify-between` | — | — | — |
| Banner icon | hidden below `sm` (the copy carries it) | shown | — | — | — |
| `Fact` grid | `grid-cols-2 gap-2` | `sm:gap-3` | `md:grid-cols-4` | — | — |
| Status card header | stacked badges, wrap | inline | — | — | — |
| Auto-renew panel | switch above copy | switch right-aligned inline | — | — | — |
| Recent invoices | stacked rows (label above value) | two-column rows | table-like alignment | — | — |
| Usage panel | 1 meter per row | — | `md:grid-cols-2` | — | `xl:grid-cols-3` |

`Fact` at `grid-cols-2` on a phone, not `grid-cols-1`: the four values are short (a date, a cycle
word, an amount) and one-per-row pushes the invoice list off a 390px screen entirely.

### ⑦.3 Checkout, invoices, dialog

- **Checkout** — summary panel is `order-first` below `lg` (a tenant must see what they are buying
  before the card form) and `lg:order-last lg:sticky lg:top-4` beside it. The card form is
  single-column throughout; a two-column card form is a known conversion sink.
- **Invoices** — the data table gets its existing responsive treatment; verify the amount column
  keeps `text-right tabular-nums` at every width and that status chips do not wrap their label.
- **`PlanSwitchDialog`** — `max-w-lg` from `sm`, full-screen sheet below it (`inset-0 rounded-none`).
  The diff list stays single-column at all widths; a side-by-side "from → to" collapses to stacked
  "from" over "to" with the arrow chip rotated 90° below `sm`.
- **`PlanStatusChip`** — already correct (`lg:` two-tier label, compact `{n}d` below). Leave it.
- **`PlanStatusBanner`** — already `sm:flex-row`. Add `md:` nothing; verify the `UpgradeCta` inside
  it is `w-full sm:w-auto`.

### ⑦.4 Universal

- No fixed pixel widths on any new element. No `w-[320px]`, no `min-w-[900px]` outside the matrix's
  own `overflow-x-auto` container.
- Every long value (`planName`, `featureLabel`, currency-formatted amount) needs `break-words` or
  `truncate` + `title`. A tenant with a 40-character plan name must not blow the grid out.
- Every interactive element ≥ 44px touch target below `sm`.
- Every list that can be empty has an explicit empty state — no zero-height gaps.

---

## ⑧ Loading, error and empty states

All three guard states on the plans page stay exactly as they are in behaviour, upgraded in form:

- **Not a billing admin** — `ph:lock-key` in a `bg-default-500` chip. Unchanged.
- **Query error** — `bg-destructive-600` chip + "Try again" that calls `refetch()`. Unchanged.
- **No plans published** — `bg-info-600` chip. Unchanged.
- **Loading** — replace the flat `h-96` rectangles with **shaped** skeletons that mirror the card
  anatomy: title bar, price bar (wider, taller), five short list bars, a full-width CTA bar. Count
  per §⑦.1. This is the house rule on skeletons and the current page violates it.

The overview page's `Fact` tiles get matching shaped skeletons rather than a single block.

---

## ⑨ Explicitly out of scope

- **A monthly / annual toggle.** `mySellablePlans` takes **no arguments** and returns one
  `billingCycle` — the tenant's current one. A toggle is not renderable without a BE change
  (`mySellablePlans(cycle: String)` plus a price-ladder lookup per cycle). Do not fake it by
  multiplying the monthly amount by 12, or by 10 with a made-up discount. If the product wants it,
  it is a separate BE prompt.
- **Any entity, migration, snapshot, DTO-field or GraphQL-schema change.** If a design idea in this
  document appears to need a new field, the idea is wrong — drop it and note it in §⑬.
- **`plan-status-chip.tsx`'s amber gradient.** See §④.
- **The marketing `plans-section.tsx`.** Public surface, different data contract
  (`PublicPlanTeaserDto`), already has its premium treatment. Referenced here only as the visual
  precedent for gradient-border cards.
- **The `(master)` ops/plans matrix and platform billing pages.** They inherit the correct static
  gradient automatically once `brand-surface.ts` exists; audit them for `primary-600` misuse and
  report in §⑬, but do not restyle them in this pass.

---

## ⑩ Files touched

**New**
- `src/presentation/components/plan/brand-surface.ts`
- `src/presentation/components/page-components/billing/plan-comparison-matrix.tsx`
- `src/presentation/components/page-components/billing/plan-card-skeleton.tsx`

**Modified**
- `src/presentation/components/page-components/billing/billing-plans-page.tsx`
- `src/presentation/components/page-components/billing/billing-overview-page.tsx`
- `src/presentation/components/page-components/billing/billing-checkout-page.tsx`
- `src/presentation/components/page-components/billing/plan-switch-dialog.tsx`
- `src/presentation/components/page-components/billing/billing-invoices-page.tsx` (responsive audit only)
- `src/presentation/components/page-components/billing/index.ts` (exports)
- `src/presentation/components/plan/plan-usage-panel.tsx`
- `src/presentation/components/plan/communication-usage-panel.tsx`
- `src/presentation/components/plan/plan-status-banner.tsx` (CTA width only)

**Untouched, by decision** — `upgrade-cta.tsx`, `plan-status-chip.tsx`, `quota-guard.tsx`,
`feature-guard.tsx`, `plan-enforcement-provider.tsx`, `useEntitlements`, every `*Dto.ts`, every
`*Query.ts`, the whole backend.

---

## ⑪ Acceptance criteria

1. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` exits **0**. A run that reports only
   a pre-existing config error checked zero files and does not count.
2. `grep -rn "primary-600\|primary-500\|primary-700" src/presentation/components/page-components/billing src/presentation/components/plan`
   returns **zero** matches.
3. `grep -rn "#8c37eb\|#315deb" src/presentation/components/page-components/billing src/presentation/components/plan`
   returns **zero** matches.
4. Every semantic tone (`bg-success-600`, `bg-warning-600`, `bg-destructive-600`, `bg-info-600`,
   `bg-default-500`) is still solid with `text-white`. No `bg-X-50`, `bg-X-100`, `text-X-700`,
   `text-X-800`, `bg-muted` or `text-muted-foreground` introduced anywhere in the touched files.
5. Every table row in §⑦ is present in the markup. Spot-checkable: the plans grid contains
   `grid-cols-1`, `sm:grid-cols-2` and `lg:grid-cols-3`; the overview `Fact` grid contains
   `grid-cols-2` and `md:grid-cols-4`.
6. `selfServeBlockedCopy` remains the **only** source of refusal wording. No new hardcoded
   "contact us" sentence in any component.
7. No amount is arithmetically transformed. `formatMoney` in, string out. No `* 12`, no `* 0.8`.
8. The checkout href still passes `cycle` through `formatCycle`, and the comment explaining why
   survives.
9. `recommendedPlanId()` returns `null` for a single-plan tenant and for a tenant already on the top
   plan, and no ribbon renders in either case.
10. The comparison matrix renders as an accordion below `md` and a table at `md` and above, from the
    same `allFeatureCodes` / `allMeterCodes` arrays — no new query, no new field.
11. Loading skeletons are shaped (multiple bars mirroring the card), not single rectangles, and their
    count matches the grid at each breakpoint.
12. No file under `PSS_2.0_Backend/` is modified. No `Migrations/` file. No `*ModelSnapshot.cs`.
    No `*Dto.ts` and no `*Query.ts` modified.
13. Manual pass at 375, 640, 768, 1024, 1280 and 1440 px on `/billing`, `/billing/plans`,
    `/billing/checkout` and `/billing/invoices`: no horizontal scroll on the page body, no clipped
    text, no overlapping elements, every CTA reachable without zoom.

---

## ⑫ Build agent

**Model: Sonnet.** This is a detailed FE-only spec with an explicit file list, an explicit
find-and-replace table and mechanical acceptance criteria. One frontend-developer agent, one pass.

Order of work: `brand-surface.ts` first → the ten replacements → card redesign → comparison matrix →
skeletons → responsive sweep → `tsc`.

---

## ⑬ Build log

_(Append-only. Newest first. Keep the last 5 sessions; git holds the rest.)_

### Session 2 — 2026-08-10 — BUILT

Built in-session (no subagent — session config forbids AgentTool without an explicit user request,
which overrides §⑫'s frontend-developer). Order followed §⑫ exactly.

**New files (3):** `plan/brand-surface.ts` (`brandSolid` / `brandGradient` / `brandSoft` / `brandText`
/ `brandRing` / `brandOutline`, all reading `var(--shell-accent*)`), `plan/index.ts` barrel,
`billing/plan-comparison-matrix.tsx`.

**Modified (9):** `billing-plans-page.tsx` (full premium card redesign + `recommendedPlanId` +
tier icons by `sortOrder` position + matrix mount), `billing-overview-page.tsx`,
`billing-checkout-page.tsx`, `billing-invoices-page.tsx`, `plan-switch-dialog.tsx`,
`plan-usage-panel.tsx`, `communication-usage-panel.tsx`, `plan-status-banner.tsx`,
`plan-card-skeleton.tsx`.

Notes on decisions taken during the build:
- Both usage panels' meter maps converted from `Record<string,string>` to
  `Record<string,{className?;style?}>` as §④ requires; only the *brand-intent* entry moved to
  `style`, semantic status tones stayed solid `bg-X-600 text-white`.
- Checkout §⑦.3 implemented as an `lg:grid` with `lg:max-w-5xl`; the summary is first in source order
  (so it is `order-first` below `lg`) and carries `lg:order-last lg:sticky lg:top-4`. Payment form is
  single-column at every width.
- Checkout page padding lives inside `StateCard` rather than at the four gate call sites, so no guard
  state can be missed.
- Overview header uses `order-first … sm:order-none` on the primary button — primary reads first at
  xs without moving it ahead of the secondary in DOM/tab order.
- Auto-renew row uses `flex-col-reverse` at xs so the switch precedes its long consequence copy.
- `planId` is `number`, so `recommendedPlanId` returns `{ planId: number; label: string } | null` and
  the matrix accordion uses `String(plan.planId)` for its `value` / `defaultValue`.
- The `cycle=${encodeURIComponent(formatCycle(billingCycle))}` comment survived the refactor.

**Acceptance:**
- §⑪.2 `grep -rn "primary-600\|primary-500\|primary-700" plan/ page-components/billing/` → the only
  two hits are prose inside `brand-surface.ts`'s own doc comment explaining the defect. Zero class
  usages.
- §⑪.3 `grep -rn "#8c37eb\|#315deb"` over the same folders → zero.
- `tsc --noEmit --incremental false` → **exit 0**.
- §⑪.13 breakpoint pass at 375/640/768/1024/1280/1440 is a manual check and has NOT been run — code
  is written to the §⑦ rules but no browser verification happened.

**§⑨ `(master)` audit — report only, nothing restyled:** three `bg-primary-600` sites remain on the
platform surface — `ops/intimations/platform-intimations-list-page.tsx:74` (`ACTIVE` status tone),
`ops/tenants/tenant-usage-panel.tsx:49` (`ok` tone) and `:154` (a count badge). All three are
*correct as-is*: `(master)` has no tenant brand to inherit, so the static platform violet is the
intended colour there. No change recommended.

**Known issues:** manual breakpoint verification outstanding (§⑪.13). No blocked work.

### Session 1 — 2026-08-10 — PLANNED (NOT BUILT)

Prompt authored. Discovery covered `billing-plans-page.tsx`, `billing-overview-page.tsx`,
`plan-status-banner.tsx`, `plan-status-chip.tsx`, `upgrade-cta.tsx`, `billing-format.ts`,
`plan-switch-dialog.tsx` (head), `BillingDto.ts`, `PlanDto.ts`, `BillingQuery.ts`, `useShellAccent`,
`platform-brand.ts`, `globals.scss` and `marketing/sections/plans-section.tsx`.

Findings that shaped the spec:
- `useShellAccent` overrides `--primary` / `--primary-foreground` / `--ring` but **not** the numbered
  scale, so all ten `primary-600` sites on the billing surface render the static platform violet on a
  tenant page. This is the root cause of the colour complaint, and it is a class-name problem, not a
  theming one.
- `mySellablePlans` takes no arguments → a cycle toggle is not buildable FE-only. Cut, §⑨.
- `allFeatureCodes` / `allMeterCodes` are already on the wire and unrendered → the comparison matrix
  costs zero BE work.
- `SellablePlanDto` has no recommendation field → derived deterministically from `sortOrder` and
  `isCurrentPlan`, and "Most popular" is refused for the same reason the marketing section refuses it.

**Known issues carried in:** none. Nothing in this prompt is blocked on the user.
