# ISSUE-42 — Template-variant content via settings (Screen #10 Online Donation Page)

> **Status:** PLANNED / DESIGN NOTE. ISSUE-41's BE is done but **its migration is intentionally NOT
> run yet** — the destructive column DROP is DEFERRED and folded into ISSUE-42's work so the live
> `fund.OnlineDonationPages` table is altered **exactly once** (user decision, session 53). This is a
> design decision to capture now so the growing template matrix doesn't get solved the wrong way (new
> typed columns per variant). **Row already added to §⑬ Known Issues.**

---

## Problem

The public donation page will grow a **matrix** of visual template types, not a fixed few:
Image-based, Video-based, Carousel, Carousel+Video, Carousel+Image, … and "etc." (open-ended).
Each variant needs **different content fields** (a video template needs a video URL/poster/autoplay; a
carousel needs an ordered slide array; an image template needs a hero image; combos need several).

The wrong fix is to keep adding typed columns to `fund.OnlineDonationPages` per variant — that produces
a **sparse-wide table** where most columns are `NULL` for any given page, and every new template type is
a schema migration on a live-money table:

| page type | VideoUrl | VideoPoster | Autoplay | CarouselSlides | HeroImage |
|-----------|:--------:|:-----------:|:--------:|:--------------:|:---------:|
| Image     | NULL     | NULL        | NULL     | NULL           | ✅ |
| Video     | ✅       | ✅          | ✅       | NULL           | NULL |
| Carousel  | NULL     | NULL        | NULL     | ✅             | NULL |
| Carousel+Video | ✅  | ✅          | ✅       | ✅             | NULL |

## Decision

Split the concern in two:

1. **Which template is selected → stays typed.** Already handled by `OnlineDonationPage.PageTypeId`
   (FK → `sett.MasterDatas`, `TypeCode = 'ONLINEDONATIONPAGETYPE'`; existing `DataValue`s: `STANDARD`,
   `CAROUSEL_FOCUS`, `IMAGE_FOCUS`, `VIDEO_FOCUS`, `MINIMAL`). Adding a new template type =
   **one MasterData row**. No schema change.

2. **Template-specific content/config → `fund.OnlineDonationPageSettings` (EAV), never new typed
   columns.** This is exactly what the settings table was built for ("sections with no backing
   columns"). The renderer reads `PageTypeId`, which tells it **which `SectionCode`s** to pull, and it
   assembles the page from settings rows.

### Model

```
PageTypeId (MasterData)  ──selects──▶  renderer component (per variant, real code)
                                            │
                                            └─reads─▶ OnlineDonationPageSettings
                                                      WHERE SectionCode IN (variant's sections)
```

### ⚠️ The renderer dispatcher ALREADY EXISTS (session 18/20 — do NOT rebuild it)

The selector-→-component split this note proposes is **already implemented** on the FE. ISSUE-42 does
NOT need to invent the dispatch; its real delta is only **where the content comes from** (typed media
columns → settings EAV). Actual file locations:

| Piece | Path (`PSS_2.0_Frontend/src/…`) |
|-------|--------------------------------|
| **Dispatcher** ("the template page") — switches on `pageTypeCode` | `presentation/components/page-components/public/onlinedonationpage/donation-page.tsx` |
| **7 page templates** | `…/public/onlinedonationpage/templates/template-{aurora,cinematic,editorial,banner-story,gallery,spotlight,pure}.tsx` |
| **7 matching thank-you states** | `…/templates/thank-you-{aurora,cinematic,editorial,banner-story,gallery,spotlight,pure}.tsx` |
| **STANDARD/Aurora content sub-sections** (the settings-fed landing blocks) | `…/templates/aurora/{HeroBenefits,WhyDonate,ImpactStats,MissionBlock,RichFooter}.tsx` |
| **Shared props/types** | `…/templates/types.ts`, `…/templates/shared.tsx` |
| **Public SSR route** (server fetch → `<DonationPage>`) | `app/[lang]/(public)/p/[slug]/page.tsx` |
| **Preview routes** | `app/[lang]/(public)/preview/onlinedonationpage/[id]/page.tsx`, `app/[lang]/(public)/templates/preview/[code]/page.tsx` |
| **Iframe embed** | `app/[lang]/(public)/embed/[slug]/page.tsx` |

Current `pageTypeCode` → template map (from `donation-page.tsx` header): `STANDARD`→Aurora,
`IMAGE_FULL`/`IMAGE_FOCUS`→Cinematic, `IMAGE_LEFT_HALF`→Editorial, `IMAGE_RIGHT_HALF`→Editorial(mirror),
`IMAGE_TOP`/`IMAGE_BOTTOM`→BannerStory, `CAROUSEL_FULL`/`CAROUSEL_FOCUS`→Gallery,
`VIDEO_HERO`/`VIDEO_FOCUS`→Spotlight, `MINIMAL`→Pure. Unknown code degrades to Aurora.

**So ISSUE-42's remaining work is narrower than a from-scratch build:** (a) add new `PageType`
MasterData rows for genuinely new combos (Carousel+Video, Carousel+Image, …) — each maps to a new or
composed template component, (b) feed each template's media/content from `OnlineDonationPageSettings`
(via the assembled `landingContent` channel) instead of the typed media columns, (c) the combined
migration then drops those now-unused typed media columns.

Example per-variant settings catalog (illustrative — finalize in the /plan-screens pass):

| PageType `DataValue` | Reads `SectionCode`(s) | Example `ParamCode`s |
|----------------------|------------------------|----------------------|
| `IMAGE_FOCUS`   | `MEDIA_IMAGE`   | `HERO_IMAGE_URL`, `IMAGE_ALT` |
| `VIDEO_FOCUS`   | `MEDIA_VIDEO`   | `VIDEO_URL`, `VIDEO_POSTER_URL`, `AUTOPLAY`, `LOOP`, `MUTED` |
| `CAROUSEL_FOCUS`| `MEDIA_CAROUSEL`| `SLIDES` (json array `{type,url,title,order}`) |
| `CAROUSEL+VIDEO`| `MEDIA_CAROUSEL` + `MEDIA_VIDEO` | union of the two above |
| `CAROUSEL+IMAGE`| `MEDIA_CAROUSEL` + `MEDIA_IMAGE` | union |

**Adding a template type** then costs: (a) one MasterData row, (b) a settings-param catalog for its
sections, (c) **one renderer component**. It is **zero schema migration** — but *not* zero code, because
the visual layout of each variant is genuinely different React (image-focus ≠ video-focus).

## Scope of columns this pass relocates

- **Template-presentation media columns MOVE into settings** as part of ISSUE-42:
  `CarouselSlidesJson`, `HeroImageUrl`, `LogoUrl`. These are per-template visual content — they belong
  in the variant's settings catalog, not as sparse typed columns. Finalize the exact set in the
  `/plan-screens #10` pass (validation rules — e.g. max-5 slides — must be preserved in the settings
  layer / renderer, not lost with the column).
- **KEEP typed** the donation-**FORM** config: `AmountChipsJson`, `AvailableFrequenciesJson`,
  `AllowCustomAmount`. These drive payment-form behavior (amounts, frequencies), not template
  presentation — they are the same for every template variant, so they are NOT template content.
- **This changes the Spec** (new PageType→settings contract, renderer registry, media relocation). It
  therefore needs a **`/plan-screens #10` spec revision** to formalize §⑥ (the per-PageType settings
  catalog + renderer registry), not a `/continue-screen` fix. `/continue-screen` handles in-scope
  tweaks only.

## Migration — SINGLE combined pass (user decision, session 53)

ISSUE-41's BE is done but **its migration was intentionally not run**. The live `fund.OnlineDonationPages`
table is altered **exactly once**, covering BOTH issues:

1. **Additive backfill** (user-owned seed): copy every existing row's values into settings rows —
   ISSUE-41's **15 cosmetic** columns (per the §⑬ mapping table) **+** ISSUE-42's **media** columns
   (`CarouselSlidesJson`, `HeroImageUrl`, `LogoUrl`).
2. **Verify** the reassembled reads (typed GetById/GetBySlug still return identical values) AND that the
   SSR `<head>` / OG-meta path still renders — do this on the SEO section **last**, per the ISSUE-41
   NULL/SSR rules.
3. **ONE destructive migration** (user-owned): `DROP COLUMN` for all of them together — 15 cosmetic +
   the media columns — in a single EF migration. No two-migration sequence on a live-money table.

Other notes:
- Settings-catalog additions for NEW template types are **additive seeds** (`sql-scripts-dyanmic`),
  user-owned — no column changes needed once the model is in place.
- Reuse the ISSUE-40 renderer-fallback guarantee: a variant that finds no settings row falls back to a
  coded default; never assume a row exists.
- `ParamDataType` stays within the allowed set (`string|text|int|decimal|bool|url|color|json`); slide
  arrays and combos use `json`.

---

## §⑬ paste-in block — DONE (already added to Known Issues, session 53)

The row is live in `prompts/onlinedonationpage.md` §⑬. It records the single-combined-migration decision
(41's DROP deferred and merged with 42) and that this pass relocates the media columns
(`CarouselSlidesJson`, `HeroImageUrl`, `LogoUrl`) while keeping the form config typed. No further paste
needed.
