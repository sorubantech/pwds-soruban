# Continuation Prompt — Screen #10 (Online Donation Page) Bug Remediation

> Paste this into a new session to resume the `/continue-screen` remediation flow.

## Context

Continuing bug-remediation for **screen #10 (Online Donation Page)**, driven by the audit register `.claude/screen-tracker/bug-reports/onlinedonationpage-audit-2026-07-10.md`. Screen type = **EXTERNAL_PAGE / DONATION_PAGE** (anonymous public donor surfaces at `/p/{slug}` NAV + `/embed/{slug}` IFRAME).

## Repo layout (3 independent git repos)

| Repo | Stack | Notes |
|------|-------|-------|
| `PSS_2.0_Frontend` | Next.js 14 / React / TS | its own git repo |
| `PSS_2.0_Backend` | .NET 8 / EF Core / GraphQL (HotChocolate) | its own git repo |
| `pss-2.0-global` | `.claude/screen-tracker` docs | its own git repo |

- Stage/commit **per-repo**.
- **User commits themselves — do NOT commit without explicit approval.**

## ✅ DONE — cancelled-donation staging strand (forward fix + one-off SQL) — NOT yet committed

**Trigger**: online-donation staging table showed a donor-**cancelled** donation still stuck in "payment gateway selection" state — `PaymentMethodId`=PENDING sentinel, `PaymentStatusId=Pending`, `GatewayResponseMessage=NULL`. Cause: PayU cancel/failure `furl` and Razorpay `modal.ondismiss` both terminate WITHOUT calling `ConfirmOnlineDonation`, so the Initiate-created staging row never advanced past PENDING and no gateway reason was captured. No migration — all columns already exist.

**Forward fix — new gateway-agnostic `MarkOnlineDonationFailed` mutation**:
- **BE** `Base.Application/.../PublicMutations/MarkOnlineDonationFailed.cs` (NEW) — command + validator + handler. Looks up staging by `PaymentSessionId`; resolves COMPLETED + FAILED master-data ids (canonical `PAYMENTSTATUS` lookup, case-insensitive, **no** `IsDeleted` filter per ODP-M8); idempotency guards (already COMPLETED → cached success, never clobbered; already FAILED → cached failed response); else sets `PaymentStatusId=FAILED`, truncated `GatewayResponseMessage`/`GatewayResponseCode`, conditional `GatewayTransactionId`; `SaveChanges`; writes `PAYMENT_FAILED` audit (userId:null). `ReceivedDate` intentionally NOT set. Returns `OnlineDonationConfirmedResponse`.
- **BE** `Base.API/.../OnlineDonationPagePublicQueries.cs` — `MarkOnlineDonationFailed` registered under the same `[EnableRateLimiting("DonationSubmit")]` policy as Initiate/Confirm.
- **FE** `OnlineDonationPagePublicMutation.ts` — `MARK_ONLINE_DONATION_FAILED` gql added.
- **FE** `payu/return/route.ts` — cancel/failure branch best-effort `await`s the mutation (correlate `udf5`=full paymentSessionId, reason=payuStatus, payload=all PayU fields) in try/catch before the failure redirect.
- **FE** `donation-form.tsx` — Razorpay `modal.ondismiss` fires `markDonationFailed({paymentSessionId, reason:"usercancelled"})` fire-and-forget.
- **Braintree** deliberately NOT wired — declines reach Confirm already; only pure Braintree abandonment strands (no client cancel hook reaches us; separate finding).

**One-off SQL** (user-applied): `PSS_2.0_Backend/PeopleServe/Services/Base/sql-scripts-dyanmic/online-donation-staging-cancelled-backfill.sql` — 3-step guarded script: STEP 1 read-only PREVIEW, STEP 2 `BEGIN;…COMMIT;` UPDATE flipping PENDING + `GatewayResponseMessage IS NULL` rows to the FAILED sibling (resolved in the SAME MasterDataTypeId via `JOIN LATERAL`), setting the cancel message + `GatewayResponseCode='USER_CANCELLED'` + `ModifiedBy=2`/`ModifiedDate=now()`, STEP 3 VERIFY count (expect 0). `ModifiedBy`/`ModifiedDate` confirmed on base `Entity` — SQL valid.

**Build verification**: BE `Base.Application` build → **0 errors** (full `Base.API` build hit pre-existing MSB3021 file-copy locks from running processes — NOT compile errors). FE `npx tsc --noEmit` → **0 errors**. No live gateway sandbox run.

**Next (user action)**: apply the one-off SQL (preview → transaction → verify), then commit the BE + FE + docs per-repo.

## ✅ DONE — ODP-H9 (failed-PayU donor dead-end, P1) — COMMITTED

- `payu/return/route.ts` — fixed dead cancel branch (`"userCancelled"` compared after `.toLowerCase()` → now matches `usercancelled` / `cancel` / `cancelled`).
- `p/[slug]/page.tsx` — reads `?donation=failed&reason=`, `describeDonationFailure()` maps to a charge-state-aware message, passes `forceError` to `<DonationPage>`.
- `donation-page.tsx` — `forceError` prop + dismissible `PaymentFailureBanner` rendered once in the dispatcher (covers all 7 templates).
- Tracker docs updated (prompt Build Log Session 41 + audit Fix Log). FE `tsc --noEmit` = 0 errors.

## ✅ DONE — ODP-H8 (clickjacking boundary / frame-ancestors CSP, session 43) — NOT yet committed

- **FE** `next.config.mjs` — new `async headers()` with two disjoint locale-prefixed rules: NAV `/:lang/p/:slug*` → `Content-Security-Policy: frame-ancestors 'none'` + legacy `X-Frame-Options: DENY` (never framable); IFRAME `/:lang/embed/:slug*` → `Content-Security-Policy: frame-ancestors *` (intentionally embeddable, X-Frame-Options deliberately omitted — cannot express "allow all origins"). Only the `frame-ancestors` directive is set (full CSP with script-src etc. out of scope — would risk breaking inline scripts/styles). `headers()` chosen over middleware because the `auth()` wrapper makes response-header injection there awkward.
- **FE** comment syncs in `(public)/layout.tsx` + `(public)/embed/[slug]/page.tsx` point at the `next.config.mjs headers()` policies.
- **FE** `tests/e2e/screens/onlinedonationpage.spec.ts` — skipped stub replaced with a real 2-test `clickjacking boundary (CSP frame-ancestors)` describe (NAV asserts CSP `frame-ancestors 'none'` + `X-Frame-Options: DENY`; IFRAME asserts CSP `frame-ancestors *` + empty X-Frame-Options).
- Tracker docs updated (prompt Build Log Session 43 + ISSUE-8 Known-Issues row CLOSED; audit Fix Log Session 43 + open-finding FIXED). FE `tsc --noEmit` = 0 errors.
- **Scope note**: FULL closure of the framing boundary. Per-tenant embed allow-list (restrict `frame-ancestors` to each charity's registered domains instead of `*`) remains a hardening follow-up.

## ✅ DONE — ODP-M10 (config-key drift, session 44) — VERIFIED already-resolved, NO code change

- Whole-backend grep for `EncryptionKey` returns only `Security:EncryptionKey` + canonical `PaymentGateway:CredentialEncryptionKey`; the drifted `PaymentGateway:EncryptionKey` exists nowhere.
- TEST webhook (`TestBraintreeWebhook`, `PaymentWebhookController.cs:228`) decrypts via `_encryptionService.DecryptForCompany` — same path as prod webhook — → `DerivePerCompanyKey` reads only the canonical key (`EncryptionService.cs:128`). Drift eliminated incidentally by the v2 AES-GCM/HKDF consolidation.
- Docs-only update (audit Fix Log + finding row marked VERIFIED FIXED). No BE/FE code touched, nothing to build.

## ✅ DONE — ODP-M11 (dead legacy Braintree credential path, ISSUE-26, session 45) — NOT yet committed

Removed the entire dead appsettings-bound legacy Braintree path (fully superseded by the LIVE per-tenant-creds `BraintreeProvider` via `PaymentGatewayFactory`, which is untouched).

- **Deleted 5 files:**
  - `Base.Infrastructure/Services/BraintreeService.cs` — singleton impl (only `using Braintree;` in that project).
  - `Base.Application/.../DonationBusiness/PaymentGateways/IBraintreeService.cs` — interface + DTOs `BraintreePaymentRequest`/`BraintreeTransactionResult`.
  - `Base.Application/.../DonationBusiness/PaymentGateways/BraintreeSettings.cs` — never-bound config POCO.
  - `Base.API/.../Donation/Queries/BraintreePaymentQueries.cs` — `[ExtendObjectType(Query)]` `GetBraintreeClientToken`.
  - `Base.API/.../Donation/Mutations/BraintreePaymentMutations.cs` — `[ExtendObjectType(Mutation)]` `ProcessBraintreePayment`/`VerifyBraintreeTransaction`/`RefundBraintreeTransaction`.
- **Edited 2 files:** removed `<PackageReference Include="Braintree" />` from `Base.Infrastructure.csproj`; removed the dead `"Braintree"` section from `Base.API/appsettings.json`.
- **Left untouched:** `Base.Support.csproj`'s own `Braintree VersionOverride="5.28.0"` (live path depends on it).
- **Verified dead before deleting:** no `AddSingleton<IBraintreeService>` / `Configure<BraintreeSettings>` / `GetSection("Braintree")` anywhere; zero FE callers; DTOs used only in the deleted files. Post-deletion grep of all 8 removed symbols → 0 references.
- **Compile proof:** `Base.Infrastructure` (transitively `Base.Application`) → **0 errors**; `Base.API` → **0 CS errors** (only 8 × MSB3021/MSB3027 output-copy locks from the running `Base.API` process — environment locks, not compile errors). No FE change.

**Next (user action)**: commit the BE + docs per-repo.

## ✅ DONE — ODP-H6 (SEO/OG/robots editor card missing, session 46) — NOT yet committed

Built the missing admin SEO/OG/robots editor card AND fixed the public page that ignored the stored `robotsIndexable` flag (previously hardcoded `index: true`, deindexing was impossible).

- **Admin FE (new card):** created `setting/publicpages/onlinedonationpage/sections/seo-section.tsx` — store-driven, no-prop `SectionCard` (`ph:share-network`, "Search & Social (SEO)", collapsible). Fields: `ogTitle` Input (maxLength 70), `ogDescription` Textarea (maxLength 160), `ogImageUrl` Input type=url, a live share-card preview with the OG-fallback note, and a `robotsIndexable` Switch (`color="success"`). All edits go through the Zustand `setField(...)`.
- **Wiring:** `editor-page.tsx` imports + renders `<SeoSection />` after `<ThankYouSection />`, OUTSIDE the NAV-only conditional → applies to both NAV and IFRAME implementations.
- **Public half (the real bug):** `OnlineDonationPagePublicQuery.ts` now selects `robotsIndexable`; `OnlineDonationPagePublicDto` carries it (required); `p/[slug]/page.tsx generateMetadata` now emits `robots: { index: !!data.robotsIndexable, follow: !!data.robotsIndexable }` instead of the hardcoded `index: true`. not-found branch already returns `index: false`.
- **Cascade fix (required-field addition):** 3 non-BE literal builders had to supply the new field — `preview/onlinedonationpage/[id]/page.tsx` (`page.robotsIndexable`), `template-mock-data.ts` (`true`), `live-preview.tsx` (`page.robotsIndexable`).
- **Compile proof:** `npx tsc --noEmit` → **0 errors**. No BE change (all four SEO fields already stored + returned by the BE).

**Next (user action)**: commit the FE + docs per-repo.

## ⏳ PENDING — pick next task from the audit register

_No self-contained quick-wins remain in the register. Remaining items are deferred (bigger scope / product decision)._

### Deferred (bigger scope / product decision — NOT quick wins)

- reCAPTCHA + CSRF shared-platform hardening pass.
- ODP-B5 auto-promotion → route via `/plan-screens`.

## Standing constraints (from memory — always in effect)

- **NEVER** run `dotnet ef migrations add` / `database update` / `remove` or hand-author migrations/snapshots — migrations are strictly user-owned. I write seed files; user applies.
- DB columns are UTC `timestamptz` (`DateTimeKind.Utc`; Npgsql throws on `Kind=Unspecified`).
- Prove compilation before handoff (BE build / FE `tsc --noEmit`).
- Default to **Sonnet** for build agents (cost-conscious).
- Reuse established sibling patterns; be honest about partial vs. full scope.

## Start by

Re-read the audit register (`onlinedonationpage-audit-2026-07-10.md`) to confirm current open findings. No self-contained quick-wins remain — the only open items are the two Deferred entries above (reCAPTCHA + CSRF hardening; ODP-B5 auto-promotion via `/plan-screens`), both of which need user confirmation before starting.
