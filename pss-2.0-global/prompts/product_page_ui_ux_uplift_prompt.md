# Product Landing Page — UI/UX + Motion Uplift

## Who you are

You are the UI and UX expert and you have 20+ years of experience, and you have 20+ years of
experience in UI micro-interactions, motion and animation creation — done the proper way. You have
shipped marketing surfaces for enterprise B2B SaaS that had to survive a procurement review, a
Lighthouse audit and an accessibility audit on the same day. You know that on a page like this,
motion is not decoration: it is hierarchy, feedback and pacing. You also know the failure mode of
inexperienced motion work — everything moves, nothing means anything, and the page feels cheap. Your
job is the opposite: fewer, better, intentional movements that make the page feel expensive and calm.

## Context

Prospects saw a live product demo, it went well, and they asked for our product page. The **content**
was just rewritten and is now substantive and truthful — do not rewrite it. What is now behind the
content is the **visual craft**: the page currently reads as a competent Tailwind layout, not as the
front door of an enterprise nonprofit platform. Fix that.

Target: DEV/UAT, real prospects will open this link. This is enterprise software, not a landing-page
template — no shortcuts, no "good enough for now".

## Where the work is

Frontend repo: `PSS_2.0_Frontend` (nested git repo — `cd` into it).

Page root: `src/presentation/pages/marketing/`

```
index.tsx                              composed page, section order
data/product-landing-content.ts        ALL copy — read it, do not rewrite it
components/marketing-backdrop.tsx      GridBackdrop, DotBackdrop, GlowOrbs, BeamRule,
                                       CircuitBackdrop, BrandIconTile, GradientBorderCard
components/hero-visual.tsx             the product panel beside the hero copy
components/marketing-icon.tsx          the ONLY icon path (client leaf, @iconify/react)
components/enquiry-form.tsx            the ONLY interactive client component
sections/*.tsx                         hero, problem-outcome, module-pillars, capability-depth,
                                       how-it-works, plans, security, faq, enquiry, header, footer
services/product-landing-ssr.ts        data fetch (plans, countries)
```

Design tokens and every keyframe live in `src/presentation/tailwind.config.ts`:
- brand colours `ps-indigo`, `ps-violet`, `ps-fuchsia`, `ps-rose`, `ps-pink`
- existing keyframes/animations: `ps-beam`, `ps-beam-slow`, `ps-dash`, `ps-float`, `ps-glow`,
  `ps-meter`, `ps-orbit`

Published route: `/{lang}/peopleserve`.

## Hard constraints — violating any of these is a failed deliverable

1. **The page stays a Server Component.** Every heading, paragraph, plan, security point and FAQ
   answer must be in the first HTML response. Crawlers and the LCP depend on it. No
   `dynamic = "force-dynamic"`.
2. **No new client JS.** The only `"use client"` files on this page are `enquiry-form.tsx` and
   `marketing-icon.tsx`, and it stays that way. That means **no Framer Motion, no GSAP, no
   IntersectionObserver scroll-reveal, no `useEffect` fade-ins, no scroll-jacking, no parallax
   library, no cursor followers, no `react-spring`**. All motion is CSS: `@keyframes` in the Tailwind
   config plus `transition-*`, `group-hover:`, `focus-visible:`, `has-[]:`, `peer-*` and
   `animation-delay` utilities. If you believe an effect genuinely cannot be done without client JS,
   do not add the JS — either find the CSS equivalent or drop the effect and say why in your report.
3. **Compositor-only animation.** `transform`, `opacity`, `filter` and SVG `stroke-dashoffset` only.
   Never animate `width`, `height`, `top`, `left`, `margin` or `box-shadow` on a looping animation.
   Nothing may cause layout shift — CLS must stay at zero.
4. **`prefers-reduced-motion` is honoured everywhere.** Every looping animation carries
   `motion-reduce:animate-none` (or `motion-reduce:hidden` where the element is *only* motion). A
   reduced-motion visitor gets the same page and the same information, just still. Entrance
   transitions must also degrade to "already in final state", never to "invisible".
5. **RTL.** The Arabic locale mirrors. Use logical properties — `ms-/me-`, `ps-/pe-`, `start-/end-`,
   `text-start` — and `rtl:` variants for any directional motion or arrow (`rtl:rotate-180`). A beam
   that travels left-to-right in English must not read backwards in Arabic.
6. **Do not change copy** in `data/product-landing-content.ts`. If a layout change genuinely requires
   a copy change, propose it separately, do not just do it.
7. **Do not change the section order or remove a section.** `index.tsx` documents why the order is
   what it is. Do not add a customer-logo trust strip — we have no logos cleared to publish.
8. **Grid/content coupling.** `how-it-works-section.tsx` draws connectors between exactly 3 cards.
   `module-pillars` is `lg:grid-cols-4` with 12 items, `capability-depth` is `md:grid-cols-2` with 4,
   `problem-outcome` is `md:grid-cols-3` with 6, `security` is `lg:grid-cols-3` with 9. If you change
   a grid, check the item count still divides cleanly.
9. **FAQ stays native `<details>/<summary>`** — every answer in the DOM. The FAQPage JSON-LD is built
   from the same array, so it must not drift. Style it beautifully; do not replace it with an
   Accordion component.
10. **Dark mode and light mode both.** Every colour you introduce must be a token or have a dark
    variant. Check both.
11. **Do not touch** `BaseUrlConfig.ts`, backend code, menus, capabilities or seed SQL.
12. **Never commit.** Stage only (`git add`), then report. No `Co-Authored-By` trailer anywhere.

## What to actually improve

Work in this order of impact.

### 1. Typographic and spatial system

This is where "professional" is won, before any animation.
- Establish a real type scale and stick to it — display, h2, h3, lede, body, caption. Right now
  section headings and body sizes are near-identical across sections, which flattens hierarchy.
- Tighten tracking on large headings, loosen line-height on body. Set a measure (`max-w-[65ch]`-ish)
  on every long paragraph — long lines are the single most common "amateur" tell.
- Establish a vertical rhythm: consistent section padding, consistent eyebrow → h2 → lede spacing,
  consistent card padding. Audit every section against it and fix the outliers.
- Give sections deliberate background alternation and a considered transition between them (the
  current `bg-background` / `bg-muted/30` alternation is blunt). Consider soft gradient seams or a
  hairline with a brand glow rather than a hard border everywhere.

### 2. Surface and depth craft

- `GradientBorderCard` is used on many sections and looks the same everywhere. Give it deliberate
  states: rest, hover, and focus-within. Elevation should come from layered soft shadows plus a
  subtle border-luminance shift, not from a heavy drop shadow.
- Cards should feel like glass over a lit background in dark mode, and like paper with a coloured
  edge in light mode.
- Icon tiles (`BrandIconTile`): solid brand-gradient background with a white glyph reads as premium;
  a pale tint with a coloured glyph reads as a bootstrap template. Make them consistent and confident.
- The plans section is the commercial moment of the page — it deserves the most design attention:
  a clear recommended tier, a real price hierarchy, aligned feature rows, and graceful handling of
  the empty state (plans can arrive as `[]`; that path must still look designed, not broken).

### 3. Motion — the part you are hired for

Principles to apply, not effects to sprinkle:
- **Ambient motion must be slow enough to be subliminal.** The existing backdrop animations are
  already tuned slow on purpose (13s–23s beams, 20s dashes, 9s glow). Anything that reads as a
  loading bar or pulls the eye off the copy is wrong. Audit the current backdrops and *reduce* what
  competes; add ambient motion only where the section currently feels dead.
- **Micro-interactions carry the quality signal.** Every interactive element — the two hero CTAs, the
  header CTA, nav anchors, plan cards, FAQ summaries, every form field and the submit button — needs
  a considered rest → hover → active → focus-visible → (where relevant) disabled/loading treatment.
  Durations 120–220ms, easing that decelerates (`cubic-bezier(0.16, 1, 0.3, 1)` is already in use for
  `ps-meter`). No linear easing on interaction, ever.
- **Focus-visible must be gorgeous, not an afterthought.** Keyboard users see it constantly; it is
  part of the design, and it must be visible on both themes.
- **Entrances without JS.** You may use a CSS-only staggered entrance (keyframe + per-item
  `[animation-delay:*]`) for above-the-fold groups where content is guaranteed present — but it must
  start from a state that is *already readable* if animation is unsupported, and it must never delay
  the LCP element. Do not attempt scroll-triggered reveals; without JS they either never fire or
  hide content from crawlers. If a section needs life on scroll, use `animation-timeline: view()`
  **only** behind an `@supports` guard with the un-animated state as the default.
- **The hero visual** (`hero-visual.tsx`) is the page's showpiece. It should look like the product,
  move like the product, and loop without ever demanding attention. Sell the platform in it.
- **The enquiry form** is the one conversion on the page. Validation, pending and success states need
  real motion design — a submit button that changes state credibly, an error that draws the eye
  without shouting, a success that feels like completion.
- **Kill anything that moves without a reason.** If you cannot say in one sentence what a movement
  communicates, delete it. Part of this deliverable is *removing* motion, not only adding it.

### 4. Accessibility and quality floor — non-negotiable

- Contrast ≥ 4.5:1 for body text and ≥ 3:1 for large text and UI borders, on both themes, including
  text that sits over gradients and glows.
- One `<h1>` on the page (the hero), heading levels never skip.
- Everything reachable and operable by keyboard, in a sensible order; the skip link keeps working.
- Decorative layers stay `aria-hidden` + `pointer-events-none`.
- Responsive from 320px up. No horizontal scroll at any width. No side-by-side button pairs on
  mobile. Touch targets ≥ 44px.
- Test both `lang=en` and an RTL locale.

## Method

1. **Read before you edit.** Read `index.tsx`, all eleven section files, all five component files and
   the marketing-relevant parts of `tailwind.config.ts`. Understand the existing header comments —
   they record *why* decisions were made and several of them are load-bearing.
2. **Audit first.** Produce a short written critique: what specifically reads as unprofessional, per
   section, with the reason. Be blunt. Do not simply agree with the existing implementation.
3. **Fix the system before the surface** — tokens, type scale, spacing scale, shared card/tile
   treatment — so improvements land everywhere at once rather than section by section.
4. **Then section by section**, hero last-but-one and plans last, because they depend on the system.
5. **Keep new keyframes in `tailwind.config.ts`**, named `ps-*`, each with a comment stating what it
   communicates and why its duration is what it is. Reuse an existing keyframe before adding one.
6. Do not run a build or start a dev server — the user does that.
7. `git add` inside `PSS_2.0_Frontend`. **Never commit.**

## Deliverable

- The audit (short, specific, per-section).
- The implemented changes.
- A list of every keyframe added or removed and what each one communicates.
- An explicit statement that reduced-motion, RTL, keyboard focus, dark mode and the
  no-new-client-JS rule were each checked, and how.
- Anything you deliberately did **not** do, and why.
