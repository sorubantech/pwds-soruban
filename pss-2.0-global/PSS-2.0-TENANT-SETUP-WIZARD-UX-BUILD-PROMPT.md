# PSS 2.0 — Tenant First-Login Setup Wizard: UX & Re-entry Build Prompt

> **Screen:** Tenant first-login setup wizard
> **Route:** `(setup)` route group — `/{lang}/setup` (chrome-free), plus a new in-dashboard re-entry surface
> **Component folder:** `presentation/components/page-components/setting/tenantsetup/`
> **Related surfaces:** `app/[lang]/(setup)/layout.tsx`, `dashboards/widgets/tenant-setup-widgets/TenantSetupChecklistWidget/`
> **Status:** NOT STARTED
> **Scope:** Frontend only — no entity, DTO, GraphQL schema or migration changes
> **Model:** Sonnet

---

## ① Why this exists

The wizard works. It is well-reasoned code with an unusually honest docblock, and most of what follows
is not a bug report — it is the gap between "a tenant can complete setup" and "a tenant enjoys the
first ten minutes of the product and comes out the other side with the app wearing their colours."

Two findings are not cosmetic. **D-1** means a tenant who has already finished setup and clicks a row
in their dashboard checklist is thrown back into the entire eight-step wizard with a `Finish setup`
button. **D-9** means a tenant who does not have their logo already hosted at a public URL cannot
enter the product at all.

| # | Defect | Evidence | Why it matters |
|---|---|---|---|
| **D-1** | **Re-entry replays the whole wizard.** The checklist widget row does `router.push(\`/${lang}/setup#${meta.anchor}\`)`; the wizard reads the hash, slides to that one section — and then still presents Back / Next / `Step n of 8` / `Finish setup`. A settled tenant editing one field re-enters the full deck and re-fires `finish: true`. | `TenantSetupChecklistWidget.tsx:135`; `tenant-setup-wizard.tsx:1036-1046`, `:1084-1150` | Editing one setting should not look like starting over. This is also exactly where the user's modal instinct is right — see §③. |
| **D-2** | **`xl:` = 0 across both wizard files.** `sm:4 md:25 lg:7 xl:0` in the wizard, `sm:1 md:1 lg:0 xl:0` in the header. The page is capped at `max-w-5xl` (~1024px) at every breakpoint including the loading and error branches. | `:1155`, `:1170`, `:1215`, `:1346`, `:1573`; `tenant-setup-header.tsx` | On a 1920px monitor a three-column form sits in a 1024px column with 900px of empty page either side. The first screen a tenant ever sees looks unfinished. |
| **D-3** | **Zero brand adoption.** `grep` for `brand-surface` / `--shell-accent` over the folder returns **0**. Every accent surface is `bg-primary`: the header rocket tile, the h1 tile, the active step bar, the section icon tile, the widget row tile. | `:1219`, `:1264`, `:1300`; `tenant-setup-header.tsx`; `TenantSetupChecklistWidget.tsx:140` | `useShellAccent` overrides `--primary`, so these are not *wrong* — but the wizard is the screen where the tenant **chooses** their colour, and it never reflects the choice back. `brand-surface.ts` exists and is used by billing; this folder has never touched it. |
| **D-4** | **Hand-rolled progress bar.** `<div className="h-2 flex-1 overflow-hidden rounded-full bg-muted">` with an inner `bg-emerald-600` div at `style={{width}}` — while the `Progress` atom is imported on line 61 and used correctly 400 lines later in the completion step. | `:61`, `:1240`ish, `:1622` | Two progress bars in one file, one an atom and one a hand-roll. The widget has a third copy (`TenantSetupChecklistWidget.tsx:114-119`). |
| **D-5** | **The step rail is unreadable.** Eight bare `h-1.5 flex-1 min-w-8 rounded-full` buttons. The only label is `aria-label`. No names, no icons, no error markers. | `:1258-1270` | The tenant cannot see what is coming, what is left, or which step failed validation — and after a failed submit the wizard silently *jumps* them to the first failing section with no map to explain the jump. |
| **D-6** | **The nav bar is sticky on mobile and NOT on desktop.** `fixed inset-x-0 bottom-0 z-20 … md:static md:border-0 md:bg-transparent md:p-0`. | `:1341` | Backwards. The WhatsApp section has 7 fields, the gateway 6 — on desktop `Next` / `Finish setup` scrolls off the bottom, so the primary action of the screen is the one thing you have to hunt for. |
| **D-7** | **The colour picker is a raw native input.** `<Input type="color" className="h-9 w-14 shrink-0 p-1">` beside a hex text box, while `dgf-widgets/color-hex-picker-widget` and `color-swatch-picker-widget` both exist. | `ColorField`, `:1690`ish | The tenant is picking the accent the entire product will wear, through the OS colour dialog, with no preview and no contrast check. They find out what they chose after they finish. |
| **D-8** | **BRANDING has no live preview.** `required: true`, but the section is four text inputs. Nothing renders the logo, nothing shows the colour applied to a button or a receipt header. | `:630-670` | See D-7. This is the highest-leverage 30 minutes of UX in the whole flow and it is currently a form. |
| **D-9** | **A logo URL is a hard gate on entering the product.** `brandingComplete = !!logoUrl?.trim() && !!primaryColorHex?.trim()`, BRANDING is `required: true`, required steps hide the Skip button and block Next, and `finishBlockedReason` refuses Finish. There is no upload — only a URL paste. | `:435`ish, `:635`, `:1078-1082` | A charity admin whose logo is a file on their laptop is **locked out of the application**. The only exit from `/setup` is Sign out. |
| **D-10** | **No "finish later" exit on first run.** Per-step Skip exists; a whole-flow escape does not. Combined with D-9 the tenant is trapped on a page whose layout was deliberately built with nothing to click out to. | `(setup)/layout.tsx`; `:1341-1400` | "Nothing to navigate to" was the right call for *chrome*. It is the wrong call for *consent*. |
| **D-11** | **Dead store state.** `openSections`, `toggleOpenSection`, `setOpenSections` are declared, reset and exported; the wizard imports none of them. | `tenant-setup-store.ts:29`, `:52-59`; `tenant-setup-istore.ts` | Accordion leftovers from the design the current slide wizard replaced. |
| **D-12** | **A refresh destroys everything, with only the browser's generic warning.** The `beforeunload` guard is present and correct (`:1057-1065`), and `persist` is deliberately absent because the draft carries API keys, gateway secrets and WhatsApp tokens. | `tenant-setup-store.ts:19-24` | The credential decision is right and must stand. But org profile, locale, branding and invites are not secrets, and losing twenty minutes of those to an accidental ⌘R is avoidable. |
| **D-13** | **The arrival anchor is read exactly once.** `anchorReadRef` + `landedRef` are one-shot, and the hash is read from `window.location.hash` rather than a reactive source. | `:213-217`, `:1036-1046` | A second widget click while already on `/setup` changes nothing. Under the §③ redesign this path disappears, but the one-shot refs must not be carried into the new Sheet. |
| **D-14** | **Two different completion numbers for the same thing.** The wizard computes `doneSections / totalSections` from cards *rendered on the client*; the widget renders `setup.completedCount / setup.applicableCount` from the server. | `:1029-1031`; `TenantSetupChecklistWidget.tsx:104-107` | The dashboard says 5/8 and the wizard says 6/7. Both are defensible in isolation; together they read as a bug. |
| **D-15** | **No connection test on any credential.** Email provider, payment gateway, WhatsApp and SMS all take secrets through `SecretInput` with no verification — while both the Email Provider Config and Payment Gateway Config screens have a test action. | `:672-990` | A typo'd key is discovered at the first real receipt or the first real donation. |
| **D-16** | **`bg-muted/40` in `ReadOnlyField`** and **`hover:bg-muted/50`** on every widget row. | `:1673`; `TenantSetupChecklistWidget.tsx:136` | House rule: no `/`-alpha tints, no `bg-muted` as a state surface. |
| **D-17** | **The loading skeleton does not resemble the page.** Five generic `h-20 w-full` bars where the real page is a header, a rail and one tall card. | `:1153-1166` | Layout shift on the tenant's very first paint. |
| **D-18** | **The header cannot show the tenant their own brand.** `bg-primary` tile, company name as text, no logo — even after the tenant has typed a logo URL two sections down. | `tenant-setup-header.tsx` | The moment branding is filled, the chrome should change. That is the payoff that makes the branding step feel worth doing. |

---

## ② Rules this build must not break

1. **The draft never persists credentials.** `emailSender`, `paymentGateway`, `whatsAppSender`, `smsSender` stay memory-only. §⑧'s selective persistence covers the four non-secret sections and nothing else.
2. **One submit per surface.** The full-page wizard still fires exactly one `saveTenantSetup` with `finish: true`. The new Sheet fires exactly one `saveTenantSetup` with `finish: false`. No autosave anywhere.
3. **A null section in the payload means "leave alone", never "clear".** The existing `send(code)` gate is correct — preserve it exactly, including `locale` always travelling.
4. **No GraphQL, DTO, resolver or migration change.** `SAVE_TENANT_SETUP_MUTATION` and `GET_TENANT_SETUP_QUERY` are used as they are. The single-section save is the existing mutation with one non-null slice and `finish: false`.
5. **`(setup)` stays chrome-free** — no `DashBoardLayoutProvider`, no sidebar, no menu. §⑩'s exit is one explicit button, not a shell.
6. **No setup gate, provider or redirect is added to `(core)/layout.tsx`.** The redirect stays decided once, at login.
7. **Server-side validation stays authoritative.** Client predicates only spare a round trip; they never replace `SaveTenantSetup.Validate`.
8. **Applicability keeps failing open.** A section stays visible while `resolved === false` on the `CHANNEL:WHATSAPP` / `CHANNEL:SMS` entitlement check.
9. **`finishedRef` is set synchronously before the refetch.** The already-complete guard races the refetch; do not convert that ref to state.
10. **No new capability codes.** No `canX` gate on anything in this flow.

---

## ③ The mental model — and the direct answer on the modal

> **First run is not a dialog, because there is nothing behind it. Re-entry is not a wizard, because there is nothing left to walk through.**

The proposal was to move the wizard from `/{lang}/setup` into a modal popup. Half of that is right, and
it is the more valuable half — but not the half it looks like.

**First run stays a full page.** Three reasons, all of them already written into this codebase by
whoever built it:

- A modal is a thing you dismiss to get back to something. A first-login tenant has nothing behind the
  overlay — which is precisely why `(setup)/layout.tsx` strips the shell. Putting the same content in a
  `Dialog` over an empty or half-provisioned dashboard advertises an exit that leads nowhere useful.
- The content does not fit. Eight sections, three-column forms, a provider card selector, five credential
  inputs and a repeating invite list. A `Dialog` caps its height and scrolls internally — you get a scroll
  inside a scroll, and D-6's stranded action bar gets worse, not better.
- The single-page slide design is already a **deliberate reversal** of an earlier stepped, deep-linked
  flow. `tenant-setup-wizard.tsx:3-27` and the `tenant-setup-catalog.ts` header both record the reason in
  the same words: *"leaving the page mid-setup is what made the old flow abandonable."* Re-litigating that
  needs evidence this repo does not have.

**Re-entry becomes a Sheet, and that is where the idea pays.** Today a tenant who finished setup weeks ago,
clicks *Email sender* on their dashboard checklist, and gets: a full route change, the shell torn away, an
eight-step wizard, a step rail, and a button that says `Finish setup`. For a one-field edit. That is the
actual UX defect the modal instinct was pointing at.

So: **the checklist widget row opens a right-side `Sheet` over the dashboard containing exactly that one
section and exactly one `Save` button.** No steps, no rail, no Finish, no route change, no lost dashboard.
Same pattern just specified for Grid Management's reference data, and the same reason: a thing that is not
the screen should not pretend to be one.

**One body, two frames.** The eight section bodies move out of the wizard into a registry
(`tenant-setup-sections.tsx`) keyed by task code. The page wizard renders them as slides. The Sheet renders
one. Neither owns the fields, so the two surfaces cannot drift.

---

## ④ Page shell — the full-run wizard

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│  ▓ logo/tile   Acme Charitable Trust                       admin@acme.org  ·  Sign out   │  ← sticky header, brand-aware
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│   🚀  Let's set you up                                     ████████████░░░░░  5 of 8      │
│       A few minutes now and the product starts wearing your name.                        │
│                                                                                          │
│  ┌── xl: rail left, card right ─────────────────────────────────────────────────────┐   │
│  │  ● Organisation      ✓ │  ┌────────────────────────────────────────────────────┐ │   │
│  │  ● Regional          ✓ │  │  ▓  Branding                          [ Required ] │ │   │
│  │  ● Branding          ◉ │  │     Your logo and colours on receipts and pages    │ │   │
│  │  ○ Email sender        │  ├────────────────────────────────────────────────────┤ │   │
│  │  ○ Payments            │  │   Logo            Primary        Live preview      │ │   │
│  │  ○ Team          ⚠     │  │   [ upload/URL ]  [ swatches ]   ┌──────────────┐  │ │   │
│  │  ○ WhatsApp            │  │                                  │ ▓ Acme       │  │ │   │
│  │  ○ SMS                 │  │                                  │ [ Donate ]   │  │ │   │
│  │                        │  │                                  └──────────────┘  │ │   │
│  │  [ Finish later ]      │  └────────────────────────────────────────────────────┘ │   │
│  └────────────────────────┴──────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│  ← Back        Step 3 of 8        [ Skip this step ]              [ Next → ]              │  ← sticky at EVERY breakpoint
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

Container: `mx-auto w-full max-w-[1400px] px-4 pb-28 pt-4 sm:px-6 lg:px-8 xl:pb-24`.
The `max-w-5xl` cap is removed from **all five** places it appears (`:1155`, `:1170`, `:1215`, `:1346`, `:1573`).

Below `xl` the rail stays horizontal above the card, as today but labelled (§⑤). At `xl` and above the
layout splits `xl:grid xl:grid-cols-[minmax(220px,280px)_1fr] xl:gap-8` — the rail becomes a real vertical
step list and the card gets the rest of the width, so three-column form rows finally have room.

---

## ⑤ The step rail — `tenant-setup-step-rail.tsx` (NEW)

Replaces the eight bare bars at `:1258-1270`. One component, two renderings driven by breakpoint, one data
source.

Per step it carries: the catalog icon, the catalog title, and a state — `done` · `current` · `skipped` ·
`error` · `pending`. State resolves in that order; `error` wins over everything when the task code appears
in `sectionErrors`.

- **`xl` and up** — a vertical list. Icon tile 32px, title, a right-aligned state glyph. `current` paints
  from `brandSoft` with a `brandOutline` left edge; `done` gets `bg-emerald-600 text-white` on the tile;
  `error` gets `bg-rose-600 text-white` and the title in `text-destructive`; `skipped` `bg-slate-600`.
- **Below `xl`** — a horizontal scroller, `overflow-x-auto` with `snap-x`, each step a compact chip with
  icon + short title. Not eight unlabelled hairlines that overflow at 375px.

Every step is clickable — this is a rail, not a gate. Clicking jumps `stepIndex`; nothing is validated on
the way. Required-but-unfilled steps still block `Next` and `Finish setup`, which is where the enforcement
belongs.

`aria-current="step"` on the current entry; the container is `role="list"`.

---

## ⑥ Progress and counters

- Delete the hand-rolled bar. Use `<Progress value={percent} size="sm" />` — the same atom the completion
  step already uses on line 1622.
- Same in the widget: replace `TenantSetupChecklistWidget.tsx:114-119` with the atom.
- **Resolve D-14.** Both surfaces show the same fraction. The wizard's `doneSections / totalSections` is the
  correct one — it is the only number that accounts for client-side applicability filtering and in-session
  skips — so the widget adopts the same rule: count rendered task rows and rows in a terminal status, not
  `setup.completedCount / setup.applicableCount`. The server fields stay on the DTO, unused by the widget.
- The fill is `bg-emerald-600` in both places. Progress is a status, not a brand surface — it does not move
  to `--shell-accent`.

---

## ⑦ Section registry — `tenant-setup-sections.tsx` (NEW)

Lift the eight `body` JSX blocks out of the `sectionDefs` `useMemo` (`:445-990`) into an exported registry:

```ts
export interface TenantSetupSectionContext {
  draft: TenantSetupDraft;
  setup: TenantSetupResultDto | null;
  fieldError: (taskCode: string, field: string) => string | undefined;
  patch: { profile; locale; branding; email; emailConfig; gateway; whatsApp; sms; invites };
  emailConfig: Record<string, any>;
  transactionalTypeId: number | null;
  localeLabels: Record<string, string | null>;
}

export const TENANT_SETUP_SECTION_BODIES: Record<
  string,
  (ctx: TenantSetupSectionContext) => React.ReactNode
>;
```

The wizard keeps ownership of `required`, `filled`, applicability, ordering and the completeness predicates
— only the JSX moves. `TextField`, `ReadOnlyField` and `ColorField` move with it and are exported so both
frames use the same presenters.

Field-level fixes applied during the move:

- **`ColorField` → `brand-color-field.tsx`.** Replace the raw `<Input type="color">` with a `Popover`
  containing the existing `color-swatch-picker-widget` palette plus a hex `Input`. The trigger is a 36px
  swatch showing the current value with the hex beside it. Invalid hex shows an inline error and does not
  clear the field. (D-7)
- **`ReadOnlyField`** drops `bg-muted/40` for `border border-dashed bg-background`. (D-16)
- Every grid in a section body gains `xl:grid-cols-4` alongside its existing `md:grid-cols-2 lg:grid-cols-3`
  — except INVITE_TEAM, which keeps its `md:grid-cols-[2fr_2fr_auto]` row shape. (D-2)

---

## ⑧ Branding section — the one that earns the flow

BRANDING is the required step whose output the tenant sees on every screen afterwards, and it is currently
four text boxes. Rebuild it as a two-pane section (`xl:grid-cols-[1fr_360px]`, stacked below):

**Left — inputs.**
- Logo: a `Tabs` pair — *Paste a URL* (today's input) and *Upload* (see below).
- Favicon URL — unchanged.
- Primary colour and Secondary colour via the new `brand-color-field`, with a row of six curated preset
  pairs above the picker so a tenant with no brand guidelines can pick something respectable in one click.

**Right — live preview card.** `sticky top-24` at `xl`. Renders, inline, from the *draft* values:
- the logo (or a lettermark fallback built from the company name) on a header strip painted `brandGradient`;
- a primary `Button` and a chip painted from the draft primary;
- one line of body text over the draft primary, with a **contrast readout** — if the computed contrast of
  `--shell-accent-foreground` against the chosen colour falls below 4.5:1, show an amber inline note:
  *"Text on this colour may be hard to read."* Advice, never a block. (D-8)

**Logo upload (D-9).** This is the lockout, and it has to close. Wire the Upload tab to the existing document
upload path used elsewhere in the app; if no storage container is provisioned for this tenant, the Upload tab
renders disabled with the reason stated in one sentence — **and in that case `brandingComplete` drops the
logo requirement**, keeping only `primaryColorHex`:

```ts
const brandingComplete = !!draft.branding?.primaryColorHex?.trim()
  && (uploadAvailable ? true : true); // logo no longer gates entry
```

Concretely: **`logoUrl` stops being part of `brandingComplete`.** A colour is enough to finish; the logo
stays strongly encouraged with a persistent inline nudge and remains on the dashboard checklist as `PENDING`
until it is set. The server-side finish guard is unchanged — confirm before building that
`SaveTenantSetup.Validate` does not itself require `LogoUrl`; **if it does, stop and report it rather than
weakening the server.** Nobody is locked out of a product because their logo is on their desktop.

---

## ⑨ Re-entry — `tenant-setup-section-sheet.tsx` (NEW)

The payoff of §③.

- `TenantSetupChecklistWidget` row `onClick` no longer routes. It sets local state `openTaskCode` and renders
  `<TenantSetupSectionSheet taskCode={openTaskCode} onOpenChange={…} />`.
- The Sheet is `side="right"`, `className="w-full sm:max-w-xl lg:max-w-2xl xl:max-w-3xl"`, full height,
  scrollable body, footer pinned.
- Header: the catalog icon tile (`brandSolid`), title, description, status chip. No step count, no rail.
- Body: `TENANT_SETUP_SECTION_BODIES[taskCode](ctx)` — the same JSX the page renders.
- Footer: `Cancel` and `Save`. `Save` is enabled only when that section is dirty. It fires **one**
  `saveTenantSetup` with every slice `null` except this one, `skippedTaskCodes: []`, and **`finish: false`**.
  `locale` still travels, hydrated from the server payload, per rule ②.3.
- On success: `toast.success`, `refetch` the setup query, close, and let the widget repaint from fresh data.
  On a `sectionErrors` response: write the errors into the section, keep the Sheet open, do not close.
- The Sheet hydrates its own draft slice from `setup` on open and calls `reset()` on close, so credentials do
  not survive a dismissal. It never reads `stepIndex`, `arrivalAnchor`, `landedRef` or `finishedRef`. (D-13)
- Closing with unsaved edits confirms via `AlertDialog` — a `beforeunload` guard is not enough for an overlay.

`/{lang}/setup#anchor` keeps working for anyone with the URL bookmarked, unchanged. It simply stops being how
the product routes people. The already-complete guard (`:280-286`) stays exactly as it is — a settled tenant
who lands on `/setup` with no anchor still bounces to the dashboard.

---

## ⑩ Navigation, exit and guards

- **Sticky at every breakpoint.** Replace `fixed inset-x-0 bottom-0 z-20 … md:static md:border-0
  md:bg-transparent md:p-0` with `sticky bottom-0 z-20 -mx-4 border-t bg-background/95 px-4 py-3
  backdrop-blur sm:-mx-6 sm:px-6 lg:-mx-8 lg:px-8`. Bottom padding on the container already reserves the
  room. (D-6)
- Left of the bar: the step counter and, when `Next` or `Finish setup` is blocked, the reason in
  `text-destructive` — not a silently disabled button. Wrap the disabled button in a `Tooltip` carrying
  `finishBlockedReason`.
- **`Finish later` (D-10).** A `variant="ghost"` link in the rail footer at `xl`, and in the header below it.
  Opens an `AlertDialog`: *"We'll keep this checklist on your dashboard. Anything you've typed on this page
  will be lost, including any keys or secrets."* Confirm routes to `/{lang}/masterdashboard`. It does **not**
  save, does **not** send `finish`, and does **not** mark anything skipped — the server-side setup state is
  untouched, so the checklist widget simply appears with everything still pending. It is only reachable when
  `finishBlockedReason` is null **or** the tenant has typed nothing; a half-filled required section shows the
  block first.
- The `beforeunload` guard at `:1057-1065` stays as it is.
- **Selective session persistence (D-12).** Add a `sessionStorage`-backed rehydrate for `profile`, `locale`,
  `branding` and `teamInvites` **only**, under key `pss.tenant-setup.draft`, cleared on finish, on
  `Finish later`, and on `reset()`. `emailSender`, `paymentGateway`, `whatsAppSender` and `smsSender` are
  never written — enforce that with an explicit allow-list in the writer, not an exclusion list, and comment
  why. A restored draft shows one dismissible `Alert`: *"We brought back what you'd typed. Provider keys
  weren't saved and need re-entering."*

---

## ⑪ Brand adoption (D-3, D-18)

Import `brandSolid`, `brandGradient`, `brandSoft`, `brandOutline` from `@/presentation/utils/brand-surface`.

| Surface | Today | Becomes |
|---|---|---|
| Header identity tile | `bg-primary text-white` | tenant logo when the draft or server has one, else lettermark on `brandGradient` |
| Page h1 rocket tile | `bg-primary text-white` | `style={brandGradient}` |
| Section icon tile, unfilled | `bg-primary` | `style={brandSolid}` |
| Section icon tile, filled | `bg-emerald-600 text-white` | unchanged — status, not brand |
| Step rail, current | `bg-primary` | `style={brandSoft}` + `brandOutline` |
| Step rail, done / error / skipped | — | `bg-emerald-600` / `bg-rose-600` / `bg-slate-600`, all `text-white` |
| Widget row tile, pending | `bg-primary` | `style={brandSolid}` |
| Widget row hover | `hover:bg-muted/50` | `hover:bg-accent` |
| Progress fill | `bg-emerald-600` | unchanged |
| Status chips | `bg-X-600 text-white` | unchanged |

**D-18's payoff:** the header reads the *draft* branding, not just the server's. The moment a tenant types a
logo URL or picks a colour in section 3, the header above them changes. That is the argument for doing the
branding step, made without a word of copy.

---

## ⑫ Skeletons and empty states

- Rewrite the loading branch (`:1153-1166`) to mirror the real layout: header block, a `Progress`-shaped
  skeleton, a rail skeleton (vertical at `xl`, horizontal below), one tall card skeleton with a
  four-field grid inside. (D-17)
- The error branch keeps its shape; the icon tile moves to `bg-rose-600` (already correct) and the container
  loses `max-w-5xl`.
- The widget's error branch stays quiet — that call was right.

---

## ⑬ Explicitly out of scope

1. No change to `SaveTenantSetup`, its validator, its DTOs or the GraphQL schema.
2. No connection-test buttons (D-15). Worth doing; it needs BE resolvers that this screen does not own. Log it.
3. No change to the login-time redirect decision or `(core)/layout.tsx`.
4. No change to the go-live checklist or `TenantSetupCompletionStep` beyond the `max-w-5xl` removal and the
   `Progress` atom it already uses correctly.
5. No new task codes, no reordering of the catalog, no change to `DisplayOrder` handling.
6. No re-introduction of deep links into owning admin screens.
7. No capability codes, no RBAC change.
8. No plan/entitlement change — applicability filtering behaves exactly as it does today.

---

## ⑭ Files touched

**New (5)**
- `page-components/setting/tenantsetup/tenant-setup-sections.tsx`
- `page-components/setting/tenantsetup/tenant-setup-step-rail.tsx`
- `page-components/setting/tenantsetup/tenant-setup-section-sheet.tsx`
- `page-components/setting/tenantsetup/brand-color-field.tsx`
- `page-components/setting/tenantsetup/branding-preview-card.tsx`

**Modified (6)**
- `page-components/setting/tenantsetup/tenant-setup-wizard.tsx` (loses ~550 lines of section JSX)
- `page-components/setting/tenantsetup/tenant-setup-header.tsx`
- `page-components/setting/tenantsetup/tenant-setup-catalog.ts` (header comment corrected — deep links are gone *and* re-entry is now a Sheet)
- `dashboards/widgets/tenant-setup-widgets/TenantSetupChecklistWidget/TenantSetupChecklistWidget.tsx`
- `application/stores/tenant-setup-stores/tenant-setup-store.ts`
- `application/stores/tenant-setup-stores/tenant-setup-istore.ts`

**Deleted**
- `openSections` / `toggleOpenSection` / `setOpenSections` from the store and its interface (D-11).

---

## ⑮ Acceptance criteria

Each is greppable.

1. `grep -rn "max-w-5xl" tenantsetup/` returns **0**.
2. `grep -c "xl:" tenant-setup-wizard.tsx` is **≥ 8**; the same grep on `tenant-setup-header.tsx` is **≥ 1**.
3. `grep -rn "brand-surface" tenantsetup/` returns **≥ 3 files**; `grep -rn "bg-primary\b" tenantsetup/` returns **0**.
4. `grep -rn "type=\"color\"" tenantsetup/` returns **0**; `brand-color-field.tsx` exists and is imported by `tenant-setup-sections.tsx`.
5. `grep -rn "bg-muted/" tenantsetup/ dashboards/widgets/tenant-setup-widgets/` returns **0**.
6. `grep -n "md:static" tenant-setup-wizard.tsx` returns **0**; `grep -n "sticky bottom-0" tenant-setup-wizard.tsx` returns **≥ 1**.
7. `grep -n 'h-2 flex-1 overflow-hidden rounded-full' tenant-setup-wizard.tsx` returns **0**; `<Progress` appears **≥ 2** times in the file and **≥ 1** time in the widget.
8. `TENANT_SETUP_SECTION_BODIES` is exported from `tenant-setup-sections.tsx` and has exactly **8** keys; `grep -c "taskCode: \"" tenant-setup-wizard.tsx` still returns **8**.
9. `tenant-setup-section-sheet.tsx` contains `finish: false` and does **not** contain `stepIndex`, `arrivalAnchor` or `finishedRef`.
10. `grep -n "router.push" TenantSetupChecklistWidget.tsx` returns **0**.
11. `grep -n "openSections" application/stores/tenant-setup-stores/` returns **0**.
12. `brandingComplete` in `tenant-setup-wizard.tsx` does **not** reference `logoUrl`.
13. The sessionStorage writer names `profile`, `locale`, `branding`, `teamInvites` in an explicit allow-list and the file does **not** contain `emailSender` in its persistence path.
14. `tenant-setup-step-rail.tsx` renders a visible text label per step — `grep -c "aria-label" tenant-setup-step-rail.tsx` is not the only labelling mechanism present.
15. `Finish later` appears in the wizard and opens an `AlertDialog`; it does not call `saveSetup`.
16. `grep -n "beforeunload" tenant-setup-wizard.tsx` still returns **1**.
17. `finishedRef.current = true` still precedes `await refetchSetup()` in `handleFinish`.
18. `branding-preview-card.tsx` reads `draft.branding` and renders a contrast advisory; it never disables a control.
19. The widget's fraction and the wizard's fraction derive from the same rule (rendered-and-terminal task rows).
20. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` exits **0**.

---

## ⑯ Build agent and work order

**Model:** Sonnet. The spec above is field-level; no architectural discovery is required.

1. **Read first, build second.** Confirm `SaveTenantSetup.Validate` does not require `LogoUrl` on finish (§⑧). If it does, **stop and report** — do not weaken the server guard.
2. Confirm the GraphQL field names actually exported by the tenant-setup resolvers before touching either query. `Get` is stripped from every resolver; `tsc` cannot catch a wrong field name.
3. Store: delete `openSections` and friends; add the allow-listed sessionStorage rehydrate (§⑩).
4. Extract `TENANT_SETUP_SECTION_BODIES` + the three presenters into `tenant-setup-sections.tsx`. Pure move — **do not** change field behaviour in this step. Typecheck before continuing.
5. `brand-color-field.tsx`, then swap `ColorField` usages.
6. `branding-preview-card.tsx`, then rebuild the BRANDING section two-pane; drop `logoUrl` from `brandingComplete`; add the logo Upload tab with its disabled fallback.
7. `tenant-setup-step-rail.tsx`; wire it into the wizard, delete the eight bare bars.
8. Wizard layout: remove all five `max-w-5xl`, add the `xl` two-column split, sticky action bar, blocked-reason text + Tooltip, `Finish later`.
9. `Progress` atom in both places; unify the fraction rule.
10. `tenant-setup-section-sheet.tsx`; rewire the widget from `router.push` to the Sheet; brand + token fixes in the widget.
11. Header: brand-aware identity tile reading the draft.
12. Skeleton rewrite.
13. `npx tsc --noEmit --incremental false` to exit 0. Then a manual pass at 375 / 640 / 768 / 1024 / 1280 / 1920, and one end-to-end run: fresh tenant → finish → dashboard → widget row → Sheet → save → widget repaints.

---

## ⑰ Build Log

*Newest first. Append only.*

### 2026-08-11 — Discovery and prompt authored
Read `(setup)/layout.tsx`, `(setup)/setup/page.tsx`, `tenant-setup-catalog.ts`, `tenant-setup-header.tsx`,
`tenant-setup-wizard.tsx` in full (1720 lines), `tenant-setup-store.ts`, and `TenantSetupChecklistWidget.tsx`.

Diagnostics over the folder: `xl:` = **0** in both files; `brand-surface` / `--shell-accent` usage = **0**;
token violations = 1 real (`bg-muted/40` at `:1673`).

Verdict on the page-vs-modal question: **first run stays a page, re-entry becomes a Sheet.** The single-page
design is a recorded, reasoned reversal of an earlier stepped flow (`:3-27`, catalog header) and the
chrome-free layout exists so there is nothing to click out to — a modal reintroduces exactly the exit that
was removed on purpose. The genuine defect the modal instinct was pointing at is re-entry: a settled tenant
editing one field is currently thrown back into the whole eight-step wizard with a `Finish setup` button.

Two non-cosmetic findings beyond that: **D-9**, a tenant without a publicly hosted logo URL cannot enter the
product at all (BRANDING is required, `brandingComplete` needs `logoUrl`, there is no upload, and the only
exit from `/setup` is Sign out); and **D-1**, the re-entry replay above. Everything else is layout, brand
adoption, and one dead store slice.
