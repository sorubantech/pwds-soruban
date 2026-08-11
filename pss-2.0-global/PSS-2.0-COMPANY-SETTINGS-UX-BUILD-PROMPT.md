# PSS 2.0 — Company Settings (#75) Staff-First UX Rebuild

> **Status:** BUILT (Session 2, 2026-08-10) — tsc clean; manual responsive/behaviour pass
> outstanding. (Read §⑬.)
> **Screen:** #75 Company Settings · `(core)/setting/orgsettings/companysettings`
> **Scope:** Frontend only. Zero entity, migration, DTO, GraphQL-schema or ParamCode changes.
> **Build agent:** Sonnet (see §⑫).

---

## ① Why this exists

A staff administrator opens this screen roughly twice a year, under pressure, to change **one**
thing — the FY start month before year-end close, the logo after a rebrand, the invoice prefix
before an audit. Today the screen makes that person hunt.

Seven sections, ~60 fields, one global Save. Everything verified in code:

| # | Defect | Evidence |
|---|---|---|
| 1 | **Responsive stops dead at `md:`.** Zero `lg:`, zero `xl:`, zero `2xl:` in the entire 3053-line folder. There is no content max-width either, so on a 1440px monitor a "Short Name" input is ~900px wide. | grep over `companysettings/**` returns `md:` and `sm:` only |
| 2 | **`SectionHeader` is copy-pasted verbatim into 6 files** — `branding:88`, `contact:149`, `financial:221`, `org-profile:178`, `organization:107`, `regional:304`. Every copy paints its icon chip `bg-primary/10 text-primary`. | six identical function bodies |
| 3 | **The tenant's brand never reaches the screen** for the same root cause the billing prompt fixed: `useShellAccent` overrides `--primary` but not the numbered ramp, and every tint here is a `/10` alpha wash rather than a brand surface. | `useShellAccent/index.ts:148-149` |
| 4 | **House design rules violated throughout** — `bg-primary/10`×6, `bg-muted/30`×2, `bg-muted/50`×1, `bg-destructive/5`×2, `bg-destructive/10`×1, `text-muted-foreground`×30+. The rule is solid `bg-X-600` + `text-white`. | grep |
| 5 | **Required fields are invisible.** 5 of 7 sections render **zero** asterisks (contact=4, org-profile=1, everything else 0) — yet `financialSchema`, `regionalSchema` and `organizationSchema` mark **10 FK fields** `requiredFkId(...)`. Those FKs default to `0`. A staff member cannot see what is unset until Save fails. | `companysettings-schemas.ts:102-154` |
| 6 | **`mode: "onSubmit"` is the wrong pairing at this density.** Sections are mutually exclusive. You can be editing §5 with a broken field in §2 and get no signal until you press Save, at which point you are teleported back to §2. | `settings-page.tsx` `useForm({ mode: "onSubmit" })` |
| 7 | **§9 Number Sequences is missing from the jump-to-first-error `order` array** — an error there is unreachable by the error handler. | `settings-page.tsx` error callback lists 6 keys, not 7 |
| 8 | **No per-section dirty or error signal.** Seven sections behind one global Save bar and no way to see where your unsaved edits or your problems live. | `SIDEBAR_ITEMS` renders label + icon only |
| 9 | **No search**, on a screen the product owner describes as "a lot of settings". The only search in the folder is inside `api-single-select`'s own popover. | grep |
| 10 | **§9 has a second, competing Save button**, so the screen has two save models and the global bar lies about §9's dirty state. | `number-sequences-section.tsx` header comment + own `useForm` |
| 11 | **Branding is edit-blind.** You pick `#0e7490`, press Save, and only then discover what the shell looks like. `useBrandingStore.hydrate()` already exists and drives `useShellAccent` live — the preview is free and nobody built it. | `branding-istore.ts:20`, `useShellAccent/index.ts:148` |

---

## ② The rules this build must not break

Quoted forward from the code. If a change would violate one of these, the change is wrong.

1. **One mutation, three stores, one transaction.** `UPDATE_COMPANY_SETTINGS_MUTATION` persists
   §1–§2 to `app.Companies` typed columns, §3–§6 to `sett.OrganizationSettings` KV rows keyed
   `(CompanyId, ParamCode)`, in a single backend transaction. Do not split it, do not add a second
   composite mutation, do not add per-section mutations.
2. **`formToRequest()` nulls every joined display field.** Every `*Name` / `*Value` / `*Code`
   companion and both `additional*` arrays are explicitly nulled/emptied before send; only FK
   `Id`s and `*Ids` go on the wire. Preserve this exactly.
3. **`sett.OrganizationSettings` rows are shared with #85.** #75 owns identity · appearance ·
   structural config; #85 owns behavioural policy. **Do not add, rename, remove or re-home a single
   ParamCode in this build.** See `PSS-2.0-SETTINGS-SCREEN-RECONCILIATION.md`.
4. **§9 Number Sequences keeps its own mutation.** `UPSERT_NUMBER_SEQUENCE_CONFIGS_MUTATION` stays
   separate — counter state (`LastSequence`, `LastResetPeriodKey`) must not enter the composite
   payload. §⑧ unifies the *button*, not the *mutation*.
5. **The `beforeunload` dirty guard stays**, and must now also fire when §9 alone is dirty.
6. **Save enablement is `isDirty`-driven, never capability-driven.** Per house rule, capability
   gates the entry point, not the Save button.

---

## ③ The staff model this rebuild adopts

> **The sidebar stops being a table of contents and becomes a status board.**

Everything below follows from that one sentence. A person who opens this screen must be able to
answer three questions **without clicking into a single section**:

| Question | Answered by |
|---|---|
| "Where is the thing I came to change?" | §④ search |
| "What have I changed but not saved?" | §⑤ dirty dots |
| "What is broken or blank and will stop me saving?" | §⑤ error + incomplete badges |

---

## ④ Settings search (new)

**New file:** `companysettings/settings-index.ts`

A static, hand-authored index — one entry per user-facing field. It is not generated; it is
curated, so synonyms a staff member actually types ("financial year", "FY", "year end") resolve.

```ts
export interface SettingsIndexEntry {
  section: ActiveSection;      // 1..6, 9
  path: string;                // RHF path, e.g. "financial.financialYearStartMonthId"
  label: string;               // exact on-screen label
  keywords: string[];          // lowercase synonyms — searched, never displayed
}
export const SETTINGS_INDEX: readonly SettingsIndexEntry[] = [ /* every field, all 7 sections */ ];
```

**Rules**
- Every field rendered in §1–§6 gets an entry. §9 gets **one** entry per catalog row is *not*
  required — index §9 once as `{ section: 9, path: "numberSequences", label: "Number Sequences",
  keywords: ["prefix","suffix","invoice number","receipt number","sequence","code format","counter"] }`.
- `path` must match the real RHF path. Add a dev-only assertion is **not** required; instead the
  builder must eyeball each path against the section file it came from.

**Widget:** `components/settings-search.tsx`
- A `Command`/combobox in the sticky bar (§⑥), triggered by click and by `Ctrl/⌘ K`.
- Match on `label` prefix first, then `label` substring, then `keywords` substring. Case-insensitive.
- Results grouped by section, section name shown as the group heading.
- Selecting a result: `setActiveSection(entry.section)` → `requestAnimationFrame` →
  `document.querySelector('[data-field="' + entry.path + '"]')?.scrollIntoView({block:"center"})`
  → apply a 2s highlight ring painted from `brandRing`, removed on timeout.
- **Therefore:** every field wrapper in §1–§6 must carry `data-field="<rhf.path>"`. This is a
  mechanical pass over the six section files.
- Empty query shows nothing (no dropdown). No results shows a single "No setting matches
  '<query>'" row.
- Below `sm`, the search collapses to an icon button that opens the same command palette full-width.

---

## ⑤ The sidebar as a status board

**Modified:** `settings-page.tsx` → extract the nav into `components/settings-nav.tsx`.

Each item renders: icon · label · **status cluster** (right-aligned).

### ⑤.1 The three status marks

| Mark | Meaning | Derivation | Paint |
|---|---|---|---|
| **Error badge** — count pill | This section has *known* validation errors | `countErrors(formState.errors[sectionKey])` — recursive leaf count | `bg-red-600 text-white` |
| **Incomplete dot** — hollow ring | A required field in this section is empty/zero and has not been touched yet | `REQUIRED_PATHS` ∩ empty value (§⑤.3) | `border-amber-600` ring, no fill |
| **Dirty dot** — filled | This section has unsaved edits | `formState.dirtyFields[sectionKey]` non-empty; for §9, its own `formState.isDirty` | `brandSolid` (tenant accent) |

Precedence when more than one applies: **error > incomplete > dirty**. Render at most one mark.

### ⑤.2 Section keys

`SIDEBAR_ITEMS` gains a `formKey` so the nav can index `errors`/`dirtyFields` without a positional
array. Ids stay `1,2,3,4,5,6,9` exactly as today — 7 and 8 remain retired and must not come back.

```ts
{ id: 1, formKey: "orgProfile",   label: "Organization Profile", icon: "ph:building" },
{ id: 2, formKey: "contact",      label: "Contact Information",  icon: "ph:address-book" },
{ id: 3, formKey: "branding",     label: "Branding",             icon: "ph:palette" },
{ id: 4, formKey: "financial",    label: "Financial Configuration", icon: "ph:coins" },
{ id: 5, formKey: "regional",     label: "Regional & Localization", icon: "ph:globe" },
{ id: 6, formKey: "organization", label: "Organization",         icon: "ph:buildings" },
{ id: 9, formKey: null,           label: "Number Sequences",     icon: "ph:hash" },   // own form
```

### ⑤.3 `REQUIRED_PATHS` — one source of truth for the asterisk

**Modified:** `companysettings-schemas.ts` — add, immediately below the composite schema:

```ts
/** Every path the schema will actually reject when empty. The asterisk and the validator
 *  live in one file so they cannot drift. Keep in sync when a schema rule changes. */
export const REQUIRED_PATHS: ReadonlySet<string> = new Set([
  "orgProfile.companyName",
  "contact.addressLine1", "contact.city", "contact.countryId",
  "contact.primaryPhone", "contact.primaryEmail",
  "financial.financialYearStartMonthId", "financial.baseCurrencyId",
  "financial.currencyDisplayFormatId", "financial.numberFormatId",
  "regional.defaultLanguageId", "regional.defaultTimezoneId",
  "regional.dateFormatId", "regional.timeFormatId", "regional.countryOfOperationId",
  "organization.auditLogRetentionYearsId",
]);
```

That is **16 required fields**, of which only **5** are marked on screen today.

**New:** `components/field-label.tsx`

```tsx
<FieldLabel path="financial.baseCurrencyId">Default Currency</FieldLabel>
```
Renders the `Label`, appends `<span className="text-red-600"> *</span>` when
`REQUIRED_PATHS.has(path)`, and sets `data-field={path}` on its wrapper for §④ scroll-to.
Every hand-typed `<span className="text-destructive">*</span>` in the six section files is deleted
and replaced by this component. `ApiSingleSelect` gains a `required?: boolean` prop, passed from the
same set, so FK selects can show the mark too.

**Incomplete derivation:** a value counts as empty when it is `null`, `""`, or — for any path whose
schema rule is `requiredFkId` — `0`. Do not treat `0` as empty for non-FK numeric fields (there are
none today; keep the rule narrow).

---

## ⑥ Validation timing

**Change `mode: "onSubmit"` → `mode: "onTouched"`.**

Rationale, in staff terms: `onTouched` validates a field the moment you leave it and re-validates as
you fix it, but says nothing about fields you have never visited. That is exactly right for a screen
you open to change one thing — you are not scolded about the other 59 fields, and you never carry a
broken field across a section switch without knowing.

Do **not** use `onChange` (yells while you type an email) or `all` (floods the sidebar with errors on
first paint, because 10 FK fields are legitimately `0` until the query resolves).

**Also fix the jump-to-first-error `order` array** — it currently omits section 9 and is positional.
Replace with a `formKey` lookup over `SIDEBAR_ITEMS`:

```tsx
(errors) => {
  const first = SIDEBAR_ITEMS.find((i) => i.formKey && errors[i.formKey]);
  if (first) setActiveSection(first.id);
  toast.error("Please fix the highlighted fields before saving.");
}
```

---

## ⑦ Brand surfaces

`brand-surface.ts` already exists at `src/presentation/components/plan/brand-surface.ts` from the
billing build. It is no longer billing-specific.

**Move it to `src/presentation/utils/brand-surface.ts`** and leave a one-line re-export at the old
path so every billing import keeps compiling:

```ts
// src/presentation/components/plan/brand-surface.ts
export * from "@/presentation/utils/brand-surface";
```

### ⑦.1 Replacement table — every violation, its fix

| File | Current | Replace with |
|---|---|---|
| 6× section files, `SectionHeader` icon chip | `bg-primary/10 text-primary` | shared `<SectionHeader>` (§⑦.2) with `style={brandSolid}` |
| `org-profile-section.tsx` ID/Code chip | `bg-muted/30 text-muted-foreground` | `border border-border bg-card`, labels `text-foreground`, values in `<code>` on `bg-background` |
| `number-sequences-section.tsx` inherit-hint cell | `bg-muted/30` | `bg-card` + `text-foreground/70` placeholder text |
| `organization-section.tsx` panel | `bg-muted/50` | `border border-border bg-card` |
| `settings-page.tsx` error panel | `bg-destructive/5` | `bg-red-600 text-white` icon chip on a `border-red-600 bg-card` panel |
| `number-sequences-section.tsx` error panel | `bg-destructive/5` | same as above |
| `save-changes-bar.tsx` Admin badge | `bg-destructive/10 text-destructive` | `bg-red-600 text-white` |
| all `text-primary` (10 sites) | `text-primary` | `style={brandText}` |
| all `text-muted-foreground` (30+) | `text-muted-foreground` | `text-foreground/70` for helper copy; `text-foreground` for anything a person must read to make a decision (unit suffixes, inherit hints, read-only values) |
| Discard `AlertDialogAction` | `bg-destructive text-destructive-foreground hover:bg-destructive/90` | `bg-red-600 text-white hover:bg-red-700` |
| active sidebar item | `border-primary/30 bg-primary/10 text-primary` | `style={brandSolid}` on the active item, plain `text-foreground hover:bg-card` on the rest |

**Brand vs status:** the accent (`brandSolid`/`brandText`/`brandSoft`) paints *brand intent* — the
active nav item, section header chips, the dirty dot, the search highlight ring, the primary Save
button. **Status keeps its solid semantic token** — errors `bg-red-600`, incomplete `border-amber-600`,
save-succeeded `bg-emerald-600`. Never mix: an error badge must not go tenant-purple.

### ⑦.2 Shared `SectionHeader`

**New:** `components/section-header.tsx` — one implementation, six deletions.

```tsx
export function SectionHeader({ icon, title, subtitle, action }: {
  icon: string; title: string; subtitle: string; action?: React.ReactNode;
}) {
  return (
    <div className="flex items-start gap-3 border-b border-border pb-4">
      <span style={brandSolid} className="flex h-9 w-9 shrink-0 items-center justify-center rounded-md">
        <Icon icon={icon} className="h-5 w-5" />
      </span>
      <div className="min-w-0 flex-1">
        <h2 className="text-base font-semibold text-foreground lg:text-lg">{title}</h2>
        <p className="text-xs text-foreground/70 lg:text-sm">{subtitle}</p>
      </div>
      {action ? <div className="shrink-0">{action}</div> : null}
    </div>
  );
}
```

Delete the local `SectionHeader` from all six section files and import this one. The `action` slot is
used by §3 Branding for its preview toggle (§⑨).

---

## ⑧ One Save bar, one mental model

Today §9 has its own Save button and sits outside the global bar. Two save models on one screen is
the single most confusing thing here for someone who edits §4 and §9 in the same sitting.

**Unify the button, not the mutation.**

`companysettings-store.ts` gains a registration slot:

```ts
// A section that owns its own mutation registers here so the one global Save bar can drive it.
extraSaver: { isDirty: boolean; save: () => Promise<boolean> } | null;
registerExtraSaver: (s: { isDirty: boolean; save: () => Promise<boolean> } | null) => void;
```

- `NumberSequencesSection` calls `registerExtraSaver({ isDirty, save })` in an effect keyed on its
  own `isDirty`, and `registerExtraSaver(null)` on unmount. Its own Save button is **removed**.
- The global bar's `isDirty` becomes `compositeDirty || (extraSaver?.isDirty ?? false)`.
- Global **Save** runs the composite mutation first; on success, if `extraSaver.isDirty`, runs
  `extraSaver.save()`.
- **Partial-failure contract, stated explicitly:** these are two mutations and there is no
  cross-store transaction. If the composite succeeds and §9 fails, show
  `toast.error("Settings saved. Number sequences could not be saved — <message>")`, leave §9 dirty
  and its form untouched, and switch `activeSection` to 9. If the composite fails, do **not** attempt
  §9 at all. Never report a partial save as a success.
- Global **Discard** resets the composite form from `lastSavedSnapshot` and calls the extra saver's
  reset — add `reset: () => void` to the registration object alongside `save`.
- `beforeunload` guards on the combined dirty flag.

---

## ⑨ Branding live preview (§3)

The one place on this screen where a staff member is guessing. `useBrandingStore.hydrate()` already
feeds `useShellAccent`, which repaints `--shell-accent*`, `--primary` and `--ring` across the whole
shell. So a real preview is a store write, not a rendering exercise.

**Behaviour**
1. On mount, `BrandingSection` snapshots `{ primaryColorHex, secondaryColorHex, logoUrl, faviconUrl }`
   from `useBrandingStore.getState()` into a ref.
2. A **Live preview** toggle (`Switch`) sits in the shared header's `action` slot, **default on**.
3. While on, colour and logo changes are pushed to `useBrandingStore.hydrate({...})` **debounced 150ms**.
   The real shell — sidebar, topbar, buttons — recolours as you drag the picker. Label the toggle
   with helper text: *"Preview applies to this browser only until you save."*
4. On unmount, on Discard, and when the toggle is switched off, `hydrate(snapshotRef.current)` restores.
5. On successful Save, the snapshot ref is **replaced** with the saved values (the preview is now
   the truth).
6. Do **not** touch `applyFavicon` from the preview path — favicon churn while typing a URL is
   noise. Favicon updates on save only.

**Plus a static preview card** below the pickers, so a person on a phone (where the shell chrome is
hidden) still sees the result: a small rounded card containing a fake topbar strip painted
`brandGradient`, a fake sidebar column painted `brandSoft`, an active-nav pill painted `brandSolid`,
and a primary Button. ~60 lines, no new dependency.

**Contrast guard:** when the chosen primary's computed luminance puts white text below WCAG AA
(4.5:1), show an inline warning chip `bg-amber-600 text-white` reading *"Low contrast — white text on
this colour may be hard to read."* Warning only; never block save. Put the luminance helper in
`utils/brand-surface.ts` next to the surfaces.

---

## ⑩ Responsive spec — xs → xl

The folder currently has **no** `lg:` or `xl:` anywhere and no content max-width. Every element below
is specified per breakpoint. Tailwind defaults: `sm` 640 · `md` 768 · `lg` 1024 · `xl` 1280 · `2xl` 1536.

### ⑩.1 Page shell

| Element | xs (<640) | sm | md | lg | xl |
|---|---|---|---|---|---|
| Outer layout | `flex-col`, `p-3` | `p-4` | `flex-row gap-6 p-4` | `gap-8 p-6` | `p-6` |
| Content column | full width | full width | `flex-1 min-w-0` | `flex-1 min-w-0` | `flex-1 min-w-0` |
| **Content max-width** | none | none | none | `max-w-[880px]` | `max-w-[1040px]` |
| Content centering | — | — | — | `mx-auto` | `mx-auto` |
| Section card padding | `p-4` | `p-5` | `p-6` | `p-6` | `p-8` |

The `max-w` + `mx-auto` pair is the fix for defect #1: on a 1440px monitor a text input stops at a
readable measure instead of running the full width of the screen.

### ⑩.2 Navigation

| Element | xs | sm | md | lg | xl |
|---|---|---|---|---|---|
| Form | horizontal chip rail, `overflow-x-auto`, `-mx-3 px-3` | same | vertical sidebar | vertical | vertical |
| Width | 100% | 100% | `w-56` | `w-64` | `w-72` |
| Sticky | no | no | `sticky top-[80px] h-[calc(100vh-110px)]` | same | same |
| Item content | icon + label + status mark | same | same | same | same |
| Label truncation | `truncate` | `truncate` | `truncate` | full | full |
| Section-count summary line under the nav | hidden | hidden | shown | shown | shown |

The chip rail below `md` must keep the status marks — that is where they matter most, because the
rail is the only place you can see all seven sections at once on a phone.

### ⑩.3 Section field grids

Base grid becomes `grid-cols-1 gap-4 sm:grid-cols-6 md:grid-cols-12 lg:gap-5`.

| Section | xs | sm (6-col) | md/lg/xl (12-col) |
|---|---|---|---|
| §1 Org Profile | 1 per row | Name 6 · Short 3 · Type 3 · Reg 3 · Tax 3 · FCRA 3 · Date 3 · Website 6 · Desc 6 | Name 8 · Short 4 · Type 4 · Reg 4 · Tax 4 · FCRA 4 · Date 4 · Website 4 · Desc 12 |
| §2 Contact | 1 per row | Addr1 6 · Addr2 6 · City 3 · State 3 · Country 3 · Postal 3 · Phone 3 · Email 3 · Fax 3 | Addr1 8 · Addr2 8 · City 4 · State 4 · Country 4 · Postal 4 · Phone 4 · Email 4 · Fax 4 |
| §3 Branding | stacked | uploads 6+6, colours 3+3 | uploads 6+6, colours 4+4, preview card 12 (`lg:col-span-8`) |
| §4 Financial | 1 per row | 3+3 pairs | 3 per row (`col-span-4`) |
| §5 Regional | 1 per row | 3+3 pairs | 3 per row; the two multi-selects `col-span-12` |
| §6 Organization | 1 per row | 6 · 6 | Audit 4 · Multi-branch switch 8 |
| §9 Number Sequences | card list (§⑩.4) | card list | table |

### ⑩.4 §9 Number Sequences below `md`

A 7-column table does not work on a phone. Below `md`, render one card per catalog row:

```
┌────────────────────────────────────────┐
│ ● Invoice                    [Enabled] │   ← entity name + Switch
│ Prefix  [INV      ]  Suffix [        ] │
│ Pattern [{PREFIX}{SEQ:0000}          ] │
│ Reset   [Never reset            ▾]     │
│ Next number: INV0042 · last used 41    │   ← preview line, always shown
└────────────────────────────────────────┘
```

The **"Next number"** preview line is required at every breakpoint, table and card alike. It is the
single most useful thing on §9 and it does not exist today: render the pattern with `{PREFIX}` /
`{SUFFIX}` / `{SEQ:n}` / `{YYYY}` substituted, `lastSequence + 1` in the counter, zero-padded to at
least the token's zero count. Empty override fields fall back to the catalog default and the preview
must reflect that fallback — that is how a person confirms "inherit" actually means what they think.

Live client-side pattern validation, matching the save-boundary rule: predefined tokens only,
`{SEQ}` mandatory, prefix non-blank. Invalid → red border + inline message + the row counts toward
§9's error badge.

### ⑩.5 Universal rules

- No horizontal page scroll at 320px. Tables scroll inside their own `overflow-x-auto` container.
- Every interactive target ≥ 40px high below `md`.
- The sticky bar collapses to two rows below `sm`: title row, then actions row `w-full` with
  `flex-1` buttons.
- `tabular-nums` on every number in §9 (counters, previews).
- Manual verification at **375 · 640 · 768 · 1024 · 1280 · 1440 px**.

---

## ⑪ Loading, error and empty states

- Replace the single `SectionSkeleton` with **per-section shaped skeletons** that mirror that
  section's real grid — §1 renders an 8/4 pair then three 4s; §9 renders 5 table rows at `md`+ and
  5 cards below. A skeleton whose shape does not match what arrives reads as a layout jump.
- The nav renders immediately with all seven items and **no** status marks while loading — never a
  skeleton, because it is static content the query does not gate.
- Query error: `border-red-600 bg-card` panel, `bg-red-600 text-white` icon chip, the server message
  verbatim, and a **Retry** button that refetches. Today the message is swallowed into a tint panel.
- §9 with zero catalog rows: an empty state reading *"No number sequences are configured for your
  organization yet. Contact support to enable them."* — not a bare empty table.

---

## ⑫ Explicitly out of scope

Do not do any of these, even if they look adjacent:

1. **Any entity, EF migration, DTO, or GraphQL schema change.** Frontend only.
2. **Any ParamCode add/rename/remove/re-home.** The #75 ↔ #85 partition is settled; the
   reconciliation doc's §5B `DELETE` and its three prerequisite checks are the user's, not this build's.
3. **Reviving section 7 or 8.** `ActiveSection` keeps `7 | 8` in the union so a persisted value
   renders nothing instead of crashing. Do not add sidebar items for them.
4. **Splitting the composite mutation** or adding per-section save buttons beyond the §9 registration.
5. **The `sett.NumberSequenceEntityTypes` catalog** — read-only here. No add/delete of entity types.
6. **`#85` Organization Settings, `#9` Receipt & Tax, or the billing pages.** Untouched.
7. **A new colour system.** `brand-surface.ts` moves; it does not grow new exports beyond the
   luminance helper in §⑨.
8. **Autosave.** Explicit Save stays. A settings screen that saves as you type is a settings screen
   that half-rebrands your tenant while you are still choosing.

---

## ⑬ Files touched

**New (6)**
```
companysettings/settings-index.ts
companysettings/components/settings-search.tsx
companysettings/components/settings-nav.tsx
companysettings/components/section-header.tsx
companysettings/components/field-label.tsx
companysettings/components/branding-preview-card.tsx
```

**Moved (1)**
```
presentation/components/plan/brand-surface.ts → presentation/utils/brand-surface.ts
  (old path becomes a one-line re-export; adds a luminance helper for §⑨)
```

**Modified (12)**
```
companysettings/settings-page.tsx                  ← mode, error-jump, layout, nav extraction, save orchestration
companysettings/companysettings-schemas.ts         ← + REQUIRED_PATHS
companysettings/companysettings-store.ts           ← + extraSaver registration
companysettings/components/save-changes-bar.tsx    ← combined dirty, search slot, red-600 badge, sm: rows
companysettings/components/api-single-select.tsx   ← + required prop, data-field
companysettings/sections/org-profile-section.tsx   ← shared header, FieldLabel, data-field, grid, tokens
companysettings/sections/contact-section.tsx       ← same
companysettings/sections/branding-section.tsx      ← same + live preview + preview card
companysettings/sections/financial-section.tsx     ← same
companysettings/sections/regional-section.tsx      ← same
companysettings/sections/organization-section.tsx  ← same
companysettings/sections/number-sequences-section.tsx ← card layout, next-number preview, pattern validation, save registration
```

**Untouched by decision:** every `*Dto.ts`, every `*Query.ts` / `*Mutation.ts`, `color-picker-input.tsx`,
`file-upload-card.tsx`, `tag-input.tsx` (unless a token replacement from §⑦.1 lands in them — token
replacement only, no structural change).

---

## ⑭ Acceptance criteria

Each is greppable or directly observable. All must pass.

1. `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false` exits **0**.
2. `grep -rn "bg-primary/10\|bg-muted/30\|bg-muted/50\|bg-destructive/5\|bg-destructive/10" <companysettings folder>` → **0 matches**.
3. `grep -rn "text-muted-foreground" <companysettings folder>` → **0 matches**.
4. `grep -rn "function SectionHeader" <companysettings folder>` → **1 match**, in `components/section-header.tsx`.
5. `grep -rn "lg:" <companysettings folder>` → **≥ 20 matches**; `grep -rn "xl:"` → **≥ 8 matches**.
6. `grep -rn "mode: \"onSubmit\"" settings-page.tsx` → **0 matches**; `"onTouched"` → **1**.
7. `grep -c "data-field=" <all six section files>` → every field in `SETTINGS_INDEX` has a matching
   `data-field`, verified by eye per section.
8. `REQUIRED_PATHS.size === 16`, and every one of the 16 renders a visible asterisk on screen.
9. §9 has **no** Save button of its own; `grep -rn "registerExtraSaver" ` → exactly 2 call sites
   (register + unregister) plus the store definition.
10. Changing the primary colour in §3 recolours the live sidebar within ~150ms; navigating away
    without saving restores the previous colour.
11. `Ctrl/⌘ K` → type "financial year" → selecting the result lands on §4 with the FY field
    scrolled into view and ringed.
12. Editing a field in §4, switching to §5, and pressing Save with a §2 field cleared lands the user
    on §2 with the error visible — and the §2 nav item showed a red badge before Save was pressed.
13. No `*Dto.ts`, `*Query.ts` or `*Mutation.ts` file is modified.
14. No horizontal page scroll at 375px; manual pass at 375 · 640 · 768 · 1024 · 1280 · 1440.
15. `npx next build` is **not** required; typecheck + manual pass is the bar.

---

## ⑮ Build agent

**Sonnet.** §①–⑭ specify the layout, the tokens, the state model and the acceptance bar concretely;
there is no architectural judgement left to make and no historic-failure pattern here.

**Work order** — each step compiles before the next begins:

1. Move `brand-surface.ts`, add the re-export shim and the luminance helper. Typecheck.
2. `section-header.tsx` + `field-label.tsx` + `REQUIRED_PATHS`. Delete the six duplicate headers.
   Typecheck.
3. Token replacement sweep (§⑦.1) across all 12 modified files. Typecheck.
4. `settings-nav.tsx` with status marks; `mode: "onTouched"`; the `formKey`-based error jump.
   Typecheck.
5. Responsive pass §⑩.1–⑩.3 plus `data-field` attributes on every field wrapper. Typecheck.
6. `settings-index.ts` + `settings-search.tsx`, wired into the sticky bar. Typecheck.
7. §⑧ save unification: store slot, §9 registration, partial-failure toasts, combined
   `beforeunload`. Typecheck.
8. §9 card layout, next-number preview, pattern validation (§⑩.4). Typecheck.
9. §⑨ branding live preview + preview card + contrast guard. Typecheck.
10. §⑪ skeletons, error panel with Retry, §9 empty state. Final
    `npx tsc --noEmit --incremental false`, then the manual breakpoint pass.

---

## ⑬ Build log

_(append-only, newest first, last 5 sessions retained — git holds the rest)_

### Session 2 — 2026-08-10 — BUILT
All ten steps of the §⑮ work order executed; `npx tsc --noEmit --incremental false` exits 0.

- **1–2 Shared primitives.** `brand-surface.ts` moved to `presentation/utils/` (the old
  `components/plan/` path is now a one-line re-export so billing imports still compile) and gained
  `meetsWhiteTextContrastAA`. Six duplicate local `SectionHeader`s collapsed into
  `components/section-header.tsx` (`function SectionHeader` = 1 match folder-wide).
- **3 Required fields.** `REQUIRED_PATHS` added to `companysettings-schemas.ts` with exactly the 16
  spec paths; `components/field-label.tsx` renders the asterisk from that set and stamps
  `data-field={path}` (13 sites) for the search palette to scroll to.
- **4 Validation timing.** `mode: "onTouched"`; the invalid-submit handler jumps to the first
  section whose `formKey` has an error via `SIDEBAR_ITEMS`.
- **5 Status board.** Nav extracted to `components/settings-nav.tsx`, exporting `SIDEBAR_ITEMS`
  (ids 1,2,3,4,5,6,9 — 7 and 8 stay retired). One mark per item, precedence error > incomplete >
  dirty, plus a section-count summary at md+.
- **6 Search.** `settings-index.ts` (37 curated entries) + `components/settings-search.tsx`
  command palette on Ctrl/⌘K, matching label-prefix → label-substring → keyword-substring, grouped
  by section, scrolling to `[data-field]` with a 2s brand-ring highlight.
- **7 Tokens.** Forbidden-token grep over the folder is clean for `bg-primary/10` (one comment
  only), `bg-muted/30`, `bg-muted/50`, `bg-destructive/5`, `bg-destructive/10` and
  `text-muted-foreground` (0). Two `hover:bg-muted` hover affordances remain in
  `api-single-select.tsx` / `tag-input.tsx` — hover states, not surfaces or status colours.
- **8 One Save bar.** §9 registers `{ isDirty, save, reset, errorCount }` on the store; the two
  mutations stay separate. The registration returns `{ ok, message? }` so a partial save reports
  the server's own message — `"Settings saved. Number sequences could not be saved — {message}"` —
  and switches the sidebar to §9 instead of sending the user to "check the other tab". §9 no
  longer toasts that failure itself.
- **9 Branding preview.** `components/branding-preview-card.tsx` + a default-on "Live preview"
  switch driving `useBrandingStore.hydrate()` on a 150 ms debounce. `faviconUrl` is excluded and
  `applyFavicon` is never called from the preview path. The mount snapshot is restored on
  toggle-off and unmount, and replaced on every dirty→clean edge, so both Save and Discard land
  correctly without `settings-page.tsx` needing to know about it.
- **10 States.** Per-section shaped skeletons carrying each section's real lg column spans (§9
  gets 5 table rows at md+ / 5 cards below); the nav renders immediately during load with status
  marks suppressed; both error panels rebuilt as `border-red-600 bg-card` with a
  `bg-red-600 text-white` icon chip, the server message verbatim, and Retry.

Not verified — needs a browser: §⑭.10/11/12 (observable palette, preview and partial-save
behaviour) and §⑭.14, the manual pass at 375 · 640 · 768 · 1024 · 1280 · 1440 px. The folder now
carries 26 `lg:` and 13 `xl:` utilities where it previously had zero of either.

### Session 1 — 2026-08-10 — PLANNED
Prompt authored. Discovery covered `settings-page.tsx` (452), `org-profile-section.tsx` (190),
`branding-section.tsx` (112), `save-changes-bar.tsx` (103), `companysettings-schemas.ts` (166),
`companysettings-store.ts` (50), `number-sequences-section.tsx` head (120),
`branding-istore.ts`, `useBranding.ts`, `brand-surface.ts`, and
`PSS-2.0-SETTINGS-SCREEN-RECONCILIATION.md` (139), plus responsive/token/duplication greps over the
full 3053-line folder. No mockup exists for this screen — layout decisions in §⑩ are original.
Eleven defects recorded in §①; the load-bearing behaviour in §② was extracted from the code and must
survive. Nothing written to `PSS_2.0_Frontend` yet.
