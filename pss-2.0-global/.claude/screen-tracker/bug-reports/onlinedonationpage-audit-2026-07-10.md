# Online Donation Page (#10) — PM Audit & Bug Register (2026-07-10)

> **Scope of audit:** end-to-end #10 OnlineDonationPage — admin setup screen, public NAV page (`/p/{slug}`), public IFRAME widget (`/embed/{slug}` + `widget.js`), the anonymous donation pipeline (`InitiateOnlineDonation` → `ConfirmOnlineDonation`), the three wired gateways (Braintree / Razorpay / PayU-India), and the coupling to the deferred **Online Donation Inbox** promotion path.
> **Owner screen for this register:** #10 (linked from `prompts/onlinedonationpage.md` §⑬). Findings are tagged by the file/screen that owns the fix.
> **Method:** 5 parallel read-only code audits (admin setup FE, public donor FE, backend/security, global-readiness/compliance, tech-debt/testing/ops) + direct read of the entity, `InitiateOnlineDonation`, `ConfirmOnlineDonation`, and the staging architecture. No code changed *during* the audit; fixes applied afterward are in the Fix Log.
> Numbering is `ODP-*` (audit-local) to avoid colliding with the prompt's existing `ISSUE-1..38`. **Maps-to** names the already-tracked issue where one exists.

---

## Verdict

**NO-GO for live donations until the P0 list is closed.** The money-path *cryptography* is genuinely solid — gateway signature/hash verification (Braintree server-side Sale, Razorpay HMAC-SHA256 + amount re-check, PayU SHA-512 constant-time reverse hash), server-authoritative amounts/currency, per-tenant AES-GCM+HKDF credential encryption, and one-active-per-tenant lifecycle. But every **protective, compliance, and measurement** layer around it is a stub, a manual back-office step, or absent: the anonymous endpoint has no working anti-abuse, a captured payment never becomes a recorded/receipted donation without manual staff action, there is no GDPR consent or compliant tax receipt, no Stripe/PayPal/multi-currency/i18n, and no automated test has ever completed a single donation.

**Suitable today only as a controlled pilot for a single India / single-currency tenant with a trusted, low-traffic audience.**

**~40 findings — 9 blocker-class (P0), 14 high (P1), 11 medium (P2), 8 low.**

> ### Fix Log — Session 36 (2026-07-10, /continue-screen P0 quick-wins — BE build clean, FE tsc clean)
> Three self-contained P0 items that needed no shared-wiring, no infra provisioning, and no blueprint change:
> - ✅ **ODP-B2** — Anonymous TEST Braintree webhook is now gated to `IHostEnvironment.IsDevelopment()`; returns 404 (indistinguishable from a missing route) in Staging/Production. Injected `IHostEnvironment` into `PaymentWebhookController`. Closes the forge-financial-records hole.
> - ✅ **ODP-H5** — Title edit no longer silently rewrites a Published/Active page's slug. `identity-section.tsx::handleTitleChange` had a dead `if/else` that rewrote the slug whenever `slugManuallyEdited` was false (always false on a fresh editor load). Now auto-derives **only while status = Draft AND not manually edited**, and runs the reserved-slug check on the derived value.
> - ✅ **ODP-B6** — Donation-pipeline MasterData folded into the idempotent feature seed (`online-donation-page-sqlscripts.sql`, new STEP 0a2 + 0b): `PAYMENTMETHOD/PENDING` sentinel + `DONATIONMODE/OD` + `DONATIONTYPE/{ONETIMEDONATION,RECURRINGDONATION}` + `PAYMENTSTATUS/{PENDING,COMPLETED,FAILED}` + `RECURRINGFREQUENCY/{MO,QT,SA,AN}`. All NOT EXISTS-guarded. **Seed = user applies** (per project convention: I write, user runs). Removes the "first donation throws MASTERDATA_MISSING" landmine for the donation path. (Inbox-promotion MasterData — CONTACTBASETYPE/EMAILTYPE/CONTACTSTATUS — is owned by #175 and out of this seed's scope.)
>
> **Deliberately NOT fixed this session (documented, not half-fixed):** ODP-B1 rate-limit binding is a GraphQL-single-endpoint architectural problem (shared `DependencyInjection.cs` + a per-operation interceptor); reCAPTCHA needs a Google secret; real CSRF needs antiforgery/cookie middleware; ODP-B3 concurrency guard needs a DB unique key (migration = user-owned); ODP-B4/B5/B7/B8 are product/blueprint decisions → `/plan-screens`. See each finding for the path.
>
> ### Fix Log — Session 38 (2026-07-10, /continue-screen — ODP-B1 rate-limit binding, BE build clean)
> - 🟡 **ODP-B1 (PARTIAL — rate-limit half closed)** — The anonymous donation endpoint is no longer unbounded. Root cause was narrow: the `"DonationSubmit"` rate-limit policy the ODP resolvers referenced **was never registered** (all six sibling public pages — P2P, CrowdFund, Prayer, Volunteer, EventReg — already register + bind their own policy; ODP was the only one whose policy row was missing and whose attribute was never applied). Fix is pure reuse, mirroring `CrowdFundDonationSubmit` field-for-field:
>   - `DependencyInjection.cs` — added `options.AddPolicy("DonationSubmit", …)`, FixedWindow 5/min, partition `online-donate-{ip}-{slug}`.
>   - `OnlineDonationPagePublicQueries.cs` — added `using Microsoft.AspNetCore.RateLimiting;` and `[EnableRateLimiting("DonationSubmit")]` on **both** `InitiateOnlineDonation` and `ConfirmOnlineDonation` (mirrors CrowdFund binding both public mutations). Rewrote the stale SERVICE_PLACEHOLDER doc-comment.
>   BE `dotnet build Base.API.csproj` → 0 errors.
>   **Still open under ODP-B1 (org-wide, NOT ODP-specific — deferred with a clear path):** (a) **reCAPTCHA** is `var recaptchaScore = 1.0m` in *every* public Initiate handler (ODP, P2P, CrowdFund, EventReg) — making it real needs FE reCAPTCHA-v3 execution + a token field on the request DTO + a user-owned Google site/secret key + a `siteverify` service; it should be built once as a shared service, not per-page. (b) **CSRF** is a shape-only `token.Length >= 16` body check across all the same handlers — real double-submit needs a cookie written on render + a matching middleware/interceptor. Both are cross-cutting platform work, not a #10 patch.
>   *Known limitation carried from the sibling pattern (not introduced here):* the partition reads `httpContext.Request.Query["slug"]`, but GraphQL variables ride the POST body, so `slug` is empty and the effective partition is per-IP (still 5/min/IP). This affects every sibling policy identically; deliberately mirrored for consistency rather than diverged in this task.
>
> ### Fix Log — Session 41 (2026-07-10, /continue-screen — ODP-H9 failed-PayU donor dead-end, FE tsc clean)
> - ✅ **ODP-H9 (FIXED)** — A failed/cancelled PayU payment no longer dead-ends the donor on a blank form. PayU is a full-page hosted redirect (no in-component `onError` like the Razorpay popup); the return route already redirected to `/p/{slug}?donation=failed&reason=…` but the page only handled `?donation=success`, so the donor saw the empty form with no message and no idea whether they were charged. Also fixed the dead-branch bug: `route.ts` compared `payuStatus === "userCancelled"` **after** `.toLowerCase()`, so it never matched and a cancel fell through to Confirm. Changes (3 FE files, reuses the form's destructive-banner idiom):
>   - `payu/return/route.ts` — cancel check now compares lower-case `usercancelled` (+ `cancel`/`cancelled`); commented the pre-lowercase reason.
>   - `p/[slug]/page.tsx` — reads `reason`; new `describeDonationFailure()` maps it to an **honest, charge-state-aware** sentence (decline/cancel = not charged; `session_missing` = auto-reversed/contact us; `confirm_*`/verify-fail = may be charged, staff reconcile, don't retry; else = the BE message). Passes it as `forceError` to `DonationPage`.
>   - `donation-page.tsx` — `forceError?: string` prop; template `switch` refactored to a `templateView` var; a sticky dismissible `role="alert"` `PaymentFailureBanner` renders **once** in the dispatcher (covers all 7 templates + future variants, no per-template edits), styled with the in-form `border-destructive/30 + bg-destructive + text-destructive` palette.
>   FE `npx tsc --noEmit` → 0 errors project-wide.
>
> ### Fix Log — Session 40 (2026-07-10, /continue-screen — ODP-M9 slug-immutability guard, BE build clean)
> - ✅ **ODP-M9 (FIXED)** — `OnlineDonationPageSlugValidator.ValidateImmutableAfterDonationsAsync` only counted `GlobalDonations`, but every public donation lands in `fund.OnlineDonationStagings` first and is promoted to `GlobalDonations` only by the manual Donation Inbox step (#175, deferred). So an Active page that had already **captured real money** but whose rows weren't promoted still passed the guard → staff could change the slug and break live receipt/shared URLs. Added an additive OR clause counting a **captured** staging row: `OnlineDonationStagings.Any(s => s.OnlineDonationPageId == pageId && s.ReceivedDate != null && s.IsDeleted != true)`. `ReceivedDate` is stamped only on Confirm-success capture, so PENDING/abandoned initiates deliberately do NOT lock the slug (no spam-initiate lockout). No MasterData resolution needed; `IApplicationDbContext` already exposes `OnlineDonationStagings` via `IDonationDbContext`. Left the promoted-`GlobalDonations` check in place. BE `dotnet build Base.Application.csproj` → 0 errors.
>
> ### Fix Log — Session 39 (2026-07-10, /continue-screen — ODP-M8 MasterData NULL-filter, BE build clean)
> - ✅ **ODP-M8 (FIXED, +1 site beyond audit scope)** — The `GetMasterDataId` helper filtered `m.IsDeleted == false`, which in Postgres translates to `"IsDeleted" = false` and **excludes seed rows where `IsDeleted` is NULL** (seeds commonly insert MasterData with NULL). Result: the webhook status-lookup returned 0 → the gateway status-transition silently no-op'd (recurring donation status never advanced). Fix mirrors the proven canonical helper `GetMasterDataIdFirstOf` ([ConfirmOnlineDonation.cs:1213](../../../PSS_2.0_Backend/PeopleServe/Services/Base/Base.Application/Business/DonationBusiness/OnlineDonationPages/PublicMutations/ConfirmOnlineDonation.cs)), which deliberately omits the `IsDeleted` filter on MasterData lookups. Dropped `&& m.IsDeleted == false` at:
>   - `PayUWebhookController.cs:287` (its own comment already said "do NOT filter == false" — code now matches the comment)
>   - `RazorpayWebhookController.cs:438`
>   - `PaymentWebhookController.cs:216`
>   - **`PaymentFlowService.cs:94`** — the SAME defective helper on the *Initiate* path, which the audit's 3-controller scope missed. `GetMasterDataIdOptional` delegates to it, so both are covered. Fixed for completeness and flagged here.
>   Left untouched: the `CompanyPaymentGateways … IsDeleted == false` filters (different entity, genuinely soft-deleted with explicit `false`). BE `dotnet build Base.API.csproj` → 0 errors.
>   *Build note (not my change):* an unrelated in-flight working-tree edit to CrowdFund public stats (`GetCrowdFundPublicStats.cs` + `CrowdFundPublicQueries.cs`, changing `GetCrowdFundPublicStatsQuery` to a 2-arg record) was mid-flight; a stale incremental `Base.Application.dll` made Base.API report a phantom "no ctor takes 2 arguments" error. Rebuilding Base.Application (0 errors) cleared it — it compiles fine and is someone else's uncommitted work, not part of this fix.
>
> ### Fix Log — Session 37 (2026-07-10, /continue-screen — ODP-H1 audit-parity, BE build clean)
> - 🟡 **ODP-H1 (PARTIAL)** — `ConfirmOnlineDonation.cs` now emits `WritePaymentEvent` audit rows on **all** one-time gateway branches, not just PayU. Added 5 calls mirroring the existing PayU pattern: **Braintree** exception (`PAYMENT_FAILED`/HIGH), decline (`PAYMENT_FAILED`/MEDIUM), capture (`PAYMENT_CAPTURED`/LOW); **Razorpay** one-time verify-fail (`PAYMENT_FAILED`/MEDIUM) and capture (`PAYMENT_CAPTURED`/LOW). Every card charge/decline through the donor Confirm path now leaves durable proof in `audit.AuditLogs`. `auditLogWriter` was already in scope. BE `dotnet build Base.API.csproj` → 0 errors.
>   **Still open under ODP-H1 (webhook-side, deferred):** recurring-cycle webhooks (Braintree `SUBSCRIPTION_CHARGED_SUCCESSFULLY`, Razorpay `subscription.charged`) still don't create `GlobalDonation` rows → recurring totals/receipts remain understated. That half needs the staging→ledger promotion decision (ODP-B5) and lives in the webhook controllers, not Confirm.

---

## Root-cause map (fix these upstream, many findings collapse)

| Root cause | Findings it drives |
|---|---|
| **Deferred inbox promotion** — a public donation writes only an `OnlineDonationStaging` row; the `GlobalDonation` (which every total + receipt reads) is created only when staff resolve the row in the Donation Inbox (#175). | ODP-B5, ODP-H1, ODP-H10, ODP-M9, ODP-B8 (receipts) |
| **Anti-automation stack is all no-op** — rate-limit unbound, reCAPTCHA hardcoded 1.0, CSRF shape-only. | ODP-B1, ODP-B3 (amplified) |
| **Single-market build** — payments, currency, and language are hard-bound to India/base-currency/English; the provider abstraction is bypassed in the donation flow. | ODP-H2, ODP-H3, ODP-H4 |
| **Compliance layer absent** — no consent capture, no receipt generation, no jurisdiction receipt formats. | ODP-B7, ODP-B8 |
| **Never exercised end-to-end** — no green automated donation, seed landmine, no reconciliation/alerting. | ODP-B6, ODP-B9, ODP-M4 |

---

## P0 — BLOCKERS

### ODP-B1 · Anti-automation stack is a no-op on an anonymous money endpoint — 🟡 PARTIAL (session 38)
reCAPTCHA is `var recaptchaScore = 1.0m` (never rejects; no site/secret key in config); the `DonationSubmit` rate-limit policy is **never registered/bound**; CSRF is a `token.Length >= 16` shape-check on a throwaway GUID never persisted or cookie-paired. → card-testing / enumeration / gateway-billing abuse the moment a live key is set. **Owner:** BE (`InitiateOnlineDonation.cs:105-119`, `OnlineDonationPagePublicQueries.cs:100-104`). **Maps-to:** ISSUE-9, ISSUE-19.
**🟡 Session 38 — rate-limit half CLOSED:** the `[EnableRateLimiting("DonationSubmit")]` binding now attaches to a real registered policy (5/min/IP/slug, mirrors `CrowdFundDonationSubmit`) on both public mutations; the endpoint is no longer unbounded. **Still open (org-wide, not ODP-specific):** reCAPTCHA=1.0 in every public Initiate handler (needs FE token + user-owned Google secret + shared `siteverify` service) and shape-only CSRF (needs cookie-pair middleware). See the Session 38 Fix Log for the full path. **Path for the remainder:** shared platform service + user-owned secrets.

### ODP-B2 · Anonymous TEST webhook could forge financial records — ✅ FIXED (session 36)
`POST /api/webhooks/braintree/{companyCode}/test` was `[AllowAnonymous]` with no env guard, synthesising a validly-signed notification from the tenant's real creds and driving `ProcessWebhookEvent` (mutates `RecurringDonationSchedule`). **Owner:** BE `PaymentWebhookController.cs:222`. Now Development-only, returns 404 elsewhere.

### ODP-B3 · Confirm double-charge / duplicate-record race
Idempotency is an unlocked read of `staging.PaymentStatusId`; two concurrent Confirms on one session both see PENDING and both call `Transaction.Sale` → donor charged twice, duplicate schedules. **Owner:** `ConfirmOnlineDonation.cs:90-101,170-176`. **Fix:** DB unique key (e.g. on `GatewayTransactionId` or a processed-marker) or optimistic-concurrency token — **migration = user-owned**; a best-effort `IMemoryCache`/`SemaphoreSlim` guard covers only single-instance sequential retries.

### ODP-B4 · Public tenant resolver still degrades to `OrderBy(CompanyId).First()`
When a hostname matches no CustomDomain/Subdomain, both the slug read and the Initiate write resolve to the lowest-CompanyId tenant → cross-tenant donation misattribution / wrong-tenant gateway charge. **Owner:** `GetOnlineDonationPageBySlug.cs:298-303`, `OnlineDonationPageTenantResolver.cs:83-88`. **Maps-to:** ISSUE-1, ISSUE-32. **Path:** hosting/tenant-routing product decision → `/plan-screens`.

### ODP-B5 · Captured ≠ recorded — a successful payment is not a recorded donation
`Confirm` charges the card but deliberately does **not** create a `GlobalDonation`; promotion is a manual staff action in the Online Donation Inbox (#175). This page's `totalRaised`/`donorCount` read `GlobalDonations`, so captured-but-unresolved money shows **£0 raised**; no `ReceiptNumber` is issued and the receipt email is a logged placeholder while the donor is told "a receipt will be emailed shortly." Deviates from approved §⑫ ("donations live in GlobalDonations"). **Owner:** cross-cutting (`ConfirmOnlineDonation.cs:29-31`, `ResolveOnlineDonationStaging.cs`, `GetOnlineDonationPageStats.cs`). **Maps-to:** ISSUE-3. **Path:** product decision (auto-promote vs. surface a "pending" figure) → `/plan-screens`.

### ODP-B6 · MASTERDATA_MISSING seed landmine — first donation fails — ✅ FIXED (session 36, donation-path subset)
Feature seed shipped only `PAYMENTMETHOD` codes; the runtime hard-requires `DONATIONMODE/OD`, `DONATIONTYPE/*`, `PAYMENTSTATUS/*`, `PAYMENTMETHOD/PENDING`, `RECURRINGFREQUENCY/*`. **Owner:** DB seed. **Maps-to:** ISSUE-28. Donation-path rows now folded into the idempotent seed; **user applies**.

### ODP-B7 · No GDPR/CCPA consent, cookie consent, or marketing opt-in
Form collects name/email/phone/address with no consent checkbox, privacy-policy link, or data-subject-rights path. **Legal blocker for EU/UK/California.** **Owner:** public FE + entity (new fields). **Path:** blueprint change → `/plan-screens`.

### ODP-B8 · No compliant tax receipt (no number, no email, no jurisdiction format)
No receipt number generated, receipt email stubbed, no UK Gift Aid / India 80G (PAN) / US 501(c)(3) capture or format. Charities lose the 25% Gift Aid uplift and cannot issue deductible receipts. **Owner:** cross-cutting (receipt pipeline + entity). **Maps-to:** ISSUE-3. **Path:** blueprint → `/plan-screens`.

### ODP-B9 · Zero functional test coverage — no green end-to-end donation
`onlinedonationpage.test-result.md`: `INFRA_ERROR`, 1 run, 1 pass (a static-asset GET), 5 fail on missing `storageState.json`, 26 skipped. No automated test charges a card or asserts a COMPLETED row. **Owner:** `/test-screen` + E2E creds. **Path:** add a sandbox-gateway E2E once ODP-B1/B6 land.

---

## P1 — HIGH

- **ODP-H1 · Braintree/Razorpay charges write no audit row; recurring cycles never create GlobalDonations.** — 🟡 PARTIAL (session 37). One-time Confirm audit parity DONE: `ConfirmOnlineDonation.cs` now writes `WritePaymentEvent` on every Braintree/Razorpay branch (exception/decline/capture), not just PayU. **Still open:** Braintree `SUBSCRIPTION_CHARGED_SUCCESSFULLY` only bumps counters, Razorpay `subscription.charged` makes a PaymentTransaction but no GlobalDonation → understated recurring totals, missing recurring receipts. **Remaining owner:** webhook controllers + staging→ledger promotion (ODP-B5). **Maps-to:** ISSUE-27.
- **ODP-H2 · Multi-currency inert.** Donor `CurrencyCode` is used only to route the gateway; the staging row always stores `page.PrimaryCurrencyId`. Admin toggle is "Coming soon"; Primary Currency is read-only base. **Owner:** BE `InitiateOnlineDonation.cs:566` + FE. **Maps-to:** ISSUE-35, ISSUE-12 (FX).
- **ODP-H3 · No i18n / RTL** on public *or* admin surfaces despite shipped `en`/`bn`/`ar` locales and `[lang]` routing. `/ar/p/...` renders English, LTR. **Owner:** FE.
- **ODP-H4 · India-biased payments; provider abstraction bypassed.** No Stripe/native PayPal/Apple Pay/SEPA/iDEAL/ACH; `Initiate` hard-rejects non-BRAINTREE/RAZORPAY/PAYU (`:312`); gateway-specific fields leak into shared DTOs. **Owner:** BE payment layer. **Maps-to:** ISSUE-2.
- **ODP-H5 · Title edit rewrote a Published page's slug (link rot) — ✅ FIXED (session 36).** `identity-section.tsx`.
- **ODP-H6 · Entire SEO/OG/robots editor card missing.** `ogTitle/ogDescription/ogImageUrl/robotsIndexable` are stored but have no admin control; `robotsIndexable` is also ignored on the public page (`p/[slug]/page.tsx:119` hardcodes `index:true`). **Owner:** admin FE + public route.
- **ODP-H7 · No in-app unsaved-changes guard.** Header Back / list nav use `router.push`, which doesn't fire the `beforeunload`-only guard → silent data loss. **Owner:** `editor-page.tsx`.
- **ODP-H8 · No `frame-ancestors` CSP anywhere.** NAV `/p/{slug}` has no clickjacking protection; the NAV/IFRAME security boundary doesn't exist. **Owner:** `next.config.mjs` / middleware. **Maps-to:** ISSUE-8.
- **ODP-H9 · Failed PayU payment dead-ends the donor.** Return route builds `?donation=failed&reason=…` but the page only handles `success` → blank form, no message, donor unsure if charged. Also `route.ts:99` compares `"userCancelled"` after `.toLowerCase()` (dead branch). **Owner:** `payu/return/route.ts`, `p/[slug]/page.tsx:140`. — ✅ **FIXED (session 41)**; page now reads `reason` and renders a charge-state-aware dismissible failure alert (once, in the `DonationPage` dispatcher — all templates), and the dead cancel-branch is fixed to lower-case. FE tsc 0 errors.
- **ODP-H10 · No analytics/measurement.** Conversion rate is a placeholder; no GA/Meta pixel/dataLayer/funnel/UTM. Can't optimize or run paid acquisition. **Owner:** FE + (visit-log) BE. **Maps-to:** ISSUE-4.
- **ODP-H11 · Conversion revenue left on the floor.** No cover-the-fees (recovers 2-4% of gross), no gift matching (module exists, unwired), tribute is a bare checkbox, no abandonment recovery. **Owner:** product/FE+BE.
- **ODP-H12 · Slug validation is cosmetic** — `slugError` is local state; never gates Save/Publish. **Owner:** `identity-section.tsx` + `editor-page.tsx`.
- **ODP-H13 · IFRAME mode shipped-but-disabled dead weight** — switcher blocks selection ("Coming soon") but a full card + 2 preview variants remain unreachable for new pages. **Owner:** admin FE (hide or ship).
- **ODP-H14 · List capped at 50 rows;** search/filter/KPIs run over loaded rows only, and "Total raised — across all pages" is really "across loaded pages." **Owner:** `list-page.tsx`.

---

## P2 — MEDIUM

- **ODP-M1 · Accessibility gaps** — labels not `htmlFor`/`id`-associated (admin + public), no focus management across payment phases, amount/frequency chips lack `aria-pressed`, CTA contrast fails on a light tenant `primaryColorHex` (hardcoded `text-white`), locked donor-field rows use a non-focusable icon. **Owner:** FE (both surfaces).
- **ODP-M2 · No donor self-service** — can't manage/cancel recurring or update an expiring card; `UpdateSubscriptionAmountAsync` is a Braintree TODO; no dunning. Card-expiry churn unmanaged. **Owner:** new surface.
- **ODP-M3 · No admin refund / dispute / chargeback flow** for online donations (provider `RefundAsync` exists, no UI). **Owner:** Donation Inbox / finance.
- **ODP-M4 · No gateway↔DB reconciliation or failed-donation alerting** — failures are `LogWarning`/`LogError` only. **Owner:** ops/BE.
- **ODP-M5 · Abandoned PENDING staging rows + orphaned Razorpay plans/subscriptions accrue forever;** no cleanup job. **Owner:** BE background job. **Maps-to:** ISSUE-25.
- **ODP-M6 · Recurring-Confirm multi-row inserts have no transaction boundary** — mid-sequence failure orphans token/schedule. **Owner:** `ConfirmOnlineDonation.cs:769-855,919-1018`.
- **ODP-M7 · IFRAME thank-you discards the Confirm response** (per-txn redirect/receipt lost); **`widget.js` omits `[lang]`** → extra redirect + nondeterministic donor locale. **Owner:** `iframe-widget.tsx`, `public/widget.js`.
- **ODP-M8 · MasterData `IsDeleted == false` filter in all 3 webhook controllers** excludes NULL-`IsDeleted` seed rows → status transitions silently no-op. **Owner:** `PayUWebhookController.cs:287`, `RazorpayWebhookController.cs:438`, `PaymentWebhookController.cs:212`. — ✅ **FIXED (session 39)**; dropped the `IsDeleted` filter to mirror `GetMasterDataIdFirstOf`, at all 3 webhook helpers **plus** `PaymentFlowService.cs:94` (same defect on the Initiate path, missed by the audit's 3-controller scope). BE build 0 errors.
- **ODP-M9 · Slug immutability guard checks `GlobalDonations` but donations live in staging** → an Active page with real (staging) donations still permits a slug change. **Owner:** `OnlineDonationPageSlugValidator.cs:116-139`. — ✅ **FIXED (session 40)**; guard now also blocks on a **captured** staging row (`OnlineDonationStagings … ReceivedDate != null`), so unpromoted-but-charged donations lock the slug too. PENDING/abandoned initiates (no `ReceivedDate`) deliberately don't lock. BE build 0 errors.
- **ODP-M10 · ISSUE-24 config-key drift** — the TEST webhook path historically read `PaymentGateway:EncryptionKey` (absent) vs the canonical `PaymentGateway:CredentialEncryptionKey`. **Owner:** BE config. *(ODP-B2's env-gate now blocks that path in prod, reducing exposure.)*
- **ODP-M11 · Dead legacy Braintree credential path** (appsettings singleton `BraintreeService` + `GetBraintreeClientToken`) coexists with tenant-creds path. **Owner:** BE cleanup. **Maps-to:** ISSUE-26.

---

## LOW

- **ODP-L1 · Legacy reset-token crypto is unauthenticated AES-CBC** with weak key derivation (`EncryptionService.cs:87-117`) — separate subsystem, flagged for the platform team (the payment-cred `EncryptForCompany` path is correct AES-GCM+HKDF).
- **ODP-L2 · `StripScriptTags` is a bypassable regex** (`OnlineDonationPageEntityHelper.cs:139-155`); relies on runtime CSP.
- **ODP-L3 · Unique index is `(CompanyId, Slug)` not `LOWER(Slug)`**, and the partial `"IsDeleted" = false` filter excludes NULL-`IsDeleted` rows (defense-in-depth only; writers lowercase before persist).
- **ODP-L4 · Stale spec/entity docs** — §⑥ + Save Model still describe 300ms autosave (removed session 5); entity doc still claims aggregations read `GlobalDonations` (pre-staging pivot).
- **ODP-L5 · Debug `console.log` in prod paths** — `editor-page.tsx:229` logs the full save payload; `onlinedonationpage.tsx:16` logs capabilities.
- **ODP-L6 · Razorpay double-click double-order window** (button not disabled during async script load); `₹` hardcoded on the Pay button; SPA thank-you state lost on refresh/back.
- **ODP-L7 · Thin trust signals** — no charity-registration/EIN, no privacy-policy link, no refund-policy display.
- **ODP-L8 · Sample seed page uses an unimplemented STRIPE gateway** with placeholder creds → the seeded `give` demo page can never take a payment.

---

## Recommended sequencing

1. **P0 gate (before any live key):** ODP-B1 (rate-limit binding + real reCAPTCHA + working CSRF), ✅ODP-B2, ODP-B3 (concurrency), ODP-B4 (kill OrderBy fallback), ✅ODP-B6, ODP-B9 (one green E2E), and the **ODP-B5/B7/B8 product decision** on auto-promotion + consent + receipts.
2. **P1:** real provider abstraction → Stripe + PayPal; ODP-H1 audit/ledger for all gateways; ODP-H2 donor-chosen multi-currency + FX; ODP-H3 i18n/RTL; ODP-H6/H7/H8/H12 admin+security fixes; ODP-H10 analytics/pixel.
3. **P2:** cover-the-fees, matching, tribute, donor self-service portal, dunning, refund/chargeback UI, a11y pass, reconciliation/alerting, tech-debt cleanup.
