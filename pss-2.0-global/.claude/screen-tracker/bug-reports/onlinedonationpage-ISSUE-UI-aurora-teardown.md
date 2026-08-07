# ODP #10 — Aurora template UI pixel-fidelity teardown (P1 UI pass, Session 64)

> **Source of truth**: the official Uyirtham ("Food That Gives Life") donation-landing design image.
> This is a TEXT teardown of that image for the frontend-developer agent (agents cannot see images).
> **The image is the SPEC, not inspiration.** Match layout, spacing, type scale, colour usage, radius,
> shadow, and image proportions. Do NOT redesign or simplify.

## Non-negotiable constraints (hold verbatim)
- **Pure FE.** No schema change, no new EAV param, no DTO-shape change. Render ONLY fields that already
  exist on `publicData` / `publicData.landingContent`. Where the image shows content with NO backing
  field (see "DEFERRED to ISSUE-43" below), **omit it gracefully** — do NOT invent a DTO field.
- **100% dynamic / config-backed.** Every headline, body, benefit, stat, footer node, amount preset,
  donor field, and payment method comes from `publicData`. Only the fallback constants already present
  in the code may remain as fallbacks.
- **Tokens only** (Tailwind design tokens; no raw hex / px) **EXCEPT** the tenant brand colour, which is
  the dynamic `accent` prop — inline `style={{ ... accent ... }}` IS permitted and expected here.
- **`accent`** = tenant forest/olive brand green in the image (buttons, second-tone heading words, icons,
  footer background, selected-chip border, big stat numbers, decorative dividers). Never hardcode a green.
- Responsive: desktop / tablet / mobile. Body must never scroll horizontally.
- **Shared-component caution**: `DonateFormSection`, `GoalProgressStrip`, `FineFooter`, `ClosedBanner`,
  `CustomCssInjector` live in `./shared` and are used by OTHER templates. Read them before editing. Prefer
  additive/opt-in styling (props/className) over structural rewrites. If a change to a shared file would
  alter another template's look, DO NOT force it — flag it in your report and style within Aurora instead.

## Files in scope
- `.../public/onlinedonationpage/templates/template-aurora.tsx` (the composition — read in full)
- `.../public/onlinedonationpage/templates/aurora/HeroBenefits.tsx`
- `.../public/onlinedonationpage/templates/aurora/WhyDonate.tsx`
- `.../public/onlinedonationpage/templates/aurora/ImpactStats.tsx`
- `.../public/onlinedonationpage/templates/aurora/Testimonials.tsx`
- `.../public/onlinedonationpage/templates/aurora/Faq.tsx`
- `.../public/onlinedonationpage/templates/aurora/RichFooter.tsx`
- `.../public/onlinedonationpage/templates/shared/*` — READ FIRST, edit only if safe cross-template.

---

## Global visual language (apply across all Aurora sections)
- **Page background = warm cream / ivory**, NOT pure white. Use a subtle warm off-white for section
  bands (e.g. a very light warm neutral token). White is reserved for elevated CARDS (donate card,
  quote card, testimonial cards) so they lift off the cream.
- Alternate section backgrounds gently: hero photo → cream mission band → slightly tinted "Why" band →
  cream stats band → dark forest-green footer.
- **Large radius** on cards: rounded-2xl / rounded-3xl. **Soft shadows** (shadow-lg/xl, warm not harsh).
- **Generous vertical rhythm**: sections ~py-16 → py-24; comfortable gaps between blocks.
- Headlines: bold, tight tracking, large scale. **Two-tone pattern** everywhere a heading has an accent
  phrase — primary text in near-black/charcoal (`text-slate-900`), the accent phrase in `accent`.
- Icons: @iconify Phosphor. Circular icon containers use a **soft accent-tinted circle** in the mission
  benefits (light green disc + accent icon) — this is the ONE place a tinted (not solid) container reads
  right per the image; KPI/stat icons follow the image (accent-coloured glyphs on cream, or solid accent
  disc for the footer/stat markers). Match the image, not the generic widget rule.

---

## Section-by-section target

### 1. HERO (restructure)
Image: full-bleed golden-hour landscape photo (two boys, arms around shoulders, watching sunset over
green fields). Over it, TOP-LEFT (not bottom):
- **Logo lockup** in a soft translucent-white rounded container (pill/badge): logo image + wordmark +
  small tagline line under it. Current code shows only `logoUrl`; keep logo-only if that's all the data
  gives, but wrap it in the rounded translucent-white badge treatment.
- **Two-tone headline**, large (text-5xl→6xl), bold: primary phrase in **dark charcoal**, second phrase
  in `accent`. Maps to `publicData.pageTitle` (single field) — since pageTitle is one string, render it
  as the primary tone; if a natural accent split field isn't available, render pageTitle in charcoal.
  (The two-tone split with a dedicated accent word is a mission-heading feature, not hero — keep hero
  headline = pageTitle.)
- **Subtitle** = `publicData.description` (dark gray).
- **CTA** = `publicData.buttonText || "Make a Donation"`, green (`accent`) pill, white text, `ph:heart-fill`
  leading icon. Anchor to `#donate`.
- **KEY CHANGE vs current**: current uses a DARK bottom scrim + white bottom-left text. The image uses
  DARK text over the bright image, TOP-left, with a **torn-paper / deckle white bottom edge** where the
  hero meets the cream body. Implement:
  - Replace the heavy `from-black/75` bottom scrim with a **soft light legibility wash** from the
    top-left (e.g. a warm-white/transparent gradient anchored top-left) so DARK headline text stays
    legible over arbitrary tenant photos WITHOUT going full-dark. Keep a faint overall wash for safety.
  - Add a **torn-paper bottom edge**: a decorative white/cream SVG (irregular ripped-paper mask or a
    repeating deckle path) pinned to the hero's bottom, bleeding into the cream mission band. Pure
    SVG/CSS, no asset dependency. Keep it subtle and responsive.
  - Move headline/subtitle/CTA to the TOP-left stack (below the logo badge), not the bottom.
- Robustness note: because tenant hero images vary in brightness, keep the light wash behind the text
  block strong enough that charcoal text is always legible; do not assume a bright photo.

### 2. MISSION + DONATE two-column band (cream background)
LEFT column:
- **Two-tone heading** (already wired): `missionTitle` charcoal + `missionTitleAccent` in `accent`.
  Image stacks them as two visual lines ("Together, We Can" / "Create a Better Tomorrow") — allow the
  accent phrase to wrap to its own line (block/inline-block), keep the space, don't force a `<br>`.
- **Body** = `missionBody` (whitespace-pre-line, slate-600).
- **HeroBenefits** = 3 stacked feature rows. Each row: a **circular soft-green disc** (light accent-tint
  bg) holding an accent-coloured Phosphor icon on the LEFT, then bold title + gray description to the
  right. Comfortable row spacing. Icons/titles/descriptions all come from landingContent (keep existing
  fallback set). Match the image's disc size (~48–56px) and left-aligned row rhythm.
- **DEFERRED to ISSUE-43** (do NOT build now): the secondary photo (kids eating) with the overlapping
  white **quote card** ("No one has ever become poor by giving…"). No backing DTO field → omit. Leave a
  short `{/* ISSUE-43: mission secondary image + quote card — needs EAV field, deferred */}` marker.

RIGHT column — **Donate card** (white, rounded-3xl, shadow-xl, sticky). This wraps `DonateFormSection`.
- Card header: green `ph:heart-fill` (or `ph:hand-heart`) + `donateCardHeading` heading + a subtext line
  ("Your donation helps us continue our mission…"). Subtext: use an existing field if one exists; else
  keep just the heading (do not invent copy as a hardcoded string in a dynamic template — a neutral
  static helper line is acceptable only if the code already had one).
- The numbered steps ("1. Choose Donation Amount", "2. Donor Information", "3. Payment Method") + amount
  preset chips + donor fields + payment-method tiles LIVE INSIDE `DonateFormSection`. **Read it first.**
  - If it already renders numbered steps + chips + payment tiles: align spacing, radius, and the
    **selected state** to the image — selected amount chip and selected payment tile get an `accent`
    border + soft accent-tint fill; unselected are neutral bordered on white.
  - Amount chips: grid of presets (image: ₹500 / ₹1,000(selected) / ₹2,500 / ₹5,000 / ₹10,000 / "Other
    Amount"). Presets are dynamic; keep the grid responsive (4-up on desktop wrapping, 2-up mobile).
  - Payment tiles: UPI / Card / Net Banking / Wallet as icon+label tiles, dynamic from configured
    methods; selected tile = accent border.
  - **Donate button**: full-width, `accent` bg, white, `ph:lock-simple` (or `ph:lock`) leading icon,
    label like "Donate Securely". Below it a centered small `ph:shield-check` + "Your donation is safe
    and secure with us" reassurance line (keep if already present; otherwise a neutral static reassurance
    line is acceptable as it's not tenant content).
  - If DonateFormSection's structure differs materially and matching the image would require a structural
    rewrite that affects other templates → DO NOT rewrite it. Apply the accent/spacing polish you safely
    can and flag the residual gap in your report.

### 3. "WHY YOUR DONATION MATTERS" band (slightly tinted band)
- Centered heading flanked by **decorative leaf/vine dividers** (small accent-tinted Phosphor botanical
  glyph — e.g. `ph:leaf` / `ph:plant` — left and right of the title). Purely decorative, `aria-hidden`.
- **4 columns**, each: accent Phosphor icon + bold title + gray description. Content from landingContent
  (keep existing fallback set of four). Image's four: 100% Impact / Transparent / Tax Benefits / Trusted
  Organization. Icons on the LEFT of each item or above — match the image (icon then title+desc, 4 across
  on desktop, 2×2 tablet, stacked mobile).

### 4. IMPACT STATS band (cream)
- Row of stat segments separated by thin vertical dividers on desktop. Each stat: accent icon/marker +
  label + **big accent number** (text-4xl/5xl bold) + small sub-caption. Content from `landingContent`
  impact stats (keep existing omit-when-empty behavior). Image shows "Lives Touched 25,000+" and "Meals
  Provided 5,00,000+" as two such stats.
- **DEFERRED to ISSUE-43** (do NOT build now): the "Trusted by Generous People" **donor-avatar cluster**
  (overlapping avatars + "2,500+" pill) and per-stat custom `ImpactStatItem.icon` — no backing field.
  Omit the avatar cluster; keep the existing stat icon behavior. Leave an ISSUE-43 marker comment.

### 5. FOOTER — RichFooter (dark forest-green, `accent`-derived dark)
- Background: deep forest green (derive from `accent` — e.g. an accent-based dark tone via overlay, or
  `accent` with a dark scrim; keep text light/white).
- LEFT brand block: logo + wordmark + tagline line; a short tagline paragraph (**tagline paragraph is
  DEFERRED to ISSUE-43** — omit if no field); a **social icons row** — circular outlined icons
  (facebook/instagram/youtube/twitter) sourced from the recursive `footerTree` social nodes.
- Columns from the recursive **FOOTER_TREE** (already built Session 63): "Get in Touch" (address / phone /
  email / website leaf nodes, each with a leading accent-tinted Phosphor icon from the node `iconName`),
  "Useful Information" links, "You Can Also Help" links. RichFooter already renders the tree — refine the
  dark-green palette, leading-icon tinting, column spacing, and social-circle treatment to match the image.
- Bottom copyright bar (slightly darker strip): `FineFooter` — center the "© {year} {tenant}. All rights
  reserved." Keep dynamic.

---

## What is explicitly OUT of this pass (report, do not build)
- ISSUE-43 enrichment fields: mission secondary image, mission quote card, impact donor-avatar cluster +
  heading, per-stat `ImpactStatItem.icon`, footer tagline paragraph. Each needs a NEW EAV param + DTO
  field + assembler + editor row → DTO-shape change → belongs to `/plan-screens #10`, NOT this session.
  Render nothing for these; leave a one-line marker comment where each would slot in.

## Deliverable from the FE agent
- The restyled `template-aurora.tsx` + `aurora/*` matching the teardown, pure-FE, dynamic, responsive.
- A short report listing: (a) exact files touched, (b) any shared-component change made and why it's
  safe (or deferred), (c) every ISSUE-43 gap left as a marker, (d) any place the image couldn't be met
  without a schema/DTO change.
