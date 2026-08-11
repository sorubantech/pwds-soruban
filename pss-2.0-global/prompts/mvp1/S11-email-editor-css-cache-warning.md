# S11 — Split the email-editor stylesheet (webpack big-string cache warning)

> **DO NOT RUN — the premise below is wrong. Investigated and closed 2026-08-10.**
>
> The split was built and proven lossless, then measured against a baseline: two clean-cache
> `npm run build` runs (`rm -rf .next/cache`), one with `index.css` intact and one with it split into
> nine ≤29 KB stylesheets loaded from a TS barrel. Both emitted **16 × `Serializing big strings
> (106kiB)`** — identical count, identical size. The split changes the warning by exactly zero.
>
> The 106 KiB string is not the editor CSS (which is 187 KB, and would not round to 106). Scanning
> `.next/cache/webpack/**/*.pack` for printable runs ≥100 KiB finds exactly one 108,607-byte
> (106.06 KiB) string, and it is a webpack-internal module-identifier chain:
> `Compilation/modules|javascript/auto|…next-image-loader…person.svg…!|app-pages-browser`. It is the
> serialized module-request list for the app-pages-browser layer, mostly `next-image-loader` SVG
> requests. No source-file reorganisation removes it. (The cache also holds ~265 other ≥100 KiB
> strings — Tailwind's generated CSS at 315/331 KiB, ApexCharts at 515 KiB, powerbi-client at 573 KiB
> — all larger than anything we author.)
>
> The work was reverted; `index.css` is byte-identical to before. Nothing was staged or committed.

**Priority: cosmetic. Run this AFTER the demo.** Nothing here fixes a bug. The build warning it
removes costs a few milliseconds of incremental-rebuild cache deserialization and has zero effect on
bundle size, runtime, or production output. It touches a demo-visible screen, so the risk of doing it
is strictly higher than the cost of leaving it.

**Frontend only.** No backend, no SQL, no migration.

---

## 0. Working rules

- **Never `git commit`.** Stage only (`git add`) and report. No push, amend or tag. Never add a
  `Co-Authored-By` trailer or a "Generated with Claude Code" line.
- Do not edit, stage or revert `src/application/configs/navigation-configs/BaseUrlConfig.ts`.
- `PSS_2.0_Frontend` is a **nested git repo** — `cd` into it to stage.
- **This is a pure file-move refactor. Not one CSS declaration may change.** No reformatting, no
  merging duplicate selectors, no "while I'm here" cleanup, no prettier pass over the rules.

---

## 1. The warning and its actual cause

```
<w> [webpack.cache.PackFileCacheStrategy] Serializing big strings (106kiB) impacts
    deserialization performance (consider using Buffer instead and decode when needed)
```

Emitted twice — once for the client compilation, once for the server one.

Source: [`email-template-editor/styles/index.css`](../../PSS_2.0_Frontend/src/presentation/components/custom-components/editors/email-template-editor/styles/index.css)
— **187 KB, 4,795 lines, 85 `====` section banners**. Webpack's filesystem cache stores each module's
processed content as a JS string; anything past ~100 KiB trips the warning.

**The trap.** The file already looks like it is split — lines 1-5 are:

```css
@import "./partials/code.css";
@import "./partials/placeholder.css";
@import "./partials/lists.css";
@import "./partials/typography.css";
@import "./partials/zoom.css";
```

`css-loader` **resolves and inlines** `@import` into the importing module. Those five partials
(≈14 KB total) are not separate modules — they are concatenated into the same 187 KB string. So
adding more partials via `@import` **will not fix this**. That is the mistake to avoid; if you find
yourself writing a new `@import` line, stop and re-read this paragraph.

Separate webpack modules only happen when JavaScript imports each stylesheet.

---

## 2. What to build

### 2.1 Split `index.css` into top-level stylesheets

Cut it along the existing `/* ==================== NAME ==================== */` banners into
coherent groups, targeting **≤ 40 KB per file** (comfortably under the threshold, with headroom as
the editor grows). Group adjacent related banners — do not create 85 files. Roughly:

`editor-core.css`, `sections-columns.css`, `toolbars.css`, `tables.css`, `images-media.css`,
`placeholders.css`, `email-compat.css` — but name them from what the banners actually say, not from
this list.

Keep `styles/partials/` exactly as it is. Those five files stay byte-identical; only how they are
loaded changes.

### 2.2 A TypeScript barrel, not a CSS one

Create `styles/index.ts`:

```ts
// Each stylesheet is imported here rather than @import-ed from a CSS entry so webpack treats them
// as separate modules. A CSS @import is inlined by css-loader into one module, which is what put a
// 187 KB string in the build cache. ORDER IS LOAD-BEARING — see the note below.
import "./partials/code.css";
import "./partials/placeholder.css";
import "./partials/lists.css";
import "./partials/typography.css";
import "./partials/zoom.css";
import "./editor-core.css";
// …remaining files, in the exact order their rules appeared in the original index.css
```

Delete `styles/index.css`. Repoint both importers from `./styles/index.css` to `./styles`:

- `email-template-editor/EmailTemplateEditor.tsx:14`
- `email-template-editor/minimal-tiptap.tsx:2`

### 2.3 Order is the whole risk

This stylesheet leans hard on **source order and specificity hacks** — doubled class selectors,
`:not()` guards, and a running battle between "manually created tables" and "pasted email tables"
where later rules deliberately override earlier ones so inline styles win. Comments like
*"let inline styles fully control - using doubled class for specificity"* are load-bearing.

Two absolute rules:

1. The five `partials/` imports come **first**, in their original order — they were lines 1-5.
2. Every subsequent file appears in the barrel in the **same order its rules appeared** in the
   original file. Never sort alphabetically. Never group "logically" against original order.

Reordering produces a silently broken email editor: tables lose their formatting, toolbars sit in
the wrong place, pasted email HTML renders wrong. None of it throws an error.

---

## 3. Acceptance

**3.1 Mechanical proof the split is lossless.** Before deleting anything, save a normalized copy of
the original; after the split, concatenate the new files **in barrel order** (with the five partials
inlined at the front, in order) and diff against it. Ignoring only the removed `@import` lines and
trailing whitespace, **the diff must be empty**. If it is not, you moved or changed something —
fix it, do not rationalize it. Do this with a script and paste the actual diff result in the handback.

**3.2** `npx tsc --noEmit` in `PSS_2.0_Frontend` is clean.

**3.3** A build after clearing `.next/cache` emits **no** `Serializing big strings` warning. Note in
the handback whether any other module still trips it — the editor CSS is the only one over 80 KB
today, but a dependency could surface once this one is gone.

**3.4 Visual check, by a human, and say so plainly if you could not run it.** Open the email template
editor and confirm: section and column hover/selected outlines; the section and column toolbars;
insert a table and check borders, header, cell selection and the resize handle; paste real email HTML
and confirm inline styles still win; image left/center/right alignment; the placeholder suggestion
popup; and the mobile `@media (max-width: 600px)` column stacking.

---

## 4. Handback

List the files created, the byte size of each, the §3.1 diff result verbatim, whether the warning is
gone, which parts of §3.4 you verified versus could not, and confirmation that nothing was committed.
If any file still exceeds 40 KB, say which and why.
