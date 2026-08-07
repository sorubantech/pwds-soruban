# PROMPT 20 — Product Landing Page & Anonymous Lead Capture

**Status:** NOT BUILT.
**Surface:** FE (new `(public)` marketing route) + BE (one anonymous mutation, one anonymous query) + migration spec (user-owned) + seed SQL (user-applied).
**Depends on:** nothing hard. Reads `billing.Plans` if present (§3.5 degrades gracefully if not).
**Related:** PROMPT-19 Phase 2 §⑮ Q4 — this page decides what the apex domain serves.

---

## ⚠️ Rules for whoever builds this

1. **Do not run `dotnet build`.** The user builds the backend.
2. **Migrations are strictly user-owned.** Never run `dotnet ef migrations add` / `database update` / `remove`, and never hand-author a migration or a snapshot. Write the *spec* in §④ step 2; the user authors, runs and commits it.
3. **Seed SQL is written, not run.** Files go in `sql-scripts-dyanmic/`; the user applies them.
4. **Frontend typecheck:** `cd PSS_2.0_Frontend && npx tsc --noEmit --incremental false`, no pipe. Only exit 0 counts as clean.
5. **`PSS_2.0_Backend/` and the frontend are gitignored** — the Grep/Glob tools return zero `.cs` matches. Use `find -iname` to locate files, or scope `grep -rn --include=*.cs` to **one** project subdirectory (a repo-wide backend grep times out at 120 s). Absolute-path `Read` works fine.
6. **HotChocolate strips `Get` from every resolver name** and appends `Input` to input types: `GetPublicPlanTeasers` → `publicPlanTeasers`, `ProductEnquiryDto` → `ProductEnquiryDtoInput`. tsc cannot see gql field names — a wrong name builds clean and fails only at runtime. Verify against the schema.
7. **DB is UTC-only.** Every Postgres date column is `timestamp with time zone`; Npgsql throws on `Kind = Unspecified`. Use `DateTime.UtcNow`.
8. **This page creates no tenant and no user account.** It creates a `Lead`. Nothing else.

---

## ⓪ Code locations — verified on disk 2026-08-03

| What | Where | State |
|---|---|---|
| Public route group | `src/app/[lang]/(public)/layout.tsx` | Anonymous, no sidebar/header/auth gate. Renders `ApolloWrapper` + children. **Exports `metadata = { title: "Donate", robots: { index: true, follow: true } }`** — group-wide, must be overridden (§3.1). |
| Existing public routes | `(public)/{p,crowdfund,event,p2p,pray,volunteer,embed,preview,templates,payu,event-payu}` | **Every one is tenant-scoped by slug.** A platform-owned, non-slug public route would be the first of its kind. |
| Lang root | `src/app/[lang]/page.tsx` | **Does not exist** — `/{lang}` 404s today. The marketing root is free to claim; no route conflict. |
| Middleware | `PSS_2.0_Frontend/middleware.ts` | Locale negotiation **only** (`bn`, `en`, `ar`, default `en`). No auth gate, no host handling. |
| ⚠️ Name collision | `src/presentation/pages/master/landing-page/` | This is the **post-login module launcher** ("mission control": `modules-grid`, `kpi-snapshot-row`, `command-palette`, `tenant-clock`). It is *not* marketing. **Do not put marketing components here and do not call the new one `landing-page`.** |
| Lead entity | `Base.Domain/Models/OpsModels/Lead.cs` | `ops.Leads`, platform-global (**no `CompanyId`**), soft-delete only. Fields: CompanyName, ContactName, ContactEmail, ContactPhone?, CountryId (**required**, FK `com.Countries`), Source, Status, OwnerUserId?, EstimatedPlanCode?, Notes?, LostReason?, ConvertedCompanyId?. |
| Lead create | `Base.Application/Business/OpsBusiness/LeadManagement/Commands/CreateLead.cs` | **`[CustomAuthorize("PLATFORM_LEADS", "PLATFORM_LEAD_EDIT")]`** and accepts a full `LeadRequestDto` incl. `Status`, `OwnerUserId`, `EstimatedPlanCode`. **Not reusable from an anonymous caller** (§3.3). Server already forces `LeadId = 0`, `ConvertedCompanyId = null`, and refuses birth-as-`WON`. |
| Lead lifecycle | `LeadHelper.AllowedSources` / `AllowedStatuses` | `NEW → QUALIFIED → WON/LOST`; `INBOUND` is an existing allowed Source. `WON` is earned by approving a commercial term. |
| Anonymous-mutation exemplar | `.../VolunteerRegistrationPages/PublicMutations/SubmitVolunteerApplication.cs` and `Base.API/EndPoints/ContactModels/Public/PrayerRequestPublicMutations.cs` | Honeypot → silent mock-success · CSRF double-submit · reCAPTCHA score (reject < 0.5) · rate-limit policy attached at the endpoint. **CSRF store and reCAPTCHA are `SERVICE_PLACEHOLDER` stubs today** (reCAPTCHA returns 1.0) — see §⑥. |
| Rate-limit policies | `Base.API/DependencyInjection.cs:226+` (`AddRateLimiter`), `app.UseRateLimiter()` at :396 | Fixed-window. Existing public policies are 5/min/IP (`PublicSubmitRateLimit`, `DonationSubmit`, `VolunteerSubmit`, …). |
| Countries | `Base.API/EndPoints/Shared/Queries/CountryQueries.cs` → `GetCountries` | Paginated grid query, `[AsParameters] GridFeatureRequest`, **no `[CustomAuthorize]`**. Reachable anonymously, but it is a full admin grid endpoint — do not bind a public form to it (§3.4). |

---

## ① The one idea

**The enquiry form on the marketing page is not a new form. It is the anonymous front door to `ops.Leads`, which already exists end-to-end.**

There is already a lead table, a `/ops/leads` screen, a `PLATFORM_SALES` role, an `INBOUND` source value, a commercial-terms flow, and a provisioning wizard that turns a `WON` lead into a tenant. Nobody has to design a pipeline. The only missing link is a hardened anonymous mutation that drops a row at the front of it.

Everything else on the page — hero, pillars, pricing, FAQ — is presentation whose sole job is to get a qualified visitor to that form. Build the form path first and correctly; the marketing surface can iterate forever afterwards.

**Corollary that constrains the whole build:** this page never creates a tenant, a user, a subscription or a trial. It creates a `Lead` with `Status = NEW`. A human qualifies it, a human approves commercial terms, and only then does the provisioning engine run. Any CTA that implies instant access is a lie until self-serve signup is a decided feature (§⑨ Q2).

---

## ② Placement

### 2.1 Build it in this Next.js app, under `(public)` — not a separate marketing site

For MVP: one deploy, one design system, one i18n setup, direct GraphQL to the same API with no CORS story, and no second thing to keep in sync. A separate CMS-backed marketing site is a real option **later**, when marketing wants to edit copy without a deploy — that is the trigger to revisit, and it is out of scope here (§⑦).

### 2.2 Route

```
src/app/[lang]/(public)/(marketing)/layout.tsx   ← own metadata, overrides "Donate"
src/app/[lang]/(public)/(marketing)/peopleserve/page.tsx  ← serves /{lang}/peopleserve
```

A nested route group `(marketing)` adds no URL segment and gives the marketing pages their own layout without disturbing the eleven tenant-slug routes that share `(public)`. The real `peopleserve/` segment sits under it.

**The page is NOT at the locale root.** `pwdatasolutions.com/{lang}` is PW Data Solutions' own company site; PeopleServe is one product on it, so the product page lives one segment deeper. Production `https://pwdatasolutions.com/en/peopleserve`, local `http://localhost:3000/en/peopleserve`. The path is defined once, as `PRODUCT_PATH` + `productPageUrl()` in `product-landing-content.ts`, and canonical / hreflang / OG / JSON-LD all derive from it so the URL sets cannot disagree.

Components live in **`src/presentation/pages/marketing/`** — *not* `pages/master/landing-page/`, which is the post-login launcher (see ⓪).

### 2.3 Which hostname serves it

Per PROMPT-19 Phase 2 §⑮ Q4, the clean split is:

| Host | Serves |
|---|---|
| apex (`pwdatasolutions.com` or equivalent) | **this page** + the lead form. No login. |
| `admin.*` | platform login → platform dashboard |
| `{tenant}.*` | tenant login → that tenant's app |

The apex resolves to `HostKind.Unknown` under the Phase 2 gate, which is exactly right: it renders public content and accepts no credentials. **The marketing page and the host gate agree without either knowing about the other.** If you later want the apex to also host the platform login, it must be added to the `Auth:PlatformHosts` allow-list — a deliberate act, not a default.

---

## ③ Design

### 3.1 Metadata — the one page that genuinely wants indexing

`(public)/layout.tsx` sets `title: "Donate"` and `robots: { index: true, follow: true }` for the whole group. The marketing layout must override both:

```tsx
export const metadata: Metadata = {
  title: { default: "…", template: "%s | …" },
  description: "…",                       // ≤ 155 chars, the SERP snippet
  robots: { index: true, follow: true },
  alternates: { canonical: "…", languages: { en: "…", bn: "…", ar: "…" } },
  openGraph: { type: "website", images: [{ url: "…", width: 1200, height: 630 }] },
  twitter: { card: "summary_large_image" },
};
```

`alternates.languages` is not optional — three locales at three URLs with the same content is duplicate content without `hreflang`. Add `Organization` + `SoftwareApplication` JSON-LD via a `<script type="application/ld+json">` in the layout.

**This page must be a Server Component.** It is the only page in the product whose ranking depends on server-rendered HTML. Push `"use client"` down to the leaves that need it — the form, the pricing toggle, the FAQ accordion, the mobile nav. If the whole page ships as a client component the SEO work is wasted.

### 3.2 Page sections (MVP)

Ordered as the visitor reads them. Each is a folder under `pages/marketing/sections/`.

| # | Section | Job | Notes |
|---|---|---|---|
| 1 | **Hero** | State what this is and who it is for in one sentence | Headline names the *outcome*, not the software. One primary CTA ("Request a demo" → scrolls to form), one secondary ("See plans" → anchors to pricing). No carousel. |
| 2 | **Trust strip** | Survive the credibility check | Logos or a metric line. **If we have no customers to name yet, omit the section entirely** — an empty or placeholder logo wall reads as failure. Do not ship lorem logos. |
| 3 | **Problem → outcome** | Make the visitor recognise themselves | Three named pains from the actual domain (receipting, grant tracking, donor duplication), each with the outcome. |
| 4 | **Module pillars** | Show scope | Map to the **real** module list (`auth.Modules`) — Donation, Contact/CRM, Case, Grant, Fund, Membership, Communications, Reports. Icon + name + one line. Do not invent modules we don't ship. |
| 5 | **How it works** | Kill "how long until we're live?" | Three steps: enquiry → guided onboarding → go live. This is where you set the expectation that onboarding is assisted, which pre-frames the lead form. |
| 6 | **Plans** | Qualify by budget before the form | Rendered from `billing.Plans` — see §3.5. |
| 7 | **Security & data** | Answer the objection that kills charity deals | Tenant isolation, encryption in transit/at rest, audit trail, data residency, backups. **Claim only what is true.** No compliance badge we do not hold. |
| 8 | **FAQ** | Absorb the long tail | 6–8 questions. Accordion, but render all answers in the DOM (collapsed via CSS) so they are indexed and Ctrl-F-able. |
| 9 | **Enquiry form** | The conversion | §3.3. Give it `id="enquiry"`; every CTA above targets it. |
| 10 | **Footer** | Legal + links | Reuse the existing privacy-policy URL from `pages/master/landing-page/footer.tsx` (`https://pwdatasolutions.com/privacy-policy/`) — **link it, don't import that component**, it belongs to the launcher. |

### 3.3 `SubmitProductEnquiry` — the anonymous mutation

**Do not reuse `CreateLeadCommand`.** It is `[CustomAuthorize]`-gated, and its DTO accepts `Status`, `OwnerUserId`, `EstimatedPlanCode` and `LostReason` — an anonymous caller must not be able to set any of them. Removing the attribute to "reuse" it would hand the public internet write access to the sales pipeline's control fields. New command, new narrow DTO.

```
Base.Application/Business/OpsBusiness/LeadManagement/PublicCommands/SubmitProductEnquiry.cs
Base.API/EndPoints/Ops/Public/ProductEnquiryPublicMutations.cs
```

**Accepted from the client** (and nothing else): `OrganizationName`, `ContactName`, `ContactEmail`, `ContactPhone?`, `CountryId`, `Industry?`, `OrganizationSize?`, `Website?`, `Notes?`, `ConsentGiven`, plus the three hardening fields `CsrfToken`, `RecaptchaToken`, `Website2` (honeypot — see naming warning below).

**Forced server-side, never read from the input:**

```csharp
entity.LeadId             = 0;
entity.Source             = LeadHelper.SOURCE_INBOUND;   // always
entity.Status             = LeadHelper.STATUS_NEW;       // always
entity.OwnerUserId        = null;                        // unassigned; sales claims it
entity.EstimatedPlanCode  = null;                        // a visitor does not price the deal
entity.LostReason         = null;
entity.ConvertedCompanyId = null;
entity.CreatedDate        = DateTime.UtcNow;             // UTC, rule 7
```

**Hardening — copy `SubmitVolunteerApplication.cs` exactly, do not improvise:**

- **Honeypot** — a hidden field a human never fills. **Naming warning:** the volunteer exemplar names its honeypot `Website`, and this form has a *real* `Website` field. Name the honeypot something else (`ReferralCode`) and label the real one clearly, or a legitimate submission with a website silently vanishes into mock-success. This is the single easiest bug to ship here.
- **Silent mock-success** on honeypot hit: return the same success shape, write nothing. Never tell a bot it was caught.
- **CSRF** double-submit token, validator requires it.
- **reCAPTCHA** score, reject < 0.5.
- **Rate limit** — register `ProductEnquirySubmit` in `DependencyInjection.cs:226+` alongside the existing policies. Fixed window, **5/min/IP** to match the others.
- **Duplicate suppression** — same email within 24 h updates `Notes` on the existing `NEW` lead rather than inserting a second row, and returns success either way. Sales should not open ten rows because someone double-clicked. Do **not** dedupe against `QUALIFIED`/`WON`/`LOST` leads — a returning prospect is a real new enquiry.

**Response:** a bare `{ success: true }`. Never return the `LeadId`, and never return a different message for "already enquired" — both leak information and neither helps the visitor.

**Notification:** on insert, email the platform sales alias via the existing `ops.PlatformCommunicationProviders` path (that table is the platform's own sender config, distinct from tenant providers). **Fire-and-forget: a failed notification must never fail the submission.** The lead is already durably stored; losing the email costs a delay, losing the lead costs the deal. If the platform EMAIL provider row is absent, log a warning and return success.

### 3.4 Countries

`Lead.CountryId` is required and FK-validated, so the form needs a country dropdown.

`GetCountries` has no `[CustomAuthorize]` and is anonymously reachable, but it is a paginated **admin grid** endpoint taking `GridFeatureRequest`. Binding a public form to it exposes an admin surface and ships grid machinery to every marketing visitor. Add a purpose-built anonymous query instead:

```
GetPublicCountriesQuery → IReadOnlyList<{ CountryId, CountryName, IsoCode }>
```

Active, non-deleted, name-ordered, no paging, cached ~1 h (the country list does not change). Small, cacheable, and it says exactly what it is.

### 3.5 Plans section — render from `billing.Plans`, and gate what is public

Hardcoding prices into JSX guarantees the marketing page and the billing engine disagree within a quarter. Read the real table via a new anonymous query:

```
GetPublicPlanTeasersQuery → IReadOnlyList<{ PlanCode, PlanName, Description, Price, CurrencyCode, Highlights[] }>
```

**But `billing.Plans` contains internal plans** — trials, custom-negotiated tiers, deprecated grandfathered rows. Publishing all of them is a leak. Add `Plan.IsPubliclyListed` (bool, default **false**) and filter on it. Default-false matters: a new internal plan must not appear on the public site because someone forgot a flag.

Never expose quota internals, meter codes, entitlement rows or feature-gate codes. Marketing highlights only.

**Degrade gracefully:** if the query fails or returns empty, render the section as "Plans tailored to your organisation → talk to us" pointing at the form. A marketing page must never show a stack trace or an empty price grid.

**CTAs on every plan card go to the enquiry form** — not to a signup. Self-serve is undecided (§⑨ Q2).

### 3.6 `ops.Leads` needs four columns

The form asks for Industry, Organization Size and Website; the lead table has none of them. Burying them in `Notes` destroys filterability on `/ops/leads` — and "show me all enquiries from hospitals sized 50+" is precisely the query sales will want on day one. Add them properly:

| Column | Type | Why |
|---|---|---|
| `Industry` | `varchar(100)?` | Segmentation. Free-ish text from a fixed dropdown; do not FK to MasterData for MVP. |
| `OrganizationSize` | `varchar(50)?` | Bucket string (`1-10`, `11-50`, …), not an int — visitors estimate, and the buckets are what sales filters on. |
| `Website` | `varchar(255)?` | The single highest-value qualification signal on the form. |
| `ConsentedAt` | `timestamptz?` | **Required for a consent checkbox to mean anything.** A checkbox whose result is not stored is not consent, it is decoration. Store the UTC timestamp; store `ConsentIpAddress varchar(45)?` too if legal wants it (IPv6 needs 45). |

**Business Address is deliberately omitted.** The pasted brief asks for it; it belongs on the sales call, not on a conversion form. Every additional field costs completions, and an address we cannot validate and do not use before qualification is pure friction. If you want it, say so and I will add it — but it should be a decision, not a default.

**Migration spec for the user** (rule 2 — do not run it):

> **⚠️ HANDOVER — this migration is yours to author, run and commit.**
> The C# side is already written: the entity properties and the EF configurations are in the repo. Nothing else in the build proceeds past compile until this runs. Per §④ step 4 this is **one** migration covering both column sets, not two.

```
dotnet ef migrations add Add_LeadEnquiryFields_And_PlanPublicListing
```

```
Add_LeadEnquiryFields_And_PlanPublicListing

  ops.Leads     + Industry           varchar(100)  NULL
  ops.Leads     + OrganizationSize   varchar(50)   NULL
  ops.Leads     + Website            varchar(255)  NULL
  ops.Leads     + ConsentedAt        timestamptz   NULL
  ops.Leads     + ConsentIpAddress   varchar(45)   NULL

  billing.Plans + IsPubliclyListed   boolean       NOT NULL DEFAULT false
```

Source of each column, so the generated migration can be checked against the code rather than trusted:

| Column | Entity | EF configuration |
|---|---|---|
| `ops.Leads.Industry` … `ConsentIpAddress` | `Base.Domain/Models/OpsModels/Lead.cs` | `Base.Infrastructure/Data/Configurations/OpsConfigurations/LeadConfiguration.cs` |
| `billing.Plans.IsPubliclyListed` | `Base.Domain/Models/BillingModels/Plan.cs` | `Base.Infrastructure/Data/Configurations/BillingConfigurations/PlanConfiguration.cs` |

**Everything is additive.** No backfill, no index, no data movement, no column dropped or retyped. Existing rows and the `/ops/leads` screen are unaffected, and the migration is reversible by a plain `Down`.

**The one thing to verify in the generated file:** `IsPubliclyListed` must come out `NOT NULL` with `defaultValue: false`. It is the only non-nullable column here, so it is the only one that can fail on existing rows — and the default is what makes the flag safe: every plan already in `billing.Plans` stays *unlisted* through the migration. A plan becomes public only when `plan-public-listing-seed.sql` says so. If the generated migration is missing the default, add it before running; a `NOT NULL` without one will error on a non-empty table.

**Order of operations:**
1. Run this migration.
2. Apply `sql-scripts-dyanmic/plan-public-listing-seed.sql` — it `UPDATE`s `IsPubliclyListed` and will fail with `42703 undefined_column` if run first.
3. Apply `sql-scripts-dyanmic/product-enquiry-notification-seed.sql` — **change the recipient address in section 2 first.**

Then surface the new fields read-only on the lead detail drawer — a captured field nobody can see was not worth capturing.

---

## ④ Build steps

1. **BE — `GetPublicCountriesQuery`** (§3.4) + endpoint. Anonymous, cached.
2. **Migration spec** (§3.6) — write it into this file's §3.6 and **stop**. Hand it to the user. Do not proceed to step 3 assuming it is applied; step 3 compiles only after the user has run it.
3. **BE — `SubmitProductEnquiry`** (§3.3): command, validator, handler, DTO, public mutation endpoint, `ProductEnquirySubmit` rate-limit policy in `DependencyInjection.cs`.
4. **BE — `Plan.IsPubliclyListed`** + `GetPublicPlanTeasersQuery` (§3.5). **This is a second migration** — fold it into the step-2 spec so the user runs one migration, not two.
5. **Seed** — `sql-scripts-dyanmic/plan-public-listing-seed.sql`: set `IsPubliclyListed = true` on the plans the user names. Write it; do not run it. **Leave it empty of guesses** — ask which plans are public (§⑨ Q1).
6. **FE — route + layout + metadata + JSON-LD** (§2.2, §3.1). Server Component.
7. **FE — sections 1–8** (§3.2), static content, no data dependency except plans.
8. **FE — the enquiry form**: RHF + zod, client component, honeypot/CSRF/reCAPTCHA wiring, inline field errors, submit-disabled-while-pending, success state that **replaces** the form (not a toast — a toast on a marketing page is easy to miss and invites double submission).
9. **FE — plans section** bound to `publicPlanTeasers` with the graceful-degradation branch.
10. **Typecheck** — `npx tsc --noEmit --incremental false`, exit 0.
11. **Record deviations** in §⑬ and update the task list.

---

## ⑤ UI notes

- **Mobile-first.** Enterprise buyers research on phones. The form must be usable one-handed: `inputMode="email"` / `type="tel"`, no side-by-side field pairs below `sm`.
- **Follow the design tokens** — no raw hex, no raw px. This page will be tempted into bespoke marketing styling; resist it beyond the hero.
- **`ar` is RTL.** The layout must not assume LTR — logical properties (`ms-`/`me-`, `text-start`), not `ml-`/`text-left`. Check the hero and the pricing cards specifically.
- **Icons:** `@iconify` Phosphor, consistent with the rest of the product.
- **Accessibility is not optional on a public page.** Real `<label>`s (not placeholders-as-labels), `aria-describedby` on errored fields, `aria-live="polite"` on the submit result, visible focus rings, 4.5:1 contrast, one `<h1>` and a sane heading order, skip-link to `#enquiry`. Test the whole form with the keyboard only.
- **Performance:** `next/image` with explicit dimensions, no layout shift in the hero, no web-font FOIT. LCP is the hero heading — do not put it behind a client-side data fetch.
- **Empty/error/loading states** for the plans section only; every other section is static.

---

## ⑥ Invariants

1. **No tenant, user, subscription or trial is created by this page.** Only `ops.Leads`.
2. **`Source = INBOUND` and `Status = NEW` are server-forced**, never client-supplied.
3. **`OwnerUserId`, `EstimatedPlanCode`, `LostReason`, `ConvertedCompanyId` are unsettable** from this surface.
4. **The response never varies** with whether the email already exists, whether the honeypot fired, or whether the notification sent. One success shape.
5. **A failed notification never fails the submission.**
6. **`IsPubliclyListed` defaults to false.** Unflagged plans are invisible.
7. **The consent checkbox writes `ConsentedAt`** or it is not consent.
8. **The honeypot is not named `Website`** (§3.3).
9. ⚠️ **CSRF and reCAPTCHA are `SERVICE_PLACEHOLDER` stubs today** — the CSRF store is not wired and the reCAPTCHA verifier returns a hardcoded 1.0. Wiring them is out of scope here (§⑦), but **this page is the first genuinely public, un-slugged, internet-facing form we ship**, which changes the risk profile: the existing public forms are at least obscured behind a tenant slug. The rate limit is therefore the *only* real spam defence at launch. Say so explicitly in the handover; do not let it be discovered later.

---

## ⑦ Out of scope

- A CMS or headless marketing site — revisit when marketing needs copy edits without a deploy.
- Self-serve signup / instant trial (§⑨ Q2).
- Wiring the CSRF store and the real reCAPTCHA verifier (own prompt; see §⑥.9).
- Blog, case studies, changelog, docs site, careers.
- A/B testing, analytics vendor, cookie-consent banner — **but if any analytics is added, the cookie banner ships with it, not after.**
- Multi-currency pricing display; render the plan's own currency.
- Editing lead fields from the marketing side.
- Business Address on the form (§3.6).

---

## ⑧ Acceptance

- [ ] `/{lang}/peopleserve` renders all MVP sections at 375 px, 768 px and 1440 px with no horizontal scroll.
- [ ] Page source contains the hero copy **before** hydration (view-source, not devtools) — proves it is server-rendered.
- [ ] `<title>` is the marketing title, **not "Donate"**; `hreflang` present for `en`/`bn`/`ar`; JSON-LD validates.
- [ ] A valid submission creates exactly one `ops.Leads` row with `Source = INBOUND`, `Status = NEW`, `OwnerUserId IS NULL`, `EstimatedPlanCode IS NULL`, `ConvertedCompanyId IS NULL`, and a non-null `ConsentedAt`.
- [ ] The new lead appears on `/ops/leads` with Industry / Size / Website visible on the detail drawer.
- [ ] A crafted mutation setting `status: "WON"` or `ownerUserId: 1` either fails schema validation or is silently ignored — **verify by reading the row, not the response**.
- [ ] Honeypot filled → success response, **zero** rows inserted.
- [ ] A submission with a real `website` value **succeeds** (the §3.3 naming trap).
- [ ] 6th submission within a minute from one IP → 429.
- [ ] Same email twice in 24 h → one row, notes appended, success both times.
- [ ] Platform provider row deleted → submission still succeeds, warning logged.
- [ ] Plans section shows only `IsPubliclyListed = true` rows; with the query forced to fail it shows the "talk to us" fallback, not an error.
- [ ] Keyboard-only completion of the form works end to end; errors are announced.
- [ ] `ar` renders RTL with no clipped or mirrored-wrong layout.
- [ ] `npx tsc --noEmit --incremental false` exits 0.

---

## ⑨ Open questions — **answered 2026-08-03, build proceeded on these**

**A1 — real prices, top tier "Custom".** All four catalogue tiers are listed: FREE (₹0), PLAN_50K "Growth" (₹50,000/yr), PLAN_100K "Full Suite" (₹100,000/yr) all show their real number; CUSTOM "Enterprise" renders the word *Custom* — its stored `Price` of 0 is an internal anchor and the FE must never print it. `GetPublicPlanTeasers` returns `IsCustom` so the card can make that substitution. Published by `plan-public-listing-seed.sql`.

**A2 — no self-serve path.** Unchanged from the assumption throughout: every CTA on the page, including every plan card, scrolls to `#enquiry`. Nothing on this surface creates a tenant, a user or a trial. If FREE later becomes self-selectable (PROMPT-14), the hero gains a second primary CTA and this prompt needs a follow-up phase.

**A3 — `/{lang}/peopleserve`, no middleware change.** *(Superseded during the build: the answer originally read "keep `/{lang}`". The locale root belongs to the PWDS company site, so the product page took its own segment — see §② and deviation 11.)* The page is served at `/{lang}/peopleserve`; the apex still redirects to `/{lang}`. Deliberately *not* touching the shared middleware matcher to serve a bare `/`: that matcher governs eleven live tenant-slug routes, and the duplicate-content concern it would solve is already handled properly by the canonical link and the `hreflang` set in §3.1. A cosmetic URL improvement is not worth putting tenant routing at risk; revisit as its own change if marketing insists.

**A4 — a platform-global setting holds the recipient.** `PLATFORM_LEAD_NOTIFICATION_EMAIL` in `sett.OrganizationSettings` (`CompanyId IS NULL`), read by `LeadHelper.GetPlatformSettingAsync`. Seeded with a **placeholder** by `product-enquiry-notification-seed.sql` — set it to a real monitored inbox before applying. Absent or blank ⇒ no alert is sent and the submission still succeeds, so an unset value fails quiet, not loud: leads accumulate unseen on `/ops/leads`. The question's own warning stands — an unmonitored alias is worse than no notification.

**A5 — no nameable customer, so the trust strip is omitted.** §3.2 forbids placeholder logos, and a "trusted by" strip with invented names is worse than no strip. Section 2 does not ship. Add it in a follow-up the day there is a real customer who has agreed to be named.

---

### Original questions, for the record

**Q1 — which plans are publicly listed, and do we show prices at all?** Named prices qualify hard and deter tyre-kickers; "from $X" or "talk to us" keeps negotiating room, which matters if charity pricing is discretionary. Blocks step 5. My leaning: show real prices for the self-serve-sized tiers, "Custom" for the top one.

**Q2 — is there ever a self-serve path from this page?** Everything above assumes no: every CTA goes to the form. This also depends on the still-open PROMPT-14 question of whether FREE is self-selectable. If FREE becomes self-serve, the hero gains a second primary CTA and this prompt needs a follow-up phase.

**Q3 — what is the apex hostname**, and does it serve `/` or `/{lang}` at the root? Ties to PROMPT-19 Phase 2 §⑮ Q3/Q4. If the apex must serve a bare `/` with no locale segment, the middleware matcher needs a look — today it redirects to `/{lang}`, which is fine but yields `pwdatasolutions.com/en`.

**Q4 — which contact address receives the lead notification**, and is it a real monitored inbox? An unmonitored alias is worse than no notification, because it manufactures the belief that leads are being seen.

**Q5 — do we have any customer we may name publicly?** Decides whether section 2 ships at all (§3.2).

---

## ⑩ Build log

### Session 1 — 2026-08-03 — BUILT (steps 1–11 complete)

**⚠️ Read this first, before anything else in this log.**

> **CSRF and reCAPTCHA on this page are `SERVICE_PLACEHOLDER` stubs.** The CSRF token store is not implemented and the reCAPTCHA verifier returns a hardcoded score of `1.0` — both accept anything. The wire fields (`CsrfToken`, `RecaptchaToken`) exist end-to-end and the FE sends `null` for both, so turning them on later is a service implementation, not a re-plumbing. **Until then, the 5/min/IP fixed-window rate limit and the `ReferralCode` honeypot are the only spam defences on this form.** This is the first genuinely public, un-slugged, internet-facing form we ship — it is on the open internet with no tenant slug to obscure it. Do not launch believing it is captcha-protected.

**Backend** (written, **not built** — the user runs `dotnet build`):

| File | What |
|---|---|
| `Base.Application/Business/SharedBusiness/Countries/PublicQueries/GetPublicCountries.cs` | Anonymous country list. |
| `Base.Application/Business/BillingBusiness/PlanCatalog/PublicQueries/GetPublicPlanTeasers.cs` | Anonymous plan teasers, `IsPubliclyListed = true` only. |
| `Base.Application/Business/OpsBusiness/LeadManagement/PublicCommands/SubmitProductEnquiry.cs` | Command + validator + handler. Forces `Source = INBOUND`, `Status = NEW`. |
| `Base.Application/Schemas/OpsSchemas/ProductEnquirySchemas.cs` | `ProductEnquiryDto`, `ProductEnquiryResultDto`. |
| `Base.API/EndPoints/Ops/Public/ProductLandingPublicQueries.cs` | `publicCountries`, `publicPlanTeasers` — both argument-free. |
| `Base.API/EndPoints/Ops/Public/ProductEnquiryPublicMutations.cs` | `submitProductEnquiry`, `[EnableRateLimiting("ProductEnquirySubmit")]`. |
| `Base.API/DependencyInjection.cs` | `ProductEnquirySubmit` fixed-window policy, 5/min/IP. |
| `Base.Domain/Models/BillingModels/Plan.cs` + `PlanConfiguration.cs` | `IsPubliclyListed`, `NOT NULL DEFAULT false`. |
| `Base.Domain/Models/OpsModels/Lead.cs` + `LeadConfiguration.cs` | `Industry` … `ConsentIpAddress`. |

**Migration** — spec is in §3.6. **Not generated, not run.** Migrations are strictly user-owned: the user authors, runs and commits it, then applies the two seeds in the stated order.

**Seeds** (written to `sql-scripts-dyanmic/`, **not applied**):
- `plan-public-listing-seed.sql` — publishes FREE / PLAN_50K / PLAN_100K / CUSTOM per §⑨ A1.
- `product-enquiry-notification-seed.sql` — `PLATFORM_LEAD_NOTIFICATION_EMAIL` + the `notify.EmailTemplates` row. **The recipient is a placeholder — replace it with a real monitored inbox before applying** (§⑨ A4).

**Frontend** — `npx tsc --noEmit --incremental false` → **exit 0**.

- `domain/entities/ops-service/ProductLandingDto.ts` (+ barrel)
- `infrastructure/gql-queries/public-queries/ProductLandingPublicQuery.ts` (+ barrel)
- `infrastructure/gql-mutations/public-mutations/ProductEnquiryPublicMutation.ts` (+ barrel)
- `presentation/pages/marketing/data/product-landing-content.ts` — **all page copy lives here**, one reviewable file, so "does this page claim a module we do not ship or a certification we do not hold?" is answerable by reading one file.
- `presentation/pages/marketing/services/product-landing-ssr.ts` — plans ISR 3600s (`public-plan-teasers`), countries 86400s (`public-countries`); every failure path returns `[]`, never throws.
- `presentation/pages/marketing/components/` — `marketing-icon.tsx`, `enquiry-form.tsx`.
- `presentation/pages/marketing/sections/` — hero, problem→outcome, module pillars, how-it-works, plans, security, faq, enquiry, header, footer.
- `presentation/pages/marketing/index.tsx` — `ProductLandingPage`.
- `app/[lang]/(public)/(marketing)/layout.tsx` — metadata override + Organization / SoftwareApplication / FAQPage JSON-LD.
- `app/[lang]/(public)/(marketing)/peopleserve/page.tsx` — serves `/{lang}/peopleserve`.

**Deviations from this prompt, and why:**

1. **§3.4 specifies `IsoCode`; there is no such column.** `com.Countries` exposes `CountryShortCode`. The public DTO and the FE bind `countryShortCode`.
2. **§⓪ claims `GetCountries` is anonymously reachable. It is not** — it carries `[CustomAuthorize(...)]`. Hence the purpose-built `GetPublicCountries`, which returns three columns and nothing else.
3. **§3.3 says the notification goes "via `ops.PlatformCommunicationProviders`", but no platform *composed-body* email method exists.** Resolved with `SendEmailByTemplateKeyAsync` plus a newly seeded `notify.EmailTemplates` row — which is why `product-enquiry-notification-seed.sql` exists at all. A composed-body platform sender is still a real gap; it belongs to the platform-comms track, not here.
4. **§④ step 11 says "record deviations in §⑬". This prompt has no §⑬** — its build log is this section, §⑩.
5. **§3.3's accepted-fields list names the honeypot `Website2`, while its own hardening bullet names it `ReferralCode`.** Built as **`ReferralCode`**. The page has a real `Website` field a visitor is *supposed* to fill in; a trap named `website` would silently bin genuine enquiries — thank-you shown, no lead written, nobody ever finds out.
6. **Section 2 (trust strip) does not ship** — §⑨ A5.
7. **Native `<select>` and native checkbox in the enquiry form** rather than the Radix `Select`/`Checkbox`. Token-styled, so it matches the kit. On a public page the native controls are the ones that open correctly on every mobile browser and degrade without JS; the Radix listbox does neither.
8. **FAQ uses native `<details>`/`<summary>`, not the `Accordion`.** Every answer must be in the DOM for crawlers and screen readers — a JS-gated accordion renders nothing to a crawler, and being found is this page's entire job. The FAQPage JSON-LD is generated from the same `FAQS` array, so structured data cannot drift from visible text.
9. **One `"use client"` leaf for icons (`MarketingIcon`).** §3.1 requires a Server Component page and §⑤ requires @iconify Phosphor icons; `@iconify/react`'s `Icon` is hook-based with no client directive, so it cannot render inside an RSC. All nine sections stay server-rendered.
10. **The OG image is referenced but not bundled** — `{MARKETING_SITE_URL}/og/peopleserve-1200x630.png`. It must be published on the marketing host before launch. A 404 makes social platforms drop the image silently; it will not error.

11. **The page moved off the locale root to `/{lang}/peopleserve`** (user instruction, same session, after §⑨ A3 was written). `pwdatasolutions.com/{lang}` is the PWDS *company* site and PeopleServe is one product on it, so claiming the locale root would have handed the company's own front page to a single product. `PRODUCT_PATH` + `productPageUrl(locale)` in `product-landing-content.ts` are the single source for the path; canonical, hreflang, `openGraph.url` and the SoftwareApplication JSON-LD all call it. Live URLs: `https://pwdatasolutions.com/{en,bn,ar}/peopleserve`, local `http://localhost:3000/en/peopleserve`.

**Known limits at launch:** CSRF/reCAPTCHA stubs (see the box above); `PLATFORM_LEAD_NOTIFICATION_EMAIL` fails *quiet* — unset means no alert and a successful submission, so leads pile up unseen on `/ops/leads`; the new `Lead` fields are captured but not yet surfaced on the lead detail drawer.
